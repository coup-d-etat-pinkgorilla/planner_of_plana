"""Freeze reviewed native F10 navigation frames; no runtime learning."""
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'backend/tests/fixtures/inventory_navigation_f10_live'


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    sources = {
        'item-page0.png': 'debug/scanner_f10_live/item-tech-notes-terminal-final/frame-04.png',
        'item-page1.png': 'debug/scanner_f10_live/item-tech-notes-terminal-final/frame-07.png',
        'item-pre-tail.png': 'debug/scanner_f10_live/item-tech-notes-terminal-final/frame-16.png',
        'item-tail.png': 'debug/scanner_f10_live/item-tech-notes-terminal-final/frame-19.png',
        'equipment-page0.png': 'debug/scanner_f10_live/equipment-three-pages-final/frame-04.png',
        'equipment-page1.png': 'debug/scanner_f10_live/equipment-three-pages-final/frame-07.png',
        'equipment-page2.png': 'debug/scanner_f10_live/equipment-three-pages-final/frame-10.png',
        'equipment-variable-drag.png': 'debug/scanner_f10_live/equipment-three-pages-final/frame-13.png',
    }
    assets = []
    for name, source in sources.items():
        target = DEST / name
        shutil.copy2(ROOT / source, target)
        assets.append({'file': name, 'source': source,
                       'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
    pairs = [
        {'source_kind': 'item', 'before': 'item-page0.png', 'after': 'item-page1.png',
         'overlap_rows': 3, 'decision': 'verified_row_overlap'},
        {'source_kind': 'item', 'before': 'item-pre-tail.png', 'after': 'item-tail.png',
         'overlap_rows': 3, 'decision': 'verified_tail_residual'},
        {'source_kind': 'equipment', 'before': 'equipment-page0.png', 'after': 'equipment-page1.png',
         'overlap_rows': 4, 'decision': 'verified_row_overlap'},
        {'source_kind': 'equipment', 'before': 'equipment-page1.png', 'after': 'equipment-page2.png',
         'overlap_rows': 4, 'decision': 'verified_row_overlap'},
        {'source_kind': 'equipment', 'before': 'equipment-page2.png', 'after': 'equipment-variable-drag.png',
         'overlap_rows': 4, 'decision': 'reject_ambiguous_overlap'},
    ]
    manifest = {'version': 1, 'actual_client_size': [1280, 720],
                'partition': 'development_calibration_not_holdout', 'assets': assets, 'pairs': pairs}
    (DEST / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(f'{len(assets)} native1280 F10 development fixtures')


if __name__ == '__main__':
    main()
