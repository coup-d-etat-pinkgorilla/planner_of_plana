"""One explicitly selected student scan; no repository/profile/learning writes."""
import argparse
import json
from pathlib import Path
import sys
from threading import Event
from time import monotonic

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import StudentMatcherAdapter, StatMenuCaptureAdapter, EquipmentMenuCaptureAdapter, WeaponMenuCaptureAdapter
from core.scanner_matchers import LevelMenuCaptureAdapter
from core.student_scan_recognizer import Observation
from core.session_calibration import SessionCalibrationStore
from core.student_panel_recovery import StudentPanelRecovery
from core.windows_scanner_adapter import WindowsCaptureInputAdapter


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--force-level-fallback", action="store_true", help="Diagnostic only: discard basic level to exercise real tab fallback")
    parser.add_argument(
        "--verify-session-calibration", action="store_true",
        help="Run one injected level fallback followed by a same-student session-calibrated read",
    )
    args = parser.parse_args()
    capture = WindowsCaptureInputAdapter()
    catalog = RecognitionAssetCatalog()
    panels = StudentPanelRecovery(capture, catalog)
    level_menu = LevelMenuCaptureAdapter(capture,catalog,recovery=panels)
    level_trace = []
    close_level = level_menu.close_level_menu
    def record_level_return(target):
        try: close_level(target)
        finally: level_trace[:] = list(panels.trace)
    level_menu.close_level_menu = record_level_return
    matcher = StudentMatcherAdapter(capture, catalog,
        level_menu=level_menu,
        stat_menu=StatMenuCaptureAdapter(capture,catalog,recovery=panels),
        equipment_menu=EquipmentMenuCaptureAdapter(capture,catalog,recovery=panels),
        weapon_menu=WeaponMenuCaptureAdapter(capture,catalog,recovery=panels))
    candidates = []
    second_candidates = []
    recognize = matcher.basic_recognizer.recognize
    if args.force_level_fallback or args.verify_session_calibration:
        def without_basic_level(crops):
            observations = recognize(crops)
            observations["level"] = Observation(None,0,"uncertain","diagnostic_injected_missing","F4 live fallback probe")
            return observations
        matcher.basic_recognizer.recognize = without_basic_level
    started = monotonic()
    try:
        targets = [t for t in capture() if t["target_id"] == args.target and t["status"] == "ready"]
        if len(targets) != 1:
            raise RuntimeError("Selected game unavailable")
        target = targets[0]
        if args.verify_session_calibration:
            target = {
                **target,
                "profile_id": "f11-live-read-only",
                "_scanner_session_id": "f11-live",
                "_scanner_generation": 1,
            }
            matcher.session_calibration = SessionCalibrationStore("f11-live", 1)
        candidates = matcher._scan_current(target, Event(), lambda *args:None)
        session_samples_before_second = (
            matcher.session_calibration.sample_count
            if matcher.session_calibration is not None else 0
        )
        if args.verify_session_calibration:
            matcher.basic_recognizer.recognize = recognize
            trace_length = len(panels.trace)
            second_candidates = matcher._scan_current(target, Event(), lambda *args:None)
            second_trace = panels.trace[trace_length:]
        else:
            second_trace = []
        report = dict(seconds=monotonic()-started, target=args.target, trace=panels.trace,
                      diagnostic_forced_level_fallback=args.force_level_fallback or args.verify_session_calibration,
                      level_fallback_trace=level_trace,
                      session_calibration=dict(
                          enabled=args.verify_session_calibration,
                          samples_before_second=session_samples_before_second,
                          second_trace=second_trace,
                          second_candidates=[
                              {k:v for k,v in row.items() if k != "_answer_specimen"}
                              for row in second_candidates
                          ],
                      ),
                      candidates=[{k:v for k,v in row.items() if k != "_answer_specimen"} for row in candidates])
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
        print(json.dumps({"seconds":report["seconds"],"values":[c["payload"]["values"] for c in candidates],
                          "second_provenance":[c["payload"]["provenance"].get("level") for c in second_candidates],
                          "samples_before_second":session_samples_before_second,
                          "second_panel_inputs":[row for row in second_trace if "input" in row],
                          "panel_inputs":[row for row in panels.trace if "input" in row]}, ensure_ascii=False))
    finally:
        matcher._close_answer_specimens(candidates)
        matcher._close_answer_specimens(second_candidates)
        matcher._clear_active_session_templates()
        if matcher.session_calibration is not None:
            matcher.session_calibration.close()
            matcher.session_calibration = None
        matcher.potential_recognizer.close()
        matcher.level_recognizer.close()
        matcher.weapon_recognizer.close()
        panels.close()
        capture.close()


if __name__ == "__main__": main()
