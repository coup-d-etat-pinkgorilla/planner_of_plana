from __future__ import annotations

import os
import re
import unittest
from types import SimpleNamespace
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import QObject, QPointF, Qt
from PySide6.QtGui import QColor
from PySide6.QtQuick import QQuickItem, QQuickView
from PySide6.QtTest import QTest
from PySide6.QtWidgets import QApplication

from gui.quick.aspect_window import (
    DESIGN_ASPECT,
    WMSZ_BOTTOM,
    WMSZ_BOTTOMRIGHT,
    WMSZ_RIGHT,
    constrain_client_size,
    fit_inside,
)
from gui.quick.design_registry import build_quick_component_map, quick_override_issues
from gui.quick.home_menu_surface_item import HomeMenuSurfaceItem
from gui.quick.models import (
    AppController,
    InventoryListModel,
    InventoryRow,
    PlanRow,
    PlanResourceRow,
    PlanResourceListModel,
    StudentListModel,
    StudentRow,
    TacticalMatchRow,
    plan_resource_rows,
)
from gui.quick.panel_surface_item import PlannerSurfaceItem
from gui.quick.studio_models import QuickStudioController
from gui.quick.theme import QuickThemeController, build_quick_tokens
from gui.quick.triangle_texture_item import TriangleTextureItem
from gui.quick_app import _initial_window_size, _show_after_first_frame, create_view
from gui import viewer_launcher
from gui.ui_design_spec import ComponentOverride, DiagonalShapeSpec, UIDesignSpec, load_ui_design_spec, save_ui_design_spec
from tools.ui_component_studio_quick import create_studio_view
from core.planning import load_plan
from core.planning_calc import PlanCostSummary
from core.tactical_challenge import TacticalDeck, query_tactical_matches


class AspectWindowTests(unittest.TestCase):
    def test_initial_quick_window_uses_normal_1280_by_720_size(self) -> None:
        size = _initial_window_size(2560, 1392)

        self.assertEqual((size.width, size.height), (1280, 720))

    def test_initial_quick_window_still_fits_a_smaller_work_area(self) -> None:
        size = _initial_window_size(1200, 700)

        self.assertLessEqual(size.width, 1200)
        self.assertLessEqual(size.height, 700)
        self.assertAlmostEqual(size.width / size.height, DESIGN_ASPECT, places=2)

    def test_width_drag_preserves_design_aspect(self) -> None:
        size = constrain_client_size(1280, 640, WMSZ_RIGHT)
        self.assertEqual(size.width, 1280)
        self.assertAlmostEqual(size.width / size.height, DESIGN_ASPECT, places=2)


    def test_height_drag_preserves_design_aspect(self) -> None:
        size = constrain_client_size(1200, 720, WMSZ_BOTTOM)
        self.assertEqual(size.height, 720)
        self.assertAlmostEqual(size.width / size.height, DESIGN_ASPECT, places=2)

    def test_corner_drag_selects_nearest_axis_and_respects_minimum(self) -> None:
        size = constrain_client_size(400, 300, WMSZ_BOTTOMRIGHT)
        self.assertGreaterEqual(size.width, 960)
        self.assertGreaterEqual(size.height, 540)
        self.assertAlmostEqual(size.width / size.height, DESIGN_ASPECT, places=2)

    def test_fit_inside_never_exceeds_available_area(self) -> None:
        size = fit_inside(1600, 1000)
        self.assertLessEqual(size.width, 1600)
        self.assertLessEqual(size.height, 1000)
        self.assertAlmostEqual(size.width / size.height, DESIGN_ASPECT, places=2)


class ViewerSelectionTests(unittest.TestCase):
    def test_quick_viewer_is_default_and_legacy_is_opt_in(self) -> None:
        with patch.dict(os.environ, {}, clear=False):
            os.environ.pop("BA_PLANNER_LEGACY_UI", None)
            self.assertEqual(viewer_launcher._selected_viewer_module(), "gui.quick_app")
        with patch.dict(os.environ, {"BA_PLANNER_LEGACY_UI": "1"}):
            self.assertEqual(viewer_launcher._selected_viewer_module(), "gui.viewer_app_qt")


class InventoryListModelTests(unittest.TestCase):
    def setUp(self) -> None:
        self.rows = [
            InventoryRow("a", "Equipment_Icon_Bag_Tier1", "가방", 12, "equipment"),
            InventoryRow("b", "Item_Icon_SkillBook_Abydos_1", "기술 노트", 7, "skill_books"),
            InventoryRow("c", "Currency_Icon_Gold", "크레딧", 1234, "resources"),
        ]
        self.model = InventoryListModel(self.rows)

    def test_model_exposes_named_roles_without_creating_row_widgets(self) -> None:
        self.assertEqual(self.model.rowCount(), 3)
        index = self.model.index(0, 0)
        self.assertEqual(self.model.data(index, self.model.NameRole), "가방")
        self.assertEqual(self.model.data(index, self.model.QuantityRole), 12)
        self.assertEqual(bytes(self.model.roleNames()[self.model.NameRole]), b"name")

    def test_query_and_category_filter_the_same_source_rows(self) -> None:
        self.model.category = "equipment"
        self.assertEqual(self.model.rowCount(), 1)
        self.model.category = "all"
        self.model.query = "gold"
        self.assertEqual(self.model.rowCount(), 1)
        self.assertEqual(self.model.data(self.model.index(0, 0), self.model.ItemIdRole), "Currency_Icon_Gold")


class StudentListModelTests(unittest.TestCase):
    def test_owned_and_query_filters_do_not_mutate_source_rows(self) -> None:
        model = StudentListModel(
            [
                StudentRow("a", "아루", True, 90, 5, "게헨나", "폭발", "경장갑", "딜러", ""),
                StudentRow("b", "시로코", False, 0, 3, "아비도스", "폭발", "경장갑", "딜러", ""),
            ]
        )
        model.ownedOnly = True
        self.assertEqual(model.rowCount(), 1)
        model.ownedOnly = False
        model.query = "아비도스"
        self.assertEqual(model.rowCount(), 1)
        self.assertEqual(model.data(model.index(0, 0), model.StudentIdRole), "b")

    def test_metadata_filters_use_the_shared_student_filter_contract(self) -> None:
        model = StudentListModel(
            [
                StudentRow("a", "아루", True, 90, 5, "게헨나", "폭발", "경장갑", "딜러", ""),
                StudentRow("b", "시로코", True, 90, 5, "아비도스", "폭발", "경장갑", "딜러", ""),
            ]
        )
        model.setFilter("school", "게헨나")
        self.assertEqual(model.rowCount(), 1)
        model.clearFilters()
        self.assertEqual(model.rowCount(), 2)


class PlanResourceModelTests(unittest.TestCase):
    def test_cost_summary_is_flattened_without_calling_it_shortage(self) -> None:
        summary = PlanCostSummary(
            credits=123_000,
            star_materials={"Item_Icon_SecretStone_1": 20},
            skill_books={"게헨나 기술 노트": 7},
        )
        model = PlanResourceListModel(plan_resource_rows(summary))
        self.assertEqual(model.rowCount(), 2)
        quantities = {
            model.data(model.index(index, 0), model.QuantityRole)
            for index in range(model.rowCount())
        }
        self.assertEqual(quantities, {7, 20})


class PlanControllerTests(unittest.TestCase):
    def test_plan_edits_use_the_existing_growth_plan_contract(self) -> None:
        with TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "growth_plan.json"
            controller = AppController(load_data=False, plan_path=path)
            controller._student_rows = [
                StudentRow("aru", "아루", True, 80, 5, "게헨나", "폭발", "경장갑", "딜러", "")
            ]
            controller.selectedStudentId = "aru"
            self.assertEqual(controller.selectedStudentDetail["displayName"], "아루")
            controller.addPlanStudent("aru")
            controller.setPlanTarget("aru", "target_level", 90)
            controller.setPlanTarget("aru", "target_star", 5)
            controller.setPlanTarget("aru", "target_weapon_level", 50)
            controller.setPlanTarget("aru", "target_equip1_tier", 9)
            controller.setPlanTarget("aru", "target_stat_atk", 20)
            controller.setPlanNotes("aru", "육성 우선")
            saved = load_plan(path)
            self.assertEqual(len(saved.goals), 1)
            self.assertEqual(saved.goals[0].student_id, "aru")
            self.assertEqual(saved.goals[0].target_level, 90)
            self.assertEqual(saved.goals[0].target_star, 5)
            self.assertEqual(saved.goals[0].target_weapon_level, 50)
            self.assertEqual(saved.goals[0].target_equip1_tier, 9)
            self.assertEqual(saved.goals[0].target_stat_atk, 20)
            self.assertEqual(saved.goals[0].notes, "육성 우선")
            self.assertIn("credits", controller.planSummary)
            controller.removePlanStudent("aru")
            self.assertEqual(load_plan(path).goals, [])


class ScanCommandTests(unittest.TestCase):
    def test_item_scan_always_supplies_filter_to_avoid_tk_dialog(self) -> None:
        controller = AppController(load_data=False)
        command = controller._scanner_command("items", "ooparts")
        self.assertIn("--item-scan-filter", command)
        self.assertEqual(command[command.index("--item-scan-filter") + 1], "ooparts")


class TacticalControllerTests(unittest.TestCase):
    def test_tactical_entry_uses_existing_sqlite_contract(self) -> None:
        with TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "tactical_challenge.db"
            controller = AppController(load_data=False)
            controller._tactical_path = path
            controller.addTacticalMatch(
                "2026-07-18", "S1", "상대", "win", "attack",
                "아루,츠바키|히비키", "유우카,슌|세리나",
            )
            matches = query_tactical_matches(path)
            self.assertEqual(len(matches), 1)
            self.assertEqual(matches[0].opponent, "상대")
            self.assertEqual(matches[0].result, "win")
            self.assertEqual(controller.tacticalModel.count, 1)
            controller.addTacticalJokbo(
                "유우카,슌|세리나", "아루,츠바키|히비키", "테스트 족보"
            )
            controller.searchTacticalJokbo("유우카,슌|세리나", "")
            self.assertGreaterEqual(len(controller.tacticalJokboResults), 1)
            self.assertTrue(any(row["source"] == "수동 족보" for row in controller.tacticalJokboResults))

    def test_screenshot_readout_becomes_an_editable_draft(self) -> None:
        controller = AppController(load_data=False)
        worker = object()
        controller._screenshot_workers.append(worker)
        readout = SimpleNamespace(
            mode="attack",
            result="loss",
            confidence=0.91,
            warnings=["확인 필요"],
            left=SimpleNamespace(deck=TacticalDeck(["aru"], ["hibiki"])),
            right=SimpleNamespace(deck=TacticalDeck(["yuuka"], ["serina"])),
        )
        controller._on_tactical_screenshot_loaded(worker, "result.png", readout)
        self.assertEqual(controller.tacticalDraft["result"], "loss")
        self.assertIn("aru", controller.tacticalDraft["attackDeck"])
        self.assertEqual(controller.tacticalDraft["confidence"], 0.91)


class QuickStudioTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QApplication.instance() or QApplication([])

    def test_studio_edits_existing_design_contract_without_viewer_tree(self) -> None:
        with TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "ui_design_spec.json"
            save_ui_design_spec(
                UIDesignSpec(components={"Root/QFrame#card": ComponentOverride("Root/QFrame#card")}),
                path,
            )
            controller = QuickStudioController(path)
            self.assertEqual(controller.entryCount, 47)
            self.assertEqual(
                len([entry for entry in controller.entries if entry["kind"] == "qml_component"]),
                20,
            )
            self.assertEqual(
                len([entry for entry in controller.entries if entry["kind"] == "qml_control"]),
                6,
            )
            self.assertEqual(
                len([entry for entry in controller.entries if entry["kind"] == "qml_overlay"]),
                2,
            )
            self.assertEqual(
                len([entry for entry in controller.entries if entry["kind"] == "qml_delegate"]),
                8,
            )
            self.assertEqual(
                len([entry for entry in controller.entries if entry["kind"] == "qml_element"]),
                10,
            )
            controller.setPalette("accent", "#123456")
            controller.setShape("Root/QFrame#card", "cut", "both", 70, 30)
            controller.save()
            saved = load_ui_design_spec(path)
            self.assertEqual(saved.palette["accent"], "#123456")
            self.assertEqual(saved.components["Root/QFrame#card"].diagonal_shape.edge, "both")

    def test_studio_saves_qml_shape_override_in_a_separate_selector_namespace(self) -> None:
        with TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "ui_design_spec.json"
            save_ui_design_spec(UIDesignSpec(), path)
            controller = QuickStudioController(path)
            controller.setQuickShape("qml/students/header", "left", 72, "reverse", 2, 14)
            controller.setQuickLayout("qml/students/header", 0, 190, 12, 6)
            controller.setQuickStyle("qml/students/header", "selected", 26, 3, 14)
            controller.setTypography("font_title", 40)
            controller.save()
            saved = load_ui_design_spec(path)
            override = saved.components["qml/students/header"]
            self.assertTrue(override.qml_shape_enabled)
            self.assertEqual(override.diagonal_shape.edge, "left")
            self.assertEqual(override.diagonal_shape.direction, "reverse")
            self.assertEqual(override.diagonal_shape.angle_degrees, 72)
            self.assertEqual(override.elevation, 2)
            self.assertEqual(override.content_safe_margin, 14)
            self.assertEqual(override.qml_preferred_size, [0, 190])
            self.assertEqual(override.qml_content_padding, [12, 6, 12, 6])
            self.assertEqual(override.qml_variant, "selected")
            self.assertEqual(override.qml_radius, 26)
            self.assertEqual(override.qml_border_width, 3)
            self.assertEqual(override.qml_content_spacing, 14)
            self.assertEqual(saved.typography["font_title"], 40)

            controller.resetQuickComponent("qml/students/header")
            controller.save()
            self.assertNotIn("qml/students/header", load_ui_design_spec(path).components)

    def test_invalid_qml_override_is_rejected_and_runtime_uses_registered_default(self) -> None:
        selector = "qml/students/header"
        invalid = ComponentOverride(
            selector=selector,
            qml_shape_enabled=True,
            diagonal_shape=DiagonalShapeSpec(edge="left", angle_degrees=120, hit_mask=True),
            elevation=9,
            qml_preferred_size=[2400, 1200],
            qml_content_padding=[0, 0, 0, 160],
            qml_variant="unknown",
            qml_radius=80,
            qml_border_width=8,
            qml_content_spacing=90,
        )
        spec = UIDesignSpec(components={selector: invalid})
        issues = quick_override_issues(spec)
        self.assertIn(selector, issues)
        resolved = build_quick_component_map(spec)["students/header"]
        self.assertEqual(resolved["diagonalEdge"], "right")
        self.assertEqual(resolved["elevation"], 3.0)

        control_selector = "qml/controls/button"
        invalid_control = ComponentOverride(
            selector=control_selector,
            qml_preferred_size=[0, 88],
            qml_pressed_surface="arbitraryColor",
        )
        control_spec = UIDesignSpec(components={control_selector: invalid_control})
        self.assertIn(control_selector, quick_override_issues(control_spec))
        resolved_control = build_quick_component_map(control_spec)["controls/button"]
        self.assertEqual(resolved_control["preferredHeight"], 54)
        self.assertEqual(resolved_control["preferredWidth"], 0)
        self.assertEqual(resolved_control["pressedSurface"], "accentStrong")

        overlay_selector = "qml/overlays/dialog"
        invalid_overlay = ComponentOverride(
            selector=overlay_selector,
            qml_surface="arbitraryColor",
            qml_scrim_opacity=1.5,
        )
        overlay_spec = UIDesignSpec(components={overlay_selector: invalid_overlay})
        self.assertIn(overlay_selector, quick_override_issues(overlay_spec))
        resolved_overlay = build_quick_component_map(overlay_spec)["overlays/dialog"]
        self.assertEqual(resolved_overlay["surface"], "panelAlt")
        self.assertEqual(resolved_overlay["scrimOpacity"], 0.5)

        delegate_selector = "qml/delegates/student-card"
        invalid_delegate = ComponentOverride(
            selector=delegate_selector,
            qml_selected_surface="arbitraryColor",
        )
        delegate_spec = UIDesignSpec(components={delegate_selector: invalid_delegate})
        self.assertIn(delegate_selector, quick_override_issues(delegate_spec))
        resolved_delegate = build_quick_component_map(delegate_spec)["delegates/student-card"]
        self.assertEqual(resolved_delegate["preferredHeight"], 226)
        self.assertEqual(resolved_delegate["selectedSurface"], "surfaceSelected")
        defaults = build_quick_component_map(UIDesignSpec())
        self.assertEqual(defaults["delegates/home-window-row"]["preferredHeight"], 62)
        self.assertEqual(defaults["delegates/plan-resource-row"]["contentPadding"], [10, 10, 10, 10])
        self.assertEqual(defaults["delegates/tactical-jokbo-row"]["preferredHeight"], 78)
        self.assertEqual(defaults["delegates/tactical-match-row"]["preferredHeight"], 106)
        self.assertEqual(defaults["delegates/statistics-row"]["contentPadding"], [12, 12, 12, 12])

        element_selector = "qml/elements/student-status-badge"
        invalid_element = ComponentOverride(
            selector=element_selector,
            qml_opacity=1.5,
        )
        element_spec = UIDesignSpec(components={element_selector: invalid_element})
        self.assertIn(element_selector, quick_override_issues(element_spec))
        resolved_element = build_quick_component_map(element_spec)["elements/student-status-badge"]
        self.assertEqual(resolved_element["preferredHeight"], 34)
        self.assertEqual(resolved_element["opacity"], 0.78)
        self.assertEqual(defaults["elements/student-detail-panel"]["preferredWidth"], 410)
        self.assertEqual(defaults["elements/plan-resource-summary"]["preferredWidth"], 430)
        self.assertEqual(defaults["elements/statistics-summary-card"]["preferredHeight"], 90)
        self.assertEqual(defaults["elements/divider"]["preferredHeight"], 1)

    def test_saved_qml_override_updates_the_live_viewer_surface(self) -> None:
        with TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "ui_design_spec.json"
            save_ui_design_spec(UIDesignSpec(), path)
            theme = QuickThemeController(path)
            studio = QuickStudioController(path)
            view, _controller = create_view(AppController(load_data=False), theme)
            view.resize(1280, 720)
            view.show()
            root = view.rootObject()
            root.setProperty("currentPage", 1)
            QTest.qWait(30)
            header = root.findChild(QObject, "studentsHeaderPanel")
            self.assertIsNotNone(header)

            studio.setQuickShape("qml/students/header", "left", 72, "reverse", 1, 16)
            studio.setQuickLayout("qml/students/header", 0, 190, 12, 6)
            studio.setQuickStyle("qml/students/header", "selected", 26, 3, 14)
            studio.setTypography("font_title", 40)
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()

            self.assertEqual(header.property("effectiveDiagonalEdge"), "left")
            self.assertEqual(header.property("effectiveDiagonalDirection"), "reverse")
            self.assertAlmostEqual(float(header.property("effectiveDiagonalAngle")), 72.0)
            self.assertAlmostEqual(float(header.property("effectiveElevation")), 1.0)
            self.assertAlmostEqual(float(header.property("effectiveContentSafeMargin")), 16.0)
            self.assertAlmostEqual(float(header.property("effectivePreferredHeight")), 190.0)
            self.assertEqual(header.property("effectiveVariant"), "selected")
            self.assertAlmostEqual(float(header.property("effectiveRadius")), 26.0)
            self.assertAlmostEqual(float(header.property("effectiveBorderWidth")), 3.0)
            self.assertAlmostEqual(float(header.property("effectiveContentSpacing")), 14.0)
            self.assertAlmostEqual(float(header.property("height")), 190.0)
            token_object = root.findChild(QObject, "designTokens")
            self.assertEqual(int(token_object.property("fontTitle")), 40)
            self.assertIs(root.findChild(QObject, "studentsHeaderPanel"), header)
            view.close()
            view.deleteLater()
            self.app.processEvents()

    def test_control_style_save_updates_existing_qml_buttons(self) -> None:
        with TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "ui_design_spec.json"
            save_ui_design_spec(UIDesignSpec(), path)
            theme = QuickThemeController(path)
            studio = QuickStudioController(path)
            view, _controller = create_view(AppController(load_data=False), theme)
            view.resize(1280, 720)
            view.show()
            self.app.processEvents()
            def find_visual_item(item: QQuickItem, object_name: str):
                for child in item.childItems():
                    if child.objectName() == object_name:
                        return child
                    found = find_visual_item(child, object_name)
                    if found is not None:
                        return found
                return None

            button = find_visual_item(view.rootObject(), "mainNavButton")
            self.assertIsNotNone(button)

            studio.setQuickControlStyle(
                "qml/controls/button", 0, 60, 14, 2,
                "backgroundDeep", "surfaceSelected", "accent", "danger",
            )
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()

            self.assertAlmostEqual(float(button.property("effectivePreferredHeight")), 60.0)
            self.assertAlmostEqual(float(button.property("effectiveRadius")), 14.0)
            self.assertAlmostEqual(float(button.property("effectiveBorderWidth")), 2.0)
            self.assertEqual(button.property("effectiveNormalSurface"), "backgroundDeep")
            self.assertEqual(button.property("effectiveHoverSurface"), "surfaceSelected")
            self.assertEqual(button.property("effectivePressedSurface"), "danger")
            self.assertIs(find_visual_item(view.rootObject(), "mainNavButton"), button)
            saved = load_ui_design_spec(path).components["qml/controls/button"]
            self.assertEqual(saved.qml_preferred_size, [0, 60])
            self.assertEqual(saved.qml_radius, 14)
            self.assertEqual(saved.qml_border_width, 2)
            self.assertEqual(saved.qml_pressed_surface, "danger")
            view.close()
            view.deleteLater()
            self.app.processEvents()

    def test_auxiliary_control_styles_update_existing_qml_objects(self) -> None:
        with TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "ui_design_spec.json"
            save_ui_design_spec(UIDesignSpec(), path)
            theme = QuickThemeController(path)
            studio = QuickStudioController(path)
            view, _controller = create_view(AppController(load_data=False), theme)
            view.resize(1280, 720)
            view.show()
            root = view.rootObject()

            def find_visual_item(item: QQuickItem, object_name: str):
                for child in item.childItems():
                    if child.objectName() == object_name:
                        return child
                    found = find_visual_item(child, object_name)
                    if found is not None:
                        return found
                return None

            progress = find_visual_item(root, "scanProgressBar")
            self.assertIsNotNone(progress)
            studio.setQuickControlStyle(
                "qml/controls/progress", 0, 18, 9, 2,
                "panelAlt", "accent", "accentStrong", "danger",
            )
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()
            self.assertIs(find_visual_item(root, "scanProgressBar"), progress)
            self.assertAlmostEqual(float(progress.property("effectivePreferredHeight")), 18.0)
            self.assertEqual(progress.property("effectiveActiveSurface"), "accentStrong")

            root.setProperty("currentPage", 1)
            QTest.qWait(30)
            checkbox = find_visual_item(root, "ownedStudentsCheckBox")
            self.assertIsNotNone(checkbox)
            studio.setQuickControlStyle(
                "qml/controls/checkbox", 30, 30, 10, 2,
                "panelAlt", "panelRaised", "accentStrong", "danger",
            )
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()
            self.assertIs(find_visual_item(root, "ownedStudentsCheckBox"), checkbox)
            self.assertAlmostEqual(float(checkbox.property("effectivePreferredWidth")), 30.0)
            self.assertAlmostEqual(float(checkbox.property("effectivePreferredHeight")), 30.0)
            self.assertEqual(checkbox.property("effectivePressedSurface"), "danger")

            root.setProperty("currentPage", 3)
            QTest.qWait(30)
            scrollbar = find_visual_item(root, "inventoryScrollBar")
            self.assertIsNotNone(scrollbar)
            studio.setQuickControlStyle(
                "qml/controls/scrollbar", 16, 0, 8, 1,
                "border", "panelRaised", "accent", "danger",
            )
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()
            self.assertIs(find_visual_item(root, "inventoryScrollBar"), scrollbar)
            self.assertAlmostEqual(float(scrollbar.property("effectivePreferredWidth")), 16.0)
            self.assertEqual(scrollbar.property("effectiveNormalSurface"), "border")
            saved = load_ui_design_spec(path).components
            self.assertEqual(saved["qml/controls/progress"].qml_preferred_size, [0, 18])
            self.assertEqual(saved["qml/controls/checkbox"].qml_preferred_size, [30, 30])
            self.assertEqual(saved["qml/controls/scrollbar"].qml_preferred_size, [16, 0])
            view.close()
            view.deleteLater()
            self.app.processEvents()

    def test_overlay_styles_update_existing_dialog_and_dropdown_objects(self) -> None:
        with TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "ui_design_spec.json"
            save_ui_design_spec(UIDesignSpec(), path)
            theme = QuickThemeController(path)
            studio = QuickStudioController(path)
            view, _controller = create_view(AppController(load_data=False), theme)
            view.resize(1280, 720)
            view.show()
            root = view.rootObject()
            root.setProperty("currentPage", 1)
            QTest.qWait(30)
            dialog = root.findChild(QObject, "advancedFiltersPopup")
            self.assertIsNotNone(dialog)
            dialog.setProperty("visible", True)
            QTest.qWait(30)
            self.app.processEvents()

            studio.setQuickOverlayStyle(
                "qml/overlays/dialog", 0, 0, 20, 24, 3,
                "panel", "accentStrong", "danger", 70,
            )
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()

            self.assertIs(root.findChild(QObject, "advancedFiltersPopup"), dialog)
            self.assertTrue(bool(dialog.property("visible")))
            self.assertAlmostEqual(float(dialog.property("effectivePadding")), 20.0)
            self.assertAlmostEqual(float(dialog.property("effectiveRadius")), 24.0)
            self.assertEqual(dialog.property("effectiveSurface"), "panel")
            self.assertEqual(dialog.property("effectiveScrimSurface"), "danger")
            self.assertAlmostEqual(float(dialog.property("effectiveScrimOpacity")), 0.7)
            dialog.setProperty("visible", False)

            root.setProperty("currentPage", 4)
            QTest.qWait(30)
            self.app.processEvents()
            dropdown = root.findChild(QObject, "plannerComboPopup")
            self.assertIsNotNone(dropdown)
            studio.setQuickOverlayStyle(
                "qml/overlays/dropdown", 0, 280, 8, 12, 2,
                "panelRaised", "accent", "backgroundDeep", 0,
            )
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()
            self.assertIs(root.findChild(QObject, "plannerComboPopup"), dropdown)
            self.assertAlmostEqual(float(dropdown.property("effectivePreferredHeight")), 280.0)
            self.assertAlmostEqual(float(dropdown.property("effectivePadding")), 8.0)
            self.assertEqual(dropdown.property("effectiveSurface"), "panelRaised")
            saved = load_ui_design_spec(path).components
            self.assertEqual(saved["qml/overlays/dialog"].qml_content_padding, [20, 20, 20, 20])
            self.assertEqual(saved["qml/overlays/dialog"].qml_scrim_opacity, 0.7)
            self.assertEqual(saved["qml/overlays/dropdown"].qml_preferred_size, [0, 280])
            view.close()
            view.deleteLater()
            self.app.processEvents()

    def test_delegate_styles_update_existing_virtualized_rows(self) -> None:
        with TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "ui_design_spec.json"
            save_ui_design_spec(UIDesignSpec(), path)
            controller = AppController(load_data=False)
            controller.studentModel.replace_rows(
                [StudentRow("aru", "아루", True, 80, 5, "게헨나", "폭발", "경장갑", "딜러", "")]
            )
            controller.selectedStudentId = "aru"
            controller.inventoryModel.replace_rows(
                [InventoryRow("item", "item", "아이템", 10, "other")]
            )
            controller.planModel.replace_rows(
                [PlanRow("aru", "아루", "", 80, 5, 90, 5, 5, 10, 10, 10, "")]
            )
            controller.planResourceModel.replace_rows(
                [PlanResourceRow("크레딧", "크레딧", 1000)]
            )
            controller.tacticalModel.replace_rows(
                [TacticalMatchRow("match", "2026-07-18", "시즌", "상대", "win", "attack", "A", "B", "")]
            )
            theme = QuickThemeController(path)
            studio = QuickStudioController(path)
            view, _controller = create_view(controller, theme)
            view.resize(1280, 720)
            view.show()
            root = view.rootObject()

            def find_visual_item(item: QQuickItem, object_name: str):
                for child in item.childItems():
                    if child.objectName() == object_name:
                        return child
                    found = find_visual_item(child, object_name)
                    if found is not None:
                        return found
                return None

            root.setProperty("currentPage", 1)
            QTest.qWait(30)
            student = find_visual_item(root, "studentDelegateSurface")
            portrait = find_visual_item(root, "studentPortraitFrame")
            badge = find_visual_item(root, "studentStatusBadge")
            detail_panel = find_visual_item(root, "studentDetailPanel")
            self.assertIsNotNone(student)
            self.assertIsNotNone(portrait)
            self.assertIsNotNone(badge)
            self.assertIsNotNone(detail_panel)
            studio.setQuickDelegateStyle(
                "qml/delegates/student-card", 240, 12, 11, 13, 14, 18, 2,
                "panelAlt", "panelAlt", "accent", "border", "accentStrong",
            )
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()
            self.assertIs(find_visual_item(root, "studentDelegateSurface"), student)
            self.assertAlmostEqual(float(student.property("effectivePreferredHeight")), 240.0)
            self.assertAlmostEqual(float(student.property("effectivePaddingRight")), 13.0)
            self.assertEqual(student.property("effectiveSelectedSurface"), "accent")
            studio.setQuickElementStyle(
                "qml/elements/student-portrait", 0, 0, 12, 1, 95,
                "panelAlt", "accent",
            )
            studio.setQuickElementStyle(
                "qml/elements/student-status-badge", 0, 38, 4, 0, 84,
                "panel", "border",
            )
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()
            self.assertIs(find_visual_item(root, "studentPortraitFrame"), portrait)
            self.assertIs(find_visual_item(root, "studentStatusBadge"), badge)
            self.assertAlmostEqual(float(portrait.property("effectiveRadius")), 12.0)
            self.assertAlmostEqual(float(badge.property("effectivePreferredHeight")), 38.0)
            self.assertAlmostEqual(float(badge.property("effectiveOpacity")), 0.84)
            studio.setQuickElementStyle(
                "qml/elements/student-detail-panel", 440, 0, 16, 2, 100,
                "panelAlt", "accent",
            )
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()
            self.assertIs(find_visual_item(root, "studentDetailPanel"), detail_panel)
            self.assertAlmostEqual(float(detail_panel.property("effectivePreferredWidth")), 440.0)
            self.assertEqual(detail_panel.property("effectiveSurface"), "panelAlt")

            root.setProperty("currentPage", 3)
            QTest.qWait(30)
            inventory = find_visual_item(root, "inventoryDelegate")
            inventory_icon = find_visual_item(root, "inventoryIconFrame")
            self.assertIsNotNone(inventory)
            self.assertIsNotNone(inventory_icon)
            studio.setQuickDelegateStyle(
                "qml/delegates/inventory-row", 90, 16, 2, 20, 2, 10, 2,
                "panel", "panelAlt", "panel", "border", "border",
            )
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()
            self.assertIs(find_visual_item(root, "inventoryDelegate"), inventory)
            self.assertAlmostEqual(float(inventory.property("effectivePreferredHeight")), 90.0)
            self.assertAlmostEqual(float(inventory.property("effectivePaddingLeft")), 16.0)
            self.assertEqual(inventory.property("effectiveAlternateSurface"), "panelAlt")
            studio.setQuickElementStyle(
                "qml/elements/inventory-icon", 62, 62, 12, 1, 100,
                "panelAlt", "border",
            )
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()
            self.assertIs(find_visual_item(root, "inventoryIconFrame"), inventory_icon)
            self.assertAlmostEqual(float(inventory_icon.property("effectivePreferredWidth")), 62.0)

            root.setProperty("currentPage", 2)
            QTest.qWait(30)
            plan = find_visual_item(root, "planDelegate")
            plan_portrait = find_visual_item(root, "planPortraitFrame")
            resource_summary = find_visual_item(root, "planResourceSummary")
            self.assertIsNotNone(plan)
            self.assertIsNotNone(plan_portrait)
            self.assertIsNotNone(resource_summary)
            studio.setQuickDelegateStyle(
                "qml/delegates/plan-row", 120, 14, 14, 14, 14, 14, 1,
                "panelRaised", "panelRaised", "surfaceSelected", "border", "accent",
            )
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()
            self.assertIs(find_visual_item(root, "planDelegate"), plan)
            self.assertAlmostEqual(float(plan.property("effectivePreferredHeight")), 120.0)
            self.assertAlmostEqual(float(plan.property("effectivePaddingTop")), 14.0)
            studio.setQuickElementStyle(
                "qml/elements/plan-portrait", 88, 0, 11, 1, 100,
                "panelAlt", "border",
            )
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()
            self.assertIs(find_visual_item(root, "planPortraitFrame"), plan_portrait)
            self.assertAlmostEqual(float(plan_portrait.property("effectivePreferredWidth")), 88.0)
            studio.setQuickElementStyle(
                "qml/elements/plan-resource-summary", 450, 0, 14, 2, 100,
                "panelAlt", "border",
            )
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()
            self.assertIs(find_visual_item(root, "planResourceSummary"), resource_summary)
            self.assertAlmostEqual(float(resource_summary.property("effectivePreferredWidth")), 450.0)

            resource = find_visual_item(root, "planResourceDelegate")
            self.assertIsNotNone(resource)
            studio.setQuickDelegateStyle(
                "qml/delegates/plan-resource-row", 64, 11, 11, 11, 11, 9, 1,
                "panelAlt", "panelAlt", "panelAlt", "border", "border",
            )
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()
            self.assertIs(find_visual_item(root, "planResourceDelegate"), resource)
            self.assertAlmostEqual(float(resource.property("effectivePreferredHeight")), 64.0)

            root.setProperty("currentPage", 4)
            QTest.qWait(30)
            tactical = find_visual_item(root, "tacticalMatchDelegate")
            self.assertIsNotNone(tactical)
            studio.setQuickDelegateStyle(
                "qml/delegates/tactical-match-row", 110, 13, 13, 13, 13, 11, 1,
                "panel", "panel", "panel", "border", "border",
            )
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()
            self.assertIs(find_visual_item(root, "tacticalMatchDelegate"), tactical)
            self.assertAlmostEqual(float(tactical.property("effectivePreferredHeight")), 110.0)

            root.setProperty("currentPage", 5)
            QTest.qWait(30)
            summary_card = find_visual_item(root, "statisticsSummaryCard")
            self.assertIsNotNone(summary_card)
            studio.setQuickElementStyle(
                "qml/elements/statistics-summary-card", 240, 96, 14, 2, 100,
                "panel", "accent",
            )
            studio.save()
            QTest.qWait(180)
            self.app.processEvents()
            self.assertIs(find_visual_item(root, "statisticsSummaryCard"), summary_card)
            self.assertAlmostEqual(float(summary_card.property("effectivePreferredWidth")), 240.0)
            self.assertAlmostEqual(float(summary_card.property("effectivePreferredHeight")), 96.0)
            saved = load_ui_design_spec(path).components
            self.assertEqual(saved["qml/delegates/student-card"].qml_preferred_size, [0, 240])
            self.assertEqual(saved["qml/delegates/inventory-row"].qml_content_padding, [16, 2, 20, 2])
            self.assertEqual(saved["qml/delegates/plan-row"].qml_selected_border_surface, "accent")
            self.assertEqual(saved["qml/delegates/plan-resource-row"].qml_preferred_size, [0, 64])
            self.assertEqual(saved["qml/delegates/tactical-match-row"].qml_content_padding, [13, 13, 13, 13])
            self.assertEqual(saved["qml/elements/student-status-badge"].qml_opacity, 0.84)
            self.assertEqual(saved["qml/elements/inventory-icon"].qml_preferred_size, [62, 62])
            self.assertEqual(saved["qml/elements/plan-portrait"].qml_preferred_size, [88, 0])
            self.assertEqual(saved["qml/elements/student-detail-panel"].qml_preferred_size, [440, 0])
            self.assertEqual(saved["qml/elements/plan-resource-summary"].qml_preferred_size, [450, 0])
            self.assertEqual(saved["qml/elements/statistics-summary-card"].qml_preferred_size, [240, 96])
            view.close()
            view.deleteLater()
            self.app.processEvents()

    def test_studio_qml_uses_fixed_canvas(self) -> None:
        controller = QuickStudioController()
        view, retained = create_studio_view(controller)
        self.assertIs(retained, controller)
        self.assertEqual(view.status(), QQuickView.Ready)
        self.assertIsNotNone(view.rootObject().findChild(QObject, "studioDesignCanvas"))
        view.close()
        view.deleteLater()
        self.app.processEvents()

    def test_studio_section_preview_uses_live_tree_ratio_and_copyable_paths(self) -> None:
        controller = QuickStudioController()
        studio_view, _retained = create_studio_view(controller)
        studio_view.resize(1280, 720)
        studio_view.show()
        root = studio_view.rootObject()
        entry = next(item for item in controller.entries if item["entryId"] == "qml/home/menu")
        root.setProperty("selectedEntry", entry)
        QTest.qWait(220)
        self.app.processEvents()

        tree_value = root.property("previewTree")
        tree = tree_value.toVariant() if hasattr(tree_value, "toVariant") else tree_value
        paths = [str(item["path"]) for item in tree]
        self.assertGreater(len(tree), 10)
        self.assertEqual(paths[0], "qml/home/menu")
        self.assertTrue(any("homePrimaryAction" in path for path in paths))

        def find_visual_item(item: QQuickItem, object_name: str):
            if item.objectName() == object_name:
                return item
            for child in item.childItems():
                found = find_visual_item(child, object_name)
                if found is not None:
                    return found
            return None

        self.assertIsNotNone(find_visual_item(root, "studioSectionPreview"))
        self.assertIsNotNone(find_visual_item(root, "studioSectionTree"))
        self.assertIsNotNone(find_visual_item(root, "copySectionPathButton"))
        self.assertIsNotNone(find_visual_item(root, "openSectionPreviewButton"))
        preview_window = root.findChild(QObject, "studioSectionPreviewWindow")
        actual_clip = root.findChild(QObject, "studioActualSectionClip")
        self.assertIsNotNone(preview_window)
        self.assertIsNotNone(actual_clip)
        self.assertEqual(int(actual_clip.property("width")), int(root.property("previewTargetWidth")))
        self.assertEqual(int(actual_clip.property("height")), int(root.property("previewTargetHeight")))

        viewer, _preview_controller = create_view(AppController(load_data=False))
        viewer.resize(1280, 720)
        viewer.show()
        QTest.qWait(40)
        menu = find_visual_item(viewer.rootObject(), "homeMenuSection")
        studio_ratio = float(root.property("previewTargetWidth")) / float(root.property("previewTargetHeight"))
        viewer_ratio = float(menu.width()) / float(menu.height())
        self.assertAlmostEqual(studio_ratio, viewer_ratio, places=5)
        self.assertAlmostEqual(float(preview_window.property("sectionRatio")), viewer_ratio, places=5)
        preview_window.resize(960, 540)
        self.app.processEvents()
        self.assertAlmostEqual(float(preview_window.property("canvasScale")), 0.5, places=5)

        controller.copyText(paths[-1])
        self.assertEqual(QApplication.clipboard().text(), paths[-1])
        viewer.close()
        viewer.deleteLater()
        studio_view.close()
        studio_view.deleteLater()
        self.app.processEvents()

    def test_studio_every_registered_section_resolves_a_live_subtree(self) -> None:
        controller = QuickStudioController()
        view, _retained = create_studio_view(controller)
        view.resize(1280, 720)
        view.show()
        root = view.rootObject()
        component_entries = [item for item in controller.entries if item["kind"] == "qml_component"]
        for entry in component_entries:
            with self.subTest(entry=entry["entryId"]):
                root.setProperty("selectedEntry", entry)
                tree = []
                for _attempt in range(10):
                    QTest.qWait(60)
                    self.app.processEvents()
                    tree_value = root.property("previewTree")
                    tree = tree_value.toVariant() if hasattr(tree_value, "toVariant") else tree_value
                    if tree:
                        break
                self.assertTrue(tree, entry["entryId"])
                self.assertEqual(tree[0]["path"], entry["entryId"])
                self.assertGreater(float(root.property("previewTargetWidth")), 1.0)
                self.assertGreater(float(root.property("previewTargetHeight")), 1.0)
        view.close()
        view.deleteLater()
        self.app.processEvents()

    def test_studio_control_apply_button_calls_control_style_slot(self) -> None:
        with TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "ui_design_spec.json"
            save_ui_design_spec(UIDesignSpec(), path)
            controller = QuickStudioController(path)
            view, _retained = create_studio_view(controller)
            view.resize(1280, 720)
            view.show()
            root = view.rootObject()
            entry = next(item for item in controller.entries if item["entryId"] == "qml/controls/button")
            root.setProperty("selectedEntry", entry)
            self.app.processEvents()

            def find_visual_item(item: QQuickItem, object_name: str):
                for child in item.childItems():
                    if child.objectName() == object_name:
                        return child
                    found = find_visual_item(child, object_name)
                    if found is not None:
                        return found
                return None

            apply_button = find_visual_item(root, "controlStyleApplyButton")
            self.assertIsNotNone(apply_button)
            center = apply_button.mapToScene(QPointF(apply_button.width() / 2, apply_button.height() / 2))
            QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, center.toPoint())
            self.app.processEvents()

            updated = next(item for item in controller.entries if item["entryId"] == "qml/controls/button")
            self.assertTrue(updated["isOverride"])
            self.assertEqual(updated["normalSurface"], "panel")
            self.assertEqual(updated["pressedSurface"], "accentStrong")

            overlay_entry = next(item for item in controller.entries if item["entryId"] == "qml/overlays/dialog")
            root.setProperty("selectedEntry", overlay_entry)
            self.app.processEvents()
            overlay_apply = find_visual_item(root, "overlayStyleApplyButton")
            self.assertIsNotNone(overlay_apply)
            overlay_center = overlay_apply.mapToScene(QPointF(overlay_apply.width() / 2, overlay_apply.height() / 2))
            QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, overlay_center.toPoint())
            self.app.processEvents()
            updated_overlay = next(item for item in controller.entries if item["entryId"] == "qml/overlays/dialog")
            self.assertTrue(updated_overlay["isOverride"])
            self.assertEqual(updated_overlay["surface"], "panelAlt")
            self.assertEqual(updated_overlay["scrimOpacityPercent"], 50)

            delegate_entry = next(item for item in controller.entries if item["entryId"] == "qml/delegates/inventory-row")
            root.setProperty("selectedEntry", delegate_entry)
            self.app.processEvents()
            delegate_apply = find_visual_item(root, "delegateStyleApplyButton")
            self.assertIsNotNone(delegate_apply)
            delegate_center = delegate_apply.mapToScene(QPointF(delegate_apply.width() / 2, delegate_apply.height() / 2))
            QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, delegate_center.toPoint())
            self.app.processEvents()
            updated_delegate = next(item for item in controller.entries if item["entryId"] == "qml/delegates/inventory-row")
            self.assertTrue(updated_delegate["isOverride"])
            self.assertEqual(updated_delegate["alternateSurface"], "panelRaised")
            self.assertEqual(updated_delegate["paddingRight"], 18)

            element_entry = next(item for item in controller.entries if item["entryId"] == "qml/elements/student-status-badge")
            root.setProperty("selectedEntry", element_entry)
            self.app.processEvents()
            element_apply = find_visual_item(root, "elementStyleApplyButton")
            self.assertIsNotNone(element_apply)
            element_center = element_apply.mapToScene(QPointF(element_apply.width() / 2, element_apply.height() / 2))
            QTest.mouseClick(view, Qt.LeftButton, Qt.NoModifier, element_center.toPoint())
            self.app.processEvents()
            updated_element = next(item for item in controller.entries if item["entryId"] == "qml/elements/student-status-badge")
            self.assertTrue(updated_element["isOverride"])
            self.assertEqual(updated_element["preferredHeight"], 34)
            self.assertEqual(updated_element["opacityPercent"], 78)
            view.close()
            view.deleteLater()
            self.app.processEvents()


class QuickThemeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QApplication.instance() or QApplication([])

    def test_shared_palette_is_expanded_into_semantic_tokens(self) -> None:
        spec = UIDesignSpec(palette={
            "accent": "#123456",
            "soft": "#e0e0e0",
            "panel": "#303840",
            "panel_alt": "#202830",
            "text": "#f0f0f0",
        })
        tokens = build_quick_tokens(spec)
        self.assertEqual(tokens["accent"], "#123456")
        self.assertEqual(tokens["panel"], "#303840")
        self.assertNotEqual(tokens["background"], tokens["panelAlt"])
        self.assertIn("surfaceSelected", tokens)

    def test_quick_triangle_item_builds_the_shared_renderer_config_from_palette(self) -> None:
        item = TriangleTextureItem()
        item.themePalette = {
            "background": "#101820",
            "panel": "#283848",
            "accentPale": "#aabbcc",
            "accent": "#123456",
        }
        config = item.texture_config()
        self.assertEqual(config.base_color, "#101820")
        self.assertEqual(config.accent_color, "#123456")
        self.assertEqual(config.random_seed, 7319)
        self.assertLess(config.tessellation_contrast, 0.04)

    def test_painted_surfaces_do_not_override_qquickitem_palette(self) -> None:
        for item in (TriangleTextureItem(), PlannerSurfaceItem()):
            meta = item.metaObject()
            theme_palette = meta.property(meta.indexOfProperty("themePalette"))
            quick_palette = meta.property(meta.indexOfProperty("palette"))
            self.assertEqual(theme_palette.typeName(), "QVariantMap")
            self.assertEqual(quick_palette.typeName(), "QQuickPalette*")

    def test_ucs_palette_save_updates_loaded_qml_without_recreating_view(self) -> None:
        with TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "ui_design_spec.json"
            spec = UIDesignSpec()
            spec.palette["accent"] = "#123456"
            save_ui_design_spec(spec, path)
            theme = QuickThemeController(path)
            view, _controller = create_view(AppController(load_data=False), theme)
            token_object = view.rootObject().findChild(QObject, "designTokens")
            self.assertIsNotNone(token_object)
            self.assertEqual(QColor(token_object.property("accent")).name(), "#123456")

            spec.palette["accent"] = "#abcdef"
            save_ui_design_spec(spec, path)
            QTest.qWait(180)
            self.app.processEvents()

            self.assertEqual(QColor(token_object.property("accent")).name(), "#abcdef")
            self.assertIs(view.rootObject().findChild(QObject, "designTokens"), token_object)
            view.close()
            view.deleteLater()
            self.app.processEvents()


class QuickPanelSurfaceTests(unittest.TestCase):
    def test_home_menu_surface_exposes_pointer_hover_feedback(self) -> None:
        surface = HomeMenuSurfaceItem()

        self.assertGreaterEqual(surface.metaObject().indexOfProperty("hovered"), 0)
        self.assertGreaterEqual(surface.metaObject().indexOfProperty("imageSource"), 0)

    def test_home_menu_surface_uses_complementary_bilateral_diagonals(self) -> None:
        surface = HomeMenuSurfaceItem()
        surface.setWidth(240)
        surface.setHeight(120)
        surface.extendLeft = True
        surface.cutRight = True
        surface.angle = 80
        surface.radius = 7
        path = surface.surface_path()

        self.assertFalse(path.contains(QPointF(1, 1)))
        self.assertTrue(path.contains(QPointF(12, 105)))
        self.assertTrue(path.contains(QPointF(225, 8)))
        self.assertFalse(path.contains(QPointF(235, 115)))
        self.assertGreater(surface.diagonalSlant, 0.0)

    def test_right_cut_recomputes_from_height_angle_and_radius(self) -> None:
        surface = PlannerSurfaceItem()
        surface.setWidth(320)
        surface.setHeight(120)
        surface.radius = 18
        surface.diagonalEdge = "right"
        surface.diagonalAngle = 80
        path = surface.surface_path()
        self.assertTrue(path.contains(QPointF(300, 18)))
        self.assertFalse(path.contains(QPointF(312, 105)))

        surface.setHeight(180)
        taller_path = surface.surface_path()
        self.assertFalse(taller_path.contains(QPointF(300, 160)))

    def test_reversing_cut_swaps_the_inset_endpoint_without_changing_bounds(self) -> None:
        surface = PlannerSurfaceItem()
        surface.setWidth(320)
        surface.setHeight(120)
        surface.radius = 12
        surface.diagonalEdge = "right"
        surface.diagonalDirection = "reverse"
        path = surface.surface_path()
        self.assertFalse(path.contains(QPointF(312, 15)))
        self.assertTrue(path.contains(QPointF(300, 100)))

    def test_surface_border_width_is_limited_to_the_ucs_safe_range(self) -> None:
        surface = PlannerSurfaceItem()
        surface.borderWidth = 9
        self.assertEqual(surface.borderWidth, 6.0)
        surface.borderWidth = -1
        self.assertEqual(surface.borderWidth, 0.0)

    def test_registry_preserves_existing_surface_hierarchy_without_overrides(self) -> None:
        components = build_quick_component_map(UIDesignSpec())
        self.assertEqual(components["main/header"]["variant"], "alt")
        self.assertEqual(components["main/profile"]["variant"], "raised")
        self.assertEqual(components["main/profile"]["radius"], 12.0)
        self.assertEqual(components["home/menu"]["diagonalEdge"], "right")
        self.assertEqual(components["home/connection"]["diagonalEdge"], "left")
        self.assertEqual(components["home/scan"]["diagonalAngle"], 80.0)
        self.assertEqual(components["students/header"]["contentSpacing"], 10)


class QuickQmlSmokeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QApplication.instance() or QApplication([])

    def test_pages_use_only_registered_visual_surfaces_and_planner_controls(self) -> None:
        pages_dir = Path(__file__).resolve().parents[1] / "gui" / "quick" / "qml" / "pages"
        raw_control = re.compile(
            r"(?m)^\s*(Button|TextField|TextArea|ComboBox|CheckBox|SpinBox|ProgressBar|ScrollBar|Popup|Dialog|Menu)\s*\{"
        )
        for qml_path in sorted(pages_dir.glob("*.qml")):
            source = qml_path.read_text(encoding="utf-8")
            self.assertNotRegex(source, r"\bRectangle\s*\{", qml_path.name)
            self.assertIsNone(raw_control.search(source), qml_path.name)
            self.assertNotRegex(source, r"#[0-9A-Fa-f]{6,8}\b", qml_path.name)

    def test_main_qml_loads_with_fixed_design_canvas(self) -> None:
        controller = AppController(load_data=False)
        controller.inventoryModel.replace_rows(
            [InventoryRow("a", "Currency_Icon_Gold", "크레딧", 100, "resources")]
        )
        view, retained_controller = create_view(controller)
        self.assertIs(retained_controller, controller)
        self.assertEqual(view.status(), QQuickView.Ready)
        root = view.rootObject()
        self.assertIsNotNone(root)
        design_canvas = root.findChild(QObject, "designCanvas")
        self.assertIsNotNone(design_canvas)
        triangle_texture = root.findChild(QObject, "triangleTexture")
        self.assertIsNotNone(triangle_texture)
        view.resize(1280, 720)
        view.show()
        self.app.processEvents()
        self.assertAlmostEqual(float(root.property("canvasScale")), 2 / 3, places=3)
        view.resize(1600, 900)
        self.app.processEvents()
        self.assertIs(root.findChild(QObject, "designCanvas"), design_canvas)
        self.assertIs(root.findChild(QObject, "triangleTexture"), triangle_texture)
        view.close()
        view.deleteLater()
        self.app.processEvents()

    def test_viewer_buttons_expose_pointer_hover_feedback(self) -> None:
        controller = AppController(load_data=False)
        view, _controller = create_view(controller)
        root = view.rootObject()

        def visual_descendants(item: QQuickItem):
            for child in item.childItems():
                yield child
                yield from visual_descendants(child)

        home_buttons = [
            root.findChild(QObject, "homePrimaryAction"),
            root.findChild(QObject, "homeStudentsAction"),
            root.findChild(QObject, "homeSettingsAction"),
        ]
        navigation_buttons = [
            item for item in visual_descendants(root)
            if item.objectName() == "mainNavButton"
        ]

        self.assertTrue(all(button is not None for button in home_buttons))
        self.assertTrue(navigation_buttons)
        self.assertTrue(all(button.property("hoverEnabled") for button in home_buttons))
        self.assertTrue(all(button.property("hoverEnabled") for button in navigation_buttons))

        view.close()
        view.deleteLater()
        self.app.processEvents()

    def test_quick_window_uses_the_theme_background_before_its_first_frame(self) -> None:
        controller = AppController(load_data=False)
        view, _controller = create_view(controller)
        expected = view._quick_theme_controller.tokens["background"]

        self.assertEqual(view.color().name().casefold(), str(expected).casefold())

        view.deleteLater()
        self.app.processEvents()

    def test_quick_window_is_revealed_only_after_its_first_frame(self) -> None:
        controller = AppController(load_data=False)
        view, _controller = create_view(controller)
        view.resize(1280, 720)

        _show_after_first_frame(view)
        self.assertEqual(view.opacity(), 0.0)

        view.frameSwapped.emit()
        self.assertEqual(view.opacity(), 1.0)

        view.close()
        view.deleteLater()
        self.app.processEvents()

    def test_home_restores_legacy_menu_and_opens_context_workspace(self) -> None:
        controller = AppController(load_data=False)
        view, _controller = create_view(controller)
        view.resize(1280, 720)
        view.show()
        QTest.qWait(30)
        self.app.processEvents()
        root = view.rootObject()

        def find_visual_item(item: QQuickItem, object_name: str):
            if item.objectName() == object_name:
                return item
            for child in item.childItems():
                found = find_visual_item(child, object_name)
                if found is not None:
                    return found
            return None

        home = find_visual_item(root, "homePage")
        menu = find_visual_item(root, "homeMenuSection")
        primary = find_visual_item(root, "homePrimaryAction")
        connection = find_visual_item(root, "homeConnectionSection")
        header_section = find_visual_item(root, "homeHeaderSection")
        header_content = find_visual_item(root, "homeHeaderContent")
        header_connector = find_visual_item(root, "homeHeaderActiveConnector")

        self.assertIsNotNone(home)
        self.assertIsNotNone(menu)
        self.assertIsNotNone(primary)
        self.assertIsNotNone(connection)
        self.assertIsNotNone(header_section)
        self.assertIsNotNone(header_content)
        self.assertIsNotNone(header_connector)
        self.assertEqual(home.property("workspaceMode"), "none")
        self.assertGreater(float(menu.property("diagonalDepth")), 0.0)
        self.assertTrue(header_section.property("visible"))
        self.assertGreater(float(header_content.property("diagonalDepth")), 0.0)
        self.assertTrue(header_connector.property("visible"))

        students = find_visual_item(root, "homeStudentsAction")
        plan = find_visual_item(root, "homePlanAction")
        settings = find_visual_item(root, "homeSettingsAction")
        overlap = float(students.property("x")) + float(students.property("width")) - float(plan.property("x"))
        self.assertAlmostEqual(overlap, float(students.property("diagonalSlant")) - 10.0, delta=1.0)
        self.assertTrue(settings.property("triangleOnly"))

        primary.clicked.emit()
        self.app.processEvents()
        self.assertEqual(home.property("workspaceMode"), "connection")
        self.assertTrue(connection.property("visible"))

        controller._target_hwnd = 7
        controller._target_title = "Blue Archive"
        controller._window_candidates = [{"hwnd": 7, "title": "Blue Archive", "size": "1920x1080"}]
        controller.targetChanged.emit()
        self.app.processEvents()
        primary.clicked.emit()
        self.app.processEvents()
        scan = find_visual_item(root, "homeScanSection")
        self.assertEqual(home.property("workspaceMode"), "scan")
        self.assertTrue(scan.property("visible"))

        self.assertIsNotNone(students)
        students.clicked.emit()
        QTest.qWait(20)
        self.app.processEvents()
        self.assertEqual(root.property("currentPage"), 1)
        view.close()
        view.deleteLater()
        self.app.processEvents()

    def test_every_page_instantiates_through_the_shared_component_layer(self) -> None:
        controller = AppController(load_data=False)
        view, _controller = create_view(controller)
        view.resize(1280, 720)
        view.show()
        root = view.rootObject()
        page_names = [
            "homePage",
            "studentsPage",
            "planPage",
            "inventoryPage",
            "tacticalPage",
            "statisticsPage",
            "settingsPage",
        ]
        for index, object_name in enumerate(page_names):
            root.setProperty("currentPage", index)
            QTest.qWait(20)
            self.app.processEvents()
            self.assertIsNotNone(root.findChild(QObject, object_name), object_name)
        students_header = root.findChild(QObject, "studentsHeaderPanel")
        root.setProperty("currentPage", 1)
        QTest.qWait(20)
        self.app.processEvents()
        students_header = root.findChild(QObject, "studentsHeaderPanel")
        self.assertIsNotNone(students_header)
        self.assertGreater(float(students_header.property("diagonalDepth")), 0.0)
        view.close()
        view.deleteLater()
        self.app.processEvents()

    def test_settings_navigation_applies_final_geometry_without_an_intermediate_home_layout(self) -> None:
        controller = AppController(load_data=False)
        view, _controller = create_view(controller)
        view.resize(1280, 720)
        view.show()
        self.app.processEvents()
        root = view.rootObject()
        header = root.findChild(QObject, "mainHeader")
        settings_action = root.findChild(QObject, "homeSettingsAction")
        preloaded_settings_page = root.findChild(QObject, "settingsPage")

        self.assertIsNotNone(header)
        self.assertIsNotNone(settings_action)
        self.assertIsNotNone(preloaded_settings_page)
        self.assertFalse(preloaded_settings_page.property("visible"))
        self.assertEqual(float(header.property("height")), 226.0)

        settings_action.clicked.emit()

        settings_page = root.findChild(QObject, "settingsPage")
        home_page = root.findChild(QObject, "homePage")
        self.assertEqual(root.property("currentPage"), 6)
        self.assertIs(settings_page, preloaded_settings_page)
        self.assertFalse(home_page.property("visible"))
        self.assertTrue(settings_page.property("visible"))
        self.assertEqual(float(header.property("height")), 62.0)
        self.assertEqual(float(settings_page.property("height")), 952.0)

        self.app.processEvents()
        self.assertEqual(float(header.property("height")), 62.0)
        self.assertEqual(float(settings_page.property("height")), 952.0)
        view.close()
        view.deleteLater()
        self.app.processEvents()

    def test_inventory_view_instantiates_only_visible_delegates(self) -> None:
        controller = AppController(load_data=False)
        controller.inventoryModel.replace_rows(
            [
                InventoryRow(str(index), f"Item_{index}", f"항목 {index}", index, "other")
                for index in range(1000)
            ]
        )
        view, _controller = create_view(controller)
        view.resize(1280, 720)
        view.show()
        root = view.rootObject()
        root.setProperty("currentPage", 3)
        for _ in range(4):
            self.app.processEvents()
        def visual_descendants(item: QQuickItem):
            for child in item.childItems():
                yield child
                yield from visual_descendants(child)

        delegates = [
            item for item in visual_descendants(root)
            if item.objectName() == "inventoryDelegate"
        ]
        self.assertGreater(len(delegates), 0)
        self.assertLess(len(delegates), 100)
        self.assertEqual(controller.inventoryModel.count, 1000)
        view.close()
        view.deleteLater()
        self.app.processEvents()

    def test_resize_preserves_loaded_page_tree_and_model_state(self) -> None:
        controller = AppController(load_data=False)
        controller.studentModel.replace_rows(
            [StudentRow("aru", "아루", True, 80, 5, "게헨나", "폭발", "경장갑", "딜러", "")]
        )
        view, _controller = create_view(controller)
        view.resize(1280, 720)
        view.show()
        root = view.rootObject()
        root.setProperty("currentPage", 1)
        for _ in range(4):
            self.app.processEvents()
        grid = root.findChild(QObject, "studentGrid")
        self.assertIsNotNone(grid)
        controller.studentModel.query = "아루"
        controller.selectedStudentId = "aru"
        view.resize(1600, 900)
        for _ in range(4):
            self.app.processEvents()
        self.assertIs(root.findChild(QObject, "studentGrid"), grid)
        self.assertEqual(controller.studentModel.query, "아루")
        self.assertEqual(controller.selectedStudentId, "aru")
        view.close()
        view.deleteLater()
        self.app.processEvents()


if __name__ == "__main__":
    unittest.main()
