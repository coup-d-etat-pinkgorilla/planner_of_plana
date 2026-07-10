"""TacticalTabComponent implementation extracted from the viewer façade."""

from __future__ import annotations

from gui import viewer_shared as _viewer_shared

globals().update({name: value for name, value in vars(_viewer_shared).items() if not name.startswith("__")})


class TacticalTabComponent:
    def _build_tactical_tab(self, root: QWidget) -> None:
        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, scale_px(12, self._ui_scale))
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
        title = QLabel("전술대항전")
        title.setObjectName("title")
        subtitle = QLabel("전술대항전 전적, 상대 방어덱, 공격 족보를 한 곳에서 기록하고 찾아봅니다.")
        subtitle.setObjectName("count")
        header_layout.addWidget(title)
        header_layout.addWidget(subtitle)
        layout.addWidget(header)

        splitter = QSplitter(Qt.Horizontal)
        splitter.setObjectName("sectionSplitter")
        splitter.setChildrenCollapsible(False)
        layout.addWidget(splitter, 1)

        input_shell = QFrame()
        input_shell.setObjectName("planSectionPanel")
        input_shell_layout = QVBoxLayout(input_shell)
        input_shell_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        input_shell_layout.setSpacing(0)

        input_panel = QWidget()
        input_panel.setObjectName("planTransparent")
        input_scroll = QScrollArea()
        input_scroll.setObjectName("sectionScrollArea")
        input_scroll.setWidgetResizable(True)
        input_scroll.setFrameShape(QFrame.NoFrame)
        input_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        input_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        _install_planner_scroll_handle(input_scroll, ui_scale=self._ui_scale)
        input_scroll.setWidget(input_panel)
        input_shell_layout.addWidget(input_scroll, 1)
        input_layout = QVBoxLayout(input_panel)
        input_layout.setContentsMargins(
            scale_px(4, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(4, self._ui_scale),
        )
        input_layout.setSpacing(scale_px(10, self._ui_scale))

        match_title = QLabel("오늘 전적 입력")
        match_title.setObjectName("sectionTitle")
        input_layout.addWidget(match_title)
        date_row = QHBoxLayout()
        date_row.setContentsMargins(0, 0, 0, 0)
        self._tactical_date = QLineEdit(date.today().isoformat())
        self._tactical_season = QLineEdit(self._tactical_data.season or "")
        self._tactical_season.setPlaceholderText("시즌")
        self._tactical_season.editingFinished.connect(self._save_tactical_season)
        date_row.addWidget(QLabel("날짜"))
        date_row.addWidget(self._tactical_date, 1)
        date_row.addWidget(QLabel("시즌"))
        date_row.addWidget(self._tactical_season, 1)
        input_layout.addLayout(date_row)

        self._tactical_match_panels: list[dict] = []
        panel_widget, panel = self._build_tactical_match_input_panel(1)
        self._tactical_match_panels.append(panel)
        input_layout.addWidget(panel_widget)

        abbrev_panel = self._build_tactical_abbreviation_panel()
        input_layout.addWidget(abbrev_panel)

        self._tactical_status = QLabel("")
        self._tactical_status.setObjectName("filterSummary")
        self._tactical_status.setWordWrap(True)
        self._tactical_status.setMaximumHeight(scale_px(48, self._ui_scale))
        self._tactical_status.hide()
        input_layout.addStretch(1)
        splitter.addWidget(input_shell)

        history_panel = QFrame()
        history_panel.setObjectName("planSectionPanel")
        history_layout = QVBoxLayout(history_panel)
        history_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        history_layout.setSpacing(scale_px(10, self._ui_scale))
        history_header = QHBoxLayout()
        history_title = QLabel("전적 기록")
        history_title.setObjectName("sectionTitle")
        self._tactical_match_summary = QLabel("")
        self._tactical_match_summary.setObjectName("filterSummary")
        history_header.addWidget(history_title)
        history_header.addWidget(self._tactical_match_summary, 1, Qt.AlignRight)
        history_layout.addLayout(history_header)
        self._tactical_match_search = QLineEdit()
        self._tactical_match_search.setPlaceholderText("상대 이름, 학생, 메모 검색")
        self._tactical_match_search.textChanged.connect(lambda *_: self._reset_tactical_match_list())
        history_layout.addWidget(self._tactical_match_search)
        self._tactical_match_list = RoundedListWidget(ui_scale=self._ui_scale)
        _install_planner_scroll_handle(self._tactical_match_list, ui_scale=self._ui_scale)
        self._tactical_match_list.currentItemChanged.connect(self._on_tactical_match_selected)
        history_layout.addWidget(self._tactical_match_list, 1)
        self._tactical_match_load_more_button = QPushButton("더 보기")
        self._tactical_match_load_more_button.clicked.connect(self._load_more_tactical_matches)
        history_layout.addWidget(self._tactical_match_load_more_button)
        match_action_row = QHBoxLayout()
        match_action_row.setContentsMargins(0, 0, 0, 0)
        self._tactical_match_copy_attack_button = QPushButton("ATK Copy")
        self._tactical_match_copy_attack_button.clicked.connect(self._copy_selected_tactical_match_attack)
        self._tactical_match_copy_defense_button = QPushButton("DEF Copy")
        self._tactical_match_copy_defense_button.clicked.connect(self._copy_selected_tactical_match_defense)
        self._tactical_match_edit_button = QPushButton("수정")
        self._tactical_match_edit_button.clicked.connect(self._edit_selected_tactical_match)
        self._tactical_match_batch_names_button = QPushButton("이름 일괄")
        self._tactical_match_batch_names_button.clicked.connect(self._edit_tactical_opponents_batch)
        self._tactical_match_delete_button = QPushButton("[삭제]")
        self._tactical_match_delete_button.clicked.connect(self._delete_selected_tactical_match)
        self._tactical_match_import_button = QPushButton("Excel Import")
        self._tactical_match_import_button.clicked.connect(self._import_tactical_spreadsheet)
        import_template_path = self._ensure_tactical_import_template()
        self._tactical_match_import_button.setToolTip(
            f"템플릿: {import_template_path}\n설명서: {tactical_import_readme_path(import_template_path)}"
        )
        match_action_row.addStretch(1)
        match_action_row.addWidget(self._tactical_match_import_button)
        match_action_row.addWidget(self._tactical_match_copy_attack_button)
        match_action_row.addWidget(self._tactical_match_copy_defense_button)
        match_action_row.addWidget(self._tactical_match_batch_names_button)
        match_action_row.addWidget(self._tactical_match_edit_button)
        match_action_row.addWidget(self._tactical_match_delete_button)
        history_layout.addLayout(match_action_row)
        splitter.addWidget(history_panel)

        insight_panel = QFrame()
        insight_panel.setObjectName("planSectionPanel")
        insight_layout = QVBoxLayout(insight_panel)
        insight_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        insight_layout.setSpacing(scale_px(10, self._ui_scale))
        tactical_mode_buttons = QHBoxLayout()
        tactical_mode_buttons.setContentsMargins(0, 0, 0, 0)
        tactical_mode_buttons.setSpacing(scale_px(8, self._ui_scale))
        tactical_insight_buttons: dict[int, QPushButton] = {}
        tactical_insight_stack = QStackedWidget()
        tactical_insight_stack.setObjectName("sectionTransparentStack")

        def sync_tactical_insight_buttons(index: int) -> None:
            for button_index, button in tactical_insight_buttons.items():
                button.setChecked(button_index == index)

        for index, label in enumerate(("상대", "족보")):
            button = QPushButton(label)
            button.setObjectName("inventoryModeButton")
            button.setCheckable(True)
            button.clicked.connect(lambda _checked=False, value=index: tactical_insight_stack.setCurrentIndex(value))
            tactical_mode_buttons.addWidget(button, 0)
            tactical_insight_buttons[index] = button
        tactical_mode_buttons.addStretch(1)
        tactical_insight_stack.currentChanged.connect(sync_tactical_insight_buttons)
        insight_layout.addLayout(tactical_mode_buttons)
        insight_layout.addWidget(tactical_insight_stack, 1)

        opponent_tab = QWidget()
        opponent_tab.setObjectName("planTransparent")
        opponent_tab_layout = QVBoxLayout(opponent_tab)
        opponent_tab_layout.setContentsMargins(0, 0, 0, 0)
        opponent_tab_layout.setSpacing(0)
        opponent_container = QFrame()
        opponent_container.setObjectName("planBand")
        opponent_layout = QVBoxLayout(opponent_container)
        opponent_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        opponent_layout.setSpacing(scale_px(10, self._ui_scale))
        opponent_search_row = QHBoxLayout()
        self._tactical_opponent_search = QLineEdit()
        self._tactical_opponent_search.setPlaceholderText("상대 이름 검색")
        self._tactical_opponent_search.returnPressed.connect(self._refresh_tactical_opponent_report)
        opponent_search_button = QPushButton("검색")
        opponent_search_button.clicked.connect(self._refresh_tactical_opponent_report)
        opponent_search_row.addWidget(self._tactical_opponent_search, 1)
        opponent_search_row.addWidget(opponent_search_button)
        opponent_layout.addLayout(opponent_search_row)
        self._tactical_opponent_summary = QLabel("")
        self._tactical_opponent_summary.setObjectName("detailSub")
        self._tactical_opponent_summary.setWordWrap(True)
        opponent_layout.addWidget(self._tactical_opponent_summary)
        self._tactical_opponent_top_list = RoundedListWidget(ui_scale=self._ui_scale)
        _install_planner_scroll_handle(self._tactical_opponent_top_list, ui_scale=self._ui_scale)
        opponent_layout.addWidget(self._tactical_opponent_top_list, 1)
        opponent_tab_layout.addWidget(opponent_container, 1)
        tactical_insight_stack.addWidget(opponent_tab)

        jokbo_tab = QWidget()
        jokbo_tab.setObjectName("planTransparent")
        jokbo_tab_layout = QVBoxLayout(jokbo_tab)
        jokbo_tab_layout.setContentsMargins(0, 0, 0, 0)
        jokbo_tab_layout.setSpacing(0)
        jokbo_container = QFrame()
        jokbo_container.setObjectName("planBand")
        jokbo_layout = QVBoxLayout(jokbo_container)
        jokbo_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        jokbo_layout.setSpacing(scale_px(10, self._ui_scale))
        search_group, self._tactical_jokbo_search_inputs = self._build_tactical_deck_editor("방어덱 검색")
        jokbo_layout.addWidget(search_group)
        search_buttons = QHBoxLayout()
        search_jokbo_button = QPushButton("족보 검색")
        search_jokbo_button.clicked.connect(self._refresh_tactical_jokbo_results)
        copy_search_button = QPushButton("전적 방어덱 복사")
        copy_search_button.clicked.connect(self._copy_selected_tactical_defense_to_search)
        search_buttons.addWidget(search_jokbo_button)
        search_buttons.addWidget(copy_search_button)
        jokbo_layout.addLayout(search_buttons)
        self._tactical_jokbo_results = RoundedListWidget(ui_scale=self._ui_scale)
        _install_planner_scroll_handle(self._tactical_jokbo_results, ui_scale=self._ui_scale)
        jokbo_layout.addWidget(self._tactical_jokbo_results, 1)
        jokbo_action_row = QHBoxLayout()
        jokbo_action_row.setContentsMargins(0, 0, 0, 0)
        self._tactical_jokbo_copy_defense_button = QPushButton("DEF Copy")
        self._tactical_jokbo_copy_defense_button.clicked.connect(self._copy_selected_tactical_jokbo_defense)
        self._tactical_jokbo_copy_attack_button = QPushButton("ATK Copy")
        self._tactical_jokbo_copy_attack_button.clicked.connect(self._copy_selected_tactical_jokbo_attack)
        jokbo_action_row.addStretch(1)
        jokbo_action_row.addWidget(self._tactical_jokbo_copy_attack_button)
        jokbo_action_row.addWidget(self._tactical_jokbo_copy_defense_button)
        jokbo_layout.addLayout(jokbo_action_row)
        jokbo_tab_layout.addWidget(jokbo_container, 1)
        tactical_insight_stack.addWidget(jokbo_tab)
        tactical_insight_stack.setCurrentIndex(0)
        sync_tactical_insight_buttons(0)
        splitter.addWidget(insight_panel)
        splitter.setSizes([scale_px(420, self._ui_scale), scale_px(520, self._ui_scale), scale_px(470, self._ui_scale)])
    def _build_tactical_match_input_panel(self, index: int) -> tuple[QFrame, dict]:
        panel_widget = QFrame()
        panel_widget.setObjectName("planBand")
        layout = QVBoxLayout(panel_widget)
        layout.setContentsMargins(scale_px(10, self._ui_scale), scale_px(10, self._ui_scale), scale_px(10, self._ui_scale), scale_px(10, self._ui_scale))
        layout.setSpacing(scale_px(8, self._ui_scale))

        header = QHBoxLayout()
        title = QLabel("대전 기록")
        title.setObjectName("sectionTitle")
        opponent = QLineEdit()
        opponent.setPlaceholderText("상대 이름")
        opponent.setMinimumWidth(scale_px(48, self._ui_scale))
        opponent.setSizePolicy(QSizePolicy.Ignored, QSizePolicy.Fixed)
        win_button = QPushButton("승")
        loss_button = QPushButton("패")
        win_button.setCheckable(True)
        loss_button.setCheckable(True)
        save_button = QPushButton("전적 추가")
        clear_button = QPushButton("새 입력")
        button_spacing = scale_px(6, self._ui_scale)
        header.setSpacing(button_spacing)
        action_width = scale_px(68, self._ui_scale)
        result_width = scale_px(36, self._ui_scale)
        for button in (win_button, loss_button):
            button.setFixedWidth(result_width)
        for button in (save_button, clear_button):
            button.setFixedWidth(action_width)
        header.addWidget(title)
        header.addWidget(opponent, 1)
        header.addWidget(win_button)
        header.addWidget(loss_button)
        header.addWidget(save_button)
        header.addWidget(clear_button)
        layout.addLayout(header)

        recent_row = QHBoxLayout()
        recent_row.setContentsMargins(0, 0, 0, 0)
        recent_row.setSpacing(button_spacing)
        paste_screenshot_button = QPushButton("붙여넣기")
        folder_screenshot_button = QPushButton("Folder")
        screenshot_button = QPushButton("캡처")
        recent_attack_button = QPushButton("최근 공격")
        recent_defense_button = QPushButton("최근 방어")
        result_action_span = result_width * 2 + action_width * 3 + button_spacing * 4
        recent_button_width = (result_action_span - button_spacing) // 2
        screenshot_button.setFixedWidth(action_width)
        folder_screenshot_button.setFixedWidth(action_width)
        paste_screenshot_button.setFixedWidth(action_width)
        recent_min_width = scale_px(86 if self._ui_scale >= SMALL_16_9_SCALE_THRESHOLD else 76, self._ui_scale)
        for button in (recent_attack_button, recent_defense_button):
            button.setMinimumWidth(recent_min_width)
            button.setMaximumWidth(recent_button_width)
            button.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        screenshot_button.setToolTip("전술대항전 결과창 스크린샷에서 승패와 공방덱을 읽어옵니다.")
        folder_screenshot_button.setToolTip("Recursively scans 16:9 images in a folder. Date-like folder names such as 260606 are used as match dates.")
        recent_attack_button.setToolTip("상대 이름으로 최근 공격 기록의 공덱/방덱을 가져옵니다.")
        recent_defense_button.setToolTip("상대 이름으로 최근 방어 기록의 공덱/방덱을 가져옵니다.")
        paste_screenshot_button.setToolTip("Analyze one image copied to the clipboard, the same as uploading a screenshot.")
        recent_row.addStretch(1)
        recent_row.addWidget(screenshot_button)
        recent_row.addWidget(folder_screenshot_button)
        recent_row.addWidget(paste_screenshot_button)
        recent_row.addWidget(recent_attack_button, 1)
        recent_row.addWidget(recent_defense_button, 1)
        layout.addLayout(recent_row)

        mode_row = QHBoxLayout()
        mode_row.setContentsMargins(0, 0, 0, 0)
        attack_mode_button = QPushButton("공격 기록")
        defense_mode_button = QPushButton("방어 기록")
        jokbo_mode_button = QPushButton("족보")
        attack_mode_button.setCheckable(True)
        defense_mode_button.setCheckable(True)
        jokbo_mode_button.setCheckable(True)
        mode_hint = QLabel("공격 기록: 내 공격덱 vs 상대 방어덱 / 방어 기록: 상대 공격덱 vs 내 방어덱 / 족보: 방어덱과 공격덱 페어")
        mode_hint.setObjectName("detailSub")
        mode_hint.setWordWrap(True)
        mode_row.addWidget(attack_mode_button)
        mode_row.addWidget(defense_mode_button)
        mode_row.addWidget(jokbo_mode_button)
        mode_row.addWidget(mode_hint, 1)
        layout.addLayout(mode_row)

        attack_widget, attack_editor = self._build_tactical_deck_editor("공격덱")
        defense_widget, defense_editor = self._build_tactical_deck_editor("방어덱")
        layout.addWidget(attack_widget)
        layout.addWidget(defense_widget)

        notes = QPlainTextEdit()
        notes.setPlaceholderText("메모")
        notes.setMaximumHeight(scale_px(58, self._ui_scale))
        layout.addWidget(notes)
        status = QLabel("")
        status.setObjectName("filterSummary")
        status.setWordWrap(True)
        status.setMaximumHeight(scale_px(48, self._ui_scale))
        status.hide()
        layout.addWidget(status)

        panel = {
            "title": title,
            "opponent": opponent,
            "result": "win",
            "win_button": win_button,
            "loss_button": loss_button,
            "mode": "attack",
            "attack_mode_button": attack_mode_button,
            "defense_mode_button": defense_mode_button,
            "jokbo_mode_button": jokbo_mode_button,
            "attack": attack_editor,
            "defense": defense_editor,
            "notes": notes,
            "status": status,
            "save_button": save_button,
            "editing_match_id": "",
            "editing_source": "",
            "editing_created_at": "",
        }
        win_button.clicked.connect(lambda *_args, target=panel: self._set_tactical_panel_result(target, "win"))
        loss_button.clicked.connect(lambda *_args, target=panel: self._set_tactical_panel_result(target, "loss"))
        attack_mode_button.clicked.connect(lambda *_args, target=panel: self._set_tactical_panel_mode(target, "attack"))
        defense_mode_button.clicked.connect(lambda *_args, target=panel: self._set_tactical_panel_mode(target, "defense"))
        jokbo_mode_button.clicked.connect(lambda *_args, target=panel: self._set_tactical_panel_mode(target, "jokbo"))
        save_button.clicked.connect(lambda *_args, target=panel: self._save_tactical_match_panel(target))
        clear_button.clicked.connect(lambda *_args, target=panel: self._clear_tactical_match_panel(target))
        screenshot_button.clicked.connect(lambda *_args, target=panel: self._import_tactical_screenshot_panel(target))
        folder_screenshot_button.clicked.connect(lambda *_args, target=panel: self._import_tactical_screenshot_folder_panel(target))
        paste_screenshot_button.clicked.connect(lambda *_args, target=panel: self._paste_tactical_screenshot_panel(target))
        recent_attack_button.clicked.connect(lambda *_args, target=panel: self._load_recent_tactical_match_panel(target, "attack"))
        recent_defense_button.clicked.connect(lambda *_args, target=panel: self._load_recent_tactical_match_panel(target, "defense"))
        self._set_tactical_panel_result(panel, "win")
        self._set_tactical_panel_mode(panel, "attack")
        return panel_widget, panel
    def _build_tactical_abbreviation_panel(self) -> QFrame:
        panel = QFrame()
        panel.setObjectName("planBand")
        layout = QVBoxLayout(panel)
        layout.setContentsMargins(scale_px(10, self._ui_scale), scale_px(10, self._ui_scale), scale_px(10, self._ui_scale), scale_px(10, self._ui_scale))
        layout.setSpacing(scale_px(7, self._ui_scale))

        header = QHBoxLayout()
        title = QLabel("줄임말 설정")
        title.setObjectName("sectionTitle")
        self._tactical_abbrev_toggle = QPushButton("펼치기")
        self._tactical_abbrev_toggle.setObjectName("planDisclosureButton")
        self._tactical_abbrev_toggle.setCheckable(True)
        self._tactical_abbrev_toggle.clicked.connect(lambda checked=False: self._set_tactical_abbreviation_expanded(bool(checked)))
        header.addWidget(title)
        header.addStretch(1)
        header.addWidget(self._tactical_abbrev_toggle)
        layout.addLayout(header)

        self._tactical_abbrev_body = QWidget()
        self._tactical_abbrev_body.setObjectName("planTransparent")
        body_layout = QVBoxLayout(self._tactical_abbrev_body)
        body_layout.setContentsMargins(0, 0, 0, 0)
        body_layout.setSpacing(scale_px(7, self._ui_scale))

        button_row = QHBoxLayout()
        button_row.setContentsMargins(0, 0, 0, 0)
        add_striker_button = QPushButton("스트 추가")
        add_striker_button.clicked.connect(lambda *_: self._add_tactical_abbreviation_row("", "", "striker"))
        add_special_button = QPushButton("스페셜 추가")
        add_special_button.clicked.connect(lambda *_: self._add_tactical_abbreviation_row("", "", "special"))
        button_row.addStretch(1)
        button_row.addWidget(add_striker_button)
        button_row.addWidget(add_special_button)
        body_layout.addLayout(button_row)

        hint = QLabel("스트라이커와 스페셜 줄임말은 별도 사전입니다. 같은 글자도 슬롯에 따라 따로 해석됩니다.")
        hint.setObjectName("detailSub")
        hint.setWordWrap(True)
        body_layout.addWidget(hint)

        self._tactical_abbrev_rows: list[tuple[QLineEdit, QLineEdit, QWidget]] = []
        self._tactical_special_abbrev_rows: list[tuple[QLineEdit, QLineEdit, QWidget]] = []
        striker_label = QLabel("스트라이커")
        striker_label.setObjectName("detailSectionTitle")
        body_layout.addWidget(striker_label)
        self._tactical_abbrev_rows_layout = QVBoxLayout()
        self._tactical_abbrev_rows_layout.setContentsMargins(0, 0, 0, 0)
        self._tactical_abbrev_rows_layout.setSpacing(scale_px(5, self._ui_scale))
        body_layout.addLayout(self._tactical_abbrev_rows_layout)

        for key, value in sorted((self._tactical_data.abbreviations or {}).items()):
            self._add_tactical_abbreviation_row(key, value, "striker")
        if not self._tactical_abbrev_rows:
            self._add_tactical_abbreviation_row("", "", "striker")

        special_label = QLabel("스페셜")
        special_label.setObjectName("detailSectionTitle")
        body_layout.addWidget(special_label)
        self._tactical_special_abbrev_rows_layout = QVBoxLayout()
        self._tactical_special_abbrev_rows_layout.setContentsMargins(0, 0, 0, 0)
        self._tactical_special_abbrev_rows_layout.setSpacing(scale_px(5, self._ui_scale))
        body_layout.addLayout(self._tactical_special_abbrev_rows_layout)

        for key, value in sorted((self._tactical_data.special_abbreviations or {}).items()):
            self._add_tactical_abbreviation_row(key, value, "special")
        if not self._tactical_special_abbrev_rows:
            self._add_tactical_abbreviation_row("", "", "special")
        layout.addWidget(self._tactical_abbrev_body)
        self._set_tactical_abbreviation_expanded(False)
        return panel
    def _set_tactical_abbreviation_expanded(self, expanded: bool) -> None:
        body = getattr(self, "_tactical_abbrev_body", None)
        toggle = getattr(self, "_tactical_abbrev_toggle", None)
        if body is not None:
            body.setVisible(expanded)
        if toggle is not None:
            toggle.blockSignals(True)
            toggle.setChecked(expanded)
            toggle.setText("접기" if expanded else "펼치기")
            toggle.blockSignals(False)
    def _add_tactical_abbreviation_row(self, key: str, value: str, role: str = "striker") -> None:
        rows_layout_name = "_tactical_special_abbrev_rows_layout" if role == "special" else "_tactical_abbrev_rows_layout"
        rows_name = "_tactical_special_abbrev_rows" if role == "special" else "_tactical_abbrev_rows"
        rows_layout = getattr(self, rows_layout_name, None)
        rows = getattr(self, rows_name, None)
        if rows_layout is None or rows is None:
            return
        row = QWidget()
        row_layout = QHBoxLayout(row)
        row_layout.setContentsMargins(0, 0, 0, 0)
        row_layout.setSpacing(scale_px(5, self._ui_scale))
        key_input = QLineEdit(key)
        key_input.setMaxLength(1)
        key_input.setPlaceholderText("글자")
        key_input.setFixedWidth(scale_px(48, self._ui_scale))
        student_input = QLineEdit(value)
        student_input.setPlaceholderText("스페셜 학생" if role == "special" else "스트라이커 학생")
        remove_button = QPushButton("[삭제]")
        row_layout.addWidget(key_input)
        row_layout.addWidget(student_input, 1)
        row_layout.addWidget(remove_button)
        rows_layout.addWidget(row)
        rows.append((key_input, student_input, row))
        key_input.editingFinished.connect(self._save_tactical_abbreviations)
        student_input.editingFinished.connect(self._save_tactical_abbreviations)
        remove_button.clicked.connect(lambda *_args, target=row, target_role=role: self._remove_tactical_abbreviation_row(target, target_role))
    def _remove_tactical_abbreviation_row(self, row: QWidget, role: str = "striker") -> None:
        rows_name = "_tactical_special_abbrev_rows" if role == "special" else "_tactical_abbrev_rows"
        rows = getattr(self, rows_name, [])
        setattr(self, rows_name, [entry for entry in rows if entry[2] is not row])
        row.setParent(None)
        row.deleteLater()
        self._save_tactical_abbreviations()
    def _set_tactical_panel_mode(self, panel: dict, mode: str) -> None:
        panel["mode"] = mode if mode in {"attack", "defense", "jokbo"} else "attack"
        if "title" in panel:
            if panel.get("editing_match_id"):
                panel["title"].setText("전적 수정")
            else:
                panel["title"].setText("족보 모드" if panel["mode"] == "jokbo" else "대전 기록")
        panel["attack_mode_button"].setChecked(panel["mode"] == "attack")
        panel["defense_mode_button"].setChecked(panel["mode"] == "defense")
        panel["jokbo_mode_button"].setChecked(panel["mode"] == "jokbo")
        selected_style = "background: transparent; color: #ffb5f0; border: 2px solid #ffb5f0; font-weight: 900;"
        idle_style = f"background: transparent; color: {MUTED}; border: 1px solid {_mix_hex('#ffb5f0', SURFACE_ALT, 0.28)}; font-weight: 700;"
        panel["attack_mode_button"].setStyleSheet(selected_style if panel["mode"] == "attack" else idle_style)
        panel["defense_mode_button"].setStyleSheet(selected_style if panel["mode"] == "defense" else idle_style)
        panel["jokbo_mode_button"].setStyleSheet(selected_style if panel["mode"] == "jokbo" else idle_style)
        opponent_input = panel.get("opponent")
        if opponent_input is not None:
            is_jokbo = panel["mode"] == "jokbo"
            opponent_input.setEnabled(not is_jokbo)
            opponent_input.setPlaceholderText("족보 모드에서는 상대 이름 미사용" if is_jokbo else "상대 이름")
    def _set_tactical_panel_result(self, panel: dict, result: str) -> None:
        panel["result"] = "loss" if result == "loss" else "win"
        panel["win_button"].setChecked(panel["result"] == "win")
        panel["loss_button"].setChecked(panel["result"] == "loss")
        panel["win_button"].setText("승")
        panel["loss_button"].setText("패")
        selected_style = "background: transparent; color: #ffb5f0; border: 2px solid #ffb5f0; font-weight: 900;"
        idle_style = f"background: transparent; color: {MUTED}; border: 1px solid {_mix_hex('#ffb5f0', SURFACE_ALT, 0.28)}; font-weight: 700;"
        panel["win_button"].setStyleSheet(selected_style if panel["result"] == "win" else idle_style)
        panel["loss_button"].setStyleSheet(selected_style if panel["result"] == "loss" else idle_style)
    def _set_tactical_panel_editing(self, panel: dict, match: TacticalMatch | None = None) -> None:
        panel["editing_match_id"] = match.id if match is not None else ""
        panel["editing_source"] = match.source if match is not None else ""
        panel["editing_created_at"] = match.created_at if match is not None else ""
        save_button = panel.get("save_button")
        if save_button is not None:
            save_button.setText("수정 저장" if match is not None else "전적 추가")
        self._set_tactical_panel_mode(panel, panel.get("mode", "attack"))
        if hasattr(self, "_tactical_match_list"):
            self._refresh_tactical_match_list()
    def _load_tactical_match_into_panel(self, panel: dict, match: TacticalMatch) -> None:
        if hasattr(self, "_tactical_date"):
            self._tactical_date.setText(match.date or "")
        if hasattr(self, "_tactical_season"):
            self._tactical_season.setText(match.season or self._tactical_data.season or "")
        panel["opponent"].setText(match.opponent)
        panel["notes"].setPlainText(match.notes)
        self._set_tactical_panel_result(panel, match.result)
        has_attack_pair = bool(match.my_attack.strikers or match.my_attack.supports or match.opponent_defense.strikers or match.opponent_defense.supports)
        has_defense_pair = bool(match.my_defense.strikers or match.my_defense.supports or match.opponent_attack.strikers or match.opponent_attack.supports)
        mode = "defense" if has_defense_pair and not has_attack_pair else "attack"
        self._set_tactical_panel_mode(panel, mode)
        if mode == "defense":
            self._set_tactical_deck_inputs(panel["attack"], match.opponent_attack)
            self._set_tactical_deck_inputs(panel["defense"], match.my_defense)
        else:
            self._set_tactical_deck_inputs(panel["attack"], match.my_attack)
            self._set_tactical_deck_inputs(panel["defense"], match.opponent_defense)
        self._set_tactical_panel_editing(panel, match)
        self._set_tactical_status(f"{self._tactical_date_label(match)} {match.opponent} 전적을 수정 모드로 불러왔습니다.", panel=panel)
    def _tactical_import_key(self, value: object) -> str:
        return re.sub(r"[\s_\-./()]+", "", str(value or "").strip().casefold())
    def _tactical_import_template_path(self) -> Path:
        return get_storage_paths().current_dir / "tactical_challenge_import_template.xlsx"
    def _ensure_tactical_import_template(self) -> Path:
        path = self._tactical_import_template_path()
        ensure_tactical_import_template(path)
        return path
    def _tactical_import_value(self, row: dict[str, str], *aliases: str) -> str:
        for alias in aliases:
            value = row.get(self._tactical_import_key(alias), "")
            if str(value or "").strip():
                return str(value).strip()
        return ""
    def _tactical_import_deck_value(
        self,
        row: dict[str, str],
        single_aliases: tuple[str, ...],
        slot_aliases: tuple[str, ...],
    ) -> str:
        single_value = self._tactical_import_value(row, *single_aliases)
        if single_value:
            return single_value

        def _slot(index: int) -> str:
            aliases: list[str] = []
            for alias in slot_aliases:
                aliases.extend(
                    [
                        f"{alias}{index}",
                        f"{alias}S{index}",
                        f"{alias}스트{index}",
                        f"{alias}스트라이커{index}",
                    ]
                )
            return self._tactical_import_value(row, *aliases)

        def _support(index: int) -> str:
            aliases: list[str] = []
            for alias in slot_aliases:
                aliases.extend(
                    [
                        f"{alias}SP{index}",
                        f"{alias}Special{index}",
                        f"{alias}스페셜{index}",
                        f"{alias}서포터{index}",
                        f"{alias}지원{index}",
                    ]
                )
            return self._tactical_import_value(row, *aliases)

        strikers = [_slot(index) for index in range(1, TACTICAL_STRIKER_SLOTS + 1)]
        supports = [_support(index) for index in range(1, TACTICAL_SUPPORT_SLOTS + 1)]
        if not any(strikers) and not any(supports):
            return ""
        return f"{','.join(strikers)}|{','.join(supports)}"
    def _normalize_tactical_import_date(self, value: str) -> str:
        text = str(value or "").strip()
        if not text:
            return ""
        if re.fullmatch(r"\d{8}", text):
            return date(int(text[:4]), int(text[4:6]), int(text[6:8])).isoformat()
        if re.fullmatch(r"\d+(\.0+)?", text):
            serial = int(float(text))
            if 20000 <= serial <= 80000:
                return (date(1899, 12, 30) + timedelta(days=serial)).isoformat()
        normalized = re.sub(r"[./]", "-", text)
        return date.fromisoformat(normalized[:10]).isoformat()
    def _normalize_tactical_import_result(self, value: str) -> str:
        key = self._tactical_import_key(value)
        if key in {"승", "win", "w", "1", "true", "o"}:
            return "win"
        if key in {"패", "loss", "lose", "l", "0", "false", "x"}:
            return "loss"
        return ""
    def _normalize_tactical_import_mode(self, value: str) -> str:
        key = self._tactical_import_key(value)
        if "족보" in key or "jokbo" in key:
            return "jokbo"
        if "방어" in key or "defense" in key or key == "def":
            return "defense"
        return "attack"
    def _canonical_import_deck(self, row_number: int, deck_text: str, label: str, errors: list[str]) -> TacticalDeck:
        deck = self._parse_tactical_deck_template(deck_text)
        canonical, error = self._canonical_tactical_deck_or_error(deck, label)
        if error:
            errors.append(f"{row_number}행: {error}")
        return canonical
    def _failed_tactical_import_row(self, raw_row: dict[str, str], error: str) -> dict[str, str]:
        failed = {str(key): str(value or "").strip() for key, value in raw_row.items()}
        failed["오류"] = error
        return failed
    def _build_tactical_import_entries(self, rows: list[dict[str, str]]) -> tuple[list[TacticalMatch], list[TacticalJokboEntry], list[str], list[dict[str, str]]]:
        matches: list[TacticalMatch] = []
        jokbo_entries: list[TacticalJokboEntry] = []
        errors: list[str] = []
        failed_rows: list[dict[str, str]] = []
        now = datetime.now().isoformat(timespec="seconds")

        for index, raw_row in enumerate(rows, start=2):
            row = {self._tactical_import_key(key): str(value or "").strip() for key, value in raw_row.items()}

            def reject(message: str) -> None:
                errors.append(message)
                failed_rows.append(self._failed_tactical_import_row(raw_row, message))

            mode = self._normalize_tactical_import_mode(
                self._tactical_import_value(row, "mode", "type", "구분", "종류", "기록종류", "기록")
            )
            generic_attack = self._tactical_import_deck_value(
                row,
                ("attack", "atk", "공격덱", "공덱"),
                ("attack", "atk", "공격", "공"),
            )
            generic_defense = self._tactical_import_deck_value(
                row,
                ("defense", "def", "방어덱", "방덱"),
                ("defense", "def", "방어", "방"),
            )
            notes = self._tactical_import_value(row, "notes", "note", "memo", "메모", "비고")
            source = self._tactical_import_value(row, "source", "출처", "데이터출처", "source_type") or "내 기록"
            row_id = self._tactical_import_value(row, "id", "match_id", "고유값")

            if mode == "jokbo":
                defense_text = self._tactical_import_deck_value(
                    row,
                    ("jokbo_defense", "족보방어덱", "방어덱", "방덱"),
                    ("jokbo_defense", "jokbodef", "족보방어", "방어", "방"),
                ) or generic_defense
                attack_text = self._tactical_import_deck_value(
                    row,
                    ("jokbo_attack", "족보공격덱", "공격덱", "공덱"),
                    ("jokbo_attack", "jokboatk", "족보공격", "공격", "공"),
                ) or generic_attack
                if not defense_text or not attack_text:
                    reject(f"{index}행: 족보는 공격덱과 방어덱이 모두 필요합니다.")
                    continue
                jokbo_errors_before = len(errors)
                defense = self._canonical_import_deck(index, defense_text, "족보 방어덱", errors)
                attack = self._canonical_import_deck(index, attack_text, "족보 공격덱", errors)
                if len(errors) != jokbo_errors_before:
                    failed_rows.append(self._failed_tactical_import_row(raw_row, "\n".join(errors[jokbo_errors_before:])))
                    continue
                jokbo_entries.append(
                    TacticalJokboEntry(
                        id=row_id or f"import-jokbo-{datetime.now().strftime('%Y%m%d%H%M%S')}-{index}-{uuid4().hex[:6]}",
                        defense=defense,
                        attack=attack,
                        notes=notes,
                        updated_at=now,
                    )
                )
                continue

            date_text = self._tactical_import_value(row, "date", "날짜", "일자")
            opponent = self._tactical_import_value(row, "opponent", "상대", "상대이름", "name", "이름")
            result_text = self._tactical_import_value(row, "result", "승패", "결과", "winloss")
            result = self._normalize_tactical_import_result(result_text) if result_text else "loss"
            if not opponent and source != "내 기록":
                opponent = "미상"
            if not opponent:
                reject(f"{index}행: 상대 이름이 필요합니다.")
                continue
            if result_text and not result:
                reject(f"{index}행: 승패는 승/패 또는 win/loss로 입력해 주세요.")
                continue
            if date_text:
                try:
                    match_date = self._normalize_tactical_import_date(date_text)
                except Exception:
                    reject(f"{index}행: 날짜 '{date_text}'를 인식할 수 없습니다.")
                    continue
            else:
                match_date = ""

            my_attack_text = self._tactical_import_deck_value(
                row,
                ("my_attack", "my atk", "내공격덱", "내공덱"),
                ("my_attack", "myatk", "내공격", "내공"),
            )
            opponent_defense_text = self._tactical_import_deck_value(
                row,
                ("opponent_defense", "op def", "상대방어덱", "상대방덱"),
                ("opponent_defense", "opdef", "상대방어", "상대방"),
            )
            my_defense_text = self._tactical_import_deck_value(
                row,
                ("my_defense", "my def", "내방어덱", "내방덱"),
                ("my_defense", "mydef", "내방어", "내방"),
            )
            opponent_attack_text = self._tactical_import_deck_value(
                row,
                ("opponent_attack", "op atk", "상대공격덱", "상대공덱"),
                ("opponent_attack", "opatk", "상대공격", "상대공"),
            )
            if mode == "defense":
                my_defense_text = my_defense_text or generic_defense
                opponent_attack_text = opponent_attack_text or generic_attack
            else:
                my_attack_text = my_attack_text or generic_attack
                opponent_defense_text = opponent_defense_text or generic_defense

            if not any((my_attack_text, opponent_defense_text, my_defense_text, opponent_attack_text)):
                reject(f"{index}행: 덱 정보가 필요합니다.")
                continue

            match_errors_before = len(errors)
            my_attack = self._canonical_import_deck(index, my_attack_text, "내 공격덱", errors) if my_attack_text else TacticalDeck()
            opponent_defense = self._canonical_import_deck(index, opponent_defense_text, "상대 방어덱", errors) if opponent_defense_text else TacticalDeck()
            my_defense = self._canonical_import_deck(index, my_defense_text, "내 방어덱", errors) if my_defense_text else TacticalDeck()
            opponent_attack = self._canonical_import_deck(index, opponent_attack_text, "상대 공격덱", errors) if opponent_attack_text else TacticalDeck()
            if len(errors) != match_errors_before:
                failed_rows.append(self._failed_tactical_import_row(raw_row, "\n".join(errors[match_errors_before:])))
                continue

            matches.append(
                TacticalMatch(
                    id=row_id or f"import-tc-{datetime.now().strftime('%Y%m%d%H%M%S')}-{index}-{uuid4().hex[:6]}",
                    date=match_date,
                    season=self._tactical_import_value(row, "season", "시즌") or self._tactical_data.season,
                    opponent=opponent,
                    result=result,
                    my_attack=my_attack,
                    opponent_defense=opponent_defense,
                    my_defense=my_defense,
                    opponent_attack=opponent_attack,
                    source=source,
                    notes=notes,
                    created_at=now,
                )
            )

        return matches, jokbo_entries, errors, failed_rows
    def _import_tactical_spreadsheet(self) -> None:
        template_path = self._ensure_tactical_import_template()
        self._show_busy_overlay("가져오는 중...")
        try:
            rows = read_tactical_import_rows(template_path)
            if not rows:
                self._set_tactical_status(f"템플릿에 가져올 행이 없습니다.\n{template_path}", error=True)
                return
            matches, jokbo_entries, errors, failed_rows = self._build_tactical_import_entries(rows)
            if not matches and not jokbo_entries and errors:
                write_tactical_import_rows(template_path, failed_rows)
                preview = "\n".join(errors[:12])
                suffix = f"\n...외 {len(errors) - 12}개 오류" if len(errors) > 12 else ""
                self._set_tactical_status(
                    "가져올 수 있는 행이 없습니다. 문제가 있는 행만 템플릿에 남겼습니다.\n" + preview + suffix,
                    error=True,
                )
                return
            upsert_tactical_matches(self._tactical_path, matches)
            upsert_tactical_jokbo_entries(self._tactical_path, jokbo_entries)
            self._storage_mtimes = self._snapshot_storage_mtimes()
            self._tactical_match_loaded_count = max(self._tactical_match_loaded_count, self._tactical_match_page_size)
            self._refresh_tactical_match_list()
            self._refresh_tactical_jokbo_results()
            if failed_rows:
                write_tactical_import_rows(template_path, failed_rows)
                preview = "\n".join(errors[:8])
                suffix = f"\n...외 {len(errors) - 8}개 오류" if len(errors) > 8 else ""
                self._set_tactical_status(
                    f"정상 행은 가져왔습니다. 전적 {len(matches)}개, 족보 {len(jokbo_entries)}개\n"
                    f"문제가 있는 행 {len(failed_rows)}개는 템플릿에 남겼습니다. 확인이 필요합니다.\n"
                    f"{preview}{suffix}",
                    error=True,
                )
            else:
                clear_tactical_import_template(template_path)
                self._set_tactical_status(
                    f"템플릿 데이터를 가져왔습니다. 전적 {len(matches)}개, 족보 {len(jokbo_entries)}개\n"
                    f"템플릿을 비웠습니다: {template_path}"
                )
        except Exception as exc:
            self._set_tactical_status(f"가져오기 실패: {exc}", error=True)
        finally:
            self._hide_busy_overlay()
    def _save_tactical_match_panel(self, panel: dict) -> None:
        if not self._save_tactical_abbreviations():
            return
        season = self._tactical_season.text().strip()
        if self._tactical_data.season != season:
            self._tactical_data.season = season
            self._save_tactical_metadata()
        now = datetime.now().isoformat(timespec="seconds")
        attack_deck = self._deck_from_tactical_inputs(panel["attack"])
        defense_deck = self._deck_from_tactical_inputs(panel["defense"])
        attack_deck, attack_error = self._canonical_tactical_deck_or_error(attack_deck, "공격덱")
        defense_deck, defense_error = self._canonical_tactical_deck_or_error(defense_deck, "방어덱")
        if attack_error or defense_error:
            self._set_tactical_status("\n".join(error for error in (attack_error, defense_error) if error), error=True, panel=panel)
            return
        self._set_tactical_deck_inputs(panel["attack"], attack_deck)
        self._set_tactical_deck_inputs(panel["defense"], defense_deck)
        if panel.get("mode") == "jokbo":
            if panel.get("editing_match_id"):
                self._set_tactical_status("전적 수정 중에는 족보로 저장할 수 없습니다. Clear로 수정 모드를 끝낸 뒤 저장해 주세요.", error=True, panel=panel)
                return
            if not any(defense_deck.strikers) and not any(defense_deck.supports):
                self._set_tactical_status("족보의 방어덱을 입력해 주세요.", error=True, panel=panel)
                return
            if not any(attack_deck.strikers) and not any(attack_deck.supports):
                self._set_tactical_status("족보의 공격덱을 입력해 주세요.", error=True, panel=panel)
                return
            entry = TacticalJokboEntry(
                id=f"jokbo-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid4().hex[:6]}",
                defense=defense_deck,
                attack=attack_deck,
                wins=0,
                losses=0,
                notes=panel["notes"].toPlainText().strip(),
                updated_at=now,
            )
            self._show_busy_overlay()
            try:
                self._tactical_data.jokbo.append(entry)
                upsert_tactical_jokbo(self._tactical_path, entry)
                self._storage_mtimes = self._snapshot_storage_mtimes()
                if hasattr(self, "_tactical_jokbo_search_inputs"):
                    self._set_tactical_deck_inputs(self._tactical_jokbo_search_inputs, defense_deck)
                self._refresh_tactical_jokbo_results()
            finally:
                self._hide_busy_overlay()
            self._set_tactical_status("족보를 저장했습니다.", panel=panel)
            return

        opponent = panel["opponent"].text().strip()
        if not opponent:
            self._set_tactical_status("상대 이름을 입력해 주세요.", error=True, panel=panel)
            return
        editing_match_id = str(panel.get("editing_match_id") or "")
        existing_match = get_tactical_match(self._tactical_path, editing_match_id) if editing_match_id else None
        is_defense_record = panel.get("mode") == "defense"
        match = TacticalMatch(
            id=editing_match_id or f"tc-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid4().hex[:6]}",
            date=self._tactical_date.text().strip(),
            season=season,
            opponent=opponent,
            result=str(panel["result"]),
            my_attack=TacticalDeck() if is_defense_record else attack_deck,
            opponent_defense=TacticalDeck() if is_defense_record else defense_deck,
            my_defense=defense_deck if is_defense_record else TacticalDeck(),
            opponent_attack=attack_deck if is_defense_record else TacticalDeck(),
            source=panel.get("editing_source") or (existing_match.source if existing_match is not None else "내 기록") or "내 기록",
            notes=panel["notes"].toPlainText().strip(),
            created_at=panel.get("editing_created_at") or (existing_match.created_at if existing_match is not None else now) or now,
        )
        self._tactical_selected_match_id = match.id
        self._show_busy_overlay()
        try:
            upsert_tactical_match(self._tactical_path, match)
            self._storage_mtimes = self._snapshot_storage_mtimes()
            self._tactical_match_loaded_count = max(self._tactical_match_loaded_count, self._tactical_match_page_size)
            self._refresh_tactical_match_list()
        finally:
            self._hide_busy_overlay()
        self._set_tactical_panel_editing(panel, match if editing_match_id else None)
        action_text = "수정했습니다" if editing_match_id else "저장했습니다"
        self._set_tactical_status(f"{self._tactical_date_label(match)} {opponent} 전적을 {action_text}.", panel=panel)
    def _clear_tactical_match_panel(self, panel: dict) -> None:
        panel["opponent"].clear()
        panel["notes"].clear()
        self._set_tactical_status("", panel=panel)
        self._set_tactical_panel_editing(panel, None)
        self._set_tactical_panel_result(panel, "win")
        self._set_tactical_panel_mode(panel, "attack")
        if hasattr(self, "_tactical_date"):
            self._tactical_date.setText(date.today().isoformat())
        if hasattr(self, "_tactical_season"):
            self._tactical_season.setText(self._tactical_data.season or "")
        self._clear_tactical_deck_inputs(panel["attack"])
        self._clear_tactical_deck_inputs(panel["defense"])
    def _load_recent_tactical_match_panel(self, panel: dict, mode: str) -> None:
        opponent = panel["opponent"].text().strip()
        if not opponent:
            self._set_tactical_status("상대 이름을 입력해 주세요.", error=True, panel=panel)
            return
        mode = "defense" if mode == "defense" else "attack"
        self._show_busy_overlay("불러오는 중...")
        try:
            match = latest_tactical_match_for_opponent(self._tactical_path, opponent, mode)
        finally:
            self._hide_busy_overlay()
        if match is None:
            label = "방어" if mode == "defense" else "공격"
            self._set_tactical_status(f"{opponent}의 최근 {label} 기록을 찾지 못했습니다.", error=True, panel=panel)
            return
        self._set_tactical_panel_mode(panel, mode)
        self._set_tactical_panel_result(panel, match.result)
        if mode == "defense":
            self._set_tactical_deck_inputs(panel["attack"], match.opponent_attack)
            self._set_tactical_deck_inputs(panel["defense"], match.my_defense)
        else:
            self._set_tactical_deck_inputs(panel["attack"], match.my_attack)
            self._set_tactical_deck_inputs(panel["defense"], match.opponent_defense)
        label = "방어" if mode == "defense" else "공격"
        self._set_tactical_status(f"{self._tactical_date_label(match)} {opponent} 최근 {label} 기록을 가져왔습니다.", panel=panel)
    def _start_tactical_screenshot_task(self, panel: dict, path: str, busy_text: str) -> None:
        self._show_busy_overlay(busy_text)
        task = TacticalScreenshotTask(path, self._tactical_screenshot_candidate_priority(), self._tactical_screenshot_answer_cache_path())
        task.signals.loaded.connect(
            lambda loaded_path, readout, target=panel, finished_task=task: self._apply_tactical_screenshot_readout(
                target,
                loaded_path,
                readout,
                finished_task,
            )
        )
        task.signals.failed.connect(
            lambda loaded_path, message, target=panel, finished_task=task: self._fail_tactical_screenshot_import(
                target,
                loaded_path,
                message,
                finished_task,
            )
        )
        self._tactical_screenshot_tasks.append(task)
        self._pool.start(task)
    def _start_tactical_screenshot_batch_task(self, panel: dict, paths: list[str], busy_text: str) -> None:
        self._show_busy_overlay(busy_text)
        task = TacticalScreenshotBatchTask(paths, self._tactical_screenshot_candidate_priority(), self._tactical_screenshot_answer_cache_path())
        task.signals.completed.connect(
            lambda results, errors, target=panel, finished_task=task: self._apply_tactical_screenshot_batch(
                target,
                results,
                errors,
                finished_task,
            )
        )
        self._tactical_screenshot_tasks.append(task)
        self._pool.start(task)
    def _tactical_screenshot_answer_cache_path(self) -> str:
        return str(get_storage_paths().current_dir / "tactical_screenshot_answer_cache.json")
    def _tactical_screenshot_candidate_priority(self) -> dict[str, list[str]]:
        season = self._tactical_season.text().strip() if hasattr(self, "_tactical_season") else ""
        try:
            return tactical_student_frequency_from_storage(self._tactical_path, season, limit=20)
        except Exception:
            return {}
    def _paste_tactical_screenshot_panel(self, panel: dict) -> None:
        clipboard = QApplication.clipboard()
        image = clipboard.image()
        source_path = ""
        if image.isNull():
            pixmap = clipboard.pixmap()
            if not pixmap.isNull():
                image = pixmap.toImage()
        if image.isNull():
            mime = clipboard.mimeData()
            if mime is not None and mime.hasUrls():
                for url in mime.urls():
                    path = Path(url.toLocalFile())
                    if path.suffix.casefold() in {".png", ".jpg", ".jpeg", ".bmp"} and path.exists():
                        source_path = str(path)
                        break
        if image.isNull() and not source_path:
            self._set_tactical_status("클립보드에 분석할 이미지가 없습니다.", error=True, panel=panel)
            return
        if source_path:
            self._start_tactical_screenshot_task(panel, source_path, "클립보드 이미지 분석 중...")
            return

        clipboard_dir = get_storage_paths().current_dir / "tactical_clipboard"
        clipboard_dir.mkdir(parents=True, exist_ok=True)
        path = clipboard_dir / f"tactical_clipboard_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{uuid4().hex[:6]}.png"
        if not image.save(str(path), "PNG"):
            self._set_tactical_status("클립보드 이미지를 저장하지 못했습니다.", error=True, panel=panel)
            return
        self._start_tactical_screenshot_task(panel, str(path), "클립보드 이미지 분석 중...")
    def _import_tactical_screenshot_panel(self, panel: dict) -> None:
        paths, _selected_filter = QFileDialog.getOpenFileNames(
            self,
            "Select tactical result screenshots",
            str(Path.home() / "Pictures" / "Screenshots"),
            "Images (*.png *.jpg *.jpeg *.bmp *.webp);;All Files (*)",
        )
        if not paths:
            return
        paths = sorted(paths, key=self._tactical_screenshot_file_time_key)
        if len(paths) > 1:
            self._start_tactical_screenshot_batch_task(
                panel,
                paths,
                f"Analyzing {len(paths)} screenshots...",
            )
            return
        self._start_tactical_screenshot_task(panel, paths[0], "Analyzing screenshot...")
    def _import_tactical_screenshot_folder_panel(self, panel: dict) -> None:
        folder = QFileDialog.getExistingDirectory(
            self,
            "Select tactical screenshot folder",
            str(Path.home() / "Pictures" / "Screenshots"),
        )
        if not folder:
            return
        paths = [str(path) for path in collect_tactical_screenshot_images(folder)]
        if not paths:
            self._set_tactical_status("Folder contains no readable 16:9 screenshots.", error=True, panel=panel)
            return
        paths = sorted(paths, key=self._tactical_screenshot_batch_sort_key)
        self._start_tactical_screenshot_batch_task(
            panel,
            paths,
            f"Analyzing {len(paths)} folder screenshots...",
        )
    def _tactical_screenshot_batch_sort_key(self, path: str) -> tuple[str, int, int, str]:
        inferred_date = tactical_screenshot_date_from_path(path)
        created_ns, modified_ns, folded = self._tactical_screenshot_file_time_key(path)
        return (inferred_date, created_ns, modified_ns, folded)
    def _tactical_screenshot_file_time_key(self, path: str) -> tuple[int, int, str]:
        try:
            stat = Path(path).stat()
            created_ns = getattr(stat, "st_birthtime_ns", None)
            if created_ns is None:
                created_ns = int(stat.st_ctime_ns)
            modified_ns = int(stat.st_mtime_ns)
        except OSError:
            created_ns = 0
            modified_ns = 0
        return (int(created_ns), modified_ns, str(path).casefold())
    def _discard_tactical_screenshot_task(self, task: QRunnable | None) -> None:
        if task is None:
            return
        try:
            self._tactical_screenshot_tasks.remove(task)
        except ValueError:
            pass
    def _fail_tactical_screenshot_import(
        self,
        panel: dict,
        _path: str,
        message: str,
        task: TacticalScreenshotTask | None = None,
    ) -> None:
        self._discard_tactical_screenshot_task(task)
        self._hide_busy_overlay()
        self._set_tactical_status(f"스크린샷 분석 실패: {message}", error=True, panel=panel)
    def _display_tactical_screenshot_deck(self, deck: TacticalDeck) -> TacticalDeck:
        return TacticalDeck(
            strikers=[self._tactical_student_display_name(student_id) for student_id in deck.strikers],
            supports=[self._tactical_student_display_name(student_id) for student_id in deck.supports],
        )
    def _tactical_match_from_screenshot_readout(
        self,
        readout: object,
        *,
        opponent: str,
        match_date: str,
        season: str,
        source: str,
        notes: str,
        created_at: str,
    ) -> TacticalMatch:
        left_deck = self._display_tactical_screenshot_deck(readout.left.deck)
        right_deck = self._display_tactical_screenshot_deck(readout.right.deck)
        is_defense_record = readout.mode == "defense"
        return TacticalMatch(
            id=f"tc-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid4().hex[:6]}",
            date=match_date,
            season=season,
            opponent=opponent,
            result=readout.result,
            my_attack=TacticalDeck() if is_defense_record else left_deck,
            opponent_defense=TacticalDeck() if is_defense_record else right_deck,
            my_defense=left_deck if is_defense_record else TacticalDeck(),
            opponent_attack=right_deck if is_defense_record else TacticalDeck(),
            source=source,
            notes=notes,
            created_at=created_at,
        )
    def _apply_tactical_screenshot_batch(
        self,
        panel: dict,
        results: object,
        errors: object,
        task: QRunnable | None = None,
    ) -> None:
        self._discard_tactical_screenshot_task(task)
        self._hide_busy_overlay()
        readouts = list(results or [])
        failures = list(errors or [])
        if not readouts:
            preview = "; ".join(f"{Path(path).name}: {message}" for path, message in failures[:3])
            self._set_tactical_status(f"스크린샷 분석 실패: {preview}", error=True, panel=panel)
            return

        fallback_match_date = self._tactical_date.text().strip() if hasattr(self, "_tactical_date") else ""
        if not fallback_match_date:
            fallback_match_date = date.today().isoformat()
        season = self._tactical_season.text().strip() if hasattr(self, "_tactical_season") else ""
        now = datetime.now()
        matches: list[TacticalMatch] = []
        warnings: list[str] = []
        for index, (path, readout) in enumerate(readouts):
            created_at = (now + timedelta(microseconds=index)).isoformat(timespec="microseconds")
            match = self._tactical_match_from_screenshot_readout(
                readout,
                opponent="",
                match_date=tactical_screenshot_date_from_path(path) or fallback_match_date,
                season=season,
                source="스크린샷",
                notes="",
                created_at=created_at,
            )
            matches.append(match)
            warnings.extend(f"{Path(path).name}: {warning}" for warning in readout.warnings[:2])

        upsert_tactical_matches(self._tactical_path, matches)
        self._storage_mtimes = self._snapshot_storage_mtimes()
        self._tactical_match_loaded_count = max(self._tactical_match_loaded_count, self._tactical_match_page_size)
        self._tactical_selected_match_id = matches[-1].id if matches else self._tactical_selected_match_id
        self._refresh_tactical_match_list()
        self._refresh_tactical_jokbo_results()
        panel["opponent"].clear()

        failed_text = f" 실패 {len(failures)}장." if failures else ""
        warning_text = f"\n주의: {' / '.join(warnings[:3])}" if warnings else ""
        self._set_tactical_status(
            f"스크린샷 {len(matches)}장을 상대 이름 없이 순서대로 추가했습니다.{failed_text}{warning_text}",
            error=bool(failures or warnings),
            panel=panel,
        )
        self._open_tactical_opponents_batch(matches, panel=panel)
    def _apply_tactical_screenshot_readout(
        self,
        panel: dict,
        _path: str,
        readout: object,
        task: TacticalScreenshotTask | None = None,
    ) -> None:
        self._discard_tactical_screenshot_task(task)
        self._hide_busy_overlay()

        self._set_tactical_panel_editing(panel, None)
        self._set_tactical_panel_result(panel, readout.result)
        self._set_tactical_panel_mode(panel, readout.mode)
        if readout.mode == "defense":
            self._set_tactical_deck_inputs(panel["attack"], self._display_tactical_screenshot_deck(readout.right.deck))
            self._set_tactical_deck_inputs(panel["defense"], self._display_tactical_screenshot_deck(readout.left.deck))
        else:
            self._set_tactical_deck_inputs(panel["attack"], self._display_tactical_screenshot_deck(readout.left.deck))
            self._set_tactical_deck_inputs(panel["defense"], self._display_tactical_screenshot_deck(readout.right.deck))
        if hasattr(self, "_tactical_date") and not self._tactical_date.text().strip():
            self._tactical_date.setText(date.today().isoformat())
        mode_label = "방어 기록" if readout.mode == "defense" else "공격 기록"
        result_label = "승" if readout.result == "win" else "패"
        warning_text = f"\n주의: {' / '.join(readout.warnings[:3])}" if readout.warnings else ""
        self._set_tactical_status(
            f"스크린샷에서 {mode_label} · {result_label} · 좌우 덱을 불러왔습니다. 상대 이름은 직접 입력해 주세요."
            f"{warning_text}",
            error=bool(readout.warnings),
            panel=panel,
        )
    def _save_tactical_season(self) -> None:
        if self._tactical_data.season == self._tactical_season.text().strip():
            return
        self._tactical_data.season = self._tactical_season.text().strip()
        self._save_tactical_metadata()
    def _save_tactical_abbreviations(self) -> bool:
        if not hasattr(self, "_tactical_abbrev_rows"):
            return True
        errors: list[str] = []

        def _collect(rows: list[tuple[QLineEdit, QLineEdit, QWidget]], expected_class: str, label: str) -> dict[str, str]:
            mapping: dict[str, str] = {}
            for key_input, student_input, _row in rows:
                key = key_input.text().strip()
                value = student_input.text().strip()
                if not key and not value:
                    continue
                if not key or not value:
                    errors.append(f"{label} 줄임말: 글자와 학생을 모두 입력해 주세요.")
                    continue
                if len(key) != 1:
                    errors.append(f"{label} 줄임말: '{key}'는 한 글자만 사용할 수 있습니다.")
                    continue
                if key in mapping:
                    errors.append(f"{label} 줄임말: '{key}'가 중복 등록되어 있습니다.")
                    continue
                matches = self._tactical_student_ids_for_name(value)
                if not matches:
                    errors.append(f"{label} 줄임말: '{value}' 학생을 인식할 수 없습니다.")
                    continue
                if len(matches) > 1:
                    names = ", ".join(self._tactical_student_display_name(student_id) for student_id in matches[:6])
                    suffix = "..." if len(matches) > 6 else ""
                    errors.append(f"{label} 줄임말: '{value}' 중복 태그입니다. ({names}{suffix})")
                    continue
                student_id = matches[0]
                if student_meta.combat_class(student_id) != expected_class:
                    errors.append(f"{label} 줄임말: '{self._tactical_student_display_name(student_id)}'는 {label} 학생이 아닙니다.")
                    continue
                mapping[key] = self._tactical_student_display_name(student_id)
                student_input.setText(mapping[key])
            return mapping

        striker_mapping = _collect(self._tactical_abbrev_rows, "striker", "스트라이커")
        special_mapping = _collect(getattr(self, "_tactical_special_abbrev_rows", []), "special", "스페셜")
        if errors:
            self._set_tactical_status("\n".join(errors), error=True)
            return False
        if (
            striker_mapping == self._tactical_data.abbreviations
            and special_mapping == self._tactical_data.special_abbreviations
        ):
            return True
        self._tactical_data.abbreviations = striker_mapping
        self._tactical_data.special_abbreviations = special_mapping
        self._save_tactical_metadata()
        return True
    def _compact_tactical_message(self, text: str, *, max_lines: int = 2, max_chars: int = 150) -> str:
        full_text = str(text or "").strip()
        if not full_text:
            return ""
        lines = [line.strip() for line in full_text.splitlines() if line.strip()]
        if len(lines) > max_lines:
            visible = lines[:max_lines]
            visible.append(f"...외 {len(lines) - max_lines}개")
            return "\n".join(visible)
        compact = "\n".join(lines) if lines else full_text
        if len(compact) > max_chars:
            return compact[: max(0, max_chars - 3)].rstrip() + "..."
        return compact
    def _set_tactical_status(self, text: str, *, error: bool = False, panel: dict | None = None) -> None:
        target = panel.get("status") if panel is not None else None
        if target is None and getattr(self, "_tactical_match_panels", None):
            target = self._tactical_match_panels[0].get("status")
        if target is None and hasattr(self, "_tactical_status"):
            target = self._tactical_status
        if target is None:
            return
        full_text = str(text or "").strip()
        compact_text = self._compact_tactical_message(full_text)
        target.setStyleSheet("color: #ff6b6b; font-weight: 800;" if error else "")
        target.setText(compact_text)
        target.setToolTip(full_text if full_text and full_text != compact_text else "")
        target.setVisible(bool(full_text))
    def _tactical_lookup_key(self, value: object) -> str:
        cleaned = " ".join(str(value or "").strip().split())
        cleaned = re.sub(r"\s*([()])\s*", r"\1", cleaned)
        return cleaned.casefold()
    def _tactical_abbreviation_map(self, role: str = "striker") -> dict[str, str]:
        rows_name = "_tactical_special_abbrev_rows" if role == "special" else "_tactical_abbrev_rows"
        data = self._tactical_data.special_abbreviations if role == "special" else self._tactical_data.abbreviations
        if hasattr(self, rows_name):
            mapping: dict[str, str] = {}
            for key_input, student_input, _row in getattr(self, rows_name):
                key = key_input.text().strip()
                value = student_input.text().strip()
                if len(key) == 1 and value:
                    mapping[key] = value
            return mapping
        return dict(data or {})
    def _parse_tactical_deck_template(self, value: str) -> TacticalDeck:
        raw = str(value or "").strip()
        if not raw:
            return TacticalDeck()
        striker_abbreviations = self._tactical_abbreviation_map("striker")
        special_abbreviations = self._tactical_abbreviation_map("special")
        if "|" in raw:
            striker_raw, support_raw = raw.split("|", 1)
        else:
            striker_raw, support_raw = raw, ""

        compact_striker = "".join(striker_raw.split())
        compact_support = "".join(support_raw.split())
        has_striker_separator = any(separator in striker_raw for separator in ",/;")
        has_support_separator = any(separator in support_raw for separator in ",/;")
        exact_striker = self._tactical_student_ids_for_name(compact_striker)
        exact_support = self._tactical_student_ids_for_name(compact_support)
        compact_strikers = (
            compact_striker
            and not exact_striker
            and not has_striker_separator
            and 1 < len(compact_striker) <= TACTICAL_STRIKER_SLOTS
            and all(char in striker_abbreviations for char in compact_striker)
        )
        compact_supports = (
            compact_support
            and not exact_support
            and not has_support_separator
            and 1 < len(compact_support) <= TACTICAL_SUPPORT_SLOTS
            and all(char in special_abbreviations for char in compact_support)
        )
        deck = parse_deck_template(raw)
        deck.strikers = (
            [striker_abbreviations[char] for char in compact_striker]
            if compact_strikers
            else [striker_abbreviations.get(name, name) if len(name) == 1 else name for name in deck.strikers]
        )
        deck.supports = (
            [special_abbreviations[char] for char in compact_support]
            if compact_supports
            else [special_abbreviations.get(name, name) if len(name) == 1 else name for name in deck.supports]
        )
        return deck
    def _tactical_student_ids_for_name(self, name: str) -> list[str]:
        needle = self._tactical_lookup_key(name)
        if not needle:
            return []
        index = self._tactical_student_lookup_index_map()
        return list(index.get(needle, []))
    def _tactical_student_lookup_index_map(self) -> dict[str, list[str]]:
        cached = getattr(self, "_tactical_student_lookup_index", None)
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
                key = self._tactical_lookup_key(term)
                if key:
                    index[key].add(student_id)
        built = {
            key: sorted(values, key=lambda student_id: student_meta.display_name(student_id).casefold())
            for key, values in index.items()
        }
        self._tactical_student_lookup_index = built
        return built
    def _tactical_student_display_name(self, student_id: str) -> str:
        record = self._records_by_id.get(student_id)
        return record.title if record is not None else student_meta.display_name(student_id)
    def _canonical_tactical_deck_or_error(self, deck: TacticalDeck, label: str) -> tuple[TacticalDeck, str]:
        errors: list[str] = []

        def _is_empty_token(value: str) -> bool:
            key = self._tactical_import_key(value)
            return key in {"", "-", "?", "unknown", "none", "null", "na", "n/a", "알수없음", "미상"}

        def _resolve_slots(values: list[str], prefix: str, expected_class: str, expected_label: str) -> list[str]:
            resolved: list[str] = []
            for index, raw_name in enumerate(values, start=1):
                raw_name = str(raw_name or "").strip()
                if _is_empty_token(raw_name):
                    resolved.append("")
                    continue
                matches = self._tactical_student_ids_for_name(raw_name)
                if not matches:
                    errors.append(f"{label} {prefix}{index}: '{raw_name}' 학생을 인식할 수 없어 저장할 수 없습니다.")
                    resolved.append(raw_name)
                elif len(matches) > 1:
                    names = ", ".join(self._tactical_student_display_name(student_id) for student_id in matches[:6])
                    suffix = "..." if len(matches) > 6 else ""
                    errors.append(f"{label} {prefix}{index}: '{raw_name}' 중복 태그입니다. ({names}{suffix})")
                    resolved.append(raw_name)
                else:
                    student_id = matches[0]
                    if student_meta.combat_class(student_id) != expected_class:
                        errors.append(f"{label} {prefix}{index}: '{self._tactical_student_display_name(student_id)}'는 {expected_label} 자리에 배치할 수 없습니다.")
                    resolved.append(self._tactical_student_display_name(student_id))
            return resolved

        canonical = TacticalDeck(
            strikers=_resolve_slots(deck.strikers[:TACTICAL_STRIKER_SLOTS], "S", "striker", "스트라이커"),
            supports=_resolve_slots(deck.supports[:TACTICAL_SUPPORT_SLOTS], "SP", "special", "스페셜"),
        )
        return canonical, "\n".join(errors)
    def _canonical_tactical_search_deck_or_error(self, deck: TacticalDeck, label: str) -> tuple[TacticalDeck, str]:
        errors: list[str] = []

        def _resolve_slots(values: list[str], prefix: str, expected_class: str, expected_label: str) -> list[str]:
            resolved: list[str] = []
            for index, raw_name in enumerate(values, start=1):
                raw_name = str(raw_name or "").strip()
                if not raw_name:
                    resolved.append("")
                    continue
                if raw_name == "*":
                    resolved.append("*")
                    continue
                matches = self._tactical_student_ids_for_name(raw_name)
                if not matches:
                    errors.append(f"{label} {prefix}{index}: '{raw_name}' 학생을 인식할 수 없습니다.")
                    resolved.append(raw_name)
                elif len(matches) > 1:
                    names = ", ".join(self._tactical_student_display_name(student_id) for student_id in matches[:6])
                    suffix = "..." if len(matches) > 6 else ""
                    errors.append(f"{label} {prefix}{index}: '{raw_name}' 중복 태그입니다. ({names}{suffix})")
                    resolved.append(raw_name)
                else:
                    student_id = matches[0]
                    if student_meta.combat_class(student_id) != expected_class:
                        errors.append(f"{label} {prefix}{index}: '{self._tactical_student_display_name(student_id)}'는 {expected_label} 자리에 배치할 수 없습니다.")
                    resolved.append(self._tactical_student_display_name(student_id))
            return resolved

        canonical = TacticalDeck(
            strikers=_resolve_slots(deck.strikers[:TACTICAL_STRIKER_SLOTS], "S", "striker", "스트라이커"),
            supports=_resolve_slots(deck.supports[:TACTICAL_SUPPORT_SLOTS], "SP", "special", "스페셜"),
        )
        return canonical, "\n".join(errors)
    def _tactical_student_id_for_name(self, name: str) -> str | None:
        matches = self._tactical_student_ids_for_name(name)
        return matches[0] if len(matches) == 1 else None
    def _tactical_portrait_pixmap(self, name: str, size: int) -> QPixmap:
        student_id = self._tactical_student_id_for_name(name)
        if not student_id:
            return QPixmap()
        source = ensure_thumbnail(student_id, size, size)
        if source is None or not source.exists():
            return QPixmap()
        pixmap = QPixmap(str(source))
        return pixmap if not pixmap.isNull() else QPixmap()
    def _build_tactical_deck_editor(self, title: str) -> tuple[QWidget, TacticalDeckEditor]:
        editor = TacticalDeckEditor(
            title,
            card_asset=self._student_card_asset,
            ui_scale=self._ui_scale,
            icon_provider=self._tactical_portrait_pixmap,
            deck_parser=self._parse_tactical_deck_template,
        )
        return editor, editor
    def _deck_from_tactical_inputs(self, inputs) -> TacticalDeck:
        if isinstance(inputs, TacticalDeckEditor):
            return inputs.deck()
        return TacticalDeck(
            strikers=[edit.text().strip() for edit in inputs.get("strikers", []) if edit.text().strip()],
            supports=[edit.text().strip() for edit in inputs.get("supports", []) if edit.text().strip()],
        )
    def _set_tactical_deck_inputs(self, inputs, deck: TacticalDeck) -> None:
        if isinstance(inputs, TacticalDeckEditor):
            inputs.setDeck(deck)
            return
        for edits, values in ((inputs.get("strikers", []), deck.strikers), (inputs.get("supports", []), deck.supports)):
            for index, edit in enumerate(edits):
                edit.setText(values[index] if index < len(values) else "")
    def _clear_tactical_deck_inputs(self, inputs) -> None:
        if isinstance(inputs, TacticalDeckEditor):
            inputs.clearDeck()
            return
        for edit in inputs.get("strikers", []) + inputs.get("supports", []):
            edit.clear()
    def _save_tactical_data(self) -> None:
        self._show_busy_overlay()
        try:
            save_tactical_challenge(self._tactical_path, self._tactical_data, sync_matches=False)
            self._storage_mtimes = self._snapshot_storage_mtimes()
        finally:
            self._hide_busy_overlay()
    def _save_tactical_metadata(self) -> None:
        self._show_busy_overlay()
        try:
            save_tactical_metadata(
                self._tactical_path,
                season=self._tactical_data.season,
                abbreviations=self._tactical_data.abbreviations,
                special_abbreviations=self._tactical_data.special_abbreviations,
            )
            self._storage_mtimes = self._snapshot_storage_mtimes()
        finally:
            self._hide_busy_overlay()
    def _save_tactical_match(self) -> None:
        if self._tactical_match_panels:
            self._save_tactical_match_panel(self._tactical_match_panels[0])
    def _save_tactical_jokbo(self) -> None:
        if not self._tactical_match_panels:
            return
        panel = self._tactical_match_panels[0]
        self._set_tactical_panel_mode(panel, "jokbo")
        self._save_tactical_match_panel(panel)
    def _clear_tactical_match_form(self) -> None:
        for panel in self._tactical_match_panels:
            self._clear_tactical_match_panel(panel)
    def _copy_tactical_match_defense_to_jokbo(self) -> None:
        deck = TacticalDeck()
        for panel in self._tactical_match_panels:
            candidate = self._deck_from_tactical_inputs(panel["defense"])
            if candidate.strikers or candidate.supports:
                deck = candidate
                break
        if self._tactical_match_panels:
            self._set_tactical_deck_inputs(self._tactical_match_panels[0]["defense"], deck)
        self._set_tactical_deck_inputs(self._tactical_jokbo_search_inputs, deck)
    def _selected_tactical_match(self) -> TacticalMatch | None:
        selected_id = self._tactical_selected_match_id
        if not selected_id and hasattr(self, "_tactical_match_list"):
            item = self._tactical_match_list.currentItem()
            selected_id = str(item.data(Qt.UserRole) or "") if item is not None else ""
        if not selected_id:
            return None
        return get_tactical_match(self._tactical_path, selected_id)
    def _tactical_date_label(self, match: TacticalMatch) -> str:
        return match.date or "날짜 없음"
    def _copy_selected_tactical_defense_to_search(self) -> None:
        match = self._selected_tactical_match()
        if match is None:
            return
        deck = match.opponent_defense if (match.opponent_defense.strikers or match.opponent_defense.supports) else match.my_defense
        self._set_tactical_deck_inputs(self._tactical_jokbo_search_inputs, deck)
        self._refresh_tactical_jokbo_results()
    def _refresh_tactical_tab(self) -> None:
        if not hasattr(self, "_tactical_match_list"):
            return
        if hasattr(self, "_tactical_season") and not self._tactical_season.hasFocus():
            previous = self._tactical_season.blockSignals(True)
            try:
                self._tactical_season.setText(self._tactical_data.season or "")
            finally:
                self._tactical_season.blockSignals(previous)
        self._refresh_tactical_match_list()
        self._refresh_tactical_opponent_report()
        self._refresh_tactical_jokbo_results()
    def _blank_tactical_opponent_matches(self) -> list[TacticalMatch]:
        total = tactical_match_count(self._tactical_path, "")
        matches = query_tactical_matches(self._tactical_path, "", limit=max(total, self._tactical_match_page_size))
        return [match for match in matches if not match.opponent.strip()]
    def _edit_tactical_opponents_batch(self) -> None:
        matches = self._blank_tactical_opponent_matches()
        if not matches:
            QMessageBox.information(self, "BA Planner", "상대 이름이 비어 있는 전술대항전 기록이 없습니다.")
            return
        self._open_tactical_opponents_batch(matches)
    def _open_tactical_opponents_batch(self, matches: list[TacticalMatch], panel: dict | None = None) -> None:
        rows = [match for match in matches if match is not None]
        if not rows:
            return
        dialog = TacticalOpponentBatchDialog(self, rows, self._ui_scale)
        if dialog.exec() != QDialog.Accepted:
            return
        updated = dialog.edited_matches()
        if not updated:
            return
        upsert_tactical_matches(self._tactical_path, updated)
        self._storage_mtimes = self._snapshot_storage_mtimes()
        self._tactical_match_loaded_count = max(self._tactical_match_loaded_count, self._tactical_match_page_size)
        if updated:
            self._tactical_selected_match_id = updated[-1].id
        self._refresh_tactical_match_list()
        self._refresh_tactical_opponent_report()
        self._refresh_tactical_jokbo_results()
        self._set_tactical_status(f"상대 이름 {len(updated)}건을 저장했습니다.", panel=panel)
    def _reset_tactical_match_list(self) -> None:
        self._tactical_match_loaded_count = self._tactical_match_page_size
        self._refresh_tactical_match_list()
    def _load_more_tactical_matches(self) -> None:
        self._show_busy_overlay("불러오는 중...")
        try:
            self._tactical_match_loaded_count += self._tactical_match_page_size
            self._refresh_tactical_match_list()
        finally:
            self._hide_busy_overlay()
    def _refresh_tactical_match_list(self) -> None:
        query = self._tactical_match_search.text() if hasattr(self, "_tactical_match_search") else ""
        if query != self._tactical_match_query:
            self._tactical_match_query = query
            self._tactical_match_loaded_count = self._tactical_match_page_size
        total_filtered = tactical_match_count(self._tactical_path, query)
        matches = query_tactical_matches(self._tactical_path, query, limit=self._tactical_match_loaded_count)
        current_id = self._tactical_selected_match_id
        editing_ids = self._tactical_match_editing_ids()
        self._tactical_match_list.blockSignals(True)
        self._tactical_match_list.clear()
        for match in matches:
            result_text = "승" if match.result == "win" else "패"
            season_text = f" · {match.season}" if match.season else ""
            source_label = self._tactical_match_source_label(match.source)
            source_text = f" · {source_label}" if source_label else ""
            is_editing = match.id in editing_ids
            item = QListWidgetItem()
            item.setData(Qt.UserRole, match.id)
            item.setToolTip(self._tactical_match_tooltip(match))
            self._tactical_match_list.addItem(item)
            row = QFrame()
            row.setObjectName("planBand")
            if is_editing:
                row.setStyleSheet(
                    f"QFrame#planBand {{ border: 2px solid #ffb5f0; background: {_mix_hex(ACCENT_SOFT, '#ffffff', 0.08)}; }}"
                )
            row_layout = QVBoxLayout(row)
            row_layout.setContentsMargins(scale_px(8, self._ui_scale), scale_px(7, self._ui_scale), scale_px(8, self._ui_scale), scale_px(7, self._ui_scale))
            top_row = QHBoxLayout()
            text = QLabel(f"{self._tactical_date_label(match)}{season_text}{source_text}  [{result_text}] {match.opponent}")
            text.setWordWrap(True)
            text.setObjectName("sectionTitle")
            top_row.addWidget(text, 1)
            if is_editing:
                editing_badge = QLabel("수정 중")
                editing_badge.setStyleSheet(
                    "color: #ffb5f0; font-weight: 900; padding: 2px 6px; border: 1px solid #ffb5f0; border-radius: 4px;"
                )
                top_row.addWidget(editing_badge)
            row_layout.addLayout(top_row)
            deck_row = QHBoxLayout()
            deck_row.setContentsMargins(0, 0, 0, 0)
            deck_row.setSpacing(scale_px(6, self._ui_scale))
            attack_deck = match.my_attack if (match.my_attack.strikers or match.my_attack.supports) else match.opponent_attack
            defense_deck = match.opponent_defense if (match.opponent_defense.strikers or match.opponent_defense.supports) else match.my_defense
            attack_label = "ATK" if (match.my_attack.strikers or match.my_attack.supports) else "OP ATK"
            defense_label = "DEF" if (match.opponent_defense.strikers or match.opponent_defense.supports) else "MY DEF"
            attack_preview = TacticalDeckPreview(card_asset=self._student_card_asset, ui_scale=self._ui_scale, icon_provider=self._tactical_portrait_pixmap, compact=True)
            attack_preview.setDeck(attack_deck)
            defense_preview = TacticalDeckPreview(card_asset=self._student_card_asset, ui_scale=self._ui_scale, icon_provider=self._tactical_portrait_pixmap, compact=True)
            defense_preview.setDeck(defense_deck)
            deck_row.addWidget(QLabel(attack_label))
            deck_row.addWidget(attack_preview)
            deck_row.addStretch(1)
            deck_row.addWidget(QLabel(defense_label))
            deck_row.addWidget(defense_preview)
            row_layout.addLayout(deck_row)
            hint = row.sizeHint()
            hint.setHeight(hint.height() + scale_px(8, self._ui_scale))
            item.setSizeHint(hint)
            self._tactical_match_list.setItemWidget(item, row)
            if current_id and match.id == current_id:
                self._tactical_match_list.setCurrentItem(item)
        self._tactical_match_list.blockSignals(False)
        summary = tactical_match_summary(self._tactical_path, self._tactical_date.text().strip())
        self._tactical_match_summary.setText(
            f"오늘 {summary['today']}/5 · 전체 {summary['wins']}승 {summary['losses']}패 · 표시 {len(matches)}/{total_filtered}"
        )
        if hasattr(self, "_tactical_match_load_more_button"):
            self._tactical_match_load_more_button.setVisible(len(matches) < total_filtered)
        self._set_tactical_match_detail(self._selected_tactical_match())
    def _delete_tactical_match(self, match_id: str) -> None:
        self._show_busy_overlay("삭제 중...")
        try:
            if not delete_tactical_match(self._tactical_path, match_id):
                return
            if self._tactical_selected_match_id == match_id:
                self._tactical_selected_match_id = None
            for panel in getattr(self, "_tactical_match_panels", []):
                if panel.get("editing_match_id") == match_id:
                    self._clear_tactical_match_panel(panel)
            self._storage_mtimes = self._snapshot_storage_mtimes()
            self._refresh_tactical_match_list()
        finally:
            self._hide_busy_overlay()
        self._set_tactical_status("전적을 삭제했습니다.")
    def _selected_tactical_match_decks(self) -> tuple[TacticalDeck, TacticalDeck] | None:
        match = self._selected_tactical_match()
        if match is None:
            return None
        attack_deck = match.my_attack if (match.my_attack.strikers or match.my_attack.supports) else match.opponent_attack
        defense_deck = match.opponent_defense if (match.opponent_defense.strikers or match.opponent_defense.supports) else match.my_defense
        return attack_deck, defense_deck
    def _copy_selected_tactical_match_attack(self) -> None:
        decks = self._selected_tactical_match_decks()
        if decks is not None:
            self._copy_tactical_deck_template(decks[0])
    def _copy_selected_tactical_match_defense(self) -> None:
        decks = self._selected_tactical_match_decks()
        if decks is not None:
            self._copy_tactical_deck_template(decks[1])
    def _edit_selected_tactical_match(self) -> None:
        match = self._selected_tactical_match()
        if match is None:
            self._set_tactical_status("수정할 전적을 먼저 선택해 주세요.", error=True)
            return
        if not self._tactical_match_panels:
            return
        self._load_tactical_match_into_panel(self._tactical_match_panels[0], match)
    def _delete_selected_tactical_match(self) -> None:
        match = self._selected_tactical_match()
        if match is not None:
            self._delete_tactical_match(match.id)
    def _tactical_match_tooltip(self, match: TacticalMatch) -> str:
        lines = [
            f"{self._tactical_date_label(match)} {match.season} {match.opponent}".strip(),
            f"내 공격덱: {deck_label(match.my_attack)}",
            f"상대 방어덱: {deck_label(match.opponent_defense)}",
        ]
        source_label = self._tactical_match_source_label(match.source)
        if source_label:
            lines.insert(1, f"출처: {source_label}")
        if deck_label(match.my_defense, empty=""):
            lines.append(f"내 방어덱: {deck_label(match.my_defense)}")
        if deck_label(match.opponent_attack, empty=""):
            lines.append(f"상대 공격덱: {deck_label(match.opponent_attack)}")
        if match.notes:
            lines.append(match.notes)
        return "\n".join(lines)
    def _on_tactical_match_selected(self, current: QListWidgetItem | None, _previous: QListWidgetItem | None) -> None:
        self._tactical_selected_match_id = str(current.data(Qt.UserRole) or "") if current is not None else None
        match = self._selected_tactical_match()
        if match is not None:
            self._tactical_opponent_search.setText(match.opponent)
            deck = match.opponent_defense if (match.opponent_defense.strikers or match.opponent_defense.supports) else match.my_defense
            self._set_tactical_deck_inputs(self._tactical_jokbo_search_inputs, deck)
        self._set_tactical_match_detail(match)
        self._refresh_tactical_opponent_report()
        self._refresh_tactical_jokbo_results()
    def _set_tactical_match_detail(self, match: TacticalMatch | None) -> None:
        if not hasattr(self, "_tactical_match_detail"):
            return
        if match is None:
            self._tactical_match_detail.setText("선택한 전적의 상세 정보가 여기에 표시됩니다.")
            return
        result_text = "승리" if match.result == "win" else "패배"
        header_parts = [self._tactical_date_label(match), match.season or "-"]
        source_label = self._tactical_match_source_label(match.source)
        if source_label:
            header_parts.append(source_label)
        header_parts.extend([match.opponent, result_text])
        lines = [
            " · ".join(header_parts),
            f"내 공격덱: {deck_label(match.my_attack)}",
            f"상대 방어덱: {deck_label(match.opponent_defense)}",
        ]
        if deck_label(match.my_defense, empty=""):
            lines.append(f"내 방어덱: {deck_label(match.my_defense)}")
        if deck_label(match.opponent_attack, empty=""):
            lines.append(f"상대 공격덱: {deck_label(match.opponent_attack)}")
        if match.notes:
            lines.append(f"메모: {match.notes}")
        self._tactical_match_detail.setText("\n".join(lines))
    def _refresh_tactical_opponent_report(self) -> None:
        if not hasattr(self, "_tactical_opponent_summary"):
            return
        opponent = self._tactical_opponent_search.text().strip()
        if not opponent:
            match = self._selected_tactical_match()
            opponent = match.opponent if match is not None else ""
        if not opponent:
            self._tactical_opponent_summary.setText("상대를 검색하거나 전적을 선택하면 상대전적과 최근 방어덱이 표시됩니다.")
            self._tactical_opponent_top_list.clear()
            return
        report = opponent_report_from_storage(self._tactical_path, opponent)
        total = len(report["matches"])
        self._tactical_opponent_top_list.clear()
        if total == 0:
            self._tactical_opponent_summary.setText(f"{opponent}: 기록이 없습니다.")
            return
        self._tactical_opponent_summary.setText(
            f"{opponent}: {report['wins']}승 {report['losses']}패 ({report['win_rate']:.1f}%)"
        )
        if deck_label(report["recent_defense"], empty=""):
            self._add_tactical_opponent_deck_row(
                title="최근 방어덱",
                defense=report["recent_defense"],
                attack=report["recent_attack"],
            )
        for index, entry in enumerate(report["top_defenses"], start=1):
            self._add_tactical_opponent_deck_row(
                title=f"TOP {index} · {entry['count']}회 · {entry['wins']}승 {entry['losses']}패 ({entry['win_rate']:.1f}%)",
                defense=entry["deck"],
                attack=entry["attack"],
            )
        if not report["top_defenses"]:
            self._tactical_opponent_top_list.addItem("방어덱 정보가 있는 전적이 없습니다.")
    def _add_tactical_opponent_deck_row(self, *, title: str, defense: TacticalDeck, attack: TacticalDeck) -> None:
        item = QListWidgetItem()
        item.setToolTip(f"공격: {deck_label(attack)}\n방어: {deck_label(defense)}")
        row = QFrame()
        row.setObjectName("planBand")
        layout = QVBoxLayout(row)
        layout.setContentsMargins(scale_px(8, self._ui_scale), scale_px(7, self._ui_scale), scale_px(8, self._ui_scale), scale_px(7, self._ui_scale))
        label = QLabel(title)
        label.setObjectName("sectionTitle")
        label.setWordWrap(True)
        layout.addWidget(label)
        deck_row = QHBoxLayout()
        deck_row.setContentsMargins(0, 0, 0, 0)
        deck_row.setSpacing(scale_px(6, self._ui_scale))
        attack_preview = TacticalDeckPreview(card_asset=self._student_card_asset, ui_scale=self._ui_scale, icon_provider=self._tactical_portrait_pixmap, compact=True)
        attack_preview.setDeck(attack)
        defense_preview = TacticalDeckPreview(card_asset=self._student_card_asset, ui_scale=self._ui_scale, icon_provider=self._tactical_portrait_pixmap, compact=True)
        defense_preview.setDeck(defense)
        deck_row.addWidget(QLabel("ATK"))
        deck_row.addWidget(attack_preview)
        deck_row.addStretch(1)
        deck_row.addWidget(QLabel("DEF"))
        deck_row.addWidget(defense_preview)
        layout.addLayout(deck_row)
        self._tactical_opponent_top_list.addItem(item)
        hint = row.sizeHint()
        hint.setHeight(hint.height() + scale_px(8, self._ui_scale))
        item.setSizeHint(hint)
        self._tactical_opponent_top_list.setItemWidget(item, row)
    def _refresh_tactical_jokbo_results(self) -> None:
        if not hasattr(self, "_tactical_jokbo_results"):
            return
        defense = self._deck_from_tactical_inputs(self._tactical_jokbo_search_inputs)
        if not any(defense.strikers) and not any(defense.supports):
            self._tactical_jokbo_results.clear()
            self._tactical_jokbo_results.addItem("방어덱을 입력하거나 전적을 선택하면 족보를 검색합니다.")
            return
        defense, error = self._canonical_tactical_search_deck_or_error(defense, "족보 검색 방어덱")
        if error:
            self._tactical_jokbo_results.clear()
            item = QListWidgetItem(self._compact_tactical_message(error, max_lines=2, max_chars=130))
            item.setToolTip(error)
            self._tactical_jokbo_results.addItem(item)
            self._set_tactical_status(error, error=True)
            return
        self._set_tactical_deck_inputs(self._tactical_jokbo_search_inputs, defense)
        results = search_jokbo_from_storage(self._tactical_path, self._tactical_data, defense)
        self._tactical_jokbo_results.clear()
        for result in results["manual"]:
            entry = result["entry"]
            self._add_tactical_jokbo_result_row(
                title=f"족보 · {result['wins']}승 {result['losses']}패 ({result['win_rate']:.1f}%)",
                defense=entry.defense,
                attack=entry.attack,
                note=entry.notes or "-",
            )
        for result in results["observed"]:
            self._add_tactical_jokbo_result_row(
                title=f"전적 기반 · {result['wins']}승 {result['losses']}패 ({result['win_rate']:.1f}%)",
                defense=result["defense"],
                attack=result["attack"],
                note="",
            )
        if self._tactical_jokbo_results.count() == 0:
            self._tactical_jokbo_results.addItem("일치하는 족보나 전적 기반 공격덱이 없습니다.")
    def _add_tactical_jokbo_result_row(self, *, title: str, defense: TacticalDeck, attack: TacticalDeck, note: str) -> None:
        item = QListWidgetItem()
        item.setData(Qt.UserRole, deck_template(defense))
        item.setData(Qt.UserRole + 1, deck_template(attack))
        row = QFrame()
        row.setObjectName("planBand")
        layout = QVBoxLayout(row)
        layout.setContentsMargins(scale_px(8, self._ui_scale), scale_px(7, self._ui_scale), scale_px(8, self._ui_scale), scale_px(7, self._ui_scale))
        label = QLabel(title)
        label.setObjectName("sectionTitle")
        if note:
            label.setToolTip(note)
        layout.addWidget(label)
        decks = QHBoxLayout()
        decks.setContentsMargins(0, 0, 0, 0)
        decks.setSpacing(scale_px(6, self._ui_scale))
        defense_preview = TacticalDeckPreview(card_asset=self._student_card_asset, ui_scale=self._ui_scale, icon_provider=self._tactical_portrait_pixmap, compact=True)
        defense_preview.setDeck(defense)
        attack_preview = TacticalDeckPreview(card_asset=self._student_card_asset, ui_scale=self._ui_scale, icon_provider=self._tactical_portrait_pixmap, compact=True)
        attack_preview.setDeck(attack)
        decks.addWidget(QLabel("ATK"))
        decks.addWidget(attack_preview)
        decks.addStretch(1)
        decks.addWidget(QLabel("DEF"))
        decks.addWidget(defense_preview)
        layout.addLayout(decks)
        self._tactical_jokbo_results.addItem(item)
        hint = row.sizeHint()
        hint.setHeight(hint.height() + scale_px(8, self._ui_scale))
        item.setSizeHint(hint)
        self._tactical_jokbo_results.setItemWidget(item, row)
    def _selected_tactical_jokbo_decks(self) -> tuple[TacticalDeck, TacticalDeck] | None:
        if not hasattr(self, "_tactical_jokbo_results"):
            return None
        item = self._tactical_jokbo_results.currentItem()
        if item is None:
            return None
        defense_text = str(item.data(Qt.UserRole) or "")
        attack_text = str(item.data(Qt.UserRole + 1) or "")
        if not defense_text and not attack_text:
            return None
        return parse_deck_template(defense_text), parse_deck_template(attack_text)
    def _copy_selected_tactical_jokbo_defense(self) -> None:
        decks = self._selected_tactical_jokbo_decks()
        if decks is not None:
            self._copy_tactical_deck_template(decks[0])
    def _copy_selected_tactical_jokbo_attack(self) -> None:
        decks = self._selected_tactical_jokbo_decks()
        if decks is not None:
            self._copy_tactical_deck_template(decks[1])
    def _copy_tactical_deck_template(self, deck: TacticalDeck) -> None:
        QApplication.clipboard().setText(deck_input_template(deck))
        if hasattr(self, "_tactical_status"):
            self._set_tactical_status("덱 템플릿을 복사했습니다.")
    def _tactical_match_editing_ids(self) -> set[str]:
        return {
            str(panel.get("editing_match_id") or "")
            for panel in getattr(self, "_tactical_match_panels", [])
            if str(panel.get("editing_match_id") or "")
        }
    def _tactical_match_source_label(self, source: str) -> str:
        source = str(source or "").strip()
        return "" if source in {"", "내 기록", "스크린샷"} else source
