# P2 작업 지시 — 실제 계획 화면 수직 슬라이스

## 작업 정보

- 작업 ID: `ba-planner-v7-p2-planning-screen`
- 저장소: 슬레이브 PC의 BA Planner v7 저장소 루트
- 작업 디렉터리: `<SLAVE_REPOSITORY_ROOT>\docs\migration\p2-planning-screen`
- 기준 단계: P0·P1 완료, P2 구현 대상
- 실행 환경: 슬레이브와 마스터는 서로 다른 PC이며 파일시스템을 공유하지 않음

## 목표

Flutter의 `계획` placeholder를 실제 학생 목표 입력 및 총 필요량 계산 화면으로 교체한다.
사용자는 학생 ID로 정적 메타데이터를 조회해 계획 대상을 추가·삭제하고, 현재 성장
상태와 목표 상태를 분리해 확인·편집하며, 학생별 및 전체의 **보유량 차감 전 총
필요량**을 계산할 수 있어야 한다.

P2는 영구 저장 이전의 in-memory 수직 슬라이스다. repository, scanner 및
인벤토리 기반 부족량은 구현하지 않는다.

## 작업 전 필수 확인

다음 파일을 UTF-8로 완전히 읽고 실제 코드가 문서와 다르면 코드를 우선한다.

1. `AGENTS.md`
2. `README.md`
3. `almanac/workflows/p0-p6-workflow-status.md`
4. `almanac/workflows/p0-p6-workflow.md`의 공통 불변식과 P2 절
5. `almanac/workflows/slave-artifact-handoff.md`
6. `almanac/workflows/cross-pc-slave-handoff.md`
7. `docs/migration/v6-knowledge-baseline.md`
8. `contracts/README.md`
9. `contracts/planning-types-v1.schema.json`
10. `frontend/lib/services/app_service.dart`
11. `frontend/lib/services/mock_app_service.dart`
12. `frontend/lib/services/process_app_service.dart`
13. `frontend/lib/ui/app_shell.dart`
14. `frontend/lib/ui/pages/section_placeholder_page.dart`
15. `frontend/test/widget_test.dart`

실제 서브시스템을 바꾸기 전에 `almanac/`을 확인하라는 저장소 규칙을 지킨다.
v6 동작을 추가로 조사하거나 코드를 참고해야 할 때만
`docs/migration/v6-knowledge-baseline.md`가 지정한 문서를 먼저 읽는다.

## 구현 범위

### 1. 계획 페이지 연결

- `AppSection.plan`에 전용 실제 계획 페이지를 연결한다.
- 다른 탭의 placeholder 동작, 기존 페이지 전환, 헤더와 개발 패널을 회귀시키지 않는다.
- 기존 테마와 반응형 레이아웃을 사용하고 좁은 창에서도 overflow가 발생하지 않게 한다.

### 2. 학생 조회·추가·삭제

- P0에 이미 존재하는 `AppService.getStudent(studentId)`만 사용해 학생 ID를 조회한다.
- 공백 ID, 조회 중, 학생 미존재, metadata 조회 오류를 화면에서 구분한다.
- 조회된 metadata의 `student_id`, `display_name`, `group`, `variant`를 안전하게 표시한다.
- 같은 학생을 중복 추가하지 않는다.
- 추가한 학생을 계획에서 삭제할 수 있다.
- P0에 목록/검색 protocol이 없으므로 전체 학생 목록 API나 새 wire method를 임의로
  만들지 않는다. P2의 검색은 정확한 학생 ID 조회로 구현하고 이 제한을 UI 문구와
  `output.md`에 기록한다.

### 3. 현재 상태와 목표 상태 분리

- `current_students`와 `plan.goals`를 별도의 Dart view/model 상태로 유지한다.
- P4 전까지 화면 상태는 명시적인 in-memory 정책으로만 유지한다. 앱 재시작 후 복원,
  파일 저장, SQLite, 프로필 저장을 구현하지 않는다.
- repository가 아직 없으므로 새 학생의 현재 상태는 protocol v1에 유효한 보수적
  초기값을 사용하고 화면에 임시 현재 상태임을 명시한다. fixture의 유효한 형태와
  `currentStudent` schema를 기준으로 하며, 목표 객체와 같은 Map을 공유하지 않는다.
- 현재 상태는 읽기 전용으로 표시하고, 목표만 편집한다.
- 빈 목표(`null` 또는 필드 생략)는 현재 값을 유지한다는 의미이며 숫자 `0`으로
  변환하지 않는다.

### 4. 목표 편집 필드

P0 schema의 이름과 범위를 그대로 사용해 다음 목표를 편집할 수 있게 한다.

- 레벨: `target_level` (0~90 또는 비움)
- 성급: `target_star` (0~5 또는 비움)
- 전용무기 레벨/성급: `target_weapon_level` (0~60),
  `target_weapon_star` (0~4)
- 스킬: `target_ex_skill` (0~5), `target_skill1`~`target_skill3` (0~10)
- 장비: `target_equip1_tier`~`target_equip3_tier` (0~10),
  `target_equip1_level`~`target_equip3_level` (0~70),
  `target_equip4_tier` (0~2)
- 능력치: `target_stat_hp`, `target_stat_atk`, `target_stat_heal` (0~25)
- 선택 사항: `favorite`, `notes`

편집 UI는 모든 필드를 한 화면에 무리하게 펼치지 말고 학생별 접기/펼치기 또는
논리적 그룹을 사용해 조작 가능하게 만든다. 정수 파싱, 범위, 빈 값 의미를 UI에서
검증하고 validation 오류를 해당 입력 또는 학생과 연결해 보여 준다.

### 5. 검증과 계산

- 계산 전에 `AppService.validatePlan()`으로 canonical plan을 받고, 그 결과를
  `AppService.calculatePlan()`에 전달한다.
- 계산은 반드시 `AppService`의 세 planning method 경계를 통해서만 수행한다.
  Widget에서 protocol client, Python process, backend 파일 또는 v6 모듈을 직접
  호출하지 않는다.
- 목표 변경 뒤 명시적인 계산 버튼 또는 안정적인 debounce 정책으로 다시 계산한다.
  중복 요청과 늦게 완료된 이전 요청이 최신 화면 상태를 덮지 않게 한다.
- 학생별 비용은 각 학생 하나만 포함한 canonical plan/current state로 같은
  `calculatePlan()`을 호출해 구하고, 전체 비용은 모든 학생을 포함해 구한다.
- `PlanCostSummary`의 scalar, count map, warnings를 사람이 읽을 수 있게 표시한다.
  값이 0인 긴 목록은 필요하면 접거나 숨길 수 있으나 테스트 가능한 핵심 총계는
  명확히 표시한다.
- 결과 명칭은 반드시 `총 필요량` 또는 동등한 표현을 사용한다. `부족량`, `부족 재화`,
  `보유량 차감`으로 표시하지 않는다.

### 6. 필수 화면 상태

다음 상태를 화면과 Widget test로 다룬다.

- 계획 대상이 없는 empty 상태
- 학생 조회 및 계산 loading 상태
- 입력 validation 오류
- backend disconnected 상태와 재연결 동작
- 학생 미존재
- metadata lookup/계획 validation/calculation 오류
- 계산 성공과 warning 표시

`AppService.state.connection`이 disconnected일 때 backend 호출 버튼은 적절히
비활성화하거나 재연결 행동을 제공하되, 이미 입력한 in-memory 목표를 버리지 않는다.

### 7. Mock과 테스트 지원

- `MockAppService`가 P2 성공 흐름을 실제로 시연하고 Widget test할 수 있도록
  결정적인 학생 metadata, canonical validation, 0이 아닌 계산 결과를 제공한다.
- 오류·loading·늦은 응답을 검증하기 위한 test double은 테스트 안에 둘 수 있다.
- 기존 `AppService` planning method 서명과 P0 schema는 변경하지 않는 것을
  우선한다. 변경이 불가피하다고 판단되면 구현 전에 `BLOCKED`로 보고하고 근거를
  남긴다.

## 필수 Widget test

최소한 다음을 자동 검증한다.

1. 계획 탭이 placeholder가 아닌 실제 계획 페이지를 연다.
2. 정확한 학생 ID 조회로 학생을 추가하고 중복 추가를 막으며 삭제할 수 있다.
3. 현재 상태와 목표 상태가 별도 표시되고 빈 목표가 `0`으로 전송되지 않는다.
4. 목표 값을 바꾸면 canonical validation 후 학생별 및 전체 총 필요량이 갱신된다.
5. 다중 학생 합산 결과가 각 학생 결과와 구분된다.
6. 총계를 부족량으로 표기하지 않는다.
7. empty, validation, loading, disconnected, 학생 미존재 및 calculation error 상태가
   깨지지 않는다.
8. 늦은 이전 계산 응답이 최신 결과를 덮지 않는다.
9. 좁은 창에서 주요 목표 입력과 총계 화면에 render overflow가 없다.
10. 기존 홈, 탭 전환, 개발 패널 및 backend transport 관련 테스트가 계속 통과한다.

테스트는 텍스트 전체 일치에 과도하게 결합하지 말고 안정적인 `ValueKey`와 의미 있는
행동을 사용한다.

## 금지 및 제외 범위

- Qt, QML, QWidget, Tkinter, PySide6 UI 코드 복사 금지
- `../v6` 런타임 import 또는 v6 파일에 대한 런타임 의존 금지
- P0 schema 우회, protocol payload 재해석 또는 새 planning wire method 추가 금지
- repository, 프로필 영구 저장, JSON/SQLite 병합 구현 금지
- scanner/matcher/capture/session protocol 구현 금지
- 인벤토리 보유량 차감 및 부족량 계산·표시 금지
- `backend/core/student_meta_data.py` 광범위 수동 편집 금지
- 생성/local 상태(`profiles/`, DB, 로그, scan 결과, Flutter `build/`, release 출력,
  Python cache)를 결과물 또는 커밋 대상으로 포함 금지
- 관련 없는 리팩터링이나 기존 사용자 변경 덮어쓰기 금지

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

추가로 금지된 GUI/v6 runtime import가 새로 유입되지 않았는지 `rg`로 검사한다.
실제 Python backend Widget/E2E 검증이 로컬 환경에서 가능하면 수행한다. 실행하지
못한 검증은 성공으로 쓰지 말고 `NOT_VERIFIED`와 이유를 기록한다.

## 완료 조건

아래 조건이 모두 충족되어야 `COMPLETED`로 보고한다.

- 계획 placeholder가 실제 in-memory 계획 화면으로 교체됐다.
- 학생 조회·추가·삭제, 목표 편집, 학생별 및 전체 총 필요량 계산이 동작한다.
- 실제 계산은 `AppService` planning method만 사용한다.
- 현재 상태, 사용자 목표, 총 필요량이 분리되고 부족량은 구현·표시되지 않는다.
- 필수 상태와 Widget test가 구현됐다.
- 기존 Python/Flutter test, analyze, Windows release build, Almanac 검증 및
  `git diff --check`가 통과했다.
- 결과 패치와 검증 기록이 아래 인계 계약에 따라 저장됐다.

## 결과물 및 인계 계약

소스는 슬레이브 PC의 작업 트리에서 수정하되, 마스터가 다른 PC에서 변경을
재현·검증할 수 있도록
다음 파일을 반드시 만든다.

```text
docs/migration/p2-planning-screen/
├─ input.md                 # 이 파일: 수정·삭제·덮어쓰기 금지
├─ output.md                # 모든 결과물이 준비된 뒤 마지막에 작성
└─ artifacts/
   ├─ p2-planning-screen.patch
   └─ verification.txt
```

- `p2-planning-screen.patch`는 P2에서 생성·수정한 소스와 테스트만 포함하는 재현 가능한
  unified diff여야 한다. `input.md`, `output.md`, 생성물과 기존 무관 변경은 제외한다.
- `verification.txt`에는 실행한 명령, 종료 코드와 핵심 결과를 기록한다. 실행하지 않은
  검증을 통과로 기록하지 않는다.
- 필요하면 추가 결과물을 `artifacts/`에 둘 수 있으나 모두 `output.md`에 기록한다.
- 각 결과물의 존재, 0보다 큰 크기, 바이트 크기와 SHA-256을 확인한다.
- 원래 `input.md`와 기존 결과물을 삭제하거나 덮어쓰지 않는다.
- 결과물을 대화나 임시 경로에만 남기지 않는다.
- 결과물을 영속화할 수 없으면 완료로 보고하지 말고 `BLOCKED`로 보고한다.

`output.md`는 `almanac/workflows/slave-artifact-handoff.md`의 계약을 그대로 따라
다음 내용을 포함한다.

- 작업 ID와 `COMPLETED`/`BLOCKED` 상태
- 수행 내용과 중요한 판단
- 모든 결과물의 상대경로, 설명, 크기, SHA-256
- 이 `input.md`의 주요 요구사항별 `PASS`/`FAIL`/`NOT_VERIFIED` 및 근거
- 실제 검증 명령과 결과
- 미완료 사항과 위험

모든 파일이 준비된 뒤에만 다음 형식으로 최종 보고한다.

먼저 외부 전달 패키지를 생성한다.

```powershell
cd "<SLAVE_REPOSITORY_ROOT>"
.\tools\new_cross_pc_handoff.ps1 `
  -TaskDirectory ".\docs\migration\p2-planning-screen" `
  -DestinationDirectory "<SLAVE_OUTBOX_OR_MOUNTED_MASTER_INBOX>" `
  -TaskId "ba-planner-v7-p2-planning-screen"
```

생성된 ZIP, `.sha256`, `.manifest.json`, `-MASTER_PROMPT.md` 네 파일을 모두 사용자에게
전달한다. 마스터 PC의 폴더에 직접 쓸 수 없으면 슬레이브 outbox에 만들고 사용자가
같은 네 파일을 옮길 수 있게 정확한 경로를 보고한다. 슬레이브의 로컬 절대경로만
보고하고 패키지 파일을 전달하지 않는 것은 완료가 아니다.

마스터가 같은 신뢰 가능한 Wi-Fi/LAN에서 `Receive-SlaveResult.ps1`을 실행하면 다음
단일 명령으로 마스터를 자동 발견하고 네 파일을 무선 전송한다. IP, port와 token을
사용자에게 요구하지 않으며 token은 결과물이나 로그에 기록하지 않는다.

```powershell
& "$HOME\.codex\ba-planner-slave\Send-SlaveResult.ps1" `
  -PackagePath "<생성된 ZIP 절대경로>"
```

마스터 수신기의 `WIRELESS_HANDOFF_RECEIVED` 확인 전에는 무선 전달 완료로 보고하지
않는다. 자동 발견이 실패하거나 사설 LAN 연결이 불가능하면 네 파일을 사용자에게
첨부하거나 수동 이동할 수 있게 보고한다.

```text
TASK_OUTPUT_READY
task_id: ba-planner-v7-p2-planning-screen
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
task_id: ba-planner-v7-p2-planning-screen
status: BLOCKED
output_md: <작성했다면 절대경로>
reason: <완료 또는 저장이 불가능한 구체적 이유>
```

마스터가 `output.md`, 결과물 존재 여부, 크기, SHA-256, diff와 검증 결과를 직접
확인하기 전에는 P2를 완료로 간주하지 않는다.
