# P6-1 학생 실제 데이터 통합

## 작업 ID

```text
ba-planner-v7-p6-1-student-integration
```

## 목표

P0~P5에서 승인된 planning, repository, scanner 경계를 유지하면서 Flutter의 학생 탭
placeholder를 실제 학생 데이터 화면으로 교체한다. 이 작업은 P6 전체가 아니라 첫 번째
수직 슬라이스다.

완성된 학생 탭에서 사용자는 선택된 프로필을 기준으로 다음 작업을 할 수 있어야 한다.

1. 정적 metadata 학생 목록을 조회한다.
2. 이름·ID를 검색하고 승인된 metadata/current-state 필드로 필터·정렬한다.
3. 학생을 선택해 정적 metadata와 확정된 현재 육성 상태를 서로 구분해 확인한다.
4. 허용된 현재값을 수정해 repository revision/idempotency 계약으로 저장한다.
5. 학생을 계획 탭으로 보내 P2의 기존 목표 편집 흐름에 추가한다.
6. 해당 학생에 연결된 review-required scanner candidate가 전달된 경우 기존 확정값과
   후보값을 비교하고, P5의 review/commit API를 통해 명시적으로 확정하거나 보류한다.

## 먼저 읽을 문서

- `README.md`
- `AGENTS.md`
- `docs/migration/v6-knowledge-baseline.md`
- `almanac/workflows/p0-p6-workflow.md`의 P6 절
- `almanac/workflows/p0-p6-workflow-status.md`의 P5, P6 UX, P6 절
- `almanac/design/frontend-section-direction-and-user-flows.md`의 공통 규칙과 학생 탭 절
- `almanac/design/responsive-diagonal-layout-policy.md`
- `almanac/workflows/slave-artifact-handoff.md`
- `almanac/workflows/cross-pc-slave-handoff.md`
- `../v6/almanac/flows/student-scan.md`
- `../v6/STUDENT_PLANNER_HANDOFF.md`

문서와 코드가 다르면 현재 v7 코드와 검증 결과를 우선하고 차이를 `output.md`에 기록한다.

## 승인된 경계

- Flutter와 Python은 별도 process이며 versioned JSONL protocol만 사용한다.
- v6 Python module을 runtime import하지 않는다.
- Qt, QML, QWidget, Tkinter, PySide6 코드를 복사하지 않는다.
- 정적 metadata, 확정된 현재 상태, 계획 목표, 총 필요량, inventory 기반 부족량을 합치지
  않는다.
- `backend/core/student_meta_data.py`는 generated data이므로 광범위하게 직접 수정하지 않는다.
- 낮은 confidence candidate는 review와 commit 없이 repository 현재값을 덮어쓰지 않는다.
- repository mutation은 expected revision과 idempotency key를 사용한다. revision conflict를
  성공으로 숨기지 말고 reload/retry 가능한 UI 상태로 표시한다.
- 학생 화면에서 scanner session을 새로 시작하는 전체 UI는 P6-3 범위다. P6-1은 이미
  전달되었거나 현재 service에서 조회 가능한 student candidate의 검토·확정 경계만 잇는다.
- 계획 preset의 새 저장 모델이나 protocol을 추측해 만들지 않는다. `계획에 추가`는 선택한
  학생 ID와 현재값을 P2 `PlanningPage`에 명시적으로 전달하고 기존 목표 편집 흐름을 연다.
- 전술대항전, 통계, 인벤토리, 홈, 스캔, 설정 placeholder는 이 작업에서 교체하지 않는다.

## 구현 요구사항

### 1. Student catalog protocol

- 단일 ID 조회만 반복 호출하지 말고 정적 student catalog를 한 번에 가져오는 명시적
  planning protocol method를 추가한다.
- request/response schema, canonical fixture, Python validation/handler, Dart validation/client,
  Mock와 contract test를 함께 갱신한다.
- 응답 DTO는 UI에 필요한 metadata만 직렬화하며 generated 내부 객체나 Python 전용 타입을
  노출하지 않는다.
- 안정적인 기본 정렬과 누락 metadata fallback을 정의한다. 긴 한국어 이름과 미등록 ID가
  화면을 깨뜨리지 않아야 한다.

### 2. Repository student mutation

- 현재 `repository.students.update` 계약을 재사용한다.
- Dart `RepositoryService`, `ProcessAppService`, `MockAppService`에 필요한 typed method를
  추가하고 기존 DTO validator를 우회하지 않는다.
- 한 학생을 수정해도 다른 학생, inventory와 goals가 사라지지 않아야 한다.
- 저장 성공 후 새 revision과 화면 상태가 일치해야 한다. 오류나 conflict 시 사용자의
  draft를 보존한다.

### 3. StudentPage

- `AppSection.students`의 `SectionPlaceholderPage`를 실제 `StudentPage`로 교체한다.
- 최소 기능 그룹은 `학생 탐색`, `현재 상태 확인·수정`, `계획으로 보내기`, 조건부
  `스캔 후보 검토`다.
- 선택 전, loading, empty, error, disconnected, missing metadata, review-required 상태를
  명시적으로 처리한다.
- 검색은 이름·ID와 기존 search tag 계약을 사용한다. 필터와 정렬은 static metadata와
  current state의 출처가 UI에서 혼동되지 않게 한다.
- 편집 가능한 현재 필드는 repository DTO 허용 필드와 값 범위를 따른다. 정적 metadata나
  target field를 현재값 편집기로 저장하지 않는다.
- UI에는 80도 사선, 글라스, 둥근 실루엣, 부착면과 모션의 확정 규칙을 적용한다. 다만
  아직 사용자 승인되지 않은 Wide/Standard/Compact 배치나 임의 breakpoint를 최종 계약처럼
  새로 확정하지 않는다. 기존 공용 geometry가 있으면 재사용하고, 없으면 이 화면에만
  중복 path 수학을 만들지 말고 최소 공용 primitive와 test를 추가한다.

### 4. 계획 탭 인계

- 학생 탭의 명시적 행동으로 계획 탭을 연다.
- 동일 학생 중복 추가, 이미 저장된 goal, current state 없음과 metadata 없음 사례를
  결정론적으로 처리한다.
- 탭 전환 후 선택 학생이 실제 PlanningPage draft에 존재해야 하며, 사용자가 목표를
  수정하기 전까지 current/target 의미를 바꾸지 않는다.

### 5. Scanner candidate 경계

- P5의 typed `ScannerCandidate`, review와 commit method를 재사용한다.
- 기존 확정값, 후보값, confidence/evidence, review-required 여부를 구분한다.
- approve 전 commit 금지, stale generation/revision과 repository revision conflict 처리,
  보류 후 현재값 불변을 test한다.
- P6-3이 소유할 target 선택, 진행률, 취소, 재시도와 최근 session 목록 UI를 이 화면에
  복제하지 않는다.

## 테스트 요구사항

최소한 다음 자동 검증을 작성한다.

- Python/Dart catalog contract와 malformed payload 거부
- 실제 Python process의 catalog 조회
- 실제/Mock repository state 병합과 단일 학생 저장
- 검색·필터·정렬, 긴 이름, 대용량 목록, 누락 metadata
- loading, empty, error, disconnected와 revision conflict에서 draft 보존
- 현재값과 정적 metadata/goal 분리
- 계획 탭 인계와 중복 학생 처리
- review-required candidate의 approve/hold/stale/conflict
- 1280×720, 1440×900, 1280×960에서 overflow와 핵심 행동 접근 가능성
- 기존 planning, repository, scanner contract와 Widget test 회귀 없음

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
docs/migration/p6-1-student-integration/
├─ input.md
├─ output.md
└─ artifacts/
   ├─ p6-1-student-integration.patch
   └─ verification.txt
```

patch는 P5가 완전히 적용된 baseline 위의 P6-1 단일 증분이어야 한다. 다음을 포함하지 않는다.

- `input.md`, `slave-execution-prompt.md`, `output.md`, `artifacts/`
- 이전 P5 patch나 handoff package
- build/cache/log/profile/database/scan result/debug crop/adaptive sample
- v6 source 복사본

모든 patch path는 `BA Planner/v7/...`여야 한다. `verification.txt`에는 baseline commit,
dirty path 판단, 실행한 명령, test 수와 결과, 실행하지 못한 master gate를 기록한다.

## 완료 조건

다음 조건을 모두 만족할 때만 `COMPLETED`로 보고한다.

- 학생 placeholder가 실제 service-backed `StudentPage`로 교체되었다.
- catalog, repository current state, 계획 인계와 candidate review 경계가 typed service를
  통과한다.
- 필수 Python 검증과 patch 무결성 검증이 통과했다.
- Flutter/Dart source와 test가 결과 patch에 존재한다.
- 모든 결과물이 `artifacts/` 아래에 있고 `output.md`에 실제 byte size와 SHA-256이 있다.

슬레이브의 `COMPLETED`는 P6-1 구현·산출물 준비 완료를 뜻할 뿐이다. 마스터가 patch와
MASTER_REQUIRED gate를 직접 검증하기 전에는 P6-1 또는 P6 전체 완료를 주장하지 않는다.
