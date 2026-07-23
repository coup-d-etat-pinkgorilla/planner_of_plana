# 슬레이브 실행 프롬프트

BA Planner v7 P6-5 통계 실제 데이터 통합을 수행하고 cross-PC 인계 패키지를 생성하십시오.

작업 ID:

```text
ba-planner-v7-p6-5-statistics-integration
```

먼저 다음을 처음부터 끝까지 읽으십시오.

- `docs/migration/p6-5-statistics-integration/input.md`
- `README.md`, `AGENTS.md`
- `docs/migration/v6-knowledge-baseline.md`
- `../v6/STUDENT_PLANNER_HANDOFF.md`의 Statistics Guide와 five-bucket 경계
- `../v6/docs/ui-behavior/statistics.md`
- `../v6/gui/student_stats.py`, `../v6/gui/viewer_components/statistics.py`는 behavior reference만 사용
- `almanac/workflows/p0-p6-workflow.md`의 공통 불변식과 P6 절
- `almanac/workflows/p0-p6-workflow-status.md`의 P6-1~P6-5 절
- `almanac/design/frontend-section-direction-and-user-flows.md`의 공통 규칙과 통계 탭 절
- `almanac/design/responsive-diagonal-layout-policy.md`
- `almanac/workflows/slave-artifact-handoff.md`, `cross-pc-slave-handoff.md`
- P6-1~P6-4 input과 승인 결과
- `frontend/lib/services/app_service.dart`, `repository_service.dart`, `process_app_service.dart`, `mock_app_service.dart`
- `frontend/lib/ui/app_shell.dart`, 학생·계획·인벤토리·홈 page와 관련 test
- planning/repository/catalog/shortage contract fixture와 process E2E

이 작업은 P6 전체가 아닙니다. 승인된 P6-4 snapshot 위에서 통계 탭만 실제 분석 화면으로 통합하십시오.
P6-6 전술대항전, P6-7 설정·통합 오류 처리 또는 새 statistics backend를 구현하지 마십시오.

변경 전 baseline gate:

- P6-1 StudentPage, P6-2 InventoryPage, P6-3 ScanPage, P6-4 HomePage가 service-backed 화면
- HomePage의 typed repository/saved-plan/shortage read model과 planning-current 안전 변환 존재
- selected profile, student/inventory catalog, repository state, gross calculation과 shortage API 존재
- workflow에서 P6-1~P6-4 `완료`, P6 전체 `진행 중`
- 승인 시점 Python 72, Flutter 91, analyze, Windows release, process E2E, 3 viewport, Almanac 통과

이 승인본이 없으면 이전 단계를 재구성하거나 오래된 origin/main 위에서 시작하지 마십시오. `BLOCKED`로
보고하고 accepted P6-4 snapshot을 요청하십시오. 정확한 승인본이 있으면 그 상태만 local baseline
commit으로 고정할 수 있으나 push하지 마십시오. baseline ID와 포함 경로를 `verification.txt`에
기록하십시오. 다른 사용자 변경과 대상 경로가 겹치면 commit·stash·삭제하지 말고 `BLOCKED`로 보고하십시오.

`input.md`의 지표 목록과 의미를 그대로 구현하십시오.

1. `AppSection.statistics` placeholder를 실제 `StatisticsPage`로 교체
2. 선택 프로필 전체를 범위로 한 학생·인벤토리·계획 3개 접근 가능한 mode
3. immutable pure-Dart distribution projection: stable key/label/count or value/denominator/percent
4. 학생 ownership, level/star, school/combat class/attack/defense/role와 known-only average
5. inventory category, known/unknown/zero/positive coverage와 missing catalog identity
6. saved goals가 있을 때만 기존 gross `calculatePlan`과 shortage `calculateShortages` 호출
7. gross scalar/material map과 required/owned/shortage/unresolved/affected-student 의미 분리
8. distribution 선택의 원인 detail 목록과 Student/Inventory/Planning data-owner 이동
9. source별 loading/empty/disconnected/partial error, refresh/re-entry와 stale generation 보호
10. deterministic Mock, 실제 process E2E source, 3 viewport와 P6-1~P6-4 회귀 보호

StudentPage 검색·필터 상태를 공유하거나 새 cross-tab filter handoff를 만들지 마십시오. v6는 filtered students를
사용했지만 v7 P6-5 범위는 선택 프로필 전체로 고정합니다. statistics sorting은 표시만 바꾸고 denominator를
바꾸지 않습니다.

통계 화면은 read-only입니다. repository save, plan mutation, inventory zero-fill, candidate review/commit을
호출하지 마십시오. missing/unknown을 0으로 바꾸거나 known-only 평균에 unknown을 포함하지 마십시오. gross
requirement, owned와 shortage를 합치지 말고 backend에 없는 stale time/history를 만들지 마십시오.

새 protocol/schema/database/cache나 chart dependency를 추가하지 마십시오. Flutter 기본 widget으로 label,
count/value와 percent가 함께 보이는 accessible bar/list를 작성하십시오. v6 Qt/QML/PySide widget, painter,
sunburst code를 복사하거나 runtime import하지 마십시오. 실제 contract 결함을 자동 test로 입증한 경우만 최소
수정하고 원인과 회귀 test를 기록하십시오.

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

repository/planning/catalog/shortage Python test도 집중 실행해 P6-5가 기존 계약을 퇴행시키지 않았음을
기록하십시오. 금지 import와 v6 runtime path 검색은 0건이어야 하며 문서·fixture 설명 문자열과 runtime
참조를 구분하십시오.

마스터 전용 검증은 실행한 것처럼 쓰지 말고 다음을 그대로 인계하십시오.

```text
MASTER_REQUIRED: cd frontend; dart format --output=none --set-exit-if-changed <P6-5 Dart paths>
MASTER_REQUIRED: cd frontend; flutter analyze
MASTER_REQUIRED: cd frontend; flutter test
MASTER_REQUIRED: cd frontend; flutter build windows --release
MASTER_REQUIRED: 실제 Dart ProcessAppService↔Python selected profile/catalog/repository/gross/shortage E2E
MASTER_REQUIRED: pure statistics projection의 stable identity/sort/denominator/percent/immutability 검증
MASTER_REQUIRED: missing/unknown/zero, repository-only identity와 known-only average 검증
MASTER_REQUIRED: gross와 shortage partial failure, refresh/re-entry와 stale generation 검증
MASTER_REQUIRED: MockAppService data/empty/unknown/partial-failure와 data-owner navigation 검증
MASTER_REQUIRED: P6-1~P6-4, planning/repository/scanner 전체 회귀
MASTER_REQUIRED: 1280x720, 1440x900, 1280x960 Widget/golden overflow와 mode/detail/action 접근성
MASTER_REQUIRED: codealmanac validate
MASTER_REQUIRED: codealmanac health
MASTER_REQUIRED: git diff --check
```

실제 Blue Archive 게임 창 smoke는 P6-5 필수 조건이 아닙니다. 실행하지 않았다면 `NOT_VERIFIED`로 기록하고
fixture/Mock 결과를 실제 게임 검증으로 표현하지 마십시오.

결과물:

```text
docs/migration/p6-5-statistics-integration/artifacts/
├─ p6-5-statistics-integration.patch
└─ verification.txt
```

patch는 승인된 P6-4 snapshot 위의 P6-5 단일 증분이어야 합니다. 신규 파일을 모두 포함하되 input/prompt,
`output.md`, `artifacts/`, 이전 patch/handoff, P6-6/P6-7, 새 backend 통계 storage/protocol,
build/cache/profile/database/log/scan result, v6 source와 recognition asset 복제본은 포함하지 마십시오.
모든 path는 `BA Planner/v7/...`여야 합니다. clean copy에서 `git apply --check --verbose`를 실행해 Checking
전체와 skipped 0을 확인하십시오.

`output.md`는 마지막에 작성하고 다음을 포함해야 합니다.

- 작업 ID와 `COMPLETED` 또는 `BLOCKED`
- baseline commit, accepted P6-4 gate와 dirty-path 판단
- full-profile scope, 3 mode, metric/denominator/unknown/gross-shortage 결정
- 요구사항별 `PASS`, `FAIL`, `NOT_VERIFIED` 표
- 실행한 명령, Python test 수와 정확한 결과
- 모든 `MASTER_REQUIRED` gate와 실제 게임 창 `NOT_VERIFIED` 여부
- 두 artifact의 상대경로, 설명, 실제 byte size와 SHA-256
- 알려진 제한과 마스터가 확인할 정확한 test/file

결과물이 준비된 뒤 다음 단일 송신 래퍼를 사용하십시오.

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p6-5-statistics-integration" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p6-5-statistics-integration"
```

IP, port 또는 token을 사용자에게 요구하거나 token을 화면·파일·로그에 기록하지 마십시오. ZIP, manifest,
sidecar, `MASTER_PROMPT.md`와 artifacts가 실제로 존재하고 hash가 일치해야 합니다. 마지막 응답에는 다음
`TASK_OUTPUT_READY`와 송신 래퍼가 생성한 `CROSS_PC_HANDOFF_READY`를 모두 포함하십시오.

```text
TASK_OUTPUT_READY
task_id: ba-planner-v7-p6-5-statistics-integration
status: COMPLETED
output_md: <SLAVE_REPOSITORY_ROOT>\docs\migration\p6-5-statistics-integration\output.md
artifacts_dir: <SLAVE_REPOSITORY_ROOT>\docs\migration\p6-5-statistics-integration\artifacts
artifact_count: 2
```

필수 구현이나 artifact 생성이 실제로 막힌 경우에만 `TASK_OUTPUT_BLOCKED`를 사용하고 구체적인 원인과
요청할 accepted snapshot을 기록하십시오. 마스터 독립 검증 전에는 P6-5 완료를 주장하지 마십시오.
P6-5가 승인되어도 P6-6·P6-7과 최종 통합 검증이 남으므로 P6 전체 완료를 주장하지 마십시오.
