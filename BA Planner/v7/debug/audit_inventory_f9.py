"""Freeze F9 evidence without modifying earlier phase snapshots."""
from pathlib import Path
import hashlib
import json
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backend'))
from core.recognition_assets import RecognitionAssetCatalog

OUT = ROOT / 'docs/migration/scanner-fallback-restoration'
def read(path):
    return json.loads(path.read_text(encoding='utf-8'))
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def entry(path):
    return dict(path=path, sha256=sha(ROOT / path))
def write(name, value):
    (OUT / name).write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')

paths = [
    'backend/core/inventory_detail_recovery.py',
    'backend/core/scanner_matchers.py', 'backend/core/scanner_runtime.py',
    'backend/core/recognition_assets.py',
    'backend/tests/test_inventory_detail_f9.py',
    'backend/tests/test_recognition_assets.py',
    'backend/tests/test_scanner_stdio_transport.py',
    'backend/tests/fixtures/inventory_detail_f9_v6_parity.json',
    'backend/tests/fixtures/inventory_detail_f9_live/manifest.json',
    'backend/assets/recognition/v1/inventory_detail_f9_manifest.json',
    'backend/assets/recognition/v1/regions/inventory_detail_f9_regions.json',
    'backend/tools/sync_inventory_f9_assets.py',
    'backend/tools/export_inventory_f9_fixtures.py',
    'backend/tools/verify_inventory_f9_live.py',
    '../v6/core/scanner_components/inventory.py',
    '../v6/core/inventory_count_matcher.py', '../v6/core/scanner_shared.py',
]
previous = entry('docs/migration/scanner-fallback-restoration/f8-source-manifest.json')
manifest = dict(phase='F9 R19-R21', recorded_on='2026-09-01',
    note='F0-F8 snapshots retained; native1280 development calibration, no profile writes or learning',
    previous_snapshot=previous, files=[entry(p) for p in paths])
write('f9-source-manifest.json', manifest)
for row in manifest['files'] + [previous]:
    assert sha(ROOT / row['path']) == row['sha256']
native_root = ROOT / 'backend/tests/fixtures/inventory_detail_f9_live'
native = read(native_root / 'manifest.json')
for row in native['assets']:
    assert sha(native_root / row['file']) == row['sha256']
asset_status = RecognitionAssetCatalog().verify()
assert asset_status['ready'] and asset_status['asset_count'] == 3046
traces = {}
for name in ['equipment-slot13', 'equipment-cancel', 'item-slot1', 'item-cancel',
             'equipment-slot1-retry', 'equipment-slot4']:
    source = ROOT / 'debug/scanner_f9_live' / name / 'trace.json'
    trace = read(source)
    assert len(trace['inputs']) == 2
    assert trace['trace'][-1] == {'restored': 0}
    if 'cancel' in name:
        assert trace['error']['code'] == 'cancelled'
    traces[name] = trace
write('f9-audit.json', dict(asset_status=asset_status,
    source_hashes_verified=len(paths), previous_snapshot=previous,
    native_hashes_verified=len(native['assets']), native_partition=native['partition'],
    native_expectations=native['assets'], live_traces=traces,
    limits=['fast grid zero-input verified by adapter regression, not full live scan',
            'Exp2 actual24890 remains weak_digit_match; new blueprint ID remains unknown',
            'filter/sort/profile validation/scroll F10; native2560 and broader coverage F12'],
    profile_writes=0, permanent_learning=0))
for src, dst in [('f9-python-final.txt', 'f9-python-tests.txt'),
                 ('f9-flutter-analyze.txt', 'f9-flutter-analyze.txt'),
                 ('f9-flutter-tests.txt', 'f9-flutter-tests.txt')]:
    shutil.copy2(ROOT / 'debug' / src, OUT / dst)
print(json.dumps(dict(assets=3046, source_hashes=len(paths), native_hashes=7, restored_live_traces=6)))
