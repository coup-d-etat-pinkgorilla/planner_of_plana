from __future__ import annotations

import importlib
import os
from pathlib import Path
import re
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import QRect, Qt, qInstallMessageHandler
from PySide6.QtGui import QColor
from PySide6.QtTest import QTest
from PySide6.QtWidgets import (
    QApplication,
    QComboBox,
    QHBoxLayout,
    QLabel,
    QProgressBar,
    QPushButton,
    QWidget,
)

from gui.ui_design_spec import ComponentOverride, UIDesignSpec, load_ui_design_spec, save_ui_design_spec
from gui.viewer_components.home import INK, MUTED, HomeElidedLabel
from gui.viewer_shared import UI_FONT_PATH, _load_ui_font_family
from tools.ui_component_studio import (
    SectionPreviewWindow, StudioWindow, _reload_visual_modules, configure_studio_application, set_studio_rendering,
    studio_rendering_enabled,
)


class UIComponentStudioTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QApplication.instance() or QApplication([])

    def test_studio_uses_the_same_bundled_font_as_planner(self) -> None:
        self.assertTrue(UI_FONT_PATH.exists())
        configure_studio_application(self.app)
        self.assertEqual(self.app.font().family(), _load_ui_font_family())
        self.assertEqual(self.app.font().pointSize(), 11)

    def test_gallery_does_not_construct_a_planner_preview(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            self.assertIsNone(studio.preview)
            self.assertGreaterEqual(len(studio.cards), 7)
            self.assertIn("type:QPushButton", studio.cards)
            studio.close()

    def test_source_refresh_rebuilds_gallery_and_preserves_selection(self) -> None:
        from gui.viewer_components.home import HomeTabComponent

        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            entry_id = "section:homeConnectionSection"
            studio.select_entry(entry_id)
            old_card = studio.cards[entry_id]

            original_builder = HomeTabComponent._build_home_connection_panel

            def marked_builder(component):
                section = original_builder(component)
                section.setProperty("hotReloadProbe", True)
                return section

            with (
                patch("tools.ui_component_studio._reload_visual_modules", return_value=("gui.viewer_app_qt",)),
                patch.object(HomeTabComponent, "_build_home_connection_panel", marked_builder),
            ):
                self.assertTrue(studio.reload_source_and_refresh())
            self.app.processEvents()

            self.assertEqual(studio.current_selector, entry_id)
            self.assertIsNot(studio.cards[entry_id], old_card)
            self.assertTrue(studio.cards[entry_id].property("selected"))
            self.assertTrue(studio.widgets[entry_id].property("hotReloadProbe"))
            self.assertIn("1개 재로딩", studio.source_refresh_status.text())
            studio.close()

    def test_source_refresh_reopens_existing_preview(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            studio.select_entry("section:homeConnectionSection")
            old_preview = Mock()
            studio.preview = old_preview

            with (
                patch("tools.ui_component_studio._reload_visual_modules", return_value=("gui.viewer_app_qt",)),
                patch.object(studio, "open_preview", return_value=True) as open_preview,
            ):
                self.assertTrue(studio.reload_source_and_refresh())

            old_preview.close.assert_called_once_with()
            open_preview.assert_called_once_with()
            studio.preview = None
            studio.close()

    def test_source_refresh_rebuilds_scan_sample_from_reloaded_runtime_builder(self) -> None:
        from gui.viewer_components.home import HomeTabComponent

        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            entry_id = "section:homeScanSection"
            studio.select_entry(entry_id)
            original_builder = HomeTabComponent._build_home_scan_panel

            def marked_builder(component):
                section = original_builder(component)
                section.setProperty("hotReloadScanProbe", True)
                return section

            with (
                patch("tools.ui_component_studio._reload_visual_modules", return_value=("gui.viewer_components.home",)),
                patch.object(HomeTabComponent, "_build_home_scan_panel", marked_builder),
            ):
                self.assertTrue(studio.reload_source_and_refresh())

            self.assertTrue(studio.widgets[entry_id].property("hotReloadScanProbe"))
            studio.close()

    def test_source_refresh_rebuilds_item_sample_from_runtime_builder(self) -> None:
        from gui.viewer_components.home import HomeTabComponent

        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            entry_id = "section:homeItemCategorySection"
            studio.select_entry(entry_id)
            original_builder = HomeTabComponent._build_home_item_panel

            def marked_builder(component):
                section = original_builder(component)
                section.setProperty("hotReloadItemProbe", True)
                return section

            with (
                patch("tools.ui_component_studio._reload_visual_modules", return_value=("gui.viewer_components.home",)),
                patch.object(HomeTabComponent, "_build_home_item_panel", marked_builder),
            ):
                self.assertTrue(studio.reload_source_and_refresh())

            self.assertTrue(studio.widgets[entry_id].property("hotReloadItemProbe"))
            studio.close()

    def test_source_refresh_rebuilds_resource_sample_from_runtime_builder(self) -> None:
        from gui.viewer_components.home import HomeTabComponent

        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            entry_id = "section:homeResourcePromptSection"
            studio.select_entry(entry_id)
            original_builder = HomeTabComponent._build_home_resource_panel

            def marked_builder(component):
                section = original_builder(component)
                section.setProperty("hotReloadResourceProbe", True)
                return section

            with (
                patch("tools.ui_component_studio._reload_visual_modules", return_value=("gui.viewer_components.home",)),
                patch.object(HomeTabComponent, "_build_home_resource_panel", marked_builder),
            ):
                self.assertTrue(studio.reload_source_and_refresh())

            self.assertTrue(studio.widgets[entry_id].property("hotReloadResourceProbe"))
            studio.close()

    def test_visual_reload_discards_same_timestamp_same_size_bytecode(self) -> None:
        module_name = "ucs_same_second_reload_probe"
        with tempfile.TemporaryDirectory() as temp_dir:
            module_path = Path(temp_dir) / f"{module_name}.py"
            old_source = 'VALUE = "old"\n'
            new_source = 'VALUE = "new"\n'
            self.assertEqual(len(old_source), len(new_source))
            module_path.write_text(old_source, encoding="utf-8")
            fixed_timestamp = int(module_path.stat().st_mtime) - 2
            os.utime(module_path, (fixed_timestamp, fixed_timestamp))
            sys.path.insert(0, temp_dir)
            try:
                importlib.invalidate_caches()
                module = importlib.import_module(module_name)
                self.assertEqual(module.VALUE, "old")
                module_path.write_text(new_source, encoding="utf-8")
                os.utime(module_path, (fixed_timestamp, fixed_timestamp))

                with patch("tools.ui_component_studio._HOT_RELOAD_VISUAL_MODULES", (module_name,)):
                    self.assertEqual(_reload_visual_modules(reload_studio=False), (module_name,))

                self.assertEqual(module.VALUE, "new")
            finally:
                sys.modules.pop(module_name, None)
                sys.path.remove(temp_dir)

    def test_visual_reload_includes_running_studio_sample_factories(self) -> None:
        studio_module = sys.modules["tools.ui_component_studio"]
        with (
            patch("tools.ui_component_studio._HOT_RELOAD_VISUAL_MODULES", ()),
            patch("tools.ui_component_studio.importlib.reload", side_effect=lambda module: module) as reload_module,
        ):
            self.assertEqual(_reload_visual_modules(), ("tools.ui_component_studio",))

        reload_module.assert_called_once_with(studio_module)
        self.assertIs(sys.modules["tools.ui_component_studio"], studio_module)

    def test_gallery_separates_widgets_and_sections(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            self.assertEqual(studio.gallery_tabs.count(), 3)
            self.assertEqual(studio.gallery_tabs.tabText(0), "위젯")
            self.assertEqual(studio.gallery_tabs.tabText(1), "섹션")
            self.assertEqual(studio.gallery_tabs.tabText(2), "상태 머신")
            self.assertIn("section:homeMenuSection", studio.cards)
            self.assertIn("section:scanHeaderSection", studio.cards)
            self.assertGreater(studio.gallery_layouts["sections"].count(), 0)
            section_layout = studio.gallery_layouts["sections"]
            menu_position = section_layout.getItemPosition(section_layout.indexOf(studio.cards["section:homeMenuSection"]))
            connection_position = section_layout.getItemPosition(section_layout.indexOf(studio.cards["section:homeConnectionSection"]))
            scan_position = section_layout.getItemPosition(section_layout.indexOf(studio.cards["section:homeScanSection"]))
            self.assertEqual(menu_position, (0, 0, 1, 1))
            self.assertEqual(connection_position, (0, 1, 1, 1))
            self.assertEqual(scan_position, (1, 0, 1, 1))
            self.assertGreaterEqual(studio.widgets["section:homeSettingsSection"].minimumHeight(), 520)
            studio.close()

    def test_section_cards_show_distinct_ratio_preserving_runtime_thumbnails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            expected_ratios = {
                "section:scanHeaderSection": lambda ratio: ratio > 8.0,
                "section:scanStudentMirrorSection": lambda ratio: 1.0 < ratio < 2.5,
                "section:scanInventoryGridMirrorSection": lambda ratio: 1.0 < ratio < 2.5,
                "section:scanProgressSection": lambda ratio: ratio > 3.0,
                "section:scanPreviewSection": lambda ratio: abs(ratio - (16 / 9)) < 0.05,
            }
            source_sizes = set()
            for entry_id, ratio_check in expected_ratios.items():
                thumbnail = studio.cards[entry_id].thumbnail
                self.assertIsNotNone(thumbnail, entry_id)
                source = thumbnail.sourcePixmap()
                self.assertFalse(source.isNull(), entry_id)
                self.assertTrue(ratio_check(thumbnail.sourceAspectRatio()), entry_id)
                source_sizes.add((source.width(), source.height()))

                thumbnail.resize(540, 220)
                self.app.processEvents()
                displayed = thumbnail.pixmap()
                self.assertFalse(displayed.isNull(), entry_id)
                displayed_ratio = displayed.width() / displayed.height()
                relative_error = abs(displayed_ratio - thumbnail.sourceAspectRatio()) / thumbnail.sourceAspectRatio()
                self.assertLess(relative_error, 0.03, entry_id)

            self.assertGreaterEqual(len(source_sizes), 4)
            studio.close()

    def test_section_gallery_uses_real_section_surfaces(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            home_sample = studio.widgets["section:homeMenuSection"]
            scan_sample = studio.widgets["section:scanHeaderSection"]
            self.assertEqual(type(home_sample).__name__, "HomeGlassSection")
            self.assertEqual(type(scan_sample).__name__, "DiagonalScanFrame")
            self.assertIsNotNone(scan_sample.findChild(QWidget, "scanHeader"))
            studio.select_entry("section:scanHeaderSection")
            self.assertEqual(studio.gallery_tabs.currentIndex(), 1)
            studio.close()

    def test_section_selector_is_routed_to_section_gallery(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "ui_design_spec.json"
            selector = "QWidget/HomeGlassSection#homeConnectionSection"
            save_ui_design_spec(UIDesignSpec(components={selector: ComponentOverride(selector)}), path)
            studio = StudioWindow(path)
            entry_id = f"selector:{selector}"
            self.assertIn(entry_id, studio.cards)
            self.assertEqual(studio.gallery_layouts["sections"].indexOf(studio.cards[entry_id]) >= 0, True)
            studio.close()

    def test_image_gallery_uses_project_reference_assets(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            for entry_id in ("asset:squareImage", "asset:studentPortrait", "asset:resourceIcon"):
                self.assertIn(entry_id, studio.cards)
                preview = studio.widgets[entry_id].findChild(QLabel, "assetPreview")
                self.assertIsNotNone(preview)
                self.assertFalse(preview.pixmap().isNull())
            portrait = studio.widgets["asset:studentPortrait"].findChild(QLabel, "assetPreview")
            resource = studio.widgets["asset:resourceIcon"].findChild(QLabel, "assetPreview")
            self.assertTrue(portrait.toolTip().endswith("templates\\students_portraits\\seia.png"))
            self.assertTrue(resource.toolTip().endswith("templates\\icons\\ooparts\\Item_Icon_Material_Nebra_2.png"))
            studio.close()

    def test_gallery_contains_complete_planning_widget_catalog(self) -> None:
        expected = {
            "widget:studentCard", "widget:studentCompactRow", "widget:planStatusBadge",
            "widget:resourceRequirementRow", "widget:resourceProgressBar", "widget:metricCard",
            "widget:distributionBarChart", "widget:histogram", "widget:stackedBar",
            "widget:heatmap", "widget:scatterPlot", "widget:trendChart",
            "widget:dataFreshnessBadge", "widget:filterChipBar", "widget:sortMenu",
            "widget:viewModeToggle", "section:studentFilterBar", "section:studentGroupSelector",
            "section:trainingTargetEditor", "section:targetPresetSelector",
            "section:homeItemCategorySection", "section:homeResourcePromptSection",
            "section:trainingMilestoneEditor", "section:bulkTargetApplyPanel",
            "section:planGroupCard", "section:priorityList", "section:scenarioCompareCard",
            "section:resourceRequirementTable", "section:resourceUsagePanel",
            "section:resourceCategorySummary", "section:currentVsTargetPanel",
            "section:incrementalCostPanel", "section:bottleneckPanel",
            "section:conflictAlertPanel", "section:scanStatusCard", "section:anomalyList",
            "section:detailDrawer", "section:emptyState",
            "section:scanDebugSection", "section:scanMirrorSection",
            "section:scanStudentMirrorSection", "section:scanInventoryGridMirrorSection",
            "section:scanWorkSection", "section:scanProgressSection",
            "section:scanPreviewSection", "section:scanResultSection",
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            self.assertTrue(expected.issubset(studio.cards))
            for entry_id in expected:
                self.assertGreater(studio.widgets[entry_id].minimumWidth(), 0)
                self.assertGreater(studio.widgets[entry_id].minimumHeight(), 0)
            studio.close()

    def test_scan_runtime_sections_are_available_as_independent_previews(self) -> None:
        expected = {
            "section:scanDebugSection": "scanDebugSection",
            "section:scanMirrorSection": "scanMirrorSection",
            "section:scanStudentMirrorSection": "scanStudentCard",
            "section:scanInventoryGridMirrorSection": "scanInventoryCard",
            "section:scanWorkSection": "scanWorkSection",
            "section:scanProgressSection": "scanProgressSection",
            "section:scanPreviewSection": "scanPreviewSection",
            "section:scanResultSection": "scanResultSection",
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            for entry_id, object_name in expected.items():
                studio.select_entry(entry_id)
                self.assertTrue(studio.open_preview())
                self.app.processEvents()
                preview = studio.preview
                self.assertIsNotNone(preview._runtime_source, entry_id)
                self.assertEqual(preview.sample.objectName(), object_name, entry_id)
                self.assertTrue(preview._settled_geometry.isValid(), entry_id)
                if entry_id == "section:scanDebugSection":
                    self.assertIsNotNone(preview.sample.findChild(QLabel, "title"))
                    self.assertTrue(studio.selection_tree.findItems("QPlainTextEdit", Qt.MatchExactly | Qt.MatchRecursive, 0))
                if entry_id == "section:scanInventoryGridMirrorSection":
                    self.assertGreaterEqual(len(preview.sample.findChildren(QWidget, "scanInventorySlot")), 20)
                    self.assertTrue(studio.selection_tree.findItems("QFrame", Qt.MatchExactly | Qt.MatchRecursive, 0))
                if entry_id == "section:scanProgressSection":
                    self.assertIsNotNone(preview.sample.findChild(QProgressBar))
                    self.assertIsNotNone(preview.sample.findChild(QPushButton))
                if entry_id == "section:scanPreviewSection":
                    self.assertGreater(preview.sample.width(), preview.sample.height())
                preview.close()
                self.app.processEvents()
            studio.close()

    def test_state_machine_tab_covers_every_main_tab_and_section_structure(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            names = {studio.state_tab_combo.itemText(i) for i in range(studio.state_tab_combo.count())}
            self.assertEqual(names, {"전체 화면", "홈", "학생부", "계획", "필요 재화", "인벤토리", "전술대항전", "통계"})
            studio.gallery_tabs.setCurrentIndex(2)
            self.app.processEvents()
            studio.state_tab_combo.setCurrentText("홈")
            self.app.processEvents()
            self.assertGreater(studio.state_transition_table.rowCount(), 10)
            self.assertGreater(studio.state_audit_table.rowCount(), 0)
            self.assertEqual(studio.state_detail_tabs.count(), 3)
            self.assertEqual(studio.state_detail_tabs.tabText(0), "Markdown 문서")
            self.assertIsNotNone(studio.state_markdown_view)
            self.assertEqual(studio.state_markdown_view.current_path.name, "home.md")
            self.assertIn("homeMenuSection", studio.state_markdown_view.last_html)
            self.assertIn("mermaid.min.js", studio.state_markdown_view.last_html)
            markdown = studio.state_markdown_view.current_path.read_text(encoding="utf-8")
            self.assertIn("scanWorkSection", markdown)
            self.assertNotIn("_scan_stop_button", markdown)
            self.assertIn("커버리지", studio.state_coverage_label.text())
            studio.close()

    def test_every_state_tab_has_a_renderable_markdown_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            studio.gallery_tabs.setCurrentIndex(2)
            self.app.processEvents()
            for tab_name in ("전체 화면", "홈", "학생부", "계획", "필요 재화", "인벤토리", "전술대항전", "통계"):
                studio.state_tab_combo.setCurrentText(tab_name)
                self.app.processEvents()
                path = studio.state_markdown_view.current_path
                self.assertTrue(path.exists(), tab_name)
                markdown = path.read_text(encoding="utf-8")
                self.assertIn("```mermaid", markdown, tab_name)
                self.assertIn("flowchart TD", markdown, tab_name)
                self.assertNotIn("flowchart LR", markdown, tab_name)
                node_labels = re.findall(r"\[([^\]]+)\]", markdown)
                self.assertTrue(node_labels, tab_name)
                self.assertFalse(
                    [label for label in node_labels if re.search(r"[가-힣]", label)],
                    f"{tab_name}: Mermaid section node labels must use English identifiers",
                )
                self.assertIn('class="mermaid"', studio.state_markdown_view.last_html, tab_name)
            self.assertTrue(studio.copy_state_markdown_path())
            self.assertTrue(QApplication.clipboard().text().endswith("statistics.md"))
            studio.close()

    def test_state_machine_audit_exposes_unmapped_source_signals(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            studio.state_tab_combo.setCurrentText("계획")
            statuses = {
                studio.state_audit_table.item(row, 0).text()
                for row in range(studio.state_audit_table.rowCount())
            }
            self.assertIn("연결됨", statuses)
            studio.state_missing_only.setChecked(True)
            self.assertGreater(studio.state_transition_table.rowCount(), 0)
            self.assertTrue(all(
                studio.state_transition_table.item(row, 8).text() == "수동 확인 필요"
                for row in range(studio.state_transition_table.rowCount())
            ))
            studio.close()

    def test_behavior_stable_ids_are_unique_ascii_and_every_tab_is_audited(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            for tab_name in ("홈", "학생부", "계획", "필요 재화", "인벤토리", "전술대항전", "통계"):
                studio.state_tab_combo.setCurrentText(tab_name)
                ids = [
                    studio.state_transition_table.item(row, 0).text()
                    for row in range(studio.state_transition_table.rowCount())
                ]
                self.assertEqual(len(ids), len(set(ids)), tab_name)
                self.assertTrue(all(re.fullmatch(r"[a-z0-9_.]+", value) for value in ids), tab_name)
                self.assertGreater(studio.state_audit_table.rowCount(), 0, tab_name)
            studio.close()

    def test_selected_section_exposes_copyable_child_tree_path(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            studio.select_entry("section:homeSettingsSection")
            self.assertGreater(studio.selection_tree.topLevelItemCount(), 0)
            root = studio.selection_tree.topLevelItem(0)
            self.assertGreater(root.childCount(), 0)
            studio.selection_tree.setCurrentItem(root.child(0))
            self.assertIn("section:homeSettingsSection", studio.tree_path_edit.text())
            self.assertTrue(studio.copy_tree_instruction())
            self.assertIn("[변경할 내용]", QApplication.clipboard().text())
            studio.close()

    def test_chart_gallery_uses_dedicated_chart_canvases(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            expected_modes = {
                "widget:distributionBarChart": "bar",
                "widget:histogram": "histogram",
                "widget:stackedBar": "stacked",
                "widget:heatmap": "heatmap",
                "widget:scatterPlot": "scatter",
                "widget:trendChart": "trend",
            }
            for entry_id, mode in expected_modes.items():
                sample = studio.widgets[entry_id]
                self.assertEqual(type(sample).__name__, "GalleryChartCanvas")
                self.assertEqual(sample.mode, mode)
            studio.close()

    def test_feature_sample_keeps_base_style_when_gallery_qss_is_empty(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            sample = studio.widgets["widget:studentCard"]
            self.assertIn("background:", sample.styleSheet())
            studio.select_entry("widget:studentCard")
            studio.style_edit.setPlainText("border: 2px solid #abcdef;")
            studio.apply_properties()
            self.assertIn("background:", sample.styleSheet())
            self.assertIn("#abcdef", sample.styleSheet())
            studio.close()

    def test_standard_sections_do_not_emit_stylesheet_parse_warnings(self) -> None:
        messages: list[str] = []

        def handler(_message_type, _context, message) -> None:
            messages.append(message)

        previous = qInstallMessageHandler(handler)
        try:
            with tempfile.TemporaryDirectory() as temp_dir:
                studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
                studio.show()
                self.app.processEvents()
                for entry_id in ("section:standardPanel", "section:planBand", "section:statisticsPanel"):
                    studio.select_entry(entry_id)
                    studio.style_edit.setPlainText("border: 2px solid #abcdef;")
                    studio.apply_properties()
                self.app.processEvents()
                studio.close()
        finally:
            qInstallMessageHandler(previous)
        self.assertFalse([message for message in messages if "parse stylesheet" in message.lower()])

    def test_preview_uses_planner_size_and_complete_home_menu_subtree(self) -> None:
        from gui.viewer_components.home import ParallelogramActionButton

        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            studio.select_entry("section:homeMenuSection")
            self.assertTrue(studio.open_preview())
            preview = studio.preview
            self.assertIsInstance(preview, SectionPreviewWindow)
            self.assertEqual(preview.size().width(), 1920)
            self.assertEqual(preview.size().height(), 1080)
            self.assertEqual(preview.sample.geometry(), QRect(16, 235, 566, 817))
            self.assertIs(preview.sample.parentWidget(), preview.preview_host)
            self.assertFalse(preview.sample.grab().isNull())
            buttons = preview.sample.findChildren(ParallelogramActionButton)
            self.assertEqual(len(buttons), 7)
            self.assertTrue(all(button.accessibleName() for button in buttons))
            textured = {button.accessibleName(): button for button in buttons}
            self.assertFalse(textured["학생부 확인"]._texture.isNull())
            self.assertIsNotNone(textured["설정"]._triangle_texture)
            self.assertIsNotNone(preview.sample._lifted_shadow)
            preview.close()
            studio.close()

    def test_preview_uses_each_home_sections_actual_main_slot(self) -> None:
        expected = {
            "section:homeMenuSection": QRect(16, 235, 566, 817),
            "section:homeSettingsSection": QRect(449, 235, 566, 817),
            "section:homeConnectionSection": QRect(1338, 235, 566, 817),
            "section:homeScanSection": QRect(1338, 235, 566, 817),
            "section:homeItemCategorySection": QRect(449, 235, 566, 817),
            "section:homeResourcePromptSection": QRect(449, 235, 566, 817),
            "section:scanHeaderSection": QRect(16, 55, 1888, 166),
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            for entry_id, geometry in expected.items():
                studio.select_entry(entry_id)
                studio.open_preview()
                self.app.processEvents()
                self.assertEqual(studio.preview.sample.geometry(), geometry, entry_id)
                studio.preview.close()
                self.app.processEvents()
            studio.close()

    def test_preview_accumulates_distinct_regions_and_skips_only_exact_duplicates(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            studio.select_entry("section:standardPanel")
            self.assertTrue(studio.open_preview())
            preview = studio.preview
            first = preview.sample

            studio.select_entry("section:planBand")
            self.assertTrue(studio.open_preview())
            self.app.processEvents()

            self.assertIs(studio.preview, preview)
            self.assertEqual(preview.entry_ids, ("section:standardPanel", "section:planBand"))
            self.assertEqual(len(preview.samples), 2)
            newest = preview.sample
            self.assertIsNot(first, newest)
            overlap_point = preview._settled_geometries["section:planBand"].center()
            top_widget = preview.preview_host.childAt(overlap_point)
            while top_widget is not None and top_widget.parentWidget() is not preview.preview_host:
                top_widget = top_widget.parentWidget()
            self.assertIs(top_widget, newest)

            self.assertTrue(studio.open_preview())
            self.assertEqual(len(preview.samples), 2)
            self.assertIs(preview.sample_for("section:planBand"), newest)
            preview.close()
            studio.close()

    def test_preview_q_and_w_animate_all_accumulated_regions_together(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            studio.select_entry("section:homeMenuSection")
            studio.open_preview()
            preview = studio.preview
            studio.select_entry("section:homeConnectionSection")
            studio.open_preview()
            preview.show()
            self.app.processEvents()

            QTest.keyClick(preview, Qt.Key_W)
            self.assertTrue(preview._animating)
            QTest.qWait(preview.PULL_MS + preview.EXIT_MS + 80)
            self.assertTrue(all(sample.isHidden() for sample in preview.samples.values()))

            QTest.keyClick(preview, Qt.Key_Q)
            self.assertTrue(preview._animating)
            QTest.qWait(preview.ENTER_MS + preview.SETTLE_MS + 80)
            for entry_id, sample in preview.samples.items():
                self.assertFalse(sample.isHidden(), entry_id)
                self.assertEqual(sample.pos(), preview._settled_geometries[entry_id].topLeft(), entry_id)
            preview.close()
            studio.close()

    def test_scan_section_sample_matches_runtime_row_grouping_and_heights(self) -> None:
        from gui.viewer_components.home import HomeMenuButtonRow

        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            studio.select_entry("section:homeScanSection")
            rows = studio.widgets["section:homeScanSection"].findChildren(HomeMenuButtonRow)

            self.assertEqual(
                [[button.text() for button in row._buttons] for row in rows],
                [["학생", "단일"], ["아이템", "장비"], ["전술대항전"]],
            )
            self.assertEqual(
                [[button._cut_right for button in row._buttons] for row in rows],
                [[True, False], [True, False], [False]],
            )
            self.assertEqual(rows[0]._width_weights, [4.0, 1.0])
            buttons = [button for row in rows for button in row._buttons]
            section = studio.widgets["section:homeScanSection"]
            self.assertIsNotNone(section._lifted_shadow)
            self.assertTrue(all(button._triangle_texture is not None for button in buttons))
            self.assertTrue(all(button._lifted_shadow is not None for button in buttons))
            self.assertTrue(all(button._state_effects_enabled for button in buttons))
            connection = studio.widgets["section:homeConnectionSection"]
            scan = studio.widgets["section:homeScanSection"]
            for object_name in ("title", "count"):
                connection_label = connection.findChild(QLabel, object_name)
                scan_label = scan.findChild(QLabel, object_name)
                self.assertEqual(scan_label.font(), connection_label.font())
                self.assertEqual(
                    scan_label.palette().color(scan_label.foregroundRole()),
                    connection_label.palette().color(connection_label.foregroundRole()),
                )
            title = scan.findChild(QLabel, "title")
            count = scan.findChild(QLabel, "count")
            self.assertEqual(title.font().pixelSize(), 24)
            self.assertEqual(title.palette().color(title.foregroundRole()), QColor(INK))
            self.assertEqual(count.palette().color(count.foregroundRole()), QColor(MUTED))
            self.assertEqual([row.height() for row in rows], [108, 108, 54])
            studio.close()

    def test_every_section_catalog_entry_renders_in_preview(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            section_ids = [entry_id for entry_id, _title, _widget_type, category in studio._entries() if category == "sections"]
            self.assertGreaterEqual(len(section_ids), 30)
            for entry_id in section_ids:
                studio.select_entry(entry_id)
                self.assertTrue(studio.open_preview(), entry_id)
                self.app.processEvents()
                preview = studio.preview
                self.assertTrue(preview.sample.isVisible(), entry_id)
                self.assertFalse(preview.sample.geometry().intersected(preview.rect()).isEmpty(), entry_id)
                image = preview.grab().toImage()
                rect = preview.sample.geometry().intersected(image.rect())
                changed = any(
                    image.pixelColor(x, y).name().lower() != "#707070"
                    for y in range(rect.top(), rect.bottom() + 1, 16)
                    for x in range(rect.left(), rect.right() + 1, 16)
                )
                self.assertTrue(changed, entry_id)
                preview.close()
                self.app.processEvents()
            studio.close()

    def test_settings_preview_contains_the_complete_settings_subtree(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            studio.select_entry("section:homeSettingsSection")
            studio.open_preview()
            preview = studio.preview
            self.app.processEvents()
            self.assertIsNotNone(preview._runtime_source)
            for object_name in (
                "homeSettingsHeaderSurface",
                "homeSettingsProfileSurface",
                "homeSettingsWindowSurface",
                "homeSettingsSupportSurface",
            ):
                self.assertIsNotNone(preview.sample.findChild(QWidget, object_name), object_name)
            header = preview.sample.findChild(QWidget, "homeSettingsHeaderSurface")
            count_labels = header.findChildren(QLabel, "count", Qt.FindDirectChildrenOnly)
            self.assertEqual(len(count_labels), 2)
            target_label = count_labels[1]
            self.assertIsInstance(target_label, HomeElidedLabel)
            target_label.setFixedWidth(90)
            target_label.setFullText("연결된 Blue Archive 창: 아주 긴 창 제목")
            self.app.processEvents()
            self.assertTrue(target_label.text().endswith("…"))
            self.assertEqual(target_label.toolTip(), "연결된 Blue Archive 창: 아주 긴 창 제목")
            self.assertGreaterEqual(len(preview.sample.findChildren(QWidget)), 35)
            preview.close()
            studio.close()

    def test_connection_and_settings_preview_use_runtime_main_sections(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            for entry_id, object_name in (
                ("section:homeConnectionSection", "homeConnectionSection"),
                ("section:homeSettingsSection", "homeSettingsSection"),
            ):
                studio.select_entry(entry_id)
                studio.open_preview()
                self.app.processEvents()
                preview = studio.preview
                self.assertIsNotNone(preview._runtime_source, entry_id)
                self.assertEqual(preview.sample.objectName(), object_name)
                self.assertEqual(preview.sample.geometry(), preview._settled_geometry)
                preview.close()
                self.app.processEvents()
            studio.close()

    def test_preview_shortcuts_work_while_a_child_control_has_focus(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            studio.select_entry("section:homeSettingsSection")
            studio.open_preview()
            preview = studio.preview
            preview.show()
            self.app.processEvents()
            combo = preview.sample.findChild(QComboBox)
            self.assertIsNotNone(combo)
            combo.setFocus()
            self.app.processEvents()
            QTest.keyClick(combo, Qt.Key_W)
            self.assertTrue(preview._animating)
            QTest.qWait(preview.PULL_MS + preview.EXIT_MS + 80)
            self.assertTrue(preview.sample.isHidden())
            QTest.keyClick(preview, Qt.Key_Q)
            QTest.qWait(preview.ENTER_MS + preview.SETTLE_MS + 80)
            self.assertFalse(preview.sample.isHidden())
            self.assertEqual(preview.sample.pos(), preview._settled_geometry.topLeft())
            preview.close()
            studio.close()

    def test_connection_preview_allows_hover_feedback_but_blocks_actions(self) -> None:
        from gui.viewer_components.home import LeftExtendedActionButton

        windows = [{"hwnd": 22, "title": "Blue Archive", "size": "1920x1080"}]
        with tempfile.TemporaryDirectory() as temp_dir, patch(
            "gui.viewer_components.home.get_all_windows",
            return_value=windows,
        ):
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            studio.select_entry("section:homeConnectionSection")
            studio.open_preview()
            preview = studio.preview
            preview.show()
            self.app.processEvents()

            self.assertFalse(preview.sample.testAttribute(Qt.WA_TransparentForMouseEvents))
            window_list = preview.sample.findChild(QWidget, "homeWindowCandidateList")
            self.assertIsNotNone(window_list)
            self.assertGreater(window_list.count(), 0)
            item = window_list.item(0)
            host = window_list.diagonalHost(item)
            QTest.mouseMove(window_list.viewport(), window_list.visualItemRect(item).center())
            self.app.processEvents()
            self.assertTrue(host._hovered)

            refresh = preview.sample.findChild(LeftExtendedActionButton)
            self.assertIsNotNone(refresh)
            clicked = Mock()
            refresh.clicked.connect(clicked)
            QTest.mouseMove(refresh, refresh.rect().center())
            self.app.processEvents()
            self.assertTrue(refresh.underMouse())
            QTest.mouseClick(refresh, Qt.LeftButton, pos=refresh.rect().center())
            self.app.processEvents()
            clicked.assert_not_called()

            preview.close()
            self.app.processEvents()
            studio.close()

    def test_preview_q_and_w_play_intro_and_outro(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            studio.select_entry("section:homeMenuSection")
            studio.open_preview()
            preview = studio.preview
            preview.show()
            self.app.processEvents()
            settled = preview._settled_geometry.topLeft()
            QTest.keyClick(preview, Qt.Key_W)
            self.assertTrue(preview._animating)
            QTest.qWait(preview.PULL_MS + preview.EXIT_MS + 80)
            self.assertTrue(preview.sample.isHidden())
            QTest.keyClick(preview, Qt.Key_Q)
            self.assertTrue(preview._animating)
            self.assertNotEqual(preview.sample.pos(), settled)
            QTest.qWait(preview.ENTER_MS + preview.SETTLE_MS + 80)
            self.assertFalse(preview.sample.isHidden())
            self.assertEqual(preview.sample.pos(), settled)
            preview.close()
            studio.close()

    def test_gallery_style_is_saved_without_geometry_controls(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            studio = StudioWindow(Path(temp_dir) / "ui_design_spec.json")
            studio.select_entry("type:QPushButton")
            studio.style_edit.setPlainText("background: #123456; color: white;")
            self.assertTrue(studio.apply_properties())
            saved = load_ui_design_spec(studio.draft_path)
            self.assertIn("#123456", saved.gallery_styles["type:QPushButton"].style_sheet)
            self.assertFalse(hasattr(studio, "x_spin"))
            studio.close()

    def test_selector_card_edits_only_visual_fields(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "ui_design_spec.json"
            selector = "QWidget/QLabel#title"
            save_ui_design_spec(UIDesignSpec(components={
                selector: ComponentOverride(selector, geometry=[10, 20, 200, 50])
            }), path)
            studio = StudioWindow(path)
            studio.select_entry(f"selector:{selector}")
            studio.style_edit.setPlainText("color: #abcdef;")
            studio.shape_enabled_check.setChecked(True)
            studio.shape_depth_mode_combo.setCurrentText("fixed")
            studio.shape_depth_spin.setValue(18)
            studio.apply_properties()
            override = load_ui_design_spec(studio.draft_path).components[selector]
            self.assertEqual(override.geometry, [10, 20, 200, 50])
            self.assertEqual(override.style_sheet, "color: #abcdef;")
            self.assertEqual(override.diagonal_shape.depth, 18)
            studio.close()

    def test_confirm_commits_pending_gallery_qss(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "ui_design_spec.json"
            studio = StudioWindow(path)
            studio.select_entry("type:QLabel")
            studio.style_edit.setPlainText("font-weight: 700;")
            with patch("tools.ui_component_studio.UI_DESIGN_SPEC_PATH", path), patch(
                "tools.ui_component_studio.QMessageBox.information"
            ):
                studio.confirm()
            saved = load_ui_design_spec(path)
            self.assertEqual(saved.gallery_styles["type:QLabel"].style_sheet, "font-weight: 700;")
            studio.close()

    def test_render_toggle_keeps_the_component_layout_space(self) -> None:
        root = QWidget(); layout = QHBoxLayout(root)
        target = QLabel("target"); sibling = QLabel("sibling")
        target.setFixedSize(180, 60); sibling.setFixedSize(120, 60)
        layout.addWidget(target); layout.addWidget(sibling)
        root.show(); self.app.processEvents(); sibling_geometry = sibling.geometry()
        set_studio_rendering(target, False); self.app.processEvents()
        self.assertFalse(studio_rendering_enabled(target)); self.assertEqual(sibling.geometry(), sibling_geometry)
        set_studio_rendering(target, True); self.app.processEvents()
        self.assertTrue(studio_rendering_enabled(target)); root.close()


if __name__ == "__main__":
    unittest.main()
