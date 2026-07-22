# P6-3 스캔 실제 UI 통합

## 작업 ID

```text
ba-planner-v7-p6-3-scan-integration
```

## 목표

마스터가 승인한 P0~P5, P6-1 학생과 P6-2 인벤토리 경계를 유지하면서 Flutter의 스캔 탭
placeholder를 P5의 실제 typed scanner service에 연결된 `ScanPage`로 교체한다. 이 작업은
P6 전체가 아니라 세 번째 수직 슬라이스다.

완성된 스캔 탭에서 사용자는 선택된 repository 프로필을 기준으로 다음 작업을 할 수 있어야 한다.

1. backend, recognition asset과 대상 게임 창의 준비 상태를 확인한다.
2. 학생 또는 인벤토리 scan kind와 ready target을 명시적으로 선택한다.
3. 한 session을 시작하고 phase, 진행률, 현재 메시지와 진단을 확인한다.
4. 실행 중인 session을 cooperative cancel하고 terminal 결과 뒤 재시도한다.
5. candidate의 kind, 변경 payload 요약, confidence/evidence와 review-required 상태를 확인한다.
6. candidate를 해당 학생 또는 인벤토리 탭으로 넘겨 기존 확정 상태와 비교·검토·commit한다.
7. 현재 앱 실행 중의 최근 session 결과를 다시 열되 존재하지 않는 영구 history를 꾸며내지 않는다.

## 먼저 읽을 문서와 코드

- `README.md`, `AGENTS.md`
- `docs/migration/v6-knowledge-baseline.md`
- `almanac/workflows/p0-p6-workflow.md`의 공통 불변식, P5와 P6 절
- `almanac/workflows/p0-p6-workflow-status.md`의 P5, P6-1, P6-2와 P6-3 절
- `almanac/design/frontend-section-direction-and-user-flows.md`의 공통 규칙과 스캔 탭 절
- `almanac/design/responsive-diagonal-layout-policy.md`
- `almanac/workflows/slave-artifact-handoff.md`
- `almanac/workflows/cross-pc-slave-handoff.md`
- `docs/migration/p5-scanner-matcher/scanner-characterization.md`
- `docs/migration/p5-scanner-matcher/scanner-runtime.md`
- `../v6/almanac/flows/student-scan.md`, `../v6/almanac/flows/inventory-scan.md`
- `frontend/lib/services/scanner_service.dart`, `process_app_service.dart`, `mock_app_service.dart`
- `frontend/lib/ui/app_shell.dart`, `student_page.dart`, `inventory_page.dart`
- `contracts/scanner-protocol-v1.schema.json`, `contracts/fixtures/scanner_protocol_v1.json`
- scanner protocol/client/process/Mock test와 P6-1/P6-2 Widget test

문서와 코드가 다르면 현재 v7 코드와 마스터 검증 결과를 우선하고 차이를 `output.md`에 기록한다.

## 승인된 P6-2 baseline gate

P6-3은 마스터가 승인한 P6-2 snapshot 위의 단일 증분이어야 한다. 승인본은 최소 다음 상태다.

- P6-1 `StudentPage`와 P6-2 `InventoryPage`가 실제 service-backed 화면이다.
- `StudentCandidateContext`와 `InventoryCandidateContext`가 존재한다.
- `planning.inventory.catalog`, `planning.plan.shortages`와 typed inventory save가 존재한다.
- `InventoryPage`의 catalog 오류는 일반 action message와 분리되어 프로필 자동 선택에 지워지지 않는다.
- 실제 Dart↔Python catalog·shortage·inventory save/restart E2E assertion이 존재한다.
- Python 전체 72 tests, Flutter 전체 65 tests, `flutter analyze`, Windows release,
  CodeAlmanac과 `git diff --check`가 마스터에서 통과했다.
- `almanac/workflows/p0-p6-workflow-status.md`에서 P6-1과 P6-2가 `완료`다.
- 현재 스캔 탭만 `SectionPlaceholderPage`이며 P5의 typed scanner API는 이미 존재한다.

승인된 P6-2 snapshot이 없다면 P6-1/P6-2를 추측해 재구성하거나 원격 branch의 오래된 상태 위에서
작업하지 않는다. `BLOCKED`로 보고하고 마스터에게 동일한 accepted P6-2 snapshot을 요청한다.
승인본이 정확히 존재하면 그 상태만 local baseline commit으로 고정할 수 있으나 push하지 않는다.
baseline commit과 포함된 P6-2 경로를 `verification.txt`에 기록한다. 다른 사용자 변경이 대상 경로와
중첩되면 임의 commit·stash·삭제하지 않고 `BLOCKED`로 보고한다.

## 소유 범위와 금지 범위

### P6-3이 소유하는 것

- ScanPage의 readiness/target/profile/kind 선택
- session start, active state, phase/progress/diagnostic/terminal 표시
- cancel, terminal 이후 retry와 같은 앱 실행 중 최근 session 요약
- event gap/error 발생 시 active session snapshot 복구 UI
- candidate/evidence 요약과 학생/인벤토리 탭으로의 typed handoff
- AppShell의 kind별 latest candidate context와 성공 commit 뒤 stale context 정리

### P6-3이 소유하지 않는 것

- scanner capture/matcher/backend protocol을 새로 설계하거나 P5를 재구현하는 일
- 학생·인벤토리 repository mutation을 ScanPage에서 중복 구현하는 일
- 홈, 통계, 전술대항전, 설정 탭 또는 P7 이후 기능
- 영구 recent-session repository나 새로운 history protocol 추측
- recognition template을 Flutter UI asset으로 복사하는 일
- 실제 게임 창을 자동 조작하는 무인 smoke test

candidate의 최종 비교·review·commit은 data owner인 `StudentPage` 또는 `InventoryPage`가 계속
소유한다. ScanPage의 기본 행동은 `학생에서 검토` 또는 `인벤토리에서 검토`이며 자동 commit이 아니다.

## 공통 불변식

- Flutter와 Python은 별도 process이며 versioned JSONL protocol만 사용한다.
- v6 Python module을 runtime import하지 않는다.
- Qt, QML, QWidget, Tkinter, PySide6 presentation 코드를 복사하지 않는다.
- scanner event는 log 문자열이 아니라 typed session/generation/sequence 계약이다.
- start response 이전 event race, stale generation, duplicate/out-of-order, sequence gap과 after-terminal
  event의 P5 정책을 약화하지 않는다.
- candidate와 terminal event는 UI 편의를 위해 drop하지 않는다.
- cancel response는 terminal event가 아니다. terminal 또는 snapshot 확인 전 session이 끝났다고
  표시하거나 새 session을 병렬 시작하지 않는다.
- 낮은 confidence/review-required candidate를 자동 승인·commit하지 않는다.
- 학생 current, inventory snapshot, static metadata, goals, gross totals와 shortage bucket을 섞지 않는다.
- recognition asset 절대경로, profile 파일과 SQLite를 Flutter가 직접 읽지 않는다.

## 구현 요구사항

### 1. ScanPage 준비 상태

- `AppSection.scan`의 placeholder를 실제 `ScanPage`로 교체한다.
- 현재 backend connection, selected repository profile, recognition readiness와 target 목록을
  독립된 상태로 로드하고 새로고침한다.
- target title이 같아도 stable `target_id`로 선택한다. foreground는 추천 표시일 뿐 자동 실행 근거가 아니다.
- ready/minimized/closed/unsupported를 구분하고 ready가 아닌 target으로 시작하지 않는다.
- readiness의 `ready`, manifest version, missing/corrupt 요약을 표시하되 내부 절대경로나 recognition
  template을 UI asset으로 노출하지 않는다.
- disconnected, no repository service, no selected profile, loading, empty target, readiness failure와
  target-list failure를 서로 구분하고 복구 행동을 제공한다.

### 2. Session controller와 event projection

- 학생/인벤토리 두 kind만 제공하고 선택된 kind와 target ID를 그대로 `startScannerSession`에 전달한다.
- active session은 하나만 허용한다. start 중, running, cancelling, terminal 상태를 명확히 나눈다.
- session ID, generation, phase, progress current/nullable total, message key와 diagnostic을 구조화해 표시한다.
- total이 null 또는 0이면 임의 percentage를 만들지 않고 indeterminate 상태로 표시한다.
- 현재 active session과 ID/generation이 다른 event는 UI 상태를 바꾸지 않는다.
- sequence gap 또는 stream error가 발생하면 `scannerSnapshot(activeSession)`을 호출해 typed projection을
  복구한다. snapshot 실패는 원래 상태를 지우지 않고 재시도 가능한 오류로 표시한다.
- terminal outcome `completed`, `cancelled`, `failed`와 structured error를 구분한다.
- widget dispose, backend disconnect/restart와 section 전환에서 subscription/timer/future setState를 정리한다.

### 3. Cancel, retry와 최근 결과

- running session에서만 cancel할 수 있다. 중복 cancel은 UI에서 억제하고 backend idempotency를 깨지 않는다.
- cancel acknowledgement 뒤 `cancelling`을 유지하고 terminal/snapshot으로 종료를 확인한다.
- retry는 terminal session의 kind와 target을 기본값으로 제안하되 새 session/generation으로 시작한다.
- 최근 결과는 현재 앱 실행 중 bounded in-memory 목록으로 제한한다. 최소 outcome, kind, target title,
  generation, 마지막 phase/diagnostic, candidate/review 대기 여부를 보존한다.
- backend가 제공하지 않는 시간, 영구 기록, 재시작 후 history를 만들어내지 않는다.

### 4. Candidate 요약과 탭 handoff

- candidate event의 typed `ScannerCandidate`를 보존하고 payload, evidence, confidence, status/source/note,
  review-required/approved를 안전하게 표시한다. raw JSON만을 유일한 사용자 UI로 사용하지 않는다.
- 같은 session candidate revision을 stable identity로 관리하고 오래된 revision이 최신 것을 덮어쓰지 않는다.
- 학생 candidate는 `StudentCandidateContext`, inventory candidate는 `InventoryCandidateContext`로 AppShell에
  전달하고 해당 탭을 연다. kind/payload 불일치면 전달하지 않고 명시적 오류를 표시한다.
- AppShell은 kind별 latest candidate context를 보존해 화면 전환 후에도 검토할 수 있게 한다.
- destination page의 commit 성공 callback으로 해당 context를 정리한다. Hold는 repository를 바꾸지 않으며
  현재 실행 중에는 다시 열 수 있다.
- ScanPage 자체는 `reviewScannerCandidate`나 `commitScannerCandidate`를 호출하지 않는다.

### 5. Mock와 기존 service 보완

- `MockAppService`가 ScanPage가 소비할 deterministic student/inventory phase → progress → candidate → terminal
  흐름을 제공하도록 보완한다. test가 timing 우연성에 의존하지 않게 한다.
- cancel, failed terminal, review-required, explicit inventory unknown과 stale repository revision 시나리오를
  만들 수 있어야 한다.
- P5 `ScannerProtocolClient`와 Python protocol을 UI 편의 때문에 느슨하게 만들지 않는다.
- snapshot raw map을 UI에서 반복 해석해야 한다면 strict Dart typed snapshot/projection model을 추가하되
  기존 wire method와 schema 의미를 바꾸지 않는다.
- 실제 P5 backend/contract 결함을 발견한 경우에만 최소 수정하고 원인·회귀 test를 기록한다.

### 6. Layout와 접근성

- P6-1/P6-2의 `DiagonalSection`, 현재 shell theme와 scrollable composition을 재사용한다.
- control row는 좁은 창에서 wrap/scroll되며 긴 target title, 긴 diagnostic, 많은 evidence/candidate 때문에
  action이 접근 불가능해지지 않아야 한다.
- 시작·취소·재시도·검토 이동 button에 stable key와 disabled semantics를 제공한다.
- phase/progress/terminal은 색상만으로 구분하지 않고 text/semantics를 함께 제공한다.
- 1280x720, 1440x900, 1280x960에서 overflow가 없고 핵심 행동을 scroll로 접근할 수 있어야 한다.

## 필수 테스트

최소 다음 자동 검증 source를 작성한다.

- readiness/target/profile의 loading, empty, error, disconnected와 refresh
- ready/minimized/closed/unsupported target, 같은 title의 stable ID와 foreground 표시
- student/inventory kind와 target ID가 start request에 정확히 전달됨
- start 중 중복 실행 금지, phase/progress/nullable total/diagnostic/terminal projection
- cancel acknowledgement와 terminal 분리, 중복 cancel 억제, terminal 이후 retry의 새 generation
- stale/duplicate/after-terminal 무시와 sequence gap snapshot 복구/복구 실패 보존
- candidate revision/evidence/review-required 표시와 kind/payload mismatch 거부
- ScanPage에서 직접 commit하지 않고 학생/인벤토리 context handoff
- destination hold는 mutation 없음, approve/commit은 repository 반영, 성공 뒤 AppShell context 정리
- MockAppService의 student/inventory/cancel/failure deterministic 흐름
- 실제 Dart `ProcessAppService` ↔ Python event E2E의 target/readiness/start/phase/progress/candidate/terminal,
  cancel 또는 snapshot, restart/dispose cleanup
- P6-1 StudentPage, P6-2 InventoryPage, planning/repository/scanner 기존 회귀
- 긴 target/diagnostic, 많은 evidence와 1280x720·1440x900·1280x960 overflow/accessibility

실제 게임 창 smoke는 자동화하지 않는다. 안전하게 수동 실행할 수 없는 경우 `NOT_VERIFIED`로 남기되
fixture/fake process E2E와 production adapter test를 대신 성공으로 과장하지 않는다.

## 슬레이브 환경 제약

현재 슬레이브 PC에는 Flutter/Dart SDK와 CodeAlmanac CLI가 없다. 설치하거나 공간 확보를 위해 SDK,
cache, repository 또는 사용자 파일을 삭제하지 않는다.

- Python 3.11 test, JSON/schema/fixture 검사, 정적 `rg`, `git diff --check`, patch 생성은 수행한다.
- Dart/Flutter source와 test는 반드시 작성한다.
- 실행할 수 없는 Flutter/Dart/analyze/release, 실제 Dart↔Python E2E와 Almanac은 성공으로 주장하지 않고
  `NOT_VERIFIED` 및 `MASTER_REQUIRED:`로 기록한다.
- 도구 부재만으로 전체 작업을 `BLOCKED` 처리하지 않는다.

## 필수 결과물

```text
docs/migration/p6-3-scan-integration/
├─ input.md
├─ output.md
└─ artifacts/
   ├─ p6-3-scan-integration.patch
   └─ verification.txt
```

patch는 마스터 승인 P6-2 snapshot 위의 P6-3 단일 증분이어야 한다. 다음을 포함하지 않는다.

- `input.md`, `slave-execution-prompt.md`, `output.md`, `artifacts/`
- P6-2 또는 이전 patch와 handoff package
- build/cache/log/profile/database/scan result/debug crop/adaptive sample
- v6 source 복사본이나 recognition template 복제본

모든 patch path는 `BA Planner/v7/...`여야 한다. `verification.txt`에는 baseline commit, accepted P6-2
gate, dirty-path 판단, 실행 명령, test 수와 결과, master 전용 gate를 기록한다.

## 완료 조건

다음을 모두 만족할 때만 `COMPLETED`로 보고한다.

- scan placeholder가 실제 service-backed `ScanPage`로 교체되었다.
- readiness·target·profile·kind, start/progress/cancel/retry와 terminal 흐름이 typed service를 통과한다.
- event gap snapshot 복구와 stale/terminal 정책이 자동 test로 보호된다.
- candidate가 자동 commit되지 않고 올바른 destination context로 전달된다.
- Mock의 student/inventory/cancel/failure 흐름과 실행 가능한 test source가 존재한다.
- 필수 Python 회귀와 patch 무결성 검증이 통과한다.
- 모든 결과물이 `artifacts/` 아래에 있고 `output.md`에 실제 byte size와 SHA-256이 있다.

슬레이브의 `COMPLETED`는 P6-3 구현·산출물 준비 완료만 뜻한다. 마스터가 모든 MASTER_REQUIRED gate와
실제 UI/event 흐름을 직접 검증하기 전에는 P6-3 또는 P6 전체 완료를 주장하지 않는다.
