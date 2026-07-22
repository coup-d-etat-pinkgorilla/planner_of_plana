# P4 보완 작업 지시 4 — 실제 cross-language 재시작 E2E와 완료 gate

## 작업 정보

- 작업 ID: `ba-planner-v7-p4-repository-persistence-followup-4`
- 작업 디렉터리: `<SLAVE_REPOSITORY_ROOT>\docs\migration\p4-repository-persistence-followup-4`
- 기준 상태: 원본 P4와 follow-up-1·2·3 증분이 모두 적용된 작업 트리
- patch 성격: follow-up-3 위의 최소 P4 완료 증분
- 실행 환경: 슬레이브와 마스터는 서로 다른 PC이며 파일시스템을 공유하지 않음

## 목표

follow-up-3에서 남은 다음 세 항목만 해결한다.

1. `repository_service.dart`의 `flutter analyze` lint 2건을 수정한다.
2. 실제 Dart `ProcessAppService`가 실제 Python backend child process를 두 번 실행해 같은
   temporary storage root에서 repository 상태를 복원하는 E2E를 추가한다.
3. nested strict contract, immutable typed state와 실제 process E2E를 계약·저장 문서에
   현재 코드와 일치하게 기록한다.

follow-up-3에서 이미 구현·검증된 nested schema, 40-case fixture, Dart validator,
malformed-success fatal policy와 typed repository state는 다시 설계하지 않는다.

## 작업 전 필수 확인

다음을 UTF-8로 처음부터 끝까지 읽는다.

1. `AGENTS.md`, `README.md`
2. `almanac/workflows/p0-p6-workflow-status.md`의 P3·P4 절
3. `almanac/workflows/p0-p6-workflow.md`의 공통 불변식과 P4 완료 조건
4. `almanac/workflows/slave-artifact-handoff.md`
5. `almanac/workflows/cross-pc-slave-handoff.md`
6. P4 원본과 follow-up-1·2·3의 `input.md`
7. follow-up-3 `output.md`와 `verification.txt`가 있으면 그 차단 사유
8. `frontend/lib/services/backend_process.dart`
9. `frontend/lib/services/planning_protocol_client.dart`
10. `frontend/lib/services/process_app_service.dart`
11. `frontend/lib/services/repository_service.dart`
12. `frontend/test/planning_protocol_client_test.dart`
13. 기존 실제 planning Python-process Flutter E2E test
14. `backend/core/backend_process.py`, `repository_protocol_v1.py`, `repository_store.py`
15. `contracts/README.md`
16. `docs/migration/p4-repository-persistence/repository-storage.md`

`py -3.11`, `flutter`, `dart`, `codealmanac`을 먼저 확인한다. 실제 child process를 실행할
수 없으면 fake test로 대체하지 말고 `BLOCKED`로 보고한다.

## 승인 baseline gate

변경 전에 다음 상태를 재현한다.

- repository fixture version 1, 40 cases: valid 14, invalid 26
- P3 parity 10 tests
- P4 집중 Python 23 tests, 전체 Python 40 tests
- Flutter 전체 42 tests
- Windows release, `codealmanac validate`, `git diff --check` 통과
- `flutter analyze`만 다음 2건으로 실패
  - `frontend/lib/services/repository_service.dart:82:68`
  - `frontend/lib/services/repository_service.dart:181:67`
  - rule: `curly_braces_in_flow_control_structures`
- Dart fixture test가 40 case의 `valid`를 실제 비교함
- malformed repository success가 fatal disconnect되고 fake process restart가 가능함
- `RepositoryService.loadRepositoryState()`가 `RepositoryState`를 반환하고 PlanningPage가
  raw state index/cast 대신 typed property를 사용함
- Python 단독 child-process restart persistence test는 있으나 실제 Dart
  `ProcessAppService` ↔ Python restart E2E는 없음

baseline이 다르면 누락된 선행 patch를 임의 재구성하지 않는다. 실제 commit/diff와 차이를
`output.md`에 적고 이 작업을 안전하게 계속할 수 없으면 `BLOCKED`로 보고한다.

## 필수 구현

### 1. Analyze lint 수정

`repository_service.dart`의 두 단일행 `if`에 Dart 스타일에 맞는 block을 사용한다. 동작,
허용 field, range, nullable 의미와 fatal protocol 정책은 바꾸지 않는다. 관련 없는 파일을
formatting하지 않는다.

### 2. Test-only process environment 주입

실제 E2E가 사용자 저장소를 건드리지 않도록 `BackendProcessConfig`에 immutable optional
environment override를 추가할 수 있다.

- production 기본값은 기존과 동일해야 한다.
- `Process.start()`에 전달할 때 부모 environment를 배제하지 않는다.
- test에서만 `BA_PLANNER_STORAGE_ROOT=<TemporaryDirectory>`를 지정한다.
- environment map은 외부 변경에 영향받지 않도록 방어적 복사 또는 immutable view로 둔다.
- backend working directory와 Python 실행 방식은 기존 `BackendProcessConfig.resolve()`를
  재사용한다.
- Windows에서는 기본 `py -3.11`; 명시 interpreter가 있으면 기존 resolve 규칙을 따른다.
- 실제 사용자 `profiles/`, DB, home storage 경로는 열거나 쓰지 않는다.

필요 최소 범위에서만 launcher/config를 바꾼다. production storage-root 기본 정책이나 Python
repository 구현은 이 테스트를 위해 변경하지 않는다.

### 3. 실제 Dart `ProcessAppService` ↔ Python restart E2E

Flutter test에서 `FakeBackendProcess`가 아닌 실제 `Process.start()` 경로를 사용한다. public
`ProcessAppService`/`RepositoryService` API로 다음 흐름을 자동화한다.

1. `Directory.systemTemp.createTemp()`로 고유 storage root를 만든다.
2. 실제 backend directory와 Python launcher를 resolve한다.
3. 첫 `ProcessAppService`를 시작한다.
4. profile create, list/current 확인, rename/select를 수행한다.
5. canonical goal plan을 저장하고 반환 revision을 확인한다.
6. typed `RepositoryState`로 profile ID, revision과 goal 값을 확인한다.
7. 첫 service를 dispose하고 첫 child process가 종료됐음을 timeout 안에 확인한다.
8. 같은 `BA_PLANNER_STORAGE_ROOT`로 새 `ProcessAppService`와 새 Python child process를
   시작한다.
9. 동일 profile ID, display name, revision과 typed goal state가 복원됐는지 확인한다.
10. 두 번째 service/process를 종료하고 temporary directory를 `finally`에서 정리한다.

현재 public service가 students/inventory mutation을 제공하지 않으면 test만을 위해 private
client에 접근하거나 새 production API를 만들지 않는다. profile과 goal의 실제 persistence,
typed state, 두 개의 독립 child process로 cross-language restart 경계를 증명한다. 기존
Python persistence suite가 current/inventory 저장과 재시작을 계속 담당함을 문서에 명시한다.

E2E test 요구사항:

- fake handle, mocked stdio 또는 Python 단독 subprocess test로 대체하지 않음
- 두 child process가 서로 다른 실제 OS process임을 start count/PID 또는 동등한 관측으로
  검증
- 각 async 단계에 유한 timeout 적용
- 실패 시 backend stderr와 exit code를 진단에 포함
- test skip, 플랫폼 조건부 pass, 실패 catch 후 성공 처리 금지
- temporary root의 절대경로와 cleanup 결과를 검증 로그에 기록하되 비밀값은 기록하지 않음
- 실제 사용자 storage root 미접근 근거를 기록

기존 dispose API로 종료 여부를 관측할 수 없다면 test 가능한 최소 read-only lifecycle
관측을 추가한다. public UI/API를 불필요하게 확장하지 않는다.

### 4. 문서 정합성

`contracts/README.md`의 repository protocol v1 절에 다음을 기록한다.

- nested confirmed/inventory/goal exact-key, type, nullable/range 검증
- 공용 fixture 40 cases(valid 14, invalid 26)를 Python schema·DTO와 Dart가 함께 판정
- repository success의 method별 runtime 검증과 malformed-success fatal policy
- `RepositoryState` typed boundary

`docs/migration/p4-repository-persistence/repository-storage.md`에 다음을 기록한다.

- Flutter가 파일 경로/JSON을 직접 읽지 않고 typed service 경계를 사용함
- test-only environment injection과 production 기본값 불변
- 실제 두 Dart-launched Python child process가 같은 temporary root를 사용한 restart E2E
- profile/goal cross-language 복원과 Python suite의 current/inventory persistence 책임
- 사용자 storage 미접근 및 temporary cleanup 정책

case 수, test 수와 명령은 최종 실제 결과를 사용한다. 실행하지 않은 검증을 통과로 쓰지
않는다. 슬레이브는 workflow status를 `완료`로 변경하지 않는다.

## 예상 변경 범위

- `frontend/lib/services/repository_service.dart`
- `frontend/lib/services/backend_process.dart`
- 실제 process E2E를 담는 `frontend/test/..._test.dart` 1개
- `contracts/README.md`
- `docs/migration/p4-repository-persistence/repository-storage.md`

다른 production 파일이 필요하면 이유와 최소성을 `output.md`에 기록한다.

## 금지 및 제외 범위

- follow-up-3 전체 patch 재포함
- schema, fixture, Python DTO, persistence core 또는 typed state의 재설계
- fixture case 삭제, `valid` 기대값 약화 또는 validator 우회
- fake process만으로 real E2E 대체
- 실제 사용자 storage 접근
- scanner/P5, P6 탭, shortage·통계 구현
- Flutter에서 repository JSON/DB/path 직접 접근
- `../v6` runtime import 또는 v6 원본 수정
- test skip, 조건부 성공, lint ignore 또는 analyzer rule 비활성화
- input/prompt/output/artifacts, 이전 patch, build/cache/local 파일을 patch에 포함
- 관련 없는 formatting, UI 변경이나 대규모 리팩터링

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

추가로 실제 E2E test만 단독 실행해 다음을 기록한다.

- test 파일과 정확한 test 이름
- 첫/두 번째 실제 child process 시작과 종료 증거
- temporary root 및 cleanup 성공
- 저장 전후 profile ID, revision과 goal 의미 일치
- 실제 사용자 storage 미접근
- fixture 40 cases(valid 14/invalid 26) 유지
- Python schema·DTO/Dart fixture validator 유지
- patch header/Checking 수와 skipped 0

## 완료 조건

- `flutter analyze`가 lint ignore 없이 통과한다.
- 실제 Dart `ProcessAppService`가 실제 Python child process 두 개를 순차 실행한다.
- 같은 temporary root에서 profile/goal과 revision이 typed state로 복원된다.
- 두 process 종료와 temporary cleanup이 자동 test로 검증된다.
- production launcher/storage 기본 동작이 바뀌지 않는다.
- nested contract·typed state·E2E 문서가 구현과 일치한다.
- P3/P4/follow-up-1·2·3 회귀가 없다.
- 전체 Python, Flutter test/analyze/release, Almanac와 diff 검사가 모두 통과한다.
- P5/P6 또는 실제 사용자 데이터 범위가 추가되지 않는다.

필수 명령 하나라도 실패하거나 real E2E가 없으면 `COMPLETED`로 보고하지 않는다.

## 결과물 및 인계 계약

```text
docs/migration/p4-repository-persistence-followup-4/
├─ input.md
├─ slave-execution-prompt.md
├─ output.md
└─ artifacts/
   ├─ p4-repository-persistence-followup-4.patch
   └─ verification.txt
```

- patch는 follow-up-3 적용 baseline 위 단일 증분이어야 한다.
- 모든 diff path는 `BA Planner/v7/...` prefix를 사용한다.
- `input.md`, `slave-execution-prompt.md`, `output.md`, `artifacts/`와 이전 단계 patch는
  patch에 포함하지 않는다.
- `git apply --check --verbose`에서 모든 path가 Checking되고 skipped 0이어야 한다.
- artifact 2개의 존재, 0보다 큰 크기, byte 크기와 SHA-256을 확인한다.
- `output.md`는 `almanac/workflows/slave-artifact-handoff.md` 계약을 따르고 모든 명령의
  exit code, test 수와 real E2E 증거를 기록한다.

마스터 receiver:

```powershell
& "$HOME\.codex\ba-planner-slave\Receive-SlaveResult.ps1" `
  -TaskId "ba-planner-v7-p4-repository-persistence-followup-4"
```

슬레이브 sender:

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p4-repository-persistence-followup-4" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p4-repository-persistence-followup-4"
```

마스터가 ZIP, 내부 artifact, patch와 전체 완료 조건을 직접 검증하기 전에는 P4를 완료로
간주하지 않는다.
