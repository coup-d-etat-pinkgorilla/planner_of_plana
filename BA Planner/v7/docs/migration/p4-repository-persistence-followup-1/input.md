# P4 보완 작업 지시 1 — Profile UI lifecycle과 repository fail-closed 계약

## 작업 정보

- 작업 ID: `ba-planner-v7-p4-repository-persistence-followup-1`
- 작업 디렉터리: `<SLAVE_REPOSITORY_ROOT>\docs\migration\p4-repository-persistence-followup-1`
- 기준 상태: 원본 P4 `ba-planner-v7-p4-repository-persistence` patch가 적용된 작업 트리
- patch 성격: 원본 P4 위에만 적용하는 보완 증분
- 실행 환경: 슬레이브와 마스터는 서로 다른 PC이며 파일시스템을 공유하지 않음

## 목표

마스터가 원본 P4 인계물을 적용해 독립 검증하면서 발견한 profile dialog lifecycle 오류,
손상 repository 데이터의 raw 예외 누출, 비엄격한 repository 성공 response 계약과 Dart
fixture 검증을 수정한다. 모든 결함을 regression test로 고정하고 Python·Flutter·Windows
release 전체 검증을 실제로 통과시킨다.

P4 구현 전체를 재작성하거나 다시 인계하지 않는다. scanner/P5와 전 탭 통합/P6으로
범위를 확장하지 않는다.

## 작업 전 필수 확인

다음 파일을 UTF-8로 완전히 읽는다.

1. `AGENTS.md`
2. `README.md`
3. `almanac/workflows/p0-p6-workflow-status.md`의 P3 baseline과 P4 절
4. `almanac/workflows/p0-p6-workflow.md`의 공통 불변식과 P4 완료 조건
5. `almanac/workflows/slave-artifact-handoff.md`
6. `almanac/workflows/cross-pc-slave-handoff.md`
7. `docs/migration/p4-repository-persistence/input.md`
8. `docs/migration/p4-repository-persistence/repository-storage.md`
9. `backend/core/repository_store.py`
10. `backend/core/repository_protocol_v1.py`
11. `backend/core/application_protocol_v1.py`
12. `backend/tests/test_repository_persistence.py`
13. `backend/tests/test_repository_protocol_contract.py`
14. `contracts/repository-protocol-v1.schema.json`
15. `contracts/fixtures/repository_protocol_v1.json`
16. `frontend/lib/services/planning_protocol_client.dart`
17. `frontend/lib/services/repository_service.dart`
18. `frontend/lib/services/process_app_service.dart`
19. `frontend/lib/services/mock_app_service.dart`
20. `frontend/lib/ui/widgets/repository_profile_panel.dart`
21. `frontend/lib/ui/pages/planning_page.dart`
22. `frontend/test/repository_profile_panel_test.dart`
23. `frontend/test/repository_protocol_contract_test.dart`
24. 기존 planning protocol의 Python/Dart contract 및 process E2E tests

`flutter`, `py -3.11`과 `codealmanac` 실행 가능 여부를 먼저 확인한다. 이번 follow-up은
Flutter test에서 발견된 실제 오류를 고치는 작업이므로 `flutter analyze`, `flutter test`,
Windows release build를 실행할 수 없는 환경에서는 `COMPLETED`로 보고하지 않는다.

## 승인 baseline gate

변경 전에 다음을 확인하고 `verification.txt`에 기록한다.

1. 원본 P4의 21개 source 변경이 모두 존재한다.
2. P3 repository fixture version 1, 26 cases와 parity 10 tests가 유지된다.
3. 원본 P4 기준 전체 Python 37 tests가 통과한다.
4. `flutter analyze`는 통과한다.
5. `frontend/test/repository_profile_panel_test.dart`는 마스터와 같은
   `TextEditingController was used after being disposed` 오류를 재현하거나, 코드상 같은
   조기 dispose 경로가 존재함을 파일·line 근거로 확인한다.
6. follow-up 작업 전 tree와 원본 P4 baseline의 차이를 기록한다.

P3 의미나 원본 P4 unrelated 코드를 변경해 gate를 맞추지 않는다. baseline 자체가 없거나
다른 단계 변경과 겹쳐 안전한 증분 patch를 만들 수 없으면 `BLOCKED`로 반환한다.

## 마스터가 재현한 결함

### 결함 1 — Profile dialog controller lifecycle

`RepositoryProfilePanel._ask()`는 `showDialog()` future가 완료된 직후 local
`TextEditingController`를 dispose한다. dialog route의 마지막 rebuild/unmount보다 dispose가
앞서면서 `TextField`가 disposed controller를 다시 사용한다.

마스터 결과:

```text
flutter test
41 tests 중 40 통과, 1 실패
A TextEditingController was used after being disposed.
repository_profile_panel.dart의 profile-name-input
```

### 결함 2 — 손상 catalog raw `KeyError`

catalog 최상위 field와 `profiles`가 list인지까지만 검사하고 각 entry를 검증하지 않는다.
`profiles: [{}]`를 `list_profiles()`가 읽으면 구조화된 `RepositoryError("corrupt_data")`
대신 raw `KeyError('profile_id')`가 발생한다.

### 결함 3 — 손상 idempotency raw `AttributeError`

profile의 `idempotency`가 object인지와 내부 record shape를 검증하지 않는다. 이를 list로
손상시키고 rename/update mutation을 호출하면 `.get()`에서 raw `AttributeError`가
application protocol 밖으로 누출된다.

### 결함 4 — 성공 response schema가 임의 payload 허용

현재 schema의 success response는 `error` key가 없다는 조건만 확인한다. 다음 payload가
`repository.profile.list`, `repository.state.get`, `repository.goals.save` 모두에서 유효로
판정된다.

```json
{"nonsense": true}
```

### 결함 5 — Dart contract test가 fixture 판정을 검증하지 않음

현재 Dart test는 envelope key와 `repository.` 접두사만 확인하며 각 fixture case의
`valid` 값을 사용하지 않는다. invalid case가 허용되거나 success payload가 깨져도 test가
통과한다. `PlanningProtocolClient._validSuccessPayload()`도 모든 `repository.*` success를
조건 없이 허용한다.

## 필수 구현

### 1. Dialog lifecycle 수정과 Widget regression

- dialog가 완전히 제거되기 전에 사용 중인 controller를 dispose하지 않는다.
- controller를 없애고 local draft/onChanged를 쓰거나, dialog lifecycle을 소유하는 별도
  StatefulWidget에서 생성·dispose하는 등 Flutter lifecycle에 맞는 구조를 사용한다.
- post-frame delay와 임의 timer로 오류를 숨기지 않는다.
- create와 rename 모두 같은 안전한 입력 경계를 사용한다.
- 취소, 빈 이름과 확인 동작을 유지한다.

Widget test는 최소 다음을 검증한다.

1. 초기 `Main` profile 표시
2. create dialog 입력·확인 후 예외 없이 새 `Second` profile이 실제 목록에 존재
3. profile 선택과 rename dialog 입력·확인 후 이름과 revision 갱신
4. dialog 취소 및 빈 입력이 mutation을 만들지 않음
5. test 종료 시 controller/overlay/dispose 관련 framework exception 없음

기존처럼 create 후에도 `Main`만 보인다는 약한 assertion으로 완료 처리하지 않는다.

### 2. Catalog와 profile의 strict corruption validation

repository read boundary에서 저장 format 전체를 검증한다.

Catalog 최소 검증:

- exact top-level fields와 version
- `selected_profile_id`는 null 또는 canonical 24자 lowercase hex profile ID
- 각 profile summary는 exact `profile_id`, `display_name`, `revision`
- display name은 비어 있지 않은 문자열
- revision은 bool이 아닌 0 이상의 정수
- profile ID와 case-folded display name의 중복 거부
- selected ID가 실제 catalog entry를 가리킴

Profile 최소 검증:

- exact top-level fields와 canonical profile ID 일치
- revision은 bool이 아닌 0 이상의 정수
- students는 list이며 각 entry가 `ConfirmedStudent`로 검증됨
- inventory는 `InventorySnapshot`으로 검증됨
- goals는 exact version 1 plan이며 각 goal이 `StudentGoalRecord`로 검증됨
- idempotency는 object이며 각 key와 fingerprint/response record shape 및 revision type이
  canonical함

손상 저장 데이터는 `RepositoryError(code="corrupt_data")` 또는 unknown store version의
`migration_required`로 fail-closed한다. `KeyError`, `AttributeError`, `TypeError` 또는
traceback/no-response가 stdio/application boundary 밖으로 누출되지 않아야 한다. 예외를
무차별 broad catch로 숨기지 말고 read validation에서 구체적으로 분류한다.

다음 regression을 Python test와 실제 application protocol response에서 검증한다.

- `profiles: [{}]`
- 잘못된 summary field type, duplicate ID/name, dangling selected ID
- bool/negative revision
- profile `idempotency: []`
- malformed idempotency record/fingerprint/response
- students/inventory/goals의 잘못된 container와 partial field
- 모든 경우 기존 정상 bytes를 쓰거나 변경하지 않음

### 3. Method별 repository response schema

`contracts/repository-protocol-v1.schema.json`에서 각 method의 성공 payload를 구체적으로
검증한다. 최소 다음 response shape를 분리한다.

- profile list
- profile create
- current profile(null 포함)
- select/rename/students/inventory/goals mutation revision
- state get의 profile/current/inventory/goals
- migration error
- 공통 구조화 error

profile ID, display name, revision, selected flag, confirmed students, inventory snapshot과 goal
plan의 필수 field/type/version을 검사하고 오타를 `additionalProperties: false`로 거부한다.
method와 success payload가 서로 바뀌어도 유효하면 안 된다. `{ "nonsense": true }`는 모든
repository success method에서 invalid여야 한다.

fixture에는 각 정상 success response, method/payload mismatch, unknown success field,
missing field, bool revision과 malformed nested state를 추가한다. 기존 16 cases를 삭제하거나
의미를 약화하지 않는다.

### 4. Dart contract와 runtime client 검증

- Dart contract test가 각 fixture의 `valid` 기대값을 실제 validator 결과와 비교한다.
- Dart에 Draft 2020-12 전체 validator를 새로 넣지 않는다면 planning contract test처럼
  repository wire shape를 검증하는 작은 명시적 validator를 작성한다.
- invalid fixture가 하나라도 허용되면 test가 실패해야 한다.
- `PlanningProtocolClient._validSuccessPayload()`의 repository 무조건 `true`를 제거하고
  method별 top-level success shape를 검사한다.
- `ProcessAppService`가 profile/state payload를 typed boundary에서 검증한다. raw
  `Map<String, dynamic>`을 Widget이 직접 cast하도록 누출하지 않는다.
- malformed success response가 client 연결을 protocol failure로 처리하는 test를 추가한다.

### 5. Real backend와 Mock flow 검증

- 실제 Python child process와 Dart `ProcessAppService` 사이에서 profile create/list/select,
  state load, goal save와 process restart 복원을 검증한다.
- 저장 root는 반드시 temporary directory와 `BA_PLANNER_STORAGE_ROOT` override를 사용한다.
- MockAppService profile create/select/rename 및 planning restore/save Widget flow를 검증한다.
- 실제 사용자 profile/DB와 홈 디렉터리를 사용하지 않는다.

## 허용 변경 범위

예상 변경은 다음에 집중한다.

- `frontend/lib/ui/widgets/repository_profile_panel.dart`
- `frontend/test/repository_profile_panel_test.dart`
- `backend/core/repository_store.py`
- `backend/tests/test_repository_persistence.py`
- `contracts/repository-protocol-v1.schema.json`
- `contracts/fixtures/repository_protocol_v1.json`
- `backend/tests/test_repository_protocol_contract.py`
- `frontend/test/repository_protocol_contract_test.dart`
- `frontend/lib/services/planning_protocol_client.dart`
- `frontend/lib/services/repository_service.dart`
- `frontend/lib/services/process_app_service.dart`
- 관련 process/client/widget test
- 계약·저장 정책 변경을 반영하는 `contracts/README.md`, `repository-storage.md`

다른 파일이 필요하면 `output.md`에 이유를 명시한다.

## 금지 및 제외 범위

- 원본 P4 전체 patch 재포함
- P3 DTO/merge/fixture 의미 변경
- scanner/session/event/candidate commit 또는 P5 구현
- P6 전체 탭, inventory 관리 화면, shortage·통계 구현
- v6 자동 탐색/import 또는 실제 사용자 데이터 변경
- test 삭제, skip, 기대값 약화, 오류를 timer/retry로 숨김
- repository success를 무조건 허용하는 client 경계 유지
- `output.md`, `artifacts/`, input/prompt, 이전 patch, build/cache/local 파일을 patch에 포함
- `almanac/workflows/p0-p6-workflow-status.md`를 슬레이브가 `완료`로 변경
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

추가로 기록한다.

- 변경 전 baseline test 수와 controller 오류 재현 결과
- 변경 후 Python 및 Flutter 전체 test 수
- malformed catalog/idempotency가 실제 `corrupt_data` response를 반환한 결과
- 모든 repository method에서 nonsense/mismatched success payload가 거부된 결과
- Dart fixture valid/invalid case 수와 runtime malformed-response test 결과
- real child process + ProcessAppService restart persistence 결과
- Mock create/select/rename 및 planning restore/save 결과
- 실제 storage root가 temporary directory였다는 근거
- 금지된 v6/scanner/GUI runtime import 검색 결과
- follow-up patch가 원본 P4와 겹치지 않는 증분인지 확인한 결과

실행하지 못한 검증은 PASS로 쓰지 않는다. 특히 Flutter test/build 또는 CodeAlmanac을
실행할 수 없으면 `BLOCKED`로 보고한다.

## 완료 조건

다음이 모두 충족돼야 `COMPLETED`로 보고한다.

- profile create/select/rename Widget test가 lifecycle exception 없이 통과한다.
- 손상 catalog/profile/idempotency가 raw 예외 없이 구조화된 오류로 fail-closed한다.
- method별 success schema가 arbitrary/mismatched payload를 거부한다.
- Dart fixture test가 valid/invalid 기대값을 실제로 검증한다.
- runtime client가 malformed repository success를 거부한다.
- real backend 및 Mock repository/planning 흐름이 모두 통과한다.
- P3 10 tests와 원본 P4 persistence tests가 회귀 없이 유지된다.
- 전체 Python, Flutter analyze/test, Windows release, Almanac와 diff 검사가 통과한다.
- P5/P6 및 실제 사용자 데이터 범위가 추가되지 않는다.

## 증분 patch 및 인계 계약

```text
docs/migration/p4-repository-persistence-followup-1/
├─ input.md
├─ slave-execution-prompt.md
├─ output.md
└─ artifacts/
   ├─ p4-repository-persistence-followup-1.patch
   └─ verification.txt
```

- patch는 원본 P4가 적용된 baseline 위에 적용 가능한 단일 follow-up 증분이다.
- 모든 diff path는 Git root 기준 `BA Planner/v7/...` prefix를 사용한다.
- 신규 파일이 있으면 `+++ b/BA Planner/v7/...` 경로여야 한다.
- `git apply --check --verbose`에서 모든 patch가 `Checking`되고 `Skipped patch`가 0인지
  기록한다.
- 결과물은 위 artifact 두 개만 포함하고, 각각 크기와 SHA-256을 `output.md`에 기록한다.
- `output.md`는 Slave Artifact Handoff 계약을 따른다.

## cross-PC 전달

마스터에서 receiver를 먼저 실행한다.

```powershell
& "$HOME\.codex\ba-planner-slave\Receive-SlaveResult.ps1" `
  -TaskId "ba-planner-v7-p4-repository-persistence-followup-1"
```

슬레이브에서 결과 준비 후 sender를 실행한다.

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p4-repository-persistence-followup-1" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p4-repository-persistence-followup-1"
```

```text
TASK_OUTPUT_READY
task_id: ba-planner-v7-p4-repository-persistence-followup-1
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

마스터가 package, artifact, 증분 patch와 전체 검증을 직접 확인하기 전에는 P4를 완료로
간주하지 않는다.
