"""Read-only F8 production identity/entry/form probe; no profile or growth operations."""
import argparse
from dataclasses import asdict
import json
from pathlib import Path
import sys
from threading import Event
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import StudentMatcherAdapter, Match
from core.scanner_session import ScanBatchResult
from core.student_panel_recovery import StudentPanelRecovery
from core.student_identity_recovery import StudentEntryRecovery
from core.student_form_recovery import StudentFormRecovery
from core.windows_scanner_adapter import WindowsCaptureInputAdapter


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--target',required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--forms',action='store_true')
    p.add_argument('--first-identity-missing',action='store_true')
    p.add_argument('--form-template-tie',action='store_true')
    p.add_argument('--cancel-after-form-read',action='store_true')
    args=p.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    native=WindowsCaptureInputAdapter();catalog=RecognitionAssetCatalog();frames=[];inputs=[]
    class Capture:
        def wait_stable(self,target,cancel,timeout=2):
            frame=native.wait_stable(target,cancel,timeout)
            filename=f'frame-{len(frames):02d}.png';frame.save(args.output/filename);frames.append(filename)
            return frame
        def click(self,target,x,y):
            inputs.append(dict(x=x,y=y,cleanup=target.get('_scanner_cleanup',False)))
            native.click(target,x,y)
    capture=Capture();panels=StudentPanelRecovery(capture,catalog)
    entry=StudentEntryRecovery(capture,catalog,panels)
    forms=StudentFormRecovery(capture,entry.regions)
    matcher=StudentMatcherAdapter(capture,catalog,entry_recovery=entry,form_recovery=forms if args.forms else None)
    cancel=Event();rows=[];report=dict(diagnostic=dict(first_missing=args.first_identity_missing,
        form_template_tie=args.form_template_tie,cancel_after_form_read=args.cancel_after_form_read))
    if args.first_identity_missing:
        original=matcher.identity_recognizer.identify;attempts=[0]
        def identify(*a,**kw):
            attempts[0]+=1
            return None if attempts[0]==1 else original(*a,**kw)
        matcher.identity_recognizer.identify=identify
    if args.form_template_tie:
        original_match=matcher.matcher.match
        def tied(*a,**kw):
            result=original_match(*a,**kw)
            return Match(result.identity,result.score,0,result.source)
        matcher.matcher.match=tied
    if args.cancel_after_form_read:
        original_collect=forms.collect
        def collect(target,token,ref,observe,read):
            def finish(frame,identity):read(frame,identity);token.set()
            return original_collect(target,token,ref,observe,finish)
        forms.collect=collect
    try:
        target=next(t for t in native() if t['target_id']==args.target and t['status']=='ready')
        if args.forms:
            result=matcher(target,cancel,lambda *_a:None)
            rows=result.candidates if isinstance(result,ScanBatchResult) else result
            report.update(outcome=result.outcome if isinstance(result,ScanBatchResult) else 'completed',
                candidates=[{k:v for k,v in row.items() if k!='_answer_specimen'} for row in rows])
            if isinstance(result,ScanBatchResult) and result.error:report['error']=dict(code=result.error.code,message=str(result.error))
        else:
            frame,identity=matcher._capture_identified(target,cancel)
            try:report['identity']=asdict(identity);report['attributes']=matcher.identity_recognizer.attributes(frame)
            finally:frame.close()
        frame,identity=matcher._capture_identified({**target,'_first_student':False},Event())
        frame.close();report['returned_identity']=asdict(identity)
    except Exception as exc:
        report['error']=dict(code=getattr(exc,'code','probe_failed'),message=str(exc))
        raise
    finally:
        report.update(frames=frames,inputs=inputs,entry_trace=entry.trace,form_trace=forms.trace)
        (args.output/'trace.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(json.dumps({k:v for k,v in report.items() if k not in {'candidates','frames'}},ensure_ascii=False))
        matcher._close_answer_specimens(rows)
        for reader in (matcher.identity_recognizer,matcher.equipment_controls,matcher.equipment_recognizer,
            matcher.skill_recognizer,matcher.star_recognizer,matcher.level_recognizer,matcher.potential_recognizer,
            matcher.weapon_recognizer,entry,panels,native):reader.close()


if __name__=='__main__':main()
