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

**FE3-c 완료.** 결과(오케스트레이터 로그 2026-10-07 13:38·13:49, 아래 FE3-c commit record):
- gate ① RED: analyze info 1건(`student_page.dart` use_null_aware_elements, 오케스트레이터가 `?catalogById[id]`로 고침)과 golden 5장(학생 3장 + 배지 글자 때문에 계획 2장, status 예상과 일치). 나머지 13장 차이 0. 오케스트레이터 검토 승인 → `-UpdateGoldens` → gate `20261007_134501` GREEN(golden 18).
- 커밋 `b7bbfcce`(FE3-c, 17파일).
- 오케스트레이터 후속(13:49) → FE3-d에서 처리한다:
  - S4 적용 필터 칩 모양을 시안(r5·padding 9·inset 테두리)에 맞추는 `BaChip` 변형.
  - `+n` 칩을 누르면 필터 모달이 열린다.
  - 결정: 계정(프로필) 전환 때 `RecentStudents`를 비운다.

**진행 중: FE3-d(1) 필터 모달 부품, 시작 커밋 `8209e2601b9eeabab4ecf1019d20996fdb17ea34`. gate `20261007_150318` RED → 수정 완료(아래 "FE3-d1 gate RED 수정"), 사용자 ① 재실행 대기.**
- FE3-d를 d1(부품·모델, 화면 변화 없음)과 d2(모달 화면 연결, 시각 변경)로 나눈다. 계획은 아래 "FE3-d 착수 기록"에 적는다.

### 커밋 기록

| slice | 커밋 | 내용 | gate |
|---|---|---|---|
| FE0-base | `36702c28` | 개편 전 프론트 미커밋 작업을 원래 내용 그대로 기준선으로 커밋(사용자 승인) | — |
| FE1-a | `54ed8086` | 디자인 토큰 추가, 같은 값 리터럴 교체(동작 보존) | 사용자 실행 analyze·test 통과(2026-10-06 21:32 보고) |
| FE1-g | `8e95d946`(golden PNG 17장), `1ac37eeb`(테스트·`fe_gate.ps1`·`fe_commit.ps1`) | golden 기준선 + gate | `debug/frontend_gate/20261006_224319` GREEN |
| FE1-b | `d5f87b7b` | 80° 기하 공용 API, 인라인 105/108곳 교체(동작 보존) | `debug/frontend_gate/20261006_231705` GREEN |
| FE1-c | `99583757` | 공용 `SectionSurface`(surface@.76, 무블러·무테, lifted shadow 4층), golden 6장 갱신(시각 변경) | ① `20261006_233307` RED(golden 6, 예상 일치) → ③ `20261006_233605` GREEN(424 + golden 17) |
| FE2-a | `97c568b6` | 공용 키트: 사선 스크롤바·포그 파라미터·`DiagonalScrollViewport`·`DiagonalRow`·UI Kit 갤러리, private 스크롤바 4종 교체(동작 보존) | `20261007_003201` RED(테스트 기대값 1ulp, 오케스트레이터 수정) → `20261007_004310` GREEN(456 + golden 17) |
| FE2-b | `859c554a` | 소형 컨트롤·제목 키트(칩·단계 태그·세그먼트·토글 칩·타입 칩·필터 버튼·스위치·미세 조절·tonal·레일 버튼·제목 4종), 요소 빌더 스테퍼 추출(동작 보존), 갤러리 FE2-b 구역 | `20261007_090015` GREEN(301 + 155 + 프로세스 28 + golden 17) |
| FE2-c | `bb1e3478` | 오버레이 키트(`InfoPopover`·`AnchoredFlyout`+프리셋·FD-090 부족 재화 2종·`BaModal` 스크림 4종), 갤러리 FE2-c 구역 | `20261007_102114` GREEN(294 + 194 + 프로세스 28 + golden 17) |
| FE2-d | `1f65b64a` | 이미지·차트 원자 키트(`ItemIconTile`·`ItemTile`·`PortraitStrip`·`SkewBar`·`KpiTile`·차트 원자·빗금·`GameAssets`), `PlanInventoryCoverageBar`를 `SkewBar`로 흡수, 계획 위젯 asset 상수 → `GameAssets`(동작 보존), 갤러리 FE2-d 구역 | `20261007_111210` GREEN(295 + 218 + 프로세스 28 + golden 17) |
| FE3-a | `620a98ee` | DE 학생 카드·그리드: 오른쪽 위 속성 글자 칩(축약 라벨, 80° 계단), 이름 카드 밖(미보유 흐림), 배지 왼쪽 80° 변 채워 쌓기, 행 피치 카드 + 이름 줄, 복합장갑 `typeComposite`, golden 3장 갱신(시각 변경) | ① RED(golden 3, 예상 일치) → `20261007_121200` GREEN(golden 17) |
| FE3-b | `809d903b` | 인연 B 게이지(목표 빗금·점선·→N, 목표 = 활성 계획 문서의 마지막 단계 `bond_rank`, 조회 경계 한 곳), 학생 golden fixture 7명·students-detail 수정·새 장면 students-grid-name-off | ① RED(golden 3, 예상 일치) → `20261007_125410` GREEN(golden 18) |
| FE3-c | `b7bbfcce` | S4 확장(결과 수 줄·적용 필터 칩 × / 모두 지우기 / 범위 조건 칩·`+n`·최근 본 학생 6명), 필터 상태를 페이지 `StudentFilterController`로 올림, 앱 셸 `RecentStudents`, 상태 배지 글꼴 Pretendard 명시, golden 학생 10명 두 줄, golden 5장 갱신(시각 변경) | ① RED(analyze info 1 오케스트레이터 수정, golden 5 예상 일치) → `20261007_134501` GREEN(golden 18) |

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

## FE2-c 착수 기록 (2026-10-07)

- 범위: 워크플로 FE2-c 행 그대로. 대상은 `InfoPopover`, `AnchoredFlyout`(+ 페이즈·시나리오·통계 점·부족 재화 2종 프리셋), `BaModal`(스크림 프리셋 4종)이다. `OverlayPortal` 기반이다(FD-021 (a)).
- 시작 커밋: `fd791947e5c75d098fc32da0f818c3f960b9f0e7`.
- 막힘 요약: FE2-c를 막는 `열림` FD는 없다.
- 동작 보존: 기존 화면은 바꾸지 않는다. golden 17장 차이 0이 완료 조건이고, 새 golden 장면은 추가하지 않는다.
- 사본: 고칠 기존 파일마다 착수 전 사본을 `debug/frontend_fe2c/pre/<v7 기준 경로>`에 둔다.
- 기기 쓰기: 매번 새 업로드 경로에서 쓰고, 쓴 뒤 다시 읽어 바이트로 대조한다.

## FE2-c 종료 기록 (2026-10-07, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없어 analyze·테스트·golden을 돌리지 못했다. 통과를 주장하지 않는다.
- FE2-c1·c2로 나누지 않고 한 번에 했다(InfoPopover·BaModal·AnchoredFlyout·프리셋 모두).
- 쓴 API는 GitHub에서 받은 Flutter 3.44.0 소스(태그 `3.44.0`)와 하나씩 대조했다. lint 규칙 목록도 lints·flutter_lints 저장소에서 확인했다.
- 별도 검토 에이전트가 새 코드·테스트를 3.44.0 소스와 대조해 읽었다. 컴파일·lint·테스트 실패 요인은 찾지 못했다고 보고했다. 위치 기대값도 모두 다시 계산해 맞았다.
- 검토 지적 중 고친 것:
  - 패널이 닫힐 때 패널 hover 상태를 지운다(MouseRegion은 사라질 때 onExit를 부르지 않는다).
  - Esc 처리기가 두 번 등록되지 않게 했다. 맨 위가 아닌 라우트의 오버레이는 Esc로 닫지 않는다.
  - `BaModal`이 빌드 중에 열고 닫지 않게 했다(컨트롤러 교체는 프레임 뒤에 반영).
  - 열린 채로 그룹을 바꾸면 새 그룹의 열린 것을 닫는다.
  - 트리거 강조는 키보드 포커스 표시 모드에서만 포커스로 켠다(마우스로 닫은 뒤 핑크 링이 남지 않게).

### 공용 키트 (`frontend/lib/ui/kit/`, 새 파일)

| 파일 | 내용 |
|---|---|
| `kit_overlay.dart` | 공통 바탕 `KitOverlayAnchor`(`OverlayPortal.overlayChildLayoutBuilder`, 매 프레임 트리거를 따라감). 위치 규칙 `KitOverlayPlacement`(below/right/left, 시안 CSS 값)와 순수 함수 `layoutKitOverlay`(섹션 경계 보정, 꼬리 위치). `KitOverlayBounds`(섹션 경계), `KitOverlayGroup`(한 번에 하나), `KitOverlayEscape`(Esc, 가장 나중 것 하나), `KitOverlayPanel`(#0d151f + 1px 링 + 그림자), `KitOverlayTail`(11×11 45°) |
| `info_popover.dart` | `InfoPopover`: (i) 24px 원(기본 #71c7f4@.12 / 열림·hover·포커스 #f2b3ef@.24), 팝오버 r9·안쪽 13 15 14·폭 330(견본 300), 제목 4×13 사선 막대 + 13.5px, 강조 #f7c9f4, 목록 왼쪽 16·간격 3. `.pop.l`/`.pop.r`(바깥 7, 꼬리 14), `auto` 정렬 |
| `anchored_flyout.dart` | `AnchoredFlyout` + `FlyoutPreset`(r 420 · l 420 · dn 380 · dl 540 · 페이즈 470 · 시나리오 500 · 통계 점). 트리거 링 `FlyoutTriggerRing`(r8 안쪽 1.5 @.7 / 사선 path @.75·@.8 2px / `.lc` #f2b3ef 1.5 + 채움 @.05 / 원 바깥 2px @.85). 행 `FlyoutRow`(r7 white@.035), `FlyoutHeader`·`FlyoutFooter`·`FlyoutLink`·`FlyoutDot` |
| `shortage_flyout.dart` | FD-090 프리셋 2종: `GroupedShortageFlyout`(분야별 그룹, 시나리오 `.shp`) · `ShortageBreakdownFlyout`(부족량·단계별 seg, Flow-4 `.fly`). 자료형 `ShortageItem`·`ShortageUse`·`ShortageGroup` |
| `ba_modal.dart` | `BaModal` + `BaModalController`. 스크림 `BaScrim` 4종(FD-013): filter .8+blur2 · scan .72+blur2 · excel rgba(5,9,14,.62) · anchored .35. 패널 `BaModalPanel.dialog`(#0d151f r12, 족보 전체) / `.sheet`(#0f1822 r14, 엑셀) |

공통 동작:
- 열기: 마우스 올림(트리거·패널, 벗어난 뒤 150ms 기다림) · 키보드 포커스 · 누르기/Enter(고정).
- 닫기: Esc · 바깥 누르기 · 고정된 것 다시 누르기 · 같은 그룹의 다른 것이 열릴 때. 닫은 뒤에는 새로 마우스를 올리거나 포커스를 새로 얻기 전까지 다시 열지 않는다.
- 포커스: 플라이아웃은 눌러 열면 패널로 포커스를 옮기고 닫을 때 트리거로 돌려준다. (i)는 포커스를 버튼에 둔다. 모달은 열 때 패널로, 닫을 때 연 자리로 돌려준다.
- 애니메이션은 없다(시안은 display 전환).

### 바꾼 파일

- `frontend/lib/ui/kit/gallery/ui_kit_gallery_page.dart`: FE2-c 제목과 `UiKitOverlaysSection`을 FE2-b 구역 아래에 붙였다. 사본은 `debug/frontend_fe2c/pre/frontend/lib/ui/kit/gallery/ui_kit_gallery_page.dart`.
- 기존 화면 파일은 건드리지 않았다. 기존 `Tooltip`을 (i)로 옮기는 일(FD-020)은 각 탭 slice 몫이다. 스캐너 소유·동결·택틱 소유 파일도 건드리지 않았다.

### 갤러리 (`gallery/ui_kit_overlays_section.dart`, 새 파일)

- 1줄: W-Info-Popover 보드(1160×400, 시안 좌표 그대로, 테두리만 갤러리용) · 모달 스크림 프리셋 4종 버튼.
- 2줄: W-Layout-Widgets "팝오버 (열린 상태)" 줄. 가로 = 시안 x − 40, 세로 = 시안 y − 852. 부족 재화 플라이아웃(FD-090 부족량·단계별) · 페이즈 팝오버 · (i) "위험도"(오른쪽 정렬).
- 3줄: 나머지 프리셋(닫힌 채): 시나리오 분야별 그룹(Scenario-Compare 값) · 통계 점(Stats-Growth "밀레니엄") · `.fly.dn`(Inventory-Analysis "밀레니엄 · 계획 학생 5명") · `.fly.dl` 사선 카드(Tactical "A 유저 · 23위").
- 시안 `.open` 견본 5개는 처음부터 열려 있다. 각자 다른 그룹이라 함께 열린다. 바깥을 누르면 닫히므로 "열린 견본 다시 열기" 버튼으로 되살린다.
- 문구는 시안 그대로이고 값은 시안 예시 값의 정적 fixture다.

### 테스트 (`frontend/test/kit/`, 32건 추가 → 예상 516 + golden 17)

| 파일 | 건수 | 확인 내용 |
|---|---|---|
| `kit_overlay_test.dart` | 7 | `.pop.l`/`.pop.r` 위치·꼬리, 섹션 경계 보정(오른쪽 끝 왼쪽 정렬·왼쪽 끝 오른쪽 정렬), auto 정렬, 섹션보다 넓은 패널, 옆 열림 세로 보정·꼬리, CSS blur 환산 |
| `info_popover_test.dart` | 8 | 누르기 고정/해제, hover 열림·150ms 뒤 닫힘·트리거→패널 이동 유지, Tab 포커스 열림·Enter 고정·Esc 닫힘·다시 포커스 열림, 바깥 누르기 닫힘(패널 안은 유지), 한 그룹 하나·다른 그룹 함께, 좌/우 정렬 위치·꼬리(closeTo), 섹션 경계 보정·auto, 버튼 24·패널 r9·안쪽·링·제목 글자·접근성 이름 |
| `anchored_flyout_test.dart` | 8 | 누르기 열림 → 패널 포커스 → Esc 닫힘 → 트리거 포커스 복귀(다시 안 열림), Tab 열림·Enter 포커스 이동·바깥 누르기 복귀, hover 링·패널 버튼 누르기, r/dn/dl 위치, 페이즈·시나리오·통계 점 위치·꼬리, 링 값, FD-090 seg 전환(부족량 2행 → 단계별 3행), 분야별 그룹 행·개수·칩 |
| `ba_modal_test.dart` | 5 | 스크림 4종 RGB·알파·blur(서로 다름), 열면 프리셋 색·blur 있는 것만 BackdropFilter, 포커스 이동·Esc 닫힘·복귀·스크림 누르기 닫힘(패널 안은 유지), barrierDismissible false, 패널 프리셋 |
| `ui_kit_gallery_overlays_test.dart` | 4 | FE2-c 타일 4개 넘침 없음·`.open` 견본 5개 열림, 닫힌 견본 누르기 열림·같은 그룹 하나만, 다시 열기 버튼, 모달 버튼 4종 |

OverlayPortal을 쓰는 테스트는 pumpAndSettle 대신 필요한 만큼 pump한다(포커스 이동은 프레임 뒤 콜백이라 pump 두 번). 레이아웃을 거친 위치는 `closeTo`로 비교한다.

### 처리한 FD

- **FD-013**: 스크림 알파는 artboard 값 4종 프리셋으로 둔다. 통일하지 않는다. 엑셀은 시안 그대로 rgba(5,9,14,.62)다.
- **FD-019**: 모달·앵커 팝업·부유 패널은 "부유 섹션 금지·모든 섹션 사선"의 예외다. 키트 패널은 둥근 사각형이다. 필터·홈 스캔·계정 추가의 사선 모달 패널은 각 slice가 `BaModal.builder`에서 그린다. 문서(§1.1·§1.2) 갱신은 이미 FD-019 확정 때 반영 대상으로 적혀 있어 이번에 손대지 않았다.
- **FD-020**: (i) 위젯을 만들었다. 기존 화면의 안내 문장·Tooltip 이동은 각 탭 slice 몫이다.
- **FD-021**: (a) `OverlayPortal` 기반이다. 탭 고정·리치 내용·좌/우 정렬·섹션 경계 보정을 한다.
- **FD-090**: `AnchoredFlyout` 위 프리셋 2종(`GroupedShortageFlyout` / `ShortageBreakdownFlyout`)이다. 실제 데이터 연결은 FE5-b 등 각 slice 몫이다.

### 알려진 시안 차이

1. **"단계별" 보기**: 시안은 seg만 있고 그림이 없다. 단계마다 단계 태그 + "n종" 머리 줄을 두고, 그 단계에 쓰는 항목만 그 단계 학생과 함께 보인다(워커 재량).
2. **hover 닫힘 지연 150ms**: 시안(CSS)은 틈을 지나면 바로 닫힌다. 패널 안 버튼까지 갈 수 있게 지연을 두었다.
3. **`.fly.l`**: 시안에 없다. `.fly`를 좌우로 뒤집은 값(왼쪽 14, 위 −12, 폭 420)이다.
4. **패널이 스크롤 영역에 잘리지 않는다**: 패널은 앱 오버레이에 그려진다. 트리거가 스크롤되어 앱 바 아래로 가도 패널은 보일 수 있다. 섹션 경계 보정은 섹션 전체 사각형 기준이다. 아래 열림은 위로, 옆 열림은 반대쪽으로 뒤집지 않는다.
5. **모달 포커스 가두기·배경 접근성**: Tab이 패널 밖으로 나갈 수 있고 배경 의미 구조를 막지 않는다. 실제 모달을 옮기는 slice(FE8 등)에서 필요하면 더한다.
6. **Esc 이중 처리 가능성**: `showDialog`처럼 Esc로 닫히는 라우트 안에 팝오버를 열면 Esc 한 번에 팝오버와 다이얼로그가 함께 닫힐 수 있다. 지금 그런 화면은 없다.
7. **아이콘·초상·아이템 이미지**: 갤러리는 이미지 대신 빈 상자·이름 첫 글자다(아이템 아이콘 위젯은 FE2-d 범위). "인벤토리에서 보기" 아이콘은 Material 아이콘이다. 5px 막대 `ShortageBar`·아이콘 자리 `ShortageIconSlot`은 FE2-d의 `SkewBar`·`ItemIconTile`이 나오면 바꾼다.
8. **트리거 견본**: `.fly.dn`(66×28 "밀레니엄")·`.fly.dl`(사선 카드 "A 유저 23위")·시나리오("부족 재화 8종") 트리거는 시안 화면 일부를 대신한 그림이다. 패널은 시안 값이다.
9. **방어 덱 "1승 1패"**: 시안은 칩이 아닌 글자라 회색 굵은 글자로 그렸다.

### 검수표 (mock 모드, 2560×1440 모니터 최대화 = 2560×1392)

갤러리 여는 법: 헤더 개발 버튼 → 개발 상태 패널 "UI Kit 갤러리" → 맨 아래 "FE2-c 오버레이" 구역.

**W-Info-Popover 대조(1줄 왼쪽 보드, 좌표 그대로)**

| 자리 | 대조 포인트 |
|---|---|
| 닫힘 "고른 학생" | (i) 24px 원 파랑 @.12. 마우스를 올리면 분홍 @.24 + 아래로 팝오버(왼쪽 −7, 위 34) "고른 순서대로 **목표 정하기** 탭에 놓입니다." 강조어 #f7c9f4. Tab 포커스·누르기로도 열린다 |
| 열림 · 왼쪽 정렬 "단계 순서" | 폭 300, 제목 앞 분홍 사선 막대, 목록 두 줄(왼쪽 16), 꼬리가 버튼 아래 |
| 열림 · 오른쪽 정렬 "넣을 단계" | 팝오버 오른쪽이 버튼 오른쪽 + 7, 꼬리 오른쪽 14, "**1 · 2 · 3**" 강조 |
| 공통 | 팝오버 #0d151f r9, 외곽 1px #71c7f4@.38, 아래 그림자, 본문 12.5px |

**W-Layout-Widgets "팝오버 (열린 상태)" 대조(2줄)**

| 견본 | 대조 포인트 |
|---|---|
| 부족 재화 플라이아웃 | 요약 줄 380×46 #1b2a3a r8 + 안쪽 핑크 링 1.5. 오른쪽 14, 위 −12, 폭 420, 꼬리 왼쪽 위 26. 머리 "부족 재화 5종" + seg 부족량/단계별(h26 11px), 행 5개(아이콘 47×38, −30·−14·−8·−6·−3 핑크, 막대 5px, 보유/필요, 초상 + 단계 태그), 아래 줄 + "인벤토리에서 보기" h28 |
| 페이즈 팝오버 | 사선 행 530×56 + 핑크 path 외곽 2px. 아래 10, 패널 오른쪽 = 행 오른쪽 − 40, 폭 470, 꼬리 오른쪽 40. 행 4개(−30 위험, −8·−3 주의, 크레딧 "충분"), "앞 페이즈에서 쓰고 남은 양 기준입니다" |
| (i) 위험도 | "부족 위험도 순위" 옆, 오른쪽 정렬 폭 300 |

**프리셋 견본(3줄, 마우스·Tab·누르기로 연다)**

| 견본 | 대조 포인트 |
|---|---|
| 시나리오(.shw) | Scenario-Compare: 패널 500, 왼쪽 −20, 꼬리 left 90. 머리 "부족 재화 8종" + 설명. 분야 엘레프 1종 · 오파츠 2종 · 노트 · BD 2종 · 장비 설계도 3종, 칩(회색·충분·핑크·주의) |
| 통계 점(.sdot) | Stats-Growth: 26px 원을 올리면 바깥 핑크 2px, 패널이 왼쪽 12 · 위 −18, 꼬리 없음, 내용 폭 |
| 아래(.fly.dn) | Inventory-Analysis: 폭 380, 오른쪽 −10, 꼬리 오른쪽 26. "부족 필요량 · BD · 노트" 색 글자, 학생 5행, "계획에서 보기 →" |
| 왼쪽 아래(.fly.dl) | Tactical: 사선 카드 + `.lc` 외곽(분홍 1.5 + 옅은 채움), 폭 540, 꼬리 왼쪽 36. 방어 덱 5행(첫 행 왼쪽 핑크 막대·"현재" 칩, 셋째 행 "?" 3칸), "상대 카드 열기 →" |
| 한 번에 하나 | 3줄 견본 둘을 차례로 열면 앞의 것이 닫힌다 |

**모달(1줄 오른쪽 타일)**: 버튼 4개가 각 스크림으로 연다. 필터·홈 스캔은 배경이 흐리고(blur 2), 엑셀 .62는 더 어둡고 패널 #0f1822, 앵커 .35는 가장 옅다. Esc·스크림 누르기·"닫기"로 닫히고 포커스가 연 버튼으로 돌아온다.

### 미검증 항목

1. analyze, 전체 테스트(기존 484 + 새 32), golden 17장 비교. 사용자 PC gate가 필요하다.
2. 실행해 봐야 아는 테스트 기대값:
   - Tab 첫 포커스가 트리거로 가는지, 포커스 이동이 pump 두 번 안에 끝나는지.
   - hover 테스트(마우스 들어감·나감 순서, 150ms 타이머).
   - Esc가 `HardwareKeyboard` 처리기로 들어오는지.
   - 실패하면 테스트 기대값부터 확인한다. 기존 화면 렌더는 golden이 판정한다.
3. 기존 갤러리 테스트(FE2-a·b)는 같은 페이지에 열린 견본 5개가 생긴 채로 돈다. 넘침·겹침 위험은 검토에서 찾지 못했지만 gate로 확인한다.
4. 갤러리 시각 배치는 사용자 검수가 필요하다.

### 사용자 실행 순서

```powershell
# ① gate. GREEN이어야 한다. golden 차이가 나오면 멈추고 오케스트레이터 검토(이번 slice는 golden을 갱신하지 않는다)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

①이 GREEN이면:

```powershell
# ② 커밋 미리보기 → ③ 커밋
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe2c -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe2c
```

### 다음 행동

1. 사용자: ①. GREEN이면 ②·③을 실행하고, RED면 `summary.txt`와 `failures/`를 오케스트레이터에 넘긴다.
2. 다음 slice: 워크플로 FE2 다음 행(FE2-d).

### FE2-c commit record (2026-10-07 10:26, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261007_102114\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE2-d 착수 기록 (2026-10-07)

- 범위: 워크플로 FE2-d 행 그대로. 대상은 `ItemIconTile`(+ 아이템 타일), `PortraitStrip`, `SkewBar`(`PlanInventoryCoverageBar` 흡수), `KpiTile`, 차트 원자(`StatChartFrame`, 80° 막대, 빗금, 축·기준선, 팔레트, hit-test geometry)다. 차트 라이브러리는 넣지 않는다(FD-023 (a)).
- 함께: FE2-c 임시 `ShortageBar`·`ShortageIconSlot`을 `SkewBar`·`ItemIconTile`로 바꾼다. FD-022 이름 나누기(`ResourceTile`/`WidgetTile`)는 이번에 필요한 것만 한다.
- 범위 밖: 완성 차트 위젯(히스토그램·꺾은선·히트맵·위험도 행 등, H §8 H8)은 FE6·FE7 몫이다.
- 시작 커밋: `bb1e3478ea18bdd04a8a829adbfb6d6ae52fdc80`.
- 동작 보존: 기존 화면 렌더는 바뀌지 않아야 한다. golden 17장 차이 0이 완료 조건이고, 새 golden 장면·게임 이미지 파일은 넣지 않는다.
- 사본: 고칠 기존 파일마다 착수 전 사본을 `debug/frontend_fe2d/pre/<v7 기준 경로>`에 둔다.
- 기기 쓰기: 매번 새 업로드 경로에서 쓰고, 쓴 뒤 다시 읽어 바이트로 대조한다.

## FE2-d 종료 기록 (2026-10-07, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없어 analyze·테스트·golden을 돌리지 못했다. 통과를 주장하지 않는다.
- FE2-d1·d2로 나누지 않고 한 번에 했다(이미지 원자·막대·KPI·차트 원자 모두).
- 쓴 API는 Flutter 3.44.0 소스와 대조했다.
- 별도 검토 에이전트가 새 코드·테스트·바꾼 기존 파일을 사본과 대조해 읽었다. 보고 내용은 이렇다.
  - 바꾼 asset 문자열은 모두 같다.
  - `PlanInventoryCoverageBar`의 그리기 호출이 기존 painter와 같다(NaN·clamp 처리까지).
  - 갤러리 타일은 시험 글꼴로 넘치지 않는다.
- 검토 지적 중 고친 것: Path 좌표는 32비트라 기하 테스트 허용 오차를 1e-4로 넓혔다. CRLF였던 두 파일(`plan_section_layout.dart`, `planning_resource_assets.dart`)의 줄 끝을 CRLF로 되돌렸다.

### 공용 키트 (`frontend/lib/ui/kit/`, 새 파일)

| 파일 | 내용 |
|---|---|
| `game_assets.dart` | `GameAssets`: 아이템 배경 3종, 크레딧, 장비 T10 3종, 아이템 아이콘·장비 아이콘(설계도 `_Piece` 선택)·학교 로고·엘레프·학생 초상 경로. `ItemBackground`(basic·purple·yellow) |
| `skew_bar.dart` | `SkewBar`(`.bar2`, 높이 4~12, 트랙 white@.09, 반경 h/2, 기울임 −10°)와 `SkewBarPainter`, `SkewBarStyle`, `CoverageTone` |
| `hatch.dart` | `paintHatch`·`HatchStyle`·`HatchBox`·`HatchPainter`. 시안 `#hx` 값: 7px 간격 45°, 바탕 rgba(158,176,194,.07), 선 .45 |
| `item_icon_tile.dart` | `ItemIconTile`: `.pt`. 배경 + 아이콘 92% contain, margin 4%는 폭 기준. 크기 42×34·47×38·52×42·74×60과 임의 크기. 그림이 없으면 빈 상자 |
| 〃 | `ItemTile`: 74×74, 수량 `.dsp` 13 + 그림자, 막대 64.9×4(왼쪽 1.5, 위 64, r1, 왼쪽 위 기준 기울임), 선택 = 2px 핑크 링 + 14px 글로우 |
| `portrait_strip.dart` | `PortraitStrip`: 초상 34×28, 간격 4, 최대 n개. `AssetImageGrid` 한 장에 아이템 기본 배경 + 초상 98%를 그린다. 넘치는 수는 "…+n" 사선 칩, 슬롯 폭(시안 246)을 고정할 수 있다. `portraitStripSplit` |
| `kpi_tile.dart` | `KpiTile`: 높이 70, 사선 바탕 r7 #203243 + 안쪽 1px. 기본형은 값 26 + 변화 11(증가 #7fe3bd·계획 #f7c9f4). `KpiTile.compare`는 이전 14 → 화살표 13 → 예상 24 |
| `stat_chart.dart` | `StatChartFrame`(viewBox × 1.25 균일 배율, 누른 자리 → 설계 좌표)·`StatChartPainter`, `skewedBarPath`·`skewedTrackPath`(80°), `paintValueBar`(모름 = 빗금, 0 = 바닥 1px), `StatChartScale`, `paintStatGridLine`(실선·점선), `paintStatLabel`, `StatChartPalette`, `StatChartHitMap` |

과잉 노랑은 시안 견본 값 #ffc66d = `AppColors.warning`으로 정했다(H §2.6 모호점). 계획 무관은 막대가 없다(`ItemTile.tone == null`).

### 바꾼 기존 파일 (모두 동작 보존)

- **`widgets/plan_section_layout.dart`**:
  - `PlanInventoryCoverageBar`의 painter를 `SkewBarPainter` + `SkewBarStyle.planCoverage`(트랙 #4f7090@.2, 기울임 없음, 반경 h/2)로 바꾸고 private `_PlanInventoryCoveragePainter`를 지웠다.
  - 위젯 모양과 키(`plan-inventory-coverage-bar-fill`)는 그대로다.
  - asset 상수·장비 아이콘 문자열은 `GameAssets`로 바꿨다(값 동일).
- **asset 문자열 → `GameAssets`(값 동일)**: `widgets/plan_phase_editor.dart`(배경), `widgets/plan_element_builder.dart`(배경·장비 아이콘), `widgets/plan_student_step_tile.dart`(장비 T10 3종), `widgets/student_section_layout.dart`(장비 아이콘·학교 로고), `models/planning_resource_assets.dart`(재화 아이콘).
- **`kit/shortage_flyout.dart`**:
  - FE2-c 임시 `ShortageIconSlot`·`ShortageBar`를 지우고 `ItemIconTile`·`SkewBar`(평평, 5px)·`ShortagePortrait`(`PortraitStrip` 22×18)로 바꿨다.
  - `ShortageItem.icon`(위젯)은 `iconAsset` + `iconBackground`로, `ShortageUse.portrait`는 `studentId`로 바꿨다.
- **`kit/gallery/ui_kit_overlays_section.dart`**: 견본 아이콘·초상을 실제 그림 경로로 바꿨다(그림이 없으면 빈 상자).
- **`kit/gallery/ui_kit_gallery_page.dart`**: FE2-d 제목과 `UiKitDataSection`을 붙였다.
- **`test/kit/anchored_flyout_test.dart`**: `ShortageBar` 대신 `SkewBar`를 찾는다.
- 사본은 `debug/frontend_fe2d/pre/frontend/...` 10개다. 스캐너 소유(`scan_student_review_workspace.dart`의 장비 아이콘 문자열 포함)·동결·택틱 소유 파일은 건드리지 않았다. 게임 이미지 파일도 넣지 않았다.
- `student_section_layout.dart`의 초상·인연 배경, `bond_rank_portrait.dart`·`student_grid_warmup.dart`·`account_section_cluster.dart`·`title_page.dart`의 초상·스튜디오 사각형 경로는 아이템 아이콘·배경이 아니라 이번에 옮기지 않았다(각 화면 slice에서 `GameAssets`로 옮긴다).

### 갤러리 (`gallery/ui_kit_data_section.dart`, 새 파일)

- 1줄(W-Data 첫 줄, 높이 300, 가로 = 시안 x − 40): KPI 사선 타일 · 전후 비교 / 주요 재화 (숫자형) / 아이템 타일 + 충족 막대.
- 2줄(높이 330): 비율 막대 행 (사선 정렬)(W-Data 둘째 줄 첫 타일) · 차트 원자 견본(막대 6개, 모름 빗금, 0 빈 막대, 평균 점선, 누르면 고르기) · 이미지 원자·막대 견본(아이콘 4크기, 그림 없음, 초상 3명·7명 "…+2", 막대 5상태).
- 타일 안쪽 여백은 시안대로 2 × 80° 컷 + 26이다. 머리는 FE2-b `TileTitle`이고 값은 시안 예시 값이다.
- 완성 위젯(히스토그램·꺾은선·± 막대·히트맵·위험도 행·부족 상위 행·부족 칩 팝업, H §8 H8)은 만들지 않았다(FE6·FE7).

### 테스트 (`frontend/test/kit/`, 25건 추가 → 예상 541 + golden 17)

| 파일 | 건수 | 확인 내용 |
|---|---|---|
| `skew_bar_test.dart` | 8 | 충족 상태 색(과잉 = warning), 채움 폭·clamp, 기울임 기준점(가운데·왼쪽 위), 모름 = 빗금 / 0 = 빈 트랙, 비율 눈금 25/50/75, planCoverage 그리기 호출이 기존 painter와 같음, `PlanInventoryCoverageBar` 키·크기·의미, 위젯 크기 |
| `item_icon_tile_test.dart` | 6 | asset 경로가 기존 문자열과 같음(계획 상수·`planningResourceIconAsset` 포함), 4크기·아이콘 상자 92%, 그림 없음 → 빈 상자·예외 없음(모든 읽기가 실패하는 asset 묶음), 아이템 타일 수량·막대·선택 링·계획 무관, "…+n" 계산, 초상 줄 칸·칩·슬롯 폭 |
| `kpi_tile_test.dart` | 2 | 기본형 라벨 9·값 26·변화 색(증가·계획)·바탕, 전후형 14 → 화살표 → 24 순서와 간격 |
| `stat_chart_test.dart` | 7 | 값 축 변환·역변환, 80° 막대 기하·contains, 틀 크기 viewBox × 1.25·누른 자리 → 설계 좌표(closeTo), hit map 위쪽 우선, 견본 막대 칸 hit, 모름(빗금)·0(바닥만)·값(채움) 구분, 팔레트 |
| `ui_kit_gallery_data_test.dart` | 2 | FE2-d 타일 6개 넘침 없음·KPI 6·아이템 타일 4·계획 무관 막대 없음·"…+2"·모름/0 막대·비율 행 레일 28.2, 차트 견본 누르기로 고르기 |

`anchored_flyout_test.dart`는 건수 그대로(`SkewBar` 확인으로 바꿈).

### 처리한 FD

- **FD-022**: 위젯 카드는 기존 `WidgetTile`(FE2-a)이다. 재화 타일 `ResourceTile`(UI-Elements 300×107)은 이번 범위에서 쓰지 않아 이름만 남겨 둔다(FE6 인벤토리에서 만든다). 갤러리 "주요 재화" 행은 원자 조합 견본(`_ResourceAmountRow`, 갤러리 private)이다.
- **FD-023**: (a) CustomPainter 원자다. 차트 패키지를 넣지 않았다(`pubspec.yaml` 변경 없음).
- **FD-012**: 이번 원자에 별 색이 없다. 그대로 둔다.
- **FD-024**: 타입 색 토큰은 이번 원자에서 쓰지 않는다.
- **데이터 의미(불변식)**: 모르는 값은 0이 아니라 빗금이다(`SkewBar(fraction: null)`, `paintValueBar(value: null)`). 0은 빈 트랙·바닥선이다.

### 알려진 시안 차이

1. **KPI 전후형 세로 정렬**: 시안은 값 줄을 baseline으로 맞추고 화살표만 가운데다. 키트는 세 요소를 가운데 정렬했다(14px와 24px 글자 바닥이 몇 px 다르다).
2. **경기천년제목 w800**: 값 글자는 FD-009대로 굵기 700이다.
3. **아이템 배경 3종의 등급 대응**: 시안 blob 3개(`6aa789`·`869728`·`362f0a`)를 기본·보라·노랑 그림으로 대응했다. 어느 등급이 어느 색인지는 각 화면 slice가 데이터에 맞춘다.
4. **초상 바탕**: 시안 초상 뒤 사각형은 아이템 기본 배경과 같은 그림이라 `GameAssets.portraitBackground = itemBackgroundBasic`이다. 계정·타이틀의 큰 초상은 스튜디오 사각형을 그대로 쓴다.
5. **빗금 선 폭**: 시안 패턴은 칸 가장자리 2px 선이 칸에 잘려 1px로 보인다. 키트는 1px 선으로 그린다.
6. **차트 원자 견본**: 시안 W-Data에 같은 견본이 없다. 갤러리용 조합이다(막대·빗금·평균선·눈금은 Stats 시안 값).
7. **갤러리 아이콘**: 견본 아이콘(기술 노트 밀레니엄 최상급, 전술 교육 BD, 장비 설계도, 네브라)은 시안과 같은 종류의 그림을 골랐다. 그림이 PC에 없으면 빈 상자다.
8. **"엘리그마" 아이콘**: 저장소에 그림이 없어 시안처럼 이름 글자(`#3d4d5c`)로 그린다.

### 검수표 (mock 모드, 2560×1440 모니터 최대화 = 2560×1392)

갤러리 여는 법: 헤더 개발 버튼 → 개발 상태 패널 "UI Kit 갤러리" → 맨 아래 "FE2-d 이미지·차트 원자" 구역.

**W-Data-Widgets 대조**

| 갤러리 타일 | 대조 포인트 |
|---|---|
| KPI 사선 타일 · 전후 비교 | 윗줄 3칸(높이 70, 사선 #203243 r7 + 테두리): 보유 학생 128 "/ 170 · +2"(초록) · 평균 육성도 63.4% "+1.2" · 계획 등록 9명 "+7"(핑크). 아랫줄: 72% → 78%, 14종 → 12종, 0 → 2개(회색 14 → 핑크 화살표 → 초록 24) |
| 주요 재화 (숫자형) | 행 2개(사선 바탕 + 테두리, 안쪽 10 18): 크레딧 아이콘 42×34 · "98.4M" · "/ 필요 261.5M" · 오른쪽 핑크 "−163.1M" · 6px 기운 막대 38%. 엘리그마는 이름 글자 아이콘, 45% |
| 아이템 타일 + 충족 막대 | 74×74 네 개: 부족(핑크 링 + 글로우, 수량 12, 막대 28% 핑크) · 충분(88, 파랑 100%) · 과잉(140, 노랑 100%) · 계획 무관(0, 막대 없음). 막대는 타일 밑변 길이(64.9)·기울기 |
| 비율 막대 행 (사선 정렬) | 5행(높이 32, 간격 8): 이름 70 · 트랙 12 r3 기울임 · 25/50/75 눈금 · 값 14. 첫 행이 오른쪽으로 28.2 들어가고 아래로 갈수록 왼쪽으로 나온다(80° 레일) |

**원자 견본(시안에 없는 갤러리 조합)**

| 견본 | 대조 포인트 |
|---|---|
| 차트 원자 | 설계 232×96 → 화면 290×120(1.25배). 80° 막대(위가 오른쪽으로 기움), 셋째 막대 "모름" = 회색 빗금, 넷째 "0" = 바닥선만, 핑크 평균 점선 63%, 막대를 누르면 핑크로 바뀐다 |
| 이미지 원자 · 막대 | 아이콘 42·47·52·74(노랑 배경 + 92% 아이콘), 그림 없음 = 짙은 빈 상자, 초상 3명 / 7명 → 5명 + "…+2" 사선 칩(슬롯 246), 막대 부족·충분·과잉·모름(빗금)·0(빈 트랙), 빗금 견본 상자 |

**계획 탭(동작 보존, golden)**: 계획 → 전체 보기의 재화 확보율 막대와 계획 화면 아이콘·배경이 이전과 같아야 한다(golden diff 0).

### 미검증 항목

1. analyze, 전체 테스트(기존 516 + 새 25), golden 17장 비교. 사용자 PC gate가 필요하다.
2. 실행해 봐야 아는 테스트 기대값:
   - `paints` 패턴(기울임 막대의 save·translate·transform 순서).
   - 그림 없음 테스트(실패하는 asset 묶음 → errorBuilder가 pump 두 번 안에 오는지).
   - 갤러리 시험 글꼴 폭. 검토 계산상 가장 빠듯한 곳은 이미지 원자 1줄(747 / 870.85)과 "…+2" 칩 슬롯(242 / 246)이다.
   - 실패하면 테스트 기대값부터 확인한다. 기존 화면 렌더는 golden이 판정한다.
3. 갤러리 시각 배치와 실제 그림(아이템·초상)은 사용자 검수가 필요하다.

### 사용자 실행 순서

```powershell
# ① gate. GREEN이어야 한다. golden 차이가 나오면 멈추고 오케스트레이터 검토(이번 slice는 golden을 갱신하지 않는다)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

①이 GREEN이면:

```powershell
# ② 커밋 미리보기 → ③ 커밋 → ④ 개편 문서 커밋
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe2d -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe2d
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesign-docs
```

### 다음 행동

1. 사용자: ①. GREEN이면 ②·③·④를 실행하고, RED면 `summary.txt`와 `failures/`를 오케스트레이터에 넘긴다.
2. FE2는 이것으로 끝난다. 다음은 워크플로 Lane A의 FE3(학생 탭)이다.

### FE2-d commit record (2026-10-07 11:16, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261007_111210\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE3-a 착수 기록 (2026-10-07)

- 범위: 워크플로 FE3-a 행 그대로. 속성 글자 칩(오른쪽 위, 80° 계단, 방어 축약 라벨 — FD-047), 이름 카드 밖(미보유 흐림, E의 2색 밑줄 없음 — FD-043), 상태 배지 왼쪽 80° 변 채워 쌓기(UNOWNED → PLAN → JP — FD-044), 행 피치 카드 + 이름 줄 ≈191.3·카드 중심 기준 행 이동(FD-045), 이름 끄면 이름 줄 접기(FD-046 (a)), 리스트 보기 현행 유지(FD-048), 복합장갑 색 `#228b22` → `AppColors.typeComposite`(FD-024).
- 범위 밖: 인연 게이지(FE3-b), S4 확장(FE3-c), 필터 모달(FE3-d), 폼 교대(FE3-e).
- 시작 커밋: `e130110d7b71f6c1bff729396274cbe387e5cdf0`.
- 막힘: 대장 막힘 요약에서 FE3-a를 막는 열림 FD 없음.
- 방어 칩 라벨: 프롬프트의 "특장" 대신 시안·FD-047의 "특수"를 쓴다(2026-10-07 사용자 확인).
- 시각 변경 slice: golden 갱신은 오케스트레이터 검토 뒤 사용자가 `fe_gate.ps1 -UpdateGoldens`로 한다. golden PNG를 직접 만들거나 지우지 않는다.
- 사본: 고칠 기존 파일마다 착수 전 사본을 `debug/frontend_fe3a/pre/<v7 기준 경로>`에 둔다.
- 기기 쓰기: 매번 새 업로드 경로에서 쓰고, 쓴 뒤 다시 읽어 바이트로 대조한다.

## FE3-a 종료 기록 (2026-10-07, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없어 analyze·테스트·golden을 돌리지 못했다. 통과를 주장하지 않는다.
- 쓴 API는 Flutter 3.44.0 소스(sparse clone)와 대조했다. lint 규칙은 flutter_lints 6.0.0 목록으로 확인했다.
- 별도 검토 에이전트가 바뀐 파일을 사본과 대조해 정적으로 읽었다. 보고 내용은 이렇다.
  - 컴파일 오류·analyze 지적 없음. 지운 심볼을 참조하는 곳이 lib·test에 남지 않았다.
  - 새 테스트의 수치 기대값을 Python으로 다시 계산해 모두 맞았다(칩·배지·이름·행 피치·행 이동·hit target).
  - `paints` 패턴이 painter의 실제 호출 순서와 맞는다.
- 시안 값은 `dc_outline.py`와 사본 원문(칩 span 스타일)에서 읽었다: Student(카드 206.87×167.47), W-Card-States(200×161.9), W-Card-Grid-DE(200.80×162.55), W-Card-Variants D·E.

### 바꾼 것

- **`frontend/lib/ui/widgets/student_section_layout.dart`**
  - **그리드 기하(FD-045, FD-046 (a))**: `StudentDiagonalGrid`의 셀을 정사각형에서 카드(폭 × 204/252)로 바꿨다. 행 사이에 이름 줄 20(3 + 16 + 1)과 3.84를 둔다. 그래서 이미지 grid·overlay의 `rowGap` = 23.84이고 아래 padding = 8 + 20이다. 행 가로 이동은 카드 중심 기준이다. 이름을 끄면 이름 줄을 접는다(`rowGap` 3.84, 아래 padding 8). 공용 함수: `studentGridRowGeometry`·`StudentGridRowGeometry`, `studentGridRowHorizontalOffset`. 이미지 grid·overlay painter·hit target이 같은 기하를 쓴다. 기준 viewport에서 행 피치는 카드 + 23.84 ≈ 190.7이다(카드 폭 206.12 — 시안 206.87과의 차이는 아래 알려진 시안 차이 1).
  - **카드 overlay(FD-043)**: 카드 안 하단 16% 정보 띠(3% 속성 띠 + 13% 회색 이름 띠)를 지웠다. 대신 아래를 그린다.
    - 오른쪽 위 속성 글자 칩: `paintStudentAttributeChips`, `studentAttributeChipBox`, `studentAttributeChips`. 공격 → 방어 순서이고, 칩 높이 max(14, 카드 높이 × .11), 위 4, 칩 사이 3, 글자 높이 × .55 w800, 여백 × .45, r3, −10° 기울임(키트 `skewBoxPath`), 그림자 0 1 2 @.4다. 칩 상자 오른쪽 끝은 칩 밑변 높이에서 카드 오른쪽 80° 변보다 6px 안쪽이라 두 칩이 80° 계단을 이룬다.
    - 미보유 암전: 칩까지 덮는다.
    - 카드 밖 이름 줄: `studentGridNameRect`, `paintStudentGridName`. 카드 아래 3, 높이 16, 폭 = 카드 하단 변, Pretendard 13 w700, 보유 `AppColors.text` · 미보유 `AppColors.textMuted`(흐림), 말줄임.
    - E안의 2색 밑줄은 그리지 않는다.
  - **배지(FD-044)**: `studentGridStatusBadgeRects`(고정 3슬롯, JP 우상단)를 `studentGridStatusBadgeStack`·`studentGridStatusBadgeSlotRect`·`StudentGridStatusBadge`로 바꿨다. 있는 배지만 UNOWNED → PLAN → JP 순서로 왼쪽 80° 변을 따라 위에서부터 채운다. 크기·pill 스타일은 그대로다.
  - **라벨(FD-047)**: 카드 칩 라벨 맵 `studentAttackChipLabels`(폭발/관통/신비/진동/화학), `studentDefenseChipLabels`(경장/중장/특수/탄력/복합)를 새로 뒀다. 필터 라벨 `studentFilterValueLabels`는 그대로다(경장갑…).
  - **타입 색(FD-024)**: 복합장갑·복합 공격 계열 `#228b22` → `AppColors.typeComposite`(#7a8ea3). 모르는 공격 타입의 대체 색 `#5c6ea8` → `AppColors.outline`(방어와 같다). 이제 타입 색은 `AppColors` 토큰만 쓴다.
  - **외곽선 두께**: 기준은 그대로 "셀의 짧은 변"이다. 셀이 카드가 되었으므로 그리드 카드는 카드 높이의 1%·2%가 된다(시안 1.67·3.35, 이전 2.07·4.13). 1×1 초상 슬롯(학생 S3, 계획 요소 초상)은 이전 두께 그대로다.
  - **폐기**: `studentCardInfoAreaFraction`, `studentCardAttributeAreaFraction`, `studentCardNameFontSize`, `studentGridStatusBadgeRects`, painter의 `_rowBounds`·`_paintName`.
  - **새 공용 기하·painter 도우미**: `studentGridCardCutDepth`, `StudentGridCardOverlayPainter.cardRectAt`(그리기와 같은 계산, 테스트·검수용). painter 생성자는 바뀌지 않아 계획 요소 초상(`plan_element_builder`)·warmup·S3 호출부는 그대로다.
- **`frontend/lib/app/theme.dart`**: `typeComposite` 주석만 고쳤다("아직 #228b22를 쓴다" → FE3-a에서 바꿨다). 값은 같다.
- **스캐너 소유 파일**: `scan_student_review_workspace.dart`·`scan_inventory_identity_review.dart`·`scan_page.dart`·`scan_companion_dock.dart`에는 `#228b22`(대소문자 무관)·`Composite`가 없다(lib 전체 검색). 그래서 건드릴 것이 없었다. 택틱 소유 파일도 건드리지 않았다.
- **리스트 보기(FD-048)**: `StudentDiagonalList`는 바꾸지 않았다.
- **계획 쪽 회귀 범위**: `plan_student_selector`(4열)는 `StudentDiagonalGrid`를 쓰므로 같은 DE 카드·행 기하가 적용된다. `plan_element_builder`의 1×1 초상은 칩·이름이 꺼져 있어 배지 채워 쌓기만 영향을 받는다.

### 문서

- `almanac/design/student-card-rendering-lessons-2026-08-02.md`: "현재 그리드 카드 렌더링 계약"에 "카드 정보 영역: DE 카드"와 "상태 배지: 왼쪽 80° 변 채워 쌓기" 소절을 새로 썼다. 고정 슬롯 배지 서술은 지웠다. 후속 체크리스트 두 줄도 고쳤다.
- `almanac/design/section-template-studio.md`(기존 미커밋 변경 있음, CRLF 유지): 학생 Section 2 grid 문단(행 간격·DE overlay·토글), 표의 "Section 2 간격·scroll"·"학생 카드" 행, "학생 카드 이름 크기 계약" → "학생 카드 이름 계약"을 고쳤다. 사본은 `debug/frontend_fe3a/pre/almanac/design/section-template-studio.md`이고, `fe_commit.ps1`이 3-way 병합한다.

### 테스트

- **새 파일 `frontend/test/student_card_de_test.dart`(17건)**
  - 칩: 축약 라벨과 필터 전체 라벨, 칩 순서와 모르는 타입 빠짐, 칩 상자 위치(시안 두 카드 크기, closeTo), 글자 스타일, painter가 타입 색으로 칩을 그리고 속성을 끄면 안 그림, 칩 계단.
  - 배지: 세 배지 쌓기 순서·위치·폭(시안 좌표), 있는 배지만 채움(PLAN만·JP만·UNOWNED+PLAN·없음), painter가 같은 칸에 그림.
  - 이름: 이름 rect, 보유·미보유 색(흐림), painter가 카드 아래에 그리고 끄면 안 그림.
  - 행 기하: 피치 191.31 / 이름 접힘 171.31, 행 left 192.95·159.21·125.48(시안).
  - 위젯 2건(1913.69×1140.62): 셀 = 카드, 행 피치·행 이동, 이름 줄은 누를 자리가 아님, 이름 끄면 접힘.
  - 복합장갑 색.
- **고친 기존 테스트(`student_studio_layout_test.dart`)**:
  - 지운 것 1건 + 대체: `student grid badges follow both top corners and the left rail`(고정 슬롯, JP 우상단)를 `student grid badges pack down the left 80 degree rail`로 바꿨다. 같은 내용을 새 파일의 배지 테스트 3건이 더 자세히 덮는다.
  - 기대값 수정 3건:
    - `student card name text is 1.5x larger with an 80 percent target` → `student grid name and Section 1 control text sizes`. `studentCardNameFontSize` 대신 `studentGridNameFontSize == 13`을 확인한다.
    - `student attack and defense colors preserve the v6 mapping`: 폐기 상수 두 줄을 뺐다.
    - `student grid is a single eight-column image grid`: `rowGap` 3.84 → 23.84, 아래 padding 28을 확인한다.
- 계획 테스트(`planning_page_test`의 4열 선택기 오른쪽 위 탭, `plan_element_builder_test`의 초상 배지)는 바뀐 기하에 기대지 않아 고치지 않았다(검토 에이전트가 4열 오른쪽 위 탭이 스크롤바 띠에 걸리지 않음을 계산으로 확인).
- 예상 건수: 541 + 17 = 558 + golden 17.

### 처리한 FD

- **FD-043**(확정): D(오른쪽 위 글자 칩) + E(이름 카드 밖), E의 2색 밑줄 없음.
- **FD-044**(확정): 배지 왼쪽 80° 변 채워 쌓기, 우상단 JP 슬롯 폐기.
- **FD-045**(확정): 행 피치 = 카드 + 이름 줄 + 3.84, 카드 중심 기준 행 이동. 이미지 grid·overlay·hit target이 같은 기하를 쓴다.
- **FD-046**(워커 재량): (a) 이름을 끄면 이름 줄을 접는다.
- **FD-047**(워커 재량): 칩 축약 라벨 경장/중장/특수/탄력/복합, 공격 폭발/관통/신비/진동(+화학). 필터는 전체 라벨이다. 프롬프트의 "특장" 대신 시안·대장의 "특수"를 썼다(2026-10-07 사용자 확인). "복합"은 시안에 없는 값이라 대장대로 추정 라벨이다.
- **FD-048**(워커 재량): 리스트 보기는 현행 유지.
- **FD-024**(워커 재량): 복합장갑 `AppColors.typeComposite`. 타입 색은 토큰만 쓴다.
- FD-012: 해당 없음(별 색 변경 없음).

### golden 갱신 사유(장면별 예상)

바뀔 장면(3):
- `students-grid`: 학생 그리드 카드가 바뀐다. 카드 안 회색 이름 띠와 속성 색 띠가 사라지고, 오른쪽 위에 칩 2개, 카드 아래에 이름 줄이 생긴다. 외곽선이 얇아진다(셀 짧은 변 → 카드 높이 1%). 행 가로 이동 기준이 셀 중심 → 카드 중심으로 바뀌어 카드가 오른쪽으로 약 3.5px 옮겨진다(셀 높이 차이의 절반 / tan80). 배지는 한 개라 같은 칸이다.
- `students-detail`: 같은 그리드 변화. S3 선택 초상(1×1, 칩·이름 꺼짐)은 배지가 한 개면 이전과 같아야 한다.
- `plan-student-selector`: 선택기 4열 그리드가 같은 DE 카드·행 기하로 바뀐다.

차이가 없어야 할 장면(14): `title`, `account-manager`, `account-editor`, `account-picker`, `home`, `plan-bottleneck`, `plan-by-phase`, `plan-overall`, `plan-phase-editor`, `plan-element-builder`, `plan-preset-manager`, `plan-scenario-list`, `plan-scenario-compare`, `scan-student-review`.
- 기존 golden에서 `plan-element-builder` 초상의 배지는 첫 칸 하나다. 그래서 채워 쌓기와 같은 자리라 차이가 없어야 한다. 이 장면에 차이가 나면 배지가 두 개 이상(예: 보유 + PLAN)이라는 뜻이니 차이 이미지를 보고 판단한다.
- `title`의 warmup 카드(불투명도 1/255)는 캡처 전에 사라진다(harness가 확인한다).

### 검수표 (mock 모드, 2560×1440 모니터 최대화 = 2560×1392)

실행: `cd frontend; flutter run -d windows --dart-define=BA_PLANNER_USE_REAL_BACKEND=false`(mock은 전체 265명 catalog, 보유 42명).

**학생 탭 그리드 → 캔버스 Student · W-Card-Grid-DE · W-Card-Variants(D·E) · W-Card-States**

| 대조 포인트 | 확인 |
|---|---|
| 속성 칩 | 카드 오른쪽 위에 공격 → 방어 칩 2개. 두 번째 칩이 아래로 3, 왼쪽으로 약 3.7 들어간 80° 계단. −10° 기울기, r3, 그림자. 글자 흰색 w800 약 10px. 라벨 폭발/관통/신비/진동 · 경장/중장/특수/탄력/복합 |
| 이름 | 카드 밖 아래 줄(카드 밑변 + 3, 13px w700), 폭 = 카드 하단 변, 가운데 정렬. 미보유는 #9eb0c2로 흐리다. 카드 안 회색 띠·2색 밑줄 없음 |
| 배지 | 왼쪽 80° 변을 따라 UNOWNED → PLAN → JP 채워 쌓기. 우상단에 JP 없음. 보유 + PLAN이면 PLAN이 맨 위. 세 배지: JP 전용 미보유 학생(예: 슌(수영복))을 계획에 넣으면 |
| 행 | 8열, 행 피치 ≈191(카드 + 이름 줄), 행마다 왼쪽으로 ≈33.6 이동(80° 레일). 맨 아래 행 이름 줄까지 스크롤된다 |
| 토글 | S4 "학생 이름 표시" 끄기 → 이름 줄이 접혀 행 간격이 ≈3.8이 된다. "학생 공격/방어 속성 표시" 끄기 → 칩이 사라진다 |
| 복합장갑 | 아리스(무장)·케이의 두 번째 칩 "복합"이 회청색 #7a8ea3(이전 초록 아님) |
| 상태(W-Card-States) | 선택 = #ff72b6 2% + 흰 1% 외곽선, 미보유 암전이 칩까지 덮는다, 인연 20/50/100 배경 구간은 이전과 같다 |
| S3 선택 초상 | 칩·이름 없음, 배지는 왼쪽 변 채워 쌓기(보유 + PLAN이면 PLAN이 첫 칸) |
| 리스트 보기 | 이전과 같다(FD-048) |

**계획 학생 선택기**: 계획 탭 → 학생 선택(`plan-student-selector-launch`). 4열 DE 카드(칩·카드 밖 이름·배지 쌓기), 행 피치 = 카드 + 23.84. 여러 명을 고르면 핑크 외곽선이 생긴다. 1~4행 4열 카드의 오른쪽 위를 눌러도 선택된다. 확인 → 요소 빌더 초상의 배지 위치를 본다.

### 알려진 시안 차이

1. **카드 폭**: 기준 viewport에서 앱 카드 폭은 206.12이고 시안은 206.87이다. 셀 폭 산식(컨테이너 폭 − inset − 80° trajectory − 스크롤바 예약 14 − 열 간격)이 FE3-a 전부터 쓰던 값이라 바꾸지 않았다. 그래서 행 피치는 190.7(시안 191.31), 첫 행 left는 약 0.5px 다르다. 같은 카드 폭을 넣으면 시안 값과 일치한다(테스트).
2. **이름 넘침**: 시안은 넘치면 잘리기만 한다(overflow hidden). 앱은 말줄임(…)을 쓴다.
3. **칩 오른쪽 위치**: 시안 칩의 right 값(9.8/13.5, 10.0/13.7, 9.9/13.5)을 "칩 밑변 높이에서 카드 오른쪽 변 − 6"으로 모델링했다. 모든 시안 카드 크기에서 ±0.05px 안이다.
4. **배지 높이**: 시안 배지 상자는 23px 고정이지만 쌓기 간격은 카드 높이 14%(23.45)로 계산되어 있다. 앱은 기존대로 상자도 14%다(±0.5px).
5. **화학 공격 칩 색**: 시안·토큰에 색이 없어 `AppColors.outline`이다. 현재 catalog에는 화학 학생이 없다.
6. **다중 폼 교대**(시안 첫 두 카드 호시노(무장)·슌(수영복))는 FE3-e 몫이다.
7. **인연 게이지·S4 확장**(Student 시안 S3·S4)은 FE3-b·FE3-c 몫이다.

### 미검증 항목

1. analyze, 전체 테스트(기존 541 + 새 17), golden 17장 비교. 사용자 PC gate가 필요하다.
2. 실행해 봐야 아는 것:
   - `paints` 패턴(칩·배지·이름 호출 순서). 검토 에이전트가 순서를 확인했지만 실행은 못 했다.
   - 위젯 테스트 기대값(1913.69×1140.62 grid의 hit target).
   - 실제 글꼴에서 칩 글자 세로 가운데.
   - 실패하면 테스트 기대값부터 확인한다.
3. golden 3장 변화가 예상과 같은지(위 장면별 예상). 14장은 차이 0이어야 한다.
4. 실제 화면 시각 비교는 사용자 검수가 필요하다(위 검수표).

### 발견 사항

1. **방어 칩 라벨 표기 불일치**: 프롬프트의 "특장"과 대장·시안의 "특수"가 달랐다. 사용자 확인으로 "특수"를 썼다.
2. **warmup 카드 이름**: `student_grid_warmup.dart`의 warmup 카드(126×102, `showNames: true`)는 이름을 카드 아래, 상자 밖에 그린다. 불투명도 1/255이고 글자 그리기 경로를 미리 데우는 목적이라 그대로 두었다(파일 미수정).

### 사용자 실행 순서

①만 먼저 실행한다. golden만 RED(위 3장)일 것으로 예상한다. 결과(`debug/frontend_gate/<stamp>/summary.txt`, `frontend/test/goldens/failures/`)를 오케스트레이터에게 보내고 멈춘다.

```powershell
# ① 비교 gate. golden 3장(students-grid, students-detail, plan-student-selector)만 RED 예상
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

② 오케스트레이터가 차이 이미지를 승인한 뒤에만:

```powershell
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3a -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3a
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesign-docs
```

`debug/frontend_fe3a/commit.json`의 `whole`에 `frontend/test/goldens/baseline`을 넣었다. 사본은 `debug/frontend_fe3a/pre/` 5개다(`student_section_layout.dart`, `theme.dart`, `student_studio_layout_test.dart`, 두 almanac design 문서).

### 다음 행동

1. 사용자: ①을 실행하고 결과를 오케스트레이터에게 넘긴다.
2. 오케스트레이터: golden 차이 검토 → 승인되면 ② → 다음 slice FE3-b(인연 B 게이지).

### FE3-a commit record (2026-10-07 12:16, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261007_121200\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: almanac/design/section-template-studio.md

## FE3-b 착수 기록 (2026-10-07)

- 범위 A: 워크플로 FE3-b 행 그대로. 학생 S3 인디케이터의 인연 게이지를 W-Bond-Variants B안으로 바꾼다. 현재 랭크 채움(rank/100 그대로, FD-051)에 목표 구간 빗금·목표 높이 점선·`→N`을 겹친다. 목표는 활성 계획 문서에서 그 학생 단계 목표의 `bond_rank`다(FD-003, FD-049). 단계가 여러 개면 마지막 단계를 쓰고, 목표가 없거나 현재 이하이면 목표 표시를 하지 않는다(FD-050). 목표 조회는 얇은 함수 한 곳으로 모은다(FB-1 때 교체). 백엔드·프로토콜은 바꾸지 않는다.
- 범위 B: 학생 golden 장면 보강(오케스트레이터 12:05). golden harness·fixture 쪽만 고친다(MockAppService 기본값 유지). 미보유, PLAN·JP 배지 2개 이상, 긴 이름, 인연 목표 있음·없음 학생을 넣고, `students-detail`이 선택 학생 S3 상세를 실제로 보이게 찍는다. 계획 장면(plan-*) fixture는 건드리지 않는다.
- 범위 밖: S4 확장(FE3-c), 필터 모달(FE3-d), 계산기(FE3-f).
- 시작 커밋: `fdf0097e5345b9e88c9bb3d1c187cf951dafe93c`.
- 막힘: 대장 막힘 요약에서 FE3-b를 막는 열림 FD 없음.
- 시각 변경 slice: golden 갱신은 오케스트레이터 검토 뒤 사용자가 `fe_gate.ps1 -UpdateGoldens`로 한다. golden PNG를 직접 만들거나 지우지 않는다.
- 사본: 고칠 기존 파일마다 착수 전 사본을 `debug/frontend_fe3b/pre/<v7 기준 경로>`에 둔다.
- 기기 쓰기: 매번 새 업로드 경로에서 쓰고, 쓴 뒤 다시 읽어 바이트로 대조한다.

## FE3-b 종료 기록 (2026-10-07, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없어 analyze·테스트·golden을 돌리지 못했다. 통과를 주장하지 않는다.
- 쓴 API는 Flutter 3.44.0 소스와 대조했다.
- 별도 검토 에이전트가 바뀐 파일을 사본과 대조해 정적으로 읽었다.
  - 컴파일 오류·analyze 지적은 없었다.
  - 테스트 1곳이 실행하면 실패할 것을 찾아 고쳤다: `Paint.strokeWidth`는 32비트라 `== 1.6` 비교가 늘 거짓이다 → 오차 1e-4로 비교한다.
  - 계획 요소 초상(목표 없음·`solidFill: false`)의 위젯 트리와 canvas 호출 순서가 이전과 같음을 확인했다.
- 시안 값은 W-Bond-Variants B안과 W-Student-Detail의 SVG 원문에서 읽었다(pattern `hat56`, clipPath 높이, line·text 속성).

### 범위 A: 인연 B 게이지

- **`frontend/lib/ui/widgets/student_section_layout.dart`**
  - `StudentBondStatus`에 `targetRank`, `solidFill`을 더했다. 목표가 보이면(아래 규칙) 그리는 순서는 이렇다.
    1. 빗금: 바닥에서 목표 높이까지, inset host 안. 키트 `paintHatch` + `studentBondTargetHatchStyle`(간격 6, 줄 2.4, −35°, 바탕 rgba(233,176,238,.16), 줄 .55).
    2. 현재 채움: 같은 rank/100 비율(FD-051). 빗금 위를 덮어 현재 ~ 목표 구간만 빗금으로 남는다.
    3. 점선: 목표 높이, 바깥 삼각형의 그 높이 가로 범위 전체. #e9b0ee 1.6, dash 3·gap 2.
    4. `→N`: Text 위젯 `student-detail-bond-target`. 경기천년제목 10 w800 #e9b0ee, 오른쪽 끝 − 3에 오른쪽 정렬, 글자 상자 바닥 = 점선 3 위(글자 바닥 ≈ 5 위).
  - 기하 함수 `studentBondTargetLine`, 상수 `studentBondTarget*`를 공개했다.
  - B안 현재 채움은 불투명 #e9b0ee(`solidFill: true`)다. 학생 S3만 true다. 계획 요소 초상(inverted)은 기본값 false라 이전과 같다.
  - `StudentSectionLayout.selectedBondTarget`을 `_StudentStatusIndicators`를 거쳐 S3 게이지로 넘긴다.
- **새 파일 `frontend/lib/ui/models/active_plan_bond_target.dart`**: 목표 조회 경계를 한 곳에 모았다(FB-1 때 이 파일만 바꾼다).
  - `ActivePlanDocumentSource`(서비스가 구현하면 활성 계획 문서를 준다)와 `loadStudentActivePlanDocument`: 구현하지 않으면 null이고, 실패해도 null이다.
  - `activePlanBondTarget`: 그 학생의 마지막 단계 `bond_rank`(FD-050).
  - `studentBondVisibleTarget`: 목표가 없거나 0 이하이거나 현재 이하이면 null이다. 현재를 모르면(미보유) 목표만 그린다(FD-050).
  - goals v1(`RepositoryGoalState`)은 `target_bond_rank`를 받지 않는다. 그래서 거기서 목표를 만들지 않는다(없는 값을 현재값·0으로 채우지 않음). 지금 실제·mock 데이터에서는 목표가 없으니 "목표 없음"으로 그린다. 백엔드·프로토콜은 바꾸지 않았다.
- **`frontend/lib/ui/pages/student_page.dart`**: 계정을 고를 때 `loadStudentActivePlanDocument`로 활성 계획 문서를 읽어 두고, 선택 학생의 목표를 `selectedBondTarget`으로 넘긴다. 이제 `PlanningStudentSeed`를 `planning_models.dart`에서 직접 가져오므로 쓰지 않게 된 `planning_page.dart` import를 지웠다(`unnecessary_import` 방지, 동작 같음).

### 범위 B: 학생 golden 장면 보강

- **`frontend/test/goldens/golden_harness.dart`**: 학생 장면 전용 `GoldenStudentMockAppService`(`GoldenMockAppService` 상속, `ActivePlanDocumentSource` 구현)를 더했다. `MockAppService` 기본값과 계획 장면 fixture(`GoldenMockAppService`)는 그대로다. 학생 7명은 bundled catalog의 실제 학생·초상이다.

| 학생 | 상태 | golden이 보는 것 |
|---|---|---|
| 아루 | 보유, 계획 없음, 목표 없음, 첫 학생(기본 선택) | `students-grid` S3: B안 불투명 채움, 목표 표시 없음 |
| 아야네 | 보유 + PLAN, 활성 계획 두 단계 30 → 45(현재 24) | `students-detail` S3: 마지막 단계 45의 빗금·점선·`→45`, S3 초상 PLAN 첫 칸 |
| 호시노 | 보유, 긴 이름(`호시노(카드 하단 변보다 긴 이름은 말줄임으로 줄어듭니다)`), 목표 20 ≤ 현재 30 | 이름 말줄임. 목표는 숨김 대상(S3에는 안 나옴) |
| 슌(수영복) | 미보유 + PLAN + JP, 목표 20 | 배지 3개 채워 쌓기, 미보유 암전·흐린 이름 |
| 히나 | 보유 + PLAN | PLAN 배지 한 개가 첫 칸 |
| 세리카 | 미보유 | UNOWNED, 흐린 이름 |
| 케이 | 보유 | 복합장갑 칩(#7a8ea3) |

- 보유·계획 상태는 장면을 열기 전에 `seedStudentScene()`이 선택 계정에 저장한다(`saveRepositoryStudents`, `saveRepositoryGoals`). 보유 값은 `buildMockOwnedStudents()` 고정 값이다(케이는 아루 값).
- **`frontend/test/goldens/fe1g_baseline_golden_test.dart`**
  - `students-grid`: 학생 fixture를 쓴다. 기본 선택(아루)에 목표 표시가 없음을 확인한다.
  - `students-detail`: 아야네를 눌러 S3가 그리드와 다르게 보인다(`→45` 확인). 이전에는 이미 선택된 첫 학생을 다시 눌러 `students-grid`와 바이트까지 같았다.
  - **새 장면 `students-grid-name-off`**: S4 "학생 이름 표시"를 끄고 찍는다(이름 줄 접힘, FD-046 (a)). `showNames == false`를 확인한다.
  - 계획 장면(plan-*)은 고치지 않았다.

### 테스트

- **새 파일 `frontend/test/student_bond_gauge_test.dart`(11건)**
  - 목표 조회 3건: 여러 단계 → 마지막 단계, 다른 학생·문서 없음 → null; 보일 목표 규칙(없음·같음·이하·초과·현재 모름·0·100 초과); `ActivePlanDocumentSource`가 없거나 실패하면 null.
  - 그리기 6건:
    - 목표 있음: `→30` 문구·스타일, 점선 y = 바닥 − 높이 × .3(closeTo), 점선 가로 범위 = 삼각형 그 높이 폭, 글자 rect(오른쪽 = 점선 오른쪽 − 3, 바닥 = 점선 − 3, 높이 10, closeTo), 빗금·점선 그리기.
    - 목표 없음과 목표 ≤ 현재: →N·점선·빗금 없음.
    - 현재 0(채움 없음)이어도 빗금을 그려 "목표 없음·0"과 구분된다.
    - B안 불투명 채움 / 이전 .78 채움.
    - 시안 값 상수.
  - 학생 탭 연결 2건: StudentPage에서 활성 계획 두 단계(30 → 50) → S3 `→50`(30 없음)이고, 목표 없는 학생을 고르면 사라진다. 활성 계획을 줄 곳이 없으면 목표 없음.
- 기존 테스트는 고치지 않았다. `StudentBondStatus`·`StudentSectionLayout` 생성자는 새 인자가 선택이라 기존 호출이 그대로 컴파일된다.
- 예상 건수: 일반 558 + 11 = 569(프로세스 28 포함), golden 17 + 1 = 18.

### 처리한 FD

- **FD-003·FD-049**(확정): 목표는 활성 계획 문서의 그 학생 단계 `bond_rank`다. 조회 경계는 `active_plan_bond_target.dart` 한 곳이다. FB-1 전이라 실제·mock 데이터에는 문서가 없어 목표 없음이다.
- **FD-050**(워커 재량): 마지막(최종) 단계 목표를 쓰고, 목표가 없거나 현재 이하이면 빗금·점선·→N을 숨긴다. inverted(계획 화면) 모드도 같은 위젯이 같은 표현을 지원한다. 다만 계획 요소 초상의 목표 연결은 이번에 하지 않았다(계획 golden 차이 0 조건, 계획 만들기 FE4 몫).
- **FD-051**(확정): 채움 비율은 rank/100 그대로이고, 목표 빗금·점선·→N을 겹친다.

### golden 갱신 사유(장면별 예상)

바뀔 장면(2):
- `students-grid`: 학생 fixture가 2명(전원 미보유)에서 7명으로 바뀌어 그리드 전체가 달라진다. 보유·미보유 섞임, 배지 1~3개 쌓기, 긴 이름 말줄임, 복합장갑 칩이 보인다. S3는 아루(보유)의 상세이고, 인연 게이지 채움이 불투명 #e9b0ee(B안)이다. 목표 표시는 없다.
- `students-detail`: 같은 그리드에서 아야네가 선택된 상태(핑크 외곽선)다. S3는 아야네 상세이고, 인연 게이지에 현재 24 채움 + 24~45 빗금 + 45 높이 점선 + `→45`가 보인다. S3 초상 배지는 PLAN 첫 칸이다. 이제 `students-grid`와 다르다.

새 장면(1, 기준 PNG 없음 → ① 비교에서 "파일 없음"으로 실패하는 것이 정상):
- `students-grid-name-off`: `students-grid`와 같은 fixture에서 이름 줄이 접혀 행 간격이 ≈3.8로 줄어든다. 카드 아래 이름이 없고, S4 "학생 이름 표시" 체크가 꺼져 있다.

차이가 없어야 할 장면(15): `title`, `account-manager`, `account-editor`, `account-picker`, `home`, `plan-bottleneck`, `plan-by-phase`, `plan-overall`, `plan-phase-editor`, `plan-student-selector`, `plan-element-builder`, `plan-preset-manager`, `plan-scenario-list`, `plan-scenario-compare`, `scan-student-review`.
- 계획 요소 초상의 인연 게이지는 `targetRank`·`solidFill`을 넘기지 않아 이전과 같은 경로로 그린다(검토 에이전트 확인).
- 학생 페이지가 활성 계획 문서를 읽는 일은 `GoldenMockAppService`에서 null이라 화면에 영향이 없다.

### 검수표 (mock 모드, 2560×1440 모니터 최대화 = 2560×1392)

mock 모드에는 활성 계획 문서가 없다(FB-1 전). 그래서 앱 화면에서는 "목표 없음" 상태만 보인다. 목표 겹침은 golden `students-detail`(② 뒤 기준 PNG)과 아래 위젯 테스트로 본다.

**W-Bond-Variants B · Student S3 · W-Student-Detail 대조**

| 대조 포인트 | 확인 |
|---|---|
| 현재 채움 | 학생 탭 S3 인연 삼각형 채움이 불투명 연핑크(#e9b0ee)다. 이전은 반투명. 비율은 rank/100 그대로(20이면 아래 20%) |
| 목표 겹침(golden `students-detail`) | 현재 채움 위로 목표 높이까지 −35° 빗금(연핑크 줄), 목표 높이에 점선(바깥 삼각형 왼쪽 사선 ~ 오른쪽 끝), 점선 위 오른쪽에 작은 `→45` |
| 목표 없음 | 목표가 없거나 현재 이하이면 빗금·점선·→N이 없다(mock 앱 화면 전부, golden `students-grid`) |
| 숫자 | 랭크 숫자 43.2px, 하단 span 가운데. 이전과 같다 |
| 계획 요소 초상 | 계획 → 학생 선택 → 요소 빌더의 인연 게이지는 이전과 같다(반투명 채움, 목표 표시 없음) |

**학생 그리드 golden(② 뒤 새 기준 PNG 검토용)**: 슌(수영복) 카드 왼쪽 변 UNOWNED → PLAN → JP 3개 계단, 히나 PLAN 첫 칸, 세리카·슌 이름 흐림, 호시노 이름 말줄임(…), 케이 둘째 칩 "복합" 회청색. `students-grid-name-off`는 이름 줄이 없고 행 간격만 3.84다.

### 알려진 시안 차이

1. **빗금 위상**: 시안 pattern은 SVG 원점 기준 6×6 칸이다. 키트 `paintHatch`는 영역 가운데를 기준으로 돌려 줄의 시작 위치가 최대 6px 다를 수 있다(간격·각도·굵기·색은 같다).
2. **`→N` 세로 위치**: 시안은 SVG text baseline = 점선 − 5다. 앱은 글자 상자 바닥 = 점선 − 3이다(경기천년제목 하강부 ≈ 2px 가정, ±1px).
3. **목표가 100 가까이**: 점선이 꼭짓점 근처로 올라가면 `→N`이 container-10 위로 나가 잘릴 수 있다. 시안에는 그런 상태가 없다.
4. **계획 요소 초상(inverted 게이지)**: 위젯은 목표 겹침을 지원하지만 이번에 연결하지 않았다(채움도 이전 반투명). 계획 만들기 slice에서 B안으로 맞춘다(FD-050).
5. **mock 화면**: 활성 계획 문서가 없어 앱에서 →N을 볼 수 없다(FB-1 전). 테스트·golden fixture만 목표를 준다.

### 미검증 항목

1. analyze, 전체 테스트(기존 558 + 새 11), golden 18장(2장 갱신 + 1장 새 장면 + 15장 차이 0). 사용자 PC gate가 필요하다.
2. 실행해 봐야 아는 것:
   - golden fixture 저장(`seedStudentScene`)과 7명 catalog 구성.
   - `students-detail`의 아야네 탭과 `→45` 확인.
   - `students-grid-name-off` 토글 탭.
   - 위젯 테스트의 `paints` 패턴(빗금·점선 drawLine).
   - 실패하면 테스트 기대값·fixture부터 확인한다.
3. 실제 글꼴에서 `→N` 세로 위치(시안 대비 ±1px)와 빗금 모양은 새 기준 PNG로 오케스트레이터가 본다.

### 발견 사항

1. 계획 화면(`plan_section_layout.dart`)은 goals v1을 메모리에서 1페이즈 문서로 바꿀 때 인연 목표가 없으면 현재값(없으면 1)을 채운다(`planningDocumentTargets`). 이 값을 학생 탭 →N의 출처로 쓰면 목표처럼 보이는 가짜 값이 생겨 쓰지 않았다. FB-1 설계 때 "목표 없음"을 문서에서 어떻게 나타낼지 정해야 한다.

### 사용자 실행 순서

① 비교 gate 하나만 실행한다. 바뀐 장면 2장(`students-grid`, `students-detail`)은 차이로, 새 장면 1장(`students-grid-name-off`)은 기준 PNG 없음으로 RED가 날 것으로 예상한다. 나머지 15장은 차이 0이어야 한다. 결과(`debug\frontend_gate\<실행 시각>\summary.txt`, `frontend\test\goldens\failures\`)를 오케스트레이터에게 보내고 멈춘다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

② 오케스트레이터 승인 뒤: golden을 갱신하고 비교를 다시 돌린다(GREEN). 오케스트레이터가 새 기준 PNG 3장(`frontend\test\goldens\baseline\students-*.png`)을 직접 열어 검토한다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

③ 새 기준 PNG 승인 뒤: 커밋한다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3b -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3b
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesign-docs
```

`debug/frontend_fe3b/commit.json`의 `whole`에 `frontend/test/goldens/baseline`을 넣었다(새 PNG `students-grid-name-off.png`도 이 폴더라 함께 들어간다). 사본은 `debug/frontend_fe3b/pre/` 5개다(`student_section_layout.dart`, `student_page.dart`, `fe1g_baseline_golden_test.dart`, `golden_harness.dart`, `student-detail-indicator-lessons-2026-08-01.md`).

### 다음 행동

1. 사용자: ①을 실행하고 결과를 오케스트레이터에게 넘긴다.
2. 오케스트레이터: 차이 검토 → ② → 새 기준 PNG 검토 → ③ → 다음 slice FE3-c(S4 확장).

### FE3-b commit record (2026-10-07 12:59, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261007_125410\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE3-c 착수 기록 (2026-10-07)

- 범위 A(워크플로 FE3-c 행 그대로): S4 결과 수 줄, 적용 필터 칩(FE2-b `BaChip` 제거형, × · 모두 지우기, 범위 조건 칩 포함·넘치면 한 줄 + "+n" — FD-060), 최근 본 학생(6명, 앱 실행 동안만, 누르면 선택 + 그리드 스크롤 — FD-061, 학생 위젯 밖 작은 상태 객체), 필터 상태를 layout state에서 페이지 컨트롤러로 올림(S4 토글과 팝업 "보유·서버"는 같은 상태 — FD-057), 기본 정렬 이름 ↑ 유지(FD-062).
- 범위 B(오케스트레이터 12:47·12:58): 상태 배지 글자가 golden에서 흰 사각형으로 그려지는 원인 확인과 배지 글꼴 명시, golden 학생 fixture를 그리드 두 줄 이상으로 늘림(계획 fixture 불변).
- 범위 밖: 필터 모달(FE3-d). 기존 Section 5·범위 카드는 동작만 유지한다.
- 시작 커밋: `6d24838bfe81d2d93e2256ef92bf03350dc513e8`.
- 막힘: 대장 막힘 요약에서 FE3-c를 막는 열림 FD 없음.
- 시각 변경 slice: golden 갱신은 오케스트레이터 검토 뒤 사용자가 `fe_gate.ps1 -UpdateGoldens`로 한다. golden PNG를 직접 만들거나 지우지 않는다.
- 사본: 고칠 기존 파일마다 착수 전 사본을 `debug/frontend_fe3c/pre/<v7 기준 경로>`에 둔다.
- 기기 쓰기: 매번 새 업로드 경로에서 쓰고, 쓴 뒤 다시 읽어 바이트로 대조한다.

## FE3-c 종료 기록 (2026-10-07, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없어 analyze·테스트·golden을 돌리지 못했다. 통과를 주장하지 않는다.
- 별도 검토 에이전트가 바뀐 파일을 사본과 대조해 정적으로 읽었다(쓴 API의 존재·시그니처, import, listener 해제, 기존 테스트 finder 충돌).
  - 컴파일 오류·analyze 지적은 없었다.
  - 새 테스트 2곳이 실행하면 실패할 것을 찾아 고쳤다.
    1. 구분선 1px 높이만큼 아래 줄이 모두 1px 내려갔다 → 구분선 뒤 간격을 5로 해 결과 수 줄이 구분선 위끝 + 6에 온다(시안 226.2 → 232.2).
    2. `student-recent-label` 키가 줄이 아니라 가운데 정렬된 글자에 붙어 있었다 → 줄(`Align`)로 옮겼다.
- 시안 값은 `W-Student-Search.dc.html`을 `tools/dc_outline.py`로 읽었다(칩·링크·결과 수 문구·썸네일 크기·외곽선).

### 범위 A: S4 확장

- **새 파일 `frontend/lib/ui/models/student_filter_controller.dart`**: 학생 그리드 필터 상태(`StudentFilterController`, `ChangeNotifier`). 학생 페이지가 하나를 소유한다.
  - 속성 조건(학교·속성 등 catalog 값), `hideUnowned`·`hideJpOnly`(S4 토글 = 필터 팝업 "보유 · 서버", FD-057), 범위 조건(`StudentRangeConditions`)을 한곳에 둔다.
  - `appliedFilters`: 속성 조건(필터 정의 순서, 값 이름순) 다음 범위 조건(목표 키 순서). 범위 조건 라벨은 축약형 `레벨 70~90`, `EX 3~5`(`studentRangeChipLabels`). 최소~최대 전체면 조건이 아니다.
  - `removeApplied`(칩 ×): 속성 값 하나를 빼거나 범위 한 항목을 최소~최대로 되돌린다. `clearApplied`(모두 지우기): 칩으로 보이는 조건(속성·범위)만 지운다. S4 토글은 그대로 둔다.
- **새 파일 `frontend/lib/ui/models/recent_students.dart`**: 최근 본 학생(`RecentStudents`, FD-061). 6명, 가장 최근이 앞, 같은 학생은 한 번. 저장하지 않는다(앱 실행 동안만). 앱 셸이 하나를 만들어 학생 탭에 넘긴다. FE4-b(계획 1단계)도 같은 객체를 받으면 된다.
- **`frontend/lib/ui/widgets/student_section_layout.dart`**
  - layout state의 `_hideUnownedStudents`·`_hideJpOnlyStudents`·`_selectedCatalogFilters`를 지우고 `filterController`를 읽는다. 넘기지 않으면 자체 컨트롤러를 만든다(기존 호출·테스트 그대로 동작).
  - S4 토글 4줄 아래 확장(W-Student-Search): 구분선(1px rgba(113,199,244,.28)) → 6 → 결과 수 줄 24 → 8 → 적용 필터 줄 26 → 10 → "최근 본 학생" 20 → 2 → 썸네일 줄 40.5.
    - 줄 왼쪽은 S4 왼쪽 80° 변을 따라 그 줄 밑변 높이에서 22px 안쪽이다(아래 줄일수록 왼쪽으로). 오른쪽 끝은 검색 상자 오른쪽이다.
    - S4 높이를 넘는 줄은 그리지 않는다(작은 창에서 축소하지 않는다).
  - 결과 수 줄 `StudentResultCountRow`: `표시 N / 전체 T · 보유 O · 계획 중 P`. N은 경기천년제목 18 w800, 나머지는 Pretendard 13 muted. N = 지금 그리드에 보이는 수, T = catalog 전체, O = 보유 수, P = 계획 학생 수.
  - 적용 필터 줄 `StudentAppliedFilterRow`: "적용 필터" 라벨 + `BaChip`(제거형, 톤 #e9b0ee 배경 .12). 조건이 없으면 "없음"이다.
    - 한 줄에 들어가는 칩만 보이고, 남는 수는 회색 `+n` 칩이다(FD-060, `studentVisibleChipCount`). `+n`은 지금 누를 수 없다(FE3-d 필터 모달에서 연결).
    - 조건이 있을 때만 오른쪽에 "모두 지우기"(#71c7f4 12 w600)가 있다.
  - 최근 본 학생 줄 `StudentRecentStrip`: 썸네일 50×40.5, 간격 5, 들어가는 수만큼. 선택 학생은 #ff72b6 1.6 외곽선, 나머지는 흰색 .85 1px이다.
    - 누르면 그 학생을 고르고(`onStudentSelected`), 그리드를 그 학생 행이 viewport 가운데에 오게 스크롤한다(`studentGridRevealOffset`, 0 ~ 최대로 자름, `AppMotion.header`).
  - `StudentDiagonalGrid`에 `revealStudentId`·`revealRequest`를 더했다. 요청이 바뀐 다음 frame에 스크롤한다.
- **`frontend/lib/ui/pages/student_page.dart`**: `StudentFilterController`를 소유하고 layout에 넘긴다. 범위 조건(`_rangeConditions`)도 컨트롤러로 옮겼다. Section 5를 닫으면 범위 조건을 처음으로 되돌리는 기존 동작은 그대로다(FE3-d 전까지).
  - 학생을 고를 때(기본 선택 포함) `RecentStudents.visit`을 부른다. 앱 셸이 목록을 주지 않으면 자체 목록을 쓴다.
- **`frontend/lib/ui/app_shell.dart`**(최소 diff): `RecentStudents` 하나를 만들어 `StudentPage`에 넘기고 dispose한다.
- 기본 정렬은 현행 이름 ↑ 그대로다(FD-062).
- Section 5·범위 카드는 동작만 유지했다(FE3-d에서 폐기).

### 범위 B: 학생 카드 후속

- **배지 글자 사각형 원인**: `paintStudentPortraitStatusBadge`의 `TextPainter` `TextStyle`에 `fontFamily`가 없었다. `CustomPainter`는 테마 글꼴을 물려받지 않아, golden에서는 테스트 글꼴(Ahem)로, 실제 앱에서는 플랫폼 기본 글꼴로 그려졌다(FE1-g 기준선부터).
- **`frontend/lib/ui/widgets/student_portrait_status_overlay.dart`**: `studentStatusBadgeTextStyle`을 공개하고 배지 painter가 쓴다. Pretendard(`AppFonts.body`, fallback `AppFonts.fallback`) w700, 글자 크기 = 배지 높이 × .43(6~12), 자간 .02em, 높이 1. 실제 앱 글꼴도 시안과 같아진다.
- **같은 원인으로 golden에서 사각형이 될 수 있는 다른 글자(목록만, 고치지 않음)**: `frontend/lib/ui/widgets/section_template_surface.dart:327`(`_paintElementLabel`), `:1104`(`_paintTextFeature`). 둘 다 Studio(편집기) 전용이라 지금 golden 장면에는 나오지 않는다. 학생 카드 이름·속성 칩·`stat_chart` 라벨은 이미 AppFonts를 명시한다.
- **`frontend/test/goldens/golden_harness.dart`**: 학생 fixture를 7명 → 10명으로 늘렸다. 8열 그리드가 두 줄이 된다.
  - 더한 학생: 하스미(보유), 나구사(미보유), 노아(보유).
  - 계획 장면 fixture(`GoldenMockAppService`)와 `MockAppService` 기본값은 그대로다.
- **`frontend/test/goldens/fe1g_baseline_golden_test.dart`**:
  - `students-grid`가 최근 본 학생 `aru`(기본 선택)를 확인한다.
  - `students-detail`이 `ayane` → `aru` 순서를 확인한다.
  - `students-grid-name-off`가 학생 수 > 열 수(두 줄)를 확인한다.
- **`almanac/design/student-card-rendering-lessons-2026-08-02.md`**: 상태 배지 절에 "painter 글자는 글꼴을 항상 명시한다"를 더했다.

### 테스트

- **새 파일 `frontend/test/student_search_section_test.dart`(13건)**
  - 최근 본 학생 목록 1건: 가장 최근이 앞, 같은 학생 한 번, 6명 상한.
  - 필터 상태 3건:
    - 칩 순서와 라벨(`밀레니엄`, `폭발`, `레벨 70~90`).
    - ×·모두 지우기는 칩 조건만 지우고 S4 토글은 그대로다.
    - 한 줄 칩 수와 `+n` 자리 계산.
  - S4 위젯 7건(2560×1208 학생 canvas):
    - 줄 위치(closeTo): 구분선 (2003.0, 226.2), 결과 수 (1998.7, 232.2, 높이 24), 칩 줄 (1992.7, 264.2, 26), 라벨 (1987.4, 300.2), 썸네일 (1980.0, 322.2), 오른쪽 끝 2523.7, 썸네일 50×40.5.
    - 결과 수 문구.
    - 칩 ×와 모두 지우기.
    - 범위 조건 칩과 `+n`(9개 조건).
    - S4 토글과 컨트롤러 공유(FD-057).
    - 최근 본 학생을 누르면 선택 + 스크롤(처음에 없던 행이 보임, 썸네일 간격 5).
    - 스크롤 위치 계산.
  - 학생 페이지 1건: 고른 학생이 최근 본 학생 앞에 오고(`aru` → `ayane, aru`) 앱 셸 목록을 쓴다. 정렬 라벨이 이름이다(FD-062).
  - 배지 글꼴 1건: Pretendard w700, 높이 × .43, 자간 .02em, 최소 6.
- **고친 기존 테스트 1건(지운 테스트 없음)**: `frontend/test/student_studio_layout_test.dart` "Section 1 dropdown changes the Section 2 student order"의 정렬 메뉴 글자 수 세기. 18px 글자를 모두 세던 조건에 정렬 강조색(`studentSortAccentColor`)을 더했다. 새 결과 수 숫자(18px)가 1100×720에서도 S4에 그려져 세는 수가 하나 늘기 때문이다. 이 테스트의 검증 내용은 같다.
- 상태를 페이지 컨트롤러로 올리면서 바뀐 기존 테스트는 없다. layout에 컨트롤러를 넘기지 않으면 자체 컨트롤러를 쓰므로 기존 토글·카탈로그 필터 테스트가 그대로 동작한다(검토 에이전트 확인).
- 예상 건수: 일반 569 + 13 = 582, golden 18(새 장면 없음).

### 처리한 FD

- **FD-057**: S4 토글(미보유 숨김·일본 서버 전용 숨김)과 필터 팝업 "보유 · 서버" 그룹은 `StudentFilterController`의 같은 상태다. 팝업 자체는 FE3-d다.
- **FD-060**: 적용 필터 칩은 범위 조건도 칩으로 보이고, 넘치면 한 줄 + `+n`이다.
- **FD-061**: 최근 본 학생 6명, 앱 실행 동안만, 학생 위젯 밖 상태 객체. 누르면 선택 + 스크롤한다.
- **FD-062**: 기본 정렬 이름 ↑ 유지(바꾸지 않음).
- 오케스트레이터 12:47·12:58 후속: 배지 글꼴 명시, golden 학생 fixture 두 줄.

### golden 갱신 사유(장면별 예상)

바뀔 장면(3):
- `students-grid`
  - 학생 10명 두 줄(둘째 줄 하스미·나구사·노아 포함, 이름순 정렬).
  - S4 아래 확장: 구분선, `표시 10 / 전체 10 · 보유 7 · 계획 중 3`, 적용 필터 "없음", 최근 본 학생 아루 1명(핑크 외곽선).
  - 배지 글자 UNOWNED·PLAN·JP가 사각형에서 Pretendard 글자로 바뀐다.
- `students-detail`: 위와 같고, 아야네가 선택되어 최근 본 학생이 아야네(핑크) → 아루 두 명이다.
- `students-grid-name-off`: 위와 같고, 이름 줄이 접혀 두 줄 사이 행 피치가 줄어든 것이 보인다(FD-046).

배지 글꼴 때문에 바뀔 수 있는 장면(2, 바뀐다면 배지 글자만):
- `plan-student-selector`, `plan-element-builder`: 학생 초상에 UNOWNED 등 배지가 그려지면 그 글자만 바뀐다. 다른 화소는 차이 0이어야 한다. 계획 fixture는 건드리지 않았다.

새 장면: 없음.

차이가 없어야 할 장면(13): `title`, `account-manager`, `account-editor`, `account-picker`, `home`, `plan-bottleneck`, `plan-by-phase`, `plan-overall`, `plan-phase-editor`, `plan-preset-manager`, `plan-scenario-list`, `plan-scenario-compare`, `scan-student-review`.
- 이 장면들에는 학생 상태 배지 painter가 나오지 않는다(`scan-student-review`의 학생 행은 보유라 배지 없음).

### 검수표 (mock 모드, 2560×1440 모니터 최대화 = 2560×1392)

**Student S4 · W-Student-Search 대조**

| 대조 포인트 | 확인 |
|---|---|
| 줄 순서 | 토글 4줄 아래: 얇은 하늘색 구분선 → 결과 수 → 적용 필터 → "최근 본 학생" → 썸네일 줄 |
| 왼쪽 변 | 각 줄 왼쪽 끝이 S4 왼쪽 사선을 따라 아래 줄일수록 왼쪽으로 간다. 오른쪽 끝은 검색 상자 오른쪽과 맞는다 |
| 결과 수 | `표시 N / 전체 T · 보유 O · 계획 중 P`. 검색어를 넣거나 "미보유 학생 숨김"을 켜면 N만 줄어든다 |
| 적용 필터 칩 | 조건이 없으면 "없음". Section 5에서 학교·속성 등을 고르면 연핑크 칩(×)이 생긴다. ×를 누르면 그 조건만 빠지고 그리드가 돌아온다 |
| 범위 조건 칩 | 범위 카드에서 레벨 등을 좁히면 `레벨 70~90` 같은 칩이 생긴다. ×로 그 항목만 최소~최대로 돌아간다 |
| 넘침 | 조건을 많이 고르면 한 줄을 넘지 않고 끝에 회색 `+n` 칩이 생긴다 |
| 모두 지우기 | 조건이 있을 때만 오른쪽에 하늘색 "모두 지우기". 누르면 칩이 모두 사라진다. S4 토글 체크는 그대로다 |
| 최근 본 학생 | 학생을 고를 때마다 맨 앞에 온다. 6명까지, 같은 학생은 한 번. 지금 선택 학생은 핑크 외곽선, 나머지는 흰 선 |
| 최근 본 학생 누르기 | 그 학생이 선택되고, 그리드가 그 학생 행까지 부드럽게 스크롤된다(아래쪽 학생을 고른 뒤 맨 위로 스크롤해 두고 눌러 본다) |
| 앱 실행 동안만 | 다른 탭에 갔다 와도 목록이 남는다. 앱을 다시 켜면 비어 있다(첫 기본 선택 학생 한 명부터) |
| 토글 공유 | "미보유 학생 숨김"·"일본 서버 전용 숨김"이 이전처럼 그리드를 거른다 |
| 기본 정렬 | 정렬 드롭다운이 이름 ↑ 그대로다 |
| 배지 글자 | 그리드·S3 초상·계획 화면 초상의 UNOWNED·PLAN·JP 글자가 Pretendard 굵게로 보인다 |

**golden(② 뒤 새 기준 PNG 검토용)**: 세 학생 장면에서 배지 글자가 사각형이 아니다. 그리드가 두 줄이다. `students-grid-name-off`는 두 줄 사이 간격이 이름 있는 장면보다 좁다. S4 아래 확장 줄이 보인다.

### 알려진 시안 차이

1. **칩 모양**: FE2-b `BaChip`을 그대로 써서 radius 7·좌우 padding 10이고 inset 테두리(@.6)가 없다. 시안은 높이 24, r5, padding 9, inset 테두리다. 색(#e9b0ee, 배경 .12, 글자 12 w700, × .8)은 같다.
2. **"보유 · 서버" 칩**: S4 토글은 칩으로 보이지 않는다(토글로 이미 보임). 모두 지우기도 토글을 끄지 않는다.
3. **결과 수 문구**: 프롬프트 예시 "24 / 170명"이 아니라 시안 문구 `표시 48 / 전체 170 · 보유 128 · 계획 중 8`을 따랐다. 보유·계획 중은 거르기 전 전체 기준이다.
4. **최근 본 학생 썸네일 배경**: 인연 단계 배경 대신 기본 배경(랭크 없음)을 쓴다. 학생마다 인연 값을 읽지 않는다.
5. **`+n` 칩**: 지금은 누를 수 없다. 시안에서는 필터 모달로 이어지며 FE3-d에서 연결한다.
6. **작은 창**: S4 높이가 모자라면 아래 줄부터 그리지 않는다(시안은 기준 viewport만 있다).

### 미검증 항목

1. analyze, 전체 테스트(기존 569 + 새 13), golden 18장(학생 3장 갱신, 계획 2장은 배지 글자에 따라 갱신 가능, 13장 차이 0). 사용자 PC gate가 필요하다.
2. 실행해 봐야 아는 것:
   - S4 줄 위치 계산(`studentSectionRect` 기준)과 시안 좌표의 ±1px.
   - 칩 폭 측정(`baChipTextStyle` TextPainter)과 실제 `BaChip` 폭의 차이로 `+n` 경계가 칩 하나 어긋날 수 있다.
   - 최근 본 학생 스크롤의 post-frame 타이밍.
   - 실패하면 테스트 기대값부터 확인한다.
3. `plan-student-selector`·`plan-element-builder`에 배지가 실제로 나오는지는 ① 결과로 확인한다.

### 발견 사항

1. `RecentStudents.clear()`는 아직 부르는 곳이 없다. 계정을 바꿔도 최근 본 학생이 남고, 학생 탭이 새로 만들어지며 기본 선택 학생(목록 첫 학생)이 맨 앞에 온다. 학생 ID는 계정과 무관해 누르면 동작은 맞다. 계정별로 비울지는 FE4-b 때 정한다.

### 사용자 실행 순서

① 비교 gate 하나만 실행한다. 학생 3장(`students-grid`, `students-detail`, `students-grid-name-off`)은 차이로 RED가 날 것으로 예상한다. `plan-student-selector`·`plan-element-builder`는 배지 글자 차이로만 RED가 날 수 있다. 나머지 13장은 차이 0이어야 한다. 결과(`debug\frontend_gate\<실행 시각>\summary.txt`, `frontend\test\goldens\failures\`)를 오케스트레이터에게 보내고 멈춘다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

② 오케스트레이터 승인 뒤: golden을 갱신하고 비교를 다시 돌린다(GREEN). 오케스트레이터가 새·바뀐 기준 PNG(`frontend\test\goldens\baseline\students-*.png`, 바뀌었다면 `plan-student-selector.png`·`plan-element-builder.png`)를 직접 열어 검토한다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

③ 새 기준 PNG 승인 뒤: 커밋한다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3c -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3c
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesign-docs
```

`debug/frontend_fe3c/commit.json`의 `whole`에 `frontend/test/goldens/baseline`을 넣었다. 사본은 `debug/frontend_fe3c/pre/` 8개다:
- `student_section_layout.dart`, `student_page.dart`, `app_shell.dart`, `student_portrait_status_overlay.dart`
- `golden_harness.dart`, `fe1g_baseline_golden_test.dart`, `student_studio_layout_test.dart`
- `student-card-rendering-lessons-2026-08-02.md`

### 다음 행동

1. 사용자: ①을 실행하고 결과를 오케스트레이터에게 넘긴다.
2. 오케스트레이터: 차이 검토 → ② → 새·바뀐 기준 PNG 검토 → ③ → 다음 slice FE3-d(필터 모달).

### FE3-c commit record (2026-10-07 13:49, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261007_134501\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE3-d 착수 기록 (2026-10-07)

- 범위(워크플로 FE3-d 행 그대로): 학생 탭·계획 1단계·통계가 함께 쓰는 필터 모달(상태 객체를 주입받는 구조, FD-104). 토글 칩·타입 칩, `RangeSliderRow`, `StarRangeBar`, 초안(draft) → 적용, 범위 모델 재구성(FD-053). Section 5와 범위 카드 2장 폐기(FD-052). 이번에는 학생 탭만 연결한다(계획 1단계는 FE4-b, 통계는 FE7-e).
- 오케스트레이터 후속(13:49): `+n` 칩 → 모달, S4 칩·모달 머리 칩 모양 확인과 `BaChip` 변형, 계정 전환 때 `RecentStudents` 비우기.
- 막힘: 대장 막힘 요약의 FE3-d 행(FD-074, FD-104)은 둘 다 확정(2026-10-06)이라 막지 않는다.
- 쪼개기: 크기가 커서 둘로 나눈다. slice 키는 `fe3d1`·`fe3d2`, 사본은 `debug/frontend_fe3d1/pre/`·`debug/frontend_fe3d2/pre/`.

| slice | 범위 | 화면 변화 |
|---|---|---|
| FE3-d1 부품·모델 | ① 성장 범위 모델: 행마다 최소~최대, 장비 티어·레벨은 3칸 중 가장 낮은 칸, 성급 9단계, 추가 능력치 합 0~75(FD-053·055), 강화·서브 최소 0 → "–"(FD-059), 행을 늘릴 수 있는 정의 목록(FD-063), 심상개화는 비활성 그룹(FD-054). ② 필터 선택 값 객체(속성·"보유 · 서버"·범위)와 토글 칩 개수(같은 그룹 조건 빼고 셈, FD-056), 적용 칩 목록. ③ 키트 `RangeSliderRow`·`StarRangeBar`(FD-012 색) + UI Kit 갤러리 W-Filter 둘째 줄. ④ `BaModal` 포커스 가두기·배경 접근성 차단·Esc 이중 처리 방지(FE2-c 남은 일). ⑤ `BaChip` 시안 S4 변형(r5·padding 9·inset 테두리) → S4 적용 필터 칩. ⑥ 계정 전환 때 `RecentStudents` 비우기 | 없음(golden 차이 0 예상. S4 칩은 golden 장면에서 "없음"이라 보이지 않는다) |
| FE3-d2 모달 화면 | 공용 필터 모달(머리 바·속성 패널·성장 범위 패널, 상태 객체 주입), `StudentFilterController`를 적용 값 + 초안으로 바꿈, 학생 탭 연결(S1 필터 버튼 · `+n` → 모달, "필터 · n" 배지 FD-058, "보유 · 서버" = S4 토글 FD-057), 필터 프리셋 칩 숨김(FD-074 (b)), Section 5·범위 카드 2장 폐기(FD-052, B §2-4)와 그 테스트 교체, section-template-studio.md "학생 Section 5 필터" 절 대체(기존 미커밋 변경 있음 → 사본 규칙), golden 새 장면 `students-filter-open` | 있음(students-* 갱신 + 새 장면) |

- 시작 커밋(FE3-d1): `8209e2601b9eeabab4ecf1019d20996fdb17ea34`.
- 기기 쓰기: 매번 새 업로드 경로에서 쓰고, 쓴 뒤 다시 읽어 바이트로 대조한다.

## FE3-d1 종료 기록 (2026-10-07, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없어 analyze·테스트·golden을 돌리지 못했다. 통과를 주장하지 않는다.
- 쓴 API는 Flutter 3.44 소스와 대조했다(`FocusScopeNode.traversalEdgeBehavior`, `containsSemantics`, `Color.a`, `TextScaler.noScaling`, 키 이벤트 전달 순서).
- 별도 검토 에이전트가 바뀐 파일을 사본과 대조해 정적으로 읽었다. analyze 지적·컴파일 오류는 없었고, 아래 셋을 고쳤다.
  1. **`BlockSemantics`를 모달 오버레이에 두면 실행 중 오류가 날 수 있다.** OverlayPortal 내용의 의미 노드는 OverlayPortal 자리의 노드를 traversal parent로 가리킨다. 그런데 `BlockSemantics`가 그 자리를 포함한 앞 화면 전체를 지워, `SemanticsNode._addToUpdate`의 `traversalParent!`가 null이 된다(`semantics.dart` 4091행). → `BlockSemantics`를 쓰지 않고, 열려 있는 동안 `BaModal.child`를 `ExcludeSemantics`로 뺀다. traversal parent 노드는 그 바깥이라 남는다.
  2. 핸들 키보드 테스트에서 ← 두 번 사이에 pump가 없어 한 번만 반영됐다 → pump를 넣었다.
  3. 테두리 칩의 `Border.all`이 Container 안쪽 여백에 더해져 칩이 2px 넓어졌다 → 테두리를 `foregroundDecoration`으로 그려 자리를 차지하지 않게 했다(시안 `box-shadow: inset`과 같음).
- 시안 값은 `W-Filter-Widgets.dc.html`·`Student-Filter.dc.html`·`W-Student-Search.dc.html`을 `dc_outline.py`와 해당 요소 원문 일부로 읽었다.

### 바꾼 것

- **새 파일 `frontend/lib/ui/models/student_filter_selection.dart`**: 필터 모달(d2)이 쓸 값과 규칙. 화면에는 아직 연결하지 않았다.
  - `StudentGrowthRangeRow`·`StudentGrowthRangeGroup`·`studentGrowthRangeGroups`(FD-053, FD-063):
    - 기본: 학생 레벨 1~90 · 성급 9단계 · 전용무기 레벨 0~60 · 인연 랭크 1~100
    - 스킬: EX 1~5 · 기본 1~10 · 강화 0~10 · 서브 0~10
    - 장비 · 능력치: 장비 티어 T0~T10 · 장비 레벨 0~70(둘 다 3칸 중 가장 낮은 칸) · 애장품 T0~T2 · 추가 능력치 HP·ATK·HEAL 합 0~75(FD-055 (a))
    - 표시: 스킬 최대 `M`, 강화·서브 0 `–`(FD-059), 티어 `T`, 성급 `★n`/`무기★n`. 칩 문구는 `레벨 70~90`, `EX 3~5`(스킬 최대도 숫자, 시안 머리 칩).
    - 육성도 행(FE7-d)은 "기본" 그룹 행 목록 앞에 더하면 된다.
  - 성급 9단계 `studentStarStep`: 학생★ 5 미만이면 학생★, 5면 5 + 전용무기★.
  - `StudentGrowthRanges`: 좁힌 행만 저장. 범위 밖은 자르고 순서는 바로잡고, 행 전체가 되면 조건에서 뺀다. `matches`는 좁힌 행을 모두 만족해야 참이다. 장비 상한 판정이 현행(칸별)과 달라진다(최저 칸 기준).
  - 심상개화(FD-054): `studentPotentialFilterChoices`(상관없음/개방/미개방)와 "v7 “준비 중” 자리" 문구만 둔다. 범위 행·조건이 아니다.
  - `StudentFilterGroup`·`studentCatalogFilterGroups`: 속성 그룹을 주입하는 구조(FD-104, 계획 그룹은 FE4-b에서 더한다). 칩 순서는 시안 순서이고, 목록에 없는 값은 뒤에 이름순으로 붙는다. catalog에 있는 값만 칩이 된다(화학은 있으면 보인다, FD-059). 학교의 협업 학생(Sakugawa·Tokiwadai)은 기존처럼 뺀다. 초기 성급 칩 이름은 시안대로 `★n`(`studentFilterChipLabel`).
  - `StudentFilterCandidate`: 학생 + 보유 + 현재 성장 값(`planElementCurrentTargets`, 미보유는 초기 값).
  - `StudentFilterSelection`(불변 값):
    - 속성(같은 그룹 = 또는, 그룹끼리 = 그리고), 보유·미보유(또는) + 일본 서버 전용 제외, 성장 범위.
    - S4 토글 대응(FD-057): `hidesUnowned` = 보유만 고른 상태, `withHideUnowned`, `hidesJpOnly`/`withHideJpOnly`.
    - `chipCount`(FD-056 (a)): 같은 그룹 조건은 빼고 다른 그룹 조건(보유 · 서버, 성장 범위 포함)만 반영해 그 값의 학생 수를 센다. "보유 · 서버" 줄은 한 그룹으로 본다.
    - `countMatching`(머리 "38 / 170명" 미리보기), `chips`(속성 → 보유 · 서버 → 성장 범위), `without`(칩 ×), `clearedKeepingOwnership`, `clearedRanges`(범위 모두 풀기), `activeCount`("필터 · n").
- **새 파일 `frontend/lib/ui/kit/range_controls.dart`**(W-Filter-Widgets 둘째 줄):
  - `RangeSliderRow`: h44 r6, 좁힌 행 핑크 .1 + 안쪽 1.5px, 이름 칸·값 칸 118, 트랙 6px r3 사선 + 25·50·75% 눈금, 채움 핑크 / #5d7288, 핸들 12×16 사선 + 바깥 2px #0d151f 링. `framed: false`로 사선 행(`.srow`) 안에 내용만 놓는다(d2 모달, 행 h48).
  - `StarRangeBar`: 9칸 사이 4, h14 r3 사선. 고른 구간 학생★ `starFilter` #e8c15a · 무기★ #71c7f4(FD-012), 좁혔으면 바깥 1.5px 핑크 링, 나머지 white@.06.
  - 조작(시안에 설명이 없어 정함): 슬라이더는 끌면 가까운 핸들이 따라오고, 누르면 가까운 핸들이 그 자리로 간다. 핸들마다 키보드 포커스와 ←/→(1씩)가 있고, 접근성은 slider(이름 "학생 레벨 최소/최대"). 성급은 칸을 누르면 가까운 끝이 오고, 끌면 누른 칸부터 지금 칸까지다. 키보드는 ←/→가 최대, Shift + ←/→가 최소다.
- **`frontend/lib/ui/kit/gallery/ui_kit_controls_section.dart`**: W-Filter 둘째 줄 범위 슬라이더(학생 레벨 70~90 · EX 1~M · 장비 티어 T0~T10)·성급 범위(★3~무기★1 · ★1~무기★4) 타일을 시안 위치(x 0 / 960.4, 980.5×250)에 더했다. 기존 3줄 배치는 그대로다.
- **`frontend/lib/ui/kit/ba_modal.dart`**(FE2-c 남은 일):
  - 포커스 가두기: 패널 FocusScope `TraversalEdgeBehavior.closedLoop`를 명시했다(기본값과 같음). Tab·Shift+Tab이 패널 안에서만 돈다.
  - 배경 접근성 차단: 열려 있는 동안 `BaModal.child`의 의미 구조를 뺀다. 화면 전체를 가리려면 BaModal이 화면 내용을 감싸게 둔다(d2 학생 탭은 화면을 child로 둔다). 스크림은 의미 구조가 없다.
  - Esc 이중 처리 방지: Esc 닫기는 그대로 `KitOverlayEscape`(가장 나중에 연 것 하나)다. 같은 Esc가 포커스 트리로도 가므로 모달 안 `Shortcuts`가 소비해, 모달을 연 라우트(다이얼로그 등)의 Esc 단축키가 함께 돌지 않는다. 모달 안에서 연 모달·팝오버는 Esc 한 번에 위의 것만 닫힌다.
- **`frontend/lib/ui/kit/ba_chip.dart`**: `BaChipShape.outlined`(r5 · 좌우 9 · 간격 5 · 안쪽 1px tone 기본색 @.6 · × @.8)와 폭 계산 `BaChip.widthFor`. 기본 모양(`standard`)은 값이 같다.
- **`frontend/lib/ui/widgets/student_section_layout.dart`**: S4 적용 필터 칩과 `+n`을 테두리 변형으로 그리고, 한 줄 칩 수 계산을 `BaChip.widthFor`로 바꿨다. 모달 머리 칩은 시안 `.chip.pk`라 기본 모양 그대로 쓴다(d2).
- **`frontend/lib/ui/app_shell.dart`**(최소 diff 2줄): 계정(프로필) 전환 때 `RecentStudents.clear()`(오케스트레이터 13:49 결정).

### 테스트

- 새 파일 5개, 36건:
  - `frontend/test/student_filter_selection_test.dart`(15): 행 순서·범위·표시(M, –, T, ★/무기★, 칩 문구), 성급 9단계, 3칸 중 가장 낮은 칸·합 0~75, 좁힌 범위(자르기·순서·전체면 해제·비교), 또는/그리고, 칩 개수(FD-056: 같은 그룹 무시·범위 반영·보유 · 서버), S4 토글 대응(FD-057), 적용 칩 목록·×·지우기, 칩 순서·화학 노출·협업 학교 제외, 심상개화 비활성, 현재 값 → 성장 값(미보유 초기 값).
  - `frontend/test/kit/range_controls_test.dart`(11): 행 모양(h44·118·좁힘 분홍·기본 강조 없음), 핸들 위치(70 → 77.5%, closeTo), 끌기·누르기(가까운 핸들, 최소 ≤ 최대), 키보드 ←/→·접근성 slider, 비활성, 성급 9칸 색·간격·링, 누르기·끌기·키보드(Shift).
  - `frontend/test/kit/ba_modal_a11y_test.dart`(4): Tab·Shift+Tab 가두기, 열려 있는 동안 배경 의미 구조 없음 → 닫으면 돌아옴, Esc 한 번에 모달만(바깥 Esc 단축키 0회, 닫힌 뒤에는 바깥으로), 모달 안 모달은 위의 것만.
  - `frontend/test/student_filter_followups_test.dart`(4): 테두리 칩 값·폭 계산 = 그린 폭, 기본 칩 불변, S4 적용 칩·`+n`이 테두리 변형, 계정 전환 때 최근 본 학생 비움(앱 전체, `SettingsPage.onProfileChanged`).
  - `frontend/test/kit/ui_kit_gallery_range_test.dart`(2): 갤러리 두 타일 크기·위치(closeTo), 견본 값, 견본 슬라이더 누르기.
- 고친 기존 테스트 0건, 지운 테스트 0건. 모달·OverlayPortal 테스트는 pumpAndSettle 대신 필요한 만큼 pump한다.
- 예상 건수: FE3-c 일반 테스트 수 + 36(FE3-c status 예상 582 기준이면 618), golden 18.

### 처리한 FD

- **FD-053**(확정): 범위 모델을 시안 의미로 재구성했다(모델·테스트). 화면 연결과 "닫아도 유지"(초안 → 적용)는 d2다.
- **FD-054**(확정): 심상개화는 비활성 자리 값만 두고 조건에 넣지 않는다.
- **FD-055 (a)**(워커 재량): 추가 능력치 = 합, 범위 0~75.
- **FD-056 (a)**(워커 재량): 칩 개수는 같은 그룹 조건을 빼고 다른 그룹 조건만 반영한다.
- **FD-057**(워커 재량): 선택 값에 S4 토글 대응을 두었다(연결은 d2).
- **FD-059**(워커 재량): 강화·서브 최소 0 → "–", 화학은 catalog에 있으면 칩이 된다.
- **FD-063**(워커 재량): 성장 범위 행을 그룹 목록으로 둬 늘릴 수 있다. 행 자체는 FE7-d.
- **FD-012**(워커 재량): 성급 범위 학생★ = `starFilter` #e8c15a.
- d2로 넘김: FD-052(Section 5·범위 카드 폐기), FD-058("필터 · n" 배지), FD-074 (b)(필터 프리셋 칩 숨김), FD-104(상태 객체 주입, 학생 탭 연결).

### golden 갱신 사유(장면별 예상)

- 바뀔 장면: 없음.
- 새 장면: 없음(`students-filter-open`은 d2).
- 차이가 없어야 할 장면(18): `title`, `account-manager`, `account-editor`, `account-picker`, `home`, `students-grid`, `students-detail`, `students-grid-name-off`, `plan-bottleneck`, `plan-by-phase`, `plan-overall`, `plan-phase-editor`, `plan-student-selector`, `plan-element-builder`, `plan-preset-manager`, `plan-scenario-list`, `plan-scenario-compare`, `scan-student-review`.
  - S4 적용 필터 칩은 golden 장면에서 "없음"이라 칩 모양 변경이 보이지 않는다.
  - 모달·범위 컨트롤은 golden 장면에 없다(UI Kit 갤러리는 golden 장면이 아니다).
  - 계정 전환은 golden 장면에서 일어나지 않는다.

### 검수표 (mock 모드, 2560×1440 모니터 최대화 = 2560×1392)

**W-Filter-Widgets 대조(개발 패널 → UI Kit 갤러리, FE2-b 구역 셋째 줄 아래 새 줄)**

| 대조 포인트 | 확인 |
|---|---|
| 범위 슬라이더 타일 | 980.5×250, 타일 제목 "범위 슬라이더", 아래 설명 "핸들 두 개 = 최소·최대. …" |
| 좁힌 행(학생 레벨 70~90) | 행 전체 연핑크 바탕 + 핑크 테두리, 이름 핑크, 트랙 오른쪽 22.5% 핑크 채움, 핸들 둘 연핑크(검은 링), 값 "70 ~ 90" 흰색 |
| 기본 행(EX 1~M, 장비 티어 T0~T10) | 바탕 거의 투명, 채움 회청(#5d7288) 전체, 핸들 회색, 값 회색. 장비 티어 아래 "3칸 중 가장 낮은 칸" |
| 눈금 | 트랙 25·50·75% 자리에 세로 짧은 선 |
| 조작 | 핸들을 끌면 값이 바뀌고, 기본값을 벗어나면 행이 핑크가 된다. 전체로 되돌리면 강조가 사라진다. Tab으로 핸들에 가서 ←/→ |
| 성급 범위 타일 | 위 행 ★3~무기★1: 3~5칸 노랑 + 6칸 파랑이 핑크 링, 나머지 어둡다. 아래 행 ★1~무기★4: 9칸 모두 색(노랑 5 + 파랑 4), 링 없음 |
| 성급 조작 | 칸을 누르면 가까운 끝이 그 칸으로, 끌면 끈 구간이 범위 |

**모달(UI Kit 갤러리 FE2-c 구역 모달 타일)**: 필터 스크림으로 열고 Tab을 여러 번 눌러도 포커스가 패널 밖(갤러리 버튼)으로 나가지 않는다. Esc 한 번에 닫히고 포커스가 연 버튼으로 돌아온다.

**Student S4(학생 탭)**: Section 5에서 학교 등을 고르면 S4 적용 필터 칩이 r5 모서리 + 연핑크 얇은 테두리로 보인다(이전 r7, 테두리 없음). 많이 고르면 끝의 회색 `+n`도 같은 모양이다.

**계정 전환**: 학생 몇 명을 눌러 최근 본 학생을 채운 뒤 설정에서 다른 계정으로 전환하면, 학생 탭의 최근 본 학생이 새 계정의 기본 선택 학생 한 명부터 다시 시작한다.

### 알려진 시안 차이

1. **슬라이더·성급 조작 규칙**: 시안에 동작 설명이 없어 정했다(가까운 핸들/끝, 끌기 구간, 키보드). 핸들·성급 막대의 키보드 포커스 표시는 파랑 링이다(키트 공통, 시안 근거 없음).
2. **값 글자 행간**: 시안 `line-height:1`이지만 앱은 한글 규칙(행간 최소 1.2, theme.dart)을 따른다. 세로 위치는 행 가운데라 차이가 작다.
3. **테두리 칩 ×**: 시안 S4는 글자 "×"(불투명도 .8)이고 앱은 키트 × 그림(11px, @.8)이다.
4. **S4 `+n` 칩**: 시안 S4에는 `+n`이 없다. FE3-c의 회색 `+n`을 같은 테두리 모양으로 맞췄다.
5. **모달 배경 접근성**: `BaModal`이 감싼 영역만 의미 구조에서 뺀다. 앱 머리(탭 줄)처럼 감싸지 않은 곳은 남는다. 화면 전체를 막는 `BlockSemantics`는 OverlayPortal과 함께 쓰면 오류 위험이 있어 쓰지 않았다(위 검토 1).

### 미검증 항목

1. analyze, 전체 테스트(기존 + 새 36), golden 18장(차이 0 예상). 사용자 PC gate가 필요하다.
2. 실행해 봐야 아는 것:
   - 모달 안 `Shortcuts`가 Esc를 소비하는 순서(`HardwareKeyboard` 처리기 → 포커스 트리).
   - `ExcludeSemantics`로 뺀 배경이 `find.bySemanticsLabel`에서 사라지는지.
   - 슬라이더 끌기 시작점(드래그 slop 뒤 위치)과 가까운 핸들 판정.
   - 앱 전체 테스트(계정 전환)의 pumpAndSettle.
   - 실패하면 테스트 기대값부터 확인한다.
3. 실제 글꼴에서 슬라이더 값·이름 칸이 118px 안에 들어가는지는 갤러리 검수로 본다.

### 발견 사항

1. **"필터 · n" 수와 머리 칩**: 시안 Student-Filter는 "필터 · 5"이고 머리 칩도 5개(게헨나·딜러·폭발·레벨 70~90·EX 3~5)다. 그런데 패널에서는 성급 행도 좁혀져 있고(`srow sel`) "일본 서버 전용 제외"도 켜져 있다. d2에서는 걸린 조건을 모두 칩과 개수에 넣는다(`activeCount` = 칩 수). 시안과 숫자가 다를 수 있다.
2. **칩 옆 학생 수 표시 범위**: 시안은 학교 줄에만 개수를 쓴다(다른 줄은 숫자 없음). 모델은 모든 칩의 개수를 셀 수 있다. d2에서는 시안대로 학교 줄에만 보인다.
3. **"보유 · 서버"와 S4 토글**: 팝업에서 "미보유"만 고르면 S4 "미보유 학생 숨김"은 꺼진 상태로 보인다(숨김이 아니라 미보유만 보기). S4 토글을 켜면 "보유"만 고른 상태가 된다.
4. **OverlayPortal + `BlockSemantics`**: 위 검토 1. 앱 전체 배경 차단이 필요하면 모달을 화면 셸 쪽에 두거나 라우트 기반으로 바꾸는 결정이 필요하다.

### 사용자 실행 순서

① 비교 gate 하나만 실행한다. golden은 18장 모두 차이 0이고 GREEN이 예상이다. 결과(`debug\frontend_gate\<실행 시각>\summary.txt`, 실패가 있으면 `frontend\test\goldens\failures\`)를 오케스트레이터에게 보내고 멈춘다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

② 오케스트레이터 승인 뒤: 이 slice는 golden 갱신이 없을 것으로 본다. ①이 GREEN이면 건너뛴다. golden 차이가 나서 오케스트레이터가 갱신을 승인한 경우에만 실행한다(GREEN 확인). 오케스트레이터가 바뀐 기준 PNG를 검토한다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

③ 승인 뒤: 커밋한다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3d1 -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3d1
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesign-docs
```

`debug/frontend_fe3d1/commit.json`의 `whole`에 `frontend/test/goldens/baseline`을 넣었다(바뀐 PNG가 없으면 올라가는 것이 없다). 사본은 `debug/frontend_fe3d1/pre/` 5개다: `app_shell.dart`, `ba_chip.dart`, `ba_modal.dart`, `ui_kit_controls_section.dart`, `student_section_layout.dart`.

### 다음 행동

1. 사용자: ①을 실행하고 결과를 오케스트레이터에게 넘긴다.
2. 오케스트레이터: 검토 → (②) → ③ → 다음 slice FE3-d2(모달 화면 연결, Section 5·범위 카드 폐기, golden `students-filter-open`).

### FE3-d1 gate RED 수정 (2026-10-07, 오케스트레이터 15:09 진단)

gate `20261007_150318` RED: analyze info 2, flutter-test-1 22건 실패. flutter-test-2·프로세스·golden 18(차이 0)·almanac·diff-check는 PASS였다. 이번에도 이 환경에서 Flutter를 돌리지 못했다. 고친 뒤 별도 검토 에이전트가 정적으로 다시 읽었고, 지적은 서식뿐이었다. 통과를 주장하지 않는다.

1. **의미 구조 assertion(128회, 갤러리 16건 + range_controls 성급 4건)**
   - 원인: `StarRangeCells`의 막대 의미 노드 하나가 increase/decrease 동작을 걸면서 increasedValue/decreasedValue를 주지 않았다("A SemanticsNode with action increase needs … both value and increasedValue or neither"). 슬라이더 핸들은 짝을 맞춰 줬다(그 테스트는 통과했다). 갤러리는 성급 막대를 그려 함께 무너졌다.
   - 수정: 성급 막대를 끝마다 slider 노드 두 개(`성급 최소`·`성급 최대`, 끝 칸 위)로 나눴다. 막대 노드는 이름·값만 가진다("성급 범위", "학생 2성 ~ 전용무기 2성"). 동작을 걸 때는 value·increasedValue·decreasedValue를 항상 함께 주고, 끝값이라 못 움직이면 그 동작과 짝 값을 함께 뺀다(슬라이더 핸들도 같은 규칙으로 정리).
   - 값 문구는 읽는 말이다. 슬라이더는 "학생 레벨 최소 70", 성급은 "성급 최소 학생 3성"·"성급 최대 전용무기 1성"이다. 새 `semanticValue` 인자(기본 = 표시 문구), `starRangeStepSpoken`, 모델 `StudentGrowthRangeRow.formatSpokenValue`(티어 "7티어", 스킬 0 "미개방")를 더했다.
2. **모달 배경 의미 구조(ba_modal_a11y_test:130)**
   - 원인(테스트 쪽으로 판단): `find.bySemanticsLabel`은 위젯의 `debugSemantics` 캐시를 본다. `ExcludeSemantics`로 빠진 하위 렌더 객체는 의미 갱신에서 방문되지 않아 마지막 노드가 캐시에 남는다. 실패 로그도 "배경 버튼" 렌더 객체 하나를 찾았을 뿐이고, 의미 트리에 그 노드가 붙어 있다는 증거는 아니다.
   - 방식: 두 방식 중 `ExcludeSemantics`를 유지한다. `BlockSemantics`는 OverlayPortal 안에 두면 OverlayPortal 자리(traversal parent)의 노드까지 지워 오류 위험이 있다(첫 검토). 이 구조에서는 BaModal이 감싼 child를 열려 있는 동안 빼는 쪽이 동작한다. traversal parent `Semantics`는 그 바깥에 있다.
   - 수정: 테스트를 의미 트리 직접 조회(`find.semantics.byLabel`)로 바꿨다. 열기 전 "배경 버튼" 1개 → 열린 동안 "배경 버튼"·"열기" 0개, 패널 "가" 1개 → 닫으면 다시 1개.
   - 이번에도 실패하면 `ExcludeSemantics`가 이 구조에서 안 먹는다는 뜻이다. 그때는 모달을 화면 셸 쪽 OverlayEntry로 옮기는 결정이 필요하다.
3. **RangeSliderRow 위치 3px(range_controls_test:113, 기대 488.3 / 실제 485.3)** — **구현이 틀렸다.**
   - 시안 확인(dc_outline + 해당 요소 원문): W-Filter-Widgets 행은 `height:44px; padding:0 14px; border-radius:6px; box-shadow:inset 0 0 0 1.5px #f2b3ef`이다. 이름·값 칸은 각각 118px이다. Student-Filter `.srow`도 안쪽 18.5 + 118 + 트랙 + 118이다. inset 그림자는 자리를 차지하지 않으므로 트랙 폭 = 행 − 28 − 236이고, 테스트 기대값이 맞다.
   - 원인: 좁힌 행의 테두리를 `BoxDecoration.border`로 줘서 Container가 테두리 두께(1.5 × 2 = 3)를 안쪽 여백에 더했다. 좁힌 행만 트랙이 3px 줄고 기본 행과 어긋났다.
   - 수정: 테두리를 `foregroundDecoration`으로 위에 그린다(테스트에 `decoration.border == null`, 앞 장식 1.5px 확인 추가).
4. **analyze deprecated 2건**: `containsSemantics` → `isSemantics`(range_controls_test). 344행 "No Semantics data found"는 1번 assertion 때문이었다. 1번을 고친 뒤 막대·끝 노드를 각각 확인하게 다시 썼다.
5. **"Looking up a deactivated widget's ancestor is unsafe"**(갤러리 탭 중 `_HighlightModeManager` → `FocusableActionDetector`가 MediaQuery 조회)
   - 원인: 1번 assertion으로 프레임이 깨진 사이 비활성 상태로 남은 detector가 강조 모드 알림을 받은 것으로 본다.
   - 수정: 핸들·성급 막대에서 `FocusableActionDetector`를 없앴다. `Focus`(onFocusChange·onKeyEvent) + `MouseRegion`(커서) + 강조 모드 리스너 mixin으로 포커스 표시를 직접 계산한다. 리스너는 initState에서 달고 dispose에서 뗀다. 콜백은 MediaQuery를 찾지 않고 `mounted`를 확인한다. build 중 key가 바뀌는 자리도 없다(핸들 key는 고정 `range-handle-low/high`, 성급 끝은 `star-range-low/high`).

**바뀐 파일(이번 수정)**
- `frontend/lib/ui/kit/range_controls.dart`
- `frontend/lib/ui/kit/gallery/ui_kit_controls_section.dart`(견본 `semanticValue`)
- `frontend/lib/ui/models/student_filter_selection.dart`(`formatSpokenValue`)
- `frontend/test/kit/range_controls_test.dart`(12건, 끝값 테스트 1건 추가)
- `frontend/test/kit/ba_modal_a11y_test.dart`
- `debug/frontend_fe3d1/commit.json`(목록은 같고 메시지만 갱신). `ba_modal.dart`는 이번에 바꾸지 않았다.

**예상**: 새 테스트 37건(15 + 12 + 4 + 4 + 2), golden 18장 차이 0.

**사용자 실행 순서(수정 뒤)**: d1은 화면 변화가 없다. ① GREEN이면 바로 ②~④를 실행한다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3d1 -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3d1
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesign-docs
```

### FE3-d1 commit record (2026-10-07 15:51, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261007_154648\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none
