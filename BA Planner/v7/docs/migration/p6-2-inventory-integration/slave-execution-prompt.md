# 슬레이브 실행 프롬프트

BA Planner v7 P6-2 인벤토리 실제 데이터 통합을 수행하고 cross-PC 인계 패키지를
생성하십시오.

작업 ID:

```text
ba-planner-v7-p6-2-inventory-integration
```

먼저 다음 파일을 처음부터 끝까지 읽으십시오.

- `docs/migration/p6-2-inventory-integration/input.md`
- `README.md`
- `AGENTS.md`
- `docs/migration/v6-knowledge-baseline.md`
- `almanac/workflows/p0-p6-workflow.md`의 P6 절
- `almanac/workflows/p0-p6-workflow-status.md`의 P5, P6 UX, P6-1과 P6-2 절
- `almanac/design/frontend-section-direction-and-user-flows.md`의 공통 규칙과 인벤토리 탭 절
- `almanac/design/responsive-diagonal-layout-policy.md`
- `almanac/workflows/slave-artifact-handoff.md`
- `almanac/workflows/cross-pc-slave-handoff.md`
- `../v6/almanac/flows/inventory-scan.md`
- `../v6/docs/inventory_scan_algorithm.md`
- `../v6/docs/inventory_sorting.md`
- `../v6/core/inventory_profiles.py`

이 작업은 P6 전체 구현이 아닙니다. 마스터가 최종 승인한 P6-1 baseline 위에서 인벤토리
탭 placeholder만 실제 데이터 수직 슬라이스로 교체합니다. 스캔·홈·통계·전술대항전·설정
탭을 구현하거나 P7 이후 기능을 시작하지 마십시오.

변경 전 baseline gate:

- HEAD `8f4ffd4b821ef88469d553db88639b2095ff84a9` 위에 마스터 승인된 P6-1 증분 존재
- Python 전체 61 tests, Flutter 전체 58 tests, `flutter analyze`, Windows release와 실제
  Dart↔Python catalog·학생 save/restart E2E가 마스터에서 통과한 상태
- `StudentPage`, `planning.student.catalog`, typed student repository save와 계획 draft 인계 존재
- `DiagonalSection` 내부가 투명 Material 경계를 사용함
- StudentPage dropdown이 `initialValue`, `isExpanded`와 ellipsis를 사용함
- catalog client test가 method별 request correlation을 사용하고 P6-1 viewport 3개가 통과함
- 현재 인벤토리 탭은 `SectionPlaceholderPage`
- repository inventory DTO와 wire mutation은 있지만 Dart typed save method, inventory catalog,
  shortage derivation과 실제 InventoryPage는 아직 없음

P6-1 master 보완이 없는 슬레이브 worktree에서 임의로 재구성하지 마십시오. 현재 승인본을
전달받지 못했다면 `BLOCKED`로 보고하고 마스터의 P6-1 accepted snapshot을 요청하십시오.
승인본이 존재하면 정확한 기존 P6-1 경로만 local baseline commit으로 고정할 수 있습니다.
push하지 말고 baseline commit ID와 포함 경로를 `verification.txt`에 기록하십시오. 다른
사용자 변경이 P6-2 대상 경로와 중첩되면 `BLOCKED`로 보고하십시오.

`input.md`의 요구사항에 따라 다음을 구현하십시오.

1. v6 대표 order·identity·zero-fill 특성화 fixture와 최소 data-only v7 catalog module
2. `planning.inventory.catalog` schema·fixture·Python handler·Dart typed client와 Mock
3. gross totals를 바꾸지 않는 별도 `planning.plan.shortages` derivation과 protocol
4. `repository.inventory.update`를 사용하는 Dart typed save와 revision/idempotency 처리
5. 실제 catalog + selected profile snapshot + saved plan을 합성하는 `InventoryPage`
6. 장비/아이템·category·검색·stable sort, manual quantity edit, unknown/zero 구분
7. 계획 부족·affected students 표시와 plan/scan 탭 callback
8. 전달된 inventory candidate의 compare/hold/review/commit 경계
9. Python, Dart contract/client와 Widget test source

전체 육성 부족, 장기 pressure, 추천·랭킹·학교 위험 분석, scanner session 시작·진행·취소
UI와 최종 반응형 layout state는 추측해 만들지 마십시오. snapshot에 없는 catalog row를 0으로
간주하지 말고, 낮은 confidence candidate를 자동 저장하지 마십시오. v6 runtime import와
Qt/QML/QWidget/Tk/PySide6 코드 복사는 금지됩니다.

슬레이브에는 Flutter/Dart SDK와 CodeAlmanac CLI가 없습니다. 설치하거나 공간 확보를 위해
파일을 삭제하지 마십시오. Dart/Flutter source와 test는 반드시 작성하되 실행 결과를
주장하지 않습니다. 도구 부재만으로 `BLOCKED` 처리하지 마십시오.

슬레이브 필수 검증:

```powershell
cd backend
py -3.11 -m unittest discover -s tests -v

cd ..
git diff --check
rg -n "from (PySide6|PyQt|tkinter)|import (PySide6|PyQt|tkinter)" backend frontend
rg -n "\.\./v6|BA Planner[/\\]v6" backend frontend
```

신규 inventory catalog/order parity, shortage schema/derivation, explicit-zero/unknown,
unresolved identity, complete-bucket repository test와 실제 Python stdio catalog/shortage 조회를
각각 단독 실행해 `verification.txt`에 명령·test 수·결과를 기록하십시오. 금지 import와 v6
runtime path 검색은 0건이어야 합니다. 문서·fixture 설명 문자열은 실제 runtime import와
구분해 판정하십시오.

마스터 전용 검증은 실행한 것처럼 쓰지 말고 다음 형식으로 그대로 인계하십시오.

```text
MASTER_REQUIRED: cd frontend; flutter analyze
MASTER_REQUIRED: cd frontend; flutter test
MASTER_REQUIRED: cd frontend; flutter build windows --release
MASTER_REQUIRED: 실제 Dart↔Python inventory catalog와 plan shortage 조회
MASTER_REQUIRED: 실제 Dart↔Python inventory save와 process restart 복원
MASTER_REQUIRED: gross required 불변, explicit zero/unknown shortage와 affected students 검증
MASTER_REQUIRED: inventory candidate hold/approve/stale/conflict와 MockAppService 흐름
MASTER_REQUIRED: 1280x720, 1440x900, 1280x960 Widget/golden overflow 검증
MASTER_REQUIRED: P6-1 StudentPage와 planning draft 회귀 검증
MASTER_REQUIRED: codealmanac validate
MASTER_REQUIRED: codealmanac health
MASTER_REQUIRED: git diff --check
```

결과물:

```text
docs/migration/p6-2-inventory-integration/artifacts/
├─ p6-2-inventory-integration.patch
└─ verification.txt
```

patch는 승인된 P6-1 baseline 위의 P6-2 단일 증분이어야 합니다. 신규 파일을 모두 포함하고
`input.md`, prompt, `output.md`, `artifacts/`, 이전 patch, handoff package, build/cache,
profile, database, log, scan result와 사용자 adaptive sample은 포함하지 마십시오. 모든
path는 `BA Planner/v7/...`여야 합니다. clean copy에서 `git apply --check --verbose`를
실행해 Checking 전체와 skipped 0을 확인하십시오.

`output.md`는 마지막에 작성하고 다음을 포함해야 합니다.

- 작업 ID와 `COMPLETED` 또는 `BLOCKED`
- baseline commit과 P6-1 승인 gate·dirty path 판단
- 구현 요약과 중요한 identity/zero/shortage 경계 결정
- 요구사항별 `PASS`, `FAIL`, `NOT_VERIFIED` 표
- 실행한 검증과 정확한 결과
- 모든 `MASTER_REQUIRED` gate
- 두 artifact의 상대경로, 설명, 실제 byte size와 SHA-256
- 미완료 사항과 위험

결과물이 준비된 뒤 다음 단일 송신 래퍼를 사용하십시오.

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p6-2-inventory-integration" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p6-2-inventory-integration"
```

IP, port 또는 token을 사용자에게 요구하거나 token을 화면·파일·로그에 기록하지 마십시오.
최종 보고에는 `TASK_OUTPUT_READY`와 `CROSS_PC_HANDOFF_READY`를 포함하십시오. ZIP, manifest,
sidecar, MASTER_PROMPT와 artifacts가 실제로 존재하고 hash가 일치해야 합니다. 마스터가
전달 package, patch와 모든 MASTER_REQUIRED gate를 직접 확인하기 전에는 P6-2나 P6 완료를
주장하지 마십시오.
