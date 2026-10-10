"""A1-c bounded conversion. Never guess skill/clip links or projectile arrival clocks.

Unlinked logic markers are retained in the index keyed by original row SHA; they
are not drawn on a clip without the permitted explicit SkillExcel name/state link.
The immutable contract requires estimated=true for inferred callback semantics.
"""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
from pathlib import Path
import sys
import time
import jsonschema
from _research_common import ROOT, VERSION, load, sha, canonical_sha, walk, file_record, write_new


def callback(clip, event):
    name, seconds = event['functionName'], event['time']
    kind = 'sfx' if name == 'PlayAudio' else 'vfx' if name.endswith('InstantiateFx') else 'other'
    frame = round(seconds * 30)
    semantic_inference = kind in ('sfx', 'vfx')
    return {'frame': frame, 'timeSeconds': seconds, 'layer': 'anim_event', 'name': name, 'kind': kind,
        'evidence': {'kind': 'observation', 'clipPath': clip['bundlePath'] + '#AnimationClip[name=' + clip['name'] + ';PathID=' + str(clip['pathId']) + ']'},
        'estimated': semantic_inference or abs(seconds * 30 - frame) >= 0.5,
        'note': 'callback metadata; category inferred from callback name; effect/hit application unknown' if semantic_inference else 'callback metadata; no damage/hit meaning assigned'}


def row_markers(row):
    result, omitted = [], Counter()
    source = row['source']
    locator = source['database'] + '/' + source['table'] + ':' + str(source.get('key', source.get('groupId')))
    if 'level' in source:
        locator += ':level=' + str(source['level'])
    for path, value in walk(row.get('dao')):
        if not isinstance(value, dict):
            continue
        type_name = value.get('$type', '')
        kind = next((k for token, k in (('Groggy', 'groggy'), ('Summon', 'summon'), ('Debuff', 'debuff'), ('Buff', 'buff'), ('DamageEffect', 'damage')) if token in type_name), 'other')
        candidates = []
        if 'Frame' in value and isinstance(value.get('Tag'), dict):
            tag = value['Tag'].get('name')
            if tag in ('ActionRelease', 'ActionStart', 'ActionEnd'):
                candidates.append(('Frame', value['Frame'], 'fire' if tag == 'ActionRelease' else 'other', tag))
        for key in ('SpawnDelay', 'StartDelay', 'Duration', 'DurationFrames'):
            if key in value:
                candidates.append((key, value[key], 'fire' if key == 'SpawnDelay' else kind, key))
        for n, frame in enumerate(value.get('HitFrames', []) or []):
            candidates.append((f'HitFrames[{n}]', frame, 'hit', 'explicit HitFrames, local entity clock'))
        for field, frame, event_kind, label in candidates:
            if not isinstance(frame, int) or isinstance(frame, bool):
                omitted['noninteger_clock'] += 1
                continue
            if frame < 0:
                omitted['negative_sentinel'] += 1
                continue
            result.append({'frame': frame, 'timeSeconds': frame / 30, 'layer': 'logic_effect',
                'name': path + '.' + field + ':' + label, 'kind': event_kind,
                'evidence': {'kind': 'table', 'table': locator, 'rowSha': source['rowSha256']},
                'estimated': True, 'note': 'arrival unknown; raw local logic frame retained; clock composition and clip binding unverified' + ('; partial row' if row['status'] != 'full' else '')})
    return result, dict(omitted)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--skill-dir', type=Path, required=True)
    ap.add_argument('--animation-dir', type=Path, required=True)
    ap.add_argument('--out-dir', type=Path, required=True)
    ap.add_argument('--receipt', type=Path, required=True)
    args = ap.parse_args()
    for p in (args.out_dir, args.receipt):
        if p.exists() or not p.resolve().is_relative_to(ROOT):
            raise ValueError('preserve output / workspace boundary')
    started = time.perf_counter()
    a, b = load(args.skill_dir / 'index.json'), load(args.animation_dir / 'index.json')
    if a['clientVersionId'] != VERSION or b['clientVersionId'] != VERSION:
        raise ValueError('input version mismatch')
    schema_path = ROOT / 'contracts/animation-spectrum-v1.schema.json'
    schema = load(schema_path)
    jsonschema.Draft202012Validator.check_schema(schema)
    validator = jsonschema.Draft202012Validator(schema)
    lock = load(ROOT / 'ba-data.lock')
    excel_pin = next(e for e in lock['extracts'] if e['server'] == 'jp' and e['kind'] == 'exceldb-json')
    skill_excel_path = ROOT / 'data/extracted/jp-json/SkillExcel.json'
    localize_path = ROOT / 'data/extracted/jp-json/LocalizeEtcExcel.json'
    for p in (skill_excel_path, localize_path):
        if sha(p) != excel_pin['files'][p.name]:
            raise ValueError('locked Excel input mismatch')
    skill_excel = load(skill_excel_path)['data_list']
    localize = {r['key']: r for r in load(localize_path)['data_list']}
    animation_fields = sorted({k for r in skill_excel for k in r if any(t in k.casefold() for t in ('animation', 'motion', 'state'))})
    excel_by_skill = defaultdict(list)
    for row in skill_excel:
        excel_by_skill[row['skill_data_key']].append(row)
    row_cache, invalid, characters, files, counters = {}, [], [], [], Counter()
    a_by_id = {c['characterId']: c for c in a['characters']}
    for n, char in enumerate(b['characters'], 1):
        cid = char['characterId']
        p = args.animation_dir / char['file']
        if sha(p) != char['sha256']:
            raise ValueError('Animation input hash mismatch')
        raw = load(p)
        ac = a_by_id[cid]
        q = args.skill_dir / ac['file']
        if sha(q) != ac['sha256']:
            raise ValueError('Skill input hash mismatch')
        skill = load(q)
        ch = skill['characterRow'] or {}
        name = localize.get(ch.get('localize_etc_id'), {})
        clips, by_id = [], {}
        for rc in raw['clips']:
            identifier = (rc['bundlePath'], rc['pathId'])
            converted = {'name': rc['name'], 'bundlePath': rc['bundlePath'], 'sourceFps': rc['sourceFps'],
                'lengthSeconds': rc['lengthSeconds'], 'lengthLogicFrames': round(rc['lengthSeconds'] * 30),
                'logicDurationFrames': None, 'events': [callback(rc, e) for e in rc['events']]}
            clips.append(converted)
            by_id[identifier] = converted
        unmapped_skills, mapped_skills = {}, []
        for key, entry in skill['skills'].items():
            explicit_names = {v for row in excel_by_skill.get(key, []) for field in animation_fields
                for v in (row[field] if isinstance(row[field], list) else [row[field]]) if isinstance(v, str) and v}
            linked = {(c['bundlePath'], c['pathId']) for c in raw['clips']
                if c['name'] in explicit_names or any(s['state'] in explicit_names for s in c['motionStates'])}
            hashes = []
            for row in entry['logicRows'] + entry['logicEffectRows']:
                digest = row['source']['rowSha256']
                if digest not in row_cache:
                    events, omitted = row_markers(row)
                    row_cache[digest] = {'source': row['source'], 'status': row['status'], 'events': events, 'omitted': omitted}
                hashes.append(digest)
            if len(linked) == 1:
                target = by_id[next(iter(linked))]
                for digest in hashes:
                    target['events'].extend(row_cache[digest]['events'])
                durations = {r['dao']['Duration'] for r in entry['logicRows'] if isinstance(r.get('dao'), dict) and isinstance(r['dao'].get('Duration'), int)}
                if len(durations) == 1 and target['logicDurationFrames'] is None:
                    target['logicDurationFrames'] = next(iter(durations))
                mapped_skills.append(key)
            else:
                unmapped_skills[key] = {'rowShas': hashes, 'reason': 'SkillExcel has no explicit animation/state field' if not animation_fields else 'no unique exact clip/state match'}
        payload = {'characterId': cid, 'kind': raw['kind'], 'devName': raw['devName'],
            'names': {'ko': name.get('name_kr', ''), 'ja': name.get('name_jp', '')},
            'clientVersionId': VERSION,
            'sourceHashes': {'excelDb': raw['sourceHashes']['excelDbSha256'],
                             'excelZip': raw['sourceHashes']['excelZipSha256'],
                             'bundles': raw['sourceHashes']['bundles']}, 'clips': clips}
        errors = [str(e.message) for e in validator.iter_errors(payload)]
        record = {'characterId': cid, 'kind': raw['kind'], 'clipCount': len(clips), 'mappedSkills': mapped_skills,
            'unmappedSkills': unmapped_skills, 'schemaValid': not errors}
        if errors:
            invalid.append({'characterId': cid, 'errors': errors, 'excluded': True})
        else:
            out = args.out_dir / f'{cid}.json'
            write_new(out, payload)
            rec = file_record(out)
            files.append(rec)
            record.update(file=out.name, sha256=rec['sha256'], bytes=rec['bytes'])
            counters['clips'] += len(clips)
            counters['animationEvents'] += sum(e['layer'] == 'anim_event' for c in clips for e in c['events'])
            counters['linkedLogicEvents'] += sum(e['layer'] == 'logic_effect' for c in clips for e in c['events'])
        characters.append(record)
        if n % 1000 == 0:
            print({'processedCharacters': n, 'validFiles': len(files)}, flush=True)
    index = {'schema': 'ba-planner.animation-spectrum-index.v1', 'clientVersionId': VERSION,
        'contract': file_record(schema_path), 'fixture': file_record(ROOT/'contracts/fixtures/animation-spectrum/binah-sample.json'),
        'inputs': [file_record(args.skill_dir/'index.json'), file_record(args.animation_dir/'index.json'), file_record(skill_excel_path), file_record(localize_path)],
        'tool': file_record(Path(__file__)), 'animationLinkFields': animation_fields,
        'rules': ['Only exact SkillExcel animation/state names plus A1-b motion-state mappings may bind skills to clips',
            'No slot-order/skill-name similarity binding; unlinked markers retained here by original row SHA',
            'Raw local logic clocks preserved, never summed into a guessed arrival time',
            'Contract inference flag overrides conflicting task estimated=false for PlayAudio/*InstantiateFx semantic labels'],
        'characters': characters, 'files': files, 'invalid': invalid,
        'unlinkedLogicRowsBySha': row_cache, 'validFileCount': len(files), 'invalidExcludedCount': len(invalid),
        'counts': dict(counters), 'unmappedSkillOccurrences': sum(len(c['unmappedSkills']) for c in characters),
        'totalPayloadBytes': sum(r['bytes'] for r in files), 'elapsedSeconds': time.perf_counter() - started,
        'limits': ['Current SkillExcel contains no permitted animation/state binding fields',
            'Enemy/metadata_missing kind is not expressible by immutable student|boss contract; excluded in invalid',
            'Mika releases retained as unlinked logic markers; clip placement NOT_VERIFIED',
            'Spine unread [?]; no flight-time guess; no runtime/store/network changes']}
    write_new(args.out_dir / 'index.json', index)
    write_new(args.receipt, {k: index[k] for k in ('validFileCount', 'invalidExcludedCount', 'counts',
        'unmappedSkillOccurrences', 'animationLinkFields', 'totalPayloadBytes', 'elapsedSeconds')})
    print(load(args.receipt), flush=True)


if __name__ == '__main__':
    main()
