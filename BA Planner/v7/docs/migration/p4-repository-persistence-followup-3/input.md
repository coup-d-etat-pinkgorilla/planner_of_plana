# P4 보완 작업 지시 3 — Nested contract, typed state와 실제 process E2E

## 작업 정보

- 작업 ID: `ba-planner-v7-p4-repository-persistence-followup-3`
- 작업 디렉터리: `<SLAVE_REPOSITORY_ROOT>\docs\migration\p4-repository-persistence-followup-3`
- 기준 상태: 원본 P4, follow-up-1과 follow-up-2 부분 증분이 모두 적용된 작업 트리
- patch 성격: follow-up-2 위의 마지막 P4 완료 증분
- 실행 환경: 슬레이브와 마스터는 서로 다른 PC이며 파일시스템을 공유하지 않음

## 목표

P4에 남은 다음 네 영역을 모두 완료한다.

1. Repository request/state의 nested DTO schema를 실제 Python DTO와 일치시킨다.
2. Dart가 공용 fixture 28건 이상의 `valid` 기대값을 실제 판정하고 runtime malformed
   success를 거부하게 한다.
3. Repository state를 immutable typed model로 바꿔 Widget의 raw map cast를 제거한다.
4. Temporary storage root에서 실제 Dart `ProcessAppService` ↔ Python child process의
   저장·종료·재시작·복원 E2E를 추가한다.

이미 승인된 persistence, atomicity, profile lifecycle, corruption fail-closed와 method별
top-level success schema를 다시 설계하지 않는다. 이 작업 완료 뒤 P4 전체 완료 조건을
마스터가 판정할 수 있어야 한다.

## 작업 전 필수 확인

다음을 UTF-8로 완전히 읽는다.

1. `AGENTS.md`, `README.md`
2. `almanac/workflows/p0-p6-workflow-status.md`의 P3·P4 절
3. `almanac/workflows/p0-p6-workflow.md`의 공통 불변식과 P4 완료 조건
4. `almanac/workflows/slave-artifact-handoff.md`
5. `almanac/workflows/cross-pc-slave-handoff.md`
6. P4 원본과 follow-up-1/follow-up-2의 `input.md`
7. `docs/migration/p4-repository-persistence/repository-storage.md`
8. `contracts/README.md`
9. `contracts/repository-protocol-v1.schema.json`
10. `contracts/fixtures/repository_protocol_v1.json`
11. `backend/core/planning.py`
12. `backend/core/repository_dto.py`, `repository_store.py`, `repository_protocol_v1.py`
13. repository parity/persistence/protocol Python tests
14. `frontend/lib/services/backend_process.dart`
15. `frontend/lib/services/planning_protocol_client.dart`
16. `frontend/lib/services/repository_service.dart`
17. `frontend/lib/services/process_app_service.dart`, `mock_app_service.dart`
18. `frontend/lib/ui/pages/planning_page.dart`
19. repository contract, protocol client, planning page/profile panel Flutter tests
20. 기존 planning protocol의 Python/Dart fixture validator와 실제 process E2E

`py -3.11`, `flutter`, `dart`, `codealmanac`을 먼저 확인한다. 이번 작업은 cross-language와
실제 process 검증이 핵심이므로 하나라도 실행할 수 없으면 `COMPLETED`로 보고하지 않는다.

## 승인 baseline gate

변경 전 다음을 재현해 `verification.txt`에 기록한다.

- P3 parity fixture 26 cases, parity 10 tests
- P4 집중 Python 22 tests, 전체 Python 39 tests
- Flutter 전체 41 tests
- repository protocol fixture version 1, 28 cases(valid 14, invalid 14)
- `flutter analyze`, Windows release, Almanac와 diff 검사 통과
- profile lifecycle 및 corruption follow-up tests 통과
- 모든 repository method의 top-level `{ "nonsense": true }` success response가 schema에서
  invalid

다음 미해결 baseline도 직접 재현한다.

- state response의 confirmed values에 `display_name`, `shortages`가 들어가도 schema valid
- goal `target_level: 999`가 schema valid
- students update의 `students: [{"junk": true}]`가 schema valid
- inventory/goals update의 빈 nested object가 schema valid
- Dart fixture test가 `case['valid']`를 읽지 않음
- `PlanningProtocolClient._validSuccessPayload()`가 `repository.*`를 무조건 true로 반환
- `RepositoryService.loadRepositoryState()`가 raw `Map<String, dynamic>` 반환
- 실제 Dart↔Python repository restart E2E 없음

이 baseline과 다르거나 선행 P4/follow-up 변경이 없으면 임의 재구성하지 말고 `BLOCKED`로
보고한다.

## 필수 구현

### 1. Nested DTO schema를 Python owner와 일치

Schema 규칙을 추측하지 말고 아래 Python owner와 실제 validator를 단일 기준으로 사용한다.

- `ConfirmedStudent`, `CONFIRMED_STUDENT_VALUE_FIELDS`, `FORBIDDEN_BUCKET_FIELDS`
- `InventoryEntry`, `InventorySnapshot`
- `StudentGoalRecord`와 `_GOAL_MAXIMUMS`
- `planning.py`의 `MAX_TARGET_*`

Confirmed student:

- `values`는 다음 field만 허용한다.
  `level`, `student_star`, `weapon_state`, `weapon_star`, `weapon_level`, `ex_skill`,
  `skill1`, `skill2`, `skill3`, `equip1`, `equip2`, `equip3`, `equip4`,
  `equip1_level`, `equip2_level`, `equip3_level`, `combat_hp`, `combat_atk`,
  `combat_def`, `combat_heal`, `form_combat_stats`, `stat_hp`, `stat_atk`, `stat_heal`
- string fields는 string 또는 null, 일반 수치 fields는 bool이 아닌 integer 또는 null,
  `form_combat_stats`는 object여야 한다.
- `display_name`, metadata, goal, cost, total과 shortage 계열 및 모든 unknown field를 거부한다.
- provenance는 string-to-string object만 허용한다.

Inventory:

- exact entry fields, 필수 `key`와 `quantity`, nullable string fields와 nullable integer
  `index`를 Python DTO와 같게 검증한다.
- empty inventory object, unknown field와 잘못된 nested type을 request/response 모두 거부한다.

Goal:

- `student_id`, `favorite`, 모든 `target_*`, `notes`만 허용한다.
- target은 integer 또는 null이며 최소 0과 다음 최대값을 적용한다.
  level 90, star 5, weapon level 60, weapon star 4, EX 5, 일반 skill 10,
  equipment tier 10, equipment level 70, equip4 tier 2, stat 25.
- bool target, `target_level: 999`, unknown target과 wrong notes/favorite type을 거부한다.
- null은 현재 값 유지 의미이므로 0과 구분한다.

Request schema:

- `repository.students.update.students`는 confirmed student array definition을 사용한다.
- inventory/goals update는 canonical snapshot/plan definition을 사용한다.
- request의 profile ID도 canonical 24자 lowercase hex definition을 사용한다.
- response state와 request update가 같은 nested definition을 재사용한다.

Python contract test는 hard-coded schema와 Python DTO validator 사이의 drift를 자동 검출한다.
대표 valid/invalid payload를 양쪽에 넣어 같은 판정을 확인한다.

### 2. Fixture 확장과 Dart valid/invalid validator

기존 28 cases를 삭제하거나 의미를 약화하지 않고 위 nested 사례를 추가한다.

최소 추가 invalid cases:

- confirmed `display_name`, `shortages`, unknown value
- wrong confirmed value type 및 provenance type
- goal maximum 초과와 bool target
- empty/malformed inventory and goals update
- junk student update
- non-canonical request profile ID
- nested state unknown/missing field

Dart에 repository wire-shape validator를 작성해 fixture의 모든 case에 대해 계산한 결과와
`case['valid']`를 비교한다. envelope key와 method prefix만 검사하는 기존 test를 교체한다.

- request와 response를 모두 판정한다.
- method별 top-level payload와 nested DTO를 검사한다.
- exact key, nullable/type/range를 Python schema와 일치시킨다.
- case ID별 실패 진단을 출력한다.
- fixture valid/invalid 수를 검증 로그에 기록한다.

전체 JSON Schema library 도입은 필수가 아니다. 다만 작은 validator를 production runtime
validator와 공유하거나 명확히 분리해 drift 방지 test를 둔다.

### 3. Runtime malformed-success 차단

`PlanningProtocolClient._validSuccessPayload()`의 repository wildcard true를 제거한다.

- profile list/create/current, revision mutation, state get을 method별 검증한다.
- exact top-level keys와 최소 nested shape를 검사하고 typed factory가 최종 nested 검증을
  소유하게 한다.
- malformed, missing, unknown, method-mismatched success는
  `BackendProtocolException` 및 기존 fatal protocol policy로 처리한다.
- error response는 기존 repository code/retryable/details 정책을 유지한다.

Fake backend tests에서 최소 다음을 검증한다.

- `{ "nonsense": true }`
- method-mismatched valid payload
- bool/negative revision
- malformed profile list/current/state
- invalid response 후 pending request 실패, 연결 종료와 재시작 가능

### 4. Immutable typed repository state

`repository_service.dart`에 책임이 드러나는 immutable type을 추가한다.

- `RepositoryState`
- 필요하면 `ConfirmedStudentState`, `InventorySnapshotState`, `StudentGoalState` 등 작은 nested
  types

`RepositoryState.fromWire()`는 exact keys, canonical ID, non-negative non-bool revision와
nested DTO를 검증한다. 다음 필드만 소유한다.

- profile ID
- revision
- confirmed current students
- inventory snapshot
- user goal plan

정적 metadata, calculated total과 shortage를 포함하지 않는다.

- `RepositoryService.loadRepositoryState()`는 typed state를 반환한다.
- `ProcessAppService`는 wire map을 즉시 typed state로 바꾼다.
- `MockAppService`도 같은 type과 revision 의미를 사용한다.
- `PlanningPage`는 property만 사용하고 `state['...']`, raw nested map cast를 하지 않는다.
- typed factory invalid test와 Mock planning restore/save Widget regression을 추가한다.

### 5. 실제 Dart `ProcessAppService` ↔ Python restart E2E

실제 Flutter test에서 fake handle이 아니라 `Process.start`로 Python backend를 두 번 실행한다.

필요하면 `BackendProcessConfig`에 immutable optional environment override를 추가하고
`startBackendProcess()`가 `Process.start(environment: ...)`로 전달하게 한다.

- production 기본 environment와 launcher 동작은 기존과 같아야 한다.
- 부모 환경을 유지한다.
- test에서만 `BA_PLANNER_STORAGE_ROOT=<TemporaryDirectory>`를 전달한다.
- 실제 사용자 profile/DB 또는 홈 경로에 쓰지 않는다.

E2E 흐름:

1. temporary directory와 실제 backend working directory 준비
2. 첫 `ProcessAppService` 연결
3. profile create/list/current, rename/select
4. canonical goals 저장; public service가 students/inventory update를 제공하면 함께 저장
5. typed state와 revision 확인
6. service dispose 및 child process 종료 확인
7. 같은 storage root로 두 번째 process/service 연결
8. 동일 profile ID, revision, students/inventory/goals 복원 확인
9. 두 번째 process 종료 및 temporary directory 정리

timeout, stderr와 process exit를 실패 진단에 포함한다. Python executable은 Windows에서
`py -3.11` 또는 명시된 interpreter를 사용한다. Fake process test는 runtime malformed
response용으로 유지하되 real E2E를 대체하지 않는다.

### 6. 문서 정합성

- `contracts/README.md`: nested strict contract와 Dart runtime 검증
- `repository-storage.md`: typed state와 temporary process E2E
- fixture 최종 case 수, valid/invalid 수와 재현 명령

슬레이브는 workflow 상태를 `완료`로 바꾸지 않는다.

## 예상 변경 범위

- repository schema와 fixture
- `contracts/README.md`
- Python repository protocol contract test
- `backend_process.dart`
- `planning_protocol_client.dart`
- `repository_service.dart`
- `process_app_service.dart`, `mock_app_service.dart`
- `planning_page.dart`
- Dart repository contract/client/process/widget tests
- `repository-storage.md`

다른 파일이 필요하면 이유를 `output.md`에 기록한다.

## 금지 및 제외 범위

- 원본 P4/follow-up-1/follow-up-2 전체 patch 재포함
- persistence atomicity, lifecycle, corruption behavior 재설계 또는 test 약화
- P3 DTO 의미를 schema 편의 때문에 변경
- scanner/P5, P6 탭, shortage·통계 구현
- 실제 사용자 storage 접근
- repository wildcard success 허용 또는 raw state map 유지
- fake process만으로 real E2E 대체
- test skip, conditional pass, 미실행 검증을 PASS로 보고
- input/prompt/output/artifacts, 이전 patch와 build/cache/local 파일 포함
- 관련 없는 formatting, UI 재설계나 대규모 리팩터링

## 필수 검증

```powershell
cd backend
py -3.11 -m unittest tests.test_repository_parity tests.test_repository_persistence tests.test_repository_protocol_contract -v
py -3.11 -m unittest discover -s tests -v

cd ..\frontend
flutter analyze
flutter test
flutter build windows --release

cd ..
codealmanac validate
git diff --check
```

추가 기록:

- baseline과 최종 Python/Flutter test 수
- fixture 총 case, valid/invalid 수
- Python schema, Python DTO와 Dart validator 판정 일치 결과
- 앞서 valid였던 metadata/shortage/goal999/junk/empty nested probe가 모두 invalid인 결과
- runtime malformed-success별 연결 종료/restart 결과
- typed state에 metadata/total/shortage가 없는 결과
- 실제 두 child process의 시작·종료, temporary root와 복원 revision
- 실제 사용자 저장소 미접근 근거
- patch header/Checking 수, skipped 0

필수 명령을 하나라도 실행할 수 없거나 실제 process E2E가 실패하면 `BLOCKED`다.

## 완료 조건

- Nested request/state schema가 Python DTO와 일치한다.
- Python schema·DTO와 Dart가 같은 fixture 판정을 낸다.
- Runtime client가 malformed repository success를 거부한다.
- UI가 typed repository state만 사용한다.
- 실제 Dart↔Python 재시작 persistence E2E가 통과한다.
- P3/P4/follow-up-1 회귀가 없다.
- 전체 Python, Flutter analyze/test, Windows release, Almanac, diff 검사가 통과한다.
- P5/P6 및 실제 사용자 데이터 범위가 추가되지 않는다.

## 증분 patch 및 인계

```text
docs/migration/p4-repository-persistence-followup-3/
├─ input.md
├─ slave-execution-prompt.md
├─ output.md
└─ artifacts/
   ├─ p4-repository-persistence-followup-3.patch
   └─ verification.txt
```

- patch는 follow-up-2 baseline 위 단일 증분이다.
- 모든 diff path는 `BA Planner/v7/...` prefix를 사용한다.
- `git apply --check --verbose`에서 모든 patch가 Checking되고 skip은 0이어야 한다.
- artifact 두 개의 크기·SHA-256을 `output.md`에 기록한다.

마스터 receiver:

```powershell
& "$HOME\.codex\ba-planner-slave\Receive-SlaveResult.ps1" `
  -TaskId "ba-planner-v7-p4-repository-persistence-followup-3"
```

슬레이브 sender:

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p4-repository-persistence-followup-3" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p4-repository-persistence-followup-3"
```

```text
TASK_OUTPUT_READY
task_id: ba-planner-v7-p4-repository-persistence-followup-3
status: COMPLETED
output_md: <슬레이브 PC의 output.md 절대경로>
artifacts_dir: <슬레이브 PC의 artifacts 절대경로>
artifact_count: 2
handoff_package: <ZIP 절대경로>
handoff_package_size: <바이트>
handoff_package_sha256: <SHA-256>
master_prompt: <-MASTER_PROMPT.md 절대경로>
wireless_transfer: `RECEIVED`, `NOT_REQUESTED` 또는 `FAILED`
```

마스터가 전체 결과를 검증하기 전에는 P4 완료로 간주하지 않는다.
