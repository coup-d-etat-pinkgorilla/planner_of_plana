# P5 작업 지시 — Scanner/Matcher session protocol과 backend

## 작업 정보

- 작업 ID: `ba-planner-v7-p5-scanner-matcher`
- 저장소: 슬레이브 PC의 BA Planner v7 저장소 루트
- 작업 디렉터리: `<SLAVE_REPOSITORY_ROOT>\docs\migration\p5-scanner-matcher`
- 기준 단계: P0·P1·P2·P3·P4 완료 baseline 위에서 P5 구현
- patch 성격: 승인된 P4 위의 단일 P5 증분
- 실행 환경: Windows, Python 3.11. 슬레이브에는 Flutter/Dart SDK와 CodeAlmanac CLI가 없음
- 인계 환경: 슬레이브와 마스터는 서로 다른 PC이며 파일시스템을 공유하지 않음

## 선행 단계 완료 선언

마스터는 `almanac/workflows/p0-p6-workflow-status.md`에서 P4를 최종 `완료`로 승인했다.
P4 원본과 follow-up-1·2·3의 인계 결과 및 마스터 직접 보완을 합친 현재 작업 트리가 P5의
유일한 승인 baseline이다. `p4-repository-persistence-followup-4/input.md`와 실행 프롬프트는
당시 남은 gate를 설명하는 이력 문서이며, 슬레이브가 다시 실행하거나 별도 P4 결과를
기다려야 하는 미완료 작업이 아니다.

따라서 슬레이브는 P4를 구현·보완·재판정하지 않는다. 아래 P4 baseline gate는 선행 완료를
뒤집기 위한 심사가 아니라 전달된 작업 트리가 마스터 승인 상태와 같은지 확인하는 무결성
검사다. gate가 다르면 P4를 고치지 말고 baseline 불일치로 `BLOCKED`를 보고한다.

## 슬레이브 도구 제한과 검증 책임

슬레이브 PC는 저장 공간 제약으로 Flutter/Dart SDK를 설치·사용하지 않으며 CodeAlmanac
CLI도 지원되지 않는다. 이 세 도구의 부재는 P5 구현·patch·인계의 차단 사유가 아니다.
슬레이브는 SDK 설치나 공간 확보를 위한 파일 삭제를 시도하지 않는다.

슬레이브는 Python backend, schema/fixture, Dart/Flutter source와 test, 문서와 asset manifest를
작성한다. Python 3.11 test, 정적 검색, JSON/asset/hash 검사, `git diff --check`, patch 검사와
cross-PC 패키징을 수행한다. Dart/Flutter source는 기존 코드와 fixture를 근거로 작성하되
실행 통과를 주장하지 않는다.

다음은 인계 후 마스터가 반드시 실행할 `MASTER_REQUIRED` gate다.

- Dart scanner fixture/validator와 client test
- Flutter 전체 test와 `flutter analyze`
- 실제 Dart `ProcessAppService` ↔ Python scanner event E2E
- Windows release build
- `codealmanac validate`와 `codealmanac health`

위 항목은 `verification.txt`와 `output.md`에서 `NOT_VERIFIED` 및
`MASTER_REQUIRED: <정확한 명령과 확인 항목>`으로 기록한다. 이 상태에서도 슬레이브 범위의
구현·Python 검증·산출물 패키징이 완료되면 `TASK_OUTPUT_READY status: COMPLETED`로 인계할 수
있다. 이는 P5 단계 완료가 아니라 마스터 검증 대기 상태다.

## 목표

v6의 capture·scanner·matcher 동작을 Qt/Tk callback과 repository 저장에서 분리하여,
Flutter 없이도 실행·검증할 수 있는 versioned scanner session application service로 옮긴다.
학생과 인벤토리 scan은 구조화된 event와 검토 가능한 candidate를 생성하고, 사용자가
명시적으로 수정·확정한 결과만 P4 repository에 반영한다.

P5는 실제 scanner backend와 typed protocol/client 경계를 완성하는 단계다. 스캔 탭의
production 화면 구성과 다른 기본 탭 통합은 P6에 남긴다.

## 작업 전 필수 확인

다음 파일을 UTF-8로 처음부터 끝까지 읽는다. 문서와 코드가 다르면 현재 코드와 실행
결과를 우선하고 차이를 `output.md`에 기록한다.

1. `AGENTS.md`, `README.md`
2. `almanac/workflows/p0-p6-workflow-status.md`
3. `almanac/workflows/p0-p6-workflow.md`의 공통 불변식과 P4·P5 절
4. `almanac/architecture/runtime-boundaries.md`
5. `almanac/workflows/slave-artifact-handoff.md`
6. `almanac/workflows/cross-pc-slave-handoff.md`
7. `docs/migration/v6-knowledge-baseline.md`
8. `docs/migration/p3-repository-dto/repository-characterization.md`
9. `docs/migration/p3-repository-dto/repository-protocol-draft.md`
10. `docs/migration/p4-repository-persistence/input.md`
11. `docs/migration/p4-repository-persistence/repository-storage.md`
12. `contracts/README.md`, 공통 envelope와 planning/repository schema·fixture
13. `backend/core/application_protocol_v1.py`, `backend_process.py`, `stdio_server.py`
14. `backend/core/repository_dto.py`, `repository_protocol_v1.py`, `repository_store.py`
15. `frontend/lib/services/backend_process.dart`, `planning_protocol_client.dart`,
    `process_app_service.dart`, `repository_service.dart`, `app_service.dart`
16. 관련 Python·Dart contract/process/repository test

v6 참조 저장소가 `<SLAVE_REPOSITORY_ROOT>\..\v6`에 있으면 다음 문서와 source를
실제 호출자까지 `rg`로 조사한다.

- `../v6/almanac/flows/student-scan.md`
- `../v6/almanac/flows/inventory-scan.md`
- `../v6/almanac/architecture/runtime-boundaries.md`
- `../v6/almanac/decisions/data-bucket-separation.md`
- `../v6/almanac/gotchas/large-module-change-safety.md`
- `../v6/docs/inventory_scan_algorithm.md`
- `../v6/docs/inventory_sorting.md`
- `../v6/docs/student_scan_status_messages.md`
- `../v6/core/scanner.py`, `scanner_components/`, `scanner_shared.py`, `scan_status.py`
- `../v6/core/capture.py`, `matcher.py`, `inventory_grid_matcher.py`,
  `inventory_slot_count_matcher.py`, `inventory_count_matcher.py`, `rescan.py`
- scanner를 생성·중단하고 callback을 소비하며 결과를 저장하는 `main.py`와 repository 호출부
- `../v6/regions/`, `../v6/templates/` 및 계정별 학습 sample 경로를 정하는 코드
- 관련 v6 scanner/matcher/capture/repository test

조사 결과는 `docs/migration/p5-scanner-matcher/scanner-characterization.md`에 남긴다. 최소한
다음을 표로 기록한다.

- 학생/인벤토리별 entrypoint, 호출자, thread/task 소유자와 callback
- 캡처 target과 window 입력, ROI, matcher, template/region 경로 의존성
- 취소 확인 지점, partial result/autosave, retry와 terminal 조건
- status/progress/candidate 생성 순서와 confidence 근거
- scanner DTO에서 P3 DTO 및 P4 commit으로 가는 field mapping
- profile별 adaptive sample의 읽기/쓰기 주체와 신뢰 조건
- Windows API, Pillow/OpenCV/numpy 등 runtime dependency와 배포 필요 파일
- 그대로 이전, adapter로 격리, fixture로 고정, P5 제외로 분류한 항목과 근거

v6가 없거나 실제 scanner 동작을 확인할 수 없으면 추측으로 대체하지 않는다. 조사 가능한
계약·fixture·headless adapter 작업은 계속하되 실제 capture/matcher parity 항목은
`NOT_VERIFIED`로 기록한다. P5 완료 조건을 충족할 수 없으면 `BLOCKED`로 보고한다.

## P4 승인 baseline — 변경 전 필수 gate

P5 구현 전에 현재 tree에서 슬레이브가 실행 가능한 gate를 재현한다.

1. repository fixture version 1, 40 cases(valid 14, invalid 26)
2. P3 repository parity 10 tests 통과
3. P3/P4 집중 Python 23 tests 및 전체 Python 40 tests 통과
4. `git diff --check` 통과
5. confirmed current, inventory와 goal은 typed repository state이며 Flutter가 저장 파일이나
   SQLite를 직접 읽지 않음
6. planning/repository runtime에서 `../v6`, scanner 또는 Qt/Tk/PySide6 import 0건
7. 실제 사용자 profile/DB/home storage를 test에서 사용하지 않음

Flutter 43 tests, `flutter analyze`, Windows release, CodeAlmanac와 실제 Dart-launched Python
restart E2E는 마스터가 이미 승인한 P4 완료 근거로 읽고 슬레이브에서 재실행하지 않는다.
관련 source/test가 승인 tree에 존재하는지는 정적으로 확인하고 `MASTER_REQUIRED`로 기록한다.

슬레이브 실행 가능 gate의 수치나 동작이 다르면 누락된 선행 patch를 임의 재구성하거나 P4
의미를 바꾸어 맞추지 않는다. 현재 commit/diff, 명령, 기대값과 실제값을 기록하고 안전하게
계속할 수 없으면 구현을 시작하지 말고 `TASK_OUTPUT_BLOCKED`로 반환한다. Flutter/Dart SDK와
CodeAlmanac CLI 부재 자체는 이 불일치에 포함하지 않는다.

## 공통 불변식

1. 스캔된 current candidate, 정적 metadata, 사용자 goal, 보유량 차감 전 총 계산 결과,
   inventory 기반 shortage를 서로 다른 DTO·field·계산 단계로 유지한다.
2. scanner candidate는 repository의 confirmed current가 아니다.
3. 낮은 confidence, uncertain, failed 또는 누락 field를 사용자 검토 없이 자동 확정하지 않는다.
4. candidate 생성과 repository commit은 서로 다른 protocol method와 service operation이다.
5. repository만 profile JSON/SQLite 병합과 영속화를 소유한다.
6. Flutter는 scanner template, region, crop, profile 파일 또는 DB를 직접 읽지 않는다.
7. scanner status는 versioned event 계약이며 stdout 로그 문자열을 파싱하지 않는다.
8. runtime UI asset과 recognition template/region/sample을 서로 다른 경로와 manifest로 배포한다.
9. `../v6`는 조사와 fixture 생성에만 사용하며 runtime import하지 않는다.
10. Qt/QML/QWidget/Tk/PySide6 presentation 및 callback orchestration 코드를 복사하지 않는다.

## 필수 구현

### 1. Scanner protocol v1 schema와 공용 fixture

production scanner 코드를 옮기기 전에 `contracts/`에 scanner protocol v1의 method별
request/response/event JSON Schema와 Python·Dart가 함께 소비하는 fixture를 만든다. 기존
공통 envelope의 `protocol: 1`, request ID와 method correlation을 유지하고 `type: "event"`를
실제 계약으로 확정한다. planning/repository schema와 fixture를 깨지 않는다.

method 이름은 일관된 `scanner.*` namespace로 정한다. 최소 use case는 다음과 같다.

- capture target 목록 및 진단
- 학생 또는 인벤토리 session start
- session cancel
- session 상태 또는 누락 event 복구를 위한 snapshot 조회
- review 대기 candidate 조회
- candidate 수정/검증
- 명시적 repository commit
- recognition asset manifest/version 및 readiness 진단

event는 최소 다음 정보를 strict payload로 가진다.

- `session_id`, 증가하는 `generation`, session 안에서 단조 증가하는 `sequence`
- `scan_kind`: student 또는 inventory
- 구조화된 `phase`, `progress`, `candidate`, `diagnostic`, `terminal` event 종류
- progress의 current/total 또는 알 수 없음 표현과 사용자용 message key
- candidate ID/revision, field별 value, status, source, score/confidence와 review-required 이유
- terminal의 completed/cancelled/failed 결과와 안정적인 error code

다음 정책을 schema, 문서와 test로 고정한다.

- 한 session에는 정확히 하나의 terminal event만 있다.
- cancel은 idempotent하며 terminal 뒤에는 새 candidate/progress를 발행하지 않는다.
- 이전 generation 또는 종료 session의 지연 event는 state/repository를 바꾸지 않는다.
- sequence gap, duplicate와 out-of-order event의 처리 및 snapshot 재동기화 정책이 명시적이다.
- start response와 최초 event의 순서 race가 소비자에게 손실을 만들지 않는다.
- protocol event와 backend 진단 stderr를 분리한다.
- unknown field/version, 잘못된 session/generation, malformed candidate와 허용되지 않은
  phase 전이는 거부한다.

공용 fixture에는 최소 다음 사례를 포함한다.

- student/inventory 정상 session 전체 event trace
- start와 cancel race, cancel 재시도, cancel 뒤 늦은 candidate
- 이전 generation stale event, duplicate/out-of-order/sequence gap
- target 없음/종료/최소화, capture 실패, region/template 누락, matcher 예외
- progress total unknown과 정상 단조 진행
- 높은 confidence와 낮은 confidence/review-required candidate
- candidate 수정 후 validation 성공/실패
- repository revision conflict, idempotent commit retry와 persistence error
- 정확히 하나의 terminal event 및 terminal 뒤 event 거부

### 2. Headless session application service

Flutter, Qt/Tk와 실제 화면 캡처 없이 Python test에서 session 전체를 실행할 수 있게 작은
application-service 경계를 만든다. 최소 dependency는 interface/protocol 또는 동등한 주입
경계로 분리한다.

- capture target provider와 capture/input driver
- student matcher와 inventory matcher
- recognition asset catalog/manifest
- event sink, monotonic clock와 ID/generation source
- cancellation token
- P4 repository commit port

session manager는 동시 session 정책을 명시하고, process 안에서 generation·sequence·terminal
상태를 소유한다. blocking capture/matcher가 stdio response/event loop를 멈추지 않도록
worker 경계를 둔다. cancel 요청은 유한 시간 안에 관측되어야 하며 process dispose 시 active
session과 worker가 정리되어야 한다.

test fake는 script된 capture/matcher 결과와 race를 결정적으로 재생해야 한다. 실제 image나
Windows target이 없는 CI/headless test에서 protocol, 취소, stale filtering, review와 commit을
모두 검증한다. fake 성공만으로 실제 adapter 완료를 주장하지 않는다.

### 3. Candidate, confidence와 review 경계

학생과 인벤토리 candidate는 P3/P4 저장 DTO와 분리한다. v6 `FieldMeta`, `FieldStatus`, source,
score 및 fallback 정보를 필요한 최소 wire DTO로 특성화하되 v6 scanner dataclass를 runtime
import하지 않는다.

- field별 `ok`, `inferred`, `uncertain`, `failed`, `skipped`, `region_missing` 또는 근거가 있는
  동등한 상태를 구분한다.
- aggregate confidence 하나로 field별 불확실성을 숨기지 않는다.
- threshold와 fallback은 asset/config version과 함께 진단 가능해야 한다.
- 낮은 confidence, 불확실/실패/누락 field가 하나라도 저장에 영향을 주면
  `review_required: true`다.
- review 수정은 원본 candidate를 덮어쓰지 않고 새 candidate revision과 audit 가능한 변경
  근거를 만든다.
- 정적 metadata, planning total과 shortage가 candidate/current payload에 들어가지 않는다.

### 4. 명시적 검토·수정·repository commit

scan 완료는 repository 저장 완료가 아니다. candidate가 `review_ready`가 된 뒤 별도 commit
요청만 P4 repository mutation을 호출한다.

- commit은 profile ID, candidate ID/revision, expected repository revision과 비어 있지 않은
  idempotency key를 요구한다.
- student candidate는 P3 `ConfirmedStudent`, inventory candidate는 canonical
  `InventorySnapshot`으로 validation된 뒤에만 commit한다.
- review-required candidate의 수정/승인 증거 없이 commit을 거부한다.
- stale candidate/session/repository revision은 기존 데이터를 바꾸지 않는다.
- 동일 idempotency key 재시도는 revision을 다시 증가시키지 않는다.
- partial student 또는 inventory 결과의 merge/replace 정책을 scan kind별로 fixture에 고정한다.
- commit 실패, 취소 또는 backend 재시작 시 candidate를 confirmed current로 간주하지 않는다.
- repository 파일/DB를 scanner가 직접 열지 않고 P4 application-service 경계를 사용한다.

### 5. 실제 Windows capture/matcher adapter 이전

characterization과 contract가 고정된 뒤 학생과 인벤토리의 실제 adapter를 한 수직 슬라이스씩
옮긴다. v6 대형 파일을 통째로 복사하지 말고 capture, ROI, recognition과 navigation 책임을
분리한다.

- 대상 창 열거와 stable target ID/title, foreground/minimized/closed 진단
- client-area 기준 캡처와 비율 ROI
- 안전한 입력/스크롤 및 안정 frame/timeout/cancel 확인
- 학생 식별과 current field matcher
- 인벤토리 grid/icon/count, 상세 fallback, scroll overlap와 terminal 판정
- 각 matcher의 score/margin/source와 conservative fallback
- 계정별 adaptive sample은 검토·확정된 sample만 쓰고 계정·실제 캡처 해상도를 격리

실제 adapter는 주입된 headless port와 같은 결과 DTO/event를 사용한다. Windows API와 image
dependency는 `backend/pyproject.toml`과 배포 문서에 명시한다. import 시 창 열거, 캡처,
입력 또는 사용자 경로 쓰기를 수행하지 않는다.

알고리즘을 단순화하거나 v6와 다르게 판단한다면 fixture와 근거를 먼저 제시한다. 학생 또는
인벤토리 중 하나를 fake로만 남기거나 실제 matcher를 placeholder로 두면 P5를
`COMPLETED`로 보고하지 않는다.

### 6. Recognition asset 경계와 패키징

필요한 `regions/`, `templates/`, catalog/config만 v7의 Python backend recognition asset
경로로 복사하고 manifest를 만든다.

- source 상대경로, 목적 상대경로, 용도, version, byte 크기와 SHA-256
- 필수/선택 asset, scan kind, 지원 해상도와 fallback
- 시작 전 누락·손상·version mismatch 진단
- release layout에서 backend가 resolve하는 실제 경로
- 테스트 fixture image와 production recognition asset의 구분
- 계정별 adaptive sample의 별도 writable local 경로와 배포 제외 규칙

Flutter `assets/`의 표시용 PNG와 recognition template을 서로 참조하거나 섞지 않는다. v6의
debug crop, cache, 사용자 profile sample과 불필요한 임시 template을 무차별 복사하지 않는다.

### 7. Python JSONL process event 연결

기존 stdin request/stdout response JSONL 위에 scanner event를 안전하게 multiplex한다.

- stdout의 각 line은 하나의 schema-valid response 또는 event다.
- 여러 worker의 stdout write는 직렬화해 line interleaving을 막는다.
- request response ID/method correlation과 planning/repository 동작을 유지한다.
- event backpressure와 bounded buffering/drop 정책을 명시한다. candidate/terminal은 유실하면
  안 되며 progress coalescing 여부를 test한다.
- malformed scanner request는 구조화된 오류를, untrusted envelope는 기존 정책을 따른다.
- process 종료/restart에서 active session terminal/cleanup과 client pending request 실패가
  결정적이어야 한다.

### 8. Dart typed scanner client와 service 경계

Dart process client가 response와 event를 구분하고 typed scanner model/stream을 제공한다.
raw dynamic map을 Widget에 누출하지 않는다.

- session ID/generation/sequence를 검증하고 stale·duplicate·out-of-order event를 처리한다.
- start response/event race에서도 최초 event를 잃지 않는다.
- session별 구독 해제, cancel, backend disconnect/restart와 dispose를 정리한다.
- malformed event의 session-scoped/fatal 정책을 명시하고 test한다.
- `AppService`/scanner service는 target list, start, cancel, review, modify, commit과 immutable
  session state를 제공한다.
- `MockAppService`는 같은 use case와 event 순서를 결정적으로 구현한다.
- `scanAvailable`은 실제 asset/adapter/backend readiness에서 파생하며 연결만 됐다고 true로
  만들지 않는다.

P5에서는 typed client/service와 headless integration test까지만 구현한다. production 스캔
탭 레이아웃, 프라나 표시 panel, 학생/인벤토리 탭 전체 UI와 다른 탭 연결은 P6 범위다.

### 9. 문서화

다음을 현재 구현과 일치하게 작성·갱신한다.

- `contracts/README.md`: method/event, session/generation/sequence, phase, 오류, cancel,
  review/commit과 호환성 정책
- `docs/migration/p5-scanner-matcher/scanner-characterization.md`
- `docs/migration/p5-scanner-matcher/scanner-runtime.md`: thread/task, port/adapter, capture target,
  cancellation, backpressure, restart와 repository 경계
- recognition asset manifest와 release/local adaptive sample 경계
- fixture 수, test matrix와 마스터 재현 절차

슬레이브는 `almanac/workflows/p0-p6-workflow-status.md`의 P5 상태를 `완료`로 바꾸지 않는다.
마스터가 인계 결과를 직접 검증한 뒤 상태를 결정한다.

## 금지 및 제외 범위

- P4 schema/fixture/DTO/persistence 의미 변경 또는 승인 case 삭제
- scan candidate나 낮은 confidence 결과의 자동 repository commit
- scanner가 repository JSON/SQLite/profile path를 직접 읽거나 쓰는 구현
- status/progress를 stdout/stderr 문자열 파싱으로 구현
- session generation/sequence/stale filtering 없는 callback 전달
- Qt/QML/QWidget/Tk/PySide6 presentation/thread code 복사
- v6 대형 scanner/matcher/repository facade의 무차별 복사
- `../v6` runtime import 또는 v6 원본 파일 변경
- 실제 사용자 profile, DB, adaptive sample 또는 홈 경로를 자동 발견해 test/변경
- Flutter UI asset과 Python recognition asset 혼합
- production 스캔 탭/학생/인벤토리/홈/통계 등 P6 UI 구현
- test skip, 조건부 성공, schema 기대값 약화 또는 오류 무시
- 생성/local 파일, cache, build, release, debug crop, 전달용 `output.md`/`artifacts/`를 patch에 포함
- 관련 없는 formatting, UI 재설계 또는 대규모 리팩터링

## 필수 자동 테스트

최소 다음을 추가한다.

1. Python·Dart가 같은 scanner request/response/event fixture의 valid/invalid를 동일 판정
2. student/inventory 정상 session의 phase, monotonic sequence와 정확히 한 terminal
3. start/cancel race, cancel 재시도와 terminal 뒤 event 없음
4. stale generation, duplicate, out-of-order와 sequence gap/snapshot 복구
5. target 없음/종료/최소화, capture/asset/matcher 실패의 구조화된 오류
6. 높은/낮은 confidence 및 field별 uncertain/review-required
7. candidate 수정 validation과 candidate revision 증가
8. review 없는 낮은 confidence commit 거부 및 repository hash/revision 보존
9. explicit commit, stale repository revision, idempotent retry와 persistence failure
10. student/inventory partial merge/replace 및 다섯 bucket 비중첩
11. event multiplex 중 planning/repository request correlation 회귀 없음
12. process disconnect/restart/dispose 시 worker·subscription·pending request 정리
13. headless fake capture/matcher session E2E
14. 실제 image fixture를 사용한 학생 matcher와 인벤토리 grid/count/scroll 회귀
15. asset manifest 누락·hash/version mismatch와 release path readiness
16. Dart typed state, Mock service와 실제 Python process event E2E

슬레이브는 1~15의 Python 및 정적 검증 가능한 부분을 실행한다. 1의 Dart 판정과 12·16의
Dart/Flutter 실행 부분은 source와 test까지 작성하고 `MASTER_REQUIRED`로 인계한다. 실행하지
않았다는 이유로 test를 삭제·skip 처리하거나 기대값을 약화하지 않는다.

실제 Windows 게임 창이 필요한 hardware/manual smoke test는 자동 test와 분리한다. 가능한 경우
read-only target enumeration과 사용자가 지정한 test target에서 student/inventory 각각 한 번의
smoke를 수행하되, 입력·profile 변경 전 명시적 안전 조건을 확인한다. 수행하지 못하면
`NOT_VERIFIED`로 기록하며 자동 fixture test를 대체했다고 주장하지 않는다.

## 필수 검증

### 슬레이브에서 실행

```powershell
cd backend
py -3.11 -m unittest tests.test_repository_parity tests.test_repository_persistence tests.test_repository_protocol_contract -v
py -3.11 -m unittest discover -s tests -v

cd ..
git diff --check
```

추가된 scanner Python contract/session/matcher test는 전체 suite와 별도로도 실행한다. 사용
가능한 Python dependency가 빠졌으면 최소 재현 가능한 dependency 목록과 오류를 기록하고,
작업 범위 안에서 설치 가능한지 판단한다. 대용량 SDK 설치나 사용자 파일 삭제는 하지 않는다.

### 마스터가 인계 후 실행

```powershell
cd frontend
flutter analyze
flutter test
flutter build windows --release

cd ..
codealmanac validate
codealmanac health
git diff --check
```

실제 Dart↔Python scanner event E2E도 마스터가 별도로 단독 실행한다. 슬레이브는 정확한 test
파일·test 이름·예상 event trace와 temporary-root 조건을 `verification.txt`에 기록한다.

추가로 다음을 `verification.txt`에 기록한다.

- P4 baseline gate의 실제 Python fixture/test 수와 마스터 승인 restart E2E 근거
- scanner fixture version, 전체/valid/invalid 및 trace별 event 수
- headless student/inventory E2E의 phase/sequence/terminal 결과
- 취소 latency와 terminal 뒤 event 0건
- stale/duplicate/out-of-order 처리 결과
- 낮은 confidence commit 거부 전후 repository hash/revision
- 명시적 commit과 idempotent retry 전후 revision
- 실제 image fixture별 matcher 결과, score/margin/source
- recognition asset file 수, manifest hash 검증과 release resolve 결과
- `MASTER_REQUIRED`: 실제 Dart↔Python event E2E와 process/worker/subscription cleanup
- 금지된 v6/GUI runtime import와 Flutter direct file/DB access 검색 결과
- 실제 사용자 profile/DB/adaptive sample 미사용 및 temporary root 증거
- patch 대상과 작업 전 tree의 중첩 여부
- 실행하지 못한 manual smoke 항목과 이유

실행하지 못한 검증은 통과로 쓰지 말고 `NOT_VERIFIED`와 이유를 기록한다. Flutter/Dart와
CodeAlmanac 항목은 이유를 도구 부재로 반복하는 대신 `MASTER_REQUIRED` 목록에 모은다.

## 완료 조건

슬레이브는 다음 조건이 충족되면 산출물 인계 상태를 `COMPLETED`로 보고할 수 있다.

- 슬레이브 실행 가능 P4 baseline과 P5 Python 검증이 통과한다.
- 요구된 Python/Dart/Flutter source, test, fixture, 문서와 asset manifest가 patch에 포함된다.
- 실제 student와 inventory capture/matcher adapter가 fake/placeholder 없이 Python test에 연결된다.
- Flutter/Dart/Almanac 마스터 gate가 `NOT_VERIFIED`/`MASTER_REQUIRED`로 정확히 기록된다.
- patch, verification, output과 cross-PC 전달 파일이 인계 계약을 충족한다.

마스터가 P5 단계를 최종 `완료`로 승인하려면 다음 조건을 모두 확인한다.

- P4 승인 baseline이 변경 전 재현되고 P5 뒤에도 회귀 없이 유지된다.
- Python·Dart가 동일한 scanner protocol/event fixture를 검증한다.
- Flutter 없이 student/inventory session, cancel, stale, review와 commit을 test한다.
- 실제 student와 inventory capture/matcher adapter가 placeholder 없이 연결된다.
- 낮은 confidence candidate가 검토 없이 repository current/inventory를 바꾸지 않는다.
- 이전 generation/terminal 뒤 event가 typed state나 repository를 바꾸지 않는다.
- explicit commit이 P4 revision/idempotency/corruption 경계를 재사용한다.
- recognition asset이 UI asset과 분리되고 manifest/hash/release path가 검증된다.
- 실제 Dart↔Python event 흐름과 process restart/dispose cleanup이 통과한다.
- Python/Flutter/release/Almanac/diff 전체 검증이 통과한다.
- P6 UI 또는 실제 사용자 데이터 변경이 포함되지 않는다.

슬레이브 실행 가능 필수 검증이 실패하거나 student/inventory 실제 adapter 중 하나가
fake/placeholder로 남으면 인계 상태를 `COMPLETED`로 보고하지 않는다. 마스터 전용 검증이
아직 실행되지 않은 사실만으로는 산출물 인계를 `BLOCKED`로 바꾸지 않는다.

## 결과물 및 인계 계약

```text
docs/migration/p5-scanner-matcher/
├─ input.md                         # 이 파일: 수정·삭제·덮어쓰기 금지
├─ slave-execution-prompt.md        # 실행 안내: patch에 포함하지 않음
├─ output.md                        # 모든 결과물이 준비된 뒤 마지막에 작성
└─ artifacts/
   ├─ p5-scanner-matcher.patch
   └─ verification.txt
```

- patch는 승인된 P4 baseline에 적용되는 단일 P5 증분이어야 하며 신규 recognition asset도
  재현 가능한 방식으로 포함한다.
- 작업 시작 전 `git status --short`와 baseline commit/diff 식별 정보를 기록한다.
- 모든 diff path는 `BA Planner/v7/...` prefix를 사용한다.
- `input.md`, `slave-execution-prompt.md`, `output.md`, `artifacts/`, 이전 patch, build/cache/local
  파일과 사용자 adaptive sample을 patch에 포함하지 않는다.
- `git apply --check --verbose`에서 모든 path가 Checking되고 skipped 0이어야 한다.
- `verification.txt`에는 모든 명령, exit code, test/fixture/event/asset 수와 실패·보존 결과를
  기록한다.
- artifact 2개의 존재, 0보다 큰 크기, byte 크기와 SHA-256을 확인한다.
- `output.md`는 `almanac/workflows/slave-artifact-handoff.md` 계약을 따른다.

## cross-PC 전달

마스터 receiver:

```powershell
& "$HOME\.codex\ba-planner-slave\Receive-SlaveResult.ps1" `
  -TaskId "ba-planner-v7-p5-scanner-matcher"
```

슬레이브 sender:

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p5-scanner-matcher" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p5-scanner-matcher"
```

Task ID와 TaskDirectory를 생략하지 않는다. 마스터가 `WIRELESS_HANDOFF_RECEIVED`를 확인하기
전에는 무선 전달 완료로 보고하지 않는다. token은 출력·파일·로그·문서에 기록하지 않는다.

```text
TASK_OUTPUT_READY
task_id: ba-planner-v7-p5-scanner-matcher
status: COMPLETED
output_md: <슬레이브 PC의 output.md 절대경로>
artifacts_dir: <슬레이브 PC의 artifacts 절대경로>
artifact_count: 2
handoff_package: <ZIP 절대경로>
handoff_package_size: <바이트>
handoff_package_sha256: <SHA-256>
master_prompt: <-MASTER_PROMPT.md 절대경로>
wireless_transfer: RECEIVED, NOT_REQUESTED 또는 FAILED
```

완료할 수 없으면 `TASK_OUTPUT_BLOCKED`로 보고한다. 마스터가 package, artifact, patch와 전체
검증을 직접 확인하기 전에는 P5를 완료로 간주하지 않는다.
