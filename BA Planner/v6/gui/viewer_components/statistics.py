"""StatisticsTabComponent implementation extracted from the viewer façade."""

from __future__ import annotations

from gui import viewer_shared as _viewer_shared

globals().update({name: value for name, value in vars(_viewer_shared).items() if not name.startswith("__")})


class StatisticsTabComponent:
    def _build_stats_tab(self, root: QWidget) -> None:
        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(scale_px(12, self._ui_scale))

        scroll = QScrollArea()
        scroll.setObjectName("sectionScrollArea")
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        host = QWidget()
        host_layout = QVBoxLayout(host)
        host_layout.setContentsMargins(0, 0, 0, 0)
        host_layout.setSpacing(scale_px(12, self._ui_scale))

        self._stats_summary_host = QWidget()
        self._stats_summary_cards = QGridLayout(self._stats_summary_host)
        self._stats_summary_cards.setContentsMargins(0, 0, 0, 0)
        self._stats_summary_cards.setHorizontalSpacing(scale_px(12, self._ui_scale))
        self._stats_summary_cards.setVerticalSpacing(scale_px(12, self._ui_scale))
        host_layout.addWidget(self._stats_summary_host)

        middle_row = QHBoxLayout()
        middle_row.setContentsMargins(0, 0, 0, 0)
        middle_row.setSpacing(scale_px(12, self._ui_scale))

        sunburst_panel = QFrame()
        sunburst_panel.setObjectName("planSectionPanel")
        sunburst_layout = QVBoxLayout(sunburst_panel)
        sunburst_layout.setContentsMargins(
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
        )
        sunburst_layout.setSpacing(scale_px(12, self._ui_scale))

        sunburst_header = QHBoxLayout()
        sunburst_header.setContentsMargins(0, 0, 0, 0)
        sunburst_header.setSpacing(scale_px(10, self._ui_scale))
        sunburst_title = QLabel("분포 탐색")
        sunburst_title.setObjectName("sectionTitle")
        sunburst_header.addWidget(sunburst_title)
        sunburst_header.addStretch(1)
        self._stats_sunburst_mode = InventorySortDropdownButton()
        self._stats_sunburst_mode.addItem("학교 > 역할 > 공격 타입", "collection_school_role_attack")
        self._stats_sunburst_mode.addItem("Striker/Special > 역할 > 포지션", "collection_class_role_position")
        self._stats_sunburst_mode.addItem("공격 타입 > 방어 타입 > 역할", "collection_attack_defense_role")
        self._stats_sunburst_mode.addItem("직군 > 육성도", "role_training")
        self._stats_sunburst_mode.addItem("필요 재화 > 세부 재화 > 티어/계열", "plan_required")
        self._stats_sunburst_mode.addItem("부족 재화 > 세부 재화 > 영향 학생", "plan_shortage")
        self._stats_sunburst_mode.addItem("기능군 > 태그 > 학생", "skill_function")
        self._stats_sunburst_mode.setCurrentIndex(4)
        self._stats_sunburst_mode.modeChanged.connect(lambda *_: self._stats_refresh_sunburst_mode())
        sunburst_header.addWidget(self._stats_sunburst_mode, 0, Qt.AlignRight)
        self._stats_sunburst_value_mode = InventorySortDropdownButton()
        self._stats_sunburst_value_mode.modeChanged.connect(lambda *_: self._stats_refresh_sunburst_mode())
        sunburst_header.addWidget(self._stats_sunburst_value_mode, 0, Qt.AlignRight)
        nav_buttons = QWidget()
        nav_buttons.setObjectName("planTransparent")
        nav_layout = QHBoxLayout(nav_buttons)
        nav_layout.setContentsMargins(0, 0, 0, 0)
        nav_layout.setSpacing(scale_px(6, self._ui_scale))
        self._stats_sunburst_root_button = QPushButton("전체")
        self._stats_sunburst_root_button.clicked.connect(self._stats_reset_sunburst_root)
        nav_layout.addWidget(self._stats_sunburst_root_button)
        self._stats_sunburst_back_button = QPushButton("뒤로")
        self._stats_sunburst_back_button.clicked.connect(self._stats_sunburst_back)
        nav_layout.addWidget(self._stats_sunburst_back_button)
        self._stats_sunburst_clear_button = QPushButton("선택 해제")
        self._stats_sunburst_clear_button.clicked.connect(self._stats_clear_sunburst_selection)
        nav_layout.addWidget(self._stats_sunburst_clear_button)
        sunburst_header.addWidget(nav_buttons, 0, Qt.AlignRight)
        sunburst_layout.addLayout(sunburst_header)
        self._stats_sunburst_breadcrumb_host = QWidget()
        self._stats_sunburst_breadcrumb_layout = QHBoxLayout(self._stats_sunburst_breadcrumb_host)
        self._stats_sunburst_breadcrumb_layout.setContentsMargins(0, 0, 0, 0)
        self._stats_sunburst_breadcrumb_layout.setSpacing(scale_px(6, self._ui_scale))
        self._stats_update_sunburst_value_options()

        chart_and_legend = QHBoxLayout()
        chart_and_legend.setContentsMargins(0, 0, 0, 0)
        chart_and_legend.setSpacing(scale_px(12, self._ui_scale))
        self._stats_sunburst = SunburstWidget(self._ui_scale)
        self._stats_sunburst.segmentSelected.connect(self._on_stats_sunburst_segment_selected)
        chart_and_legend.addWidget(self._stats_sunburst, 1)
        legend_panel = QFrame()
        legend_panel.setObjectName("planBand")
        legend_panel.setFixedWidth(scale_px(210, self._ui_scale))
        legend_layout = QVBoxLayout(legend_panel)
        legend_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        legend_layout.setSpacing(scale_px(6, self._ui_scale))
        legend_title = QLabel("색상 경로")
        legend_title.setObjectName("detailSectionTitle")
        legend_layout.addWidget(legend_title)
        self._stats_sunburst_legend_layout = QVBoxLayout()
        self._stats_sunburst_legend_layout.setContentsMargins(0, 0, 0, 0)
        self._stats_sunburst_legend_layout.setSpacing(scale_px(4, self._ui_scale))
        legend_layout.addLayout(self._stats_sunburst_legend_layout)
        legend_layout.addStretch(1)
        chart_and_legend.addWidget(legend_panel, 0)
        sunburst_layout.addLayout(chart_and_legend, 1)
        self._stats_summary_line = QLabel("")
        self._stats_summary_line.setObjectName("filterSummary")
        sunburst_layout.addWidget(self._stats_summary_line)
        middle_row.addWidget(sunburst_panel, 3)

        detail_panel = QFrame()
        detail_panel.setObjectName("planSectionPanel")
        detail_layout = QVBoxLayout(detail_panel)
        detail_layout.setContentsMargins(
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
        )
        detail_layout.setSpacing(scale_px(8, self._ui_scale))
        selected_title = QLabel("선택 상세 정보")
        selected_title.setObjectName("sectionTitle")
        detail_layout.addWidget(selected_title)

        path_caption = QLabel("선택 경로")
        path_caption.setObjectName("detailSub")
        detail_layout.addWidget(path_caption)
        self._stats_detail_path_label = QLabel("L0: 전체")
        self._stats_detail_path_label.setObjectName("filterSummary")
        detail_layout.addWidget(self._stats_detail_path_label, 0, Qt.AlignLeft)

        divider = QFrame()
        divider.setFrameShape(QFrame.HLine)
        divider.setObjectName("sectionDivider")
        detail_layout.addWidget(divider)

        title_row = QHBoxLayout()
        title_row.setContentsMargins(0, 0, 0, 0)
        title_stack = QVBoxLayout()
        title_stack.setContentsMargins(0, 0, 0, 0)
        title_stack.setSpacing(0)
        self._stats_detail_name_label = QLabel("전체")
        self._stats_detail_name_label.setObjectName("detailSectionTitle")
        self._stats_detail_level_label = QLabel("Level 0")
        self._stats_detail_level_label.setObjectName("detailSub")
        title_stack.addWidget(self._stats_detail_name_label)
        title_stack.addWidget(self._stats_detail_level_label)
        title_row.addLayout(title_stack, 1)
        self._stats_detail_total_label = QLabel("0")
        self._stats_detail_total_label.setObjectName("metricValue")
        self._stats_detail_total_label.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        title_row.addWidget(self._stats_detail_total_label, 0)
        detail_layout.addLayout(title_row)

        metric_row = QHBoxLayout()
        metric_row.setContentsMargins(0, 0, 0, 0)
        metric_row.setSpacing(scale_px(8, self._ui_scale))
        count_card = QFrame()
        count_card.setObjectName("statPanel")
        count_layout = QVBoxLayout(count_card)
        count_layout.setContentsMargins(scale_px(10, self._ui_scale), scale_px(8, self._ui_scale), scale_px(10, self._ui_scale), scale_px(8, self._ui_scale))
        count_title = QLabel("학생 수")
        count_title.setObjectName("detailSub")
        self._stats_detail_metric_count_label = QLabel("0")
        self._stats_detail_metric_count_label.setObjectName("kpiValueSub")
        count_layout.addWidget(count_title)
        count_layout.addWidget(self._stats_detail_metric_count_label)
        metric_row.addWidget(count_card, 1)
        percent_card = QFrame()
        percent_card.setObjectName("statPanel")
        percent_layout = QVBoxLayout(percent_card)
        percent_layout.setContentsMargins(scale_px(10, self._ui_scale), scale_px(8, self._ui_scale), scale_px(10, self._ui_scale), scale_px(8, self._ui_scale))
        percent_title = QLabel("비율")
        percent_title.setObjectName("detailSub")
        self._stats_detail_metric_percent_label = QLabel("0.0%")
        self._stats_detail_metric_percent_label.setObjectName("kpiValueSub")
        percent_layout.addWidget(percent_title)
        percent_layout.addWidget(self._stats_detail_metric_percent_label)
        metric_row.addWidget(percent_card, 1)
        detail_layout.addLayout(metric_row)

        owned_label_row = QHBoxLayout()
        owned_label_row.setContentsMargins(0, 0, 0, 0)
        owned_title = QLabel("보유율")
        owned_title.setObjectName("detailSub")
        owned_label_row.addWidget(owned_title)
        self._stats_detail_owned_bar_label = QLabel("0.0%")
        self._stats_detail_owned_bar_label.setObjectName("detailSub")
        self._stats_detail_owned_bar_label.setAlignment(Qt.AlignRight)
        owned_label_row.addWidget(self._stats_detail_owned_bar_label)
        detail_layout.addLayout(owned_label_row)
        self._stats_detail_owned_bar = QProgressBar()
        self._stats_detail_owned_bar.setRange(0, 100)
        self._stats_detail_owned_bar.setTextVisible(False)
        self._stats_detail_owned_bar.setFixedHeight(scale_px(8, self._ui_scale))
        detail_layout.addWidget(self._stats_detail_owned_bar)

        chip_row = QHBoxLayout()
        chip_row.setContentsMargins(0, 0, 0, 0)
        chip_row.setSpacing(scale_px(8, self._ui_scale))
        self._stats_detail_owned_label = QLabel("보유\n0")
        self._stats_detail_unowned_label = QLabel("미보유\n0")
        self._stats_detail_planned_label = QLabel("계획\n0")
        for chip in (self._stats_detail_owned_label, self._stats_detail_unowned_label, self._stats_detail_planned_label):
            chip.setObjectName("filterSummary")
            chip.setAlignment(Qt.AlignCenter)
            chip.setMinimumHeight(scale_px(48, self._ui_scale))
            chip_row.addWidget(chip, 1)
        detail_layout.addLayout(chip_row)

        self._stats_sunburst_top_detail = QLabel("")
        self._stats_sunburst_top_detail.hide()
        self._stats_sunburst_detail = QLabel("")
        self._stats_sunburst_detail.hide()
        detail_layout.addStretch(1)
        middle_row.addWidget(detail_panel, 2)
        host_layout.addLayout(middle_row, 1)

        self._stats_chart_tabs = QTabBar()
        self._stats_chart_tabs.setObjectName("inventorySubTabBar")
        for label, value in (
            ("컬렉션 구성", "collection"),
            ("육성 상태", "growth"),
            ("계획 진행", "plan"),
            ("재화/인벤토리", "resource"),
            ("스킬/기능 태그", "skill"),
        ):
            index = self._stats_chart_tabs.addTab(label)
            self._stats_chart_tabs.setTabData(index, value)
        self._stats_chart_tabs.currentChanged.connect(self._stats_chart_tab_changed)
        host_layout.addWidget(self._stats_chart_tabs)
        self._stats_chart_tabs.hide()

        cards_wrap = QWidget()
        self._stats_cards_layout = QGridLayout(cards_wrap)
        self._stats_cards_layout.setContentsMargins(0, 0, 0, 0)
        self._stats_cards_layout.setHorizontalSpacing(scale_px(12, self._ui_scale))
        self._stats_cards_layout.setVerticalSpacing(scale_px(12, self._ui_scale))
        self._stats_cards_layout.setColumnStretch(0, 1)
        host_layout.addWidget(cards_wrap)
        cards_wrap.hide()
        scroll.setWidget(host)
        layout.addWidget(scroll, 1)
    def _stats_set_mode(self, attr_name: str, value: str) -> None:
        if getattr(self, attr_name, None) == value:
            return
        setattr(self, attr_name, value)
        self._refresh_stats_tab()
    def _stats_chart_tab_changed(self, index: int) -> None:
        if self._stats_chart_tabs is None:
            return
        value = self._stats_chart_tabs.tabData(index)
        next_tab = str(value or "collection")
        if self._stats_active_chart_tab == next_tab:
            return
        self._stats_active_chart_tab = next_tab
        self._refresh_stats_tab()
    def _stats_refresh_sunburst_mode(self) -> None:
        self._stats_update_sunburst_value_options()
        self._stats_sunburst_selected_path = ()
        self._stats_sunburst_breadcrumb_path = ()
        self._stats_sunburst_selected_context = {}
        self._stats_sunburst_selected_node = None
        self._stats_sunburst_drill_stack.clear()
        self._refresh_stats_tab()
    def _stats_reset_sunburst_root(self) -> None:
        self._stats_sunburst_selected_path = ()
        self._stats_sunburst_breadcrumb_path = ()
        self._stats_sunburst_selected_context = {}
        self._stats_sunburst_selected_node = None
        self._stats_sunburst_drill_stack.clear()
        self._refresh_stats_tab()
    def _stats_clear_sunburst_selection(self) -> None:
        current_path = self._stats_sunburst_breadcrumb_path
        self._stats_sunburst_selected_path = ()
        self._stats_sunburst_selected_context = {}
        self._stats_sunburst_selected_node = None
        if current_path:
            self._stats_sunburst_breadcrumb_path = current_path
        self._refresh_stats_tab()
    def _stats_sunburst_back(self) -> None:
        if not self._stats_sunburst_drill_stack:
            self._stats_reset_sunburst_root()
            return
        previous_path = self._stats_sunburst_drill_stack.pop()
        self._stats_apply_sunburst_path(previous_path, push_current=False)
    def _on_stats_sunburst_segment_selected(self, payload: object) -> None:
        if not isinstance(payload, dict) or not payload:
            self._stats_clear_sunburst_selection()
            return
        path = tuple(str(part) for part in payload.get("path", ()) if str(part))
        self._stats_apply_sunburst_path(path, push_current=True)
    def _stats_current_sunburst_mode(self) -> str:
        value = self._stats_sunburst_mode.currentData() if self._stats_sunburst_mode is not None else None
        return str(value or "collection_school_role_attack")
    def _stats_update_sunburst_value_options(self) -> None:
        if self._stats_sunburst_value_mode is None:
            return
        mode = self._stats_current_sunburst_mode()
        if mode == "role_training":
            options = (("직군 평균 육성도", "training_avg"), ("학생 수", "student_count"), ("보유 학생만", "owned_count"))
            default = "training_avg"
        elif mode.startswith("collection_") or mode == "skill_function":
            options = (("학생 수", "student_count"), ("보유 학생만", "owned_count"), ("계획 학생만", "planned_count"))
            default = "student_count"
        elif mode == "plan_required":
            options = (("필요 비율", "required"), ("충족률", "coverage"), ("부족 비율", "shortage"))
            default = "required"
        else:
            options = (("부족 비율", "shortage"), ("필요 비율", "required"), ("충족률", "coverage"))
            default = "shortage"
        current = self._stats_sunburst_value_key()
        if current not in {value for _label, value in options}:
            current = default
        self._stats_sunburst_value_mode.blockSignals(True)
        self._stats_sunburst_value_mode.clear()
        for label, value in options:
            self._stats_sunburst_value_mode.addItem(label, value)
        selected_index = next((index for index, (_label, value) in enumerate(options) if value == current), 0)
        self._stats_sunburst_value_mode.setCurrentIndex(selected_index)
        self._stats_sunburst_value_mode.blockSignals(False)
        return
        if mode.startswith("collection_") or mode == "skill_function":
            options = (("학생 수", "student_count"), ("보유 학생", "owned_count"), ("계획 학생", "planned_count"))
            default = "student_count"
        elif mode == "plan_required":
            options = (("필요 비율", "required"), ("충족률", "coverage"), ("부족 비율", "shortage"))
            default = "required"
        else:
            options = (("부족 비율", "shortage"), ("필요 비율", "required"), ("충족률", "coverage"))
            default = "shortage"
        current = self._stats_sunburst_value_key()
        if current not in {value for _label, value in options}:
            current = default
        self._stats_sunburst_value_mode.blockSignals(True)
        self._stats_sunburst_value_mode.clear()
        for label, value in options:
            self._stats_sunburst_value_mode.addItem(label, value)
        selected_index = next((index for index, (_label, value) in enumerate(options) if value == current), 0)
        self._stats_sunburst_value_mode.setCurrentIndex(selected_index)
        self._stats_sunburst_value_mode.blockSignals(False)
    def _stats_node_for_path(self, root: SunburstNode, path: tuple[str, ...]) -> SunburstNode | None:
        if not path:
            return root
        parts = list(path)
        if parts and parts[0] == root.label:
            parts = parts[1:]
        node = root
        for part in parts:
            found = next((child for child in node.children if child.label == part), None)
            if found is None and self._stats_sunburst is not None:
                display_nodes = self._stats_sunburst._display_nodes(node.children)
                found = next((child for child in display_nodes if child.label == part), None)
            if found is None:
                return None
            node = found
        return node
    def _stats_apply_sunburst_path(self, path: tuple[str, ...], *, push_current: bool) -> None:
        root = self._stats_sunburst_root()
        if not path or path == (root.label,):
            self._stats_reset_sunburst_root()
            return
        node = self._stats_node_for_path(root, path)
        if node is None:
            self._stats_reset_sunburst_root()
            return
        if push_current and self._stats_sunburst_selected_path != path:
            self._stats_sunburst_drill_stack.append(self._stats_sunburst_selected_path)
        self._stats_sunburst_selected_path = path
        self._stats_sunburst_breadcrumb_path = path
        context = dict(node.context or {})
        context["node"] = node
        self._stats_sunburst_selected_context = context
        self._stats_sunburst_selected_node = node
        self._refresh_stats_tab()
    def _stats_sunburst_value_key(self) -> str:
        value = self._stats_sunburst_value_mode.currentData() if self._stats_sunburst_value_mode is not None else None
        return str(value or "student_count")
    def _stats_scope_student_ids(self) -> set[str] | None:
        value = self._stats_sunburst_selected_context.get("student_ids")
        if isinstance(value, set):
            return {str(item) for item in value}
        if isinstance(value, (list, tuple)):
            return {str(item) for item in value}
        return None
    def _stats_scope_records(self) -> list[StudentRecord]:
        student_ids = self._stats_scope_student_ids()
        if not student_ids:
            return list(self._filtered_students)
        return [record for record in self._filtered_students if record.student_id in student_ids]
    def _stats_option_combo(
        self,
        layout: QHBoxLayout,
        options: tuple[tuple[str, str], ...],
        current_value: str,
        attr_name: str,
    ) -> QComboBox:
        combo = QComboBox()
        for label, value in options:
            combo.addItem(label, value)
        selected_index = next((index for index, (_label, value) in enumerate(options) if value == current_value), 0)
        combo.setCurrentIndex(selected_index)
        combo.currentIndexChanged.connect(lambda *_args, combo=combo, attr_name=attr_name: self._stats_set_mode(attr_name, str(combo.currentData())))
        layout.addWidget(combo, 0, Qt.AlignRight)
        return combo
    def _stats_make_rows(self, counts: Counter[str], *, denominator: int | None = None) -> list[DistributionRow]:
        if not counts:
            return []
        total = denominator if denominator is not None else sum(counts.values())
        if total <= 0:
            total = sum(counts.values())
        rows: list[DistributionRow] = []
        ordered = [(label, count) for label, count in counts.items() if count > 0]
        for index, (label, count) in enumerate(sorted(ordered, key=lambda item: (-item[1], item[0].casefold()))):
            percent = (count / total * 100.0) if total else 0.0
            rows.append(DistributionRow(label=label, count=count, percent=percent, color=PALETTE[index % len(PALETTE)]))
        return rows
    def _stats_resource_weight(self, amount: int | float, basis: int | float) -> float:
        if basis <= 0:
            return 0.0
        return max(0.0, float(amount) / float(basis) * 100.0)
    def _stats_resource_weighted_entries(
        self,
        records: list[StudentRecord],
        goal_map: dict[str, StudentGoal],
        *,
        shortage_only: bool = False,
    ) -> list[tuple[StudentRecord, PlanResourceRequirement, float, int]]:
        weighted: list[tuple[StudentRecord, PlanResourceRequirement, float, int]] = []
        for record in records:
            summary = self._cached_goal_cost(record.student_id, record=record, goal=goal_map.get(record.student_id), goal_map=goal_map)
            if summary is None:
                continue
            entries = self._plan_requirement_entries(summary, record=record)
            if shortage_only:
                basis = sum(max(0, entry.required - entry.owned) for entry in entries)
            else:
                basis = sum(entry.required for entry in entries)
            if basis <= 0:
                continue
            for entry in entries:
                shortage = max(0, entry.required - entry.owned)
                amount = shortage if shortage_only else entry.required
                weight = self._stats_resource_weight(amount, basis)
                if weight > 0:
                    weighted.append((record, entry, weight, shortage))
        return weighted
    def _stats_field_rows(self, field_name: str, *, records: list[StudentRecord] | None = None, multi: bool = False) -> list[DistributionRow]:
        records = list(self._stats_scope_records() if records is None else records)
        if field_name == "owned":
            return build_distribution(records, field_name)
        counts: Counter[str] = Counter()
        for record in records:
            values = get_student_values(record, field_name)
            if not values:
                counts["(없음)"] += 1
                continue
            selected_values = values if multi else values[:1]
            for value in selected_values:
                counts[format_filter_value(field_name, value)] += 1
        return self._stats_make_rows(counts, denominator=len(records))
    @staticmethod
    def _stats_bucket(number: int, buckets: tuple[tuple[int, int, str], ...], empty_label: str = "미확인") -> str:
        if number <= 0:
            return empty_label
        for low, high, label in buckets:
            if low <= number <= high:
                return label
        return str(number)
    @staticmethod
    def _stats_summary_has_requirement(summary: PlanCostSummary | None) -> bool:
        if summary is None:
            return False
        if any((summary.credits, summary.level_exp, summary.equipment_exp, summary.weapon_exp)):
            return True
        return any(
            bool(mapping)
            for mapping in (
                summary.star_materials,
                summary.equipment_materials,
                summary.level_exp_items,
                summary.equipment_exp_items,
                summary.weapon_exp_items,
                summary.skill_books,
                summary.ex_ooparts,
                summary.skill_ooparts,
                summary.favorite_item_materials,
                summary.stat_materials,
                summary.stat_levels,
            )
        )
    def _stats_equipment_tier(self, record: StudentRecord, slot_index: int) -> int:
        return _tier_from_item_id_or_name(None, getattr(record, f"equip{slot_index}", None))
    def _stats_growth_score(self, record: StudentRecord) -> float:
        pieces: list[float] = []
        pieces.append(min(1.0, max(0.0, (_int_or_none(record.level) or 0) / MAX_TARGET_LEVEL)))
        pieces.append(min(1.0, max(0.0, record.star / MAX_TARGET_STAR)))
        skills = [
            min(1.0, max(0.0, (_int_or_none(record.ex_skill) or 0) / MAX_TARGET_EX_SKILL)),
            min(1.0, max(0.0, (_int_or_none(record.skill1) or 0) / MAX_TARGET_SKILL)),
            min(1.0, max(0.0, (_int_or_none(record.skill2) or 0) / MAX_TARGET_SKILL)),
            min(1.0, max(0.0, (_int_or_none(record.skill3) or 0) / MAX_TARGET_SKILL)),
        ]
        pieces.append(sum(skills) / len(skills))
        equipment_tiers = [self._stats_equipment_tier(record, index) for index in (1, 2, 3)]
        if any(equipment_tiers):
            pieces.append(sum(min(1.0, max(0.0, tier / MAX_TARGET_EQUIP_TIER)) for tier in equipment_tiers) / 3)
        stat_values = [_int_or_none(record.stat_hp) or 0, _int_or_none(record.stat_atk) or 0, _int_or_none(record.stat_heal) or 0]
        if any(stat_values):
            pieces.append(sum(min(1.0, max(0.0, value / MAX_TARGET_STAT)) for value in stat_values) / 3)
        if record.weapon_state in {"weapon_equipped", "weapon_unlocked_not_equipped"}:
            weapon_level = min(1.0, max(0.0, (_int_or_none(record.weapon_level) or 0) / MAX_TARGET_WEAPON_LEVEL))
            weapon_star = min(1.0, max(0.0, (_int_or_none(record.weapon_star) or 0) / MAX_TARGET_WEAPON_STAR))
            pieces.append((weapon_level + weapon_star) / 2)
        return (sum(pieces) / len(pieces) * 100.0) if pieces else 0.0
    def _stats_training_score(self, record: StudentRecord) -> float:
        return self._stats_growth_score(record)
    def _stats_training_group_rows(self, field_name: str, records: list[StudentRecord]) -> list[DistributionRow]:
        grouped: dict[str, list[float]] = defaultdict(list)
        for record in records:
            values = get_student_values(record, field_name)
            label = format_filter_value(field_name, values[0]) if values else "(없음)"
            grouped[label].append(self._stats_training_score(record))
        rows: list[DistributionRow] = []
        for index, (label, scores) in enumerate(
            sorted(grouped.items(), key=lambda item: (-(sum(item[1]) / max(1, len(item[1]))), item[0].casefold()))
        ):
            average = sum(scores) / max(1, len(scores))
            rows.append(DistributionRow(label=label, count=average, percent=average, color=PALETTE[index % len(PALETTE)]))
        return rows
    def _stats_growth_rows(self, mode: str) -> list[DistributionRow]:
        records = [record for record in self._stats_scope_records() if record.owned]
        counts: Counter[str] = Counter()
        if not records:
            return []
        if mode == "level_bucket":
            buckets = ((1, 34, "Lv 1-34"), (35, 49, "Lv 35-49"), (50, 69, "Lv 50-69"), (70, 84, "Lv 70-84"), (85, 90, "Lv 85-90"))
            for record in records:
                counts[self._stats_bucket(_int_or_none(record.level) or 0, buckets)] += 1
        elif mode == "star":
            for record in records:
                counts[f"{record.star or 0}성"] += 1
        elif mode == "weapon_state":
            return self._stats_field_rows("weapon_state", records=records)
        elif mode == "weapon_star":
            for record in records:
                value = _int_or_none(record.weapon_star) or 0
                counts[f"전무 {value}성" if value else "전무 없음"] += 1
        elif mode == "weapon_level":
            buckets = ((1, 20, "Lv 1-20"), (21, 40, "Lv 21-40"), (41, 50, "Lv 41-50"), (51, 60, "Lv 51-60"))
            for record in records:
                counts[self._stats_bucket(_int_or_none(record.weapon_level) or 0, buckets, "전무 없음")] += 1
        elif mode == "ex_skill":
            for record in records:
                counts[f"EX Lv {(_int_or_none(record.ex_skill) or 0)}"] += 1
        elif mode in {"skill1", "skill2", "skill3"}:
            label_map = {"skill1": "기본", "skill2": "강화", "skill3": "서브"}
            for record in records:
                counts[f"{label_map[mode]} Lv {(_int_or_none(getattr(record, mode)) or 0)}"] += 1
        elif mode == "normal_skill_avg":
            buckets = ((1, 3, "평균 1-3"), (4, 6, "평균 4-6"), (7, 9, "평균 7-9"), (10, 10, "평균 10"))
            for record in records:
                values = [_int_or_none(record.skill1) or 0, _int_or_none(record.skill2) or 0, _int_or_none(record.skill3) or 0]
                counts[self._stats_bucket(round(sum(values) / 3), buckets)] += 1
        elif mode == "equipment_avg":
            buckets = ((1, 3, "평균 T1-T3"), (4, 6, "평균 T4-T6"), (7, 9, "평균 T7-T9"), (10, 10, "평균 T10"))
            for record in records:
                tiers = [self._stats_equipment_tier(record, index) for index in (1, 2, 3)]
                counts[self._stats_bucket(round(sum(tiers) / 3), buckets)] += 1
        elif mode in {"equip1", "equip2", "equip3"}:
            slot_index = int(mode[-1])
            for record in records:
                tier = self._stats_equipment_tier(record, slot_index)
                counts[f"T{tier}" if tier else "미장착"] += 1
        elif mode == "equip4":
            for record in records:
                tier = _tier_from_item_id_or_name(None, record.equip4)
                counts[f"T{tier}" if tier else "없음"] += 1
        elif mode == "equipment_slot_status":
            for record in records:
                for slot_index in (1, 2, 3):
                    tier = self._stats_equipment_tier(record, slot_index)
                    if tier >= MAX_TARGET_EQUIP_TIER:
                        counts["최대 티어"] += 1
                    elif tier > 0:
                        counts["장착"] += 1
                    else:
                        counts["미장착/잠김"] += 1
            return self._stats_make_rows(counts, denominator=len(records) * 3)
        elif mode == "role_training":
            return self._stats_training_group_rows("role", records)
        elif mode in {"ability_hp", "ability_atk", "ability_heal"}:
            field_name = {"ability_hp": "stat_hp", "ability_atk": "stat_atk", "ability_heal": "stat_heal"}[mode]
            buckets = ((1, 5, "1-5"), (6, 10, "6-10"), (11, 15, "11-15"), (16, 20, "16-20"), (21, 24, "21-24"), (25, 25, "25"))
            for record in records:
                counts[self._stats_bucket(_int_or_none(getattr(record, field_name)) or 0, buckets, "0")] += 1
        else:
            buckets = ((1, 39, "0-39%"), (40, 59, "40-59%"), (60, 79, "60-79%"), (80, 94, "80-94%"), (95, 100, "95-100%"))
            for record in records:
                counts[self._stats_bucket(round(self._stats_growth_score(record)), buckets, "0%")] += 1
        return self._stats_make_rows(counts, denominator=len(records))
    def _stats_plan_rows(self, mode: str) -> list[DistributionRow]:
        goal_map = self._plan_goal_map()
        records = self._stats_scope_records()
        planned_records = [record for record in records if record.student_id in goal_map]
        if mode == "plan_membership":
            counts = Counter(
                "계획 있음" if record.student_id in goal_map else "계획 없음"
                for record in records
            )
            return self._stats_make_rows(counts, denominator=len(records))

        if mode == "planned_owned_ratio":
            counts = Counter("보유" if record.owned else "미보유" for record in planned_records)
            return self._stats_make_rows(counts, denominator=len(planned_records))

        if mode == "plan_completion":
            counts: Counter[str] = Counter()
            for record in planned_records:
                summary = self._cached_goal_cost(record.student_id, record=record, goal=goal_map.get(record.student_id), goal_map=goal_map)
                counts["목표 달성"] += int(not self._stats_summary_has_requirement(summary))
                counts["남은 목표 있음"] += int(self._stats_summary_has_requirement(summary))
            return self._stats_make_rows(counts, denominator=max(1, len(planned_records)))

        if mode in {"planned_school", "planned_role", "planned_attack"}:
            field_name = {"planned_school": "school", "planned_role": "role", "planned_attack": "attack_type"}[mode]
            return self._stats_field_rows(field_name, records=planned_records)

        if mode.startswith("target_") or mode == "before_after_change":
            counts: Counter[str] = Counter()
            deltas: Counter[str] = Counter()
            for record in planned_records:
                goal = goal_map.get(record.student_id)
                if goal is None:
                    continue
                target_level = max(_int_or_none(record.level) or 0, int(getattr(goal, "target_level", 0) or 0))
                target_star = self._current_or_target_star(record, goal)
                target_weapon = self._current_or_target_weapon_star(record, goal)
                target_ex = max(_int_or_none(record.ex_skill) or 0, int(getattr(goal, "target_ex_skill", 0) or 0))
                target_skills = [
                    max(_int_or_none(getattr(record, field_name)) or 0, int(getattr(goal, f"target_{field_name}", 0) or 0))
                    for field_name in ("skill1", "skill2", "skill3")
                ]
                target_equips = [
                    max(self._stats_equipment_tier(record, slot_index), int(getattr(goal, f"target_equip{slot_index}_tier", 0) or 0))
                    for slot_index in (1, 2, 3)
                ]
                target_stats = [
                    max(_int_or_none(getattr(record, field_name)) or 0, int(getattr(goal, f"target_{field_name}", 0) or 0))
                    for field_name in ("stat_hp", "stat_atk", "stat_heal")
                ]
                if mode == "target_level":
                    counts[self._stats_bucket(target_level, ((1, 34, "Lv 1-34"), (35, 49, "Lv 35-49"), (50, 69, "Lv 50-69"), (70, 84, "Lv 70-84"), (85, 90, "Lv 85-90")))] += 1
                elif mode == "target_star":
                    counts[f"{target_star}성"] += 1
                elif mode == "target_weapon":
                    counts[f"전무 {target_weapon}성" if target_weapon else "전무 없음"] += 1
                elif mode == "target_ex":
                    counts[f"EX Lv {target_ex}"] += 1
                elif mode == "target_normal_skill":
                    counts[f"평균 Lv {round(sum(target_skills) / 3)}"] += 1
                elif mode == "target_equipment":
                    counts[f"평균 T{round(sum(target_equips) / 3)}"] += 1
                elif mode == "target_ability":
                    counts[f"평균 {round(sum(target_stats) / 3)}"] += 1
                else:
                    deltas["레벨"] += max(0, target_level - (_int_or_none(record.level) or 0))
                    deltas["성급"] += max(0, target_star - self._record_current_star(record))
                    deltas["전무"] += max(0, target_weapon - (int(record.weapon_star or 0)))
                    deltas["EX"] += max(0, target_ex - (_int_or_none(record.ex_skill) or 0))
                    deltas["일반 스킬"] += sum(max(0, target - (_int_or_none(getattr(record, field_name)) or 0)) for target, field_name in zip(target_skills, ("skill1", "skill2", "skill3")))
                    deltas["장비"] += sum(max(0, target - self._stats_equipment_tier(record, slot_index)) for target, slot_index in zip(target_equips, (1, 2, 3)))
                    deltas["능력개방"] += sum(max(0, target - (_int_or_none(getattr(record, field_name)) or 0)) for target, field_name in zip(target_stats, ("stat_hp", "stat_atk", "stat_heal")))
            if mode == "before_after_change":
                return self._stats_make_rows(deltas)
            return self._stats_make_rows(counts, denominator=len(planned_records))

        student_ids = [record.student_id for record in planned_records]
        summary, _selected_count, contributing_count = self._resource_total_for_ids(student_ids, goal_map)
        entries = self._plan_requirement_entries(summary)
        if contributing_count == 0:
            return []

        if mode in {"required_categories", "shortage_categories"}:
            counts: Counter[str] = Counter()
            weighted_entries = self._stats_resource_weighted_entries(
                planned_records,
                goal_map,
                shortage_only=mode == "shortage_categories",
            )
            for _record, entry, weight, _shortage in weighted_entries:
                counts[_plan_resource_category_label(entry.category)] += weight
            return self._stats_make_rows(counts)

        if mode == "expensive_students":
            counts = Counter()
            for record in planned_records:
                summary = self._cached_goal_cost(record.student_id, record=record, goal=goal_map.get(record.student_id), goal_map=goal_map)
                if summary is None:
                    continue
                requirement_count = len(self._plan_requirement_entries(summary, record=record))
                if requirement_count:
                    counts[record.title] = requirement_count
            return self._stats_make_rows(counts)

        if mode == "remaining_growth":
            counts = Counter()
            for record, _entry, weight, _shortage in self._stats_resource_weighted_entries(planned_records, goal_map, shortage_only=True):
                counts[record.title] += weight
            return self._stats_make_rows(counts)

        counts = Counter()
        for _record, entry, weight, _shortage in self._stats_resource_weighted_entries(planned_records, goal_map, shortage_only=True):
            counts[entry.name] += weight
        return self._stats_make_rows(counts)
    def _stats_resource_rows(self, mode: str) -> list[DistributionRow]:
        goal_map = self._plan_goal_map()
        planned_records = [record for record in self._stats_scope_records() if record.student_id in goal_map]
        summary, _selected_count, contributing_count = self._resource_total_for_ids([record.student_id for record in planned_records], goal_map)
        if contributing_count == 0:
            return []
        entries = self._plan_requirement_entries(summary)
        counts: Counter[str] = Counter()

        weighted_required = self._stats_resource_weighted_entries(planned_records, goal_map, shortage_only=False)
        weighted_shortage = self._stats_resource_weighted_entries(planned_records, goal_map, shortage_only=True)

        if mode == "required_totals":
            for _record, entry, weight, _shortage in weighted_required:
                counts[entry.name] += weight
            return self._stats_make_rows(counts)
        if mode == "shortage_categories":
            for _record, entry, weight, _shortage in weighted_shortage:
                counts[_plan_resource_category_label(entry.category)] += weight
            return self._stats_make_rows(counts)
        if mode == "shortage_items":
            for _record, entry, weight, _shortage in weighted_shortage:
                counts[entry.name] += weight
            return self._stats_make_rows(counts)
        if mode == "required_categories":
            for _record, entry, weight, _shortage in weighted_required:
                counts[_plan_resource_category_label(entry.category)] += weight
            return self._stats_make_rows(counts)
        if mode == "school_demand":
            for _record, entry, weight, _shortage in weighted_required:
                for pattern in (r"Item_Icon_Material_ExSkill_([^_]+)_", r"Item_Icon_SkillBook_([^_]+)_"):
                    match = re.match(pattern, entry.key)
                    if match:
                        counts[match.group(1)] += weight
                        break
            return self._stats_make_rows(counts)
        if mode == "oopart_family":
            for _record, entry, weight, _shortage in weighted_required:
                if entry.category not in {"ex_ooparts", "skill_ooparts"}:
                    continue
                family = re.sub(r"\s+T\d+$", "", entry.name).strip() or entry.name
                counts[family] += weight
            return self._stats_make_rows(counts)
        if mode == "equipment_type":
            for _record, entry, weight, _shortage in weighted_required:
                if entry.category != "equipment_materials":
                    continue
                series = _equipment_series_key_from_item(entry.key, entry.name) or re.sub(r"\s+T\d+$", "", entry.name).strip() or entry.name
                counts[_equipment_series_label(series)] += weight
            return self._stats_make_rows(counts)
        if mode == "equipment_tier":
            for _record, entry, weight, _shortage in weighted_required:
                if entry.category != "equipment_materials":
                    continue
                tier = _tier_from_item_id_or_name(entry.key, entry.name)
                counts[f"T{tier}" if tier else "?곗뼱 誘몄긽"] += weight
            return self._stats_make_rows(counts)

        if mode == "required_totals":
            counts["크레딧"] = summary.credits
            counts["활동 보고서 EXP"] = summary.level_exp
            counts["장비 EXP"] = summary.equipment_exp
            counts["무기 EXP"] = summary.weapon_exp
            return self._stats_make_rows(counts)
        if mode == "shortage_categories":
            for entry in entries:
                shortage = max(0, entry.required - entry.owned)
                if shortage:
                    counts[_plan_resource_category_label(entry.category)] += shortage
            return self._stats_make_rows(counts)
        if mode == "required_categories":
            for entry in entries:
                if entry.required:
                    counts[_plan_resource_category_label(entry.category)] += entry.required
            return self._stats_make_rows(counts)
        if mode == "shortage_rate":
            rows: list[DistributionRow] = []
            shortage_rows = [
                (entry.name, max(0, entry.required - entry.owned), entry.required)
                for entry in entries
                if entry.required > 0 and max(0, entry.required - entry.owned) > 0
            ]
            shortage_rows.sort(key=lambda item: (-(item[1] / max(1, item[2])), -item[1], item[0]))
            for index, (name, shortage, required) in enumerate(shortage_rows):
                rows.append(DistributionRow(name, shortage, shortage / max(1, required) * 100.0, PALETTE[index % len(PALETTE)]))
            return rows
        if mode == "school_demand":
            for entry in entries:
                for pattern in (r"Item_Icon_Material_ExSkill_([^_]+)_", r"Item_Icon_SkillBook_([^_]+)_"):
                    match = re.match(pattern, entry.key)
                    if match:
                        counts[match.group(1)] += entry.required
                        break
            return self._stats_make_rows(counts)
        if mode == "oopart_family":
            for entry in entries:
                if entry.category not in {"ex_ooparts", "skill_ooparts"}:
                    continue
                family = re.sub(r"\s+T\d+$", "", entry.name).strip() or entry.name
                counts[family] += entry.required
            return self._stats_make_rows(counts)
        if mode == "equipment_type":
            for entry in entries:
                if entry.category != "equipment_materials":
                    continue
                series = _equipment_series_key_from_item(entry.key, entry.name) or re.sub(r"\s+T\d+$", "", entry.name).strip() or entry.name
                counts[_equipment_series_label(series)] += entry.required
            return self._stats_make_rows(counts)
        if mode == "equipment_tier":
            for entry in entries:
                if entry.category != "equipment_materials":
                    continue
                tier = _tier_from_item_id_or_name(entry.key, entry.name)
                counts[f"T{tier}" if tier else "티어 미상"] += entry.required
            return self._stats_make_rows(counts)

        for entry in entries:
            shortage = max(0, entry.required - entry.owned)
            if shortage:
                counts[entry.name] += shortage
        return self._stats_make_rows(counts)
    def _stats_skill_rows(self, mode: str) -> list[DistributionRow]:
        records = [record for record in self._stats_scope_records() if record.owned]
        if mode == "skill_is_area_damage":
            return self._stats_field_rows("skill_is_area_damage", records=records)
        if mode in {"skill_ignore_cover", "skill_knockback"}:
            return self._stats_field_rows(mode, records=records)
        return self._stats_field_rows(mode, records=records, multi=True)
    def _stats_show_chart_row_detail(self, row: DistributionRow) -> None:
        if self._stats_sunburst_detail is None:
            return
        self._stats_sunburst_detail.setText(
            "\n".join(
                (
                    "Chart selection",
                    f"Label: {row.label}",
                    f"Value: {self._stats_row_count_text(row.count, compact=True)}",
                    f"Share: {row.percent:.1f}%",
                )
            )
        )
    def _stats_row_count_text(self, value: int | float, *, compact: bool = False) -> str:
        try:
            number = float(value)
        except (TypeError, ValueError):
            return _format_count(value, compact=compact)
        if not compact and not number.is_integer():
            return f"{number:,.1f}"
        return _format_count(value, compact=compact)
    def _stats_add_bar_rows(self, layout: QVBoxLayout, rows: list[DistributionRow], *, limit: int = 8, compact_count: bool = False) -> None:
        if not rows:
            empty = QLabel("현재 조건에 맞는 데이터가 없습니다.")
            empty.setObjectName("detailSub")
            layout.addWidget(empty)
            return
        for row in rows[:limit]:
            wrap = QWidget()
            row_layout = QHBoxLayout(wrap)
            row_layout.setContentsMargins(0, 0, 0, 0)
            row_layout.setSpacing(scale_px(8, self._ui_scale))
            label = QLabel(row.label)
            label.setObjectName("detailSub")
            label.setFixedWidth(scale_px(132, self._ui_scale))
            label.setToolTip(row.label)
            row_layout.addWidget(label, 0, Qt.AlignVCenter)
            bar = QProgressBar()
            bar.setRange(0, 100)
            bar.setTextVisible(False)
            bar.setFixedHeight(scale_px(8, self._ui_scale))
            bar.setValue(max(0, min(100, int(round(row.percent)))))
            row_layout.addWidget(bar, 1, Qt.AlignVCenter)
            count_text = self._stats_row_count_text(row.count, compact=compact_count)
            value = QLabel(f"{count_text} · {row.percent:.1f}%")
            value.setObjectName("detailSub")
            value.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
            value.setFixedWidth(scale_px(92, self._ui_scale))
            row_layout.addWidget(value, 0, Qt.AlignVCenter)
            wrap.setCursor(Qt.PointingHandCursor)
            wrap.mousePressEvent = lambda event, row=row: self._stats_show_chart_row_detail(row)
            layout.addWidget(wrap)
    def _stats_add_distribution_rows(self, layout: QVBoxLayout, rows: list[DistributionRow]) -> None:
        if not rows:
            empty = QLabel("현재 조건에 맞는 데이터가 없습니다.")
            empty.setObjectName("detailSub")
            layout.addWidget(empty)
            return
        top = rows[0]
        top_wrap = QHBoxLayout()
        donut = DonutWidget(top.percent, top.color, f"{top.percent:.0f}%", self._ui_scale)
        top_wrap.addWidget(donut, 0, Qt.AlignLeft | Qt.AlignVCenter)
        top_text = QVBoxLayout()
        main_label = QLabel(top.label)
        main_label.setObjectName("metricValue")
        count_label = QLabel(f"{self._stats_row_count_text(top.count, compact=True)}")
        count_label.setObjectName("detailSub")
        top_text.addWidget(main_label)
        top_text.addWidget(count_label)
        top_wrap.addLayout(top_text, 1)
        layout.addLayout(top_wrap)
        self._stats_add_bar_rows(layout, rows, limit=5)
    def _stats_add_chart_card(
        self,
        *,
        grid: QGridLayout,
        index: int,
        title: str,
        subtitle: str,
        options: tuple[tuple[str, str], ...],
        current_value: str,
        attr_name: str,
        rows: list[DistributionRow],
        chart_kind: str,
        compact_count: bool = False,
    ) -> None:
        card = QFrame()
        card.setObjectName("statPanel")
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(scale_px(16, self._ui_scale), scale_px(16, self._ui_scale), scale_px(16, self._ui_scale), scale_px(16, self._ui_scale))
        card_layout.setSpacing(scale_px(10, self._ui_scale))
        header = QHBoxLayout()
        header.setContentsMargins(0, 0, 0, 0)
        title_wrap = QVBoxLayout()
        title_label = QLabel(title)
        title_label.setObjectName("sectionTitle")
        subtitle_label = QLabel(subtitle)
        subtitle_label.setObjectName("detailSub")
        subtitle_label.setWordWrap(True)
        title_wrap.addWidget(title_label)
        title_wrap.addWidget(subtitle_label)
        header.addLayout(title_wrap, 1)
        self._stats_option_combo(header, options, current_value, attr_name)
        card_layout.addLayout(header)
        if chart_kind == "distribution":
            self._stats_add_distribution_rows(card_layout, rows)
        else:
            self._stats_add_bar_rows(card_layout, rows, compact_count=compact_count)
        grid.addWidget(card, index // 2, index % 2)
    def _stats_value_label(self, record: StudentRecord, field_name: str) -> str:
        if field_name == "owned":
            return "보유" if record.owned else "미보유"
        value = get_student_value(record, field_name)
        return format_filter_value(field_name, value) if value else "(누락)"
    def _sunburst_context_merge(self, current: dict[str, object], incoming: dict[str, object]) -> None:
        for key in ("student_ids", "resource_keys", "categories"):
            value = incoming.get(key)
            if value is None:
                continue
            target = current.setdefault(key, set())
            if isinstance(target, set):
                if isinstance(value, (set, list, tuple)):
                    target.update(str(item) for item in value)
                else:
                    target.add(str(value))
        for key in ("required", "owned", "shortage"):
            value = incoming.get(key)
            if value is None:
                continue
            try:
                current[key] = float(current.get(key, 0.0) or 0.0) + float(value)
            except (TypeError, ValueError):
                pass
        for key in ("training_score_sum", "training_count"):
            value = incoming.get(key)
            if value is None:
                continue
            try:
                current[key] = float(current.get(key, 0.0) or 0.0) + float(value)
            except (TypeError, ValueError):
                pass
        impacts = incoming.get("impacts")
        if isinstance(impacts, list):
            current.setdefault("impacts", [])
            if isinstance(current["impacts"], list):
                current["impacts"].extend(impacts)
    def _sunburst_tree_from_paths(self, title: str, paths: list[tuple], *, value_mode: str | None = None) -> SunburstNode:
        tree: dict[str, dict] = {}

        for item in paths:
            if len(item) == 2:
                raw_path, raw_value = item
                context = {}
            else:
                raw_path, raw_value, context = item
            value = float(raw_value or 0)
            if value <= 0:
                continue
            cursor = tree
            if isinstance(context, dict):
                self._sunburst_context_merge(cursor.setdefault("_context", {}), context)
            for part in raw_path:
                label = str(part or "(누락)")
                cursor = cursor.setdefault(label, {})
                if isinstance(context, dict):
                    self._sunburst_context_merge(cursor.setdefault("_context", {}), context)
            cursor["_value"] = float(cursor.get("_value", 0.0)) + value

        def build(label: str, branch: dict) -> SunburstNode:
            children = [
                build(child_label, child_branch)
                for child_label, child_branch in branch.items()
                if child_label not in {"_value", "_context"}
            ]
            children.sort(key=lambda child: (-child.total(), child.label.casefold()))
            context = dict(branch.get("_context", {}) or {})
            node_value = float(branch.get("_value", 0.0))
            if value_mode == "coverage":
                required = float(context.get("required", 0.0) or 0.0)
                owned = float(context.get("owned", 0.0) or 0.0)
                node_value = 100.0 if required <= 0 and owned > 0 else max(0.0, min(100.0, owned / required * 100.0)) if required > 0 else 0.0
                context["value_mode"] = "coverage"
            elif value_mode == "training_avg":
                score_sum = float(context.get("training_score_sum", 0.0) or 0.0)
                score_count = float(context.get("training_count", 0.0) or 0.0)
                node_value = max(0.0, min(100.0, score_sum / score_count)) if score_count > 0 else 0.0
                context["value_mode"] = "training_avg"
            node = SunburstNode(label=label, value=node_value, children=children, context=context)
            node.context = context | {"node": node}
            return node

        root = build(title, tree)
        return root
    def _collection_sunburst_root(self, mode: str) -> SunburstNode:
        if mode == "collection_class_role_position":
            fields = ("combat_class", "role", "position")
            title = "Visible Students"
        elif mode == "collection_attack_defense_role":
            fields = ("attack_type", "defense_type", "role")
            title = "Visible Students"
        else:
            fields = ("school", "role", "attack_type")
            title = "Visible Students"
        value_key = self._stats_sunburst_value_key()
        goal_map = self._plan_goal_map()
        records = list(self._filtered_students)
        paths = [
            (
                tuple(self._stats_value_label(record, field_name) for field_name in fields),
                1.0,
                {"student_ids": {record.student_id}},
            )
            for record in records
            if value_key == "student_count"
            or (value_key == "owned_count" and record.owned)
            or (value_key == "planned_count" and record.student_id in goal_map)
        ]
        return self._sunburst_tree_from_paths(title, paths)
    @staticmethod
    def _stats_training_bucket_label(score: float) -> str:
        if score >= 90:
            return "90-100%"
        if score >= 75:
            return "75-89%"
        if score >= 60:
            return "60-74%"
        if score >= 40:
            return "40-59%"
        return "0-39%"
    def _role_training_sunburst_root(self) -> SunburstNode:
        value_key = self._stats_sunburst_value_key()
        records = list(self._filtered_students)
        paths: list[tuple] = []
        value_mode: str | None = "training_avg" if value_key == "training_avg" else None
        for record in records:
            if value_key in {"training_avg", "owned_count"} and not record.owned:
                continue
            score = self._stats_training_score(record)
            role_label = self._stats_value_label(record, "role")
            bucket_label = self._stats_training_bucket_label(score)
            if value_key == "student_count" or value_key == "owned_count":
                value = 1.0
            else:
                value = score
            paths.append(
                (
                    (role_label, bucket_label),
                    value,
                    {
                        "student_ids": {record.student_id},
                        "training_score_sum": score,
                        "training_count": 1,
                    },
                )
            )
        return self._sunburst_tree_from_paths("직군별 육성도", paths, value_mode=value_mode if paths else None)
    def _skill_book_sunburst_path(self, item_id: str, name: str) -> tuple[str, ...]:
        if "SkillBook_Ultimate" in item_id or "Ultimate" in item_id:
            return ("Skills", "Secret Notes", name)
        match = re.match(r"Item_Icon_Material_ExSkill_([^_]+)_(\d+)", item_id)
        if match:
            return ("Skills", "Tactical BD", match.group(1), f"T{int(match.group(2)) + 1}")
        match = re.match(r"Item_Icon_SkillBook_([^_]+)_(\d+)", item_id)
        if match:
            return ("스킬", "기술 노트", match.group(1), f"T{int(match.group(2)) + 1}")
        base, tier = _plan_resource_split_tier(name)
        school, _, kind = base.partition(" ")
        if school and kind:
            return ("스킬", kind, school, f"T{tier}" if tier else name)
        return ("스킬", "기타", name)
    def _oopart_sunburst_path(self, group: str, item_id: str, name: str) -> tuple[str, ...]:
        tier = _tier_from_item_id_or_name(item_id, name)
        family = name
        if tier:
            family = re.sub(r"\s+T\d+$", "", name).strip() or name
        return ("오파츠", group, family, f"T{tier}" if tier else name)
    def _equipment_sunburst_path(self, item_id: str, name: str) -> tuple[str, ...]:
        tier = _tier_from_item_id_or_name(item_id, name)
        series_key = _equipment_series_key_from_item(item_id, name)
        series = series_key or re.sub(r"\s+T\d+$", "", name).strip() or name
        return ("장비", "설계도", series, f"T{tier}" if tier else name)
    def _resource_sunburst_root(self, *, shortage_only: bool) -> SunburstNode:
        goal_map = self._plan_goal_map()
        records = [record for record in self._filtered_students if record.student_id in goal_map]
        value_key = self._stats_sunburst_value_key()
        paths: list[tuple] = []

        def resource_path(entry: PlanResourceRequirement) -> tuple[str, ...]:
            item_id = entry.key
            if entry.category == "credits":
                return ("재화", entry.name)
            if entry.category == "level_exp":
                return ("레벨", "활동 보고서", entry.name)
            if entry.category == "equipment_exp":
                return ("장비", "경험치", entry.name)
            if entry.category == "weapon_exp":
                return ("전용무기", "경험치", entry.name)
            if entry.category == "skill_books":
                return self._skill_book_sunburst_path(item_id, entry.name)
            if entry.category == "ex_ooparts":
                return self._oopart_sunburst_path("EX 스킬", item_id, entry.name)
            if entry.category == "skill_ooparts":
                return self._oopart_sunburst_path("일반 스킬", item_id, entry.name)
            if entry.category == "stat_materials":
                return ("능력개방", entry.name)
            if entry.category == "favorite_item_materials":
                return ("애용품", entry.name)
            if entry.category == "equipment_materials":
                return self._equipment_sunburst_path(item_id, entry.name)
            if entry.category == "star_materials":
                return ("성작 / 전용무기", "엘레프", entry.name)
            return ("기타", entry.category, entry.name)

        for record in records:
            summary = self._cached_goal_cost(record.student_id, record=record, goal=goal_map.get(record.student_id), goal_map=goal_map)
            if summary is None:
                continue
            entries = self._plan_requirement_entries(summary, record=record)
            required_basis = sum(entry.required for entry in entries)
            shortage_basis = sum(max(0, entry.required - entry.owned) for entry in entries)
            for entry in entries:
                shortage = max(0, entry.required - entry.owned)
                if value_key == "coverage":
                    value = 100.0 if entry.required <= 0 else max(0.0, min(100.0, (entry.owned / entry.required) * 100.0))
                elif shortage_only or value_key == "shortage":
                    value = self._stats_resource_weight(shortage, shortage_basis)
                else:
                    value = self._stats_resource_weight(entry.required, required_basis)
                if value <= 0:
                    continue
                base_path = resource_path(entry)
                path = (*base_path, record.title) if shortage_only else base_path
                paths.append(
                    (
                        path,
                        value,
                        {
                            "student_ids": {record.student_id},
                            "resource_keys": {entry.key},
                            "categories": {entry.category},
                            "required": entry.required,
                            "owned": entry.owned,
                            "shortage": shortage,
                            "weight": value,
                            "impacts": [(record.student_id, record.title, entry.name, int(entry.required), int(shortage))],
                        },
                    )
                )

        title = "계획 부족" if shortage_only else "계획 필요"
        return self._sunburst_tree_from_paths(title, paths, value_mode="coverage" if value_key == "coverage" else None)
    def _skill_function_sunburst_root(self) -> SunburstNode:
        records = [record for record in self._filtered_students if record.owned]
        groups = (
            ("버프", "skill_buff"),
            ("디버프", "skill_debuff"),
            ("CC", "skill_cc"),
            ("특수 효과", "skill_special"),
            ("회복", "skill_heal_targets"),
            ("해제", "skill_dispel_targets"),
            ("이동", "skill_reposition_targets"),
            ("소환", "skill_summon_types"),
            ("패시브", "passive_stat"),
            ("전무 패시브", "weapon_passive_stat"),
            ("추가 패시브", "extra_passive_stat"),
        )
        paths: list[tuple] = []
        for record in records:
            for group_label, field_name in groups:
                for value in get_student_values(record, field_name):
                    label = format_filter_value(field_name, value)
                    paths.append(((group_label, label, record.title), 1.0, {"student_ids": {record.student_id}}))
            for field_name, label in (
                ("skill_is_area_damage", "EX 범위 공격"),
                ("skill_ignore_cover", "엄폐 무시"),
                ("skill_knockback", "넉백"),
            ):
                value = get_student_value(record, field_name)
                if value:
                    paths.append(((label, format_filter_value(field_name, value), record.title), 1.0, {"student_ids": {record.student_id}}))
        return self._sunburst_tree_from_paths("기능 맵", paths)
    def _stats_sunburst_root(self) -> SunburstNode:
        mode = self._stats_sunburst_mode.currentData() if self._stats_sunburst_mode is not None else None
        if mode == "plan_required":
            return self._resource_sunburst_root(shortage_only=False)
        if mode == "plan_shortage":
            return self._resource_sunburst_root(shortage_only=True)
        if mode == "skill_function":
            return self._skill_function_sunburst_root()
        if mode == "role_training":
            return self._role_training_sunburst_root()
        return self._collection_sunburst_root(str(mode or "collection_school_role_attack"))
    def _stats_rebuild_sunburst_breadcrumb(self, breadcrumb: tuple[str, ...]) -> None:
        layout = self._stats_sunburst_breadcrumb_layout
        if layout is None:
            return
        self._clear_layout_widgets(layout)
        if not breadcrumb:
            button = QPushButton("전체")
            button.setFixedHeight(scale_px(24, self._ui_scale))
            button.clicked.connect(self._stats_reset_sunburst_root)
            layout.addWidget(button, 0, Qt.AlignLeft)
            layout.addStretch(1)
            return
        for index, part in enumerate(breadcrumb):
            if index:
                separator = QLabel(">")
                separator.setObjectName("filterSummary")
                layout.addWidget(separator, 0, Qt.AlignLeft)
            button = QPushButton(part)
            button.setFixedHeight(scale_px(24, self._ui_scale))
            if index == 0:
                button.clicked.connect(self._stats_reset_sunburst_root)
            else:
                target_path = tuple(breadcrumb[: index + 1])
                button.clicked.connect(lambda _checked=False, path=target_path: self._stats_apply_sunburst_path(path, push_current=True))
            layout.addWidget(button, 0, Qt.AlignLeft)
        layout.addStretch(1)
    def _stats_update_sunburst_legend(self, root: SunburstNode) -> None:
        layout = self._stats_sunburst_legend_layout
        if layout is None:
            return
        self._clear_layout_widgets(layout)
        if self._stats_sunburst is None or not root.children:
            empty = QLabel("표시할 경로가 없습니다.")
            empty.setObjectName("detailSub")
            empty.setWordWrap(True)
            layout.addWidget(empty)
            return
        max_depth = max(1, self._stats_sunburst._display_depth(root, is_root=True))
        levels: dict[int, dict[str, dict[str, object]]] = defaultdict(dict)

        def collect(nodes: list[SunburstNode], depth: int, path: tuple[str, ...]) -> None:
            for index, node in enumerate(nodes):
                value = node.total()
                if value <= 0:
                    continue
                current_path = (*path, node.label)
                level = levels[depth]
                entry = level.setdefault(
                    node.label,
                    {
                        "value": 0.0,
                        "color": SunburstWidget._node_color(node, index, depth, max_depth),
                        "paths": [],
                    },
                )
                entry["value"] = float(entry.get("value", 0.0) or 0.0) + value
                paths = entry.get("paths")
                if isinstance(paths, list) and len(paths) < 6:
                    paths.append(current_path)
                if node.children and not (node.context or {}).get("other"):
                    child_nodes = self._stats_sunburst._display_nodes(node.children)
                    collect(child_nodes, depth + 1, current_path)

        collect(self._stats_sunburst._display_nodes(root.children), 1, (root.label,))
        max_rows_per_level = 12
        for depth in sorted(levels):
            entries = sorted(levels[depth].items(), key=lambda item: (-float(item[1].get("value", 0.0) or 0.0), item[0].casefold()))
            if not entries:
                continue
            self._stats_add_sunburst_legend_header(
                layout,
                depth,
                max_depth,
                SunburstWidget._node_color(SunburstNode("Level"), 0, depth, max_depth),
            )
            level_total = sum(float(entry.get("value", 0.0) or 0.0) for _label, entry in entries)
            visible_entries = entries[:max_rows_per_level]
            for entry_index, (label, entry) in enumerate(visible_entries):
                value = float(entry.get("value", 0.0) or 0.0)
                percent = (value / level_total * 100.0) if level_total else 0.0
                paths = entry.get("paths")
                path_tuple = tuple(paths[0]) if isinstance(paths, list) and paths else (root.label, label)
                tooltip_paths = [" > ".join(path) for path in paths] if isinstance(paths, list) else []
                self._stats_add_sunburst_legend_row(
                    layout,
                    label,
                    str(entry.get("color") or "#6f7f8f"),
                    percent,
                    depth,
                    path_tuple,
                    tooltip="\n".join(tooltip_paths),
                    height_index=entry_index,
                    height_total=len(visible_entries),
                )
            if len(entries) > max_rows_per_level:
                more = QLabel(f"+ {len(entries) - max_rows_per_level} more")
                more.setObjectName("detailSub")
                layout.addWidget(more)
    def _stats_add_sunburst_legend_header(self, layout: QVBoxLayout, depth: int, max_depth: int, color: str) -> None:
        row = QWidget()
        row_layout = QHBoxLayout(row)
        row_layout.setContentsMargins(0, scale_px(4, self._ui_scale), 0, 0)
        row_layout.setSpacing(scale_px(6, self._ui_scale))
        swatch = QLabel("")
        swatch.setFixedSize(scale_px(10, self._ui_scale), scale_px(10, self._ui_scale))
        swatch.setStyleSheet(f"background: {color}; border-radius: {scale_px(2, self._ui_scale)}px;")
        row_layout.addWidget(swatch, 0, Qt.AlignVCenter)
        position = "내부" if depth == 1 else "외부" if depth == max_depth else "중간"
        header = QLabel(f"Level {depth} · {position}")
        header.setObjectName("detailSub")
        header.setStyleSheet("font-weight: 800; color: #d8e7f3;")
        row_layout.addWidget(header, 1, Qt.AlignVCenter)
        layout.addWidget(row)
    def _stats_add_sunburst_legend_row(
        self,
        layout: QVBoxLayout,
        label_text: str,
        color: str,
        percent: float,
        depth: int,
        path: tuple[str, ...],
        tooltip: str | None = None,
        height_index: int = 0,
        height_total: int = 1,
    ) -> None:
        row = QWidget()
        row.setFixedHeight(scale_px(20, self._ui_scale))
        row_layout = QHBoxLayout(row)
        row_layout.setContentsMargins(scale_px(max(0, depth - 1) * 14, self._ui_scale), 0, 0, 0)
        row_layout.setSpacing(scale_px(6, self._ui_scale))
        swatch = QLabel("")
        ratio = (height_total - height_index) / max(1, height_total)
        swatch_height = scale_px(4 + ratio * 10, self._ui_scale)
        swatch.setFixedSize(scale_px(9, self._ui_scale), swatch_height)
        swatch.setStyleSheet(f"background: {color}; border-radius: {scale_px(2, self._ui_scale)}px;")
        row_layout.addWidget(swatch, 0, Qt.AlignVCenter)
        label = QLabel(label_text)
        label.setObjectName("detailSub")
        label.setToolTip(tooltip or " > ".join(path))
        row_layout.addWidget(label, 1, Qt.AlignVCenter)
        value_label = QLabel(f"{percent:.1f}%")
        value_label.setObjectName("detailSub")
        value_label.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        value_label.setFixedWidth(scale_px(48, self._ui_scale))
        row_layout.addWidget(value_label, 0, Qt.AlignVCenter)
        layout.addWidget(row)
    def _stats_update_sunburst_detail_panel(self, display_root: SunburstNode, breadcrumb: tuple[str, ...]) -> None:
        required_widgets = (
            self._stats_detail_path_label,
            self._stats_detail_name_label,
            self._stats_detail_level_label,
            self._stats_detail_total_label,
            self._stats_detail_metric_count_label,
            self._stats_detail_metric_percent_label,
            self._stats_detail_owned_bar,
            self._stats_detail_owned_bar_label,
            self._stats_detail_owned_label,
            self._stats_detail_unowned_label,
            self._stats_detail_planned_label,
        )
        if any(widget is None for widget in required_widgets):
            return
        context = dict(display_root.context or {})
        if self._stats_sunburst_selected_context:
            context |= self._stats_sunburst_selected_context
        path = self._stats_sunburst_selected_path or breadcrumb or (display_root.label,)
        level = max(0, len(path) - 1)
        label = path[-1] if path else display_root.label
        student_ids_raw = context.get("student_ids")
        student_ids = {str(item) for item in student_ids_raw} if isinstance(student_ids_raw, set) else set()
        if not student_ids and isinstance(student_ids_raw, (list, tuple)):
            student_ids = {str(item) for item in student_ids_raw}
        scoped_records = [record for record in self._filtered_students if not student_ids or record.student_id in student_ids]
        total_students = len(scoped_records)
        owned = sum(1 for record in scoped_records if record.owned)
        unowned = max(0, total_students - owned)
        goal_map = self._plan_goal_map()
        planned = sum(1 for record in scoped_records if record.student_id in goal_map)
        percent = (total_students / max(1, len(self._filtered_students)) * 100.0) if self._filtered_students else 0.0
        owned_rate = owned / max(1, total_students) * 100.0 if total_students else 0.0
        training_sum = float(context.get("training_score_sum", 0.0) or 0.0)
        training_count = float(context.get("training_count", 0.0) or 0.0)
        total_text = f"{training_sum / training_count:.1f}%" if training_count > 0 else f"{total_students:,}"

        self._stats_detail_path_label.setText(f"L{level}: {label}")
        self._stats_detail_name_label.setText(label)
        self._stats_detail_level_label.setText(f"Level {level}")
        self._stats_detail_total_label.setText(total_text)
        self._stats_detail_metric_count_label.setText(f"{total_students:,}")
        self._stats_detail_metric_percent_label.setText(f"{percent:.1f}%")
        self._stats_detail_owned_bar.setValue(max(0, min(100, int(round(owned_rate)))))
        self._stats_detail_owned_bar_label.setText(f"{owned_rate:.1f}%")
        self._stats_detail_owned_label.setText(f"보유\n{owned:,}")
        self._stats_detail_unowned_label.setText(f"미보유\n{unowned:,}")
        self._stats_detail_planned_label.setText(f"계획\n{planned:,}")
    def _refresh_stats_sunburst(self) -> None:
        if self._stats_sunburst is None or self._stats_sunburst_detail is None or self._stats_sunburst_top_detail is None:
            return
        root = self._stats_sunburst_root()
        breadcrumb = self._stats_sunburst_breadcrumb_path or (root.label,)
        display_root = self._stats_node_for_path(root, breadcrumb) or root
        if display_root is root:
            breadcrumb = (root.label,)
        self._stats_sunburst.setRoot(display_root, selected_path=(), breadcrumb=breadcrumb)
        self._stats_rebuild_sunburst_breadcrumb(breadcrumb)
        self._stats_update_sunburst_legend(display_root)
        self._stats_update_sunburst_detail_panel(display_root, breadcrumb)
        if self._stats_sunburst_root_button is not None:
            self._stats_sunburst_root_button.setEnabled(display_root is not root or bool(self._stats_sunburst_selected_path))
        if self._stats_sunburst_back_button is not None:
            self._stats_sunburst_back_button.setEnabled(bool(self._stats_sunburst_drill_stack))
        if self._stats_sunburst_clear_button is not None:
            self._stats_sunburst_clear_button.setEnabled(bool(self._stats_sunburst_selected_context))
        if not display_root.children:
            self._stats_sunburst_top_detail.setText("현재 모드와 필터에 맞는 데이터가 없습니다.")
            self._stats_sunburst_detail.setText("선택된 segment가 없습니다.")
            return
        total = display_root.total()
        top_lines = [f"Root: {' > '.join(breadcrumb)}", f"Total: {total:,.0f}"]
        for child in sorted(display_root.children, key=lambda node: (-node.total(), node.label.casefold()))[:8]:
            percent = (child.total() / total * 100.0) if total else 0.0
            top_lines.append(f"{child.label}: {child.total():,.0f} ({percent:.1f}%)")
        self._stats_sunburst_top_detail.setText("\n".join(top_lines))

        context = self._stats_sunburst_selected_context
        lines: list[str] = []
        if context:
            required = float(context.get("required", 0.0) or 0.0)
            owned = float(context.get("owned", 0.0) or 0.0)
            shortage = float(context.get("shortage", 0.0) or 0.0)
            student_ids = context.get("student_ids")
            student_count = len(student_ids) if isinstance(student_ids, set) else 0
            if self._stats_sunburst_selected_path:
                lines.append("Path: " + " > ".join(self._stats_sunburst_selected_path))
            if student_count:
                lines.append(f"Students: {student_count:,}")
            training_sum = float(context.get("training_score_sum", 0.0) or 0.0)
            training_count = float(context.get("training_count", 0.0) or 0.0)
            if training_count > 0:
                lines.append(f"Training: {training_sum / training_count:.1f}%")
            if required or owned or shortage:
                coverage = 100.0 if required <= 0 else max(0.0, min(100.0, owned / required * 100.0))
                lines.append(f"Required: {_format_count(required, compact=True)}")
                lines.append(f"Owned: {_format_count(owned, compact=True)}")
                lines.append(f"Shortage: {_format_count(shortage, compact=True)}")
                lines.append(f"Coverage: {coverage:.1f}%")
            impacts = context.get("impacts")
            if isinstance(impacts, list) and impacts:
                lines.append("Impact TOP")
                for impact in sorted(impacts, key=lambda item: (-(item[4] if len(item) > 4 else 0), str(item[1])))[:6]:
                    if len(impact) >= 5:
                        lines.append(f"- {impact[1]}: {impact[2]} {_format_count(impact[3], compact=True)} / 부족 {_format_count(impact[4], compact=True)}")
        self._stats_sunburst_detail.setText("\n".join(lines) if lines else "선택된 segment가 없습니다.")
    def _refresh_stats_tab(self) -> None:
        if self._stats_cards_layout is None or self._stats_summary_host is None:
            return

        while self._stats_summary_cards.count():
            item = self._stats_summary_cards.takeAt(0)
            widget = item.widget()
            if widget is not None:
                widget.deleteLater()

        while self._stats_cards_layout.count():
            item = self._stats_cards_layout.takeAt(0)
            widget = item.widget()
            if widget is not None:
                widget.deleteLater()

        records = self._stats_scope_records()
        total = len(records)
        owned = sum(1 for record in records if record.owned)
        unowned = max(0, total - owned)
        goal_map = self._plan_goal_map()
        planned = sum(1 for record in records if record.student_id in goal_map)
        owned_records = [record for record in records if record.owned]
        planned_records = [record for record in records if record.student_id in goal_map]
        avg_level = round(sum((_int_or_none(record.level) or 0) for record in owned_records) / max(1, owned), 1) if owned else 0
        avg_star = round(sum(record.star for record in owned_records) / max(1, owned), 1) if owned else 0
        weapon_records = [record for record in owned_records if record.weapon_state in {"weapon_equipped", "weapon_unlocked_not_equipped"}]
        avg_weapon = round(sum((_int_or_none(record.weapon_level) or 0) for record in weapon_records) / max(1, len(weapon_records)), 1) if weapon_records else 0
        avg_ex = round(sum((_int_or_none(record.ex_skill) or 0) for record in owned_records) / max(1, owned), 1) if owned else 0
        normal_skill_values = [
            (_int_or_none(record.skill1) or 0) + (_int_or_none(record.skill2) or 0) + (_int_or_none(record.skill3) or 0)
            for record in owned_records
        ]
        avg_normal_skill = round(sum(normal_skill_values) / max(1, owned * 3), 1) if owned else 0
        avg_equip = round(
            sum(sum(self._stats_equipment_tier(record, index) for index in (1, 2, 3)) for record in owned_records) / max(1, owned * 3),
            1,
        ) if owned else 0
        avg_ability = round(
            sum((_int_or_none(record.stat_hp) or 0) + (_int_or_none(record.stat_atk) or 0) + (_int_or_none(record.stat_heal) or 0) for record in owned_records) / max(1, owned * 3),
            1,
        ) if owned else 0
        avg_score = round(sum(self._stats_growth_score(record) for record in owned_records) / max(1, owned), 1) if owned else 0
        avg_training = round(sum(self._stats_training_score(record) for record in owned_records) / max(1, owned), 1) if owned else 0
        complete_count = 0
        for record in planned_records:
            summary = self._cached_goal_cost(record.student_id, record=record, goal=goal_map.get(record.student_id), goal_map=goal_map)
            if not self._stats_summary_has_requirement(summary):
                complete_count += 1
        completion = round(complete_count / max(1, len(planned_records)) * 100.0, 1) if planned_records else 0
        planned_summary, _selected_count, contributing_count = self._resource_total_for_ids([record.student_id for record in planned_records], goal_map)
        shortage_count = 0
        if contributing_count:
            shortage_count = sum(1 for entry in self._plan_requirement_entries(planned_summary) if entry.required > entry.owned)

        summary_cards = (
            ("표시 중 학생", str(total), "현재 필터 기준"),
            ("보유율", f"{(owned / max(1, total) * 100.0):.1f}%", f"{owned} / {total}"),
            ("계획 편입률", f"{(planned / max(1, total) * 100.0):.1f}%", f"{planned} / {total}"),
            ("평균 레벨 / 성급", f"Lv.{avg_level} / ★{avg_star}", "보유 학생 기준"),
            ("육성 완성도", f"{avg_training:.1f}%", "기존 종합 점수 기준"),
        )
        for index, (label, value, sub) in enumerate(summary_cards):
            card = QFrame()
            card.setObjectName("summaryCard")
            card_layout = QVBoxLayout(card)
            card_layout.setContentsMargins(scale_px(14, self._ui_scale), scale_px(14, self._ui_scale), scale_px(14, self._ui_scale), scale_px(14, self._ui_scale))
            text_label = QLabel(label)
            text_label.setObjectName("metricLabel")
            value_label = QLabel(value)
            value_label.setObjectName("metricValue")
            sub_label = QLabel(sub)
            sub_label.setObjectName("kpiValueSub")
            card_layout.addWidget(text_label)
            card_layout.addWidget(value_label)
            card_layout.addWidget(sub_label)
            self._stats_summary_cards.addWidget(card, 0, index)
            self._stats_summary_cards.setColumnStretch(index, 1)

        if self._stats_scope_student_ids():
            self._stats_summary_line.setText(
                f"통계는 학생 탭에 현재 표시된 {len(self._filtered_students)}명 중 선버스트 선택 범위 {len(records)}명을 기준으로 합니다."
            )
        else:
            self._stats_summary_line.setText(f"통계는 학생 탭에 현재 표시된 {len(self._filtered_students)}명을 기준으로 합니다.")
        self._refresh_stats_sunburst()

        collection_options = (
            ("보유 여부", "owned"),
            ("학교", "school"),
            ("초기 성급", "rarity"),
            ("파밍", "farmable"),
            ("공격 타입", "attack_type"),
            ("방어 타입", "defense_type"),
            ("클래스", "combat_class"),
            ("역할", "role"),
            ("포지션", "position"),
            ("무기 타입", "weapon_type"),
            ("엄폐", "cover_type"),
            ("사거리", "range_type"),
            ("메인 오파츠", "growth_material_main"),
            ("서브 오파츠", "growth_material_sub"),
        )
        growth_options = (
            ("레벨 구간", "level_bucket"),
            ("성급", "star"),
            ("전용무기 상태", "weapon_state"),
            ("전용무기 성급", "weapon_star"),
            ("전용무기 레벨", "weapon_level"),
            ("EX 스킬", "ex_skill"),
            ("기본 스킬", "skill1"),
            ("강화 스킬", "skill2"),
            ("서브 스킬", "skill3"),
            ("일반 스킬 평균", "normal_skill_avg"),
            ("장비 평균 티어", "equipment_avg"),
            ("1번 장비", "equip1"),
            ("2번 장비", "equip2"),
            ("3번 장비", "equip3"),
            ("장비 슬롯 상태", "equipment_slot_status"),
            ("애용품", "equip4"),
            ("능력개방 HP", "ability_hp"),
            ("능력개방 ATK", "ability_atk"),
            ("능력개방 HEAL", "ability_heal"),
            ("직군별 육성도", "role_training"),
            ("종합 완성도", "growth_score"),
        )
        plan_options = (
            ("계획 포함 여부", "plan_membership"),
            ("계획 대상 보유율", "planned_owned_ratio"),
            ("목표 완료 여부", "plan_completion"),
            ("학생별 남은 성장량", "remaining_growth"),
            ("남은 재화 종류 많은 학생", "expensive_students"),
            ("목표 레벨", "target_level"),
            ("목표 성급", "target_star"),
            ("목표 전무", "target_weapon"),
            ("목표 EX", "target_ex"),
            ("목표 일반 스킬", "target_normal_skill"),
            ("목표 장비", "target_equipment"),
            ("목표 능력개방", "target_ability"),
            ("계획 전후 변화", "before_after_change"),
            ("계획 학교 구성", "planned_school"),
            ("계획 역할 구성", "planned_role"),
            ("계획 공격 타입", "planned_attack"),
            ("필요 재화 비율", "required_categories"),
            ("부족 재화 비율 TOP", "shortage_items"),
        )
        resource_options = (
            ("필요 재화 비율 TOP", "required_totals"),
            ("부족 재화 비율 TOP", "shortage_items"),
            ("부족률 TOP", "shortage_rate"),
            ("필요 카테고리 비율", "required_categories"),
            ("부족 카테고리 비율", "shortage_categories"),
            ("학교별 BD/노트", "school_demand"),
            ("오파츠 계열", "oopart_family"),
            ("장비 종류", "equipment_type"),
            ("장비 티어", "equipment_tier"),
        )
        skill_options = (
            ("버프", "skill_buff"),
            ("디버프", "skill_debuff"),
            ("CC", "skill_cc"),
            ("특수 효과", "skill_special"),
            ("회복 대상", "skill_heal_targets"),
            ("해제 대상", "skill_dispel_targets"),
            ("이동 대상", "skill_reposition_targets"),
            ("소환", "skill_summon_types"),
            ("패시브 스탯", "passive_stat"),
            ("전무 패시브", "weapon_passive_stat"),
            ("추가 패시브", "extra_passive_stat"),
            ("EX 범위 공격", "skill_is_area_damage"),
            ("엄폐 무시", "skill_ignore_cover"),
            ("넉백", "skill_knockback"),
        )

        if self._stats_collection_mode not in {value for _label, value in collection_options}:
            self._stats_collection_mode = "school"
        if self._stats_growth_mode not in {value for _label, value in growth_options}:
            self._stats_growth_mode = "level_bucket"
        if self._stats_plan_mode not in {value for _label, value in plan_options}:
            self._stats_plan_mode = "shortage_items"
        if self._stats_resource_mode not in {value for _label, value in resource_options}:
            self._stats_resource_mode = "shortage_items"
        if self._stats_skill_mode not in {value for _label, value in skill_options}:
            self._stats_skill_mode = "skill_buff"

        if self._stats_chart_tabs is not None:
            target_index = next(
                (index for index in range(self._stats_chart_tabs.count()) if self._stats_chart_tabs.tabData(index) == self._stats_active_chart_tab),
                0,
            )
            if self._stats_chart_tabs.currentIndex() != target_index:
                self._stats_chart_tabs.blockSignals(True)
                self._stats_chart_tabs.setCurrentIndex(target_index)
                self._stats_chart_tabs.blockSignals(False)

        chart_specs = {
            "collection": dict(
                title="분포 분석",
                subtitle="현재 root 범위",
                options=collection_options,
                current_value=self._stats_collection_mode,
                attr_name="_stats_collection_mode",
                rows=self._stats_field_rows(self._stats_collection_mode),
                chart_kind="distribution",
                compact_count=False,
            ),
            "growth": dict(
                title="분포 분석",
                subtitle="육성 상태 기준",
                options=growth_options,
                current_value=self._stats_growth_mode,
                attr_name="_stats_growth_mode",
                rows=self._stats_growth_rows(self._stats_growth_mode),
                chart_kind="bar",
                compact_count=False,
            ),
            "plan": dict(
                title="분포 분석",
                subtitle="계획 진행 기준",
                options=plan_options,
                current_value=self._stats_plan_mode,
                attr_name="_stats_plan_mode",
                rows=self._stats_plan_rows(self._stats_plan_mode),
                chart_kind="bar",
                compact_count=False,
            ),
            "resource": dict(
                title="분포 분석",
                subtitle="재화/인벤토리 기준",
                options=resource_options,
                current_value=self._stats_resource_mode,
                attr_name="_stats_resource_mode",
                rows=self._stats_resource_rows(self._stats_resource_mode),
                chart_kind="bar",
                compact_count=False,
            ),
            "skill": dict(
                title="분포 분석",
                subtitle="스킬/기능 태그 기준",
                options=skill_options,
                current_value=self._stats_skill_mode,
                attr_name="_stats_skill_mode",
                rows=self._stats_skill_rows(self._stats_skill_mode),
                chart_kind="bar",
                compact_count=False,
            ),
        }
        spec = chart_specs.get(self._stats_active_chart_tab, chart_specs["collection"])
        self._stats_add_chart_card(grid=self._stats_cards_layout, index=0, **spec)
    def _format_cost_summary(self, summary: PlanCostSummary) -> str:
        lines = [
            f"크레딧: {_format_count(summary.credits, compact=True)}",
            f"EXP: {_format_count(summary.level_exp, compact=True)}",
        ]
        if summary.level_exp_items:
            lines.append("활동 보고서:")
            for key, value in sorted(summary.level_exp_items.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.equipment_exp:
            lines.append(f"장비 EXP: {_format_count(summary.equipment_exp, compact=True)}")
        if summary.equipment_exp_items:
            lines.append("장비 강화석:")
            for key, value in sorted(summary.equipment_exp_items.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.weapon_exp:
            lines.append(f"무기 EXP: {_format_count(summary.weapon_exp, compact=True)}")
        if summary.weapon_exp_items:
            lines.append("무기 성장 재료:")
            for key, value in sorted(summary.weapon_exp_items.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.star_materials:
            lines.append("성급 재화:")
            for key, value in sorted(summary.star_materials.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.equipment_materials:
            lines.append("장비 재화:")
            for key, value in sorted(summary.equipment_materials.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.skill_books:
            lines.append("스킬북:")
            for key, value in sorted(summary.skill_books.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.ex_ooparts:
            lines.append("EX 오파츠:")
            for key, value in sorted(summary.ex_ooparts.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.skill_ooparts:
            lines.append("일반 스킬 오파츠:")
            for key, value in sorted(summary.skill_ooparts.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.favorite_item_materials:
            lines.append("애용품 재화:")
            for key, value in sorted(summary.favorite_item_materials.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.stat_materials:
            lines.append("능력개방 재화:")
            for key, value in sorted(summary.stat_materials.items(), key=lambda item: (-item[1], item[0])):
                lines.append(f"- {key}: {_format_count(value, compact=True)}")
        if summary.stat_levels:
            lines.append("능력개방 목표:")
            for key, value in sorted(summary.stat_levels.items()):
                lines.append(f"- {key}: +{value}")
        if summary.warnings:
            lines.append("메모:")
            for warning in dict.fromkeys(summary.warnings):
                lines.append(f"- {warning}")
        return "\n".join(lines)
