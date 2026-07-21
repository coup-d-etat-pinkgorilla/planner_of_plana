# P3 작업 지시 — Repository 특성화와 DTO 분리

## 작업 정보

- 작업 ID: `ba-planner-v7-p3-repository-dto`
- 저장소: 슬레이브 PC의 BA Planner v7 저장소 루트
- 작업 디렉터리: `<SLAVE_REPOSITORY_ROOT>\docs\migration\p3-repository-dto`
- 기준 단계: P0·P1·P2 완료, P3 구현 대상
- 실행 환경: 슬레이브와 마스터는 서로 다른 PC이며 파일시스템을 공유하지 않음

## 목표

v6 `core/repository.py`를 그대로 복사하지 말고, repository가 scanner DTO와 profile
storage에 결합된 지점을 먼저 특성화한다. 학생 현재 상태, 인벤토리, 사용자 목표와
scanner candidate를 UI·scanner·영속 저장 형식에 독립적인 v7 DTO로 분리하고, v6의
학생/인벤토리 병합 및 JSON/SQLite 조회 우선순위를 고정 fixture와 순수 Python test로
재현한다.

P3의 결과는 P4 영구 저장과 P5 scanner protocol이 함께 사용할 **데이터 경계와 회귀
기준**이다. 실제 사용자 프로필, JSON 또는 SQLite에 쓰는 repository는 P3에서 구현하지
않는다.

## 작업 전 필수 확인

다음 파일을 UTF-8로 완전히 읽고, 문서와 코드가 다르면 코드 및 실행 결과를 우선한다.

1. `AGENTS.md`
2. `README.md`
3. `almanac/workflows/p0-p6-workflow-status.md`
4. `almanac/workflows/p0-p6-workflow.md`의 공통 불변식과 P3 절
5. `almanac/architecture/runtime-boundaries.md`
6. `almanac/workflows/slave-artifact-handoff.md`
7. `almanac/workflows/cross-pc-slave-handoff.md`
8. `docs/migration/v6-knowledge-baseline.md`
9. `contracts/README.md`
10. `backend/core/planning.py`
11. `backend/core/planning_calc.py`
12. `backend/core/student_meta_types.py`
13. `backend/core/protocol_v1.py`
14. `backend/tests/test_planning_parity.py`

v6 참조 저장소가 `<SLAVE_REPOSITORY_ROOT>\..\v6`에 있으면 다음 파일도 읽는다.
경로가 다르면 실제 v6 루트를 찾아 동일 파일을 확인한다.

1. `../v6/almanac/architecture/runtime-boundaries.md`
2. `../v6/almanac/decisions/data-bucket-separation.md`
3. `../v6/almanac/gotchas/large-module-change-safety.md`
4. `../v6/almanac/flows/student-scan.md`
5. `../v6/almanac/flows/inventory-scan.md`
6. `../v6/docs/inventory_sorting.md`
7. `../v6/STUDENT_PLANNER_HANDOFF.md`
8. `../v6/core/repository.py`
9. `../v6/core/merge.py`
10. `../v6/core/scanner_shared.py`의 `ItemEntry`, `FieldStatus`, `FieldMeta`,
    `StudentEntry`, `ScanResult`
11. `../v6/core/inventory_profiles.py`
12. `../v6/core/db.py`와 `../v6/core/db_writer.py`
13. repository·merge·inventory profile을 직접 검증하는 v6 테스트

작업을 시작하기 전에 `rg`로 v6 `ScanRepository`, scanner DTO, callback, JSON/SQLite,
profile 및 inventory ordering의 직접 호출자와 문자열 기반 결합까지 조사한다. 조사
결과는 아래 특성화 문서에 파일/심볼/책임 단위로 남긴다.

## 공통 불변식

다음 다섯 데이터 버킷을 DTO, 필드 매핑, fixture와 test에서 명시적으로 구분한다.

1. 스캔된 현재 상태
2. 정적 메타데이터
3. 사용자 목표
4. 보유량 차감 전 총 계산 결과
5. 인벤토리에서 파생한 부족량

- 현재 상태 DTO에 정적 메타데이터, 목표, 계산 결과 또는 부족량을 저장하지 않는다.
- 정적 메타데이터는 기존 `student_meta` API/type 경계를 재사용한다.
- 사용자 목표와 총 계산 결과는 기존 `planning.py` 타입을 우선 재사용하며 같은 의미의
  중복 DTO를 만들지 않는다.
- 부족량은 P3에서 계산하거나 저장하지 않는다. 향후 파생값임을 매핑 문서에만 기록한다.
- 빈 목표는 현재 값을 유지한다는 의미이며 숫자 `0`으로 정규화하지 않는다.
- 낮은 confidence 또는 review-required scanner candidate를 확정 현재 상태로 자동
  승격하지 않는다.

## 구현 범위

### 1. v6 repository 결합 특성화 문서

`docs/migration/p3-repository-dto/repository-characterization.md`를 작성한다. 최소한 다음을
근거 파일과 심볼까지 포함해 기록한다.

- v6 repository의 import 의존성: config/storage path, DB, merge, metadata,
  inventory profile, scanner DTO, DB writer
- `ScanResult`/`StudentEntry`/`ItemEntry`가 repository 입력으로 들어오는 경로와 UI 또는
  callback 결합 지점
- raw scan, current snapshot, history, backup, fast-scan roster, DB snapshot의 책임
- 학생 JSON 조회와 인벤토리 SQLite 우선·JSON fallback/resync의 비대칭
- 손상 JSON, DB 오류, 빈 DB, 누락 파일을 v6가 실제로 처리하는 방식
- 학생 병합, replace mode, authoritative field, history diff의 규칙
- 인벤토리 key 정규화, 중복 선택, 부분 스캔, profile 범위 교체, 정렬과 zero-fill 규칙
- v6 동작 중 그대로 보존할 parity와 P4에서 명시적으로 개선해야 할 위험을 구분한 표

문서는 v6의 동작을 미화하거나 추측하지 말고, 확인되지 않은 사항은
`NOT_VERIFIED`로 표시한다.

### 2. 독립 v7 DTO

`backend/core/` 아래에 이름이 책임을 드러내는 작은 모듈을 만들고 다음 DTO를 정의한다.
정확한 파일명은 현재 코드 구조에 맞춰 선택하되 `output.md`에 선택 근거를 기록한다.

- 학생의 확정된 현재 상태 DTO
- canonical inventory entry 및 inventory snapshot DTO
- 영속화 가능한 사용자 목표를 기존 `StudentGoal`과 연결하는 경계
- scanner candidate DTO와 field-level evidence/status
- repository에 전달되는 commit 입력 DTO 또는 command

DTO 요구사항:

- Python 3.11 표준 라이브러리만으로 직렬화·역직렬화 및 검증 가능해야 한다.
- Qt, Flutter, Pillow image, capture region, matcher 객체, callback, DB connection,
  filesystem path를 필드로 갖지 않는다.
- scanner candidate와 확정 현재 상태는 별도 타입이어야 한다.
- candidate에는 최소한 candidate/session 식별자, 대상 종류, payload, confidence 또는
  field evidence, `review_required`를 표현할 수 있어야 한다.
- 확정 current DTO에는 candidate confidence를 현재값처럼 섞지 않는다. 필요한 provenance는
  별도 명시적 metadata로 제한한다.
- unknown field, 잘못된 타입, 누락 필수 필드, 지원하지 않는 version의 정책을 명시하고
  test한다. 임의로 조용히 버릴지 오류로 만들지 모호하게 두지 않는다.
- canonical JSON 표현은 결정적이어야 하며 fixture round-trip 후 의미와 출력이 안정적이어야
  한다.

scanner candidate는 P5의 session/event protocol을 선점하지 않는 최소 데이터 계약으로
한정한다. scanner 실행, 이미지 처리 또는 event stream은 구현하지 않는다.

### 3. 순수 병합·정규화 로직

filesystem과 DB를 열지 않는 순수 함수로 v6 parity 대상 동작을 구현한다. 최소 범위는
다음과 같다.

학생 상태:

- 새 값 `None`은 기존 값 유지
- level, 성급, 무기/장비 성장치의 v6 max 규칙
- 판독 성공이 명시된 authoritative 무기 필드의 감소 허용
- `unknown` 장비 tier 무시
- 능력치 허용 범위와 범위 밖 값 보존 정책
- 충돌하는 weapon state의 보수적 처리
- form별 combat stats 병합
- replace mode와 실제 변경 field diff

인벤토리:

- item ID 우선 canonical key와 legacy name key 정규화
- 같은 항목 후보가 중복될 때 v6 rank 규칙
- 새 수량이 `None`/빈 문자열이면 기존 값 유지하고 문자열 `"0"`은 유효한 0으로 처리
- 부분 스캔에서 누락 항목 유지
- 명시된 profile만 교체하며, 실제로 스캔되지 않은 profile을 빈 결과로 지우지 않음
- profile의 canonical order 및 누락 항목 zero-fill 결과가 결정적임
- diff가 추가/수량 변경을 표현하고 파생 부족량과 혼합되지 않음

JSON/SQLite 해석:

- 실제 I/O 대신 JSON snapshot과 SQLite row snapshot을 인자로 받는 순수 resolver로 우선순위,
  fallback 및 canonicalization 결과를 표현한다.
- v6의 현재 비대칭을 fixture로 고정하되, P4에서 저장 계층이 사용할 명시적 source/error
  결과를 반환해 조용한 실패에 의존하지 않게 한다.
- P3 테스트는 임시 사용자 profile, 실제 `profiles/`, 실제 DB 또는 v6 파일을 쓰지 않는다.

### 4. v6 parity fixture

`contracts/fixtures/repository_v6_parity.json`을 추가한다. fixture 자체에 format/version과
case ID를 두고, 입력·옵션·기대 canonical 결과·기대 diff 또는 오류를 포함한다.

최소 case:

1. 학생 부분 갱신과 `None` 보존
2. max 규칙과 authoritative 감소의 차이
3. unknown 장비, 범위 밖 stat, weapon state 충돌
4. replace mode
5. form combat stats 병합
6. legacy inventory name key와 item ID key 통합
7. 중복 inventory candidate 선택
8. 부분 inventory scan 및 명시적 `"0"`
9. profile 범위 교체와 미스캔 profile 보존
10. profile order와 zero-fill
11. SQLite non-empty 우선
12. SQLite empty/error 시 JSON fallback
13. 손상/누락/unknown-version 입력 정책
14. 다섯 데이터 버킷 field mapping을 검증하는 대표 round-trip

fixture 기대값은 v6 함수를 일회성 조사 도구로 실행하거나 코드와 기존 테스트를 대조해
확정할 수 있다. 그러나 최종 v7 test와 runtime은 `../v6`를 import하거나 읽으면 안 된다.
fixture provenance, 참조한 v6 심볼과 의도적으로 달라진 정책은 특성화 문서에 기록한다.

### 5. 테스트

`backend/tests/`에 다음을 자동 검증하는 테스트를 추가한다.

- 모든 parity fixture case를 v7 순수 함수로 재생
- DTO canonical JSON round-trip
- scanner/matcher/GUI/v6 import 없이 DTO 및 병합 모듈 import 가능
- 다섯 데이터 버킷의 금지된 필드 혼합 방지
- unknown field, 오래된 version, 누락·손상 payload 정책
- inventory ordering과 zero-fill의 결정성
- fixture에 실제 사용자 경로, 시간, random 값이 없어 반복 실행 결과가 동일함

테스트 수만 늘리기보다 각 fixture case ID가 실패 메시지에 드러나도록 구성한다.

### 6. Repository application service와 protocol method 초안

`docs/migration/p3-repository-dto/repository-protocol-draft.md`에 P4/P5용 초안을 작성한다.
P3에서는 wire schema, dispatcher 또는 Dart client를 구현하지 않는다.

초안에는 다음을 포함한다.

- profile 생성/목록/선택/이름 변경 후보 method
- current students/inventory 조회 및 수정 후보 method
- goals 저장/복원 후보 method
- scanner candidate 검토와 repository commit을 분리하는 후보 method
- request/response DTO, version, structured error와 idempotency/atomicity 고려사항
- 총 필요량과 부족량을 저장 원본으로 취급하지 않는 규칙
- P4 소유 범위와 P5 소유 범위의 명확한 구분

초안은 설계 입력이지 P0 planning protocol v1의 호환 계약 변경이 아니다.

## 금지 및 제외 범위

- v6 `repository.py`, `scanner.py`, `scanner_shared.py`, `db.py`의 통째 복사 금지
- Qt, QML, QWidget, Tkinter, PySide6 presentation/UI orchestration 복사 금지
- `../v6` runtime/test import 또는 v6 경로에 대한 런타임 의존 금지
- 실제 사용자 profile JSON, SQLite, `profiles/`, scan 결과 또는 local DB 쓰기 금지
- 실제 `ScanRepository` 영속 저장 구현, atomic write, migration 실행 금지(P4 범위)
- scanner/matcher/capture/session/event backend 구현 금지(P5 범위)
- Flutter UI, `AppService`, planning protocol schema/dispatcher 변경 금지
- 부족량 계산·저장 또는 총 필요량을 부족량으로 이름 바꾸기 금지
- `backend/core/student_meta_data.py` 광범위 수동 편집 금지
- release/build/cache/log/DB 등 생성·local 상태를 patch에 포함 금지
- P2 미커밋 파일과 관련 없는 사용자 변경 덮어쓰기 금지

기존 계약 변경이 불가피하다고 판단되면 임의로 확장하지 말고 `BLOCKED`로 보고하며,
필요한 변경과 근거를 구체적으로 기록한다.

## 예상 소스 산출물

정확한 모듈 분리는 슬레이브가 현재 구조에 맞춰 결정하되, 완료 시 patch에는 최소한
다음 의미의 결과가 있어야 한다.

- `backend/core/`의 독립 repository DTO 모듈
- `backend/core/`의 순수 병합/정규화 모듈
- `backend/tests/`의 DTO 및 parity fixture test
- `contracts/fixtures/repository_v6_parity.json`
- `docs/migration/p3-repository-dto/repository-characterization.md`
- `docs/migration/p3-repository-dto/repository-protocol-draft.md`

## 검증 명령

저장소 루트에서 다음을 실행하고 결과를 기록한다.

```powershell
cd backend
py -3.11 -m unittest discover -s tests -v

cd ..\frontend
flutter analyze
flutter test
flutter build windows --release

cd ..
codealmanac validate
git diff --check
```

추가로 다음을 검사한다.

```powershell
# 새 backend runtime/test에 v6 또는 GUI/scanner 구현 import가 없는지 확인
rg -n "\.\.[/\\]v6|from core\.scanner|import core\.scanner|PySide6|PyQt|tkinter|qml" backend contracts

# 생성/local 파일이 patch에 포함되지 않았는지 확인
git status --short
```

v6 자체 테스트를 parity 근거로 실행했다면 명령과 결과를 별도로 기록한다. 실행하지 못한
검증은 성공으로 쓰지 말고 `NOT_VERIFIED`와 이유를 남긴다.

## 완료 조건

아래 조건이 모두 충족돼야 `COMPLETED`로 보고한다.

- scanner/matcher 없이 import하고 재생할 수 있는 독립 DTO와 순수 병합 경계가 있다.
- 다섯 데이터 버킷의 필드 매핑이 문서, DTO와 test에 고정됐다.
- v6 학생/인벤토리 병합과 JSON/SQLite 우선순위의 대표 동작이 fixture에 고정됐다.
- v7 test가 `../v6` runtime import 없이 전체 fixture를 통과한다.
- unknown field, version, 누락·손상 데이터 정책과 inventory order/zero-fill이 test된다.
- repository application service/protocol의 P4/P5 경계 초안이 있다.
- 실제 사용자 저장소, scanner backend, Flutter/wire 구현은 추가되지 않았다.
- Python/Flutter test, analyze, Windows release build, Almanac 검증과 `git diff --check`가
  통과했거나, 환경상 실행하지 못한 항목이 `NOT_VERIFIED`로 정직하게 기록됐다.
- 결과 patch와 검증 기록이 아래 인계 계약에 따라 저장됐다.

## 결과물 및 인계 계약

소스는 슬레이브 PC의 작업 트리에서 수정하되, 마스터가 다른 PC에서 재현·검증할 수
있도록 다음 파일을 반드시 만든다.

```text
docs/migration/p3-repository-dto/
├─ input.md                          # 이 파일: 수정·삭제·덮어쓰기 금지
├─ output.md                         # 모든 결과물이 준비된 뒤 마지막에 작성
├─ repository-characterization.md   # patch에도 포함할 P3 소스 문서
├─ repository-protocol-draft.md      # patch에도 포함할 P3 소스 문서
└─ artifacts/
   ├─ p3-repository-dto.patch
   └─ verification.txt
```

- `p3-repository-dto.patch`는 P3에서 생성·수정한 source, fixture, test와 두 P3 문서만
  포함하는 재현 가능한 unified diff여야 한다.
- `input.md`, `output.md`, `artifacts/`, 생성/local 파일 및 기존 무관 변경은 patch에서
  제외한다.
- `verification.txt`에는 실행한 명령, 종료 코드와 핵심 결과를 기록한다. 실행하지 않은
  검증을 통과로 기록하지 않는다.
- 필요하면 추가 결과물을 `artifacts/`에 둘 수 있으나 모두 `output.md`에 기록한다.
- 각 결과물의 존재, 0보다 큰 크기, 바이트 크기와 SHA-256을 확인한다.
- 원래 `input.md`와 기존 결과물을 삭제하거나 덮어쓰지 않는다.
- 결과물을 대화나 임시 경로에만 남기지 않는다.
- 결과물을 영속화할 수 없으면 완료로 보고하지 말고 `BLOCKED`로 보고한다.

`output.md`는 `almanac/workflows/slave-artifact-handoff.md` 계약에 따라 다음을 포함한다.

- 작업 ID와 `COMPLETED`/`BLOCKED` 상태
- 수행 내용과 중요한 판단
- 모든 결과물의 상대경로, 설명, 크기와 SHA-256
- 이 `input.md` 주요 요구사항별 `PASS`/`FAIL`/`NOT_VERIFIED` 및 근거
- 실제 검증 명령과 결과
- v6 대비 의도적 차이, 미완료 사항과 P4/P5 위험

모든 파일이 준비된 뒤 외부 전달 패키지를 만든다.

```powershell
cd "<SLAVE_REPOSITORY_ROOT>"
.\tools\new_cross_pc_handoff.ps1 `
  -TaskDirectory ".\docs\migration\p3-repository-dto" `
  -DestinationDirectory "<SLAVE_OUTBOX_OR_MOUNTED_MASTER_INBOX>" `
  -TaskId "ba-planner-v7-p3-repository-dto"
```

생성된 ZIP, `.sha256`, `.manifest.json`, `-MASTER_PROMPT.md` 네 파일을 모두 전달한다.
같은 신뢰 가능한 사설 Wi-Fi/LAN을 사용하면 마스터가 수신기를 연 뒤 다음처럼 P3
인자를 명시해 송신한다. 현재 wrapper의 기본값은 P2이므로 인자 생략을 금지한다.

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p3-repository-dto" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p3-repository-dto"
```

마스터 수신기의 `WIRELESS_HANDOFF_RECEIVED` 확인 전에는 무선 전달 완료로 보고하지
않는다. 자동 발견이 실패하면 네 파일을 첨부하거나 수동 이동할 수 있게 정확한 경로를
보고한다. 일회용 token은 화면, 저장소, 결과물 또는 로그에 기록하지 않는다.

```text
TASK_OUTPUT_READY
task_id: ba-planner-v7-p3-repository-dto
status: COMPLETED
output_md: <슬레이브 PC의 output.md 절대경로>
artifacts_dir: <슬레이브 PC의 artifacts 절대경로>
artifact_count: <결과물 개수>
handoff_package: <ZIP 절대경로>
handoff_package_size: <바이트>
handoff_package_sha256: <SHA-256>
master_prompt: <-MASTER_PROMPT.md 절대경로>
wireless_transfer: `RECEIVED`, `NOT_REQUESTED` 또는 `FAILED`
```

완료할 수 없으면 다음 형식을 사용한다.

```text
TASK_OUTPUT_BLOCKED
task_id: ba-planner-v7-p3-repository-dto
status: BLOCKED
output_md: <작성했다면 절대경로>
reason: <완료 또는 저장이 불가능한 구체적인 이유>
```

마스터가 `output.md`, 결과물 존재 여부, 크기, SHA-256, diff와 검증 결과를 직접
확인하기 전에는 P3를 완료로 간주하지 않는다.
