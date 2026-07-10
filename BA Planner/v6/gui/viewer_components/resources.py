"""ResourcesTabComponent implementation extracted from the viewer façade."""

from __future__ import annotations

from gui import viewer_shared as _viewer_shared

globals().update({name: value for name, value in vars(_viewer_shared).items() if not name.startswith("__")})


class ResourcesTabComponent:
    def _build_resource_tab(self, root: QWidget) -> None:
        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, scale_px(12, self._ui_scale))
        layout.setSpacing(scale_px(12, self._ui_scale))

        header = QFrame()
        header.setObjectName("header")
        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        header_layout.setSpacing(scale_px(12, self._ui_scale))

        title_wrap = QVBoxLayout()
        title_wrap.setSpacing(scale_px(4, self._ui_scale))
        title = QLabel("필요 재화량")
        title.setObjectName("title")
        title_wrap.addWidget(title)
        subtitle = QLabel(
            "계획된 범위의 학생들이 필요로 하는 재화량과, 계획에 포함되어 있지 않는 학생들을 임의로 묶어서 필요 재화량을 확인할 수 있습니다."
        )
        subtitle.setObjectName("count")
        subtitle.setWordWrap(True)
        title_wrap.addWidget(subtitle)
        header_layout.addLayout(title_wrap, 1)
        layout.addWidget(header)

        toolbar = QFrame()
        toolbar.setObjectName("panel")
        toolbar_layout = QHBoxLayout(toolbar)
        toolbar_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        toolbar_layout.setSpacing(scale_px(10, self._ui_scale))

        self._resource_search = LiveSearchLineEdit()
        self._resource_search.setPlaceholderText("학생 이름, ID, 태그로 검색; 필터로 범위를 좁힙니다")
        self._resource_search.textChanged.connect(self._on_resource_search_changed)
        self._resource_search.liveTextChanged.connect(self._schedule_filter_refresh)
        toolbar_layout.addWidget(self._resource_search, 3)

        self._resource_sort_mode = InventorySortDropdownButton()
        self._resource_sort_mode.addItem("성급 높은순", "star_desc")
        self._resource_sort_mode.addItem("성급 낮은순", "star_asc")
        self._resource_sort_mode.addItem("레벨 높은순", "level_desc")
        self._resource_sort_mode.addItem("이름순", "name_asc")
        self._resource_sort_mode.modeChanged.connect(self._on_resource_sort_changed)
        toolbar_layout.addWidget(self._resource_sort_mode, 0, Qt.AlignVCenter)

        self._resource_show_unowned = QCheckBox("미보유 학생 표시")
        self._resource_show_unowned.stateChanged.connect(self._on_resource_show_unowned_changed)
        toolbar_layout.addWidget(self._resource_show_unowned)

        self._resource_hide_jp_only = QCheckBox("일본 서버 전용 숨김")
        self._resource_hide_jp_only.stateChanged.connect(self._on_resource_hide_jp_only_changed)
        toolbar_layout.addWidget(self._resource_hide_jp_only)

        self._resource_filter_button = QPushButton("필터")
        self._resource_filter_button.setObjectName("planQuickButton")
        self._resource_filter_button.clicked.connect(self._open_filter_dialog)
        toolbar_layout.addWidget(self._resource_filter_button)
        resource_refresh_button = QPushButton("새로고침")
        resource_refresh_button.setObjectName("planQuickButton")
        resource_refresh_button.clicked.connect(self._reload_data)
        toolbar_layout.addWidget(resource_refresh_button)

        self._resource_filter_summary = QLabel("적용된 필터 없음")
        self._resource_filter_summary.setWordWrap(True)
        self._resource_filter_summary.setObjectName("filterSummary")

        splitter = QSplitter(Qt.Horizontal)
        splitter.setObjectName("sectionSplitter")
        splitter.setChildrenCollapsible(False)

        left_panel = QFrame()
        left_panel.setObjectName("planSectionPanel")
        left_layout = QVBoxLayout(left_panel)
        left_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        left_layout.setSpacing(scale_px(10, self._ui_scale))

        self._resource_left_top_panel = PlanEditorSectionCard(ui_scale=self._ui_scale, radius=16)
        resource_left_top_layout = QVBoxLayout(self._resource_left_top_panel)
        resource_left_top_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        resource_left_top_layout.setSpacing(scale_px(8, self._ui_scale))

        self._resource_left_header_host = QWidget()
        self._resource_left_header_host.setObjectName("planTransparent")
        left_header = QHBoxLayout(self._resource_left_header_host)
        left_header.setContentsMargins(0, 0, 0, 0)
        left_header.setSpacing(scale_px(8, self._ui_scale))
        left_header_title = QLabel("범위 설정")
        left_header_title.setObjectName("resourceSectionTitle")
        left_header.addWidget(left_header_title)
        left_header.addStretch(1)

        self._resource_mode_buttons: dict[int, QPushButton] = {}
        for index, label in enumerate(("범위", "검색")):
            button = QPushButton(label)
            button.setObjectName("resourceModeButton")
            button.setCheckable(True)
            button.clicked.connect(lambda _checked=False, value=index: self._set_resource_left_mode(value))
            self._resource_mode_buttons[index] = button
            left_header.addWidget(button, 0, Qt.AlignVCenter)

        self._resource_left_top_stack = QStackedWidget()
        self._resource_left_top_stack.setObjectName("sectionTransparentStack")
        resource_left_top_layout.addWidget(self._resource_left_header_host, 0)
        resource_left_top_layout.addWidget(self._resource_left_top_stack, 0)
        left_layout.addWidget(self._resource_left_top_panel, 0)

        self._resource_left_stack = QStackedWidget()
        self._resource_left_stack.setObjectName("sectionTransparentStack")
        left_layout.addWidget(self._resource_left_stack, 1)

        scope_tab = QWidget()
        scope_tab.setObjectName("planTransparent")
        scope_layout = QVBoxLayout(scope_tab)
        scope_layout.setContentsMargins(0, 0, 0, 0)
        scope_layout.setSpacing(scale_px(10, self._ui_scale))

        self._resource_scope_top_controls = QWidget()
        self._resource_scope_top_controls.setObjectName("planTransparent")
        scope_top_layout = QVBoxLayout(self._resource_scope_top_controls)
        scope_top_layout.setContentsMargins(0, 0, 0, 0)
        scope_top_layout.setSpacing(scale_px(6, self._ui_scale))

        scope_header = QHBoxLayout()
        scope_header.setContentsMargins(0, 0, 0, 0)
        scope_header.setSpacing(scale_px(8, self._ui_scale))
        left_title = QLabel("계산 범위")
        left_title.setObjectName("sectionTitle")
        scope_header.addWidget(left_title)
        scope_header.addStretch(1)
        scope_top_layout.addLayout(scope_header)

        self._resource_list_summary = QLabel("")
        self._resource_list_summary.setObjectName("detailSub")
        self._resource_list_summary.setWordWrap(True)
        scope_top_layout.addWidget(self._resource_list_summary)
        self._resource_left_top_stack.addWidget(self._resource_scope_top_controls)

        unplanned_options = QFrame()
        unplanned_options.setObjectName("planSectionPanel")
        unplanned_layout = QVBoxLayout(unplanned_options)
        unplanned_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        unplanned_layout.setSpacing(scale_px(8, self._ui_scale))
        unplanned_title = QLabel("미계획 학생 계산")
        unplanned_title.setObjectName("detailSectionTitle")
        unplanned_layout.addWidget(unplanned_title)
        unplanned_row = QHBoxLayout()
        unplanned_row.setSpacing(scale_px(10, self._ui_scale))
        self._resource_unplanned_level = QCheckBox("레벨")
        self._resource_unplanned_level.setChecked(True)
        self._resource_unplanned_level.stateChanged.connect(self._on_resource_unplanned_options_changed)
        unplanned_row.addWidget(self._resource_unplanned_level)
        self._resource_unplanned_equipment = QCheckBox("장비")
        self._resource_unplanned_equipment.setChecked(True)
        self._resource_unplanned_equipment.stateChanged.connect(self._on_resource_unplanned_options_changed)
        unplanned_row.addWidget(self._resource_unplanned_equipment)
        self._resource_unplanned_skills = QCheckBox("스킬")
        self._resource_unplanned_skills.setChecked(True)
        self._resource_unplanned_skills.stateChanged.connect(self._on_resource_unplanned_options_changed)
        unplanned_row.addWidget(self._resource_unplanned_skills)
        unplanned_row.addStretch(1)
        unplanned_layout.addLayout(unplanned_row)
        resource_card_min_width = max(scale_px(104, self._ui_scale), int(round(self._student_card_asset.base_size.width() * 0.52)))
        self._resource_scope_grid = ParallelogramCardGrid(
            self._student_card_asset,
            self._ui_scale,
            min_card_width=resource_card_min_width,
        )
        self._resource_scope_grid.setObjectName("studentGrid")
        self._resource_scope_grid.setFrameShape(QFrame.NoFrame)
        self._resource_scope_grid.setAutoFillBackground(False)
        self._resource_scope_grid.setAttribute(Qt.WA_TranslucentBackground, True)
        self._resource_scope_grid.viewport().setAutoFillBackground(False)
        self._resource_scope_grid.viewport().setAttribute(Qt.WA_TranslucentBackground, True)
        self._resource_scope_grid.viewport().setStyleSheet("background: transparent; border: none;")
        if self._resource_scope_grid.widget() is not None:
            self._resource_scope_grid.widget().setAutoFillBackground(False)
            self._resource_scope_grid.widget().setAttribute(Qt.WA_TranslucentBackground, True)
            self._resource_scope_grid.widget().setStyleSheet("background: transparent; border: none;")
        _install_planner_scroll_handle(self._resource_scope_grid, ui_scale=self._ui_scale)
        self._resource_scope_grid.current_changed.connect(self._on_resource_scope_card_changed)
        self._resource_scope_grid.layout_changed.connect(lambda *_: self._refresh_card_layout())
        self._resource_scope_grid_panel = PlanGridContentPanel(ui_scale=self._ui_scale)
        scope_grid_panel_layout = QVBoxLayout(self._resource_scope_grid_panel)
        scope_grid_panel_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        scope_grid_panel_layout.setSpacing(0)
        scope_grid_panel_layout.addWidget(self._resource_scope_grid, 1)
        scope_layout.addWidget(self._resource_scope_grid_panel, 1)

        scope_buttons = QHBoxLayout()
        scope_buttons.setSpacing(scale_px(8, self._ui_scale))
        for label, handler in (
            ("선택 제거", self._resource_remove_scope_selected),
            ("비우기", self._resource_clear_checked),
        ):
            button = QPushButton(label)
            button.setObjectName("planQuickButton")
            button.clicked.connect(handler)
            if label == "선택 제거":
                self._resource_remove_scope_button = button
            scope_buttons.addWidget(button)
        scope_buttons.addStretch(1)
        scope_buttons.addWidget(unplanned_options, 0, Qt.AlignRight | Qt.AlignVCenter)
        scope_layout.addLayout(scope_buttons)
        self._resource_left_stack.addWidget(scope_tab)

        search_tab = QWidget()
        search_tab.setObjectName("planTransparent")
        search_layout = QVBoxLayout(search_tab)
        search_layout.setContentsMargins(0, 0, 0, 0)
        search_layout.setSpacing(scale_px(10, self._ui_scale))

        self._resource_search_top_controls = QWidget()
        self._resource_search_top_controls.setObjectName("planTransparent")
        search_top_layout = QVBoxLayout(self._resource_search_top_controls)
        search_top_layout.setContentsMargins(0, 0, 0, 0)
        search_top_layout.setSpacing(scale_px(6, self._ui_scale))
        search_top_layout.addWidget(toolbar, 0)
        search_top_layout.addWidget(self._resource_filter_summary, 0)

        result_title = QLabel("검색 결과")
        result_title.setObjectName("sectionTitle")
        search_top_layout.addWidget(result_title)
        self._resource_search_summary = QLabel("")
        self._resource_search_summary.setObjectName("detailSub")
        self._resource_search_summary.setWordWrap(True)
        search_top_layout.addWidget(self._resource_search_summary)
        self._resource_left_top_stack.addWidget(self._resource_search_top_controls)

        self._resource_search_grid = ParallelogramCardGrid(
            self._student_card_asset,
            self._ui_scale,
            multi_select=True,
            min_card_width=resource_card_min_width,
        )
        self._resource_search_grid.setObjectName("studentGrid")
        self._resource_search_grid.setFrameShape(QFrame.NoFrame)
        self._resource_search_grid.setAutoFillBackground(False)
        self._resource_search_grid.setAttribute(Qt.WA_TranslucentBackground, True)
        self._resource_search_grid.viewport().setAutoFillBackground(False)
        self._resource_search_grid.viewport().setAttribute(Qt.WA_TranslucentBackground, True)
        self._resource_search_grid.viewport().setStyleSheet("background: transparent; border: none;")
        if self._resource_search_grid.widget() is not None:
            self._resource_search_grid.widget().setAutoFillBackground(False)
            self._resource_search_grid.widget().setAttribute(Qt.WA_TranslucentBackground, True)
            self._resource_search_grid.widget().setStyleSheet("background: transparent; border: none;")
        _install_planner_scroll_handle(self._resource_search_grid, ui_scale=self._ui_scale)
        self._resource_search_grid.selection_changed.connect(self._on_resource_search_selection_changed)
        self._resource_search_grid.layout_changed.connect(lambda *_: self._refresh_card_layout())
        self._resource_search_grid_panel = PlanGridContentPanel(ui_scale=self._ui_scale)
        search_grid_panel_layout = QVBoxLayout(self._resource_search_grid_panel)
        search_grid_panel_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        search_grid_panel_layout.setSpacing(0)
        search_grid_panel_layout.addWidget(self._resource_search_grid, 1)
        search_layout.addWidget(self._resource_search_grid_panel, 1)

        search_buttons = QHBoxLayout()
        search_buttons.setSpacing(scale_px(8, self._ui_scale))
        self._resource_add_selected_button = QPushButton("선택한 학생 추가")
        self._resource_add_selected_button.setObjectName("planQuickButton")
        self._resource_add_selected_button.clicked.connect(self._resource_add_pending_to_scope)
        search_buttons.addWidget(self._resource_add_selected_button)
        for label, handler in (
            ("결과 전체 추가", self._resource_check_visible),
            ("계획에 포함된 학생 전체 추가", self._resource_check_visible_planned),
            ("선택 해제", self._resource_clear_search_selection),
        ):
            button = QPushButton(label)
            button.setObjectName("planQuickButton")
            button.clicked.connect(handler)
            search_buttons.addWidget(button)
        search_buttons.addStretch(1)
        search_layout.addLayout(search_buttons)
        self._resource_left_stack.addWidget(search_tab)
        self._set_resource_left_mode(0)

        right_panel = QFrame()
        right_panel.setObjectName("planSectionPanel")
        right_layout = QVBoxLayout(right_panel)
        right_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        right_layout.setSpacing(scale_px(10, self._ui_scale))

        self._resource_right_top_controls = PlanEditorSectionCard(ui_scale=self._ui_scale, radius=16)
        aggregate_options_layout = QVBoxLayout(self._resource_right_top_controls)
        aggregate_options_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        aggregate_options_layout.setSpacing(scale_px(8, self._ui_scale))
        aggregate_header = QHBoxLayout()
        aggregate_header.setContentsMargins(0, 0, 0, 0)
        aggregate_header.setSpacing(scale_px(8, self._ui_scale))
        aggregate_title = QLabel("합산 결과")
        aggregate_title.setObjectName("sectionTitle")
        aggregate_header.addWidget(aggregate_title)
        aggregate_header.addStretch(1)
        aggregate_sort_label = QLabel("정렬")
        aggregate_sort_label.setObjectName("detailMiniSub")
        aggregate_header.addWidget(aggregate_sort_label, 0, Qt.AlignVCenter)
        self._resource_requirement_sort = InventorySortDropdownButton()
        self._resource_requirement_sort.addItem("일반", "default")
        self._resource_requirement_sort.addItem("부족한 비율 순서", "shortage_ratio")
        self._resource_requirement_sort.modeChanged.connect(self._on_resource_requirement_sort_changed)
        aggregate_header.addWidget(self._resource_requirement_sort, 0, Qt.AlignVCenter)
        aggregate_options_layout.addLayout(aggregate_header)

        self._resource_aggregate_summary = QLabel("학생을 범위에 추가하면 성장 비용을 합산합니다.")
        self._resource_aggregate_summary.setObjectName("detailSub")
        self._resource_aggregate_summary.setWordWrap(True)
        aggregate_options_layout.addWidget(self._resource_aggregate_summary)

        self._resource_requirement_empty = QLabel("학생을 범위에 추가하면 필요한 재화를 미리 볼 수 있습니다.")
        self._resource_requirement_empty.setObjectName("filterSummary")
        self._resource_requirement_empty.setWordWrap(True)
        self._resource_requirement_empty.setMinimumHeight(scale_px(22, self._ui_scale))
        aggregate_options_layout.addWidget(self._resource_requirement_empty)
        right_layout.addWidget(self._resource_right_top_controls, 0)

        self._resource_requirement_scroll = QScrollArea()
        self._resource_requirement_scroll.setObjectName("sectionScrollArea")
        self._resource_requirement_scroll.setFrameShape(QFrame.NoFrame)
        self._resource_requirement_scroll.setWidgetResizable(True)
        self._resource_requirement_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self._resource_requirement_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        self._resource_requirement_scroll.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        _install_planner_scroll_handle(self._resource_requirement_scroll, ui_scale=self._ui_scale)

        self._resource_requirement_grid_host = QWidget()
        self._resource_requirement_grid_host.setObjectName("planTransparent")
        self._resource_requirement_grid_host.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        self._resource_requirement_grid = QGridLayout(self._resource_requirement_grid_host)
        self._resource_requirement_grid.setContentsMargins(
            scale_px(6, self._ui_scale),
            scale_px(6, self._ui_scale),
            scale_px(6, self._ui_scale),
            scale_px(6, self._ui_scale),
        )
        self._resource_requirement_grid.setHorizontalSpacing(scale_px(8, self._ui_scale))
        self._resource_requirement_grid.setVerticalSpacing(scale_px(8, self._ui_scale))
        self._resource_requirement_grid.setAlignment(Qt.AlignTop)
        for column in range(3):
            self._resource_requirement_grid.setColumnStretch(column, 1)
        self._resource_requirement_scroll.setWidget(self._resource_requirement_grid_host)
        self._resource_requirement_grid_panel = PlanGridContentPanel(ui_scale=self._ui_scale)
        requirement_grid_panel_layout = QVBoxLayout(self._resource_requirement_grid_panel)
        requirement_grid_panel_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        requirement_grid_panel_layout.setSpacing(0)
        requirement_grid_panel_layout.addWidget(self._resource_requirement_scroll, 1)
        right_layout.addWidget(self._resource_requirement_grid_panel, 1)

        splitter.addWidget(left_panel)
        splitter.addWidget(right_panel)
        splitter.setStretchFactor(0, 1)
        splitter.setStretchFactor(1, 1)
        splitter.setSizes([scale_px(720, self._ui_scale), scale_px(720, self._ui_scale)])
        layout.addWidget(splitter, 1)

        self._sync_resource_controls_from_students()
        self._refresh_resource_students_list()
        self._refresh_resource_view()
        QTimer.singleShot(0, self._sync_resource_result_start)
        self._resources_dirty = False
    def _sync_resource_controls_from_students(self) -> None:
        if not hasattr(self, "_resource_search"):
            return
        self._resource_syncing_controls = True
        try:
            if self._resource_search.text() != self._search.text():
                self._resource_search.setText(self._search.text())
            target_sort = self._sort_mode.currentData()
            self._resource_sort_mode.setCurrentData(str(target_sort))
            self._resource_show_unowned.setChecked(self._show_unowned.isChecked())
            self._resource_hide_jp_only.setChecked(self._hide_jp_only.isChecked())
            self._resource_filter_summary.setText(self._filter_summary.text())
            self._resource_filter_button.setText(self._filter_button.text())
        finally:
            self._resource_syncing_controls = False
        QTimer.singleShot(0, self._sync_resource_result_start)
    def _set_resource_left_mode(self, index: int) -> None:
        index = 0 if index <= 0 else 1
        if hasattr(self, "_resource_left_stack"):
            self._resource_left_stack.setCurrentIndex(index)
        if hasattr(self, "_resource_left_top_stack"):
            self._resource_left_top_stack.setCurrentIndex(index)
        for button_index, button in getattr(self, "_resource_mode_buttons", {}).items():
            button.blockSignals(True)
            button.setChecked(button_index == index)
            button.blockSignals(False)
        QTimer.singleShot(0, self._sync_resource_result_start)
    def _sync_resource_result_start(self) -> None:
        required = (
            "_resource_left_top_panel",
            "_resource_left_header_host",
            "_resource_left_stack",
            "_resource_left_top_stack",
            "_resource_scope_top_controls",
            "_resource_search_top_controls",
            "_resource_right_top_controls",
        )
        if not all(hasattr(self, name) for name in required):
            return
        active_top = (
            self._resource_search_top_controls
            if self._resource_left_stack.currentIndex() == 1
            else self._resource_scope_top_controls
        )
        left_header_height = self._resource_left_header_host.sizeHint().height()
        left_vertical_margins = scale_px(20, self._ui_scale)
        left_gap = scale_px(8, self._ui_scale)
        left_natural_height = left_vertical_margins + left_header_height + left_gap + active_top.sizeHint().height()
        target_height = max(left_natural_height, self._resource_right_top_controls.sizeHint().height())
        active_height = max(1, target_height - left_vertical_margins - left_header_height - left_gap)
        active_top.setFixedHeight(active_height)
        self._resource_left_top_stack.setFixedHeight(active_height)
        self._resource_left_top_panel.setFixedHeight(max(1, target_height))
        self._resource_right_top_controls.setFixedHeight(max(1, target_height))
    def _on_resource_requirement_sort_changed(self, _value: object) -> None:
        selector = getattr(self, "_resource_requirement_sort", None)
        self._resource_requirement_sort_mode = selector.currentData() if selector is not None else "default"
        self._refresh_resource_view()
    def _on_resource_search_changed(self, text: str) -> None:
        if self._resource_syncing_controls:
            return
        if self._search.text() != text:
            self._search.setText(text)
    def _on_resource_sort_changed(self, _value: object) -> None:
        if self._resource_syncing_controls:
            return
        target_sort = self._resource_sort_mode.currentData()
        if self._sort_mode.currentData() == target_sort:
            return
        self._sort_mode.setCurrentData(str(target_sort))
    def _on_resource_show_unowned_changed(self, _state: int) -> None:
        if self._resource_syncing_controls:
            return
        checked = self._resource_show_unowned.isChecked()
        if self._show_unowned.isChecked() != checked:
            self._show_unowned.setChecked(checked)
    def _on_resource_hide_jp_only_changed(self, _state: int) -> None:
        if self._resource_syncing_controls:
            return
        checked = self._resource_hide_jp_only.isChecked()
        if self._hide_jp_only.isChecked() != checked:
            self._hide_jp_only.setChecked(checked)
    def _resource_compact_cost_text(self, summary: PlanCostSummary | None) -> str:
        if summary is None:
            return "아직 계획 목표 없음"
        total_materials = sum(summary.star_materials.values()) + sum(summary.equipment_materials.values()) + sum(summary.skill_books.values()) + sum(summary.ex_ooparts.values()) + sum(summary.skill_ooparts.values()) + sum(summary.favorite_item_materials.values()) + sum(summary.stat_materials.values())
        return (
            f"크레딧 {_format_count(summary.credits, compact=True)} · "
            f"EXP {_format_count(summary.level_exp, compact=True)} · "
            f"재화 {_format_count(total_materials, compact=True)}"
        )
    def _resource_focus_label(
        self,
        record: StudentRecord,
        summary: PlanCostSummary | None,
        goal_map: dict[str, StudentGoal] | None = None,
    ) -> str:
        goal_map = self._plan_goal_map() if goal_map is None else goal_map
        status = []
        status.append("계획됨" if record.student_id in goal_map else "미계획")
        status.append("보유" if record.owned else "미보유")
        if summary is None:
            return " · ".join(status)
        buckets = [
            ("스킬", sum(summary.skill_books.values()) + sum(summary.ex_ooparts.values()) + sum(summary.skill_ooparts.values())),
            ("장비", sum(summary.equipment_materials.values())),
            ("성급", sum(summary.star_materials.values())),
            ("애용품", sum(summary.favorite_item_materials.values())),
            ("능력개방", sum(summary.stat_materials.values())),
        ]
        label, amount = max(buckets, key=lambda item: item[1])
        if amount > 0:
            status.append(f"{label} 중심")
        return " · ".join(status)
    def _resource_goal_for_student(
        self,
        student_id: str,
        goal_map: dict[str, StudentGoal] | None = None,
    ) -> StudentGoal | None:
        goal_map = self._plan_goal_map() if goal_map is None else goal_map
        return goal_map.get(student_id)
    def _resource_summary_for_student(
        self,
        student_id: str,
        goal_map: dict[str, StudentGoal] | None = None,
    ) -> PlanCostSummary | None:
        record = self._records_by_id.get(student_id)
        goal = self._resource_goal_for_student(student_id, goal_map)
        if record is None or goal is None:
            return None
        return self._cached_goal_cost(student_id, record=record, goal=goal)
    def _resource_unplanned_goal_for_student(self, student_id: str) -> StudentGoal | None:
        if not (
            self._resource_include_unplanned_level
            or self._resource_include_unplanned_equipment
            or self._resource_include_unplanned_skills
        ):
            return None
        record = self._records_by_id.get(student_id)
        if record is None:
            return None
        goal = StudentGoal(student_id=student_id)
        if self._resource_include_unplanned_level:
            goal.target_level = MAX_TARGET_LEVEL
        if self._resource_include_unplanned_equipment:
            goal.target_equip1_tier = MAX_TARGET_EQUIP_TIER
            goal.target_equip2_tier = MAX_TARGET_EQUIP_TIER
            goal.target_equip3_tier = MAX_TARGET_EQUIP_TIER
            goal.target_equip1_level = MAX_TARGET_EQUIP_LEVEL
            goal.target_equip2_level = MAX_TARGET_EQUIP_LEVEL
            goal.target_equip3_level = MAX_TARGET_EQUIP_LEVEL
            if self._record_supports_unique_item(record):
                goal.target_equip4_tier = MAX_TARGET_EQUIP4_TIER
        if self._resource_include_unplanned_skills:
            goal.target_ex_skill = MAX_TARGET_EX_SKILL
            goal.target_skill1 = MAX_TARGET_SKILL
            goal.target_skill2 = MAX_TARGET_SKILL
            goal.target_skill3 = MAX_TARGET_SKILL
        return goal
    def _resource_current_student(self) -> str | None:
        if hasattr(self, "_resource_scope_grid"):
            return self._resource_scope_grid.current_card_id()
        return None
    def _refresh_resource_students_list(self) -> None:
        if not hasattr(self, "_resource_scope_grid"):
            return
        current_id = self._resource_current_student_id or self._resource_current_student()
        old_scope_cards = dict(self._resource_scope_card_by_id)
        old_search_cards = dict(self._resource_search_card_by_id)

        goal_map = self._plan_goal_map()
        visible_ids = {record.student_id for record in self._filtered_students}
        self._resource_search_pending_ids &= visible_ids
        selected_records = [
            self._records_by_id[student_id]
            for student_id in self._resource_selected_ids
            if student_id in self._records_by_id
        ]
        selected_records.sort(key=lambda record: record.title.lower())
        planned_count = sum(1 for record in selected_records if record.student_id in goal_map)

        scope_cards: list[StudentCardWidget] = []
        next_scope_by_id: dict[str, StudentCardWidget] = {}
        for record in selected_records:
            card = old_scope_cards.get(record.student_id)
            if card is None:
                card = self._build_student_card(record)
            else:
                self._apply_student_card_record(card, record)
            card.setDisplayOptions(show_name_panel=False, show_unowned_badge=True)
            scope_cards.append(card)
            next_scope_by_id[record.student_id] = card

        self._resource_scope_card_by_id = next_scope_by_id
        self._resource_scope_grid.set_cards(scope_cards)

        if scope_cards:
            restore_id = current_id if current_id in self._resource_scope_card_by_id else selected_records[0].student_id
            self._resource_scope_grid.set_current_card(restore_id)
            self._resource_current_student_id = restore_id
        else:
            self._resource_scope_grid.set_current_card(None)
            self._resource_current_student_id = None

        visible_planned = sum(1 for record in self._filtered_students if record.student_id in goal_map)
        search_cards: list[StudentCardWidget] = []
        next_search_by_id: dict[str, StudentCardWidget] = {}
        for record in self._filtered_students:
            card = old_search_cards.get(record.student_id)
            if card is None:
                card = self._build_student_card(record)
            else:
                self._apply_student_card_record(card, record)
            card.setDisplayOptions(show_name_panel=False, show_unowned_badge=True)
            card.setToolTip("")
            search_cards.append(card)
            next_search_by_id[record.student_id] = card

        self._resource_search_card_by_id = next_search_by_id
        self._resource_search_grid.set_cards(search_cards)
        self._resource_search_grid.set_selected_card_ids(set(self._resource_search_pending_ids))

        self._resource_list_summary.setText(
            f"범위 {len(selected_records)}명 · 계획 {planned_count}명 · 미계획 {len(selected_records) - planned_count}명"
        )
        if hasattr(self, "_resource_search_summary"):
            visible_selected = len(self._resource_selected_ids & {record.student_id for record in self._filtered_students})
            pending_count = len(self._resource_search_pending_ids)
            self._resource_search_summary.setText(
                f"검색 결과 {len(self._filtered_students)}명 · 계획 {visible_planned}명 · 이미 범위에 있음 {visible_selected}명 · 선택 {pending_count}명"
            )
        self._update_resource_scope_actions()
        self._update_resource_search_actions()
        for record in selected_records:
            self._enqueue_thumb(record.student_id)
        for record in self._filtered_students:
            self._enqueue_thumb(record.student_id)
        QTimer.singleShot(0, self._sync_resource_result_start)
    def _on_resource_scope_card_changed(self, current: str | None, _previous: str | None) -> None:
        self._resource_current_student_id = current
        self._update_resource_scope_actions()
    def _on_resource_search_selection_changed(self, selected_ids: object) -> None:
        if isinstance(selected_ids, set):
            self._resource_search_pending_ids = {str(student_id) for student_id in selected_ids}
        else:
            self._resource_search_pending_ids = set()
        self._refresh_resource_search_summary()
        self._update_resource_search_actions()
    def _refresh_resource_search_summary(self) -> None:
        if not hasattr(self, "_resource_search_summary"):
            return
        goal_map = self._plan_goal_map()
        visible_planned = sum(1 for record in self._filtered_students if record.student_id in goal_map)
        visible_selected = len(self._resource_selected_ids & {record.student_id for record in self._filtered_students})
        self._resource_search_summary.setText(
            f"검색 결과 {len(self._filtered_students)}명 · 계획 {visible_planned}명 · 이미 범위에 있음 {visible_selected}명 · 선택 {len(self._resource_search_pending_ids)}명"
        )
        QTimer.singleShot(0, self._sync_resource_result_start)
    def _update_resource_scope_actions(self) -> None:
        if hasattr(self, "_resource_remove_scope_button"):
            self._resource_remove_scope_button.setEnabled(bool(self._resource_current_student()))
    def _update_resource_search_actions(self) -> None:
        if hasattr(self, "_resource_add_selected_button"):
            self._resource_add_selected_button.setEnabled(bool(self._resource_search_pending_ids))
    def _on_resource_unplanned_options_changed(self, _state: int) -> None:
        self._resource_include_unplanned_level = self._resource_unplanned_level.isChecked()
        self._resource_include_unplanned_equipment = self._resource_unplanned_equipment.isChecked()
        self._resource_include_unplanned_skills = self._resource_unplanned_skills.isChecked()
        self._refresh_resource_view()
    def _resource_add_pending_to_scope(self) -> None:
        if not self._resource_search_pending_ids:
            return
        self._resource_selected_ids.update(self._resource_search_pending_ids)
        self._resource_search_pending_ids.clear()
        self._set_resource_left_mode(0)
        self._refresh_resource_students_list()
        self._refresh_resource_view()
    def _resource_remove_scope_selected(self) -> None:
        student_id = self._resource_current_student()
        if not student_id:
            return
        self._resource_selected_ids.discard(student_id)
        self._resource_search_pending_ids.discard(student_id)
        self._resource_current_student_id = None
        self._refresh_resource_students_list()
        self._refresh_resource_view()
    def _resource_clear_search_selection(self) -> None:
        self._resource_search_pending_ids.clear()
        if hasattr(self, "_resource_search_grid"):
            self._resource_search_grid.set_selected_card_ids(set())
        self._refresh_resource_search_summary()
        self._update_resource_search_actions()
    def _resource_check_visible(self) -> None:
        self._resource_selected_ids.update(record.student_id for record in self._filtered_students)
        self._resource_search_pending_ids.clear()
        self._set_resource_left_mode(0)
        self._refresh_resource_students_list()
        self._refresh_resource_view()
    def _resource_check_visible_planned(self) -> None:
        goal_map = self._plan_goal_map()
        self._resource_selected_ids.update(record.student_id for record in self._filtered_students if record.student_id in goal_map)
        self._resource_search_pending_ids.clear()
        self._set_resource_left_mode(0)
        self._refresh_resource_students_list()
        self._refresh_resource_view()
    def _resource_clear_checked(self) -> None:
        self._resource_selected_ids.clear()
        self._resource_search_pending_ids.clear()
        self._resource_current_student_id = None
        self._refresh_resource_students_list()
        self._refresh_resource_view()
    def _resource_total_for_ids(
        self,
        student_ids: list[str] | tuple[str, ...] | set[str],
        goal_map: dict[str, StudentGoal] | None = None,
    ) -> tuple[PlanCostSummary, int, int]:
        goal_map = self._plan_goal_map() if goal_map is None else goal_map
        ordered_ids = [student_id for student_id in student_ids if student_id in self._records_by_id]
        total = PlanCostSummary()
        contributing_count = 0
        for student_id in ordered_ids:
            record = self._records_by_id[student_id]
            if student_id in goal_map:
                summary = self._cached_goal_cost(student_id, record=record, goal=goal_map[student_id])
            else:
                unplanned_goal = self._resource_unplanned_goal_for_student(student_id)
                summary = calculate_goal_cost(record, unplanned_goal) if unplanned_goal is not None else None
            if summary is None:
                continue
            total.merge(summary)
            contributing_count += 1
        return total, len(ordered_ids), contributing_count
    def _set_output_from_summary(self, target: QListWidget, summary: PlanCostSummary | None) -> None:
        target.clear()
        if summary is None:
            target.addItem("이 선택에 사용할 계획 목표가 아직 없습니다.")
            return

        sections: list[tuple[str, list[tuple[str, int]]]] = []
        if summary.credits:
            sections.append(("크레딧", [("크레딧", summary.credits)]))
        if summary.level_exp:
            sections.append(("레벨 EXP", [("레벨 EXP", summary.level_exp)] + sorted(summary.level_exp_items.items(), key=lambda item: (-item[1], item[0]))))
        if summary.equipment_exp or summary.equipment_exp_items:
            rows = []
            if summary.equipment_exp:
                rows.append(("장비 EXP", summary.equipment_exp))
            rows.extend(sorted(summary.equipment_exp_items.items(), key=lambda item: (-item[1], item[0])))
            sections.append(("장비 EXP", rows))
        if summary.weapon_exp or summary.weapon_exp_items:
            rows = []
            if summary.weapon_exp:
                rows.append(("무기 EXP", summary.weapon_exp))
            rows.extend(sorted(summary.weapon_exp_items.items(), key=lambda item: (-item[1], item[0])))
            sections.append(("무기 EXP", rows))
        for heading, mapping in (("성급 재화", summary.star_materials), ("장비 재화", summary.equipment_materials), ("스킬북", summary.skill_books), ("EX 오파츠", summary.ex_ooparts), ("일반 스킬 오파츠", summary.skill_ooparts), ("애용품 재화", summary.favorite_item_materials), ("능력개방 재화", summary.stat_materials)):
            if mapping:
                sections.append((heading, sorted(mapping.items(), key=lambda item: (-item[1], item[0]))))
        if summary.stat_levels:
            sections.append(("능력개방 목표", sorted(summary.stat_levels.items(), key=lambda item: item[0])))

        if not sections and summary.warnings:
            for warning in dict.fromkeys(summary.warnings):
                target.addItem(warning)
            return

        for heading, rows in sections:
            heading_item = QListWidgetItem(heading)
            heading_item.setFlags(Qt.ItemIsEnabled)
            target.addItem(heading_item)
            for key, value in rows:
                target.addItem(f"  {key}: {_format_count(value, compact=True)}" if isinstance(value, int) else f"  {key}: {value}")
        if summary.warnings:
            target.addItem("메모")
            for warning in dict.fromkeys(summary.warnings):
                target.addItem(f"  {warning}")
    def _clear_requirement_grid(self, grid: QGridLayout) -> None:
        while grid.count():
            item = grid.takeAt(0)
            widget = item.widget()
            if widget is not None:
                widget.deleteLater()
    def _clear_layout_widgets(self, layout) -> None:
        while layout.count():
            item = layout.takeAt(0)
            widget = item.widget()
            child_layout = item.layout()
            if widget is not None:
                widget.deleteLater()
            elif child_layout is not None:
                self._clear_layout_widgets(child_layout)
    def _populate_requirement_grid(
        self,
        grid: QGridLayout,
        entries: list[PlanResourceRequirement],
        *,
        columns: int = 3,
    ) -> None:
        for index, requirement in enumerate(entries):
            chip = PlanResourceChip(ui_scale=self._ui_scale)
            chip.setData(requirement)
            grid.addWidget(chip, index // columns, index % columns)
    def _sort_resource_requirement_entries(
        self,
        entries: list[PlanResourceRequirement],
    ) -> list[PlanResourceRequirement]:
        if getattr(self, "_resource_requirement_sort_mode", "default") != "shortage_ratio":
            return entries
        return sorted(
            entries,
            key=lambda entry: (
                -(max(0, entry.required - entry.owned) / max(1, entry.required)),
                -max(0, entry.required - entry.owned),
                -entry.required,
                entry.name.casefold(),
            ),
        )
    def _refresh_resource_view(self) -> None:
        if not hasattr(self, "_resource_requirement_grid"):
            return
        self._refresh_resource_aggregate_view()
    def _is_resource_tab_current(self) -> bool:
        return (
            self._main_tabs is not None
            and self._resource_tab is not None
            and self._main_tabs.currentWidget() is self._resource_tab
        )
    def _refresh_resources_if_visible(self) -> None:
        if self._is_resource_tab_current():
            self._refresh_resource_students_list()
            self._refresh_resource_view()
            self._resources_dirty = False
        else:
            self._resources_dirty = True
    def _on_main_tab_changed(self, _index: int) -> None:
        if self._resources_dirty and self._is_resource_tab_current():
            self._refresh_resource_students_list()
            self._refresh_resource_view()
            self._resources_dirty = False
        if getattr(self, "_main_tabs", None) is not None and self._main_tabs.currentWidget() is getattr(self, "_inventory_tab", None):
            self._schedule_inventory_layout_sync()
