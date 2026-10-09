---
title: "Frontend Redesign Backend Status"
summary: "FB-8a/b 계획·시나리오 authoring 저장과 승인된 설계 조사, Lane A의 FB-14 프리셋·그룹, FB-1c 교체·복구 및 문서 v2 기록입니다."
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
