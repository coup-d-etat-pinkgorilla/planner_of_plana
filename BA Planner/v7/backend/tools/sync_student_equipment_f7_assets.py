"""Copy only fixed v6 check/button templates; no runtime v6 dependency."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
V6 = ROOT.parent / 'v6'
DEST = ROOT / 'backend/assets/recognition/v1'


def main():
    assets = []
    for label in ('true', 'false', 'possible', 'impossible'):
        source = f'templates/equipcheck/{label}.png'
        path = DEST / f'templates/student_equipment/f7/{label}.png'
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(V6/source, path)
        data = path.read_bytes()
        assets.append(dict(path=path.relative_to(DEST).as_posix(), scan_kind='student',
            purpose='student-equipment-control-template', required=True, bytes=len(data),
            sha256=hashlib.sha256(data).hexdigest(), source_path='../v6/'+source, equipment_state=label))
    (DEST/'student_equipment_f7_manifest.json').write_text(json.dumps(dict(version=1,
        source_version='student-equipment-f7-v6-2026-08-31', assets=assets), indent=2)+'\n', encoding='utf-8')
    print(f'F7: {len(assets)} fixed control assets')


if __name__ == '__main__': main()
