# P5 보완 작업 지시 1 — 실제 adapter, event transport와 Dart typed client

## 작업 정보

- 작업 ID: `ba-planner-v7-p5-scanner-matcher-followup-1`
- 작업 디렉터리: `<SLAVE_REPOSITORY_ROOT>\docs\migration\p5-scanner-matcher-followup-1`
- 기준 상태: P4 완료 baseline 위에 마스터가 인수한 P5 부분 증분이 적용된 tree
- patch 성격: 인수된 P5 부분 증분 위의 단일 후속 증분
- 슬레이브 환경: Windows/Python 3.11 사용 가능, Flutter/Dart SDK와 CodeAlmanac CLI 없음

## 마스터 인수 상태

마스터는 다음 패키지의 내부 `p5-scanner-matcher.patch`를 검증·적용했다.

- 외부 패키지 task ID: `ba-planner-v7-p5-repository-persistence`(잘못된 이름)
- 실제 내부 작업 ID: `ba-planner-v7-p5-scanner-matcher`
- ZIP SHA-256: `5ee0b0492c264d6c4ff2f542cdd8fbbe0bd4de57ce019e2b078cbedd4201d22d`
- 인수 patch SHA-256: `8ef763d5ad294e803bfb6a2cea7a6e8b56bf2d69efd8b85a084e66a37ae291c0`
- 원래 baseline commit: `e0740be8951546034144a3eabd5aecea4493e459`

인수된 부분 증분은 scanner protocol schema/fixture, headless session service, candidate review와
P4 repository commit port만 구현한다. 마스터 검증에서 P5 집중 Python 8, 전체 Python 48,
Flutter 43, analyze, Windows release와 Almanac이 통과했다. P5 단계는 아직 완료되지 않았다.

## 목표

부분 증분에서 빠진 다음 네 production 경계를 구현해 P5 완료 후보를 만든다.

1. 실제 Windows student/inventory capture·input·matcher adapter
2. production recognition asset 선택·manifest·hash·runtime resolution
3. Python JSONL response/event multiplex와 lifecycle/backpressure
4. Dart typed scanner client/service와 실행 가능한 test source

슬레이브는 1~3과 Python test를 직접 실행한다. 4의 source와 test는 작성하되 SDK를 설치하거나
실행하지 않고 `MASTER_REQUIRED`로 인계한다. 도구 부재만으로 `BLOCKED` 처리하지 않는다.

## 작업 전 필수 확인

다음을 UTF-8로 처음부터 끝까지 읽는다.

1. `AGENTS.md`, `README.md`
2. `almanac/workflows/p0-p6-workflow-status.md`의 P4·P5 절
3. `almanac/workflows/p0-p6-workflow.md`의 공통 불변식과 P5 절
4. `almanac/workflows/slave-artifact-handoff.md`
5. `almanac/workflows/cross-pc-slave-handoff.md`
6. `docs/migration/p5-scanner-matcher/input.md`
7. `docs/migration/p5-scanner-matcher/scanner-characterization.md`
8. `docs/migration/p5-scanner-matcher/scanner-runtime.md`
9. `backend/core/scanner_protocol_v1.py`, `scanner_session.py`
10. `backend/tests/test_scanner_protocol_contract.py`, `test_scanner_session.py`
11. `contracts/scanner-protocol-v1.schema.json`, `fixtures/scanner_protocol_v1.json`
12. `backend/core/application_protocol_v1.py`, `stdio_server.py`, `backend_process.py`
13. `frontend/lib/services/backend_process.dart`, `planning_protocol_client.dart`,
    `process_app_service.dart`, `app_service.dart`, `repository_service.dart`
14. 관련 Python·Dart process/contract/repository test

v6에서는 `../v6/almanac/flows/student-scan.md`, `inventory-scan.md`,
`docs/inventory_scan_algorithm.md`, `docs/inventory_sorting.md`, `core/capture.py`,
`core/scanner.py`, `core/scanner_components/`, `core/matcher.py`, inventory matcher 모듈,
`regions/`, `templates/`와 실제 호출자를 다시 대조한다. Qt/Tk callback과 presentation 코드는
복사하지 않는다.

## 인수 baseline gate

변경 전에 다음을 재현한다.

1. 인수된 10개 P5 경로가 존재한다.
2. scanner fixture version 1, 15 cases(valid 9, invalid 6)다.
3. `py -3.11 -m unittest tests.test_scanner_protocol_contract tests.test_scanner_session -v`가
   8 tests를 통과한다.
4. 전체 Python suite가 48 tests를 통과한다.
5. `git diff --check`가 통과한다.
6. 실제 Windows adapter, asset manifest, stdio event transport와 Dart scanner client가 아직
   없다는 부분 증분 상태가 일치한다.

하나라도 다르면 누락된 부분 증분을 추측해 재구성하지 않는다. 실제 차이를 기록하고
`BLOCKED`로 보고한다. Flutter/Dart/CodeAlmanac 도구 부재는 gate 불일치가 아니다.

### 증분 patch 기준 만들기

이전 부분 증분이 슬레이브 tree에서 아직 uncommitted라면 먼저 위 gate와 10개 경로가 마스터
인수본과 같은지 확인한다. 그 상태만 담은 로컬 baseline commit을 만들고 commit ID를
`verification.txt`에 기록해도 된다. push하지 않는다. follow-up patch는 그 baseline commit
이후 변경만 포함해야 하며 이전 59,809-byte patch 전체를 다시 포함하면 안 된다.

기존 부분 증분 외 사용자 변경이 있으면 임의 commit·stash·삭제하지 말고 중첩 경로를 기록해
`BLOCKED`로 보고한다.

## 필수 구현

### 1. 실제 Windows capture와 input adapter

`scanner_session.ScannerSessionService`가 사용하는 port에 실제 Windows 구현을 연결한다.

- 대상 창 열거와 stable target ID/title/status
- closed/minimized/background/foreground 진단
- client-area 캡처와 실제 해상도 기록
- 비율 ROI crop, stable-frame 대기, timeout와 cooperative cancellation
- 안전한 click/scroll/navigation 경계
- import 시 창 열거·캡처·입력·사용자 경로 쓰기 없음
- 모든 Windows/native 호출을 작은 adapter에 격리해 headless fake test 유지

v6 `capture.py`를 통째로 복사하지 않는다. 필요한 Win32/Pillow 기능만 port 계약에 맞춰 옮기고
오류를 안정적인 scanner error/event로 변환한다.

### 2. 실제 student matcher adapter

최소 production 학생 scan 수직 슬라이스를 placeholder 없이 연결한다.

- 학생 식별
- P3 `ConfirmedStudent`가 허용하는 current field 판독
- field별 value/status/source/score/confidence evidence
- region/template 누락과 낮은 confidence의 review-required 처리
- fallback과 retry가 취소 token을 관측
- 정적 metadata, goal, 총 필요량과 shortage를 candidate에 넣지 않음

v6 알고리즘을 축소하면 축소 범위와 후속 위험을 문서화하되, fake matcher를 production
adapter로 등록하지 않는다.

### 3. 실제 inventory matcher adapter

최소 production inventory scan 수직 슬라이스를 연결한다.

- profile별 정렬·후보 제한과 zero-fill 계약
- grid/icon/count fast path
- confidence/margin 부족 시 상세 fallback
- scroll motion/overlap, tail/empty/near-zero 종료 판정
- 이미 확인한 anchor와 낮은 confidence 결합 방지
- canonical `InventorySnapshot` candidate 생성

학생과 inventory 중 하나라도 production path가 fake/placeholder면 `COMPLETED`로 보고하지
않는다.

### 4. Recognition asset manifest와 runtime path

필요한 production region/template/config만 v7 backend 전용 경로에 포함한다.

- manifest version과 각 파일의 상대경로, scan kind, 용도, 크기, SHA-256
- 필수/선택, 지원 해상도, fallback과 source version
- 시작 전 누락·손상·version mismatch 검사
- backend 개발/release runtime resolution
- test fixture image와 production asset 분리
- 계정별 adaptive sample의 writable local 경로와 배포 제외

Flutter UI asset, v6 debug crop/cache/temp와 사용자 profile sample을 포함하지 않는다. binary
asset은 patch와 ZIP에서 손실 없이 재현돼야 한다.

### 5. Python JSONL event transport

`ScannerProtocolV1`을 실제 `ApplicationProtocolV1`/backend process에 연결하고 scanner event를
stdout JSONL로 multiplex한다.

- response와 event line의 원자적 직렬화
- 여러 worker의 line interleaving 금지
- start response가 client에 관측되기 전 event 유실/race 방지
- bounded queue와 progress coalescing/backpressure
- candidate와 terminal event는 drop 금지
- planning/repository request correlation과 기존 fatal policy 회귀 없음
- cancel/snapshot/restart/dispose에서 worker와 queue 정리
- stderr 진단과 protocol stdout 분리

`ScannerProtocolV1.handle()`도 공통 trusted envelope/version/type 정책을 거치게 한다. schema에
맞지 않는 성공/event를 runtime에서 무검사 통과시키지 않는다.

### 6. Dart typed scanner client/service source

Flutter/Dart SDK 없이 기존 source/test 패턴을 따라 구현한다.

- response와 event demultiplex
- immutable typed target/session/event/candidate/evidence model
- session ID/generation/sequence cursor와 stale/duplicate/gap/terminal 정책
- start response/event race buffer
- target list, readiness, start, cancel, snapshot, review와 commit API
- disconnect/restart/dispose 시 subscription과 pending state 정리
- `ProcessAppService.startScan()` 실제 연결과 readiness 기반 `scanAvailable`
- `MockAppService`의 결정적 동일 use case
- malformed event의 session-scoped 또는 fatal 정책

production 스캔 탭 UI는 만들지 않는다. Dart contract/client/service test와 실제 Python process
event E2E test source를 작성하며 skip이나 조건부 pass를 넣지 않는다.

### 7. 문서 정합성

`contracts/README.md`, `scanner-characterization.md`, `scanner-runtime.md`와 asset manifest 설명을
실제 구현에 맞춘다. 슬레이브는 workflow status를 `완료`로 바꾸지 않는다.

## 필수 Python 테스트

1. 실제 adapter module import가 side effect와 GUI/v6 runtime import 없이 가능
2. script/fake capture와 실제 image fixture를 통한 student/inventory production adapter
3. target closed/minimized, capture failure, timeout와 cancellation
4. field evidence와 낮은 confidence review-required
5. grid/count/detail fallback과 scroll overlap/terminal
6. asset manifest 전체 파일 크기·SHA-256·누락/손상/version mismatch
7. stdio start response/event 순서와 concurrent line atomicity
8. backpressure에서 progress만 coalesce되고 candidate/terminal은 보존
9. cancel/restart/dispose worker·queue cleanup
10. planning/repository stdio 회귀와 scanner request/event schema

## 슬레이브 필수 검증

```powershell
cd backend
py -3.11 -m unittest tests.test_scanner_protocol_contract tests.test_scanner_session -v
py -3.11 -m unittest discover -s tests -v

cd ..
git diff --check
```

신규 adapter/asset/stdio test를 각각 단독 실행하고 명령, exit code, case/event/asset 수와
취소·hash·queue 보존 결과를 `verification.txt`에 기록한다. 실제 게임 창 smoke가 안전하게
가능하면 student/inventory 각각 수행하고, 불가능하면 `NOT_VERIFIED`로 남긴다.

## MASTER_REQUIRED

슬레이브는 다음 명령을 실행하거나 SDK를 설치하지 않는다. Dart/Flutter source와 test는
작성하고 마스터가 실행할 정확한 파일·test 이름을 기록한다.

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

마스터는 실제 Dart `ProcessAppService` ↔ Python scanner event E2E, process restart/dispose와
release asset resolution도 단독 확인한다.

## 슬레이브 완료 조건

다음이 모두 충족돼야 산출물 인계를 `COMPLETED`로 보고한다.

- 이전 부분 증분 baseline과 전체 Python 회귀 유지
- student/inventory production adapter가 placeholder 없이 연결되고 image fixture test 통과
- recognition manifest의 모든 production asset hash/readiness 통과
- JSONL response/event multiplex와 cleanup Python test 통과
- Dart typed client/service와 실행 가능한 test source 포함
- MASTER_REQUIRED 항목을 통과로 가장하지 않고 `NOT_VERIFIED`로 기록
- 이전 부분 patch를 재포함하지 않은 follow-up 단일 증분
- artifact와 cross-PC 인계 계약 충족

실제 adapter, asset manifest, JSONL transport 또는 Dart source 중 하나라도 빠지면
`BLOCKED`로 보고한다. Flutter/Dart/CodeAlmanac 미실행만으로는 `BLOCKED` 처리하지 않는다.

## 결과물과 인계

```text
docs/migration/p5-scanner-matcher-followup-1/
├─ input.md
├─ slave-execution-prompt.md
├─ output.md
└─ artifacts/
   ├─ p5-scanner-matcher-followup-1.patch
   └─ verification.txt
```

- patch는 인수된 P5 부분 증분 위의 단일 후속 증분이다.
- 모든 diff path는 `BA Planner/v7/...` prefix를 사용한다.
- input/prompt/output/artifacts, 이전 patch, build/cache/debug crop/user sample을 포함하지 않는다.
- `git apply --check --verbose`에서 모든 path Checking, skipped 0을 확인한다.
- artifact 크기·SHA-256을 `output.md`에 기록한다.
- `output.md`와 `MASTER_PROMPT.md`에 MASTER_REQUIRED 명령을 포함한다.

마스터 receiver와 슬레이브 sender task ID는 모두 다음을 사용한다.

```text
ba-planner-v7-p5-scanner-matcher-followup-1
```

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p5-scanner-matcher-followup-1" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p5-scanner-matcher-followup-1"
```

마스터가 결과를 직접 검증하기 전에는 P5를 완료로 판정하지 않는다.
