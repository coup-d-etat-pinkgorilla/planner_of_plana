"""Freeze reviewed native F8 frames; development regression, not runtime learning."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT/'backend/tests/fixtures/student_identity_f8_live'


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    rows = []
    for name, source, state, identity, combat in [
        ('lobby-calibration', 'lobby-entry-stable/frame-00.png', 'lobby', None, None),
        ('lobby-verification', 'lobby-entry-bounded/frame-00.png', 'lobby', None, None),
        ('lobby-hidden', 'lobby-entry-corrected/frame-00.png', 'unknown', None, None),
        ('student-list', 'list-entry/frame-00.png', 'student_list', None, None),
        ('mika', 'mika-retry/frame-01.png', 'basic', 'mika', None),
        ('hoshino-form1', 'hoshino-forms/frame-00.png', 'basic', 'hoshino_battle', [106747,3383,2771,4538]),
        ('hoshino-form2', 'hoshino-original2-tie/frame-00.png', 'basic', 'hoshino_battle#2', [48823,8633,1949,5674]),
    ]:
        source = 'debug/scanner_f8_live/'+source
        path = DEST/(name+'.png')
        shutil.copy2(ROOT/source, path)
        rows.append(dict(file=path.name, source=source, state=state, identity=identity, combat=combat,
                         sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    (DEST/'manifest.json').write_text(json.dumps(dict(version=1, actual_client_size=[1280,720],
        partition='development_regression_not_holdout_or_runtime_learning', assets=rows), indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__': main()
