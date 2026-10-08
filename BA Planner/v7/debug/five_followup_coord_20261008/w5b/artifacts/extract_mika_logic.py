"""W5b round 1: exact CH0069Ex01 dependency slice, local pinned JP only.

No full export, network, key logging, shared-store write, or old-file overwrite.
Reuse the registered same-build DAO schema rather than re-extract its kind.
"""
import hashlib
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
from contextlib import closing

ROOT = Path(__file__).resolve().parents[4]
ART = Path(__file__).resolve().parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'data/extracted/pipeline'))
import memorypack_strict as mp
from common import sha256_file, sqlcipher_decrypt
from skilldata import SKILL_ROOT, EFFECT_ROOT


def write_new(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')


def canon_sha(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                    separators=(',', ':')).encode('utf-8')).hexdigest()


def walk(value, path='$'):
    yield path, value
    if isinstance(value, dict):
        for k, v in value.items():
            yield from walk(v, f'{path}.{k}')
    elif isinstance(value, list):
        for i, v in enumerate(value):
            yield from walk(v, f'{path}[{i}]')


def record(blob, root, schemas, source):
    reader = mp.Reader(blob, schemas)
    try:
        dao = reader.read(root)
        if reader.pos != len(blob):
            raise ValueError(('trailing bytes', reader.pos, len(blob)))
        error = None
    except Exception as exc:
        dao, error = reader.root, str(exc)
    dao = json.loads(json.dumps(dao, default=lambda x: sorted(x) if isinstance(x, set) else str(x)))
    return {'source': dict(source, rowSha256=hashlib.sha256(blob).hexdigest()),
            'status': 'full' if error is None else 'partial' if dao else 'failed',
            'consumedBytes': reader.pos, 'totalBytes': len(blob), 'decodeError': error,
            'decodedSha256': canon_sha(dao), 'dao': dao}


def info(p):
    return {'path': p.relative_to(ROOT).as_posix(), 'size': p.stat().st_size,
            'sha256': sha256_file(p)}


def main():
    evidence = ROOT / 'docs/tactic-editor/evidence/t1-mika-ex-logic-jp-1.73.0.json'
    exports = [ROOT / 'data/extracted/jp-json' / n for n in
               ['SkillLogic.CH0069Ex01.json', 'LogicEffect_PC.CH0069Ex01.json']]
    receipt = ART / 'round1-extraction-verification.json'
    assert not any(p.exists() for p in [evidence, receipt, *exports]), 'never overwrite existing output'
    protected = list((ROOT / 'data/extracted/jp-json').glob('*.json'))
    protected += [ROOT / p for p in ['ba-data.lock', 'data/extracted/pipeline/extract_jp.py',
        'data/extracted/skill-timing-jp.json', 'data/extracted/cost-effects-jp.json',
        'docs/tactic-editor/t1-user-mika-ex-observations-2026-10-08.md',
        'docs/tactic-editor/t1-mika-ex-gate-2026-10-08.md',
        'docs/tactic-editor/evidence/t1-mika-ex-gate-2026-10-08.json',
        'docs/tactic-editor/t1-mika-ex-context-followup-2026-10-08.md',
        'docs/tactic-editor/evidence/t1-mika-ex-context-followup-2026-10-08.json']]
    before = [info(p) for p in protected]
    lock = json.loads((ROOT / 'ba-data.lock').read_text(encoding='utf-8'))
    manifest = json.loads(Path('C:/Users/brigh/ba-client-data/clients/jp/jp-1.73.0-e2baf70e/manifest.json').read_text(encoding='utf-8'))
    pin = lock['pins']['jp']
    schema_path = ROOT / 'docs/tactic-editor/evidence/t3-binah-dao-schema-jp.json'
    schema_lock = next(x for x in lock['extracts'] if x['server'] == 'jp' and x['kind'] == 'dao-schema')
    assert sha256_file(schema_path) == schema_lock['files'][schema_path.name]
    source_names = ['GameAssembly.dll', 'global-metadata.dat', 'LevelSkillDataDBSchema.db', 'LogicEffectDataDBSchema.db']
    sources = {}
    for name in source_names:
        src = Path(manifest['files'][name]['installed_path'])
        sha = sha256_file(src)
        assert sha == manifest['files'][name]['sha256'] == pin['files'][name], name
        sources[name] = {'sha256': sha, 'size': src.stat().st_size}
    schemas = mp.load_schema_bundle(schema_path)
    mp.LENIENT_ENUMS = True
    excel_path = ROOT / 'data/extracted/jp-json/SkillExcel.json'
    excel_rows = [r for r in json.loads(excel_path.read_text(encoding='utf-8'))['data_list']
                  if 'CH0069Ex01' in r.values()]
    assert excel_rows and any(r.get('level') == 5 for r in excel_rows)
    skill_rows, effect_rows, links, missing = [], [], [], []
    with tempfile.TemporaryDirectory(prefix='baplanner_w5b_') as directory:
        temp = Path(directory)
        # Secret is consumed privately in this process; never printed/copied/hashed.
        key = Path('C:/Users/brigh/ba_jp_key.txt').read_text(encoding='utf-8').strip()
        for name, filename in [('LevelSkillDataDBSchema.db', 'skill.db'), ('LogicEffectDataDBSchema.db', 'effect.db')]:
            sqlcipher_decrypt(Path(manifest['files'][name]['installed_path']), temp / filename, key)
        del key
        with closing(sqlite3.connect(temp / 'skill.db')) as con:
            matches = list(con.execute('SELECT Key, Bytes FROM Student WHERE Key = ?', ('CH0069Ex01',)))
            assert len(matches) == 1
            for ident, blob in matches:
                rec = record(blob, SKILL_ROOT, schemas, {'database': 'LevelSkillDataDBSchema.db',
                    'databaseSha256': sources['LevelSkillDataDBSchema.db']['sha256'], 'table': 'Student', 'key': ident})
                skill_rows.append(rec)
        pending = set()
        for rec in skill_rows:
            for path, value in walk(rec['dao']):
                if 'LogicEffectGroupId' in path and isinstance(value, str) and value:
                    pending.add(value)
                    links.append({'from': 'CH0069Ex01', 'fieldPath': path, 'toGroupId': value})
        seen = set()
        with closing(sqlite3.connect(temp / 'effect.db')) as con:
            while pending - seen:
                group = sorted(pending - seen)[0]
                seen.add(group)
                matches = list(con.execute('SELECT GroupId, Level, Bytes FROM LogicEffect_PC WHERE GroupId = ? ORDER BY Level', (group,)))
                if not matches:
                    missing.append(group)
                for ident, level, blob in matches:
                    rec = record(blob, EFFECT_ROOT, schemas, {'database': 'LogicEffectDataDBSchema.db',
                        'databaseSha256': sources['LogicEffectDataDBSchema.db']['sha256'], 'table': 'LogicEffect_PC',
                        'groupId': ident, 'level': level})
                    effect_rows.append(rec)
                    for path, value in walk(rec['dao']):
                        if 'LogicEffectGroupId' in path and isinstance(value, str) and value:
                            pending.add(value)
                            links.append({'from': ident, 'level': level, 'fieldPath': path, 'toGroupId': value})
    result = {'schema': 'ba-planner.mika-ex-logic.v1', 'server': 'japan', 'clientVersion': '1.73.0',
        'versionId': pin['version_id'], 'gameAssemblySha256': pin['files']['GameAssembly.dll'],
        'metadataSha256': pin['files']['global-metadata.dat'], 'sources': sources,
        'scope': {'key': 'CH0069Ex01', 'allFieldsPreserved': True, 'linkedRowsOnly': True,
                  'wholeTableExport': False, 'existingSkillExcelReused': True, 'newExcelTablesNeeded': [],
                  'tablesUnchangedReason': 'SkillExcel already exported; SkillLogic and LogicEffect_PC are MemoryPack tables, not ExcelDB FlatBuffers tables.'},
        'decoder': {'path': 'data/extracted/pipeline/memorypack_strict.py',
                    'sha256': sha256_file(ROOT / 'data/extracted/pipeline/memorypack_strict.py'),
                    'sameBuildSchemaPath': schema_path.relative_to(ROOT).as_posix(),
                    'sameBuildSchemaSha256': sha256_file(schema_path), 'strictFullConsumption': True,
                    'undeclaredEnumsPreservedAsUnresolvedNumbers': True},
        'skillExcel': {'sourcePath': excel_path.relative_to(ROOT).as_posix(), 'sourceSha256': sha256_file(excel_path),
                       'rowCount': len(excel_rows), 'rows': [{'decodedSha256': canon_sha(r), 'row': r} for r in excel_rows]},
        'skillLogic': skill_rows, 'logicEffects': effect_rows, 'referenceLinks': links,
        'missingEffectGroups': sorted(missing), 'round': 1,
        'provenanceLimits': ['JP data; exact observed KR build and equivalence remain unverified.'],
        'tool': {'path': 'debug/five_followup_coord_20261008/w5b/artifacts/extract_mika_logic.py',
                 'sha256': sha256_file(__file__)}}
    assert not missing
    assert all(r['status'] == 'full' for r in skill_rows + effect_rows), 'strict decode incomplete'
    # Publish exact dependency slices only after all decodes succeeded.
    write_new(exports[0], {'schema': 'ba-planner.mika-skilllogic-slice.v1', 'rows': skill_rows})
    write_new(exports[1], {'schema': 'ba-planner.mika-logiceffect-slice.v1', 'rows': effect_rows})
    write_new(evidence, result)
    after = [info(ROOT / x['path']) for x in before]
    assert before == after, 'protected pre-existing bytes changed'
    write_new(receipt, {'round': 1, 'existingBytesPreserved': True, 'protectedBefore': before,
        'protectedAfter': after, 'sources': sources, 'outputs': [info(p) for p in [*exports, evidence]],
        'skillRows': len(skill_rows), 'effectRows': len(effect_rows), 'missingGroups': missing,
        'decrypt': {'allPageHmacVerified': True, 'temporaryPlaintextRemoved': True},
        'networkCalls': 0, 'sharedStoreWrites': 0, 'keyValueRecordedOrHashed': False})
    print(json.dumps({'round': 1, 'skillRows': len(skill_rows), 'effectRows': len(effect_rows),
                      'missingGroups': missing, 'existingBytesPreserved': True}))


if __name__ == '__main__':
    main()
