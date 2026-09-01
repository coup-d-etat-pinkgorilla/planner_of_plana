"""Read-only F6 verification; optional missing-basic injection, never growth or profile writes."""
import argparse
from dataclasses import asdict
import json
from pathlib import Path
import sys
from threading import Event
from time import monotonic

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import (StudentMatcherAdapter,SkillMenuCaptureAdapter,StarMenuCaptureAdapter,
    LevelMenuCaptureAdapter,StatMenuCaptureAdapter,EquipmentMenuCaptureAdapter,WeaponMenuCaptureAdapter)
from core.student_panel_recovery import StudentPanelRecovery
from core.student_skill_recognizer import StudentSkillRecognizer,SKILL_REGIONS
from core.student_scan_recognizer import Observation
from core.windows_scanner_adapter import WindowsCaptureInputAdapter


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("mode",choices=("panel","single"))
    p.add_argument("--target",required=True)
    p.add_argument("--output",type=Path,required=True)
    p.add_argument("--missing-basic-skills",action="store_true")
    p.add_argument("--cancel-after-open",action="store_true")
    args = p.parse_args()
    if args.cancel_after_open and args.mode != "panel": p.error("cancel probe requires panel mode")
    args.output.mkdir(parents=True,exist_ok=True)
    capture = WindowsCaptureInputAdapter()
    catalog = RecognitionAssetCatalog()
    recovery = StudentPanelRecovery(capture,catalog)
    reader = StudentSkillRecognizer(catalog)
    menu = SkillMenuCaptureAdapter(capture,catalog,recovery=recovery,recognizer=reader)
    checks,skill_trace = [],[]
    read_check = reader.read_check
    def record_check(frame):
        frame.save(args.output/f"check-{len(checks)}.png")
        result = read_check(frame)
        checks.append(asdict(result))
        return result
    reader.read_check = record_check
    close_menu = menu.close_skill_menu
    def record_close(target):
        try: close_menu(target)
        finally: skill_trace[:] = list(recovery.trace)
    menu.close_skill_menu = record_close
    matcher = None
    rows = []
    report = dict(mode=args.mode,diagnostic_missing_basic=args.missing_basic_skills,status="failed")
    started = monotonic()
    try:
        targets = [t for t in capture() if t["target_id"]==args.target and t["status"]=="ready"]
        if len(targets)!=1: raise RuntimeError("Selected game unavailable")
        target = targets[0]
        with capture.wait_stable(target,Event()) as frame:
            frame.save(args.output/"basic.png")
            report["size"] = list(frame.size)
        if args.mode == "panel":
            cancel = Event()
            frame = None
            try:
                frame = menu.capture_skill_menu(target,cancel)
                frame.save(args.output/"opened.png")
                if args.cancel_after_open:
                    cancel.set()
                    try:
                        recovery.recapture(target,cancel,"skill").close()
                        raise AssertionError("cancel did not block recapture")
                    except Exception as exc:
                        if getattr(exc,"code",None)!="cancelled": raise
                        report["cancel_recapture"] = "cancelled_before_capture"
                else:
                    report["fields"] = {k:asdict(v) for k,v in reader.recognize_menu(frame).items()}
            finally:
                if frame is not None: frame.close()
                menu.close_skill_menu(target)
        else:
            matcher = StudentMatcherAdapter(capture,catalog,skill_menu=menu,
                star_menu=StarMenuCaptureAdapter(capture,catalog,recovery=recovery),
                level_menu=LevelMenuCaptureAdapter(capture,catalog,recovery=recovery),
                stat_menu=StatMenuCaptureAdapter(capture,catalog,recovery=recovery),
                equipment_menu=EquipmentMenuCaptureAdapter(capture,catalog,recovery=recovery),
                weapon_menu=WeaponMenuCaptureAdapter(capture,catalog,recovery=recovery))
            if args.missing_basic_skills:
                original = matcher.basic_recognizer.recognize
                def missing(crops):
                    result = original(crops)
                    for field in SKILL_REGIONS:
                        result[field] = Observation(None,0,"uncertain","diagnostic_injected_missing","F6 basic skill diagnostic")
                    return result
                matcher.basic_recognizer.recognize = missing
            rows = matcher._scan_current(target,Event(),lambda *a:None)
            report["candidates"] = [{k:v for k,v in row.items() if k!="_answer_specimen"} for row in rows]
        with capture.wait_stable(target,Event()) as frame:
            frame.save(args.output/"returned.png")
            report["returned_state"] = recovery.recognizer.classify(frame)
        report["status"] = "returned_basic" if report["returned_state"]=="basic" else "return_unconfirmed"
    except Exception as exc:
        report["error"] = dict(code=getattr(exc,"code","probe_failed"),message=str(exc))
        raise
    finally:
        report.update(seconds=monotonic()-started,checks=checks,skill_trace=skill_trace or recovery.trace)
        (args.output/"trace.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        print(json.dumps({k:v for k,v in report.items() if k not in {"candidates","skill_trace"}},ensure_ascii=False))
        if matcher:
            matcher._close_answer_specimens(rows)
            for r in (matcher.star_recognizer,matcher.level_recognizer,matcher.potential_recognizer,matcher.weapon_recognizer): r.close()
        reader.close();recovery.close();capture.close()


if __name__ == "__main__": main()
