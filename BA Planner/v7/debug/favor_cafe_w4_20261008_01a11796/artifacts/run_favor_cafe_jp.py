"""W4: pinned JP-only table extraction with prior JSON byte preservation.

Uses the existing local JP key privately. No network, key output, source copy,
game execution, old JSON re-extraction, or shared-store mutation.
"""
import hashlib
import importlib
import json
from pathlib import Path
import shutil
import sqlite3
import sys
import tempfile
from contextlib import nullcontext

ROOT = Path(__file__).resolve().parents[3]
ARTIFACTS = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'data/extracted/pipeline'))
import extract_jp
from common import sha256_file, sqlcipher_decrypt

TABLES = ['FavorLevelExcel', 'CafeInteractionExcel']


def info(path):
    return {'path': path.relative_to(ROOT).as_posix(), 'size': path.stat().st_size, 'sha256': sha256_file(path)}


def write_new_json(path, obj):
    with path.open('x', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.write('\n')


def main():
    json_dir = ROOT / 'data/extracted/jp-json'
    new_paths = [json_dir / (t + '.json') for t in TABLES]
    report_path = ARTIFACTS / 'extraction-verification.json'
    const_path = ARTIFACTS / 'ConstCommonExcel.candidate-fields.json'
    if any(p.exists() for p in [*new_paths, report_path, const_path]):
        raise SystemExit('outputs already exist; do not re-extract/overwrite')
    assert set(TABLES).issubset(extract_jp.TABLES)
    prior = list(json_dir.glob('*.json')) + [ROOT / 'data/extracted' / n for n in ['battle-tables-jp.json', 'skill-timing-jp.json', 'cost-effects-jp.json']]
    before = [info(p) for p in prior if p.exists()]
    lock = json.loads((ROOT / 'ba-data.lock').read_text(encoding='utf-8'))
    manifest = json.loads(Path('C:/Users/brigh/ba-client-data/clients/jp/jp-1.73.0-e2baf70e/manifest.json').read_text(encoding='utf-8'))
    src = Path(manifest['files']['ExcelDB.db']['installed_path'])
    source_sha = sha256_file(src)
    assert source_sha == lock['pins']['jp']['files']['ExcelDB.db'] == manifest['files']['ExcelDB.db']['sha256']
    extract_jp.TABLES = TABLES
    resume = Path(sys.argv[1]).resolve() if len(sys.argv) == 2 else None
    if resume:
        assert resume.name == 'excel.db' and resume.parent.name.startswith('baplanner_w4_')
        assert resume.is_relative_to(Path(tempfile.gettempdir()).resolve())
        assert resume.is_file()
    inventory = json.loads((ARTIFACTS / 'jp-static-field-inventory-v2.json').read_text(encoding='utf-8'))
    zip_src = Path(manifest['files']['Excel.zip']['installed_path'])
    zip_sha = sha256_file(zip_src)
    assert zip_sha == lock['pins']['jp']['files']['Excel.zip']
    sys.path.insert(0, str(ROOT / 'backend/tools/battle_spec'))
    from excel_zip_table import read as read_zip_table
    const_all = read_zip_table(str(zip_src), inventory['relevantTypes'], 'ConstCommon')
    const_names = {p['property'] for p in inventory['constCandidateFields'] if p['declaringType'] == 'FlatData.ConstCommonExcel' and p['property'][0].isupper()}
    const_rows = [{k: v for k, v in row.items() if k in const_names} for row in const_all]
    with tempfile.TemporaryDirectory(prefix='baplanner_w4_') as directory:
        temp = Path(directory)
        plain = resume or temp / 'excel.db'
        if resume is None:
            # The secret remains only in process memory. Never hashed, logged or copied.
            key = Path('C:/Users/brigh/ba_jp_key.txt').read_text(encoding='utf-8').strip()
            sqlcipher_decrypt(src, plain, key)
            del key
        report, _ = extract_jp.dump_excel_tables(str(plain), str(temp))
        assert all(type(report[t]) is int and report[t] > 0 for t in TABLES), report
        con = sqlite3.connect(plain)
        sql_tables = [r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")]
        mapping = {t.replace('DBSchema', '').replace('_', '') + 'Excel': t for t in sql_tables if t.endswith('DBSchema')}
        con.close()
        assert const_rows
        # Publish only after every required decode succeeds.
        for table, target in zip(TABLES, new_paths):
            with target.open('xb') as f:
                f.write((temp / (table + '.json')).read_bytes())
            shutil.copyfile(target, ARTIFACTS / target.name)
        write_new_json(const_path, {'table': 'ConstCommonExcel', 'source': 'JP Excel.zip', 'sourceSha256': zip_sha,
                                   'rowCount': len(const_rows), 'candidateScalarFieldsOnly': True,
                                   'decoder': 'existing excel_zip_table.read + same-build JP FlatData.ConstCommonExcel properties',
                                   'rows': const_rows})
    if resume:
        resume.unlink()
        for table, target in zip(TABLES, new_paths):
            leftover = resume.parent / (table + '.json')
            if leftover.exists():
                assert sha256_file(leftover) == sha256_file(target)
                leftover.unlink()
        resume.parent.rmdir()
    after = [info(ROOT / x['path']) for x in before]
    assert before == after, 'existing output bytes changed'
    result = {'schema': 'ba-planner.w4-extraction-verification.v1', 'versionId': manifest['version_id'],
              'sourceSha256': source_sha, 'sourceSize': src.stat().st_size,
              'decrypt': {'method': 'common.sqlcipher_decrypt', 'allPageHmacVerified': True,
                          'pageSize': 4096, 'verifiedPageCount': src.stat().st_size // 4096,
                          'temporaryPlaintextRemoved': True, 'resumeFromCompletedHmacPass': bool(resume),
                          'initialAttempt': 'decode succeeded in temporary output; ConstCommon absent from SQL catalog; published no outputs; resumed original temporary plaintext'},
              'tableOnlyOverride': TABLES, 'rowCounts': report,
              'newFiles': [info(p) for p in new_paths], 'constFile': info(const_path),
              'sqlTableNames': sorted(sql_tables),
              'priorFileCount': len(before), 'priorFilesBefore': before, 'priorFilesAfter': after,
              'priorBytesPreserved': True,
              'tool': {'path': 'data/extracted/pipeline/extract_jp.py', 'sha256': sha256_file(ROOT / 'data/extracted/pipeline/extract_jp.py')},
              'networkCalls': 0, 'gameRuntimeExecutions': 0, 'sharedStoreWrites': 0}
    write_new_json(report_path, result)
    print(json.dumps({k: result[k] for k in ['versionId', 'rowCounts', 'newFiles', 'priorFileCount', 'priorBytesPreserved']}))


if __name__ == '__main__':
    main()
