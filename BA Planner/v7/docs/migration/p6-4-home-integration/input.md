# P6-4 홈 실제 데이터 통합

## 작업 ID

`ba-planner-v7-p6-4-home-integration`

## 목표

마스터가 승인한 P0~P5와 P6-1 학생·P6-2 인벤토리·P6-3 스캔 통합 경계를 유지하면서,
현재 이미지 메뉴 중심의 홈을 실제 repository·planning·scanner 상태를 읽는 시작 대시보드로 완성한다.
기존 80° 사선 홈 메뉴는 빠른 이동 수단으로 보존하고, 문제/검토 상태, 선택 프로필, 저장된 계획,
인벤토리 부족량과 최근 스캔 요약을 실제 데이터에서 파생해 표시한다.

이 작업은 P6-4 하나의 증분이다. 통계, 전술대항전, 설정 및 전 탭 통합 오류 처리는 각각
P6-5~P6-7이 소유한다. P6-4 완료만으로 P6 전체 완료를 주장하지 않는다.

## 먼저 읽을 자료

- `README.md`, `AGENTS.md`
- `docs/migration/v6-knowledge-baseline.md`
- `almanac/workflows/p0-p6-workflow.md`의 공통 불변식과 P6 절
- `almanac/workflows/p0-p6-workflow-status.md`의 P6-1~P6-4 절
- `almanac/design/frontend-section-direction-and-user-flows.md`의 공통 규칙과 홈 탭 절
- `almanac/design/responsive-diagonal-layout-policy.md`
- `almanac/workflows/slave-artifact-handoff.md`, `cross-pc-slave-handoff.md`
- `docs/migration/v6-diagonal-home-menu-migration.md`
- P6-1~P6-3의 `input.md`, 현재 `output.md`가 있다면 승인 근거
- `frontend/lib/ui/pages/home_page.dart`, `planning_page.dart`, `inventory_page.dart`, `scan_page.dart`
- `frontend/lib/ui/app_shell.dart`, `app_section.dart`
- `frontend/lib/services/app_service.dart`, `repository_service.dart`, `scanner_service.dart`
- `frontend/lib/services/process_app_service.dart`, `mock_app_service.dart`
- 관련 Flutter test와 실제 Dart↔Python repository/planning/scanner E2E

## 승인된 P6-3 baseline gate

P6-4는 마스터가 승인한 P6-3 snapshot 위의 단일 증분이어야 한다. 최소 다음 상태가 있어야 한다.

- `StudentPage`, `InventoryPage`, `ScanPage`가 service-backed 실제 화면이다.
- 학생·인벤토리 candidate가 AppShell의 kind별 context로 전달되고 성공 commit 뒤 정리된다.
- ScanPage가 typed readiness·target·session·snapshot·cancel/retry와 앱 실행 중 bounded recent 결과를 가진다.
- repository에 선택 프로필, confirmed students, inventory, saved goals가 있고 planning shortage API가 존재한다.
- P6-3 마스터 보정과 실제 process snapshot E2E assertion이 포함되어 있다.
- 워크플로에서 P6-1~P6-3은 `완료`, P6 전체는 `진행 중`, P6-4는 미완료다.
- 승인 시점 기준 Python 72 tests, Flutter 78 tests, analyze, Windows release, 실제 process E2E,
  3개 viewport, Almanac과 `git diff --check`가 통과했다.

이 상태가 없으면 이전 단계를 추측해 재구성하거나 오래된 origin/main 위에서 작업하지 않는다.
`BLOCKED`로 보고하고 마스터에게 동일한 accepted P6-3 snapshot을 요청한다. 정확한 승인본이 있다면
그 상태만 local baseline commit으로 고정할 수 있으나 push하지 않는다. baseline ID와 승인 경로를
`verification.txt`에 기록한다. 기존 사용자 변경과 대상 경로가 겹치면 commit·stash·삭제하지 않고
`BLOCKED`로 보고한다.

## 범위와 데이터 소유권

### P6-4가 소유하는 것

- 선택 프로필과 backend 연결 상태를 보여 주는 홈 상태 요약
- 실제 repository state에서 파생한 confirmed 학생 수, inventory known/unknown 요약과 저장된 목표 수
- 저장된 plan과 inventory를 사용한 주요 부족 재화 요약
- P6-3의 최신 in-memory scan 결과와 검토 대기 candidate 표시
- 문제/검토 상태에서 적절한 data-owner 탭으로 이동하는 명시적 행동
- 기존 홈 이미지 메뉴를 보존한 전체 기본 탭 빠른 이동
- loading, empty, disconnected, partial error와 refresh/resume 동작

### P6-4가 소유하지 않는 것

- 새 repository, planning 또는 scanner wire method/schema
- 홈에서 repository mutation, candidate review/commit 또는 plan 저장
- backend에 없는 영구 최근 활동, last-scan timestamp, 데이터 최신 시각 또는 stale 판정
- 통계 차트·집계 계약, 전술대항전 편성, 설정/재시작/진단 구현
- P6-5~P6-7 또는 P7 이후 기능
- v6 UI code/runtime import, 홈 PNG 재생성 또는 recognition template 복제

홈은 read model이다. 값의 출처와 의미를 바꾸지 않고 기존 typed service를 조합한다. 새 backend method가
필요하다고 판단되면 구현하지 말고 `BLOCKED` 또는 명시적 위험으로 보고해 마스터 결정을 받는다.

## 공통 불변식

- Flutter와 Python은 별도 process이며 versioned JSONL protocol만 사용한다.
- `../v6` Python module을 runtime import하지 않고 Qt/QML/QWidget/Tk/PySide6 code를 복사하지 않는다.
- scanned current, static metadata, user goals, gross calculation, inventory shortage 다섯 bucket을 섞지 않는다.
- repository snapshot 부재나 inventory `quantity: null`은 0이 아니다.
- 홈에서 자동 save, candidate 승인, zero-fill 또는 목표 변경을 하지 않는다.
- 저장된 goals가 없으면 plan/shortage는 empty다. 임시 PlanningPage draft를 저장된 계획으로 표현하지 않는다.
- shortage는 기존 `calculateShortages` 결과만 사용하며 required, owned, shortage와 unresolved를 보존한다.
- 최근 scan은 P6-3과 같은 현재 앱 실행 중 bounded memory다. backend가 제공하지 않는 시각을 만들지 않는다.
- async refresh의 늦은 응답이 새 profile/connection/navigation 상태를 덮어쓰지 않게 generation을 둔다.

## 구현 요구사항

### 1. 기존 홈 메뉴와 정보 구조

- `home_page.dart`의 기존 742×1018 설계 캔버스, 80° geometry, PNG crop, 메뉴 caption과 모든 기본 탭
  navigation을 보존한다. 이미지 자산을 교체하거나 다시 생성하지 않는다.
- 홈의 정보 우선순위는 `문제/검토 필요` → `프로필·계획·부족 요약` → `빠른 이동`이다.
- 서비스 요약은 `DiagonalSection` 등 승인된 glass/diagonal widget을 재사용하고 중앙에 독립적으로 떠 있는
  card 집합으로 만들지 않는다.
- 넓은 창은 dashboard와 기존 launcher를 함께 볼 수 있고, 좁거나 낮은 창은 전체 페이지 scroll/reflow로
  모든 상태와 메뉴에 접근할 수 있어야 한다. 전체 canvas를 무조건 축소해 text를 읽기 어렵게 만들지 않는다.

### 2. 프로필과 repository 요약

- `RepositoryService`가 없거나 backend가 disconnected/connecting이면 각각 구분된 상태와 설정 이동 행동을
  제공한다. P6-7의 reconnect/restart 구현을 홈에 복제하지 않는다.
- profiles를 읽어 selected profile을 stable ID로 찾고 `loadRepositoryState`를 호출한다.
- 선택 프로필 없음, profiles empty, state loading, profile/state error를 구분한다.
- 프로필 이름과 revision, confirmed student 수, inventory entry 수를 실제 `RepositoryState`에서 표시한다.
- inventory는 known quantity entry와 unknown quantity entry를 분리한다. 누락/unknown을 0으로 합산하지 않는다.
- 활성 계획은 저장된 `RepositoryState.goals`의 학생 수로 정의한다. 화면의 임시 planning draft를 추측하지 않는다.
- 명시적 refresh와 홈 재진입 시 다시 읽는다. 같은 프로필·revision이라도 요청 중 상태 전환과 오류 복구를
  안전하게 처리하고 stale future를 무시한다.

### 3. 부족 재화 요약

- 저장된 goal이 있을 때만 repository students, saved goals와 inventory snapshot을 기존
  `calculateShortages`에 전달한다. current student 변환은 InventoryPage와 같은 승인 필드 의미를 재사용하거나
  공용 helper로 추출해 두 화면의 해석이 달라지지 않게 한다.
- 양수 shortage를 우선해 내림차순으로 정렬하고 안정적인 tie-breaker를 적용한다. 홈에는 bounded top-N만
  보이며 전체 분석은 InventoryPage로 이동한다.
- `owned == null`, `shortage == null`, `resolved == false`, warnings를 0 또는 정상으로 표현하지 않는다.
- goals empty, 계산 중, 결과 empty, partial warning, 계산 failure를 구분한다.
- 홈은 gross total을 새 방식으로 재계산하거나 shortage 결과를 저장하지 않는다.

### 4. 최근 스캔과 검토 대기 인계

- P6-3의 terminal recent summary를 public immutable typed projection으로 AppShell에 전달한다. 홈이
  ScanPage private state나 raw event map을 직접 읽지 않는다.
- 최소 kind, target title/ID, outcome, generation, phase/diagnostic, candidate count와 review-required를
  보존한다. backend에 없는 timestamp는 추가하지 않는다.
- 앱 실행 중 latest 또는 작은 bounded 목록만 공유한다. AppShell/ScanPage 생명주기 밖 영구 저장은 금지한다.
- AppShell의 student/inventory candidate context 존재 여부를 홈의 검토 대기 상태로 표시한다.
- 검토 행동은 candidate의 data owner인 StudentPage 또는 InventoryPage로 이동한다. scan session 상세는
  ScanPage로 이동한다. 홈에서 review/commit API를 호출하지 않는다.
- destination commit 성공 뒤 context가 정리되면 홈의 검토 대기 표시도 사라져야 한다. Hold는 유지한다.

### 5. 빠른 행동과 상태 오류

- 프로필/backend 문제 → 설정, 데이터 없음 → 스캔, 저장된 계획 → 계획, 부족 상세 → 인벤토리,
  학생 확인 → 학생, 최근 scan 상세 → 스캔으로 이동하는 stable-key action을 제공한다.
- 기존 이미지 메뉴의 홈 이외 모든 기본 탭 버튼도 계속 정확히 이동해야 한다.
- 일부 source가 실패해도 성공한 profile/count/scan 요약을 모두 지우지 않는다. source별 오류와 retry를 둔다.
- 사용자에게 내부 절대경로, raw exception stack 또는 recognition asset 경로를 노출하지 않는다.
- AppServiceState의 개발용 placeholder count를 실제 repository count로 오인하지 않는다.

### 6. Mock와 실제 service

- `MockAppService`/repository mock에서 selected profile, no profile, known/unknown inventory, saved/no goals,
  shortage success/warning/failure와 disconnected 상태를 deterministic하게 검증할 수 있게 한다.
- 실제 `ProcessAppService`·RepositoryService·ScannerService 계약을 UI 편의로 느슨하게 만들지 않는다.
- 새 protocol 없이 구현 가능한 범위이므로 backend 변경은 원칙적으로 금지한다. 실제 결함을 test로 입증한
  최소 수정만 허용하고 원인과 회귀 test를 기록한다.

### 7. Layout와 접근성

- 상태는 색상만으로 구분하지 않고 text/icon/semantics를 함께 제공한다.
- 긴 profile/resource/target/diagnostic, 많은 warning과 missing metadata가 overflow를 만들지 않아야 한다.
- refresh, 검토, 계획, 인벤토리, 스캔, 설정 이동에는 stable key와 적절한 disabled semantics가 있어야 한다.
- 1280×720, 1440×900, 1280×960에서 overflow가 없고 dashboard와 기존 메뉴의 핵심 action을 scroll로
  접근할 수 있어야 한다. 기존 home geometry/seam/crop test를 퇴행시키지 않는다.

## 필수 테스트

최소 다음 자동 검증 source를 작성한다.

- disconnected/connecting, RepositoryService 부재, profile loading/empty/error와 refresh 복구
- selected profile stable ID, revision, confirmed student, inventory known/unknown, saved goal 수
- goals empty에서는 shortage 호출 없음; goals 존재 시 정확한 current/goals/inventory 전달
- positive shortage 정렬과 top-N, unknown/unresolved/warning/empty/error 표시
- 느린 이전 profile/refresh 응답이 새 상태를 덮어쓰지 않는 generation race
- ScanPage terminal summary → AppShell → Home typed projection
- student/inventory pending candidate action, Hold 유지와 commit 성공 뒤 홈 표시 정리
- profile/backend 문제·학생·계획·인벤토리·스캔·설정 quick action navigation
- 부분 실패가 성공한 다른 source 요약을 지우지 않음
- MockAppService의 deterministic no-data/data/error 흐름
- 실제 Dart ProcessAppService↔Python repository load와 shortage 요약 E2E
- P6-1 StudentPage, P6-2 InventoryPage, P6-3 ScanPage와 planning/repository/scanner 회귀
- 기존 home image/80° geometry/seam/crop/navigation 회귀
- 긴 문자열과 1280×720·1440×900·1280×960 overflow/action 접근성

실제 게임 창 smoke는 P6-4 필수 조건이 아니다. 실행하지 않았다면 `NOT_VERIFIED`로 기록하며 fixture나
Mock 결과를 실제 게임 검증으로 표현하지 않는다.

## 슬레이브 환경 제약

현재 슬레이브 PC에는 Flutter/Dart SDK와 CodeAlmanac CLI가 없다. 설치하거나 공간 확보를 위해 SDK,
cache, repository 또는 사용자 파일을 삭제하지 않는다.

- Python 3.11 test, JSON/schema/fixture 검사, 정적 `rg`, `git diff --check`, patch 생성은 수행한다.
- Dart/Flutter source와 test는 반드시 작성한다.
- Flutter/Dart test, analyze, Windows release, 실제 Dart↔Python E2E와 Almanac은 실행한 것처럼 주장하지 않고
  `NOT_VERIFIED`, 근거 첫머리에 `MASTER_REQUIRED:`를 기록한다.
- 도구 부재만으로 전체 작업을 `BLOCKED` 처리하지 않는다.

## 필수 결과물

```text
docs/migration/p6-4-home-integration/
├─ input.md
├─ output.md
└─ artifacts/
   ├─ p6-4-home-integration.patch
   └─ verification.txt
```

patch는 승인된 P6-3 snapshot 위의 P6-4 단일 증분이어야 한다. 다음을 포함하지 않는다.

- `input.md`, `slave-execution-prompt.md`, `output.md`, `artifacts/`
- P6-3 또는 이전 patch와 handoff package
- P6-5~P6-7 구현
- build/cache/log/profile/database/scan result/debug crop/adaptive sample
- v6 source나 Qt/PySide presentation code, recognition template 또는 기존 홈 PNG 복제본

모든 patch path는 `BA Planner/v7/...`여야 한다. `verification.txt`에는 baseline commit, accepted P6-3
gate, dirty-path 판단, 구현 결정, 실행 명령, test 수와 결과, master 전용 gate를 기록한다.

## 완료 조건

다음을 모두 만족할 때만 `COMPLETED`로 보고한다.

- 기존 홈 menu geometry/navigation이 유지되며 실제 service-backed 상태 대시보드가 추가되었다.
- 선택 프로필, 실제 repository count, 저장된 plan과 shortage summary가 bucket 의미를 보존한다.
- latest scan과 pending candidate가 typed AppShell read model로 홈에 전달되고 홈에서 mutation하지 않는다.
- loading, empty, disconnected, partial error, refresh/resume와 stale async race가 test source로 보호된다.
- quick action과 3개 viewport, 기존 홈 geometry 회귀 test source가 존재한다.
- 가능한 Python 회귀와 patch 무결성 검사가 통과한다.
- 두 artifact가 `artifacts/` 아래에 있고 `output.md`에 실제 byte size와 SHA-256이 기록된다.

슬레이브의 `COMPLETED`는 P6-4 구현과 산출물 준비 완료만 뜻한다. 마스터가 모든 `MASTER_REQUIRED` gate를
직접 통과시키기 전에는 P6-4 완료를 주장하지 않는다. P6-4가 승인되어도 P6-5~P6-7과 최종 통합 흐름이
남으므로 P6 전체 완료를 주장하지 않는다.
