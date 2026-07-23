# 슬레이브 실행 프롬프트

BA Planner v7 P6-6 전술대항전 실제 데이터 통합을 수행하고 cross-PC 인계 패키지를 생성하십시오.

작업 ID:

```text
ba-planner-v7-p6-6-tactical-integration
```

먼저 다음을 처음부터 끝까지 읽으십시오.

- `docs/migration/p6-6-tactical-integration/input.md`
- `README.md`, `AGENTS.md`
- `docs/migration/v6-knowledge-baseline.md`
- `almanac/workflows/p0-p6-workflow.md`의 공통 불변식과 P6 절
- `almanac/workflows/p0-p6-workflow-status.md`의 P6-1~P6-6 절
- `almanac/workflows/p7-p13-tactical-backend-workflow.md`의 P6/P7 경계와 P7 이후 제외 범위
- `almanac/design/frontend-section-direction-and-user-flows.md`의 공통 규칙과 전술대항전 탭 절
- `almanac/design/responsive-diagonal-layout-policy.md`
- `almanac/workflows/slave-artifact-handoff.md`, `cross-pc-slave-handoff.md`
- P6-1~P6-5 input과 마스터 승인 결과
- `../v6/docs/ui-behavior/tactical.md`, `../v6/core/tactical_challenge.py`와 tactical tests는 behavior reference만 사용
- 현재 planning/repository/scanner contract, schema, fixture와 Python/Dart process E2E
- `frontend/lib/services/`의 AppService/RepositoryService/ProcessAppService/MockAppService
- `frontend/lib/ui/app_shell.dart`, `app_section.dart`, 실제 학생·계획·인벤토리·스캔·홈·통계 page와 test

이 작업은 P6 전체 또는 P7이 아닙니다. accepted P6-5 snapshot 위에서 전술대항전의 수동 기본 기능만
구현하십시오. P6-7 설정·통합 오류 처리, 로비 스캔, 상대 identity/history, provenance, 전술 통계,
변경 감지, 예측·추천과 공유 분석을 구현하지 마십시오.

변경 전 baseline gate:

- P6-1~P6-5의 모든 기본 탭이 service-backed 화면
- 선택 profile, 실제 student catalog/current와 repository restart restore 경계 존재
- P6-5의 `absent`/`unknown` 분리와 out-of-range student 통계 보정 포함
- workflow에서 P6-1~P6-5 `완료`, P6 전체 `진행 중`
- 승인 시점 Python 72, Flutter 106, analyze, Windows release, process E2E, Mock, 3 viewport, Almanac 통과

이 승인본이 없으면 이전 단계를 재구성하거나 오래된 `origin/main` 위에서 시작하지 마십시오. `BLOCKED`로
보고하고 accepted P6-5 snapshot을 요청하십시오. P6-5가 아직 commit되지 않은 snapshot이라면 HEAD ID만으로
동일하다고 판단하지 말고 승인된 변경 경로와 내용을 확인하십시오. baseline ID, P6-5 포함 경로와 dirty-path
판단을 `verification.txt`에 기록하십시오. 다른 사용자 변경과 대상 경로가 겹치면 commit·stash·삭제하지 말고
`BLOCKED`로 보고하십시오. 승인 snapshot을 local baseline commit으로 고정할 수는 있으나 push하지 마십시오.

`input.md`의 계약을 그대로 구현하십시오.

1. `AppSection.pvp` placeholder를 실제 TacticalPage로 교체
2. canonical student ID를 저장하는 fixed 4 Striker + 2 Special slot model
3. confirmed owned-only 내 덱과 catalog-wide 상대/족보 덱 후보 경계
4. attack/defense 방향, nullable occurred date, season/opponent/result/notes가 있는 match v1
5. defense/attack pair와 notes만 가진 수동 jokbo v1
6. profile-scoped atomic state, 독립 revision과 idempotent mutation
7. strict versioned tactical schema, shared fixture, Python dispatcher와 Dart typed service
8. match/jokbo create·edit·delete·search·filter·detail·copy/reuse
9. loading·empty·disconnected·partial error·revision conflict·retry와 stale generation 보호
10. deterministic Mock, 실제 process restart E2E source, 3 viewport와 P6-1~P6-5 회귀 보호

덱 slot의 `null`과 순서를 보존하고 중간 빈 slot을 압축하지 마십시오. 표시 이름이나 v6 줄임말을 저장 ID로
사용하지 마십시오. `kind=attack`은 내 attack 대 상대 defense, `kind=defense`는 상대 attack 대 내 defense입니다.
UI, DTO와 test에서 이 방향을 뒤집지 마십시오. 날짜 없음은 오늘 날짜로 채우지 않습니다.

tactical data는 scanned current, static metadata, user goals, gross calculation, inventory shortage와 별도 domain으로
보존하십시오. Flutter가 파일이나 SQLite를 직접 읽거나 tactical record를 repository current/goals에 끼워 넣지
않게 하십시오. Python backend만 persistence를 소유하고 stale revision, idempotent retry와 atomic failure를
구조적으로 처리해야 합니다.

P6-6에서 screenshot/clipboard/folder/Excel import, abbreviation, OCR/template matching, lobby rank/opponent scan,
hidden slot, provenance/confidence, observed timestamp, 승률·빈도, 추천·예측·공유를 추가하지 마십시오. v6
Qt/QML/PySide UI나 tactical facade/SQLite 모듈을 복사하거나 runtime import하지 마십시오. P7 계약을 추측해
과도한 DTO를 만들지 마십시오.

새 backend/service 계약이 필요한 작업이므로 schema와 양쪽 fixture/test 없이 ad-hoc JSON map만 추가하지
마십시오. contract 결함을 자동 test로 입증한 경우에만 기존 공용 계층을 최소 수정하고 원인과 회귀 test를
기록하십시오.

슬레이브에는 Flutter/Dart SDK와 CodeAlmanac CLI가 없습니다. 설치하거나 공간 확보를 위해 파일을 삭제하지
마십시오. Dart/Flutter source와 test는 반드시 작성하되 실행 결과를 주장하지 않습니다. 도구 부재만으로
`BLOCKED` 처리하지 마십시오.

슬레이브 필수 검증:

```powershell
cd backend
py -3.11 -m unittest discover -s tests -v

cd ..
git diff --check
rg -n "from (PySide6|PyQt|tkinter)|import (PySide6|PyQt|tkinter)" backend frontend
rg -n "\.\./v6|BA Planner[/\\]v6" backend frontend
```

tactical schema/fixture, persistence/restart, revision/idempotency, profile isolation과 기존 repository/protocol
Python test를 집중 실행하십시오. 금지 import와 v6 runtime path 검색은 0건이어야 하며 문서·fixture 설명
문자열과 runtime 참조를 구분하십시오.

마스터 전용 검증은 실행한 것처럼 쓰지 말고 다음을 그대로 인계하십시오.

```text
MASTER_REQUIRED: cd backend; py -3.11 -m unittest discover -s tests -v
MASTER_REQUIRED: cd frontend; dart format --output=none --set-exit-if-changed <P6-6 Dart paths>
MASTER_REQUIRED: cd frontend; flutter analyze
MASTER_REQUIRED: cd frontend; flutter test
MASTER_REQUIRED: cd frontend; flutter build windows --release
MASTER_REQUIRED: tactical schema/fixture의 Python/Dart parity와 strict invalid-case 검증
MASTER_REQUIRED: 실제 Dart ProcessAppService↔Python profile-scoped match/jokbo save→restart→restore E2E
MASTER_REQUIRED: fixed 4+2 slot, null/order, duplicate/class와 attack/defense 방향 검증
MASTER_REQUIRED: stale revision, idempotent retry, atomic failure와 profile isolation 검증
MASTER_REQUIRED: MockAppService empty/data/create/edit/delete/filter/copy/revision-failure 검증
MASTER_REQUIRED: canonical student ID, owned-only own deck와 catalog-wide opponent deck 검증
MASTER_REQUIRED: disconnected/loading/error/retry, refresh/re-entry/profile-change/stale generation 검증
MASTER_REQUIRED: P6-1~P6-5와 planning/repository/scanner candidate approve/hold 전체 회귀
MASTER_REQUIRED: 1280x720, 1440x900, 1280x960 Widget/golden overflow와 편집/검색/상세 action 접근성
MASTER_REQUIRED: codealmanac validate
MASTER_REQUIRED: codealmanac health
MASTER_REQUIRED: git diff --check
```

실제 Blue Archive 게임 창 smoke는 P6-6 필수 조건이 아닙니다. 실행하지 않았다면 `NOT_VERIFIED`로 기록하고
fixture/Mock 결과를 실제 게임 검증으로 표현하지 마십시오.

결과물:

```text
docs/migration/p6-6-tactical-integration/artifacts/
├─ p6-6-tactical-integration.patch
└─ verification.txt
```

patch는 accepted P6-5 snapshot 위의 P6-6 단일 증분이어야 합니다. 신규 파일을 모두 포함하되 input/prompt,
`output.md`, `artifacts/`, 이전 patch/handoff, P6-7/P7+, build/cache/profile/database/log/scan result,
v6 source·UI·SQLite와 recognition/runtime asset 복제본은 포함하지 마십시오. 모든 path는
`BA Planner/v7/...`여야 합니다. clean copy에서 `git apply --check --verbose`를 실행해 Checking 전체와
skipped 0을 확인하십시오.

`verification.txt`에는 최소 다음을 기록하십시오.

- baseline commit과 accepted P6-5 snapshot 포함 경로, dirty-path 판단
- 새/수정 protocol method, DTO, storage path와 profile/revision/idempotency 결정
- 4+2 slot, own/opponent candidate, attack/defense 방향과 date-null 결정
- P7+ 제외 범위와 v6 behavior reference만 사용했다는 근거
- 실행 명령, test 수와 정확한 결과, master 전용 gate

`output.md`는 마지막에 작성하고 다음을 포함해야 합니다.

- 작업 ID와 `COMPLETED` 또는 `BLOCKED`
- 요구사항별 `PASS`, `FAIL`, `NOT_VERIFIED` 표
- 실행한 명령과 Python test 수·정확한 결과
- 모든 `MASTER_REQUIRED`와 실제 게임 창 `NOT_VERIFIED` 여부
- 두 artifact의 상대경로, 설명, 실제 byte size와 SHA-256
- 알려진 제한과 마스터가 확인할 정확한 test/file

결과물이 준비된 뒤 다음 단일 송신 래퍼를 사용하십시오.

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p6-6-tactical-integration" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p6-6-tactical-integration"
```

IP, port 또는 token을 사용자에게 요구하거나 token을 화면·파일·로그에 기록하지 마십시오. ZIP, manifest,
sidecar, `MASTER_PROMPT.md`와 artifacts가 실제로 존재하고 hash가 일치해야 합니다. 마지막 응답에는 다음
`TASK_OUTPUT_READY`와 송신 래퍼가 생성한 `CROSS_PC_HANDOFF_READY`를 모두 포함하십시오.

```text
TASK_OUTPUT_READY
task_id: ba-planner-v7-p6-6-tactical-integration
status: COMPLETED
output_md: <SLAVE_REPOSITORY_ROOT>\docs\migration\p6-6-tactical-integration\output.md
artifacts_dir: <SLAVE_REPOSITORY_ROOT>\docs\migration\p6-6-tactical-integration\artifacts
artifact_count: 2
```

필수 구현이나 artifact 생성이 실제로 막힌 경우에만 `TASK_OUTPUT_BLOCKED`를 사용하고 구체적인 원인과
요청할 accepted snapshot을 기록하십시오. 마스터 독립 검증 전에는 P6-6 완료를 주장하지 마십시오.
P6-7과 최종 통합 검증이 남으므로 P6 전체 완료도 주장하지 마십시오.
