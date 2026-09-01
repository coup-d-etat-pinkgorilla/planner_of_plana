"""Copy F8 fixed attribute/state templates and navigation ROIs, without v6 runtime code."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
V6 = ROOT.parent/'v6'
DEST = ROOT/'backend/assets/recognition/v1'


def main():
    assets = []
    def record(path, purpose, source, identity=None):
        raw = path.read_bytes()
        assets.append(dict(path=path.relative_to(DEST).as_posix(), scan_kind='student', purpose=purpose,
            required=True, bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest(), source_path=source,
            identity_value=identity))
    normal = json.loads((V6/'regions/student_normal_info_regions.json').read_text(encoding='utf-8-sig'))
    lobby = json.loads((V6/'regions/lobby_regions.json').read_text(encoding='utf-8-sig'))['lobby']
    menu = json.loads((V6/'regions/student_menu_regions.json').read_text(encoding='utf-8-sig'))['student_menu']
    regions = {k: v for k, v in normal.items() if k.startswith(('basic_attribute_', 'style_form_'))}
    regions.update(lobby_flag=lobby['detect_flag'], student_list_flag=menu['menu_detect_flag'],
                   student_list_button=lobby['student_menu_button'], first_student_button=menu['first_student_button'])
    # Current native1280 lobby places the fixed Lv glyph three pixels higher.
    # Keep legacy geometry for other sizes; this is a fixed ROI, not a wider search.
    regions['lobby_flag_native_1280'] = {**regions['lobby_flag'],
        'y1': regions['lobby_flag']['y1']-3/720, 'y2': regions['lobby_flag']['y2']-3/720}
    path = DEST/'regions/student_identity_regions.json'
    path.write_text(json.dumps(regions, indent=2)+'\n', encoding='utf-8')
    record(path, 'student-identity-regions', '../v6/regions/student_normal_info_regions.json+lobby_regions.json+student_menu_regions.json')
    for source in sorted((V6/'templates/student_basic_attributes').glob('*/*.png')):
        path = DEST/'templates/student_identity/attributes'/source.parent.name/source.name
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, path)
        record(path, 'student-attribute-template', '../v6/'+source.relative_to(V6).as_posix(), source.parent.name+':'+source.stem)
    for state, name in [('lobby', 'lobby_template.png'), ('student_list', 'student_menu__menu_detect_flag.png')]:
        source = V6/'templates/menu_detect_flag'/name
        path = DEST/'templates/student_identity'/name
        shutil.copy2(source, path)
        record(path, 'student-entry-template', '../v6/'+source.relative_to(V6).as_posix(), state)
    (DEST/'student_identity_manifest.json').write_text(json.dumps(dict(version=1,
        source_version='student-identity-f8-2026-08-31', assets=assets), indent=2)+'\n', encoding='utf-8')
    print(f'F8 assets: {len(assets)}')


if __name__ == '__main__': main()
