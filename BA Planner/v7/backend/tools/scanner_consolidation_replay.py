"""C0 screen-state replay for the scanner consolidation golden fixtures.

Test and tool support only; production never imports this module. Recorded game frames
are labelled as screens, and each input moves the replay between screens by the control
name it hits, so the production adapter wiring runs on fixed frames without a game.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from threading import Event
from typing import Any

from PIL import Image

from core.inventory_detail_recovery import InventoryDetailRecognizer, InventoryDetailRecovery
from core.inventory_navigation import InventoryNavigation
from core.recognition_answer_samples import RecognitionAnswerSampleStore
from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import (
    EquipmentMenuCaptureAdapter, InventoryMatcherAdapter, LevelMenuCaptureAdapter, SkillMenuCaptureAdapter,
    StarMenuCaptureAdapter, StatMenuCaptureAdapter, StudentMatcherAdapter, WeaponMenuCaptureAdapter,
)
from core.scanner_session import ScanBatchResult, ScannerError
from core.student_form_recovery import StudentFormRecovery
from core.student_identity_recovery import StudentEntryRecovery
from core.student_panel_recovery import StudentPanelRecovery


V7_ROOT = Path(__file__).resolve().parents[2]
FIXTURE_DIR = V7_ROOT / "backend/tests/fixtures/scanner_consolidation"
SCENARIOS = FIXTURE_DIR / "scenarios.json"
GOLDEN_DIR = FIXTURE_DIR / "golden"
SESSION_ID = "c0-golden"
# Answer-sample scopes require a 24-hex account id; the store itself is an empty temp dir.
GOLDEN_PROFILE_ID = "c0" * 12


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _key(x: float, y: float) -> tuple[float, float]:
    return round(float(x), 6), round(float(y), 6)


def control_index(catalog: RecognitionAssetCatalog, scan_kind: str) -> dict[tuple[float, float], list[str]]:
    """Map every region center of one scan kind to its region names."""
    index: dict[tuple[float, float], set[str]] = {}

    def visit(value: Any, name: str) -> None:
        if isinstance(value, dict):
            if all(isinstance(value.get(k), (int, float)) for k in ("x1", "y1", "x2", "y2")):
                center = _key((value["x1"] + value["x2"]) / 2, (value["y1"] + value["y2"]) / 2)
                index.setdefault(center, set()).add(name)
            for child, item in value.items():
                visit(item, child)
        elif isinstance(value, list):
            for position, item in enumerate(value):
                visit(item, f"{name}[{position}]")

    manifest = catalog.load()
    purposes = sorted({raw["purpose"] for raw in manifest["assets"]
                       if raw.get("scan_kind") == scan_kind and str(raw.get("purpose", "")).endswith("-regions")})
    for purpose in purposes:
        visit(catalog.region_for_purpose(scan_kind, purpose), purpose)
    return {center: sorted(names) for center, names in index.items()}


class ReplayCapture:
    """Capture/input port whose frames follow a labelled screen graph."""

    def __init__(self, scenario: dict[str, Any], controls: dict[tuple[float, float], list[str]]) -> None:
        self.scenario = scenario
        self.controls = controls
        self.screen = scenario["initial"]
        self.transitions = scenario.get("transitions", {})
        self.images: dict[str, Image.Image] = {}
        self.inputs: list[dict[str, Any]] = []
        self.captures: list[str] = []

    def _frame(self) -> Image.Image:
        if self.screen not in self.images:
            path = V7_ROOT / self.scenario["screens"][self.screen]["path"]
            with Image.open(path) as source:
                self.images[self.screen] = source.convert("RGB")
        if not self.captures or self.captures[-1] != self.screen:
            self.captures.append(self.screen)
        return self.images[self.screen].copy()

    def _move(self, record: dict[str, Any], keys: list[str]) -> None:
        rules = self.transitions.get(self.screen, {})
        record["from"] = self.screen
        for key in keys:
            if key in rules:
                self.screen = rules[key]
                break
        else:
            record["unmapped"] = True
        record["to"] = self.screen
        self.inputs.append(record)

    def capture(self, _target, *, cancel=None, timeout=2.0):
        return self._frame()

    def wait_stable(self, _target, cancel: Event, timeout: float = 2.0):
        if cancel is not None and cancel.is_set():
            raise ScannerError("cancelled", "capture cancelled")
        return self._frame()

    def click(self, target, x_ratio, y_ratio):
        names = self.controls.get(_key(x_ratio, y_ratio), [])
        record = {"input": "click", "x": round(float(x_ratio), 6), "y": round(float(y_ratio), 6),
                  "names": names, "cleanup": bool(target.get("_scanner_cleanup", False))}
        self._move(record, [*(f"click:{name}" for name in names),
                            f"click@{round(float(x_ratio), 4)},{round(float(y_ratio), 4)}", "click:*"])

    def press_key(self, target, key):
        self._move({"input": "key", "key": key, "cleanup": bool(target.get("_scanner_cleanup", False))},
                   [f"key:{key}", "key:*"])
        return True

    def scroll(self, _target, delta):
        self._move({"input": "scroll", "delta": delta}, ["scroll"])

    def drag_scroll(self, _target, start, end):
        self._move({"input": "drag_scroll", "start": [round(v, 6) for v in start],
                    "end": [round(v, 6) for v in end]}, ["drag"])

    def close(self) -> None:
        for image in self.images.values():
            image.close()
        self.images.clear()


def build_student_matcher(capture, catalog, answer_samples):
    """Same graph as core.scanner_runtime.build_scanner_service with the replay port."""
    panels = StudentPanelRecovery(capture, catalog)
    matcher = StudentMatcherAdapter(
        capture, catalog, equipment_menu=EquipmentMenuCaptureAdapter(capture, catalog, recovery=panels),
        weapon_menu=WeaponMenuCaptureAdapter(capture, catalog, recovery=panels),
        stat_menu=StatMenuCaptureAdapter(capture, catalog, recovery=panels),
        level_menu=LevelMenuCaptureAdapter(capture, catalog, recovery=panels),
        star_menu=StarMenuCaptureAdapter(capture, catalog, recovery=panels),
        skill_menu=SkillMenuCaptureAdapter(capture, catalog, recovery=panels),
        answer_samples=answer_samples,
        entry_recovery=StudentEntryRecovery(capture, catalog, panels),
        form_recovery=StudentFormRecovery(capture, catalog.region_for_purpose("student", "student-identity-regions")),
    )

    def close():
        matcher.potential_recognizer.close()
        matcher.level_recognizer.close()
        matcher.star_recognizer.close()
        matcher.skill_recognizer.close()
        matcher.equipment_controls.close()
        matcher.identity_recognizer.close()
        matcher.entry_recovery.close()
        panels.close()
    return matcher, close


def build_inventory_matcher(capture, catalog, answer_samples):
    detail = InventoryDetailRecognizer(catalog)
    matcher = InventoryMatcherAdapter(
        capture, catalog, answer_samples=answer_samples,
        detail_recovery=InventoryDetailRecovery(capture, detail),
        navigation=InventoryNavigation(capture, catalog, detail),
    )

    def close():
        matcher.detail_recovery.recognizer.close()
        matcher.navigation.close()
    return matcher, close


def normalize(value: Any) -> Any:
    """JSON-safe, image-free view. Images become size + pixel digest."""
    if isinstance(value, Image.Image):
        return {"image": {"mode": value.mode, "size": list(value.size),
                          "sha256": hashlib.sha256(value.tobytes()).hexdigest()}}
    if isinstance(value, ScannerError):
        return {"code": value.code, "message": value.message, "details": normalize(value.details)}
    if isinstance(value, ScanBatchResult):
        return {"candidates": normalize(value.candidates), "outcome": value.outcome,
                "error": normalize(value.error), "screen_state": value.screen_state,
                "coverage_complete": value.coverage_complete}
    if isinstance(value, dict):
        return {str(key): normalize(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [normalize(item) for item in value]
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    return {"repr": type(value).__name__}


def _close_images(value: Any) -> None:
    if isinstance(value, Image.Image):
        value.close()
    elif isinstance(value, dict):
        for item in value.values():
            _close_images(item)
    elif isinstance(value, (list, tuple)):
        for item in value:
            _close_images(item)


def verify_inputs(scenario: dict[str, Any]) -> list[str]:
    """Return screen names whose recorded frame is missing or differs from its pinned digest."""
    problems = []
    for name, screen in scenario["screens"].items():
        path = V7_ROOT / screen["path"]
        if not path.is_file() or file_sha256(path) != screen["sha256"]:
            problems.append(name)
    return problems


def run_scenario(scenario: dict[str, Any]) -> dict[str, Any]:
    catalog = RecognitionAssetCatalog()
    capture = ReplayCapture(scenario, control_index(catalog, scenario["scan_kind"]))
    progress_log: list[Any] = []

    def progress(current, total, message, feedback=None):
        progress_log.append([current, total, message, normalize(feedback)])
    progress.supports_feedback = True  # type: ignore[attr-defined]

    target = {"target_id": "c0-replay", "status": "ready", "profile_id": GOLDEN_PROFILE_ID,
              "_scanner_session_id": SESSION_ID, "_scanner_generation": 1, **scenario.get("target", {})}
    with TemporaryDirectory(prefix="c0-golden-") as storage:
        samples = RecognitionAnswerSampleStore(Path(storage))
        build = build_student_matcher if scenario["scan_kind"] == "student" else build_inventory_matcher
        matcher, close = build(capture, catalog, samples)
        result: Any = None
        try:
            try:
                result = matcher(target, Event(), progress)
                output = normalize(result)
            except ScannerError as exc:
                output = {"raised": normalize(exc)}
            return {
                "scenario": scenario["id"],
                "result": output,
                "inputs": capture.inputs,
                "screens_captured": capture.captures,
                "progress": progress_log,
            }
        finally:
            _close_images(result.candidates if isinstance(result, ScanBatchResult) else result)
            close()
            capture.close()


def dumps(document: dict[str, Any]) -> str:
    return json.dumps(document, ensure_ascii=False, indent=1, sort_keys=True) + "\n"


def load_scenarios() -> list[dict[str, Any]]:
    return json.loads(SCENARIOS.read_text(encoding="utf-8"))["scenarios"]


def golden_path(scenario_id: str) -> Path:
    return GOLDEN_DIR / f"{scenario_id}.json"


def main() -> None:
    import argparse
    parser = argparse.ArgumentParser(description="Compare or deliberately rewrite C0 scanner golden fixtures.")
    parser.add_argument("--write", action="store_true",
                        help="overwrite golden files; only for a phase whose status records the intended diff")
    parser.add_argument("scenario", nargs="*", help="scenario ids (default: all)")
    args = parser.parse_args()
    scenarios = [s for s in load_scenarios() if not args.scenario or s["id"] in args.scenario]
    differing = []
    for scenario in scenarios:
        if verify_inputs(scenario):
            raise SystemExit(f"{scenario['id']}: recorded input frame missing or changed")
        text = dumps(run_scenario(scenario))
        path = golden_path(scenario["id"])
        # autocrlf checkouts may turn LF into CRLF; content, not line endings, is the contract.
        same = path.is_file() and path.read_text(encoding="utf-8").replace("\r\n", "\n") == text
        if args.write and not same:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8", newline="\n")
        differing.extend([] if same else [scenario["id"]])
        print(f"{scenario['id']}: {'same' if same else 'written' if args.write else 'DIFF'}")
    if differing and not args.write:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
