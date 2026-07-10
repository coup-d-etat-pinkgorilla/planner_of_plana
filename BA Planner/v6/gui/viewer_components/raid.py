"""RaidGuideTabComponent implementation extracted from the viewer façade."""

from __future__ import annotations

from gui import viewer_shared as _viewer_shared

globals().update({name: value for name, value in vars(_viewer_shared).items() if not name.startswith("__")})


class RaidGuideTabComponent:
    def _build_raid_guide_tab(self, root: QWidget) -> None:
        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(scale_px(12, self._ui_scale))

        header = QFrame()
        header.setObjectName("header")
        header_layout = QVBoxLayout(header)
        header_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(16, self._ui_scale),
        )
        title = QLabel("공략 타임라인")
        title.setObjectName("title")
        subtitle = QLabel("총력전, 대결전, 제약해제결전의 덱과 스킬 사용 타이밍을 오버레이용 데이터로 정리합니다.")
        subtitle.setObjectName("count")
        header_layout.addWidget(title)
        header_layout.addWidget(subtitle)
        layout.addWidget(header)

        splitter = QSplitter(Qt.Horizontal)
        splitter.setObjectName("sectionSplitter")
        splitter.setChildrenCollapsible(False)
        layout.addWidget(splitter, 1)

        list_panel = QFrame()
        list_panel.setObjectName("planSectionPanel")
        list_layout = QVBoxLayout(list_panel)
        list_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        list_layout.setSpacing(scale_px(8, self._ui_scale))
        list_title = QLabel("공략 목록")
        list_title.setObjectName("sectionTitle")
        list_layout.addWidget(list_title)
        self._raid_filter_text = QLineEdit()
        self._raid_filter_text.setPlaceholderText("보스, 난이도, 제목 검색")
        self._raid_filter_text.textChanged.connect(lambda *_: self._refresh_raid_guide_list())
        list_layout.addWidget(self._raid_filter_text)
        self._raid_filter_mode = QComboBox()
        self._raid_filter_mode.addItem("전체 모드", "")
        for mode, label in RAID_GUIDE_MODES.items():
            self._raid_filter_mode.addItem(label, mode)
        self._raid_filter_mode.currentIndexChanged.connect(lambda *_: self._refresh_raid_guide_list())
        list_layout.addWidget(self._raid_filter_mode)
        self._raid_guide_list = RoundedListWidget(ui_scale=self._ui_scale)
        self._raid_guide_list.currentItemChanged.connect(self._on_raid_guide_selected)
        list_layout.addWidget(self._raid_guide_list, 1)
        list_buttons = QGridLayout()
        list_buttons.setContentsMargins(0, 0, 0, 0)
        list_buttons.setHorizontalSpacing(scale_px(6, self._ui_scale))
        list_buttons.setVerticalSpacing(scale_px(6, self._ui_scale))
        self._raid_new_button = QPushButton("새 공략")
        self._raid_edit_button = QPushButton("수정")
        self._raid_duplicate_button = QPushButton("복제")
        self._raid_delete_button = QPushButton("삭제")
        self._raid_share_button = QPushButton("공유")
        self._raid_import_share_button = QPushButton("가져오기")
        self._raid_new_button.clicked.connect(self._new_raid_guide)
        self._raid_edit_button.clicked.connect(self._edit_selected_raid_guide)
        self._raid_duplicate_button.clicked.connect(self._duplicate_selected_raid_guide)
        self._raid_delete_button.clicked.connect(self._delete_selected_raid_guide)
        self._raid_share_button.clicked.connect(self._share_current_raid_guide)
        self._raid_import_share_button.clicked.connect(self._import_raid_guide_share)
        list_buttons.addWidget(self._raid_new_button, 0, 0)
        list_buttons.addWidget(self._raid_edit_button, 0, 1)
        list_buttons.addWidget(self._raid_duplicate_button, 1, 0)
        list_buttons.addWidget(self._raid_delete_button, 1, 1)
        list_buttons.addWidget(self._raid_share_button, 2, 0)
        list_buttons.addWidget(self._raid_import_share_button, 2, 1)
        list_layout.addLayout(list_buttons)
        splitter.addWidget(list_panel)

        editor_panel = QFrame()
        editor_panel.setObjectName("planSectionPanel")
        editor_layout = QVBoxLayout(editor_panel)
        editor_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        editor_layout.setSpacing(scale_px(10, self._ui_scale))

        meta_panel = QFrame()
        meta_panel.setObjectName("planBand")
        meta_layout = QGridLayout(meta_panel)
        meta_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        meta_layout.setHorizontalSpacing(scale_px(8, self._ui_scale))
        meta_layout.setVerticalSpacing(scale_px(8, self._ui_scale))
        self._raid_title_input = QLineEdit()
        self._raid_title_input.setPlaceholderText("공략 제목")
        self._raid_mode_input = InventorySortDropdownButton()
        for mode, label in RAID_GUIDE_MODES.items():
            self._raid_mode_input.addItem(label, mode)
        self._raid_mode_input.modeChanged.connect(lambda *_: self._on_raid_mode_changed())
        self._raid_boss_input = InventorySortDropdownButton()
        for boss in RAID_BOSS_TIME_LIMIT_SECONDS:
            self._raid_boss_input.addItem(boss, boss)
        self._raid_boss_input.addItem(RAID_CUSTOM_INPUT_LABEL, "")
        self._raid_boss_input.modeChanged.connect(lambda *_: self._on_raid_boss_changed())
        self._raid_boss_custom_input = QLineEdit()
        self._raid_boss_custom_input.setPlaceholderText("보스 직접 입력")
        self._raid_boss_custom_input.textChanged.connect(lambda *_: self._on_raid_boss_changed())
        boss_input_wrap = QWidget()
        boss_input_wrap.setObjectName("planTransparent")
        boss_input_layout = QHBoxLayout(boss_input_wrap)
        boss_input_layout.setContentsMargins(0, 0, 0, 0)
        boss_input_layout.setSpacing(scale_px(6, self._ui_scale))
        boss_input_layout.addWidget(self._raid_boss_input, 1)
        boss_input_layout.addWidget(self._raid_boss_custom_input, 1)
        self._raid_difficulty_input = InventorySortDropdownButton()
        for difficulty in RAID_GUIDE_DIFFICULTIES:
            self._raid_difficulty_input.addItem(difficulty, difficulty)
        self._raid_difficulty_input.addItem(RAID_CUSTOM_INPUT_LABEL, "")
        self._raid_difficulty_input.modeChanged.connect(lambda *_: self._sync_raid_difficulty_custom_visibility())
        self._raid_difficulty_custom_input = QLineEdit()
        self._raid_difficulty_custom_input.setPlaceholderText("난이도 직접 입력")
        difficulty_input_wrap = QWidget()
        difficulty_input_wrap.setObjectName("planTransparent")
        difficulty_input_layout = QHBoxLayout(difficulty_input_wrap)
        difficulty_input_layout.setContentsMargins(0, 0, 0, 0)
        difficulty_input_layout.setSpacing(scale_px(6, self._ui_scale))
        difficulty_input_layout.addWidget(self._raid_difficulty_input, 1)
        difficulty_input_layout.addWidget(self._raid_difficulty_custom_input, 1)
        self._raid_terrain_input = InventorySortDropdownButton()
        for terrain in ("실내전", "시가전", "야전"):
            self._raid_terrain_input.addItem(terrain, terrain)
        self._raid_time_limit_input = QSpinBox()
        self._raid_time_limit_input.setRange(0, 9999)
        self._raid_time_limit_input.setButtonSymbols(QAbstractSpinBox.NoButtons)
        time_limit_wrap = QWidget()
        time_limit_wrap.setObjectName("planTransparent")
        time_limit_layout = QHBoxLayout(time_limit_wrap)
        time_limit_layout.setContentsMargins(0, 0, 0, 0)
        time_limit_layout.setSpacing(scale_px(6, self._ui_scale))
        time_limit_layout.addWidget(self._raid_time_limit_input, 1)
        time_limit_label = QLabel("sec")
        time_limit_label.setObjectName("detailMiniSub")
        time_limit_layout.addWidget(time_limit_label)
        self._raid_notes_input = ImmediatePlaceholderPlainTextEdit()
        self._raid_notes_input.setPlaceholderText("공략 전체 메모")
        self._raid_notes_input.setMaximumHeight(scale_px(72, self._ui_scale))
        self._raid_editor_state_label = QLabel("")
        self._raid_editor_state_label.setWordWrap(True)
        meta_layout.addWidget(QLabel("제목"), 0, 0)
        meta_layout.addWidget(self._raid_title_input, 0, 1, 1, 3)
        meta_layout.addWidget(QLabel("모드"), 1, 0)
        meta_layout.addWidget(self._raid_mode_input, 1, 1)
        meta_layout.addWidget(QLabel("지형"), 1, 2)
        meta_layout.addWidget(self._raid_terrain_input, 1, 3)
        meta_layout.addWidget(QLabel("보스"), 2, 0)
        meta_layout.addWidget(boss_input_wrap, 2, 1, 1, 3)
        meta_layout.addWidget(QLabel("난이도"), 3, 0)
        meta_layout.addWidget(difficulty_input_wrap, 3, 1)
        meta_layout.addWidget(QLabel("제한시간"), 3, 2)
        meta_layout.addWidget(time_limit_wrap, 3, 3)
        meta_layout.addWidget(self._raid_notes_input, 4, 0, 1, 4)
        meta_layout.addWidget(self._raid_editor_state_label, 5, 0, 1, 4)
        list_layout.insertWidget(0, meta_panel)

        step_row = QHBoxLayout()
        step_row.setContentsMargins(0, 0, 0, 0)
        step_row.setSpacing(scale_px(8, self._ui_scale))
        self._raid_deck_step_button = QPushButton("1. 덱 설정")
        self._raid_timeline_step_button = QPushButton("2. 타임라인 작성")
        self._raid_deck_step_button.clicked.connect(lambda: self._set_raid_editor_step(0))
        self._raid_timeline_step_button.clicked.connect(self._go_raid_timeline_step)
        step_row.addWidget(self._raid_deck_step_button)
        step_row.addWidget(self._raid_timeline_step_button)
        step_row.addStretch(1)
        editor_layout.addLayout(step_row)

        self._raid_editor_stack = QStackedWidget()
        self._raid_editor_stack.setObjectName("sectionTransparentStack")

        deck_panel = QFrame()
        deck_panel.setObjectName("planBand")
        deck_layout = QVBoxLayout(deck_panel)
        deck_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        deck_header = QLabel("덱")
        deck_header.setObjectName("sectionTitle")
        deck_layout.addWidget(deck_header)
        self._raid_deck_preview_host = QWidget()
        self._raid_deck_preview_host.setObjectName("planTransparent")
        self._raid_deck_preview_grid = QGridLayout(self._raid_deck_preview_host)
        self._raid_deck_preview_grid.setContentsMargins(0, 0, 0, 0)
        self._raid_deck_preview_grid.setHorizontalSpacing(scale_px(10, self._ui_scale))
        self._raid_deck_preview_grid.setVerticalSpacing(scale_px(5, self._ui_scale))
        deck_layout.addWidget(self._raid_deck_preview_host)
        template_row = QHBoxLayout()
        template_row.setContentsMargins(0, 0, 0, 0)
        template_row.setSpacing(scale_px(6, self._ui_scale))
        self._raid_deck_template_input = QLineEdit()
        self._raid_deck_template_input.setPlaceholderText("스트라이커1 스트라이커2 ... 스페셜1 스페셜2  예: 드히나 수시노 아코 히마리")
        self._raid_deck_template_input.returnPressed.connect(self._import_raid_deck_template)
        template_import_button = QPushButton("Import")
        template_copy_button = QPushButton("Copy")
        template_import_button.clicked.connect(self._import_raid_deck_template)
        template_copy_button.clicked.connect(self._copy_raid_deck_template)
        template_row.addWidget(self._raid_deck_template_input, 1)
        template_row.addWidget(template_import_button)
        template_row.addWidget(template_copy_button)
        deck_layout.addLayout(template_row)
        order_row = QHBoxLayout()
        order_row.setContentsMargins(0, 0, 0, 0)
        order_row.setSpacing(scale_px(6, self._ui_scale))
        self._raid_order_pick_button = QPushButton("순서 설정")
        self._raid_order_pick_button.setCheckable(True)
        self._raid_order_pick_button.setToolTip("켜둔 상태에서 캐릭터 아이콘을 누르면 1번부터 첫 사용 순서가 붙습니다. 이미 번호가 붙은 아이콘을 누르면 해당 번호를 제거합니다.")
        self._raid_order_pick_button.toggled.connect(self._update_raid_order_status)
        self._raid_order_clear_button = QPushButton("순서 초기화")
        self._raid_order_clear_button.setToolTip("모든 첫 사용 순서를 지웁니다.")
        self._raid_order_clear_button.clicked.connect(self._clear_raid_first_orders)
        self._raid_order_status = QLabel("")
        self._raid_order_status.setObjectName("filterSummary")
        self._raid_order_status.setWordWrap(True)
        order_row.addWidget(self._raid_order_pick_button)
        order_row.addWidget(self._raid_order_clear_button)
        order_row.addWidget(self._raid_order_status, 1)
        deck_layout.addLayout(order_row)
        detail_panel = QFrame()
        detail_panel.setObjectName("planSectionPanel")
        detail_layout = QGridLayout(detail_panel)
        detail_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        detail_layout.setHorizontalSpacing(scale_px(10, self._ui_scale))
        detail_layout.setVerticalSpacing(scale_px(8, self._ui_scale))
        self._raid_slot_detail_title = QLabel("슬롯을 선택하세요")
        self._raid_slot_detail_title.setObjectName("sectionTitle")
        self._raid_slot_detail_student = QLabel("")
        self._raid_slot_detail_student.setObjectName("detailSub")
        self._raid_slot_student_input = QLineEdit()
        self._raid_slot_student_input.setPlaceholderText("학생 이름 또는 별칭")
        self._raid_slot_student_input.editingFinished.connect(self._apply_selected_raid_slot_student_text)
        self._raid_slot_borrowed = QCheckBox("대여 학생")
        self._raid_slot_borrowed.stateChanged.connect(self._update_selected_raid_slot_detail)
        condition_panel = QFrame()
        condition_panel.setObjectName("planTransparent")
        condition_layout = QVBoxLayout(condition_panel)
        condition_layout.setContentsMargins(0, 0, 0, 0)
        condition_layout.setSpacing(scale_px(7, self._ui_scale))
        condition_title = QLabel("육성 조건")
        condition_title.setObjectName("sectionTitle")
        condition_layout.addWidget(condition_title)
        star_row = QHBoxLayout()
        star_row.setContentsMargins(0, 0, 0, 0)
        star_row.setSpacing(scale_px(6, self._ui_scale))
        star_label = QLabel("성작")
        star_label.setObjectName("detailMiniSub")
        self._raid_slot_star_selector = PlanSegmentSelector(9, color_break=5, ui_scale=self._ui_scale)
        self._raid_slot_star_selector.valueChanged.connect(self._update_selected_raid_slot_detail)
        star_row.addWidget(star_label)
        star_row.addWidget(self._raid_slot_star_selector, 1)
        condition_layout.addLayout(star_row)
        skill_grid = QGridLayout()
        skill_grid.setContentsMargins(0, 0, 0, 0)
        skill_grid.setHorizontalSpacing(scale_px(6, self._ui_scale))
        skill_grid.setVerticalSpacing(scale_px(3, self._ui_scale))
        self._raid_slot_skill_inputs: dict[str, QSpinBox] = {}
        for column, (key, label, maximum) in enumerate((
            ("ex", "EX", 5),
            ("basic", "기본", 10),
            ("enhanced", "강화", 10),
            ("sub", "서브", 10),
        )):
            spin = MaxTokenSpinBox(show_max_token=True)
            spin.setRange(0, maximum)
            spin.setSpecialValueText("-")
            spin.valueChanged.connect(self._update_selected_raid_slot_detail)
            skill_label = QLabel(label)
            skill_label.setObjectName("detailMiniSub")
            skill_grid.addWidget(skill_label, 0, column)
            skill_grid.addWidget(spin, 1, column)
            self._raid_slot_skill_inputs[key] = spin
        condition_layout.addLayout(skill_grid)
        equipment_grid = QGridLayout()
        equipment_grid.setContentsMargins(0, 0, 0, 0)
        equipment_grid.setHorizontalSpacing(scale_px(6, self._ui_scale))
        equipment_grid.setVerticalSpacing(scale_px(3, self._ui_scale))
        self._raid_slot_equipment_inputs: dict[str, QSpinBox] = {}
        self._raid_slot_equipment_labels: dict[str, QLabel] = {}
        for column, (key, label, maximum) in enumerate((
            ("equip1", "장비1", 10),
            ("equip2", "장비2", 10),
            ("equip3", "장비3", 10),
            ("unique", "애용품", 2),
        )):
            spin = MaxTokenSpinBox()
            spin.setRange(0, maximum)
            spin.setSpecialValueText("-")
            spin.setPrefix("T")
            spin.valueChanged.connect(self._update_selected_raid_slot_detail)
            equipment_label = QLabel(label)
            equipment_label.setObjectName("detailMiniSub")
            equipment_grid.addWidget(equipment_label, 0, column)
            equipment_grid.addWidget(spin, 1, column)
            self._raid_slot_equipment_labels[key] = equipment_label
            self._raid_slot_equipment_inputs[key] = spin
        condition_layout.addLayout(equipment_grid)
        stat_grid = QGridLayout()
        stat_grid.setContentsMargins(0, 0, 0, 0)
        stat_grid.setHorizontalSpacing(scale_px(6, self._ui_scale))
        stat_grid.setVerticalSpacing(scale_px(3, self._ui_scale))
        self._raid_slot_stat_inputs: dict[str, QSpinBox] = {}
        for column, (key, label) in enumerate((
            ("hp", "HP"),
            ("atk", "ATK"),
            ("heal", "HEAL"),
        )):
            spin = MaxTokenSpinBox()
            spin.setRange(0, 25)
            spin.valueChanged.connect(self._update_selected_raid_slot_detail)
            max_button = QPushButton("MAX")
            max_button.setFixedWidth(scale_px(48, self._ui_scale))
            max_button.clicked.connect(lambda _checked=False, target=spin: target.setValue(target.maximum()))
            stat_label = QLabel(label)
            stat_label.setObjectName("detailMiniSub")
            stat_input_row = QHBoxLayout()
            stat_input_row.setContentsMargins(0, 0, 0, 0)
            stat_input_row.setSpacing(scale_px(4, self._ui_scale))
            stat_input_row.addWidget(spin, 1)
            stat_input_row.addWidget(max_button)
            stat_grid.addWidget(stat_label, 0, column)
            stat_grid.addLayout(stat_input_row, 1, column)
            self._raid_slot_stat_inputs[key] = spin
        condition_layout.addLayout(stat_grid)
        condition_layout.addStretch(1)
        notes_panel = QFrame()
        notes_panel.setObjectName("planTransparent")
        notes_layout = QVBoxLayout(notes_panel)
        notes_layout.setContentsMargins(0, 0, 0, 0)
        notes_layout.setSpacing(scale_px(6, self._ui_scale))
        notes_title = QLabel("슬롯 메모")
        notes_title.setObjectName("sectionTitle")
        notes_layout.addWidget(notes_title)
        self._raid_slot_notes = ImmediatePlaceholderPlainTextEdit()
        self._raid_slot_notes.setPlaceholderText("선택한 학생/슬롯 메모")
        self._raid_slot_notes.setMinimumHeight(scale_px(128, self._ui_scale))
        self._raid_slot_notes.textChanged.connect(self._update_selected_raid_slot_detail)
        notes_layout.addWidget(self._raid_slot_notes, 1)
        detail_body = QWidget()
        detail_body.setObjectName("planTransparent")
        detail_body_layout = QHBoxLayout(detail_body)
        detail_body_layout.setContentsMargins(0, 0, 0, 0)
        detail_body_layout.setSpacing(scale_px(12, self._ui_scale))
        detail_body_layout.addWidget(condition_panel, 1)
        detail_body_layout.addWidget(notes_panel, 1)
        detail_layout.addWidget(self._raid_slot_detail_title, 0, 0)
        detail_layout.addWidget(self._raid_slot_student_input, 0, 1)
        detail_layout.addWidget(self._raid_slot_borrowed, 0, 2)
        detail_layout.addWidget(detail_body, 1, 0, 1, 3)
        detail_layout.setColumnStretch(1, 1)
        deck_layout.addWidget(detail_panel)
        deck_action_row = QHBoxLayout()
        deck_action_row.setContentsMargins(0, 0, 0, 0)
        self._raid_deck_status = QLabel("")
        self._raid_deck_status.setObjectName("filterSummary")
        self._raid_deck_status.setWordWrap(True)
        self._raid_to_timeline_button = QPushButton("타임라인 작성으로")
        self._raid_to_timeline_button.clicked.connect(self._go_raid_timeline_step)
        deck_save_button = QPushButton("저장")
        deck_save_button.clicked.connect(self._save_current_raid_guide)
        deck_action_row.addWidget(self._raid_deck_status, 1)
        deck_action_row.addWidget(deck_save_button)
        deck_action_row.addWidget(self._raid_to_timeline_button)
        deck_layout.addLayout(deck_action_row)

        timeline_panel = QFrame()
        timeline_panel.setObjectName("planBand")
        timeline_layout = QVBoxLayout(timeline_panel)
        timeline_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        timeline_layout.setSpacing(scale_px(8, self._ui_scale))
        action_row = QHBoxLayout()
        action_row.setContentsMargins(0, 0, 0, 0)
        timeline_title = QLabel("타임라인")
        timeline_title.setObjectName("sectionTitle")
        action_row.addWidget(timeline_title)
        edit_deck_button = QPushButton("덱 수정")
        edit_deck_button.clicked.connect(lambda: self._set_raid_editor_step(0))
        action_row.addWidget(edit_deck_button)
        assist_button = QPushButton("보조 모드")
        assist_button.clicked.connect(self._open_raid_assist)
        action_row.addWidget(assist_button)
        action_row.addStretch(1)
        for label, callback in (
            ("행 추가", self._add_raid_timeline_row),
            ("복제", self._duplicate_raid_timeline_row),
            ("삭제", self._delete_raid_timeline_row),
            ("위", lambda: self._move_raid_timeline_row(-1)),
            ("아래", lambda: self._move_raid_timeline_row(1)),
        ):
            button = QPushButton(label)
            button.clicked.connect(callback)
            action_row.addWidget(button)
        timeline_layout.addLayout(action_row)

        self._raid_deck_summary_host = QWidget()
        self._raid_deck_summary_host.setObjectName("planTransparent")
        self._raid_deck_summary_grid = QGridLayout(self._raid_deck_summary_host)
        self._raid_deck_summary_grid.setContentsMargins(0, 0, 0, 0)
        self._raid_deck_summary_grid.setHorizontalSpacing(scale_px(8, self._ui_scale))
        self._raid_deck_summary_grid.setVerticalSpacing(scale_px(6, self._ui_scale))
        timeline_layout.addWidget(self._raid_deck_summary_host)

        self._raid_timeline_table = QTableWidget(0, 5)
        self._raid_timeline_table.setHorizontalHeaderLabels(
            ["사용 타이밍", "사용 스킬", "시전 대상", "메모", "이미지"]
        )
        self._raid_timeline_table.setSelectionBehavior(QAbstractItemView.SelectRows)
        self._raid_timeline_table.setSelectionMode(QAbstractItemView.SingleSelection)
        self._raid_timeline_table.setEditTriggers(QAbstractItemView.AllEditTriggers)
        self._raid_timeline_table.setAlternatingRowColors(True)
        timeline_font = QFont(self._raid_timeline_table.font())
        if timeline_font.pointSize() > 0:
            timeline_font.setPointSize(timeline_font.pointSize() + 1)
        elif timeline_font.pixelSize() > 0:
            timeline_font.setPixelSize(timeline_font.pixelSize() + 1)
        else:
            timeline_font.setPointSize(11)
        self._raid_timeline_table.setFont(timeline_font)
        self._raid_timeline_table.verticalHeader().setVisible(True)
        self._raid_timeline_table.verticalHeader().setDefaultSectionSize(scale_px(30, self._ui_scale))
        header_view = self._raid_timeline_table.horizontalHeader()
        header_view.setSectionResizeMode(QHeaderView.Interactive)
        header_view.setSectionResizeMode(3, QHeaderView.Stretch)
        self._raid_timeline_table.setColumnWidth(0, scale_px(150, self._ui_scale))
        self._raid_timeline_table.setColumnWidth(1, scale_px(180, self._ui_scale))
        self._raid_timeline_table.setColumnWidth(2, scale_px(160, self._ui_scale))
        self._raid_timeline_table.setColumnWidth(4, scale_px(130, self._ui_scale))
        self._raid_timeline_table.itemChanged.connect(self._on_raid_timeline_item_changed)
        timeline_layout.addWidget(self._raid_timeline_table, 1)

        paste_row = QHBoxLayout()
        paste_row.setContentsMargins(0, 0, 0, 0)
        self._raid_paste_input = QPlainTextEdit()
        self._raid_paste_input.setPlaceholderText("아카라이브 표나 텍스트 타임라인을 붙여넣고 가져오기를 누르세요.")
        self._raid_paste_input.setMaximumHeight(scale_px(86, self._ui_scale))
        paste_button = QPushButton("붙여넣기 가져오기")
        paste_button.clicked.connect(self._import_raid_timeline_text)
        paste_row.addWidget(self._raid_paste_input, 1)
        paste_row.addWidget(paste_button)
        timeline_layout.addLayout(paste_row)

        bottom_row = QHBoxLayout()
        bottom_row.setContentsMargins(0, 0, 0, 0)
        self._raid_status = QLabel("")
        self._raid_status.setObjectName("filterSummary")
        self._raid_status.setWordWrap(True)
        bottom_row.addWidget(self._raid_status, 1)
        save_button = QPushButton("저장")
        save_button.clicked.connect(self._save_current_raid_guide)
        bottom_assist_button = QPushButton("보조 모드")
        bottom_assist_button.clicked.connect(self._open_raid_assist)
        bottom_row.addWidget(save_button)
        bottom_row.addWidget(bottom_assist_button)
        timeline_layout.addLayout(bottom_row)
        self._raid_editor_stack.addWidget(deck_panel)
        self._raid_editor_stack.addWidget(timeline_panel)
        editor_layout.addWidget(self._raid_editor_stack, 1)
        splitter.addWidget(editor_panel)
        splitter.setStretchFactor(0, 3)
        splitter.setStretchFactor(1, 7)

        self._selected_raid_guide_id = self._raid_guide_data.guides[0].id if self._raid_guide_data.guides else None
        self._refresh_raid_guide_list()
        self._load_selected_raid_guide()
        self._set_raid_editor_step(0)
    def _current_raid_guide(self) -> RaidGuide | None:
        selected_id = getattr(self, "_selected_raid_guide_id", None)
        for guide in self._raid_guide_data.guides:
            if guide.id == selected_id:
                return guide
        return self._raid_guide_data.guides[0] if self._raid_guide_data.guides else None
    def _set_raid_combo_text(self, combo: QComboBox, value: str) -> None:
        text = str(value or "").strip()
        combo.blockSignals(True)
        if text:
            index = combo.findText(text, Qt.MatchFixedString)
            if index >= 0:
                combo.setCurrentIndex(index)
            else:
                combo.setCurrentIndex(-1)
                combo.setEditText(text)
        else:
            combo.setCurrentIndex(-1)
            combo.setEditText("")
        combo.blockSignals(False)
    def _raid_combo_text(self, combo: QComboBox) -> str:
        text = combo.currentText().strip()
        return "" if text == RAID_CUSTOM_INPUT_LABEL else text
    def _raid_current_boss(self) -> str:
        if not hasattr(self, "_raid_boss_input"):
            return ""
        data = str(self._raid_boss_input.currentData() or "").strip()
        if data:
            return data
        return self._raid_boss_custom_input.text().strip() if hasattr(self, "_raid_boss_custom_input") else ""
    def _set_raid_boss_value(self, value: str) -> None:
        if not hasattr(self, "_raid_boss_input"):
            return
        boss = str(value or "").strip()
        if boss and boss in RAID_BOSS_TIME_LIMIT_SECONDS:
            self._raid_boss_input.setCurrentData(boss)
            if hasattr(self, "_raid_boss_custom_input"):
                self._raid_boss_custom_input.clear()
                self._raid_boss_custom_input.hide()
        else:
            self._raid_boss_input.setCurrentData("")
            if hasattr(self, "_raid_boss_custom_input"):
                self._raid_boss_custom_input.setText(boss)
                self._raid_boss_custom_input.show()
    def _sync_raid_difficulty_custom_visibility(self) -> None:
        if not hasattr(self, "_raid_difficulty_custom_input"):
            return
        self._raid_difficulty_custom_input.setVisible(not str(self._raid_difficulty_input.currentData() or "").strip())
    def _raid_current_difficulty(self) -> str:
        if not hasattr(self, "_raid_difficulty_input"):
            return ""
        data = str(self._raid_difficulty_input.currentData() or "").strip()
        if data:
            return data
        return self._raid_difficulty_custom_input.text().strip() if hasattr(self, "_raid_difficulty_custom_input") else ""
    def _set_raid_difficulty_value(self, value: str) -> None:
        if not hasattr(self, "_raid_difficulty_input"):
            return
        difficulty = str(value or "").strip()
        if difficulty and difficulty in RAID_GUIDE_DIFFICULTIES:
            self._raid_difficulty_input.setCurrentData(difficulty)
            if hasattr(self, "_raid_difficulty_custom_input"):
                self._raid_difficulty_custom_input.clear()
                self._raid_difficulty_custom_input.hide()
        else:
            self._raid_difficulty_input.setCurrentData("")
            if hasattr(self, "_raid_difficulty_custom_input"):
                self._raid_difficulty_custom_input.setText(difficulty)
                self._raid_difficulty_custom_input.show()
    def _raid_generated_title(self, *, terrain: str, boss: str, difficulty: str) -> str:
        parts = [
            str(terrain or "지형").strip() or "지형",
            str(boss or "보스").strip() or "보스",
            str(difficulty or "난이도").strip() or "난이도",
        ]
        return "_".join(parts)
    def _raid_guide_display_title(self, guide: RaidGuide) -> str:
        title = str(guide.title or "").strip()
        if title:
            return title
        return self._raid_generated_title(terrain=guide.terrain, boss=guide.boss, difficulty=guide.difficulty)
    def _raid_unique_generated_title(self, base_title: str, current_guide_id: str) -> str:
        base = str(base_title or "").strip() or self._raid_generated_title(terrain="", boss="", difficulty="")
        data = getattr(self, "_raid_guide_data", None)
        existing_titles: set[str] = set()
        for guide in getattr(data, "guides", []):
            if guide.id == current_guide_id:
                continue
            display_title = self._raid_guide_display_title(guide).strip()
            if display_title:
                existing_titles.add(display_title)
        if base not in existing_titles:
            return base
        suffix = 2
        while f"{base}_{suffix}" in existing_titles:
            suffix += 1
        return f"{base}_{suffix}"
    def _raid_should_generate_title(self, raw_title: str, previous_generated_title: str) -> bool:
        title = str(raw_title or "").strip()
        if not title:
            return True
        if title == previous_generated_title:
            return True
        return title.replace(" ", "") in {"새공략", "공략"}
    def _on_raid_boss_changed(self) -> None:
        if getattr(self, "_raid_guide_editor_guard", False):
            return
        boss = self._raid_current_boss()
        if hasattr(self, "_raid_boss_custom_input"):
            self._raid_boss_custom_input.setVisible(not str(self._raid_boss_input.currentData() or "").strip())
        time_limit = RAID_BOSS_TIME_LIMIT_SECONDS.get(boss)
        if time_limit is not None:
            self._raid_time_limit_input.setValue(time_limit)
        default_mode = RAID_BOSS_DEFAULT_MODES.get(boss)
        if default_mode and self._raid_mode_input.currentData() != default_mode:
            self._raid_mode_input.setCurrentData(default_mode)
    def _set_raid_editor_step(self, index: int) -> None:
        if not hasattr(self, "_raid_editor_stack"):
            return
        self._raid_editor_stack.setCurrentIndex(max(0, min(1, index)))
        active = self._raid_editor_stack.currentIndex()
        self._raid_deck_step_button.setStyleSheet("font-weight: 900;" if active == 0 else "")
        self._raid_timeline_step_button.setStyleSheet("font-weight: 900;" if active == 1 else "")
        if active == 1:
            self._refresh_raid_deck_summary()
    def _refresh_raid_editor_source_state(self) -> None:
        if not hasattr(self, "_raid_editor_state_label"):
            return
        current = self._current_raid_guide()
        if current is None:
            self._raid_editor_state_label.setText("현재 상태: 선택된 공략 없음")
            self._raid_editor_state_label.setStyleSheet(
                f"color: #8a93a7; font-weight: 800; padding: {scale_px(5, self._ui_scale)}px;"
            )
            return
        if current.id in getattr(self, "_raid_new_guide_ids", set()):
            self._raid_editor_state_label.setText("현재 상태: 새 공략 작성 중")
            self._raid_editor_state_label.setStyleSheet(
                "color: #2f80ed; font-weight: 900; "
                f"padding: {scale_px(6, self._ui_scale)}px; "
                "border: 1px solid rgba(47, 128, 237, 0.45); "
                "border-radius: 6px; "
                "background: rgba(47, 128, 237, 0.10);"
            )
            return
        self._raid_editor_state_label.setText("현재 상태: 기존 공략 수정 중")
        self._raid_editor_state_label.setStyleSheet(
            "color: #4f5d75; font-weight: 900; "
            f"padding: {scale_px(6, self._ui_scale)}px; "
            "border: 1px solid rgba(79, 93, 117, 0.28); "
            "border-radius: 6px; "
            "background: rgba(79, 93, 117, 0.08);"
        )
    def _raid_deck_complete(self) -> bool:
        for row in getattr(self, "_raid_deck_rows", []):
            student_id = str(row.get("student_id") or "")
            if not student_id or student_id not in self._records_by_id:
                return False
        return bool(getattr(self, "_raid_deck_rows", []))
    def _go_raid_timeline_step(self) -> None:
        self._sync_raid_deck_slot_icons()
        self._raid_deck_status.setStyleSheet("")
        self._set_raid_editor_step(1)
    def _update_raid_step_state(self) -> None:
        if not hasattr(self, "_raid_to_timeline_button"):
            return
        complete = self._raid_deck_complete()
        self._raid_to_timeline_button.setEnabled(True)
        self._raid_timeline_step_button.setEnabled(True)
        if hasattr(self, "_raid_deck_status"):
            guide = self._collect_raid_guide_from_editor()
            filled = sum(1 for slot in guide.deck if slot.student_id)
            total = len(guide.deck)
            if complete:
                self._raid_deck_status.setStyleSheet("")
                self._raid_deck_status.setText(f"덱 설정 완료 · {filled}/{total}")
            else:
                self._raid_deck_status.setStyleSheet("")
                self._raid_deck_status.setText(f"덱 슬롯 {filled}/{total} 입력")
    def _save_raid_guide_data(self) -> None:
        save_raid_guides(self._raid_guide_path, self._raid_guide_data)
        self._storage_mtimes = self._snapshot_storage_mtimes()
    def _open_raid_assist(self) -> None:
        if not hasattr(self, "_raid_timeline_table"):
            return
        guide = self._collect_raid_guide_from_editor()
        if not guide.timeline:
            if hasattr(self, "_raid_status"):
                self._raid_status.setStyleSheet("color: #ffb84d; font-weight: 800;")
                self._raid_status.setText("Assist needs at least one timeline step.")
            return
        existing = getattr(self, "_raid_assist_window", None)
        if existing is not None:
            existing.close()
        window = TacticAssistWindow(
            guide,
            template_root=TEMPLATE_DIR / "tactic_assist",
            parent=self,
        )
        window.destroyed.connect(lambda *_: setattr(self, "_raid_assist_window", None))
        self._raid_assist_window = window
        window.show()
    def _raid_student_label(self, student_id: str) -> str:
        if not student_id:
            return ""
        record = self._records_by_id.get(student_id)
        return record.title if record is not None else student_meta.display_name(student_id)
    def _raid_lookup_key(self, value: object) -> str:
        cleaned = " ".join(str(value or "").strip().split())
        cleaned = re.sub(r"\s*([()])\s*", r"\1", cleaned)
        return cleaned.casefold()
    def _raid_student_lookup_index_map(self) -> dict[str, list[str]]:
        cached = getattr(self, "_raid_student_lookup_index", None)
        if cached is not None:
            return cached
        index: dict[str, set[str]] = defaultdict(set)
        for student_id in student_meta.all_ids():
            record = self._records_by_id.get(student_id)
            terms: list[object] = [
                student_id,
                student_id.replace("_", " "),
                student_meta.display_name(student_id),
                record.title if record is not None else "",
                record.display_name if record is not None else "",
            ]
            terms.extend(student_meta.search_tags(student_id))
            terms.extend(student_meta.kr_search_tags(student_id))
            for term in terms:
                key = self._raid_lookup_key(term)
                if key:
                    index[key].add(student_id)
        self._raid_student_lookup_index = {
            key: sorted(values, key=lambda student_id: self._raid_student_label(student_id).casefold())
            for key, values in index.items()
        }
        return self._raid_student_lookup_index
    def _raid_student_id_for_text(self, text: str) -> str:
        raw = str(text or "").strip()
        if not raw:
            return ""
        if raw in self._records_by_id or raw in set(student_meta.all_ids()):
            return raw
        matches = self._raid_student_lookup_index_map().get(self._raid_lookup_key(raw), [])
        return matches[0] if len(matches) == 1 else raw
    def _raid_slot_expected_combat_class(self, slot_type: object) -> str:
        return "special" if str(slot_type or "") == "support" else str(slot_type or "")
    def _raid_portrait_pixmap(self, student_id: str, size: int) -> QPixmap:
        if not student_id or student_id not in self._records_by_id:
            return QPixmap()
        source = ensure_thumbnail(student_id, size, size)
        if source is None or not source.exists():
            return QPixmap()
        pixmap = QPixmap(str(source))
        return pixmap if not pixmap.isNull() else QPixmap()
    def _make_raid_student_combo(self, expected_class: str | None = None) -> QComboBox:
        combo = QComboBox()
        combo.setEditable(True)
        combo.addItem("", "")
        records = sorted(self._all_students, key=lambda record: record.title.casefold())
        for record in records:
            if expected_class and student_meta.combat_class(record.student_id) != expected_class:
                continue
            combo.addItem(record.title, record.student_id)
        return combo
    def _set_combo_student(self, combo: QComboBox, student_id: str) -> None:
        if not student_id:
            combo.setCurrentIndex(0)
            return
        index = combo.findData(student_id)
        if index >= 0:
            combo.setCurrentIndex(index)
        else:
            combo.setEditText(self._raid_student_label(student_id) if student_id in self._records_by_id else student_id)
    def _combo_student_id(self, combo: QComboBox) -> str:
        data = combo.currentData()
        if data:
            return str(data)
        return self._raid_student_id_for_text(combo.currentText())
    def _raid_template_label_for_student(self, student_id: str) -> str:
        return self._raid_student_label(student_id) if student_id in self._records_by_id else str(student_id or "")
    def _raid_deck_template_from_slots(self) -> str:
        strikers: list[str] = []
        supports: list[str] = []
        for row in getattr(self, "_raid_deck_rows", []):
            student_id = str(row.get("student_id") or "")
            label = self._raid_template_label_for_student(student_id)
            if row.get("slot_type") == "striker":
                strikers.append(label)
            else:
                supports.append(label)
        tokens = [*strikers, *supports]
        while tokens and not tokens[-1]:
            tokens.pop()
        return " ".join(token or "-" for token in tokens)
    def _sync_raid_template_from_slots(self) -> None:
        if getattr(self, "_raid_template_sync_guard", False) or not hasattr(self, "_raid_deck_template_input"):
            return
        self._raid_template_sync_guard = True
        self._raid_deck_template_input.setText(self._raid_deck_template_from_slots())
        self._raid_template_sync_guard = False
    def _raid_template_parts(self, value: str) -> list[str]:
        text = str(value or "")
        has_explicit_separator = any(separator in text for separator in ",/;")
        if has_explicit_separator:
            parts = text.replace("/", ",").replace(";", ",").replace("\n", ",").split(",")
        else:
            parts = text.split()
        return ["" if part.strip() == "-" else part.strip() for part in parts]
    def _raid_student_ids_for_text(self, text: str) -> list[str]:
        needle = self._raid_lookup_key(text)
        if not needle:
            return []
        return list(self._raid_student_lookup_index_map().get(needle, []))
    def _parse_raid_deck_template(self, value: str) -> tuple[list[str], list[str], list[str]]:
        raw = str(value or "").strip()
        striker_count, support_count = slot_counts_for_mode(str(self._raid_mode_input.currentData() or ""))
        if "|" in raw:
            striker_raw, support_raw = raw.split("|", 1)
            striker_tokens = self._raid_template_parts(striker_raw)
            support_tokens = self._raid_template_parts(support_raw)
        else:
            tokens = self._raid_template_parts(raw)
            striker_tokens = tokens[:striker_count]
            support_tokens = tokens[striker_count : striker_count + support_count]

        errors: list[str] = []

        def resolve(tokens: list[str], expected_class: str, label: str, maximum: int) -> list[str]:
            resolved: list[str] = []
            for index, token in enumerate(tokens[:maximum], start=1):
                if not token:
                    resolved.append("")
                    continue
                matches = self._raid_student_ids_for_text(token)
                if not matches:
                    errors.append(f"{label}{index}: '{token}' 학생을 인식할 수 없습니다.")
                    resolved.append(token)
                    continue
                if len(matches) > 1:
                    names = ", ".join(self._raid_student_label(student_id) for student_id in matches[:6])
                    suffix = "..." if len(matches) > 6 else ""
                    errors.append(f"{label}{index}: '{token}' 중복 태그입니다. ({names}{suffix})")
                    resolved.append(token)
                    continue
                student_id = matches[0]
                if student_meta.combat_class(student_id) != self._raid_slot_expected_combat_class(expected_class):
                    errors.append(f"{label}{index}: '{self._raid_student_label(student_id)}'는 {label} 슬롯에 배치할 수 없습니다.")
                resolved.append(student_id)
            resolved += [""] * max(0, maximum - len(resolved))
            return resolved

        return (
            resolve(striker_tokens, "striker", "S", striker_count),
            resolve(support_tokens, "special", "SP", support_count),
            errors,
        )
    def _apply_raid_deck_template(self, value: str) -> list[str]:
        strikers, supports, errors = self._parse_raid_deck_template(value)
        self._raid_template_sync_guard = True
        for row in getattr(self, "_raid_deck_rows", []):
            source = strikers if row.get("slot_type") == "striker" else supports
            slot_index = int(row.get("slot_index") or 1) - 1
            row["student_id"] = source[slot_index] if slot_index < len(source) else ""
        self._raid_template_sync_guard = False
        self._sync_raid_deck_slot_icons()
        self._sync_raid_template_from_slots()
        self._refresh_selected_raid_slot_detail()
        self._update_raid_step_state()
        self._refresh_raid_validation()
        return errors
    def _import_raid_deck_template(self) -> None:
        value = self._raid_deck_template_input.text().strip() or QApplication.clipboard().text().strip()
        if not value:
            return
        errors = self._apply_raid_deck_template(value)
        if errors:
            self._raid_deck_status.setStyleSheet("color: #ffb84d; font-weight: 800;")
            self._raid_deck_status.setText(" / ".join(errors[:3]) + (f" 외 {len(errors) - 3}개" if len(errors) > 3 else ""))
    def _copy_raid_deck_template(self) -> None:
        text = self._raid_deck_template_from_slots()
        self._raid_deck_template_input.setText(text)
        QApplication.clipboard().setText(text)
    def _sync_raid_deck_slot_icons(self) -> None:
        preview_icons = getattr(self, "_raid_deck_preview_icons", [])
        for index, row in enumerate(getattr(self, "_raid_deck_rows", [])):
            icon = preview_icons[index] if index < len(preview_icons) else None
            if not isinstance(icon, TacticalDeckSlot):
                continue
            student_id = str(row.get("student_id") or "")
            name = self._raid_student_label(student_id) if student_id in self._records_by_id else student_id
            pixmap = self._raid_portrait_pixmap(student_id, max(self._thumb_width, self._thumb_height))
            first_order = int(row.get("first_order") or 0)
            icon.setData(
                name=name,
                pixmap=pixmap,
                badge_text=str(first_order) if first_order > 0 else "",
                corner_badge_text="A" if bool(row.get("borrowed")) else "",
            )
        self._update_raid_order_status()
    def _ordered_raid_deck_indices(self, *, exclude_index: int | None = None) -> list[int]:
        ordered: list[tuple[int, int]] = []
        for index, row in enumerate(getattr(self, "_raid_deck_rows", [])):
            if exclude_index is not None and index == exclude_index:
                continue
            try:
                order = int(row.get("first_order") or 0)
            except (TypeError, ValueError):
                order = 0
            if order > 0:
                ordered.append((order, index))
        return [index for _order, index in sorted(ordered)]
    def _apply_raid_first_order(self, index: int, order: int) -> None:
        rows = getattr(self, "_raid_deck_rows", [])
        if not rows or index < 0 or index >= len(rows):
            return
        ordered_indices = self._ordered_raid_deck_indices(exclude_index=index)
        if order > 0:
            insert_at = max(0, min(order - 1, len(ordered_indices)))
            ordered_indices.insert(insert_at, index)
        for row in rows:
            row["first_order"] = 0
        for order_index, row_index in enumerate(ordered_indices, start=1):
            rows[row_index]["first_order"] = order_index
        self._sync_raid_deck_slot_icons()
        self._refresh_selected_raid_slot_detail()
        self._refresh_raid_validation()
    def _next_raid_first_order(self) -> int:
        rows = getattr(self, "_raid_deck_rows", [])
        used: set[int] = set()
        for row in rows:
            try:
                order = int(row.get("first_order") or 0)
            except (TypeError, ValueError):
                order = 0
            if order > 0:
                used.add(order)
        for order in range(1, len(rows) + 1):
            if order not in used:
                return order
        return len(rows) + 1
    def _update_raid_order_status(self, _checked: bool | None = None) -> None:
        if not hasattr(self, "_raid_order_status"):
            return
        rows = getattr(self, "_raid_deck_rows", [])
        count = 0
        for row in rows:
            try:
                order = int(row.get("first_order") or 0)
            except (TypeError, ValueError):
                order = 0
            if order > 0:
                count += 1
        if hasattr(self, "_raid_order_pick_button") and self._raid_order_pick_button.isChecked():
            self._raid_order_pick_button.setText("확인")
            next_order = self._next_raid_first_order()
            self._raid_order_status.setText(f"아이콘을 누르면 {next_order}번으로 지정됩니다. 번호가 있는 아이콘은 누르면 해제됩니다.")
        else:
            if hasattr(self, "_raid_order_pick_button"):
                self._raid_order_pick_button.setText("순서 설정")
            self._raid_order_status.setText(f"첫 사용 순서 {count}/{len(rows)}")
    def _on_raid_deck_slot_clicked(self, index: int) -> None:
        self._select_raid_deck_slot(index)
        if not hasattr(self, "_raid_order_pick_button") or not self._raid_order_pick_button.isChecked():
            return
        rows = getattr(self, "_raid_deck_rows", [])
        if index < 0 or index >= len(rows):
            return
        if not str(rows[index].get("student_id") or ""):
            self._update_raid_order_status()
            return
        current_order = int(rows[index].get("first_order") or 0)
        self._apply_raid_first_order(index, 0 if current_order > 0 else self._next_raid_first_order())
    def _clear_raid_first_orders(self) -> None:
        for row in getattr(self, "_raid_deck_rows", []):
            row["first_order"] = 0
        self._sync_raid_deck_slot_icons()
        self._refresh_selected_raid_slot_detail()
        self._refresh_raid_validation()
    def _select_raid_deck_slot(self, index: int) -> None:
        rows = getattr(self, "_raid_deck_rows", [])
        if not rows:
            self._raid_selected_deck_slot_index = 0
            return
        self._raid_selected_deck_slot_index = max(0, min(index, len(rows) - 1))
        self._refresh_selected_raid_slot_detail()
    def _apply_selected_raid_slot_student_text(self) -> None:
        if getattr(self, "_raid_slot_detail_guard", False):
            return
        rows = getattr(self, "_raid_deck_rows", [])
        if not rows or not hasattr(self, "_raid_slot_student_input"):
            return
        index = max(0, min(getattr(self, "_raid_selected_deck_slot_index", 0), len(rows) - 1))
        row = rows[index]
        raw = self._raid_slot_student_input.text().strip()
        if not raw:
            row["student_id"] = ""
            row["borrowed"] = False
            row["first_order"] = 0
            row["star_conditions"] = {}
            row["skill_conditions"] = {}
            row["equipment_conditions"] = {}
            row["stat_conditions"] = {}
            self._sync_raid_deck_slot_icons()
            self._sync_raid_template_from_slots()
            self._refresh_selected_raid_slot_detail()
            self._update_raid_step_state()
            self._refresh_raid_validation()
            return

        warning_message = ""
        matches = self._raid_student_ids_for_text(raw)
        if len(matches) == 1:
            student_id = matches[0]
            row["student_id"] = student_id
            if not row.get("skill_conditions"):
                row["skill_conditions"] = self._default_raid_skill_conditions()
            expected_class = self._raid_slot_expected_combat_class(row.get("slot_type"))
            if expected_class and student_meta.combat_class(student_id) != expected_class:
                warning_message = f"{self._raid_student_label(student_id)}은(는) 이 슬롯 타입과 다릅니다."
        elif len(matches) > 1:
            names = ", ".join(self._raid_student_label(student_id) for student_id in matches[:6])
            suffix = "..." if len(matches) > 6 else ""
            self._raid_deck_status.setStyleSheet("color: #ffb84d; font-weight: 800;")
            self._raid_deck_status.setText(f"'{raw}' 후보가 여러 명입니다: {names}{suffix}")
            return
        else:
            row["student_id"] = raw
            warning_message = f"'{raw}' 학생을 인식하지 못했습니다."

        self._sync_raid_deck_slot_icons()
        self._sync_raid_template_from_slots()
        self._refresh_selected_raid_slot_detail()
        self._update_raid_step_state()
        self._refresh_raid_validation()
        if warning_message:
            self._raid_deck_status.setStyleSheet("color: #ffb84d; font-weight: 800;")
            self._raid_deck_status.setText(warning_message)
    def _raid_condition_values_from_inputs(self, inputs: dict[str, QSpinBox]) -> dict[str, int]:
        values: dict[str, int] = {}
        for key, spin in inputs.items():
            value = int(spin.value())
            if inputs is getattr(self, "_raid_slot_skill_inputs", {}) or value > 0:
                values[key] = value
        return values
    def _default_raid_skill_conditions(self) -> dict[str, int]:
        return {
            "ex": 5,
            "basic": 10,
            "enhanced": 10,
            "sub": 10,
        }
    def _raid_star_conditions_from_inputs(self) -> dict[str, int]:
        total = int(self._raid_slot_star_selector.value())
        weapon_star = max(0, total - 5)
        star = min(5, total)
        if weapon_star > 0:
            star = 5
        values: dict[str, int] = {}
        if star > 0:
            values["star"] = star
        if weapon_star > 0:
            values["weapon_star"] = weapon_star
        return values
    def _set_raid_star_condition_inputs(self, values: object) -> None:
        mapping = values if isinstance(values, dict) else {}
        try:
            star = max(0, min(5, int(mapping.get("star", 0) or 0)))
        except (TypeError, ValueError):
            star = 0
        try:
            weapon_star = max(0, min(4, int(mapping.get("weapon_star", 0) or 0)))
        except (TypeError, ValueError):
            weapon_star = 0
        total = 5 + weapon_star if weapon_star > 0 else star
        self._raid_slot_star_selector.blockSignals(True)
        self._raid_slot_star_selector.setState(minimum_value=0, value=total, enabled_count=9)
        self._raid_slot_star_selector.blockSignals(False)
    def _set_raid_condition_inputs(self, inputs: dict[str, QSpinBox], values: object) -> None:
        mapping = values if isinstance(values, dict) else {}
        for key, spin in inputs.items():
            spin.blockSignals(True)
            try:
                value = int(mapping.get(key, 0) or 0)
            except (TypeError, ValueError):
                value = 0
            spin.setValue(max(spin.minimum(), min(spin.maximum(), value)))
            spin.blockSignals(False)
    def _refresh_selected_raid_slot_detail(self) -> None:
        if not hasattr(self, "_raid_slot_detail_title"):
            return
        rows = getattr(self, "_raid_deck_rows", [])
        if not rows:
            self._raid_slot_detail_title.setText("슬롯을 선택하세요")
            self._raid_slot_detail_student.setText("")
            if hasattr(self, "_raid_slot_student_input"):
                self._raid_slot_student_input.clear()
            if hasattr(self, "_raid_slot_star_selector"):
                self._set_raid_star_condition_inputs({})
            self._set_raid_condition_inputs(getattr(self, "_raid_slot_skill_inputs", {}), {})
            self._set_raid_condition_inputs(getattr(self, "_raid_slot_equipment_inputs", {}), {})
            self._set_raid_condition_inputs(getattr(self, "_raid_slot_stat_inputs", {}), {})
            return
        index = max(0, min(getattr(self, "_raid_selected_deck_slot_index", 0), len(rows) - 1))
        self._raid_selected_deck_slot_index = index
        row = rows[index]
        slot_label = "S" if row.get("slot_type") == "striker" else "SP"
        student_id = str(row.get("student_id") or "")
        name = self._raid_student_label(student_id) if student_id in self._records_by_id else student_id or "-"
        self._raid_slot_detail_guard = True
        self._raid_slot_detail_title.setText(f"{slot_label}{row.get('slot_index')} 상세")
        self._raid_slot_detail_student.setText(name)
        self._raid_slot_student_input.setText(name if student_id else "")
        self._raid_slot_borrowed.setChecked(bool(row.get("borrowed")))
        equipment_slot_names = list(student_meta.equipment_slots(student_id) or ()) if student_id else []
        for offset, key in enumerate(("equip1", "equip2", "equip3")):
            label_widget = self._raid_slot_equipment_labels.get(key)
            if label_widget is None:
                continue
            if offset < len(equipment_slot_names) and equipment_slot_names[offset]:
                label_widget.setText(_equipment_series_label(str(equipment_slot_names[offset])))
            else:
                label_widget.setText(f"장비{offset + 1}")
        if "unique" in self._raid_slot_equipment_labels:
            self._raid_slot_equipment_labels["unique"].setText("애용품")
        self._set_raid_star_condition_inputs(row.get("star_conditions"))
        self._set_raid_condition_inputs(self._raid_slot_skill_inputs, row.get("skill_conditions"))
        self._set_raid_condition_inputs(self._raid_slot_equipment_inputs, row.get("equipment_conditions"))
        self._set_raid_condition_inputs(self._raid_slot_stat_inputs, row.get("stat_conditions"))
        self._raid_slot_notes.setPlainText(str(row.get("notes") or ""))
        self._raid_slot_detail_guard = False
    def _raid_deck_group_layouts(self, grid: QGridLayout, *, mode: str, compact: bool = False) -> dict[str, QHBoxLayout]:
        striker_count, support_count = slot_counts_for_mode(mode)
        groups: dict[str, QHBoxLayout] = {}
        for column, (slot_type, title, count) in enumerate((
            ("striker", "STRIKER", striker_count),
            ("support", "SPECIAL", support_count),
        )):
            frame = QFrame()
            frame.setObjectName("raidDeckGroup")
            frame.setSizePolicy(QSizePolicy.Fixed, QSizePolicy.Fixed)
            outer = QVBoxLayout(frame)
            margin_x = scale_px(6 if compact else 8, self._ui_scale)
            margin_y = scale_px(5 if compact else 7, self._ui_scale)
            outer.setContentsMargins(margin_x, margin_y, margin_x, margin_y)
            outer.setSpacing(scale_px(3 if compact else 4, self._ui_scale))
            label = QLabel(title)
            label.setObjectName("detailMiniSub")
            label.setAlignment(Qt.AlignLeft)
            outer.addWidget(label)
            row = QHBoxLayout()
            row.setContentsMargins(0, 0, 0, 0)
            row.setSpacing(scale_px(1 if compact else 2, self._ui_scale))
            outer.addLayout(row)
            grid.addWidget(frame, 0, column, Qt.AlignLeft | Qt.AlignTop)
            grid.setColumnStretch(column, 0)
            groups[slot_type] = row
        grid.setColumnStretch(2, 1)
        return groups
    def _fix_raid_deck_group_widths(self, grid: QGridLayout) -> None:
        for index in range(grid.count()):
            widget = grid.itemAt(index).widget()
            if isinstance(widget, QFrame) and widget.objectName() == "raidDeckGroup":
                widget.setFixedWidth(widget.sizeHint().width())
    def _update_selected_raid_slot_detail(self) -> None:
        if getattr(self, "_raid_slot_detail_guard", False):
            return
        rows = getattr(self, "_raid_deck_rows", [])
        if not rows:
            return
        index = max(0, min(getattr(self, "_raid_selected_deck_slot_index", 0), len(rows) - 1))
        rows[index]["borrowed"] = self._raid_slot_borrowed.isChecked()
        rows[index]["star_conditions"] = self._raid_star_conditions_from_inputs()
        rows[index]["skill_conditions"] = self._raid_condition_values_from_inputs(self._raid_slot_skill_inputs)
        rows[index]["equipment_conditions"] = self._raid_condition_values_from_inputs(self._raid_slot_equipment_inputs)
        rows[index]["stat_conditions"] = self._raid_condition_values_from_inputs(self._raid_slot_stat_inputs)
        rows[index]["notes"] = self._raid_slot_notes.toPlainText().strip()
        if not str(rows[index].get("student_id") or ""):
            rows[index]["first_order"] = 0
            rows[index]["star_conditions"] = {}
            rows[index]["skill_conditions"] = {}
            rows[index]["equipment_conditions"] = {}
            rows[index]["stat_conditions"] = {}
            self._sync_raid_deck_slot_icons()
            self._refresh_raid_validation()
            return
        self._sync_raid_deck_slot_icons()
        self._refresh_raid_validation()
    def _refresh_raid_deck_summary(self) -> None:
        if not hasattr(self, "_raid_deck_summary_grid"):
            return
        while self._raid_deck_summary_grid.count():
            item = self._raid_deck_summary_grid.takeAt(0)
            widget = item.widget()
            if widget is not None:
                widget.deleteLater()
        guide = self._collect_raid_guide_from_editor()
        group_layouts = self._raid_deck_group_layouts(self._raid_deck_summary_grid, mode=guide.mode, compact=True)
        for index, slot in enumerate(guide.deck):
            cell = QWidget()
            cell.setObjectName("planTransparent")
            layout = QVBoxLayout(cell)
            layout.setContentsMargins(0, 0, 0, 0)
            layout.setSpacing(scale_px(3, self._ui_scale))
            slot_width = scale_px(54, self._ui_scale)
            slot_height = max(scale_px(42, self._ui_scale), int(round(slot_width / self._student_card_asset.aspect_ratio)))
            icon = TacticalDeckSlot(
                card_asset=self._student_card_asset,
                ui_scale=self._ui_scale,
                preferred_width=slot_width,
                preferred_height=slot_height,
            )
            icon.setFixedSize(slot_width, slot_height)
            name = self._raid_student_label(slot.student_id) if slot.student_id in self._records_by_id else slot.student_id
            icon.setData(
                name=name,
                pixmap=self._raid_portrait_pixmap(slot.student_id, slot_width),
                badge_text=str(slot.first_order) if getattr(slot, "first_order", 0) else "",
                corner_badge_text="A" if getattr(slot, "is_borrowed", False) else "",
            )
            layout.addWidget(icon, 0, Qt.AlignCenter)
            group_layouts.get(slot.slot_type, group_layouts["striker"]).addWidget(cell)
        self._fix_raid_deck_group_widths(self._raid_deck_summary_grid)
    def _raid_guide_list_focus_badge(self, guide: RaidGuide) -> str:
        if guide.id in getattr(self, "_raid_new_guide_ids", set()):
            return "새 작성"
        return "수정 중"
    def _style_raid_guide_list_row(self, row: QWidget, *, active: bool, badge_text: str) -> None:
        title = row.findChild(QLabel, "raidGuideRowTitle")
        badge = row.findChild(QLabel, "raidGuideRowBadge")
        radius = scale_px(10, self._ui_scale)
        if active:
            row.setStyleSheet(
                f"""
                QFrame#raidGuideRow {{
                    background: {_mix_hex(ACCENT_SOFT, '#ffffff', 0.08)};
                    border: {scale_px(2, self._ui_scale)}px solid {ACCENT};
                    border-radius: {radius}px;
                }}
                QLabel#raidGuideRowTitle {{
                    color: {INK};
                    font-weight: 900;
                }}
                QLabel#raidGuideRowBadge {{
                    color: #ffffff;
                    background: {ACCENT_STRONG};
                    border-radius: {scale_px(8, self._ui_scale)}px;
                    padding: {scale_px(2, self._ui_scale)}px {scale_px(8, self._ui_scale)}px;
                    font-weight: 900;
                }}
                """
            )
            if badge is not None:
                badge.setText(badge_text)
                badge.show()
        else:
            row.setStyleSheet(
                f"""
                QFrame#raidGuideRow {{
                    background: transparent;
                    border: {scale_px(1, self._ui_scale)}px solid transparent;
                    border-radius: {radius}px;
                }}
                QFrame#raidGuideRow:hover {{
                    background: {_mix_hex(SURFACE_ALT, '#ffffff', 0.04)};
                    border-color: {_mix_hex(BORDER, '#ffffff', 0.16)};
                }}
                QLabel#raidGuideRowTitle {{
                    color: {INK};
                    font-weight: 700;
                }}
                QLabel#raidGuideRowBadge {{
                    color: transparent;
                    background: transparent;
                    border: none;
                }}
                """
            )
            if badge is not None:
                badge.clear()
                badge.hide()
        if title is not None:
            font = title.font()
            font.setBold(active)
            title.setFont(font)
    def _raid_guide_list_row_widget(self, guide: RaidGuide, display_title: str, *, active: bool) -> QWidget:
        row = QFrame()
        row.setObjectName("raidGuideRow")
        row.setProperty("guideId", guide.id)
        row.setCursor(Qt.PointingHandCursor)
        layout = QHBoxLayout(row)
        layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(7, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(7, self._ui_scale),
        )
        layout.setSpacing(scale_px(8, self._ui_scale))
        title = QLabel(display_title)
        title.setObjectName("raidGuideRowTitle")
        title.setWordWrap(False)
        layout.addWidget(title, 1)
        badge = QLabel("")
        badge.setObjectName("raidGuideRowBadge")
        badge.setAlignment(Qt.AlignCenter)
        layout.addWidget(badge, 0, Qt.AlignRight | Qt.AlignVCenter)
        self._style_raid_guide_list_row(row, active=active, badge_text=self._raid_guide_list_focus_badge(guide))
        return row
    def _sync_raid_guide_list_focus(self) -> None:
        if not hasattr(self, "_raid_guide_list"):
            return
        selected_id = self._selected_raid_guide_id
        guide_by_id = {guide.id: guide for guide in self._raid_guide_data.guides}
        for row_index in range(self._raid_guide_list.count()):
            item = self._raid_guide_list.item(row_index)
            guide_id = str(item.data(Qt.UserRole) or "")
            widget = self._raid_guide_list.itemWidget(item)
            guide = guide_by_id.get(guide_id)
            if widget is None or guide is None:
                continue
            self._style_raid_guide_list_row(
                widget,
                active=guide_id == selected_id,
                badge_text=self._raid_guide_list_focus_badge(guide),
            )
    def _refresh_raid_guide_list(self) -> None:
        if not hasattr(self, "_raid_guide_list"):
            return
        selected_id = self._selected_raid_guide_id
        self._raid_guide_list.blockSignals(True)
        self._raid_guide_list.clear()
        query = self._raid_filter_text.text().strip().casefold() if hasattr(self, "_raid_filter_text") else ""
        mode_filter = self._raid_filter_mode.currentData() if hasattr(self, "_raid_filter_mode") else ""
        selected_row = -1
        for guide in self._raid_guide_data.guides:
            display_title = self._raid_guide_display_title(guide)
            haystack = " ".join([display_title, guide.boss, guide.difficulty, guide.terrain]).casefold()
            if query and query not in haystack:
                continue
            if mode_filter and guide.mode != mode_filter:
                continue
            item = QListWidgetItem("")
            item.setToolTip(display_title)
            item.setData(Qt.UserRole, guide.id)
            item.setSizeHint(QSize(0, scale_px(46, self._ui_scale)))
            self._raid_guide_list.addItem(item)
            self._raid_guide_list.setItemWidget(
                item,
                self._raid_guide_list_row_widget(guide, display_title, active=guide.id == selected_id),
            )
            if guide.id == selected_id:
                selected_row = self._raid_guide_list.count() - 1
        self._raid_guide_list.blockSignals(False)
        if selected_row >= 0:
            self._raid_guide_list.setCurrentRow(selected_row)
        elif self._raid_guide_list.count():
            self._raid_guide_list.setCurrentRow(0)
        self._sync_raid_guide_list_focus()
    def _on_raid_guide_selected(self, current: QListWidgetItem | None, _previous: QListWidgetItem | None) -> None:
        if self._raid_guide_editor_guard or current is None:
            return
        self._selected_raid_guide_id = str(current.data(Qt.UserRole) or "")
        self._load_selected_raid_guide()
        self._sync_raid_guide_list_focus()
    def _load_selected_raid_guide(self) -> None:
        guide = self._current_raid_guide()
        if guide is None or not hasattr(self, "_raid_title_input"):
            if guide is None and hasattr(self, "_raid_title_input"):
                self._raid_guide_editor_guard = True
                empty_guide = new_raid_guide()
                self._raid_title_input.clear()
                self._set_raid_boss_value("")
                self._set_raid_difficulty_value("")
                self._raid_time_limit_input.setValue(int(empty_guide.time_limit_seconds or 0))
                self._raid_notes_input.clear()
                self._rebuild_raid_deck_editor(empty_guide)
                self._set_raid_timeline_steps([])
                self._raid_guide_editor_guard = False
                self._update_raid_step_state()
                self._refresh_raid_deck_summary()
                self._refresh_raid_editor_source_state()
                self._refresh_raid_validation()
            return
        guide = sanitize_guide(guide)
        self._raid_guide_editor_guard = True
        self._raid_title_input.setText(guide.title)
        self._raid_mode_input.setCurrentData(guide.mode)
        self._set_raid_boss_value(guide.boss)
        self._set_raid_difficulty_value(guide.difficulty)
        self._raid_terrain_input.setCurrentData(guide.terrain)
        self._raid_time_limit_input.setValue(int(guide.time_limit_seconds or 0))
        self._raid_notes_input.setPlainText(guide.notes)
        self._rebuild_raid_deck_editor(guide)
        self._set_raid_timeline_steps(guide.timeline)
        self._raid_guide_editor_guard = False
        self._update_raid_step_state()
        self._refresh_raid_deck_summary()
        self._refresh_raid_editor_source_state()
        self._refresh_raid_validation()
    def _rebuild_raid_deck_editor(self, guide: RaidGuide | None = None) -> None:
        guide = sanitize_guide(guide or self._collect_raid_guide_from_editor())
        if hasattr(self, "_raid_deck_preview_grid"):
            while self._raid_deck_preview_grid.count():
                item = self._raid_deck_preview_grid.takeAt(0)
                widget = item.widget()
                if widget is not None:
                    widget.deleteLater()
        self._raid_deck_rows = []
        self._raid_deck_preview_icons: list[TacticalDeckSlot] = []
        group_layouts = self._raid_deck_group_layouts(self._raid_deck_preview_grid, mode=guide.mode, compact=False)
        for index, slot in enumerate(guide.deck):
            slot_label = "S" if slot.slot_type == "striker" else "SP"
            if len(guide.deck) > 6:
                slot_width = min(self._thumb_width, scale_px(104, self._ui_scale))
                slot_height = max(scale_px(78, self._ui_scale), int(round(slot_width / self._student_card_asset.aspect_ratio)))
            else:
                slot_width = min(self._thumb_width, scale_px(220, self._ui_scale))
                slot_height = max(scale_px(120, self._ui_scale), int(round(slot_width / self._student_card_asset.aspect_ratio)))

            preview_cell = QWidget()
            preview_cell.setObjectName("planTransparent")
            preview_layout = QVBoxLayout(preview_cell)
            preview_layout.setContentsMargins(0, 0, 0, 0)
            preview_layout.setSpacing(scale_px(3, self._ui_scale))
            preview_icon = TacticalDeckSlot(
                card_asset=self._student_card_asset,
                ui_scale=self._ui_scale,
                preferred_width=slot_width,
                preferred_height=slot_height,
            )
            preview_icon.setFixedSize(slot_width, slot_height)
            preview_label = QLabel(f"{slot_label}{slot.slot_index}")
            preview_label.setObjectName("detailSub")
            preview_label.setAlignment(Qt.AlignCenter)
            preview_layout.addWidget(preview_icon, 0, Qt.AlignCenter)
            preview_layout.addWidget(preview_label)
            group_layouts.get(slot.slot_type, group_layouts["striker"]).addWidget(preview_cell)
            self._raid_deck_preview_icons.append(preview_icon)
            preview_icon.clicked.connect(lambda slot_index=index: self._on_raid_deck_slot_clicked(slot_index))
            self._raid_deck_rows.append(
                {
                    "slot_type": slot.slot_type,
                    "slot_index": slot.slot_index,
                    "student_id": slot.student_id,
                    "alias": slot.alias,
                    "borrowed": bool(slot.is_borrowed),
                    "first_order": int(getattr(slot, "first_order", 0) or 0),
                    "star_conditions": {
                        key: value
                        for key, value in dict(getattr(slot, "star_conditions", {}) or {}).items()
                        if key != "weapon_level"
                    },
                    "skill_conditions": dict(getattr(slot, "skill_conditions", {}) or self._default_raid_skill_conditions()),
                    "equipment_conditions": dict(getattr(slot, "equipment_conditions", {}) or {}),
                    "stat_conditions": dict(getattr(slot, "stat_conditions", {}) or {}),
                    "notes": slot.notes,
                }
            )
        self._fix_raid_deck_group_widths(self._raid_deck_preview_grid)
        self._raid_selected_deck_slot_index = min(getattr(self, "_raid_selected_deck_slot_index", 0), max(0, len(self._raid_deck_rows) - 1))
        self._sync_raid_deck_slot_icons()
        self._sync_raid_template_from_slots()
        self._refresh_selected_raid_slot_detail()
        self._update_raid_step_state()
    def _set_raid_timeline_steps(self, steps: list[TimelineStep]) -> None:
        self._raid_guide_editor_guard = True
        self._raid_timeline_table.setRowCount(0)
        for step in steps:
            self._append_raid_timeline_step(step)
        self._refresh_raid_timeline_row_numbers()
        self._raid_guide_editor_guard = False
    def _table_text(self, row: int, column: int) -> str:
        item = self._raid_timeline_table.item(row, column)
        return item.text().strip() if item is not None else ""
    def _refresh_raid_timeline_row_numbers(self) -> None:
        if not hasattr(self, "_raid_timeline_table"):
            return
        for row in range(self._raid_timeline_table.rowCount()):
            self._raid_timeline_table.setVerticalHeaderItem(row, QTableWidgetItem(str(row + 1)))
    def _set_table_text(self, row: int, column: int, text: object) -> None:
        item = QTableWidgetItem(str(text or ""))
        if column == 0:
            item.setToolTip("예: 3:40.000, 03:40:000, 3코, 3.5코. 비우면 이전 스킬 후 즉시 사용")
        elif column == 1:
            item.setToolTip("예: 아코, 아코 EX")
        elif column == 2:
            item.setToolTip("예: 드히나. 비우면 대상 지정 없음")
        elif column == 4:
            item.setToolTip("나중에 커스텀 이미지나 게임 캡처를 연결할 자리입니다.")
        self._raid_timeline_table.setItem(row, column, item)
    def _normalize_raid_timing_text(self, text: str) -> str:
        raw = str(text or "").strip()
        match = re.match(r"^(\d{1,2}):(\d{2}):(\d{1,3})$", raw)
        if match:
            return f"{int(match.group(1))}:{match.group(2)}.{match.group(3).ljust(3, '0')[:3]}"
        return raw
    def _raid_timeline_skill_text(self, step: TimelineStep) -> str:
        actor = self._raid_student_label(step.actor_student_id) if step.actor_student_id in self._records_by_id else step.actor_student_id
        action = str(step.action_type or "EX").strip()
        actor_text = str(actor or "").strip()
        if actor_text and action and action != "EX":
            actor_text = f"{actor_text} {action}"
        return actor_text
    def _raid_timeline_target_text(self, step: TimelineStep) -> str:
        return (
            self._raid_student_label(step.target_student_id)
            if step.target_student_id in self._records_by_id
            else str(step.target_student_id or "")
        )
    def _raid_timeline_memo_text(self, step: TimelineStep) -> str:
        parts = [
            step.condition,
            step.damage_check,
            step.phase,
            step.note,
        ]
        return " / ".join(str(part).strip() for part in parts if str(part or "").strip())
    def _split_raid_skill_target_text(self, text: str) -> tuple[str, str]:
        raw = str(text or "").strip()
        for delimiter in ("->", "=>", "→", ">"):
            if delimiter in raw:
                actor, target = raw.split(delimiter, 1)
                return actor.strip(), target.strip()
        return raw, ""
    def _parse_raid_timeline_skill_text(self, text: str) -> tuple[str, str, str]:
        actor_text, target_text = self._split_raid_skill_target_text(text)
        action_type = "EX"
        actor_id = self._raid_student_id_for_text(actor_text)
        if actor_text and actor_id == actor_text:
            pieces = actor_text.rsplit(None, 1)
            if len(pieces) == 2:
                possible_actor, possible_action = pieces
                possible_actor_id = self._raid_student_id_for_text(possible_actor)
                if possible_actor_id != possible_actor or possible_actor in self._records_by_id:
                    actor_id = possible_actor_id
                    action_type = possible_action.strip() or "EX"
        target_id = self._raid_student_id_for_text(target_text)
        return actor_id, action_type, target_id
    def _append_raid_timeline_step(self, step: TimelineStep | None = None) -> None:
        row = self._raid_timeline_table.rowCount()
        self._raid_timeline_table.insertRow(row)
        step = step or TimelineStep(order=row + 1)
        values = [
            step.cue_text,
            self._raid_timeline_skill_text(step),
            self._raid_timeline_target_text(step),
            self._raid_timeline_memo_text(step),
            step.card_hint,
        ]
        for column, value in enumerate(values):
            self._set_table_text(row, column, value)
        self._refresh_raid_timeline_row_numbers()
    def _timeline_steps_from_table(self) -> list[TimelineStep]:
        steps: list[TimelineStep] = []
        for row in range(self._raid_timeline_table.rowCount()):
            step = TimelineStep(order=row + 1)
            timing_text = self._normalize_raid_timing_text(self._table_text(row, 0))
            if timing_text:
                update_step_cue(step, timing_text)
            else:
                step.cue_kind = "trigger"
                step.cue_text = ""
            actor_id, action_type, embedded_target_id = self._parse_raid_timeline_skill_text(self._table_text(row, 1))
            target_text = self._table_text(row, 2)
            step.actor_student_id = actor_id
            step.action_type = action_type
            step.target_student_id = self._raid_student_id_for_text(target_text) if target_text else embedded_target_id
            step.note = self._table_text(row, 3)
            step.card_hint = self._table_text(row, 4)
            if step.cue_text and not step.actor_student_id and not step.target_student_id:
                step.action_type = "marker"
                step.cue_kind = "note" if step.cue_kind == "trigger" else step.cue_kind
            steps.append(step)
        return steps
    def _collect_raid_guide_from_editor(self) -> RaidGuide:
        current = self._current_raid_guide()
        guide = current or new_raid_guide()
        mode = self._raid_mode_input.currentData() if hasattr(self, "_raid_mode_input") else guide.mode
        boss = self._raid_current_boss() if hasattr(self, "_raid_boss_input") else guide.boss
        difficulty = self._raid_current_difficulty() if hasattr(self, "_raid_difficulty_input") else guide.difficulty
        terrain = (
            str(self._raid_terrain_input.currentData() or "").strip()
            if hasattr(self, "_raid_terrain_input")
            else guide.terrain
        )
        raw_title = self._raid_title_input.text().strip() if hasattr(self, "_raid_title_input") else guide.title
        previous_generated_title = self._raid_generated_title(terrain=guide.terrain, boss=guide.boss, difficulty=guide.difficulty)
        if self._raid_should_generate_title(raw_title, previous_generated_title):
            generated_title = self._raid_generated_title(terrain=terrain, boss=boss, difficulty=difficulty)
            title = self._raid_unique_generated_title(generated_title, guide.id)
        else:
            title = raw_title
        deck: list[GuideDeckSlot] = []
        for row in getattr(self, "_raid_deck_rows", []):
            star_conditions = {
                key: value
                for key, value in dict(row.get("star_conditions") or {}).items()
                if key != "weapon_level"
            }
            deck.append(
                GuideDeckSlot(
                    slot_type=str(row["slot_type"]),
                    slot_index=int(row["slot_index"]),
                    student_id=str(row.get("student_id") or ""),
                    alias=str(row.get("alias") or ""),
                    is_borrowed=bool(row.get("borrowed")),
                    first_order=int(row.get("first_order") or 0),
                    star_conditions=star_conditions,
                    skill_conditions=dict(row.get("skill_conditions") or {}),
                    equipment_conditions=dict(row.get("equipment_conditions") or {}),
                    stat_conditions=dict(row.get("stat_conditions") or {}),
                    notes=str(row.get("notes") or ""),
                )
            )
        return sanitize_guide(
            RaidGuide(
                id=guide.id,
                title=title,
                mode=str(mode or guide.mode),
                boss=boss,
                difficulty=difficulty,
                terrain=terrain,
                time_limit_seconds=self._raid_time_limit_input.value() if hasattr(self, "_raid_time_limit_input") else guide.time_limit_seconds,
                notes=self._raid_notes_input.toPlainText().strip() if hasattr(self, "_raid_notes_input") else guide.notes,
                deck=deck or default_deck_for_mode(str(mode or guide.mode)),
                timeline=self._timeline_steps_from_table() if hasattr(self, "_raid_timeline_table") else guide.timeline,
            )
        )
    def _on_raid_mode_changed(self) -> None:
        if self._raid_guide_editor_guard:
            return
        guide = self._collect_raid_guide_from_editor()
        guide.deck = default_deck_for_mode(guide.mode)
        self._rebuild_raid_deck_editor(guide)
        self._set_raid_editor_step(0)
        self._refresh_raid_validation()
    def _on_raid_timeline_item_changed(self, item: QTableWidgetItem) -> None:
        if self._raid_guide_editor_guard:
            return
        if item.column() == 0:
            normalized = self._normalize_raid_timing_text(item.text())
            if normalized != item.text().strip():
                self._raid_guide_editor_guard = True
                self._set_table_text(item.row(), 0, normalized)
                self._raid_guide_editor_guard = False
        self._refresh_raid_validation()
    def _add_raid_timeline_row(self) -> None:
        self._append_raid_timeline_step(TimelineStep(order=self._raid_timeline_table.rowCount() + 1, action_type="EX"))
        self._raid_timeline_table.setCurrentCell(self._raid_timeline_table.rowCount() - 1, 0)
    def _duplicate_raid_timeline_row(self) -> None:
        row = self._raid_timeline_table.currentRow()
        if row < 0:
            return
        step = TimelineStep(order=row + 2)
        update_step_cue(step, self._normalize_raid_timing_text(self._table_text(row, 0)))
        step.actor_student_id, step.action_type, embedded_target_id = self._parse_raid_timeline_skill_text(self._table_text(row, 1))
        target_text = self._table_text(row, 2)
        step.target_student_id = self._raid_student_id_for_text(target_text) if target_text else embedded_target_id
        step.note = self._table_text(row, 3)
        step.card_hint = self._table_text(row, 4)
        self._raid_timeline_table.insertRow(row + 1)
        self._raid_guide_editor_guard = True
        for column, value in enumerate([
            step.cue_text,
            self._raid_timeline_skill_text(step),
            self._raid_timeline_target_text(step),
            step.note,
            step.card_hint,
        ]):
            self._set_table_text(row + 1, column, value)
        self._refresh_raid_timeline_row_numbers()
        self._raid_guide_editor_guard = False
    def _delete_raid_timeline_row(self) -> None:
        row = self._raid_timeline_table.currentRow()
        if row >= 0:
            self._raid_timeline_table.removeRow(row)
            self._refresh_raid_timeline_row_numbers()
            self._refresh_raid_validation()
    def _move_raid_timeline_row(self, direction: int) -> None:
        row = self._raid_timeline_table.currentRow()
        target = row + direction
        if row < 0 or target < 0 or target >= self._raid_timeline_table.rowCount():
            return
        rows = self._timeline_steps_from_table()
        rows[row], rows[target] = rows[target], rows[row]
        self._set_raid_timeline_steps(rows)
        self._raid_timeline_table.setCurrentCell(target, 0)
        self._refresh_raid_timeline_row_numbers()
    def _import_raid_timeline_text(self) -> None:
        text = self._raid_paste_input.toPlainText()
        if not text.strip():
            return
        steps = parse_timeline_text(text, start_order=self._raid_timeline_table.rowCount() + 1)
        for step in steps:
            resolved = self._raid_student_id_for_text(step.actor_student_id)
            step.actor_student_id = resolved
            self._append_raid_timeline_step(step)
        self._raid_paste_input.clear()
        self._refresh_raid_validation()
    def _share_current_raid_guide(self) -> None:
        guide = self._collect_raid_guide_from_editor()
        try:
            token = encode_raid_guide_share(guide)
        except Exception as exc:
            QMessageBox.warning(self, "BA Planner", f"공략 공유 문자열을 만들지 못했습니다.\n\n{exc}")
            return
        QApplication.clipboard().setText(token)
        if hasattr(self, "_raid_status"):
            self._raid_status.setStyleSheet("color: #2f80ed; font-weight: 900;")
            self._raid_status.setText("공략 공유 문자열을 클립보드에 복사했습니다. 이미지는 별도로 공유해 주세요.")
            self._raid_status.setToolTip(token)
    def _import_raid_guide_share(self) -> None:
        clipboard_text = QApplication.clipboard().text().strip()
        initial_text = clipboard_text if "BAPRG1:" in clipboard_text else ""
        text, ok = QInputDialog.getMultiLineText(
            self,
            "공략 공유 문자열 가져오기",
            "BAPRG1: 공유 문자열을 붙여넣으세요.\n이미지가 있는 공략은 이미지를 별도로 받은 뒤 함께 보관해 주세요.",
            initial_text,
        )
        if not ok:
            return
        try:
            guide = decode_raid_guide_share(text)
        except ValueError as exc:
            QMessageBox.warning(self, "BA Planner", f"공략 공유 문자열을 읽지 못했습니다.\n\n{exc}")
            return
        self._raid_guide_data.guides.append(guide)
        self._selected_raid_guide_id = guide.id
        self._raid_new_guide_ids.add(guide.id)
        self._save_raid_guide_data()
        self._refresh_raid_guide_list()
        self._load_selected_raid_guide()
        if hasattr(self, "_raid_status"):
            self._raid_status.setStyleSheet("color: #2f80ed; font-weight: 900;")
            self._raid_status.setText("공유 문자열에서 공략을 가져왔습니다. 추가 이미지는 별도로 연결해 주세요.")
    def _new_raid_guide(self) -> None:
        guide = new_raid_guide()
        self._raid_guide_data.guides.append(guide)
        self._selected_raid_guide_id = guide.id
        self._raid_new_guide_ids.add(guide.id)
        self._save_raid_guide_data()
        self._refresh_raid_guide_list()
        self._load_selected_raid_guide()
    def _edit_selected_raid_guide(self) -> None:
        current = self._current_raid_guide()
        if current is None:
            return
        self._selected_raid_guide_id = current.id
        self._load_selected_raid_guide()
        self._set_raid_editor_step(0)
    def _duplicate_selected_raid_guide(self) -> None:
        current = self._collect_raid_guide_from_editor()
        cloned = clone_guide(current)
        self._raid_guide_data.guides.append(cloned)
        self._selected_raid_guide_id = cloned.id
        self._raid_new_guide_ids.add(cloned.id)
        self._save_raid_guide_data()
        self._refresh_raid_guide_list()
        self._load_selected_raid_guide()
    def _delete_selected_raid_guide(self) -> None:
        current = self._current_raid_guide()
        if current is None:
            return
        self._raid_guide_data.guides = [guide for guide in self._raid_guide_data.guides if guide.id != current.id]
        self._raid_new_guide_ids.discard(current.id)
        self._selected_raid_guide_id = self._raid_guide_data.guides[0].id if self._raid_guide_data.guides else None
        self._save_raid_guide_data()
        self._refresh_raid_guide_list()
        self._load_selected_raid_guide()
    def _save_current_raid_guide(self) -> None:
        guide = self._collect_raid_guide_from_editor()
        for index, existing in enumerate(self._raid_guide_data.guides):
            if existing.id == guide.id:
                self._raid_guide_data.guides[index] = guide
                break
        else:
            self._raid_guide_data.guides.append(guide)
        self._selected_raid_guide_id = guide.id
        self._raid_new_guide_ids.discard(guide.id)
        self._save_raid_guide_data()
        if hasattr(self, "_raid_title_input"):
            self._raid_guide_editor_guard = True
            self._raid_title_input.setText(guide.title)
            self._raid_guide_editor_guard = False
        self._refresh_raid_guide_list()
        self._refresh_raid_editor_source_state()
        self._show_raid_deck_saved_feedback(guide)
        self._refresh_raid_validation(saved=True)
    def _show_raid_deck_saved_feedback(self, guide: RaidGuide) -> None:
        if not hasattr(self, "_raid_deck_status"):
            return
        filled = sum(1 for slot in guide.deck if slot.student_id)
        total = len(guide.deck)
        self._raid_deck_status.setStyleSheet("color: #2f80ed; font-weight: 900;")
        self._raid_deck_status.setText(f"저장 완료 · 덱 슬롯 {filled}/{total}")
    def _refresh_raid_validation(self, *, saved: bool = False) -> None:
        if not hasattr(self, "_raid_status"):
            return
        guide = self._collect_raid_guide_from_editor()
        warnings = validate_guide(guide, known_student_ids=set(student_meta.all_ids()))
        prefix = "저장 완료. " if saved else ""
        if warnings:
            visible = warnings[:3]
            suffix = f" 외 {len(warnings) - 3}개" if len(warnings) > 3 else ""
            self._raid_status.setStyleSheet("color: #ffb84d; font-weight: 800;")
            self._raid_status.setText(prefix + " / ".join(visible) + suffix)
            self._raid_status.setToolTip("\n".join(warnings))
        else:
            striker_count, support_count = slot_counts_for_mode(guide.mode)
            self._raid_status.setStyleSheet("")
            self._raid_status.setText(
                prefix + f"{RAID_GUIDE_MODES.get(guide.mode, guide.mode)} · 덱 {striker_count}+{support_count} · 행 {len(guide.timeline)}개"
            )
            self._raid_status.setToolTip("")
