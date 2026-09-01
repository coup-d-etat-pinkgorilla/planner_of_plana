"""Freeze reviewed native F9 development frames; no runtime learning."""
import hashlib,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DEST=ROOT/'backend/tests/fixtures/inventory_detail_f9_live'

def main():
    DEST.mkdir(parents=True,exist_ok=True);assets=[]
    for name,source,original,identity,count,selected in [
        ('item','item','item-initial/frame.png','Item_Icon_SkillBook_Hyakkiyako_0','2344',0),
        ('equipment','equipment','equipment-initial/frame.png','Equipment_Icon_Exp_3','116',0),
        ('item-selected1','item','item-slot1/frame-02.png','Item_Icon_SkillBook_Hyakkiyako_1','843',1),
        ('equipment-necklace10','equipment','equipment-slot13/frame-04.png','Equipment_Icon_Necklace_Tier10','306',13),
        ('equipment-weak-count','equipment','equipment-slot1-retry/frame-04.png','Equipment_Icon_Exp_2',None,1),
        ('equipment-unknown-id','equipment','equipment-slot4/frame-03.png',None,'1934',4),
        ('equipment-faded-selection','equipment','equipment-slot1/frame-00.png','Equipment_Icon_Exp_3','116',None),
    ]:
        path=DEST/(name+'.png');original='debug/scanner_f9_live/'+original
        shutil.copy2(ROOT/original,path)
        assets.append(dict(file=path.name,source=original,source_kind=source,identity=identity,count=count,selected_slot=selected,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    (DEST/'manifest.json').write_text(json.dumps(dict(version=1,actual_client_size=[1280,720],partition='development_calibration_not_holdout',assets=assets),indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':main()
