"""Pin visually checked F6 frames as development regression only."""
import hashlib,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DEST=ROOT/'backend/tests/fixtures/student_skill_f6_live'
def main():
    DEST.mkdir(parents=True,exist_ok=True)
    rows=[]
    for name,source,check,values,state in [
        ('mika-on','mika-off-on/check-1.png',True,[5,10,10,10],'skill'),
        ('mika-off','mika-off-on/check-0.png',False,None,'skill'),
        ('mika-basic','mika-panel/returned.png',None,None,'basic'),
        ('miyu-on','miyu-panel/opened.png',True,[1,1,1,1],'skill'),
        ('miyu-basic','miyu-panel/returned.png',None,None,'basic')]:
        source='debug/scanner_f6_live/'+source;path=DEST/(name+'.png');shutil.copy2(ROOT/source,path)
        rows.append(dict(file=path.name,source=source,check=check,values=values,state=state,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    (DEST/'manifest.json').write_text(json.dumps(dict(version=1,actual_client_size=[1280,720],partition='development_regression_not_holdout_or_runtime_learning',assets=rows),indent=2)+'\n',encoding='utf-8')
if __name__=='__main__':main()
