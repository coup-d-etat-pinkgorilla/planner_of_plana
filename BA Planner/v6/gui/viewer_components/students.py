"""StudentsTabComponent implementation extracted from the viewer façade."""

from __future__ import annotations

from gui import viewer_shared as _viewer_shared

globals().update({name: value for name, value in vars(_viewer_shared).items() if not name.startswith("__")})


class StudentsTabComponent:
    def _build_ui(self) -> None:
        root = TriangleTextureWidget(
            TriangleTextureConfig(
                base_color=BG,
                panel_color=PALETTE_PANEL,
                soft_color=PALETTE_SOFT,
                accent_color=PALETTE_ACCENT,
                triangle_size=scale_px(130, self._ui_scale),
                tessellation_contrast=0.032,
                random_seed=7319,
                macro_triangle_chance=0.075,
                macro_triangle_scale=3.0,
                macro_triangle_contrast=0.024,
                light_direction_degrees=132.0,
                light_strength=0.16,
                light_center_x=0.5,
                light_center_y=0.5,
                edge_vignette_strength=0.2,
                fog_direction_degrees=18.0,
                fog_strength=0.13,
            ),
            self,
        )
        root.setObjectName("viewerRoot")
        self._background_texture = root
        self.setCentralWidget(root)

        outer_layout = QVBoxLayout(root)
        outer_layout.setContentsMargins(
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
        )
        outer_layout.setSpacing(scale_px(12, self._ui_scale))

        tabs = QTabWidget()
        self._main_tabs = tabs
        tabs.setObjectName("mainTabs")
        tabs.tabBar().setObjectName("mainTabBar")
        tabs.tabBar().setUsesScrollButtons(True)
        outer_layout.addWidget(tabs, 1)

        scan_tab = QWidget()
        self._scan_tab = self._add_main_tab(tabs, scan_tab, "스캔")
        self._build_scan_tab(scan_tab)

        students_tab = QWidget()
        self._students_tab = self._add_main_tab(tabs, students_tab, _tr("tab.students"))
        self._build_students_tab(students_tab)

        plan_tab = QWidget()
        self._add_main_tab(tabs, plan_tab, _tr("tab.plans"))
        self._build_plan_tab(plan_tab)

        resource_tab = QWidget()
        self._resource_tab = self._add_main_tab(tabs, resource_tab, "필요 재화")
        self._build_resource_tab(resource_tab)

        inventory_tab = QWidget()
        self._inventory_tab = self._add_main_tab(tabs, inventory_tab, _tr("tab.inventory"))
        self._build_inventory_tab(inventory_tab)

        tactical_tab = QWidget()
        self._add_main_tab(tabs, tactical_tab, "전술대항전")
        self._build_tactical_tab(tactical_tab)

        if SHOW_RAID_GUIDE_TAB:
            raid_guide_tab = QWidget()
            self._add_main_tab(tabs, raid_guide_tab, "공략 타임라인")
            self._build_raid_guide_tab(raid_guide_tab)

        if SHOW_STATS_TAB:
            stats_tab = QWidget()
            self._add_main_tab(tabs, stats_tab, "Statistics")
            self._build_stats_tab(stats_tab)

        settings_tab = QWidget()
        self._settings_tab = self._add_main_tab(tabs, settings_tab, "설정")
        self._build_settings_tab(settings_tab)

        tabs.currentChanged.connect(self._on_main_tab_changed)

        self.setStyleSheet(
            f"""
            QMainWindow {{ background: {BG}; color: {INK}; }}
            QWidget {{ background: transparent; color: {INK}; }}
            QLabel {{ background: transparent; }}
            QTabWidget#mainTabs::pane {{
                border: none;
                border-radius: {scale_px(18, self._ui_scale)}px;
                background: transparent;
                top: {scale_px(3, self._ui_scale)}px;
            }}
            QTabWidget#tacticalInsightTabs::pane {{
                border: none;
                background: transparent;
                border-radius: {scale_px(14, self._ui_scale)}px;
            }}
            QTabBar::tab {{
                background: transparent;
                color: {MUTED};
                padding: {scale_px(10, self._ui_scale)}px {scale_px(14, self._ui_scale)}px;
                margin-right: {scale_px(6, self._ui_scale)}px;
                border-radius: {scale_px(10, self._ui_scale)}px;
            }}
            QTabBar::tab:hover {{
                background: {ACCENT_SOFT};
                color: {INK};
            }}
            QTabBar::tab:selected {{
                background: {ACCENT_PALE};
                color: {ACCENT_STRONG};
                font-weight: 700;
            }}
            QTabBar#mainTabBar {{
                margin-bottom: {scale_px(2, self._ui_scale)}px;
            }}
            QTabBar#mainTabBar::tab {{
                background: transparent;
                color: {MUTED};
                border: 2px solid transparent;
                border-radius: {scale_px(10, self._ui_scale)}px;
                padding: {scale_px(8, self._ui_scale)}px {scale_px(14, self._ui_scale)}px;
                margin-right: {scale_px(6, self._ui_scale)}px;
                font-weight: 700;
            }}
            QTabBar#mainTabBar::tab:hover {{
                background: transparent;
                color: #ffb5f0;
                border-color: {_mix_hex("#ffb5f0", SURFACE_ALT, 0.28)};
            }}
            QTabBar#mainTabBar::tab:selected {{
                background: transparent;
                color: #ffb5f0;
                border: 2px solid #ffb5f0;
                font-weight: 800;
            }}
            QTabWidget#inventoryRootTabs {{
                background: {_mix_hex(SURFACE_ALT, BG, 0.08)};
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.36)};
                border-radius: {scale_px(14, self._ui_scale)}px;
            }}
            QTabWidget#inventoryRootTabs::pane {{
                background: transparent;
                border: none;
                border-radius: {scale_px(14, self._ui_scale)}px;
            }}
            QFrame#inventorySubTabs {{
                background: {SURFACE_ALT};
                border: none;
                border-radius: {scale_px(14, self._ui_scale)}px;
            }}
            QStackedWidget#inventorySubStack {{
                background: transparent;
                border: none;
            }}
            QStackedWidget#sectionTransparentStack,
            QStackedWidget#planEditorStack {{
                background: transparent;
                border: none;
            }}
            QWidget#inventoryPaneContent {{
                background: transparent;
                border: none;
            }}
            QScrollArea#sectionScrollArea {{
                background: transparent;
                border: none;
            }}
            QScrollArea#sectionScrollArea > QWidget > QWidget {{
                background: transparent;
                border: none;
            }}
            QTabBar#inventorySubTabBar {{
                background: transparent;
                border: none;
            }}
            QTabBar#inventorySubTabBar::tab {{
                background: transparent;
                color: {MUTED};
                border: none;
                border-bottom: {scale_px(2, self._ui_scale)}px solid transparent;
                border-radius: 0px;
                padding: {scale_px(10, self._ui_scale)}px {scale_px(16, self._ui_scale)}px;
                margin-right: {scale_px(10, self._ui_scale)}px;
                font-size: {scale_px(12, self._ui_scale)}px;
                font-weight: 800;
            }}
            QTabBar#inventorySubTabBar::tab:hover {{
                color: {INK};
                border-bottom-color: {ACCENT_SOFT};
            }}
            QTabBar#inventorySubTabBar::tab:selected {{
                color: {ACCENT_STRONG};
                border-bottom-color: {ACCENT};
                font-weight: 900;
            }}
            QFrame#header, QFrame#panel, QFrame#statPanel, QFrame#summaryCard, QFrame#scanInventoryCard {{
                background: {SURFACE};
                border: 1px solid {BORDER};
                border-radius: {scale_px(14, self._ui_scale)}px;
            }}
            QFrame#scanHeader {{
                background: {SURFACE};
                border: 1px solid {BORDER};
                border-radius: {scale_px(14, self._ui_scale)}px;
            }}
            QFrame#scanHeader[connected="true"] {{
                border: {scale_px(3, self._ui_scale)}px solid #76d7ff;
            }}
            QFrame#scanPreviewPanel {{
                background: #05070d;
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.12)};
                border-radius: {scale_px(14, self._ui_scale)}px;
            }}
            QFrame#scanStudentCard, QFrame#scanStudentCaptureCard {{
                background: {_mix_hex(SURFACE_ALT, BG, 0.08)};
                border: none;
                border-radius: {scale_px(8, self._ui_scale)}px;
            }}
            QFrame#scanStudentMetaPanel {{
                background: {_mix_hex(PALETTE_PANEL, SURFACE_ALT, 0.18)};
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.2)};
                border-radius: {scale_px(8, self._ui_scale)}px;
            }}
            QLabel#scanStudentValue {{
                color: {INK};
                font-size: {scale_px(13, self._ui_scale)}px;
                font-weight: 900;
            }}
            QSplitter#inventorySplitter,
            QSplitter#sectionSplitter {{
                background: transparent;
                border: none;
            }}
            QSplitter#inventorySplitter::handle,
            QSplitter#sectionSplitter::handle {{
                background: transparent;
                border: none;
            }}
            QSplitter#inventorySplitter::handle:horizontal,
            QSplitter#sectionSplitter::handle:horizontal {{
                width: {scale_px(10, self._ui_scale)}px;
            }}
            QFrame#heroWrap {{
                background: {SURFACE_ALT};
                border: 1px solid {BORDER};
                border-radius: {scale_px(18, self._ui_scale)}px;
            }}
            QLabel#title {{ font-size: {scale_px(24, self._ui_scale)}px; font-weight: 800; color: {INK}; }}
            QLabel#count, QLabel#detailSub, QLabel#filterSummary, QLabel#sectionSub, QLabel#kpiValueSub {{ color: {MUTED}; }}
            QLabel#scanProfile {{
                color: #ff8fd6;
                font-size: {scale_px(15, self._ui_scale)}px;
                font-weight: 900;
            }}
            QLabel#sectionTitle {{ font-size: {scale_px(15, self._ui_scale)}px; font-weight: 800; color: {INK}; }}
            QLabel#badge {{
                background: {ACCENT_PALE};
                color: {ACCENT_STRONG};
                border: 1px solid {ACCENT_SOFT};
                border-radius: {scale_px(9, self._ui_scale)}px;
                padding: {scale_px(4, self._ui_scale)}px {scale_px(8, self._ui_scale)}px;
            }}
            QLabel#metricValue {{ font-size: {scale_px(22, self._ui_scale)}px; font-weight: 800; color: {INK}; }}
            QLabel#metricLabel {{ color: {MUTED}; font-size: {scale_px(11, self._ui_scale)}px; text-transform: uppercase; }}
            QLineEdit, QComboBox, QPushButton, QPlainTextEdit {{
                background: {SURFACE};
                border: 1px solid {BORDER};
                border-radius: {scale_px(9, self._ui_scale)}px;
                padding: {scale_px(8, self._ui_scale)}px {scale_px(10, self._ui_scale)}px;
                min-height: {scale_px(22, self._ui_scale)}px;
            }}
            QPushButton {{
                background: transparent;
                color: #ffb5f0;
                border: 1px solid {_mix_hex("#ffb5f0", SURFACE_ALT, 0.28)};
                font-weight: 700;
            }}
            QPushButton:hover {{
                background: transparent;
                color: #ffb5f0;
                border-color: {_mix_hex("#ffb5f0", "#ffffff", 0.18)};
            }}
            QPushButton:checked {{
                background: transparent;
                color: #ffb5f0;
                border: 2px solid #ffb5f0;
            }}
            QPushButton:disabled {{
                background: transparent;
                color: {MUTED};
                border-color: {_mix_hex(BORDER, SURFACE_ALT, 0.28)};
            }}
            QComboBox, QLineEdit, QPlainTextEdit {{
                background: {SURFACE_ALT};
                color: {INK};
            }}
            QCheckBox {{
                color: {MUTED};
                spacing: {scale_px(8, self._ui_scale)}px;
            }}
            QListWidget#roundedList,
            QListWidget#planQuickAddList {{
                background: {SURFACE_ALT};
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.36)};
                border-radius: {scale_px(14, self._ui_scale)}px;
                padding: 0px;
            }}
            QListWidget#roundedList::item,
            QListWidget#planQuickAddList::item {{
                background: transparent;
                border: none;
                padding: 0px;
            }}
            QListWidget#roundedList::item:selected,
            QListWidget#planQuickAddList::item:selected {{
                background: transparent;
                border: none;
            }}
            QAbstractItemView {{
                selection-background-color: transparent;
            }}
            QLabel#hero {{
                background: transparent;
                border: none;
                border-radius: {scale_px(16, self._ui_scale)}px;
            }}
            QLabel#detailName {{ font-size: {scale_px(28, self._ui_scale)}px; font-weight: 700; }}
            QFrame#detailCard {{
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 {SURFACE_ALT}, stop:1 {SURFACE});
                border: 1px solid {BORDER};
                border-radius: {scale_px(18, self._ui_scale)}px;
            }}
            QLabel#detailInlineName {{
                font-size: {scale_px(24, self._ui_scale)}px;
                font-weight: 800;
                color: {INK};
            }}
            QLabel#detailInlineSub, QLabel#detailMetaLine, QLabel#detailSectionTitle, QLabel#detailSkillLabel, QLabel#detailEquipCaption {{
                color: {MUTED};
            }}
            QLabel#detailSectionTitle {{
                font-size: {scale_px(11, self._ui_scale)}px;
                font-weight: 700;
                letter-spacing: 1px;
            }}
            QLabel#detailChip {{
                border-radius: {scale_px(10, self._ui_scale)}px;
                padding: {scale_px(5, self._ui_scale)}px {scale_px(10, self._ui_scale)}px;
                font-weight: 700;
            }}
            QLabel#detailBigValue {{
                font-size: {scale_px(44, self._ui_scale)}px;
                font-weight: 900;
            }}
            QLabel#detailMiniValue {{
                font-size: {scale_px(20, self._ui_scale)}px;
                font-weight: 800;
                color: {INK};
            }}
            QLabel#scanLiveMiniValue {{
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 800;
                color: {INK};
            }}
            QLabel#scanLiveWeaponValue {{
                font-size: {scale_px(16, self._ui_scale)}px;
                font-weight: 800;
                color: {INK};
            }}
            QLabel#inventoryDetailMetricValue {{
                font-size: {scale_px(18, self._ui_scale)}px;
                font-weight: 800;
                color: {INK};
            }}
            QLabel#inventoryValue {{
                font-size: {scale_px(13, self._ui_scale)}px;
                font-weight: 800;
                color: {INK};
            }}
            QLabel#inventoryPressureAmount {{
                font-size: {scale_px(11, self._ui_scale)}px;
                font-weight: 900;
            }}
            QLabel#inventoryPressureCoverage {{
                color: {MUTED};
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 800;
            }}
            QLabel#inventoryCoveragePercent {{
                color: {INK};
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 900;
            }}
            QLabel#inventoryCoverageCaption {{
                color: {MUTED};
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 900;
            }}
            QLabel#inventoryStudentDemand {{
                color: {INK};
                font-size: {scale_px(15, self._ui_scale)}px;
                font-weight: 900;
            }}
            QLabel#inventoryColumnHeader {{
                color: {MUTED};
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 800;
            }}
            QPushButton#inventoryModeButton {{
                background: transparent;
                color: #ffa9f5;
                border: 1px solid {_mix_hex("#ffa9f5", SURFACE_ALT, 0.25)};
                border-radius: {scale_px(12, self._ui_scale)}px;
                padding: {scale_px(8, self._ui_scale)}px {scale_px(16, self._ui_scale)}px;
                font-size: {scale_px(13, self._ui_scale)}px;
                font-weight: 800;
            }}
            QPushButton#inventoryModeButton:hover {{
                background: transparent;
                color: #ffa9f5;
                border-color: {_mix_hex("#ffa9f5", "#ffffff", 0.18)};
            }}
            QPushButton#inventoryModeButton:checked {{
                background: transparent;
                color: #ffa9f5;
                border: 2px solid #ffa9f5;
            }}
            QPushButton#inventorySortDropdownButton {{
                background: transparent;
                color: #ffb5f0;
                border: 1px solid {_mix_hex("#ffb5f0", SURFACE_ALT, 0.28)};
                border-radius: {scale_px(9, self._ui_scale)}px;
                padding: {scale_px(8, self._ui_scale)}px {scale_px(24, self._ui_scale)}px {scale_px(8, self._ui_scale)}px {scale_px(16, self._ui_scale)}px;
                min-height: {scale_px(22, self._ui_scale)}px;
                font-size: {scale_px(13, self._ui_scale)}px;
                font-weight: 800;
                text-align: left;
            }}
            QPushButton#inventorySortDropdownButton::menu-indicator {{
                subcontrol-origin: padding;
                subcontrol-position: center right;
                right: {scale_px(8, self._ui_scale)}px;
            }}
            QPushButton#inventorySortDropdownButton:hover {{
                background: transparent;
                color: #ffb5f0;
                border: 1px solid {_mix_hex("#ffb5f0", "#ffffff", 0.18)};
            }}
            QMenu {{
                background: {SURFACE_ALT};
                color: {INK};
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.24)};
                border-radius: {scale_px(10, self._ui_scale)}px;
                padding: {scale_px(4, self._ui_scale)}px;
            }}
            QMenu::item {{
                padding: {scale_px(7, self._ui_scale)}px {scale_px(18, self._ui_scale)}px;
                border-radius: {scale_px(7, self._ui_scale)}px;
            }}
            QMenu::item:selected {{
                background: {ACCENT_SOFT};
                color: {INK};
            }}
            QPushButton#inventoryMiniModeButton {{
                background: transparent;
                color: #ffb5f0;
                border: 1px solid {_mix_hex("#ffb5f0", SURFACE_ALT, 0.28)};
                border-radius: {scale_px(10, self._ui_scale)}px;
                padding: {scale_px(4, self._ui_scale)}px {scale_px(9, self._ui_scale)}px;
                min-height: {scale_px(18, self._ui_scale)}px;
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 800;
            }}
            QPushButton#inventoryMiniModeButton:hover {{
                background: transparent;
                color: #ffb5f0;
                border-color: {_mix_hex("#ffb5f0", "#ffffff", 0.18)};
            }}
            QPushButton#inventoryMiniModeButton:checked {{
                background: transparent;
                color: #ffb5f0;
                border: 2px solid #ffb5f0;
            }}
            QProgressBar#inventoryPressureBar {{
                background: transparent;
                border: 1px solid rgba(255, 255, 255, 0.78);
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QProgressBar#inventoryPressureBar::chunk {{
                background: #ff304f;
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QProgressBar#inventoryPlanCoverageBar,
            QProgressBar#inventoryPoolCoverageBar {{
                background: #ffffff;
                border: 1px solid #e1e4eb;
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QProgressBar#inventoryPlanCoverageBar[empty="true"],
            QProgressBar#inventoryPoolCoverageBar[empty="true"] {{
                background: transparent;
                border: 1px solid rgba(255, 255, 255, 0.78);
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QProgressBar#inventoryPlanCoverageBar::chunk {{
                background: #ff304f;
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QProgressBar#inventoryPoolCoverageBar::chunk {{
                background: #ffb5f0;
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QProgressBar#inventoryBottleneckBar {{
                background: transparent;
                border: none;
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QProgressBar#inventoryBottleneckBar::chunk {{
                background: #ff304f;
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QLabel#inventoryBottleneckName {{
                color: #f7fbff;
                font-size: {scale_px(11, self._ui_scale)}px;
                font-weight: 800;
            }}
            QLabel#inventoryBottleneckRatio {{
                color: {MUTED};
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 800;
            }}
            QProgressBar#inventorySchoolRiskBar {{
                background: transparent;
                border: none;
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QProgressBar#inventorySchoolRiskBar::chunk {{
                background: #ff304f;
                border-radius: {scale_px(3, self._ui_scale)}px;
            }}
            QLabel#inventorySchoolRiskPercent {{
                color: {MUTED};
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 800;
            }}
            QLabel#inventoryStatus {{
                border-radius: {scale_px(8, self._ui_scale)}px;
                padding: {scale_px(4, self._ui_scale)}px {scale_px(7, self._ui_scale)}px;
                font-size: {scale_px(11, self._ui_scale)}px;
                font-weight: 800;
                background: transparent;
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.18)};
                color: {MUTED};
            }}
            QLabel#inventoryStatus[status="sufficient"] {{
                background: transparent;
                border-color: #ffa9f5;
                color: #ffa9f5;
            }}
            QLabel#inventoryStatus[status="plan_shortage"] {{
                background: transparent;
                border-color: #ff304f;
                color: #ff304f;
            }}
            QLabel#inventoryStatus[status="long_term_pressure"] {{
                background: transparent;
                border-color: #ffb5f0;
                color: #ffb5f0;
            }}
            QLabel#inventoryStatus[status="unused"] {{
                background: transparent;
                border-color: #8b93a7;
                color: #8b93a7;
            }}
            QLabel#inventoryStatus[status="high_tier_bottleneck"] {{
                background: transparent;
                border-color: #d7193f;
                color: #d7193f;
            }}
            QLabel#inventoryRequiredBadge {{
                background: transparent;
                border: 1px solid #ffb5f0;
                border-radius: {scale_px(8, self._ui_scale)}px;
                color: #ffb5f0;
                font-size: {scale_px(10, self._ui_scale)}px;
                font-weight: 800;
                padding: {scale_px(2, self._ui_scale)}px {scale_px(7, self._ui_scale)}px;
            }}
            QLabel#inventoryHintPink {{
                background: transparent;
                color: #ffb5f0;
                border: 1px solid {_mix_hex("#ffb5f0", SURFACE_ALT, 0.28)};
                border-radius: {scale_px(8, self._ui_scale)}px;
                padding: {scale_px(8, self._ui_scale)}px;
                font-weight: 700;
            }}
            QLabel#inventoryHintBlue {{
                background: transparent;
                color: #9fd4ff;
                border: 1px solid {_mix_hex("#9fd4ff", SURFACE_ALT, 0.28)};
                border-radius: {scale_px(8, self._ui_scale)}px;
                padding: {scale_px(8, self._ui_scale)}px;
                font-weight: 700;
            }}
            QLabel#detailMiniSub {{
                color: {MUTED};
                font-size: {scale_px(12, self._ui_scale)}px;
            }}
            QFrame#planSectionPanel {{
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 {_mix_hex(SURFACE, '#ffffff', 0.06)}, stop:1 {_mix_hex(SURFACE, SURFACE_ALT, 0.18)});
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.08)};
                border-radius: {scale_px(16, self._ui_scale)}px;
            }}
            QFrame#raidDeckGroup {{
                background: {_mix_hex(SURFACE_ALT, SURFACE, 0.42)};
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.22)};
                border-radius: {scale_px(12, self._ui_scale)}px;
            }}
            QFrame#inventoryContentPanel {{
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 {_mix_hex(SURFACE, '#ffffff', 0.06)}, stop:1 {_mix_hex(SURFACE, SURFACE_ALT, 0.18)});
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.18)};
                border-radius: {scale_px(16, self._ui_scale)}px;
            }}
            #planEditorInventoryShell {{
                background: {_mix_hex(SURFACE_ALT, BG, 0.08)};
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.36)};
                border-radius: {scale_px(14, self._ui_scale)}px;
            }}
            #planEditorSectionCard {{
                background: transparent;
                border: none;
            }}
            #planBand {{
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 {_mix_hex(SURFACE_ALT, '#ffffff', 0.03)}, stop:1 {_mix_hex(SURFACE_ALT, BG, 0.14)});
                border: 1px solid {_mix_hex(BORDER, SURFACE_ALT, 0.24)};
                border-radius: {scale_px(18, self._ui_scale)}px;
            }}
            #planBand QLabel#sectionTitle,
            #planBand QLabel#detailSectionTitle {{
                color: #f7fbff;
            }}
            #planEditorSectionCard QLabel#sectionTitle,
            #planEditorSectionCard QLabel#detailSectionTitle {{
                color: #f7fbff;
            }}
            QFrame#inventoryPressureRow {{
                background: transparent;
                border: none;
                border-radius: 0px;
            }}
            QWidget#planTransparent {{
                background: transparent;
                border: none;
            }}
            QLineEdit#planValueInput {{
                background: {_mix_hex(SURFACE_ALT, BG, 0.04)};
                border: 1px solid {_mix_hex(BORDER, '#ffffff', 0.08)};
                border-radius: {scale_px(11, self._ui_scale)}px;
                padding: {scale_px(6, self._ui_scale)}px {scale_px(10, self._ui_scale)}px;
                font-size: {scale_px(17, self._ui_scale)}px;
                font-weight: 800;
                color: {INK};
            }}
            QLineEdit#planValueInput:disabled {{
                color: {MUTED};
                background: {_mix_hex(SURFACE_ALT, BG, 0.22)};
            }}
            QPushButton#planQuickButton {{
                background: transparent;
                color: #ffa9f5;
                border: 1px solid {_mix_hex("#ffa9f5", SURFACE_ALT, 0.25)};
                border-radius: {scale_px(11, self._ui_scale)}px;
                padding: {scale_px(6, self._ui_scale)}px {scale_px(12, self._ui_scale)}px;
                font-size: {scale_px(12, self._ui_scale)}px;
                font-weight: 800;
                min-width: {scale_px(58, self._ui_scale)}px;
            }}
            QPushButton#planQuickButton:checked,
            QPushButton#resourceModeButton:checked {{
                background: transparent;
                color: #ffa9f5;
                border: 2px solid #ffa9f5;
            }}
            QPushButton#resourceModeButton {{
                background: transparent;
                color: #ffa9f5;
                border: 1px solid {_mix_hex("#ffa9f5", SURFACE_ALT, 0.25)};
                border-radius: {scale_px(11, self._ui_scale)}px;
                padding: {scale_px(6, self._ui_scale)}px {scale_px(14, self._ui_scale)}px;
                font-size: {scale_px(12, self._ui_scale)}px;
                font-weight: 800;
                min-width: {scale_px(58, self._ui_scale)}px;
            }}
            QLabel#resourceSectionTitle {{
                font-size: {scale_px(17, self._ui_scale)}px;
                font-weight: 900;
                color: {INK};
            }}
            QPushButton#planQuickButton:disabled {{
                background: transparent;
                color: {MUTED};
                border-color: {_mix_hex(BORDER, SURFACE_ALT, 0.28)};
            }}
            QPushButton#planStepButton {{
                background: transparent;
                color: #ffb5f0;
                border: 1px solid {_mix_hex("#ffb5f0", SURFACE_ALT, 0.28)};
                border-radius: {scale_px(11, self._ui_scale)}px;
                padding: {scale_px(4, self._ui_scale)}px;
                font-size: {scale_px(15, self._ui_scale)}px;
                font-weight: 900;
                min-width: {scale_px(28, self._ui_scale)}px;
            }}
            QPushButton#planStepButton:hover {{
                background: transparent;
                border-color: {_mix_hex("#ffb5f0", "#ffffff", 0.18)};
            }}
            QPushButton#planStepButton:disabled {{
                color: {MUTED};
                background: transparent;
                border-color: {_mix_hex(BORDER, SURFACE_ALT, 0.28)};
            }}
            QPushButton#planDisclosureButton {{
                background: transparent;
                color: #ffb5f0;
                border: 1px solid {_mix_hex("#ffb5f0", SURFACE_ALT, 0.28)};
                border-radius: {scale_px(11, self._ui_scale)}px;
                padding: {scale_px(7, self._ui_scale)}px {scale_px(10, self._ui_scale)}px;
                font-size: {scale_px(11, self._ui_scale)}px;
                font-weight: 800;
                text-align: left;
            }}
            QPushButton#planDisclosureButton:hover {{
                background: transparent;
                color: #ffb5f0;
                border-color: {_mix_hex("#ffb5f0", "#ffffff", 0.18)};
            }}
            QLabel#detailSkillValue {{
                color: {INK};
                font-size: {scale_px(21, self._ui_scale)}px;
                font-weight: 800;
            }}
            QLabel#detailEquipValue {{
                color: {INK};
                font-size: {scale_px(22, self._ui_scale)}px;
                font-weight: 800;
            }}
            QLabel#statValue {{ color: {INK}; font-weight: 700; }}
            QGroupBox {{
                border: 1px solid {BORDER};
                border-radius: {scale_px(12, self._ui_scale)}px;
                margin-top: {scale_px(10, self._ui_scale)}px;
                padding-top: {scale_px(12, self._ui_scale)}px;
                background: {SURFACE};
                font-weight: 700;
            }}
            QGroupBox::title {{
                subcontrol-origin: margin;
                left: {scale_px(12, self._ui_scale)}px;
                padding: 0 {scale_px(4, self._ui_scale)}px;
                color: {INK};
            }}
            QSpinBox {{
                background: {SURFACE_ALT};
                border: 1px solid {BORDER};
                border-radius: {scale_px(8, self._ui_scale)}px;
                padding: {scale_px(6, self._ui_scale)}px {scale_px(8, self._ui_scale)}px;
            }}
            QScrollBar:vertical {{
                background: {SURFACE_ALT};
                width: {scale_px(12, self._ui_scale)}px;
                margin: {scale_px(4, self._ui_scale)}px;
                border-radius: {scale_px(6, self._ui_scale)}px;
            }}
            QScrollBar::handle:vertical {{
                background: {ACCENT_SOFT};
                min-height: {scale_px(36, self._ui_scale)}px;
                border-radius: {scale_px(6, self._ui_scale)}px;
            }}
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical,
            QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {{
                background: transparent;
                border: none;
                height: 0px;
            }}
            """
        )
        self._build_busy_overlay(root)
    def _build_students_tab(self, root: QWidget) -> None:
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
        title = QLabel("Blue Archive Planner")
        title.setObjectName("title")
        title_wrap.addWidget(title)
        subtitle = QLabel("학생 목록과 현재 성장 상태를 확인하고 육성 계획을 구성합니다.")
        subtitle.setObjectName("count")
        title_wrap.addWidget(subtitle)
        header_layout.addLayout(title_wrap, 1)

        self._count_label = QLabel("")
        self._count_label.setObjectName("count")
        header_layout.addWidget(self._count_label)
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

        self._search = LiveSearchLineEdit()
        self._search.setPlaceholderText("학생 이름, ID, 태그로 검색")
        self._search.liveTextChanged.connect(self._schedule_filter_refresh)
        toolbar_layout.addWidget(self._search, 3)

        self._sort_mode = InventorySortDropdownButton()
        self._sort_mode.addItem("성급 높은순", "star_desc")
        self._sort_mode.addItem("성급 낮은순", "star_asc")
        self._sort_mode.addItem("레벨 높은순", "level_desc")
        self._sort_mode.addItem("이름순", "name_asc")
        self._sort_mode.modeChanged.connect(lambda *_: self._apply_filters())
        toolbar_layout.addWidget(self._sort_mode, 0, Qt.AlignVCenter)

        self._show_unowned = QCheckBox("미보유 학생 표시")
        self._show_unowned.setChecked(True)
        self._show_unowned.stateChanged.connect(self._apply_filters)
        toolbar_layout.addWidget(self._show_unowned)

        self._hide_jp_only = QCheckBox("일본 서버 전용 숨김")
        self._hide_jp_only.stateChanged.connect(self._apply_filters)
        toolbar_layout.addWidget(self._hide_jp_only)

        self._filter_button = QPushButton("필터")
        self._filter_button.setObjectName("planQuickButton")
        self._filter_button.clicked.connect(self._open_filter_dialog)
        toolbar_layout.addWidget(self._filter_button)

        refresh_button = QPushButton("새로고침")
        refresh_button.setObjectName("planQuickButton")
        refresh_button.clicked.connect(self._reload_data)
        toolbar_layout.addWidget(refresh_button)
        layout.addWidget(toolbar)

        self._filter_summary = QLabel("적용된 필터 없음")
        self._filter_summary.setWordWrap(True)
        self._filter_summary.setObjectName("filterSummary")
        layout.addWidget(self._filter_summary)

        content = QSplitter(Qt.Horizontal)
        content.setObjectName("sectionSplitter")
        content.setChildrenCollapsible(False)
        layout.addWidget(content, 1)

        list_panel = QFrame()
        list_panel.setObjectName("planSectionPanel")
        list_layout = QVBoxLayout(list_panel)
        list_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        list_layout.setSpacing(scale_px(10, self._ui_scale))

        detail = RoundedMaskFrame(ui_scale=self._ui_scale, radius=16)
        detail.setObjectName("planSectionPanel")
        detail.setFrameShape(QFrame.NoFrame)
        detail.setAttribute(Qt.WA_StyledBackground, True)
        detail_shell_layout = QVBoxLayout(detail)
        detail_shell_layout.setContentsMargins(0, 0, 0, 0)
        detail_shell_layout.setSpacing(0)
        detail_body = QWidget()
        detail_body.setObjectName("planTransparent")
        detail_body.setAutoFillBackground(False)
        detail_body.setAttribute(Qt.WA_TranslucentBackground, True)
        self._detail_panel = detail_body  # type: ignore[assignment]
        detail_shell_layout.addWidget(detail_body)
        detail_layout = QVBoxLayout(detail_body)
        detail_layout.setContentsMargins(
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
        )
        detail_layout.setSpacing(scale_px(10, self._ui_scale))

        hero_wrap = QFrame()
        self._hero_wrap = hero_wrap
        hero_wrap.setObjectName("heroWrap")
        hero_layout = QVBoxLayout(hero_wrap)
        hero_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
        )
        self._hero = StudentPortraitWidget(self._student_card_asset)
        self._hero.setObjectName("hero")
        self._hero.setMinimumWidth(scale_px(286, self._ui_scale))
        hero_layout.addWidget(self._hero)
        detail_layout.addWidget(hero_wrap)

        detail_card = QFrame()
        detail_card.setObjectName("detailCard")
        detail_card_layout = QVBoxLayout(detail_card)
        detail_card_layout.setContentsMargins(
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
            scale_px(12, self._ui_scale),
        )
        detail_card_layout.setSpacing(scale_px(8, self._ui_scale))

        bar_row = QHBoxLayout()
        bar_row.setContentsMargins(0, 0, 0, 0)
        bar_row.setSpacing(scale_px(6, self._ui_scale))
        self._detail_attack_bar = ParallelogramPanel(fill=ACCENT_SOFT, border=ACCENT, slant=DETAIL_SLANT)
        self._detail_attack_bar.setFixedHeight(scale_px(8, self._ui_scale))
        self._detail_defense_bar = ParallelogramPanel(fill=ACCENT_PALE, border=PALETTE_SOFT, slant=DETAIL_SLANT)
        self._detail_defense_bar.setFixedHeight(scale_px(8, self._ui_scale))
        bar_row.addWidget(self._detail_attack_bar, 1)
        bar_row.addWidget(self._detail_defense_bar, 1)
        detail_card_layout.addLayout(bar_row)

        self._detail_progress_strip = DetailProgressStrip()
        detail_card_layout.addWidget(self._detail_progress_strip)

        name_row = QHBoxLayout()
        name_row.setContentsMargins(0, 0, 0, 0)
        name_row.setSpacing(scale_px(10, self._ui_scale))
        self._detail_school_icon = QLabel()
        self._detail_school_icon.setFixedSize(scale_px(26, self._ui_scale), scale_px(26, self._ui_scale))
        self._detail_school_icon.setScaledContents(False)
        name_row.addWidget(self._detail_school_icon, 0, Qt.AlignTop)
        name_col = QVBoxLayout()
        name_col.setContentsMargins(0, 0, 0, 0)
        name_col.setSpacing(scale_px(2, self._ui_scale))
        self._name = QLabel("학생을 선택하세요")
        self._name.setObjectName("detailInlineName")
        self._subtitle = QLabel("")
        self._subtitle.setObjectName("detailInlineSub")
        self._detail_badges = QLabel("")
        self._detail_badges.setObjectName("detailMetaLine")
        self._detail_badges.setWordWrap(True)
        name_col.addWidget(self._name)
        name_col.addWidget(self._subtitle)
        name_col.addWidget(self._detail_badges)
        name_row.addLayout(name_col, 1)
        detail_card_layout.addLayout(name_row)

        chip_row = QHBoxLayout()
        chip_row.setContentsMargins(0, 0, 0, 0)
        chip_row.setSpacing(scale_px(8, self._ui_scale))
        self._detail_attack_chip = QLabel("-")
        self._detail_attack_chip.setObjectName("detailChip")
        self._detail_defense_chip = QLabel("-")
        self._detail_defense_chip.setObjectName("detailChip")
        chip_row.addWidget(self._detail_attack_chip, 0, Qt.AlignLeft)
        chip_row.addWidget(self._detail_defense_chip, 0, Qt.AlignLeft)
        chip_row.addStretch(1)
        detail_card_layout.addLayout(chip_row)

        self._detail_plan_button = ParallelogramButton("플랜에 추가", style=self._card_button_style)
        self._detail_plan_button.clicked.connect(self._add_current_student_to_plan)
        self._detail_plan_button.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self._detail_plan_button.setFixedHeight(scale_px(32, self._ui_scale))
        plan_row = QHBoxLayout()
        plan_row.setContentsMargins(0, 0, 0, 0)
        plan_row.addWidget(self._detail_plan_button, 1)
        detail_card_layout.addLayout(plan_row)

        stat_row = QHBoxLayout()
        stat_row.setContentsMargins(0, 0, 0, 0)
        stat_row.setSpacing(scale_px(6, self._ui_scale))
        level_card = ParallelogramPanel(fill=_mix_hex(PALETTE_SOFT, SURFACE_ALT, 0.52), border=PALETTE_SOFT, slant=DETAIL_SLANT)
        level_layout = QVBoxLayout(level_card)
        level_layout.setContentsMargins(scale_px(14, self._ui_scale), scale_px(14, self._ui_scale), scale_px(14, self._ui_scale), scale_px(14, self._ui_scale))
        level_layout.setSpacing(scale_px(6, self._ui_scale))
        level_title = QLabel("LEVEL")
        level_title.setObjectName("detailSectionTitle")
        level_title.setAlignment(Qt.AlignCenter)
        self._detail_level_value = QLabel("-")
        self._detail_level_value.setObjectName("detailBigValue")
        self._detail_level_value.setAlignment(Qt.AlignCenter)
        level_layout.addWidget(level_title)
        level_layout.addStretch(1)
        level_layout.addWidget(self._detail_level_value)
        level_layout.addStretch(1)
        stat_row.addWidget(level_card, 3)

        side_cards = QVBoxLayout()
        side_cards.setContentsMargins(0, 0, 0, 0)
        side_cards.setSpacing(scale_px(6, self._ui_scale))
        position_card = ParallelogramPanel(fill=_mix_hex(PALETTE_PANEL, PALETTE_SOFT, 0.16), border=PALETTE_SOFT, slant=DETAIL_SLANT)
        position_layout = QVBoxLayout(position_card)
        position_layout.setContentsMargins(scale_px(12, self._ui_scale), scale_px(10, self._ui_scale), scale_px(12, self._ui_scale), scale_px(10, self._ui_scale))
        position_layout.setSpacing(scale_px(2, self._ui_scale))
        self._detail_position_value = QLabel("-")
        self._detail_position_value.setObjectName("detailMiniValue")
        self._detail_position_value.setAlignment(Qt.AlignCenter)
        position_layout.addStretch(1)
        position_layout.addWidget(self._detail_position_value)
        position_layout.addStretch(1)
        side_cards.addWidget(position_card)

        class_card = ParallelogramPanel(fill=_mix_hex(PALETTE_PANEL, PALETTE_SOFT, 0.16), border=PALETTE_SOFT, slant=DETAIL_SLANT)
        class_layout = QVBoxLayout(class_card)
        class_layout.setContentsMargins(scale_px(12, self._ui_scale), scale_px(10, self._ui_scale), scale_px(12, self._ui_scale), scale_px(10, self._ui_scale))
        class_layout.setSpacing(scale_px(2, self._ui_scale))
        self._detail_class_value = QLabel("-")
        self._detail_class_value.setObjectName("detailMiniValue")
        self._detail_class_value.setAlignment(Qt.AlignCenter)
        class_layout.addStretch(1)
        class_layout.addWidget(self._detail_class_value)
        class_layout.addStretch(1)
        side_cards.addWidget(class_card)

        self._detail_weapon_card = ParallelogramPanel(fill=_mix_hex(PALETTE_PANEL_ALT, PALETTE_SOFT, 0.12), border=PALETTE_SOFT, slant=DETAIL_SLANT)
        weapon_layout = QVBoxLayout(self._detail_weapon_card)
        weapon_layout.setContentsMargins(scale_px(12, self._ui_scale), scale_px(10, self._ui_scale), scale_px(12, self._ui_scale), scale_px(10, self._ui_scale))
        weapon_layout.setSpacing(scale_px(2, self._ui_scale))
        self._detail_weapon_value = QLabel("-")
        self._detail_weapon_value.setObjectName("detailMiniValue")
        self._detail_weapon_value.setAlignment(Qt.AlignCenter)
        self._detail_weapon_sub = QLabel("-")
        self._detail_weapon_sub.setObjectName("detailMiniSub")
        self._detail_weapon_sub.setAlignment(Qt.AlignCenter)
        weapon_layout.addStretch(1)
        weapon_layout.addWidget(self._detail_weapon_value)
        weapon_layout.addStretch(1)
        side_cards.addWidget(self._detail_weapon_card)
        stat_row.addLayout(side_cards, 2)
        detail_card_layout.addLayout(stat_row)

        skill_row = QHBoxLayout()
        skill_row.setContentsMargins(0, 0, 0, 0)
        skill_row.setSpacing(scale_px(4, self._ui_scale))
        self._detail_skill_labels: dict[str, QLabel] = {}
        for index, (key, label) in enumerate((("ex", "EX"), ("s1", "N"), ("s2", "P"), ("s3", "S"))):
            skill_card = ParallelogramPanel(fill=_mix_hex(PALETTE_PANEL, PALETTE_ACCENT, 0.14), border=PALETTE_SOFT, slant=DETAIL_SLANT)
            skill_layout = QVBoxLayout(skill_card)
            skill_layout.setContentsMargins(scale_px(10, self._ui_scale), scale_px(10, self._ui_scale), scale_px(10, self._ui_scale), scale_px(10, self._ui_scale))
            skill_layout.setSpacing(scale_px(4, self._ui_scale))
            top = QLabel(label)
            top.setObjectName("detailSkillLabel")
            top.setAlignment(Qt.AlignCenter)
            value = QLabel("-")
            value.setObjectName("detailSkillValue")
            value.setAlignment(Qt.AlignCenter)
            self._detail_skill_labels[key] = value
            skill_layout.addStretch(1)
            skill_layout.addWidget(top)
            skill_layout.addWidget(value)
            skill_layout.addStretch(1)
            skill_row.addWidget(skill_card, 1)
        detail_card_layout.addLayout(skill_row)

        equip_row = QHBoxLayout()
        equip_row.setContentsMargins(0, 0, 0, 0)
        equip_row.setSpacing(0)
        self._detail_equip_cards: dict[str, EquipmentDetailCard] = {}
        for slot in ("equip1", "equip2", "equip3", "equip4"):
            card = EquipmentDetailCard(
                self._ui_scale,
                fill=_mix_hex(PALETTE_PANEL_ALT, PALETTE_SOFT, 0.18),
                border=PALETTE_SOFT,
                slant=DETAIL_SLANT,
            )
            equip_row.addWidget(card, 1)
            self._detail_equip_cards[slot] = card
        detail_card_layout.addLayout(equip_row)

        self._detail_stats_line = QLabel("-")
        self._detail_stats_line.setObjectName("detailMetaLine")
        self._detail_stats_line.setAlignment(Qt.AlignCenter)
        self._detail_stats_line.setTextFormat(Qt.RichText)
        self._detail_stats_line.setMinimumHeight(scale_px(38, self._ui_scale))
        self._detail_stats_line.setWordWrap(False)
        detail_card_layout.addWidget(self._detail_stats_line)

        self._detail_bonus_stats_line = QLabel("-")
        self._detail_bonus_stats_line.setObjectName("detailMetaLine")
        self._detail_bonus_stats_line.setAlignment(Qt.AlignCenter)
        self._detail_bonus_stats_line.setTextFormat(Qt.RichText)
        self._detail_bonus_stats_line.setMinimumHeight(scale_px(18, self._ui_scale))
        self._detail_bonus_stats_line.setWordWrap(False)
        detail_card_layout.addWidget(self._detail_bonus_stats_line)
        detail_layout.addWidget(detail_card)
        detail_layout.addStretch(1)
        self._student_grid_panel = PlanGridContentPanel(ui_scale=self._ui_scale)
        student_grid_panel_layout = QVBoxLayout(self._student_grid_panel)
        student_grid_panel_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        student_grid_panel_layout.setSpacing(0)

        self._student_grid = ParallelogramCardGrid(
            self._student_card_asset,
            self._ui_scale,
            min_card_width=self._student_grid_card_width,
            fixed_column_count=STUDENT_GRID_COLUMNS,
        )
        self._student_grid.setObjectName("studentGrid")
        self._student_grid.setFrameShape(QFrame.NoFrame)
        self._student_grid.setAutoFillBackground(False)
        self._student_grid.setAttribute(Qt.WA_TranslucentBackground, True)
        self._student_grid.viewport().setAutoFillBackground(False)
        self._student_grid.viewport().setAttribute(Qt.WA_TranslucentBackground, True)
        self._student_grid.viewport().setStyleSheet("background: transparent; border: none;")
        if self._student_grid.widget() is not None:
            self._student_grid.widget().setAutoFillBackground(False)
            self._student_grid.widget().setAttribute(Qt.WA_TranslucentBackground, True)
            self._student_grid.widget().setStyleSheet("background: transparent; border: none;")
        _install_planner_scroll_handle(self._student_grid, ui_scale=self._ui_scale)
        self._student_grid.current_changed.connect(self._on_student_card_changed)
        self._student_grid.layout_changed.connect(self._on_student_grid_layout_changed)
        student_grid_panel_layout.addWidget(self._student_grid, 1)
        list_layout.addWidget(self._student_grid_panel, 1)

        detail.setMinimumWidth(scale_px(356, self._ui_scale))
        detail.setMaximumWidth(scale_px(408, self._ui_scale))
        content.addWidget(list_panel)
        content.addWidget(detail)
        content.setStretchFactor(0, 5)
        content.setStretchFactor(1, 1)
        content.setSizes([scale_px(1168, self._ui_scale), scale_px(352, self._ui_scale)])
        content.splitterMoved.connect(lambda *_: QTimer.singleShot(0, self._sync_hero_height))
        QTimer.singleShot(0, self._sync_hero_height)
    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        QTimer.singleShot(0, self._sync_hero_height)
        self._sync_busy_overlay_geometry()
    def _build_busy_overlay(self, parent: QWidget) -> None:
        overlay = QFrame(parent)
        overlay.setObjectName("busyOverlay")
        overlay.setAttribute(Qt.WA_StyledBackground, True)
        overlay.hide()
        overlay.setGeometry(parent.rect())
        overlay.setStyleSheet(
            f"""
            QFrame#busyOverlay {{
                background: rgba(0, 0, 0, 132);
            }}
            QFrame#busyCard {{
                background: {SURFACE};
                border: 1px solid {BORDER};
                border-radius: {scale_px(10, self._ui_scale)}px;
            }}
            QProgressBar {{
                background: {SURFACE_ALT};
                border: 1px solid {BORDER};
                border-radius: {scale_px(5, self._ui_scale)}px;
                min-height: {scale_px(10, self._ui_scale)}px;
                max-height: {scale_px(10, self._ui_scale)}px;
            }}
            QProgressBar::chunk {{
                background: {ACCENT_STRONG};
                border-radius: {scale_px(5, self._ui_scale)}px;
            }}
            """
        )

        layout = QVBoxLayout(overlay)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setAlignment(Qt.AlignCenter)

        card = QFrame(overlay)
        card.setObjectName("busyCard")
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(
            scale_px(24, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(24, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        card_layout.setSpacing(scale_px(12, self._ui_scale))

        label = QLabel("저장 중...", card)
        label.setObjectName("sectionTitle")
        label.setAlignment(Qt.AlignCenter)
        progress = QProgressBar(card)
        progress.setRange(0, 0)
        progress.setTextVisible(False)
        progress.setFixedWidth(scale_px(220, self._ui_scale))

        card_layout.addWidget(label)
        card_layout.addWidget(progress, 0, Qt.AlignHCenter)
        layout.addWidget(card)

        self._busy_overlay = overlay
        self._busy_label = label
        self._busy_progress = progress
    def _sync_busy_overlay_geometry(self) -> None:
        if self._busy_overlay is None:
            return
        parent = self._busy_overlay.parentWidget()
        if parent is None:
            return
        self._busy_overlay.setGeometry(parent.rect())
    def _show_busy_overlay(
        self,
        text: str = "저장 중...",
        *,
        progress_current: int | None = None,
        progress_total: int | None = None,
    ) -> None:
        if self._busy_overlay is None:
            return
        if self._busy_label is not None:
            self._busy_label.setText(text)
        if self._busy_progress is not None:
            if progress_total is not None and progress_total > 0:
                self._busy_progress.setRange(0, int(progress_total))
                self._busy_progress.setValue(max(0, min(int(progress_current or 0), int(progress_total))))
            else:
                self._busy_progress.setRange(0, 0)
                self._busy_progress.setValue(0)
        self._sync_busy_overlay_geometry()
        self._busy_overlay.raise_()
        self._busy_overlay.show()
        if not self._busy_cursor_active:
            QApplication.setOverrideCursor(Qt.WaitCursor)
            self._busy_cursor_active = True
        QApplication.processEvents()
    def _update_busy_overlay_progress(self, current: int, total: int, text: str) -> None:
        safe_total = max(1, int(total))
        safe_current = max(0, min(int(current), safe_total))
        percent = round((safe_current / safe_total) * 100)
        if self._busy_label is not None:
            self._busy_label.setText(f"{text}\n{safe_current} / {safe_total} ({percent}%)")
        if self._busy_progress is not None:
            self._busy_progress.setRange(0, safe_total)
            self._busy_progress.setValue(safe_current)
    def _hide_busy_overlay(self) -> None:
        if self._busy_overlay is not None:
            self._busy_overlay.hide()
        if self._busy_cursor_active:
            QApplication.restoreOverrideCursor()
            self._busy_cursor_active = False
        QApplication.processEvents()
    def changeEvent(self, event) -> None:
        super().changeEvent(event)
        if event.type() == QEvent.WindowStateChange and not self._applying_work_area:
            if self.windowState() & Qt.WindowMaximized:
                QTimer.singleShot(0, self._apply_work_area_geometry)
            QTimer.singleShot(0, self._sync_hero_height)
    def _sync_hero_height(self) -> None:
        if self._hero_wrap is None or self._detail_panel is None or not hasattr(self, "_hero"):
            return
        wrap_width = self._hero_wrap.width()
        if wrap_width <= 0:
            return
        inset = scale_px(32, self._ui_scale)
        card_width = max(1, wrap_width - inset)
        card_height = max(1, int(round(card_width / max(0.01, self._student_card_asset.aspect_ratio))))
        preferred_height = card_height + inset
        detail_height = self._detail_panel.height()
        max_height = max(scale_px(196, self._ui_scale), int(detail_height * 0.37)) if detail_height > 0 else preferred_height
        wrap_height = min(preferred_height, max_height)
        self._hero_wrap.setFixedHeight(wrap_height)
    def eventFilter(self, watched, event) -> bool:
        if event.type() == QEvent.KeyPress and self._handle_student_tab_arrow_key(event):
            return True
        return super().eventFilter(watched, event)
    def _is_students_tab_active(self) -> bool:
        return (
            self._main_tabs is not None
            and self._students_tab is not None
            and self._main_tabs.currentWidget() is self._students_tab
        )
    def _open_students_tab(self) -> None:
        if self._main_tabs is not None and self._students_tab is not None:
            self._main_tabs.setCurrentWidget(self._students_tab)
    def _handle_student_tab_arrow_key(self, event) -> bool:
        if not self._is_students_tab_active():
            return False
        key = event.key()
        if key not in {Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down}:
            return False
        modifiers = event.modifiers()
        if modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier):
            return False
        focus = QApplication.focusWidget()
        if isinstance(
            focus,
            (
                QLineEdit,
                QPlainTextEdit,
                QComboBox,
                QAbstractSpinBox,
                QListWidget,
                QTableWidget,
                QTabBar,
            ),
        ):
            return False
        moved = self._move_student_selection_for_key(key)
        if moved:
            event.accept()
        return moved
    def _move_student_selection_for_key(self, key: int) -> bool:
        columns = max(1, STUDENT_GRID_COLUMNS)
        if key == Qt.Key_Left:
            return self._move_student_selection(-1)
        if key == Qt.Key_Right:
            return self._move_student_selection(1)
        if key == Qt.Key_Up:
            return self._move_student_selection(-columns)
        if key == Qt.Key_Down:
            return self._move_student_selection(columns)
        return False
    def _move_student_selection(self, step: int) -> bool:
        if not hasattr(self, "_student_grid") or not self._filtered_students:
            return False
        ids = [record.student_id for record in self._filtered_students if record.student_id in self._item_by_id]
        if not ids:
            return False
        current = self._student_grid.current_card_id()
        if current in ids:
            current_index = ids.index(current)
            next_index = max(0, min(len(ids) - 1, current_index + int(step)))
        else:
            next_index = 0 if step >= 0 else len(ids) - 1
        next_id = ids[next_index]
        if next_id == current:
            return False
        self._student_grid.set_current_card(next_id)
        return True
    def _poll_debug_ba_arrow_keys(self) -> None:
        if not self._student_scan_debug_enabled:
            return
        if not is_target_foreground():
            self._ba_arrow_key_down[VK_LEFT] = False
            self._ba_arrow_key_down[VK_RIGHT] = False
            return
        for vk, key in ((VK_LEFT, Qt.Key_Left), (VK_RIGHT, Qt.Key_Right)):
            down = _async_key_down(vk)
            was_down = self._ba_arrow_key_down.get(vk, False)
            self._ba_arrow_key_down[vk] = down
            if down and not was_down:
                self._open_students_tab()
                self._move_student_selection_for_key(key)
    def _refresh_card_layout(self) -> None:
        if self._card_layout_guard or not hasattr(self, "_student_grid"):
            return
        sizes = [self._student_grid.current_card_size()]
        if hasattr(self, "_plan_grid"):
            sizes.append(self._plan_grid.current_card_size())
        if hasattr(self, "_resource_scope_grid"):
            sizes.append(self._resource_scope_grid.current_card_size())
        if hasattr(self, "_resource_search_grid"):
            sizes.append(self._resource_search_grid.current_card_size())
        thumb_width = max(size.width() for size in sizes)
        thumb_height = max(size.height() for size in sizes)
        outer_margin = self._student_card_asset.style.outer_margin * 2
        grid_width = thumb_width + outer_margin
        grid_height = thumb_height + outer_margin

        if thumb_width <= 0 or thumb_height <= 0:
            return

        if (
            thumb_width == self._thumb_width
            and thumb_height == self._thumb_height
            and grid_width == self._grid_width
            and grid_height == self._grid_height
        ):
            return

        self._card_layout_guard = True
        try:
            self._thumb_width = thumb_width
            self._thumb_height = thumb_height
            self._grid_width = grid_width
            self._grid_height = grid_height
            self._placeholder_icon = make_placeholder_icon(self._thumb_width, self._thumb_height)
            self._unowned_icon_cache.clear()
            self._clear_thumb_requests()
            for student_id in sorted(
                set(self._item_by_id)
                | set(self._plan_card_by_id)
                | set(getattr(self, "_plan_search_card_by_id", {}))
                | set(getattr(self, "_resource_scope_card_by_id", {}))
                | set(getattr(self, "_resource_search_card_by_id", {}))
            ):
                self._enqueue_thumb(student_id)
        finally:
            self._card_layout_guard = False
    def _on_plan_grid_layout_changed(self, width: int, height: int) -> None:
        if hasattr(self, "_plan_search_grid"):
            search_width = max(80, int(round(width * 0.5)))
            search_height = max(scale_px(96, self._ui_scale), int(round(height * 0.5)) + scale_px(28, self._ui_scale))
            self._plan_search_grid.set_min_card_width(search_width)
            self._plan_search_grid.setFixedHeight(search_height)
            if hasattr(self, "_plan_search_grid_panel"):
                self._plan_search_grid_panel.setFixedHeight(search_height + scale_px(20, self._ui_scale))
        self._refresh_card_layout()
    def _reload_data(self) -> None:
        self._all_students = load_students()
        self._inventory_snapshot = load_inventory_snapshot()
        self._resource_snapshot = load_latest_resource_snapshot()
        self._inventory_quantity_index_cache = _inventory_quantity_index(self._inventory_snapshot or {}, self._resource_snapshot)
        self._plan = load_plan(self._plan_path)
        self._tactical_data = load_tactical_challenge(self._tactical_path, load_matches=False)
        self._raid_guide_data = load_raid_guides(self._raid_guide_path)
        self._invalidate_plan_caches()
        self._storage_mtimes = self._snapshot_storage_mtimes()
        self._records_by_id = {record.student_id: record for record in self._all_students}
        self._tactical_student_lookup_index = None
        self._raid_student_lookup_index = None
        self._filter_options = build_filter_options(self._all_students)
        self._unowned_icon_cache.clear()
        self._apply_filters()
        self._refresh_plan_lists()
        self._refresh_plan_totals()
        self._refresh_stats_tab()
        self._refresh_inventory_tab()
        self._refresh_tactical_tab()
        self._refresh_raid_guide_list()
        self._load_selected_raid_guide()
    def _schedule_filter_refresh(self, *_args) -> None:
        self._filter_refresh_timer.start()
    def _schedule_plan_search_refresh(self, *_args) -> None:
        self._plan_search_timer.start()
    def _apply_filters(self) -> None:
        for key in HIDDEN_STUDENT_FILTER_FIELDS:
            self._selected_filters.pop(key, None)
        active_search = self._resource_search if hasattr(self, "_resource_search") and self._resource_search.hasFocus() else self._search
        query = _live_line_edit_text(active_search).strip().casefold()
        sort_mode = self._sort_mode.currentData()

        items = [
            record
            for record in self._all_students
            if matches_student_filters(
                record,
                self._selected_filters,
                query,
                hide_jp_only=self._hide_jp_only.isChecked(),
            )
            and (self._show_unowned.isChecked() or record.owned)
        ]

        if sort_mode == "star_desc":
            items.sort(
                key=lambda record: (
                    -student_growth_sort_key(record)[0],
                    -student_growth_sort_key(record)[1],
                    -(record.level or 0),
                    record.title.lower(),
                )
            )
        elif sort_mode == "star_asc":
            items.sort(
                key=lambda record: (
                    student_growth_sort_key(record)[0],
                    student_growth_sort_key(record)[1],
                    record.level or 0,
                    record.title.lower(),
                )
            )
        elif sort_mode == "level_desc":
            items.sort(key=lambda record: (-(record.level or 0), -record.star, record.title.lower()))
        else:
            items.sort(key=lambda record: record.title.lower())

        self._filtered_students = items
        self._filter_summary.setText(
            summarize_filters(
                self._selected_filters,
                self._filter_options,
                hide_jp_only=self._hide_jp_only.isChecked(),
            )
        )
        active_count = active_filter_count(self._selected_filters) + int(self._hide_jp_only.isChecked())
        self._filter_button.setText(f"필터 ({active_count})" if active_count else "필터")
        self._rebuild_list()
        self._refresh_stats_tab()
        self._sync_resource_controls_from_students()
        self._refresh_resources_if_visible()
    def _open_filter_dialog(self) -> None:
        dialog = FilterDialog(self, self._filter_options, self._selected_filters, self._ui_scale)
        if dialog.exec() == QDialog.Accepted:
            self._selected_filters = dialog.selected_filters()
            self._apply_filters()
    def _rebuild_list(self) -> None:
        selected_id = self._current_student_id()
        old_cards = dict(self._item_by_id)
        cards: list[StudentCardWidget] = []
        next_by_id: dict[str, StudentCardWidget] = {}

        for record in self._filtered_students:
            card = old_cards.get(record.student_id)
            if card is None:
                card = self._build_student_card(record)
            else:
                self._apply_student_card_record(card, record)
            cards.append(card)
            next_by_id[record.student_id] = card

        self._item_by_id = next_by_id
        self._student_grid.set_cards(cards)

        for record in self._filtered_students:
            self._enqueue_thumb(record.student_id)

        owned_count = sum(1 for record in self._all_students if record.owned)
        self._count_label.setText(f"{len(self._filtered_students)}명 표시 / 전체 {len(self._all_students)}명 (보유 {owned_count}명)")

        if self._filtered_students:
            restore_id = selected_id if selected_id in self._item_by_id else self._filtered_students[0].student_id
            self._student_grid.set_current_card(restore_id)
        else:
            self._student_grid.set_current_card(None)
            self._clear_detail()
    def _remember_thumb_pixmap(self, student_id: str, width: int, height: int, pixmap: QPixmap) -> None:
        if pixmap.isNull():
            return
        key = (student_id, width, height)
        self._thumb_pixmap_cache[key] = pixmap
        self._thumb_pixmap_cache.move_to_end(key)
        while len(self._thumb_pixmap_cache) > self._thumb_pixmap_cache_limit:
            self._thumb_pixmap_cache.popitem(last=False)
    def _cached_thumb_pixmap(self, student_id: str, width: int, height: int, path: str | None = None) -> QPixmap | None:
        key = (student_id, width, height)
        cached = self._thumb_pixmap_cache.get(key)
        if cached is not None:
            self._thumb_pixmap_cache.move_to_end(key)
            return cached
        if not path:
            return None
        pixmap = QPixmap(path)
        if pixmap.isNull():
            return None
        self._remember_thumb_pixmap(student_id, width, height, pixmap)
        return pixmap
    def _apply_cached_thumb_to_card(self, card: StudentCardWidget) -> None:
        pixmap = self._cached_thumb_pixmap(card.student_id, self._thumb_width, self._thumb_height)
        if pixmap is not None:
            card.setPixmap(pixmap)
    def _clear_thumb_requests(self) -> None:
        self._thumb_pump.stop()
        self._thumb_loading.clear()
        self._pending_thumb_requests.clear()
        self._pending_thumb_lookup.clear()
    def _enqueue_thumb(self, student_id: str) -> None:
        request = (student_id, self._thumb_width, self._thumb_height)
        if request in self._thumb_loading or request in self._pending_thumb_lookup:
            return
        self._pending_thumb_requests.append(request)
        self._pending_thumb_lookup.add(request)
        if not self._thumb_pump.isActive():
            self._thumb_pump.start()
    def _visible_thumb_student_ids(self) -> set[str]:
        visible: set[str] = set()
        for attr in ("_student_grid", "_plan_grid", "_resource_scope_grid", "_resource_search_grid"):
            grid = getattr(self, attr, None)
            if grid is not None and grid.isVisible():
                visible.update(grid.visible_card_ids())
        return visible
    def _pop_next_thumb_request(self) -> tuple[str, int, int]:
        visible_ids = self._visible_thumb_student_ids()
        if visible_ids:
            for index, request in enumerate(self._pending_thumb_requests):
                if request[0] in visible_ids:
                    return self._pending_thumb_requests.pop(index)
        return self._pending_thumb_requests.pop(0)
    def _drain_thumb_queue(self) -> None:
        started = 0
        while (
            self._pending_thumb_requests
            and started < self._thumb_batch_size
            and len(self._thumb_loading) < self._thumb_max_in_flight
        ):
            student_id, width, height = self._pop_next_thumb_request()
            request = (student_id, width, height)
            self._pending_thumb_lookup.discard(request)
            if not self._has_any_card_target(student_id):
                continue
            self._queue_thumb(student_id, width, height)
            started += 1
        if not self._pending_thumb_requests or len(self._thumb_loading) >= self._thumb_max_in_flight:
            self._thumb_pump.stop()
    def _queue_thumb(self, student_id: str, width: int, height: int) -> None:
        request = (student_id, width, height)
        if request in self._thumb_loading:
            return

        self._thumb_loading.add(request)
        task = ThumbTask(student_id, width, height)
        task.signals.loaded.connect(self._apply_thumb)
        self._pool.start(task)
    def _apply_thumb(self, student_id: str, path: str, width: int, height: int) -> None:
        self._thumb_loading.discard((student_id, width, height))
        if self._pending_thumb_requests and not self._thumb_pump.isActive():
            self._thumb_pump.start()
        if not path:
            return
        if width != self._thumb_width or height != self._thumb_height:
            return

        pixmap = self._cached_thumb_pixmap(student_id, width, height, path)
        if pixmap is not None and not pixmap.isNull():
            if student_id in self._item_by_id:
                self._student_grid.set_card_pixmap(student_id, pixmap)
            if student_id in self._plan_card_by_id:
                self._plan_grid.set_card_pixmap(student_id, pixmap)
            if student_id in self._resource_scope_card_by_id:
                self._resource_scope_grid.set_card_pixmap(student_id, pixmap)
            if student_id in self._resource_search_card_by_id:
                self._resource_search_grid.set_card_pixmap(student_id, pixmap)
    def _on_student_card_changed(self, current: str | None, _previous: str | None) -> None:
        if not current:
            self._clear_detail()
            return

        record = next((entry for entry in self._filtered_students if entry.student_id == current), None)
        if record is None:
            self._clear_detail()
            return

        self._populate_detail(record)
    def _on_student_grid_layout_changed(self, _width: int, _height: int) -> None:
        self._refresh_card_layout()
    def _populate_detail(self, record: StudentRecord) -> None:
        attack_color = _attack_color(record.attack_type)
        defense_color = _defense_accent_color(record.defense_type)
        self._name.setText(record.title)
        self._subtitle.clear()
        self._detail_badges.clear()
        self._subtitle.setVisible(False)
        self._detail_badges.setVisible(False)
        self._detail_plan_button.setText("플랜에서 보기" if record.student_id in self._plan_goal_map() else "플랜에 추가")
        self._detail_attack_bar.setColors(_mix_hex(attack_color, SURFACE_ALT, 0.12), attack_color)
        self._detail_defense_bar.setColors(_mix_hex(defense_color, SURFACE_ALT, 0.12), defense_color)
        has_weapon_progress = record.owned and record.star >= 5 and (record.weapon_state or "") != "no_weapon_system"
        self._detail_progress_strip.setProgress(record.star if record.owned else 0, record.weapon_star or 0, has_weapon_progress)
        self._detail_attack_chip.setVisible(False)
        self._detail_defense_chip.setVisible(False)
        self._detail_level_value.setStyleSheet(f"color: {INK};")
        self._detail_weapon_value.setStyleSheet(f"color: {INK};")

        school_logo = _school_logo_path(record.school)
        if school_logo is not None:
            school_pixmap = QPixmap(str(school_logo))
            if not school_pixmap.isNull():
                self._detail_school_icon.setPixmap(_tinted_pixmap(school_pixmap, "#ffffff", self._detail_school_icon.size()))
            else:
                self._detail_school_icon.setPixmap(QPixmap())
        else:
            self._detail_school_icon.setPixmap(QPixmap())

        self._detail_level_value.setText(str(record.level or "-") if record.owned else "-")
        self._detail_position_value.setText(_position_label(record.position))
        self._detail_class_value.setText((record.combat_class or "-").title())
        has_weapon = record.owned and (record.weapon_state or "") != "no_weapon_system"
        self._detail_weapon_card.setVisible(True)
        self._detail_weapon_value.setText(f"Lv.{record.weapon_level}" if has_weapon and record.weapon_level is not None else "-")
        self._detail_weapon_sub.clear()

        self._detail_skill_labels["ex"].setText(str(record.ex_skill or "-") if record.owned else "-")
        self._detail_skill_labels["s1"].setText(str(record.skill1 or "-") if record.owned else "-")
        self._detail_skill_labels["s2"].setText(str(record.skill2 or "-") if record.owned else "-")
        self._detail_skill_labels["s3"].setText(str(record.skill3 or "-") if record.owned else "-")

        for index, slot in enumerate(("equip1", "equip2", "equip3"), start=1):
            tier = getattr(record, slot)
            tier_num = _parse_tier_number(tier)
            level = _int_or_none(getattr(record, f"{slot}_level"))
            value_text = _slot_placeholder(tier) if record.owned else "-"
            icon_path = _equipment_icon_path(record.student_id, index, tier) if record.owned else None
            icon_pixmap = QPixmap()
            if icon_path is not None:
                loaded = QPixmap(str(icon_path))
                if not loaded.isNull():
                    icon_pixmap = loaded
                    value_text = ""
            elif tier_num is not None:
                value_text = f"T{tier_num}"
            self._detail_equip_cards[slot].setData(
                icon=icon_pixmap,
                value=value_text,
                level=str(level) if record.owned and level is not None else "",
            )

        favorite_supported = student_meta.favorite_item_enabled(record.student_id)
        favorite_tier = _parse_tier_number(record.equip4)
        favorite_value = _slot_placeholder(record.equip4, supported=favorite_supported) if record.owned else "-"
        if record.owned and favorite_tier is not None:
            favorite_value = f"T{favorite_tier}"
        self._detail_equip_cards["equip4"].setData(
            icon=QPixmap(),
            value=favorite_value,
            level="",
        )

        combat_values = (record.combat_hp, record.combat_atk, record.combat_def, record.combat_heal)
        if record.owned and any(_int_or_none(value) is not None for value in combat_values):
            self._detail_stats_line.setText(_detail_stats_html((
                ("HP", record.combat_hp),
                ("ATK", record.combat_atk),
                ("DEF", record.combat_def),
                ("HEAL", record.combat_heal),
            ), font_px=scale_px(17, self._ui_scale)))
        else:
            self._detail_stats_line.setText("-")

        if record.owned:
            self._detail_bonus_stats_line.setText(_detail_bonus_stats_html((
                ("HP", record.stat_hp),
                ("ATK", record.stat_atk),
                ("HEAL", record.stat_heal),
            ), font_px=scale_px(13, self._ui_scale)))
        else:
            self._detail_bonus_stats_line.setText("-")

        hero_path = portrait_path(record.student_id)
        hero_size = self._hero.card_size()
        hero_source = None
        if hero_size.width() > 0 and hero_size.height() > 0:
            hero_source = ensure_thumbnail(record.student_id, hero_size.width(), hero_size.height())
        if hero_source is None:
            hero_source = hero_path

        if hero_source and hero_source.exists():
            pixmap = QPixmap(str(hero_source))
            if not pixmap.isNull():
                self._large_pixmap = pixmap
                self._hero.setPixmap(self._large_pixmap, owned=record.owned)
                return

        self._large_pixmap = None
        if record.owned:
            self._hero.clear()
        else:
            self._hero.setPixmap(self._unowned_icon(record.student_id).pixmap(self._hero.size()), owned=False)
    def _clear_detail(self) -> None:
        self._name.setText("학생을 선택하세요")
        self._subtitle.clear()
        self._detail_badges.clear()
        self._subtitle.setVisible(False)
        self._detail_badges.setVisible(False)
        self._detail_attack_chip.setVisible(False)
        self._detail_defense_chip.setVisible(False)
        self._detail_school_icon.setPixmap(QPixmap())
        self._detail_plan_button.setText("플랜에 추가")
        self._detail_progress_strip.setProgress(0, 0, False)
        self._detail_level_value.setText("-")
        self._detail_position_value.setText("-")
        self._detail_class_value.setText("-")
        self._detail_weapon_card.setVisible(False)
        self._detail_weapon_value.setText("-")
        self._detail_weapon_sub.clear()
        for label in self._detail_skill_labels.values():
            label.setText("-")
        for card in self._detail_equip_cards.values():
            card.clearData()
        self._detail_stats_line.setText("-")
        self._detail_bonus_stats_line.setText("-")
        self._hero.clear()
    def _current_student_id(self) -> str | None:
        if not hasattr(self, "_student_grid"):
            return None
        return self._student_grid.current_card_id()
    def _unowned_icon(self, student_id: str) -> QIcon:
        cached = self._unowned_icon_cache.get(student_id)
        if cached is None:
            cached = make_unowned_icon(student_id, self._thumb_width, self._thumb_height)
            self._unowned_icon_cache[student_id] = cached
        return cached
    @staticmethod
    def _equip_text(tier: str | None, level: int | None) -> str:
        if tier and level is not None:
            return f"{tier} / Lv.{level}"
        if tier:
            return tier
        return "-"
