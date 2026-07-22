# P4 보완 작업 지시 2 — Repository wire contract와 실제 Dart process E2E

## 작업 정보

- 작업 ID: `ba-planner-v7-p4-repository-persistence-followup-2`
- 작업 디렉터리: `<SLAVE_REPOSITORY_ROOT>\docs\migration\p4-repository-persistence-followup-2`
- 기준 상태: 원본 P4와 follow-up-1이 적용된 작업 트리
- patch 성격: follow-up-1 위에만 적용하는 마지막 P4 contract 증분
- 실행 환경: 슬레이브와 마스터는 서로 다른 PC이며 파일시스템을 공유하지 않음

## 목표

P4 follow-up-1 이후 남은 범위만 완료한다.

1. repository method별 성공 response schema와 확장 fixture
2. Dart fixture valid/invalid 판정과 runtime malformed-success 거부
3. raw map을 Widget에 누출하지 않는 typed repository state 경계
4. 실제 Dart `ProcessAppService`와 Python child process의 저장·재시작 E2E

Profile dialog lifecycle과 corruption fail-closed는 follow-up-1에서 승인됐으므로 회귀 test만
유지하고 다시 설계하지 않는다. P5/P6 구현으로 범위를 넓히지 않는다.

## 작업 전 필수 확인

다음 파일을 UTF-8로 완전히 읽는다.

1. `AGENTS.md`, `README.md`
2. `almanac/workflows/p0-p6-workflow-status.md`의 P3·P4 절
3. `almanac/workflows/p0-p6-workflow.md`의 공통 불변식과 P4 완료 조건
4. `almanac/workflows/slave-artifact-handoff.md`
5. `almanac/workflows/cross-pc-slave-handoff.md`
6. `docs/migration/p4-repository-persistence/input.md`
7. `docs/migration/p4-repository-persistence-followup-1/input.md`
8. `docs/migration/p4-repository-persistence/repository-storage.md`
9. `contracts/README.md`
10. `contracts/repository-protocol-v1.schema.json`
11. `contracts/fixtures/repository_protocol_v1.json`
12. `backend/core/repository_dto.py`, `repository_store.py`, `repository_protocol_v1.py`
13. `backend/tests/test_repository_protocol_contract.py`, `test_repository_persistence.py`
14. `frontend/lib/services/backend_process.dart`
15. `frontend/lib/services/planning_protocol_client.dart`
16. `frontend/lib/services/repository_service.dart`
17. `frontend/lib/services/process_app_service.dart`, `mock_app_service.dart`
18. `frontend/lib/ui/pages/planning_page.dart`
19. `frontend/test/repository_protocol_contract_test.dart`
20. `frontend/test/planning_protocol_client_test.dart`
21. `frontend/test/planning_page_test.dart`, `repository_profile_panel_test.dart`
22. planning protocol의 method별 schema와 Python/Dart contract test 구조

`py -3.11`, `flutter`, `dart`와 `codealmanac`을 실제로 실행할 수 있는지 먼저 확인한다.
하나라도 없어 필수 검증을 실행할 수 없으면 구현 일부만 만들고 `COMPLETED`로 보고하지
말고 `BLOCKED`로 반환한다.

## 승인 baseline gate

변경 전에 다음을 재현하고 `verification.txt`에 기록한다.

- P3 repository parity: fixture version 1, 26 cases, 10 tests
- P4+follow-up-1 집중 Python: 22 tests
- 전체 Python: 39 tests
- 전체 Flutter: 41 tests
- `flutter analyze`, Windows release, `codealmanac validate`, `git diff --check`: 통과
- profile create/select/rename/cancel/빈 입력 lifecycle test: 통과
- malformed catalog와 malformed idempotency: 구조화된 `corrupt_data`
- 현재 repository fixture: version 1, 기존 16 cases 이상 유지
- 현재 알려진 결함 재현: profile-list success의 `{ "nonsense": true }`가 schema에서
  유효하고, Dart test가 fixture의 `valid`를 판정하지 않으며 repository runtime success가
  무조건 허용됨

baseline이 없거나 원본 P4/follow-up-1 외의 변경과 겹쳐 안전한 증분을 만들 수 없으면
`BLOCKED`로 반환한다. 승인된 lifecycle/corruption 코드를 되돌리거나 test를 약화하지 않는다.

## 필수 구현

### 1. Method별 성공 response JSON Schema

`contracts/repository-protocol-v1.schema.json`에서 request와 error뿐 아니라 성공 response를
method별 payload와 상관시킨다. 모든 object는 확장을 명시적으로 허용한 경우가 아니면
`additionalProperties: false`를 사용한다.

최소 성공 payload 계약:

- `repository.profile.list`
  - `profiles`: profile summary array
  - `selected_profile_id`: canonical profile ID 또는 null
- `repository.profile.create`
  - `profile`: profile summary
  - `revision`: bool이 아닌 0 이상의 integer
- `repository.profile.current`
  - `profile`: selected profile summary 또는 null
- `repository.profile.select`, `repository.profile.rename`,
  `repository.students.update`, `repository.inventory.update`, `repository.goals.save`
  - exact `{ "revision": non-negative integer }`
- `repository.state.get`
  - canonical `profile_id`, revision, `students`, `inventory`, `goals`
- 모든 repository method의 구조화 error

공통 definition을 재사용하되 다음을 구체적으로 검증한다.

- canonical 24자 lowercase hex profile ID
- non-empty display name, bool이 아닌 revision, selected bool
- confirmed student DTO의 version/student_id/values/provenance 경계
- inventory snapshot version/entries와 canonical entry shape
- goal plan version/goals 및 기존 planning goal의 field/type/null 의미
- method와 success payload의 정확한 상관관계

다음은 반드시 invalid여야 한다.

- 모든 method에서 `{ "nonsense": true }`
- profile-list payload를 state-get method에 사용하거나 그 반대
- missing/unknown success field
- bool/negative revision
- malformed nested student/inventory/goal
- error와 success field 혼합

Python contract test는 fixture의 모든 case를 Draft 2020-12 validator로 검증하고 method별
정상 response가 실제 `RepositoryProtocolV1` 결과와 의미가 일치하는 사례도 포함한다.

### 2. 공용 fixture 확장

기존 version 1과 16 cases를 삭제하거나 의미를 약화하지 않는다. 최소 다음을 추가한다.

- 각 repository method의 정상 success response
- 각 success response의 missing/unknown/type 오류
- method/payload mismatch
- `nonsense` payload
- malformed nested state
- 허용 error와 잘못된 error code/retryable/details

모든 case ID는 고유하며 `valid` expected boolean을 가진다. 최종 case 수와 operation/method별
분포를 `verification.txt`에 기록한다.

### 3. Dart contract validator

Dart 쪽은 Draft 2020-12 전체 validator dependency를 새로 도입하지 않아도 된다. 대신 기존
planning contract test처럼 repository fixture를 소비하는 명시적 wire-shape validator를
작성한다.

- 모든 fixture case의 계산된 validity를 `case['valid']`와 비교한다.
- envelope, request payload, method별 success payload, error shape와 nested state를 검사한다.
- invalid case가 하나라도 허용되거나 valid case가 거부되면 test가 실패한다.
- fixture를 단순히 순회하며 key와 method prefix만 확인하는 test는 허용하지 않는다.

Python schema validator와 Dart structure validator가 같은 fixture 전부를 소비해야 한다.

### 4. Runtime client의 method별 success 검증

`PlanningProtocolClient._validSuccessPayload()`의 `repository.* => true`를 제거한다.

- 각 repository method의 top-level success payload를 method별로 검증한다.
- error payload는 기존 error 경계에서만 처리한다.
- malformed success는 해당 request만 값으로 반환하지 않고 protocol failure로 처리하며
  pending request/connection 정책은 기존 P1 계약과 일관돼야 한다.
- profile list/create/current/revision/state의 malformed, missing, unknown field test를 추가한다.
- `retryable`을 포함한 repository error shape와 허용 code 정책을 유지한다.

top-level 검증과 typed deserialization의 책임을 명확히 나눈다. 같은 payload를 서로 다른
규칙으로 중복 구현해 drift시키지 않는다.

### 5. Typed repository state boundary

`RepositoryService.loadRepositoryState()`가 raw `Map<String, dynamic>`을 반환하지 않게 한다.
책임이 드러나는 immutable typed model을 정의한다. 최소 필드는 다음과 같다.

- profile ID
- revision
- confirmed students
- inventory snapshot
- goal plan

wire factory에서 exact keys, version, type과 nested shape를 검증한다. Widget과
`PlanningPage`는 typed state의 property를 사용하며 raw map cast를 하지 않는다.

- `ProcessAppService`는 wire response를 typed model로 변환한다.
- `MockAppService`도 같은 typed return과 revision 의미를 구현한다.
- static metadata, total need와 shortage를 state model에 추가하지 않는다.
- 향후 P5 candidate/confidence를 current state에 섞지 않는다.

### 6. 실제 Dart ↔ Python process persistence E2E

Flutter test에서 실제 Python child process를 `ProcessAppService`로 실행해 다음 흐름을
검증한다.

1. temporary storage root 생성
2. profile create/list/current
3. profile rename/select와 revision 증가
4. students/inventory/goals 저장 또는 현재 public service 범위에 맞는 state/goal 저장
5. service dispose로 첫 child process 종료
6. 같은 temporary storage root로 새 process/service 시작
7. typed state에서 profile ID, revision, students/inventory/goals 복원 확인
8. test 종료 후 process와 temporary directory 정리

현재 `BackendProcessConfig`가 environment override를 지원하지 않으므로 필요한 최소 변경으로
명시적인 environment map을 추가할 수 있다. production 기본값은 기존과 동일해야 하며,
test에서만 `BA_PLANNER_STORAGE_ROOT=<temporary directory>`를 전달한다. 부모 환경을 제거하거나
실제 사용자 저장소를 사용하지 않는다.

실제 process E2E는 fake process test로 대체할 수 없다. 별도로 fake response test를 사용해
malformed-success rejection을 검증하는 것은 허용한다. Windows에서 `py -3.11` launcher와
backend working directory를 실제 사용하며 timeout과 stderr를 실패 진단에 포함한다.

### 7. 문서 정합성

- `contracts/README.md`: method별 response, strict success, typed Dart boundary 갱신
- `repository-storage.md`: typed state와 test storage override 경계 갱신
- fixture case 수와 real process E2E 재현 명령 기록

슬레이브는 `almanac/workflows/p0-p6-workflow-status.md`를 `완료`로 변경하지 않는다.

## 예상 변경 범위

- `contracts/repository-protocol-v1.schema.json`
- `contracts/fixtures/repository_protocol_v1.json`
- `contracts/README.md`
- `backend/tests/test_repository_protocol_contract.py`
- 필요 시 `backend/core/repository_protocol_v1.py`
- `frontend/lib/services/backend_process.dart`
- `frontend/lib/services/planning_protocol_client.dart`
- `frontend/lib/services/repository_service.dart`
- `frontend/lib/services/process_app_service.dart`
- `frontend/lib/services/mock_app_service.dart`
- `frontend/lib/ui/pages/planning_page.dart`
- `frontend/test/repository_protocol_contract_test.dart`
- `frontend/test/planning_protocol_client_test.dart` 또는 별도 repository process E2E test
- typed state 관련 Widget/service tests
- `docs/migration/p4-repository-persistence/repository-storage.md`

다른 파일이 필요하면 `output.md`에 이유를 기록한다.

## 금지 및 제외 범위

- 원본 P4나 follow-up-1 전체 patch 재포함
- 승인된 profile lifecycle/corruption behavior 변경 또는 test 약화
- P3 DTO/merge/fixture 의미 변경
- scanner/P5, 전 탭/P6, shortage·통계 구현
- v6 자동 import 또는 실제 사용자 profile/DB 접근
- repository success payload 무조건 허용
- raw repository state map을 Widget에 유지
- fake process만으로 real process E2E를 대체
- test skip, conditional pass, 실행하지 않은 검증을 PASS로 보고
- input/prompt/output/artifacts, 이전 patch, build/cache/local 파일을 patch에 포함
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

추가로 다음 실제 결과를 기록한다.

- 변경 전 baseline test 수
- 변경 후 Python/Flutter test 수
- repository fixture 총 case 수와 valid/invalid 수
- Python과 Dart가 모든 fixture expected validity와 일치한 결과
- 모든 method의 nonsense/mismatch payload 거부 결과
- runtime malformed-success가 protocol failure가 된 결과
- typed state에 metadata/total/shortage field가 없는 결과
- real child process 두 회차의 PID/종료, temporary root와 복원 revision
- 실제 사용자 저장소 미접근 확인
- patch path 수, `Checking` 수와 `Skipped patch: 0`

하나라도 실패하거나 실행할 수 없으면 `COMPLETED`가 아니라 `BLOCKED`다.

## 완료 조건

- method별 success schema와 fixture가 arbitrary/mismatched payload를 거부한다.
- Python과 Dart가 같은 모든 fixture의 `valid` 기대값을 만족한다.
- runtime client가 malformed repository success를 거부한다.
- repository state가 typed model로만 UI에 전달된다.
- 실제 Dart `ProcessAppService` ↔ Python process 재시작 복원 E2E가 통과한다.
- follow-up-1 lifecycle/corruption와 P3 parity가 회귀하지 않는다.
- 전체 Python, Flutter analyze/test, Windows release, Almanac와 diff 검사가 통과한다.
- P5/P6와 실제 사용자 데이터 범위가 추가되지 않는다.

## 증분 patch 및 인계 계약

```text
docs/migration/p4-repository-persistence-followup-2/
├─ input.md
├─ slave-execution-prompt.md
├─ output.md
└─ artifacts/
   ├─ p4-repository-persistence-followup-2.patch
   └─ verification.txt
```

- patch는 원본 P4+follow-up-1 baseline 위의 단일 증분이다.
- 모든 diff path는 Git root 기준 `BA Planner/v7/...` prefix를 사용한다.
- `git apply --check --verbose`의 모든 patch가 `Checking`되고 skip은 0이어야 한다.
- 결과 artifact 두 개의 실제 크기와 SHA-256을 `output.md`에 기록한다.
- `output.md`는 Slave Artifact Handoff 계약을 따른다.

## cross-PC 전달

마스터 receiver:

```powershell
& "$HOME\.codex\ba-planner-slave\Receive-SlaveResult.ps1" `
  -TaskId "ba-planner-v7-p4-repository-persistence-followup-2"
```

슬레이브 sender:

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p4-repository-persistence-followup-2" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p4-repository-persistence-followup-2"
```

```text
TASK_OUTPUT_READY
task_id: ba-planner-v7-p4-repository-persistence-followup-2
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

마스터가 package, artifact, patch와 전체 검증을 직접 확인하기 전에는 P4 완료로 간주하지
않는다.
