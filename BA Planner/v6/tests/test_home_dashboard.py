from __future__ import annotations

import os
import math
import unittest
from unittest.mock import Mock, patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import QEvent, QPoint, QPointF, QRectF, Qt
from PySide6.QtTest import QTest
from PySide6.QtGui import QColor, QEnterEvent, QImage, QPainter, QPainterPath
from PySide6.QtWidgets import (
    QApplication,
    QFrame,
    QGraphicsDropShadowEffect,
    QLabel,
    QLineEdit,
    QPushButton,
    QStackedWidget,
    QTabWidget,
    QVBoxLayout,
    QWidget,
)

from gui.viewer_components.home import (
    HOME_CENTER_INTRO_ANGLE,
    HOME_CENTER_OUTRO_ANGLE,
    HOME_DIAGONAL_ANGLE,
    HOME_MENU_CAPTION_COLOR,
    HOME_MENU_CAPTION_RATIO,
    HOME_MENU_CAPTION_TEXT_COLOR,
    HOME_MENU_INTRO_ANGLE,
    HOME_MENU_OUTRO_ANGLE,
    HOME_MENU_SETTINGS_TEXT_COLOR,
    HOME_MENU_TEXTURE_OVERSCAN,
    HOME_MENU_TEXTURES,
    DiagonalMenuComboBox,
    DiagonalLineEdit,
    HomeButtonCaptionOverlay,
    HomeDashboardWidget,
    HomeGlassSection,
    HomeElidedLabel,
    HomeSectionHost,
    HomeTabComponent,
    LeftExtendedActionButton,
    LiftedShadowSpec,
    ParallelogramActionButton,
    _home_candidate_triangle_texture,
    _paint_lifted_shadow,
)
from gui.viewer_components.scan import ScanTabComponent
from gui.viewer_components.window import ViewerWindowComponent
from gui.viewer_shared import PALETTE_ACCENT, PALETTE_PANEL_ALT, SURFACE, _mix_hex


class HomeSectionHostTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.app = QApplication.instance() or QApplication([])

    def test_section_replacement_finishes_at_host_origin(self) -> None:
        host = HomeSectionHost()
        host.resize(420, 280)
        first = QWidget()
        second = QWidget()
        host.addPage(first, initial=True)
        host.addPage(second)
        host.show()

        host.transitionTo(second, intro=0.0, outro=180.0)
        QTest.qWait(1100)

        self.assertIs(host.currentPage(), second)
        self.assertFalse(first.isVisible())
        self.assertTrue(second.isVisible())
        self.assertEqual(second.pos().x(), 0)
        self.assertEqual(second.pos().y(), 0)

    def test_numeric_direction_contract_matches_screen_space_angles(self) -> None:
        host = HomeSectionHost()
        host.resize(420, 280)

        intro = host._offset(0.0)
        outro = host._offset(180.0)
        up = host._offset(90.0)
        down = host._offset(270.0)
        diagonal_intro = host._offset(80.0)
        diagonal_outro = host._offset(260.0)

        self.assertGreater(intro.x(), 0)
        self.assertEqual(intro.y(), 0)
        self.assertLess(outro.x(), 0)
        self.assertEqual(outro.y(), 0)
        self.assertEqual(up.x(), 0)
        self.assertLess(up.y(), 0)
        self.assertEqual(down.x(), 0)
        self.assertGreater(down.y(), 0)
        for offset, angle in ((diagonal_intro, 80.0), (diagonal_outro, 260.0)):
            radians = math.radians(angle)
            cross = (offset.x() * -math.sin(radians)) - (offset.y() * math.cos(radians))
            self.assertAlmostEqual(cross, 0.0, delta=1.5)

    def test_menu_refresh_defaults_to_intro_zero_and_outro_one_eighty(self) -> None:
        host = HomeSectionHost()
        page = QWidget()
        host.addPage(page, initial=True)
        host.transitionTo = Mock()

        callback = Mock()
        host.refreshCurrent(callback)

        host.transitionTo.assert_called_once_with(page, intro=0.0, outro=180.0, midpoint=callback)

    def test_menu_refresh_exits_left_before_entering_rightward_from_left(self) -> None:
        host = HomeSectionHost()
        host.resize(420, 280)
        page = QWidget()
        host.addPage(page, initial=True)
        host.show()
        midpoint = Mock()

        host.refreshCurrent(
            midpoint,
            intro=HOME_MENU_INTRO_ANGLE,
            outro=HOME_MENU_OUTRO_ANGLE,
        )
        QTest.qWait(HomeSectionHost.PULL_MS + HomeSectionHost.EXIT_MS - 35)
        self.assertFalse(midpoint.called)
        self.assertLess(page.x(), 0)

        QTest.qWait(70)
        self.assertTrue(midpoint.called)
        self.assertLess(page.x(), 0)
        QTest.qWait(HomeSectionHost.ENTER_MS + HomeSectionHost.SETTLE_MS)
        self.assertEqual(page.pos(), QPoint(0, 0))

    def test_central_sections_follow_eighty_degree_motion_from_bottom_right_anchor(self) -> None:
        host = HomeSectionHost()
        host.resize(420, 280)
        intro_start = -host._offset(HOME_CENTER_INTRO_ANGLE)
        outro_end = host._offset(HOME_CENTER_OUTRO_ANGLE)

        self.assertAlmostEqual(intro_start.x(), outro_end.x(), delta=1)
        self.assertAlmostEqual(intro_start.y(), outro_end.y(), delta=1)
        self.assertLess(intro_start.x(), 0)
        self.assertGreater(intro_start.y(), 0)

        self.assertGreaterEqual(intro_start.y(), host.height() + 40)
        motion = -intro_start
        radians = math.radians(HOME_CENTER_INTRO_ANGLE)
        cross = (motion.x() * -math.sin(radians)) - (motion.y() * math.cos(radians))
        self.assertAlmostEqual(cross, 0.0, delta=1.5)
        self.assertGreater(motion.x(), 0)
        self.assertLess(motion.y(), 0)

    def test_center_transition_uses_outgoing_and_incoming_panel_motion_independently(self) -> None:
        component = object.__new__(HomeTabComponent)
        outgoing = QWidget()
        incoming = QWidget()
        component._home_center_host = Mock()
        component._home_center_host.currentPage.return_value = outgoing
        component._home_center_motion_by_page = {
            outgoing: (11.0, 22.0),
            incoming: (33.0, 44.0),
        }

        component._home_transition_center(incoming)

        component._home_center_host.transitionTo.assert_called_once_with(
            incoming,
            intro=33.0,
            outro=22.0,
        )

    def test_central_transition_frames_move_down_left_out_and_up_right_in(self) -> None:
        host = HomeSectionHost()
        host.resize(420, 280)
        outgoing = QWidget()
        incoming = QWidget()
        host.addPage(outgoing, initial=True)
        host.addPage(incoming)
        host.show()

        host.transitionTo(
            incoming,
            intro=HOME_CENTER_INTRO_ANGLE,
            outro=HOME_CENTER_OUTRO_ANGLE,
        )
        QTest.qWait(HomeSectionHost.PULL_MS + HomeSectionHost.EXIT_MS - 35)
        self.assertLess(outgoing.x(), 0)
        self.assertGreater(outgoing.y(), 0)

        QTest.qWait(70)
        intro_sample = QPoint(incoming.pos())
        self.assertLess(intro_sample.x(), 0)
        self.assertGreater(intro_sample.y(), 0)
        QTest.qWait(160)
        self.assertGreater(incoming.x(), intro_sample.x())
        self.assertLess(incoming.y(), intro_sample.y())
        QTest.qWait(HomeSectionHost.ENTER_MS + HomeSectionHost.SETTLE_MS)
        self.assertEqual(incoming.pos(), QPoint(0, 0))

    def test_main_tab_animation_keeps_incoming_header_stationary(self) -> None:
        class Harness(QWidget, HomeTabComponent):
            pass

        harness = Harness()
        harness._ui_scale = 1.0
        tabs = QTabWidget(harness)
        tabs.resize(640, 420)
        harness.resize(640, 420)
        harness._main_tabs = tabs

        pages: list[tuple[QWidget, QFrame, QFrame]] = []
        for name in ("first", "second"):
            page = QWidget()
            layout = QVBoxLayout(page)
            header = QFrame()
            header.setObjectName("header")
            header.setFixedHeight(72)
            header_layout = QVBoxLayout(header)
            header_layout.addWidget(QLabel(name))
            body = QFrame()
            body.setObjectName("panel")
            layout.addWidget(header)
            layout.addWidget(body, 1)
            tabs.addTab(page, name)
            pages.append((page, header, body))

        harness.show()
        tabs.show()
        self.app.processEvents()
        harness._capture_outgoing_main_tab()
        tabs.setCurrentIndex(1)
        self.app.processEvents()
        incoming_header = pages[1][1]
        incoming_body = pages[1][2]
        header_position = incoming_header.pos()
        incoming_body_rect, _ = harness._tab_transition_parts(pages[1][0])
        incoming_final_pos = pages[1][0].mapTo(tabs, incoming_body_rect.topLeft())

        harness._home_tab = pages[1][0]
        harness._animate_main_tab_change(1)
        self.app.processEvents()

        self.assertTrue(incoming_header.isVisible())
        self.assertEqual(incoming_header.pos(), header_position)
        self.assertTrue(incoming_body.isVisible())
        self.assertEqual(incoming_body.graphicsEffect().opacity(), 0.0)
        self.assertEqual(harness._main_tab_incoming_overlay.x(), incoming_final_pos.x())
        self.assertGreater(harness._main_tab_incoming_overlay.y(), incoming_final_pos.y())
        QTest.qWait(1100)
        self.assertTrue(incoming_body.isVisible())
        self.assertIsNone(incoming_body.graphicsEffect())
        self.assertEqual(incoming_header.pos(), header_position)
        harness.deleteLater()

    def test_home_studio_layout_preview_opens_workspace_and_switches_existing_stack(self) -> None:
        component = object.__new__(HomeTabComponent)
        component._home_root_stack = QStackedWidget()
        dashboard = QWidget()
        workspace = QWidget()
        component._home_root_stack.addWidget(dashboard)
        component._home_root_stack.addWidget(workspace)
        component._home_root_stack.setCurrentWidget(dashboard)
        component._home_scan_workspace_page = workspace
        component._reset_scan_result_transition = Mock()
        component._reset_scan_inventory_card = Mock()
        component._reset_scan_student_card = Mock()
        component._set_plana_message = Mock()
        component._animate_home_scan_workspace_in = Mock()

        component._show_home_scan_layout_preview("inventory")
        component._reset_scan_inventory_card.assert_called_once_with(
            "디버그",
            "그리드 스캔 레이아웃 미리보기",
            5,
            4,
        )
        self.assertIs(component._home_root_stack.currentWidget(), workspace)
        component._animate_home_scan_workspace_in.assert_called_once_with()

        component._show_home_scan_layout_preview("student")
        component._reset_scan_student_card.assert_called_once_with(meta="학생 스캔 레이아웃 미리보기")
        component._animate_home_scan_workspace_in.assert_called_once_with()

    def test_settings_header_and_components_follow_section_diagonal_menu_boundary(self) -> None:
        class Harness(QWidget, HomeTabComponent, ScanTabComponent):
            pass

        harness = Harness()
        harness._ui_scale = 1.0
        harness._refresh_settings_profiles = Mock()
        harness._sync_settings_labels = Mock()
        section = harness._build_home_settings_panel()
        section.resize(560, 720)
        section.show()
        self.app.processEvents()

        self.assertTrue(section._round_extension_corners)
        component_rows = harness._home_settings_component_rows
        component_layout = harness._home_settings_component_layout
        self.assertEqual(len(component_rows), 4)
        self.assertTrue(all(row._cut_right for row in component_rows))
        self.assertTrue(all(row._extend_left > 0 for row in component_rows))
        self.assertTrue(all(row._round_extension_corners for row in component_rows))
        self.assertTrue(all(row._angle_degrees == HOME_DIAGONAL_ANGLE for row in component_rows))
        self.assertTrue(all(row._radius == 7 for row in component_rows))
        self.assertTrue(all(left.x() > right.x() for left, right in zip(component_rows, component_rows[1:])))
        for row in component_rows:
            section_y = component_layout.mapTo(section, QPoint(0, row.y())).y()
            section_bottom_y = section_y + row.height()
            expected_left_top = section.leftEdgeXAt(section_y)
            expected_left_bottom = section.leftEdgeXAt(section_bottom_y)
            expected_right_top = component_layout.width() - (section.width() - section.rightEdgeXAt(section_y))
            expected_right_bottom = component_layout.width() - (
                section.width() - section.rightEdgeXAt(section_bottom_y)
            )
            row_extension = row.leftExtensionDepth()
            self.assertAlmostEqual(row.x() + row_extension, expected_left_top, delta=1.0)
            self.assertAlmostEqual(row.x(), expected_left_bottom, delta=1.0)
            self.assertAlmostEqual(row.x() + row.width(), expected_right_top, delta=1.0)
            self.assertAlmostEqual(row.x() + row.width() - row_extension, expected_right_bottom, delta=1.0)
        self.assertEqual(harness._settings_disconnect_button.text(), "연결 해제")
        self.assertIsInstance(harness._settings_target_label, HomeElidedLabel)
        harness._settings_target_label.resize(90, 24)
        harness._settings_target_label.setFullText("선택된 BA 창: 아주 긴 Blue Archive 창 제목")
        self.app.processEvents()
        self.assertTrue(harness._settings_target_label.text().endswith("…"))
        self.assertEqual(
            harness._settings_target_label.toolTip(),
            "선택된 BA 창: 아주 긴 Blue Archive 창 제목",
        )
        self.assertEqual(len(harness._home_settings_menu_rows), 5)
        first_row = harness._home_settings_menu_rows[0]
        self.assertEqual([button._extend_left for button in first_row._buttons], [True, True])
        self.assertTrue(all(button._extend_left for row in harness._home_settings_menu_rows for button in row._buttons))
        settings_buttons = [button for row in harness._home_settings_menu_rows for button in row._buttons]
        expected_header_fill = QColor(_mix_hex(PALETTE_ACCENT, PALETTE_PANEL_ALT, 0.62))
        self.assertTrue(all(button._fill == expected_header_fill for button in settings_buttons))
        self.assertEqual(len(harness._home_settings_control_slots), 6)
        for slot in harness._home_settings_control_slots:
            slot.syncControlGeometry()
            control = slot.control()
            left_top, left_bottom, right_top, right_bottom = slot.boundaryEndpoints()
            slant = control._diagonal_slant() if isinstance(control, DiagonalMenuComboBox) else control.diagonalSlant()
            self.assertGreater(control.width(), slot.width())
            self.assertAlmostEqual(control.x() + slant, left_top, delta=1.0)
            self.assertAlmostEqual(control.x(), left_bottom, delta=1.0)
            self.assertAlmostEqual(control.x() + control.width(), right_top, delta=1.0)
            self.assertAlmostEqual(control.x() + control.width() - slant, right_bottom, delta=1.0)
        self.assertTrue(all(button._angle_degrees == HOME_DIAGONAL_ANGLE for button in first_row._buttons))
        self.assertTrue(all(button._radius == 7 for button in first_row._buttons))
        first, second = first_row._buttons
        slant = first._diagonal_slant(first.width(), first.height())
        top_gap = (second.x() + slant) - (first.x() + first.width())
        bottom_gap = second.x() - (first.x() + first.width() - slant)
        self.assertAlmostEqual(top_gap, 8.0, delta=1.5)
        self.assertAlmostEqual(bottom_gap, 8.0, delta=1.5)
        profile_button_controls = [slot.control() for slot in harness._home_settings_control_slots[1:4]]
        vertical_gaps = [
            lower.y() - (upper.y() + upper.height())
            for upper, lower in zip(profile_button_controls, profile_button_controls[1:])
        ]
        self.assertTrue(all(abs(gap - harness._home_settings_group_gap) <= 1 for gap in vertical_gaps))
        self.assertTrue(all(abs(gap - top_gap) <= 1.5 for gap in vertical_gaps))
        self.assertTrue(all(abs(gap - bottom_gap) <= 1.5 for gap in vertical_gaps))
        self.assertEqual(HOME_CENTER_INTRO_ANGLE, 80.0)
        self.assertEqual(HOME_CENTER_OUTRO_ANGLE, 260.0)
        section.deleteLater()

    def test_settings_profile_uses_native_model_with_custom_diagonal_dropdown(self) -> None:
        class Harness(QWidget, HomeTabComponent, ScanTabComponent):
            pass

        harness = Harness()
        harness._ui_scale = 1.0
        harness._refresh_settings_profiles = Mock()
        harness._sync_settings_labels = Mock()
        section = harness._build_home_settings_panel()
        section.resize(620, 720)
        section.show()
        self.app.processEvents()

        combo = harness._settings_profile_combo
        self.assertIsInstance(combo, DiagonalMenuComboBox)
        self.assertEqual(combo.accessibleName(), "프로필 선택")
        self.assertNotIn("}}", combo.view().styleSheet())
        combo.addItems(["Default", "Second"])
        combo.setCurrentIndex(1)
        self.assertEqual(combo.currentText(), "Second")
        self.assertFalse(combo.surfacePath().contains(QPointF(0.0, 0.0)))
        self.assertTrue(combo.surfacePath().contains(QPointF(combo.width() / 2.0, combo.height() / 2.0)))

        rendered = QImage(combo.size(), QImage.Format_ARGB32_Premultiplied)
        rendered.fill(0)
        combo.render(rendered)
        self.assertEqual(rendered.pixelColor(0, 0).alpha(), 0)
        self.assertGreater(rendered.pixelColor(combo.width() // 2, combo.height() // 2).alpha(), 0)
        combo.showPopup()
        self.app.processEvents()
        self.assertTrue(combo.view().isVisible())
        combo.hidePopup()
        section.deleteLater()

    def test_settings_components_use_texture_and_lifted_shadow_but_buttons_do_not(self) -> None:
        class Harness(QWidget, HomeTabComponent, ScanTabComponent):
            pass

        harness = Harness()
        harness._ui_scale = 1.0
        harness._refresh_settings_profiles = Mock()
        harness._sync_settings_labels = Mock()
        section = harness._build_home_settings_panel()
        section.resize(620, 720)
        section.show()
        self.app.processEvents()

        surfaces = [
            section.findChild(HomeGlassSection, name)
            for name in (
                "homeSettingsHeaderSurface",
                "homeSettingsProfileSurface",
                "homeSettingsWindowSurface",
                "homeSettingsSupportSurface",
            )
        ]
        self.assertTrue(all(surface is not None and surface._triangle_texture is not None for surface in surfaces))
        self.assertIsNotNone(section._lifted_shadow)
        self.assertTrue(all(surface._lifted_shadow is section._lifted_shadow for surface in surfaces))
        buttons = [button for row in harness._home_settings_menu_rows for button in row._buttons]
        self.assertTrue(buttons)
        self.assertTrue(all(button._triangle_texture is None for button in buttons))
        self.assertTrue(all(button._lifted_shadow is None for button in buttons))
        self.assertIsNotNone(harness._settings_profile_combo._triangle_texture)
        section.deleteLater()

    def test_scan_and_item_menus_follow_projected_diagonal_rows(self) -> None:
        component = object.__new__(HomeTabComponent)
        component._ui_scale = 1.0
        component._home_start_scan = Mock()
        base_font_size = QPushButton().font().pointSizeF()

        scan = component._build_home_scan_panel()
        item = component._build_home_item_panel()
        scan.resize(420, 620)
        item.resize(420, 620)
        scan.show()
        item.show()
        self.app.processEvents()

        self.assertEqual([len(row._buttons) for row in component._home_scan_menu_rows], [2, 2, 1])
        self.assertEqual(component._home_scan_menu_rows[0]._buttons[0].text(), "학생")
        self.assertEqual(component._home_scan_menu_rows[0]._buttons[1].text(), "단일")
        self.assertEqual(component._home_scan_menu_rows[1]._buttons[0].text(), "아이템")
        self.assertEqual(component._home_scan_menu_rows[1]._buttons[1].text(), "장비")
        self.assertEqual(component._home_scan_menu_rows[2]._buttons[0].text(), "전술대항전")
        self.assertEqual(
            [[button._cut_right for button in row._buttons] for row in component._home_scan_menu_rows],
            [[True, False], [True, False], [False]],
        )
        scan_buttons = [button for row in component._home_scan_menu_rows for button in row._buttons]
        self.assertTrue(all(math.isclose(button.font().pointSizeF(), base_font_size * 1.2) for button in scan_buttons))
        self.assertIs(scan._lifted_shadow, component._home_scan_section_shadow)
        self.assertTrue(all(button._lifted_shadow is component._home_scan_button_shadow for button in scan_buttons))
        self.assertTrue(all(button._triangle_texture is not None for button in scan_buttons))
        self.assertEqual([button._triangle_texture.random_seed for button in scan_buttons], [9101, 9102, 9103, 9104, 9105])
        for button, seed in zip(scan_buttons, (9101, 9102, 9103, 9104, 9105)):
            expected_texture = _home_candidate_triangle_texture(
                button._triangle_texture.base_color,
                random_seed=seed,
            ).normalized()
            self.assertEqual(button._triangle_texture, expected_texture)
        self.assertTrue(all(button._triangle_texture_only for button in scan_buttons))
        self.assertTrue(all(button._state_effects_enabled for button in scan_buttons))
        student, single_student = component._home_scan_menu_rows[0]._buttons
        self.assertAlmostEqual(student.width() / single_student.width(), 4.0, delta=0.08)
        normal = QImage(student.size(), QImage.Format_ARGB32_Premultiplied)
        normal.fill(0)
        student.render(normal)
        hover_point = QPointF(student.width() * 0.25, student.height() * 0.25)
        QApplication.sendEvent(student, QEnterEvent(hover_point, hover_point, hover_point))
        self.app.processEvents()
        hovered = QImage(student.size(), QImage.Format_ARGB32_Premultiplied)
        hovered.fill(0)
        student.render(hovered)
        self.assertTrue(student.underMouse())
        sample = QPoint(round(hover_point.x()), round(hover_point.y()))
        self.assertNotEqual(normal.pixelColor(sample), hovered.pixelColor(sample))
        QApplication.sendEvent(student, QEvent(QEvent.Leave))
        self.app.processEvents()
        self.assertFalse(student.underMouse())
        for button in (single_student, component._home_scan_menu_rows[1]._buttons[1], component._home_scan_menu_rows[2]._buttons[0]):
            self.assertTrue(button.surfacePath().contains(QPointF(button.width() - 1, button.height() / 2.0)))
        self.assertEqual([row.height() for row in component._home_scan_menu_rows], [108, 108, 54])
        self.assertEqual([slot.height() for slot in component._home_scan_control_slots], [108, 108, 54])
        component._home_scan_menu_rows[0]._buttons[1].click()
        component._home_start_scan.assert_called_once_with("student_current")
        self.assertEqual([len(row._buttons) for row in component._home_item_menu_rows], [2, 2, 2])
        item_buttons = [button for row in component._home_item_menu_rows for button in row._buttons]
        self.assertTrue(all(math.isclose(button.font().pointSizeF(), base_font_size * 1.2) for button in item_buttons))
        self.assertTrue(all(button._fill == QColor(SURFACE) for button in item_buttons))
        self.assertTrue(all(button._triangle_texture.base_color == SURFACE for button in item_buttons))
        self.assertIs(item._lifted_shadow, component._home_item_section_shadow)
        self.assertTrue(all(button._lifted_shadow is component._home_item_button_shadow for button in item_buttons))
        self.assertEqual([button._triangle_texture.random_seed for button in item_buttons], [9201, 9202, 9203, 9204, 9205, 9206])
        for button, seed in zip(item_buttons, range(9201, 9207)):
            expected_texture = _home_candidate_triangle_texture(
                button._triangle_texture.base_color,
                random_seed=seed,
            ).normalized()
            self.assertEqual(button._triangle_texture, expected_texture)
        self.assertTrue(all(button._triangle_texture_only for button in item_buttons))
        self.assertTrue(all(button._reserve_shadow_inset for button in item_buttons))
        self.assertEqual([row.height() for row in component._home_item_menu_rows], [108, 108, 108])
        self.assertEqual([slot.height() for slot in component._home_item_control_slots], [108, 108, 108])
        self.assertTrue(scan._round_extension_corners)
        self.assertTrue(item._round_extension_corners)
        self.assertTrue(all(slot.boundaryEndpoints()[0] > slot.boundaryEndpoints()[1] for slot in component._home_scan_control_slots))
        scan.deleteLater()
        item.deleteLater()

    def test_item_panel_interlocks_with_scan_panel_when_docked_right(self) -> None:
        dashboard = HomeDashboardWidget(ui_scale=1.0)
        menu_host = HomeSectionHost(dashboard)
        center_host = HomeSectionHost(dashboard)
        right_host = HomeSectionHost(dashboard)
        dashboard.setHosts(menu_host, center_host, right_host)
        menu = HomeGlassSection(fill="#334155", radius=7, cut_right=True)
        item = HomeGlassSection(
            fill="#475569",
            radius=7,
            cut_right=True,
            extend_left=30,
            round_extension_corners=True,
        )
        scan = HomeGlassSection(
            fill="#526178",
            radius=7,
            extend_left=30,
            round_extension_corners=True,
        )
        menu_host.addPage(menu, initial=True)
        center_host.addPage(item, initial=True)
        right_host.addPage(scan, initial=True)
        dashboard.setCenterDock("right")
        dashboard.resize(1200, 720)
        dashboard.show()
        self.app.processEvents()

        for y in (24, 360, 696):
            item_edge = center_host.x() + item.rightEdgeXAt(y)
            scan_edge = right_host.x() + scan.leftEdgeXAt(y)
            self.assertAlmostEqual(scan_edge - item_edge, dashboard.seamGap(), delta=1.0)
        dashboard.deleteLater()

    def test_resource_prompt_projects_cut_inputs_and_actions_along_parent_edge(self) -> None:
        component = object.__new__(HomeTabComponent)
        component._ui_scale = 1.0
        component._home_save_manual_resources = Mock()
        component._home_cancel_resource_prompt = Mock()

        section = component._build_home_resource_panel()
        section.resize(566, 817)
        section.show()
        self.app.processEvents()

        inputs = (component._home_credit_input, component._home_pyroxene_input)
        self.assertTrue(section._round_extension_corners)
        self.assertIs(section._lifted_shadow, component._home_resource_section_shadow)
        self.assertTrue(all(isinstance(line_edit, DiagonalLineEdit) for line_edit in inputs))
        self.assertTrue(
            all(line_edit._lifted_shadow is component._home_resource_input_shadow for line_edit in inputs)
        )
        for line_edit in inputs:
            self.assertGreater(line_edit.cutDepth(), 0.0)
            path = line_edit.surfacePath()
            self.assertGreater(line_edit.interactionPath().boundingRect().width(), path.boundingRect().width())
            self.assertTrue(
                path.contains(QPointF(line_edit.width() - line_edit.cutDepth() - 3, line_edit.height() * 0.25))
            )
            self.assertFalse(path.contains(QPointF(line_edit.width() - 2, line_edit.height() - 2)))

        self.assertEqual(
            [label.accessibleName() for label in component._home_resource_icon_labels],
            ["크레딧", "청휘석"],
        )
        self.assertTrue(all(label.pixmap() is not None and not label.pixmap().isNull() for label in component._home_resource_icon_labels))
        self.assertTrue(all(max(label.pixmap().width(), label.pixmap().height()) == 33 for label in component._home_resource_icon_labels))

        self.assertEqual(len(component._home_resource_control_slots), 3)
        for slot in component._home_resource_control_slots:
            top_y = slot.mapTo(section, QPoint(0, 0)).y()
            right_top = slot.boundaryEndpoints()[2]
            self.assertAlmostEqual(section.rightEdgeXAt(top_y) - right_top, 24.0, delta=1.0)

        confirm = component._home_resource_confirm_button
        cancel = component._home_resource_cancel_button
        self.assertIsInstance(cancel, ParallelogramActionButton)
        self.assertTrue(cancel._cut_right)
        self.assertFalse(cancel._extend_left)
        self.assertLess(confirm.geometry().right(), cancel.geometry().left())
        confirm.click()
        cancel.click()
        component._home_save_manual_resources.assert_called_once_with()
        component._home_cancel_resource_prompt.assert_called_once_with()
        section.deleteLater()

    def test_dashboard_interlocks_menu_and_settings_bevels_with_constant_gap(self) -> None:
        dashboard = HomeDashboardWidget(ui_scale=1.0)
        menu_host = HomeSectionHost(dashboard)
        center_host = HomeSectionHost(dashboard)
        right_host = HomeSectionHost(dashboard)
        dashboard.setHosts(menu_host, center_host, right_host)
        menu = HomeGlassSection(fill="#334155", radius=7, cut_right=True)
        settings = HomeGlassSection(
            fill="#475569",
            radius=7,
            cut_right=True,
            extend_left=30,
            round_extension_corners=True,
        )
        menu_host.addPage(menu, initial=True)
        center_host.addPage(settings, initial=True)
        dashboard.resize(1200, 720)
        dashboard.show()
        self.app.processEvents()

        for y in (24, 360, 696):
            menu_edge = menu_host.x() + menu.rightEdgeXAt(y)
            settings_edge = center_host.x() + settings.leftEdgeXAt(y)
            self.assertAlmostEqual(settings_edge - menu_edge, dashboard.seamGap(), delta=1.0)
        self.assertLess(center_host.x(), menu_host.geometry().right())
        dashboard.deleteLater()

    def test_outro_snapshot_can_render_beyond_the_rectangular_host(self) -> None:
        dashboard = QWidget()
        dashboard.resize(900, 600)
        host = HomeSectionHost(dashboard)
        host.setGeometry(240, 120, 360, 360)
        page = HomeGlassSection(
            fill="#475569",
            radius=7,
            cut_right=True,
            extend_left=30,
            round_extension_corners=True,
        )
        host.addPage(page, initial=True)
        dashboard.show()
        self.app.processEvents()

        host.transitionTo(None, outro=0.0)
        QTest.qWait(70)

        self.assertEqual(len(host._animation_overlays), 1)
        overlay = host._animation_overlays[0]
        self.assertIs(overlay.parentWidget(), dashboard)
        self.assertLess(overlay.x(), host.x())
        self.assertGreater(overlay.pixmap().toImage().pixelColor(12, overlay.height() - 18).alpha(), 0)
        host.stopTransition()
        dashboard.deleteLater()

    def test_disconnected_primary_action_introduces_connection_panel_at_one_eighty(self) -> None:
        component = object.__new__(HomeTabComponent)
        component._home_connected = False
        component._home_center_host = Mock()
        component._home_right_host = Mock()
        component._home_connection_panel = QWidget()
        component._refresh_home_window_candidates = Mock()

        component._home_primary_action()

        component._refresh_home_window_candidates.assert_called_once_with()
        component._home_right_host.transitionTo.assert_called_once_with(
            component._home_connection_panel,
            intro=180.0,
            outro=0.0,
        )
        component._home_connection_panel.deleteLater()

    def test_scan_action_closes_scan_panel_when_pressed_again(self) -> None:
        component = object.__new__(HomeTabComponent)
        component._home_connected = True
        component._home_scan_panel = QWidget()
        component._home_center_host = Mock()
        component._home_right_host = Mock()
        component._home_right_host.currentPage.return_value = component._home_scan_panel
        component._home_center_motion_by_page = {}

        component._home_primary_action()

        component._home_right_host.transitionTo.assert_called_once_with(None, intro=180.0, outro=0.0)
        component._home_scan_panel.deleteLater()

    def test_settings_action_closes_settings_panel_when_pressed_again(self) -> None:
        component = object.__new__(HomeTabComponent)
        component._home_settings_panel = QWidget()
        component._home_center_host = Mock()
        component._home_center_host.currentPage.return_value = component._home_settings_panel
        component._home_transition_center = Mock()
        component._refresh_settings_profiles = Mock()
        component._home_right_host = Mock()

        component._home_show_settings()

        component._home_transition_center.assert_called_once_with(None)
        component._refresh_settings_profiles.assert_not_called()
        component._home_right_host.transitionTo.assert_not_called()
        component._home_settings_panel.deleteLater()

    def test_connection_section_rounds_the_exposed_extension_vertices(self) -> None:
        section = HomeGlassSection(
            fill="#7f8fa6",
            radius=12,
            extend_left=30,
            round_extension_corners=True,
        )
        section.resize(320, 220)
        rendered = QImage(section.size(), QImage.Format_ARGB32_Premultiplied)
        rendered.fill(0)
        section.render(rendered)

        extension = round(section.leftExtensionDepth())
        for x, y in ((extension, 0), (319, 0), (319, 219), (0, 219)):
            self.assertEqual(rendered.pixelColor(x, y).alpha(), 0)
        self.assertGreater(rendered.pixelColor(extension + 10, 12).alpha(), 0)
        self.assertGreater(rendered.pixelColor(12, 207).alpha(), 0)
        section.deleteLater()

    def test_connection_section_extension_edge_stays_at_eighty_degrees(self) -> None:
        section = HomeGlassSection(
            fill="#7f8fa6",
            radius=12,
            extend_left=30,
            angle_degrees=HOME_DIAGONAL_ANGLE,
            round_extension_corners=True,
        )

        for height in (220, 420, 620):
            section.resize(460, height)
            extension = section.leftExtensionDepth()
            actual_angle = math.degrees(math.atan2(float(height), extension))
            self.assertAlmostEqual(actual_angle, HOME_DIAGONAL_ANGLE, places=6)

        section.deleteLater()

    def test_inline_window_picker_preserves_saved_selection_and_applies_candidate(self) -> None:
        class Harness(QWidget, HomeTabComponent):
            pass

        harness = Harness()
        harness._ui_scale = 1.0
        harness._saved_target = Mock(return_value=(22, "Blue Archive"))
        harness._apply_target_window_selection = Mock(return_value=True)
        harness._home_right_host = HomeSectionHost()
        windows = [
            {"hwnd": 11, "title": "Notes", "size": "900x700"},
            {"hwnd": 22, "title": "Blue Archive", "size": "1600x900"},
        ]
        with patch("gui.viewer_components.home.get_all_windows", return_value=windows):
            panel = harness._build_home_connection_panel()
            harness._home_right_host.resize(460, 420)
            harness._home_right_host.addPage(panel, initial=True)
            harness._refresh_home_window_candidates()

        self.assertEqual(harness._home_window_list.count(), 2)
        selected = harness._home_window_list.currentItem()
        self.assertIsNotNone(selected)
        self.assertEqual(selected.data(Qt.UserRole)["hwnd"], 22)
        self.assertTrue(harness._home_window_confirm_button.isEnabled())

        harness._home_window_list.setCurrentRow(0)
        harness._apply_home_window_candidate()
        harness._apply_target_window_selection.assert_called_once_with(11, "Notes")
        harness.deleteLater()

    def test_connection_list_and_action_row_share_section_edges(self) -> None:
        class Harness(QWidget, HomeTabComponent):
            pass

        harness = Harness()
        harness._ui_scale = 1.0
        harness._saved_target = Mock(return_value=(0, ""))
        harness._home_right_host = HomeSectionHost()
        with patch("gui.viewer_components.home.get_all_windows", return_value=[]):
            panel = harness._build_home_connection_panel()
            panel.resize(566, 817)
            panel.show()
            self.app.processEvents()

        buttons = {
            button.property("uiDesignStableSelectorSegment"): button
            for button in panel.findChildren(QPushButton)
            if button.property("uiDesignStableSelectorSegment")
        }
        self.assertEqual(harness._home_window_list.geometry().left(), 30)
        self.assertEqual(buttons["QPushButton[0]"].geometry().left(), 30)
        self.assertEqual(
            buttons["QPushButton[2]"].geometry().right(),
            harness._home_window_list.geometry().right(),
        )
        self.assertEqual(
            buttons["QPushButton[2]"].geometry().left()
            - buttons["QPushButton[1]"].geometry().right()
            - 1,
            7,
        )
        self.assertIsInstance(buttons["QPushButton[0]"], LeftExtendedActionButton)
        self.assertGreater(buttons["QPushButton[0]"].extensionDepth(), 0.0)
        panel.deleteLater()
        harness.deleteLater()

    def test_connection_summary_elides_and_preserves_full_accessible_text(self) -> None:
        label = HomeElidedLabel("현재 선택: 아주 긴 Blue Archive 창 제목")
        label.resize(90, 24)
        label.show()
        self.app.processEvents()

        self.assertTrue(label.text().endswith("…"))
        self.assertEqual(label.accessibleName(), "현재 선택: 아주 긴 Blue Archive 창 제목")
        self.assertEqual(label.toolTip(), label.accessibleName())
        label.deleteLater()

    def test_connection_section_and_candidate_rows_receive_requested_surface_effects(self) -> None:
        class Harness(QWidget, HomeTabComponent):
            pass

        harness = Harness()
        harness._ui_scale = 1.0
        harness._saved_target = Mock(return_value=(0, ""))
        harness._home_right_host = HomeSectionHost()
        with patch(
            "gui.viewer_components.home.get_all_windows",
            return_value=[{"hwnd": 11, "title": "Blue Archive", "size": "1920x1080"}],
        ):
            panel = harness._build_home_connection_panel()
            panel.resize(566, 817)
            panel.show()
            harness._refresh_home_window_candidates()
            self.app.processEvents()

        host = harness._home_window_list.diagonalHost(harness._home_window_list.item(0))
        buttons = {
            button.property("uiDesignStableSelectorSegment"): button
            for button in panel.findChildren(QPushButton)
            if button.property("uiDesignStableSelectorSegment")
        }
        self.assertIsNotNone(panel._lifted_shadow)
        self.assertIsNotNone(buttons["QPushButton[0]"]._lifted_shadow)
        self.assertIsInstance(buttons["QPushButton[1]"].graphicsEffect(), QGraphicsDropShadowEffect)
        self.assertIsInstance(buttons["QPushButton[2]"].graphicsEffect(), QGraphicsDropShadowEffect)
        self.assertEqual(buttons["QPushButton[1]"].graphicsEffect().offset().x(), 2.0)
        self.assertEqual(buttons["QPushButton[2]"].graphicsEffect().offset().y(), 2.0)
        self.assertIsNotNone(host)
        self.assertIsNotNone(host._triangle_texture)
        self.assertIsNotNone(host._shadow_color)
        self.assertEqual(host._radius, 7)
        panel.deleteLater()
        harness.deleteLater()

    def test_menu_refresh_swaps_content_between_exit_and_entrance(self) -> None:
        host = HomeSectionHost()
        host.resize(360, 260)
        page = QWidget()
        host.addPage(page, initial=True)
        host.show()
        state = {"label": "connect"}

        host.refreshCurrent(lambda: state.__setitem__("label", "scan"))
        QTest.qWait(1100)

        self.assertEqual(state["label"], "scan")
        self.assertIs(host.currentPage(), page)
        self.assertTrue(page.isVisible())
        self.assertEqual(page.pos().x(), 0)
        self.assertEqual(page.pos().y(), 0)

    def test_manual_resources_are_saved_through_repository(self) -> None:
        component = object.__new__(HomeTabComponent)
        component._home_credit_input = QLineEdit("123456")
        component._home_pyroxene_input = QLineEdit("7890")
        component._home_center_host = HomeSectionHost()
        component._home_center_host.resize(420, 280)
        component._home_resource_panel = QWidget()
        component._home_item_panel = QWidget()
        component._home_center_host.addPage(component._home_resource_panel, initial=True)
        component._home_center_host.addPage(component._home_item_panel)
        component._reload_data = Mock()
        repository = Mock()

        with (
            patch("core.db_writer.build_scan_meta", return_value={"scan_id": "manual", "scanned_at": "now"}),
            patch("core.repository.ScanRepository", return_value=repository),
        ):
            component._home_save_manual_resources()

        result, meta = repository.save.call_args.args
        self.assertEqual(result.resources, {"credit": 123456, "pyroxene": 7890})
        self.assertEqual(meta["source"], "manual_resource_input")
        component._reload_data.assert_called_once_with()

    def test_menu_uses_four_equal_rows_with_interlocking_buttons(self) -> None:
        component = object.__new__(HomeTabComponent)
        component._ui_scale = 1.0

        section = component._build_home_menu_section()
        section.resize(520, 620)
        section.show()
        self.app.processEvents()

        rows = component._home_menu_rows
        self.assertEqual(len(rows), 4)
        self.assertLessEqual(max(row.height() for row in rows) - min(row.height() for row in rows), 1)
        self.assertEqual([len(row._buttons) for row in rows], [1, 3, 2, 1])
        self.assertTrue(all(rows[index].width() > rows[index + 1].width() for index in range(3)))

        rows_widget = component._home_menu_rows_widget
        for row in rows:
            section_y = rows_widget.y() + row.y()
            expected_width = rows_widget.width() - (section.width() - section.rightEdgeXAt(section_y))
            self.assertAlmostEqual(row.width(), expected_width, delta=1.0)

        self.assertFalse(component._home_primary_button._extend_left)
        self.assertEqual(
            [button._extend_left for button in component._home_menu_buttons],
            [False, True, True, False, True, False],
        )
        all_buttons = [component._home_primary_button, *component._home_menu_buttons]
        settings = component._home_menu_buttons_by_name["설정"]
        decorated_buttons = [button for button in all_buttons if button is not settings]
        self.assertTrue(all(button._radius == 7 for button in all_buttons))
        self.assertTrue(all(button._angle_degrees == HOME_DIAGONAL_ANGLE for button in all_buttons))
        self.assertIs(section._lifted_shadow, component._home_menu_shadow)
        self.assertTrue(all(button._lifted_shadow is component._home_menu_shadow for button in decorated_buttons))
        self.assertTrue(all(button._caption_overlay_ratio == HOME_MENU_CAPTION_RATIO for button in decorated_buttons))
        self.assertTrue(all(button._texture_overscan == HOME_MENU_TEXTURE_OVERSCAN for button in all_buttons))
        self.assertTrue(all(not button._show_focus_outline for button in all_buttons))
        self.assertTrue(all(button._caption_text_enabled for button in all_buttons))
        self.assertTrue(all(isinstance(button._caption_overlay, HomeButtonCaptionOverlay) for button in decorated_buttons))
        self.assertTrue(
            all(button._caption_overlay.testAttribute(Qt.WA_TransparentForMouseEvents) for button in decorated_buttons)
        )
        self.assertIsNone(settings._lifted_shadow)
        self.assertEqual(settings._caption_overlay_ratio, 0.0)
        self.assertIsInstance(settings._caption_overlay, HomeButtonCaptionOverlay)
        self.assertTrue(settings._caption_overlay.testAttribute(Qt.WA_TransparentForMouseEvents))
        self.assertEqual(settings._caption_text_color, QColor(HOME_MENU_SETTINGS_TEXT_COLOR))
        self.assertTrue(all(button._caption_text_color == QColor(HOME_MENU_CAPTION_TEXT_COLOR) for button in decorated_buttons))
        self.assertTrue(settings._triangle_texture_only)
        self.assertFalse(settings._state_effects_enabled)

        for row in rows[1:3]:
            slants = [button._diagonal_slant(button.width(), button.height()) for button in row._buttons]
            self.assertLessEqual(max(slants) - min(slants), 0.25)
            for left, right, slant in zip(row._buttons, row._buttons[1:], slants):
                top_gap = (right.x() + slant) - (left.x() + left.width())
                bottom_gap = right.x() - (left.x() + left.width() - slant)
                self.assertAlmostEqual(top_gap, 10.0, delta=1.5)
                self.assertAlmostEqual(bottom_gap, 10.0, delta=1.5)
        section.deleteLater()

    def test_menu_buttons_use_clipped_textures_without_visible_copy(self) -> None:
        component = object.__new__(HomeTabComponent)
        component._ui_scale = 1.0

        section = component._build_home_menu_section()
        section.resize(520, 620)
        section.show()
        self.app.processEvents()

        image_buttons = {
            "학생부 확인",
            "계획 설정",
            "인벤토리",
            "전술대항전",
            "통계",
        }
        all_buttons = [component._home_primary_button, *component._home_menu_buttons]
        self.assertTrue(all(button.text() == "" for button in all_buttons))
        self.assertTrue(all(button.accessibleName() for button in all_buttons))
        self.assertEqual(component._home_primary_button.accessibleName(), "싯딤의 상자와 연결")
        self.assertFalse(component._home_primary_button._texture.isNull())
        for name in image_buttons:
            self.assertTrue(HOME_MENU_TEXTURES[name].is_file())
            self.assertFalse(component._home_menu_buttons_by_name[name]._texture.isNull())

        settings = component._home_menu_buttons_by_name["설정"]
        self.assertTrue(settings._texture.isNull())
        self.assertIsNotNone(settings._triangle_texture)
        self.assertAlmostEqual(settings._triangle_visible_ratio, 0.52)
        self.assertIsNone(settings._triangle_fade_direction_degrees)
        self.assertIsNone(settings._triangle_fade_end_color)
        self.assertTrue(settings._triangle_texture_only)
        self.assertAlmostEqual(settings._triangle_texture.tessellation_contrast, 0.1)
        self.assertAlmostEqual(settings._triangle_texture.macro_triangle_contrast, 0.05)

        sample = component._home_menu_buttons_by_name["학생부 확인"]
        rendered = QImage(sample.size(), QImage.Format_ARGB32_Premultiplied)
        rendered.fill(0)
        sample.render(rendered)
        self.assertEqual(rendered.pixelColor(0, 0).alpha(), 0)
        self.assertGreater(rendered.pixelColor(sample.width() // 2, sample.height() // 2).alpha(), 0)
        self.assertEqual(rendered.pixelColor(sample.width() // 2, sample.height() - 2).alpha(), 255)

        caption_top = round(sample.height() * 0.65)
        white_text_pixels = sum(
            1
            for y in range(caption_top, sample.height())
            for x in range(0, sample.width() // 2)
            if rendered.pixelColor(x, y).lightness() > 235
        )
        self.assertGreater(white_text_pixels, 10)

        settings_rendered = QImage(settings.size(), QImage.Format_ARGB32_Premultiplied)
        settings_rendered.fill(0)
        settings.render(settings_rendered)
        settings_caption_top = round(settings.height() * 0.65)
        white_text_pixels = sum(
            1
            for y in range(settings_caption_top, settings.height())
            for x in range(0, settings.width() // 2)
            if settings_rendered.pixelColor(x, y).lightness() > 235
        )
        self.assertGreater(white_text_pixels, 10)
        section.deleteLater()

    def test_lifted_shadow_fades_toward_lower_right_edge(self) -> None:
        image = QImage(48, 48, QImage.Format_ARGB32_Premultiplied)
        image.fill(0)
        painter = QPainter(image)
        painter.setRenderHint(QPainter.Antialiasing, True)
        path = QPainterPath()
        path.addRect(QRectF(0.0, 0.0, 40.0, 40.0))
        _paint_lifted_shadow(
            painter,
            path,
            LiftedShadowSpec(color="#000000", offset_x=3.0, offset_y=3.0, layers=4, max_alpha=0.24),
        )
        painter.end()

        near_alpha = image.pixelColor(40, 40).alpha()
        outer_alpha = image.pixelColor(42, 42).alpha()
        self.assertGreater(near_alpha, outer_alpha)
        self.assertGreater(outer_alpha, 0)
        self.assertEqual(image.pixelColor(45, 45).alpha(), 0)

    def test_caption_overlay_is_a_continuous_light_gray_child_surface(self) -> None:
        button = ParallelogramActionButton(
            "caption target",
            fill="#e8e8e8",
            accent="#ffffff",
            extend_left=False,
            radius=0,
            display_text=False,
            caption_overlay_ratio=HOME_MENU_CAPTION_RATIO,
        )
        button.resize(240, 120)
        image = QImage(button.size(), QImage.Format_ARGB32_Premultiplied)
        image.fill(0)
        button.render(image)

        x = button.width() // 2
        upper_lightness = image.pixelColor(x, 60).lightness()
        boundary_lightness = image.pixelColor(x, 76).lightness()
        transition_lightness = image.pixelColor(x, 84).lightness()
        caption_lightness = image.pixelColor(x, 108).lightness()
        self.assertAlmostEqual(upper_lightness, boundary_lightness, delta=3)
        expected_caption = QColor(HOME_MENU_CAPTION_COLOR)
        expected_lightness = expected_caption.lightness()
        self.assertLess(
            abs(transition_lightness - expected_lightness),
            abs(boundary_lightness - expected_lightness),
        )
        self.assertLessEqual(
            abs(caption_lightness - expected_lightness),
            abs(transition_lightness - expected_lightness),
        )
        actual_caption = image.pixelColor(x, 108)
        self.assertLessEqual(abs(actual_caption.red() - expected_caption.red()), 4)
        self.assertLessEqual(abs(actual_caption.green() - expected_caption.green()), 4)
        self.assertLessEqual(abs(actual_caption.blue() - expected_caption.blue()), 4)
        button.deleteLater()

    def test_primary_button_swaps_connection_and_scan_textures(self) -> None:
        component = object.__new__(HomeTabComponent)
        component._ui_scale = 1.0
        section = component._build_home_menu_section()
        component._home_connection_status_label = None
        component._home_ready = True
        component._home_connected = None
        component._home_right_host = HomeSectionHost()
        component._home_connection_panel = QWidget()

        shittim_key = component._home_primary_button._texture.cacheKey()
        component._sync_home_connection_state(True, "Blue Archive")
        scan_key = component._home_primary_button._texture.cacheKey()

        self.assertEqual(component._home_primary_button.text(), "")
        self.assertEqual(component._home_primary_button.accessibleName(), "스캔")
        self.assertNotEqual(shittim_key, scan_key)
        self.assertFalse(component._home_primary_button._texture.isNull())
        section.deleteLater()

    def test_connection_state_is_committed_before_menu_refresh(self) -> None:
        component = object.__new__(HomeTabComponent)
        component._home_connection_status_label = None
        component._home_ready = True
        component._home_connected = False
        component._home_menu_host = Mock()

        component._sync_home_connection_state(True, "Blue Archive")
        component._sync_home_connection_state(True, "Blue Archive")

        self.assertTrue(component._home_connected)
        component._home_menu_host.refreshCurrent.assert_called_once()
        _callback, kwargs = component._home_menu_host.refreshCurrent.call_args
        self.assertEqual(kwargs, {"intro": 0.0, "outro": 180.0})


class HomeScannerCommandTests(unittest.TestCase):
    def test_item_category_is_forwarded_to_scanner_bridge(self) -> None:
        component = object.__new__(ScanTabComponent)
        command = component._scanner_command("items", item_filter="ooparts")
        self.assertIn("--item-scan-filter", command)
        index = command.index("--item-scan-filter")
        self.assertEqual(command[index + 1], "ooparts")


if __name__ == "__main__":
    unittest.main()
