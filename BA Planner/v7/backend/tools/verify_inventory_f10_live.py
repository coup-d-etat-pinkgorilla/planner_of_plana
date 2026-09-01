"""Run the production F10 navigation boundary and restore the requested filter at its first page."""
import argparse,json,sys
from dataclasses import asdict
from pathlib import Path
from threading import Event
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from core.inventory_detail_recovery import InventoryDetailRecognizer
from core.inventory_navigation import InventoryNavigation
from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_session import ScannerError
from core.windows_scanner_adapter import WindowsCaptureInputAdapter

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--target',required=True);p.add_argument('--profile',required=True)
    p.add_argument('--scrolls',type=int,default=2);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
    native=WindowsCaptureInputAdapter();frames=[];inputs=[]
    class Capture:
        def wait_stable(self,target,cancel,timeout=2):
            frame=native.wait_stable(target,cancel,timeout);name=f'frame-{len(frames):02d}.png';frame.save(a.output/name);frames.append(name);return frame
        def click(self,target,x,y):inputs.append(dict(kind='click',x=x,y=y,cleanup=target.get('_scanner_cleanup',False)));native.click(target,x,y)
        def scroll(self,target,delta):inputs.append(dict(kind='scroll',delta=delta));native.scroll(target,delta)
        def drag_scroll(self,target,start,end):inputs.append(dict(kind='drag_scroll',start=start,end=end));native.drag_scroll(target,start,end)
    capture=Capture();catalog=RecognitionAssetCatalog();detail=InventoryDetailRecognizer(catalog);nav=InventoryNavigation(capture,catalog,detail)
    cancel=Event();report={'profile':a.profile,'frames':frames,'inputs':inputs,'steps':[]};target=None;current=None
    try:
        target=next((t for t in native() if t['target_id']==a.target and t['status']=='ready'),None)
        if target is None:raise ScannerError('target_not_ready','requested game window is not ready; no input')
        target={**target,'inventory_scan_profile':a.profile}
        current=capture.wait_stable(target,cancel);source=detail.classify(current);report['source']=source
        prepared=nav.prepare(target,cancel,current);report['prepared']=asdict(prepared);report['prepare_trace']=list(nav.trace)
        current.close();current=capture.wait_stable(target,cancel)
        for index in range(a.scrolls):
            moved=nav.advance(target,cancel,current,source);current.close();current=moved.frame
            report['steps'].append(dict(index=index+1,overlap_rows=moved.overlap_rows,
                slot_indices=list(moved.slot_indices),terminal=moved.terminal,
                terminal_after_page=moved.terminal_after_page,reason=moved.reason,trace=list(nav.trace)))
            if moved.terminal or moved.terminal_after_page:break
    except Exception as exc:
        report['error']=dict(code=getattr(exc,'code','probe_failed'),message=str(exc))
    finally:
        # Reapplying the same verified filter also resets the list to its first page.
        if target is not None:
            try:
                if current is None:current=capture.wait_stable(target,Event())
                restored=nav.prepare(target,Event(),current);report['restored']=asdict(restored);report['restore_trace']=list(nav.trace)
            except Exception as exc:report['restore_error']=dict(code=getattr(exc,'code','restore_failed'),message=str(exc))
        if current is not None:current.close()
        report['frames']=frames;report['inputs']=inputs
        (a.output/'trace.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(json.dumps(report))
        nav.close();detail.close();native.close()
    if 'error' in report or 'restore_error' in report:raise SystemExit(2)

if __name__=='__main__':main()
