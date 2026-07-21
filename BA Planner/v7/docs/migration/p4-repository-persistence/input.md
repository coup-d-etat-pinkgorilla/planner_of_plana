# P4 작업 지시 — Repository와 프로필 영구 저장

## 작업 정보

- 작업 ID: `ba-planner-v7-p4-repository-persistence`
- 저장소: 슬레이브 PC의 BA Planner v7 저장소 루트
- 작업 디렉터리: `<SLAVE_REPOSITORY_ROOT>\docs\migration\p4-repository-persistence`
- 기준 단계: P0·P1·P2·P3 완료, 아래 P3 승인 baseline 위에서 P4 구현
- 실행 환경: 슬레이브와 마스터는 서로 다른 PC이며 파일시스템을 공유하지 않음

## 목표

Python backend가 프로필 catalog, 확정 학생 현재 상태, canonical inventory snapshot과 사용자
목표의 저장·복원을 소유하게 한다. 저장은 재실행 뒤 복원되고, 실패 시 기존 정상 데이터를
보존하며, Flutter는 versioned local protocol과 `AppService`만 사용한다.

P4는 P3에서 승인한 DTO와 순수 병합 parity를 실제 I/O 및 application-service 경계에
연결하는 단계다. scanner session/candidate 생성은 P5, 전 탭 실제 데이터 통합은 P6에
남긴다.

## 작업 전 필수 확인

다음 파일을 UTF-8로 처음부터 끝까지 읽는다. 문서와 코드가 다르면 현재 코드와 실행
결과를 우선하고 차이를 `output.md`에 기록한다.

1. `AGENTS.md`
2. `README.md`
3. `almanac/workflows/p0-p6-workflow-status.md`
4. `almanac/workflows/p0-p6-workflow.md`의 공통 불변식과 P3·P4 절
5. `almanac/architecture/runtime-boundaries.md`
6. `almanac/workflows/slave-artifact-handoff.md`
7. `almanac/workflows/cross-pc-slave-handoff.md`
8. `docs/migration/v6-knowledge-baseline.md`
9. `docs/migration/p3-repository-dto/repository-characterization.md`
10. `docs/migration/p3-repository-dto/repository-protocol-draft.md`
11. `contracts/README.md`
12. `backend/core/repository_dto.py`
13. `backend/core/repository_merge.py`
14. `backend/tests/test_repository_parity.py`
15. `contracts/fixtures/repository_v6_parity.json`
16. `backend/core/protocol_v1.py`, `stdio_server.py`, `backend_process.py`
17. `frontend/lib/services/app_service.dart`, `planning_protocol_client.dart`,
    `process_app_service.dart`, `mock_app_service.dart`
18. `frontend/lib/ui/pages/planning_page.dart`와 관련 test

v6 참조 저장소가 `<SLAVE_REPOSITORY_ROOT>\..\v6`에 있으면 repository, profile, DB 및
직접 호출부를 `rg`로 조사한다. 최소 확인 대상은 다음과 같다.

- `../v6/core/repository.py`, `merge.py`, `inventory_profiles.py`
- `../v6/core/db.py`, `db_writer.py`, `scanner_shared.py`
- config/profile storage path를 정하는 코드
- profile 생성·선택·이름 변경, 학생 JSON, inventory SQLite/JSON fallback과 resync 호출부
- 관련 v6 test와 `../v6/almanac/`의 repository/data-bucket 문서

v6가 없거나 일부 동작을 재현할 수 없으면 추측하지 말고 해당 항목을 `NOT_VERIFIED`로
기록한다. Qt/QML/QWidget/Tk/PySide6 코드는 복사하지 않는다.

## P3 승인 baseline — 변경 전 필수 gate

P4 구현 전에 다음 상태를 재현한다.

### 승인된 파일

- `backend/core/repository_dto.py`
- `backend/core/repository_merge.py`
- `backend/tests/test_repository_parity.py`
- `contracts/fixtures/repository_v6_parity.json`
- `docs/migration/p3-repository-dto/repository-characterization.md`
- `docs/migration/p3-repository-dto/repository-protocol-draft.md`

### 재현 조건

1. repository fixture는 version 1, 26 cases다.
2. `py -3.11 -m unittest tests.test_repository_parity -v`는 10 tests를 통과한다.
3. 전체 Python suite는 P4 변경 전 27 tests를 통과한다.
4. `CONFIRMED_STUDENT_VALUE_FIELDS`와 `StudentMeta.__annotations__`의 교집합은
   `set()`이다.
5. `display_name`은 `ConfirmedStudent.values`와 student
   `RepositoryCommitCommand.confirmed_payload`에서 `RepositoryDTOError`로 거부된다.
6. `repository_merge.STUDENT_FIELDS`는 v6 legacy parity 집합이고 v7 confirmed-current
   허용 집합과 의도적으로 다르다.
7. P3 코드는 실제 filesystem/SQLite를 열거나 사용자 저장소를 쓰지 않는다.
8. `../v6`, scanner 또는 GUI runtime import가 없다.

하나라도 맞지 않으면 P4 코드를 작성하지 않는다. 현재 tree, 명령, 기대값과 실제값을
`output.md`에 기록하고 `TASK_OUTPUT_BLOCKED`로 반환한다. 승인 없이 P3 DTO 의미, fixture
기대값 또는 병합 parity를 바꿔 gate를 통과시키지 않는다.

## 공통 불변식

다음 다섯 데이터 버킷을 저장 schema, protocol payload와 test에서 계속 분리한다.

1. 스캔 후 검토·확정된 현재 상태
2. 정적 메타데이터
3. 사용자 목표
4. 보유량 차감 전 총 계산 결과
5. 인벤토리에서 파생한 부족량

- P4가 영속화하는 원본 상태는 프로필 정보, 확정 current, inventory와 goal이다.
- 정적 metadata는 기존 `student_meta` owner를 유지하며 current record로 복제하지 않는다.
- 총 계산 결과와 부족량은 cache나 편의를 이유로 원본처럼 저장·병합하지 않는다.
- 빈 goal field의 `null`은 현재 값 유지이며 숫자 `0`으로 정규화하지 않는다.
- Flutter는 JSON, SQLite 또는 profile 경로를 직접 읽거나 쓰지 않는다.
- runtime에서 `../v6`를 import하지 않는다.

## 필수 구현

### 1. P4 저장 계약과 fixture

P4 구현 전에 `contracts/`에 repository/profile protocol v1의 method별 JSON Schema와
Python·Dart가 함께 소비하는 fixture를 만든다. 공용 envelope의 `protocol: 1`, request ID,
method correlation과 strict 오류 검사를 재사용한다. 기존 planning method와 fixture를
깨지 않는다.

최소 use case는 다음과 같다. 실제 method 이름은 일관된 `repository.*` namespace로
확정하고 schema, Python dispatcher, Dart client와 문서를 모두 같게 맞춘다.

- profile 목록, 생성, 선택, 이름 변경
- 선택 profile 및 revision 조회
- 학생 current 전체/단건 조회와 update
- inventory snapshot 조회와 update
- goal plan load와 save

모든 mutation은 비어 있지 않은 idempotency key와 expected revision을 받는다. 성공 시 새
revision을 반환한다. revision 충돌은 쓰지 않고 구조화된 오류를 반환한다. 이름 충돌,
profile 미존재, 잘못된 payload/version, 손상 데이터, 저장 실패와 migration 필요 상태를
안정적인 error code와 `retryable` 의미로 고정한다.

fixture에는 최소 정상 round-trip, unknown field/version, 누락·잘못된 타입, 중복 profile
이름, stale revision, 같은 idempotency key 재시도, 손상 JSON, SQLite 오류, 부분 데이터,
atomic write 실패, v6 import preview/commit 또는 명시적 unsupported 경계를 포함한다.

### 2. Profile 및 repository application service

Python 3.11 표준 라이브러리 중심의 작은 모듈로 구현한다. 저장 root와 I/O 의존성은 test가
임시 디렉터리와 fault injection을 사용할 수 있게 주입한다. import 시 사용자 경로를 만들거나
열지 않는다.

- stable profile ID와 별도 display name을 가진 profile catalog
- profile 생성·목록·선택·rename의 명시적 충돌 규칙
- P3 `ConfirmedStudent`, `InventorySnapshot`, `StudentGoalRecord`/`GrowthPlan` 경계 재사용
- canonical 결정적 직렬화와 저장 format version
- per-profile monotonic revision 및 optimistic concurrency
- idempotency key 재시도 시 같은 mutation을 중복 적용하지 않는 정책
- 임시 파일을 같은 filesystem에 쓰고 flush/fsync 가능한 범위까지 수행한 뒤 atomic replace
- 쓰기/replace 실패 시 마지막 정상 파일과 catalog 선택 상태 보존
- process crash 뒤 남은 temp 파일의 무시 또는 안전한 복구 정책
- lock 또는 단일-writer 경계를 명시해 두 backend process의 동시 쓰기 손실 방지
- malformed/unknown version/부분 데이터의 fail-closed 오류와 정상 데이터 비파괴

inventory source 선택은 P3의 `resolve_inventory_snapshot()` parity를 입력으로 사용한다.
SQLite non-empty 우선, JSON fallback/resync를 그대로 보존할지 v7에서 개선할지를 근거와
test로 고정한다. fallback 오류를 조용히 숨기지 말고 source와 진단을 application-service
결과 또는 구조화된 오류에 남긴다.

### 3. v6 profile import/migration 경계

실제 사용자 v6 데이터를 자동으로 찾아 쓰거나 변경하지 않는다. 명시적 source 경로와 target
profile을 받는 preview와 commit 경계를 제공하거나, 이번 P4에서 안전하게 구현할 수 없다면
구조화된 `migration_not_supported` 경계와 후속 계획을 고정한다.

구현하는 경우 다음을 지킨다.

- preview는 read-only이며 affected profile/record/key, 경고와 충돌을 반환한다.
- commit은 preview token 또는 source fingerprint와 expected revision을 재검증한다.
- name-only inventory를 catalog 근거 없이 item ID로 추측 병합하지 않는다.
- 원본 v6 파일은 수정·삭제하지 않는다.
- import 실패 시 기존 v7 profile을 보존한다.

### 4. Python protocol/stdio 연결

repository method를 기존 Python process dispatcher에 연결하되 planning protocol v1의
동작과 오류 의미를 유지한다. malformed/untrusted envelope 정책, request ID/method 대응과
stderr 진단 경계를 깨지 않는다.

실제 process를 종료하고 다시 시작한 뒤 같은 저장 root로 profile, current, inventory와
goal이 복원되는 종단간 test를 추가한다. test는 실제 사용자 `profiles/`, DB 또는 홈
디렉터리를 사용하지 않는다.

### 5. Dart client, AppService와 최소 프로필 UI

Flutter는 repository protocol client와 `AppService`의 typed boundary를 통해서만 접근한다.
raw dynamic map을 Widget 전체로 누출하지 말고 protocol/client 경계에서 shape와 허용 오류를
검사한다. `MockAppService`도 같은 use case를 구현해 기존 test 기본값을 유지한다.

P4 UI는 다음 최소 경로만 제공한다.

- 현재 profile 표시
- profile 목록, 생성, 선택과 이름 변경
- loading, empty, validation, disconnected, revision conflict와 persistence error 상태
- 선택 변경 또는 앱 재실행 뒤 계획 화면이 저장된 current/goal을 다시 불러오는 경로

P6의 학생/인벤토리 전체 관리 화면, scanner UI, 통계/홈 집계는 구현하지 않는다. 기존
화면 스타일을 광범위하게 재설계하지 않는다.

### 6. 문서화

다음을 현재 구현과 일치하게 갱신한다.

- `contracts/README.md`: method, payload, 오류, revision/idempotency/version 정책
- repository 저장 layout, 파일 소유권, atomicity, lock, corruption/recovery 정책 문서
- v6 import/migration 지원 범위와 명시적 제외 항목
- 새 test fixture와 마스터 재현 절차

슬레이브는 `almanac/workflows/p0-p6-workflow-status.md`의 P4 상태를 `완료`로 바꾸지 않는다.
마스터가 인계 결과를 직접 검증한 뒤 상태를 결정한다.

## 금지 및 제외 범위

- P3 DTO/merge/fixture의 의미 변경 또는 승인된 case 삭제
- scanner start/cancel/event/session, image/capture/matcher 및 candidate 자동 commit
- 낮은 confidence 결과를 current로 자동 승격
- P6 전 탭 구현, shortage 표시, 통계/추천 기능
- Qt/QML/QWidget/Tk/PySide6 코드 복사
- Flutter에서 profile JSON/SQLite/path 직접 접근
- `../v6` runtime import 또는 v6 원본 파일 변경
- 실제 사용자 profile, DB, 홈 디렉터리를 test 대상으로 사용
- 생성/local 파일, cache, build, release, 전달용 `output.md`/`artifacts/`를 patch에 포함
- 관련 없는 formatting, UI 재설계 또는 대규모 리팩터링

## 필수 테스트

최소 다음 자동 test를 추가한다.

1. profile create/list/select/rename과 이름 충돌
2. current, inventory, goals 저장 후 새 repository/process instance에서 복원
3. 다섯 bucket 비중첩과 `display_name` current 유입 거부 유지
4. 총 계산 결과와 shortage가 저장 format에 들어가지 않음
5. stale revision이 기존 데이터 변경 없이 실패
6. 같은 idempotency key 재시도가 중복 mutation/revision 증가를 만들지 않음
7. temp write, flush, replace 또는 SQLite 실패 주입 후 기존 정상 데이터 보존
8. malformed JSON, unknown version, 부분 데이터와 빈 DB/JSON fallback
9. 두 writer 경쟁 또는 lock 충돌의 결정적 결과
10. protocol schema/fixture의 Python·Dart contract parity
11. 실제 Python child process 재시작 전후 persistence E2E
12. Mock 및 real `AppService`의 최소 profile/planning 흐름 Widget test

## 필수 검증

```powershell
cd backend
py -3.11 -m unittest tests.test_repository_parity -v
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

- P3 baseline gate의 실제 fixture/test 수와 field 교집합
- P4 신규 schema/fixture/test 수
- 실제 child process 재시작 persistence 결과
- failure injection별 기존 데이터 hash/revision 보존 결과
- 금지된 v6/scanner/GUI runtime import 검색 결과
- 실제 사용자 profile/DB를 쓰지 않았다는 temp root 증거
- patch 대상과 작업 전 tree의 중첩 여부

실행하지 못한 검증은 통과로 쓰지 말고 `NOT_VERIFIED`와 이유를 기록한다.

## 완료 조건

다음이 모두 충족돼야 `COMPLETED`로 보고한다.

- P3 승인 baseline이 변경 전 재현되고 P4 뒤에도 회귀 없이 유지된다.
- profile, current, inventory와 goal이 실제 process 재실행 뒤 복원된다.
- atomic/failure test에서 마지막 정상 데이터와 선택 profile이 보존된다.
- revision 충돌과 idempotent retry가 자동 test로 고정된다.
- 계산 총계와 shortage가 원본 상태처럼 저장되지 않는다.
- Flutter가 파일/DB를 직접 읽지 않고 Mock/real service 경계가 일치한다.
- 병합·손상·실패 fixture 및 Python/Dart contract test가 통과한다.
- v6 import/migration 경계가 명시적이고 v6 원본을 변경하지 않는다.
- Python/Flutter/release/Almanac/diff 전체 검증이 통과한다.
- P5/P6 범위가 추가되지 않았다.

## 결과물 및 인계 계약

```text
docs/migration/p4-repository-persistence/
├─ input.md                              # 이 파일: 수정·삭제·덮어쓰기 금지
├─ slave-execution-prompt.md             # 실행용 안내: patch에 포함하지 않음
├─ output.md                             # 모든 결과물이 준비된 뒤 마지막에 작성
└─ artifacts/
   ├─ p4-repository-persistence.patch
   └─ verification.txt
```

- patch는 위 P3 승인 baseline에 적용되는 단일 P4 증분이어야 한다.
- 작업 시작 전 `git status --short`와 baseline commit 또는 diff 식별 정보를
  `verification.txt`에 기록한다.
- P3 파일을 수정해야 한다면 이유와 semantic diff를 별도 항목으로 기록한다. P3 의미를
  바꾸는 수정은 허용되지 않는다.
- `input.md`, `slave-execution-prompt.md`, `output.md`, `artifacts/`, 이전 단계 patch와
  관련 없는 변경을 patch에 포함하지 않는다.
- `verification.txt`에는 명령, exit code, test/fixture 수와 실패 주입 결과를 기록한다.
- 모든 artifact의 존재, 0보다 큰 크기, 바이트 크기와 SHA-256을 확인한다.
- `output.md`는 `almanac/workflows/slave-artifact-handoff.md` 계약을 따른다.

## cross-PC 전달

마스터에서 receiver를 먼저 실행한다.

```powershell
& "$HOME\.codex\ba-planner-slave\Receive-SlaveResult.ps1" `
  -TaskId "ba-planner-v7-p4-repository-persistence"
```

슬레이브에서 결과 준비 후 sender를 사용한다.

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p4-repository-persistence" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p4-repository-persistence"
```

Task ID와 TaskDirectory를 생략하지 않는다. 마스터의 `WIRELESS_HANDOFF_RECEIVED` 확인 전에는
무선 전달 완료로 보고하지 않는다. token은 출력·파일·로그·문서에 기록하지 않는다.

```text
TASK_OUTPUT_READY
task_id: ba-planner-v7-p4-repository-persistence
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

완료할 수 없으면 `TASK_OUTPUT_BLOCKED`로 보고한다. 마스터가 package, artifact, patch와 전체
검증을 직접 확인하기 전에는 P4를 완료로 간주하지 않는다.
