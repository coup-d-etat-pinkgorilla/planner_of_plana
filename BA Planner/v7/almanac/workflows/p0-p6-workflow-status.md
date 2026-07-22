---
title: "P0-P6 Workflow Status"
summary: "새 대화에서도 P0~P6 작업의 정의, 진행 상태, 산출물과 다음 행동을 복원하기 위한 활성 진행 기록입니다."
topics: [workflow, architecture, migration]
sources:
  - id: agent-instructions
    type: file
    path: AGENTS.md
---

# P0-P6 Workflow Status

이 문서는 P0~P6 워크플로가 모두 완료될 때까지 유지하는 활성 작업 기록이다. 새
대화에서 관련 작업을 시작할 때 가장 먼저 읽고, 단계의 상태·결정·산출물·다음 행동이
바뀐 작업이 끝날 때마다 갱신한다. [@agent-instructions]

## 기록 원칙

- 저장소나 사용자가 제공한 근거 없이 단계의 목적과 완료 상태를 추측하지 않는다.
- 각 단계의 `input.md`, `output.md`와 `artifacts/` 위치를 기록한다.
- 완료 판정은 마스터가 결과물을 직접 확인한 뒤에만 기록한다.
- 슬레이브의 완료 보고만 받은 상태는 `검증 중`이며 `완료`가 아니다.
- 중요한 설계 결정, 실패 원인, 보류 이유와 다음 행동을 남긴다.
- 코드와 문서가 이 기록과 다르면 코드 및 검증 결과를 우선하고 이 문서를 바로잡는다.
- P0~P6 전체가 완료되기 전에는 이 문서를 삭제하거나 완료 기록을 축약하지 않는다.
- 전체 완료 후에는 최종 상태와 검증 근거를 남긴 뒤 장기 결정 문서로 정리할 수 있다.

## 상태 값

| 상태 | 의미 |
|---|---|
| `정의 필요` | 단계 이름이나 완료 조건이 아직 확인되지 않음 |
| `대기` | 정의됐지만 선행 작업 또는 명령을 기다림 |
| `진행 중` | 마스터 또는 슬레이브가 작업 중 |
| `인계 대기` | 슬레이브가 결과를 만들었으나 `output.md`와 결과물 인계가 끝나지 않음 |
| `검증 중` | 마스터가 전달된 결과물을 확인 중 |
| `차단됨` | 구체적인 장애 때문에 진행할 수 없음 |
| `완료` | 마스터가 결과물과 완료 조건을 직접 확인함 |

## 단계 정의

단계의 고정된 목적과 완료 조건은
[P0-P6 Implementation Workflow](p0-p6-workflow)를 따른다. 이 문서는 그 정의를
반복하지 않고 현재 상태, 실제 산출물, 검증과 다음 행동을 기록한다.

## 현재 단계 현황

2026-07-22 P0 계약, P1 process transport, P2 실제 계획 화면, P3 repository DTO·병합
parity와 P4 repository persistence를 현재 작업 트리에서 마스터가 직접 완료 조건과 대조해
보완하고 인수했다. Python test 40개, Flutter test 43개, `flutter analyze`, 실제 Python
process의 planning method와 repository restart E2E, MockAppService 흐름, Almanac 검증과
Windows release build가 통과했다. 변경은 아직 커밋되지 않았다.

| 단계 | 목적 | 상태 | 근거 또는 산출물 | 다음 행동 |
|---|---|---|---|---|
| P0 | planning IPC 계약과 공용 fixture | `완료` | schema·fixture, Python/Dart contract 및 parity test 통과 | 계약 변경 시 양쪽 fixture test 유지 |
| P1 | Python JSONL process와 Dart client | `완료` | lifecycle·오류·실제 세 method E2E 및 release build 통과 | P2가 `AppService` planning method만 사용하도록 유지 |
| P2 | 실제 계획 화면 수직 슬라이스 | `완료` | 인계 patch 적용 후 마스터 보완, Widget test 8개와 전체 39개·실제 backend·Mock·release 통과 | P4/P6 전까지 in-memory·총 필요량 경계 유지 |
| P3 | repository 특성화와 DTO 분리 | `완료` | 원본과 followup 2건 적용, DTO·fixture·비중첩·전체 검증 통과 | P4에서 승인된 DTO·병합 계약 유지 |
| P4 | 프로필과 repository 영구 저장 | `완료` | nested schema·40-case Python/Dart contract, typed state, atomic persistence와 실제 Dart↔Python restart E2E; Python 40·Flutter 43·analyze·release 통과 | P5에서 repository 확정과 분리된 scanner session 경계 작성 |
| P5 | scanner/matcher session protocol과 backend | `대기` | `BLOCKED` 부분 증분 10-path patch 인수·검증 후 follow-up-1 지시 작성 | 실제 adapter·asset manifest·JSONL event transport·Dart typed client 작업을 슬레이브에게 전달 |
| P6 | 전 기본 탭 실제 데이터 통합 | `대기` | 현재 홈 골격과 placeholder 페이지 | P2·P4·P5 인수 후 P6-1 학생부터 진행 |

## 현재 결정

- P0은 planning wire 계약, P1은 그 계약의 실제 process transport로 분리한다.
- P2에서 계획 탭을 먼저 실제화하고 P6에서는 repository·scanner 결과까지 통합한다.
- P3는 실제 repository 쓰기보다 DTO와 v6 병합 parity를 먼저 완료한다.
- P5는 scanner 결과 생성과 repository 확정을 분리한다.
- P5 event는 session ID, generation과 단조 증가 sequence를 가지며 terminal 뒤 event와
  이전 generation의 지연 event는 typed state와 repository를 바꾸지 않는다.
- 낮은 confidence candidate는 자동 저장하지 않고 검토·수정과 expected repository
  revision/idempotency key를 가진 별도 commit만 P4 경계를 호출한다.
- recognition template·region·adaptive sample은 Flutter UI asset과 분리하며 manifest와
  SHA-256으로 배포 경계를 검증한다.
- P6은 학생 → 인벤토리 → 스캔 → 홈 → 통계 → 전술대항전 → 설정 순서로 진행한다.
- P6 완료는 정식 출시가 아니라 통합 베타 기준이다.
- P6 화면 설계 전 입력으로 `almanac/design/frontend-section-direction-and-user-flows.md`를
  사용한다. 이 문서는 사용자가 정한 80도 사선·글라스·부착면·전환 방향을 확정 규칙으로,
  계획 외 탭의 기능별 행동 순서를 검수 전 가설로 구분한다.
- 창 비율 대응은 `almanac/design/responsive-diagonal-layout-policy.md`의 제한된 레이아웃
  상태 제안을 검수한 뒤 확정한다. 전체 캔버스 일괄 축소와 제약 없는 자동 재배치는
  기본 전략으로 사용하지 않는다.
- 기능 화면은 한 섹션에 많은 기능을 압축하기보다 사용자 목적 단위의 여러 부착 섹션으로
  나눈다. 중앙에 독립적으로 떠 있는 섹션은 만들지 않는다.
- backend launcher 설정은 연결 시점에 지연 해석해 잘못된 경로에서도 shell을 띄운다.
- timeout 후 늦은 response ID는 진단만 남기지만, malformed response·method mismatch,
  허용되지 않은 오류 code·성공 payload와 stdin 실패는 연결 전체를 종료한다.
- P1의 실제 backend에는 scanner capability가 없으며 스캔 버튼을 비활성화한다.
- 슬레이브와 마스터가 다른 PC이면 로컬 절대경로를 인계로 인정하지 않고 ZIP,
  SHA-256, manifest와 마스터 실행 프롬프트 네 파일을 마스터 inbox로 옮긴다.
- 같은 신뢰 가능한 사설 Wi-Fi/LAN에서는 일회용 token 수신기로 네 파일을 무선
  전송하고 ZIP 검증 후 자동 종료한다. token은 결과물이나 장기 문서에 기록하지 않는다.
- 마스터는 `$HOME/.codex/ba-planner-slave/Receive-SlaveResult.ps1` 단일 래퍼로 결과
  수신·staging 검사·`MASTER_PROMPT.md` 클립보드 복사를 수행한다.
- 슬레이브는 `$HOME/.codex/ba-planner-slave/Send-SlaveResult.ps1` 단일 래퍼로
  패키징·UDP 마스터 자동 발견·무선 업로드를 수행하며 IP·port·token을 수동 입력하지 않는다.
- 현재 슬레이브 PC는 저장 공간 제약으로 Flutter/Dart SDK를 설치·사용하지 않으며
  CodeAlmanac CLI도 지원되지 않는다. 이는 작업 차단 사유가 아니라 검증 책임 분리 조건이다.
  슬레이브는 Python·정적 검사·patch·패키징을 수행하고 Flutter/Dart/analyze/release,
  실제 Dart↔Python E2E와 Almanac 검증은 `MASTER_REQUIRED`로 인계한다.
- 슬레이브가 작성한 Flutter/Dart code와 test는 마스터 검증 전 통과로 간주하지 않으며,
  슬레이브의 `COMPLETED`는 산출물 준비 완료일 뿐 단계 완료 승인이 아니다.
- Windows UDP discovery는 도달 불가능한 가상 어댑터의 ICMP connection-reset을 개별
  probe 잡음으로 무시하고 nonce가 일치하는 수신기 응답을 계속 기다린다.

## 확인된 P0/P1 산출물

- 계약: `contracts/planning-protocol-v1.schema.json`과 method/error schema
- fixture: `contracts/fixtures/planning_protocol_v1.json`
- Python: `backend/core/protocol_v1.py`, `stdio_server.py`, `backend_process.py`
- Dart: `backend_process.dart`, `planning_protocol_client.dart`, `process_app_service.dart`
- test: Python contract/stdio test와 Dart contract/client test
- 실행 선택: 기본 mock을 유지하며 dart-define으로 실제 backend를 선택

기존 슬레이브 `input.md`, `output.md`와 `artifacts/` 위치는 확인되지 않았다. 이후
사용자가 현재 작업 트리의 P0/P1을 이 워크플로에 맞게 직접 수정하도록 지시했고,
마스터가 코드·diff·테스트를 직접 보완하고 검증했으므로 기존 인계 누락은 P0/P1의
완료를 막지 않는 일회성 예외로 판정했다. P2부터는 Slave Artifact Handoff 계약을
생략하지 않는다.

## 현재 검증

- `codealmanac validate`: 통과, 6 pages
- `py -3.11 -m unittest discover -s tests -v`: 27 tests 통과
- P3 repository parity: 10 tests와 fixture 26 cases 통과; current/metadata field 교집합 없음, `display_name` confirmed/commit 유입 두 사례 거부
- `flutter analyze`: 문제 없음
- `flutter test`: 39 tests 통과
- P2 Widget test: 8 tests 통과(조회·중복·삭제·오류·Mock·목표 의미·합산·stale·좁은 화면)
- 실제 Python process의 student lookup, plan validation, calculation: 통과
- timeout, late response, malformed response, method mismatch, invalid error/success
  payload, stdin failure, unexpected exit, restart와 dispose: 통과
- `flutter build windows --release`: 통과
- `git diff --check`: 통과
- 금지된 GUI/v6 runtime import 검사: 유입 없음

## 다음 행동

1. `docs/migration/p5-scanner-matcher/slave-execution-prompt.md`를 슬레이브에게 전달한다.
2. 슬레이브는 P4 승인 baseline gate가 모두 통과한 경우에만 P5 구현을 시작한다.
3. P5 인계 전까지 scanner capability와 스캔 버튼은 비활성 상태를 유지한다.
4. P6 전까지 P2 결과는 보유량 차감 전 총 필요량이며 부족량을 표시하지 않는다.
5. P6 하위 단계의 화면 구성을 확정하기 전에 탭별 흐름 가설의 `사용자 검수 포인트`를
   사용자와 확인하고, 승인된 흐름만 실제 섹션 구성으로 변환한다.

## P6 UX 선행 입력 — 섹션 방향과 탭별 사용자 흐름

- 상태: `진행 중`
- 목적: 실제 P6 화면 배치 전에 공통 섹션 규칙과 계획 외 탭의 기능별 행동 흐름을 고정
- 입력: 사용자 제공 프론트엔드 디자인 방향, P6 탭별 기능, v6 사용자 흐름 감사
- 출력 보고서: `almanac/design/frontend-section-direction-and-user-flows.md`,
  `almanac/design/responsive-diagonal-layout-policy.md`
- 결과물: 80도 사선·부착면·글라스·모션 계약, 탭별 기능 그룹·주 흐름·탭 간 인계·검수 질문,
  창 비율별 제한된 레이아웃 상태와 사선 안전 폭 계약 제안
- 검증: `AppSection.primary`, P6 탭별 기능과 v6 보존 흐름 대조; `codealmanac validate`와
  `codealmanac health` 통과(8 pages, orphan·dead ref·broken link·citation 문제 없음)
- 결정 및 제약: 계획 탭은 사용자가 이미 기획한 기준 사례로만 기록하며 재설계하지 않음;
  나머지 탭의 흐름은 화면 배치가 아니라 검수 전 가설임
- 차단 사항: 없음
- 다음 행동: 사용자가 탭별 우선순위·흐름 분기점과 반응형 정책의 승인 항목을 검수한 뒤
  실제 섹션 구성 및 지원 최소 창 크기를 별도 확정
- 최종 갱신: 2026-07-22

## 마스터 사용량 중단 시 슬레이브 작업 규칙

마스터의 사용량이 중간에 끊기거나 마스터가 결과를 즉시 검사할 수 없을 때도 슬레이브는
이미 전달받은 현재 단계의 `input.md` 범위 안에서 작업을 계속할 수 있다. 다만 슬레이브의
`COMPLETED` 보고는 마스터의 수신·검증·적용을 대신하지 않으며, 마스터 검증 없이 다음 의존
단계를 구현하지 않는다.

### 공통으로 계속할 수 있는 작업

1. 이미 지시받은 현재 단계의 구현, 테스트, 문서화와 자체 검증을 끝낸다.
2. 최종 patch, fixture, 검증 로그 등 실제 결과물을 `artifacts/`에 저장한다.
3. 각 결과물의 크기와 SHA-256을 기록한 `output.md`를 작성하고 인계 패키지를 준비한다.
4. 실패·미검증·환경 제한과 마스터가 결정해야 할 사항을 `output.md`에 명시한다.
5. 다음 단계에 필요한 v6 동작 조사, 현재 코드 경계 목록, 위험 목록과 테스트 사례를 읽기
   전용 조사 산출물로 준비할 수 있다.
6. 마스터가 복귀할 때까지 원래 결과물과 전송 패키지를 보존하며, 임의로 재생성하거나
   다른 단계 결과와 합치지 않는다.

### 마스터 검증 전 금지 작업

- 슬레이브가 자신의 결과를 승인·적용된 것으로 간주하거나 이 상태 문서를 `완료`로 바꾸는 일
- 현재 단계 결과를 전제로 다음 의존 단계의 production 구현을 시작하는 일
- 아직 승인되지 않은 DTO, protocol, event schema 또는 repository 경계를 사실상 확정하는 일
- 마스터 작업공간에 patch를 직접 적용하거나 여러 단계 patch를 하나로 합치는 일
- `../v6` runtime import, 실제 사용자 프로필 변경 또는 명시되지 않은 migration 실행
- 마스터 지시 없이 기존 결과물을 폐기·재생성하거나 파일명과 인계 경로를 바꾸는 일

### 단계별 대기 작업

| 마스터 중단 시점 | 슬레이브가 할 수 있는 작업 | 넘어가면 안 되는 경계 |
|---|---|---|
| P3 검증 전 | P3 follow-up 완료·자체 테스트·패키징, P4의 atomic write·손상·migration·revision 시험 항목 조사 | P4 영구 저장 구현 |
| P4 지시 전 | v6 프로필 저장 동작과 오류 사례 조사, 저장 파일 소유권·migration 위험·contract test 표 초안 | 승인되지 않은 P3 DTO를 사용한 P4 코드 |
| P4 작업 중 | 전달받은 P4 범위 구현·전체 검증·패키징 | 자신의 P4 결과를 전제로 한 P5 구현 |
| P5 지시 전 | v6 scanner/capture/matcher 의존성 조사, event 종류·취소·stale·confidence fixture 후보와 recognition asset 목록 작성 | session protocol 확정, backend 연결, repository commit 구현 |
| P5 작업 중 | 전달받은 P5 범위 구현·headless test·asset 검사·패키징 | 자신의 P5 결과를 전제로 한 P6 실제 연결 |
| P6 지시 전 | 탭별 placeholder·공용 widget·필요 service 목록, loading/empty/error/disconnected 및 대용량 UI test matrix 작성 | 실제 repository/scanner client 연결 |
| P6 작업 중 | 마스터가 지정한 단일 P6 하위 단계만 구현·검증·패키징 | 다음 P6 하위 단계나 미승인 service 계약으로 범위 확대 |

P4, P5와 P6은 순차 의존하므로 마스터가 없는 동안 자동 연쇄 실행하지 않는다. 병렬 준비는
선행 계약을 바꾸지 않는 조사, fixture 후보, 테스트 계획과 UI 현황 목록으로 제한한다.

## P2 — 계획 화면 수직 슬라이스

- 상태: `완료`
- 목적: 계획 placeholder를 학생 목표 편집과 총 필요량 계산이 가능한 실제 화면으로 교체
- 완료 조건: AppService planning method만 사용하는 학생별·전체 계산, 필수 상태와 Widget test, 전체 검증 통과
- 입력: `docs/migration/p2-planning-screen/input.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p2-planning-screen/staging/master-verify-20260722-000001-a8bb6fea/output.md`
- 결과물: 같은 staging의 `artifacts/p2-planning-screen.patch`, `artifacts/verification.txt`; 수신 ZIP SHA-256 `16b833cde5201f3dd90e08d56ccbce223f5ee40d78c4f1257ea15daf063cdc87`
- 검증: ZIP·manifest·산출물 크기/SHA-256 일치, 무중첩 확인, `git apply --check` 후 적용; Python 17, Flutter 39, analyze, 실제 Python process E2E, Mock flow, Windows release, Almanac와 diff 검사 통과
- 결정 및 제약: 정확한 학생 ID 조회, in-memory 임시 현재 상태, AppService planning method만 사용, 부족량·저장·scanner 제외
- 차단 사항: 없음
- 다음 행동: 작성된 P3 작업 지시를 슬레이브에게 전달하고 DTO·병합 fixture 결과 인계 대기
- 최종 갱신: 2026-07-22

## P3 — Repository 특성화와 DTO 분리

- 상태: `완료`
- 목적: v6 repository의 scanner·storage 결합을 특성화하고 독립 DTO와 순수 병합 parity 경계를 확정
- 완료 조건: scanner/matcher 없이 fixture 재생, 다섯 데이터 버킷 매핑 고정, v6 runtime import 없는 parity test, 실제 사용자 저장소 쓰기 없음
- 입력: `docs/migration/p3-repository-dto/input.md`
- 추가 입력: `docs/migration/p3-repository-dto-followup-1/input.md`
- 추가 입력 2: `docs/migration/p3-repository-dto-followup-2/input.md`
- 출력 보고서: 원본 `docs/migration/handoffs/incoming/ba-planner-v7-p3-repository-dto/staging/20260722-004918-138dd469/output.md`; followup-1 `docs/migration/handoffs/incoming/ba-planner-v7-p3-repository-dto-followup-1/staging/20260722-012000-57ed5103/output.md`; followup-2 `docs/migration/handoffs/incoming/ba-planner-v7-p3-repository-dto-followup-2/staging/20260722-020150-bead4898/output.md`
- 결과물: followup-2 staging의 `artifacts/p3-repository-dto-followup-2.patch`, `artifacts/verification.txt`; followup-2 ZIP SHA-256 `af07c2538b63cdb9cd03601a4bde8d28ce5324372f439884f052853e30823560`
- 검증: 세 패키지의 ZIP·manifest·sidecar·artifact 해시와 단계별 baseline·무중첩 확인, 각 `git apply --check` 후 증분 적용; P3 10 tests·fixture 26 cases, Python 27, Flutter 39, analyze, Windows release, Almanac, diff, 실제 backend 세 method E2E와 Mock 계획 흐름 통과; current/metadata 교집합 `set()`, `display_name` confirmed/commit 유입 두 사례 모두 `RepositoryDTOError`
- 결정 및 제약: P3는 DTO·순수 병합·fixture·문서·test만 구현하며 영구 저장은 P4, scanner session/backend는 P5에 남김
- 차단 사항: 없음
- 다음 행동: P4가 아래 승인 baseline을 변경 전 gate로 재현하도록 유지
- 최종 갱신: 2026-07-22

### P3 승인 baseline

P3 완료는 현재 작업 트리의 다음 파일과 실행 결과를 P4의 불변 입력으로 승인한 것을
뜻한다. P4 슬레이브는 구현 전에 이 baseline을 재현하며, 하나라도 다르면 P3를 임의로
수정하지 않고 `BLOCKED`로 반환한다.

- 승인 파일: `backend/core/repository_dto.py`, `backend/core/repository_merge.py`,
  `backend/tests/test_repository_parity.py`, `contracts/fixtures/repository_v6_parity.json`,
  `docs/migration/p3-repository-dto/repository-characterization.md`,
  `docs/migration/p3-repository-dto/repository-protocol-draft.md`
- fixture 기준: version 1, 26 cases(`student_merge` 6, `inventory_normalize` 3,
  `inventory_merge` 2, `inventory_order` 1, `inventory_diff` 1, `resolve` 2,
  `dto_error` 10, `bucket_mapping` 1)
- test 기준: `tests.test_repository_parity` 10 tests, 변경 전 전체 Python 27 tests
- field 기준: `CONFIRMED_STUDENT_VALUE_FIELDS`와 `StudentMeta.__annotations__` 교집합
  `set()`; `display_name`의 confirmed-current 및 student commit 유입 모두 거부
- 책임 기준: P3는 독립 DTO, 순수 병합, fixture와 특성화만 소유한다. filesystem/SQLite
  I/O, profile catalog, atomic persistence와 migration은 P4가 소유한다.
- 금지 기준: 실제 사용자 저장소 쓰기, `../v6`·scanner·GUI runtime import, 정적 metadata,
  goal, 총 계산 결과 또는 shortage의 confirmed-current/inventory 유입 없음

## P4 — Repository와 프로필 영구 저장

- 상태: `완료`
- 목적: Python backend가 프로필, 확정 현재 상태, 인벤토리와 사용자 목표의 안전한 저장·복원을 소유
- 완료 조건: 재실행 복원, atomic failure 시 기존 데이터 보존, revision/idempotency 및 손상·병합 fixture, Python/Dart contract와 전체 검증 통과
- 입력: `docs/migration/p4-repository-persistence/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p4-repository-persistence/slave-execution-prompt.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p4-repository-persistence/staging/20260722-124720-98185035/output.md`
- 결과물: 같은 staging의 `artifacts/p4-repository-persistence.patch`, `artifacts/verification.txt`; ZIP SHA-256 `f14f7d07f7908b71d87af136e3afbe027cf9c6c338c958a40eea52d73776143f`
- 검증: ZIP 21,647 bytes와 SHA-256이 사용자 값·manifest·sidecar에 일치하고 내부 artifact 2개의 크기·해시도 `output.md`와 일치함. 21개 patch path가 모두 `BA Planner/v7/...`이고 기존 Almanac 변경과 중첩 없이 `git apply --check` 및 적용 통과. P3+P4 집중 Python 20, 전체 Python 37, `flutter analyze`, Windows release build, `codealmanac validate`, `git diff --check` 통과. Flutter 전체 41개 중 나머지 40개는 통과했으나 신규 profile panel test 1개가 disposed `TextEditingController` 재사용으로 실패. 수동 corruption probe에서 malformed catalog entry는 raw `KeyError`, malformed profile `idempotency`는 raw `AttributeError`를 발생시켜 구조화된 `corrupt_data` fail-closed 조건을 충족하지 못함. repository schema는 임의 success payload도 유효 판정하며 Dart fixture test는 case별 `valid`를 검증하지 않음
- 결정 및 제약: P4는 저장·profile·repository protocol과 최소 profile UI만 구현하며 scanner session/backend는 P5, 전 탭 통합은 P6에 남김
- 원본 인계 차단 이력: profile dialog lifecycle과 손상 catalog/idempotency raw 예외는 follow-up-1에서 해결됨; method별 success response schema와 Dart contract 검증은 미해결
- 보완 입력: `docs/migration/p4-repository-persistence-followup-1/input.md`
- 보완 슬레이브 실행 프롬프트: `docs/migration/p4-repository-persistence-followup-1/slave-execution-prompt.md`
- 보완 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p4-repository-persistence-followup-1/staging/20260722-141231-dda5ceb6/output.md`
- 보완 결과물: 같은 staging의 `artifacts/p4-repository-persistence-followup-1.patch`, `artifacts/verification.txt`; ZIP SHA-256 `d1cc336970efcd1ae8dac08163452102af22b526f17f770072d854c2d04c33c9`
- 보완 검증: ZIP 6,982 bytes와 SHA-256이 사용자 값·manifest·sidecar에 일치하고 내부 artifact 2개의 크기·해시도 `output.md`와 일치함. 4개 증분 path가 모두 `BA Planner/v7/...`이며 현재 상태 문서와 중첩 없이 apply-check·적용 통과. 집중 Python 22, 전체 Python 39, Flutter 41, analyze, Windows release, Almanac와 diff 검사 통과. profile create/select/rename/cancel/빈 입력 lifecycle test 통과; malformed catalog와 idempotency가 모두 `corrupt_data`로 fail-closed함. 반면 `{ "nonsense": true }` profile-list success가 schema에서 여전히 유효하며 method별 success schema, Dart valid/invalid validator와 runtime rejection, typed repository state 및 real Dart/Python restart E2E는 미구현임
- 차단 사항: follow-up-1은 lifecycle/corruption을 해결했고 follow-up-2 부분 증분은 method별 top-level success schema만 해결함. Dart fixture validator, runtime malformed-success 차단, typed repository state, real Dart/Python restart E2E와 nested request/state schema가 미구현임. 전달문이 P4 follow-up task를 P2 및 `p2-planning-screen.patch`로 부르는 복사 오류도 남아 있음
- 보완 입력 2: `docs/migration/p4-repository-persistence-followup-2/input.md`
- 보완 슬레이브 실행 프롬프트 2: `docs/migration/p4-repository-persistence-followup-2/slave-execution-prompt.md`
- 보완 출력 보고서 2: `docs/migration/handoffs/incoming/ba-planner-v7-p4-repository-persistence-followup-2/staging/20260722-150536-0faf9415/output.md`
- 보완 결과물 2: 같은 staging의 `artifacts/p4-repository-persistence-followup-2.patch`, `artifacts/verification.txt`; ZIP SHA-256 `2d985e43867337843da811e08b02876cf4b340c575846f7028f03e717bb5085e`
- 보완 검증 2: ZIP 5,539 bytes와 SHA-256이 사용자 값·manifest·sidecar에 일치하고 내부 artifact 2개의 크기·해시도 `output.md`와 일치함. schema·fixture 2개 증분 path가 `BA Planner/v7/...`이며 apply-check·적용 통과. repository fixture는 28 cases(valid 14/invalid 14), Python 집중 22·전체 39, Flutter 41, analyze와 Windows release 통과. 모든 repository method의 top-level nonsense success는 schema에서 거부됨. 그러나 confirmed current의 `display_name`/`shortages`와 goal `target_level: 999`가 포함된 state response, junk student update, 빈 inventory/goals update request가 여전히 schema에서 유효함. Dart test는 `valid`를 읽지 않고 runtime client는 `repository.*` success를 무조건 허용하며 service/UI는 raw state map을 사용함. 실제 Dart↔Python restart E2E 없음
- 보완 입력 3: `docs/migration/p4-repository-persistence-followup-3/input.md`
- 보완 슬레이브 실행 프롬프트 3: `docs/migration/p4-repository-persistence-followup-3/slave-execution-prompt.md`
- 보완 출력 보고서 3: `docs/migration/handoffs/incoming/ba-planner-v7-p4-repository-persistence-followup-3/staging/20260722-161431-fa2a3481/output.md` (`BLOCKED`)
- 보완 결과물 3: 같은 staging의 `artifacts/p4-repository-persistence-followup-3.patch` 50,024 bytes, SHA-256 `79b403e7a44a175c58ad37cc95f8b503ab74c7e61a2999337710988285af4982`; `artifacts/verification.txt` 3,733 bytes, SHA-256 `14980ff4d86dd5141306ad80b527a0304777267407c4b342a890e94dfd410bed`; ZIP 12,769 bytes, SHA-256 `2d032d42a459e9e788ac7658bb45bd5f47ff61354c54035595e5d24dd2dda809`
- 보완 검증 3: ZIP 크기·SHA-256이 사용자 값, manifest와 sidecar에 일치하고 내부 artifact 2개의 크기·해시도 `output.md`와 일치함. unique staging에만 해제했고 10개 patch path가 모두 `BA Planner/v7/...`이며 기존 상태 문서 변경과 중첩 없이 `git apply --check --verbose` 및 적용 통과. repository fixture는 40 cases(valid 14/invalid 26)이며 Dart가 모든 case의 `valid`를 비교하고 Python schema·DTO contract 집중 23 및 전체 Python 40 tests가 통과함. malformed repository success fatal/restart test, typed repository state, Mock profile flow, Python 자체 child-process 재시작 복원, Flutter 전체 42 tests, Windows release, Almanac와 diff 검사가 통과함. 그러나 `flutter analyze`는 `repository_service.dart` 82·181행의 `curly_braces_in_flow_control_structures` 2건으로 실패함
- follow-up-3 차단 이력: 필수 실제 Dart `ProcessAppService` ↔ Python child-process temporary-root 종료·재시작·복원 E2E, analyzer 정리와 nested strict contract·typed state·E2E 문서 갱신이 누락됐음
- 보완 입력 4: `docs/migration/p4-repository-persistence-followup-4/input.md`
- 보완 슬레이브 실행 프롬프트 4: `docs/migration/p4-repository-persistence-followup-4/slave-execution-prompt.md`
- 마스터 직접 보완: 슬레이브 환경에 Flutter/Dart/CodeAlmanac이 없어 follow-up-4 실행이 불가능했으므로 마스터 작업트리에서 `BackendProcessConfig`의 immutable test environment override, 실제 repository process restart E2E, analyzer block 수정과 계약·저장·runtime 문서를 직접 완성함
- 최종 검증: P3/P4 집중 Python 23, 전체 Python 40, repository fixture 40 cases(valid 14/invalid 26), Flutter 전체 43, `flutter analyze`, Windows release build, `codealmanac validate`, `git diff --check` 통과. 실제 E2E는 Dart가 시작한 서로 다른 Python child process 2개를 순차 종료·실행하고 같은 temporary `BA_PLANNER_STORAGE_ROOT`에서 profile ID, display name, revision 3과 canonical goal을 typed state로 복원했으며 두 process exit code 0과 temporary root 삭제를 확인함. 금지된 v6/Qt runtime import 0건
- 슬레이브용 완료 선언: P4는 마스터 승인으로 최종 완료되었으며 follow-up-4는 재실행 대기
  작업이 아닌 이력 문서다. P5 슬레이브는 현재 작업 트리를 승인 baseline으로 사용하고,
  baseline이 다르면 P4를 수정하지 않고 `BLOCKED`로 보고한다.
- 차단 사항: 없음
- 다음 행동: P4 typed repository boundary를 유지한 채 P5 scanner/matcher session protocol을 시작
- 최종 갱신: 2026-07-22

## P5 — Scanner/Matcher session protocol과 backend

- 상태: `대기`
- 목적: v6 capture·scanner·matcher를 UI callback과 repository 저장에서 분리해 학생·인벤토리
  session, 구조화 event, 검토 가능한 candidate와 명시적 commit을 제공
- 완료 조건: 공용 Python/Dart event fixture, headless student/inventory session test, 취소·stale·낮은
  confidence 보존, 실제 adapter, recognition asset 분리와 전체 검증 통과
- 입력: `docs/migration/p5-scanner-matcher/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p5-scanner-matcher/slave-execution-prompt.md`
- 보완 입력: `docs/migration/p5-scanner-matcher-followup-1/input.md`
- 보완 슬레이브 실행 프롬프트: `docs/migration/p5-scanner-matcher-followup-1/slave-execution-prompt.md`
- 수신 패키지: `docs/migration/handoffs/incoming/ba-planner-v7-p5-repository-persistence/ba-planner-v7-p5-repository-persistence-20260722-222844.zip`, 17,273 bytes, SHA-256 `5ee0b0492c264d6c4ff2f542cdd8fbbe0bd4de57ce019e2b078cbedd4201d22d`
- 출력 보고서: 같은 incoming 아래 `staging/20260722-223045-00ae52e9/output.md` (`BLOCKED`)
- 결과물: 같은 staging의 `artifacts/p5-scanner-matcher.patch` 59,809 bytes, SHA-256 `8ef763d5ad294e803bfb6a2cea7a6e8b56bf2d69efd8b85a084e66a37ae291c0`; `artifacts/verification.txt` 4,188 bytes, SHA-256 `8345024909aaafc3c1ce51f3eb243e7512951beda38c8298033dab8628155f80`
- 인계 식별 오류: 외부 task ID는 `ba-planner-v7-p5-repository-persistence`, 동봉 master prompt는 P2와 `p2-planning-screen.patch`로 잘못 표기됐지만 내부 `output.md`와 artifact는 `ba-planner-v7-p5-scanner-matcher` 부분 증분이다.
- 마스터 검증: ZIP 크기·SHA-256이 사용자 값·manifest·sidecar와 일치하고 artifact 2개의
  크기·SHA-256도 `output.md`와 일치함. HEAD가 슬레이브 baseline `e0740be`와 같고 기존
  worktree 변경과 10개 patch path의 중첩이 없었으며 `git apply --check --verbose` 후 patch를
  clean 적용함. P5 집중 Python 8, 전체 Python 48, Flutter 전체 43, `flutter analyze`, Windows
  release build, `codealmanac validate`, `codealmanac health`, `git diff --check` 통과. 계획 화면
  Widget test 8개에서 current/goal 분리·빈 goal/숫자 0·총 필요량·MockAppService 흐름이
  통과했고 실제 Python stdio 8 tests와 실제 `ProcessAppService` repository restart E2E도 통과함.
- 결정 및 제약: P4 baseline을 선행 gate로 사용하고 candidate 생성과 repository 확정을 분리한다.
  event는 session ID·generation·sequence·정확히 하나의 terminal을 가지며, 낮은 confidence는
  review 없이 commit할 수 없다. 실제 student/inventory adapter 중 하나라도 placeholder이면
  완료가 아니다. UI asset과 recognition asset은 별도 manifest/path를 사용한다.
- 슬레이브 환경: Flutter/Dart SDK와 CodeAlmanac CLI 없음. Python test와 scanner backend,
  fixture·schema·asset·patch 검증은 슬레이브가 수행하고 Dart/Flutter test·analyze·release,
  실제 Dart↔Python event E2E와 Almanac 검증은 마스터 인계 후 필수 gate로 수행한다.
- 인계 차단 이력: 원본 패키지는 실제 Windows student/inventory adapter, recognition asset
  manifest, JSONL event transport와 Dart typed client 미구현으로 `BLOCKED`였고 P5 완료 조건을
  충족하지 못했다. 부분 증분 자체는 마스터가 검증·인수했다.
- 차단 사항: 없음. 남은 구현은 슬레이브가 수행 가능하며 Flutter/Dart/Almanac 실행만
  마스터 인계 후 `MASTER_REQUIRED` gate로 수행한다.
- 다음 행동: follow-up-1 실행 프롬프트를 슬레이브에게 전달하고 결과 인계 대기
- 최종 갱신: 2026-07-22

최종 갱신: 2026-07-22

## 단계별 기록 양식

단계 정의 또는 상태가 확인되면 아래 항목을 해당 단계 섹션으로 추가한다.

```markdown
## P<n> — <단계명>

- 상태: `<상태 값>`
- 목적: `<이 단계가 달성할 결과>`
- 완료 조건: `<마스터가 검증할 조건>`
- 입력: `<input.md 절대경로 또는 저장소 상대경로>`
- 출력 보고서: `<output.md 경로>`
- 결과물: `<artifacts/ 경로와 주요 파일>`
- 검증: `<마스터가 실행하거나 확인한 내용>`
- 결정 및 제약: `<유지해야 할 판단>`
- 차단 사항: `<없음 또는 구체적인 원인>`
- 다음 행동: `<다음 대화에서 바로 수행할 일>`
- 최종 갱신: `<YYYY-MM-DD>`
```

## 대화 간 인계 절차

1. 새 대화에서 이 문서와 현재 대상 단계의 `input.md`를 읽는다.
2. `다음 행동`과 실제 작업 트리·산출물의 상태가 일치하는지 확인한다.
3. 슬레이브 명령에는 [Slave Artifact Handoff](slave-artifact-handoff)의 인계 계약을
   포함한다.
4. 결과를 받은 마스터는 `output.md`와 결과물을 직접 확인한다.
5. 검증 결과, 새 결정과 다음 행동을 이 문서에 기록한 뒤 대화를 마친다.
