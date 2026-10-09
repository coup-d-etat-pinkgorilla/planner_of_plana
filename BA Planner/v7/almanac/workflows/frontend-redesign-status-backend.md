---
title: "Frontend Redesign Backend Status"
summary: "FB-2a 확정 이력·journal·최소 summary와 승인된 FB-2 조사, FB-8a/b authoring 및 Lane A 백엔드 기록입니다."
topics: [workflow, design]
sources:
  - id: workflow
    type: file
    path: almanac/workflows/frontend-redesign-workflow.md
  - id: student-contract
    type: file
    path: contracts/planning-student-calculate-v1.schema.json
  - id: student-tests
    type: file
    path: backend/tests/test_student_calculation_fb11a.py
---
백엔드 워커 전용(Lane A 병렬, 2026-10-07)

# FB-2a 이력 저장 기반

## 착수 (2026-10-09)

- 시작 SHA: `7965e4620d7f05e7b522af250462eb274bdb10f3`. FE4-i 및 redesigndocs 이후 HEAD.
- AGENTS·README/runtime 경계 → workflow FB-2·FB-3 설계 승인 → 프론트/전술 오케스트레이터 23:25 → 아래 FB-2 조사 전체를 읽었다. 승인 결정 1~7을 기준으로 구현하며 조사 절은 그대로 둔다.
- profile 안 optional current_history v1, manual/import/new/legacy·prefix 정리·공용 journal 및 최소 summary를 구현한다. 스캐너 호출은 바꾸지 않고 수신 port만 만든다. 삭제 journal은 FB-2d로 남긴다.
- 공유 서비스 pre/post를 남긴다. 관련 Python·Dart 서비스·process만 직접 실행하고 전체 Python·gate·stage·커밋·push는 하지 않는다.

## 종료 (2026-10-10, 사용자 검증 대기)

### 계약·정책 요약

| 항목 | FB-2a 결과 |
|---|---|
| 저장 | profile v1의 optional `current_history` v1. strict Python CurrentHistory/ScanHistoryContext, 새 schema, strict Dart RepositoryCurrentHistory·presence/change/event·summary DTO. state.get 기존 5키 응답은 그대로 |
| 8키 | version, next_sequence, baseline, events, total_counts, last_applied_at, scan_session_ids, latest_scans. baseline은 sequence/recorded_at/origin/students/inventory |
| diff | 학생 한 명의 confirmed record 전체 before/after + present(value). values 안 missing/null, form 객체, optional provenance까지 유지. inventory는 canonical_resource_key(item_id or key)의 present/quantity. missing·unknown null·문자열 0·삭제·큰 수량을 구별. 배열 순서/이름/ordinal 변경은 성장·수량 diff가 아님 |
| 시각 | backend aware UTC clock, 소수초 6자리 Z. cache/revision 검증 뒤 읽는다. prepared 실패의 시각은 남지 않고 committed response replay·복구는 원래 시각. 같은 시각은 sequence로 정렬, clock 역행은 보정하지 않고 coverage.timestamps_monotonic=false |
| 출처 | public repository.students.update/inventory.update는 manual. import는 성공 적용 시각 seed 1건(0→0), scan 회수 제외. 신규 empty baseline/0건, legacy는 첫 current 쓰기 직전 실제값을 시각 미상 legacy baseline |
| 미연결 스캐너 | old 4인자 내부 update 호출은 **unattributed**. scan/manual/import로 잘못 분류하지 않고 current 복원을 유지한다. 사용자 프롬프트 4의 허용 대안이며 23:25 source 3종 결정에 대한 임시 호환 항목이다. scan port가 연결된 새 적용부터 scan으로 기록; 옛 unattributed를 과거 scan으로 바꾸지 않음 |
| 표시·저장 단위 | raw source별 lifetime/retained commit count와 total/retained **scan_session_count**를 분리. 같은 session_id의 여러 commit은 표시 1회. lifetime session ID 집합을 prefix 정리 뒤에도 보존하여 재등장 세션을 두 번 세지 않음 |
| 보존 | 365일 / 10,000건 / canonical UTF-8 16 MiB 중 먼저. 오래된 연속 prefix만 baseline으로 접음. 최신 적용 1건·latest_scans·누적 count·last_applied_at·session ID 유지. baseline/index와 최신 1건도 못 넣으면 invalid_payload reason=history_capacity_exceeded, current/revision/cache 모두 이전 값. GET prune 없음 |
| revision·journal | current/event/cache/profile revision+1/catalog을 공용 write_transaction에 함께 저장. create/import도 같은 journal. root OS guard → marker → 복구 → profile/catalog; prepared=이전 전체, committed=이후 전체. plan 첫 이관/save/replace/goals/profile 메타는 history 보존만 |
| 삭제 | inline history는 profile과 함께 지워짐. 전술 v1/v2·lock을 포함한 **삭제 journal은 FB-2d**, 이번에 삭제 코드 변경/원자성 완료 선언 없음 |
| 최소 조회 | repository.history.summary {profile_ids:1..128 unique IDs} → profiles별 revision/history_sequence, last_manual_at/last_import_at, total/retained_event_count, source별 total/retained_counts, total/retained_scan_session_count, coverage(origin/baseline_sequence/baseline_at/first_retained_at/complete/timestamps_monotonic) |
| 캐시 | context 없는 옛 operation fingerprint와 {revision} cache 유지. replay가 clock·history 호환·revision 검증보다 먼저. explicit context는 fingerprint에 포함, 다른 context/key 재사용은 idempotency_conflict. v6 import는 기존처럼 key 없는 새 profile 생성 API이며 재호출이 새 profile을 만드는 기존 의미를 바꾸지 않음; journal 복구는 이미 생성된 seed의 시각을 보존 |
| 손상 | 새 중복 학생 입력/import는 invalid_payload reason=duplicate_identity. 기존 중복/손상 history는 corrupt_data, supported-shape의 unknown history version은 migration_required. 빈 history로 대체하지 않음 |

**중복 경로 선조사 결과:** v6 `_students`는 서로 다른 JSON map key의 raw.student_id가 같으면 2명을 append할 수 있다. 기존 direct update도 중복 배열을 받아 저장할 수 있었다. scan 학생 commit은 target ID의 기존 항목을 모두 지우고 1명을 append하여 해당 target의 중복은 만들지 않지만, 다른 학생의 중복은 전체 배열에 남길 수 있었다. 실제 읽은 v7 10개 profile(각 학생 217명)과 v6 1개 account에는 중복이 없었다. 변환 시 조용한 last-wins/합산으로 원래값을 지울 근거가 없으므로 기존 파일은 explicit corrupt_data guard로 읽기를 막고 파일/원본의 명시 정리를 요구한다. 실제 사용자 profile/v6 원본은 수정하지 않았다. fixture로 가능한 v6 중복 경로와 저장 파일의 거부·바이트 보존을 고정했다.

**Mock 경계:** manual 저장은 strict helper와 공용 plan/current cache를 사용한다. 옛 Mock scanner commit이 current map에 직접 쓰는 블록을 바꾸지 않고, repository map observer가 교체한 bucket을 unattributed로 함께 기록한다(메타·계획 쓰기는 같은 current bucket 참조를 유지하므로 event 없음). 같은 값 적용도 기록하며 다음 manual 쓰기의 복원 chain을 유지한다. scanner approved context/partial scope/upsert/replay는 FB-2b의 조율 대상이다. Mock v6 가져오기는 기존 UnsupportedError/빈 preview를 유지하며 import seed는 공용 DTO fixture와 실제 Process 경로에서 검증했다. ConfirmedStudentState는 검증했던 provenance를 이제 DTO/toWire에도 보존한다.

### fixture·실측

| 묶음 | 고정·검증 사례 |
|---|---|
| shared strict | current_history_v1: empty, missing/null/0/삭제/대수량, 학생 missing bond/form/provenance, 동값 scan 두 commit=한 session, compacted. unknown key/bool/nonbool presence/잘못된 missing 값/학생 bool/sequence gap/count 불일치/raw UTF-8 초과/중복 diff/끊긴 before/빈 scope/stale latest index/중복 baseline/date 오류. **17 policy + 4 protocol message** |
| 출처·호환 | new/legacy/public manual 두 bucket/import seed/contextless unattributed/explicit scan/부분 scope, scan enum 없는 raw text·null profile, scope 밖 diff 거부, metadata/plan/goals/first migration은 event 없음, 옛 cache replay와 재시작 원래 시각 |
| 정리 | count/365일 경계/bytes 각각 prefix 이동, baseline 재구성, 삭제된 key의 latest index와 누적 count 유지, legacy/compacted 불완전 coverage, 단독 capacity 오류의 이전 바이트 보존, clock 역행 |
| 원자성 | current/create/import 각각 7개 journal 경계 × Exception/프로세스 exit=42 subcase. profile/catalog 각각 before_write/fsync/replace 실패 6건, 복구 자체 중단 뒤 재복구. 공통 read가 먼저 복구, committed current 응답 replay는 clock 없이 최초 응답 |
| process | 새 current+동값+key replay→plan save→restart summary/DTO, legacy summary read(이관 없음)→첫 current→v6 import seed→restart. 기존 current 복원/FB-1b 계획 이관/FB-1c 보관/FB-8b authoring process 함께 회귀 |

실제 프로필 크기: 학생 217명·inventory 614항목, 기존 JSON 약 192,767~198,413 bytes. `backend/tests/fixtures/current_history_profile_shape.json`은 이 구조에서 계정 ID/이름·원래 수량·원래 학생값/provenance를 제거한 익명 fixture다. 보존 제한을 우회하는 작은 테스트 profile로만 측정하지 않았다.

| 실측(기본 상한) | bytes / 시간 |
|---|---:|
| import seed history | 212,947 bytes |
| 접힌 full current baseline | 125,163 bytes |
| legacy 전체 학생·inventory 변경 1건+baseline | 409,771 bytes |
| 같은 session의 동값 학생 scan 10,000 commits history | 4,452,539 bytes (10,000 보존, 표시 1회) |
| 위 append+strict 복원 검증 | 1.7465초 |
| 실제 journal을 통한 전체 학생 수정 후 profile / journal | 475,227 / 811,615 bytes |
| 위 durable 쓰기 | 0.0824초 |

16 MiB(16,777,216 bytes)에 여유가 있어 이 정상 크기의 full 적용이나 10,000 동값 학생 commit은 capacity 거부 없이 저장된다. 모든 값이 매번 바뀌는 큰 적용은 16 MiB 조건으로 더 일찍 prefix를 접는다. session/latest index도 byte budget에 포함하므로 누적 ID만으로 상한을 넘기는 비정상 장기/거대 입력 역시 명시 capacity 오류다. 원본 이름·수량을 commit fixture에 넣지 않았으며 숫자/처리 시간은 `debug/frontend_fb2a/size-measurement.json`에 있다.

### 직접 검증·인계

- Python 관련 **106 OK**: history 18, 기존 persistence/protocol/v6/FB-1b/FB-1c/FB-8a/FB-8b 및 planning schema contract. 결과 `debug/frontend_fb2a/python-targeted.txt`. 기존 FB-1b legacy setup 한 곳은 새 생성 history를 제거하여 이력 도입 전 파일을 정확히 구성한다. v6 원본/plan·scenario 계산 계약·stats current 경로는 변경 없음.
- Dart 관련 서비스 **192 OK**, process **6 OK**(새 2+기존 4). 결과 `dart-services.txt`, `dart-process.txt`; 지정 파일·--exclude-tags golden·concurrency=1만 실행. 지정 Dart analyze **0 issues**(`dart-analyze.txt`). golden 변화 예상 0.
- 공유 mock/process/planning_protocol_client pre/post, `debug/frontend_fb2a/commit.json` status=false, whole=본 문서(기존 FB-2 조사 그대로 포함), post_dir=`debug/frontend_fb2a/post`. client는 prefix 기반 repository validator를 이미 사용하여 코드 변경 없음. scanner 블록/pre WIP와 index 보존·3-way merge 검증은 handoff-verification.json에 남긴다.
- 전체 Python·fe_gate·stage·커밋·push는 실행하지 않았다. 사용자 전체 Python 결과 파일은 아직 없다.

사용자 PC 전체 Python(v7 root에서):

```powershell
Push-Location backend
try {
  py -3.11 -m unittest discover -s tests -v 2>&1 | Tee-Object -FilePath '..\debug\frontend_fb2a\python-full.txt'
  $fb2aPythonExit = $LASTEXITCODE
} finally { Pop-Location }
if ($fb2aPythonExit -ne 0) { throw 'FB-2a Python 전체 실패: python-full.txt 확인' }
```

사용자 실행 순서: **Python 전체 → 두 워커가 모두 멈춘 뒤 fe_gate → fe_commit -Slice fb2a → redesigndocs**. gate/커밋은 이 워커가 하지 않는다.

### FB-2b·FB-2c·프론트 연결 메모

| 대상 | 다음 연결 경계 |
|---|---|
| FB-2b | tactic log 23:25 대응 뒤, repository.update_students/update_inventory의 keyword history_context=ScanHistoryContext.from_wire(...)로 연결. source=scan, session/generation/candidate/revision, session.target의 raw kind/profile, 실제 승인 scope. 4인자 옛 경로는 계속 unattributed. 빈 승인 scope는 호출하지 않음. FD-147 동값도 적용 호출; candidate 제외 key는 scope 밖. 새 key/context fingerprint와 응답 유실 replay, Mock upsert/승인 scope/idempotency를 함께 맞출 것 |
| FB-2b summary | 이번 최소 응답에 last_scan_at, raw tuple last_scans, item/student latest 시각을 추가. latest_scans와 scan_session_ids를 사용하며 session 수를 원시 commit 수로 바꾸지 않음. FE8-c 계정 메타는 **student 행**. unattributed/manual/import timestamp를 마지막 scan으로 대체하지 않음 |
| FB-2c | baseline+whole student/resource present diff의 apply_event를 재사용. 기간·events/diff·cursor/filter와 session 마지막 적용점 묶음. prefix 이전 coverage 불완전, deleted key/unknown quantity/clock 역행을 0으로 만들지 않음. manual/import/unattributed도 실제 상태 복원에는 포함하지만 scan 점/회수에는 제외 |
| FE6-f / FE7-h | 원시 commit count는 진단용, 스냅샷/추세/A6는 scan session 수. 기간 KPI/스파크라인은 FB-2c 후 연결; 지금 최소 summary로 과거 delta를 합성하지 않음. 현재 statistics.snapshot_count의 inventory-entry 의미를 바꾸지 않음 |
| FE8-c / FE8-g1 | 마지막 수동 수정/가져오기는 최소 summary로 별도 의미 표시 가능. 계정 학생 scan 시각·종류별 막대는 FB-2b 뒤; 앱 실행 중 최근 8 session 기록(FD-149)은 영속 성공 이력으로 대체하지 않음 |
| Dart 호출 | RepositoryService.loadRepositoryHistorySummary(profileIds) → result.profiles의 typed DTO. 요청당 1..128 unique IDs. unknown/unrecorded는 last 시각 null, coverage.complete=false. UTC→local 표시는 프론트 담당. state.get/현재값 저장 요청·{revision} 반환 사용법은 동일 |
| FB-2d | 전술 v1/v2 삭제 대상·공용 guard·고정 lock 순서 회신 후 별도 프롬프트로 착수 |

**여기서 멈춘다.** 구현·직접 검증을 마쳤고 사용자 전체 Python/gate 및 오케스트레이터 확인을 기다린다. FB-2b/c/d는 다음 프롬프트를 받은 뒤 시작한다.

# FB-2 읽기 전용 설계 조사

## 조사 기준·결론 (2026-10-09)

- 조사 HEAD: `df547db746534def4316e24b3b983a689f1ada56`. AGENTS → README/runtime 경계 → workflow의 FB-2·FB-3, FE6-f·FE7-h·FE8-c·FE8-g1 및 스캐너 변동 대응 → orchestrator 22:10 → FD-041·FD-147과 연결된 inventory-catalog-order, 시안 조사 E/F/I, FD-042·FD-096·FD-144·FD-146·FD-149를 읽었다. 앞당긴 것은 **조사만**이며 구현 승인은 아직 없다. 기존 FB-8 조사 형식을 참고했다.
- **현재 확정 저장은 시각·적용 source를 갖고 있지 않다.** scanner candidate의 evidence/provenance, 인식 정답 샘플의 confirmed_at, UI의 idempotency key, 파일 mtime을 스캔 커밋 시각으로 바꾸어 읽을 수 없다.
- 권장안: 확정 profile 옆 별도 파일 대신 **같은 profile JSON에 optional `current_history` v1**을 둔다. 이력은 학생·인벤토리 확정 상태와 같은 transaction에 넣고, 계산/목표/계획/정적 메타와 분리한다. baseline + 적용별 diff + 적용 대상 scope + 보존 기간을 넘어 유지할 최신 scan index가 필요하다.
- FD-041의 단위는 저장/승인 **commit 1회 = 이력 1건**이다. manual도 남기되 `스냅샷 n회`와 `지난 스캔` 기준은 source=scan만 센다. FD-147 때문에 diff=[]인 승인도 scope와 시각을 남긴다. 시작·인식·review·취소·완료만으로는 scan 시각을 갱신하지 않는다.
- 아래 이름·상한·분할·오류 reason은 **승인 전 계약 초안**이다. 코드·계약·테스트는 바꾸거나 실행하지 않았고, gate·stage·커밋·push와 commit.json 생성도 하지 않았다. 이 절은 다음 백엔드 commit의 본 문서 whole에 함께 넣는다.

## 1. 현재 저장 경로와 가진 시각·source

| 경로 | 실제 확정 쓰기·revision | 지금 있는 정보 / 없는 정보 | FB-2 처리 제안 |
|---|---|---|---|
| scanner 학생 승인 | `ScannerSessionService.commit`가 get_state 후 candidate 학생을 교체한 전체 배열로 `JsonRepository.update_students` 호출. profile/catalog revision +1 | session_id/generation/candidate_id/candidate_revision/scan_kind는 세션에 있음. 학생 values와 field별 provenance는 저장 가능. 적용 시각·scan source는 repository로 전달되지 않음 | scanner가 서버 내부 context와 승인 student ID를 함께 넘겨 source=scan으로 1건 |
| scanner 인벤토리 승인 | commit가 `_merged_inventory`로 읽은 key만 upsert한 전체 snapshot을 `update_inventory`에 전달. 읽지 않은 key는 보존. revision +1 | session.target의 inventory_scan_profile, payload의 catalog_revision, entry의 observed_slot가 있음. scanner-only entry inventory_scan_profile은 DTO 변환 전에 제거. 확정 entry.profile_id는 **현재 catalog 정렬 프로필** | 원래 scan profile + 실제 승인 resource keys를 별도 context로 전달. 전체 저장 snapshot의 모든 key를 스캔했다고 보지 않음 |
| 학생/인벤토리 화면의 candidate 적용 | student_page `_approveCandidate`, inventory_page `_approveCandidate`, scan_page `_applyStudentCandidate`가 review→scanner commit 호출 | review reason·field evidence·audit는 세션 정보. 화면에서 고쳐 승인해도 확정 저장 경계는 scan commit | source=scan 유지. 수동 보정의 field provenance와 저장 적용 source는 서로 다른 의미 |
| 직접 학생 저장 API | `repository.students.update` → Process `saveRepositoryStudents` → update_students. **전체 교체**, 삭제도 가능. revision +1 | canonical values/optional provenance, expected_revision/key만. 독립 학생 화면의 직접 save 호출은 현재 검색되지 않았고 API·서비스·tests의 호출은 있음 | source=manual. before/after 전체 상태로 학생 추가·삭제·field diff 계산 |
| 인벤토리 수량 직접 고치기 | inventory_page `_save` → `saveRepositoryInventory` → `repository.inventory.update` → update_inventory. 전체 bucket 교체. revision +1 | key의 `inventory-save-<microseconds>`는 UI 요청 식별자이며 저장된 시각 필드가 아님. quantity는 문자열 또는 null | source=manual. 같은 수량을 새 key로 저장해도 1건. FD-096의 크레딧·엘리그마 수동 입력 금지는 유지 |
| v6 가져오기 | `repository.migration.import` → import_v6_profile, 학생·inventory·goals·plan을 **새 profile revision=0**으로 생성 | V6Account에 source_profile_key·warnings는 있으나 scan 시각 없음. v6 JSON에서 값만 변환; 과거 스캔 시각/provenance를 이관하지 않음. 반환 결과의 source 정보도 profile 이력으로 저장되지 않음 | source=import인 초기 seed 1건 제안. 시각은 **가져오기 성공 시각**이며 scan count/마지막 scan에서 제외. 원본 scan 시각을 발명하지 않음 |
| 신규 profile 생성 | create_profile가 empty current + empty v2 plan, revision=0을 생성 | 생성 시각 없음 | 빈 baseline/빈 history. 학생·inventory 적용 및 scan으로 세지 않음 |
| legacy 계획 첫 get 이관 | `_ensure_plan_locked`가 goals→plan 및 goals 정규화 저장, revision +1. get_state/get_plan/관련 scanner·scenario 호출에서 촉발 가능 | 시각 없음. **학생·inventory 목표 보충이나 확정값 변경 경로가 아님** | history event 및 scan count 없음. 같은 lock/journal에서 history 필드를 보존 |
| plan.save/replace, legacy goals.save, profile select/rename/update | profile/catalog revision 증가; replace는 scenario 파일까지 journal | current를 포함한 profile 파일을 다시 쓰지만 학생/수량을 수정하지 않음. scenario created_at/updated_at는 그 레코드 시각 | history 보존만. profile revision 증가를 current event로 추론하지 않음 |
| catalog 재정렬/alias rebase | `_profile`의 rebase_inventory_snapshot가 읽기 view의 key/ordinal/profile/observed_slot를 정규화. 이후 쓰기에 반영될 수 있음 | catalog_revision은 내용 SHA이지 시각이 아님. position/name만 바뀔 수 있음 | 경제 값 diff·scan 시각을 만들지 않음. known alias는 양쪽 상태를 같은 canonical resource_key로 맞춤 |
| UI seed·fixture·Mock | seed_ui_test_profile는 v6 import/rename/select 및 scenario 생성 경로 사용. Mock은 메모리 current 저장 및 scanner commit을 별도로 구현 | Mock에도 확정 저장 history/시각 없음. 현재 Mock inventory commit은 Python upsert와 달리 payload로 bucket 교체. 이력용 scanner context 없음 | 실제 저장과 같은 history helper/DTO가 필요. scanner-owned Mock commit 변화는 요청서로 조율. seed는 public repository 경로를 유지하면 별도 가짜 scan 불필요 |

`resolve_inventory_input`/repository_merge의 sqlite·json `source`는 **입력 선택 출처**이며 runtime current update의 scan/manual source가 아니다. v6 importer는 현재 JSON 경로다. 인식 정답 샘플 파일은 review 과정에서 confirmed_at·confirmation_source=user_review를 남길 수 있으나 repository revision 실패 전에도 생길 수 있고, 재화 수량 이력이 아니므로 FB-2의 근거로 사용하지 않는다. 전술대항전 commit·정적 metadata export·계산 결과/부족량·scanner snapshot/event 복원 역시 이력 대상 밖이다.

추가로 확인한 주의:

- ConfirmedStudent.provenance는 필드 출처 문자열 map이고 시각 계약이 아니다. 현재 Dart ConfirmedStudentState는 이를 검증하지만 DTO 필드/toWire에는 보존하지 않는다. 학생 값 diff와 provenance-only 변경을 분리하며, 직접 편집 왕복에서 provenance 보존 여부는 후속 DTO 결정이 필요하다.
- repository_merge.student_diff는 v6 parity용 넓은 field 목록을 쓰고 inventory_diff는 after key만 순회하여 **삭제와 missing/null을 충분히 표현하지 않는다**. 이를 그대로 이력 diff로 쓰지 않는다. 이력은 실제 확정 **before/after**를 비교하며 v6 MAX merge나 비용 정규화를 다시 적용하지 않는다.
- 학생 배열은 현 repository 경계에 student_id 중복 검사 없이 들어갈 수 있다. 학생 단위 이력의 key가 모호해지는 입력/기존 파일 정책도 승인해야 한다. 조용히 last-wins로 접지 않는다.

코드 근거: [repository current 쓰기](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/repository_store.py:539>), [공통 mutation](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/repository_store.py:328>), [scan commit](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/scanner_session.py:567>), [scan upsert](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/scanner_session.py:691>), [v6 변환](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/v6_migration.py:86>), [v6 import](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/repository_store.py:571>), [직접 inventory 저장](<C:/Users/brigh/planner_of_plana/BA Planner/v7/frontend/lib/ui/pages/inventory_page.dart:201>), [현재 DTO](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/repository_dto.py:128>), [Dart provenance 경계](<C:/Users/brigh/planner_of_plana/BA Planner/v7/frontend/lib/services/repository_service.dart:187>).

## 2. 이력 레코드 모양·diff 및 변경 없는 적용

승인 전 원본 초안(배열/객체는 strict; 아래 표기의 `...`는 문법 예시 생략이다):

```text
current_history = {
  version: 1, next_sequence: N,
  baseline: {sequence, at: UTC-string|null,
             students: [confirmed-current ...],
             inventory: [{resource_key, quantity: decimal-string|null} ...]},
  events: [{
    sequence, recorded_at: UTC-string, source: scan|manual|import,
    revision_before, revision_after,
    scan_kind: string|null, inventory_scan_profile: string|null,
    scan_context: {session_id, generation, candidate_id, candidate_revision}|null,
    applied_scope: {student_ids: [...], resource_keys: [...]},
    student_changes: [{student_id, before_present, after_present,
      fields: [{field, before: {present, value}, after: {present, value}}],
      provenance: {before: {present, value}, after: {present, value}}|null}],
    inventory_changes: [{resource_key,
      before: {present, quantity}, after: {present, quantity}}],
    catalog_revision: SHA|null
  }],
  scan_totals: {commit_count, first_at: UTC-string|null},
  latest_scans: {by_kind: [...], by_resource_key: [...], by_student_id: [...]}
}
```

- `recorded_at`은 backend의 UTC aware clock이 **최초 성공 적용**에 대해 정하는 RFC3339 `Z` 문자열이다. 구현 시 Python/Dart fixture에서 소수초 precision을 고정한다. 스캔 촬영/시작/완료 시각과 구별한다. 재시도·journal 복구는 원래 시각/sequence를 쓰며 새 clock을 읽지 않는다. UI key·mtime·sample confirmed_at을 쓰지 않는다.
- 단위는 profile 안의 증가하는 sequence다. 보통 event는 같은 current mutation의 revision_before→revision_after(+1), import 초기 seed만 0→0이며 별도 profile revision을 올리지 않는다. 장차 학생·아이템을 같이 적용하는 commit은 한 event의 양쪽 changes에 넣는다.
- `scan_kind`·`inventory_scan_profile`은 **raw string 그대로** 저장·반환·완전 일치 검색한다. trim/대소문자 변환·ScannerKind/InventoryScanProfile enum 변환·SCAN_PROFILES membership 검사는 금지한다. source=scan 이외는 null, scanner 쪽에서 profile을 모르면 null 그대로이며 catalog entry.profile_id로 채우지 않는다. 구문/크기 제한만 두는 안(문자열 1~1024 UTF-8 bytes, 원문 불변)이며 모르는 종류·profile fixture를 둔다.
- `applied_scope`가 핵심이다. 학생은 승인한 candidate의 **student_id**, 인벤토리는 **실제로 승인하여 적용한 resource_key**다. 합쳐진 bucket 전체 key나 diff에 나타난 key만으로 추측하지 않는다. 수동 전체 교체는 이전/새 bucket ID의 합집합을 작업 범위로 잡아 삭제도 표현하되 scan index는 갱신하지 않는다. 제외한 미승인 key는 기존값과 scan 시각을 유지한다. 승인한 null은 unknown이며 0이나 인식 성공의 증거가 아니다.
- inventory identity는 `canonical_resource_key(item_id or key)`다. ordinal/index·observed_slot·catalog profile을 이력 key로 삼지 않으며 unknown ID를 버리지 않는다. 수량은 기존 canonical decimal-string/null, 부호 있는 delta 문자열은 양쪽이 present/known일 때만 파생하고 나머지는 delta=null이다. 추가·삭제를 수량 0으로 채우지 않는다. 값이 같은 순서/이름/위치 변화는 수량 diff가 아니다.
- 학생은 student_id와 현재 DTO fields로 비교하고 missing과 명시 null을 present flag로 구별한다. form_combat_stats는 field 객체 전체의 before/after, provenance는 별도 차이로 원문을 유지한다. 목표·favorite/notes·비용·부족·정적 catalog 메타를 넣지 않으며 배열 순서만 바뀌었다고 성장 diff를 만들지 않는다.
- 전부 같아도 **새 승인 commit이면 event＋scope＋시각＋기존 revision +1**이다. changes가 비어도 latest_scans와 scan count를 갱신한다. 별도 key의 manual 동값 저장도 1건이다. repository 적용이 없는 session 완료·미승인·취소/실패·빈 승인 scope는 갱신하지 않는다(빈 scan scope는 invalid_payload안). 같은 key 재시도는 event/index/count를 늘리지 않는다.
- 동일 시각은 sequence로 정렬한다. clock이 돌아가도 원래 시각을 발명/보정하지 않고, latest scan은 마지막 승인 sequence의 시각을 반환한다. 시간 경계와 sequence 순서가 역전하는 기간은 warning·불완전 coverage로 표시하고 delta를 만들지 않는다. sequence 기준은 재구성할 수 있다.

**회수 주의(FD-041/FD-144):** 현재 full student scan은 학생 candidate마다 순차 commit하므로 한 session이 여러 건이다. `scan_commit_count`를 그대로 “스냅샷 n회”로 삼는 것이 FD-041 문구에 따른 제안이다. session_id 별 집계를 두더라도 commit 수와 바꾸지 않는다. A6를 full scan/session 단위로 그리려면 집계·완료 조건의 별도 승인이 필요하다. manual/import는 scan 회수에 넣지 않고 아이템별 scan 점은 해당 key가 applied_scope에 있는 scan만 센다(동값 점 포함). 다른 아이템의 scan을 그 아이템의 측정점으로 세지 않는다.

## 3. 저장 위치·크기·정리·transaction/revision

| 안 | 이점·필요 변경 | 판단 |
|---|---|---|
| A. profile JSON 안 optional current_history | current·history·revision/cache가 같은 after image. 기존 plan/scenario transaction의 profile target에 포함되고 profile과 함께 삭제됨. 매 profile 쓰기의 크기는 증가 | **권장**. 크기를 제한한 JSON부터. profile strict validator에 optional key를 허용하고 state/plan get에 원본 이력을 흘리지 않음 |
| B. history/{profile_id}.json | 큰 이력을 보통 profile 읽기/쓰기에서 분리 | current/profile catalog/history의 3-file journal, plan.replace 처리·별도 revision·삭제 target/lock이 늘어남. 첫 구현으로 권장하지 않음 |
| C. SQLite 이력 | 색인·장기 이력에 적합 | JSON profile/catalog와 DB를 한 commit으로 만드는 새 transaction 설계가 필요. A의 성능 측정에서 필요성이 확인되면 재설계 |

### 크기 제한 제안값

- profile별 **최근 365일·최대 10,000 event·current_history의 canonical UTF-8 16 MiB** 중 먼저 닿는 조건으로 정리한다. 10,000은 학생 순차 commit 수천 건을 보존하려는 값이며 1,000/2,048이면 전체 학생 scan 몇 번에 밀려날 수 있다. 16 MiB는 큰 전체 inventory diff가 건수 상한만으로 무제한 커지지 않게 하는 안이다. JSON/base64 journal의 메모리·읽기/쓰기 비용은 구현에서 fixture 크기와 처리 시간으로 검증하고 상한을 최종 확정한다.
- 새 current 저장 transaction 안에서 **오래된 연속 prefix**만 지우고 해당 diff를 baseline에 반영한다. 일별 마지막만 합치거나 manual을 지워 scan만 남기지 않는다. 새 event를 넣고 조건을 만족할 때까지 baseline을 전진시킨다. 비동기 정리 쓰기·GET prune·별도 revision 증가는 만들지 않는다.
- `latest_scans`는 scope로 같은 transaction 안에서 만드는 파생 index다. event를 지워도 종류별·현재값이 삭제된 key를 포함한 마지막 scan 시각을 잃지 않고 옛 scan을 새 scan으로 세지 않는다. scan_totals의 누적 commit 수와 보존 기간 내 count를 따로 반환한다. 종류 tuple은 raw `(scan_kind, inventory_scan_profile)`, resource/student key도 원래 identity다.
- baseline과 latest index만으로 16 MiB를 넘는 profile, 또는 단독 event를 넣을 수 없는 경우 시각/diff를 조용히 버리지 않고 **쓰기 전에 invalid_payload reason=history_capacity_exceeded**로 거부하는 안이다. current 저장을 막으므로 반드시 승인받아야 한다. baseline을 상한에서 빼고 제한을 지켰다고 하지 않는다. 상한 확대·외부 store 이관은 후속 명시 결정이다.
- 보존 시작 이전 diff는 `coverage.complete=false`, delta=null(또는 범위 오류)로 명시하고 0/빈 diff와 구별한다. 최신 scan index의 시각이 남아 있어도 그 시점의 과거값을 모두 복원할 수 있다고 하지 않는다. baseline 점은 scan 1건이 아니다.

### 호환·revision·실패 복구

- history 없는 기존 profile의 query는 기록 없음/coverage 불명을 반환한다. 읽기만으로 field를 생성하거나 revision을 올리거나 과거 scan을 만들지 않는다. 첫 current 쓰기의 lock 안에서 **쓰기 직전 실제값**을 시각 미상 baseline으로 잡고 첫 event를 추가한다. 신규는 empty, v6는 import event와 baseline을 생성 transaction에 함께 둔다. legacy plan 첫 이관의 기존 revision bump는 유지하되 history event로 세지 않는다.
- 현 `_write_profile_catalog`는 profile→catalog atomic write 후 Exception이면 rollback하지만 프로세스 중단용 durable journal은 없다. create/import/delete도 같다. FB-2는 current＋history＋profile revision/catalog/cache를 **공용 write_transaction**으로 저장하여 복구 결과가 이전 전체/이후 전체만 되게 한다. current commit 뒤 timestamp/index를 따로 쓰지 않는다.
- 현 journal target은 catalog/profiles/scenarios, writes 최대 3, after=null 금지, writer의 stage loop도 세 항목 zip이다. inline current 저장은 두 target으로 충분하다. 현 delete의 catalog/profile/tactical v1/scenarios/presets 다섯 target을 journal화하려면 삭제 after=null·target allowlist·건수/loop 확장이 필요하다.
- **삭제의 별도 조율점:** TacticalV2Store는 `tactical/{id}.v2.json`을 쓰는데 현 delete는 `{id}.json`만 지운다. 두 버전을 포함한 전체 삭제면 여섯 target이다. v1/v2 writer도 `.tactical.lock`/`.tactical-v2.lock`을 따로 잡으므로 root guard만으로 동시 삭제 전체를 보장할 수 없다. 오케스트레이터가 tactical 소유자에게 삭제 대상·읽기/쓰기 공통 guard 참여·고정 lock 순서 대응을 요청해야 한다. 협의 전에는 전체 삭제의 원자성을 완료로 선언하지 않는다. inline history가 profile과 함께 삭제되는 점은 이 별도 파일 문제와 구별한다.
- profile 삭제 때 history도 삭제한다. delete/create/import journal화도 FB-2a에 포함하는 안이다. 중단한 삭제는 시작 후 get_state/plan/history/scenario list/get의 공통 guard가 복구하며, 반쯤 삭제한 계정이나 고립된 history를 보이지 않는다. scanner 학습 sample 삭제는 별도 소유·정책이며 이력 삭제와 묶지 않는다.
- 독립 history writer/revision을 만들지 않고 view의 `history_sequence`를 snapshot/cursor에 쓴다. 보통 current 적용은 기존 profile revision +1뿐이다. plan/profile 메타에 따른 revision gap은 정상이다. scenario/preset collection revision은 불변, plan.save/replace/goals/legacy migration은 history를 보존하지만 늘리지 않는다.
- manual의 옛 request fingerprint와 `{revision}` 응답을 유지한다. 새 scanner context를 fingerprint에 포함하는 방식은 호환 처리를 명시하고 **옛 cache 확인을 새 history 호환 검증/clock보다 먼저** 한다. 옛 cache에 새 scan을 덧붙이지 않는다. 새 key에 다른 source/scope/profile context면 idempotency_conflict. context 미지원 scanner를 manual로 잘못 분류하여 완료로 삼지 않는다(FB-2b 연결 필요).
- student ID 중복은 새 입력 invalid_payload, 기존 baseline의 모호한 중복은 corrupt_data/명시 정리 요청으로 처리하는 안이다. 현재 update 계약의 추가 제약이므로 별도 승인한다. 손상된 history도 빈 값으로 바꾸지 않는다.

근거: [현재 두 파일 저장](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/repository_store.py:199>), [삭제 대상](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/repository_store.py:396>), [journal target·복구](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/repository_transaction.py:78>), [transaction writer](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/repository_transaction.py:216>), [tactical v2 파일](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/tactical_v2.py:408>), [v2 lock](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/tactical_v2.py:470>), [v1 lock](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/tactical_store.py:222>).

## 4. 조회 메서드 초안·소비자

이력 전용 method로 현재 repository.state/profile 응답의 고정 key나 기존 snapshot_count를 바꾸지 않는다. 아래는 승인 대상 계약 초안이다.

| method(가칭) | 요청·응답 초안 | 소비자 |
|---|---|---|
| repository.history.summary | `{profile_ids, resource_keys?, student_ids?}` → profile별 `{profile_id, revision, history_sequence, last_scan_at, last_scans:[{scan_kind, inventory_scan_profile, sequence, at}], items:[{resource_key,last_scan_at}], students:[{student_id,last_scan_at}], retained_scan_commit_count,total_scan_commit_count,coverage}` | FE8-c는 계정 메타를 한 호출로. FE8-g1 종류별 막대, FE6 상세 item 시각. 이력 없는 item/student의 last_scan_at은 null이며 enum 변환 없음 |
| repository.history.events | `{profile_id, from_at?, to_at?, source?, scan_kind?, inventory_scan_profile?, student_ids?, resource_keys?, cursor?, limit?}` → `{revision, history_sequence, coverage, events, scan_commit_count, next_cursor}` | FE6-f 최근 변화, 상세스파크라인 원본, FE7-h A6/B3 원본. source/대상 filter는 표시할 event 선택이며 reconstruct에서 다른 source의diff를 빠뜨리지 않음 |
| repository.history.diff | `{profile_id, from, to, student_ids?,resource_keys?}` → `{revision, history_sequence, coverage, from_point,to_point,student_changes,inventory_changes,scan_commit_count}` | FE6-f KPI/기간 net change, FE7-h 두 시점 KPI. 시간/sequence 또는 최신·이전 scan/현재 endpoint를 같은 helper로 해석 |

- summary는 profile_ids 최대 128, key/student filter 각각 최대 256개를 제안한다(계정 N+1 조회 방지·응답 크기 제한). events는 default limit=100, max=200. unknown kind/profile filter는 정상 빈 결과, unknown resource ID도 보존한다. missing profile은 기존 profile_not_found. UTC aware RFC3339만 받아 events는 `[from_at,to_at)`로 선택하고 기간 diff는 양쪽 경계 직전 상태를 비교한다. filter 생략은 전체, 명시 inventory_scan_profile=null은 null tuple 검색으로 구별한다.
- diff endpoint는 strict one-of 초안: `{at: UTC}`, `{sequence: int}`, `{scan: latest|previous, scan_kind: raw, inventory_scan_profile: raw|null, resource_key?: ID, student_id?: ID}` 또는 `to={current:true}`. 시간 endpoint는 경계 직전, sequence/scan은 해당 적용 직후 상태다. selector latest/previous는 이력 API의 선택 규칙이며 raw scan_kind/profile enum이 아니다. 범위 역전·대상 중복 지정은 invalid_payload, 필요한 scan/과거 상태가 없으면 coverage 불완전·delta=null. query anchor 시점의 현재 상태까지 같은 root guard 아래에서 읽는다.
- cursor는 profile/필터/anchor history_sequence를 묶은 불투명 값이다. 다음 페이지에 anchor 뒤 write를 섞지 않는다. prune으로 필요한 prefix가 사라지면 `invalid_payload reason=history_cursor_expired`로 재조회를 알리는 안이다. read는 profile revision을 올리지 않는다.
- “지난 스캔 대비”는 종류/resource/student scope의 **최근 두 scan commit 시점의 실제 current**를 비교하는 안이다. 사이의 manual 변경도 먼저 반영해 상태를 복원한다. 현재값 vs 마지막 scan은 별개 비교로 UI가 구별한다. scan 한 건뿐이면 두 scan 비교는 delta=null이지만 현재/마지막 scan 비교는 가능하다. FD-042 trend는 해당 key scan 세 건 미만이면 숨긴다. manual/import 점은 scan 회수를 늘리지 않는다.
- 과거 current projection 복원은 공용 helper를 쓰고 query마다 비용식/정규화를 복제하지 않는다. FE7-h 성장 필터는 현재 metadata에서 선택한 student ID 집합을 양쪽 시점에 적용한다. 전체 학생 합계와 필터에 해당하는 scan 표본 수를 구별하며, 상태 없는 학생·unknown quantity를 0으로 채우지 않는다.
- **history는 과거 goals/계획/metadata를 저장하지 않는다.** 현재 plan을 고정한 과거 보유량의 부족/충족률은 같은 plan/catalog 기준으로 다시 계산할 수 있지만, “당시 활성 계획”이나 “계획 등록 +7”을 재현한 값은 아니다. 해당 KPI delta는 범위 밖으로 숨기거나 별도 목표 이력 승인이 필요하다. 크레딧·엘리그마도 FB-3/FB-10의 실제 key/scan 전에는 null/스캔 없음이며 가짜 수치를 넣지 않는다.
- FD-147 표시는 프론트가 UTC→local 변환, 경과일/14 상한 막대, 최근≤7일/오래됨>7일/스캔 없음으로 그린다. FB-2는 시각/coverage/raw 종류를 반환한다. I-scan Q4가 계정 메타를 학생 행과 같은 시각으로 설명하므로 **FE8-c는 student의 last_scans 행**을 읽는 안이다. 전체 종류 최신 last_scan_at과 학생 최신을 조용히 바꾸지 않는다.
- FE8-g1 “최근 스캔”은 FD-149의 앱 실행 중 8건 session 기록을 유지한다. 영속 성공 적용 이력을 session 시작/완료 로그 대신 쓰지 않는다. 현재 statistics snapshot_count(inventory entries 개수 projection)도 FD-041의 scan 회수로 바꾸어 쓰지 않는다.

## 5. 스캐너 소유 경계·요청서 초안

**여기는 요청안만 작성했다. scanner log나 코드에 보내거나 옮기지 않았다. 오케스트레이터가 FB-10 형식 고정·소유자와 조율한다.**

| 요청 | 스캐너 쪽 필요한 정보·대응 | Lane A 수신 경계 |
|---|---|---|
| repository commit port | update_students/inventory에 optional 내부 history_context 또는 scan 전용 port 추가. source=scan, session/candidate 식별, raw scan_kind/profile, 실제 승인 ID scope 전달. 프론트의 source 자기 신고로 판별하지 않음 | 공용 strict context validator＋current/history 동시 저장. 기존 수동 public method는 source=manual 고정 |
| inventory profile 보존 | session.target의 원래 profile 유지, scanner-only entry field를 버리기 전에 scope/context 확보. entry.profile_id는 catalog 정보라 사용 금지. 새 문자열을 history enum으로 거부하지 않음 | raw 문자열 저장/검색/Dart DTO 파싱. catalog ordinal에 의존하지 않음 |
| 부분 승인(FD-146) | 실제 승인·적용 resource keys와 제외하여 옛값을 보존한 keys 구별. 미식별 slot을 key로 바꾸지 않음. quantity null/needs_review 처리는 FB-10 계약에 맞춤 | scope 대상만 최신 scan 갱신. 전체 bucket의 동값 key에 시각을 붙이지 않음. needs_review storage를 임의 추가하지 않음 |
| 전부 그대로(FD-147) | 적용을 선택하면 diff 0이어도 기존 commit 호출. FD-144의 그대로=적용 불필요로 skip하면 시각을 갱신하지 않음. 완료 시 자동 history를 만들지 않음 | 비어 있지 않은 승인 scope＋빈 diff event 원자 저장. 같은 key 재시도는 같은 시각/한 건 |
| retry/revision/Mock | 응답 유실 시 같은 key/context 재전송. 학생 순차 commit의 응답 revision을 다음 expected로. Mock scanner commit도 같은 scope/upsert/history helper 사용(공유 file은 동결/pre-post 분리) | legacy cache replay 우선·source/context 충돌 거부. Python/Dart/process fixture 함께 고정 |
| 삭제 동시성(별도 tactical 요청) | tactical v1/v2 파일 삭제 범위, root guard 참여와 lock 순서를 소유자와 확정. scanner tactical_lobby commit도 같은 보호 경계를 거치게 검토 | 공용 journal target/삭제 image 확장과 fixture. tactical 소유 코드 직접 수정 없이 협의 결과를 받음 |

scanner_session.py·scanner_protocol_v1.py·scanner_runtime.py·matcher/recognizer·scanner service/UI는 이번에도 수정하지 않았다. FB-2 때문에 scanner start의 기존 지원 종류 검사를 제거하도록 요청하지 않는다. enum 금지는 **history 저장/조회/DTO 경계**이며 인식 구현의 지원 종류와 별개다. crop/evidence/sample 이미지나 candidate 전체를 history에 넣지 않는다.

## 6. 분할 제안·구현 전 승인 사항

| slice안 | 범위·완료 조건 | 선행 |
|---|---|---|
| FB-2a 저장 기반 | current_history DTO/diff/baseline/정리, manual/v6/new/legacy 호환, profile/catalog atomic journal, 삭제/생성/import의 durable 경계, idempotency/손상/크기 fixture. contracts/Python/Dart history DTO 고정. 최소 query로 restart 검증 | 설계 승인. scanner context 선확정. 전체 삭제는 tactical 파일·guard 조율 필요(미승인 시 별도 하위 slice로 명시 분리) |
| FB-2b scan 연결＋마지막 scan 조회 | scanner 담당의 port/context 대응 후 scan/no-change/부분 scope 확정 저장. summary＋typed Process/Mock＋process restart/legacy replay. FE8-c/g1·FE6 item 시각 연결 메모 | FB-2a＋scanner 소유자 대응/동결 창. 연결 전 scan freshness 완료로 삼지 않음 |
| FB-2c 기간/그래프 조회 | events/diff/reconstruction/filter/cursor, FE6-f·FE7-h의 같은 상태 기준·scan 회수/coverage. 기존 projection 로직 사용, FD-042 trend 세 scan 조건 검증. UI는 프론트 담당 | FB-2a/b. 성장 집계 단위·스냅샷 명칭 승인 |

### 오케스트레이터가 승인할 핵심 결정

| 결정 | 권장안·미확정점 |
|---|---|
| 저장 위치·복구 범위 | profile 안 optional current_history v1. current 외 create/import/delete journal화도 FB-2a에 포함하는 안. 현 다섯 target/전술 v2 포함 여섯 target·삭제 image 확장과 tactical guard 조율, 미승인 부분의 하위 slice 분리를 결정 |
| source/초기 seed | scan/manual에 import 추가. import는 성공 시각 seed, scan 제외. 옛 profile 시각 미상 baseline/신규 empty. 과거 scan 발명 금지 |
| event/스냅샷 단위 | FD-041의 1 commit=1건. full student session을 한 snapshot으로 집계하려면 FD-144 순차 commit의 완료 조건을 별도 결정. 종류 queue도 session/commit 수 구별 |
| scan scope·동값 적용 | 승인 ID만 시각 갱신, diff 0도 기록. 완료만/미승인·제외/빈 scope는 갱신 없음. FD-146 scope 전달을 scanner 담당에 요청 |
| raw 문자열·cache 호환 | raw kind/profile enum·trim 금지. 길이 제한, null/누락 의미, 옛 cache 재시도 우선 처리, 새 context fingerprint 방식 확정 |
| 보존·상한 | 365일/10,000건/16 MiB, prefix→baseline 정리＋최신 scan index/누적 count 유지. 못 넣을 때 current 저장 거부 정책과 reason 승인·크기 측정 |
| 기간·비교 기준 | UTC[from,to), 두 scan 점 vs 현재/마지막 scan 구별, scope별 count, manual을 상태 복원에 반영, 모자란 기간은 delta=null. clock 역행/cursor 만료도 명시 |
| 기존 모호한 데이터 | student_id 중복 입력 거부/기존 파일 정리 요구, provenance-only 변경과 Dart DTO 보존. 기존 계약 추가 제약을 명시·fixture 고정 |
| 소비자·분할 | FE8-c 학생 시각 vs 전체 최신 구별. FE7-h 과거 plan KPI는 이번 범위 밖. FB-2a/b/c 순서와 scanner 소유 동결 창 |

### 필수 fixture(구현 전에 정책 고정)

| 묶음 | 필수 사례 |
|---|---|
| 저장 출처 | 학생/inventory scan, 양쪽 manual, import, 새 profile, 옛 무history profile. review에서 수정한 scan도 source=scan |
| 동값·제외 | 전체 동값 scan/동값 manual/동일 key 재시도, 완료했지만 미적용, 취소/실패, 비어 있지 않은 scope＋빈 diff, 빈 scan scope 거부 |
| partial/identity | 승인 key만 갱신, scope 밖 옛값/시각 유지, unknown kind/profile 원문·null profile·미래 profile, catalog 재정렬/alias/unknown resource ID |
| diff 정확성 | 0/null/absent, 추가/삭제, 큰 정수 수량 문자열/음수 delta, 학생 missing/null, form object/provenance-only/배열 순서 변경, student ID 중복 명시 오류 |
| revision/cache | profile 메타/plan 저장·첫 이관은 event 없음, scan/manual +1뿐, scenario/preset 불변, 옛 cache/응답 모양, 같은 key 다른 context 충돌, 재시작 동일 시각 |
| transaction | profile/catalog 각 쓰기 경계, journal prepared/committed/복구 중 예외·강제 종료, create/import/delete 재시작. 항상 이전 전체/이후 전체이며 가짜 시각/event·중복 없음 |
| retention | 세 상한 각각, baseline 복원, 지운 event의 최신 scan index 유지, 누적/보존 count 구별, 과거 coverage 부족, 단독 거대 record 거부, 손상 history 빈 값 대체 금지 |
| query/통계 | profile 격리, source/대상 filter에서도 manual을 반영한 복원, 기간 끝/동시각/clock 역행, cursor 고정/만료, 0/1/2 scan 및 trend 세 건 조건, scope 밖 key는 scan 점 제외 |
| 회귀·왕복 | v1 current/profile DTO, FB-1b 이관·FB-1c/FB-8 journal 보관·v6 import·기존 scenario/통계 값, strict Python/schema/Dart, scan commit→restart→summary/diff process E2E |

**여기서 멈춘다.** 이 절은 승인 전 계약안이다. 다음 구현 프롬프트 전에는 코드 편집을 재개하지 않는다. commit.json을 만들지 않으며 다음 백엔드 commit의 backend 상태 문서 whole에 이 조사도 함께 넣는다.

# FB-8b 시나리오 authoring

## 착수 (2026-10-09)

- 시작 SHA: `0160910f2c803e28aee1bf04ab5abc7b2bb4cfde`. FB-8a `4accf46c` 커밋 이후 HEAD.
- AGENTS·README·runtime 경계, 워크플로 FB-8/앞뒤 병렬, 오케스트레이터 17:30·19:40·20:05, FB-8a 종료 전체/FB-8b 연결 메모와 승인된 읽기 전용 조사를 읽었다.
- 공용 authoring validator/schema/레코드 DTO를 재사용하여 create/update의 typed optional 저장, get/duplicate의 bundle 보존과 metadata-only revision/idempotency를 구현한다. compare는 document-only 의미를 유지하고 필요성 판단 근거를 종료 기록에 남긴다.
- 스키마 목록 기대 집합의 `planning-authoring-v1.schema.json`은 이미 FB-8a 커밋에 반영되어 있다. 새 schema 없이 기존 scenario schema에 optional 필드를 참조하며 관련 계약 모듈을 직접 검증한다.
- UI·스캐너·tactic·metadata 소유 파일은 고치지 않는다. 공유 서비스 pre/post를 남기며 전체 Python·gate·stage·커밋·push는 하지 않는다.

## 종료 (2026-10-09)

FB-8b의 Python·계약·Dart 서비스·Mock/Process와 직접 검증을 마쳤다. **코드 편집을 멈춘다.** 전체 Python과 공통 gate·stage·커밋·push는 실행하지 않았다. 화면·widget/golden 코드 및 baseline은 바꾸지 않았으며 golden 변화는 0을 예상한다.

### 계약·저장 경계

| 경계 | 확정 동작 |
|---|---|
| scenario.create authoring 누락 | 문서 기반 default. 저장 field는 생략하여 기존 v1/v2 레코드 모양을 보존 |
| scenario.update authoring 누락 | 기존 sidecar를 새 문서에 공용 validator로 검증하여 보존. 불일치하면 `invalid_payload`, `details.reason=authoring_required`, `details.authoring_reason=공용 실패 reason` |
| 명시 객체 | sidecar 전체 교체. 문서의 default 객체로 명시적으로 초기화 가능. 부분 merge 없음 |
| 명시 null | `invalid_payload`, `reason=invalid_shape`. Dart strict fromWire에서도 거부 |
| get | optional 저장 sidecar 반환. `PlanningScenarioRecord.hasAuthoring`는 실제 저장 여부, `.authoring`은 저장 값 또는 문서 default |
| duplicate | 요청은 기존 식별자·두 revision·key 유지. 문서 버전·목표·메타·선택 순서·나중에 단계·체인·직접 선행 모두 보존. 레코드/문서 ID·이름·시각만 재발급 |
| 메타만 update | record revision과 scenario collection revision 각각 1 증가. profile revision·active plan·goals 불변 |
| idempotency | 누락 요청의 fingerprint는 이전 operation 그대로. 명시 authoring만 canonical operation에 포함. 최초 응답 cache를 revision 및 누락 메타 호환 검증보다 먼저 확인. 나중 수정·삭제·재시작 후에도 최초 `{revision, scenario_id}` 반환 |

- `ScenarioStore._canonical_authoring`에서 FB-8a 공용 `planning_authoring_from_wire`를 재사용한다. 자동+직접 DAG, 학생 체인 prefix/suffix, 칸 및 같은 칸 배열 순서, 누적 목표, 메타 key 규칙은 복제하거나 완화하지 않았다.
- 문서·authoring·record/collection revision·응답 cache가 기존 scenario 파일 atomic write 한 번에 저장된다. 기존 repository guard와 FB-1c journal recovery를 재사용한다. 활성 plan.replace로 보관한 레코드도 같은 get/update/duplicate 경계를 사용한다.
- create/update의 Dart `PlanningScenarioCreateRequest`·`PlanningScenarioUpdateRequest`는 strict fromWire/toWire이며 `PlanningAuthoring? authoring`을 서비스로 전달한다. delete/duplicate도 strict identity DTO를 거친다. Mock은 같은 mutation cache·누락/교체·복제와 최초 응답 재시도를 구현한다.
- 새 schema 파일은 추가하지 않았다. 기존 `scenario-protocol-v1.schema.json`의 create/update optional property가 공용 schema를 참조한다. `test_planning_protocol_contract.py`의 기대 집합에 이미 들어 있는 authoring schema를 그대로 검증했고 해당 모듈도 통과했다.

### compare에 authoring을 넣지 않는 근거

`planning.scenario.compare` 요청은 현재 학생·인벤토리와 `document_a/b`만 유지한다. `ScenarioStore._summary`·`_calculation_summary`는 record.document만 보고, 비교 경로도 기존 문서 계산을 그대로 호출한다. authoring.deferred_stages는 document.phases 밖에 있으므로 계산·비교·phase/stage/student counts·calculation summary에서 제외된다. 편집 복원에는 get.authoring이 필요하지만 계산 요청에는 필요하지 않다.

같은 칸 재화 배분은 기존 document.phases의 stage 배열 순서다. 직접 선행은 그 배열을 검증하는 편집 규칙이며, 별도 실행 조건이나 재정렬을 비교 계산에 주입하지 않는다. 따라서 metadata만 바꾼 문서와 복제 문서의 계산값이 같다. all-deferred의 비교 비용은 0이다. 기존 v1/v2 문서 및 FE4-e의 메타 없는 호출을 유지한다.

### fixture·직접 검증

| 묶음 | 검증한 정책 |
|---|---|
| `planning_authoring_v1.json` 55개 공용 정책 | scenario create 경계와 strict Dart DTO에서 동일 valid/reason/canonical 결과. 단계 집합·체인·누적 목표·직접 참조·순환·칸/배열 순서·선택/메타·unknown ID·Unicode 선행 정렬 포함 |
| `scenario_authoring_v1.json` 16개 wire | create/update 누락·객체·null·미래 버전·unknown key·bool target, duplicate identity, get 객체·legacy·null |
| 저장·재시도 | 메타만 수정, 누락 보존/불일치 오류, 명시 default 초기화, source와 duplicate 분리, 선택/나중에만 있는 레코드, profile bucket 불변, metadata fingerprint 및 선행 pair 정렬, 오래된 최초 응답 |
| legacy 회귀 | v1/v2 메타 없는 create/update operation SHA가 이전 공식과 동일. get/list/replay가 파일 byte를 바꾸지 않음. 현재 메타가 예전 문서에 맞지 않아도 옛 누락 요청 replay 우선 |
| 실패 주입 | scenario 쓰기 before_write/before_fsync/before_replace 각각 예외·프로세스 강제 종료. 재시작 시 완전한 이전 bundle/cache, 성공 후 완전한 새 bundle/cache 및 재시도 동일 응답 |
| process E2E | create → 메타만 update → duplicate → 재시작 get/compare → 누락 불일치 거부 → all-deferred 교체 → 재시작 get/compare → 최초 응답 replay. 별도 legacy v1 재시작. 기존 FB-8a 보관·v1/v2 시나리오 회귀 포함 |

| 실행 | 결과·로그 |
|---|---|
| 관련 Python 8모듈 | **67 passed**, `debug/frontend_fb8b/python-targeted.txt` (새 FB-8b 11건 포함, scenario store/protocol/contract, FB-8a, planning schema 기대 집합, FB-1a, FB-1c) |
| Dart 서비스 5파일 | **184 passed**, `debug/frontend_fb8b/dart-services.txt` (새 75건 포함, 기존 scenario/authoring/plan/v2) |
| Dart process 4파일 | **5 passed**, `debug/frontend_fb8b/dart-process.txt` |
| 관련 Dart analyze | **No issues found**, `debug/frontend_fb8b/dart-analyze.txt` |
| 최종 변경 재검증 | Python 신규 11 passed `python-new-final.txt`, Dart 신규 75 passed `dart-new-final.txt` |
| 전체 Python·공통 gate | **미실행**, 사용자 단계. UI/golden 변경 없음 |

직접 명령은 backend에서 `py -3.11 -X utf8 -m unittest tests.test_scenario_authoring_fb8b tests.test_scenario_store tests.test_scenario_protocol tests.test_scenario_protocol_contract tests.test_planning_authoring_fb8a tests.test_planning_protocol_contract tests.test_planning_document_v2_fb1a tests.test_repository_plan_replace_fb1c -v`, frontend에서 `flutter test --no-pub --exclude-tags golden --concurrency=1` 뒤 위 서비스 또는 process 파일을 명시했다. 두 Flutter 실행은 순서대로 진행했다.

### FE4-f 연결 메모

1. 시나리오 편집 시작: `listScenarios(profileId)`의 collection revision과 `getScenario(...).scenario.revision`을 잡고, `.document` + `.authoring`을 하나의 draft로 복원한다. counts는 배치 학생만 세므로 선택 학생·나중에 칸을 summary에서 추론하지 않는다.
2. 문서+칸 보드 저장: `createScenario` 또는 `updateScenario`에 FE4-f가 만든 전체 `PlanningAuthoring`을 `authoring:`으로 함께 준다. update에는 최신 collection/record 두 revision이 필요하다. 공용 validator가 요구하는 같은 칸 배열 순서까지 프론트가 정리하여 보낸다. stage ID 재발급 시 deferred·chain·직접 edge endpoint도 함께 remap한다.
3. FE4-e의 기존 메타 없는 호출은 계속 사용 가능하다. update 누락은 보존이며 null을 지우기 용도로 보내지 않는다. 초기화는 `PlanningAuthoring.defaultForDocument(document)` 명시 객체다.
4. `revision_conflict`는 `details.current_revision` 또는 `current_scenario_revision`을 보고 재조회·편집 충돌을 처리한다. `authoring_required`는 draft를 유지하고 새 문서와 맞는 sidecar를 함께 보낸다. `idempotency_conflict`는 같은 key에 다른 내용을 재사용한 오류다. `repository_busy/persistence_failed` 재시도는 같은 payload/revision/key를 유지한다. 응답 유실 후에는 같은 호출로 최초 응답을 받는다.
5. duplicate는 추가 authoring 인자 없이 bundle을 보존한다. compare는 두 get 레코드의 `.document`만 넘긴다. 비교 결과로 편집 메타를 덮어쓰지 않는다. 현재값·필수 선행 계산용 값도 saved targets에 되쓰지 않는다.

### 사용자 Python 전체·인계·동결

v7 루트에서 실행(결과 `debug\frontend_fb8b\python-full.txt`):

```powershell
New-Item -ItemType Directory -Force debug\frontend_fb8b | Out-Null
Push-Location backend
py -3.11 -X utf8 -m unittest discover -s tests -v *> ..\debug\frontend_fb8b\python-full.txt
$fb8bPythonExit = $LASTEXITCODE
Pop-Location
Get-Content debug\frontend_fb8b\python-full.txt -Tail 12
if ($fb8bPythonExit -ne 0) { throw "FB-8b Python full failed ($fb8bPythonExit)" }
```

- `debug/frontend_fb8b/commit.json`: status=false, whole=본 backend 상태 문서, post_dir=`debug/frontend_fb8b/post`. 공유 서비스 mock/process/client의 pre/post 사본을 함께 둔다. client는 기존 scanner WIP 그대로이며 이번 modified 목록에는 없다.
- `handoff-verification.json`에 HEAD·index 불변, HEAD/pre/post clean merge와 공유 서비스 scanner 영역 제외, 보호 파일 목록·post SHA를 기록한다. 이번 slice에 baseline 폴더를 넣지 않는다.
- 전체 Python 후 **두 워커 모두 멈춘 상태**에서 gate·`fe_commit -Slice fb8b`·redesigndocs는 사용자/오케스트레이터가 진행한다. 이 워커는 여기서 멈추며 다음 프롬프트 전에는 코드 편집을 재개하지 않는다.

# FB-8a 활성 계획 authoring 저장

## 착수 (2026-10-09)

- 시작 SHA: `611ec7a1d243f5b3524b480183600fdcead368c6`. FE4-h `8beab94e` 이후 HEAD.
- FB-8 설계 조사와 워크플로 FB-8 행, 오케스트레이터 2026-10-09 17:30 승인을 읽었다. 문서 v2 옆 authoring v1 6키, prefix/suffix·전체 DAG·칸/배열 순서 검증, optional 보존 및 기존 fingerprint 호환, deferred-only 교체 보존을 구현한다.
- 활성 계획 get/save/replace와 legacy goals 손실 방지. 시나리오는 교체 보존 레코드를 읽고 유지하는 최소 경로이며 CRUD 확장은 FB-8b로 넘긴다.
- 공유 서비스 스캐너 WIP를 pre/post로 보존한다. UI·metadata·스캐너·tactic은 편집하지 않으며 gate·stage·커밋·push는 하지 않는다.

## 종료 (2026-10-09) — 구현·직접 검증 완료, 사용자 전체 실행 대기

### 계약·저장 결과

- 공용 `planning_authoring.py` + `planning-authoring-v1.schema.json` + Dart `PlanningAuthoring`의 strict 6키를 맞췄다. 자동 같은 학생 edge + 직접 교차 edge의 전체 DAG, 배치 prefix/나중에 suffix, 전체 체인의 nullable 누적 목표, 같은 칸 배열 순서를 검증한다. 계산 문서나 배열을 재정렬하지 않는다.
- 프로필 `plan_authoring`, wire `authoring`. 활성 문서는 계속 v2 kind=plan이다. 공용 validator/시나리오 record는 기존 nested v1/v2 버전을 유지한다. 문서·비용식·정규화·goals 파생 함수·통계 입력은 수정하지 않았다.
- `RepositoryPlanState.authoring`은 누락 시 document 기반 기본값, `hasAuthoring`은 실제 wire 필드 존재 여부다. Save/ReplaceRequest 및 Process/Mock은 typed optional authoring을 전달하고 명시 null wire를 거부한다. DTO의 배열·map·nullable targets는 불변이며 toWire는 독립 사본이다.
- 직접 pair는 의미상 집합으로 정렬한다. Unicode code point 정렬을 Python/Dart에서 일치시켰다. student_order·stage_order_by_student 배열·deferred_stages의 순서는 보존한다. 미등록 학생 ID·목표 없는 선택 학생과 notes 공백을 보존한다.

| 경계 | 최종 동작 |
|---|---|
| plan.get, stored authoring 없음 | 기존 4키 response·파일 bytes 유지. authoring 이관/추가 revision 없음. FB-1b legacy 첫 plan 이관만 원래대로 |
| plan.save 누락 | stored authoring 없으면 옛 경로. 있으면 보존·새 문서와 재검증. 맞지 않으면 invalid_payload, reason=authoring_required, authoring_reason=원인. mutation/cache 쓰기 없음 |
| plan.save 명시 object | 전체 metadata 교체. document/goals/plan_authoring/profile revision/catalog/cache를 한 저장 transaction으로. metadata만 바뀌어도 profile +1 |
| plan.replace 누락 | 새 active는 새 document 기본값. 옛 authoring은 archive로만. 옛 fingerprint 그대로 |
| plan.replace 명시 object | 새 active bundle 전체 교체. 옛 document+authoring 보관 후 같은 journal transaction으로 profile/catalog/scenario 반영 |
| replace 보관 조건 | old phases 또는 authoring 선택 학생/나중에 단계가 있으면 보관. 양쪽 모두 비었을 때만 archived_scenario_id=null·scenario revision 불변 |
| clear | document 기반 default authoring object를 명시. null은 지우기 의미가 아니며 거부 |
| idempotency | 누락 요청은 옛 fingerprint를 그대로 사용. 명시 metadata는 canonical fingerprint에 포함. cache를 omission 호환성·revision 검사보다 먼저 확인, 최초 응답 replay·중복 archive 금지 |
| legacy goals.save | non-default authoring은 plan_lossy_write, details.reasons에 authoring_metadata. default metadata는 기존 구조/인연 손실 검사 통과 시 새 legacy 문서 기본값으로 맞춤 |
| 시나리오 최소 경로 | replace archive에 optional authoring 저장·get/list strict 읽기·duplicate 보존. 기존 update는 metadata를 유지·재검증하고 불일치면 authoring_required로 거부. CRUD 요청 authoring 확장은 FB-8b |

오류 reason은 README에 정리했다: invalid_shape, unsupported_version, targets, target_regression, student_order, stage_set, stage_chain, goal_metadata, stage_reference, self_reference, same_student_prerequisite, duplicate_prerequisite, cycle, lane_order, stage_order, authoring_required. 저장 손상은 corrupt_data, 미지원 저장 version은 migration_required이며 기본값으로 덮지 않는다. revision_conflict/profile·scenario·both details, idempotency_conflict, repository_busy, persistence_failed는 기존 규칙을 재사용한다.

### 정책 fixture·회귀

`contracts/fixtures/planning_authoring_v1.json` **55건**(canonical 결과·reason 포함), `repository_plan_authoring_v1.json` **11건**(optional request/response·보관 record wire)을 Python/Dart 공용 기준으로 고정했다. JSON Schema는 shape/range를, 양 언어 공용 DTO는 bundle 의미를 검사한다. bool/string/float token을 int로 인정하지 않는다.

| 조사 5절 묶음 | 고정·검증한 내용 |
|---|---|
| legacy-no-authoring(plan) | get 필드 누락·default DTO·bytes 불변·원래 legacy plan 첫 이관 후 revision 안정. 기존 v1 scenario default도 버전 보존 |
| deferred-targets, selected-order | 전체 19키 nullable·0·bond, notes/favorite, 미등록·목표 없는 선택 학생과 선택 순서 복원 |
| stage-set-and-chain | 양쪽 ID 중복, 자기 학생 단계 집합의 누락/중복/다른 학생 참조, prefix/suffix·체인 역전 거부. 같은 목표/all-null은 허용 |
| monotonic | 전체 학생 체인의 integer→작은 값/null, bond 감소/null 회귀 거부; null→정수·동일 목표·부분 목표 허용 |
| direct-reference, cycles | 없는 endpoint·self·같은 학생 직접 pair·중복·extra 거부, 직접 cycle과 자동 체인을 거친 간접 cycle 거부 |
| same-lane-and-cross-lane | 같은 칸/나중에 배열 역전, 더 늦은 phase·나중에 선행→배치 후행 거부. 배치→나중에 허용. 조용한 재정렬 없음 |
| deferred-exclusion, all-deferred | goals는 마지막 배치 단계만. 나중에 bond/높은 목표·선택 학생은 계산/비교/통계 goals·scenario counts에서 제외. 전부 나중에면 계산 0·빈 goals지만 편집 bundle 보존 |
| save omission-and-clear | compatible 누락 보존, incompatible 누락 reason=authoring_required, 명시 default clear, null 거부 |
| metadata-only-revision/idempotency | 문서/goals 값 불변인 metadata 저장에도 profile/catalog revision 증가, 원 응답 replay, changed key 충돌. 옛 save·replace fingerprint를 직접 비교 |
| replace-full-bundle/deferred-only | 옛 document+authoring 완전 보존, 전부 나중에·선택만인 bundle도 archive, 완전 empty는 skip. 재시작/후속 metadata 변경 후 원 응답 replay |
| exception/crash/journal | 8 transaction 경계의 exception/os._exit, 3 파일 × 3 atomic write 실패, save rollback, 4 관련 reader의 선복구, 복구 자체 중단 후 재복구. 문서·authoring·goals·revision·cache·archive가 전부 전/전부 후 |
| strict cross-language | shape·version·targets·metadata·집합/graph reason 일치, Unicode pair 정렬, deep immutable/독립 직렬화, 새 strict record·request DTO·mock |

- Python 관련 **112 PASS**: 신규 FB-8a 21 + 기존 91. v1/v2 문서 frozen 계산/비교·기존 v1 scenario bytes, FB-1b legacy/v6/통계 parity, FB-1c journal·기존 cache, 시나리오 CRUD, FB-14 독립 collection 회귀 포함. `debug/frontend_fb8a/python-targeted.txt`.
- Dart 서비스 **166 PASS**: 신규 FB-8a 75 + 기존 계약/계획/replace/presets/scenario/v2 DTO 91. `debug/frontend_fb8a/dart-services.txt`.
- process E2E **7 PASS**: 신규 save → 재시작 get → replace → 재시작 get → archive/계산 비교 → idempotent replay → all-deferred 재보관 1건, 기존 plan/replace/presets/scenario/v2 계산·시나리오 6건. `debug/frontend_fb8a/dart-process.txt`.
- 관련 Dart analyze **0 issues**. `debug/frontend_fb8a/dart-analyze.txt`. FB-8a diff check를 확인했다. 전체 Python·fe_gate·golden·stage·커밋·push는 실행하지 않았다. FB-8a 자체 UI/golden 코드·baseline 변경은 없다.
- 학생/인벤토리/이름/선택 profile writer가 metadata를 보존하고, presets collection과 revision이 독립임을 확인했다. scanner/tactic/metadata 소유 코드는 편집하지 않았다.

### FE4-f 연결 메모

1. `loadRepositoryPlan(profileId)`의 `document`와 `authoring`을 같은 초안으로 복원한다. `hasAuthoring=false`여도 DTO 기본값을 사용하며 GET으로 metadata를 다시 저장할 필요는 없다. 선택 순서는 studentOrder, 원래 학생 체인은 stageOrderByStudent다. 학생의 notes/favorite는 배치 학생이면 document.goalMetadata, 나머지 선택 학생이면 authoring.goalMetadata에서 읽는다.
2. 기존 v2 nullable 원본을 유지한다. 배치 단계만 document.phases에 넣고 나중에 단계 전체를 deferred_stages에 넣는다. 목표 편집 중 임시 unassigned와 명시 나중에를 구별하고 ensurePlaced가 후자를 다시 배치하지 않게 한다. 빈 칸은 제거하되 stage ID는 유지한다. 모든 단계가 나중에여도 유효 bundle은 저장 가능하다.
3. 자동 체인·직접 선행 graph의 stable topological 순서를 phase.stages/deferred_stages 배열에 반영한다. backend는 student_order로 비용 배열을 다시 정렬하지 않는다. 같은 학생 배치 prefix/나중에 suffix와 graph·lane 오류는 편집 단계에서 표시한다.
4. `PlanningAuthoring.fromWire({...6키...}, document)`로 엄격한 bundle을 만들고 `saveRepositoryPlan(..., document: document, authoring: authoring, expectedRevision: loaded.revision, idempotencyKey: key)`를 한 번 호출한다. 편집한 authoring을 전부 보내는 쪽을 권장한다. nullable 목표를 기존 정수 v1 보기로 변환하여 저장하지 않는다.
5. 교체는 plan.get revision과 scenario.list collection revision을 읽고 `replaceRepositoryPlan(..., authoring: 새 bundle, expectedScenarioRevision: list.revision, archiveName/Description)`으로 보낸다. archivedScenarioId가 null이면 보관 없음이다. deferred-only도 ID가 반환된다. 활성 metadata와 보관 metadata를 각각 결과에서 읽는다.
6. revision_conflict는 기존 revision_scope별 최신 snapshot을 다시 읽고 초안을 보존하여 충돌 처리한다. authoring_required는 최신 bundle을 함께 복원해 다시 검증해야 하며 자동 clear하지 않는다. cycle/lane_order/stage_order 등의 reason과 stage IDs를 해당 카드에 연결한다. 같은 key의 재시도는 최초 payload/revision 그대로, 수정 요청에는 새 key를 사용한다.

### FB-8b 연결 메모

- 공용 schema/validator와 `PlanningScenarioRecord.storedAuthoring/authoring/hasAuthoring/toWire`를 재사용한다. create/update request DTO·Process/Mock의 typed optional authoring, create 누락=default·update 누락=보존, 명시 null 거부와 옛 fingerprint 호환을 확장한다. 이번에는 그 요청 인자를 추가하지 않았다.
- `_append_record(..., authoring=...)`가 replace 보관을 받으며 read/duplicate는 이미 보존한다. 기존 update에는 orphan 방지 guard만 있다. 전체 CRUD의 명시 metadata 교체·metadata-only record/collection revision·idempotent replay는 FB-8b fixture로 고정해야 한다.
- scenario.list summary의 계산 대상 counts와 comparison 문서 API는 그대로다. deferred/선택 학생 복원은 get.authoring에서 한다. v1 nested document의 기존 의미·누락 default 호환은 유지한다. 새 active 계획 경계는 계속 v2다.
- scenario 편입에서 stage ID를 재발급하면 deferred·직접 edge endpoint·학생 체인까지 함께 remap해야 한다. endpoint 탈락을 조용히 삭제하지 않는다. 프론트 FE4-e/f와 조율한다.

### 사용자 전체 실행·인계

v7 루트에서 실행(결과 `debug\frontend_fb8a\python-full.txt`):

```powershell
New-Item -ItemType Directory -Force debug\frontend_fb8a | Out-Null
Push-Location backend
py -3.11 -X utf8 -m unittest discover -s tests -v *> ..\debug\frontend_fb8a\python-full.txt
$fb8aPythonExit = $LASTEXITCODE
Pop-Location
Get-Content debug\frontend_fb8a\python-full.txt -Tail 12
if ($fb8aPythonExit -ne 0) { throw "FB-8a Python full failed ($fb8aPythonExit)" }
```

- `debug/frontend_fb8a/commit.json`: status=false, whole=본 backend 상태 문서(아래 승인 조사 포함), post_dir=`debug/frontend_fb8a/post`. 공유 서비스의 스캐너 WIP는 pre/post 차이로 분리했다. planning_protocol_client는 수정하지 않았다.
- 사용자 Python 전체 후 두 워커가 멈춘 상태에서 오케스트레이터의 gate·커밋 순서를 따른다. 이 워커는 여기서 코드 편집을 멈춘다. FB-8b는 다음 구현 프롬프트를 받은 뒤 시작한다.

# FB-8 읽기 전용 설계 조사

## 조사 기준·결론 (2026-10-09)

- 시작 HEAD: `a79f5d1d951528f3774fbd61efd6384f9a9c5b93`. FB-14 `780705ff`, FE4-d2 `7cd9592e` 커밋 이후다.
- FD-068(b)·FD-069·FD-071, Flow-3-Order/Flow-4-Save 원본 HTML의 안내 문구, FE4-d1/d2 종료 기록, FB-1b/c 계약, 현재 문서·저장·시나리오·통계 소비자를 읽었다.
- **권장: 계산 문서 v2는 그대로 두고, 활성 계획·시나리오 옆 `authoring` v1에 교차 선행·전체 학생 순서·학생별 논리 단계 순서·나중에 단계 전체를 저장한다.** 나중에 단계는 계산 문서에 넣지 않는다. 목표·선택 학생을 복원할 자료는 저장하되 계산/goals/비교/통계 입력과 분리한다.
- 아래는 **승인 전 계약 제안**이다. 코드·schema·fixture·테스트는 수정하지 않았다. 이 상태 문서만 수정하며 commit.json·gate·커밋은 만들거나 실행하지 않는다. 승인된 구현 프롬프트를 받은 뒤 착수한다.

### 현재 확인한 사실과 FD-068 적용

| 근거 | 현재 동작·설계에 주는 제약 |
|---|---|
| FD-068(b) | 교차 선행은 편집 배치 규칙이다. 계산기에 prerequisite 실행 조건을 추가하는 결정이 아니다. 과거 문구의 “문서 v1 그대로”는 현재 v2를 유지하는 뜻으로 적용 |
| FD-069 | 선행과 같은 칸 허용, 같은 칸에서는 선행→후행으로 자동 정렬. backend는 계산 배열 순서를 그대로 쓰므로 저장 시 이 순서도 검증해야 함 |
| FD-071 | 빈 칸은 저장 때 제거. 순서 n칸은 나중에 제외. 빈 보드 칸 자체를 authoring에 별도로 보존하지 않는 안 |
| Flow-3-Order 원문 | “1순위 · 2순위 · 3순위 · 나중에”, “선행 단계보다 앞 칸에는 놓을 수 없습니다”, “칸이 그대로 계획의 페이즈가 됩니다”. 직접 선행은 분홍 점선, 같은 학생 자동 선행은 회색 실선 |
| Flow-4-Save 원문 | “어느 쪽을 골라도 학생·목표·단계는 한 묶음으로 남아서, 나중에 1~3단계 어디로든 돌아와 고칠 수 있습니다.” ID만 저장해 목표를 버리는 안은 불충분 |
| FE4-d1/d2 | 같은 학생 이동·같은 칸 정렬은 구현됨. 직접 선행/나중에는 FE4-f. d2의 학생별 묶음·부족만·크게/작게는 보기 상태이며 저장 계산 순서를 바꾸지 않음 |

## 1. authoring 모양과 검증 제안

계산 문서 옆의 필드 이름은 wire/시나리오에서 `authoring`, profile 파일에서는 기존 `plan` 옆 `plan_authoring`으로 제안한다. 외부 profile/scenario 저장 version=1과 nested 계산 document.version=1/2는 유지한다. 새 authoring만 version=1이다.

```text
authoring = {
  version: 1,
  prerequisites: [{stage_id, requires_stage_id}],
  deferred_stages: [{stage_id, student_id, name, targets}],
  student_order: [student_id, ...],
  stage_order_by_student: {student_id: [stage_id, ...]},
  goal_metadata: {student_id: {favorite: bool, notes: string}}
}
```

`stage_id`는 후행, `requires_stage_id`는 선행이다. `requires → stage` 방향으로 해석한다. 배열/객체 필드는 모두 필수이며 extra field·null object·잘못된 version/type은 거부한다. `deferred_stages`는 문서 stage와 동일한 **4키**를 쓰되 targets는 v2의 19키 int/null, 범위·0·bond 의미도 그대로다. 현재값이나 선행 성장을 채워 저장하지 않는다. 학생 ID는 카탈로그와 대조하여 지우지 않는다.

### 왜 stage_order_by_student가 필요한가

문서에는 배치한 단계만 들어가고 나중에 단계는 밖에 있으므로, 같은 학생의 원래 1→2→3 순서를 **칸 배치와 독립적으로** 알아야 한다. targets만 비교하면 같은 목표나 all-null 단계의 순서를 알 수 없고, opaque stage ID·이름에서 번호를 추측해서도 안 된다. 따라서 이 map을 추가한다. 이 키를 제외하려면 deferred stage마다 명시적 student_step 같은 추가 ordinal이 필요하다. 기존 4키 stage DTO를 재사용하고 전체 단계 체인을 한 곳에 두는 map 쪽을 권장한다.

| 필드·규칙 | 제안하는 엄격 검증 |
|---|---|
| stage 집합 | document의 모든 stage + deferred_stages. 전체 stage_id 유일, 양쪽 중복 금지. 단계는 배치 또는 나중에 중 한 곳에만 있음 |
| student_order | 중복 없는 고른 학생 순서. 모든 stage의 student_id를 포함. 목표를 아직 만들지 않은 선택 학생도 허용하여 1단계 복원. 미등록 ID도 보존 |
| stage_order_by_student | key 집합은 student_order와 정확히 같음. 각 배열은 그 학생의 stage만 포함하고, 전체 stage 집합을 누락/중복 없이 정확히 덮음. 목표 없는 선택 학생은 [] |
| 같은 학생 자동 선행 | 각 학생 map의 인접 단계 쌍으로 도출. wire prerequisites에는 반복 저장하지 않음. 문서의 학생별 단계 순서는 이 체인의 prefix여야 하며, 나중에는 남은 suffix. 앞 단계를 나중에 두고 뒤 단계만 계산하는 배치는 거부 |
| targets | 학생별 전체 체인 순서로 공용 v2 target validator를 적용. integer 뒤 감소/null은 오류. all-null·동일 목표·부분 목표·명시적 0 허용. 목표만으로 순서를 다시 정하지 않음 |
| deferred_stages 배열 순서 | 나중에 칸의 카드 순서. 같은 학생 자동 선행 및 deferred끼리 직접 선행의 선행→후행 순서를 지킴. student_order는 선택 순서이지 이 배열의 강제 정렬 키가 아님 |
| goal_metadata | **문서에 stage가 없는 선택 학생**(student_order − document 학생 집합)만 정확히 포함. deferred-only/목표 없는 선택 학생의 favorite·notes 보존. 배치 학생 metadata는 document.goal_metadata가 유일한 원본이며 중복 허용하지 않음. v1 시나리오의 배치 학생은 기존 v1 의미 유지 |
| 직접 선행 pair | 양 끝이 전체 stage 집합에 존재. 자기 참조·동일 pair 중복 금지. 같은 학생 pair는 자동 체인과 중복/충돌하므로 거부하고 교차 학생 pair만 저장 |
| 순환 | 직접 선행만 검사하지 않고 **자동 같은 학생 선행 + 직접 선행** 전체 graph가 DAG인지 검사. 자동 선행을 거쳐 생기는 간접 순환도 거부 |
| 앞 칸 금지 | 나중에를 마지막 lane으로 취급. 선행 lane ≤ 후행 lane. deferred 선행→배치 후행은 금지; 배치 선행→deferred 후행은 허용 |
| 같은 칸 | 같은 phase 또는 나중에 안에서 선행의 실제 배열 index < 후행 index. frontend가 stable topological sort한 결과를 전송하고 backend는 검증만 함. backend가 문서를 조용히 재정렬하지 않음 |

검증 순서는 document 파싱 → authoring shape/집합/학생 체인·목표 검증 → 직접 pair → 전체 graph 순환 → lane/칸 안 순서다. 입력 오류는 `invalid_payload`와 details.reason/관련 stage IDs로 드러내는 안이며, 저장된 손상은 `corrupt_data`로 막고 metadata를 버리지 않는다. 입력 authoring의 미지원 version은 invalid_payload, 저장 version 미지원은 migration_required로 제안한다.

읽기 fallback은 `student_order = document 첫 등장 학생`, 학생별 stage_order는 document flatten 순서, prerequisites/deferred_stages/추가 goal_metadata는 빈 값이다. fallback은 현재 학생 값·catalog 정렬에 의존하지 않는다.

범위에 넣지 않는 값: 같은 학생 자동 edge의 복제, 계산용 유효 목표, 카드 상태·비용·보유량, 보기 필터/compact 토글, 프리셋 출처. 직접 연결의 자유 서술 사유(시안 “노트 먼저 쓰기”)가 별도 편집 요구가 되면 그 text 필드는 오케스트레이터가 추가 결정해야 한다. 이번 pair 제안에는 두 ID만 둔다.

## 2. 나중에 목표 저장 위치 비교

| 안 | 복원·계산 영향 | 판단 |
|---|---|---|
| A. authoring에 단계 전체 + 체인/학생 metadata | document v2 shape/비용식 그대로. 계산용 문서는 배치 단계만. 별도 record validator로 ID/체인/선행 정합성 보장 | **권장**. FD-068(b), Flow-4의 한 묶음 복원과 가장 잘 맞음 |
| B. document v2에 calculation-excluded phase 표시 | 현재 phase는 phase_id/name/stages만 엄격히 허용. flag를 추가하면 현재 v2 계약을 깨고, flag를 안 넣고 이름으로 구별하면 모든 계산기가 그 phase를 계산함. goals/비교/통계까지 필터가 필요 | 비권장. “계산 문서 그대로”와 충돌. 예약 phase ID/이름 sentinel도 사용하지 않음 |
| C. document v3에 deferred와 prerequisites 넣기 | 버전을 새로 만들 수는 있으나 Python/Dart parser, v1/v2/v3 계산/파생/비교, 저장·mock 전체에 새 문서 분기 필요 | 현 FD-068(b) 범위에 과함. 선행을 실제 계산 실행 조건으로 바꾸는 후속 결정이 있을 때 재검토 |

권장 A의 원본 단위는 `{document, authoring}`다. 계산에 넘길 때는 `document`만 꺼낸다. deferred-only 학생이 있으면 document.goal_metadata에 억지로 넣지 않고 authoring.goal_metadata에 둔다. 전부 나중에인 문서는 `phases=[]`, 문서 goal_metadata={}이며 goals=[]다. 학생·목표·체인·favorite/notes는 authoring으로 복원한다.

### 나중에가 계산에서 빠지는지 확인한 경로

| 소비 경로 | 코드상 확인·구현 시 불변식 |
|---|---|
| planning.document.calculate | payload는 current_students/inventory/document만. parser/계산기는 document.phases[].stages[]만 순회. authoring을 넣으면 현재 strict payload 오류; 새 계산 필드도 추가하지 않음 |
| plan.get calculation / scenario.list calculation | 공용 planning_summary가 record의 document만 projection으로 계산. authoring/deferred를 붙이지 않으면 비용·부족·병목 모두 제외 |
| goals v1 파생 | goals_from_document는 문서 phase→stage 학생별 마지막 배치 목표만 파생. bond는 문서에만. deferred-only 학생 및 deferred의 높은 목표는 goals에 넣지 않음 |
| planning.scenario.compare | API는 두 **문서** 비교이며 시나리오 ID 저장 조회 API가 아님. final_targets도 phase→stage만 읽음. 두 문서가 같으면 비용/목표 비교는 같고, authoring 차이를 계산 차이로 만들지 않음 |
| scenario.list counts | 현재 phase_count/stage_count/student_count/student_ids는 문서만 집계. 계산 대상 개수 의미 유지. 나중에/선택 학생 수는 FE4-f가 get.authoring에서 따로 읽으며 이 조사에서는 list summary 필드를 늘리지 않음 |
| StatisticsPage | state.goals → planning.plan.calculate + shortages 경로 사용, goal 수는 state.goals.length. goals에 deferred를 넣지 않으면 제외. 기존 통계는 페이즈/인연/authoring을 복원하는 경로가 아님 |

코드 근거: [문서 계산·비교](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/planning_document.py:234>), [goals 파생](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/repository_plan.py:22>), [공용 요약](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/planning_summary.py:9>), [시나리오 집계](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/scenario_store.py:220>), [통계 입력](<C:/Users/brigh/planner_of_plana/BA Planner/v7/frontend/lib/ui/pages/statistics_page.dart:165>).

## 3. 저장·호환 경계 제안

authoring은 FB-14처럼 별도 collection/revision을 두지 않는다. 해당 활성 계획/시나리오 record의 일부이며 **authoring만 변경해도 해당 revision이 오른다**. 문서와 따로 저장하는 2단 호출·별도 sidecar 파일은 사용하지 않는다.

| 경계 | 제안 |
|---|---|
| plan.get | 기존 response에 optional `authoring` object 허용. 저장 필드가 없으면 기존 response shape 유지, 새 Dart DTO가 document 기반 default를 노출. GET으로 필드 생성/추가 revision 증가 없음. FB-1b의 원래 legacy plan 첫 이관은 기존대로 |
| plan.save | 기존 payload + optional authoring. 명시하면 전체 authoring 교체, document/goals/plan_authoring/profile revision/catalog/cache를 기존 두 파일 transaction 안에서 같이 저장. authoring만 바뀌어도 profile revision +1 |
| plan.replace | 기존 payload + optional **새 계획의** authoring. 기존 활성의 document와 authoring을 같은 scenario record로 보존, 새 활성 bundle과 goals/cache를 기존 공통 journal transaction으로 교체. 두 revision 검사/details/최초 응답 replay 유지 |
| scenario.create | 기존 payload + optional authoring. document와 함께 정규화·검증하고 같은 collection atomic write/cache에 저장. scenario revision=0, collection +1, profile revision은 원래 규칙 유지 |
| scenario.get | record에 optional authoring 허용. 누락은 DTO의 default. 기존 v1/v2 nested 문서 모두 읽으며 문서 버전을 강제로 올리지 않음 |
| scenario.update | 기존 payload + optional authoring. 명시하면 전체 교체, record revision+1·collection+1·timestamp/cache 한 atomic write. name/description만 바꾸는 업데이트로 metadata가 사라지지 않아야 함 |
| scenario.duplicate | document_id/record ID만 새로 발급하는 기존 방식. stage ID는 record 범위이므로 그대로 써도 됨. authoring을 deep copy하고 내부 stage 참조 그대로 보존. 원본/복사본 수정 격리 |
| compare | get으로 record bundle을 읽고 document_a/b만 기존 API로 전달. authoring은 원본 복원에만 사용. metadata를 비교 요청 document 안에 넣지 않음 |
| profile/current/inventory writer | 기존 profile dict의 plan_authoring을 보존. 계산 summary는 document로만 재계산. presets collection과 서로 변화 없음 |
| legacy goals.save | 기존 plan_lossy_write 보호를 확장해 직접 선행·deferred·별도 선택/학생 순서를 잃는 쓰기도 차단(details.reasons에 authoring_metadata). 예전 최초 응답 replay는 mutation 없이 허용 |

### optional 필드의 의미를 분리해야 한다

- **create/replace에서 누락**: 새 record/new active의 document 기반 default. replace의 옛 authoring을 새 document에 잘못 붙이지 않는다. 옛 bundle은 보존 scenario로 간다.
- **save/update에서 누락**: 기존 authoring이 없으면 종전 경로. 있으면 그대로 보존하되 incoming document와 정합성을 다시 검증한다. 참조/체인/선택 metadata가 더는 맞지 않는 경우 `invalid_payload(details.reason=authoring_required)`로 막는다. 조용히 clear하거나 고아 edge/deferred를 삭제하지 않는다.
- **명시 object**: full replacement. 지우려면 document 기반 default authoring object를 명시한다. null을 “지움”으로 쓰지 않는다.
- **old record에 누락**: 읽을 때만 default를 파생. 파일 bytes 및 revision을 유지하고 불필요한 이관을 만들지 않는다. 원래 document/goals의 의미를 바꾸지 않는다.
- schema/Dart는 기존 키 집합 및 `+ authoring` 형태만 허용한다. authoring가 있으면 내부는 strict. **현재 strict Dart DTO는 새 필드를 곧바로 거부하므로** FB-8에서 schema·DTO·Process·Mock·shared fixture를 한 슬라이스로 맞춰야 한다. 배포 바이너리 간 버전 불일치를 보장하는 안은 아니다.

### idempotency·복구 주의

명시 authoring을 포함한 요청의 fingerprint에는 canonical document·authoring·기존 revision/보존 정보 전체를 넣는다. 순서 의미가 있는 student_order/stage_order/deferred 배열은 유지하고, prerequisites는 pair 정렬로 canonical하게 만들 수 있다. 입력에 authoring이 **없던** 요청은 기존 fingerprint 알고리즘을 유지하여 FB-1b/c·scenario의 옛 캐시가 계속 replay되어야 한다.

현재 저장 상태에서 “effective authoring”을 계산하여 fingerprint에 넣으면, 나중 편집 후 최초 요청 replay가 달라진다. 따라서 요청의 authoring 필드 존재 여부/값에 따라 fingerprint를 정하고, 캐시 확인을 **현재 snapshot과 omission 호환성 검증보다 먼저** 한다. 최초 응답은 후속 변경·archive 삭제 뒤에도 그대로 반환하며 archive를 다시 만들지 않는다. `{revision}` 캐시와 replace의 세 필드 캐시는 기존 strict 읽기를 유지한다.

기존 [공통 transaction](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/repository_transaction.py:1>)은 profile/catalog/scenario 전체 파일 이미지를 journal에 담는다. authoring을 기존 파일 객체 안에 넣으면 새 파일/lock 순서가 필요 없다. save의 잡힌 실패 rollback 보장은 유지하고, replace의 prepared=전부 전/committed=전부 후 복구 이미지에 authoring도 함께 들어가야 한다. 조회는 기존 guard·선복구 경계를 사용한다. 손상된 authoring을 발견해도 record를 “meta 없음”으로 fallback하지 않는다.

### FB-1c의 빈 활성 예외는 승인 시 확장 필요

현재 [replace](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/repository_store.py:480>)는 `old.plan.phases`가 비면 보존 scenario를 만들지 않는다. **배치 문서는 비었지만 나중에 단계/선택 학생이 남아 있는 활성 계획**에 이 조건을 그대로 쓰면 한 묶음 복원 자료를 잃는다.

권장 조건은 “기존 배치 phases가 있거나, old authoring에 보존할 deferred stage/선택 학생이 있으면 archive”다. 이때 empty calculation document도 유효 scenario로 저장하고 scenario collection revision을 올린다. 문서·authoring 둘 다 비어 있는 옛 empty record는 종전처럼 archived_scenario_id=null·collection revision 불변이다. **이는 FB-1c 빈 조건의 추가 확장 제안이며, 구현 전에 오케스트레이터가 승인할 계약 차이**다.

## 4. 같은 칸의 재화 배분 순서 확인

[calculate_document_projection](<C:/Users/brigh/planner_of_plana/BA Planner/v7/backend/core/planning_document.py:254>)는 phase 배열을 순회하고 그 안의 stage 배열을 순회한다. 각 stage에서 `owned_at_entry = remaining[resource_key]`, 부족량을 계산한 뒤 `remaining = max(0, remaining-required)`로 바로 갱신한다. 같은 페이즈 안 다음 단계도 이 잔량을 받는다. phase resource의 owned는 phase 진입 snapshot이다. graph/student_order를 보고 계산기 내부에서 다시 정렬하지 않는다.

코드 수정·파일 쓰기 없이 계산 전이의 비용 반환만 메모리 mock으로 치환한 확인: 같은 P1에 A(60 credit), B(50 credit), 보유 75를 넣었다.

| 문서 단계 순서 | 단계 진입 보유량 | 단계 부족량 | 총 비용 | 첫 병목 |
|---|---|---|---|---|
| A→B | A=75, B=15 | A=0, B=35 | 110 | B |
| B→A | B=75, A=25 | B=0, A=35 | 110 | A |

이 확인은 재화 순회/배분만 검증한 것이며 실제 성장 비용식을 새로 검증한 테스트는 아니다. FD-069의 같은 칸 선행→후행 순서가 실제 부족 배분에 영향을 준다는 근거다. FE4-f는 lane별 stable topological sort(자동 같은 학생 edge+직접 edge)를 **document.stages 배열에** 반영해야 한다. 기존 `_sortLaneByStep`는 같은 학생이 차지한 자리 안에서만 순서를 바꿔 교차 선행을 처리하지 못한다.

또한 부족이 발생해도 현재 계산기는 후행 비용 계산·가상 성장/재화 소진을 계속한다. 직접 선행을 비용 계산의 실행 gate나 새로운 병목 propagation 규칙으로 추가하지 않는다. 이 FD-068(b) 슬라이스에서 보장하는 것은 배치/배분 순서와 제외 범위이며, “선행이 실제 완료될 때까지 후행 비용 0” 같은 의미는 아니다.

## 5. 영향받는 소비자와 필수 회귀 fixture

### 소비자·소유 경계

| 소비자 | 필요한 대응 |
|---|---|
| Python repository_plan/repository_store/protocol | bundle validator·optional field·legacy 손실 방지·save/replace fingerprint·deferred-only archive. 문서 목표/goals 파생은 공용 기존 경계 재사용 |
| Python scenario_store/protocol | record shape·CRUD/duplicate·optional omission 보존·fingerprint·archive 전달. summary 계산/count는 배치 document 의미 유지 |
| Python planning_document/planning_summary/protocol 계산 | 비용식/응답 필드/문서 shape 변경 없음. target validator 재사용과 순서/제외 회귀만. student_order로 backend 계산 순서를 재정렬하지 않음 |
| contracts repository/scenario schema·fixture·README | 공용 authoring v1 DTO 정의/참조, optional key 호환·semantic validation·오류 reason 문서. 새 계산 문서 version 없음 |
| Dart repository_plan_service/scenario_service | RepositoryPlanState·Save/ReplaceRequest·PlanningScenarioRecord 및 CRUD 요청에 strict authoring DTO. absent default·nullable deferred stage·deep immutable/직렬화 검증 |
| Process/Mock/protocol client validators | 완전 bundle 전달·재시도·metadata-only revision·deep copy. 서비스 공유 scanner WIP가 있으므로 구현 때도 pre/post로 분리 |
| FE4-f PlanFlowDraft/DocumentBoundary/Controller | 학생별 원본 체인·선택 순서·deferred를 복원. 현재 calculationWire는 unassigned를 임시 phase에 포함하므로 **명시 deferred와 목표 편집 중 임시 unassigned를 구별**해야 함. ensurePlaced가 deferred를 다시 배치하지 않게 함 |
| FE4-f order editor/step | 교차 edge 편집·순환/앞 칸 금지·같은 칸 topological sort·나중에 suffix 이동·clear/delete 때 참조 정리의 명시 처리. d2 보기 그룹 정렬을 계산 순서로 오인하지 않음 |
| FE4-e 저장/FE4-h 읽기/시나리오 재편집 | get의 authoring을 DTO→초안으로 연결. can-save는 “모두 배치” 대신 “배치 또는 명시 deferred로 모두 분류·유효”여야 함. 전부 deferred도 저장 가능한 안 |
| 활성 계획 기존 phase editor·시나리오 편입/비교 | 현재 `_incorporateScenario`는 stage ID를 재발급하고 회귀 stage를 건너뜀. 병합 때 active/source 양쪽 stage/deferred/edge/체인 ID를 함께 remap하고 선택 순서 합치기·정합성 검증 필요. endpoint 탈락을 조용히 지우지 않음. bundle을 읽지 않은 기존 save가 손실 쓰기로 막히면 프런트 연결이 필요 |
| 통계·학생 목표·인벤토리 소비자 | state.goals 의미 그대로, deferred 배제. authoring-only active 저장도 profile revision이 올라 변경 알림이 발생하나 비용/goals는 동일할 수 있음 |
| title/account/scan/tactical·seed·metadata 세션 | 프로필 revision 경로는 기존 규칙. 별도 authoring 이관 revision 없음. profile 수정/스캔 commit이 optional 필드를 보존하는지 회귀 요청; 스캐너/tactic/metadata 소유 코드는 FB-8 워커가 고치지 않음 |
| FB-14 preset/group 저장 | 별도 collection. authoring revision과 결합하지 않음. preset/group은 graph나 deferred 단계 ID의 저장소가 아님 |

### 승인 후 먼저 고정할 fixture

아래는 **fixture 목록 제안**이며 이번 조사에서 JSON/test 파일을 만들지 않았다.

| 묶음·사례 | 반드시 확인할 결과 |
|---|---|
| legacy-no-authoring(v1 scenario/v2 plan/scenario) | read default·읽기 bytes/revision 불변, 기존 calculate/compare/goals 결과 동일, 예전 request/response fixture 계속 유효 |
| deferred-targets-null-zero-bond | 19키·null·0·bond 1/100·favorite/notes 보존, 계산용 현재값으로 되쓰지 않음. bool/string/범위/누락/extra 거부 |
| selected-order-with-no-stage/unknown-student | 카탈로그 순서와 다른 선택 순서·미등록·목표 없는 학생 복원. 순서 중복/참조 학생 누락/추가 metadata key 거부 |
| stage-set-and-chain | placed/deferred ID 중복, 없는 stage 참조, 다른 학생 stage가 chain에 포함, chain 누락/중복 거부. all-null/동일 목표에서도 같은 학생 deferred prefix·placed suffix 배치 거부 |
| monotonic-across-deferred-boundary | 배치 마지막→deferred 첫 단계 및 deferred끼리 integer 감소/null 회귀 거부. 동일 목표·all-null 체인 허용 |
| direct-reference/self/duplicate/same-student | 잘못된 pair shape, 없는 endpoint, 자기 참조, 중복 pair, 자동 체인과 중복/역방향 같은 학생 pair 거부 |
| cycles-direct-and-implicit | 직접 cycle + A1→A2·B1→B2 자동 edge를 거쳐 생기는 교차 cycle 모두 거부 |
| same-lane-and-cross-lane | 같은 칸 선행→후행 허용/역순 거부; 앞 칸 금지; 후행 이동뿐 아니라 선행을 뒤로 옮길 때도 검사. deferred→placed 금지, placed→deferred/deferred→deferred 올바른 순서 허용 |
| within-phase-allocation | 위 75/60/50 순서 사례처럼 총량과 첫 병목/진입 잔량 구별. 선행 부족으로 후행 비용 계산을 중단하지 않는 기존 의미 유지 |
| deferred-exclusion | 높은 deferred 목표/희귀 재화/현재값 없는 deferred 학생을 넣어도 document projection/goals/compare/stats는 scheduled-only 기준과 값 동일. deferred 때문에 계산 warning/병목/학생 비교 행이 추가되지 않음 |
| all-deferred/fully-empty | all-deferred의 비용/goals/배치 count=0, 원본은 복원. fully-empty 기존 empty 계약 유지 |
| save/update omission-and-clear | 이름 변경·호환 문서 수정 omission 보존, 참조를 깨는 omission 오류·무변경, 명시 default object clear, null clear 거부, legacy goals 손실 오류 |
| metadata-only-revision/idempotency | authoring만 수정하면 record/profile 또는 scenario/collection revision 정확히 +1. 동일 key replay, 같은 key 다른 metadata 충돌, 후속 변경 뒤 최초 replay. 옛 fingerprint/response 캐시도 replay |
| replace-full-bundle/deferred-only | 원래 document+authoring archive 완전 보존·새 active bundle/goals 일치. all-deferred old archive 생성(승인 확장), 양쪽 빈 old archive 없음 |
| duplicate-and-remap | 복제본 stage 참조·deferred chain 유지, deep copy 격리. 편입의 ID remap 전체 참조 보존/탈락 endpoint 명시 오류 |
| exception/crash/journal | save 잡힌 profile/catalog 실패 원본 bytes, replace 각 write/commit 사이 예외·process 중단 후 document+authoring+goals+cache 전부 전/전부 후, 최초 replay archive 1개 |
| process E2E | bundle 포함 plan save→재시작 get→replace→재시작 active/보존 scenario get→기존 document compare. scenario create→update→duplicate→재시작 get, stale/replay 함께 |
| strict cross-language/stored-corruption | Python schema+semantic/Dart DTO 동일 판정·왕복·불변. 손상 authoring 읽기/저장 오류·원본 유지, UI fallback으로 빈 authoring 처리 금지 |

### 오케스트레이터가 구현 전에 승인할 핵심

1. 문서 v2 유지·authoring 전체 단계 보관 안 A와 6키 모양(추가 student_stage 체인 및 deferred-only/목표 없는 학생 metadata 범위).
2. scheduled prefix/deferred suffix, 자동+직접 graph cycle/같은 칸 배열 순서 검증, 목표 없는 선택 학생 복원 정책.
3. optional authoring의 create/replace default와 save/update 보존·손실 오류, 옛 fingerprint 호환.
4. FB-1c의 “빈 phases면 archive 없음”을 **authoring도 비었을 때만**으로 확장하여 deferred-only bundle 보존.

조사를 마쳤고 구현은 시작하지 않았다. 비용 순회 메모리 확인 외 Python/Dart 제품 테스트·gate를 실행하지 않았다. 승인 및 구현 프롬프트를 기다리며 여기서 멈춘다.

# FB-14 단계 프리셋·내 그룹 저장

## 착수 (2026-10-09)

- 시작 SHA: `e2502aed0f1ae145d474ca1055a522b705cc5ad8`. FB-1c `6fcd5fa0` 커밋 이후 HEAD에서 편집을 재개했다.
- FB-14 행, FD-074(b), 오케스트레이터 2026-10-09 14:30, tactical collection revision 방식, FE4-c 메모리 프리셋 모델과 적용 확장 규칙을 읽었다.
- profile별 독립 collection revision·전체 교체·idempotency. nullable 목표와 단계 이름을 저장하며, 미등록 학생 ID를 보존한다. 프로필/활성 계획 revision과 서로 영향을 주지 않는다.
- 상한: 프리셋 100개·각 50단계·총 1,000단계; 그룹 100개·각 1,000 ID·총 10,000 membership; 이름 120·ID 128 Unicode code point. 개인 재사용 목록에 여유를 두면서 JSONL 크기와 검증 작업량을 제한한다. 게임 데이터 개수에서 도출한 상한이 아니다.
- 빈 목록·빈 프리셋·빈 그룹을 허용한다. 같은 그룹 안 학생 ID 중복은 거부하고, 그룹 간 겹침은 허용한다. preset/group ID는 별도 namespace다.
- UI·스캐너·tactic·metadata는 수정하지 않는다. 공유 서비스 WIP는 pre/post로 보존하며 gate·stage·커밋·push는 하지 않는다.

## 구현·직접 검증 종료 (2026-10-09)

FB-14 backend·계약·Dart 서비스 구현과 직접 검증을 마쳤다. 코드 편집을 멈추고 사용자 Python 전체 실행을 기다린다. gate·stage·커밋·push는 하지 않았다. 화면 및 widget/golden 코드는 수정하지 않았으며 golden 변화는 0을 예상한다.

### 계약·저장 요약

| 항목 | 확정 구현 |
|---|---|
| get | `repository.presets.get {profile_id}` → `{profile_id, revision, stage_presets, student_groups}` |
| save | `repository.presets.save {profile_id, expected_revision, idempotency_key, stage_presets, student_groups}` → `{revision}`; 두 목록 전체 교체 |
| revision | 이 묶음의 collection revision. profile/state/plan/scenario revision과 독립. profile 변경으로 stale이 되지 않으며 프리셋 저장으로 plan 저장이 stale이 되지 않음 |
| 목표 | 19 key 모두 필수, int/null. bond_rank는 null 또는 1–100, 다른 키의 0은 실제 목표. 누적 절대 목표이므로 integer 뒤 null/더 작은 integer 거부 |
| 단계 | `{name, targets}`. 원본 nullable/부분 목표 보존, 현재값·성장 선행 조건·비용 계산을 저장에 섞지 않음 |
| 그룹 | `{group_id, name, student_ids}`. 카탈로그 미등록 ID·순서 보존. 그룹 안 중복 거부, 그룹 간 겹침 허용 |
| ID·이름 | preset/group 각각의 namespace 안 ID 유일. 두 종류끼리 같은 ID 허용. opaque ID는 보존, 이름은 trim; 이름 중복 허용 |
| 빈 데이터 | [] 전체 교체·빈 stages·빈 student_ids·all-null 단계 허용 |
| 새/v6/legacy | 유효 프로필에 파일이 없으면 논리적인 빈 revision 0. get은 파일 생성/계획 이관/프로필 revision 변경을 하지 않음. 새 프로필·v6 가져오기 transaction에 추가 파일 쓰기가 필요하지 않음 |
| 파일·잠금 | `presets/{profile_id}.json`에 두 목록/revision/idempotency 한 번의 atomic write. 기존 OS repository guard 공유, pending plan journal 복구 뒤 조회/저장. 프로필 삭제와 직렬화 |
| 삭제 | profile 삭제 때 파일도 삭제. 예외 발생 시 profile/catalog와 프리셋 원본 bytes 함께 복원 |
| 재시도 | canonical 전체 save(expected_revision 포함) fingerprint. 동일 key/request는 나중 저장·재시작 후에도 최초 revision 응답 replay. 변경된 요청은 idempotency_conflict |
| 오류 | invalid_payload·revision_conflict(details.current_revision = collection revision)·idempotency_conflict·repository_busy·persistence_failed 재사용. 손상 파일은 corrupt_data, 지원하지 않는 저장 version은 migration_required. 빈 데이터로 덮지 않음 |

Python은 문서와 프리셋의 목표 검증을 `planning_targets_from_wire` 공용 경계로 뽑았다. 비용/정규화는 복제하지 않았고 v1 성장 검증·오류 의미를 유지했다. Dart는 기존 문서 v2 stage target parser를 재사용하고 프리셋 누적 회귀·중복·상한을 추가 검증한다. `RepositoryPresetsService` 별도 capability를 두어 기존 `RepositoryService` 소비자·테스트 더블을 깨지 않는다. Process/Mock 둘 다 구현한다. DTO는 deep immutable이며 toWire 결과는 분리된 복사본이다.

### 정책 fixture·상한 근거

공유 fixture: `contracts/fixtures/repository_presets_v1.json` 43건. schema_valid와 Python/Dart semantic valid를 구별했다. JSON Schema가 shape/range/per-array cap을 검증하고, object ID 중복·단계 회귀·전체 nested cap은 DTO 검증 책임이다.

| 정책 | 검증 |
|---|---|
| all-null → 명시적 0·부분 성장 목표 → max·bond 1/100 | 원본 그대로 저장·왕복; 성장 선행 조건을 합성하지 않음 |
| 미등록 future-student·그룹 간 aru 겹침·preset/group 동일 ID·이름 중복 | 보존/허용 |
| 빈 묶음·빈 프리셋·빈 그룹 | 저장·clear·재시작 조회 |
| bool/string/float 목표, bond 0, 누락/extra key·field, 빈 key/name/ID | invalid_payload/strict Dart 거부 |
| preset/group ID 중복, 그룹 내 학생 중복, integer→null/감소 | 명시적 거부 |
| 프리셋 100·각 50·총 1,000단계 / 그룹 100·각 1,000 ID·총 10,000 membership | Python/Dart 경계값과 초과값 생성 테스트 |
| 이름 120·ID 128 Unicode code point | fixture maxLength; 이름 emoji 120/121 경계 Python/Dart 검증. raw 입력 길이를 검사한 뒤 이름 trim |
| profile/plan 저장 ↔ 프리셋 저장 | revision 독립, 서로 파일 변경 없음; 두 프로필 격리 |
| 신규·v6 가져오기·legacy 조회 | 빈 revision 0; legacy presets get/save로 plan 이관이 일어나지 않음 |
| stale·key 충돌·이전 응답 replay | 무변경·details·재시작 이후 최초 응답 |
| before_write / before_fsync / before_replace 예외 | 최초/기존 파일 모두 원본 bytes·두 목록·revision·cache 유지, temp 정리 |
| 프로필 삭제 파일 unlink 실패 | profile/catalog/presets bytes 모두 복원; 성공 시 파일 제거 |
| 손상 JSON/shape/revision/cache/회귀 | 읽기·저장 모두 오류, 원본 bytes 유지 |
| live save 중 다른 thread get/delete | repository_busy; 잠금 해제 후 정상 삭제. mock 동시 save는 한 요청만 성공 |

상한은 개인 재사용 목록을 넉넉하게 허용하면서 IPC payload·저장 크기와 검증 작업량을 제한하기 위해 정했다. 현재 게임 학생/기본 프리셋 개수에서 도출한 값이 아니다. 전체 단계·membership cap으로 중첩 배열의 곱이 무제한 커지는 것을 막고, 미등록/향후 학생 ID는 정해진 범위 안에서 그대로 보존한다. 필터 프리셋은 범위 밖이다.

### 직접 검증·회귀 결과

- Python **91 OK**: FB-14 11 + repository 계약/저장/parity/FB-1b/FB-1c + planning document v1/v2 + scenario store/protocol/contract. 로그 `debug/frontend_fb14/python-targeted.txt`.
- Dart 계약·DTO·mock·기존 서비스 **70 passed**: FB-14 49 + repository contract/FB-1b/FB-1c 서비스 21. 로그 `debug/frontend_fb14/dart-targeted.txt`.
- Process E2E **4 passed**: FB-14 save→restart get→stale/replay→clear→restart original replay→delete, 기존 repository restart·FB-1b·FB-1c 각 1. 로그 `debug/frontend_fb14/process-e2e.txt`.
- 대상 6파일 `dart analyze`: No issues found (`debug/frontend_fb14/dart-analyze.txt`). 공유 process/mock는 FB-14 추가 메서드 블록만 format했다.
- `codealmanac validate`: ok. 인계 3-way merge 8파일 clean, 공유 mock/process의 기존 스캐너 WIP 제외·나머지 블록 동일. planning_protocol_client 미수정, 보호된 tracked 파일 시작 후 변경 0, index 미수정.
- v1 projection/comparison frozen output·v1 scenario bytes, nullable v2, v6 가져오기 및 기존 교체 journal 회귀 모두 통과. 계산·시나리오 비용 결과 변경 없음.
- Python 전체는 **미실행**이며 다음 사용자 단계다. fe_gate·golden 갱신·stage·커밋·push는 실행하지 않았다.

### 프런트 연결 메모 (FE4-c 이후)

1. 선택 프로필별 `RepositoryPresetsService.loadRepositoryPresets(profileId)`로 묶음과 collection revision을 로드한다. Process/Mock는 이 capability를 구현하며 repository_service.dart가 DTO/service를 export한다. profile revision을 expected_revision으로 쓰지 않는다.
2. FE4-c의 `PlanElementPreset`은 `List<Map<String,int>>` sparse 메모리 모델이고 단계 이름 필드가 없다. 저장에는 `RepositoryStagePreset`/`RepositoryPresetStage(name, targets)`의 **19키 nullable** 원본을 쓴다. 새 sparse 초안을 저장할 때 누락 키는 null로 채우며 현재값으로 채우지 않는다. 프런트는 적용 모델에 단계 이름을 확장해 저장 이름을 연결해야 한다.
3. 프리셋 적용 때만 non-null 목표를 sparse map으로 넘겨 기존 `PlanFlowGoalEditor._stagesForMode` 확장 규칙(첫 단계 현재값, 다음 단계 직전 유효값, 성장 정규화, 현재값보다 낮지 않음, 증가 없는 단계 제거)을 사용한다. 이 결과를 원본 저장 프리셋에 되쓰지 않는다. 저장 단계 회귀는 서버/DTO가 거부하므로 조용한 자동 접기 대신 사용자 편집에 드러낸다.
4. `RepositoryStudentGroup`의 ID 목록을 저장 모델에 보관한다. 현재 카탈로그와의 교집합은 선택/표시용으로만 계산하며, 미등록 ID를 저장 요청에서 필터링하지 않는다. 그룹 간 같은 학생은 유효하다.
5. 저장은 `saveRepositoryPresets(RepositoryPresetsSaveRequest(profileId: profileId, expectedRevision: loaded.revision, idempotencyKey: ..., stagePresets: 전체 목록, studentGroups: 전체 목록))`. 변경하지 않은 반대쪽 목록도 포함한다. 한 사용자 저장 시도에 key를 한 번 발급하고 네트워크/busy/persistence 재시도는 동일 request/key를 사용한다. 수정된 내용은 새 key다.
6. 성공 응답의 revision은 최초 replay 값일 수 있으므로 뒤이어 get으로 최신 목록/revision을 다시 읽는다. `revision_conflict`는 details.current_revision을 참고해 reload·사용자 재편집으로 해결하고, stale 초안을 최신 revision으로 자동 재전송하지 않는다. idempotency_conflict는 같은 key에 다른 요청을 썼다는 오류다. repository_busy/persistence_failed는 retryable이며 입력을 보존한다. profile 삭제/전환 때 해당 draft/revision을 분리·폐기한다.
7. 저장 묶음은 활성 계획과 별도다. 프리셋/그룹 저장에 plan.save를 추가 호출할 필요가 없고, 활성 계획 저장으로 프리셋 revision이 바뀌지 않는다. 필터 chip 저장은 연결하지 않는다.

### 인계·사용자 실행 단계

- `debug/frontend_fb14/commit.json`: status=false, modified/added 목록, whole=`almanac/workflows/frontend-redesign-status-backend.md`, post_dir=`debug/frontend_fb14/post`.
- pre/post 사본을 보존한다. 공유 mock/process의 FB-14 추가분을 제거하면 pre와 같아야 하고, HEAD/pre/post 3-way 적용 후 추가분을 제거하면 HEAD와 같아야 한다. 스캐너 WIP를 commit 후보에 섞지 않는다. planning_protocol_client.dart는 수정하지 않았다.
- 인계 검증은 `debug/frontend_fb14/handoff-verification.json`; 기존 index를 건드리지 않는다. baseline 폴더는 manifest whole에 없다.
- 먼저 v7 루트에서 아래 Python 전체 명령을 실행하고 `debug/frontend_fb14/python-full.txt` 결과를 확인한다. 이후 gate·커밋은 두 워커가 멈춘 뒤 사용자/오케스트레이터가 진행한다. 이 워커는 여기서 멈춘다.

```powershell
Push-Location backend
py -3.11 -X utf8 -m unittest discover -s tests -v 2>&1 | Tee-Object -FilePath ..\debug\frontend_fb14\python-full.txt
$fb14PythonExit = $LASTEXITCODE
Pop-Location
if ($fb14PythonExit -ne 0) { throw "FB-14 Python 전체 실패: $fb14PythonExit" }
```

# FB-1c 활성 계획 교체·시나리오 보존

## 착수 (2026-10-09)

- 시작 SHA: `b4bb199ae639dca7786edd691f7378f03f8bae84`. FB-1b `11426131` 커밋 뒤 편집을 재개했다.
- FB-1 읽기 전용 조사의 repository 계약·저장 주의·필수 회귀, FB-1b 종료 기록, FD-067(a)·FD-088과 runtime 경계를 읽었다.
- replace는 profile/catalog/scenario 공통 잠금 아래 journal로 교체 전/후 한쪽 전체만 복구한다. 관련 읽기도 같은 경계에서 먼저 복구한다.
- phases=[]는 archive 없음·scenario revision 유지. 문서/goals/revision/idempotency 응답은 함께 저장한다.
- UI·스캐너·tactic·metadata 파일은 수정하지 않는다. 기존 서비스 WIP는 pre에 보존한다. gate·stage·커밋·push는 하지 않는다.

## 구현·직접 검증 종료 (2026-10-09)

FB-1c의 backend·계약·Dart 서비스 구현을 마쳤다. Python 전체는 사용자 단계로 남긴다.
gate·stage·커밋·push는 하지 않았다. UI·widget/golden·scanner/tactic·metadata 파일은 고치지 않았다.

### 교체 계약

| 항목 | 확정 계약 |
| --- | --- |
| 요청 | repository.plan.replace `{profile_id, expected_revision, expected_scenario_revision, idempotency_key, document, archive_name, archive_description}` |
| 응답 | `{revision, scenario_revision, archived_scenario_id}`. strict RepositoryPlanReplaceResult |
| 입력 | 새 document는 v2/kind=plan. 기존 nullable 목표·metadata·회귀 검증 재사용. 두 revision은 non-bool int≥0. 보존명은 trim 뒤 nonempty, 설명은 빈 문자열 허용 |
| 보존 | 기존 phases가 있으면 scenario record revision=0, base_profile_revision=교체 직전 profile revision. collection revision +1 |
| 문서 정체성 | kind=scenario·document_id=새 scenario ID. 원래 문서 이름·phase/stage ID·순서·목표·metadata는 그대로. 기존 비교는 서로 다른 document ID를 요구하므로 반복 보존본에도 고유 ID 필요 |
| 빈 활성 | phases=[]면 archived_scenario_id=null, collection revision·scenario 파일 그대로. 없던 파일을 만들지 않음. 두 expected revision 검사는 유지 |
| 활성 저장 | 새 문서·학생별 최종 단계 goals 파생·profile revision +1·catalog summary·멱등 응답을 같은 교체 transaction에 저장 |
| 충돌 | revision_conflict details `{revision_scope: profile\|scenario\|both, current_revision, current_scenario_revision}`. expected_scenario_revision은 **collection** revision |
| 재시도 | 같은 key/작업/canonical 문서/trim 보존 정보/두 expected revision은 최초 응답을 반환. 후속 저장·archive 삭제 후에도 재생성 안 함. 바뀌면 idempotency_conflict |
| 이전 캐시 | 기존 `{revision}`과 새 세 필드 response를 모두 엄격히 읽음. 일반 저장과 replace는 profile key 공간 공유. 기존 scenario CRUD 캐시는 그대로 |

archive outer name/description은 호출자 입력이며 문서 내부 name은 기존 값을 보존한다.
현재 학생·인벤토리·다른 시나리오는 변경하지 않는다. 인연 목표는 문서에만 남고 goals에는 없다.
문서 계산/비용식·FB-11b 선물 계산은 변경하지 않았다. Mock 비용식도 추가하지 않았다.

### 공용 잠금·journal 복구

`backend/core/repository_transaction.py`가 JsonRepository와 ScenarioStore의 경계를 소유한다.
고정 순서는 **root별 OS guard → 호환 marker → journal 복구 → profile/catalog/scenario 접근**이다.
서로 다른 store 잠금을 겹쳐 잡지 않는다. 같은 thread/root의 nested callback은 guard를 재사용하고,
다른 thread/process는 retryable repository_busy를 받는다. Windows byte-range lock은 프로세스
중단 때 OS가 해제한다(다른 OS는 flock). `.repository.guard`는 남아도 잠금 소유를 뜻하지 않는다.
guard를 얻은 뒤 이 구현의 `.repository.lock` marker만 다시 쓸 수 있으며, 과거/수동/알 수 없는
marker는 추측하여 제거하지 않고 busy로 막는다. 잠금 정리 실패도 guard를 해제하여 재시도를 허용한다.

replace는 `.repository.transaction.json`에 원본 바이트/완성본과 SHA256을 fsync하여 prepared로
쓴 뒤 profile → catalog → (archive가 있으면) scenario 순서로 각 파일을 fsync+atomic replace한다.
committed journal을 fsync+atomic replace한 뒤 journal을 지운다. **prepared는 원본 전체 복원,
committed는 완성본 전체 재적용**이다. 복구 자체가 중단되면 남은 journal로 다시 수행한다.
잡힌 실패는 persistence_failed이고 committed 이후 실패는 보존된 최초 응답으로 재시도한다.
손상된 journal은 corrupt_data로 막으며 혼합 snapshot이나 빈 문서를 반환하지 않는다.

plan.get/state.get/scenario.list/get뿐 아니라 profile.list/current·repository/scenario writer도
같은 guard에서 먼저 복구한다. 한 조회 안의 profile/current/collection snapshot은 잠금 아래 읽는다.
FB-1b 이관과 일반 두 파일 저장의 기존 예외 rollback은 유지한다. 이번 journal의 다중 파일
프로세스 중단 복구 보장은 replace transaction에 적용한다.

### fixture·실패 주입·회귀

공유 wire fixture `contracts/fixtures/repository_plan_replace_v1.json`은 20개 valid/invalid 사례다.
완전 요청·archive/null 응답·두 revision 충돌 details, bool/음수 revision·누락/추가 key·공백 보존명·
null 설명·빈 key·scenario 활성 문서·잘못된 archive ID·기존 응답만 있는 replace를 거부한다.
v1 활성 문서 거부는 Dart DTO 테스트에서도 별도로 확인한다.
기존 idempotency 저장 파일의 `{revision}`을 **읽는 호환성**과 replace 응답의 **세 필드 요구**는 별개다.

| 실패/경계 | 검사한 결과 |
| --- | --- |
| before_journal / prepared / profile·catalog·scenario 쓰기 뒤 / before_commit | 잡힌 예외 및 os._exit(73) 뒤 원본 3파일 바이트 전체 복원 |
| committed / journal 제거 뒤 | 예외 및 os._exit 뒤 교체 후 전체 유지. 같은 key 재시도 archive 1개 |
| 파일별 before_write / before_fsync / before_replace | 3×3 실패 모두 원본 전체·revision/goals/cache 보존 |
| 외부 process.kill | 살아 있을 때 조회 busy, 종료 뒤 OS guard 해제·잔여 marker/journal로 원본 전체 복구 |
| 관련 읽기 4경로 | plan/state/scenario list/get 각각 prepared·committed 중단 상태를 먼저 복구하고 반환 |
| 복구 도중 파일 실패 / marker 정리 실패 | journal 유지·재시도 가능, guard가 영구 busy로 남지 않음 |
| 손상 journal header/path/checksum | corrupt_data, 대상 파일을 추가로 덮지 않음 |
| 빈 활성·scenario 파일 없음 | collection 증가/생성 없음. stale collection revision은 명시적 충돌 |
| 기존 scenario·현재 상태 | 원래 scenario record 내용·현재 students/inventory 보존. archive base는 교체 직전 값 |

| 직접 검증 | 결과/로그 |
| --- | --- |
| Python 14모듈: replace 14건 + FB-1b·repository·v6·seed·scenario·문서 v1/v2·계산 parity·shortage | 90건 통과, debug/frontend_fb1c/python-targeted.txt |
| Dart DTO/mock 7건 + FB-1b·repository fixture·protocol client·mock scanner | 46건 통과, debug/frontend_fb1c/dart-targeted.txt |
| Process 새 교체 왕복 + 기존 FB-1b/repository/scenario | 4건 통과, debug/frontend_fb1c/dart-process.txt |
| analyze / almanac | 통과: services·새 테스트 No issues, almanac 42페이지. dart-analyze.txt, almanac-validate.txt |
| 슬라이스 diff·인계 | 통과: 수정 9파일 병합 충돌 없음·pre 11파일·post 15파일 고정·추가 파일 공백 오류 없음·스캐너 WIP 제외·보호 파일 및 index 변경 없음. diff-check-owned.txt, handoff-verification.json |
| 전역 git diff --check | exit 2: 소유 범위 밖 frontend-redesign-orchestrator-log.md:467의 new blank line at EOF. diff-check.txt. 로그 소유자에게 EOF 빈 줄 정리 요청; 이번 slice에서 해당 로그를 수정하지 않음 |
| Python 전체 / 공통 gate | 미실행. 전체 명령 아래. golden 변경 0 예상·baseline 포함 안 함 |

새 process E2E는 legacy 첫 get(4→5) → v2 save(6) → 기존 scenario 생성(collection 1) →
replace(profile 7, collection 2) → backend 재시작 → active/state/goals·archive 재조회 →
기존 시나리오 유지·보존본의 실제 비용/인연 목표 비교·멱등 재시도/두 revision 충돌까지 묶었다.
v6 가져오기/seed 반복, 시나리오 v1 frozen 비용·비교, FB-1a nullable 문서와 기존 goals 비용·
재화·부족량 회귀도 통과했다. 비교 시 archive ID를 새 문서 ID로 써야 한다는 점을 process에서 확인했다.

### FE4-e 프런트 연결 메모

1. FE4-h의 `loadRepositoryPlan(profileId)`와 `loadRepositoryState`로 같은 profile revision을 확보한다.
   `listScenarios(profileId)`의 revision을 **expectedScenarioRevision**으로 사용하며 그 결과의
   currentProfileRevision도 같아야 한다. 다르면 재조회하여 한 기준으로 미리보기한다.
2. 적용 초안은 v2/kind=plan이며 19개 nullable 목표와 goal_metadata를 그대로 둔다. 저장 전
   document projection 미리보기를 사용한다. "페이즈로 추가"는 합친 문서 save,
   "이걸로 바꾸기"만 아래 단일 replace를 쓴다. UI가 별도로 scenario.create/goals.save를 하지 않는다.
3. 호출 전 초안·두 expected revision·보존명/설명·idempotency key를 고정한다. 성공 뒤에는
   active/state/scenario 목록을 재조회하고 UI/cache의 두 revision을 갱신한다. archive ID가 null이면
   빈 기존 계획이어서 보존본이 없다는 뜻이다. 오래된 성공 재시도의 반환 revision이 현재값보다
   낮을 수 있으므로 반환값만 현재 snapshot으로 덮지 않는다.
4. revision_conflict는 details.revision_scope로 profile/scenario/both를 구별한다. 초안을 보존한 채
   재조회·다시 미리보기한다. timeout/disconnect/repository_busy/persistence_failed는 같은 고정 요청과
   key로 재시도한다(이미 committed일 수 있음). idempotency_conflict에서 새 key로 자동 교체하지 않는다.
   invalid_payload·corrupt_data·migration_required는 오류를 표시하고 빈 활성/빈 목록으로 처리하지 않는다.
5. RepositoryPlanService capability가 replace 메서드를 추가했다. 이 capability를 구현한 프런트 테스트
   대역은 새 메서드를 추가해야 한다. 기존 RepositoryService interface는 그대로다. 화면·widget/golden
   대역과 실제 교체 버튼·인연 게이지 연결은 프런트 소유이며 이번 slice에서 수정하지 않았다.

```dart
final plans = service as RepositoryPlanService;
final result = await plans.replaceRepositoryPlan(
  profileId: profileId,
  document: retainedDraftV2,
  expectedRevision: retainedProfileRevision,
  expectedScenarioRevision: retainedScenarioCollectionRevision,
  idempotencyKey: retainedReplaceKey,
  archiveName: retainedArchiveName,
  archiveDescription: retainedArchiveDescription,
);
// 성공 뒤 active/state/scenario를 다시 읽어 갱신한다.
```

### 사용자 Python 전체·인계·동결

루트에서 실행하고 결과를 debug/frontend_fb1c/python-full.txt에 남긴다.

```powershell
Push-Location backend
py -3.11 -m unittest discover -s tests -v 2>&1 | Tee-Object -FilePath ..\debug\frontend_fb1c\python-full.txt
$fb1cPythonExit = $LASTEXITCODE
Pop-Location
if ($fb1cPythonExit -ne 0) { throw "FB-1c Python full failed: $fb1cPythonExit" }
```

debug/frontend_fb1c/commit.json은 status=false, whole=이 backend 상태 문서,
post_dir=debug/frontend_fb1c/post다. pre/post 사본을 고정하고 기존 스캐너 WIP는 슬라이스에서 제외한다.
planning_protocol_client.dart는 변경하지 않고 시작 pre와 일치하는지 확인한다.
gate·stage·커밋·push는 하지 않는다. 여기서 코드 편집을 멈추며 후속 작업은 오케스트레이터 프롬프트를 기다린다.

# FB-1b 활성 계획 저장·legacy 이관

## 착수 (2026-10-08)

- 시작 SHA: `e9baa24959e9f7b26ce08f8113c60c0118f06d1b`. FB-11b `7d0af068` 커밋을 확인하고 편집을 재개했다.
- 워크플로 FB-1 전체·분할 FB-1b·밤 2·병렬 규칙, 로그 14:05·21:34, 아래 FB-1 설계 조사의 repository/파생/첫 로드/소비자, FD-003·026·027·049·067·083·138을 읽었다. [@workflow]
- 중복 legacy goal은 각 항목 비용 합산을 문서의 누적 단계로 안전하게 보존할 수 없으므로 `legacy_goals_conflict`로 막고 원본 파일을 보존한다. 자동 병합/삭제하지 않는다. 먼저 정책 fixture를 고정한다.
- 문서는 v2(kind=plan), 목표는 원래 int/null·bond는 항상 null로 이관한다. 저장·goals 파생·revision은 하나의 repository transaction이다. replace는 FB-1c로 남긴다.
- UI·위젯/golden·스캐너·tactic·metadata 소유 파일은 수정하지 않는다. 서비스 기존 변경을 pre에 보존하고 index·커밋·push는 하지 않는다.

## 구현·직접 검증 완료

FB-1b를 구현했다. **Python 전체·두 워커 종료 뒤 공통 gate·커밋은 사용자 단계**다.
화면과 위젯/golden 코드는 수정하지 않았다. 기존 스캐너 서비스 변경은 pre에 보존했다.

### 계약과 저장 경계

| 경계 | FB-1b 계약 |
| --- | --- |
| repository.plan.get | 입력 `{profile_id}`; 출력 `{profile_id, revision, document, calculation}`. document는 v2/kind=plan |
| repository.plan.save | 입력 `{profile_id, expected_revision, idempotency_key, document}`; 출력 `{revision}`. v1/scenario 문서·회귀·잘못된 목표/metadata 거부 |
| 저장 형식 | profile/catalog 바깥 version=1 유지. profile의 명시적 plan 필드 유무로 이관 여부 구별. plan이 있으면 goals fallback 없음 |
| goals 파생 | phase→stage 순 학생별 마지막 단계, 첫 등장 학생 순서. 18개 목표를 원래 int/null로 대응. favorite/notes 보존, bond는 문서에만 |
| revision·멱등성 | 문서/goals/idempotency를 profile atomic write, catalog revision 함께 갱신. 같은 key·작업·canonical 문서·expected revision은 최초 응답 재사용. 달라지면 idempotency_conflict |
| 첫 로드 | state.get/plan.get 공통 함수. legacy만 lock 아래 재확인 후 한 번 이관·revision +1. 경합은 retryable repository_busy, 오래된 expected revision은 revision_conflict |
| 신규/v6 import | 생성 transaction 안에 문서·파생 goals를 넣고 revision=0. 별도 첫 로드 이관 없음. v6 원본 읽기 전용 |
| 계산 요약 | scenario.list와 공용 planning_summary 경계. 같은 profile snapshot의 문서/students/inventory 사용. 기존 6-key PlanningScenarioCalculationSummary, 실패는 null |
| legacy writer | goals.save도 같은 변환·transaction. 여러 phase / 학생당 여러 stage / 명시적 bond 목표를 잃으면 plan_lossy_write(details.reasons) |
| 실패 | 중복 목표 legacy_goals_conflict(details.student_ids), 손상/변환 불가 저장 데이터 corrupt_data. 파일을 빈 문서로 덮지 않음. 잡힌 저장 실패에는 profile/catalog 원본 바이트 rollback |

repository.state.get의 기존 다섯 필드와 RepositoryService의 기존 interface는 바꾸지 않았다.
추가 RepositoryPlanService capability를 ProcessAppService·MockAppService가 구현한다.
RepositoryPlanState/SaveRequest는 strict DTO이며 문서 목표·metadata가 불변이다. Dart에는
성장 비용식을 복제하지 않았다. mock은 변환·revision·멱등성·손실 방지를 재현하고 기존 빈
mock 문서 projection을 요약한다(실제 비용 검증은 process 경로). mock 계산 실패도 null이다.
학생/인벤토리/프로필 수정은 저장 목표를 만들거나 고치지 않고 revision·계산 요약만 바꾼다.

### 먼저 고정한 이관 정책 fixture

`contracts/fixtures/repository_plan_migration_v1.json`은 구현 전에 고정한 8개 정책이다.
`repository_plan_v1.json`은 추가 16개 request/response 판정이다. Python schema와 Dart validator가
동일 fixture를 읽는다. schema의 구조 검사 외 학생 ID 집합·중복 ID·누적 회귀는 기존 parser가 검사한다.

| 정책 fixture | 결과와 근거 |
| --- | --- |
| null_bond_known_current | 현재 인연 35를 알아도 목표 bond=null. 기존 목표 level=10만 옮김 |
| null_bond_unknown_current | 현재 인연 모름도 bond=null. 1을 지어내지 않음 |
| all_null_goal | 학생 단계 유지, 19-key all-null. favorite=false와 원래 공백 메모 보존. 단계 표시명만 trim/fallback |
| partial_goal_explicit_zero | 전무 레벨 25·애장품 1·HP 0만 그대로, 나머지 null. 계산 선행 조건을 목표에 되쓰지 않음 |
| empty_legacy | phases=[]·goal_metadata={} 저장, 최초 로드 revision +1 |
| duplicate_goals | 같은 학생 level 10/20의 비용은 각각 합산됨을 시험. 마지막 항목이나 누적 단계로 접으면 비용이 달라져 legacy_goals_conflict. 원본 두 goal과 파일 보존 |
| corrupt_legacy | JSON 손상은 corrupt_data. 빈 문서/파생 goals로 덮지 않음 |
| saved_empty_is_authoritative | 예전 목표를 저장한 뒤 빈 문서 save·재시작해도 빈 상태 유지. 이미 있는 plan을 legacy로 보지 않음 |

추가 검증: 학생별 최종 단계·첫 등장 순서, metadata·0·null, 이관 전 stale revision,
성공 재시도(후속 richer 문서 저장 뒤에도 최초 응답), 다중 phase/stage·bond에 대한 legacy
손실 오류, 동시 첫 조회, profile/catalog 1·2번째 쓰기 실패 rollback, 저장 목표/goals 불일치
손상, 계산 요약 실패, 신규/v6 import·중복 import 원본 보존을 포함한다.

### 회귀와 직접 검증

| 검증 | 결과 |
| --- | --- |
| Python 13모듈: FB-1b·repository persistence/parity/contract·v6·seed·scenario·문서 v1/v2·계획 parity·shortage | **76건 통과**, debug/frontend_fb1b/python-targeted.txt |
| Dart: 새 DTO/mock 13건 + 기존 repository fixture·통계 projection·protocol client·mock scanner | **44건 통과**, debug/frontend_fb1b/dart-targeted.txt |
| Process: 새 first get→save→restart→계산/손실 방지/빈 문서 + 기존 repository/scenario E2E | **3건 통과**, debug/frontend_fb1b/dart-process.txt |
| flutter analyze (services와 새 테스트) | **통과**, debug/frontend_fb1b/dart-analyze.txt |
| almanac·diff·슬라이스 병합 | **통과: almanac 42페이지, diff 오류 없음, 수정 11파일 충돌 없음·pre 12파일·post 21파일 고정·기존 스캐너 변경 제외·보호 파일 및 index 변경 없음**, debug/frontend_fb1b/almanac-validate.txt, diff-check.txt, handoff-verification.json |
| Python 전체·공통 fe_gate | **미실행, 아래 사용자 명령**. golden 0 예상(화면·baseline 수정 없음) |

v6 가져오기 기존 3건과 source byte 보존/생성 revision 0/중복 목표 import 거부를 확인했다.
시나리오 v1의 frozen 계산·비교·저장 파일 parity, v2 CRUD·재시작·목표 분리, 공용 active/scenario
요약 일치가 통과했다. scenario 최초 접근은 공유 repository lock을 잡기 전에 profile 이관을
마친다. 이 경로의 legacy_goals_conflict를 scenario 오류 schema에도 등록했다.

통계의 기존 goals 총량·shortage 계산과 기존 statistics_projection 테스트가 통과했다.
process E2E의 단일 성장 목표에서는 크레딧·총 성장 재화·부족량이 저장 문서 계산과 같다.
문서 resource의 credits 행은 총 credits와 별도로 대조하며 기존 goals shortage가 재화 행만
내보내는 의미를 유지했다. v2의 현재값 부족/인연 비용 경고는 성장 비용과 분리하여 검사한다.

새 다중 단계의 재화 배분이나 bond에 필요한 선행 성급은 goals v1에 표현되지 않는다.
파생 목표를 계산용 값으로 채워 이 차이를 숨기지 않는다. **새 활성 화면 수치는 FD-026대로
저장 문서 projection**을 사용한다. 문서의 인연 비용 미계산 경고는 FB-11b 이후에도 그대로다.

시드 회귀는 격리한 200학생/500아이템 profile로 import→rename→8개 시나리오→반복 실행을
검사했다(선택 list KPI 계산만 대역). 추가 이관 없이 rename 뒤 revision=1, scenario base=1,
collection revision=8과 8개 시나리오가 재실행 뒤에도 그대로다. 실제 v6 파일 전체 실행은
소비자 읽기 순서 대응과 사용자 환경에서 이어간다.

### 소비자 영향·오케스트레이터 전달 요청

모든 행은 알림/후속 요청이며 해당 화면·스캐너·tactic·시드 파일을 이번 slice에서 고치지 않았다.
legacy 최초 state/plan 로드가 profile revision을 +1 하므로 catalog summary와 반환 state가
다르면 **반환 revision이 권위값**이다. 기존 scenario.base_profile_revision은 과거 기준 그대로다.

| 소비자 | 확인한 영향 | 요청할 대응 / 소유자 |
| --- | --- | --- |
| title_page.dart | 목록/선택 profile을 보관한 뒤 state를 로드. 선택 profile 없는 분기는 fallback.revision으로 state 로드 전에 select | 선택 대상 state를 먼저 로드하거나 profile 목록을 재조회하여 최신 revision으로 select. state 로드 후 _profile revision도 갱신 / 프런트 |
| account_section_cluster.dart | 목록을 읽고 각 state를 읽어도 _profiles/_selected에는 이전 목록 revision 유지. 선택·수정·삭제는 그 revision 사용 | state별 반환 revision으로 profile summary 갱신 또는 목록 재조회. 이관 실패는 보여 주고 빈 목표로 처리하지 않음 / 프런트 |
| scan_page.dart | profile과 state를 읽고 scanner commit에는 state.revision 사용 | state.revision 사용 유지. profile 표시/cache 및 첫 session base revision도 이관 후 값으로 맞추기. repository_busy 재시도·revision_conflict 재조회 검사 / 스캐너 소유자에 전달 |
| tactical_page.dart | repository state·tactical state·catalog를 병렬 로드하며 _profile은 이전 summary | state 반환 revision을 profile/cache에 전파, 추천/비교 cache 갱신. tactical 자체 collection revision과 profile revision 구별 / tactic 소유자에 전달 |
| seed_ui_test_profile.py | import 뒤 state revision으로 scenario 생성은 안전. 기존 legacy profile이 미선택이면 state 이전 select에 목록 revision 사용 | 기존 계정 재사용 시 state를 먼저 읽은 revision으로 select 또는 conflict 뒤 재조회. 신규 import·반복 8개 seed 회귀 통과 / 도구 후속 소유자 |
| scenario 목록/비교·통계/인벤토리 | 과거 scenario base가 이관 후 current revision과 달라 stale 표시 가능. 파생 goals는 호환 경로 | 과거 base를 다시 쓰지 않기. 새 활성 수치/cache는 document projection과 get.calculation 사용 / 프런트 |

### 프런트 연결 메모

1. `_loadRepositoryPlan`의 메모리 goals→v1 변환을 `RepositoryPlanService.loadRepositoryPlan(profileId)`로
   교체한다. 빈 문서도 그대로 사용하며 goals fallback으로 되살리지 않는다. RepositoryService
   대역은 기존 interface 그대로이고 실제/mock을 추가 capability로 검사/캐스팅한다.
2. plan.get과 loadRepositoryState를 각각 읽었을 때 revision이 같아야 한다. 다르면 다시 읽고,
   편집 중 충돌은 초안을 보존한 채 재조회/다시 미리보기한다. 저장 expectedRevision은 그 일치한
   snapshot의 revision이다. 저장 재시도는 같은 document·expectedRevision·idempotencyKey를 유지한다.
3. FE4 초안의 v2 PlanningDocument를 saveRepositoryPlan에 전달한다. append는 기존 문서와 phase를
   합쳐 저장한다. 문서 goals/metadata를 프런트에서 별도로 저장하지 않는다. replace와 자동 archive는
   FB-1c 계약 뒤 연결한다.
4. 문서 계산 current는 confirmedStudentPlanningCurrent에 실제 확인된 nullable bond_rank만 보탠다.
   bond_rank를 목표로 복사하거나 모르는 현재 인연을 1로 만들지 않는다. get.calculation=null은 계산
   불가 상태이며 문서 내용은 계속 표시한다.
5. 인연 게이지/ActivePlanDocumentSource에는 저장 문서의 학생별 마지막 nullable bond target을
   연결한다(FD-049). goals에는 인연 key가 없다. current 이하 또는 null 목표의 표시 정책은 기존
   프런트 규칙을 따른다. UI·게이지·위젯/golden fixture 수정은 프런트 몫이다.

```dart
final plans = service as RepositoryPlanService;
final active = await plans.loadRepositoryPlan(profileId);
final revision = await plans.saveRepositoryPlan(
  profileId: profileId,
  document: draftDocumentV2,
  expectedRevision: active.revision, // state와도 같은 snapshot인지 먼저 확인
  idempotencyKey: retainedSaveKey,
);
```

### 사용자 검증·인계

루트에서 Python 전체를 실행한다. 결과 파일은 debug/frontend_fb1b/python-full.txt다.

```powershell
Push-Location backend
py -3.11 -m unittest discover -s tests -v 2>&1 | Tee-Object -FilePath ..\debug\frontend_fb1b\python-full.txt
$fb1bPythonExit = $LASTEXITCODE
Pop-Location
if ($fb1bPythonExit -ne 0) { throw "FB-1b Python full failed: $fb1bPythonExit" }
```

Python 전체 통과 → **두 워커가 모두 멈춘 뒤** `fe_gate` →
`fe_commit -Slice fb1b -DryRun` 검토 → `fe_commit -Slice fb1b` → `redesigndocs`.
golden 변경은 0을 예상하며 baseline 폴더는 whole에 넣지 않는다.
debug/frontend_fb1b/commit.json은 status=false·whole=이 backend 상태 문서다. 수정 전 pre와
고정 종료 post를 함께 둔다. 커밋·push·index 변경은 하지 않는다. FB-1b 커밋까지 코드 편집을
멈추며 다음 FB-1c는 별도 오케스트레이터 프롬프트 뒤 시작한다.

# FB-11b 인연 경험치·선물 3안

## 착수 기록 (2026-10-08)

- 시작 SHA: `d7674086ee949c71ea224d37eece3a50410fd7e9`. FB-1a `682b2a7b` 커밋을 확인하고 편집을 재개한다.
- 워크플로 FB-11·저녁/밤 재개 지점, 프론트 로그 08:45·13:45·16:48·20:17, tactic W4/W4b와 `a107c3f2`의 favor-cafe evidence, FD-163(a)·164·165, 아래 FB-11b 사전 조사를 읽었다. [@workflow]
- W4b: 현재 랭크 L의 FavorLevelExcel.ExpType[g-1]을 차감하고 L+1로 진행한다. JP 1.73.0의 100행을 사용한다. 쓰다듬기는 CafeInteractionExcel FavorExp 15 [표], 3시간 getter [코드], 가능 횟수 [?]다.
- 현재 랭크 시작 가정을 응답에 표시한다. 첫 회 즉시 가능 가정의 최소 간격 시간만 내며 하루 횟수를 만들지 않는다. FD-164 보유 많은 순→최대 경험치 선물 부족분, FD-165 성장 재화 목록과 분리한다.
- 소유 경계: 서비스 DTO·mock/process·계약·Python만 수정한다. lib/ui/**·위젯/golden, developer_tools*·backend/data/*·data/extracted/pipeline/* 및 스캐너/tactic 파일은 수정하지 않는다. 문서 계산의 인연 비용 경고는 유지한다.
- 수정 전 사본은 debug/frontend_fb11b/pre/. 기존 미커밋 스캐너 변경은 보존하고 커밋·push·stage는 하지 않는다. 다음 FB-1b는 새 프롬프트 뒤 시작한다.

## 구현 종료 및 인계 (2026-10-08)

FB-11b의 도메인·계약·서비스·직접 검증을 마쳤다. **Python 전체·두 워커 종료 후 공통 gate·커밋은 사용자 단계로 남는다.**
lib/ui/**·위젯/golden 코드는 수정하지 않았다. 문서 v2의 인연 비용 미계산 경고를 유지한다.

### 계약과 계산

| 경계 | 계약 |
| --- | --- |
| 입력 추가 | 선택 bond={current_rank: 1~100 또는 null}. 목표는 기존 정수 targets.bond_rank. 랭크 진행도·추가 key 거부 |
| 기존 입력 | bond 생략 시 기존 성공 필드·비용·재화·경고 그대로, bond 응답도 생략 |
| bond 필수 필드 | current_rank, target_rank, assumption, source_version, favor_levelup_type, required_exp, plans, warnings |
| 가정/자료 버전 | assumption=current_rank_start, source_version=jp-1.73.0 |
| 필요 경험치 | 현재 L..목표 T−1의 ExpType[g−1] 합. 같은/낮은 목표=0. 현재·그룹 미확인=null·경고 |
| 3안 | plans.preferred_large(실제 선호 매칭 SSR), normal(SR, 선호 배수 포함), petting |
| 선물 행 | gift_id, resource_key, display_name, base_exp, multiplier, exp_per_gift, owned, required, used_owned, shortage |
| 선물 안 | available, inventory_complete, provided_exp, shortage, gifts |
| 쓰다듬기 | exp_per_interaction=15, interval_hours=3, required_count=ceil(exp/15), minimum_hours=max(count−1,0)×3, first_interaction=immediate, available_count=null |

- core/student_bond.py는 developer_tools._student_gift_affinities의 태그 규칙을 옮긴 순수 도메인이다. 실제 preferred/unique 매칭이 있을 때 accepted 태그에 BC/Bc/ew를 합치고 매칭 수 최대 3, 배수 1+매칭 수, 경험치 exp_value×배수다. 매칭 없음은 배수 1이다. 도구를 runtime import하지 않고 도구 파일도 수정하지 않았다.
- FD-164: 각 안에서 보유 많은 순으로 필요한 수만 사용한다. 동률은 경험치 내림차순·gift ID 오름차순. 부족하면 해당 안의 최고 경험치 선물로 ceil한 개수를 채운다. 후보별 보유를 서로 다른 안 사이에서 차감하지 않는다.
- 인벤토리는 안정 present resource_key로 연결한다. 52종 경험치 선물의 Schale ID를 reviewed ItemDBSchema 식별자·rarity와 연결한 사본을 사용하며, 선물 이름 추측이나 ordinal을 identity로 쓰지 않는다. 상자·미등록 행사 선물 경험치는 만들지 않는다.
- 보유 누락/null은 0이 아니다. 확인된 보유만 사용하고 fallback 보유가 미확인이면 해당 행/안의 shortage=null로 둔다. 명시적 0은 실제 부족 수를 낸다. inventory_complete=false인 잠정 계산에는 경고가 붙는다. 선호 대형 후보가 없으면 available=false다.
- minimum_hours는 첫 회 즉시 가능한 조건에서 간격만 계산한 이론적 하한이다. 실제 현재 가능 여부·방문·리셋·서버 제한은 [?]다. 하루 8회/2회나 예상 일수를 만들지 않는다. 현재 랭크 미확인은 exp·필요 횟수·시간 모두 null이다.
- FD-165: bond 3안은 totals·credit_breakdown·성장 resources를 바꾸지 않는다. 원래 성장 재료에 포함되는 present(애장품 재료)은 그대로다. FB-1a의 "Bond growth cost is unavailable" 경고도 그대로다. 인연 선물은 문서의 크레딧 비용이 아니다.
- 새 schema planning-student-bond-v1을 기존 student-calculate의 선택 request/response로 참조한다. 기존 19-key 정수 targets/currentStudent 계약은 그대로이며 null bond 목표를 이 메서드에 추가하지 않는다. 예약 opaque bond의 테스트는 정의된 strict 객체 검사로 갱신했다.

### 경험치 표 근거

승인된 W4/W4b evidence: docs/tactic-editor/evidence/favor-cafe-tables-jp-1.73.0.json,
커밋 a107c3f2. 오래된 최상위 status 문자열은 미확정 상태를 남기지만,
**expTypeAnalysis v2.status=confirmed-per-level-required-exp**가 최종 판정이다.

| 자료 | 꼬리표·근거 |
| --- | --- |
| FavorLevelExcel 100행 | [표] rows SHA256 ea46aef8d84687a66c0854b1f40a39b5d1ea5284fa80100ddb66632e24724c85 |
| FavorData.Levelup, RVA 0x1a1bae0 | [코드] 현재 L 행 조회→ExpType[g−1] 차감→L+1; evidence SHA256 5af3d6e8923cc28db3f0e0e5a20edd0dd4e6d1da3ca9299efb8c787021d3c9db |
| CharacterExcel | [표] file SHA256 2ff635b1340a88c02a35ececdb16fbeb99c100c08793102c314f78ffe70f385c. Cafe 276명 그룹 1, 현재 canonical 265명 전부 매칭 |
| CafeInteractionExcel 276행 | [표] FavorExp(11)/Id=0/Amount=15. rows SHA256 d02f4a7d0e46ff190cb34b05e46badb5177d7f6c5b42ffd32eaa8e2f9ddcb430 |
| CafeService.get_InteractCooltime, RVA 0x1338160 | [코드] FromHours(3.0), dis SHA256 c8ceb20c2136d473dd4f1417a262e9f1527d573ea4597bebb4946d15caff2a7e |
| 가능 횟수·서버 강제·방문/리셋 | [?] 미확인. available_count=null |

core/student_bond_data.py는 승인된 자료의 portable snapshot(100 랭크·276 그룹·52 identity)이다.
debug/frontend_fb11b/generate_domain_snapshot.py가 원본 file/row sha를 확인해 생성한다.
runtime은 공용 저장소·추출 경로에 의존하지 않는다. backend/data/*와 pipeline는 수정하지 않았다.
JP 1.73.0에서 확인된 해석이며 KR/다른 빌드 서버 동작의 대조 완료를 뜻하지 않는다.
계약 README에 동일 해시·태그와 gift identity의 별도 Steam ItemDBSchema 근거를 적었다.

### 배분 예시 및 고정 fixture

contracts/fixtures/planning_student_bond_v1.json의 7건: unknown_inventory,
quantity_before_exp, owned_then_shortage, same_rank, lower_target, unknown_current,
max_rank_boundary. 같은 입력의 실제 protocol 응답과 canned mock을 고정했다.

| 사례(아루) | 계산 결과 |
| --- | --- |
| 현재 10→12, 필요 60+90=150. 일반 5000 보유 6개(20/개), 선호 5017 보유 1개(60/개), 나머지 0 | 보유 많은 5000 6개→5017 1개. 제공 180, 부족 0. 경험치 순 우선 배분이 아님 |
| 현재 1→11, 필요 360. 선호 대형 5103 보유 1개(60×3=180), 나머지 0 | 1개 보유 사용 + 추가 1개, required=2·used_owned=1·shortage=1. 일반 안은 5017 6개 부족. 쓰다듬기 24회, 첫 회 즉시 가정 최소 69시간, 가능 횟수 [?] |
| 현재 1→3, 필요 15+30=45, present 스캔 없음 | 대형 5103 1개 또는 일반 5017 1개. 보유·부족 null·경고. 쓰다듬기 3회, 최소 간격 시간 6시간 |

경험치 1→2=15, 1→3=45, 1→4=75, 10→12=150, 99→100은 99행만,
100→100=0을 검사했다. 인공 2열 fixture로 그룹 2→원소 1도 검증하며 그룹 0/범위 밖을
기본 그룹으로 바꾸지 않는다. 보유 순서 변경, 명시적 null, 태그 매칭 상한, unknown current/
group/선호 후보, strict 입력·응답, 숫자 bool 거부도 검사한다.

### 직접 검증

| 검사 | 결과 / 로그 |
| --- | --- |
| Python: 새 bond·gift, 기존 FB-11a·FB-1a·문서·시나리오·계약·비용·shortage/repository parity 13모듈 | **74건 통과**, debug/frontend_fb11b/python-targeted.txt |
| Dart: 새 strict DTO/mock, 기존 student_calculation_service·growth_calculator_adapter | **36건 통과**, debug/frontend_fb11b/dart-targeted.txt |
| Dart: planning_protocol_contract·client·repository_contract | **25건 통과**, debug/frontend_fb11b/dart-contract.txt |
| Process: 새 인연 1건 + 기존 FB-11a 1건 | **2건 통과**, debug/frontend_fb11b/dart-process.txt. 같은 비용·재화·저장소 revision·파일 바이트 유지 |
| analyze: lib/services와 서비스/새 테스트 | **No issues found**, debug/frontend_fb11b/dart-analyze.txt |
| almanac·diff·slice 병합 | **통과: almanac 42페이지, diff 오류 없음, 수정 10파일 충돌 없음·post 20파일 고정·기존 스캐너 변경 제외·index 변경 없음**, debug/frontend_fb11b/almanac-validate.txt, diff-check.txt, handoff-verification.json |

### FE3-g 연결 메모

```dart
final result = await service.calculateStudent(
  currentStudent: request.currentStudent,
  targets: request.targets, // 완전한 기존 정수 19-key, bond_rank는 목표 랭크
  inventory: request.inventory,
  bond: StudentBondRequest(currentRank: confirmedBondRank), // 미확인은 null
);
final bond = result.bond;
```

- 기존 성장 전용 인터페이스는 변경하지 않았다. 새 PlanningStudentBondCalculationService capability를 ProcessAppService/MockAppService가 구현하고 AppService 확장 메서드가 선택 인연 입력을 분기한다. 기존 어댑터·프런트 테스트 대역은 계속 동작한다.
- FE3-g가 원래 확정값/직접 입력에서 currentRank를 따로 읽어 전달한다. 기존 currentStudent에 bond_rank를 몰래 넣지 않는다. 현재를 모르는데 1로 채우지 않는다. 디바운스 한 호출에서 성장+bond를 받아 이전 요청의 응답 버림·취소를 유지한다.
- 필요 경험치=result.bond.requiredExp, 선호/일반 안=preferredLarge/normal, gift 행=requiredAmount·usedOwned·owned·shortage다. unknown은 빗금/미확인으로 표시하고 available=false 안은 사용할 수 없음을 드러낸다. 세 안 선택은 팝오버 고정·강조만 바꾼다.
- sourceVersion·assumption=current_rank_start, petting.firstInteraction=immediate 조건의 minimumHours를 구분한다. availableCount=null은 [?]이며 하루 횟수/일수를 만들지 않는다. bond.warnings는 인연 타일, 기존 result.warnings는 성장 경고로 연결한다.
- result.resources만 성장 재화 목록과 부족 종류 수에 쓴다. 선물 안을 합치지 않는다. 기존 성장 present 행이 있다고 모두 제거하는 것도 피한다.
- reservedBond는 검증된 wire의 깊은 immutable 호환 뷰이며 result.bond는 typed immutable DTO다. 모든 field/key·산식·불변성을 검사한다. Mock은 fixture 7개 학생·랭크·보유 입력만 지원하고 다른 입력은 UnsupportedError다. 실제 임의 입력 수치는 Python process를 사용한다.
- lib/ui/**는 이 워커가 수정하지 않았다. planning_models.dart도 프런트 소유로 유지한다.

### 사용자 실행 순서와 다음 배정

v7 루트에서 Python 전체 결과를 저장한다(직접 실행하지 않았으며 결과 파일도 만들지 않았다).

```powershell
Push-Location backend
py -3.11 -m unittest discover -s tests -v 2>&1 | Tee-Object -FilePath ..\debug\frontend_fb11b\python-full.txt
$fb11bPythonExit = $LASTEXITCODE
Pop-Location
if ($fb11bPythonExit -ne 0) { throw "FB-11b Python full failed: $fb11bPythonExit" }
```

Python 전체 → **두 워커가 모두 멈춘 뒤** fe_gate → fe_commit -Slice fb11b → redesigndocs.

```powershell
powershell -ExecutionPolicy Bypass -File frontend/tool/fe_gate.ps1
powershell -ExecutionPolicy Bypass -File frontend/tool/fe_commit.ps1 -Slice fb11b -DryRun
powershell -ExecutionPolicy Bypass -File frontend/tool/fe_commit.ps1 -Slice fb11b
redesigndocs
```

debug/frontend_fb11b/commit.json은 status=false·whole=백엔드 상태 문서만이며 pre/post를
고정한다. baseline 폴더는 넣지 않는다. 커밋·push·stage는 하지 않았다.
FB-11b 커밋까지 코드 편집을 멈춘다. 다음 FB-1b는 오케스트레이터 프롬프트 뒤 시작한다.

# FB-1a 계획 문서 v2 nullable 목표

## 착수 기록 (2026-10-08)

- 진행 중: FB-1a. 시작 커밋 SHA: `0fd3770234805b3e293c83a5285765a5492e0193`.
- FB-13 `fa15e87c` 커밋 후 코드 편집 재개 승인. 워크플로 FB-1 전체·오후 재개 지점·Lane A 병렬 규칙, 오케스트레이터 로그 14:05 파일 경계, 아래 FB-1 설계 조사와 FD-003·026·027·049·138을 읽었다. [@workflow]
- 범위: 문서 v2의 19-key nullable 절대 목표와 strict 학생별 goal_metadata, 계산 중 유효 상태를 넘기는 공용 코어 경계, v1/v2 문서 계산·시나리오, Dart 문서 DTO·서비스·테스트.
- 이 slice 동안 `frontend/lib/ui/models/planning_models.dart`의 문서 DTO 부분만 백엔드 소유다. 화면·위젯·golden 테스트, 스캐너·tactic·metadata M 소유 파일은 수정하지 않는다. repository 활성 문서 저장/이관/goals 파생은 FB-1b, replace는 FB-1c다.
- 기존 서비스 3파일의 스캐너 미커밋 변경을 보존한다. 수정 전 사본은 `debug/frontend_fb1a/pre/`에 둔다. 커밋·push·stage 미실시. 전체 gate는 두 워커 종료 후 사용자 PC에서 실행하며 golden 변화 0을 예상한다.

## 구현 종료 및 인계 (2026-10-08)

FB-1a의 코드·계약·직접 검증을 마쳤다. **Python 전체·두 워커 종료 후 공통 gate·커밋은 사용자 단계로 남는다.**
현재 화면이 만드는 v1 경로를 유지했으며 golden 변화는 0을 예상한다. golden 비교 자체는 아직 실행하지 않았다.

### v1/v2 계약 비교

| 계약 | 문서 v1 (유지) | 문서 v2 (추가) |
| --- | --- | --- |
| 문서 필드 | version, document_id, name, kind, phases | 같은 필드 + 필수 goal_metadata |
| targets | 19 key 전부 정수 | 같은 19 key 전부 int 또는 null |
| null / 0 | null 거부, 기존 정수 의미 유지 | null=그 항목 목표 없음, 0=명시적 실제 값 |
| bond_rank | 1~100 | null 또는 1~100 |
| 학생 메모 | 없음 | 학생 ID별 favorite bool, notes string; 두 필드만 허용 |
| 단계 검사 | 기존 성장 조합 검사와 누적 절대 목표 | 범위·19 key·누적 절대 목표 검사; 선행 성장은 계산 중에 결합 |
| 다음 단계 상태 | 기존 calculate_goal_cost + _advance | calculate_goal_transition의 유효 상태 |
| 시나리오 | 기존 문서/파일/결과 유지 | 저장·조회·목록·복제·비교·재시작에서 버전/null/메모 보존 |

- 같은 학생의 이전 정수 목표 뒤에 더 작은 정수나 null이 오면 회귀 오류다. null→정수는 허용한다. 페이즈를 넘어서도 적용한다.
- goal_metadata의 ID 집합은 단계에 등장하는 학생 집합과 정확히 일치한다. 각 값은 favorite·notes만 허용한다. false·빈 메모·메모 공백을 그대로 보존한다. 빈 문서는 phases=[], goal_metadata={}다.
- schema는 기존 문서 정의를 documentV1로 보존하고 documentV2 분기를 추가했다. 시나리오 schema가 공유 document를 참조하므로 바깥 IPC·시나리오 저장소 버전은 계속 1이다.
- 문서 계산과 시나리오 비교의 current_students에만 선택 bond_rank(null 또는 1~100)를 받는다. 공유 currentStudent와 FB-11a의 단일 학생·정수 19 key는 확장하지 않았다.
- 공용 planning_growth_rules 경계가 현재값 하한·장비 티어/레벨·전무/성급·스킬 잠금·능력 개방·애장품의 필수 인연을 계산 중에 해결한다. 장비 정규화 helper를 기존 비용 코어와 함께 사용하고, 비용식은 기존 calculate_goal_cost 하나를 재사용한다.
- 원본 nullable StudentGoal을 코어에 전달한 뒤 계산용 사본만 만든다. 계산 후 상태는 다음 단계에 전달하고 저장 targets에는 되쓰지 않는다. all-null 단계에 현재 인연 35가 있어도 성급 성장을 새로 만들지 않는다.
- 현재 성장 기준값을 모르면 계산 경고를 낸다. 모르는 인연에 1을 넣지 않는다. 애장품의 필수 인연은 계산 상태에만 반영하며 원본 bond_rank=null은 유지한다. 인연 성장 비용은 아직 가격을 계산하지 않고 경고한다(FB-11b). 다른 알려진 비용의 합은 잠정 결과다.
- repository.plan.get/save·이관·goals 파생(FB-1b), replace(FB-1c)는 구현하지 않았다. 시나리오 process 검증에서 활성 프로필 파일이 바뀌지 않는 것도 확인했다.

### 먼저 고정한 정책 fixture

`contracts/fixtures/planning_document_v2.json`: **15건(유효 12, 회귀 오류 3)**을 구현 전에 고정했다.

| fixture | 고정 정책 |
| --- | --- |
| null_bond_known / null_bond_unknown | 현재 인연 35 / 미확인이어도 bond 목표는 null 유지, 비용 0 |
| all_null | 단계 자체는 유지, 비용 0 |
| explicit_zero | level·애장품·능력 개방의 명시적 0 유지, 현재값보다 낮아도 목표를 현재값으로 쓰지 않음 |
| same_as_current | 현재와 같은 목표 비용 0 |
| partial_weapon | 전무 레벨만 20→25. 필수 성급·전무 성급은 계산 상태로 전달, 성급 비용 한 번 |
| partial_equipment | 장비 레벨만 15→20. 필요한 티어를 계산하고 다음 단계에서 티어 재과금 없음 |
| partial_favorite_known_bond | 현재 인연 20, 애장품 T2만 지정. bond null 유지, 500,000 크레딧 |
| partial_favorite_unknown_bond / partial_favorite_requires_bond | 인연 미확인 / 현재 10. 필수 인연에 대해 경고, 저장 목표 null 유지 |
| unknown_level_baseline | 현재 레벨 미확인, 목표 31. 기준값 부족 경고 |
| regresses_integer / regresses_to_null / bond_regresses_to_null | 더 낮은 정수 / 정수 뒤 null / 인연 정수 뒤 null 거부 |
| empty_document | 빈 문서, 계산 비용 0·경고 0 |

정책별 Python/schema·Dart DTO 검사 외에 불완전 19 key, bool·문자열 목표, bond=0,
메타데이터 누락·추가 학생·추가 필드·잘못된 타입도 거부한다. 전무/장비의 두 단계 합과
같은 최종 목표 단일 단계의 비용을 비교하고, 원본 입력·목표가 계산 뒤 그대로인지 확인한다.

### v1 회귀와 직접 검증

변경 전 `planning_document_v1_fb1a_parity.json`에 문서 A/B wire·projection·compare 결과를,
`scenario_v1_fb1a_parity.json`에 create/get/list와 저장 파일 전체 텍스트를 고정했다.
**문서·projection·compare·시나리오 반환값은 값 단위로 같고 시나리오 저장 파일은 바이트 단위로 같다.**
기존 v6 비용 parity, FB-12 단계 비용, FB-11a 단일 학생 계약·왕복도 통과했다.

| 검사 | 결과 / 로그 |
| --- | --- |
| Python: 새 v2, 기존 문서·시나리오·계약·비용·재고/저장 parity 11모듈 | **64건 통과**, debug/frontend_fb1a/python-targeted.txt |
| Dart: 새 v2 DTO/mock, 기존 scenario_service·growth_rules·document_projection | **35건 통과**, debug/frontend_fb1a/dart-targeted.txt |
| Process: v2 문서 계산 + v2 시나리오 저장→재시작→조회→v1/v2 비교, 기존 scenario·FB-11a | **4건 통과**, debug/frontend_fb1a/dart-process.txt |
| 변경 Dart 5파일 analyze | **No issues found**, debug/frontend_fb1a/dart-analyze.txt |
| codealmanac validate | **통과**, debug/frontend_fb1a/almanac-validate.txt |
| git diff --check / 읽기 전용 slice 병합 검사 | **통과 / 수정 10파일 충돌 없음**, debug/frontend_fb1a/diff-check.txt / handoff-verification.json |

### FE4 초안 컨트롤러 연결 메모

- 현재 v1 화면·초안은 그대로 쓸 수 있다. PlanningDocument의 기본 version은 1이고 기존 stage.targets는 immutable 정수 Map이다. PlanElementStageDraft·preset·planningDocumentTargets는 변경하지 않았다.
- v2를 만드는 경계에서 PlanningDocument(version: 2, ..., goalMetadata: ...)를 명시한다. 각 단계 targets는 planningDocumentTargetKeys 19개를 전부 가진 Map<String, int?>로 만들고, 선택하지 않은 목표는 null로 둔다. 현재값으로 채우는 planningDocumentTargets를 v2 생성에 사용하지 않는다.
- v2 읽기·편집은 stage.nullableTargets를 쓴다. legacy stage.targets는 null을 포함한 단계에 대해 StateError를 내므로 v2를 기존 정수 편집기에 바로 넘기지 않는다. 선택 목표 제거는 그 학생의 모든 관련 단계에서 함께 지워 누적 회귀를 피한다.
- goalMetadata는 문서 학생 ID 집합과 맞춰 PlanningGoalMetadata(favorite: ..., notes: ...)를 구성한다. favorite=false와 메모를 초안 재생성·복제 때도 보존한다.
- 계산은 service.calculatePlanningDocument(..., document: document.toWire())를 사용한다. createScenario/compareScenarios는 v1/v2 PlanningDocument를 그대로 받는다. 반환 projection과 계산 경고를 초안에 연결하되 유효 계산 상태를 원본 targets에 넣지 않는다.
- FB-11a 계산기 호출은 계속 정수 targets로 남는다. 활성 문서 저장/로드·goals 파생 연결은 FB-1b 이후에 한다. planning_models.dart의 임시 소유 예외는 이 slice 종료와 함께 해제하되, 커밋 전 pre/post 경계를 지킨다.

### 사용자 실행 순서와 다음 배정

v7 루트 PowerShell에서 전체 Python 결과를 저장한다(아직 실행하지 않았으며 아래 결과 파일도 만들지 않았다).

```powershell
Push-Location backend
py -3.11 -m unittest discover -s tests -v 2>&1 | Tee-Object -FilePath ..\debug\frontend_fb1a\python-full.txt
$fb1aPythonExit = $LASTEXITCODE
Pop-Location
if ($fb1aPythonExit -ne 0) { throw "FB-1a Python full failed: $fb1aPythonExit" }
```

Python 전체 통과 → **두 워커가 모두 멈춘 뒤** fe_gate → fe_commit -Slice fb1a → redesigndocs.

```powershell
powershell -ExecutionPolicy Bypass -File frontend/tool/fe_gate.ps1
powershell -ExecutionPolicy Bypass -File frontend/tool/fe_commit.ps1 -Slice fb1a -DryRun
powershell -ExecutionPolicy Bypass -File frontend/tool/fe_commit.ps1 -Slice fb1a
redesigndocs
```

인계 파일: debug/frontend_fb1a/commit.json(status=false, whole=백엔드 상태 문서만),
수정 전 pre/와 고정 종료본 post/. baseline 폴더는 넣지 않았다.
종료본은 수정 10 + 추가 6 + whole 1 = 17파일이다. 읽기 전용 3-way 병합에서 mock의 기존
스캐너 변경이 커밋 후보에 섞이지 않고, Dart의 문서 DTO 밖 모델·preset·변환 helper가
pre와 같으며 Git index가 변하지 않는 것을 확인했다.
커밋·push·stage는 하지 않았다. **FB-1a 커밋까지 코드 편집을 멈춘다.**
FB-1b는 커밋 뒤 오케스트레이터 프롬프트를 받고 시작하며, 첫 작업은 legacy 이관 정책 fixture
(null bond·all-null·중복 학생 goal·부분 목표·빈 활성 문서)를 고정하는 것이다.

# FB-13 학생 catalog 애장품 가용성

## 착수 기록 (2026-10-08)

- 진행 중: FB-13. 시작 커밋 SHA: `2bcdcbd9f490a53e0bb4a0c66bd81625bfbeb895`.
- 워크플로 FB-13 행, FB-1 "분할", 실행 순서의 Lane A 병렬 규칙과 오케스트레이터 로그 08:57을 읽었다. FB-11a `facdd1d3` 이후 코드 편집 재개가 승인되었다. [@workflow]
- 범위: `planning.student.catalog`의 필수 `has_favorite_item: bool`(KR 서버 제공 여부), 계약·Python 테스트·Dart DTO/metadata·mock·번들 exporter/asset·DTO/mock/process 검증.
- 기존 미커밋 변경 있음: `mock_app_service.dart`, `planning_protocol_client.dart`, `process_app_service.dart`의 스캐너 변경. catalog 수정 전 사본은 `debug/frontend_fb13/pre/`에 보존한다. mock의 catalog 부분만 수정하고 나머지 서비스 2파일과 스캐너·tactic 소유 파일은 수정하지 않는다.
- `frontend/lib/ui/**`, 위젯·golden 테스트와 baseline PNG는 수정하지 않는다. 전체 gate는 두 워커가 모두 멈춘 뒤 사용자 PC에서 실행한다. golden 변화 시 비교 → 오케스트레이터 검토 → UpdateGoldens 및 재비교 → 커밋 순서를 따른다.
- 커밋·push·stage를 하지 않는다. FB-1a는 이 슬라이스 종료 후 준비 메모만 남기며 오케스트레이터 프롬프트를 받은 뒤 시작한다.

## 종료 기록 (2026-10-08)

FB-13 백엔드 범위의 코드·계약·직접 검증을 마쳤다. **Python 전체·공통 gate·golden 판정·커밋은 사용자 단계로 남는다.**
필수 wire 필드 누락이 확인된 프런트 소유 테스트 fixture 2곳과 범위 밖 almanac 오류 6건을
아래에 기록했다. 이 상태에서 공통 gate GREEN이나 동작 보존 완료를 주장하지 않는다.

### 구현과 계약

- `protocol_v1.py`: 모든 catalog 항목에 `student_meta.favorite_item_enabled(student_id, server="kr")`의 bool을 넣는다. 요청은 계속 `{}`이고 JP 제공·보유·장착·목표 티어와 독립적이다.
- schema·README·공용 fixture: 고정 필드는 19개, `has_favorite_item` 필수 bool. true/false fixture와 누락·"yes"·"no"·null·0·1 거부 fixture를 Python/Dart 양쪽에서 검증한다.
- `StudentCatalogEntry`: immutable `hasFavoriteItem`, strict fromWire, bool `metadata` getter. 수동 생성자 생략은 기존 대역 호환을 위해 false, `missing-student` fallback도 false다. 실제 wire 누락은 거부한다.
- `MockAppService._studentCatalogWire`: bool을 보존하여 compact·long-name 사본에서도 Aru=true / Ayane=false를 유지한다. 스캐너 코드와 서비스 나머지 2파일은 변경하지 않았다.
- exporter는 runtime catalog builder를 재사용한다. 기존 exporter 재실행 시 사라지던 FB-5 `forms`도 보존하고, asset·runtime 전체 항목이 같도록 재생성한다. 265명: KR true 60명, false 205명.
- 재생성 과정에서 기존 번들의 오래된 `jp_only=true` 7건이 현재 canonical/runtime 값 false로 동기화되었다: `niko`, `rena`, `akane_school_uniform`, `otogi`, `konoka`, `koyuki_pajama`, `kurumi`. 신규 bool과 이 7개 flag 외 기존 필드·폼·순서는 동일하다. canonical metadata 자체는 수정하지 않았다.
- Python은 Aru=true / Airi=false, Ayane·Asuna의 KR=false / JP=true를 검증한다. 모든 항목의 bool 타입·KR 판정, 잘못된 값·누락 schema 거부, 번들 전체 parity, exporter 재현성, Python process 전체 응답 parity를 검사한다.
- 새 Dart 서비스 테스트는 DTO·metadata·수동 생략·missing fallback·번들 전체·폼·이름 사본을 검사한다. 별도 process E2E는 실제 Python catalog와 번들·full mock의 265명 가용성 전체를 비교한다.

### 직접 검증

| 검사 | 결과와 로그 |
| --- | --- |
| Python `tests.test_student_catalog`, `tests.test_planning_protocol_contract`, `tests.test_canonical_metadata`, `tests.test_student_calculation_fb11a` | **33건 통과**, `debug/frontend_fb13/python-targeted.txt` |
| Dart `student_catalog_service_test`, `planning_protocol_client_test`, `planning_protocol_contract_test`, `mock_student_fixture_test` | **39건 통과**, `debug/frontend_fb13/dart-targeted.txt` |
| 새 `student_catalog_process_e2e_test` | **1건 통과**, `debug/frontend_fb13/dart-process.txt` |
| 변경 서비스·테스트 5파일 analyze | **No issues found**, `debug/frontend_fb13/dart-analyze.txt` |
| 프런트 fixture 영향 확인: `student_form_cycle_test`, `student_studio_layout_test` | **46건 통과 / 9건 실패**, 모두 `Invalid student catalog entry fields`, `debug/frontend_fb13/frontend-fixture-check.txt` |
| `codealmanac validate` | **실패, 범위 밖 metadata-manager 문서 오류 6건**, `debug/frontend_fb13/almanac-validate.txt` |
| `git diff --check` | 통과, `debug/frontend_fb13/diff-check.txt` |

#### 프런트 워커 연결 요청 (이 워커는 수정하지 않음)

1. `frontend/test/student_form_cycle_test.dart`의 `_wire`(18행)와
   `frontend/test/student_studio_layout_test.dart`의 Erika `StudentCatalogEntry.fromWire` 항목(1859행)에
   필수 `has_favorite_item` bool을 넣는다. 신규 strict 계약을 완화하면 안 된다. 두 곳 누락 때문에
   폼 교대 테스트 8건과 Studio 테스트 1건이 실패한다. 테스트를 삭제하지 않는다.
2. 수동 DTO 사본은 가용성을 유지하려면 `hasFavoriteItem: source.hasFavoriteItem`을 전달해야 한다.
   예: golden harness `_withDisplayName`은 현재 Hoshino(KR=true)의 필드를 생략하여 false로 만든다.
   이 워커는 golden 테스트를 고치지 않았다. 프런트 워커가 해당 fixture의 의미를 확인한다.
3. `_calculatorMetadata`의 전체-true 폴백 제거와 실제 false 학생의 애장품 행 숨김 검증은 프런트 몫이다.
   현재 metadata는 모든 DTO에서 bool을 제공한다. `students-calculator` 장면 Aru는 KR=true라
   해당 행은 유지될 것으로 예상하지만, golden 변화 여부는 공통 gate로 확정한다.

almanac 오류는 `metadata-manager-orchestrator-log`의 topics 누락 1건,
`metadata-manager-status`의 workflow 미인용 1건,
`metadata-manager-workflow`의 canonical-export·data-lock·devtools-backend·stats-sync 미인용 4건이다.
해당 소유자가 정리해야 하며 FB-13 범위에서는 편집하지 않았다.

### 사본·커밋 준비

기존 수정 파일 10개에 `debug/frontend_fb13/pre/` 사본을 만들었다. mock 서비스의 pre→post diff는
catalog bool 전달 **1줄**뿐이다. 수정 파일 10개·신규 테스트 2개와 종료 상태의 사본은
`debug/frontend_fb13/post/`에 고정한다. `debug/frontend_fb13/commit.json`은 `status: false`,
`whole: ["almanac/workflows/frontend-redesign-status-backend.md"]`, `post_dir: "debug/frontend_fb13/post"`다.
golden은 실행·갱신하지 않았으므로 baseline 폴더는 whole에 넣지 않았다. 검토 후 실제 PNG가 바뀐
경우에만 `frontend/test/goldens/baseline`을 whole에 추가한다. 커밋·push·stage 미실시.

인계 검증(`debug/frontend_fb13/handoff-verification.json`): pre/HEAD/post의 3-way 병합 10개가
모두 충돌 없이 가능하다. mock의 예정 커밋 내용에는 catalog bool 1줄만 추가되고 기존 스캐너
미커밋 변경은 포함되지 않는다. UI·golden·해당 프런트 fixture·서비스 나머지 2파일 등
착수 시 해시를 기록한 125개 보호 파일은 그대로다. 검증은 임시 파일에서만 수행했고 index를
변경하지 않았다.

### 사용자 실행 단계

저장소 루트의 일반 PowerShell에서 먼저 Python 전체를 실행한다. 결과 파일은 지정한
`debug/frontend_fb13/python-full.txt`다. 이 워커는 전체 결과 파일을 미리 만들지 않는다.

```powershell
Push-Location backend
py -3.11 -m unittest discover -s tests -v 2>&1 | Tee-Object -FilePath ..\debug\frontend_fb13\python-full.txt
$fb13PythonExit = $LASTEXITCODE
Pop-Location
Write-Host "FB-13 Python exit: $fb13PythonExit"
```

1. **Python 전체 통과** → 프런트 소유 fixture와 almanac 오류 정리 → **두 워커가 모두 멈춘 뒤**
   `powershell -ExecutionPolicy Bypass -File frontend/tool/fe_gate.ps1`.
2. golden 변화가 없으면 동작 보존 slice로 진행한다. 변화가 있으면 **① 비교 gate → 오케스트레이터
   차이 검토 → ② `fe_gate.ps1 -UpdateGoldens` 후 다시 `fe_gate.ps1` → ③ 커밋** 순서를 따른다.
   baseline whole 추가는 이 경우에만 한다. FE3-f2b의 golden ②는 FB-13 커밋 뒤에 한다. [@workflow]
3. GREEN 확인 후 `powershell -ExecutionPolicy Bypass -File frontend/tool/fe_commit.ps1 -Slice fb13 -DryRun`,
   이어 같은 명령에서 `-DryRun`을 빼고 실행한다. 기존 스캐너 변경이 섞이지 않는지 확인한다.
4. 오케스트레이터의 공유 문서 갱신과 `fe_commit.ps1 -Slice redesigndocs`로 문서 커밋을 정리한다.

### 다음 준비: FB-1a

FB-13은 정적 가용성 데이터이므로 FB-1 저장·이관 의존성을 추가하지 않는다. 다음은 승인된
분할의 **FB-1a: 문서 v2 nullable targets·goal_metadata·v1/v2 계산 및 시나리오 호환**이다.
현재 아래 FB-1 설계 조사와 워크플로 "분할"을 인계 자료로 유지한다. FB-1b 저장·이관과
FB-1c 교체 transaction은 별도 slice다. **오케스트레이터 프롬프트를 받은 뒤 FB-1a를 착수하며,
지금은 시작하지 않는다.**

# FB-11a 단일 학생 성장 계산

## 착수 기록

- 진행 중: FB-11a. 시작 커밋 SHA: `f2cf4fb81c07b30188a49d1240b3169ccc9fbf33`.
- 지정 문서의 불변식, Lane A 앞뒤 병렬, FD-162(b)·FD-163(a)·FD-026, runtime 경계, FE3-f1 계산 어댑터 및 FB-12 종료 기록을 읽었다. [@workflow]
- 범위: Python 계산·프로토콜, 계약, Dart 서비스·DTO, 서비스 테스트·process E2E. FB-11b는 저장소 데이터원 조사만 한다.
- 기존 미커밋 변경 있음: `mock_app_service.dart`, `process_app_service.dart`, `planning_protocol_client.dart`의 스캐너 변경. 수정 전 사본을 `debug/frontend_fb11a/pre/`에 보존했다. 스캐너 부분·프런트 UI·위젯/golden 테스트·공유 상태 문서는 수정하지 않는다.
- 전체 gate는 두 워커가 모두 멈춘 뒤 사용자가 실행한다. 커밋·push·stage를 하지 않는다.
- 사용자 확인: codealmanac가 topics를 읽을 수 있도록 YAML 메타데이터 뒤 **본문 첫 줄**에 지정 문구를 배치한다(2026-10-08 답변).

## FB-11a 종료 기록 (2026-10-08)

코드·계약·직접 검증 완료. **사용자 Python 전체 실행과 두 워커 종료 후 공통 gate·커밋은 대기**한다.
FB-11b 구현은 이번 슬라이스에서 하지 않았으며, 데이터 수치가 없는 부분을 아래에 명시했다.

### 바뀐 파일

| 파일 | 변경 |
| --- | --- |
| `backend/core/planning_calc.py` | 선택적인 크레딧 집계 인자와 9범주 상수. 기존 비용을 더하는 지점에서 집계, 기존 PlanCostSummary와 wire 불변 |
| `backend/core/planning_document.py` | 선택적인 집계 인자를 계산 코어에 전달. 기존 문서 계산·자원 행·현재값 이월 로직 재사용 |
| `backend/core/protocol_v1.py` | `planning.student.calculate` 등록·검증·읽기 전용 계산 응답 |
| `backend/tests/test_planning_protocol_contract.py` | 알려진 스키마 목록에 새 메서드 추가 |
| `backend/tests/test_student_calculation_fb11a.py` (추가) | Python 새 테스트 10건: fixture, 문서 일치, 9범주 고정값, 오류·strict 계약·입력 불변 |
| `contracts/planning-student-calculate-v1.schema.json` (추가) | currentStudent·19 key targets·optional inventory·totals·9범주·재화 행·warnings·예약 bond |
| `contracts/planning-protocol-v1.schema.json`, `contracts/protocol-error-v1.schema.json` | 알려진 메서드·오류 조합 등록 |
| `contracts/fixtures/planning_student_calculate_v1.json` (추가) | Python/Dart 공용 고정 fixture 4쌍 |
| `contracts/README.md` | 계약·범주·재고 의미·예약 bond·AppService 확장 방식 문서화 |
| `frontend/lib/services/student_calculation_service.dart` (추가) | strict DTO fromWire, 범주 합 검사, 재화 부족 일관성·중복 키 검사, immutable 예약 bond 객체 |
| `frontend/lib/services/app_service.dart` | DTO export와 `AppService.calculateStudent` 확장 메서드 |
| `frontend/lib/services/planning_protocol_client.dart` | 새 메서드의 응답 DTO 검사·오류 코드 등록 |
| `frontend/lib/services/process_app_service.dart` | 기능 인터페이스 구현, 한 번의 IPC 요청으로 DTO 반환 |
| `frontend/lib/services/mock_app_service.dart` | 기능 인터페이스 구현, 고정 fixture 비용 + 전달된 재고 보유/부족. 기존 스캐너 부분 수정 없음 |
| `frontend/lib/services/mock_student_calculation_fixture.dart` (추가) | 공용 fixture mixed_growth와 같은 canned 응답. Dart 비용 계산식 없음 |
| `frontend/test/student_calculation_service_test.dart` (추가) | 새 서비스 테스트 8건(DTO·reserved bond·strict 응답·오류·mock 저장소 불변) |
| `frontend/test/student_calculation_process_e2e_test.dart` (추가) | 새 실제 Dart↔Python 왕복 1건, 문서 계산과 일치·파일 바이트 불변 |
| 이 문서 | 백엔드 전용 기록. 공유 status·오케스트레이터 로그는 수정하지 않음 |

기존 파일 11개에 pre 사본이 있다. commit.json은 modified 11, added 7, `status: false`,
`whole: ["almanac/workflows/frontend-redesign-status-backend.md"]`다. slice 종료 사본은
`post_dir: "debug/frontend_fb11a/post"`로 고정하여 이후 다른 워커의 서비스 편집이 섞이지 않게 한다.
debug 로그·생성/검증 도구·사본은 커밋하지 않는다.

### 계약 요약

기존 `planning.student.*`에 맞는 **`planning.student.calculate`**를 그대로 채택했다(FD-162(b)).
입력·출력은 protocol v1의 추가 메서드이며 기존 메서드를 삭제하거나 기존 응답에 필드를 붙이지 않는다. [@student-contract]

| 방향 | 필드 | 계약 |
| --- | --- | --- |
| 입력 | `current_student` | 기존 current_students 항목 그대로. student_id 필수, 인연 현재 진행도 필드 없음 |
| 입력 | `targets` | 기존 계산기/문서 목표의 완전한 19 key. 정수 범위·성장 규칙을 기존 문서 검증기로 검사 |
| 입력 | `inventory` | 선택 inventorySnapshot. 생략은 `{version:1, entries:[]}`이며 보유를 0으로 가정하지 않음 |
| 출력 | `totals` | `{credits: int}`. 보유를 차감하지 않은 총 크레딧 |
| 출력 | `credit_breakdown` | 9범주 각각 nonnegative integer. 비용이 없는 범주도 0으로 포함, 합 = totals.credits |
| 출력 | `resources` | planning.document.calculate의 overall.resources와 같은 행·순서, 크레딧 행 포함 |
| 출력 | `warnings` | 기존 코어의 문자열 목록, 문서 계산과 같음 |
| 예약 | `bond` | 선택 객체로 예약. FB-11a Python/mock 모두 내보내지 않음. Dart는 객체만 허용하며 깊게 불변화해 보존, 의미 해석은 FB-11b |

범주 목록은 다음과 같다. 별도 부분 목표를 정규화하거나 비용을 다시 계산하지 않는다.

| key | 계산 코어의 단위 |
| --- | --- |
| `level` | 학생 레벨 |
| `student_star` | 학생 성급. 전무 해금 때문에 성급을 올리는 비용도 이 범주 |
| `weapon_star` | 전용무기 성급 |
| `favorite_item` | 애장품(기존 코어의 Tier2 비용) |
| `equipment` | 일반 장비 3칸 티어 + 레벨 |
| `ex_skill` | EX 스킬 |
| `weapon_level` | 전용무기 레벨 |
| `skill` | 일반 스킬 3개 |
| `potential` | 능력 개방 HP/ATK/HEAL |

재화 행 key는 `resource_key, item_id, display_name, category, required, owned, shortage,
affected_stage_ids`다. 재고 미확인/누락은 owned·shortage 둘 다 null, 명시적 0은 전체 필요량이
부족량이다. 부족량은 보유를 차감하고 0 아래로 내려가지 않는다. `unresolved:` 행도 보존한다.
affected_stage_ids는 기존 계산기 임시 문서와 같은 `["growth-calculator-stage"]`이며 저장 ID가 아니다.
서버 내부에서 기존 단일 단계 문서 검증·goal 변환·자원 projection을 재사용한다. 비용은 기존
planning_calc에서 한 번만 계산하며, 입력과 저장소·활성 계획을 변경하지 않는다.

AppService 자체의 기존 구현자(프런트 소유 widget 대역)를 깨뜨리지 않기 위해
`AppServiceStudentCalculation` 확장 메서드가 `PlanningStudentCalculationService`에 위임한다.
ProcessAppService·MockAppService가 기능 인터페이스를 구현하므로 AppService 타입에서도
`service.calculateStudent(...)`로 바로 호출한다. 이전 서비스 대역이 새 기능을 호출하면
UnsupportedError가 나며, 기존 메서드 사용은 그대로 가능하다.

mock은 mixed_growth 고정 비용·재화 fixture를 사용하고 재고 보유/부족만 입력에 맞춘다.
임의 목표를 실제로 계산하지 않으며, 기존 mock 문서 계산의 빈 결과도 그대로 둔다(FE3-f1의
기존 동작 테스트 유지). 실제 수치의 문서 일치 검증은 Python 및 process E2E에서 수행했다.

### 일관성 테스트와 검증

새 Python 테스트에서 같은 입력의 크레딧 합계·재화 행 전체·순서·경고를 기존 1페이즈
1단계 문서 계산과 비교하며, 모든 경우에 범주 합 = totals를 검사한다. [@student-tests]

- 공용 fixture 4쌍: 변경 없음, 레벨 30→31, 9범주 동시 성장, 같은 성장 + 0/충분/명시적 미확인 재고.
- 현재 목표보다 낮은 레벨·장비 목표: 비용 0, 재화 행 없음.
- ★5·해금 후 미장착 전무 ★2 Lv30, 장비 `Tier2`·애장품 T2 현재값: 이미 달성한 범주 비용 0, 전무 레벨 증분만 계산.
- 전 항목 최대 목표 1건 + 고정 seed 무작위 유효 목표 50건(장비 부분 레벨·스킬·전무·능력 개방 조합).
- 메타데이터 미존재 학생: 기존 경고 및 unresolved 행을 유지.
- mixed_growth 고정 수치: 총 14,000,529. 범주 순서대로 8,683,465 / 1,200,000 / 1,000,000 /
  500,000 / 31,164 / 80,000 / 2,115,900 / 90,000 / 300,000.
- invalid payload 11종(불필요 저장 ID, missing current/target, null inventory, bool 정수,
  unknown key, 전무/장비 성장 규칙 위반), 계산 예외의 correlated error, 예약 bond 객체 계약.
- Dart는 DTO strict 키·타입·범주 합·재화 부족 산식·중복 resource_key·예약 bond 깊은 불변을 검사.
- 실제 프로세스 왕복은 fixture와 일치하고 기존 문서 계산과도 일치한다. repository revision·goals·
  시나리오 목록이 그대로이며 테스트 저장 루트의 모든 파일 바이트도 동일하다.

직접 실행한 결과:

| 검사 | 결과 / 로그 |
| --- | --- |
| `py -3.11 debug/frontend_fb11a/run-python-worker.py` | **97건 통과**, 24.135초. 새 10건 + 계획/문서/FB-12/parity/계약/shortage/repository/scenario/metadata/gift 회귀. `debug/frontend_fb11a/python-worker.txt` |
| `flutter test --no-pub --concurrency=1 test/student_calculation_service_test.dart test/student_calculation_process_e2e_test.dart` | **9건 통과**(서비스 8 + 새 process 1). `debug/frontend_fb11a/dart-worker.txt` |
| 위 두 파일 + `planning_protocol_contract_test.dart`, `planning_protocol_client_test.dart`, `repository_protocol_contract_test.dart` | **34건 통과**. `debug/frontend_fb11a/dart-worker-regression.txt` |
| `dart analyze lib/services` | **No issues found**. `debug/frontend_fb11a/dart-analyze-services.txt` |
| `codealmanac validate` | **validate: ok**, 39 pages. YAML 뒤 본문 첫 줄 배치로 사용자와 합의한 메타데이터 형식 반영 |
| `git diff --check -- .` | 통과(기존 LF/CRLF 안내만 있음) |

Python 전체 약 26분, 전체 fe_gate·golden·Windows release는 직접 실행하지 않았다.
UI·위젯/golden 테스트는 수정하지 않았다. 스캐너 서비스 3개는 pre 대비 이번 계산 기능 추가만
있는 것을 확인했다. 기존 스캐너 변경·새로 생긴 다른 워커 파일은 커밋 목록에서 제외한다.

### FB-11b 사전 조사 (코드 수정 없음)

| 필요한 데이터 | 저장소 근거 / 판정 |
| --- | --- |
| 인연 랭크별 누적 경험치 수치 | **없음**. backend metadata/planning, SchaleDB adapter, data/extracted의 현재 JSON에는 랭크 경험치 표가 없다 |
| 쓰다듬기 경험치 수치·하루 가능 횟수 | **없음**. 현재 Python/메타데이터/추출 JSON에서 수치를 확인하지 못함. 임의 상수를 넣지 않았다 |
| 선물 기본 exp_value | **있음**: `backend/core/gift_meta_data.py`의 GIFT_ITEMS(52종, 저장된 exp_value 값은 20·60). `gift_meta.py:exp_value()`가 읽는다 |
| 학생 gift_affinities | **있음**: `backend/data/metadata/v1/student_catalog.json`의 gift_affinities(265명), preferred_tags·unique_tags. Ayane는 BB/bB. `canonical_metadata.py`가 검증·분리 보관, `student_meta.py:157~162`가 호환 accessor 제공 |
| SchaleDB 변환·쓰기 | `schaledb_metadata_adapter.py:89` adapt_gifts가 Favor 아이템의 ExpValue→exp_value, Tags→tags 변환. `schaledb_provider.py`는 students/items JSON만 읽음. `tools/developer_tools.py:991`가 별도 gift_meta_data GIFT_ITEMS를 원자적으로 갱신 |
| 기존 선호 배수 계산 근거 | `tools/developer_tools.py:833` _student_gift_affinities: preferred/unique 태그 + UNIVERSAL_GIFT_TAGS(BC/Bc/ew), match_count 최대 3, multiplier=1+match_count, points=exp_value*multiplier. 개발 도구 전용이며 FB-11b에서 도메인 경계로 분리할 후보 |

인연 보상 추출표와 경험치 표는 구분해야 한다:

- `data/extracted/jp-json/FavorLevelRewardExcel.json`은 13,750행이고 key는
  `character_id, favor_level, stat_type, stat_value`뿐이다. 인연 **능력치 보상**이며 경험치 표가 아니다.
  public-json의 동명 파일 및 student-stats-jp.json도 이 통계 경로라 누적 경험치 근거로 쓰지 않는다.
- `debug/il2cpp_types/types-steam-bbe68ad3.json`에는
  `MX.Data.Excel.FavorLevelExcel` 타입(Level·ExpType vector),
  `MX.Data.Excel.CafeInteractionExcel` 타입(FavorEmoticonRewardParcelType·Id·Amount)이 있다.
  **타입/필드 이름만 있고 실제 행 수치가 없다.** 따라서 이름을 발견했다고 경험치 숫자가 확보된 것은 아니다.
- FB-11b에 필요한 데이터원: 같은 클라이언트 버전의 FavorLevelExcel 실제 행과 ExpType 값의
  해석 근거(랭크 경험치·누적 변환), CafeInteractionExcel 실제 보상 행과 parcel type 확인,
  쓰다듬기 횟수/재사용 간격의 설정·행 근거. 현재 추출 pipeline의 표 목록에는 이 두 표가 없다.
  데이터를 확보하기 전 FB-11b의 경험치/일수 계산을 구현하지 않는다. 외부 숫자·시안 예시를 채택하지 않았다.
- 조사 중 어떤 메타데이터·SchaleDB 동기화·추출 pipeline·스캐너/tactic 파일도 고치지 않았다.
  로컬 조사 결과만 `debug/frontend_fb11a/bond-type-survey.json`, `bond-field-survey.json`에 남겼다.

### 프런트 워커 연결 메모 (프런트 소유, 이번에 수정하지 않음)

`growth_calculator_adapter.dart`의 `calculateGrowthTargets`에서 임시 문서 생성/호출 대신 다음을
한 번 호출한다. 기존 250ms 디바운스·요청 번호/늦은 응답 버림·취소·오류 상태는 그대로 둔다.

```dart
final result = await service.calculateStudent(
  currentStudent: request.currentStudent,
  targets: request.targets,
  inventory: request.inventory,
);
```

- import는 기존 `services/app_service.dart`면 DTO·확장 메서드가 함께 보인다. 기능 판별이
  필요하면 `service is PlanningStudentCalculationService`를 사용한다.
- 총 크레딧은 `result.credits`, 경고는 `result.warnings`다. `result.resources`에서
  resourceKey가 credits인 행을 빼면 기존 성장 재화 목록이다. `row.toWire()`를 기존
  GrowthCalculatorResourceRow.fromWire에 넘길 수 있고 requiredAmount·owned·shortage를 직접 매핑해도 된다.
- `creditBreakdown`은 현재 `GrowthCalculatorCreditBreakdown.unavailable` enum/getter뿐이므로
  프런트에서 available 상태 + `Map<String,int>`를 담는 형태로 확장하고 `result.creditBreakdown`을 채운다.
  9범주를 그대로 그리거나 EX+일반 스킬, 전무 성급+레벨처럼 표시용으로 합칠 수 있다.
  모든 비용 범주가 합계에 포함되도록 학생 성급·애장품·능력 개방을 빠뜨리지 않는다.
- 필요 재화 수량을 더해 한 숫자로 만들지 않는다. unknown owned/shortage는 지금처럼 Unknown으로
  매핑한다. 크레딧 보유·계획 포함·스캔 시각의 FD-172 정책은 별도 기존 상태를 유지한다.
- 이번 DTO의 reservedBond가 null인 것은 FB-11a의 정상 응답이다. 인연 타일은 FB-11b 전까지 기존
  빈 상태를 유지한다. 인연 현재값/진행도 입력 계약을 이번에 늘리지 않았다.
- frontend 위젯 대역은 기존 AppService만 구현해도 계속 컴파일된다. 새 기능을 쓰는 대역은
  기능 인터페이스도 구현하거나 MockAppService의 calculateStudent를 override한다.

### 사용자 실행 단계

① 사용자 PC Python 전체 테스트. 결과 파일은 **debug/frontend_fb11a/python-full.txt**다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7\backend"
py -3.11 -m unittest discover -s tests -v *> ..\debug\frontend_fb11a\python-full.txt
Get-Content ..\debug\frontend_fb11a\python-full.txt -Tail 5
```

② **프런트·백엔드 두 워커 모두 멈춘 뒤** 아래 순서로 실행한다. gate GREEN 전 커밋하지 않는다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fb11a -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fb11a
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesigndocs
```

실행 실패가 있으면 해당 로그로 확인한다. 전체 검사 통과·커밋 결과는 이 백엔드 상태 문서에
추가한다. 다음 행동: 사용자 전체 검증 → FB-11a 커밋 → 프런트 계산기 어댑터 연결,
FB-11b는 누락 데이터원을 먼저 확보한다.

## FB-1 읽기 전용 설계 조사 (2026-10-08)

**FB-11a 사용자 승인. 프런트 수정 → gate GREEN → fb11a 커밋까지 코드 편집 중지.**
이번 작업은 아래 조사 기록만 추가한다. Python·Dart·계약·fixture·commit manifest·프로필은
수정하지 않았고, FB-1 구현을 시작하거나 gate를 실행하지 않았다. 조사 시 HEAD는
`f2cf4fb81c07b30188a49d1240b3169ccc9fbf33`다. 아래 계약과 문서 v2는 **제안**이며 구현된 계약이 아니다.

### 요구와 현재 경로

워크플로의 **FB-1 절 전체**를 읽었다. `repository.plan.*` 신설, goals-only 프로필의 첫 로드
영속 이관, 저장과 같은 revision의 goals v1 파생, **문서에서 명시적인 "목표 없음"**, Python·계약·
Dart·mock·계약 테스트·process E2E 한 슬라이스, v6 가져오기·시나리오 저장·통계 회귀 0이 요구다. [@workflow]
FD-003·026·027·049·050·065·066·067·083·138도 함께 확인했다
(`docs/frontend-redesign/decision-register.md`). FD-067의 기존 활성 계획 자동 시나리오 보존과
FD-083의 활성 계획 계산 요약을 계약 초안에 포함한다.

- `backend/core/repository_store.py`: 프로필에는 students·inventory·goals·idempotency만 있다.
  `_profile`이 키 집합을 정확히 검사하므로 active document를 파일에 덧붙이기만 하면 corrupt_data다.
  `get_state`/Dart `RepositoryState.fromWire`도 현재 다섯 응답 키를 고정한다.
- `frontend/lib/ui/widgets/plan_section_layout.dart::_loadRepositoryPlan`: goals 순서로 학생당 단계 1개,
  페이즈 1개를 메모리에서 만든다. 문서 ID `active-plan`, 페이즈 ID `v6-imported-plan`,
  단계 ID `v6-<student_id>-1`, 이름은 notes 또는 "v6 목표"다. 빈 goals는 phases=[]다.
- `frontend/lib/ui/models/planning_models.dart::planningDocumentTargets`: null/없는 goal 값을 현재값으로
  채우고, 인연은 현재값 또는 1을 넣은 뒤 정규화한다. **이 반환값을 그대로 저장해서는 안 된다.**
- `backend/core/planning_document.py`: 현재 문서 v1은 19개 key의 정수 targets를 요구하며
  bond_rank도 1~100이다. `_goal`은 18개만 StudentGoal로 매핑한다. goals v1에는 인연 필드가 없다.
- `frontend/lib/ui/models/active_plan_bond_target.dart`: 지금은 ActivePlanDocumentSource가 없으면
  null이다. goals에서 인연 목표를 만들지 않으며 마지막 단계 목표를 조회한다. FB-1 연결 경계다.
- `backend/core/scenario_store.py::_calculation_summary`: 문서 projection으로 목록 KPI를 만든다.
  active get도 이 로직을 공용화해서 사용한다. Python이 계산·저장을 소유한다
  (`almanac/architecture/runtime-boundaries.md`).

### "목표 없음"의 계약 초안

권장안은 **PlanningDocument v2의 19-key nullable targets**다. key는 모두 존재해야 하며,
값은 int 또는 null이다. `null`은 해당 항목의 목표 없음이고, 0은 그 필드에서 허용되는 실제
수치다. bond_rank는 null 또는 1~100이다. 예를 들어 현재 인연 35라도 목표가 없으면
`"bond_rank": null`로 저장하고, 현재 인연을 몰라도 null로 저장한다.
현재값과 같거나 낮은 정수 목표는 달성한 명시적 목표이며 null과 다르다.

- 단계 없음, 단계의 특정 목표 없음, 모든 targets가 null인 단계, 빈 활성 계획(phases=[])을
  구분한다. 빈 문서도 저장된 활성 문서이므로 재로드 때 예전 goals로 되살리지 않는다.
  이관 시 all-null goal 항목은 보존하고, 새 편집기의 무성장 단계 제거 정책과 구분한다.
- 단계는 계속 누적 절대 목표다. 같은 학생의 이전 명시적 목표는 후속 단계에도 유지한다.
  int 이후 더 작은 int나 null로 지우는 입력은 회귀 오류로 처리한다. 목표 제거는 그 학생의
  관련 모든 단계에서 해당 목표를 지우는 문서 편집으로 표현한다. 처음 null이던 필드는
  후속 단계에서 처음 정수 목표를 가질 수 있다.
- 계산은 null을 원본 목표로 보존한 채 기존 StudentGoal/계산 코어에 전달한다. 현재값·이전
  단계의 계산 후 상태 및 전무/장비의 필수 선행 성장은 계산 중에만 적용한다. 이 유효 상태를
  다음 단계에 넘기는 공용 코어 경계를 마련하고, 계산용 현재값을 저장 targets로 되쓰지 않는다.
  비용식·정규화는 복제하지 않는다. 현재 `_advance`를 nullable 목표에 그대로 쓰면 안 된다.
- 문서 구조·값 범위·학생별 단계 순서는 저장 시 검사한다. null이 낀 잠금/선행 조건 검사는
  실제 현재 상태와 공용 성장 규칙을 함께 사용해야 한다. 현재 인연을 모른다고 1을 만들거나,
  애장품 목표가 있다고 사용자가 정하지 않은 인연 목표를 만들지 않는다. 데이터가 부족하면
  계산 경고로 드러낸다. 이관의 애장품/전무/부분 목표 fixture로 정책을 먼저 고정한다.
- 기존 문서 v1과 FB-11a 단일 학생의 완전한 정수 targets는 계속 받는다. 문서 v2를 새로운
  schema 분기로 추가하고 `planning.document.calculate`·scenario 저장/비교가 같이 읽도록 한다.
  기존 v1의 정수 의미를 바꾸거나 FB-11a 계약을 nullable로 바꾸지 않는다.

문서 버전 선택은 FB-1 구현 착수 때 확정할 사항이다. 현재 v1만으로는 목표 없음의
lossless 저장이 불가능하므로, schema·Python·Dart 문서 DTO·시나리오 경로의 동시 확장이 필요하다.

### repository 계약 초안 (protocol 1)

| 메서드 | 입력 payload | 성공 출력 payload | 의미 |
|---|---|---|---|
| `repository.plan.get` | `{profile_id}` | `{profile_id, revision, document, calculation}` | kind=plan인 저장 문서와 현재 profile revision, 계산 요약. legacy 첫 로드는 이관 후 revision을 반환 |
| `repository.plan.save` | `{profile_id, expected_revision, idempotency_key, document}` | `{revision}` | 전체 활성 문서와 파생 goals를 같은 profile revision으로 저장 |
| `repository.plan.replace` | `{profile_id, expected_revision, expected_scenario_revision, idempotency_key, document, archive_name, archive_description}` | `{revision, scenario_revision, archived_scenario_id}` | 기존 활성 문서를 kind=scenario로 보존하고 새 활성 문서/goals 저장을 단일 transaction으로 수행 |

`document`는 위 문서 v2 제안이며 활성 입력은 kind=plan만 받는다. 새 프로필과 이관 완료
프로필에는 빈 경우에도 문서가 존재한다. replace에서 기존 phases가 비었으면 보존할 계획이
없으므로 archived_scenario_id=null, scenario_revision은 증가하지 않는 안을 권장한다.
페이즈로 추가는 프런트가 활성 문서와 새 페이즈를 합쳐 save하는 기존 FD-080 방향이다.
ID 중복·학생별 단계 회귀를 백엔드에서 검사하고 expected_revision으로 동시 편집을 막는다.

`calculation`은 scenario.list의 PlanningScenarioCalculationSummary와 같은 모양이다:
credits, required_resource_type_count, known_shortage_type_count, inventory_complete,
first_bottleneck_phase_number(null 허용), representative_shortage(null 또는
resource_key·item_id·display_name·category·shortage). 문서와 같은 revision의 students/inventory로
계산한다. 요약 계산 실패는 calculation=null로 드러내되 저장 문서는 조회 가능하게 유지한다.
상세 활성 계획 수치는 FD-026대로 저장 문서의 `planning.document.calculate` 결과를 쓴다.

기존 repository.state.get 응답에 문서를 몰래 추가하지 않는다. 새 plan get/save DTO와
RepositoryService 기능을 추가하고 ProcessAppService·MockAppService·strict fromWire를 맞춘다.
state와 plan을 따로 읽을 때 revision이 다르면 재조회하여 같은 snapshot으로 계산한다.
기존 invalid_payload·revision_conflict·idempotency_conflict·repository_busy·persistence_failed
오류 규칙을 재사용하고, replace의 두 revision을 오류 details에서 구별한다.
재시도는 최초 응답을 그대로 반환하고 시나리오를 두 번 만들지 않아야 한다.

저장상의 주의: `_catalog_mutation`은 profile+catalog 두 파일을 순서대로 쓰고 **잡힌 예외**에
rollback한다. ScenarioStore는 별도 파일·lock·collection revision을 쓴다. 기존 `scenario.create`
후 `plan.save`를 호출하는 조합으로 FD-067을 충족했다고 볼 수 없다. 공통 transaction 경계,
고정 lock 순서, 중단 후 journal 복구를 설계하고 모든 관련 읽기가 미완료 transaction을
복구한 뒤 보도록 한다. 문서/goals/idempotency는 한 profile payload, archive는 scenario payload,
revision 요약은 catalog에 함께 반영한다. 기존 idempotency 응답 검사는 `{revision}`만 허용하므로
replace 응답 저장 형식을 확장할 때 기존 캐시도 계속 읽어야 한다.

### goals v1 파생 방식

문서 순서(phase 순서 → stage 순서)에서 학생별 **마지막 단계**를 선택한다. 첫 등장 학생
순서를 유지하여 학생당 goal 하나를 만든다. 마지막 단계의 누적 targets를 쓰고, 단계 비용을
더하거나 필드별 최대값을 임의로 합치지 않는다.

| 문서 target | goals v1 field |
|---|---|
| level / student_star | target_level / target_star |
| weapon_level / weapon_star | target_weapon_level / target_weapon_star |
| ex_skill / skill1·2·3 | target_ex_skill / target_skill1·2·3 |
| equip1·2·3_tier / equip1·2·3_level | target_equip1·2·3_tier / target_equip1·2·3_level |
| equip4_tier | target_equip4_tier |
| stat_hp / stat_atk / stat_heal | target_stat_hp / target_stat_atk / target_stat_heal |
| bond_rank | 대응 필드 없음. 활성 문서에만 보존하고 goals v1에 새 key를 넣지 않음 |

nullable 값은 대응 target_*에도 null로 남긴다. student_id를 넣고, 단계가 사라진 학생의
파생 goal은 제거한다. 빈 문서는 `{version:1, goals:[]}`다. all-null 학생도 호환 목록에서
보존하지만, 인연 게이지/구체적 목표 유무는 숫자를 채워서 유도하지 않는다.
기존 favorite와 notes의 lossless 보존이 필요하다. 권장 초안은 문서의 학생별 `goal_metadata`
(student_id → favorite·notes)로 보존하고, 새 학생은 favorite=true, notes는 최종 단계 이름을
기본값으로 삼는 것이다. 이 metadata의 strict schema도 문서 v2 안에 포함한다.

파생은 저장 transaction 안에서 백엔드만 수행한다. students/inventory 스캔·수동 수정은
사용자 targets를 다시 만들지 않고 projection만 바꾼다. goals v1은 호환 소비용 결과이며
활성 문서 수치의 새 원천이 아니다(FD-026·138).
기존 `repository.goals.save`도 영향받는다.
두 저장 원천을 남기지 않도록 legacy writer를 같은 goals→문서 변환/transaction으로 연결하는
안이 필요하다. empty/legacy 단일 페이즈는 이 경로를 허용하고, 다중 페이즈·인연 목표를 가진
문서의 손실성 덮어쓰기는 명시적 오류로 막는 안을 권장한다. 정확한 오류 계약은 FB-1에서 확정한다.

### 기존 프로필의 첫 로드 이관

1. 저장 형식 v1 reader를 유지하고, active document가 없는 legacy 프로필만 대상으로 한다.
   profile의 새 저장 버전/명시적 active 필드로 이관 완료를 구별한다. catalog·inventory·protocol
   버전은 각각 따로 취급한다. 문서가 빈 것은 미이관 상태가 아니다.
2. 목표 순서·학생당 단계 1·페이즈 1·기존 표시 이름 규칙을 재사용한다. 18개 goal target은
   원래 정수/null 그대로 매핑하고 bond_rank는 **항상 null**이다. 현재 students에서 목표를
   채우지 않는다. favorite·원래 notes도 보존한다. goals가 비면 empty active document를 저장한다.
3. repository lock 아래 이관 여부를 재확인하고 문서+파생 goals+profile/catalog revision을
   한 번만 저장한다. get_state와 plan.get 등 공개 profile-state 로드가 같은 이관 함수를 쓴다.
   동시 첫 로드·재시작은 한 번만 이관한다. 기존 파일과 idempotency 내역을 보존하고,
   실패 시 corrupt legacy를 빈 문서로 덮어쓰지 않는다.
4. 이미 저장된 프로필의 이관은 revision을 한 번 증가시키고 반환 revision이 권위값이다.
   listProfiles에서 받은 이전 revision을 이후 저장에 쓰지 않는다. 기존 시나리오의
   base_profile_revision은 과거 기준으로 유지되어 stale 표기가 생길 수 있음을 소비자에 전달한다.
  신규 생성/v6 import는 가능하면 최초 profile 생성 transaction에 문서를 함께 넣어 별도 이관을 피한다.
  `backend/tools/seed_ui_test_profile.py`는 v6 import 후 get_state의 revision으로 scenario를 만들므로
  이관 후 반환 revision과 기존 시나리오 seed의 반복 실행을 회귀 검사한다.
5. 현재 임시 변환의 `v6-<student_id>-1` ID는 중복 student goal에 충돌한다. 기존 schema는 중복
   goals를 명시적으로 막지 않고 calculate_plan_totals는 각 항목을 더한다. 마지막 항목으로
   조용히 접으면 기존 비용이 바뀔 수 있다. 중복 fixture와 이관 오류/정리 정책을 먼저 정해야 한다.
   스캔에 없는 학생·부분 목표·잠금 조건이 맞지 않는 legacy 목표도 삭제/가짜 목표 생성으로 처리하지 않는다.

필수 회귀 fixture: null bond(현재 알려짐/모름), all-null goals, 명시적 0, 현재와 같은 목표,
부분 목표/전무의 필수 성급/애장품, 빈 계획 저장 후 재로드, 여러 단계의 최종 파생,
v6 가져오기 후 비용·재화 parity, 재시작·동시 첫 로드, stale revision, idempotent replay,
replace 중 저장 실패/프로세스 중단 복구, 기존 v1 scenario 저장·비교·통계 경로.
process E2E는 legacy 첫 get→새 문서 save→재시작 get→goals/문서 계산 및 교체 보존까지 묶는다.
이번 조사에서는 테스트를 작성하거나 실행하지 않았다.

### 영향받는 소비자 목록

| 소비자/경계 | FB-1 영향 |
|---|---|
| JsonRepository, RepositoryProtocolV1, repository DTO/schema/fixtures, ProcessAppService, MockAppService | 새 문서 저장/이관/파생, 엄격한 키 검사, revision·idempotency·transaction 일치 |
| planning_document.py, 문서 calculate schema/fixture, Dart planning_models.dart | 목표 없음/문서 v2, 단계 진행 상태, v1 호환 |
| ScenarioStore, scenario protocol/DTO, compareScenarios | 문서 v2 round-trip, 원자적 archive, 공용 활성 요약, 기존 v1 scenario 호환 |
| plan_section_layout.dart, plan_student_selector.dart, FE4 저장 흐름 | `_loadRepositoryPlan` 메모리 변환을 plan get으로 교체, save/append/replace 연결 |
| active_plan_bond_target.dart, student_page.dart/학생 인디케이터 | 저장 문서의 마지막 nullable bond 조회; 현재 plannedIds는 state.goals 기준이므로 문서로 연결 |
| growth_calculator_adapter.dart | 현재 계획 포함 판정은 goals 기준. FB-1 후 문서로 연결; 단일 학생 계산 자체는 FB-11a 유지 |
| inventory_page.dart | 현재 state.goals→calculateShortages. 호환 경로 유지, 새 활성 화면은 FD-026 문서 projection으로 연결 |
| statistics_page.dart, 통계 view model/fixture | 현재 goals→calculatePlan/calculateShortages와 goals.length. 새 계획 수치는 저장 문서 projection으로 연결 |
| scenario 목록/비교의 활성 행, FE5/FE6/FE7 | get.calculation 공용 KPI, 현재 상태 변경 때 재계산, 문서 저장 때 revision 갱신 |
| title_page.dart, account_section_cluster.dart, scan_page.dart, tactical_page.dart, 프로필 전환 | state 로드에 이관 revision 변화가 생김. 갱신 revision 전파/캐시 재조회 검사; scanner/tactic 파일은 별도 소유자 협의 |
| seed_ui_test_profile.py, repository/v6 migration/parity/process E2E, 계획·학생·통계·인벤토리 service/widget 대역 | legacy writer 정책과 첫 로드 부작용, 신규 RepositoryService capability, strict DTO fixture 갱신 |

프런트 파일은 조사만 했다. 코드 동결 해제 후에도 백엔드 워커가 UI·위젯/golden 테스트를
편집하지 않고, 문서 버전/새 서비스 계약을 프런트 워커에게 연결 메모로 전달해야 한다.

### 다음 백엔드 요청: 학생 catalog has_favorite_item

프런트 요청 **`planning.student.catalog` 항목에 `has_favorite_item: bool` 추가**를 접수한다.
**권장: FB-1과 분리한 작은 catalog 확장 slice**로, fb11a 커밋 이후 먼저 진행한다.
이 필드는 정적 가용성 데이터이고 프로필 저장·이관·목표 없음과 독립적이다. 계산기 애장품 행의
현재 전체-true 폴백을 해소하는 데 FB-1의 저장 설계를 기다릴 필요가 없다. slice 번호는
오케스트레이터가 배정하며 이번 조사에서 FB 표/결정 등록부를 수정하지 않는다.

- 근거: `backend/core/student_meta.py::favorite_item_enabled(student_id, server="kr")`가 bool을
  반환한다. 내부 `has_favorite_item`은 "yes"/"no" 문자열이며 서버별 필드 → 공유 필드 →
  favorite 학생 집합 순서로 판정한다. source of truth는
  `backend/data/metadata/v1/student_catalog.json`이고 generated student_meta_data.py는 수정 대상이 아니다.
- 제안 의미: 현재 catalog 요청이 `{}`이고 profile server 입력이 없으므로 **KR 서버에서 애장품이
  제공되는 학생인지**로 고정한다. JP 제공 여부, 현재 보유/장착 여부, 목표 equip4_tier와 구분해
  README에 적는다. JP 지원은 별도 server 선택 계약이 생길 때 확장한다.
- 범위: protocol_v1.py catalog builder, catalog schema·fixture·README/Python contract tests,
  StudentCatalogEntry 필드·strict fromWire·metadata getter, MockAppService `_studentCatalogWire`,
  `frontend/tool/export_student_catalog_asset.py`와 재생성한 `frontend/assets/student_catalog.json`,
  DTO/mock/process 검증을 같은 작은 slice에 넣는다. bool은 모든 신규 catalog 항목에 제공하고
  문자열 "yes"/"no"/null을 wire bool 대신 보내지 않는다. 기존 UI+backend 동시 배포 원칙을 따르며,
  기존 fixture/수동 DTO 생성자의 누락·fallback 처리도 계약에서 명시한다.
- 검증: true/false 및 KR/JP 가용성 차이 사례, 잘못된 bool 타입 거부, runtime catalog↔bundled mock
  값 parity, process 왕복. 아직 폴백인 missing-student를 실제 가용 학생으로 간주하지 않는다.
- 프런트 연결: `StudentCatalogEntry.metadata`에 bool을 넣으면 student_page.dart의
  `_calculatorMetadata`가 이미 해당 key를 우선한다. 폴백 제거/애장품 행 숨김 검증은 프런트 워커
  몫이며 이번에 고치지 않았다. FB-1에는 이 필드를 의존 조건으로 묶지 않는다.

조사 문서 검증: `codealmanac validate` OK. 변경 대상은 이 상태 문서뿐이며, 코드 동결을 유지한다.
