# 슬레이브 실행 프롬프트

BA Planner v7 P6-7 설정 및 통합 오류 처리를 수행하고 cross-PC 인계 패키지를 생성하십시오.

작업 ID:

```text
ba-planner-v7-p6-7-settings-error-integration
```

먼저 다음을 처음부터 끝까지 읽으십시오.

- `docs/migration/p6-7-settings-error-integration/input.md`
- `README.md`, `AGENTS.md`, `docs/migration/v6-knowledge-baseline.md`
- `almanac/workflows/p0-p6-workflow.md`의 공통 불변식과 P6 절
- `almanac/workflows/p0-p6-workflow-status.md`의 P6-1~P6-7 절
- `almanac/design/frontend-section-direction-and-user-flows.md`의 설정·복구 흐름
- `almanac/design/responsive-diagonal-layout-policy.md`
- `almanac/workflows/slave-artifact-handoff.md`, `cross-pc-slave-handoff.md`
- P6-1~P6-6 input, patch 범위와 마스터 승인 결과
- 현재 AppService/RepositoryService/ScannerService/TacticalService와 ProcessAppService/MockAppService
- `planning_protocol_client.dart`, `app_shell.dart`, `app_section.dart`, 모든 실제 P6 page와 test

이 작업은 P6의 마지막 구현 증분이지만 마스터의 P6 완료 판정 또는 P7 시작이 아닙니다. accepted P6-6
snapshot 위에서 설정과 전 탭 오류·복구, 최종 P6 통합 test source만 구현하십시오.

변경 전 baseline gate:

- P6-1~P6-6의 모든 기본 탭이 service-backed 화면
- P6-6 tactical contract/storage/service/page와 마스터 보정 포함
- workflow에서 P6-1~P6-6 `완료`, P6 `진행 중`, P6-7 `인계 대기`
- 승인 시점 Python 79, Flutter 121, analyze, Windows release, process E2E, Mock, 3 viewport, Almanac 통과
- 승인 P6-6은 HEAD `e58281e`만으로 식별할 수 없는 commit되지 않은 snapshot일 수 있음

HEAD ID만 보고 동일 baseline이라 판단하지 말고 승인 P6-6의 수정·신규 경로와 내용을 확인하십시오.
baseline commit, accepted dirty paths와 중복 판단을 `verification.txt`에 기록하십시오. snapshot이 없으면
이전 단계를 재구성하거나 오래된 origin에서 시작하지 말고 `BLOCKED`로 보고하여 accepted P6-6 snapshot을
요청하십시오. 기존 사용자 변경과 P6-7 대상 경로가 겹치면 commit·stash·삭제·덮어쓰지 마십시오.

`input.md`의 계약을 그대로 구현하십시오.

1. Settings placeholder를 profile/connection/scanner/diagnostics/Adaptive-Sync 실제 화면으로 교체
2. profile list/create/select/rename, revision conflict와 전환 후 전 탭 reload
3. reconnect/restart single-flight, generation 보호와 명시적 진행·실패·retry 상태
4. scanner readiness/targets 표시와 Scan deep-link; 설정에서 scan 시작·target 저장은 금지
5. protocol/launcher/process/scanner와 bounded recent stderr/lifecycle의 secret-safe typed diagnostics
6. 공통 recovery model/widget 또는 동등한 typed 오류·복구 계약을 실제 기본 탭에 최소 연결
7. profile/process 전환의 stale response와 cross-profile draft/candidate 누출 방지
8. reconnect/restart 중 planning/tactical draft와 scan candidate의 자동 commit·삭제 방지
9. 실제 process와 Mock의 P6 전체 흐름, P6-1~P6-6 회귀와 3 viewport test source

RepositoryService에 없는 profile 삭제, backup/import/export를 추측해 구현하지 마십시오. 새 settings DB/file,
무제한 log, 환경변수 값·token·사용자 payload 진단 dump를 만들지 마십시오. 설정 표시만으로 backend를 자동
시작하지 말고 기존 lazy launcher resolution을 보존하십시오. backend wire method는 backend가 실제로 소유한
정보가 아니면 추가하지 말고 launcher/stderr는 최소 client-side typed diagnostics로 처리하십시오.

오류를 성공한 것처럼 숨기거나 모든 탭에 자동 retry loop를 넣지 마십시오. reconnect/restart 뒤 새 generation을
reload하되 늦은 이전 응답이 현재 profile/state/draft를 덮지 않아야 합니다. scanner 중 연결이 끊기면 session이
계속된 것처럼 표현하지 말고 candidate Hold/Approve와 repository commit 경계를 보존하십시오.

P7+ tactical scanner/history/provenance/statistics/recommendation, installer/update/telemetry, 정식 release와 배포,
v6 Qt/QML/PySide UI 또는 runtime import는 범위 밖입니다. 실제 게임 창을 실행하지 않았다면 fixture/Mock를 실제
게임 검증으로 표현하지 마십시오.

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

profile/repository/process lifecycle, scanner candidate, planning/shortage와 tactical persistence Python test를 집중
실행하십시오. 금지 import와 v6 runtime path 검색은 0건이어야 하며 문서·fixture 문자열과 runtime 참조를
구분하십시오.

마스터 전용 검증은 실행한 것처럼 쓰지 말고 다음을 그대로 인계하십시오.

```text
MASTER_REQUIRED: cd backend; py -3.11 -m unittest discover -s tests -v
MASTER_REQUIRED: cd frontend; dart format --output=none --set-exit-if-changed <P6-7 Dart paths>
MASTER_REQUIRED: cd frontend; flutter analyze
MASTER_REQUIRED: cd frontend; flutter test
MASTER_REQUIRED: cd frontend; flutter build windows --release
MASTER_REQUIRED: Settings profile list/create/select/rename, revision conflict와 전 탭 reload 검증
MASTER_REQUIRED: reconnect/restart single-flight, generation, failure/retry와 dispose 안전성 검증
MASTER_REQUIRED: diagnostics bounded/secret-safe/copy report, lazy launcher와 deterministic Mock 검증
MASTER_REQUIRED: scanner readiness/targets, Scan deep-link와 설정에서 scan 미실행 검증
MASTER_REQUIRED: Adaptive-Sync entry와 keyboard/semantic/scroll 접근성 검증
MASTER_REQUIRED: profile/process 전환의 planning/tactical draft와 candidate Hold/Approve 격리 검증
MASTER_REQUIRED: 실제 Dart ProcessAppService↔Python scan candidate→current review→goal→gross→shortage→save→restart→restore E2E
MASTER_REQUIRED: 실제 process E2E와 MockAppService 전체 흐름의 근거 분리 검증
MASTER_REQUIRED: P6-1~P6-6 page/service/contract와 tactical persistence 전체 회귀
MASTER_REQUIRED: 1280x720, 1440x900, 1280x960 populated/error/long-text Widget/golden overflow와 action 접근성
MASTER_REQUIRED: codealmanac validate
MASTER_REQUIRED: codealmanac health
MASTER_REQUIRED: git diff --check
```

실제 Blue Archive 게임 창 smoke는 P6-7 필수 조건이 아닙니다. 실행하지 않았다면 `NOT_VERIFIED`로 기록하고
fixture/Mock 결과를 실제 게임 검증으로 표현하지 마십시오.

결과물:

```text
docs/migration/p6-7-settings-error-integration/artifacts/
├─ p6-7-settings-error-integration.patch
└─ verification.txt
```

patch는 accepted P6-6 snapshot 위의 P6-7 단일 증분이어야 합니다. 신규 파일을 모두 포함하되 input/prompt,
`output.md`, `artifacts/`, 이전 patch/handoff, P7+, build/cache/profile/database/log/scan result와 v6 source/assets를
포함하지 마십시오. 전 탭 recovery 연결로 수정한 기존 page는 각 경로의 필요성을 기록하고 formatting-only
churn을 제거하십시오. 모든 path는 `BA Planner/v7/...`여야 합니다. clean copy에서
`git apply --check --verbose`를 실행해 Checking 전체와 skipped 0을 확인하십시오.

`verification.txt`에는 최소 다음을 기록하십시오.

- baseline commit, accepted P6-6 수정·신규 경로와 dirty-path 중복 판단
- Settings source/action별 실제 service owner와 추가한 typed diagnostics/recovery 경계
- reconnect/restart generation, profile reload, draft/candidate 격리 결정
- profile 삭제·backup/import, scan target persistence와 P7+ 제외 근거
- real-process와 Mock test 근거 구분, 실행 명령·test 수·정확한 결과, master 전용 gate

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
  -TaskId "ba-planner-v7-p6-7-settings-error-integration" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p6-7-settings-error-integration"
```

IP, port 또는 token을 사용자에게 요구하거나 token을 화면·파일·로그에 기록하지 마십시오. ZIP, manifest,
sidecar, `MASTER_PROMPT.md`와 artifacts가 실제로 존재하고 hash가 일치해야 합니다. 마지막 응답에는 다음
`TASK_OUTPUT_READY`와 송신 래퍼가 생성한 `CROSS_PC_HANDOFF_READY`를 모두 포함하십시오.

```text
TASK_OUTPUT_READY
task_id: ba-planner-v7-p6-7-settings-error-integration
status: COMPLETED
output_md: <SLAVE_REPOSITORY_ROOT>\docs\migration\p6-7-settings-error-integration\output.md
artifacts_dir: <SLAVE_REPOSITORY_ROOT>\docs\migration\p6-7-settings-error-integration\artifacts
artifact_count: 2
```

필수 구현이나 artifact 생성이 실제로 막힌 경우에만 `TASK_OUTPUT_BLOCKED`를 사용하고 구체적인 원인과
요청할 accepted snapshot을 기록하십시오. 마스터 독립 검증 전에는 P6-7이나 P6 전체 완료를 주장하거나
workflow를 `완료`로 바꾸지 마십시오.
