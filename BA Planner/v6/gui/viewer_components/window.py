"""ViewerWindowComponent implementation extracted from the viewer façade."""

from __future__ import annotations

from gui import viewer_shared as _viewer_shared

globals().update({name: value for name, value in vars(_viewer_shared).items() if not name.startswith("__")})


class ViewerWindowComponent:
    def __init__(
        self,
        ui_scale: float,
        startup_geometry: QRect | None = None,
        startup_screen_geometry: QRect | None = None,
        student_scan_debug: bool = False,
    ):
        super().__init__()
        self._ui_scale = ui_scale
        self._startup_geometry = QRect(startup_geometry) if startup_geometry is not None and not startup_geometry.isEmpty() else None
        self._startup_screen_geometry = (
            QRect(startup_screen_geometry)
            if startup_screen_geometry is not None and not startup_screen_geometry.isEmpty()
            else None
        )
        self._startup_window_applied = False
        self._applying_work_area = False
        self._student_scan_debug_enabled = bool(student_scan_debug)
        self._ba_arrow_key_down = {VK_LEFT: False, VK_RIGHT: False}
        self._detail_panel: QFrame | None = None
        self._hero_wrap: QFrame | None = None
        self._busy_overlay: QFrame | None = None
        self._busy_label: QLabel | None = None
        self._busy_progress: QProgressBar | None = None
        self._busy_cursor_active = False
        self._student_card_asset = ParallelogramCardAsset(build_card_style(CARD_BUTTON_ASSET, ui_scale))
        self._card_button_style = build_card_button_style(CARD_BUTTON_ASSET, ui_scale)
        self._base_thumb_width = scale_px(self._student_card_asset.base_size.width(), ui_scale)
        self._thumb_width = self._base_thumb_width
        self._thumb_height = scale_px(self._student_card_asset.base_size.height(), ui_scale)
        self._student_grid_card_width = scale_px(STUDENT_GRID_CARD_BASE_WIDTH, ui_scale)
        self._plan_grid_card_width = scale_px(PLAN_GRID_CARD_BASE_WIDTH, ui_scale)
        outer_margin = self._student_card_asset.style.outer_margin * 2
        self._grid_width = self._thumb_width + outer_margin
        self._grid_height = self._thumb_height + outer_margin
        self.setWindowTitle("Blue Archive Planner")
        self.resize(scale_px(PLANNER_BASE_WIDTH, ui_scale), scale_px(PLANNER_BASE_HEIGHT, ui_scale))

        self._pool = QThreadPool.globalInstance()
        self._tactical_screenshot_tasks: list[QRunnable] = []
        if not get_active_profile_name():
            activate_profile("Default")
        self._all_students = load_students()
        self._records_by_id = {record.student_id: record for record in self._all_students}
        self._tactical_student_lookup_index: dict[str, list[str]] | None = None
        self._filtered_students = list(self._all_students)
        self._item_by_id: dict[str, StudentCardWidget] = {}
        self._plan_card_by_id: dict[str, StudentCardWidget] = {}
        self._resource_scope_card_by_id: dict[str, StudentCardWidget] = {}
        self._resource_search_card_by_id: dict[str, StudentCardWidget] = {}
        self._thumb_loading: set[tuple[str, int, int]] = set()
        self._pending_thumb_requests: list[tuple[str, int, int]] = []
        self._pending_thumb_lookup: set[tuple[str, int, int]] = set()
        self._thumb_batch_size = 16
        self._thumb_max_in_flight = 48
        self._thumb_pixmap_cache: OrderedDict[tuple[str, int, int], QPixmap] = OrderedDict()
        self._thumb_pixmap_cache_limit = 640
        self._placeholder_icon = make_placeholder_icon(self._thumb_width, self._thumb_height)
        self._unowned_icon_cache: dict[str, QIcon] = {}
        self._large_pixmap: QPixmap | None = None
        self._selected_filters: dict[str, set[str]] = {key: set() for key in FILTER_FIELD_ORDER}
        self._filter_options = build_filter_options(self._all_students)
        self._plan_path = get_storage_paths().current_dir / "growth_plan.json"
        self._plan = load_plan(self._plan_path)
        self._tactical_path = get_storage_paths().current_dir / "tactical_challenge.db"
        self._tactical_data = load_tactical_challenge(self._tactical_path, load_matches=False)
        self._raid_guide_path = get_storage_paths().current_raid_guides_json
        self._raid_guide_data = load_raid_guides(self._raid_guide_path)
        self._selected_raid_guide_id: str | None = None
        self._raid_new_guide_ids: set[str] = set()
        self._raid_guide_editor_guard = False
        self._raid_deck_rows: list[dict[str, object]] = []
        self._raid_selected_deck_slot_index = 0
        self._raid_student_lookup_index: dict[str, list[str]] | None = None
        self._raid_assist_window: TacticAssistWindow | None = None
        self._plan_editor_guard = False
        self._selected_plan_student_id: str | None = None
        self._plan_segment_inputs: dict[str, PlanSegmentSelector] = {}
        self._plan_level_inputs: dict[str, PlanStepper] = {}
        self._plan_level_rows: dict[str, QWidget] = {}
        self._plan_level_row_labels: dict[str, QLabel] = {}
        self._plan_equipment_labels: dict[str, QLabel] = {}
        self._plan_stat_rows: dict[str, QWidget] = {}
        self._plan_ability_release_expanded = False
        self._resource_selected_ids: set[str] = self._planned_student_ids()
        self._resource_search_pending_ids: set[str] = set()
        self._resource_current_student_id: str | None = None
        self._resource_include_unplanned_level = True
        self._resource_include_unplanned_equipment = True
        self._resource_include_unplanned_skills = True
        self._resource_requirement_sort_mode = "default"
        self._resource_syncing_controls = False
        self._main_tabs: QTabWidget | None = None
        self._settings_tab: QWidget | None = None
        self._scan_tab: QWidget | None = None
        self._students_tab: QWidget | None = None
        self._scanner_process: subprocess.Popen | None = None
        self._scanner_mode: str = ""
        self._scanner_tray_icon: QSystemTrayIcon | None = None
        self._settings_profile_combo: QComboBox | None = None
        self._settings_active_profile_label: QLabel | None = None
        self._settings_target_label: QLabel | None = None
        self._scan_header: QFrame | None = None
        self._scan_profile_label: QLabel | None = None
        self._scan_target_label: QLabel | None = None
        self._scan_status_label: QLabel | None = None
        self._scan_start_hint_label: QLabel | None = None
        self._scan_aspect_warning_label: QLabel | None = None
        self._scan_progress_bar: QProgressBar | None = None
        self._scan_progress_label: QLabel | None = None
        self._scan_eta_label: QLabel | None = None
        self._scan_stop_button: QPushButton | None = None
        self._scan_plana_image_label: QLabel | None = None
        self._scan_student_hero: StudentPortraitWidget | None = None
        self._scan_student_progress_strip: DetailProgressStrip | None = None
        self._scan_plana_message_label: QLabel | None = None
        self._scan_plana_meta_label: QLabel | None = None
        self._scan_plana_log: QPlainTextEdit | None = None
        self._scan_plana_pixmaps: dict[str, QPixmap] = {}
        self._scan_student_card: QFrame | None = None
        self._scan_inventory_card: QFrame | None = None
        self._scan_detail_stack: QStackedWidget | None = None
        self._scan_inventory_title_label: QLabel | None = None
        self._scan_inventory_meta_label: QLabel | None = None
        self._scan_inventory_grid_layout: QGridLayout | None = None
        self._scan_inventory_grid_cells: list[dict[str, object]] = []
        self._scan_inventory_grid_cols = 5
        self._scan_inventory_grid_rows = 4
        self._scan_inventory_visible_slots = 20
        self._scan_student_name_label: QLabel | None = None
        self._scan_student_meta_label: QLabel | None = None
        self._scan_student_value_labels: dict[str, QLabel] = {}
        self._scan_student_equip_cards: dict[str, EquipmentDetailCard] = {}
        self._scan_student_live_state: dict[str, object] = {}
        self._scan_student_position_label: QLabel | None = None
        self._scan_student_class_label: QLabel | None = None
        self._scan_student_weapon_level_label: QLabel | None = None
        self._scan_student_combat_stats_label: QLabel | None = None
        self._scan_current_student_id = ""
        self._scan_current_student_name = ""
        self._scan_inventory_confirmed_count = 0
        self._scan_inventory_scroll_animation: QParallelAnimationGroup | None = None
        self._scan_status_file_offset = 0
        self._scan_status_recent_messages: list[str] = []
        self._scan_started_at: datetime | None = None
        self._scan_last_progress: tuple[int | None, int | None] = (None, None)
        self._resource_tab: QWidget | None = None
        self._resources_dirty = False
        self._inventory_snapshot = load_inventory_snapshot()
        self._resource_snapshot = load_latest_resource_snapshot()
        self._inventory_quantity_index_cache = _inventory_quantity_index(self._inventory_snapshot or {}, self._resource_snapshot)
        self._plan_goal_map_cache: dict[str, StudentGoal] | None = None
        self._plan_cost_cache: dict[tuple[str, tuple[object, ...]], PlanCostSummary] = {}
        self._plan_resource_icon_path_cache: dict[tuple[str | None, str], Path | None] = {}
        self._plan_resource_pixmap_cache: dict[Path, QPixmap] = {}
        storage_paths = get_storage_paths()
        self._storage_watch_paths = (
            storage_paths.current_students_json,
            storage_paths.current_inventory_json,
            self._plan_path,
            self._tactical_path,
            self._raid_guide_path,
            storage_paths.db_path,
        )
        self._storage_mtimes = self._snapshot_storage_mtimes()
        self._stats_cards_layout: QGridLayout | None = None
        self._stats_summary_host: QWidget | None = None
        self._stats_chart_tabs: QTabBar | None = None
        self._stats_active_chart_tab = "collection"
        self._stats_sunburst: SunburstWidget | None = None
        self._stats_sunburst_mode: QComboBox | None = None
        self._stats_sunburst_value_mode: QComboBox | None = None
        self._stats_sunburst_detail: QLabel | None = None
        self._stats_sunburst_top_detail: QLabel | None = None
        self._stats_detail_path_label: QLabel | None = None
        self._stats_detail_name_label: QLabel | None = None
        self._stats_detail_level_label: QLabel | None = None
        self._stats_detail_total_label: QLabel | None = None
        self._stats_detail_metric_count_label: QLabel | None = None
        self._stats_detail_metric_percent_label: QLabel | None = None
        self._stats_detail_owned_bar: QProgressBar | None = None
        self._stats_detail_owned_bar_label: QLabel | None = None
        self._stats_detail_owned_label: QLabel | None = None
        self._stats_detail_unowned_label: QLabel | None = None
        self._stats_detail_planned_label: QLabel | None = None
        self._stats_sunburst_breadcrumb_host: QWidget | None = None
        self._stats_sunburst_breadcrumb_layout: QHBoxLayout | None = None
        self._stats_sunburst_legend_layout: QVBoxLayout | None = None
        self._stats_sunburst_root_button: QPushButton | None = None
        self._stats_sunburst_back_button: QPushButton | None = None
        self._stats_sunburst_clear_button: QPushButton | None = None
        self._stats_collection_mode = "school"
        self._stats_growth_mode = "level_bucket"
        self._stats_plan_mode = "shortage_items"
        self._stats_resource_mode = "shortage_items"
        self._stats_skill_mode = "skill_buff"
        self._stats_sunburst_selected_path: tuple[str, ...] = ()
        self._stats_sunburst_breadcrumb_path: tuple[str, ...] = ()
        self._stats_sunburst_selected_context: dict[str, object] = {}
        self._stats_sunburst_selected_node: SunburstNode | None = None
        self._stats_sunburst_drill_stack: list[tuple[str, ...]] = []
        self._tactical_selected_match_id: str | None = None
        self._tactical_match_page_size = 100
        self._tactical_match_loaded_count = self._tactical_match_page_size
        self._tactical_match_query = ""
        self._card_layout_guard = False
        self._thumb_pump = QTimer(self)
        self._thumb_pump.setSingleShot(False)
        self._thumb_pump.setInterval(0)
        self._thumb_pump.timeout.connect(self._drain_thumb_queue)
        self._filter_refresh_timer = QTimer(self)
        self._filter_refresh_timer.setSingleShot(True)
        self._filter_refresh_timer.setInterval(SEARCH_DEBOUNCE_MS)
        self._filter_refresh_timer.timeout.connect(self._apply_filters)
        self._plan_search_timer = QTimer(self)
        self._plan_search_timer.setSingleShot(True)
        self._plan_search_timer.setInterval(SEARCH_DEBOUNCE_MS)
        self._plan_search_timer.timeout.connect(self._refresh_plan_lists)
        self._storage_watch_timer = QTimer(self)
        self._storage_watch_timer.setSingleShot(False)
        self._storage_watch_timer.setInterval(1000)
        self._storage_watch_timer.timeout.connect(self._poll_storage_changes)
        self._storage_watch_timer.start()
        self._scanner_poll_timer = QTimer(self)
        self._scanner_poll_timer.setSingleShot(False)
        self._scanner_poll_timer.setInterval(1000)
        self._scanner_poll_timer.timeout.connect(self._check_scanner_process)
        self._scan_status_poll_timer = QTimer(self)
        self._scan_status_poll_timer.setSingleShot(False)
        self._scan_status_poll_timer.setInterval(75)
        self._scan_status_poll_timer.timeout.connect(self._poll_scan_status_events)
        self._ba_input_poll_timer = QTimer(self)
        self._ba_input_poll_timer.setSingleShot(False)
        self._ba_input_poll_timer.setInterval(35)
        self._ba_input_poll_timer.timeout.connect(self._poll_debug_ba_arrow_keys)

        self._build_ui()
        app = QApplication.instance()
        if app is not None:
            app.installEventFilter(self)
        if self._student_scan_debug_enabled:
            self._load_saved_target_into_capture()
            self._ba_input_poll_timer.start()
        self._apply_filters()
        self._refresh_plan_lists()
        self._refresh_plan_totals()
        self._refresh_stats_tab()
        self._refresh_resource_students_list()
        self._refresh_resource_view()
        self._refresh_tactical_tab()
        self._resources_dirty = False
        self.setMinimumSize(1, 1)
    def showEvent(self, event) -> None:
        super().showEvent(event)
        if self._startup_window_applied:
            return
        self._startup_window_applied = True
        QTimer.singleShot(0, self._apply_startup_window_state)
    def closeEvent(self, event) -> None:
        self._terminate_scanner_process()
        assist_window = getattr(self, "_raid_assist_window", None)
        if assist_window is not None:
            assist_window.close()
            self._raid_assist_window = None
        super().closeEvent(event)
    def _terminate_scanner_process(self) -> None:
        process = self._scanner_process
        self._scanner_poll_timer.stop()
        if self._scan_status_poll_timer is not None:
            self._scan_status_poll_timer.stop()
        if process is None:
            return
        self._scanner_process = None
        self._scanner_mode = ""
        self._finish_scan_progress_view(1)
        if process.poll() is not None:
            return
        try:
            process.terminate()
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=2)
        except Exception:
            pass
    def _snapshot_storage_mtimes(self) -> dict[Path, int | None]:
        mtimes: dict[Path, int | None] = {}
        for path in self._storage_watch_paths:
            try:
                mtimes[path] = path.stat().st_mtime_ns
            except OSError:
                mtimes[path] = None
        return mtimes
    def _poll_storage_changes(self) -> None:
        current_mtimes = self._snapshot_storage_mtimes()
        if current_mtimes == self._storage_mtimes:
            return
        self._storage_mtimes = current_mtimes
        self._reload_data()
    def _apply_startup_window_state(self) -> None:
        self._apply_work_area_geometry(self._startup_geometry, self._startup_screen_geometry)
        self._startup_geometry = None
        self._startup_screen_geometry = None
        QTimer.singleShot(0, self._sync_hero_height)
        self._schedule_inventory_layout_sync()
        if os.name == "nt":
            self.winId()
            _set_windows_caption_theme(int(self.winId()), PALETTE_SOFT, _preferred_text_hex(PALETTE_SOFT))
    def _apply_work_area_geometry(
        self,
        available_override: QRect | None = None,
        screen_geometry_override: QRect | None = None,
    ) -> None:
        if available_override is not None and not available_override.isEmpty():
            available = QRect(available_override)
            screen_geometry = QRect(screen_geometry_override) if screen_geometry_override is not None and not screen_geometry_override.isEmpty() else QRect(available_override)
        else:
            screen = self.windowHandle().screen() if self.windowHandle() else QApplication.primaryScreen()
            available = screen.availableGeometry() if screen is not None else QRect()
            screen_geometry = screen.geometry() if screen is not None else QRect()
        if os.name == "nt" and (available_override is None or available_override.isEmpty()):
            self.winId()
            work_area = _windows_work_area(int(self.winId()))
            if work_area is not None:
                available = work_area
        if available.isEmpty():
            return
        target_frame = _window_frame_for_screen_area(screen_geometry, available)
        frame = self.frameGeometry()
        client = self.geometry()
        left_margin = max(0, client.left() - frame.left())
        top_margin = max(0, client.top() - frame.top())
        right_margin = max(0, frame.right() - client.right())
        bottom_margin = max(0, frame.bottom() - client.bottom())
        target_client = QRect(
            target_frame.left() + left_margin,
            target_frame.top() + top_margin,
            max(1, target_frame.width() - left_margin - right_margin),
            max(1, target_frame.height() - top_margin - bottom_margin),
        )
        self._applying_work_area = True
        try:
            self.setWindowState(self.windowState() & ~Qt.WindowMaximized)
            self.setMinimumSize(1, 1)
            self.setMaximumSize(16777215, 16777215)
            self.setGeometry(target_client)
            self.setFixedSize(target_client.size())
        finally:
            self._applying_work_area = False
    def _add_main_tab(self, tabs: QTabWidget, content: QWidget, label: str) -> QWidget:
        tabs.addTab(content, label)
        return content
