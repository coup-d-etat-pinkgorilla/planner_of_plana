"""One selected read-only F2 panel round trip, with screenshots and state trace."""
import argparse
from dataclasses import asdict
from datetime import datetime
import json
from pathlib import Path
import sys
from threading import Event
from time import monotonic

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import EquipmentMenuCaptureAdapter, WeaponMenuCaptureAdapter, StatMenuCaptureAdapter
from core.student_potential_recognizer import StudentPotentialRecognizer
from core.scanner_matchers import LevelMenuCaptureAdapter
from core.student_level_recognizer import StudentLevelRecognizer
from core.scanner_matchers import StarMenuCaptureAdapter
from core.student_star_recognizer import StudentStarRecognizer
from core.student_panel_recovery import StudentPanelRecovery
from core.student_weapon_recognizer import StudentWeaponRecognizer
from core.windows_scanner_adapter import WindowsCaptureInputAdapter


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("panel", choices=("weapon", "equipment", "stat", "level", "star"))
    p.add_argument("--target", required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--cancel-after-open", action="store_true")
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    catalog = RecognitionAssetCatalog()
    capture = WindowsCaptureInputAdapter()
    recovery = StudentPanelRecovery(capture, catalog)
    adapter = {"weapon": WeaponMenuCaptureAdapter, "equipment": EquipmentMenuCaptureAdapter,
               "stat": StatMenuCaptureAdapter, "level": LevelMenuCaptureAdapter,
               "star": StarMenuCaptureAdapter}[args.panel](capture,catalog,recovery=recovery)
    started = monotonic()
    report = dict(at=datetime.now().astimezone().isoformat(),panel=args.panel,target=args.target,status="failed")
    try:
        targets = [t for t in capture() if t["target_id"] == args.target and t["status"] == "ready"]
        if len(targets) != 1: raise RuntimeError("Selected game unavailable")
        target = targets[0]
        cancel = Event()
        frame = getattr(adapter, f"capture_{args.panel}_menu")(target, cancel)
        try:
            frame.save(args.output / "opened.png")
            report["size"] = list(frame.size)
            if args.cancel_after_open:
                cancel.set()
                try:
                    unexpected = recovery.recapture(target, cancel, args.panel)
                    unexpected.close()
                    raise AssertionError("cancel did not stop recapture")
                except Exception as exc:
                    if getattr(exc, "code", None) != "cancelled":
                        raise
                    report["cancel_recapture"] = "cancelled_before_capture"
            if args.panel in {"weapon", "stat", "level", "star"}:
                recognizer = {"weapon":StudentWeaponRecognizer,"stat":StudentPotentialRecognizer,
                              "level":StudentLevelRecognizer,"star":StudentStarRecognizer}[args.panel](catalog)
                try: report["fields"] = {k:asdict(v) for k,v in recognizer.recognize_menu(frame).items()}
                finally: recognizer.close()
        finally:
            frame.close()
            getattr(adapter, f"close_{args.panel}_menu")({**target, "_scanner_cancel": cancel})
        frame = capture.wait_stable(target, Event())
        try: frame.save(args.output / "returned.png")
        finally: frame.close()
        report.update(status="returned_basic",state=recovery.state)
    except Exception as exc:
        report["error"] = dict(code=getattr(exc,"code","probe_failed"),message=str(exc))
        raise
    finally:
        report.update(trace=recovery.trace,seconds=monotonic()-started)
        recovery.close();capture.close()
        (args.output/"trace.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        print(json.dumps(report,ensure_ascii=False))


if __name__ == "__main__": main()
