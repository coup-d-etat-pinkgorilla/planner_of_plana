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

2026-07-22 P0 계약, P1 process transport, P2 실제 계획 화면과 P3 repository DTO·병합
parity를 현재 작업 트리에서 마스터가 직접 워크플로 완료 조건과 대조해 보완하고 인수했다. Python test 27개,
Flutter test 39개, `flutter analyze`, 실제 Python process의 세 planning method
종단간 호출, MockAppService 계획 흐름, Almanac 검증과 Windows release build가
통과했다. 변경은 아직 커밋되지 않았다.

| 단계 | 목적 | 상태 | 근거 또는 산출물 | 다음 행동 |
|---|---|---|---|---|
| P0 | planning IPC 계약과 공용 fixture | `완료` | schema·fixture, Python/Dart contract 및 parity test 통과 | 계약 변경 시 양쪽 fixture test 유지 |
| P1 | Python JSONL process와 Dart client | `완료` | lifecycle·오류·실제 세 method E2E 및 release build 통과 | P2가 `AppService` planning method만 사용하도록 유지 |
| P2 | 실제 계획 화면 수직 슬라이스 | `완료` | 인계 patch 적용 후 마스터 보완, Widget test 8개와 전체 39개·실제 backend·Mock·release 통과 | P4/P6 전까지 in-memory·총 필요량 경계 유지 |
| P3 | repository 특성화와 DTO 분리 | `완료` | 원본과 followup 2건 적용, DTO·fixture·비중첩·전체 검증 통과 | P4에서 승인된 DTO·병합 계약 유지 |
| P4 | 프로필과 repository 영구 저장 | `대기` | P3 승인 baseline과 `input.md`·슬레이브 실행 프롬프트 작성 | 지시를 슬레이브에 전달하고 P4 인계 대기 |
| P5 | scanner/matcher session protocol과 backend | `대기` | 없음 | P3/P4 경계 인수 후 event schema부터 작성 |
| P6 | 전 기본 탭 실제 데이터 통합 | `대기` | 현재 홈 골격과 placeholder 페이지 | P2·P4·P5 인수 후 P6-1 학생부터 진행 |

## 현재 결정

- P0은 planning wire 계약, P1은 그 계약의 실제 process transport로 분리한다.
- P2에서 계획 탭을 먼저 실제화하고 P6에서는 repository·scanner 결과까지 통합한다.
- P3는 실제 repository 쓰기보다 DTO와 v6 병합 parity를 먼저 완료한다.
- P5는 scanner 결과 생성과 repository 확정을 분리한다.
- P6은 학생 → 인벤토리 → 스캔 → 홈 → 통계 → 전술대항전 → 설정 순서로 진행한다.
- P6 완료는 정식 출시가 아니라 통합 베타 기준이다.
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

1. `docs/migration/p4-repository-persistence/slave-execution-prompt.md`를 슬레이브에게 전달한다.
2. P4 전까지 P2 계획 상태는 in-memory이며 임시 현재 상태임을 유지한다.
3. P6 전까지 P2 결과는 보유량 차감 전 총 필요량이며 부족량을 표시하지 않는다.
4. 슬레이브는 P3 승인 baseline gate가 모두 통과한 경우에만 P4 구현을 시작한다.

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

- 상태: `대기`
- 목적: Python backend가 프로필, 확정 현재 상태, 인벤토리와 사용자 목표의 안전한 저장·복원을 소유
- 완료 조건: 재실행 복원, atomic failure 시 기존 데이터 보존, revision/idempotency 및 손상·병합 fixture, Python/Dart contract와 전체 검증 통과
- 입력: `docs/migration/p4-repository-persistence/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p4-repository-persistence/slave-execution-prompt.md`
- 출력 보고서: 인계 전이므로 없음
- 결과물: 인계 전이므로 없음
- 검증: P3 승인 baseline을 P4 변경 전 필수 gate로 고정하고 P4 범위·금지 경계·인계 계약을 워크플로 정의와 대조함
- 결정 및 제약: P4는 저장·profile·repository protocol과 최소 profile UI만 구현하며 scanner session/backend는 P5, 전 탭 통합은 P6에 남김
- 차단 사항: 없음
- 다음 행동: 슬레이브에 실행 프롬프트를 전달하고 `output.md`, P4 증분 patch와 검증 기록 인계 대기
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
