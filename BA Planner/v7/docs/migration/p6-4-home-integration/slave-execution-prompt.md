# 슬레이브 실행 프롬프트

BA Planner v7 P6-4 홈 실제 데이터 통합을 수행하고 cross-PC 인계 패키지를 생성하십시오.

작업 ID:

```text
ba-planner-v7-p6-4-home-integration
```

먼저 다음을 처음부터 끝까지 읽으십시오.

- `docs/migration/p6-4-home-integration/input.md`
- `README.md`, `AGENTS.md`
- `docs/migration/v6-knowledge-baseline.md`
- `almanac/workflows/p0-p6-workflow.md`의 공통 불변식과 P6 절
- `almanac/workflows/p0-p6-workflow-status.md`의 P6-1~P6-4 절
- `almanac/design/frontend-section-direction-and-user-flows.md`의 공통 규칙과 홈 탭 절
- `almanac/design/responsive-diagonal-layout-policy.md`
- `almanac/workflows/slave-artifact-handoff.md`, `cross-pc-slave-handoff.md`
- `docs/migration/v6-diagonal-home-menu-migration.md`
- P6-1~P6-3 input과 승인 결과
- `frontend/lib/ui/pages/home_page.dart`, `planning_page.dart`, `inventory_page.dart`, `scan_page.dart`
- `frontend/lib/ui/app_shell.dart`, `app_section.dart`
- `frontend/lib/services/app_service.dart`, `repository_service.dart`, `scanner_service.dart`
- `frontend/lib/services/process_app_service.dart`, `mock_app_service.dart`
- 관련 Flutter test와 repository/planning/scanner process E2E

이 작업은 P6 전체가 아닙니다. 승인된 P6-3 snapshot 위에서 홈만 실제 상태 대시보드로 통합하십시오.
P6-5 통계, P6-6 전술대항전, P6-7 설정 및 통합 오류 처리를 구현하지 마십시오.

변경 전 baseline gate:

- P6-1 StudentPage, P6-2 InventoryPage, P6-3 ScanPage가 service-backed 화면
- kind별 candidate context와 성공 commit 뒤 정리, typed terminal recent scan 존재
- repository selected profile/current students/inventory/saved goals와 planning shortage API 존재
- P6-3 master 보정과 typed snapshot process E2E assertion 존재
- workflow에서 P6-1~P6-3 `완료`, P6 전체 `진행 중`
- 승인 시점 Python 72, Flutter 78, analyze, Windows release, process E2E, 3 viewport, Almanac 통과

이 승인본이 없으면 이전 단계를 재구성하거나 오래된 origin/main 위에서 시작하지 마십시오. `BLOCKED`로
보고하고 accepted P6-3 snapshot을 요청하십시오. 정확한 승인본이 있으면 그 상태만 local baseline
commit으로 고정할 수 있으나 push하지 마십시오. baseline ID와 포함 경로를 `verification.txt`에
기록하십시오. 다른 사용자 변경과 대상 경로가 겹치면 commit·stash·삭제하지 말고 `BLOCKED`로 보고하십시오.

`input.md`에 따라 다음을 구현하십시오.

1. 기존 742×1018·80° 홈 이미지 메뉴의 geometry/crop/navigation 보존
2. 문제/검토 필요 → 프로필·계획·부족 요약 → 빠른 이동 순서의 실제 dashboard
3. RepositoryService의 selected profile, revision, confirmed student와 inventory known/unknown count
4. 저장된 goals만 활성 계획으로 표시하고 goals가 있을 때만 기존 shortage API 호출
5. positive shortage top-N과 unknown/unresolved/warning/empty/error의 정직한 표시
6. P6-3 latest terminal scan을 public immutable typed projection으로 ScanPage → AppShell → Home 전달
7. student/inventory pending candidate를 표시하고 data-owner 탭으로 이동; commit 성공 뒤 표시 정리
8. source별 loading/empty/disconnected/partial error, refresh와 홈 재진입 reload, stale future generation 보호
9. 설정·학생·계획·인벤토리·스캔으로 가는 stable-key action과 좁은 창 scroll/reflow
10. deterministic Mock source와 Flutter test source, 기존 홈·P6-1~P6-3 회귀 보호

홈은 read model입니다. repository save, candidate review/commit, zero-fill 또는 plan mutation을 수행하지
마십시오. AppServiceState의 개발용 count를 실제 repository count로 표현하지 마십시오. inventory null은
0이 아니며 임시 PlanningPage draft는 저장된 계획이 아닙니다. backend가 제공하지 않는 last-scan timestamp,
영구 recent activity 또는 stale 시각을 만들지 마십시오.

새 repository/planning/scanner protocol은 만들지 마십시오. 실제 contract 결함을 자동 test로 입증한 경우만
최소 수정하고 원인과 회귀 test를 기록하십시오. v6 runtime import와 Qt/QML/QWidget/Tk/PySide6 code 복사는
금지됩니다. 기존 home PNG와 recognition template을 복제하거나 수정하지 마십시오.

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

repository/planning/scanner Python test도 집중 실행해 P6-4가 기존 계약을 퇴행시키지 않았음을 기록하십시오.
금지 import와 v6 runtime path 검색은 0건이어야 하며 문서·fixture 설명 문자열과 runtime 참조를 구분하십시오.

마스터 전용 검증은 실행한 것처럼 쓰지 말고 다음을 그대로 인계하십시오.

```text
MASTER_REQUIRED: cd frontend; flutter analyze
MASTER_REQUIRED: cd frontend; flutter test
MASTER_REQUIRED: cd frontend; flutter build windows --release
MASTER_REQUIRED: 실제 Dart ProcessAppService↔Python selected profile/repository load/saved goals/shortage E2E
MASTER_REQUIRED: Home refresh/resume와 stale async generation, partial source failure 검증
MASTER_REQUIRED: ScanPage terminal summary→AppShell→Home typed projection 검증
MASTER_REQUIRED: student/inventory Hold 유지와 commit 성공 뒤 Home pending-review 정리 검증
MASTER_REQUIRED: MockAppService no-profile/data/unknown/shortage warning/failure/disconnected 흐름 검증
MASTER_REQUIRED: 기존 home 742x1018·80도 geometry/seam/crop와 모든 menu navigation 회귀 검증
MASTER_REQUIRED: P6-1 StudentPage, P6-2 InventoryPage, P6-3 ScanPage, planning/repository/scanner 회귀
MASTER_REQUIRED: 1280x720, 1440x900, 1280x960 Widget/golden overflow와 핵심 action 접근성
MASTER_REQUIRED: codealmanac validate
MASTER_REQUIRED: codealmanac health
MASTER_REQUIRED: git diff --check
```

실제 Blue Archive 게임 창 smoke는 P6-4 필수 조건이 아닙니다. 실행하지 않았다면 `NOT_VERIFIED`로 기록하고
fixture/Mock 결과를 실제 게임 검증으로 표현하지 마십시오.

결과물:

```text
docs/migration/p6-4-home-integration/artifacts/
├─ p6-4-home-integration.patch
└─ verification.txt
```

patch는 승인된 P6-3 snapshot 위의 P6-4 단일 증분이어야 합니다. 신규 파일을 모두 포함하되 input/prompt,
`output.md`, `artifacts/`, 이전 patch/handoff, P6-5~P6-7, build/cache/profile/database/log/scan result/debug crop,
v6 source, home PNG와 recognition template 복제본은 포함하지 마십시오. 모든 path는
`BA Planner/v7/...`여야 합니다. clean copy에서 `git apply --check --verbose`를 실행해 Checking 전체와
skipped 0을 확인하십시오.

`output.md`는 마지막에 작성하고 다음을 포함해야 합니다.

- 작업 ID와 `COMPLETED` 또는 `BLOCKED`
- baseline commit, accepted P6-3 gate와 dirty-path 판단
- Home read model, shortage, scan summary, pending-review와 responsive layout 결정
- 요구사항별 `PASS`, `FAIL`, `NOT_VERIFIED` 표
- 실행한 명령, Python test 수와 정확한 결과
- 모든 `MASTER_REQUIRED` gate와 실제 게임 창 `NOT_VERIFIED` 여부
- 두 artifact의 상대경로, 설명, 실제 byte size와 SHA-256
- 알려진 제한과 마스터가 확인할 정확한 test/file

결과물이 준비된 뒤 다음 단일 송신 래퍼를 사용하십시오.

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p6-4-home-integration" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p6-4-home-integration"
```

IP, port 또는 token을 사용자에게 요구하거나 token을 화면·파일·로그에 기록하지 마십시오. ZIP, manifest,
sidecar, `MASTER_PROMPT.md`와 artifacts가 실제로 존재하고 hash가 일치해야 합니다. 마지막 응답에는 다음
`TASK_OUTPUT_READY`와 송신 래퍼가 생성한 `CROSS_PC_HANDOFF_READY`를 모두 포함하십시오.

```text
TASK_OUTPUT_READY
task_id: ba-planner-v7-p6-4-home-integration
status: COMPLETED
output_md: <SLAVE_REPOSITORY_ROOT>\docs\migration\p6-4-home-integration\output.md
artifacts_dir: <SLAVE_REPOSITORY_ROOT>\docs\migration\p6-4-home-integration\artifacts
artifact_count: 2
```

필수 구현이나 artifact 생성이 실제로 막힌 경우에만 `TASK_OUTPUT_BLOCKED`를 사용하고 구체적인 원인과
요청할 accepted snapshot을 기록하십시오. 마스터 독립 검증 전에는 P6-4 완료를 주장하지 마십시오.
P6-4가 승인되어도 P6-5~P6-7과 최종 통합 검증이 남으므로 P6 전체 완료를 주장하지 마십시오.
