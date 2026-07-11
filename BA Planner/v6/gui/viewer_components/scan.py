"""ScanTabComponent implementation extracted from the viewer façade."""

from __future__ import annotations

from gui import viewer_shared as _viewer_shared
from gui.bug_report_dialog import BugReportDialog

globals().update({name: value for name, value in vars(_viewer_shared).items() if not name.startswith("__")})


class ScanTabComponent:
    def _build_scan_student_card(self) -> QFrame:
        card = QFrame()
        card.setObjectName("scanStudentCard")
        card.setMinimumWidth(scale_px(560, self._ui_scale))
        card.setMinimumHeight(scale_px(410, self._ui_scale))
        card.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        self._scan_student_value_labels = {}
        self._scan_student_equip_cards = {}

        capture_layout = QVBoxLayout(card)
        capture_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        capture_layout.setSpacing(scale_px(12, self._ui_scale))

        top_row = QHBoxLayout()
        top_row.setContentsMargins(0, 0, 0, 0)
        top_row.setSpacing(scale_px(18, self._ui_scale))

        hero_wrap = QFrame()
        hero_wrap.setObjectName("heroWrap")
        hero_wrap.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        hero_wrap.setMinimumSize(scale_px(236, self._ui_scale), scale_px(178, self._ui_scale))
        hero_layout = QVBoxLayout(hero_wrap)
        hero_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(10, self._ui_scale),
        )
        self._scan_student_hero = StudentPortraitWidget(self._student_card_asset)
        self._scan_student_hero.setObjectName("hero")
        self._scan_student_hero.setMinimumSize(scale_px(220, self._ui_scale), scale_px(164, self._ui_scale))
        self._scan_student_hero.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        hero_layout.addWidget(self._scan_student_hero)
        top_row.addWidget(hero_wrap, 5)

        top_panel = QFrame()
        top_panel.setObjectName("scanStudentMetaPanel")
        top_panel.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        top_panel.setMinimumWidth(scale_px(250, self._ui_scale))
        top_layout = QVBoxLayout(top_panel)
        top_layout.setContentsMargins(
            scale_px(10, self._ui_scale),
            scale_px(8, self._ui_scale),
            scale_px(10, self._ui_scale),
            scale_px(8, self._ui_scale),
        )
        top_layout.setSpacing(scale_px(8, self._ui_scale))

        self._scan_student_progress_strip = ScanLiveProgressStrip()
        top_layout.addWidget(self._scan_student_progress_strip)

        stat_row = QHBoxLayout()
        stat_row.setContentsMargins(0, 0, 0, 0)
        stat_row.setSpacing(scale_px(8, self._ui_scale))

        level_card = ParallelogramPanel(fill=_mix_hex(PALETTE_SOFT, SURFACE_ALT, 0.52), border=PALETTE_SOFT, slant=DETAIL_SLANT)
        level_card.setMinimumHeight(scale_px(108, self._ui_scale))
        level_layout = QVBoxLayout(level_card)
        level_layout.setContentsMargins(scale_px(14, self._ui_scale), scale_px(12, self._ui_scale), scale_px(14, self._ui_scale), scale_px(12, self._ui_scale))
        level_layout.setSpacing(scale_px(4, self._ui_scale))
        level_title = QLabel("LEVEL")
        level_title.setObjectName("detailSectionTitle")
        level_title.setAlignment(Qt.AlignCenter)
        level_value = QLabel("-")
        level_value.setObjectName("detailBigValue")
        level_value.setAlignment(Qt.AlignCenter)
        self._scan_student_value_labels["level"] = level_value
        level_layout.addWidget(level_title)
        level_layout.addStretch(1)
        level_layout.addWidget(level_value)
        level_layout.addStretch(1)
        stat_row.addWidget(level_card, 3)

        side_cards = QVBoxLayout()
        side_cards.setContentsMargins(0, 0, 0, 0)
        side_cards.setSpacing(scale_px(6, self._ui_scale))
        self._scan_student_position_label = QLabel("-")
        self._scan_student_class_label = QLabel("-")
        self._scan_student_weapon_level_label = QLabel("-")
        for value_label, compact_text in (
            (self._scan_student_position_label, True),
            (self._scan_student_class_label, True),
            (self._scan_student_weapon_level_label, "weapon"),
        ):
            mini_card = ParallelogramPanel(fill=_mix_hex(PALETTE_PANEL, PALETTE_SOFT, 0.16), border=PALETTE_SOFT, slant=DETAIL_SLANT)
            mini_card.setMinimumHeight(scale_px(30, self._ui_scale))
            mini_layout = QVBoxLayout(mini_card)
            mini_layout.setContentsMargins(scale_px(10, self._ui_scale), scale_px(4, self._ui_scale), scale_px(10, self._ui_scale), scale_px(4, self._ui_scale))
            value_label.setObjectName("scanLiveWeaponValue" if compact_text == "weapon" else "scanLiveMiniValue")
            value_label.setAlignment(Qt.AlignCenter)
            mini_layout.addWidget(value_label, 1)
            side_cards.addWidget(mini_card)
        stat_row.addLayout(side_cards, 2)
        top_layout.addLayout(stat_row)

        self._scan_student_value_labels["stats"] = QLabel("-")
        self._scan_student_value_labels["stats"].setObjectName("detailMetaLine")
        self._scan_student_value_labels["stats"].setAlignment(Qt.AlignCenter)
        self._scan_student_value_labels["stats"].setTextFormat(Qt.RichText)
        top_layout.addWidget(self._scan_student_value_labels["stats"])
        top_row.addWidget(top_panel, 4)
        capture_layout.addLayout(top_row, 3)

        bottom_row = QHBoxLayout()
        bottom_row.setContentsMargins(0, 0, 0, 0)
        bottom_row.setSpacing(scale_px(18, self._ui_scale))

        skill_equip_layout = QVBoxLayout()
        skill_equip_layout.setContentsMargins(0, 0, 0, 0)
        skill_equip_layout.setSpacing(scale_px(10, self._ui_scale))

        skill_row = QHBoxLayout()
        skill_row.setContentsMargins(0, 0, 0, 0)
        skill_row.setSpacing(scale_px(8, self._ui_scale))
        for key, caption in (("skill_ex", "EX"), ("skill_s1", "N"), ("skill_s2", "P"), ("skill_s3", "S")):
            skill_card = ParallelogramPanel(fill=_mix_hex(PALETTE_PANEL, PALETTE_ACCENT, 0.14), border=PALETTE_SOFT, slant=DETAIL_SLANT)
            skill_card.setMinimumHeight(scale_px(76, self._ui_scale))
            skill_layout = QVBoxLayout(skill_card)
            skill_layout.setContentsMargins(scale_px(10, self._ui_scale), scale_px(7, self._ui_scale), scale_px(10, self._ui_scale), scale_px(7, self._ui_scale))
            skill_layout.setSpacing(scale_px(3, self._ui_scale))
            caption_label = QLabel(caption)
            caption_label.setObjectName("detailSkillLabel")
            caption_label.setAlignment(Qt.AlignCenter)
            value_label = QLabel("-")
            value_label.setObjectName("detailSkillValue")
            value_label.setAlignment(Qt.AlignCenter)
            value_label.setWordWrap(True)
            self._scan_student_value_labels[key] = value_label
            skill_layout.addStretch(1)
            skill_layout.addWidget(caption_label)
            skill_layout.addWidget(value_label)
            skill_layout.addStretch(1)
            skill_row.addWidget(skill_card, 1)
        skill_equip_layout.addLayout(skill_row, 1)

        equip_row = QHBoxLayout()
        equip_row.setContentsMargins(0, 0, 0, 0)
        equip_row.setSpacing(scale_px(8, self._ui_scale))
        for key in ("equip1", "equip2", "equip3", "favorite"):
            equip_card = EquipmentDetailCard(
                self._ui_scale,
                fill=_mix_hex(PALETTE_PANEL_ALT, PALETTE_SOFT, 0.18),
                border=PALETTE_SOFT,
                slant=DETAIL_SLANT,
            )
            equip_card.setMinimumHeight(scale_px(94, self._ui_scale))
            equip_row.addWidget(equip_card, 1)
            self._scan_student_equip_cards[key] = equip_card
        skill_equip_layout.addLayout(equip_row, 1)
        bottom_row.addLayout(skill_equip_layout, 10)

        stats_panel = QFrame()
        stats_panel.setObjectName("scanStudentMetaPanel")
        stats_panel.setSizePolicy(QSizePolicy.Fixed, QSizePolicy.Expanding)
        stats_panel.setMinimumWidth(scale_px(126, self._ui_scale))
        stats_panel.setMaximumWidth(scale_px(154, self._ui_scale))
        stats_layout = QVBoxLayout(stats_panel)
        stats_layout.setContentsMargins(scale_px(8, self._ui_scale), scale_px(8, self._ui_scale), scale_px(8, self._ui_scale), scale_px(8, self._ui_scale))
        self._scan_student_combat_stats_label = QLabel("-")
        self._scan_student_combat_stats_label.setObjectName("detailMetaLine")
        self._scan_student_combat_stats_label.setAlignment(Qt.AlignCenter | Qt.AlignVCenter)
        self._scan_student_combat_stats_label.setTextFormat(Qt.RichText)
        self._scan_student_combat_stats_label.setMinimumHeight(scale_px(112, self._ui_scale))
        self._scan_student_combat_stats_label.setWordWrap(False)
        stats_layout.addWidget(self._scan_student_combat_stats_label, 1)
        bottom_row.addWidget(stats_panel, 0)
        capture_layout.addLayout(bottom_row, 2)

        self._scan_student_name_label = QLabel("")
        self._scan_student_meta_label = QLabel("")
        self._scan_student_name_label.setVisible(False)
        self._scan_student_meta_label.setVisible(False)

        self._scan_student_card = card
        self._render_scan_live_card()
        return card
    def _build_scan_inventory_grid_card(self) -> QFrame:
        card = QFrame()
        card.setObjectName("scanInventoryCard")
        card.setMinimumWidth(scale_px(560, self._ui_scale))
        card.setMinimumHeight(scale_px(410, self._ui_scale))
        card.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        layout = QVBoxLayout(card)
        layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        layout.setSpacing(scale_px(12, self._ui_scale))

        header_row = QHBoxLayout()
        header_row.setContentsMargins(0, 0, 0, 0)
        header_row.setSpacing(scale_px(12, self._ui_scale))
        self._scan_inventory_title_label = QLabel("인벤토리 그리드")
        self._scan_inventory_title_label.setObjectName("detailInlineName")
        self._scan_inventory_title_label.setWordWrap(True)
        header_row.addWidget(self._scan_inventory_title_label, 1)

        self._scan_inventory_meta_label = QLabel("스캔 대기 중")
        self._scan_inventory_meta_label.setObjectName("detailInlineSub")
        self._scan_inventory_meta_label.setWordWrap(True)
        self._scan_inventory_meta_label.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        header_row.addWidget(self._scan_inventory_meta_label, 2)
        layout.addLayout(header_row)

        grid_host = QFrame()
        grid_host.setObjectName("scanInventoryGridHost")
        grid_host.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        grid = QGridLayout(grid_host)
        grid.setContentsMargins(0, 0, 0, 0)
        grid.setSpacing(scale_px(8, self._ui_scale))
        self._scan_inventory_grid_layout = grid
        self._scan_inventory_grid_cells = []
        self._scan_inventory_grid_cols = 5
        self._scan_inventory_grid_rows = 4
        self._scan_inventory_visible_slots = 20
        icon_min_size = scale_px(54, self._ui_scale)
        cell_min_size = scale_px(68, self._ui_scale)
        for index in range(25):
            cell = QFrame()
            cell.setObjectName("scanInventorySlot")
            cell.setMinimumSize(cell_min_size, cell_min_size)
            cell.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
            cell_layout = QVBoxLayout(cell)
            cell_layout.setContentsMargins(
                scale_px(5, self._ui_scale),
                scale_px(5, self._ui_scale),
                scale_px(5, self._ui_scale),
                scale_px(5, self._ui_scale),
            )
            cell_layout.setSpacing(scale_px(2, self._ui_scale))
            icon_label = QLabel()
            icon_label.setObjectName("scanInventorySlotImage")
            icon_label.setMinimumSize(icon_min_size, icon_min_size)
            icon_label.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
            icon_label.setAlignment(Qt.AlignCenter)
            cell_layout.addWidget(icon_label, 1)
            quantity_label = QLabel("")
            quantity_label.setObjectName("scanInventorySlotQuantity")
            quantity_label.setAlignment(Qt.AlignCenter)
            quantity_label.setMinimumHeight(scale_px(18, self._ui_scale))
            quantity_label.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
            cell_layout.addWidget(quantity_label, 0)
            grid.addWidget(cell, index // self._scan_inventory_grid_cols, index % self._scan_inventory_grid_cols)
            self._scan_inventory_grid_cells.append({
                "frame": cell,
                "image": icon_label,
                "quantity_label": quantity_label,
                "slot": index + 1,
                "tier": None,
            })
        layout.addWidget(grid_host, 1)
        self._scan_inventory_card = card
        self._configure_scan_inventory_grid(5, 4)
        return card
    def _set_scan_detail_mode(self, mode: str) -> None:
        stack = self._scan_detail_stack
        if stack is None:
            return
        if mode == "inventory" and self._scan_inventory_card is not None:
            stack.setCurrentWidget(self._scan_inventory_card)
        elif self._scan_student_card is not None:
            stack.setCurrentWidget(self._scan_student_card)
    def _configure_scan_inventory_grid(self, grid_cols: object = None, grid_rows: object = None) -> None:
        try:
            cols = int(grid_cols)
        except (TypeError, ValueError):
            cols = 5
        try:
            rows = int(grid_rows)
        except (TypeError, ValueError):
            rows = 4
        cols = max(1, min(5, cols))
        rows = max(1, min(5, rows))
        self._scan_inventory_grid_cols = cols
        self._scan_inventory_grid_rows = rows
        self._scan_inventory_visible_slots = min(len(self._scan_inventory_grid_cells), cols * rows)
        grid = self._scan_inventory_grid_layout
        if grid is not None:
            for column in range(5):
                grid.setColumnStretch(column, 1 if column < cols else 0)
                grid.setColumnMinimumWidth(column, 0)
            for row in range(5):
                grid.setRowStretch(row, 1 if row < rows else 0)
                grid.setRowMinimumHeight(row, 0)
            for index, cell in enumerate(self._scan_inventory_grid_cells):
                frame = cell.get("frame")
                if isinstance(frame, QFrame):
                    grid.removeWidget(frame)
                    grid.addWidget(frame, index // cols, index % cols)
        self._reset_scan_inventory_grid_cells()
        self._reflow_scan_inventory_grid()
    def _reflow_scan_inventory_grid(self) -> None:
        grid = self._scan_inventory_grid_layout
        if grid is None:
            return
        cols = max(1, int(getattr(self, "_scan_inventory_grid_cols", 5) or 5))
        visible_slots = int(getattr(self, "_scan_inventory_visible_slots", 20) or 20)
        cells = list(getattr(self, "_scan_inventory_grid_cells", []))
        visible_cells = [
            (index, cell)
            for index, cell in enumerate(cells[:visible_slots])
        ]
        for index, cell in visible_cells:
            frame = cell.get("frame")
            if isinstance(frame, QFrame):
                grid.removeWidget(frame)
                grid.addWidget(frame, index // cols, index % cols)
                frame.setVisible(True)
        for index, cell in enumerate(cells[visible_slots:], start=visible_slots):
            frame = cell.get("frame")
            if isinstance(frame, QFrame):
                grid.removeWidget(frame)
                grid.addWidget(frame, index // cols, index % cols)
                frame.setVisible(False)
    def _inventory_slot_color(self, tier: object = None, confirmed: bool = False) -> str:
        if confirmed:
            return "#DDF7EC"
        try:
            tier_number = int(tier)
        except (TypeError, ValueError):
            tier_number = -1
        return {
            0: "#F7FAFC",
            1: "#D8ECFF",
            2: "#FFF0B8",
            3: "#EBCBFF",
        }.get(tier_number, "#EEF4F8")
    def _style_scan_inventory_cell(
        self,
        cell: dict[str, object],
        *,
        tier: object = None,
        confirmed: bool = False,
        anchor: bool = False,
        scan_target: bool = False,
    ) -> None:
        frame = cell.get("frame")
        if not isinstance(frame, QFrame):
            return
        if anchor and confirmed:
            bg = "rgba(255, 194, 87, 0.18)"
            border = "#FFC247"
        elif confirmed:
            bg = "rgba(65, 184, 131, 0.12)"
            border = "#41B883"
        elif anchor:
            bg = "rgba(255, 194, 87, 0.10)"
            border = "#F5B944"
        elif scan_target:
            bg = "rgba(92, 205, 255, 0.08)"
            border = "#5CCDFF"
        else:
            bg = "rgba(255, 255, 255, 0.04)"
            border = "#9EB6C8"
        frame.setStyleSheet(
            f"QFrame#scanInventorySlot {{ background: {bg}; border: 1px solid {border}; border-radius: 6px; }} "
            "QLabel { background: transparent; }"
        )
    def _empty_scan_inventory_state(self, slot_number: int) -> dict[str, object]:
        return {
            "slot": slot_number,
            "tier": None,
            "confirmed": False,
            "anchor": False,
            "scan_target": False,
            "item_name": "",
            "quantity": "",
            "item_id": None,
        }
    def _scan_inventory_cell_state(self, cell: dict[str, object]) -> dict[str, object]:
        return {
            "tier": cell.get("tier"),
            "confirmed": bool(cell.get("confirmed")),
            "anchor": bool(cell.get("anchor")),
            "scan_target": bool(cell.get("scan_target")),
            "item_name": str(cell.get("item_name") or ""),
            "quantity": str(cell.get("quantity") or ""),
            "item_id": cell.get("item_id"),
        }
    def _render_scan_inventory_cell(self, cell: dict[str, object], slot_number: int) -> None:
        image_label = cell.get("image")
        quantity_label = cell.get("quantity_label")
        tier = cell.get("tier")
        confirmed = bool(cell.get("confirmed"))
        anchor = bool(cell.get("anchor"))
        scan_target = bool(cell.get("scan_target"))
        item_name = str(cell.get("item_name") or "")
        quantity = str(cell.get("quantity") or "")
        item_id = cell.get("item_id")
        tooltip = f"{slot_number}\uBC88 \uC2AC\uB86F"
        if confirmed and item_name:
            tooltip = f"{item_name} x{quantity}" if quantity else item_name
        if anchor:
            tooltip = f"\uC575\uCEE4 / {tooltip}"
        if scan_target and not confirmed:
            tooltip = f"\uB2E4\uC74C \uC2A4\uCE94 / {tooltip}"
        if isinstance(image_label, QLabel):
            label_size = image_label.size()
            icon_side = max(
                scale_px(54, self._ui_scale),
                min(label_size.width(), label_size.height(), scale_px(86, self._ui_scale)),
            )
            image_label.setPixmap(
                _scan_inventory_slot_pixmap(
                    size=QSize(icon_side, icon_side),
                    item_id=str(item_id) if item_id else None,
                    item_name=item_name,
                    quantity=None,
                    tier=tier,
                    slot_number=None,
                )
            )
            image_label.setToolTip(tooltip)
        if isinstance(quantity_label, QLabel):
            quantity_text = str(quantity or "").strip()
            display_quantity = f"x{quantity_text}" if quantity_text else ""
            font_px = scale_px(15, self._ui_scale)
            if (display_quantity.startswith("x") and len(display_quantity) > 6) or (display_quantity and not display_quantity.startswith("x") and len(display_quantity) >= 6):
                font_px = scale_px(13, self._ui_scale)
            quantity_label.setText(display_quantity)
            quantity_label.setVisible(bool(display_quantity))
            quantity_label.setStyleSheet(
                f"background: transparent; color: #f7fbff; font-size: {font_px}px; font-weight: 900;"
            )
            quantity_label.setToolTip(tooltip)
        frame = cell.get("frame")
        if isinstance(frame, QFrame):
            frame.setVisible(slot_number <= getattr(self, "_scan_inventory_visible_slots", 20))
            frame.setToolTip(tooltip)
        self._style_scan_inventory_cell(
            cell,
            tier=tier,
            confirmed=confirmed,
            anchor=anchor,
            scan_target=scan_target,
        )
    def _apply_scan_inventory_cell_state(
        self,
        cell: dict[str, object],
        slot_number: int,
        state: dict[str, object] | None = None,
    ) -> None:
        next_state = self._empty_scan_inventory_state(slot_number)
        if state:
            for key in ("tier", "confirmed", "anchor", "scan_target", "item_name", "quantity", "item_id"):
                next_state[key] = state.get(key, next_state.get(key))
        cell.update(next_state)
        self._render_scan_inventory_cell(cell, slot_number)
    def _reset_scan_inventory_grid_cells(self) -> None:
        visible_slots = int(getattr(self, "_scan_inventory_visible_slots", 20) or 20)
        for index, cell in enumerate(getattr(self, "_scan_inventory_grid_cells", [])):
            slot_number = index + 1
            frame = cell.get("frame")
            if isinstance(frame, QFrame):
                frame.setVisible(index < visible_slots)
            self._apply_scan_inventory_cell_state(cell, slot_number)
    def _scan_inventory_cell(self, slot_number: object) -> dict[str, object] | None:
        try:
            index = int(slot_number) - 1
        except (TypeError, ValueError):
            return None
        cells = getattr(self, "_scan_inventory_grid_cells", [])
        if index < 0 or index >= len(cells) or index >= getattr(self, "_scan_inventory_visible_slots", len(cells)):
            return None
        return cells[index]
    def _set_scan_inventory_cell_tier(self, slot_number: object, tier: object) -> None:
        cell = self._scan_inventory_cell(slot_number)
        if cell is None:
            return
        cell["tier"] = tier
        self._render_scan_inventory_cell(cell, int(slot_number))
    def _mark_scan_inventory_cell_anchor(self, slot_number: object) -> None:
        cell = self._scan_inventory_cell(slot_number)
        if cell is None:
            return
        cell["anchor"] = True
        try:
            slot_index = int(slot_number)
        except (TypeError, ValueError):
            slot_index = 1
        self._render_scan_inventory_cell(cell, slot_index)
        self._reflow_scan_inventory_grid()
    def _set_scan_inventory_cell_confirmed(
        self,
        slot_number: object,
        item_name: str,
        quantity: str,
        item_id: str | None = None,
        *,
        row_anchor: bool = False,
    ) -> None:
        cell = self._scan_inventory_cell(slot_number)
        if cell is None:
            return
        try:
            slot_index = int(slot_number)
        except (TypeError, ValueError):
            slot_index = 1
        cell["confirmed"] = True
        cell["scan_target"] = False
        cell["item_name"] = item_name
        cell["quantity"] = quantity
        cell["item_id"] = item_id
        if row_anchor:
            cell["anchor"] = True
        self._render_scan_inventory_cell(cell, slot_index)
        self._reflow_scan_inventory_grid()
    def _apply_scan_inventory_scroll_feedback(
        self,
        moved_rows: object = None,
        overlap_rows: object = None,
        scan_slots: object = None,
    ) -> None:
        visible_slots = int(getattr(self, "_scan_inventory_visible_slots", 20) or 20)
        cols = max(1, int(getattr(self, "_scan_inventory_grid_cols", 5) or 5))
        rows = max(1, int(getattr(self, "_scan_inventory_grid_rows", 4) or 4))
        try:
            moved = int(moved_rows)
        except (TypeError, ValueError):
            try:
                moved = rows - int(overlap_rows)
            except (TypeError, ValueError):
                moved = rows
        moved = max(0, min(rows, moved))
        shift = moved * cols
        cells = list(getattr(self, "_scan_inventory_grid_cells", []))
        old_states = [self._scan_inventory_cell_state(cell) for cell in cells[:visible_slots]]
        new_states = [self._empty_scan_inventory_state(index + 1) for index in range(visible_slots)]
        if 0 < shift < visible_slots:
            for src_index in range(shift, visible_slots):
                dst_index = src_index - shift
                carried = dict(old_states[src_index])
                carried["scan_target"] = False
                new_states[dst_index].update(carried)
        elif shift == 0:
            for index in range(visible_slots):
                carried = dict(old_states[index])
                carried["scan_target"] = False
                new_states[index].update(carried)
        target_indices: set[int] = set()
        if isinstance(scan_slots, (list, tuple, set)):
            for raw in scan_slots:
                try:
                    value = int(raw)
                except (TypeError, ValueError):
                    continue
                if 0 <= value < visible_slots:
                    target_indices.add(value)
                elif 1 <= value <= visible_slots:
                    target_indices.add(value - 1)
        if not target_indices and shift > 0:
            target_indices = set(range(max(0, visible_slots - shift), visible_slots))
        for index in target_indices:
            if 0 <= index < visible_slots:
                new_states[index]["scan_target"] = True
        for index, cell in enumerate(cells):
            slot_number = index + 1
            if index < visible_slots:
                self._apply_scan_inventory_cell_state(cell, slot_number, new_states[index])
            else:
                frame = cell.get("frame")
                if isinstance(frame, QFrame):
                    frame.setVisible(False)
        self._reflow_scan_inventory_grid()
        self._animate_scan_inventory_scroll(moved)
    def _animate_scan_inventory_scroll(self, moved_rows: int) -> None:
        if moved_rows <= 0:
            return
        visible_slots = int(getattr(self, "_scan_inventory_visible_slots", 20) or 20)
        cols = max(1, int(getattr(self, "_scan_inventory_grid_cols", 5) or 5))
        rows = max(1, int(getattr(self, "_scan_inventory_grid_rows", 4) or 4))
        cells = list(getattr(self, "_scan_inventory_grid_cells", []))[:visible_slots]
        frames = [cell.get("frame") for cell in cells]
        frames = [frame for frame in frames if isinstance(frame, QFrame) and frame.isVisible()]
        if not frames:
            return
        row_step = 0
        if len(frames) > cols:
            row_step = abs(frames[cols].pos().y() - frames[0].pos().y())
        if row_step <= 0:
            spacing = 0
            grid = self._scan_inventory_grid_layout
            if grid is not None:
                spacing = max(0, grid.spacing())
            row_step = frames[0].height() + spacing
        offset = max(1, min(rows, int(moved_rows))) * max(1, row_step)
        previous = getattr(self, "_scan_inventory_scroll_animation", None)
        if previous is not None:
            previous.stop()
        group = QParallelAnimationGroup(self)
        duration = max(150, min(360, 170 + int(moved_rows) * 35))
        for frame in frames:
            end_pos = frame.pos()
            start_pos = end_pos + QPoint(0, offset)
            frame.move(start_pos)
            animation = QPropertyAnimation(frame, b"pos", group)
            animation.setDuration(duration)
            animation.setStartValue(start_pos)
            animation.setEndValue(end_pos)
            animation.setEasingCurve(QEasingCurve.OutCubic)
            group.addAnimation(animation)
        self._scan_inventory_scroll_animation = group
        group.finished.connect(lambda: setattr(self, "_scan_inventory_scroll_animation", None))
        group.start()
    def _build_scan_tab(self, root: QWidget) -> None:
        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, scale_px(12, self._ui_scale))
        layout.setSpacing(scale_px(12, self._ui_scale))

        header = QFrame()
        header.setObjectName("scanHeader")
        header.setProperty("connected", False)
        self._scan_header = header
        header_layout = QVBoxLayout(header)
        header_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        header_layout.setSpacing(scale_px(6, self._ui_scale))
        title = QLabel("스캔")
        title.setObjectName("title")
        header_layout.addWidget(title)
        self._scan_profile_label = QLabel()
        self._scan_profile_label.setObjectName("scanProfile")
        header_layout.addWidget(self._scan_profile_label)
        self._scan_target_label = QLabel()
        self._scan_target_label.setObjectName("count")
        self._scan_target_label.setWordWrap(True)
        header_layout.addWidget(self._scan_target_label)

        scan_actions = QHBoxLayout()
        scan_actions.setSpacing(scale_px(6, self._ui_scale))
        for label, mode in (
            ("학생", "students"),
            ("현재 학생", "student_current"),
            ("자원", "resources"),
            ("아이템", "items"),
            ("장비", "equipment"),
        ):
            button = QPushButton(label)
            button.clicked.connect(lambda _checked=False, scan_mode=mode: self._launch_scanner(scan_mode))
            scan_actions.addWidget(button)
        scan_actions.addStretch(1)

        self._scan_aspect_warning_label = QLabel("")
        self._scan_aspect_warning_label.setObjectName("count")
        self._scan_aspect_warning_label.setWordWrap(True)
        self._scan_aspect_warning_label.setSizePolicy(QSizePolicy.Ignored, QSizePolicy.Fixed)
        scan_actions.addWidget(self._scan_aspect_warning_label, 1, Qt.AlignVCenter)
        header_layout.addLayout(scan_actions)
        layout.addWidget(header)

        body = QGridLayout()
        body.setSpacing(scale_px(12, self._ui_scale))
        layout.addLayout(body, 1)

        summary_panel = QFrame()
        summary_panel.setObjectName("panel")
        summary_layout = QVBoxLayout(summary_panel)
        summary_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        summary_layout.setSpacing(scale_px(10, self._ui_scale))

        self._scan_plana_message_label = QLabel("접속 확인. 선생님, 기다리고 있었습니다.")
        self._scan_plana_message_label.setObjectName("title")
        self._scan_plana_message_label.setWordWrap(True)
        self._scan_plana_message_label.setMinimumHeight(scale_px(78, self._ui_scale))
        self._scan_plana_message_label.setAlignment(Qt.AlignTop | Qt.AlignLeft)
        summary_layout.addWidget(self._scan_plana_message_label)

        self._scan_plana_meta_label = QLabel("학생부 정리 대기 중")
        self._scan_plana_meta_label.setObjectName("count")
        self._scan_plana_meta_label.setWordWrap(True)
        summary_layout.addWidget(self._scan_plana_meta_label)

        self._scan_plana_log = QPlainTextEdit()
        self._scan_plana_log.setReadOnly(True)
        self._scan_plana_log.setPlaceholderText("학생 스캔을 실행하면 프라나의 업무 보고가 표시됩니다.")
        self._scan_plana_log.setMinimumHeight(scale_px(150, self._ui_scale))
        summary_layout.addWidget(self._scan_plana_log, 1)
        body.addWidget(summary_panel, 0, 0)

        right_column = QWidget()
        right_column.setObjectName("planTransparent")
        right_column.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        right_column_layout = QVBoxLayout(right_column)
        right_column_layout.setContentsMargins(0, 0, 0, 0)
        right_column_layout.setSpacing(scale_px(12, self._ui_scale))
        body.addWidget(right_column, 0, 1, 2, 1)
        panel = QFrame()
        panel.setObjectName("panel")
        panel.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        panel_layout = QVBoxLayout(panel)
        panel_layout.setContentsMargins(
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
            scale_px(14, self._ui_scale),
        )
        panel_layout.setSpacing(scale_px(8, self._ui_scale))

        controls_row = QHBoxLayout()
        controls_row.setContentsMargins(0, 0, 0, 0)
        controls_row.setSpacing(scale_px(8, self._ui_scale))

        progress_panel = QFrame()
        progress_panel.setObjectName("inventoryPressureRow")
        progress_panel.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        progress_layout = QHBoxLayout(progress_panel)
        progress_layout.setContentsMargins(
            scale_px(8, self._ui_scale),
            scale_px(4, self._ui_scale),
            scale_px(8, self._ui_scale),
            scale_px(4, self._ui_scale),
        )
        progress_layout.setSpacing(scale_px(6, self._ui_scale))

        self._scan_progress_bar = QProgressBar()
        self._scan_progress_bar.setRange(0, 100)
        self._scan_progress_bar.setValue(0)
        self._scan_progress_bar.setTextVisible(False)
        self._scan_progress_bar.setMinimumWidth(scale_px(120, self._ui_scale))
        self._scan_progress_bar.setMaximumWidth(scale_px(320, self._ui_scale))
        self._scan_progress_bar.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        progress_layout.addWidget(self._scan_progress_bar, 1)

        self._scan_progress_label = None
        self._scan_eta_label = None
        self._scan_status_label = self._scan_plana_meta_label
        controls_row.addWidget(progress_panel, 1)

        self._scan_stop_button = QPushButton("스캔 중지")
        self._scan_stop_button.setEnabled(False)
        self._scan_stop_button.clicked.connect(self._request_scanner_stop)
        controls_row.addWidget(self._scan_stop_button, 0, Qt.AlignVCenter)
        panel_layout.addLayout(controls_row)
        right_column_layout.addWidget(panel, 0)


        self._scan_plana_image_label = None
        self._scan_detail_stack = QStackedWidget()
        self._scan_detail_stack.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        self._scan_detail_stack.addWidget(self._build_scan_student_card())
        self._scan_detail_stack.addWidget(self._build_scan_inventory_grid_card())
        body.addWidget(self._scan_detail_stack, 1, 0)

        preview_min_width = scale_px(560, self._ui_scale)
        preview_panel = AspectRatioFrame(aspect_width=16, aspect_height=9, min_width=preview_min_width)
        preview_panel.setObjectName("scanPreviewPanel")
        preview_panel.setMinimumSize(preview_min_width, preview_panel.heightForWidth(preview_min_width))
        preview_layout = QVBoxLayout(preview_panel)
        preview_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        preview_layout.addStretch(1)
        right_column_layout.addWidget(preview_panel, 1)

        body.setColumnStretch(0, 1)
        body.setColumnStretch(1, 2)
        body.setRowStretch(0, 0)
        body.setRowStretch(1, 1)
        self._set_plana_expression("neutral")
        self._reset_scan_student_card()
        self._sync_settings_labels()
    def _build_settings_tab(self, root: QWidget) -> None:
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
        title = QLabel("설정")
        title.setObjectName("title")
        header_layout.addWidget(title)
        self._settings_active_profile_label = QLabel()
        self._settings_active_profile_label.setObjectName("count")
        header_layout.addWidget(self._settings_active_profile_label)
        self._settings_target_label = QLabel()
        self._settings_target_label.setObjectName("count")
        self._settings_target_label.setWordWrap(True)
        header_layout.addWidget(self._settings_target_label)
        layout.addWidget(header)

        profile_panel = QFrame()
        profile_panel.setObjectName("panel")
        profile_layout = QVBoxLayout(profile_panel)
        profile_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        profile_layout.setSpacing(scale_px(10, self._ui_scale))
        profile_title = QLabel("계정 관리")
        profile_title.setObjectName("sectionTitle")
        profile_layout.addWidget(profile_title)
        self._settings_profile_combo = QComboBox()
        profile_layout.addWidget(self._settings_profile_combo)
        profile_buttons = QHBoxLayout()
        apply_profile = QPushButton("프로필 적용")
        apply_profile.clicked.connect(self._apply_selected_profile)
        profile_buttons.addWidget(apply_profile)
        new_profile = QPushButton("새 프로필")
        new_profile.clicked.connect(self._create_profile)
        profile_buttons.addWidget(new_profile)
        refresh_profile = QPushButton("새로고침")
        refresh_profile.clicked.connect(self._refresh_settings_profiles)
        profile_buttons.addWidget(refresh_profile)
        profile_buttons.addStretch(1)
        profile_layout.addLayout(profile_buttons)

        delete_data_button = QPushButton("현재 프로필 데이터 삭제")
        delete_data_button.clicked.connect(self._confirm_delete_current_profile_data)
        profile_layout.addWidget(delete_data_button)
        layout.addWidget(profile_panel)

        window_panel = QFrame()
        window_panel.setObjectName("panel")
        window_layout = QVBoxLayout(window_panel)
        window_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        window_layout.setSpacing(scale_px(10, self._ui_scale))
        window_title = QLabel("블루아카이브 창 인식")
        window_title.setObjectName("sectionTitle")
        window_layout.addWidget(window_title)
        window_buttons = QHBoxLayout()
        refresh_windows = QPushButton("창 목록 열기")
        refresh_windows.clicked.connect(self._open_window_picker_dialog)
        window_buttons.addWidget(refresh_windows)
        window_buttons.addStretch(1)
        window_layout.addLayout(window_buttons)
        layout.addWidget(window_panel)

        report_panel = QFrame()
        report_panel.setObjectName("panel")
        report_layout = QVBoxLayout(report_panel)
        report_layout.setContentsMargins(
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
            scale_px(18, self._ui_scale),
        )
        report_layout.setSpacing(scale_px(10, self._ui_scale))
        report_title = QLabel("지원")
        report_title.setObjectName("sectionTitle")
        report_layout.addWidget(report_title)
        report_description = QLabel("문제가 발생했다면 설명과 진단정보를 작성해 신고할 수 있습니다.")
        report_description.setObjectName("count")
        report_description.setWordWrap(True)
        report_layout.addWidget(report_description)
        report_button_row = QHBoxLayout()
        report_button = QPushButton("문제 신고")
        report_button.clicked.connect(self._open_bug_report_dialog)
        report_button_row.addWidget(report_button)
        report_button_row.addStretch(1)
        report_layout.addLayout(report_button_row)
        layout.addWidget(report_panel)
        layout.addStretch(1)

        self._refresh_settings_profiles()
        self._sync_settings_labels()
    def _open_bug_report_dialog(self) -> None:
        dialog = BugReportDialog(
            profile_name=get_active_profile_name("Default"),
            parent=self,
        )
        dialog.exec()
    def _saved_target(self) -> tuple[int, str]:
        config = load_config()
        try:
            hwnd = int(config.get("target_hwnd") or 0)
        except (TypeError, ValueError):
            hwnd = 0
        return hwnd, str(config.get("target_title") or "")
    def _load_saved_target_into_capture(self) -> bool:
        hwnd, title = self._saved_target()
        if not hwnd:
            return False
        set_target_window(hwnd, title)
        return True
    def _sync_settings_labels(self) -> None:
        profile = get_active_profile_name("Default") or "Default"
        hwnd, title = self._saved_target()
        settings_target = f"{title} (HWND={hwnd})" if hwnd else "선택된 창 없음"
        scan_target = title if hwnd else "선택된 창 없음"
        target_connected = False
        if hwnd:
            try:
                target_connected = any(int(window.get("hwnd") or 0) == hwnd for window in get_all_windows())
            except Exception:
                target_connected = True
        aspect_warning = self._target_aspect_warning(hwnd)
        if self._settings_active_profile_label is not None:
            self._settings_active_profile_label.setText(f"현재 프로필: {profile}")
        if self._settings_target_label is not None:
            self._settings_target_label.setText(f"선택된 BA 창: {settings_target}")
        if self._scan_profile_label is not None:
            self._scan_profile_label.setText(f"현재 프로필: {profile}")
        if self._scan_target_label is not None:
            self._scan_target_label.setText(f"선택된 BA 창: {scan_target}")
        if self._scan_header is not None:
            if self._scan_header.property("connected") != target_connected:
                self._scan_header.setProperty("connected", target_connected)
                self._scan_header.style().unpolish(self._scan_header)
                self._scan_header.style().polish(self._scan_header)
                self._scan_header.update()
        if self._scan_aspect_warning_label is not None:
            self._scan_aspect_warning_label.setText(aspect_warning)
    def _target_aspect_warning(self, hwnd: int) -> str:
        if not hwnd:
            return ""
        size = ""
        try:
            for window in get_all_windows():
                if int(window.get("hwnd") or 0) == hwnd:
                    size = str(window.get("size") or "")
                    break
        except Exception:
            return ""
        match = re.search(r"(\d+)\s*[×x]\s*(\d+)", size)
        if not match:
            return ""
        width = int(match.group(1))
        height = int(match.group(2))
        if width <= 0 or height <= 0:
            return ""
        ratio = width / height
        target_ratio = 16 / 9
        if abs(ratio - target_ratio) <= 0.02:
            return f"BA 창 비율 확인: {width}x{height} (16:9)"
        return (
            f"BA 창 비율 확인 필요: 현재 {width}x{height}입니다. "
            "학생 스캔 전 블루 아카이브를 16:9 창모드로 맞춰 주십시오."
        )
    def _refresh_settings_profiles(self) -> None:
        if self._settings_profile_combo is None:
            return
        active = get_active_profile_name("Default") or "Default"
        profiles = list_profiles()
        if active not in profiles:
            profiles.insert(0, active)
        self._settings_profile_combo.clear()
        self._settings_profile_combo.addItems(profiles)
        index = self._settings_profile_combo.findText(active)
        if index >= 0:
            self._settings_profile_combo.setCurrentIndex(index)
        self._sync_settings_labels()
    def _open_window_picker_dialog(self) -> None:
        dialog = QDialog(self)
        dialog.setWindowTitle("Blue Archive 창 선택")
        dialog.setModal(True)
        dialog.resize(scale_px(680, self._ui_scale), scale_px(520, self._ui_scale))

        layout = QVBoxLayout(dialog)
        layout.setContentsMargins(
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
            scale_px(16, self._ui_scale),
        )
        layout.setSpacing(scale_px(10, self._ui_scale))

        current_label = QLabel()
        current_label.setObjectName("count")
        current_label.setWordWrap(True)
        layout.addWidget(current_label)

        list_widget = QListWidget()
        list_widget.setSelectionMode(QAbstractItemView.SingleSelection)
        layout.addWidget(list_widget, 1)

        button_row = QHBoxLayout()
        refresh_button = QPushButton("새로고침")
        button_row.addWidget(refresh_button)
        button_row.addStretch(1)
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        ok_button = buttons.button(QDialogButtonBox.StandardButton.Ok)
        cancel_button = buttons.button(QDialogButtonBox.StandardButton.Cancel)
        ok_button.setText("선택한 창 사용")
        cancel_button.setText("취소")
        ok_button.setEnabled(False)
        button_row.addWidget(buttons)
        layout.addLayout(button_row)

        def refresh() -> None:
            list_widget.clear()
            saved_hwnd, saved_title = self._saved_target()
            current_label.setText(f"현재 선택: {saved_title} (HWND={saved_hwnd})" if saved_hwnd else "현재 선택: 없음")
            selected_row = -1
            for index, window in enumerate(get_all_windows()):
                title = str(window.get("title") or "")
                hwnd = int(window.get("hwnd") or 0)
                size = str(window.get("size") or "")
                item = QListWidgetItem(f"{title}    {size}    HWND={hwnd}")
                item.setData(Qt.UserRole, window)
                if "blue archive" in title.casefold() or "bluearchive" in title.casefold():
                    item.setForeground(QColor("#3dbf7a"))
                list_widget.addItem(item)
                if hwnd == saved_hwnd:
                    selected_row = index
            if selected_row >= 0:
                list_widget.setCurrentRow(selected_row)
            ok_button.setEnabled(list_widget.currentItem() is not None)

        def apply_selected() -> None:
            item = list_widget.currentItem()
            if item is None:
                return
            window = item.data(Qt.UserRole)
            if not isinstance(window, dict):
                return
            hwnd = int(window.get("hwnd") or 0)
            title = str(window.get("title") or "")
            if not hwnd:
                return
            config = load_config()
            config["target_hwnd"] = hwnd
            config["target_title"] = title
            save_config(config)
            set_target_window(hwnd, title)
            self._sync_settings_labels()
            if self._scan_status_label is not None:
                self._scan_status_label.setText(f"BA 창 설정 완료: {title}")
            dialog.accept()

        list_widget.itemSelectionChanged.connect(lambda: ok_button.setEnabled(list_widget.currentItem() is not None))
        list_widget.itemDoubleClicked.connect(lambda _item: apply_selected())
        refresh_button.clicked.connect(refresh)
        buttons.accepted.connect(apply_selected)
        buttons.rejected.connect(dialog.reject)

        refresh()
        dialog.exec()
    def _apply_selected_profile(self) -> None:
        if self._settings_profile_combo is None:
            return
        name = self._settings_profile_combo.currentText().strip()
        if not name:
            return
        self._activate_profile_and_reload(name)
    def _create_profile(self) -> None:
        name, ok = QInputDialog.getText(self, "새 프로필", "프로필 이름")
        if not ok:
            return
        name = name.strip()
        if not name:
            return
        self._activate_profile_and_reload(name)
        self._refresh_settings_profiles()
    def _confirm_delete_current_profile_data(self) -> None:
        if self._scanner_process is not None and self._scanner_process.poll() is None:
            QMessageBox.information(self, "BA Planner", "스캔 중에는 데이터를 삭제할 수 없습니다.")
            return

        paths = get_storage_paths()
        message = (
            f"현재 프로필 '{paths.profile_name}'의 저장 데이터를 삭제합니다.\n\n"
            "삭제 대상:\n"
            "- 스캔 결과\n"
            "- 학생/인벤토리 현재 데이터\n"
            "- 변경 이력\n"
            "- 계획, 총력전/전술대항전 기록 등 프로필 데이터\n"
            "- 프로필 DB\n\n"
            "프로필 자체와 앱 설정, 선택된 BA 창 정보는 유지됩니다.\n"
            "이 작업은 되돌릴 수 없습니다. 계속하시겠습니까?"
        )
        answer = QMessageBox.warning(
            self,
            "모든 데이터 삭제",
            message,
            QMessageBox.Yes | QMessageBox.No,
            QMessageBox.No,
        )
        if answer != QMessageBox.Yes:
            return

        try:
            self._delete_current_profile_data(paths)
        except Exception as exc:
            QMessageBox.warning(self, "BA Planner", f"데이터 삭제에 실패했습니다.\n\n{exc}")
            return

        QMessageBox.information(self, "BA Planner", "현재 프로필의 저장 데이터를 삭제했습니다.")
    def _delete_current_profile_data(self, paths) -> None:
        root = paths.root.resolve()
        targets = [
            paths.current_dir,
            paths.history_dir,
            paths.scans_dir,
            paths.db_path,
        ]
        for target in targets:
            resolved = target.resolve()
            if not resolved.is_relative_to(root):
                raise RuntimeError(f"프로필 범위를 벗어난 경로입니다: {target}")
            if target.is_dir():
                shutil.rmtree(target)
            elif target.exists():
                target.unlink()

        storage_paths = ensure_profile_storage(paths.profile_name)
        init_db(storage_paths.db_path)
        self._plan_path = storage_paths.current_dir / "growth_plan.json"
        self._tactical_path = storage_paths.current_dir / "tactical_challenge.db"
        self._raid_guide_path = storage_paths.current_raid_guides_json
        self._storage_watch_paths = (
            storage_paths.current_students_json,
            storage_paths.current_inventory_json,
            self._plan_path,
            self._tactical_path,
            self._raid_guide_path,
            storage_paths.db_path,
        )
        self._scan_status_file_offset = 0
        self._scan_status_recent_messages = []
        if self._scan_plana_log is not None:
            self._scan_plana_log.clear()
        if self._scan_status_label is not None:
            self._scan_status_label.setText("데이터 삭제 완료")
        self._reload_data()
        self._sync_settings_labels()
    def _activate_profile_and_reload(self, name: str) -> None:
        try:
            storage_paths = activate_profile(name)
            init_db(storage_paths.db_path)
            self._plan_path = storage_paths.current_dir / "growth_plan.json"
            self._tactical_path = storage_paths.current_dir / "tactical_challenge.db"
            self._raid_guide_path = storage_paths.current_raid_guides_json
            self._storage_watch_paths = (
                storage_paths.current_students_json,
                storage_paths.current_inventory_json,
                self._plan_path,
                self._tactical_path,
                self._raid_guide_path,
                storage_paths.db_path,
            )
            self._reload_data()
            self._sync_settings_labels()
            if self._scan_status_label is not None:
                self._scan_status_label.setText(f"프로필 전환 완료: {name}")
        except Exception as exc:
            QMessageBox.warning(self, "BA Planner", f"프로필 전환에 실패했습니다.\n\n{exc}")
    def _open_settings_tab(self) -> None:
        if self._main_tabs is not None and self._settings_tab is not None:
            self._main_tabs.setCurrentWidget(self._settings_tab)
    def _scan_status_path(self) -> Path:
        return get_storage_paths().current_dir / "scan_status.jsonl"
    def _scan_stop_request_path(self) -> Path:
        return get_storage_paths().current_dir / "scan_stop_requested.flag"
    def _scan_status_ack_path(self) -> Path:
        return get_storage_paths().current_dir / "scan_status_ack.json"
    def _clear_scan_stop_request(self) -> None:
        try:
            self._scan_stop_request_path().unlink(missing_ok=True)
        except Exception:
            pass
    def _request_scanner_stop(self) -> None:
        process = self._scanner_process
        if process is None or process.poll() is not None:
            return
        try:
            path = self._scan_stop_request_path()
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(datetime.now().isoformat(), encoding="utf-8")
        except Exception as exc:
            QMessageBox.warning(self, "BA Planner", f"스캔 중지 요청을 전달하지 못했습니다.\n\n{exc}")
            return
        if self._scan_status_label is not None:
            self._scan_status_label.setText(f"{self._scanner_mode_label(self._scanner_mode)} 중지 요청")
        if self._scan_stop_button is not None:
            self._scan_stop_button.setEnabled(False)
            self._scan_stop_button.setText("중지 요청됨")
    def _reset_scan_progress_view(self, mode_label: str) -> None:
        self._scan_started_at = datetime.now()
        self._scan_last_progress = (0, None)
        if self._scan_progress_bar is not None:
            self._scan_progress_bar.setRange(0, 100)
            self._scan_progress_bar.setValue(0)
        if self._scan_progress_label is not None:
            self._scan_progress_label.setText("0%")
        if self._scan_eta_label is not None:
            self._scan_eta_label.setText(f"예상 완료: {mode_label} 진행률 수집 중")
    def _finish_scan_progress_view(self, code: int) -> None:
        if self._scan_progress_bar is not None:
            self._scan_progress_bar.setRange(0, 100)
            if code == 0:
                self._scan_progress_bar.setValue(100)
        if self._scan_progress_label is not None and code == 0:
            self._scan_progress_label.setText("100%")
        if self._scan_eta_label is not None:
            self._scan_eta_label.setText("예상 완료: 완료" if code == 0 else "예상 완료: 중단됨")
        if self._scan_stop_button is not None:
            self._scan_stop_button.setEnabled(False)
            self._scan_stop_button.setText("스캔 중지")
    def _update_scan_progress_from_event(self, event: dict) -> None:
        fields = event.get("fields") if isinstance(event.get("fields"), dict) else {}
        current = self._coerce_progress_int(fields.get("current"))
        total = self._coerce_progress_int(fields.get("total"))
        note = str(fields.get("note") or "").strip()
        if current is None:
            current = 0
        if total is not None and total <= 0:
            total = None
        self._scan_last_progress = (current, total)

        percent: float | None = None
        if total:
            percent = max(0.0, min(100.0, (current / total) * 100.0))

        if self._scan_progress_bar is not None:
            self._scan_progress_bar.setRange(0, 100)
            self._scan_progress_bar.setValue(int(round(percent or 0.0)))
        if self._scan_progress_label is not None:
            if total:
                self._scan_progress_label.setText(f"{percent:.1f}% ({current}/{total})")
            else:
                self._scan_progress_label.setText(f"{current}건 처리")

        eta_text = "예상 완료: 계산 중"
        if total and current > 0 and self._scan_started_at is not None:
            elapsed = max(0.0, (datetime.now() - self._scan_started_at).total_seconds())
            remaining = elapsed * max(0, total - current) / max(1, current)
            eta = datetime.now() + timedelta(seconds=remaining)
            eta_text = f"예상 완료: {eta.strftime('%H:%M:%S')}"
            if note:
                eta_text += f" · {note}"
        elif note:
            eta_text = f"예상 완료: 계산 중 · {note}"
        if self._scan_eta_label is not None:
            self._scan_eta_label.setText(eta_text)
    @staticmethod
    def _coerce_progress_int(value: object) -> int | None:
        try:
            if value is None or value == "":
                return None
            return int(value)
        except (TypeError, ValueError):
            return None
    def _resolve_scan_student_id(self, student_id: object = None, student_name: object = None) -> str:
        sid = str(student_id or "").strip()
        if sid:
            return sid
        name = str(student_name or "").strip()
        if not name:
            return ""
        try:
            for candidate in student_meta.all_ids():
                if student_meta.display_name(candidate) == name:
                    return candidate
        except Exception:
            return ""
        return ""
    def _scan_portrait_source(self, student_id: str, form_index: object = 1) -> Path | None:
        sid = str(student_id or "").strip()
        if not sid:
            return None
        try:
            form = int(form_index or 1)
        except (TypeError, ValueError):
            form = 1
        if form > 1:
            suffix = form - 1
            for ext in (".png", ".jpg", ".jpeg", ".webp"):
                path = PORTRAIT_DIR / f"{sid}_{suffix}{ext}"
                if path.exists():
                    return path
        return portrait_path(sid)
    def _set_scan_student_portrait(self, student_id: str, form_index: object = 1) -> None:
        if self._scan_student_hero is None:
            return
        sid = str(student_id or "").strip()
        if not sid:
            self._scan_student_hero.clear()
            return
        source = self._scan_portrait_source(sid, form_index)
        if source is None or not source.exists():
            self._scan_student_hero.clear()
            return
        portrait = QPixmap(str(source))
        if portrait.isNull():
            self._scan_student_hero.clear()
            return
        record = self._records_by_id.get(sid)
        self._scan_student_hero.setPixmap(portrait, owned=record.owned if record is not None else True)
    def _reset_scan_live_state(self, student_id: str) -> None:
        sid = str(student_id or "").strip()
        record = self._records_by_id.get(sid)
        position = student_meta.field(sid, "position") if sid else None
        combat_class = student_meta.field(sid, "combat_class") if sid else None
        if record is not None:
            position = record.position or position
            combat_class = record.combat_class or combat_class
        self._scan_student_live_state = {
            "student_id": sid,
            "form_index": 1,
            "position": _position_label(position),
            "combat_class": (str(combat_class or "-").title() if combat_class else "-"),
            "level": None,
            "student_star": None,
            "weapon_star": None,
            "weapon_level": None,
            "weapon_status": None,
            "ex_skill": None,
            "skill1": None,
            "skill2": None,
            "skill3": None,
            "equip1": None,
            "equip2": None,
            "equip3": None,
            "equip4": None,
            "equip1_level": None,
            "equip2_level": None,
            "equip3_level": None,
            "combat_hp": None,
            "combat_atk": None,
            "combat_def": None,
            "combat_heal": None,
            "stat_hp": None,
            "stat_atk": None,
            "stat_heal": None,
        }
    def _scan_int_value(self, value: object) -> int | None:
        if value is None:
            return None
        if isinstance(value, bool):
            return int(value)
        if isinstance(value, int):
            return value
        text = str(value).strip().replace(",", "")
        if not text or text == "-":
            return None
        match = re.search(r"-?\d+", text)
        if not match:
            return None
        try:
            return int(match.group(0))
        except ValueError:
            return None
    def _scan_text_value(self, value: object) -> str | None:
        text = str(value or "").strip()
        return text or None
    def _scan_tier_value(self, value: object) -> str | None:
        text = str(value or "").strip().upper()
        if not text or text == "-":
            return None
        match = re.search(r"T\s*(\d+)", text)
        if match:
            return f"T{match.group(1)}"
        if text in {"EMPTY", "LEVEL_LOCKED", "LOVE_LOCKED", "NULL", "UNSUPPORTED", "UNKNOWN", "NO_SYSTEM"}:
            return text.lower()
        return text
    def _render_scan_live_card(self) -> None:
        state = getattr(self, "_scan_student_live_state", {}) or {}
        sid = str(state.get("student_id") or self._scan_current_student_id or "").strip()
        if self._scan_student_progress_strip is not None:
            star = self._scan_int_value(state.get("student_star")) or 0
            weapon_star = self._scan_int_value(state.get("weapon_star")) or 0
            show_weapon = bool(weapon_star or state.get("weapon_level") is not None or state.get("weapon_status"))
            self._scan_student_progress_strip.setProgress(star, weapon_star, show_weapon)

        level_label = self._scan_student_value_labels.get("level")
        if level_label is not None:
            level = self._scan_int_value(state.get("level"))
            level_label.setText(str(level) if level is not None else "-")
        if self._scan_student_position_label is not None:
            self._scan_student_position_label.setText(str(state.get("position") or "-"))
        if self._scan_student_class_label is not None:
            self._scan_student_class_label.setText(str(state.get("combat_class") or "-"))
        if self._scan_student_weapon_level_label is not None:
            weapon_level = self._scan_int_value(state.get("weapon_level"))
            if weapon_level is not None:
                self._scan_student_weapon_level_label.setText(f"Lv.{weapon_level}")
            else:
                self._scan_student_weapon_level_label.setText(str(state.get("weapon_status") or "-"))

        skill_pairs = {
            "skill_ex": "ex_skill",
            "skill_s1": "skill1",
            "skill_s2": "skill2",
            "skill_s3": "skill3",
        }
        for label_key, state_key in skill_pairs.items():
            label = self._scan_student_value_labels.get(label_key)
            if label is not None:
                label.setText(str(state.get(state_key) or "-"))

        bonus_label = self._scan_student_value_labels.get("stats")
        bonus_values = (state.get("stat_hp"), state.get("stat_atk"), state.get("stat_heal"))
        if bonus_label is not None:
            if any(self._scan_int_value(value) is not None for value in bonus_values):
                bonus_label.setText(_detail_bonus_stats_html((
                    ("HP", self._scan_int_value(state.get("stat_hp"))),
                    ("ATK", self._scan_int_value(state.get("stat_atk"))),
                    ("HEAL", self._scan_int_value(state.get("stat_heal"))),
                ), font_px=scale_px(13, self._ui_scale)))
            else:
                bonus_label.setText("-")

        combat_values = (state.get("combat_hp"), state.get("combat_atk"), state.get("combat_def"), state.get("combat_heal"))
        if self._scan_student_combat_stats_label is not None:
            if any(self._scan_int_value(value) is not None for value in combat_values):
                self._scan_student_combat_stats_label.setText(_scan_live_vertical_stats_html((
                    ("HP", self._scan_int_value(state.get("combat_hp"))),
                    ("ATK", self._scan_int_value(state.get("combat_atk"))),
                    ("DEF", self._scan_int_value(state.get("combat_def"))),
                    ("HEAL", self._scan_int_value(state.get("combat_heal"))),
                ), font_px=scale_px(14, self._ui_scale)))
            else:
                self._scan_student_combat_stats_label.setText("-")

        for index, slot in enumerate(("equip1", "equip2", "equip3"), start=1):
            card = self._scan_student_equip_cards.get(slot)
            if card is None:
                continue
            tier = self._scan_text_value(state.get(slot))
            level = self._scan_int_value(state.get(f"{slot}_level"))
            icon_path = _equipment_icon_path(sid, index, tier) if sid else None
            icon_pixmap = QPixmap()
            value_text = _slot_placeholder(tier)
            if icon_path is not None:
                loaded = QPixmap(str(icon_path))
                if not loaded.isNull():
                    icon_pixmap = loaded
                    value_text = ""
            elif _parse_tier_number(tier) is not None:
                value_text = str(tier)
            card.setData(icon=icon_pixmap, value=value_text, level=str(level) if level is not None else "")

        favorite_card = self._scan_student_equip_cards.get("favorite")
        if favorite_card is not None:
            favorite_supported = student_meta.favorite_item_enabled(sid) if sid else True
            tier = self._scan_text_value(state.get("equip4"))
            tier_num = _parse_tier_number(tier)
            value_text = _slot_placeholder(tier, supported=favorite_supported)
            if tier_num is not None:
                value_text = f"T{tier_num}"
            favorite_card.setData(icon=QPixmap(), value=value_text, level="")
    def _reset_scan_student_card(self, student_id: object = None, student_name: object = None, meta: str = "") -> None:
        self._set_scan_detail_mode("student")
        name = str(student_name or "").strip()
        sid = self._resolve_scan_student_id(student_id, name)
        if sid and not name:
            try:
                name = student_meta.display_name(sid)
            except Exception:
                name = sid
        self._scan_current_student_id = sid
        self._scan_current_student_name = name
        self._reset_scan_live_state(sid)
        if self._scan_student_name_label is not None:
            self._scan_student_name_label.setText(name or "")
        if self._scan_student_meta_label is not None:
            self._scan_student_meta_label.setText(meta or "")
        for label in self._scan_student_value_labels.values():
            label.setText("-")
        if self._scan_student_progress_strip is not None:
            self._scan_student_progress_strip.setProgress(0, 0, False)
        for card in self._scan_student_equip_cards.values():
            card.clearData()
        self._set_scan_student_portrait(sid, 1)
        self._render_scan_live_card()
    def _set_scan_student_value(self, key: str, value: object) -> None:
        state = getattr(self, "_scan_student_live_state", None)
        if state is None:
            self._scan_student_live_state = {}
            state = self._scan_student_live_state
        text = str(value or "").strip()
        if key == "level":
            state["level"] = self._scan_int_value(value) if self._scan_int_value(value) is not None else text or None
        elif key == "star":
            state["student_star"] = self._scan_int_value(value)
        elif key == "weapon":
            level = self._scan_int_value(re.search(r"Lv\.\s*(\d+)", text).group(1) if re.search(r"Lv\.\s*(\d+)", text) else None)
            star_match = re.search(r"(\d+)\s*성", text)
            if star_match:
                state["weapon_star"] = self._scan_int_value(star_match.group(1))
            if level is not None:
                state["weapon_level"] = level
            elif text and not star_match:
                state["weapon_status"] = text
        elif key in {"skill_ex", "skill_s1", "skill_s2", "skill_s3"}:
            state[{"skill_ex": "ex_skill", "skill_s1": "skill1", "skill_s2": "skill2", "skill_s3": "skill3"}[key]] = self._scan_int_value(value) if self._scan_int_value(value) is not None else text or None
        elif key in {"equip1", "equip2", "equip3"}:
            tier = self._scan_tier_value(value)
            if tier is not None:
                state[key] = tier
            level_match = re.search(r"Lv\.\s*(\d+)", text)
            if level_match:
                state[f"{key}_level"] = self._scan_int_value(level_match.group(1))
        elif key == "favorite":
            state["equip4"] = self._scan_tier_value(value) or text or None
        elif key == "stats":
            match = re.search(r"HP\s+([^/]+)\s*/\s*ATK\s+([^/]+)\s*/\s*HEAL\s+(.+)$", text)
            if match:
                state["stat_hp"] = self._scan_int_value(match.group(1))
                state["stat_atk"] = self._scan_int_value(match.group(2))
                state["stat_heal"] = self._scan_int_value(match.group(3))
        elif key == "combat_stats":
            match = re.search(r"HP\s+([^/]+)\s*/\s*ATK\s+([^/]+)\s*/\s*DEF\s+([^/]+)\s*/\s*HEAL\s+(.+)$", text)
            if match:
                state["combat_hp"] = self._scan_int_value(match.group(1))
                state["combat_atk"] = self._scan_int_value(match.group(2))
                state["combat_def"] = self._scan_int_value(match.group(3))
                state["combat_heal"] = self._scan_int_value(match.group(4))
        label = self._scan_student_value_labels.get(key)
        if label is not None:
            label.setText(text or "-")
        self._render_scan_live_card()
    def _merge_scan_equipment_value(self, key: str, *, tier: object = None, level: object = None) -> None:
        state = self._scan_student_live_state
        if tier is not None and str(tier).strip():
            state[key] = self._scan_tier_value(tier)
        if level is not None and str(level).strip():
            state[f"{key}_level"] = self._scan_int_value(level)
        self._render_scan_live_card()
    def _merge_scan_weapon_value(self, *, star: object = None, level: object = None) -> None:
        state = self._scan_student_live_state
        if star is not None and str(star).strip():
            state["weapon_star"] = self._scan_int_value(star)
            state["weapon_status"] = None
        if level is not None and str(level).strip():
            state["weapon_level"] = self._scan_int_value(level)
            state["weapon_status"] = None
        self._render_scan_live_card()
    def _merge_scan_stat_value(self, field_name: str, value: object) -> None:
        self._scan_student_live_state[field_name] = self._scan_int_value(value)
        self._render_scan_live_card()
    def _merge_scan_combat_stat_value(self, field_name: str, value: object) -> None:
        self._scan_student_live_state[field_name] = self._scan_int_value(value)
        self._render_scan_live_card()
    def _apply_scan_field_confirmed_event(self, fields: dict) -> None:
        field_name = str(fields.get("field") or "").strip()
        value = fields.get("value")
        if not field_name:
            return
        direct_map = {
            "level": "level",
            "student_star": "star",
            "ex_skill": "skill_ex",
            "skill1": "skill_s1",
            "skill2": "skill_s2",
            "skill3": "skill_s3",
            "equip4": "favorite",
        }
        label_key = direct_map.get(field_name)
        if label_key:
            self._set_scan_student_value(label_key, value)
            return
        if field_name == "weapon_star":
            self._merge_scan_weapon_value(star=value)
        elif field_name == "weapon_level":
            self._merge_scan_weapon_value(level=value)
        elif field_name in {"equip1", "equip2", "equip3"}:
            self._merge_scan_equipment_value(field_name, tier=value)
        elif field_name in {"equip1_level", "equip2_level", "equip3_level"}:
            self._merge_scan_equipment_value(field_name.removesuffix("_level"), level=value)
        elif field_name in {"stat_hp", "stat_atk", "stat_heal"}:
            self._merge_scan_stat_value(field_name, value)
        elif field_name in {"combat_hp", "combat_atk", "combat_def", "combat_heal"}:
            self._merge_scan_combat_stat_value(field_name, value)
    def _reset_scan_inventory_card(self, source_label: object = None, meta: str = "", grid_cols: object = None, grid_rows: object = None) -> None:
        label = str(source_label or "").strip() or "인벤토리"
        self._set_scan_detail_mode("inventory")
        if grid_cols is not None or grid_rows is not None:
            self._configure_scan_inventory_grid(grid_cols, grid_rows)
        else:
            self._reset_scan_inventory_grid_cells()
        if self._scan_inventory_title_label is not None:
            self._scan_inventory_title_label.setText(f"{label} 그리드")
        if self._scan_inventory_meta_label is not None:
            self._scan_inventory_meta_label.setText(meta or "그리드 상태를 확인하고 있습니다.")
        self._scan_inventory_confirmed_count = 0
        self._scan_current_student_id = ""
        self._scan_current_student_name = ""
        if self._scan_student_name_label is not None:
            self._scan_student_name_label.setText(f"{label} 스캔 중")
        if self._scan_student_meta_label is not None:
            self._scan_student_meta_label.setText(meta or "그리드 상태를 확인하고 있습니다.")
        for value_label in self._scan_student_value_labels.values():
            value_label.setText("-")
        self._set_scan_student_value("level", "그리드")
        self._set_scan_student_value("star", "대기")
        self._set_scan_student_value("equip1", "확정 0")
        self._set_scan_student_value("equip2", "티어 대기")
        self._set_scan_student_value("equip3", "스크롤 대기")
        if self._scan_student_progress_strip is not None:
            self._scan_student_progress_strip.setProgress(0, 0, False)
        if self._scan_student_hero is not None:
            self._scan_student_hero.clear()
    def _update_scan_student_card_from_event(self, event: dict) -> None:
        event_id = str(event.get("id") or "")
        fields = event.get("fields") if isinstance(event.get("fields"), dict) else {}
        student_name = str(fields.get("student_name") or "").strip()
        student_id = self._resolve_scan_student_id(fields.get("student_id"), student_name)

        if event_id == "field.confirmed":
            self._apply_scan_field_confirmed_event(fields)
            return
        if event_id == "student.form.switch":
            form_index = fields.get("form_index") or 1
            sid = student_id or self._scan_current_student_id
            if sid:
                self._scan_student_live_state["form_index"] = self._scan_int_value(form_index) or 1
                self._set_scan_student_portrait(sid, form_index)
            return
        if event_id == "inventory.scan.start":
            source_label = fields.get("source_label") or fields.get("source") or "\uC778\uBCA4\uD1A0\uB9AC"
            grid_cols = fields.get("grid_cols")
            grid_rows = fields.get("grid_rows")
            total_slots = fields.get("total_slots")
            profile_id = str(fields.get("profile_id") or "").strip()
            grid_text = f"{grid_cols}x{grid_rows} \uADF8\uB9AC\uB4DC" if grid_cols and grid_rows else "\uADF8\uB9AC\uB4DC"
            meta_parts = [grid_text]
            if total_slots:
                meta_parts.append(f"{total_slots}\uCE78")
            if profile_id:
                meta_parts.append(profile_id)
            self._reset_scan_inventory_card(source_label, " / ".join(meta_parts), grid_cols, grid_rows)
            self._set_scan_student_value("star", f"{total_slots}\uCE78" if total_slots else "\uD655\uC778 \uC911")
            return
        if event_id == "inventory.slot.tier_hint":
            tier = fields.get("tier_hint")
            slot_number = fields.get("slot_number")
            if tier is not None:
                suffix = f" ({slot_number}\uBC88)" if slot_number else ""
                self._set_scan_student_value("equip2", f"T{tier} \uD78C\uD2B8{suffix}")
                self._set_scan_inventory_cell_tier(slot_number, tier)
            return
        if event_id == "inventory.row_anchor.confirmed":
            slot_number = fields.get("slot_number")
            row_number = fields.get("row_number")
            self._mark_scan_inventory_cell_anchor(slot_number)
            label = f"{row_number}\uD589 \uC575\uCEE4" if row_number else "\uD589 \uC575\uCEE4"
            if slot_number:
                label = f"{label} {slot_number}\uBC88"
            self._set_scan_student_value("equip2", label)
            if self._scan_inventory_meta_label is not None:
                self._scan_inventory_meta_label.setText(f"{label} \uD655\uC815")
            return
        if event_id == "inventory.slot.confirmed":
            self._scan_inventory_confirmed_count = max(0, self._scan_inventory_confirmed_count) + 1
            item_name = str(fields.get("item_name") or "").strip()
            quantity = str(fields.get("quantity") or "").strip()
            slot_number = fields.get("slot_number")
            row_anchor = bool(fields.get("row_anchor"))
            self._set_scan_student_value("equip1", f"\uD655\uC815 {self._scan_inventory_confirmed_count}")
            if item_name:
                detail = f"{item_name} x{quantity}" if quantity else item_name
                self._set_scan_student_value("favorite", detail)
            item_id = fields.get("item_id")
            self._set_scan_inventory_cell_confirmed(
                slot_number,
                item_name,
                quantity,
                str(item_id) if item_id else None,
                row_anchor=row_anchor,
            )
            if self._scan_inventory_meta_label is not None:
                suffix = " / \uC575\uCEE4" if row_anchor else ""
                self._scan_inventory_meta_label.setText(f"\uD655\uC815 {self._scan_inventory_confirmed_count}\uAC1C{suffix}")
            if self._scan_student_meta_label is not None:
                slot_text = f"{slot_number}\uBC88 \uC2AC\uB86F" if slot_number else "\uC2AC\uB86F"
                self._scan_student_meta_label.setText(f"{slot_text} \uD655\uC815 \uC911")
            return
        if event_id == "inventory.scroll":
            overlap_rows = fields.get("overlap_rows")
            moved_rows = fields.get("moved_rows")
            self._apply_scan_inventory_scroll_feedback(
                moved_rows=moved_rows,
                overlap_rows=overlap_rows,
                scan_slots=fields.get("scan_slots"),
            )
            if moved_rows is not None:
                self._set_scan_student_value("equip3", f"{moved_rows}\uD589 \uC774\uB3D9")
            elif overlap_rows is not None:
                self._set_scan_student_value("equip3", f"\uC911\uBCF5 {overlap_rows}\uD589")
            if self._scan_student_meta_label is not None:
                self._scan_student_meta_label.setText("\uB2E4\uC74C \uADF8\uB9AC\uB4DC \uD398\uC774\uC9C0\uB85C \uC774\uB3D9 \uC911")
            if self._scan_inventory_meta_label is not None:
                self._scan_inventory_meta_label.setText("\uADF8\uB9AC\uB4DC\uB97C \uC704\uB85C \uBC00\uC5B4 \uB2E4\uC74C \uD398\uC774\uC9C0\uB97C \uC900\uBE44\uD569\uB2C8\uB2E4")
            return

        if event_id == "student.identify.start":
            index = str(fields.get("index") or "").strip()
            meta = f"{index}번째 학생 사진 확인 중" if index else "학생 사진 확인 중"
            self._reset_scan_student_card(meta=meta)
            return
        if event_id == "student.identify.success":
            self._reset_scan_student_card(student_id, student_name, "사진 식별 완료. 기록 카드를 준비합니다.")
            return
        if event_id == "student.scan.start":
            self._reset_scan_student_card(student_id, student_name, "학생부 기록 정리 중")
            return

        if student_name and not self._scan_current_student_name:
            self._scan_current_student_name = student_name
            if self._scan_student_name_label is not None:
                self._scan_student_name_label.setText(student_name)
        if student_id and not self._scan_current_student_id:
            self._scan_current_student_id = student_id
            self._set_scan_student_portrait(student_id)

        if event_id == "level.read.ok":
            self._set_scan_student_value("level", fields.get("level"))
        elif event_id == "level.read.failed":
            self._set_scan_student_value("level", "확인 필요")
        elif event_id in {"star.read.ok", "star.infer_from_weapon"}:
            star = fields.get("star")
            self._set_scan_student_value("star", star)
            if self._scan_student_progress_strip is not None:
                try:
                    self._scan_student_progress_strip.setProgress(int(star or 0), 0, False)
                except (TypeError, ValueError):
                    pass
        elif event_id == "star.read.uncertain":
            star = fields.get("star")
            self._set_scan_student_value("star", f"{star}성 확인 필요" if star else "확인 필요")
        elif event_id == "weapon_state.no_system":
            self._set_scan_student_value("weapon", "미해금")
        elif event_id == "weapon_state.unlocked_not_equipped":
            self._set_scan_student_value("weapon", "미장착")
        elif event_id == "weapon_state.equipped":
            self._set_scan_student_value("weapon", "장착")
        elif event_id == "weapon_state.uncertain":
            self._set_scan_student_value("weapon", "확인 필요")
        elif event_id == "weapon.skip_star_locked":
            self._set_scan_student_value("weapon", "잠금")
        elif event_id == "weapon.skip_no_system":
            self._set_scan_student_value("weapon", "미해금")
        elif event_id == "weapon.skip_not_equipped":
            self._set_scan_student_value("weapon", "미장착")
        elif event_id == "weapon.summary":
            self._set_scan_student_value("weapon", f"{fields.get('star')}성 Lv.{fields.get('level')}")
            if self._scan_student_progress_strip is not None:
                try:
                    star_label = self._scan_student_value_labels.get("star")
                    student_star = int((star_label.text() if star_label is not None else "0") or 0)
                    weapon_star = int(fields.get("star") or 0)
                    self._scan_student_progress_strip.setProgress(student_star, weapon_star, True)
                except (TypeError, ValueError):
                    pass
        elif event_id == "skills.value.ok":
            skill_key = str(fields.get("skill") or "")
            label_key = {
                "ex_skill": "skill_ex",
                "skill1": "skill_s1",
                "skill2": "skill_s2",
                "skill3": "skill_s3",
            }.get(skill_key)
            if label_key:
                self._set_scan_student_value(label_key, fields.get("value"))
        elif event_id == "skills.summary":
            self._set_scan_student_value("skill_ex", fields.get("ex"))
            self._set_scan_student_value("skill_s1", fields.get("s1"))
            self._set_scan_student_value("skill_s2", fields.get("s2"))
            self._set_scan_student_value("skill_s3", fields.get("s3"))
        elif event_id == "skills.skill2.skip_star_locked":
            self._set_scan_student_value("skill_s2", "잠금")
        elif event_id == "skills.skill3.skip_star_locked":
            self._set_scan_student_value("skill_s3", "잠금")
        elif event_id == "equipment.saved_max_skip":
            for key in ("equip1", "equip2", "equip3"):
                self._set_scan_student_value(key, "T10 Lv.70")
        elif event_id == "equipment.favorite_saved_max_skip":
            self._set_scan_student_value("favorite", "T2")
        elif event_id.startswith("equip") and ".empty" in event_id:
            slot = event_id[5:6]
            if slot in {"1", "2", "3"}:
                self._set_scan_student_value(f"equip{slot}", "미장착")
        elif event_id in {"equip2.button_off_empty", "equip3.button_off_empty"}:
            self._set_scan_student_value(event_id[:6], "미장착")
        elif event_id in {"equip2.slot_flag.empty", "equip3.slot_flag.empty"}:
            self._set_scan_student_value(event_id[:6], "미장착")
        elif event_id in {"equip2.slot_flag.level_locked", "equip3.slot_flag.level_locked"}:
            self._set_scan_student_value(event_id[:6], "잠김")
        elif event_id in {"equip2.skip_level_locked_from_level", "equip3.skip_level_locked_from_level"}:
            self._set_scan_student_value(event_id[:6], "잠김")
        elif event_id.startswith("equip") and event_id.endswith(".tier.ok"):
            slot = event_id[5:6]
            if slot in {"1", "2", "3"}:
                self._merge_scan_equipment_value(f"equip{slot}", tier=fields.get("tier"))
        elif event_id.startswith("equip") and event_id.endswith(".level.ok"):
            slot = event_id[5:6]
            if slot in {"1", "2", "3"}:
                self._merge_scan_equipment_value(f"equip{slot}", level=fields.get("level"))
        elif event_id == "favorite.unsupported":
            self._set_scan_student_value("favorite", "없음")
        elif event_id in {"favorite.growth_off_dot_empty", "favorite.slot_flag.empty"}:
            self._set_scan_student_value("favorite", "미장착")
        elif event_id == "favorite.growth_on_needs_menu":
            self._set_scan_student_value("favorite", "상세 확인 중")
        elif event_id == "favorite.slot_flag.love_locked":
            self._set_scan_student_value("favorite", "인연 15 잠금")
        elif event_id == "favorite.slot_flag.null":
            self._set_scan_student_value("favorite", "없음")
        elif event_id == "favorite.tier.t1":
            self._set_scan_student_value("favorite", "T1")
        elif event_id == "favorite.tier.t2":
            self._set_scan_student_value("favorite", "T2")
        elif event_id == "stats.skip_condition":
            self._set_scan_student_value("stats", "잠금")
        elif event_id == "stats.saved_max_skip":
            self._set_scan_student_value("stats", "최대 기록")
        elif event_id == "stats.summary":
            self._set_scan_student_value(
                "stats",
                f"HP {fields.get('hp')} / ATK {fields.get('atk')} / HEAL {fields.get('heal')}",
            )
        elif event_id == "summary.student.compact":
            if self._scan_student_meta_label is not None:
                self._scan_student_meta_label.setText("정리 완료. 기록 반영을 기다립니다.")
        elif event_id == "student.scan.commit":
            if self._scan_student_meta_label is not None:
                self._scan_student_meta_label.setText("기록 반영 완료")
        elif event_id == "student.scan.partial_commit":
            if self._scan_student_meta_label is not None:
                self._scan_student_meta_label.setText("확인 필요 항목이 있어 일부 기록만 반영했습니다.")
        elif event_id == "student.scan.failed":
            if self._scan_student_meta_label is not None:
                self._scan_student_meta_label.setText("기록 반영 실패")
    def _plana_expression_path(self, expression: str) -> Path:
        filename = f"{expression}.png"
        candidates = (
            BASE_DIR / "assets" / "plana" / filename,
            APP_DIR / "assets" / "plana" / filename,
            APP_DIR / "_internal" / "assets" / "plana" / filename,
        )
        for path in candidates:
            if path.exists():
                return path
        return candidates[0]
    def _set_plana_expression(self, expression: str) -> None:
        if self._scan_plana_image_label is None:
            return
        expression = expression if expression else "neutral"
        pixmap = self._scan_plana_pixmaps.get(expression)
        if pixmap is None:
            path = self._plana_expression_path(expression)
            pixmap = QPixmap(str(path))
            self._scan_plana_pixmaps[expression] = pixmap
        if pixmap.isNull():
            self._scan_plana_image_label.clear()
            self._scan_plana_image_label.setVisible(False)
            return
        target_w = scale_px(260, self._ui_scale)
        target_h = scale_px(360, self._ui_scale)
        self._scan_plana_image_label.setVisible(True)
        self._scan_plana_image_label.setPixmap(
            pixmap.scaled(
                target_w,
                target_h,
                Qt.KeepAspectRatio,
                Qt.SmoothTransformation,
            )
        )
    def _set_plana_message(self, message: str, meta: str = "") -> None:
        if self._scan_plana_message_label is not None:
            self._scan_plana_message_label.setText(message)
        if self._scan_plana_meta_label is not None:
            self._scan_plana_meta_label.setText(meta or "학생부 정리 대기 중")
    def _reset_plana_scan_status(self, mode_label: str) -> None:
        self._scan_status_file_offset = 0
        self._scan_status_recent_messages = []
        try:
            reset_status_log(self._scan_status_path())
            write_status_ack(self._scan_status_ack_path(), 0)
        except Exception:
            pass
        self._set_plana_message(
            "스캔을 준비하는 중입니다. 잠시만 기다려 주십시오, 선생님.",
            f"{mode_label} 준비 중",
        )
        self._set_plana_expression("neutral")
        if self._scan_plana_log is not None:
            self._scan_plana_log.clear()
        self._reset_scan_student_card()
    def _append_plana_status_event(self, event: dict) -> None:
        if str(event.get("id") or "") == "progress.update":
            self._update_scan_progress_from_event(event)
            return
        self._update_scan_student_card_from_event(event)
        message = str(event.get("message") or "").strip()
        if not message:
            return
        level = str(event.get("level") or "detail")
        phase = str(event.get("phase") or "scan")
        expression = str(event.get("expression") or "").strip()
        if expression:
            self._set_plana_expression(expression)
        fields = event.get("fields") if isinstance(event.get("fields"), dict) else {}
        student_name = str(fields.get("student_name") or "").strip()
        meta_parts = []
        if student_name:
            meta_parts.append(student_name)
        if phase:
            meta_parts.append(phase)
        meta = " / ".join(meta_parts)
        if level in {"primary", "result", "skip", "warning", "error"}:
            self._set_plana_message(message, meta)

        try:
            ts = datetime.fromtimestamp(float(event.get("ts") or 0)).strftime("%H:%M:%S")
        except Exception:
            ts = "--:--:--"
        prefix = {
            "warning": "확인 필요",
            "error": "오류",
            "skip": "판단",
            "result": "확인",
            "primary": "진행",
        }.get(level, "상세")
        line = f"[{ts}] {prefix} · {message}"
        self._scan_status_recent_messages.append(line)
        self._scan_status_recent_messages = self._scan_status_recent_messages[-80:]
        if self._scan_plana_log is not None:
            self._scan_plana_log.setPlainText("\n".join(self._scan_status_recent_messages))
            self._scan_plana_log.verticalScrollBar().setValue(
                self._scan_plana_log.verticalScrollBar().maximum()
            )
    def _poll_scan_status_events(self) -> None:
        try:
            events, offset = read_status_events(self._scan_status_path(), self._scan_status_file_offset)
        except Exception:
            return
        self._scan_status_file_offset = offset
        last_seq = 0
        for event in events:
            self._append_plana_status_event(event)
            try:
                last_seq = max(last_seq, int(event.get("seq") or 0))
            except (TypeError, ValueError):
                pass
        if last_seq > 0:
            try:
                write_status_ack(self._scan_status_ack_path(), last_seq)
            except Exception:
                pass
    def _scanner_mode_label(self, mode: str) -> str:
        labels = {
            "resources": "자원 스캔",
            "items": "아이템 스캔",
            "equipment": "장비 스캔",
            "students": "학생 스캔",
            "student_current": "현재 학생 스캔",
        }
        return labels.get(mode, mode or "스캔")
    def _cleanup_finished_scanner_process(self, *, notify: bool) -> bool:
        process = self._scanner_process
        if process is None:
            return False
        code = process.poll()
        if code is None:
            return False
        self._scanner_process = None
        self._scanner_poll_timer.stop()
        if self._scan_status_poll_timer is not None:
            self._scan_status_poll_timer.stop()
        self._on_scanner_process_finished(code, notify=notify)
        return True
    def _on_scanner_process_finished(self, code: int, *, notify: bool = True) -> None:
        self._poll_scan_status_events()
        mode = self._scanner_mode
        self._scanner_mode = ""
        label = self._scanner_mode_label(mode)
        self._finish_scan_progress_view(code)
        if self._scan_status_label is not None:
            self._scan_status_label.setText(
                f"{label} 완료" if code == 0 else f"{label} 종료 코드: {code}"
            )
        if code == 0:
            try:
                self._reload_data()
            except Exception:
                pass
        if notify:
            self._notify_scanner_finished(label, code)
    def _notify_scanner_finished(self, label: str, code: int) -> None:
        title = "BA Planner"
        message = f"{label}이 끝났습니다." if code == 0 else f"{label}이 종료되었습니다. 코드: {code}"
        QApplication.alert(self, 0)
        QApplication.beep()
        if os.name == "nt":
            try:
                import winsound

                winsound.MessageBeep(winsound.MB_ICONASTERISK if code == 0 else winsound.MB_ICONHAND)
            except Exception:
                pass
        if not QSystemTrayIcon.isSystemTrayAvailable():
            return
        icon = self.windowIcon()
        if self._scanner_tray_icon is None:
            self._scanner_tray_icon = QSystemTrayIcon(icon, self)
            self._scanner_tray_icon.setToolTip("BA Planner")
            self._scanner_tray_icon.show()
        elif not icon.isNull():
            self._scanner_tray_icon.setIcon(icon)
        tray_icon = QSystemTrayIcon.Information if code == 0 else QSystemTrayIcon.Warning
        self._scanner_tray_icon.showMessage(title, message, tray_icon, 8000)
    def _scanner_command(self, mode: str) -> list[str]:
        command = [sys.executable]
        if not getattr(sys, "frozen", False):
            command.append(str(BASE_DIR / "main.py"))
        command.extend(["--scanner", "--use-saved-target", "--suppress-overlay"])
        if mode:
            command.extend(["--auto-scan", mode])
        return command
    def _launch_scanner(self, mode: str) -> None:
        self._cleanup_finished_scanner_process(notify=False)
        if self._scanner_process is not None and self._scanner_process.poll() is None:
            QMessageBox.information(self, "BA Planner", "이미 스캐너가 실행 중입니다.")
            return
        if not self._load_saved_target_into_capture():
            QMessageBox.information(self, "BA Planner", "먼저 설정 탭에서 BA 창을 선택해주세요.")
            self._open_settings_tab()
            return
        self._sync_settings_labels()
        activate_target_window()
        self._clear_scan_stop_request()
        creationflags = subprocess.CREATE_NO_WINDOW if os.name == "nt" and hasattr(subprocess, "CREATE_NO_WINDOW") else 0
        try:
            self._scanner_process = subprocess.Popen(
                self._scanner_command(mode),
                cwd=str(BASE_DIR),
                creationflags=creationflags,
            )
        except Exception as exc:
            QMessageBox.warning(self, "BA Planner", f"스캐너 실행에 실패했습니다.\n\n{exc}")
            return
        self._scanner_mode = mode
        label = self._scanner_mode_label(mode)
        self._reset_plana_scan_status(label)
        self._reset_scan_progress_view(label)
        if mode in {"items", "equipment", "resources"}:
            self._reset_scan_inventory_card(label, f"{label} 준비 중", 5, 5 if mode == "equipment" else 4)
        if mode in {"students", "all"}:
            self._set_plana_message(
                "첫 번째 학생의 기본 정보 화면을 확인합니다. 선생님, 스캔할 첫 번째 학생의 정보창을 띄워 주십시오.",
                "첫 학생 정보창에서 시작",
            )
        if self._scan_status_label is not None:
            self._scan_status_label.setText(f"{label} 시작")
        if self._scan_stop_button is not None:
            self._scan_stop_button.setEnabled(True)
            self._scan_stop_button.setText("스캔 중지")
        self._scanner_poll_timer.start()
        if self._scan_status_poll_timer is not None:
            self._scan_status_poll_timer.start()
    def _state_export_students(self) -> list[dict[str, object]]:
        field_map = (
            ("student_id", "student_id"),
            ("display_name", "display_name"),
            ("level", "level"),
            ("student_star", "star"),
            ("weapon_state", "weapon_state"),
            ("weapon_star", "weapon_star"),
            ("weapon_level", "weapon_level"),
            ("ex_skill", "ex_skill"),
            ("skill1", "skill1"),
            ("skill2", "skill2"),
            ("skill3", "skill3"),
            ("equip1", "equip1"),
            ("equip2", "equip2"),
            ("equip3", "equip3"),
            ("equip4", "equip4"),
            ("equip1_level", "equip1_level"),
            ("equip2_level", "equip2_level"),
            ("equip3_level", "equip3_level"),
            ("combat_hp", "combat_hp"),
            ("combat_atk", "combat_atk"),
            ("combat_def", "combat_def"),
            ("combat_heal", "combat_heal"),
            ("stat_hp", "stat_hp"),
            ("stat_atk", "stat_atk"),
            ("stat_heal", "stat_heal"),
        )
        rows: list[dict[str, object]] = []
        for record in self._all_students:
            if not record.owned:
                continue
            rows.append({export_key: getattr(record, attr) for export_key, attr in field_map})
        return rows
    def _copy_state_export_to_clipboard(self) -> None:
        try:
            students = self._state_export_students()
            token = encode_state_export(
                students=students,
                inventory=self._inventory_snapshot or {},
                resources=self._resource_snapshot or {},
                profile_name=get_active_profile_name("Default"),
                app_version=APP_VERSION,
            )
        except Exception as exc:
            QMessageBox.warning(self, "BA Planner", f"State export failed.\n\n{exc}")
            return
        QApplication.clipboard().setText(token)
        student_count = len(students)
        inventory_count = len(self._inventory_snapshot or {})
        resource_count = len(self._resource_snapshot or {})
        if self._scan_status_label is not None:
            self._scan_status_label.setText(
                f"State export copied: students {student_count}, inventory {inventory_count}, resources {resource_count}"
            )
        QMessageBox.information(
            self,
            "BA Planner",
            "State export copied to clipboard.\n\n"
            f"Students: {student_count} / Inventory: {inventory_count} / Resources: {resource_count}\n"
            f"Length: {len(token):,} characters",
        )
    def _check_scanner_process(self) -> None:
        if self._scanner_process is None:
            self._scanner_poll_timer.stop()
            if self._scan_status_poll_timer is not None:
                self._scan_status_poll_timer.stop()
            return
        self._poll_scan_status_events()
        code = self._scanner_process.poll()
        if code is None:
            return
        self._scanner_process = None
        self._scanner_poll_timer.stop()
        if self._scan_status_poll_timer is not None:
            self._scan_status_poll_timer.stop()
        self._on_scanner_process_finished(code)
