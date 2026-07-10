"""StudentScannerComponent implementation extracted from the Scanner façade."""

from __future__ import annotations

from core import scanner_shared as _scanner_shared

globals().update({name: value for name, value in vars(_scanner_shared).items() if not name.startswith("__")})


class StudentScannerComponent:
    def _close_student_panel(
        self,
        *,
        capture_name: str | None = None,
        region_key: str | None = None,
        settle_reason: str,
        wait: float = PANEL_CLOSE_SETTLE_WAIT,
    ) -> bool:
        sr = self.r["student"]
        self._active_student_panel = None
        started = time.perf_counter()
        clicked = False
        if region_key and region_key in sr:
            clicked = self._click_r(sr[region_key], region_key)
        if (not clicked) and capture_name:
            clicked = self._click_captured_point(capture_name, label=capture_name)
        if not clicked:
            self._esc(delay=wait)
            started = time.perf_counter()
        ok = self._settle_student_detail(
            settle_reason,
            transition_key=f"close:{settle_reason}",
            started_at=started,
        )
        if not ok:
            self._esc(delay=wait)
            ok = self._settle_student_detail(f"{settle_reason}_esc_retry", initial_wait=0.0)
        return ok
    def _panel_close_spec(self, panel_name: str) -> tuple[str | None, str | None, str]:
        if panel_name == "skill":
            return "skill_close_button", "skillmenu_quit_button", "close_skill_menu"
        if panel_name == "weapon":
            return "weapon_close_button", "weapon_menu_quit_button", "close_weapon_menu"
        if panel_name == "equipment":
            return "equipment_close_button", "equipmentmenu_quit_button", "close_equipment_menu"
        if panel_name == "stat":
            return "stat_close_button", "statmenu_quit_button", "close_stat_menu"
        return None, None, "close_panel"
    def _close_active_student_panel(self, *, wait: float = PANEL_CLOSE_SETTLE_WAIT) -> bool:
        panel_name = self._active_student_panel
        if not panel_name:
            return False
        capture_name, region_key, settle_reason = self._panel_close_spec(panel_name)
        self._active_student_panel = None
        sr = self.r["student"]
        started = time.perf_counter()
        clicked = False
        if region_key and region_key in sr:
            clicked = self._click_r(sr[region_key], region_key)
        if (not clicked) and capture_name:
            clicked = self._click_captured_point(capture_name, label=capture_name)
        if not clicked:
            return False
        ok = self._settle_student_detail(
            settle_reason,
            transition_key=f"close:{settle_reason}",
            started_at=started,
        )
        if not ok:
            self._esc(delay=wait)
            ok = self._settle_student_detail(f"{settle_reason}_esc_retry", initial_wait=0.0)
        return ok
    def begin_student_scan(self, student_id: str) -> StudentEntry:
        """Create a temporary student entry at the start of a scan."""
        entry = StudentEntry(
            student_id=student_id,
            display_name=student_meta.display_name(student_id),
            scan_state=ScanState.TEMP,
        )
        self._status("student.scan.start", student_id=student_id, student_name=entry.display_name)
        _log.debug(f"[TEMP] start: {entry.label()}")
        return entry
    def _mark_favorite_item_unsupported(self, entry: StudentEntry, sid: str) -> None:
        entry.equip4 = EquipSlotFlag.NULL.value
        entry.set_meta("equip4", FieldMeta.skipped("favorite_item_unsupported"))
        self._status("favorite.unsupported", student_name=entry.display_name or student_meta.display_name(sid))
        self.log(f"  ????: {sid}??equip4 ???????????????????????????嫄?????????耀붾굝???????⑤슢??筌믩끃異?????????????????????????????룸㎗????꿔꺂?????????????????????????????곕춴???????????곕춴??????????????-> null")
    def finalize_student_entry(
        self,
        entry:   StudentEntry,
        ctx:     "ScanCtx",
        *,
        partial_ok: bool = True,
    ) -> EntryCommitResult:
        """Validate a temporary student entry before it is committed."""


















        if not entry.student_id:
            entry.scan_state = ScanState.FAILED
            self._status("student.scan.failed", student_name=entry.display_name or "")
            return EntryCommitResult(
                entry=entry, committed=False,
                missing=[], confidence=0.0,
                reason="student_id missing",
            )

        missing    = entry.missing_fields()
        confidence = entry.confidence()

        if not missing:
            # All required fields were filled, so the entry can be committed.
            entry.scan_state = ScanState.COMMITTED

            # Still log if any field succeeded with low confidence.
            uncertain = entry.uncertain_fields()
            if uncertain:
                self._status(
                    "summary.student.uncertain",
                    student_name=entry.display_name,
                    fields=", ".join(uncertain),
                )
                _log.warning(
                    f"{ctx} warning: committed with uncertain fields: {uncertain}"
                )
            else:
                _log.info(
                    f"{ctx} COMMITTED "
                    f"(confidence={confidence:.2f})"
                )
            return EntryCommitResult(
                entry=entry, committed=True,
                missing=[], confidence=confidence,
            )

        # Missing fields are allowed in partial mode.
        if partial_ok:
            entry.scan_state = ScanState.PARTIAL
            self._status("student.scan.partial_commit", student_name=entry.display_name)
            _log.warning(
                f"{ctx} warning: PARTIAL "
                f"(confidence={confidence:.2f} missing={missing})"
            )
            return EntryCommitResult(
                entry=entry, committed=True,
                missing=missing, confidence=confidence,
                reason=f"missing={missing}",
            )

        # In strict mode, missing required fields make the entry fail.
        entry.scan_state = ScanState.FAILED
        self._status("student.scan.failed", student_name=entry.display_name)
        _log.warning(
            f"{ctx} FAILED (strict) "
            f"(confidence={confidence:.2f} missing={missing})"
        )
        return EntryCommitResult(
            entry=entry, committed=False,
            missing=missing, confidence=confidence,
            reason=f"strict_fail missing={missing}",
        )
    def commit_student_entry(
        self,
        result:  EntryCommitResult,
        results: list[StudentEntry],
        idx:     int,
    ) -> bool:
        """Append a validated entry to the results list when allowed."""
        entry = result.entry
        if not result.committed:
            self._status("student.scan.failed", student_name=entry.display_name)
            _log.warning(
                f"[{idx+1:>3}] skipped entry: {entry.label()} -> {result.reason}"
            )
            return False

        results.append(entry)

        state_tag = "COMMITTED" if entry.is_committed() else "PARTIAL"
        _log.info(
            f"[{idx+1:>3}] {state_tag}: {entry.label()} "
            f"(confidence={result.confidence:.2f})"
        )
        if result.missing:
            self._status(
                "summary.student.failed",
                student_name=entry.display_name,
                fields=", ".join(result.missing),
            )
            self._warn(
                f"  [{idx+1:>3}] {entry.label()} missing fields: {result.missing}"
            )
        else:
            self._status("student.scan.commit", student_name=entry.display_name)
        return True
    def _invalidate_student_basic_capture(self) -> None:
        self._student_basic_img = None
        self._student_basic_crops = None
    def _set_student_basic_capture(self, image: Image.Image) -> None:
        self._student_basic_img = image
        self._student_basic_crops = None
    def _student_basic_crop_keys(self) -> tuple[str, ...]:
        regions = self.r.get("student", {})
        explicit = {
            "student_texture_region",
            "weapon_info_menu_button",
            "equipment_button",
        }
        return tuple(
            key for key in regions
            if key.startswith("basic_") or key in explicit
        )
    def _get_student_basic_capture(
        self,
        *,
        refresh: bool = False,
    ) -> Optional[Image.Image]:
        if refresh or getattr(self, "_student_basic_img", None) is None:
            img = self._capture()
            if img is None:
                return None
            self._set_student_basic_capture(img)
        return self._student_basic_img
    def _get_student_basic_crops(self) -> Optional[ScreenCropSet]:
        image = self._get_student_basic_capture()
        if image is None:
            return None
        if getattr(self, "_student_basic_crops", None) is None:
            regions = self.r.get("student", {})
            self._student_basic_crops = ScreenCropSet.from_image(
                image,
                regions,
                keys=self._student_basic_crop_keys(),
            )
            _log.debug(
                "student basic crops prepared: count=%d memory=%d source=%s",
                len(self._student_basic_crops.names()),
                self._student_basic_crops.memory_bytes(),
                self._student_basic_crops.source_size,
            )
        return self._student_basic_crops
    def _get_student_basic_region(self, name: str) -> Optional[PreparedScreenRegion]:
        # Some unit-test scanners intentionally bypass __init__; in that case
        # retain the legacy caller-provided image path.
        if not hasattr(self, "_student_basic_img"):
            return None
        crops = self._get_student_basic_crops()
        return crops.get(name) if crops is not None else None
    def save_student_basic_crops(self, directory: str | Path, *, prefix: str = "") -> list[Path]:
        """Export the current named crops for ROI and matcher diagnostics."""
        crops = self._get_student_basic_crops()
        return crops.save_debug(directory, prefix=prefix) if crops is not None else []
    def save_student_panel_crops(
        self,
        panel_name: str,
        directory: str | Path,
        *,
        prefix: str = "",
    ) -> list[Path]:
        """Export retained equipment or stat crops without the full capture."""
        crops = {
            "equipment": getattr(self, "_student_equipment_crops", None),
            "stat": getattr(self, "_student_stat_crops", None),
        }.get(panel_name)
        return crops.save_debug(directory, prefix=prefix) if crops is not None else []
    def _release_student_basic_source(self) -> None:
        """Drop the full basic screenshot after all named consumers have run."""
        self._student_basic_img = None
    def _adjust_region(
        self,
        region: dict,
        *,
        left: float = 0.0,
        top: float = 0.0,
        right: float = 0.0,
        bottom: float = 0.0,
    ) -> dict:
        return {
            "x1": max(0.0, min(1.0, region["x1"] + left)),
            "y1": max(0.0, min(1.0, region["y1"] + top)),
            "x2": max(0.0, min(1.0, region["x2"] + right)),
            "y2": max(0.0, min(1.0, region["y2"] + bottom)),
        }
    def _basic_equipment_empty_dot_region(self, slot: int) -> Optional[dict]:
        regions = self.r.get("student", {}) if hasattr(self, "r") else {}
        if slot in (1, 2, 3):
            configured = regions.get(f"basic_equipment_{slot}_empty_dot_region")
        elif slot == 4:
            configured = regions.get("basic_favorite_empty_dot_region")
        else:
            configured = None
        return configured or BASIC_EQUIP_EMPTY_DOT_REGIONS.get(slot)
    def _basic_equipment_empty_dot_present(self, img: Image.Image, slot: int) -> bool:
        region = self._basic_equipment_empty_dot_region(slot)
        if not region:
            return False
        crop = crop_region(img, region).convert("RGB")
        arr = np.asarray(crop)
        if arr.size == 0:
            return False
        red = arr[:, :, 0].astype(np.int16)
        green = arr[:, :, 1].astype(np.int16)
        blue = arr[:, :, 2].astype(np.int16)
        mask = (
            (red > 230)
            & (green > 145)
            & (green < 220)
            & (blue < 100)
            & ((red - green) > 25)
        )
        pixels = int(mask.sum())
        ratio = float(mask.mean())
        _log.debug(f"basic equip{slot} empty dot: pixels={pixels} ratio={ratio:.3f} region={region}")
        return (
            pixels >= BASIC_EQUIP_EMPTY_DOT_MIN_PIXELS
            and ratio >= BASIC_EQUIP_EMPTY_DOT_MIN_RATIO
        )
    def _equipment_growth_button_active(self, img: Image.Image, region: dict) -> bool:
        ratio = self._active_blue_button_ratio(img, region, "equipment growth button")
        return ratio >= EQUIPMENT_GROWTH_ACTIVE_BLUE_MIN_RATIO
    def _active_blue_button_ratio(self, img: Image.Image, region: dict, label: str) -> float:
        crop = crop_region(img, region).convert("RGB")
        arr = np.asarray(crop)
        if arr.size == 0:
            return 0.0
        red = arr[:, :, 0].astype(np.int16)
        green = arr[:, :, 1].astype(np.int16)
        blue = arr[:, :, 2].astype(np.int16)
        mask = (
            (blue > 180)
            & (green > 150)
            & (red < 170)
            & ((blue - red) > 35)
        )
        ratio = float(mask.mean())
        _log.debug(f"{label} active blue ratio={ratio:.3f}")
        return ratio
    def _apply_basic_equipment_hints(
        self,
        entry: StudentEntry,
        img: Image.Image,
        slots_to_scan: set[int],
        *,
        include_favorite: bool,
        growth_button_active: bool,
    ) -> None:
        for slot in sorted(tuple(slots_to_scan)):
            if slot not in (1, 2, 3):
                continue
            if not self._basic_equipment_empty_dot_present(img, slot):
                continue
            equip_key = f"equip{slot}"
            level_key = f"equip{slot}_level"
            setattr(entry, equip_key, EquipSlotFlag.EMPTY.value)
            entry.set_meta(equip_key, FieldMeta.skipped("basic_empty_dot"))
            setattr(entry, level_key, None)
            entry.set_meta(level_key, FieldMeta.skipped("basic_empty_dot"))
            slots_to_scan.discard(slot)
            self.log(f"  equipment{slot}: empty dot detected -> skip basic read")
            self._status(f"equip{slot}.basic_empty_dot", student_name=entry.display_name)
    @staticmethod
    def _equipment_level_matches_tier(level: int, tier: str) -> bool:
        max_levels = {
            "T1": 10, "T2": 20, "T3": 30, "T4": 40, "T5": 45,
            "T6": 50, "T7": 55, "T8": 60, "T9": 65, "T10": 70,
        }
        max_level = max_levels.get(tier)
        return bool(max_level is not None and 1 <= level <= max_level)
    def _read_basic_equipment_slot(
        self,
        entry: StudentEntry,
        image: Image.Image,
        regions: dict,
        slot: int,
    ) -> bool:
        level_region = regions.get(f"basic_equipment_{slot}_level_digits_quad")
        icon_region = regions.get(f"basic_equipment_{slot}_icon_region")
        equipment_slots = student_meta.equipment_slots(entry.student_id)
        equipment_family = equipment_slots[slot - 1] if slot <= len(equipment_slots) else None
        if not (level_region and icon_region and equipment_family):
            return False
        if not hasattr(self, "_basic_equip_level_run_templates"):
            self._basic_equip_level_run_templates = {}
        level_templates = self._basic_equip_level_run_templates.setdefault(slot, {})
        tier_result = read_basic_equipment_icon_tier_result(
            image, icon_region, equipment_family,
        )
        generated_level_result = read_basic_equipment_generated_level_result(
            image,
            level_region,
            slot,
            equipment_family,
            str(tier_result.value) if tier_result.value and not tier_result.uncertain else None,
            icon_region,
        )
        if generated_level_result.value is not None and not generated_level_result.uncertain:
            level_result = generated_level_result
        else:
            level_result = read_basic_equipment_level_result(
                image, level_region, level_templates,
            )
        level = level_result.value
        tier = tier_result.value
        confident = (
            level is not None
            and tier is not None
            and not level_result.uncertain
            and not tier_result.uncertain
            and self._equipment_level_matches_tier(level, tier)
        )
        _log.debug(
            "basic equip%d: level=%s score=%.3f uncertain=%s tier=%s score=%.3f uncertain=%s compatible=%s icon=%s level_detail=%s",
            slot, level, level_result.score, level_result.uncertain,
            tier, tier_result.score, tier_result.uncertain,
            self._equipment_level_matches_tier(level, tier) if level and tier else False,
            tier_result.label,
            level_result.label,
        )
        if not confident:
            return False
        equip_key = f"equip{slot}"
        level_key = f"equip{slot}_level"
        setattr(entry, equip_key, tier)
        setattr(entry, level_key, level)
        entry.set_meta(
            equip_key,
            FieldMeta(status=FieldStatus.OK, source=FieldSource.TEMPLATE,
                      score=tier_result.score, note="basic_info_icon"),
        )
        entry.set_meta(
            level_key,
            FieldMeta(status=FieldStatus.OK, source=FieldSource.TEMPLATE,
                      score=level_result.score, note="basic_info_icon"),
        )
        self._status(f"equip{slot}.tier.ok", student_name=entry.display_name, tier=tier)
        self._field_confirmed(entry, equip_key, tier)
        self._status(f"equip{slot}.level.ok", student_name=entry.display_name, level=level)
        self._field_confirmed(entry, level_key, level, display_value=f"Lv.{level}")
        self.log(f"  equipment{slot}: basic read {tier} Lv.{level}")
        return True
    def _learn_basic_equipment_slot(
        self,
        entry: StudentEntry,
        image: Image.Image,
        regions: dict,
        slot: int,
    ) -> None:
        level = getattr(entry, f"equip{slot}_level")
        tier = getattr(entry, f"equip{slot}")
        level_region = regions.get(f"basic_equipment_{slot}_level_digits_quad")
        if isinstance(level, int) and level_region:
            if not hasattr(self, "_basic_equip_level_run_templates"):
                self._basic_equip_level_run_templates = {}
            templates = self._basic_equip_level_run_templates.setdefault(slot, {})
            learn_basic_equipment_level(image, level_region, level, templates)
        if isinstance(level, int) or isinstance(tier, str):
            _log.debug(
                "basic equip%d calibration: tier=%s level=%s",
                slot, tier, level,
            )
    def _is_lobby_capture(self, img: Optional[Image.Image]) -> bool:
        detect_r = self.r.get("lobby", {}).get("detect_flag")
        if img is None or not detect_r:
            return False
        roi = crop_region(img, detect_r)
        return is_lobby(roi, {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0})
    def _is_student_menu_capture(self, img: Optional[Image.Image]) -> bool:
        detect_r = self.r.get("student_menu", {}).get("menu_detect_flag")
        if img is None or not detect_r:
            return False
        roi = crop_region(img, detect_r)
        return is_student_menu(roi, {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0})
    def _student_additional_menu_region(self) -> Optional[dict]:
        # Reuse the student-menu detect ROI by default because the additional
        # menu applies the same dimmed effect to that area.
        return (
            self.r.get("student", {}).get("student_additional_menu_on_flag")
            or self.r.get("student_menu", {}).get("menu_detect_flag")
        )
    def _is_student_additional_menu_capture(self, img: Optional[Image.Image]) -> bool:
        detect_r = self._student_additional_menu_region()
        if img is None or not detect_r:
            return False
        if (
            self._is_basic_info_tab_on_capture(img)
            or self._is_level_tab_on_capture(img)
            or self._is_star_tab_on_capture(img)
        ):
            return False
        roi = crop_region(img, detect_r)
        return is_student_additional_menu_on(
            roi,
            {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0},
        )
    def _is_student_panel_title_capture(self, img: Optional[Image.Image], panel_name: str) -> bool:
        if img is None:
            return False
        expected_template = STUDENT_PANEL_TITLE_TEMPLATES.get(panel_name)
        if expected_template is None or not expected_template.exists():
            _log.warning("student panel title template missing: %s", panel_name)
            return self._is_student_additional_menu_capture(img)
        title_crop = crop_region(img, STUDENT_PANEL_TITLE_REGION)
        scores: dict[str, float] = {}
        for name, template_path in STUDENT_PANEL_TITLE_TEMPLATES.items():
            if template_path.exists():
                scores[name] = match_score_resized(title_crop, str(template_path))
        expected_score = scores.get(panel_name, 0.0)
        other_best = max((score for name, score in scores.items() if name != panel_name), default=0.0)
        margin = expected_score - other_best
        threshold = self._panel_title_score_threshold(panel_name)
        has_history = bool(self._panel_title_score_history.get(panel_name))
        bootstrap_match = (
            not has_history
            and expected_score >= STUDENT_PANEL_TITLE_BOOTSTRAP_SCORE
            and margin >= STUDENT_PANEL_TITLE_BOOTSTRAP_MARGIN
        )
        adaptive_match = (
            expected_score >= threshold
            and margin >= STUDENT_PANEL_TITLE_MIN_MARGIN
        )
        matched = bootstrap_match or adaptive_match
        _log.debug(
            "student_panel_title[%s]: %s margin=%.3f threshold=%.3f bootstrap=%s matched=%s",
            panel_name,
            " ".join(f"{name}={score:.3f}" for name, score in sorted(scores.items())),
            margin,
            threshold,
            str(bootstrap_match).lower(),
            str(matched).lower(),
        )
        if matched:
            self._record_panel_title_score(panel_name, expected_score)
        return matched
    def _is_level_tab_on_capture(self, img: Optional[Image.Image]) -> bool:
        detect_r = self.r.get("student", {}).get("levelcheck_button")
        if img is None or not detect_r:
            return False
        roi = crop_region(img, detect_r)
        return is_level_tab_on(roi, {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0})
    def _is_basic_info_tab_on_capture(self, img: Optional[Image.Image]) -> bool:
        detect_r = self.r.get("student", {}).get("basic_info_button")
        if img is None or not detect_r:
            return False
        roi = crop_region(img, detect_r)
        return is_basic_info_tab_on(
            roi,
            {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0},
        )
    def _is_star_tab_on_capture(self, img: Optional[Image.Image]) -> bool:
        detect_r = self.r.get("student", {}).get("star_menu_button")
        if img is None or not detect_r:
            return False
        roi = crop_region(img, detect_r)
        return is_star_tab_on(
            roi,
            {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 1.0},
        )
    def _student_detail_score(self, img: Optional[Image.Image]) -> float:
        texture_r = self.r.get("student", {}).get("student_texture_region")
        if img is None or not texture_r:
            return 0.0
        crop = crop_region(img, texture_r)
        _, score = match_student_texture(crop)
        return score
    def _wait_for_student_menu_state(
        self,
        expected_in_student_menu: bool,
        *,
        timeout: float,
        initial_wait: float = 0.0,
        poll: float = 0.25,
    ) -> bool:
        if initial_wait > 0 and not self._wait(initial_wait):
            return False
        deadline = time.monotonic() + timeout
        ready_streak = 0
        while time.monotonic() < deadline:
            if self._stop_requested():
                return False
            img = self._capture()
            matches = img is not None and self._is_student_menu_capture(img) == expected_in_student_menu
            if matches:
                ready_streak += 1
                if ready_streak < STUDENT_MENU_READY_STABLE_POLLS:
                    if not self._wait(poll):
                        return False
                    continue
                self._invalidate_student_basic_capture()
                return True
            ready_streak = 0
            if not self._wait(poll):
                return False
        return False
    def _wait_for_student_detail(
        self,
        *,
        timeout: float = DETAIL_READY_WAIT,
        initial_wait: float = 0.0,
        poll: float = 0.25,
    ) -> bool:
        if initial_wait > 0 and not self._wait(initial_wait):
            return False
        deadline = time.monotonic() + timeout
        ready_streak = 0
        while time.monotonic() < deadline:
            if self._stop_requested():
                return False
            img = self._capture()
            if img is not None and self._is_basic_info_tab_on_capture(img):
                self._set_student_basic_capture(img)
                return True
            score = self._student_detail_score(img)
            _log.debug(
                f"[detail_wait] texture_score={score:.3f} "
                f"ready_streak={ready_streak}"
            )
            if score >= DETAIL_READY_SCORE:
                ready_streak += 1
                if ready_streak < DETAIL_READY_STABLE_POLLS:
                    if not self._wait(poll):
                        return False
                    continue
                self._set_student_basic_capture(img)
                return True
            else:
                ready_streak = 0
            if not self._wait(poll):
                return False
        return False
    def _wait_for_student_detail_fast(
        self,
        *,
        timeout: float = DETAIL_READY_WAIT,
        initial_wait: float = 0.0,
        poll: float = 0.20,
    ) -> bool:
        if initial_wait > 0 and not self._wait(initial_wait):
            return False
        deadline = time.monotonic() + timeout
        last_img: Optional[Image.Image] = None
        while time.monotonic() < deadline:
            if self._stop_requested():
                return False
            img = self._capture()
            last_img = img
            if img is not None and self._is_basic_info_tab_on_capture(img):
                self._set_student_basic_capture(img)
                return True
            if not self._wait(poll):
                return False
        if last_img is not None:
            self._set_student_basic_capture(last_img)
            return True
        return False
    def _student_texture_digest(self, img: Optional[Image.Image]) -> Optional[str]:
        texture_r = self.r.get("student", {}).get("student_texture_region")
        if img is None or not texture_r:
            return None
        try:
            crop = crop_region(img, texture_r)
        except Exception:
            return None
        return hashlib.sha1(crop.tobytes()).hexdigest()
    def _student_texture_signature(self, img: Optional[Image.Image]) -> Optional[np.ndarray]:
        texture_r = self.r.get("student", {}).get("student_texture_region")
        if img is None or not texture_r:
            return None
        try:
            crop = crop_region(img, texture_r).convert("RGB").resize((24, 24), Image.BILINEAR)
        except Exception:
            return None
        return np.asarray(crop, dtype=np.float32) / 255.0
    @staticmethod
    def _student_texture_signature_delta(
        left: Optional[np.ndarray],
        right: Optional[np.ndarray],
    ) -> float:
        if left is None or right is None or left.shape != right.shape:
            return 1.0
        return float(np.mean(np.abs(left - right)))
    def _current_student_digest(self, *, refresh: bool) -> Optional[str]:
        img = self._get_student_basic_capture(refresh=refresh)
        return self._student_texture_digest(img)
    def _wait_for_student_change(
        self,
        previous_digest: str,
        *,
        timeout: float = 3.0,
        initial_wait: float = STUDENT_CHANGE_INITIAL_WAIT,
        poll: float = STUDENT_CHANGE_POLL,
    ) -> Optional[str]:
        started = time.perf_counter()
        if initial_wait > 0 and not self._wait(initial_wait):
            return None
        deadline = time.monotonic() + timeout
        changed_digest: Optional[str] = None
        previous_signature: Optional[np.ndarray] = None
        stable_streak = 0
        while time.monotonic() < deadline:
            if self._stop_requested():
                return None
            img = self._get_student_basic_capture(refresh=True)
            digest = self._student_texture_digest(img)
            if digest and digest != previous_digest:
                signature = self._student_texture_signature(img)
                delta = self._student_texture_signature_delta(previous_signature, signature)
                stable_streak = stable_streak + 1 if delta <= STUDENT_CHANGE_STABLE_DELTA else 1
                previous_signature = signature
                changed_digest = digest
                _log.debug(
                    "[navigation_transition] changed=true stable_streak=%d delta=%.4f",
                    stable_streak,
                    delta,
                )
                if stable_streak >= STUDENT_CHANGE_STABLE_POLLS:
                    _log.info(
                        "[navigation_transition] elapsed=%.3fs initial=%.3fs success=true stable=true",
                        time.perf_counter() - started,
                        initial_wait,
                    )
                    return digest
            else:
                changed_digest = None
                previous_signature = None
                stable_streak = 0
            if not self._wait(poll):
                return None
        if changed_digest is not None:
            _log.warning(
                "[navigation_transition] elapsed=%.3fs initial=%.3fs success=true stable=false",
                time.perf_counter() - started,
                initial_wait,
            )
            return changed_digest
        _log.warning(
            "[navigation_transition] elapsed=%.3fs initial=%.3fs success=false stable=false",
            time.perf_counter() - started,
            initial_wait,
        )
        return None
    def _wait_for_capture_match(
        self,
        predicate: Callable[[Optional[Image.Image]], bool],
        *,
        timeout: float,
        initial_wait: float = 0.0,
        poll: float = UI_FLAG_POLL,
        stable_polls: int = 1,
        label: str = "",
    ) -> Optional[Image.Image]:
        if initial_wait > 0 and not self._wait(initial_wait):
            return None
        deadline = time.monotonic() + timeout
        ready_streak = 0
        last_img: Optional[Image.Image] = None
        while time.monotonic() < deadline:
            if self._stop_requested():
                return None
            img = self._capture()
            last_img = img
            matched = img is not None and predicate(img)
            _log.debug(
                f"[wait_match] label={label} matched={matched} "
                f"ready_streak={ready_streak}"
            )
            if matched:
                ready_streak += 1
                if ready_streak >= stable_polls:
                    return img
            else:
                ready_streak = 0
            if not self._wait(poll):
                return last_img if matched else None
        return None
    def _click_student_region_and_wait(
        self,
        region_key: str,
        label: str,
        predicate: Callable[[Optional[Image.Image]], bool],
        *,
        timeout: float,
        initial_wait: float = DELAY_AFTER_CLICK,
        poll: float = UI_FLAG_POLL,
        stable_polls: int = 1,
        fallback_delay: float = DELAY_TAB_SWITCH,
        match_delay: float = UI_FLAG_MATCH_DELAY,
    ) -> Optional[Image.Image]:
        started = time.perf_counter()
        success = False
        transition_key = f"open:{label}"
        adaptive_initial_wait = self._panel_transition_initial_wait(transition_key)
        region = self.r.get("student", {}).get(region_key)
        try:
            if not region:
                self.log(f"  missing {region_key}")
                return None
            if not self._click_r(region, label):
                return None
            img = self._wait_for_capture_match(
                predicate,
                timeout=timeout,
                initial_wait=adaptive_initial_wait,
                poll=min(poll, PANEL_TRANSITION_POLL),
                stable_polls=stable_polls,
                label=label,
            )
            if img is not None:
                success = True
                return img
            if fallback_delay > 0 and not self._wait(fallback_delay):
                return None
            img = self._capture()
            if img is not None and predicate(img):
                success = True
                return img
            _log.warning(f"{label} did not reach expected panel state")
            return None
        finally:
            elapsed = time.perf_counter() - started
            self._record_panel_transition(
                transition_key,
                elapsed,
                success=success,
                initial_wait=adaptive_initial_wait,
            )
            _log.info(
                "[perf] student.panel_wait elapsed=%.3fs label=%s region=%s success=%s",
                elapsed,
                label,
                region_key,
                str(success).lower(),
            )
    def _recover_first_student_entry(self) -> bool:
        _log.warning("recovering first student entry from fallback state")
        img = self._capture()
        if img is not None:
            if self._is_lobby_capture(img):
                _log.warning("recover detect: still in lobby")
                if not self.enter_student_menu():
                    return False
            elif self._is_student_menu_capture(img):
                _log.warning("recover detect: still in student menu")
        self._invalidate_student_basic_capture()
        return self.enter_first_student()
    def _restore_basic_tab(self) -> bool:
        """Return to the basic info tab."""
        sr = self.r["student"]
        current = self._get_student_basic_capture(refresh=True)
        if current is not None and self._is_basic_info_tab_on_capture(current):
            self._set_student_basic_capture(current)
            return True
        if "basic_info_button" in sr:
            img = self._click_student_region_and_wait(
                "basic_info_button",
                "basic_info_tab",
                self._is_basic_info_tab_on_capture,
                timeout=TAB_ON_READY_WAIT,
                initial_wait=DELAY_AFTER_CLICK,
                poll=UI_FLAG_POLL,
                stable_polls=1,
                fallback_delay=BASIC_TAB_SETTLE_WAIT,
            )
            if img is not None:
                self._set_student_basic_capture(img)
                return True
        else:
            self._esc()
        return self._settle_student_detail("basic_info_tab", initial_wait=0.0)
    def _settle_student_detail(
        self,
        reason: str,
        *,
        initial_wait: float = MENU_CLOSE_DETAIL_WAIT,
        timeout: float = 2.5,
        poll: float = 0.20,
        transition_key: str | None = None,
        started_at: float | None = None,
    ) -> bool:
        effective_initial_wait = initial_wait
        if transition_key:
            effective_initial_wait = self._panel_transition_initial_wait(transition_key)
        started = started_at if started_at is not None else time.perf_counter()
        self._invalidate_student_basic_capture()
        ok = self._wait_for_student_detail(
            timeout=timeout,
            initial_wait=effective_initial_wait,
            poll=min(poll, PANEL_TRANSITION_POLL) if transition_key else poll,
        )
        if transition_key:
            self._record_panel_transition(
                transition_key,
                time.perf_counter() - started,
                success=ok,
                initial_wait=effective_initial_wait,
            )
        _log.debug(f"[detail_settle] reason={reason} ok={ok}")
        return ok
    def scan_students(self) -> list[StudentEntry]:
        return self.scan_students_v5()
    def _scan_student_fields(self, entry: StudentEntry) -> bool:
        """Scan fields in dependency order so locked features can be skipped."""
        fields = {
            "student_id": entry.student_id,
            "student_name": entry.display_name,
        }
        with self._perf_step("student.fields", **fields):
            with self._perf_step("student.read_level", **fields):
                self.read_level(entry)
            if self._stop_requested():
                return False
            with self._perf_step("student.read_weapon_state", **fields):
                self.read_weapon_state(entry)
            if self._stop_requested():
                return False
            with self._perf_step("student.read_star", **fields):
                self.read_student_star(entry)
            if self._stop_requested():
                return False
            with self._perf_step("student.restore_basic_after_star", **fields):
                self._restore_basic_tab()
            if self._stop_requested():
                return False
            with self._perf_step("student.read_skills", **fields):
                self.read_skills(entry)
            if self._stop_requested():
                return False
            with self._perf_step("student.read_weapon", **fields):
                self.read_weapon(entry)
            if self._stop_requested():
                return False
            with self._perf_step("student.read_equipment", **fields):
                self.read_equipment(entry)
            if self._stop_requested():
                return False
            with self._perf_step("student.read_basic_combat_stats", **fields):
                self.read_basic_combat_stats(entry)
            if self._stop_requested():
                return False
            with self._perf_step("student.read_multi_form_combat_stats", **fields):
                self.read_multi_form_combat_stats(entry)
            self._release_student_basic_source()
            if self._stop_requested():
                return False
            with self._perf_step("student.read_stats", **fields):
                self.read_stats(entry)
        return not self._stop_requested()
    def scan_current_student(self) -> list[StudentEntry]:
        self._reset_panel_transition_history()
        self._info("[scan] current student scan start")
        self._status("session.start")
        self._emit_progress_state(current=0, total=1, note="current student scan")
        results: list[StudentEntry] = []

        try:
            with self._perf_step("student.identify", index=1, mode="current"):
                sid = self.identify_student(0)
            if sid is None:
                self._warn("student identify failed")
                self._status("student.identify.failed", index=1)
                return []

            ctx = ScanCtx(idx=1, student_id=sid)
            entry = self.begin_student_scan(sid)

            with self._perf_step("student.total", index=1, student_id=sid, student_name=entry.display_name, mode="current"):
                if not self._scan_student_fields(entry):
                    return results

                with self._perf_step("student.finalize_commit", index=1, student_id=sid, student_name=entry.display_name, mode="current"):
                    commit_result = self.finalize_student_entry(entry, ctx, partial_ok=True)
                    added = self.commit_student_entry(commit_result, results, 0)
            if added:
                self._emit_progress_state(current=1, total=1, note="current student scan")
                self._log_student(entry, 0)
                if self._asv:
                    self._asv.on_student_committed(entry)
        except Exception as e:
            _log.exception(f"????????????????????밸븶筌믩끃??獄???????멥렑???????????????????耀붾굝?????臾먮뼁?????쇨덫?????????????????????????濾???????????????????????癲????????????????????????????????????????????????????????????????ш끽維뽳쭩?뱀땡???얩맪???????????????????轅붽틓??섑떊???⑤챷?????????????????????????嫄???????????????????????筌??????????????????????????????????????? {e}")
            self._error(f"????????????????????밸븶筌믩끃??獄???????멥렑???????????????????耀붾굝?????臾먮뼁?????쇨덫?????????????????????????濾???????????????????????癲????????????????????????????????????????????? {e}")
            if self._asv:
                partial = ScanResult(students=list(results))
                self._asv.emergency_save(partial, {})
        finally:
            self._restore_basic_tab()
            if self._asv:
                self._asv.log_stats()

        summary = f"current student scan done: total {len(results)}"
        self._emit_progress_state(current=len(results), total=1, note="current student scan done")
        self._status(
            "summary.session.done_with_counts",
            total=len(results),
            scanned=len(results),
            skipped=0,
            warnings=0,
        )
        _log.info(summary)
        self._info(f"[scan] {summary}")
        return results
    def scan_students_v5(self) -> list[StudentEntry]:
        self._reset_panel_transition_history()
        log_section(_log, "???????????????????????????????????????????????????(V6)")
        self._info("[scan] student scan start (v6)")
        self._status("session.start")
        results:       list[StudentEntry] = []
        skipped_count  = 0
        scanned_count  = 0
        self._emit_progress_state(
            current=0,
            total=self._student_total_hint,
            note="student scan",
        )

        try:
            self._status("session.first_student.enter")
            if not self._wait_for_student_detail(initial_wait=0.5, timeout=DETAIL_READY_WAIT):
                self._status("session.first_student.enter_failed")
                return []
            self._restore_basic_tab()

            seen_ids:        set[str]       = set()
            consecutive_dup: int            = 0
            prev_id:         Optional[str]  = None
            all_student_ids = tuple(student_meta.all_ids())

            for idx in range(500):
                if self._stop_requested():
                    _log.info("stop requested while scanning students; breaking loop")
                    break


                _log.debug(f"[{idx+1}] identify student")
                preferred_ids = tuple(sid for sid in all_student_ids if sid not in seen_ids)
                fallback_ids = all_student_ids if seen_ids else None
                with self._perf_step(
                    "student.identify",
                    index=idx + 1,
                    mode="v5",
                    pool=len(preferred_ids),
                    fallback_pool=len(fallback_ids or ()),
                ):
                    sid = self.identify_student(
                        idx,
                        candidate_ids=preferred_ids or None,
                        fallback_candidate_ids=fallback_ids,
                    )
                if sid is None:
                    self._warn(f"[{idx+1}] identify failed; stopping scan")
                    break


                if sid == prev_id:
                    consecutive_dup += 1
                    _log.info(
                        f"[{idx+1}] ?????????????????????????⑤벡??????????????????????? ????????????: {sid} "
                        f"({consecutive_dup}/{MAX_CONSECUTIVE_DUP})"
                    )
                    if consecutive_dup >= MAX_CONSECUTIVE_DUP:
                        _log.info("same student repeated; stopping loop")
                        self._status("student.loop.seen_before", student_id=sid, student_name=student_meta.display_name(sid))
                        self._info("  repeated student detected; stopping")
                        break
                    self._status("student.loop.duplicate", student_id=sid, student_name=student_meta.display_name(sid), count=consecutive_dup, limit=MAX_CONSECUTIVE_DUP)
                    self._wait_ui_status_flush(label=f"student:{sid}:skipped")
                    self._restore_basic_tab()
                    self.go_next_student()
                    continue

                consecutive_dup = 0
                prev_id = sid

                if sid in seen_ids:
                    _log.info(f"[{idx+1}] already scanned student {sid}; stopping")
                    self._status("student.loop.seen_before", student_id=sid, student_name=student_meta.display_name(sid))
                    self._info(f"  ?????????????????????? ???? ???????????????????????????{sid}")
                    break
                seen_ids.add(sid)




                _log.info(f"[{idx+1:>3}] ??????????????????????????????????????????????????? {sid}")
                ctx = ScanCtx(idx=idx+1, student_id=sid)

                # Create a temporary entry, then fill it step by step.
                entry = self.begin_student_scan(sid)

                with self._perf_step("student.total", index=idx + 1, student_id=sid, student_name=entry.display_name, mode="v5"):
                    # Keep going through the pipeline even if a step is missing.
                    # Each step writes into the same TEMP entry.
                    if not self._scan_student_fields(entry):
                        break

                    # Validate TEMP entry and decide COMMITTED/PARTIAL
                    with self._perf_step("student.finalize_commit", index=idx + 1, student_id=sid, student_name=entry.display_name, mode="v5"):
                        commit_result = self.finalize_student_entry(
                            entry, ctx, partial_ok=True
                        )

                        # Add the validated result unless it failed strict checks.
                        added = self.commit_student_entry(commit_result, results, idx)
                if added:
                    scanned_count += 1
                    self._emit_progress_state(
                        current=len(results),
                        total=self._student_total_hint,
            note="student scan",
                    )
                    self._log_student(entry, len(results) - 1)

                    if self._asv:
                        self._asv.on_student_committed(entry)
                    self._wait_ui_status_flush(label=f"student:{sid}")

                self._restore_basic_tab()
                with self._perf_step("student.navigate_next", index=idx + 1, student_id=sid, student_name=entry.display_name, mode="v5"):
                    self.go_next_student()

        except Exception as e:
            _log.exception(f"?????????????????????????????????????????????????????????????ш끽維뽳쭩?뱀땡???얩맪???????????????????轅붽틓??섑떊???⑤챷?????????????????????????嫄???????????????????????筌??????????????????????????????????????? {e}")
            self._error(f"?????????????????????????????????????????? {e}")

            if self._asv:
                partial = ScanResult(students=list(results))
                self._asv.emergency_save(partial, {})
        finally:
            if self._asv:
                self._asv.log_stats()

        summary = (
            f"student scan done: total {len(results)} "
            f"(????????????????????{scanned_count} / ???????????????????ш끽維뽳쭩?뱀땡???얩맪???????????????????轅붽틓??섑떊???⑤챷?????????????????????????嫄???????????????????????筌????{skipped_count})"
        )
        self._emit_progress_state(
            current=len(results),
            total=max(self._student_total_hint or 0, len(results)) or None,
            note="student scan",
        )
        self._status(
            "summary.session.done_with_counts",
            total=len(results),
            scanned=scanned_count,
            skipped=skipped_count,
            warnings=0,
        )
        _log.info(summary)
        self._info(f"[scan] {summary}")
        return results
    def scan_students_fast(self) -> list[StudentEntry]:
        return self.scan_students_v5()
    def _make_skipped_entry(self, student_id: str) -> StudentEntry:
        if student_id in self._maxed_saved_data:
            entry = _dict_to_student_entry(self._maxed_saved_data[student_id])
        else:
            entry = StudentEntry(
                student_id=student_id,
                display_name=student_meta.display_name(student_id),
                skipped=True,
            )

        return entry
    def enter_student_menu(self) -> bool:
        self.log("  ???????????????????????????????????????..")
        self._status("session.student_menu.enter")
        btn = self.r["lobby"].get("student_menu_button")
        if not btn:
            self.log("  missing student_menu_button")
            self._status("session.student_menu.enter_failed")
            return False

        attempts = [
            btn,

        ]
        for attempt, region in enumerate(attempts, start=1):
            clicked = self._click_r(region, f"student_menu_{attempt}")
            _log.info(f"[student_menu] attempt={attempt} clicked={clicked}")
            if not clicked:
                continue
            if self._wait_for_student_menu_state(
                True,
                timeout=LOBBY_EXIT_WAIT,
                initial_wait=MENU_CLICK_SETTLE_WAIT,
            ):
                return self._wait(STUDENT_MENU_READY_SETTLE_WAIT)
            if attempt < len(attempts):
                self.log(f"  ????????????????????????????.. ({attempt+1}/{len(attempts)})")
        self._status("session.student_menu.enter_failed")
        return False
    def enter_first_student(self) -> bool:
        self.log("  ???????????????????????..")
        self._status("session.first_student.enter")
        btn = self.r["student_menu"].get("first_student_button")
        if not btn:
            self.log("  missing first_student_button")
            self._status("session.first_student.enter_failed")
            return False

        if not self._wait(FIRST_STUDENT_PRECLICK_WAIT):
            return False

        clicked = self._click_r(btn, "first_student")
        _log.info(f"[first_student] clicked={clicked}")
        if not clicked:
            self._status("session.first_student.enter_failed")
            return False
        ok = self._wait_for_student_detail(initial_wait=DETAIL_CLICK_SETTLE_WAIT)
        if not ok:
            self._status("session.first_student.enter_failed")
        return ok
    def enter_first_student_fast(self) -> bool:
        self.log("  ???????????????????????????????????????????????????...")
        self._status("session.first_student.enter")
        btn = self.r["student_menu"].get("first_student_button")
        if not btn:
            self.log("  missing first_student_button")
            self._status("session.first_student.enter_failed")
            return False
        if not self._wait(FIRST_STUDENT_PRECLICK_WAIT):
            return False
        clicked = self._click_r(btn, "first_student_fast")
        _log.info(f"[first_student_fast] clicked={clicked}")
        if not clicked:
            self._status("session.first_student.enter_failed")
            return False
        ok = self._wait_for_student_detail_fast(initial_wait=DETAIL_CLICK_SETTLE_WAIT)
        if not ok:
            self._status("session.first_student.enter_failed")
        return ok
    def go_next_student(self) -> bool:
        previous_digest = self._current_student_digest(refresh=False)
        self._invalidate_student_basic_capture()
        self._status("navigation.next.arrow")
        if self._send_student_arrow("right"):
            if previous_digest is None:
                return self._wait(DELAY_NEXT)
            if self._wait_for_student_change(previous_digest) is not None:
                return True
            self._status("navigation.next.no_change")
            self._warn("  ??????????????????????????????????????????????????????????????????????????????????????????????????????곕춴??????-> ????????????fallback")

        btn = self.r["student"].get("next_student_button")
        if not btn:
            self.log("  missing next_student_button")
            return False
        self._status("navigation.next.button_fallback")
        self._click_r(btn, "next_student")
        if previous_digest is not None:
            return self._wait_for_student_change(previous_digest) is not None
        return self._wait(DELAY_NEXT)
    def go_next_student_fast(self, previous_digest: str) -> Optional[str]:
        self._invalidate_student_basic_capture()
        self._status("navigation.next.arrow")
        if self._send_student_arrow("right"):
            next_digest = self._wait_for_student_change(previous_digest)
            if next_digest is not None:
                return next_digest
            self._status("navigation.next.no_change")
            self._warn("  ??????????????????????????????????????????????????????????????????????????????????????????????????????곕춴??????-> ????????????fallback")

        btn = self.r["student"].get("next_student_button")
        if not btn:
            self.log("  missing next_student_button")
            return None
        self._invalidate_student_basic_capture()
        self._status("navigation.next.button_fallback")
        if not self._click_r(btn, "next_student_fast"):
            return None
        return self._wait_for_student_change(previous_digest)
    def go_previous_student_fast(self, previous_digest: str) -> Optional[str]:
        self._invalidate_student_basic_capture()
        if self._send_student_arrow("left"):
            return self._wait_for_student_change(previous_digest)
        return None
    def _send_student_arrow(self, direction: str) -> bool:
        hwnd = find_target_hwnd()
        if not hwnd:
            self.log("  warning: target window missing -> arrow key skip")
            return False
        if direction == "left":
            return send_key(hwnd, VK_LEFT, key_name="left", delay=0.0)
        return send_key(hwnd, VK_RIGHT, key_name="right", delay=0.0)
    def _student_attribute_candidates(self, image: Image.Image) -> tuple[list[str], dict[str, str]]:
        """Read stable basic-card labels and return their metadata intersection."""
        regions = self.r.get("student", {})
        attributes: dict[str, str] = {}
        for field in ("attack_type", "defense_type", "position", "combat_class", "role"):
            region_key = f"basic_attribute_{field}"
            region = regions.get(region_key)
            if region is None:
                continue
            prepared = self._get_student_basic_region(region_key)
            crop = prepared.image if prepared is not None else crop_region(image, region)
            result = read_basic_student_attribute_result(crop, field)
            if result.value is not None and not result.uncertain:
                attributes[field] = str(result.value)
            _log.debug(
                "student attribute: field=%s value=%s score=%.3f uncertain=%s label=%s",
                field, result.value, result.score, result.uncertain, result.label,
            )

        # Three fields already reduce the average pool below six. Requiring at
        # least three prevents a broad or weak label from bloating the union.
        candidates = student_meta.ids_matching_attributes(attributes)
        if len(attributes) < 3 or not (1 <= len(candidates) <= 32):
            _log.info(
                "student attribute guard disabled: fields=%s pool=%d",
                attributes, len(candidates),
            )
            return [], attributes
        _log.info(
            "student attribute guard: fields=%s pool=%d candidates=%s",
            attributes, len(candidates), " ".join(candidates),
        )
        return candidates, attributes
    def identify_student(
        self,
        idx: int = 0,
        *,
        candidate_ids: Iterable[str] | None = None,
        fallback_candidate_ids: Iterable[str] | None = None,
    ) -> Optional[str]:
        """Identify the current student from the portrait texture region."""
        sr = self.r["student"]
        texture_r = sr.get("student_texture_region")
        ctx = ScanCtx(idx=idx + 1, step="identify")
        self._status("student.identify.start", index=idx + 1)

        if not texture_r:
            _log.warning(f"{ctx} student_texture_region missing -> cannot identify")
            self._status("student.identify.failed", index=idx + 1)
            return None

        def _try() -> Optional[str]:
            img = self._get_student_basic_capture(refresh=True)
            if img is None:
                return None
            crop = crop_region(img, texture_r)
            attribute_candidates, _attributes = self._student_attribute_candidates(img)
            sid, score = match_student_texture(
                crop,
                candidate_ids=candidate_ids,
                fallback_candidate_ids=fallback_candidate_ids,
                injected_candidate_ids=attribute_candidates,
            )
            if sid is not None:
                _log.info(
                    f"{ctx} ?????????????????????????????????????????????????????????????????????????????ㅻ깹???????????? {student_meta.display_name(sid)} "
                    f"(score={score:.3f})"
                )
                self._info(
                    f"  ??????????????????[{idx+1}] {student_meta.display_name(sid)} (score={score:.3f})"
                )
                self._status(
                    "student.identify.success",
                    index=idx + 1,
                    student_id=sid,
                    student_name=student_meta.display_name(sid),
                    technical=f"score={score:.3f}",
                )
                return sid

            _log.debug(f"{ctx} ?????????????????????????????????????????????????????????????????????????????????????????????곕춴??????(score={score:.3f})")
            dump_roi(crop, "identify_fail", score=score, reason="below_thresh")
            if self._asv:
                self._asv.on_step_error("identify")
            self._status("student.identify.retry", index=idx + 1, technical=f"score={score:.3f}")
            self._warn(f"[{idx+1}] ?????????????????????????????????????????????????????????????????????????????????????????????곕춴??????(score={score:.3f})")
            return None

        sid = self._retry(_try, max_attempts=RETRY_IDENTIFY, delay=0.6, label="identify student")
        if sid is not None or idx != 0:
            if sid is None:
                self._status("student.identify.failed", index=idx + 1)
            return sid

        _log.warning(f"{ctx} first student identify failed; trying recovery")
        self._warn(f"[{idx+1}] first student identify failed; trying recovery")
        if not self._recover_first_student_entry():
            self._status("student.identify.failed", index=idx + 1)
            return None
        self._restore_basic_tab()
        self._invalidate_student_basic_capture()
        sid = self._retry(_try, max_attempts=RETRY_IDENTIFY, delay=0.6, label="identify student after recovery")
        if sid is None:
            self._status("student.identify.failed", index=idx + 1)
        return sid
    def _read_skills_from_basic(self, entry: StudentEntry, img: Image.Image) -> bool:
        sr = self.r["student"]
        staged: dict[str, tuple[Optional[int], FieldMeta]] = {}
        specs = (
            ("ex_skill", "basic_EX_skill", True, None),
            ("skill1", "basic_Skill_1", False, None),
            ("skill2", "basic_Skill_2", False, SKILL2_UNLOCK_STAR),
            ("skill3", "basic_Skill_3", False, SKILL3_UNLOCK_STAR),
        )
        for field_name, region_key, is_ex, unlock_star in specs:
            if (
                unlock_star is not None
                and entry.student_star is not None
                and entry.student_star < unlock_star
            ):
                staged[field_name] = (None, FieldMeta.skipped("star_locked"))
                continue
            region = sr.get(region_key)
            if region is None:
                _log.debug("basic skill region missing: %s", region_key)
                return False
            prepared = self._get_student_basic_region(region_key)
            skill_crop = prepared.image if prepared is not None else crop_region(img, region)
            result = read_basic_skill_result(skill_crop, is_ex=is_ex)
            if result.value is None or result.uncertain:
                _log.info(
                    "[basic_skill] fallback student=%s field=%s value=%s score=%.3f label=%s",
                    entry.student_id,
                    field_name,
                    result.value,
                    result.score,
                    result.label,
                )
                return False
            staged[field_name] = (
                int(result.value),
                FieldMeta.ok(FieldSource.TEMPLATE, score=result.score),
            )

        for field_name, (value, meta) in staged.items():
            setattr(entry, field_name, value)
            entry.set_meta(field_name, meta)
            if value is None and field_name == "skill2":
                self._status("skills.skill2.skip_star_locked", student_name=entry.display_name, star=entry.student_star)
            elif value is None and field_name == "skill3":
                self._status("skills.skill3.skip_star_locked", student_name=entry.display_name, star=entry.student_star)
            else:
                self._status_skill_value(entry, field_name, value)
        self.log(
            f"  ?????????????????????????????????? EX={entry.ex_skill} "
            f"S1={entry.skill1} S2={entry.skill2} S3={entry.skill3}"
        )
        self._status(
            "skills.basic.success",
            student_name=entry.display_name,
            ex=entry.ex_skill,
            s1=entry.skill1,
            s2=entry.skill2,
            s3=entry.skill3,
        )
        self._status(
            "skills.summary",
            student_name=entry.display_name,
            ex=entry.ex_skill,
            s1=entry.skill1,
            s2=entry.skill2,
            s3=entry.skill3,
        )
        return True
    def read_skills(self, entry: StudentEntry) -> None:
        """Read the skill panel from a single capture and fill skill fields."""
        ctx = ScanCtx(student_id=entry.student_id, step="read_skills")
        self._status("skills.start", student_name=entry.display_name)
        basic_img = self._get_student_basic_capture()
        if basic_img is not None and self._read_skills_from_basic(entry, basic_img):
            return
        self._status("skills.basic.fallback", student_name=entry.display_name)
        self.log("  basic skill scan unavailable -> opening skill menu")

        self._active_student_panel = "skill"
        img = self._click_student_region_and_wait(
            "skill_menu_button",
            "skill_menu_button",
            lambda capture: self._is_student_panel_title_capture(capture, "skill"),
            timeout=ADDITIONAL_PANEL_READY_WAIT,
        )
        if img is None:
            _log.warning(f"{ctx} skill menu open failed")
            self._esc()
            return

        sr      = self.r["student"]
        check_r = sr.get("skill_all_view_check_region")

        if check_r:
            if read_skill_check(crop_region(img, check_r)) == CheckFlag.FALSE:
                self.log("  enabling all skill view")
                self._click_r(check_r, "skill_check")
                if not self._wait(0.3):
                    self._esc()
                    return
                img = self._capture()
                if img is None:
                    _log.warning(f"{ctx} skill menu capture failed")
                    self._esc()
                    return

        for field_name, region_key, tmpl_key in [
            ("ex_skill", "EX_skill", "EX_Skill"),
            ("skill1",   "Skill_1",  "Skill1"),
            ("skill2",   "Skill_2",  "Skill2"),
            ("skill3",   "Skill_3",  "Skill3"),
        ]:
            if field_name == "skill2" and entry.student_star is not None and entry.student_star < SKILL2_UNLOCK_STAR:
                entry.skill2 = None
                entry.set_meta("skill2", FieldMeta.skipped("star_locked"))
                self._status("skills.skill2.skip_star_locked", student_name=entry.display_name, star=entry.student_star)
                self.log(f"  {entry.student_star} star -> Skill2 locked")
                continue
            if field_name == "skill3" and entry.student_star is not None and entry.student_star < SKILL3_UNLOCK_STAR:
                entry.skill3 = None
                entry.set_meta("skill3", FieldMeta.skipped("star_locked"))
                self._status("skills.skill3.skip_star_locked", student_name=entry.display_name, star=entry.student_star)
                self.log(f"  {entry.student_star} star -> Skill3 locked")
                continue
            region = sr.get(region_key)
            if region is None:
                _log.warning(f"{ctx.with_step(field_name)} region missing -> skip")
                entry.set_meta(field_name, FieldMeta.region_missing(region_key))
                continue
            crop = crop_region(img, region)
            raw  = read_skill(crop, tmpl_key)
            try:
                setattr(entry, field_name, int(raw))
                entry.set_meta(field_name, FieldMeta.ok(FieldSource.TEMPLATE))
                self._status_skill_value(entry, field_name, getattr(entry, field_name))
            except (TypeError, ValueError):
                _log.debug(f"{ctx.with_step(field_name)} ????????????????????????⑤벡??????????????????????????????????곕춴??????(raw={raw!r})")
                dump_roi(crop, f"skill_{field_name}", reason="convert_fail")
                setattr(entry, field_name, None)
                entry.set_meta(field_name,
                               FieldMeta.failed(FieldSource.TEMPLATE,
                                                note=f"raw={raw!r}"))
                if self._asv:
                    self._asv.on_step_error("read_skills", entry.student_id or "")

        self.log(
            f"  ????????????????? EX={entry.ex_skill} "
            f"S1={entry.skill1} S2={entry.skill2} S3={entry.skill3}"
        )
        self._status(
            "skills.summary",
            student_name=entry.display_name,
            ex=entry.ex_skill,
            s1=entry.skill1,
            s2=entry.skill2,
            s3=entry.skill3,
        )
        self._close_student_panel(
            capture_name="skill_close_button",
            region_key="skillmenu_quit_button",
            settle_reason="close_skill_menu",
        )
    def read_weapon_state(self, entry: StudentEntry) -> None:
        """Read only the weapon unlock/equipped state from the basic tab."""
        ctx      = ScanCtx(student_id=entry.student_id, step="read_weapon")
        self._status("weapon_state.start", student_name=entry.display_name)
        img = self._get_student_basic_capture()
        if img is None:
            entry.weapon_state = WeaponState.NO_WEAPON_SYSTEM
            entry.set_meta("weapon_state", FieldMeta.failed(FieldSource.TEMPLATE, "capture_fail"))
            return

        sr       = self.r["student"]
        weapon_button_r = sr.get("weapon_info_menu_button")
        if weapon_button_r:
            prepared_button = self._get_student_basic_region("weapon_info_menu_button")
            button_img = prepared_button.image if prepared_button is not None else img
            button_region = prepared_button.region if prepared_button is not None else weapon_button_r
            active_ratio = self._active_blue_button_ratio(button_img, button_region, "weapon growth button")
            is_active = active_ratio >= EQUIPMENT_GROWTH_ACTIVE_BLUE_MIN_RATIO
            if is_active:
                entry.weapon_state = WeaponState.WEAPON_EQUIPPED
                entry.set_meta("weapon_state", FieldMeta.ok(FieldSource.TEMPLATE, score=active_ratio))
                self._status(
                    "weapon_state.equipped",
                    student_name=entry.display_name,
                    technical=f"button_blue_ratio={active_ratio:.3f}",
                )
                self.log(f"  ?????????????????????????????????????????? WEAPON_EQUIPPED (button_blue_ratio={active_ratio:.3f})")
                return
            entry.weapon_state = WeaponState.NO_WEAPON_SYSTEM
            entry.set_meta("weapon_state", FieldMeta.ok(FieldSource.TEMPLATE, score=1.0 - active_ratio))
            self._status(
                "weapon_state.no_system",
                student_name=entry.display_name,
                technical=f"button_blue_ratio={active_ratio:.3f}",
            )
            self.log(f"  ?????????????????????????????????????????? NO_WEAPON_SYSTEM (button_blue_ratio={active_ratio:.3f})")
            return

        weapon_r = sr.get("weapon_detect_flag_region") or sr.get("weapon_unlocked_flag")
        if not weapon_r:
            entry.weapon_state = WeaponState.NO_WEAPON_SYSTEM
            entry.set_meta("weapon_state", FieldMeta.region_missing("weapon_info_menu_button"))
            return

        state, score = detect_weapon_state(crop_region(img, weapon_r))
        entry.weapon_state = state

        if score < 0.60:
            entry.set_meta("weapon_state",
                           FieldMeta.uncertain(FieldSource.TEMPLATE, score=score,
                                               note=state.value))
            self._status("weapon_state.uncertain", student_name=entry.display_name, state=state.name, technical=f"score={score:.3f}")
            _log.warning(f"{ctx} ??????????????????????????????????????????????????????????(score={score:.3f}, {state.name})")
        else:
            entry.set_meta("weapon_state",
                           FieldMeta.ok(FieldSource.TEMPLATE, score=score))
            if state == WeaponState.WEAPON_EQUIPPED:
                self._status("weapon_state.equipped", student_name=entry.display_name, technical=f"score={score:.3f}")
            elif state == WeaponState.WEAPON_UNLOCKED_NOT_EQUIPPED:
                self._status("weapon_state.unlocked_not_equipped", student_name=entry.display_name, technical=f"score={score:.3f}")
            else:
                self._status("weapon_state.no_system", student_name=entry.display_name, technical=f"score={score:.3f}")
        self.log(f"  ?????????????????????????????????????????? {state.name} (score={score:.3f})")
    def read_weapon(self, entry: StudentEntry) -> None:
        """Read weapon detail when the weapon system is unlocked/equipped."""
        self._status("weapon.start", student_name=entry.display_name)

        if entry.weapon_state is None:
            self.read_weapon_state(entry)

        if entry.student_star is not None and entry.student_star < WEAPON_UNLOCK_STAR:
            entry.weapon_star = None
            entry.weapon_level = None
            entry.set_meta("weapon_star", FieldMeta.skipped("star_locked"))
            entry.set_meta("weapon_level", FieldMeta.skipped("star_locked"))
            self._status("weapon.skip_star_locked", student_name=entry.display_name, star=entry.student_star)
            self.log(f"  {entry.student_star} star -> weapon locked")
            return

        state = entry.weapon_state
        if state is None:
            entry.set_meta("weapon_star", FieldMeta.skipped("weapon_state_missing"))
            entry.set_meta("weapon_level", FieldMeta.skipped("weapon_state_missing"))
            return
        weapon_meta = entry.get_meta("weapon_state")
        weapon_state_confirmed = (
            weapon_meta is not None
            and weapon_meta.status == FieldStatus.OK
        )
        if state == WeaponState.WEAPON_EQUIPPED and not weapon_state_confirmed:
            entry.weapon_star = None
            entry.weapon_level = None
            entry.set_meta("weapon_star", FieldMeta.skipped("weapon_state_uncertain"))
            entry.set_meta("weapon_level", FieldMeta.skipped("weapon_state_uncertain"))
            self._status("weapon.skip_state_uncertain", student_name=entry.display_name)
            self.log("  weapon button inactive -> weapon scan skipped")
            return
        if state == WeaponState.NO_WEAPON_SYSTEM:
            entry.weapon_star = None
            entry.weapon_level = None
            entry.set_meta("weapon_star", FieldMeta.skipped("no_weapon_system"))
            entry.set_meta("weapon_level", FieldMeta.skipped("no_weapon_system"))
            self._status("weapon.skip_no_system", student_name=entry.display_name)
            return

        if state == WeaponState.WEAPON_UNLOCKED_NOT_EQUIPPED:
            entry.weapon_star  = None
            entry.weapon_level = None
            entry.set_meta("weapon_star",  FieldMeta.skipped("not_equipped"))
            entry.set_meta("weapon_level", FieldMeta.skipped("not_equipped"))
            self._status("weapon.skip_not_equipped", student_name=entry.display_name)
            self.log("  basic weapon read unavailable -> opening weapon menu")
            return

        sr = self.r["student"]
        basic_img = self._get_student_basic_capture()
        basic_level_r = sr.get("basic_weapon_level_digits_quad")
        basic_star_r = sr.get("basic_weapon_star_region")
        prepared_level = self._get_student_basic_region("basic_weapon_level_digits_quad")
        prepared_star = self._get_student_basic_region("basic_weapon_star_region")
        if basic_img is not None and basic_level_r is not None and basic_star_r is not None:
            level_img = prepared_level.image if prepared_level is not None else basic_img
            level_region = prepared_level.region if prepared_level is not None else basic_level_r
            star_crop = prepared_star.image if prepared_star is not None else crop_region(basic_img, basic_star_r)
            basic_level = read_basic_weapon_level_result(level_img, level_region)
            basic_star = read_basic_weapon_star_result(star_crop)
            if (
                basic_level.value is not None
                and not basic_level.uncertain
                and basic_star.value is not None
                and not basic_star.uncertain
            ):
                entry.weapon_level = int(basic_level.value)
                entry.weapon_star = int(basic_star.value)
                entry.set_meta(
                    "weapon_level",
                    FieldMeta(
                        status=FieldStatus.OK,
                        source=FieldSource.TEMPLATE,
                        score=basic_level.score,
                        note="basic_info",
                    ),
                )
                entry.set_meta(
                    "weapon_star",
                    FieldMeta(
                        status=FieldStatus.OK,
                        source=FieldSource.TEMPLATE,
                        score=basic_star.score,
                        note="basic_info",
                    ),
                )
                self._status(
                    "weapon.basic_fast_success",
                    student_name=entry.display_name,
                    star=entry.weapon_star,
                    level=entry.weapon_level,
                )
                self._field_confirmed(entry, "weapon_star", entry.weapon_star, display_value=f"{entry.weapon_star} stars")
                self._field_confirmed(entry, "weapon_level", entry.weapon_level, display_value=f"Lv.{entry.weapon_level}")
                self.log(
                    f"  ?????????????????????????????????????????밸븶筌믩끃??獄???????멥렑???????????????????耀붾굝?????臾먮뼁?????쇨덫?????????????????????????濾???????????????????????癲??????????????????????????????????????????????????? {entry.weapon_star}??Lv.{entry.weapon_level} "
                    f"(level={basic_level.score:.3f}, star={basic_star.score:.3f})"
                )
                return
            self._status("weapon.basic_fast_fallback", student_name=entry.display_name)
            self.log(
                "  ?????????????????????????????????????밸븶筌믩끃??獄???????멥렑???????????????????耀붾굝?????臾먮뼁?????쇨덫?????????????????????????濾???????????????????????癲??????????????????????????????????????????????????????-> ????????????????????밸븶筌믩끃??獄???????멥렑???????????????????耀붾굝?????臾먮뼁?????쇨덫?????????????????????????濾???????????????????????癲???????????????????????????????????????????????????????????????????????????????ㅻ깹??????????????????????????"
                f"(level={basic_level.value}/{basic_level.score:.3f}, "
                f"star={basic_star.value}/{basic_star.score:.3f})"
            )

        self._active_student_panel = "weapon"
        img = self._click_student_region_and_wait(
            "weapon_info_menu_button",
            "weapon_info_menu",
            lambda capture: self._is_student_panel_title_capture(capture, "weapon"),
            timeout=ADDITIONAL_PANEL_READY_WAIT,
        )
        if img is None:
            self.log("  missing weapon_info_menu_button")
            entry.weapon_star = None
            entry.weapon_level = None
            entry.set_meta("weapon_star", FieldMeta.failed(FieldSource.TEMPLATE, "panel_not_detected"))
            entry.set_meta("weapon_level", FieldMeta.failed(FieldSource.TEMPLATE, "panel_not_detected"))
            self._esc()
            return

        star_r = sr.get("weapon_star_region")
        if star_r:
            from core.matcher import read_weapon_star_v5_result
            rs = read_weapon_star_v5_result(crop_region(img, star_r))
            entry.weapon_star = rs.value
            entry.set_meta("weapon_star",
                           FieldMeta.ok(FieldSource.TEMPLATE, score=rs.score)
                           if not rs.uncertain
                           else FieldMeta.uncertain(FieldSource.TEMPLATE,
                                                    score=rs.score))
        else:
            entry.set_meta("weapon_star", FieldMeta.region_missing("weapon_star_region"))

        d1 = sr.get("weapon_level_digit_1") or sr.get("weapon_level_digit1")
        d2 = sr.get("weapon_level_digit_2") or sr.get("weapon_level_digit2")
        if d1 and d2:
            entry.weapon_level = read_weapon_level(img, d1, d2)
            for _ in range(2):
                if entry.weapon_level is not None:
                    break
                if not self._wait(WEAPON_CAPTURE_RETRY_WAIT):
                    break
                retry_img = self._capture()
                if retry_img is None:
                    break
                retry_level = read_weapon_level(retry_img, d1, d2)
                if retry_level is not None:
                    img = retry_img
                    entry.weapon_level = retry_level
                    break
            entry.set_meta("weapon_level",
                           FieldMeta.ok(FieldSource.TEMPLATE)
                           if entry.weapon_level is not None
                           else FieldMeta.failed(FieldSource.TEMPLATE, "digit_read_fail"))
            self.log(f"  ????????????????????밸븶筌믩끃??獄???????멥렑???????????????????耀붾굝?????臾먮뼁?????쇨덫?????????????????????????濾???????????????????????癲????????????????????????????????? {entry.weapon_star}??Lv.{entry.weapon_level}")
            self._status(
                "weapon.summary",
                student_name=entry.display_name,
                star=entry.weapon_star,
                level=entry.weapon_level,
            )
            self._field_confirmed(entry, "weapon_star", entry.weapon_star, display_value=f"{entry.weapon_star} stars")
            self._field_confirmed(entry, "weapon_level", entry.weapon_level, display_value=f"Lv.{entry.weapon_level}")
        else:
            self.log("  missing weapon_level_digit")
            entry.set_meta("weapon_level", FieldMeta.region_missing("weapon_level_digit"))

        self._close_student_panel(
            capture_name="weapon_close_button",
            region_key="weapon_menu_quit_button",
            settle_reason="close_weapon_menu",
        )
    def read_equipment(self, entry: StudentEntry) -> None:
        """Read equipment state and slots from the equipment menu."""
        self._status("equipment.start", student_name=entry.display_name)


        sid       = entry.student_id or ""
        favorite_supported = student_meta.favorite_item_enabled(sid)
        if not favorite_supported and entry.equip4 is None:
            self._mark_favorite_item_unsupported(entry, sid)

        slots_to_scan = {1, 2, 3}
        if entry.level is not None and entry.level < EQUIP2_UNLOCK_LEVEL:
            entry.equip2 = EquipSlotFlag.LEVEL_LOCKED.value
            entry.equip2_level = None
            entry.set_meta("equip2", FieldMeta.skipped("level_locked"))
            entry.set_meta("equip2_level", FieldMeta.skipped("level_locked"))
            self._status("equip2.skip_level_locked_from_level", student_name=entry.display_name, level=entry.level)
            slots_to_scan.discard(2)
        if entry.level is not None and entry.level < EQUIP3_UNLOCK_LEVEL:
            entry.equip3 = EquipSlotFlag.LEVEL_LOCKED.value
            entry.equip3_level = None
            entry.set_meta("equip3", FieldMeta.skipped("level_locked"))
            entry.set_meta("equip3_level", FieldMeta.skipped("level_locked"))
            self._status("equip3.skip_level_locked_from_level", student_name=entry.display_name, level=entry.level)
            slots_to_scan.discard(3)

        sr        = self.r["student"]
        equip_btn = sr.get("equipment_button")
        if not equip_btn:
            self.log("  missing equipment_button")



        img = self._get_student_basic_capture()
        if img is None:
            return
        basic_img = img
        growth_button_active = self._equipment_growth_button_active(img, equip_btn)
        self._status(
            "equipment.button.active" if growth_button_active else "equipment.button.inactive",
            student_name=entry.display_name,
        )
        favorite_scan_needed = favorite_supported
        favorite_dot_present = (
            favorite_scan_needed
            and self._basic_equipment_empty_dot_present(img, 4)
        )
        if favorite_scan_needed:
            if favorite_dot_present:
                entry.equip4 = EquipSlotFlag.EMPTY.value
                entry.set_meta("equip4", FieldMeta.skipped("basic_empty_dot"))
                favorite_scan_needed = False
                self._status("favorite.basic_empty_dot", student_name=entry.display_name)
                self.log("  equipment: basic read unavailable -> opening equipment menu")
            elif not growth_button_active:
                entry.equip4 = EquipSlotFlag.LOVE_LOCKED.value
                entry.set_meta("equip4", FieldMeta.skipped("growth_button_off_no_dot_love_locked"))
                favorite_scan_needed = False
                self._status("favorite.slot_flag.love_locked", student_name=entry.display_name)
                self.log("  equipment: growth button inactive with empty slots -> infer locked")
        self._apply_basic_equipment_hints(
            entry,
            img,
            slots_to_scan,
            include_favorite=favorite_scan_needed,
            growth_button_active=growth_button_active,
        )
        for slot in sorted(tuple(slots_to_scan)):
            if self._read_basic_equipment_slot(entry, basic_img, sr, slot):
                slots_to_scan.discard(slot)
        if favorite_scan_needed and entry.equip4 is None:
            favorite_region = sr.get("basic_favorite_tier_region")
            if favorite_region:
                favorite_result = read_basic_favorite_tier_result(basic_img, favorite_region)
                _log.debug(
                    "basic favorite: value=%s score=%.3f uncertain=%s label=%s",
                    favorite_result.value,
                    favorite_result.score,
                    favorite_result.uncertain,
                    favorite_result.label,
                )
                if favorite_result.value in ("T1", "T2") and not favorite_result.uncertain:
                    entry.equip4 = str(favorite_result.value)
                    entry.set_meta(
                        "equip4",
                        FieldMeta(
                            status=FieldStatus.OK,
                            source=FieldSource.TEMPLATE,
                            score=favorite_result.score,
                            note="basic_info_marker",
                        ),
                    )
                    self._status(
                        "favorite.tier.t1" if entry.equip4 == "T1" else "favorite.tier.t2",
                        student_name=entry.display_name,
                        tier=entry.equip4,
                    )
                    self._field_confirmed(entry, "equip4", entry.equip4)
                    self.log(f"  ???? ????????? {entry.equip4} (?????????????????????????????????????????????됰Ŧ?????????轅붽틓????곌램?뽳쭕????????????????????????????룸ı???嶺뚮슣??쮼??????????????????????ㅻ깹?????????ㅻ깹??????????????????????????????關?쒎첎?嫄??怨몃룯?????")
        favorite_scan_needed = favorite_supported and entry.equip4 is None

        pre = read_equip_check(crop_region(img, equip_btn))
        if not slots_to_scan and not favorite_scan_needed:
            return

        if pre == CheckFlag.IMPOSSIBLE:
            self.log("  equipment growth button impossible on basic screen; opening menu")

        self._active_student_panel = "equipment"
        img = self._click_student_region_and_wait(
            "equipment_button",
            "equipment_tab",
            lambda capture: self._is_student_panel_title_capture(capture, "equipment"),
            timeout=ADDITIONAL_PANEL_READY_WAIT,
        )
        if img is None:
            self._esc()
            return

        check_r = sr.get("equipment_all_view_check_region")
        if check_r:
            check_state = read_equip_check_inside(crop_region(img, check_r))
            if check_state == CheckFlag.FALSE and self._wait(EQUIP_CHECK_RETRY_WAIT):
                retry_img = self._capture()
                if retry_img is not None:
                    img = retry_img
                    check_state = read_equip_check_inside(crop_region(img, check_r))
            if check_state == CheckFlag.FALSE:
                self.log("  equipment all-view checkbox is off; enabling it")
                if self._click_r(check_r, "equipment_all_view_check") and self._wait(0.45):
                    retry_img = self._capture()
                    if retry_img is not None:
                        img = retry_img
                        check_state = read_equip_check_inside(crop_region(img, check_r))
            if check_state == CheckFlag.FALSE:
                _log.warning(f"{entry.label()} equipment all-view checkbox remained off; continuing with visible slots")

        equipment_crop_keys = tuple(
            key for key in sr
            if key.startswith("equipment_") or key.startswith("equip")
        )
        self._student_equipment_crops = ScreenCropSet.from_image(
            img,
            sr,
            keys=equipment_crop_keys,
        )

        # Slots 1-3 share the same equipment-menu capture.
        for slot in sorted(slots_to_scan):
            skip_flags = {EquipSlotFlag.EMPTY}
            if slot in (2, 3):
                skip_flags.add(EquipSlotFlag.LEVEL_LOCKED)
            self._scan_equip_slot(entry, img, sr, slot,
                                  skip_flags=skip_flags, scan_level=True)
            self._learn_basic_equipment_slot(entry, basic_img, sr, slot)

        if slots_to_scan and all(getattr(entry, f"equip{slot}") in (None, "unknown") for slot in slots_to_scan):
            _log.warning(f"{entry.label()} equipment capture unstable -> retry once")
            if self._wait(0.35):
                retry_img = self._capture()
                if retry_img is not None:
                    img = retry_img
                    for slot in sorted(slots_to_scan):
                        skip_flags = {EquipSlotFlag.EMPTY}
                        if slot in (2, 3):
                            skip_flags.add(EquipSlotFlag.LEVEL_LOCKED)
                        self._scan_equip_slot(entry, img, sr, slot,
                                              skip_flags=skip_flags, scan_level=True)
                        self._learn_basic_equipment_slot(entry, basic_img, sr, slot)

        # ????4
        if favorite_supported:
            self._status("favorite.start", student_name=entry.display_name)
            self._scan_equip_slot(
                entry, img, sr, 4,
                skip_flags={EquipSlotFlag.EMPTY,
                            EquipSlotFlag.LOVE_LOCKED,
                            EquipSlotFlag.NULL},
                scan_level=False,
            )
        else:
            self._mark_favorite_item_unsupported(entry, sid)

        self._close_student_panel(
            capture_name="equipment_close_button",
            region_key="equipmentmenu_quit_button",
            settle_reason="close_equipment_menu",
        )
    def _scan_equip_slot(
        self,
        entry: StudentEntry,
        img: Image.Image,
        sr: dict,
        slot: int,
        skip_flags: set[EquipSlotFlag],
        scan_level: bool,
    ) -> None:
        """Scan one equipment slot from a shared equipment-menu capture."""
        equip_key = f"equip{slot}"
        level_key = f"equip{slot}_level"

        flag_r = (sr.get(f"equip{slot}_flag")
                  or sr.get(f"equip{slot}_emptyflag")
                  or sr.get(f"equip{slot}_empty_flag"))
        if flag_r:
            slot_flag = read_equip_slot_flag(crop_region(img, flag_r), slot)
            if slot_flag in skip_flags:
                self.log(f"  equipment{slot}: {slot_flag.value} -> skipped")
                setattr(entry, equip_key, slot_flag.value)
                entry.set_meta(equip_key,
                               FieldMeta.skipped(f"slot_flag={slot_flag.value}"))
                if scan_level:
                    entry.set_meta(level_key,
                                   FieldMeta.skipped(f"slot_flag={slot_flag.value}"))
                if slot == 2 and slot_flag == EquipSlotFlag.EMPTY:
                    self._status("equip2.slot_flag.empty", student_name=entry.display_name)
                elif slot == 2 and slot_flag == EquipSlotFlag.LEVEL_LOCKED:
                    self._status("equip2.slot_flag.level_locked", student_name=entry.display_name)
                elif slot == 3 and slot_flag == EquipSlotFlag.EMPTY:
                    self._status("equip3.slot_flag.empty", student_name=entry.display_name)
                elif slot == 3 and slot_flag == EquipSlotFlag.LEVEL_LOCKED:
                    self._status("equip3.slot_flag.level_locked", student_name=entry.display_name)
                elif slot == 4 and slot_flag == EquipSlotFlag.EMPTY:
                    self._status("favorite.slot_flag.empty", student_name=entry.display_name)
                elif slot == 4 and slot_flag == EquipSlotFlag.LOVE_LOCKED:
                    self._status("favorite.slot_flag.love_locked", student_name=entry.display_name)
                elif slot == 4 and slot_flag == EquipSlotFlag.NULL:
                    self._status("favorite.slot_flag.null", student_name=entry.display_name)
                return

        tier_r = sr.get(f"equipment_{slot}")
        tier_candidates: list[tuple[str, float]] = []
        if tier_r:
            tier_crop = crop_region(img, tier_r)
            tier_candidates = rank_equip_tier_candidates(tier_crop, slot)
            _log.debug(
                f"equip{slot} tier: "
                + " ".join(f"{t}={s:.3f}" for t, s in tier_candidates)
            )
        else:
            entry.set_meta(equip_key, FieldMeta.region_missing(f"equipment_{slot}"))

        lv: int | None = None
        if scan_level:
            d1 = sr.get(f"equipment_{slot}_level_digit_1")
            d2 = sr.get(f"equipment_{slot}_level_digit_2")
            if d1 and d2:
                lv = read_equip_level(
                    img,
                    slot,
                    d1,
                    d2,
                    getattr(self, "_equip_level_run_templates", None),
                )
                setattr(entry, level_key, lv)
                entry.set_meta(level_key,
                               FieldMeta.ok(FieldSource.TEMPLATE)
                               if lv is not None
                               else FieldMeta.failed(FieldSource.TEMPLATE,
                                                     "digit_read_fail"))
                self.log(f"  equipment{slot} level: {lv}")
                if lv is not None:
                    self._status(f"equip{slot}.level.ok", student_name=entry.display_name, level=lv)
                    self._field_confirmed(entry, f"equip{slot}_level", lv, display_value=f"Lv.{lv}")
            else:
                self.log(f"  missing equipment_{slot}_level_digit")
                entry.set_meta(level_key,
                               FieldMeta.region_missing(f"equipment_{slot}_level_digit"))

        if tier_r:
            tier = "unknown"
            tier_score = 0.0
            if tier_candidates:
                tier, tier_score = tier_candidates[0]
                if tier_score < EQUIP_TIER_ACCEPT_SCORE:
                    if (
                        scan_level
                        and lv == MAX_EQUIP_LEVEL
                        and tier == "T10"
                        and tier_score >= EQUIP_T10_LEVEL70_FALLBACK_SCORE
                    ):
                        entry.set_meta(
                            equip_key,
                            FieldMeta(
                                status=FieldStatus.INFERRED,
                                source=FieldSource.INFERRED,
                                score=tier_score,
                                note="level70_implies_t10",
                            ),
                        )
                    else:
                        tier = "unknown"
                        entry.set_meta(
                            equip_key,
                            FieldMeta.uncertain(
                                FieldSource.TEMPLATE,
                                score=tier_score,
                                note="tier=unknown",
                            ),
                        )
                else:
                    entry.set_meta(equip_key, FieldMeta.ok(FieldSource.TEMPLATE, score=tier_score))
            else:
                entry.set_meta(equip_key, FieldMeta.uncertain(FieldSource.TEMPLATE, note="tier=unknown"))
            setattr(entry, equip_key, tier)
            self.log(f"  equipment{slot} tier: {tier}")
            if tier != "unknown":
                if slot == 4:
                    if tier == "T1":
                        self._status("favorite.tier.t1", student_name=entry.display_name, tier=tier)
                        self._field_confirmed(entry, "equip4", tier)
                    elif tier == "T2":
                        self._status("favorite.tier.t2", student_name=entry.display_name, tier=tier)
                        self._field_confirmed(entry, "equip4", tier)
                else:
                    self._status(f"equip{slot}.tier.ok", student_name=entry.display_name, tier=tier)
                    self._field_confirmed(entry, f"equip{slot}", tier)
    def _learn_basic_level_for_run(
        self,
        image: Image.Image,
        region: dict,
        level: int,
    ) -> bool:
        digits = str(level)
        glyphs, has_second_digit = extract_basic_student_level_glyphs(image, region)
        detected_count = 2 if has_second_digit else 1
        if len(digits) != detected_count or len(glyphs) != len(digits):
            _log.info(
                "[basic_level_calibration] rejected level=%s detected_digits=%d glyphs=%d",
                level,
                detected_count,
                len(glyphs),
            )
            return False

        learned = 0
        for position, (digit, glyph) in enumerate(zip(digits, glyphs)):
            position_templates = self._basic_level_run_templates.setdefault(position, {})
            variants = position_templates.setdefault(digit, [])
            variants.append(glyph.copy())
            del variants[:-4]
            learned += 1
        total = sum(
            len(variants)
            for position_templates in self._basic_level_run_templates.values()
            for variants in position_templates.values()
        )
        _log.info(
            "[basic_level_calibration] learned level=%s digits=%s samples_added=%d total=%d",
            level,
            digits,
            learned,
            total,
        )
        return True
    def read_level(self, entry: StudentEntry) -> None:
        """Read the student level tab and parse the level digits."""
        ctx = ScanCtx(student_id=entry.student_id, step="read_level")
        self._status("level.start", student_name=entry.display_name)
        sr = self.r["student"]
        basic_region = sr.get("basic_level_digits_quad")
        basic_img = self._get_student_basic_capture()
        prepared_level = self._get_student_basic_region("basic_level_digits_quad")
        if basic_img is not None and basic_region is not None:
            level_img = prepared_level.image if prepared_level is not None else basic_img
            level_region = prepared_level.region if prepared_level is not None else basic_region
            basic_result = read_basic_student_level_result(
                level_img,
                level_region,
                self._basic_level_run_templates,
            )
            if basic_result.value is not None and not basic_result.uncertain:
                entry.level = int(basic_result.value)
                entry.set_meta("level", FieldMeta.ok(FieldSource.TEMPLATE, score=basic_result.score))
                self._status("level.read.ok", student_name=entry.display_name, level=entry.level)
                self._field_confirmed(entry, "level", entry.level, display_value=f"Lv.{entry.level}")
                _log.info(
                    "[basic_level] success student=%s value=%s score=%.3f label=%s",
                    entry.student_id,
                    entry.level,
                    basic_result.score,
                    basic_result.label,
                )
                self.log(
                    f"  ??????????????????????????????? {entry.label()} -> Lv.{entry.level} "
                    f"(score={basic_result.score:.3f})"
                )
                return
            _log.info(
                "[basic_level] fallback student=%s value=%s score=%.3f label=%s",
                entry.student_id,
                basic_result.value,
                basic_result.score,
                basic_result.label,
            )

        img = self._click_student_region_and_wait(
            "levelcheck_button",
            "levelcheck_button",
            self._is_level_tab_on_capture,
            timeout=TAB_ON_READY_WAIT,
            fallback_delay=0.5,
        )
        if img is None:
            _log.warning(f"{ctx} level tab capture failed")
            entry.set_meta("level", FieldMeta.failed(FieldSource.TEMPLATE, "tab_fail"))
            return

        d1 = sr.get("level_digit_1")
        d2 = sr.get("level_digit_2")
        if not d1 or not d2:
            _log.warning(f"{ctx} missing level_digit region")
            self._restore_basic_tab()
            entry.set_meta("level", FieldMeta.region_missing("level_digit"))
            return

        lv = read_student_level_v5(img, d1, d2)
        for _ in range(2):
            if lv is not None:
                break
            if not self._wait(LEVEL_CAPTURE_RETRY_WAIT):
                break
            retry_img = self._capture()
            if retry_img is None:
                break
            retry_level = read_student_level_v5(retry_img, d1, d2)
            if retry_level is not None:
                img = retry_img
                lv = retry_level
                break
        entry.level = lv

        if lv is not None:
            entry.set_meta("level", FieldMeta.ok(FieldSource.TEMPLATE))
            self._status("level.read.ok", student_name=entry.display_name, level=lv)
            self._field_confirmed(entry, "level", lv, display_value=f"Lv.{lv}")
            self.log(f"  ?????????????? {entry.label()} -> Lv.{lv}")
            if basic_img is not None and basic_region is not None:
                self._learn_basic_level_for_run(basic_img, basic_region, lv)
        else:
            entry.set_meta("level", FieldMeta.failed(FieldSource.TEMPLATE, "digit_read_fail"))
            self._status("level.read.failed", student_name=entry.display_name)
            _log.warning(f"{ctx} level digit read failed")
            if self._asv:
                self._asv.on_step_error("read_level", entry.student_id or "")

        self._restore_basic_tab()
    def read_student_star(self, entry: StudentEntry) -> None:
        """Read the student's star count, or infer it from weapon unlock state."""
        self._status("star.start", student_name=entry.display_name)


        ctx = ScanCtx(student_id=entry.student_id, step="read_student_star")

        weapon_meta = entry.get_meta("weapon_state")
        weapon_state_confirmed = (
            weapon_meta is not None
            and weapon_meta.status == FieldStatus.OK
        )
        can_infer_from_weapon = (
            weapon_state_confirmed
            and entry.weapon_state in (
                WeaponState.WEAPON_EQUIPPED,
                WeaponState.WEAPON_UNLOCKED_NOT_EQUIPPED,
            )
        )
        if can_infer_from_weapon:
            # Students with a weapon system unlocked are guaranteed to be 5-star.
            entry.student_star = 5
            entry.set_meta("student_star",
                           FieldMeta.inferred("weapon_state implies student star 5"))
            self._status("star.infer_from_weapon", student_name=entry.display_name, star=5)
            self._field_confirmed(entry, "student_star", 5, display_value="5 stars")
            self.log("  ????????????????????밸븶筌믩끃??獄???????멥렑???????????????????耀붾굝?????臾먮뼁?????쇨덫?????????????????????????濾???????????????????????癲???????????????????????????????????????????????????????⑤벡????????? ??????-> ????????????????????????????????????????(5????????????????????")
            return
        if entry.weapon_state == WeaponState.WEAPON_UNLOCKED_NOT_EQUIPPED:
            self.log("  weapon state implies 5-star -> skipping star menu scan")

        sr = self.r["student"]
        basic_region = sr.get("basic_student_stars_quad")
        basic_img = self._get_student_basic_capture()
        prepared_star = self._get_student_basic_region("basic_student_stars_quad")
        if basic_img is not None and basic_region is not None:
            star_img = prepared_star.image if prepared_star is not None else basic_img
            star_region = prepared_star.region if prepared_star is not None else basic_region
            basic_result = read_basic_student_star_result(star_img, star_region)
            if basic_result.value is not None and not basic_result.uncertain:
                entry.student_star = int(basic_result.value)
                entry.set_meta(
                    "student_star",
                    FieldMeta.ok(FieldSource.TEMPLATE, score=basic_result.score),
                )
                self._status(
                    "star.read.ok",
                    student_name=entry.display_name,
                    star=entry.student_star,
                )
                self._field_confirmed(entry, "student_star", entry.student_star, display_value=f"{entry.student_star} stars")
                _log.info(
                    "[basic_star] success student=%s value=%s score=%.3f label=%s",
                    entry.student_id,
                    entry.student_star,
                    basic_result.score,
                    basic_result.label,
                )
                self.log(
                    f"  ????????????????????????? {entry.label()} -> {entry.student_star}??"
                    f"(score={basic_result.score:.3f})"
                )
                return
            _log.info(
                "[basic_star] fallback student=%s value=%s score=%.3f label=%s",
                entry.student_id,
                basic_result.value,
                basic_result.score,
                basic_result.label,
            )

        img = self._click_student_region_and_wait(
            "star_menu_button",
            "star_menu",
            self._is_star_tab_on_capture,
            timeout=TAB_ON_READY_WAIT,
            fallback_delay=0.3,
        )
        if img is None:
            entry.set_meta("student_star",
                           FieldMeta.failed(FieldSource.TEMPLATE, "capture_fail"))
            return

        region_key = (
            "student_star_region"
            if "student_star_region" in sr
            else "star_region"
        )
        star_r = sr.get(region_key)
        if not star_r:
            entry.set_meta("student_star",
                           FieldMeta.region_missing(region_key))
            return

        from core.matcher import read_student_star_v5_result
        r = read_student_star_v5_result(crop_region(img, star_r))

        entry.student_star = r.value
        if r.uncertain or r.value is None:
            entry.set_meta("student_star",
                           FieldMeta.uncertain(FieldSource.TEMPLATE,
                                               score=r.score,
                                               note=f"value={r.value}"))
            self._status("star.read.uncertain", student_name=entry.display_name, star=r.value, technical=f"score={r.score:.3f}")
            _log.warning(f"{ctx} ????????????????????????????????????(score={r.score:.3f} val={r.value})")
        else:
            entry.set_meta("student_star",
                           FieldMeta.ok(FieldSource.TEMPLATE, score=r.score))
            self._status("star.read.ok", student_name=entry.display_name, star=entry.student_star)
            self._field_confirmed(entry, "student_star", entry.student_star, display_value=f"{entry.student_star} stars")
            self.log(f"  ???????? {entry.label()} -> {entry.student_star}??(score={r.score:.3f})")
    def _student_form_template_candidates(self, student_id: str, form_index: int) -> list[Path]:
        template_names: list[str] = []
        configured = student_meta.field_for_form(student_id, "template_name", form_index)
        if configured:
            template_names.append(str(configured))
        base_name = student_meta.template_path(student_id)
        if form_index == 1:
            template_names.append(base_name)
        else:
            base = Path(base_name)
            suffix = base.suffix or ".png"
            template_names.append(f"{base.stem}_{form_index - 1}{suffix}")
            template_names.append(f"{student_id}_{form_index - 1}.png")
        seen: set[str] = set()
        paths: list[Path] = []
        for template_name in template_names:
            if not template_name or template_name in seen:
                continue
            seen.add(template_name)
            path = TEMPLATE_DIR / "students" / template_name
            if path.exists():
                paths.append(path)
        return paths
    def _match_current_student_form_by_template(self, student_id: str, image: Image.Image) -> int | None:
        texture_r = self.r.get("student", {}).get("student_texture_region")
        if not texture_r:
            return None
        crop = crop_region(image, texture_r)
        scores: list[tuple[int, float, str]] = []
        for form_index in student_meta.form_indexes(student_id):
            form_scores = [
                match_score_resized(crop, str(path))
                for path in self._student_form_template_candidates(student_id, form_index)
            ]
            if form_scores:
                best_score = max(form_scores)
                scores.append((form_index, best_score, str(form_scores)))
        if not scores:
            return None
        scores.sort(key=lambda item: item[1], reverse=True)
        best_form, best_score, _detail = scores[0]
        second_score = scores[1][1] if len(scores) > 1 else 0.0
        margin = best_score - second_score
        _log.debug(
            "multi-form template: student=%s best=%s score=%.3f margin=%.3f all=%s",
            student_id,
            best_form,
            best_score,
            margin,
            " ".join(f"{form}({score:.3f})" for form, score, _ in scores),
        )
        if best_score >= 0.60 and margin >= 0.025:
            return student_meta.normalize_form_index(student_id, best_form)
        return None
    def _match_current_student_form_by_attributes(self, student_id: str, image: Image.Image) -> int:
        regions = self.r.get("student", {})
        attributes: dict[str, str] = {}
        for field in ("attack_type", "defense_type", "position", "combat_class", "role"):
            region_key = f"basic_attribute_{field}"
            region = regions.get(region_key)
            if region is None:
                continue
            crop = crop_region(image, region)
            result = read_basic_student_attribute_result(crop, field)
            if result.value is not None and not result.uncertain:
                attributes[field] = str(result.value)
        best_form = 1
        best_score = -1
        for form_index in student_meta.form_indexes(student_id):
            score = 0
            for field, detected in attributes.items():
                expected = student_meta.field_for_form(student_id, field, form_index)
                if expected is not None and str(expected) == detected:
                    score += 1
            if score > best_score:
                best_score = score
                best_form = form_index
        _log.debug("multi-form attribute: student=%s form=%s score=%s attrs=%s", student_id, best_form, best_score, attributes)
        return student_meta.normalize_form_index(student_id, best_form)
    def _current_student_form_index(self, student_id: str) -> int:
        if not student_meta.is_multi_form(student_id):
            return 1
        image = self._get_student_basic_capture(refresh=True)
        if image is None:
            return 1
        template_form = self._match_current_student_form_by_template(student_id, image)
        if template_form is not None:
            return template_form
        return self._match_current_student_form_by_attributes(student_id, image)
    def _student_form_region(self, form_index: int) -> Optional[dict]:
        regions = self.r.get("student", {})
        return regions.get(f"style_form_{form_index}_button") or regions.get(f"student_form_{form_index}_button")
    def _switch_student_form(self, form_index: int) -> bool:
        region = self._student_form_region(form_index)
        if not region:
            self.log(f"  form {form_index} switch region missing")
            return False
        self._invalidate_student_basic_capture()
        if not self._click_r(region, f"student_form_{form_index}"):
            return False
        return self._settle_student_detail(f"student_form_{form_index}", initial_wait=0.35, timeout=2.0, poll=0.15)
    def _copy_combat_stats_from_entry(self, source: StudentEntry, target: StudentEntry) -> None:
        for field_name in _COMBAT_STAT_FIELDS:
            setattr(target, field_name, getattr(source, field_name, None))
            meta = source.get_meta(field_name)
            if meta is not None:
                target.set_meta(field_name, meta)
    def read_multi_form_combat_stats(self, entry: StudentEntry) -> None:
        student_id = entry.student_id or ""
        if not student_meta.is_multi_form(student_id):
            return
        current_form = self._current_student_form_index(student_id)
        _store_entry_form_combat_stats(entry, current_form)
        other_forms = [form for form in student_meta.form_indexes(student_id) if form != current_form]
        if not other_forms:
            return
        original_stats = _entry_combat_stats(entry)
        original_meta = {field_name: entry.get_meta(field_name) for field_name in _COMBAT_STAT_FIELDS}
        for form_index in other_forms:
            if self._stop_requested():
                break
            if not self._switch_student_form(form_index):
                continue
            self._status("student.form.switch", student_id=entry.student_id, student_name=entry.display_name, form_index=form_index)
            probe = StudentEntry(student_id=entry.student_id, display_name=entry.display_name)
            self.read_basic_combat_stats(probe)
            _store_entry_form_combat_stats(probe, form_index)
            if str(form_index) in probe.form_combat_stats:
                entry.form_combat_stats[str(form_index)] = probe.form_combat_stats[str(form_index)]
                self.log(f"  form {form_index} combat stats saved: {entry.form_combat_stats[str(form_index)]}")
        for field_name, value in original_stats.items():
            setattr(entry, field_name, value)
        for field_name, meta in original_meta.items():
            if meta is not None:
                entry.set_meta(field_name, meta)
        if current_form != student_meta.normalize_form_index(student_id, current_form):
            current_form = student_meta.normalize_form_index(student_id, current_form)
        if other_forms and current_form in student_meta.form_indexes(student_id):
            if self._switch_student_form(current_form):
                self._status("student.form.switch", student_id=entry.student_id, student_name=entry.display_name, form_index=current_form)
    def read_basic_combat_stats(self, entry: StudentEntry) -> None:
        """Read basic-screen combat values and additional-stat badge presence."""
        image = self._get_student_basic_capture()
        if image is None:
            return
        regions = self.r.get("student", {})
        from core.matcher import (
            read_basic_additional_stat_badge_result,
            read_basic_additional_stat_value_result,
            read_basic_combat_stat_result,
        )

        combat_details: dict[str, str] = {}
        for stat_key, field_name in (
            ("hp", "combat_hp"),
            ("atk", "combat_atk"),
            ("def", "combat_def"),
            ("heal", "combat_heal"),
        ):
            region_key = f"basic_combat_{stat_key}_digits"
            region = regions.get(region_key)
            if not region:
                entry.set_meta(field_name, FieldMeta.region_missing(region_key))
                continue
            result = read_basic_combat_stat_result(image, region)
            combat_details[stat_key] = result.label
            setattr(entry, field_name, result.value)
            if result.value is None or result.uncertain:
                entry.set_meta(field_name, FieldMeta.uncertain(
                    FieldSource.TEMPLATE, score=result.score, note=result.label
                ))
            else:
                entry.set_meta(field_name, FieldMeta.ok(FieldSource.TEMPLATE, score=result.score))
                self._field_confirmed(entry, field_name, result.value)

        badges: dict[str, Optional[bool]] = {}
        additional_values: dict[str, Optional[int]] = {}
        for stat_key in ("hp", "atk", "heal"):
            region_key = f"basic_additional_badge_{stat_key}"
            region = regions.get(region_key)
            if not region:
                badges[stat_key] = None
                additional_values[stat_key] = None
                continue
            result = read_basic_additional_stat_badge_result(image, region)
            badge_present = result.value if not result.uncertain else None
            badges[stat_key] = badge_present
            if badge_present is True:
                value_result = read_basic_additional_stat_value_result(image, region)
                additional_values[stat_key] = (
                    int(value_result.value)
                    if value_result.value is not None and not value_result.uncertain
                    else None
                )
                combat_details[f"additional_{stat_key}"] = value_result.label
            elif badge_present is False:
                additional_values[stat_key] = 0
            else:
                additional_values[stat_key] = None
        entry._basic_additional_badges = badges
        entry._basic_additional_values = additional_values
        _log.debug("basic combat recognition details: %s", combat_details)
        self.log(
            f"  basic stats: HP={entry.combat_hp} ATK={entry.combat_atk} "
            f"DEF={entry.combat_def} HEAL={entry.combat_heal} "
            f"badges={badges} additional={additional_values}"
        )
    def read_stats(self, entry: StudentEntry) -> None:
        """
        Lv.90 + 5??????????????????????????????????????????????????????????????????????????????????????
        ??????????????????????????????????ㅻ깹??????????????????????????????????????????????????????????????????????????HP / ATK / HEAL ??????????????????????????????????????
        """
        self._status("stats.start", student_name=entry.display_name)
        level_ok = entry.level is not None and entry.level >= STAT_UNLOCK_LEVEL
        star_ok  = entry.student_star is not None and entry.student_star >= STAT_UNLOCK_STAR

        if not level_ok or not star_ok:
            self.log(
                f"  ??????????????????????????????????????????????????????????"
                f"(Lv.{entry.level} / {entry.student_star}??"
            )
            self._status("stats.skip_condition", student_name=entry.display_name, level=entry.level, star=entry.student_star)
            return

        badges = getattr(entry, "_basic_additional_badges", {})
        additional_values = getattr(entry, "_basic_additional_values", {})
        stat_pairs = (("hp", "stat_hp"), ("atk", "stat_atk"), ("heal", "stat_heal"))
        confirmed_basic_stats: dict[str, int] = {}
        for stat_key, _field_name in stat_pairs:
            if stat_key in additional_values and additional_values.get(stat_key) is not None:
                confirmed_basic_stats[stat_key] = int(additional_values[stat_key] or 0)
            elif badges.get(stat_key) is False:
                confirmed_basic_stats[stat_key] = 0

        if len(confirmed_basic_stats) == len(stat_pairs):
            for stat_key, field_name in stat_pairs:
                value = confirmed_basic_stats[stat_key]
                setattr(entry, field_name, value)
                if badges.get(stat_key) is False:
                    entry.set_meta(field_name, FieldMeta.inferred("basic_screen_badge_absent"))
                else:
                    entry.set_meta(field_name, FieldMeta.ok(FieldSource.TEMPLATE))
            self._status(
                "stats.basic_values_skip",
                student_name=entry.display_name,
                hp=entry.stat_hp,
                atk=entry.stat_atk,
                heal=entry.stat_heal,
            )
            self._field_confirmed(entry, "stat_hp", entry.stat_hp)
            self._field_confirmed(entry, "stat_atk", entry.stat_atk)
            self._field_confirmed(entry, "stat_heal", entry.stat_heal)
            self.log(
                "  basic screen additional stats confirmed -> "
                f"stat menu skipped ({entry.stat_hp}/{entry.stat_atk}/{entry.stat_heal})"
            )
            return

        self._active_student_panel = "stat"
        img = self._click_student_region_and_wait(
            "stat_menu_button",
            "stat_menu_button",
            lambda capture: self._is_student_panel_title_capture(capture, "stat"),
            timeout=ADDITIONAL_PANEL_READY_WAIT,
            fallback_delay=0.4,
            match_delay=STAT_PANEL_MATCH_DELAY,
        )
        if img is None:
            self._esc()
            return

        ctx = ScanCtx(student_id=entry.student_id, step="read_stats")

        sr = self.r["student"]
        self._student_stat_crops = ScreenCropSet.from_image(
            img,
            sr,
            keys=("hp", "atk", "heal"),
        )
        for stat_key, field_name, region_key in [
            ("hp",   "stat_hp",   "hp"),
            ("atk",  "stat_atk",  "atk"),
            ("heal", "stat_heal", "heal"),
        ]:
            region = sr.get(region_key)
            if not region:
                _log.warning(f"{ctx.with_step(field_name)} missing region")
                entry.set_meta(field_name, FieldMeta.region_missing(region_key))
                continue

            from core.matcher import read_stat_value_result
            prepared = self._student_stat_crops.get(region_key)
            stat_crop = prepared.image if prepared is not None else crop_region(img, region)
            r = read_stat_value_result(stat_crop, stat_key)
            setattr(entry, field_name, r.value)

            if r.value is None or r.uncertain:
                entry.set_meta(field_name,
                               FieldMeta.uncertain(FieldSource.TEMPLATE,
                                                   score=r.score,
                                                   note=f"val={r.value}"))
                _log.warning(f"{ctx.with_step(field_name)} basic combat stat uncertain "
                             f"(score={r.score:.3f} val={r.value})")
            else:
                entry.set_meta(field_name,
                               FieldMeta.ok(FieldSource.TEMPLATE, score=r.score))
                self._field_confirmed(entry, field_name, r.value)

        self.log(
            f"  ???????????????????? HP={entry.stat_hp} "
            f"ATK={entry.stat_atk} HEAL={entry.stat_heal}"
        )
        self._status(
            "stats.summary",
            student_name=entry.display_name,
            hp=entry.stat_hp,
            atk=entry.stat_atk,
            heal=entry.stat_heal,
        )
        self._close_student_panel(
            capture_name="stat_close_button",
            region_key="statmenu_quit_button",
            settle_reason="close_stat_menu",
        )
    def _log_student(self, entry: StudentEntry, idx: int) -> None:
        weapon_info = ""
        if entry.weapon_state == WeaponState.WEAPON_EQUIPPED:
            weapon_info = f" | ???????????????????????????????{entry.weapon_star}???????????????????{entry.weapon_level}"
        elif entry.weapon_state == WeaponState.WEAPON_UNLOCKED_NOT_EQUIPPED:
            weapon_info = " | weapon:not-equipped"

        equip_info = (
            f"{entry.equip1}(Lv.{entry.equip1_level})/"

            f"{entry.equip3}(Lv.{entry.equip3_level})/"
            f"{entry.equip4}"
        )
        self.log(
            f"  [{idx+1:>3}] {entry.label()}  Lv.{entry.level}  "
            f"{entry.student_star}*{weapon_info}  "
            f"EX:{entry.ex_skill} S1:{entry.skill1} "
            f"S2:{entry.skill2} S3:{entry.skill3}  "
            f"equip:{equip_info}  "
            f"stats(HP:{entry.stat_hp}/ATK:{entry.stat_atk}/HEAL:{entry.stat_heal})"
        )
        self._status(
            "summary.student.compact",
            student_name=entry.display_name,
            level=entry.level,
            star=entry.student_star,
        )


        # Emit a compact summary for uncertain / failed / inferred fields.
        uncertain = entry.uncertain_fields()
        failed    = entry.failed_fields()
        inferred  = [k for k, v in entry._meta.items()
                     if v.status == FieldStatus.INFERRED]

        if uncertain:
            _log.warning(
                f"  [{idx+1:>3}] {entry.label()} "
                f"-> uncertain: {uncertain}"
            )
        if failed:
            _log.warning(
                f"  [{idx+1:>3}] {entry.label()} "
                f"-> failed: {failed}"
            )
        if inferred:
            _log.info(
                f"  [{idx+1:>3}] {entry.label()} "
                f"-> inferred: {inferred}"
            )
