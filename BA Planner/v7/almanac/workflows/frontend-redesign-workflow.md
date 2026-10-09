---
title: "Frontend Redesign Implementation Workflow"
summary: "2026-10-05 확정된 UI/UX 개선 시안(택틱 제외 57개 artboard, 10-06 스캔 탭·성장 계산기 추가 포함)을 Flutter 프론트로 옮기는 실행 계약입니다. 토큰·기하(FE1) → 공통 위젯(FE2) → 탭별 수직 slice(FE3~FE9, 필요한 백엔드 FB-1~FB-9 포함) → 마감(FE10) 순서와 gate, 결정 대장·artboard 지도·조사 보고서의 위치를 고정합니다."
topics: [workflow, design, architecture]
sources:
  - id: prototype
    type: file
    path: docs/frontend-redesign/prototype/2026-10-05/MANIFEST.json
  - id: register
    type: file
    path: docs/frontend-redesign/decision-register.md
  - id: artboard-map
    type: file
    path: docs/frontend-redesign/artboard-map.md
  - id: survey-shared
    type: file
    path: docs/frontend-redesign/survey/H-shared-elements.md
  - id: section-direction
    type: file
    path: almanac/design/frontend-section-direction-and-user-flows.md
  - id: responsive
    type: file
    path: almanac/design/responsive-diagonal-layout-policy.md
  - id: studio
    type: file
    path: almanac/design/section-template-studio.md
  - id: tactic-workflow
    type: file
    path: almanac/workflows/tactic-editor-boss-mechanics-workflow.md
  - id: post-consolidation
    type: file
    path: almanac/workflows/post-consolidation-workflow.md
  - id: orchestrator-log
    type: file
    path: almanac/workflows/frontend-redesign-orchestrator-log.md
---

# Frontend Redesign Implementation Workflow

## 목적과 배경

사용자가 UI/UX 개선 작업을 끝내고 Design 캔버스 "BA Planner v7 UI 개선 시안"을 확정했다(2026-10-05, 73개 artboard). 2026-10-06에 스캔 탭 6장과
성장 계산기 1장이 추가되어 80개가 되었다. 이 워크플로는 그중 **택틱 페이지(Tactic-*, Boss-*, Tactical-Timeline 23개)를 뺀 57개 artboard**를
현재 Flutter 프론트(`frontend/lib`)로 구현한다. 택틱 탭은 개발 중이며
`almanac/workflows/tactic-editor-boss-mechanics-workflow.md`의 T5a/T5가 맡는다. [@tactic-workflow]

시안 원본과 저장소 사본:

- 캔버스: `https://claude.ai/artifact/BqhYfDnvkiQCTjDv8XgYJ3` (version `1791216886-b4f5`, 2026-10-06). 사용자가 브라우저로 본다.
- 사본: `docs/frontend-redesign/prototype/2026-10-05/*.dc.html` + `canvas.json` + `MANIFEST.json`(sha256). 이미지(`/_blob/…`)는
  들어 있지 않다. 워커는 좌표·문구·색·상태를 사본에서 읽고, 그림 비교는 사용자가 캔버스로 한다. [@prototype]
- 사본을 읽을 때는 `py -3.11 docs/frontend-redesign/tools/dc_outline.py <파일> [--abs] [--text-only]`를 쓴다.
  파일마다 반복되는 공통 CSS와 긴 사선 path를 걸러 요소당 한 줄로 보여 주므로 원문을 통째로 읽는 것보다 훨씬 싸다.

오케스트레이터가 시안과 코드를 8개 그룹으로 대조한 조사 보고서는 `docs/frontend-redesign/survey/`에 있다.
각 slice 프롬프트는 해당 그룹 보고서만 읽게 한다.

| 그룹 | 보고서 | 범위 |
|---|---|---|
| H | `survey/H-shared-elements.md` | UI-Elements, W-Data/Layout/Filter/Info 위젯, 토큰 비교, 요소 카탈로그 |
| A | `survey/A-title-home.md` | 타이틀·계정 관리, 홈 연결 흐름, 스캔 팝업 |
| B | `survey/B-student.md` | 학생 탭, 학생 카드·인연·검색·필터 부품 |
| C | `survey/C-plan-flow.md` | 계획 만들기 4단계 |
| D | `survey/D-scenario.md` | 시나리오 목록·열어 보기·비교 |
| E | `survey/E-inventory.md` | 인벤토리 5화면 |
| F | `survey/F-stats.md` | 통계 탭과 기능 제안서 |
| G | `survey/G-pvp.md` | 전술대항전 5화면 |
| I | `survey/I-scan.md` | 스캔 탭 6화면(2026-10-06 추가) |
| J | `survey/J-calc.md` | 성장 계산기(2026-10-06 추가) |

조사의 핵심 결론:

- **그대로 재사용**: 셸(L-glass 헤더, 주 탭, 연결 배지, 개발 버튼), 80° 섹션 기하(`buildAttachedSectionPolygon`, 96 grid),
  lifted shadow(수식이 시안 4층 알파와 정확히 일치), 탭 전환 970ms, `DiagonalMediaListItem`, 성작·인연·상태 배지,
  `PlanPhaseCard`·`DiagonalFlowIndicator`, `PlanDiagonalScrollbar`, `ScrollViewportFog`, 재화 타일, 스테퍼.
- **부채**: 시안의 핵심 색(핑크 `#f2b3ef` 등)이 theme에 없고, 80° 계산이 108곳에 인라인, 사선 스크롤바 5벌,
  모션 상수 6벌이 중복된다. 쓸 만한 위젯 다수가 `plan_section_layout.dart`(8,445줄)·`student_section_layout.dart` 안에 private이다.
- **신규**: −10° 스큐 계열(세그먼트, 토글 칩, 단계 태그, 범위 슬라이더, 스큐 막대), 6색 칩, 레일 버튼, `DiagonalRow`,
  (i) 팝오버·플라이아웃·모달, 아이템 아이콘 타일, 데이터 위젯 11종. 현재 lib에 skew 변환은 0건이다.
- **화면 수준**: 타이틀은 diff 수준, 학생은 카드·필터 중심 수정, 계획·시나리오는 재구성, 인벤토리·통계·전술대항전은 사실상 재작성.
- **데이터**: 스냅샷 이력, 아이템 학교·티어 메타, 활성 계획 문서 저장, 전술 v2 쓰기·시도 횟수, 엑셀 해석, 게임 창 크기,
  학생 폼 목록이 백엔드에 없다. 육성도·위험도·계획 충족률은 산식이 없다.
- **탭 구성**: 탭바 8개(홈·학생·계획·인벤토리·전술대항전·통계·스캔·설정)는 바뀌지 않았다. "시나리오"는 계획 탭 안의 뷰 전환이고,
  "계획 만들기"는 계획 탭 안의 모드다. 스캔 탭 시안은 2026-10-06에 추가됐고(고르기 → 진행 → 결과 검토, 학생은 백그라운드·아이템은
  포그라운드, 전술대항전 스캔은 전술대항전 탭에서만), 설정 탭 시안은 없다. 성장 계산기는 학생 탭 기하를 그대로 쓰는 계산 모드다
  (진입점은 FD-160).

## 확정 결정

결정은 전부 결정 대장 `docs/frontend-redesign/decision-register.md`에 `FD-###`로 관리한다. [@register]
2026-10-05 사용자가 정한 뼈대 결정:

- **FD-001 시안 우선.** 시안이 기존 확정 문서(theme.dart 주석, section-template-studio.md의 계정·학생 Section 5 계약,
  student-card-rendering-lessons의 JP 배지 등)와 다르면 시안을 따른다. 충돌하는 문서 절은 **그 변경을 구현하는 slice에서**
  시안에 맞춰 고친다(대장의 "갱신" 근거 칸이 목록이다).
- **FD-002 백엔드 포함.** 시안이 요구하는 백엔드·프로토콜 추가를 이 워크플로에 포함하고, 화면별 수직 slice로 진행한다.
  프론트만으로 되는 화면을 먼저 한다.
- **FD-003 활성 계획 = 페이즈 문서.** 활성 계획을 `PlanningDocument`(페이즈·단계)로 저장하는 새 repository 계약을 만든다.
  goals v1은 거기서 파생한다. 인연 목표(학생 상세 B안의 `→30`)도 활성 계획 문서의 단계 목표에서 읽는다.
- **FD-004 체크포인트 C 선행 충족.** 2026-10-06 실제 검증을 인수하고 C 소스 커밋 `2156685ac63a852021e3dc01093185f78d97df49`를 확인했다.
  C 대기는 해제되었으며 FE1-a부터 코드 착수가 가능하다. 기존 slice별 결정·검증 규칙은 유지한다. [@post-consolidation]

대장 상태 규칙: `열림` 항목은 사용자 결정 전까지 "막는 slice"를 시작하지 않는다. `워커 재량` 항목은 권장안대로 처리하고
status에 FD ID로 보고한다. 워커가 새 모호점을 찾으면 status의 "발견 사항"에만 적고 대장은 오케스트레이터가 고친다.
대장 끝의 "slice별 막힘 요약" 표가 착수 가능 여부의 기준이다.

## 불변식

- **기준 viewport는 2560×1392**(2560×1440 모니터에서 최대화한 작업 영역, 헤더 아래 콘텐츠 영역은 y=184부터 2560×1208)다.
  시안 좌표는 이 viewport 기준이다. 섹션 rect는 96 grid로 옮긴다: `gx = x/2560·96`, `gy = (y−184)/1208·96`. [@responsive]
- **화면은 Studio 문서의 typed projection으로 배치한다.** 새 화면은 새 Studio 레이아웃 문서(`ui/studio/*_studio_layout.dart`)를 만들고,
  `almanac/design/section-template-studio.md`의 "Studio 구성을 실제 화면에 적용할 때의 규칙"을 그대로 지킨다.
  시안을 눈대중으로 다시 그리지 않는다. 섹션 path bounds는 기준 viewport에서 시안과 일치해야 하고(±1px), 섹션 내부 요소는 ±2px 안이다. [@studio]
- **반응형 정책을 지킨다.** 다른 창 크기에서 전체 화면을 `FittedBox`로 일괄 축소하지 않는다. 승인된 레이아웃 상태 안에서만 적응한다. [@responsive]
- **기존 v7 요소를 재사용한다.** 사선 스크롤바, 리스트·그리드 스크롤 포그, lifted shadow, 섹션 모션은 FE2에서 공용화한 한 벌만 쓴다.
  화면마다 새로 만들지 않는다. 시안에 스크롤바·포그가 그려져 있지 않은 스크롤 영역에도 공용 스크롤바·포그를 붙인다.
- **문구는 시안 그대로 쓴다.** 앱 UI 문구는 `~습니다` 체를 쓴다. 사용법·설명 문장은 화면에 상시 띄우지 않고 제목 옆 (i) 팝오버 뒤에 둔다(W-Info-Popover 규칙).
  상태·수치·선택지 설명은 그대로 보인다.
- **mock 기본 실행을 유지한다.** 새 `AppService` 메서드는 같은 slice에서 `MockAppService` 구현과 fixture를 함께 만든다.
  검수용 fixture는 해당 artboard의 예시 값(계정 `거모이는존재한다 (v7 UI 테스트)`, 학생·수치)을 재현해서, 사용자가 캔버스와 같은 숫자로 비교할 수 있게 한다.
- **데이터 의미를 지킨다.** 다섯 데이터 버킷(스캔 현재 상태, 정적 메타, 사용자 목표, 총 계산 결과, 재고 기반 부족)을 섞지 않는다.
  서로 다른 재화의 수량을 하나의 합으로 더하지 않는다. 모르는 값은 0으로 채우지 않고 '—'나 빗금으로 표시한다.
- **프로세스 경계를 지킨다.** Flutter는 파일을 해석하지 않는다(엑셀 해석은 Python). 프로토콜 변경은 additive를 원칙으로 하고,
  Dart `fromWire`의 키 검증·Python 응답·`contracts/` 스키마·mock을 같은 slice에서 맞춘다.
- **구조 변경과 시각 변경을 섞지 않는다.** FE1처럼 동작 보존 리팩터인 slice는 golden diff 0이 완료 조건이다.
  golden 기준선은 FE1-g에서 처음 만든다(FE1-a 시점에는 golden이 0개였다).
- **커밋은 slice마다 `frontend/tool/fe_commit.ps1`로 한다(2026-10-06).** 워커는 착수 전에 고칠 기존 파일마다 사본을
  `debug/frontend_<slice>/pre/<v7 기준 경로>`에 두고, 종료 때 `debug/frontend_<slice>/commit.json`(slice, message 줄 배열,
  modified, added, status)을 쓴다. 사용자는 `fe_gate.ps1`(GREEN) → `fe_commit.ps1 -Slice <slice> -DryRun` → `fe_commit.ps1 -Slice <slice>`만
  실행한다. 스크립트는 사본과 현재 파일의 차이만 index에 올리므로 기존 미커밋 변경과 섞이지 않는다. 사본이나 commit.json이 없으면
  그 slice는 완료가 아니다.
- **기존 미커밋 변경이 있는 파일을 고칠 때.** C 인계의 `unrelated-changes.json`에 있는 파일을 고칠 때도 같은 사본 규칙을 따르고,
  status에 "기존 미커밋 변경 있음"으로 적는다. `fe_commit.ps1`은 사본(base)·HEAD(ours)·slice 끝 내용(theirs)을 `git merge-file`로
  3-way 병합해 index에만 올린다. 기존 변경과 slice 변경이 같은 줄이면 충돌로 멈추고, 오케스트레이터가 처리한다(선례: FE0-base
  `36702c28` — slice가 기존 미커밋 작업 위에서 줄을 고친 경우 그 작업을 원래 내용 그대로 먼저 커밋했다, 사용자 승인). 파일째
  `git add` 하지 않는다. 스캐너 소유 미커밋 변경(서비스 4개, scan_page·scan_companion_dock, 스캐너 테스트)은 작업트리에 남아 있다.
- **기기 파일 쓰기는 쓴 뒤 다시 읽어 확인한다(2026-10-07).** 세션의 기기 쓰기 도구(작업 공간 → PC)가 방금 고친 내용이 아니라
  같은 경로의 이전 사본을 써 넣은 일이 여러 번 있었다(status 0단계 소실, 오케스트레이터 로그·워크플로·스캐너 로그 되돌림). 원인은
  작업 공간 파일 동기화 지연으로 추정한다. 규칙: 최종 내용을 새 경로에 한 번에 만들고 몇 초 기다린 뒤 쓰고, 쓴 뒤 PC 파일을 다시 읽어
  내용(해시)이 같은지 확인한다. 공유 문서(로그·status)는 쓰기 직전에 최신본을 다시 읽고 그 위에 덧붙인다. 파일 끝에 빈 줄을 남기지
  않는다(`git diff --check`가 저장소 전체를 검사한다).
- **PowerShell 도구 파일은 ASCII로만 쓴다(2026-10-06).** Windows PowerShell 5.1은 BOM 없는 파일을 CP949로 읽고, 기기 파일 전송에서
  BOM이 빠질 수 있다. 한글 메시지가 필요하면 별도 UTF-8 데이터 파일에서 읽는다.
- **golden PNG 갱신(시각 변경 slice).** 갱신된 `frontend/test/goldens/baseline/*.png`는 commit.json의 `whole`에
  `"frontend/test/goldens/baseline"`으로 넣는다(바이너리라 병합하지 않는다). 사용자 순서: `fe_gate.ps1`(비교, golden만 RED 예상)
  → 오케스트레이터가 `failures/` 차이 이미지를 검토 → `fe_gate.ps1 -UpdateGoldens` → `fe_gate.ps1`(비교 GREEN) → `fe_commit.ps1`.
- **워커 환경에 셸·Flutter가 없을 수 있다.** 그때 워커는 코드와 테스트만 쓰고, gate 실행은 사용자가 `fe_gate.ps1`
  (FE1-g 이후)로 한다. 통과를 주장하지 않는다.
- **테스트를 같이 옮긴다.** 화면을 재작성하면 그 화면의 widget test(ValueKey 의존)를 같은 slice에서 다시 쓴다.
  지운 테스트는 status에 목록과 대체 테스트를 적는다.
- **파일 소유권**: 택틱 세션 소유(`ui/pages/tactic_page.dart`, `ui/widgets/tactic/*`, `ui/models/tactic_models.dart`,
  `services/tactic_fixture_service.dart`, `test/tactic/*`)는 건드리지 않는다. 스캐너 세션 소유(`backend/core/` 인식 계열,
  `ui/widgets/scan_student_review_workspace.dart`, `scan_inventory_identity_review.dart`)는 수정하지 않는다. 새 스캔 탭은
  이 두 위젯을 새 파일에서 마운트하거나 마운트 해제만 한다. `ui/pages/scan_page.dart`(FE8-f1)와 `ui/widgets/scan_companion_dock.dart`(FE8-g3)는
  스캐너 세션에 미커밋 편집이 없는 시점(동결 창)에만 고치고, 추출한 로직 파일 위치를 스캐너 오케스트레이터 로그에 알린다.
  스캐너 프로토콜 추가(FB-10)는 스캐너 워크플로가 구현하고 이 워크플로는 요청과 소비만 한다.
  `app_section.dart`·`app_shell.dart`는 두 워크플로가 함께 쓰므로 최소 diff로만 고친다.
- `../v6` import 금지, Qt/Tk 반입 금지, 자동 커밋 금지. 커밋은 gate가 녹색으로 보고된 뒤 사용자가 승인한다.

## 검증

모든 slice의 공통 gate:

1. 자동 검사: `frontend/tool/fe_gate.ps1`(analyze → golden 외 테스트 → golden 비교 → almanac validate → `git diff --check`를 차례로, 2026-10-06부터 AGENTS.md 기준 명령). 맨 `flutter test`는 golden과 프로세스 E2E를 병렬로 돌려 E2E가 시간 초과되므로 쓰지 않는다. 백엔드를 고쳤으면 `cd backend; py -3.11 -m unittest discover -s tests -v`,
   프로토콜을 고쳤으면 Dart↔Python process E2E, `codealmanac validate`, `git diff --check`. FE 단계 마지막 slice와 FE10은 `flutter build windows --release`까지.
2. **워커 환경에서 도구가 안 돌면**(2026-10-04 체크포인트 C 때처럼 flutter 무출력, venv `.pyd` ACCESS_DENIED) 통과를 주장하지 않는다.
   대신 `frontend/tool/fe_gate.ps1`(FE1에서 작성: analyze·test·golden·validate를 한 번에 돌리고 요약을 파일로 남김)을 사용자가 일반 PowerShell에서 실행하고,
   그 요약을 status에 붙인다.
3. **사용자 시각 검수**: 사용자가 앱(mock 모드 `--dart-define=BA_PLANNER_USE_REAL_BACKEND=false`, 기준 viewport 최대화)과 캔버스를 나란히 보고
   artboard 지도 `docs/frontend-redesign/artboard-map.md`의 검수 포인트를 확인한다. [@artboard-map] 워커는 검수표만 만든다:
   artboard 이름 → 앱에서 그 상태를 여는 방법(탭, 개발 패널 토글, mock 시나리오) → 확인 포인트. 워커는 스크린샷을 반복 비교하지 않는다(토큰 절약).
4. FE2 동안에는 개발 패널에서 여는 **UI Kit 갤러리**(UI-Elements·W-* artboard 배치를 그대로 따른 페이지)가 검수 대상이다.

## 실행 순서와 gate

```text
FE0 ─(체크포인트 C 커밋)→ FE1 → FE2(a→b→c→d)
                                   ├─ Lane A: FE3 → FB-1 → FE4 → FE5 → FB-2·FB-3 → FE6 → FE7
                                   ├─ Lane B: FE8 (FB-4, FB-10은 스캐너 워크플로) ← FE2 뒤 병렬 가능
                                   └─ Lane C: FB-6·FB-7 → FE9            ← FE2 뒤 병렬 가능
                                   → FE10
```

워커가 한 명이면 Lane A → B → C 순서로 간다. 학생(FE3)이 먼저인 이유는 학생 카드·그리드·필터 모달을 계획 만들기(FE4-b)와
통계 필터(FE7-e)가 재사용하기 때문이다. 병렬로 돌릴 때는 lane마다 위 파일 소유권과 별도로 "공용 위젯 파일은 FE2 이후 Lane A만 고친다"를 지킨다.
다른 lane에서 공용 위젯을 바꿔야 하면 status에 요청만 적는다.

**Lane A 앞뒤 병렬(2026-10-07, 사용자 승인).** Lane A를 워커 두 명으로 나눈다.
- 프론트 워커: FE3-f2 → FE3-g → FE4 … 순서. 고치는 곳은 `lib/ui/**`와 위젯·golden 테스트다. 서비스 계층(`lib/services/**`), 백엔드, 계약은 고치지 않는다. 필요하면 status에 요청만 적는다.
- 백엔드 워커: FB-11(a 계산 메서드 → b 인연 선물) → FB-1 순서. 고치는 곳은 `backend/`(스캐너·tactic 소유 제외), `contracts/`, `lib/services/**`, 서비스 테스트와 process E2E다. `lib/ui/**`는 고치지 않는다. 화면 쪽 연결(예: 계산기 어댑터를 새 메서드로 바꾸기)은 프론트 워커 몫이다.
- 백엔드 워커는 `almanac/workflows/frontend-redesign-status-backend.md`에만 쓴다(세션 운영 규칙 6의 예외). commit.json은 `status: false`로 두고, 이 파일을 `whole`에 넣는다. 프론트 워커는 지금처럼 `frontend-redesign-status.md`에 쓴다.
- gate는 두 워커가 모두 멈췄을 때 돌린다. 한쪽 작업 중 파일 때문에 RED가 나면 그 워커가 끝난 뒤 다시 돌린다. 커밋은 slice마다 각자의 commit.json으로 하고, 파일 집합이 겹치지 않아야 한다.
- 백엔드 slice마다 Python 전체 테스트를 사용자 PC에서 돌린다(약 26분).

### FE0 — 준비 (코드 편집 없음)

| 항목 | 내용 | 상태 |
|---|---|---|
| FE0-1 | 시안 사본·MANIFEST·`dc_outline.py` 반입 | 완료(오케스트레이터, 2026-10-05) |
| FE0-2 | 조사 보고서 8개 반입 | 완료(오케스트레이터) |
| FE0-3 | 결정 대장·artboard 지도 작성 | 완료(오케스트레이터). 열림 15건 |
| FE0-4 | 체크포인트 C 커밋 확인 | 완료(2026-10-06). C `2156685ac63a` 확인·최종 인수, 다음 FE1-a |
| FE0-5 | FE3-d 전에 FD-074·FD-104 답 받기 | 완료(2026-10-06). 열림 23건 일괄 결정 |
| FE0-6 | 2026-10-06 추가 시안 7장 반입·조사(I, J 보고서)·대장(FD-140~173)·지도 갱신 | 완료(오케스트레이터, 2026-10-06) |
| FE0-7 | 열림 23건 사용자 결정 | 완료(2026-10-06): FD-166 (c), FD-096 (c), 나머지 권장안. 열림 0건 |

### FE1 — 기반: 토큰·기하·표면

| slice | 범위 | gate |
|---|---|---|
| FE1-a 토큰 (동작 보존) | `AppColors` 확장(accent·accentText·onAccent·scrollThumb·textSecondary·textDim·popover·rowSurface·indicatorSurface·scrim, 칩 6색 tone 쌍, 공격·방어 타입 5색), `AppMotion`(360/460/970/220/180ms), `AppRadii`, 컨트롤 높이 토큰, `AppType` 개정(FD-008·FD-010). 하드코딩된 같은 값을 토큰으로 바꾸기만 한다 | golden diff 0, 하드코딩 핑크 6곳 → 토큰 — **완료 2026-10-06**: 커밋 `54ed8086`(기존 타이포·계획 작업은 FE0-base `36702c28`로 먼저 커밋) |
| FE1-g golden 기준선 + 게이트 스크립트 (2026-10-06 추가, FE1-b 전 필수) | 저장소에 Flutter golden이 0개라 동작 보존 slice를 판정할 수 없다. 기준 viewport 2560×1392, DPR 1, 실제 폰트(Pretendard·GyeonggiTitle을 `FontLoader`로 asset에서 적재), mock fixture, 애니메이션 정착 후 `matchesGoldenFile`로 장면을 고정한다. 장면은 **인라인 80° 계산이 있는 파일을 모두 한 번 이상 그리도록** 고른다(최소: 타이틀, 계정 관리·편집·초상 선택, 홈, 학생 그리드·상세, 계획 메인 병목/페이즈별/전체, 요소 빌더, 페이즈 편집기, 학생 선택기, 프리셋 관리, 시나리오 목록·비교). 함께 FE1-d의 `frontend/tool/fe_gate.ps1`(analyze·test·golden·almanac validate·diff-check를 돌리고 요약 파일을 남김)을 만든다. golden PNG는 Windows 폰트 렌더 때문에 **사용자 PC에서** `flutter test --update-goldens test/goldens`로 한 번 생성하고 따로 커밋한다 | 사용자가 생성한 golden 커밋 + fe_gate 1회 녹색. 이후 FE1-b·FE2-a 등 동작 보존 slice는 이 golden diff 0이 완료 조건 — **완료 2026-10-06**: 17장, 비교 GREEN(`debug/frontend_gate/20261006_222432`), PNG 커밋 `8e95d946` |
| FE1-b DiagonalGeometry (동작 보존) | `tan80` 상수, `cutDepth(h)`, 레일 x(y), 법선 inset(g/sin80), 둥근 다각형 단일 함수(Q 곡선 vs 원호는 FE1-b에서 둘 다 측정해 시안 path와 맞는 쪽, 다른 쪽은 호환 래퍼), 행 오프셋 2모드(translate/resize). 인라인 108곳 교체 | golden diff 0, 기하 단위 테스트. 스캐너 소유 `scan_student_review_workspace.dart`의 3곳은 바꾸지 않는다. 교체 전 `flutter test --coverage test/goldens`로 108곳이 golden 장면에서 실행되는지 줄 단위로 확인하고, 실행되지 않는 줄은 기하 단위 테스트로 덮는다. 고치는 파일마다 착수 전 사본을 `debug/frontend_fe1b/pre/`에 둔다 — **완료 2026-10-06**: gate GREEN `20261006_231705`(419 + golden 17), 커밋 `d5f87b7b` |
| FE1-c SectionSurface (시각 변경) | 섹션 표면 .76·무블러·무테 + lifted shadow 4층(FD-006, FD-007). `DiagonalSection`·`SectionTemplateSurface` 계열을 한 표면으로 | golden 갱신 사유 기록, 사용자 검수(아무 탭이나 캔버스와 표면 비교) — **완료 2026-10-06**: golden 6장 갱신(예상 6장과 일치, 나머지 11장 차이 0), gate GREEN `20261006_233605`(424 + golden 17), 커밋 `99583757` |
| FE1-d 게이트 스크립트 | FE1-g로 앞당겨 합쳤다(2026-10-06) | — |

갱신 문서: `app/theme.dart` 주석, section-template-studio.md 표면 절.

### FE2 — 공통 위젯 키트 (+ UI Kit 갤러리)

새 공용 위젯은 `frontend/lib/ui/kit/` 아래에 둔다(기존 `ui/widgets/`의 private 위젯을 옮길 때도 여기로). 각 sub-slice는 만든 위젯을 UI Kit 갤러리에 올린다.
요소 이름은 H 보고서 §6 카탈로그 이름을 그대로 쓴다. [@survey-shared]

| slice | 범위 | 재사용·교체 | gate |
|---|---|---|---|
| FE2-a 행·스크롤 | `DiagonalRow`(.srow/.row/.plain/.tile, default/hover/selected/blue, 테두리 path 공유 hit test), `DiagonalScrollViewport`(resize·translate 모드), `PlanDiagonalScrollbar` 공용 이동과 private 4종 대체, `ScrollViewportFog` extent·색·페이드 범위 파라미터 | 기존 학생·계정·프리셋·페이즈 편집기 스크롤바를 공용으로 교체(동작 보존) | 기존 화면 golden diff 0 + 갤러리 검수(W-Layout "사다리꼴 안 스크롤") — **완료 2026-10-07**: gate `20261007_004310` |
| FE2-b 소형 컨트롤·제목 | `BaChip(tone, removable)`, `StageTag`, `SkewSegmented`, `SkewToggleChip`/`TypeChip`, `FilterButton`, `BaSwitch`, `Stepper`+`MaxBadge`(추출), `NudgeButtons`, `TonalButton` 핑크 변형, `RailButton`(+그룹), `PanelTitle`/`TileTitle`/`SubHeader`/`KV` | Material `SegmentedButton`(4페이지)·`Chip` 교체는 각 탭 slice에서 한다. 여기서는 위젯만 | 갤러리 검수(W-Layout 칩·세그먼트·버튼, W-Filter) — **완료 2026-10-07**: 커밋 `859c554a` |
| FE2-c 오버레이 | `InfoPopover`(i, hover·focus·tap, 좌/우 정렬, 섹션 경계 안 정렬), `AnchoredFlyout`(r/l/dn/dl, 꼬리, 사선 path 트리거) + 페이즈·시나리오·점 프리셋, `BaModal`(스크림 + #0d151f 패널). `OverlayPortal` 기반 | `Tooltip`으로 쓰던 설명은 각 탭 slice에서 옮긴다 | 갤러리 검수(W-Info-Popover, W-Layout 팝오버), 키보드 포커스로 열림 테스트 — **완료 2026-10-07**: 커밋 `bb1e3478`, gate `20261007_102114` GREEN. 남은 일: 모달 포커스 가두기·배경 접근성 차단과 Esc 이중 처리는 `BaModal`을 처음 실제로 쓰는 slice(FE3-d 필터 모달)에서 더한다 |
| FE2-d 이미지·차트 원자 | `ItemIconTile`(rarity 배경 + 92% 아이콘), `PortraitStrip`(+"…+n"), `SkewBar`(`PlanInventoryCoverageBar` 흡수), 차트 primitive(`StatChartFrame` viewBox×1.25, 80° 막대, 빗금, 축·기준선, 팔레트, hit-test geometry), `KpiTile` | 차트 라이브러리를 추가하지 않는다(CustomPainter) | 갤러리 검수(W-Data KPI·아이템 타일·막대 행) — **완료 2026-10-07**: 커밋 `1f65b64a`, gate `20261007_111210` GREEN(295 + 218 + 프로세스 28 + golden 17) |

### FE3 — 학생 탭

| slice | 범위 | 백엔드 | gate·갱신 문서 |
|---|---|---|---|
| FE3-a DE 카드·그리드 | 속성 글자 칩(오른쪽 위, 80° 계단, 방어 축약 라벨), 이름 카드 밖(미보유 흐림), 배지 채워 쌓기, 행 피치 191.3. `StudentGridCardOverlayPainter`·`StudentDiagonalGrid`는 계획 쪽도 쓰므로 `plan_student_selector`·`plan_element_builder` 회귀를 같이 본다 | — | Student, W-Card-*, W-Card-Grid-DE 검수. student-card-rendering-lessons, section-template-studio 학생 카드 절 갱신 — **완료 2026-10-07**: golden 3장 갱신(예상과 일치), 커밋 `620a98ee` |
| FE3-b 인연 B 게이지 | 현재 랭크 + 목표 빗금·점선·`→N`. 목표는 활성 계획 문서 단계 목표(FD-003). FB-1 전에는 목표 없음 상태로 그린다 | — | W-Bond-Variants B, Student S3. student-detail-indicator-lessons 갱신 — **완료 2026-10-07**: 커밋 `809d903b`(학생 golden 7명 fixture, students-detail 분리, students-grid-name-off 추가) |
| FE3-c S4 확장 | 결과 수 줄, 적용 필터 칩(×, 모두 지우기), 최근 본 학생. 필터 상태를 layout state에서 페이지 컨트롤러로 올린다 | — | Student S4 — **완료 2026-10-07**: 커밋 `b7bbfcce`(배지 글꼴 명시, golden 학생 10명 두 줄 포함) |
| FE3-d 필터 모달 | 학생·계획 1·통계가 함께 쓰는 필터 모달(상태 객체를 주입받는 구조, FD-104). 토글 칩, 타입 칩, `RangeSliderRow`, `StarRangeBar`, draft→적용, 범위 모델 재구성. Section 5·범위 카드 2장 폐기 | (FD-074 결과에 따라 프리셋 저장) | Student-Filter. section-template-studio "학생 Section 5 필터" 절 대체 — **완료 2026-10-07**: d1 `ddc251eb`(부품·모델), d2 `0890de7a`(모달 연결, Section 5·범위 카드 폐기, golden `students-filter-open` 추가) |
| FE3-e 다중 폼 교대 | 폼 2개 이상 학생 초상 3초 교대, warmup에 폼 이미지 포함 | FB-5 | W-Card-States "폼 2개" — **완료 2026-10-07**: 커밋 `a3692424`(공유 `StudentFormClock`, FB-5 catalog `forms`, GyeonggiTitle 빠진 글리프는 Pretendard 대체, golden 4장 갱신 + `students-grid-second-form` 추가) |
| FE3-f 성장 계산기 | 학생 탭 계산기 모드(진입·복귀, S1 버튼 세트, 헤더 제목 교체), 목표 13행(시안 12행 + 애장품 행, FD-166 (c); 스테퍼·정규화·MAX·되돌리기·바꾼 목표 칩), S3 인디케이터를 목표값으로 + "현재 …" 태그, S4 선택 학생·최근 계산, 크레딧 타일(내역 막대는 FD-162 결과에 따라)·성장 재화 목록, 디바운스 재계산. 계산기 목표는 저장하지 않는다. 인연 타일은 빈 상태 | FE3-a~c | Calc-Student(인연 타일 제외, 애장품 행은 시안에 없으므로 다른 행과 같은 모양으로) — f1 **완료 2026-10-07**: 커밋 `7ec07589`(상태 모델·정규화·계산 어댑터, 화면 연결 없음). f2a **완료 2026-10-08**: 커밋 `3e7272e2`(진입·복귀, S1, S2 두 열, 계산 연결, `ItemIconTile` 자산 없음 대체 표시, golden `students-calculator` 추가). f2b **완료 2026-10-08**: 커밋 `576bd568`(S3 목표·토글, S4 요약·최근 계산, 어댑터 교체, 크레딧 내역 5묶음, 애장품 가용성 반영). FE3-f 완료 |
| FE3-g 인연 선물 타일 | 선물 3안(선호 대형/일반/쓰다듬기), 선물 팝오버, 배분 규칙(FD-164) | FB-11, FD-163 | Calc-Student 인연 타일 — **보류(2026-10-08 사용자 결정: 데이터 먼저)**: 인연 경험치 표·쓰다듬기 수치를 확보한 뒤 FB-11b와 함께 진행. 그때까지 계산기 인연 타일은 빈 상태. **보류 해제 2026-10-09**: FB-11b `7d0af068` 커밋. 프론트 순서는 FE4-d 뒤 — **완료 2026-10-09**: 커밋 `6eb04542`(gate `20261009_185920` GREEN, golden `students-calculator` 갱신·`students-calculator-bond-popover` 추가) |

### FB-1 — 활성 계획 문서 저장

**분할(2026-10-08, 백엔드 워커 설계 조사 `frontend-redesign-status-backend.md` "FB-1 읽기 전용 설계 조사" 승인).**
- FB-1a 문서 v2: 19-key nullable targets(`null` = 목표 없음, 0은 실제 값), 학생별 `goal_metadata`(favorite·notes), 계산 경로가 null을 원본 목표로 보존(유효 상태는 계산 중에만), `planning.document.calculate`·시나리오 저장/비교가 v1·v2를 함께 읽음. v1 정수 의미와 FB-11a 계약은 바꾸지 않는다.
- FB-1b 저장·이관: `repository.plan.get/save`, goals v1 파생(학생별 마지막 단계, bond_rank는 문서에만), legacy 첫 로드 이관(bond_rank 항상 null, 현재값으로 목표를 채우지 않음, 중복 goal 정책 fixture 먼저), legacy `repository.goals.save` 경로 정리. 이관으로 revision이 바뀌므로 title·scan·tactical 쪽 소비자는 소유자에게 알린다. — a **완료 2026-10-08** `682b2a7b`. b **완료 2026-10-09** `11426131`(21파일, Python 898 통과) + 소비자 연결 `86589da6`(fe1brev: title·계정 화면 revision 전파). scan·tactical은 tactic 오케스트레이터에 알림(10-09 00:50).
- FB-1c 교체 보존: `repository.plan.replace`(기존 활성 문서를 시나리오로 보존 + 새 활성 문서를 한 transaction, lock 순서·journal 복구). FE4-e 전에만 있으면 된다. — **완료 2026-10-09**(Python 912 통과, fb1c·fe4d1·문서 커밋, HEAD `e2502aed`).
- 프론트 연결(FE4-h, 아래 FE4 표): 화면이 FB-1b 저장 문서를 읽도록 바꾼다(`_loadRepositoryPlan` 메모리 변환 → `RepositoryPlanService`, 학생 →N·계산기 계획 포함 판정을 문서 기준으로). 백엔드 상태 문서 FB-1b "프런트 연결 메모"·"소비자 영향" 표가 입력이다.

`repository.plan.*`(가칭: 활성 계획 문서 조회·저장) 신설. 기존 goals v1만 있는 프로필은 첫 로드 때 지금 메모리에서 하던 1페이즈 변환을
영속화한다. 저장할 때 goals v1을 파생해 기존 `calculateShortages` 등 소비자가 그대로 동작하게 한다. **"목표 없음"을 문서에 명시적으로 나타낸다**(FE3-b 발견: 지금 메모리 변환 `planningDocumentTargets`는 인연 목표가 없으면 현재값(없으면 1)을 채워 가짜 목표가 된다. 학생 탭 →N은 이 값을 쓰지 않는다). Python·`contracts/`·Dart 클라이언트·mock·
계약 테스트·process E2E를 한 slice로 한다. gate: 기존 v6 가져오기·시나리오 저장·통계 경로 회귀 0.

### FE4 — 계획 만들기 (계획 탭 안의 모드)

공통 골격은 3-Section(A 진행 레일 (0,209,587,1183) 왼쪽 사다리꼴 / B 본문 (400,209,1702,1183) 평행사변형 / C 보조 (1920,209,640,1183) 오른쪽 사다리꼴)이다.
새 Studio 문서가 필요하다. 시안 script는 비어 있으므로 상태 전이는 변형 artboard(One/Many/Filter)의 차이로 정의한다(C 보고서 §1~§4).

| slice | 범위 | 선행 |
|---|---|---|
| FE4-a 흐름 골격 | Studio 문서, StepRail(스텝 4개·요약 4행·다음/이전), 초안 `PlanningDocument` 컨트롤러 + 디바운스 계산, 부족 재화 플라이아웃. 현 `_showStudentSelector/_showElementBuilder/_showPhaseEditor/_creatingScenario` 플래그 묶음을 대체 | FD-082 — **완료 2026-10-08**: 커밋 `a18897a1`(초안 컨트롤러·StepRail·Studio 문서, 기존 세 화면은 B 본문에 축소 수용, golden `plan-flow-step1/2` 추가). 임시 상태: 기존 화면이 작게 보이고 C 보조가 비어 있다(FE4-b~d에서 교체) |
| FE4-b 1단계 학생 고르기 | 8열 그리드·순서 배지·C 패널 목록/압축, 한 명 모드(학생 상세 인디케이터 재사용), 필터 모달 + 계획 칩 그룹 | FE3-a·FE3-d, FD-074 — **완료 2026-10-08**: 커밋 `2a5a7655`(새 1단계, 초안 문서 v2 전환, golden `plan-flow-step1` 갱신·`-many`·`-filter` 추가). 후속 확인: 필터 장면 왼쪽 레일 위 "필터 · 2" 알약 위치 |
| FE4-c 2단계 목표 정하기 | 학생 탭 줄·가로 단계 카드·COST(`stage_results[].cost`)·현재→최종, 프리셋 바. 미배정 목록 폐기 | FD-074 — **완료 2026-10-09**: 커밋 `4a831177`(새 2단계 B·C, `PlanFlowGoalEditor`, 더 보기 패널 FD-072, golden `plan-flow-step2` 갱신·`-step2-more` 추가, `-step1-filter` 알약 수정) |
| FE4-d 3단계 단계 순서 | 칸(=페이즈) 보드, 드래그, 같은 학생 선행 강제(기존 `_sequenceOrderIsValid` 재사용), 상태 배지, 자동 정렬, Many 모드 | — **분할(2026-10-09)**: d1 = Flow-3-Order(칸 보드·드래그·드롭 거부·같은 학생 회색 화살표·상태 배지 FD-035·C 상세·자동 정렬 3종·칸 이름/추가 FD-069·071, 3단계 축소 페이즈 편집기 교체 FD-070). d2 = Flow-3-Order-Many(12개 초과 작게 보기·크게/작게 seg·선택 카드 확장·이어진 선만·툴바·줄바꿈 스크롤). 직접 선행(분홍 점선)·"나중에" 칸은 FE4-f — **완료 2026-10-09**: d1(fb1c 뒤 커밋, golden `plan-flow-step3`), d2 `7cd9592e`(golden `plan-flow-step3-many` 추가, 펼친 카드는 칩을 가리지 않고 아래를 민다). 후속: 사이 줄 칩 위를 지나는 곡선은 FE4-f에서 |
| FE4-e 4단계 저장 | 미리보기, 활성 계획 비교, 시나리오로 저장(기존 `createScenario`), 활성 계획에 페이즈로 추가/이걸로 바꾸기(FB-1) | FB-1, FD-031 — **완료 2026-10-09**: 커밋 `3af5246c`(gate ② `20261009_215639`, golden `plan-flow-step4`·`plan-flow-step4-append` 추가). 후속(FE4-i): golden 비교 대역과 계산 대역 기준 맞추기 |
| FE4-f 교차 선행·나중에 칸 | 학생 간 선행 연결, "나중에" 칸 저장 | FB-8, FD-068. FB-8 조사의 소비자 표(초안 복원·명시 deferred와 임시 미배치 구별·칸별 stable topological sort를 document 배열에 반영·편입 ID remap)가 입력 |
| FE4-g 계산기 → 계획 넘김 | `PlanningStudentSeed`에 목표를 실어 계획 만들기 2단계를 계산기 목표로 열기, 이미 초안·활성 계획에 있는 학생 처리(FD-171) | FE4-c, FE3-f |
| FE4-h 저장 문서 읽기 연결 | 계획 화면·학생 탭·계산기가 `repository.plan.get` 문서를 읽도록 전환(`_loadRepositoryPlan` 메모리 변환 제거, 빈 문서를 goals로 되살리지 않음, state·plan revision 일치 재조회, `get.calculation=null`은 계산 불가 표시). 학생 →N은 문서의 마지막 nullable bond. 통계·인벤토리는 호환 경로 유지 | FB-1b. FE4-e 전에 끝낸다 — **완료 2026-10-09**: 커밋 `8beab94e`(gate `20261009_171109` GREEN, golden 변경 0). 후속(FE4-e): 기존 페이즈 편집기·편입 뒤 작업 문서를 정수 v1로 다시 만드는 경로가 남아 있다. 저장 때 v2 null이 정수로 바뀌지 않게 한다 |
| FE4-i 프리셋·내 그룹 저장 연결 (2026-10-09 추가) | FB-14 `repository.presets.get/save`(프로필별, 자체 revision, 전체 교체 + idempotency)를 화면에 연결: FE4-c 2단계 프리셋 바·C 패널의 단계 프리셋 저장·적용·이름 바꾸기·삭제(단계 이름 포함, nullable 목표 그대로), FE4-b 1단계 "내 그룹" 칩 저장·불러오기. 필터 프리셋은 범위 밖(FD-074 (b), 칩 숨김 유지). FD-169 계산기 "빠른 목표"의 프리셋 항목도 같은 저장소를 읽는다 | FB-14, FD-074. FE4-e 뒤, FE4-f 전(FB-8b를 기다리는 동안) — **완료 2026-10-09**: gate ② `20261009_231201` GREEN(golden 7장 갱신, `plan-flow-step2-saved` 추가), golden 비교 대역을 계산 대역 기준으로 맞춤. 후속(FE5-b): 계산 대역을 문서 의존으로 바꿔 비교 차이 표현을 golden에 다시 담는다 |

### FE5 — 시나리오·활성 계획 보기 (계획 탭 안의 뷰 전환)

| slice | 범위 | 선행 |
|---|---|---|
| FE5-a 목록 v2 | 정렬 seg·필터 칩·검색·오래된 개수·펼침 행 액션(열기/복제/이름·설명/삭제 — 서비스는 있음), 활성 계획 고정 행, 비교 담기(최대 4) | FE2 |
| FE5-b 미리보기 | 선택 시 `getScenario` + `compareScenarios(active, s)`, 지연 표시·캐시 | FE5-a |
| FE5-c 보기 모드 + 병목 탭 | 읽기 전용 보기 상태, 3섹션 레이아웃(활성 계획 홈 포함, FD-082), 활성 대비 KPI 4개·delta 칩, 병목 카드. 요약 행 3종을 상수(`planOverallProgressPercent = 72` 등)에서 projection으로 | FD-034, FD-082 |
| FE5-d 페이즈별·전체 탭 | 진입/필요/종료 + 막대 + delta, 전체 2~5열 그리드 | FD-031, (필요시 FB-9) |
| FE5-e 4열 비교 | 기준 계획 선택, 행 그룹, 세로 넘침 처리 | FD-034, (필요시 FB-9 다중 비교) |
| FE5-f 정리 | 옛 계획 메인 Section 1 버튼 묶음, 페이즈 편집 진입점, `_PlanWorkspaceSnapshot` 왕복 로직 폐기·이관, `planning_page_test`·`plan_element_builder_test` 재작성 | FE4·FE5 전부 |

### FB-2 · FB-3 — 이력과 아이템 메타

- **FB-2 설계 승인(2026-10-09 23:25, 오케스트레이터 로그·status-backend "FB-2 읽기 전용 설계 조사")**: profile JSON 안 optional `current_history` v1(같은 transaction), source scan/manual/import, 저장 단위 commit 1건·표시 단위(스냅샷 n회·추세 점)는 scan 세션, 승인 scope만 시각 갱신·diff 0 적용도 기록, raw 문자열, 보존 365일/10,000건/16 MiB. 분할: **FB-2a** 저장 기반(manual/import/new/legacy·current 쓰기와 create/import journal·scanner용 선택 port) → **FB-2b** scan 연결 + summary(스캐너 소유자 대응 뒤, 요청은 tactic 로그 23:25) → **FB-2c** events/diff/기간 조회 → **FB-2d** 프로필 삭제 journal(전술 v1/v2 파일·lock 조율 뒤).
- **FB-2 스냅샷 이력 + 마지막 스캔 시각**(FD-041): 학생·인벤토리 저장 이력(시각, source, `resource_key`·학생 단위 diff), 조회 메서드,
  프로필별 마지막 스캔 시각. 이력 키는 `resource_key`다(inventory-catalog-order). 인벤토리·통계·타이틀 계정 메타가 함께 쓴다.
  스캔 탭의 "종류별 마지막 스캔"·아이템별 "n일 전 스캔"을 위해 이력 레코드에 `scan_kind`·`inventory_scan_profile`을 넣고,
  바뀐 값이 없는 적용도 시각을 남긴다(FD-147).
  `scan_kind`·`inventory_scan_profile`은 **불투명 문자열로 받은 그대로 저장한다**(고정 enum 검사 금지, 2026-10-06). 스캐너의 그리드 스캔
  방식 실험으로 프로필 구성이 바뀌어도 이력 저장·조회가 깨지지 않게 하기 위해서다. 화면 표시명은 프론트의 표시 표에서 찾고, 모르는 값은
  원문 그대로 보여 준다.
- **FB-3 아이템 카탈로그 메타**(FD-096): `planning.inventory.catalog` 행에 학교·티어·family·획득처 추가, 학생·단계별 필요량 분해, 통화(크레딧·엘리그마) 카탈로그 항목 추가 — 보유량은 스캔으로 받는다(FD-096 (c), 인식은 FB-10). 수동 입력은 두지 않는다.
  `InventoryCatalogEntry.fromWire`의 고정 키 검사를 같은 slice에서 고친다.

### FE6 — 인벤토리

| slice | 범위 | 선행 |
|---|---|---|
| FE6-a 로직 추출 + 부족 위험 | `_InventoryPageState`의 로드·편집·저장·부족 계산을 컨트롤러로, 4섹션 배치, 위험도 행, 상세(kv·사용 학생·직접 고치기·스캔/계획 이동). 이력·획득처는 빈 상태. 후보 승인 `_CandidatePanel`은 스캔 탭 아이템 검토(FE8-g5)로 옮기므로, FE8-g5가 끝난 뒤 제거한다(그전에는 그대로 둔다). FD-146이 영속 "확인 필요"로 정해지면 그 표시를 그린다 | FD-030, FD-031 |
| FE6-b 전체 아이템 | 종류별 타일 + 충족 막대 + 플라이아웃 | FE6-a |
| FE6-c 분석 | 학교별 BD·노트, 장비 부위×티어 히트맵, 부족 상위 행 | FB-3, FD-031 |
| FE6-d 오파츠 확장 | 확장 버튼 → 다른 섹션 퇴장 → 오파츠 확대 → 선택 상세. `plan_phase_editor`의 rect morph(`phaseEditorElements`/`_lerpGridRect`)를 공용 섹션 morph로 추출(실수 rect 보간) | FE6-c |
| FE6-e 티어별 충족률 | 노트·BD 학교×티어, 오파츠 종류×티어 | FB-3, FD-031 |
| FE6-f 이력 연동 | KPI 델타, 상세 스파크라인, 최근 변화 | FB-2 |

### FE7 — 통계

공통 레이아웃: 왼쪽 주제·범위 (0,209,587,1183) / 가운데 KPI + 위젯 세로 스크롤(translate 모드, 그래프마다 원래 비율, 차트 ×1.25) (400,209,1702,1183) /
오른쪽 근거 + 원본 탭 이동 (1920,209,640,1183). 1차 범위는 Statistics-Proposal 확정 사항대로 K·D·A1·A2·B1·C1·C2다.

| slice | 범위 | 선행 |
|---|---|---|
| FE7-a 골격 | 3열, 주제 3개 전환, 기준 데이터 자리, 위젯 타일 계단 배치, 근거 패널 틀. 기존 `_reload()` 재사용 | FD-104 |
| FE7-b 성장 1차 | 육성도·항목 완성도 projection, KPI(성장), A1 히스토그램, A2 트랙 막대, 구간 선택 → 근거 목록 | FD-028 |
| FE7-c 인벤토리·계획 1차 | B1(재화별 충족률, `ShortageCategoryStatistics`의 이종 합산 교체), C1 불릿, C2 산점 | FD-031, FD-034 |
| FE7-d 원본 탭 이동 | `AppShell._open`에 navigation intent(학생 필터·범위, 인벤토리 행, 계획 단계), 대상 탭 수신, "← 통계" 복귀 칩 | FE3-d, FE6-a, FE4-d, FD-028 |
| FE7-e 통계 전용 필터 | 필터 모달 재사용, 통계 필터 상태 분리 + 학생 탭 필터 불러오기, A1~A6에만 적용 | FE3-d, FD-074, FD-104 |
| FE7-f 2차 | A3·A4·B2·C4 | FD-028 |
| FE7-g C3 계단선 | 활성 계획 문서 계산(phase_results·bottlenecks) → 페이즈별 누적 부족 | FB-1 |
| FE7-h 이력 연동 | A6·B3·KPI 증감·스냅샷 1회 문구 | FB-2, FD-041, FD-096 |
| FE7-i 3차 | A5·C5 | FD-028 |

### FE8 — 타이틀·홈·스캔 (Lane B)

| slice | 범위 | 선행 |
|---|---|---|
| FE8-a 타이틀 diff | T1~T11(A 보고서 §2.4): 시작 380, 설정·나가기 크기, 보유율 진행 막대, `보유 217 / 265`, 카드 전체 버튼, 로고 glow, Space 키캡. Studio JSON 재저장 + projection 테스트 | — |
| FE8-b 계정 관리 목록 + 추가 모달 | 행 그라데이션·진행 막대·`지금` 칩·포그, 추가 = 이름만 받는 모달 | FE2-c |
| FE8-c 편집기·초상 통합 | 확장 패널(편집기 + 6열 초상), 메타 줄(마지막 스캔은 FB-2 전까지 숨김) | (FB-2) |
| FE8-d 게임 창 연결 상태 | 앱 전역 `connectedTarget`, 헤더 칩(회색 미연결 / 녹색 "연결됨 · Blue Archive · 2560×1440") | FB-4, FD-116 |
| FE8-e 창 선택 패널 + 교체 이펙트 | 오른쪽 부착 패널, 메뉴 out 180° → 첫 버튼 `스캔` 교체 → in 0° + overshoot + flash(타임라인은 A 보고서 §7.2) | FD-116 |
| FE8-f1 스캔 세션 컨트롤러 추출 (동작 보존) | `_ScanPageState`의 세션·이벤트 커서·후보·최근·companion·dock 호출을 `ui/scan/scan_session_controller.dart`로, 학생 검토 순수 로직을 `ui/scan/scan_student_review_logic.dart`로 추출. AppShell이 컨트롤러를 소유. 동결 창에서만 | — (`scan_page_test` 회귀 0) |
| FE8-f2 머리글 진행·토스트 | 연결 칩 자리 우선순위(백엔드 끊김 > 스캔 진행·일시정지 > 게임 창 연결, FD-148), 탭 `스캔` 점, 완료 토스트 | FE8-f1 |
| FE8-f3 홈 스캔 팝업 연결 | 홈 팝업 타일 → 컨트롤러로 시작(또는 스캔 탭 이동, FD-140), 전술대항전 타일은 전술대항전 탭 링크(FD-150), 선물 타일(FD-151) | FE8-f1, FE8-g1, FD-140, FD-151 |
| FE8-g1 스캔 탭 골격 + 고르기 | 3섹션 `ScanTabPage`, S1 준비 상태·최근 스캔·게임 창 다시 선택, S2 고르기(학생/아이템 상호 배타, 아이템 다중 선택, 종류별 마지막 스캔 막대 — FB-2 전에는 "—"), S3 시작 전 안내. 미연결이면 홈과 같은 창 선택 패널(FD-155) | FE8-f1, FD-140, FD-151 |
| FE8-g2 학생 진행 (백그라운드) | 진행 화면(진행 수치·지금 읽는 학생·KPI·방금 읽은 학생), 학생 전체 스캔의 `dockBeside` 호출 제거, 다른 탭 이동 후에도 진행 유지. 일시정지 버튼은 FB-10 전까지 숨김 | FE8-f1, FE8-f2 + **FB-10 형식 고정 선언**(스캐너 오케스트레이터 로그, 2026-10-06 추가) |
| FE8-g3 아이템 진행 창 (포그라운드) | 아이템 시작 시 dock, `ScanCompanionDock` 재작성(진행/일시정지/완료), 여러 종류 큐(FD-143), 완료 → 복원 + 결과 검토. 동결 창에서만 | FE8-f1, FD-141 + **FB-10 형식 고정 선언**(스캐너 오케스트레이터 로그, 2026-10-06 추가) |
| FE8-g4 학생 결과 검토 | 새 `ScanStudentReviewBoard`: 분류(전체/확인 필요/바뀐 학생/새 학생/그대로), 계산 일치 일괄 적용(순차 commit, FD-144), S3 학생 상세 인디케이터 + 이전값 주석 + 폴백 카드(crop은 FB-10 뒤). 기존 workspace는 마운트 해제만 | FE8-f1, FE3-a~b + **FB-10 형식 고정 선언**(스캐너 오케스트레이터 로그, 2026-10-06 추가) |
| FE8-g5 아이템 결과 검토 | 새 `ScanItemReviewBoard`: 칸별 승인, 읽지 못한 칸 빗금, 확인 필요 칸 제외 부분 적용, S3 검사기. 미식별 칸은 기존 `ScanInventoryIdentityReview` 마운트. 끝나면 FE6-a의 `_CandidatePanel` 제거와 `_handoffCandidate` 인벤토리·학생 분기 제거 | FE8-f1, FE2-d, FD-146 + **FB-10 형식 고정 선언**(스캐너 오케스트레이터 로그, 2026-10-06 추가) |

### FB-4 ~ FB-11 — 나머지 백엔드

| slice | 내용 | 선행 |
|---|---|---|
| FB-4 | `scanner.target.list`에 창 크기·게임 판별 | FD-116 |
| FB-5 | 학생 카탈로그에 폼 목록·폼 초상 경로(사용자 설치본 추출 대상 확장 포함) | — 완료 2026-10-07 `a3692424`(폼 2개 이상 학생만 선택 필드 `forms`, 단일 폼은 그대로) |
| FB-6 | 전술 v2 기록·족보 쓰기(빈칸·슬롯 출처·상대 identity 보존), 시도 횟수, 족보 이름, `MockAppService` v2 구현 | FD-127, FD-128 |
| FB-7 | 엑셀 가져오기 해석 preview/commit(Python, 파일 지문 확인, 처리 규칙 저장) | FD-128 |
| FB-8 | 계획 문서 v2 또는 authoring 메타(교차 선행·나중에 칸·학생 순서) | FD-068 — **설계 승인 2026-10-09**(status-backend "FB-8 읽기 전용 설계 조사"): 문서 v2 유지 + 레코드 옆 `authoring` v1(6키, 나중에 단계 전체 보관, 안 A), 같은 학생 체인 = 배치 prefix + 나중에 suffix, 자동+직접 선행 전체 DAG·앞 칸 금지·같은 칸 배열 순서는 백엔드가 검증만, optional 의미(create/replace 누락 = 기본값, save/update 누락 = 보존 또는 authoring_required), 옛 fingerprint 호환, FB-1c 빈 활성 예외를 "문서·authoring 모두 빌 때만"으로 확장. 분할: **FB-8a** 활성 계획(DTO·validator·plan.get/save/replace·legacy goals.save 손실 방지·archive 확장), **FB-8b** 시나리오(create/get/update/duplicate·compare 전달). FE4-f 전에 둘 다 — FB-8b **완료 2026-10-09**: 커밋 `9aab5453`(Python 955). FB-8a **완료 2026-10-09**: 커밋 `4accf46c`(21파일, Python 944 중 943 통과 + 스키마 목록 테스트 1건은 오케스트레이터가 기대 집합에 새 스키마 이름을 더한 뒤 모듈 재실행 통과) |
| FB-9 | 계산 응답 보강(페이즈 진입/종료 잔량 의미 확정, 다중 비교) — FE5-d/FE5-e에서 필요가 확인될 때만 | — |
| FB-10 | 스캐너 프로토콜 추가 — **스캐너 워크플로가 구현**(additive): `scanner.session.pause/resume`·`paused` 이벤트(D21 개정, FD-142), 학생 폴백 필드 crop·역산값(FD-145), 인벤토리 entry별 승인·부분 commit·`needs_review` 영속 표시(FD-146), 진행 중 후보·feedback 스트리밍(FD-156), 정답 샘플 수, **크레딧·엘리그마 보유량 스캔**(FD-096 (c): 새 인식 대상, 스캔 탭 고르기에 종류로 추가). 이 워크플로는 요청서를 스캐너 오케스트레이터 로그에 남기고 프론트는 필드가 오면 그린다 | FD-142·FD-146·FD-096 확정(2026-10-06) |
| FB-11 | 학생 성장 계산 + 인연 선물: 단일 학생 계산 메서드(totals + 범주별 크레딧 + 재화 행 + 인연 블록, FD-162), 인연 랭크별 누적 경험치 표·쓰다듬기 상수 메타데이터, 선물 카탈로그·선호 배수로 선물 3안 계산(FD-163) | FD-162, FD-163 — a(계산 메서드 `planning.student.calculate`, 9범주 크레딧)와 b(인연 선물)로 나눔. b는 자료 선행: `FavorLevelExcel`·`CafeInteractionExcel` 실제 행과 쓰다듬기 횟수 근거가 필요하다(저장소에 없음, 2026-10-08 조사). 공용 클라이언트 자료 저장소를 맡은 택틱 오케스트레이터에게 요청했다 — a **완료 2026-10-08**: 커밋 `facdd1d3`(Python 847 통과). b는 택틱 W4 자료 도착(커밋 `9d14b2b5`) 후 ExpType 해석 확정(택틱 W4b) 대기 — b **완료 2026-10-08**: 커밋 `7d0af068`(Python 881 통과, `student_bond.py`·`planning-student-bond-v1`, 자료 스냅샷 `core/student_bond_data.py`) |
| FB-12 | 계획 계산 버그 2건(FE3-f1 발견, 2026-10-07): ① `planning_calc._calculate_star_cost`가 `record.star`를 읽어 wire의 `student_star`가 무시되고 성급 비용이 늘 ★0부터 계산됨 ② `planning_document._advance`가 장비 티어를 `"Tier<n>"`으로 이월하는데 `_parse_tier_number`는 `T<n>`만 읽어 2단계 이상 장비 비용이 T0부터 계산됨. 계획 탭·계산기 공통 | FE3-f2 전 단독 slice — **완료 2026-10-07**: 커밋 `50dbed6c`(Python 836건 통과, 기존 기대값 변화 0, 새 테스트 9건) |
| FB-13 | 학생 catalog 항목에 `has_favorite_item: bool`(KR 서버 애장품 제공 여부, `student_meta.favorite_item_enabled`). 계약·Python·Dart DTO·mock·자산 재생성·process 검증 한 slice. 계산기 애장품 행 폴백 해소용(FE3-f2a 발견) | FB-1과 독립, FE3-f2b의 golden 갱신 전에 커밋 — **완료 2026-10-08**: 커밋 `fa15e87c`(13파일) |
| FB-14 | 단계 프리셋·내 그룹 저장(FD-074 (b)): 프로필별 저장 묶음, 자체 collection revision(활성 계획 저장과 충돌하지 않게), 전체 교체 저장 + idempotency. 단계 프리셋은 이름 + 단계(이름, 19키 nullable 목표), 내 그룹은 이름 + 학생 ID 목록. 필터 프리셋은 범위 밖 | FD-074, FE4-b·FE4-c 연결은 프론트 — **완료 2026-10-09**: 커밋 `780705ff`(Python 923 통과) |

**스캐너 변동 대응(2026-10-06).** 스캐너 워크플로가 그리드 스캔 방식 개선 실험을 진행 중이라 FB-10의 응답 형식이 바뀔 수 있다.
프론트는 인식 방식이 아니라 프로토콜 형식에만 기대고, FB-10 필드가 오기 전에는 해당 표시를 숨기거나 "스캔 없음" 빗금으로 그린다
(일시정지는 FD-142에 따라 FB-10 전까지 취소로 동작). 칸별 승인·부분 적용·`needs_review`·진행 중 스트리밍의 형식에 기대는
FE8-g2~g5는 스캐너 워크플로가 FB-10 형식 고정을 스캐너 오케스트레이터 로그에 선언한 뒤에만 착수한다. FE8-g1(골격·고르기)과
FE8-f1~f3은 이 조건 없이 진행한다. 형식이 요청서와 다르게 고정되면 오케스트레이터가 FD·FE8-g 범위를 다시 맞춘다.

### FE9 — 전술대항전 (Lane C)

| slice | 범위 | 선행 |
|---|---|---|
| FE9-a 기록 화면 v1 이식 | 4섹션 배치, 목록·필터·작성·저장·복제. 기존 `_reload/_mutation` 재사용, `_DeckEditor`·AlertDialog 폐기, 하위 화면 전환 UI | FD-126 |
| FE9-b v2 데이터 계층 | `TacticalEvidenceService` 소비, 버려지던 wire 필드 Dart DTO 확장, mock v2 | FB-6, FD-128 |
| FE9-c 로비 스캔 섹션 | 스캔 → 후보 → `commitTacticalLobby` → 카드 선택 → 자동 채움 → 저장 시 링크. `app_shell._handoffCandidate` 인계 수정 | FD-127 |
| FE9-d 시그니처 족보 패널 | stats/recommend/freshness, 드래그로 공격 덱 복사 | FD-127 |
| FE9-e 분석 + 전체 보기 | Analysis S1~S3, 족보 전체 보기 팝업 | FD-126, FD-127 |
| FE9-f 엑셀 가져오기 | 파일 선택 → preview → 승인 모달(열 연결, 모르는 문자열 처리, 미리보기) → commit | FB-7 |
| FE9-g 슬롯 통계 | 내 기록 기반 부분만. 모집단 통계는 데이터원 결정 전 빈 상태 | FD-126, FD-127 |

### FE10 — 마감

- 택틱 탭 셸 규칙 조율: 9번째 탭과 선반 폭(760 → 860, 택틱 시안). 택틱 워크플로 T5와 함께 정한다.
- 대장의 `열림` 0건 확인, 충돌 문서 갱신 누락 점검(대장 "갱신" 근거 칸 전수), 죽은 코드(옛 Section 5, 범위 카드, `_DeckEditor`, 런타임 사용처 없는 `SectionTemplateSurface`·`AttachedSectionTemplateSurface`(FD-174) 등) 제거.
- 전체 회귀 + Windows Release + 사용자 최종 둘러보기(artboard 지도 57장 전수).
- `frontend-section-direction-and-user-flows.md`의 탭별 "사용자 검수 포인트"를 결정문으로 바꾼다(그 문서 §13 규칙). [@section-direction]

## 세션 운영 규칙

1. 세션 시작 시 읽는 순서: `AGENTS.md` → `README.md` → 이 문서 → `frontend-redesign-status.md` → 결정 대장의 해당 절 → 해당 그룹 조사 보고서 → artboard 지도의 해당 행.
   시안 사본은 `dc_outline.py`로 필요한 artboard만 본다.
2. 한 세션은 한 slice다. slice가 크면 status에 sub-slice를 먼저 쪼개 적고 하나만 한다.
3. 착수 전 status에 "진행 중: <slice>, 시작 커밋 SHA"를 적는다. 종료 시 실행 명령·결과 수치·처리한 `워커 재량` FD·미검증 항목·검수표·다음 행동을 적는다.
4. 대장의 막힘 요약에서 해당 slice를 막는 `열림` FD가 있으면 시작하지 않고 보고한다. 이 문서나 대장에 권장안이 있는 `워커 재량` 항목은 질문 없이 권장안으로 진행한다.
5. 동작 보존 slice에서 golden diff가 생기면 멈추고 status에 사유를 적은 뒤 보고한다. 임의로 golden을 덮지 않는다.
6. **status 문서는 워커만 쓴다**(첫 워커가 FE1 시작 때 만든다). 오케스트레이터의 결정·검토는 `frontend-redesign-orchestrator-log.md`에 append 한다. [@orchestrator-log]
7. 다른 slice의 문제를 발견하면 status "발견 사항"에 적기만 하고 고치지 않는다.

## 세션 시작 프롬프트 템플릿

```
BA Planner v7 프론트 개편(시안 구현) 작업이다. 다음 순서로 읽어라:
AGENTS.md → README.md → almanac/workflows/frontend-redesign-workflow.md
→ almanac/workflows/frontend-redesign-status.md(없으면 FE1 시작 때 만든다)
→ docs/frontend-redesign/decision-register.md의 <절>과 "slice별 막힘 요약"
→ docs/frontend-redesign/survey/<그룹 보고서>
→ docs/frontend-redesign/artboard-map.md의 <slice> 행.

이번 세션의 범위는 <slice ID — 제목>이다. 워크플로의 해당 slice 항목과 불변식만 수행한다.
시안은 docs/frontend-redesign/prototype/2026-10-05/ 사본을 tools/dc_outline.py로 읽는다(원문 통째 읽기 금지).
막힘 요약에서 이 slice를 막는 '열림' FD가 있으면 시작하지 말고 보고하라. '워커 재량' FD는 권장안대로 처리하고 status에 ID로 남겨라.
시작 전에 status에 진행 중 표시와 시작 SHA를 적고, 고칠 기존 파일마다 사본을 debug/frontend_<slice>/pre/<경로>에 둔다.
종료 시 debug/frontend_<slice>/commit.json(slice, message, modified, added, status)을 쓰고,
status에 실행 명령·결과·미검증 항목·검수표·다음 행동과 사용자 실행 명령
(fe_gate.ps1 → fe_commit.ps1 -Slice <slice> -DryRun → fe_commit.ps1 -Slice <slice>)을 적어라.
flutter·python이 이 환경에서 돌지 않으면 통과를 주장하지 마라. 직접 커밋하지 않는다.
```

## 재개 지점

- 2026-10-05: FE0-1~FE0-3 완료(오케스트레이터). 체크포인트 C 커밋 대기(FD-004). 다음 행동: C 커밋 확인 → FE1-a.
  FE3-d 착수 전에 FD-074·FD-104, FE4-a 전에 FD-082 답이 필요하다.
- 2026-10-06: 시안 추가 반영(오케스트레이터). 스캔 탭 6장으로 FD-120 확정(스캔 탭 = 고르기·진행·결과 검토), FE8-f/g를 f1~f3·g1~g5로 재편,
  성장 계산기를 FE3-f/g·FE4-g로 추가, FB-10(스캐너 워크플로 소관)·FB-11 신설. 열림 23건. 계산기 착수 전 FD-160·FD-166,
  스캔 탭 고르기 전 FD-140·FD-151이 필요하다.

- 2026-10-06: 사용자 승인 범위의 C 소스 커밋 `2156685ac63a852021e3dc01093185f78d97df49` 및 모든 실제 gate를 인수했다. FD-004 대기 해제, 다음 행동 FE1-a. 인계: `docs/migration/scanner-consolidation/checkpoint-c-handoff-2026-10-06.md`. 이 문서의 기존 미추적 이력은 C 커밋에 포함하지 않았다.
- 2026-10-06(저녁): 열림 23건 사용자 결정 — FD-166 (c) 계산기 목표 13행(애장품 포함), FD-096 (c) 크레딧·엘리그마 스캔 대상 추가(FB-10 요청에 포함), 나머지 21건 권장안. 열림 0건. 다음 행동 FE1-a.
- 2026-10-06(밤): FE1-a 워커 종료(코드 15파일 + 토큰 테스트, gate 미실행). 오케스트레이터 검토: 값 동일 교체 확인, `theme.dart`·`app_shell.dart`·`plan_section_layout.dart`에 기존 미커밋 변경이 있어 index 전용 패치와 커밋 도우미를 `debug/frontend_fe1a_commit_20261006/`에 만들었다. golden 기준선이 없어 FE1-g(기준선 + fe_gate)를 FE1-b 앞에 넣었다. 다음 행동: 사용자 커밋 도우미 실행 → FE1-g.
- 2026-10-06(밤 2): FE1-g 완료(golden 17장, fe_gate GREEN `20261006_222432`). 검증 명령을 `fe_gate.ps1`로 바꿨다(AGENTS.md, frontend/README.md; 루트 README.md는 C 이전 미커밋 변경이 있어 그 정리 때 같이 고친다). FE1-a·FE1-g 코드와 개편 문서는 아직 미커밋 — `commit-fe1a.ps1 -CommitRedesignDocs -IncludeFE1g -GateSummary …`로 FE1-b 전에 커밋한다. 다음 행동: FE1-b.
- 2026-10-06(밤 3): FE1-g `1ac37eeb`, 개편 문서 `180f5551`, FE0-base `36702c28`(기존 미커밋 타이포·계획 자원 아이콘·시나리오 비교 작업을 원래 내용대로, 사용자 승인), FE1-a `54ed8086`, FE1-b `d5f87b7b`(gate `20261006_231705` GREEN, 419 + golden 17) 커밋. push 안 함. `fe_commit.ps1`을 3-way 병합 + snapshot/optional_added/post_dir/inspect, ASCII 전용으로 개정. 다음 행동: FE1-c SectionSurface(시각 변경, golden 갱신).
- 2026-10-06(밤 4): FE1-c `99583757`(공용 `SectionSurface`, golden 6장 갱신). 워크플로 문서 커밋 `b91c30ff`. FE1 완료. FD-174(섹션 선택 표시 유지) 확정. 다음 행동: FE2-a 행·스크롤(동작 보존, golden diff 0).
- 2026-10-06(밤 5): 사용자 승인으로 스캐너 변동 대응 2건 반영. FB-2의 `scan_kind`·`inventory_scan_profile`은 불투명 문자열로 저장하고, FE8-g2~g5는 FB-10 형식 고정 선언 뒤에만 착수한다. 스캐너 실험 쪽 응답 형식 변경 여부는 아직 미정이다.
- 2026-10-07(오전): FE1-c `99583757`, FE2-a, FE2-b `859c554a`, FE2-c `bb1e3478` 커밋. gate는 프로세스 테스트 분리판(`fe_gate.ps1`, 문서 커밋 `fd791947`). 다음 행동: FE2-d 이미지·차트 원자.
- 2026-10-07(낮): FE2-d `1f65b64a`. FE2(공통 위젯 키트·UI Kit 갤러리) 완료. 사용자 갤러리 시각 검수는 남아 있다(지적 사항은 해당 위젯을 처음 쓰는 화면 slice에서 고친다). 다음 행동: FE3-a DE 카드·그리드(시각 변경, golden 갱신).
- 2026-10-07(낮 2): FE3-a `620a98ee`(DE 카드·그리드, golden 3장 갱신), 문서 `fdf0097e`. 다음 행동: FE3-b 인연 B 게이지 + 학생 golden 장면 보강.
- 2026-10-07(낮 3): FE3-b `809d903b`. 다음 행동: FE3-c S4 확장 + 배지 글꼴(golden Ahem 사각형) + 학생 fixture 두 줄.
- 2026-10-07(오후): FE3-c `b7bbfcce`. 결정: 최근 본 학생은 계정(프로필) 전환 때 비운다(FE3-d에서 연결). 다음 행동: FE3-d 필터 모달.
- 2026-10-07(저녁): FE3-d1 `ddc251eb`, FE3-d2 `0890de7a`. 다음 행동: FE3-e 다중 폼 교대(+FB-5 catalog 폼 확장).
- 2026-10-07(밤): FE3-e `a3692424`(+FB-5), 문서 `8a6482e7`. FE3-f는 f1(계산기 상태·계산 연결, 화면 변화 없음)과 f2(화면 모드·4섹션 연결, golden 장면 추가)로 나눈다. 크레딧 내역 막대는 FB-11 전까지 숨기고 FD-162 (a) 임시 문서 계산으로 그린다. 다음 행동: FE3-f1.
- 2026-10-07(밤 2): FE3-f1 `7ec07589`, 문서 `bcde9559`. 워커가 백엔드 계획 계산 버그 2건을 발견했고 오케스트레이터가 코드로 확인했다 → FB-12 신설, FE3-f2 전에 단독 slice로 고친다. 다음 행동: FB-12 → FE3-f2.
- 2026-10-07(밤 3): FB-12 `50dbed6c`, 문서 `f2cf4fb8`. 사용자 승인으로 Lane A를 프론트·백엔드 워커 두 명으로 나눴다(실행 순서 절 "Lane A 앞뒤 병렬"). 다음 행동: 프론트 FE3-f2, 백엔드 FB-11a.
- 2026-10-08(새벽): FE3-f2를 f2a/f2b로 분할. gate `20261008_022827` RED(아이콘 경로를 지어낸 fixture) → 프론트 수정 대기. FB-11a 코드 승인, 커밋은 gate GREEN 뒤. 사용자 결정: FE3-g는 데이터 먼저(인연 경험치·쓰다듬기 표를 택틱 쪽 자료 저장소에 요청). 다음 행동: gate ① 재실행 → golden ② → fb11a·fe3f2a 커밋 → 프론트 f2b, 백엔드 FB-1(+`has_favorite_item`).
- 2026-10-08(아침): FE3-f2a `3e7272e2`, FB-11a `facdd1d3`(Python 847), 문서 `2bcdcbd9`. 택틱 W4가 인연·카페 자료를 넣었다(ExpType 해석은 W4b 대기). 시각화 도구(애니메이션 효과 프레임 스펙트럼)는 택틱 워크플로로 넘겼다. 다음 행동: 프론트 FE3-f2b, 백엔드 FB-13 → FB-1a.
- 2026-10-08(낮): FE3-f2b `576bd568`, 문서 `c2d5f413`(사용자 push). FB-13 커밋 직전. 택틱 W4b가 인연 ExpType을 확정해 FB-11b 자료 조건이 풀렸다. 새 메타데이터 관리자 워크플로가 "첫 실행 추출 = 프론트 레인"을 정했다(계약 확정 뒤 편성). 다음 행동: 백엔드 FB-1a, 프론트 FE4-a(또는 FB-11b 뒤 FE3-g).
- 2026-10-08(오후): FB-13 `fa15e87c`. 배정: 백엔드 FB-1a(문서 v2, 이 slice 동안 `lib/ui/models/planning_models.dart`의 문서 DTO는 백엔드 워커 소유), 프론트 FE4-a(흐름 골격, `planning_models.dart` 수정 금지). FB-11b는 FB-1a 뒤.
- 2026-10-08(저녁): FE4-a `a18897a1`, 문서 `eea7f113`. FB-1a는 Python 전체·커밋 대기(gate `20261008_164059` GREEN에 포함). 커밋 뒤 `planning_models.dart` 소유는 프론트로 돌아온다. 다음 행동: 프론트 FE4-b(1단계 학생 고르기 + 초안을 문서 v2로 전환), 백엔드 FB-11b(인연 선물 계산) → FB-1b.
- 2026-10-08(밤): FB-1a `682b2a7b`(17파일, Python 873 통과). `planning_models.dart` 소유가 프론트로 돌아왔다. 프론트 FE4-b, 백엔드 FB-11b 착수.
- 2026-10-08(밤 2): FE4-b `2a5a7655`. FB-11b 코드 완료(커밋 대기). 다음 행동: 프론트 FE4-c(2단계 목표 정하기) → FE4-d → FE3-g, 백엔드 FB-1b(활성 계획 저장·이관).
- 2026-10-09(새벽): FB-11b `7d0af068`(10-08 21:58), 문서 `e9baa249`. FB-1b `11426131`(Python 898), fe1brev `86589da6`, FE4-c `4a831177`, 문서 `b4bb199a`. 다음 행동: 프론트 FE4-d1(3단계 칸 보드) → FE4-d2(Many) → FE4-h(저장 문서 읽기) → FE3-g, 백엔드 FB-1c(replace). FE4-e는 FB-1c·FE4-h 뒤.
- 2026-10-09(낮): FE4-d1·FB-1c gate `20261009_124241` GREEN, `plan-flow-step3` 승인, FB-1c Python 912 통과. 커밋 대기(fb1c → fe4d1 → 문서). 다음 행동: 프론트 FE4-d2(Many + 화살표가 칸 머리 칩을 피하게), 백엔드 FB-14(단계 프리셋·내 그룹 저장, FD-074 (b)).
- 2026-10-09(오후): FB-14 `780705ff`, FE4-d2 `7cd9592e`, 문서 `a79f5d1d`. FE4-h gate `20261009_171109` GREEN(커밋 대기). FB-8 설계 승인·a/b 분할. 다음 행동: 프론트 FE3-g(인연 선물 타일) → FE4-e(4단계 저장), 백엔드 FB-8a → FB-8b. FE4-f는 FB-8a·b 뒤.
- 2026-10-09(저녁): FE4-h `8beab94e`, 문서 `611ec7a1`. 프론트 FE3-g·백엔드 FB-8a 착수(프롬프트 전달). 오케스트레이터 세션 교대 — 인계 프롬프트는 `debug/frontend_redesign_handoff/handoff-prompt-20261009.md`. 다음 행동: 두 워커 멈춤 → gate ① → `students-calculator` 차이·새 팝오버 장면 검토 → ② → FB-8a Python 전체 → fb8a → fe3g → 문서.
- 2026-10-09(밤): FE3-g `6eb04542`, FB-8a `4accf46c`(Python 943 + 수정한 스키마 목록 테스트 모듈 재실행 통과). 오케스트레이터 세션 교대 후 첫 검토. FE4-i(프리셋·내 그룹 저장 연결) 신설. 다음 행동: 프론트 FE4-e(4단계 저장) → FE4-i → FE4-f, 백엔드 FB-8b(시나리오 authoring). FE4-f는 FB-8b 뒤.
- 2026-10-09(밤 2): FE4-e·FB-8b gate ② `20261009_215639` GREEN(①에서 두 레인 교차 컴파일 오류를 오케스트레이터가 고침), FB-8b Python 955. 커밋 순서 fb8b → fe4e → 문서. 다음 행동: 프론트 FE4-i(+golden 비교 대역 기준 맞추기) → FE4-f, 백엔드 FB-2 읽기 전용 설계 조사(앞당김).
- 2026-10-09(밤 3): FB-8b `9aab5453`, FE4-e `3af5246c`, 문서 `df547db7`. FE4-i gate ② `20261009_231201` GREEN(커밋 대기). FB-2 설계 승인·a/b/c/d 분할, 스캐너·전술 요청은 tactic 로그 23:25. 다음 행동: fe4i → 문서 커밋, 프론트 FE4-f(교차 선행·나중에 칸), 백엔드 FB-2a.
