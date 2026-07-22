# 슬레이브 실행 프롬프트

BA Planner v7 P6-1 학생 실제 데이터 통합을 수행하고 cross-PC 인계 패키지를 생성하십시오.

작업 ID:

```text
ba-planner-v7-p6-1-student-integration
```

먼저 다음 파일을 처음부터 끝까지 읽으십시오.

- `docs/migration/p6-1-student-integration/input.md`
- `README.md`
- `AGENTS.md`
- `docs/migration/v6-knowledge-baseline.md`
- `almanac/workflows/p0-p6-workflow.md`의 P6 절
- `almanac/workflows/p0-p6-workflow-status.md`의 P5, P6 UX, P6 절
- `almanac/design/frontend-section-direction-and-user-flows.md`의 공통 규칙과 학생 탭 절
- `almanac/design/responsive-diagonal-layout-policy.md`
- `almanac/workflows/slave-artifact-handoff.md`
- `almanac/workflows/cross-pc-slave-handoff.md`
- `../v6/almanac/flows/student-scan.md`
- `../v6/STUDENT_PLANNER_HANDOFF.md`

이 작업은 P6 전체 구현이 아닙니다. P5가 완전히 적용된 baseline 위에서 학생 탭
placeholder만 실제 데이터 수직 슬라이스로 교체합니다. 인벤토리·스캔·홈·통계·전술대항전·
설정 탭을 구현하거나 P7 이후 기능을 시작하지 마십시오.

변경 전 baseline gate:

- P0~P4 완료 상태와 P5 최종 증분이 모두 존재해야 함
- Python 전체 59 tests, Flutter 전체 47 tests가 마스터에서 통과한 상태
- P5 production recognition coverage는 학생 2명과 inventory icon 2개의 제한된 범위
- 현재 학생 탭은 `SectionPlaceholderPage`
- repository student DTO와 mutation protocol은 존재하지만 Dart 저장 method와 실제 학생
  화면은 아직 없음
- planning은 단일 학생 lookup만 제공하며 catalog list protocol은 아직 없음

baseline commit과 `git status --short`를 `verification.txt`에 기록하십시오. P5 파일이
uncommitted라면 P5 인수 경로만 별도 local baseline commit으로 고정할 수 있지만 push하지
말고 commit ID와 포함 경로를 기록하십시오. 다른 사용자 변경이 P6-1 대상 경로와 중첩되거나
P5 필수 경계가 없으면 임의로 재구성하지 말고 `BLOCKED`로 보고하십시오.

`input.md`의 요구사항에 따라 다음을 구현하십시오.

1. 정적 student catalog용 versioned planning protocol request/response, schema, fixture,
   Python handler와 Dart typed client
2. `repository.students.update`를 사용하는 Dart typed mutation과 revision/idempotency 처리
3. 실제 catalog + selected profile repository state를 합성하는 `StudentPage`
4. 검색·필터·정렬, 상세 조회, 현재값 수정·저장과 모든 필수 UI 상태
5. 선택 학생을 P2 `PlanningPage` draft로 전달하는 명시적 탭 인계
6. 이미 전달된 student scanner candidate의 review/hold/commit 경계
7. Python, Dart와 Widget test source

계획 preset protocol, scanner session 시작·진행·취소 UI, 전체 반응형 layout state, 다른 탭
기능은 추측해 만들지 마십시오. 낮은 confidence candidate를 자동 저장하지 말고 정적
metadata·현재값·goal·계산 결과·inventory shortage를 분리하십시오. v6 runtime import와
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

신규 catalog schema/fixture/handler test, repository student update test와 실제 Python stdio
catalog 조회를 각각 단독 실행해 `verification.txt`에 명령·test 수·결과를 기록하십시오.
금지 import 검색은 0건이어야 합니다. 문서나 test fixture의 설명 문자열을 실제 runtime
import로 오인하지 말고 검색 결과가 있으면 각 경로를 판정해 기록하십시오.

마스터 전용 검증은 실행한 것처럼 쓰지 말고 다음 형식으로 그대로 인계하십시오.

```text
MASTER_REQUIRED: cd frontend; flutter analyze
MASTER_REQUIRED: cd frontend; flutter test
MASTER_REQUIRED: cd frontend; flutter build windows --release
MASTER_REQUIRED: 실제 Dart↔Python process에서 catalog 조회, repository 학생 저장과 restart 복원
MASTER_REQUIRED: 1280x720, 1440x900, 1280x960 Widget/golden overflow 검증
MASTER_REQUIRED: codealmanac validate
MASTER_REQUIRED: codealmanac health
MASTER_REQUIRED: git diff --check
```

결과물:

```text
docs/migration/p6-1-student-integration/artifacts/
├─ p6-1-student-integration.patch
└─ verification.txt
```

patch는 P5 baseline 위의 P6-1 단일 증분이어야 합니다. 신규 파일을 모두 포함하고
`input.md`, prompt, `output.md`, `artifacts/`, 이전 patch, handoff package, build/cache, profile,
database, log, scan result와 사용자 adaptive sample은 포함하지 마십시오. 모든 path는
`BA Planner/v7/...`여야 합니다. clean copy에서 `git apply --check --verbose`를 실행해
Checking 전체와 skipped 0을 확인하십시오.

`output.md`는 마지막에 작성하고 다음을 포함해야 합니다.

- 작업 ID와 `COMPLETED` 또는 `BLOCKED`
- baseline commit과 dirty path 판단
- 구현 요약과 중요한 경계 결정
- 요구사항별 `PASS`, `FAIL`, `NOT_VERIFIED` 표
- 실행한 검증과 정확한 결과
- 모든 `MASTER_REQUIRED` gate
- 두 artifact의 상대경로, 설명, 실제 byte size와 SHA-256
- 미완료 사항과 위험

결과물이 준비된 뒤 다음 단일 송신 래퍼를 사용하십시오.

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -RepositoryRoot "<SLAVE_REPOSITORY_ROOT>" `
  -TaskId "ba-planner-v7-p6-1-student-integration" `
  -TaskDirectory "<SLAVE_REPOSITORY_ROOT>\docs\migration\p6-1-student-integration"
```

IP, port 또는 token을 사용자에게 요구하거나 token을 화면·파일·로그에 기록하지 마십시오.
최종 보고에는 `TASK_OUTPUT_READY`와 `CROSS_PC_HANDOFF_READY`를 포함하십시오. ZIP, manifest,
sidecar, MASTER_PROMPT와 artifacts가 실제로 존재하고 hash가 일치해야 합니다. 마스터가
전달 package, patch와 모든 MASTER_REQUIRED gate를 직접 확인하기 전에는 P6-1이나 P6 완료를
주장하지 마십시오.
