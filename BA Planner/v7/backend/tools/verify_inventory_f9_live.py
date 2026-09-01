"""Read-only F9 capture/probe; no repository or consumable actions."""
import argparse
from dataclasses import asdict
import json
import sys
from pathlib import Path
from threading import Event
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from core.windows_scanner_adapter import WindowsCaptureInputAdapter
from core.recognition_assets import RecognitionAssetCatalog
from core.inventory_detail_recovery import InventoryDetailRecognizer,InventoryDetailRecovery
from core.scanner_session import ScannerError

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target',required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--slot',type=int)
    parser.add_argument('--cancel-after-read',action='store_true')
    args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    native=WindowsCaptureInputAdapter();reader=InventoryDetailRecognizer(RecognitionAssetCatalog());frames=[];inputs=[];report={}
    class Capture:
        def wait_stable(self,target,cancel,timeout=2):
            frame=native.wait_stable(target,cancel,timeout);name=f'frame-{len(frames):02d}.png';frame.save(args.output/name);frames.append(name);return frame
        def click(self,target,x,y):
            inputs.append(dict(x=x,y=y,cleanup=target.get('_scanner_cleanup',False)));native.click(target,x,y)
    capture=Capture();recovery=InventoryDetailRecovery(capture,reader);cancel=Event()
    if args.cancel_after_read:
        read=reader.read
        def cancelling(*a):result=read(*a);cancel.set();return result
        reader.read=cancelling
    try:
        target=next((t for t in native() if t['target_id']==args.target and t['status']=='ready'),None)
        if target is None:raise ScannerError('target_not_ready','requested game window is not ready; no input')
        with capture.wait_stable(target,cancel) as frame:
            frame.save(args.output/'frame.png');source=reader.classify(frame)
            report.update(size=frame.size,source=source,original_selected=reader.selected(frame,source) if source else None)
            if args.slot is not None:
                result=recovery.resolve(target,cancel,frame,args.slot,None,None,False)
            else:result=reader.read(frame,source) if source else None
            report['result']=asdict(result) if result else None
    except Exception as exc:
        report['error']=dict(code=getattr(exc,'code','probe_failed'),message=str(exc))
        if getattr(exc,'code',None)!='cancelled':raise
    finally:
        report.update(frames=frames,inputs=inputs,trace=recovery.trace)
        (args.output/'trace.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(json.dumps(report))
        reader.close();native.close()

if __name__=='__main__':main()
