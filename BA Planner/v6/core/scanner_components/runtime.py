"""ScannerRuntimeComponent implementation extracted from the Scanner façade."""

from __future__ import annotations

from core import scanner_shared as _scanner_shared

globals().update({name: value for name, value in vars(_scanner_shared).items() if not name.startswith("__")})


class ScannerRuntimeComponent:
    def __init__(
        self,
        regions: dict,
        on_progress: Optional[Callable[[str], None]] = None,
        on_progress_state: Optional[Callable[[dict], None]] = None,
        on_status_event: Optional[Callable[[dict], None]] = None,
        on_status_ack_wait: Optional[Callable[[int], bool]] = None,
        maxed_ids:   Optional[set[str]]  = None,
        maxed_saved_data: Optional[dict[str, dict]] = None,
        student_saved_data: Optional[dict[str, dict]] = None,
        student_total_hint: Optional[int] = None,
        autosave_manager = None,   # AutoSaveManager | None
        inventory_profile_id: str | list[str] | tuple[str, ...] | None = None,
        fast_student_ids: Optional[list[str]] = None,
        inventory_detail_override_dir: str | os.PathLike | None = None,
        inventory_capture_resolution: object = None,
    ):
        self.r             = regions
        self._on_progress  = on_progress
        self._on_progress_state = on_progress_state
        self._on_status_event = on_status_event
        self._on_status_ack_wait = on_status_ack_wait
        self._status_seq = 0
        self._last_status_seq = 0
        self._stop         = False
        self._space_stop_latched = False
        self._maxed_saved_data: dict[str, dict] = {}
        self._student_total_hint = None
        self._asv          = autosave_manager   # AutoSaveManager or None
        self._student_basic_img: Optional[Image.Image] = None
        self._student_basic_crops: Optional[ScreenCropSet] = None
        self._student_equipment_crops: Optional[ScreenCropSet] = None
        self._student_stat_crops: Optional[ScreenCropSet] = None
        self._captured_click_points = self._load_captured_click_points()
        self._active_student_panel: str | None = None
        self._panel_transition_history: dict[str, list[float]] = {}
        self._panel_title_score_history: dict[str, list[float]] = {}
        self._basic_level_run_templates: dict[int, dict[str, list[np.ndarray]]] = {}
        self._equip_level_run_templates: dict[int, dict[str, list[np.ndarray]]] = {}
        self._basic_equip_level_run_templates: dict[int, dict[int, dict[str, list[np.ndarray]]]] = {}
        self._basic_equip_tier_run_templates: dict[int, dict[str, list[np.ndarray]]] = {}
        self._inventory_icon_cache: dict[str, dict[str, tuple[str | None, str, str | None]]] = {
            "item": {},
            "equipment": {},
        }
        self._inventory_failed_hashes: dict[str, set[str]] = {
            "item": set(),
            "equipment": set(),
        }
        self._default_inventory_profile_ids = normalize_inventory_profile_ids(inventory_profile_id)
        self._inventory_detail_override_dir = (
            Path(inventory_detail_override_dir)
            if inventory_detail_override_dir
            else None
        )
        self._inventory_capture_resolution = inventory_resolution_key(inventory_capture_resolution)
        self._forced_inventory_profile_id: str | None = (
            None
            if not self._default_inventory_profile_ids or self._default_inventory_profile_ids == ("all",)
            else self._default_inventory_profile_ids[0]
        )

        _log.debug(
            "scanner init: asset_dir=%s template_dir=%s inventory_profiles=%s detail_override=%s",
            ASSET_DIR,
            TEMPLATE_DIR,
            self._default_inventory_profile_ids or ("all",),
            self._inventory_detail_override_dir,
        )
    def stop(self) -> None:
        self._stop = True
        _log.info("scan stop requested")
        self._status("stop.requested")
    def clear_stop(self) -> None:
        self._stop = False
        self._space_stop_latched = False
    def _stop_requested(self) -> bool:
        if not self._stop and _space_key_down():
            self._stop = True
            if not self._space_stop_latched:
                self._space_stop_latched = True
                self._info("[stop] Spacebar emergency stop requested")
                self._status("stop.spacebar")
                _log.info("spacebar emergency stop requested")
        return self._stop
    def _wait(self, seconds: float, step: float = 0.05) -> bool:
        end = time.monotonic() + max(0.0, seconds)
        poll_step = max(0.001, step)
        while True:
            if self._stop_requested():
                return False
            remaining = end - time.monotonic()
            if remaining <= 0:
                break
            time.sleep(min(poll_step, remaining))
        return not self._stop_requested()
    def _panel_transition_initial_wait(self, key: str) -> float:
        samples = self._panel_transition_history.get(key, ())
        if len(samples) < 3:
            return PANEL_TRANSITION_INITIAL_WAIT
        ordered = sorted(samples)
        middle = len(ordered) // 2
        median = (
            ordered[middle]
            if len(ordered) % 2
            else (ordered[middle - 1] + ordered[middle]) / 2.0
        )
        return max(
            PANEL_TRANSITION_MIN_WAIT,
            min(PANEL_TRANSITION_MAX_WAIT, median - PANEL_TRANSITION_LEAD),
        )
    def _record_panel_transition(
        self,
        key: str,
        elapsed: float,
        *,
        success: bool,
        initial_wait: float,
    ) -> None:
        samples = self._panel_transition_history.setdefault(key, [])
        if success:
            samples.append(max(0.0, elapsed))
            del samples[:-PANEL_TRANSITION_HISTORY_SIZE]
        median = sorted(samples)[len(samples) // 2] if samples else 0.0
        _log.info(
            "[panel_transition] key=%s elapsed=%.3fs initial=%.3fs success=%s samples=%d median=%.3fs",
            key,
            elapsed,
            initial_wait,
            str(success).lower(),
            len(samples),
            median,
        )
    def _reset_panel_transition_history(self) -> None:
        self._panel_transition_history.clear()
        self._panel_title_score_history.clear()
        self._basic_level_run_templates.clear()
        equip_templates = getattr(self, "_equip_level_run_templates", None)
        if equip_templates is not None:
            equip_templates.clear()
        _log.info("[panel_transition] history reset for new student scan run")
    def _panel_title_score_threshold(self, panel_name: str) -> float:
        samples = self._panel_title_score_history.get(panel_name, ())
        if not samples:
            return STUDENT_PANEL_TITLE_MIN_SCORE
        ordered = sorted(samples)
        middle = len(ordered) // 2
        median = (
            ordered[middle]
            if len(ordered) % 2
            else (ordered[middle - 1] + ordered[middle]) / 2.0
        )
        return max(
            STUDENT_PANEL_TITLE_ADAPTIVE_FLOOR,
            min(STUDENT_PANEL_TITLE_MIN_SCORE, median - STUDENT_PANEL_TITLE_ADAPTIVE_LEAD),
        )
    def _record_panel_title_score(self, panel_name: str, score: float) -> None:
        samples = self._panel_title_score_history.setdefault(panel_name, [])
        samples.append(float(score))
        del samples[:-STUDENT_PANEL_TITLE_HISTORY_SIZE]
        threshold = self._panel_title_score_threshold(panel_name)
        _log.info(
            "[panel_title_calibration] panel=%s score=%.3f threshold=%.3f samples=%d",
            panel_name,
            score,
            threshold,
            len(samples),
        )
    def _load_captured_click_points(self) -> dict[str, dict]:
        path = Path(CAPTURED_CLICK_POINTS_FILE)
        try:
            if path.exists():
                raw = json.loads(path.read_text(encoding="utf-8"))
                if isinstance(raw, dict):
                    _log.info("[coord_capture] loaded %d points from %s", len(raw), path)
                    return raw
        except Exception as exc:
            _log.warning("[coord_capture] failed to load %s: %s", path, exc)
        return {}
    def _click_ratio_point(self, rx: float, ry: float, label: str = "", delay: float = 0.0) -> bool:
        rect = self._rect()
        if rect is None:
            _log.warning(f"[click] rect missing: {label}")
            return False
        hwnd = self._hwnd()
        if not hwnd:
            _log.warning(f"[click] hwnd missing: {label}")
            return False
        cx, cy = ratio_to_client(rect, rx, ry)
        ok = click_point(hwnd, cx, cy, label=label, delay=delay)
        _log.debug(
            f"[click] {label} ratio=({rx:.6f},{ry:.6f}) client=({cx},{cy}) ok={ok}"
        )
        return ok
    def _click_captured_point(self, name: str, *, label: str = "", delay: float = 0.0) -> bool:
        point = self._captured_click_points.get(name)
        if not isinstance(point, dict):
            return False
        ratio = point.get("ratio")
        if not isinstance(ratio, dict):
            return False
        try:
            rx = float(ratio["x"])
            ry = float(ratio["y"])
        except Exception:
            return False
        return self._click_ratio_point(rx, ry, label=label or name, delay=delay)
    def _click_region_capture(self, name: str, *, label: str = "", delay: float = 0.0) -> bool:
        region = _region_capture_region(name)
        if region is None:
            self.log(f"warning: missing region capture {name}")
            return False
        clicked = self._click_r(region, label or name)
        if clicked and delay > 0:
            return self._wait(delay)
        return clicked
    def _click_region_capture_x_from_y(
        self,
        x_name: str,
        y_name: str,
        *,
        label: str = "",
        delay: float = 0.0,
    ) -> bool:
        x_region = _region_capture_region(x_name)
        y_region = _region_capture_region(y_name)
        if x_region is None or y_region is None:
            self.log(f"warning: missing mixed region capture x={x_name} y={y_name}")
            return False
        region = {
            "x1": x_region["x1"],
            "x2": x_region["x2"],
            "y1": y_region["y1"],
            "y2": y_region["y2"],
        }
        clicked = self._click_r(region, label or f"{x_name}_x_{y_name}_y")
        if clicked and delay > 0:
            return self._wait(delay)
        return clicked
    def _region_capture_match_score(self, name: str) -> float | None:
        region = _region_capture_region(name)
        template_path = _region_capture_reference_path(name)
        if region is None or not template_path:
            return None
        img = self._capture()
        if img is None:
            return None
        crop = crop_region(img, region)
        return match_score_resized(crop, template_path, focus_center=True)
    def _wait_for_region_capture_match(
        self,
        name: str,
        *,
        threshold: float,
        timeout: float,
        initial_wait: float = 0.0,
        poll: float = UI_FLAG_POLL,
    ) -> bool:
        if initial_wait > 0 and not self._wait(initial_wait):
            return False
        deadline = time.monotonic() + timeout
        last_score: float | None = None
        while time.monotonic() < deadline:
            if self._stop_requested():
                return False
            score = self._region_capture_match_score(name)
            last_score = score
            if score is not None and score >= threshold:
                self._debug(f"  {name} ready score={score:.3f}")
                return True
            if not self._wait(poll):
                return False
        if last_score is None:
            self.log(f"  {name} ready check unavailable")
        else:
            self.log(f"  {name} ready timeout score={last_score:.3f} < {threshold:.2f}")
        return False
    def _debug(self, msg: str) -> None:
        _log.debug(msg)
    def _info(self, msg: str) -> None:
        _log.info(msg)
        if self._on_progress:
            self._on_progress(msg)
    def _emit_progress_state(
        self,
        *,
        current: int | None = None,
        total: int | None = None,
        note: str = "",
    ) -> None:
        if self._on_progress_state:
            self._on_progress_state(
                {
                    "current": current,
                    "total": total,
                    "note": note,
                }
            )
    def _status(self, event_id: str, **fields) -> int | None:
        callback = getattr(self, "_on_status_event", None)
        if not callback:
            return None
        try:
            self._status_seq = int(getattr(self, "_status_seq", 0)) + 1
            event = make_status_event(event_id, data=fields)
            event["seq"] = self._status_seq
            callback(event)
            self._last_status_seq = self._status_seq
            return self._status_seq
        except Exception:
            _log.exception("scan status callback failed: %s", event_id)
            return None
    def _status_skill_value(self, entry: StudentEntry, field_name: str, value: object) -> None:
        if value is None:
            return
        label_map = {
            "ex_skill": "EX",
            "skill1": "basic",
            "skill2": "enhanced",
            "skill3": "sub",
        }
        self._status(
            "skills.value.ok",
            student_name=entry.display_name,
            skill=field_name,
            label=label_map.get(field_name, field_name),
            value=value,
        )
        self._field_confirmed(entry, field_name, value)
    def _field_confirmed(
        self,
        entry: StudentEntry,
        field_name: str,
        value: object,
        *,
        label: str | None = None,
        display_value: str | None = None,
    ) -> int | None:
        if value is None:
            return None
        label_map = {
            "level": "level",
            "student_star": "student star",
            "weapon_star": "weapon star",
            "weapon_level": "weapon level",
            "ex_skill": "EX skill",
            "skill1": "basic skill",
            "skill2": "enhanced skill",
            "skill3": "sub skill",
            "equip1": "equipment 1 tier",
            "equip2": "equipment 2 tier",
            "equip3": "equipment 3 tier",
            "equip1_level": "equipment 1 level",
            "equip2_level": "equipment 2 level",
            "equip3_level": "equipment 3 level",
            "equip4": "favorite item",
            "stat_hp": "bonus hp",
            "stat_atk": "bonus atk",
            "stat_heal": "bonus heal",
            "combat_hp": "HP",
            "combat_atk": "ATK",
            "combat_def": "DEF",
            "combat_heal": "HEAL",
        }
        return self._status(
            "field.confirmed",
            student_id=entry.student_id,
            student_name=entry.display_name,
            field=field_name,
            value=value,
            label=label or label_map.get(field_name, field_name),
            display_value=display_value or str(value),
        )
    def _wait_ui_status_flush(self, seq: int | None = None, *, label: str = "") -> bool:
        if not self._on_status_ack_wait:
            return True
        target = int(seq or self._last_status_seq or 0)
        if target <= 0:
            return True
        ok = self._on_status_ack_wait(target)
        if not ok:
            _log.debug("ui status flush timeout: seq=%s label=%s", target, label)
        return ok
    @contextmanager
    def _perf_step(self, label: str, **fields) -> Iterator[None]:
        """Log elapsed time for one scanner step into the per-scan debug log."""
        started = time.perf_counter()
        try:
            yield
        finally:
            elapsed = time.perf_counter() - started
            extras = " ".join(
                f"{key}={value}"
                for key, value in fields.items()
                if value is not None
            )
            suffix = f" {extras}" if extras else ""
            _log.info("[perf] %s elapsed=%.3fs%s", label, elapsed, suffix)
    def _warn(self, msg: str) -> None:
        _log.warning(msg)
        if self._on_progress:
            self._on_progress(f"??????????????????ш끽維뽳쭩?뱀땡???얩맪???????????????????轅붽틓??섑떊???⑤챷??????????????????{msg}")
    def _error(self, msg: str) -> None:
        _log.error(msg)
        if self._on_progress:
            self._on_progress(f"????????????????{msg}")
    @property
    def log(self):
        return self._info
    def _capture(self, retry: int = RETRY_CAPTURE) -> Optional[Image.Image]:
        """Capture the game window, retrying briefly on failure."""
        started = time.perf_counter()
        for i in range(retry + 1):
            if self._stop_requested():
                _log.debug(
                    "[perf] capture elapsed=%.3fs success=false reason=stop attempt=%d",
                    time.perf_counter() - started,
                    i + 1,
                )
                return None
            img = capture_window_background()
            if img is not None:
                source_size = img.info.get("capture_source_size", img.size)
                try:
                    source_w, source_h = source_size
                except (TypeError, ValueError):
                    source_w, source_h = img.size
                self._inventory_capture_resolution = inventory_resolution_key((source_w, source_h))
                _log.debug(
                    "[perf] capture elapsed=%.3fs success=true attempt=%d "
                    "source_size=%sx%s normalized_size=%sx%s size=%sx%s",
                    time.perf_counter() - started,
                    i + 1,
                    source_w,
                    source_h,
                    img.width,
                    img.height,
                    img.width,
                    img.height,
                )
                return img
            if i < retry:
                _log.debug(f"capture retry ({i+1}/{retry})")
                if not self._wait(0.1):
                    _log.debug(
                        "[perf] capture elapsed=%.3fs success=false reason=wait_stop attempt=%d",
                        time.perf_counter() - started,
                        i + 1,
                    )
                    return None
        self._error("capture failed")
        self._status("capture.failed")
        _log.info(
            "[perf] capture elapsed=%.3fs success=false attempts=%d",
            time.perf_counter() - started,
            retry + 1,
        )
        return None
    def _rect(self) -> Optional[tuple[int, int, int, int]]:
        return get_window_rect()
    def _hwnd(self) -> Optional[int]:
        return find_target_hwnd()
    def _retry(
        self,
        fn: Callable,
        max_attempts: int = 2,
        delay: float = 0.3,
        label: str = "",
    ):
        """Retry fn() until it returns a non-None result or attempts run out."""




        for i in range(max_attempts):
            if self._stop_requested():
                return None
            result = fn()
            if result is not None:
                return result
            if i < max_attempts - 1:
                self.log(f"  ?????{label} ({i+2}/{max_attempts})")
                if not self._wait(delay):
                    return None
        return None
    def _click_r(self, region: dict, label: str = "") -> bool:
        """Click the center point of a ratio region."""
        rect = self._rect()
        if rect is None:
            _log.warning(f"[click] window rect missing: {label}")
            return False
        hwnd = self._hwnd()
        rx = (region["x1"] + region["x2"]) / 2
        ry = (region["y1"] + region["y2"]) / 2
        if hwnd:
            cx, cy = ratio_to_client(rect, rx, ry)
            ok = click_point(hwnd, cx, cy, label=label)
            _log.debug(
                f"[click] {label} hwnd={hwnd} ratio=({rx:.4f},{ry:.4f}) "
                f"client=({cx},{cy}) ok={ok}"
            )
            return ok
        ok = click_center(rect, region, label)
        _log.debug(f"[click] {label} ratio=({rx:.4f},{ry:.4f}) fallback ok={ok}")
        return ok
    def _tab(self, region_key: str, delay: float = DELAY_TAB_SWITCH) -> bool:
        """Click a student tab/button region and wait for it to settle."""
        sr = self.r["student"]
        region = sr.get(region_key)
        if not region:
            self.log(f"  warning: {region_key} missing -> skipped")
            return False
        ok = self._click_r(region, region_key)
        if delay > 0:
            if not self._wait(delay):
                return False
        return ok
    def _esc(self, n: int = 1, delay: float = PANEL_CLOSE_SETTLE_WAIT) -> None:
        """Close the current panel, usually via ESC fallback logic."""
        hwnd = self._hwnd()
        for _ in range(n):
            if self._stop_requested():
                return
            if n == 1 and self._close_active_student_panel(wait=delay):
                return
            if hwnd:
                send_escape(hwnd, delay=delay)
            else:
                press_esc()
    def run_full_scan(self) -> ScanResult:
        self.clear_stop()
        result = ScanResult()
        self.log("[scan] full scan start")
        result.resources = self.scan_resources()
        result.items     = self.scan_items()
        if not self._stop_requested():
            result.equipment = self.scan_equipment()
        if not self._stop_requested():
            result.students  = self.scan_students()
        self.log("[scan] full scan done")
        return result
