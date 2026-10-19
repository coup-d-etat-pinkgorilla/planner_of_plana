"""Read-only source checks and deterministic derived-output helpers for CM A1."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
VERSION = 'jp-1.73.0-e2baf70e'


def load(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def canonical_sha(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                    separators=(',', ':')).encode('utf-8')).hexdigest()


def write_new(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('x', encoding='utf-8', newline='\n') as f:
        json.dump(value, f, ensure_ascii=False, indent=1, allow_nan=False)
        f.write('\n')


def file_record(path):
    path = Path(path).resolve()
    return {'path': path.relative_to(ROOT).as_posix(), 'bytes': path.stat().st_size, 'sha256': sha(path)}


def source_context(names):
    lock = load(ROOT / 'ba-data.lock')
    if lock['pins']['jp']['version_id'] != VERSION:
        raise ValueError('JP version pin differs; stop')
    store = Path(lock['store_root'])
    manifest = load(store / 'clients/jp' / VERSION / 'manifest.json')
    checked = {}
    for name in names:
        spec = manifest['files'][name]
        p = Path(spec['installed_path'])
        digest = sha(p)
        if digest != spec['sha256'] or digest != lock['pins']['jp']['files'][name]:
            raise ValueError('installed source hash mismatch: ' + name)
        checked[name] = {'sha256': digest, 'bytes': p.stat().st_size}
    return lock, manifest, checked


def excel_inputs(lock):
    ex = next(e for e in lock['extracts'] if e['server'] == 'jp' and e['kind'] == 'exceldb-json')
    rows = {}
    receipts = {}
    for name in ('CharacterExcel', 'CharacterSkillListExcel', 'SkillExcel'):
        p = ROOT / 'data/extracted/jp-json' / (name + '.json')
        if sha(p) != ex['files'][p.name]:
            raise ValueError('local Excel JSON differs from locked extract: ' + name)
        rows[name] = load(p)['data_list']
        receipts[name] = file_record(p)
    return rows, receipts


def skill_groups(row):
    return {v for k, values in row.items() if k.endswith('skill_group_id')
            and isinstance(values, list) for v in values if isinstance(v, str) and v}


def characters(excel):
    chars = {r['id']: r for r in excel['CharacterExcel']}
    lists = {}
    for row in excel['CharacterSkillListExcel']:
        if skill_groups(row):
            lists.setdefault(row['character_skill_list_group_id'], []).append(row)
    selected = set(lists) | {r['id'] for r in chars.values()
                            if r.get('is_playable_character') or r.get('tactic_entity_type') == 1}
    result = {}
    entity_names = {1: 'Student', 2: 'Minion', 4: 'Elite', 8: 'Champion', 16: 'Boss',
                    32: 'Obstacle', 64: 'Servant', 128: 'Vehicle', 256: 'Summoned',
                    512: 'Hallucination', 1024: 'DestructibleProjectile'}
    for cid in sorted(selected):
        ch = chars.get(cid)
        raw_entity = ch.get('tactic_entity_type') if ch else None
        kind = ('student' if ch and (ch.get('is_playable_character') or raw_entity == 1) else
                'boss' if raw_entity == 16 else 'enemy' if ch else 'metadata_missing')
        forms = sorted({r['form_index'] for r in lists.get(cid, [])})
        flags = []
        if ch and ch.get('is_dummy'):
            flags.append('dummy')
        if any(f != 0 for f in forms):
            flags.append('form_variant')
        if ch and ch.get('is_npc'):
            flags.append('npc')
        result[cid] = {'characterId': cid, 'devName': ch.get('dev_name', '') if ch else '',
                       'kind': kind, 'variantKinds': flags, 'formIndices': forms,
                       'tacticEntityType': raw_entity, 'tacticEntityName': entity_names.get(raw_entity),
                       'classificationBasis': 'CharacterExcel playable flag; generated FlatData TacticEntityType enum labels',
                       'characterRow': ch, 'skillListRows': lists.get(cid, []),
                       'groups': sorted(set().union(*(skill_groups(r) for r in lists.get(cid, []))))}
    return result


def walk(value, path='$'):
    yield path, value
    if isinstance(value, dict):
        for k, v in value.items():
            yield from walk(v, path + '.' + k)
    elif isinstance(value, list):
        for i, v in enumerate(value):
            yield from walk(v, f'{path}[{i}]')


def effect_refs(record):
    return sorted({v for p, v in walk(record.get('dao'))
                   if 'LogicEffectGroupId' in p and isinstance(v, str) and v})
