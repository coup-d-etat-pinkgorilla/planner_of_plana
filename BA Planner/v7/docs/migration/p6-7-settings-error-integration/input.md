# P6-7 설정 및 통합 오류 처리 입력

## 작업 정보

- 작업 ID: `ba-planner-v7-p6-7-settings-error-integration`
- 선행 단계: 마스터가 독립 검증한 P6-1~P6-6 전체 snapshot
- 결과 단위: 승인된 P6-6 snapshot 위의 P6-7 단일 증분

## 목표

`AppSection.settings` placeholder를 실제 설정 화면으로 교체하고, 프로필·backend·scanner 상태와
복구 action을 한곳에서 제공한다. 모든 기본 탭의 disconnected/loading/empty/error 상태가 데이터
소유자와 복구 경로를 정확히 안내하도록 통합하고, P6의 스캔 → 현재 상태 검토 → 목표 설정 → 총
필요량 → 인벤토리 부족량 → 저장·process restart 복원 흐름을 실제 backend와 Mock 양쪽에서 검증한다.

P6-7은 P6의 마지막 하위 단계지만 슬레이브가 P6 전체를 완료 처리하지 않는다. 결과를 받은 마스터가
patch와 모든 master-only gate를 독립 검증한 뒤에만 workflow의 P6-7과 P6 전체를 완료로 바꾼다.

## 승인 baseline gate

작업 전에 다음을 확인한다.

- P6-1 학생, P6-2 인벤토리, P6-3 스캔, P6-4 홈, P6-5 통계, P6-6 전술대항전이 모두
  service-backed 화면이다.
- P6-6의 tactical contract/storage/service/page/test와 마스터 보정이 현재 snapshot에 포함되어 있다.
- workflow에서 P6-1~P6-6은 `완료`, P6 전체는 `진행 중`, P6-7은 `인계 대기`다.
- 마스터 승인 결과는 Python 79개, Flutter 121개, analyze, Windows release, 실제 process E2E,
  Mock, 1280×720·1440×900·1280×960과 Almanac 검증 통과다.
- 승인 P6-6은 현재 HEAD `e58281e`만으로 재현되지 않는다. P6-6 수락 변경이 commit되지 않은
  작업 트리 snapshot일 수 있으므로 HEAD ID만 비교하지 말고 승인된 수정·신규 경로와 내용을 확인한다.

이 snapshot이 없으면 이전 단계를 재구성하거나 오래된 `origin/main`에서 임의로 시작하지 않는다.
accepted P6-6 snapshot을 요청하고 `BLOCKED`로 보고한다. 기존 사용자 변경과 P6-7 대상 경로가
겹치면 commit, stash, 삭제 또는 덮어쓰기를 하지 않는다.

## 고정 기능 범위

### 1. 설정 화면

- 기본 landing은 선택 프로필과 연결 상태를 함께 보여 주는 `프로필 및 연결` 개요다.
- RepositoryService를 통해 프로필 목록 조회, 생성, 선택, 이름 변경을 제공한다.
- stable profile ID, revision conflict, reload와 profile 전환 후 전 탭 재로딩을 보존한다.
- repository에 삭제 계약이 없으므로 프로필 삭제를 추측해 구현하지 않는다. UI에 필요하면
  `현재 버전에서 지원하지 않음`으로 명시한다. backup/import/restore도 범위 밖이다.
- backend disconnected/connecting/connected 상태를 구분하고 `재연결`, `backend 재시작` action을
  제공한다. action은 single-flight이며 오래된 generation의 성공·실패가 현재 상태를 덮지 않는다.
- scanner readiness와 target 목록을 보여 주고 Scan 탭으로 이동할 수 있게 한다. 설정 화면에서
  scan을 시작하거나 선택 target을 새 저장 계약으로 영속화하지 않는다.
- Adaptive-Sync는 기본 탭이 아닌 보조 page로 유지하고 설정에서 명시적으로 진입시킨다.

### 2. 진단 정보

- protocol version, 연결 상태, backend launcher의 configured/resolved 상태, Python executable/args/
  working directory, scanner readiness와 최근 backend lifecycle/stderr 진단을 typed view로 제공한다.
- 고급 진단은 기본 프로필 action과 분리된 접을 수 있는 section 또는 별도 subsection으로 둔다.
- 최근 진단을 추가한다면 bounded in-memory buffer만 사용한다. 새 log file, database 또는 설정
  persistence를 만들지 않는다.
- 진단 복사는 결정론적인 text report이며 환경변수 값, token, 사용자 payload, 프로필 데이터,
  학생·인벤토리·목표·전술 기록과 임의 파일 내용을 포함하지 않는다.
- 설정 표시만을 위해 backend process를 자동 시작하지 않는다. lazy launcher resolution을 보존하고,
  실제 재연결·재시작 action에서 발생한 오류를 구조화해 표시한다.
- MockAppService 진단은 실제 process를 암시하지 않는 결정론적인 fixture여야 한다.

새 backend wire method는 실제 backend 소유 정보 없이는 만들지 않는다. launcher/최근 stderr처럼 Dart
process client가 이미 소유한 정보는 최소 typed client-side diagnostics 경계로 노출할 수 있다.

### 3. 전 탭 공통 오류·복구

- 공통 recovery model/widget 또는 동등한 typed 계약을 사용해 source, 상태, 사용자 영향과 action을
  일관되게 표현한다. 모든 page를 무차별 재작성하지 말고 기존 page별 상태 모델을 보존한다.
- 오류별 action은 `다시 불러오기`, `재연결`, `backend 재시작`, `설정 열기`, `스캔 열기` 중 실제로
  유효한 경로만 제공한다. 자동 무한 retry와 restart storm을 만들지 않는다.
- partial failure는 성공한 source 데이터를 지우지 않으며 원래 오류를 삼키지 않는다.
- profile 전환, reconnect/restart와 탭 재진입 후 각 data owner가 새 generation으로 reload된다.
- 늦은 이전 profile/process/generation 응답은 새 state, draft 또는 candidate를 덮어쓰지 않는다.
- reconnect/restart는 planning draft, tactical draft, scanner candidate를 자동 commit·삭제·승인하지 않는다.
- scanner session 중 process가 끊기면 session이 계속된 것처럼 표시하지 않는다. candidate가 이미
  존재한다면 명시적 Hold/Approve 경계를 유지하고, 없으면 terminal/disconnected 복구 상태로 간다.
- profile 전환 시 이전 profile의 draft/candidate가 새 profile에 노출되거나 저장되지 않는다.

## 최종 P6 통합 흐름

다음 흐름을 실제 ProcessAppService↔Python과 MockAppService에서 각각 검증할 수 있는 test source와
fixture를 작성한다.

1. 프로필 생성·선택 또는 기존 프로필 선택
2. student/inventory scan readiness와 target 확인, scan candidate 생성
3. candidate를 Hold했을 때 repository가 변하지 않음
4. Approve했을 때 confirmed current/inventory만 명시적으로 저장됨
5. 학생 현재 상태 검토와 명시적 학생 저장
6. 계획 draft 작성·저장, gross total 계산
7. 저장된 inventory와 gross를 사용한 shortage 확인
8. Home/Statistics에서 같은 typed source 결과 확인
9. Tactical match/jokbo 저장과 profile 격리 확인
10. backend 재시작 뒤 profile, current, inventory, goal, shortage와 tactical state 복원
11. 설정의 연결 복구 후 모든 기본 탭 재진입·reload

실제 scanner 장치나 게임 창이 없는 test에서는 deterministic backend fixture/harness를 사용하되 실제
게임 검증이라고 표현하지 않는다. real-process test와 Mock test의 근거를 분리한다.

## UI와 반응형 조건

- no profile, loading, empty, disconnected, partial source error, revision conflict, reconnect/restart 실패와
  recovery 진행 상태를 구분한다.
- action 중 중복 클릭을 막고 keyboard focus, semantic label과 scroll 접근성을 보존한다.
- 긴 프로필·경로·오류·target 이름과 많은 진단 행이 1280×720, 1440×900, 1280×960에서 overflow 없이
  표시되고 핵심 profile/recovery action에 접근 가능해야 한다.
- 현재 `DiagonalSection`, glass/theme, AppShell navigation과 responsive policy를 재사용한다.

## 명시적 제외 범위

- profile 삭제, backup/restore/import/export, installer/update/telemetry/remote support
- 새 settings database/file, 환경변수·token·사용자 payload를 포함한 진단 dump
- 설정 화면에서 scan 시작 또는 target selection 영속화
- 실제 게임 창 smoke를 fixture/Mock로 대체했다는 주장
- P7 이후 tactical scan/history/provenance/statistics/recommendation
- P7 시작, 정식 release 판정과 배포
- Qt/QML/QWidget/Tk/PySide6 코드와 `../v6` runtime import

## 필수 테스트

### Service와 상태

- profile list/create/select/rename, stable ID, revision conflict와 전환 reload
- no service/no profile/disconnected/connecting/partial source error
- reconnect/restart single-flight, 실패, 재시도, generation과 dispose 안전성
- bounded diagnostics, 비밀정보 제거, 결정론적인 copy report와 Mock 표시
- scanner readiness/targets와 Scan deep-link, 설정 화면에서 scan 미실행
- Adaptive-Sync entry
- profile/process 전환에서 draft/candidate 격리와 stale response 보호

### 최종 통합과 회귀

- 실제 Dart↔Python profile/current/inventory/goal/gross/shortage/tactical save→restart→restore
- scanner candidate Hold/Approve 경계와 repository revision/idempotency
- MockAppService의 동일 사용자 흐름과 모든 설정 오류 branch
- P6-1~P6-6 page/service/contract 전체 회귀
- 1280×720·1440×900·1280×960의 populated/error/long-text Widget 또는 golden layout

## 슬레이브 환경 제약

슬레이브 PC에는 Flutter/Dart SDK와 CodeAlmanac CLI가 없다. 설치하거나 공간 확보를 위해 SDK, cache,
repository 또는 사용자 파일을 삭제하지 않는다.

- Python 3.11 test, schema/fixture 검사, 정적 `rg`, `git diff --check`, patch 생성은 수행한다.
- Dart/Flutter source와 test는 반드시 작성한다.
- Flutter/Dart test, analyze, Windows release, 실제 Dart↔Python E2E와 Almanac은 실행한 것처럼 주장하지
  않고 `NOT_VERIFIED`, 근거 첫머리에 `MASTER_REQUIRED:`를 기록한다.
- 도구 부재만으로 전체 작업을 `BLOCKED` 처리하지 않는다.

## 필수 결과물

```text
docs/migration/p6-7-settings-error-integration/
├─ input.md
├─ output.md
└─ artifacts/
   ├─ p6-7-settings-error-integration.patch
   └─ verification.txt
```

patch는 accepted P6-6 snapshot 위의 P6-7 단일 증분이어야 한다. input/prompt/output/artifacts, 이전
patch/handoff, build/cache/profile/database/log/scan result, v6 source/assets와 P7+ 구현을 포함하지 않는다.
모든 patch path는 `BA Planner/v7/...`여야 한다. 전 탭 recovery 연결 때문에 기존 page를 수정했다면
각 경로의 필요성을 기록하고 formatting-only churn을 포함하지 않는다.

## 완료 조건

- Settings placeholder가 실제 profile/connection/scanner/diagnostics/Adaptive-Sync 설정 화면으로 교체된다.
- profile 전환과 backend 복구가 전 탭 reload를 일으키며 stale response와 cross-profile 누출을 막는다.
- 전 탭의 오류가 정확한 data owner와 유효한 recovery action을 제공한다.
- candidate/draft가 복구 과정에서 자동 승인·저장·삭제되지 않는다.
- 실제 process와 Mock의 최종 P6 흐름 및 3 viewport test source가 있다.
- 가능한 Python 회귀와 patch 무결성 검사가 통과한다.
- 두 artifact가 존재하고 `output.md`에 실제 byte size와 SHA-256이 기록된다.

슬레이브의 `COMPLETED`는 구현과 산출물 준비 완료만 뜻한다. 마스터가 전체 gate를 독립 통과시키기 전에는
P6-7 또는 P6 전체 완료를 주장하거나 workflow를 `완료`로 바꾸지 않는다.
