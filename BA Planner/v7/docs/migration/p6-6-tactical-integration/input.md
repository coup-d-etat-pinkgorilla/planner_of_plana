# P6-6 전술대항전 실제 데이터 통합 입력

## 작업 정보

- 작업 ID: `ba-planner-v7-p6-6-tactical-integration`
- 선행 단계: 마스터가 독립 검증한 P6-5 통계 통합
- 결과 단위: 승인된 P6-5 snapshot 위의 P6-6 단일 증분

## 목표

`AppSection.pvp` placeholder를 선택 프로필의 실제 학생 catalog와 confirmed current를 사용하는
전술대항전 화면으로 교체한다. 사용자는 4 Striker + 2 Special 슬롯의 공격·방어 덱을 구성하고,
공격/방어 전적과 메모를 프로필별로 저장·복원하며, 기록과 수동 족보를 검색·필터·재사용할 수
있어야 한다.

P6-6은 전술대항전의 수동 기본 기능만 소유한다. 로비 스캔, 상대 identity/history, 방어 snapshot,
provenance 확장, 승률·빈도 통계, 변경 감지, 예상 방어덱, 추천과 공유 분석은 P7~P13 범위다.

## 승인 baseline gate

작업 전에 다음을 확인한다.

- P6-1 StudentPage, P6-2 InventoryPage, P6-3 ScanPage, P6-4 HomePage, P6-5 StatisticsPage가
  service-backed 화면이다.
- P6-5의 인벤토리 `absent`/`unknown` 분리와 유효 범위 student statistics 보정이 포함되어 있다.
- workflow에서 P6-1~P6-5는 `완료`, P6 전체는 `진행 중`이다.
- 마스터 승인 결과는 Python 72개, Flutter 106개, analyze, Windows release, 실제 process E2E,
  Mock, 1280×720·1440×900·1280×960과 Almanac 검증 통과다.

이 snapshot이 없으면 이전 단계를 재구성하거나 오래된 `origin/main`에서 임의로 시작하지 않는다.
accepted P6-5 snapshot을 요청하고 `BLOCKED`로 보고한다. 기존 사용자 변경과 P6-6 대상 경로가
겹치면 commit, stash, 삭제 또는 덮어쓰기를 하지 않는다.

## 참조와 해석 원칙

- `../v6/core/tactical_challenge.py`, `../v6/docs/ui-behavior/tactical.md`와 v6 tactical tests는
  동작 특성화 자료로만 사용한다.
- v6의 Qt/QML/PySide presentation, SQLite facade 또는 import/export 코드를 복사하지 않는다.
- 학생은 표시 이름이 아니라 v7 canonical `student_id`로 저장한다.
- v6 이름·줄임말 문자열 저장을 그대로 답습하지 않는다.
- P6에서 불명확한 로비 관측·가려진 슬롯·출처·예측 의미를 추측해 계약에 넣지 않는다.

## P6-6 고정 데이터 계약

### 1. TacticalDeck v1

- `strikers`: 정확히 4개의 slot. 각 값은 canonical student ID 또는 `null`이다.
- `specials`: 정확히 2개의 slot. 각 값은 canonical student ID 또는 `null`이다.
- slot 순서를 보존한다. 중간 빈 slot을 압축하거나 뒤의 학생을 앞으로 당기지 않는다.
- 같은 덱 안에서 같은 student ID의 중복 배치를 금지한다.
- 사용자 자신의 덱은 confirmed current에 있고 catalog의 combat class가 해당 slot과 일치하는 학생만
  선택할 수 있다.
- 상대 덱과 족보 대상 덱은 catalog 전체에서 선택할 수 있지만 class 규칙은 동일하다.
- repository-only ID 또는 missing combat class는 evidence에는 보존하되 새 slot 선택 후보로 추측하지 않는다.

### 2. TacticalMatch v1

최소 필드는 다음과 같다.

- `version: 1`
- stable `match_id`
- `kind`: `attack` 또는 `defense`
- `occurred_on`: ISO `YYYY-MM-DD` 또는 명시적인 `null`
- trimmed `season`, `opponent`, `notes`
- `result`: `win` 또는 `loss`
- `attack_deck`, `defense_deck`

`kind=attack`이면 attack은 내 덱, defense는 상대 덱이다. `kind=defense`이면 attack은 상대 덱,
defense는 내 덱이다. UI와 test에서 이 방향을 명시한다. 날짜 없음은 오늘로 바꾸지 않으며 별도
`날짜 없음`으로 표시한다. 상대는 비어 있을 수 없다. P6-6에서 source/confidence/observed time이나
예측 field를 만들지 않는다.

### 3. TacticalJokbo v1

최소 필드는 `version: 1`, stable `jokbo_id`, `defense_deck`, `attack_deck`, `notes`다. 족보는
수동으로 저장한 대응 덱 pair이며 관측 승률, 추천 점수 또는 예측이 아니다. 빈 defense/attack 덱은
저장하지 않는다.

### 4. Profile-scoped tactical state

- tactical state는 `version: 1`, 독립된 non-negative revision, matches, jokbo를 가진다.
- 선택 프로필마다 격리하고 새 backend process에서도 복원한다.
- 다섯 planning/repository bucket 안에 tactical record를 current, goal, gross 또는 shortage처럼 섞지 않는다.
- Python backend만 atomic persistence를 소유한다. Flutter는 JSON/SQLite/profile 파일을 직접 읽지 않는다.
- stale revision은 fail-closed, idempotency key 재시도는 중복 write가 없어야 한다.
- partial/failed write는 기존 tactical state와 revision을 보존한다.

## 최소 wire/service 경계

P6-6 전용 versioned schema와 Python/Dart 공용 fixture를 추가하고 다음 의미를 제공한다.

- `tactical.state.get`
- `tactical.match.upsert`
- `tactical.match.delete`
- `tactical.jokbo.upsert`
- `tactical.jokbo.delete`

조회는 `profile_id`, mutation은 `profile_id`, `expected_revision`, `idempotency_key`와 대상 DTO/ID를
사용한다. method 이름을 바꿀 필요가 있다면 같은 의미와 strict schema를 유지하고 결정 근거를
`verification.txt`에 기록한다. request/response의 unknown field, bool-as-int, 잘못된 version/ID/date,
slot 수·중복·class 위반을 양쪽 contract test로 거부한다.

P7의 import/provenance/snapshot/query/statistics 계약을 앞당겨 추가하지 않는다. P7 특성화 때 호환 확장할
수 있도록 P6 DTO는 작고 명시적으로 유지한다.

## UI와 사용자 흐름

### 기록 mode

- 첫 화면은 저장된 기록 목록과 명확한 `새 전적` action으로 한다.
- 선택 프로필 ID/name과 tactical revision, backend 연결 상태를 표시한다.
- 상대, student ID/display label, kind, result, season과 날짜 범위로 검색·필터한다.
- 정렬은 occurred date 내림차순, 날짜 없음 마지막, stable ID tie-break로 결정론적이어야 한다.
- 기록 상세에서 수정, 삭제 확인, `새 기록으로 복사`를 제공한다. 복사는 원본 ID를 유지하거나 원본을
  mutate하지 않는 새 draft다.

### 편집 mode

- 공격/방어 기록 종류, 날짜 없음 여부, 시즌, 상대, 승패, 메모를 편집한다.
- 4 Striker + 2 Special의 공격·방어 슬롯을 시각적으로 구분한다.
- 학생 검색은 display label을 제공하되 저장값과 selection key는 canonical ID다.
- 내 덱 후보는 confirmed owned 학생으로 제한한다. 상대 덱은 catalog 전체를 사용할 수 있다.
- 저장 전 기록 종류에 따른 내 덱/상대 덱 방향을 다시 표시한다.
- validation 실패는 기존 저장값과 목록을 바꾸지 않는다.

### 족보 mode

- defense deck/student와 text로 수동 족보를 검색한다.
- 족보 상세에서 수정, 삭제 확인과 `새 공격 기록으로 복사`를 제공한다.
- 복사된 draft는 새 match ID를 사용하고 족보 원본은 유지한다.

### 상태와 반응형 UI

- Repository/Tactical service 부재, disconnected/connecting, no profile, loading, empty, source error,
  validation error, revision conflict, save/delete failure와 retry를 구분한다.
- refresh, profile 변경, backend recovery와 PVP 탭 재진입 시 reload한다.
- 늦은 이전 generation 응답은 새 profile/state/draft를 덮어쓰지 않는다.
- `DiagonalSection`, 현재 glass/theme와 scroll composition을 재사용한다.
- 긴 이름·상대·시즌·메모, 많은 기록과 1280×720·1440×900·1280×960에서 overflow 없이 편집·저장·
  검색·상세 action에 접근 가능해야 한다.

## 명시적 제외 범위

- 게임 창/폴더/clipboard screenshot 분석, tactical scanner와 recognition asset
- v6 Excel/CSV import/export와 줄임말 사전
- 로비 순위·상대 이름 OCR/template, refresh generation과 opponent identity
- 상대 방어 이력, hidden/visible observation slot, provenance와 confidence
- 승률, 학생 빈도, 신선도, 변경 감지, 추천, 예상 방어덱, 공유 분석
- P6-7 설정·통합 오류 처리와 P6 전체 완료 판정
- Qt/QML/QWidget/Tk/PySide6 코드와 v6 runtime import

## 필수 테스트

### Python/contract

- valid/invalid shared fixture와 Python/Dart schema parity
- fixed 4+2 slot, order/null preservation, duplicate/class/date/version/unknown-field rejection
- profile isolation, create/update/delete, stale revision과 idempotent retry
- atomic failure preservation과 process restart restore
- display name 변경과 무관하게 canonical student ID 보존
- 전술 데이터가 repository current/goals/inventory와 분리됨

### Dart/service/UI

- exact ProcessAppService requests와 typed responses/errors
- MockAppService deterministic empty/data/save/edit/delete/revision-failure flows
- owned-only own-deck selector, catalog-wide opponent selector와 combat class filtering
- attack/defense direction, incomplete slot, date-null과 validation
- 상대/student/kind/result/season/date filter와 deterministic sorting
- match/jokbo copy가 새 draft ID를 쓰고 원본을 mutate하지 않음
- partial failure, refresh/re-entry, profile change와 stale generation protection
- 실제 Dart↔Python save → process restart → restore E2E
- P6-1~P6-5, planning/repository/scanner 기존 회귀
- 1280×720·1440×900·1280×960 Widget/golden overflow와 action 접근성

실제 게임 창 smoke는 P6-6 필수 조건이 아니다. fixture/Mock 결과를 실제 게임 검증으로 표현하지 않는다.

## 슬레이브 환경 제약

슬레이브 PC에는 Flutter/Dart SDK와 CodeAlmanac CLI가 없다. 설치하거나 공간 확보를 위해 SDK, cache,
repository 또는 사용자 파일을 삭제하지 않는다.

- Python 3.11 test, schema/fixture 검사, 정적 `rg`, `git diff --check`, patch 생성은 수행한다.
- Dart/Flutter source와 test는 반드시 작성한다.
- Flutter/Dart test, analyze, Windows release, 실제 Dart↔Python E2E와 Almanac은 실행한 것처럼 주장하지 않고
  `NOT_VERIFIED`, 근거 첫머리에 `MASTER_REQUIRED:`를 기록한다.
- 도구 부재만으로 전체 작업을 `BLOCKED` 처리하지 않는다.

## 필수 결과물

```text
docs/migration/p6-6-tactical-integration/
├─ input.md
├─ output.md
└─ artifacts/
   ├─ p6-6-tactical-integration.patch
   └─ verification.txt
```

patch는 accepted P6-5 snapshot 위의 P6-6 단일 증분이어야 한다. input/prompt/output/artifacts, 이전
patch/handoff, build/cache/profile/database/log/scan result, v6 source/assets와 P6-7/P7+ 구현을 포함하지 않는다.
모든 patch path는 `BA Planner/v7/...`여야 한다.

## 완료 조건

- PVP placeholder가 실제 학생과 profile-scoped tactical service를 쓰는 화면으로 교체된다.
- 4+2 slot, attack/defense 방향, canonical ID와 owned/catalog 후보 경계가 보존된다.
- match/jokbo create·edit·delete·search·filter·copy와 restart restore가 구현된다.
- strict contract, atomic persistence, revision/idempotency와 profile isolation이 test로 보호된다.
- loading/empty/disconnected/error/retry/re-entry/stale generation과 3 viewport test source가 있다.
- 가능한 Python 회귀와 patch 무결성 검사가 통과한다.
- 두 artifact가 존재하고 `output.md`에 실제 byte size와 SHA-256이 기록된다.

슬레이브의 `COMPLETED`는 구현과 산출물 준비 완료만 뜻한다. 마스터가 모든 전용 gate를 독립 통과시키기
전에는 P6-6 완료를 주장하지 않는다. P6-7과 최종 통합 흐름이 남으므로 P6 전체 완료도 주장하지 않는다.
