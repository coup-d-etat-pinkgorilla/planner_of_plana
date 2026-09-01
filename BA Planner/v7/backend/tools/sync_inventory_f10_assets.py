"""Export v6 inventory navigation coordinates/references as versioned v7 assets."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT=Path(__file__).resolve().parents[2];V6=ROOT.parent/'v6';DEST=ROOT/'backend/assets/recognition/v1'
CAP=V6/'debug/region_captures';OUT=DEST/'templates/inventory_f10';OUT.mkdir(parents=True,exist_ok=True)
controls=['filtermenu_button','eq_filtermenu_button','filter_tab','sort_tab','filter_reset_button',
          'filter_confirm_button','eq_filter_confirm_button','eleph_filter','note_filter','bd_filter',
          'ooparts_filter','reports_filter']
regions={'filter_title':{'x1':1030/2560,'y1':145/1440,'x2':1530/2560,'y2':285/1440},'controls':{}}
for name in controls:
    raw=json.loads((CAP/f'{name}.region.json').read_text(encoding='utf-8-sig'))
    p=raw['points_ratio'];regions['controls'][name]={
        'x1':min(v['x'] for v in p),'y1':min(v['y'] for v in p),
        'x2':max(v['x'] for v in p),'y2':max(v['y'] for v in p)}
regions['controls']['presents_filter']={
    'x1':regions['controls']['ooparts_filter']['x1'],'x2':regions['controls']['ooparts_filter']['x2'],
    'y1':regions['controls']['note_filter']['y1'],'y2':regions['controls']['note_filter']['y2']}
assets=[]
def record(path,purpose,identity,source):
    raw=path.read_bytes();assets.append(dict(path=path.relative_to(DEST).as_posix(),scan_kind='inventory',
        purpose=purpose,required=True,bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),
        identity_value=identity,source_path=source))
for name in ['sort_rule_check','sort_name_rule_check','eq_sort_rule_check']:
    meta=json.loads((CAP/f'{name}.region.json').read_text(encoding='utf-8-sig'));p=meta['points_ratio']
    regions[name]={'x1':min(v['x'] for v in p),'y1':min(v['y'] for v in p),'x2':max(v['x'] for v in p),'y2':max(v['y'] for v in p)}
    src=CAP/f'{name}_001.png';dst=OUT/src.name;shutil.copy2(src,dst)
    record(dst,'inventory-navigation-template',name,'../v6/'+src.relative_to(V6).as_posix())
title=V6/'templates/menu_detect_flag/inventory_filter_title_display_settings.png';dst=OUT/'filter_title.png';shutil.copy2(title,dst)
record(dst,'inventory-navigation-template','filter_title','../v6/'+title.relative_to(V6).as_posix())
region_path=DEST/'regions/inventory_navigation_f10_regions.json';region_path.write_text(json.dumps(regions,indent=2)+'\n',encoding='utf-8')
record(region_path,'inventory-navigation-regions','regions',','.join('../v6/debug/region_captures/'+n+'.region.json' for n in controls))
(DEST/'inventory_navigation_f10_manifest.json').write_text(json.dumps(dict(version=1,
    source_version='inventory-f10-2026-09-01',assets=assets),indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(asset_count=len(assets),region_count=len(regions['controls']))))
