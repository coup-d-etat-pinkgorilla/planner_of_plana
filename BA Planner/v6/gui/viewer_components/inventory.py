"""InventoryTabComponent implementation extracted from the viewer façade."""

from __future__ import annotations

from gui import viewer_shared as _viewer_shared

globals().update({name: value for name, value in vars(_viewer_shared).items() if not name.startswith("__")})


class InventoryTabComponent:
    def _inventory_panel_margin(self) -> int:
        return scale_px(14, self._ui_scale)
    def _inventory_panel_gap(self) -> int:
        return scale_px(10, self._ui_scale)
    def _configure_inventory_panel_layout(
        self,
        layout: QHBoxLayout | QVBoxLayout | QGridLayout,
        *,
        margin: int | None = None,
        spacing: int | None = None,
    ) -> None:
        panel_margin = self._inventory_panel_margin() if margin is None else margin
        panel_spacing = self._inventory_panel_gap() if spacing is None else spacing
        layout.setContentsMargins(panel_margin, panel_margin, panel_margin, panel_margin)
        layout.setSpacing(panel_spacing)
    def _build_inventory_tab(self, root: QWidget) -> None:
        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, scale_px(12, self._ui_scale))
        layout.setSpacing(scale_px(12, self._ui_scale))

        header = QFrame()
        header.setObjectName("header")
        header_layout = QVBoxLayout(header)
        header_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        header_layout.setSpacing(scale_px(4, self._ui_scale))

        title = QLabel(_tr("inventory.title"))
        title.setObjectName("title")
        header_layout.addWidget(title)

        subtitle = QLabel(_tr("inventory.subtitle"))
        subtitle.setObjectName("count")
        subtitle.setWordWrap(True)
        header_layout.addWidget(subtitle)

        self._inventory_summary = QLabel(_tr("inventory.empty"))
        self._inventory_summary.setObjectName("filterSummary")
        self._inventory_summary.setWordWrap(True)
        header_layout.addWidget(self._inventory_summary)

        layout.addWidget(header)

        self._inventory_root_tabs = RoundedMaskTabWidget(ui_scale=self._ui_scale)
        self._inventory_root_tabs.setObjectName("inventoryRootTabs")
        self._inventory_root_tabs.tabBar().hide()
        self._inventory_root_tabs.currentChanged.connect(self._sync_inventory_mode_buttons)
        self._inventory_root_buttons: dict[int, QPushButton] = {}
        self._inventory_equipment_lists: dict[str, QListWidget] = {}
        self._inventory_equipment_summaries: dict[str, QLabel] = {}
        self._inventory_item_lists: dict[str, QListWidget] = {}
        self._inventory_item_summaries: dict[str, QLabel] = {}
        self._inventory_oopart_plan_usage: dict[str, InventoryOpartPlanUsage] = {}
        self._inventory_oopart_selected_id: str | None = None
        self._inventory_pool_pressure_mode = "equipment"
        self._inventory_pool_pressure_buttons: dict[str, QPushButton] = {}
        self._inventory_requirement_index: dict[str, PlanResourceRequirement] = {}
        self._inventory_pool_requirement_index: dict[str, PlanResourceRequirement] = {}

        equipment_root = QWidget()
        equipment_layout = QVBoxLayout(equipment_root)
        self._configure_inventory_panel_layout(equipment_layout, margin=0)
        self._inventory_equipment_tabs = InventorySubTabWidget(ui_scale=self._ui_scale)
        self._inventory_equipment_tabs.setObjectName("inventorySubTabs")
        self._inventory_equipment_tabs.tabBar().setObjectName("inventorySubTabBar")

        for series in EQUIPMENT_SERIES:
            series_label = _equipment_series_label(series.icon_key)
            tab = QWidget()
            tab.setObjectName("inventoryPaneContent")
            tab.setAutoFillBackground(False)
            tab.setAttribute(Qt.WA_TranslucentBackground, True)
            tab_layout = QVBoxLayout(tab)
            self._configure_inventory_panel_layout(tab_layout)

            summary = QLabel(_tr("inventory.no_scanned_category"))

            tab_layout.addWidget(InventoryColumnHeader(ui_scale=self._ui_scale))

            item_list = RoundedListWidget(ui_scale=self._ui_scale)
            item_list.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
            item_list.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
            item_list.currentItemChanged.connect(self._on_inventory_item_changed)
            tab_layout.addWidget(item_list, 1)
            self._inventory_equipment_tabs.addTab(tab, series_label)
            self._inventory_equipment_lists[series.icon_key] = item_list
            self._inventory_equipment_summaries[series.icon_key] = summary

        equipment_layout.addWidget(self._inventory_equipment_tabs, 1)
        self._inventory_root_tabs.addTab(equipment_root, _tr("inventory.root_equipment"))

        item_root = QWidget()
        item_layout = QVBoxLayout(item_root)
        self._configure_inventory_panel_layout(item_layout, margin=0)
        self._inventory_item_tabs = InventorySubTabWidget(ui_scale=self._ui_scale)
        self._inventory_item_tabs.setObjectName("inventorySubTabs")
        self._inventory_item_tabs.tabBar().setObjectName("inventorySubTabBar")

        for key, label in (
            ("ooparts", _tr("inventory.category.ooparts")),
            ("wb", _tr("inventory.category.wb")),
            ("stones", _tr("inventory.category.stones")),
            ("reports", _tr("inventory.category.reports")),
            ("weapon_parts", _tr("inventory.category.weapon_parts")),
            ("tech_notes", _tr("inventory.category.tech_notes")),
            ("bd", _tr("inventory.category.bd")),
            ("resources", _tr("inventory.category.resources")),
            ("elephs", _tr("inventory.category.elephs")),
            ("presents", _tr("inventory.category.presents")),
            ("other", _tr("inventory.category.other")),
        ):
            tab = QWidget()
            tab.setObjectName("inventoryPaneContent")
            tab.setAutoFillBackground(False)
            tab.setAttribute(Qt.WA_TranslucentBackground, True)
            tab_layout = QVBoxLayout(tab)
            self._configure_inventory_panel_layout(tab_layout)

            summary = QLabel(_tr("inventory.no_scanned_category"))

            tab_layout.addWidget(InventoryColumnHeader(ui_scale=self._ui_scale))

            item_list = RoundedListWidget(ui_scale=self._ui_scale)
            item_list.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
            item_list.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
            item_list.currentItemChanged.connect(self._on_inventory_item_changed)
            if key == "ooparts":
                item_list.currentItemChanged.connect(self._on_inventory_oopart_changed)
            tab_layout.addWidget(item_list, 1)
            self._inventory_item_tabs.addTab(tab, label)
            self._inventory_item_lists[key] = item_list
            self._inventory_item_summaries[key] = summary

        item_layout.addWidget(self._inventory_item_tabs, 1)
        self._inventory_root_tabs.addTab(item_root, _tr("inventory.root_items"))

        inventory_mode_panel = RoundedMaskFrame(ui_scale=self._ui_scale)
        inventory_mode_panel.setObjectName("inventoryContentPanel")
        inventory_mode_layout = QVBoxLayout(inventory_mode_panel)
        self._configure_inventory_panel_layout(inventory_mode_layout)

        inventory_mode_buttons = QHBoxLayout()
        inventory_mode_buttons.setContentsMargins(0, 0, 0, 0)
        inventory_mode_buttons.setSpacing(scale_px(8, self._ui_scale))
        for index, label in ((0, _tr("inventory.root_equipment")), (1, _tr("inventory.root_items"))):
            button = QPushButton(label)
            button.setObjectName("inventoryModeButton")
            button.setCheckable(True)
            button.clicked.connect(lambda _checked=False, value=index: self._set_inventory_root_mode(value))
            inventory_mode_buttons.addWidget(button, 0)
            self._inventory_root_buttons[index] = button
        inventory_mode_buttons.addStretch(1)
        sort_label = QLabel(_tr("inventory.sort_label"))
        sort_label.setObjectName("detailMiniSub")
        inventory_mode_buttons.addWidget(sort_label, 0, Qt.AlignVCenter)
        self._inventory_material_sort_mode = InventorySortDropdownButton()
        self._inventory_material_sort_mode.addItem(_tr("inventory.sort_category"), "category_tier_desc")
        self._inventory_material_sort_mode.addItem(_tr("inventory.sort_tier"), "tier_desc")
        self._inventory_material_sort_mode.modeChanged.connect(lambda *_: self._refresh_inventory_tab())
        inventory_mode_buttons.addWidget(self._inventory_material_sort_mode, 0, Qt.AlignVCenter)
        inventory_mode_layout.addLayout(inventory_mode_buttons)
        inventory_mode_layout.addWidget(self._inventory_root_tabs, 1)
        self._sync_inventory_mode_buttons()

        inventory_splitter = QSplitter(Qt.Horizontal)
        inventory_splitter.setObjectName("inventorySplitter")
        inventory_splitter.setChildrenCollapsible(False)

        overview_panel = QFrame()
        overview_panel.setObjectName("planSectionPanel")
        overview_panel.setMinimumWidth(scale_px(260, self._ui_scale))
        overview_layout = QVBoxLayout(overview_panel)
        self._configure_inventory_panel_layout(overview_layout)

        pressure_panel = QFrame()
        pressure_panel.setObjectName("planBand")
        pressure_layout = QVBoxLayout(pressure_panel)
        pressure_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(9, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        pressure_layout.setSpacing(scale_px(8, self._ui_scale))
        insight_title = QLabel(_tr("inventory.pressure_title"))
        insight_title.setObjectName("sectionTitle")
        pressure_layout.addWidget(insight_title)

        self._inventory_insight_summary = QLabel(_tr("inventory.pressure_empty"))
        self._inventory_insight_summary.setObjectName("detailSub")
        self._inventory_insight_summary.setTextFormat(Qt.RichText)
        self._inventory_insight_summary.setWordWrap(True)
        pressure_layout.addWidget(self._inventory_insight_summary)
        overview_layout.addWidget(pressure_panel, 0)

        plan_priority_panel = QFrame()
        plan_priority_panel.setObjectName("planBand")
        plan_priority_panel.setFixedHeight(scale_px(230, self._ui_scale))
        plan_priority_layout = QVBoxLayout(plan_priority_panel)
        plan_priority_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(8, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(8, self._ui_scale),
        )
        plan_priority_layout.setSpacing(scale_px(6, self._ui_scale))
        plan_priority_title = QLabel(_tr("inventory.plan_shortage_top"))
        plan_priority_title.setObjectName("detailSectionTitle")
        plan_priority_layout.addWidget(plan_priority_title)
        self._inventory_plan_priority_list = InventoryPriorityListWidget(ui_scale=self._ui_scale)
        self._configure_inventory_priority_cards(self._inventory_plan_priority_list)
        self._inventory_plan_priority_list.currentItemChanged.connect(self._on_inventory_priority_changed)
        plan_priority_layout.addWidget(self._inventory_plan_priority_list, 1)
        overview_layout.addWidget(plan_priority_panel, 0)

        pool_pressure_panel = QFrame()
        pool_pressure_panel.setObjectName("planBand")
        pool_pressure_panel.setFixedHeight(scale_px(230, self._ui_scale))
        pool_pressure_layout = QVBoxLayout(pool_pressure_panel)
        pool_pressure_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(8, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(8, self._ui_scale),
        )
        pool_pressure_layout.setSpacing(scale_px(6, self._ui_scale))
        pool_pressure_header = QHBoxLayout()
        pool_pressure_header.setContentsMargins(0, 0, 0, 0)
        pool_pressure_header.setSpacing(scale_px(5, self._ui_scale))
        pool_pressure_title = QLabel(_tr("inventory.full_pool_top"))
        pool_pressure_title.setObjectName("detailSectionTitle")
        pool_pressure_header.addWidget(pool_pressure_title, 1, Qt.AlignVCenter)
        for mode, label in (("equipment", "장비"), ("ooparts", "오파츠")):
            button = QPushButton(label)
            button.setObjectName("inventoryMiniModeButton")
            button.setCheckable(True)
            button.clicked.connect(lambda _checked=False, value=mode: self._set_inventory_pool_pressure_mode(value))
            self._inventory_pool_pressure_buttons[mode] = button
            pool_pressure_header.addWidget(button, 0, Qt.AlignVCenter)
        pool_pressure_layout.addLayout(pool_pressure_header)
        self._sync_inventory_pool_pressure_buttons()
        self._inventory_pool_pressure_list = InventoryPriorityListWidget(ui_scale=self._ui_scale)
        self._configure_inventory_priority_cards(self._inventory_pool_pressure_list)
        self._inventory_pool_pressure_list.currentItemChanged.connect(self._on_inventory_priority_changed)
        pool_pressure_layout.addWidget(self._inventory_pool_pressure_list, 1)
        overview_layout.addWidget(pool_pressure_panel, 0)

        bottleneck_panel = QFrame()
        bottleneck_panel.setObjectName("planBand")
        bottleneck_layout = QVBoxLayout(bottleneck_panel)
        bottleneck_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(8, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(8, self._ui_scale),
        )
        bottleneck_layout.setSpacing(scale_px(6, self._ui_scale))
        bottleneck_layout.setAlignment(Qt.AlignTop)
        bottleneck_title = QLabel(_tr("inventory.common_bottleneck"))
        bottleneck_title.setObjectName("detailSectionTitle")
        bottleneck_layout.addWidget(bottleneck_title)
        self._inventory_bottleneck_rows = QWidget()
        self._inventory_bottleneck_rows.setObjectName("planTransparent")
        self._inventory_bottleneck_rows_layout = QVBoxLayout(self._inventory_bottleneck_rows)
        self._inventory_bottleneck_rows_layout.setContentsMargins(0, scale_px(8, self._ui_scale), 0, 0)
        self._inventory_bottleneck_rows_layout.setSpacing(scale_px(7, self._ui_scale))
        bottleneck_layout.addWidget(self._inventory_bottleneck_rows, 0)

        school_panel = QFrame()
        self._inventory_school_risk_panel = school_panel
        school_panel.setObjectName("planBand")
        school_panel.setFixedHeight(scale_px(126, self._ui_scale))
        school_layout = QVBoxLayout(school_panel)
        school_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(7, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(7, self._ui_scale),
        )
        school_layout.setSpacing(scale_px(5, self._ui_scale))
        school_layout.setAlignment(Qt.AlignTop)
        school_title = QLabel(_tr("inventory.school_shortage"))
        school_title.setObjectName("detailSectionTitle")
        school_layout.addWidget(school_title)
        self._inventory_school_risk_rows_host = QWidget()
        self._inventory_school_risk_rows_host.setObjectName("planTransparent")
        self._inventory_school_risk_rows_layout = QVBoxLayout(self._inventory_school_risk_rows_host)
        self._inventory_school_risk_rows_layout.setContentsMargins(0, 0, 0, 0)
        self._inventory_school_risk_rows_layout.setSpacing(scale_px(5, self._ui_scale))
        school_layout.addWidget(self._inventory_school_risk_rows_host, 0)

        lower_pressure_stack = QWidget()
        lower_pressure_stack.setObjectName("planTransparent")
        lower_pressure_layout = QVBoxLayout(lower_pressure_stack)
        lower_pressure_layout.setContentsMargins(0, 0, 0, 0)
        lower_pressure_layout.setSpacing(scale_px(10, self._ui_scale))
        lower_pressure_layout.addWidget(bottleneck_panel, 1)
        lower_pressure_layout.addWidget(school_panel, 0)
        overview_layout.addWidget(lower_pressure_stack, 1)

        detail_shell = QFrame()
        detail_shell.setObjectName("planSectionPanel")
        detail_shell.setMinimumWidth(scale_px(360, self._ui_scale))
        detail_shell_layout = QVBoxLayout(detail_shell)
        self._configure_inventory_panel_layout(detail_shell_layout)

        detail_scroll = QScrollArea()
        detail_scroll.setObjectName("sectionScrollArea")
        detail_scroll.setFrameShape(QFrame.NoFrame)
        detail_scroll.setWidgetResizable(True)
        detail_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        detail_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)

        detail_panel = QWidget()
        detail_panel.setObjectName("planTransparent")
        detail_panel.setMinimumWidth(scale_px(320, self._ui_scale))
        detail_layout = QVBoxLayout(detail_panel)
        self._configure_inventory_panel_layout(detail_layout, margin=0)
        detail_scroll.setWidget(detail_panel)
        detail_shell_layout.addWidget(detail_scroll, 1)

        def build_detail_card() -> tuple[QFrame, QVBoxLayout]:
            card = QFrame()
            card.setObjectName("planBand")
            card_layout = QVBoxLayout(card)
            card_layout.setContentsMargins(
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
                scale_px(10, self._ui_scale),
            )
            card_layout.setSpacing(scale_px(8, self._ui_scale))
            return card, card_layout

        def add_detail_metric_rows(parent_layout: QVBoxLayout, rows: tuple[tuple[str, str], ...]) -> None:
            table = QGridLayout()
            table.setContentsMargins(0, 0, 0, 0)
            table.setHorizontalSpacing(scale_px(8, self._ui_scale))
            table.setVerticalSpacing(scale_px(6, self._ui_scale))
            table.setColumnStretch(0, 1)
            table.setColumnMinimumWidth(1, scale_px(118, self._ui_scale))
            for row, (key, label) in enumerate(rows):
                name_label = QLabel(label)
                name_label.setObjectName("detailMiniSub")
                value_label = QLabel("-")
                value_label.setObjectName("inventoryDetailMetricValue")
                value_label.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
                value_label.setMinimumWidth(scale_px(118, self._ui_scale))
                self._inventory_oopart_metric_labels[key] = value_label
                table.addWidget(name_label, row, 0)
                table.addWidget(value_label, row, 1)
            parent_layout.addLayout(table)

        self._inventory_oopart_metric_labels: dict[str, QLabel] = {}

        plan_detail_card, plan_detail_layout = build_detail_card()
        detail_header = QWidget()
        detail_header.setObjectName("planTransparent")
        detail_header_layout = QHBoxLayout(detail_header)
        detail_header_layout.setContentsMargins(0, 0, 0, 0)
        detail_header_layout.setSpacing(scale_px(10, self._ui_scale))
        self._inventory_oopart_detail_icon = QLabel()
        self._inventory_oopart_detail_icon.setFixedSize(scale_px(48, self._ui_scale), scale_px(48, self._ui_scale))
        self._inventory_oopart_detail_icon.setAlignment(Qt.AlignCenter)
        detail_header_layout.addWidget(self._inventory_oopart_detail_icon, 0, Qt.AlignVCenter)
        detail_title_stack = QVBoxLayout()
        detail_title_stack.setContentsMargins(0, 0, 0, 0)
        detail_title_stack.setSpacing(scale_px(4, self._ui_scale))
        self._inventory_oopart_detail_title = QLabel(_tr("inventory.detail.select_oopart"))
        self._inventory_oopart_detail_title.setObjectName("sectionTitle")
        detail_title_stack.addWidget(self._inventory_oopart_detail_title)
        self._inventory_oopart_detail_meta = QLabel("")
        self._inventory_oopart_detail_meta.setObjectName("inventoryStatus")
        self._inventory_oopart_detail_meta.setAlignment(Qt.AlignCenter)
        self._inventory_oopart_detail_meta.setVisible(False)
        detail_title_stack.addWidget(self._inventory_oopart_detail_meta, 0, Qt.AlignLeft)
        detail_header_layout.addLayout(detail_title_stack, 1)
        plan_detail_layout.addWidget(detail_header)
        add_detail_metric_rows(
            plan_detail_layout,
            (
                ("owned", _tr("inventory.detail.owned")),
                ("required", _tr("inventory.detail.plan_need")),
                ("shortage", _tr("inventory.detail.plan_short")),
                ("coverage", _tr("inventory.detail.plan_coverage")),
            ),
        )
        detail_layout.addWidget(plan_detail_card, 0)

        pool_detail_card, pool_detail_layout = build_detail_card()
        pool_title = QLabel(_tr("inventory.detail.full_growth"))
        pool_title.setObjectName("detailSectionTitle")
        pool_detail_layout.addWidget(pool_title)
        add_detail_metric_rows(
            pool_detail_layout,
            (
                ("pool_required", _tr("inventory.detail.full_pool_need")),
                ("pool_shortage", _tr("inventory.detail.pool_left")),
                ("pool_coverage", _tr("inventory.detail.full_coverage")),
            ),
        )
        detail_layout.addWidget(pool_detail_card, 0)

        hint_card, hint_layout = build_detail_card()
        hint_title = QLabel(_tr("inventory.detail.decision_hints"))
        hint_title.setObjectName("detailSectionTitle")
        hint_layout.addWidget(hint_title)
        self._inventory_oopart_next_hint = QLabel("-")
        self._inventory_oopart_next_hint.setObjectName("inventoryHintPink")
        self._inventory_oopart_next_hint.setWordWrap(True)
        hint_layout.addWidget(self._inventory_oopart_next_hint)
        self._inventory_oopart_farm_hint = QLabel("-")
        self._inventory_oopart_farm_hint.setObjectName("inventoryHintBlue")
        self._inventory_oopart_farm_hint.setWordWrap(True)
        hint_layout.addWidget(self._inventory_oopart_farm_hint)
        detail_layout.addWidget(hint_card, 0)

        student_card, student_layout = build_detail_card()
        affected_value = QLabel("-")
        affected_value.setObjectName("inventoryDetailMetricValue")
        affected_value.setAlignment(Qt.AlignLeft | Qt.AlignVCenter)
        self._inventory_oopart_metric_labels["affected"] = affected_value
        student_layout.addWidget(affected_value)
        breakdown_title = QLabel(_tr("inventory.detail.student_breakdown"))
        breakdown_title.setObjectName("detailSectionTitle")
        student_layout.addWidget(breakdown_title)

        self._inventory_oopart_impact_list = RoundedListWidget(ui_scale=self._ui_scale)
        self._inventory_oopart_impact_list.setIconSize(QSize(scale_px(34, self._ui_scale), scale_px(34, self._ui_scale)))
        self._inventory_oopart_impact_list.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self._inventory_oopart_impact_list.setFixedHeight(scale_px(80, self._ui_scale))
        self._inventory_oopart_impact_list.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self._inventory_oopart_impact_list.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        student_layout.addWidget(self._inventory_oopart_impact_list, 0)
        detail_layout.addWidget(student_card, 0)

        self._inventory_oopart_detail_summary = QLabel(_tr("inventory.detail.pick_item"))
        self._inventory_oopart_detail_summary.setVisible(False)
        self._inventory_oopart_family_shortage = QLabel("-")
        self._inventory_oopart_family_shortage.setVisible(False)

        inventory_splitter.addWidget(overview_panel)
        inventory_splitter.addWidget(inventory_mode_panel)
        inventory_splitter.addWidget(detail_shell)
        inventory_splitter.setStretchFactor(0, 1)
        inventory_splitter.setStretchFactor(1, 5)
        inventory_splitter.setStretchFactor(2, 1)
        inventory_splitter.setSizes([
            scale_px(260, self._ui_scale),
            scale_px(1180, self._ui_scale),
            scale_px(360, self._ui_scale),
        ])
        layout.addWidget(inventory_splitter, 1)
        self._refresh_inventory_tab()
    def _set_inventory_root_mode(self, index: int) -> None:
        if hasattr(self, "_inventory_root_tabs"):
            self._inventory_root_tabs.setCurrentIndex(index)
        self._sync_inventory_mode_buttons()
    def _sync_inventory_mode_buttons(self, *_args) -> None:
        buttons = getattr(self, "_inventory_root_buttons", {})
        tabs = getattr(self, "_inventory_root_tabs", None)
        current = tabs.currentIndex() if tabs is not None else 0
        for index, button in buttons.items():
            button.blockSignals(True)
            button.setChecked(index == current)
            button.blockSignals(False)
    def _set_inventory_pool_pressure_mode(self, mode: str) -> None:
        if mode not in {"equipment", "ooparts"}:
            mode = "equipment"
        self._inventory_pool_pressure_mode = mode
        self._sync_inventory_pool_pressure_buttons()
        if hasattr(self, "_inventory_pool_pressure_list"):
            self._refresh_inventory_insight_panel()
    def _sync_inventory_pool_pressure_buttons(self) -> None:
        mode = getattr(self, "_inventory_pool_pressure_mode", "equipment")
        for key, button in getattr(self, "_inventory_pool_pressure_buttons", {}).items():
            button.blockSignals(True)
            button.setChecked(key == mode)
            button.blockSignals(False)
    def _schedule_inventory_layout_sync(self) -> None:
        if not hasattr(self, "_inventory_root_tabs"):
            return
        QTimer.singleShot(0, self._sync_inventory_layout)
        QTimer.singleShot(80, self._sync_inventory_layout)
    def _sync_inventory_layout(self) -> None:
        widgets: list[QWidget] = []
        for name in ("_inventory_root_tabs", "_inventory_equipment_tabs", "_inventory_item_tabs"):
            widget = getattr(self, name, None)
            if isinstance(widget, QWidget):
                widgets.append(widget)
        for group_name in ("_inventory_equipment_lists", "_inventory_item_lists"):
            for widget in getattr(self, group_name, {}).values():
                if isinstance(widget, QWidget):
                    widgets.append(widget)
        for name in ("_inventory_plan_priority_list", "_inventory_pool_pressure_list", "_inventory_oopart_impact_list"):
            widget = getattr(self, name, None)
            if isinstance(widget, QWidget):
                widgets.append(widget)

        for widget in widgets:
            widget.updateGeometry()
            if widget.layout() is not None:
                widget.layout().activate()
            if isinstance(widget, RoundedListWidget):
                widget._schedule_sync_after_layout()
            elif isinstance(widget, RoundedMaskFrame):
                widget._schedule_mask()
    def _refresh_resource_aggregate_view(self) -> None:
        goal_map = self._plan_goal_map()
        student_ids = sorted(
            self._resource_selected_ids,
            key=lambda student_id: self._records_by_id[student_id].title.lower() if student_id in self._records_by_id else student_id,
        )
        summary, selected_count, contributing_count = self._resource_total_for_ids(student_ids, goal_map)
        planned_count = sum(1 for student_id in student_ids if student_id in goal_map)
        unplanned_count = max(0, selected_count - planned_count)
        unplanned_included = max(0, contributing_count - planned_count)
        self._resource_aggregate_summary.setText(
            f"선택 범위 {selected_count}명을 합산 중입니다. 계획 학생 {planned_count}명과 미계획 학생 {unplanned_included}/{unplanned_count}명이 현재 합계에 반영됩니다."
        )
        self._resource_requirement_grid_host.setUpdatesEnabled(False)
        try:
            self._clear_requirement_grid(self._resource_requirement_grid)
            self._resource_requirement_scroll.setVisible(True)
            if contributing_count == 0:
                self._resource_requirement_empty.setText("현재 선택 범위에서 필요한 재화가 없습니다.")
                self._resource_requirement_empty.setVisible(True)
                return
            entries = self._sort_resource_requirement_entries(self._plan_requirement_entries(summary))
            self._resource_requirement_empty.setText("" if entries else "현재 계산 범위에는 추가 재화가 필요하지 않습니다.")
            self._resource_requirement_empty.setVisible(True)
            if not entries:
                return
            shortages = sum(1 for entry in entries if entry.required > entry.owned)
            self._resource_aggregate_summary.setText(
                f"{len(entries)}종의 아이템 중 부족한 종류는 {shortages}개이며, 계획에 있는 학생 {planned_count}명과 포함되어 있지 않은 학생 {unplanned_included}명이 반영되어 있습니다."
            )
            self._populate_requirement_grid(self._resource_requirement_grid, entries)
        finally:
            self._resource_requirement_grid_host.setUpdatesEnabled(True)
    def _refresh_resource_inventory_view(self) -> None:
        self._refresh_inventory_tab()
        return
        if not hasattr(self, "_resource_inventory_output"):
            return
        self._resource_inventory_output.clear()
        inventory = self._inventory_snapshot or {}
        if not inventory:
            self._resource_inventory_summary.setText(_tr("inventory.empty"))
            self._resource_inventory_output.addItem("아이템 또는 장비 스캔을 실행하면 현재 인벤토리가 채워집니다.")
            return

        def sort_key(item: tuple[str, dict]) -> tuple[int, str]:
            _, payload = item
            raw_quantity = payload.get("quantity")
            try:
                quantity = int(str(raw_quantity).replace(",", ""))
            except Exception:
                quantity = -1
            name = str(payload.get("name") or item[0])
            return (-quantity, name)

        ordered = sorted(inventory.items(), key=sort_key)
        total_quantity = 0
        for _, payload in ordered:
            try:
                total_quantity += int(str(payload.get("quantity") or "0").replace(",", ""))
            except Exception:
                continue

        self._resource_inventory_summary.setText(
            f"현재 인벤토리 스냅샷 {len(ordered)}개 · 총 수량 {_format_count(total_quantity, compact=True)}"
        )
        for key, payload in ordered:
            name = str(payload.get("name") or key)
            quantity_value = _inventory_quantity_value(payload.get("quantity"))
            quantity = _format_count(quantity_value, compact=True) if quantity_value is not None else str(payload.get("quantity") or "?")
            item = QListWidgetItem(f"{name}: {quantity}")
            if quantity_value is not None:
                item.setToolTip(f"{name}: {_full_count_tooltip(quantity_value)}")
            self._resource_inventory_output.addItem(item)
    def _inventory_plan_requirement_index(self) -> dict[str, PlanResourceRequirement]:
        goal_map = self._plan_goal_map()
        total, _selected_count, _contributing_count = self._resource_total_for_ids(
            [goal.student_id for goal in self._plan.goals],
            goal_map,
        )
        entries = self._plan_requirement_entries(total)
        return {entry.key: entry for entry in entries}
    def _inventory_full_pool_goal_for_student(self, record: StudentRecord) -> StudentGoal:
        goal = StudentGoal(student_id=record.student_id)
        goal.target_level = MAX_TARGET_LEVEL
        goal.target_star = MAX_TARGET_STAR
        goal.target_ex_skill = MAX_TARGET_EX_SKILL
        goal.target_skill1 = MAX_TARGET_SKILL
        goal.target_skill2 = MAX_TARGET_SKILL
        goal.target_skill3 = MAX_TARGET_SKILL
        goal.target_equip1_tier = MAX_TARGET_EQUIP_TIER
        goal.target_equip2_tier = MAX_TARGET_EQUIP_TIER
        goal.target_equip3_tier = MAX_TARGET_EQUIP_TIER
        goal.target_equip1_level = MAX_TARGET_EQUIP_LEVEL
        goal.target_equip2_level = MAX_TARGET_EQUIP_LEVEL
        goal.target_equip3_level = MAX_TARGET_EQUIP_LEVEL
        if self._plan_allows_weapon_targets(record):
            goal.target_weapon_star = MAX_TARGET_WEAPON_STAR
            goal.target_weapon_level = MAX_TARGET_WEAPON_LEVEL
        if self._record_supports_unique_item(record):
            goal.target_equip4_tier = MAX_TARGET_EQUIP4_TIER
        goal.target_stat_hp = MAX_TARGET_STAT
        goal.target_stat_atk = MAX_TARGET_STAT
        goal.target_stat_heal = MAX_TARGET_STAT
        return goal
    def _inventory_full_pool_requirement_index(self) -> dict[str, PlanResourceRequirement]:
        total = PlanCostSummary()
        for record in self._all_students:
            goal = self._inventory_full_pool_goal_for_student(record)
            summary = self._cached_goal_cost(record.student_id, record=record, goal=goal)
            if summary is not None:
                total.merge(summary)
        entries = self._plan_requirement_entries(total)
        return {entry.key: entry for entry in entries}
    def _inventory_max_student_counts(self) -> tuple[int, int]:
        inventory_index = getattr(self, "_inventory_quantity_index_cache", {})
        report_exp = sum(
            inventory_index.get(f"Item_Icon_ExpItem_{tier}", 0) * value
            for tier, value in enumerate((50, 500, 2_000, 10_000))
        )
        stone_exp = sum(
            inventory_index.get(f"Equipment_Icon_Exp_{tier}", 0) * value
            for tier, value in enumerate((90, 360, 1_440, 5_760))
        )

        level_costs: list[int] = []
        equipment_costs: list[int] = []
        for record in self._all_students:
            goal = self._inventory_full_pool_goal_for_student(record)
            summary = self._cached_goal_cost(record.student_id, record=record, goal=goal)
            if summary is None:
                continue
            if summary.level_exp > 0:
                level_costs.append(summary.level_exp)
            if summary.equipment_exp > 0:
                equipment_costs.append(summary.equipment_exp)

        return (
            _max_affordable_student_count(report_exp, level_costs, max(level_costs, default=0)),
            _max_affordable_student_count(stone_exp, equipment_costs, max(equipment_costs, default=0)),
        )
    def _inventory_requirement_for_entry(
        self,
        item_id: str,
        name: str,
        requirement_index: dict[str, PlanResourceRequirement] | None = None,
    ) -> PlanResourceRequirement | None:
        requirement_index = requirement_index if requirement_index is not None else getattr(self, "_inventory_requirement_index", {})
        if item_id in requirement_index:
            return requirement_index[item_id]
        folded_name = name.casefold()
        for entry in requirement_index.values():
            if entry.name.casefold() == folded_name:
                return entry
        return None
    def _inventory_status_for_values(self, *, owned: int, required: int, pool_left: int = 0, tier: int = 0) -> str:
        if required > owned:
            return "고티어 병목" if tier >= 8 else "계획 부족"
        if pool_left > 0:
            return "장기적으로 부족"
        if required <= 0 and pool_left <= 0:
            return "미사용"
        return "충분"
    def _inventory_equipment_priority_statuses(self, entries: list[tuple[str, dict]]) -> dict[str, str]:
        requirement_index = getattr(self, "_inventory_requirement_index", {})
        ranked: list[tuple[int, int, str, str]] = []
        seen: set[str] = set()
        for item_key, payload in entries:
            item_id = payload.get("item_id")
            item_id_text = str(item_id) if item_id else str(item_key)
            if item_id_text in seen:
                continue
            seen.add(item_id_text)
            name = _inventory_display_label(item_key, payload)
            owned = _inventory_quantity_value(payload.get("quantity")) or 0
            requirement = self._inventory_requirement_for_entry(item_id_text, name, requirement_index)
            required = requirement.required if requirement is not None else 0
            shortage = max(0, required - owned)
            if shortage <= 0:
                continue
            tier = _tier_from_item_id_or_name(item_id_text, name)
            ranked.append((shortage, tier, name.casefold(), item_id_text))
        ranked.sort(key=lambda item: (-item[0], -item[1], item[2]))
        return {
            item_id: _inventory_priority_shortage_status(rank)
            for rank, (_shortage, _tier, _name, item_id) in enumerate(ranked[:3], start=1)
        }
    def _inventory_oopart_priority_statuses(
        self,
        oopart_usage: dict[str, InventoryOpartPlanUsage],
    ) -> dict[str, str]:
        ranked_by_tier: dict[int, list[tuple[int, int, str, str]]] = {4: [], 3: []}
        for item_id, usage in oopart_usage.items():
            shortage = usage.shortage
            if shortage <= 0:
                continue
            tier = _tier_from_item_id_or_name(item_id, usage.name)
            if tier not in ranked_by_tier:
                continue
            ranked_by_tier[tier].append((shortage, usage.required, usage.name.casefold(), item_id))

        statuses: dict[str, str] = {}
        for tier in (4, 3):
            ranked = ranked_by_tier[tier]
            ranked.sort(key=lambda item: (-item[0], -item[1], item[2]))
            if ranked:
                statuses[ranked[0][3]] = _inventory_priority_shortage_status(1)
        return statuses
    @staticmethod
    def _inventory_bottleneck_bucket(category: str) -> str:
        if category == "credits":
            return "크레딧"
        if category == "level_exp":
            return "레벨"
        if category in {"equipment_exp", "equipment_materials"}:
            return "장비"
        if category == "weapon_exp":
            return "무기"
        if category in {"skill_books", "ex_ooparts", "skill_ooparts"}:
            return "스킬"
        if category == "stat_materials":
            return "능력개방"
        return "기타"
    @staticmethod
    def _inventory_is_common_requirement_category(category: str) -> bool:
        return category in {
            "credits",
            "level_exp",
            "equipment_exp",
            "weapon_exp",
            "skill_books",
            "stat_materials",
            "equipment_materials",
        }
    def _inventory_common_bottleneck_rows(self) -> list[tuple[int, int, int, str]]:
        buckets: dict[str, list[int]] = defaultdict(lambda: [0, 0])
        for entry in self._inventory_requirement_index.values():
            if not self._inventory_is_common_requirement_category(entry.category):
                continue
            required = max(0, entry.required)
            shortage = max(0, entry.required - entry.owned)
            if required <= 0:
                continue
            bucket = self._inventory_bottleneck_bucket(entry.category)
            buckets[bucket][0] += shortage
            buckets[bucket][1] += required
        rows = []
        for bucket, (shortage, required) in buckets.items():
            if required <= 0:
                continue
            ratio = int((shortage / required) * 100) if shortage > 0 else 0
            coverage = max(0, min(100, 100 - ratio))
            rows.append((ratio, coverage, shortage, bucket))
        bucket_order = {
            "크레딧": 0,
            "레벨": 1,
            "장비": 2,
            "무기": 3,
            "스킬": 4,
            "능력개방": 5,
        }
        rows.sort(key=lambda item: (bucket_order.get(item[3], 99), -item[0], -item[1], item[3]))
        return rows
    def _inventory_common_bottleneck_text(self) -> str:
        rows = self._inventory_common_bottleneck_rows()
        rows = [(ratio, shortage, bucket) for ratio, _coverage, shortage, bucket in rows]
        if not rows:
            return "현재 계획의 공통 재화 병목이 없습니다."
        return "\n".join(f"{bucket}: {ratio}% 부족 ({_format_count(shortage, compact=True)})" for ratio, shortage, bucket in rows)
    def _inventory_plan_diagnosis_text(self) -> str:
        coverage_rows = self._inventory_common_bottleneck_rows()
        coverage = 100.0 if not coverage_rows else sum(row[1] for row in coverage_rows) / len(coverage_rows)

        bottleneck_rows = [row for row in coverage_rows if row[2] > 0]
        if bottleneck_rows:
            _shortage_ratio, _bucket_coverage, _shortage, bucket = max(
                bottleneck_rows,
                key=lambda row: (row[0], row[2], row[3]),
            )
            bottleneck = bucket
            recommendations = {
                "크레딧": "크레딧 확보 우선",
                "레벨": "활동 보고서 확보 우선",
                "장비": "장비 재료 파밍 우선",
                "무기": "무기 성장 재료 확보",
                "스킬": "BD/기술 노트/오파츠 우선",
                "능력개방": "WB 확보 우선",
            }
            action = recommendations.get(bucket, "부족률 높은 재화부터 확보")
        else:
            bottleneck = "없음"
            action = "현재 계획 유지"

        return (
            f'<div style="color:{MUTED}; margin-bottom:5px;">재화 충족률 : {coverage:.1f}%</div>'
            f'<div style="color:{MUTED}; margin-bottom:5px;">가장 큰 병목 요소 : {escape(bottleneck)}</div>'
            f'<div style="color:{MUTED};">행동 추천 : {escape(action)}</div>'
        )
    def _inventory_pool_pressure_rows(self) -> list[tuple[str, InventoryOpartPlanUsage | PlanResourceRequirement, int, str]]:
        mode = getattr(self, "_inventory_pool_pressure_mode", "equipment")
        if mode == "ooparts":
            rows: list[tuple[str, InventoryOpartPlanUsage | PlanResourceRequirement, int, str]] = [
                ("usage", usage, usage.pool_shortage, usage.name.lower())
                for usage in self._inventory_oopart_plan_usage.values()
                if usage.pool_shortage > 0
            ]
        else:
            rows = [
                ("requirement", entry, entry.required - entry.owned, entry.name.lower())
                for entry in self._inventory_pool_requirement_index.values()
                if entry.category == "equipment_materials" and entry.required > entry.owned
            ]
        rows.sort(key=lambda row: (-row[2], row[3]))
        return rows[:5]
    def _refresh_inventory_common_bottleneck_summary(self) -> None:
        layout = getattr(self, "_inventory_bottleneck_rows_layout", None)
        if layout is None:
            return
        self._clear_layout_widgets(layout)
        rows = self._inventory_common_bottleneck_rows()
        if not rows:
            label = QLabel("현재 계획의 공통 재화 병목이 없습니다.")
            label.setObjectName("detailSub")
            label.setWordWrap(True)
            layout.addWidget(label)
            return
        for shortage_ratio, coverage, shortage, bucket in rows:
            row = QWidget()
            row.setObjectName("planTransparent")
            row_layout = QHBoxLayout(row)
            row_layout.setContentsMargins(0, 0, 0, 0)
            row_layout.setSpacing(scale_px(6, self._ui_scale))

            name_label = QLabel(bucket)
            name_label.setObjectName("inventoryBottleneckName")
            name_label.setAlignment(Qt.AlignCenter)
            name_label.setFixedWidth(scale_px(58, self._ui_scale))
            row_layout.addWidget(name_label, 0, Qt.AlignVCenter)

            bar = QProgressBar()
            bar.setObjectName("inventoryBottleneckBar")
            bar.setTextVisible(False)
            bar.setFixedHeight(scale_px(7, self._ui_scale))
            bar.setValue(coverage)
            bar.setToolTip(f"충족률 {coverage}% · 부족 {_full_count_tooltip(shortage)}")
            row_layout.addWidget(bar, 1, Qt.AlignVCenter)

            value_label = QLabel(f"{coverage}%")
            value_label.setObjectName("inventoryBottleneckRatio")
            value_label.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
            value_label.setFixedWidth(scale_px(34, self._ui_scale))
            value_label.setToolTip(f"부족률 {shortage_ratio}% · 부족 {_full_count_tooltip(shortage)}")
            row_layout.addWidget(value_label, 0, Qt.AlignVCenter)
            layout.addWidget(row)
    def _inventory_school_risk_rows(self) -> list[tuple[int, int, int, str, dict[str, int]]]:
        inventory_index = getattr(self, "_inventory_quantity_index_cache", {})
        required_by_school: dict[str, dict[str, int]] = defaultdict(lambda: {"BD": 0, "기술 노트": 0})
        item_ids_by_school: dict[str, set[str]] = defaultdict(set)

        for record in self._all_students:
            school = (record.school or "ETC").strip() or "ETC"
            goal = self._inventory_full_pool_goal_for_student(record)
            summary = self._cached_goal_cost(record.student_id, record=record, goal=goal)
            if summary is None:
                continue
            for entry in self._plan_requirement_entries(summary, record=record):
                item_id = entry.key
                match = re.match(r"Item_Icon_Material_ExSkill_([^_]+)_", item_id)
                if match:
                    school_key = match.group(1)
                    required_by_school[school_key]["BD"] += entry.required
                    item_ids_by_school[school_key].add(item_id)
                    continue
                match = re.match(r"Item_Icon_SkillBook_([^_]+)_", item_id)
                if match and "Ultimate" not in item_id:
                    school_key = match.group(1)
                    required_by_school[school_key]["기술 노트"] += entry.required
                    item_ids_by_school[school_key].add(item_id)

        rows: list[tuple[int, int, int, str, dict[str, int]]] = []
        for school, values in required_by_school.items():
            required = values["BD"] + values["기술 노트"]
            if required <= 0:
                continue
            owned = sum(max(0, int(inventory_index.get(item_id, 0))) for item_id in item_ids_by_school.get(school, set()))
            shortage = max(0, required - owned)
            if shortage <= 0:
                continue
            coverage = max(0, min(100, int((owned / required) * 100)))
            rows.append((coverage, shortage, required, school, values))
        rows.sort(key=lambda row: (row[0], -row[1], row[3]))
        return rows[:3]
    def _refresh_inventory_school_risk_summary(self) -> None:
        layout = getattr(self, "_inventory_school_risk_rows_layout", None)
        if layout is None:
            return
        self._clear_layout_widgets(layout)
        rows = self._inventory_school_risk_rows()
        if not rows:
            label = QLabel("재화 부족 위험 학교가 없습니다.")
            label.setObjectName("detailSub")
            label.setWordWrap(True)
            layout.addWidget(label)
            return

        spacing = scale_px(5, self._ui_scale)
        row_host_height = self._inventory_school_risk_rows_host.height()
        if row_host_height <= 0 and hasattr(self, "_inventory_school_risk_panel"):
            row_host_height = max(
                1,
                self._inventory_school_risk_panel.height()
                - scale_px(14, self._ui_scale)
                - scale_px(22, self._ui_scale)
                - spacing,
            )
        available_row_height = max(1, row_host_height - spacing * max(0, len(rows) - 1))
        icon_size = max(
            scale_px(18, self._ui_scale),
            min(scale_px(30, self._ui_scale), available_row_height // max(1, len(rows))),
        )
        for coverage, shortage, required, school, values in rows:
            row = QWidget()
            row.setObjectName("planTransparent")
            row_layout = QHBoxLayout(row)
            row_layout.setContentsMargins(0, 0, 0, 0)
            row_layout.setSpacing(scale_px(6, self._ui_scale))

            icon = QLabel()
            icon.setFixedSize(scale_px(50, self._ui_scale), icon_size)
            icon.setAlignment(Qt.AlignCenter)
            logo_path = _school_logo_tinted_path(school, size=icon_size)
            if logo_path is not None and logo_path.exists():
                pixmap = QPixmap(str(logo_path))
                if not pixmap.isNull():
                    icon.setPixmap(pixmap.scaled(icon_size, icon_size, Qt.KeepAspectRatio, Qt.SmoothTransformation))
            row_layout.addWidget(icon, 0, Qt.AlignCenter)

            bar = QProgressBar()
            bar.setObjectName("inventorySchoolRiskBar")
            bar.setTextVisible(False)
            bar.setFixedHeight(scale_px(7, self._ui_scale))
            bar.setValue(coverage)
            bar.setToolTip(
                f"{school}\n충족률 {coverage}% · 부족 {_full_count_tooltip(shortage)} / 필요 {_full_count_tooltip(required)}\n"
                f"BD {_format_count(values['BD'], compact=True)} · 기술 노트 {_format_count(values['기술 노트'], compact=True)}"
            )
            row_layout.addWidget(bar, 1, Qt.AlignVCenter)

            percent = QLabel(f"{coverage}%")
            percent.setObjectName("inventorySchoolRiskPercent")
            percent.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
            percent.setFixedWidth(scale_px(34, self._ui_scale))
            row_layout.addWidget(percent, 0, Qt.AlignVCenter)
            layout.addWidget(row)
    def _inventory_school_shortage_text(self) -> str:
        school_totals: dict[str, dict[str, int]] = defaultdict(lambda: {"BD": 0, "TN": 0})
        wb_totals: dict[str, int] = defaultdict(int)
        for entry in self._inventory_requirement_index.values():
            shortage = max(0, entry.required - entry.owned)
            if shortage <= 0:
                continue
            item_id = entry.key
            match = re.match(r"Item_Icon_Material_ExSkill_([^_]+)_", item_id)
            if match:
                school_totals[match.group(1)]["BD"] += shortage
                continue
            match = re.match(r"Item_Icon_SkillBook_([^_]+)_", item_id)
            if match and "Ultimate" not in item_id:
                school_totals[match.group(1)]["TN"] += shortage
                continue
            if item_id in _WORKBOOK_ID_TO_NAME:
                wb_totals[_WORKBOOK_ID_TO_NAME[item_id].replace(" WB", "")] += shortage
        school_rows = [
            (values["BD"] + values["TN"], school, values)
            for school, values in school_totals.items()
            if values["BD"] or values["TN"]
        ]
        school_rows.sort(key=lambda item: (-item[0], item[1]))
        lines = []
        icon_size = scale_px(36, getattr(self, "_ui_scale", 1.0))
        for _total, school, values in school_rows[:4]:
            logo_path = _school_logo_tinted_path(school, size=icon_size)
            counts = f"BD {values['BD']:,} · 기술 노트 {values['TN']:,}"
            if logo_path is not None:
                logo_src = escape(logo_path.as_posix(), quote=True)
                lines.append(
                    f'<img src="{logo_src}" width="{icon_size}" height="{icon_size}"> '
                    f'<span style="vertical-align:middle;">{escape(counts)}</span>'
                )
            else:
                lines.append(f"{escape(school)} {escape(counts)}")
        if wb_totals:
            wb_text = ", ".join(f"{name} {amount:,}" for name, amount in sorted(wb_totals.items()))
            lines.append(f"WB: {escape(wb_text)}")
        return "<br>".join(lines) if lines else "현재 계획의 BD, 기술 노트, WB 부족이 없습니다."
    def _inventory_material_sort_mode_key(self) -> str:
        selector = getattr(self, "_inventory_material_sort_mode", None)
        value = selector.currentData() if selector is not None else None
        return str(value or "category_tier_desc")
    def _inventory_oopart_sort_key(self, entry: tuple[str, dict]) -> tuple[int, int, str]:
        item_id = str(entry[1].get("item_id") or "")
        family_order = {
            definition.icon_key: index
            for index, definition in enumerate(OPART_DEFINITIONS)
        }
        match = re.match(r"Item_Icon_Material_(.+)_(\d+)$", item_id)
        if not match:
            return (9999, 9999, _inventory_display_label(entry[0], entry[1]).lower())
        family = match.group(1)
        tier_index = int(match.group(2))
        family_index = family_order.get(family, 9999)
        name = _inventory_display_label(entry[0], entry[1]).lower()
        if self._inventory_material_sort_mode_key() == "tier_desc":
            return (-tier_index, family_index, name)
        return (family_index, -tier_index, name)
    def _inventory_school_material_sort_key(self, entry: tuple[str, dict], *, material: str) -> tuple[int, int, str]:
        item_id = str(entry[1].get("item_id") or "")
        school_order = {school: index for index, school in enumerate(_SCHOOL_SEQUENCE)}
        if material == "bd":
            pattern = r"Item_Icon_Material_ExSkill_([^_]+)_(\d+)$"
        else:
            if item_id == "Item_Icon_SkillBook_Ultimate_Piece":
                return (9998, 9998, _inventory_display_label(entry[0], entry[1]).lower())
            pattern = r"Item_Icon_SkillBook_([^_]+)_(\d+)$"
        match = re.match(pattern, item_id)
        if not match:
            return (9999, 9999, _inventory_display_label(entry[0], entry[1]).lower())
        school = match.group(1)
        tier_index = int(match.group(2))
        school_index = school_order.get(school, 9999)
        name = _inventory_display_label(entry[0], entry[1]).lower()
        if self._inventory_material_sort_mode_key() == "tier_desc":
            return (-tier_index, school_index, name)
        return (school_index, -tier_index, name)
    def _inventory_build_oopart_plan_usage(self) -> dict[str, InventoryOpartPlanUsage]:
        usage_by_item: dict[str, InventoryOpartPlanUsage] = {}
        impact_by_item: dict[str, dict[str, InventoryOpartStudentImpact]] = {}
        pool_impact_by_item: dict[str, dict[str, InventoryOpartStudentImpact]] = {}

        def add_summary(
            *,
            record: StudentRecord,
            summary: PlanCostSummary,
            target_usage_by_item: dict[str, InventoryOpartPlanUsage],
            target_impact_by_item: dict[str, dict[str, InventoryOpartStudentImpact]],
            pool: bool,
        ) -> None:
            for category, values, impact_field in (
                ("ex_ooparts", summary.ex_ooparts, "ex_required"),
                ("skill_ooparts", summary.skill_ooparts, "skill_required"),
            ):
                for key, raw_required in values.items():
                    required = int(raw_required or 0)
                    if required <= 0:
                        continue
                    item_id = _plan_resource_item_id(key, category)
                    if not item_id or item_id not in _OPART_ITEM_IDS:
                        continue
                    name = _plan_resource_display_name(item_id, key)
                    usage = target_usage_by_item.get(item_id)
                    if usage is None:
                        usage = InventoryOpartPlanUsage(item_id=item_id, name=name)
                        target_usage_by_item[item_id] = usage
                    if pool:
                        usage.pool_required += required
                        if impact_field == "ex_required":
                            usage.pool_ex_required += required
                        else:
                            usage.pool_skill_required += required
                    else:
                        usage.required += required
                        if impact_field == "ex_required":
                            usage.ex_required += required
                        else:
                            usage.skill_required += required

                    impacts = target_impact_by_item.setdefault(item_id, {})
                    impact = impacts.get(record.student_id)
                    if impact is None:
                        impact = InventoryOpartStudentImpact(student_id=record.student_id, title=record.title)
                        impacts[record.student_id] = impact
                    if impact_field == "ex_required":
                        impact.ex_required += required
                    else:
                        impact.skill_required += required

        priority_index = self._plan_priority_index()

        for goal in self._plan.goals:
            record = self._records_by_id.get(goal.student_id)
            if record is None:
                continue
            summary = self._cached_goal_cost(goal.student_id, record=record, goal=goal)
            if summary is None:
                continue
            add_summary(
                record=record,
                summary=summary,
                target_usage_by_item=usage_by_item,
                target_impact_by_item=impact_by_item,
                pool=False,
            )

        for record in self._all_students:
            goal = StudentGoal(student_id=record.student_id)
            goal.target_ex_skill = MAX_TARGET_EX_SKILL
            goal.target_skill1 = MAX_TARGET_SKILL
            goal.target_skill2 = MAX_TARGET_SKILL
            goal.target_skill3 = MAX_TARGET_SKILL
            summary = self._cached_goal_cost(record.student_id, record=record, goal=goal)
            if summary is None:
                continue
            add_summary(
                record=record,
                summary=summary,
                target_usage_by_item=usage_by_item,
                target_impact_by_item=pool_impact_by_item,
                pool=True,
            )

        for item_id, usage in usage_by_item.items():
            usage.owned = self._inventory_quantity_index_cache.get(item_id, 0)
            usage.impacts = sorted(
                impact_by_item.get(item_id, {}).values(),
                key=lambda impact: (
                    priority_index.get(impact.student_id, 999999),
                    impact.title.lower(),
                    impact.student_id,
                ),
            )
            usage.pool_impacts = sorted(
                pool_impact_by_item.get(item_id, {}).values(),
                key=lambda impact: (
                    priority_index.get(impact.student_id, 999999),
                    -impact.total_required,
                    impact.title.lower(),
                    impact.student_id,
                ),
            )
        return usage_by_item
    @staticmethod
    def _inventory_coverage(owned: int, required: int) -> str:
        if required <= 0:
            return "-"
        return f"{min(100, int((owned / required) * 100))}%"
    def _inventory_oopart_status(self, usage: InventoryOpartPlanUsage | None) -> str:
        if usage is None or (usage.required <= 0 and usage.pool_required <= 0):
            return "미사용"
        if usage.shortage > 0:
            return "계획 부족"
        if usage.pool_shortage > 0:
            return "장기적으로 부족"
        return "충분"
    def _clear_inventory_oopart_metrics(self) -> None:
        for label in getattr(self, "_inventory_oopart_metric_labels", {}).values():
            label.setText("-")
    def _set_inventory_metric(self, key: str, value: str) -> None:
        label = getattr(self, "_inventory_oopart_metric_labels", {}).get(key)
        if label is not None:
            label.setText(value)
    def _set_inventory_metric_number(self, key: str, value: int, *, compact: bool = True, signed: bool = False, empty_zero: bool = False) -> None:
        label = getattr(self, "_inventory_oopart_metric_labels", {}).get(key)
        if label is None:
            return
        if empty_zero and value <= 0:
            label.setText("-")
            label.setToolTip("-")
            return
        label.setText(_format_count(value, compact=compact, signed=signed))
        label.setToolTip(_full_count_tooltip(value))
    def _set_inventory_detail_status(self, status: str | None) -> None:
        label = getattr(self, "_inventory_oopart_detail_meta", None)
        if label is None:
            return
        if not status:
            label.setText("")
            label.setToolTip("")
            label.setProperty("status", "")
            label.setVisible(False)
        else:
            status_text = _inventory_status_label(status)
            label.setText(status_text)
            label.setToolTip(status_text)
            label.setProperty("status", _inventory_status_key(status))
            label.setVisible(True)
        label.style().unpolish(label)
        label.style().polish(label)
    def _set_inventory_detail_icon(self, item_id: str | None, name: str) -> None:
        icon_label = getattr(self, "_inventory_oopart_detail_icon", None)
        if icon_label is None:
            return
        icon_path = _inventory_icon_path(item_id, name)
        if icon_path is not None and icon_path.exists():
            pixmap = _item_icon_pixmap(size=icon_label.size(), item_id=item_id, icon_path=icon_path)
            if not pixmap.isNull():
                icon_label.setPixmap(pixmap)
                return
        icon_label.setPixmap(QPixmap())
    def _resize_inventory_impact_list_to_contents(self) -> None:
        target = getattr(self, "_inventory_oopart_impact_list", None)
        if target is None:
            return
        minimum = scale_px(80, self._ui_scale)
        height = target.frameWidth() * 2 + scale_px(8, self._ui_scale)
        for index in range(target.count()):
            item = target.item(index)
            hint = item.sizeHint()
            height += hint.height() if hint.isValid() else scale_px(28, self._ui_scale)
        if target.count() > 1:
            height += max(0, target.count() - 1) * max(0, target.spacing())
        target.setFixedHeight(max(minimum, height))
    def _clear_inventory_detail_hints(self) -> None:
        for attr in (
            "_inventory_oopart_next_hint",
            "_inventory_oopart_farm_hint",
            "_inventory_oopart_family_shortage",
        ):
            label = getattr(self, attr, None)
            if label is not None:
                label.setText("-")
    def _inventory_student_icon(self, student_id: str) -> QIcon:
        size = scale_px(34, self._ui_scale)
        source = ensure_thumbnail(student_id, size, size)
        if source is not None and source.exists():
            pixmap = QPixmap(str(source))
            if not pixmap.isNull():
                return QIcon(pixmap.scaled(size, size, Qt.KeepAspectRatio, Qt.SmoothTransformation))
        return make_placeholder_icon(size, size)
    def _inventory_student_pixmap(self, student_id: str, size: int) -> QPixmap:
        source = ensure_thumbnail(student_id, size, size)
        if source is None or not source.exists():
            return QPixmap()
        pixmap = QPixmap(str(source))
        return pixmap if not pixmap.isNull() else QPixmap()
    def _inventory_oopart_family_shortage_text(self, item_id: str) -> str:
        prefix = "_".join(item_id.rsplit("_", 1)[:-1])
        if not prefix:
            return "-"
        rows: list[str] = []
        for tier_index in range(3, -1, -1):
            sibling_id = f"{prefix}_{tier_index}"
            usage = self._inventory_oopart_plan_usage.get(sibling_id)
            if usage is None:
                continue
            shortage = usage.shortage or usage.pool_shortage
            if shortage > 0:
                label = f"T{tier_index + 1}"
                sign = "-" if usage.shortage > 0 else "전체 육성 -"
                rows.append(f"{label}: {sign}{_format_count(shortage, compact=True)}")
        return "\n".join(rows) if rows else "같은 계열 부족이 없습니다."
    def _inventory_oopart_decision_hints(self, usage: InventoryOpartPlanUsage) -> tuple[str, str]:
        if usage.shortage > 0:
            top = usage.impacts[0] if usage.impacts else None
            if top is not None:
                next_hint = f"다음 목표\n{top.title}의 육성에 {_format_count(top.total_required, compact=True)}개가 더 필요합니다."
            else:
                next_hint = f"다음 목표\n현재 계획 수요를 충족하려면 {_format_count(usage.shortage, compact=True)}개 더 필요합니다."
            farm_hint = f"파밍 우선순위\n높습니다. 현재 계획 학생 중 {len(usage.impacts):,}명이 더 필요로 합니다."
            return next_hint, farm_hint
        if usage.pool_shortage > 0:
            next_hint = f"다음 목표\n현재 계획은 충족되었지만 전체 육성 기준으로는 {_format_count(usage.pool_shortage, compact=True)}개가 더 필요합니다."
            farm_hint = "파밍 우선순위\n현재는 괜찮지만, 전체 학생 육성 기준으로는 장기적으로 부족할 수 있습니다."
            return next_hint, farm_hint
        return (
            "다음 목표\n현재 계획과 알려진 전체 육성 수요가 모두 충족됐습니다.",
            "파밍 우선순위\n현재는 파밍을 안해도 괜찮습니다.",
        )
        if usage.shortage > 0:
            top = usage.impacts[0] if usage.impacts else None
            if top is not None:
                need_parts = []
                if top.ex_required:
                    need_parts.append(f"EX {_format_count(top.ex_required, compact=True)}")
                if top.skill_required:
                    need_parts.append(f"일반 {_format_count(top.skill_required, compact=True)}")
                need_text = " / ".join(need_parts) or _format_count(top.total_required, compact=True)
                next_hint = f"다음 목표\n{top.title} ({need_text})까지 {_format_count(usage.shortage, compact=True)}개 더 필요합니다."
            else:
                next_hint = f"다음 목표\n현재 계획 수요를 해소하려면 {_format_count(usage.shortage, compact=True)}개 더 필요합니다."
            farm_hint = f"파밍 우선순위\n높음 - 현재 계획 학생 {len(usage.impacts):,}명을 막고 있습니다."
        elif usage.pool_shortage > 0:
            next_hint = f"다음 목표\n현재 계획은 충족됐지만 전체 육성 기준 {_format_count(usage.pool_shortage, compact=True)}개가 더 필요합니다."
            farm_hint = f"파밍 우선순위\n중간 - 전체 육성 {len(usage.pool_impacts):,}명 기준 장기적으로 부족합니다."
        else:
            next_hint = "다음 목표\n현재 계획과 알려진 전체 육성 수요가 모두 충족됐습니다."
            farm_hint = "파밍 우선순위\n지금은 낮음."
        return next_hint, farm_hint
    def _inventory_common_decision_hints(
        self,
        *,
        name: str,
        shortage: int,
        pool_left: int,
        consumers: list[tuple[str, str, int]],
        pool_consumers: list[tuple[str, str, int]],
    ) -> tuple[str, str]:
        if shortage > 0:
            if consumers:
                _student_id, title, amount = consumers[0]
                next_hint = f"다음 목표\n{title}의 육성에 {_format_count(amount, compact=True)}개가 더 필요합니다."
            else:
                next_hint = f"다음 목표\n현재 계획 수요를 충족하려면 {_format_count(shortage, compact=True)}개 더 필요합니다."
            farm_hint = f"파밍 우선순위\n높습니다. 현재 계획 학생 중 {len(consumers):,}명이 더 필요로 합니다."
            return next_hint, farm_hint
        if pool_left > 0:
            next_hint = f"다음 목표\n현재 계획은 충족되었지만 전체 육성 기준으로는 {_format_count(pool_left, compact=True)}개가 더 필요합니다."
            farm_hint = "파밍 우선순위\n현재는 괜찮지만, 전체 학생 육성 기준으로는 장기적으로 부족할 수 있습니다."
            return next_hint, farm_hint
        return (
            "다음 목표\n현재 계획과 알려진 전체 육성 수요가 모두 충족됐습니다.",
            "파밍 우선순위\n현재는 파밍을 안해도 괜찮습니다.",
        )
        if shortage > 0:
            if consumers:
                _student_id, title, amount = consumers[0]
                next_hint = f"다음 목표\n{title} 목표를 열려면 {_format_count(shortage, compact=True)}개 더 필요합니다. (학생 필요 {_format_count(amount, compact=True)})"
            else:
                next_hint = f"다음 목표\n현재 계획 수요를 해소하려면 {_format_count(shortage, compact=True)}개 더 필요합니다."
            farm_hint = f"파밍 우선순위\n높음 - 현재 계획 학생 {len(consumers):,}명을 막고 있습니다."
        elif pool_left > 0:
            next_hint = f"다음 목표\n현재 계획은 충족됐지만 전체 육성 기준 {name} {_format_count(pool_left, compact=True)}개가 더 필요합니다."
            farm_hint = f"파밍 우선순위\n중간 - 전체 육성 {len(pool_consumers):,}명 기준 장기적으로 부족합니다."
        else:
            next_hint = "다음 목표\n현재 계획과 알려진 전체 육성 수요가 모두 충족됐습니다."
            farm_hint = "파밍 우선순위\n지금은 낮음."
        return next_hint, farm_hint
    def _inventory_common_related_pressure_text(self, item_id: str, category: str) -> str:
        rows: list[tuple[int, str]] = []
        for entry in self._inventory_requirement_index.values():
            if entry.key == item_id or entry.category != category:
                continue
            shortage = max(0, entry.required - entry.owned)
            if shortage > 0:
                rows.append((shortage, entry.name))
        rows.sort(key=lambda item: (-item[0], item[1].casefold()))
        if rows:
            return "\n".join(f"{name}: -{_format_count(shortage, compact=True)}" for shortage, name in rows[:5])
        return "연관된 현재 계획 부족이 없습니다."
    def _inventory_student_consumers(self, item_id: str, name: str, *, full_pool: bool = False) -> list[tuple[str, str, int]]:
        consumers: list[tuple[str, str, int]] = []
        if full_pool:
            records_and_goals = []
            for record in self._all_students:
                records_and_goals.append((record, self._inventory_full_pool_goal_for_student(record)))
        else:
            records_and_goals = []
            for goal in self._plan.goals:
                record = self._records_by_id.get(goal.student_id)
                if record is not None:
                    records_and_goals.append((record, goal))
        for record, goal in records_and_goals:
            summary = self._cached_goal_cost(record.student_id, record=record, goal=goal)
            if summary is None:
                continue
            for entry in self._plan_requirement_entries(summary, record=record):
                if entry.key == item_id or entry.name.casefold() == name.casefold():
                    consumers.append((record.student_id, record.title, entry.required))
                    break
        priority_index = self._plan_priority_index()
        consumers.sort(
            key=lambda item: (
                priority_index.get(item[0], 999999) if not full_pool else 999999,
                -item[2],
                item[1].casefold(),
                item[0],
            )
        )
        return consumers
    @staticmethod
    def _inventory_exp_yield(category: str, item_id: str, name: str) -> tuple[str, int] | None:
        tier = _tier_from_item_id_or_name(item_id, name)
        if tier <= 0:
            return None
        index = max(0, min(3, tier - 1))
        if category == "level_exp":
            return "레벨 EXP", (50, 500, 2_000, 10_000)[index]
        if category == "equipment_exp":
            return "장비 EXP", (90, 360, 1_440, 5_760)[index]
        if category == "weapon_exp":
            return "무기 EXP", (10, 50, 200, 1_000)[index]
        return None
    def _on_inventory_item_changed(self, current: QListWidgetItem | None, _previous: QListWidgetItem | None = None) -> None:
        if current is None or not hasattr(self, "_inventory_oopart_detail_title"):
            return
        category = str(current.data(Qt.UserRole + 6) or "")
        if category == "ooparts":
            return

        item_id = str(current.data(Qt.UserRole) or "")
        name = str(current.data(Qt.UserRole + 1) or item_id or "인벤토리 항목")
        owned = int(current.data(Qt.UserRole + 2) or 0)
        required = int(current.data(Qt.UserRole + 3) or 0)
        shortage = int(current.data(Qt.UserRole + 4) or 0)
        status = str(current.data(Qt.UserRole + 5) or self._inventory_status_for_values(owned=owned, required=required))
        pool_required = int(current.data(Qt.UserRole + 7) or 0)
        pool_left = int(current.data(Qt.UserRole + 8) or 0)

        self._inventory_oopart_detail_title.setText(name)
        self._set_inventory_detail_status(status)
        self._set_inventory_detail_icon(item_id, name)
        self._clear_inventory_detail_hints()
        self._inventory_oopart_impact_list.clear()
        self._set_inventory_metric_number("owned", owned)
        self._set_inventory_metric_number("required", required, empty_zero=True)
        self._set_inventory_metric_number("shortage", shortage, empty_zero=True)
        self._set_inventory_metric("coverage", self._inventory_coverage(owned, required))
        self._set_inventory_metric_number("pool_required", pool_required, empty_zero=True)
        self._set_inventory_metric_number("pool_shortage", pool_left, empty_zero=True)
        self._set_inventory_metric("pool_coverage", self._inventory_coverage(owned, pool_required))
        self._set_inventory_metric("ex_required", "-")
        self._set_inventory_metric("skill_required", "-")

        consumers = self._inventory_student_consumers(item_id, name) if required > 0 else []
        pool_consumers = self._inventory_student_consumers(item_id, name, full_pool=True) if pool_required > 0 else []
        if consumers or pool_consumers:
            self._set_inventory_metric("affected", f"계획 {len(consumers):,}명 / 전체 {len(pool_consumers):,}명")
        else:
            self._set_inventory_metric("affected", "-")
        category_text = _inventory_category_label(category) or _tr("tab.inventory")
        self._inventory_oopart_detail_summary.setText(
            f"상태: {_inventory_status_label(status)}. {category_text} 재화를 현재 계획 및 전체 육성 수요와 비교합니다."
        )
        next_hint, farm_hint = self._inventory_common_decision_hints(
            name=name,
            shortage=shortage,
            pool_left=pool_left,
            consumers=consumers,
            pool_consumers=pool_consumers,
        )
        if hasattr(self, "_inventory_oopart_next_hint"):
            self._inventory_oopart_next_hint.setText(next_hint)
        if hasattr(self, "_inventory_oopart_farm_hint"):
            self._inventory_oopart_farm_hint.setText(farm_hint)
        if hasattr(self, "_inventory_oopart_family_shortage"):
            self._inventory_oopart_family_shortage.setText(self._inventory_common_related_pressure_text(item_id, category))
        exp_yield = self._inventory_exp_yield(category, item_id, name)
        if exp_yield is not None and owned > 0:
            label, value = exp_yield
            self._inventory_oopart_impact_list.addItem(f"환산 가치: {_format_count(owned * value, compact=True)} {label}")
        planned_consumer_ids = {student_id for student_id, _title, _amount in consumers}
        display_consumers = [(student_id, title, amount, True) for student_id, title, amount in consumers]
        display_consumers.extend(
            (student_id, title, amount, False)
            for student_id, title, amount in pool_consumers
            if student_id not in planned_consumer_ids
        )
        if display_consumers:
            for student_id, title, amount, planned in display_consumers[:12]:
                item = QListWidgetItem("")
                item.setSizeHint(QSize(scale_px(260, self._ui_scale), scale_px(64, self._ui_scale)))
                row = InventoryOpartImpactRow(card_asset=self._student_card_asset, ui_scale=self._ui_scale)
                row.setGenericData(
                    title=title,
                    demand_text=(
                        f"{_format_count(amount, compact=True)}개"
                        if planned
                        else f"{_format_count(amount, compact=True)}개"
                    ),
                    pixmap=self._inventory_student_pixmap(student_id, scale_px(76, self._ui_scale)),
                    planned=planned,
                )
                if planned:
                    item.setBackground(QColor("#3a2238"))
                    item.setForeground(QColor("#ffe1f0"))
                self._inventory_oopart_impact_list.addItem(item)
                self._inventory_oopart_impact_list.setItemWidget(item, row)
        else:
            self._inventory_oopart_impact_list.addItem("현재 계획에서 이 아이템을 소비하는 학생이 없습니다.")

        self._resize_inventory_impact_list_to_contents()
    def _on_inventory_oopart_changed(self, current: QListWidgetItem | None, _previous: QListWidgetItem | None = None) -> None:
        item_id = str(current.data(Qt.UserRole) or "") if current is not None else ""
        self._inventory_oopart_selected_id = item_id or None
        if current is not None:
            target = self._inventory_item_lists.get("ooparts") if hasattr(self, "_inventory_item_lists") else None
            widget = target.itemWidget(current) if target is not None else None
            if isinstance(widget, InventoryOpartFamilyRow):
                widget.setSelectedItem(item_id)
        self._update_inventory_oopart_detail(current)
    def _on_inventory_oopart_cell_selected(self, item_id: str, list_item: QListWidgetItem, widget: InventoryOpartFamilyRow) -> None:
        list_item.setData(Qt.UserRole, item_id)
        list_item.setData(Qt.UserRole + 1, _plan_resource_display_name(item_id, item_id))
        list_item.setData(Qt.UserRole + 2, self._inventory_quantity_index_cache.get(item_id, 0))
        usage = self._inventory_oopart_plan_usage.get(item_id) if hasattr(self, "_inventory_oopart_plan_usage") else None
        list_item.setData(Qt.UserRole + 3, usage.required if usage else 0)
        list_item.setData(Qt.UserRole + 4, usage.shortage if usage else 0)
        list_item.setData(Qt.UserRole + 5, self._inventory_oopart_status(usage))
        list_item.setData(Qt.UserRole + 6, "ooparts")
        widget.setSelectedItem(item_id)
        target = self._inventory_item_lists.get("ooparts") if hasattr(self, "_inventory_item_lists") else None
        if target is not None:
            target.setCurrentItem(list_item)
        self._inventory_oopart_selected_id = item_id
        self._update_inventory_oopart_detail(list_item)
    def _on_inventory_priority_changed(self, current: QListWidgetItem | None, _previous: QListWidgetItem | None = None) -> None:
        item_id = str(current.data(Qt.UserRole) or "") if current is not None else ""
        if item_id:
            category = str(current.data(Qt.UserRole + 6) or "")
            if category == "ooparts" or item_id in _OPART_ITEM_IDS:
                self._select_inventory_oopart(item_id)
            else:
                self._select_inventory_item(item_id)
    def _select_inventory_item(self, item_id: str) -> None:
        if not item_id:
            return
        for list_map, root_index in (
            (getattr(self, "_inventory_equipment_lists", {}), 0),
            (getattr(self, "_inventory_item_lists", {}), 1),
        ):
            for category_index, (_category, target) in enumerate(list_map.items()):
                for index in range(target.count()):
                    item = target.item(index)
                    if str(item.data(Qt.UserRole) or "") == item_id:
                        self._inventory_root_tabs.setCurrentIndex(root_index)
                        if root_index == 0 and hasattr(self, "_inventory_equipment_tabs"):
                            self._inventory_equipment_tabs.setCurrentIndex(category_index)
                        elif root_index == 1 and hasattr(self, "_inventory_item_tabs"):
                            self._inventory_item_tabs.setCurrentIndex(category_index)
                        target.setCurrentItem(item)
                        target.scrollToItem(item)
                        return
    def _select_inventory_oopart(self, item_id: str) -> None:
        if not hasattr(self, "_inventory_item_lists"):
            return
        target = self._inventory_item_lists.get("ooparts")
        if target is None:
            return
        family_prefix = "_".join(item_id.rsplit("_", 1)[:-1])

        def apply_match(item: QListWidgetItem) -> None:
            item.setData(Qt.UserRole, item_id)
            item.setData(Qt.UserRole + 1, _plan_resource_display_name(item_id, item_id))
            item.setData(Qt.UserRole + 2, self._inventory_quantity_index_cache.get(item_id, 0))
            usage = self._inventory_oopart_plan_usage.get(item_id) if hasattr(self, "_inventory_oopart_plan_usage") else None
            item.setData(Qt.UserRole + 3, usage.required if usage else 0)
            item.setData(Qt.UserRole + 4, usage.shortage if usage else 0)
            item.setData(Qt.UserRole + 5, self._inventory_oopart_status(usage))
            item.setData(Qt.UserRole + 6, "ooparts")
            widget = target.itemWidget(item)
            if isinstance(widget, InventoryOpartFamilyRow):
                widget.setSelectedItem(item_id)
            self._inventory_root_tabs.setCurrentIndex(1)
            self._inventory_item_tabs.setCurrentIndex(0)
            target.setCurrentItem(item)
            target.scrollToItem(item)

        fallback_item: QListWidgetItem | None = None
        for index in range(target.count()):
            item = target.item(index)
            current_id = str(item.data(Qt.UserRole) or "")
            current_prefix = "_".join(current_id.rsplit("_", 1)[:-1])
            if current_id == item_id:
                apply_match(item)
                return
            if fallback_item is None and family_prefix and current_prefix == family_prefix:
                fallback_item = item
        if fallback_item is not None:
            apply_match(fallback_item)
    def _configure_inventory_priority_cards(self, target: QListWidget) -> None:
        target.setViewMode(QListView.ListMode)
        target.setResizeMode(QListView.Adjust)
        target.setMovement(QListView.Static)
        target.setFlow(QListView.TopToBottom)
        target.setWrapping(False)
        target.setWordWrap(True)
        target.setSpacing(0)
        target.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        target.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        target.verticalScrollBar().setEnabled(False)
        target.setFixedHeight(scale_px(182, self._ui_scale))
    def _add_inventory_usage_list_item(self, target: QListWidget, usage: InventoryOpartPlanUsage, *, pool: bool) -> None:
        if pool:
            amount = usage.pool_shortage
            meta = f"{_format_count(usage.owned, compact=True)} / {_format_count(usage.pool_required, compact=True)} · 전체 육성 부족"
            tooltip = f"{usage.name}\n전체 육성 부족 {usage.pool_shortage:,} / 필요 {usage.pool_required:,}"
        else:
            amount = usage.shortage
            meta = f"{_format_count(usage.owned, compact=True)} / {_format_count(usage.required, compact=True)} · 계획 {len(usage.impacts)}명"
            tooltip = f"{usage.name}\n계획 부족 {usage.shortage:,} / 필요 {usage.required:,}"
        item = QListWidgetItem("")
        item.setSizeHint(QSize(scale_px(170, self._ui_scale), scale_px(36, self._ui_scale)))
        item.setData(Qt.UserRole, usage.item_id)
        target.addItem(item)

        row = InventoryPressureRow(ui_scale=self._ui_scale)
        icon_path = _inventory_icon_path(usage.item_id, usage.name)
        row.setData(
            icon_path=icon_path,
            item_id=usage.item_id,
            name=usage.name,
            amount=amount,
            total=usage.pool_required if pool else usage.required,
            meta=meta,
            pool=pool,
        )
        target.setItemWidget(item, row)
        item.setToolTip(tooltip)
        item.setData(Qt.UserRole + 6, "ooparts")
    def _add_inventory_requirement_list_item(self, target: QListWidget, entry: PlanResourceRequirement, *, pool: bool) -> None:
        shortage = max(0, entry.required - entry.owned)
        if shortage <= 0:
            return
        item = QListWidgetItem("")
        item.setSizeHint(QSize(scale_px(170, self._ui_scale), scale_px(36, self._ui_scale)))
        item.setData(Qt.UserRole, entry.key)
        item.setData(Qt.UserRole + 1, entry.name)
        item.setData(Qt.UserRole + 2, entry.owned)
        item.setData(Qt.UserRole + 3, entry.required)
        item.setData(Qt.UserRole + 4, shortage)
        item.setData(Qt.UserRole + 6, entry.category)
        target.addItem(item)

        row = InventoryPressureRow(ui_scale=self._ui_scale)
        row.setData(
            icon_path=entry.icon_path,
            item_id=entry.key,
            name=entry.name,
            amount=shortage,
            total=entry.required,
            meta=(
                f"{_format_count(entry.owned, compact=True)} / {_format_count(entry.required, compact=True)} · "
                f"{'전체 육성 부족' if pool else '계획 부족'}"
            ),
            pool=pool,
        )
        target.setItemWidget(item, row)
        item.setToolTip(f"{entry.name}\n부족 {shortage:,} / 필요 {entry.required:,}")
    def _refresh_inventory_insight_panel(self) -> None:
        if not hasattr(self, "_inventory_insight_summary"):
            return
        self._inventory_plan_priority_list.clear()
        self._inventory_pool_pressure_list.clear()
        if hasattr(self, "_inventory_bottleneck_rows_layout"):
            self._refresh_inventory_common_bottleneck_summary()
        if hasattr(self, "_inventory_school_risk_rows_layout"):
            self._refresh_inventory_school_risk_summary()

        usages = list(self._inventory_oopart_plan_usage.values())
        plan_requirement_top = [
            entry
            for entry in sorted(
                self._inventory_requirement_index.values(),
                key=lambda entry: (-(entry.required - entry.owned), entry.name.lower()),
            )
            if self._inventory_is_common_requirement_category(entry.category) and entry.required > entry.owned
        ][:5]
        pool_priority_rows = self._inventory_pool_pressure_rows()

        if not usages and not plan_requirement_top and not pool_priority_rows:
            self._inventory_insight_summary.setText("아직 계획 또는 전체 육성 기준 오파츠 수요가 없습니다.")
            self._update_inventory_oopart_detail(None)
            return

        self._inventory_insight_summary.setText(self._inventory_plan_diagnosis_text())

        plan_priority_rows = sorted(
            [("usage", usage, usage.shortage, usage.name.lower()) for usage in usages if usage.shortage > 0]
            + [
                ("requirement", entry, entry.required - entry.owned, entry.name.lower())
                for entry in plan_requirement_top
            ],
            key=lambda row: (-row[2], row[3]),
        )[:5]
        if plan_priority_rows:
            for row_type, source, _, _ in plan_priority_rows:
                if row_type == "usage":
                    self._add_inventory_usage_list_item(self._inventory_plan_priority_list, source, pool=False)
                else:
                    self._add_inventory_requirement_list_item(self._inventory_plan_priority_list, source, pool=False)
        else:
            self._inventory_plan_priority_list.addItem("현재 계획 부족이 없습니다.")
        if pool_priority_rows:
            for row_type, source, _, _ in pool_priority_rows:
                if row_type == "usage":
                    self._add_inventory_usage_list_item(self._inventory_pool_pressure_list, source, pool=True)
                else:
                    self._add_inventory_requirement_list_item(self._inventory_pool_pressure_list, source, pool=True)
        else:
            self._inventory_pool_pressure_list.addItem("전체 육성 기준 남은 부족이 없습니다.")
    def _update_inventory_oopart_detail(self, current: QListWidgetItem | None) -> None:
        if not hasattr(self, "_inventory_oopart_detail_title"):
            return
        self._inventory_oopart_impact_list.clear()
        if current is None:
            self._inventory_oopart_detail_title.setText(_tr("inventory.detail.select_oopart"))
            self._set_inventory_detail_status(None)
            self._set_inventory_detail_icon(None, "")
            self._inventory_oopart_detail_summary.setText(_tr("inventory.detail.pick_item"))
            self._clear_inventory_oopart_metrics()
            self._clear_inventory_detail_hints()
            self._resize_inventory_impact_list_to_contents()
            return

        item_id = str(current.data(Qt.UserRole) or "")
        name = str(current.data(Qt.UserRole + 1) or item_id or "오파츠")
        owned = int(current.data(Qt.UserRole + 2) or 0)
        usage = self._inventory_oopart_plan_usage.get(item_id)
        self._inventory_oopart_detail_title.setText(name)
        self._set_inventory_detail_icon(item_id, name)
        if usage is None:
            usage = InventoryOpartPlanUsage(item_id=item_id, name=name, owned=owned)
        else:
            usage.owned = owned

        self._set_inventory_metric_number("owned", owned)
        self._set_inventory_metric_number("required", usage.required, empty_zero=True)
        self._set_inventory_metric_number("shortage", usage.shortage, empty_zero=True)
        self._set_inventory_metric("coverage", self._inventory_coverage(owned, usage.required))
        self._set_inventory_metric_number("pool_required", usage.pool_required, empty_zero=True)
        self._set_inventory_metric_number("pool_shortage", usage.pool_shortage, empty_zero=True)
        self._set_inventory_metric("pool_coverage", self._inventory_coverage(owned, usage.pool_required))
        self._set_inventory_metric_number("ex_required", usage.ex_required, empty_zero=True)
        self._set_inventory_metric_number("skill_required", usage.skill_required, empty_zero=True)
        self._set_inventory_metric("affected", f"계획 {len(usage.impacts):,}명 / 전체 {len(usage.pool_impacts):,}명")

        status = self._inventory_oopart_status(usage)
        self._set_inventory_detail_status(status)
        planned_ids = set(self._plan_goal_map())
        planned_pool_count = sum(1 for impact in usage.pool_impacts if impact.student_id in planned_ids)
        self._inventory_oopart_detail_summary.setText(
            f"상태: {_inventory_status_label(status)}. 전체 육성 영향 학생 {len(usage.pool_impacts):,}명 "
            f"(현재 계획 {planned_pool_count:,}명)."
        )
        next_hint, farm_hint = self._inventory_oopart_decision_hints(usage)
        if hasattr(self, "_inventory_oopart_next_hint"):
            self._inventory_oopart_next_hint.setText(next_hint)
        if hasattr(self, "_inventory_oopart_farm_hint"):
            self._inventory_oopart_farm_hint.setText(farm_hint)
        if hasattr(self, "_inventory_oopart_family_shortage"):
            self._inventory_oopart_family_shortage.setText(self._inventory_oopart_family_shortage_text(item_id))
        if not usage.pool_impacts:
            self._inventory_oopart_impact_list.addItem("표시할 학생 수요가 없습니다.")
            self._resize_inventory_impact_list_to_contents()
            return

        planned_impacts = [impact for impact in usage.impacts if impact.student_id in planned_ids]
        planned_seen = {impact.student_id for impact in planned_impacts}
        remaining_pool = [impact for impact in usage.pool_impacts if impact.student_id not in planned_seen]
        for impact in planned_impacts + remaining_pool:
            is_planned = impact.student_id in planned_ids
            item = QListWidgetItem("")
            item.setSizeHint(QSize(scale_px(260, self._ui_scale), scale_px(64, self._ui_scale)))
            row = InventoryOpartImpactRow(card_asset=self._student_card_asset, ui_scale=self._ui_scale)
            row.setData(
                impact=impact,
                pixmap=self._inventory_student_pixmap(impact.student_id, scale_px(76, self._ui_scale)),
                planned=is_planned,
            )
            if is_planned:
                item.setBackground(QColor("#3a2238"))
                item.setForeground(QColor("#ffe1f0"))
            self._inventory_oopart_impact_list.addItem(item)
            self._inventory_oopart_impact_list.setItemWidget(item, row)
        self._resize_inventory_impact_list_to_contents()
    def _inventory_classify_item(self, item_key: str, payload: dict) -> str:
        key_text = str(item_key or "")
        item_id = str(payload.get("item_id") or (key_text if "_Icon_" in key_text or key_text.startswith("Item_") else ""))
        name = _inventory_display_label(item_key, payload)
        if item_id == "Currency_Icon_Gold":
            return "resources"
        if item_id in _OPART_ITEM_IDS:
            return "ooparts"
        if item_id in _WB_ITEM_IDS or item_id in _WORKBOOK_ID_TO_NAME:
            return "wb"
        if item_id.startswith("Equipment_Icon_Exp_"):
            return "stones"
        if item_id.startswith("Equipment_Icon_WeaponExpGrowth"):
            return "weapon_parts"
        if item_id.startswith("Item_Icon_SkillBook_"):
            return "tech_notes"
        if item_id.startswith("Item_Icon_Material_ExSkill_"):
            return "bd"
        if item_id.startswith("Item_Icon_SecretStone_"):
            return "elephs"
        if _is_present_item_id(item_id):
            return "presents"
        if _report_icon_for_entry(item_id or None, name):
            return "reports"
        return "other"
    def _inventory_snapshot_with_resources(self, inventory: dict[str, dict]) -> dict[str, dict]:
        merged = dict(inventory)
        credit_quantity = _inventory_quantity_value(getattr(self, "_resource_snapshot", {}).get("credit"))
        if credit_quantity is not None:
            merged["Currency_Icon_Gold"] = {
                "item_id": "Currency_Icon_Gold",
                "name": "크레딧",
                "quantity": credit_quantity,
                "item_source": "resources",
            }
        return merged
    def _inventory_convertible_coverage_key(self, item_id: str, name: str, category: str) -> tuple[str, int] | None:
        stone_match = re.match(r"Equipment_Icon_Exp_(\d+)$", item_id)
        if category == "stones" and stone_match:
            return ("stones", int(stone_match.group(1)) + 1)

        weapon_part = _weapon_exp_item_part_and_tier(item_id)
        if category == "weapon_parts" and weapon_part is not None:
            part_key, tier = weapon_part
            return (f"weapon:{part_key}", tier)

        if category == "reports":
            report_token = _report_icon_for_entry(item_id or None, name)
            report_match = re.match(r"report_(\d+)$", report_token or "")
            if report_match:
                return ("reports", int(report_match.group(1)) + 1)
        return None
    def _inventory_convertible_coverage_owned(
        self,
        entries: list[tuple[str, dict]],
        *,
        category: str,
        requirement_index: dict[str, PlanResourceRequirement],
    ) -> dict[str, float]:
        rows: dict[str, dict[str, object]] = {}
        grouped: dict[str, list[str]] = {}
        for item_key, payload in entries:
            item_id = payload.get("item_id")
            item_id_text = str(item_id) if item_id else str(item_key)
            name = _inventory_display_label(item_key, payload)
            family_tier = self._inventory_convertible_coverage_key(item_id_text, name, category)
            if family_tier is None:
                continue
            family, tier = family_tier
            quantity_value = _inventory_quantity_value(payload.get("quantity"))
            owned = float(quantity_value if quantity_value is not None else 0)
            requirement = self._inventory_requirement_for_entry(item_id_text, name, requirement_index)
            required = float(requirement.required if requirement is not None else 0)
            rows[item_id_text] = {
                "family": family,
                "tier": tier,
                "owned": owned,
                "required": required,
            }
            grouped.setdefault(family, []).append(item_id_text)

        effective = {item_id: float(row["owned"]) for item_id, row in rows.items()}
        for item_ids in grouped.values():
            for target_id in item_ids:
                target = rows[target_id]
                target_tier = int(target["tier"])
                adjusted_owned = float(target["owned"])
                for source_id in item_ids:
                    source = rows[source_id]
                    source_tier = int(source["tier"])
                    if source_tier >= target_tier:
                        continue
                    surplus = max(0.0, float(source["owned"]) - float(source["required"]))
                    if surplus <= 0:
                        continue
                    adjusted_owned += surplus / float(4 ** (target_tier - source_tier))
                effective[target_id] = adjusted_owned
        return effective
    def _set_inventory_oopart_family_items(
        self,
        target: QListWidget,
        summary: QLabel,
        oopart_usage: dict[str, InventoryOpartPlanUsage],
    ) -> None:
        target.clear()
        if not self._inventory_oopart_selected_id and OPART_DEFINITIONS:
            self._inventory_oopart_selected_id = f"Item_Icon_Material_{OPART_DEFINITIONS[0].icon_key}_3"

        usages = list(oopart_usage.values())
        plan_shortage_items = sum(1 for usage in usages if usage.shortage > 0)
        plan_shortage_total = sum(usage.shortage for usage in usages)
        pool_shortage_items = sum(1 for usage in usages if usage.pool_shortage > 0)
        pool_shortage_total = sum(usage.pool_shortage for usage in usages)
        summary.setText(
            f"{len(OPART_DEFINITIONS)}계열 · 계획 부족 {plan_shortage_items}개 ({plan_shortage_total:,}) · "
            f"전체 육성 부족 {pool_shortage_items}개 ({pool_shortage_total:,})"
        )

        restore_item: QListWidgetItem | None = None
        for definition in OPART_DEFINITIONS:
            tier_items: list[tuple[int, str, str, int, str, Path | None]] = []
            row_selected_id = self._inventory_oopart_selected_id
            family_ids = [f"Item_Icon_Material_{definition.icon_key}_{index}" for index in range(4)]
            if row_selected_id not in family_ids:
                row_selected_id = family_ids[-1]
            for tier_index in range(3, -1, -1):
                item_id = f"Item_Icon_Material_{definition.icon_key}_{tier_index}"
                name = _plan_resource_display_name(item_id, item_id)
                usage = oopart_usage.get(item_id)
                owned = self._inventory_quantity_index_cache.get(item_id, 0)
                status = self._inventory_oopart_status(usage)
                tier_items.append((tier_index + 1, item_id, name, owned, status, _inventory_icon_path(item_id, name)))

            widget = InventoryOpartFamilyRow(
                family_name=definition.family_en,
                tier_items=tier_items,
                selected_item_id=self._inventory_oopart_selected_id if self._inventory_oopart_selected_id in family_ids else None,
                ui_scale=self._ui_scale,
            )
            item = QListWidgetItem()
            item.setFlags(Qt.ItemIsEnabled | Qt.ItemIsSelectable)
            item.setSizeHint(QSize(scale_px(320, self._ui_scale), scale_px(98, self._ui_scale)))
            item.setData(Qt.UserRole, row_selected_id)
            item.setData(Qt.UserRole + 1, _plan_resource_display_name(row_selected_id, row_selected_id))
            item.setData(Qt.UserRole + 2, self._inventory_quantity_index_cache.get(row_selected_id, 0))
            selected_usage = oopart_usage.get(row_selected_id)
            item.setData(Qt.UserRole + 3, selected_usage.required if selected_usage else 0)
            item.setData(Qt.UserRole + 4, selected_usage.shortage if selected_usage else 0)
            item.setData(Qt.UserRole + 5, self._inventory_oopart_status(selected_usage))
            item.setData(Qt.UserRole + 6, "ooparts")
            target.addItem(item)
            target.setItemWidget(item, widget)
            widget.selected.connect(lambda value, list_item=item, row_widget=widget: self._on_inventory_oopart_cell_selected(value, list_item, row_widget))
            if self._inventory_oopart_selected_id in family_ids:
                restore_item = item

        if restore_item is None and target.count() > 0:
            restore_item = target.item(0)
            self._inventory_oopart_selected_id = str(restore_item.data(Qt.UserRole) or "")
        target.setCurrentItem(restore_item)
        self._update_inventory_oopart_detail(restore_item)
    def _set_inventory_list_items(
        self,
        target: QListWidget,
        summary: QLabel,
        entries: list[tuple[str, dict]],
        *,
        category: str = "",
        oopart_usage: dict[str, InventoryOpartPlanUsage] | None = None,
        priority_statuses: dict[str, str] | None = None,
    ) -> None:
        target.clear()
        requirement_index = getattr(self, "_inventory_requirement_index", {})
        pool_requirement_index = getattr(self, "_inventory_pool_requirement_index", {})
        if not entries:
            summary.setText(_tr("inventory.no_scanned_category"))
            target.addItem(_tr("inventory.scan_to_populate"))
            if category == "ooparts":
                self._inventory_oopart_selected_id = None
                self._update_inventory_oopart_detail(None)
            return

        total_quantity = sum(
            quantity
            for _item_key, payload in entries
            if (quantity := _inventory_quantity_value(payload.get("quantity"))) is not None
        )
        summary.setText(_tr("inventory.summary", count=len(entries), quantity=_format_count(total_quantity, compact=True)))

        if category == "ooparts" and oopart_usage:
            shortage_items = sum(1 for usage in oopart_usage.values() if usage.shortage > 0)
            total_shortage = sum(usage.shortage for usage in oopart_usage.values())
            pool_shortage_items = sum(1 for usage in oopart_usage.values() if usage.pool_shortage > 0)
            pool_total_shortage = sum(usage.pool_shortage for usage in oopart_usage.values())
            plan_top = sorted(oopart_usage.values(), key=lambda usage: (-usage.shortage, usage.name.lower()))[:3]
            pool_top = sorted(oopart_usage.values(), key=lambda usage: (-usage.pool_shortage, usage.name.lower()))[:3]
            plan_top_text = ", ".join(f"{usage.name} {_format_count(usage.shortage, compact=True)}" for usage in plan_top if usage.shortage > 0) or "없음"
            pool_top_text = ", ".join(f"{usage.name} {_format_count(usage.pool_shortage, compact=True)}" for usage in pool_top if usage.pool_shortage > 0) or "없음"
            summary.setText(
                f"{len(entries)}개 · 총 수량 {_format_count(total_quantity, compact=True)} · "
                f"계획 부족 {shortage_items}개 ({_format_count(total_shortage, compact=True)}) · "
                f"전체 육성 부족 {pool_shortage_items}개 ({_format_count(pool_total_shortage, compact=True)})\n"
                f"계획 우선순위: {plan_top_text}\n"
                f"전체 육성 부족: {pool_top_text}"
            )

        plan_coverage_owned = self._inventory_convertible_coverage_owned(
            entries,
            category=category,
            requirement_index=requirement_index,
        )
        pool_coverage_owned = self._inventory_convertible_coverage_owned(
            entries,
            category=category,
            requirement_index=pool_requirement_index,
        )

        restore_item: QListWidgetItem | None = None
        for item_key, payload in entries:
            item_id = payload.get("item_id")
            item_id_text = str(item_id) if item_id else str(item_key)
            name = _inventory_display_label(item_key, payload)
            quantity_value = _inventory_quantity_value(payload.get("quantity"))
            owned = quantity_value if quantity_value is not None else 0
            requirement = self._inventory_requirement_for_entry(item_id_text, name, requirement_index)
            required = requirement.required if requirement is not None else 0
            plan_short = max(0, required - owned)
            pool_requirement = self._inventory_requirement_for_entry(item_id_text, name, pool_requirement_index)
            pool_required = pool_requirement.required if pool_requirement is not None else 0
            pool_left = max(0, pool_required - owned)
            usage = oopart_usage.get(item_id_text) if oopart_usage else None
            priority_status = priority_statuses.get(item_id_text) if priority_statuses else None
            shortage = bool(usage and (usage.shortage > 0 or usage.pool_shortage > 0))
            if usage and usage.required > 0:
                quantity = _format_count(owned, compact=True)
                meta = (
                    f"계획 필요 {_format_count(usage.required, compact=True)} · 계획 부족 {_format_count(usage.shortage, compact=True)} · "
                    f"전체 육성 필요 {_format_count(usage.pool_required, compact=True)} · 전체 육성 부족 {_format_count(usage.pool_shortage, compact=True)} · "
                    f"EX {_format_count(usage.ex_required, compact=True)} / 일반 {_format_count(usage.skill_required, compact=True)} · 계획 {len(usage.impacts)}명"
                )
            elif usage and usage.pool_required > 0:
                quantity = _format_count(owned, compact=True)
                meta = (
                    f"계획 수요 없음 · 전체 육성 필요 {_format_count(usage.pool_required, compact=True)} · "
                    f"전체 육성 부족 {_format_count(usage.pool_shortage, compact=True)} · EX {_format_count(usage.pool_ex_required, compact=True)} / 일반 {_format_count(usage.pool_skill_required, compact=True)}"
                )
            else:
                quantity = _format_count(quantity_value, compact=True) if quantity_value is not None else str(payload.get("quantity") or "?")
                tier = _tier_from_item_id_or_name(item_id_text, name)
                meta_parts = []
                if category:
                    meta_parts.append(_inventory_category_label(category))
                if tier:
                    meta_parts.append(f"T{tier}")
                meta = " - ".join(meta_parts)
            if not usage:
                tier = _tier_from_item_id_or_name(item_id_text, name)
                status = priority_status or self._inventory_status_for_values(owned=owned, required=required, pool_left=pool_left, tier=tier)
                shortage = plan_short > 0 or bool(priority_status)
                plan_need_text = _format_count(required, compact=True) if required > 0 else "-"
                plan_short_text = _format_count(plan_short, compact=True, signed=True) if plan_short > 0 else "-"
                pool_remain_text = _format_count(pool_left, compact=True) if pool_left > 0 else "-"
            else:
                status = priority_status or self._inventory_oopart_status(usage)
                shortage = shortage or bool(priority_status)
                plan_need_text = _format_count(usage.required, compact=True) if usage.required > 0 else "-"
                plan_short_text = _format_count(usage.shortage, compact=True, signed=True) if usage.shortage > 0 else "-"
                pool_remain_text = _format_count(usage.pool_shortage, compact=True) if usage.pool_shortage > 0 else "-"
            plan_effective_owned = plan_coverage_owned.get(item_id_text, float(owned))
            pool_effective_owned = pool_coverage_owned.get(item_id_text, float(owned))
            widget = InventoryListItem(ui_scale=self._ui_scale)
            widget.setData(
                icon_path=_inventory_icon_path(str(item_id) if item_id else None, name),
                item_id=item_id_text or None,
                name=name,
                quantity=quantity,
                meta="" if category == "ooparts" else meta,
                shortage=shortage,
                plan_need=plan_need_text,
                plan_short=plan_short_text,
                pool_remain=pool_remain_text,
                status=status,
                show_text=True,
                owned_value=owned,
                plan_required_value=required if not usage else usage.required,
                pool_required_value=pool_required if not usage else usage.pool_required,
                plan_coverage_owned_value=plan_effective_owned,
                pool_coverage_owned_value=pool_effective_owned,
                owned_tooltip=_full_count_tooltip(owned),
                plan_need_tooltip=_full_count_tooltip(required if not usage else usage.required),
                plan_short_tooltip=_full_count_tooltip(plan_short if not usage else usage.shortage),
                pool_remain_tooltip=_full_count_tooltip(pool_left if not usage else usage.pool_shortage),
            )
            item = QListWidgetItem()
            item.setFlags(Qt.ItemIsEnabled | Qt.ItemIsSelectable)
            item.setSizeHint(QSize(scale_px(640, self._ui_scale), scale_px(64, self._ui_scale)))
            item.setData(Qt.UserRole, item_id_text)
            item.setData(Qt.UserRole + 1, name)
            item.setData(Qt.UserRole + 2, owned)
            item.setData(Qt.UserRole + 3, required if not usage else usage.required)
            item.setData(Qt.UserRole + 4, plan_short if not usage else usage.shortage)
            item.setData(Qt.UserRole + 5, status)
            item.setData(Qt.UserRole + 6, category)
            item.setData(Qt.UserRole + 7, pool_required if not usage else usage.pool_required)
            item.setData(Qt.UserRole + 8, pool_left if not usage else usage.pool_shortage)
            target.addItem(item)
            target.setItemWidget(item, widget)
            if category == "ooparts" and item_id_text == self._inventory_oopart_selected_id:
                restore_item = item

        if category == "ooparts":
            if restore_item is None and target.count() > 0:
                restore_item = target.item(0)
            target.setCurrentItem(restore_item)
            self._update_inventory_oopart_detail(restore_item)
    def _refresh_inventory_tab(self) -> None:
        if not hasattr(self, "_inventory_root_tabs"):
            return

        inventory = self._inventory_snapshot_with_resources(self._inventory_snapshot or {})
        self._inventory_requirement_index = self._inventory_plan_requirement_index()
        self._inventory_pool_requirement_index = self._inventory_full_pool_requirement_index()
        if not inventory:
            self._inventory_summary.setText(_tr("inventory.empty_with_hint"))
            self._inventory_oopart_plan_usage = self._inventory_build_oopart_plan_usage()
            oopart_priority_statuses = self._inventory_oopart_priority_statuses(self._inventory_oopart_plan_usage)
            for key, widget in self._inventory_equipment_lists.items():
                self._set_inventory_list_items(widget, self._inventory_equipment_summaries[key], [])
            for key, widget in self._inventory_item_lists.items():
                if key == "ooparts" and self._inventory_oopart_plan_usage:
                    entries = [
                        (
                            item_id,
                            {
                                "item_id": item_id,
                                "name": usage.name,
                                "quantity": 0,
                                "planned_only": True,
                            },
                        )
                        for item_id, usage in self._inventory_oopart_plan_usage.items()
                    ]
                    entries.sort(key=self._inventory_oopart_sort_key)
                    self._set_inventory_list_items(
                        widget,
                        self._inventory_item_summaries[key],
                        entries,
                        category=key,
                        oopart_usage=self._inventory_oopart_plan_usage,
                        priority_statuses=oopart_priority_statuses,
                    )
                else:
                    self._set_inventory_list_items(widget, self._inventory_item_summaries[key], [], category=key)
            self._refresh_inventory_insight_panel()
            self._schedule_inventory_layout_sync()
            return

        total_quantity = sum(
            quantity
            for payload in inventory.values()
            if (quantity := _inventory_quantity_value(payload.get("quantity"))) is not None
        )
        latest_seen = max((str(payload.get("last_seen_at") or "") for payload in inventory.values()), default="")
        latest_time = _tr("inventory.last_updated", time=latest_seen) if latest_seen else "확인되지 않았습니다"
        report_students, equipment_students = self._inventory_max_student_counts()
        self._inventory_summary.setText(
            _tr(
                "inventory.summary_scanned",
                count=len(inventory),
                quantity=_format_count(total_quantity, compact=True),
                time=latest_time,
            )
            + f" 현재 보고서로 {report_students}명의 학생, 강화석으로 {equipment_students}명의 학생을 최대치까지 올릴 수 있습니다."
        )

        self._inventory_oopart_plan_usage = self._inventory_build_oopart_plan_usage()
        self._refresh_inventory_insight_panel()

        equipment_groups: dict[str, list[tuple[str, dict]]] = {series.icon_key: [] for series in EQUIPMENT_SERIES}
        item_groups: dict[str, list[tuple[str, dict]]] = {
            "ooparts": [],
            "wb": [],
            "stones": [],
            "reports": [],
            "weapon_parts": [],
            "tech_notes": [],
            "bd": [],
            "resources": [],
            "elephs": [],
            "presents": [],
            "other": [],
        }

        for item_key, payload in inventory.items():
            item_id = str(payload.get("item_id") or "")
            if item_id.startswith("Equipment_Icon_") and "_Tier" in item_id:
                series_key = item_id.removeprefix("Equipment_Icon_").split("_Tier", 1)[0]
                if series_key in equipment_groups:
                    equipment_groups[series_key].append((item_key, payload))
                    continue
            item_groups[self._inventory_classify_item(item_key, payload)].append((item_key, payload))

        scanned_oopart_ids = {
            str(payload.get("item_id") or item_key)
            for item_key, payload in item_groups["ooparts"]
        }
        for item_id, usage in self._inventory_oopart_plan_usage.items():
            if item_id in scanned_oopart_ids:
                continue
            item_groups["ooparts"].append(
                (
                    item_id,
                    {
                        "item_id": item_id,
                        "name": usage.name,
                        "quantity": usage.owned,
                        "planned_only": True,
                    },
                )
            )

        known_requirement_ids = {
            str(payload.get("item_id") or item_key)
            for item_key, payload in inventory.items()
        }
        known_requirement_ids.update(str(payload.get("item_id") or item_key) for item_key, payload in item_groups["ooparts"])
        requirement_entries: dict[str, PlanResourceRequirement] = {}
        requirement_entries.update(self._inventory_pool_requirement_index)
        requirement_entries.update(self._inventory_requirement_index)
        for item_id, entry in requirement_entries.items():
            if not self._inventory_is_common_requirement_category(entry.category):
                continue
            if item_id in known_requirement_ids or item_id in _OPART_ITEM_IDS:
                continue
            payload = {
                "item_id": item_id,
                "name": entry.name,
                "quantity": 0,
                "planned_only": True,
            }
            if item_id.startswith("Equipment_Icon_") and "_Tier" in item_id:
                series_key = item_id.removeprefix("Equipment_Icon_").split("_Tier", 1)[0]
                if series_key in equipment_groups:
                    equipment_groups[series_key].append((item_id, payload))
                    known_requirement_ids.add(item_id)
                    continue
            item_groups[self._inventory_classify_item(item_id, payload)].append((item_id, payload))
            known_requirement_ids.add(item_id)

        wb_order = {
            item_id: index
            for index, item_id in enumerate(tuple(_WORKBOOK_ID_TO_NAME) + _WB_ITEM_IDS)
        }
        stone_order = {item_id: index for index, (item_id, _name) in enumerate(EQUIPMENT_EXP_ITEMS)}
        report_order = {token: index for index, token in enumerate(_REPORT_ORDER)}
        weapon_order = {
            item_id: index
            for index, item_id in enumerate(
                [
                    f"Equipment_Icon_WeaponExpGrowth{part_key}_{tier}"
                    for part_key, _label in WEAPON_PART_ITEMS
                    for tier in range(3, -1, -1)
                ]
            )
        }
        present_profile = get_inventory_profile("presents")
        present_order = {
            item_id: index
            for index, item_id in enumerate(inventory_profile_ordered_item_ids(present_profile) if present_profile else ())
            if item_id
        }
        def equipment_sort_key(entry: tuple[str, dict]) -> tuple[int, str]:
            item_id = str(entry[1].get("item_id") or "")
            try:
                tier_number = int(item_id.rsplit("_Tier", 1)[-1])
            except ValueError:
                tier_number = -1
            return (-tier_number, _inventory_display_label(entry[0], entry[1]).lower())

        def ordered_sort_key(order_map: dict[str, int], entry: tuple[str, dict]) -> tuple[int, str]:
            item_id = str(entry[1].get("item_id") or "")
            return (order_map.get(item_id, 9999), _inventory_display_label(entry[0], entry[1]).lower())

        equipment_priority_statuses = self._inventory_equipment_priority_statuses(
            [entry for entries in equipment_groups.values() for entry in entries]
        )
        oopart_priority_statuses = self._inventory_oopart_priority_statuses(self._inventory_oopart_plan_usage)

        for series in EQUIPMENT_SERIES:
            entries = sorted(equipment_groups[series.icon_key], key=equipment_sort_key)
            self._set_inventory_list_items(
                self._inventory_equipment_lists[series.icon_key],
                self._inventory_equipment_summaries[series.icon_key],
                entries,
                priority_statuses=equipment_priority_statuses,
            )

        ordered_items = {
            "ooparts": sorted(item_groups["ooparts"], key=self._inventory_oopart_sort_key),
            "wb": sorted(item_groups["wb"], key=lambda entry: ordered_sort_key(wb_order, entry)),
            "stones": sorted(item_groups["stones"], key=lambda entry: ordered_sort_key(stone_order, entry)),
            "reports": sorted(
                item_groups["reports"],
                key=lambda entry: (
                    report_order.get(
                        _report_icon_for_entry(
                            str(entry[1].get("item_id") or "") or None,
                            _inventory_display_label(entry[0], entry[1]),
                        )
                        or "",
                        9999,
                    ),
                    _inventory_display_label(entry[0], entry[1]).lower(),
                ),
            ),
            "weapon_parts": sorted(item_groups["weapon_parts"], key=lambda entry: ordered_sort_key(weapon_order, entry)),
            "tech_notes": sorted(item_groups["tech_notes"], key=lambda entry: self._inventory_school_material_sort_key(entry, material="tech_notes")),
            "bd": sorted(item_groups["bd"], key=lambda entry: self._inventory_school_material_sort_key(entry, material="bd")),
            "resources": sorted(item_groups["resources"], key=lambda entry: _inventory_display_label(entry[0], entry[1]).lower()),
            "elephs": sorted(item_groups["elephs"], key=lambda entry: _inventory_display_label(entry[0], entry[1]).lower()),
            "presents": sorted(item_groups["presents"], key=lambda entry: ordered_sort_key(present_order, entry)),
            "other": sorted(item_groups["other"], key=lambda entry: _inventory_display_label(entry[0], entry[1]).lower()),
        }

        for category, entries in ordered_items.items():
            self._set_inventory_list_items(
                self._inventory_item_lists[category],
                self._inventory_item_summaries[category],
                entries,
                category=category,
                oopart_usage=self._inventory_oopart_plan_usage if category == "ooparts" else None,
                priority_statuses=oopart_priority_statuses if category == "ooparts" else None,
            )
        self._schedule_inventory_layout_sync()
