"""F7 read-only panel probe; diagnostic failure injection is explicitly labelled."""
import argparse
from dataclasses import asdict
import json
from pathlib import Path
import sys
from threading import Event
from time import monotonic

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import EquipmentMenuCaptureAdapter
from core.student_equipment_recognizer import EquipmentMenuRecognizer, StudentEquipmentRecognizer
from core.student_equipment_recovery import EquipmentControlRecognizer, resolve_equipment_menu, favorite_dot_state
from core.student_panel_recovery import StudentPanelRecovery
from core.student_scan_recognizer import Observation, ratio_crop
from core.windows_scanner_adapter import WindowsCaptureInputAdapter


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--target', required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--first-read-missing', action='store_true')
    p.add_argument('--cancel-after-open', action='store_true')
    p.add_argument('--diagnostic-tier-noise', action='store_true',
                   help='Corrupt only captured tier pixels in memory; never change game data')
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    capture = WindowsCaptureInputAdapter()
    catalog = RecognitionAssetCatalog()
    recovery = StudentPanelRecovery(capture, catalog)
    controls = EquipmentControlRecognizer(catalog)
    menu = EquipmentMenuCaptureAdapter(capture, catalog, recovery=recovery, controls=controls)
    reader = EquipmentMenuRecognizer(catalog)
    checks, reads = [], []
    report = dict(status='failed', diagnostic_first_read_missing=args.first_read_missing,
                  diagnostic_tier_noise=args.diagnostic_tier_noise)
    started = monotonic()
    original_check = controls.read_check
    def check(frame):
        frame.save(args.output/f'check-{len(checks)}.png')
        result = original_check(frame)
        checks.append(asdict(result))
        return result
    controls.read_check = check
    original_read = reader.recognize
    def read(frame, slots):
        frame.save(args.output/f'detail-{len(reads)}.png')
        if args.diagnostic_tier_noise:
            from tools.benchmark_student_equipment_f7_d2 import noisy_tier
            changed = frame.copy()
            try:
                for slot in slots:
                    if slot <= 3:
                        next_frame = noisy_tier(changed, reader, slot, 120, 710+slot)
                        changed.close()
                        changed = next_frame
                changed.save(args.output/f'diagnostic-detail-{len(reads)}.png')
                result = original_read(changed, slots)
            finally:
                changed.close()
        else:
            result = original_read(frame, slots)
        if args.first_read_missing and not reads:
            result = {key: Observation(None, 0, 'uncertain', 'diagnostic_injected_missing', 'F7 first read only') for key in result}
        reads.append({k: asdict(v) for k,v in result.items()})
        return result
    reader.recognize = read
    try:
        targets = [t for t in capture() if t['target_id']==args.target and t['status']=='ready']
        if len(targets)!=1: raise RuntimeError('Selected game unavailable')
        target = targets[0]
        with capture.wait_stable(target, Event()) as frame:
            frame.save(args.output/'basic.png')
            report['size'] = list(frame.size)
            with ratio_crop(frame, controls.regions['equipment_button']) as crop:
                report['growth'] = asdict(controls.read_growth(crop))
            with ratio_crop(frame, catalog.region('student')['basic_favorite_empty_dot_region']) as crop:
                report['favorite_dot'] = favorite_dot_state(crop, StudentEquipmentRecognizer.empty_dot)
        cancel = Event()
        if args.cancel_after_open:
            try:
                with menu.capture_equipment_menu(target, cancel):
                    cancel.set()
                    try: menu.recapture_equipment_menu(target, cancel).close()
                    except Exception as exc:
                        if getattr(exc, 'code', None) != 'cancelled': raise
                        report['cancel_recapture'] = 'cancelled_before_capture'
                    else: raise AssertionError('cancel did not block recapture')
            finally: menu.close_equipment_menu(target)
        else:
            report['fields'] = {k: asdict(v) for k,v in resolve_equipment_menu(menu, reader, target,
                cancel, {}, (1,2,3)).items()}
        with capture.wait_stable(target, Event()) as frame:
            frame.save(args.output/'returned.png')
            report['returned_state'] = recovery.recognizer.classify(frame)
        report['status'] = 'returned_basic' if report['returned_state']=='basic' else 'return_unconfirmed'
    except Exception as exc:
        report['error'] = dict(code=getattr(exc, 'code', 'probe_failed'), message=str(exc))
        raise
    finally:
        report.update(seconds=monotonic()-started, checks=checks, reads=reads, trace=recovery.trace)
        (args.output/'trace.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        print(json.dumps({k:v for k,v in report.items() if k not in {'reads', 'trace'}}, ensure_ascii=False))
        controls.close(); recovery.close(); capture.close()


if __name__ == '__main__': main()
