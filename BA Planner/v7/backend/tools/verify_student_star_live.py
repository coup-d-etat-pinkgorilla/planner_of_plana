"""One current-student F5 scan. Diagnostics discard observations, never alter game data."""
import argparse
import json
from pathlib import Path
import sys
from threading import Event
from time import monotonic

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import (StudentMatcherAdapter, StarMenuCaptureAdapter, LevelMenuCaptureAdapter,
    StatMenuCaptureAdapter, EquipmentMenuCaptureAdapter, WeaponMenuCaptureAdapter)
from core.student_panel_recovery import StudentPanelRecovery
from core.student_scan_recognizer import Observation
from core.windows_scanner_adapter import WindowsCaptureInputAdapter


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--diagnostic", choices=("none", "missing-basic", "missing-both"), default="none")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    capture = WindowsCaptureInputAdapter()
    catalog = RecognitionAssetCatalog()
    recovery = StudentPanelRecovery(capture, catalog)
    star_menu = StarMenuCaptureAdapter(capture, catalog, recovery=recovery)
    star_trace = []
    close_star = star_menu.close_star_menu
    def record_return(target):
        try: close_star(target)
        finally: star_trace[:] = list(recovery.trace)
    star_menu.close_star_menu = record_return
    matcher = StudentMatcherAdapter(capture, catalog, star_menu=star_menu,
        level_menu=LevelMenuCaptureAdapter(capture,catalog,recovery=recovery),
        stat_menu=StatMenuCaptureAdapter(capture,catalog,recovery=recovery),
        equipment_menu=EquipmentMenuCaptureAdapter(capture,catalog,recovery=recovery),
        weapon_menu=WeaponMenuCaptureAdapter(capture,catalog,recovery=recovery))
    if args.diagnostic != "none":
        recognize = matcher.basic_recognizer.recognize
        def missing_star(crops):
            result = recognize(crops)
            result["student_star"] = Observation(None,0,"uncertain","diagnostic_injected_missing","F5 basic-star diagnostic")
            return result
        matcher.basic_recognizer.recognize = missing_star
    if args.diagnostic == "missing-both":
        matcher.weapon_recognizer.read_state = lambda *a,**kw: Observation(
            None,0,"uncertain","diagnostic_injected_missing","F5 independent weapon diagnostic")
    rows = []
    started = monotonic()
    try:
        targets = [t for t in capture() if t["target_id"] == args.target and t["status"] == "ready"]
        if len(targets) != 1: raise RuntimeError("Selected game unavailable")
        target = targets[0]
        with capture.wait_stable(target,Event()) as frame:
            frame.save(args.output/"basic.png")
        rows = matcher._scan_current(target,Event(),lambda *a:None)
        with capture.wait_stable(target,Event()) as frame:
            frame.save(args.output/"returned.png")
            state = recovery.recognizer.classify(frame)
        report = dict(diagnostic=args.diagnostic,seconds=monotonic()-started,returned_state=state,
            star_trace=star_trace,candidates=[{k:v for k,v in row.items() if k!="_answer_specimen"} for row in rows])
        (args.output/"trace.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        print(json.dumps(dict(seconds=report["seconds"],returned_state=state,
            star=[row["payload"]["values"].get("student_star") for row in rows],
            provenance=[row["payload"]["provenance"].get("student_star") for row in rows],
            star_inputs=[r for r in star_trace if "input" in r]),ensure_ascii=False))
    finally:
        matcher._close_answer_specimens(rows)
        for reader in (matcher.star_recognizer,matcher.level_recognizer,matcher.potential_recognizer,matcher.weapon_recognizer):
            reader.close()
        recovery.close()
        capture.close()


if __name__ == "__main__": main()
