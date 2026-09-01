"""Freeze visually reviewed native F7 captures for development regression only."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT/'backend/tests/fixtures/student_equipment_f7_live'


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    rows = []
    for name, source, state, checked in (
        ('mika-off', 'mika-off-on/check-0.png', 'equipment', False),
        ('mika-on', 'mika-off-on/check-2.png', 'equipment', True),
        ('mika-basic', 'mika-off-on/basic.png', 'basic', None),
        ('mika-return', 'mika-cancel/returned.png', 'basic', None),
    ):
        path = DEST/(name+'.png')
        shutil.copy2(ROOT/'debug/scanner_f7_live'/source, path)
        rows.append(dict(file=path.name, source='debug/scanner_f7_live/'+source, state=state,
            check=checked, sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    (DEST/'manifest.json').write_text(json.dumps(dict(version=1,
        partition='development_regression_not_D2_validation_or_runtime_learning',
        expected={'tiers':['T10','T10','T10'], 'levels':[70,70,70], 'growth_active':True},
        assets=rows), indent=2)+'\n', encoding='utf-8')
    print(f'{len(rows)} native1280 development fixtures')


if __name__=='__main__': main()
