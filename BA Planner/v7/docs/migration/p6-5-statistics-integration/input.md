# P6-5 통계 실제 데이터 통합

## 작업 ID

`ba-planner-v7-p6-5-statistics-integration`

## 목표

마스터가 승인한 P0~P5와 P6-1~P6-4 경계를 유지하면서 통계 탭 placeholder를 선택 프로필의
실제 학생 catalog/current state, inventory catalog/snapshot, saved goals, gross calculation과 shortage
결과를 읽는 service-backed 분석 화면으로 교체한다.

통계는 원본을 수정하는 화면이 아니다. `관심 구간 발견 → 근거 목록 확인 → 학생·인벤토리·계획
data-owner 탭으로 이동` 흐름만 소유한다. 새 통계 backend, history, 캐시 또는 repository mutation을
만들지 않는다.

이 작업은 P6-5 하나의 증분이다. 전술대항전과 설정·통합 오류 처리는 P6-6·P6-7이 소유하며,
P6-5 완료만으로 P6 전체 완료를 주장하지 않는다.

## 먼저 읽을 자료

- `README.md`, `AGENTS.md`
- `docs/migration/v6-knowledge-baseline.md`
- `../v6/STUDENT_PLANNER_HANDOFF.md`의 Statistics Guide와 five-bucket 경계
- `../v6/docs/ui-behavior/statistics.md`
- `../v6/gui/student_stats.py`, `../v6/gui/viewer_components/statistics.py`는 동작 참고만 하고 UI code를 복사하지 않음
- `almanac/workflows/p0-p6-workflow.md`의 공통 불변식과 P6 절
- `almanac/workflows/p0-p6-workflow-status.md`의 P6-1~P6-5 절
- `almanac/design/frontend-section-direction-and-user-flows.md`의 공통 규칙과 통계 탭 절
- `almanac/design/responsive-diagonal-layout-policy.md`
- `almanac/workflows/slave-artifact-handoff.md`, `cross-pc-slave-handoff.md`
- P6-1~P6-4의 `input.md`와 승인 결과
- `frontend/lib/services/app_service.dart`, `repository_service.dart`, `process_app_service.dart`, `mock_app_service.dart`
- `frontend/lib/ui/app_shell.dart`, `app_section.dart`
- `student_page.dart`, `planning_page.dart`, `inventory_page.dart`, `home_page.dart`
- planning/repository/catalog/shortage contract fixture와 Python/Dart test

## 승인된 P6-4 baseline gate

P6-5는 마스터가 승인한 P6-4 snapshot 위의 단일 증분이어야 한다. 최소 다음 상태가 있어야 한다.

- P6-1 StudentPage, P6-2 InventoryPage, P6-3 ScanPage, P6-4 HomePage가 service-backed 실제 화면이다.
- HomePage가 typed selected profile/repository state, saved goals, shortage와 recent scan을 읽기 전용으로 표시한다.
- `confirmedStudentPlanningCurrent`가 repository current envelope를 planning current 입력으로 안전하게 변환한다.
- repository에 선택 프로필, confirmed students, inventory와 saved goals가 있고 student/inventory catalog API가 있다.
- 기존 `calculatePlan`은 gross totals, `calculateShortages`는 required/owned/shortage를 별도 의미로 반환한다.
- workflow에서 P6-1~P6-4는 `완료`, P6 전체는 `진행 중`, P6-5는 미완료다.
- 승인 시점 기준 Python 72 tests, Flutter 91 tests, analyze, Windows release, 실제 process E2E,
  3개 viewport, Almanac과 `git diff --check`가 통과했다.

이 승인본이 없으면 이전 단계를 추측해 재구성하거나 오래된 origin/main 위에서 작업하지 않는다.
`BLOCKED`로 보고하고 마스터에게 동일한 accepted P6-4 snapshot을 요청한다. 정확한 승인본이 있다면 그
상태만 local baseline commit으로 고정할 수 있으나 push하지 않는다. baseline ID와 승인 경로를
`verification.txt`에 기록한다. 기존 사용자 변경과 대상 경로가 겹치면 commit·stash·삭제하지 않고
`BLOCKED`로 보고한다.

## 고정된 P6-5 분석 범위

P6 workflow가 요구한 구현 전 지표·차트 목록을 다음과 같이 고정한다.

### 공통 범위

- 집계 범위는 `선택 프로필 전체`다. v6는 Student 탭의 filtered students를 사용했지만, v7에는 탭 간
  filter 공유 계약이 없으므로 P6-5에서 숨은 결합을 만들지 않는다.
- StudentPage의 검색·필터·정렬 상태를 읽거나 바꾸지 않는다. 정렬은 통계 표시만 바꾸며 분모를 바꾸지 않는다.
- 학생·인벤토리·계획의 3개 명시적 mode를 `SegmentedButton`, tab 또는 동등한 접근 가능한 control로 제공한다.
- 각 분포는 count, 명시적 denominator와 percent를 가진 immutable pure-Dart projection으로 만든다.
- 정렬은 기본 `count/value 내림차순 → normalized label/identity 오름차순`으로 결정적이어야 한다.

### 학생 mode

KPI:

- catalog 학생 수
- confirmed/owned 학생 수
- saved goal 학생 수와 catalog에 없는 orphan goal 수
- known level만을 분모로 한 평균 level과 known count
- known student_star만을 분모로 한 평균 star와 known count

고정 분포 selector:

- ownership: catalog ID가 repository confirmed state에 있으면 owned, 아니면 unowned
- current level bucket: `1–20`, `21–40`, `41–60`, `61–80`, `81–90`, `Unknown`
- current star: `1`~`5`, `Unknown`
- static metadata: `school`, `combat_class`, `attack_type`, `defense_type`, `role`

current level/star 분포는 confirmed 학생만 대상으로 하고 null/누락은 `Unknown`으로 센다. metadata 분포는
전체 catalog를 대상으로 하며 null/empty는 `(Missing)`으로 센다. repository에는 있지만 catalog에 없는
confirmed ID를 버리지 말고 별도 `Missing catalog metadata` 근거 목록과 count로 표시한다.

### 인벤토리 mode

KPI:

- catalog item 수
- snapshot identity 수
- known quantity item 수
- unknown quantity item 수
- explicit zero item 수와 positive quantity item 수
- catalog에 없는 snapshot identity 수

고정 분포:

- category별 catalog item count
- category별 known/unknown coverage count와 percent
- category를 찾을 수 없는 snapshot identity는 `(Missing category)`로 유지

서로 다른 resource의 quantity를 의미 없는 하나의 `총 보유량` KPI로 합치지 않는다. `quantity: null`과
snapshot 부재는 0이 아니다. stale/last-updated 시각은 backend가 제공하지 않으므로 만들지 않는다.

### 계획 mode

KPI와 분포:

- saved goal 수
- 기존 `calculatePlan`의 gross scalar totals: `credits`, `level_exp`, `equipment_exp`, `weapon_exp`
- gross material map을 category/key별로 보존한 ranked rows; 기존 map을 새 의미로 합치지 않음
- shortage row 수, positive shortage row 수, unresolved/unknown row 수, affected unique student 수
- category별 required/known-owned/positive-shortage를 서로 분리한 값과 unknown count
- positive shortage top-N resource rows: shortage 내림차순, `resource_key` tie-break, bounded 10

saved goal이 없으면 gross/shortage API를 호출하지 않는다. goal이 있으면 같은 immutable repository snapshot에서
`confirmedStudentPlanningCurrent`, saved goals, inventory를 두 기존 API에 전달한다. gross failure와 shortage
failure는 source별 partial error로 표시하고 성공한 다른 결과를 지우지 않는다.

## 범위와 데이터 소유권

### P6-5가 소유하는 것

- statistics pure projection/model과 결정적 집계·정렬·percent 계산
- service-backed `StatisticsPage`와 학생/인벤토리/계획 mode
- 선택 프로필 범위·revision·source 상태 표시와 refresh/re-entry
- 분포 선택, detail 근거 목록과 data-owner 탭 이동
- loading, empty, disconnected, partial error와 stale future protection
- Mock와 실제 process 집계 검증, responsive/accessibility test

### P6-5가 소유하지 않는 것

- repository mutation, plan save, inventory zero-fill 또는 candidate review/commit
- StudentPage filter state 공유나 통계 선택을 destination filter로 강제하는 새 handoff 계약
- 새 statistics wire protocol/schema, database table, history, timestamp 또는 analytics cache
- 계획 계산 공식 재구현, shortage와 gross totals 혼합
- v6 Qt/QML/PySide widget, painter 또는 sunburst code 복사
- 전술대항전, 설정, 통합 오류 처리 또는 P7 이후 기능

## 공통 불변식

- Flutter와 Python은 별도 process이며 versioned JSONL protocol만 사용한다.
- `../v6` runtime import와 Qt/QML/QWidget/Tk/PySide6 presentation code 복사를 금지한다.
- scanned current, static metadata, user goals, gross result, inventory shortage 다섯 bucket을 섞지 않는다.
- `backend/core/student_meta_data.py`를 통계 편의를 위해 광범위하게 hand-edit하지 않는다.
- missing, unknown, explicit zero와 empty result를 서로 구분한다.
- 평균은 알려진 값만 분모로 사용하고 `known/total`을 함께 표시한다. unknown을 0으로 넣지 않는다.
- percentage는 count의 명시적 denominator가 0이면 0 또는 `n/a`로 안전하게 표시하며 NaN/Infinity를 만들지 않는다.
- UI에 표시되는 label과 raw identity를 분리하고 같은 표시 이름이 있어도 stable ID/key로 집계한다.
- async refresh의 늦은 profile/catalog/state/gross/shortage 응답이 새 generation을 덮어쓰지 않는다.

## 구현 요구사항

### 1. Pure statistics projection

- Flutter UI와 분리된 immutable statistics model/helper를 추가한다. 입력 typed object를 mutate하지 않는다.
- distribution row는 최소 stable key, label, count/value, denominator와 percent를 가진다.
- duplicate catalog identity, repository-only identity, missing metadata, null field, zero denominator를 test한다.
- label이 같아도 identity가 다른 resource를 계산 중 합치지 않는다. 표시 group이 필요한 경우 raw identities를
  detail에 보존한다.
- chart package를 새로 추가하지 않는다. Flutter 기본 widget으로 accessible bar/list를 구현한다.
- v6 sunburst의 시각 알고리즘이나 PySide painter를 port하지 않는다.

### 2. StatisticsPage source orchestration

- `AppSection.statistics` placeholder를 실제 `StatisticsPage`로 교체한다.
- `RepositoryService` 부재, backend disconnected/connecting, no profile, profile/catalog/state loading·empty·error를
  각각 구분한다.
- selected profile은 stable ID로 찾고 repository state, student catalog, inventory catalog를 같은 generation에서
  로드한다. profile ID/revision과 선택된 scope를 화면에 표시한다.
- source별 성공값은 다른 source 실패 때문에 모두 사라지지 않는다. refresh와 홈/다른 탭에서 통계 재진입 시
  reload하며 dispose 뒤 setState/timer/future update를 막는다.

### 3. 학생 분석

- 위에 고정한 KPI와 selector만 구현한다. v6의 추가 rarity/position/weapon_type 등 미지원 metadata를 추측해
  새 계약으로 만들지 않는다.
- ownership은 catalog와 confirmed ID set의 관계이며 current value 유무만으로 owned를 추측하지 않는다.
- distribution row 선택 시 같은 화면 안에 원인 학생 ID/display name 목록을 보여 준다.
- `학생에서 확인` action은 StudentPage를 열되 P6-5에서 새 cross-tab filter handoff를 만들지 않는다.

### 4. 인벤토리 분석

- inventory snapshot identity는 `item_id ?? key`의 기존 repository 의미를 사용한다.
- catalog category와 stable resource identity를 조인하되 unknown catalog identity를 버리지 않는다.
- category distribution/detail에서 known, unknown, zero, positive를 분리한다.
- `인벤토리에서 확인` action은 InventoryPage를 열며 통계 화면이 quantity를 수정하지 않는다.

### 5. 계획·부족 분석

- saved goals가 있을 때만 `calculatePlan`과 `calculateShortages`를 호출한다.
- current/goals/inventory request가 PlanningPage·InventoryPage·HomePage와 같은 의미인지 exact request test로 고정한다.
- gross totals의 4 scalar와 material map은 기존 response key를 보존하고 unknown key를 조용히 숫자로 합치지 않는다.
- shortage required/owned/shortage/resolved/affected IDs를 유지한다. owned/shortage null은 `Unknown`으로 표시한다.
- gross 또는 shortage 부분 실패를 별도 retry 가능한 상태로 표시한다.
- `계획에서 확인`, `부족 상세`는 각각 PlanningPage와 InventoryPage로 이동한다.

### 6. Layout와 접근성

- `DiagonalSection`, 현재 glass/theme와 scrollable composition을 재사용한다. 한 section에 모든 chart를 압축하지 않는다.
- mode control, scope/source summary, KPI, distribution, detail/action을 목적별 부착 section으로 나눈다.
- bar의 의미를 색상만으로 전달하지 않고 label, count/value와 percent text/semantics를 함께 표시한다.
- 긴 profile/student/resource/category 이름, 많은 distribution row와 warning에도 action을 scroll로 접근할 수 있어야 한다.
- 1280×720, 1440×900, 1280×960에서 overflow가 없고 mode·selector·detail·data-owner action이 접근 가능해야 한다.

## 필수 테스트

최소 다음 자동 검증 source를 작성한다.

- pure projection의 stable sorting, denominator/percent, zero denominator와 input immutability
- full-profile scope가 StudentPage의 search/sort 상태와 결합되지 않음
- ownership, repository-only missing metadata, level/star known-average와 Unknown bucket
- school/combat_class/attack/defense/role `(Missing)` 분포와 detail identity 보존
- inventory catalog/snapshot join, known/unknown/zero/positive와 missing category
- goals empty에서 gross/shortage 호출 없음
- saved goals에서 exact current/goals/inventory request와 4 gross scalar/material maps
- shortage positive top-10, tie-break, required/owned/shortage 분리, unresolved/affected students
- gross 실패와 shortage 실패가 성공한 profile/catalog/state/다른 calculation을 지우지 않음
- disconnected/connecting, RepositoryService 부재, no profile, source별 loading/empty/error와 refresh recovery
- 느린 이전 generation 응답이 새 profile/refresh 결과를 덮어쓰지 않음
- Student/Inventory/Plan 세 mode와 detail → data-owner navigation
- MockAppService deterministic data/empty/unknown/partial-failure 흐름
- 실제 Dart ProcessAppService↔Python repository/catalog/gross/shortage E2E
- P6-1~P6-4, planning/repository/scanner 기존 회귀
- 긴 문자열, 대용량 distribution과 1280×720·1440×900·1280×960 overflow/accessibility

실제 게임 창 smoke는 P6-5 필수 조건이 아니다. 실행하지 않았다면 `NOT_VERIFIED`로 기록하고 fixture/Mock
결과를 실제 게임 검증으로 표현하지 않는다.

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
docs/migration/p6-5-statistics-integration/
├─ input.md
├─ output.md
└─ artifacts/
   ├─ p6-5-statistics-integration.patch
   └─ verification.txt
```

patch는 승인된 P6-4 snapshot 위의 P6-5 단일 증분이어야 한다. 다음을 포함하지 않는다.

- `input.md`, `slave-execution-prompt.md`, `output.md`, `artifacts/`
- P6-4 또는 이전 patch와 handoff package
- P6-6/P6-7 구현, 새 protocol/backend statistics storage
- build/cache/log/profile/database/scan result/debug crop/adaptive sample
- v6 source, Qt/PySide presentation code, recognition template 또는 runtime asset 복제본

모든 patch path는 `BA Planner/v7/...`여야 한다. `verification.txt`에는 baseline commit, accepted P6-4 gate,
dirty-path 판단, 지표/분모/unknown 결정, 실행 명령, test 수와 결과, master 전용 gate를 기록한다.

## 완료 조건

다음을 모두 만족할 때만 `COMPLETED`로 보고한다.

- Statistics placeholder가 선택 프로필 전체를 읽는 service-backed 실제 화면으로 교체되었다.
- 학생·인벤토리·계획 3개 mode와 이 문서에 고정된 KPI/분포가 typed source에서 계산된다.
- five bucket, missing/unknown/zero, denominator와 gross/shortage 의미가 보존된다.
- detail 원인 목록과 data-owner navigation이 있으며 통계 화면에서 mutation하지 않는다.
- loading, empty, disconnected, partial error, refresh/re-entry와 stale generation이 test source로 보호된다.
- pure projection, Mock, 실제 process, 3개 viewport와 기존 P6 회귀 test source가 존재한다.
- 가능한 Python 회귀와 patch 무결성 검사가 통과한다.
- 두 artifact가 `artifacts/` 아래에 있고 `output.md`에 실제 byte size와 SHA-256이 기록된다.

슬레이브의 `COMPLETED`는 P6-5 구현과 산출물 준비 완료만 뜻한다. 마스터가 모든 `MASTER_REQUIRED` gate를
직접 통과시키기 전에는 P6-5 완료를 주장하지 않는다. P6-5가 승인되어도 P6-6·P6-7과 최종 통합 흐름이
남으므로 P6 전체 완료를 주장하지 않는다.
