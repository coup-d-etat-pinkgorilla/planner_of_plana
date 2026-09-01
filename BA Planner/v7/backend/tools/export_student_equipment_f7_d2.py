"""Freeze visually reviewed independent native menu captures; never update a bank."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'backend/tests/fixtures/student_equipment_f7_d2'
# Human labels checked against both basic and detail screenshots, not reader output.
REVIEWED = (
    ('shizuko', ['T8', 'T8', 'T5'], [60, 60, 45]),
    ('asuna', ['T2', 'T1', 'T1'], [20, 10, 10]),
    ('megu', ['T6', 'T6', 'T6'], [50, 50, 50]),
    ('toki', ['T10', 'T8', 'T10'], [70, 60, 70]),
    ('toki-bunny', ['T4', 'T4', 'T4'], [40, 40, 40]),
    ('tomoe-qipao', ['T4', 'T7', 'T8'], [37, 54, 59]),
    ('mimori', ['T9', 'T10', 'T9'], [65, 70, 65]),
    ('hasumi-swimsuit', ['T3', 'T3', 'T3'], [30, 30, 30]),
)


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    assets = []
    for name, tiers, levels in REVIEWED:
        source = f'debug/scanner_f7_followup/{name}-panel/detail-0.png'
        dest = DEST / f'{name}.png'
        shutil.copy2(ROOT / source, dest)
        assets.append(dict(file=dest.name, source=source, tiers=tiers, levels=levels,
                           size=[1280, 720], sha256=hashlib.sha256(dest.read_bytes()).hexdigest()))
    manifest = dict(version=1, captured='2026-08-31',
        partition='independent_current_menu_validation_no_bank_training',
        limitations=['native1280 only', 'clean originals do not demonstrate naturally weak T10 recovery'],
        assets=assets)
    (DEST / 'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    print(f'{len(assets)} independently reviewed menu frames / {len(assets)*3} slots')


if __name__ == '__main__':
    main()
