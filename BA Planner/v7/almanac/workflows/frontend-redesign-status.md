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

**FE2-a 완료.** 결과(오케스트레이터 로그 2026-10-07 00:41, 아래 FE2-a commit record):
- gate `debug/frontend_gate/20261007_003201` RED: 테스트 1건 실패. `diagonal_scroll_viewport_test.dart`의 translate 폭 정확 비교가 1ulp 차이로 틀렸다. 오케스트레이터가 `closeTo(before.width, 1e-9)`로 고쳤다. 그 밖에는 analyze PASS, golden 17장 차이 0.
- `debug/frontend_gate/20261007_004310` GREEN(456 + golden 17).
- 커밋 `97c568b6fc35ae8e3ba5c7304d9a8c51da7c9473`.
- 프롬프트가 가리킨 로그 "00:47 항목"은 로그 파일에 없다(00:41 항목과 status의 00:48 commit record만 있다).

**진행 중: FE2-b 소형 컨트롤·제목, 시작 커밋 `97c568b6fc35ae8e3ba5c7304d9a8c51da7c9473`(FE2-a).** 코드·테스트 작성은 끝났고 gate는 아직 돌리지 않았다(사용자 PC ①~③ 대기). 자세한 내용은 아래 "FE2-b" 절.

### 커밋 기록

| slice | 커밋 | 내용 | gate |
|---|---|---|---|
| FE0-base | `36702c28` | 개편 전 프론트 미커밋 작업을 원래 내용 그대로 기준선으로 커밋(사용자 승인) | — |
| FE1-a | `54ed8086` | 디자인 토큰 추가, 같은 값 리터럴 교체(동작 보존) | 사용자 실행 analyze·test 통과(2026-10-06 21:32 보고) |
| FE1-g | `8e95d946`(golden PNG 17장), `1ac37eeb`(테스트·`fe_gate.ps1`·`fe_commit.ps1`) | golden 기준선 + gate | `debug/frontend_gate/20261006_224319` GREEN |
| FE1-b | `d5f87b7b` | 80° 기하 공용 API, 인라인 105/108곳 교체(동작 보존) | `debug/frontend_gate/20261006_231705` GREEN |
| FE1-c | `99583757` | 공용 `SectionSurface`(surface@.76, 무블러·무테, lifted shadow 4층), golden 6장 갱신(시각 변경) | ① `20261006_233307` RED(golden 6, 예상 일치) → ③ `20261006_233605` GREEN(424 + golden 17) |
| FE2-a | `97c568b6` | 공용 키트: 사선 스크롤바·포그 파라미터·`DiagonalScrollViewport`·`DiagonalRow`·UI Kit 갤러리, private 스크롤바 4종 교체(동작 보존) | `20261007_003201` RED(테스트 기대값 1ulp, 오케스트레이터 수정) → `20261007_004310` GREEN(456 + golden 17) |

아래 FE1-a·FE1-g 절의 "미실행", "대기" 표현은 작성 당시 기록이다. 결과는 이 표와 각 절의 커밋 기록이 최신이다.

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

## FE1-b 착수 기록 (2026-10-06)

- 범위: 80° 기하 공용 API(`frontend/lib/ui/geometry/diagonal_geometry.dart`), 인라인 `tan(80…)` 108곳 교체(스캐너 소유 3곳 제외), FD-016 둥근 다각형 단일 API, 기하 단위 테스트. 동작 보존: golden 17장 diff 0과 `fe_gate.ps1` GREEN이 완료 조건.
- 시작 커밋 `180f5551cc4d63621612c9b454fc2ede32159d1a`(브랜치 `scanner-consolidation`). (정정 2026-10-06 FE1-c: 착수 당시 "FE1-a 단독 커밋이 보이지 않는다"고 적었으나 오판이었다. FE0-base `36702c28`, FE1-a `54ed8086`이 그 뒤에 커밋됐고 FE1-b는 그 위에서 커밋됐다.)
- 막힘: 대장 막힘 요약에서 FE1을 막는 열림 FD 없음. 처리 FD: FD-016(워커 재량).
- 착수 전 사본(`debug/frontend_fe1b/pre/<v7 기준 경로>`, 12개). 각 파일을 기기에서 읽은 시점의 바이트 그대로이며, 쓰기 때 수정 시각을 대조해 그사이 바뀐 파일이 없음을 확인했다.
  - `frontend/lib/ui/widgets/account_section_cluster.dart`
  - `frontend/lib/ui/widgets/diagonal_flow_indicator.dart`
  - `frontend/lib/ui/widgets/diagonal_media_list_item.dart`
  - `frontend/lib/ui/widgets/diagonal_menu.dart`
  - `frontend/lib/ui/widgets/plan_element_builder.dart`
  - `frontend/lib/ui/widgets/plan_phase_editor.dart`
  - `frontend/lib/ui/widgets/plan_preset_manager.dart`
  - `frontend/lib/ui/widgets/plan_section_layout.dart`(C 이전 미커밋 변경이 있는 파일)
  - `frontend/lib/ui/widgets/plan_student_selector.dart`
  - `frontend/lib/ui/widgets/section_template_surface.dart`
  - `frontend/lib/ui/widgets/student_range_condition_section.dart`
  - `frontend/lib/ui/widgets/student_section_layout.dart`

## FE1-b 종료 기록 (2026-10-06, 커밋 `d5f87b7b`)

**완료.** gate `debug/frontend_gate/20261006_231705` GREEN: analyze 이슈 0, 테스트 419(기존 414 + 기하 5), golden 17장 차이 0, almanac validate, diff-check. 커밋 `d5f87b7b`(15파일, `fe_commit.ps1`의 3-way 병합, 작업트리에 남은 차이 없음). 인라인 `tan(80…)` 교체 105/108곳, 스캐너 소유 `scan_student_review_workspace.dart` 3곳은 남겼다.

### 공용 API (`frontend/lib/ui/geometry/diagonal_geometry.dart`, 새 파일)

| API | 식 | 비고 |
|---|---|---|
| `diagonalTan80`, `diagonalSin80` | `math.tan(80 * math.pi / 180)`, `math.sin(80 * math.pi / 180)` | 교체 전 인라인 식과 같은 식으로 계산한 `final` 상수 → 비트 단위로 같은 값 |
| `diagonalCutDepth(h)` | `h / tan80` | 섹션 컷 깊이·레일 inset·평행사변형 기울기 폭 |
| `diagonalRiseForRun(run)` | `run * tan80` | cutDepth의 역 |
| `diagonalNormalInset(g)` | `g / sin80` | 법선 간격 → 가로 간격 |
| `diagonalRightRailX(right:, y:)`, `diagonalLeftRailX(left:, y:)` | `right - y / tan80`, `left + y / tan80` | 레일 x(y) |
| `diagonalRowTranslateOffset(viewportHeight:, rowBottomInViewport:)` | `(vh - bottom) / tan80` | 행 오프셋 translate 모드 |
| `diagonalRowResizeReduction(viewportHeight:, rowHeight:)` | `(vh - rowHeight) / tan80` | 행 오프셋 resize 모드(행 폭에서 빼는 값) |
| `diagonalRoundedPolygon(points, radius:, corner:)` + `DiagonalCornerStyle.arc / quadratic` | 기존 두 구현을 그대로 옮김 | FD-016 단일 API |

입력 타입은 `num`이다(`math.max(0, …)`처럼 런타임에 int가 오는 자리도 기존 `num / double`과 같은 결과).

**처리한 FD: FD-016(워커 재량).** 둥근 다각형: 원호 필렛(`buildRoundedSectionPolygon`)과 Q 곡선(`roundedPolygonPath`)은 같은 꼭짓점에서 **서로 다른 path**를 낸다. 그래서 "기존 path와 같은 결과를 내는 한쪽"을 모든 호출의 정본으로 고르면 다른 쪽 호출처의 화면이 바뀐다(동작 보존 위반). 두 구현을 `diagonalRoundedPolygon`의 `corner` 모드로 묶어 정본 하나로 만들고, 기존 이름 두 개는 각 모드를 부르는 호환 래퍼로 남겼다. 본문은 글자 그대로 옮겼다(옮긴 본문이 원본과 같은지 기계적으로 대조함, 차이는 주석 1줄). 시안의 Q 곡선으로 통일할지는 캔버스 대조가 필요하므로 각 화면 slice(또는 FE1-c 표면)에서 정한다.
**FD-016 세 번째 함수 `buildRightCutRoundedPath`(`diagonal_header.dart`)를 합치지 않은 이유(의도).** (1) 일반 다각형 함수가 아니다. 꼭짓점 목록이 아니라 `width`·`height`·`radius`·`angleDegrees`(각도 인자)로 오른쪽 컷 사각형을 만들고, 네 모서리를 `quadraticBezierTo`로 직접 그린다. 컷 쪽 두 모서리는 반경 위치를 변의 방향이 아니라 축 방향(`height - safeRadius`)으로 잡는다. (2) 그래서 같은 모양을 `diagonalRoundedPolygon(corner: quadratic)`에 꼭짓점으로 넘기면 모서리 시작·끝점이 달라져 헤더 golden이 바뀐다. (3) `tan(angleDegrees …)`는 80 리터럴이 아니어서 108곳에 들지 않는다. 시안 헤더(우측 80° 컷 r14, H §6.1)에 맞춰 바꿀 때 다각형 API로 옮기는 것을 검토한다. FE1-b 커밋에 이 파일이 없는 것은 의도다.

### 바꾼 파일과 교체 수

`const`는 `math.tan(...)`/`math.sin(...)`만 `diagonalTan80`/`diagonalSin80`으로 바꾼 자리다(앞뒤 연산이 함수 형태와 맞지 않거나 지역 변수 `tangent`·`sine`에 담는 자리). 함수 형태는 `X / tan80`이 독립된 항일 때만 썼다. 앞에 `*`·`/`·단항 `-`가 붙어 결합 순서가 달라질 수 있는 자리는 `const`로만 바꿨다. 교체는 스크립트로 하고 266줄 diff를 줄마다 읽어 연산 순서가 같은지 확인했다.

| 파일 | tan80 인라인 | 교체 형태 | sin80 인라인 | 그 밖 |
|---|---|---|---|---|
| `student_section_layout.dart` | 33 | cutDepth 26(그중 translate 모드 1), const 7 | 4: normalInset 3, const 1 | |
| `plan_section_layout.dart` | 20 | cutDepth 20(그중 translate 1, resize 1) | — | |
| `plan_element_builder.dart` | 17 | cutDepth 9(그중 rightRailX 1), const 8 | 10: normalInset 8, const 2 | |
| `plan_phase_editor.dart` | 14 | cutDepth 13, const 1 | 4: normalInset 2, const 2 | |
| `plan_preset_manager.dart` | 5 | cutDepth 3, const 2 | 4: normalInset 3, const 1 | |
| `section_template_surface.dart` | 4 | riseForRun 3, cutDepth 1 | — | `buildRoundedSectionPolygon` → 래퍼 |
| `account_section_cluster.dart` | 3 | cutDepth 2, const 1 | — | |
| `diagonal_media_list_item.dart` | 3 | cutDepth 3 | — | |
| `plan_student_selector.dart` | 3 | cutDepth 3 | — | |
| `student_range_condition_section.dart` | 2 | const 2 | 3: normalInset 1, const 2 | |
| `diagonal_flow_indicator.dart` | 1 | cutDepth 1 | — | 쓰지 않게 된 `dart:math` import 제거 |
| `diagonal_menu.dart` | 0 | — | — | `roundedPolygonPath` → 래퍼 |
| **합계** | **105** | | **25** | |

새 파일: `frontend/lib/ui/geometry/diagonal_geometry.dart`, `frontend/test/geometry/diagonal_geometry_test.dart`.
모든 수정 파일에 `import '../geometry/diagonal_geometry.dart';`를 추가했다. 줄바꿈(CRLF/LF)은 파일마다 원래대로 두었다.

### 남긴 곳과 이유

| 위치 | 이유 |
|---|---|
| `scan_student_review_workspace.dart` 855·857, 968·970 (tan80 3곳 + sin80 1곳) | 스캐너 세션 소유 파일(워크플로 소유권 규칙). 스캐너 동결 창이나 FE8-g4에서 바꾼다 |
| `section_template_surface.dart`의 `tan(cornerAngle / 2)` | 80° 계산이 아니라 필렛 반각이다. 내용은 바꾸지 않았고, `buildRoundedSectionPolygon` 본문과 함께 `diagonal_geometry.dart`의 `_arcRoundedPolygon`으로 **위치만** 옮겼다(주석 표시) |
| `diagonal_header.dart` 23·119, `diagonal_menu.dart` 32, `diagonal_section.dart` 39 | `tan(angleDegrees …)`처럼 각도를 인자로 받는 범용 함수다. 80° 리터럴이 아니어서 108곳에 들지 않는다. 호출 각도는 모두 80이지만 API를 각도 인자 없이 바꾸는 일은 이번 범위 밖이다 |
| `buildRightCutRoundedPath`(`diagonal_header.dart`) | 위 FD-016 처리 참고 |
| 지역 변수 `tangent`·`sine`을 쓰는 식(예: `studentDiagonalFilterRowWidth`의 `/ tangent`) | 변수에 담는 줄만 상수로 바꿨다. 쓰는 식까지 함수로 옮기면 diff가 커지고 이득이 없다 |

### 기하 단위 테스트 (`frontend/test/geometry/diagonal_geometry_test.dart`, 5건)

- 상수가 교체 전 식과 비트 단위로 같은지 확인한다.
- cutDepth·rise·normalInset·좌우 레일을 높이 15개(0, 음수, 1392 포함)와 int 입력으로 비교한다.
- 행 오프셋 두 모드를 viewport 4개 × 행 5개로 비교한다.
- 교체 줄이 있는 공개 레이아웃 함수 11개를 교체 전 인라인 식과 비교한다: `planScenarioParallelogramDepth`, `sectionTemplateCutDepth`, `studentFilterGroupContentInset`, `diagonalParallelogramBottomCenterX`, `planStudentSelectorDiagonalDepth`, `studentStarSegmentDepth`, `portraitGridTrajectoryOffset`, `planPhaseRowHorizontalOffset`, `studentDiagonalRowHorizontalOffset`, `planPhaseRowWidth`, `studentDiagonalFilterRowWidth`.
- 다각형: 교체 전 두 구현을 테스트 안에 그대로 옮겨 두고, 래퍼와 `diagonalRoundedPolygon`의 path를 bounds·contour 길이·17개 표본 위치로 정확히 비교한다. 다각형 5개 × 반경 5개이며, 중복 점 다각형과 점 2개 경계도 포함한다.
- 모두 `closeTo`가 아니라 정확히 같은지(`equals`) 본다.

private 함수·painter 안의 교체 줄은 공개 API가 없어 직접 부를 수 없다. 이 줄들이 golden 장면에서 실행되는지는 아래 커버리지 명령으로 확인한다. 실행되지 않는 줄이 있으면 다음 세션이 그 줄을 지나는 공개 함수 테스트를 추가한다.

### gate 결과

| 항목 | 결과 |
|---|---|
| `flutter analyze` | PASS(이슈 0) |
| 테스트(golden 제외) | 419 통과(414 + 기하 5) |
| golden 17장 | 차이 0 |
| almanac validate, git diff --check | PASS |
| gate 요약 | `debug/frontend_gate/20261006_231705/summary.txt` GREEN |
| 커버리지(교체 줄 실행 여부, `flutter test --coverage test/goldens`) | 결과를 받지 못했다. 교체 줄은 값이 비트 단위로 같아(단위 테스트 통과) golden 미실행 줄이 있어도 위험은 낮다. 필요하면 FE2 착수 전에 `lcov.info`로 확인한다 |

### 다음 행동

FE1-c SectionSurface(아래 절).

### FE1-b commit record (2026-10-06 23:18, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261006_231705\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE1-c 착수 기록 (2026-10-06)

- 범위: 섹션 표면을 시안 값 하나로 통일(FD-006): `AppColors.surface`@.76, 블러 없음, 테두리 없음, 아래에 lifted path shadow 4층(FD-007 (a)). 공용 위젯·painter 하나로 모으고 기존 클래스는 얇은 래퍼로 둔다. 행·타일·칩·스크롤바·포그(FE2)와 텍스처(FD-015 (a))는 범위 밖.
- 시작 커밋 `d5f87b7b`(착수 시 HEAD `b91c30ff`, 문서만 다름). 막힘: FE1을 막는 열림 FD 없음.
- 착수 전 사본(`debug/frontend_fe1c/pre/<v7 기준 경로>`, 기기에서 읽은 바이트 그대로):
  - `almanac/design/section-template-studio.md` — **기존 미커밋 변경 있음**(C 인계 `unrelated-changes.json`)
  - `frontend/lib/app/theme.dart` — `unrelated-changes.json` 목록에 있음(FE0-base 이후 남은 변경 여부는 `fe_commit.ps1`이 판정)
  - `frontend/lib/ui/widgets/plan_section_layout.dart` — 같은 목록에 있음
  - `frontend/lib/ui/widgets/diagonal_section.dart`
  - `frontend/lib/ui/widgets/section_template_surface.dart`
  - `frontend/lib/ui/pages/title_page.dart`
  - `frontend/lib/ui/widgets/account_section_cluster.dart`
  - `frontend/lib/ui/widgets/plan_phase_editor.dart`
  - `frontend/lib/ui/widgets/student_range_condition_section.dart`
  - `frontend/lib/ui/widgets/plan_student_selector.dart`
  - `frontend/lib/ui/widgets/plan_element_builder.dart`
  - `frontend/lib/ui/widgets/student_section_layout.dart`
  - `frontend/test/title_page_test.dart`

## FE1-c 종료 기록 (2026-10-06, 코드 작성 완료·gate 미실행)

### 공용 섹션 표면 (`frontend/lib/ui/widgets/section_surface.dart`, 새 파일)

| API | 내용 |
|---|---|
| `sectionSurfaceOpacity`, `sectionSurfaceColor` | 0.76, `AppColors.surface`@0.76 |
| `paintSectionSurface(canvas, path, {fillPath, fill, shadow})` | `paintLiftedPathShadow`(기본 `defaultLiftedSectionShadow`, 4층)를 먼저, 그 위에 fill. `fillPath`로 자식 표면을 뺀 path를 칠할 수 있다. 그림자는 차감 전 path |
| `SectionSurface(clipper:, child:, fill?, shadow?)` | `CustomPaint(SectionSurfacePainter)` + `ClipPath` + 투명 `Material`. `BackdropFilter`·테두리 없음. painter는 hit test를 받지 않는다 |
| `SectionSurfacePainter`, `SectionPathClipper` | 위 위젯의 painter, 고정 path clipper |

### 바꾼 표면 (이전 → 이후)

| 위치 | 이전 | 이후 |
|---|---|---|
| `diagonal_section.dart` `DiagonalSection` | surface@.92, blur 8, `Border.all(outline)` | `SectionSurface` 래퍼(.76, 블러·테두리 없음, lifted shadow) |
| `section_template_surface.dart` `SectionTemplateSurface`, `AttachedSectionTemplateSurface` | .88(선택 primaryMuted@.78), blur 8, 1px outline(선택 2.5px primary) | `SectionSurface` 래퍼. 선택되지 않으면 테두리 없음. 선택 표시는 유지(아래) |
| 같은 파일 `SectionCanvasPainter`(Studio 편집기 미리보기) | .92(선택 primaryMuted@.88) + 1px outline(선택 2.5px primary) | 선택되지 않은 Section은 `paintSectionSurface`(런타임과 같음). 선택 표시는 유지 |
| `title_page.dart` `_StudioPathSurface`, `account_section_cluster.dart` `_PathSurface`의 텍스처 없는 바탕(타이틀 brand·account, 계정 관리·편집·초상 선택 바탕) | surface@.78 + blur 8 | `sectionSurfaceColor`, 블러 없음. 그림자는 기존처럼 화면이 그리는 `LiftedPathShadow` 1회 |
| `plan_student_selector.dart` 선택 패널 painter | 그림자 + surface@.84 | `paintSectionSurface`(.76) |
| 이미 시안 값(.76 + 그림자)이던 painter: `PlanSectionFoundationPainter`, 페이즈 편집기·범위 조건·학생 선택기·요소 빌더 foundation | 각자 같은 식을 인라인 | `paintSectionSurface` 호출로 교체(값 동일) |
| 화면별 알파 상수 `planSectionOpacity`, `studentSectionOpacity`, `planStudentSelectorSectionOpacity`, `planElementBuilderSectionOpacity` | 각 0.76 | `= sectionSurfaceOpacity`(값 동일, const 유지) |

**선택 상태(FD-005).** 시안의 섹션 자체에는 선택 상태가 없다(선택 핑크는 행 `.srow.sel`·세그먼트 등 FE2 요소에 쓰인다, H §6.2·§6.3). 섹션 선택 표시는 Studio 편집기(`SectionCanvasPainter`)와 런타임에서 쓰지 않는 `SectionTemplateSurface`/`AttachedSectionTemplateSurface`의 `selected`에만 있다. 시안 근거가 불분명하므로 기존 표현(primaryMuted 채움 + primary 외곽선)을 유지했다. 이 표시를 핑크로 바꿀지는 오케스트레이터 판단 사항이다(발견 사항 2).

**범위 밖으로 둔 것.**
- 텍스처 표면의 blur(타이틀 설정·나가기·시작 버튼, 계정 행동 버튼, 계정 목록 컨테이너): FD-015 (a), Container 표면이다.
- 헤더(`app_shell` L-glass blur 10, `diagonal_header` blur 12)와 홈 메뉴(`diagonal_menu` blur 7): 섹션 표면이 아니라 셸·메뉴 요소이고 시안 H §6.1에서 "재사용"으로 판정됐다.
- 학생 탭 foundation painter: 그림자는 path, 채움은 자식 Container를 뺀 path로 따로 그리는 구조라 상수만 공용 값으로 묶었다(채움 식은 이미 .76).
- 행·타일·칩·스크롤바·포그(FE2).

### 바꾼 파일

modified 13(착수 전 사본 있음): `almanac/design/section-template-studio.md`(기존 미커밋 변경 있음), `frontend/lib/app/theme.dart`(주석만), `frontend/lib/ui/pages/title_page.dart`, `frontend/lib/ui/widgets/account_section_cluster.dart`, `diagonal_section.dart`, `plan_element_builder.dart`, `plan_phase_editor.dart`, `plan_section_layout.dart`, `plan_student_selector.dart`, `section_template_surface.dart`, `student_range_condition_section.dart`, `student_section_layout.dart`, `frontend/test/title_page_test.dart`.
added 2: `frontend/lib/ui/widgets/section_surface.dart`, `frontend/test/widgets/section_surface_test.dart`.
whole: `frontend/test/goldens/baseline`(갱신 PNG). 쓰지 않게 된 `lifted_path_shadow.dart` import를 3파일(`plan_phase_editor`, `student_range_condition_section`, `plan_element_builder`)에서 지웠다.
문서: `section-template-studio.md`에 공용 표면 규칙 절을 넣고 "배경/blur 표면 개수" 문장을 고쳤다(FD-006 갱신 요구). `theme.dart`는 `AppColors.surface` 주석에 표면 규칙과 공용 API 위치를 적었다.

### 테스트

- 고친 테스트: `title_page_test.dart`의 "title follows the section studio placement and account state". brand glass 아래 `BackdropFilter`를 `findsOneWidget` → `findsNothing`으로 바꿨고, 색이 `sectionSurfaceColor`인지 확인을 추가했다. 같은 테스트의 primary 섹션 `BackdropFilter` 1개 검사는 텍스처 표면 것이라 그대로 통과해야 한다.
- 지운 테스트 없음.
- 새 테스트 `test/widgets/section_surface_test.dart`(5건). 확인하는 것: 알파 .76과 화면별 상수가 공용 값인지, `paintSectionSurface`가 그림자 4층(층별 색 확인) 다음 fill로 drawPath 5회인지, 그림자 생략·차감 path 채움, `DiagonalSection`·`SectionTemplateSurface`·`AttachedSectionTemplateSurface`에 `BackdropFilter`와 테두리 `DecoratedBox`가 없고 `SectionSurfacePainter`(fill .76, 기본 그림자)가 하나인지.
- 기대 수: golden 제외 424(419 + 5), golden 17.

### golden 갱신 사유(장면별 예상)

| 장면 | 예상 | 바뀌는 표면 |
|---|---|---|
| `title` | **바뀜** | brand·account 섹션 바탕: blur 8 제거, 알파 .78 → .76(배경 삼각 무늬가 선명하게 비침) |
| `account-manager`, `account-editor`, `account-picker` | **바뀜** | 계정 섹션 바탕: 같은 변화. 텍스처 버튼·목록은 그대로 |
| `plan-student-selector` | **바뀜** | 선택 패널(C) 알파 .84 → .76 |
| `scan-student-review` | **바뀜** | `DiagonalSection` 카드: .92 → .76, blur·1px 외곽선 제거, lifted shadow 추가 |
| `home`, `students-grid`, `students-detail`, `plan-bottleneck`, `plan-by-phase`, `plan-overall`, `plan-phase-editor`, `plan-element-builder`, `plan-preset-manager`, `plan-scenario-list`, `plan-scenario-compare` | **같아야 함** | 이미 .76 + 그림자였고 같은 식을 공용 함수로 옮겼을 뿐이다. `plan-element-builder`는 선택 패널이 확정 뒤 퇴장하므로 같아야 한다 |

위 6장 외에 차이가 나거나, 6장 안에서 표면 외(글자·행·버튼·텍스처) 차이가 보이면 회귀다. `fe_gate.ps1` ①의 `frontend/test/goldens/failures/`로 확인한다.

### 처리한 FD

FD-006(표면 통일, 확정), FD-007(그림자 (a) lifted 4층만, `.sw` 이중 그림자 없음, 워커 재량 권장안), FD-005(선택 핑크 규칙: 섹션 선택은 시안 근거가 없어 기존 표현 유지), FD-015(텍스처 유지, 워커 재량 권장안), FD-016(이번 slice에서 바꾼 것 없음).

### 소유권·영향 범위

- `scan_page.dart`, `scan_student_review_workspace.dart`는 열어서 고치지 않았다. 공용 `DiagonalSection` 내부가 바뀌어 **스캔 탭(세션·최근 스캔·검토 카드)의 섹션 표면도 같이 바뀐다**(발견 사항 1).
- `DiagonalSection`을 쓰는 다른 화면(인벤토리, 통계, 설정, 전술대항전 `tactical_page.dart`, 학생 탭의 스캔 후보 카드)도 같이 바뀐다. golden 장면에 없으므로 검수표로 확인한다. `tactical_page.dart`는 택틱(전술 편집기) 소유 파일이 아니며 열지 않았다.
- `app_shell.dart`는 바꾸지 않았다.

### 검수표 (mock 모드, 2560×1440 모니터에서 최대화 = 2560×1392)

실행: `cd frontend; flutter run -d windows --dart-define=BA_PLANNER_USE_REAL_BACKEND=false`. 공통 대조 포인트(캔버스 UI-Elements 블록 7 규칙과 각 탭 artboard 섹션)는 네 가지다. ① 섹션 바탕이 반투명(.76)이라 뒤의 삼각 무늬가 은은히 비친다. ② 비치는 무늬가 흐려지지 않는다(블러 없음). ③ 섹션 가장자리에 1px 외곽선이 없다. ④ 오른쪽·아래로 2px짜리 얇은 그림자가 있다.

| 탭·화면 | 여는 방법 | 볼 곳 |
|---|---|---|
| 타이틀 | 앱 시작 화면 | brand·account 섹션 바탕(①②④). 시작·설정·나가기 텍스처 버튼은 이전과 같아야 함 |
| 계정 관리·편집·초상 | 타이틀 → 설정 → 편집 → 초상 변경 | 각 섹션 바탕(①②④), 텍스처 버튼은 이전과 같음 |
| 계획 → 학생 선택기 | 계획 탭 → 학생 선택 | 오른쪽 선택 패널이 다른 섹션과 같은 투명도 |
| 인벤토리 | 인벤토리 탭 | 각 `DiagonalSection`(①~④) |
| 통계 | 통계 탭 | 섹션들(①~④) |
| 설정 | 설정 탭 | 섹션(①~④) |
| 전술대항전 | 전술대항전 탭 | 섹션(①~④) |
| 스캔 | 스캔 탭 → 대상 선택 → 시작(mock) | 세션·최근 스캔·검토 카드(①~④) |
| 홈·학생·계획 메인 | 각 탭 | 이전과 같아야 함(이미 시안 표면) |

### 미검증 항목

- 이 세션은 Flutter를 실행할 수 없었다. analyze·테스트·golden은 모두 미실행이며 통과를 주장하지 않는다.
- 위험 지점(실패하면 로그를 받아 고친다):
  - 새 테스트의 `paints` 패턴 매처(함수 대상).
  - 첫 실행에서 golden이 위 6장만 바뀌는지.
  - 그림자가 섹션 bounds 밖(오른쪽·아래 2px)에 그려지므로, 부모가 자르는 화면에서 그림자가 잘려 보일 수 있다(검수표에서 확인).

### 사용자 실행 순서

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① 비교: golden만 RED 예상(위 6장). 오케스트레이터가 frontend\test\goldens\failures\ 차이 이미지를 검토
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 검토 승인 뒤 golden 갱신
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
# ③ 비교 GREEN 확인
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ④ 커밋 미리보기 → ⑤ 커밋
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe1c -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe1c
```

### 발견 사항

1. **스캔 화면 표면 변경(허용된 간접 영향).** `scan_page.dart`·`scan_student_review_workspace.dart`의 `DiagonalSection`이 새 표면을 따른다. 스캐너 세션에 알릴 필요가 있다(그쪽 테스트에 블러·테두리 의존은 찾지 못했다).
2. **섹션 선택 표시 색.** Studio 편집기와 미사용 `SectionTemplateSurface` 계열의 선택 표시는 primaryMuted(파랑)다. FD-005(선택 = 핑크)를 편집기에도 적용할지 결정이 필요하다.
3. **`SectionTemplateSurface`·`AttachedSectionTemplateSurface`는 런타임에서 쓰는 곳이 없다**(lib·test 전체 검색, 정의 파일 제외). Studio 미리보기에도 쓰이지 않는다. FE10 죽은 코드 정리 후보다.

### 다음 행동

1. 사용자: 위 ①~⑤. ① 결과(`summary.txt`, `failures/`)를 오케스트레이터가 검토한다.
2. 다음 slice: FE2-a(행·스크롤: `DiagonalRow`, `DiagonalScrollViewport`, 공용 사선 스크롤바, 포그 파라미터. 동작 보존, golden diff 0).

### FE1-c commit record (2026-10-06 23:37, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261006_233605\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: almanac/design/section-template-studio.md

## FE2-a 착수 기록 (2026-10-06)

- 범위: 워크플로 FE2-a 행 그대로. 동작 보존이며, 기존 화면 golden 17장 차이 0이 완료 조건이다. 새 golden 장면은 추가하지 않는다.
- 시작 커밋: `233fb3890a274cabea6e6b86f302cf492d3ff15f`.
- 막힘 요약: FE2-a를 막는 `열림` FD는 없다(열림 0건).
- 워커 재량 FD는 FD-014, FD-018, FD-022다.
- sub-slice 분할(같은 세션에서 둘 다 진행하며, 커밋은 `fe2a` 하나):
  - **FE2-a1 스크롤.** 대상은 다음과 같다.
    - `ui/kit/`에 공용 사선 스크롤바(`DiagonalScrollbar`, `PlanDiagonalScrollbar` 이동), `ScrollViewportFog` 파라미터화(extent·색·페이드 범위), `DiagonalScrollViewport`(resize·translate)를 둔다.
    - 학생·계정·프리셋·페이즈 편집기의 private 스크롤바 4종을 공용으로 교체한다.
  - **FE2-a2 행·갤러리.** 대상은 `DiagonalRow`(.srow/.row/.plain/.tile, 상태 4종, 테두리 path hit test), UI Kit 갤러리, 개발 패널 진입점이다.
- 사본: 고칠 기존 파일마다 착수 전 사본을 `debug/frontend_fe2a/pre/<v7 기준 경로>`에 둔다.

## FE2-a 종료 기록 (2026-10-07, 코드 작성 완료·gate 미실행)

FE2-a1(스크롤)과 FE2-a2(행·갤러리)를 모두 끝냈다. 커밋은 `fe2a` 하나다.
- 이 환경에는 Flutter·Dart가 없다. analyze·테스트·golden은 돌리지 못했으니 통과를 주장하지 않는다.
- 대신 두 가지로 확인했다.
  - 이전 painter 5종을 테스트 안에 그대로 복사해 두고, 공용 painter와 그리기 명령을 비교하는 테스트를 넣었다.
  - 별도 검토 에이전트가 pre 사본과 새 코드를 대조했다. 화면별 값·연산 순서·Paint·키·Stack 순서가 같다고 보고했고, 컴파일·lint 문제는 찾지 못했다.

### 공용 키트 (`frontend/lib/ui/kit/`, 새 파일)

| 파일 | 내용 |
|---|---|
| `scroll_viewport_fog.dart` | `ScrollViewportFog`를 `ui/widgets/`에서 옮겼고, 옛 파일은 다시 내보내기만 한다(아래 설명). |
| `diagonal_scrollbar.dart` | `DiagonalScrollbar`: 계획 화면의 `PlanDiagonalScrollbar` 구현을 그대로 옮긴 위젯(아래 설명). |
| `diagonal_scroll_viewport.dart` | `DiagonalScrollViewport`(아래 설명). |
| `diagonal_row.dart` | `DiagonalRow`, `WidgetTile`과 보조 클래스·함수(아래 설명). |
| `gallery/ui_kit_gallery_page.dart` | `UiKitGalleryPage`. 개발 패널에서 연다. |

**`scroll_viewport_fog.dart`**
- 기존 이름(`ScrollViewportFog`, `scrollViewportFogVisibility`, `scrollViewportFogExtent`)을 그대로 쓴다. 옛 경로 `ui/widgets/scroll_viewport_fog.dart`는 `export`만 남겼다. 스캐너 소유 `scan_student_review_workspace.dart`도 이 경로로 import하므로 그 파일은 고치지 않았다.
- `ScrollViewportFog`에 파라미터를 더했다. 기본값은 기존과 같다.

  | 파라미터 | 기본값 |
  |---|---|
  | `extent` | 36 |
  | `color` | #263d52 |
  | `topOpacity` | 1 |
  | `bottomOpacity` | 1 |

- 불투명도가 1이면 기존과 같은 위젯 트리를 만든다(`Opacity`를 끼우지 않는다).
- 페이드 계산 `scrollViewportFogOpacity`와 생성자 `ScrollViewportFog.fromScroll`을 새로 두었다.
- `ScrollFogSpec`으로 시안 포그 세 종을 표현한다.
  - `standard`(A): 36px #263d52, 페이드 없음.
  - `panel(color)`(B): 44px, 페이드 60.
  - `statistics`(C): 56px rgba(25,36,50,.96), 페이드 80.

**`diagonal_scrollbar.dart`**
- `DiagonalScrollbar`: 기본값은 계획 화면 구현과 같다. 화면별 차이를 재현하는 파라미터가 있다.

  | 파라미터 | 값 |
  |---|---|
  | `trackPoint` | 레일 점 함수 |
  | `style` | `DiagonalScrollbarStyle`: 색·두께, path/`drawLine`, 스크롤할 것이 없어도 썸 그리기 |
  | `thumbSizing` | viewport 비율 또는 콘텐츠 비율 |
  | `extentSource` | controller 또는 콘텐츠 높이 |
  | `scrollOffset` | 보정한 스크롤 값 |
  | `drag` | rect, rail, none |
  | `showFog`·`fog`·`fogClipper`·`fogBuilder` | 포그 설정 |

- 그 밖에 공개한 것:
  - painter `DiagonalScrollbarPainter`.
  - 레일 점 함수 `diagonalScrollbarTrackPoint`(기존 `planScrollbarTrackPoint` 식)와 `diagonalScrollbarRailTrackPoint`(기존 프리셋 식).
  - 드래그 띠 `diagonalScrollbarDragPath`.

**`diagonal_scroll_viewport.dart`**
- `DiagonalScrollViewport`: resize·translate 두 모드가 있다(FD-018 (a)). 행 배치 함수는 `diagonalScrollRowSlot`이다.
- 두 모드 모두 FE1-b의 `diagonalRowTranslateOffset`·`diagonalRowResizeReduction`을 쓴다.
  - 기준 폭은 기존 `planPhaseRowWidth`와 같은 식이다.
  - translate는 `left += run`이고, resize는 `width += run`이다.
  - 화면 밖 행은 시안 CSS `cover 0%~100%`처럼 자른다.
- 기존 화면은 이 위젯으로 바꾸지 않았다. 바꾸는 일은 각 탭 slice가 한다.

**`diagonal_row.dart`**
- `DiagonalRow`
  - 변형: `.srow`, `.row`, `.plain`, `.tile`, 그리고 `rail`(`.rsr-*`).
  - 표시: `none`, `selected`, `blue`. hover는 누를 수 있는 행에서만 생긴다.
  - 테두리 path는 `diagonalRowPath`(80° 평행사변형, r8 Q 곡선 = 시안 path)다. 그리기·`ClipPath`·hit test·hover가 같은 path를 쓴다.
  - 시안 값은 `DiagonalRowLook.of`에 있다.
- `WidgetTile`(FD-022).

### 스크롤바 교체 (동작 보존)

| 화면 | 이전 | 교체 후 공용 위젯에 넘기는 값 |
|---|---|---|
| 계획 6곳(페이즈·병목·시나리오 목록·비교·전체 등) | `PlanDiagonalScrollbar` | 기본값 그대로. `PlanDiagonalScrollbar`는 `DiagonalScrollbar`의 typedef로 남겼다(테스트 호환). `keyPrefix` 기본값 `'plan-phase'`에 기대던 1곳은 값을 명시했다. |
| 학생 3곳(필터·목록·그리드, 계획 학생 선택기 포함) | `_StudentDiagonalScrollbar` + painter | 래퍼만 남겼다. `drag: rail`(레일 띠 8px), `fogBuilder` → `StudentViewportFog`. |
| 계정 2곳(초상 그리드·프로필 목록) | `_DiagonalScrollbar` + painter | 래퍼만 남겼다. `showFog: false`, 썸 #8edcff, `trackPoint: portraitScrollbarTrackPoint`. |
| 프리셋 3곳(요소 빌더의 프리셋 불러오기·프리셋 단계·미배정 목록) | `_PlanPresetDiagonalScrollbarPainter` + 화면마다 Stack | `_PlanPresetDiagonalScrollbar` 래퍼를 두었다. 넘기는 값: `extentSource`·`thumbSizing`을 콘텐츠 기준으로, `drawLine`, 위쪽 기준 레일 점, `planStageEffectiveScrollOffset` 값. 미배정 목록은 `drag: none`이다. |
| 페이즈 편집기 4곳 | `_PhaseEditorDiagonalScrollbarPainter` + Stack | `thumbSizing: contentRatio`, `phaseEditorScrollbarStyle`(트랙 2px outline@.38, 썸 4px accent@.9, `drawLine`, 스크롤할 것이 없어도 썸 표시), `drag: none`. |

- "프리셋"은 `plan_element_builder.dart`의 프리셋 painter를 뜻하는 것으로 보았다. `plan_preset_manager.dart`에는 private 스크롤바가 없다.
- 재현하지 못해 교체를 건너뛴 곳은 없다.
- 바뀌었지만 그리지 않는 것:
  - 드래그 영역 키를 `<prefix>-diagonal-scrollbar-drag`로 통일했다. 계획·프리셋은 원래 `-scrollbar-drag`였고, 이 이름을 찾는 코드·테스트는 없다.
  - 프리셋·페이즈 편집기 목록에도 1×1 `<prefix>-scrollbar-handle-center` 표식이 생겼다. 그리지 않고 포인터도 받지 않는다.
  - `ScrollConfiguration(scrollbars: false)`이 감싸는 범위가 스크롤 뷰에서 Stack 전체로 넓어졌다.
- 시안 대비 남은 시각 차이(동작 보존이라 이번에는 두었다):
  - 계정 썸 #8edcff(시안 #e5a0ea).
  - 페이즈 편집기 2px/4px accent.
  - 프리셋·페이즈 편집기 `drawLine`.
  - 이 값들은 각 탭 slice에서 캔버스와 대조해 공용 기본값으로 모은다. 파라미터와 주석에 그 뜻을 적었다.

### 바꾼 파일

- 기존 파일 7개. pre 사본은 `debug/frontend_fe2a/pre/frontend/lib/ui/widgets/`에 있다.
  - `plan_section_layout.dart`(CRLF 유지)
  - `student_section_layout.dart`
  - `account_section_cluster.dart`
  - `plan_element_builder.dart`
  - `plan_phase_editor.dart`
  - `scroll_viewport_fog.dart`(export만 남김)
  - `development_panel.dart`(갤러리 버튼 1개)
- 기존 미커밋 변경: 7개 모두 FE1-c 커밋 기록상 작업트리 차이가 없었다(`Working-tree diffs left`에 없음). 이 환경에서는 `git status`를 볼 수 없어 확인은 하지 못했다. `fe_commit.ps1`이 3-way 병합하므로, 차이가 있으면 거기서 드러난다.
- 새 파일 10개: `lib/ui/kit/` 5개, `test/kit/` 5개.
- `app_shell.dart`는 건드리지 않았다. 개발 패널 버튼이 `Navigator.push`로 갤러리를 연다.
- 스캐너 소유·동결·택틱 소유 파일도 건드리지 않았다.

### 테스트 (`frontend/test/kit/`, 32건 추가 → 예상 456 + golden 17)

| 파일 | 건수 | 확인 내용 |
|---|---|---|
| `diagonal_scrollbar_test.dart` | 9 | 아래 설명 |
| `scroll_viewport_fog_test.dart` | 6 | 기본값 36·#263d52·불투명도 1, 옛 경로 재수출, 포그 B·C 사양, 페이드 0이면 기존 on/off와 같은지, 불투명도 1이면 `Opacity` 없음, 페이드 25% |
| `diagonal_scroll_viewport_test.dart` | 5 | 아래 설명 |
| `diagonal_row_test.dart` | 6 | 아래 설명 |
| `ui_kit_gallery_test.dart` | 6 | 아래 설명 |

**`diagonal_scrollbar_test.dart`**
- 레일 점이 이전 식과 비트 단위로 같은지 확인한다.
- **이전 painter 4종**(계획=학생, 계정, 프리셋, 페이즈 편집기)을 그대로 복사해 두고, 공용 painter와 그리기 명령을 비교한다. 크기 3 × 스크롤 4 × 범위 3 조합에서 명령 종류·점·색·두께·cap·style을 본다.
  - `drawLine`은 정확한 double로 비교한다.
  - `drawPath`는 PathMetrics로 읽으므로 float32 정밀도로 비교한다.
- 위젯 테스트: 포그 기본값, 썸 표식 이동, 드래그, `showFog`·`drag`·`fogBuilder` 옵션.

**`diagonal_scroll_viewport_test.dart`**
- translate 모드 배치가 `planPhaseRowHorizontalOffset`·`planPhaseRowWidth`와 정확히 같은지 확인한다.
- 두 모드가 기하 API를 쓰는지, 행 윗변 오른쪽 끝이 레일 위에 있는지 확인한다.
- W-Layout 시안 폭 523.5/513.3/503.1, 시작 폭 472와 대조한다.
- 위젯에서 resize·translate 스크롤을 확인한다.

**`diagonal_row_test.dart`**
- path 모양: rail은 왼쪽이 수직이다.
- 변형·상태별 시안 CSS 값.
- 사선 바깥 삼각형을 누르면 반응하지 않는다.
- hover는 path 안, 누를 수 있는 행에서만 생긴다.
- painter의 채움·테두리 stroke, `WidgetTile`.

**`ui_kit_gallery_test.dart`**
- 개발 패널에서 열린다.
- resize 스크롤로 폭이 Δy/tan80만큼 넓어지고, 위 포그가 나타난다.
- translate 스크롤로 행이 Δy/tan80만큼 밀린다.
- 상태 견본이 맞고, 규칙이 없는 조합은 만들지 않는다.
- 직접 누르는 행의 hover·선택, 사선 바깥 탭.
- rail 행 선택.

지운 테스트는 없다. 기존 테스트가 찾는 키(`*-diagonal-scrollbar`, `*-fog`, `*-viewport-fog-*`, `*-scrollbar-handle-center`, `account-*-diagonal-scrollbar-drag`, `student-*-fog`의 `StudentViewportFog` 타입)는 모두 그대로다.

### 처리한 FD

- **FD-018 (a)**: `DiagonalScrollViewport(mode: resize/translate)`, `ScrollViewportFog` extent·색·페이드 범위 파라미터, `ScrollFogSpec` A/B/C.
- **FD-022**: 위젯 카드 `.tile`은 `WidgetTile`(= `DiagonalRow` tile 변형)로 만들었다. 갤러리 카드가 이것을 쓴다. 재화 타일 `ResourceTile`은 이번에 필요하지 않아 만들지 않았다(FE2-d `ItemIconTile` 때).
- **FD-014**: 시안에 정의만 있는 `.dash`는 만들지 않았다. `.row`·`.plain`의 hover·선택, rail의 파랑처럼 CSS 규칙이 없는 상태도 만들지 않았다. 갤러리에서는 "—"로 보인다.
- **FD-016**: 행 path는 시안과 같은 Q 곡선(`DiagonalCornerStyle.quadratic`)이다. 새 위젯이라 동작 보존과 무관하다.
- **워커 재량 1**: 워크플로의 네 변형 외에 `rail`(`.rsr-*`, W-Layout·Tactical·Import-Excel)을 더했다. "사다리꼴 안 스크롤" 견본을 그 배치대로 올리는 데 필요했다.

### 검수표 (mock 모드, 2560×1440 모니터 최대화 = 2560×1392)

**UI Kit 갤러리 여는 방법**
1. 헤더 오른쪽 개발 버튼(보드 아이콘)을 누른다.
2. 개발 상태 패널에서 "UI Kit 갤러리"를 누른다.
3. 왼쪽 위 뒤로 버튼으로 닫는다.

**W-Layout-Widgets "사다리꼴 안 스크롤" 타일(갤러리 첫 타일)과 캔버스 대조**

1. 패널: 560×320 사다리꼴(왼쪽 수직, 오른쪽 80°, r14, #141e2b). 목록 뷰포트는 (12,14) 541.5×292다.
2. 행 폭이 레일을 따른다.
   - 정지 상태 폭: 1행 523.5, 2행 513.3, 3행 503.1.
   - 위로 스크롤하면 넓어지고, 아래로 내리면 좁아진다. 왼쪽 끝은 고정이다.
3. 선택 행(처음엔 2행 "시로코"): 왼쪽 분홍 3px 막대와 핑크 그라데이션. 다른 행을 누르면 선택이 옮겨 간다.
4. hover: 행 바탕이 rgba(36,52,72,.8)로 밝아진다.
5. 사선 스크롤바: 트랙과 썸이 레일과 평행하고, 썸이 레일을 따라 움직인다. 썸을 끌어도 스크롤된다.
6. 포그 B(44px #141e2b)
   - 맨 위에서는 위 포그가 없고, 스크롤을 시작하면 60px 동안 나타난다.
   - 끝 60px 동안 아래 포그가 사라진다.
7. 알려진 차이
   - 초상 44×36 자리는 학생 이미지 대신 이름 첫 글자다.
   - 스크롤바 트랙의 가로 inset은 공용값 10이다. 시안 견본은 약 7이라 트랙이 시안보다 최대 3px 왼쪽에 있다.
   - rail 선택 그라데이션은 행 폭 기준이다(시안은 기울인 바탕 기준).
   - 설명 5번째 줄(CSS 구현 메모)은 빼고, 4줄만 둔다.
   - 타일 제목은 FE2-b `TileTitle` 전까지 갤러리 전용 임시 구현이다.

**갤러리 두 번째 타일 "평행사변형 안 스크롤 (translate)"(통계 sv-*)**
- 행 폭은 일정하고, 스크롤하면 행 전체가 레일 방향으로 밀린다.
- 포그 C: 56px, 페이드 80.
- 행은 `.srow`이고, hover와 선택이 된다.

**세 번째 타일 "사선 행 변형 · 상태"(UI-Elements 행 견본과 대조)**
- `.srow`
  - 기본 rgba(16,24,35,.72), 안쪽 1px 테두리 rgba(113,199,244,.16).
  - hover rgba(30,45,62,.9).
  - 선택 rgba(52,36,58,.85), 안쪽 2px #f2b3ef.
  - 파랑: 안쪽 2px rgba(113,199,244,.65).
- `.row`는 srow 바탕이고 상태가 없다. `.plain`은 투명하다.
- `.tile`은 rgba(16,24,35,.6), 테두리 없음, hover rgba(45,80,105,.8).
- rail은 위 "사다리꼴 안 스크롤" 행과 같다.
- 맨 아래 "직접 눌러 보기" 행으로 hover·선택과 사선 바깥 탭(반응 없음)을 확인한다.

**스크롤바를 바꾼 4화면(+계획). 모두 바뀌면 안 된다: golden diff 0 + 눈으로 확인**

| 화면 | 여는 방법 | 확인 포인트 |
|---|---|---|
| 학생 | 학생 탭 → 그리드·목록, 필터 열기 | 핑크 썸 8px, 레일 띠를 끌면 스크롤, 포그 #263d52(필터는 패널색) |
| 계정 | 타이틀 → 계정 관리, 계정 편집 → 초상 선택 | 하늘색 썸 #8edcff, 포그 없음, 썸 끌기 |
| 프리셋 | 계획 탭 → 계획 만들기(요소 빌더): 프리셋 불러오기 목록, 프리셋 단계 목록, 미배정 목록 | 핑크 썸, 포그, 앞의 두 목록은 오른쪽 끝을 끌면 스크롤 |
| 페이즈 편집기 | 계획 탭 → 페이즈 편집 | 얇은 핑크 썸 4px(스크롤할 것이 없어도 보임), 트랙 2px, 끌기 없음 |
| 계획 | 계획 탭 → 페이즈별·병목·전체, 시나리오 목록·비교 | 이전과 같음 |

### 미검증 항목

1. `flutter analyze`, 전체 테스트(기존 424 + 새 32), golden 17장 비교. 모두 사용자 PC gate가 필요하다.
2. 새 테스트 기대값 중 실제 실행에서 어긋날 수 있는 곳:
   - `drawPath` 비교의 PathMetrics 끝점 정밀도.
   - 갤러리 드래그 거리(drag slop 18px 이후 이동).
   - hover 테스트의 마우스 이벤트 순서.
   - 개발 패널 ListView에서 갤러리 버튼이 2560×1392 안에 그려지는지.
   - 실패하면 테스트 기대값부터 확인한다. 화면 코드는 golden이 판정한다.
3. 갤러리의 시각 배치(타일 내부 좌표)는 사용자 검수가 필요하다.

### 발견 사항

1. **status 0단계 기록이 기기에서 사라졌다.** FE2-a 착수 때 기기에 쓴 FE1-c 결과·착수 기록이 확인 시점에 없었다. 파일은 FE1-c 커밋 내용 그대로였고, 줄바꿈만 CRLF였다(mtime은 내가 쓴 시각). 원인은 모른다. 이번 종료 기록과 함께 다시 썼다.
2. `fe_commit.ps1`이 붙이는 trailer의 `Claude-Session` URL이 고정값(이전 세션)이다. 오케스트레이터가 판단할 일이다.
3. 계정 썸 색(#8edcff)과 페이즈 편집기 스크롤바(2px/4px accent)는 시안 사선 스크롤바와 다르다. 각 탭 slice에서 정할 일이다(계정 FE8, 페이즈 편집기 FE4).

### 사용자 실행 순서

```powershell
# ① gate. GREEN이어야 한다. golden 차이가 나오면 멈추고 오케스트레이터 검토(동작 보존 slice라 golden을 갱신하지 않는다)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

①이 GREEN이면:

```powershell
# ② 커밋 미리보기 → ③ 커밋
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe2a -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe2a
```

### 다음 행동

1. 사용자: ①. GREEN이면 ②·③을 실행하고, golden이나 테스트가 RED면 `summary.txt`와 `failures/`를 오케스트레이터에 넘긴다.
2. 다음 slice: FE2-b 소형 컨트롤·제목(`TileTitle`이 생기면 갤러리 임시 제목을 바꾼다).

### FE2-a commit record (2026-10-07 00:48, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261007_004310\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE2-b 착수 기록 (2026-10-07)

- 범위: 워크플로 FE2-b 행 그대로(칩·태그, 세그먼트·토글, 필터·스위치, 스테퍼·MAX 배지 추출·NudgeButtons, TonalButton·RailButton, 제목·텍스트). 위젯만 만들고 기존 화면 교체는 각 탭 slice에서 한다.
- 시작 커밋: `97c568b6fc35ae8e3ba5c7304d9a8c51da7c9473`.
- 막힘 요약: FE2-b를 막는 `열림` FD는 없다.
- 동작 보존: 스테퍼·MAX 배지 추출은 기존 golden 17장 차이 0이 완료 조건이다. 새 위젯은 시안 값을 따른다. 새 golden 장면은 추가하지 않는다.
- 사본: 고칠 기존 파일마다 착수 전 사본을 `debug/frontend_fe2b/pre/<v7 기준 경로>`에 둔다.
- sub-slice: FE2-b1(칩·세그먼트·토글·스위치·필터 버튼)과 FE2-b2(스테퍼·조절·버튼·제목)를 같은 세션에서 모두 했다. 커밋은 `fe2b` 하나다.
- 기존 미커밋 변경: 고친 기존 파일 2개(`plan_element_builder.dart`, `ui/kit/gallery/ui_kit_gallery_page.dart`)는 FE2-a 커밋 기록상 작업트리 차이가 없다("Working-tree diffs left: none"). 이 환경에서 `git status`는 볼 수 없다.

## FE2-b 종료 기록 (2026-10-07, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없어 analyze·테스트·golden을 돌리지 못했다. 통과를 주장하지 않는다.
- 스테퍼 추출 부분은 옮기기 전 코드와 문자 단위로 대조했다(들여쓰기와 이름만 다르다).
- 별도 검토 에이전트가 새 코드·테스트·추출 부분을 읽고 대조했다. 컴파일·lint·테스트 실패 요인은 찾지 못했다고 보고했고, 요소 빌더 기본 렌더도 같다고 했다.
- 검토 지적 중 고친 것: 선택된 칸도 키보드 포커스가 보이게, `TypeChip` `focusNode` 전달, `TileTitle` 긴 제목 줄임표.

### 공용 키트 (`frontend/lib/ui/kit/`, 새 파일)

| 파일 | 위젯 | 시안 값 |
|---|---|---|
| `kit_pressable.dart` | `KitPressable`(탭·Enter/Space·hover·포커스 공통), `kitDisabledOpacity`(.45), `kitFocusColor`(#71c7f4) | 비활성·포커스 모양은 시안에 없어 워커가 정했다 |
| `skew_box.dart` | `SkewBox`/`SkewBoxPainter`/`skewBoxPath` | skewX(−10°) 가운데 기준, r5 Q 곡선, 테두리는 안쪽(`box-shadow: inset`과 같음) |
| `kit_glyph.dart` | `KitGlyph`(×·깔때기·꺾쇠) | 시안 svg path, stroke 1.9 round |
| `ba_chip.dart` | `BaChip`(tone = `AppTones` 6색, `onRemove` → × 11px), `StageTag` | h24 r7 12px w700 / 단계 1 #71c7f4·2 #f2b3ef·3 #ffc66d, 채움 @.16 + 안쪽 1px @.55, 선택 = 원색 + #1a1f2a |
| `skew_controls.dart` | `SkewSegmented<T>`, `SkewToggleChip`, `TypeChip`+`TypeColorBar`, `FilterButton`, `BaSwitch` | 아래 설명 |
| `stepper.dart` | `BaStepper`, `StepButton`, `MaxBadge`, `NudgeButtons` | 앞의 셋은 요소 빌더에서 추출(아래), `.nd` 18×13 r3 |
| `buttons.dart` | `TonalButton`(normal·primary·ghost·danger), `RailButton`(+`RailButtonLook`), `RailButtonGroup` | 아래 설명 |
| `titles.dart` | `PanelTitle`, `TileTitle`, `SubHeader`, `KV`, `TitleBar`, `TitleRule`, `kitDisplayStyle` | 7×22·19px·캡 46 / 6×18·16px·캡 40 / 5×5 점 + 8px / cap 11px·간격 3 |

`skew_controls.dart` 시안 값:
- 세그먼트: h36 padding 16 간격 6, rgba(16,24,35,.9) + 1px rgba(158,176,194,.35), on #3a2a44 + 1.5px #f2b3ef.
- 토글 칩: h30 padding 13 간격 7. off white@.05 + 1px outline@.9, on #f2b3ef@.2 + 1.5px.
- 타입 칩: 앞에 8×14 r2 사선 막대.
- 필터 버튼: h30 padding 12. off white@.05 + 1px rgba(90,110,130,.9), 적용 중 #f2b3ef@.16 + 1.5px + "필터 · n".
- 스위치: 40×22 r11, 손잡이 16(left 3 → 21).

`buttons.dart` 시안 값:
- tonal: r10 padding 16 13px w600, #3a4b58/#d6e4f0 hover #455866, pri #f2b3ef/#2a1330 hover #f7c9f4.
- 레일 버튼: 왼쪽 수직·오른쪽 80° r8, 안쪽 16 / cut+12. 변형 7종(base·ghost·pri·sel-pink·sel-blue·done·tri).
- 그룹: 버튼 폭 = 첫 폭 − (윗변까지 세로 거리)/tan80. 시안 Scenario-List 347.1→334.7과 맞춘다.

### 스테퍼 추출 (동작 보존)

`plan_element_builder.dart`의 private 3종을 `kit/stepper.dart`로 옮겼다.
- 옮긴 위젯:
  - `_CompactTargetStepper` → `BaStepper`.
  - `_StepTextButton` → `StepButton`.
  - `_MaxBadge` → `MaxBadge`.
- 호출 5곳은 이름만 바꿨다. 키(`-decrease/-label/-value/-increase/-max`)·스타일·콜백은 그대로다.
- 기본값은 지금 렌더다. `BaStepperLayout.inline`(라벨이 값 왼쪽), `StepButtonLook.planBuilder`(활성 흰 글자, Material ink).
- 시안 `.stp`와 다른 점은 파라미터로 골라 쓴다.
  - `layout: labelAbove`: 라벨 13.5px w700 #9eb0c2가 위, 값 최소 폭 40.
  - `look: prototype`: 평소 회색, hover 때 흰 글자 + white@.08 원.
- MAX 배지는 시안과 같아 그대로다.
- 이름은 Material `Stepper`와 겹치지 않게 `BaStepper`로 했다(워크플로 표의 `Stepper`).

### 갤러리

- 새 파일 `gallery/ui_kit_controls_section.dart`를 FE2-a 타일 아래에 붙였다.
- `ui_kit_gallery_page.dart`는 임시 `_TileTitle`·`_SubHeader`를 지우고 키트 `TileTitle`·`SubHeader`로 바꿨다. 그래서 FE2-a 타일의 룰이 제목 아래 전체 폭으로 내려갔다.
- 배치(가로 좌표 = 시안 x − 40):
  - 1줄(250): W-Layout 첫 줄 4타일 — 제목 3단계, 칩·세그먼트·버튼, 단계 태그, 변경 강조 + 조절.
  - 2줄(250): W-Filter 첫 줄 3타일 — 토글 칩, 타입 칩, 적용 중 필터.
  - 3줄(330): 레일 버튼, 스위치·스테퍼·MAX, 필터 버튼. W-Filter 둘째 줄의 범위 슬라이더·성급 범위는 FE3-d 범위라 그 자리에 레일 버튼과 스위치·스테퍼를 두고, 필터 버튼은 시안과 같은 오른쪽 끝에 둔다.
  - 4줄(480): 상태 견본. 컨트롤 13종 × 기본 · hover(고정) · 선택·켜짐 · 비활성. 시안 CSS에 규칙이 없는 칸은 "—"다.
- 갤러리의 견본 컨트롤은 실제로 반응한다(세그먼트 선택, 칩 토글, × 빼기, 스위치, 스테퍼, ▲▼).

### 테스트 (`frontend/test/kit/`, 28건 추가 → 예상 484 + golden 17)

| 파일 | 건수 | 확인 내용 |
|---|---|---|
| `ba_chip_test.dart` | 4 | tone 6색 배경·글자·r7·높이 24, × 탭·키보드, × 없음, 단계 태그 색·선택 채움 |
| `skew_controls_test.dart` | 7 | 세그먼트 on/off 바탕·테두리·글자·높이·탭·키보드·비활성, 토글 칩 on/off·개수·굵기, 타입 칩 막대 색·위치, 필터 버튼 "필터"/"필터 · 3"·색·탭·키보드, 스위치 40×22·손잡이 21·켜짐 색·키보드·비활성 |
| `stepper_test.dart` | 6 | 요소 빌더 키·콜백·최소/최대 비활성, `*`·전파 바탕, MAX 배지 색, 시안 배치(라벨 위·값 폭 40), 시안 스텝 버튼 hover, ▲▼ 콜백·hover·비활성·18×13 |
| `buttons_test.dart` | 5 | tonal 색표, tonal 크기·hover·탭·키보드·비활성, 레일 버튼 변형 색, 레일 버튼 사선 hit test·안쪽 여백, 그룹 폭(레일 따라 감소, 시안 334.7) |
| `titles_test.dart` | 4 | 패널 제목 막대 7×22·19px·캡 46·간격, 타일 제목 6×18·16px·캡 40·칩 오른쪽 끝, 소제목 점·글꼴, 키-값 11px·간격 3 |
| `ui_kit_gallery_controls_test.dart` | 2 | FE2-b 타일 11개가 넘침 없이 그려짐, 견본 컨트롤 반응(세그먼트·토글 칩·× 키보드·스위치·▲▼) |

공용 도우미 `kit_test_utils.dart`는 테스트 파일이 아니다(`_test.dart`가 아님). 레이아웃을 거친 위치·크기는 `closeTo`로 비교하고, 같은 식을 같은 순서로 계산한 값만 정확 비교했다(오케스트레이터 로그 00:41).

### 처리한 FD

- **FD-005**: 선택·적용 중은 모두 핑크다(세그먼트 on, 토글 칩 on, 필터 적용 중, 레일 sel-pink). sel-blue는 시안 클래스 그대로 둔다.
- **FD-008·FD-010**: 경기천년제목을 소제목 8px·MAX 7.5px에도 쓴다. 시안 전용 크기 토큰(12.5·10.5·11.5·13.5·19·16.5·25.2·8)을 그대로 쓴다.
- **FD-009**: 새 코드의 시안 w800(단계 태그·소제목·시안 스텝 버튼)은 bold(700)로 그렸다. 추출한 요소 빌더 스테퍼는 동작 보존이라 기존 w800을 그대로 둔다.
- **FD-011**: 토글 칩 글자 #dfe7ee는 `AppColors.text`로 그렸다.
- **FD-014**: 시안에 정의만 있고 쓰이지 않는 클래스는 만들지 않았다.
  - `.chip.solid`, `.btn.dng`, `.btn.icon`, `.tonal.cur`, `.tonal.done`.
  - `.viewsel` 등.
- **FD-024**: 타입 칩 막대 색은 `AppColors.type*` 5색이고, 복합장갑 #7a8ea3을 포함한다.
- **FD-012**: 이번 범위에 별 색이 없다(성급 범위는 FE3-d).

### 알려진 시안 차이

1. **"변경 강조 + 조절" 타일**: 바뀐 값 평행사변형 강조 상자(ChangedValue)는 FE2-b 범위가 아니라 만들지 않았다(FE4 계획 만들기). ▲▼만 값 옆에 붙였다.
2. **세그먼트 테두리 위치**: 시안은 CSS `border`(상자 바깥)이지만 키트는 안쪽에 그린다. on일 때 1.5px로 굵어져도 상자 크기는 그대로다(시안은 1px 커진다).
3. **사선 바탕 모서리**: 기울인 둥근 사각형을 r5 Q 곡선 평행사변형으로 근사했다.
4. **시안에 없는 상태**: 비활성 불투명도 .45와 키보드 포커스 파랑 테두리·고리는 워커가 정했다.
5. **아이콘**: 갤러리 tonal·레일 버튼·모달 칩 아이콘은 Material 아이콘이다. 키트가 직접 그리는 ×·깔때기·꺾쇠만 시안 svg path다.
6. **레일 sel 그라데이션**: 버튼 폭 기준 가로 그라데이션이다.
7. **단계 태그 오른쪽 여백**: 시안 span에 `gap:5px`가 있지만 자식이 하나라 영향이 없다.

### 검수표 (mock 모드, 2560×1440 모니터 최대화 = 2560×1392)

갤러리 여는 법: 헤더 개발 버튼 → 개발 상태 패널 "UI Kit 갤러리" → 아래로 스크롤해 "FE2-b 소형 컨트롤 · 제목" 구역으로 간다.

**W-Layout-Widgets 대조**

| 갤러리 타일 | 대조 포인트 |
|---|---|
| 제목 3단계 | 패널 제목: 핑크 막대 7×22, 19px 제목, 오른쪽 회색 칩, 아래 룰 캡 46. 타일 제목: 6×18, 16px, 오른쪽 핑크 칩 "1주", 캡 40. 소제목: 파란 점 5×5 + 10px |
| 칩 · 세그먼트 · 버튼 | 세그먼트 28 높이 11px(1주 on = #3a2a44 + 핑크 1.5px), 칩 6색 순서(정보·강조·충분·주의·위험·보조), tonal 주 버튼 핑크·보조 버튼 #3a4b58, 높이 40 r10 |
| 단계 태그 | 윗줄 @.16 채움 + 같은 색 글자, 아랫줄 원색 채움 + 어두운 글자, "3단계 · 선택" |
| 변경 강조 + 조절 | Lv.90 옆 ▲▼(18×13, hover 핑크). 강조 상자가 없는 것은 위 "알려진 시안 차이" 1 |

**W-Filter-Widgets 대조**

| 갤러리 타일 | 대조 포인트 |
|---|---|
| 토글 칩 | h30, off 회색 테두리·on 핑크 채움 + 1.5px, 개수 10.5px 회색, 문구 "같은 줄 = "또는", 줄끼리 = "그리고"" |
| 타입 칩 | 앞 막대 8×14 사선: 폭발/경장갑 #920008, 관통/중장갑 #bd8901, 신비/특수장갑 #226f9b, 진동/탄력장갑 #9945a8, 복합장갑 #7a8ea3 |
| 적용 중 필터 | 핑크 칩 + × 11px(누르면 빠짐), "24 / 170명" |
| 필터 버튼 | "필터"(회색 테두리) / "필터 · 3"(핑크), 깔때기 14px, 모달 칩 프리셋·초기화·적용(핑크) |

**UI-Elements·기타 대조**

| 갤러리 타일 | 대조 포인트 |
|---|---|
| 레일 버튼 | Scenario-List 왼쪽 버튼 묶음: sel-pink 58 높이 + ghost + pri. 아래로 갈수록 오른쪽 끝이 레일을 따라 줄어든다. 두 번째 묶음은 base·sel-blue·done·tri |
| 스위치 · 스테퍼 · MAX | 스위치 40×22(on 핑크 + 손잡이 #2a1330). 시안 스테퍼(라벨 위, 회색 ±), 전파 EX(파랑 바탕). 요소 빌더 현재 모양(흰 ±, 라벨 왼쪽), MAX 배지 |
| 상태 견본 | hover 칸(tonal #455866·pri #f7c9f4, 레일 ghost rgba(36,52,72,.8), 스텝 원, ▲▼ 핑크), 비활성 .45 |

**요소 빌더(동작 보존, golden `plan-element-builder`)**: 계획 탭 → 계획 만들기 → 단계 카드의 스테퍼·MAX 배지가 이전과 같아야 한다.

### 미검증 항목

1. analyze, 전체 테스트(기존 456 + 새 28), golden 17장 비교. 사용자 PC gate가 필요하다.
2. 실행해 봐야 아는 테스트 기대값:
   - 키보드 Space → `ActivateIntent` 경로.
   - `ensureVisible`이 가로·세로 스크롤을 겹쳐 지나가는지.
   - 갤러리의 시험 글꼴(정사각형) 폭 계산. 레일 버튼 타일은 744 중 720, 상태 견본은 세로 여유가 약 10px이라 빠듯하다.
   - 실패하면 테스트 기대값부터 확인한다. 요소 빌더 렌더는 golden이 판정한다.
3. 갤러리 시각 배치는 사용자 검수가 필요하다.

### 발견 사항

1. **FE2-a 발견 사항 1의 원인(기기 쓰기 도구).** 같은 업로드 경로(`outputs/...`)로 기기에 다시 쓰면, 그 경로에서 전에 올렸던 내용이 써질 수 있다. 이번 0단계에서 재현됐다.
   - status를 고쳐 쓴 직후 다시 읽으니 FE2-a 종료 때 내용(72035 bytes)이었다. 그 사이 FE2-a commit record 절도 잠깐 사라졌다.
   - 새 경로에서 다시 쓰고 재확인해 바로잡았다.
   - 이번 slice부터 기기 쓰기는 매번 새 업로드 경로에서 하고, 쓴 뒤 다시 읽어 바이트 단위로 대조한다.
   - FE2-a 때 lib 파일은 쓴 뒤 대조했고 gate도 통과했으므로 영향이 없다.
2. **오케스트레이터 로그 "00:47 항목"**: 로그 파일에 없다(00:41만 있다).

### 사용자 실행 순서

```powershell
# ① gate. GREEN이어야 한다. golden 차이가 나오면 멈추고 오케스트레이터 검토(이번 slice는 golden을 갱신하지 않는다)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

①이 GREEN이면:

```powershell
# ② 커밋 미리보기 → ③ 커밋
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe2b -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe2b
```

### 다음 행동

1. 사용자: ①. GREEN이면 ②·③을 실행하고, RED면 `summary.txt`와 `failures/`를 오케스트레이터에 넘긴다.
2. 다음 slice: FE2-c 오버레이(`InfoPopover`, `AnchoredFlyout`, `BaModal`).

### FE2-b commit record (2026-10-07 09:03, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261007_090015\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none
