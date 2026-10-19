"""JP client + JP key -> ExcelDB JSON (arisu format) + skill-timing-jp.json + cost-effects-jp.json.

Reads only local files. The key comes from get_jp_key.py.
Needs: pip install "plana-flatbuffers @ git+https://github.com/arisu-archive/plana-flatbuffers@v0.16.0"
       (brings flatbuffers + xxhash; use a newer tag after JP schema updates)

usage: python extract_jp.py --jp "C:/YostarGames/BlueArchive_JP" --key-file "%USERPROFILE%/ba_jp_key.txt" --out-dir ..
"""
import argparse
import hashlib
import importlib
import json
import os
import re
import sqlite3
import tempfile

import memorypack_strict as mp
from common import jp_bundle_path, sha256_file, sqlcipher_decrypt
from il2cpp_meta import generate_dao_schema
from skilldata import decode_effect_db, decode_skill_db, write_effect_json, write_skill_json

BATTLE_TABLES = {
    # The runtime calls this concept LevelDamageFactor, while ExcelDB stores it as BattleLevelFactor.
    'LevelDamageFactor': 'BattleLevelFactorExcel',
    'TerrainAdaptationFactor': 'TerrainAdaptationFactorExcel',
    'BulletArmorDamageFactor': 'BulletArmorDamageFactorExcel',
    'CharacterLevelStatFactor': 'CharacterLevelStatFactorExcel',
}

TABLES = ['CharacterExcel', 'CharacterSkillListExcel', 'SkillExcel', 'LocalizeSkillExcel', 'LocalizeEtcExcel', 'CharacterStatExcel',
          # student-stat catalog (build_stat_catalog.py)
          'CharacterWeaponExcel', 'FavorLevelRewardExcel', 'CharacterGearExcel', 'EquipmentExcel', 'EquipmentStatExcel', 'StatLevelInterpolationExcel', 'CharacterTranscendenceExcel', 'CharacterPotentialExcel', 'CharacterPotentialStatExcel',
          # battle damage rules (battle-tables-jp.json)
          *BATTLE_TABLES.values(),
          # T4a stage 14 DamageLimitChecker input; JP rows are provisional for Steam (not the pinned Steam DB)
          'CharacterCalculationLimitExcel',
          # frontend request 2026-10-08 02:45: favor experience and cafe interaction rewards
          'FavorLevelExcel', 'CafeInteractionExcel']


def snake(name):
    return re.sub(r'(?<=[a-z0-9])(?=[A-Z])', '_', name).lower()


def to_plain(v):
    if isinstance(v, bytes):
        return v.decode('utf-8', 'replace')
    if hasattr(v, 'tolist'):          # numpy arrays from the flatbuffers object API
        return v.tolist()
    if isinstance(v, list):
        return [to_plain(x) for x in v]
    if hasattr(v, '__dict__'):
        return {snake(k): to_plain(x) for k, x in vars(v).items()}
    return v


def rows_sha256(rows):
    payload = json.dumps(rows, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode('utf-8')
    return hashlib.sha256(payload).hexdigest()


def dump_excel_tables(plain_db, json_dir):
    con = sqlite3.connect(plain_db)
    sql_tables = [r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")]
    # assets-dumper rule: strip 'DBSchema', add 'Excel', drop underscores
    by_fb = {t.replace('DBSchema', '').replace('_', '') + 'Excel': t for t in sql_tables if t.endswith('DBSchema')}
    report = {}
    decoded = {}
    for fb in TABLES:
        if fb not in by_fb:
            report[fb] = 'missing in ExcelDB'
            continue
        mod = importlib.import_module(f'MX.Data.Excel.{fb}')
        cls, tcls = getattr(mod, fb), getattr(mod, fb + 'T')
        rows = [to_plain(tcls.InitFromObj(cls.GetRootAs(b, 0))) for (b,) in con.execute(f'SELECT Bytes FROM "{by_fb[fb]}"')]
        json.dump({'data_list': rows}, open(os.path.join(json_dir, fb + '.json'), 'w', encoding='utf-8'), ensure_ascii=False)
        report[fb] = len(rows)
        if fb in BATTLE_TABLES.values():
            decoded[fb] = rows
    con.close()
    return report, decoded


def write_battle_tables(path, decoded, meta):
    missing = [fb for fb in BATTLE_TABLES.values() if fb not in decoded]
    if missing:
        raise RuntimeError(f'battle tables missing from ExcelDB: {missing}')
    tables = {}
    for name, fb in BATTLE_TABLES.items():
        rows = decoded[fb]
        tables[name] = {
            'sourceTable': fb,
            'rowCount': len(rows),
            'rowsSha256': rows_sha256(rows),
            'rows': rows,
        }
    payload = dict(meta, schema='ba-planner.battle-tables.v1', tables=tables)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
        f.write('\n')
    return {name: {'rowCount': item['rowCount'], 'rowsSha256': item['rowsSha256']}
            for name, item in tables.items()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--jp', required=True)
    ap.add_argument('--key-file', required=True)
    ap.add_argument('--out-dir', required=True)
    ap.add_argument('--json-dir', help='where to write ExcelDB JSON (default <out-dir>/jp-json)')
    a = ap.parse_args()
    key = open(os.path.expandvars(os.path.expanduser(a.key_file)), encoding='utf-8').read().strip()
    json_dir = a.json_dir or os.path.join(a.out_dir, 'jp-json')
    os.makedirs(json_dir, exist_ok=True)
    tb = os.path.join(a.jp, 'BlueArchive_Data', 'StreamingAssets', 'TableBundles')
    listing = os.listdir(tb)
    try:
        version = json.load(open(os.path.join(a.jp, 'game-launcher-config.json'), encoding='utf-8'))['version']
    except Exception:
        version = None
    ga = os.path.join(a.jp, 'GameAssembly.dll')
    md = os.path.join(a.jp, 'BlueArchive_Data', 'il2cpp_data', 'Metadata', 'global-metadata.dat')

    with tempfile.TemporaryDirectory() as tmp:
        # ---- ExcelDB (FlatBuffers via arisu-archive/plana-flatbuffers)
        src = jp_bundle_path(tb, 'ExcelDB.db', listing); dec = os.path.join(tmp, 'excel.db')
        sqlcipher_decrypt(src, dec, key)
        rep, battle = dump_excel_tables(dec, json_dir)
        source_sha = sha256_file(src)
        json.dump({'source': 'local JP client ExcelDB.db', 'clientVersion': version, 'ref': f'local-{version}',
                   'sourceSha256': source_sha}, open(os.path.join(json_dir, 'SOURCE.json'), 'w'))
        print('ExcelDB tables', rep)
        battle_report = write_battle_tables(
            os.path.join(a.out_dir, 'battle-tables-jp.json'),
            battle,
            {
                'server': 'japan',
                'clientVersion': version,
                'source': 'JP client ExcelDB.db',
                'sourceSha256': source_sha,
            },
        )
        print('battle tables', battle_report)

        # ---- skill DBs (MemoryPack, schema generated from this same client build)
        schemas, unions = generate_dao_schema(ga, md)
        bundle = os.path.join(tmp, 'schema.json')
        json.dump({'schemas': schemas, 'unions': {k: {str(t): n for t, n in v.items()} for k, v in unions.items()}}, open(bundle, 'w'))
        schemas = mp.load_schema_bundle(bundle)
        mp.LENIENT_ENUMS = True
        decoder = (f'strict MemoryPack decoder; schema generated from this client ({len(schemas)} types, '
                   f'{sum(len(v) for v in unions.values())} union tags); undeclared enum values kept as numbers')
        meta_common = {'server': 'japan', 'clientVersion': version, 'decoder': decoder,
                       'gameAssemblySha256': sha256_file(ga), 'metadataSha256': sha256_file(md)}

        src = jp_bundle_path(tb, 'LevelSkillDataDBSchema.db', listing); dec = os.path.join(tmp, 'skill.db')
        sqlcipher_decrypt(src, dec, key)
        counts = write_skill_json(os.path.join(a.out_dir, 'skill-timing-jp.json'), decode_skill_db(dec, schemas),
                                  dict(meta_common, source='JP client LevelSkillDataDBSchema.db, table Student', sourceSha256=sha256_file(src)))
        print('skills', counts)

        src = jp_bundle_path(tb, 'LogicEffectDataDBSchema.db', listing); dec = os.path.join(tmp, 'effect.db')
        sqlcipher_decrypt(src, dec, key)
        effects, failed = decode_effect_db(dec, schemas)
        counts = write_effect_json(os.path.join(a.out_dir, 'cost-effects-jp.json'), effects, failed,
                                   dict(meta_common, source='JP client LogicEffectDataDBSchema.db, LogicEffect_PC', sourceSha256=sha256_file(src)))
        print('cost effects', counts, 'undecoded rows', failed)


if __name__ == '__main__':
    main()
