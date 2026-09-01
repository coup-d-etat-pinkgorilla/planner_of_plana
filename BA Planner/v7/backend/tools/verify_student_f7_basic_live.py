"""F7 single-student production basic recognition, with all game input disabled."""
import argparse
from dataclasses import asdict
import json
from pathlib import Path
import sys
from threading import Event

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import StudentMatcherAdapter
from core.scanner_session import ScannerError
from core.student_panel_recovery import StudentPanelRecognizer
from core.student_scan_recognizer import ratio_crop
from core.student_equipment_recovery import favorite_dot_state
from core.windows_scanner_adapter import WindowsCaptureInputAdapter


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--target',required=True);p.add_argument('--output',type=Path,required=True)
    args=p.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    native=WindowsCaptureInputAdapter();catalog=RecognitionAssetCatalog();panel=StudentPanelRecognizer(catalog)
    report={'inputs':0};rows=[]
    class ReadOnlyCapture:
        def wait_stable(self,target,cancel,timeout=2):
            frame=native.wait_stable(target,cancel,timeout)
            if panel.classify(frame)!='basic':
                frame.close();raise ScannerError('panel_wrong_start','verified basic required')
            frame.save(args.output/'basic.png')
            with ratio_crop(frame,matcher.equipment_controls.regions['equipment_button']) as crop:
                report['growth']=asdict(matcher.equipment_controls.read_growth(crop))
            with ratio_crop(frame,catalog.region('student')['basic_favorite_empty_dot_region']) as crop:
                report['favorite_dot']=favorite_dot_state(crop,matcher.equipment_recognizer.empty_dot)
            return frame
    matcher=StudentMatcherAdapter(ReadOnlyCapture(),catalog)
    try:
        target=next(t for t in native() if t['target_id']==args.target and t['status']=='ready')
        rows=matcher._scan_current(target,Event(),lambda *args:None)
        report['candidates']=[{k:v for k,v in row.items() if k!='_answer_specimen'} for row in rows]
        (args.output/'trace.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(report,ensure_ascii=False))
    finally:
        matcher._close_answer_specimens(rows)
        for reader in (matcher.equipment_controls,matcher.equipment_recognizer,matcher.skill_recognizer,
                       matcher.star_recognizer,matcher.level_recognizer,matcher.potential_recognizer,matcher.weapon_recognizer):
            reader.close()
        panel.close();native.close()


if __name__=='__main__':main()
