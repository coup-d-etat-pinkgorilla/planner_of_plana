"""Build W4 evidence from already-generated rows; no table re-extraction."""
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[3]
A = Path(__file__).resolve().parent
EVIDENCE = ROOT / 'docs/tactic-editor/evidence/favor-cafe-tables-jp-1.73.0.json'


def read(p):
    return json.loads(p.read_text(encoding='utf-8'))


def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def row_sha(rows):
    return hashlib.sha256(json.dumps(rows, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def new(p, obj):
    with p.open('x', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.write('\n')


def main():
    if EVIDENCE.exists():
        raise SystemExit('preserve prior evidence')
    tables = {}
    for name in ['FavorLevelExcel', 'CafeInteractionExcel']:
        path = ROOT / 'data/extracted/jp-json' / (name + '.json')
        rows = read(path)['data_list']
        tables[name] = {'jsonFile': path.relative_to(ROOT).as_posix(), 'rowCount': len(rows),
                        'size': path.stat().st_size, 'jsonFileSha256': digest(path),
                        'rowsSha256': row_sha(rows), 'allFieldsPreserved': True, 'rows': rows}
    frows, crows = tables['FavorLevelExcel']['rows'], tables['CafeInteractionExcel']['rows']
    chars_path = ROOT / 'data/extracted/jp-json/CharacterExcel.json'
    chars = read(chars_path)['data_list']
    by_id = {r['id']: r for r in chars}
    distribution = lambda rows: dict(sorted(Counter(str(r.get('favor_levelup_type', 'MISSING')) for r in rows).items()))
    cafe_chars = [by_id[r['character_id']] for r in crows if r['character_id'] in by_id]
    static = read(A / 'jp-static-field-inventory-v2.json')
    native = read(A / 'cooltime-native-resolution.json')
    const = read(A / 'ConstCommonExcel.candidate-fields.json')
    preservation = read(A / 'prior-json-preservation.json')
    dependencies = read(A / 'local-decoder-dependencies.json')
    sys.path.insert(0, str(ROOT / 'data/extracted/pipeline'))
    from il2cpp_meta import Il2Cpp
    p = Il2Cpp('C:/YostarGames/BlueArchive_JP/GameAssembly.dll', 'C:/YostarGames/BlueArchive_JP/BlueArchive_Data/il2cpp_data/Metadata/global-metadata.dat')
    vector_methods = [dict(m, returnTypeName=p.tname(m['returnType'])) for m in p.method_addresses('MX.Data.Excel.FavorLevelExcel') if m['name'] in ['ExpType', 'get_ExpTypeLength', 'get_Level']]
    assert next(m for m in vector_methods if m['name'] == 'ExpType')['returnTypeName'] == 'long'
    levels = [r['level'] for r in frows]
    vector_lengths = Counter(len(r['exp_type']) for r in frows)
    values = [r['exp_type'][0] for r in frows]
    favor_analysis = {
        'status': 'undetermined', 'conclusion': '해석 미확정 + 후보 2개. Level은 행의 랭크 축이고 ExpType은 long 벡터(현재 길이 1)이다. 랭크별 필요 경험치 후보가 더 잘 맞지만 누적 여부·레벨 경계·그룹 인덱스 변환은 실행 소비자 근거 없이 확정하지 않는다.',
        'candidates': [
            {'id': 'per-level-required-exp', 'tag': '[?]', 'meaning': '각 Level 행의 exp_type 원소는 랭크 한 단계에 필요한 경험치', 'support': '양수·비감소·초기 동일값 반복은 필요 경험치 곡선과 양립', 'unresolved': 'Level L이 L→L+1인지 L-1→L인지; FavorLevelupType 1이 원소 0으로 변환되는지 미검증'},
            {'id': 'cumulative-threshold', 'tag': '[?]', 'meaning': '각 Level 행의 exp_type 원소는 누적 경험치 임계값', 'support': '비감소 수열이라는 사실만으로 누적을 배제할 수는 없음', 'limitation': 'Level 2/3=30, 4/5/6=35, 7/8/9=40으로 같은 임계값의 여러 랭크가 생긴다. 실행 소비자와 0비용 단계 의미 미확인'}],
        'facts': [
            {'tag': '[코드]', 'fact': 'JP native schema: FavorLevelExcel.Level long, ExpTypeLength int, ExpType(index) returns long', 'methods': vector_methods},
            {'tag': '[표]', 'fact': '100 distinct contiguous Level rows 1..100, every vector length 1; positive, nondecreasing, not strictly increasing', 'rowCount': len(frows), 'levelMin': min(levels), 'levelMax': max(levels), 'uniqueLevels': len(set(levels)), 'contiguousLevels': levels == list(range(1, 101)), 'vectorLengthDistribution': dict(vector_lengths), 'nondecreasing': all(a <= b for a, b in zip(values, values[1:])), 'strictlyIncreasing': all(a < b for a, b in zip(values, values[1:])), 'firstTenValues': values[:10], 'lastValue': values[-1], 'cumulativeValuesWereNotGenerated': True},
            {'tag': '[코드]', 'fact': 'Full metadata field/property scan found CharacterExcel.FavorLevelupType int; no separate FavorExpType/FavorLevelType enum or a second matching group selector', 'matchingMembers': static['favorReferenceFields']},
            {'tag': '[표]', 'fact': 'Read existing CharacterExcel; no re-extraction', 'file': chars_path.relative_to(ROOT).as_posix(), 'jsonFileSha256': digest(chars_path), 'rowCount': len(chars), 'allRowsDistribution': distribution(chars), 'isPlayableRows': sum(bool(r.get('is_playable')) for r in chars), 'isPlayableDistribution': distribution([r for r in chars if r.get('is_playable')]), 'cafeRowsMatched': len(cafe_chars), 'cafeRowsUnmatched': len(crows) - len(cafe_chars), 'cafeCharacterDistribution': distribution(cafe_chars)},
            {'tag': '[?]', 'fact': 'Level rows provide the rank axis. ExpType vector columns can represent a progression group, but with length 1 and FavorLevelupType values 0/1 the native index transformation is not grounded. Do not index the vector with raw FavorLevelupType.'}],
        'publicWikiUsed': False}
    new(A / 'favor-structure-analysis.json', favor_analysis)
    reward_tuples = Counter((r['favor_emoticon_reward_parcel_type'], r['favor_emoticon_reward_id'], r['favor_emoticon_reward_amount']) for r in crows)
    parcel = next(t for t in static['relevantTypes'] if t['name'] == 'FlatData.ParcelType')
    parcel11 = [f for f in parcel['fields'] if f['constant'] == 11]
    assert len(parcel11) == 1 and parcel11[0]['name'] == 'FavorExp'
    dis_path = A / 'dis/MX.GameLogic.Service.CafeService.get_InteractCooltime.txt'
    tool_path = ROOT / 'data/extracted/pipeline/extract_jp.py'
    tool_sha = digest(tool_path)
    interaction = {
        'reward': {'tag': '[표]+[코드]', 'uniform': len(reward_tuples) == 1, 'tuples': [{'parcelType': t, 'parcelTypeName': 'FavorExp', 'id': i, 'amount': v, 'rowCount': n} for (t, i, v), n in reward_tuples.items()], 'enum': {'type': 'FlatData.ParcelType', 'member': 'FavorExp', 'constant': 11}},
        'constSearch': {'tag': '[표]', 'sqlConstCommonPresent': False, 'constCafeTypePresent': False, 'source': const, 'candidateMembers': static['constCandidateFields'],
                        'countOrInteractCooldownFoundInTable': False, 'units': {'CafeMonologueIntervalMillisec': 'milliseconds by field-name candidate; monologue, not interaction', 'CafeBubbleIdleDurationMilliSec': 'milliseconds by field-name candidate; bubble', 'CafeAutoChargePeriodInMsc': 'milliseconds by field-name candidate; production autocharge', 'CafeSummonCoolTimeFromHour': 'hours by field-name candidate; summon, not interaction', 'CafeTravelSyncIntervalByMillisec': 'milliseconds by field-name candidate; travel sync'},
                        'note': 'Enumerated all matching Const Excel fields/properties; unrelated Arena/Combat names are metadata labels only. No Steam/Viewer/Arena source access.'},
        'cooldown': {'status': 'client-getter-grounded', 'tag': '[코드]', 'clientGetterHours': 3.0, 'symbol': 'MX.GameLogic.Service.CafeService.get_InteractCooltime', 'rva': '0x1338160', 'va': '0x181338160', 'bound': 'exact PE unwind 0x181338160..0x1813381a8', 'instructionCount': 14, 'loadInstruction': '0x181338195 movsd xmm0, qword ptr [rip + 0x601938b]', 'literal': native['literal'], 'tailcall': native['tailcall'], 'nativeTargetSymbol': 'System.TimeSpan.FromHours', 'disFile': dis_path.relative_to(ROOT).as_posix(), 'disFileSha256': digest(dis_path), 'disText': dis_path.read_text(encoding='utf-8'), 'scope': 'Pinned JP client getter returns 3 hours. CanInteract caller, server enforcement, visit/reset interaction, and daily maximum were not traced.'},
        'availableCount': {'status': 'unconfirmed', 'tag': '[?]', 'value': None, 'conclusion': '미확인. 표에서 쓰다듬기 가능 횟수를 찾지 못했고 1함수 라운드를 간격 getter에 사용했다. 24/3 등으로 하루 횟수를 만들어 내지 않는다.'},
        'disassemblyFunctionCount': 1, 'disassemblyRounds': 1, 'additionalRound': False}
    payload = {
        'schema': 'ba-planner.favor-cafe-tables.v1', 'status': 'extracted-with-exp-type-uncertainty',
        'server': 'japan', 'clientVersion': '1.73.0', 'versionId': 'jp-1.73.0-e2baf70e',
        'source': 'Pinned local JP ExcelDB.db; additional ConstCommon scalar candidates from same-build Excel.zip',
        'sourceSha256': 'a5cfbbb9c7f00ccdd82a59e100febb7ed5eb107bc8ac93c6ed0dede14418416a',
        'gameAssemblySha256': static['hashes']['GameAssembly.dll'], 'metadataSha256': static['hashes']['global-metadata.dat'],
        'createdUtc': datetime.now(timezone.utc).isoformat(timespec='seconds'),
        'decoder': {'tool': 'v7 extract_jp.py@' + tool_sha[:8], 'extractJpSha256': tool_sha, 'tableOnlyOverride': ['FavorLevelExcel', 'CafeInteractionExcel'], 'dependencies': dependencies, 'rowHashRule': 'UTF-8 json.dumps(rows, ensure_ascii=False, sort_keys=True, separators=(comma,colon))'},
        'tables': tables, 'expTypeAnalysis': favor_analysis, 'cafeInteraction': interaction,
        'staticInventory': {'typeCount': static['typeCount'], 'fieldsExamined': static['fieldsExamined'], 'propertiesExamined': static['propertiesExamined'], 'matchingFavorMembers': len(static['favorReferenceFields']), 'matchingConstMembers': len(static['constCandidateFields']), 'cafeInteractionTypesWithMethodAddresses': len(static['cafeMethodNameInventory']), 'file': (A / 'jp-static-field-inventory-v2.json').relative_to(ROOT).as_posix(), 'sha256': digest(A / 'jp-static-field-inventory-v2.json'), 'steamTypesNotUsed': True},
        'preservation': preservation,
        'execution': {'allPageHmacVerified': True, 'verifiedPageCount': 218644480 // 4096, 'decryptionPassCount': 1, 'newTablesDecodedBeforePublicationOnly': True, 'existingTablesReextracted': False, 'temporaryPlaintextRemoved': True, 'initialAttempt': 'Completed HMAC/decode into temporary output, then ConstCommon absent from SQL catalog. No canonical outputs published. Resumed that completed plaintext, read ConstCommon via pinned JP Excel.zip, published new JSONs, removed plaintext and task temp directory.', 'finalization': 'Temporary-directory nonempty cleanup failed after successful publication; leftover new-table temporary JSON hash matched published bytes, then exact task-owned file/directory removed. Existing outputs were verified against frozen lock/CCL hashes.', 'networkCalls': 0, 'gameRuntimeExecutions': 0, 'keyDisclosures': 0, 'keyCopies': 0, 'originalClientFileCopies': 0, 'sharedStoreWrites': 0},
        'frontendReadPaths': [tables[n]['jsonFile'] for n in tables] + ['docs/tactic-editor/evidence/favor-cafe-tables-jp-1.73.0.json'],
        'clientDataStore': {'kind': 'favor-cafe-tables', 'importStatus': 'MASTER_REQUIRED', 'lockUpdated': False},
        'wholePython': {'status': 'MASTER_REQUIRED', 'command': 'cd backend; py -3.11 -m unittest discover -s tests -v'},
        'commit': {'status': 'MASTER_REQUIRED', 'messageMustContain': 'frontend request 2026-10-08 02:45'}}
    new(EVIDENCE, payload)
    shutil.copyfile(EVIDENCE, A / EVIDENCE.name)
    shutil.copyfile(tool_path, A / 'extract_jp.py')
    new(A / 'extraction-verification.json', {'rowCounts': {n: t['rowCount'] for n, t in tables.items()}, 'priorFileCount': preservation['count'], 'priorBytesPreserved': preservation['allMatch'], 'execution': payload['execution'], 'toolSha256': tool_sha, 'evidenceSha256': digest(EVIDENCE)})
    print(json.dumps({'tables': {n: {k: v for k, v in t.items() if k != 'rows'} for n, t in tables.items()}, 'expTypeStatus': favor_analysis['status'], 'cooldownHours': 3, 'availableCount': 'unconfirmed', 'evidenceSize': EVIDENCE.stat().st_size, 'evidenceSha256': digest(EVIDENCE), 'toolSha256': tool_sha}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
