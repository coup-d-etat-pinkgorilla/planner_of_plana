"""A1-a: generalize W5b strict row decoding; local pinned JP, no store writes.

Decode every skill DB row once. Character ownership uses explicit SkillList groups,
SkillExcel group/data keys, then the existing Binah group+'_' suffix rule. Unowned
rows are retained separately, never assigned by name similarity. Partial rows and
their bytes consumed/error/raw hashes remain visible. Secrets are not logged.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from contextlib import closing
import json
import hashlib
from pathlib import Path
import sqlite3
import sys
import tempfile
import time

from _research_common import (ROOT, VERSION, canonical_sha, characters, effect_refs,
                              excel_inputs, file_record, load, sha, source_context, write_new)

sys.path.insert(0, str(ROOT / 'data/extracted/pipeline'))
import memorypack_strict as mp
from common import sqlcipher_decrypt
from skilldata import SKILL_ROOT, EFFECT_ROOT


def decode_record(blob, root, schemas, source):
    # Same reader/status/normalization as W5b, with failures retained rather than fatal.
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
            'decodedSha256': canonical_sha(dao), 'dao': dao}


def quoted(name):
    return '"' + name.replace('"', '""') + '"'


def collect_skill(skill_id, skills, effects):
    logic = sorted(skills[skill_id], key=lambda r: r['source']['table'])
    pending = set().union(*(effect_refs(r) for r in logic))
    seen, referenced = set(), []
    while pending - seen:
        group = sorted(pending - seen)[0]
        seen.add(group)
        for row in effects.get(group, []):
            referenced.append(row)
            pending.update(effect_refs(row))
    referenced.sort(key=lambda r: (r['source']['table'], r['source']['groupId'], r['source']['level']))
    missing = seen - set(effects)
    return {'logicRows': logic, 'logicEffectRows': referenced,
            'referencesComplete': not missing, 'referencedEffectGroups': sorted(seen),
            'missingEffectGroups': sorted(missing)}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out-dir', type=Path, required=True)
    ap.add_argument('--evidence-index', type=Path, required=True)
    ap.add_argument('--receipt', type=Path, required=True)
    args = ap.parse_args()
    for p in (args.out_dir, args.evidence_index, args.receipt):
        if p.exists():
            raise FileExistsError('preserve existing output: ' + str(p))
        if not p.resolve().is_relative_to(ROOT):
            raise ValueError('output must remain in v7')
    started = time.perf_counter()
    lock, manifest, sources = source_context(('GameAssembly.dll', 'global-metadata.dat',
        'ExcelDB.db', 'LevelSkillDataDBSchema.db', 'LogicEffectDataDBSchema.db'))
    excel, inputs = excel_inputs(lock)
    selected = characters(excel)
    schema_path = ROOT / 'docs/tactic-editor/evidence/t3-binah-dao-schema-jp.json'
    schema_pin = next(e for e in lock['extracts'] if e['server'] == 'jp' and e['kind'] == 'dao-schema')
    if sha(schema_path) != schema_pin['files'][schema_path.name]:
        raise ValueError('same-build schema hash mismatch')
    schemas = mp.load_schema_bundle(schema_path)
    mp.LENIENT_ENUMS = True
    skills, effects, table_counts = defaultdict(list), defaultdict(list), {}
    with tempfile.TemporaryDirectory(prefix='baplanner_a1a_') as directory:
        temp = Path(directory)
        # Existing local secret consumed only inside this process. No key metadata exported.
        key = (Path.home() / 'ba_jp_key.txt').read_text(encoding='utf-8').strip()
        for name, filename in (('LevelSkillDataDBSchema.db', 'skill.db'),
                               ('LogicEffectDataDBSchema.db', 'effect.db')):
            sqlcipher_decrypt(Path(manifest['files'][name]['installed_path']), temp / filename, key)
        del key
        for db_name, filename, root_type, destination, columns in (
            ('LevelSkillDataDBSchema.db', 'skill.db', SKILL_ROOT, skills, ('Key', 'Bytes')),
            ('LogicEffectDataDBSchema.db', 'effect.db', EFFECT_ROOT, effects, ('GroupId', 'Level', 'Bytes'))):
            with closing(sqlite3.connect('file:' + (temp / filename).as_posix() + '?mode=ro', uri=True)) as con:
                for (table,) in con.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"):
                    actual_columns = {r[1] for r in con.execute('PRAGMA table_info(' + quoted(table) + ')')}
                    if not set(columns) <= actual_columns:
                        table_counts[db_name + '/' + table] = {'skippedColumns': sorted(actual_columns)}
                        continue
                    counts = Counter()
                    sql = 'SELECT ' + ','.join(quoted(c) for c in columns) + ' FROM ' + quoted(table)
                    for values in con.execute(sql):
                        ident, blob = values[0], values[-1]
                        source = {'database': db_name, 'databaseSha256': sources[db_name]['sha256'],
                                  'table': table}
                        if root_type == SKILL_ROOT:
                            source['key'] = ident
                        else:
                            source.update(groupId=ident, level=values[1])
                        rec = decode_record(blob, root_type, schemas, source)
                        destination[ident].append(rec)
                        counts[rec['status']] += 1
                    table_counts[db_name + '/' + table] = dict(counts)
                    print(json.dumps({'decodedTable': db_name + '/' + table, 'counts': dict(counts)}), flush=True)
    # Temporary plaintext has been removed before publishing any derived rows.
    excel_by_group = defaultdict(list)
    for row in excel['SkillExcel']:
        excel_by_group[row['group_id']].append(row)
    all_keys = set(skills)
    seen_keys, files, per_character = set(), [], []
    for n, (cid, character) in enumerate(selected.items(), 1):
        keys, group_missing = set(), []
        for group in character['groups']:
            found = {group} & all_keys
            found.update(r['skill_data_key'] for r in excel_by_group.get(group, []) if r['skill_data_key'] in all_keys)
            found.update(k for k in all_keys if k.startswith(group + '_'))
            if not found:
                group_missing.append(group)
            keys.update(found)
        seen_keys.update(keys)
        output_skills, character_counts = {}, Counter()
        missing_effects = set()
        for skill_id in sorted(keys):
            rec = collect_skill(skill_id, skills, effects)
            missing_effects.update(rec['missingEffectGroups'])
            character_counts.update(r['status'] for r in rec['logicRows'] + rec['logicEffectRows'])
            output_skills[skill_id] = rec
        payload = {'schema': 'ba-planner.skill-logic-full.v1', 'clientVersionId': VERSION,
                   **{k: v for k, v in character.items() if k != 'groups'}, 'skillGroups': character['groups'],
                   'sourceHashes': {k: v['sha256'] for k, v in sources.items()},
                   'skills': output_skills, 'missingSkillGroups': group_missing,
                   'missingEffectGroups': sorted(missing_effects),
                   'decodeCountsWithReferences': dict(character_counts)}
        path = args.out_dir / f'{cid}.json'
        write_new(path, payload)
        rec = file_record(path)
        files.append(rec)
        per_character.append({'characterId': cid, 'devName': character['devName'], 'kind': character['kind'],
                              'variantKinds': character['variantKinds'], 'file': path.name,
                              'sha256': rec['sha256'], 'bytes': rec['bytes'], 'skillCount': len(keys),
                              'decodeCountsWithReferences': dict(character_counts),
                              'missingSkillGroups': group_missing, 'missingEffectGroups': sorted(missing_effects)})
        if n % 1000 == 0:
            print(json.dumps({'charactersWritten': n}), flush=True)
    unassigned = sorted(all_keys - seen_keys)
    unassigned_path = args.out_dir / 'unassigned-skill-rows.json'
    write_new(unassigned_path, {'schema': 'ba-planner.unassigned-skill-rows.v1', 'clientVersionId': VERSION,
                               'reason': 'No explicit selected CharacterSkillList/SkillExcel ownership; never name-fitted',
                               'skills': {k: collect_skill(k, skills, effects) for k in unassigned}})
    files.append(file_record(unassigned_path))
    skill_counts = Counter(r['status'] for rows in skills.values() for r in rows)
    effect_counts = Counter(r['status'] for rows in effects.values() for r in rows)
    index = {'schema': 'ba-planner.skill-logic-full-index.v1', 'clientVersionId': VERSION,
             'sourceHashes': sources, 'excelInputs': inputs, 'schemaSource': file_record(schema_path),
             'decoder': file_record(ROOT / 'data/extracted/pipeline/memorypack_strict.py'),
             'tool': file_record(Path(__file__)),
             'gameAssemblySha256': sources['GameAssembly.dll']['sha256'],
             'metadataSha256': sources['global-metadata.dat']['sha256'],
             'enumSource': file_record(ROOT / 'backend/.venv/Lib/site-packages/FlatData/TacticEntityType.py'),
             'characterSelection': 'all Student enum/is_playable_character plus all nonempty CharacterSkillList group IDs; missing CharacterExcel preserved',
             'ownershipRule': 'exact SkillList group or SkillExcel group_id->skill_data_key, plus group+underscore suffix; no name similarity',
             'characterCount': len(selected), 'characterKindCounts': dict(Counter(r['kind'] for r in per_character)),
             'uniqueSkillKeyCount': len(skills), 'assignedUniqueSkillKeyCount': len(seen_keys),
             'unassignedUniqueSkillKeyCount': len(unassigned), 'uniqueSkillRowCounts': dict(skill_counts),
             'uniqueDecodedEffectRowCounts': dict(effect_counts), 'databaseTables': table_counts,
             'characters': per_character, 'files': files, 'totalPayloadBytes': sum(r['bytes'] for r in files),
             'filesOver10MiB': [r for r in files if r['bytes'] > 10 << 20],
             'elapsedSeconds': time.perf_counter() - started,
             'limits': ['Partial decode is retained; no unknown union/member guessing',
                        'Unassigned skill rows are not attributed to a character',
                        'Entity DAO is inline; exact runtime arrival/HP arithmetic remains unverified',
                        'Spine not decoded; source version JP only; no store write/network/game process']}
    write_new(args.out_dir / 'index.json', index)
    write_new(args.evidence_index, index)
    write_new(args.receipt, {'version': VERSION, 'counts': {k: index[k] for k in ('characterCount',
        'uniqueSkillKeyCount', 'assignedUniqueSkillKeyCount', 'unassignedUniqueSkillKeyCount',
        'uniqueSkillRowCounts', 'uniqueDecodedEffectRowCounts', 'totalPayloadBytes', 'elapsedSeconds')},
        'sources': sources, 'temporaryPlaintextRemoved': True, 'keyValuesRecorded': False,
        'index': file_record(args.out_dir / 'index.json'), 'evidenceIndex': file_record(args.evidence_index)})
    print(json.dumps(load(args.receipt)['counts']), flush=True)


if __name__ == '__main__':
    main()
