"""Export fixed v6 inventory detail banks/ROIs and reviewed native UI flags."""
import hashlib
import json
import math
from pathlib import Path
import shutil
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
V6=ROOT.parent/'v6'
DEST=ROOT/'backend/assets/recognition/v1'

def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def bounds(payload):
    p=payload['points_ratio']
    return dict(x1=min(v['x'] for v in p),y1=min(v['y'] for v in p),x2=max(v['x'] for v in p),y2=max(v['y'] for v in p))
def quad(payload,dx=0,dy=0):
    w,h=payload['window_rect']['width'],payload['window_rect']['height']
    pts=payload['points_client'];p=[dict(x=(v['x']+dx)/w,y=(v['y']+dy)/h) for v in pts]
    return dict(points_ratio=p,output_size=[round(math.dist(tuple(pts[0].values()),tuple(pts[1].values()))),round(math.dist(tuple(pts[1].values()),tuple(pts[2].values())))])

def main():
    assets=[]
    def record(path,purpose,source,identity=None):
        raw=path.read_bytes();assets.append(dict(path=path.relative_to(DEST).as_posix(),scan_kind='inventory',purpose=purpose,
            required=True,bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),source_path=source,identity_value=identity))
    def copy(source,purpose,identity):
        path=DEST/'templates/inventory_f9'/source.relative_to(V6/'templates');path.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(source,path);record(path,purpose,'../v6/'+source.relative_to(V6).as_posix(),identity)
        return path.relative_to(DEST).as_posix()
    regions=dict(title=dict(x1=.08,y1=0,x2=.18,y2=.06),list_title=dict(x1=.53,y1=.13,x2=.59,y2=.175),sources={},profiles={},counts={})
    for source in ['item','equipment']:
        regions['sources'][source]=read(V6/f'regions/{source}_regions.json')[source]
        sourcepath=ROOT/f'debug/scanner_f9_live/{source}-initial/frame.png'
        with Image.open(sourcepath) as frame:
            for key in ['title','list_title']:
                r=regions[key];box=tuple(round(r[k]*(frame.width if k.startswith('x') else frame.height)) for k in ['x1','y1','x2','y2'])
                path=DEST/f'templates/inventory_f9/{source}_{key}.png';path.parent.mkdir(parents=True,exist_ok=True)
                with frame.crop(box) as crop:crop.save(path)
                record(path,'inventory-page-template',sourcepath.relative_to(ROOT).as_posix(),source+':'+key)
    for directory in sorted((V6/'templates/inventory_detail').iterdir()):
        if not directory.is_dir():continue
        profile=directory.name;source='equipment' if profile=='equipment' else 'item'
        rois=sorted(directory.glob('*.json'))
        if not rois:continue
        name_roi=V6/'templates/inventory_detail_names'/('equip_name_image_region.region.json' if source=='equipment' else 'item_name_image_region.region.json')
        regions['profiles'][profile]=dict(icon=bounds(read(rois[0])),name=bounds(read(name_roi)),source=source)
        for p in sorted(directory.glob('*.png')):copy(p,'inventory-detail-icon',profile+':'+p.stem)
        for p in sorted((V6/'templates/inventory_detail_names'/profile).glob('*.png')):copy(p,'inventory-detail-name',profile+':'+p.stem)
    for source,dirname in [('item','inventory_count'),('equipment','equipment_count')]:
        directory=V6/'templates'/dirname;pack={};groups=read(directory/'layout.json')['digit_groups']
        paths={p.stem:copy(p,'inventory-detail-count',source+':'+p.stem) for p in sorted(directory.glob('*.png'))}
        def cell(name,payload):
            return dict(region=quad(payload),templates={k.rsplit('_',1)[1]:v for k,v in paths.items() if k.startswith(name+'_')})
        for n in range(1,7):
            name=('e_' if source=='equipment' else '')+f'x_digit{n}';p=directory/(name+'.region.json')
            if not p.exists():continue
            row=dict(x=cell(name,read(p)),digits=[])
            group=next((g for g in groups if str(n) in g['starts']),None)
            for i in range(n):
                if group:
                    base=read(directory/(group['base_region']+'.region.json'));start=group['starts'][str(n)]
                    region=quad(base,start['x']+group['step']['x']*i-base['points_screen'][0]['x'],start['y']+group['step']['y']*i-base['points_screen'][0]['y'])
                    item=cell(group['template_region'],base);item['region']=region
                else:
                    name='digit1' if n==1 else f'digit{n}_{i+1}';p=directory/(name+'.region.json')
                    item=cell(name,read(p)) if p.exists() else dict(templates={})
                row['digits'].append(item)
            pack[str(n)]=row
        regions['counts'][source]=pack
    path=DEST/'regions/inventory_detail_f9_regions.json';path.write_text(json.dumps(regions,indent=2)+'\n',encoding='utf-8')
    record(path,'inventory-detail-regions','adapted:v6 inventory detail/count regions + F9 native UI flags')
    (DEST/'inventory_detail_f9_manifest.json').write_text(json.dumps(dict(version=1,source_version='inventory-f9-2026-09-01',assets=assets),indent=2)+'\n',encoding='utf-8')
    print('F9 assets:',len(assets),'total:',2005+len(assets))

if __name__=='__main__':main()
