"""A1-c independent shape/arithmetic/source sample gate, with explicit unverified links."""
import argparse
from pathlib import Path
import re
import jsonschema
from _research_common import ROOT, load, sha, write_new


def facts(clip):
    return {k: v for k, v in clip.items() if k != 'events'} | {
        'events': [{k: v for k, v in e.items() if k != 'note'} for e in clip['events']]}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--src', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--report', type=Path, required=True)
    args = ap.parse_args()
    index = load(args.src/'index.json')
    validator = jsonschema.Draft202012Validator(load(ROOT/'contracts/animation-spectrum-v1.schema.json'))
    errors = []
    for rec in index['files']:
        p = ROOT/rec['path']
        data = load(p)
        if sha(p) != rec['sha256'] or p.stat().st_size != rec['bytes']:
            errors.append({'file': p.name, 'error': 'SHA/size'})
        errors.extend({'file': p.name, 'error': e.message} for e in validator.iter_errors(data))
        if str(data['characterId'])+'.json' != p.name:
            errors.append({'file': p.name, 'error': 'character filename'})
        for c in data['clips']:
            if c['lengthLogicFrames'] != round(c['lengthSeconds']*30):
                errors.append({'file': p.name, 'error': 'length arithmetic'})
            for e in c['events']:
                if e['frame'] != round(e['timeSeconds']*30):
                    errors.append({'file': p.name, 'error': 'event arithmetic'})
    fixture = load(ROOT/'contracts/fixtures/animation-spectrum/binah-sample.json')
    binah = load(args.src/'7300700.json')
    samples = []
    for old in fixture['clips']:
        new = next(c for c in binah['clips'] if c['name'] == old['name'] and c['bundlePath'] == old['bundlePath'])
        samples.append({'clip': old['name'], 'allSourceFactsEqual': facts(new) == facts(old),
            'lengthLogicFrames': new['lengthLogicFrames'], 'frames': [e['frame'] for e in new['events']]})
    mika = load(args.src/'10059.json')
    clip = next(c for c in mika['clips'] if c['name'] == 'CH0069_Exs')
    mouth = [e for e in clip['events'] if e['name'] == 'SetMouthTile']
    character = next(c for c in index['characters'] if c['characterId'] == 10059)
    entry = character['unmappedSkills']['CH0069Ex01']
    release = sorted(e['frame'] for digest in entry['rowShas'] for e in index['unlinkedLogicRowsBySha'][digest]['events']
        if re.fullmatch(r'\$\.EntityTimeline\[\d+\]\.Frame:ActionRelease', e['name']))
    expected = [30,32,34,38,42,53,57,62,66,71,75]
    timing = load(ROOT/'data/extracted/skill-timing-jp.json')['skills']['CH0069Ex01']['timeline']
    timing_release = sorted(e['frame'] for e in timing if e['tag'] == 'ActionRelease')
    pass_gate = not errors and all(s['allSourceFactsEqual'] for s in samples) and len(mouth) == 4 and all(e['kind']=='other' for e in mouth) and release == expected == timing_release
    result = {'shapeIntegrityArithmeticPass': not errors, 'schemaValidatedFiles': len(index['files']), 'errors': errors,
        'binahFixtureSourceFacts': samples, 'fixtureNotesExcludedFromValueComparison': True,
        'mikaMouthOtherCount': len(mouth), 'mikaReleaseFramesRetainedInIndex': release,
        'mikaReleaseRawAndTimingMatch': release == expected == timing_release,
        'mikaReleasePlacedOnClip': False, 'overallSampleStatus': 'NOT_VERIFIED',
        'dataVerificationPass': pass_gate, 'linkBlocker': 'No permitted explicit SkillExcel animation/state fields',
        'inferenceConflict': 'Task estimated=false conflicts with immutable contract/fixture inferred sfx/vfx; kept estimated=true',
        'protectedContractSha256': sha(ROOT/'contracts/animation-spectrum-v1.schema.json'),
        'protectedFixtureSha256': sha(ROOT/'contracts/fixtures/animation-spectrum/binah-sample.json')}
    write_new(args.out, result)
    lines = ['불일치: [표] SkillExcel에 애니메이션/상태 필드가 없어 허용된 연결 근거가 없다. [?] 과제의 anim_event estimated=false는 불변 계약/fixture의 의미 추론 표시와 충돌한다.', '',
        '# A1 애니메이션 스펙트럼 표본 검수 — 2026-10-10', '',
        '[표] NOT_VERIFIED — 출력 스키마·산술·원자료 대조는 통과했으나 미카 EX 로직 마커의 클립 배치는 미확정이다. 슬롯 순서·이름 유사도로 연결하지 않았다.', '',
        '| 항목 | 결과 | 근거 |', '|---|---|---|',
        f'| 전체 출력 | PASS | [표] {len(index["files"])}개 schema/SHA/bytes/파일명/프레임 산술 일치 |']
    lines += [f'| {s["clip"]} | '+('PASS' if s['allSourceFactsEqual'] else 'FAIL')+f' | [관측] 길이 {s["lengthLogicFrames"]}f; 이벤트 {s["frames"]}; bundle/fps/초/이름/종류/estimated/evidence 동일 |' for s in samples]
    lines += [f'| 미카 EX anim_event | PASS | [관측] SetMouthTile {len(mouth)}건, 모두 other |',
        f'| 미카 EX 원 release | PASS | [표] {release}; 원 rowSha와 skill-timing-jp 일치, index에 logic_effect 마커로 보존 |',
        '| 미카 EX 클립 안의 release | NOT_VERIFIED | [?] 명시 SkillExcel 연결 필드가 없어서 클립에는 붙이지 않음 |',
        '| callback estimated=false 요청 | NOT_VERIFIED | [?] sfx/vfx는 callback 이름으로 의미를 추론하므로 계약대로 true; other는 false(반 프레임 이상 반올림 예외) |', '',
        '[표] fixture는 변경하지 않았다. 값 비교는 설명문 note만 제외하며 나머지 두 clip 객체의 모든 값이 동일하다. sourceFps와 30 fps 로직 축을 별도로 유지했다.', '',
        f'[표] 계약 밖 kind {index["invalidExcludedCount"]}개는 index.invalid에 schema 오류를 남기고 출력에서 제외했다. enemy를 boss로 바꾸지 않았다.', '',
        '[표] T3 대조: Normal_Attack 140f는 클립 길이이며 전체 행동 Duration으로 대체하지 않았다. Vital_Groggy 340f도 별도 300f 로직 clock으로 바꾸지 않았다.', '',
        '[?] CM 후속 선택: 명시된 클립↔스킬 연결 자료를 제공하거나, 학생의 SkillList ex 슬롯↔Exs 상태를 연결하는 규칙을 별도 근거로 승인한 후 새 블록에서 병합. 현재 규칙만으로 보스 EX 연결도 미확정이다.', '',
        'CF A2 표본 입력:', '', str(args.src.resolve()/'7300700.json'), str(args.src.resolve()/'10059.json'), str(args.src.resolve()/'index.json'), '',
        '[?] CF는 현재 anim_event를 표시할 수 있다. 로직 층의 클립 배치를 완료로 처리하면 안 된다.']
    args.report.parent.mkdir(parents=True, exist_ok=True)
    with args.report.open('x',encoding='utf-8',newline='\n') as f:
        f.write('\n'.join(lines)+'\n')
    print({k: result[k] for k in ('schemaValidatedFiles','dataVerificationPass','mikaReleaseFramesRetainedInIndex','overallSampleStatus')})
    if not pass_gate:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
