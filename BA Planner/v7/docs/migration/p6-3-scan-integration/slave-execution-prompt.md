# 슬레이브 실행 프롬프트

BA Planner v7 P6-3 스캔 실제 UI 통합을 수행하고 cross-PC 인계 패키지를 생성하십시오.

작업 ID:

```text
ba-planner-v7-p6-3-scan-integration
```

먼저 다음을 처음부터 끝까지 읽으십시오.

- `docs/migration/p6-3-scan-integration/input.md`
- `README.md`, `AGENTS.md`
- `docs/migration/v6-knowledge-baseline.md`
- `almanac/workflows/p0-p6-workflow.md`의 공통 불변식, P5와 P6 절
- `almanac/workflows/p0-p6-workflow-status.md`의 P5, P6-1, P6-2와 P6-3 절
- `almanac/design/frontend-section-direction-and-user-flows.md`의 공통 규칙과 스캔 탭 절
- `almanac/design/responsive-diagonal-layout-policy.md`
- `almanac/workflows/slave-artifact-handoff.md`, `cross-pc-slave-handoff.md`
- `docs/migration/p5-scanner-matcher/scanner-characterization.md`, `scanner-runtime.md`
- `../v6/almanac/flows/student-scan.md`, `inventory-scan.md`
- `frontend/lib/services/scanner_service.dart`, `process_app_service.dart`, `mock_app_service.dart`
- `frontend/lib/ui/app_shell.dart`, `student_page.dart`, `inventory_page.dart`
- scanner schema/fixture와 기존 Python/Dart scanner test

이 작업은 P6 전체 구현이 아닙니다. 승인된 P6-2 snapshot 위에서 스캔 탭 placeholder만 실제 P5
scanner service UI로 교체합니다. 홈·통계·전술대항전·설정 또는 P7 이후 기능을 구현하지 마십시오.

변경 전 baseline gate:

- P6-1 StudentPage와 P6-2 InventoryPage 및 두 candidate context 존재
- inventory catalog·shortage·typed save와 P6-2 master catalog-error 보완 존재
- 실제 catalog·shortage·inventory restart E2E assertion 존재
- Python 72, Flutter 65, analyze, release, Almanac과 diff check가 마스터에서 통과한 승인본
- workflow status에서 P6-1·P6-2 `완료`, 스캔 탭만 placeholder
- P5 typed target/readiness/session/event/snapshot/review/commit service와 process/Mock test 존재

이 승인본이 없으면 P6-1/P6-2를 재구성하거나 오래된 origin/main 위에서 시작하지 마십시오.
`BLOCKED`로 보고하고 마스터에게 accepted P6-2 snapshot을 요청하십시오. 정확한 승인본이 있다면 그
상태만 local baseline commit으로 고정할 수 있으나 push하지 마십시오. baseline ID와 포함 경로를
`verification.txt`에 기록하십시오. 다른 사용자 변경과 대상 경로가 겹치면 commit·stash·삭제하지 말고
`BLOCKED`로 보고하십시오.

`input.md`에 따라 다음을 구현하십시오.

1. backend/recognition/profile/target 준비 상태와 refresh를 제공하는 실제 `ScanPage`
2. student/inventory kind 및 stable target ID 선택과 단일 active session start
3. typed phase/progress/nullable-total/diagnostic/terminal projection
4. cancel acknowledgement와 terminal을 분리한 cancelling, terminal 이후 새-generation retry
5. sequence gap/stream error의 active-session snapshot 복구와 실패 시 기존 상태 보존
6. 현재 앱 실행 중 bounded recent-session 요약
7. candidate revision·payload 요약·confidence/evidence·review-required 표시
8. student/inventory candidate를 AppShell을 통해 각 data-owner 탭 context로 전달
9. destination commit 성공 뒤 stale context 정리; Hold는 mutation 없이 재검토 가능
10. deterministic Mock student/inventory/cancel/failure 흐름과 Flutter test source

ScanPage에서 repository를 직접 쓰거나 candidate를 자동 review/commit하지 마십시오. 최종 비교와 commit은
StudentPage/InventoryPage가 소유합니다. cancel 응답만으로 terminal이라고 간주하지 말고, stale/gap 정책을
느슨하게 하지 마십시오. backend에 없는 영구 scan history나 timestamp를 만들지 마십시오. v6 runtime
import와 Qt/QML/QWidget/Tk/PySide6 코드 복사는 금지됩니다.

P5 protocol/backend는 이미 승인됐습니다. 실제 contract 결함을 자동 test로 입증한 경우가 아니면 schema,
Python scanner session 또는 production adapter를 변경하지 마십시오. UI가 snapshot을 안전하게 소비하려면
strict Dart typed snapshot/projection model을 추가할 수 있지만 wire 의미는 유지하십시오.

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

P5 scanner protocol/session/stdio/production-adapter Python test도 집중 실행해 P6-3가 backend 계약을
퇴행시키지 않았음을 기록하십시오. 금지 import와 v6 runtime path 검색은 0건이어야 합니다. 문서·fixture
설명 문자열은 실제 runtime import와 구분해 판정하십시오.

마스터 전용 검증은 실행한 것처럼 쓰지 말고 다음을 그대로 인계하십시오.

```text
MASTER_REQUIRED: cd frontend; flutter analyze
MASTER_REQUIRED: cd frontend; flutter test
MASTER_REQUIRED: cd frontend; flutter build windows --release
MASTER_REQUIRED: 실제 Dart ProcessAppService↔Python target/readiness/start/phase/progress/candidate/terminal E2E
MASTER_REQUIRED: cancel 또는 snapshot 복구, backend restart와 dispose cleanup 검증
MASTER_REQUIRED: MockAppService student/inventory/cancel/failure와 candidate handoff 검증
MASTER_REQUIRED: StudentPage/InventoryPage hold·approve·commit 및 성공 뒤 AppShell context 정리
MASTER_REQUIRED: stale/duplicate/gap/after-terminal과 start-event race 회귀 검증
MASTER_REQUIRED: 1280x720, 1440x900, 1280x960 Widget/golden overflow와 핵심 action 접근성
MASTER_REQUIRED: P6-1 StudentPage, P6-2 InventoryPage, planning/repository 회귀 검증
MASTER_REQUIRED: codealmanac validate
MASTER_REQUIRED: codealmanac health
MASTER_REQUIRED: git diff --check
```

실제 Blue Archive 게임 창 smoke는 안전한 사용자 참여 없이 자동 실행하지 마십시오. 실행하지 못한 경우
`NOT_VERIFIED`로 기록하고 fixture/fake-process 결과를 실제 게임 검증으로 표현하지 마십시오.

결과물:

```text
docs/migration/p6-3-scan-integration/artifacts/
├─ p6-3-scan-integration.patch
└─ verification.txt
```

patch는 승인된 P6-2 snapshot 위의 P6-3 단일 증분이어야 합니다. 신규 파일을 모두 포함하되 input/prompt,
`output.md`, `artifacts/`, 이전 patch/handoff, build/cache/profile/database/log/scan result/debug crop/adaptive
sample과 recognition template 복제본은 포함하지 마십시오. 모든 path는 `BA Planner/v7/...`여야 합니다.
clean copy에서 `git apply --check --verbose`를 실행해 Checking 전체와 skipped 0을 확인하십시오.

`output.md`는 마지막에 작성하고 다음을 포함해야 합니다.

- 작업 ID와 `COMPLETED` 또는 `BLOCKED`
- baseline commit, accepted P6-2 gate와 dirty-path 판단
- session/cancel/snapshot/candidate-handoff 결정과 구현 요약
- 요구사항별 `PASS`, `FAIL`, `NOT_VERIFIED` 표
- 실행한 명령, Python test 수와 정확한 결과
- 모든 `MASTER_REQUIRED` gate와 실제 게임 창 `NOT_VERIFIED` 여부
- 두 artifact의 상대경로, 설명, 실제 byte size와 SHA-256
- 알려진 제한과 마스터가 확인할 정확한 test/file

결과물이 준비된 뒤 다음 단일 송신 래퍼를 사용하십시오.

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p6-3-scan-integration" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p6-3-scan-integration"
```

IP, port 또는 token을 사용자에게 요구하거나 token을 화면·파일·로그에 기록하지 마십시오. ZIP,
manifest, sidecar, `MASTER_PROMPT.md`와 artifacts가 실제로 존재하고 hash가 일치해야 합니다.
마지막 응답에는 다음 `TASK_OUTPUT_READY`와 송신 래퍼가 생성한 `CROSS_PC_HANDOFF_READY`를 모두
포함하십시오.

```text
TASK_OUTPUT_READY
task_id: ba-planner-v7-p6-3-scan-integration
status: COMPLETED
output_md: <SLAVE_REPOSITORY_ROOT>\docs\migration\p6-3-scan-integration\output.md
artifacts_dir: <SLAVE_REPOSITORY_ROOT>\docs\migration\p6-3-scan-integration\artifacts
artifact_count: 2
```

필수 구현이나 artifact 생성이 실제로 막힌 경우에만 `TASK_OUTPUT_BLOCKED`를 사용하고 구체적인 원인과
요청할 accepted snapshot을 기록하십시오. 마스터 독립 검증 전에는 P6-3 또는 P6 전체 완료를 주장하지
마십시오.
