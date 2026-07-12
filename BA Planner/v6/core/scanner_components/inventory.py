"""InventoryScannerComponent implementation extracted from the Scanner façade."""

from __future__ import annotations

from core import scanner_shared as _scanner_shared

globals().update({name: value for name, value in vars(_scanner_shared).items() if not name.startswith("__")})


class InventoryScannerComponent:
    def _capture_settled_inventory_scroll_frame(
        self,
        initial_img: Image.Image,
        slots: list[dict],
        *,
        grid_cols: int,
        grid_rows: int,
        row_step_px: int,
    ) -> tuple[Image.Image | None, dict | None, int]:
        """Capture until gray-band row centers are stable across consecutive frames."""
        previous_img = initial_img
        previous_layout = _inventory_gray_band_layout_slots(
            previous_img,
            slots,
            grid_cols=grid_cols,
            grid_rows=grid_rows,
            row_step_px=row_step_px,
        )
        stable_comparisons = 0
        for capture_index in range(1, INVENTORY_SCROLL_STABLE_MAX_CAPTURES + 1):
            if not self._wait(INVENTORY_SCROLL_STABLE_FRAME_WAIT):
                return None, None, capture_index
            current_img = self._capture()
            if current_img is None:
                return None, None, capture_index
            current_layout = _inventory_gray_band_layout_slots(
                current_img,
                slots,
                grid_cols=grid_cols,
                grid_rows=grid_rows,
                row_step_px=row_step_px,
            )
            if _inventory_gray_band_centers_stable(previous_layout, current_layout, row_step_px):
                stable_comparisons += 1
            else:
                stable_comparisons = 0
            if stable_comparisons >= INVENTORY_SCROLL_STABLE_REQUIRED_COMPARISONS:
                return current_img, current_layout, capture_index
            previous_img = current_img
            previous_layout = current_layout
        return None, previous_layout, INVENTORY_SCROLL_STABLE_MAX_CAPTURES

    def _inventory_filter_title_score(self, img: Optional[Image.Image]) -> float | None:
        if img is None or not INVENTORY_FILTER_TITLE_TEMPLATE.exists():
            return None
        title_crop = crop_region(img, INVENTORY_FILTER_TITLE_REGION)
        return match_score_resized(title_crop, str(INVENTORY_FILTER_TITLE_TEMPLATE))
    def _is_inventory_filter_menu_capture(self, img: Optional[Image.Image]) -> bool:
        score = self._inventory_filter_title_score(img)
        matched = score is not None and score >= INVENTORY_FILTER_TITLE_MIN_SCORE
        _log.debug(
            "inventory_filter_title: score=%s threshold=%.3f matched=%s",
            "none" if score is None else f"{score:.3f}",
            INVENTORY_FILTER_TITLE_MIN_SCORE,
            str(matched).lower(),
        )
        return matched
    def _wait_for_inventory_filter_menu_open(
        self,
        *,
        timeout: float = INVENTORY_PANEL_OPEN_TIMEOUT,
        initial_wait: float = INVENTORY_FILTER_MENU_SETTLE_WAIT,
        poll: float = UI_FLAG_POLL,
    ) -> bool:
        if initial_wait > 0 and not self._wait(initial_wait):
            return False
        deadline = time.monotonic() + timeout
        ready_streak = 0
        last_score: float | None = None
        while time.monotonic() < deadline:
            if self._stop_requested():
                return False
            img = self._capture()
            last_score = self._inventory_filter_title_score(img)
            if last_score is not None and last_score >= INVENTORY_FILTER_TITLE_MIN_SCORE:
                ready_streak += 1
                if ready_streak >= INVENTORY_FILTER_TITLE_STABLE_POLLS:
                    self._debug(f"  inventory filter title ready score={last_score:.3f}")
                    return True
            else:
                ready_streak = 0
            if not self._wait(poll):
                return False
        if last_score is None:
            self.log("  inventory filter title check unavailable")
        else:
            self.log(
                f"  inventory filter title timeout "
                f"score={last_score:.3f} < {INVENTORY_FILTER_TITLE_MIN_SCORE:.2f}"
            )
        return False
    def _wait_for_item_inventory_filter_menu_open(
        self,
        *,
        timeout: float = INVENTORY_PANEL_OPEN_TIMEOUT,
        initial_wait: float = INVENTORY_FILTER_MENU_SETTLE_WAIT,
        poll: float = UI_FLAG_POLL,
    ) -> bool:
        if initial_wait > 0 and not self._wait(initial_wait):
            return False
        deadline = time.monotonic() + timeout
        ready_streak = 0
        last_title_score: float | None = None
        last_sort_score: float | None = None
        while time.monotonic() < deadline:
            if self._stop_requested():
                return False
            img = self._capture()
            last_title_score = self._inventory_filter_title_score(img)
            last_sort_score = self._item_filter_menu_sort_tab_score(None)
            title_ready = (
                last_title_score is not None
                and last_title_score >= INVENTORY_FILTER_TITLE_MIN_SCORE
            )
            sort_ready = (
                last_sort_score is not None
                and last_sort_score >= ITEM_SORT_RULE_MATCH_THRESHOLD
            )
            if title_ready or sort_ready:
                ready_streak += 1
                if ready_streak >= INVENTORY_FILTER_TITLE_STABLE_POLLS:
                    self._debug(
                        "  item filter menu ready "
                        f"title_score={'none' if last_title_score is None else f'{last_title_score:.3f}'} "
                        f"sort_score={'none' if last_sort_score is None else f'{last_sort_score:.3f}'}"
                    )
                    return True
            else:
                ready_streak = 0
            if not self._wait(poll):
                return False
        self.log(
            "  item filter menu open check failed "
            f"title_score={'none' if last_title_score is None else f'{last_title_score:.3f}'} "
            f"sort_score={'none' if last_sort_score is None else f'{last_sort_score:.3f}'}"
        )
        return False
    def _wait_for_equipment_inventory_filter_menu_open(
        self,
        *,
        timeout: float = INVENTORY_PANEL_OPEN_TIMEOUT,
        initial_wait: float = INVENTORY_FILTER_MENU_SETTLE_WAIT,
        poll: float = UI_FLAG_POLL,
    ) -> bool:
        if initial_wait > 0 and not self._wait(initial_wait):
            return False
        deadline = time.monotonic() + timeout
        ready_streak = 0
        last_title_score: float | None = None
        last_sort_score: float | None = None
        while time.monotonic() < deadline:
            if self._stop_requested():
                return False
            img = self._capture()
            last_title_score = self._inventory_filter_title_score(img)
            last_sort_score = self._region_capture_match_score("eq_sort_rule_check")
            title_ready = (
                last_title_score is not None
                and last_title_score >= INVENTORY_FILTER_TITLE_MIN_SCORE
            )
            sort_ready = (
                last_sort_score is not None
                and last_sort_score >= EQUIPMENT_SORT_RULE_MATCH_THRESHOLD
            )
            if title_ready or sort_ready:
                ready_streak += 1
                if ready_streak >= INVENTORY_FILTER_TITLE_STABLE_POLLS:
                    self._debug(
                        "  equipment filter menu ready "
                        f"title_score={'none' if last_title_score is None else f'{last_title_score:.3f}'} "
                        f"sort_score={'none' if last_sort_score is None else f'{last_sort_score:.3f}'}"
                    )
                    return True
            else:
                ready_streak = 0
            if not self._wait(poll):
                return False
        self.log(
            "  equipment filter menu open check failed "
            f"title_score={'none' if last_title_score is None else f'{last_title_score:.3f}'} "
            f"sort_score={'none' if last_sort_score is None else f'{last_sort_score:.3f}'}"
        )
        return False
    def _click_region_capture_and_wait_for_reference(
        self,
        click_name: str,
        reference_name: str,
        *,
        label: str = "",
        threshold: float = INVENTORY_PANEL_READY_THRESHOLD,
        timeout: float = INVENTORY_PANEL_OPEN_TIMEOUT,
        initial_wait: float = INVENTORY_FILTER_TAB_SETTLE_WAIT,
        max_attempts: int = INVENTORY_PANEL_OPEN_ATTEMPTS,
    ) -> bool:
        for attempt in range(1, max_attempts + 1):
            if not self._click_region_capture(click_name, label=label or click_name):
                return False
            if self._wait_for_region_capture_match(
                reference_name,
                threshold=threshold,
                timeout=timeout,
                initial_wait=initial_wait,
                poll=min(UI_FLAG_POLL, PANEL_TRANSITION_POLL),
            ):
                return True
            if attempt < max_attempts:
                self.log(
                    f"  {click_name} did not open expected panel "
                    f"({attempt}/{max_attempts}) -> retry"
                )
        return False
    def _open_inventory_filter_panel(
        self,
        click_name: str,
        *,
        label: str,
        timeout: float = INVENTORY_PANEL_OPEN_TIMEOUT,
        initial_wait: float = INVENTORY_FILTER_MENU_SETTLE_WAIT,
        max_attempts: int = 2,
    ) -> bool:
        for attempt in range(1, max_attempts + 1):
            if not self._click_region_capture(click_name, label=label or click_name):
                return False
            if self._wait_for_inventory_filter_menu_open(
                timeout=timeout,
                initial_wait=initial_wait,
                poll=min(UI_FLAG_POLL, PANEL_TRANSITION_POLL),
            ):
                return True
            if attempt < max_attempts:
                self.log(
                    f"  {click_name} did not open inventory filter menu "
                    f"({attempt}/{max_attempts}) -> retry"
                )
        self.log(f"  {label} failed: filter menu title was not recognized; stopping scan")
        self.stop()
        return False
    def _open_item_inventory_filter_panel(
        self,
        *,
        timeout: float = INVENTORY_PANEL_OPEN_TIMEOUT,
        initial_wait: float = INVENTORY_FILTER_MENU_SETTLE_WAIT,
        max_attempts: int = 2,
    ) -> bool:
        label = "filtermenu_button"
        for attempt in range(1, max_attempts + 1):
            if not self._click_region_capture("filtermenu_button", label=label):
                return False
            if self._wait_for_item_inventory_filter_menu_open(
                timeout=timeout,
                initial_wait=initial_wait,
                poll=min(UI_FLAG_POLL, PANEL_TRANSITION_POLL),
            ):
                return True
            if attempt < max_attempts:
                self.log(
                    f"  {label} did not open item filter menu "
                    f"({attempt}/{max_attempts}) -> retry"
                )
        self.log("  item filtermenu_button failed: item filter menu title was not recognized; stopping scan")
        self.stop()
        return False
    def _open_equipment_inventory_filter_panel(
        self,
        *,
        timeout: float = INVENTORY_PANEL_OPEN_TIMEOUT,
        initial_wait: float = INVENTORY_FILTER_MENU_SETTLE_WAIT,
        max_attempts: int = 2,
    ) -> bool:
        label = "eq_filtermenu_button"
        for attempt in range(1, max_attempts + 1):
            if not self._click_region_capture("eq_filtermenu_button", label=label):
                return False
            if self._wait_for_equipment_inventory_filter_menu_open(
                timeout=timeout,
                initial_wait=initial_wait,
                poll=min(UI_FLAG_POLL, PANEL_TRANSITION_POLL),
            ):
                return True
            if attempt < max_attempts:
                self.log(
                    f"  {label} did not open equipment filter menu "
                    f"({attempt}/{max_attempts}) -> retry"
                )
        self.log("  eq_filtermenu_button failed: equipment filter menu did not become ready; stopping scan")
        self.stop()
        return False
    def _click_inventory_tab(self, name: str, *, label: str = "") -> bool:
        """Select an inventory tab once and allow its content to settle."""
        return self._click_region_capture(
            name,
            label=label or name,
            delay=INVENTORY_FILTER_TAB_SETTLE_WAIT,
        )
    def _ensure_region_matches_reference(
        self,
        name: str,
        *,
        threshold: float = INVENTORY_SORT_RULE_MATCH_THRESHOLD,
        click_delay: float = DELAY_AFTER_CLICK,
        check_wait: float = INVENTORY_SORT_RULE_CHECK_WAIT,
        retry_wait: float = INVENTORY_SORT_RULE_RETRY_WAIT,
        max_attempts: int = INVENTORY_SORT_RULE_MAX_ATTEMPTS,
    ) -> bool:
        for attempt in range(1, max_attempts + 1):
            if check_wait > 0 and not self._wait(check_wait):
                return False
            score = self._region_capture_match_score(name)
            if score is None:
                self.log(f"  {name} reference unavailable -> skip check")
                return False
            self.log(f"  {name} match score={score:.3f} (attempt {attempt}/{max_attempts})")
            if score >= threshold:
                return True
            if attempt >= max_attempts:
                break
            self.log(f"  {name} mismatch -> clicking")
            if not self._click_region_capture(name, label=name, delay=click_delay):
                return False
            if retry_wait > 0 and not self._wait(retry_wait):
                return False
        self.log(f"  {name} did not reach threshold {threshold:.2f}")
        return False
    def _item_scan_profiles(
        self,
        inventory_profile_id: str | list[str] | tuple[str, ...] | None,
    ) -> tuple[str | None, ...]:
        requested = inventory_profile_id
        if requested is None:
            requested = self._default_inventory_profile_ids
        normalized = normalize_inventory_profile_ids(requested)
        if not normalized or normalized == ("all",):
            return (None,)
        return tuple(normalized)
    def _item_sort_rule_check_name(self, profile_id: str | None) -> str:
        if profile_id == "student_elephs":
            return "sort_name_rule_check"
        return "sort_rule_check"
    def _item_filter_menu_sort_tab_score(self, profile_id: str | None) -> float | None:
        names = [self._item_sort_rule_check_name(profile_id)]
        for fallback_name in ("sort_rule_check", "sort_name_rule_check"):
            if fallback_name not in names:
                names.append(fallback_name)
        best_score: float | None = None
        for name in names:
            score = self._region_capture_match_score(name)
            if score is None:
                continue
            if best_score is None or score > best_score:
                best_score = score
        return best_score
    def _ensure_item_inventory_filter_tab_active(self, profile_id: str | None) -> bool:
        sort_score = self._item_filter_menu_sort_tab_score(profile_id)
        if sort_score is not None and sort_score >= ITEM_SORT_RULE_MATCH_THRESHOLD:
            self.log(f"  item filter menu opened on sort tab score={sort_score:.3f} -> switching to filter tab")
            if not self._click_inventory_tab("filter_tab", label="filter_tab"):
                return False
            return True
        self._debug(
            "  item filter menu assumed on filter tab "
            f"sort_score={'none' if sort_score is None else f'{sort_score:.3f}'}"
        )
        return True
    def _prepare_item_inventory(self, profile_id: str | None, *, ensure_sort_rule: bool) -> bool:
        self.log(f"  item filter menu open (profile={profile_id or 'all'})")
        if not self._open_item_inventory_filter_panel(
            timeout=INVENTORY_PANEL_OPEN_TIMEOUT,
            initial_wait=INVENTORY_FILTER_MENU_SETTLE_WAIT,
            max_attempts=2,
        ):
            self.log("  item prepare failed: filter menu did not open")
            return False
        if not self._ensure_item_inventory_filter_tab_active(profile_id):
            self.log("  item prepare failed: filter_tab activation failed")
            return False
        if not self._click_region_capture(
            "filter_reset_button",
            label="filter_reset_button",
            delay=INVENTORY_FILTER_TAB_SETTLE_WAIT,
        ):
            self.log("  item prepare failed: filter_reset_button click failed")
            return False

        filter_button_by_profile = {
            "student_elephs": "eleph_filter",
            "tech_notes": "note_filter",
            "tactical_bd": "bd_filter",
            "ooparts": "ooparts_filter",
            "activity_reports": "reports_filter",
        }
        if profile_id == "presents":
            filter_button = "presents_filter(ooparts_x,note_y)"
            self.log(f"  item filter select: {filter_button}")
            if not self._click_region_capture_x_from_y(
                "ooparts_filter",
                "note_filter",
                label="presents_filter",
                delay=INVENTORY_FILTER_TAB_SETTLE_WAIT,
            ):
                self.log(f"  item prepare failed: {filter_button} click failed")
                return False
        else:
            filter_button = filter_button_by_profile.get(profile_id or "")
            if filter_button:
                self.log(f"  item filter select: {filter_button}")
                if not self._click_region_capture(
                    filter_button,
                    label=filter_button,
                    delay=INVENTORY_FILTER_TAB_SETTLE_WAIT,
                ):
                    self.log(f"  item prepare failed: {filter_button} click failed")
                    return False

        if not self._click_inventory_tab("sort_tab", label="sort_tab"):
            self.log("  item prepare failed: sort_tab click failed")
            return False
        sort_rule_check = self._item_sort_rule_check_name(profile_id)
        if not self._ensure_region_matches_reference(
            sort_rule_check,
            threshold=ITEM_SORT_RULE_MATCH_THRESHOLD,
        ):
            self.log(f"  item prepare failed: {sort_rule_check} mismatch")
            return False

        if not self._click_region_capture(
            "filter_confirm_button",
            label="filter_confirm_button",
            delay=INVENTORY_FILTER_CONFIRM_WAIT,
        ):
            self.log("  item prepare failed: filter_confirm_button click failed")
            return False
        return self._wait(INVENTORY_FILTER_CONFIRM_WAIT)
    def _prepare_equipment_inventory(self) -> bool:
        self.log("  equipment filter menu open")
        if not self._open_equipment_inventory_filter_panel(
            timeout=INVENTORY_PANEL_OPEN_TIMEOUT,
            initial_wait=INVENTORY_FILTER_MENU_SETTLE_WAIT,
            max_attempts=2,
        ):
            self.log("  equipment prepare failed: filter panel did not open")
            return False
        if not self._ensure_region_matches_reference(
            "eq_sort_rule_check",
            threshold=EQUIPMENT_SORT_RULE_MATCH_THRESHOLD,
        ):
            self.log("  equipment prepare failed: eq_sort_rule_check mismatch")
            return False
        if not self._click_region_capture(
            "eq_filter_confirm_button",
            label="eq_filter_confirm_button",
            delay=INVENTORY_FILTER_CONFIRM_WAIT,
        ):
            self.log("  equipment prepare failed: eq_filter_confirm_button click failed")
            return False
        return self._wait(INVENTORY_FILTER_CONFIRM_WAIT)
    def _reset_inventory_scan_state(self, source: str) -> None:
        self._inventory_icon_cache[source] = {}
        self._inventory_failed_hashes[source] = set()
        self._inventory_motion_row_step_px = None
    def _close_inventory_menu(self) -> bool:
        menu_back = self.r.get("menu", {}).get("backbutton")
        if not menu_back:
            self.log("warning: missing menu backbutton")
            return False
        if not self._click_r(menu_back, "menu_backbutton"):
            return False
        return self._wait(0.2)
    def _go_home_from_inventory(self) -> bool:
        return self._click_region_capture("home", label="home", delay=0.35)
    def _exit_inventory_to_menu(self) -> bool:
        if not self._close_inventory_menu():
            return False
        if not self._go_home_from_inventory():
            return False
        if not self._open_menu():
            return False
        return self._wait(1.0)
    def _return_inventory_to_lobby(self) -> None:
        self.log("?????????????????????????????⑤벡???????????????????????????????????????꾩룆梨띰쭕?뚢뵾??????????????嶺뚮죭?댁젘??????????????????????釉먮폁???????????????????살몝????...")
        if not self._close_inventory_menu():
            return
        self._go_home_from_inventory()
    def scan_resources(self) -> dict:
        self.log("???????????????????????????..")
        img = self._capture()
        if img is None:
            return {}

        lobby_r = self.r["lobby"]
        result: dict = {}

        ocr.load()
        try:
            for key, rk in [("credit", "credit_region"),
                             ("pyroxene", "pyroxene_region")]: 
                try:
                    crop = crop_region(img, lobby_r[rk])
                    result[key] = ocr.read_item_count(crop)
                except Exception as e:
                    result[key] = None
                    _log.warning(f"?????OCR ?????????????????????????곕춴??????({key}): {type(e).__name__}: {e}")
        finally:
            ocr.unload()

        self.log(f"Lobby OCR: pyroxene={result.get('pyroxene', '-')} credit={result.get('credit', '-')}")
        return result
    def _open_menu(self) -> bool:
        rect = self._rect()
        if not rect:
            return False
        self.log("??????????????????????????????????????????????..")
        self._click_r(self.r["lobby"]["menu_button"], "menu_button")
        return self._wait(0.7)
    def _go_to(self, btn_key: str, label: str) -> bool:
        btn = self.r["menu"].get(btn_key)
        if not btn:
            self.log(f"warning: {label} button region missing")
            return False
        self.log(f"  {label} ????????????????..")
        self._click_r(btn, label)
        return self._wait(1.0)
    def _return_lobby(self) -> None:
        self.log("?????????????????????????????⑤벡???????????????????????????????????????꾩룆梨띰쭕?뚢뵾??????????????嶺뚮죭?댁젘??????????????????????釉먮폁???????????????????살몝????...")
        back = (
            self.r.get("student_menu", {}).get("backbutton")
            or self.r.get("menu", {}).get("backbutton")
        )
        for attempt in range(4):
            if self._stop_requested():
                return
            img = self._capture()
            if self._is_lobby_capture(img):
                return
            if self._close_active_student_panel(wait=PANEL_CLOSE_SETTLE_WAIT):
                continue
            if back and self._click_r(back, f"student_backbutton_{attempt + 1}"):
                if not self._wait(0.8):
                    return
                continue
            break
        self.log("  warning: ?????????????????????????????⑤벡???????????????????????????????????????꾩룆梨띰쭕?뚢뵾??????????????嶺뚮죭?댁젘??????????????????????釉먮폁???????????????????살몝???? ?????????????????????????????????거?????????????⑤벡瑜???饔낅떽???????멸괜????????????????????????????????????????곕춴??????-> ESC 1??fallback")
        self._esc()
    def _capture_inventory_page(
        self,
        img: Image.Image,
        slots: list[dict],
        *,
        grid_hash: str,
        page_index: int,
        grid_cols: int,
    ) -> InventoryPageSnapshot:
        slot_snaps: list[InventorySlotSnapshot] = []
        for idx, slot in enumerate(slots):
            icon_crop = crop_region(img, _slot_icon_region(slot))
            slot_snaps.append(
                InventorySlotSnapshot(
                    slot_index=idx,
                    icon_hash=_img_hash(icon_crop),
                )
            )
        last_row_hashes = [s.icon_hash for s in slot_snaps[-grid_cols:]] if grid_cols > 0 else []
        return InventoryPageSnapshot(
            page_index=page_index,
            grid_hash=grid_hash,
            last_row_hashes=last_row_hashes,
            slots=slot_snaps,
        )
    def _verify_inventory_slot(
        self,
        rect: tuple[int, int, int, int],
        slot: dict,
        name_r: dict,
        count_r: dict,
        source: str,
        profile_id: str | None = None,
        input_backend: InventoryGridInput | None = None,
        slot_index: int | None = None,
        count_fallback: InventoryVerification | None = None,
    ) -> InventoryVerification | None:
        self._debug(
            f"    verify slot: source={source} profile={profile_id or '-'} "
            f"slot=({slot.get('x1', 0):.3f},{slot.get('y1', 0):.3f},"
            f"{slot.get('x2', 0):.3f},{slot.get('y2', 0):.3f})"
        )
        if input_backend is not None:
            if slot_index is None:
                self._debug("    verify failed: missing input slot index")
                return None
            input_backend.move_to_slot(slot_index)
            input_backend.confirm_slot()
            self._debug(
                f"    verify slot via {input_backend.backend_name}: "
                f"slot_index={slot_index}"
            )
        else:
            click_point = _inventory_slot_safe_click_point(slot)
            if click_point is None:
                self._debug("    verify failed: slot has no allowed click point")
                return None
            click_rx, click_ry = click_point
            if not safe_click(rect, click_rx, click_ry, f"{source}_slot"):
                self._debug(
                    f"    verify failed: slot click rejected at ({click_rx:.3f},{click_ry:.3f})"
                )
                return None
        if not self._wait(DELAY_AFTER_CLICK):
            return None

        img2 = self._capture()
        if img2 is None:
            self._debug("    verify failed: detail capture failed")
            return None
        if input_backend is not None and os.environ.get("BA_INVENTORY_VCON_SLOT_DEBUG") == "1":
            try:
                debug_dir = BASE_DIR / "debug" / "inventory_vcon_slots"
                debug_dir.mkdir(parents=True, exist_ok=True)
                safe_profile = (profile_id or source or "inventory").replace("/", "_").replace("\\", "_")
                safe_slot = slot_index if slot_index is not None else "unknown"
                img2.save(debug_dir / f"{source}_{safe_profile}_slot{safe_slot}_{int(time.time() * 1000)}.png")
            except Exception:
                _log.debug("failed to save vcon slot debug capture", exc_info=True)

        count = ""
        if source == "item" or profile_id:
            count_match = None
            if source == "equipment" or profile_id == "equipment":
                count_match = read_equipment_count_from_detail(img2)
                if (
                    count_match.value is None
                    and count_match.reason in ("no_x_templates", "missing_digit_templates")
                ):
                    self.log(
                        "    equipment count fallback -> item templates "
                        f"(reason={count_match.reason})"
                    )
                    count_match = read_item_count_from_detail(img2)
            else:
                count_match = read_item_count_from_detail(img2)
            if count_match.value is not None:
                count = count_match.value
                self.log(
                    f"    count template matched: {count} "
                    f"(digits={count_match.digit_count}, conf={count_match.confidence:.2f})"
                )
            else:
                self.log(
                    f"    count template fallback: reason={count_match.reason} "
                    f"(digits={count_match.digit_count}, conf={count_match.confidence:.2f})"
                )
            if not count:
                if (
                    count_fallback is not None
                    and count_match is not None
                    and str(count_match.reason).startswith("weak_x_match")
                ):
                    self.log(
                        "    detail count weak_x_match -> grid template/count fallback"
                    )
                    return count_fallback
                self._debug("    verify failed: count unresolved")
                return None
            matched_item_id = None
            matched_score = 0.0
            detail_crop = self._inventory_detail_crop(img2, profile_id) if profile_id else None
            detail_name_crop = self._inventory_detail_name_crop(img2, source) if profile_id else None
            if profile_id:
                matched_item_id, matched_score = self._match_inventory_detail_crop(
                    detail_crop,
                    profile_id,
                    detail_name_crop,
                )
                if matched_item_id:
                    self.log(
                        f"    detail template matched: {matched_item_id} "
                        f"(score={matched_score:.2f})"
                    )
                else:
                    self._debug(
                        f"    detail template unresolved "
                        f"(best_score={matched_score:.2f}, profile={profile_id})"
                    )
            return InventoryVerification(
                name=None,
                count=count,
                item_id=matched_item_id,
                match_score=matched_score,
                detail_crop=detail_crop,
                detail_name_crop=detail_name_crop,
            )
        self.log("    detail template fallback disabled: profile/template match required")
        return None
    def _match_inventory_icon(
        self,
        icon_crop: Image.Image,
        source: str,
        profile_id: str | None = None,
    ) -> tuple[str | None, float]:
        best_item_id: str | None = None
        best_score = 0.0
        for item_id, path in inventory_profile_template_catalog(source, profile_id):
            score = match_score_resized_raw(icon_crop, path)
            if score > best_score:
                best_score = score
                best_item_id = item_id
        threshold = 0.84 if source == "equipment" else 0.80
        if best_score < threshold:
            return None, best_score
        return best_item_id, best_score
    def _inventory_detail_crop(
        self,
        image: Image.Image,
        profile_id: str | None,
    ) -> Image.Image | None:
        region = _inventory_detail_template_region(profile_id)
        if region is None:
            return None
        return crop_region(image, region)
    def _inventory_detail_name_crop(
        self,
        image: Image.Image,
        source: str,
    ) -> Image.Image | None:
        region = _inventory_detail_name_template_region(source)
        if region is None:
            return None
        return crop_region(image, region)
    def _inventory_detail_template_catalog_for_scan(
        self,
        profile_id: str | None,
    ) -> list[tuple[str, str]]:
        base_catalog = _inventory_detail_template_catalog(profile_id)
        if not profile_id or self._inventory_detail_override_dir is None:
            return base_catalog

        samples = resolution_sample_catalog(
            self._inventory_detail_override_dir,
            self._inventory_capture_resolution,
            profile_id,
        )
        # Compatibility fallback for confirmed templates saved before samples
        # were separated by capture resolution.
        legacy_base = self._inventory_detail_override_dir / profile_id
        for png in sorted(legacy_base.glob("*.png")):
            samples.setdefault(png.stem, [str(png)])
        return merge_answer_samples(
            base_catalog,
            samples,
            excluded_prefixes=("Equipment_Icon_WeaponExpGrowth",),
        )
    def _inventory_detail_name_template_catalog_for_scan(
        self,
        profile_id: str | None,
    ) -> list[tuple[str, str]]:
        base_catalog = _inventory_detail_name_template_catalog(profile_id)
        if not profile_id or self._inventory_detail_override_dir is None:
            return base_catalog

        name_root = self._inventory_detail_override_dir.parent / "inventory_detail_names"
        samples = resolution_sample_catalog(
            name_root,
            self._inventory_capture_resolution,
            profile_id,
        )
        legacy_base = name_root / profile_id
        for png in sorted(legacy_base.glob("*.png")):
            samples.setdefault(png.stem, [str(png)])
        return merge_answer_samples(base_catalog, samples)
    def _match_inventory_detail_name_crop(
        self,
        crop: Image.Image | None,
        profile_id: str | None,
    ) -> tuple[str | None, float]:
        if crop is None:
            return None, 0.0
        catalog = self._inventory_detail_name_template_catalog_for_scan(profile_id)
        if not catalog:
            return None, 0.0

        scores_by_id: dict[str, float] = {}
        for item_id, path in catalog:
            score = match_score_textonly(crop, path)
            scores_by_id[item_id] = max(scores_by_id.get(item_id, 0.0), score)

        ranked = sorted(scores_by_id.items(), key=lambda row: row[1], reverse=True)
        best_item_id, best_score = ranked[0] if ranked else (None, 0.0)
        second_best = ranked[1][1] if len(ranked) > 1 else 0.0

        if best_score < 0.72 or (best_score - second_best) < 0.02:
            return None, best_score
        return best_item_id, best_score
    def _match_inventory_detail_crop(
        self,
        crop: Image.Image | None,
        profile_id: str | None,
        name_crop: Image.Image | None = None,
    ) -> tuple[str | None, float]:
        if crop is None:
            return None, 0.0
        catalog = self._inventory_detail_template_catalog_for_scan(profile_id)
        if not catalog:
            return None, 0.0
        name_catalog: dict[str, list[str]] = {}
        for item_id, path in self._inventory_detail_name_template_catalog_for_scan(profile_id):
            name_catalog.setdefault(item_id, []).append(path)

        scores_by_id: dict[str, float] = {}
        family_top_scores: dict[str, list[tuple[str, float]]] = {}
        for item_id, path in catalog:
            icon_score = match_score_resized_raw(crop, path)
            name_score = 0.0
            if name_crop is not None:
                for name_path in name_catalog.get(item_id, ()):
                    name_score = max(name_score, match_score_textonly(name_crop, name_path))
            score = _combine_inventory_detail_scores(icon_score, name_score)
            scores_by_id[item_id] = max(scores_by_id.get(item_id, 0.0), score)

        ranked = sorted(scores_by_id.items(), key=lambda row: row[1], reverse=True)
        best_item_id, best_score = ranked[0] if ranked else (None, 0.0)
        second_best = ranked[1][1] if len(ranked) > 1 else 0.0
        for item_id, score in scores_by_id.items():
            family_key = _inventory_detail_strict_family(item_id)
            if family_key is not None:
                top_scores = family_top_scores.setdefault(family_key, [])
                top_scores.append((item_id, score))
        for top_scores in family_top_scores.values():
            top_scores.sort(key=lambda row: row[1], reverse=True)
            del top_scores[4:]

        if best_score < 0.88 or (best_score - second_best) < 0.015:
            return None, best_score

        strict_family = _inventory_detail_strict_family(best_item_id)
        if strict_family is not None:
            family_threshold, overall_margin_threshold, family_margin_threshold = (
                STRICT_DETAIL_FAMILY_THRESHOLDS[strict_family]
            )
            family_second_best = 0.0
            for item_id, score in family_top_scores.get(strict_family, []):
                if item_id != best_item_id:
                    family_second_best = score
                    break
            overall_margin = best_score - second_best
            family_margin = best_score - family_second_best
            if (
                best_score < family_threshold
                or overall_margin < overall_margin_threshold
                or family_margin < family_margin_threshold
            ):
                self.log(
                    f"    detail template ambiguous reject: {best_item_id} "
                    f"(score={best_score:.2f}, overall_margin={overall_margin:.3f}, "
                    f"family_margin={family_margin:.3f})"
                )
                return None, best_score
        return best_item_id, best_score
    def _match_inventory_detail_template(
        self,
        image: Image.Image,
        profile_id: str | None,
    ) -> tuple[str | None, float]:
        return self._match_inventory_detail_crop(
            self._inventory_detail_crop(image, profile_id),
            profile_id,
            self._inventory_detail_name_crop(image, profile_id or "item"),
        )
    def _fill_missing_profile_entries(
        self,
        items: list[ItemEntry],
        profile,
        source: str,
    ) -> list[ItemEntry]:
        ordered_names = list(profile.ordered_names)
        ordered_item_ids = list(inventory_profile_ordered_item_ids(profile))
        if not ordered_names:
            return items

        def _entry_rank(entry: ItemEntry) -> tuple[int, int, int]:
            quantity = str(entry.quantity or "").strip()
            has_nonzero_quantity = int(quantity not in ("", "0"))
            has_item_id = int(bool(entry.item_id))
            quantity_len = len(quantity)
            return (has_nonzero_quantity, has_item_id, quantity_len)

        by_item_id: dict[str, ItemEntry] = {}
        by_name: dict[str, ItemEntry] = {}
        unmatched: list[ItemEntry] = []
        for entry in items:
            if entry.item_id:
                prev = by_item_id.get(entry.item_id)
                if prev is None or _entry_rank(entry) > _entry_rank(prev):
                    if prev is not None:
                        unmatched.append(prev)
                    by_item_id[entry.item_id] = entry
                else:
                    unmatched.append(entry)
                continue
            if entry.name:
                prev = by_name.get(entry.name)
                if prev is None or _entry_rank(entry) > _entry_rank(prev):
                    if prev is not None:
                        unmatched.append(prev)
                    by_name[entry.name] = entry
                else:
                    unmatched.append(entry)
                continue
            unmatched.append(entry)

        rebuilt: list[ItemEntry] = []
        for idx, expected_name in enumerate(ordered_names):
            expected_item_id = ordered_item_ids[idx] if idx < len(ordered_item_ids) else None
            matched = None
            if expected_item_id:
                matched = by_item_id.pop(expected_item_id, None)
            if matched is None and expected_name:
                matched = by_name.pop(expected_name, None)
            if matched is None:
                continue
            matched.name = expected_name or matched.name
            matched.item_id = expected_item_id or matched.item_id
            matched.index = idx
            rebuilt.append(matched)

        tail = [entry for entry in items if entry not in rebuilt]
        for idx, entry in enumerate(tail, start=len(rebuilt)):
            entry.index = idx
        return rebuilt + tail
    def _append_profile_gap_entries(
        self,
        items: list[ItemEntry],
        seen_keys: set[str],
        profile_seen_names: set[str],
        profile,
        ordered_names: list[str],
        ordered_item_ids: list[str | None],
        source: str,
        start_idx: int,
        end_idx: int,
    ) -> int:
        if end_idx <= start_idx:
            return 0
        end_idx = min(end_idx, len(ordered_names))
        self.log(
            f"  profile gap zero-fill: start={start_idx} end={end_idx}"
        )
        added = 0
        for profile_idx in range(max(0, start_idx), end_idx):
            expected_name = ordered_names[profile_idx]
            expected_item_id = (
                ordered_item_ids[profile_idx]
                if profile_idx < len(ordered_item_ids)
                else None
            )
            if not expected_name and not expected_item_id:
                continue
            entry = ItemEntry(
                name=expected_name,
                quantity="0",
                item_id=expected_item_id,
                source=source,
                index=len(items),
                scan_meta={
                    "status": "zero_filled",
                    "reason": "profile_order_gap",
                    "profile_id": profile.profile_id,
                    "profile_index": profile_idx,
                    "review_required": False,
                },
            )
            key = entry.key()
            if key in seen_keys:
                continue
            seen_keys.add(key)
            if entry.name:
                profile_seen_names.add(entry.name)
            items.append(entry)
            added += 1
        return added
    def _scroll_inventory_page(
        self,
        rect: tuple[int, int, int, int],
        slots: list[dict],
        grid_r: dict,
        drag_config: InventoryDragConfig,
        scroll_amount: int,
        grid_cols: int,
        scroll_index: int = 0,
        debug_dir: Path | None = None,
        before_y_offset_px: int = 0,
        drag_rx_offset: float = 0.0,
        focus_anchor_before_capture: bool = False,
    ) -> tuple[bool, Optional[InventoryPageSnapshot], int, int, int]:
        self._last_inventory_tail_page_detected = False
        focus_anchor_clicked = False
        pre_capture_cursor_moved = False
        if focus_anchor_before_capture:
            focus_anchor_clicked = _click_inventory_focus_anchor_slot(rect, slots)
            if focus_anchor_clicked:
                self._debug("  focus anchor clicked on inventory slot 1 before capture")
            pre_capture_cursor_moved = _move_cursor_away_from_inventory_grid(rect)
            if pre_capture_cursor_moved:
                self._debug("  cursor moved away from inventory grid before pre-drag capture")
            if (focus_anchor_clicked or pre_capture_cursor_moved) and not self._wait(0.18):
                return False, None, scroll_amount, 0, before_y_offset_px
        before_img = self._capture()
        before_slots = (
            _shift_slots_y(slots, before_y_offset_px, before_img.size)
            if before_img is not None and before_y_offset_px
            else slots
        )
        before_grid_r = _grid_region(before_slots) if before_img is not None and before_y_offset_px else grid_r
        before = crop_region(before_img, before_grid_r) if before_img else None
        before_grid_hash = _img_hash(before) if before is not None else ""
        before_page = self._capture_inventory_page(
            before_img,
            before_slots,
            grid_hash=before_grid_hash,
            page_index=-1,
            grid_cols=grid_cols,
        ) if before_img is not None else None
        next_amount = scroll_amount
        start_rx = drag_config.start_rx + drag_rx_offset
        start_ry = drag_config.start_ry
        if abs(drag_rx_offset) >= 0.0001:
            self._debug(
                f"  drag x offset: rx={start_rx:.6f} "
                f"base={drag_config.start_rx:.6f} offset={drag_rx_offset:+.6f}"
            )
        retry_amount = int(scroll_amount * drag_config.retry_scale)
        attempts = [scroll_amount, retry_amount]

        for idx, amount in enumerate(attempts, start=1):
            end_ry = start_ry + drag_config.delta_ry(amount)
            start_rx_clamped = max(0.02, min(0.98, start_rx))
            start_ry_clamped = max(0.02, min(0.98, start_ry))
            end_ry_clamped = max(0.02, min(0.98, end_ry))
            scroll_ok = drag_scroll(
                find_target_hwnd(),
                rect,
                start_rx_clamped,
                start_ry_clamped,
                end_ry_clamped,
                delay=0.35,
                duration=drag_config.duration,
                end_hold=drag_config.end_hold,
            )
            self.log(
                f"  drag try {idx}: start=({start_rx_clamped:.6f},{start_ry_clamped:.6f}) "
                f"end=({start_rx_clamped:.6f},{end_ry_clamped:.6f}) "
                f"delta_px={amount} duration={drag_config.duration:.2f} ok={scroll_ok}"
            )
            post_drag_cursor_moved = _move_cursor_away_from_inventory_grid(rect)
            cursor_moved = bool(pre_capture_cursor_moved or post_drag_cursor_moved)
            if post_drag_cursor_moved:
                self._debug("  drag cursor moved away from inventory grid before capture")
            if not self._wait(0.18):
                return False, None, next_amount, 0, before_y_offset_px

            after_img = self._capture()
            if after_img is None:
                return scroll_ok, None, next_amount, 0, before_y_offset_px
            grid_rows = max(1, (len(slots) + grid_cols - 1) // max(1, grid_cols))
            row_step_px = _slot_row_step_px(before_slots, after_img.size, grid_cols)
            settled_img, settled_gray_layout, settle_captures = self._capture_settled_inventory_scroll_frame(
                after_img,
                slots,
                grid_cols=grid_cols,
                grid_rows=grid_rows,
                row_step_px=row_step_px,
            )
            if settled_img is None:
                self.log(
                    f"  drag try {idx}: grid did not settle after {settle_captures} captures "
                    "-> stopping without motion estimation"
                )
                return False, None, next_amount, 0, before_y_offset_px
            after_img = settled_img
            self.log(f"  drag try {idx}: grid settled after {settle_captures} verification captures")
            after = crop_region(after_img, before_grid_r)
            after_grid_hash = _img_hash(after)
            after_page = self._capture_inventory_page(
                after_img,
                before_slots,
                grid_hash=after_grid_hash,
                page_index=-1,
                grid_cols=grid_cols,
            )
            before_hashes = [snap.icon_hash for snap in before_page.slots] if before_page is not None else []
            after_hashes = [snap.icon_hash for snap in after_page.slots]
            image_changed = before is None or not _images_similar(before, after)
            hash_changed = before_grid_hash != after_grid_hash
            slot_sequence_changed = before_hashes != after_hashes
            moved = image_changed or hash_changed or slot_sequence_changed
            self.log(
                f"  drag try {idx}: moved={moved} "
                f"(image_changed={image_changed}, hash_changed={hash_changed}, "
                f"slot_sequence_changed={slot_sequence_changed})"
            )
            if moved:
                base_row_step_px = _slot_row_step_px(before_slots, after_img.size, grid_cols)
                calibrated_row_step_px = getattr(self, "_inventory_motion_row_step_px", None)
                row_step_px = base_row_step_px
                if calibrated_row_step_px is not None and base_row_step_px > 0:
                    calibrated_int = int(round(float(calibrated_row_step_px)))
                    if int(round(base_row_step_px * 0.97)) <= calibrated_int <= int(round(base_row_step_px * 1.03)):
                        row_step_px = calibrated_int
                expected_move_px = min(abs(amount), row_step_px * max(1, grid_rows - 1)) if row_step_px > 0 else abs(amount)
                search_margin_px = max(50, row_step_px * max(1, grid_rows - 1)) if row_step_px > 0 else 50
                motion = _estimate_inventory_scroll_motion(
                    before_img,
                    after_img,
                    before_grid_r,
                    expected_move_px,
                    search_margin_px=search_margin_px,
                    slots=before_slots,
                ) if before_img is not None else None
                motion_overlap = _inventory_overlap_rows_from_motion(motion, row_step_px, grid_rows)
                if (
                    before_img is not None
                    and motion is not None
                    and motion_overlap is not None
                    and row_step_px > 0
                ):
                    _initial_overlap_rows, initial_moved_rows, _initial_y_delta, initial_tail_scroll = motion_overlap
                    initial_raw_y_delta = int(round((initial_moved_rows * row_step_px) - motion.actual_move_px))
                    residual_limit = _inventory_normal_residual_limit_px(row_step_px)
                    residual_carry_limit = _inventory_normal_residual_carry_limit_px(row_step_px)
                    should_recheck_residual = (
                        not initial_tail_scroll
                        and initial_moved_rows > 0
                        and motion.score >= INVENTORY_SCROLL_RESIDUAL_MIN_SCORE
                        and abs(initial_raw_y_delta) > residual_limit
                        and abs(initial_raw_y_delta) <= residual_carry_limit
                    )
                    if should_recheck_residual:
                        self.log(
                            f"  drag try {idx}: normal residual {initial_raw_y_delta:+d}px "
                            f"> limit {residual_limit}px -> settle recheck"
                        )
                        if self._wait(INVENTORY_SCROLL_RESIDUAL_SETTLE_WAIT):
                            settled_img = self._capture()
                            if settled_img is not None:
                                settled_after = crop_region(settled_img, before_grid_r)
                                settled_after_grid_hash = _img_hash(settled_after)
                                settled_after_page = self._capture_inventory_page(
                                    settled_img,
                                    before_slots,
                                    grid_hash=settled_after_grid_hash,
                                    page_index=-1,
                                    grid_cols=grid_cols,
                                )
                                settled_after_hashes = [snap.icon_hash for snap in settled_after_page.slots]
                                settled_motion = _estimate_inventory_scroll_motion(
                                    before_img,
                                    settled_img,
                                    before_grid_r,
                                    expected_move_px,
                                    search_margin_px=search_margin_px,
                                    slots=before_slots,
                                )
                                settled_overlap = _inventory_overlap_rows_from_motion(
                                    settled_motion,
                                    row_step_px,
                                    grid_rows,
                                )
                                if settled_motion is not None and settled_overlap is not None:
                                    (
                                        _settled_overlap_rows,
                                        settled_moved_rows,
                                        settled_y_delta,
                                        settled_tail_scroll,
                                    ) = settled_overlap
                                    settled_raw_y_delta = int(
                                        round((settled_moved_rows * row_step_px) - settled_motion.actual_move_px)
                                    )
                                    same_direction = (
                                        initial_raw_y_delta == 0
                                        or settled_raw_y_delta == 0
                                        or (initial_raw_y_delta > 0) == (settled_raw_y_delta > 0)
                                    )
                                    carry_settled_residual = (
                                        not settled_tail_scroll
                                        and settled_moved_rows == initial_moved_rows
                                        and same_direction
                                        and settled_motion.score >= INVENTORY_SCROLL_RESIDUAL_MIN_SCORE
                                        and abs(settled_raw_y_delta) > residual_limit
                                        and abs(settled_raw_y_delta) <= residual_carry_limit
                                    )
                                    if carry_settled_residual:
                                        settled_overlap = _inventory_overlap_rows_from_motion(
                                            settled_motion,
                                            row_step_px,
                                            grid_rows,
                                            carry_normal_offset=True,
                                        )
                                        if settled_overlap is not None:
                                            settled_y_delta = settled_overlap[2]
                                    action = "carry" if carry_settled_residual else "settled"
                                    self.log(
                                        f"  drag try {idx}: residual recheck actual={settled_motion.actual_move_px}px "
                                        f"raw_y_delta={settled_raw_y_delta:+d}px "
                                        f"y_delta={settled_y_delta:+d}px action={action} "
                                        f"score={settled_motion.score:.3f}"
                                    )
                                    after_img = settled_img
                                    after = settled_after
                                    after_grid_hash = settled_after_grid_hash
                                    after_page = settled_after_page
                                    after_hashes = settled_after_hashes
                                    image_changed = before is None or not _images_similar(before, after)
                                    hash_changed = before_grid_hash != after_grid_hash
                                    slot_sequence_changed = before_hashes != after_hashes
                                    moved = image_changed or hash_changed or slot_sequence_changed
                                    motion = settled_motion
                                    motion_overlap = settled_overlap
                moved_rows: int | None = None
                tail_scroll = False
                y_offset_refinement = None
                if motion_overlap is not None:
                    motion_overlap, hash_overlap_recovered = _reconcile_inventory_scroll_overlap(
                        motion_overlap,
                        before_hashes,
                        after_hashes,
                        grid_cols=grid_cols,
                        grid_rows=grid_rows,
                    )
                    overlap_rows, moved_rows, y_offset_delta_px, tail_scroll = motion_overlap
                    if hash_overlap_recovered:
                        self.log(
                            f"  drag try {idx}: motion overlap recovered by slot hashes "
                            f"moved_rows={moved_rows} overlap_rows={overlap_rows}"
                        )
                    digit_vote = None
                    if (
                        before_img is not None
                        and moved_rows is not None
                        and moved_rows > 0
                        and overlap_rows > 0
                        and not tail_scroll
                    ):
                        digit_vote = _estimate_inventory_overlap_digit_y_delta(
                            before_img,
                            after_img,
                            slots,
                            before_y_offset_px=before_y_offset_px,
                            grid_cols=grid_cols,
                            grid_rows=grid_rows,
                            row_step_px=row_step_px,
                            moved_rows=moved_rows,
                            refine_radius_px=4,
                        )
                        if (
                            digit_vote is not None
                            and int(digit_vote["dominant_count"]) >= min(4, int(digit_vote["slot_count"]))
                            and float(digit_vote["dominant_mean_score"]) >= 0.55
                        ):
                            old_y_delta = y_offset_delta_px
                            y_offset_delta_px = int(digit_vote["dominant_delta_y_offset_px"])
                            y_offset_refinement = {
                                "method": digit_vote["method"],
                                "previous_delta_y_offset_px": old_y_delta,
                                "applied_delta_y_offset_px": y_offset_delta_px,
                                "dominant_count": int(digit_vote["dominant_count"]),
                                "slot_count": int(digit_vote["slot_count"]),
                                "confidence": float(digit_vote["confidence"]),
                                "dominant_mean_score": float(digit_vote["dominant_mean_score"]),
                            }
                            self.log(
                                f"  drag try {idx}: digit vote y_delta {old_y_delta:+d}px -> "
                                f"{y_offset_delta_px:+d}px count={digit_vote['dominant_count']}/"
                                f"{digit_vote['slot_count']} score={digit_vote['dominant_mean_score']:.3f}"
                            )
                    y_offset_px = before_y_offset_px + y_offset_delta_px
                    self.log(
                        f"  drag try {idx}: motion actual={motion.actual_move_px}px "
                        f"expected={motion.expected_step_px}px row_step={row_step_px}px "
                        f"moved_rows={moved_rows} overlap_rows={overlap_rows} tail={tail_scroll} "
                        f"before_y={before_y_offset_px:+d}px y_delta={y_offset_delta_px:+d}px "
                        f"y_offset={y_offset_px:+d}px score={motion.score:.3f} method={motion.method}"
                    )
                    if (
                        motion is not None
                        and moved_rows is not None
                        and moved_rows > 0
                        and not tail_scroll
                        and motion.score >= 0.70
                        and base_row_step_px > 0
                    ):
                        observed_row_step = motion.actual_move_px / max(1, moved_rows)
                        if base_row_step_px * 0.97 <= observed_row_step <= base_row_step_px * 1.03:
                            previous_row_step = getattr(self, "_inventory_motion_row_step_px", None)
                            if previous_row_step is None:
                                updated_row_step = observed_row_step
                            else:
                                updated_row_step = (float(previous_row_step) * 0.65) + (observed_row_step * 0.35)
                            self._inventory_motion_row_step_px = updated_row_step
                            self.log(
                                f"  drag try {idx}: observed row_step={observed_row_step:.2f}px "
                                f"calibrated={updated_row_step:.2f}px base={base_row_step_px}px"
                            )
                else:
                    if (
                        motion is not None
                        and row_step_px > 0
                        and motion.actual_move_px < row_step_px * 0.35
                    ):
                        verified_motion = (
                            _verify_inventory_near_zero_motion(
                                before_img,
                                after_img,
                                before_grid_r,
                                expected_move_px,
                                row_step_px,
                                motion,
                                slots=before_slots,
                            )
                            if before_img is not None
                            else None
                        )
                        if verified_motion is None and before_img is not None:
                            self.log(
                                f"  drag try {idx}: near-zero motion actual={motion.actual_move_px}px "
                                f"row_step={row_step_px}px -> verify recapture"
                            )
                            if self._wait(INVENTORY_SCROLL_NEAR_ZERO_VERIFY_WAIT):
                                verified_img = self._capture()
                                if verified_img is not None:
                                    verified_after = crop_region(verified_img, before_grid_r)
                                    verified_after_grid_hash = _img_hash(verified_after)
                                    verified_after_page = self._capture_inventory_page(
                                        verified_img,
                                        before_slots,
                                        grid_hash=verified_after_grid_hash,
                                        page_index=-1,
                                        grid_cols=grid_cols,
                                    )
                                    verified_after_hashes = [snap.icon_hash for snap in verified_after_page.slots]
                                    recaptured_motion = _estimate_inventory_scroll_motion(
                                        before_img,
                                        verified_img,
                                        before_grid_r,
                                        expected_move_px,
                                        search_margin_px=search_margin_px,
                                        slots=before_slots,
                                    )
                                    verified_motion = _verify_inventory_near_zero_motion(
                                        before_img,
                                        verified_img,
                                        before_grid_r,
                                        expected_move_px,
                                        row_step_px,
                                        recaptured_motion,
                                        slots=before_slots,
                                    )
                                    if verified_motion is not None:
                                        after_img = verified_img
                                        after = verified_after
                                        after_grid_hash = verified_after_grid_hash
                                        after_page = verified_after_page
                                        after_hashes = verified_after_hashes
                                        image_changed = before is None or not _images_similar(before, after)
                                        hash_changed = before_grid_hash != after_grid_hash
                                        slot_sequence_changed = before_hashes != after_hashes
                                        moved = image_changed or hash_changed or slot_sequence_changed
                                        motion = verified_motion
                        verified_overlap = _inventory_overlap_rows_from_motion(
                            verified_motion,
                            row_step_px,
                            grid_rows,
                        )
                        if verified_motion is not None and verified_overlap is not None:
                            motion = verified_motion
                            overlap_rows, moved_rows, y_offset_delta_px, tail_scroll = verified_overlap
                            digit_vote = None
                            if (
                                before_img is not None
                                and moved_rows is not None
                                and moved_rows > 0
                                and overlap_rows > 0
                                and not tail_scroll
                            ):
                                digit_vote = _estimate_inventory_overlap_digit_y_delta(
                                    before_img,
                                    after_img,
                                    slots,
                                    before_y_offset_px=before_y_offset_px,
                                    grid_cols=grid_cols,
                                    grid_rows=grid_rows,
                                    row_step_px=row_step_px,
                                    moved_rows=moved_rows,
                                    refine_radius_px=4,
                                )
                                if (
                                    digit_vote is not None
                                    and int(digit_vote["dominant_count"]) >= min(4, int(digit_vote["slot_count"]))
                                    and float(digit_vote["dominant_mean_score"]) >= 0.55
                                ):
                                    old_y_delta = y_offset_delta_px
                                    y_offset_delta_px = int(digit_vote["dominant_delta_y_offset_px"])
                                    y_offset_refinement = {
                                        "method": digit_vote["method"],
                                        "previous_delta_y_offset_px": old_y_delta,
                                        "applied_delta_y_offset_px": y_offset_delta_px,
                                        "dominant_count": int(digit_vote["dominant_count"]),
                                        "slot_count": int(digit_vote["slot_count"]),
                                        "confidence": float(digit_vote["confidence"]),
                                        "dominant_mean_score": float(digit_vote["dominant_mean_score"]),
                                    }
                                    self.log(
                                        f"  drag try {idx}: digit vote y_delta {old_y_delta:+d}px -> "
                                        f"{y_offset_delta_px:+d}px count={digit_vote['dominant_count']}/"
                                        f"{digit_vote['slot_count']} score={digit_vote['dominant_mean_score']:.3f}"
                                    )
                            y_offset_px = before_y_offset_px + y_offset_delta_px
                            self.log(
                                f"  drag try {idx}: near-zero verified actual={motion.actual_move_px}px "
                                f"expected={motion.expected_step_px}px row_step={row_step_px}px "
                                f"moved_rows={moved_rows} overlap_rows={overlap_rows} "
                                f"before_y={before_y_offset_px:+d}px y_delta={y_offset_delta_px:+d}px "
                                f"y_offset={y_offset_px:+d}px score={motion.score:.3f} method={motion.method}"
                            )
                        else:
                            self.log(
                                f"  drag try {idx}: near-zero motion actual={motion.actual_move_px}px "
                                f"row_step={row_step_px}px verification failed -> stop without retry"
                            )
                            _save_inventory_scroll_debug(
                                debug_dir,
                                before_img=before_img,
                                after_img=after_img,
                                slots=slots,
                                grid_cols=grid_cols,
                                grid_rows=grid_rows,
                                scroll_index=scroll_index,
                                attempt_index=idx,
                                amount=amount,
                                scroll_ok=scroll_ok,
                                moved=moved,
                                image_changed=image_changed,
                                hash_changed=hash_changed,
                                slot_sequence_changed=slot_sequence_changed,
                                row_step_px=row_step_px,
                                expected_move_px=expected_move_px,
                                search_margin_px=search_margin_px,
                                motion=motion,
                                overlap_rows=0,
                                moved_rows=0,
                                y_offset_px=before_y_offset_px,
                                before_grid_hash=before_grid_hash,
                                after_grid_hash=after_grid_hash,
                                before_hashes=before_hashes,
                                after_hashes=after_hashes,
                                cursor_moved=cursor_moved,
                                before_y_offset_px=before_y_offset_px,
                                before_slots=before_slots,
                                tail_scroll=False,
                                focus_anchor_clicked_before_capture=focus_anchor_clicked,
                            )
                            return False, None, next_amount, 0, before_y_offset_px
                    else:
                        overlap_rows = _count_row_overlap(before_hashes, after_hashes, grid_cols)
                        y_offset_px = before_y_offset_px
                        self.log(
                            f"  drag try {idx}: overlap_rows={overlap_rows} source=hash "
                            f"y_offset={y_offset_px:+d}px"
                        )

                final_slots = _shift_slots_y(slots, y_offset_px, after_img.size) if y_offset_px else slots
                final_gray_band_layout = None
                if row_step_px > 0:
                    gray_layout = settled_gray_layout or _inventory_gray_band_layout_slots(
                        after_img,
                        slots,
                        grid_cols=grid_cols,
                        grid_rows=grid_rows,
                        row_step_px=row_step_px,
                    )
                    if gray_layout is not None:
                        final_slots = gray_layout["slots"]
                        final_gray_band_layout = {
                            "method": "target_gray_band_row_layout",
                            "score": round(float(gray_layout["score"]), 6),
                            "mean_strength": round(float(gray_layout["mean_strength"]), 6),
                            "spacing_score": round(float(gray_layout["spacing_score"]), 6),
                            "candidate_count": int(gray_layout["candidate_count"]),
                            "selected_band_y_centers_px": [
                                round(float(band["y_center_px"]), 3)
                                for band in gray_layout["bands"]
                            ],
                            "row_centers_px": [
                                round(float(value), 3)
                                for value in gray_layout["row_centers_px"]
                            ],
                            "tail_page_detected": bool(gray_layout.get("tail_page_detected")),
                            "tail_signature": gray_layout.get("tail_signature"),
                        }
                        self._last_inventory_tail_page_detected = bool(gray_layout.get("tail_page_detected"))
                        tail_suffix = " tail=yes" if gray_layout.get("tail_page_detected") else ""
                        self.log(
                            f"  drag try {idx}: gray-band layout applied "
                            f"score={gray_layout['score']:.3f} "
                            f"rows={','.join(str(round(float(v), 1)) for v in gray_layout['row_centers_px'])}"
                            f"{tail_suffix}"
                        )
                final_grid_r = _grid_region(final_slots)
                final_after = crop_region(after_img, final_grid_r)
                final_after_grid_hash = _img_hash(final_after)
                final_after_page = self._capture_inventory_page(
                    after_img,
                    final_slots,
                    grid_hash=final_after_grid_hash,
                    page_index=-1,
                    grid_cols=grid_cols,
                )
                final_after_hashes = [snap.icon_hash for snap in final_after_page.slots]
                adapted_amount, target_move_px = _adapt_inventory_drag_amount(
                    amount,
                    motion,
                    row_step_px,
                    grid_rows,
                    drag_config,
                )
                if adapted_amount != amount:
                    self.log(
                        f"  drag try {idx}: adaptive next delta_px={adapted_amount} "
                        f"(current={amount}, target_move={target_move_px}px, "
                        f"actual={motion.actual_move_px if motion is not None else 0}px)"
                    )

                _save_inventory_scroll_debug(
                    debug_dir,
                    before_img=before_img,
                    after_img=after_img,
                    slots=slots,
                    grid_cols=grid_cols,
                    grid_rows=grid_rows,
                    scroll_index=scroll_index,
                    attempt_index=idx,
                    amount=amount,
                    scroll_ok=scroll_ok,
                    moved=moved,
                    image_changed=image_changed,
                    hash_changed=hash_changed,
                    slot_sequence_changed=slot_sequence_changed,
                    row_step_px=row_step_px,
                    expected_move_px=expected_move_px,
                    search_margin_px=search_margin_px,
                    motion=motion,
                    overlap_rows=overlap_rows,
                    moved_rows=moved_rows,
                    y_offset_px=y_offset_px,
                    before_grid_hash=before_grid_hash,
                    after_grid_hash=final_after_grid_hash,
                    before_hashes=before_hashes,
                    after_hashes=final_after_hashes,
                    cursor_moved=cursor_moved,
                    before_y_offset_px=before_y_offset_px,
                    before_slots=before_slots,
                    tail_scroll=tail_scroll,
                    y_offset_refinement=y_offset_refinement,
                    focus_anchor_clicked_before_capture=focus_anchor_clicked,
                    after_slots=final_slots,
                    gray_band_layout=final_gray_band_layout,
                )
                next_amount = adapted_amount
                return True, final_after_page, next_amount, overlap_rows, y_offset_px

            grid_rows = max(1, (len(slots) + grid_cols - 1) // max(1, grid_cols))
            row_step_px = _slot_row_step_px(before_slots, after_img.size, grid_cols)
            expected_move_px = min(abs(amount), row_step_px * max(1, grid_rows - 1)) if row_step_px > 0 else abs(amount)
            search_margin_px = max(50, row_step_px * max(1, grid_rows - 1)) if row_step_px > 0 else 50
            _save_inventory_scroll_debug(
                debug_dir,
                before_img=before_img,
                after_img=after_img,
                slots=slots,
                grid_cols=grid_cols,
                grid_rows=grid_rows,
                scroll_index=scroll_index,
                attempt_index=idx,
                amount=amount,
                scroll_ok=scroll_ok,
                moved=moved,
                image_changed=image_changed,
                hash_changed=hash_changed,
                slot_sequence_changed=slot_sequence_changed,
                row_step_px=row_step_px,
                expected_move_px=expected_move_px,
                search_margin_px=search_margin_px,
                motion=None,
                overlap_rows=0,
                moved_rows=None,
                y_offset_px=before_y_offset_px,
                before_grid_hash=before_grid_hash,
                after_grid_hash=after_grid_hash,
                before_hashes=before_hashes,
                after_hashes=after_hashes,
                cursor_moved=cursor_moved,
                before_y_offset_px=before_y_offset_px,
                before_slots=before_slots,
            )
        return False, None, scroll_amount, 0, before_y_offset_px
    def _advance_inventory_page_with_input(
        self,
        input_backend: InventoryGridInput,
        slots: list[dict],
        grid_r: dict,
        grid_cols: int,
        before_page: InventoryPageSnapshot,
    ) -> tuple[bool, Optional[InventoryPageSnapshot]]:
        try:
            input_backend.advance_page()
        except Exception as exc:
            self.log(f"  {input_backend.backend_name} page advance failed: {exc}")
            _log.exception("inventory input page advance failed")
            return False, None

        if not self._wait(0.25):
            return False, None

        after_img = self._capture()
        if after_img is None:
            return False, None

        after = crop_region(after_img, grid_r)
        after_page = self._capture_inventory_page(
            after_img,
            slots,
            grid_hash=_img_hash(after),
            page_index=-1,
            grid_cols=grid_cols,
        )
        before_hashes = [snap.icon_hash for snap in before_page.slots]
        after_hashes = [snap.icon_hash for snap in after_page.slots]
        moved = (
            before_page.grid_hash != after_page.grid_hash
            or before_hashes != after_hashes
        )
        self.log(
            f"  {input_backend.backend_name} advance: moved={moved} "
            f"(hash_changed={before_page.grid_hash != after_page.grid_hash}, "
            f"slot_sequence_changed={before_hashes != after_hashes})"
        )
        if moved:
            overlap_rows = _count_row_overlap(before_hashes, after_hashes, grid_cols)
            self.log(f"  {input_backend.backend_name} advance: overlap_rows={overlap_rows}")
        return moved, after_page
    def _scan_grid(
        self,
        section: str,
        source: str,
        drag_config: InventoryDragConfig,
        scroll_amount: int,
        input_backend_name: str = "legacy",
    ) -> list[ItemEntry]:
        r_sec   = self.r[section]
        slots   = r_sec["grid_slots"]
        name_r  = r_sec["name_region"]
        count_r = r_sec["count_region"]
        grid_r  = _grid_region(slots)

        rect = self._rect()
        if not rect:
            self.log("window not found")
            return []

        items:       list[ItemEntry] = []
        seen_keys:   set[str]        = set()
        seen_hashes: list[str]       = []
        fast_grid_entries = 0
        detail_verified_entries = 0
        icon_cache = self._inventory_icon_cache.setdefault(source, {})
        failed_hashes = self._inventory_failed_hashes.setdefault(source, set())
        active_profile = get_inventory_profile(self._forced_inventory_profile_id)
        if active_profile is not None and active_profile.source != source:
            active_profile = None
        profile_seen_names: set[str] = set()
        icon = "item" if source == "item" else "equipment"
        scroll_debug_dir = _inventory_scroll_debug_dir(source, self._forced_inventory_profile_id)
        if scroll_debug_dir is not None:
            self.log(f"  inventory scroll debug: {scroll_debug_dir}")
        grid_cols = int(r_sec.get("grid_cols", 0))
        grid_rows = int(r_sec.get("grid_rows", 0))
        if grid_cols <= 0:
            grid_cols = max(1, int(round(len(slots) ** 0.5)))
        if grid_rows <= 0:
            grid_rows = max(1, (len(slots) + grid_cols - 1) // grid_cols)
        source_label = "\uC544\uC774\uD15C" if source == "item" else "\uC7A5\uBE44"
        self._status(
            "inventory.scan.start",
            source=source,
            source_label=source_label,
            grid_cols=grid_cols,
            grid_rows=grid_rows,
            total_slots=len(slots),
            profile_id=active_profile.profile_id if active_profile is not None else None,
        )
        current_scroll_amount = scroll_amount
        input_backend: InventoryGridInput | None = None
        legacy_scroll = True
        requested_backend = (input_backend_name or "legacy").strip().lower()
        if requested_backend != "legacy":
            self.log(
                f"  inventory input backend requested: {requested_backend} "
                "(experimental focus navigation)"
            )
            try:
                cursor_anchor_screen = None
                focus_anchor = None
                if slots:
                    hwnd = find_target_hwnd()
                    anchor_cx, anchor_cy = ratio_to_client(
                        rect,
                        float(slots[0].get("cx", 0.0)),
                        float(slots[0].get("cy", 0.0)),
                    )
                    if hwnd:
                        cursor_anchor_screen = client_to_screen(hwnd, anchor_cx, anchor_cy)
                        focus_anchor = (
                            lambda hwnd=hwnd, cx=anchor_cx, cy=anchor_cy:
                            click_point(hwnd, cx, cy, label="inventory_vcon_anchor", delay=0.25)
                        )
                input_backend = create_inventory_input_backend(
                    requested_backend,
                    cols=grid_cols,
                    rows=grid_rows,
                    cursor_anchor_screen=cursor_anchor_screen,
                    focus_anchor=focus_anchor,
                )
                input_backend.start()
                legacy_scroll = False
                self.log(
                    f"  inventory input backend: {input_backend.backend_name} "
                    f"(grid={grid_cols}x{grid_rows})"
                )
            except InventoryInputUnavailable as exc:
                self.log(
                    f"  inventory input backend unavailable: {requested_backend} "
                    f"({exc}) -> legacy scroll"
                )
                _log.warning("inventory input backend unavailable: %s", exc)
                input_backend = None
                legacy_scroll = True
        profile_ordered_names: list[str] = list(active_profile.ordered_names) if active_profile is not None else []
        profile_ordered_item_ids: list[str | None] = list(inventory_profile_ordered_item_ids(active_profile)) if active_profile is not None else []
        profile_index_by_name: dict[str, int] = {name: idx for idx, name in enumerate(profile_ordered_names)}
        profile_index_by_item_id: dict[str, int] = {
            item_id: idx for idx, item_id in enumerate(profile_ordered_item_ids) if item_id
        }
        profile_cursor = 0
        profile_max_unique_items = (
            INVENTORY_PROFILE_MAX_UNIQUE_ITEMS.get(active_profile.profile_id)
            if active_profile is not None
            else None
        )
        profile_explicit_slot_scan_limit = (
            INVENTORY_PROFILE_SLOT_SCAN_LIMITS.get(active_profile.profile_id)
            if active_profile is not None
            else None
        )
        profile_slot_scan_limit = (
            min(len(slots), profile_explicit_slot_scan_limit)
            if profile_explicit_slot_scan_limit is not None
            else (
                min(len(slots), profile_max_unique_items)
                if input_backend is not None
                and active_profile is not None
                and profile_max_unique_items is not None
                else None
            )
        )
        def _unique_scanned_item_count() -> int:
            return len(
                {
                    entry.item_id or entry.name
                    for entry in items
                    if entry.item_id or entry.name
                }
            )

        self.log(f"{icon} ?????????????????????????????????????????????????????????????(????{len(slots)}??")
        if active_profile is not None:
            expected_count = len(active_profile.expected_item_ids) or len(active_profile.ordered_names)
            limit_suffix = (
                f", max_unique={profile_max_unique_items}"
                if profile_max_unique_items is not None
                else ""
            )
            self.log(
                f"  inventory profile forced: {active_profile.profile_id} "
                f"({expected_count} expected{limit_suffix})"
            )
            if profile_slot_scan_limit is not None:
                self.log(f"  profile slot scan limit: {profile_slot_scan_limit}")

        def _profile_found_count() -> int:

            if active_profile is None:
                return 0
            if active_profile.expected_item_ids:
                return len(
                    {
                        entry.item_id
                        for entry in items
                        if entry.item_id in active_profile.expected_item_ids
                    }
                )
            return len(
                {
                    entry.name
                    for entry in items
                    if entry.name in set(active_profile.ordered_names)
                }
            )

        def _env_nonnegative_int(name: str, default: int) -> int:
            try:
                return max(0, int(os.environ.get(name, str(default))))
            except (TypeError, ValueError):
                return default

        def _env_float(name: str, default: float) -> float:
            try:
                return float(os.environ.get(name, str(default)))
            except (TypeError, ValueError):
                return default
        slot_count_row_gap_enabled = os.environ.get("BA_ITEM_COUNT_ROW_GAP_Y_OFFSET", "0") == "1"
        slot_count_y_offset_search_radius = _env_nonnegative_int("BA_ITEM_COUNT_Y_OFFSET_SEARCH_PX", 2)
        slot_count_color_filter_mode = os.environ.get("BA_ITEM_COUNT_COLOR_FILTER_MODE", "dark_ink")
        self._debug(f"  item slot count color filter mode: {slot_count_color_filter_mode}")
        self._inventory_motion_row_step_px = None
        grid_match_enabled = os.environ.get("BA_INVENTORY_GRID_MATCH", "1") != "0"
        grid_fast_min_score = _env_float("BA_ITEM_GRID_FAST_MIN_SCORE", 0.86)
        grid_fast_min_margin = _env_float("BA_ITEM_GRID_FAST_MIN_MARGIN", 0.09)
        grid_fast_min_count_confidence = _env_float("BA_ITEM_GRID_FAST_MIN_COUNT_CONF", 0.66)
        grid_relaxed_min_count_confidence = _env_float("BA_ITEM_GRID_RELAXED_MIN_COUNT_CONF", 0.55)
        active_profile_id = active_profile.profile_id if active_profile is not None else None
        (
            grid_anchor_match_enabled,
            grid_order_hint_enabled,
            grid_row_anchor_hint_enabled,
        ) = inventory_grid_hint_flags(
            active_profile_id,
            grid_match_enabled=grid_match_enabled,
        )
        grid_order_hint_exact_min_score = _env_float("BA_ITEM_GRID_ORDER_HINT_EXACT_MIN_SCORE", 0.70)
        grid_order_hint_family_min_score = _env_float("BA_ITEM_GRID_ORDER_HINT_FAMILY_MIN_SCORE", 0.78)
        grid_order_hint_wb_min_score = _env_float("BA_ITEM_GRID_ORDER_HINT_WB_MIN_SCORE", 0.68)
        grid_order_hint_min_count_confidence = _env_float("BA_ITEM_GRID_ORDER_HINT_MIN_COUNT_CONF", 0.60)
        grid_terminal_anchor_min_score = _env_float("BA_ITEM_GRID_TERMINAL_ANCHOR_MIN_SCORE", 0.70)
        grid_anchor_cross_check_enabled = grid_anchor_match_enabled and os.environ.get("BA_ITEM_GRID_ANCHOR_CROSS_CHECK", "1") != "0"
        grid_anchor_cross_check_min_score = _env_float("BA_ITEM_GRID_ANCHOR_CROSS_CHECK_MIN_SCORE", 0.78)
        grid_anchor_cross_check_margin = _env_float("BA_ITEM_GRID_ANCHOR_CROSS_CHECK_MARGIN", 0.04)
        grid_direct_icon_match_enabled = os.environ.get(INVENTORY_DIRECT_ICON_MATCH_ENV, "0") != "0"
        page_shadow_enabled = inventory_page_shadow_enabled(
            active_profile_id,
            grid_match_enabled=grid_match_enabled,
        )
        page_shadow_authoritative = inventory_page_shadow_authoritative(
            active_profile_id,
            shadow_enabled=page_shadow_enabled,
        )
        if page_shadow_authoritative:
            grid_anchor_match_enabled = False
            grid_order_hint_enabled = False
            grid_row_anchor_hint_enabled = False
        page_shadow_workers = max(1, _env_nonnegative_int("BA_INVENTORY_PAGE_SHADOW_WORKERS", 4))
        page_shadow_top_k = max(1, _env_nonnegative_int("BA_INVENTORY_PAGE_SHADOW_TOP_K", 4))
        page_shadow_min_score = _env_float("BA_INVENTORY_PAGE_SHADOW_MIN_SCORE", 0.55)
        self._debug(
            f"  item grid matcher: enabled={grid_match_enabled} "
            f"anchor_match={grid_anchor_match_enabled} "
            f"order_hint={grid_order_hint_enabled} row_anchor={grid_row_anchor_hint_enabled} "
            f"direct_icon={grid_direct_icon_match_enabled} "
            f"page_shadow={page_shadow_enabled} "
            f"shadow_authoritative={page_shadow_authoritative}"
        )
        def _next_profile_expected_item() -> tuple[int | None, str | None]:
            if active_profile is None or not profile_ordered_item_ids:
                return None, None
            index = max(0, profile_cursor)
            while index < len(profile_ordered_item_ids):
                item_id = profile_ordered_item_ids[index]
                name = profile_ordered_names[index] if index < len(profile_ordered_names) else None
                if item_id and (not name or name not in profile_seen_names):
                    return index, item_id
                index += 1
            return None, None

        def _school_tier_parts(item_id: str | None, prefix: str) -> tuple[str, str] | None:
            if not item_id or not item_id.startswith(prefix):
                return None
            suffix = item_id.removeprefix(prefix)
            school, sep, tier = suffix.rpartition("_")
            if not sep or not school or not tier.isdigit():
                return None
            return school, tier

        def _is_school_order_profile(profile_id: str | None) -> bool:
            return profile_id in INVENTORY_GRID_ORDER_HINT_PROFILES

        def _profile_order_relation(
            profile_id: str | None,
            expected_item_id: str | None,
            observed_item_id: str | None,
        ) -> str | None:
            if not expected_item_id or not observed_item_id:
                return None
            if expected_item_id == observed_item_id:
                return "exact"
            if profile_id == "tech_notes":
                prefix = "Item_Icon_SkillBook_"
                expected_parts = _school_tier_parts(expected_item_id, prefix)
                observed_parts = _school_tier_parts(observed_item_id, prefix)
                if expected_parts and observed_parts and expected_parts[0] == observed_parts[0]:
                    return "same_family"
                return None
            if profile_id == "tactical_bd":
                prefix = "Item_Icon_Material_ExSkill_"
                expected_parts = _school_tier_parts(expected_item_id, prefix)
                observed_parts = _school_tier_parts(observed_item_id, prefix)
                if expected_parts and observed_parts and expected_parts[0] == observed_parts[0]:
                    return "same_family"
                return None
            if profile_id != "ooparts":
                return None
            material_prefix = "Item_Icon_Material_"
            if expected_item_id.startswith(material_prefix) and observed_item_id.startswith(material_prefix):
                expected_base, _, expected_tier = expected_item_id.rpartition("_")
                observed_base, _, observed_tier = observed_item_id.rpartition("_")
                if expected_tier.isdigit() and observed_tier.isdigit() and expected_base == observed_base:
                    return "same_family"
            workbook_prefix = "Item_Icon_WorkBook_"
            if expected_item_id.startswith(workbook_prefix):
                if observed_item_id.startswith(workbook_prefix):
                    return "workbook_tail"
                return "workbook_expected"
            return None

        def _order_hint_min_score(relation: str | None) -> float:
            if relation == "exact":
                return grid_order_hint_exact_min_score
            if relation == "same_family":
                return grid_order_hint_family_min_score
            if relation in {"workbook_tail", "workbook_expected"}:
                return grid_order_hint_wb_min_score
            return 1.0

        next_scan_slot_indices: set[int] | None = None
        next_scan_y_offset_px = 0
        carried_grid_anchor_profile_indices: dict[int, int] = {}
        profile_scan_incomplete = False
        next_page_tail_detected = False
        shadow_prewarmed_keys: set[tuple[str, int, int]] = set()

        for scroll_i in range(MAX_SCROLLS):
            if self._stop_requested():
                break

            current_page_tail_detected = next_page_tail_detected
            next_page_tail_detected = False
            current_scan_slot_indices = next_scan_slot_indices
            current_scan_y_offset_px = next_scan_y_offset_px
            next_scan_slot_indices = None
            next_scan_y_offset_px = 0
            if current_scan_slot_indices is not None:
                if not current_scan_slot_indices:
                    self.log("  row-step scan window empty -> stopping")
                    break
                self.log(
                    f"  row-step scan window: "
                    f"{len(current_scan_slot_indices)}/{len(slots)} slots "
                    f"y_offset={current_scan_y_offset_px:+d}px"
                )

            img = self._capture()
            if img is None:
                break

            active_slots = _shift_slots_y(slots, current_scan_y_offset_px, img.size) if current_scan_y_offset_px else slots
            active_gray_band_layout = None
            active_row_step_px = _slot_row_step_px(active_slots, img.size, grid_cols)
            if active_row_step_px > 0:
                gray_layout = _inventory_gray_band_layout_slots(
                    img,
                    slots,
                    grid_cols=grid_cols,
                    grid_rows=grid_rows,
                    row_step_px=active_row_step_px,
                )
                if gray_layout is not None:
                    active_slots = gray_layout["slots"]
                    active_gray_band_layout = gray_layout
                    if gray_layout.get("tail_page_detected"):
                        current_page_tail_detected = True
                    tail_suffix = " tail=yes" if gray_layout.get("tail_page_detected") else ""
                    self.log(
                        f"  gray-band layout page {scroll_i + 1}: "
                        f"score={gray_layout['score']:.3f} "
                        f"rows={','.join(str(round(float(v), 1)) for v in gray_layout['row_centers_px'])}"
                        f"{tail_suffix}"
                    )
            active_grid_r = _grid_region(active_slots)
            grid_crop = crop_region(img, active_grid_r)
            cur_hash  = _img_hash(grid_crop)
            page = self._capture_inventory_page(
                img,
                active_slots,
                grid_hash=cur_hash,
                page_index=scroll_i,
                grid_cols=grid_cols,
            )

            if cur_hash in seen_hashes:
                self.log(f"  ?????????????????????????⑤벡????????????????????????????????ш끽維뽳쭩?뱀땡???얩맪???????????????????轅붽틓??섑떊???⑤챷?????????????????????????嫄???????????????????????筌???????????????????????? -> ??????????????????????????????????????????({len(items)}??")
                break
            seen_hashes.append(cur_hash)
            if len(seen_hashes) > 10:
                seen_hashes.pop(0)

            new_this = 0
            page_item_ids: list[str] = []
            page_raw_names: list[str] = []
            profile_limit_reached = False
            slot_count_y_offset_hint = 0
            slot_count_row_y_offset_estimates = {}
            grid_row_anchor_state = InventoryGridRowAnchorState(
                grid_cols=grid_cols,
                enabled=bool(
                    grid_row_anchor_hint_enabled
                    and active_profile is not None
                    and _is_school_order_profile(active_profile.profile_id)
                ),
            )
            for carried_slot_idx, carried_profile_idx in carried_grid_anchor_profile_indices.items():
                grid_row_anchor_state.record_confirmed(carried_slot_idx, carried_profile_idx)
            total_page_slots = min(len(active_slots), len(page.slots))
            slot_scan_order = _inventory_anchor_scan_order(
                total_page_slots,
                grid_cols,
                grid_rows,
                current_scan_slot_indices,
            ) if grid_row_anchor_state.enabled else [
                idx for idx in range(total_page_slots)
                if current_scan_slot_indices is None or idx in current_scan_slot_indices
            ]

            page_shadow_result = None
            page_shadow_config = None
            shadow_assignments_by_slot = {}
            page_actual_item_ids: dict[int, str] = {}
            if page_shadow_enabled and active_profile is not None and profile_ordered_item_ids:
                try:
                    shadow_catalog = inventory_profile_template_catalog(source, active_profile.profile_id)
                    page_shadow_config = inventory_page_shadow_matching_config(r_sec, active_profile.profile_id)
                    if active_slots:
                        shadow_slot_size = crop_region(img, active_slots[0]).size
                        prewarm_key = (active_profile.profile_id, *shadow_slot_size)
                        if prewarm_key not in shadow_prewarmed_keys:
                            prewarm_result = prewarm_inventory_grid_templates(
                                shadow_catalog,
                                page_shadow_config,
                                shadow_slot_size,
                            )
                            shadow_prewarmed_keys.add(prewarm_key)
                            self.log(
                                f"  inventory page shadow prewarm: profile={active_profile.profile_id} "
                                f"slot_size={shadow_slot_size[0]}x{shadow_slot_size[1]} "
                                f"templates={prewarm_result.template_count} "
                                f"hits={prewarm_result.cache_hits} misses={prewarm_result.cache_misses} "
                                f"elapsed_ms={prewarm_result.elapsed_ms:.1f}"
                            )
                    page_shadow_result = evaluate_inventory_page_shadow(
                        img,
                        active_slots[:total_page_slots],
                        shadow_catalog,
                        page_shadow_config,
                        profile_ordered_item_ids,
                        scan_indices=current_scan_slot_indices,
                        top_k=page_shadow_top_k,
                        workers=page_shadow_workers,
                        min_score=page_shadow_min_score,
                    )
                    shadow_resolved = sum(
                        1 for assignment in page_shadow_result.assignments if assignment.item_id
                    )
                    self.log(
                        f"  inventory page shadow prepared: profile={active_profile.profile_id} "
                        f"page={scroll_i + 1} "
                        f"slots={len(page_shadow_result.assignments)} "
                        f"resolved={shadow_resolved} workers={page_shadow_result.worker_count} "
                        f"elapsed_ms={page_shadow_result.elapsed_ms:.1f}"
                    )
                    shadow_assignments_by_slot = {
                        assignment.slot_index: assignment
                        for assignment in page_shadow_result.assignments
                    }
                except Exception:
                    _log.exception("inventory page shadow failed")
                    self.log(f"  inventory page shadow failed: page={scroll_i + 1}")
            if page_shadow_authoritative and page_shadow_result is None:
                profile_scan_incomplete = active_profile is not None
                self.log(
                    f"  inventory shadow authoritative unavailable: "
                    f"profile={active_profile_id or '-'} page={scroll_i + 1} -> stopping"
                )
                break

            processed_slot_indices: set[int] = set()
            for slot_idx in slot_scan_order:
                has_unprocessed_prior_slot = any(
                    prior_slot_idx < slot_idx and prior_slot_idx not in processed_slot_indices
                    for prior_slot_idx in slot_scan_order
                )
                slot = active_slots[slot_idx]
                slot_snap = page.slots[slot_idx]
                processed_slot_indices.add(slot_idx)
                if self._stop_requested():
                    break
                if current_scan_slot_indices is not None and slot_idx not in current_scan_slot_indices:
                    continue
                if not slot_count_row_gap_enabled and grid_cols > 0 and slot_idx % grid_cols == 0:
                    slot_count_y_offset_hint = 0
                if (
                    profile_slot_scan_limit is not None
                    and slot_idx >= profile_slot_scan_limit
                ):
                    self.log(
                        f"  profile slot scan limit reached: "
                        f"{slot_idx}/{profile_slot_scan_limit}"
                    )
                    profile_limit_reached = True
                    break

                if current_page_tail_detected and grid_cols > 0 and slot_idx >= max(0, (grid_rows - 1) * grid_cols):
                    empty_scores = _inventory_tail_empty_slot_gray_scores(img, slot)
                    if _inventory_tail_empty_slot_detected(empty_scores):
                        self._debug(
                            f"    tail empty slot skipped: slot={slot_idx + 1} "
                            f"icon={empty_scores['icon']:.3f} "
                            f"bg={empty_scores['background']:.3f} "
                            f"digit={empty_scores['digit']:.3f} "
                            f"mean={empty_scores['mean']:.3f}"
                        )
                        continue

                shadow_assignment = shadow_assignments_by_slot.get(slot_idx)
                if page_shadow_authoritative and (
                    shadow_assignment is None or shadow_assignment.item_id is None
                ):
                    self._debug(
                        f"    shadow authoritative unresolved skip: slot={slot_idx} page={scroll_i + 1}"
                    )
                    continue

                icon_crop = crop_region(img, _slot_icon_region(slot))
                if page_shadow_authoritative:
                    icon_template_item_id, icon_template_score = None, 0.0
                else:
                    icon_template_item_id, icon_template_score = self._match_inventory_icon(
                        icon_crop,
                        source,
                        active_profile.profile_id if active_profile is not None else None,
                    )
                icon_template_matched = icon_template_item_id is not None
                grid_template_item_id: str | None = None
                grid_template_score = 0.0
                grid_template_matched = False
                grid_anchor_eligible = False
                grid_count_confidence = 0.0
                grid_count_raw = ""
                grid_count_low_confidence = False
                detail_template_item_id: str | None = None
                detail_template_score = 0.0
                assigned_profile_idx: int | None = None
                matched_profile_name: str | None = None

                verified = None
                detail_count_fallback: InventoryVerification | None = None
                detail_count_fallback_confidence = 0.0
                detail_count_fallback_raw = ""
                detail_count_fallback_low_confidence = False
                if source in {"item", "equipment"} and grid_match_enabled:
                    slot_crop = crop_region(img, slot)
                    slot_count_search_px = slot_count_y_offset_search_radius
                    slot_count_row_estimate = None
                    if slot_count_row_gap_enabled and grid_cols > 0:
                        slot_count_row_index = slot_idx // grid_cols
                        slot_count_row_estimate = slot_count_row_y_offset_estimates.get(slot_count_row_index)
                        if slot_count_row_estimate is None:
                            row_start = slot_count_row_index * grid_cols
                            row_end = min(len(active_slots), row_start + grid_cols)
                            row_indices = [
                                index
                                for index in range(row_start, row_end)
                                if current_scan_slot_indices is None or index in current_scan_slot_indices
                            ]
                            slot_count_row_estimate = estimate_item_slot_count_row_y_offset(
                                img,
                                [active_slots[index] for index in row_indices],
                                center=0,
                                radius=slot_count_y_offset_search_radius,
                                color_filter_tolerance_percent=1.0,
                                color_filter_mode=slot_count_color_filter_mode,
                            )
                            slot_count_row_y_offset_estimates[slot_count_row_index] = slot_count_row_estimate
                            if slot_count_row_estimate.y_offset_px is not None:
                                self._debug(
                                    f"    row count y-offset: row={slot_count_row_index + 1} "
                                    f"dy={slot_count_row_estimate.y_offset_px:+d}px "
                                    f"gap={slot_count_row_estimate.mean_bottom_gap:.2f} "
                                    f"samples={slot_count_row_estimate.sample_count} "
                                    f"conf={slot_count_row_estimate.confidence:.2f}"
                                )
                        if slot_count_row_estimate.y_offset_px is not None:
                            slot_count_y_offset_hint = slot_count_row_estimate.y_offset_px
                            slot_count_search_px = 0
                    slot_count_debug_dir = None
                    debug_count_match = None
                    if scroll_debug_dir is not None:
                        slot_count_debug_dir = (
                            scroll_debug_dir
                            / "slot_count_digits"
                            / f"page_{scroll_i + 1:02d}_slot_{slot_idx + 1:02d}"
                        )
                        debug_count_match = read_item_slot_count(
                            img,
                            slot,
                            debug_dir=slot_count_debug_dir,
                            y_offset_px=slot_count_y_offset_hint,
                            y_offset_search_px=slot_count_search_px,
                            color_filter_mode=slot_count_color_filter_mode,
                        )
                        slot_count_y_offset_hint = debug_count_match.y_offset_px
                        if (
                            debug_count_match.value is None
                            and slot_count_search_px == 0
                            and slot_count_row_estimate is not None
                            and slot_count_row_estimate.y_offset_px is not None
                            and slot_count_y_offset_search_radius > 0
                        ):
                            debug_count_match = read_item_slot_count(
                                img,
                                slot,
                                debug_dir=slot_count_debug_dir,
                                y_offset_px=slot_count_y_offset_hint,
                                y_offset_search_px=slot_count_y_offset_search_radius,
                                color_filter_mode=slot_count_color_filter_mode,
                            )
                            slot_count_y_offset_hint = debug_count_match.y_offset_px
                    grid_template_config = page_shadow_config or _inventory_grid_template_matching_config(
                        r_sec,
                        active_profile.profile_id if active_profile is not None else None,
                    )
                    grid_match_min_score = grid_fast_min_score
                    grid_match_min_margin = grid_fast_min_margin
                    direct_match_config = (
                        grid_template_config.get("direct_icon_match")
                        if isinstance(grid_template_config, dict)
                        else None
                    )
                    if isinstance(direct_match_config, dict) and direct_match_config.get("enabled", False):
                        grid_match_min_score = float(direct_match_config.get("fast_min_score", grid_match_min_score))
                        grid_match_min_margin = float(direct_match_config.get("fast_min_margin", grid_match_min_margin))
                    grid_tier_hint, grid_tier_confidence = detect_inventory_grid_tier_hint(
                        slot_crop,
                        grid_template_config,
                    )
                    if grid_tier_hint is not None:
                        self._status(
                            "inventory.slot.tier_hint",
                            source=source,
                            source_label=source_label,
                            slot_index=slot_idx,
                            slot_number=slot_idx + 1,
                            page_index=scroll_i + 1,
                            tier_hint=grid_tier_hint,
                            tier_confidence=round(grid_tier_confidence, 4),
                            grid_cols=grid_cols,
                            grid_rows=grid_rows,
                            total_slots=len(slots),
                            profile_id=active_profile.profile_id if active_profile is not None else None,
                        )
                    if page_shadow_authoritative:
                        grid_match = InventoryGridMatchResult(
                            item_id=shadow_assignment.item_id,
                            best_item_id=shadow_assignment.item_id,
                            score=float(shadow_assignment.score),
                            margin=1.0,
                            candidate_count=1,
                        )
                        grid_catalog = []
                    else:
                        grid_catalog = inventory_profile_template_catalog(
                            source,
                            active_profile.profile_id if active_profile is not None else None,
                        )
                        grid_match = match_inventory_grid_template(
                            slot_crop,
                            grid_catalog,
                            grid_template_config,
                            row_anchor_state=grid_row_anchor_state,
                            slot_index=slot_idx,
                            ordered_item_ids=profile_ordered_item_ids,
                        )
                    grid_row_anchor_candidate_count = grid_match.row_anchor_candidate_count
                    grid_best_item_id = grid_match.best_item_id or grid_match.item_id
                    grid_candidate_item_id = grid_match.item_id
                    if (
                        grid_anchor_cross_check_enabled
                        and grid_row_anchor_candidate_count > 0
                        and grid_best_item_id is not None
                        and (
                            grid_row_anchor_candidate_count == 1
                            or (
                                active_profile is not None
                                and grid_best_item_id in active_profile.terminal_item_ids
                            )
                        )
                    ):
                        unrestricted_grid_match = match_inventory_grid_template(
                            slot_crop,
                            grid_catalog,
                            grid_template_config,
                        )
                        unrestricted_best_item_id = unrestricted_grid_match.best_item_id or unrestricted_grid_match.item_id
                        if (
                            unrestricted_best_item_id
                            and unrestricted_best_item_id != grid_best_item_id
                            and unrestricted_grid_match.score >= grid_anchor_cross_check_min_score
                            and unrestricted_grid_match.score >= grid_match.score + grid_anchor_cross_check_margin
                        ):
                            self._debug(
                                f"    grid row anchor cross-check rejected: slot={slot_idx} "
                                f"anchored={grid_best_item_id} score={grid_match.score:.2f} "
                                f"unrestricted={unrestricted_best_item_id} "
                                f"score={unrestricted_grid_match.score:.2f}"
                            )
                            grid_match = unrestricted_grid_match
                            grid_row_anchor_candidate_count = grid_match.row_anchor_candidate_count
                            grid_best_item_id = grid_match.best_item_id or grid_match.item_id
                            grid_candidate_item_id = grid_match.item_id
                    order_hint_item_id: str | None = None
                    order_hint_profile_idx: int | None = None
                    order_hint_relation: str | None = None
                    if (
                        grid_order_hint_enabled
                        and active_profile is not None
                        and grid_best_item_id is not None
                    ):
                        order_hint_profile_idx, expected_item_id = _next_profile_expected_item()
                        order_hint_relation = _profile_order_relation(
                            active_profile.profile_id,
                            expected_item_id,
                            grid_best_item_id,
                        )
                        if (
                            order_hint_relation is not None
                            and grid_match.score >= _order_hint_min_score(order_hint_relation)
                        ):
                            grid_candidate_item_id = grid_candidate_item_id or grid_best_item_id
                            order_hint_item_id = expected_item_id
                    if (
                        grid_order_hint_enabled
                        and active_profile is not None
                        and grid_best_item_id is not None
                        and not order_hint_item_id
                        and grid_row_anchor_candidate_count == 1
                        and grid_best_item_id in active_profile.terminal_item_ids
                        and grid_match.score >= grid_terminal_anchor_min_score
                    ):
                        terminal_profile_idx = profile_index_by_item_id.get(grid_best_item_id)
                        if terminal_profile_idx is not None:
                            grid_candidate_item_id = grid_candidate_item_id or grid_best_item_id
                            order_hint_item_id = grid_best_item_id
                            order_hint_profile_idx = terminal_profile_idx
                            order_hint_relation = "terminal_anchor"
                    if grid_candidate_item_id:
                        grid_profile_name = inventory_item_display_name(grid_candidate_item_id)
                        grid_profile_idx = profile_index_by_item_id.get(grid_candidate_item_id)
                        if grid_profile_idx is None and grid_profile_name:
                            grid_profile_idx = profile_index_by_name.get(grid_profile_name)
                        grid_allowed = active_profile is None or grid_profile_idx is not None
                        if not grid_allowed:
                            self._debug(
                                f"    grid template outside profile fallback: "
                                f"slot={slot_idx} item_id={grid_candidate_item_id}"
                            )
                            count_match = None
                        else:
                            grid_visual_anchor_strong = bool(
                                grid_profile_idx is not None
                                and grid_candidate_item_id
                                and grid_match.score >= grid_match_min_score
                                and grid_match.margin >= grid_match_min_margin
                            )
                            if grid_row_anchor_state.should_promote_anchor(slot_idx, strong_match=grid_visual_anchor_strong):
                                if grid_row_anchor_state.record_confirmed(slot_idx, grid_profile_idx, as_anchor=True):
                                    row_number = slot_idx // max(1, grid_cols) + 1
                                    visual_anchor_name = inventory_item_display_name(grid_candidate_item_id) or grid_candidate_item_id
                                    self._debug(
                                        f"    grid visual anchor confirmed: "
                                        f"row={row_number} slot={slot_idx + 1} profile_idx={grid_profile_idx} "
                                        f"score={grid_match.score:.2f} margin={grid_match.margin:.3f}"
                                    )
                                    self._status(
                                        "inventory.row_anchor.confirmed",
                                        source=source,
                                        source_label=source_label,
                                        slot_index=slot_idx,
                                        slot_number=slot_idx + 1,
                                        row_number=row_number,
                                        page_index=scroll_i + 1,
                                        item_name=visual_anchor_name,
                                        item_id=grid_candidate_item_id,
                                        profile_index=grid_profile_idx,
                                        grid_cols=grid_cols,
                                        grid_rows=grid_rows,
                                        total_slots=len(slots),
                                        profile_id=active_profile.profile_id if active_profile is not None else None,
                                    )
                            count_match = debug_count_match or read_item_slot_count(
                                img,
                                slot,
                                y_offset_px=slot_count_y_offset_hint,
                                y_offset_search_px=slot_count_search_px,
                                color_filter_mode=slot_count_color_filter_mode,
                            )
                        if (
                            count_match is not None
                            and count_match.value is None
                            and debug_count_match is None
                            and slot_count_search_px == 0
                            and slot_count_row_estimate is not None
                            and slot_count_row_estimate.y_offset_px is not None
                            and slot_count_y_offset_search_radius > 0
                        ):
                            count_match = read_item_slot_count(
                                img,
                                slot,
                                y_offset_px=slot_count_y_offset_hint,
                                y_offset_search_px=slot_count_y_offset_search_radius,
                                color_filter_mode=slot_count_color_filter_mode,
                            )
                        if count_match is not None:
                            slot_count_y_offset_hint = count_match.y_offset_px
                        if count_match is not None and count_match.value is not None:
                            gate_reasons: list[str] = []
                            if not page_shadow_authoritative and grid_match.score < grid_match_min_score:
                                gate_reasons.append(f"score<{grid_match_min_score:.2f}")
                            if not page_shadow_authoritative and grid_match.margin < grid_match_min_margin:
                                gate_reasons.append(f"margin<{grid_match_min_margin:.3f}")
                            if count_match.confidence < grid_fast_min_count_confidence:
                                gate_reasons.append(f"count_conf<{grid_fast_min_count_confidence:.2f}")
                            order_hint_visual_gate_ok = (
                                not order_hint_item_id
                                or (
                                    grid_match.score >= grid_match_min_score
                                    and grid_match.margin >= grid_match_min_margin
                                )
                            )
                            order_hint_accepted = bool(
                                order_hint_item_id
                                and order_hint_visual_gate_ok
                                and count_match.confidence >= grid_order_hint_min_count_confidence
                            )
                            visual_gate_ok = bool(
                                page_shadow_authoritative
                                or (
                                    grid_match.score >= grid_match_min_score
                                    and grid_match.margin >= grid_match_min_margin
                                )
                            )
                            relaxed_count_accepted = bool(
                                gate_reasons
                                and visual_gate_ok
                                and count_match.confidence >= grid_relaxed_min_count_confidence
                                and (
                                    grid_row_anchor_candidate_count == 1
                                    or grid_match.candidate_count == 1
                                    or grid_match.margin >= grid_match_min_margin * 1.75
                                )
                            )
                            tier_suffix = (
                                f" tier={grid_match.tier_hint} cand={grid_match.candidate_count}"
                                if grid_match.tier_hint is not None
                                else ""
                            )
                            anchor_suffix = (
                                f" row_anchor_candidates={grid_row_anchor_candidate_count}"
                                if grid_row_anchor_candidate_count
                                else ""
                            )
                            if gate_reasons and not order_hint_accepted and not relaxed_count_accepted:
                                self._debug(
                                    f"    grid fast gated: slot={slot_idx} item_id={grid_candidate_item_id} "
                                    f"x{count_match.value} reasons={','.join(gate_reasons)} "
                                    f"score={grid_match.score:.2f} margin={grid_match.margin:.3f} "
                                    f"count_conf={count_match.confidence:.2f} dy={count_match.y_offset_px:+d}"
                                    f"{tier_suffix}"
                                    f"{anchor_suffix}"
                                )
                                detail_count_fallback = InventoryVerification(
                                    name=None,
                                    count=count_match.value,
                                    item_id=grid_candidate_item_id,
                                    match_score=grid_match.score,
                                )
                                detail_count_fallback_confidence = count_match.confidence
                                detail_count_fallback_raw = count_match.raw
                                detail_count_fallback_low_confidence = bool(
                                    count_match.confidence < grid_fast_min_count_confidence
                                )
                            else:
                                grid_template_item_id = order_hint_item_id if order_hint_accepted else grid_candidate_item_id
                                if order_hint_accepted:
                                    assigned_profile_idx = order_hint_profile_idx
                                grid_template_score = grid_match.score
                                grid_count_confidence = count_match.confidence
                                grid_count_raw = count_match.raw
                                grid_count_low_confidence = bool(relaxed_count_accepted and count_match.confidence < grid_fast_min_count_confidence)
                                grid_template_matched = True
                                grid_anchor_eligible = bool(
                                    grid_visual_anchor_strong
                                    and grid_template_item_id == grid_candidate_item_id
                                )
                                verified = InventoryVerification(
                                    name=None,
                                    count=count_match.value,
                                    item_id=grid_template_item_id,
                                    match_score=grid_template_score,
                                )
                                order_suffix = (
                                    f", order_hint={order_hint_relation}:{grid_best_item_id}->{grid_template_item_id}"
                                    if order_hint_accepted
                                    else (", relaxed_count_conf" if relaxed_count_accepted else "")
                                )
                                self.log(
                                    f"    {'shadow authoritative' if page_shadow_authoritative else 'grid template'} matched: "
                                    f"{grid_template_item_id} "
                                    f"x{count_match.value} "
                                    f"(score={grid_match.score:.2f}, "
                                    f"margin={grid_match.margin:.3f}, "
                                    f"count_conf={count_match.confidence:.2f}, dy={count_match.y_offset_px:+d}"
                                    f"{tier_suffix}"
                                    f"{anchor_suffix}"
                                    f"{order_suffix})"
                                )
                        elif count_match is not None:
                            self._debug(
                                f"    grid count fallback: slot={slot_idx} "
                                f"reason={count_match.reason} raw={count_match.raw!r} dy={count_match.y_offset_px:+d}"
                            )
                    elif grid_match.score > 0.0:
                        best_suffix = f" item_id={grid_best_item_id}" if grid_best_item_id else ""
                        tier_suffix = (
                            f" tier={grid_match.tier_hint} cand={grid_match.candidate_count}"
                            if grid_match.tier_hint is not None
                            else ""
                        )
                        anchor_suffix = (
                            f" row_anchor_candidates={grid_row_anchor_candidate_count}"
                            if grid_row_anchor_candidate_count
                            else ""
                        )
                        self._debug(
                            f"    grid template fallback: slot={slot_idx}{best_suffix} "
                            f"best={grid_match.score:.2f} margin={grid_match.margin:.3f}"
                            f"{tier_suffix}"
                            f"{anchor_suffix}"
                        )
                used_detail_verification = verified is None
                if verified is None:
                    verified = self._verify_inventory_slot(
                        rect,
                        slot,
                        name_r,
                        count_r,
                        source,
                        profile_id=active_profile.profile_id if active_profile is not None else None,
                        input_backend=input_backend,
                        slot_index=slot_idx,
                        count_fallback=detail_count_fallback,
                    )
                    if verified is detail_count_fallback and detail_count_fallback is not None:
                        grid_template_item_id = detail_count_fallback.item_id
                        grid_template_score = detail_count_fallback.match_score
                        grid_count_confidence = detail_count_fallback_confidence
                        grid_count_raw = detail_count_fallback_raw
                        grid_count_low_confidence = detail_count_fallback_low_confidence
                        grid_template_matched = True
                        grid_anchor_eligible = False
                        self.log(
                            f"    grid fallback accepted after weak detail count: "
                            f"{grid_template_item_id} x{detail_count_fallback.count} "
                            f"(score={grid_template_score:.2f}, "
                            f"count_conf={grid_count_confidence:.2f})"
                        )
                if verified is not None and page_shadow_authoritative and shadow_assignment.item_id:
                    verified = InventoryVerification(
                        name=verified.name,
                        count=verified.count,
                        item_id=shadow_assignment.item_id,
                        match_score=float(shadow_assignment.score),
                        detail_crop=verified.detail_crop,
                        detail_name_crop=verified.detail_name_crop,
                    )
                    grid_template_item_id = shadow_assignment.item_id
                    grid_template_score = float(shadow_assignment.score)
                if not verified:
                    continue
                if grid_template_matched:
                    fast_grid_entries += 1
                elif used_detail_verification:
                    detail_verified_entries += 1
                name = verified.name
                count = verified.count
                if verified.item_id:
                    if grid_template_matched and verified.item_id == grid_template_item_id:
                        pass
                    else:
                        detail_template_item_id = verified.item_id
                        detail_template_score = verified.match_score
                item_id = grid_template_item_id or detail_template_item_id or icon_template_item_id
                if not item_id:
                    self.log(f"  template unresolved skip: slot={slot_idx}")
                    continue

                row_anchor_confirmed = False
                if active_profile is not None:
                    matched_profile_name = inventory_item_display_name(item_id)
                    if not matched_profile_name and item_id in profile_index_by_name:
                        matched_profile_name = item_id
                    assigned_profile_idx = profile_index_by_item_id.get(item_id)
                    if assigned_profile_idx is None and matched_profile_name:
                        assigned_profile_idx = profile_index_by_name.get(matched_profile_name)

                    if assigned_profile_idx is None:
                        self.log(
                            f"  explicit template outside profile skip: "
                            f"slot={slot_idx} item_id={item_id}"
                        )
                        continue

                    if assigned_profile_idx > profile_cursor:
                        self.log(
                            f"  profile cursor jump: {profile_cursor} -> {assigned_profile_idx}"
                        )
                        defer_gap_fill = bool(grid_row_anchor_state.enabled and has_unprocessed_prior_slot)
                        if defer_gap_fill:
                            self._debug(
                                f"    profile gap zero-fill deferred: "
                                f"slot={slot_idx + 1} cursor={profile_cursor} target={assigned_profile_idx}"
                            )
                        else:
                            gap_added = self._append_profile_gap_entries(
                                items,
                                seen_keys,
                                profile_seen_names,
                                active_profile,
                                profile_ordered_names,
                                profile_ordered_item_ids,
                                source,
                                profile_cursor,
                                assigned_profile_idx,
                            )
                            if gap_added:
                                profile_cursor = max(profile_cursor, assigned_profile_idx)
                    if assigned_profile_idx < len(profile_ordered_names):
                        name = profile_ordered_names[assigned_profile_idx]
                    else:
                        name = matched_profile_name
                    if (
                        assigned_profile_idx < len(profile_ordered_item_ids)
                        and profile_ordered_item_ids[assigned_profile_idx]
                    ):
                        item_id = profile_ordered_item_ids[assigned_profile_idx]
                    promote_to_anchor = grid_row_anchor_state.should_promote_anchor(slot_idx, strong_match=grid_anchor_eligible)
                    if grid_row_anchor_state.record_confirmed(slot_idx, assigned_profile_idx, as_anchor=promote_to_anchor):
                        row_anchor_confirmed = True
                        row_number = slot_idx // max(1, grid_cols) + 1
                        self._debug(
                            f"    grid row anchor confirmed: "
                            f"row={row_number} "
                            f"slot={slot_idx + 1} profile_idx={assigned_profile_idx}"
                        )
                        self._status(
                            "inventory.row_anchor.confirmed",
                            source=source,
                            source_label=source_label,
                            slot_index=slot_idx,
                            slot_number=slot_idx + 1,
                            row_number=row_number,
                            page_index=scroll_i + 1,
                            item_name=name or matched_profile_name or inventory_item_display_name(item_id) or item_id,
                            item_id=item_id,
                            profile_index=assigned_profile_idx,
                            grid_cols=grid_cols,
                            grid_rows=grid_rows,
                            total_slots=len(slots),
                            profile_id=active_profile.profile_id if active_profile is not None else None,
                        )

                if not name and item_id:
                    name = inventory_item_display_name(item_id) or item_id
                if not name:
                    continue

                icon_cache[slot_snap.icon_hash] = (name, count, item_id)
                if page_shadow_authoritative:
                    detect_source = f"shadow_authoritative({grid_template_score:.2f})"
                elif grid_template_matched:
                    detect_source = f"grid_template({grid_template_score:.2f})"
                elif detail_template_item_id is not None:
                    detect_source = f"detail_image_template+detail({detail_template_score:.2f})"
                elif icon_template_matched:
                    detect_source = f"icon_template+detail({icon_template_score:.2f})"
                else:
                    detect_source = "detail_template"

                canonical_name = inventory_item_display_name(item_id)
                if canonical_name:
                    name = canonical_name
                elif active_profile is not None:
                    profile_name = resolve_inventory_profile_name(active_profile, name, profile_seen_names)
                    if profile_name:
                        name = profile_name
                        detect_source = f"{detect_source}+profile"
                    else:
                        duplicate_name = find_inventory_profile_duplicate(active_profile, name, profile_seen_names)
                        if duplicate_name:
                            self.log(
                                f"  duplicate profile match skipped: raw={name} "
                                f"-> {duplicate_name}"
                            )
                            continue
                if item_id:
                    page_item_ids.append(item_id)
                    page_actual_item_ids[slot_idx] = item_id
                if name:
                    page_raw_names.append(name)

                entry = ItemEntry(
                    name=name,
                    quantity=count,
                    item_id=item_id,
                    source=source,
                    index=len(items),
                    scan_meta={
                        "status": "ok",
                        "reason": "direct_match",
                        "profile_id": active_profile.profile_id if active_profile is not None else None,
                        "profile_index": assigned_profile_idx,
                        "match_score": round(max(grid_template_score, detail_template_score, icon_template_score), 4),
                        "detect_source": detect_source,
                        "fast_grid": bool(grid_template_matched),
                        "grid_template_score": round(grid_template_score, 4) if grid_template_matched else None,
                        "grid_count_confidence": round(grid_count_confidence, 4) if grid_template_matched else None,
                        "grid_count_raw": grid_count_raw if grid_template_matched else None,
                        "grid_count_low_confidence": grid_count_low_confidence if grid_template_matched else False,
                        "roi_y_offset_px": current_scan_y_offset_px,
                        "review_required": False,
                        "capture_resolution": self._inventory_capture_resolution,
                    },
                    detail_crop=verified.detail_crop,
                    detail_name_crop=verified.detail_name_crop,
                )
                k = entry.key()
                if k not in seen_keys:
                    seen_keys.add(k)
                    items.append(entry)
                    if entry.name:
                        profile_seen_names.add(entry.name)
                        if active_profile is not None:
                            mapped_idx = profile_index_by_name.get(entry.name)
                            if mapped_idx is not None:
                                profile_cursor = max(profile_cursor, mapped_idx + 1)
                    new_this += 1
                    self.log(f"  {icon} [{len(items):>3}] {name}  x{count} ({detect_source})")
                    self._status(
                        "inventory.slot.confirmed",
                        source=source,
                        source_label=source_label,
                        slot_index=slot_idx,
                        slot_number=slot_idx + 1,
                        page_index=scroll_i + 1,
                        item_name=name,
                        quantity=count,
                        item_id=item_id,
                        row_anchor=row_anchor_confirmed,
                        grid_cols=grid_cols,
                        grid_rows=grid_rows,
                        total_slots=len(slots),
                        profile_id=active_profile.profile_id if active_profile is not None else None,
                    )
                    if (
                        profile_max_unique_items is not None
                        and _unique_scanned_item_count() >= profile_max_unique_items
                    ):
                        self.log(
                            f"  profile max unique items reached: "
                            f"{active_profile.profile_id} "
                            f"({_unique_scanned_item_count()}/{profile_max_unique_items})"
                        )
                        profile_limit_reached = True
                        break
                else:
                    existing_index = next(
                        (idx for idx, existing in enumerate(items) if existing.key() == k),
                        None,
                    )
                    existing = items[existing_index] if existing_index is not None else None
                    existing_meta = getattr(existing, "scan_meta", {}) or {}
                    if (
                        existing is not None
                        and existing_meta.get("status") == "zero_filled"
                        and str(existing.quantity or "").strip() in ("", "0")
                        and str(entry.quantity or "").strip() not in ("", "0")
                    ):
                        entry.index = existing.index
                        entry.scan_meta = dict(entry.scan_meta or {})
                        entry.scan_meta["replaced_zero_fill"] = True
                        items[existing_index] = entry
                        if entry.name:
                            profile_seen_names.add(entry.name)
                            if active_profile is not None:
                                mapped_idx = profile_index_by_name.get(entry.name)
                                if mapped_idx is not None:
                                    profile_cursor = max(profile_cursor, mapped_idx + 1)
                        new_this += 1
                        self.log(
                            f"  {icon} [{entry.index + 1:>3}] {name}  x{count} "
                            f"({detect_source}; zero-fill replaced)"
                        )
                        self._status(
                            "inventory.slot.confirmed",
                            source=source,
                            source_label=source_label,
                            slot_index=slot_idx,
                            slot_number=slot_idx + 1,
                            page_index=scroll_i + 1,
                            item_name=name,
                            quantity=count,
                            item_id=item_id,
                            row_anchor=row_anchor_confirmed,
                            grid_cols=grid_cols,
                            grid_rows=grid_rows,
                            total_slots=len(slots),
                            profile_id=active_profile.profile_id if active_profile is not None else None,
                        )

            if page_shadow_result is not None and page_shadow_authoritative:
                resolved_slots = sum(
                    1 for assignment in page_shadow_result.assignments if assignment.item_id
                )
                self.log(
                    f"  inventory page shadow authoritative result: "
                    f"profile={active_profile.profile_id} page={scroll_i + 1} "
                    f"assigned={resolved_slots} "
                    f"unresolved={len(page_shadow_result.assignments) - resolved_slots} "
                    f"committed={len(page_actual_item_ids)}"
                )
            elif page_shadow_result is not None:
                comparison = page_shadow_result.comparison(page_actual_item_ids)
                self.log(
                    f"  inventory page shadow comparison: profile={active_profile.profile_id} "
                    f"page={scroll_i + 1} "
                    f"comparable={comparison['comparable']} agreed={comparison['agreed']} "
                    f"disagreed={comparison['disagreed']} shadow_only={comparison['shadow_only']} "
                    f"actual_only={comparison['actual_only']}"
                )
                for assignment in page_shadow_result.assignments:
                    actual_item_id = page_actual_item_ids.get(assignment.slot_index)
                    if assignment.item_id != actual_item_id:
                        self._debug(
                            f"  inventory page shadow difference: profile={active_profile.profile_id} "
                            f"page={scroll_i + 1} "
                            f"slot={assignment.slot_index + 1} "
                            f"shadow={assignment.item_id or 'unresolved'} "
                            f"score={assignment.score:.3f} "
                            f"actual={actual_item_id or 'unresolved'}"
                        )

            if active_profile is None:
                active_profile = infer_inventory_scan_profile(source, page_item_ids, page_raw_names)
                if active_profile is not None:
                    expected_count = len(active_profile.expected_item_ids) or len(active_profile.ordered_names)
                    profile_max_unique_items = INVENTORY_PROFILE_MAX_UNIQUE_ITEMS.get(
                        active_profile.profile_id
                    )
                    profile_explicit_slot_scan_limit = INVENTORY_PROFILE_SLOT_SCAN_LIMITS.get(
                        active_profile.profile_id
                    )
                    profile_slot_scan_limit = (
                        min(len(slots), profile_explicit_slot_scan_limit)
                        if profile_explicit_slot_scan_limit is not None
                        else (
                            min(len(slots), profile_max_unique_items)
                            if input_backend is not None
                            and profile_max_unique_items is not None
                            else None
                        )
                    )
                    profile_ordered_names = list(active_profile.ordered_names)
                    profile_ordered_item_ids = list(inventory_profile_ordered_item_ids(active_profile))
                    profile_index_by_name = {name: idx for idx, name in enumerate(profile_ordered_names)}
                    profile_index_by_item_id = {
                        item_id: idx for idx, item_id in enumerate(profile_ordered_item_ids) if item_id
                    }
                    profile_cursor = 0
                    for entry in items:
                        mapped_idx = None
                        if entry.item_id:
                            mapped_idx = profile_index_by_item_id.get(entry.item_id)
                        if mapped_idx is None and entry.name:
                            mapped_idx = profile_index_by_name.get(entry.name)
                        if mapped_idx is not None:
                            profile_cursor = max(profile_cursor, mapped_idx + 1)
                    rebuilt_seen_keys: set[str] = set()
                    rebuilt_profile_names: set[str] = set()
                    for entry in items:
                        if not entry.item_id:
                            normalized_name = resolve_inventory_profile_name(
                                active_profile,
                                entry.name,
                                rebuilt_profile_names,
                            )
                            if normalized_name:
                                entry.name = normalized_name
                        if entry.name:
                            rebuilt_profile_names.add(entry.name)
                        rebuilt_seen_keys.add(entry.key())
                    seen_keys = rebuilt_seen_keys
                    profile_seen_names = rebuilt_profile_names
                    limit_suffix = (
                        f", max_unique={profile_max_unique_items}"
                        if profile_max_unique_items is not None
                        else ""
                    )
                    self.log(
                        f"  inventory profile detected: {active_profile.profile_id} "
                        f"({expected_count} expected{limit_suffix})"
                    )
                    if (
                        profile_max_unique_items is not None
                        and _unique_scanned_item_count() >= profile_max_unique_items
                    ):
                        self.log(
                            f"  profile max unique items reached: "
                            f"{active_profile.profile_id} "
                            f"({_unique_scanned_item_count()}/{profile_max_unique_items})"
                        )
                        profile_limit_reached = True

            fast_suffix = (
                f", fast_grid={fast_grid_entries}, detail={detail_verified_entries}"
                if source in {"item", "equipment"}
                else ""
            )
            self.log(
                f"  scroll {scroll_i+1}: new {new_this} / total {len(items)}"
                f"{fast_suffix}"
            )

            if profile_limit_reached:
                break
            if self._stop_requested():
                break

            if active_profile is not None:
                expected_count = len(active_profile.expected_item_ids) or len(active_profile.ordered_names)
                found_item_ids = {entry.item_id for entry in items if entry.item_id}
                found_names = {entry.name for entry in items if entry.name}
                if is_inventory_profile_complete(active_profile, found_item_ids, found_names):
                    self.log(
                        f"  profile complete: {active_profile.profile_id} "
                        f"({_profile_found_count()}/{expected_count} matched)"
                    )
                    break
                if is_inventory_profile_terminal_seen(active_profile, found_item_ids, found_names):
                    self.log(
                        f"  profile terminal reached: {active_profile.profile_id} "
                        f"({_profile_found_count()}/{expected_count} matched)"
                    )
                    break
                if active_profile.profile_id in INVENTORY_NO_SCROLL_PROFILES:
                    self.log(f"  profile no-scroll: {active_profile.profile_id} -> first page only")
                    break

            if current_page_tail_detected:
                self.log(f"  tail page consumed: total {len(items)}")
                break

            scroll_overlap_rows = 0
            if input_backend is not None and not legacy_scroll:
                moved, after_page = self._advance_inventory_page_with_input(
                    input_backend,
                    slots,
                    grid_r,
                    grid_cols,
                    page,
                )
                next_page_tail_detected = False
            else:
                moved, after_page, current_scroll_amount, scroll_overlap_rows, next_scan_y_offset_px = self._scroll_inventory_page(
                    rect,
                    slots,
                    grid_r,
                    drag_config,
                    current_scroll_amount,
                    grid_cols,
                    scroll_index=scroll_i,
                    debug_dir=scroll_debug_dir,
                    before_y_offset_px=current_scan_y_offset_px,
                    drag_rx_offset=(
                        float(os.environ.get("BA_INVENTORY_ITEM_DRAG_RX_OFFSET", "-0.006"))
                        if source == "item"
                        else 0.0
                    ),
                )
                next_page_tail_detected = bool(getattr(self, "_last_inventory_tail_page_detected", False))
                if next_page_tail_detected:
                    self.log("  next page tail signature detected -> will stop after scanning it")
                if _inventory_overlap_requires_stop(
                    moved,
                    scroll_overlap_rows,
                    tail_page_detected=next_page_tail_detected,
                    stop_on_no_overlap=(
                        os.environ.get("BA_INVENTORY_STOP_ON_NO_SCROLL_OVERLAP", "1") != "0"
                    ),
                ):
                    profile_scan_incomplete = active_profile is not None
                    self.log(
                        "  scroll overlap lost: no duplicated row detected after move "
                        "-> stopping inventory scan to avoid drift/user-interaction corruption"
                    )
                    break
                next_scan_slot_indices = _inventory_scan_indices_after_scroll(
                    len(slots),
                    grid_cols,
                    grid_rows,
                    scroll_overlap_rows,
                    tail_page_detected=next_page_tail_detected,
                )
                if next_scan_slot_indices is None:
                    self.log(
                        f"  row-step scan window fallback: "
                        f"overlap_rows={scroll_overlap_rows} -> all slots"
                    )
                else:
                    self.log(
                        f"  row-step next scan: "
                        f"overlap_rows={scroll_overlap_rows} "
                        f"slots={len(next_scan_slot_indices)}/{len(slots)} "
                        f"y_offset={next_scan_y_offset_px:+d}px"
                    )
                self.log(f"  next drag delta_px={current_scroll_amount}")
            if after_page is None:
                profile_scan_incomplete = active_profile is not None
                if profile_scan_incomplete:
                    self.log(
                        "  scroll failed before next page capture "
                        "-> profile tail zero-fill disabled"
                    )
                break
            if input_backend is not None and not legacy_scroll:
                before_hashes = [slot.icon_hash for slot in page.slots]
                after_hashes = [slot.icon_hash for slot in after_page.slots]
                scroll_overlap_rows = _count_row_overlap(before_hashes, after_hashes, grid_cols)
                next_scan_slot_indices = _new_inventory_slot_indices(
                    len(slots),
                    grid_cols,
                    grid_rows,
                    scroll_overlap_rows,
                )
                self.log(
                    f"  row-step next scan: "
                    f"overlap_rows={scroll_overlap_rows} "
                    f"slots={'all' if next_scan_slot_indices is None else len(next_scan_slot_indices)}/{len(slots)} "
                    f"y_offset={next_scan_y_offset_px:+d}px"
                )
            repeated_last_row = (
                page.last_row_hashes
                and after_page.last_row_hashes
                and page.last_row_hashes == after_page.last_row_hashes
            )
            if not moved:
                self.log(f"  scroll finished: total {len(items)}")
                break
            if repeated_last_row:
                self.log(f"  repeated last row after scroll: total {len(items)}")
                break
            carried_grid_anchor_profile_indices = _carried_inventory_anchor_indices(
                grid_row_anchor_state.anchor_profile_indices(),
                len(slots),
                grid_cols,
                grid_rows,
                scroll_overlap_rows,
            )
            if carried_grid_anchor_profile_indices:
                self._debug(
                    "    carried grid anchors: "
                    + ", ".join(
                        f"slot={slot_idx + 1}->profile={profile_idx}"
                        for slot_idx, profile_idx in sorted(carried_grid_anchor_profile_indices.items())
                    )
                )
            ui_next_scan_slot_indices = _new_inventory_slot_indices(
                len(slots),
                grid_cols,
                grid_rows,
                scroll_overlap_rows,
            )
            self._status(
                "inventory.scroll",
                source=source,
                source_label=source_label,
                scroll_index=scroll_i + 1,
                next_page_index=scroll_i + 2,
                grid_cols=grid_cols,
                grid_rows=grid_rows,
                total_slots=len(slots),
                overlap_rows=scroll_overlap_rows,
                moved_rows=max(0, grid_rows - scroll_overlap_rows),
                # A tail page is intentionally scanned in full for verification,
                # but the live UI should only highlight rows newly exposed by
                # the scroll.  Otherwise carried overlap rows look like duplicate
                # user-visible work even though duplicate keys are not committed.
                scan_slots=(
                    sorted(ui_next_scan_slot_indices)
                    if ui_next_scan_slot_indices is not None
                    else None
                ),
                y_offset_px=next_scan_y_offset_px,
            )
        if active_profile is not None:
            if profile_cursor < len(profile_ordered_names):
                if profile_scan_incomplete:
                    self.log(
                        f"  profile tail zero-fill skipped: scan incomplete "
                        f"cursor={profile_cursor} end={len(profile_ordered_names)}"
                    )
                else:
                    self._append_profile_gap_entries(
                        items,
                        seen_keys,
                        profile_seen_names,
                        active_profile,
                        profile_ordered_names,
                        profile_ordered_item_ids,
                        source,
                        profile_cursor,
                        len(profile_ordered_names),
                    )
            items = self._fill_missing_profile_entries(items, active_profile, source)
        if input_backend is not None:
            input_backend.close()
        return items
    def capture_inventory_scroll_debug(
        self,
        section: str,
        source: str,
        drag_config: InventoryDragConfig,
        scroll_amount: int,
        debug_dir: Path,
        *,
        focus_anchor_before_scroll: bool = False,
    ) -> dict:
        """Capture inventory scroll movement without reading grid contents."""
        r_sec = self.r[section]
        slots = r_sec["grid_slots"]
        grid_r = _grid_region(slots)

        rect = self._rect()
        if not rect:
            self.log("window not found")
            return {"ok": False, "reason": "window_not_found", "scrolls": 0}

        debug_dir.mkdir(parents=True, exist_ok=True)
        grid_cols = int(r_sec.get("grid_cols", 0))
        grid_rows = int(r_sec.get("grid_rows", 0))
        if grid_cols <= 0:
            grid_cols = max(1, int(round(len(slots) ** 0.5)))
        if grid_rows <= 0:
            grid_rows = max(1, (len(slots) + grid_cols - 1) // grid_cols)

        self.log(
            f"[debug] {source} scroll capture start: "
            f"slots={len(slots)} grid={grid_cols}x{grid_rows} dir={debug_dir}"
        )
        self._reset_inventory_scan_state(source)

        profile_id = self._forced_inventory_profile_id
        if profile_id in INVENTORY_NO_SCROLL_PROFILES:
            stop_reason = "profile_no_scroll"
            summary = {
                "ok": True,
                "section": section,
                "source": source,
                "profile_id": profile_id,
                "focus_anchor_before_scroll": bool(focus_anchor_before_scroll),
                "grid_cols": grid_cols,
                "grid_rows": grid_rows,
                "slot_count": len(slots),
                "scrolls": [],
                "stop_reason": stop_reason,
                "debug_dir": str(debug_dir),
            }
            (debug_dir / "debug_capture_summary.json").write_text(
                json.dumps(summary, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            self.log(f"[debug] {source} scroll capture skipped: profile={profile_id} no-scroll")
            return summary

        seen_hashes: list[str] = []
        current_scroll_amount = scroll_amount
        next_scan_slot_indices: set[int] | None = None
        next_scan_y_offset_px = 0
        scroll_rows: list[dict] = []
        stop_reason = "max_scrolls"

        for scroll_i in range(MAX_SCROLLS):
            if self._stop_requested():
                stop_reason = "stop_requested"
                break

            current_scan_slot_indices = next_scan_slot_indices
            current_scan_y_offset_px = next_scan_y_offset_px
            next_scan_slot_indices = None
            next_scan_y_offset_px = 0
            if current_scan_slot_indices is not None:
                if not current_scan_slot_indices:
                    stop_reason = "empty_next_scan_window"
                    self.log("  row-step scan window empty -> stopping")
                    break
                self.log(
                    f"  row-step scan window skipped for debug: "
                    f"{len(current_scan_slot_indices)}/{len(slots)} slots "
                    f"y_offset={current_scan_y_offset_px:+d}px"
                )

            img = self._capture()
            if img is None:
                stop_reason = "capture_failed"
                break

            active_slots = _shift_slots_y(slots, current_scan_y_offset_px, img.size) if current_scan_y_offset_px else slots
            active_grid_r = _grid_region(active_slots) if current_scan_y_offset_px else grid_r
            grid_crop = crop_region(img, active_grid_r)
            cur_hash = _img_hash(grid_crop)
            page = self._capture_inventory_page(
                img,
                active_slots,
                grid_hash=cur_hash,
                page_index=scroll_i,
                grid_cols=grid_cols,
            )

            if cur_hash in seen_hashes:
                stop_reason = "duplicate_grid_hash"
                self.log("  repeated grid hash before drag -> stopping")
                break
            seen_hashes.append(cur_hash)
            if len(seen_hashes) > 10:
                seen_hashes.pop(0)

            moved, after_page, current_scroll_amount, scroll_overlap_rows, next_scan_y_offset_px = self._scroll_inventory_page(
                rect,
                slots,
                grid_r,
                drag_config,
                current_scroll_amount,
                grid_cols,
                scroll_index=scroll_i,
                debug_dir=debug_dir,
                before_y_offset_px=current_scan_y_offset_px,
                drag_rx_offset=(
                    float(os.environ.get("BA_INVENTORY_ITEM_DRAG_RX_OFFSET", "-0.006"))
                    if source == "item"
                    else 0.0
                ),
                focus_anchor_before_capture=focus_anchor_before_scroll,
            )
            tail_page_detected = bool(getattr(self, "_last_inventory_tail_page_detected", False))
            next_scan_slot_indices = _new_inventory_slot_indices(
                len(slots),
                grid_cols,
                grid_rows,
                scroll_overlap_rows,
            )
            scroll_rows.append(
                {
                    "scroll_index": scroll_i,
                    "moved": bool(moved),
                    "overlap_rows": scroll_overlap_rows,
                    "next_scan_slots": (
                        sorted(next_scan_slot_indices)
                        if next_scan_slot_indices is not None
                        else None
                    ),
                    "next_y_offset_px": next_scan_y_offset_px,
                    "next_drag_delta_px": current_scroll_amount,
                    "tail_page_detected": tail_page_detected,
                }
            )

            if tail_page_detected:
                stop_reason = "tail_page_detected"
                self.log("  tail page signature detected -> stopping debug capture")
                break

            if (
                moved
                and scroll_overlap_rows <= 0
                and os.environ.get("BA_INVENTORY_STOP_ON_NO_SCROLL_OVERLAP", "1") != "0"
            ):
                stop_reason = "overlap_lost"
                self.log(
                    "  scroll overlap lost: no duplicated row detected after move "
                    "-> stopping debug capture"
                )
                break
            if after_page is None:
                stop_reason = "scroll_failed"
                self.log("  scroll failed before next page capture -> stopping debug capture")
                break

            repeated_last_row = (
                page.last_row_hashes
                and after_page.last_row_hashes
                and page.last_row_hashes == after_page.last_row_hashes
            )
            if not moved:
                stop_reason = "not_moved"
                self.log("  scroll finished: no movement")
                break
            if repeated_last_row:
                stop_reason = "repeated_last_row"
                self.log("  repeated last row after scroll")
                break

            self.log(
                f"  debug scroll {scroll_i + 1}: "
                f"overlap_rows={scroll_overlap_rows} "
                f"next_slots={'all' if next_scan_slot_indices is None else len(next_scan_slot_indices)} "
                f"y_offset={next_scan_y_offset_px:+d}px "
                f"next_delta_px={current_scroll_amount}"
            )

        summary = {
            "ok": stop_reason not in {"window_not_found", "capture_failed"},
            "section": section,
            "source": source,
            "profile_id": self._forced_inventory_profile_id,
            "focus_anchor_before_scroll": bool(focus_anchor_before_scroll),
            "grid_cols": grid_cols,
            "grid_rows": grid_rows,
            "slot_count": len(slots),
            "scrolls": scroll_rows,
            "stop_reason": stop_reason,
            "debug_dir": str(debug_dir),
        }
        (debug_dir / "debug_capture_summary.json").write_text(
            json.dumps(summary, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        self.log(
            f"[debug] {source} scroll capture done: "
            f"scrolls={len(scroll_rows)} reason={stop_reason}"
        )
        return summary
    def scan_items(
        self,
        inventory_profile_id: str | list[str] | tuple[str, ...] | None = None,
        *,
        navigate_from_menu: bool = True,
        return_to_lobby: bool = True,
    ) -> list[ItemEntry]:
        self.log("[scan] item scan start")
        self._debug(
            "item scan context: "
            f"navigate_from_menu={navigate_from_menu} "
            f"return_to_lobby={return_to_lobby} "
            f"profiles={self._item_scan_profiles(inventory_profile_id)} "
            f"icon_templates={len(_inventory_template_catalog('item'))}"
        )
        prev_forced_profile_id = self._forced_inventory_profile_id
        try:
            if navigate_from_menu:
                if not self._open_menu():
                    return []
            else:
                self.log("  using current item inventory screen")
            item_profiles = self._item_scan_profiles(inventory_profile_id)
            all_items: list[ItemEntry] = []
            sort_rule_checked = False

            for index, profile_id in enumerate(item_profiles, start=1):
                profile_label = profile_id or "all"
                self.log(f"[scan] item pass {index}/{len(item_profiles)} profile={profile_label}")
                self._forced_inventory_profile_id = profile_id
                if navigate_from_menu:
                    if not self._go_to("item_entry_button", "items"):
                        return all_items
                    if not self._wait(0.5):
                        return all_items
                if not self._prepare_item_inventory(profile_id, ensure_sort_rule=not sort_rule_checked):
                    self.log("  item inventory prepare failed; item scan stopped without lobby retry")
                    return all_items
                sort_rule_checked = True
                self._reset_inventory_scan_state("item")
                result = self._scan_grid("item", "item", ITEM_INVENTORY_DRAG, ITEM_INVENTORY_DRAG.delta_px)
                all_items.extend(result)
                self.log(f"[scan] item pass done: {len(result)} entries")
                if navigate_from_menu and index < len(item_profiles):
                    if not self._exit_inventory_to_menu():
                        return all_items

            self.log(f"[scan] item scan done: {len(all_items)} entries")
            return all_items
        except Exception as e:
            self.log(f"item scan error: {e}")
            _log.exception("item scan error")
            return []
        finally:
            self._forced_inventory_profile_id = prev_forced_profile_id
            if return_to_lobby:
                self._return_inventory_to_lobby()
    def scan_equipment(
        self,
        *,
        navigate_from_menu: bool = True,
        return_to_lobby: bool = True,
    ) -> list[ItemEntry]:
        self.log("[scan] equipment scan start")
        self._debug(
            "equipment scan context: "
            f"navigate_from_menu={navigate_from_menu} "
            f"return_to_lobby={return_to_lobby} "
            f"icon_templates={len(_inventory_template_catalog('equipment'))} "
            f"detail_templates={len(_inventory_detail_template_catalog('equipment'))}"
        )
        prev_forced_profile_id = self._forced_inventory_profile_id
        try:
            self._forced_inventory_profile_id = "equipment"
            if navigate_from_menu:
                if not self._open_menu():
                    return []
                if not self._go_to("equipment_entry_button", "equipment"):
                    return []
                if not self._wait(0.5):
                    return []
            else:
                self.log("  using current equipment inventory screen")
            if not self._prepare_equipment_inventory():
                self.log("  equipment inventory prepare failed; equipment scan stopped without lobby retry")
                return []
            self._reset_inventory_scan_state("equipment")
            result = self._scan_grid(
                "equipment",
                "equipment",
                EQUIPMENT_INVENTORY_DRAG,
                EQUIPMENT_INVENTORY_DRAG.delta_px,
            )
            self.log(f"[scan] equipment scan done: {len(result)} entries")
            return result
        except Exception as e:
            self.log(f"equipment scan error: {e}")
            _log.exception("equipment scan error")
            return []
        finally:
            self._forced_inventory_profile_id = prev_forced_profile_id
            if return_to_lobby:
                self._return_inventory_to_lobby()
