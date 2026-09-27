"""Bounded panel transitions; visual state is independent of input API success."""
from __future__ import annotations

from threading import Event
from time import monotonic
from typing import Any, Protocol

from PIL import Image, ImageStat

from core.scanner_session import ScannerError
from core.scan_context import ScanContext
from core.student_scan_recognizer import Observation, ratio_crop
from core.student_weapon_recognizer import _color_similarity, _normalized_correlation
from core import recognition_thresholds as rt


PANEL_CLOSE_KEYS = {"weapon": "weapon_menu_quit_button", "equipment": "equipmentmenu_quit_button",
                    "skill": "skillmenu_quit_button", "stat": "statmenu_quit_button"}
TAB_KEYS = {"basic": "basic_info_button", "level": "levelcheck_button", "star": "star_menu_button"}


class PanelMenu(Protocol):
    """One student detail panel: open and return a verified frame, re-read it, close back to basic.

    ``recapture`` is needed only by callers that read with ``attempts > 1``.
    """

    def capture(self, target: dict[str, Any], cancel: Event) -> Image.Image: ...
    def recapture(self, target: dict[str, Any], cancel: Event) -> Image.Image: ...
    def close(self, target: dict[str, Any]) -> None: ...


def merge_observation(previous: Observation | None, current: Observation) -> Observation:
    """Keep known values; a confirmed disagreement is sticky review evidence."""
    if previous is None:
        return current
    if previous.source == "panel_value_conflict":
        return previous
    if previous.confirmed and current.confirmed and previous.value != current.value:
        return Observation(previous.value, min(previous.confidence, current.confidence), "uncertain",
                           "panel_value_conflict", f"{previous.source}={previous.value};{current.source}={current.value}")
    if previous.confirmed:
        return previous
    if current.confirmed or current.confidence > previous.confidence:
        return current
    return previous


def read_panel_fields(menu, kind, target, cancel, initial, fields, read, *, attempts=1, retry_if=None):
    """Only a verified return makes a panel read failure recoverable as partial."""
    merged = {field: initial[field] for field in fields if field in initial}
    frame = None
    try:
        try:
            frame = menu.capture(target, cancel)
            for attempt in range(attempts):
                if cancel.is_set():
                    raise ScannerError("cancelled", "panel reading cancelled")
                if attempt:
                    frame.close()
                    frame = None
                    frame = menu.recapture(target, cancel)
                try:
                    observed = read(frame)
                except (ValueError, OSError) as exc:
                    raise ScannerError("panel_read_failed", str(exc)) from exc
                for field in fields:
                    if field in observed:
                        merged[field] = merge_observation(merged.get(field), observed[field])
                if all(field in merged and (merged[field].confirmed or merged[field].source == "panel_value_conflict") for field in fields):
                    break
                if retry_if is not None and not retry_if(merged):
                    break
        finally:
            if frame is not None:
                frame.close()
            menu.close(target)
    except ScannerError as exc:
        safe = (exc.details.get("screen_state") == "basic"
                or getattr(getattr(menu, "recovery", None), "state", None) == "basic")
        if not safe or exc.code not in {"panel_open_failed", "panel_unconfirmed", "capture_failed", "capture_timeout", "panel_read_failed"}:
            raise
        merged[f"{kind}_panel"] = Observation(None, 0, "partial", "panel_recovery", exc.code+";same-student basic restored")
    if any(field not in merged or not merged[field].confirmed for field in fields):
        merged.setdefault(f"{kind}_panel", Observation(None, 0, "partial", "panel_recovery", "fields unresolved after bounded reads"))
    return merged


class StudentPanelRecognizer:
    NAME_REGION = dict(x1=.055, y1=.77, x2=.205, y2=.82)

    def __init__(self, catalog):
        self.regions = catalog.region_for_purpose("student", "student-panel-regions")
        self.portrait_region = catalog.region("student")["student_texture_region"]
        self.templates = {}
        for asset in catalog.assets("student", "student-panel-template"):
            with Image.open(catalog.resolve(asset.path)) as source:
                self.templates[asset.identity] = source.convert("RGB")
        if set(self.templates) != set(PANEL_CLOSE_KEYS) | set(TAB_KEYS):
            self.close()
            raise ScannerError("template_missing", "panel titles and active tabs are required")
        self.scores = {}

    def classify(self, frame):
        scores = {}
        for state, template in self.templates.items():
            crop = ratio_crop(frame, self.regions[TAB_KEYS.get(state, "title")])
            try:
                correlation = _normalized_correlation(crop, template)
                color = _color_similarity(crop, template)
                # Active tabs depend on both light surface and dark glyphs. A separate
                # NCC floor tolerates 1280 glyph antialiasing without accepting blank UI.
                scores[state] = (color if correlation >= rt.value("student.panel.tab.correlation_floor") else 0) if state in TAB_KEYS else .7 * correlation + .3 * color
            finally:
                crop.close()
        self.scores = scores
        titles = sorted(PANEL_CLOSE_KEYS, key=lambda name: scores[name], reverse=True)
        if scores[titles[0]] >= rt.value("student.panel.title.score") and scores[titles[0]] - scores[titles[1]] >= rt.value("student.panel.title.margin"):
            return titles[0]
        # Do not accept a dimmed underlying tab when a panel title is ambiguous.
        if scores[titles[0]] >= rt.value("student.panel.title.ambiguous"):
            return "unknown"
        tabs = [name for name in TAB_KEYS if scores[name] >= rt.value("student.panel.tab.score")]
        return tabs[0] if len(tabs) == 1 else "unknown"

    def identity(self, frame):
        return [ratio_crop(frame, region) for region in (self.NAME_REGION, self.portrait_region)]

    def same_student(self, frame, baseline):
        current = self.identity(frame)
        try:
            gray = baseline[0].convert("L")
            try:
                signal = ImageStat.Stat(gray).stddev[0] >= 8
            finally:
                gray.close()
            return signal and _color_similarity(current[0], baseline[0]) >= rt.value("student.panel.same_student.name_color") and _color_similarity(current[1], baseline[1]) >= rt.value("student.panel.same_student.portrait_color")
        finally:
            for image in current:
                image.close()

    def close(self):
        for image in self.templates.values():
            image.close()
        self.templates.clear()


class StudentPanelRecovery:
    OPEN_CAPTURES, OPEN_SECONDS, CLOSE_SECONDS = 4, 4.0, 5.0

    def __init__(self, capture, catalog, *, recognizer=None):
        self.capture = capture
        self.recognizer = recognizer or StudentPanelRecognizer(catalog)
        self.regions = self.recognizer.regions
        self.baseline = None
        self.target_id = None
        self.state = "unknown"
        self.trace = []

    @staticmethod
    def _center(region):
        return ((region["x1"] + region["x2"]) / 2, (region["y1"] + region["y2"]) / 2)

    def _observe(self, target, cancel, deadline):
        if cancel.is_set():
            raise ScannerError("cancelled", "panel transition cancelled")
        remaining = deadline - monotonic()
        if remaining <= 0:
            raise ScannerError("panel_timeout", "panel observation budget exhausted")
        frame = self.capture.wait_stable(target, cancel, timeout=min(1.0, remaining))
        try:
            self.state = self.recognizer.classify(frame)
            self.trace.append({"state": self.state, "scores": dict(self.recognizer.scores)})
            if cancel.is_set():
                raise ScannerError("cancelled", "cancelled during panel observation")
            if self.state == "basic" and self.baseline is not None and not self.recognizer.same_student(frame, self.baseline):
                self.state = "unknown"
                raise ScannerError("panel_student_changed", "return screen belongs to another student")
            return frame
        except Exception:
            frame.close()
            raise

    def _poll(self, target, cancel, expected, deadline, count):
        for index in range(count):
            delay = .35 if index == count - 1 else .15
            if cancel.wait(min(delay, max(0, deadline - monotonic()))):
                raise ScannerError("cancelled", "panel transition cancelled")
            try:
                frame = self._observe(target, cancel, deadline)
            except ScannerError as exc:
                if exc.code not in {"capture_failed", "capture_timeout", "panel_timeout"}:
                    raise
                self.state = "unknown"
                self.trace.append({"error": exc.code})
                continue
            if self.state == expected:
                return frame
            frame.close()
        raise ScannerError("panel_unconfirmed", f"expected {expected}; observed {self.state}")

    def open(self, target, cancel, panel, button):
        if self.baseline is not None:
            raise ScannerError("panel_active", "previous panel has not returned safely")
        self.trace = []
        target = ScanContext.of(target).replace(cancel=cancel)
        deadline = monotonic() + self.OPEN_SECONDS
        frame = self._observe(target, cancel, deadline)
        try:
            if self.state != "basic":
                raise ScannerError("panel_wrong_start", "open requires verified basic tab")
            self.baseline = self.recognizer.identity(frame)
            self.target_id = target.get("target_id")
        finally:
            frame.close()
        try:
            self.capture.click(target, *self._center(button))
            self.trace.append({"input": "open", "panel": panel})
            return self._poll(target, cancel, panel, deadline, self.OPEN_CAPTURES)
        except Exception as exc:
            self.restore(target)
            if cancel.is_set():
                raise ScannerError("cancelled", "panel opening cancelled; basic restored") from exc
            if isinstance(exc, ScannerError) and (exc.code.startswith("input_") or exc.code.startswith("target_")):
                raise
            raise ScannerError("panel_open_failed", "panel did not open; basic restored",
                               details={"screen_state": "basic"}) from exc

    def recapture(self, target, cancel, panel):
        if self.baseline is None or target.get("target_id") != self.target_id:
            raise ScannerError("panel_not_active", "recapture has no matching open panel")
        return self._poll(ScanContext.of(target).replace(cancel=cancel), cancel, panel, monotonic() + 2.0, 2)

    def _clear_baseline(self):
        for image in self.baseline or ():
            image.close()
        self.baseline = None
        self.target_id = None

    def restore(self, target):
        if self.baseline is None:
            return
        if target.get("target_id") != self.target_id:
            raise ScannerError("panel_target_changed", "cleanup target differs from open target")
        cleanup = ScanContext.of(target).replace(cleanup=True, cancel=Event())
        cancel = cleanup.cancel
        deadline = monotonic() + self.CLOSE_SECONDS
        try:
            for attempt in range(4):
                try:
                    frame = self._poll(cleanup, cancel, "basic", deadline, 1 if attempt == 0 else 2)
                    frame.close()
                    return
                except ScannerError as exc:
                    if exc.code != "panel_unconfirmed":
                        raise
                if attempt == 3 or monotonic() >= deadline:
                    break
                if self.state in PANEL_CLOSE_KEYS and attempt < 2:
                    x, y = self._center(self.regions[PANEL_CLOSE_KEYS[self.state]])
                    if attempt == 1:
                        x += self.regions["alternate_close_dx"]
                    try:
                        self.capture.click(cleanup, x, y)
                    except ScannerError as exc:
                        if exc.code != "input_failed":
                            raise
                elif self.state in {"level", "star"} and attempt < 2:
                    self.capture.click(cleanup, *self._center(self.regions["basic_info_button"]))
                else:
                    if not self.capture.press_key(cleanup, "escape"):
                        raise ScannerError("input_failed", "Escape was rejected")
                self.trace.append({"input": "restore", "attempt": attempt + 1})
            raise ScannerError("panel_restore_failed", f"basic return unconfirmed: {self.state}")
        except Exception as exc:
            self.state = "unknown"
            raise ScannerError("panel_restore_failed", "same-student basic return not verified") from exc
        finally:
            self._clear_baseline()

    def close(self):
        self._clear_baseline()
        self.recognizer.close()
