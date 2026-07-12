"""PlannerTabComponent implementation extracted from the viewer façade."""

from __future__ import annotations

from gui import viewer_shared as _viewer_shared

globals().update({name: value for name, value in vars(_viewer_shared).items() if not name.startswith("__")})


class PlannerTabComponent:
    def _build_plan_tab(self, root: QWidget) -> None:
        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, scale_px(12, self._ui_scale))
        layout.setSpacing(scale_px(12, self._ui_scale))

        header = QFrame()
        header.setObjectName("header")
        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
        )
        header_layout.setSpacing(scale_px(10, self._ui_scale))

        title = QLabel("계획 작업공간")
        title.setObjectName("title")
        header_layout.addWidget(title)

        summary = QLabel("필요할 때만 검색하고, 계획 학생은 학생 탭처럼 카드로 관리합니다.")
        summary.setObjectName("count")
        header_layout.addWidget(summary, 1)
        layout.addWidget(header)

        quick_add_panel = QFrame()
        self._plan_quick_add_panel = quick_add_panel
        quick_add_panel.setObjectName("planBand")
        quick_add_layout = QVBoxLayout(quick_add_panel)
        quick_add_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(12, self._ui_scale),
        )
        quick_add_layout.setSpacing(scale_px(8, self._ui_scale))

        quick_add_header = QHBoxLayout()
        quick_add_header.setContentsMargins(0, 0, 0, 0)
        quick_add_header.setSpacing(scale_px(10, self._ui_scale))
        title_add = QLabel("빠른 추가")
        title_add.setObjectName("sectionTitle")
        quick_add_header.addWidget(title_add)
        quick_add_note = QLabel("필요할 때만 학생 이름, ID, 태그로 검색하세요.")
        quick_add_note.setObjectName("count")
        quick_add_note.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        quick_add_header.addWidget(quick_add_note, 1)
        quick_add_layout.addLayout(quick_add_header)

        quick_add_row = QHBoxLayout()
        quick_add_row.setContentsMargins(0, 0, 0, 0)
        quick_add_row.setSpacing(scale_px(8, self._ui_scale))
        self._plan_search = LiveSearchLineEdit()
        self._plan_search.setPlaceholderText("학생 이름, ID, 태그 입력")
        self._plan_search.liveTextChanged.connect(self._schedule_plan_search_refresh)
        quick_add_row.addWidget(self._plan_search, 1)
        self._plan_add_button = QPushButton("추가")
        self._plan_add_button.clicked.connect(self._add_selected_student_to_plan)
        quick_add_row.addWidget(self._plan_add_button, 0, Qt.AlignVCenter)
        quick_add_layout.addLayout(quick_add_row)

        self._plan_search_card_by_id: dict[str, StudentCardWidget] = {}
        plan_search_width = max(scale_px(80, self._ui_scale), int(round(self._student_card_asset.base_size.width() * 0.5)))
        self._plan_search_grid = ParallelogramCardGrid(
            self._student_card_asset,
            self._ui_scale,
            drag_enabled=True,
            min_card_width=plan_search_width,
            fixed_card_width=True,
        )
        self._plan_search_grid.setObjectName("studentGrid")
        plan_search_grid_height = max(
            scale_px(150, self._ui_scale),
            int(round(plan_search_width / self._student_card_asset.aspect_ratio)) + scale_px(28, self._ui_scale),
        )
        plan_search_panel_vertical_margins = scale_px(20, self._ui_scale)
        self._plan_search_grid.setFixedHeight(plan_search_grid_height)
        self._plan_search_grid.setFrameShape(QFrame.NoFrame)
        self._plan_search_grid.setAutoFillBackground(False)
        self._plan_search_grid.setAttribute(Qt.WA_TranslucentBackground, True)
        self._plan_search_grid.viewport().setAutoFillBackground(False)
        self._plan_search_grid.viewport().setAttribute(Qt.WA_TranslucentBackground, True)
        self._plan_search_grid.viewport().setStyleSheet("background: transparent; border: none;")
        if self._plan_search_grid.widget() is not None:
            self._plan_search_grid.widget().setAutoFillBackground(False)
            self._plan_search_grid.widget().setAttribute(Qt.WA_TranslucentBackground, True)
            self._plan_search_grid.widget().setStyleSheet("background: transparent; border: none;")
        _install_planner_scroll_handle(self._plan_search_grid, ui_scale=self._ui_scale)
        self._plan_search_grid.current_changed.connect(self._on_plan_search_card_changed)
        self._plan_search_grid.card_drag_moved.connect(self._on_plan_search_card_drag_moved)
        self._plan_search_grid.card_drag_finished.connect(self._on_plan_search_card_drag_finished)
        self._plan_search_grid.setVisible(False)
        self._plan_search_grid_panel = PlanGridContentPanel(ui_scale=self._ui_scale)
        self._plan_search_grid_panel.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self._plan_search_grid_panel.setFixedHeight(plan_search_grid_height + plan_search_panel_vertical_margins)
        self._plan_search_grid_panel.setVisible(False)
        plan_search_grid_panel_layout = QVBoxLayout(self._plan_search_grid_panel)
        plan_search_grid_panel_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        plan_search_grid_panel_layout.setSpacing(0)
        plan_search_grid_panel_layout.addWidget(self._plan_search_grid)
        quick_add_layout.addWidget(self._plan_search_grid_panel)

        self._plan_search_state = QLabel("학생 순서를 드래그해서 변경할 수 있으며, 학생 순서대로 인벤토리 탭에서 재화 우선 목표를 보여줍니다.")
        self._plan_search_state.setObjectName("filterSummary")
        self._plan_search_state.setWordWrap(True)
        quick_add_layout.addWidget(self._plan_search_state)

        splitter = QSplitter(Qt.Horizontal)
        splitter.setObjectName("sectionSplitter")
        splitter.setChildrenCollapsible(False)
        layout.addWidget(splitter, 1)

        plan_panel = QFrame()
        self._plan_panel = plan_panel
        plan_panel.setObjectName("planSectionPanel")
        plan_layout = QVBoxLayout(plan_panel)
        plan_layout.setContentsMargins(scale_px(14, self._ui_scale), scale_px(14, self._ui_scale), scale_px(14, self._ui_scale), scale_px(14, self._ui_scale))
        plan_layout.setSpacing(scale_px(10, self._ui_scale))

        plan_header = QHBoxLayout()
        plan_header.setContentsMargins(0, 0, 0, 0)
        plan_header.setSpacing(scale_px(10, self._ui_scale))
        title_plan = QLabel("계획 학생")
        title_plan.setObjectName("sectionTitle")
        plan_header.addWidget(title_plan)
        self._plan_count_label = QLabel("")
        self._plan_count_label.setObjectName("count")
        plan_header.addWidget(self._plan_count_label, 1, Qt.AlignRight)
        plan_layout.addLayout(plan_header)

        self._plan_empty_label = QLabel("아직 계획에 학생이 없습니다. 아래 빠른 추가에서 첫 학생을 추가하세요.")
        self._plan_empty_label.setObjectName("filterSummary")
        self._plan_empty_label.setWordWrap(True)
        plan_layout.addWidget(self._plan_empty_label)

        self._plan_grid_panel = PlanGridContentPanel(ui_scale=self._ui_scale)
        plan_grid_layout = QVBoxLayout(self._plan_grid_panel)
        plan_grid_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        plan_grid_layout.setSpacing(0)

        self._plan_grid = ParallelogramCardGrid(
            self._student_card_asset,
            self._ui_scale,
            reorder_enabled=True,
            min_card_width=self._plan_grid_card_width,
            fixed_column_count=PLAN_GRID_COLUMNS,
        )
        self._plan_grid.setObjectName("studentGrid")
        self._plan_grid.setFrameShape(QFrame.NoFrame)
        self._plan_grid.setAutoFillBackground(False)
        self._plan_grid.setAttribute(Qt.WA_TranslucentBackground, True)
        self._plan_grid.viewport().setAutoFillBackground(False)
        self._plan_grid.viewport().setAttribute(Qt.WA_TranslucentBackground, True)
        self._plan_grid.viewport().setStyleSheet("background: transparent; border: none;")
        if self._plan_grid.widget() is not None:
            self._plan_grid.widget().setAutoFillBackground(False)
            self._plan_grid.widget().setAttribute(Qt.WA_TranslucentBackground, True)
            self._plan_grid.widget().setStyleSheet("background: transparent; border: none;")
        _install_planner_scroll_handle(self._plan_grid, ui_scale=self._ui_scale)
        self._plan_grid.current_changed.connect(self._on_plan_card_changed)
        self._plan_grid.layout_changed.connect(self._on_plan_grid_layout_changed)
        self._plan_grid.order_changed.connect(self._on_plan_order_changed)
        plan_grid_layout.addWidget(self._plan_grid, 1)
        plan_layout.addWidget(self._plan_grid_panel, 1)

        plan_layout.addWidget(quick_add_panel, 0)

        plan_buttons = QHBoxLayout()
        self._plan_remove_button = QPushButton("제거")
        self._plan_remove_button.clicked.connect(self._remove_selected_plan_student)
        plan_buttons.addWidget(self._plan_remove_button)
        self._plan_open_button = QPushButton("학생 탭에서 보기")
        self._plan_open_button.clicked.connect(self._focus_selected_plan_student_in_viewer)
        plan_buttons.addWidget(self._plan_open_button)
        plan_buttons.addStretch(1)
        plan_layout.addLayout(plan_buttons)

        splitter.addWidget(plan_panel)

        editor_panel = RoundedMaskFrame(ui_scale=self._ui_scale)
        editor_panel.setObjectName("planEditorInventoryShell")
        editor_panel.setFrameShape(QFrame.NoFrame)
        editor_panel.setAutoFillBackground(False)
        editor_panel.setAttribute(Qt.WA_StyledBackground, True)
        editor_outer_layout = QVBoxLayout(editor_panel)
        self._configure_inventory_panel_layout(editor_outer_layout)

        editor_scroll = QScrollArea()
        editor_scroll.setObjectName("sectionScrollArea")
        editor_scroll.setWidgetResizable(True)
        editor_scroll.setFrameShape(QFrame.NoFrame)
        editor_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        editor_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        _install_planner_scroll_handle(editor_scroll, ui_scale=self._ui_scale)
        editor_outer_layout.addWidget(editor_scroll, 1)

        editor_content = QWidget()
        editor_content.setObjectName("planTransparent")
        editor_layout = QVBoxLayout(editor_content)
        editor_layout.setContentsMargins(scale_px(16, self._ui_scale), scale_px(16, self._ui_scale), scale_px(16, self._ui_scale), scale_px(16, self._ui_scale))
        editor_layout.setSpacing(scale_px(10, self._ui_scale))
        editor_scroll.setWidget(editor_content)

        editor_header = PlanEditorSectionCard(ui_scale=self._ui_scale, radius=16)
        editor_header_layout = QHBoxLayout(editor_header)
        editor_header_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
        )
        editor_header_layout.setSpacing(scale_px(10, self._ui_scale))
        name_col = QVBoxLayout()
        name_col.setContentsMargins(0, 0, 0, 0)
        name_col.setSpacing(scale_px(2, self._ui_scale))
        self._plan_name = QLabel("학생을 선택하세요")
        self._plan_name.setObjectName("detailName")
        name_col.addWidget(self._plan_name)
        self._plan_current = QLabel("")
        self._plan_current.setObjectName("detailSub")
        name_col.addWidget(self._plan_current)
        editor_header_layout.addLayout(name_col, 1)

        plan_editor_stack = QStackedWidget()
        plan_editor_stack.setObjectName("planEditorStack")
        plan_editor_stack.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        plan_editor_mode_buttons = QHBoxLayout()
        plan_editor_mode_buttons.setContentsMargins(0, 0, 0, 0)
        plan_editor_mode_buttons.setSpacing(scale_px(8, self._ui_scale))
        plan_editor_buttons: dict[int, QPushButton] = {}

        def sync_plan_editor_buttons(index: int) -> None:
            for button_index, button in plan_editor_buttons.items():
                button.setChecked(button_index == index)

        for index, label in ((0, "목표 타겟"), (1, "필요 재화")):
            button = QPushButton(label)
            button.setObjectName("inventoryModeButton")
            button.setCheckable(True)
            button.clicked.connect(lambda _checked=False, value=index: plan_editor_stack.setCurrentIndex(value))
            plan_editor_mode_buttons.addWidget(button, 0)
            plan_editor_buttons[index] = button
        plan_editor_mode_buttons.addStretch(1)
        plan_editor_stack.currentChanged.connect(sync_plan_editor_buttons)
        editor_header_layout.addLayout(plan_editor_mode_buttons, 0)
        editor_layout.addWidget(editor_header)

        edit_tab = QWidget()
        edit_tab.setObjectName("planTransparent")
        edit_tab_layout = QVBoxLayout(edit_tab)
        edit_tab_layout.setContentsMargins(0, 0, 0, 0)
        edit_tab_layout.setSpacing(0)
        resources_tab = QWidget()
        resources_tab.setObjectName("planTransparent")
        resources_tab_layout = QVBoxLayout(resources_tab)
        resources_tab_layout.setContentsMargins(0, 0, 0, 0)
        resources_tab_layout.setSpacing(0)

        controls_wrap = PlanEditorContentPanel(ui_scale=self._ui_scale)
        controls_wrap.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        controls_layout = QVBoxLayout(controls_wrap)
        controls_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        controls_layout.setSpacing(0)

        self._plan_controls_scroll = QScrollArea()
        self._plan_controls_scroll.setObjectName("sectionScrollArea")
        self._plan_controls_scroll.setFrameShape(QFrame.NoFrame)
        self._plan_controls_scroll.setWidgetResizable(True)
        self._plan_controls_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self._plan_controls_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        self._plan_controls_scroll.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        _install_planner_scroll_handle(self._plan_controls_scroll, ui_scale=self._ui_scale)

        controls_content = QWidget()
        controls_content.setObjectName("planTransparent")
        controls_content_layout = QVBoxLayout(controls_content)
        controls_content_layout.setContentsMargins(0, 0, 0, 0)
        controls_content_layout.setSpacing(scale_px(10, self._ui_scale))
        self._plan_controls_scroll.setWidget(controls_content)
        controls_layout.addWidget(self._plan_controls_scroll, 1)

        def add_plan_level_row(
            parent_layout: QVBoxLayout,
            field_name: str,
            label: str,
            maximum: int,
            *,
            label_width: int = 62,
        ) -> QFrame:
            row = QFrame()
            row.setObjectName("inventoryPressureRow")
            row_layout = QHBoxLayout(row)
            row_layout.setContentsMargins(
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
            )
            row_layout.setSpacing(scale_px(8, self._ui_scale))
            row_title = QLabel(label)
            row_title.setObjectName("detailSectionTitle")
            row_title.setMinimumWidth(scale_px(label_width, self._ui_scale))
            self._plan_level_row_labels[field_name] = row_title
            row_layout.addWidget(row_title)
            selector = PlanStepper(maximum, ui_scale=self._ui_scale)
            selector.valueChanged.connect(lambda value, name=field_name: self._on_plan_digit_changed(name, value))
            self._plan_level_inputs[field_name] = selector
            self._plan_level_rows[field_name] = row
            row_layout.addWidget(selector, 1)
            parent_layout.addWidget(row)
            return row

        progression_panel = PlanEditorSectionCard(ui_scale=self._ui_scale)
        progression_layout = QVBoxLayout(progression_panel)
        progression_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        progression_layout.setSpacing(scale_px(8, self._ui_scale))
        progression_title = QLabel("목표 타겟")
        progression_title.setObjectName("sectionTitle")
        progression_layout.addWidget(progression_title)
        progression_row = QFrame()
        progression_row.setObjectName("inventoryPressureRow")
        progression_row_layout = QHBoxLayout(progression_row)
        progression_row_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        progression_row_layout.setSpacing(scale_px(12, self._ui_scale))
        progression_label = QLabel("성작 상태")
        progression_label.setObjectName("detailSectionTitle")
        progression_label.setMinimumWidth(scale_px(118, self._ui_scale))
        progression_row_layout.addWidget(progression_label, 0, Qt.AlignTop)
        star_selector = PlanSegmentSelector(9, color_break=5, ui_scale=self._ui_scale)
        star_selector.valueChanged.connect(lambda value: self._on_plan_segment_changed("star_weapon", value))
        self._plan_segment_inputs["star_weapon"] = star_selector
        progression_row_layout.addWidget(star_selector, 1)
        progression_layout.addWidget(progression_row)

        add_plan_level_row(progression_layout, "target_level", "학생 레벨", 90, label_width=118)
        add_plan_level_row(progression_layout, "target_weapon_level", "전용무기 레벨", MAX_TARGET_WEAPON_LEVEL, label_width=118)

        stat_toggle = QPushButton()
        stat_toggle.setObjectName("planDisclosureButton")
        stat_toggle.clicked.connect(self._toggle_ability_release_targets)
        progression_layout.addWidget(stat_toggle)
        self._plan_stat_caption = stat_toggle
        self._update_ability_release_toggle_text()

        for field_name, label in (
            ("target_stat_hp", "HP"),
            ("target_stat_atk", "ATK"),
            ("target_stat_heal", "HEAL"),
        ):
            row = add_plan_level_row(progression_layout, field_name, label, 25, label_width=118)
            self._plan_stat_rows[field_name] = row

        controls_content_layout.addWidget(progression_panel)

        requirement_panel = PlanEditorSectionCard(ui_scale=self._ui_scale)
        requirement_panel.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        requirement_layout = QVBoxLayout(requirement_panel)
        requirement_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        requirement_layout.setSpacing(scale_px(8, self._ui_scale))
        requirement_header = QHBoxLayout()
        requirement_header.setContentsMargins(0, 0, 0, 0)
        requirement_header.setSpacing(scale_px(10, self._ui_scale))
        requirement_title = QLabel("필요 재화")
        requirement_title.setObjectName("sectionTitle")
        requirement_header.addWidget(requirement_title)
        self._plan_requirement_summary = QLabel("선택 학생 · 필요 / 보유")
        self._plan_requirement_summary.setObjectName("count")
        self._plan_requirement_summary.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        requirement_header.addWidget(self._plan_requirement_summary, 1)
        requirement_layout.addLayout(requirement_header)

        self._plan_requirement_empty = QLabel("계획 학생을 선택하고 목표를 지정하면 필요한 재화를 미리 볼 수 있습니다.")
        self._plan_requirement_empty.setObjectName("filterSummary")
        self._plan_requirement_empty.setWordWrap(True)
        self._plan_requirement_empty.setMinimumHeight(scale_px(22, self._ui_scale))
        requirement_layout.addWidget(self._plan_requirement_empty)

        self._plan_requirement_scroll = QScrollArea()
        self._plan_requirement_scroll.setObjectName("sectionScrollArea")
        self._plan_requirement_scroll.setFrameShape(QFrame.NoFrame)
        self._plan_requirement_scroll.setWidgetResizable(True)
        self._plan_requirement_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self._plan_requirement_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        self._plan_requirement_scroll.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        _install_planner_scroll_handle(self._plan_requirement_scroll, ui_scale=self._ui_scale)

        self._plan_requirement_grid_host = QWidget()
        self._plan_requirement_grid_host.setObjectName("planTransparent")
        self._plan_requirement_grid_host.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        self._plan_requirement_grid = QGridLayout(self._plan_requirement_grid_host)
        self._plan_requirement_grid.setContentsMargins(
            scale_px(6, self._ui_scale),
            scale_px(6, self._ui_scale),
            scale_px(6, self._ui_scale),
            scale_px(6, self._ui_scale),
        )
        self._plan_requirement_grid.setHorizontalSpacing(scale_px(8, self._ui_scale))
        self._plan_requirement_grid.setVerticalSpacing(scale_px(8, self._ui_scale))
        self._plan_requirement_grid.setAlignment(Qt.AlignTop)
        for column in range(3):
            self._plan_requirement_grid.setColumnStretch(column, 1)
        self._plan_requirement_scroll.setWidget(self._plan_requirement_grid_host)
        requirement_layout.addWidget(self._plan_requirement_scroll, 1)

        skill_panel = PlanEditorSectionCard(ui_scale=self._ui_scale)
        skill_layout = QVBoxLayout(skill_panel)
        skill_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        skill_layout.setSpacing(scale_px(8, self._ui_scale))
        skill_title = QLabel("스킬")
        skill_title.setObjectName("sectionTitle")
        skill_layout.addWidget(skill_title)
        for field_name, label, count in (
            ("target_ex_skill", "EX", MAX_TARGET_EX_SKILL),
            ("target_skill1", "Skill1", MAX_TARGET_SKILL),
            ("target_skill2", "Skill2", MAX_TARGET_SKILL),
            ("target_skill3", "Skill3", MAX_TARGET_SKILL),
        ):
            row = QFrame()
            row.setObjectName("inventoryPressureRow")
            row_layout = QHBoxLayout(row)
            row_layout.setContentsMargins(
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
            )
            row_layout.setSpacing(scale_px(12, self._ui_scale))
            row_title = QLabel(label)
            row_title.setObjectName("detailSectionTitle")
            row_title.setMinimumWidth(scale_px(64, self._ui_scale))
            row_layout.addWidget(row_title)
            selector = PlanSegmentSelector(count, active_fill=ACCENT_STRONG, active_border=ACCENT, ui_scale=self._ui_scale)
            selector.valueChanged.connect(lambda value, name=field_name: self._on_plan_segment_changed(name, value))
            self._plan_segment_inputs[field_name] = selector
            row_layout.addWidget(selector, 1)
            skill_layout.addWidget(row)
        controls_content_layout.addWidget(skill_panel, 0)

        equipment_panel = PlanEditorSectionCard(ui_scale=self._ui_scale)
        equipment_layout = QVBoxLayout(equipment_panel)
        equipment_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        equipment_layout.setSpacing(scale_px(8, self._ui_scale))
        equipment_title = QLabel("장비 티어")
        equipment_title.setObjectName("sectionTitle")
        equipment_layout.addWidget(equipment_title)

        equipment_body = QWidget()
        equipment_body.setObjectName("planTransparent")
        equipment_body_layout = QHBoxLayout(equipment_body)
        equipment_body_layout.setContentsMargins(0, 0, 0, 0)
        equipment_body_layout.setSpacing(scale_px(10, self._ui_scale))
        equipment_main = QVBoxLayout()
        equipment_main.setContentsMargins(0, 0, 0, 0)
        equipment_main.setSpacing(scale_px(10, self._ui_scale))
        equipment_body_layout.addLayout(equipment_main, 9)

        self._plan_unique_item_panel = QFrame()
        self._plan_unique_item_panel.setObjectName("inventoryPressureRow")
        unique_layout = QVBoxLayout(self._plan_unique_item_panel)
        unique_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        unique_layout.setSpacing(scale_px(8, self._ui_scale))
        unique_title = QLabel("애용품")
        unique_title.setObjectName("detailSectionTitle")
        unique_layout.addWidget(unique_title)
        self._plan_unique_item_selector = PlanSegmentSelector(2, active_fill=PALETTE_SOFT, active_border="#ffffff", inactive_fill=_mix_hex(SURFACE_ALT, BG, 0.14), ui_scale=self._ui_scale)
        self._plan_unique_item_selector.valueChanged.connect(lambda value: self._on_plan_segment_changed("target_equip4_tier", value))
        self._plan_segment_inputs["target_equip4_tier"] = self._plan_unique_item_selector
        unique_layout.addWidget(self._plan_unique_item_selector)
        equipment_body_layout.addWidget(self._plan_unique_item_panel, 3)
        equipment_layout.addWidget(equipment_body)

        for field_name, slot_index in (
            ("target_equip1_tier", 1),
            ("target_equip2_tier", 2),
            ("target_equip3_tier", 3),
        ):
            row = QFrame()
            row.setObjectName("inventoryPressureRow")
            row_layout = QHBoxLayout(row)
            row_layout.setContentsMargins(
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
            )
            row_layout.setSpacing(scale_px(10, self._ui_scale))
            row_title = QLabel(f"장비 {slot_index}")
            row_title.setObjectName("detailSectionTitle")
            row_title.setMinimumWidth(scale_px(70, self._ui_scale))
            self._plan_equipment_labels[field_name] = row_title
            row_layout.addWidget(row_title)
            control_stack = QVBoxLayout()
            control_stack.setContentsMargins(0, 0, 0, 0)
            control_stack.setSpacing(scale_px(8, self._ui_scale))
            selector = PlanSegmentSelector(MAX_TARGET_EQUIP_TIER, active_fill=PALETTE_SOFT, active_border="#ffffff", inactive_fill=_mix_hex(SURFACE_ALT, BG, 0.14), ui_scale=self._ui_scale)
            selector.valueChanged.connect(lambda value, name=field_name: self._on_plan_segment_changed(name, value))
            self._plan_segment_inputs[field_name] = selector
            control_stack.addWidget(selector)

            level_field_name = f"target_equip{slot_index}_level"
            level_row = QWidget()
            level_row.setObjectName("planTransparent")
            level_layout = QHBoxLayout(level_row)
            level_layout.setContentsMargins(0, 0, 0, 0)
            level_layout.setSpacing(scale_px(8, self._ui_scale))
            level_title = QLabel("레벨")
            level_title.setObjectName("detailSectionTitle")
            level_title.setMinimumWidth(scale_px(54, self._ui_scale))
            self._plan_level_row_labels[level_field_name] = row_title
            level_layout.addWidget(level_title)
            level_selector = PlanStepper(MAX_TARGET_EQUIP_LEVEL, ui_scale=self._ui_scale)
            level_selector.valueChanged.connect(lambda value, name=level_field_name: self._on_plan_digit_changed(name, value))
            self._plan_level_inputs[level_field_name] = level_selector
            self._plan_level_rows[level_field_name] = level_row
            level_layout.addWidget(level_selector, 1)
            control_stack.addWidget(level_row)

            row_layout.addLayout(control_stack, 1)
            equipment_main.addWidget(row)
        controls_content_layout.addWidget(equipment_panel, 0)

        self._plan_student_summary = QLabel("필요 재화 미리보기가 여기에 표시됩니다.")
        self._plan_total_summary = QLabel("")
        self._plan_student_summary.setVisible(False)
        self._plan_total_summary.setVisible(False)
        controls_content_layout.addStretch(1)
        edit_tab_layout.addWidget(controls_wrap, 1)
        resources_tab_layout.addWidget(requirement_panel, 1)
        plan_editor_stack.addWidget(edit_tab)
        plan_editor_stack.addWidget(resources_tab)
        plan_editor_stack.setCurrentIndex(0)
        sync_plan_editor_buttons(0)
        editor_layout.addWidget(plan_editor_stack, 1)
        splitter.addWidget(editor_panel)

        splitter.setStretchFactor(0, 5)
        splitter.setStretchFactor(1, 3)
    def _plan_goal_map(self) -> dict[str, StudentGoal]:
        if self._plan_goal_map_cache is None:
            self._plan_goal_map_cache = self._plan.goal_map()
        return self._plan_goal_map_cache
    def _invalidate_plan_caches(self, student_id: str | None = None) -> None:
        self._plan_goal_map_cache = None
        if student_id is None:
            self._plan_cost_cache.clear()
            return
        for cache_key in [cache_key for cache_key in self._plan_cost_cache if cache_key[0] == student_id]:
            del self._plan_cost_cache[cache_key]
    def _plan_priority_index(self) -> dict[str, int]:
        return {goal.student_id: index for index, goal in enumerate(self._plan.goals)}
    def _planned_student_ids(self) -> set[str]:
        return {goal.student_id for goal in self._plan.goals if goal.student_id in self._records_by_id}
    def _add_plan_student_to_resource_scope(self, student_id: str) -> None:
        if student_id in self._records_by_id:
            self._resource_selected_ids.add(student_id)
    def _goal_cache_signature(self, goal: StudentGoal) -> tuple[object, ...]:
        return tuple(getattr(goal, field_name, None) for field_name in _PLAN_GOAL_CACHE_FIELDS)
    def _cached_goal_cost(
        self,
        student_id: str,
        *,
        record: StudentRecord | None = None,
        goal: StudentGoal | None = None,
        goal_map: dict[str, StudentGoal] | None = None,
    ) -> PlanCostSummary | None:
        record = record or self._records_by_id.get(student_id)
        if goal is None:
            goal_map = self._plan_goal_map() if goal_map is None else goal_map
            goal = goal_map.get(student_id)
        if record is None or goal is None:
            return None
        cache_key = (student_id, self._goal_cache_signature(goal))
        summary = self._plan_cost_cache.get(cache_key)
        if summary is None:
            summary = calculate_goal_cost(record, goal)
            self._plan_cost_cache[cache_key] = summary
        return summary
    def _cached_plan_resource_icon_path(self, item_id: str | None, name: str) -> Path | None:
        cache_key = (item_id, name)
        if cache_key not in self._plan_resource_icon_path_cache:
            self._plan_resource_icon_path_cache[cache_key] = _plan_resource_icon_path(item_id, name)
        return self._plan_resource_icon_path_cache[cache_key]
    def _cached_plan_resource_pixmap(self, icon_path: Path | None) -> QPixmap | None:
        if icon_path is None:
            return None
        pixmap = self._plan_resource_pixmap_cache.get(icon_path)
        if pixmap is None:
            pixmap = QPixmap(str(icon_path)) if icon_path.exists() else QPixmap()
            self._plan_resource_pixmap_cache[icon_path] = pixmap
        return pixmap if not pixmap.isNull() else None
    def _save_plan(self) -> None:
        save_plan(self._plan_path, self._plan)
        try:
            self._storage_mtimes[self._plan_path] = self._plan_path.stat().st_mtime_ns
        except OSError:
            self._storage_mtimes[self._plan_path] = None
    def _get_or_create_goal(self, student_id: str) -> StudentGoal:
        for goal in self._plan.goals:
            if goal.student_id == student_id:
                return goal
        goal = StudentGoal(student_id=student_id)
        self._plan.goals.append(goal)
        self._invalidate_plan_caches(student_id)
        return goal
    def _apply_student_card_record(self, card: StudentCardWidget, record: StudentRecord) -> None:
        divider_primary, divider_secondary = _student_divider_colors(record)
        card.setData(
            title=record.title,
            owned=record.owned,
            divider_left=QColor(divider_primary),
            divider_right=QColor(divider_secondary),
        )
        card.setToolTip("")
    def _build_student_card(
        self,
        record,
        *,
        show_name_panel: bool = True,
        show_unowned_badge: bool = True,
    ) -> StudentCardWidget:
        divider_primary, divider_secondary = _student_divider_colors(record)
        card = StudentCardWidget(
            card_asset=self._student_card_asset,
            student_id=record.student_id,
            title=record.title,
            owned=record.owned,
            divider_left=QColor(divider_primary),
            divider_right=QColor(divider_secondary),
            show_name_panel=show_name_panel,
            show_unowned_badge=show_unowned_badge,
        )
        card.setToolTip("")
        self._apply_cached_thumb_to_card(card)
        return card
    def _current_plan_grid_student_id(self) -> str | None:
        if not hasattr(self, "_plan_grid"):
            return None
        return self._plan_grid.current_card_id()
    def _set_plan_search_selection(self, student_id: str | None) -> None:
        if not hasattr(self, "_plan_search_grid"):
            return
        target_id = student_id if student_id in self._plan_search_card_by_id else None
        previous = self._plan_search_grid.blockSignals(True)
        try:
            self._plan_search_grid.set_current_card(target_id)
        finally:
            self._plan_search_grid.blockSignals(previous)
    def _set_plan_grid_selection(self, student_id: str | None) -> None:
        if not hasattr(self, "_plan_grid"):
            return
        target_id = student_id if student_id in self._plan_card_by_id else None
        previous = self._plan_grid.blockSignals(True)
        try:
            self._plan_grid.set_current_card(target_id)
        finally:
            self._plan_grid.blockSignals(previous)
    def _has_any_card_target(self, student_id: str) -> bool:
        return (
            student_id in self._item_by_id
            or student_id in self._plan_card_by_id
            or student_id in self._resource_scope_card_by_id
            or student_id in self._resource_search_card_by_id
        )
    def _update_plan_actions(self) -> None:
        search_selected = self._plan_current_all_student_id()
        planned_selected = self._current_plan_grid_student_id()
        if hasattr(self, "_plan_add_button"):
            self._plan_add_button.setEnabled(bool(search_selected))
        if hasattr(self, "_plan_remove_button"):
            self._plan_remove_button.setEnabled(bool(planned_selected))
        if hasattr(self, "_plan_open_button"):
            self._plan_open_button.setEnabled(bool(planned_selected))
    @staticmethod
    def _record_has_weapon_system(record: StudentRecord) -> bool:
        return (record.weapon_state or "") != "no_weapon_system"
    @staticmethod
    def _plan_allows_weapon_targets(record: StudentRecord) -> bool:
        # In the planner, allow future weapon goals even before the weapon
        # system is unlocked on the current record.
        return True
    @staticmethod
    def _weapon_level_cap_for_star(weapon_star: int) -> int:
        return {
            1: 30,
            2: 40,
            3: 50,
            4: 60,
        }.get(max(0, int(weapon_star)), 0)
    @staticmethod
    def _record_base_star(record: StudentRecord) -> int:
        try:
            rarity = int(record.rarity or 1)
        except (TypeError, ValueError):
            rarity = 1
        return max(1, min(5, rarity))
    @staticmethod
    def _record_current_star(record: StudentRecord) -> int:
        return max(StudentViewerWindow._record_base_star(record), int(record.star or 0))
    @staticmethod
    def _record_current_skill(raw_value: int | None) -> int:
        return max(1, int(raw_value or 0))
    @staticmethod
    def _record_weapon_level(record: StudentRecord) -> int:
        if (record.weapon_state or "") in ("weapon_equipped", "weapon_unlocked_not_equipped"):
            return max(1, int(record.weapon_level or 0) or 1)
        return 0
    @staticmethod
    def _record_star_weapon_total(record: StudentRecord) -> int:
        weapon_star = max(0, int(record.weapon_star or 0))
        if (record.weapon_state or "") == "no_weapon_system":
            weapon_star = 0
        if weapon_star > 0:
            return 5 + weapon_star
        return StudentViewerWindow._record_current_star(record)
    def _current_or_target_weapon_star(self, record: StudentRecord, goal: StudentGoal | None = None) -> int:
        current_weapon_star = max(0, int(record.weapon_star or 0))
        if goal is None:
            return current_weapon_star
        return max(current_weapon_star, int(getattr(goal, "target_weapon_star", 0) or 0))
    def _current_or_target_star(self, record: StudentRecord, goal: StudentGoal | None = None) -> int:
        current_star = self._record_current_star(record)
        if goal is None:
            return current_star
        return max(current_star, int(getattr(goal, "target_star", 0) or 0))
    @staticmethod
    def _current_equipment_level(current_tier: int, raw_level: int | None) -> int:
        if raw_level and raw_level > 0:
            return min(int(raw_level), EQUIPMENT_TIER_MAX_LEVEL.get(max(current_tier, 0), MAX_TARGET_EQUIP_LEVEL))
        if current_tier <= 0:
            return 0
        return 1
    @staticmethod
    def _minimum_equipment_tier_for_level(level: int) -> int:
        normalized = max(0, int(level))
        for tier, max_level in sorted(EQUIPMENT_TIER_MAX_LEVEL.items()):
            if normalized <= max_level:
                return tier
        return MAX_TARGET_EQUIP_TIER
    @staticmethod
    def _equipment_level_cap_for_tier(tier: int) -> int:
        return EQUIPMENT_TIER_MAX_LEVEL.get(max(0, int(tier)), MAX_TARGET_EQUIP_LEVEL)
    @staticmethod
    def _goal_value(goal: StudentGoal | None, field_name: str, current_value: int) -> int:
        if goal is None:
            return current_value
        raw_value = getattr(goal, field_name, None)
        if raw_value is None:
            return current_value
        return max(current_value, int(raw_value))
    def _sync_plan_goal(self, goal: StudentGoal, record: StudentRecord) -> None:
        current_star = self._record_current_star(record)
        current_weapon_star = max(0, int(record.weapon_star or 0))
        current_weapon_level = self._record_weapon_level(record)
        allows_weapon_targets = self._plan_allows_weapon_targets(record)

        target_star = max(current_star, int(goal.target_star or 0))
        target_weapon_star = max(current_weapon_star, int(goal.target_weapon_star or 0))
        target_weapon_level = max(current_weapon_level, int(goal.target_weapon_level or 0))

        if not allows_weapon_targets:
            target_weapon_star = current_weapon_star
            target_weapon_level = current_weapon_level
        if target_weapon_star > 0 or target_weapon_level > 0:
            target_star = max(target_star, 5)
        target_weapon_level = min(target_weapon_level, self._weapon_level_cap_for_star(target_weapon_star))

        goal.target_star = target_star if target_star > current_star else None
        goal.target_weapon_star = target_weapon_star if allows_weapon_targets and target_weapon_star > current_weapon_star else None
        goal.target_weapon_level = target_weapon_level if allows_weapon_targets and target_weapon_level > current_weapon_level else None

        for slot_index in range(1, 4):
            tier_field = f"target_equip{slot_index}_tier"
            level_field = f"target_equip{slot_index}_level"
            current_tier = _parse_tier_number(getattr(record, f"equip{slot_index}", None)) or 0
            current_level = self._current_equipment_level(current_tier, getattr(record, f"equip{slot_index}_level", None))
            raw_target_tier = getattr(goal, tier_field)
            target_level = max(current_level, int(getattr(goal, level_field) or 0))
            target_tier = max(current_tier, int(raw_target_tier or 0))
            if target_level > 0:
                if raw_target_tier is not None and target_tier > 0:
                    target_level = min(target_level, self._equipment_level_cap_for_tier(target_tier))
                else:
                    target_tier = max(target_tier, self._minimum_equipment_tier_for_level(target_level))
                target_level = min(target_level, EQUIPMENT_TIER_MAX_LEVEL.get(target_tier, MAX_TARGET_EQUIP_LEVEL))
            setattr(goal, level_field, target_level if target_level > current_level else None)
            setattr(goal, tier_field, target_tier if target_tier > current_tier else None)

        if self._record_supports_unique_item(record) and hasattr(goal, "target_equip4_tier"):
            current_unique_tier = _parse_tier_number(record.equip4) or 0
            target_unique_tier = max(current_unique_tier, int(getattr(goal, "target_equip4_tier") or 0))
            goal.target_equip4_tier = target_unique_tier if target_unique_tier > current_unique_tier else None
    @staticmethod
    def _record_has_unique_item(record: StudentRecord) -> bool:
        value = str(record.equip4 or "").strip().lower()
        return bool(value and value != "null")
    @staticmethod
    def _record_supports_unique_item(record: StudentRecord) -> bool:
        if StudentViewerWindow._record_has_unique_item(record):
            return True
        return bool(student_meta.favorite_item_enabled(record.student_id))
    @staticmethod
    def _equipment_slot_labels(record: StudentRecord) -> list[str]:
        labels = list(student_meta.equipment_slots(record.student_id) or [])
        fallback = ["장비 1", "장비 2", "장비 3"]
        normalized: list[str] = []
        for index in range(3):
            try:
                label = str(labels[index] or fallback[index]).strip()
            except Exception:
                label = fallback[index]
            normalized.append(_equipment_series_label(label.title()))
        return normalized
    def _plan_supports_field(self, goal: StudentGoal | None, field_name: str) -> bool:
        if goal is None:
            return False
        return hasattr(goal, field_name)
    def _refresh_plan_editor_visibility(self, record: StudentRecord, goal: StudentGoal | None) -> None:
        labels = self._equipment_slot_labels(record)
        for idx, field_name in enumerate(("target_equip1_tier", "target_equip2_tier", "target_equip3_tier")):
            label_widget = self._plan_equipment_labels.get(field_name)
            if label_widget is not None:
                label_widget.setText(labels[idx])
        for idx, field_name in enumerate(("target_equip1_level", "target_equip2_level", "target_equip3_level"), start=1):
            label_widget = self._plan_level_row_labels.get(field_name)
            if label_widget is not None:
                label_widget.setText(labels[idx - 1])

        target_weapon_star = self._goal_value(goal, "target_weapon_star", max(0, int(record.weapon_star or 0)))
        target_weapon_level = self._goal_value(goal, "target_weapon_level", self._record_weapon_level(record))
        show_weapon_level = self._plan_allows_weapon_targets(record) and (target_weapon_star > 0 or target_weapon_level > 0)
        weapon_row = self._plan_level_rows.get("target_weapon_level")
        if weapon_row is not None:
            weapon_row.setVisible(show_weapon_level)

        self._refresh_ability_release_visibility(record, goal)

        has_unique_item = self._record_supports_unique_item(record)
        self._plan_unique_item_panel.setVisible(has_unique_item)
        if has_unique_item:
            selector = self._plan_unique_item_selector
            selector.setEnabled(self._plan_supports_field(goal, "target_equip4_tier"))
    @staticmethod
    def _set_widget_visible(widget: QWidget | None, visible: bool) -> None:
        if widget is not None and widget.isVisible() != visible:
            widget.setVisible(visible)
    def _update_ability_release_toggle_text(self) -> None:
        marker = "-" if self._plan_ability_release_expanded else "+"
        self._plan_stat_caption.setText(f"능력개방 {marker}")
    def _ability_release_available(self, record: StudentRecord, goal: StudentGoal | None) -> bool:
        current_level = max(0, int(record.level or 0))
        return self._goal_value(goal, "target_level", current_level) >= 90
    def _refresh_ability_release_visibility(self, record: StudentRecord, goal: StudentGoal | None) -> None:
        available = self._ability_release_available(record, goal)
        self._set_widget_visible(self._plan_stat_caption, available)
        for row in self._plan_stat_rows.values():
            self._set_widget_visible(row, available and self._plan_ability_release_expanded)
        self._update_ability_release_toggle_text()
    def _toggle_ability_release_targets(self) -> None:
        self._plan_ability_release_expanded = not self._plan_ability_release_expanded
        student_id = self._selected_plan_student_id or self._plan_current_all_student_id()
        record = self._records_by_id.get(student_id) if student_id else None
        goal = self._plan_goal_map().get(student_id) if student_id else None
        if record is not None:
            self._refresh_ability_release_visibility(record, goal)
        else:
            self._update_ability_release_toggle_text()
    def _refresh_weapon_level_controls(self, record: StudentRecord, goal: StudentGoal | None) -> None:
        current_weapon_level = self._record_weapon_level(record)
        target_weapon_star = self._current_or_target_weapon_star(record, goal)
        target_weapon_level = self._goal_value(goal, "target_weapon_level", current_weapon_level)
        show_weapon_level = self._plan_allows_weapon_targets(record) and (target_weapon_star > 0 or target_weapon_level > 0)
        self._set_widget_visible(self._plan_level_rows.get("target_weapon_level"), show_weapon_level)
        weapon_level_selector = self._plan_level_inputs["target_weapon_level"]
        weapon_level_selector.setMaximumValue(self._weapon_level_cap_for_star(target_weapon_star))
        weapon_level_selector.setEnabled(self._plan_allows_weapon_targets(record))
        weapon_level_selector.setState(
            minimum_value=current_weapon_level,
            value=target_weapon_level,
        )
    def _refresh_star_weapon_controls(self, record: StudentRecord, goal: StudentGoal | None) -> None:
        current_total = self._record_star_weapon_total(record)
        current_star = self._record_current_star(record)
        current_weapon_star = max(0, int(record.weapon_star or 0))
        target_star = self._goal_value(goal, "target_star", current_star)
        target_weapon_star = self._goal_value(goal, "target_weapon_star", current_weapon_star)
        target_total = target_star if target_weapon_star <= 0 else 5 + target_weapon_star
        self._plan_segment_inputs["star_weapon"].setState(
            minimum_value=current_total,
            value=target_total,
            enabled_count=9 if self._plan_allows_weapon_targets(record) else 5,
        )
        self._refresh_weapon_level_controls(record, goal)
    def _refresh_single_equipment_controls(self, record: StudentRecord, goal: StudentGoal | None, slot_index: int) -> None:
        tier_field = f"target_equip{slot_index}_tier"
        level_field = f"target_equip{slot_index}_level"
        current_tier = _parse_tier_number(getattr(record, f"equip{slot_index}", None)) or 0
        current_level = self._current_equipment_level(current_tier, getattr(record, f"equip{slot_index}_level", None))
        target_tier = self._goal_value(goal, tier_field, current_tier)
        self._plan_segment_inputs[tier_field].setState(
            minimum_value=current_tier,
            value=target_tier,
        )
        self._plan_level_inputs[level_field].setMaximumValue(self._equipment_level_cap_for_tier(target_tier))
        self._plan_level_inputs[level_field].setState(
            minimum_value=current_level,
            value=self._goal_value(goal, level_field, current_level),
        )
    def _refresh_single_digit_control(self, record: StudentRecord, goal: StudentGoal | None, field_name: str) -> None:
        if field_name == "target_level":
            current_value = max(0, int(record.level or 0))
        elif field_name == "target_weapon_level":
            self._refresh_star_weapon_controls(record, goal)
            return
        elif field_name == "target_stat_hp":
            current_value = max(0, int(record.stat_hp or 0))
        elif field_name == "target_stat_atk":
            current_value = max(0, int(record.stat_atk or 0))
        elif field_name == "target_stat_heal":
            current_value = max(0, int(record.stat_heal or 0))
        else:
            return
        selector = self._plan_level_inputs.get(field_name)
        if selector is None:
            return
        selector.setEnabled(self._plan_supports_field(goal, field_name))
        selector.setState(
            minimum_value=current_value,
            value=self._goal_value(goal, field_name, current_value),
        )
        if field_name == "target_level":
            self._refresh_ability_release_visibility(record, goal)
    def _refresh_single_segment_control(self, record: StudentRecord, goal: StudentGoal | None, field_name: str) -> None:
        if field_name == "star_weapon":
            self._refresh_star_weapon_controls(record, goal)
            return
        if field_name.startswith("target_equip") and field_name.endswith("_tier"):
            self._refresh_single_equipment_controls(record, goal, int(field_name[len("target_equip")]))
            return
        if field_name == "target_equip4_tier":
            if self._record_supports_unique_item(record):
                current_unique_tier = _parse_tier_number(record.equip4) or 0
                self._plan_unique_item_selector.setState(
                    minimum_value=current_unique_tier,
                    value=self._goal_value(goal, "target_equip4_tier", current_unique_tier),
                    enabled_count=2,
                )
            return
        current_value = 0
        if field_name == "target_ex_skill":
            current_value = self._record_current_skill(record.ex_skill)
        elif field_name == "target_skill1":
            current_value = self._record_current_skill(record.skill1)
        elif field_name == "target_skill2":
            current_value = self._record_current_skill(record.skill2)
        elif field_name == "target_skill3":
            current_value = self._record_current_skill(record.skill3)
        selector = self._plan_segment_inputs.get(field_name)
        if selector is not None:
            selector.setState(
                minimum_value=current_value,
                value=self._goal_value(goal, field_name, current_value),
            )
    def _refresh_plan_editor_controls(self, record: StudentRecord, goal: StudentGoal | None) -> None:
        current_total = self._record_star_weapon_total(record)
        current_star = self._record_current_star(record)
        current_weapon_star = max(0, int(record.weapon_star or 0))
        target_star = self._goal_value(goal, "target_star", current_star)
        target_weapon_star = self._goal_value(goal, "target_weapon_star", current_weapon_star)
        target_total = target_star if target_weapon_star <= 0 else 5 + target_weapon_star
        self._plan_segment_inputs["star_weapon"].setState(
            minimum_value=current_total,
            value=target_total,
            enabled_count=9 if self._plan_allows_weapon_targets(record) else 5,
        )

        for field_name, current_value in (
            ("target_ex_skill", self._record_current_skill(record.ex_skill)),
            ("target_skill1", self._record_current_skill(record.skill1)),
            ("target_skill2", self._record_current_skill(record.skill2)),
            ("target_skill3", self._record_current_skill(record.skill3)),
        ):
            self._plan_segment_inputs[field_name].setState(
                minimum_value=current_value,
                value=self._goal_value(goal, field_name, current_value),
            )

        for slot_index in range(1, 4):
            tier_field = f"target_equip{slot_index}_tier"
            level_field = f"target_equip{slot_index}_level"
            current_tier = _parse_tier_number(getattr(record, f"equip{slot_index}", None)) or 0
            current_level = self._current_equipment_level(current_tier, getattr(record, f"equip{slot_index}_level", None))
            target_tier = self._goal_value(goal, tier_field, current_tier)
            self._plan_segment_inputs[tier_field].setState(
                minimum_value=current_tier,
                value=target_tier,
            )
            self._plan_level_inputs[level_field].setMaximumValue(self._equipment_level_cap_for_tier(target_tier))
            self._plan_level_inputs[level_field].setState(
                minimum_value=current_level,
                value=self._goal_value(goal, level_field, current_level),
            )

        current_level = max(0, int(record.level or 0))
        current_weapon_level = self._record_weapon_level(record)
        self._plan_level_inputs["target_level"].setState(
            minimum_value=current_level,
            value=self._goal_value(goal, "target_level", current_level),
        )
        weapon_level_selector = self._plan_level_inputs["target_weapon_level"]
        target_weapon_star = self._current_or_target_weapon_star(record, goal)
        weapon_level_selector.setMaximumValue(self._weapon_level_cap_for_star(target_weapon_star))
        weapon_level_selector.setEnabled(self._plan_allows_weapon_targets(record))
        weapon_level_selector.setState(
            minimum_value=current_weapon_level,
            value=self._goal_value(goal, "target_weapon_level", current_weapon_level),
        )

        for field_name, current_value in (
            ("target_stat_hp", max(0, int(record.stat_hp or 0))),
            ("target_stat_atk", max(0, int(record.stat_atk or 0))),
            ("target_stat_heal", max(0, int(record.stat_heal or 0))),
        ):
            selector = self._plan_level_inputs.get(field_name)
            if selector is None:
                continue
            selector.setEnabled(self._plan_supports_field(goal, field_name))
            selector.setState(
                minimum_value=current_value,
                value=self._goal_value(goal, field_name, current_value),
            )

        if self._record_supports_unique_item(record):
            current_unique_tier = _parse_tier_number(record.equip4) or 0
            self._plan_unique_item_selector.setState(
                minimum_value=current_unique_tier,
                value=self._goal_value(goal, "target_equip4_tier", current_unique_tier),
                enabled_count=2,
            )

        self._refresh_plan_editor_visibility(record, goal)
    def _on_plan_segment_changed(self, field_name: str, value: int) -> None:
        if self._plan_editor_guard:
            return
        student_id = self._selected_plan_student_id or self._plan_current_all_student_id()
        if not student_id:
            return
        record = self._records_by_id.get(student_id)
        if record is None:
            return
        was_planned = student_id in self._plan_goal_map()
        goal = self._get_or_create_goal(student_id)

        if field_name == "star_weapon":
            target_star = min(5, value)
            target_weapon_star = max(0, value - 5)
            goal.target_star = target_star if target_star > self._record_current_star(record) else None
            goal.target_weapon_star = target_weapon_star if target_weapon_star > max(0, int(record.weapon_star or 0)) else None
        else:
            current_value = 0
            if field_name == "target_ex_skill":
                current_value = self._record_current_skill(record.ex_skill)
            elif field_name == "target_skill1":
                current_value = self._record_current_skill(record.skill1)
            elif field_name == "target_skill2":
                current_value = self._record_current_skill(record.skill2)
            elif field_name == "target_skill3":
                current_value = self._record_current_skill(record.skill3)
            elif field_name.startswith("target_equip"):
                slot_index = int(field_name[len("target_equip")])
                current_value = _parse_tier_number(getattr(record, f"equip{slot_index}", None)) or 0
            if self._plan_supports_field(goal, field_name):
                setattr(goal, field_name, value if value > current_value else None)

        self._sync_plan_goal(goal, record)
        self._invalidate_plan_caches(student_id)
        if not was_planned:
            self._add_plan_student_to_resource_scope(student_id)
        self._save_plan()
        self._selected_plan_student_id = student_id
        self._refresh_after_plan_goal_change(student_id, rebuild_lists=not was_planned, changed_field=field_name)
    def _on_plan_digit_changed(self, field_name: str, value: int) -> None:
        if self._plan_editor_guard:
            return
        student_id = self._selected_plan_student_id or self._plan_current_all_student_id()
        if not student_id:
            return
        record = self._records_by_id.get(student_id)
        if record is None:
            return
        was_planned = student_id in self._plan_goal_map()
        goal = self._get_or_create_goal(student_id)

        if field_name == "target_level":
            current_value = max(0, int(record.level or 0))
        elif field_name == "target_weapon_level":
            current_value = self._record_weapon_level(record)
        elif field_name == "target_stat_hp":
            current_value = max(0, int(record.stat_hp or 0))
        elif field_name == "target_stat_atk":
            current_value = max(0, int(record.stat_atk or 0))
        elif field_name == "target_stat_heal":
            current_value = max(0, int(record.stat_heal or 0))
        else:
            slot_index = int(field_name[len("target_equip")])
            current_tier = _parse_tier_number(getattr(record, f"equip{slot_index}", None)) or 0
            current_value = self._current_equipment_level(current_tier, getattr(record, f"equip{slot_index}_level", None))
        if self._plan_supports_field(goal, field_name):
            setattr(goal, field_name, value if value > current_value else None)

        self._sync_plan_goal(goal, record)
        self._invalidate_plan_caches(student_id)
        if not was_planned:
            self._add_plan_student_to_resource_scope(student_id)
        self._save_plan()
        self._selected_plan_student_id = student_id
        self._refresh_after_plan_goal_change(student_id, rebuild_lists=not was_planned, changed_field=field_name)
    def _refresh_after_plan_goal_change(self, student_id: str, *, rebuild_lists: bool, changed_field: str | None = None) -> None:
        if rebuild_lists:
            self._refresh_plan_lists()
            self._set_plan_grid_selection(student_id)
        else:
            self._refresh_plan_editor_after_goal_change(student_id, changed_field)
            if self._current_plan_grid_student_id() != student_id:
                self._set_plan_grid_selection(student_id)
            self._update_plan_actions()
        self._refresh_plan_totals()
    def _refresh_plan_editor_after_goal_change(self, student_id: str, changed_field: str | None = None) -> None:
        record = self._records_by_id.get(student_id)
        goal = self._plan_goal_map().get(student_id)
        if record is None:
            self._clear_plan_editor()
            return
        self._plan_editor_guard = True
        try:
            if changed_field is None:
                self._refresh_plan_editor_controls(record, goal)
            elif changed_field in self._plan_segment_inputs:
                self._refresh_single_segment_control(record, goal, changed_field)
            elif changed_field in self._plan_level_inputs:
                if changed_field.startswith("target_equip") and changed_field.endswith("_level"):
                    self._refresh_single_equipment_controls(record, goal, int(changed_field[len("target_equip")]))
                else:
                    self._refresh_single_digit_control(record, goal, changed_field)
        finally:
            self._plan_editor_guard = False
        self._update_plan_student_summary(student_id)
        self._refresh_selected_plan_requirements(student_id)
    def _set_plan_empty_scroll_margin_mode(self, empty: bool) -> None:
        for attr in ("_plan_controls_scroll", "_plan_requirement_scroll"):
            scroll_area = getattr(self, attr, None)
            if scroll_area is None:
                continue
            margins = scroll_area.viewportMargins()
            scroll_area.setViewportMargins(
                margins.left(),
                margins.top(),
                0 if empty else scale_px(18, self._ui_scale),
                margins.bottom(),
            )
            handle = getattr(scroll_area, "_planner_scroll_handle", None)
            if isinstance(handle, PlannerScrollHandle):
                handle.setSuppressed(empty)
    def _refresh_plan_lists(self) -> None:
        if not hasattr(self, "_plan_search_grid"):
            return
        query = _live_line_edit_text(self._plan_search).strip().casefold()
        current_all = self._plan_current_all_student_id()
        current_plan = self._current_plan_grid_student_id() or self._selected_plan_student_id
        goal_map = self._plan_goal_map()

        self._plan_search_grid.clear_cards()
        self._plan_search_card_by_id.clear()
        search_cards: list[StudentCardWidget] = []
        match_count = 0
        if query:
            for record in sorted(self._all_students, key=lambda item: item.title.lower()):
                if query not in student_meta.search_blob(record.student_id, record.title):
                    continue
                card = self._build_student_card(
                    record,
                    show_name_panel=False,
                    show_unowned_badge=False,
                )
                search_cards.append(card)
                self._plan_search_card_by_id[record.student_id] = card
                match_count += 1

        if search_cards:
            self._plan_search_grid.add_cards(search_cards)
            for student_id in self._plan_search_card_by_id:
                self._enqueue_thumb(student_id)
        self._plan_search_grid.setVisible(bool(query))
        if hasattr(self, "_plan_search_grid_panel"):
            self._plan_search_grid_panel.setVisible(bool(query))
        if not query:
            self._plan_search_state.setText("학생 순서를 드래그해서 변경할 수 있으며, 학생 순서대로 인벤토리 탭에서 재화 우선 목표를 보여줍니다.")
        elif match_count:
            self._plan_search_state.setText(f"{match_count}명 찾음. 학생을 선택해 계획에 추가하세요.")
        else:
            self._plan_search_state.setText("검색과 일치하는 학생이 없습니다.")

        planned_goals = list(self._plan.goals)
        planned_ids = tuple(goal.student_id for goal in planned_goals if goal.student_id in self._records_by_id)
        current_ids = tuple(self._plan_card_by_id)
        if planned_ids != current_ids:
            self._plan_grid.clear_cards()
            self._plan_card_by_id.clear()
            planned_cards: list[StudentCardWidget] = []
            for goal in planned_goals:
                record = self._records_by_id.get(goal.student_id)
                if record is None:
                    continue
                card = self._build_student_card(record)
                planned_cards.append(card)
                self._plan_card_by_id[record.student_id] = card

            if planned_cards:
                self._plan_grid.add_cards(planned_cards)
                for student_id in self._plan_card_by_id:
                    self._enqueue_thumb(student_id)
        else:
            planned_cards = list(self._plan_card_by_id.values())

        self._plan_count_label.setText(f"{len(planned_cards)}명")
        self._plan_empty_label.setVisible(not planned_cards)
        self._plan_grid.setVisible(bool(planned_cards))
        if hasattr(self, "_plan_grid_panel"):
            self._plan_grid_panel.setVisible(bool(planned_cards))

        self._set_plan_search_selection(current_all)
        self._set_plan_grid_selection(current_plan)
        focused_id = current_plan if current_plan in self._plan_card_by_id else self._plan_current_all_student_id()
        if focused_id:
            self._selected_plan_student_id = focused_id if focused_id in goal_map else None
            self._load_plan_student(focused_id)
        else:
            self._selected_plan_student_id = None
            self._clear_plan_editor()
        self._update_plan_actions()
    def _plan_current_all_student_id(self) -> str | None:
        if not hasattr(self, "_plan_search_grid"):
            return None
        return self._plan_search_grid.current_card_id()
    def _on_plan_search_card_changed(self, current: str | None, _previous: str | None) -> None:
        if current is None:
            self._update_plan_actions()
            return
        self._selected_plan_student_id = current if current in self._plan_goal_map() else None
        self._set_plan_grid_selection(current if current in self._plan_goal_map() else None)
        self._load_plan_student(current)
        self._update_plan_actions()
    def _on_plan_card_changed(self, current: str | None, _previous: str | None) -> None:
        if current is None:
            self._selected_plan_student_id = None
            self._update_plan_actions()
            return
        self._selected_plan_student_id = current
        self._set_plan_search_selection(current)
        self._load_plan_student(current)
        self._update_plan_actions()
    def _on_plan_order_changed(self, student_ids: object) -> None:
        ordered_ids = [str(student_id) for student_id in student_ids or []]
        if not ordered_ids:
            return
        ordered_id_set = set(ordered_ids)
        goal_by_id = {goal.student_id: goal for goal in self._plan.goals}
        next_goals = [goal_by_id[student_id] for student_id in ordered_ids if student_id in goal_by_id]
        next_goals.extend(goal for goal in self._plan.goals if goal.student_id not in ordered_id_set)
        if [goal.student_id for goal in next_goals] == [goal.student_id for goal in self._plan.goals]:
            return
        self._plan.goals = next_goals
        self._invalidate_plan_caches()
        self._save_plan()
        self._refresh_plan_totals()
    @staticmethod
    def _global_pos_in_widget(widget: QWidget | None, global_pos: QPoint) -> bool:
        if widget is None or not widget.isVisible():
            return False
        top_left = widget.mapToGlobal(QPoint(0, 0))
        return QRect(top_left, widget.size()).contains(global_pos)
    def _is_plan_drop_target(self, global_pos: QPoint) -> bool:
        if self._global_pos_in_widget(getattr(self, "_plan_quick_add_panel", None), global_pos):
            return False
        if self._global_pos_in_widget(getattr(self, "_plan_grid_panel", None), global_pos):
            return True
        if self._global_pos_in_widget(getattr(self, "_plan_empty_label", None), global_pos):
            return True
        plan_panel = getattr(self, "_plan_panel", None)
        if not self._global_pos_in_widget(plan_panel, global_pos):
            return False
        quick_add_panel = getattr(self, "_plan_quick_add_panel", None)
        if quick_add_panel is None:
            return True
        quick_add_top = quick_add_panel.mapToGlobal(QPoint(0, 0)).y()
        return global_pos.y() < quick_add_top
    def _plan_drop_insert_index(self, global_pos: QPoint) -> int | None:
        if (
            hasattr(self, "_plan_grid")
            and self._plan_grid.isVisible()
            and self._global_pos_in_widget(getattr(self, "_plan_grid_panel", None), global_pos)
        ):
            return self._plan_grid.drop_index_for_global_pos(
                global_pos,
                stable_index=getattr(self._plan_grid, "_drop_placeholder_index", None),
            )
        return None
    def _add_student_to_plan(self, student_id: str, *, insert_index: int | None = None) -> None:
        if not student_id:
            return
        goal = self._get_or_create_goal(student_id)
        if insert_index is not None:
            next_goals = [candidate for candidate in self._plan.goals if candidate.student_id != student_id]
            clamped_index = max(0, min(insert_index, len(next_goals)))
            next_goals.insert(clamped_index, goal)
            if [candidate.student_id for candidate in next_goals] != [candidate.student_id for candidate in self._plan.goals]:
                self._plan.goals = next_goals
                self._invalidate_plan_caches()
        self._add_plan_student_to_resource_scope(student_id)
        self._selected_plan_student_id = student_id
        self._save_plan()
        self._refresh_plan_lists()
        self._set_plan_grid_selection(student_id)
        self._update_plan_student_summary(student_id)
        self._refresh_plan_totals()
        self._update_plan_actions()
    def _on_plan_search_card_drag_moved(self, _student_id: str, global_pos: object) -> None:
        if not isinstance(global_pos, QPoint) or not hasattr(self, "_plan_grid"):
            return
        if (
            self._plan_grid.isVisible()
            and self._global_pos_in_widget(getattr(self, "_plan_grid_panel", None), global_pos)
        ):
            index = self._plan_grid.drop_index_for_global_pos(
                global_pos,
                stable_index=getattr(self._plan_grid, "_drop_placeholder_index", None),
            )
            self._plan_grid.set_external_drop_placeholder(index)
            return
        self._plan_grid.clear_external_drop_placeholder()
    def _on_plan_search_card_drag_finished(self, student_id: str, global_pos: object) -> None:
        if not isinstance(global_pos, QPoint):
            return
        try:
            if not self._is_plan_drop_target(global_pos):
                return
            self._add_student_to_plan(student_id, insert_index=self._plan_drop_insert_index(global_pos))
        finally:
            if hasattr(self, "_plan_grid"):
                self._plan_grid.clear_external_drop_placeholder()
    def _add_selected_student_to_plan(self) -> None:
        student_id = self._plan_current_all_student_id() or self._selected_plan_student_id
        if not student_id:
            return
        self._add_student_to_plan(student_id)
    def _remove_selected_plan_student(self) -> None:
        student_id = self._current_plan_grid_student_id() or self._selected_plan_student_id
        if not student_id:
            return
        self._plan.goals = [goal for goal in self._plan.goals if goal.student_id != student_id]
        self._invalidate_plan_caches(student_id)
        self._selected_plan_student_id = None
        self._save_plan()
        self._refresh_plan_lists()
        self._refresh_plan_totals()
        self._update_plan_actions()
    def _focus_selected_plan_student_in_viewer(self) -> None:
        if not self._selected_plan_student_id:
            return
        if self._selected_plan_student_id in self._item_by_id:
            self._student_grid.set_current_card(self._selected_plan_student_id)
            if self._main_tabs is not None:
                self._main_tabs.setCurrentIndex(0)
    def _load_plan_student(self, student_id: str) -> None:
        record = self._records_by_id.get(student_id)
        if record is None:
            self._clear_plan_editor()
            return
        self._set_plan_empty_scroll_margin_mode(False)
        goal = self._plan_goal_map().get(student_id)
        self._plan_editor_guard = True
        try:
            self._plan_ability_release_expanded = False
            self._plan_name.setText(record.title)
            self._plan_current.setText("보유" if record.owned else "미보유")
            for selector in self._plan_segment_inputs.values():
                selector.setEnabled(True)
            for selector in self._plan_level_inputs.values():
                selector.setEnabled(True)
            self._refresh_plan_editor_controls(record, goal)
        finally:
            self._plan_editor_guard = False
        self._update_plan_student_summary(student_id)
        self._refresh_selected_plan_requirements(student_id)
    def _clear_plan_editor(self) -> None:
        self._set_plan_empty_scroll_margin_mode(True)
        self._plan_editor_guard = True
        try:
            self._plan_name.setText("학생을 선택하세요")
            self._plan_current.setText("")
            for selector in self._plan_segment_inputs.values():
                selector.setEnabled(False)
                selector.setState(minimum_value=0, value=0, enabled_count=selector._count)
            for selector in self._plan_level_inputs.values():
                selector.setEnabled(False)
                selector.setState(minimum_value=0, value=0)
        finally:
            self._plan_editor_guard = False
        if hasattr(self, "_plan_unique_item_panel"):
            self._plan_unique_item_panel.setVisible(False)
        if hasattr(self, "_plan_stat_caption"):
            self._plan_stat_caption.setVisible(False)
            self._update_ability_release_toggle_text()
        for row in getattr(self, "_plan_stat_rows", {}).values():
            row.setVisible(False)
        self._plan_student_summary.setText("선택된 학생이 없습니다.")
        self._refresh_plan_requirements(None)
        self._update_plan_actions()
    def _update_plan_student_summary(self, student_id: str) -> None:
        record = self._records_by_id.get(student_id)
        goal = self._plan_goal_map().get(student_id)
        if record is None or goal is None:
            self._plan_student_summary.setText("비용을 계산하려면 이 학생을 계획에 추가하세요.")
            return
        summary = self._cached_goal_cost(student_id, record=record, goal=goal)
        if summary is None:
            self._plan_student_summary.setText("비용을 계산하려면 이 학생을 계획에 추가하세요.")
            return
        self._plan_student_summary.setText(self._format_cost_summary(summary))
    def _add_current_student_to_plan(self) -> None:
        student_id = self._current_student_id()
        if not student_id:
            return
        self._get_or_create_goal(student_id)
        self._add_plan_student_to_resource_scope(student_id)
        self._selected_plan_student_id = student_id
        self._save_plan()
        self._refresh_plan_lists()
        self._set_plan_grid_selection(student_id)
        self._refresh_plan_totals()
        self._update_plan_actions()
    def _refresh_plan_totals(self) -> None:
        if not hasattr(self, "_plan_total_summary"):
            return
        goal_map = self._plan_goal_map()
        total, _selected_count, _contributing_count = self._resource_total_for_ids(
            [goal.student_id for goal in self._plan.goals],
            goal_map,
        )
        self._plan_total_summary.setText(
            f"계획 학생 {len(self._plan.goals)}명\n{self._format_cost_summary(total)}"
        )
        self._refresh_resources_if_visible()
        self._refresh_inventory_tab()
    def _refresh_selected_plan_requirements(self, student_id: str | None = None) -> None:
        selected_id = student_id or self._selected_plan_student_id or self._current_plan_grid_student_id()
        if not selected_id:
            self._refresh_plan_requirements(None)
            return
        record = self._records_by_id.get(selected_id)
        goal = self._plan_goal_map().get(selected_id)
        if record is None or goal is None:
            self._refresh_plan_requirements(None)
            return
        self._refresh_plan_requirements(self._cached_goal_cost(selected_id, record=record, goal=goal), record=record)
    def _plan_requirement_sort_key(
        self,
        entry: PlanResourceRequirement,
        *,
        equipment_slot_order: dict[str, int],
    ) -> tuple[int, int, str]:
        category = entry.category
        item_id = entry.key
        if category == "skill_books":
            if item_id == "Item_Icon_SkillBook_Ultimate_Piece":
                category = "secret_notes"
            elif item_id.startswith("Item_Icon_Material_ExSkill_"):
                category = "skill_bd"
            elif item_id.startswith("Item_Icon_SkillBook_"):
                category = "skill_notes"
        elif category == "equipment_materials":
            series_key = _equipment_series_key_from_item(item_id, entry.name)
            slot_index = equipment_slot_order.get(series_key or "")
            if slot_index in (1, 2, 3):
                category = f"equipment_slot_{slot_index}"
        tier = _tier_from_item_id_or_name(item_id, entry.name)
        return (
            _PLAN_RESOURCE_CATEGORY_ORDER.get(category, 999),
            -tier,
            entry.name.lower(),
        )
    def _apply_weapon_exp_wildcard_ownership(self, merged: dict[tuple[str, str], PlanResourceRequirement]) -> None:
        inventory_index = self._inventory_quantity_index_cache
        wildcard_remaining = {
            tier: inventory_index.get(f"{WEAPON_EXP_ITEM_PREFIX}{WEAPON_EXP_WILDCARD_PART_KEY}_{tier - 1}", 0)
            for tier in range(1, 5)
        }
        weapon_entries: list[PlanResourceRequirement] = []
        for entry in merged.values():
            if entry.category != "weapon_exp":
                continue
            parsed = _weapon_exp_item_part_and_tier(entry.key)
            if parsed is None:
                continue
            part_key, tier = parsed
            if part_key == WEAPON_EXP_WILDCARD_PART_KEY:
                wildcard_remaining[tier] = max(0, wildcard_remaining.get(tier, 0) - entry.required)
            else:
                weapon_entries.append(entry)

        for entry in sorted(weapon_entries, key=lambda value: value.key):
            parsed = _weapon_exp_item_part_and_tier(entry.key)
            if parsed is None:
                continue
            _part_key, tier = parsed
            shortage = max(0, entry.required - entry.owned)
            if shortage <= 0:
                continue
            wildcard_available = wildcard_remaining.get(tier, 0)
            if wildcard_available <= 0:
                continue
            wildcard_used = min(shortage, wildcard_available)
            entry.owned += wildcard_used
            wildcard_remaining[tier] = wildcard_available - wildcard_used
    def _plan_requirement_entries(self, summary: PlanCostSummary, *, record: StudentRecord | None = None) -> list[PlanResourceRequirement]:
        inventory_index = self._inventory_quantity_index_cache
        merged: dict[tuple[str, str], PlanResourceRequirement] = {}
        equipment_slot_order: dict[str, int] = {}
        if record is not None:
            for index, slot_key in enumerate(student_meta.equipment_slots(record.student_id) or (), start=1):
                if slot_key:
                    equipment_slot_order[str(slot_key)] = index

        def add_entry(category: str, key: str, required: int) -> None:
            if required <= 0:
                return
            item_id = _plan_resource_item_id(key, category)
            name = _plan_resource_display_name(item_id, key)
            if category == "equipment_materials":
                name = _equipment_resource_display_name(item_id, name)
            owned = inventory_index.get(item_id or "", inventory_index.get(key, 0))
            icon_path = self._cached_plan_resource_icon_path(item_id, name)
            icon = self._cached_plan_resource_pixmap(icon_path)
            merge_key = (category, item_id or key)
            current = merged.get(merge_key)
            if current is None:
                merged[merge_key] = PlanResourceRequirement(
                    key=item_id or key,
                    name=name,
                    required=required,
                    owned=owned,
                    icon_path=icon_path,
                    category=category,
                    icon=icon,
                )
            else:
                current.required += required

        add_entry("credits", "Currency_Icon_Gold", summary.credits)
        for category, values in (
            ("level_exp", summary.level_exp_items),
            ("equipment_exp", summary.equipment_exp_items),
            ("weapon_exp", summary.weapon_exp_items),
            ("skill_books", summary.skill_books),
            ("ex_ooparts", summary.ex_ooparts),
            ("skill_ooparts", summary.skill_ooparts),
            ("favorite_item_materials", summary.favorite_item_materials),
            ("stat_materials", summary.stat_materials),
            ("equipment_materials", summary.equipment_materials),
            ("star_materials", summary.star_materials),
        ):
            for key, required in values.items():
                add_entry(category, key, required)

        self._apply_weapon_exp_wildcard_ownership(merged)

        return sorted(
            merged.values(),
            key=lambda entry: self._plan_requirement_sort_key(entry, equipment_slot_order=equipment_slot_order),
        )
    def _refresh_plan_requirements(self, summary: PlanCostSummary | None, *, record: StudentRecord | None = None) -> None:
        if not hasattr(self, "_plan_requirement_grid"):
            return

        self._plan_requirement_grid_host.setUpdatesEnabled(False)
        try:
            while self._plan_requirement_grid.count():
                item = self._plan_requirement_grid.takeAt(0)
                widget = item.widget()
                if widget is not None:
                    widget.deleteLater()

            if summary is None:
                self._plan_requirement_empty.setText("계획 학생을 선택하고 목표를 지정하면 필요한 재화를 미리 볼 수 있습니다.")
                self._plan_requirement_empty.setVisible(True)
                self._plan_requirement_scroll.setVisible(True)
                self._plan_requirement_summary.setText("선택 학생 · 필요 / 보유")
                return

            entries = self._plan_requirement_entries(summary, record=record)
            self._plan_requirement_empty.setText("" if entries else "이 학생의 현재 목표에는 추가 재화가 필요하지 않습니다.")
            self._plan_requirement_empty.setVisible(True)
            self._plan_requirement_scroll.setVisible(True)
            if not entries:
                self._plan_requirement_summary.setText("선택 학생 · 필요 / 보유")
                return

            shortages = sum(1 for entry in entries if entry.required > entry.owned)
            self._plan_requirement_summary.setText(
                f"{len(entries)}개 · 부족 {shortages}개 · 필요 / 보유"
            )
            columns = 3
            for index, requirement in enumerate(entries):
                chip = PlanResourceChip(ui_scale=self._ui_scale)
                chip.setData(requirement)
                self._plan_requirement_grid.addWidget(chip, index // columns, index % columns)
        finally:
            self._plan_requirement_grid_host.setUpdatesEnabled(True)
