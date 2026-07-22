# P6-2 인벤토리 실제 데이터 통합

## 작업 ID

```text
ba-planner-v7-p6-2-inventory-integration
```

## 목표

P0~P5와 마스터가 최종 승인한 P6-1 경계를 유지하면서 Flutter의 인벤토리 탭
placeholder를 실제 catalog·repository·planning·scanner 데이터 화면으로 교체한다. 이
작업은 P6 전체가 아니라 두 번째 수직 슬라이스다.

완성된 인벤토리 탭에서 사용자는 선택된 프로필을 기준으로 다음 작업을 할 수 있어야 한다.

1. 장비와 아이템 catalog를 category/profile 순서로 탐색한다.
2. 이름·ID를 검색하고 category·데이터 상태로 필터하며 안정적으로 정렬한다.
3. 현재 보유량과 데이터 없음/미스캔 상태를 구분해 조회·수정·저장한다.
4. 저장된 계획의 총 필요량, 보유량과 부족량을 서로 다른 값으로 확인한다.
5. 부족 재화가 어떤 계획 학생에게 필요한지 확인하고 계획 탭으로 이동한다.
6. 전달된 inventory scanner candidate가 있으면 기존 snapshot과 비교한 뒤 명시적으로
   확정하거나 보류한다.

## 먼저 읽을 문서

- `README.md`
- `AGENTS.md`
- `docs/migration/v6-knowledge-baseline.md`
- `almanac/workflows/p0-p6-workflow.md`의 P6 절
- `almanac/workflows/p0-p6-workflow-status.md`의 P5, P6 UX, P6-1과 P6-2 절
- `almanac/design/frontend-section-direction-and-user-flows.md`의 공통 규칙과 인벤토리 탭 절
- `almanac/design/responsive-diagonal-layout-policy.md`
- `almanac/workflows/slave-artifact-handoff.md`
- `almanac/workflows/cross-pc-slave-handoff.md`
- `../v6/almanac/flows/inventory-scan.md`
- `../v6/docs/inventory_scan_algorithm.md`
- `../v6/docs/inventory_sorting.md`
- `../v6/core/inventory_profiles.py`

문서와 코드가 다르면 현재 v7 코드와 검증 결과를 우선하고 차이를 `output.md`에 기록한다.

## 승인된 UX 범위

- 기본 진입은 `보유량 목록`이다. `부족 진단`은 동일 탭의 별도 기능 섹션으로 제공한다.
- 부족량은 선택 프로필에 저장된 현재 계획만 대상으로 한다. v6의 `전체 육성 부족`,
  장기 pressure, 추천·랭킹·학교 위험 분석은 P6-2 범위가 아니다.
- 스캔 비교는 이미 전달되었거나 현재 service에서 조회 가능한 inventory candidate만
  처리한다. target 선택, session 시작, 진행률, 취소, 재시도와 최근 session UI는 P6-3이
  소유한다.
- 계획 목표를 바꾸는 행동은 계획 탭으로 이동한다. 인벤토리 탭이 goal을 직접 수정하지
  않는다.
- 정확한 최종 Wide/Standard/Compact 계약과 제품 최소 창 크기를 새로 확정하지 않는다.
  P6-1의 검증된 `DiagonalSection`과 현재 공용 shell 규칙을 재사용한다.

## 데이터 불변식

- Flutter와 Python은 별도 process이며 versioned JSONL protocol만 사용한다.
- v6 Python module을 runtime import하지 않는다.
- Qt, QML, QWidget, Tkinter, PySide6 코드를 복사하지 않는다.
- 정적 inventory metadata/order, 확정 snapshot, 사용자 goal, 총 필요량과 부족량을 서로
  다른 DTO·필드·계산 단계로 유지한다.
- `calculate_goal_cost()`와 `calculate_plan_totals()`은 보유량 차감 전 총 필요량이라는
  기존 의미를 유지한다. shortage를 기존 totals에 덮어쓰지 않는다.
- catalog에 항목이 있지만 repository snapshot에 없다는 사실만으로 보유량 0을 만들지
  않는다. 명시적으로 저장된 `quantity: "0"` 또는 scanner/profile-order 계약이 생성한
  zero-fill 항목만 실제 0이다. 그 외는 `unknown`/미스캔이다.
- name-only entry를 추측으로 item ID와 결합하지 않는다. identity 우선순위는 기존
  repository parity와 같이 명시적 `item_id`, canonical `key`, 검증된 alias fixture만
  사용한다.
- 낮은 confidence candidate는 review와 commit 없이 repository inventory를 덮어쓰지 않는다.
- repository mutation은 complete inventory bucket, expected revision과 idempotency key를
  사용한다. 다른 inventory entry, students와 goals를 잃지 않는다.
- P5 production recognition coverage는 inventory icon 2개의 제한된 smoke coverage다.
  catalog 규모와 실제 scanner recognition coverage를 같은 의미로 보고하지 않는다.
- recognition template은 Flutter UI asset으로 복사하지 않는다.

## 구현 요구사항

### 1. Inventory catalog와 v6 order 특성화

- v6 `inventory_profiles.py`를 runtime import하거나 파일 전체를 복사하기 전에, P6-2에
  필요한 category/profile ID, item identity, display name, order index와 zero-fill 의미를
  고정한 parity fixture를 먼저 만든다.
- fixture는 최소한 장비, 활동 보고서, 기술 노트, 전술 교육 BD, 오파츠와 학생 엘레프의
  대표 순서, name-only 비추론, explicit zero, unknown/missing과 중복 identity를 포함한다.
- v7에는 UI·scanner·repository를 import하지 않는 최소 data-only catalog/order module을
  둔다. 기존 `equipment_items.py`, student metadata와 planning material source를 재사용한다.
- `backend/core/student_meta_data.py` generated data를 광범위하게 손수 수정하지 않는다.
- versioned application protocol에 `planning.inventory.catalog`와 엄격한 response DTO를
  추가한다. schema, canonical fixture, Python validation/handler, Dart validation/client,
  Mock와 contract test를 함께 갱신한다.
- catalog row는 최소 `resource_key`, nullable `item_id`, `display_name`, `category`,
  `profile_id`, `order_index`와 zero-fill 가능 여부를 명시한다. 내부 Python 객체나 asset
  절대경로를 노출하지 않는다.

### 2. 별도 shortage derivation 계약

- 총 필요량 계산을 수정하지 않고, current students + saved goals + inventory snapshot에서
  plan shortage를 파생하는 별도 headless module과 protocol method를 만든다.
- method 이름은 `planning.plan.shortages`를 사용하고 request/response schema와 fixture,
  Python/Dart contract test를 추가한다.
- response의 각 row는 최소 resource identity, display name/category, `required`, nullable
  `owned`, nullable `shortage`, `affected_student_ids`를 가진다.
- `owned`가 unknown이면 `shortage`도 unknown이다. `max(0, required - owned)`는 owned가
  명시적으로 알려진 경우에만 계산한다.
- 영향 학생은 같은 기존 per-student gross calculation 결과에서 파생한다. UI나 필터 상태를
  backend 계산 입력으로 사용하지 않는다.
- exact item ID/key 매핑이 불가능한 총 필요량은 버리거나 임의 매핑하지 말고 unresolved
  row 또는 warning으로 보존한다.
- scalar credit/EXP와 scanner inventory item의 identity가 정해지지 않았다면 억지로
  차감하지 않는다. fixture가 보장하는 resource만 shortage로 계산한다.

### 3. Repository inventory mutation

- 기존 `repository.inventory.update` wire 계약을 재사용한다.
- Dart `RepositoryInventoryState`에 검증된 constructor/serialization 경계를 추가하고,
  `RepositoryService`, `ProcessAppService`, `MockAppService`에 typed save method를 제공한다.
- 수동 수정은 non-negative canonical integer 문자열만 저장한다. 빈 값은 0이 아니라
  unknown/remove 판단을 명시적으로 적용한다.
- 한 항목을 수정해도 snapshot의 다른 항목·profile/order metadata와 students/goals가
  보존되어야 한다.
- 저장 성공 후 새 revision과 reload 결과가 일치해야 한다. revision conflict 또는 backend
  오류에서는 사용자의 draft를 보존하고 reload 행동을 제공한다.

### 4. InventoryPage

- `AppSection.inventory`의 `SectionPlaceholderPage`를 실제 `InventoryPage`로 교체한다.
- 최소 기능 그룹은 `보유량 탐색`, `보유량 조회·수정`, `계획 부족 분석`, 조건부
  `스캔 결과 비교·확정`이다.
- 선택 전, loading, empty catalog, empty snapshot, error, disconnected, unknown quantity,
  missing metadata와 review-required 상태를 명시적으로 처리한다.
- 장비/아이템 mode, category filter, 이름·ID 검색, catalog order/name/quantity/shortage
  정렬을 제공한다. 정렬은 Widget 순서에 의존하지 않고 stable tie-breaker를 가진다.
- catalog에만 있는 row는 unknown으로 보이며 zero로 렌더링하지 않는다. explicit zero와
  unknown은 label, semantics와 test에서 구분한다.
- 상세에는 identity/category/profile, 현재 보유량과 provenance가 있다면 갱신 근거,
  plan required/owned/shortage와 affected students를 분리해 표시한다.
- 부족 분석은 저장된 goal이 없거나 inventory가 unknown인 경우 계산 불가 이유를 보여준다.
- 계획으로 이동 및 스캔 탭으로 이동 callback을 AppShell에 연결하되 다른 placeholder를
  교체하지 않는다.
- P6-1의 `DiagonalSection`을 재사용하고 내부 Material 경계, dropdown expanded/ellipsis,
  lazy scroll action과 viewport 회귀를 보존한다.

### 5. Inventory scanner candidate 경계

- P5의 typed `ScannerCandidate`, review와 commit method를 재사용한다.
- 기존 snapshot과 후보의 added/changed/missing/unknown row를 구분한다. 누락을 자동 0으로
  바꾸지 않는다.
- candidate evidence, confidence와 review-required 여부를 표시한다.
- Hold는 repository를 바꾸지 않는다. Approve는 review가 필요한 경우 review를 먼저 수행한
  뒤 expected repository revision으로 commit한다.
- stale generation/candidate revision/repository revision conflict와 idempotent retry를
  test한다.

## 테스트 요구사항

최소한 다음 자동 검증을 작성한다.

- v6 대표 order/identity/zero-fill parity fixture와 v7 catalog 결과 일치
- Python/Dart inventory catalog·shortage schema와 malformed payload 거부
- 실제 Python stdio process의 catalog와 shortage 조회
- 총 필요량 계산 결과 불변 및 shortage 별도 파생
- explicit zero, unknown, name-only, unresolved identity와 negative quantity 거부
- 실제/Mock inventory save, complete bucket 보존, revision conflict draft 보존과 restart 복원
- 장비/아이템·category·검색·정렬, 긴 이름, 대용량 catalog, 누락 metadata
- loading, empty catalog/snapshot, error, disconnected와 saved goal 없음
- required/owned/shortage/affected students 구분과 계획 탭 인계
- inventory candidate hold/approve/stale/conflict와 missing→zero 금지
- 1280×720, 1440×900, 1280×960에서 overflow와 핵심 행동 접근 가능성
- 기존 P6-1 StudentPage, planning, repository와 scanner 회귀 없음

## 슬레이브 환경 제약

현재 슬레이브 PC에는 Flutter/Dart SDK와 CodeAlmanac CLI가 없다. 이를 설치하거나 공간을
확보하려고 SDK, cache, repository 또는 사용자 파일을 삭제하지 않는다.

- Python 3.11 test, JSON/schema/fixture 검사, 정적 `rg`, `git diff --check`, patch 생성은
  슬레이브가 수행한다.
- Dart/Flutter source와 test는 반드시 작성한다.
- 실행할 수 없는 Flutter/Dart/analyze/release와 Almanac 검증은 성공으로 주장하지 않고
  `NOT_VERIFIED` 및 `MASTER_REQUIRED:`로 기록한다.
- SDK/CLI 부재만으로 작업 전체를 `BLOCKED` 처리하지 않는다.

## 필수 결과물

```text
docs/migration/p6-2-inventory-integration/
├─ input.md
├─ output.md
└─ artifacts/
   ├─ p6-2-inventory-integration.patch
   └─ verification.txt
```

patch는 마스터 승인된 P6-1 baseline 위의 P6-2 단일 증분이어야 한다. 다음을 포함하지 않는다.

- `input.md`, `slave-execution-prompt.md`, `output.md`, `artifacts/`
- P6-1 또는 이전 단계 patch와 handoff package
- build/cache/log/profile/database/scan result/debug crop/adaptive sample
- v6 source 복사본

모든 patch path는 `BA Planner/v7/...`여야 한다. `verification.txt`에는 baseline commit,
dirty path 판단, 실행한 명령, test 수와 결과, 실행하지 못한 master gate를 기록한다.

## 완료 조건

다음 조건을 모두 만족할 때만 `COMPLETED`로 보고한다.

- inventory placeholder가 실제 service-backed `InventoryPage`로 교체되었다.
- catalog, inventory save, plan shortage와 candidate review 경계가 typed service를 통과한다.
- unknown과 explicit zero, gross required와 shortage가 자동 test로 분리되어 있다.
- 필수 Python 검증과 patch 무결성 검증이 통과했다.
- Flutter/Dart source와 test가 결과 patch에 존재한다.
- 모든 결과물이 `artifacts/` 아래에 있고 `output.md`에 실제 byte size와 SHA-256이 있다.

슬레이브의 `COMPLETED`는 P6-2 구현·산출물 준비 완료를 뜻할 뿐이다. 마스터가 patch와
MASTER_REQUIRED gate를 직접 검증하기 전에는 P6-2 또는 P6 전체 완료를 주장하지 않는다.
