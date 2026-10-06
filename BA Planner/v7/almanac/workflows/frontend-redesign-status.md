---
title: "Frontend Redesign Status"
summary: "프론트 개편(시안 구현) 워크플로의 워커 진행 상태입니다. slice별 시작 SHA, 실행 명령과 결과, 처리한 워커 재량 FD, 미검증 항목, 다음 행동을 기록합니다."
topics: [workflow, design]
sources:
  - id: workflow
    type: file
    path: almanac/workflows/frontend-redesign-workflow.md
  - id: register
    type: file
    path: docs/frontend-redesign/decision-register.md
  - id: survey-shared
    type: file
    path: docs/frontend-redesign/survey/H-shared-elements.md
---

# Frontend Redesign — 워커 상태

규칙: 이 파일은 워커만 쓴다. 오케스트레이터 결정은 `frontend-redesign-orchestrator-log.md`에 있다. 실행 범위와 gate는 워크플로를 따른다. [@workflow]

## 현재 상태

**FE1-b DiagonalGeometry(동작 보존): 코드·단위 테스트 작성 완료, gate 미실행(사용자 PC 실행 대기).** 시작 커밋 `180f5551cc4d63621612c9b454fc2ede32159d1a`. 커밋하지 않았다. 자세한 내용은 아래 "FE1-b" 절.

FE1-g는 커밋됐다(`8e95d946` golden PNG, `1ac37eeb` 코드; 아래 "FE1-g 커밋 기록"). 아래 FE1-g·FE1-a 문단은 당시 기록이다.

**FE1-g golden 기준선 + 게이트 스크립트: golden 17장 생성·비교 통과(사용자 PC). gate는 RED였다(Python E2E 4건 시간 초과, almanac 인용 1건). 수정 후 재실행 대기.** 시작 커밋 `691e5213eb4b88ac1a6ce611e79b694ec247570c`(FE1-a 변경은 아직 작업트리에만 있다). lib/는 바꾸지 않았다. 커밋하지 않았다. 자세한 내용은 아래 "FE1-g" 절.

**FE1-a 토큰(동작 보존): 코드 변경 완료, 자동 gate 미실행(사용자 실행 대기).** 시작 커밋 `691e5213eb4b88ac1a6ce611e79b694ec247570c` (브랜치 `scanner-consolidation`, 2026-10-06). 커밋하지 않았다.

이 세션 환경에서는 Flutter를 실행할 수 없었으므로 analyze·test 통과를 주장하지 않는다(아래 "미검증"). 사용자 실행 요청:

```powershell
cd frontend
flutter analyze
flutter test
```

기대값: analyze 이슈 0, test **414/414**(기존 411 + 이번에 추가한 `test/theme_tokens_test.dart` 3건). 결과를 이 문서 "gate 결과" 절에 붙인다.

## FE1-a 착수 기록 (2026-10-06)

- 범위: `AppColors` 확장, `AppMotion`, `AppRadii`, 컨트롤 높이 토큰, `AppType` 개정(FD-008, FD-010). 이미 하드코딩된 같은 값을 토큰으로 바꾸기만 한다. 색·크기·모션 값은 바꾸지 않는다.
- 범위 밖: FE1-b(80° 기하 공용화), FE1-c(섹션 표면), FE1-d(`fe_gate.ps1`).
- 막힘: 대장 막힘 요약에서 FE1을 막는 열림 FD 없음. [@register]
- 작업트리: C 이전부터 남은 미커밋 변경을 stage·revert·정리하지 않고 그대로 둔 채 현재 파일을 기준으로 수정한다.

## FE1-a 종료 기록 (2026-10-06)

### 추가한 토큰 (`frontend/lib/app/theme.dart`)

| 묶음 | 내용 |
|---|---|
| `AppColors` | `accent #f2b3ef`, `accentText #f7c9f4`, `onAccent #2a1330`, `scrollThumb #e5a0ea`, `textSecondary #c3cfdb`, `textDim #6f8397`, `popover #0d151f`, `rowSurface #101823`(알파는 사용처에서), `indicatorSurface #203243`, `scrim #060a10`(알파 프리셋은 FE2-c), `starDisplay #f3c96b`, `starFilter #e8c15a`, 타입 5색 `typeExplosive #920008`·`typePiercing #bd8901`·`typeMystic #226f9b`·`typeSonic #9945a8`·`typeComposite #7a8ea3`. 클래스 주석에 색 역할 규칙(선택·강조 = 핑크, 탐색 = 파랑, FD-005) |
| `AppTone`/`AppTones` | 칩 6색 tone 쌍: info(#71c7f4@.16 / #a8e0ff), pink(#f2b3ef@.2 / #f7c9f4), ok(#58d6a7@.16 / #7fe3bd), warn(#ffc66d@.16 / #ffd08a), danger(#ff7e8a@.16 / #ffa0a8), gray(#9eb0c2@.14 / #c3cfdb). 값은 시안 `.chip` CSS |
| `AppMotion` | `section` 360ms, `sectionCurve` easeInOutCubic, `entranceCurve` easeOutCubic, `shell` 460ms, `tabBodyPull/Exit/Enter/Settle` 120/300/360/190ms + `tabBody` 970ms, `header` 220ms, `tab` 180ms |
| `AppRadii` | section 14, control 10, tab 8, tooltip 8, row 8, rowLarge 12, chip 7, skew 5, toggle 11 |
| `AppControlHeights` | tab 44, chip 24, segmented 36, toggleChip 30, tonalButton 40, toggle 22, stepper 24, info 24 |
| `AppType` 개정 | 시안 전용 크기 토큰 18종(8, 8.5, 9, 9.5, 10.5, 11.5, 12.5, 13.5, 16.5, 17, 19, 21, 22, 25.2, 26, 30, 34, 43.2). 경기천년제목 "20px 미만 금지" 주석을 "값·제목 서체, 크기 제한 없음"으로 개정(FD-008). 800/900 처리 규칙 주석(FD-009) |

### 하드코딩 → 토큰 교체 (값 동일)

| 대상 | 교체 수 | 파일 |
|---|---|---|
| 핑크 `#f2b3ef`(알파 변형 2개 포함) | 14곳 → 0 (gate의 "하드코딩 핑크 6곳" = 6파일 전부) | `app/theme.dart`(`planPhaseNumber`), `developer_tools_main.dart`, `diagonal_flow_indicator.dart`, `diagonal_media_list_item.dart`(`diagonalMediaHighlightColor`), `plan_phase_editor.dart`(6), `plan_section_layout.dart`(4) |
| 스크롤 썸 `#e5a0ea` | 5곳 → 0 | `plan_element_builder.dart`(3), `plan_section_layout.dart`, `student_section_layout.dart` |
| 인디케이터 `#203243` | 4곳 → 0 | `plan_element_builder.dart`, `student_section_layout.dart`(3) |
| 타입 4색 | 4곳 → 0 | `student_section_layout.dart` `studentAttackTypeColor` |
| 성작 노랑 `#f3c96b` | 2곳 → 0 | `diagonal_media_list_item.dart`, `student_section_layout.dart` |
| 섹션 모션 360ms | 6벌 → 0 | `plan_phase_editor`, `student_section_layout`, `plan_element_builder`, `plan_student_selector`, `plan_preset_manager`, `plan_section_layout` |
| 섹션·셸 곡선 easeInOutCubic | 9곳 → 0 | 위 6파일 + `title_page.dart`, `account_section_cluster.dart` |
| 셸 460ms | 5곳 → 0 | `app_shell.dart`, `title_page.dart`, `account_section_cluster.dart`(3) |
| 탭 본문 120/300/360/970, 진입 곡선 | 5곳 → 0 | `animated_section_stack.dart` |
| 헤더 220ms·탭 180ms·탭 높이 44 | 3곳 | `app_shell.dart`(최소 diff 3줄) |
| 테마 반경 14/10/10/8 | 4곳 | `app/theme.dart` |

`phaseEditorButtonHoverColor`/`PressedColor`는 `const Color(0x33f2b3ef)`/`(0x4df2b3ef)` → `final … = AppColors.accent.withValues(alpha: 0x33 / 255)`(같은 값, const → final). 사용처는 non-const `InkWell` 3곳뿐이다. 공개 상수 이름은 모두 유지했다.

### 바꾼 파일 목록 (15)

- `frontend/lib/app/theme.dart`
- `frontend/lib/developer_tools_main.dart`
- `frontend/lib/ui/app_shell.dart`
- `frontend/lib/ui/pages/title_page.dart`
- `frontend/lib/ui/widgets/account_section_cluster.dart`
- `frontend/lib/ui/widgets/animated_section_stack.dart`(theme import 추가)
- `frontend/lib/ui/widgets/diagonal_flow_indicator.dart`(theme import 추가)
- `frontend/lib/ui/widgets/diagonal_media_list_item.dart`
- `frontend/lib/ui/widgets/plan_element_builder.dart`
- `frontend/lib/ui/widgets/plan_phase_editor.dart`
- `frontend/lib/ui/widgets/plan_preset_manager.dart`
- `frontend/lib/ui/widgets/plan_section_layout.dart`
- `frontend/lib/ui/widgets/plan_student_selector.dart`
- `frontend/lib/ui/widgets/student_section_layout.dart`
- `frontend/test/theme_tokens_test.dart`(신규: 토큰 값 = 기존 리터럴 값, 칩 tone, 모션·반경·높이 3건)
- 이 문서(신규)

파일별 줄바꿈(CRLF/LF)은 원래대로 보존했다. 소유권 규칙상 손대지 않은 파일: 택틱 세션 소유 전부, 스캐너 세션 소유(`scan_student_review_workspace.dart`, `scan_inventory_identity_review.dart`), 동결 창 대상(`scan_page.dart`, `scan_companion_dock.dart`). `app_section.dart`는 수정하지 않았다.

### 처리한 FD

| FD | 상태 | 처리 |
|---|---|---|
| FD-005 | 확정 | `accent`·`accentText`·`onAccent`·`scrollThumb` 신설, 핑크 하드코딩 6파일 교체, 색 역할 규칙을 `AppColors` 주석에 기록. 주 탭 선택은 파랑 유지 |
| FD-008 | 확정 | `AppType`·`AppFonts` 주석을 "값·제목 서체, 크기 제한 없음"으로 개정 |
| FD-009 | 워커 재량 | 권장안 (a): 새 코드의 800/900은 `bold`(700). 기존 `w800`/`w900` 75곳은 렌더 결과가 바뀔 수 있어(합성 굵게 여부) FE1-a에서 바꾸지 않았다. 규칙만 주석에 기록 |
| FD-010 | 워커 재량 | 권장안 (a): 시안 전용 크기 18종을 역할 토큰으로 추가. 기존 `fontSize:` 리터럴 154곳은 이번에 교체하지 않았다(아래 "남긴 것") |
| FD-011 | 워커 재량 | 권장안대로 `textSecondary`·`textDim`·`popover`·`rowSurface`·`indicatorSurface` 신설. 거의 흰 변형 3종은 코드에 사용처 0건이라 `text` 통합 규칙만 주석에 기록 |
| FD-012 | 워커 재량 | 권장안 (a): `starDisplay`·`starFilter` 두 토큰 |
| FD-017 | 워커 재량 | 권장안대로 `AppMotion`. 값·곡선 불변 |
| FD-024 | 워커 재량 | 권장안대로 타입 색을 theme로 추출, `typeComposite #7a8ea3` 추가(사용처 연결은 하지 않음, 발견 사항 2) |
| FD-007, FD-015, FD-016 | 워커 재량 | FE1-a에서는 해당 없음: FD-007은 FE1-c(표면), FD-016은 FE1-b(기하)에서 처리. FD-015는 권장안 (a) 절차 텍스처 유지라 변경 없음 |

### gate 결과

| 항목 | 결과 |
|---|---|
| `flutter analyze` | **미실행** — 사용자 실행 요청 |
| `flutter test` | **미실행** — 기대 414/414 |
| golden | **비교 대상 없음**: `frontend/test/goldens/`가 비어 있고 테스트에 `matchesGoldenFile`이 0건이다. 따라서 "golden diff 0"은 이 저장소에서 판정할 대상이 없다(발견 사항 1). 픽셀을 읽는 일반 테스트 3곳(`widget_test.dart` 2, `student_studio_layout_test.dart` 1)은 `flutter test`에 포함된다 |
| 값 불변 근거 | 교체한 모든 자리의 토큰 값이 원래 리터럴과 같다(diff 검토, 위 표). `theme_tokens_test.dart`가 토큰 값과 별칭 상수(`diagonalMediaHighlightColor`, `phaseEditor*Color`, 모션 상수 3개, `planPhaseNumber`)를 원래 리터럴과 비교한다. 기존 `planning_page_test`(`0xfff2b3ef`)·`student_studio_layout_test`(`0xff920008`) 단언도 그대로다 |
| `codealmanac validate`, `git diff --check` | 미실행 |

### 미검증 항목

- `flutter analyze`, `flutter test`, `codealmanac validate`, `git diff --check` 전부. 이 세션은 사용자 PC의 파일을 읽고 쓰기만 할 수 있었고 셸이 없었다. 클라우드 작업 공간에는 Flutter SDK를 설치할 수 없었다(storage.googleapis.com·GitHub·패키지 레지스트리 egress 차단). 그래서 Dart 컴파일·lint는 사람의 diff 검토로만 확인했다.
- 컴파일 위험이 있는 지점: theme import를 새로 넣은 2파일, `const` → `final`로 바꾼 `phaseEditorButtonHoverColor`/`PressedColor`(const 문맥 사용처 없음 확인), 새 `AppTone` 클래스(`@immutable`, const 생성자).
- 시각 검수: 동작 보존 slice라 검수표 없음. 값이 같으므로 화면 변화가 없어야 한다.

### 남긴 것 (의도적으로 바꾸지 않음)

- `fontSize:` 리터럴 154곳, `FontWeight.w800/w900` 75곳: 대부분 각 화면 slice가 재작성할 위젯 안에 있다. 토큰은 준비해 두었고 교체는 화면 slice에서 한다.
- 역할이 다른 180/220ms(`plan_element_builder` hover 4곳, `plan_section_layout` 2곳)는 탭·헤더 모션이 아니므로 그대로 두었다.
- `BATrianglePalette`의 알파 구운 값(`0x80e5a0ea`, `0x88e9b0ee`), `studentSortAccentColor #e9b0ee`, 학생 카드 선택 `#ff72b6`(3곳): 이번 토큰 목록 밖이다.
- 그림자색 `#050911` 3중 정의(`app_shell`, `diagonal_menu`, `lifted_path_shadow`): FE1-c 표면 slice 소관이다.

### 발견 사항 (오케스트레이터 판단 필요)

1. **Flutter golden 기준선이 없다.** 워크플로의 FE1-a/FE1-b "golden diff 0"과 FE1-c "golden 갱신 사유 기록"은 golden 파일을 전제하지만 `frontend/test/goldens/`는 비어 있다. 동작 보존 리팩터인 FE1-b(인라인 80° 계산 108곳 교체)는 값 비교만으로 보증하기 어렵다. FE1-b 착수 전에 현재 화면의 golden 기준선(최소: 홈·학생·계획·타이틀·계정 화면, 기준 viewport)을 만드는 작업을 FE1-d 앞이나 FE1-b 첫 단계로 넣을지 결정이 필요하다. Windows 폰트 렌더 차이 때문에 golden은 사용자 PC에서 생성·비교해야 한다.
2. **복합장갑 색 불일치.** 코드 `studentAttackTypeColor`/`studentDefenseTypeColor`는 `Composite`(그리고 분해 계열 공격)를 `#228b22` 녹색으로 그린다. 시안 W-Filter-Widgets의 복합장갑은 `#7a8ea3`이다. FE1-a는 값을 바꾸지 않았다. FE3-a(카드 속성 칩) 또는 FE3-d(타입 칩)에서 바꿀 것을 제안한다.
3. **테스트 수 변화.** 이번 slice가 토큰 테스트 3건을 추가해 기준선이 411 → 414가 된다.

### 다음 행동

1. 사용자: `cd frontend; flutter analyze; flutter test` 실행 → 결과 수치를 이 문서 "gate 결과"에 기록(analyze 이슈 0, 414/414 기대). 실패하면 출력 전문을 붙인다. 다음 세션이 같은 FE1-a 범위에서 수정한다.
2. 녹색이면 사용자 승인 하에 FE1-a 커밋(이 문서와 위 15파일만, 기존 미커밋 변경과 분리).
3. 다음 slice **FE1-b DiagonalGeometry(동작 보존)**: `tan80`·`cutDepth`·레일 x(y)·법선 inset·둥근 다각형 단일 API(FD-016)·행 오프셋 2모드, 인라인 108곳 교체, 기하 단위 테스트. 착수 전에 발견 사항 1(golden 기준선)의 오케스트레이터 결정을 받는다.

## FE1-g 착수 기록 (2026-10-06)

- 범위: golden 기준선 테스트(`frontend/test/goldens/`)와 `frontend/tool/fe_gate.ps1`. 앱 코드(`lib/`)는 바꾸지 않는다. golden PNG는 이 환경에서 만들지 않는다.
- 장면 선택 근거: H 보고서 §1(UI 요소 사전 블록 1~8의 코드 대응)과 §6.1(셸·표면·기하 요소의 Flutter 대응). [@survey-shared]
- 시작 커밋 `691e5213eb4b88ac1a6ce611e79b694ec247570c`(브랜치 `scanner-consolidation`). FE1-a 15파일은 아직 커밋되지 않은 작업트리 상태다(사용자 보고 2026-10-06 21:32: analyze·test 전부 통과). 따라서 이 기준선은 **FE1-a 적용 후 화면**을 고정한다. FE1-a는 값이 같은 토큰 교체라 화면은 FE1-a 이전과 같아야 한다.
- 작업트리: 기존 미커밋 변경은 건드리지 않았다. 고친 기존 파일은 `frontend/.gitignore` 하나이고, C 인계 `unrelated-changes.json` 목록에 없는 파일이다(기존 변경 없음).
- 막힘: 없음.

## FE1-g 종료 기록 (2026-10-06)

### 만든 파일

| 파일 | 내용 |
|---|---|
| `frontend/test/goldens/golden_harness.dart` | 공용 도구. viewport 2560×1392·DPR 1, `FontLoader`로 Pretendard 4굵기·GyeonggiTitle 적재(+FontManifest의 아이콘 글꼴), 대상 플랫폼 Windows(`TargetPlatformVariant.only`), `runAsync` 이미지 선디코드(`Image`·`AssetImageGrid`), 애니메이션 정착 후 `matchesGoldenFile('baseline/<장면>.png')`, 타이틀 학생 그리드 warmup 완료 대기, 시나리오 수정 시각 고정 mock(`GoldenMockAppService`) |
| `frontend/test/goldens/fe1g_baseline_golden_test.dart` | 장면 17개(아래 표). 모두 `MockAppService` fixture |
| `frontend/tool/fe_gate.ps1` | gate 스크립트(아래). UTF-8 BOM·CRLF(Windows PowerShell 5.1 호환) |
| `frontend/.gitignore` | `/test/goldens/failures/`(golden 비교 실패 시 생기는 차이 이미지) 무시 1줄 추가 |
| `frontend/dart_test.yaml` | `golden` 태그 선언(2026-10-06 gate 결과 반영 수정) |

golden PNG 경로: `frontend/test/goldens/baseline/<장면>.png` (17개, 사용자 PC에서 생성).

### 장면 목록 (17)

| # | 장면(PNG 이름) | 띄우는 방법 |
|---|---|---|
| 1 | `title` | `BAPlannerApp(showTitle: true)`, warmup 완료 대기 |
| 2 | `account-manager` | 1 → `title-settings` |
| 3 | `account-editor` | 2 → `account-edit` |
| 4 | `account-picker` | 3 → `account-change-portrait` |
| 5 | `home` | `BAPlannerApp`(앱 셸, 홈 탭) |
| 6 | `students-grid` | 5 → `top-tab-students` |
| 7 | `students-detail` | 6 → 그리드 첫 학생 선택 |
| 8 | `plan-bottleneck` | `PlanningPage`(기본 fixture, 병목 탭) |
| 9 | `plan-by-phase` | 8 → `plan-resource-tab-byPhase` |
| 10 | `plan-overall` | 8 → `plan-resource-tab-overall` |
| 11 | `plan-phase-editor` | 8 → `plan-phase-editor-launch` |
| 12 | `plan-student-selector` | 8 → `plan-student-selector-launch` |
| 13 | `plan-element-builder` | 프리셋 1개 → 학생 선택기에서 첫 학생 → 선택 확정 → 프리셋 적용 |
| 14 | `plan-preset-manager` | 프리셋 1개 → `plan-preset-manager-launch` |
| 15 | `plan-scenario-list` | 시나리오 1개 생성 + `loadRepositoryPlan: true` → `plan-scenario-list-launch` |
| 16 | `plan-scenario-compare` | 15와 같은 준비 → 비교 시작 → 활성 계획 + 시나리오 선택 → 확정 |
| 17 | `scan-student-review` | `ScanStudentReviewWorkspace` 단독(후보 2개: aru 확인 필요, hoshino 변경). 스캐너 세션 소유 위젯이라 그리기만 한다 |

계획·시나리오·스캔 장면은 앱 셸 없이 앱 테마(`BAPlannerTheme.dark()`)의 `Scaffold`에 띄운다(기존 `planning_page_test`와 같은 방식). 셸·헤더는 5~7번이 그린다.

### 파일 → 장면 대응표

`lib/`에서 `tan(80 …)` 인라인 계산이 있는 파일은 12개, 108곳이다(FE1-b 교체 대상과 같은 수). 각도를 인자로 받아 `tan(angleDegrees …)`로 계산하는 사선 위젯 3개도 함께 묶었다.

| 파일 | 인라인 `tan(80…)` | 그리는 장면 |
|---|---|---|
| `ui/widgets/student_section_layout.dart` | 33 | `students-grid`, `students-detail`, `plan-student-selector` |
| `ui/widgets/plan_section_layout.dart` | 20 | `plan-bottleneck`, `plan-by-phase`, `plan-overall`, `plan-scenario-list`, `plan-scenario-compare` |
| `ui/widgets/plan_element_builder.dart` | 17 | `plan-element-builder` |
| `ui/widgets/plan_phase_editor.dart` | 14 | `plan-phase-editor` |
| `ui/widgets/plan_preset_manager.dart` | 5 | `plan-preset-manager` |
| `ui/widgets/section_template_surface.dart` | 4 | `title`, `account-*`, 모든 `plan-*` |
| `ui/widgets/account_section_cluster.dart` | 3 | `account-manager`, `account-editor`, `account-picker` |
| `ui/widgets/diagonal_media_list_item.dart` | 3 | `plan-bottleneck`, `plan-phase-editor`, `scan-student-review` |
| `ui/widgets/plan_student_selector.dart` | 3 | `plan-student-selector`(+ `plan-element-builder` 진입 경로) |
| `ui/widgets/scan_student_review_workspace.dart` | 3 | `scan-student-review` |
| `ui/widgets/student_range_condition_section.dart` | 2 | `plan-student-selector`(`plan-range-condition-section`) |
| `ui/widgets/diagonal_flow_indicator.dart` | 1 | `plan-bottleneck`(페이즈 목록), `plan-element-builder` |
| `ui/widgets/diagonal_header.dart` | 0 (각도 인자 2) | `home`, `students-grid`, `students-detail` |
| `ui/widgets/diagonal_menu.dart` | 0 (각도 인자 1) | `home` |
| `ui/widgets/diagonal_section.dart` | 0 (각도 인자 1) | `scan-student-review` |

빠진 파일은 없다. 다만 대응은 **파일 단위**다. 파일 안의 모든 `tan(80…)` 줄이 이 장면들에서 실제로 실행되는지는 확인하지 못했다(실행 환경 없음). 특히 `section_template_surface.dart`의 4곳은 어느 함수가 어느 장면에서 쓰이는지 추적하지 않았다. FE1-b 워커는 교체 전에 해당 줄이 golden 장면에서 실행되는지 확인하고, 실행되지 않는 줄은 단위 테스트로 보강한다.
`section_template_surface.dart:1158`의 `tan(cornerAngle / 2)`는 80° 계산이 아니라 필렛 반각 계산이라 108곳에 넣지 않았다.

### fe_gate.ps1

차례: `flutter analyze` → (`-UpdateGoldens`면) `flutter test --update-goldens test/goldens` → `flutter test --exclude-tags golden`(golden 외 전체) → `flutter test test/goldens`(golden 비교) → `codealmanac validate`(v7) → `git diff --check -- .`(v7 범위). golden과 나머지를 나눠 차례로 돌리는 이유는 아래 "FE1-g gate 결과" 참고(2026-10-06 수정). 단계가 실패해도 나머지를 돌리고 `debug/frontend_gate/<yyyyMMdd_HHmmss>/`에 단계별 `*.log`, `goldens.sha256.txt`(golden PNG 해시 목록), `summary.txt`(결과 GREEN/RED, git HEAD, flutter 버전, 단계별 PASS/FAIL·exit·초·요약 줄, golden 수, 실패 이미지 수, golden 경로의 `git status`)를 쓴다. 모두 통과하면 종료 코드 0, 아니면 1. PATH에 명령이 없으면 그 단계를 실패(exit 9009)로 기록한다. 커밋·push·설치·작업트리 정리는 하지 않는다.
`-UpdateGoldens`로 만든 직후 golden 비교 단계가 같은 PNG와 다시 비교하므로, 첫 실행에서 재현성(두 번 그려도 같은지)까지 확인된다.

### 사용자 실행 명령

PowerShell에서 v7 폴더 기준으로 실행한다. FE1-a 커밋(오케스트레이터 커밋 도우미 `debug/frontend_fe1a_commit_20261006/commit-fe1a.ps1`)을 먼저 끝내 두는 것을 권한다. 기준선이 FE1-a 커밋 위의 상태가 된다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"

# 1) golden 첫 생성(17개) + 전체 gate
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens

# 2) 생성된 golden PNG만 따로 커밋(다른 staged 변경과 섞지 않도록 경로를 지정)
git add -- frontend/test/goldens/baseline
git commit -m "Add FE1-g golden baseline images" -- frontend/test/goldens/baseline

# 3) 비교 모드로 다시 실행 → summary.txt의 result가 GREEN인지 확인
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

실행 정책이 막지 않으면 `.\frontend\tool\fe_gate.ps1 -UpdateGoldens`처럼 바로 실행해도 된다. 결과는 마지막 `debug/frontend_gate/<시각>/summary.txt`를 이 문서 "FE1-g gate 결과"에 붙인다.
FE1-g 코드(테스트 2파일, `fe_gate.ps1`, `.gitignore` 1줄, 이 문서)의 커밋은 gate가 녹색으로 보고된 뒤 사용자 승인으로 따로 한다. `.gitignore` 외에는 새 파일이므로 기존 미커밋 변경과 섞이지 않는다.

기대값:

- `flutter-analyze`: No issues found.
- `flutter-test`(golden 제외): 414개 통과. `flutter-test-golden`: 17개 통과.
- `git-diff-check`: v7 범위의 기존 미커밋 변경에 whitespace 문제가 있으면 여기서 실패할 수 있다. 그때는 `git-diff-check.log`의 파일이 FE1-g 파일인지 먼저 본다.

### FE1-g gate 결과

사용자 실행 2회(2026-10-06, 사용자 PC, Flutter 3.44.6 stable). 로그: `debug/frontend_gate/20261006_220859/`(생성), `debug/frontend_gate/20261006_221212/`(비교).

| 단계 | 생성 실행 `20261006_220859` (HEAD `691e5213`) | 비교 실행 `20261006_221212` (HEAD `8e95d946`) |
|---|---|---|
| flutter-analyze | PASS, No issues found | PASS, No issues found |
| flutter-test-update-goldens | PASS, 17/17, PNG 17개 생성 | — |
| flutter-test(당시엔 golden 포함 전체) | FAIL, +427 −4 | FAIL, +427 −4 |
| almanac-validate | FAIL, `survey-shared` 미인용(unused_sources) | FAIL, 같은 사유 |
| git-diff-check | PASS, 0건 | PASS, 0건 |
| golden PNG | 17개 | 17개, 해시 목록이 생성 실행과 **완전히 같음**, 실패 이미지 0 |

- **golden 17장은 두 실행 모두 통과했다.** 비교 실행에서 기존 PNG와 diff 0이었고 실패 이미지가 없었으므로 재현성도 확인됐다. 비교 실행 시 `git status`에 baseline PNG가 나오지 않아 PNG는 커밋된 것으로 본다(HEAD `8e95d946`).
- **실패 4건은 golden이 아니다.** 실제 Python 프로세스를 띄우는 E2E 4건이 두 실행 모두 똑같이 시간 초과로 실패했다:
  `planning_protocol_client_test`(test 20s 초과), `repository_process_e2e_test`(`planning.inventory.catalog` 요청 10s 초과), `scenario_process_e2e_test`·`tactical_process_e2e_test`(`repository.profile.create` 요청 10s 초과).
  네 건 모두 golden 파일이 병렬로 실행되던 구간(00:01~01:34)에 났다. FE1-a 직후 golden 없이 돌린 `flutter test`는 414/414 통과였다(사용자 보고). 그래서 2560×1392 golden 렌더링이 CPU를 차지해 Python 백엔드 응답이 늦어진 것으로 판단했다(가장 유력한 원인, 단독 재현은 아직 하지 않음).
- 조치(2026-10-06): golden 테스트 라이브러리에 `@Tags(['golden'])`, `frontend/dart_test.yaml`에 태그 선언, `fe_gate.ps1`은 golden 외 전체와 golden을 **나눠 차례로** 실행. E2E 테스트 자체(C 커밋 파일)는 고치지 않았다.
- almanac: status frontmatter의 `survey-shared` 출처를 본문(FE1-g 착수 기록)에서 인용하도록 고쳤다.
- `fe_gate.ps1`이 flutter 출력의 `•`를 `?`로 읽던 문제(콘솔 코드페이지)를 고쳤다: 실행 중에만 콘솔 출력 인코딩을 UTF-8로 두고 끝나면 되돌린다.

재실행 결과(수정 후 비교 모드): **미실행** — 사용자 실행 대기.

### 미검증 항목과 첫 실행에서 실패할 수 있는 지점

- 이 세션은 Flutter·PowerShell을 실행할 수 없었다(사용자 PC 셸 없음, 클라우드에서는 SDK·패키지 설치가 네트워크 정책으로 막힘). 첫 작성분은 사용자 실행으로 analyze PASS·golden 17/17을 확인했다. 수정분(태그, `dart_test.yaml`, gate 단계 분리, 인코딩)은 아직 실행 전이다.
- E2E 시간 초과의 원인이 CPU 경합이라는 판단은 수정 후 재실행(golden 외 414/414)으로 확인한다. 그래도 실패하면 golden과 무관한 E2E 불안정이므로 해당 로그를 오케스트레이터에게 넘긴다.
- 실패할 수 있는 지점(실패하면 로그를 붙여 주면 다음 세션이 고친다):
  1. **Windows 대상 플랫폼**: 기존 테스트는 기본값(android)으로 돈다. 실제 앱과 같게 하려고 golden만 Windows로 그렸다. 데스크톱 전용 경로(스크롤바, 시각 밀도 compact)에서 예외가 나면 그 장면만 android 기본값으로 바꾸는 방안이 있다.
  2. **타이틀 warmup 대기**: `student-grid-paint-warmup`이 400회 pump 안에 사라지지 않으면 실패한다(결과 흔들림 방지용으로 일부러 실패시킴).
  3. **FontManifest 아이콘 글꼴**: 읽지 못하면 아이콘만 테스트 글꼴로 그려진다. 실패하지는 않고 결과도 결정적이다.
  4. 장면 진입 키: `students-detail`(첫 학생 키가 정확히 1개여야 함), `plan-scenario-compare`(후보 키 `plan-compare-candidate-<id>`).
- 재현성: 같은 PC에서는 결정적이어야 한다(고정 시드 배경, 고정 시나리오 시각, 이미지 선디코드). 다른 PC나 다른 Flutter 버전에서는 글꼴 렌더 차이로 diff가 날 수 있다. golden은 이 PC 기준이다.

### 재실행 명령 (수정 후)

golden PNG는 이미 커밋돼 있으므로 다시 만들지 않는다. 비교 모드만 돌린다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

기대: `flutter-analyze` PASS, `flutter-test` 414 통과, `flutter-test-golden` 17 통과, `almanac-validate` PASS, `git-diff-check` PASS → result GREEN.

### 처리한 FD

FE1-g에 걸린 워커 재량 FD는 없다.

### 발견 사항

1. `section_template_surface.dart`의 인라인 4곳과 `student_section_layout.dart`의 33곳은 장면이 파일을 그리기는 하지만 줄 단위 실행 여부는 모른다. FE1-b 착수 시 커버리지(`flutter test --coverage test/goldens`)로 줄 단위 확인을 권한다.
2. 실제 앱의 계획 탭은 `loadRepositoryPlan: true`로 열리지만, 계획 메인·하위 화면 장면은 기존 테스트처럼 기본 fixture(`loadRepositoryPlan: false`)로 그렸다. 병목·페이즈 내용이 더 많아 기하 회귀를 더 넓게 잡기 때문이다. 시나리오 2장면만 repository 경로다.
3. **저장소 검증 명령과 golden의 병렬 실행.** AGENTS.md·README의 `cd frontend; flutter test`는 golden까지 한 번에 병렬로 돌린다. 그러면 위 E2E 4건이 시간 초과로 실패할 수 있다. 오케스트레이터가 검증 명령을 `frontend/tool/fe_gate.ps1`(또는 `flutter test --exclude-tags golden` 뒤 `flutter test test/goldens`)로 바꿀지 결정해야 한다. E2E 요청 시간 제한(10s)이 부하에 민감하다는 점도 스캐너·저장소 워크플로에 알릴 만하다.

### 다음 행동

1. ~~golden 생성·커밋~~ 완료(2026-10-06). 사용자: 위 "재실행 명령"으로 비교 모드 gate → `summary.txt`를 붙여 주면 "FE1-g gate 결과"를 채운다.
2. 비교 모드가 GREEN이면 사용자 승인 하에 FE1-g 코드 커밋(테스트 2파일, `dart_test.yaml`, `fe_gate.ps1`, `.gitignore` 1줄, 이 문서).
3. 다음 slice **FE1-b DiagonalGeometry(동작 보존)**: `tan80` 상수, `cutDepth(h)`, 레일 x(y), 법선 inset(g/sin80), 둥근 다각형 단일 API(FD-016), 행 오프셋 2모드(translate/resize). 인라인 108곳 교체(스캐너 소유 `scan_student_review_workspace.dart` 3곳은 소유권 규칙상 FE1-b에서도 손대지 않고 status에 남긴다), 기하 단위 테스트. 완료 조건은 이 golden 17장 diff 0과 `fe_gate.ps1` GREEN이다.

### FE1-g 커밋 기록 (2026-10-06 22:44, fe_commit.ps1 자동 기록)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261006_224319\summary.txt (result         : GREEN)
- 커밋 방식: 고치기 전 사본·HEAD·현재 파일 3-way 병합 결과를 index에만 올림. 작업트리에 남긴 기존 변경: 없음

### FE1-b commit record (2026-10-06 23:18, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261006_231705\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none
