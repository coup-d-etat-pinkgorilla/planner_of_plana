from __future__ import annotations

from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from gui.triangle_texture import TriangleTextureWidget
from gui.viewer_components.scan import ScanTabComponent, SlantedScanHeader


class ScanBackgroundWaveTests(unittest.TestCase):
    def test_scan_header_triangle_size_tracks_eighty_percent_of_height(self) -> None:
        self.assertAlmostEqual(SlantedScanHeader._triangle_size_for_height(148), 118.4)
        self.assertEqual(SlantedScanHeader._triangle_size_for_height(4), 6.0)

    def _component(self) -> ScanTabComponent:
        component = ScanTabComponent.__new__(ScanTabComponent)
        component._background_texture = Mock(spec=TriangleTextureWidget)
        component._scan_status_label = None
        component._startup_connection_wave_checked = False
        return component

    def test_event_presets_match_requested_color_duration_and_final_state(self) -> None:
        component = self._component()
        background = component._background_texture

        component._play_ba_connected_wave()
        _, connected = background.playWave.call_args
        self.assertEqual(connected["mode"], "pulse")
        self.assertEqual(connected["duration_ms"], component._BA_CONNECTED_WAVE_MS)

        background.reset_mock()
        component._play_scan_prepare_wave()
        prepare_color, prepare = background.playWave.call_args
        self.assertEqual(prepare_color[0].casefold(), "#f266b3")
        self.assertEqual(prepare["mode"], "hold")
        self.assertEqual(prepare["duration_ms"], component._SCAN_PREPARE_WAVE_MS)

        background.reset_mock()
        component._play_scan_finished_wave(success=True)
        success_color, success = background.playWave.call_args
        self.assertEqual(success_color[0].casefold(), "#aeb7c6")
        self.assertEqual(success["mode"], "restore")

        background.reset_mock()
        component._play_scan_finished_wave(success=False)
        error_color, error = background.playWave.call_args
        self.assertEqual(error_color[0].casefold(), "#ff5f70")
        self.assertEqual(error["mode"], "restore")
        self.assertLess(error["duration_ms"], success["duration_ms"])
        self.assertGreater(error["front_alpha"], success["front_alpha"])

    def test_target_selection_triggers_connected_wave_after_saving_target(self) -> None:
        component = self._component()
        component._sync_settings_labels = Mock()
        component._play_ba_connected_wave = Mock()

        with (
            patch("gui.viewer_components.scan.load_config", return_value={}) as load_config,
            patch("gui.viewer_components.scan.save_config") as save_config,
            patch("gui.viewer_components.scan.set_target_window") as set_target_window,
        ):
            applied = component._apply_target_window_selection(1234, "Blue Archive")

        self.assertTrue(applied)
        load_config.assert_called_once_with()
        save_config.assert_called_once_with({"target_hwnd": 1234, "target_title": "Blue Archive"})
        set_target_window.assert_called_once_with(1234, "Blue Archive")
        component._play_ba_connected_wave.assert_called_once_with()

    def test_disconnect_target_clears_persisted_and_runtime_connection(self) -> None:
        component = self._component()
        component._sync_settings_labels = Mock()

        with (
            patch(
                "gui.viewer_components.scan.load_config",
                return_value={"target_hwnd": 1234, "target_title": "Blue Archive", "theme": "dark"},
            ),
            patch("gui.viewer_components.scan.save_config") as save_config,
            patch("gui.viewer_components.scan.clear_target_window") as clear_target_window,
        ):
            component._disconnect_target_window()

        save_config.assert_called_once_with({"theme": "dark"})
        clear_target_window.assert_called_once_with()
        component._sync_settings_labels.assert_called_once_with()

    def test_confirmed_saved_target_schedules_one_startup_connection_wave(self) -> None:
        component = self._component()
        component._play_ba_connected_wave = Mock()

        with patch("gui.viewer_components.scan.QTimer.singleShot") as single_shot:
            component._schedule_startup_connection_wave(True)
            component._schedule_startup_connection_wave(True)

        single_shot.assert_called_once_with(0, component._play_ba_connected_wave)

    def test_unconfirmed_saved_target_does_not_schedule_startup_wave(self) -> None:
        component = self._component()

        with patch("gui.viewer_components.scan.QTimer.singleShot") as single_shot:
            component._schedule_startup_connection_wave(False)
            component._schedule_startup_connection_wave(True)

        single_shot.assert_not_called()

    def test_first_label_sync_uses_actual_hwnd_match_for_startup_effect(self) -> None:
        component = self._component()
        component._saved_target = Mock(return_value=(1234, "Blue Archive"))
        component._target_aspect_warning = Mock(return_value="")
        component._schedule_startup_connection_wave = Mock()
        component._settings_active_profile_label = None
        component._settings_target_label = None
        component._scan_profile_label = None
        component._scan_target_label = None
        component._scan_header = None
        component._scan_aspect_warning_label = None

        with (
            patch("gui.viewer_components.scan.get_active_profile_name", return_value="Default"),
            patch("gui.viewer_components.scan.get_all_windows", return_value=[{"hwnd": 1234}]),
        ):
            component._sync_settings_labels()

        component._schedule_startup_connection_wave.assert_called_once_with(True)

    def test_success_and_error_process_completion_choose_matching_restore_wave(self) -> None:
        for code, expected_success in ((0, True), (7, False)):
            with self.subTest(code=code):
                component = self._component()
                component._scanner_mode = "resources"
                component._poll_scan_status_events = Mock()
                component._scanner_mode_label = Mock(return_value="자원 스캔")
                component._play_scan_finished_wave = Mock()
                component._finish_scan_progress_view = Mock()
                component._reload_data = Mock()
                component._notify_scanner_finished = Mock()

                component._on_scanner_process_finished(code, notify=False)

                component._play_scan_finished_wave.assert_called_once_with(success=expected_success)
                if expected_success:
                    component._reload_data.assert_called_once_with()
                else:
                    component._reload_data.assert_not_called()

    def test_successful_scanner_launch_starts_prepare_wave(self) -> None:
        component = self._component()
        component._scanner_process = None
        component._scan_status_poll_timer = None
        component._scan_stop_button = None
        component._cleanup_finished_scanner_process = Mock(return_value=False)
        component._load_saved_target_into_capture = Mock(return_value=True)
        component._reset_scan_result_transition = Mock()
        component._sync_settings_labels = Mock()
        component._clear_scan_stop_request = Mock()
        component._scanner_command = Mock(return_value=["scanner"])
        component._scanner_mode_label = Mock(return_value="현재 학생 스캔")
        component._play_scan_prepare_wave = Mock()
        component._reset_plana_scan_status = Mock()
        component._reset_scan_progress_view = Mock()
        component._scanner_poll_timer = Mock()
        process = SimpleNamespace(poll=lambda: None)

        with (
            patch("gui.viewer_components.scan.activate_target_window"),
            patch("gui.viewer_components.scan.subprocess.Popen", return_value=process),
        ):
            component._launch_scanner("student_current")

        component._play_scan_prepare_wave.assert_called_once_with()
        component._scanner_poll_timer.start.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
