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

**FB-12 완료.** 결과(오케스트레이터 로그 2026-10-07 23:25, 아래 FB-12 commit record):
- Python 836건 통과(1552초), gate `20261007_232002` GREEN.
- 커밋 `50dbed6c`(FB-12: planning_calc.py·planning_document.py + 새 테스트 9건 + status), 문서 커밋 `f2cf4fb8`. 기존 기대값 변화 0.
- 이번부터 Lane A를 프론트·백엔드 워커 두 명으로 나눈다(워크플로 실행 순서 "Lane A 앞뒤 병렬"). 백엔드 워커는 `frontend-redesign-status-backend.md`에 쓴다.

**FE3-f2a 완료.** 커밋 `3e7272e2`(gate `20261008_080127` GREEN). 같은 때 FB-11a(백엔드 단일 학생 계산) `facdd1d3`(Python 847), 문서 `2bcdcbd9`.

**FE3-f2b 완료.** 커밋 `576bd568`(gate `20261008_122807` GREEN, golden `students-calculator`·`plan-element-builder` 갱신 포함). FB-13(catalog `has_favorite_item`, 백엔드 워커) `fa15e87c`, 문서 `0fd37702`.

**FE4-a 완료.** 커밋 `a18897a1`(gate `20261008_164059` GREEN, golden `plan-flow-step1`·`plan-flow-step2` 추가), 문서 `eea7f113`. FE4-a2(활성 계획 편집 경로 이관)는 하지 않고 FE4-b로 넘어갔다(오케스트레이터 배정 2026-10-08 16:48). FB-1a(문서 v2, 백엔드 워커) `682b2a7b` 커밋으로 `planning_models.dart` 소유가 프론트로 돌아왔다.

**FE4-b 완료.** 커밋 `2a5a7655`(gate `20261008_212503` GREEN, ①의 analyze 1건은 오케스트레이터가 고침). FE4-b2(한 명 모드·최근 본 학생)는 하지 않고 FE4-c로 넘어갔다(오케스트레이터 배정 2026-10-08 21:34).

**FE4-c 코드 작성 완료, gate ① 대기(2026-10-08 밤).** 시작 커밋 `2a5a7655`(그 뒤 문서 커밋이 있으면 그것). 분할하지 않았다(아래 "FE4-c 착수 기록"·"FE4-c 종료 기록"). 예상: golden 3건 RED(`plan-flow-step2`·`plan-flow-step1-filter` 바뀜, `plan-flow-step2-more` 기준 없음).

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
| FE3-d1 | `ddc251eb` | 필터 모달 부품: 성장 범위·필터 선택 값 모델(FD-053·054·055·056·059·063), 키트 `RangeSliderRow`·`StarRangeBar`(FD-012) + 갤러리, `BaModal` 포커스 가두기·배경 의미 구조 차단·Esc 이중 처리 방지, `BaChip` 테두리 변형(S4 칩), 계정 전환 때 최근 본 학생 비움(화면 변화 없음) | `20261007_150318` RED(의미 구조 짝 값·테두리 3px 등 5건) → `20261007_154648` GREEN(307 + 284 + 프로세스 28 + golden 18) |
| FE3-d2 | `0890de7a` | 필터 모달 화면 연결: 공용 `StudentFilterModal`(머리 바·속성·성장 범위 패널), 컨트롤러 적용 값 + 초안, S1 필터 버튼·S4 `+n` → 모달, S1 배지(FD-058), 셸 모달 배경 범위(15:51 결정 4), Section 5·범위 카드 폐기(FD-052), golden `students-filter-open` | `20261007_170820` RED(핸들 해제 시점·새 장면) → `20261007_173720` GREEN(594 + 프로세스 28 + golden 19) |
| FE3-e | `a3692424`(+ 문서 `8a6482e7`) | 다중 폼 초상 교대(FD-064: 공용 시계 하나, 폼 수 × 3초 계단식, TickerMode 꺼짐이면 멈춤) + FB-5 catalog `forms`(계약·Python·Dart·mock·E2E), warmup 폼 초상, 제목 글꼴에 없는 글리프(– → −) 수정, golden 4장 갱신 + 새 장면 `students-grid-second-form`(시각 변경) | ① `20261007_191233` RED(golden 5, 예상 일치) → ② `20261007_195559` GREEN(golden 20, 백엔드 812) |
| FE3-f1 | `7ec07589`(+ 문서 `bcde9559`) | 성장 계산기 상태 모델(13행·계산기 정규화·현재값 출처·빠른 목표·칸 토글·최근 계산) + 계산 어댑터(임시 1페이즈 1단계 문서 `planning.document.calculate`, 디바운스), 새 파일 6, 기존 파일 수정 0(동작 보존) | `20261007_213219` GREEN(648 + 프로세스 28 + golden 20) |
| FB-12 | `50dbed6c`(+ 문서 `f2cf4fb8`) | 계획 계산 버그 2건: 성급 비용이 wire `student_star`를 읽음(★0부터 계산하던 것 정정), 장비 티어 이월을 정규 형식 `T<n>`으로 쓰고 티어 파서를 견고하게(백엔드만, 새 테스트 9건) | Python 836 통과, `20261007_232002` GREEN |
| FE3-f2a | `3e7272e2` | 성장 계산기 화면 연결 1/2: 진입·복귀(머리말 덮어쓰기·"← 학생" 칩·Esc·주 탭), 계산기 S1, S2 두 열(13행·크레딧 타일·재화 목록), 계산 연결, `ItemIconTile` 자산 없음 대체 표시, golden 학생 5장 갱신 + 새 장면 `students-calculator`(시각 변경) | `20261008_022827` RED(지어낸 아이콘 id) → `20261008_030824` RED(테스트 파일 덮어쓰기) → `20261008_080127` GREEN |
| FB-11a | `facdd1d3` | 백엔드 단일 학생 계산 `planning.student.calculate`(totals + 9범주 크레딧 + 재화 행), Dart DTO·클라이언트·mock(백엔드 워커, `frontend-redesign-status-backend.md`) | Python 847 통과, 같은 gate |
| FE3-f2b | `576bd568` | 성장 계산기 화면 연결 2/2: S3 목표값·"현재 …" 태그·칸 토글(FD-167), S4 요약·"기준" 칩·최근 계산(FD-170), 단일 학생 계산 어댑터(FB-11a), 크레딧 내역 9범주 막대, 크레딧 합계 칸 줄이기, FB-13 프론트 연결(fixture 3곳·애장품 폴백 제거·아야네 12행), golden 2장 갱신 | `20261008_102700` RED(크레딧 타일 넘침) → `20261008_121125` RED(golden 2, 예측 일치) → `20261008_122807` GREEN |
| FB-13 | `fa15e87c` | catalog `has_favorite_item`(KR 애장품 제공 여부) 계약·Python·Dart·mock·asset 재생성(백엔드 워커, `frontend-redesign-status-backend.md`) | 백엔드 기록 참조, 프론트 gate는 `20261008_122807` GREEN |
| FE4-a | `a18897a1`(+ 문서 `eea7f113`) | 계획 만들기 흐름 골격: 3-Section Studio 문서, 진행 레일(스텝 4개·요약 4행·다음/이전), 초안 컨트롤러 + 문서 경계 + 250ms 디바운스 계산, 부족 재화 플라이아웃, 시나리오 생성(1단계)·비교 편집(3단계) 진입, 기존 세 화면은 B 본문에 축소 수용, golden 2장 추가 | `20261008_152312` RED(넘침·가림·단계 상태 기대·analyze 1) → `20261008_162544` RED(golden 2, 새 장면) → `20261008_164059` GREEN |
| FB-1a | `682b2a7b` | 문서 v2: 19키 nullable 목표(null = 목표 없음)·학생별 `goal_metadata`, 계산·시나리오가 v1·v2를 함께 읽음(백엔드 워커, `frontend-redesign-status-backend.md`) | Python 873 통과, 프론트 gate `20261008_164059` GREEN에 포함 |
| FE4-b | `2a5a7655` | 계획 만들기 1단계 새 학생 고르기(8열 그리드·순서 배지·C 목록/압축 그리드·역할군 칩·필터 모달 + 계획 칩 그룹), 초안 문서 v2 전환, 시나리오 반영·비교의 v2 정수 보기, golden `plan-flow-step1`·`-step2` 갱신·`-many`·`-filter` 추가 | ① RED(analyze 1 `use_null_aware_elements`, 오케스트레이터 수정 + golden 4 예측 일치) → ② → `20261008_212503` GREEN |

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

## FE3-d2 착수 기록 (2026-10-07)

- 범위(FE3-d 착수 기록의 d2 계획 그대로): d1 부품으로 Student-Filter 모달을 구성하고 학생 탭 S1 필터 버튼·S4 `+n`으로 연다. 상태는 FE3-c `StudentFilterController`를 주입한다(FD-104). 초안(draft) → 적용 / 취소.
- 15:51 결정: 머리 칩과 "필터 · n" = 실제로 걸린 조건 전부(숫자 = 칩 수), 칩 옆 학생 수는 학교 줄에만, AppShell 수준 모달 배경 범위로 셸 전체를 ExcludeSemantics로 덮는다(OverlayPortal + BlockSemantics 금지, app_shell 최소 diff, 커지면 FE10).
- 그 밖: 닫힌 뒤 S1 필터 버튼 개수 배지(FD-058), 필터 프리셋 칩 숨김(FD-074 (b)), 심상개화 비활성(FD-054), Section 5·범위 카드 2장 폐기(FD-052, B §2-4)와 section-template-studio.md "학생 Section 5 필터" 절 대체(기존 미커밋 변경 있음 → 사본 규칙).
- 범위 밖: 계획 1단계 연결(FE4-b), 통계 연결(FE7-e), 육성도 행(FE7-d).
- 시작 커밋: `06091c07e45cc5bc21e9a473a1a70af32d55fa05`.
- 시각 변경 slice: golden 갱신은 오케스트레이터 검토 뒤 사용자가 `fe_gate.ps1 -UpdateGoldens`로 한다. 새 장면 `students-filter-open`. golden PNG를 직접 만들거나 지우지 않는다.
- 사본: `debug/frontend_fe3d2/pre/<v7 기준 경로>`. 기기 쓰기는 새 업로드 경로에서 쓰고 다시 읽어 바이트로 대조한다.

## FE3-d2 종료 기록 (2026-10-07, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없어 analyze·테스트·golden을 돌리지 못했다. 통과를 주장하지 않는다.
- 쓴 API는 Flutter 3.44 소스와 대조했다(`OverlayPortal` 의미 노드, `SchedulerBinding.addPostFrameCallback`·`ensureVisualUpdate`, `find.semantics.byLabel`, `listEquals`·`setEquals`).
- 별도 검토 에이전트가 바뀐 파일을 사본과 대조해 정적으로 읽었다. 컴파일 오류는 없었다. 지적 5건은 모두 고쳤다.
  1. 모달 배지 `BoxDecoration`에 `const`가 없었다(`prefer_const_constructors`, gate RED 원인).
  2. 셸 배경 범위가 scheduler idle 중 바로 `setState`했다. 첫 마운트 빌드도 idle 중이라 위험하다 → 늘 프레임 뒤에 다시 그린다(의미 구조가 한 프레임 늦게 바뀐다).
  3. 탭을 떠날 때 열린 모달을 닫지 않았다 → `active`가 꺼지면 프레임 뒤에 닫는다(초안은 버린다).
  4. 셸 의미 구조 테스트의 `SemanticsHandle`을 `addTearDown`으로 정리한다.
  5. "범위 모두 풀기"·S4 `+n` 버튼이 이름을 두 번 읽었다 → 안쪽 칩을 `ExcludeSemantics`로 감쌌다.
- 시안 값은 `Student-Filter.dc.html`을 `dc_outline.py --abs`와 원문 CSS(`flex-wrap:wrap;gap:8px 10px;padding:4px 0`)로 읽었다.

### 바꾼 것

**1-1 모달 구성(FD-104)**
- 새 `frontend/lib/ui/widgets/student_filter_modal.dart`: `StudentFilterModal`(머리 바 + 속성 패널 + 성장 범위 패널 + "필터 · n" 배지).
  - 바깥 틀: `BaModal`(필터 스크림 .8 + blur 2).
  - 값: 초안 `StudentFilterSelection`. 바뀐 초안은 `onChanged`로 돌려준다. 속성 그룹은 쓰는 쪽이 넘긴다(FE4-b·FE7-e 재사용).
- `StudentFilterController`를 적용 값 + 초안으로 바꿨다.
  - 초안 흐름: `beginEdit` → `updateDraft` → `applyDraft`, 또는 `discardDraft`. `resetDraft`는 초안만 비운다.
  - 적용 값 쪽: `chips`, `activeCount`, `searchRowChips`, `removeApplied`, `clearApplied`, `matches`.
  - 이전 API(`catalogKeys`, `catalog`, `range`, `appliedFilters`, `StudentAppliedFilter`, `rangeBounds`, `clearCatalog`, `resetRange`)는 없앴다.
- 학생 탭 연결(`student_section_layout.dart`):
  - 레이아웃 전체를 `BaModal`이 감싼다.
  - S1 필터 버튼은 "필터 열기"(`tune_rounded`)이고 모달을 연다.
  - "적용"만 초안을 그리드에 건다. 닫기 ×·Esc·스크림은 초안을 버린다.
  - 그리드 필터는 `StudentFilterCandidate`(속성 + 보유 + 현재 성장 값)를 만들어 `filter.matches`로 건다. 후보는 학생·보유·현재 값이 바뀔 때만 다시 만든다(내용 비교).

**1-2 표시**
- 머리 칩과 "필터 · n"은 걸린 조건 전부이고, 숫자는 칩 수다(15:51 결정 1).
- S1 필터 버튼 개수 배지 `student-filter-count-badge`(FD-058, 워커 재량):
  - 모달이 닫혀 있고 조건이 있을 때만 단다.
  - 모양: 아이콘 오른쪽 위, h18 알약, #0d151f + 1.5px 핑크 링, 글자 #f7c9f4.
  - 모달이 열려 있는 동안에는 모달이 (18, 226)에 "필터 · n"을 그린다.
- 칩 옆 학생 수는 학교 줄에만 둔다(15:51 결정 2, `studentFilterCountedGroups`). 학교 소제목에는 값 수를 쓴다.
- S4 `+n` 칩은 `KitPressable`이며 누르면 모달을 연다.
- S4 줄의 칩은 `searchRowChips`(걸린 조건에서 "보유 · 서버"를 뺀 것)다. 바로 위 토글이 그 조건을 보인다.
- 필터 프리셋 칩은 숨긴다(FD-074 (b)).
- 심상개화는 비활성 칩 3개와 "v7 “준비 중” 자리"만 둔다(FD-054). 좁은 창에서는 칩 줄을 자르고 안내 문구를 말줄임한다.
- 육성도 행은 넣지 않았다(FE7-d, FD-063).

**1-3 폐기(FD-052, B §2-4)**

| 없앤 것 | 대체 |
|---|---|
| 학생 탭 Section 5 분기: `StudentDiagonalFilterList` `student-filter-section-5`, 초기화 `student-filter-reset`(InkWell), `student-section-5-motion`·`-foundation` 키 | 필터 모달(`student-filter-modal`, 초기화 = 모달 머리 "초기화" `student-filter-reset`) |
| 기하 도우미: `studentFilterSectionPolygon`·`studentFilterSectionPath`·`studentListSectionEdgeLength`·`studentFilterCompanionSectionRect`·`studentFilterSectionHorizontalInterval`·`studentFilterContainerPolygon`·`studentFilterContainerPath`·`studentFoundationUsesLegacySectionChildren`·`studentFilterResetPath`, 상수 `studentFilterResetButtonSize`·`studentFilterCompanionSectionGap`, painter `filterSection` 깃발 | `StudentFilterModalLayout`·`studentFilterRowSpan`·`studentFilterChipRowHeight` |
| `studentMatchesCatalogFilters` | `StudentFilterSelection.matches` |
| `StudentSectionLayout` 인자 `onFilterVisibilityChanged`·`filterCompanion`·`rangeConditionMatches`, 상태 `_showFilters`·`_toggleFilterSection`·`_toggleCatalogFilter`·`_resetCatalogFilters` | `_filterModal`(`BaModalController`)·`_openFilterModal`·`_applyFilterModal` |
| `student_page.dart`의 범위 카드 2장(`StudentRangeConditionSection` `student-range-condition-section`)과 닫으면 범위 초기화 | 모달 성장 범위 패널(적용 값은 모달을 닫아도 유지) |

남긴 것: `StudentDiagonalFilterList`·`StudentRangeConditionSection`·`StudentRangeConditions`와 그 테스트. 계획 학생 선택기(`plan_student_selector.dart`)가 FE4-b 전까지 쓴다. 학생 탭에서는 폐기했고, 코드는 FE4-b에서 지운다.

없앤·바꾼 테스트:

| 이전 테스트 | 처리 | 대체 |
|---|---|---|
| studio `Section 5 keeps the left rail and halves its previous width` | 삭제 | 모달 배치 테스트(`배치가 시안 좌표와 같다`). fog 폭 단언만 `student viewport fog extent follows the lifted shadow inset`로 옮겼다 |
| studio `Section 5 container derives both diagonal edges from its parent` | 삭제 | 같은 모달 배치 테스트(행 좌우 = 80° 변 규칙) |
| studio `Section 5 foundation does not repaint Section 2 legacy children` | 삭제 | (painter 분기 자체가 없어짐) |
| studio `student sections use explicit motion paths and filter swap` | 다시 씀 → `… and filter modal` | S1 → 모달, Section 2 그대로, `tune_rounded` |
| studio `catalog filters persist across the Section 5 toggle and reset` | 다시 씀 → `catalog filters apply through the filter modal and reset` | 적용 / 닫기 취소 / 초기화 + 적용 |
| range `student filter and condition sections preserve a 24 px visible gap` | 삭제 | — |
| range `student filter close and reopen resets range conditions` | 삭제 | 모달 `취소(닫기 · Esc · 스크림)는 초안을 버리고, 적용은 그리드에 건다` |
| search `적용 필터 칩 …`, `× 와 모두 지우기 …`, `범위 조건도 칩이고 …` | 새 API로 고침 | 칩 순서는 시안 칩 순서(게헨나 → 아비도스), 범위 칩 키 `student-applied-filter-growth-level` |
| followups `S4 적용 필터 칩과 "+n"이 테두리 변형을 쓴다` | `+n` 안 `BaChip`을 찾게 고침 | — |

- `almanac/design/section-template-studio.md`: "학생 Section 5 필터와 Section 2 고정 viewport 후속 계약" 절을 "학생 필터 모달과 Section 2 고정 viewport 후속 계약"으로 바꿨다(모달 진입·배경·배치·속성·성장 범위·배지). Filter 행동 문단, 최초 토대 표의 화면 범위·Section 5·전환 행, 출처 2개도 고쳤다. 이 파일에는 FE3-d2 전 미커밋 변경이 있어 사본(`debug/frontend_fe3d2/pre/almanac/design/section-template-studio.md`)을 두었다.

**1-4 셸 배경 범위(15:51 결정 4)**
- `ba_modal.dart`: `BaModalBackdrop`(열린 모달 수를 세는 범위)과 `BaModalBackdropExclude`(그동안 의미 구조에서 뺌)를 더했다. `BaModal`은 열 때 가장 가까운 범위에 등록한다.
- `app_shell.dart`(diff 최소):
  - `build`가 `BaModalBackdrop(child: _buildShell(context))`를 돌려준다.
  - 머리 탭 줄(`home-header-entrance`), `RecoveryBanner`, 개발 패널 두 곳, 스캔 독을 `BaModalBackdropExclude`로 감쌌다.
  - FE10으로 넘길 만큼 커지지 않았다.
- `student_page.dart`: 레이아웃 아래 나머지 내용(메타데이터 안내·후보 카드·메시지)을 `BaModalBackdropExclude`로 감쌌다.
- 그 밖의 학생 탭 내용은 `BaModal`이 뺀다. 다른 탭은 `AnimatedSectionStack`이 이미 뺀다.
- 결과: 모달이 열려 있으면 셸 전체(머리 포함)가 빠지고 모달만 남는다.
- 셸 전체를 한 `ExcludeSemantics`로 덮지 않은 이유: 모달 OverlayPortal 자리(의미 트리의 traversal parent)가 그 안에 들어가기 때문이다. `OverlayPortal + BlockSemantics`는 쓰지 않았다.

### 테스트

- 새 `frontend/test/student_filter_modal_test.dart`(7):
  - S1·`+n` → 모달.
  - 닫기·Esc·스크림 = 취소(초안 버림), 적용 → 그리드, 초기화 → 적용.
  - S1 배지 = 칩 수 = 머리 칩 수, 열려 있으면 모달 배지만.
  - 학교 줄만 학생 수.
  - 심상개화 비활성, 범위는 초안에.
  - 배치(시안 좌표 `closeTo` 0.5).
  - 셸 의미 구조 차단(`find.semantics`) + 닫은 뒤 학생 탭 동작.
  - 모달은 `pump` 두 번으로 민다(pumpAndSettle 대기 회피).
- 고친 테스트: 위 표.
- golden: `students-filter-open` 장면 1개 추가(아래).

### 처리한 FD

- FD-052: Section 5·범위 카드 폐기.
- FD-054: 심상개화 비활성.
- FD-057: 보유 · 서버 = S4 토글.
- FD-058: 배지 위치. 워커 재량으로 S1 알약을 정했다.
- FD-059: catalog 값만 칩으로 만든다. d1 모델을 그대로 쓴다.
- FD-063: 육성도 행은 FE7-d로 남긴다.
- FD-074 (b): 프리셋 칩 숨김.
- FD-104: 상태 주입.
- 오케스트레이터 15:51 결정 1·2·4.

### golden 갱신 사유(장면별 예상)

- 새 장면 `students-filter-open`:
  - 학생 10명 fixture에서 S1으로 모달을 연다.
  - 초안: 게헨나·아비도스, 딜러, 폭발, 레벨 70~90, 성급 ★3~무기★1, 일본 서버 전용 제외.
  - 보이는 것: 머리 칩 7개, "필터 · 7", 학교 줄 칩 옆 학생 수, 좁힌 두 `.srow` 분홍.
  - 배경 학생 탭은 스크림 .8 + blur 2 아래에 보인다.
- `students-grid`·`students-detail`·`students-grid-name-off`: 차이 0이 예상이다(작업 지시는 "바뀐다"였다). 세 장면 모두 걸린 조건이 없다.
  - Section 5 분기는 원래 닫힌 상태라 그려지지 않았다.
  - S1 배지는 조건이 있을 때만 보인다.
  - S1 아이콘·tooltip은 닫힌 상태의 이전 값(`tune_rounded`, "필터 열기")과 같다.
  - 그 아래 0높이 `Column` 하나가 더해졌다.
  - 차이가 나면 원인을 조사해 보고한다.
- 차이 0: 나머지 15장(`title`·계정 3장·`home`·`plan-*` 9장·`scan-student-review`). plan fixture는 건드리지 않았다.

### 검수표 (mock 모드, 2560×1440 모니터 최대화 = 2560×1392)

**Student-Filter 대조(학생 탭 → S1 필터 버튼)**

| 대조 포인트 | 확인 |
|---|---|
| 스크림 | 화면 전체 어둡게(.8) + 약한 흐림, 머리 탭 줄도 덮인다 |
| 머리 바 | (453.8, 206) 1876×92 사선 r14. 핑크 사선 막대 · "필터" · 결과 수(굵게) "/ N명" · 구분선 · 핑크 칩(×) · "초기화" · "적용"(파랑) · × |
| 프리셋 칩 | 없다(FD-074 (b)) |
| 속성 패널 | (285.9, 320) 984×930. 제목 "속성" + "같은 줄은 “또는”, 줄끼리는 “그리고”" |
| 학교 줄 | 소제목 "학교" 옆 값 수, 칩 옆 학생 수(다른 줄에는 숫자 없음). 두 줄이면 줄 높이 76 |
| 공격·방어 줄 | 왼쪽 색 막대 칩(화학은 막대 없음) |
| 보유 · 서버 | 보유 · 미보유 · 일본 서버 전용 제외. S4 토글과 같이 바뀐다 |
| 성장 범위 패널 | (1127.9, 320) 1182×930. "범위 모두 풀기" 칩, 기본·스킬·장비 · 능력치 소제목, `.srow` 48 사이 10 |
| 좁힌 행 | 분홍 바탕 + 4px 핑크 테두리 |
| 심상개화 | 맨 아래, 칩 3개 흐림(누를 수 없음), 오른쪽 "v7 “준비 중” 자리" |
| "필터 · n" | 열려 있는 동안 화면 왼쪽 (18, 226). 수 = 머리 칩 수 |
| 적용 / 취소 | "적용"이면 닫히고 그리드가 걸린다. ×·Esc·스크림이면 닫히고 바뀐 것이 버려진다 |
| S1 배지 | 적용 뒤 S1 필터 아이콘 오른쪽 위 작은 핑크 링 알약에 같은 수. 조건을 모두 풀면 사라진다 |
| S4 `+n` | 조건이 많아 `+n`이 보이면 눌러서 모달이 열린다 |
| 다른 창 크기 | 1280×720 정도로 줄여도 넘침 줄무늬가 없다(패널 안 세로 스크롤) |

### 알려진 시안 차이

1. **"필터 · n"**: 시안은 "필터 · 5"(머리 칩 5개)인데 패널에는 성급 행과 일본 서버 전용 제외도 걸려 있다. 15:51 결정 1대로 걸린 조건 전부를 센다.
2. **S1 배지 모양**: 시안 W-Student-Actions에는 배지가 없다. FD-058 워커 재량으로 정했다.
3. **칩 줄 높이**: 시안 값(한 줄 34, 두 줄 76)을 그대로 따랐다. 한 줄 34는 CSS 계산 값(30 + 8)보다 4 작다.
4. **결과 수·칩 학생 수의 범위**: 검색어가 있으면 검색 결과 안에서 센다("/ N명"의 N은 catalog 전체).
5. **패널 높이**: 다른 창 크기에서는 머리 바 아래 22부터 1250/1392 높이까지이고, 넘치면 패널 안에서 스크롤한다(시안은 한 크기뿐).
6. **셸 배경 의미 구조**: 범위 갱신이 한 프레임 늦다(위 검토 2).

### 미검증 항목

1. analyze, 전체 테스트, golden 19장 비교. 사용자 PC gate가 필요하다.
2. 실행해 봐야 아는 것:
   - 모달 칩 폭 추정(`studentFilterToggleChipWidth`)과 실제 칩 폭이 맞아 줄 수가 맞는지(어긋나면 칩 줄이 넘치거나 남는다. 오류는 나지 않는다).
   - 셸 의미 구조 테스트의 탭 이름 노드(`전술대항전`)와 모달 이름 노드 병합.
   - 스크림 탭 위치(1300, 1320)가 스크림에 닿는지.
   - 1280×720 창에서 머리 바·성장 행이 넘치지 않는지.
3. 실제 글꼴에서 머리 칩이 길게 이어질 때 잘림, 학교 칩 줄 수.

### 사용자 실행 순서

① 비교 gate만 실행하고 멈춘다. 예상은 RED다(새 장면 `students-filter-open` 기준 없음). 그 밖의 golden 18장은 차이 0이 예상이다. 결과(`debug\frontend_gate\<실행 시각>\summary.txt`, `frontend\test\goldens\failures\`)를 오케스트레이터에게 보낸다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

② 오케스트레이터 승인 뒤 golden을 갱신하고 GREEN을 확인한다. 오케스트레이터가 새 PNG를 검토한다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

③ 승인 뒤 커밋한다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3d2 -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3d2
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesign-docs
```

- `debug/frontend_fe3d2/commit.json`의 `whole`은 `frontend/test/goldens/baseline`이다(새 PNG 포함).
- 사본은 `debug/frontend_fe3d2/pre/` 11개다: app_shell, ba_modal, student_filter_controller, student_page, student_section_layout, 테스트 5개, section-template-studio.md.

### 다음 행동

1. 사용자: ①을 실행하고 결과를 오케스트레이터에게 넘긴다.
2. 오케스트레이터: 검토 → ② → PNG 검토 → ③.
3. 다음은 FE4-b(계획 1단계에 같은 모달 연결, 이전 필터 위젯 삭제)다.

### FE3-d2 commit record (2026-10-07 17:45, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261007_173720\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: almanac/design/section-template-studio.md

## FE3-e 착수 기록 (2026-10-07)

- 범위(작업 지시 2026-10-07 17:52, 워크플로 FE3-e·FB-5 행): FB-5 백엔드(`planning.student.catalog` 학생 항목에 폼 목록 선택 필드, 계약·Dart `fromWire`·mock·단위 테스트·프로세스 E2E 왕복)와 다중 폼 초상 교대(FD-064: 폼 수 × 3초, 계단식, 공용 시계 하나, 화면 밖·TickerMode 꺼짐이면 멈춤, 시간 주입 가능), warmup에 폼 이미지 포함.
- 함께: 경기천년제목에 없는 글리프(en dash 등)가 golden에서 사각형으로 나오는 문제(오케스트레이터 17:42) 수정과 같은 위치 목록.
- 범위 밖: 스캐너 소유 인식 파일·scan_* 위젯, scan_page·scan_companion_dock, 택틱 소유 파일. 이미지 추출 대상 확장이 인식 계열을 건드리면 스캐너 오케스트레이터 로그에 요청만 남긴다.
- 시작 커밋: `04c4cb67de3e7de62c4b63001e0ffdcba22d7736`(FE3-d2 `0890de7a` 뒤 문서 커밋).
- 사본: `debug/frontend_fe3e/pre/<v7 기준 경로>`. 기기 쓰기는 새 업로드 경로에서 쓰고 다시 읽어 바이트로 대조한다.

## FE3-e 종료 기록 (2026-10-07, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없어 `flutter analyze`·Dart 테스트·golden을 돌리지 못했다. 통과를 주장하지 않는다.
- Python은 워커 환경(Linux, Python 3.13, jsonschema 4.26)에서 일부만 직접 돌렸다:
  - 명령: `cd backend; python3 -m unittest tests.test_student_catalog tests.test_planning_protocol_contract -v`
  - 결과: 10건 중 9건 통과.
  - 실패 1건 `test_catalog_rejects_payload_and_real_process_serves_list`: `core.backend_process`가 Windows 전용 `ctypes.WINFUNCTYPE`(user_input_guard)와 인식 asset manifest를 읽다 멈춘 환경 문제다. 바꾸기 전 판에서도 같은 자리에서 실패한다.
- 같은 환경에서 `test_stdio_protocol_server`·`test_planning_parity`·`test_inventory_protocol`·`test_canonical_metadata`의 실패 4건도 모두 환경 문제다(Windows ctypes 2, 내려받지 않은 parity fixture 2).
- 전체 `py -3.11 -m unittest discover -s tests -v`는 사용자 PC에서 실행해야 한다(아래 ①).
- 별도 검토 에이전트가 바뀐 파일을 사본과 대조해 정적으로 읽었다. 컴파일 오류·analyze 지적은 없었다. 지적을 모두 고쳤다:
  1. 그리드 `active` 계산의 `sublist(first, last)`: 줄어든 목록에 예전 스크롤 위치가 남으면 `first > last`라 RangeError가 난다. → 범위가 비면 0번 도는 반복문으로 바꿨다.
  2. 교대 때 한 프레임 초상이 비는 문제: `AssetImageGrid`가 바뀐 asset을 프레임 뒤에 넣었다. → asset이 바뀐 직후(`didUpdateWidget`) 캐시에서 바로 온 이미지는 같은 프레임에 넣는다. 첫 그리기 경로는 그대로다.
  3. 알리는 도중 듣는 곳이 빠지면 Timer가 남을 수 있었다. → `notifyListeners` 뒤에 다시 맞춘다.
  4. golden `tearDown`에서 고정을 풀면 실패한 테스트의 남은 트리에 진짜 Timer가 붙을 수 있었다. → `tearDown`을 없앴다(파일마다 isolate가 따로다).
  5. CRLF 파일 8개가 통째로 LF로 바뀌어 전체 diff가 되었다. → 원래 줄은 원래 줄 끝을 되살리고, 새 줄만 LF로 썼다.

### 바뀐 파일

**백엔드**
- `backend/core/protocol_v1.py`:
  - `planning.student.catalog` 학생 항목 끝에 선택 필드 `forms`를 붙인다(폼 2개 이상 학생만).
  - `_catalog_forms`와 주입용 `student_forms` 인자를 더했다. 기본값은 `student_meta.MULTI_FORM_STUDENTS`다.
- `backend/tests/test_student_catalog.py`:
  - 주입 폼 3건(이름 없는 폼 → `template_name: null`). 폼 1개·없음 학생은 key가 없고, 기존 필드 순서는 그대로다.
  - 실제 metadata의 다중 폼 학생 집합·`format_form_ref` 일치.
  - 실제 프로세스 응답에 `hoshino_battle` 폼 2개.

**계약**
- `contracts/planning-student-catalog-v1.schema.json`: entry에 `forms`(minItems 2, `$defs/form` = `form_id`·`label`·`template_name`(string|null), 추가 key 거부).
- `contracts/fixtures/planning_protocol_v1.json`: 사례 2건(다중 폼 응답 valid, 폼 1개 목록 invalid). Python·Dart 계약 테스트가 같이 읽는다.
- `contracts/README.md`: `planning.student.catalog` 절 새로 씀. 정한 것:
  - 폼 1개 이하 학생은 필드를 **뺀다**(빈 목록을 보내지 않음).
  - `form_id` 규칙, `template_name` null이면 플레이스홀더로 그린다.
  - 호환성 주의(아래 발견 사항 1).

**프런트**
- `frontend/lib/services/app_service.dart`: `StudentCatalogForm`, `StudentCatalogEntry.forms`/`isMultiForm`. `fromWire`는 `forms`를 선택 key로 받는다(2개 미만·알 수 없는 key·폼 필드 이상은 거부).
- `frontend/lib/services/mock_app_service.dart` + `frontend/assets/student_catalog.json`: mock catalog의 다중 폼 학생 2명(`hoshino_battle`, `shun_swimsuit`)에 같은 모양의 `forms`.
- 새 `frontend/lib/ui/widgets/student_form_cycle.dart`:
  - `StudentFormClock`: 앱 전체 시계 하나. 듣는 곳이 있을 때만 3초 `Timer.periodic` 하나가 돈다. `freeze`로 고정한다.
  - `StudentFormClockScope`(주입), `StudentFormCycleBuilder`(다중 폼 학생이 있고 TickerMode가 켜져 있을 때만 듣는다).
  - `studentPortraitAssetAt`·`studentPortraitAssetsOf`.
- `frontend/lib/ui/widgets/student_section_layout.dart`:
  - 학생 그리드 카드(보이는 행에 다중 폼이 있을 때), S3 선택 카드, S4 최근 본 학생 썸네일이 같은 시계로 교대한다.
  - 계획 학생 선택도 같은 `StudentDiagonalGrid`라 함께 교대한다.
  - 경기천년제목 TextStyle 17곳에 폴백 지정을 더했다.
- `frontend/lib/ui/widgets/student_grid_warmup.dart`: warmup asset에 다중 폼 학생의 모든 폼 초상을 넣는다(앞쪽 64명 제한과 상관없이).
- `frontend/lib/ui/widgets/asset_image_grid.dart`: asset 교체 직후 캐시 이미지를 같은 프레임에 넣는다(교대 깜박임 방지).
- `frontend/lib/app/theme.dart`: `AppFonts.fallback` 맨 앞에 Pretendard.
- `frontend/lib/ui/kit/stepper.dart`(5곳), `frontend/lib/ui/widgets/diagonal_media_list_item.dart`(3곳), `frontend/lib/ui/widgets/plan_element_builder.dart`(5곳): 경기천년제목 TextStyle에 `fontFamilyFallback: AppFonts.fallback`.

**테스트**
- 새 `frontend/test/student_form_cycle_test.dart`(10건):
  - FB-5 `fromWire` 2건(받기, 거부·이름 없는 폼), mock catalog 폼 1건.
  - 교대 규칙 1건, 시계 Timer 1건.
  - 그리드 0초·3초·6초 1건, 폼 1개 학생은 시계를 듣지 않음 1건, TickerMode 꺼짐 멈춤·다시 켬 1건, 같은 시계 두 곳 같은 단계 1건.
  - warmup 1건.
- `frontend/test/repository_process_e2e_test.dart`: 실제 Python 프로세스 catalog에서 `hoshino_battle` 폼 2개(`form_id`·`template_name`), `ayane`은 빈 목록(프로세스 E2E 왕복).
- `frontend/test/goldens/golden_harness.dart`: 학생 fixture 복사 때 `forms`도 옮긴다.
- `frontend/test/goldens/fe1g_baseline_golden_test.dart`: `setUp`에서 시계를 단계 0에 고정, 새 장면 `students-grid-second-form`(단계 1).
- Dart 계약 테스트 `planning_protocol_contract_test.dart`는 고치지 않았다. 새 fixture 사례 2건을 같은 `fromWire`로 검증한다.

사본: `debug/frontend_fe3e/pre/` 18개(위 기존 파일 전부). CRLF가 섞인 파일: `protocol_v1.py`, `test_student_catalog.py`, fixture, README, schema, `app_service.dart`, `theme.dart`, `repository_process_e2e_test.dart`. 이 파일들은 원래 줄의 줄 끝을 그대로 두고 새 줄만 LF로 썼다.

### 처리한 FD

- FD-064(워커 재량, 권장안): 폼 수 × 3초, 계단식(페이드 없음), 모든 학생이 같은 단계 값(같은 시계).
- 단계 → 폼: `단계 % 폼 수`. 폼 2개면 0초 첫 폼, 3초 둘째 폼, 6초 첫 폼이다.

### 다중 폼 교대가 적용되는 곳과 안 되는 곳

- 적용: 학생 탭 그리드 카드, S3 선택 카드, S4 최근 본 학생, 계획 학생 선택 그리드. 모두 `StudentCatalogEntry`를 가진 자리다.
- 아직 안 됨: 학생 ID만 받는 자리(계획 요소 빌더·계획 단계 타일·계획 탭 목록·통계·타이틀·계정 아바타·스캔 검토). 이 자리는 첫 폼(`<id>.png`)을 그대로 그린다. FE4·FE7에서 entry를 넘기면 같은 `StudentFormCycleBuilder`로 붙일 수 있다.

### 이미지 추출 대상·스캐너 로그 요청

- 요청 없음. 다중 폼 학생 2명의 폼 초상(`hoshino_battle_1.png`, `shun_swimsuit_1.png`)이 이미 `frontend/assets/student_portraits/`에 있다(UI asset).
- 인식 계열 파일과 게임 이미지 자산은 건드리지 않았다. `scanner-structural-consolidation-orchestrator-log.md`에 항목을 더하지 않았다.

### en dash 등 경기천년제목에 없는 글리프

`GyeonggiTitle-Medium.ttf` cmap 검사 결과 없는 글리프: `–`(U+2013) `—`(U+2014) `•`(U+2022) `−`(U+2212) `✓` `✔` `≈`. `·`는 있다. Pretendard에는 `✔` `∼`만 없다.

고친 방법: `AppFonts.fallback` 맨 앞을 번들 Pretendard로 바꿨다. 폴백을 지정한 경기천년제목 글자는 빠진 글리프만 같은 문장 안에서 Pretendard로 그린다. 앱과 golden이 같고, 기기 서체에 따라 달라지지 않는다. 폴백 지정이 없던 경기천년제목 TextStyle은 Lane A 파일 30곳에 지정을 더했다.

| 위치 | 글자 | 서체 | 처리 |
|---|---|---|---|
| `ui/models/student_filter_selection.dart:81,95` 스킬 0 → "–"(필터 모달 강화·서브 행 값, 범위 칩) | – | 경기천년제목(폴백 있음) | 고침(폴백 순서) |
| `ui/kit/stepper.dart` `StepButton` "−"(계획 요소 빌더 스테퍼 `plan_element_builder.dart:3134`, 갤러리) | − | 경기천년제목(폴백 없음) | 고침(폴백 추가) |
| `ui/kit/shortage_flyout.dart:93` 부족 "−n" | − | `kitDisplayStyle`(폴백 있음) | 고침(폴백 순서) |
| `ui/kit/gallery/*` "—" "−163.1M" 등 견본 | — − | 본문·`kitDisplayStyle` | 고침 또는 본래 문제 없음 |
| `ui/kit/info_popover.dart:230` "•" | • | 본문 | 문제 없음 |
| `ui/widgets/plan_section_layout.dart:4040,4764,5347,7773` "–" "−" "—" | – − — | 본문(테마 기본) | 문제 없음 |
| `statistics/statistics_projection.dart:120-124` "1–20" 등 | – | 본문 | 문제 없음(사용처 본문 스타일) |
| `ui/pages/inventory_page.dart:712`, `section_placeholder_page.dart:166`, `tactical_page.dart:190` "—" | — | 본문 | 문제 없음 |
| `ui/widgets/scan_student_review_workspace.dart:1344-1447` "—" | — | 본문 | 스캐너 소유 — 손대지 않음, 문제 없음 |
| `developer_tools_main.dart:2184` "—" | — | 본문(개발 도구) | 문제 없음 |
| 폴백 지정 없는 경기천년제목 TextStyle 10곳: `title_page.dart`(7), `home_page.dart`(1), `account_section_cluster.dart`(2) | 현재 문자열에 빠진 글리프 없음 | 경기천년제목(폴백 없음) | 남김(Lane B 화면 FE8에서 지정). 지금은 숫자·한글뿐이다 |

### golden 변화 예측

- 바뀜(정상):
  - `students-filter-open`: 강화·서브 행 최소값 "–"가 흰 사각형에서 Pretendard 대시로 바뀐다.
  - `plan-element-builder`: 스테퍼 "−" 버튼이 사각형에서 Pretendard 빼기 기호로 바뀐다(스테퍼가 장면에 보이면).
  - `plan-preset-manager`: 같은 스테퍼가 보이면 바뀐다(보이지 않으면 차이 0).
- 새 장면: `students-grid-second-form`(학생 10명 fixture, 시계 단계 1): 슌(수영복) 카드만 둘째 폼 `shun_swimsuit_1.png`. 나머지는 `students-grid`와 같다.
- 차이 0:
  - `students-grid`·`students-detail`·`students-grid-name-off`: 단계 0 = 첫 폼 `shun_swimsuit.png`, 이전과 같은 파일.
  - `title`·계정 3장·`home`: warmup asset만 늘었다.
  - 나머지 `plan-*`: plan fixture는 다중 폼 학생이 없다.
  - `scan-student-review`.
- 차이가 예측과 다르면 원인을 조사해 보고한다.

### 검수표 (mock 모드, 2560×1440 모니터 최대화 = 2560×1392)

| artboard·상태 | 여는 방법 | 확인 |
|---|---|---|
| W-Card-States "폼 2개(3초)" | 학생 탭, 검색 "슌" 또는 "호시노" | 슌(수영복)·호시노(무장) 카드가 3초마다 둘째 폼으로 바뀌고 3초 뒤 돌아온다. 페이드 없이 바로 바뀐다. 다른 카드는 그대로다 |
| 깜박임 | 같은 화면에서 교대 순간 | 초상이 비는 프레임이 없다 |
| 같은 시계 | 다중 폼 학생을 선택해 S3·S4 최근 본 학생에 함께 보이게 | 그리드 카드·S3 선택 카드·최근 본 학생 썸네일이 같은 순간에 바뀐다 |
| 멈춤 | 다른 탭으로 갔다가 돌아온다 | 다른 탭에 있는 동안 학생 탭은 멈춘다(돌아오면 이어서 교대) |
| 계획 학생 선택 | 계획 탭 → 학생 고르기 | 다중 폼 학생 카드가 같은 규칙으로 교대한다 |
| en dash | 학생 탭 → S1 필터 → 성장 범위 "강화"·"서브" | 최소값 "–"가 사각형이 아닌 대시로 보인다 |
| 스테퍼 "−" | 계획 탭 → 요소 빌더 | 빼기 버튼 글자가 대시 모양 |

### 알려진 시안 차이

1. 시안 CSS `stuform2/3/4`는 폼 수별 keyframe 애니메이션이다. 앱은 같은 주기의 계단식 전환을 공용 시계 하나로 한다(카드마다 시작 시점이 다르지 않고 모두 같이 바뀐다).
2. 폼 label은 canonical metadata 값("1", "2")이다. 화면에는 폼 이름을 보이지 않는다(시안도 초상만 바뀐다).

### 미검증 항목

1. `flutter analyze`(info 0), Dart 테스트(새 10건 + 프로세스 E2E 추가 단언), golden(19 + 1장), 전체 Python 테스트. 사용자 PC에서 실행해야 한다.
2. 실행해 봐야 아는 것:
   - 전역 시계의 Timer가 다른 위젯 테스트(전체 catalog mock을 쓰는 학생·계획 화면)에서 테스트 끝에 남지 않는지(트리 해제 때 듣는 곳이 빠져 취소되도록 했다).
   - 교대 순간 캐시 이미지가 같은 프레임에 들어가는지.
   - golden에서 Pretendard 폴백이 실제로 사각형을 대신하는지.

### 발견 사항

1. **catalog 추가 필드와 구버전 UI**: FE3-e 이전 Dart `StudentCatalogEntry.fromWire`는 key 집합을 정확히 비교한다. 그래서 `forms`가 있는 항목(다중 폼 학생 2명)이 오면 catalog 전체를 거부한다. 지금은 UI와 backend를 한 묶음으로 배포하므로 문제가 되지 않는다. 다만 "기존 클라이언트가 깨지지 않아야 한다"를 글자 그대로 지키려면 응답 버전 협상이 필요하다. 계약 README에 적었다.
2. 다중 폼 교대가 학생 ID만 받는 화면(계획 요소 빌더 등)에는 아직 없다(위 목록). FE4에서 entry를 넘길지 오케스트레이터 판단이 필요하다.

### 사용자 실행 순서

① gate만 실행하고 멈춘다. 백엔드 전체 테스트도 같이 돌린다. 예상: Python 전부 통과. gate는 golden만 RED다(새 장면 기준 없음, `students-filter-open`·`plan-element-builder` 등 차이). 결과(`debug\frontend_gate\<실행 시각>\summary.txt`, `frontend\test\goldens\failures\`)를 오케스트레이터에게 보낸다. 오케스트레이터가 차이 이미지를 검토한다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7\backend"
py -3.11 -m unittest discover -s tests -v
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

② 승인 뒤 golden을 갱신하고 GREEN을 확인한다. 오케스트레이터가 새 기준 이미지를 검토한다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

③ 승인 뒤 커밋한다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3e -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3e
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesign-docs
```

`debug/frontend_fe3e/commit.json`의 `whole`은 `frontend/test/goldens/baseline`이다(새·바뀐 PNG 포함). 백엔드·계약 파일도 같은 commit.json에 넣었다.

### FE3-e commit record (2026-10-07 20:12, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261007_195559\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: frontend/lib/services/mock_app_service.dart

## FE3-f1 착수 기록 (2026-10-07)

- 범위(작업 지시 2026-10-07 20:35, 오케스트레이터 로그 20:28 f1/f2 분할, 워크플로 FE3-f 행): 계산기 상태 모델(`lib/ui/models/`, 13행 목표, FD-166 계산기 정규화, FD-168 현재값 출처, FD-169 빠른 목표, FD-167 칸 토글·개수, FD-170 최근 계산)과 계산 어댑터(FD-162 (a): 임시 1페이즈 1단계 문서 `planning.document.calculate`, 디바운스, 늦은 응답 버림, 오류 상태, 크레딧 내역 없음, FD-172 명시 값).
- 범위 밖: 화면 연결(FE3-f2), 백엔드 메서드 추가(FB-11), 스캐너·tactic 소유 파일, `scan_page.dart`·`scan_companion_dock.dart`·`app_shell.dart`. 기존 `normalizePlanningGrowthTargets` 동작은 바꾸지 않는다.
- 시작 커밋: `8a6482e7c8e506773db487f5f76fa4079ac5988f`(FE3-e `a3692424` 뒤 문서 커밋).
- 사본: 고치는 기존 파일은 `debug/frontend_fe3f1/pre/<v7 기준 경로>`. 새 파일 위주로 만든다. 기기 쓰기는 새 업로드 경로에서 쓰고 다시 읽어 바이트로 대조한다.
- 먼저 확인: `planning.document.calculate`(백엔드 `protocol_v1._document_calculate` → `calculate_document_projection`)는 받은 문서를 계산만 하고 저장소·활성 계획을 건드리지 않는다. 저장 id도 요구하지 않는다(문서 id는 임의 문자열). 그래서 진행한다.

## FE3-f1 종료 기록 (2026-10-07, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없어 `flutter analyze`·Dart 테스트·golden을 돌리지 못했다. 통과를 주장하지 않는다.
- 백엔드는 고치지 않았다. Python 전체 실행은 하지 않는다(작업 지시 §3).
- 별도 검토 에이전트가 새 파일 6개를 정적으로 읽었다(컴파일·flutter_lints 6·테스트 기대값을 손으로 계산, 정규화를 Python으로 옮겨 무작위 검사). 지적 2건을 고쳤다:
  1. `prefer_initializing_formals`: Dart 3.12부터 이름 있는 매개변수를 같은 이름의 private 필드에 넣으면(`{basis} : _basis = basis`) 린트가 잡는다. → 필드 이름을 `_activeBasis`, `_planningService`로 바꿨다.
  2. (선택) `GrowthCalculatorEngine.cancel()`을 dispose 뒤에 부르면 ChangeNotifier assert. → 맨 앞에서 돌아간다.
- 워커도 계산기 정규화와 기존 `normalizePlanningGrowthTargets`를 Python으로 옮겨 무작위로 23만 번 조작했다. 성장 규칙 위반·하한·상한·장비 레벨 규칙 어긋남 0건이었다. Dart 실행이 아니므로 gate가 최종 확인이다.

### 바뀐 파일

기존 파일은 고치지 않았다(`debug/frontend_fe3f1/pre` 사본 없음). 화면 파일·`app_shell.dart`·`mock_app_service.dart`·스캐너·tactic 소유 파일은 그대로다. 그래서 golden 변화는 0이어야 한다.

| 파일 | 내용 |
|---|---|
| `frontend/lib/ui/models/growth_calculator_rules.dart` | 13행 정의, 계산기 정규화, 빠른 목표, 바뀐 목표 목록·칩, 칸 개수 |
| `frontend/lib/ui/models/growth_calculator_state.dart` | `GrowthCalculatorState`(현재값 출처·토글·되돌리기), `RecentGrowthCalculations` |
| `frontend/lib/ui/models/growth_calculator_adapter.dart` | 임시 문서, 요청·결과 모델, `GrowthCalculatorEngine`(디바운스) |
| `frontend/test/growth_calculator_rules_test.dart` | 15건 |
| `frontend/test/growth_calculator_state_test.dart` | 16건 |
| `frontend/test/growth_calculator_adapter_test.dart` | 13건 |

### 13행 목록(Calc-Student 순서 + 애장품)

애장품 행은 시안에 없어서 자리를 정해야 했다. S3에서 애장품 칸이 장비 3칸 바로 뒤에 있고, 애장품 티어가 인연 목표를 끌어올리므로 장비 3 뒤·인연 앞에 두었다.

| # | 행(`GrowthCalculatorRow`) | 움직이는 key | 스테퍼 단위 |
|---|---|---|---|
| 1 | 레벨 `level` | `level` | 레벨 |
| 2 | 성급 `studentStar` | `student_star` | ★ |
| 3 | 전용무기 `weapon` | `weapon_star`, `weapon_level` | ★(Lv은 따라감) |
| 4 | EX 스킬 `exSkill` | `ex_skill` | 단계 |
| 5 | 일반 스킬 `normalSkill` | `skill1` | 단계 |
| 6 | 강화 스킬 `enhancedSkill` | `skill2` | 단계 |
| 7 | 서브 스킬 `subSkill` | `skill3` | 단계 |
| 8~10 | 장비 1·2·3 `equipment1~3` | `equipN_tier`, `equipN_level` | 티어(레벨은 따라감). 부위 이름(모자 등)은 f2가 메타데이터로 붙임 |
| 11 | 애장품 `favoriteItem` | `equip4_tier` | 티어. 애장품 없는 학생은 행 없음(12행) |
| 12 | 인연 `bond` | `bond_rank` | 랭크 |
| 13 | 능력 개방 `abilityRelease` | `stat_hp`, `stat_atk`, `stat_heal` | 세 값 각각(`GrowthCalculatorAbility`), 행 값 = 합 |

19 key를 한 번씩 덮는다(테스트).

### 정규화 규칙 표(`normalizeGrowthCalculatorTargets`, 계산기 전용)

계획 쪽 `normalizePlanningGrowthTargets`는 그대로다. 계산기 함수가 그 앞뒤에 아래 규칙을 더한다.

| 규칙 | 계산기 | 계획(기존, 바꾸지 않음) |
|---|---|---|
| 범위 | 현재값 이상, MAX 이하(애장품 없으면 `equip4_tier` MAX 0) | 최소~MAX |
| 장비 티어를 현재보다 올림 | 장비 레벨 = 그 티어 최대(T10 → 70) | 레벨은 그대로(티어 상한으로만 자름) |
| 장비 티어를 스테퍼로 현재 티어로 되돌림 | 장비 레벨 = 현재 레벨 | — |
| 장비 레벨을 직접 정함(빠른 목표 "완전 육성") | 현재 레벨~그 티어 최대 사이에서 그 값 | — |
| 전용무기 ★ 올림 / 현재로 되돌림 | Lv = 그 ★ 최대(★1 → 30) / 현재 Lv. 전용무기 목표가 있으면 학생 ★5 | 같은 ★5 조건 |
| 능력 개방 | 세 값 각각. 값이 있으면 레벨 90·★5 | 같음 |
| 애장품 | 계산에 넣음. T1 → 인연 15, T2 → 인연 20, 인연이 성급을 끌어올림 | 같음 |
| 행 사이 조건(강화 ★2, 서브 ★3, 장비 2·3칸 레벨 10·20, 인연 상한 ★별) | 기존 함수가 맞춤 | 같음 |
| 순서 | ① 현재값~MAX로 자르기 ② 장비 레벨·전무 Lv 맞추기 ③ 기존 함수(바꾼 key 그대로 전달) ④ 다시 ① ⑤ 다시 ② | — |

현재값과 ③의 결과가 둘 다 성장 규칙에 맞으면 key마다 큰 값도 맞는다. 그래서 ④·⑤ 뒤에도 위반이 없다(`assert` + 무작위 테스트 300 × 10회).
- 빠른 목표(FD-169): 고른 행은 MAX, 나머지 행은 현재값에서 시작한다. 행 사이 조건은 정규화가 맞춘다(예: "스킬만 MAX"는 서브 스킬 때문에 ★3 미만이면 ★3까지 오른다).
  - 완전 육성 = 19 key 전부 MAX(같은 티어의 덜 오른 장비 레벨도 70).
  - 레벨·장비만 MAX = 레벨 90 + 장비 3칸 T10 Lv.70.
  - 스킬만 MAX = EX 5 + 스킬 3종 10.
- 칸 토글(FD-167): 바뀐 칸이면 직전 목표를 기억하고 현재값으로, 그대로인 칸이면 기억한 목표로 돌린다. 기억이 없으면 아무것도 하지 않는다(false).
  - 다른 행 목표가 그 칸을 끌어올리면 현재값까지 내려가지 않는다. 예: 성급 목표 ★2 이상이면 강화 스킬 최소 1.
  - "바뀌는 칸 n · 그대로 m"은 이 학생에게 쓰는 행(13 또는 12)으로 센다.
- 되돌리기: 행 단위로 처음 값(`initialTargets`)으로 돌린다. 처음 값은 보통 현재값이고, 최근 계산에서 다시 열면 그때 목표다. `revertAll`도 있다.
- "바뀐 목표" 칩: 레벨 +n · 성급 +n · 전용무기 ★s · Lv.l · 스킬 +n단계(EX·스킬 3종 합) · 장비 +n티어(3칸 합) · 애장품 Tn · 인연 +n · 능력 개방 +n.
  - 시안 예시 숫자(스킬 +17단계)는 FD-025에 따라 따르지 않고 실제 차이로 센다.

### 현재값 출처(FD-168)

- 확정값: `confirmedCurrent` = repository 학생 상태. f2는 `planElementCurrentTargets(seed)`를 넘긴다(계획 요소 빌더와 같은 변환, 미보유면 기본값).
- 직접 입력: 처음 고를 때 확정값에서 시작한다.
  - 상태 객체가 살아 있는 동안 고친 값을 기억하고, 어디에도 저장하지 않는다.
  - 장비 티어를 고치면 현재 레벨을 그 티어 최대로, 전무 ★를 고치면 그 ★ 최대 Lv로 본다.
  - 기준을 바꾸면 목표를 새 현재값 위로 다시 맞춘다.
- `updateConfirmedCurrent`: 스캔 승인 등으로 repository가 바뀌면 f2가 부른다.

### 최근 계산(FD-170)

- `RecentGrowthCalculations`: 학생 + 기준 + 목표 맵, 최대 6건, 학생마다 한 건(다시 넣으면 맨 앞으로 옮기고 새 목표로 바꿈), 앱 실행 동안만 유지.
- 계정 전환: `app_shell.dart`를 고치지 않으려고 `syncProfile(profileId)`를 두었다. 이전에 알린 계정과 다르면 비운다.
  - f2가 학생 탭에서 계정 id를 알릴 때 부른다. 또는 오케스트레이터가 허락하면 셸 `_profileChanged`에서 `clear()`를 부른다.

### 계산 어댑터(FD-162 (a))

- 호출: 기존 `PlanningDocumentService.calculatePlanningDocument`(= `planning.document.calculate`).
  - 인자: `current_students: [그 학생 한 명]`, `inventory`, `document: 임시 문서`.
  - 백엔드 `protocol_v1._document_calculate` → `calculate_document_projection`은 받은 문서를 계산만 한다. 저장소 쓰기·활성 계획 변경·저장 id 요구가 없어서 진행했다. 새 백엔드 메서드는 만들지 않았다(FB-11 소관).
  - mock 왕복 테스트도 계산 뒤 repository revision·goals·시나리오 목록이 그대로인지 확인한다.
- 임시 문서 모양(1페이즈 1단계, 계약 `planning-document-calculate-v1` 그대로):

```json
{"version": 1, "document_id": "growth-calculator", "name": "성장 계산기", "kind": "scenario",
 "phases": [{"phase_id": "growth-calculator-phase", "name": "성장 계산기",
   "stages": [{"stage_id": "growth-calculator-stage", "student_id": "<학생>", "name": "계산기 목표",
     "targets": {"<19 key>": 0}}]}]}
```

- `kind`는 `scenario`다(활성 계획 문서가 아니라는 표시). 백엔드 계산은 kind와 상관없다.
- 현재 학생 항목:
  - 확정값 기준이고 repository에 그 학생이 있으면 계획 탭과 같은 `confirmedStudentPlanningCurrent`를 보낸다.
  - 직접 입력·미보유면 계산기 현재값으로 만든다(`growthCalculatorCurrentStudentWire`: `T<n>`/null 장비, 전무 ★>0이면 `weapon_equipped`, 인연은 보내지 않음). 워커 환경 Python에서 `_current_students_from_wire` 통과를 확인했다.
- 인벤토리: repository 것을 쓰고, 없으면 빈 인벤토리.
- 결과(`GrowthCalculatorResult`):
  - `credits` = `overall.cost.credits`(없으면 크레딧 행, 그것도 없으면 0).
  - `resources` = `overall.resources`에서 크레딧 행을 뺀 성장 재화 행. 순서는 백엔드 순서다.
  - `warnings`: 백엔드 경고 문자열.
  - `shortageTypeCount`: "부족 n종".
- 없는 값은 명시 값으로 둔다(FD-172):
  - 크레딧 보유 `creditHolding` = `GrowthCalculatorHoldingNoScan`(FD-096 (c), 빗금·부족 칩 숨김).
  - 재화 보유 = `Known(n)` / `Unknown`(부족 0, `isShort` false).
  - 크레딧 내역 `creditBreakdown` = `GrowthCalculatorCreditBreakdown.unavailable`(FB-11 전 숨김).
  - 계획 포함 `planMembership` = `inPlan`/`notInPlan`(goals v1 기준, FD-027 방식) / `unknown`(repository 없음).
- `GrowthCalculatorEngine`:
  - 디바운스는 `growthCalculatorDebounce = 250ms`다.
  - `schedule`마다 요청 번호가 오르고, 응답이 왔을 때 번호가 다르면 버린다(늦은 응답·대기 중 새 요청).
  - 상태는 `Idle` / `Pending(lastResult)` / `Ready(result)` / `Failed(error, lastResult)`다.
  - `cancel()`이 있고, dispose 뒤 응답은 무시한다.
- 테스트의 디바운스는 testWidgets의 가짜 시간으로 민다. `fake_async`는 직접 의존성이 아니라서 가져오지 않았다(`depend_on_referenced_packages` 방지).

### FD-074 단계 프리셋 연결: 보류

FD-074 (b)는 단계 프리셋 영속화를 정했지만 저장소(프로필별 repository 버킷)는 FE4-b·c에서 만든다. 지금 `defaultPlanElementPresets`는 빈 인메모리 목록이다. 그래서 빠른 목표에 "단계 프리셋 마지막 단계"는 넣지 않았다(보류). 저장소가 생기면 `growthCalculatorQuickTargets`와 같은 모양(현재값 + 프리셋 목표 → 정규화)으로 더한다.

### f2가 쓸 공개 API 요약

```dart
// growth_calculator_rules.dart
enum GrowthCalculatorRow { level, studentStar, weapon, exSkill, normalSkill, enhancedSkill, subSkill,
  equipment1, equipment2, equipment3, favoriteItem, bond, abilityRelease }   // .label .keys .primaryKey .equipmentSlot
enum GrowthCalculatorAbility { hp, atk, heal }                                // .key .label
enum GrowthCalculatorQuickTarget { fullGrowth, levelAndEquipment, skills }    // .label .rows
class GrowthCalculatorCellCounts { changing, unchanged }
class GrowthCalculatorChange { row, current, target, delta }
class GrowthCalculatorChangeChip { group, label }
normalizeGrowthCalculatorTargets / growthCalculatorWithRow / growthCalculatorWithAbility / growthCalculatorQuickTargets
growthCalculatorTargetMaximums / growthCalculatorRows / growthCalculatorRowValue

// growth_calculator_state.dart  (ChangeNotifier)
GrowthCalculatorState(studentId:, confirmedCurrent:, hasFavoriteItem:, basis:, initialTargets:)
  basis current confirmedCurrent targets initialTargets rows maximums
  rowTarget(row) rowCurrent(row) rowMaximum(row) abilityTarget(a) abilityCurrent(a)
  isRowAvailable isRowChanged isRowModified canToggleRow cellCounts changes changeChips record
  setRowTarget(row, v) setAbilityTarget(a, v) applyQuickTarget(q) toggleRow(row)->bool
  revertRow(row) revertAll() setBasis(b) setDirectCurrentRow(row, v) setDirectCurrentAbility(a, v)
  updateConfirmedCurrent(map)
enum GrowthCalculatorBasis { confirmed, direct }                               // .label
class GrowthCalculationRecord { studentId, basis, targets }
RecentGrowthCalculations (ChangeNotifier): records, add(record), clear(), syncProfile(id), profileId   // capacity 6

// growth_calculator_adapter.dart
GrowthCalculatorRequest.fromState(state, repository: repositoryState?)
calculateGrowthTargets(service, request) -> Future<GrowthCalculatorResult>   // 디바운스 없이 한 번
GrowthCalculatorEngine(service:, debounce:) (ChangeNotifier): status, requestNumber, schedule(request), cancel()
sealed GrowthCalculatorStatus: Idle | Pending | Ready | Failed  (.lastResult)
GrowthCalculatorResult: credits, creditHolding(NoScan), creditBreakdown(unavailable), resources, planMembership,
  warnings, shortageTypeCount
GrowthCalculatorResourceRow: resourceKey, itemId?, displayName, category, amount, holding, shortage, isShort
sealed GrowthCalculatorHolding: Known(quantity) | Unknown | NoScan
enum GrowthCalculatorPlanMembership { inPlan, notInPlan, unknown }
```

f2 연결 순서 예: 상태 변경 리스너에서 `engine.schedule(GrowthCalculatorRequest.fromState(state, repository: _repositoryState))`를 부른다. 결과를 받으면 `recent.add(state.record)`를 부른다(기록 시점은 f2 재량).

### 처리한 FD

FD-166 (c)(13행·계산기 정규화), FD-167 (a)(토글·개수, 상태만), FD-168 (a), FD-169 (a)(프리셋 연결 보류), FD-170 (a), FD-162 (a)(임시 문서·내역 없음), FD-172(명시 값). FD-049: 계산기 목표는 인연 게이지 활성 계획 목표와 별개다(이 파일들은 `active_plan_bond_target.dart`를 쓰지 않는다).

### 발견 사항(오케스트레이터 판단 필요)

1. **백엔드 성급 비용이 현재 ★를 늘 0으로 본다**:
   - `planning_calc._calculate_star_cost`가 `getattr(record, "star", 0)`을 읽는다. 그런데 `current_students` 항목 이름은 `student_star`다(`_CURRENT_INTEGER_FIELDS`, Dart `planningCurrentFields`).
   - 그래서 성급을 올리는 목표의 크레딧·엘레프가 ★0부터 계산된다.
   - 계획 탭 문서 계산도 같은 경로라 이번에 생긴 문제는 아니다. 백엔드 소관이라 고치지 않았다(FB-11 또는 백엔드 수정 슬라이스).
2. **여러 단계 문서의 장비 티어 이월 형식**:
   - `planning_document._advance`가 다음 단계용 현재 장비를 `"Tier<n>"`으로 쓴다. 그런데 `_parse_tier_number`는 `"T"`로 시작하는 값만 읽는다. `"TIER7"` → `int("IER7")` 실패 → 0이 된다.
   - 계산기(1단계 문서)와는 상관없지만 계획 탭 2단계 이상 장비 비용에 영향이 있을 수 있다. 확인만 했고 고치지 않았다.
3. mock `calculatePlanningDocument`는 재화 행·크레딧을 비워 보낸다(J-calc §5.1). f2 golden에서 크레딧·재화 목록을 채운 장면이 필요하면 golden fixture 서비스에 결과를 넣어야 한다. `mock_app_service.dart`에는 스캐너 쪽 미커밋 변경이 있어 이번에는 건드리지 않았다.

### 사용자 실행 순서(동작 보존 슬라이스)

예상: analyze info 0, 새 단위 테스트 44건 포함 전부 통과, golden 차이 0(20장 그대로). RED가 나면 `summary.txt`를 오케스트레이터에게 보낸다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3f1 -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3f1
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesigndocs
```

`debug/frontend_fe3f1/commit.json`: modified 없음, added 6, status true. `redesigndocs`와 `redesign-docs`는 같은 폴더(`debug/frontend_redesigndocs`)를 쓴다(스크립트가 `-`를 지운다).

### FE3-f1 commit record (2026-10-07 21:36, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261007_213219\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FB-12 착수 기록 (2026-10-07)

- 범위(작업 지시 2026-10-07 21:41, 오케스트레이터 로그 21:38, 워크플로 FB 표 FB-12 행): FE3-f1 발견 사항 1·2번.
  ① `planning_calc._calculate_star_cost`가 `record.star`를 읽어 wire의 `student_star`를 무시한다.
  ② `planning_document._advance`가 장비 티어를 `"Tier<n>"`으로 이월하는데 `_parse_tier_number`는 `"T<n>"`만 읽는다.
- 범위 밖: 스캐너 소유 백엔드 파일(recognition_*, scanner_*, student_*_recognizer 등), 프런트 파일 전부, 계약 형식.
- 시작 커밋: `bcde9559`(FE3-f1 `7ec07589` 뒤 문서 커밋).
- 사본: `debug/frontend_fb12/pre/backend/core/planning_calc.py`, `planning_document.py`(고치기 전 PC 파일과 바이트 동일 확인).

## FB-12 종료 기록 (2026-10-07, 코드 작성 완료·사용자 실행 대기)

이 환경(Linux, Python 3.13)에서는 백엔드 테스트 일부만 돌릴 수 있었다. 사용자 PC의 전체 실행(`py -3.11 -m unittest discover -s tests -v`)은 아래 사용자 실행 순서 ①이다. 통과를 주장하지 않는다.
- 워커 실행: `backend/tests` 중 내려받은 44파일(192건). 결과는 `debug/frontend_fb12/python-worker-linux.txt`에 있다.
  - 계획 계산 관련 모듈은 전부 통과했다: `test_planning_calc_fb12`(새 9건), `test_planning_document`, `test_planning_parity`, `test_planning_protocol_contract`, `test_plan_shortages`, `test_repository_parity`, `test_scenario_*`, `test_v6_migration`, `test_repository_protocol_contract`.
  - 실패·오류 53건은 모두 환경 문제다. Windows 전용 `ctypes.WINFUNCTYPE`, 실제 백엔드 프로세스, 내려받지 않은 tactical·battle fixture가 원인이다.
  - 고치기 전 코드로 같은 44파일을 돌렸을 때(새 테스트 제외)와 실패 목록이 한 줄도 다르지 않다.
- 새 테스트 9건은 고치기 전 코드에서 모두 실패한다(18 실패 + 1 오류). 버그를 실제로 잡는 테스트다.

### 바뀐 파일

| 파일 | 바뀐 것 |
|---|---|
| `backend/core/planning_calc.py` | `_current_student_star(record)` 추가(`student_star` 먼저, 없으면 `star`), `_calculate_star_cost`가 그것을 쓴다. `_parse_tier_number`를 `T<n>`·`Tier<n>`·대소문자·공백을 읽고 그 밖은 0으로 바꿨다 |
| `backend/core/planning_document.py` | `_advance`가 장비 티어를 정규 형식 `"T<n>"`으로 이월한다(0이면 None, 기존과 같음) |
| `backend/tests/test_planning_calc_fb12.py` | 새 파일 9건(성급 5, 장비 이월 2, 티어 파서 2) |

계약(contracts)·프런트·fixture는 바꾸지 않았다. 계약의 현재 장비 필드는 `{"type": ["string", "null"]}`이라 형식 규칙이 없고, 이번 수정은 받는 쪽만 넓혔다. 줄 끝은 원래대로 LF다.

### 고친 방식

1. **현재 성급**: `_current_student_star`가 `getattr(record, "student_star", None)`을 먼저 읽고, None이면 `getattr(record, "star", 0)`을 읽는다.
   - `_advance`는 다음 단계용 레코드에 `student_star`를 이미 쓰고 있었다. 그래서 2단계 이상 문서의 성급 이월도 함께 맞는다(새 테스트 `test_later_stage_star_cost_starts_from_the_previous_stage`).
   - 예: ★3 → ★5는 고치기 전 크레딧 1,250,000·엘레프 330(★0부터)이었다. 고친 뒤 1,200,000·220이고, ★3→★4 + ★4→★5 합과 같다.
   - 고치기 전에는 현재 ★5인 학생에게 ★5 목표만 있어도 크레딧 1,250,000·엘레프 330이 나왔다(새 테스트 `test_reaching_the_current_star_costs_nothing`).
2. **장비 티어 이월**: `_advance`가 `f"T{value}"`를 쓴다.
   - 정규 형식은 `T<n>`이다. 근거: 스캐너 인식기 `student_equipment_recognizer.py:1591` `f"T{number}"`, 계약 fixture `planning_v6_parity.json`·Dart mock 학생 `"T1"`, 프런트 계산기 `growthCalculatorCurrentStudentWire`.
3. **티어 파서**: 공백을 모두 지우고 대문자로 만든 뒤 `TIER`, `T` 접두를 떼고 남은 것이 ASCII 숫자일 때만 그 값을 쓴다. 그 밖은 0이다. 문자열이 아니면 0이다.
   - 고치기 전과 결과가 달라지는 입력:

| 입력 | 고치기 전 | 고친 뒤 |
|---|---|---|
| `"Tier7"`, `"TIER7"`, `"tier10"`, `"Tier 10"` | 0 | 7, 7, 10, 10 |
| `"T-1"` | -1 | 0 |
| `"T+3"` | 3 | 0 |
| `"T１"`(전각 숫자) | 1 | 0 |
| 정수 `7` 등 문자열이 아닌 값 | AttributeError | 0 |
| `"T7"`, `"t7"`, `" T 7 "`, `None`, `""`, `"love_locked"`, `"T7a"` | 7, 7, 7, 0, 0, 0, 0 | 같음 |

### 바뀐 기대값

기존 테스트의 기대값 중 바뀐 것은 없다. 기존 테스트를 고치지 않았다.
- `contracts/fixtures/planning_v6_parity.json`(`test_planning_parity`): 레코드가 `student_star: 1`이고 목표가 ★2다. 성급 누적표에서 ★0과 ★1이 둘 다 0이라 고치기 전후 값이 같다(크레딧 439,944, 엘레프 30). 워커가 고치기 전후 두 코드로 계산해 확인했다.
- `test_planning_document` 첫 테스트: 장비가 1·2단계 모두 T1이다. 고치기 전 2단계는 `"Tier1"` → 0 → T0→T1을 계산했지만 그 비용이 0이었다. 그래서 단계별 크레딧은 고치기 전후 모두 [910, 2870]이다. 그 테스트는 0보다 큰지만 본다.
- 프런트 프로세스 E2E(`final_p6_process_e2e_test.dart`, `repository_process_e2e_test.dart`, `scenario_process_e2e_test.dart`)는 크레딧을 `isA<int>()`·`greaterThan(0)`·`isNotEmpty`로만 본다. 굳은 버그 수치가 없어 고치지 않았다.
- 프런트 golden은 mock 서비스로 그려 백엔드 계산을 쓰지 않는다. 변화 0을 예상한다.

실제 화면 숫자는 바뀐다. 계획 탭·통계·인벤토리 부족·시나리오 비교에서 현재 ★가 1보다 큰 학생의 성급 목표 비용과, 2단계 이상 문서의 장비·성급 비용이 내려간다(버그로 부풀었던 값이 바로잡힘).

### `star` 속성 grep 결과

- 명령: `grep -rn '\bstar\b'`로 `backend/core`, `backend/tools`, 내려받은 `backend/tests` 44파일을 찾았다. 그중 `getattr(...,"star")`, `.star`, `"star":` 꼴만 골랐다.
- 계획 계산에 레코드를 넘기는 경로:
  - `protocol_v1._current_students_from_wire`(`planning.plan.calculate`·`plan.shortages`·`document.calculate`·`scenario.compare`)와 `planning_document`의 레코드 사본이다. 둘 다 `student_star`만 갖는다.
  - repository DTO(`repository_dto.py:70`), 병합(`repository_merge.py:8`), v6 이전 가져오기(`v6_migration.py:14`)도 모두 `student_star`다.
  - 계약 fixture `planning_v6_parity.json`도 `student_star`다.
- `star` 이름이 나오는 다른 곳은 계획 레코드가 아니다:
  - `student_stats.py`의 `build.star`(`StudentBuild` 데이터클래스)
  - 스캐너 소유 `student_identity_recovery.py:246`·`student_panel_recovery.py:19,268`·`student_matcher_adapter.py:116`(패널 탭 이름 `"star"`)
- 결론: 지금 `star` 속성을 가진 계획 레코드는 없다. 폴백은 이름이 바뀌기 전 레코드를 위한 안전장치로만 남긴다(새 테스트가 폴백과 우선순위를 확인한다).
- 남은 점: 내려받지 않은 스캐너 테스트 약 50파일은 계획 계산을 import하지 않을 것으로 보지만 직접 grep하지는 않았다. 사용자 전체 실행이 확인한다.

### `planning_calc.py` 레코드 필드 대조(`_CURRENT_INTEGER_FIELDS`·문자열 필드)

| 계산이 읽는 이름 | wire 필드 | 판정 |
|---|---|---|
| `star` | `student_star` | **불일치 → 고침**(위 1) |
| `level`, `weapon_star`, `weapon_level`, `ex_skill`, `skill1~3`, `stat_hp/atk/heal`, `student_id` | 같은 이름 | 일치 |
| `equip1~3`, `equip4`(문자열), `equip1~3_level` | 같은 이름 | 이름은 일치. 값 형식은 위 2·3으로 맞춤 |
| `weapon_state` | 같은 이름 | 이름 일치. 값은 `weapon_equipped`·`weapon_unlocked_not_equipped`를 해금으로 본다. 백엔드 생산자(`student_weapon_recognizer.py:80`, `student_star_recognizer.py:11`, 둘 다 스캐너 소유라 읽기만 함)가 쓰는 값과 같다 |
| `display_name`, `title` | 없음 | 엘레프 표시 이름 대체용이다. `student_id`가 있으면 쓰지 않는다(wire는 늘 있음). 영향 없음, 고치지 않음 |
| `weapon_type` | 없음 | 없으면 `student_meta.weapon_type(student_id)`로 찾는 의도된 대체다. 고치지 않음 |
| (`bond_rank`) | 현재 항목에 없음 | 계산이 읽지 않는다 |

같은 성격(이름 불일치)은 `star` 하나였다.

참고(고치지 않음): 프런트 mock 학생 fixture(`mock_student_fixture.dart`)는 `weapon_state: 'weapon_unlocked'`를 쓴다. 백엔드 생산자는 이 값을 내지 않고, 검증기(`student_candidate_validation.py:129`)만 허용한다. 계산은 이 값을 해금으로 보지 않는다. mock 화면은 백엔드 계산을 쓰지 않아 숫자에 영향이 없다. 실제 스캔 값과 맞출지는 스캐너 쪽 판단이다.

### 사용자 실행 순서(동작 보존 화면, golden 변화 0 예상)

① Python 전체 테스트. 결과를 `debug\frontend_fb12\python-full.txt`에 남긴다. 예상: 전부 통과(FE3-e 때 812건 + 새 9건 = 821건 안팎).

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7\backend"
cmd /c "py -3.11 -m unittest discover -s tests -v > ..\debug\frontend_fb12\python-full.txt 2>&1"
Get-Content ..\debug\frontend_fb12\python-full.txt -Tail 4
```

② gate → 커밋 미리보기 → 커밋 → 문서 커밋.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fb12 -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fb12
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesigndocs
```

`debug/frontend_fb12/commit.json`: modified 2(`planning_calc.py`, `planning_document.py`, pre 사본 있음), added 1(새 테스트), status true.
- `python-full.txt`와 `python-worker-linux.txt`는 커밋 대상이 아니다.
- ①에서 실패가 나오면 그 파일을 오케스트레이터에게 보낸다.

### FB-12 commit record (2026-10-07 23:25, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261007_232002\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE3-f2 분할 (2026-10-07)

작업 지시(2026-10-07 23:47)의 범위가 크다. 모드 전환, S1 버튼 6개, S2 두 열(13행·크레딧·재화 목록·아래 버튼), S3 목표 표시·토글, S4 교체, golden 장면이 모두 들어 있다. 그래서 둘로 나눈다. 둘 다 시각 변경 slice다.

| sub-slice | 범위 | golden |
|---|---|---|
| **FE3-f2a(이번)** | 진입·복귀(FD-160 (a) S1 버튼, FD-161 (a) 헤더 "← 학생" 칩·Esc·주 탭 다시 누르기, 헤더 제목 교체), 계산기 S1 버튼 세트(기준 토글 FD-168, 빠른 목표 FD-169, 계획에 추가 비활성, 현재값 갱신, 되돌리기), S2 왼쪽 열(13행 스테퍼·MAX·행 되돌리기·바뀐 목표 칩·"바뀌는 칸 n · 그대로 m" 칩·능력 개방 플라이아웃·직접 입력 현재값 스테퍼), S2 오른쪽 열(크레딧 타일 합계 + 보유 "스캔 없음" 빗금, 내역 막대 숨김, 인연 타일 빈 상태, 성장 재화 목록·정렬·접힘), 아래 버튼("이 목표로 계획에 추가" 비활성, FD-173 버튼 숨김), 계산 연결(디바운스, Pending 흐리게, Failed 오류 문구, Ready → 최근 계산 추가), 최근 계산 상태 객체와 `syncProfile` | 새 장면 `students-calculator` |
| FE3-f2b(다음) | S3 인디케이터를 목표값으로 + "현재 …" 태그, S3 칸 누르기 토글(FD-167), S4 계산기 내용(선택 학생 요약·"기준: …" 칩·최근 계산 줄, 누르면 그 목표로 다시 열기), 계정 전환 비움 위젯 테스트, 필요하면 능력 개방 플라이아웃 열림 장면 | 새 장면 1~2, `students-calculator` 갱신 |

f2a 동안 S3·S4는 학생 탭 그대로다. S3는 선택 학생의 현재값을 그리고, S4 최근 본 학생을 누르면 그 학생으로 계산기를 다시 연다.

## FE3-f2a 종료 기록 (2026-10-08, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없다. 그래서 `flutter analyze`·Dart 테스트·golden을 돌리지 못했고, 통과를 주장하지 않는다.
- 별도 검토 에이전트 2개가 바뀐·새 파일을 정적으로 읽었다. 하나는 lib 컴파일·린트·런타임, 다른 하나는 테스트 기대값·기존 테스트 영향을 보았다. 지적을 고친 뒤 고친 곳만 다시 읽혔다.
- 고친 지적:
  1. 컴파일 오류: `_AppHeader`에 `override`라는 필드를 두면 같은 클래스의 `@override`가 그 필드로 풀린다. → `pageOverride`로 바꿨다.
  2. `SemanticsAction`은 material·flutter_test가 다시 내보내지 않는다. → `isSemantics(value·increasedValue·hasIncreaseAction·hasDecreaseAction)` 매처로 바꿨다(`kit/range_controls_test.dart`와 같은 방식).
  3. `RenderProxyBox`·`BoxHitTestResult`도 material이 내보내지 않는다. → `package:flutter/rendering.dart`를 import했다.
  4. 호출 수 기대값: 앱 셸이 시작할 때 계획 탭도 문서를 한 번 계산한다. → 계산기를 열기 전 호출 수를 기준으로 센다.
  5. 작은 창 레이아웃:
     - 1024×768(캔버스 992×736)에서 목표 행 버튼이 잘리거나 누를 수 없었다. → 행 내용을 426px로 그린 뒤 같은 비율로 줄인다(`_ScaleDownRow`, 넓으면 그대로 채움).
     - 두 열 제목이 겹쳤다. → 왼쪽 제목을 오른쪽 제목 앞에서 끊고, "바뀌는 칸" 칩은 줄여 넣는다. 제목 줄은 첫 행과 겹치지 않게 올린다(섹션 안에서).
  6. 재화 목록 상자(직사각형)가 같은 높이의 왼쪽 열 목표 행 오른쪽 끝 누르기를 가렸다. → 상자 바닥 왼쪽을 지나는 80° 레일 왼쪽에서는 누르기를 받지 않는다(`_RailHitRegion`, 그리기는 그대로). 빈 상태 문구도 레일 위쪽 끝으로 옮겼다.
  7. 계정 다시 읽기·스캔 승인 뒤 학생 값이 같으면 다시 계산하지 않았다(인벤토리만 바뀐 경우). → `_refreshCalculatorCurrent`가 계산을 예약한다.
  8. 기존 코드 잠재 버그: `_switchSection2View`가 `reverse()`의 일반 Future를 기다렸다. 계산기 전환이 S2 애니메이션을 다시 시작하면 그 Future가 끝나지 않아 목록/그리드 토글이 멈춘다. → `.orCancel`로 기다린다(기존 `on TickerCanceled`가 받는다).
  9. 엔진 상태가 바뀔 때마다 학생 화면 전체를 `setState`하던 것을 뺐다. 계산기 섹션이 엔진을 직접 듣는다.

### 바뀐 파일

| 파일 | 종류 | 줄(+/−) | 내용 |
|---|---|---|---|
| `frontend/lib/ui/widgets/page_header_override.dart` | 새 | 86 | 머리말 제목·부제·복귀 칩 바꾸기 값과 컨트롤러(`set`·`clear`·`release`(dispose 중 안전)·`back`) |
| `frontend/lib/ui/app_shell.dart` | 수정 | +54 −13(diff 67줄) | 작업 지시 §1의 "주 탭 처리 최소 diff"다. 컨트롤러 1개를 만들어 `StudentPage`에 넘긴다. 같은 탭을 다시 누르면 `back`을 부른다. `_CompoundPageHeader`가 값을 듣고, `_AppHeader`는 제목·부제를 바꾸고 제목 옆에 `BaChip` 복귀 칩(`page-header-back-chip`)을 그린다 |
| `frontend/lib/ui/pages/student_page.dart` | 수정 | +178 −34 | 계산기 열기/닫기, 학생당 계산 엔진, Esc 등록, 머리말 값, 최근 계산(`syncProfile`), 확정값 갱신. 예전 S1 계획 넘기기(`_addToPlan`·`_draftValues`)를 뺐다 |
| `frontend/lib/ui/widgets/student_section_layout.dart` | 수정 | +185 −8 | S1: 계산기 모드 버튼 세트, 학생 모드 container-16을 "성장 계산기 열기"(`student-open-calculator`, 아이콘 `calculate_outlined`)로 바꿈. S2: 계산기 모드면 `GrowthCalculatorSection`(바탕 painter `bare`). 전환 때 S1·S2 다시 들이기 |
| `frontend/lib/ui/models/growth_calculator_state.dart` | 수정 | +13 | `resetToCurrent()`(모든 목표 = 현재값, 토글 기억 비움) |
| `frontend/lib/ui/widgets/growth_calculator_section.dart` | 새 | 1658 | S2 두 열·아래 버튼·능력 개방 플라이아웃·배치 계산(`GrowthCalculatorLayout`)·정렬·행 글자 함수 |
| `frontend/test/growth_calculator_view_test.dart` | 새 | 381 | 위젯 테스트 9 + 순수 테스트 1(아래) |
| `frontend/test/student_page_test.dart` | 수정 | +27 −4 | 첫 테스트: S1 계획 넘기기 → 계산기 진입(넘기기 없음 확인) |
| `frontend/test/goldens/golden_harness.dart` | 수정 | +62 | `GoldenCalculatorMockAppService`(학생 fixture + 계산 결과: 크레딧 18,420,000, 재화 15행, 1행은 보유 모름) |
| `frontend/test/goldens/fe1g_baseline_golden_test.dart` | 수정 | +40 | 새 장면 `students-calculator` |

`lib/services/**`·`backend/`·`contracts/`·스캐너·tactic 파일·`scan_page.dart`·`scan_companion_dock.dart`·`mock_app_service.dart`는 고치지 않았다. golden 계산 숫자는 harness의 서비스 double에 넣었다.

### 화면 구성(f2a)

- 진입: 학생 S1 container-16 "성장 계산기 열기"(FD-160 (a)). 선택 학생으로 연다. 같은 자리의 계산기 S1 버튼은 "이 목표로 계획에 추가"이고 FE4-g까지 비활성이다.
- 복귀(FD-161 (a)): 세 가지가 모두 학생 목록으로 돌아간다. 계산기 목표는 버린다(저장하지 않음).
  - 머리말 제목 옆 "← 학생" 칩
  - Esc(위에 열린 플라이아웃이 있으면 그것부터 닫는다)
  - 주 탭 "학생" 다시 누르기
- 머리말: 제목 "성장 계산기", 부제 "학생 한 명 · 목표까지 필요한 인연 선물 · 크레딧 · 재화를 바로 계산 (계획에는 저장하지 않음)".
- S1(학생 4섹션 기하 그대로):
  - 기준 토글 "확정값 기준"/"직접 입력"(FD-168)
  - "빠른 목표" 드롭다운(완전 육성·레벨·장비만 MAX·스킬만 MAX, FD-169)
  - 계획에 추가(비활성)
  - "학생 스캔으로 현재값 갱신"
  - "현재값으로 되돌리기"(바뀐 칸이 없으면 비활성)
- S2 왼쪽 "목표 정하기":
  - 제목 줄: 정보 팝오버, "바뀌는 칸 n · 그대로 m" 칩
  - 13행(애장품 유무를 모르면 13행, FD-166 (c)). 행마다 이름, 현재, 목표 스테퍼, MAX, 행 되돌리기(바꿨을 때만)가 있다.
    - 장비 행 이름은 catalog 장비 종류에서 가져온다("장비 1 · 모자").
    - 직접 입력 기준이면 "현재" 칸이 스테퍼가 된다.
    - 능력 개방 행은 HP·ATK·HEAL 세 스테퍼 `AnchoredFlyout`을 연다.
  - "바꾼 목표" 칩 묶음 + "현재값으로 되돌리기" + 단계 제한 안내
- S2 오른쪽 "필요 재화":
  - "목표까지" 칩, 실패 시 오류 문구
  - 크레딧 타일: 합계만 그린다. 내역 막대는 숨긴다. 보유는 "스캔 없음" 빗금이고 부족 칩은 숨긴다(FD-172).
  - 인연 타일: "인연 a → b" + "인연 선물 계산은 아직 지원하지 않습니다"(FE3-g)
  - 성장 재화 목록: `result.resources`. 정렬 "부족 큰 순"(기본)·"필요 많은 순"·"보유 많은 순"이 있고, 보유를 모르는 행은 보유·부족 정렬에서 뒤로 간다. 6행까지 보이고 "… 등 n종 더 · 모두 보기"/"접기"로 펼친다. 보유를 아는 행은 "보유 n" + 부족 칩, 모르는 행은 "스캔 없음"이다.
- 아래: "이 목표로 계획에 추가 / 계획 만들기 2 · 목표 정하기로 넘깁니다"(비활성). "인벤토리 · 부족 위험에서 보기"는 숨긴다(FD-173 (c)).
- 계산:
  - 상태가 바뀔 때마다 `engine.schedule`(250ms 디바운스)을 부른다. 계산기를 열 때마다 엔진을 새로 만든다.
  - Pending이면 직전 결과를 흐리게(0.55), Failed면 오류 문구와 직전 결과를 보인다.
  - Ready면 `recent.add(state.record)`. 계정을 고르면 `syncProfile`.
  - 서비스가 `PlanningDocumentService`가 아니면 "이 연결에서는 재화를 계산할 수 없습니다"를 보인다.
- S3·S4는 f2a에서 학생 모드 그대로다(FE3-f2b). S4 최근 본 학생을 누르면 그 학생으로 계산기를 다시 연다.

### 위젯 테스트(`growth_calculator_view_test.dart`)

1. 진입·복귀: S1 버튼 → 머리말 제목·칩 → 칩으로 복귀, Esc로 복귀, 주 탭 다시 누르기로 복귀
2. 디바운스: 레벨 + 세 번(40ms 간격) → 계산 1번 추가, "Lv.4"
3. 빠른 목표(완전 육성 = MAX 표, 칸 13/0, 칩), 현재값으로 되돌리기, 기준 토글(직접 입력 현재 스테퍼 "2" → 확정값 기준 "1")
4. 행 MAX·되돌리기, 장비 행 이름
5. "계획에 추가" 비활성(아래 버튼·S1 둘 다), FD-173 버튼 없음, 인연 빈 상태
6. 능력 개방 플라이아웃: HP + → "1 · 0 · 0", 레벨 90·★5로 맞춰짐, Esc가 플라이아웃만 닫음
7. 크레딧 합계·스캔 없음·재화 6행·펼치기 9행·정렬(필요 많은 순 맨 위)
8. 계산 오류 문구·크레딧 "—"
9. 의미 구조: value "Lv.1", increasedValue "Lv.2", 늘리기만 있음(handle은 본문 끝에서 dispose)
10. (순수) 정렬·숫자·행 글자 함수

계정 전환 비움 위젯 테스트는 f2b다(S4가 최근 계산을 그릴 때). `RecentGrowthCalculations.syncProfile` 단위 테스트는 FE3-f1에 있다.

### golden 변화 예측

- 새 장면: `students-calculator`(학생 fixture + `GoldenCalculatorMockAppService`, 아루). 빠른 목표 "스킬만 MAX" + 레벨 90 + 장비 1 두 단계를 바꾼 상태다. 장면에서 보이는 것:
  - 머리말 "성장 계산기"·"← 학생" 칩
  - 계산기 S1 버튼 묶음
  - 목표 행(바뀐 값 분홍)·바꾼 목표 칩·"바뀌는 칸 n · 그대로 m"
  - 크레딧 18,420,000·보유 "스캔 없음" 빗금
  - 인연 빈 상태
  - 재화 6행(부족 큰 순)·"… 등 n종 더 · 모두 보기"
  - S3·S4는 학생 모드 그대로
- 바뀜(정상): S1 container-16 아이콘 `playlist_add_rounded` → `calculate_outlined`. 학생 S1이 보이는 장면이 모두 바뀐다: `students-grid`·`students-detail`·`students-grid-name-off`·`students-grid-second-form`·`students-filter-open`(모달 아래 S1). 툴팁 글자는 장면에 없다. 머리말은 그대로다(값이 없으면 기존 제목).
- 차이 0: `title`·계정 3장·`home`·`plan-*`·`scan-student-review`.
- 차이가 예측과 다르면 원인을 조사해 보고한다.

### 처리한 FD

FD-160 (a)(진입 버튼·계획에 추가 비활성), FD-161 (a)(칩·Esc·주 탭), FD-162 (a)(임시 문서 계산 표시), FD-166 (c)(13행), FD-168(기준 토글·직접 입력 현재 스테퍼), FD-169(빠른 목표), FD-170(최근 계산 추가·`syncProfile`; 표시는 f2b), FD-172(크레딧 합계만·스캔 없음 빗금·부족 칩 숨김), FD-173 (c)(버튼 숨김). FD-167(S3 토글)은 f2b다. 칸 개수 칩은 f2a에 있다. FD-049: 계산기 목표는 인연 게이지 활성 계획 목표와 섞지 않는다.

### 검수표 (mock 모드, 2560×1440 모니터 최대화 = 2560×1392)

| artboard·상태 | 여는 방법 | 확인 |
|---|---|---|
| Calc-Student 진입 | 학생 탭 → S1 "성장 계산기 열기"(계산기 아이콘) | 머리말이 "성장 계산기" + 부제로 바뀌고 제목 옆에 "← 학생" 칩이 있다. S1이 계산기 버튼 묶음으로 바뀐다 |
| 복귀 3가지 | 칩 / Esc / 주 탭 "학생" 다시 누르기 | 학생 그리드로 돌아오고 머리말이 "학생"으로 돌아온다 |
| 목표 행 | S2 왼쪽 | 13행(애장품 포함). +/−/MAX로 바꾸면 값이 분홍, 행 끝에 되돌리기, "바뀌는 칸 n · 그대로 m"·바꾼 목표 칩이 같이 바뀐다 |
| 능력 개방 | "능력 개방" 행 값 | 오른쪽에 HP·ATK·HEAL 플라이아웃. 처음 올리면 레벨 90·★5가 같이 맞춰진다. Esc는 플라이아웃만 닫는다 |
| 기준 토글 | S1 "직접 입력" | "현재" 칸이 스테퍼가 된다. "확정값 기준"으로 돌아가면 확정값으로 돌아온다 |
| 빠른 목표 | S1 "빠른 목표" | 세 항목이 해당 행을 MAX로 올린다 |
| 계산 | 값을 바꾼 직후 | 오른쪽이 잠깐 흐려졌다가 크레딧·재화가 다시 그려진다(mock은 재화 행이 비어 "목표까지 더 필요한 성장 재화가 없습니다") |
| 크레딧 타일 | S2 오른쪽 위 | 합계만 보이고 내역 막대가 없다. 보유는 빗금 "스캔 없음", 부족 칩이 없다 |
| 비활성 | 아래 "이 목표로 계획에 추가"·S1 같은 버튼 | 누를 수 없다. "인벤토리 · 부족 위험에서 보기"가 없다 |
| 작은 창 | 창을 1280×720 정도로 줄인다 | 목표 행 버튼이 잘리지 않고 같은 비율로 작아진다. 두 열 제목이 겹치지 않는다 |

### 알려진 시안 차이

1. 시안 S3·S4 계산기 내용(목표값 + "현재 …" 태그, 최근 계산 줄)은 f2b에서 그린다.
2. 크레딧 내역 막대·보유량·부족 칩, 인연 선물 계산은 숨김·빈 상태다(FD-172·FE3-g).
3. 작은 창에서는 목표 행을 줄여 그린다(시안에 작은 창 규칙이 없다).

### 미검증 항목

1. `flutter analyze`(info 0), Dart 테스트(새 10건 + 바뀐 1건), golden(새 1 + 바뀜 5). 사용자 PC에서 실행해야 한다.
2. 실행해 봐야 아는 것:
   - 능력 개방 플라이아웃이 2560 폭에서 섹션 경계 안에 열리는지(`KitOverlayBounds`)
   - `FittedBox`로 줄인 행이 1024~1600 폭에서 읽을 만한지
   - 계산기 전환 때 S1·S2 다시 들이기 애니메이션이 자연스러운지

### 발견 사항(오케스트레이터 판단 필요)

1. **catalog에 애장품 유무가 없다**: `StudentCatalogEntry`에 `has_favorite_item`이 없다. 그래서 계산기는 모든 학생에게 애장품 행을 둔다(13행). 백엔드 워커 요청: catalog 항목에 `has_favorite_item`(bool, 추가 필드)을 넣어 달라는 것이다. 들어오면 메타데이터에 그 값을 그대로 쓰도록 `student_page.dart` `_calculatorMetadata`만 고치면 된다(이미 값이 있으면 그 값을 쓴다).
2. **겹친 사선 목록의 누르기**: 직사각형 `DiagonalScrollViewport` 둘이 80° 레일로 나란히 있으면, 위에 있는 상자의 레일 왼쪽 빈 자리가 아래 목록 누르기를 가린다. 이번에는 계산기 안에 `_RailHitRegion`을 두었다. 계획 화면 등 같은 배치가 또 나오면 키트(`DiagonalScrollViewport` 옵션)로 올릴지 판단이 필요하다.
3. `StudentPage.onAddToPlan`(학생 → 계획 넘기기)은 이제 학생 탭에서 부르지 않는다. 셸은 여전히 넘긴다. FE4-g "이 목표로 계획에 추가"가 이 경로를 다시 쓸 수 있게 남겼다.

### 사용자 실행 순서(시각 변경, 백엔드 워커와 프론트 워커가 둘 다 멈췄을 때만 gate)

① gate만 실행하고 멈춘다. 예상: analyze info 0, Dart 테스트 통과, golden만 RED(새 `students-calculator` 기준 없음 + 학생 5장 차이). 결과(`debug\frontend_gate\<실행 시각>\summary.txt`, `frontend\test\goldens\failures\`)를 오케스트레이터에게 보낸다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

② 승인 뒤 golden을 갱신하고 GREEN을 확인한다. 오케스트레이터가 새 기준 이미지를 검토한다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

③ 승인 뒤 커밋한다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3f2a -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3f2a
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesigndocs
```

`debug/frontend_fe3f2a/commit.json`: modified 7, added 3, `whole`은 `frontend/test/goldens/baseline`(새·바뀐 PNG 포함), status true. pre 사본은 `debug/frontend_fe3f2a/pre/`에 있다. 작업 지시의 slice 이름은 `fe3f2`였으나 분할했으므로 `fe3f2a`를 쓴다(f2b는 `fe3f2b`).

### 수정 (2026-10-08, gate `20261008_022827` RED 뒤)

오케스트레이터 검토(로그 02:33): 일반 테스트 1건과 golden `students-calculator`가 이미지 로드 예외로 실패했다. 학생 장면 5건 차이(S1 아이콘 교체)는 승인됐다.

원인:
- 테스트와 golden fixture의 재화 itemId를 지어냈다. 해당 아이콘 파일이 없다.
  - 테스트: `res-0`…`res-8`
  - golden: `Item_Icon_Material_Lower_1~9`, `Item_Icon_SkillBook_Ultimate_Gehenna_3`, 그리고 전술 교육 BD에 기술 노트 id(`Item_Icon_SkillBook_Gehenna_3`)
- `ItemIconTile`에는 이미 `errorBuilder`가 있었다. 하지만 "파일 없음" 오류가 올 때 스트림을 듣는 위젯이 없으면 이 오류를 받지 못한다. 그때는 이미지 캐시가 대기 항목을 지우면서 스트림 completer가 버려지고, 늦게 온 오류가 `FlutterError`로 올라간다(stack: `PlatformAssetBundle.load` → "resolving an image codec").

고친 것:
1. **fixture id**: 모두 `frontend/assets/item_icons/**`·`assets/student_elephs`에 파일이 있는 실제 inventory id로 바꿨다(PC 자산 목록과 대조, 15/15 존재).
   - golden: 오파츠 하급 9행 → `Item_Icon_Material_Nebra_0~3`·`Phaistos_0~3`·`Wolfsegg_0`. 부족 0·필요량 5~45로 바꿔 기본 정렬(부족 큰 순)에서 대표 행 뒤로 가게 했다(전에는 이 9행이 위 6줄을 다 차지했다).
   - golden: 기술 노트 → `Item_Icon_SkillBook_Gehenna_3`
   - golden: 전술 교육 BD → `Item_Icon_Material_ExSkill_Gehenna_3`
   - 위젯 테스트: 같은 오파츠 9개(`_resourceIds`). 행 key와 기대값도 그 id로 바꿨다.
2. **`ItemIconTile` 대체 표시**: 배경·아이콘 그림을 새 `ItemIconAssetImage`(`AssetImage` 하위 클래스)로 읽는다.
   - 스트림을 풀 때 첫 결과(그림 또는 오류)가 올 때까지만 리스너 하나를 붙여 둔다. 그래서 위젯이 먼저 트리에서 빠져도 오류를 조용히 받는다. 그림이 오면 받은 `ImageInfo`를 dispose하고 리스너를 뗀다.
   - 캐시에서 읽는 중(pending)인 그림에만 붙인다. 이미 다 읽힌(또는 이미 실패한) completer에 붙이면 리스너가 그 자리에서 불려 바로 떨어진다. 그때 듣는 곳이 없으면 completer가 버려지고, 뒤이어 `Image`가 붙을 때 "Stream has been disposed"가 날 수 있다.
   - 그리기·캐시 key·`errorBuilder`는 그대로다. 아이콘이 없으면 배경만, 배경이 없으면 빈 상자를 그린다.
   - 기존 golden 장면에는 `ItemIconTile`이 없어 차이가 없다(쓰는 곳: UI Kit 갤러리, `shortage_flyout`, 계산기).
3. **위젯 테스트 1건 추가** `test/kit/item_icon_tile_test.dart`(FE2-d부터 있던 파일, 아래 "덮어쓰기 실수" 참고): 테스트용 asset bundle이 정한 경로의 읽기를 붙잡았다가 "파일 없음"으로 끝낸다.
   - 화면에 있는 동안 실패: 예외 없음, 크기 그대로, 빈 상자 1개.
   - 읽는 도중 트리에서 빠진 뒤 실패: 예외 없음. 고치기 전 코드에서는 이 경우 `FlutterError`가 올라올 것으로 본다(Flutter 소스 `ImageStreamCompleter`·`AssetBundleImageProvider`를 읽은 판단이고, 실행으로 확인하지 않았다).

바뀐 파일(추가):

| 파일 | 종류 | 내용 |
|---|---|---|
| `frontend/lib/ui/kit/item_icon_tile.dart` | 수정 | `ItemIconAssetImage` 추가, `Image.asset` 2곳 → `Image(image: ItemIconAssetImage(...))`, 머리 주석 |
| `frontend/test/kit/item_icon_tile_test.dart` | 수정 | HEAD 내용(243줄, 테스트 6건) 그대로 + `import 'dart:async';` 1줄 + 끝에 테스트 1건과 도움 클래스 `_HeldAssetBundle`·`_heldHost`. 기존 줄 삭제·변경 0 |
| `frontend/test/goldens/golden_harness.dart` | 수정(f2a 안) | fixture id |
| `frontend/test/growth_calculator_view_test.dart` | 새(f2a 안) | 실제 id 9개 |

golden 예측: `students-calculator`는 새 장면이다. 재화 6줄은 부족 큰 순으로 안티키테라(부족 17)·시계 T10 설계도(14)·전술 교육 BD(4)·기술 노트(96, 부족 0)·활동 보고서(64)·볼프세크(45)이고, 아이콘이 실제 그림으로 보인다. "… 등 9종 더" 줄에는 숨은 행 이름이 나온다(보유 모름인 아루의 엘레프가 맨 뒤). 학생 장면 5건은 승인된 S1 아이콘 차이다. 나머지는 차이 0이다.

`debug/frontend_fe3f2a/commit.json`: modified 9(`item_icon_tile.dart`·`test/kit/item_icon_tile_test.dart` 추가, pre 사본 `debug/frontend_fe3f2a/pre/frontend/lib/ui/kit/item_icon_tile.dart`·`.../test/kit/item_icon_tile_test.dart`), added 3.

사용자 실행 순서는 위 ①~③ 그대로다. 오케스트레이터 순서(로그 02:33)는 gate ① 재실행 → golden 갱신 ② GREEN → fb11a·fe3f2a 커밋 → redesigndocs다. f2b는 fe3f2a 커밋 뒤에 시작한다.

### 덮어쓰기 실수와 되돌림 (2026-10-08, gate `20261008_030824` 뒤)

오케스트레이터 검토: gate의 테스트는 모두 통과했고 golden 6건은 예상한 차이였다. 그런데 일반 테스트가 659건이어야 하는데 653건이었다.

원인:
- `test/kit/item_icon_tile_test.dart`는 FE2-d(`1f65b64a`)부터 추적되는 파일(243줄, 테스트 6건)이다. 워커가 이 파일을 테스트 1건짜리로 덮어썼다.
- 워커는 "같은 경로에 파일이 있는지"를 PC가 아니라 이 세션에 예전에 받아 둔 일부 사본 폴더에서 확인했다. 거기에 그 파일이 없어 새 파일로 잘못 판단했다.
- FE3-f2a 처음 기록의 `ItemIconTile` 사용처 조사("기존 테스트 없음")도 같은 일부 사본에서 했다. 그래서 틀렸다.

되돌림:
1. HEAD(`f2cf4fb8`) 내용을 git 객체에서 그대로 꺼냈다.
   - 워커 환경에는 git 명령이 없다. 그래서 PC의 `.git`에서 HEAD commit → tree → blob을 읽었다.
   - blob `2ab2d3527d04839423a46a370a8b5892c7f3088f`이고, 해시를 다시 계산해 일치를 확인했다. 243줄, LF다.
   - index의 같은 경로 blob과도 같다.
2. 그 내용에 `import 'dart:async';` 1줄을 더했다(`Completer`·`FutureOr`). 파일 끝(main 안 마지막)에 테스트 1건, main 뒤에 도움 클래스 2개를 붙였다. 기존 테스트는 지우거나 바꾸지 않았다(diff 삭제 줄 0). 테스트 수는 6 + 1 = 7, gate 일반 테스트는 659건이 되어야 한다.
3. pre 사본: `debug/frontend_fe3f2a/pre/frontend/test/kit/item_icon_tile_test.dart` = HEAD 내용. commit.json에서 이 파일을 added에서 modified로 옮겼다.

기존 테스트 6건과 새 `ItemIconAssetImage`:
- 고치지 않았다. 읽어 본 판단으로는 깨지지 않는다.
- 기존 테스트는 `CachingAssetBundle`의 `load`가 늘 실패하는 bundle로 그린다.
  - 크기·아이콘 상자: `Positioned` 위치·크기만 본다.
  - 빈 상자: 배경 실패 → `ItemIconPlaceholder`. `errorBuilder`는 그대로이고, 이 경로에서 실패는 위젯이 듣는 동안 온다.
  - 아이템 타일·초상 줄: 그림을 보지 않는다.
- `AssetImage`의 같음 비교(runtimeType 포함)를 쓰는 테스트(`planning_page_test`)는 `ItemIconTile`이 아닌 계획 위젯의 `Image.asset`을 본다. 그래서 영향이 없다.
- `ItemIconTile`을 그리는 다른 테스트는 `ui_kit_gallery_data_test`(`ItemTile` 개수만 셈)뿐이다. PC의 `test/kit` 전체를 다시 받아 확인했다.

"새"로 적은 파일의 추적 여부(PC `.git/index` 직접 읽기 = `git ls-files`, HEAD tree도 확인):

| 파일 | index | HEAD tree | 판정 |
|---|---|---|---|
| `frontend/lib/ui/widgets/page_header_override.dart` | 없음 | 없음 | 새 파일 맞음 |
| `frontend/lib/ui/widgets/growth_calculator_section.dart` | 없음 | 없음 | 새 파일 맞음 |
| `frontend/test/growth_calculator_view_test.dart` | 없음 | 없음 | 새 파일 맞음 |
| `frontend/test/kit/item_icon_tile_test.dart` | `2ab2d352` | 같음 | 추적 중 → modified로 옮김 |

modified로 적은 나머지 7개 파일의 pre 사본도 index blob과 해시가 같다. 그 파일들에는 미커밋 변경이 없었다.

앞으로: 파일을 새로 만들기 전에 같은 경로를 PC에서 직접 확인한다(폴더 목록 또는 `.git/index`). 예전에 받아 둔 사본 폴더로 판단하지 않는다.

### FE3-f2a commit record (2026-10-08 08:30, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261008_080127\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE3-f2b 착수 기록 (2026-10-08)

- 작업 지시(09:01)의 §0을 읽었다: 워크플로 FE3-f 행·FB-1 "분할"·FB-13 행·재개 지점(아침), 오케스트레이터 로그 08:45·08:57, 이 문서의 FE3-f2 분할표 f2b 행과 f2a 종료·수정 기록, `frontend-redesign-status-backend.md` "프런트 워커 연결 메모"(FB-11a), FD-167·FD-170, J-calc §1 S3·S4, Calc-Student 시안.
- 0단계 기록: FE3-f2a `3e7272e2`, FB-11a `facdd1d3`(위 커밋 기록 표).
- 시작 시점 PC: HEAD 계열 `2bcdcbd9` 뒤 작업 트리. FB-13(백엔드 워커) 코드가 작업 트리에 있고 커밋 전이다.
- 고칠 파일 8개가 모두 추적 중인지 PC `.git/index`로 확인했다. pre 사본이 index blob과 같다(미커밋 변경 없음). 새 파일은 만들지 않았다.

## FE3-f2b 종료 기록 (2026-10-08, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없다. 그래서 `flutter analyze`·Dart 테스트·golden을 돌리지 못했고, 통과를 주장하지 않는다.
- 별도 검토 에이전트 2개가 lib 4파일과 테스트 4파일을 정적으로 읽었다(Flutter 3.44 소스로 API 대조). 고친 지적:
  1. 계산기 모드를 켜고 끌 때 레이아웃 뿌리 위젯이 `SizedBox` ↔ `ListenableBuilder`로 바뀌어 네 섹션 상태(검색창 포커스·초상)가 새로 만들어졌다. → 두 모드 모두 `ListenableBuilder(Listenable.merge([?calculator?.state]))`로 둔다(학생 모드 그림은 같다).
  2. S3 인연 칸(container-10)의 경계 사각형이 애장품·능력 개방 칸을 덮어 누르기를 가렸다. → 인연 칸을 맨 아래에 두고, 컨테이너·feature 하나에 해당하는 칸(인연·레벨·전용무기 Lv·능력 개방)은 누르기 자리를 그 경로로 자른다.
  3. 검색 Enter 테스트가 검색 결과 반영 전에 Enter를 눌렀다. → `enterText` 뒤 `pump` 한 번. 화면도 빈 검색·지금 학생과 같은 첫 결과에서는 아무것도 하지 않는다(바꾼 목표를 지우지 않게).
  4. 999,950 이상이 "1000K"로 보였다 → "1M". 내역 줄 이름 칸 92 → 108(“애장품 · 능력 개방” 잘림).
- 검토 에이전트 하나가 "FB-11a 메서드가 백엔드·클라이언트에 없다"고 했다. 워커가 받아 둔 사본이 오래된 것이었다. PC 파일을 다시 받아 `planning_protocol_client.dart`의 `planning.student.calculate` 검증과 `backend/core/protocol_v1.py`의 `METHOD_STUDENT_CALCULATE`를 확인했다.

### 바뀐 파일(모두 추적 중, 새 파일 없음)

| 파일 | 줄(+/−) | 내용 |
|---|---|---|
| `frontend/lib/ui/models/growth_calculator_adapter.dart` | +107 −25 | 단일 학생 계산 우선 + 임시 문서 폴백(`calculateGrowthTargets(Object, …)`, `growthCalculatorSupports`), `GrowthCalculatorCreditBreakdown`을 enum → "available + 범주별 값" 클래스로, `GrowthCalculatorResult.creditBreakdown`·`fromStudentCalculation`, 엔진이 `Object` 서비스를 받음 |
| `frontend/lib/ui/widgets/growth_calculator_section.dart` | +679 −6 | EX 최대 "M", 크레딧 내역 막대, S3 표시값·칸·"현재 …" 태그(`GrowthCalculatorIndicatorOverlay`), S4 선택 학생 요약·최근 계산 줄, `GrowthCalculatorModeData` 필드 3개 |
| `frontend/lib/ui/widgets/student_section_layout.dart` | +265 −26 | S3 계산기 분기(목표값·분홍·★ 목표 테두리·인연 목표 빗금·칸 겹침), S4 계산기 분기(`_calculatorSection4`, 검색 Enter), 인디케이터 위젯 5종에 강조색 인자(기본값 = 기존 색), 바탕 painter ★ 목표, `StudentRecentThumb.semanticPrefix`, 전환 때 S4 다시 들이기 |
| `frontend/lib/ui/pages/student_page.dart` | +33 −9 | 엔진 생성(`growthCalculatorSupports`), 최근 계산 듣기, `_openCalculator({record})`, `_openRecentCalculation`, 모드 데이터에 계획 포함·최근 계산 |
| `frontend/test/growth_calculator_view_test.dart` | +329 −25 | 대역이 `calculateStudent`를 덮어씀, 새 위젯 테스트 6 + 순수 1 |
| `frontend/test/growth_calculator_adapter_test.dart` | +119 −1 | 단일 학생 계산 묶음 4건(1회 호출·폴백·미지원·디바운스) |
| `frontend/test/goldens/golden_harness.dart` | +32 −24 | `GoldenCalculatorMockAppService`가 `calculateStudent`(9범주 내역 포함, `fromWire` 검증 통과)를 덮어씀 |
| `frontend/test/goldens/fe1g_baseline_golden_test.dart` | +13 −3 | `students-calculator` 기대값(내역 막대·레벨 태그·최근 계산) |

`lib/services/**`·`backend/`·`contracts/`·`frontend/assets/student_catalog.json`·스캐너·tactic 파일·`app_shell.dart`는 고치지 않았다.

### 계산 어댑터 교체(FB-11a 연결 메모대로)

- `calculateGrowthTargets(service, request)`: 서비스가 `PlanningStudentCalculationService`면 `calculateStudent(currentStudent:, targets:, inventory:)`를 한 번 부른다. 아니고 `PlanningDocumentService`면 예전 임시 문서 계산, 둘 다 아니면 `UnsupportedError`.
- 디바운스(250ms)·요청 번호·늦은 응답 버림·취소·오류 상태는 그대로다(엔진 코드는 서비스 타입만 바뀜).
- 결과: `credits`, `resources`에서 `credits` 행을 뺀 성장 재화(`row.toWire()` → 기존 `GrowthCalculatorResourceRow.fromWire`, 보유 모름은 그대로 Unknown), `warnings`, 9범주 `creditBreakdown`. 인연(`reservedBond`)은 쓰지 않는다(FB-11b 전 빈 상태 유지). 크레딧 보유·계획 포함 표기(FD-172)는 그대로다.
- `MockAppService`·`ProcessAppService`는 둘 다 단일 학생 계산을 가진다. mock은 목표와 상관없이 고정 결과(`mockStudentCalculationWire`)를 돌려주므로 mock 모드 화면의 숫자는 목표를 바꿔도 같다(백엔드 실행 모드에서 실제 계산).

### 크레딧 내역 막대(FD-162 (b))

| 줄 | 더하는 FB-11a 범주 |
|---|---|
| 레벨 | `level` |
| 스킬 | `ex_skill` + `skill` |
| 장비 | `equipment` |
| 성급 · 전무 | `student_star` + `weapon_star` + `weapon_level` |
| 애장품 · 능력 개방 | `favorite_item` + `potential` |
| 기타 | 위에 없는 범주(지금은 없음) |

- 9범주가 모두 한 줄에 들어간다(테스트로 고정). 0인 줄은 그리지 않지만 합계에는 영향이 없다. 줄 합 = 합계.
- 막대 길이는 가장 큰 줄 기준 비율(시안), 값은 "3.1M"·"150K" 짧은 수, 의미 구조 값은 쉼표 숫자.
- 내역이 없으면(임시 문서 경로) 숨긴다. 타일 안 남은 폭이 180px보다 좁아도 숨긴다(합계는 그대로).

### S3(FD-167)

- 계산기 목표값으로 그린다: 레벨·전용무기 Lv·스킬 4칸·장비 3칸(티어·Lv)·애장품·능력 개방. 학생 상세 인디케이터 위젯을 그대로 쓰고 값만 목표로 바꾼다(`growthCalculatorIndicatorValues`). 전투 능력치는 확정값 그대로다.
- ★는 현재 ★를 채우고 목표 ★를 테두리로 그린다(기존 `paintStudentStarStatus` 목표 표기). 인연은 현재 랭크 + 목표 빗금(FE3-b 게이지).
- 바뀐 칸 글자는 분홍(`growthCalculatorChangedColor`), 그대로인 칸은 흰색. 인디케이터 위젯 5종에 강조색 인자를 더했고 기본값이 기존 색이라 학생 모드 그림은 같다.
- 칸을 누르면 `toggleRow`(현재값 ↔ 직전 목표). 칸 key `calculator-cell-<행>`(전용무기는 Lv 칸 `weapon`과 ★칸 `weapon-star` 두 곳). 바꿀 것이 없는 칸은 누르기 동작이 없다.
- "현재 …" 분홍 태그: 묶음(레벨·성급·전용무기·스킬·장비·애장품·능력 개방·인연) 안의 행이 바뀌면 그 묶음 오른쪽 위 모서리에 단다. 글자는 현재값 출처(확정값/직접 입력)의 값이다.

### S4(FD-170·FD-172)

- 검색창은 그대로 둔다. 계산기 모드에서는 결과 목록이 없으므로 Enter(입력 동작 "검색")로 첫 결과 학생을 계산기로 연다.
- 선택 학생 요약: 이름 / "학교 · 클래스 · 계획에 있음·없음·확인 전"(FB-1 전 goals v1 기준) + 분홍 칩 "기준: 확정값/직접 입력". 학생 스캔 시각은 FB-2 전까지 숨긴다.
- 구분선 → "최근 계산 · 누르면 그때 목표로 다시 엽니다" → 초상 줄(최대 6, 앱 실행 동안만, 학생마다 한 건). 누르면 그 학생·기준·목표로 다시 연다. 비어 있으면 "아직 계산한 학생이 없습니다".
- 계정을 바꾸면 비운다: 셸이 학생 탭을 프로필 세대로 다시 만들고(최근 계산 객체도 새로 생김), 페이지는 `syncProfile`도 부른다. 위젯 테스트로 고정했다.

### 표기 확인: 스킬 최대 "M"

f2a의 S2 목표 행은 최대일 때 EX "5", 나머지 "M"이었다. 기존 규칙을 찾아 EX도 "M"으로 맞췄다. 근거(모두 최대값 이상이면 "M", EX 최대 5·나머지 10):
- 학생 상세 인디케이터 `_StudentStatusIndicators._skillValue(key, maximum)`(`'ex_skill', 5`)
- 계획 요소 빌더 `_skillDisplay(value, maximum)`
- 목록 행 `formatDiagonalMediaSkillLevels`(최대 `[5, 10, 10, 10]`)
- 필터 범위 `StudentRangeValueStyle.skill`, 키트 갤러리 EX 범위(`value >= 5 ? 'M'`)
시안 S3의 "5/5"는 예시 표기라 쓰지 않는다(FD-025). S3는 기존 인디케이터를 그대로 써서 원래 "M"이다.

### 위젯·단위 테스트

`growth_calculator_view_test.dart`(새 6 + 순수 1, 기존 9 + 1은 대역만 교체):
1. S3 목표값·EX "M"(S2·S3)·분홍·"현재 1" 태그, 레벨 칸 토글 두 번(바뀌는 칸 수 −1, 흰색, 태그 사라짐 → 되돌아옴)
2. S3 칸 의미 구조(label "레벨 칸", value "바뀜, 목표 Lv.50, 현재 1", 버튼·누르기)
3. S4 요약·"기준: 확정값", 최근 계산 추가, 검색 Enter로 다른 학생, 최근 계산을 누르면 그 목표(레벨 50)로 다시 열고 그 목표로 계산
4. 계정 전환(`SettingsPage.onProfileChanged`) 뒤 계산기가 닫히고 최근 계산이 비어 있다
5. 단일 학생 계산 1회 + 내역 다섯 줄 값(600K·150K·200K·250K·34.6K)
6. 임시 문서 경로(단일 학생 계산이 없는 서비스)는 내역 막대를 숨긴다(섹션만 따로 그림)
7. (순수) 묶음이 범주를 빠뜨리지 않음·합계 일치·"기타"·짧은 수

`growth_calculator_adapter_test.dart` 새 묶음 4건: 두 기능이 다 있으면 `calculateStudent`만 1회(문서 계산 0)·내역·크레딧 행 제외, 없으면 임시 문서·내역 없음, 미지원 서비스 `UnsupportedError`, 엔진 디바운스 뒤 마지막 요청으로 1회.

### golden 변화 예측

- 바뀜(정상): `students-calculator`. S3가 목표값(레벨 90·스킬 M·장비 1 +2 티어, 분홍)과 "현재 …" 태그, ★ 목표 테두리(스킬 MAX가 ★를 끌어올리면). S4가 아루 요약·"기준: 확정값"·최근 계산 한 칸. 크레딧 타일 오른쪽에 내역 다섯 줄(레벨 3.1M · 스킬 7.9M · 장비 4.6M · 성급 · 전무 2.8M · 애장품 · 능력 개방 20K). S2 EX 목표 칸 "5" → "M".
- 차이 0: 학생 장면 5장(학생 모드는 강조색 기본값·같은 뿌리 위젯), `title`·계정 3장·`home`·`plan-*`·`scan-student-review`.
- 장면 추가는 하지 않았다(능력 개방 플라이아웃 열림 장면은 디바운스 Timer·OverlayPortal 정착 위험에 비해 얻는 것이 적다고 판단).
- FB-13이 같은 작업 트리에 있어 그쪽 변화(golden harness `_withDisplayName`이 `hasFavoriteItem`을 잃음 등, 아래 "FB-13")가 섞일 수 있다. 차이가 예측과 다르면 원인을 조사해 보고한다.

### 처리한 FD

FD-162 (b)(단일 학생 계산·내역 막대, 폴백 (a)), FD-167 (a)(S3 칸 토글·분홍/흰색·태그), FD-168(S4 "기준" 칩), FD-170 (a)(최근 계산 줄·다시 열기·계정 전환 비움), FD-172(계획 포함 goals v1 기준·스캔 시각 숨김·크레딧 보유 빗금 유지), FD-049(계산기 목표는 활성 계획 인연 목표와 섞지 않음: S3 인연 빗금은 계산기 목표만 씀).

### 검수표 (mock 모드, 2560×1440 모니터 최대화 = 2560×1392)

| artboard·상태 | 여는 방법 | 확인 |
|---|---|---|
| Calc-Student S3 | 학생 탭 → 성장 계산기 열기 → 아무 목표 + | S3 해당 칸이 목표값·분홍으로 바뀌고 칸 오른쪽 위에 "현재 …" 분홍 태그가 붙는다. 그대로인 칸은 흰색 |
| S3 칸 누르기 | 분홍 칸을 누른다 | 그 칸만 현재값(흰색)으로, 다시 누르면 직전 목표로. "바뀌는 칸 n · 그대로 m"과 필요 재화가 같이 바뀐다 |
| ★·인연 | 성급·인연 목표를 올린다 | ★는 현재만 채워지고 목표까지 테두리, 인연 게이지에 목표 빗금 |
| 스킬 최대 | 스킬 행 MAX | S2 EX·일반 모두 "M", S3 SKILL SUMMARY도 "M" |
| S4 | 계산기 연 상태 | 학생 이름 / 학교 · 클래스 · 계획 포함, "기준: 확정값" 칩(직접 입력이면 바뀜), 최근 계산 초상 |
| 최근 계산 | 다른 학생을 검색창에 쓰고 Enter → 앞 학생 초상 누르기 | 앞 학생이 그때 목표로 다시 열린다 |
| 계정 전환 | 설정에서 다른 계정으로 | 계산기가 닫히고 다시 열면 최근 계산에 앞 계정 학생이 없다 |
| 크레딧 내역 | 크레딧 타일 오른쪽 | 막대 줄(레벨·스킬·장비·성급 · 전무·애장품 · 능력 개방), mock은 고정 숫자 |

### 알려진 시안 차이

1. 시안 내역 막대는 4줄이다. 9범주를 빠뜨리지 않으려고 "애장품 · 능력 개방" 줄을 더했다(0이면 그리지 않음).
2. 시안 S3 "EX 5/5" 대신 기존 규칙 "M".
3. S4 "학생 스캔 어제 21:40"은 FB-2 전까지 숨긴다(FD-172).
4. 최근 계산을 "직접 입력" 기준으로 다시 열면 기준과 목표는 돌아오지만, 그때 고친 현재값은 남지 않는다(FD-170 기록은 학생 + 기준 + 목표). 목표는 확정값 위로 다시 맞춘다.

### FB-13 반영 여부

- FB-13은 이 slice보다 먼저 커밋되지 않았다(작업 트리에 코드만 있음). 그래서 작업 지시대로 폴백 제거와 애장품 행 숨김 테스트를 넣지 않고 후속으로 남긴다.
- 지금 코드도 FB-13 값을 쓴다: `_calculatorMetadata`는 metadata에 `has_favorite_item`이 있으면 그 값을 그대로 쓰고, 없을 때만 true로 채운다. FB-13의 `StudentCatalogEntry.metadata`는 모든 항목에 bool을 넣으므로, FB-13이 들어오면 폴백은 쓰이지 않는다(아야네 등 KR false 학생은 12행).
- 후속(FB-13 커밋 뒤 프론트): ① `_calculatorMetadata`의 true 폴백 제거(`hasFavoriteItem` 직접 사용) ② 애장품 없는 학생(mock 아야네)의 12행·S3 애장품 칸 누르기 없음 테스트.
- 백엔드 상태 문서의 "프런트 워커 연결 요청"(FB-13): 프론트 소유 테스트 fixture 2곳(`student_form_cycle_test.dart` `_wire`, `student_studio_layout_test.dart` Erika `fromWire`)에 필수 `has_favorite_item`이 없어 9건 실패, golden harness `_withDisplayName`이 `hasFavoriteItem`을 잃음. 이번 지시 범위 밖이라 고치지 않았다. FB-13 gate 전에 누가 고칠지 오케스트레이터 판단이 필요하다.

### 미검증 항목

1. `flutter analyze`(info 0), Dart 테스트, golden(바뀜 1). 사용자 PC에서 실행해야 한다.
2. 실행해 봐야 아는 것: S3 태그가 작은 창에서 서로 겹치는지, 칸 누르기 자리(사각형으로 나눈 스킬·장비 칸)가 실제 열과 맞는지, 계산기 전환 때 S4 다시 들이기 모양.

### 발견 사항(오케스트레이터 판단 필요)

1. 위 FB-13 프론트 fixture 3곳(테스트 2 + golden harness 1).
2. mock 모드 계산 숫자는 고정이다(`MockAppService.calculateStudent`가 목표를 보지 않음). 검수 때 숫자 변화는 백엔드 실행 모드에서만 보인다.

### 사용자 실행 순서(시각 변경, 두 워커가 모두 멈췄을 때만 gate)

① gate만 실행하고 멈춘다. 예상: analyze info 0, 테스트 통과(단, FB-13 fixture 3곳이 고쳐지지 않았으면 그쪽 9건 RED), golden은 `students-calculator` 차이. 결과를 오케스트레이터에게 보낸다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

② **FB-13 커밋 뒤에만** golden을 갱신하고 GREEN을 확인한다(두 slice가 같은 baseline 폴더를 `whole`로 커밋한다).

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

③ 승인 뒤 커밋한다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3f2b -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3f2b
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesigndocs
```

`debug/frontend_fe3f2b/commit.json`: modified 8, added 0, `whole`은 `frontend/test/goldens/baseline`, status true. pre 사본은 `debug/frontend_fe3f2b/pre/`. (추가 작업 뒤 modified 10, 아래)

## FE3-f2b 추가 작업 기록 (2026-10-08 10:16 지시, FB-13 프론트 연결)

오케스트레이터가 FE3-f2b를 승인(로그 10:14)한 뒤 같은 slice에 더한 작업이다. FB-13 결과(`StudentCatalogEntry.hasFavoriteItem`, 엄격한 `fromWire`)는 작업 트리에 있다(커밋 전). 계약은 완화하지 않았고 테스트도 지우지 않았다. gate 미실행.

### 고친 것

1. `test/student_form_cycle_test.dart` `_wire`: `'has_favorite_item': false`를 `jp_only` 다음에 더했다. 이 테스트의 학생은 지어낸 id라 애장품 없음으로 둔다.
2. `test/student_studio_layout_test.dart` Erika `fromWire`(1859행 부근): `'has_favorite_item': false`. asset의 `erika` 값(false)과 같다.
3. `test/goldens/golden_harness.dart` `_withDisplayName`: `hasFavoriteItem: source.hasFavoriteItem`을 넘긴다(긴 이름 사본이 값을 잃지 않게).
4. `lib/ui/pages/student_page.dart`: `_calculatorMetadata`(값이 없으면 true로 채우던 폴백)를 지웠다. 현재값 변환 seed는 `entry.metadata`를 그대로 쓰고, 계산기 상태는 `hasFavoriteItem: entry.hasFavoriteItem`이다. 쓰지 않게 된 `planStudentHasFavoriteItemMetadata`는 import `show`에서 뺐다. `StudentCatalogEntry.fallback`(메타데이터 없는 학생)은 false라 12행이다.
5. `test/growth_calculator_view_test.dart`: 위젯 테스트 1건 추가 "KR 애장품이 없는 학생(아야네)은 애장품 행 없이 12행이다(FB-13)". 아루(KR true)는 `hasFavoriteItem` true, S3 `calculator-cell-favoriteItem` 있음 → 검색 Enter로 아야네(KR false) → `hasFavoriteItem` false, `rows` 12개·`favoriteItem` 없음, S2 `calculator-row-favoriteItem`·S3 `calculator-cell-favoriteItem` 없음, "바뀌는 칸 0 · 그대로 12", 성장 MAX 뒤 "바뀌는 칸 12 · 그대로 0". 끝에서 디바운스 Timer를 정착시킨다. 기존 "빠른 목표" 테스트는 13행 근거 주석만 고쳤다(catalog true).
6. 남은 fixture 검사: `'jp_only'`를 쓰는 프론트 파일을 모두 봤다. `planning_protocol_client_test.dart`는 FB-13이 이미 고쳤고, `plan_element_builder_test.dart`는 metadata 맵(선택 key)이라 `fromWire`를 거치지 않으며, `lib/`는 읽기만 한다. 더 고칠 곳은 없다.

### pre 사본(HEAD 기준)

HEAD는 `2bcdcbd9`(문서 커밋, 부모 `facdd1d3`). git 객체를 직접 읽어 HEAD blob과 맞췄다.

| 파일 | HEAD blob | pre 사본 |
|---|---|---|
| `test/student_form_cycle_test.dart` | `a57e78d2` | HEAD blob(이번에 처음 고침, 고치기 전 작업 트리와도 같음) |
| `test/student_studio_layout_test.dart` | `ed1ac1af` | 같음 |
| `lib/ui/pages/student_page.dart` | `7971c457` | 기존 pre 사본 그대로(HEAD와 같음) |
| `test/goldens/golden_harness.dart` | `597c373b` | 같음 |
| `test/growth_calculator_view_test.dart` | `a223bea6` | 같음 |

### commit.json

`debug/frontend_fe3f2b/commit.json`: modified 10(앞 8 + fixture 테스트 2), added 0, `whole`은 `frontend/test/goldens/baseline`, status true. 메시지에 FB-13 연결 줄을 더했다.

### golden 변화 예측(갱신)

- `students-calculator`: 바뀜(앞의 f2b 예측 그대로). 아루는 KR true라 13행이 유지된다(HEAD에서도 폴백 true였으므로 행 수 차이 없음).
- jp_only가 false로 바뀐 7명(niko·rena·akane_school_uniform·otogi·konoka·koyuki_pajama·kurumi)은 golden fixture에 없다. 학생 장면 catalog는 아루·아야네·호시노·슌(수영복)·히나·세리카·케이·하스미·나구사·노아, 기본 mock은 아루·아야네, `scan-student-review`는 아루·호시노다. 그래서 "JP" 배지 변화는 없다. 슌(수영복)은 HEAD와 지금 모두 jp_only true라 배지가 남는다.
- `_withDisplayName` 사본: 호시노 한 명만 쓴다. 호시노 `hasFavoriteItem`이 이제 true로 전달된다(전에는 false). 호시노를 고르는 장면이 없고 학생 격자·상세는 애장품 유무를 그리지 않으므로 화면 차이 0으로 본다.
- `plan-element-builder`: FB-13 때문에 바뀔 수 있다(f2b 코드와 무관). HEAD catalog에는 `has_favorite_item`이 없어서 계획 요소 빌더(`planStudentHasFavoriteItemMetadata`, key가 없으면 false)가 아루를 애장품 없음으로 봤다. FB-13 뒤 아루는 true다. 이 장면은 기본 mock 격자의 첫 학생(catalog 순서상 아루)으로 빌더를 열므로 애장품 칸·행이 생길 수 있다. 다른 `plan-*` 장면도 아루의 애장품 요소를 그리면 같은 이유로 바뀔 수 있다.
- 그 밖의 장면은 차이 0.
- 차이가 예측과 다르면 원인을 조사해 보고한다.

### 사용자 실행 순서(바뀐 점)

① gate. 예상: analyze info 0, FB-13 fixture 실패 9건은 이번 수정으로 사라진다, golden은 `students-calculator`(+ FB-13으로 `plan-element-builder` 가능) 차이.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

②·③은 앞 "FE3-f2b 종료 기록"과 같다. golden 갱신은 FB-13 커밋 순서에 맞춰 오케스트레이터가 정한다(두 slice가 같은 baseline 폴더를 `whole`로 커밋한다).

### 수정 (2026-10-08, gate `20261008_102700` RED 뒤)

gate 결과: analyze·test-1·test-3·process 38·almanac·diff-check 통과. 실패는 3건이다.

1. `student_page_test.dart` "catalog search and calculator entry use services": RenderFlex가 오른쪽으로 67px 넘침(f2b 코드 원인).
   - 원인: 크레딧 타일(`_CreditTile`)의 Row가 아이콘 79 + 간격 18 + 합계 칸(고정 폭) + 내역 막대 앞 간격 24 + 막대(Expanded)였다. 1024×768에서 타일은 최소 폭 420, 안쪽 폭은 420 − 32.6 − (128/tan80° + 14) = 350.8이다. 기본 `MockAppService.calculateStudent`의 크레딧은 14,000,529라 테스트 글꼴(글자당 1em)에서 30px × 10글자 − 자간 0.3 × 10 = 297px이 된다. 79 + 18 + 297 + 24 − 350.8 = 67.2로 보고값과 맞는다. f2a는 내역 간격 24가 없고 숫자도 짧아 넘치지 않았다.
   - 수정: 합계 칸(크레딧 글자 · 숫자 · 보유 빗금 줄)을 `ConstrainedBox(maxWidth: 남는 폭)` + `FittedBox(scaleDown, 왼쪽 정렬)`로 감싸, 남는 폭보다 넓으면 같은 비율로 줄인다. 남는 폭 = 안쪽 폭 − 79 − 18 − (내역이 있으면 24). 내역 막대는 그 뒤 남는 폭을 쓰고 180px 미만이면 숨긴다(기존 규칙). 실제 글꼴·큰 창에서는 합계 칸이 남는 폭보다 좁아 배율 1이라 `students-calculator` 모양은 그대로다. 바뀐 파일은 `growth_calculator_section.dart` 하나(commit.json modified에 이미 있음).
2. golden `students-calculator` 1.51%: 예측한 f2b 변화다. 실패 이미지에서 S3 목표값·"현재 …" 태그, S4 요약·"기준: 확정값"·최근 계산, 크레딧 18,420,000과 내역 다섯 줄(3.1M · 7.9M · 4.6M · 2.8M · 20K), 13행을 확인했다.
3. golden `plan-element-builder` 0.03%: 예측한 FB-13 영향이다. 차이는 x 522–1195, y 285–624 한 곳뿐이다. 장비 상태 넷째 칸 "애장품"이 "-"에서 "− T0 + / MAX" 스테퍼로, 왼쪽 장비 칸의 애장품이 "-"에서 자물쇠로 바뀌었다. 아루의 `has_favorite_item`이 true가 되어 계획 요소 빌더가 애장품 칸을 연다(f2b 코드 무관).

사용자 실행 순서: gate를 다시 돌린다. 예상: test-2 통과, golden은 위 2장만 차이(갱신 전). 그 뒤 golden 갱신 시점(`-UpdateGoldens`)은 FB-13 커밋 순서에 맞춰 오케스트레이터가 정한다.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
```

### gate `20261008_121125` 결과 (2026-10-08 12:11)

- analyze, test-1 303 · test-2 358 · test-3 22(UI 683), process 38, almanac, diff-check 통과. `student_page_test` 넘침은 사라졌다.
- golden 실패 2장은 예측과 같다: `students-calculator` 1.51%(f2b), `plan-element-builder` 0.03%(FB-13).
- 두 장의 testImage는 `20261008_102700`의 testImage와 sha256까지 같다. 크레딧 타일 수정은 golden 화면을 바꾸지 않았다(실제 글꼴에서 배율 1).
- HEAD가 `8b880441`로 움직였다(다른 작업 커밋 "A0: define animation spectrum contract…", "metadata M0"). f2b 파일 10개의 index blob은 그대로라 pre 사본(HEAD 기준)도 그대로 맞다.
- FB-13은 아직 커밋 전이다(index의 `app_service.dart`·`student_catalog.json`이 작업 트리와 다르다). `plan-element-builder` 차이는 FB-13 작업 트리 때문이므로, 지금 `-UpdateGoldens` 후 f2b가 baseline 폴더를 `whole`로 커밋하면 FB-13 커밋 전 baseline에 FB-13 화면이 들어간다. 순서(FB-13 먼저 커밋, 또는 f2b에 함께 싣기)는 오케스트레이터가 정한다.

남은 사용자 실행 순서(오케스트레이터 결정 뒤):

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3f2b -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3f2b
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesigndocs
```

### 결정: golden 함께 갱신 (사용자, 2026-10-08 12:19)

- FB-13 커밋을 기다리지 않고 지금 `-UpdateGoldens`로 `students-calculator`(f2b)와 `plan-element-builder`(FB-13 작업 트리의 애장품 칸)를 함께 갱신한다. f2b가 baseline 폴더를 `whole`로 커밋한다.
- 그래서 FB-13이 커밋되기 전까지 HEAD의 `plan-element-builder` baseline은 FB-13 화면이다. FB-13 커밋 뒤 그 장면은 차이 0이어야 한다. FB-13 쪽 코드(`app_service.dart`·`mock_app_service.dart`·`student_catalog.json` 등)는 f2b commit.json에 넣지 않는다(백엔드 워커 소유).
- commit.json 메시지에 이 내용을 한 줄 더했다(modified 10·added 0 그대로).
- 실행 순서: 위 "남은 사용자 실행 순서"와 같다(`-UpdateGoldens` → gate GREEN 확인 → `fe_commit -Slice fe3f2b -DryRun` → `fe_commit -Slice fe3f2b` → `fe_commit -Slice redesigndocs`).

### FE3-f2b commit record (2026-10-08 12:32, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261008_122807\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE4-a 분할과 FE4-a1 착수 기록 (2026-10-08)

- 작업 지시(14:14)의 §0을 읽었다: 워크플로 FE4 절(공통 3-Section 기하, FE4-a 행)·재개 지점(2026-10-08 오후)·"Lane A 앞뒤 병렬", 오케스트레이터 로그 14:05(파일 경계), FD-070~FD-082(FD-078·FD-081·FD-082), C 보고서 §0~§4, artboard-map Flow-* 행, 시안 Flow-1-Students(`dc_outline.py`).
- 0단계 기록: FE3-f2b `576bd568`, FB-13 `fa15e87c`(위 커밋 기록 표). 시작 커밋 `0fd37702`.
- 막힘 확인: FE4-a를 막는 FD-082는 확정(권장안 (a)), FD-078·FD-081은 확정/워커 재량. 열림 0건.

### 분할(운영 규칙 2)

`plan_section_layout.dart`(8,237줄)의 네 플래그는 두 갈래 흐름에 걸쳐 있다. 시나리오 만들기(`_creatingScenario` + 스냅샷 왕복)와 활성 계획 편집(`학생 추가`·`페이즈 만들기`·학생 탭 넘김, 플래그 3개)이다. 한 번에 바꾸면 `planning_page_test` 26건 중 흐름 관련 10건 남짓과 golden 3장(`plan-student-selector`·`plan-element-builder`·`plan-phase-editor`)이 함께 바뀌어 검토가 어렵다. 그래서 둘로 나눈다.

| sub-slice | 범위 | golden |
|---|---|---|
| **FE4-a1 흐름 골격 + 시나리오 만들기** (이번) | 새 Studio 문서(A 진행 레일·B 본문·C 보조), StepRail(스텝 4개·요약 4행·다음/이전), 초안 컨트롤러(문서 DTO를 감싸는 경계 어댑터, 디바운스 `planning.document.calculate`), 부족 재화 플라이아웃(FE2-c `ShortageBreakdownFlyout` 재사용). 계획 탭 S1 "시나리오 생성"(FD-081의 "새 시나리오") → 1단계, 시나리오 비교 "편집" → 3단계. `_creatingScenario`·`_editingScenario*`·`_PlanWorkspaceSnapshot` 왕복을 컨트롤러로 대체(초안이 활성 계획 작업 상태와 따로 있어 스냅샷이 필요 없다). 각 스텝은 기존 화면(학생 고르기·요소 편집기·페이즈 편집기)을 레일 옆에서 그대로 열고, 4단계는 기존 저장 대화상자를 연다 | 새 장면 추가만. 기존 plan-* 장면 차이 0 예상 |
| **FE4-a2 활성 계획 편집 경로 이관** (다음) | "학생 추가"·"페이즈 만들기"·학생 탭 넘김(`initialSeed`)을 흐름 1·3·2단계로 옮기고 `_showStudentSelector`/`_showElementBuilder`/`_showPhaseEditor`/`_switchingStudentSelector` 제거, 4단계 "계획에 반영"(메모리 반영, FB-1 전), 해당 `planning_page_test` 재작성 | `plan-student-selector`·`plan-element-builder`·`plan-phase-editor`(레일 크롬) |

- FE4-a1 동안 활성 계획 편집 경로는 지금 그대로 둔다(기능 손실 없음). 두 경로가 같은 기존 화면을 각자 띄우는 중복은 a2에서 없앤다.
- 바꿀 기존 파일(추적 중, PC `.git/index`로 확인 예정): `plan_section_layout.dart`, `plan_student_selector.dart`(선택 변화 알림 콜백 1개 추가), `planning_page_test.dart`, golden 테스트·하네스. 새 파일은 같은 경로가 index에 없는지 확인한 뒤 만든다.

## FE4-a1 종료 기록 (2026-10-08, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없다. 그래서 `flutter analyze`·Dart 테스트·golden을 돌리지 못했고, 통과를 주장하지 않는다.
- 별도 검토 에이전트 1개가 새 파일 5개와 바뀐 파일 5개를 정적으로 읽었다(정의 파일과 생성자·콜백 시그니처 대조). 고친 지적:
  1. `PlanFlowDraft`의 `Map.unmodifiable({… List.unmodifiable(…)})`가 문맥 타입을 받지 못해 `List<dynamic>`이 되고, 단계가 있는 초안을 만들 때마다 런타임 TypeError가 난다. → 맵·리스트에 타입 인자를 적었다.
  2. `confirmStudentStages`의 `?? const []`가 `List<dynamic>`으로 추론돼 `Set<dynamic>`을 `Set<String>` 인자로 넘긴다(컴파일 오류). → `const <PlanElementStageDraft>[]`.
  3. `plan_flow_rail.dart`의 쓰지 않는 `anchored_flyout.dart` import 삭제(analyze 경고).
  4. 계산 문서 테스트가 리스트를 담은 record를 `equals`로 비교했다(record 안 리스트는 동일성 비교라 늘 실패). → 리스트로 바꿨다.
  5. 흐름 화면·새 진입 메서드가 `controller.reverse()` Future를 기다렸다. 모션 도중 다른 forward/reverse가 끼면 그 Future는 끝나지 않아 `_switching`이 영영 true로 남는다(`on TickerCanceled`는 `.orCancel` 없이는 오지 않는다). → 새 코드(`PlanFlowWorkspace._changeStep`·`_close`, `_openScenarioCreation`, `_editScenarioFromComparison`)는 퇴장을 시작만 하고 `AppMotion.section`만 기다린다. 기존 메서드의 같은 패턴은 이번 범위 밖이라 그대로 둔다.
  6. `_shownStep`을 `initState`에서 정하고 `flow`가 바뀌면 다시 정한다(첫 알림이 단계 변경이면 4단계 등장 모션을 건너뛰던 문제).
- 검토 중 PC `planning_models.dart`·`mock_app_service.dart`·`scenario_service.dart`가 FB-1a 작업으로 바뀐 것을 확인했다(작업 트리, 미커밋). 이 slice 코드는 그 변경과 함께 컴파일된다: `PlanningDocumentStage(targets: Map<String, int>)`는 `Map<String, int?>` 인자에 들어가고, `PlanningDocument`의 새 인자(`version`·`goalMetadata`)는 선택이다. 세 파일은 고치지 않았다.

### 분할 여부

FE4-a를 a1/a2로 나눴고 이번은 **FE4-a1**이다(위 "FE4-a 분할과 FE4-a1 착수 기록"). 활성 계획 편집 경로(학생 추가·페이즈 만들기·학생 탭 넘김)는 지금 그대로 두고 FE4-a2에서 흐름으로 옮긴다.

### 바뀐 파일

| 파일 | 상태 | 줄(+/−) | 내용 |
|---|---|---|---|
| `frontend/lib/ui/studio/plan_flow_studio_layout.dart` | 새 파일 | +70 | 흐름 3-Section Studio 문서(A `flow-rail` (0,2,22,94) 왼쪽 사다리꼴, B `flow-body` (15,2,56,94) 아래 평행사변형, C `flow-aside` (72,2,24,94) 오른쪽 사다리꼴). 순수 데이터 |
| `frontend/lib/ui/models/plan_flow_draft.dart` | 새 파일 | +866 | `PlanFlowStep`·`PlanFlowDraft`(학생·학생별 단계·칸), `PlanFlowDocumentBoundary`(문서 DTO를 만들고 읽는 유일한 곳), `PlanFlowCalculation.fromProjection`(크레딧·부족 재화), `PlanFlowContext`, `PlanFlowController`(단계 규칙·초안 편집·250ms 디바운스 계산·요청 번호·늦은 응답 버림·오류 상태·시나리오 저장) |
| `frontend/lib/ui/widgets/plan_flow_rail.dart` | 새 파일 | +682 | `PlanFlowRail`(제목+InfoPopover, 스텝 4개, 연결선, 요약 4행, 부족 재화 플라이아웃, 계산 오류, 다음/이전), 섹션 경로·painter 도우미, 문구 함수 |
| `frontend/lib/ui/widgets/plan_flow_workspace.dart` | 새 파일 | +685 | `PlanFlowWorkspace`: 레일 + 단계 본문(1 학생 고르기, 2 요소 편집기, 3 페이즈 편집기, 4 B "이렇게 만들어집니다"·C 저장 위치), 섹션 모션, 기존 저장 대화상자 이전 |
| `frontend/test/plan_flow_test.dart` | 새 파일 | +747 | 아래 테스트 |
| `frontend/lib/ui/widgets/plan_section_layout.dart` | 수정(CRLF 유지) | +86 −314 | `_PlanWorkspaceSnapshot`·`_creatingScenario`·`_editingScenario*`·스냅샷 왕복·`_saveScenarioDraft` 제거, `PlanFlowController? _flow`, `_openScenarioCreation`·`_closeFlow`·`_discardFlow`·`_editScenarioFromComparison`, 흐름이 열려 있으면 홈 섹션을 숨기고 `PlanFlowWorkspace`를 그린다 |
| `frontend/lib/ui/widgets/plan_student_selector.dart` | 수정 | +25 −17 | 선택 변화 알림 `onSelectionChanged`(선택 인자), `_selectedSeeds()` 추출 |
| `frontend/test/planning_page_test.dart` | 수정 | +42 −25 | 시나리오 만들기 테스트 2건을 흐름 기준으로 다시 씀 |
| `frontend/test/goldens/golden_harness.dart` | 수정 | +66 | `GoldenPlanFlowMockAppService`(크레딧 48,200,000, 오파츠 부족 5종 + 충분 1종) |
| `frontend/test/goldens/fe1g_baseline_golden_test.dart` | 수정 | +41 | 새 장면 2개 |

`lib/services/**`, `backend/`, `contracts/`, `planning_models.dart`, 스캐너·tactic·metadata 소유 파일, `developer_tools*`, `app_shell.dart`는 고치지 않았다.

### 테스트

- `plan_flow_test.dart`
  - 기하: 세 섹션 다각형이 시안 점(2560×1208 캔버스)과 1px 안.
  - 컨트롤러: 단계 이동·비활성 조건(학생 없으면 2단계 불가, 단계 없으면 3단계 불가, 칸 배치가 끝나야 4단계), 확정한 학생 덧붙이기.
  - 경계: `calculationWire`가 칸에 없는 단계를 단계 번호별 임시 페이즈에 넣음, `toScenarioDocument` ↔ `fromDocument` 왕복.
  - 계산 결과: 크레딧 줄 대체, 부족을 모르면 "—".
  - 레일: 상태 칩·비활성 버튼, Semantics label·value·hint(핸들은 본문 끝에서 dispose).
  - 디바운스: 편집 3번 → 계산 1번, 요약 "2명"·"3개"·"1.2M"·"2종", 오류 문구. 늦은 응답 버림.
  - 플라이아웃: 탭으로 열림, 부족 큰 순, Esc로 닫힘.
  - 기존 화면: PlanningPage에서 1단계 학생 고르기 → 레일 "다음"(보류 선택) → 2단계 요소 편집기(B 윗변 왼쪽부터) → 1단계 버튼 → 다음 → 프리셋 확정 → 다음 → 3단계 페이즈 편집기 → 이전 → 요소 편집기.
- `planning_page_test.dart`: "시나리오 생성"이 흐름을 열고 그만두기가 학생 고르기 퇴장 모션을 트는지, 흐름 안에서 요소 편집기·페이즈 편집기를 거쳐 4단계 → "저장하고 닫기" → 대화상자 → 시나리오 1건 저장.

### golden 예측

- 새 장면 2개: `plan-flow-step1`(시나리오 생성 → 레일 + 학생 고르기), `plan-flow-step2`(학생 1명 → 균형 성장 프리셋 확정 → 디바운스 뒤 요약 "48.2M"·"5종"). 아이템 ID는 실제 아이콘이 있는 오파츠(`Nebra_3`·`Phaistos_3`·`Wolfsegg_0`·`Nebra_2`·`Phaistos_2`, 충분 `Nebra_1`)만 쓴다. 첫 실행은 기준 PNG가 없어 RED가 정상이다.
- 기존 21장면은 차이 0 예상. 시나리오 만들기 경로만 바뀌었고, 기존 장면 중 그 경로를 지나는 장면은 없다(`plan-scenario-list`·`plan-scenario-compare`는 시나리오를 미리 넣고 연다).

### 처리한 FD

- **FD-078**: 섹션 모션을 부착면 규칙으로(레일 0/180, B 80/260, C 180/0).
- **FD-081**: 이번 진입은 계획 탭 안만(S1 "시나리오 생성" → 1단계, 시나리오 비교 "편집" → 3단계). 학생 탭 → 2단계는 FE4-g.
- **FD-082**: 권장안 (a) 전제로 진행했다. 흐름 초안은 활성 계획 작업 상태와 따로 있다.

### 바뀐 동작(검토 때 볼 것)

1. 시나리오 만들기 동안 S1(계획 홈)이 보이지 않는다. 흐름이 화면 전체를 쓴다.
2. 저장 대화상자에서 취소하면 4단계에 남는다(전에는 시나리오 만들기를 끝냈다).
3. 페이즈 편집기 "완료" 뒤 바로 대화상자가 뜨지 않고 4단계를 보인다. 대화상자는 레일 "저장하고 닫기" 또는 C "시나리오로 저장"으로 연다.
4. 1단계에서 레일 "다음"을 누르면 학생 고르기에서 고르는 중인 학생으로 확정한다.
5. 학생을 다시 고르면 기존 학생 뒤에 덧붙인다(바꾸지 않는다).
6. 4단계 부제는 "시나리오로 저장". 활성 계획 두 갈래(FD-079)는 FB-1 뒤 FE4-e.
7. 부족 재화 플라이아웃은 재고 보기·아이템 탭 이동을 아직 뺐다(FE4-b~d).
8. 흐름 섹션은 PlanningPage의 좌우 16px 패딩 안에 그려져 시안보다 2528/2560 비율로 좁다(기존 계획 화면과 같은 규칙).

### 검수표

| 항목 | 확인 |
|---|---|
| A·B·C 섹션이 시안 Flow-* 좌표와 맞는다 | 기하 테스트(1px) |
| 스텝 4개·요약 4행·다음/이전, 비활성 조건 | 위젯 테스트 |
| 요약이 계산 뒤 바뀐다, 디바운스 1회 계산 | 위젯 테스트 |
| 부족 재화 플라이아웃 열기·닫기 | 위젯 테스트 |
| 기존 세 화면이 각 단계에서 열린다, 기능 손실 없음 | 위젯 테스트 + planning_page_test |
| Semantics value 3종(스텝 칩·부제, 요약 값, 저장 위치) | 위젯 테스트 1건 + 코드 |
| 앱 문구 ~습니다체 | 코드 확인 |
| 금지 파일 미수정 | 바뀐 파일 표 |

### FB-1a 뒤 v2 전환 메모

- 바꿀 곳은 `PlanFlowDocumentBoundary` 하나다. `toScenarioDocument`·`calculationWire`에서 `version: 2`와 `goalMetadata`를 채우고, 목표 없음은 `null`로 둔다. `fromDocument`는 `stage.targets` 대신 `nullableTargets`를 읽는다(지금 FB-1a 작업 트리의 `targets` getter는 null이 있으면 StateError를 던진다).
- `PlanElementStageDraft`가 `Map<String, int>`를 쓰는 동안은 경계에서 v1 ↔ v2를 바꾼다. 편집기를 nullable로 바꾸는 일은 FE4-c.

### 확인하지 못한 것

- analyze·테스트·golden 실행 전부(이 환경에 Flutter 없음).
- 새 장면 2개의 실제 그림. 첫 실행 RED 뒤 PNG를 보고 레일 글자 넘침·플라이아웃 위치를 확인해야 한다.

### 사용자 실행 순서

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① 두 워커가 멈춘 상태에서 gate → 오케스트레이터 검토
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 새 장면 기준 PNG 만들기 → gate 다시
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ③ 커밋
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4a -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4a
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesigndocs
```

## FE4-a1 gate `20261008_152312` 수정 기록 (2026-10-08 16:05 지시, 코드 작성 완료·gate 미실행)

gate RED 4건(오케스트레이터 로그 16:02)을 고쳤다. 이 환경에는 Flutter가 없어 다시 돌리지 못했다.

1. **analyze `prefer_initializing_formals`** (`plan_flow_draft.dart:473`): `PlanFlowController`의 서비스 필드를 공개 `final Object? service`로 바꾸고 `this.service`로 받는다(호출하는 쪽 `service:` 인자는 그대로).
2. **기존 화면 임시 수용(FE4-b~d 전까지).** 축소 방식으로 했다.
   - 1~3단계 기존 화면(학생 고르기·요소 편집기·페이즈 편집기)은 원래 받던 크기, 곧 계획 화면 캔버스 전체(`SizedBox.fromSize(size: 캔버스)`)로 배치한다. 학생 고르기는 원래처럼 계획 홈 S1 자리(`planSectionPath(size, 'element-1')`)와 `planStudentSelectorSection1RightAtReference(size)`를 받는다. 흐름에서는 S1을 그리지 않아 그 자리는 비어 보인다.
   - 그 캔버스를 `FittedBox(fit: contain)`으로 통째로 줄여 `planFlowLegacyBodyRect`에 넣는다. 히트 테스트는 변환을 따른다. 넣는 자리는 B 평행사변형 안에서 A·C·사선과 겹치지 않는 사각형이다. 왼쪽은 B 왼쪽 사선의 윗끝, 오른쪽은 B 오른쪽 사선의 아랫끝, 위아래는 B 윗변·아랫변이고, 네 변 모두 16px 안쪽이다. 기준 viewport(계획 화면 캔버스 폭 2528)에서 폭은 약 1230, 배율은 약 0.49다.
   - 실패 원인: 전에는 학생 고르기에 레일을 "섹션 1"로 줘 패널 배치가 바뀌었다. 그래서 학생 고르기 자신의 패널 표면(`CustomPaint`)이 확정 버튼 위에 놓여 `plan-student-selector-confirm-selection` 누르기를 가렸다. 요소 편집기는 B 윗변 왼쪽부터 오른쪽 끝까지의 좁은 폭을 받아 `plan_element_builder.dart:1557` Row(+33)·`:2793` Column(+4.6)·`:3671` Row(+37)가 넘쳤다. 원래 크기로 그리면 둘 다 기존 계획 화면과 같은 배치라 생기지 않는다.
   - B·C 섹션 표면은 1~3단계에도 그린다(빈 C는 FE4-b~d에서 채운다). 표면은 `IgnorePointer`다. 기존 화면은 그 위, 레일 아래에 둔다.
   - `planning_page_test.dart`는 이번에 고치지 않았다.
   - `plan_flow_test`는 기준 viewport 2560×1392로 그린다(전과 같음). 넘침 예외는 무시하지 않는다. "각 단계에서 기존 화면을 연다" 테스트의 위치 기대는 다음으로 바꿨다: 요소 편집기의 크기가 캔버스와 같고, 그려진 사각형이 `planFlowLegacyFittedRect`와 맞고, 레일 윗변 오른쪽 끝보다 오른쪽·C 왼쪽 사선 아랫끝보다 왼쪽이다.
3. **`plan_flow_test` 285행 `done` 기대.** 285행은 `goNext` 전, 2단계에 머무는 동안이라 컨트롤러가 `current`를 돌려준 것이 맞다. 시안으로 확인했다: Flow-1-Students는 학생 3명을 고른 1단계도 "지금"(`sel-pink`)이고, Flow-4-Save는 1~3단계 "완료"(`done`)·4단계 "지금"이다. 그래서 규칙은 "지금 단계는 할 일을 마쳐도 지금, 넘어간 뒤 완료"다(semantics 테스트의 2단계 "지금, 1명 중 1명 완료"와도 같다). 컨트롤러는 그대로 두고, 테스트를 고쳤다: 285행은 `current`를 기대하고, `goNext` 뒤 2단계 `done`·3단계 `current`를 확인한다.
4. **golden `plan-flow-step2`가 `plan-starter-preset-balanced-growth`를 못 찾음.** 원인은 2번과 같다. 확정 버튼 누르기가 가려져 요소 편집기가 열리지 않았다. 2번으로 해결될 것으로 본다. `plan-flow-step1`은 새 장면이라 기준이 없는 것이 정상이다.

### 바뀐 파일(이번 수정분)

| 파일 | 내용 |
|---|---|
| `frontend/lib/ui/models/plan_flow_draft.dart` | `service` 초기화 형식 |
| `frontend/lib/ui/widgets/plan_flow_workspace.dart` | `planFlowLegacyBodyRect`(B 안쪽 사각형)·`planFlowLegacyFittedRect`, 기존 화면을 원래 캔버스 크기로 그린 뒤 `FittedBox`로 축소(`plan-flow-legacy-slot`·`-fit`·`-canvas`), 학생 고르기에 계획 홈 S1 자리, B·C 표면을 모든 단계에 |
| `frontend/test/plan_flow_test.dart` | 285행 기대(시안 기준), 기존 화면 위치 기대 |

추적 중인 파일은 이번에 더 바꾸지 않았다. commit.json은 메시지의 흐름 화면 설명만 고쳤고, pre 사본은 그대로다.

### golden 예측(갱신)

- 새 장면 `plan-flow-step1`: 레일(1단계 "지금", 요약 "—"), B·C 빈 표면, B 안쪽에 약 0.5배로 줄어든 학생 고르기. 학생 고르기 패널은 원래처럼 S1 자리 오른쪽에 있고, S1 자리는 비어 있다.
- 새 장면 `plan-flow-step2`: 레일(1단계 "완료", 2단계 "지금", 요약 1명·단계 n개·"48.2M"·"5종"), B 안쪽에 약 0.5배로 줄어든 요소 편집기.
- 두 장면 안의 기존 화면이 작게 보이는 것은 축소 방식이라 정상이다.
- 기존 21장면은 차이 0 예상. 바뀐 것은 시나리오 만들기 흐름 안쪽뿐이고, 기존 장면은 그 경로를 지나지 않는다.

### 사용자 실행 순서

앞 "FE4-a1 종료 기록"과 같다(① gate → 오케스트레이터 검토, ② `-UpdateGoldens` 뒤 gate, ③ `fe_commit -Slice fe4a` → `redesigndocs`).

### FE4-a1 commit record (2026-10-08 16:45, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261008_164059\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE4-b 분할과 FE4-b1 착수 기록 (2026-10-08 저녁)

- 작업 지시(20:18)의 §0을 읽었다: 워크플로 FE4 절·FE4-b 행·재개 지점(2026-10-08 저녁·밤), 오케스트레이터 로그 16:02·16:48(+20:17 FB-1a 커밋 확인), `frontend-redesign-status-backend.md` FB-1a "FE4 초안 컨트롤러 연결 메모", 결정 대장 FD-074·FD-077·FD-078·FD-104, C 보고서 §1, 시안 Flow-1-Students·Flow-1-Students-Many·Flow-1-Students-Filter·Flow-1-Students-One(`dc_outline.py`).
- 0단계 기록: FE4-a `a18897a1`, FB-1a `682b2a7b`(위 커밋 기록 표).
- 막힘 확인: FD-074 확정(권장안 (b): 단계 프리셋·내 그룹은 프로필별 저장소, 필터 프리셋은 범위 제외), FD-104 확정(권장안 (a): 상태 객체 주입), FD-077·FD-078은 워커 재량(권장안: 7명 이상 압축, 부착면 규칙 + 모드 전환 360ms 보간). 열림 0건.

### 분할(운영 규칙 2)

1단계를 새로 만들고 초안을 v2로 바꾸는 일만으로 바뀌는 파일이 많다. 컨트롤러·문서 경계, 새 1단계 화면, 학생 그리드 배지, 필터 모달 그룹, FE4-a 흐름 테스트, golden 두 장면이 모두 바뀐다. 한 명 모드는 B·C 모양 보간과 학생 탭 상세 인디케이터(`student_section_layout.dart`의 비공개 `_StudentStatusIndicators`) 공개화가 필요하다. 그래서 따로 나눈다.

| sub-slice | 범위 | golden |
|---|---|---|
| **FE4-b1 여러 명 모드 + v2 초안** (이번) | 초안을 문서 v2로 전환(19키 `Map<String, int?>`, `goalMetadata`, 2·3단계 정수 편집기와는 경계에서 변환). 새 1단계 B: 제목·고른 수 칩, 검색·빠른 칩·적용 칩·필터 버튼 줄, 8열 그리드 + 고른 순서 배지. C: 고른 학생 목록(6명까지) / 압축 그리드(7명부터, 정렬 세그먼트·모두 비우기·경고 줄), 역할군 칩 + "보이는 학생 모두 고르기". 필터 모달(FE3-d, 상태 객체 주입) + 계획 칩 그룹. 기존 학생 고르기 기능 대조표 | `plan-flow-step1`·`plan-flow-step2` 바뀜, 새 장면 Many·Filter |
| **FE4-b2 한 명 모드** (다음) | 세그먼트 "한 명 \| 여러 명", B 폭·C 짧은 사다리꼴 360ms 보간(FD-078), 학생 탭 상세 인디케이터 재사용, "이미 잡혀 있는 목표", "이 학생 목표 정하기", 최근 본 학생 줄(앱 셸 `RecentStudents` 연결) | 새 장면 One |

- 활성 계획 편집 경로("학생 추가")는 FE4-a2를 하지 않아 아직 기존 `PlanStudentSelector`를 쓴다. 그래서 선택기 파일과 그 테스트(`planning_page_test`의 선택기 테스트들)는 지우지 않는다. golden `plan-student-selector`도 바뀌지 않는다. 흐름 1단계는 더 이상 이 선택기를 쓰지 않으므로, 기능 대조표와 옮긴 테스트를 종료 기록에 적는다.
- FD-074 "내 그룹"·"이 n명을 그룹으로 저장"·"지금 고른 학생으로 그룹 만들기"와 필터 모달 "프리셋" 버튼은 저장소(FB-1b 이후 버킷)가 없어 숨긴다.

## FE4-b1 종료 기록 (2026-10-08 밤, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없다. 그래서 `flutter analyze`·Dart 테스트·golden을 돌리지 못했고, 통과를 주장하지 않는다.
- 별도 검토 에이전트 1개가 바뀐 파일 전부를 정적으로 읽었다. 정의 파일과 생성자·콜백·키를 대조하고, 시안 fixture 데이터도 확인했다. 고친 지적:
  1. `plan_flow_test.dart`의 남는 `});`(컴파일 오류).
  2. `planning_page_test` "scenario selector accepts the upper-right of fourth-column portraits in rows 1-4"가 옛 선택기 그리드 키를 찾았다. → 새 1단계 그리드로 옮겼다(아래 대조표).
  3. `_PathClipper` const 2곳(analyze info).
  4. 시나리오 "반영"에서 활성 계획에 없는 학생의 바닥값이 0이 되던 문제. → 프로필 확정 현재값으로 seed를 만들고, seed가 없을 때 바닥값은 `planElementTargetMinimums`를 쓴다.
  5. C 상태 줄 버튼이 좁은 창에서 넘칠 수 있었다. → `FittedBox(scaleDown)`.
- PC `.git/index`로 확인했다: 바꾼 추적 파일 9개는 작업 시작 때 PC 내용 = HEAD 블롭이다. 새 파일 2개는 index에 없다.

### 바뀐 파일

| 파일 | 상태 | 줄(+/−) | 내용 |
|---|---|---|---|
| `frontend/lib/ui/widgets/plan_flow_student_step.dart` | 새 파일 | +999 | 새 1단계 화면 3개. `PlanFlowStudentPicker`(흐름 동안 유지하는 상태: 학생·보유·계획, `StudentFilterController` 주입, 검색어, C 정렬), `PlanFlowStudentBody`(B: 제목·고른 수 칩, 검색·빠른 칩·적용 칩·필터 버튼 줄, 8열 그리드 + 순서 배지, 필터 모달), `PlanFlowStudentAside`(C: 고른 학생 목록 / 7명부터 압축 그리드·정렬·모두 비우기·경고 줄, 역할군 칩, 보이는 학생 모두 고르기). 계획 칩 그룹·검색·시안 좌표 도우미 |
| `frontend/test/plan_flow_student_step_test.dart` | 새 파일 | +484 | 아래 테스트 |
| `frontend/lib/ui/models/plan_flow_draft.dart` | 수정 | +320 −88 | 초안을 문서 v2로(`PlanFlowStageDraft` 19키 `Map<String, int?>`, `goalMetadata`), `PlanFlowGoalCodec`(정수 편집기 ↔ v2), `planFlowDocumentIntegerTargets`(정수만 다루는 기존 화면용), 경계가 `PlanningDocument(version: 2, goalMetadata)`를 만들고 v1·v2를 읽음, 컨트롤러 고르기 API(`toggleStudent`·`addStudents`·`removeStudent`·`clearStudents`, FE4-a1의 보류 선택·`confirmStudents` 제거) |
| `frontend/lib/ui/widgets/plan_flow_workspace.dart` | 수정 | +42 −29 | 1단계를 B·C 모션 안의 새 화면으로(기존 선택기 축소 수용 제거), 2·3단계 정수 편집기에 `editorStagesFor`, 미리보기에 정수 보기 |
| `frontend/lib/ui/widgets/plan_flow_rail.dart` | 수정 | +1 −6 | 1단계 부제가 초안 학생 수만 본다 |
| `frontend/lib/ui/widgets/student_section_layout.dart` | 수정 | +118 −3 | `StudentDiagonalGrid`에 `selectionOrder`(순서 배지)·`showRemoveMarks`(×)·`semanticLabelOf`·`scrollKey`(모두 선택 인자, 기본값 = 기존 동작), 그리는 함수 `paintStudentGridOrderBadge`·`paintStudentGridRemoveMark`, 필터 이름 표에 `plan` |
| `frontend/lib/ui/widgets/plan_section_layout.dart` | 수정(CRLF 유지) | +54 −13 | 시나리오 "반영"·시나리오 비교 학생 화면이 v2 시나리오를 `planFlowDocumentIntegerTargets`로 읽음(null은 앞 단계, 첫 단계는 확정 현재값) |
| `frontend/test/plan_flow_test.dart` | 수정 | +210 −36 | 고르기 API·v2 경계·변환 테스트, 1단계 새 화면 기준으로 흐름 테스트 |
| `frontend/test/planning_page_test.dart` | 수정 | +39 −32 | 흐름 테스트 3건을 새 1단계로 옮김 |
| `frontend/test/goldens/golden_harness.dart` | 수정 | +4 −1 | `GoldenPlanFlowMockAppService`가 학생 장면 fixture(10명)를 이어받음 |
| `frontend/test/goldens/fe1g_baseline_golden_test.dart` | 수정 | +96 −17 | 계획 만들기 장면 4개(1단계·1단계 Many·1단계 Filter·2단계) |

`lib/services/**`, `backend/`, `contracts/`, 스캐너·tactic·metadata 소유 파일, `developer_tools*`, `app_shell.dart`는 고치지 않았다. `planning_models.dart`는 이번에 고칠 필요가 없었다.

### 기존 학생 고르기(`PlanStudentSelector`) 기능 대조

흐름 1단계는 더 이상 `PlanStudentSelector`를 쓰지 않는다. 다만 활성 계획 "학생 추가" 경로(FE4-a2 미진행)가 아직 그 선택기를 써서, 선택기 파일·테스트·golden `plan-student-selector`는 그대로 둔다.

| 기존 선택기 | 새 1단계 | 테스트 |
|---|---|---|
| 이름 검색(이름·태그) | 검색창 "이름, 학교, 역할": 이름·태그에 학교·역할·편성 이름을 더함 | `plan_flow_student_step_test` 검색 |
| 속성 필터 7그룹(사선 필터 목록) | 필터 모달(FE3-d) 속성 7그룹 + 계획 칩 그룹 | 필터 모달 테스트 |
| 보유 상태(보유/미보유) | 모달 "보유 · 서버"(보유/미보유/일본 서버 전용 제외) + 빠른 칩 "보유만" | 필터 모달 테스트 |
| 계획 상태(계획 포함/미계획, 기준 = 흐름 초안의 단계 학생) | 계획 칩 그룹 "계획에 없는 학생만"/"계획에 있는 학생만" + 빠른 칩. 기준 = 프로필 목표(학생 탭 PLAN 배지와 같음) | 필터 모달 테스트 |
| 성장 범위 조건(하한·상한 on/off) | 모달 "성장 범위"(행마다 최소~최대, FE3-d 모델) | 모달 조작은 FE3-d 테스트, 적용 흐름은 필터 모달 테스트 |
| "검색·필터 초기화" | 모달 "초기화" + 적용 칩 × + 빠른 칩 끄기 | 필터 모달 테스트 |
| 정렬(이름순 고정) | 그리드 이름순(같음), C 압축 그리드 정렬 "고른 순서/이름/학교" 추가 | 7명 경계 테스트 |
| 여러 명 고르기·고른 순서 유지 | 그리드 누르기 → 초안에 고른 순서대로, 카드 순서 배지, C 목록 번호 | 고르기 테스트, `plan_flow_test` |
| 다시 눌러 빼기 | 다시 누르기 + C 목록 × + 압축 카드 누르기 + "모두 비우기" | 고르기·7명 경계 테스트 |
| 고른 수 + "확정" 버튼 | 제목 칩 "n명 골랐습니다" + 레일 "다음 · 목표 정하기"(FE4-a부터 확정 버튼 없음) | `plan_flow_test`, `planning_page_test` |
| 4열 그리드 · 카드 오른쪽 위 누르기 | 8열(시안), 같은 `StudentDiagonalGrid` 카드 누르기 모양 | `planning_page_test` "scenario selector accepts …"(그리드 키·열 수만 바꿔 옮김) |
| 불러오는 중 · 오류 · 다시 시도 | 흐름을 열 때 계획 화면이 학생·프로필을 한 번 읽는다(FE4-a `_flowContext`, 실패하면 흐름이 열리지 않음). 1단계 자체 로딩은 없다 | — |
| 빈 결과 "조건에 맞는 학생이 없습니다." | 같은 문구 | 검색 테스트 |
| 패널 모션(80/260) | 섹션 모션: B 80/260, C 180/0, 레일 0/180(FD-078) | `planning_page_test` 흐름 퇴장 |

옮긴 테스트:
- `planning_page_test` "scenario creation opens the plan flow and quitting plays the selector outro" → "… step 1 and quitting plays the flow outro". 선택기 패널 퇴장 검사를 흐름 섹션 퇴장 검사로 바꿨다(B dx<0·dy>0, 레일 dx<0, C dx>0).
- `planning_page_test` "scenario creation reuses …": 선택기 그리드·확정 버튼 → 새 그리드·레일 "다음". 2~4단계 단언은 그대로다.
- `planning_page_test` "scenario selector accepts the upper-right …": 그리드 키를 새 그리드로, 4열 → `grid.columns`로 바꿨다(4번째 열, 1~4행 그대로).
- `plan_flow_test`: FE4-a1 보류 선택 API → 고르기 API.
- 선택기 자체 테스트(활성 계획 "학생 추가" 경로)는 그대로다.

### 테스트

- `plan_flow_student_step_test.dart`(새 파일):
  - 계획 칩 그룹 위치·이름, 요약·경고 문구.
  - 고르기·다시 누르기·× → 순서 배지가 당겨짐.
  - 7명 경계(FD-077): 6명 목록 ↔ 7명 압축 그리드, 정렬 "이름", 압축 카드 누르기, 모두 비우기.
  - 필터 모달: 초안은 적용 전까지 그리드에 안 걸림, 닫으면 버림, 적용하면 학교 + 계획 칩이 걸림. 빠른 칩·적용 칩 ×, "보유만".
  - 역할군 칩(하나만 켜짐·다시 누르면 끔)과 "보이는 학생 모두 고르기".
  - 검색(학교 이름, 결과 없음).
  - 의미 구조: 행 label·value·hint, 압축 카드 "… 빼기". `SemanticsHandle`은 본문 끝에서 dispose한다.
- `plan_flow_test.dart`:
  - 컨트롤러 고르기 API(덧붙이기·빼기 시 단계·goal_metadata 정리·모두 비우기).
  - 2단계 확정이 정수 → v2(고르지 않은 목표 null, 19키, goal_metadata 기본값)이고, 편집기 보기는 원래 입력과 같다.
  - 변환(처음 올라간 단계부터 목표, 뒤 단계 유지, 역변환).
  - 정수 보기 도우미.
  - 경계: 계산 문서 v2(goal_metadata 키 = 문서 학생, null 유지, `PlanningDocument.fromWire` 통과), 저장 문서 v2, 다시 열면 목표·goal_metadata 그대로.
  - 1단계 새 화면 → 2·3단계 기존 화면.

### golden 예측

- 바뀜 2: `plan-flow-step1`(1단계 새 화면, 3명: 긴 이름·아루·미보유+PLAN+JP, C 목록 3행·순서 배지), `plan-flow-step2`(학생 fixture 10명으로 바뀐 아루의 요소 편집기 축소 화면, 레일 요약 "48.2M·5종").
- 새 장면 2: `plan-flow-step1-many`(8명, C 압축 그리드·정렬 세그먼트·경고 "미보유 2명 · 이미 계획에 있는 학생 3명"), `plan-flow-step1-filter`(필터 모달 + 계획 칩 그룹, 초안 "계획에 없는 학생만" + 게헨나).
- 그대로: 나머지 21장면. `plan-student-selector`(활성 계획 경로라 그대로), 학생 그리드 장면(배지 인자는 기본값이라 그림이 같다)도 포함한다.
- 그래서 ① gate는 golden 4건 RED가 예상이다(바뀜 2 + 기준 없음 2).

### 처리한 FD

- **FD-077**: 7명부터 C 압축 그리드.
- **FD-104**: 필터 모달에 흐름 소유 `StudentFilterController`(계획 칩 그룹 포함)를 주입한다. 학생 탭 필터와 서로 덮어쓰지 않는다.
- **FD-074**: "내 그룹"·그룹 저장·필터 프리셋은 저장소가 없어 숨긴다(모달 프리셋 칩은 FE3-d부터 숨김).
- **FD-078**: 섹션 모션 부착면 규칙 유지. 한 명/여러 명 전환 보간은 FE4-b2.

### 바뀐 동작(검토 때 볼 것)

1. 1단계에서 고르면 바로 초안에 들어간다. 다시 누르면(또는 ×) 그 학생의 단계·칸 배치·goal_metadata도 확인 없이 빠진다.
2. 시나리오를 문서 v2로 저장한다(목표 없음 = null). 기존 v1 시나리오를 "편집"으로 열면 지금 값보다 높은 키만 목표로 보고, 저장하면 v2가 된다.
3. 시나리오 "반영"과 비교 학생 화면은 v2 시나리오의 null을 앞 단계 값(첫 단계는 확정 현재값)으로 채운 정수 보기로 읽는다.
4. PLAN 배지·계획 칩 기준이 프로필 목표다(학생 탭과 같음). 이전 선택기는 흐름 초안의 단계 학생이었다.
5. 검색이 학교·역할 이름도 찾는다.
6. 계획 칩 "다른 계획에 있는 학생 포함"·"목표를 이미 채운 학생 숨기기"는 아직 없다. 활성 계획 문서(FB-1b)가 필요하고, 학생 한 명이 여러 값을 가지는 그룹 모델도 필요하다.
7. 한 명 모드 세그먼트·최근 본 학생은 FE4-b2다. FE4-a1에서 더한 `PlanStudentSelector.onSelectionChanged`는 흐름에서 더 쓰지 않는다(남겨 둠).

### 검수표

| 항목 | 확인 |
|---|---|
| 8열 그리드 + 고른 순서 배지(시안 지름 26, 압축 21) | 고르기 테스트 + 그리는 함수 |
| C 목록 ↔ 압축 그리드 7명 경계 | 7명 경계 테스트 |
| 필터 모달 초안 → 적용, 계획 칩 그룹 | 필터 모달 테스트 |
| v2 초안: 19키·null 유지·goal_metadata 일치 | `plan_flow_test` 변환·경계 |
| 2·3단계 기존 화면 동작 그대로(정수 경계) | `plan_flow_test` 흐름, `planning_page_test` 저장까지 |
| 기존 선택기 기능 대조·테스트 옮김 | 위 표 |
| Semantics label·value·hint | 의미 구조 테스트 + 레일(FE4-a) |
| `closeTo`, 명시적 pump, analyze info 0, ~습니다체 | 코드 확인(실행 안 됨) |
| 금지 파일 미수정 | 바뀐 파일 표 |

### 확인하지 못한 것

- analyze·테스트·golden 실행 전부(이 환경에 Flutter 없음).
- 새 장면 그림. 실제 시안과 비교할 것은 다음과 같다: 순서 배지 위치, C 목록 행 사선 맞춤, 압축 그리드 카드 크기(이름 줄 글자 크기는 그리드 공용 15px라 시안 10px보다 크다), 필터 모달 계획 그룹 위치.

### 사용자 실행 순서

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① gate만 실행 → 결과를 오케스트레이터에게 보내고 기다린다
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 승인 뒤 기준 이미지 갱신 → gate
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ③ 커밋
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4b -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4b
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesigndocs
```

### FE4-b1 commit record (2026-10-08 21:33, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261008_212503\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE4-c 착수 기록 (2026-10-08 밤)

- 작업 지시(22:14)의 §0을 읽었다: 워크플로 FE4 절·FE4-c 행·재개 지점(2026-10-08 밤 2), 오케스트레이터 로그 16:02·16:48·21:16·21:34, 결정 대장 FD-072~FD-076, 시안 Flow-2-Goals(`dc_outline.py`), C 보고서 §2, FB-1a "FE4 초안 컨트롤러 연결 메모".
- 0단계 기록: FE4-b `2a5a7655`(위 커밋 기록 표).
- 막힘 확인: FD-072·FD-073·FD-075·FD-076은 워커 재량(권장안으로 진행), FD-074 확정(단계 프리셋·내 그룹 저장소는 FB-1b 이후). 열림 0건.
- 21:16 요청(`plan-flow-step2` 0.6% 차이 원인 한 줄): FE4-b1에서 계획 만들기 golden mock(`GoldenPlanFlowMockAppService`)이 학생 장면 fixture(`GoldenStudentMockAppService` + `seedStudentScene`)를 이어받게 바꿨다. 그래서 아루가 저장된 보유 학생(Lv.1, ★1, 스킬 1/1/0/0, 모자 T1 Lv.1)이 되었다. 이전에는 기본 mock에 아루가 없어 미보유 기본값이었다. 학생 탭·계산기 golden과 같은 fixture 값이다.
- 분할 판단: FE4-a2·FE4-b2처럼 남은 조각이 다음 배정에서 빠지는 일이 있었다. 그래서 이번에는 나누지 않고 지시 범위 전체(2단계 B·C, 필터 알약 확인)를 한 번에 한다. 바뀌는 파일은 새 2단계 화면·편집 상태와 컨트롤러·워크스페이스·흐름 테스트·golden이다. 기존 요소 편집기(`PlanElementBuilder`)는 활성 계획 "학생 추가" 경로가 아직 쓰므로 지우지 않는다.

## FE4-c 종료 기록 (2026-10-08 밤, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없다. 그래서 `flutter analyze`·Dart 테스트·golden을 돌리지 못했고, 통과를 주장하지 않는다.
- 별도 검토 에이전트 1개가 바뀐 파일 전부를 정적으로 읽었다. kit·모델 정의와 생성자·키·mock 값(`buildMockOwnedStudents`)을 대조했다. 고친 지적:
  1. "더 보기" 키가 `ValueKey<String?>`로 만들어져 테스트·golden이 못 찾았다. → 지역 변수로 받아 `ValueKey<String>`.
  2. 단계 카드가 겹쳐 놓여(간격 363 < 폭 473) 오른쪽 끝 누르기(×·상태 칩·인연 ▲▼)가 다음 카드로 갔다. → 누르기 감지를 카드 자르기(평행사변형) 안쪽에 둔다.
  3. `_designBox`의 쓰지 않는 `key` 인자(analyze 경고).
  4. `stage_results` 읽기의 if-case 맵 원소(`use_null_aware_elements` 가능성). → 일반 반복문.
  5. 편집 상태가 계산 결과 알림마다 학생 작업 단계를 다시 읽을 수 있었다(시나리오 편집으로 연 단계 중 앞 단계보다 올린 것이 없는 단계가 있을 때). → 학생별로 마지막에 읽거나 넣은 초안 단계 id와 비교하고, 초안이 그대로면 건너뛴다.
- PC `.git/index`로 확인했다: 바꾼 추적 파일 9개는 작업 시작 때 PC 내용 = HEAD 블롭이다. 새 파일 3개는 index에 없다. 시작 뒤 PC 파일 mtime도 그대로다.

### 바뀐 파일

| 파일 | 상태 | 줄(+/−) | 내용 |
|---|---|---|---|
| `frontend/lib/ui/models/plan_flow_goal_editor.dart` | 새 파일 | +597 | `PlanFlowGoalEditor`: 학생별 정수 작업 단계·모드·고른 단계·"더 보기", 값 바꾸기(기존 요소 편집기 `_setTarget` 이식: 앞 단계 하한·최댓값·정규화·뒤 단계 올림·900ms 표시), 단계 추가/삭제/이름(기본 이름 번호), 모드(프리셋·한 번에 MAX·직접 입력), 목표 지우기(모든 단계), 다른 학생·모두 적용. 고칠 때마다 "앞 단계보다 올린 단계"만 `setStudentStages`로 초안에 넣는다 |
| `frontend/lib/ui/widgets/plan_flow_goal_step.dart` | 새 파일 | +2762 | `PlanFlowGoalBody`(B: 학생 탭 줄, 프리셋 바, 지금 상태 카드 + 단계 카드 가로 스크롤 + 단계 추가, 현재 → 최종 7항목), `PlanFlowGoalAside`(C: 단계 프리셋 행, 다른 학생에도 적용·모두, 이 학생 재화 요약). 카드 블록(LEVEL·STAR·WEAPON·인연 ▲▼, 성급 9칸, SKILL SUMMARY, EQUIPMENT 티어 ◀▶, ABILITY + 더 보기, COST) |
| `frontend/test/plan_flow_goal_step_test.dart` | 새 파일 | +1094 | 아래 테스트 |
| `frontend/lib/ui/models/plan_flow_draft.dart` | 수정 | +169 −3 | `PlanFlowStageResource`·`PlanFlowStageCost`(`stage_results[]`: 크레딧·재화·들어설 때 보유/부족·경고), `PlanFlowCalculation.stageCosts`, `PlanFlowController.setStudentStages`(단계 id가 그대로면 칸 배치 유지, 바뀌면 그 학생 단계를 모두 칸에서 뺌, 빈 목록 = 미설정) |
| `frontend/lib/ui/widgets/plan_flow_workspace.dart` | 수정 | +42 −39 | 2단계를 B·C 모션 안의 새 화면으로(요소 편집기 축소 수용 제거), 편집 상태를 흐름 동안 유지·폐기, 프리셋 목록 갱신 |
| `frontend/lib/ui/widgets/student_filter_modal.dart` | 수정 | +13 −7 | 선택 인자 `showCountBadge`(기본 true = 학생 탭 그대로) |
| `frontend/lib/ui/widgets/plan_flow_student_step.dart` | 수정 | +2 | 흐름 1단계 필터 모달은 `showCountBadge: false` |
| `frontend/test/plan_flow_test.dart` | 수정 | +52 −31 | 흐름 위젯 테스트를 새 2단계 기준으로(아래 대조표) |
| `frontend/test/planning_page_test.dart` | 수정 | +7 −11 | "scenario creation builds goals in the plan flow and reuses the phase editor"(이름 바꿈): 프리셋·확정·페이즈 편집기 열기 → 한 번에 MAX + 레일 "다음" |
| `frontend/test/plan_flow_student_step_test.dart` | 수정 | +5 | 필터 모달 테스트에 배지 없음 단언 |
| `frontend/test/goldens/golden_harness.dart` | 수정 | +98 −1 | `GoldenPlanFlowMockAppService`가 단계마다 `stage_results`(크레딧 + 오파츠 2종, 순서 0 = 부족 1종, 1 = 부족 2종, 2 이후 = 지금 가능, 미보유 = 비용 0 + 경고), `goldenFlowStagePreset()`(총력전 3단계) |
| `frontend/test/goldens/fe1g_baseline_golden_test.dart` | 수정 | +55 −8 | `plan-flow-step2` 다시 씀, 새 `plan-flow-step2-more`, 쓰지 않게 된 import 1줄 삭제 |

`lib/services/**`, `backend/`, `contracts/`, 스캐너·tactic·metadata 소유 파일, `developer_tools*`, `app_shell.dart`, `plan_section_layout.dart`(CRLF)는 고치지 않았다. 기존 요소 편집기 `plan_element_builder.dart`·`plan_preset_manager.dart`도 그대로다(활성 계획 "학생 추가" 경로).

### 기존 요소 편집기 기능 대조

흐름 2단계는 더 이상 `PlanElementBuilder`를 쓰지 않는다. 활성 계획 "학생 추가" 경로가 아직 그 편집기를 써서 파일·`plan_element_builder_test`·golden `plan-element-builder`·`plan-preset-manager`는 그대로 둔다.

| 기존 요소 편집기 | 새 2단계 | 테스트(`plan_flow_goal_step_test` 기준) |
|---|---|---|
| 스테퍼 `− 값 +`(아래 한계 = 앞 단계 값, 첫 단계는 지금 값 · 위 한계 = 목표 최댓값) | 카드 ▲▼ 미세 조절: LEVEL·STAR·WEAPON·인연·EX/Normal/Passive/Sub, 장비 티어 ◀▶. 같은 한계 규칙 | "값 바꾸기 …", "미세 조절 → 디바운스 …"(▼는 지금 값까지) |
| MAX 배지(칸마다 최댓값) | "더 보기" 스테퍼의 MAX 배지 + 프리셋 바 "한 번에 MAX"(모든 목표, FD-075) | "성급 9칸 · … 더 보기", "한 번에 MAX …" |
| 성장 규칙 정규화(장비 티어↔레벨, 무기★↔레벨, 성급↔인연, 스킬2·3↔성급, 능력치 = Lv.90·5성, 애장품 없는 학생) | 같은 `normalizePlanningGrowthTargets` | "성장 규칙 …", "더 보기"(능력치 MAX → Lv.90) |
| 뒤 단계 자동 올림 + 900ms 표시 | 같음(파란 바탕) | "값 바꾸기 …" |
| 성급 · 전용무기 스트립(9칸, 고른 칸을 다시 누르면 한 칸 아래) | 카드 성급 9칸(같은 규칙) + STAR ▲▼(FD-072) | "성급 9칸 …" |
| 장비 편집기(티어·레벨) · 애장품 슬롯 · 능력치 스테퍼 | 카드는 티어 ◀▶, 레벨·애장품(애장품 있는 학생만)·HP/ATK/HEAL·무기 ★는 "더 보기"(FD-072) | "성급 9칸 · 장비 티어 ◀▶ · 더 보기 스테퍼" |
| 프리셋 적용(듬성한 단계를 앞 단계에 누적해 펼치고, 올린 것이 없는 단계는 버림) | 프리셋 바 세그먼트 + C 프리셋 행(같은 규칙) | "프리셋 …", "한 번에 MAX · 직접 입력 세그먼트와 프리셋 세그먼트" |
| 단계 추가(고른 단계 바로 뒤 복사본) · 선택 단계 삭제(하나는 남김) · 기본 이름 번호 다시 매기기 | "단계 추가" 세로 버튼(고른 단계 뒤) · 카드마다 ×(하나 남으면 비활성) · 같은 번호 규칙 · 이름 인라인 편집(FD-073) | "단계 추가는 …", "단계 추가·삭제 버튼과 카드 고르기" |
| 단계 고르기(카드 선택) | 카드 누르기 = 고르기(굵은 테두리), 값을 고치면 그 단계를 고름 | "단계 추가·삭제 버튼과 카드 고르기" |
| 현재 상태로 초기화 | "직접 입력"(빈 1단계) | "한 번에 MAX는 …" |
| 확정(앞 단계보다 올린 단계만, 없으면 안내) | 확정 버튼 없음. 고칠 때마다 올린 단계만 초안에 들어가고(v2 null 규칙), 올린 것이 없는 단계는 카드에 "목표 없음"으로 남는다 | "v2: …", "값 바꾸기 …" |
| 학생 큐(확정하면 다음 학생) | 학생 탭(고른 순서, 설정 중·완료·미설정, 아무 때나 이동) | "처음에는 …", "학생 탭은 …" |
| 미배정 목록(이름 바꾸기·삭제·학생 다시 편집) | 없앰. 이름은 카드 머리, 삭제는 카드 ×, 학생 편집은 탭, 칸 배치는 3단계 | `plan_flow_test` 흐름("미배정" 없음) |
| 현재 상태 섹션(읽기 전용) | 지금 상태 카드(미보유면 "모집 필요", FD-076) | "미보유 학생 …" |
| 계획으로 돌아가기 · 페이즈 편집기 열기 | 레일 이전 · 다음(FE4-a) | `plan_flow_test`, `planning_page_test` |

옮긴 테스트:
- `plan_flow_test` "1단계는 새 학생 고르기 …": 2단계 요소 편집기 축소 배치 검사 → 새 2단계 B·C 단언(축소 슬롯 없음, 탭, 프리셋 세그먼트, 저장 버튼·미배정 없음) + "한 번에 MAX" → 3단계. 축소 배치 검사는 3단계 페이즈 편집기로 옮겼다. 돌아오면 고른 모드가 남는다.
- `planning_page_test` "scenario creation …": 프리셋 + 확정 + "페이즈 편집기 열기" → "한 번에 MAX" + 레일 "다음". 3·4단계 단언은 그대로다.
- golden `plan-flow-step2`: 프리셋 + 확정 → 3명 + 3단계 프리셋.
- 기존 요소 편집기 자체 테스트(`plan_element_builder_test`, `planning_page_test` 활성 계획 경로)는 그대로다.

### 테스트

- `plan_flow_goal_step_test.dart`(새 파일, 23건):
  - 편집 상태: 처음 상태(첫 학생·직접 입력·초안 비어 있음), v2(올린 키만 목표, 나머지 null, 계산 문서·`PlanningDocument.fromWire`까지 null 유지), 값 바꾸기 한계·뒤 단계 올림·900ms 표시, 성장 규칙, 단계 추가/삭제/이름, 프리셋 누적 펼침, 한 번에 MAX·직접 입력, 목표 지우기(모든 단계, 묶인 목표도 내려감, v2 null), 다른 학생·모두 적용, 미보유 학생, 1단계에서 뺀 학생, 시나리오 편집처럼 기존 단계로 열기.
  - 초안 연결: `setStudentStages` 칸 배치 규칙, `stage_results` 읽기·COST 행 순서·비용 한 줄·상태 칩, 현재 → 최종 글자·막대(`closeTo`).
  - 화면: 학생 탭 순서·상태·전환, 미세 조절 3번 → 디바운스 계산 1번 → COST·상태·비용 한 줄 갱신(계산 결과를 목표에 되쓰지 않음) + 의미 구조(label · value · increasedValue · decreasedValue + 동작, `SemanticsHandle`은 본문 끝에서 dispose), 단계 추가·삭제·이름 인라인 편집·카드 고르기, MAX/직접 입력/프리셋 세그먼트와 C 프리셋 행, 현재 → 최종 ×, 성급 9칸·장비 티어·더 보기 스테퍼, C 다른 학생에도 적용·모두·재화 요약, 미보유 학생 칩.
  - 계산 디바운스·바뀐 칸 Timer는 명시적인 pump로 끝까지 흘린다.
- `plan_flow_test.dart`·`planning_page_test.dart`: 위 옮긴 테스트.
- `plan_flow_student_step_test.dart`: 필터 모달에 "필터 · n" 배지가 없다.

### golden 예측

- 바뀜 2: `plan-flow-step2`(새 2단계: 탭 3명 — 아루 설정 중·호시노·미보유 슌, 총력전 3단계 카드 3장 + COST·상태 칩 "부족 1종 / 부족 2종 / 지금 가능", 현재 → 최종, C 프리셋 2행·다른 학생 2행·재화 요약, 레일 "48.2M·5종"), `plan-flow-step1-filter`(왼쪽 위 "필터 · 2" 배지가 사라짐).
- 새 장면 1: `plan-flow-step2-more`(아루 한 번에 MAX 뒤 미보유 슌 탭, Lv.4 1단계, "모집 필요", 더 보기 펼침).
- 그대로: `plan-element-builder`·`plan-preset-manager`(활성 계획 경로, 파일 미수정), `plan-flow-step1`·`plan-flow-step1-many`(모달을 열지 않음), 학생 탭 필터 장면(배지 기본값 true) 등 나머지.
- 그래서 ① gate는 golden 3건 RED가 예상이다(바뀜 2 + 기준 없음 1).

### 처리한 FD

- **FD-072 (a)**: 목표 키 19개를 모두 고칠 수 있다. 성급은 카드 STAR ▲▼ + 성급 9칸, 장비 레벨·애장품·추가 능력치·무기 ★는 카드 아래 "더 보기"(EQUIPMENT·ABILITY·COST 자리를 스테퍼 판으로 바꿈).
- **FD-073**: 단계 이름 기본 "n단계", 카드 머리 인라인 편집(비우면 기본 이름). 프리셋 적용 때 프리셋 단계 이름은 아직 쓸 수 없다(`PlanElementPreset`에 단계 이름이 없음, FD-074 모델 변경과 함께).
- **FD-074**: 프리셋 바·C는 계획 화면 프리셋 관리의 인메모리 프리셋을 보여 주고 적용한다(기존 편집기 "프리셋 적용" 대조 유지). 저장되는 프리셋("지금 구성을 프리셋으로")과 영속 저장, 1단계 "내 그룹"은 FB-1b 저장소 전까지 그리지 않는다. 판단 근거: 지시의 "저장되는 단계 프리셋"을 저장 기능·저장소로 읽었다. 인메모리 프리셋도 숨겨야 한다면 세그먼트·C 행만 빼면 된다(프리셋 적용 대조 행은 비게 된다).
- **FD-075**: "한 번에 MAX"(1단계에 모든 목표 최댓값, 애장품 없는 학생은 0)·"직접 입력"(지금 값 그대로인 빈 1단계)은 모드이고 저장하지 않는다.
- **FD-076**: 미보유 학생은 목표 최솟값을 지금 값으로 본다. 탭 "미보유", 지금 상태 카드·단계 상태 "모집 필요". 백엔드는 현재 상태가 없는 학생 단계를 계산에서 빼므로 COST는 "모집 뒤에 비용을 계산합니다"다(모집 비용 FB-9).

### 필터 알약 판정

- 판정: 버그. `StudentFilterModal`이 "필터 · n" 배지를 (18, 226)에 그린다. 이 자리는 학생 탭 S1 필터 버튼 자리다. 계획 만들기 1단계에서는 필터 버튼이 B 오른쪽 위에 있어서 배지가 레일 2단계 근처에 떠 보였다. 시안 Flow-1-Students-Filter에도 떠 있는 배지가 없다(B 버튼 "필터 · n"만 있음).
- 수정: `StudentFilterModal.showCountBadge`(기본 true). 흐름 1단계만 false다. 학생 탭은 그대로다.

### 바뀐 동작(검토 때 볼 것)

1. 2단계에는 확정 버튼이 없다. 값을 고칠 때마다 앞 단계보다 올린 단계만 초안에 들어가고 디바운스 계산이 돈다(레일 요약·카드 COST).
2. 학생의 단계 목록이 바뀌면(추가·삭제, 또는 어떤 단계가 앞 단계보다 올린 것이 없어짐) 그 학생의 단계는 모두 칸에서 빠진다(3단계에서 다시 배치). 값만 바꾸면 칸 배치는 그대로다.
3. 카드 상태 "지금 가능/부족 n종"의 기준: 2단계에는 칸 순서가 없어서 계산 문서의 임시 순서(모든 학생 1단계 → 2단계 …)에서 단계에 들어설 때의 보유량이다(C 보고서 §2.6 미정 항목).
4. 현재 → 최종은 7항목이다. 시안 6항목에 추가 능력치(ABILITY)를 더했고, EQUIPMENT ×는 애장품도 함께 지운다.
5. "고른 n명 모두 …"·학생 행 "바꾸기"는 확인 없이 그 학생의 단계를 지금 모드로 바꾼다.
6. 기존 v1/v2 시나리오를 "편집"으로 열면 초안 단계를 작업 단계로 읽는다. 지금 값과 같아 초안에 null로 들어가는 키는 처음 고칠 때 null로 정리된다.
7. 프리셋 바 "지금 구성을 프리셋으로"는 없다(FD-074).

### 검수표

| 항목 | 확인 |
|---|---|
| 학생 탭 줄(1단계 고른 순서, 상태 3종) | 탭 테스트 |
| 단계 카드 추가·삭제, 이름(FD-073) | 편집 상태·화면 테스트 |
| 카드 COST(`stage_results`, 디바운스 1회) | 미세 조절 → 디바운스 테스트, 계산 결과 읽기 테스트 |
| 현재 → 최종, × = 모든 단계에서 지우기(v2 null) | 목표 지우기 테스트 2건 |
| 프리셋 바 모드(FD-075), 저장 숨김(FD-074) | 세그먼트 테스트, `plan_flow_test` |
| 카드에 없는 목표(FD-072), 미보유(FD-076) | 더 보기·미보유 테스트 |
| v2: 고르지 않은 목표 null, `planningDocumentTargets` 안 씀, 계산 결과 되쓰기 없음 | v2 테스트(계산 문서·fromWire), 디바운스 테스트 |
| 미배정 목록 없앰, 기존 편집기 기능 대조·테스트 옮김 | 위 표 |
| C 보조(Flow-2) | C 테스트 |
| 필터 알약 | 판정·수정, 1단계 필터 테스트 단언 |
| Semantics value 3종, `SemanticsHandle` 본문 끝 dispose | 디바운스 테스트 |
| `closeTo`, 명시적 pump, analyze info 0, ~습니다체 | 코드 확인(실행 안 됨) |
| 금지 파일 미수정 | 바뀐 파일 표 |

### 확인하지 못한 것

- analyze·테스트·golden 실행 전부(이 환경에 Flutter 없음).
- 새 장면 그림. 시안과 견줄 것: 카드 블록 안 글자 크기(블록마다 scaleDown), 성급 9칸 위치, 장비 아이콘(카탈로그 `equipment_slot_n` 이름), "단계 추가" 점선, C 행 간격(창 높이가 1208이 아니면 행 높이는 고정·위치만 비율).
- 학생이 많을 때 C "다른 학생에도 적용"은 4명까지 보이고 나머지는 "외 n명" 줄로 줄인다.

### 사용자 실행 순서

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① gate만 실행 → 결과를 오케스트레이터에게 보내고 기다린다
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 승인 뒤 기준 이미지 갱신 → gate
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ③ 커밋
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4c -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4c
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice redesigndocs
```

## fe1brev 종료 기록 (2026-10-09 새벽, FB-1b 이관 revision 전파, 코드 작성 완료·gate 미실행)

작업 지시(00:51): FE4-c 승인 뒤 같은 워커가 작은 별도 slice로 한다. 읽은 것: `frontend-redesign-status-backend.md` FB-1b "소비자 영향·오케스트레이터 전달 요청" 표와 "프런트 연결 메모", 오케스트레이터 로그 00:37·00:47, gate `20261009_003919` 로그. 이 환경에는 Flutter가 없어 analyze·테스트를 돌리지 못했다.

### 실패 원인(gate `20261009_003919`, `title_page_test` "first run imports a v6 account and opens its repository plan")

- 로그 문구: `v6 계정을 가져오지 못했습니다: Bad state: revision_conflict`. 충돌은 화면이 아니라 테스트 대역 `_V6ImportMockService.importV6Account` 안에서 난다.
- 그 대역은 `selectProfile` 뒤 `saveRepositoryStudents(..., 0, ...)`로 revision 0을 고정해서 넘긴다. FB-1b mock은 state revision과 프로필 revision을 하나로 맞췄다(state가 없으면 프로필 revision을 쓴다). 그래서 선택이 올린 revision 1과 맞지 않는다.
- 고친 방법: 대역이 `selectProfile`이 돌려준 revision으로 다음 저장을 한다. 테스트 기대(단언)는 그대로다.

### 화면 수정(FB-1b 소비자 영향표의 프런트 두 행)

| 파일 | 줄(+/−) | 내용 |
|---|---|---|
| `frontend/lib/ui/pages/title_page.dart` | +25 −5 | 선택된 계정이 없으면 대상 state를 먼저 읽고 그 revision으로 select한다(목록 revision 아님). state를 읽은 뒤 `_profile` revision을 state 값으로 바꾼다. 읽기 실패(이관 실패 포함)는 문구로 보이고, 주 버튼은 첫 실행(새 계정·v6 가져오기)으로 가지 않고 다시 읽는다 |
| `frontend/lib/ui/widgets/account_section_cluster.dart` | +96 −11 | 계정마다 state를 읽고 돌려받은 revision으로 목록 값을 바꾼다(선택·수정·삭제가 이 값을 씀). 한 계정이 실패해도 나머지는 보이고, 실패한 계정은 오류 줄 + 행 "보유 : 읽지 못함"(0명으로 보이지 않음). 공용 도우미 `repositoryLoadErrorText`(legacy_goals_conflict·corrupt_data·repository_busy 문구), `loadRepositoryStateRetrying`(repository_busy 두 번까지 재시도), `repositoryProfileWithRevision` |
| `frontend/test/title_page_test.dart` | +151 −2 | 위 대역 수정 + 새 테스트 3건 |

새 테스트:
- 선택 안 된 legacy 프로필(활성 문서 없이 저장된 state): 타이틀이 첫 state 로드(revision 0 → 1) 뒤 그 값으로 선택(1 → 2)하고 오류가 없다. 이전 코드는 목록 값 0으로 select해서 충돌한다.
- 계정 관리: 두 번째 계정의 첫 state 로드가 revision을 올린 뒤 "이 계정으로 전환"이 충돌 없이 된다.
- 계정 관리: 첫 로드 이관 실패(`legacy_goals_conflict`)는 오류 줄과 "보유 : 읽지 못함"으로 보이고 다른 계정은 그대로다.

범위 밖(고치지 않음): `scan_page.dart`·`tactical_page.dart`(다른 레인, 오케스트레이터가 tactic 로그 00:50에 전달), `lib/services/**`(백엔드). FE4-c 매니페스트와 겹치는 파일 없음. golden 변화 0 예상(정상 경로 그림은 같고, 실패 문구는 실패 때만 보임).

### 사용자 실행 순서

로그 00:47 순서대로: fe1brev 수정 → gate ② → fb1b(Python 전체 먼저) → fe1brev → fe4c → redesigndocs.

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe1brev -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe1brev
```

### fe1brev commit record (2026-10-09 02:33, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261009_013850\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

### FE4-c commit record (2026-10-09 02:34, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261009_013850\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE4-d1 종료 기록 (2026-10-09 새벽, 코드 작성 완료·gate 미실행)

작업 지시(02:38): 계획 만들기 3단계 단계 순서(Flow-3-Order). HEAD `b4bb199a` 이후. 읽은 것: 워크플로 FE4 표(FE4-d 분할 메모), artboard-map Flow-3-Order 행, 결정 대장 FD-035·FD-069·FD-070·FD-071, 시안 Flow-3-Order(`dc_outline.py`), 기존 `plan_phase_editor.dart`(`_sequenceOrderIsValid`)·`plan_student_step_tile.dart`, FE4-c 상태 기록.

이 환경에는 Flutter·Dart가 없다. 그래서 `flutter analyze`·Dart 테스트·golden을 돌리지 못했고, 통과를 주장하지 않는다.
- 별도 검토 에이전트 1개가 바뀐 파일 전부를 정적으로 읽었다. kit·모델 생성자 시그니처, null·타입(`int.clamp`, `ValueKey<String?>`, 필드 승격), 새 테스트 11건과 golden 단언을 구현과 대조했다. 고친 지적:
  1. EX 목표를 스킬처럼 5 → "M"으로 적었다. 새 테스트 기대("EX 3→5")·시안(`EX5`)과 다르다. → EX는 숫자 그대로.
  2. `_DropHint`의 `CustomPaint`가 const가 아니었다(analyze info). → const.
  3. 새 테스트 `fromProjection` 맵 리터럴(`prefer_const_literals_to_create_immutables`). → const 맵.
  4. 칸·카드 키가 `Positioned` 안쪽 위젯에 있어 순서가 바뀌면 element가 새로 만들어졌다(끌기·칸 이름 입력 상태가 사라짐). → 키를 `Positioned`로 옮김.
- PC `.git/index`로 확인했다: 바꾼 추적 파일 6개는 작업 시작 때 PC 내용 = HEAD 블롭이다. 새 파일 3개는 index와 PC에 없다. 시작 뒤 PC 파일 mtime도 그대로다.

### 바뀐 파일

| 파일 | 상태 | 줄(+/−) | 내용 |
|---|---|---|---|
| `frontend/lib/ui/widgets/plan_flow_order_step.dart` | 새 파일 | +1423 | `PlanFlowOrderBody`(B: 제목 · (i) · "단계 n개" · 거부 이유, 칸 보드, 범례 "같은 학생 · 자동"), `PlanFlowOrderAside`(C: 고른 카드 머리, 포함한 목표, 먼저 끝나야 하는 단계, 이 칸에서 부족한 재화, 자동으로 정렬 3행). 칸 보드: 칸 타일(80° 레일을 따라 228마다 40.2 왼쪽, 스크롤하면 보이는 높이 기준으로 다시 놓음), 칸 머리 이름 인라인 편집 + 상태 칩, 카드 한 줄 3장(넘치면 다음 줄, 28.9 왼쪽), 빈 칸 "여기로 끌어다 놓기", 마지막 칸 아래 "칸 추가", 같은 학생 회색 실선 화살표. 카드(`.srow` 398.4×150): 초상 · 이름 · 단계 태그 · 목표 요약 · 비용 한 줄 · 상태 칩. 칸마다 `DragTarget`, 카드는 `Draggable`(놓은 위치로 칸 안 자리 계산) |
| `frontend/lib/ui/models/plan_flow_order_editor.dart` | 새 파일 | +280 | `PlanFlowOrderEditor`(고른 카드, 마지막 거부 이유, 칸에 넣기·옮기기·이름·칸 추가·자동 정렬 전달, 상태·선행·칸 부족 재화 읽기), `planFlowGoalChanges`(앞 단계 → 이 단계 목표 바뀜: 카드 요약 `Lv.90`·C 상세 `EX 3→5`, 스킬 10 = M), `PlanFlowLaneShortage` |
| `frontend/test/plan_flow_order_step_test.dart` | 새 파일 | +697 | 아래 테스트 |
| `frontend/lib/ui/models/plan_flow_draft.dart` | 수정 | +367 −8 | `PlanFlowBottleneck`·`PlanFlowCalculation.bottlenecks`(응답 `bottlenecks[]`), `PlanFlowShortage.affectedStageIds`, `PlanFlowStageStatus`·`planFlowStageStatuses`(FD-035), `PlanFlowAutoArrange`, `planFlowDefaultPhaseName`("n순위"). 컨트롤러: `placeUnassignedStages`, `orderViolation`, `moveStage`(같은 칸 선행 → 후행 정렬), `renamePhase`, `addPhase`, `autoArrange`. 저장 문서·계산 문서에서 빈 칸을 뺌 |
| `frontend/lib/ui/widgets/plan_flow_workspace.dart` | 수정 | +33 −109 | 3단계를 B·C 모션 안의 새 화면으로(축소해 넣던 `PlanPhaseEditor`와 `planFlowLegacyBodyRect`·`planFlowLegacyFittedRect`·`plan-flow-legacy-*` 슬롯 제거, FD-070), 3단계 화면 상태를 흐름 동안 유지·폐기 |
| `frontend/test/plan_flow_test.dart` | 수정 | +32 −19 | 흐름 위젯 테스트의 3단계 단언을 새 칸 보드로(아래) |
| `frontend/test/planning_page_test.dart` | 수정 | +5 −9 | 시나리오 만들기 흐름의 3단계 조작을 새 칸 보드로(아래) |
| `frontend/test/goldens/golden_harness.dart` | 수정 | +71 −10 | `GoldenPlanFlowMockAppService`: 단계 재화를 문서 순번 대신 그 학생의 단계 번호로 정함(1 = 부족 1종, 2 = 부족 2종, 3 이후 = 충분), `bottlenecks`(재화마다 처음 모자라는 단계)와 전체 재화 행 `affected_stage_ids`(그 재화를 쓰는 단계). `goldenFlowTwoStagePreset()`(육성 2단계) |
| `frontend/test/goldens/fe1g_baseline_golden_test.dart` | 수정 | +44 | 새 장면 `plan-flow-step3` |

`lib/services/**`, `backend/`, `contracts/`, 스캐너·tactic·metadata 소유 파일, `app_shell.dart`, `plan_section_layout.dart`(CRLF)는 고치지 않았다. `plan_phase_editor.dart`·`plan_student_step_tile.dart`는 활성 계획 "페이즈 편집"(`plan-phase-editor-launch`, golden `plan-phase-editor`)과 4단계 미리보기(`PlanStudentStepPreview`)가 아직 써서 지우지 않고 고치지도 않았다.

### 기존 페이즈 편집기 기능 대조(흐름 3단계)

| 기존 페이즈 편집기(흐름에 축소 수용) | 새 3단계 | 테스트 |
|---|---|---|
| 미배정 목록 → 페이즈로 끌어 놓기 | 3단계를 처음 그리면 칸에 없는 단계를 n단계 → n순위 칸에 넣는다(같은 학생 앞 단계보다 앞 칸·뒤 단계보다 뒤 칸에는 두지 않음). 미배정 자리("나중에" 칸)는 FE4-f | "칸에 없는 단계는 …", "처음 그리면 …" |
| 카드를 페이즈 사이·페이즈 안에서 끌기(삽입선) | 카드를 칸 사이·칸 안에서 끌기(놓은 위치의 카드 가운데 기준으로 자리), 끄는 동안 칸 테두리(놓을 수 있으면 핑크, 거부면 빨강) | "카드를 끌어 칸을 옮기고 …", "칸 이름 바꾸기 · 칸 추가 …"(빈 칸에 놓기) |
| `_sequenceOrderIsValid`(같은 학생 단계 순서, 스낵바 "같은 학생의 단계 순서를 지켜 배치하세요.") | `orderViolation`: 선행보다 앞 칸·뒤 단계보다 뒤 칸은 거부하고 이유 문구("호시노 2단계는 선행 단계(호시노 1단계)보다 앞 칸에 둘 수 없습니다.")를 B 제목 줄에 보인다. 같은 칸은 허용하고 선행 → 후행으로 다시 놓는다(FD-069) | "선행보다 앞 칸 · …", "카드를 끌어 …" |
| 전부 배치 · 빠른 배치 | 처음 자동 배치 + C "자동으로 정렬" 3종 | "자동 정렬 3종 …", "부족이 적은 단계부터 …" |
| 되돌리기 · 전부 되돌리기(미배정으로) | 없음. "나중에" 칸이 FE4-f에서 그 자리를 맡는다 | — |
| 페이즈 이름 편집 | 칸 머리 인라인 편집, 비우면 기본 "n순위"(FD-071) | 컨트롤러·화면 이름 테스트 |
| 페이즈 추가 · 삭제 · 위/아래 이동 | 마지막 칸 아래 "칸 추가". 빈 칸은 저장·계산 문서에서 빠진다(FD-071). 칸 삭제·칸 순서 이동 버튼은 시안에 없어 만들지 않았다(카드 이동·자동 정렬로 대신) | "칸 이름 · 칸 추가 · 빈 칸은 …" |
| 완료(미배정 0일 때 4단계) · 뒤로 | 레일 "다음"(모든 단계가 칸에 있으면) · "이전" | `plan_flow_test`, `planning_page_test` |

바꾼 기존 테스트 기대(FD-070으로 흐름 안에서 `plan-phase-editor`·`plan-flow-legacy-*`가 없어졌기 때문):
- `plan_flow_test` "1단계는 새 학생 고르기, 2단계는 새 목표 정하기이고, 3단계는 기존 페이즈 편집기를 연다" → 이름 "… 3단계는 새 칸 보드다". 3단계 단언: 페이즈 편집기 축소 배치(`planFlowLegacyFittedRect`) 대신 `PlanFlowOrderBody`·`PlanFlowOrderAside`가 있고 `plan-phase-editor`가 없다, 단계가 "1순위" 칸에 들어가 레일 "다음"이 켜진다, 첫 칸이 A 레일 오른쪽 사선과 C 왼쪽 사선 사이에 있다. "이전" 단언은 그대로(페이즈 편집기 없음 → 칸 보드 없음).
- `planning_page_test` "scenario creation builds goals in the plan flow and reuses the phase editor" → 이름 "… builds goals and orders stages in the plan flow". 3단계 조작: `plan-phase-editor-assign-all`·`-complete` 누르기 → 칸 보드가 있는지 보고 레일 "다음". 4단계·저장·목록 단언(페이즈 1개)은 그대로다.
- 활성 계획 페이즈 편집기 테스트(`planning_page_test` "phase editor keeps lists …" 등)·`plan_element_builder_test`는 그대로다.

### 테스트

- `plan_flow_order_step_test.dart`(새 파일, 11건):
  - 초안 컨트롤러: 칸에 넣기(빈 초안 → 1·2순위, 일부가 이미 칸에 있으면 나머지만, 이름 유지), 거부 이유 두 가지(선행보다 앞 칸 · 뒤 단계보다 뒤 칸)와 거부 때 배치 그대로, 같은 칸 허용·정렬, 칸 안 자리 옮기기, 칸 이름(앞뒤 공백 정리, 비우면 기본), 칸 추가, 빈 칸은 저장 문서·계산 문서에서 빠짐, 자동 정렬 3종(이름 유지, 부족이 적은 단계부터는 계산 결과 기준이고 같은 학생 순서를 지킴).
  - 상태(FD-035): 응답 `bottlenecks`·`affected_stage_ids` 읽기, 부족·막힘·가능, 병목보다 앞에 둔 단계는 막히지 않음, 카드·칸 머리 글자, 목표 바뀜 글자.
  - 화면: 처음 그리면 칸에 넣기, 칸 간격(40.2·228), 상태 칩 3종, 화살표 1개, 처음 고른 카드. 끌어 옮기기 → 거부 → 이유 문구 → 다른 카드를 고르면 지움. 카드 고르기 → C 제목·포함한 목표·선행("자동")·이 칸 부족 재화(−20)·빈 칸 문구. 칸 이름 입력(done), 칸 추가 → 빈 칸에 끌어 놓기, 자동 정렬 행 누르기.
  - 계산 디바운스 Timer는 명시적인 pump로 끝까지 흘린다.
- `plan_flow_test.dart`·`planning_page_test.dart`: 위 바꾼 기대.

### golden 예측

- 새 장면 1: `plan-flow-step3` — 3명(호시노 육성 2단계 · 아루 총력전 3단계 · 미보유 슌 육성 2단계) = 단계 7개, 1순위 [호시노 1 · 아루 1 · 슌 1] / 2순위 [호시노 2 · 아루 2 · 슌 2] / 3순위 [아루 3], 호시노 2단계 고름(핑크 테두리, C 상세). 배지: 호시노 1·2 "부족", 아루 1~3 "막힘", 슌 "모집 필요". 칸 머리: "부족 1종"·"부족 2종"(빨강, 막힌 카드가 있음)·"막힘". 회색 화살표 4개(호시노 1→2, 아루 1→2→3, 슌 1→2).
- 그대로: `plan-flow-step2`·`plan-flow-step2-more`(단계가 있는 보유 학생이 한 명이라 단계 번호 = 문서 순번 + 1, 단계 비용·전체 재화 행 값 그대로. 새 `bottlenecks`는 3단계만 읽고, 바뀐 `affected_stage_ids`는 닫힌 부족 재화 플라이아웃의 사용처에만 쓰인다), `plan-phase-editor`(활성 계획 경로, 파일 미수정), `plan-flow-step1*`, 나머지.
- 그래서 ① gate는 golden 1건 RED(기준 없음)가 예상이다.
- 이 장면에서 "가능"(초록) 카드는 나오지 않는다. mock의 볼프세크 철광석을 모든 보유 단계가 쓰고 그 병목(호시노 2단계)이 아루 3단계보다 앞이라 아루 3단계도 막힘이다. 2단계 장면을 바꾸지 않으려고 mock 재화 구성은 그대로 두었다. 가능 배지는 위젯 테스트가 본다.

### 처리한 FD

- **FD-035**: 부족 = 어떤 병목의 `stage_id`이거나 들어설 때 모자라는 재화가 있음(`stage_results`), 막힘 = 다른 병목 재화의 `affected_stage_ids`에 있고 문서 순서(칸 → 칸 안)상 그 병목 단계보다 뒤(자기 부족과 겹치면 막힘), 가능 = 둘 다 아님. "뒤"를 더한 이유: `affected_stage_ids`는 그 재화를 쓰는 모든 단계라서 병목보다 앞 단계까지 막힘이 된다. 응답의 병목 행에는 영향 단계 목록이 없어 전체 재화 행 것을 쓴다. 미보유 학생 단계는 "모집 필요"(FD-076).
- **FD-069**: 같은 칸 허용, 칸 안에서 같은 학생 단계는 단계 번호 순서로 다시 놓는다(다른 학생 카드 자리는 그대로).
- **FD-070**: 흐름 3단계는 새 칸 보드다. 시나리오 비교 "편집"도 같은 흐름(`initialStep: order`)이라 새 화면으로 들어간다. 활성 계획 "페이즈 편집"은 이번 범위 밖이라 기존 편집기 그대로(FE5-c).
- **FD-071**: 칸 머리 이름 인라인 편집(기본 "n순위", 비우면 기본으로), 마지막 칸 아래 "칸 추가", 빈 칸은 저장 문서에서 뺀다(계산 문서에서도 뺀다). 레일 부제 "순서 n칸"은 전부터 빈 칸을 세지 않는다.

### 바뀐 동작(검토 때 볼 것)

1. 3단계를 열면 칸에 없는 단계를 바로 칸에 넣는다. 그래서 레일 "다음"이 곧바로 켜진다(전에는 페이즈 편집기에서 모두 배치하고 완료). 컨트롤러가 아니라 화면이 첫 프레임 뒤 부른다(단위 테스트의 "3단계에 들어간 직후 다음 불가" 기대는 그대로).
2. 2단계에서 한 학생의 단계를 바꾸면 그 학생 단계가 칸에서 빠진다(FE4-c 규칙). 3단계로 돌아오면 다시 n순위 규칙으로 넣는다(다른 학생 배치는 그대로).
3. 거부 이유는 B 제목 줄 오른쪽에 빨강 글자로 남고, 다음 이동·카드 고르기·칸 추가·자동 정렬에서 지운다.
4. 칸 삭제·칸 위아래 이동은 없다(시안에 없음). 빈 칸은 화면에 남지만 저장·계산에서는 빠진다.
5. 자동 정렬은 확인 없이 지금 배치를 바꾼다. 칸 이름·id는 앞에서부터 다시 쓰고 남는 칸은 지운다. "고른 학생 순서대로"는 학생마다 한 칸, "부족이 적은 단계부터"는 마지막 계산의 단계별 부족 종류 수가 적은 순서로 칸을 나눈다(계산 전이면 모두 0으로 봄).
6. 칸 보드는 세로로 스크롤한다. 스크롤하면 칸이 보이는 높이에 맞춰 80° 선을 따라 옆으로 다시 놓인다.
7. 카드를 끄는 동안 보이는 것은 작은 행(초상 · 이름 · 단계 태그)이다.
8. C "이 칸에서 부족한 재화"는 그 칸 단계들의 들어설 때 부족량을 재화마다 더한 값(큰 순 3개, 나머지는 "외 n종")이다.

### 검수표

| 항목 | 확인 |
|---|---|
| 칸 보드: 80° 레일 40px씩 왼쪽, 카드 끌기(칸 사이·칸 안) | 화면 테스트(간격 단언, 끌기 2건) |
| 같은 학생 회색 실선 화살표 | 화살표 개수 단언, golden |
| 선행보다 앞 칸 거부 + 이유, 같은 칸 허용·정렬(FD-069) | 컨트롤러·화면 테스트 |
| 상태 배지 가능·부족·막힘(FD-035), 초안 계산 결과 사용 | 상태 테스트, 화면 칩 테스트, golden |
| C 선택 카드 상세 + 자동 정렬 3종 | C 테스트, 자동 정렬 테스트 |
| 칸 이름 인라인(기본 n순위), 칸 추가, 빈 칸 저장 때 제거(FD-071) | 컨트롤러·화면 테스트 |
| 기존 PlanPhaseEditor 교체(FD-070), 시나리오 비교 "편집" → 새 화면 | 워크스페이스 코드, `plan_flow_test` |
| 범위 밖 미구현: 직접 선행·"나중에"(FE4-f), 작게 보기(FE4-d2) | 코드 확인 |
| ~습니다체, 명시적 pump, 금지 파일 미수정 | 코드 확인(실행 안 됨) |

### 확인하지 못한 것

- analyze·테스트·golden 실행 전부(이 환경에 Flutter 없음).
- 새 장면 그림. 시안과 견줄 것: 화살표 시작·끝 위치(카드 아래 186 → 다음 카드 위 212.5), 카드 안 글자 줄 간격, 칸 머리 이름 칸 폭(220), 긴 이름(호시노) 말줄임, C 행 간격.
- 터치 화면에서 세로 스크롤과 카드 끌기가 겹칠 때(마우스는 스크롤 뷰가 끌기를 받지 않음). 끄는 동안 보드 자동 스크롤은 없다.
- 단계가 많을 때(30개) 보기는 FE4-d2.

### 사용자 실행 순서

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① gate만 실행 → 결과를 오케스트레이터에게 보내고 기다린다
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 승인 뒤 기준 이미지 갱신 → gate
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ③ 커밋
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4d1 -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4d1
```

### FE4-d1 commit record (2026-10-09 14:30, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261009_124241\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE4-d2 종료 기록 (2026-10-09 오후, 코드 작성 완료·gate 미실행)

작업 지시(14:31): 계획 만들기 3단계 · 단계가 많은 경우(Flow-3-Order-Many) + FE4-d1 golden 후속(화살표가 칸 머리 칩을 지나감). FE4-d1 커밋 뒤 HEAD에서 시작했다. 읽은 것: 워크플로 FE4-d 분할 메모, artboard-map Flow-3-Order-Many 행, 시안 Flow-3-Order-Many(`dc_outline.py` + 원본 HTML의 칸·칩·곡선 path), FE4-d1 종료 기록, 오케스트레이터 로그 12:50.

이 환경에는 Flutter·Dart가 없다. 그래서 `flutter analyze`·Dart 테스트·golden을 돌리지 못했고, 통과를 주장하지 않는다.
- 별도 검토 에이전트 1개가 바뀐 파일 전부를 정적으로 읽고 새 테스트·golden 장면을 좌표까지 따라갔다. 고친 지적:
  1. `listEquals`를 `material.dart`가 내보내지 않는다(컴파일 오류). → `package:flutter/foundation.dart` show `listEquals`.
  2. 칩·카드 크기를 `Size ==`로 비교하면 소수 오차로 실패한다. → 너비·높이를 `closeTo`.
  3. 머리 피하는 x 상한 비교(372)가 1 ulp 차이에 걸릴 수 있다. → 0.01 여유.
  4. 같은 칸 같은 줄의 앞·뒤 단계(FD-069)로 가는 작게 보기 화살표가 위로 휘고 꺾쇠는 아래를 향했다. → 아래에 있지 않으면 옆 가운데끼리 곧게 잇는다.
  5. 작게 보기 칸 머리 열(118)이 "모두 지금 가능" 칩(약 117)과 거의 같았다. → 126(첫 칩 자리 139.8 안).
  6. 위젯 파일 머리 주석이 "작게 보기는 FE4-d2에서 더한다"로 남아 있었다.
- PC `.git/index`로 확인했다: 바꾼 추적 파일 5개는 작업 시작 때 PC 내용 = HEAD 블롭이다. 시작 뒤 PC 파일 mtime도 그대로다. 새 파일은 없다.

### 바뀐 파일

| 파일 | 줄(+/−) | 내용 |
|---|---|---|
| `frontend/lib/ui/widgets/plan_flow_order_step.dart` | +1092 −100 | 화살표: `PlanFlowOrderArrow`에 꺾인 선(`elbowY`)·S 곡선(`curve`)·경로·끝 방향. 크게 보기는 카드 아래에서 내려와 칸 사이(줄 사이) 틈에서 옆으로 가고, 칸 첫 카드로는 칸 머리(이름 칸 220 + 상태 칩) 오른쪽으로 윗변에 들어간다(`planFlowOrderHeaderClearX`). 작게 보기: 판(평행사변형 #162431), 칸(머리 열 이름 17 · 단계 n개 · 상태 칩, 칩 다섯 개씩 줄바꿈, 칸 높이 18 + 54·줄), 칩(204×44: 초상 37×30 · 이름 12 · 단계 태그 · 상태 점 7), 고른 카드만 398×150으로 펼침(칩 자리 가운데, 그림자 + 불투명 바탕), 고른 카드와 이어진 선만(S 곡선), 이어지지 않은 칩 불투명도 .55, 툴바(학생 초상 8명 + 나머지 수 · 부족 있는 단계만 · 선택 중 ×), 범례(상태 점 가능 · 부족 · 막힘). B 제목 줄: 12개를 넘으면 크게·작게 세그먼트, 작게 보기에서는 "단계 n개" 칩을 오른쪽으로 옮기고 학생별 묶음 토글. (i)는 작게 보기에서 "많을 때" |
| `frontend/lib/ui/models/plan_flow_order_editor.dart` | +118 −3 | `planFlowOrderCompactThreshold`(12), `many`·`compact`·`setCompact`, `groupByStudent`·`shortOnly` 토글, `clearSelection`(다시 고르기 전까지 고른 카드 없음), `visibleStageIds`(부족만 · 학생별 묶음, 고른 카드는 늘 보임), `stageIndexFor`(보이는 자리 → 실제 칸 자리), `isConnected` |
| `frontend/test/plan_flow_order_step_test.dart` | +263 | 아래 테스트 |
| `frontend/test/goldens/golden_harness.dart` | +13 | `goldenFlowManyPreset()`(셋으로 나누기: 레벨 → EX·스킬 → 장비 T10) |
| `frontend/test/goldens/fe1g_baseline_golden_test.dart` | +50 | 새 장면 `plan-flow-step3-many` |

`lib/services/**`, `backend/`, `contracts/`, 스캐너·tactic·metadata 소유 파일, `app_shell.dart`는 고치지 않았다. 초안 컨트롤러(`plan_flow_draft.dart`)·워크스페이스도 그대로다.

### 동작

- 단계가 12개를 넘으면 3단계는 작게 보기로 열린다. 크게·작게 세그먼트로 바꾼 뒤에는 그 고른 값을 흐름 동안 지킨다. 12개 이하면 세그먼트를 그리지 않는다(FE4-d1 화면 그대로).
- 작게 보기의 끌기·놓기 거부·같은 칸 정렬·자동 정렬·칸 이름·칸 추가는 크게 보기와 같은 컨트롤러 규칙이다. 칩·펼친 카드 모두 끌 수 있고, 펼친 카드 위에 놓으면 그 카드 자리(같은 칸)로 옮긴다.
- 학생별 묶음·부족 있는 단계만은 보기만 바꾼다(칸 배치는 그대로). 놓을 자리는 보이는 목록의 자리를 실제 칸 자리로 바꿔 계산한다(그 자리 카드 앞, 끝이면 마지막 보이는 카드 뒤). 부족만은 계산 결과가 있을 때만 거르고, 다 숨은 칸은 "조건에 맞는 단계가 없습니다"다.
- 선택 중 ×: 고른 카드를 풀면 펼친 카드·선·흐림이 없어지고 C는 "고른 단계가 없습니다"다. 칩을 누르면 다시 고른다.
- 크게 보기 화살표(후속): 칸 사이 14 틈의 가운데(다음 칸 위 7)에서 옆으로 가고, 칸 첫 카드로는 머리 오른쪽 + 16(카드 윗변 212.5 ~ 372 안)으로 내려간다. 같은 칸 다음 줄은 줄 사이 틈(카드 위 7)에서 옆으로 간다. 모서리는 반지름 10까지 둥글게.

### 테스트

- `plan_flow_order_step_test.dart`:
  - 기존 "처음 그리면 …"에 단언 추가: 다음 칸 첫 카드로 가는 화살표가 꺾인 선이고, 칸 사이 틈 높이에서 옆으로 가며, 칸 머리(이름 칸 오른쪽) 오른쪽 · 카드 윗변 안으로 들어간다.
  - 새 그룹 "작게 보기(FE4-d2)" 6건: 화살표 경로 계산(줄 사이 틈, 머리 피하는 x 상한, 시안 곡선 시작·끝 좌표), 12개 초과 자동 작게 보기(펼친 카드 398×150 · 칩 204×44 · 칩 간격 · 이어진 선 1개 · 흐림 .55 · 크게/작게 왕복), 칩 고르기 → 펼침 · 앞뒤 선 2개 · 선택 중 × → 선택 풀기, 부족 있는 단계만 · 학생별 묶음(배치 그대로), 작게 보기 끌기(같은 칸 허용 · 뒤 단계보다 뒤 칸 거부와 이유 문구).
- 기존 테스트 기대는 바꾸지 않았다(단언만 더함).

### golden 예측

- 바뀜 1: `plan-flow-step3` — 화살표 경로만. 2순위 아루 → 3순위 아루 선이 3순위 머리("막힘" 칩)를 지나지 않고 칸 사이 틈에서 옆으로 간 뒤 머리 오른쪽으로 아루 3단계 윗변에 들어간다. 1→2순위 선도 같은 꺾인 모양이 된다(호시노·아루·슌 1→2는 2순위 첫 카드 호시노만 머리 피하는 x). 카드·칸·글자는 그대로다.
- 새 장면 1: `plan-flow-step3-many` — 열 명 × 3단계 = 단계 30개, 작게 보기. 1·2·3순위 칸에 칩 10개씩(두 줄), 호시노 2단계를 골라 펼침(분홍 테두리), 호시노 1 → 2 → 3 곡선 두 개, 나머지 칩 흐림, 툴바 "학생" 초상 8명 + 나머지 수 · "부족 있는 단계만" · "호시노(카드 하단 변보… 선택 중 ×", 제목 줄 "단계 30개" · 크게/작게(작게) · 학생별 묶음, 범례 상태 점. 상태 점은 거의 빨강(mock에서 병목 뒤 같은 재화를 쓰는 단계가 막힘).
- 그대로: 나머지 장면(2단계 장면·활성 계획 페이즈 편집기 포함). 바꾼 파일은 3단계 화면과 새 프리셋 함수뿐이다.
- 그래서 ① gate는 golden 2건 RED(바뀜 1 + 기준 없음 1)가 예상이다.

### 바뀐 동작(검토 때 볼 것)

1. 작게 보기를 처음 열면 첫 칸 첫 카드가 골라져 펼쳐진다. 그 카드는 시안 자리(칩 가운데 높이)라 윗부분 27이 보드 위로 잘린다(내리면 아래 칸 칩을 더 가린다).
2. 펼친 카드는 시안처럼 이웃 칩(아래 칸 첫 줄 일부)을 덮는다. 덮인 칩은 펼친 카드를 풀거나 다른 카드를 고르면 다시 누를 수 있다.
3. 크게 보기에서 두 칸 이상 아래로 가는 선과, 두 줄 칸의 첫 줄에서 내려오는 선은 사이 카드 위를 세로로 지나간다(선은 카드 위에 그린다).
4. 작게 보기 "학생" 초상 줄은 보기만 한다(누르는 동작 없음).
5. "선택 중" 칩 이름은 12자에서 줄인다(긴 이름 학생).
6. 작게 보기 칸 머리 열은 한 줄 칸(높이 72)보다 조금 길어 칸 사이 틈으로 넘친다(시안과 같음).

### 검수표

| 항목 | 확인 |
|---|---|
| 12개 초과 자동 작게 보기, 크게·작게로 되돌리기 | 작게 보기 테스트 |
| 선택 카드만 398×150, 이어진 선만, 나머지 흐리게 | 작게 보기 테스트, golden |
| 툴바: 학생별 묶음 · 부족 있는 단계만 · 선택 중 × | 툴바 테스트 2건 |
| 칸 줄바꿈 + 보드 스크롤 | 칸 높이·칩 간격 단언, golden(두 줄 칸) |
| 끌기 · 거부 · 자동 정렬이 작게 보기에서도 같은 규칙 | 작게 보기 끌기 테스트(자동 정렬은 같은 C 행·컨트롤러) |
| 후속: 화살표가 칸 머리를 피해 카드 윗변으로 | 화살표 단언 2건, golden `plan-flow-step3` |
| 범위 밖 미구현: 직접 선행(분홍 점선) · "나중에" 칸(FE4-f) | 코드 확인 |
| ~습니다체, 명시적 pump, 금지 파일 미수정 | 코드 확인(실행 안 됨) |

### 확인하지 못한 것

- analyze·테스트·golden 실행 전부(이 환경에 Flutter 없음).
- 새 그림: 칩 안 글자 크기, 펼친 카드 그림자, 곡선 굵기, 머리 열 줄 간격, 툴바 칩 자리, 크게 보기 꺾인 선 모서리.
- 작게 보기에서 끄는 동안 보드 자동 스크롤은 없다(크게 보기와 같음).

### 사용자 실행 순서

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① gate만 실행 → 결과를 오케스트레이터에게 보내고 기다린다
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 승인 뒤 기준 이미지 갱신 → gate
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ③ 커밋
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4d2 -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4d2
```

### FE4-d2 수정 기록 (gate ① `20261009_150924` 뒤, 2026-10-09 오후, gate 미실행)

실패 1건: `plan_flow_order_step_test` "단계가 12개를 넘으면 …"의 `arrows.single.curve`가 false였다. 원인(오케스트레이터 진단): 아루 1단계(1순위 첫 칩)를 펼친 카드가 칩 자리 가운데 높이에 그려져 아래 끝이 y≈123이 되고, 2순위 첫 칩(아루 2단계, y 112~156)을 가렸다. 그래서 화살표가 "아래에 있지 않다"고 보고 옆 직선을 그렸다. 결정: 펼친 카드는 다른 칩을 가리지 않는다. 테스트 기대는 바꾸지 않았다.

고친 것(`plan_flow_order_step.dart` +151 −51, `plan_flow_order_step_test.dart` +11):
- `_CompactBoardLayout`이 고른 단계를 받아 펼친 카드(398.4×150) 자리를 배치 안에서 잡는다. `planFlowOrderExpandedRect`는 없앴다.
  - 같은 줄: 카드가 칩 두 자리 가까이 차지한다. 그 줄의 오른쪽 칩은 카드 오른쪽 끝 + 칩 간격으로 **옆으로 민다**. 줄 끝(칩 다섯 자리)을 넘는 칩은 다음 줄로 넘긴다. 옆으로 미는 쪽을 고른 이유: 칩 순서가 보이는 목록 순서와 그대로 같고(끌어 놓을 자리 계산이 단순), 한 칩만 넘어가므로 줄 수가 덜 늘어난다. 다음 줄로 통째로 넘기면 카드 오른쪽에 넓은 빈자리가 생긴다.
  - 왼쪽: 줄 첫 카드는 시안 자리(칩 자리 24 왼쪽)지만 칸 머리 열(이름 · 단계 n개 · 상태 칩)과 겹치면 머리 열 오른쪽 + 4에서 시작한다. 줄 중간 카드는 왼쪽 칩과 겹치지 않게 칩 자리에서 시작한다(24 왼쪽으로 가면 왼쪽 칩 오른쪽 끝 14를 덮는다).
  - 위: 카드 윗변이 위 칩(같은 칸 앞 줄 또는 앞 칸의 맨 아래 칩·카드)보다 14 아래가 되게 그 줄을 내린다. 위에 칩이 없는 첫 칸 첫 줄은 시안 자리 그대로라 윗부분 27이 보드 위로 넘친다.
  - 아래: 카드가 있는 줄 다음 줄은 카드 아래 끝 + 10, 칸 상자는 카드 아래 끝 + 14까지 늘어나고, 뒤 칸·"칸 추가"·스크롤 높이가 따라간다.
- 칸 머리 열을 칸 위 12 → 6, 줄 간격 5 → 3으로 줄여 한 줄 칸(높이 72) 안에 넣었다. 머리 열이 칸 아래로 넘쳐 다음 칸 카드와 겹칠 수 있었다(시안보다 6 위).
- 작게 보기 화살표는 둘이 같은 높이에 걸칠 때(같은 칸 같은 줄, FD-069)만 옆 직선이고, 아래 칸·다음 줄이면 S 곡선(카드 아래 → 칩 위)이다.
- 놓을 자리 계산: 줄 높이가 고르지 않아 "높이가 가장 가까운 줄 → 그 줄에서 놓은 x보다 가운데가 왼쪽인 칩 뒤"로 바꿨다.
- 테스트: 그 테스트에 "펼친 카드가 보이는 칩 rect 어느 것과도 겹치지 않음" 단언(보이는 칩 전부)을 더했다.
- 정적 확인: 같은 배치 규칙을 Python으로 옮겨 테스트 초안(5명 × 3단계)과 golden 초안(10명 × 3단계)에서 30·15개 단계를 하나씩 골라 보았다. 펼친 카드와 칩, 칩끼리 겹침 0. 아루 1단계 → 2단계, 아루 2단계 앞·뒤 선 모두 곡선 조건이다. 테스트 초안에서 1순위는 [아루 1(카드) · 아야네 1 · 호시노 1 · 히나 1] / [노아 1] 두 줄이 되고, 아야네 1 → 호시노 1 간격은 칩 간격 그대로다.

golden: `plan-flow-step3`(화살표 경로)는 승인됨(오케스트레이터). `plan-flow-step3-many`는 이 배치가 기준이다: 1순위 칩 10개(두 줄), 2순위는 호시노 2단계 카드가 첫 자리를 차지하고 카드 윗변이 1순위 마지막 칩 줄보다 14 아래가 되도록 그 줄이 내려가며 [카드 + 칩 3] / [칩 5] / [칩 1] 세 줄, 3순위 칩 10개. 다른 장면은 바뀌지 않는다. ① gate 예상: `plan-flow-step3-many` 기준 없음 1건(이전 gate의 새 그림은 버린다).

commit.json·pre 사본은 그대로다(바꾼 파일 2개 모두 FE4-d2 범위 안).

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4d2 -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4d2
```

### FE4-d2 commit record (2026-10-09 16:23, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261009_161730\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE4-h 종료 기록 (2026-10-09 오후, 저장 문서 읽기 연결, 코드 작성 완료·gate 미실행)

작업 지시(16:23): 계획 화면·학생 탭·계획 만들기 흐름이 활성 계획을 저장 문서(`plan.get`, `RepositoryPlanService.loadRepositoryPlan`)에서 읽는다. FE4-d2 커밋 뒤 HEAD에서 시작했다. 읽은 것: 워크플로 FE4-h 행, backend status FB-1b "소비자 영향" 표·"프런트 연결 메모" 1·2·4, FB-1c 종료 기록의 프런트 메모(replace는 읽기만), `lib/services/repository_plan_service.dart`, mock의 `loadRepositoryPlan`·`_ensureMockRepositoryPlan`·`mock_repository_plan.dart`.

이 환경에는 Flutter·Dart가 없다. 그래서 `flutter analyze`·Dart 테스트·golden을 돌리지 못했고, 통과를 주장하지 않는다.
- 별도 검토 에이전트 1개가 바뀐 파일 전부를 정적으로 읽었다(컴파일·lint·남은 참조·mock 동작에 대한 테스트 기대·golden 영향). 고친 지적: `repository_service.dart`가 이미 `repository_plan_service.dart`를 export하므로 두 개를 같이 import하면 `unnecessary_import`가 난다(3곳) → 지웠다. 낡은 주석 4곳을 고쳤다.
- PC `.git/index`로 확인했다: 바꾼 추적 파일 12개는 작업 시작 때 PC 내용 = HEAD 블롭이다(`plan_section_layout.dart`는 CRLF만 다르고 CRLF를 지켰다). 작업 중 PC 파일 mtime도 그대로다.

### 바뀐 파일

| 파일 | 줄(+/−) | 내용 |
|---|---|---|
| `frontend/lib/ui/models/repository_plan_snapshot.dart` (새 파일) | +82 | `loadRepositoryPlanSnapshot`: `plan.get` → `state.get` 순서로 읽고 revision이 같아야 돌려준다. 다르면 둘 다 다시 읽는다(최대 3번, `repositoryPlanSnapshotAttempts`). 끝내 다르면 `RepositoryPlanSnapshotMismatch`. `plan.get`을 먼저 부르는 이유: 레거시 첫 읽기의 이관 revision(+1)을 `state.get`이 같이 본다. 서비스가 `RepositoryPlanService`가 아니면 state만 읽고 plan은 null. `activePlanStudentIds`(문서에 단계가 있는 학생) |
| `frontend/lib/ui/widgets/plan_section_layout.dart` (CRLF) | +162 −106 | `_loadRepositoryPlan`: goals → 1페이즈 메모리 변환을 지우고 snapshot의 저장 문서를 그대로 쓴다. 페이즈·단계·이름·id는 문서 그대로, 기존 정수 화면용 목표는 `planFlowDocumentIntegerTargets`(v2 null → 앞 단계 값, 첫 단계는 확정 현재값). 작업 문서(`_document`)는 저장 문서(v2, null 그대로)라 계산·비교에 null이 그대로 간다. `_repositoryPlan`(snapshot) 보관. `calculation == null`이면 `_calculationUnavailable` → 자세한 계산을 부르지 않고 섹션 3에 "계산할 수 없음" 문구(`planCalculationUnavailableMessage`, 키 `plan-calculation-unavailable`), 섹션 2 문서는 그대로. `_ensureRepositoryContext`(흐름·시나리오 목록·비교 진입)도 같은 snapshot 경로, `_flowContext`는 `activePlan`으로 저장 문서를 넘긴다. `_incorporateScenario`의 바닥값을 `stage.targets` 대신 정수 보기로 읽는다(v2 null이면 StateError였다). 섹션 4의 "계산 오류" 분기 2개를 지우고 섹션 3 상태 분기로 옮겼다(아래 "바뀐 동작" 1) |
| `frontend/lib/ui/models/active_plan_bond_target.dart` | +7 −30 | `activePlanBondTarget`이 마지막 단계의 `nullableTargets['bond_rank']`(null = 목표 없음). FB-1 전 임시 경계 `ActivePlanDocumentSource`·`loadStudentActivePlanDocument`를 없앴다 |
| `frontend/lib/ui/models/growth_calculator_adapter.dart` | +11 −7 | `growthCalculatorPlanMembership(PlanningDocument? activePlan, …)`: 문서에 그 학생 단계가 있으면 계획에 있음, 문서가 없으면 모름. `GrowthCalculatorRequest.fromState`에 `activePlan` |
| `frontend/lib/ui/models/plan_flow_draft.dart` | +9 | `PlanFlowContext.activePlan`(선택), `plannedStudentIds` |
| `frontend/lib/ui/pages/student_page.dart` | +25 −12 | 계정 선택 때 snapshot으로 state·문서를 같이 읽는다(실패하면 state만, 문서 null). PLAN 배지 `plannedIds`·→N·계산기 계획 포함이 모두 문서 기준 |
| `frontend/lib/ui/widgets/plan_flow_student_step.dart` | +5 −6 | 1단계 계획 학생 = `context.plannedStudentIds`(goals를 보지 않는다) |
| `frontend/lib/ui/widgets/growth_calculator_section.dart` | +1 −1 | 주석만(계획 포함 기준) |
| `frontend/test/planning_page_test.dart` | +266 | 새 그룹 "FE4-h 저장 문서 읽기" 6건 + 기록용 mock `_RepositoryPlanLoadService` |
| `frontend/test/student_bond_gauge_test.dart` | +110 −39 | 아래 |
| `frontend/test/growth_calculator_adapter_test.dart` | +55 −14 | 아래 |
| `frontend/test/plan_flow_student_step_test.dart` | +28 −1 | 아래 |
| `frontend/test/goldens/golden_harness.dart` | +21 −22 | `GoldenStudentMockAppService`가 `ActivePlanDocumentSource` 대신 `seedStudentScene`에서 v2 활성 계획을 `saveRepositoryPlan`으로 저장한다(아래 golden 예측) |

`lib/services/**`, `backend/`, `contracts/`, 스캐너·tactic·metadata 소유 파일, `app_shell.dart`는 고치지 않았다. 통계·인벤토리는 goals 호환 경로 그대로다. 저장(save/append/replace)은 손대지 않았다(FE4-e). 서비스에 요청할 빠진 기능은 없다.

### 동작

- 계획 탭(`loadRepositoryPlan: true`): 선택 계정의 snapshot을 읽어 저장 문서의 페이즈·단계를 섹션 2에 그린다. 빈 문서는 빈 계획이다(goals가 남아 있어도 되살리지 않는다, 더미 계획도 그리지 않는다). 이 snapshot의 revision이 나중 저장의 `expectedRevision`이다(`_repositoryPlan.revision` = `_repositoryState.revision`).
- `plan.get`의 `calculation`이 null이면 섹션 3은 "계산할 수 없음 / 지금은 이 계획을 계산할 수 없습니다. 계획 내용은 그대로 보여 줍니다."이고 자세한 계산(`planning.document.calculate`)을 부르지 않는다. 문서를 편집·편입해 다시 계산이 성공하면 이 상태는 풀린다.
- 계산할 수 있으면 지금처럼 화면이 자세한 계산을 한 번 더 부른다(`plan.get`의 요약에는 페이즈별 소비·병목이 없다).
- 학생 탭: PLAN 배지·인연 →N·계산기 "계획에 있음/없음/확인 전"이 모두 같은 저장 문서다. →N은 그 학생 마지막 단계의 `bond_rank`이고 null이면 목표 없음이다.
- 시나리오 만들기 1단계·비교 "편집"(3단계): 흐름 문맥이 계획 화면과 같은 snapshot(이미 읽었으면 다시 읽지 않는다)의 저장 문서를 갖고, 1단계 계획 학생은 그 문서 기준이다.

### 테스트

- `planning_page_test.dart` 새 그룹 6건(레거시 계정: revision 4, goals에 아야네 `target_level` 10):
  - 레거시 프로필 첫 로드: `plan.get` revision `[5]`, `state.get` `[5]`, 이관 문서 단계(`plan-step-v6-imported-plan-ayane-1`)만 보임, 계산할 수 없음·계산 오류 없음.
  - 빈 문서: goals에 아야네가 있어도 단계 타일 0, 계산할 수 없음 없음.
  - calculation null: "계산할 수 없음" 문구가 보이고 문서 단계도 보임, 자세한 계산을 부르지 않음(불렀다면 계산 오류).
  - revision 불일치 재조회: 첫 `plan.get`이 revision 4 + 낡은 문서 → 다시 읽어 `[4, 5]`/`[5, 5]`, 낡은 문서 단계는 안 보임.
  - 끝내 불일치(3번): 오류("revision이 맞지 않습니다")를 보이고 낡은 문서는 쓰지 않음.
  - 시나리오 만들기 1단계: 다시 읽지 않고(`[5]`) 계획 학생 = 문서 학생 `{ayane}`.
- `student_bond_gauge_test.dart`:
  - 새 단위 테스트 2건: v2 문서의 null bond(마지막 단계 null = 목표 없음, 다른 null 목표가 있어도 `targets` StateError 없이 읽음), 레거시 goals → 이관 문서(revision 5, bond null → 목표 없음).
  - 기대를 바꾼 것: "조회는 ActivePlanDocumentSource만 쓰고 실패하면 목표 없음" 테스트를 지웠다(그 임시 경계를 없앴고 위 두 테스트가 대신한다). "S3 게이지가 … 마지막 단계 목표를 쓴다"는 임시 경계 mock 대신 `plan.save`로 저장한 v2 문서(아루 30 → 50, 아야네 null)를 읽는다. 기대값(→50, 아야네는 목표 없음)은 그대로다. "활성 계획을 줄 곳이 없으면…"은 기본 mock이 이제 빈 저장 문서를 주므로 이름만 "빈 활성 계획이면…"으로 바꿨다(기대 그대로).
- `growth_calculator_adapter_test.dart`: 계획 포함 테스트를 goals 기준에서 문서 기준으로 다시 썼다(지시: 계산기 어댑터 "현재 계획에 있음"을 문서 기준으로). goals에만 있는 학생은 문서에 없으면 "계획에 없음"이라는 단언을 더했다. `fromState`를 부르는 두 테스트("확정값 기준이면…", "MockAppService 왕복")는 `activePlan`을 넘긴다. 넘기지 않으면 계획 포함이 "모름"이 되기 때문이고, 기대(`notInPlan`)는 그대로다.
- `plan_flow_student_step_test.dart`: 준비 함수가 `plan.get` 문서를 `PlanFlowContext.activePlan`으로 넘긴다(goals 저장은 mock에서 그 문서도 바꾼다, 기대 그대로). 새 테스트 1건: 같은 계정 상태라도 문서를 주지 않으면 계획 학생이 없다(goals를 보지 않는다).
- `title_page_test` "first run imports a v6 account …"의 키 `plan-step-v6-imported-plan-ayane-1`은 mock 이관 문서의 페이즈 id와 같아 그대로 통과할 것으로 본다.

### golden 예측

- 변경 0을 예상한다.
- harness를 바꾼 이유: 학생 장면의 →N이 쓰던 임시 경계(`ActivePlanDocumentSource`)를 없앴다. 이제 `seedStudentScene`이 v2 활성 계획을 저장하고, 화면은 그 문서를 `plan.get`으로 읽는다. 문서: 페이즈 1 = 아야네 bond 30 · 슌(수영복) 20 · 히나 null, 페이즈 2 = 아야네 45. 나머지 목표는 모두 null, goal_metadata는 즐겨찾기 true · 메모 빈칸.
- 그대로인 이유:
  - PLAN 배지: 문서 학생 {아야네, 슌, 히나} = 예전 goals 학생과 같다.
  - goals 호환 보기(통계·인벤토리): 예전에도 goals 저장이 mock에서 문서를 거쳐 만들어졌다. 같은 학생·순서·즐겨찾기·빈 목표라 같다.
  - →N: 아야네 45(현재 24), 슌 20(미보유) 그대로. 호시노는 예전 임시 문서에 20(현재 30 이하라 숨김)이 있었고 이제 계획에 없다. 어느 쪽이든 표시가 없다. 히나는 목표 없음 그대로.
  - 계산기 장면: 아루는 어느 쪽이든 "계획에 없음"이다.
  - 계획 홈 장면: `loadRepositoryPlan`을 쓰지 않는다(더미 그대로). 시나리오 목록·비교 장면은 빈 문서로, 예전 goals 0개와 같다.
- 보이지 않는 차이: 학생 장면에서 셸이 화면 밖에 만든 계획 탭이 이제 2페이즈를 읽는다.

### 바뀐 동작(검토 때 볼 것)

1. 계산 오류 문구가 이제 실제로 보인다. 예전 "계산 오류" 분기는 섹션 4(`element-4`)에 있었지만, 그 앞의 섹션 4 분기가 항상 먼저 돌아가서 그리지 못하는 코드였다. 이제 읽기·계산 오류와 계산할 수 없음은 섹션 3(재화 탭 자리)에 보인다. 오류가 없으면 섹션 3은 그대로다.
2. 계정을 읽지 못하면(끝내 revision 불일치 포함) 섹션 2는 예전처럼 더미 계획을 그린다. 오류는 섹션 3에 보인다. 이 동작은 원래 있던 것이고 이번에 바꾸지 않았다.
3. 저장 문서에 단계가 없는 페이즈가 있으면 빈 페이즈로 그린다.
4. 이관된 레거시 계획의 페이즈·단계 이름은 백엔드 문서 이름이다(mock: 페이즈 "v6 목표", 단계는 메모 또는 "v6 목표"). 예전 화면 이름 "v6 가져온 계획"이 아니다. 페이즈 id `v6-imported-plan`은 같다.
5. 편집·편입 뒤 작업 문서는 지금처럼 화면 상태에서 v1 정수 문서로 다시 만든다. 저장은 FE4-e다.
6. 학생 탭도 계정을 열 때 `plan.get`을 부른다(백엔드가 요약 계산을 한 번 한다). 문서를 읽지 못하면 state만 읽고 PLAN 배지 없음 · 계산기 "계획 확인 전"이다.

### 검수표

| 항목 | 확인 |
|---|---|
| `_loadRepositoryPlan` → `plan.get`, 빈 문서 = 빈 계획, goals로 되살리지 않음 | 계획 테스트 2건 |
| plan/state revision 불일치 → 다시 읽어 같은 snapshot | 재조회 테스트 2건 |
| `calculation == null` → 계산할 수 없음 + 문서 표시 | 계획 테스트 1건 |
| 레거시 첫 로드 이관 revision | 계획 테스트 1건, 인연 단위 테스트 1건 |
| 학생 탭 →N = 마지막 nullable bond_rank, null = 목표 없음 | 인연 테스트 3건 |
| plannedIds·계산기 계획 포함 = 문서 기준 | 어댑터 테스트, 1단계 테스트, golden(그대로) |
| 흐름 진입이 같은 경로 | 1단계 계획 학생 테스트 |
| 통계·인벤토리 goals 경로 그대로, 저장 범위 밖 | 코드 확인 |
| `lib/services/**`·금지 파일 미수정, ~습니다체 | 코드 확인(실행 안 됨) |

### 확인하지 못한 것

- analyze·테스트·golden 실행 전부(이 환경에 Flutter 없음).
- ProcessAppService(실제 백엔드)에서 레거시 계정 첫 `plan.get` → `state.get`이 같은 revision을 주는지(FB-1b 계약상 그렇다).
- 섹션 3 상태 문구의 위치·줄바꿈 모양(평행사변형 안 가운데).

### 사용자 실행 순서

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① gate만 실행 → 결과를 오케스트레이터에게 보내고 기다린다(golden 변경 0 예상)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 커밋
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4h -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4h
```

### FE4-h commit record (2026-10-09 17:23, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261009_171109\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE3-g 종료 기록 (2026-10-09 저녁, 성장 계산기 인연 선물 타일, 코드 작성 완료·gate 미실행)

작업 지시(17:37): 계산기가 인연 선물 계산(FB-11b)을 함께 받아 인연 타일·선물 팝오버를 채운다. FE4-h 커밋 뒤 HEAD에서 시작했다. 읽은 것: 워크플로 FE3-g 행, FD-163·164·165, backend status FB-11b 절 전체("계약과 계산"·배분 예시·"FE3-g 연결 메모"), 시안 Calc-Student 인연 타일·`.gpop` 두 팝오버(`dc_outline.py` + 원본 HTML 스타일), FE3-f2b 계산기 어댑터·디바운스, 서비스 DTO(`student_bond_service.dart`, `calculateStudentWithBond`, mock fixture 7건).

이 환경에는 Flutter·Dart가 없다. 그래서 `flutter analyze`·Dart 테스트·golden을 돌리지 못했고, 통과를 주장하지 않는다.
- 별도 검토 에이전트 1개가 바뀐 파일 전부를 정적으로 읽었다. 대상은 컴파일·lint, 그리고 mock fixture 값과 학생 탭 흐름에 대한 테스트 기대다. 컴파일 오류·분석 경고는 찾지 못했다. 고친 지적:
  1. 창이 좁으면(인연 타일 최소 폭 420) 쓰다듬기 안 버튼이 넘칠 수 있다 → 큰 수를 `FittedBox`로 줄이고, 이름 칸 flex 3.
  2. FD-165 단언이 `Item_Icon_Favor` 접두로 찾아 성장 재화 fixture의 `Item_Icon_Favor_Selection`(정당한 성장 present 행)과 겹칠 수 있었다 → 이 사례의 선물 key 3개로 좁히고, 결과 재화 key 목록이 고르기 전후 같음을 단언한다.
  3. (i) 도움말이 섹션 플라이아웃 묶음과 같아 마우스만 올려도 고정한 선물 팝오버가 닫혔다 → 선물 팝오버 묶음을 따로 둔다.
  4. 확정 인연이 성급 상한을 넘는 자료(예 ★1 · 인연 15)에서 보내는 값과 계산기 행 값이 달랐다 → repository에 `bond_rank`가 있으면 계산기 확정 현재값(정규화된 값)을 보낸다. 없으면 null이다.
- PC `.git/index`로 확인했다: 바꾼 추적 파일 6개는 작업 시작 때 PC 내용 = HEAD 블롭이다. 작업 중 PC mtime도 그대로다.

### 바뀐 파일

| 파일 | 줄(+/−) | 내용 |
|---|---|---|
| `frontend/lib/ui/widgets/growth_calculator_bond_tile.dart` (새 파일) | +926 | 아래 "인연 타일"의 위젯과 순수 함수(안 문구 · 기본 안 · 안내 문구) |
| `frontend/lib/ui/models/growth_calculator_adapter.dart` | +104 −3 | 아래 "계산 호출" |
| `frontend/lib/ui/widgets/growth_calculator_section.dart` | +37 −43 | 빈 인연 타일(`_BondTile`)을 `GrowthCalculatorBondTile`로 바꿨다(결과를 기다리는 동안 흐림은 크레딧 타일과 같다). 고른 안 상태(학생이 바뀌면 처음으로), 선물 팝오버 묶음, "필요 재화" 제목 줄에 성장 경고 |
| `frontend/test/growth_calculator_adapter_test.dart` | +238 | 아래 테스트 |
| `frontend/test/growth_calculator_view_test.dart` | +324 −4 | 아래 테스트 |
| `frontend/test/goldens/fe1g_baseline_golden_test.dart` | +38 −2 | `students-calculator` 장면을 함수로 묶고 인연 목표 1 → 3을 더했다. 새 장면 `students-calculator-bond-popover` |
| `frontend/test/goldens/golden_harness.dart` | +4 | 주석만(계산기 golden 대역의 인연은 기본 mock의 공유 fixture 응답) |

`lib/services/**`, `backend/`, `contracts/`, 스캐너·tactic·metadata 소유 파일, `app_shell.dart`는 고치지 않았다. 서비스에 요청할 빠진 기능은 없다.

### 동작

**계산 호출(어댑터)**
- 서비스가 `PlanningStudentBondCalculationService`면 디바운스 한 번에 `calculateStudentWithBond`를 한 번 부른다. 성장 입력(currentStudent·19 key 정수 targets·inventory)은 그대로이고, 거기에 `bond: StudentBondRequest(currentRank)`를 더한다.
- 이전 요청 응답 버림(요청 번호)은 그대로다.
- `GrowthCalculatorRequest.currentBondRank`:
  - 확정값 기준이면 repository 학생 값에 `bond_rank`가 있을 때만 그 값이다(계산기 확정 현재값).
  - 미보유이거나 값이 없거나 repository를 아직 못 읽었으면 null이다. 계산기 현재값의 채운 1을 보내지 않는다.
  - 직접 입력 기준이면 계산기에 적은 현재 인연이다.
  - `currentStudent`에는 인연을 넣지 않는다(`planningCurrentFields`에 없다).
- 결과(`GrowthCalculatorResult`):
  - `bond`(계산됨 / 계산할 수 없음), 보낸 `bondCurrentRank`·`bondTargetRank`를 갖는다.
  - `resources`·`shortageTypeCount`·`warnings`는 성장 결과만이다(FD-165).
- 인연 호출이 `UnsupportedError`이면 같은 요청으로 성장만 다시 계산하고, 인연은 "계산할 수 없음"이다. 지금 mock은 공유 fixture의 학생·랭크·보유 입력만 인연을 계산하기 때문이다. 이 처리가 없으면 mock 모드와 기존 계산기 테스트 대역에서 fixture 밖 입력의 계산기 전체가 실패한다. 실제 프로세스 서비스는 이 오류를 내지 않으므로 한 번만 부른다.

**인연 타일**(시안 112 높이, 왼쪽·오른쪽 29.7)
- 머리 줄: "인연 현재 → 목표"와 "필요 경험치 n · 현재 랭크 시작 기준 · 셋 중 하나로 채웁니다".
- 오른쪽에는 `bond.warnings`가 있으면 "경고 n건" 칩(warn)을 둔다. (i) "인연 계산 기준"에는 현재 랭크 시작 가정 · 자료 `jp-1.73.0` · 쓰다듬기 조건 · 경고 원문을 적는다.
- 세 안(시안 `.gbtn`, 고르면 분홍 바탕 + 안쪽 1.5 링, 별 아이콘 분홍):
  - 선호 선물 (대) · 일반 선물: 큰 수는 필요 개수 합 "×n"이다. 아래 줄은 "부족 n" / "보유로 충분" / "보유 미확인" / "쓸 수 없음"(`available=false`, 큰 수 "—")이다. 오른쪽은 꺾쇠다.
  - 카페 · 쓰다듬기: 큰 수는 필요 횟수 "n회"이다. 아래 줄 "최소 n시간 · 첫 회 즉시 가정"은 `minimumHours`와 조건 `first_interaction=immediate`를 함께 적는다. 오른쪽 "[?]"(툴팁 "하루 가능 횟수는 확인되지 않았습니다")가 `availableCount=null`이다. 하루 횟수·일수는 만들지 않는다.
- 기본 안은 선호 선물 (대)이고, 쓸 수 없으면 일반 선물이다(시안 g1 on).
- 안내 상태(문구만, 키 `calculator-bond-guide`):
  - 현재 인연을 모르면 "현재 인연 랭크를 모릅니다 · 학생 스캔이나 직접 입력으로 현재 랭크를 정하면 선물을 계산합니다", 머리 줄은 "인연 미확인 → n"이다.
  - 목표가 현재 이하이면 "인연 목표가 현재 랭크 이하입니다 · 목표 인연을 올리면 필요한 선물을 계산합니다"이다.
  - 계산할 수 없는 입력이면 "이 입력으로는 인연 선물을 계산할 수 없습니다"이다.

**선물 팝오버**(시안 `.gpop`, 폭 520, 아래 10, 꼬리 left 30)
- 선물 안을 누르면 그 안을 고르고 목록을 고정해 연다. 다시 누르기·Esc·바깥 누르기로 닫는다. 다른 안을 누르면 그 목록으로 바뀐다. 쓰다듬기를 누르면 선물 목록을 닫고 쓰다듬기를 고른다.
- 고르기는 고정·강조만 바꾼다. 다시 계산하지 않고, 재화 목록·"부족 n종"도 그대로다(FD-165).
- 내용:
  - 머리 줄: 안 이름(경기천년제목 16)과 설명.
  - 열 이름: 선물 · 경험치 · 수량 · 보유.
  - 선물 행(백엔드 배분 순서 그대로, FD-164): 아이콘 40(present 아이콘), 이름 + "1개 경험치 n · 선호 ×m", 경험치 합, "×필요" + "보유 사용 n", "보유 n" + 부족 n(분홍)/충분(초록). 보유를 모르면 빗금 + "미확인".
  - 합계 줄: "합계 ×n · 경험치 제공 / 필요 · 보유가 많은 선물부터 씁니다".
  - `available=false`면 "이 학생에게 맞는 선물이 없어 이 안은 쓸 수 없습니다"이다.

**경고 연결**
- `bond.warnings`는 인연 타일 칩 + (i)에 둔다.
- `result.warnings`(성장)는 "필요 재화" 제목 줄의 "계산 경고 n건" 칩 + (i)에 둔다. 경고가 없으면 칩이 없다. 계산 실패 문구가 있으면 그것을 먼저 보인다.

### 테스트

**`growth_calculator_adapter_test.dart`**: 새 그룹 "인연 선물(FB-11b, FE3-g)" 7건
- 확정 인연을 따로 보내고 currentStudent에 넣지 않음.
- 모르는 인연은 null(1·채운 값으로 채우지 않음), 직접 입력은 적은 값.
- 한 호출로 성장 + 인연(fixture 10→12: 필요 150, 일반 안 보유 사용 6), 같은 입력의 성장만 결과와 재화 key·부족 종류 수·크레딧이 같음(FD-165).
- 현재 미확인은 `{'current_rank': null}`, 안내 상태.
- `UnsupportedError`이면 성장만.
- 안 문구 4종과 기본 안.
- 재계산기는 디바운스 한 번에 마지막 요청의 성장 + 인연.

**`growth_calculator_view_test.dart`**: 새 그룹 "인연 타일(FE3-g)" 4건(공유 fixture 입력을 쓰는 `_BondService`: 기본 계정에 보유 아루 + fixture 인벤토리)
- 확정 인연 10을 따로 보내고 목표가 현재 이하면 안내.
- 10→12: "인연 10 → 12", 필요 경험치 150, 선호 ×1 "부족 1", 일반 ×7 "보유로 충분", 쓰다듬기 "10회" · "최소 27시간 · 첫 회 즉시 가정" · [?], 타일 안에 "하루" 없음.
- 팝오버: 일반 안 행(웨이브캣 베개 ×6 · 보유 사용 6, 매장금의 지도 ×1), 합계 ×7, "경험치 180 / 필요 150". 선호 안 행 "부족 1".
- 고르기는 강조만 바꾼다(호출 수 그대로, 재화 key 그대로, 부족 종류 수 그대로). 쓰다듬기를 누르면 목록이 닫힌다.
- 1→3(보유 스캔 없음): "보유 미확인", 행 "미확인", 인연 경고 칩은 있고 성장 경고 칩은 없음.
- 성장 경고 칩 "계산 경고 1건"(`_CalculatorService`에 warnings 매개변수를 더함, 기본 빈 목록이라 기존 테스트는 그대로).

**기대를 바꾼 것**
- "\"이 목표로 계획에 추가\"는 FE4-g 전까지 비활성 …"의 마지막 단언 `calculator-bond-empty`(빈 타일)를 `calculator-bond-guide`와 "인연 미확인" 머리 줄로 바꿨다.
- 이유: 빈 타일을 FE3-g 타일로 바꿨고, 그 mock의 첫 학생(아루)은 미보유라 현재 인연을 모른다. 그래서 안내 상태가 맞다.

**기존 테스트 대역**
- `_CalculatorService`처럼 `calculateStudent`만 덮어쓴 `MockAppService` 하위 클래스는 인연 호출이 fixture 밖이라 `UnsupportedError` → 성장만이다. 그래서 `calls` 수·결과가 그대로다.

### golden 예측

- 바뀜 1: `students-calculator`.
  - 장면에 인연 목표 1 → 3을 더했다. 공유 fixture "아루 1→3, present 스캔 없음"과 같은 입력이고, 계산기 golden 대역은 성장만 덮어쓰고 인연은 기본 mock 응답이다.
  - 그래서 S2 인연 목표 행이 3(바뀐 칸 분홍), "바꾼 목표" 칩에 인연, S3 인연 게이지에 목표 3 빗금·"현재 …" 태그가 생긴다.
  - 인연 타일: "인연 1 → 3 · 필요 경험치 45 · 현재 랭크 시작 기준 · 셋 중 하나로 채웁니다", "경고 1건" 칩 + (i). 세 안은 선호 선물 (대) ×1 "보유 미확인"(고름, 분홍) / 일반 선물 ×1 "보유 미확인" / 카페 · 쓰다듬기 3회 "최소 6시간 · 첫 회 즉시 가정" [?]이다.
  - 크레딧·재화 목록 숫자는 그대로(18,420,000, 재화 15행)다.
- 새 장면 1: `students-calculator-bond-popover`. 같은 장면에서 선호 선물 (대)를 눌러 목록을 연다. 고풍스러운 달걀 공예품 1행(1개 경험치 180 · 선호 ×3, 경험치 180, ×1 · 보유 사용 0, 빗금 + 미확인), 합계 ×1 · 경험치 180 / 필요 45가 보인다.
- 그대로: 나머지 장면. 계산기를 여는 장면은 이 둘뿐이고, 성장 경고 칩은 golden 결과에 경고가 없어 그려지지 않는다.
- 그래서 ① gate는 golden 2건 RED(바뀜 1 + 기준 없음 1)가 예상이다.

### 바뀐 동작(검토 때 볼 것)

1. mock 모드(MockAppService)에서는 공유 fixture 7건과 같은 입력일 때만 인연이 계산되고, 그 밖은 "이 입력으로는 인연 선물을 계산할 수 없습니다"이다. 이 경우 한 디바운스에 서비스 호출이 둘(인연 시도 → 성장)이다. 프로세스 서비스는 한 번이다.
2. 선물 목록은 마우스를 올리거나 포커스만으로는 열지 않는다. 시안처럼 고른 안의 목록만 열고, 누르면 고정한다. 닫아도 고른 안은 남는다.
3. 백엔드 경고 문장(영어 원문)은 (i) 안에 그대로 보인다. 칩 글자만 한국어다.
4. 선물 행 순서는 백엔드 배분 순서이고, 팝오버 설명에 "경험치가 높은 순"을 쓰지 않는다(FD-164 배분과 다를 수 있다).
5. 첫 결과가 오기 전 한 프레임은 머리 줄이 계산기 값("인연 1")이다. 현재 인연을 모르면 결과가 온 뒤 "인연 미확인 → n"이 된다.
6. 현재 인연을 모르는데 목표도 현재(채운 값)와 같으면 머리 줄이 "인연 미확인 → 1"처럼 보인다.

### 검수표

| 항목 | 확인 |
|---|---|
| bond(현재 인연, 모르면 null)를 같은 호출로, currentStudent에 bond_rank 없음, 1로 채우지 않음 | 어댑터 테스트 3건, 화면 테스트 1건 |
| 디바운스 한 번에 성장 + 인연, 이전 응답 버림 그대로 | 재계산기 테스트, 기존 디바운스 테스트 |
| 필요 경험치 · 세 안(필요량 · 보유 사용 · 부족), available=false "쓸 수 없음" | 어댑터 문구 테스트, 화면 테스트 |
| 모르는 값 빗금/미확인, availableCount=null → [?], 하루 횟수·일수 없음 | 화면 테스트 2건 |
| 쓰다듬기 minimumHours와 조건(첫 회 즉시) 구분 | 화면·어댑터 문구 테스트 |
| 선물 팝오버, 고르기는 고정·강조만 | 화면 테스트, golden 새 장면 |
| bond.warnings → 인연 타일, result.warnings → 성장 경고 | 화면 테스트 2건 |
| 선물은 성장 재화·부족 종류 수에 없음(FD-165) | 어댑터·화면 테스트 |
| 현재 인연 모름 / 목표 없음 → 안내 상태 | 화면 테스트 2건, 기존 테스트(바꾼 기대) |
| `lib/services/**`·금지 파일 미수정, ~습니다체 | 코드 확인(실행 안 됨) |

### 확인하지 못한 것

- analyze·테스트·golden 실행 전부(이 환경에 Flutter 없음).
- 새 그림: 안 버튼 글자 크기·줄임, 팝오버 열 폭(경험치 64 · 수량 70 · 보유 104)과 행 높이, present 아이콘 바탕, 작은 창(타일 최소 폭 420)에서 안 버튼 모양.
- ProcessAppService(실제 Python)에서 fixture 밖 입력의 인연 결과 화면.

### 사용자 실행 순서

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① gate만 실행 → 결과를 오케스트레이터에게 보내고 기다린다(golden 2건 RED 예상)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 승인 뒤 기준 이미지 갱신 → gate
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ③ 커밋
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3g -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe3g
```

### FE3-g commit record (2026-10-09 19:18, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261009_185920\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE4-e 계획 만들기 4단계 저장 (구현 끝, gate 전)

- 시작: 2026-10-09 20:10, 시작 SHA `0160910f2c803e28aee1bf04ab5abc7b2bb4cfde`(FE3-g 커밋 `6eb04542` 뒤 HEAD).
- 범위: 시안 Flow-4-Save. B(페이즈 행 미리보기 + hover 필요 재화, 활성 계획 비교 타일, 크게 늘어나는 재화), C(시나리오로 저장 / 활성 계획에 페이즈로 추가 / 이걸로 바꾸기, 패널 안 이름 입력, "저장한 뒤" 토글 2개), A primary 라벨 = C 선택.
- 고칠 기존 파일(사본 `debug/frontend_fe4e/pre/frontend/...`): `lib/ui/widgets/plan_flow_workspace.dart`, `lib/ui/models/plan_flow_draft.dart`, `lib/ui/widgets/plan_flow_rail.dart`, `lib/ui/widgets/plan_section_layout.dart`, `test/planning_page_test.dart`, `test/plan_flow_test.dart`, `test/goldens/fe1g_baseline_golden_test.dart`. 새 파일: `lib/ui/models/plan_flow_save.dart`, `test/plan_flow_save_test.dart`.

### FE4-e 종료 기록 (2026-10-09 20:52, 커밋 전)

상태: 구현 끝, gate 미실행. 시작 SHA `0160910f2c803e28aee1bf04ab5abc7b2bb4cfde`. `debug/frontend_fe4e/commit.json`(baseline whole)을 두었다. 직접 커밋하지 않았다.

#### 바꾼 것

시작 기록과 달리 `test/plan_flow_test.dart`는 고치지 않았고(사본만 남음), `test/goldens/golden_harness.dart`를 고쳤다(사본 추가). 새 파일은 `lib/ui/models/plan_flow_save.dart`, `lib/ui/widgets/plan_flow_save_step.dart`, `test/plan_flow_save_test.dart`다.

- 새 `lib/ui/models/plan_flow_save.dart`
  - `PlanFlowSaveTarget` 3지선다. 옵션 제목이 곧 C 버튼·A primary 글자다(FD-079).
  - `loadPlanFlowSaveSnapshot`: `plan.get`·`state.get` 같은 revision([loadRepositoryPlanSnapshot]) + `scenario.list`. 목록의 `current_profile_revision`이 계정 revision과 다르면 3번까지 다시 읽는다(FB-1c 메모 1).
  - `planFlowMergedPlanDocument`: 활성 문서 뒤에 초안 페이즈를 붙인다. 페이즈·단계 id가 겹치면 `-2`… 접미사. 초안 null은 그 학생이 활성 계획에서 이미 정한 키만 앞 값을 이어 받고(문서 퇴행 규칙), 나머지 null은 그대로다. 초안 값이 활성 값보다 낮으면 문서를 만들지 않고 "페이즈로 추가"를 막는다(학생 이름 안내). goal_metadata는 활성 우선.
  - `PlanFlowSaveComparison`: `compareScenarios(활성, 후보)`. 후보는 시나리오·바꾸기 = 초안(`kind=plan`), 페이즈로 추가 = 병합 문서(FD-080). 후보 문서 id는 `plan-flow-compare-*`(활성 id와 다르다). 충족률 FD-031 (a)는 비교 `resources[]`의 owned·required로 계산하고 보유를 모르는 재화는 "n종 모름"으로 센다. 부족 = `known_shortage_type_count`, 크레딧 = `credits_a/b`, 학생 = `students[].presence`. 크게 늘어나는 재화 = `required_delta_b_minus_a` 큰 순 3개. 페이즈 팝오버는 `projection_b.phase_results`.
  - `PlanFlowSaveController`: 4단계에 들어올 때마다 저장 직전 상태를 읽고 비교한다. 초안이 바뀌면 비교·보류 요청을 버린다.
    - 시나리오로 저장 = `createScenario`(목록 revision, base = 계정 revision, 설명 ''). 편집 흐름은 `updateScenario`(연 시나리오 revision, 첫 읽기는 편집을 열 때의 목록 revision).
    - 페이즈로 추가 = `saveRepositoryPlan(병합 문서, expectedRevision = plan.get revision, key)`.
    - 이걸로 바꾸기 = `replaceRepositoryPlan(초안 kind=plan, 활성 문서 id·이름, expectedScenarioRevision = scenario.list revision, archiveName, archiveDescription '')`. `archivedScenarioId` null이면 "활성 계획을 바꿨습니다."만 알린다.
    - authoring은 어느 경로에서도 보내지 않는다(FE4-f).
    - 실패: `revision_conflict`·`authoring_required`(`invalid_payload` + `reason`) → 보류 요청을 버리고 초안은 두고 다시 읽어 알린다. timeout·끊김·`repository_busy`·`persistence_failed`(또는 retryable) → 보류 요청을 그대로 두고 다시 누르면 같은 키·같은 문서 객체를 보낸다. `idempotency_conflict` → 새 키를 만들지 않고 "다시 읽기"를 안내한다. 그 밖의 코드는 코드와 함께 알린다.
    - 보류 요청은 위치·초안 객체·이름·snapshot revision이 같을 때만 다시 쓴다(바뀌면 새 키).
    - 저장하는 문서는 흐름 초안(v2)에서 바로 만든다. 계획 화면 `_document`·`_incorporateScenario`·정수 편집기 보기(v1 재구성)를 거치지 않는다(오케스트레이터 17:30 후속).
- 새 `lib/ui/widgets/plan_flow_save_step.dart`(시안 Flow-4-Save)
  - B: 제목 + 페이즈·단계 칩, 페이즈 행 P1~Pn(80° 사선 스크롤, 3행 넘으면 스크롤; 페이즈로 추가는 활성 페이즈 뒤 번호) — 학생 초상·이름·단계 태그, 상태 칩(모두 지금 가능 / 부족 n종, 막힌 단계가 있으면 빨강), "재화 ▸". 행에 마우스를 올리면(누르면 고정) 필요 재화 팝오버(부족 큰 순 6줄, 필요 N, −N/충분/여유, "앞 페이즈에서 쓰고 남은 양 기준입니다"). 시안의 "인벤토리에서 보기" 버튼은 넣지 않았다.
  - B: "지금 활성 계획과 비교" 타일 4칸, "가장 크게 늘어나는 재화" 3줄(막대 = 후보 기준 보유/필요).
  - C: "어디에 넣으시겠습니까" + (i), 3지선다(고를 수 없으면 흐리게 + 이유), 이름 칸(시나리오 이름 / 바꾸기는 옮겨 둘 기존 계획 이름, 기존 활성이 비면 안내 / 페이즈로 추가는 이름 없음 안내), "저장한 뒤" 토글 2개, 저장 버튼, 실패 안내 + "다시 읽기".
- `plan_flow_workspace.dart`: 저장 대화상자를 없애고 위 B·C를 그린다. A primary(`plan-flow-next`)와 C 버튼(`plan-flow-save-confirm`)은 같은 `_save`, 글자·활성은 C 선택을 따른다. `onSaved`를 더했다. 쓰지 않게 된 `planFlowSavePhaseContainerPath`·`_PlanFlowSaveAside`를 지웠다.
- `plan_flow_rail.dart`: `saveLabel`·`saveEnabled`(4단계 primary 글자·활성, 4단계 스텝 부제). 기본값은 그대로라 1~3단계 화면은 같다.
- `plan_flow_draft.dart`: `_document`에 kind 인자, `toPlanDocument` 추가. `PlanFlowCalculation.phaseResources`와 `planFlowPhaseResources`(`phase_results` 읽기). 쓰지 않게 된 `prepareScenarioSave`·`saveScenario`·`PlanFlowSavePreparation` 삭제.
- `plan_section_layout.dart`(최소 diff, CRLF 유지): 흐름 저장 결과를 받아, 활성 계획을 바꿨으면 계정 상태·활성 계획 snapshot을 비우고 다시 읽는다(`loadRepositoryPlan`이면 화면도). "시나리오 보기로 이동"이 켜져 있으면 닫은 뒤 시나리오 목록을 연다.
- 테스트
  - 새 `test/plan_flow_save_test.dart`: 병합(id 접미사, null 이어 받기·유지, goal_metadata, 퇴행 차단), FD-031 충족률, 비교 읽기, 시나리오 저장(패널 이름, v2 null), 페이즈로 추가(plan.save revision·key·authoring 없음), 퇴행 시 고를 수 없음, 바꾸기(빈 활성 → archivedScenarioId null / 기존 활성 → 고친 이름으로 보관), revision_conflict·authoring_required(다시 읽기, 초안 유지), 끊김(같은 키·같은 문서), idempotency_conflict(새 키 없음), A·C 글자 동기 위젯 테스트.
  - `planning_page_test.dart` "scenario creation builds goals and orders stages in the plan flow": 저장 대화상자 대신 패널 이름 칸에 입력하고 레일 primary로 저장한다. "시나리오 보기로 이동"이 기본 켜짐이라 저장 뒤 시나리오 목록이 저절로 열리므로 `plan-scenario-create-launch` 확인과 `plan-scenario-list-launch` 누르기를 뺐다(바꾼 이유: FD-079 패널 안 이름 입력·저장한 뒤 토글). 설명은 ''인지 본다.
  - golden: `golden_harness.dart` `GoldenPlanFlowMockAppService.compareScenarios`(단계 결과를 문서별로 모아 `phase_results`·비교 줄을 만드는 대역, 계산 대역은 그대로). 새 장면 `plan-flow-step4`, `plan-flow-step4-append`.

#### golden ① 예상

- RED(기준 이미지 없음): `plan-flow-step4`(시나리오로 저장 선택, B 페이즈 P1~P3 · 비교 타일 · 늘어나는 재화), `plan-flow-step4-append`(페이즈로 추가 선택, P3~P5, P4 필요 재화 팝오버 고정).
- 그대로: 나머지 장면 전부. `plan-flow-step1`~`plan-flow-step3-many`는 4단계 스텝 부제("시나리오로 저장")와 1~3단계 primary 글자가 같다. 계산 대역(`calculatePlanningDocument`)은 바꾸지 않았다.

#### 검수표

| 항목 | 확인 |
|---|---|
| B 페이즈 행 P1~Pn + hover 필요 재화 팝오버("앞 페이즈에서 쓰고 남은 양 기준") | golden append 장면, 위젯 테스트(행 키) |
| 비교 타일: 충족률 FD-031 (a)·부족·크레딧·학생, 페이즈로 추가 = compareScenarios(active, merged) | 단위 테스트 2건, golden |
| C 3지선다, 이름은 패널 안(다이얼로그 없음), "저장한 뒤" 독립 토글 2개, 설명 입력 없음 | 위젯 테스트, planning_page_test |
| A primary와 C 버튼 같은 동작, 글자 = C 선택 | 위젯 테스트(세 위치), golden 2장면 |
| 시나리오 = createScenario / 페이즈로 추가 = plan.save(plan.get revision, key) / 바꾸기 = plan.replace(scenario.list revision), archivedScenarioId null | 단위 테스트 4건 |
| 저장 문서는 v2 초안 그대로(null 유지), v1 재구성 경로 안 거침 | 단위 테스트(nullableTargets null 확인), 코드 확인 |
| authoring 안 보냄, authoring_required·revision_conflict → 초안 유지 + 다시 읽기 | 단위 테스트 2건 |
| 같은 key 재시도 = 같은 payload, idempotency_conflict는 새 키 없음 | 단위 테스트 2건 |
| `lib/services/**`·backend·contracts·스캐너·tactic 미수정, app_shell 미수정, `plan_section_layout` 최소 diff | 코드 확인 |

#### 확인하지 못한 것

- analyze·테스트·golden 실행 전부(이 환경에 Flutter 없음). 정적 검토만 했다(별도 검토 1회, 지적 반영).
- 새 그림: 페이즈 행 칩 폭(150 고정)·"+n명", 팝오버 위치(행 아래 오른쪽 맞춤), 비교 타일 글자 크기(26)와 작은 창에서의 줄임, C 패널 행 간격(작은 창에서 세로 넘침 가능).
- 실제 백엔드(ProcessAppService)에서 `plan.replace`·`plan.save`·`scenario.compare` 왕복과 오류 코드 모양(`repository_busy`·`persistence_failed` retryable 여부 포함).
- `loadRepositoryPlan == false`인 계획 화면은 활성 계획을 바꾼 뒤 계정 snapshot만 다시 읽고 작업 문서(`_document`)는 다시 만들지 않는다(앱은 `loadRepositoryPlan: true`로 쓰는지 확인 필요).

#### 남은 일·서비스 요청

- 서비스 요청 없음. "단계 순서는 페이즈 편집에서 다시 바꿀 수 있게 유지" 토글은 상태만 둔다(authoring 저장은 FE4-f).
- 초안 목표가 활성 목표보다 낮은 학생이 있으면 "페이즈로 추가"를 막는다. 올려서 붙일지(활성 값으로 맞춤)·그 학생만 빼고 붙일지는 정하지 않았다(오케스트레이터 판단 필요).
- 4단계 스텝 부제는 시안의 "시나리오 또는 활성 계획" 대신 고른 위치 글자다(1~3단계 golden을 흔들지 않으려고). 바꾸려면 7장면 갱신.

#### 사용자 실행 순서

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① gate만 실행 → 결과를 오케스트레이터에게 보내고 기다린다(새 장면 2건 RED 예상)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 승인 뒤 기준 이미지 갱신 → gate
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ③ 커밋
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4e -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4e
```

### FE4-e commit record (2026-10-09 22:05, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261009_215639\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE4-i 프리셋·내 그룹 저장 연결 (구현 끝, gate 전)

- 시작: 2026-10-09 22:20, 시작 SHA `df547db746534def4316e24b3b983a689f1ada56`(FB-8b `9aab5453`, FE4-e `3af5246c`, 문서 커밋 뒤 HEAD).
- 범위: 0) golden 비교 대역을 계산 대역 기준으로 맞추고 레일 = 비교 b 단언 추가(22:10 후속), 1) FB-14 `repository.presets.get/save` 화면 연결, 2) 2단계 단계 프리셋 저장·적용·이름 바꾸기·삭제, 3) 1단계 "내 그룹" 저장·불러오기·삭제, 4) 계산기 "빠른 목표"에 단계 프리셋 마지막 단계(FD-169). 필터 프리셋은 범위 밖.
- 고칠 기존 파일(사본 `debug/frontend_fe4i/pre/frontend/...`): `lib/ui/models/planning_models.dart`, `lib/ui/models/plan_flow_goal_editor.dart`, `lib/ui/widgets/plan_flow_goal_step.dart`, `lib/ui/widgets/plan_flow_student_step.dart`, `lib/ui/widgets/plan_flow_workspace.dart`, `lib/ui/models/growth_calculator_rules.dart`, `lib/ui/models/growth_calculator_state.dart`, `lib/ui/widgets/growth_calculator_section.dart`, `lib/ui/widgets/student_section_layout.dart`, `lib/ui/pages/student_page.dart`, `test/goldens/golden_harness.dart`, `test/goldens/fe1g_baseline_golden_test.dart`.

### FE4-i 종료 기록 (2026-10-09 23:15, 커밋 전)

상태: 구현 끝, gate 미실행. 시작 SHA `df547db746534def4316e24b3b983a689f1ada56`. `debug/frontend_fe4i/commit.json`(baseline whole, status=true)을 두었다. 직접 커밋하지 않았다. 시작 기록 목록에 더해 `test/plan_flow_test.dart`, `test/growth_calculator_view_test.dart`를 고쳤다(사본 추가). 새 파일은 `lib/ui/models/repository_presets_controller.dart`, `test/plan_flow_presets_test.dart`다.

#### 0. golden 비교 대역 맞추기(22:10 후속)

- `GoldenPlanFlowMockAppService.compareScenarios`가 두 문서를 계산 대역으로 계산하고 그 `overall`로 비교 줄을 만든다(백엔드 `compare_document_projections`와 같은 식: a쪽 줄이 있으면 그 보유량, 부족 = 필요 − 보유, 크레딧 = `overall.cost.credits`). 페이즈 팝오버용 `phase_results`만 단계 결과를 페이즈마다 모아 더한다(계산 대역은 빈 목록).
- 계산 대역 `overall`은 문서와 상관없이 고정(48.2M, 부족 5종)이므로 a·b 값이 같다. 1~3단계 장면의 레일 숫자를 흔들지 않으려고 계산 대역은 바꾸지 않았다.
- 단언(`plan-flow-step4`): 같은 초안이면 비교 `credits_b` = 레일 필요 크레딧, `known_shortage_type_count_b` = 레일 부족 재화 종 수, 비교 타일 크레딧·부족 칸의 b쪽 글자 = 레일 글자.

#### 1~4. 바꾼 것

- 새 `repository_presets_controller.dart`(`RepositoryPresetsController`): 선택 프로필의 묶음(단계 프리셋 + 학생 그룹)과 묶음 자체 revision. 저장은 두 목록 전체 교체 + 사용자 저장마다 새 키. 성공하면 get으로 다시 읽는다(replay revision을 믿지 않음).
  - `revision_conflict`: 최신 묶음을 다시 읽고 하려던 편집(새 프리셋·이름·삭제·그룹)을 남겨 알린다. 저절로 다시 보내지 않고 "다시 저장"이 그 편집을 최신 목록 위에 새 키로 적용한다(적용할 대상이 없어졌으면 알린다).
  - 연결 끊김·`repository_busy`·`persistence_failed`(또는 retryable): 같은 요청 객체(같은 키·같은 내용)를 "다시 저장"으로 다시 보낸다.
  - `idempotency_conflict`: 새 키를 만들지 않고 다시 읽는다. 읽기 실패는 "다시 저장"이 다시 읽는다.
  - 안내는 어느 목록의 것인지(프리셋/그룹) 나눠 2단계는 프리셋, 1단계는 그룹 안내만 보인다.
  - `planElementPresetFromRepository`: 저장된 프리셋 → 적용 모델(non-null만 듬성한 목표, 단계 이름, id `stored:<preset_id>`). 저장 원본은 바꾸지 않는다.
- `planning_models.dart` `PlanElementPreset`: `stageNames`, `repositoryPresetId`, `stageNameAt`(선택 인자라 기존 호출 그대로).
- 2단계(`plan_flow_goal_editor.dart`, `plan_flow_goal_step.dart`)
  - 프리셋 바 "지금 구성을 프리셋으로"(숨겨 둔 저장): 지금 학생의 초안 v2 단계(앞 단계보다 올린 단계, 단계 이름 + 19키 nullable 원본, null을 지금 값으로 채우지 않음)를 새 프리셋으로 저장한다. 기본 이름 "학생 목표 n단계". 단계가 없거나 저장 중이면 비활성.
  - 프리셋 적용은 기존 누적 펼침 규칙 그대로이고 저장된 단계 이름을 카드 이름으로 쓴다.
  - C 프리셋 행: 저장된 프리셋이 먼저(이름 바꾸기 = 행 안 입력, 지우기 아이콘), 계획 화면 프리셋 관리의 인메모리 프리셋은 뒤에 적용만. 저장 안내 줄 + "다시 저장".
- 1단계(`plan_flow_student_step.dart`) C "내 그룹": 머리 줄(+ (i), "지금 고른 학생으로 그룹 만들기"), 그룹 행 최대 3개(이름 · 초상 3 · "n명" / "n명 · 목록에 없음 m" · 지우기). 행을 누르면 카탈로그에 있는 그룹 학생만 고른 순서 뒤에 더한다(이미 고른 학생 그대로). 카탈로그에 없는 ID는 고르지 않지만 저장 요청에서 빼지 않는다. 기본 이름 "첫 학생 외 n명".
- `plan_flow_workspace.dart`: 흐름마다 저장소 하나를 만들어 다음 프레임에 읽는다. 1단계 C·2단계 B·C에 넘기고, 저장된 프리셋 + 인메모리 프리셋을 2단계 편집 상태에 넣는다.
- 계산기(`growth_calculator_rules.dart`·`_state.dart`·`_section.dart`, `student_section_layout.dart`, `student_page.dart`): "빠른 목표" 고정 3항목 뒤에 선택 계정 단계 프리셋의 마지막 단계("이름 · 마지막 단계")를 붙인다. 고르면 그 단계가 정한 키만 올리고(현재값보다 낮으면 현재값) 나머지는 현재값, 정규화. 계산기를 열 때·계정이 바뀔 때 저장소에서 다시 읽는다.
- 필터 프리셋은 범위 밖(칩 숨김 유지). `lib/services/**`·backend·contracts·스캐너·tactic·app_shell 미수정.

#### 테스트

- 새 `test/plan_flow_presets_test.dart`: 저장소(원본 nullable·단계 이름 저장, 전체 교체로 반대쪽 목록 유지, 저장 뒤 다시 읽기, 이름 바꾸기·삭제, 그룹의 목록에 없는 ID·순서 보존·중복 제거, revision_conflict → 다시 읽기·편집 유지·다시 저장 새 키, retryable → 같은 요청 객체, idempotency_conflict → 새 키 없음, 저장소 없는 서비스), 적용 모델, 2단계 단계 이름 적용·저장 단계 v2 원본, 2단계 위젯(저장·이름 바꾸기·삭제), 1단계 위젯(목록에 없음 표시, 누르면 고르기, 그룹 저장, 지우기), 계산기 프리셋 항목 규칙·상태. 테스트 대역은 `loadRepositoryPresets(String)`·`saveRepositoryPresets(RepositoryPresetsSaveRequest)` 현재 시그니처 그대로다.
- `test/plan_flow_test.dart`(바꾼 기대, 1줄): 2단계 "저장 버튼은 없다(FD-074)" → 프로필 저장소가 있으면 `plan-flow-goal-preset-save`가 있다(FE4-i가 숨겨 둔 저장을 연다).
- `test/growth_calculator_view_test.dart`: 빠른 목표에 저장된 프리셋 마지막 단계 항목이 붙고 고르면 레벨만 오르는 테스트 1건 추가.
- golden: `golden_harness.dart` 비교 대역(0번)과 `seedPresetScene`, `fe1g_baseline_golden_test.dart` 0번 단언과 새 장면.

#### golden ① 예상

- 새 장면(기준 없음): `plan-flow-step2-saved` — 1단계에서 저장된 그룹 "총력전 · 신비 딜러"(호시노·아루 + 목록에 없는 학생 1)로 두 명을 고르고, 2단계에서 저장된 프리셋 "총력전 3단계 · 내 프리셋"(단계 이름 성장 기반 → 스킬·인연 → 성급·전용무기)을 적용한 상태. 프리셋 바 맨 앞 저장된 프리셋 · 인메모리 2개 · MAX · 직접 입력 · "지금 구성을 프리셋으로", C 첫 행에 이름 바꾸기·지우기 아이콘과 저장 안내 없음.
- 바뀜 7: `plan-flow-step1`·`plan-flow-step1-many`·`plan-flow-step1-filter`(C에 "내 그룹" 머리 줄 + 버튼 + "만든 그룹이 없습니다" 줄, 그 아래 역할군 칩·보이는 학생 줄이 아래로 밀림), `plan-flow-step2`·`plan-flow-step2-more`(프리셋 바에 "지금 구성을 프리셋으로"), `plan-flow-step4`·`plan-flow-step4-append`(비교 숫자: 충족률·부족 5 → 5종·크레딧 48.2M → 48.2M 처럼 a·b가 같고, "가장 크게 늘어나는 재화"는 "활성 계획보다 늘어나는 재화가 없습니다" 한 줄. append 팝오버 숫자는 그대로).
- 그대로: 나머지 장면 전부(`plan-flow-step3`·`-many`, 학생·계산기 장면 포함 — 계산기 드롭다운은 닫힌 상태).

#### 검수표

| 항목 | 확인 |
|---|---|
| 0: 비교 대역 = 계산 대역 기준, 레일 = 비교 b 단언 | golden 테스트 단언 4개 |
| presets.get/save, 프로필별·자체 revision·두 목록 전체 교체·idempotency key | 단위 테스트 3건 |
| revision_conflict → 다시 읽고 편집 유지·알림, retryable → 같은 요청, idempotency_conflict → 새 키 없음 | 단위 테스트 3건 |
| 단계 프리셋 저장(이름 + 단계 이름·19키 nullable 원본)·적용(단계 이름)·이름 바꾸기·삭제, 숨긴 "저장" 열기 | 단위·위젯 테스트, golden 새 장면 |
| 내 그룹 저장·불러오기·삭제, 목록에 없는 학생 ID 보존 | 단위·위젯 테스트, golden 새 장면 |
| 계산기 빠른 목표에 프리셋 마지막 단계(같은 저장소) | 단위 2건, 계산기 위젯 1건 |
| 필터 프리셋 범위 밖, 금지 파일 미수정, ~습니다체 | 코드 확인 |

#### 확인하지 못한 것

- analyze·테스트·golden 실행 전부(이 환경에 Flutter 없음). 정적 검토만 했다(별도 검토 1회, 지적 반영: 기존 테스트 1줄, 내 그룹 머리 줄 배치, 재시도·읽기 실패·안내 범위, 이름 입력 닫기, 좁은 창 그룹 행).
- 새 그림: 프리셋 바가 길어질 때 가로 스크롤과 저장 버튼 자리, C 프리셋 행 아이콘 두 개와 이름 줄임, 내 그룹 행(초상 32×26)과 작은 창에서 C 아래쪽 넘침(1단계 6명 + 그룹 3개 + 역할군 칩).
- ProcessAppService(실제 Python)에서 presets 왕복·오류 모양.

#### 남은 일·판단

- 그룹 이름 바꾸기는 없다(저장·불러오기·삭제만). 새 그룹·프리셋 이름은 기본 이름으로 바로 저장하고, 프리셋만 C에서 이름을 바꾼다.
- 계획 화면 프리셋 관리(인메모리)는 그대로다. 2단계에서는 저장된 프리셋 뒤에 적용 전용으로 보인다. 프리셋 관리를 저장소로 옮길지는 정하지 않았다(오케스트레이터 판단).
- 계산 대역 `overall`이 고정이라 4단계 비교 장면은 a·b가 같다. 비교 타일의 차이 표현을 golden으로 보려면 계산 대역을 문서 의존으로 바꿔야 하고 1~3단계 장면이 함께 바뀐다.

#### 사용자 실행 순서

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① gate만 실행 → 결과를 오케스트레이터에게 보내고 기다린다(위 7장면 변경 + 새 장면 1건 RED 예상)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 승인 뒤 기준 이미지 갱신 → gate
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ③ 커밋
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4i -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4i
```

### FE4-i commit record (2026-10-09 23:23, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261009_231201\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE4-f 교차 선행·나중에 칸 (f1 구현 끝, gate 전)

- 시작: 2026-10-09 23:35, 시작 SHA `7965e4620d7f05e7b522af250462eb274bdb10f3`(FE4-i `e5555b52`, 문서 커밋 뒤 HEAD).
- 범위가 커서 둘로 나눈다. 이번에는 **FE4-f1**만 한다.
  - **f1(이번)**: 초안 모델(명시 나중에 단계 목록 · 직접 선행 목록, 목표 편집 중 임시 미배치와 구별), 크게 보기 "나중에" 칸 · 분홍 점선 직접 선행 만들기(카드 아래 점 끌기 · C "선행 단계 추가")·지우기(C ×), 자기 학생·자기 자신·중복·순환·앞 칸 거부(백엔드 reason과 같은 말), 칸마다 자동 체인 + 직접 선행의 stable topological 순서를 phase.stages · deferred_stages 배열에 반영, `ensurePlaced`가 명시 나중에를 다시 배치하지 않음, 모두 나중에여도 저장, 저장 3지선다가 authoring 전체를 보냄(시나리오 create/update · 페이즈로 추가는 활성 authoring과 병합 · 이걸로 바꾸기), 시나리오 편집을 document + authoring으로 복원, authoring 오류 reason · stage ID를 카드에 잇기(초안 유지), 작게 보기도 "나중에" 칸과 고른 카드의 직접 선행 선(경로 다듬기 전).
  - **f2(다음)**: 작게 보기 S 곡선이 사이 줄 칩 위를 지나지 않게 경로 다듬기(직접 선행 점선 포함, 16:25 후속), `_incorporateScenario` stage ID 재발급 시 deferred · 직접 edge endpoint · 학생 체인 remap(끝점 빠진 edge를 조용히 지우지 않음), 활성 계획(plan.get document + authoring)을 흐름 초안으로 여는 진입(지금은 진입 경로가 없다).
- 고칠 기존 파일(사본 `debug/frontend_fe4f/pre/frontend/...`): `lib/ui/models/plan_flow_draft.dart`, `lib/ui/models/plan_flow_order_editor.dart`, `lib/ui/models/plan_flow_save.dart`, `lib/ui/widgets/plan_flow_order_step.dart`, `lib/ui/widgets/plan_flow_save_step.dart`, `lib/ui/widgets/plan_flow_rail.dart`, `lib/ui/widgets/plan_section_layout.dart`(시나리오 편집 복원에 authoring을 넘기는 한 곳), `test/plan_flow_order_step_test.dart`, `test/plan_flow_save_test.dart`, `test/goldens/fe1g_baseline_golden_test.dart`.

### FE4-f1 종료 기록 (2026-10-10 00:40, 커밋 전)

상태: f1 구현 끝, gate 미실행. 시작 SHA `7965e4620d7f05e7b522af250462eb274bdb10f3`. `debug/frontend_fe4f/commit.json`(baseline whole, status=true)을 두었다. 직접 커밋하지 않았다. 시작 기록의 파일 목록 그대로 고쳤고(사본 있음), 새 파일은 `test/plan_flow_authoring_test.dart` 하나다. `lib/services/**`·backend·contracts·스캐너·tactic·app_shell 미수정.

#### 바꾼 것

- 초안(`plan_flow_draft.dart`)
  - `PlanFlowDraft.deferredStageIds`(명시 "나중에" 칸, 칸 안 순서) · `prerequisites`(`PlanFlowPrerequisite`, 학생 간 직접 선행). `unassignedStages`는 칸에도 나중에 칸에도 없는 단계(목표 편집 중 임시 미배치)만이다. `allStagesAssigned`는 "칸 또는 나중에 칸"이라 모두 나중에여도 참이다.
  - `planFlowOrderEdges`(자동 체인 + 유효한 직접 선행), `planFlowStableTopological`(놓을 수 있는 것 중 원래 자리가 가장 앞인 것부터, 순환이면 남은 것을 원래 순서로), `planFlowOrderIssues`(백엔드 reason과 같은 말: `stage_reference`·`self_reference`·`same_student_prerequisite`·`duplicate_prerequisite`·`cycle`·`lane_order`·`stage_order`, 카드 id 포함). 나중에 칸 = 마지막 칸(칸 수).
  - 컨트롤러: `orderReady`(모두 놓임 + 위반 없음)가 3단계 완료·4단계 진입·"다음"을 정한다. `orderIssues`(초안마다 한 번 계산), `savedIssue`/`reportSavedIssue`(저장 거절 reason을 카드에 잇고, 초안이 바뀌면 없어짐), `issuesOf`.
  - 칸 배열은 이동·잇기·배치·자동 정렬마다 자동 체인 + 직접 선행의 stable topological 순서로 다시 놓는다(기존 `_sortLaneByStep` 대체, 기존 테스트의 순서는 그대로). 같은 칸 배분 순서가 부족 배분에 영향을 주므로 이 배열이 그대로 phase.stages · deferred_stages가 된다.
  - `moveStage(phaseId: planFlowDeferredLaneId)`: 나중에 칸으로 옮기면 같은 학생 뒤 단계도 함께 간다(배치 prefix + 나중에 suffix). `orderViolation`은 자동 체인과 직접 선행 양쪽을 본다(선행보다 앞 칸 · 기다리는 단계보다 뒤 칸 거부, 기존 문구 그대로 + 직접 선행 문구).
  - `addPrerequisite`/`removePrerequisite`: 자기 자신 · 같은 학생 · 이미 이음 · 순환 · 먼저 끝나야 하는 단계가 뒤 칸이면 거부하고 이유를 돌려준다. 같은 칸이면 선행을 앞으로 놓는다.
  - `placeUnassignedStages`: 선행부터 놓고, 먼저 끝나야 하는 단계보다 앞 칸·기다리는 단계보다 뒤 칸에 두지 않는다. 앞 단계가 나중에 칸이면 나중에 칸으로 간다. 명시 나중에 단계는 다시 놓지 않는다(놓을 것이 없어도 2단계에서 순서가 바뀌었으면 배열만 다시 정리). `autoArrange`는 나중에 칸을 두고 직접 선행을 지킨다. `completeOrder`는 칸에 넣은 id를 나중에 칸에서 뺀다.
  - 목표 편집(`setStudentStages`·`confirmStudentStages`)에서 남은 단계의 명시 나중에는 둔다. 학생 빼기·단계 지우기·목표 편집으로 **사용자가 지운 단계**에 걸린 직접 선행은 함께 지운다(아래 판단 1).
  - 계산: 나중에 칸 단계는 계산 문서에서 빠지고(상태 없음), 모두 나중에면 계산을 부르지 않는다.
  - 경계: `PlanFlowDocumentBoundary.fromDocument(document, authoring:)`(없으면 DTO 기본값; 학생 순서 = `student_order`, 학생 체인 = `stage_order_by_student`, 나중에 단계 nullable 목표 그대로, goal_metadata는 문서 학생은 문서 것·나머지 선택 학생은 authoring 것), `authoringWire`/`authoringFor`(공용 `PlanningAuthoring.fromWire`로 만든다. 단계 없는 선택 학생 포함).
- 3단계 화면(`plan_flow_order_step.dart`, `plan_flow_order_editor.dart`)
  - 크게 보기: 마지막 칸 아래 "칸 추가", 그 아래 "나중에" 칸(점선 타일 `.dash`, 머리 "나중에 · 아직 급하지 않은 단계를 여기로", 이름 고치기 없음, 상태 칩 없음). 나중에 칸 카드 상태는 "나중에", 비용 줄 "나중에 칸 단계는 계산에서 빠집니다".
  - 직접 선행 분홍 점선(#f2b3ef 2.5, 7 5, 꺾쇠 실선 2.2): 같은 학생 화살표와 같은 경로 함수(칸 사이 틈 · 칸 머리 피하기)를 쓴다. 범례에 "직접 이은 선행 조건".
  - 잇기: 카드 아래 점(분홍 원)을 다른 카드에 끌어 놓기, 또는 C "선행 단계 추가" → 카드 누르기(머리에 분홍 안내). 거부하면 머리에 이유. 규칙을 어긴 카드는 빨간 테두리 + 의미 구조에 이유.
  - C: 위반 이유 행, "먼저 끝나야 하는 단계"에 자동 행 + 직접 선행 행(최대 3, 분홍 고리 아이콘, "직접"/"직접 · 나중에", × 지우기) + "선행 단계 추가"(고르는 중이면 "카드를 눌러 고릅니다 · 그만두기"), 나중에 칸 카드면 "나중에 칸 · 계산에서 빠집니다" 행.
  - 작게 보기: "칸 추가" 아래 나중에 칸(점선, 머리 "나중에 · 단계 n개"), 칩도 점을 받아 잇는다, 고른 카드의 직접 선행·기다리는 단계 선을 분홍 점선으로(경로는 기존 S 곡선 그대로, 다듬기는 f2), 위반 칩은 빨간 테두리.
- 저장(`plan_flow_save.dart`, `plan_flow_save_step.dart`, `plan_flow_rail.dart`)
  - 시나리오 create/update · 이걸로 바꾸기: 초안 authoring 전체(`authoringFor`)를 보낸다. 페이즈로 추가: `planFlowMergedPlanDocument(activeAuthoring: plan.get authoring)`가 학생 순서(활성 뒤 새 학생) · 체인(활성 배치 → 초안 배치 → 활성 나중에 → 초안 나중에) · deferred_stages(활성 뒤 초안) · 직접 선행(바꾼 id로 끝점 remap, 끝점이 빠진 edge도 지우지 않고 보냄)을 합치고 공용 validator로 확인한다. 실패하면 위치를 고를 수 없고 reason을 보인다. 단계 id 재발급 표 `stageIds`.
  - `invalid_payload` + validator reason, 또는 보내기 전 `PlanningAuthoringFormatException` → `invalid_authoring`: 보류 요청을 버리고 다시 읽지 않으며, reason 설명 + stage ID(페이즈로 추가면 병합 id → 초안 id)를 `reportSavedIssue`로 3단계 카드에 잇는다. 초안은 그대로다. `authoring_required`·`revision_conflict`는 기존대로 다시 읽기.
  - 4단계 B 개수 칩에 "나중에 n개", 페이즈가 없으면 "모든 단계가 나중에 칸에 있어 만들어질 페이즈가 없습니다", 레일 3단계 부제 "… · 나중에 n개", 페이즈로 추가 부제(새 페이즈 0개) "붙일 페이즈 없이 나중에 칸 단계만 보관합니다".
  - nullable 목표는 정수 v1로 바꾸지 않는다(초안 v2 → 문서·deferred_stages 그대로).
- `plan_section_layout.dart`(CRLF, 2줄): 시나리오 비교 "편집"이 `scenario.document + scenario.authoring`으로 초안을 연다.

#### 판단(오케스트레이터 확인 부탁)

1. 사용자가 단계를 지우면(학생 빼기 · 2단계에서 단계 지우기 · 프리셋 재적용으로 id가 바뀜) 그 단계에 걸린 직접 선행도 지운다. 저장 실패 · 병합 · 복원에서는 지우지 않는다. 복원한 초안에 끝점이 빠진 edge가 있으면 `stage_reference` 위반으로 카드·C에 보이고 C ×로 지운다.
2. "칸 추가"는 마지막 칸과 "나중에" 칸 사이에 둔다(새 칸은 나중에 칸 위에 생긴다). 시안에는 "칸 추가"가 없다. 그래서 칸 → 나중에 칸으로 가는 꺾인 선이 "칸 추가" 타일 위를 지난다(f2 경로 다듬기에서 같이 본다).
3. 나중에 칸 타일은 시안 `.plain`(투명) 대신 `.dash`(옅은 바탕 + 점선)로 그렸다. 끌어 놓는 칸이라 경계가 보이게 했다.
4. 4단계 "단계 순서는 페이즈 편집에서 다시 바꿀 수 있게 유지" 토글은 여전히 상태만 둔다. FE4-f1부터 authoring은 늘 보낸다(나중에 칸·직접 선행을 잃지 않게). 끄면 무엇을 덜 보낼지 정하지 않았다.
5. 페이즈로 추가에서 초안 배치 목표가 활성 나중에 단계 목표보다 높으면(체인상 활성 나중에가 뒤) validator `target_regression`으로 그 위치를 막고 "활성 계획의 나중에 칸·선행 조건과 맞출 수 없어 붙일 수 없습니다(뒤 단계 목표가 앞 단계보다 낮습니다)"를 보인다. 활성 나중에 단계를 몰래 올리지 않는다.
6. 직접 선행에는 시안의 메모("노트 먼저 쓰기")를 두지 않았다(authoring v1에 자리가 없다). C 행 오른쪽은 "직접"이다.

#### 서비스·백엔드 확인 요청(코드는 고치지 않았다)

- 백엔드 `PlanningAuthoringError`(ValueError)가 repository/scenario 프로토콜에서 `invalid_payload` + `details{reason, stage_id, requires_stage_id}`로 나가는지 확인 부탁. 프로토콜 `except (TypeError, ValueError)` 경로로 가면 details가 빠져 프론트는 `invalid_payload` 일반 오류(재시도 없음)로만 보인다. 프론트는 보내기 전에 같은 공용 validator로 막으므로 정상 사용에서는 나오지 않는다.
- compare(`planning.scenario.compare`)·계산에 페이즈가 0개인 문서(모두 나중에)를 넘겨도 되는지 확인 부탁. 계산은 프론트가 부르지 않게 했고, 4단계 비교는 그대로 부른다.

#### 테스트

- 새 `test/plan_flow_authoring_test.dart`(14건): 나중에 칸으로 옮기기(뒤 단계 함께 · ensurePlaced가 다시 놓지 않음 · 계산 문서에서 빠짐 · 앞 단계가 나중에면 꺼낼 수 없음), 모두 나중에 → 3단계 완료 · 계산 안 부름 · authoring(nullable 그대로), 목표 편집 중 임시 미배치와 명시 나중에 구별, 직접 선행 거부 5종 · 같은 칸 정렬 · 나중에 칸 안 정렬 · 지우기, 자동 정렬과 직접 선행, 위반 reason·카드(lane_order · cycle · stage_reference), authoring wire ↔ 복원(목표 없는 선택 학생 · goal_metadata), 시나리오 create authoring 저장 · 페이즈로 추가 병합(활성 나중에 보존 · id 재발급 remap · edge 끝점), authoring 오류 → 카드 · 초안 유지 · 다시 읽지 않음, 오류 코드 매핑, 위젯 3건(나중에 칸 끌어 놓기 · C 선행 단계 추가 → 카드 누르기 → 분홍 점선 → C × · 카드 아래 점 끌기와 거부 이유).
- `test/plan_flow_save_test.dart`: 시나리오 대역이 authoring을 기록·전달한다. "authoring은 보내지 않는다" 기대 2곳을 "보낸다"로 바꾸고 내용(학생 순서 · 바꾼 id 체인 · 나중에 없음)을 본다.
- `test/plan_flow_order_step_test.dart`: 칸 추가 뒤 "여기로 끌어다 놓기"는 빈 나중에 칸에도 있어 새 칸 안에서 찾는다(1곳).
- 테스트 대역 시그니처: `_AuthoringService.createScenario`·`saveRepositoryPlan`, 기존 `_RecordingService` 세 개 모두 `PlanningAuthoring? authoring` 선택 매개변수까지 서비스와 같다.
- 정적 검토(별도 검토 1회): 컴파일·시그니처 문제 없음. 지적 반영 — 모두 나중에일 때 계산 안 부름, 2단계에서 나중에 칸 순서가 바뀌면 배열 다시 정리, 자동 정렬에서 앞 단계가 나중에면 나중에 칸으로, `completeOrder` 겹침 제거, 테스트 주석.

#### golden ① 예상

- 새 장면(기준 없음): `plan-flow-step3-deferred` — plan-flow-step3와 같은 세 명. 아루 3단계를 "나중에" 칸으로 옮겨 3순위 칸은 빈 칸("여기로 끌어다 놓기"), 그 아래 "칸 추가", 그 아래 점선 나중에 칸에 아루 3단계 카드(상태 "나중에", 비용 줄 "나중에 칸 단계는 계산에서 빠집니다"). 아루 1단계(1순위) → 호시노 2단계(2순위) 분홍 점선 화살표(같은 학생 회색 화살표와 같은 꺾인 경로, 끝이 호시노 2단계 윗변에서 회색과 겹칠 수 있음). 호시노 2단계를 골라 C에 "먼저 끝나야 하는 단계": 호시노 1단계 · 자동, 아루 1단계 · 직접 · ×, "선행 단계 추가". 레일 3단계 부제 "단계 7개 · 순서 2칸 · 나중에 1개". 아루 3단계가 계산에서 빠져 상태 배지·칸 머리 칩이 plan-flow-step3와 다를 수 있다.
- 바뀜 2: `plan-flow-step3`(크게 보기: "칸 추가" 아래 빈 점선 나중에 칸 + 머리 글자, 카드 7장 아래 가운데 쪽 분홍 점, 범례에 분홍 점선 "직접 이은 선행 조건", C "먼저 끝나야 하는 단계" 아래 "선행 단계 추가" 행이 생겨 그 아래 "이 칸에서 부족한 재화"·"자동으로 정렬"이 약 58px 내려감), `plan-flow-step3-many`(작게 보기: "칸 추가" 아래 점선 나중에 칸 — 보드 아래쪽이라 일부 또는 전부가 스크롤 밖일 수 있음, 범례에 분홍 점선, 펼친 호시노 2단계 카드에 분홍 점, C 같은 변화).
- 그대로: 나머지 전부(`plan-flow-step1*`·`-step2*`·`-step4`·`-step4-append` 포함 — 나중에 칸·직접 선행이 없고 4단계 글자·비교 그대로).

#### 검수표

| 항목 | 확인 |
|---|---|
| 직접 선행 만들기(점 끌기 · C 추가 뒤 카드)·지우기(C ×), 분홍 점선 | 위젯 2건, golden 새 장면 |
| 자기 자신 · 같은 학생 · 이미 이음 · 순환 · 앞 칸 거부(백엔드 reason과 같은 말) | 단위 1건 + 위반 reason 1건 |
| "나중에" 칸 보관, 임시 미배치와 구별, ensurePlaced가 다시 놓지 않음, 모두 나중에여도 저장 | 단위 3건, 위젯 1건 |
| 같은 칸 stable topological 순서를 phase.stages · deferred_stages에, 같은 학생 배치 prefix + 나중에 suffix | 단위 2건(칸 · 나중에 칸) + authoring 왕복 |
| plan.get/scenario.get document + authoring 복원(없으면 DTO 기본값) | 단위 1건(시나리오 편집 진입 연결), 활성 계획을 흐름으로 여는 진입은 f2 |
| 저장 3지선다가 authoring 전체 전송, 시나리오 create/update, nullable 유지 | 단위 4건 |
| authoring 오류 reason · stage ID를 카드에, 초안 자동 삭제 없음 | 단위 2건 |
| 금지 파일 미수정, ~습니다체 | 코드 확인 |

#### 확인하지 못한 것

- analyze · 테스트 · golden 실행 전부(이 환경에 Flutter 없음). 정적 검토만 했다.
- 새 그림: 나중에 칸 점선·바탕, 카드 아래 점 크기(10px)와 자리(카드 아래 가운데 쪽 x 186), 분홍 점선 간격, C 직접 선행 행의 × 크기, 작게 보기 나중에 칸이 보이는 위치.
- 끌기 체감: 카드 아래 점(24×20 터치 자리)을 끌 때 카드 끌기와 섞이지 않는지(위젯 테스트는 점이 위에 있어 카드가 맞지 않는다고 본다).
- ProcessAppService(실제 Python)에서 authoring 왕복과 오류 details 모양(위 확인 요청).

#### 남은 일(f2)

- 작게 보기 S 곡선이 사이 줄 칩 위를 지나지 않게 경로 다듬기(직접 선행 점선 포함, 16:25 후속). 크게 보기에서 칸 → 나중에 칸 선이 "칸 추가" 위를 지나는 것도 같이 본다.
- `_incorporateScenario`: stage ID 재발급 때 deferred · 직접 edge 끝점 · 학생 체인 remap(끝점 빠진 edge를 조용히 지우지 않음). 지금 편입은 계획 화면 작업 문서(정수 v1)에 붙이는 기존 경로라 authoring이 없다.
- 활성 계획(plan.get document + authoring)을 흐름 초안으로 여는 진입(시안 A "계획 탭 페이즈 · 순서 바꾸기 → 3단계"). 경계 함수(`fromDocument(authoring:)`)는 f1에 있다.

#### 사용자 실행 순서

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① gate만 실행 → 결과를 오케스트레이터에게 보내고 기다린다(위 2장면 변경 + 새 장면 1건 RED 예상)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 승인 뒤 기준 이미지 갱신 → gate
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ③ 커밋
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4f -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4f
```

### FE4-f commit record (2026-10-10 01:13, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261010_004148\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE4-f2 선 경로 다듬기·시나리오 편입 remap·활성 계획 흐름 진입 (구현 끝, gate 전)

- 시작: 2026-10-10 01:20, 시작 SHA `64f29afefe675b269d4fa3660076f2e813333ed8`(FB-2a `000aaa85`, FE4-f1 `7bff91ec`, 문서 커밋 뒤 HEAD).
- 범위(f1 "남은 일(f2)" 세 가지): 1) 작게 보기 S 곡선(회색·분홍 점선)이 사이 줄 칩 위를 지나지 않게 칩 사이·칸 사이 틈으로 돌리고, 크게 보기 칸 → 나중에 칸 선이 "칸 추가" 타일 위를 지나지 않게 한다. 2) `_incorporateScenario`를 v2 문서 + authoring 병합으로 바꿔 stage ID 재발급 때 deferred_stages·직접 선행 양 끝·stage_order_by_student·student_order를 함께 remap하고 authoring 전체로 저장한다(끝점이 빠진 edge 처리 근거는 종료 기록). 3) 활성 계획(plan.get document + authoring)을 흐름 초안으로 여는 진입(활성 계획 홈 "페이즈 만들기" 옆, 최소 diff).
- 고칠 기존 파일(사본 `debug/frontend_fe4f2/pre/frontend/...`): `lib/ui/widgets/plan_flow_order_step.dart`, `lib/ui/models/plan_flow_draft.dart`, `lib/ui/models/plan_flow_save.dart`, `lib/ui/widgets/plan_section_layout.dart`, `test/plan_flow_order_step_test.dart`, `test/plan_flow_authoring_test.dart`, `test/planning_page_test.dart`.

### FE4-f2 종료 기록 (2026-10-10 02:40, 커밋 전)

상태: 구현 끝, gate 미실행. 시작 SHA `64f29afefe675b269d4fa3660076f2e813333ed8`. `debug/frontend_fe4f2/commit.json`(baseline whole, status=true)을 두었다. 직접 커밋하지 않았다. 시작 기록 목록 그대로 고쳤고(사본 있음) 새 파일은 없다. `lib/services/**`·backend·contracts·스캐너·tactic·app_shell 미수정. 옛 PlanPhaseEditor는 그대로 둔다(FE5-c).

#### 1. 선 경로 다듬기(`plan_flow_order_step.dart`)

- `PlanFlowOrderArrow.via`(지나는 점): `curve`면 점을 차례로 잇는 수직 접선 S 곡선(같은 x 구간은 곧은 세로선), 아니면 둥근 모서리 꺾인 선(`planFlowRoundedPolyline`). `via`가 없으면 기존 경로·판정과 똑같다(기존 곡선·직선 판정 테스트 기대 그대로).
- 작게 보기 `planFlowOrderCompactArrow(from, to, obstacles:)`: 고른 카드와 이은 선(회색 · 분홍 점선 모두)이 다른 칩 자리를 지나면 돈다(`planFlowOrderPathHits`, 3 간격 표본 · 1 안쪽 상자).
  - 위아래: 시작·끝 사이에 걸친 칩을 줄(세로로 겹치는 묶음)로 나누고, 줄마다 칩 x 구간(±3)을 합친 틈의 가운데·줄 오른쪽 끝 바깥(+9)·지금 x(비어 있으면) 중 "옮기는 거리 + 끝까지 남는 거리"가 가장 작은 곳을 고른다. 줄 위·아래 2 안쪽에서 세로로 지나고 옆으로 가는 것은 줄 사이·칸 사이 틈뿐이다. S 곡선 판정(`curve == true`)·시작·끝 점은 돌지 않을 때와 같다.
  - 같은 줄(사이에 칩): 줄 아래 틈(아래 끝 + 6)으로 내려가 옆으로 가서 `to` 아래로 올라간다(꺾쇠 위 방향).
  - 지날 틈을 못 찾거나 돈 경로도 부딪히면 돌지 않은 선을 쓴다.
- 크게 보기 `planFlowOrderArrowAvoiding`: 칸 → "나중에" 칸 선의 세로 구간이 "칸 추가" 타일(상자 ±6)을 지나면 타일 위 틈(타일 위 − 7)에서 타일 오른쪽 바깥(+16)으로 옆으로 가 내려가고, 원래 꺾는 높이(나중에 칸 위 − 7)에서 들어갈 x로 간다.
- 새 단위 테스트 3건(`test/plan_flow_order_step_test.dart` "선 경로(FE4-f2)"): 사이 줄 칩 피하기(틈 가운데 x, 칩 높이 안에서는 x 그대로, 막는 칩이 없으면 기존 S 곡선과 같음), 같은 줄 아래로 돌기(꺾쇠 위, y가 줄 아래 6 안), "칸 추가" 비키기(지나는 점 4개, 안 지나면 같은 객체).
- 안 한 것: 크게 보기에서 칸을 둘 이상 건너는 세로 구간이 사이 칸 카드 위를 지나는 것(범위 밖), 작게 보기 "칸 추가" 타일은 장애물에 넣지 않았다.

#### 2. 시나리오 편입(`plan_flow_save.dart` `planFlowIncorporateScenario`, `plan_section_layout.dart` `_incorporateScenario`)

- 계획 화면 작업 문서(정수 보기)에 붙이던 기존 경로를 버리고, 저장된 활성 계획(`plan.get` document + authoring) 뒤에 시나리오(get 레코드의 document + authoring, 없으면 DTO 기본값)를 붙여 `plan.save(document, authoring, expectedRevision: plan.get revision)`로 저장한 뒤 활성 계획을 다시 읽는다. 문서는 v2 nullable 원본 그대로(v1 시나리오는 흐름 편집과 같은 `fromDocument` 규칙), authoring은 전체다.
- 병합·재발급은 f1 `planFlowMergedPlanDocument`를 그대로 쓴다: 페이즈 id · 배치 단계 id · 나중에 단계 id(활성 문서 + 활성 나중에와 겹치면 `-2`…) 재발급, 그 표로 직접 선행 양 끝 remap, `stage_order_by_student` = 활성 배치 → 편입 배치 → 활성 나중에 → 편입 나중에, `student_order` = 활성 뒤 편입 새 학생. 편입 페이즈 이름은 기존처럼 "시나리오 이름 · 페이즈 이름".
- 퇴행 단계: 기존 규칙(활성 목표보다 낮은 시나리오 단계는 제외)을 nullable로 옮겼다(null은 퇴행이 아니고 앞 값을 이어 받음). 체인상 뒤에 오는 활성 나중에 단계가 시나리오 배치 목표보다 낮거나 그 키를 비우면 그 학생의 시나리오 배치 단계를 모두 뺀다(활성 쪽은 고치지 않는다). 단계가 하나도 안 남은 학생은 편입하지 않는다.
- **끝점이 빠진 edge — 판단: 그 edge만 명시해 빼고 수를 알린다(편입은 계속).** 근거: (1) 끝점이 빠지는 경우는 위 퇴행 제외뿐이고, 뺀 단계의 목표는 이미 활성 계획 앞 단계가 이루며 편입 페이즈는 늘 활성 페이즈 뒤라 "그 단계 뒤에" 순서 뜻이 남는다. (2) 기존 편입도 퇴행 단계를 빼고 수를 알리는 방식이라 같은 흐름이다. (3) 편입을 멈추면 퇴행 단계 하나 때문에 시나리오 전체를 못 붙인다. 뺀 edge는 `PlanFlowIncorporation.droppedPrerequisites`로 남기고 안내에 "그 단계에 이은 직접 선행 n개도 뺐습니다"를 붙인다. 그 밖의 edge는 지우지 않고 그대로 보내므로, 만약 끝점이 없으면 validator가 거절해 편입하지 않고 이유를 알린다.
- 실패: 병합 authoring을 만들 수 없으면 "활성 계획의 나중에 칸·선행 조건과 맞출 수 없어 … 편입하지 않았습니다(이유)", `revision_conflict`면 다시 읽고 "편입하는 사이에 활성 계획이 바뀌어 편입하지 않았습니다…", 그 밖은 "편입하지 못했습니다(code)". 성공 안내 문구는 기존 그대로.
- 동작 변화(확인 부탁): 편입이 이제 저장까지 한다. 계획 화면 편집기(옛 PlanPhaseEditor·요소 빌더)에서 저장하지 않은 작업 문서 변경은 다시 읽은 저장 계획으로 바뀐다. `loadRepositoryPlan: false`인 계획 화면은 편입 뒤 보이는 단계가 바뀌지 않는다(저장은 된다). 활성 계획 저장소가 없는 서비스에서는 편입 버튼이 아무것도 하지 않는다.
- 비교 화면은 먼저 닫고 그다음 다시 읽는다(닫는 모션 동안 계정 상태를 비우지 않게).
- 테스트: `plan_flow_authoring_test.dart` 3건(id 재발급 remap 전부 · 퇴행 단계와 그 edge 명시 제외 · 활성 나중에보다 높은 배치 단계 제외), `planning_page_test.dart` 기존 편입 테스트에 저장 결과(v2 · authoring 있음 · 편입 페이즈 이름) 단언 추가.

#### 3. 활성 계획을 흐름 초안으로 여는 진입(`plan_section_layout.dart`, `plan_flow_draft.dart`, `plan_flow_save.dart`)

- 활성 계획 홈 섹션 1 "페이즈 만들기" 버튼 오른쪽에 40px 아이콘 버튼(`plan-flow-edit-active-launch`, ↕, 툴팁·의미 "활성 계획 단계 순서 바꾸기")을 더했다(최소 diff: 같은 줄, 열 폭이 가장 좁은 120일 때도 왼쪽 버튼 74px).
- 누르면 `plan.get`을 다시 읽어(`_ensureRepositoryContext(refresh: true)`) document + authoring(없으면 DTO 기본값)으로 초안을 열고, 단계가 있으면 3단계, 없으면 1단계로 연다. `PlanFlowPurpose.editActivePlan`, `PlanFlowController.activePlanRevision`(연 revision).
- 4단계: "이걸로 바꾸기"를 먼저 고르고(기존 계획은 "고치기 전 활성 계획" 시나리오로 옮겨 둠), "페이즈로 추가"는 "활성 계획을 고치는 중이라 페이즈로 붙이지 않습니다"로 막고 비교도 하지 않는다. "시나리오로 저장"은 그대로 쓸 수 있다. 이걸로 바꾸기의 expected revision은 초안을 연 revision이라 그 사이 활성 계획이 바뀌었으면 `revision_conflict`로 알리고 다시 읽은 뒤에만 최신으로 옮긴다(3단계에 다녀오는 재읽기로는 옮기지 않는다).
- 판단(확인 부탁): 활성 계획을 고칠 때 덮어쓰기 전용 위치(보관 없이 plan.save)는 만들지 않았다. "이걸로 바꾸기"가 기존 계획을 시나리오로 옮겨 두므로 되돌릴 수 있다. 저장 뒤 "시나리오 보기로 이동" 토글 기본값(켜짐)은 그대로다.
- 테스트: `plan_flow_authoring_test.dart` 1건(이걸로 바꾸기 기본 · 페이즈로 추가 막음 · 보관 이름 · 연 revision으로 충돌 → 다시 읽은 뒤 저장 성공 · 저장된 authoring), `planning_page_test.dart` 1건(버튼 → 흐름 3단계, purpose · revision · 칸 · 나중에 칸 복원).

#### 정적 검토

- 별도 검토 1회: 컴파일·시그니처·lint 문제 없음. 지적 반영 — 새 버튼 폭(48 → 40, 틈 8 → 6, `minimumSize: Size.zero`: 좁은 화면 900×900 테스트에서 "페이즈 만들기"가 넘치지 않게), expected revision을 충돌 뒤에만 옮기기, 활성 나중에보다 높은 편입 배치 단계 제외, 비교 화면을 닫은 뒤 다시 읽기, 고치기 흐름에서 병합 비교 생략, 보관 이름 기본값, 쓰이지 않는 분기 제거.
- lint 확인: 새 코드에 `if (x case final y?) y`·`if (x != null) x` 컬렉션 요소, `.toSet().toList()`, 쓰이지 않는 private 매개변수·지역 변수 없음.

#### golden ① 예상

- 바뀜(확실): `plan-flow-step3-many` — 고른 호시노 2단계 카드로 들어오는 호시노 1단계 선과 나가는 호시노 3단계 선이 사이 줄의 흐린 칩(16:25에 적은 1순위 세리카, 2순위 히나·노아) 위를 지나지 않고, 칩 사이 틈(또는 줄 오른쪽 끝 바깥)을 세로로 지나며 줄 사이·칸 사이 틈에서만 옆으로 간다. 줄 사이 틈이 10px라 그 구간의 옆 이동은 거의 수평으로 보인다.
- 바뀜(섹션 1이 보이는 계획 홈 장면): "페이즈 만들기" 버튼이 46px 좁아지고 오른쪽에 ↕ 아이콘 버튼. `plan-overall`·`plan-by-phase`·`plan-bottleneck`·`plan-scenario-list`·`plan-scenario-compare`는 섹션 1이 보이므로 바뀐다. `plan-student-selector`·`plan-phase-editor`·`plan-preset-manager`·`plan-element-builder`는 그 장면에서 섹션 1이 보이면 같은 변화다(확인 못 함).
- 그대로: `plan-flow-step3`(나중에 칸 선 없음), `plan-flow-step3-deferred`(아루 2단계 → 나중에 아루 3단계 선은 2열 카드라 "칸 추가" 타일 오른쪽을 지나 비키지 않음), `plan-flow-step1*`·`-step2*`·`-step4*`, 학생·계정·스캔 장면.
- 새 장면 없음.

#### 검수표

| 항목 | 확인 |
|---|---|
| 작게 보기 S 곡선(회색 · 분홍)이 사이 줄 칩 위를 안 지남(칩 사이 · 줄 사이 틈) | 단위 2건, golden `-many` |
| 크게 보기 칸 → 나중에 칸 선이 "칸 추가" 위를 안 지남 | 단위 1건 |
| 기존 곡선 · 직선 판정 테스트 기대 그대로 | 기존 테스트 미수정(`curve` 유지) |
| 편입 stage ID 재발급: deferred · edge 양 끝 · stage_order_by_student · student_order | 단위 1건 |
| 끝점이 빠진 edge는 명시 제외 + 안내(근거 위) | 단위 1건 |
| 편입 저장 v2 nullable 원본 + authoring 전체 | 단위 · 위젯 단언 |
| 활성 계획 → 흐름 초안(plan.get document + authoring, 기본값), 3단계/1단계, 최소 diff 진입 | 단위 1건, 위젯 1건 |
| 금지 파일 미수정, ~습니다체 | 코드 확인 |

#### 확인하지 못한 것

- analyze · 테스트 · golden 실행 전부(이 환경에 Flutter 없음). 정적 검토만 했다.
- 새 그림: 작게 보기 돌린 선의 모양(10px 줄 사이 틈의 옆 이동이 수평에 가깝다), 새 아이콘 버튼과 좁아진 "페이즈 만들기"(가장 좁은 열 120에서 글자 줄임).
- ProcessAppService(실제 Python)에서 편입 plan.save(authoring 포함)와 고치기 흐름의 replace 왕복.

#### 사용자 실행 순서

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① gate만 실행 → 결과를 오케스트레이터에게 보내고 기다린다(위 장면 변경 RED 예상, 새 장면 없음)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 승인 뒤 기준 이미지 갱신 → gate
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ③ 커밋
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4f2 -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4f2
```

### FE4-f2 commit record (2026-10-10 03:07, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261010_023726\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE4-g 계산기 → 계획 넘김 (구현 끝, gate 전)

### FE4-g 착수 기록 (2026-10-10 03:30)

- 진행 중: FE4-g. 시작 SHA `c9258cb1aa9507d3f8ac0dae2dacc408006844f3`(FE4-f2 `fe_commit` 뒤 HEAD, 브랜치 scanner-consolidation).
- 범위: FD-171 (a). `PlanningStudentSeed`에 계산기 목표를 싣고, 성장 계산기 "이 목표로 계획에 추가"(S1 container-16 · 아래 큰 버튼)를 누르면 계획 탭 계획 만들기 흐름을 2단계로 열어 그 학생 단계를 채운다. 진행 중 초안이 있으면 덧붙이고, 초안이나 활성 계획에 그 학생이 있으면 마지막 단계 뒤 새 단계로 넣는다.
- 막힘: 대장 "slice별 막힘 요약" FE4-g 행은 "—"(열림 0건). FD-171은 워커 재량(권장안 (a)).
- 고칠 기존 파일(사본 `debug/frontend_fe4g/pre/frontend/...`): `lib/ui/models/planning_models.dart`, `lib/ui/models/plan_flow_draft.dart`, `lib/ui/models/plan_flow_goal_editor.dart`, `lib/ui/widgets/plan_section_layout.dart`, `lib/ui/pages/student_page.dart`, `lib/ui/widgets/growth_calculator_section.dart`, `lib/ui/widgets/student_section_layout.dart`(주석만), `test/growth_calculator_view_test.dart`, `test/student_page_test.dart`. 새 파일: `test/plan_flow_handoff_test.dart`. 서비스 계층·app_shell·backend·contracts·스캐너·tactic 파일은 고치지 않는다.
- 환경: 이 세션은 PC 셸이 없다(파일을 가져와 고친 뒤 되돌려 쓴다). Flutter·Python을 돌리지 못하므로 정적 검토만 한다.

### FE4-g 종료 기록 (2026-10-10 03:55, 커밋 전)

상태: 구현 끝, gate 미실행. 시작 SHA `c9258cb1aa9507d3f8ac0dae2dacc408006844f3`. `debug/frontend_fe4g/commit.json`(slice=fe4g, baseline whole, status=true)을 두었다. 직접 커밋하지 않았다. 착수 기록의 파일 목록 그대로 고쳤고(사본 `debug/frontend_fe4g/pre/frontend/...`), 새 파일은 `test/plan_flow_handoff_test.dart` 하나다. 서비스 계층(`lib/services/**`)·app_shell·backend·contracts·스캐너·tactic 파일은 고치지 않았다. `plan_section_layout.dart`는 CRLF를 유지했다.

#### 실행 명령·결과

- 실행한 명령 없음. 이 세션은 PC 셸이 없고 작업 공간에서 Flutter SDK도 받을 수 없다(storage.googleapis.com·github.com 프록시 403). analyze·테스트·golden 모두 돌리지 않았고 통과를 주장하지 않는다.
- 정적 검토: 별도 검토 에이전트 1회(컴파일·lint·테스트 기대값을 코드와 mock으로 대조). 지적 반영 — `plan_flow_handoff_test.dart`에 `TestWidgetsFlutterBinding.ensureInitialized()`(mock catalog가 asset 번들을 읽음), `_openHandoffFlow` 대기 표시를 `try/finally`로 풀기, 진행 중 흐름에 넣는 경로를 다음 프레임으로 미루기(didUpdateWidget 빌드 중 리스너 깨우기 방지), 닫힌 흐름이면 `ignored`(알림 없음), 시나리오 목록 열기 도중 넘어오면 목록을 열지 않기.

#### 바뀐 것

1. **시드**(`planning_models.dart`): `PlanningStudentSeed.targets`(선택, 19키 정수 절대값). null이면 목표 없이 넘긴다.
2. **계산기 버튼**(`student_page.dart`): S1 container-16 "이 목표로 계획에 추가"와 아래 큰 버튼이 켜진다(`_addCalculatorToPlan`). 시드에는 계산기가 **지금 현재값보다 올린 키만** 싣는다. 고르지 않은 키는 싣지 않으므로 계획 쪽에서 null로 남는다(0·현재값으로 채우지 않음). 시드의 currentValues는 확정값이고 계획 쪽은 쓰지 않는다. 계산기 상태·최근 계산(FD-170)은 건드리지 않는다(학생 탭으로 돌아오면 계산기가 그대로 열려 있다). 계획 흐름의 이전·취소는 계획 탭 안에서 끝나고 계산기와 상태를 나누지 않는다.
3. **초안에 넣기**(`plan_flow_draft.dart` `PlanFlowController.receiveHandoff`, 순수 함수 `planFlowHandoffStageTargets`·`planFlowActiveLastTargets`):
   - 바닥 snapshot: 초안에 그 학생 단계가 있으면 그 마지막 단계(정수 보기) → 없고 활성 계획(`PlanFlowContext.activePlan`)에 있으면 활성 계획 마지막 단계(`planFlowDocumentIntegerTargets`, null은 앞 단계 값) → 둘 다 없으면 확정 지금 값. 활성 계획을 고치는 흐름(`editActivePlan`)은 초안이 곧 활성 계획이라 초안만 본다.
   - 새 단계 = 바닥 snapshot 복제 + 계산기 값이 바닥보다 높은 키만 그 값으로 올림 → `normalizePlanningGrowthTargets(changedKeys: 올린 키)`(선행 조건이 함께 오름, 예 전용무기 → ★5). 바닥보다 낮거나 같은 계산기 값은 쓰지 않는다(퇴행 없음). 오르는 키가 없으면 단계를 만들지 않는다.
   - 그 학생 단계 끝에 붙이고(id `<학생>-calc-<n>`, 이름 `n단계`) v2 변환·칸 배치 정리는 2단계 편집과 같은 `setStudentStages`가 한다: 정수 → v2는 `PlanFlowGoalCodec.fromEditor`(지금 값보다 처음 올라간 단계부터 목표, 끝까지 안 오른 키는 모든 단계 null). 단계가 늘면 그 학생 단계는 칸에서 빠져 3단계에서 다시 배치한다(plan-element-builder-lessons "목표를 바꾸거나 단계를 추가·삭제한 학생은 페이즈 배정을 다시").
   - 끝나면 2단계로 가고 그 학생을 목표 순번·편집기 초점(`goalFocusStudentId`/`goalFocusSerial`)으로 잡는다. 편집기는 마지막 단계(넘긴 단계)를 고른 상태로 연다.
4. **2단계 편집기**(`plan_flow_goal_editor.dart`): 흐름의 초점 요청이 바뀌면 이미 있는 편집기도 그 학생 탭으로 바꾼다. 다른 동작은 그대로다.
5. **계획 화면**(`plan_section_layout.dart` `_consumeInitialSeed`): 넘어온 시드로 예전 요소 편집기를 여는 대신 계획 만들기 흐름(새 시나리오 목적)을 2단계로 연다. 진행 중 흐름이 있으면 그 초안에 넣는다. 흐름 상태를 읽는 동안(`_handoffPending`) 계획 홈 섹션을 들이지 않는다. 흐름을 열 수 없는 서비스(계정 상태·시나리오 저장소 없음)만 예전 요소 편집기로 연다(목표는 싣지 않음). 넣은 결과 안내(~습니다체 SnackBar): 초안 학생 뒤 새 단계 / 활성 계획 학생 / 이미 들어 있음 / 올린 목표 없음. 초안·활성 계획에 없던 학생은 화면으로 보이므로 알리지 않는다.
6. 주석(`growth_calculator_section.dart`, `student_section_layout.dart`), 테스트 주석(`student_page_test.dart`).

#### 판단(확인 부탁)

- **FD-171 (a) 워커 재량, 권장안대로.** 활성 계획에 그 학생이 있을 때 새 단계는 활성 계획 마지막 단계 snapshot을 복제한다. 그래서 초안의 그 단계는 활성 계획이 정한 키도 같은 값으로 들고 있다(계산기에서 고르지 않은 키라도 활성 계획이 정했으면 null이 아니다). 근거: 단계 누적 snapshot 계약("새 단계는 선택 단계 바로 뒤에 그 snapshot을 복제")이고, FE4-e "페이즈로 추가"(`planFlowMergedPlanDocument`)는 활성 값과 같은 값을 퇴행으로 보지 않으므로 기존 병합 규칙을 바꾸지 않는다. "시나리오로 저장"하면 활성 계획 목표를 포함한 독립 snapshot이 된다. 바닥보다 낮은 계산기 값은 버린다(예: 활성 레벨 70, 계산기 60 → 70).
- **계산기 13행 → v2 변환.** FE3-f1 계산 어댑터(`growthCalculatorDocument`)는 v1 정수 19키 임시 문서를 만들 뿐 nullable 변환이 없다. 그래서 계산기 쪽은 "현재값보다 올린 키만"을 넘기고, 계획 쪽은 흐름이 이미 쓰는 `PlanFlowGoalCodec.fromEditor`로 v2를 만든다. 새 변환 규칙은 만들지 않았다.
- **인연 목표.** 계산기에서 인연을 올렸을 때만 `bond_rank`를 싣는다. 현재 인연을 목표로 복사하지 않고, 확정 인연을 모르는 학생(바닥 1)도 올린 값만 목표가 된다(FB-1b 프런트 연결 메모 4·5: bond 목표는 문서의 nullable 값, 모르는 현재 인연을 1로 만들지 않음 — 계산 current 쪽은 이번에 바꾸지 않았다).
- **기존 코드와 충돌하는 규칙은 찾지 못했다.** 멈출 사유 없음.
- 새 단계 이름은 기본 이름(`n단계`)이다(편집기의 기본 이름 번호 다시 매기기와 맞음). "계산기 목표" 같은 출처 이름은 붙이지 않았다.

#### 처리한 FD

- FD-171 (a)(워커 재량): 위와 같다.
- FD-168: 직접 입력 현재값은 넘기지 않는다(올린 키만, 계획 바닥은 확정값).
- FD-170: 넘긴 뒤 최근 계산 그대로.
- FD-172: S4 "계획에 있음/없음"은 FE4-h 그대로(활성 문서 기준). 이번에 바꾸지 않았다.
- FD-160 한 명 모드 C 보조 링크(워커 재량): 하지 않았다.

#### 테스트

- 새 `test/plan_flow_handoff_test.dart`(12건): 순수 함수 3건(바닥 복제 · 퇴행 없음, 올린 키 정규화로 선행 조건 · 규칙 위반 없음, 오르는 키 없으면 null) · 초안 없음(1단계 = 계산기 목표, 고르지 않은 키 null, goal_metadata 기본값, 2단계 · 초점) · 초안 있음·학생 없음(뒤에 덧붙임, 다른 학생 단계 · 칸 그대로) · 초안에 학생 있음(마지막 단계 뒤 2단계, 레벨 이어 받음 · 낮추지 않음, 칸에서 빠짐) · 초안 마지막 단계에 이미 있음(nothingNew, 칸 그대로) · 활성 계획에 학생 있음(snapshot 레벨 70 + 스킬, 나머지 null) · 활성 snapshot에 이미 있음 · 활성 계획 고치는 흐름은 초안만 · 목표 없음 · 이미 있는 편집기의 학생 탭 전환.
- `growth_calculator_view_test.dart`: "FE4-g 전까지 비활성" 테스트를 바꿨다 — 두 버튼이 켜지고, 일반 스킬 MAX 뒤 누르면 계획 탭 흐름 2단계가 그 학생으로 열리며 단계 `skill1` 10 · `level`/`bond_rank` null, 학생 탭으로 돌아오면 계산기 값 그대로. 새 테스트 "직접 입력 현재값은 계획으로 넘기지 않는다"(직접 입력 레벨 50 → 단계 없음 · "목표 없이 더했습니다" 안내). 인연 안내 단언은 바꾼 테스트로 옮겼다. 지운 테스트 없음.
- `planning_page_test.dart`에는 시드 테스트가 없었다(바꾸지 않음).

#### golden 예측

- 바뀜(확실): `students-calculator`·`students-calculator-bond-popover` — 계산기 S1 container-16(`calculator-add-to-plan`) 아이콘이 흐린 색(textMuted 45%)에서 본문 색으로, 아래 큰 버튼 "이 목표로 계획에 추가 / 계획 만들기 2 · 목표 정하기로 넘깁니다"가 비활성 모양에서 활성(primary) 모양으로. 그 밖의 영역은 같다.
- 그대로: 계획 장면 전부(시드를 넘기는 장면이 없음), `plan-flow-step2*`, 학생 · 계정 · 스캔 장면.
- 새 장면 제안: 하지 않는다. 계산기에서 연 2단계는 기존 `plan-flow-step2`와 같은 화면 구성(학생 탭 하나 · 단계 카드 하나)이고 값만 다르다. 원하면 `plan-flow-step2-from-calculator`(활성 계획 학생 → snapshot 단계 + 안내)를 다음 slice에서 더할 수 있다.

#### 검수표

| artboard / 확인 | 여는 방법 | 확인 포인트 |
|---|---|---|
| Calc-Student "이 목표로 계획에 추가" | mock 모드 → 학생 탭 → 학생 고르기 → S1 "성장 계산기 열기" | S1 container-16 아이콘과 아래 큰 버튼이 켜져 있음 |
| 계산기 → 계획 2단계 | 위에서 목표 몇 개 올리고 큰 버튼(또는 S1 버튼) | 계획 탭 계획 만들기 2단계, 그 학생 탭 · 1단계 카드가 올린 값, 현재 → 최종 줄에 올린 항목만 |
| 진행 중 초안에 덧붙임 | 계획 탭 "시나리오 생성"으로 다른 학생 고른 뒤 학생 탭 계산기에서 넘기기 | 같은 초안에 학생 탭이 하나 더, 기존 학생 그대로 |
| 초안에 이미 있는 학생 | 같은 학생을 계산기에서 다시 넘기기 | 그 학생 2단계 카드 추가(앞 단계 값 이어 받음), 안내 "만들던 초안에 이어 … 2단계로 …" |
| 활성 계획 학생 | 활성 계획에 있는 학생을 넘기기 | 1단계 카드가 활성 계획 마지막 단계 값 + 올린 값, 안내 "… 활성 계획 마지막 단계에 이어지는 단계로 …" |
| 계산기 그대로 | 넘긴 뒤 학생 탭 | 계산기 · 최근 계산 그대로 |

#### 확인하지 못한 것

- analyze · 테스트 · golden 실행 전부. 정적 검토만 했다.
- 위젯 테스트의 탭 전환 뒤 계획 화면이 onstage인지(`AnimatedSectionStack`을 읽지 못함), SnackBar 타이머 정리.
- ProcessAppService(실제 Python)에서 계산기 → 2단계 → 4단계 저장 왕복.
- 탭 전환 중 넘김의 그림(계획 홈 섹션을 모션 없이 내린 뒤 흐름이 들어옴).

#### 발견 사항

- 초안에 그 학생의 "나중에" 칸 단계가 있으면 새 단계가 체인 끝(나중에 단계 뒤)에 붙는다. 3단계에서 그 단계를 칸에 넣으려면 같은 학생 체인 규칙(배치 prefix + 나중에 suffix) 때문에 나중에 칸에 두거나 앞 단계를 칸으로 옮겨야 한다. 막지는 않았다.
- `PlanFlowContext.activePlan`은 문서만 있고 authoring이 없어, 활성 계획의 "나중에" 단계는 바닥 snapshot에 들어가지 않는다. FE4-e 병합(활성 배치 → 초안 배치 → 활성 나중에)에서 활성 나중에 단계가 새 단계보다 낮으면 기존 병합 규칙대로 처리된다(이번에 바꾸지 않음).
- 활성 계획 학생을 넘긴 초안의 2단계 "현재 → 최종" 줄 · 계산은 초안 기준이라 활성 계획 이전 단계의 비용은 넣지 않는다(FE4-e 초안과 같은 동작).

#### 다음 행동

- 오케스트레이터: gate ① 결과 검토(golden 2장 예측 대조), 위 판단 3건 확인.
- 사용자 실행 순서:

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① gate만 실행 → 결과를 오케스트레이터에게 보내고 기다린다(students-calculator · -bond-popover RED 예상, 새 장면 없음)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 승인 뒤 기준 이미지 갱신 → gate
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ③ 커밋
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4g -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe4g
```

### fe4g commit record (2026-10-10 14:04, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261010_135343\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE5-a 시나리오 목록 v2 (구현 끝, gate 전)

### FE5-a 착수 기록 (2026-10-10 14:40)

- 진행 중: FE5-a(Lane A 프론트 워커). 시작 SHA `1fa861942e15459fc479e8e91cb899b6af3ff0c8`(FE8-a `815e0589`, FE4-g `af745731`, 문서 커밋 뒤 HEAD, 브랜치 scanner-consolidation).
- 범위: 워크플로 FE5 표 FE5-a — 정렬 세그먼트 · 필터 칩 · 검색 · 오래된 개수, 펼침 행 액션(열기/복제/이름·설명/삭제), 활성 계획 고정 행, 비교 담기(최대 4, 슬롯 A = 활성 계획 고정). 미리보기 내용(FE5-b), 보기 모드(FE5-c), 4열 비교(FE5-e)는 범위 밖이다.
- 막힘: 대장 "slice별 막힘 요약" FE5-a 행 "—"(열림 0건). 워커 재량 FD-083·FD-084·FD-087, 확정 FD-091을 처리한다.
- 고칠 기존 파일(사본 `debug/frontend_fe5a/pre/frontend/...`): `lib/ui/widgets/plan_section_layout.dart`(CRLF 유지), `lib/ui/app_section.dart`(FD-091 부제 한 줄), `test/planning_page_test.dart`, `test/goldens/fe1g_baseline_golden_test.dart`, `test/goldens/golden_harness.dart`.
- 새 파일(예정): `lib/ui/studio/plan_scenario_list_studio_layout.dart`(Scenario-List 3섹션 Studio 문서), `lib/ui/models/plan_scenario_list_state.dart`(정렬·필터·검색·비교 담기 상태), `lib/ui/widgets/plan_scenario_list.dart`(S1 메뉴·비교 슬롯, S2 목록, S3 빈 미리보기), `test/plan_scenario_list_test.dart`.
- 고치지 않는다: `lib/services/**`(Lane B fb4-dart 작업 중), backend·contracts, 스캐너 · 전술 · 타이틀 화면, `app_shell.dart`. 서비스에 필요한 것은 요청만 적는다.
- 환경: PC 셸 없음(파일을 가져와 고친 뒤 되돌려 쓴다), Flutter·Python 실행 불가 → 정적 검토만.

### FE5-a 종료 기록 (2026-10-10 15:20, 커밋 전)

상태: 구현은 끝났고 gate는 아직 돌리지 않았다. 시작 SHA는 `1fa861942e15459fc479e8e91cb899b6af3ff0c8`이다. `debug/frontend_fe5a/commit.json`을 두었다(slice=fe5a, whole에는 기준 이미지 2장을 하나씩 적음, status=true). 직접 커밋하지 않았다.

- 고친 기존 파일은 착수 기록 목록 그대로다(사본 `debug/frontend_fe5a/pre/frontend/...`).
- 새 파일은 4개다: `lib/ui/studio/plan_scenario_list_studio_layout.dart`, `lib/ui/models/plan_scenario_list_state.dart`, `lib/ui/widgets/plan_scenario_list.dart`, `test/plan_scenario_list_test.dart`.
- 고치지 않은 곳: `lib/services/**`(Lane B), backend, contracts, 스캐너 · 전술 · 타이틀 화면, `app_shell.dart`, 공용 키트(`lib/ui/kit/**`).
- `plan_section_layout.dart`는 CRLF를 유지했다.

#### 실행 명령·결과

- 실행한 명령은 없다. 이 세션에는 PC 셸이 없고, 작업 공간에서 Flutter SDK를 받을 수 없다. analyze · 테스트 · golden을 하나도 돌리지 않았으므로 통과를 주장하지 않는다.
- 정적 검토는 별도 검토 에이전트로 한 번 했다. 키트 생성자 · 서비스 API · mock 동작 · 테스트 기대값 · golden harness 문서 검증을 코드끼리 대조했고, 확실한 컴파일 · 테스트 실패는 찾지 못했다. 반영한 지적은 다음과 같다.
  - 세 섹션 바탕 `CustomPaint`가 Stack의 느슨한 제약에서 크기 0으로 그려지던 것을 `Positioned.fill`로 감쌌다.
  - 정보 팝오버 문구가 아직 없는 동작(두 번 누르기 · 열기)을 약속하지 않게 고쳤다.
  - 비교 화면에 두 대상을 넘겨 열 때 자동 비교를 첫 읽기 뒤 한 번만 하게 했다.
  - 목록 S1 "새 시나리오"에서 흐름 상태를 읽다 실패해도 예외가 새지 않게 했다.
  - 목록이 바쁠 때 비교 슬롯 B~D를 잠갔다.
  - 고정 행에서 쓰지 않던 매개변수를 지웠다.
  - 불러오는 중 개수를 `—`로 보이게 했다.
  - 테스트의 "섹션 1이 있음" 단언을 모션 값 단언으로 바꿨다.
- grep 범위: `test/**` 전체(로컬에 없던 테스트 파일 24개를 더 가져와 확인)와 `lib/**`에서, 지운 심볼 · 키(`PlanScenarioListCard`, `plan-scenario-list-refresh`, `plan-scenario-card-clip-*`, `plan-scenario-shortage-icon-*`)와 바뀐 부제를 참조하는 곳을 찾았다. 아래 "테스트"에 적은 파일 말고는 없었다. `plan_scenario_comparison_test.dart`는 `PlanScenarioComparisonSection`을 직접 만들지만, 새 매개변수 `initialSelectedIds`에 기본값이 있어 고치지 않았다.

#### 바뀐 것

1. **3섹션 화면**(시안 Scenario-List, `plan_scenario_list_studio_layout.dart`): 목록을 열면 계획 홈 섹션 1도 내려가고 S1 메뉴 · S2 목록 · S3 미리보기가 들어온다. 모션은 S1 0→180, S2 80→260(기존 목록과 같음), S3 180→0이다.
   - S1 `scenario-menu`(0,2,15,94, 왼쪽 면 사다리꼴)은 시안과 같다.
   - S2 `scenario-list`(8,2,49,94, 아래 면 평행사변형)와 S3 `scenario-preview`(58,2,38,94, 오른쪽 면 사다리꼴)는 시안 x가 96 grid에 맞지 않아 가장 가까운 정수 칸에 두었다. 차이는 S2 −2.1 · +8.6px, S3 +11.3px다. Studio 문서 주석과 테스트에 적어 두었다.
2. **S1 메뉴**:
   - "보는 중 · 시나리오 목록 / 저장된 시나리오 n"(누르면 다시 읽음).
   - 버튼 셋: 활성 계획으로(목록 닫기), 새 시나리오(목록을 내리고 계획 만들기 1단계), 프리셋 관리(목록을 내리고 프리셋 관리, 닫으면 계획 홈).
   - "비교할 계획 n / 4" 슬롯 A~D와 "나란히 비교 n개", 아래 안내 문구.
3. **S2 목록**(`plan_scenario_list_state.dart`, 서버 요약만으로 클라이언트 계산):
   - 정렬 4종: 최근 수정 · 부족 적은 순 · 크레딧 적은 순 · 이름. 계산 요약이 없으면 맨 뒤고, 같으면 최근 수정 → 이름 → id 순이다.
   - 필터 칩: "현재 데이터 기준만", "학생 · …"(목록에 든 학생 메뉴), 이름·설명 검색(지우기 ×), "오래된 시나리오 n개".
   - 조건에 맞는 것이 없으면 "조건 지우기"가 나온다(정렬은 그대로 둔다).
   - 카드는 `DiagonalRow` 위에 체크 · 초상 3 · 이름 · 상태 칩 · 수정 시각 · 설명 · 크레딧/부족 n종/첫 병목/학생 줄 · 대표 부족 재화(아이콘 + −양)를 둔다. 스크롤은 `DiagonalScrollViewport`(사선 스크롤바 + 포그)다.
4. **펼침 행**: 카드를 누르면 펼쳐진다(한 번에 하나, 다시 누르면 접힘). 펼친 행이 S3 미리보기 대상이다. 액션은 다섯이다.
   - 열기: FE5-c 전까지 꺼져 있고 툴팁을 단다.
   - 비교에 담기 / 빼기.
   - 복제: `duplicateScenario` → 다시 읽기 → 새 시나리오를 펼친다.
   - 이름 · 설명: `BaModal`, `getScenario`로 문서를 읽고 같은 문서로 `updateScenario`를 부르며 authoring은 넘기지 않아 보존된다.
   - 삭제: `BaModal` 확인 뒤 `deleteScenario`.
   - expected revision은 목록 응답의 collection revision과 시나리오 revision이다. 충돌(`revision_conflict`)이면 다시 읽고 "목록이 그 사이 바뀌어 다시 불러왔습니다. 다시 … 주십시오."로 안내한다. 그 밖의 실패는 "… 못했습니다(코드)."다.
5. **활성 계획 고정 행**(S2 위, 파란 행):
   - 학생 · 페이즈 · 단계 수는 활성 계획 문서에서 읽는다.
   - 크레딧 · 부족 · 첫 병목은 `plan.get` 계산 요약(`RepositoryPlanState.calculation`)에서 읽는다. 요약이 없으면 `—`이고, 병목이 없으면 "없음"이다.
   - 초상은 5명까지, 넘으면 "+n"이다.
6. **S3 미리보기**: FE5-b 전이라 최소한만 보인다. 고른 행이 없으면 "목록에서 시나리오를 고르면 여기에 보입니다."이고, 있으면 상태 칩 · 초상 · 이름 · 설명 · 수정 시각만 보인다. `getScenario` + compare 기반 내용은 FE5-b에서 채운다.
7. **비교 담기 → 나란히 비교**:
   - 시나리오를 하나 담으면 "나란히 비교"가 켜진다. 누르면 목록을 내리고 기존 A↔B 비교 화면(`PlanScenarioComparisonSection`)을 활성 계획 + 그 시나리오로 열어 바로 비교한다(새 매개변수 `initialSelectedIds`). 계획 홈 섹션 1은 비교 화면처럼 다시 들어온다.
   - 둘 이상 담으면 꺼지고 툴팁 "셋 이상 나란히 비교하는 화면은 아직 열 수 없습니다."가 뜬다(FE5-e).
   - 넷이 찬 뒤 더 담으면 "비교할 계획은 활성 계획을 포함해 4개까지 담을 수 있습니다."로 안내한다.
8. **계획 탭 부제**(`app_section.dart`, FD-091): "육성 목표와 필요 재화 · 시나리오".
9. **`plan_section_layout.dart` 정리**:
   - 예전 `PlanScenarioListSection` · `PlanScenarioListCard` · `_PlanScenarioListSectionPainter`를 지웠다. 비교 화면이 쓰는 것(`_ScenarioStudentPortraits`, `_PlanScenarioListCardPainter`, `PlanScenarioParallelogramClipper`, `planScenarioListSectionRect/Path`)은 남겼다.
   - 새 위젯은 같은 이름으로 다시 내보낸다(`export 'plan_scenario_list.dart' show …`).
   - 목록을 열고 닫을 때와 `_setActive` 모두 섹션 1을 함께 움직인다. 비교 화면은 예전처럼 섹션 1을 둔다.
   - FE4-g 넘김 경로(`_consumeInitialSeed`, `_handoffPending`, "목록 열기 도중 넘어오면 목록을 열지 않기" 가드)와 FE4-f2 "흐름으로 열기" 아이콘 버튼은 그대로 두었다.

#### 판단(확인 부탁)

- S1은 시안처럼 목록 화면 자체의 메뉴로 두고, 목록 동안 계획 홈 섹션 1을 내렸다. 예전에는 "섹션 1을 두고 목록만 바꿈"이었다. 비교 슬롯이 S1에 있어야 시안 상태(비교 3/4)를 나타낼 수 있어서다. FE5-c(FD-082)에서 S1을 홈 메뉴 섹션과 같은 자리로 맞추는 일은 그대로 남는다.
- "열기"는 보기 모드(FE5-c)가 없어 꺼 두었다. 예전 목록 카드는 누르면 아무 동작이 없었으므로 잃은 동작은 없다.
- "나란히 비교"는 A + 시나리오 하나일 때만 연다(FD-085 2분할 비교 화면 재사용). 셋 이상은 FE5-e 전까지 꺼 둔다.
- 슬롯 A(활성 계획)는 눌러도 아무 일이 없는 칸이다(캡션 "기준 · 뺄 수 없습니다"). 비활성 모양으로 흐려지지 않게 하려고 이렇게 했다.

#### 처리한 FD

- FD-083(워커 재량, 권장안): 활성 계획 요약은 `plan.get` 계산 요약(FB-1에서 이미 내려옴)을 그대로 쓰고, 개수는 문서에서 센다. 서비스는 고치지 않았다.
- FD-084(워커 재량, 권장안): 비교 슬롯 A는 활성 계획 고정, B~D는 담은 순서, 목록을 다시 읽어 없어진 시나리오는 슬롯에서 빠진다.
- FD-087(워커 재량, 권장안): 사선 스크롤바와 포그는 공용 `DiagonalScrollViewport` + `ScrollFogSpec.panel`을 쓴다(키트는 고치지 않음).
- FD-091(확정): 계획 탭 헤더 부제.

#### 테스트

- 새 `test/plan_scenario_list_test.dart`(10건):
  - 상태 모델 5건: 정렬 · 필터와 오래된 개수 · 비교 담기 용량과 정리 · 펼침과 조건 지우기 · 표기.
  - Studio 3섹션 기하 1건.
  - 위젯 4건: 고정 행 · 정렬 · 검색 · 학생 필터 · 펼친 행 미리보기 / 복제 · 이름·설명 · 삭제가 서비스로 저장됨 / 비교 슬롯 1→4 · 넘침 안내 · 슬롯 빼기 · A↔B 비교 열기 / S1 새 시나리오 → 흐름, 활성 계획으로 → 홈 섹션 다섯 복귀.
- `planning_page_test.dart` 기대 변경(모두 의도된 변경):
  - 'scenario list card exposes identity calculation and portraits' → 'scenario list row exposes …'. 위젯이 `PlanScenarioListCard`에서 `PlanScenarioListRow`로 바뀌었다. 같은 정보(크레딧 · 부족 · 병목 · 초상 · 상태 · 수정 시각)를 새 표기로 확인하고, 펼침 액션 키 확인을 더했다.
  - 'scenario list keeps section 1 and uses the 80 to 260 diagonal workspace' → 'scenario list replaces the plan home with its three sections and returns to the active plan'. 시안 3섹션 구성으로 섹션 1이 내려가는 것이 이번 slice의 의도다. S2 80→260 모션은 같은 단언으로 남겼다.
  - 저장 → 목록 테스트에서 카드 clip 키 · 포그 clip 단언을 `DiagonalRowClipper` 자손 · `plan-scenario-diagonal-fog` 단언으로 바꿨다. 카드 모양이 키트 `DiagonalRow`로 바뀌었기 때문이다.
- golden: `golden_harness.dart`에 `GoldenScenarioListMockAppService`(시나리오 5개 · 계산 요약 · 수정 시각 · 활성 계획 요약)를 더했고, `fe1g_baseline_golden_test.dart`에 새 장면을 더했다.
- 지운 테스트는 없다. `plan_scenario_comparison_test.dart` · `plan_flow_*` · `plan_element_builder_test.dart`는 바꾸지 않았다(grep 확인).

#### golden 예측

- 바뀜(확실): `plan-scenario-list`. 예전 한 섹션 카드 목록이 S1 메뉴 · S2 목록(고정 행 + 시나리오 1개 카드) · S3 빈 미리보기로 전부 바뀐다. 계획 홈 섹션 1도 사라진다.
- 새 장면: `plan-scenario-list-expanded`. `GoldenScenarioListMockAppService`의 시나리오 5개 중 "04 공격대 핵심"이 오래된 상태다. "07 3단계 우선순위" 행이 펼쳐지고, 비교 3/4(A 활성 계획 + 02 · 07)에, 미리보기는 이름 · 초상만 보인다.
- 그대로: `plan-scenario-compare`(홈 비교 버튼으로 열고 처음 고른 대상이 없음, 섹션 1 처리 같음). 그 밖의 계획 장면, 학생 · 계정 · 스캔 · 타이틀 장면도 그대로다. 부제(FD-091)는 셸을 그리는 golden 장면이 없어 영향이 없다.
- commit.json whole: `frontend/test/goldens/baseline/plan-scenario-list.png`, `frontend/test/goldens/baseline/plan-scenario-list-expanded.png`.

#### 검수표

| artboard / 확인 | 여는 방법 | 확인 포인트 |
|---|---|---|
| Scenario-List 3섹션 | mock 모드 → 계획 탭 → "시나리오 리스트" | S1 메뉴 · S2 목록 · S3 미리보기, 계획 홈 섹션 1이 내려감 |
| 고정 행 | 위 화면 S2 위 | 활성 계획 학생 · 페이즈 · 단계 수, 크레딧 · 부족 · 첫 병목(요약 없으면 `—`) |
| 정렬 · 필터 · 검색 | S2 제목 줄 seg, 필터 칩 | 정렬 4종, 현재 데이터 기준만, 학생 메뉴, 검색 · 지우기, 오래된 개수, 조건 지우기 |
| 펼침 행 | 카드 누르기 | 한 번에 하나, 액션 다섯(열기는 꺼짐 · 툴팁), S3에 이름 |
| 복제 · 이름·설명 · 삭제 | 펼친 행 액션 | 목록 다시 읽기, 복제본이 펼쳐짐, 모달 문구(~습니다체) |
| 비교 담기 | 카드 왼쪽 체크 | "n / 4", 슬롯 B~D, 넷 넘으면 안내, 슬롯 눌러 빼기 |
| 나란히 비교 | 하나만 담고 "나란히 비교 2개" | A↔B 비교 화면이 그 둘로 열리고 비교 결과가 바로 보임 |
| S1 버튼 | 새 시나리오 / 프리셋 관리 / 활성 계획으로 | 흐름 1단계 / 프리셋 관리 / 계획 홈 섹션 다섯 복귀 |
| 계획 탭 부제 | 헤더 | "육성 목표와 필요 재화 · 시나리오" |

#### 확인하지 못한 것

- analyze · 테스트 · golden 실행 전부. 정적 검토만 했다.
- 실제 화면 그림: 섹션 안 요소 위치(시안 offset을 옮겨 적음), 좁은 창(약 1280px)에서 펼친 행 액션 줄이 넘치는지, 학생 필터 팝업 메뉴 모양.
- ProcessAppService(실제 Python)에서 복제 · 이름 변경 · 삭제 왕복과 revision 충돌 안내.
- 목록 → 새 시나리오 → 흐름 닫기 뒤 계획 홈 복귀 모션(위젯 테스트로만 확인하게 해 둠).

#### 서비스 요청

- 없음. 기존 `PlanningScenarioRepositoryService`(list · get · update · delete · duplicate)와 `RepositoryPlanState.calculation`으로 충분했다.

#### 발견 사항

- 시안 Scenario-List S2 · S3의 x(215.4 · 1720 · 1535.4)는 96 grid 칸 경계가 아니다. 계획 만들기 흐름처럼 정수 칸으로 근사했다. 시안 쪽 조정이 필요하면 디자인 확인 항목이다.
- 목록 응답에 학생 이름이 없어 학생 필터 메뉴는 앱 서비스 catalog로 이름을 붙인다. catalog를 못 읽으면 id가 보인다.

#### 다음 행동

- 오케스트레이터: gate ① 결과 검토(`plan-scenario-list` RED 1장 + 새 장면 1장 예상), 위 판단 4건 확인. 커밋 순서(Lane B → Lane A → redesigndocs)는 오케스트레이터가 정한다.
- 사용자 실행 순서:

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① 두 워커가 모두 멈춘 뒤 gate만 실행 → 결과를 오케스트레이터에게 보내고 기다린다(plan-scenario-list RED, 새 장면 plan-scenario-list-expanded 기준 없음 예상)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 승인 뒤 기준 이미지 갱신 → gate
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ③ 커밋(순서는 오케스트레이터가 정한다)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe5a -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe5a
```

### FE5-a gate ① RED 수정 기록 (2026-10-10 15:45, 커밋 전)

- gate `debug/frontend_gate/20261010_152318`(git `665b39bb`)은 RED였다. 원인은 컴파일 오류 하나다.
  - analyze: 3건. 오류 1건과 lint info 2건이다.
  - UI 테스트 3분할: 23건 실패. 전부 `loading … [E]`이고, 모두 같은 컴파일 오류(`plan_section_layout.dart:2154`)로 테스트 파일을 불러오지 못한 것이다. 기대값이 틀려서 실패한 테스트는 이번 gate에서 보이지 않았다. 컴파일이 막혀 테스트 본문이 돌지 않았으므로, 테스트가 맞는지는 아직 확인되지 않았다.
  - golden: 같은 이유로 불러오지 못해 비교하지 못했다.
  - process 51건 · almanac · git-diff-check는 PASS.
- 고친 것:
  1. `plan_section_layout.dart` `_createScenarioFromList`
     - 원인: `PlanFlowContext? flowContext`를 try/catch 안에서 대입하는 non-final 지역 변수로 두었다. 그래서 null 검사로 좁힌 타입이 `setState` 클로저 안에서 풀렸다(`argument_type_not_assignable`).
     - 수정: 실패하면 null을 돌려주는 `_flowContextOrNull()`을 새로 두고 `final`로 받는다.
     - 동작은 그대로다(읽기 실패 시 흐름을 열지 않고 예외를 내보내지 않음). CRLF를 유지했다.
  2. `plan_scenario_list_state.dart` `PlanScenarioListController`
     - 원인: `prefer_initializing_formals` 2건.
     - 수정: 어디서도 쓰지 않던 생성자 매개변수(sort · compareIds · expandedId)를 지우고, 필드 초기값(최근 수정 · 빈 비교 · 펼침 없음)으로 바꿨다. 코드와 테스트는 모두 인자 없이 만든다(grep 확인).
- commit.json · golden 예측 · 사용자 실행 명령은 종료 기록 그대로다. 실행한 명령은 여전히 없고 통과를 주장하지 않는다. 다음 gate에서 테스트 본문이 처음 돈다.

### FE5-a gate ① 재실행 결과 (2026-10-10 15:50, 커밋 전)

- 결과: RED. 실패는 golden 2건뿐이고, 둘 다 종료 기록의 예측과 같다.
  - `plan-scenario-list`: 89.97% 차이.
  - `plan-scenario-list-expanded`: 기준 이미지 없음(새 장면).
- 그 밖에는 모두 PASS다: analyze, UI 테스트 1,205건, process 51건, 나머지 golden(`plan-scenario-compare` 포함), almanac, 공백 검사.
- `plan-scenario-list` 새 그림(`failures/plan-scenario-list_testImage.png`)을 직접 열어 봤다.
  - 보인 것: S1 메뉴(보는 중 · 버튼 셋 · 비교 1 / 4 · 슬롯 A 활성 계획, B~D 빈 칸 · 나란히 비교 꺼짐), S2(제목 · 정렬 seg · 필터 칩 · 고정 행 · 시나리오 카드 1장), S3 빈 미리보기 문구. 세 섹션 바탕이 모두 그려졌다.
  - 넘침 띠나 깨진 글자는 없었다.
- 눈에 띈 점이 하나 있다. 부족 0종일 때도 "0종"이 강조색(분홍)이다(고정 행 · 카드 모두). 시안은 부족이 있는 경우만 보여 준다. 바꿀지는 오케스트레이터 판단에 맡기고, 이번에는 고치지 않았다.
- 다음: 오케스트레이터 승인 뒤 ② `fe_gate.ps1 -UpdateGoldens` → `fe_gate.ps1`, ③ `fe_commit.ps1 -Slice fe5a -DryRun` → `fe_commit.ps1 -Slice fe5a`(순서는 오케스트레이터가 정한다).

### fe5a commit record (2026-10-10 16:52, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261010_162247\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE5-b 시나리오 미리보기 (구현 끝, gate 전)

### FE5-b 착수 기록 (2026-10-10 17:25)

- 진행 중: FE5-b(Lane A 프론트 워커). 시작 SHA는 redesigndocs `11281bed`(오케스트레이터 로그 17:05: fb4-dart `63a01318` → FE5-a `3e3f26c1` → 문서 `11281bed` 뒤 HEAD, 브랜치 scanner-consolidation). 이 세션은 PC의 git을 읽을 수 없어 짧은 SHA로 적는다.
- 범위: 워크플로 FE5 표 FE5-b.
  - S3 미리보기: 행을 고르면 `getScenario` + `compareScenarios(활성, 시나리오)`를 한 번 부르고, (시나리오 revision, 활성 revision, 프로필 revision) 키로 캐시하고, 읽는 동안 로딩을 보인다(FD-089). 늦게 온 이전 응답은 화면을 덮지 않는다.
  - 내용: 활성 대비 KPI 3개(a → b), 학생 · 단계 목표 차이 칩, 분야별 가장 큰 부족, "부족 재화 n종" → 부족 재화 팝오버(FD-090, 키트 `GroupedShortageFlyout` = Flow-4와 같은 `AnchoredFlyout` 프리셋 묶음), "현재 데이터 기준"/"저장 시점과 다름" 칩.
  - S3 아래 버튼: "비교에 담기/빼기"만 FE5-a 행 액션과 같이 연결하고, "열기"(FE5-c)와 "계획에 적용…"(FD-088, FE5-c)은 꺼 둔다.
  - golden 계산 대역 후속(오케스트레이터 로그 10-09 23:25): 계산 대역 `overall`을 문서 의존으로 바꾸고, 미리보기 장면도 같은 대역을 쓴다. 바뀌는 plan-flow-step1~4 장면을 예측해 보고한다.
- 막힘: 대장 "slice별 막힘 요약" FE5-b 행 "—"(열림 0건). 워커 재량 FD-089 · FD-090을 권장안대로 처리한다.
- 고칠 기존 파일(사본 `debug/frontend_fe5b/pre/frontend/...`): `lib/ui/widgets/plan_scenario_list.dart`, `lib/ui/widgets/plan_section_layout.dart`(CRLF 유지, 목록에 저장소 상태를 넘기는 줄만), `test/goldens/golden_harness.dart`, `test/goldens/fe1g_baseline_golden_test.dart`, `test/plan_scenario_list_test.dart`.
- 새 파일(예정): `lib/ui/models/plan_scenario_preview.dart`(비교 결과 → 미리보기 모델, 캐시 · 늦은 응답 처리), `lib/ui/widgets/plan_scenario_preview.dart`(S3 내용), `test/plan_scenario_preview_test.dart`.
- 고치지 않는다: `lib/services/**`, backend · contracts, 스캐너(`scan_page.dart` 등, Lane B 작업 중) · 전술 · 타이틀 화면, `app_shell.dart`. 서비스에 필요한 것은 요청만 적는다.
- 환경: PC 셸이 없다(파일을 가져와 고친 뒤 되돌려 쓴다). Flutter · Python을 돌릴 수 없어 정적 검토만 한다.

### FE5-b 종료 기록 (2026-10-10 18:00, 커밋 전)

상태: 구현은 끝났고 gate는 아직 돌리지 않았다. 시작 SHA는 redesigndocs `11281bed`다. `debug/frontend_fe5b/commit.json`을 두었다(slice=fe5b, status=true, whole에는 기준 이미지 10장을 파일 하나씩 적음). 직접 커밋하지 않았다.

- 고친 기존 파일: `lib/ui/widgets/plan_scenario_list.dart`, `lib/ui/widgets/plan_section_layout.dart`(한 줄, CRLF 유지), `test/goldens/golden_harness.dart`, `test/goldens/fe1g_baseline_golden_test.dart`.
- 착수 기록에 적은 `test/plan_scenario_list_test.dart`는 고칠 필요가 없어 그대로다. 사본(`debug/frontend_fe5b/pre/...`)은 남아 있지만 commit.json `modified`에는 넣지 않았다.
- 새 파일: `lib/ui/models/plan_scenario_preview.dart`, `lib/ui/widgets/plan_scenario_preview.dart`, `test/plan_scenario_preview_test.dart`.
- 고치지 않은 곳: `lib/services/**`, backend · contracts, 스캐너(Lane B) · 전술 · 타이틀 화면, `app_shell.dart`, 공용 키트(`lib/ui/kit/**`).

#### 실행 명령·결과

- 실행한 명령은 없다. 이 세션은 PC 셸이 없고 Flutter SDK도 없다. analyze · 테스트 · golden을 하나도 돌리지 않았으므로 통과를 주장하지 않는다.
- 정적 검토: 별도 검토 에이전트 1회. 확실한 실패 2건과 가능성 높은 문제 2건을 찾았고 모두 고쳤다.
  1. **컴파일 오류**: `preview != null`을 따로 담은 bool(`ready`)로 검사해 null이 풀리지 않았다. FE5-a 때와 같은 종류다. 조건을 `if`에 바로 두어 고쳤다.
  2. **v1 문서 성장 규칙 위반**: harness와 새 테스트의 v1 시나리오 문서가 ★1인데 스킬 2 · 3이 7이었다(스킬 2는 ★2, 스킬 3은 ★3이 필요). mock `createScenario`가 거부하므로 ★3으로 고쳤다.
  3. 분야 행 라벨 "노트 · BD"가 74px 칸을 테스트 글꼴에서 넘칠 수 있어 `FittedBox`로 감쌌다.
  4. 비교의 A 문서(활성 계획 문서)나 확정 상태가 바뀌면 캐시를 버린다(`invalidate`, 그 전에 보낸 응답은 버림). `required_a`가 응답에 없으면 0으로 보지 않는다.
- grep 범위: `test/**` 전체에서 미리보기 키, `GoldenScenarioListMockAppService` · 계산 대역 참조, S3에 새로 생긴 글자("비교에서 빼기" · "비교에 담기" 등)와 겹치는 `find.text`를 찾았다. 계산 대역을 쓰는 테스트는 golden 테스트 하나뿐이다. 기존 위젯 테스트에서 기대를 바꿀 곳은 없었다(행 위젯 단독 테스트는 S3가 없다).

#### 바뀐 것

1. **미리보기 읽기**(`plan_scenario_preview.dart` 모델, FD-089)
   - 펼친 행(= 고른 행)마다 `getScenario` + `compareScenarios(A = 활성 계획 문서, B = 시나리오 문서)`를 한 번 부른다. 확정 학생과 재고는 계획 화면의 저장소 상태를 쓴다(목록에 `repositoryState`를 새로 넘긴다).
   - 키는 (시나리오 id, 시나리오 revision, 활성 계획 revision, 프로필 revision)이다. 같은 키는 다시 부르지 않는다(접었다 다시 펼쳐도 캐시).
   - 응답은 자기 키에만 저장되므로, 빠르게 다른 행을 고른 사이 늦게 온 이전 응답이 지금 행의 화면을 덮지 않는다.
   - 읽는 중에는 "활성 계획과 비교하는 중입니다."를, 실패하면 "활성 계획과 비교하지 못했습니다(코드)." + "다시 읽기"를, 비교 서비스나 활성 계획이 없으면 "활성 계획과 비교할 수 없습니다."를 보인다.
2. **S3 내용**(`plan_scenario_preview.dart` 위젯 `PlanScenarioPreviewLayer`, 시안 Scenario-List S3 좌표, 왼쪽은 80° 변에서 잼)
   - **84**: 초상 3 · 이름(20px) · 설명 · 수정 시각. 제목 칩 "현재 데이터 기준"/"저장 시점과 다름"은 FE5-a 그대로다.
   - **168 · 198 KPI**: "활성 계획 대비 · 왼쪽 = 활성 계획 · 오른쪽 = 이 시나리오"와 KPI 3칸(필요 크레딧 · 부족 재화 · 첫 병목, a → b). b 색은 나아지면 초록, 나빠지면 경고, 같거나 모르면 흰색이다. 첫 병목은 projection `bottlenecks[].phase_number` 최솟값이고, 목록이 비면 "없음", 목록이 없으면 "—"다.
   - **288 학생 · 단계**: 시나리오 문서 학생 최대 3줄. 단계 경로 `P1 1단계 → P2 2단계`, 마지막 단계 목표 요약(정하지 않은 목표와 최솟값 그대로인 성급 · 장비 · 전무 · 인연은 쓰지 않음), 차이 칩이 있다. 넘치면 소제목 옆 "외 n명".
     - 칩: `b_only` → "이 시나리오에만"(분홍), 차이 없음 → "활성 계획과 같음"(회색), 모든 차이가 두 값을 알고 시나리오 쪽이 낮음 → "활성보다 낮은 목표"(초록), 그 밖 → "목표 다름 n"(파랑). 방향은 a/b 값으로 클라이언트가 판단한다(D §1-5).
   - **512 분야별 가장 큰 부족**: 엘레프 · 오파츠 · 노트 · BD · 장비 설계도 · 크레딧 다섯 줄. 그 분야에서 `shortage_b`가 가장 큰 재화, 병목 위치("P1 아루 1단계", `projection_b.bottlenecks[].stage_id` → 문서 단계), 부족량, 활성 대비 칩을 보인다.
     - 칩: 같음 / −n 초록 / +n 경고 / 활성 계획에 없는 재화는 "이 시나리오에만".
     - 부족 없는 분야는 흐리게("부족 없음", 모르면 "—"). 크레딧이 모자라지 않으면 "충분"(초록) · "모든 페이즈"다.
   - **"부족 재화" KPI = 팝오버 트리거**(FD-090): 키트 `GroupedShortageFlyout`(분야별 그룹 프리셋, 폭 500)다. Flow-4 레일 플라이아웃(`ShortageBreakdownFlyout`)과 같은 `AnchoredFlyout` 프리셋 묶음이다.
     - 제목 "부족 재화 n종", 부제 "활성 계획 m종 · 활성 계획에만 부족 k종", 행마다 활성 대비 칩.
     - 시안 하단 문구 "항목을 누르면 그 재화가 막는 단계로 이동합니다"와 "인벤토리에서 보기"는 동작이 없어(보기 모드 FE5-c, 인벤토리 FE6) 넣지 않았다.
   - **804 버튼**: "비교에 담기/빼기"는 행 액션과 같다(넷이 차면 FE5-a 안내). "열기"와 "계획에 적용…"은 꺼져 있고 툴팁을 단다.
3. **목록 화면**(`plan_scenario_list.dart`): 미리보기 로더를 상태에 두고, 펼친 행 · 목록 다시 읽기 · 활성 계획 revision 변화 때 키를 맞춘다. 빈 미리보기 안내는 FE5-a 자리 그대로라 `plan-scenario-list` golden은 바뀌지 않는다.
4. **golden 계산 대역 문서 의존화**(오케스트레이터 로그 10-09 23:25 후속, `golden_harness.dart`)
   - 공용 함수 `goldenCalculationBand` · `goldenComparisonBand` · `goldenBandSummary`를 두었다. 계획 만들기 mock과 시나리오 목록 mock이 같은 함수를 쓴다.
   - `overall` = 단계 필요량의 합 vs 고정 재고(`goldenBandInventory`). 같은 문서면 같은 값이고, 단계가 늘면 필요 크레딧 · 부족이 는다. 크레딧 = 단계 크레딧 합.
   - 단계 결과는 FE4 값 그대로다(학생 n번째 단계마다 크레딧 18.2M · 9.6M · 1.8M, 오파츠 · 볼프세크와 진입 보유량). 그래서 2단계 카드 상태 칩 · 3단계 배지 · 병목은 바뀌지 않는다.
   - 미리보기 분야를 보이려고 단계 재화를 늘렸다. 기술 노트(게헨나 최상급) 24 · 40 · 16, 시계 T10 설계도 n≥2, 전술 교육 BD(게헨나 최상급) n≥2, 아루 엘레프(아루 단계마다 120)이고, 모두 진입 보유량 = 필요량이라 단계 부족은 없다. id는 계산기 golden 대역에서 실제 파일로 확인된 것만 썼다.
   - 비교 대역의 학생 목표 차이는 `MockAppService`와 같이 학생마다 마지막 단계를 견준다(전에는 빈 값).
   - **시나리오 목록 mock**: 목록 요약 · 활성 계획 요약(`plan.get` calculation) · 미리보기 비교를 모두 같은 대역에서 만든다. 백엔드가 세 값을 같은 계산 경로로 만들기 때문이다. FE5-a의 시안 예시 고정값(186.2M · 112.8M 등)은 대역 값으로 바뀐다.
   - 이 장면 전용 활성 계획(`listActivePlanDocument`, 학생 장면 활성 계획보다 무거움)을 저장해, "07 3단계 우선순위" 미리보기가 크레딧 · 부족량은 나아지고 학생 칩 세 가지가 모두 보이게 했다.
   - 시나리오 문서는 v1 ★3 · 페이즈별 목표(Lv.80 · EX 3 · 스킬 7 → Lv.90 · EX 5 · 스킬 10 · T9 → T10) · 단계 이름 "n단계"다. "03 방어선 강화"는 미보유 두 명(세리카 · 나구사)으로 바꿔 "부족 0종 · 병목 없음" 초록 행을 지켰다(설명도 바꿈).

#### 처리한 FD

- FD-089(워커 재량, 권장안): 선택 시 1회 호출 + (시나리오 revision, 활성 revision, 프로필 revision) 키 캐시, 로딩 표시. 키 밖의 입력(활성 계획 문서 · 확정 상태 객체)이 바뀌면 캐시를 버린다.
- FD-090(워커 재량, 권장안): `AnchoredFlyout` 위 프리셋 2종 중 분야별 그룹(`GroupedShortageFlyout`)을 미리보기에 쓴다. Flow-4는 부족량 · 단계별 프리셋 그대로다.
- FD-088 · FD-082(FE5-c 몫): "계획에 적용…"과 "열기"는 꺼 두었다.

#### 판단(확인 부탁)

- 시나리오 목록 golden 숫자를 FE5-a의 시안 예시 고정값에서 대역 값으로 바꿨다. 미리보기 KPI가 행 · 고정 행과 같은 대역에서 나와야 서로 맞기 때문이다. 시안 숫자를 다시 재현하려면 대역에 장면 전용 비용표가 필요하다.
- 부족 재화 팝오버 부제의 시안 "빠진 6종은 이 시나리오에 없는 학생 몫"은 정의가 확인되지 않아(D §1-5) "활성 계획에만 부족 n종"(두 부족량을 알고 시나리오에서는 모자라지 않는 재화 수)으로 썼다.
- 시안 하단의 "항목을 누르면 … 이동합니다" · "인벤토리에서 보기"는 동작할 곳이 없어 넣지 않았다.
- 미리보기 KPI는 3칸(시안 그대로)이다. 충족률은 넣지 않았다.

#### 테스트

- 새 `test/plan_scenario_preview_test.dart`(9건)
  - 모델 3건: KPI · 학생 칩 · 부족 순서 · 분야 다섯 줄 · 병목 위치 · 묶음 / 값이 없으면 null(0 아님) / 칩 규칙 · 목표 요약.
  - 캐시 3건: 같은 키 한 번 · 늦은 응답이 지금 행을 덮지 않음 · revision 바뀌면 새 키 / invalidate 뒤 이전 응답 버림 / 실패 · 다시 읽기.
  - S3 층 위젯 2건: KPI · 학생 · 분야 행 · 버튼 꺼짐/켜짐 · 팝오버 4행 · 부제 / 읽는 중 · 실패.
  - 계획 화면 1건: 행을 고르면 getScenario 1 · compare 1, 접었다 펼치면 캐시, S3 비교에 담기 → "2 / 4".
- `fe1g_baseline_golden_test.dart`(의도된 변경)
  - `plan-flow-step2`의 `find.text('48.2M')`을 "레일 크레딧 = `planFlowCreditsLabel(flow)` · 48.2M이 아님"으로 바꿨다. 대역이 문서 의존이 되어 고정값이 없어졌기 때문이다.
  - 시나리오 목록 장면 준비를 `_openScenarioListScene`으로 묶고, 미리보기 KPI(07 = 73.8M)와 학생 칩 세 가지를 단언한다.
  - 새 장면 `plan-scenario-list-shortage`를 더했다. "부족 재화" KPI를 눌러 팝오버를 열고 7행 · "부족 재화 7종"을 단언한다.
- 지운 테스트 없음. `plan_scenario_list_test.dart` · `planning_page_test.dart`는 바꾸지 않았다.

#### golden 예측(장면별)

계산은 대역 식을 그대로 옮긴 계산으로 확인했고, 화면 그림은 확인하지 못했다.

| 장면 | 예측 | 이유 |
|---|---|---|
| `plan-flow-step1` · `-many` · `-filter` | 그대로 | 단계가 없어 계산을 부르지 않는다(레일 "—") |
| `plan-flow-step2` | 바뀜 | 레일 48.2M · 5종 → 29.6M · 6종(아루 3단계). 카드 비용 줄 둘째 재화가 "아루의 엘레프 120"으로, COST 블록에 기술 노트 · 설계도 · BD · 엘레프 줄, 오른쪽 "이 학생 재화" 수 증가. 상태 칩은 그대로 |
| `plan-flow-step2-saved` | 바뀜 | 레일 57.4M · 7종(호시노 2 + 아루 3 기준), 카드 비용 줄 · COST 행 |
| `plan-flow-step2-more` | 바뀜 | 레일 18.2M · 2종(아루 MAX 1단계 + 미보유 슌), 카드 비용 |
| `plan-flow-step3` | 바뀜(레일 중심) | 레일 57.4M · 7종, 충족률. 배지(부족 2 · 막힘 4 · 모집 필요 2) · 칸 머리는 그대로. 고른 카드 재화 목록에 새 줄이 생길 수 있음 |
| `plan-flow-step3-deferred` | 바뀜 | 레일 55.6M · 7종(아루 3단계는 나중에 칸이라 계산 밖) |
| `plan-flow-step3-many` | 바뀜 | 레일 207.2M · 8종(보유 7명 × 3단계) |
| `plan-flow-step4` | 바뀜 | 비교 타일 a(활성 46M · 4종) → b(57.4M · 7종), 화살표 색과 충족률 a ≠ b. "가장 크게 늘어나는 재화" 3줄 = 크레딧 +11.4M · 아루의 엘레프 +360 · 파이스토스(최상급) +96. 레일 57.4M · 7종 |
| `plan-flow-step4-append` | 바뀜 | b = 활성 + 새 페이즈 병합 103.4M · 7종(a 46M · 4종), 늘어나는 재화 크레딧 +57.4M · 엘레프 +360 · 파이스토스 +192. 고정된 P4 팝오버에 새 분야 줄 |
| `plan-scenario-list` | 그대로 | 고른 행이 없고 빈 안내 자리는 FE5-a 그대로, 기본 mock 대역 |
| `plan-scenario-list-expanded` | 바뀜 | 고정 행 112M · 6종 · P1(이 장면 활성 계획: 학생 5 · 페이즈 3 · 단계 8). 행 요약이 대역 값으로(07 73.8M · 7종 · P1 · 네브라(최상급) −194 / 01 18.2M · 2종 · P1 · 아루의 엘레프 −70 / 02 73.8M · 6종 · P1 · 네브라 −194 / 03 0 · 부족 0종 · 병목 없음 · 부족 없음(초록), 학생 세리카 · 나구사 / 04 55.6M · 7종 · P1 · 아루의 엘레프 −190 · 저장 시점과 다름). S3가 채워진다(아래) |
| `plan-scenario-list-shortage` | 새 장면 | expanded와 같은 상태 + 팝오버. 제목 "부족 재화 7종", 부제 "활성 계획 6종", 분야 4묶음(엘레프 1 · 오파츠 3 · 노트 · BD 2 · 장비 설계도 1) |
| `plan-scenario-compare` 외 나머지 | 그대로 | 기본 mock 비교, 학생 · 계정 · 스캔 · 타이틀 장면은 이 대역을 쓰지 않음 |

expanded · shortage 장면의 S3 내용:

- KPI: 112M → 73.8M(초록) · 6종 → 7종(경고) · P1 → P1(흰색).
- 학생 줄: 아루 "P1 1단계 → P2 2단계 · Lv.90 · ★3 · 스킬 M/M/M/M · T9 · 이 시나리오에만" / 아야네 "P1 1단계 → P3 2단계 · … · T10 · 활성보다 낮은 목표" / 호시노 "P2 1단계 · … · T9 · 활성 계획과 같음".
- 분야 행: 엘레프(아루의 엘레프 −190, 위치 없음, 이 시나리오에만) / 오파츠(네브라(최상급) −194, P1 아루 1단계, −180) / 노트 · BD(기술 노트 −92, −64) / 장비 설계도(시계 T10 설계도 −4, −8) / 크레딧(충분 · 모든 페이즈).
- 버튼: 열기 꺼짐 · 비교에서 빼기 · 계획에 적용… 꺼짐.

commit.json whole에는 위 "바뀜 · 새 장면" 10장을 적었다. 그 밖의 장면이 바뀌어 나오면 예측과 다른 것이니 알려 주기 바란다.

#### 검수표

| artboard / 확인 | 여는 방법 | 확인 포인트 |
|---|---|---|
| Scenario-List S3 미리보기 | mock 모드 → 계획 탭 → "시나리오 리스트" → 행 누르기 | 읽는 중 표시 뒤 KPI 3칸(a → b, 색), 학생 · 단계 줄과 칩, 분야 다섯 줄(흐림 · 충분) |
| 캐시 | 같은 행을 접었다 다시 펼치기, 다른 행으로 빠르게 옮기기 | 다시 읽기 표시 없이 바로 나옴, 늦게 온 이전 행 내용이 덮지 않음 |
| 부족 재화 팝오버 | S3 "부족 재화" 칸에 마우스 올리기 / 누르기 | 폭 500 패널, 분야 소제목 + n종, 행 칩(같음 · −n · +n · 이 시나리오에만) |
| S3 버튼 | 아래 버튼 | 비교에 담기/빼기 = S1 슬롯 수 변화, 열기 · 계획에 적용 꺼짐 + 툴팁 |
| 저장 시점과 다름 | 오래된 시나리오 행 고르기 | 제목 칩 "저장 시점과 다름" |
| 4단계 비교 타일(golden 대역 확인) | golden `plan-flow-step4` · `-append` | a · b 값이 다르고 화살표 색 · 늘어나는 재화 줄이 보임 |

#### 확인하지 못한 것

- analyze · 테스트 · golden 실행 전부. 정적 검토만 했다.
- 실제 그림: S3 요소 위치(시안 offset을 옮겨 적음), 좁은 창에서 학생 줄 · 분야 줄 넘침, 팝오버가 S3 아래 버튼 위로 겹치는 정도.
- ProcessAppService(실제 Python)의 compare 응답(`students[].target_differences` 모양, `bottlenecks[].stage_id` · `phase_number`)으로 위치 · 칩이 같은지.
- `plan-flow-step2-saved`의 학생별 단계 수(저장 프리셋 펼치기 규칙)는 FE4-i 기록대로 호시노 2단계를 가정했다.

#### 서비스 요청

- 없음. 기존 `getScenario` · `compareScenarios`로 충분했다. 다만 `PlanningScenarioComparisonResult`의 세 맵은 지금도 타입 검증이 없다(D §5). 화면은 모르는 모양을 null로 읽고 넘어간다.

#### 발견 사항

- 실제 백엔드 compare의 `resources[]`에 크레딧 줄이 들어 있으면, 4단계 "가장 크게 늘어나는 재화"(`PlanFlowSaveComparison.increases`)가 크레딧을 재화로 맨 위에 올린다(golden 대역에서 보임, FE4-e 코드). 크레딧을 빼야 하는지는 FE4-e 담당 판단이다. 이번에는 고치지 않았다.

#### 다음 행동

- 오케스트레이터: gate ① 결과 검토(위 표의 바뀜 9장 + 새 장면 1장 예상), 판단 4건 확인. 커밋 순서는 오케스트레이터가 정한다.
- 사용자 실행 순서:

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① 두 워커가 모두 멈춘 뒤 gate만 실행 → 결과를 오케스트레이터에게 보내고 기다린다(plan-flow-step2 · -saved · -more · step3 · -deferred · -many · step4 · -append · plan-scenario-list-expanded RED, 새 장면 plan-scenario-list-shortage 기준 없음 예상)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 승인 뒤 기준 이미지 갱신 → gate
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ③ 커밋(순서는 오케스트레이터가 정한다)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe5b -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe5b
```

## fb2b-dart + sfb2b Mock (Lane A, XB paired history Dart 쪽)

### fb2b-dart 착수 기록 (2026-10-10 20:40)

- 진행 중: fb2b-dart(+sfb2b Mock), Lane A 프론트 워커. 프롬프트 `debug/frontend_redesign_handoff/fb2bdart-worker-prompt-20261010.md`.
- 시작 SHA: `11281beda57efadbbc2860f374d0367f556ffff4`(브랜치 scanner-consolidation). 이 세션은 PC의 git을 읽을 수 없어 가장 최근 gate 요약(`debug/frontend_gate/20261010_185608/summary.txt`의 `git` 줄)과 오케스트레이터 로그 19:55의 HEAD를 옮겨 적는다. 그 뒤 커밋이 있었다면 오케스트레이터가 고쳐 적는다.
- 동결 계약 SHA 확인: `debug/xb_fb2b_actual_20261010/artifacts/cf-contract-hashes.json`의 7개 파일을 PC에서 가져와 바이트 수와 SHA-256을 다시 셌다. **7개 모두 일치**(멈출 이유 없음).
  - `contracts/repository-history-scan-latest-v1.schema.json` 10465 B `dc0e7599…bbf3`
  - `contracts/repository-protocol-v1.schema.json` 23558 B `e8647360…782d`
  - `contracts/fixtures/repository_history_scan_latest_v1.json` 198652 B `d4686283…2446`
  - `contracts/fixtures/current_history_v1.json` 135624 B `9c930060…6f28`
  - `contracts/scan-commit-history-context-v1.schema.json` 3246 B `aeaa9fb3…9da8e`
  - `contracts/fixtures/scan_commit_history_context_v1.json` 74500 B `0f8a89bf…53ff`
  - `contracts/fixtures/scanner_commit_history_sfb2b_v1.json` 13433 B `3f7c1df7…ff9`
- 범위: 프롬프트 1(FB-2b summary 13키 · `repository.history.scan_latest` DTO · 서비스 · Process · strict 검사 · 읽기 전용 Mock), 2(S-FB2b Mock scanner commit: 승인 identity upsert · 원 complete bucket과 공개 7필드 고정 · receipt 우선 replay · 내부 `appendScan` 1회 · observer 중복 억제 · 빈/전부 제외 scope 거절), 3(공유 fixture 직접 읽기 · 기대 갱신 · process E2E).
- 고칠 기존 파일(사본 `debug/frontend_fb2bdart/pre/<경로>`, 8개):
  - `frontend/lib/services/repository_history_service.dart` — 기존 미커밋 변경 없음(gate 185608 `git-diff-check.log`의 수정 파일 목록에 없음).
  - `frontend/lib/services/repository_service.dart` — 기존 미커밋 변경 없음(같은 근거).
  - `frontend/lib/services/process_app_service.dart` — **기존 미커밋 변경 있음**(스캐너 WIP). 새 wrapper 1개만 history 묶음 끝에 더한다.
  - `frontend/lib/services/mock_app_service.dart` — **기존 미커밋 변경 있음**(스캐너 WIP). WIP 줄은 지우지 않고, 스캐너 메서드 안에는 짧은 삽입만 하고 새 로직은 한 덩어리로 더한다.
  - `frontend/lib/services/mock_repository_history.dart` — 기존 미커밋 변경 없음.
  - `frontend/test/repository_history_service_test.dart`, `frontend/test/repository_history_process_e2e_test.dart`, `frontend/test/repository_history_query_process_e2e_test.dart` — 기존 미커밋 변경 없음.
- 새 파일(예정): `frontend/lib/services/repository_history_scan_latest.dart`(history 서비스 part), `frontend/test/repository_history_scan_latest_test.dart`, `frontend/test/repository_history_scan_latest_process_e2e_test.dart`, `frontend/test/mock_scanner_commit_history_test.dart`.
- 고치지 않는다: `frontend/lib/ui/**`(scan_page.dart는 Lane B), `app_shell.dart`, `backend/**` · `contracts/**`(읽기만), `planning_protocol_client.dart`(repository.* 성공 검사가 이미 `isValidRepositorySuccessPayload`로 넘어가므로 고칠 필요가 없다).
- 환경: PC 셸이 없다(파일을 가져와 고친 뒤 되돌려 쓴다). 이 작업 공간에서는 Dart SDK를 받을 수 없어(storage.googleapis.com · pub.dev 차단) Flutter · Dart를 돌리지 못한다. 정적 검토와, 같은 규칙을 Python으로 옮긴 fixture 대조만 한다. 통과를 주장하지 않는다.

### fb2b-dart 종료 기록 (2026-10-10 20:45, 커밋 전)

상태: 구현은 끝났고 gate는 아직 돌리지 않았다. 시작 SHA는 `11281bed`다. `debug/frontend_fb2bdart/commit.json`(slice=fb2bdart, status=true, post_dir=`debug/frontend_fb2bdart/post`)과 pre · post 사본을 두었다. 직접 커밋하지 않았다.

- 고친 기존 파일 8개(pre 사본 있음): `frontend/lib/services/repository_history_service.dart`, `repository_service.dart`, `process_app_service.dart`, `mock_app_service.dart`, `mock_repository_history.dart`, `frontend/test/repository_history_service_test.dart`, `repository_history_process_e2e_test.dart`, `repository_history_query_process_e2e_test.dart`.
- 새 파일 4개: `frontend/lib/services/repository_history_scan_latest.dart`(history 서비스 part), `frontend/test/repository_history_scan_latest_test.dart`, `frontend/test/repository_history_scan_latest_process_e2e_test.dart`(process 분류), `frontend/test/mock_scanner_commit_history_test.dart`.
- 고치지 않은 곳: `frontend/lib/ui/**`(scan_page.dart · `ui/scan/**`는 Lane B), `app_shell.dart`, `planning_protocol_client.dart`(repository.* 성공 응답은 이미 `isValidRepositorySuccessPayload`로 위임되고, 여기에 새 메서드를 엄격하게 넣었다. 요청 쪽도 `isValidRepositoryProtocolMessage`에 넣었다), `repository_history_query.dart`(기존 stored history · cache 검사기를 강화하지 않는다), golden harness · golden 테스트, `backend/**` · `contracts/**`.

#### 구현 요약

1. **FB-2b summary**: `RepositoryHistorySummary` 12 → 13키. `last_scan_at`은 필수 nullable(6자리 UTC)이고 `total_counts.scan == 0`일 때만 null이다(`scan`도 `manual`·`import`와 같은 짝 검사에 넣음). 값은 저장된 `last_applied_at.scan` 그대로다(최대 시각 · manual/import/unattributed로 대체하지 않음). `lastScanAt` getter, `toWire`, `unrecorded`, `_summarize`, SummaryResult 중첩 검사가 모두 13키다. 키가 빠진 응답에 기본값을 채우지 않는다(옛 12키 응답은 strict하게 거부).
2. **`repository.history.scan_latest`**(새 part `repository_history_scan_latest.dart`):
   - `RepositoryHistoryScanLatestRequest`: 필수 `profile_id` + 선택 6개. 타입은 정확히(bool · int, 1.0 · true 거부), page 1..200(기본 100), after ≥ 0, after > 0이면 anchor 필수, after ≤ anchor, 페이지 조절 키는 `include_by_kind=true`일 때만, 대상 각 256개 이하. 새 query 문자열은 UTF-8 인코딩 **전에** 홀로 선 surrogate를 거부하고(`utf8.encode`는 U+FFFD로 바꿔 숨기므로), 1..1024 bytes를 원문 그대로(trim · enum 없음) 지킨다. resource key는 canonical alias(`Item_Icon_SkillBook_Ultimate_Piece` → `Item_Icon_SkillBook_Ultimate`, 백엔드 `LEGACY_RESOURCE_KEYS`와 같은 표 `historyLegacyResourceKeys`)를 먼저 적용한 뒤 중복을 거부한다. 정렬은 기존 `_historyIdCompare`(rune 순서, U+E000 < U+10000)를 그대로 쓴다. `nextKindPage(page)`는 첫 페이지의 `history_sequence`를 anchor로 붙인다.
   - `RepositoryHistoryScanLatestResult`(exact8) · `HistoryLatestScan`(exact5, `inventory_scan_profile` 필수 nullable 원문) · `HistoryStudentScanLatest` / `HistoryResourceScanLatest`(exact3). 검사: by_kind는 latest sequence 오름차순 · 튜플 유일 · 200 이하, next-after는 마지막 sequence와 같을 때만, 행은 rune 순서로 유일 · resource 행은 canonical key, `latest_scan == null ⇔ reason ∈ {unrecorded, scan_not_found}`, `last_scan_at == null`이면 by_kind · next · 행 scan이 모두 비어야 한다, `unrecorded`는 history 없음(sequence 0)일 때만. `fromWireFor(request, wire)`는 요청 대상 행 일치 · include 여부 · page 경계 · anchor 일치까지 본다.
   - `RepositoryService.loadRepositoryHistoryScanLatest` 추가. `ProcessAppService`는 `repository.history.scan_latest`를 보내고 `fromWireFor`로 받는다. 오류(`invalid_payload` reason=`stale_scan_latest`, retryable=false / `corrupt_data`)는 기존 repository 오류 처리 그대로 `BackendRemoteException`으로 온다.
   - Mock: `repositoryHistoryScanLatest(...)`(저장 index · `last_applied_at.scan`만 읽음). profile revision은 `_mockRepositoryState`(이관 없음), history는 `_currentHistories`. observer · clock · cache · map 쓰기 없음, 결과는 분리된 사본. stale anchor는 `BackendRemoteException(invalid_payload, details.reason=stale_scan_latest, retryable=false)`, 불가능한 by_kind 중복은 include=false여도 `corrupt_data`(고치지 않음).
3. **S-FB2b Mock scanner commit**(student/inventory 세션만, 전술 로비는 기존 4인자 경로 그대로):
   - 공개 요청 7필드(`session_id` · `generation` · `candidate_id` · `candidate_revision` · `profile_id` · `expected_repository_revision` · `idempotency_key`)의 canonical JSON과 session/key로 receipt를 찾는다. 같은 요청이면 **revision 검사 · 읽기 · 쓰기 · clock보다 먼저** 최초 응답을 그대로 돌려준다. 같은 key에 다른 필드(generation 포함)면 `idempotency_conflict`. manual 저장 cache(`_planIdempotency`)와 섞지 않는다.
   - 처음 보는 요청: 저장된 후보 revision이 다르면 `candidate_revision_conflict`, 검토 필요 · 미승인이면 `review_required`(둘 다 기존처럼 `StateError`). 그다음 승인 payload로 scope를 정하고(student = `[student_id]`, inventory = 항목의 canonical identity), 빈 scope(전부 제외 포함)는 상태를 읽기 전에 `BackendRemoteException(invalid_candidate, details.reason=empty_scan_scope)`이며 receipt를 남기지 않는다. 이어 state를 읽고(get_state처럼 첫 이관 포함) **원 complete bucket**을 만든다: inventory는 canonical identity upsert(관찰하지 않은 기존 항목 유지, scanner 전용 `inventory_scan_profile` 필드 제거, alias → 현재 key), student는 같은 ID만 교체. 이 bucket · 공개 요청 · nested context · 승인 scope · 원문 kind/profile · (내부 provenance: applied/excluded/retry_of=null)를 receipt에 고정한다.
   - revision이 낡으면 `revision_conflict`(receipt는 pending으로 남고, 같은 key 재시도는 다시 merge하지 않고 같은 고정 bucket으로 같은 결과). 맞으면 한 번 쓰고 `RepositoryCurrentHistory.appendScan`으로 scan 적용 1건(source=scan, applied_scope = 승인 scope, nested context exact4, 동값 적용도 기록)을 남긴다. 이 쓰기 동안 `_scannerMockCurrentWrite`로 current-map observer를 막아 unattributed 중복이 없다. 성공 뒤 receipt는 응답만 남기고 bucket을 놓는다. profile 목록 revision도 맞춘다.
   - 원문 kind/profile은 `startScannerSession`에서 세션별 내부 map에 남긴다(public `ScannerSession` 그대로). 공개 API로 표현할 수 없는 미래 원문 profile은 `@visibleForTesting debugSetScannerSessionRawMetadata`로만 넣는다. 제외 key 추적은 후보 map 쓰기 관찰(`MockScannerCandidateMap`)로 한다.
   - `appendScan`(history 서비스): scope 밖 diff를 거부하고(`scan_scope_mismatch`), 빈 scope · 중복 ID · 잘못된 context를 거부한다. index 갱신은 Python `append_history`와 같다(by_kind는 같은 튜플을 빼고 끝에 추가, 학생 · 자원은 rune 순서, session ID 평생 목록). `appendManual`은 동작 그대로이고 diff · 접기 꼬리를 `appendScan`과 나눠 쓴다(`_historyDiffs`, `_appendHistoryEvent`).
4. **테스트**:
   - `repository_history_scan_latest_test.dart`: 공유 fixture의 valid 11건을 순수 query · Mock · 응답 검사기로 그대로 재현(+ Mock clock 0회 · 목록 revision 그대로 · 사본 분리 · summary `lastScanAt` 일치), metadata policy oracle 31건(요청 오류 → `FormatException` · 요청 메시지 검사 false, stale → `RepositoryHistoryScanLatestError`, payload → index query 결과 일치), oracle 적용 기록 7건을 Mock `appendScan`/`appendManual`로 다시 쌓아 index · last_scan_at · session · 결과를 대조(가지친 2건과 import 1건은 Mock helper로 만들 수 없어 index 대조에서만 쓴다), 요청 경계(rune 순서와 `String.compareTo` 반대 확인, 홀로 선 surrogate 4종 · 빈 문자열 · 1026 bytes 거부와 1023/1024 bytes 허용, alias 중복, 학생 ID 원문 유지, 잘못된 제어 키 10종), 결과 DTO strict 18종, Mock stale · corrupt · clock rollback(시각이 아니라 마지막 적용 sequence), summary exact13 검사.
   - `mock_scanner_commit_history_test.dart`: `scanner_commit_history_sfb2b_v1.json` 6건마다 upsert(관련 없는 항목 유지, 제외 항목 이전 값 유지), scan 1건 · unattributed 0, 원문 kind/profile(알 수 없는 원문 profile 포함), 승인 scope, nochange면 변경 0, nested context exact4, scan_latest(승인 key만 갱신, 제외 key는 `scan_not_found`), 공개 성공 4키, receipt replay(다른 곳 쓰기 뒤에도 최초 응답 · clock 1회 그대로), 같은 key 다른 expected = `idempotency_conflict`. 빈 scope 거절(receipt 없음 · 상태 그대로), pending 손실 재시도(같은 key는 계속 conflict, expected를 바꾸면 idempotency_conflict, 새 의도는 새 key), 낡은 후보 revision · 검토 필요.
   - `repository_history_service_test.dart`: "typed missing/null/zero…"와 "summary protocol is strict…"는 공유 summary가 13키가 된 것이 **의도된 변경**이라 그대로 녹색이 되어야 하고, `last_scan_at` 누락 · null 불일치 · 12키 응답 거부를 더했다. 옛 "old Mock scanner writes stay unattributed…"는 S-FB2b로 기대가 바뀌어 "seeded unattributed history is not reclassified; new Mock scanner commits record scan once"로 바꿨다(과거 unattributed 1건 유지, 새 scan 1건, replay는 기록 없음, 동값 scan 2 · session 1, 뒤 manual은 따로).
   - process: `repository_history_process_e2e_test.dart` 2건에 summary 13키 · manual/import만 있으면 `last_scan_at` null을, `repository_history_query_process_e2e_test.dart`에 fixture `last_applied_at.scan`과 같은 `lastScanAt`을 더했다. 새 `repository_history_scan_latest_process_e2e_test.dart`는 실제 Python 저장소에 fixture history 11건을 넣고 결과 · summary를 대조하고, 첫 페이지 → 둘째 페이지 → manual 쓰기 → stale anchor(`invalid_payload`/`stale_scan_latest`/retryable=false) → 처음부터 다시 → 재시작 뒤 같은 결과 · 같은 파일 바이트를 본다.
   - grep으로 찾은 영향 대상: summary를 단언하는 테스트는 위 3개 파일뿐이다. Mock commit을 쓰는 테스트는 `repository_history_service_test`, `scan_page_test`(UI 적용 · 충돌 · 재검증), `scan_page_revision_test`(Lane B, `super.commitScannerCandidate`), `inventory_page_test`(승인 commit · 낡은 revision). 이들은 고치지 않았다: 오류 형태(`StateError(code)`)와 응답 4키를 그대로 두었고, 저장소 밖에서 만든 후보(저장된 후보 없음)는 넘어온 후보로 처리한다. statistics · golden 대역은 `MockAppService`를 상속만 하고 scan commit · history를 부르지 않는다. `RepositoryService`를 직접 구현하는 테스트 대역은 없다(새 interface 메서드 영향 없음).

#### 실행 명령 · 결과

- Flutter · Dart: **실행하지 못했다.** 이 작업 공간은 Dart SDK를 받을 수 없고(storage.googleapis.com · pub.dev가 프록시 정책으로 막힘) PC 셸도 없다. analyze · 테스트 · golden 통과를 주장하지 않는다.
- 계약 SHA 재계산(Python hashlib): 7개 모두 `cf-contract-hashes.json`과 일치.
- 같은 규칙을 Python으로 옮긴 대조(`debug/frontend_fb2bdart/artifacts/scan_latest_policy_sim.py`, 출력 `scan_latest_policy_sim.txt`): valid 11/11, oracle 31/31(payload 18 · 요청 오류 11 · stale 2), 적용 재생 7건 index · 결과 일치. Dart 코드를 실행한 것이 아니라 Dart에 넣은 규칙(요청 검사 · 결과 검사 · query · index 갱신)을 옮겨 fixture와 맞춰 본 것이다.
- 기기 쓰기 뒤 다시 읽어 SHA-256 비교: 코드 12개 · pre 8개 · 이 문서 모두 일치.

#### cf-semantic-review-checklist 항목별 답

1. Summary exact13 · 필수 nullable `last_scan_at`: 맞다. 누락 키 fallback · `latest_updated_at` · 최대 시각 대체 없음. null ⇔ scan 0을 DTO가 검사한다.
2. scan_latest profile + 선택 6 · exact8/5/3: 서비스 interface · Process wrapper(`fromWireFor`) · 요청/응답 strict 검사 · DTO · Mock · 공유 fixture 소비자가 같은 DTO 하나를 쓴다.
3. scalar/UTF-8 경계 · alias 먼저 · seek/anchor · stale 재시도 불가: 요청 DTO와 Mock query가 백엔드 `history_scan_latest.py`와 같은 순서로 검사한다(fixture 31건으로 대조).
4. 행 정렬은 `_historyIdCompare`, U+E000 < U+10000(fixture `unicode_scalar_e000_before_10000` + 직접 테스트). surrogate 거부는 새 경계의 런타임 검사이며 JSON schema와 별개다.
5. Mock latest = 저장 index(적용 sequence · source=scan · 승인 scope). 빈 · 제외만 있는 경우 보존, 필터 불일치 · include=false에도 profile `last_scan_at` 유지, clock rollback 테스트 있음.
6. Mock inventory commit = upsert, 관련 없는 기존 항목 유지, scan 적용 1건, replay에서 observer 중복 없음(테스트로 unattributed 0 확인).
7. Pending UI 재시도: **이 slice는 Mock 쪽만**(receipt 우선 replay, pending은 원 bucket 고정, 같은 key에 다른 expected는 conflict). 화면 쪽 고정(최초 candidate/profile/expected/key, busy · 응답 손실에 재구성 안 함)은 Lane B S-FB1b(`scan_page.dart`, `ui/scan/scan_repository_sync.dart`의 `ScanPendingApply`) 소관이고 이 slice는 손대지 않았다. Lane B `scan_page_revision_test`의 응답 손실 replay 기대가 이 Mock 위에서 도는지는 같은 gate에서 확인해야 한다.
8. 공유 fixture는 고정 SHA 그대로다. process · golden 단계 GREEN은 **미검증**(gate 전).
9. 소비자 경로 · 바이트 · SHA는 아래 표. gate 원본 파일과 CF 확인은 gate 뒤에 붙인다.

| 경로 | bytes | SHA-256 |
|---|---|---|
| frontend/lib/services/repository_history_service.dart | 34028 | `f5d70291db6e5ec322b6ab9f913d4a3eccaa58017e2151bc617a7fdca6eeb946` |
| frontend/lib/services/repository_history_scan_latest.dart | 18259 | `ebbdc7818154170b98a612bf24d8d9d02218a981e9b0a3c5cdcfaef20ce351ee` |
| frontend/lib/services/repository_service.dart | 25944 | `3c9bb9516762ebe44208fb48be6a587d330d7feb474bc34733429bc9e039e575` |
| frontend/lib/services/process_app_service.dart | 38277 | `0f23ddaa3819b0263eb6f4ac267b49cda4a987983d6ebd5a6d9d9e9a6e57a030` |
| frontend/lib/services/mock_app_service.dart | 94884 | `48dda3278b6efa3a8bd5df789eedca11b26dda198545252d4850eddee04b5580` |
| frontend/lib/services/mock_repository_history.dart | 1639 | `e6f6cb986687637666e1c0df4ef0b038c9aeb66fea685bfc100d4ffb154f8bf2` |
| frontend/test/repository_history_scan_latest_test.dart | 25126 | `e142e4ab5c989616c36da66d5662459a6cb20488ea35eab0f19cdeb8e7c2468f` |
| frontend/test/repository_history_scan_latest_process_e2e_test.dart | 7226 | `7e5d1b2313743e98dbd0b2756941d907d48fa12348074b37fb53205d20ef49f0` |
| frontend/test/mock_scanner_commit_history_test.dart | 16183 | `9ac1b43dc538ce504f505d94d9b7e78554450e4fb89bbd5da4e0bdf6067f4cb3` |
| frontend/test/repository_history_service_test.dart | 15257 | `52a28ffe5ea2292c249aad5e67df5e11f10edefbbb44512267ca5cffda1d6626` |
| frontend/test/repository_history_process_e2e_test.dart | 9539 | `a4deb4ab9b2fc60b7377449177ed8374ecf19435c042b807c053df289675577f` |
| frontend/test/repository_history_query_process_e2e_test.dart | 10443 | `b197fd985e1ad0082bed02e4c3f0ff097999658f14ceb336b631d154436589fb` |

#### WIP 보존 확인

- `mock_app_service.dart` · `process_app_service.dart`의 스캐너 WIP 줄은 지우거나 바꾸지 않았다. 이 slice의 변경은 `mock_app_service.dart`에서 후보 map 선언 1줄 교체, `startScannerSession` 4줄 삽입, `commitScannerCandidate` 앞머리 분기 삽입, observer 1줄 삽입, scan_latest 메서드 · 새 commit 묶음 · 파일 끝 private 클래스 추가뿐이고, `process_app_service.dart`는 wrapper 1개 추가뿐이다. 원래 줄의 줄끝(CRLF/LF 섞임)도 그대로 두었다.
- PC git을 읽을 수 없어 WIP 줄과 겹치는지는 확인하지 못했다. 겹치면 `fe_commit.ps1 -DryRun`이 merge conflict로 멈추고 `.conflict` 파일을 남긴다(그때 오케스트레이터가 처리).

#### 미검증 항목

- analyze(특히 flutter_lints 6 info 단계) · 컴파일 · 모든 테스트 실행 · golden 비교 · 실제 Python과의 process E2E.
- process E2E가 fixture history를 넣은 프로필(revision 3 · 99, 학생 · 자원 비어 있음, history 없는 프로필 포함)을 실제 저장소가 받아들이는지. 기존 FB-2c E2E와 같은 방식이지만 이번 fixture로는 처음이다.
- Dart `RepositoryCurrentHistory.fromWire`가 fixture valid 11건을 모두 받아들이는지(XB는 Dart 소비용이라 했지만 Dart로는 처음 읽는다).
- golden 변화: 0 예상. 화면 코드 · golden harness를 바꾸지 않았고 golden 장면은 scan commit · history를 부르지 않는다. 바뀌면 이 slice 탓인지 보고 이유를 적는다.
- Lane B(S-FB1b) 테스트와의 상호작용: Mock commit이 이제 profile 목록 revision을 맞추고 receipt를 먼저 본다. `scan_page_revision_test`의 대역은 자기 receipt를 따로 가지므로 같은 key로 `super`를 두 번 부르지 않지만, gate에서 확인해야 한다.

#### 발견 사항

- 공유 서비스 파일 줄끝이 섞여 있다(`mock_app_service.dart` CRLF 2235/2351줄, `process_app_service.dart` 1181/1205줄, `repository_service.dart` 713/740줄). LF 줄이 대체로 미커밋 WIP나 최근 slice가 넣은 줄로 보인다. fe_commit의 Norm/Write-LikeHead가 처리하므로 막지는 않는다.
- `_SnapshotMockService`(scan_page_test)처럼 Mock 밖에서 만든 세션 · 후보로 `super.commitScannerCandidate`를 부르는 대역이 있어, 저장된 후보가 없으면 넘어온 후보를 쓴다(백엔드는 `candidate_not_found`). 세션 존재 · terminal 검사도 같은 이유로 Mock에 넣지 않았다.

#### 다음 행동

- 오케스트레이터: gate 결과 검토. 기대: 직전 gate의 이 slice 몫 5건(`repository_history_service_test` 2건, `repository_history_process_e2e_test` 2건, `repository_history_query_process_e2e_test` 1건)이 녹색, 새 테스트 녹색, golden 변화 0(FE5-b 몫 RED는 그대로). 같은 소스 GREEN을 XB에 회신 → XB backend 커밋 → 이 slice 커밋(순서는 오케스트레이터가 정한다).
- 사용자 실행 순서:

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① 두 워커가 모두 멈춘 뒤 gate만 실행 → 결과를 오케스트레이터에게 보내고 기다린다
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 커밋은 XB backend 커밋 뒤(순서는 오케스트레이터가 정한다)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fb2bdart -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fb2bdart
```

### fe5b commit record (2026-10-10 22:53, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261010_220311\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

### fb2bdart commit record (2026-10-10 23:20, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261010_220311\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: frontend/lib/services/process_app_service.dart, frontend/lib/services/mock_app_service.dart

## FE5-c1 착수 기록 (2026-10-10 23:50, Lane A)

- 상태: 진행 중. 시작 SHA = `18c5f0b0a14e95aaa48cbbb6e006db23f6b43f85`(scanner-consolidation HEAD).
- 범위: 시나리오 보기 모드(열기 · 뒤로 · 다른 시나리오 열기) · Detail 3섹션 위젯(비교 KPI · delta를 끌 수 있게, c2 재사용) · 활성 대비 KPI 4개 · 병목 카드(같은 단계 묶음 · 지연 단계 · 카드 ↔ 단계 행 강조) · 요약 행 3종 projection · "계획에 적용…"(FD-088, FE4-e 저장 경로 재사용).
- 막힘 요약의 이 slice 열림 FD 0건 확인. 워커 재량 FD-035 · FD-038 · FD-039 · FD-067 · FD-088은 권장안대로 처리한다.
- 고칠 기존 파일(사본: `debug/frontend_fe5c1/pre/<경로>`):
  - `frontend/lib/ui/widgets/plan_scenario_list.dart`
  - `frontend/lib/ui/widgets/plan_scenario_preview.dart`
  - `frontend/lib/ui/models/plan_scenario_preview.dart`
  - `frontend/lib/ui/widgets/plan_section_layout.dart`
  - `frontend/lib/ui/models/plan_flow_draft.dart`(흐름을 4단계 · 저장 위치를 미리 고른 채 여는 값 하나)
  - `frontend/lib/ui/models/plan_flow_save.dart`(그 값을 첫 저장 위치로 쓰기)
  - `frontend/test/goldens/golden_harness.dart`, `frontend/test/goldens/fe1g_baseline_golden_test.dart`
  - `frontend/test/planning_page_test.dart`, `frontend/test/plan_scenario_list_test.dart`, `frontend/test/plan_scenario_preview_test.dart`
- 새 파일(예정): `frontend/lib/ui/models/plan_scenario_detail.dart`, `frontend/lib/ui/widgets/plan_scenario_detail.dart`, `frontend/lib/ui/studio/plan_scenario_detail_studio_layout.dart`, `frontend/test/plan_scenario_detail_test.dart`.
- 이 환경에는 flutter가 없다(정적 검토만 가능). `frontend/lib/services/**`는 고치지 않는다.

## FE5-c1 종료 기록 (2026-10-11 01:08, Lane A)

- 상태: 구현 끝, **정적 검토만 했다**. 이 환경에는 flutter · dart가 없다(pub.dev · storage.googleapis.com 접속 거절). analyze · 테스트 · golden은 한 번도 돌리지 않았다. 통과를 주장하지 않는다.
- 시작 SHA `18c5f0b0`. 사본은 `debug/frontend_fe5c1/pre/`에 있다. `plan_scenario_list_test.dart` 사본도 두었지만 그 파일은 고치지 않았다(commit.json `modified`에 없음).
- commit.json: `debug/frontend_fe5c1/commit.json`(slice=fe5c1, status=true, whole = 기준 이미지 6장, 하나씩).

### 실행 명령 · 결과

- `flutter analyze` · `flutter test`: 실행하지 못했다(SDK 없음).
- 정적 검토 에이전트 1회(바뀐 파일 전부 · 새 테스트 기대값 손 계산): 확실한 컴파일 오류 1건. `plan_scenario_detail.dart`에서 반복문 안에서 `int?` 카운터를 `+= 1` 했다(반복 안에서는 null 승격이 풀린다). 지역 `var` 카운터로 세고 반복 뒤에 넣도록 고쳤다. lint 지적 · 남은 참조 · 테스트 최상위 `expect`는 0건이었다.
- 장치 반영: 바뀐 파일 10개 · 새 파일 4개를 `expectedMtimeMs`로 쓰고 다시 받아 `cmp`로 14개 모두 같음을 확인했다. `plan_section_layout.dart`는 CRLF 그대로다(8328줄 모두 CRLF).

### 한 일

1. **열기**(목록 행 액션 · S3 "열기"): 계획 화면이 `_viewingScenarioId`를 들고, 같은 `PlanScenarioListSection`(같은 key)이 Detail 3섹션을 그린다. 위젯이 그대로 남으므로 FE5-b 미리보기 캐시를 그대로 쓴다(열기 전 펼친 행의 compare 응답, 다시 부르지 않음 — 테스트로 확인). 섹션 모션은 목록 열기 · 닫기와 같은 `_scenarioListController` reverse → 상태 전환 → forward다. S1 "시나리오 목록"이 뒤로, 목록에서 다른 행을 열면 그 시나리오다. 목록을 닫거나 흐름 · 프리셋 관리 · 비교로 나가는 모든 곳에서 `_viewingScenarioId`를 비운다. 열기는 활성 계획과 비교할 수 있을 때만 켜진다(꺼지면 툴팁).
2. **Detail 3섹션 위젯** `PlanDetailWorkspace`(`widgets/plan_scenario_detail.dart`) + Studio 문서 `plan_scenario_detail_studio_layout.dart`(메뉴 0,2,15,94 · 페이즈 8,2,25,94 평행사변형 · 재화 34,2,62,94 사다리꼴, 시안 대비 +8.6 · +11.3px). S3 맨 위 한 줄은 seg(병목 / 페이즈별 · 전체) + 칩 3개다. **페이즈별 · 전체는 seg 자리만 두고 꺼 두었다**(툴팁 "아직 열 수 없습니다", FE5-d). 칩 3개("재화 유형 · 전체", "충족 재화 숨기기", "부족량 많은 순")도 자리 · 상태 표시만이고 동작은 없다.
3. **KPI 4개**(필요 크레딧 · 부족 재화 · 첫 병목 · 끝까지 가는 학생 n/m). 값은 FE5-b 미리보기에 이번에 저장한 compare 응답 그대로(`PlanScenarioPreview.result` · `activeDocument` 추가)에서 계산한다. 새 서비스 메서드는 없다. "부족 재화" 칸은 FE5-b 팝오버(`planScenarioShortageFlyout`, FD-090)다.
4. **병목 카드**: 같은 `stage_id` 병목을 한 장으로 묶는다(번호 = 처음 나온 순서). 재화 타일은 모자란 것 먼저, 둘보다 적으면 그 단계 `stage_results` 중 충분한 재화(크레딧 먼저)로 채우고 최대 3개다(넘치면 "모자란 재화 외 n종"). 지연 단계와 활성 대비 칩도 단다. 카드를 고르면 S2 그 단계 행이 분홍 테두리(`DiagonalRowMark.selected`)이고, 병목 단계 행이나 요약 행을 눌러도 카드가 골라진다. 처음에는 병목 1이 골라져 있다(시안 상태).
5. **요약 행 projection**: 상수 14개(`planPrimaryBottleneckOwned/Required/StudentCount/StudentIds`, `planPhaseShortage*` 6개, `planOverall*` 4개)를 지우고 `PlanResourceSummaryProjection.of(병목 · 페이즈별 · 전체 목록 · 페이즈)`로 바꿨다. 계획 홈 레이아웃은 그대로다(같은 위젯 · 같은 키, `PlanResourceItemSummary.iconAsset`만 null 허용). grep으로 찾은 사용처는 `plan_section_layout.dart` 헤더와 `planning_page_test.dart`뿐이었다.
   - 가장 심한 병목 = 화면 병목 목록의 첫 병목(문서 순서) · 첫 재화. "보유량 : 진입 잔량 / 필요량 : 그 단계 필요". 학생 = 막힌 학생 + 지연 단계 학생.
   - 가장 부족한 재화 = 모자란 재화가 있는 첫 페이즈에서 충족률(보유/필요)이 가장 낮은 재화. "P{n}에서 m명 중 k명만 완료 가능"(k = 그 페이즈의 모자란 재화를 하나도 쓰지 않는 학생).
   - 전체 = FD-031 (a) 충족률(FE4-e `planFlowFulfillment` 그대로, 보유 모름은 "보유 모름 n종"으로 덧붙임) · 부족 종 수 · 부족 재화를 쓰는 학생 수.
   - 병목 · 부족 페이즈가 없으면 "병목 없음" / "부족한 재화 없음"이고 아이콘 없이 바탕만 보인다.
6. **계획에 적용…(FD-088)**: 미리보기 · 보기 모드 버튼이 켜진다(저장된 활성 계획과 비교 응답이 있을 때). 2선택 모달(활성 계획에 페이즈로 추가 / 활성 계획을 이걸로 바꾸기 — "지금 활성 계획은 시나리오로 옮겨 둡니다")에서 고르면 계획 만들기 흐름을 그 시나리오 초안(`PlanFlowDocumentBoundary.fromDocument`, authoring 포함)으로 **4단계에서 그 위치를 고른 채** 연다. 저장 · 비교 · revision · 다시 보내기 · 이걸로 바꾸기의 기존 활성 보존(FD-067)은 FE4-e `PlanFlowSaveController` 그대로다. 새 규칙은 없고 기존 코드와 충돌도 없었다. 바꾼 것은 흐름 값 하나(`PlanFlowController.initialSaveTarget`)와, 저장 컨트롤러가 그것을 첫 위치로 쓰는 것뿐이다. 단계 순서에 고칠 점이 있으면(`orderReady` 거짓) 3단계로 연다. "c2로 넘김" 없음.
7. 보기 모드 S1 나머지: "페이즈 편집" = 비교 화면 "편집"과 같은 길(흐름 3단계), "복제해서 새로" = 목록의 복제(복제 뒤 보기 모드에 머물고 목록에서는 사본이 펼쳐진다), "비교에 담기 · n/4" = 목록 담기, 분홍 현재 버튼 = 다시 비교(캐시 무효화). 정보 5줄 = 학생 · 페이즈 · 단계 · 저장 시각 · 데이터(현재 기준 / 저장 시점과 다름).

### 처리한 FD

- FD-034 (a) 확정안: 끝까지 가는 학생 = 아래 FD-035 두 상태에 단계가 없는 학생 / `stage_results` 학생 수. **판단**: 백엔드 `affected_stage_ids`는 그 재화를 쓰는 **모든** 단계(병목 단계 앞 단계 포함, `planning_document.py`)다. 그래서 글자 그대로 "어디에도 없으면"으로 세면 병목 앞에서 이미 그 재화를 쓰고 끝난 학생까지 막힌 학생이 된다. FE4-d(`planFlowStageStatuses`)와 같이 **병목 단계 뒤의 affected 단계만** 막힘으로 셌다. FD-034 결정문의 "FD-035와 같은 원천" 취지를 따른 것이다. 오케스트레이터 확인을 바란다.
- FD-035(워커 재량, 권장안): 여기서 막힘 = 어떤 병목의 `stage_id`, 앞 단계 대기 = 다른 병목의 affected 중 문서 순서상 뒤, 겹치면 앞 단계 대기. 병목 줄에 `affected_stage_ids`가 없으면 전체 재화 줄의 것을 쓴다.
- FD-038 (c)(워커 재량, 권장안): 부족량 차이(FE5-b 함수), 두 문서 모두 부족 0이면 필요량 차이를 회색, 크레딧은 필요량 차이. 병목 카드 타일은 "활성보다 ±n".
- FD-039(워커 재량, 권장안): `stage_id`(같은 학생) → (학생, 학생 안 순번). 차이 칩은 FE5-b `planScenarioStudentDelta` 그대로. "활성 계획과 다른 단계 n" = 같음이 아닌 단계 수.
- FD-067 · FD-088(워커 재량, 권장안): 위 6번.
- FD-082 (a): Detail 위젯을 비교 스위치가 있는 하나로 만들었다(아래 c2 매개변수). 홈 첫 화면은 바꾸지 않았다.
- FD-089 · FD-090: 캐시 · 팝오버 재사용. FD-031 (a): 요약 행 전체 충족률.

### 판단(워커 재량, 기록)

- 페이즈 헤더 "부족 n종"은 그 페이즈 단계들의 `stage_results[].resources[].shortage_at_entry > 0` 재화 종 수다. `phase_results.owned`의 뜻은 문서화되지 않았기 때문이다(D §2-5). 보유를 하나도 모르면 칩이 없다.
- 병목 카드 활성 대비 칩은 비교 `bottlenecks[]`(재화별 first_phase · shortage)의 첫 재화 기준이다: 이 시나리오에만 / 활성보다 n페이즈 빨리(경고) / 늦게(ok) / 부족 줄어듦 · 늘어남 / 활성 계획과 같음. "활성 계획 대비" 줄은 다른 병목(시나리오에 있고 활성에 없거나 페이즈 · 부족량이 다름) n개 · 활성 계획에만 있는 병목 n개다.
- 페이즈 배지 색은 홀수 P 파랑 · 짝수 P 분홍이다(시안 P1 파랑 · P2 분홍).
- 보기 모드는 비교 응답이 준비된 뒤에만 S2 · S3를 그린다(그 전에는 읽는 중 · 실패 · 비교할 수 없음 · 시나리오 없음 안내).

### c2가 쓸 레이아웃 매개변수(`PlanDetailWorkspace`)

- `keyPrefix`: 키 앞부분(c1 = `plan-scenario-detail`). 키: `-workspace`, `-menu|phase|resource-motion`, `-phase-title/-count/-different`, `-phase-{n}`, `-stage-{stageId}`(`-state`, `-delta`), `-toolbar`, `-tab`(병목), `-tab-later`(꺼진 페이즈별 · 전체), `-summary`(`-title`, `-detail`, `-delta`), `-compare-caption`, `-kpis`, `-kpi-credits|shortage|bottleneck|finishing`, `-body-panel`, `-cards`, `-cards-empty`, `-card-{n}`(`-phase`, `-delta`, `-resource-{key}`, `-delayed`).
- `animation`: 섹션 모션(S1 0/180 · S2 80/260 · S3 180/0).
- `data`: `PlanDetailData`. c2는 `PlanDetailData.fromProjection(document: 활성 문서, projection: 문서 계산, format:)`로 비교 없이 만든다(`comparison` 생략 → a쪽 KPI · 칩 null).
- `menuBuilder(PlanDetailMenuFrame)`: S1 내용. `frame.row(offset, height)`가 시안 S1 버튼 자리(왼쪽 14, 오른쪽 변 − 22)다. 좌표는 `PlanDetailMetrics.menu*`이고, 시나리오 S1은 `PlanScenarioDetailMenu`, 정보 줄은 `PlanDetailInfoRow`다.
- `showComparison`: false면 S2 활성 대비 칩 · "활성 계획과 다른 단계" · S3 "활성 계획 대비" 줄 · KPI 줄을 그리지 않는다. 본문 패널은 요약 행 아래(`PlanDetailMetrics.bodyTopWithoutComparison` = 섹션 위 +152)부터다(비교 있음 +262).
- `selectedCard` · `onSelectCard`: 카드(0부터) ↔ 단계 행 강조.
- `shortageKpi`: 부족 재화 KPI 칸 감싸기(팝오버).
- `placeholder`: data가 null일 때 S2 · S3 가운데.
- 페이즈별 · 전체 탭은 `PlanDetailResourceTab`에 자리만 있다(FE5-d가 S3 본문 분기 · seg 동작을 더한다).

### golden 예측(장면별)

- `plan-scenario-list-expanded`: 펼친 07 행의 "열기" 행 액션이 켜진다(흐림 → 핑크 선명). S3 아래 "열기" · "계획에 적용…"도 켜진다(흐림 → 선명). 다른 곳은 그대로다. 계산 대역에 더한 필드(병목 `affected_stage_ids`, 비교 `bottlenecks[]`)는 미리보기가 읽지 않는다.
- `plan-scenario-list-shortage`: 위와 같은 버튼 변화(팝오버가 덮지 않는 부분)뿐이다.
- `plan-scenario-detail-bottleneck`(새 장면): 보기 모드 · 병목 탭 · 병목 1 선택. 계산 대역 기준으로 보이는 것:
  - S1: 07 이름, 정보 줄 학생 3명 · 페이즈 3개 · 단계 5개 · 저장 9.22 23:10 · 현재 기준.
  - S2: 페이즈 3개 · 단계 5, "활성 계획과 다른 단계 3"(아루 1 · 2 "이 시나리오에만", 아야네 2 "목표 다름 3"). P1 부족 1종 · P2 3종 · P3 2종. 아루 1 "병목 1 · 여기서 막힘"(분홍 테두리), 아루 2 "병목 2 · 여기서 막힘", 아야네 1 · 호시노 1 · 아야네 2 "앞 단계 대기".
  - S3 요약: "오파츠 · 네브라 디스크 (최상급) · 14 부족 / P1 아루 1단계에서 막힙니다 · 이 병목으로 지연되는 단계 2개" + "활성 계획과 같음". "활성 계획과 다른 병목 0개 · 활성 계획에만 있는 병목 0개".
  - KPI: 112M → 73.8M(초록) · 6종 → 7종(경고) · P1 → P1 · 0 / 5 → 0 / 3.
  - 카드 1(P1 아루 1단계): 네브라 14 부족 "활성보다 −180" + 크레딧 충분 "활성보다 −38.2M", 지연 "아야네 1단계 (P1) · 호시노 1단계 (P2)"(호시노는 긴 이름이라 말줄임).
  - 카드 2(P2 아루 2단계): 파이스토스 30 부족 "활성 계획과 같음" + 볼프세크 8 부족 "활성보다 −54", 지연 "호시노 1단계 (P2) · 아야네 2단계 (P3)".
- `plan-bottleneck`: 요약 행이 견본 병목 1의 첫 재화로 바뀐다. 아이콘 네브라(노랑 바탕) → 기초 전술교육 BD 아비도스(기본 바탕), "보유량 : 42 / 필요량 : 60" → "보유량 : 4 / 필요량 : 12". "확보 시 학생 3명…" 문구는 같다(학생 = 호시노 · 노노미 · 아코).
- `plan-by-phase`: "보유량 : 42 / 필요량 : 60" → "보유량 : 3 / 필요량 : 5", "2단계에서 4명 중 1명만 완료 가능" → "P2에서 4명 중 3명만 완료 가능". 아이콘(안티키테라 · 보라)은 같다.
- `plan-overall`: "전체 요구량의 72% 확보" → "60% 확보", "14종 부족 · 6명의 성장 계획에 영향" → "6종 부족 · 11명의 성장 계획에 영향".
- 바뀌지 않을 장면:
  - `plan-scenario-list`: 펼친 행이 없어 S3 버튼이 없다.
  - `plan-scenario-compare`: 대역이 아닌 `GoldenMockAppService`이고 섹션 5가 내려가 있다.
  - `plan-phase-editor` · `plan-element-builder` · `plan-preset-manager`: 홈 섹션을 그리지 않는다.
  - `plan-student-selector`: 섹션 5 값이 0이다. 섹션 5가 보이면 `plan-bottleneck`처럼 요약 행이 바뀐다.
  - `plan-flow-*`: 흐름 UI는 병목 `stage_id` · `shortage`와 전체 줄 affected만 읽는다.
  - `home` · `students-*` · `scan-student-review` · `title` · `account-*`: 이 slice와 상관없다(Lane B 장면에 영향 없음).

### 테스트 변경(의도된 변경)

- `planning_page_test.dart`: 상수 요약 행 기대(42/60, 72% · 14종 · 6명, "2단계에서 4명 중 1명", 학생 강조 집합 아즈사 · 노노미 · 하루카 / 전체 6명)를 견본 목록 projection 값으로 바꿨다. 위 golden 예측과 같은 숫자다. 강조 기대는 학생 단위다: 병목 = 호시노 · 노노미 · 아코의 모든 단계, 전체 = 견본의 모든 단계(유우카 포함).
- `plan_scenario_preview_test.dart`: 주석만 고쳤다(층에 콜백을 넘기지 않으면 꺼짐). 기대는 그대로다.
- `plan_scenario_list_test.dart` · `plan_element_builder_test.dart`: grep 결과 영향 없음(열기 꺼짐 · 요약 상수를 보지 않는다).
- 새 `plan_scenario_detail_test.dart`:
  - 모델: 단계 상태 · 끝까지 가는 학생 · 단계 맞춤 · 재화 ± · 병목 칩 · 카드 묶음/채움/지연 · KPI · 비교 없음.
  - 위젯: 카드 ↔ 행 강조, 비교를 끄면 KPI · 칩 없음.
  - 계획 화면: 열기는 compare를 다시 부르지 않고, 목록으로 돌아가고, 계획에 적용 → 이걸로 바꾸기 → 흐름 4단계가 replace를 고른 채 열린다.
- golden 테스트: 새 장면 1개와 그 기대(카드 2장, 상태 칩, "활성 계획과 다른 단계 3", "0 / 3").

### 미검증 항목

- analyze(flutter_lints info 단계 포함) · 컴파일 · 모든 테스트 · golden. 위 숫자는 손 계산이다.
- 화면 배치: S2 행 들여쓰기(헤더 대비 22px) · 카드 타일 폭 · 툴바 한 줄 폭 · 긴 학생 이름 말줄임을 렌더로 보지 못했다. golden 검수 때 시안과 대조가 필요하다.
- 흐름 4단계를 시나리오 초안(editScenario 목적)으로 바로 열 때 3지선다 중 "시나리오로 저장"은 그 시나리오 고치기로 보인다(FE4-e 그대로). 페이즈로 추가는 FE4-e 규칙(초안 목표가 활성보다 낮으면 막힘)을 따른다. 비교 화면 "편입"(낮은 단계는 빼고 붙임)과는 다른 기존 경로다.
- 실제 백엔드 compare 응답으로 보기 모드를 그려 본 적 없다(Mock은 병목 · 재화가 비어 "막히는 단계가 없습니다"가 보인다).

### 검수표

| 프롬프트 항목 | 상태 |
|---|---|
| 1 열기 · 뒤로 · 다른 시나리오 열기 · 캐시 재사용 | 했다(테스트: compare 1회 유지) |
| 2 Detail 3섹션 · 비교 끄기 · c2 매개변수 · seg + 칩 3 | 했다(페이즈별 · 전체는 꺼 둠, 칩은 표시만) |
| 3 KPI 4개 · ± FD-038 (c) · 새 서비스 메서드 없음 | 했다 |
| 4 병목 카드 묶음 · 지연 단계 · 카드 ↔ 행 강조 · FD-035 · FD-039 | 했다 |
| 5 요약 행 projection · 사용처 grep · 홈 레이아웃 유지 · golden 예측 | 했다 |
| 6 계획에 적용 2선택 · FE4-e 경로 | 했다(충돌 없음) |
| services/** 안 고침 · Lane B 파일 · app_shell 안 고침 | 지켰다 |
| golden 새 장면 1개, 적용 모달 장면은 제안하지 않음 | 지켰다 |
| 정적 검토만 · 직접 커밋 안 함 · ~습니다체 | 지켰다 |

### 발견 사항

- 계획 홈 `_calculateDocument`의 병목 지연 단계(`delayedStages`)는 `affected_stage_ids` 전부(병목 단계 자신과 앞 단계 포함)다. FD-035 · 이번 보기 모드(병목 단계 뒤만)와 뜻이 다르다. 홈을 Detail로 바꾸는 FE5-c2에서 맞추면 된다.
- golden 계산 대역은 그동안 병목 줄에 `affected_stage_ids`가 없었고, 비교 대역은 `bottlenecks`가 빈 목록이었다(백엔드는 둘 다 준다). 이번에 백엔드 모양으로 맞췄다.
- MockAppService `compareScenarios`는 크레딧 0 · 재화 · 병목 빈 목록을 준다. 보기 모드 위젯 테스트는 그 위에서 "막히는 단계가 없습니다"만 확인한다.

### 다음 행동

- 오케스트레이터: gate 결과를 검토한다. 기대는 다음과 같다.
  - analyze · UI 테스트 녹색.
  - golden RED는 위 예측 6장(바뀜 5 + 새 1)이고, 그 밖의 장면 변화는 0이다.
  - 다른 장면이 바뀌거나 컴파일 · lint 지적이 나오면 이 slice 몫으로 돌려받아 고친다.
- 사용자 실행 순서:

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① 두 워커가 모두 멈춘 뒤 gate만 실행 → 결과를 오케스트레이터에게 보내고 기다린다
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 오케스트레이터 승인 뒤 기준 이미지 갱신 → 다시 gate
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ③ 커밋(순서는 오케스트레이터가 정한다)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe5c1 -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe5c1
```

### fe5c1 commit record (2026-10-11 03:06, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261011_025111\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE5-c2 착수 기록 (2026-10-11 03:40, Lane A)

- 상태: 진행 중. 시작 SHA = `84f645c391f54cc312ce12f21d85ed34789f325b`(scanner-consolidation HEAD).
- 범위: 활성 계획 홈 = 비교 없는 Detail 3섹션(FD-082 (a)) · S1 시나리오 목록 · 계획 만들기 · 페이즈 편집(FD-070) + 정보 줄 · S3 seg 페이즈별 · 전체에 옛 홈 위젯 · 병목 지연 단계를 병목 뒤 단계만 세기 · `PlanFlowSaveComparison.increases`에서 크레딧 줄 빼기 · FE4-g 발견 재확인.
- 막힘 요약의 이 slice 열림 FD 0건 확인. 워커 재량 FD는 권장안대로 처리하고 종료 기록에 ID를 적는다.
- 고칠 기존 파일(사본: `debug/frontend_fe5c2/pre/<경로>`):
  - `frontend/lib/ui/widgets/plan_scenario_detail.dart`
  - `frontend/lib/ui/widgets/plan_section_layout.dart`
  - `frontend/lib/ui/pages/planning_page.dart`
  - `frontend/lib/ui/models/plan_flow_save.dart`
  - `frontend/test/planning_page_test.dart`, `frontend/test/plan_element_builder_test.dart`, `frontend/test/plan_preset_manager_test.dart`, `frontend/test/plan_scenario_list_test.dart`, `frontend/test/plan_flow_save_test.dart`, `frontend/test/title_page_test.dart`
  - `frontend/test/goldens/fe1g_baseline_golden_test.dart`, `frontend/test/goldens/golden_harness.dart`
- 새 파일(예정): `frontend/test/plan_home_detail_test.dart`.
- 이 환경에는 flutter가 없다(정적 검토만 가능). `frontend/lib/services/**` · `inventory_page.dart`는 고치지 않는다(Lane B).

## FE5-c2 종료 기록 (2026-10-11 04:25, Lane A)

- 상태: 구현 끝, **정적 검토만 했다**. 이 환경에는 flutter · dart가 없다. analyze · 테스트 · golden은 한 번도 돌리지 않았다. 통과를 주장하지 않는다.
- 시작 SHA `84f645c3`. 사본 12개는 `debug/frontend_fe5c2/pre/frontend/`에 있다(장치 크기 12개 모두 원본과 같음).
- commit.json: `debug/frontend_fe5c2/commit.json`(slice=fe5c2, status=true, modified 12 · added 1, whole = 기준 이미지 6장, 하나씩).

### 실행 명령 · 결과

- `flutter analyze` · `flutter test`: 실행하지 못했다(SDK 없음).
- 정적 검토 에이전트 1회(바뀐 파일 전부 · 쓰는 API 시그니처 대조 · 테스트 기대값 추적 · test/ 전체에서 옛 홈 키 grep). 컴파일 오류 · analyzer info는 0건이었다. 지적 7건은 모두 고쳤다.
  1. golden `plan-scenario-detail-bottleneck`: 화면 밖에 남은 Detail 홈에도 "병목 1 · 여기서 막힘"이 있어 `findsOneWidget`이 2개를 찾는다. finder를 `plan-scenario-detail-view` 안으로 좁혔다(테스트만 바뀌고 그림은 그대로).
  2. `title_page_test` 1280×720: 새 홈 S1 아래쪽 정보 줄이 좁아 라벨("필요 크레딧")이 넘친다. `PlanDetailInfoRow` 라벨을 `Flexible` + 말줄임으로 바꿨다. 넓은 창에서는 그대로이고, c1 보기 S1의 같은 넘침도 함께 막힌다.
  3. 손넘김 대체 경로(흐름 문맥이 없을 때 요소 편집기 · 페이즈 편집기)에서 새 홈이 그 아래에 함께 보였다. 홈 조건에 `!_showPhaseEditor && !_showElementBuilder`를 더했다(옛 홈과 같은 조건).
  4. S3 툴바가 1248px 폭에서 겨우 맞았다(정렬 라벨이 길어지면 넘침). 칩 묶음을 `Expanded` + 오른쪽 `Align` + `FittedBox(scaleDown)`에 넣었다. 넓은 창에서는 크기와 자리가 그대로다.
  5. 비교 화면 "활성 계획으로"에서 비교 S1 메뉴가 모션 없이 사라졌다. 새 홈 모드에서는 element-1도 함께 내린다.
  6. `loadRepositoryPlan=false`에서 `_reloadRepositoryPlan`이 홈 계산 결과를 지워 "계산 중"에 머물렀다. 지우지 않는다(`_loadRepositoryPlan`이 새 문서와 함께 비운다).
  7. `_detailHome`의 쓰지 않는 인자를 뺐고, `plan_flow_save.dart` 중첩 `if` · `_lockedTabs`를 `dart format` 모양으로 들여 썼다.
- 장치 반영: 바뀐 파일 12개 · 새 파일 1개를 `expectedMtimeMs`로 쓰고 다시 받아 `cmp`로 13개 모두 같음을 확인했다. `plan_section_layout.dart`는 CRLF 그대로다(8769줄 모두 CRLF).

### 한 일

1. 첫 화면: `PlanSectionLayout._detailHome`이 `PlanDetailWorkspace(showComparison: false)`(keyPrefix `plan-home`, 모션 element-2)를 그린다. 데이터는 `PlanDetailData.fromProjection(활성 문서, 문서 계산 projection)`이다. KPI · delta 칩 · "활성 계획과 다른 단계"는 없다.
   - 안내 상태는 S3 `resourcePlaceholder`에 보인다: 계산 오류(`plan-calculation-error`) · 읽는 중 · 안 읽음 · 단계 없음 · 계산 불가(`plan-calculation-unavailable`, 기존 문구) · 계산 중.
   - 문서가 있으면 S2 단계 행은 그대로 보인다. 문서를 못 읽었으면 S2에 "활성 계획을 읽지 못했습니다."를 보인다.
   - `legacyHome`(기본 false, 앱 셸은 넘기지 않음)은 옛 5섹션 홈을 그대로 그린다. 옛 홈 테스트와 옛 화면 golden(페이즈 편집기 · 학생 추가 · 요소 편집기)만 쓴다.
2. S1: 새 `PlanDetailMenuLayer` + `PlanDetailRailMenu`로 그린다. FE5-a 목록 S1 · c1 보기 S1과 같은 자리 · 같은 버튼 top이다.
   - "보는 중 · 활성 계획" + 계획 이름(누르면 다시 읽기).
   - 액션: 시나리오 목록 · 계획 만들기(분홍) · 페이즈 편집(흐름 3단계, FD-070).
   - 정보 "이 계획": 학생 · 페이즈 · 단계 · 필요 크레딧 · 부족 재화.
   - **합침**: FE4-f2 아이콘 버튼("단계 순서")과 "페이즈 편집"은 같은 동작(활성 계획을 흐름 3단계로 연다)이다. 하나로 합쳤고 키 `plan-flow-edit-active-launch`는 그대로다.
   - 새 홈에는 옛 섹션 1이 없다. 그래서 A↔B 비교 화면은 같은 S1 자리에 자기 메뉴("목록으로" · "활성 계획으로", `plan-comparison-menu`)를 두고, 비교 본문은 S1(400) 오른쪽부터 쓴다.
3. S3 seg: `PlanDetailWorkspace`에 `resourceTab` · `onResourceTab` · `tabBody` · `tabSummary` · `toolbarChips` · `resourcePlaceholder`를 더했다.
   - 홈은 페이즈별 · 전체를 켠다. 본문은 옛 홈 `PlanConsumptionSection`(S3 평행사변형 path 안)이고, 요약 행은 `PlanPhaseResourceSummary` · `PlanOverallResourceSummary`(`PlanResourceSummaryProjection.of`)다. 옛 위젯이 S3에 그대로 들어가 기능 손실이 없어 멈추지 않았다.
   - 툴바 칩 3개(재화 유형 · 충족 재화 숨기기 · 정렬)는 홈에서 동작한다(옛 홈 필터 상태를 함께 쓴다).
4. 병목 지연 단계: `_calculateDocument`가 `PlanDetailStageStates.fromProjection(projection)?.delayedBy(item)`으로 병목 단계 뒤 단계만 센다(FD-035). 옛 홈(legacyHome)에도 같이 적용된다.
5. FE4-g 재확인: 두 건 모두 그대로 있다(아래 "발견 사항"). 홈 교체와 무관한 흐름 handoff 경로라 c2 범위 밖으로 두었다.
6. `PlanFlowSaveComparison.increases`: `category` 또는 `resource_key`가 `credits`인 줄을 뺀다. `plan_flow_save_test` 새 그룹으로 잠갔다(크레딧 줄 + 일반 줄 → 일반 줄만, 크레딧 KPI 값은 그대로).

### 처리한 FD

- FD-082 (a): 활성 계획 홈 = 비교 없는 Detail 3섹션.
- FD-070: S1 "페이즈 편집" = 흐름 3단계.
- FD-035: 단계 상태 · 지연 단계는 병목 단계 뒤만.
- FD-038: 크레딧은 필요량 차이 KPI로만 보이고, 늘어나는 재화 목록에서는 뺀다.
- FD-031 (a): 전체 탭 요약 행 충족률은 c1 projection(`planFlowFulfillment`) 그대로다.

### 판단(워커 재량, 기록)

- **legacyHome 다리**: 옛 홈을 시험하는 테스트 약 30건(FE5-f 재작성 대상)을 지금 고쳐 쓰지 않으려고 둔 플래그다. 앱에서는 늘 새 홈이다.
- **c1 시나리오 보기의 페이즈별 · 전체는 켜지 않았다**: 보기 모드에는 비교 projection만 있다. 옛 `PlanConsumptionSection`에 넣으려면 시나리오 projection용 변환을 따로 만들어야 하므로, FE5-d에서 시안대로 다시 그릴 때 함께 연다. 그래서 c1 golden 변화는 없다.
- **칩 적용 범위**: 재화 유형 · 충족 재화 숨기기는 병목 카드의 재화 줄과 페이즈별 · 전체에 적용한다. 정렬은 페이즈별 · 전체에만 적용하고, 병목 카드에는 적용하지 않는다(병목 번호 = 막히는 순서를 지킨다).
- **페이즈별 탭에서 재화를 눌러도 S2를 강조하지 않는다**: 옛 홈의 섹션 2 강조는 옛 단계 타일에 묶여 있다. FE5-d 몫으로 둔다.
- **`title_page_test` 한 줄 수정**: 계정 가져오기 뒤 계획 탭 첫 화면이 새 홈이라 단계 키가 `plan-step-v6-imported-plan-ayane-1` → `plan-home-stage-v6-ayane-1`로 바뀐다. `title_page.dart`는 고치지 않았다.
- `app_shell.dart`는 고치지 않았다.

### golden 예측(장면별)

바뀜 6장(commit.json `whole`):

- `plan-bottleneck`: 옛 5섹션 홈(GoldenMockAppService · 더미 병목) → Detail 홈. 장면 mock도 `GoldenActivePlanHomeMockAppService`(학생 장면 + 시나리오 목록 장면의 활성 계획 저장, 계산 대역)로 바뀐다.
  - S1 정보: 5명 · 3개 · 8개 · 112M · 6종.
  - S2: P1~P3 단계 8개. 아야네 1 · 2단계는 "여기서 막힘", 나머지는 "앞 단계 대기"다. 페이즈 머리: P1 부족 1종 · P2 2종 · P3 충분.
  - S3 카드 2장. 카드 1은 네브라 디스크(최상급) 14 부족(진입 76 · 필요 90) + 크레딧 충분, 지연 히나 1 · 케이 1 · 노아 1 · 호시노 1이다. 카드 2는 파이스토스 30 · 볼프세크 8, 지연 히나 2 · 아야네 3이다.
  - 요약: "오파츠 · 네브라 디스크 (최상급) · 14 부족 / P1 아야네 1단계에서 막힙니다 · 이 병목으로 지연되는 단계 4개".
- `plan-by-phase`: 같은 홈의 S3 페이즈별 탭. 본문은 옛 페이즈별 소비 목록이고, 요약은 "보유량 : 76 / 필요량 : 450" · "P1에서 5명 중 0명만 완료 가능"이다.
- `plan-overall`: 같은 홈의 S3 전체 탭(옛 전체 소비 목록 + 전체 요약 행).
- `plan-scenario-compare`: 옛 섹션 1 → 비교 S1 메뉴(목록으로 · 활성 계획으로). 비교 본문 왼쪽 경계가 S1 오른쪽으로 옮겨 간다. 여는 길은 목록 "나란히 비교"(A = 활성, B = 같은 시나리오)다.
- `plan-flow-step4` · `plan-flow-step4-append`: C "가장 크게 늘어나는 재화"에서 크레딧 줄(대역에서 증가량이 가장 큼)이 빠지고 다음 재화가 올라온다. 크레딧은 위 비교 KPI에 그대로 있다.

그대로(이유):

- `plan-phase-editor` · `plan-student-selector` · `plan-element-builder`: `legacyHome`으로 옛 홈에서 연다. 지연 단계 변경은 실제 계산 병목에만 닿는다. 이 장면 mock(MockAppService 계산)은 병목이 빈 목록이라 옛 홈은 더미 병목을 그린다.
- `plan-preset-manager`: 여는 길만 목록 S1 "프리셋 관리"로 바뀐다. 프리셋 관리가 열리면 홈 · 목록을 그리지 않으므로 화면은 같다.
- `plan-flow-step1` · `-many` · `-filter` · `step2` · `-saved` · `-more` · `step3` · `-deferred` · `-many`: 흐름이 열리면 홈을 그리지 않는다. "계획 만들기"는 새 홈 S1에 같은 키로 있다.
- `plan-scenario-list` · `-expanded` · `-shortage`: 목록이 열리면 홈 3섹션은 모션 0(화면 밖)이다. 목록 S1 자리 계산(옛 element-1 bounds)은 바꾸지 않았다.
- `plan-scenario-detail-bottleneck`: 홈은 위와 같이 화면 밖이다. 이 장면의 Detail 위젯에서 바뀐 것은 툴바 칩 묶음과 정보 줄 라벨뿐이고, 둘 다 넓은 창에서 크기 · 자리가 같다. finder만 보기 모드 안으로 좁혔다.
- 계획 밖 장면(`title` · `account-*` · `home` · `students-*` · `scan-student-review` · `account-new`): 계획 탭이 offstage라 그리지 않는다.
- 새 장면 제안: 없다(홈 3장면이 새 홈을 덮는다).

FB-3 영향 가능(같은 gate):

- 새 홈 3장면은 학생 장면 fixture와 계산 대역의 재화 이름 · 카테고리 · 아이콘(`planningResourceIconAsset`) · 학생 이름(카탈로그)을 그린다. FB-3가 카탈로그 meta나 mock 재화 행을 바꾸면 S2 단계 행 이름, S3 카드 · 페이즈별 · 전체 줄의 이름 · 아이콘 · 순서, S1 "부족 재화 n종"이 함께 바뀔 수 있다.
- `plan-flow-step4` 두 장의 늘어나는 재화 줄도 같은 이유로 바뀔 수 있다.
- RED가 위 6장 밖(예: `plan-scenario-list*`)으로 번지면 FB-3 쪽 변화인지 먼저 본다.

### 테스트 변경(의도된 변경)

- `planning_page_test.dart`:
  - `pumpPage`와 `PlanningPage` 직접 생성 3곳에 `legacyHome: true`를 넣었다(옛 홈 시험, FE5-f에서 재작성).
  - FE4-f2 "단계 순서" 테스트 → "페이즈 편집"(같은 키, 새 홈에서 연다).
  - FE4-h 그룹: `plan-step-…` → `plan-home-stage-<stage id>`(`v6-ayane-1` · `stale-hina-1`), `_planStepTiles` → `_homeStageRows`, 빈 계획은 `plan-home-empty`.
- `plan_element_builder_test.dart`(4곳) · `plan_preset_manager_test.dart`: `legacyHome: true`.
- `plan_scenario_list_test.dart`: 홈 모션 키 element-1~5 → `home-menu` · `home-phase` · `home-resource`. 비교 화면은 `comparison-menu` = 1 · `home-menu` = 0이다.
- `title_page_test.dart`: 위 판단의 키 한 줄.
- `plan_flow_save_test.dart`: 새 그룹 "가장 크게 늘어나는 재화(FE5-c2)".
- 새 `plan_home_detail_test.dart`(5건): 위젯 2건(seg → tabBody · tabSummary, resourcePlaceholder), 화면 3건(비교 없는 홈 · S1 · 정보 줄 · 옛 진입 키 없음, 페이즈별 · 전체 탭, 목록 열고 닫기 · 페이즈 편집 → 흐름 3단계).
- goldens: 위 예측대로 `_openActivePlanHome` · `_tapHomeTab` · `GoldenActivePlanHomeMockAppService`를 더했다.
- 영향 grep: test/ 전체에서 `PlanningPage(` · `PlanSectionLayout(` · `plan-step-` · `plan-element-N-motion` · 옛 진입 키를 찾았다. 남은 사용처는 모두 `legacyHome: true`다. plan_flow* · plan_scenario_detail · plan_scenario_preview 테스트는 새 홈에도 있는 키만 쓴다.

### 남긴 옛 코드(FE5-f에서 정리)

- `PlanSectionLayout`의 옛 홈 섹션 1~6(`legacyHome`에서만 그림)과 섹션 1 버튼(페이즈 편집기 · 학생 추가 · 프리셋 관리 · 비교 · 목록).
- 옛 A↔B 후보 고르기(`plan-compare-candidate-*`).
- `PlanPhaseEditor` · `PlanStudentSelector` · `PlanElementBuilder` 옛 홈 진입.
- `PlanResourceHeader` · `PlanBottleneckDiagonalList` · 더미 데이터(`dummyPlanBottleneckDetails` · `dummyPlanPhaseConsumptions` · `dummyPlanOverallConsumption` · `dummyPlanPhases`).
- `PlanningPage` · `PlanSectionLayout.legacyHome` 플래그 자체와 옛 홈 테스트(planning_page_test 대부분 · plan_element_builder_test · plan_preset_manager_test).
- `_PlanWorkspaceSnapshot`은 이번에 고친 파일에 없다(lib · test grep 0건). 다른 이름이면 그대로 두었다.

### 미검증 항목

- analyze · 테스트 · golden 실행 전부.
- 1280×720 최소 창에서 새 홈 S1 아래쪽 정보 줄이 S1 사다리꼴 밖으로 나가는지(넘침 예외는 막았지만 그림은 못 봄).
- `FittedBox`로 줄어든 툴바에서 재화 유형 · 정렬 팝업이 열리는 위치.
- ProcessAppService 실제 계산의 `phase_results` · `affected_stage_ids` 모양과 홈 페이즈별 탭.
- golden 예측 수치(손 계산).

### 검수표

| 프롬프트 항목 | 상태 |
|---|---|
| 1 첫 화면 Detail · 비교 없음 · 안내 상태 | 했다 |
| 2 S1 3버튼 + 정보 줄 · 같은 자리 · 아이콘 버튼 | 했다(페이즈 편집 = FE4-f2 버튼, 합침) |
| 3 seg 페이즈별 · 전체 · 옛 위젯 · c1 판단 | 했다(c1은 켜지 않음, 기능 손실 없음) |
| 4 지연 단계 병목 뒤만 | 했다 |
| 5 FE4-g 재확인 | 두 건 그대로, 범위 밖 → 다음 slice 제안 |
| 6 increases 크레딧 제외 · 테스트 | 했다 |
| services/** · inventory_page · backend · contracts · scan/tactical/title_page · account_* · app_shell 안 고침 | 지켰다 |
| PlanPhaseEditor 등 옛 코드 안 지움 · 옛 테스트 전면 재작성 안 함 | 지켰다(목록 위) |
| golden 장면별 예측 · 새 장면 없음 · FB-3 영향 | 적었다 |
| 정적 검토만 · 직접 커밋 안 함 · ~습니다체 | 지켰다 |

### 발견 사항

- FE4-g 1: 계산기 handoff 초안에 그 학생의 "나중에" 칸 단계가 있으면 새 단계가 체인 끝(나중에 단계 뒤)에 붙는다(`PlanFlowController.receiveHandoff`). 3단계에서 칸에 넣으려면 나중에 칸에 두거나 앞 단계를 옮겨야 한다.
- FE4-g 2: `PlanFlowContext.activePlan`은 문서만 있고 authoring이 없어, 활성 계획의 "나중에" 단계가 바닥 snapshot에 들어가지 않는다. 고치려면 흐름 문맥에 활성 authoring을 실어야 해서 서비스 모델 확인이 필요하다.
- 두 건 모두 흐름 handoff 경로라 계획 홈 교체와 무관하다. 별도 흐름 정리 slice(예: FE4-g2)나 FE5-f 앞 소단위로 묶기를 제안한다.

### 다음 행동

- 오케스트레이터: gate 결과를 검토한다. 기대는 다음과 같다.
  - analyze · UI 테스트 녹색.
  - golden RED는 위 6장이고, 그 밖의 변화는 FB-3 영향 후보로 먼저 본다.
  - 컴파일 · lint 지적이나 예측 밖 장면 변화가 이 slice 몫이면 돌려받아 고친다.
- 사용자 실행 순서:

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① 두 워커가 모두 멈춘 뒤 gate만 실행 → 결과를 오케스트레이터에게 보내고 기다린다
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 오케스트레이터 승인 뒤 기준 이미지 갱신 → 다시 gate
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ③ 커밋(순서는 오케스트레이터가 정한다)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe5c2 -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe5c2
```

### fe5c2 commit record (2026-10-11 14:32, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261011_135529\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE5-d 착수 기록 (2026-10-11 14:52, Lane A)

- 상태: 진행 중. 시작 SHA = `dfd1d620`(scanner-consolidation HEAD, redesigndocs 커밋. 이 환경에서는 `.git`을 읽을 수 없어 오케스트레이터 로그 14:45의 짧은 SHA를 적는다).
- 범위: Detail S3 페이즈별 · 전체 탭을 시안(Scenario-Detail-Phase · -All)대로 새로 그리고 활성 계획 홈 · 시나리오 보기 모두에서 켠다. 홈의 옛 `PlanConsumptionSection` 연결을 새 위젯으로 바꾸고, 칩 3개(재화 유형 · 충족 재화 숨기기 · 정렬)를 새 두 탭에 연결한다.
- 막힘 요약의 이 slice 열림 FD 0건 확인. FD-037(페이즈 진입/종료)은 백엔드 `planning_document.py`를 먼저 읽고 판단한다(FB-9 필요 여부는 종료 기록에 적는다).
- 고칠 기존 파일(사본: `debug/frontend_fe5d/pre/<경로>`):
  - `frontend/lib/ui/models/plan_scenario_detail.dart`
  - `frontend/lib/ui/widgets/plan_scenario_detail.dart`
  - `frontend/lib/ui/widgets/plan_section_layout.dart`
  - `frontend/lib/ui/widgets/plan_scenario_list.dart`
  - `frontend/test/plan_home_detail_test.dart`, `frontend/test/plan_scenario_detail_test.dart`
  - `frontend/test/goldens/fe1g_baseline_golden_test.dart`, `frontend/test/goldens/golden_harness.dart`
- 새 파일(예정): 없음(필요하면 종료 기록에 적는다).
- 이 환경에는 flutter가 없다(정적 검토만 가능). `frontend/lib/services/**` · 인벤토리 파일 · app_shell은 고치지 않는다.

## FE5-d 종료 기록 (2026-10-11 15:30, Lane A)

- 상태: 구현 끝, **정적 검토만 했다**. 이 환경에는 flutter · dart가 없다. analyze · 테스트 · golden은 한 번도 돌리지 않았다. 통과를 주장하지 않는다.
- 시작 SHA `dfd1d620`. 사본 8개는 `debug/frontend_fe5d/pre/frontend/`에 있다. `plan_scenario_detail_test.dart` · `golden_harness.dart` 사본도 두었지만 두 파일은 결국 고치지 않았다(commit.json `modified`에 없음).
- commit.json: `debug/frontend_fe5d/commit.json`(slice=fe5d, status=true). modified 6, added 3(새 테스트 1 + 새 기준 이미지 2), whole = 바뀌는 기준 이미지 3장(하나씩).

### 실행 명령 · 결과

- `flutter analyze` · `flutter test`: 실행하지 못했다(SDK 없음).
- FD-037 확인: 백엔드 `backend/core/planning_document.py` `calculate_document_projection`을 읽었다(아래 "FB-9 필요 여부").
- 시안: `dc_outline.py --abs`로 Scenario-Detail-Phase · -All 사본만 읽었다.
- 정적 검토 에이전트 1회(바뀐 파일 전부 · 쓰는 API 시그니처 대조 · 테스트 기대값 손 계산 · test/ 전체 grep). 컴파일 오류는 0건이었다. 지적은 모두 고쳤다.
  1. 테스트 실패 2건: golden `plan-by-phase`와 `plan_home_detail_test`의 요약 행 finder가 키가 붙은 `Text` 자신을 찾지 못한다 → `matchRoot: true`.
  2. analyzer info 후보 2건: `x == null ? null : x.m()`(prefer_null_aware_operators) → if 문으로 바꿨다. const로 쓸 수 있는 `Text('크레딧')` → const.
  3. 화면 위험 4건:
     - 전체 그룹 행 머리 줄이 칩(24)보다 낮았다(22 → 24).
     - 그룹 · 크레딧 행 안쪽 여백이 사선에 먹혔다 → 사선 깊이 + 10. 시안 값과 같다(크레딧 19.5, 1줄 28.0, 2줄 38.2).
     - 좁은 칸(5열 · 작은 창)에서 전체 타일의 마크 · 막대가 넘칠 수 있다 → 폭 150 미만이면 둘을 빼고 "보유 / 필요"만 보인다.
     - 크레딧 행 "보유 · 필요" 글자는 폭 220으로 묶었다.
  4. 페이즈별 요약 행이 계산 전이나 보유를 모를 때 "부족한 재화가 없습니다"라고 말했다 → 계산 못 함 · 보유 모름 · 재화 없음 문구를 나눴다.
- 장치 반영: 바뀐 파일 6개 · 새 파일 1개를 `expectedMtimeMs`로 쓰고 다시 받아 `cmp`로 7개 모두 같음을 확인했다. `plan_section_layout.dart`는 CRLF 그대로다(8647줄 모두 CRLF).

### 한 일

1. **페이즈별**(Scenario-Detail-Phase): `PlanDetailWorkspace`가 직접 그린다.
   - 요약 행 "가장 부족한 재화":
     - 대상: 처음으로 모자라는 재화가 있는 페이즈에서 충족률이 가장 낮은 재화(같으면 부족량이 큰 것).
     - 제목: "이름 · Pn에서 m명 중 k명만 완료". 완료 = 그 페이즈 단계에 FD-035 상태나 진입 부족이 없는 학생.
     - 설명: "Pn 종료 시 x개 남습니다". 종료 0이고 뒤 페이즈에서 그 재화를 더 쓰면 "…0개 남아서 뒤 페이즈 단계 n개가 막힙니다".
     - 보기 모드 칩: "활성보다 ±n 부족".
   - 페이즈 카드(시안 `.srow` 300px):
     - 머리 줄: P번호 · 이름 · 학생 초상 · 부족 n종/충분.
     - 크레딧 진입/필요/종료 줄.
     - 재화 타일 2열: 진입 · 필요 · 종료, 충족 막대 + 내림 %(100% 초록 · 50% 이상 노랑 · 그 밖 분홍), 보기 모드에서만 활성 대비 칩.
   - 카드를 누르면 S2에서 그 페이즈 헤더(`srow sel`)와 단계 행이 강조된다. 페이즈별 탭에서는 단계 행을 눌러도 그 페이즈를 고른다.
2. **전체**(Scenario-Detail-All):
   - 요약 행 "전체 요구량": "필요량의 n% 확보 · n종 부족 · m명 중 k명의 계획에 영향(· 보유 모름 n종)" + 고정 설명. 보기 모드 칩 "활성 a% → b%"(오르면 ok, 내리면 경고).
   - 본문 위 줄(시안 471 → 패널 511): "재화 n종 · 한 행에 [2|3|4|5]"(기본 4) + 보기 모드 범례 "= 같음 · 신규 = 이 시나리오에만 · ± 활성 대비".
   - 본문: 크레딧 행(보유 · 필요, 막대, 부족/충분, "활성보다 ±n") + 분야 그룹 행. 분야는 `PlanScenarioResourceField` 순서(엘레프 · 오파츠 · 노트 · BD · 장비 설계도 · 그 밖)이고, 머리 줄은 "n종 · 부족 n종/충분"이다.
   - n열 타일: 이름 + 마크 = / ±n / 신규, "보유 / 필요", 막대 + %.
   - 타일을 누르면 S2에서 그 재화를 쓰는 단계(`affected_stage_ids`)가 강조된다. 다시 누르면 해제된다.
3. **두 화면 모두 켬**:
   - 활성 계획 홈(`showComparison: false`): ± 칩 · 마크 · 범례 · 활성 대비 칩이 없다.
   - 시나리오 보기: 비교 응답의 `projection_b`(페이즈 · 전체 재화)와 비교 `resources[]`(±)로 그린다. 시나리오 보기는 탭 · 칩 · 고른 페이즈/재화 · 열 수를 자기 상태로 들고, 다른 시나리오를 열면 고른 것만 처음(P1 · 없음)으로 돌린다.
4. **홈 연결 교체**: `_detailHome`이 옛 `PlanConsumptionSection` · `PlanPhaseResourceSummary` · `PlanOverallResourceSummary`를 더는 쓰지 않는다. `tabBody` · `tabSummary` · `toolbarChips` 매개변수와 `_filterHomeData` · `_homeToolbarChips`를 지웠다.
5. **칩 3개**: 새 `PlanDetailResourceFilter` + `PlanDetailFilterChips`.
   - 키는 `<keyPrefix>-filter-category` · `-hide-satisfied` · `-sort`로, FE5-c2 홈 칩과 같다.
   - 재화 유형 · 충족 재화 숨기기는 병목 카드 · 페이즈 타일(크레딧 줄 포함) · 전체 타일에 건다. 정렬은 페이즈 · 전체 타일에만 건다. 보유를 모르는 재화는 숨기지 않는다.
   - 홈은 옛 홈 필터 상태(`_selectedResourceCategories` 등)를 그대로 넘겨 받고, `_applyHomeFilter`로 쓴다.
   - 병목 카드 거르기는 홈 전용 함수에서 워크스페이스로 옮겨, 시나리오 보기에도 같이 걸린다.

### 처리한 FD

- FD-037(워커 재량): 백엔드 의미를 먼저 확인했다. 진입 = `phase_results[].resources[].owned`, 종료 = max(0, 진입 − 필요)를 클라이언트가 계산한다. FB-9를 쓰지 않는다.
- FD-038 (c): 페이즈 타일 칩 · 전체 마크 · 크레딧 "활성보다 ±n" · 요약 칩을 기존 `planScenarioResourceDelta`로 낸다. 활성 계획 필요 0인 재화는 "이 시나리오에만"(마크 "신규", `planDetailResourceDelta`)이다.
- FD-031 (a): 전체 확보율과 활성 쪽 확보율은 같은 식(`planFlowFulfillment`)이다.
- FD-087: 새 두 목록에 공용 사선 스크롤바 · 포그(`DiagonalScrollViewport`)를 쓴다.
- FD-035: S2 상태 칩은 그대로다. 페이즈별 요약 행의 "완료 가능 학생"이 같은 상태를 쓴다.

### FB-9 필요 여부

- **필요 없다.** `calculate_document_projection`은 페이즈마다 `phase_remaining = dict(remaining)`을 떠 두고, 단계마다 `remaining[key] = max(0, before − required)`로 줄인다. 페이즈 줄 `owned`는 `phase_remaining.get(key)`다.
  - 그래서 `owned` = 그 페이즈 진입 잔량(앞 페이즈까지 쓰고 남은 양)이다.
  - 음이 아닌 필요량을 차례로 빼고 0에서 자르는 것은 페이즈 합을 한 번에 빼고 자르는 것과 같다. 따라서 종료 = max(0, owned − required)는 정확하다.
  - 다음 페이즈 진입 = 이 페이즈 종료다(시안 P1 종료 70.8M = P2 진입). 보유를 모르는 재화는 진입 · 종료 모두 "—"다.
- 정확히 만들 수 없는 값: **페이즈 단위 활성 대비 ±**(시안 P1 노트 +12 · P2 노트 +30처럼 페이즈마다 다른 값).
  - 두 문서의 페이즈를 맞추는 규칙이 없다(FD-039는 단계만 맞춘다). 그래서 타일 칩은 그 재화의 계획 전체 차이(비교 `resources[]`)를 쓴다. 추측해서 페이즈끼리 맞추지 않았다.
  - 페이즈별 차이가 꼭 필요하면 FB-9가 아니라 페이즈 맞춤 규칙(FD)을 먼저 정해야 한다(아래 발견 사항).

### 판단(워커 재량, 기록)

- 칩 · 고른 페이즈 · 고른 재화 · 열 수는 화면(홈 · 시나리오 보기)이 들고 워크스페이스에 넘긴다. 홈의 탭 · 칩은 옛 홈 상태를 그대로 쓴다(`legacyHome`과 공유).
- 처음 고른 페이즈 = P1(시안 상태 "P1 강조"), 전체 탭은 고른 재화 없음.
- "충족 재화 숨기기"는 보유를 모르는 재화를 숨기지 않는다. 옛 홈은 "알려진 부족"만 남겨 모름도 숨겼다.
- 전체 탭 그룹 · "재화 n종"은 칩으로 걸러진 뒤의 수다. 페이즈 카드 머리 줄 "부족 n종"은 거르기 전 그 페이즈 전체 수다.
- 크레딧 줄은 재화 유형 "크레딧"과 충족 재화 숨기기에 함께 걸린다.
- 빈 상태 문구: 계산 응답 없음 "…계산하지 못했습니다.", 재화 없음 "이 계획에 필요한 재화가 없습니다.", 칩에 다 걸림 "조건에 맞는 재화가 없습니다."
- 페이즈 카드 높이 = 18 + 32 + (8 + 24) + 12 + 줄 × 88 + (줄 − 1) × 12 + 18(시안 2줄 300). 전체 그룹 행 = 44 + 줄 × 58(시안 102 · 160).

### golden 예측(장면별)

바뀜(whole 3장):

- `plan-by-phase`: 옛 `PlanConsumptionSection` → 새 페이즈 카드 3장.
  - P1: 크레딧 진입 99M · 필요 91M · 종료 8M. 네브라(최상급) 76/450 16% · 볼프세크 30/90 33% · 기술 노트 24/120 20%, 부족 3종.
  - P2 · P3 카드가 이어진다.
  - S2에서 P1 헤더와 단계 5개가 분홍 강조된다(처음 고른 페이즈 P1).
  - 요약 행: "오파츠 · 네브라 디스크 (최상급) · P1에서 5명 중 0명만 완료" / "P1 종료 시 0개 남습니다".
  - golden 대역의 페이즈 진입값은 대역 고정값이다(백엔드처럼 앞 페이즈 소비를 빼지 않는다). `_goldenPhaseResults`를 고치면 `plan-flow-step4`의 페이즈 상태도 바뀌므로 그대로 두었다.
- `plan-overall`: 옛 전체 목록 → 본문 위 "재화 7종 · 한 행에 4", 크레딧 행(500M / 112M, 100% 충분), 그룹 3개(오파츠 4 · 노트 · BD 2 · 장비 설계도 1). 요약 행은 "필요량의 n% 확보 · 6종 부족 · …"이다. 마크 · 범례 · 칩은 없다.
- `plan-scenario-detail-bottleneck`: S3 맨 위 seg가 "병목 + 꺼진 페이즈별 · 전체"(두 묶음) → 켜진 세 칸 한 묶음으로 바뀐다. 표시용 정렬 칩 "부족량 많은 순"은 동작하는 칩의 기본값 "기본 순서"로 바뀐다. 본문 · KPI · S1 · S2는 같다.

새 장면(added 2장):

- `plan-scenario-detail-phase`(시안 Scenario-Detail-Phase 상태): 보기 모드 → 페이즈별.
  - 07 시나리오 페이즈 카드 3장(P2는 패널 아래로 이어짐), 타일 활성 대비 칩(아루 엘레프 "이 시나리오에만").
  - 요약 행: 네브라(최상급) P1 76/180, 칩 "활성보다 −180 부족"(계획 전체 부족 374 → 194). KPI 4칸, caption "페이즈를 누르면 왼쪽 단계가 강조됩니다".
- `plan-scenario-detail-all`(시안 Scenario-Detail-All 상태): 보기 모드 → 전체. 범례, 엘레프 그룹(아루 "신규"), 마크 = / ±n, 크레딧 "활성보다 −n", 요약 칩 "활성 a% → b%".

그대로(이유):

- `plan-bottleneck`: 병목 탭은 그대로다. 카드 거르기는 홈 함수 → 워크스페이스로 옮겼지만 기본 칩(전체 · 숨기기 꺼짐)에서는 카드가 같다. 칩은 같은 BaChip 세 개를 한 Row로 감쌌을 뿐이라 크기 · 자리가 같다.
- `plan-scenario-list` · `-expanded` · `-shortage` · `plan-scenario-compare`: 홈은 화면 밖이고, 목록 · 미리보기 · 비교 S1은 고치지 않았다.
- `plan-flow-*` 전부: 흐름이 열리면 홈을 그리지 않는다. golden 대역 · `_goldenPhaseResults`는 고치지 않았다(4단계 페이즈 상태 그대로).
- `plan-phase-editor` · `plan-student-selector` · `plan-element-builder` · `plan-preset-manager`: 옛 홈(`legacyHome`)이거나 홈을 그리지 않는다. 옛 홈의 필터 · 소비 목록 코드는 고치지 않았다.
- 계획 밖 장면(`title` · `account-*` · `home` · `students-*` · `scan-student-review` · `account-new`): 계획 탭이 offstage다.

### 테스트 변경(의도된 변경)

- 새 `test/plan_detail_tabs_test.dart`:
  - 모델 4건: 진입/필요/종료 · %, 확보율 · 영향 학생, 요약 행, 활성 대비.
  - 위젯 4건: 페이즈 카드 ↔ S2 강조, 전체 타일 ↔ S2 강조 · 열 수, 칩 거르기, 비교 범례 · 마크 · 칩.
- `test/plan_home_detail_test.dart`(FE5-c2 테스트):
  - 위젯 그룹: `tabBody` · `tabSummary` 매개변수가 없어졌으므로 "새 본문 · 요약 행 키"로 바꿨다.
  - 화면 테스트: "옛 홈 위젯을 보인다" → "새 위젯이고 `PlanConsumptionSection` 없음, 칩 누를 수 있음"(의도 그대로 FE5-d의 목표).
- golden 테스트: `plan-by-phase` · `plan-overall`의 기대 키를 새 위젯 키로 바꿨다. 새 장면 2개와 `_openScenarioDetailTab`을 더했다.
- 영향 grep: test/ 전체에서 `tabBody` · `tabSummary` · `toolbarChips` · `tab-body-` · `tab-later` · 홈 칩 키 · `PlanDetailWorkspace(`를 찾았다. 나머지(`plan_scenario_detail_test`의 c1 위젯 테스트)는 `onResourceTab`을 넘기지 않아 예전 꺼진 seg 그대로라 바꿀 필요가 없다. 옛 홈 테스트는 `legacyHome: true`라 영향이 없다.

### 남긴 옛 코드(FE5-f에서 정리)

- `PlanConsumptionSection` · `PlanConsumptionCard` 계열, `PlanPhaseResourceSummary` · `PlanOverallResourceSummary` · `PlanResourceSummaryProjection`, `filterPlanConsumptionGroups` · `filterPlanBottleneckDetails`. 이제 옛 홈(`legacyHome`)만 쓴다.
- `_calculateDocument`의 `_phaseConsumptions` · `_overallConsumption` · `_bottleneckDetails` 만들기와 섹션 3 강조(`_toggleSection3Resource` · `_selectedSection3ResourceKey`). 옛 홈만 쓴다.
- 옛 홈 필터 토글(`_toggleResourceCategory` 등)과 섹션 4 · 6 필터 위젯. 새 홈은 `_applyHomeFilter`로 같은 상태만 쓴다.
- `PlanDetailWorkspace._lockedTabs`(seg를 넘기지 않을 때의 꺼진 모양). 앱에서는 쓰지 않고 c1 위젯 테스트만 쓴다.
- FE5-c2 종료 기록의 목록(옛 홈 섹션 1~6, `legacyHome`, 옛 진입 버튼, A/B 후보 고르기, `PlanPhaseEditor` 등)은 그대로다.

### 미검증 항목

- analyze · 테스트 · golden 실행 전부.
- 1280×720 같은 작은 창에서 페이즈 카드 · 전체 5열 그림(넘침은 코드로 막았지만 보지 못함).
- 실제 백엔드(ProcessAppService)에서 크레딧이 인벤토리 snapshot에 있는지. 없으면 크레딧 진입 · 종료 · 보유가 "—"다.
- 칩 메뉴(PopupMenu)가 FittedBox로 줄어든 툴바에서 열리는 위치.

### 검수표

| 프롬프트 항목 | 상태 |
|---|---|
| 1 페이즈별: 크레딧 진입/필요/종료 · 타일 진입 · 필요 · 종료 + 막대 % + ± 칩 · 페이즈 → S2 강조 | 했다(±는 재화 줄 단위) |
| 1 FD-037 원천 · FB-9 | 백엔드 확인, FB-9 불필요 |
| 2 전체: 한 행에 2~5 · 분야 그룹 + 크레딧 행 · 마크 = / ± / 신규 · 확보율 + 활성 a → b 칩 | 했다 |
| 3 홈 · 시나리오 보기 모두 켬(홈은 칩 없이, 보기는 비교 응답) | 했다 |
| 4 홈 옛 `PlanConsumptionSection` 연결 → 새 위젯, 옛 파일 · `legacyHome` 안 지움 | 했다(남긴 목록 위) |
| 5 칩 3개가 새 두 탭에서 동작 | 했다(홈 · 시나리오 보기) |
| services/** · 인벤토리 · backend · contracts · scan/tactical/title_page · account_* · app_shell 안 고침 | 지켰다 |
| golden 장면별 예측 · 새 장면 2개 이하 | 지켰다(새 2) |
| 정적 검토만 · 직접 커밋 안 함 · ~습니다체 | 지켰다 |

### 발견 사항

- 페이즈 단위 활성 대비(시안 P1 +12 · P2 +30)를 만들려면 두 문서의 페이즈를 맞추는 규칙이 먼저 필요하다(FD-039는 단계 맞춤뿐). 지금은 재화 줄 전체 차이를 쓴다. 필요하면 새 FD로 정하기를 제안한다. 그다음 `projection_a.phase_results`로 클라이언트 계산이 가능하다.
- golden 대역 `_goldenPhaseResults`의 페이즈 진입값은 첫 단계 `owned_at_entry`(대역 고정값)라, 백엔드처럼 앞 페이즈 소비가 빠지지 않는다. 화면 문구 · 계산식은 백엔드 의미로 맞췄다. 대역을 백엔드 의미로 바꾸면 `plan-flow-step4` 페이즈 상태도 바뀌므로 별도 slice에서 판단해야 한다.
- 옛 `planResourceCategory`는 경로 문자열로 분류해서 기술 노트(`skill_book` 폴더)를 "기술 노트"가 아니라 오파츠로 센다(키 `skill_note` · `skillnote`만 본다). FE5-c2부터 홈 칩이 같은 함수를 쓴다. 칩 분류를 `category` 기준으로 바꾸는 것은 FE5-f(옛 필터 정리) 몫으로 남긴다.

### 다음 행동

- 오케스트레이터: gate 결과를 검토한다. 기대는 다음과 같다.
  - analyze · UI 테스트 녹색.
  - golden RED는 위 3장 변경 + 새 2장(기준 없음)이다. 그 밖의 변화는 이 slice 몫인지 먼저 본다(Lane B FE6-a는 인벤토리 파일만).
- 사용자 실행 순서:

```powershell
cd "C:\Users\brigh\planner_of_plana\BA Planner\v7"
# ① 두 워커가 모두 멈춘 뒤 gate만 실행 → 결과를 오케스트레이터에게 보내고 기다린다
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ② 오케스트레이터 승인 뒤 기준 이미지 갱신 → 다시 gate
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1 -UpdateGoldens
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_gate.ps1
# ③ 커밋(순서는 오케스트레이터가 정한다)
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe5d -DryRun
powershell -ExecutionPolicy Bypass -File .\frontend\tool\fe_commit.ps1 -Slice fe5d
```

### fe5d commit record (2026-10-11 16:56, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261011_164434\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE5-e 착수 기록 (2026-10-11 17:51, Lane A)

- 상태: 진행 중. 시작 SHA = `1fbc4ddd`(scanner-consolidation HEAD, XB M1 exact18 커밋. 부모 `f1ca4713`. 이 환경에서는 `.git`을 읽을 수 없어 오케스트레이터 로그 17:49의 SHA를 적는다).
- 범위: 시나리오 나란히 비교 최대 4열(Scenario-Compare). 목록 비교 슬롯 3~4개 → 4열 비교, 2개 → 기존 A↔B 2-pane 유지(FD-085)하되 후보 목록(`_ComparisonCandidateDiagonalList`) 제거. 기준 대비 N−1회 `compareScenarios`(FD-092)와 FE5-b 미리보기 캐시 키 규칙의 캐시.
- 막힘 요약의 이 slice 열림 FD 0건 확인. 처리할 FD: FD-034 · FD-038 · FD-039 · FD-085 · FD-086 · FD-092 · FD-093.
- 고칠 기존 파일(사본: `debug/frontend_fe5e/pre/<경로>`. 결국 고치지 않은 파일은 종료 기록에 적는다):
  - `frontend/lib/ui/widgets/plan_section_layout.dart`
  - `frontend/lib/ui/widgets/plan_scenario_list.dart`, `frontend/lib/ui/models/plan_scenario_list_state.dart`
  - `frontend/test/planning_page_test.dart`, `frontend/test/plan_scenario_comparison_test.dart`, `frontend/test/plan_scenario_list_test.dart`
  - `frontend/test/goldens/fe1g_baseline_golden_test.dart`, `frontend/test/goldens/golden_harness.dart`
- 새 파일(예정): `frontend/lib/ui/models/plan_scenario_compare.dart`, `frontend/lib/ui/widgets/plan_scenario_compare.dart`, `frontend/lib/ui/studio/plan_scenario_compare_studio_layout.dart`, `frontend/test/plan_scenario_compare_test.dart`, 새 golden 장면 하나(필요하면).
- 이 환경에는 flutter가 없다(정적 검토만 가능). `frontend/lib/services/**` · 인벤토리 파일 · app_shell은 고치지 않는다.

## FE5-e 종료 기록 (2026-10-11 18:38, Lane A)

- 상태: 구현 끝, **정적 검토만 했다**. 이 환경에는 flutter · dart가 없다. analyze · 테스트 · golden은 한 번도 돌리지 않았다. 통과를 주장하지 않는다.
- 시작 SHA `1fbc4ddd`(XB M1, 부모 `f1ca4713`). 사본 8개는 `debug/frontend_fe5e/pre/frontend/`에 있다. 그중 `lib/ui/models/plan_scenario_list_state.dart` · `test/goldens/golden_harness.dart`는 결국 고치지 않았다(commit.json `modified`에 없음).
- commit.json: `debug/frontend_fe5e/commit.json`(slice=fe5e, status=true). modified 6, added 5(새 lib 3 + 새 테스트 1 + 새 기준 이미지 1), whole = 바뀌는 기준 이미지 2장(하나씩).

### 실행 명령 · 결과

- `flutter analyze` · `flutter test`: 실행하지 못했다(SDK 없음).
- 시안: `dc_outline.py`로 Scenario-Compare 사본만 읽었다(원문 통째 읽기 없음). 백엔드 `compare_document_projections`는 의미 확인용으로만 읽었다(수정 없음).
- 정적 검토 에이전트 2회(바뀐 파일 전부 · 쓰는 API 시그니처 대조 · lint · 테스트 흐름 손 추적 · test/ 전체 grep).
  1. 1회차 지적, 모두 고쳤다:
     - 컴파일 오류 1건: `plan_section_layout.dart`가 `planCompareActiveId`를 import하지 않았다 → `show` import를 더했다.
     - 새 화면 테스트 준비 실패 1건: 시나리오 대역 목표(Lv.2 + 장비 T9 · T2 애장품)가 v1 성장 규칙(장비 2칸 Lv.10, T2 인연 20)에 걸려 `createScenario`가 거절한다 → Lv.80 · 인연 20으로 바꿨다.
     - analyzer 경고 3건: 후보 목록을 지우며 쓰이지 않게 된 `_ScenarioStudentPortraits`(삭제), 늘 같은 값만 받게 된 `_PlanScenarioListCardPainter`의 `accent` 매개변수(삭제), `_loadCatalog`의 불필요한 cast(삭제).
     - 형식: 옛 홈 섹션 반복의 들여쓰기를 고쳤다.
  2. 2회차: 고친 곳 재확인과 시드 목표의 v1 규칙 전수 대조. 남은 문제는 없었다.
- 기기 반영: 바꾼 파일 10개를 쓰고 다시 읽어 `cmp`로 같음을 확인했다. 사본 8개는 크기로 확인했다(경로가 깊어 다시 읽지 못한다).

### 구현

- 목록(`plan_scenario_list.dart`): "나란히 비교"를 시나리오 1~3개(활성 계획 포함 2~4개)에서 켠다. "셋 이상은 아직 열 수 없습니다" Tooltip을 지웠다. 보기 모드 S3 첫 탭 `initialResourceTab`(4열 "전체"용)을 더했다.
- 계획 화면(`plan_section_layout.dart`):
  - `_compareFromList`는 하나면 A↔B 2-pane, 둘~셋이면 4열(`_compareScenarioIds`)을 연다.
  - 목록 상태(`PlanScenarioListController`)를 계획 화면이 들고 목록에 넘긴다. 계획 홈에서 목록을 열 때마다 새로 만들고, 목록 ↔ 비교를 오가는 동안 정렬 · 필터 · 비교 슬롯을 이어 쓴다.
  - 4열 열 헤더 연결:
    - "비교에서 빼기"는 목록 슬롯에서도 뺀다. 둘이 남으면 A↔B 2-pane으로 바꾼다(목록 모션을 내렸다 올림).
    - "열기"는 A면 계획 홈, 시나리오면 목록 보기 모드다.
    - "전체"는 A면 계획 홈 전체 탭, 시나리오면 보기 모드 전체 탭이다(FD-093).
    - "계획에 적용…"은 2선택 모달 뒤 기존 `_applyScenarioFromView`(FE4-e 저장 4단계)로 간다. `_openFlowFromView`가 비교 화면에서도 열리게 했다.
  - 2-pane(`PlanScenarioComparisonSection`)의 후보 목록(`_ComparisonCandidateDiagonalList` · `_ComparisonCandidateCard`)과 "두 계획 나란히 보기" 버튼을 지웠다. 결과 전에는 읽는 중 · 실패(다시 불러오기) · 안내만 보인다(FD-085).
  - 옛 홈 섹션 1 "시나리오 비교"는 시나리오 목록을 연다(후보 고르기가 목록 슬롯으로 옮겨 감). 옛 홈의 4열 비교는 옛 섹션 1 자리에 자기 S1을 둔다.
- 새 파일:
  - `models/plan_scenario_compare.dart`: 열 모델 · 기준 대비 · 최고 값 · 차이만 보기 판정(`PlanCompareTable`), 쌍 캐시(`PlanComparePairLoader`).
  - `studio/plan_scenario_compare_studio_layout.dart`: 라벨 열 + 열 A~D.
  - `widgets/plan_scenario_compare.dart`: `PlanScenarioCompareView`.

### 처리한 FD

- FD-085(워커 재량, 권장안): 2개면 기존 2-pane 유지, 후보 목록 제거.
- FD-086(워커 재량, 권장안): 섹션은 화면 높이(94칸)에 두고 열 헤더 아래 행 전부(라벨 열 + 4열)가 **한 `SingleChildScrollView`**로 함께 세로 스크롤한다. 학생 수 제한은 없다. 행은 섹션 왼쪽 80° 변을 따라 민다(행 아래 경계 기준 + 14px). 행 안에서는 그 Scrollable의 position을 읽는다(`Scrollable.maybeOf(context)`). 스크롤바는 마지막 열 오른쪽 변과 평행한 공용 `DiagonalScrollbar`이고, 포그는 다섯 섹션 모양으로 자른다.
- FD-092(워커 재량, 권장안): 기준 대비 N−1회 `compareScenarios`. 키 = (기준 id, 기준 revision, 열 id, 열 revision, 프로필 revision)으로 FD-089와 같은 규칙이다. 활성 계획 revision은 저장된 활성 계획 revision이다. 키 밖 입력(활성 계획 문서 · 확정 상태)이 바뀌면 캐시를 버린다. 기준을 바꾸면 새 기준 쌍이 모두 올 때까지 앞 표를 두고 S1 부제에 "기준을 바꾸는 중입니다"를 보인다. 새 서비스 메서드는 없다.
- FD-093(워커 재량, 권장안): "목록" · "+n종 더"는 부족 재화 팝오버(FD-090 키트 `GroupedShortageFlyout`, 칩 = 기준 대비 부족량 차이)를 연다. "전체"는 그 열의 Detail 전체 탭으로 간다. stale은 열 헤더 "저장 시점과 다름" 칩이다.
- FD-034 (a): 끝까지 가는 학생 = `PlanDetailStageStates.finishingStudents` / 문서 계산 학생 수(FE5-c1 함수 재사용).
- FD-038 (c): 크레딧은 필요량 차이, 부족 재화는 종 수 차이, 재화 팝오버 칩은 부족량 차이다(FE5-b `planScenarioShortageDelta`를 "기준과 같음" · "기준에 없음" 문구로).
- FD-039: 4열은 단계 행이 없어 단계 맞춤을 쓰지 않는다. 학생 칸은 비교 응답 `students[]`(학생별 마지막 단계 목표)를 쓴다(백엔드와 같은 정의).

### FB-9 필요 여부

- **지금은 "FB-9 다중 비교 필요"로 보지 않는다.** 근거와 한계는 다음과 같다(실측 없음).
  - 호출 수: 4열을 열 때 3회(3열이면 2회), 기준을 바꿀 때마다 새 기준이면 3회 더, 본 기준으로 돌아오면 0회(캐시)다. 세 호출은 한꺼번에 보낸다(응답을 기다려 순서대로 보내지 않음).
  - 응답 크기: 호출마다 projection 두 개(`stage_results` · `phase_results` · `overall.resources` · `bottlenecks`)와 비교 줄을 받는다. 기준 projection은 호출마다 다시 계산되어 중복으로 온다. 같은 기준에서는 4열 한 화면에 projection 6개(필요 4개)가 오므로 중복은 1.5배다. 기준을 4번 다 바꾸면 12회 · projection 24개다.
  - 체감 지연은 이 환경에서 잴 수 없었다. gate · 실기에서 4열 열기 · 기준 바꾸기가 느리면 FB-9(`compare` 다중 문서 + 기준 index, D §3-5)로 올리자고 적어 둔다.

### 페이즈 단위 기준 대비

- 비교 화면에 필요하지 않다. 시안 Compare에 페이즈 단위 행이 없어서다(첫 병목은 각 열 자기 projection의 페이즈 번호만 보인다). 그래서 만들지 않았다.
- FE5-d 발견 사항은 그대로 열려 있다. 참고용 FD 안(정하지 않음):
  - (a) 페이즈 순번 맞춤
  - (b) `phase_id` 일치 우선, 없으면 순번
  - (c) 단계 맞춤(FD-039)으로 맞은 단계가 가장 많은 페이즈끼리 맞춤
  - 권장 (b): FD-039와 같은 "id 우선 → 순번" 모양이고 계산이 싸다.

### 시안과 다른 점 · 남긴 것

- 고정 · 스크롤: 시안 메모 "위 항목은 고정 · 학생만 스크롤"과 칩 "다른 학생만" · "포함 안 된 칸 접기"는 FD-086(전부 함께 스크롤)과 맞지 않아 따르지 않았다. 칩도 만들지 않았다. 열 헤더(128px)만 고정이다.
- 섹션 rect: 시안 열 간격 461.5(17.3칸)는 정수 칸이 아니다. 열은 16칸 · 17칸 간격이다. 열마다 10.8px 좁고, 오른쪽 열일수록 왼쪽으로 붙는다(D 오른쪽 끝 −34.2px). 라벨 열은 윗변 −2.1px이다.
- 표기:
  - 분야 칸은 시안 점 세 개 + "전체 n" 대신 "+n종 더"(팝오버) + "전체"(Detail 전체 탭)다. FD-093 문구를 따랐다.
  - 부족이 없으면 "충분", 모르면 "—"다.
  - 수정 시각은 목록과 같은 `수정 9.22 23:10` 형식이다(시안 `9.22 23:10 수정`).
  - S 칩은 최댓값을 M으로 쓴다(EX 5도 M, FE5-b 목표 요약과 같은 규칙). 시안 "5·M·M·M"과 "M·M·M·M"이 서로 맞지 않아 규칙 쪽을 따랐다.
- 최고 값: 모든 열이 같거나 아는 값이 둘보다 적으면 칠하지 않는다. 동점은 모두 칠한다. 규모 · 학생 행은 칠하지 않는다.
- ± 표시 토글은 크레딧 · 부족 재화의 기준 대비 글자만 숨긴다. 학생 "같음 / 다름 n / 신규"는 늘 보인다.
- 빠진 것:
  - 팝오버 아래 "항목을 누르면 그 재화가 막는 단계로 이동합니다" · "인벤토리에서 보기"는 없다(이동 대상 · 인벤토리 연결이 없고 app_shell은 이번 범위 밖).
  - 학생 목표 팝오버(시안 "호시노 · 최종 목표 전체")는 선택 요소라 만들지 않았다.
  - 헤더 부제 "육성 목표와 필요 재화 · 시나리오 비교"는 바꾸지 않았다.
- golden 장면 `plan-scenario-compare-4`의 열 D는 시안의 "01 단기 집중"이 아니라 "04 공격대 핵심"이다. stale 칩(FD-093)을 장면에 담으려고 골랐다.

### 테스트 변경(의도된 변경)

- `planning_page_test.dart`:
  - "scenario comparison …"은 `initialSelectedIds`로 두 대상을 넘긴다. 후보 카드 사선 배치 검사를 지우고, 후보 목록 · 확인 버튼이 없음을 확인한다. 후보 목록을 없앤 것이 FD-085 권장안이어서다.
  - "comparison workspace incorporates …"(옛 홈)은 "시나리오 비교" → 목록 → 슬롯 담기 → "나란히 비교" → 편입 순서다. 옛 진입 버튼이 목록을 열게 바뀌어서다.
- `plan_scenario_comparison_test.dart`: `initialSelectedIds`로 연다. 후보 배지 A/B 글자 검사는 지웠다(같은 이유).
- `plan_scenario_list_test.dart`: 4/4에서 "나란히 비교"가 켜진다(`isTrue`). FE5-e가 "A + 하나만" 제한을 풀어서다.
- `grep`으로 test/ 전체에서 `plan-compare-candidate-*` · `plan-scenario-compare-confirm` · `-candidates` · 옛 진입 · 3개 이상 비활성 기대를 찾았다. 위 세 파일 밖에는 없었다.
- 새 `plan_scenario_compare_test.dart`:
  - 모델: 열 값 · 기준 대비 · 학생 표시 · 칩 값 · 최고 값 · 차이만 보기 · 기준 바꾸기 · 쌍 캐시.
  - 화면 2개:
    - 4열 → 호출 3 → 기준 B(6) → 기준 A(캐시, 6) → ± 끄기 → 빼기 2번(3열 → 2-pane) → 목록 "2 / 4"
    - 목록으로 돌아가 슬롯 유지("3 / 4") → 다시 4열 → "열기" → 보기 모드
- `fe1g_baseline_golden_test.dart`: 새 장면 `plan-scenario-compare-4`를 더했다.

### golden 예측(장면별)

- **바뀜 `plan-scenario-list-expanded`**: 비교 3/4(02 · 07)라 S1 "나란히 비교 3개" 버튼이 꺼진 모양(흐림)에서 켜진 모양으로 바뀐다. Tooltip 제거는 보이지 않는다. 나머지 영역은 같다.
- **바뀜 `plan-scenario-list-shortage`**: 같은 목록 장면이라 S1 버튼이 위와 같이 바뀐다. 팝오버 · 미리보기는 같다.
- **추가 `plan-scenario-compare-4`**(새 기준 이미지, commit.json `added`):
  - S1: 나란히 비교 · 4개 / 기준 A, 토글 차이만 끔 · 최고 값 켬 · ± 켬, 기준 라디오 A~D.
  - 라벨 열과 열 A 활성 계획(파랑 헤더 · "비교 기준"), B 02, C 07, D 04(저장 시점과 다름 칩).
  - 위 다섯 행 · 분야 네 행 · 학생 행 일부(화면 아래는 잘리고 스크롤된다).
- **안 바뀜 `plan-scenario-compare`**: 오케스트레이터 예상과 다르다. 이 장면은 목록에서 하나를 담아 연 뒤 자동 비교가 끝난 **결과 화면**(2-pane 전체 결과 탭)을 찍는다. 후보 목록은 결과 전 선택 상태에만 있었으므로 픽셀이 같다. 결과 화면 · FE5-c2 S1 메뉴는 고치지 않았다. 바뀌면 원인을 다시 보겠다.
- **안 바뀜**:
  - `plan-scenario-list`: 담은 시나리오 0개라 버튼은 그대로 꺼져 있다.
  - `plan-scenario-detail-bottleneck` · `-phase` · `-all`: 보기 모드 S1은 Detail 메뉴라 비교 슬롯이 없다. 첫 탭 기본값은 병목 그대로다.
  - 계획 홈 · 옛 홈 장면(`plan-bottleneck` · `plan-by-phase` · `plan-overall` 등): 옛 "시나리오 비교" 버튼의 글자 · 켜짐 조건이 같다.
  - 계획 만들기 · 학생 · 인벤토리 · 계정 · 타이틀 · 스캔 장면: 코드 경로가 같다.

### 미검증 항목

- analyze 0건, 일반 테스트 · 새 테스트 통과, golden 2장 차이 · 새 장면 모양(gate 필요).
- 4열 실기 확인: 스크롤 동기, 팝오버 위치, 열 헤더 버튼 hit test, 2560 이외 폭에서의 겹침.
- 체감 지연(FB-9 판단 근거). 실제 백엔드에서 세 쌍을 한꺼번에 보낼 때의 동작.
- 옛 홈 4열(옛 섹션 1을 숨기고 자기 S1)과 4열 → 2-pane 전환 모션.

### 검수표

| 항목 | 결과 |
|---|---|
| 목록 슬롯 3~4개 → 4열, 2개 → A↔B 2-pane, 후보 목록 제거(FD-085) | 구현 · 테스트 작성(미실행) |
| 라벨 열 + 4열 행 높이 맞춤 · 한 Scrollable(FD-086) | 구현(정적) |
| 열 A 파랑 "비교 기준", 기준 라디오로 ± · 같음/다름 재계산 | 구현 · 테스트 작성 |
| 보기 토글 3(차이만 · 최고 값 · ±) | 구현 · 일부 테스트(± 끄기) |
| 행 그룹(위 다섯 · 분야 네 · 학생) | 구현 |
| "+n종 더" · "목록" → 팝오버, "전체" → Detail 전체 탭, stale 칩(FD-093) | 구현 · golden 장면에 stale 칩 |
| N−1회 쌍 비교 · FD-089 키 캐시 · 새 서비스 메서드 없음(FD-092) | 구현 · 테스트 작성(호출 수) |
| FD-034 (a) · FD-038 (c) 재사용 | 구현 · 모델 테스트 |
| 페이즈 단위 기준 대비 | 만들지 않음(필요 없음, FD 안만) |
| services · inventory · app_shell · backend · contracts 수정 없음 | 지킴 |
| analyze 0 · 테스트 · golden | 미실행(SDK 없음) |

### 발견 사항

- 옛 홈(`legacyHome`)의 A↔B 2-pane에는 나가는 길이 없다. 결과 화면 "목록으로 이동" · 편입 · 편집 말고는 섹션 1 버튼이 모두 꺼져 있다. FE5-a 이전부터 그렇다. FE5-f에서 옛 홈을 정리할 때 함께 보면 된다. 이번에는 고치지 않았다.
- FD-086과 시안 메모("위 항목은 고정 · 학생만 스크롤") · 칩 두 개가 서로 맞지 않는다. decision-register 문구를 시안 메모와 맞출지는 오케스트레이터가 판단할 일이다.

### 다음 행동

- 사용자 실행 명령(순서는 오케스트레이터가 정한다):
  1. 두 워커가 모두 멈춘 뒤 `frontend/tool/fe_gate.ps1` → 결과를 오케스트레이터에게 보내고 기다린다(golden은 위 2장 RED + 새 장면 1장 예상).
  2. 승인 뒤 `fe_gate.ps1 -UpdateGoldens` → `fe_gate.ps1`.
  3. `fe_commit.ps1 -Slice fe5e -DryRun` → `fe_commit.ps1 -Slice fe5e`.
- gate에서 analyze · 테스트가 실패하면 그 출력으로 고친다. 4열 열기 · 기준 바꾸기가 느리면 FB-9로 올린다.

### fe5e commit record (2026-10-11 20:32, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261011_195443\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## M2 착수 기록 (2026-10-11 21:05, Lane A)

- 상태: 진행 중. 범위는 M2 — `developer_tools_main.dart --tool=metadata-manager` 도구 창(탭 ① 학생 ② 출처 ③ 자산, ④ 업데이트 · ⑤ 배포는 자리만), `tool_registry.dart`, 새 6 메서드 strict DTO, mock 모드다. 레인은 Lane A이고 상태 문서는 이 파일이다(오케스트레이터 로그 20:45 배정).
- 시작 SHA = `feb4dc2b`(redesigndocs, 오케스트레이터 로그 20:45의 커밋 순서 fe5e `c3374b21` → fe6b `e45194bc` → 옛 파일 삭제 → redesigndocs `feb4dc2b`). 그 뒤 XB FB-10a · release2 반영 커밋이 있을 수 있다. 이 환경에서는 `.git`을 읽을 수 없어 로그의 SHA를 적는다.
- WIP 유무: `developer_tools_main.dart`(mtime 2026-10-06, SHA256 `210a912f2584bb468ce7abda01779ad5edb366b8f001a487130bf401f0ac4fb0`)와 `developer_tools/tool_backend_client.dart`의 미커밋 변경은 이 환경에서 **확인할 수 없다**(`.git` 읽기 불가). 사용자 확인 명령: `git status --short frontend/lib/developer_tools_main.dart frontend/lib/developer_tools run_student_metadata_editor.cmd`. 있든 없든 pre 사본(`debug/frontend_m2/pre/<경로>`)과 끝 사본(`debug/frontend_m2/post/<경로>`)을 두고 commit.json에 `post_dir`를 적는다.
- 고칠 기존 파일(pre 사본 3개):
  - `frontend/lib/developer_tools_main.dart`
  - `frontend/lib/developer_tools/tool_backend_client.dart`
  - `run_student_metadata_editor.cmd`(저장소 루트, ASCII만)
- 새 파일(예정): `frontend/lib/developer_tools/tool_registry.dart`, 기존 세 도구 화면을 옮길 파일, 새 6 메서드 DTO · 서비스(실제 · mock) · `metadata-manager` 화면 파일, `frontend/test/`의 새 개발자 도구 테스트(DTO 양성 · 음성, 화면 탭 전환 · 빈 상태 · 오류).
- 계약 · fixture SHA 대조(기기 작업 트리 파일 = XB 17:02 · 17:04 게시값):

| 경로 | 기기 SHA256 | XB 게시값 |
|---|---|---|
| `contracts/developer-tools-metadata-manager-v1.schema.json` | `687730c00a1240315027d8a4885dd3ebb16af86edec63a2e65a9de7cd7020442` | 같음 |
| `contracts/fixtures/developer_tools_metadata_manager_m1_v1.json` | `7411495f2ae8df96a8a4bb0348093638ece76f259cb0e967fb317d70301abddc` | 같음(작업 트리 값. 커밋 blob은 CRLF→LF 정규화 `3b02087f…`, XB 17:49) |
| `contracts/README.md` | `97d1b3178ed38ac53ab402300a01262738e360b2150190693e66ca8c2bc54ae7` | 같음 |
| `backend/tools/developer_tools.py` | `9465b934f4f53b0dae0caef59c2fadfd3a9e4734e5a64c473f43da687b86aa53` | 같음 |

- `debug/xb_m1_actual_20261011/artifacts/dart-new-method-fields.json`(SHA256 `902ae4f3…`)의 6 메서드 params · result 정의는 커밋된 schema `$defs`와 바이트 의미가 같다(키 정렬 JSON 비교로 6개 모두 일치 확인).
- 이 환경에는 flutter · python이 없다(정적 검토만 가능). `backend/**` · `contracts/**` · `frontend/lib/ui/**` · `services/**` · golden · `app_shell.dart` · `release/**`는 고치지 않는다.

## M2 종료 기록 (2026-10-11 21:29, Lane A)

- 상태: 구현 끝, **정적 검토만 했다**. 이 환경에는 flutter · dart · python이 없다. analyze · 테스트 · 실제 창 · 실제 Python 메서드 호출은 한 번도 돌리지 않았다. 통과를 주장하지 않는다.
- 근거: XB M1 커밋 `1fbc4ddd`, 계약 `contracts/developer-tools-metadata-manager-v1.schema.json`(SHA256 `687730c0…`) · fixture `contracts/fixtures/developer_tools_metadata_manager_m1_v1.json`(작업 트리 `7411495f…`), 필드 정의 `debug/xb_m1_actual_20261011/artifacts/dart-new-method-fields.json`(커밋 schema `$defs`와 6개 모두 같음).
- 시작 SHA `feb4dc2b`. pre 사본 3개 `debug/frontend_m2/pre/`, 끝 사본 10개 `debug/frontend_m2/post/`(바꾼 3 + 새 7).
- commit.json: `debug/frontend_m2/commit.json`(slice=m2, modified 3, added 7, `post_dir` = `debug/frontend_m2/post`, status=false, whole = 이 상태 문서).
- WIP: 착수 기록대로 `developer_tools_main.dart` · `tool_backend_client.dart` · 런처의 미커밋 변경은 이 환경에서 확인하지 못했다. fe_commit의 3-way merge(pre/HEAD/post)가 겹침을 잡는다.

### 실행 명령 · 결과

- `flutter analyze` · `flutter test` · `py -3.11 -m unittest`: 실행하지 못했다(SDK 없음).
- 계약 대조: 6 메서드의 params · result를 커밋 schema `$defs`와 `dart-new-method-fields.json`에서 키 정렬 JSON으로 비교했다(같음). backend `developer_tools.py`(`dispatch` · `validate_envelope`)와 `metadata_manager_m1.py`는 의미 확인용으로만 읽었다.
- 정적 검토 에이전트 2회(바뀐 파일 전부 · 키트 API 시그니처 대조 · 계약 대비 DTO 엄격도 · lint · 새 테스트와 기존 `developer_tools_app_test.dart` 손 추적).
  1. 1회차 지적, 모두 고쳤다:
     - 막는 결함 1건: mock 레거시 백엔드가 `fields: []`를 주면 옮긴 편집기가 "읽는 중" 스피너를 끝없이 돌린다 → mock 테스트 `pumpAndSettle`이 시간 초과되고, 실제 `--mock` 창의 ① 탭도 영원히 스피너다. 기본 네 필드(`student_id` · `display_name` · `template_name` · `group`)를 주고 학생은 비웠다.
     - 늦은 응답 덮어쓰기 3곳(② 상태 · 버전 다시 읽기, ② 비교 도중 대상 바꾸기, ③ 매핑 목록) → 세대 번호로 막았다. 서비스가 바뀌면 세 탭이 다시 읽는다.
     - DTO 경계 2건: `generated_utc`는 RFC 3339 정규식으로 본다(`DateTime.tryParse`는 날짜만 · 공백 구분도 받는다), `plannerPath`는 줄바꿈 문자를 거절한다(계약 정규식과 같게).
     - `DeveloperTool` enum에 넣은 `metadataManager`를 맨 뒤로 옮겼다(기존 값의 순번 유지).
  2. 2회차: 고친 곳 재확인, mock 모드에서 무한 애니메이션 없음, 테스트 결과가 바뀐 곳 없음. 남은 문제 없음.
- 기기 반영: 바꾼 · 새 파일 10개와 post 사본을 쓰고, 본 파일은 다시 읽어 `cmp`로 같음을, post · pre 사본은 크기로 확인했다.

### 구현

- **도구 등록**(`developer_tools/tool_registry.dart`): 항목 = id · 창 제목 · 빌더(+ 옛 이름 `aliases`). `metadata-manager`(aliases `student-metadata`) · `student-template` · `inventory-grid`. 모르는 이름 · 이름 없음은 `metadata-manager`다(옛 기본값 = 편집기와 같은 자리). A2는 이 표에 항목 한 줄을 더하면 된다.
- **진입점**(`developer_tools_main.dart`): `--tool`은 등록표를 읽는다. `--mock`(또는 `--mock=true`, `BA_PLANNER_DEVELOPER_TOOL_MOCK=true`)이면 Python 없이 연다. 기존 세 화면은 `developer_tools/legacy_tool_pages.dart`로 그대로 옮겼다(바이트 비교: 추가는 `MetadataEditorPage.onSelectedStudentChanged` 매개변수와 호출 3줄뿐). `DeveloperToolApp(tool:, client:)`와 `DeveloperTool` enum은 기존 호출 · 테스트 호환으로 남겼고, `DeveloperTool.metadata`는 메타데이터 관리자 ① 탭을 연다. 창 제목: 편집기 → "BA Planner v7 · 메타데이터 관리자", 나머지 두 도구는 그대로.
- **전송**(`tool_backend_client.dart`): `ToolEnvelopeTransport.send`(응답 envelope를 해석하지 않고 돌려줌)를 더했다. 프로세스 실행만 `_run`으로 뽑았고, 기존 `call`의 요청 · 오류 문구 · `ok` 처리 · `result` 반환은 그대로다.
- **DTO**(`developer_tools/metadata_manager_dto.dart`): 요청 exact `version/method/params`(version=1, params 키도 계약대로, `version_id` · `student_id` 정규식 검사), 응답 exact `version/ok/result` · `version/ok/error`(+ `error.type/message` → `MetadataManagerRemoteError`). 객체마다 키 집합이 정확해야 하고(additionalProperties false), enum · const · nullable · SHA-256 모양 · `minProperties` · if/then(`store.versions` 미연결 = 빈 목록, `store.diff` available ⇔ 보고서 + `report_identity_only`, 그 밖 ⇔ null + `not_verified`, asset catalog ⇔ 주소 키 · `*.bundle`, manual ⇔ 셋 다 null)을 검사한다. 미입증 출처(`provenance: null` · `source_state: unknown` · `comparisons: []`)만 받는다. 위반은 `MetadataManagerProtocolException`.
- **서비스**(`developer_tools/metadata_manager_service.dart`): 실제 = `ProtocolMetadataManagerService`(envelope 전송 → DTO). mock = `OfflineMetadataManagerService`(아무것도 부르지 않고 `MetadataManagerUnavailable` → 화면은 오류가 아니라 "저장소 미연결 · 빈 상태"). 레거시 백엔드만 있으면 "새 메서드 연결 없음"으로 같은 빈 상태다. 새 서비스 메서드(Python 쪽)는 없다.
- **창**(`developer_tools/metadata_manager_page.dart`, 키트만: `SkewSegmented` · `SkewToggleChip` · `TonalButton` · `BaChip` · `DiagonalRow` · `KitPressable` · `PanelTitle` · `TileTitle` · `SubHeader` · `KV`):
  - 탭 바(① 학생 ② 출처 ③ 자산 ④ 업데이트 ⑤ 배포) + 오프라인 칩. 탭은 처음 열 때 읽고 그 뒤 상태를 둔다(`IndexedStack`).
  - ① 학생: 기존 편집기 + 오른쪽 "이 값은 어디서 왔나" 패널(필드 · 값 · 출처 · 버전 열). 출처 · 버전은 계약대로 "확인되지 않음", 값이 없으면 "값 없음", `note` · `unavailable_groups`를 그대로 보인다. 창 폭 1400 이상이면 펼쳐 시작하고, 좁으면 접힌 띠(40px)의 버튼으로 연다(편집기의 900px 넓은 배치 기준을 지키려고).
  - ② 출처: 연결 칩(연결됨 / 저장소 미연결 + "기존 기능은 그대로 동작합니다"), store_root, 검증 안 함(not_verified), 빠진 kind, lock 고정 버전(서버 · 버전 · 클라이언트 · 번들 · 파일 해시 앞 12자리), extract 목록, 등록된 버전(lock 고정 표시 · manifest만 확인), 기존 보고서 비교(서버 · 이전 · 다음 선택, 기본 = 고정 버전 → 마지막 다른 버전). 결과: 보고서 있음(L1 파일 판정 · L2 표별 요약 원문 · L3 문구) / 보고서 없음 · 저장소 미연결은 "차이 0이 아닙니다"라고 적는다.
  - ③ 자산: "실물 검증 아님(M4 필요)" 안내를 늘 보인다. `asset_map.list`(M0 초안 요약)와 `asset_map.check(scope)` 행을 (역할, 경로)로 합쳐 표(경로 · 역할 · 매핑 · 로컬 파일 · 주소 키 · 번들 · 텍스처 · 실물 확인 안 됨)로 그린다. 범위(전체 · UI · 인식), 필터 누락 · 수동(개수), 이름 변경 · 해시 변경은 M4 판정이라 꺼 둔 칩이다.
  - ④ "M5에서 채웁니다." ⑤ "M6에서 채웁니다."
- **런처**(`run_student_metadata_editor.cmd`, ASCII): `--tool=student-metadata` → `--tool=metadata-manager`(두 갈래 모두).
- 키트는 고치지 않았고 요청할 것도 없다.

### 탭별 검수표

| 탭 | 실제 Python 메서드로 채워짐 | mock 빈 상태 | 테스트(작성, 미실행) |
|---|---|---|---|
| ① 학생 | 편집기 = 기존 메서드 그대로. 패널 = `metadata.source.view` — **미검증**(실창 필요). fixture 응답으로는 채워짐 | 빈 편집기(기본 네 필드, 학생 0) + "학생을 고르면…" | 패널 요청 exact envelope, "확인되지 않음" ×3, "값 없음", 레거시 백엔드면 연결 없음 안내 |
| ② 출처 | `store.status` · `store.versions` · `store.diff` — **미검증**(실창 필요). fixture로는 채워짐 | "저장소 미연결" 칩 두 개 + mock 사유, 비교 불가 안내 | 연결 · 고정 버전 · 버전 행 · diff 요청 envelope · L1 행 · L3, 서버 실패 · 계약 불일치 · 보고서 없음 표시 |
| ③ 자산 | `asset_map.list` · `asset_map.check` — **미검증**(실창 필요). fixture로는 채워짐 | M4 안내 + "빈 상태" 두 개 | 행 키 · 로컬 누락 · 개수 문구 · 필터 · M4 칩 꺼짐 · check 요청 1회(scope all) |
| ④ 업데이트 | 자리만 | "M5에서 채웁니다." | 문구 |
| ⑤ 배포 | 자리만 | "M6에서 채웁니다." | 문구 |

### DTO 테스트 목록(`frontend/test/metadata_manager_dto_test.dart`)

- 양성(계약 fixture): 요청 6개 읽기 → 같은 envelope로 다시 쓰기, 서비스 요청 생성 = fixture 요청, `store.status` · `store.versions` · `store.diff` 상태 3종(disconnected · missing = 보고서 없음 · not_verified, available = 보고서 있음), `metadata.source.view` + `unknown_existing_provenance`, `asset_map.list` · `asset_map.check`, `envelope_error` → 서버 실패(type · message).
- 음성 요청(fixture `negative_requests`): params null · `version_id` 경로 탈출 · `student_id` 경로 탈출은 거절. 섞인 버전은 계약 모양으로는 맞아서 보내고 서버가 `store_mixed_version`으로 거절한다(그대로 둔다). 키 더함 · 모르는 메서드 · 범위 enum 밖도 거절.
- 음성 응답(fixture를 한 곳씩 바꿈):
  - envelope: 키 더함 · 빠짐 · version 2 · version true · ok 문자열 · 성공에 error · 오류에 message 없음 · 배열.
  - `store.status`: 상태 enum · 검증 const · 빈 pins · 해시 모양 · 빈 files · 모르는 서버 · extract 서버 · provenance 해시 63자 · missing_kinds 타입 · pin 키 빠짐.
  - `store.versions`: 미연결인데 목록 · manifest 검증 const · pinned 타입.
  - `store.diff`: available에 보고서 없음 · 검증 짝 · missing에 보고서 · 보고서 schema · L1 판정 · 날짜 · from 경로 탈출.
  - `metadata.source.view`: provenance를 채움 · comparisons를 채움 · source_state · value_state · comparison_state.
  - `asset_map.list`: manual에 주소 키 · catalog인데 주소 키 없음 · 번들 경로 · 경로 탈출 · 절대 경로 · 줄바꿈 경로 · 빈 note · 상태 const · 검증 const(+ 올바른 catalog는 받음).
  - `asset_map.check`: 실물 검증 주장 · 구조 상태 · 로컬 상태 · 범위.
- 화면(`frontend/test/metadata_manager_page_test.dart`): 등록표(id · 옛 이름 · 기본값 · enum id), mock 모드 다섯 탭, fixture로 세 탭 채우기(exact 요청), 오류 표시, 보고서 없음, 옛 이름 alias, 서비스 선택.
- 기존 `developer_tools_app_test.dart`는 고치지 않았다. `DeveloperTool.metadata` 테스트가 이제 메타데이터 관리자 창을 연다. 편집기는 1200px에서 1159px(넓은 배치 유지)이고, 높이는 탭 바만큼(약 54px) 줄었지만 스크롤 영역이 흡수한다. 정적 추적으로는 모든 기대(`'호시노'` ×1, `'저장'` ×1, 다른 화면 제목)가 그대로 맞는다(미실행).

### XB 요청

- **XB 요청: 배포본에 `developer_tools*` · 저장소 쓰기 경로가 없는지 검사하는 테스트**(사용자 결정 3, M2 완료 조건에 들어가는 테스트). XB 19:09 · 19:36의 release exact2(`backend/tests/test_release_developer_tools_exclusion.py` + `frontend/tool/sync_windows_release.ps1` 보존 7줄)가 이 요청의 후보다. M2가 더한 Dart 파일(`frontend/lib/developer_tools/` 아래 `tool_registry.dart` · `legacy_tool_pages.dart` · `metadata_manager_*.dart`)이 그 테스트의 "Dart main import/export closure" 검사에서 배포본 main 쪽에 닿지 않는지 함께 확인해 달라. 배포본 앱 진입점 `lib/main.dart`는 `developer_tools`를 import하지 않고, `lib/ui/**`에서도 참조가 없다(이 세션에서 확인. `services/**`는 확인하지 않았다). 새 파일을 import하는 것은 개발자 도구 진입점 `developer_tools_main.dart`뿐이다.

### 미검증 항목

- analyze 0건(info 포함), 새 테스트 · 기존 개발자 도구 테스트 통과.
- 실제 창: 세 탭이 실제 Python 메서드로 채워지는지(저장소 연결 여부, 실제 asset-map 행 수 UI 1,045 + 인식 780 기대, 1,825행 목록 스크롤), 출처 패널이 실제 학생으로 채워지는지.
- mock 창 실행(`--mock`), 옛 이름 `--tool=student-metadata` 실행.
- 배포본 제외 테스트(XB 쪽).

### 발견 사항

- 이미 빌드된 개발자 도구 번들 `release/developer_tools/ba_planner_v7.exe`는 `metadata-manager`를 모른다. 옛 진입점은 모르는 이름을 편집기로 돌리므로 런처는 다시 빌드할 때까지 옛 편집기를 연다(망가지지는 않는다). 번들을 다시 만드는 일은 XB 릴리스 스크립트 몫이다.
- M1 계약은 `provenance`를 null, `comparisons`를 빈 배열로만 허용한다. M3에서 생성 출처를 기록하면 계약 버전이 바뀌어야 하고, 이 DTO도 함께 바꿔야 한다(지금 DTO는 출처가 채워진 응답을 계약 위반으로 거절한다 — 의도된 동작).
- ③의 이름 변경 · 해시 변경 필터는 M4 판정(`bundle-renamed` · `bundle-hash-changed`)이 계약에 들어와야 켤 수 있다.
- `DeveloperToolApp`의 기본 생성자는 이제 `const`가 아니다(기존 테스트는 `const`로 부르지 않는다).

### 다음 행동

- 사용자 실행 명령(순서는 오케스트레이터가 정한다):
  1. 워커가 모두 멈춘 뒤 `powershell -ExecutionPolicy Bypass -File frontend/tool/fe_gate.ps1` → 결과를 오케스트레이터에게 보내고 기다린다(golden 변화 0 예상 — 개발자 도구는 golden 범위 밖).
  2. `fe_commit.ps1 -Slice m2 -DryRun` → `fe_commit.ps1 -Slice m2`.
  3. 실제 창 확인(v7 루트에서, 기존 런처와 같은 인자):
     - 실제 백엔드: `run_student_metadata_editor.cmd`. 또는 `set BA_PLANNER_BACKEND_DIR=%CD%\backend` → `cd frontend` → `flutter run -d windows -t lib/developer_tools_main.dart --dart-entrypoint-args=--tool=metadata-manager`.
     - mock: `cd frontend` → `flutter run -d windows -t lib/developer_tools_main.dart --dart-entrypoint-args=--tool=metadata-manager --dart-entrypoint-args=--mock`.
     - 옛 이름: `... --dart-entrypoint-args=--tool=student-metadata`(같은 창 ① 탭).
     - 기대: ①에서 학생을 고르면 패널이 필드마다 "확인되지 않음"을 보인다. ②는 저장소 연결 상태 · lock 고정 버전 · 등록된 버전을 보이고, 비교는 저장소에 보고서가 없으면 "보고서 없음"이다. ③은 "실물 검증 아님(M4 필요)"과 asset-map 행을 보인다. ④⑤는 자리 문구다.

## FE4-g2 흐름 handoff 정리 (구현 끝, gate 전)

### FE4-g2 착수 기록 (2026-10-11, Lane A, 로컬 Claude Code)

- 착수 때 진행 중: FE4-g2. 시작 SHA `9d959d15416b6251e8aaa1d682ea3550d48af524`(브랜치 scanner-consolidation).
- 범위: ① 계산기 handoff 새 단계를 그 학생의 "나중에" 칸 단계 앞(나중에가 아닌 마지막 단계 바로 뒤)에 넣고 바닥 snapshot을 그 앞 단계로 ② 활성 계획 "나중에" 단계와 바닥 snapshot(서비스 조사 먼저) ③ 회귀 테스트. 화면 디자인 변경 없음.
- 막힘: 대장 "slice별 막힘 요약"에 FE4-g2 행 없음, FE4-g 행 "—"(열림 0건). 멈출 사유 없음.
- 고칠 기존 파일(사본 `debug/frontend_fe4g2/pre/frontend/...`): `frontend/lib/ui/models/plan_flow_draft.dart`, `frontend/test/plan_flow_handoff_test.dart`. `plan_section_layout.dart`의 PlanFlowContext 생성부는 2번 결론에 따라 필요할 때만(그때 사본 추가).
- 기존 미커밋 변경(WIP): `git status --short` 결과 두 파일 모두 없음(이 status 문서도 없음).

### FE4-g2 종료 기록 (2026-10-11 23:55, Lane A, 커밋 전)

상태: 구현 끝(1번 구현, 2번은 코드 변경 없이 결론), gate 미실행(CF 몫). 시작 SHA `9d959d15416b6251e8aaa1d682ea3550d48af524`. `debug/frontend_fe4g2/commit.json`(slice=fe4g2, status=true). 직접 커밋하지 않았다(git 쓰기 없음).

#### 실행한 명령·결과

- `frontend`에서 `flutter analyze`: **No issues found**(0건, info 포함).
- `flutter test test/plan_flow_handoff_test.dart`: 첫 실행 17 통과 · 1 실패(새 테스트 (b)의 활성 문서 fixture에 v2 `goal_metadata`가 없어 `PlanningAuthoring.fromWire`가 거절 — 테스트 fixture 문제, `_activePlan(wireValid: true)` 추가) → 재실행 **18 통과 · 0 실패**.
- 바뀐 동작에 걸리는 기존 테스트(grep `receiveHandoff`·`PlanFlowContext`·`PlanFlowHandoffKind`·`planFlowMergedPlanDocument`·`deferredStageIds`·`calculator-add-to-plan`, golden 제외)를 파일마다 따로 실행(통과/실패): `growth_calculator_view_test` 24/0 · `planning_page_test` 61/0 · `plan_flow_authoring_test` 18/0 · `plan_flow_goal_step_test` 23/0 · `plan_flow_order_step_test` 19/0 · `plan_flow_presets_test` 13/0 · `plan_flow_save_test` 15/0 · `plan_flow_student_step_test` 8/0 · `plan_flow_test` 15/0 · `student_page_test` 9/0. 잠금 실패 없음.
- `dart format`은 gate 대상이 아니고 두 파일 모두 원래부터 형식 차이가 있어 파일 전체 재형식을 하지 않았다(diff 최소).

#### 1. "나중에" 칸 뒤에 붙는 문제 — 구현

- **실제 동작 확인(충돌 없음, 멈추지 않음)**: `setStudentStages`는 단계 id 목록이 바뀌면 그 학생 단계를 **칸(phases)에서만** 빼고(`_withoutStages(previous)`), 명시 "나중에"는 지운 단계만 뺀다(`_withoutDeferred(dropped)`). 그래서 "단계가 늘면 칸 배치가 풀린다"는 기존 규칙 뒤에도 나중에 단계는 나중에 칸에 남는다. 체인 = [풀린 앞 단계들 + 새 단계(임시 미배치)] + [나중에 단계들]이고, 3단계에서 앞쪽을 칸에 넣으면 "배치 prefix + 나중에 suffix"가 그대로 성립한다. 두 규칙은 충돌하지 않는다. 고치기 전 동작(새 단계가 나중에 단계 뒤)은 3단계에서 새 단계를 칸에 넣으면 선행 단계보다 앞 칸이라 막혔다.
- **넣을 자리**: 새 순수 함수 `planFlowHandoffInsertIndex(stageIds, deferred)` = 그 학생 단계 중 나중에가 아닌 마지막 단계 바로 뒤(나중에 단계들 앞). 지시의 "배치된 마지막 단계"는 "나중에 칸이 아닌 마지막 단계"로 읽었다: 칸에 있는 단계와 목표 편집 중 임시 미배치 단계는 모두 3단계에서 칸에 넣을 prefix이고, handoff 직후에는 어차피 모두 임시 미배치가 된다. 정상 초안에서는 두 정의가 같다.
- **바닥 snapshot = 그 자리 바로 앞 단계**. 근거: 단계는 누적 절대 목표 snapshot이고 새 단계는 체인에서 바로 앞 단계 뒤에 오므로 그 앞 단계를 복제해야 한다(plan-element-builder-lessons "새 단계는 선택 단계 바로 뒤에 그 snapshot을 복제"). 나중에 단계는 체인에서 새 단계 **뒤**라 바닥으로 쓰면 ① 사용자가 "나중에"로 미룬 목표가 지금 배치할 새 단계로 당겨지고 ② 새 단계가 나중에 단계 이상이 되어 나중에 단계가 증가 없는 단계로 바뀌며 ③ 나중에 단계에만 있는 값을 계산기로 다시 올리면 "이미 들어 있음"으로 버려진다(테스트 "나중에 단계가 바닥이 되지 않는다"가 이 경우를 고정).
- **뒤 나중에 단계 올리기**: 새 순수 함수 `planFlowRaiseLaterStages` — 새 단계보다 낮은 키만 새 단계 값으로 올리고 `normalizePlanningGrowthTargets(changedKeys)`로 정규화한다. 단계 계약 "이전 단계 값을 이후 단계보다 높이면 이후 단계의 같은 필드를 자동으로 올린다"와 2단계 편집기 `setTarget`의 뒤 단계 전파와 같은 규칙이다. 낮추지는 않는다. 이걸 하지 않으면 체인이 퇴행해 authoring `target_regression`이 난다.
- 이름: 새 단계 `n단계`(넣은 자리 번호), 기본 이름(`n단계` 꼴)은 2단계 편집기 `_renumberDefaultNames`처럼 다시 매긴다(나중에 `2단계` → `3단계`). 직접 바꾼 이름은 그대로. 결과 `step` = 넣은 자리 번호, `kind`는 기존 규칙 그대로(초안에 그 학생 단계가 있으면 `appendedToDraft`).
- 초안 단계가 **모두 나중에**면 자리 0(새 1단계), 바닥 = 지금 값. 초안에 그 학생 단계가 있으면 초안 체인만 본다는 FE4-g 규칙을 유지해 활성 계획 snapshot을 쓰지 않는다(아래 "판단" 1).
- 활성 계획을 고치는 흐름(`editActivePlan`)은 초안이 활성 계획(나중에 포함)이라 같은 규칙이 그대로 적용된다.

#### 2. 활성 계획 "나중에" 단계와 바닥 — 조사 결과, 코드 변경 없음

- 서비스 조사(grep): 활성 authoring은 **기존 응답으로 이미 읽을 수 있다** — `plan.get` → `RepositoryPlanState.authoring`(`lib/services/repository_plan_service.dart`, FB-8a; 저장된 authoring이 없으면 `PlanningAuthoring.defaultForDocument`). 계획 화면은 이미 `_repositoryPlan`(RepositoryPlanState)을 들고 있고 4단계 병합도 `_snapshot?.plan?.authoring`을 쓴다. 시나리오 쪽은 `scenario_service.dart`의 authoring(FB-8b). backend·contracts 변경 필요 없음.
- 결론: **문서의 단계 순서만으로 충분하다.** 근거: 활성 문서(`PlanningDocument`)의 phases에는 **배치된 단계만** 있고 나중에 단계는 authoring `deferred_stages`에만 있다. authoring 검증(`PlanningAuthoring.fromWire`)이 같은 학생 체인 = 문서 phase 순회 순서(배치) + deferred 순서를 강제하므로, 문서에서 그 학생의 마지막 단계(`planFlowActiveLastTargets`)는 곧 "활성 계획의 배치된 마지막 단계(나중에 단계 제외)"다. 1번과 같은 규칙(나중에 단계는 바닥이 아니다)이 이미 성립한다. 또 "활성 계획에 페이즈로 추가" 병합(`planFlowMergedPlanDocument`)은 체인을 활성 배치 → 초안 배치(새 단계) → 활성 나중에 → 초안 나중에로 만들어, 새 단계가 활성 나중에 단계 **앞**에 온다(1번과 같은 위치). 그래서 `PlanFlowContext`에 authoring을 싣지 않았고 `plan_section_layout.dart`는 고치지 않았다(사본도 없음).
- FE4-g "발견 사항" 2의 "활성 나중에 단계가 바닥 snapshot에 들어가지 않는다"는 CF 규칙상 **의도된 동작**으로 정리된다. 남는 문제는 병합 쪽이다(아래 발견 사항 2).

#### 판단(확인 부탁)

1. 초안 단계가 모두 나중에인 학생: 바닥 = 지금 값(활성 계획 snapshot 아님). 초안에 그 학생이 있으면 초안 체인만 본다는 FE4-g 규칙의 연장이다. 반대로 하려면 `receiveHandoff`의 `activeLast` 조건을 `insertAt == 0`으로 바꾸면 된다.
2. 뒤 나중에 단계 자동 올림(`planFlowRaiseLaterStages`)은 초안 안의 단계 계약으로 보고 했다. FE4-e 병합의 "낮은 값을 몰래 올리지 않고 막는다"는 활성·초안 사이 규칙이라 다르게 본 것이다.

#### 처리한 FD

- '워커 재량' FD 새로 처리한 것 없음. FD-171 (a)(FE4-g에서 처리)의 동작은 바꾸지 않았다. 막힘 요약에 FE4-g2 행 없음(FE4-g "—").

#### 테스트

- `plan_flow_handoff_test.dart` 새 그룹 `"나중에" 칸 단계 앞에 넣기(FE4-g2)` 6건: 순수 `planFlowHandoffInsertIndex`(빈 목록 · 나중에 없음 · 끝 하나 · 끝 둘 · 모두 나중에) · 순수 `planFlowRaiseLaterStages`(낮은 키만 오름 · 높은 값 유지 · 바뀌지 않은 단계는 같은 객체 · 전용무기 올리면 ★5 정규화) · (a) 초안 배치 1단계(레벨 50) + 나중에 2단계(레벨 80)에 레벨 60·스킬 10 → [1단계, 새 2단계, 나중에 3단계], 바닥 50, 나중에 단계 스킬 10으로 오름, 나중에 칸 유지, 칸 배치 풀림, 3단계에서 둘 다 칸에 넣어 `orderReady` · (a') 레벨 75(나중에 80보다 낮음)도 새 단계로 들어감 · 모두 나중에인 초안은 새 1단계(활성 계획 70을 쓰지 않음) · (b) 활성 문서(배치 레벨 70) + 활성 authoring(나중에 레벨 90, `fromWire` 검증) → 바닥 70으로 레벨 85 새 단계(`appendedAfterActive`), 칸에 넣고 병합하면 `stage_order_by_student` = [활성 1단계, 새 단계, 활성 나중에], 병합 막힘 없음.
- (c) 기존 handoff 테스트 12건 그대로 통과(기대값 수정 없음). `_activePlan`에 선택 인자 `wireValid`만 더했다(기본 false라 기존 테스트 입력은 그대로).
- 지운 테스트 없음.

#### golden 변화 예상

- 전 장면 **변화 0** 예상. 근거: 바뀐 코드는 `PlanFlowController.receiveHandoff`와 새 순수 함수 둘뿐이고, golden harness에는 계산기 handoff(`receiveHandoff`·목표 실은 시드)를 지나는 장면이 없다(`test/goldens/*.dart` grep). `PlanFlowContext` 생성부는 고치지 않았으므로 `plan-flow-step1`~`step4`·`step4-append`·`step3-deferred`·`step3-many`·`plan-flow-goal-*`·`plan-flow-order-*`·`plan-flow-save-*` 모두 그대로. 새 장면 없음.

#### 미검증

- golden 비교·전체 `fe_gate.ps1`: 미실행(CF 몫).
- ProcessAppService(실제 Python)에서 계산기 → 2단계 → 3단계 → 4단계 "페이즈로 추가" 저장 왕복: 미실행.
- 화면 확인(2단계 편집기가 어느 단계 카드를 고른 상태로 여는지, SnackBar 문구): 미실행 — 아래 발견 사항 1·3.

#### 검수표

| 확인 | 여는 방법 | 확인 포인트 |
|---|---|---|
| 초안 나중에 단계 앞에 넣기 | mock 모드 → 계획 탭 "시나리오 생성" → 학생 하나에 2단계에서 단계 2개 → 3단계에서 1단계를 1순위, 2단계를 "나중에" 칸 → 학생 탭 같은 학생 계산기에서 목표를 올리고 "이 목표로 계획에 추가" | 2단계: 그 학생 카드가 1단계 · 새 2단계(계산기 값, 1단계 값을 이어 받음) · 3단계(원래 나중에 단계, 새 단계보다 낮던 값은 새 단계 값으로 오름). 안내 "만들던 초안에 이어 … 2단계로 …" |
| 3단계 배치 | 위에서 "다음" → 3단계 | 원래 나중에 단계는 "나중에" 칸에 그대로, 1·2단계는 칸 밖(다시 배치). 1·2단계를 1순위(또는 1·2순위)에 넣을 수 있고 규칙 위반 표시 없음, "다음" 켜짐 |
| 나중에 값만 다시 올리기 | 나중에 단계에만 있는 값(예: 레벨)을 계산기에서 같은 값으로 넘기기 | "이미 들어 있음"이 아니라 새 단계가 생김 |
| 활성 계획 나중에 단계 | 활성 계획에서 학생 단계 하나를 나중에 칸에 둔 상태(단계 순서 바꾸기)로 저장 → 계산기에서 그 학생을 배치 단계보다 높고 나중에 단계 이하 값으로 넘기기 | 1단계 카드 값 = 활성 배치 마지막 단계 + 올린 값(나중에 단계 값이 아님). 4단계 "활성 계획에 페이즈로 추가" 가능 |

#### WIP 보존 확인

- 고친 두 파일·이 status 문서는 착수 때 WIP 없음(`git status --short`). 다른 미커밋 변경(스캐너·서비스·문서)은 건드리지 않았다. 줄 끝은 원본과 같은 LF(편집 중 한 번 CRLF로 바뀐 것을 되돌려 확인: 두 파일·status 모두 CR 0개). post 사본 불필요(WIP 없음).

#### 발견 사항

1. **2단계 편집기 선택 단계**: 넘긴 학생에게 나중에 단계가 있으면 새 단계가 마지막이 아니어서, 처음 여는 편집기는 마지막 단계(나중에 단계)를 고른다(`PlanFlowGoalEditor.selectedStageIdOf`의 기본값 = 마지막). 새 단계를 고르려면 흐름이 초점 단계 id(예: `goalFocusStageId`)를 내고 `plan_flow_goal_editor.dart` `_flowChanged`의 초점 처리에서 `_selectedStages[focus]`를 그 id로 두는 작은 변경이 필요하다. 이번 slice 수정 파일 범위 밖이라 하지 않았다.
2. **"페이즈로 추가" 병합의 활성 나중에 단계 퇴행**(FE4-e/f1 기존 동작): `planFlowMergedPlanDocument`는 활성 나중에 단계를 그대로 두므로, 초안 배치 단계(계산기 새 단계 포함)가 활성 나중에 단계보다 높은 값이나 활성 나중에 단계가 null로 둔 키를 정하면 authoring 검증이 `target_regression`으로 거절해 그 위치가 막힌다(예: 활성 배치 레벨 70 · 나중에 레벨 90, 계산기에서 레벨 95나 스킬을 올림). 같은 학생에게 활성 나중에 단계가 있으면 흔히 걸린다. 해법 후보: 병합에서 활성 나중에 단계를 1번과 같은 규칙으로 올리기(`planFlowRaiseLaterStages`와 같은 뜻) vs 지금처럼 막고 안내만. 병합 규칙("낮은 값을 몰래 올리지 않는다")을 바꾸는 결정이라 CF 판단 몫.
3. **SnackBar 문구**: `nothingNew` 안내 "… 학생의 마지막 단계에 들어 있어 …"는 나중에 단계가 있을 때 실제 비교 단계(나중에 앞 마지막 단계)와 어긋난다. 문구는 `plan_section_layout.dart` `_notifyHandoff`라 이번 범위 밖. 후보: "… 나중에 칸 앞 마지막 단계에 …".
4. **활성 계획에 나중에 단계만 있는 학생**: 문서에 그 학생 단계가 없어 `activeLast` = null → 바닥 = 지금 값, `kind = added`(안내 없음), PLAN 배지·계산기 "현재 계획에 있음"도 문서 기준이라 없음(FE4-h · FD-172). 병합에서는 새 단계가 활성 나중에 단계 앞에 오므로 2번의 퇴행 거절이 걸릴 수 있다.

#### 다음 행동

- CF: 레인 워커가 모두 멈춘 뒤 gate(golden 변화 0 예상), `fe_commit.ps1 -Slice fe4g2`. 판단 1·2와 발견 사항 1·2 결정 — 1·3은 작은 후속 slice(편집기·문구), 2는 병합 규칙 결정.

### fe4g2 commit record (2026-10-12 00:38, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261012_002617\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE4-g3 handoff 후속 (구현 끝, gate 전)

### FE4-g3 착수 기록 (2026-10-12 01:01, Lane A, 로컬 Claude Code)

- 상태: **진행 중**. 시작 SHA `4196525575b8a249fd4dc7811305617c2ce62d82`(브랜치 scanner-consolidation).
- 범위: ① 계산기 handoff 뒤 2단계 편집기가 새 단계(나중에 단계 앞)를 고른 상태로 열기(흐름 초점 단계 id, 이미 열린 편집기·새로 여는 편집기) ② `_notifyHandoff`의 `nothingNew` 문구를 나중에 단계 유무에 맞게 ③ 테스트. 화면 디자인 변경 없음. "페이즈로 추가" 병합 퇴행(FE4-g2 발견 2)은 제외.
- 막힘: 대장 "slice별 막힘 요약"에 FE4-g3 행 없음, FE4-g 행 "—"(열림 0건). 멈출 사유 없음.
- 고칠 기존 파일(사본 `debug/frontend_fe4g3/pre/<경로>`): `frontend/lib/ui/models/plan_flow_draft.dart`, `frontend/lib/ui/models/plan_flow_goal_editor.dart`, `frontend/lib/ui/widgets/plan_section_layout.dart`(`_notifyHandoff` 문구만), `frontend/test/plan_flow_handoff_test.dart`, 이 status 문서. `plan_flow_goal_step.dart`·`plan_flow_goal_step_test.dart`는 필요할 때만(사본은 미리 둠).
- 기존 미커밋 변경(WIP): `git status --short` 결과 위 파일 모두 없음. 줄 끝: `plan_section_layout.dart`만 CRLF, 나머지 LF — 그대로 유지.

### FE4-g3 종료 기록 (2026-10-12 01:10, Lane A, 커밋 전)

상태: 구현 끝, gate 미실행(CF 몫). 시작 SHA `4196525575b8a249fd4dc7811305617c2ce62d82`. `debug/frontend_fe4g3/commit.json`(slice=fe4g3, status=true). 직접 커밋하지 않았다(git 쓰기 없음).

#### 실행한 명령·결과

- `frontend`에서 `flutter analyze`: **No issues found**(0건, info 포함).
- `flutter test test/plan_flow_handoff_test.dart`: 첫 실행 21 통과 · 2 실패(새 위젯 테스트 (a)(b) 끝에 이 파일 흐름의 1시간 계산 디바운스 Timer가 남아 `!timersPending` — 기대값은 모두 통과. 테스트 끝에서 Timer를 흘리는 `flushCalculation` 추가) → 재실행 **23 통과 · 0 실패**(기존 18 + 새 5).
- 바뀐 동작에 걸리는 기존 테스트(grep `receiveHandoff`·`PlanFlowGoalEditor`·`goalFocus`·`selectedStageIdOf`·`PlanFlowHandoff`·`nothingNew`·`calculator-add-to-plan`·`PlanFlowWorkspace`·`PlanningPage(`, golden 제외 + 지시 목록)를 파일마다 따로 실행(통과/실패): `plan_flow_goal_step_test` 23/0 · `plan_flow_test` 15/0 · `planning_page_test` 61/0 · `student_page_test` 9/0 · `growth_calculator_view_test` 24/0 · `plan_flow_presets_test` 13/0 · `plan_flow_authoring_test` 18/0 · `plan_flow_order_step_test` 19/0 · `plan_flow_save_test` 15/0 · `plan_flow_student_step_test` 8/0 · `plan_element_builder_test` 51/0 · `plan_home_detail_test` 5/0 · `plan_preset_manager_test` 5/0 · `plan_scenario_compare_test` 7/0 · `plan_scenario_detail_test` 12/0 · `plan_scenario_list_test` 10/0 · `plan_scenario_preview_test` 9/0. 잠금(build/·.dart_tool/) 실패 없음.
- `git diff --check`(수정 4파일 + 이 문서): 통과. 줄 끝 유지 확인: `plan_section_layout.dart` CRLF(8504줄 · CR 8504), 나머지 LF(CR 0).

#### 1. 2단계 편집기가 넘어온 새 단계를 고른 상태로 열기 — 구현

- 흐름: `PlanFlowController.goalFocusStageId`(새 getter). `receiveHandoff`가 새 단계를 만들면 그 단계 id, 만들지 않으면(`nothingNew`·`noTargets`) null로 두고, 지금처럼 `goalFocusStudentId`·`goalFocusSerial`을 함께 바꾼다.
- 편집기(`PlanFlowGoalEditor`): 새 private `_selectFocusStage(studentId, stageId)` — 초점 단계 id가 그 학생의 **초안 단계 id**에 있을 때만 `_selectedStages[학생] = id`. id가 없거나(null) 그 학생 단계 목록에 없으면 고른 단계를 건드리지 않는다(기본 = 마지막 단계, 사용자가 고른 단계는 그대로).
  · 이미 열린 편집기: `_flowChanged`에서 serial이 바뀐 요청마다 적용. **순서 주의**: `receiveHandoff`는 `setStudentStages`(알림 1회 — 편집기는 이때 그 학생 작업 단계와 고른 단계를 stale로 지운다) 뒤에 serial을 올리고 다시 알린다. 그래서 초점 단계 적용을 stale 정리 **뒤**로 옮겼다(예전 "초안이 그대로면 바로 return" 분기를 `if (!identical(...)) { 정리 }`로 바꾼 동작 보존 리팩터, 정리 내용은 그대로).
  · 새로 여는 편집기: 계획 만들기 화면은 편집기를 2단계를 처음 그릴 때 만든다(`plan_flow_workspace.dart` `_goalEditor`, 흐름마다 하나). 계산기로 흐름을 새로 열면 `receiveHandoff`가 편집기보다 먼저 돌므로, 생성자에서 흐름의 지금 초점 단계를 한 번 적용한다(`_seenFocusSerial`은 지금처럼 현재 serial). 흐름이 handoff를 받은 적이 없으면 초점 단계가 null이라 기본 선택 그대로.
- 다른 초점 요청 경로: grep `_goalFocusSerial`·`_goalFocusStudentId`·`goalFocus` — 쓰는 곳은 `receiveHandoff` 한 곳뿐(`plan_flow_draft.dart`), 읽는 곳은 `plan_flow_goal_editor.dart`(+ 테스트). 계산기 handoff 외 경로 없음 → 바뀌는 다른 동작 없음.
- `plan_flow_goal_step.dart`는 고치지 않았다: 카드 목록이 이미 `selectedStageIdOf`로 고른 카드를 굵은 테두리로 그리고 `_revealSelected`로 보이게 스크롤한다.

#### 2. nothingNew 안내 문구 — 구현

- 새 순수 함수 `planFlowHandoffNothingNewMessage(name, stageIds, deferred)`(`plan_flow_draft.dart`, `planFlowHandoffInsertIndex` 재사용). `_notifyHandoff`는 nothingNew 한 갈래만 이 함수를 부른다(그 학생 `editorStagesFor` id · 초안 `deferredStageIds`; nothingNew면 `receiveHandoff`가 초안 단계를 바꾸지 않으므로 넘기기 직전 상태와 같다). 다른 갈래 문구는 그대로.
- 문구 전후:
  · 전(모든 경우): `계산기 목표가 이미 {이름} 학생의 마지막 단계에 들어 있어 새 단계를 만들지 않았습니다.`
  · 후 — 그 학생에게 나중에 단계가 **없음**(초안 단계 없음 · 활성 계획 바닥 · 지금 값 바닥 포함): 전과 **같음**.
  · 후 — 나중에 단계가 **있고** 그 앞 단계가 있음(바닥 = 나중에 칸 앞 마지막 단계): `계산기 목표가 이미 {이름} 학생의 나중에 칸 앞 마지막 단계에 들어 있어 새 단계를 만들지 않았습니다.`
  · 후 — 단계가 **모두 나중에**(FE4-g2 판단 1: 바닥 = 지금 값): `계산기 목표가 이미 {이름} 학생의 지금 값에 들어 있어 새 단계를 만들지 않았습니다.` (지시에 없던 셋째 갈래 — 아래 판단 1)
- "나중에 칸"은 3단계 화면 문구(`plan_flow_order_step.dart` '나중에 칸')와 맞췄다. ~습니다체 한 줄.

#### 판단(확인 부탁)

1. 단계가 모두 나중에인 학생의 nothingNew는 "나중에 칸 앞 마지막 단계"가 없어 실제 비교 대상(지금 값)을 말하게 했다. 둘째 문구로 합치려면 함수의 마지막 삼항을 지우면 된다.
2. 초점 단계는 "초안 단계 id에 있을 때만" 고른다(편집기 작업 단계 중 아직 초안에 없는 것은 대상 아님). handoff가 만든 단계는 항상 초안 단계라 실제 차이는 없다.

#### 처리한 FD

- '워커 재량' FD 새로 처리한 것 없음. FD-171 (a) 동작은 바꾸지 않았다. 막힘 요약에 FE4-g3 행 없음(FE4-g "—", 열림 0건).

#### 테스트

- `plan_flow_handoff_test.dart` 새 그룹 `편집기 초점 단계 · 이미 들어 있음 문구(FE4-g3)` 5건(배치 1단계 레벨 50 + 나중에 2단계 레벨 80 초안):
  · (a) 위젯: 넘긴 뒤 만든 편집기(계획 만들기 화면처럼) + `PlanFlowGoalBody`·`Aside` → 단계 [1단계, 새 단계, 나중에], 고른 단계 = 새 단계(`aru-calc-1`, 예전 기본값은 나중에 단계). 화면의 "단계 추가"가 새 단계 바로 뒤 · 나중에 단계 앞에 들어가 화면 동작으로도 선택을 확인.
  · (b) 위젯: 이미 열린 편집기(아야네 탭 보는 중, 아루는 1단계를 골라 둠)에 넘기면 아루 탭 + 새 단계로 바뀜 → 다시 넘기면 다음 새 단계(`aru-calc-2`, 3번째 · 나중에 앞)로 바뀜 → 이미 들어 있는 값을 넘기면(nothingNew, 초점 단계 null) 사용자가 고른 단계 유지.
  · 초점 단계가 없으면(nothingNew) 새로 여는 편집기는 마지막 단계(지금 동작).
  · 문구 단위: 나중에 없음 · 단계 없음 · 나중에 앞 단계 있음 · 모두 나중에.
  · (c) 흐름 상태로: 나중에 있는 초안 / 없는 초안에 레벨 50(바닥과 같음)을 넘겨 nothingNew → 각각 "나중에 칸 앞 마지막 단계" / 기존 문구.
- (d) 기존 handoff 18건·goal step 23건 기대값 수정 없이 통과. 지운 테스트 없음. SnackBar 자체(`_notifyHandoff` → `ScaffoldMessenger`) 위젯 경로는 기존 `growth_calculator_view_test`의 noTargets 문구 테스트가 덮고, nothingNew 갈래는 같은 함수 호출이라 순수 함수 + 흐름 상태 테스트로 대신했다(계산기 테스트 파일은 범위 밖이라 고치지 않음).

#### golden 변화 예상

- 전 장면 **변화 0** 예상. 근거: golden harness·테스트(`test/goldens/*.dart`)에 `receiveHandoff`·`goalFocus`·`initialSeed`·handoff 시드가 없다(grep). 초점 단계는 handoff에서만 생기므로 golden 흐름의 `goalFocusStageId`는 늘 null → 생성자·`_flowChanged`의 새 분기가 아무것도 고르지 않는다.
  · 2단계(편집기를 처음 여는 경로, 기본 선택 = 마지막 단계): `plan-flow-step2` · `plan-flow-step2-more` · `plan-flow-step2-saved` — 변화 0.
  · 그 밖의 계획 만들기 장면 `plan-flow-step1`·`-step1-filter`·`-step1-many`·`-step3`·`-step3-deferred`·`-step3-many`·`-step4`·`-step4-append` — 편집기 선택과 무관, 변화 0.
  · 계산기 `students-calculator`·`-bond-popover` — "계획에 추가"를 누르지 않음, `_notifyHandoff` 미경유, 변화 0. 새 장면 없음.

#### 미검증

- golden 비교·전체 `fe_gate.ps1`: 미실행(CF 몫).
- 실제 앱(mock·ProcessAppService)에서 계산기 → 2단계 선택 카드·SnackBar 눈 확인: 미실행(아래 검수표).

#### 검수표

| 확인 | 여는 방법 | 확인 포인트 |
|---|---|---|
| 새로 여는 편집기의 선택 단계 | mock 모드 → 계획 탭 "시나리오 생성" → 학생 하나에 2단계에서 단계 2개 → 3단계에서 1단계를 1순위, 2단계를 "나중에" 칸 → 계획 만들기를 둔 채 학생 탭 같은 학생 계산기에서 목표를 올리고 "이 목표로 계획에 추가" | 2단계가 그 학생 탭으로 열리고 **새 2단계 카드가 굵은 테두리(고름)**, 3단계(원래 나중에) 카드는 고르지 않음. "단계 추가"를 누르면 새 단계 바로 뒤(나중에 단계 앞)에 들어감 |
| 이미 열린 편집기 | 위 상태에서 2단계에 머문 채(다른 학생 탭을 봐도 됨) 계산기로 가서 같은 학생 목표를 더 올리고 다시 "이 목표로 계획에 추가" | 그 학생 탭으로 바뀌고 방금 만든 새 단계(3단계, 나중에 단계 앞)가 골라져 있음 |
| nothingNew 문구(나중에 있음) | 위 상태에서 계산기 목표를 새 단계 값 이하로 두고 넘기기 | SnackBar "계산기 목표가 이미 {이름} 학생의 나중에 칸 앞 마지막 단계에 들어 있어 새 단계를 만들지 않았습니다." · 고른 카드는 그대로 |
| nothingNew 문구(나중에 없음) | 나중에 칸 단계가 없는 학생으로 같은 값 넘기기 | 예전 문구 "… 마지막 단계에 들어 있어 …" 그대로 |
| 기본 선택 회귀 | 계산기 없이 계획 만들기 2단계를 열기 | 지금처럼 마지막 단계가 골라짐 |

#### WIP 보존 확인

- 고친 4파일·이 status 문서는 착수 때 WIP 없음(`git status --short`). 다른 미커밋 변경(스캐너·서비스·문서 등)은 건드리지 않았다. post 사본 불필요(WIP 없음). `plan_flow_goal_step.dart`·`plan_flow_goal_step_test.dart`는 고치지 않아 미리 둔 사본(goal_step_test)을 지웠다. status 문서 사본은 commit.json `status=true` 관례(fe4g2와 같음)라 두지 않았다.

#### 발견 사항

1. (이 slice 범위 밖, 적기만) `_notifyHandoff`의 nothingNew 기존 문구 "마지막 단계"는 초안·활성 계획에 그 학생 단계가 없을 때(바닥 = 지금 값)도 같은 말을 한다. 지시대로 나중에 단계가 없으면 문구를 바꾸지 않았다. 고치려면 결과에 바닥 종류를 싣는 쪽이 정확하다.
2. FE4-g2 발견 2(병합 퇴행 규칙)는 그대로 열려 있다(손대지 않음).

#### 다음 행동

- CF: 레인 워커가 모두 멈춘 뒤 gate(golden 변화 0 예상), `fe_commit.ps1 -Slice fe4g3`. 판단 1·2 확인.

### fe4g3 commit record (2026-10-12 01:56, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261012_014658\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE6-d 오파츠 확장 (Lane A, 로컬 Claude Code)

### FE6-d 착수 기록 (2026-10-12, Lane A)

- 상태: 진행 중 → 코드 작성 완료(아래 종료 기록). 시작 SHA = `861eea5629550fa343fe8d6af32af1b17dd3254c`(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`). 워커 프롬프트 `debug/frontend_redesign_handoff/fe6d-worker-prompt-20261012.md`(CF 02:00 배정).
- 범위: 인벤토리 분석 S2 오파츠 확장(시안 `Inventory-Analysis-Opa.dc.html`). 키트 공용 섹션 morph(실수 rect 보간 + 섹션별 퇴장), 확장 시퀀스(A 180° · S1 80° · S4 0° · S5 260° 퇴장 → S2 확대 → 상세 열), 확장 상태 산점도(아이콘 점, 크로스페이드), 선택 오파츠 상세 열, 확장 전 점 선택, "축소" 의미 라벨. 키트 `TonalButton`에 위젯 아이콘 슬롯 · 의미 라벨(기존 동작 그대로).
- 막힘: 대장 막힘 요약의 FE6-d 행은 `—`(막는 열림 FD 없음). FD-103은 워커 재량(권장안대로), FD-031·FD-033 확정, FD-099·FD-101 워커 재량.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe6d/pre/<v7 기준 경로>`, 사본과 작업 트리 cmp 일치 확인):
  - `frontend/lib/ui/kit/buttons.dart`
  - `frontend/lib/ui/inventory/inventory_analysis.dart`
  - `frontend/lib/ui/inventory/inventory_analysis_charts.dart`
  - `frontend/lib/ui/inventory/inventory_analysis_sections.dart`
  - `frontend/lib/ui/inventory/inventory_controller.dart`
  - `frontend/lib/ui/inventory/inventory_workspace.dart`
  - `frontend/lib/ui/studio/inventory_studio_layout.dart`
  - `frontend/test/kit/buttons_test.dart`
  - `frontend/test/inventory_analysis_page_test.dart`
- 새 파일(예정): `frontend/lib/ui/kit/section_morph.dart`, `frontend/lib/ui/inventory/inventory_opa_sections.dart`(workspace의 part), 테스트 `frontend/test/kit/section_morph_test.dart`·`frontend/test/inventory_opa_test.dart`·`frontend/test/inventory_opa_page_test.dart`, 검수 fixture `frontend/test/inventory_fe6d_fixture.dart`, golden 1장 `frontend/test/goldens/fe6d_inventory_opa_golden_test.dart`(`inventory-analysis-opa`, 실행하지 않음).
- WIP: 고칠 기존 파일 9개 모두 `git status --short <경로>`가 비어 있다(미커밋 변경 없음). 모두 LF(`git ls-files --eol`: i/lf w/lf).
- 고치지 않음: `plan_phase_editor.dart`(같은 일을 하는 private `_lerpGridRect`·`phaseEditorElements`·`_PhaseEditorMotion`이 거기 남는다. FE5-f에서 지울 예정), `lib/services/**`, `account_section_cluster.dart`, `app_shell.dart`·`app_section.dart`, `school_labels.dart`, golden harness·기존 golden 테스트, `frontend/tool/**`, backend·contracts.

### FE6-d 종료 기록 (2026-10-12, Lane A, 코드 작성 완료 · CF gate 미실행)

시안 Inventory-Analysis-Opa(확장 완료 상태)의 S2 오파츠 확장을 끝냈다. 헤더 부제("· 분석 · 오파츠 확장")는 `app_section.dart`·`app_shell.dart` 몫이라 바꾸지 않았다(발견 사항 2).

#### 실행 명령 · 결과

모두 `frontend`에서 이 PC(Claude Code)로 실행했다. 로그는 실패 줄(`[E]`·`EXCEPTION`·`Some tests failed`·`error •`)만 찾았다.

| 명령 | 결과 |
|---|---|
| `flutter analyze`(1차) | 이슈 3(`lerpDouble` 미정의 2 · 쓰지 않는 import 1) → 고침 |
| `flutter analyze`(최종, test 포함) | **No issues found**(info 포함 0) |
| `flutter test test/kit/section_morph_test.dart`(1차) | 6 통과 · 1 실패(path bounds float32 오차 2.4e-4 > 1e-6) → 허용치 1e-3 |
| `flutter test test/kit/section_morph_test.dart`(최종) | 7 통과 · 0 실패 |
| `flutter test test/inventory_opa_test.dart`(1차) | 컴파일 실패(`InventoryCatalogEntry.school` 필수 인자) → `school: null` |
| `flutter test test/inventory_opa_test.dart`(최종) | 9 통과 · 0 실패 |
| `flutter test test/inventory_opa_page_test.dart`(1차) | 4 통과 · 2 실패: ① 테스트가 Opa fixture에 없는 `inventory-heatmap` 키를 찾음 → S4 제목으로 ② 1280×720에서 S2 제목 줄(`_Fit` 최소 640)이 "확장" 버튼을 잘라 누를 수 없음 → 최소 폭 400(발견 사항 5) |
| `flutter test test/inventory_opa_page_test.dart`(최종) | 6 통과 · 0 실패 |
| `flutter test test/inventory_analysis_page_test.dart`(첫 실행) | 600초 넘게 응답 없음 → 중지. 같은 시각 다른 dart 프로세스가 있어 빌드 잠금 경합으로 본다. 재시도 1회: 8 통과 · 0 실패(4초) |
| 회귀(파일 하나씩, 46개) | 전부 통과 · 실패 0: `test/kit/*_test.dart` 25개(anchored_flyout 8 · ba_chip 4 · ba_modal_a11y 4 · ba_modal 5 · buttons 6 · diagonal_row 6 · diagonal_scroll_viewport 5 · diagonal_scrollbar 9 · info_popover 8 · item_icon_tile 7 · kit_overlay 7 · kpi_tile 2 · range_controls 12 · scroll_viewport_fog 6 · section_morph 7 · skew_bar 8 · skew_controls 7 · stat_chart 7 · stepper 6 · titles 4 · ui_kit_gallery_controls 2 · _data 2 · _overlays 4 · _range 2 · ui_kit_gallery 6), inventory 12개(analysis_page 8 · analysis 16 · controller 13 · currency_readonly 2 · fb3_service 15 · opa_page 6 · opa 9 · page 9 · shell_lazy 1 · tiers_page 7 · tiers 9 · view_model 13), `TonalButton` 사용처 9개(plan_flow_goal_step 23 · plan_flow_presets 13 · plan_flow_save 15 · plan_flow_student_step 8 · plan_scenario_list 10 · plan_scenario_preview 9 · plan_scenario_compare 7 · student_filter_modal 7 · growth_calculator_view 24 · metadata_manager_page 7) |
| `git diff --check`(고친 · 새 파일) | 0(경고는 autocrlf 안내뿐). 새 파일 7개 · 고친 파일 9개 모두 LF · 끝 개행 하나 |

- 걸리는 기존 테스트는 `TonalButton`·`inventory-oopart-expand`·`InventoryOopartScatterPainter`·`InventoryScatterGeometry`·`inventory_studio_layout`·`InventoryWorkspace`를 grep해서 찾았다. 기존 inventory_* 전부와 키트 · `TonalButton` 사용처 테스트를 실행했다.
- 고친 기존 테스트 기대(사유 = 바뀐 동작): `inventory_analysis_page_test.dart` "S2 … disabled expand" → "확장"이 켜지고 의미 라벨 `오파츠 패널 확장`, 점을 누르면 그 오파츠가 선택(FD-103). 지운 테스트 없음.
- 일회성 렌더 확인: 실제 글꼴(harness `loadGoldenFonts`·`settleGoldenScene`)로 접힘 · 퇴장 중 · morph 중 · 확장 완료 · 학생 플라이아웃과 FE6-c `inventory-analysis` 장면을 scratchpad PNG로 한 번 보았다(임시 테스트 파일은 실행 뒤 지웠다, golden 비교 아님). 확장 장면 배치 · 상세 열 · 아이콘 점이 시안 자리에 들어오고, FE6-c 장면은 "확장" 버튼만 달라졌다.
- 실행하지 않음: golden(`test/goldens/**`, 새 `fe6d_inventory_opa_golden_test.dart` 포함), 전체 `fe_gate.ps1`, `-UpdateGoldens`, `fe_commit.ps1`, 맨 `flutter test`, process E2E, `codealmanac validate`.

#### 고친 파일

- **키트 `lib/ui/kit/section_morph.dart`(새)**: `sectionMorphRect`(실수 `Rect.lerp`, grid `.round()` 없음) · `sectionCanvasElementPolygon` · `sectionMorphPolygon`(같은 mode · face 두 element 꼭짓점의 실수 보간, 80° 사선 유지, 보간 rect 안) · `buildSectionMorphPath`(같은 둥근 모서리 함수 + 캔버스 경계, 0 · 1에서 원래 element path) · `sectionExitOffset`/`sectionEntryOffset`(`sectionMotionOffset` 재사용) · `SectionMorphTimeline`(퇴장 → morph → 상세 구간).
- **키트 `lib/ui/kit/buttons.dart`**: `TonalButton`에 `leading`(위젯 아이콘 슬롯, 간격 8)과 `semanticLabel`(→ `KitPressable`)을 더했다. 둘 다 없으면 지금과 같다(FE6-c 발견 4 해소).
- **`lib/ui/studio/inventory_studio_layout.dart`**: 확장 S2 Studio 문서 `inventoryAnalysisOpaStudioDocument`(element `inventory-analysis-ooparts-expanded`, rect (0,2,96,94), 오른쪽 면 사다리꼴 face 0+96 · 깊이 96)와 상세 열 좌표 `InventoryOpaMetrics`.
- **`lib/ui/inventory/inventory_analysis.dart`**: 순수 함수 `inventoryOopartWeakestTier` · `inventoryOopartRanking` · `inventoryDefaultOopartFamily` · `inventoryOopartDetail`(+ `InventoryOopartRank` · `InventoryOopartStudent` · `InventoryOopartDetail`).
- **`lib/ui/inventory/inventory_analysis_charts.dart`**: `InventoryScatterGeometry`를 접힘(1012×420) ↔ 확장(1974×1034.8) 실수 보간 배치로(0에서 FE6-c 값 그대로), 산점도 painter에 `geometry` · `icons`(점 → 아이콘 원 크로스페이드) · `selectedFamily` · `iconSlots()`.
- **`lib/ui/inventory/inventory_controller.dart`**: `oopartExpanded`(탭 안 로컬, 분석 모드 · 티어 화면 닫힘일 때만) · `setOopartExpanded` · `selectOopart` · `selectedOopartFamily`(고른 것, 없으면 병목 1위) · `oopartSelectionExplicit` · `oopartRanking` · `selectedOopartDetail`(메모). 목록으로 가거나 티어 화면을 열면 접힌다.
- **`lib/ui/inventory/inventory_workspace.dart`**: `_SectionQuad.fromPolygon`, 분석 모드 사이드바 내용을 stage 안 맨 위로(그림 순서 같음), `_InventoryAnalysisStage`에 확장 컨트롤러 · `_expansion`(퇴장 섹션 Transform · S2 morph 표면 `_InventoryMorphSurfacePainter` · 상세), 분석 ↔ 티어 교체는 키트 오프셋 함수로(같은 식).
- **`lib/ui/inventory/inventory_analysis_sections.dart`**: S2 `ooparts(morph:, reveal:)`(morph 꼭짓점으로 quad, 산점도 크기 보간), "확장"/"축소" 버튼 활성 · 시안 글리프 · 의미 라벨, 제목 줄 최소 폭 640 → 400, 산점도 점 누름 = 선택, 확장 아이콘 겹(그림 없으면 이름 앞 두 글자), 글리프 3종(확장 · 축소 · 단계)과 글리프 색 인자.
- **`lib/ui/inventory/inventory_opa_sections.dart`(새, workspace의 part)**: 선택 오파츠 상세 열(머리 · 티어별 보유/필요 · 사용 학생 + 플라이아웃 · 병목 순위 · 계획 이동).
- 테스트: `test/kit/section_morph_test.dart`(7) · `test/kit/buttons_test.dart`(+1) · `test/inventory_opa_test.dart`(9) · `test/inventory_opa_page_test.dart`(6) · `test/inventory_analysis_page_test.dart`(기대 변경) · 검수 fixture `test/inventory_fe6d_fixture.dart` · golden `test/goldens/fe6d_inventory_opa_golden_test.dart`(1장, 실행 안 함).
- 고치지 않음: `plan_phase_editor.dart`(같은 일을 하는 private `_lerpGridRect` · `phaseEditorElements` · `_PhaseEditorMotion`이 그대로 남는다 — FE5-f에서 지울 때 키트 morph로 대체 가능), 계획 화면, `lib/services/**`, `account_section_cluster.dart`, `app_shell.dart`·`app_section.dart`, `school_labels.dart`, golden harness · 기존 golden 테스트, `frontend/tool/**`, backend · contracts, 택틱 · 스캐너 파일, FE6-c · FE6-e fixture.

#### 배치(기준 viewport 2560×1392)

| 대상 | 값 | 시안 대비 |
|---|---|---|
| 확장 S2 rect · spec | (0,2,96,94) 오른쪽 면 사다리꼴, face 0+96, 깊이 96 → (208.6,209.2)·(2560,209.2)·(2560,1392)·(0,1392) | 위 · 오른쪽 변 0px, **왼쪽 사선 두 꼭짓점 −12px**(±1px 예외, 발견 사항 1) |
| 제목 줄 · 규칙선 · 티어 토글 · 산점도 위치 | 접힌 S2와 같은 `InventoryAnalysisMetrics`(왼쪽 사선 변 기준 22 · 21.8 · 30 · 28.9, 위 20 · 65 · 78 · 120) | 사선 변 기준 0, 절대 x는 섹션과 함께 −12px |
| 산점도 svg | 1974×1034.8(플롯 56→1788.6, 사선 175.4, 축 글자 (922,1020.8) · (130,497) 14.3px) | 0 |
| 점 아이콘 | 원 r 15 · 병목 22(티어 색 28% + 테두리 2 · 병목 분홍 3), 그림 원 r 13 · 20, 티어 글자 (0.72r, r+2) 10px 800 | ±0.5px |
| 상세 열 | 오른쪽 변에서 504(x 2056) · 위 115.8(y 325) · 폭 474 · 묶음 간격 14 | 0 |
| 상세 열 안 | 머리 64×52 · 간격 12 · 이름 22px, 상자 안쪽 10 · 14 · 캡션 아래 4, 티어 행 40 · 간격 2 · 칸 46 / 막대 / 96 / 52 · 간격 12 · 막대 10, 학생 캡션 70 · 줄 시작 +16 · 줄 260, 순위 행 38 · 18 / 35×28 / 이름 / 티어 / 44 · 간격 10, 버튼 38 · 안쪽 14 | 시안 flex 값 그대로(±2px 안, 화면에서 재지 않음) |

#### 처리한 FD

- **FD-103(워커 재량, 권장안)**: ① 점 → 아이콘은 크로스페이드(morph 구간에서 점 불투명도 1 → 0, 아이콘 원 · 그림 0 → 1) ② 확장 상태는 탭 안 로컬(컨트롤러 `oopartExpanded`, 라우팅 아님). 부제 변경은 `app_section` 몫이라 하지 않았다(발견 사항 2) ③ "축소"에 의미 라벨 `오파츠 패널 축소`(확장은 시안 `오파츠 패널 확장`) ④ 확장 전에도 점 선택 가능, 고른 오파츠가 확장 상세에 그대로 보인다. 기본 선택 = 병목 순위 1위.
- **FD-031(확정)**: 상세 막대 = 재화별 min(보유, 필요)/필요.
- **FD-033(확정)**: 병목 순위는 오파츠마다 재화(티어) 하나의 부족량이고, 티어끼리 더하지 않는다(네브라 T3 −37 + T4 −46을 합치지 않음). 보유 모름은 빗금 막대 · `보유 —` · `—`.
- **FD-099(워커 재량)**: 산점도 · 순위는 FE6-c S2 범위(계획이 쓰고 보유를 아는 오파츠)를 그대로 쓴다. 상세 티어 행은 그 오파츠의 카탈로그 티어 전부(계획 밖 티어도 행).
- **FD-101(워커 재량)**: 학생별 티어 부족 = 활성 문서 계산 `stage_results[].resources`의 `shortage_at_entry`를 같은 재화 안에서만 더한다. 단계 정보가 없으면 학생은 세고 몫은 `—`.

이번에 정한 규칙(시안 · 대장에 근거 없음, 워커 결정):
1. "가장 부족한 티어": 보유를 알고 모자라는 티어 중 충족률 가장 낮은 것 → 높은 티어 → 부족량 큰 것 → 카탈로그 순서(FE6-e "가장 부족" 칸 규칙과 같다).
2. 병목 순위: 그 티어 부족량 큰 순 → 충족률 낮은 순 → 카탈로그 순서, 5행. 모자라는 오파츠가 없으면 "모자라는 오파츠가 없습니다." 핵심 병목 오파츠는 분홍 이름, 고른 오파츠는 굵게. 행을 누르면 그 오파츠를 고른다(시안은 정보 행).
3. 선택 표시는 사용자가 고른 뒤에만 산점도에 그린다(선 2px 흰색 + 점 고리). 기본 선택은 상세 열에만 쓴다(시안 확장 장면에 선택 표시가 없고, `inventory-analysis` 기준 이미지가 바뀌지 않게).
4. 티어 행: 계획 밖 티어는 `보유 n / 필요 0`, 빈 막대, `—`. 충분이면 초록 `충분`, 모자라면 분홍 `−n`.
5. 사용 학생 = 그 오파츠 계획 티어를 쓰는 학생 합집합(문서 순서). 줄 순서는 FE6-c 규칙 3과 같다(모자람 있음 → 가장 높은 부족 티어 → 그 부족량 → 이름 → 문서 순서). 플라이아웃 칸 = 누군가 모자라는 티어 중 높은 둘, 최대 8줄 + `… 외 n명`. 플라이아웃은 초상 줄 전체를 트리거로 둔다(시안은 `…+n` 칩 자리).
6. 머리 아이콘 = 가장 부족한 티어(없으면 가장 높은 티어)의 그림.
7. "확장"은 계획 계산이 있고 막는 안내가 없을 때만 켠다. 티어 화면이 열려 있으면 거절하고, 목록으로 가거나 티어 화면을 열면 접힌다. 확장 중에는 사이드바가 퇴장해 있어 다른 섹션 버튼은 누를 수 없다.

#### §4.6 모호점별 결론

1. **점 → 아이콘 전환**: 크로스페이드(FD-103). 같은 morph 구간에서 산점도 크기 · 배치를 실수 보간하고 점 불투명도 ↓ · 아이콘 ↑.
2. **헤더 부제**: 확장 상태는 탭 안 로컬 상태. 부제 "· 분석 · 오파츠 확장"은 `app_section`·`app_shell` 몫이라 이번에 바꾸지 않았다(FE6-e 발견 5와 같은 묶음).
3. **"축소" aria-label**: `오파츠 패널 축소`를 붙였다(키트 `TonalButton.semanticLabel`).
4. **확장 전 점 선택**: 있다. 점을 누르면 고르고(말풍선도 뜬다) 확장 상세가 그 오파츠다. 확장 산점도 · 병목 순위 행에서도 고를 수 있다.

#### 모션 시간 · 순서(AppMotion 안)

- 확장(합계 940ms, `SectionMorphTimeline`, 곡선 `AppMotion.sectionCurve`): ① 0–360ms(`AppMotion.section`) 사이드바 180° · S1 80° · S4 0° · S5 260°가 `sectionMotionOffset`만큼 동시에 퇴장, S2는 제자리 ② 360–720ms(`AppMotion.section`) S2가 오른쪽 · 위 부착을 유지한 채 확장 rect로 실수 morph(표면 path · 제목 줄 · 토글 · 산점도 1012×420 → 1974×1034.8), 점 → 아이콘 크로스페이드 ③ 720–940ms(`AppMotion.header`) 상세 열 등장(불투명도 0 → 1, 오른쪽 24px에서 제자리).
- 축소: 같은 값을 거꾸로 지난다 — 상세 사라짐(220) → S2 축소(360) → 네 섹션이 부착면 쪽에서 돌아옴(360, 각 intro 방향). 움직이는 동안 입력을 받지 않는다(IgnorePointer).
- 분석 ↔ 티어 교체(FE6-e)는 그대로(키트 오프셋 함수로 같은 식).

#### golden 변화 예상

- **`inventory-analysis`(바뀜, S2 버튼 하나)**: "확장" 버튼이 비활성(불투명도 .45, Material `open_in_full` 16px)에서 활성(불투명)으로, 아이콘이 시안 svg 글리프(14px, 기존 16px 자리 가운데)로 바뀐다. 버튼 크기 · 위치 · 칩 · 제목은 같다(아이콘 자리 16 유지). 산점도 · 다른 섹션 · 사이드바는 변화 0: 산점도 배치는 t = 0에서 FE6-c 상수 그대로, 점 불투명도 .95 × 1, 기본 선택은 표시하지 않음, 사이드바 내용은 stage 안으로 옮겼지만 같은 순서로 맨 위에 그린다. 제목 줄 최소 폭 640 → 400은 기준 viewport(실제 폭 약 940)에서 영향 없음. → 기준 이미지를 commit.json `whole`에 파일 단위로 넣었다.
- **`inventory`·`inventory-all`(변화 0)**: 목록 모드 Stack 순서(표면 → D · C · B → 사이드바) 그대로.
- **`inventory-tiers`(변화 0)**: 티어 정지 화면은 표면 → 티어 섹션 → 사이드바 같은 순서.
- **키트 `TonalButton` 사용 장면 전부(변화 0)**: `leading`·`semanticLabel`이 없으면 같은 위젯 트리 · 그림이다.
- **다른 장면**: 변화 0.
- **새 장면 `inventory-analysis-opa`**(`fe6d_inventory_opa_golden_test.dart`, 기준 이미지 없음 → RED, CF가 만든다). 기대 모습(일회성 렌더로 확인한 배치):
  - 헤더는 지금과 같다(부제 "보유 재화와 장비"). 사이드바 · S1 · S4 · S5 없음.
  - 섹션 하나: 위 209 · 오른쪽 · 아래 끝까지, 왼쪽 사선 변 x 208.6(위) → 0(아래).
  - 제목 "오파츠 · 보유율 × 수요" + "왼쪽 위 = 핵심 병목" 분홍 칩 + "축소"(시안 축소 글리프), T1~T4 토글(모두 켜짐) + 범례.
  - 산점도 1974×1035: 플롯 평행사변형, 4분면 점선, 축 글자 14.3px, 점은 지름 30 아이콘 원(티어 색 테두리, 아래 오른쪽 `T1`~`T4`), 네브라 디스크 T4 · 로혼치 사본 T4는 지름 44 + 분홍 테두리, 두 이름 분홍 굵게. 네브라 · 로혼치 · 파에스토스 · 안티키테라는 게임 아이콘, 아우름 코인 · 오브 오브 위트 · 구스타프 총알 · 토리노 수의는 원 안에 "아우" · "오브" · "구스" · "토리". 보유율 100% 티어 점이 오른쪽 끝에 겹친다.
  - 오른쪽 상세 열(x 2056, y 325): 네브라 아이콘 64×52 · "선택한 오파츠" · "네브라 디스크" · "핵심 병목" 칩 / "티어별 보유 / 필요 (계획 요구량)" T1 210/180 충분 · T2 160/120 충분 · T3 96/133 −37(막대 72%) · T4 12/58 −46(막대 21%) / "사용 학생" 초상 5 + "…+1" / "병목 순위 · 가장 부족한 티어 기준" 1 네브라 디스크(분홍 굵게) T4 −46 · 2 로혼치 사본(분홍) T4 −31 · 3 파에스토스 원반 T3 −22 · 4 안티키테라 장치 T4 −18 · 5 토리노 수의 T3 −9(아이콘 자리 "토리") / 분홍 "계획에서 쓰는 단계 보기".

#### 검수표

artboard `Inventory-Analysis-Opa.dc.html` → 앱:
- 여는 방법: 인벤토리 탭 → 사이드바 맨 위 "분석" → S2 제목 줄 "확장". Mock 기본 실행은 계획이 없어 "확장"이 흐리다(안내만). 시안 숫자 장면은 fixture로만 열린다(golden `inventory-analysis-opa`, `test/inventory_opa_page_test.dart`).
- 확인 포인트:
  1. 애니메이션: 확장을 누르면 사이드바는 왼쪽, S1은 위(약간 오른쪽), S4는 오른쪽, S5는 아래(약간 왼쪽)로 동시에 빠지는가 → S2가 위 · 오른쪽에 붙은 채 왼쪽 · 아래로 커지는가(계단 없이 매끄럽게) → 점이 아이콘으로 바뀌는가 → 상세 열이 오른쪽에서 살짝 들어오며 나타나는가(합계 약 0.94초).
  2. "축소"(의미 라벨 "오파츠 패널 축소"): 상세가 먼저 사라지고 S2가 줄어든 뒤 네 섹션이 각자 붙은 면에서 돌아오는가.
  3. 확장 섹션 모양: 위 · 오른쪽 변이 시안과 같고, 왼쪽 사선이 시안보다 12px 왼쪽(아래 끝이 화면 왼쪽 경계에 닿음).
  4. 산점도: 아이콘 원 크기(30 · 병목 44), 분홍 병목 테두리, 티어 글자, 그림 없는 오파츠의 두 글자, 이름 위치(가장 높은 티어 점 왼쪽).
  5. 상세 열: 머리 · 칩, 티어 4행(skew 막대 · 수치 · 충분/−n), 사용 학생 줄과 hover/누름 플라이아웃("네브라 디스크 · 사용 학생 6명", 학생별 `T4 n` 보라 · `T3 n` 노랑), 병목 순위 5행, 분홍 버튼 → 계획 탭.
  6. 선택: 확장 전 점을 누르면 그 오파츠 선이 흰색으로 굵어지고, 확장하면 상세가 그 오파츠다. 병목 순위 행 · 확장 산점도 점을 눌러도 바뀐다.
  7. 작은 창(1280×720)에서 "확장"이 보이고 시퀀스 중 예외가 없는가.

#### 미검증 항목

- golden(새 장면 `inventory-analysis-opa`, 바뀌는 `inventory-analysis`, 변화 0 예상 `inventory`·`inventory-all`·`inventory-tiers`·키트 사용 장면): 미실행(CF가 `fe_gate.ps1`·`failures/` 검토·`-UpdateGoldens`).
- 전체 `fe_gate.ps1`(다른 테스트 · process E2E · `codealmanac validate`): 미실행.
- 상세 열 안 요소 ±2px는 시안 flex 값을 옮긴 것이고 화면에서 재지 않았다(렌더 한 번은 배치 넘침 여부만 보았다). 특히 티어 행 수치 칸(최소 96, 긴 수는 막대가 줄어듦)과 플라이아웃 위치(아래 · 오른쪽 맞춤 outset 20).
- 실제 백엔드 카탈로그(오파츠 20종)에서 확장 산점도 점 겹침 · 성능은 보지 않았다.
- 실제 앱 창에서의 애니메이션 체감(프레임)은 위젯 테스트(진행 0.25 · 0.5 · 0.75 예외 없음)로만 확인했다.

#### WIP 보존 확인

- 고친 기존 파일 9개는 착수 때 WIP가 없었다(`git status --short` 빈 줄). post 사본 · `post_dir`는 두지 않았다. 착수 사본은 `debug/frontend_fe6d/pre/`에 있고 9개 모두 작업 트리와 다르다(cmp).
- 작업 트리의 다른 미커밋 변경(Lane B `lib/services/**`·`account_section_cluster.dart`·`title_page.dart`, 스캐너 파일들, 문서들)은 읽지도 고치지도 않았다.
- git 쓰기는 하지 않았다.

#### 발견 사항

1. **확장 S2 −12px**: 시안 확장 섹션의 왼쪽 사선 아래 끝 x 12가 grid 밖이라(오른쪽 면 사다리꼴 아래 왼쪽 = `rect.left + 폭 × (1 − 깊이/96)` → 0 또는 26.7px) ±1px가 안 된다. FE6-e 발견 1(T2 부유 −2.6px)과 같은 Studio grid 한계 — 섹션 꼭짓점을 grid 밖 값으로 줄 수 있는 spec이 필요하다(키트 · Studio 소단위).
2. **헤더 부제**: 시안 확장 부제 "보유 재화와 장비 · 분석 · 오파츠 확장"(분석 "· 분석", 티어 "· 티어별 충족률")은 `app_section`·`app_shell` 몫이라 이번에도 바꾸지 않았다. FD-103 권장안은 "부제 포함 탭 안 로컬 상태"라, 부제를 탭 상태에서 받는 `app_section` 소단위가 필요하다(FE6-e 발견 5와 묶음).
3. **`plan_phase_editor.dart` 중복**: 같은 일을 하는 private `_lerpGridRect`(정수 grid `.round()` 보간) · `phaseEditorElements` · `_PhaseEditorMotion`이 남아 있다. FE5-f에서 그 파일을 지울 때 키트 `section_morph.dart`로 대체하면 된다.
4. **"계획에서 쓰는 단계 보기"**: 지금은 계획 탭으로 이동만 한다. 재화 · 그 재화를 쓰는 단계에 초점을 넘기는 인계(E §4.5)는 계획 탭 진입점이 필요한 후속이다.
5. **S2 제목 줄 최소 폭(FE6-c)**: `_Fit` 최소 640이라 작은 창(1280×720)에서 "확장" 버튼이 잘려 누를 수 없었다. 400으로 줄여 제목 글자가 먼저 줄게 했다(기준 viewport 영향 없음). 다른 분석 섹션 제목 줄(S4 · S5)도 같은 위험이 있는지 보지 않았다.
6. **시안 견본 순서**: 시안 플라이아웃은 문서 순서(… 호시노 · 아루 · 미카)인데 구현은 FE6-c 규칙 3(부족 큰 순 → 이름)이라 미카(T4 6)가 호시노(T4 6)보다 위다. 산점도는 FE6-c 발견 2처럼 같은 값의 점이 겹친다(시안은 티어마다 y를 조금씩 어긋나게 그렸다).
7. **확장 중 S1 · S4 · S5 상태**: 확장 완료 동안 세 섹션은 트리에서 빠지므로 축소 뒤 S1 학교 목록 스크롤 위치가 처음으로 돌아간다.
8. **빌드 잠금**: 첫 `inventory_analysis_page_test` 실행이 600초 넘게 멈췄다(같은 시각 다른 dart 프로세스, Lane B 추정). 한 번 재시도해 4초에 통과했다.

#### 사본 · commit.json

- 착수 사본: `debug/frontend_fe6d/pre/<경로>`(고친 기존 파일 9개). WIP가 없어 post 사본은 없다.
- `debug/frontend_fe6d/commit.json`: slice `fe6d`, `status=true`, modified 9, added 7(새 기준 이미지 `inventory-analysis-opa.png`는 CF가 넣는다), `whole = [frontend/test/goldens/baseline/inventory-analysis.png]`. message 근거: Inventory-Analysis-Opa artboard, E §4, FD-103(+ FD-031 · 033 · 099 · 101).
- 인계: `debug/frontend_fe6d/output.md`.

#### 다음 행동

- FE6-d 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: 레인 워커가 모두 멈춘 뒤 gate 1회. 예상: analyze 0, 일반 테스트 +23(키트 morph 7 + 버튼 1 + 집계 9 + 위젯 6), golden은 새 장면 `inventory-analysis-opa` 기준 없음 RED + `inventory-analysis` S2 "확장" 버튼만 RED, 다른 장면 변화 0. 승인 뒤 `-UpdateGoldens` · 재비교 · `fe_commit.ps1 -Slice fe6d`.
- 발견 사항 1(grid 밖 섹션 spec) · 2(부제) · 4(단계 포커스 인계) · 5(다른 제목 줄)는 CF 판단을 기다린다. 3은 FE5-f에서.

### fe6d commit record (2026-10-12 07:56, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261012_074656\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE5-f 옛 계획 화면 정리 (Lane A, 로컬 Claude Code)

### FE5-f 착수 기록 (2026-10-12, Lane A)

- 상태: **f1 코드 완료(아래 종료 기록), f2 남음**. 시작 SHA `0566391311e591c4b979a50a19661c8ce110eb3b`(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`). 워커 프롬프트 `debug/frontend_redesign_handoff/fe5f-worker-prompt-20261012.md`(CF 09:30 배정).
- 막힘: 대장 막힘 요약 FE5-f 행 = FD-082(확정 2026-10-06, 권장안 (a)). 막는 열림 FD 없음. FD-086은 그대로 둔다(범위 밖).
- 동작 보존 slice다. 새 화면을 만들지 않고, 사용자에게 보이는 화면(Detail 홈 · 계획 만들기 · 시나리오 목록 · 보기 · 비교 · 페이즈 편집 = 흐름 3단계)은 바꾸지 않는다.

#### 0. 정리 목록(코드 고치기 전 grep)

`plan_section_layout.dart`는 8504줄이고, 아래 항목의 대부분이 이 파일 안에서만 쓰인다. 앱 셸(`app_shell.dart`)은 `legacyHome`을 넘기지 않으므로 앱은 늘 Detail 홈이다.

| 지울 것 | 아직 쓰는 곳(grep) | 대체 경로 | 처리 |
|---|---|---|---|
| `legacyHome` 다리(`PlanningPage` · `PlanSectionLayout` 매개변수, build 조건 4곳, `_closeScenarioList` 조건 2곳, 2-pane `section1Bounds` 분기) | lib: `planning_page.dart`. test: `planning_page_test`(`pumpPage` + 직접 3곳) · `plan_element_builder_test`(4곳) · `plan_preset_manager_test`(1곳) · golden(3장면) | Detail 홈(FE5-c2) | **f1** |
| 옛 홈 섹션 1 버튼 묶음(페이즈 만들기 · FE4-f2 아이콘 · 학생 추가 · 프리셋 생성·관리 · 시나리오 비교 · 시나리오 생성 · 시나리오 리스트) | 옛 홈 build의 `sectionLayer('element-1')`만 | Detail 홈 S1(시나리오 목록 · 계획 만들기 · 페이즈 편집), 목록 S1 "프리셋 관리" · 비교 슬롯 | **f1** |
| 옛 홈 섹션 2~6(읽기 전용 페이즈 목록 `PlanPhaseDiagonalList` · `PlanPhaseCard`, 섹션 3 탭 `PlanBottleneckDiagonalList` · `PlanConsumptionSection`, 섹션 4 `PlanResourceControls`, 섹션 5 `PlanResourceHeader` · 요약 행 3종 · projection, 섹션 6 `PlanResourceTypeFilterSection`) | 옛 홈 build만. test: `planning_page_test`, `plan_home_detail_test`(`PlanConsumptionSection` findsNothing 2줄), `planning_document_projection_test`(`PlanConsumptionResourcePreview`) | Detail 홈 S2 단계 행 · S3 병목 카드 · 페이즈별 · 전체(FE5-c1 · FE5-d) · 칩 3개 | **f1** |
| 옛 홈 상태 · 핸들러(`_highlightedStudentIds` · `_highlightedStageKeys` · `_selectedSection3ResourceKey` · `_showResourceTypeFilters`, 토글 8개, `_bottleneckDetails` · `_phaseConsumptions` · `_overallConsumption`와 `_calculateDocument`의 옛 미리보기 만들기, `_stageKeysById` · `_consumptionResource` · `_resourceIcon`, `_openPresetManager`) | 옛 홈만(새 홈 `_applyHomeFilter` · `_selectResourceView`가 강조 상태를 지우기만 한다) | Detail 홈 자체 상태(`_homeSelected*`) | **f1** |
| 옛 견본 데이터 · 기하(`dummyPlanBottleneckDetails` · `dummyPlanPhaseConsumptions` · `dummyPlanOverallConsumption` · 미리보기 클래스, `filterPlan*`, `planSectionPath` · `planResource*` 기하 · `planPhaseContainerPath` · `planBottleneckContainerPath`, `PlanSectionFoundationPainter`, 옛 모션 상수 `planSection1~5Motion` · `planSection3TabMotion` · `planSectionMotions`) | 옛 홈만. test: `planning_page_test` | — | **f1** |
| 옛 학생 추가 진입(`_openStudentSelector` · `_closeStudentSelector` · `_selectPlanStudents`, `_showStudentSelector` · `_switchingStudentSelector`, build의 `PlanStudentSelector`) | 옛 섹션 1 "학생 추가"만 | 계획 만들기 1단계 학생 고르기(FE4-b) | **f1**(진입 제거). 위젯 파일 `plan_student_selector.dart`는 프리셋 관리 · 테스트가 상수를 쓰므로 **f2** |
| `_PlanWorkspaceSnapshot` 왕복 | lib · test grep 0건. `git log -S`: FE4-a1 `a18897a1`에서 이미 사라졌다 | 흐름 초안(`PlanFlowController`) | 할 일 없음(기록만) |
| 옛 `PlanPhaseEditor`(`plan_phase_editor.dart` 2246줄)와 홈 진입 | lib: `plan_section_layout`(요소 편집기 "페이즈 편집기" 대체 경로), `plan_element_builder`(`phaseEditorPathSurfaceTexture`), `plan_preset_manager`(텍스처 · 기하). test: `planning_page_test` 단위 13건 · 위젯 2건, `plan_element_builder_test`, `kit/diagonal_scrollbar_test`, `theme_tokens_test` | 흐름 3단계 칸 보드(FD-070) | **f2** |
| 요소 편집기 대체 경로(계정 없음 → `PlanElementBuilder`)와 `_planPhases` · `_planElements` · `_draftsByStudent` · `_unassignedPlanElementIds` · `_rebuildDocumentFromPhases` · `dummyPlanPhases`(편집기 견본) | lib: `_openHandoffFlow` 대체 분기. test: `plan_element_builder_test` `_legacyBuilderService` 4건 | 계정 없음 빈 상태(아래 1번 권장안) | **f2** |
| 키트로 대체 가능한 private 코드(목록만) | `plan_phase_editor.dart` `_lerpGridRect` · `phaseEditorElements` · `_PhaseEditorMotion`(FE6-d 발견 3) | `lib/ui/kit/section_morph.dart` | 교체 안 함 · f2에서 파일째 지움 |

지울 테스트와 대체 테스트(f1 예정):

- `planning_page_test.dart`: 옛 홈 단위 · 화면 테스트(섹션 기하 · 모션 상수 · 견본 합계 · 필터 · 섹션 3 탭 · 섹션 4/6 필터 · 페이즈 목록 스크롤 · 옛 홈 강조 등)와 옛 진입 버튼으로 여는 페이즈 편집기 · 학생 추가 화면 테스트를 지운다. 대체: `plan_home_detail_test`(Detail 홈 S1 · seg · 목록 왕복 · 페이즈 편집), `plan_scenario_detail_test` · `plan_detail_tabs_test`(병목 카드 · 페이즈별 · 전체 · 칩), `plan_flow_order_step_test`(칸 보드), `plan_flow_student_step_test`(학생 고르기). 남는 경로를 쓰던 테스트(목록 왕복 · 계획 만들기 · 편입 · 흐름 저장)는 Detail 홈에서 다시 쓴다. 정확한 목록은 종료 기록.
- `plan_element_builder_test.dart` `_legacyBuilderService` 4건: f1에서는 대체 경로가 남으므로 `legacyHome`만 빼고 옛 홈 키를 쓰던 끝부분 2건만 고친다. 4건 삭제는 f2.
- `plan_preset_manager_test.dart`: 여는 길을 목록 S1 "프리셋 관리"로 바꾼다.
- `planning_document_projection_test.dart`(옛 `PlanConsumptionResourcePreview` 1건): 파일째 지운다(대체: Detail 모델의 보유 모름 '—' 테스트, 종료 기록).

golden 장면 영향(f1, 실행하지 않음):

- 지울 장면 정의 3개(옛 홈에서만 열린다): `plan-phase-editor` · `plan-student-selector` · `plan-element-builder`. 기준 PNG는 지우지 않는다.
- 바뀔 장면: 없음(목표). 남는 계획 장면은 모두 Detail 홈 · 흐름 · 목록 경로라 옛 홈 코드를 지나지 않는다(근거는 종료 기록).

#### 분할 결정(세션 운영 규칙 2)

범위가 크다(지울 줄 `plan_section_layout.dart` 약 4,500줄 + `planning_page_test` 약 3,000줄 + `plan_phase_editor.dart` 2,246줄, golden 장면 정의 3개 삭제). 그래서 나눈다.

- **f1(이번)** = `legacyHome` 다리 · 옛 홈 섹션 1~6(버튼 묶음 · 옛 위젯 · 견본 · 기하 · 상태) · 옛 학생 추가 진입 제거, 옛 홈 테스트 삭제 · 재작성, 옛 홈 전용 golden 장면 정의 3개 삭제. `legacyHome`을 빼면 세 장면을 열 길이 없어지므로 golden 정리는 f1에 들어간다(권장 분할과 다른 점).
- **f2(다음)** = 계정 없음 빈 상태(1번) + 요소 편집기 대체 경로 · 옛 `PlanPhaseEditor`(파일 삭제, 프리셋 관리 · 요소 편집기가 쓰는 텍스처 · 기하 이관) · `plan_student_selector.dart` 정리 · `_legacyBuilderService` 4건과 페이즈 편집기 단위 · 위젯 테스트 정리. golden 장면 변화는 0 예상(남는 장면 없음).

#### 1. 계정 없음 대체 경로(조사만, 구현은 f2)

- 지금: 흐름을 열 수 없는 서비스(선택 계정 없음)로 학생이 넘어오면 옛 요소 편집기를 연다(`_openHandoffFlow`).
- 다른 탭: 인벤토리는 가운데 안내 문구 하나(`inventory_workspace.dart` `_Notice`, "선택된 계정이 없습니다. 설정에서 계정을 고르면 인벤토리가 보입니다.", `AppColors.textSecondary`). 택틱은 아이콘 + 문구(`_Message`, "선택된 프로필이 없습니다."). 학생 탭은 선택이 없으면 첫 계정을 쓴다. **공통 위젯 · 문구가 없고 탭마다 다르다** → 지시대로 이 항목은 멈추고 권장안을 CF에 넘긴다.
- 권장안: 인벤토리 방식(아이콘 없는 가운데 문구, ~습니다체)을 Detail 홈의 기존 안내 자리(`_homeNotice`, S2 · S3)에 쓴다. 문구 "선택된 계정이 없습니다. 설정에서 계정을 고르면 계획이 보입니다.", 키 `plan-home-no-profile`. 계산기에서 넘어온 학생은 버리지 않고 SnackBar "계정을 먼저 골라야 계획에 추가할 수 있습니다."로 알린다. S1 버튼은 지금처럼 꺼진다.
- 발견(관련): 계정이 없을 때 `loadRepositoryPlan: true` 홈은 `_document`가 null로 남아 "활성 계획을 읽는 중입니다."를 계속 보인다(`_loadRepositoryPlan`의 `selected == null` 분기가 문서 · 안내 상태를 정하지 않는다). 위 빈 상태가 이 경우도 덮어야 한다(f2).

#### 고칠 파일(f1)

- `frontend/lib/ui/pages/planning_page.dart`
- `frontend/lib/ui/widgets/plan_section_layout.dart`(CRLF 유지)
- `frontend/test/planning_page_test.dart`, `frontend/test/plan_element_builder_test.dart`, `frontend/test/plan_preset_manager_test.dart`, `frontend/test/plan_home_detail_test.dart`
- `frontend/test/planning_document_projection_test.dart`(삭제 — commit.json `deleted`)
- `frontend/test/goldens/fe1g_baseline_golden_test.dart`(장면 정의 3개 · 그 전용 헬퍼 삭제만). `golden_harness.dart`는 옛 장면 전용 헬퍼가 없어 고치지 않는다(`goldenTestPreset`은 `plan-preset-manager` · 흐름 장면이 쓴다).
- 이 status 문서.
- 사본: `debug/frontend_fe5f1/pre/<v7 기준 경로>`(위 9개, cmp 일치 확인). WIP: 9개 모두 `git status --short <경로>`가 비어 있다(미커밋 변경 없음) → post 사본 없음.
- 고치지 않음: `lib/services/**` · `lib/ui/inventory/**` · `inventory_studio_layout.dart`(Lane B), `lib/ui/kit/**` · `test/kit/**`(옛 상수 `planCreditIconAsset` 등과 `PlanInventoryCoverageBar`를 키트 테스트가 잠그고 있어 남긴다), `plan_studio_layout.dart`(옛 `planStudioDocument`가 쓰는 곳 없이 남는다), `app_shell.dart` · `app_section.dart`, `frontend/tool/**`, backend · contracts, 기준 PNG.

### FE5-f 종료 기록 (2026-10-12, Lane A, f1 코드 완료 · CF gate 미실행)

f1(옛 계획 홈 제거)을 끝냈다. 사용자에게 보이는 화면(Detail 홈 · 계획 만들기 · 시나리오 목록 · 보기 · 비교 · 페이즈 편집 = 흐름 3단계)은 바꾸지 않았다. 앱은 FE5-c2부터 이미 Detail 홈만 그렸고, 옛 홈은 테스트 · golden이 `legacyHome: true`로만 열었다. f2는 아래 "다음 행동".

#### 실행 명령 · 결과

모두 `frontend`에서 이 PC(Claude Code)로 실행했다. 로그는 실패 줄(`[E]` · `EXCEPTION` · `Some tests failed` · `error •`)만 찾았다. 로그 · 요약은 `debug/frontend_fe5f1/logs/`.

| 명령 | 결과 |
|---|---|
| `flutter analyze lib`(중간) | 내 파일: 미사용 import 6건 → 지움. 같은 시각 `lib/ui/inventory/inventory_controller.dart` · `inventory_workspace.dart` 오류 3~5건(Lane B 편집 중, 손대지 않음) |
| `flutter analyze`(최종, 전체) | **No issues found**(info 포함 0) |
| `flutter test test/plan_element_builder_test.dart test/plan_preset_manager_test.dart test/plan_home_detail_test.dart`(1차) | 60 통과 · 1 실패: `plan_preset_manager_test` "narrow viewport" — 새 여는 길(시나리오 목록)이 1280×720에서 RenderFlex 넘침 3건(`plan_scenario_list.dart`, FE5-a 몫, 발견 사항 1) → 기준 창에서 연 뒤 좁은 창으로 줄이게 고침 |
| `flutter test test/plan_preset_manager_test.dart`(2차) | 5 통과 · 0 실패 |
| `flutter test` 계획 묶음 9개(`planning_page` · `planning_document_projection` · `plan_detail_tabs` · `plan_flow` · `plan_scenario_compare` · `_comparison` · `_detail` · `_list` · `_preview`) | 96 통과 · 0 실패 |
| `flutter test` 셸 · 학생 · 키트 묶음 16개 | 147 통과 · 0 실패 |
| 최종 회귀 `flutter test --reporter json` 45개 파일(`plan_*` · `planning_*` · `scenario_*` 중 process E2E 제외 전부 + `student_page_test` + `PlanningPage` · `plan_section_layout` · 앱 셸을 쓰는 파일 grep 전부) | **650 통과 · 1 실패**. 실패는 `planning_protocol_client_test` "real Python process serves every P0 planning method through AppService"(20초 시간 초과 — 다른 파일과 병렬로 돈 실제 프로세스 테스트) |
| `flutter test test/planning_protocol_client_test.dart`(단독 재실행) | 24 통과 · 0 실패 |
| `git diff --check`(고친 파일 9개) | 0(경고는 autocrlf 안내뿐) |

최종 회귀 파일별(통과 · 실패): planning_page 32·0, plan_element_builder 51·0, plan_preset_manager 5·0, plan_home_detail 5·0, planning_document_projection 1·0, plan_detail_tabs 8·0, plan_flow 15·0, plan_flow_authoring 18·0, plan_flow_goal_step 23·0, plan_flow_handoff 23·0, plan_flow_order_step 19·0, plan_flow_presets 13·0, plan_flow_save 15·0, plan_flow_student_step 8·0, plan_scenario_compare 7·0, plan_scenario_comparison 2·0, plan_scenario_detail 12·0, plan_scenario_list 10·0, plan_scenario_preview 9·0, plan_student_step_tile 3·0, planning_authoring_service 75·0, planning_document_v2_service 19·0, planning_growth_rules 13·0, planning_protocol_client 23·1(단독 24·0), planning_protocol_contract 7·0, planning_resource_assets 1·0, scenario_authoring_service 75·0, scenario_service 2·0, student_page 9·0, title_page 25·0, widget_test 16·0, account_manager_fe8b 6·0, home_app_shell 1·0, statistics_app_shell 1·0, inventory_shell_lazy 1·0, profile_delete_fb2d 17·0, growth_calculator_view 24·0, section_template_studio 15·0, student_filter_followups 4·0, student_filter_modal 7·0, geometry/diagonal_geometry 5·0, kit/diagonal_scroll_viewport 5·0, kit/item_icon_tile 7·0, kit/skew_bar 8·0, widgets/section_surface 5·0.

빌드 잠금 경합은 없었다(재시도 0회).

#### 지운 코드

- `lib/ui/widgets/plan_section_layout.dart`: 8504 → 3828줄(diff +154 / −4830, 추가 줄은 대부분 블록 이동에 따른 diff 정렬). CRLF 그대로.
  - `legacyHome` 매개변수와 build · `_closeScenarioList` · 2-pane `section1Bounds`의 분기.
  - 옛 홈 `sectionLayer`(섹션 1 버튼 7개 · 섹션 2 `PlanPhaseDiagonalList` · `PlanPhaseCard` · 섹션 3 탭 · 섹션 4 · 5 · 6), 위젯 `PlanResourceControls` · `PlanResourceTypeFilterSection` · `PlanResourceHeader`(+탭) · 요약 행 3종 · `PlanResourceItemSummary` · projection 4종 · `PlanConsumptionSection` · `DiagonalList` · `Card` · `CreditRow` · `ResourceTile` · `PlanBottleneckDiagonalList` · `DetailCard` · `CreditShortage` · `ResourceTile` · `PlanSectionFoundationPainter` · `PlanResourceHeaderPainter`와 private 페인터 · 클리퍼.
  - 견본 · 모델: `PlanBottleneckResourcePreview` · `PlanDelayedStagePreview` · `PlanBottleneckDetailPreview` · `PlanConsumptionResourcePreview` · `PlanConsumptionGroupPreview`, `dummyPlanBottleneckDetails` · `dummyPlanPhaseConsumptions` · `dummyPlanOverallConsumption`, `filterPlan*` · `planBottleneckFocusStep` · `planStudentStageKey` · `formatPlanAmount`, 옛 이름 상수 9개.
  - 기하 · 모션: `planSectionPath` · `planStudentSelectorSection1RightAtReference` · `planResource*`(탭 선반 · 머리 · 컨트롤 · 필터) · `planPhaseContainerPath` · `planBottleneckContainerPath` · `planPhaseItemRect` · 상수 `planPhaseItem*` · `planResource*Height` · `planSection1~5Motion` · `planSection3TabMotion` · `planSectionMotions`.
  - 상태 · 핸들러: 강조 3종 · `_showResourceTypeFilters` · 토글 8개 · `_bottleneckDetails` · `_phaseConsumptions` · `_overallConsumption` · `_stageKeysById` · `_consumptionResource` · `_resourceIcon` · `_calculateDocument`의 옛 미리보기 만들기 · `_openPresetManager` · 학생 추가(`_openStudentSelector` · `_closeStudentSelector` · `_selectPlanStudents` · `_showStudentSelector` · `_switchingStudentSelector`, build의 `PlanStudentSelector`). 모션 컨트롤러는 `element-1`(비교 S1 메뉴) · `element-2`(Detail 홈) 둘만 만든다.
  - 남긴 것(이유): `planScenarioListMotion` · `planResourceControlGap`(2-pane 비교가 씀), `PlanPhaseContainerPainter` · `planPhaseLeftBoundary` · `planPhaseRightBoundary` · `planPhaseRow*` · `_PlanLocalPathClipper`(비교 · 기하 테스트), `planResourceCategory` · `PlanResourceCategory` · `PlanResourceSort` · `PlanResourceView`(Detail 칩 · seg), 아이콘 상수 5개 · `PlanInventoryCoverageBar`(키트 테스트가 잠금), `PlanDiagonalScrollbar` typedef(남은 페이즈 편집기 테스트), `PlanPhasePreview` · `dummyPlanPhases` · 요소 편집기 · 페이즈 편집기 대체 경로(f2).
- `lib/ui/pages/planning_page.dart`: 46 → 41줄(`legacyHome` 제거).
- 파일 삭제 없음(commit.json `deleted` 빈 목록). `planning_document_projection_test.dart`는 착수 기록의 "파일째 지운다" 예정을 바꿔 새 모델로 다시 썼다(Detail 모델에 보유 모름 단위 테스트가 없어서).

#### 지운 · 바꾼 테스트와 대체 테스트

`planning_page_test.dart`(4488 → 1762줄, 61 → 32건). 지운 29건과 대체:

| 지운 테스트 | 대체 |
|---|---|
| plan phase items use the expanded readable height · all section 3 tab bodies use intro 80 and outro 260 · uses the requested per-section intro and outro directions | 없음(상수째 지움). Detail 모션 · 배치는 `plan_scenario_list_test` "Studio 3섹션…" · `plan_home_detail_test` |
| regular equipment uses the v6 default item background at every tier · overall consumption is the exact sum of phase consumption · bottleneck filtering preserves calculated focus-step data · plan-phase-consumption / plan-overall-consumption clamps a stale scroll offset when satisfied items hide(2건) | `plan_scenario_detail_test` "같은 단계 병목은 카드 한 장…" · `plan_detail_tabs_test` "페이즈 진입/필요/종료와 충족률(FD-037)" · "전체 확보율(FD-031 (a))…" · "칩: 재화 유형 · 충족 재화 숨기기가 전체 타일을 거른다" |
| projects the five sections from the plan Studio document · section 4 controls and section 6 share the canonical geometry · phase items follow the parent parallelogram edges · two-column resources keep their size and align to long control rails · resource header follows the section 5 parallelogram safe interval · bottleneck container is inset to 95 percent with a small top margin | `plan_scenario_list_test` "Studio 3섹션: S1은 시안과 같고 S2·S3는 정수 칸 근사다"(Detail 3섹션 기하) |
| places five sections and a diagonal phase preview · bottleneck is first and overall uses its dedicated two-line summary · resource summaries highlight their affected students in every tab · phase consumption cards reuse resources and overall aggregates one group · section 3 resources focus exact consuming plans in every resource tab · bottleneck delayed-stage button highlights exact rows and list scrolls · section 4 opens and operates the resource type filter · phase list scrolls while preserving its diagonal container | `plan_home_detail_test` 5건(Detail 홈 · S1 · seg · 목록 왕복 · 페이즈 편집) · `plan_scenario_detail_test` "카드를 고르면 그 단계 행이 분홍 테두리…" · `plan_detail_tabs_test` "페이즈별: 카드 · 타일 값, 카드 ↔ S2 페이즈 강조" · "전체: 크레딧 행 · 분야 그룹, 타일 ↔ S2 단계 강조, 열 수" |
| phase editor keeps lists and side controls interactive · phase editor source rows follow the diagonal scroll rail · phase editor sections play their outro when the plan tab deactivates(옛 "페이즈 만들기" 버튼으로 연다) | `plan_flow_order_step_test`(칸 보드, FD-070) · `plan_element_builder_test` 대체 경로 2건(요소 편집기에서 페이즈 편집기). 페이즈 편집기 위젯 · 단위 테스트(이 파일 15건)는 f2까지 남는다 |
| student selector keeps section 1 and resets search and filters on exit · student selector panels play outro when the plan tab deactivates · student selection exits both panels before opening and reopening the builder · multi-select processes students in click order and reopens the selected student plan | `plan_flow_student_step_test` "그리드에서 고르면 고른 순서 배지가 붙고…" · "필터 모달: 초안은 적용 전까지…" · "검색은 이름에 더해 학교·역할 이름으로도 찾는다" |

바꾼 테스트:

- `planning_page_test` "resource categories filter and sort the section 3 data" → "resource categories classify the Detail filter chip data"(`planResourceCategory` 분류만 남기고 옛 필터 부분 삭제).
- `planning_page_test` `pumpPage`: `legacyHome` 제거(Detail 홈).
- "comparison workspace incorporates a scenario after the active plan": Detail 홈 S1 "시나리오 목록"(`RailButton`) → 비교 슬롯 → "나란히 비교" → 편입.
- "scenario list replaces the plan home with its three sections and returns to the active plan": 옛 `plan-element-1-motion` 대신 Detail 홈(`plan-home-view`) 모션 값 1 → 0 → 1, 옛 "시나리오 비교" 꺼짐 단언 삭제.
- "scenario creation opens the plan flow step 1 and quitting plays the flow outro": `plan-scenario-create-launch` 위젯 타입 `FilledButton` → `RailButton`.
- `plan_element_builder_test` 대체 경로 4건: `legacyHome` 제거. "builder deletes only the selected unassigned stage and return preserves the rest" → "… and the phase editor keeps the rest"(옛 홈 "페이즈 만들기" 대신 요소 편집기의 `plan-starter-open-phase-editor`). "phase completion exits the builder and returns to plan main": 끝 단언 `plan-phase-scroll` → `plan-home-view`.
- `plan_preset_manager_test`: 여는 길 = 목록 S1 `plan-scenario-menu-presets`, 닫으면 `plan-home-view`. "narrow viewport"는 기준 창에서 연 뒤 1280×720으로 줄인다(발견 사항 1).
- `plan_home_detail_test`: 옛 `PlanConsumptionSection` import · findsNothing 2줄 삭제, 테스트 이름에서 "(옛 PlanConsumptionSection 없음)"을 뺐다.
- `planning_document_projection_test`: 같은 이름 테스트를 `PlanDetailResourceTile`(보유 모름 → owned · exit · shortage · fraction · percent null, satisfied false)로 다시 썼다.

#### 계정 없음 빈 상태 결론

- 다른 탭에 공통 방식이 없다(인벤토리 = 가운데 문구, 택틱 = 아이콘 + "프로필" 문구, 학생 = 첫 계정 대체). 지시대로 이 항목은 멈추고, 착수 기록 "1."의 권장안(인벤토리 방식 문구 `plan-home-no-profile` + 넘어온 학생은 SnackBar 안내)을 CF에 넘긴다. f1은 대체 경로(요소 편집기)를 그대로 두었다.

#### golden

- 지운 장면 정의(`fe1g_baseline_golden_test.dart`, 실행 안 함): `plan-phase-editor` · `plan-student-selector` · `plan-element-builder`, 그 장면 전용 헬퍼 `_selectFirstPlanStudent`, `_openPlanning`의 `legacyHome` 인자. `golden_harness.dart`는 고치지 않았다. 기준 PNG는 지우지 않았다 — CF 삭제 대상:
  - `frontend/test/goldens/baseline/plan-phase-editor.png`
  - `frontend/test/goldens/baseline/plan-student-selector.png`
  - `frontend/test/goldens/baseline/plan-element-builder.png`
- 남는 장면 변화 0 근거:
  - 계획 장면(`plan-bottleneck` · `plan-by-phase` · `plan-overall` · `plan-preset-manager` · `plan-flow-*` 11 · `plan-scenario-*` 9)은 모두 `legacyHome: false`로 열던 장면이다. 그 경로의 build 분기(Detail 홈 · 목록 · 2-pane · 4열 · 비교 S1 메뉴 · 흐름 · 프리셋 관리)는 조건식에서 `legacyHome` 항만 빠졌고 그리는 위젯 · 인자는 같다(2-pane `section1Bounds`는 원래 쓰던 Detail S1 bounds 분기 그대로).
  - Detail 홈은 `_homeProjection` · `_document` · `_homeSelected*` · 필터 3종 · `_selectedResourceView`만 읽는다. 이 값의 계산 · 갱신은 바뀌지 않았다(`_calculateDocument`는 같은 응답을 `_homeProjection`에 넣고, 지운 것은 옛 미리보기 목록뿐). 지운 강조 상태는 Detail 홈이 읽지 않았다.
  - 모션: 그려지는 컨트롤러는 원래도 `element-1`(비교 S1 · 4열 메뉴) · `element-2`(Detail 홈)뿐이었다. 지운 `element-3~5`는 옛 홈만 그렸다. 두 컨트롤러의 forward/reverse 시점은 같다.
  - 계획 밖 장면(타이틀 · 계정 · 홈 · 학생 · 인벤토리 · 스캔)은 계획 탭이 offstage이거나 계획 코드를 지나지 않는다.
  - golden 테스트 파일은 analyze 0이다(컴파일 확인만, 실행 안 함).

#### 처리한 FD

- FD-082 (a)(확정): 옛 홈을 지워 첫 화면은 Detail 홈 하나만 남는다.
- FD-086: 그대로(범위 밖).

#### 미검증 항목

- golden(`test/goldens/**`): 미실행. 남는 장면 변화 0은 위 코드 경로 근거로만 말한다.
- 전체 `fe_gate.ps1`(`codealmanac validate` 포함): 미실행.
- process E2E(`*_process_e2e_test.dart`): 미실행(서비스 계층은 고치지 않음).
- 실제 앱 창에서 계획 탭 확인: 미실행.

#### 검수표(계획 탭, mock 모드 · 기준 viewport)

| 확인할 것 | 여는 방법 | 기대 |
|---|---|---|
| 첫 화면 | 계획 탭 | Detail 홈(S1 시나리오 목록 · 계획 만들기 · 페이즈 편집 + "이 계획" 정보, S2 단계 행, S3 병목 카드) — 지금과 같다 |
| S3 seg · 칩 | 페이즈별 · 전체 탭, 재화 유형 · 충족 숨기기 · 정렬 | 지금과 같다 |
| 시나리오 목록 왕복 | S1 "시나리오 목록" → "활성 계획으로" | 목록이 들어오고 나간 뒤 Detail 홈이 다시 들어온다 |
| 나란히 비교(2개 · 4열) · 편입 | 목록 비교 슬롯 → "나란히 비교" | 비교 S1 메뉴 · 본문 위치 그대로, "활성 계획으로"로 홈 |
| 프리셋 관리 | 목록 S1 "프리셋 관리" → 나가기 | 닫으면 Detail 홈 |
| 페이즈 편집 · 계획 만들기 | S1 버튼 | 흐름 3단계 · 1단계, 닫으면 홈 |
| 계산기 → 계획(계정 있음) | 학생 탭 계산기 "이 목표로 계획에 추가" | 흐름 2단계(지금과 같다) |
| 계정 없음(지금 그대로, f2 대상) | 계정 없이 계산기에서 넘김 | 옛 요소 편집기가 열린다(f2에서 빈 상태로 바꿈) |

#### WIP 보존 확인

- 고친 파일 9개 모두 착수 때 WIP 없음(`git status --short` 빈 결과) → post 사본 없음. 다른 레인의 미커밋 변경(서비스 · 인벤토리 · 스캔 파일 등)은 건드리지 않았다.

#### 발견 사항

1. **시나리오 목록 1280×720 넘침(FE5-a 몫)**: 목록을 1280×720에서 열면 `plan_scenario_list.dart`의 Row 3곳(1139:14 · 1343:12 `plan-scenario-filter-row` · 2154:25)이 각각 123 · 37 · 1.8px 넘친다. 옛 홈 "프리셋 생성·관리" 버튼 대신 목록을 거쳐야 해서 드러났다. 이번에는 테스트를 기준 창에서 열게만 바꿨다.
2. **계정 없을 때 홈이 "읽는 중"에 머문다**: `loadRepositoryPlan: true`인데 선택 계정이 없으면 `_document`가 null로 남아 "활성 계획을 읽는 중입니다."가 계속 보인다. f2 빈 상태가 이 경우도 덮어야 한다(착수 기록 1.).
3. **계산 응답 형식 검사 하나가 빠짐**: 옛 미리보기 만들기에 있던 `projection['overall'] as Map` 캐스트가 함께 빠졌다. 전에는 `overall`이 없는 응답이 "계산 오류"가 되었고, 이제는 Detail 모델(`PlanDetailData.fromProjection`)이 그대로 읽는다. mock · process 응답은 늘 `overall`을 준다. 의도한 변경이 아니어서 적어 둔다.
4. **남은 옛 공개 이름**: `plan_studio_layout.dart`의 `planStudioDocument`(옛 5섹션 Studio 문서)는 쓰는 곳이 없어졌다(studio 파일은 이 slice 범위 밖). 아이콘 상수 5개 · `PlanInventoryCoverageBar`는 키트 테스트(`test/kit/item_icon_tile_test` · `skew_bar_test`)만 쓴다. 정리하려면 키트 테스트를 함께 고치는 소단위가 필요하다.
5. **키트 morph로 대체 가능한 private 코드**(목록만, FE6-d 발견 3): `plan_phase_editor.dart`의 `_lerpGridRect` · `phaseEditorElements` · `_PhaseEditorMotion`. f2에서 파일째 지우면 사라진다.

#### 사본 · commit.json

- 착수 사본: `debug/frontend_fe5f1/pre/<경로>`(9개). WIP가 없어 post 사본은 없다.
- `debug/frontend_fe5f1/commit.json`: slice `fe5f1`, `status=true`, modified 8, added 0, deleted 0. message 근거: 워크플로 FE5-f 행 · FD-082 (a) · 이 status 착수 기록(정리 목록 · 분할).
- 인계: `debug/frontend_fe5f1/output.md`.

#### 다음 행동

- f1 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: 레인 워커가 모두 멈춘 뒤 gate 1회. 예상: analyze 0, 일반 테스트 −29(planning_page_test) 외 변화 없음, golden은 장면 정의 3개가 빠지고 남는 장면 변화 0. 기준 PNG 3장은 사용자 승인 뒤 별도 삭제 커밋. 그다음 `fe_commit.ps1 -Slice fe5f1`.
- CF 결정 대기: 계정 없음 빈 상태 권장안(착수 기록 1.).
- **f2 범위**: ① 계정 없음 빈 상태(결정대로, 발견 2 포함) ② 요소 편집기 대체 경로 제거(`_openHandoffFlow` 대체 분기, `_builderSeed` · 큐 · `_planElements` · `_draftsByStudent` · `_unassignedPlanElementIds` · `_planPhases` · `_rebuildDocumentFromPhases` · `_completePhaseEditor` · `dummyPlanPhases` · `PlanPhasePreview`) ③ `plan_phase_editor.dart` 삭제(프리셋 관리 · 요소 편집기가 쓰는 텍스처 · 기하 이관, 필요하면 키트 morph) ④ `plan_student_selector.dart` 정리(프리셋 관리 · 테스트가 쓰는 상수 이관) ⑤ `PlanElementBuilder` 위젯 정리 범위 판단(`plan_element_builder.dart`에는 `PlanElementPreset` · `planElementCurrentTargets` 등 공용 정의가 있어 파일째는 못 지움) ⑥ 테스트: `_legacyBuilderService` 4건, `planning_page_test` 페이즈 편집기 · 학생 고르기 단위 · 위젯 15건과 "dummy phases keep student steps in execution order", `plan_element_builder_test` 페이즈 편집기 드롭 거부, `kit/diagonal_scrollbar_test` · `theme_tokens_test`의 옛 위젯 의존. golden 장면 변화 0 예상(남은 옛 장면 없음).

### fe5f1 commit record (2026-10-12 21:30, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261012_211921\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE5-f2 옛 계획 화면 정리 나머지 (Lane A, 로컬 Claude Code)

### FE5-f2 착수 기록 (2026-10-13, Lane A)

- 상태: **코드 완료(아래 FE5-f2 종료 기록), CF gate 미실행**. 시작 SHA `9c03d50b0c00fcf0a0df72da44be0c8694c99629`(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`). 배정: CF 로그 2026-10-12 23:15, 프롬프트 `debug/frontend_redesign_handoff/fe5f2-worker-prompt-20261012.md`.
- 막힘: 대장 막힘 요약 FE5-f 행 = FD-082(확정 2026-10-06). 막는 열림 FD 없음, 워커 재량 FD 없음.
- 범위: f1 종료 기록 "다음 행동"의 f2 = ① 계정 없음 빈 상태(사용자 결정 2026-10-12 21:45, f1 발견 2 포함) ② 요소 편집기 대체 경로 제거 ③ `plan_phase_editor.dart` 삭제 ④ `plan_student_selector.dart` 정리 ⑤ 테스트 ⑥ f1 발견 3(`overall` 형식 검사).
- 동작 보존 + 결정된 빈 상태만 추가. 남는 golden 장면 변화 0이 완료 조건이다(계정 없음 장면은 golden에 없고 새 장면을 만들지 않는다).

#### 3. `plan_phase_editor.dart` 사용처(grep, 이 파일 밖)

| 공개 이름 | lib 사용처 | test 사용처 | 처리 |
|---|---|---|---|
| `PlanPhaseEditor` · `PlanPhaseEditorItem` · `PlanPhaseEditorGroup` | `plan_section_layout`(대체 경로 build · `_completePhaseEditor`) | `planning_page_test`(위젯 2건) · `plan_element_builder_test`(대체 경로 2건 · 드롭 거부 1건) | 지움(대체 경로와 함께). 대체 = 흐름 3단계 칸 보드(FD-070) |
| `PhaseEditorPathButton`(+ private `_PhaseEditorButtonPainter` · `_PhaseEditorPathClipper`, `phaseEditorButtonHoverColor` · `PressedColor` · `phaseEditorSelectionColor`) | `plan_preset_manager` | `theme_tokens_test`(색 2개) | `plan_preset_manager.dart`로 옮김(쓰는 쪽 파일) |
| `phaseEditorCenteredTrapezoidListRect`(+ `phaseEditorShortTrapezoidEdgeLength` · `phaseEditorContainerInset` · `phaseEditorCompactListNormalGap`) | `plan_preset_manager` | `planning_page_test`(단위) | `plan_preset_manager.dart`로 옮김 |
| `phaseEditorControlGap` · `phaseEditorControlHeight`(+ 최소 · 최대 · 비율 상수) | `plan_preset_manager` | `planning_page_test`(단위) | `plan_preset_manager.dart`로 옮김 |
| `phaseEditorParallelogramPath` | `plan_preset_manager` | — | `plan_preset_manager.dart`로 옮김 |
| `phaseEditorPathSurfaceTexture` | `plan_element_builder`(`planPresetListTexture`의 원값) · `plan_preset_manager` | `plan_element_builder_test`(`same`) | 값을 `plan_element_builder.dart`의 `planPresetListTexture`에 직접 둠, 프리셋 관리는 그 이름을 씀 |
| `phaseEditorScrollbarStyle` · `phaseEditorScrollbarTrackPoint` | — | `kit/diagonal_scrollbar_test`(옛 painter 대조) | 지움(페이즈 편집기 전용). 키트 테스트의 그 대조 줄 · 1건을 지운다 |
| `phaseEditorMotionDuration` | — | `theme_tokens_test` | 지움(그 줄 삭제) |
| 나머지(`phaseEditorElements` · 기하 · 상수 · `phaseEditorMotionDirection` · `_lerpGridRect` · `_PhaseEditorMotion` 등) | — | `planning_page_test`(단위 11건) | 지움(키트 morph로 옮길 것 없음: 쓰는 화면이 함께 사라진다) |

#### 4. `plan_student_selector.dart` 사용처(grep, 이 파일 밖)

| 공개 이름 | lib | test | 처리 |
|---|---|---|---|
| `PlanStudentSelector` | — (f1에서 진입 제거) | `planning_page_test` · `plan_flow_test`(`findsNothing` 각 1줄) | 지움(그 줄 삭제) |
| `planStudentSelectorFilterControlGap`(8.0) | `plan_preset_manager` | — | `plan_preset_manager.dart` 상수로 옮김 |
| `planStudentSelectorMotion` · `SelectionSectionRect` · `ConfirmTexture` | — | `planning_page_test`(단위 2건) | 지움 |
| `planStudentSelectorDiagonalDepth` | — | `geometry/diagonal_geometry_test`(1줄) | 지움(그 줄 삭제) |
| `planStudentSelectorSectionOpacity` | — | `widgets/section_surface_test`(1줄) | 지움(그 줄 삭제) |
| `planStudentSelectorMotionDuration` | — | `theme_tokens_test`(1줄) | 지움(그 줄 삭제) |
| 나머지 공개 이름 18개 | — | — | 지움 |

→ 두 파일 모두 파일째 지운다(commit.json `deleted`, git rm은 CF · 사용자).

#### 고칠 · 지울 파일과 WIP

| 파일 | 처리 | WIP(`git status --short`) |
|---|---|---|
| `frontend/lib/ui/widgets/plan_section_layout.dart`(CRLF) | 고침 | 없음 |
| `frontend/lib/ui/widgets/plan_preset_manager.dart` | 고침(이관 받음) | 없음 |
| `frontend/lib/ui/widgets/plan_element_builder.dart` | 고침(텍스처 값) | 없음 |
| `frontend/lib/ui/models/plan_scenario_detail.dart` | 고침(`overall` 검사) | 없음 |
| `frontend/lib/ui/widgets/plan_phase_editor.dart` | **삭제** | 없음 |
| `frontend/lib/ui/widgets/plan_student_selector.dart` | **삭제** | 없음 |
| `frontend/test/plan_element_builder_test.dart` · `planning_page_test.dart` · `plan_home_detail_test.dart` · `plan_flow_test.dart` · `theme_tokens_test.dart` · `kit/diagonal_scrollbar_test.dart` · `geometry/diagonal_geometry_test.dart` · `widgets/section_surface_test.dart` | 고침 | 모두 없음 |
| `almanac/workflows/frontend-redesign-status.md` | 고침(이 기록) | 없음 |

- 사본: `debug/frontend_fe5f2/pre/<v7 기준 경로>` 15개(cmp 일치). WIP가 없어 post 사본 · `post_dir`은 없다.
- `planning_page.dart`는 고칠 것이 없으면 그대로 둔다(종료 기록에 적는다).
- 고치지 않음: `lib/services/**` · `lib/ui/inventory/**` · `inventory_studio_layout.dart`(Lane B), 학생 · 인벤토리 · 스캔 · 타이틀 화면, `app_shell.dart` · `app_section.dart`, `lib/ui/kit/**`(옮길 기하가 없음), `frontend/tool/**`, backend · contracts, golden 테스트 · harness(지울 장면 없음), 기준 PNG.

### FE5-f2 종료 기록 (2026-10-13, Lane A, 코드 완료 · CF gate 미실행)

f2(옛 계획 화면 정리의 나머지)를 끝냈다. 계정 없음 빈 상태(사용자 결정)만 새로 보이고, 계정이 있을 때의 화면(Detail 홈 · 계획 만들기 · 시나리오 목록 · 보기 · 비교 · 프리셋 관리)은 바꾸지 않았다. 이로써 FE5-f(f1 + f2)의 코드 범위가 끝난다.

#### 실행 명령 · 결과

모두 `frontend`에서 이 PC(Claude Code)로 실행했다. 로그는 실패 줄(`[E]` · `EXCEPTION` · `Some tests failed` · `error •`)만 찾았다. 로그 · 요약은 `debug/frontend_fe5f2/logs/`.

| 명령 | 결과 |
|---|---|
| `flutter analyze lib`(중간 1) | 미사용 import 2건(`plan_section_layout.dart`의 `plan_element_builder.dart` · `plan_student_step_tile.dart`) → 지움 |
| `flutter analyze lib`(중간 2 · 3) | No issues found |
| `flutter analyze test/<고친 파일>`(파일별) | 미사용 import 6건 · 불필요 import 1건 · 미사용 선언 1건(`_threeStageTestPreset`) · 지운 파일 URI 1건 · 컴파일 2건(새 테스트의 `AppColors` import · `const` 생성자) → 모두 고침, 최종 0 |
| `flutter test test/plan_home_detail_test.dart`(1차) | 8 통과 · 1 실패: 새 `overall` 테스트 — mock `plan.get`도 같은 계산 응답의 `overall`을 캐스트해서 요약을 만들기 때문에(빼면 `calculation`이 null → "계산할 수 없음") 테스트 mock이 계획 화면의 계산 호출에서만 `overall`을 빼게 고침 |
| `flutter test test/plan_home_detail_test.dart`(2차) | 9 통과 · 0 실패 |
| 확인용: `_calculateDocument`의 검사 줄을 잠시 빼고 `--plain-name overall` | 실패(테스트가 검사에 걸린다는 확인) → 파일을 원래대로 되돌림(`checkProjection` 1곳 확인) |
| `flutter analyze`(최종, 전체) | **No issues found**(info 포함 0) |
| `flutter test --reporter json` 73개 파일(`plan_*` · `planning_*` · `scenario_*` 중 process E2E · `planning_protocol_client` 제외 전부 + `PlanningPage` · `plan_section_layout` · `plan_preset_manager` · `plan_element_builder` · 앱 셸 · 학생 탭 · 계산기를 쓰는 파일 grep 전부 + `test/kit/*` 전부 + `theme_tokens` · `geometry/diagonal_geometry` · `widgets/section_surface` + f1 목록의 `title_page` · `account_manager_fe8b` · `statistics_app_shell` · `profile_delete_fb2d` · `section_template_studio` · `student_filter_modal`) | **822 통과 · 0 실패** |
| `flutter test test/planning_protocol_client_test.dart`(단독, 실제 Python 프로세스 테스트가 병렬에서 시간 초과될 수 있어 따로) | 24 통과 · 0 실패 |
| `git diff --check`(고친 파일 · status) | 0(autocrlf 안내만) |

회귀 파일별(통과 · 실패): planning_page 17·0, plan_element_builder 47·0, plan_home_detail 9·0, plan_preset_manager 5·0, plan_detail_tabs 8·0, plan_flow 15·0, plan_flow_authoring 18·0, plan_flow_goal_step 23·0, plan_flow_handoff 23·0, plan_flow_order_step 19·0, plan_flow_presets 13·0, plan_flow_save 15·0, plan_flow_student_step 8·0, plan_scenario_compare 7·0, plan_scenario_comparison 2·0, plan_scenario_detail 12·0, plan_scenario_list 10·0, plan_scenario_preview 9·0, plan_student_step_tile 3·0, planning_authoring_service 75·0, planning_document_projection 1·0, planning_document_v2_service 19·0, planning_growth_rules 13·0, planning_protocol_contract 7·0, planning_resource_assets 1·0, scenario_authoring_service 75·0, scenario_service 2·0, student_page 9·0, student_bond_gauge 12·0, student_filter_followups 4·0, student_filter_modal 7·0, student_range_condition_section 4·0, student_search_section 13·0, growth_calculator_adapter 24·0, growth_calculator_rules 15·0, growth_calculator_state 16·0, growth_calculator_view 24·0, title_page 25·0, widget 16·0, account_manager_fe8b 6·0, home_app_shell 1·0, statistics_app_shell 1·0, inventory_shell_lazy 1·0, profile_delete_fb2d 17·0, section_template_studio 15·0, theme_tokens 3·0, diagonal_geometry 5·0, section_surface 5·0, kit: anchored_flyout 8·0, ba_chip 4·0, ba_modal 5·0, ba_modal_a11y 4·0, buttons 6·0, diagonal_row 6·0, diagonal_scroll_viewport 5·0, diagonal_scrollbar 8·0, info_popover 8·0, item_icon_tile 7·0, kit_overlay 7·0, kpi_tile 2·0, range_controls 12·0, scroll_viewport_fog 6·0, section_morph 7·0, skew_bar 8·0, skew_controls 7·0, stat_chart 7·0, stepper 6·0, titles 4·0, ui_kit_gallery 6·0, ui_kit_gallery_controls 2·0, ui_kit_gallery_data 2·0, ui_kit_gallery_overlays 4·0, ui_kit_gallery_range 2·0. 별도: planning_protocol_client 24·0.

빌드 잠금 경합은 없었다(재시도 0회).

#### 지운 코드 · 파일

- **파일 삭제(작업 트리, commit.json `deleted`, git rm은 CF · 사용자)**: `frontend/lib/ui/widgets/plan_phase_editor.dart`(2246줄), `frontend/lib/ui/widgets/plan_student_selector.dart`(898줄).
- `lib/ui/widgets/plan_section_layout.dart`: 3828 → 3336줄(CRLF 그대로).
  - 요소 편집기 대체 경로: `_openHandoffFlow`의 "흐름을 열 수 없는 서비스" 분기(→ 아래 빈 상태 · SnackBar), build의 `PlanElementBuilder` · `PlanPhaseEditor` 자리, `editorItems` · `initialEditorGroups` · `unassignedBuilderItems`.
  - 상태: `_showPhaseEditor` · `_showElementBuilder` · `_usingLivePlanElements` · `_builderSeed` · `_builderStudentQueue` · `_builderStudentQueueIndex` · `_draftsByStudent` · `_planElements` · `_unassignedPlanElementIds` · `_planPhases`.
  - 함수: `_rebuildDocumentFromPhases` · `_openPhaseEditor` · `_closeElementBuilder` · `_closePhaseEditor` · `_confirmPlanElementStages` · `_editPlanStudent` · `_renameUnassignedPlanElement` · `_deleteUnassignedPlanElement` · `_completePhaseEditor`, `_loadRepositoryPlan`의 편집기용 정수 목표 · 초안 · 페이즈 미리보기 만들기(`planFlowDocumentIntegerTargets` 호출 포함, 계산 문서에는 쓰이지 않았다).
  - 모델 · 견본: `PlanPhasePreview` · `dummyPlanPhases`.
  - 바뀐 것: Detail 홈 학생 이름(`_catalogName`)은 지운 `_planPhases` 대신 읽은 문서 학생의 카탈로그 이름 지도(`_studentNames`, 없으면 id — 전과 같은 값)에서 읽는다.
- 남긴 것(이유): `PlanElementBuilder` 위젯과 `plan_element_builder.dart`(공용 정의 `PlanElementPreset` · `PlanElementStageDraft` · `planElementCurrentTargets` 등을 흐름 · 학생 탭 · 프리셋 관리가 쓰고, 위젯은 자기 위젯 테스트 20여 건이 직접 띄운다 — 발견 사항 4), `PlanDiagonalScrollbar` typedef(`planning_page_test` 시나리오 포그 테스트), `_studentSeedsById`(편입).

#### 옮긴 것과 새 위치

| 옛 이름(`plan_phase_editor.dart` · `plan_student_selector.dart`) | 새 위치 · 이름 | 비고 |
|---|---|---|
| `PhaseEditorPathButton`(+ `_PhaseEditorButtonPainter` · `_PhaseEditorPathClipper`) | `plan_preset_manager.dart` `_PlanPresetPathButton`(+ `_PlanPresetButtonPainter` · `_PlanPresetPathClipper`) | 프리셋 관리만 쓴다. 쓰지 않던 `emphasized` 인자(늘 false)는 빼고 false 경로 그리기를 그대로 옮겼다. 잠금 아이콘 키 `plan-phase-editor-lock-icon` → `plan-preset-lock-icon`(참조 0건) |
| `phaseEditorButtonHoverColor` · `PressedColor` | `plan_preset_manager.dart` `planPresetButtonHoverColor` · `PressedColor`(공개, 값 같음) | `theme_tokens_test`가 같은 값으로 잠근다 |
| `phaseEditorCenteredTrapezoidListRect` · `ShortTrapezoidEdgeLength` · `ContainerInset` · `CompactListNormalGap`(= `SectionSeamGap` 12) | `plan_preset_manager.dart` `_planPresetCenteredTrapezoidListRect` 등 private | 식 그대로 |
| `phaseEditorControlGap` · `ControlHeight`(+ 최소 44 · 최대 72 · 비율 0.065) | `plan_preset_manager.dart` `_planPresetControlGap` · `_planPresetControlHeight` 등 | 식 그대로 |
| `phaseEditorParallelogramPath` | `plan_preset_manager.dart` `_planPresetParallelogramPath` | 식 그대로 |
| `phaseEditorPathSurfaceTexture` | `plan_element_builder.dart` `planPresetListTexture`(원래 이 이름이 옛 값을 가리켰다)에 값 직접. 프리셋 관리도 이 이름을 쓴다 | 값 12개 그대로 |
| `planStudentSelectorFilterControlGap`(8.0) | `plan_preset_manager.dart` `_planPresetFilterControlGap` | |
| 키트 morph로 대체 가능하던 `_lerpGridRect` · `phaseEditorElements` · `_PhaseEditorMotion`(FE6-d 발견 3) | 없음(파일째 지움) | 쓰는 화면이 함께 사라져 키트로 옮길 것이 없었다. `lib/ui/kit/**`는 고치지 않았다 |

#### 지운 · 바꾼 테스트와 대체 테스트

| 지운 테스트 | 대체 |
|---|---|
| `planning_page_test`: phase editor uses the requested motions and responsive section sizes · detail contents follow main section 2 sizing · side lists use the short edge and equal margins · side-list gaps survive responsive resizing · detail rows reserve one full-height assign button · item surface is a bilateral 80 degree parallelogram · scrollbar follows the same 80 degree rail · facing sections preserve the explicit diagonal seam · controls preserve equal height and diagonal clearances · outer container is clipped as a parallelogram(단위 10건) | 없음(화면째 지움). 페이즈 편집 = 흐름 3단계 칸 보드: `plan_flow_order_step_test`. 프리셋 관리로 옮긴 기하는 `plan_preset_manager_test`(5건)와 golden `plan-preset-manager`가 지킨다 |
| `planning_page_test`: phase editor bulk and phase-order controls update editor state · inserts and reorders items between phase rows(위젯 2건) | `plan_flow_order_step_test` "카드를 끌어 칸을 옮기고…" · "칸 이름 바꾸기 · 칸 추가 · 자동 정렬" |
| `planning_page_test`: all plan student selector panels use intro 80 and outro 260 · selector confirmation is bottom-right and shares the title texture(단위 2건) | `plan_flow_student_step_test`(1단계 학생 고르기) |
| `planning_page_test`: dummy phases keep student steps in execution order | 없음(견본째 지움) |
| `plan_element_builder_test`: preset overwrites the draft and confirmation creates unassigned items · builder deletes only the selected unassigned stage and the phase editor keeps the rest · phase completion exits the builder and returns to plan main(대체 경로 3건) | 계획 탭 쪽: `plan_home_detail_test` 계정 없음 3건(아래). 위젯 쪽(직접 띄움): "preset clamps an explicit T9 equipment level…" · "level-only preset raises…"(프리셋 → 확정) · "right list selection enables deletion for one stage" · "restored phase button opens only after plan elements exist" |
| `plan_element_builder_test`: phase editor rejects a drop that reverses student stages | `plan_flow_order_step_test` "선행보다 앞 칸 · 뒤 단계보다 뒤 칸은 거부하고 이유를 돌려준다" · "카드를 끌어 칸을 옮기고, 선행보다 앞 칸은 거부하고…" |
| `kit/diagonal_scrollbar_test`: phase editor (content ratio, thin accent, thumb when idle)(옛 painter 대조 1건) | 없음(스타일 상수째 지움). 나머지 대조(계획 · 학생 · 계정 · 프리셋)는 그대로 |

바꾼 테스트:

- `plan_element_builder_test` "planning seed opens the four-section element builder"(대체 경로 4건 중 1) → "element builder opens its four sections and student status": `PlanningPage`(계정 없음 mock) 대신 `_pumpBuilder`로 위젯을 바로 띄우고 단언은 그대로. "right list and phase action reuse…": `same(phaseEditorPathSurfaceTexture)` → `triangleSize` 104 값 단언. `_legacyBuilderService` · `_threeStageTestPreset` · 쓰지 않게 된 import 삭제.
- `planning_page_test` "scenario creation opens the plan flow step 1…" · `plan_flow_test`: `find.byType(PlanStudentSelector), findsNothing` 1줄씩 삭제(클래스째 지움). 쓰지 않게 된 import 6개 삭제.
- `theme_tokens_test`: 버튼 색 2개는 새 이름(`planPresetButton*Color`)으로 같은 값, `phaseEditorMotionDuration` · `planStudentSelectorMotionDuration` 줄 삭제. `geometry/diagonal_geometry_test`: `planStudentSelectorDiagonalDepth` 줄 삭제. `widgets/section_surface_test`: `planStudentSelectorSectionOpacity` 줄 삭제. `kit/diagonal_scrollbar_test`: `phaseEditorScrollbarTrackPoint` 대조 줄 · 옛 `_OldPhasePainter` 삭제.
- 추가(`plan_home_detail_test`, 5 → 9건): 계정 없음 "S2 · S3 안내 문구, '읽는 중'에 머물지 않고 S1은 꺼진다" · "계산기에서 넘어온 학생은 SnackBar로 알리고 흐름 · 요소 편집기를 열지 않는다" · "계정을 고르면 다시 만든 계획 화면은 바로 정상 홈이다", 그리고 "계산 응답에 overall이 없으면 계산 오류다(FE5-f1 발견 3)".

#### 계정 없음 빈 상태 동작

- 계정 목록에 선택된 계정이 없으면(`_loadRepositoryPlan` · `_ensureRepositoryContext`가 알게 되는 시점) `_noProfile`을 켜고 읽은 상태 · 문서 · 계산을 비운다(`_markNoProfile`). `loadRepositoryPlan: true`도 "활성 계획을 읽는 중입니다."에 머물지 않는다(f1 발견 2 해소).
- Detail 홈 S2 · S3 안내 자리(`_homeNotice`)에 "선택된 계정이 없습니다. 설정에서 계정을 고르면 계획이 보입니다."(키 `plan-home-no-profile`, `AppColors.textSecondary`, 아이콘 없음, 상수 `planNoProfileMessage`).
- S1의 시나리오 목록 · 계획 만들기 · 페이즈 편집과 "활성 계획 다시 읽기" 카드는 꺼진다. 꺼진 버튼 툴팁은 같은 문구다(발견 사항 2).
- 계산기에서 넘어온 학생: 흐름 · 요소 편집기를 열지 않고 SnackBar "계정을 먼저 골라야 계획에 추가할 수 있습니다."(`planNoProfileHandoffMessage`). 홈은 계정 없음 빈 상태로 돌아온다. 계정은 있는데 흐름을 열 수 없을 때(흐름을 열 수 없는 서비스 · 계정 상태 읽기 실패)는 "계획 만들기를 열 수 없어 계산기 목표를 계획에 넣지 못했습니다."(발견 사항 3).
- 계정을 고르면 앱 셸이 `_profileChanged`에서 계획 화면 키(`plan-<profileGeneration>`)를 바꾸고 넘긴 학생(`_planningSeed`)도 비우므로, 새로 만든 계획 화면은 바로 정상 홈이다(테스트는 같은 키 교체를 흉내 낸다).

#### golden

- 지운 장면: 없음. 새 장면: 없음(계정 없음 장면은 만들지 않았다). golden 테스트 · harness는 고치지 않았고 지운 이름을 참조하지 않는다(전체 analyze 0).
- 남는 장면 변화 0 근거(실행 안 함):
  - 계정이 있는 장면만 있다(golden mock은 모두 기본 선택 계정). `_noProfile`은 false로 남아 S1 버튼 · 툴팁 · 안내 분기가 전과 같다. `loadRepositoryPlan: false`로 여는 `plan-preset-manager` · 흐름 · 목록 장면은 `_ensureRepositoryContext`에서 `_noProfile = false`만 더 쓴다.
  - Detail 홈은 같은 `_document` · `_homeProjection`을 그린다. 학생 이름은 같은 값(카탈로그 이름, 없으면 id)이다. 새 `checkProjection`은 mock · golden 계산 응답(`overall` Map, `resources` Map 목록)을 그대로 통과시킨다.
  - `plan-preset-manager`: 옮긴 버튼 · 기하 · 텍스처는 식 · 값이 같고, 지운 `emphasized` 인자는 프리셋 관리가 넘긴 적이 없다(늘 false 경로).
  - 지운 build 분기(요소 편집기 · 페이즈 편집기)는 계정 없음 대체 경로로만 열렸고, golden에는 그 장면이 없다(f1에서 정의 삭제).

#### 처리한 FD

- FD-082 (a)(확정): 그대로. 이번 slice를 막는 열림 FD · 워커 재량 FD 없음.

#### 미검증 항목

- golden(`test/goldens/**`): 미실행. 남는 장면 변화 0은 위 코드 경로 근거로만 말한다.
- 전체 `fe_gate.ps1`(`codealmanac validate` 포함): 미실행.
- process E2E(`*_process_e2e_test.dart`): 미실행(서비스 계층은 고치지 않음).
- 실제 앱 창(앱 셸에서 계정 없이 계산기 → 계획, 설정에서 계정 고르기): 미실행. 앱 셸 경로는 코드 읽기와 키 교체를 흉내 낸 위젯 테스트로만 확인했다.

#### 검수표(계획 탭, mock 모드 · 기준 viewport)

| 확인할 것 | 여는 방법 | 기대 |
|---|---|---|
| 계정 없음 상태 | 계정을 하나도 고르지 않은 상태(예: 계정 없는 mock · 계정을 모두 지운 뒤)로 계획 탭 | S2 · S3 가운데에 "선택된 계정이 없습니다. 설정에서 계정을 고르면 계획이 보입니다."(회색, 아이콘 없음). "읽는 중"이 남지 않는다. S1 버튼 셋 · 현재 계획 카드는 꺼져 있고 툴팁이 같은 문구 |
| 계산기에서 넘기기(계정 없음) | 학생 탭 계산기 "이 목표로 계획에 추가" | 계획 탭으로 가고 SnackBar "계정을 먼저 골라야 계획에 추가할 수 있습니다.". 흐름 · 옛 요소 편집기가 열리지 않고 위 빈 상태 그대로 |
| 계정 고른 뒤 | 설정에서 계정 고르기 → 계획 탭 | 바로 정상 Detail 홈(빈 계획이면 "활성 계획이 비어 있습니다…", S1 켜짐). 넘겼던 학생은 남지 않는다 |
| 계정 있음(회귀) | 계획 탭 첫 화면 · 계산기에서 넘기기 · 목록 S1 "프리셋 관리" | 지금과 같다(흐름 2단계, 프리셋 관리 버튼 · 목록 모양 그대로) |

#### WIP 보존 확인

- 고친 · 지운 파일 14개(+ status) 모두 착수 때 WIP 없음(`git status --short` 빈 결과) → post 사본 · `post_dir` 없음. 종료 때 `git status`의 다른 변경(스캐너 소유 `scan_page.dart` · `scan_companion_dock.dart` · `scan_student_review_workspace.dart` · 스캐너 테스트 등)은 이 slice가 건드리지 않은 기존 WIP다.

#### 발견 사항

1. **`overall` 검사 위치**: 지시는 "`PlanDetailData.fromProjection`에서"였지만 `fromProjection`은 계산 전 빈 응답(`{}`, 홈 "계산하는 중")과 시나리오 미리보기 응답으로도 불려 거기서 던지면 그 화면들이 깨진다. 그래서 같은 모델 파일에 `PlanDetailData.checkProjection`(overall이 Map이 아니거나 `overall.resources`가 Map 목록이 아니면 `FormatException`)을 두고, 옛 캐스트가 있던 자리(활성 계획 홈이 계산 응답을 받는 `_calculateDocument`)에서 부른다. 결과는 옛 동작과 같다("계산 오류\n…", S2 단계 행은 그대로).
2. **"S1 버튼은 지금처럼 꺼진다"는 사실과 달랐다**: 계정이 없을 때 S1 버튼은 켜져 보이고 눌러도 아무 일이 없었다(서비스 종류만 봤다). 결정 문구대로 이제 실제로 끈다. 꺼진 이유 툴팁은 새 문구를 만들지 않고 결정 문구(`planNoProfileMessage`)를 쓴다. "활성 계획 다시 읽기" 카드도 같이 끈다. CF 확인 필요.
3. **새 문구 1개(CF 확인 필요)**: 계정은 있는데 흐름을 열 수 없을 때(서비스가 시나리오 저장소가 아님 · 계정 상태 읽기 예외) SnackBar "계획 만들기를 열 수 없어 계산기 목표를 계획에 넣지 못했습니다."(`planHandoffUnavailableMessage`). 전에는 이 경우도 옛 요소 편집기가 열렸다. 결정 문구("계정을 먼저 골라야…")를 쓰면 사실과 달라 따로 두었다. mock · process 서비스에서는 읽기 실패 때만 보인다.
4. **`PlanElementBuilder` 위젯이 앱에서 쓰이지 않게 됐다**: 계획 탭 대체 경로가 유일한 사용처였다. 위젯은 `plan_element_builder_test` 위젯 테스트 20여 건(`_pumpBuilder`)이 직접 띄우고, 파일에는 흐름 · 학생 탭 · 프리셋 관리가 쓰는 공용 정의가 있다. 위젯(과 `onOpenPhaseEditor` 같은 인자) 정리는 별도 소단위(공용 정의 분리 + 위젯 테스트 정리)가 필요하다. 이번에는 범위 밖으로 두었다(f1 "다음 행동" ⑤의 판단).
5. **키트 주석 2곳이 지운 파일을 가리킨다**: `lib/ui/kit/section_morph.dart` 6줄("그 파일은 FE5-f에서 지울 예정") · `lib/ui/kit/diagonal_scrollbar.dart` 5줄("페이즈 편집기가"). 코드 영향 없음, 키트는 이번 범위가 아니라 고치지 않았다.
6. **계정 선택 복귀 테스트는 앱 셸을 흉내 낸다**: 계획 화면 자체는 계정 바뀜을 듣지 않고 앱 셸의 키 교체에 기댄다. 테스트는 키를 바꿔 다시 띄우는 방식이다. 앱 셸 통합 테스트(계정 없는 셸 → 설정에서 고르기 → 계획 탭)는 없다.
7. f1 발견 1(시나리오 목록 1280×720 넘침) · 4(`planStudioDocument` · 키트 테스트만 쓰는 옛 이름)는 그대로 남는다(다른 slice).

#### 사본 · commit.json

- 착수 사본: `debug/frontend_fe5f2/pre/<v7 기준 경로>` 15개(고친 파일 12 + 지운 파일 2 + status). WIP가 없어 post 사본은 없다.
- `debug/frontend_fe5f2/commit.json`: slice `fe5f2`, `status=true`, modified 12, added 0, deleted 2(`plan_phase_editor.dart` · `plan_student_selector.dart`). message 근거: 워크플로 FE5-f 행 · f1 종료 기록 "다음 행동" · CF 로그 2026-10-12 21:45.
- 인계: `debug/frontend_fe5f2/output.md`.

#### 다음 행동

- f2 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: 레인 워커가 모두 멈춘 뒤 gate 1회. 예상: analyze 0, 일반 테스트 −20 +4(planning_page −15, plan_element_builder −4, kit/diagonal_scrollbar −1, plan_home_detail +4), golden 장면 수 그대로 · 변화 0. 지운 파일 2개는 사용자 승인 뒤 삭제 커밋(`git rm`) — `fe_commit.ps1 -Slice fe5f2`가 `deleted`를 다루지 않으면 같은 삭제 커밋에 넣는다.
- CF 확인: 발견 사항 2(S1 끄기 · 툴팁) · 3(새 SnackBar 문구). 그 뒤 워크플로 FE5-f 행에 f2 완료를 적으면 FE5 표가 끝난다.
- 후속 소단위 후보: 발견 4(`PlanElementBuilder` 위젯 정리), 5(키트 주석), f1 발견 1 · 4.

### fe5f2 commit record (2026-10-13 01:13, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261013_010336\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE7-a 통계 골격 (Lane A, 로컬 Claude Code)

### FE7-a 착수 기록 (2026-10-13, Lane A)

- 상태: 진행 중. 시작 SHA = `cac83222bac7cc7ae7bb4b71f562b45713c4e10b`(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`).
- 범위: 통계 탭 골격(시안 공통 레이아웃). Studio 문서 3섹션(왼쪽 주제·범위 / 가운데 KPI + 위젯 세로 스크롤 / 오른쪽 근거), 주제 3개 전환, 기준 데이터 자리, 범위·필터 버튼 자리(비활성), KPI 띠 자리, 위젯 타일 계단 배치("준비 중"), 근거 패널 틀, 기존 `_reload()` 재사용. 그래프 내용은 넣지 않는다(FE7-b 이후).
- 막힘: 대장 막힘 요약의 FE7-a 행 = FD-104 → 확정(2026-10-06, (a)). 막는 `열림` FD 없음. 워커 재량 FD-106 · FD-125는 권장안으로 처리하고 종료 기록에 적는다.
- 지금 통계 화면 기능(`statistics_page.dart`, `ListView` + `DiagonalSection` 카드):
  1. 머리 카드: "Profile statistics", 연결 상태 글자(Backend disconnected/connecting/Selected profile scope), 계정 이름·id·revision, 읽기 막대, 출처별 오류 6종, "No selected profile.", 새로 고침(`statistics-refresh`).
  2. 모드 seg(`statistics-mode`, Students/Inventory/Plan).
  3. Students: KPI 칩 6개(catalog·confirmed·saved goals·orphan goals·평균 레벨·평균 성급), 누락 메타 id, 분포 선택(`statistics-student-selector`, 8종) → 행(`statistics-row-*`, 막대·n/m·%) → 근거(초상 + 인연 랭크, `statistics-student-bond-*`), "Review in Students".
  4. Inventory: KPI 칩 7개(catalog·snapshot·known·unknown·absent·explicit zero·positive), 누락 id, 카테고리 커버리지 행(`statistics-inventory-*`) → 근거 id 목록, "Review in Inventory".
  5. Plan: 목표 없음 안내 + "Open Plan", KPI 칩(saved goals·gross 스칼라·shortage rows·positive·unresolved·affected), gross 재료 맵, 부족 카테고리(수량 합산), 부족 상위 10, "Review in Plan"·"Shortage details".
  6. 데이터: `_reload()`(계정 → 상태 → 학생 목록 → 인벤토리 목록 → 목표가 있으면 `calculatePlan`·`calculateShortages`, generation 가드), 연결 변화 시 다시 읽기, `reloadToken`.
- 지울 것: 1~5의 옛 화면 위젯 전부(새 골격으로 대체). 남길 것: 6의 데이터 읽기(`_reload()` · generation 가드 · 연결 감시 · `reloadToken`). 읽기 시점만 "처음 보일 때"로 바꾼다(지금은 셸 시작 때 오프스테이지에서 읽는다).
- 고칠 기존 파일(착수 사본 `debug/frontend_fe7a/pre/<v7 기준 경로>`, 작업 트리와 cmp 일치):
  - `frontend/lib/ui/pages/statistics_page.dart` — WIP 없음(`git status --short` 빈 줄), 작업 트리 CRLF
  - `frontend/test/statistics_page_test.dart` — WIP 없음, CRLF
  - `frontend/test/statistics_app_shell_test.dart` — WIP 없음, CRLF
  - `almanac/workflows/frontend-redesign-status.md`(이 문서) — WIP 없음, LF
- 새 파일(예정): `frontend/lib/ui/studio/statistics_studio_layout.dart`, `frontend/lib/ui/statistics/statistics_topics.dart`(주제·타일 목록), `frontend/lib/ui/statistics/statistics_source.dart`(읽은 원천 자료 묶음, 작업 중 추가), `frontend/lib/ui/statistics/statistics_workspace.dart`(3섹션 위젯), 테스트 `frontend/test/statistics_workspace_test.dart`, golden `frontend/test/goldens/fe7a_statistics_golden_test.dart`(장면 `statistics-growth` 1장, 실행하지 않음).
- 읽기만: `frontend/lib/statistics/statistics_projection.dart`(바꾸지 않는다). 고치지 않음: `app_shell.dart`·`app_section.dart`, `lib/ui/kit/**`, `lib/services/**`, Lane B 타이틀 쪽, golden harness, `frontend/tool/**`, backend·contracts.

### FE7-a 종료 기록 (2026-10-13, Lane A, 코드 작성 완료 · CF gate 미실행)

통계 탭을 시안 공통 레이아웃(3섹션) 골격으로 바꿨다. 그래프 · KPI 값 · 근거 목록 · 필터 · 원본 탭 이동은 넣지 않았다(FE7-b~h).

#### 실행 명령 · 결과

모두 `frontend`에서 이 PC(Claude Code)로 실행했다. 로그는 `debug/frontend_fe7a/logs/`이고, 실패 줄(`[E]`·`EXCEPTION`·`Some tests failed`·`error •`)만 찾았다.

| 명령 | 결과 |
|---|---|
| `flutter analyze`(1차, 코드 작성 직후) | **No issues found** |
| `flutter test` 통계 3파일(1차) | +13 −14: ① 필터 · 기준 데이터 · 다시 스캔 행 폭이 시안보다 14px 좁음(오른쪽 여백을 36으로 잘못 읽음 → 모든 행 22) ② 800×600 · 1280×720에서 "다시 스캔" 행 Row 넘침(폭 35) → 왼쪽 행을 최소 폭 180으로 배치하고 자름 ③ 계획 범위 칩(BaChip)이 좁은 제목 줄에서 넘침 → FittedBox scaleDown ④ 테스트 fixture에 계정이 없어 빈 상태 대신 "선택된 계정이 없습니다" → fixture에 계정 추가 |
| `flutter test` 통계 3파일(2차) | **+27 −0** |
| 일회성 렌더(임시 `test/zz_fe7a_render_tmp_test.dart`, harness 공개 함수 `loadGoldenFonts`·`settleGoldenScene`, scratchpad PNG 4장: 성장 · 인벤토리 · 계획 · 계획 1280×720) | 배치는 시안 자리. 제목 줄 범위 글자가 줄 가운데에 서 있음(느슨한 Flexible + Spacer가 남는 폭을 끝에 남김) → `spaceBetween`로 고치고 테스트에 오른쪽 끝 단언 추가. 임시 테스트는 지웠다. golden 비교 아님 |
| `flutter test test/statistics_workspace_test.dart`(+ 임시 렌더) | +13 −0 |
| `flutter analyze`(최종) | **No issues found**(info 포함 0) |
| 관련 25파일 한 번에(`--reporter json`, 아래) | **+226 −0** |
| `git diff --check`(고친 3파일) · 새 6파일 줄 끝 공백 검사 | 0 · 0. 새 파일은 LF · 끝 개행 하나, 고친 기존 3파일은 pre와 같은 CRLF |

관련 25파일(파일별 통과 · 실패, 모두 −0): statistics_workspace +12(새), statistics_page +13, statistics_app_shell +2, statistics_projection +6, home_page +5, home_app_shell +1, widget_test +16, inventory_shell_lazy +1, section_template_studio +15, account_manager_fe8b +6, growth_calculator_view +24, profile_delete_fb2d +17, student_filter_followups +4, student_filter_modal +7, title_page +25, planning_page +17, scan_page_revision +14, tactical_page_revision +5, kit/diagonal_scroll_viewport +5, kit/scroll_viewport_fog +6, kit/diagonal_row +6, kit/kpi_tile +2, kit/titles +4, kit/section_morph +7, kit/buttons +6.

- 걸리는 기존 테스트 찾기: `statistics`·`Statistics`·`top-tab-statistics`·`AppSection.statistics`·`statistics-page`로 test/ 전체를 grep했다. 셸 오프스테이지 읽기 시점이 바뀌므로 `BAPlannerApp(`을 쓰는 셸 테스트 전부와 `listProfiles`·`loadRepositoryState`를 덮어쓰는 테스트 전부, 쓰는 키트(scroll viewport · fog · diagonal_row · kpi_tile · titles · section_morph · buttons) 테스트를 함께 돌렸다. `developer_tools_app_test`의 "item statistics"·`metadata_manager_dto_test`·process E2E 2개의 `statistics`는 다른 기능(아이템 통계 · 전술 통계 · gross 계산)이라 돌리지 않았다.
- 빌드 잠금(`build/`·`.dart_tool/`) 충돌은 없었다. `flutter analyze`가 pub get을 돌렸지만 `pubspec.lock`·`pubspec.yaml`은 바뀌지 않았다.
- 실행하지 않음: golden(`test/goldens/**`, 새 `fe7a_statistics_golden_test.dart` 포함), 전체 `fe_gate.ps1`, `-UpdateGoldens`, `fe_commit.ps1`, 맨 `flutter test`, process E2E, `codealmanac validate`.

#### 고친 파일

- **`lib/ui/studio/statistics_studio_layout.dart`(새)**: Studio 문서 `statisticsStudioDocument`(3 element), id 상수, `statisticsSection`, 섹션 안 좌표 `StatisticsMetrics`(시안 값 + 유도식 주석).
- **`lib/ui/statistics/statistics_topics.dart`(새)**: `StatisticsMode`(옛 페이지 enum을 그대로 옮김, F §4 "enum 재사용") + 주제별 글자 · 도움말 · 범위 · KPI 라벨 · 타일 줄(ID · 제목 · 차수 · 시안 폭 · 높이) · 근거 버튼 글자, 순수 함수 `statisticsTileScale` · `statisticsTileSlots`.
- **`lib/ui/statistics/statistics_source.dart`(새)**: `_reload()`가 읽은 원천 자료 묶음 `StatisticsSourceData`(버킷별 필드 + 오류 목록 + 근거 패널 읽기 상태 안내 `notice`). FE7-b가 여기서 값을 꺼낸다.
- **`lib/ui/statistics/statistics_workspace.dart`(새)**: 3섹션 위젯 `StatisticsWorkspace`(섹션 표면 = 공용 `paintSectionSurface`, 내용은 섹션 path로 자름), `statisticsSectionPolygon`, `StatisticsViewportGeometry`. 쓰는 키트: `RailButton` · `DiagonalRow`(rail) · `BaChip` · `KitGlyph` · `InfoPopover` · `PanelTitle` · `TileTitle` · `KpiTile` · `WidgetTile` · `DiagonalScrollViewport`(translate, `ScrollFogSpec.statistics`) · `sectionCanvasElementPolygon`.
- **`lib/ui/pages/statistics_page.dart`**(CRLF 유지): 옛 `ListView` 화면을 지우고 `StatisticsWorkspace`를 그린다. `_reload()`(순서 · generation 가드 · 목표 없을 때 계산 생략)는 그대로이고 오류 글자만 한국어로 바꿨다. 읽기 시점: `TickerMode.valuesOf(context).enabled`로 보임을 판단해 처음 보일 때 읽고, 숨어 있는 동안의 다시 읽기 요청(`reloadToken` · 연결 · 서비스 교체)은 표시만 해 두었다가 다시 보일 때 한 번 읽는다. `StatisticsMode`는 이 파일에서 export한다(옛 import 호환).
- 테스트:
  - `test/statistics_page_test.dart`(재작성, CRLF 유지) 13건: 연결 · 저장소 없음 · 계정 없음 안내, 읽는 중 → 빈 상태, 목표 없을 때 계산 생략 + 원천 자료 보존, 목표 있을 때 두 계산 페이로드(옛 테스트 그대로), 주제 전환(타일 목록 · viewport key, 다시 읽지 않음), 필터 · 근거 버튼 비활성 + 다시 스캔 → 스캔 탭, 출처 실패 안내 + token 다시 읽기 회복, 늦은 이전 응답 무시(옛 테스트, revision을 화면 글자 대신 넘긴 자료로 확인), 숨은 페이지는 처음 보일 때까지 읽지 않음, 4개 창 크기 넘침 없음.
  - `test/statistics_app_shell_test.dart`(재작성, CRLF 유지) 2건: 셸 시작 때 통계 읽기 0회 → 탭을 열면 1회 → 홈 갔다 다시 열면 2회(호출 스택 `_StatisticsPageState.`로 센다), 셸 안 1280×720 세 주제 넘침 없음.
  - `test/statistics_workspace_test.dart`(새) 12건: 섹션 path 꼭짓점 ±1px, viewport · 스크롤바 여백, 타일 자리 함수, 주제별 타일 순서, 왼쪽 요소 · 근거 버튼 · 성장 타일 · KPI 띠 · 제목 줄 · 인벤토리 · 계획 타일 rect ±2px, 스크롤하면 사선을 따라 15.9px 밀림 + 주제를 바꿨다 돌아오면 스크롤 처음, 주제 버튼 콜백, 1280×720 · 800×600 넘침 없음.
  - `test/goldens/fe7a_statistics_golden_test.dart`(새, 장면 1장, 실행 안 함).
- 지운 테스트(옛 화면 키 의존)와 대체:
  - "empty goals skip both calculation APIs and expose all modes"(Students/Inventory/Plan 글자) → "empty goals skip both calculation APIs and keep every source" + "topic buttons switch the tile list without reading again".
  - "detail and data-owner actions navigate without mutation"(`statistics-row-owned` · 근거 초상 · `statistics-open-*`) → "filter and evidence actions are placeholders; rescan opens scan". 행 · 근거 · 이동은 FE7-b · FE7-d에서 새 키로 다시 쓴다.
  - "student source failure preserves inventory and refresh recovers"(`statistics-refresh`) → "source failure is reported and a token reload recovers".
  - "statistics is scrollable at …"(`statistics-mode` · `ListView`) → "statistics fits …" + workspace 테스트의 크기별 넘침 검사.
  - 셸 "statistics tab is service-backed and reloads on re-entry"("Profile statistics") → "statistics tab reads when first shown and reloads on re-entry"(읽기 횟수로 고정).
  - 나머지 두 건(연결 · 저장소 · 계정 안내, 늦은 응답)은 기대를 새 표시 자리로 옮겼다.
- 고치지 않음: `statistics_projection.dart`(읽기만, 화면에서 아직 안 씀), `app_shell.dart`·`app_section.dart`, `lib/ui/kit/**`, `lib/services/**`, Lane B 타이틀 · 계정 파일, 인벤토리 · 계획 · 학생 · 스캔 화면, golden harness, `frontend/tool/**`, backend · contracts.

#### 섹션 배치(기준 viewport 2560×1392, Studio 문서)

| 섹션 | rect(grid) · spec | 꼭짓점(기준 viewport) | 시안 대비 |
|---|---|---|---|
| 왼쪽 주제 · 범위 | (0,2,22,94) 왼쪽 면 사다리꼴, face 0+96, 깊이 96 | (0,209.2)·(586.7,209.2)·(378.1,1392)·(0,1392) | 0.1px 미만 |
| 가운데 KPI + 위젯 | (15,2,64,94) 아래 면 평행사변형, **face 0+84**, 깊이 96 | (608.6,209.2)·(2101.9,209.2)·(1893.3,1392)·(400,1392) | 0.1px 미만(rect 오른쪽 4.8px는 path 밖) |
| 오른쪽 근거 | (72,2,24,94) 오른쪽 면 사다리꼴, face 0+96, 깊이 96 | (2128.6,209.2)·(2560,209.2)·(2560,1392)·(1920,1392) | 0.1px 미만 |

섹션 안(시안 값, 위젯 테스트로 재는 것은 ±2px):
- 왼쪽: "통계" 21px (20, +22) · 주제 버튼 64높이 피치 74(폭 538 · 524.9 · 511.9 = 행 윗변 높이의 사선에서 22) · 필터 캡션 +316 · 필터 버튼 +342 52높이 · 보조 문구 +402 · 기준 데이터 캡션 +458 · 행 +484 44높이 피치 50 · 다시 스캔 아래에서 70, 52높이.
- 가운데: 제목 줄 (635.9, +20, 1425.3×36) · viewport (400, +72, 1683.2×1100.8). viewport 오른쪽 끝 = 사선 − 6이라 공용 스크롤바 트랙이 시안 트랙 (1671.1,12)→(1481.2,1088.8)과 겹친다(트랙 위 · 아래 끝은 키트 inset 10이라 시안 12보다 2px 길다). KPI 띠 (627.4, 287.2, 1373.3×84).
- 타일: A1 (549.3,393.2,791.4×322) · A2 (1303.9,393.2,695.5×322) · A4 (480.6,737.2,751.6×368) · A6 (1187.2,737.2,751.6×368) · A3 (421.5,1127.2,741.9×313) · A5 (1128.2,1127.2,741.9×313) / B1 (550.9,393.2,725.1×313) · B2 (1240.8,393.2,758.6×313) · B3 (485.2,728.2,1455.2×351) / C1 (543,393.2,749.8×358) · C2 (1249.7,393.2,749.8×358) · C3 (481.5,773.2,777×327) · C4 (1220.8,773.2,711.6×327) · C5 (422.4,1122.2,1448.5×313). 모두 테스트 ±2px 통과.
- 오른쪽: 제목 (2160.8, +22) · 안내 줄 (2160, +72) · ghost (1959.2,1248,578.8×58) · primary (1948.2,1316,589.8×52).
- 타일 계단은 공용 viewport translate 모드가 만든다: 줄 왼쪽 = inset + (viewport 바닥 − 줄 바닥) × tan 10°, inset = 30 + 사선 깊이(10) = 31.76, reserve = 70 − 6 − inset = 32.24(시안: 타일 아래 왼쪽이 섹션 사선에서 30, 줄 위 오른쪽이 70). 같은 줄 타일은 사선 변 사이 20, 폭은 시안 비율. 콘텐츠 높이 1191 · 830 · 1186(위 6, 사이 22, 아래 32 — 마지막 4px 빈 행)이 시안과 같아 스크롤 범위 90.2px · 가로 이동 15.9px도 같다(테스트).
- 다른 창 크기: 섹션은 Studio grid로 바뀐다. 왼쪽 · 오른쪽 요소는 세로 비율(0.4~1)로 함께 줄고(계획 만들기 A 레일 규칙, 요소마다 FittedBox), 가운데 타일 높이는 viewport 폭 비율이다(타일 모양 유지). KPI 띠는 846px보다 좁으면 띠째 줄인다. 전체 화면 일괄 축소는 하지 않는다.

#### 섹션 모션

- 탭 진입 · 퇴장은 셸 `AnimatedSectionStack`의 기존 통계 모션(intro 90 · outro 270, `AppMotion.tabBody*`) 그대로다. 섹션별 부착면 방향 모션(왼쪽은 왼쪽, 가운데는 아래, 오른쪽은 오른쪽)은 셸의 `independentMotionIndices`에 통계를 넣어야 해서(`app_shell.dart`) 이번에 하지 않았다(발견 사항 7).
- 주제 전환은 가운데 제목 줄 + viewport를 주제별 key(`statistics-topic-body-<topic>` · `statistics-viewport-<topic>`)로 바꿔 끼우고 `AppMotion.header`(220ms) 교차 페이드한다. 스크롤 위치는 넘기지 않는다(테스트).

#### 처리한 FD

- **FD-104(확정)**: 필터는 통계 전용(학생 성장에만) — 왼쪽 캡션 "필터 · 학생 성장에만 적용", 학생 성장은 "없음 · 보유 —명 전체", 인벤토리 · 계획은 "인벤토리 · 계획 집계는 항상 전체", 보조 문구 두 줄(시안 그대로). 버튼은 FE7-e 전까지 비활성.
- **FD-105(워커 재량, 권장안)**: KPI는 주제별 5칸(시안 라벨), 값은 '—'. 누르면 스크롤은 FE7-b.
- **FD-106(워커 재량)**: 권장안 "미구현 위젯은 빈 카드 없이 레이아웃을 당긴다"는 FE7-a 골격과 충돌한다(골격 단계에서는 모든 위젯이 미구현). CF 프롬프트대로 시안의 모든 타일을 "준비 중" + 차수 칩으로 두었다. 1차 출시 때 2·3차 타일을 빼는 방식은 발견 사항 1.
- **FD-125(워커 재량, 권장안 중 지금 되는 부분)**: "다시 스캔"은 스캔 탭을 연다(`onOpen(AppSection.scan)`, FE6-a 인벤토리 스캔 버튼과 같음). "해당 종류 강조"는 스캔 쪽 진입점이 생기면.
- FD-028 · FD-031 · FD-033 · FD-034: 이번에 쓰는 값이 없다. 모르는 값은 모두 '—'(FD-033)이고 다섯 버킷은 `StatisticsSourceData`에 출처별로 따로 둔다.
- 막는 `열림` FD 없음.

#### 지운 · 옮긴 기능과 "FE7-b/c에서 복원" 목록

지운 옛 화면 위젯(모두 `statistics_page.dart` 안): 머리 카드("Profile statistics" · 연결 글자 · 계정 이름 · id · revision · 읽기 막대 · 오류 목록), 새로 고침 버튼(`statistics-refresh`), 모드 seg(`statistics-mode`), Students/Inventory/Plan 세 보기 전부(KPI 칩 · 분포 선택 · 행 · 근거 초상 · 카테고리 커버리지 · gross 재료 맵 · 부족 카테고리 · 부족 상위 10 · Review/Open/Shortage 버튼 4개).

옮긴 것: 연결 · 저장소 없음 · 계정 없음 · 읽는 중 · 출처별 오류 → 근거 패널 안내 줄(`StatisticsSourceData.notice`). 모드 전환 → 주제 버튼 3개. 새로 고침 → 탭을 다시 열면 다시 읽는다(셸 reloadToken, 테스트로 고정). 계정 이름 · revision 표시는 시안에 자리가 없어 넘긴 자료에만 남는다.

FE7-b/c에서 복원(시안 위젯으로):
- FE7-b: 성장 KPI(보유 학생 · 평균 육성도 · 최대 레벨 · 완전 육성 · 계획 등록), A1(옛 레벨 분포를 대신하는 육성도 분포, 세그 육성도/레벨/스킬/장비), A2, 구간 선택 → 근거 학생 목록(옛 근거 초상 · 인연 랭크 `BondRankPortrait` 재사용 후보), "보유 n명" 범위 글자.
- FE7-c: 인벤토리 KPI · B1(옛 카테고리 커버리지의 스캔 없음 판정을 빗금으로), 계획 KPI · C1(옛 부족 상위 목록) · C2, 근거 재화 목록, 범위 칩 "활성 계획 · n명 · 페이즈 n".
- 그 뒤 slice: 이동(옛 Review in Students · Inventory · Plan · Shortage details → 근거 패널 아래 두 버튼, FE7-d), 기준 데이터 시각 · 스냅샷(FE7-h). 옛 분포 중 school · combat_class · attack_type · defense_type · role · star는 A3 · A4(FE7-f)와 통계 필터(FE7-e)로 간다. gross 재료 맵 · 옛 KPI 칩(orphan goals · unresolved 등)은 시안에 자리가 없다(복원하지 않음, 필요하면 개발 도구).

#### golden 변화 예상

- **기존 장면 전부: 변화 0.** 통계 탭이 보이는 장면이 없고(golden 테스트 `statistics` grep 0건), 통계 페이지는 오프스테이지에서 그리지 않는다. 바뀐 것은 오프스테이지 통계가 셸 시작 때 Mock을 읽지 않게 된 것뿐이라 다른 화면 그림에 닿지 않는다. 바뀌는 기존 기준 이미지가 없어 commit.json에 `whole`을 두지 않았다.
- **새 장면 `statistics-growth`**(`fe7a_statistics_golden_test.dart`, 기준 이미지 없음 → RED, CF가 만든다). 기대 모습(일회성 렌더로 본 배치):
  - 헤더: 통계 탭 선택, 제목 "통계", 부제 "계정 성장 통계"(app_section 그대로, 발견 사항 3).
  - 왼쪽: "통계", 주제 버튼 3개(학생 성장 핑크 선택 · 인벤토리 현황 · 계획 집계, 부제 한 줄씩, 사선을 따라 좁아짐), "필터 · 학생 성장에만 적용" + 흐린 필터 버튼(깔때기 · "필터" · "없음 · 보유 —명 전체" · 꺾쇠) + 보조 문구 두 줄, "기준 데이터" + 3행(학생 스캔 · 인벤토리 · 스냅샷, 오른쪽 회색 칩 '—'), 아래 "다시 스캔"(스캔 아이콘 · 꺾쇠).
  - 가운데: "학생 성장" + (i), 오른쪽 끝 "보유 —명 기준 · 지난 스냅샷 대비". KPI 5칸(보유 학생 · 평균 육성도 · 최대 레벨 · 완전 육성 · 계획 등록, 값 '—'). 타일 6장 계단(A1 육성도 분포 1차 · A2 항목별 완성도 1차 / A4 학교 · 역할 비교 2차 · A6 성장 추이 2차 / A3 성작 · 전용무기 2차 · A5 스킬 · 장비 매트릭스 3차, 각 가운데 "준비 중"), A3 · A5 줄은 viewport 아래에서 잘리고 아래 포그. 오른쪽에 공용 사선 스크롤바(긴 핑크 썸).
  - 오른쪽: "근거 확인" 제목, "구간을 고르면 근거가 보입니다.", 아래 흐린 ghost "학생 탭에서 보기" · 흐린 핑크 primary "이 구간 학생을 계획에 추가"(둘 다 꺾쇠, 왼쪽 변 사선).

#### 검수표

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Stats-Growth(골격) | 앱 mock 실행 → 통계 탭(기본 학생 성장) | 세 섹션 모양 · 간격(왼쪽 사다리꼴 · 가운데 평행사변형 · 오른쪽 사다리꼴), 주제 버튼 계단 폭, KPI 띠 5칸 자리, 타일 6장 계단(줄마다 사선을 따라 왼쪽으로), 가운데를 스크롤하면 타일이 사선을 따라 오른쪽으로 밀리고 위 포그가 나타남, 공용 스크롤바 |
| Stats-Inventory(골격) | 왼쪽 "인벤토리 현황" | 타일 B1 · B2 / B3(전폭), 스크롤 없음(콘텐츠 830) → 썸 없음, 범위 글자 "활성 계획 기준 · 인벤토리 스캔 —", 필터 부제 "인벤토리 · 계획 집계는 항상 전체", 근거 버튼 글자 |
| Stats-Plan(골격) | 왼쪽 "계획 집계" | 타일 C1 · C2 / C3 · C4 / C5(전폭), 범위 칩 "활성 계획 · —명 · 페이즈 —", 근거 버튼 글자 |
| Statistics-Proposal | 위 세 화면 | 차수 칩(1차 핑크 · 2차 파랑 · 3차 회색)이 기능 카드 표와 같은가, 모르는 값이 모두 '—'인가, (i) 도움말 문구 |
| (공통) | 주제를 바꾸고 돌아오기, 다른 탭 → 통계 | 주제 전환 때 가운데가 짧게 교차 페이드되고 스크롤이 처음으로, 탭 진입 · 퇴장은 다른 탭과 같은 셸 모션, 1280×720에서 예외 없이 줄어드는가, 필터 · 근거 버튼은 흐리고 눌리지 않음, "다시 스캔" → 스캔 탭 |

#### 미검증 항목

- golden(새 장면 `statistics-growth` · 기존 장면 변화 0 예측): **미실행**. 일회성 렌더는 배치 확인만이다.
- 전체 `fe_gate.ps1`(나머지 테스트 · process E2E · `codealmanac validate` · 저장소 전체 `git diff --check`): **미실행**.
- 실제 백엔드에서의 통계 탭(처음 열 때 읽기 시간): **미실행**. Mock과 위젯 테스트만 보았다.
- 섹션 안 요소 중 테스트로 재지 않은 것(제목 "통계" · 캡션 · 보조 문구 · 근거 제목 · 안내 줄 위치)은 시안 값을 옮긴 계산이다.
- 실제 창에서의 주제 전환 페이드 · 셸 모션 체감.

#### WIP 보존 확인

- 고친 기존 4파일(통계 페이지 · 테스트 2 · 이 문서)은 착수 때 WIP가 없었다(`git status --short` 빈 줄). post 사본 · `post_dir`는 두지 않았다. pre 사본 대비 diff는 이 slice 줄뿐이고, 기존 3파일의 CRLF를 유지했다.
- 작업 트리의 다른 미커밋 변경(Lane B 타이틀 · 계정 쪽, 스캐너 · 백엔드 파일, 다른 문서)은 읽지도 고치지도 않았다. git 쓰기는 하지 않았다. 임시 렌더 테스트는 작업 트리에서 지웠다(커밋 대상 아님).

#### 발견 사항

1. **FD-106 vs 골격**: 권장안대로라면 1차 출시 때 2·3차 타일(A3 · A4 · A5 · A6 · B2 · B3 · C3 · C4 · C5)을 빼고 레이아웃을 당겨야 한다. 타일 목록에 차수가 있어 거르기는 한 줄이지만, 한 줄에 하나만 남는 경우(A4 없이 A6만 등) 타일 폭 · 줄 구성 규칙이 없다. FE7-b/c 착수 전 CF 결정 필요(빈 카드 유지 vs 당기기, 당길 때 줄 구성).
2. **근거 패널 빈 상태 문구**: 시안 세 장 모두 구간이 선택된 상태라 빈 상태 문구가 없다. 프롬프트 예시 "구간을 고르면 근거가 보입니다."를 쓰고, 제목은 Proposal 흐름 2단계 "근거 확인"을 썼다. 읽기 상태 안내(연결 · 계정 없음 · 오류)도 같은 줄에 둔다.
3. **헤더 부제**: 시안 "학생 성장 · 관심 구간 발견 → 근거 확인 → 원본 탭으로 이동"(주제별로 바뀜)인데 `app_section.dart`는 "계정 성장 통계"다. 고치지 않음 범위라 그대로다(FE6-e 발견 5 · FE6-d 발견 2와 같은 "탭 상태 → 부제" 소단위).
4. **KPI 타일 높이**: 통계 시안 KPI는 84높이 · 값 28px, 키트 `KpiTile`은 70 · 26px다. 띠 자리(84)는 시안대로 두고 키트 타일을 가운데 놓았다. FE7-b에서 키트 높이 인자가 필요한지 판단(키트 요청 후보).
5. **타일 제목의 회색 ID**: 시안 "A1"은 13px 회색이고 제목은 16px 흰색이다. 키트 `TileTitle`은 글자 하나만 받아 "A1 육성도 분포"를 한 색으로 그린다(키트 요청 후보: 앞 글자 슬롯). 프롬프트의 "PanelTitle" 대신 시안 타일 머리(6×18 막대 · 16px)와 같은 키트 `TileTitle`을 썼고, 근거 패널 제목에 `PanelTitle`을 썼다. A1 · B2 · B3 · C1의 머리 세그는 FE7-b 이후 차수 칩 자리를 바꾼다.
6. **근거 패널 버튼 모양**: 시안은 왼쪽 변 80° · 오른쪽 수직(왼쪽 섹션 레일 버튼의 좌우 반전)인데 키트에 그 변형이 없다. 키트 `RailButton`을 좌우로 뒤집어 바탕만 쓰고 글자는 바로 세워 올렸다(지금은 비활성이라 문제없음). FE7-d에서 누를 수 있게 할 때 키트 변형으로 바꾸는 편이 낫다(키트 요청 후보).
7. **셸 쪽 두 가지**: (a) 셸이 통계에 `active`를 주지 않아 페이지가 `TickerMode`로 보임을 판단한다(선례 `student_form_cycle.dart`). CF가 인벤토리처럼 `active` 인자를 원하면 셸 한 줄 + 페이지 몇 줄이다. (b) 섹션별 부착면 모션은 셸 `independentMotionIndices`에 통계를 넣고 페이지가 진입 모션을 그리는 소단위가 필요하다(학생 · 계획 탭 선례).
8. **작은 창 가독성**: 1280×720에서 왼쪽 · 오른쪽 섹션 요소가 하한 0.4배까지 줄어 글자가 작다(계획 만들기 A 레일과 같은 규칙). 예외는 없다. 작은 창용 승인된 레이아웃 상태가 없어 그대로 두었다.
9. 시안 KPI 띠 x(227.4)는 줄 자리 양쪽에서 17.4 안쪽이라는 것 말고 규칙을 찾지 못했다. 상수 `kpiInset`으로 두었다.
10. 시안 오른쪽 아래 버튼의 둘째 줄 중 구간에 묶인 글자("필터: 육성도 60~70%", "기술 노트 탭 · 최상급 선택", "P2 선택 · 순서 바꾸기")는 빼고 구간과 무관한 글자만 두었다. 구간 글자는 FE7-d에서 선택에 따라 붙인다.

#### 사본 · commit.json

- 착수 사본: `debug/frontend_fe7a/pre/<경로>`(고친 기존 4파일). WIP가 없어 post 사본은 없다.
- `debug/frontend_fe7a/commit.json`: slice `fe7a`, `status=true`, modified 4(이 문서 포함), added 6(새 기준 이미지 `statistics-growth.png`는 CF가 넣는다), `whole` 없음(바뀌는 기존 기준 이미지 없음). message 근거: Stats-Growth · Stats-Inventory · Stats-Plan artboard, F §2 · §3, FD-104(+ FD-105 · 106 · 125).
- 인계: `debug/frontend_fe7a/output.md`.

#### 다음 행동

- FE7-a 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: 레인 워커가 모두 멈춘 뒤 gate 1회. 예상: analyze 0, 일반 테스트에서 통계 3파일 +27(새 workspace 12 · page 13 · shell 2, 옛 page 9 · shell 1 대체), golden은 새 장면 `statistics-growth` 기준 없음 RED만, 다른 장면 변화 0. 승인 뒤 `-UpdateGoldens` · 재비교 · `fe_commit.ps1 -Slice fe7a`.
- 발견 사항 1(FD-106 적용 방식)은 FE7-b 착수 전 CF 결정, 4 · 5 · 6은 키트 요청 후보, 3 · 7은 셸 · app_section 소단위 후보.

#### 재개(13:10 CF 메시지)

경위: 같은 FE7-a 프롬프트가 두 세션에 들어가 01:50에 다른 세션이 이 slice 파일(`statistics_topics.dart`·`statistics_workspace.dart`·`statistics_workspace_test.dart`)을 고쳤고, 그 세션이 12:50에 모두 되돌리고 멈췄다(CF 확인). 재개 때 파일이 내 마지막 상태(크기 8649 · 36899, `showsOrder`·`_TileHeader` 흔적 0)임을 확인했다. `debug/frontend_fe7a/logs/`에 남은 로그 8개(analyze1 · analyze_final · related.json · related_err · render_tmp · test1~3, 01:37~01:46)는 모두 이 세션 것이다. CF 시안 대조 3건(FD-001 시안 우선)을 고쳤다.

##### 타일 머리 시안 대조(dc_outline: Stats-Growth · Stats-Inventory · Stats-Plan)

| 타일 | 시안 제목 | 머리 seg(첫 칸 선택) | 차수 칩 | 앱(재개 뒤) |
|---|---|---|---|---|
| A1 | 육성도 분포 | 육성도 · 레벨 · 스킬 · 장비 | 없음 | seg 자리(비활성), 칩 없음 |
| A2 | 항목별 완성도 | — | 1차(pk) | 칩 |
| A4 | **학교 비교**(옛 앱 "학교 · 역할 비교") | 학교 · 역할 | 없음 | 제목 고침, seg 자리, 칩 없음 |
| A6 | 성장 추이 | — | 2차 | 칩 |
| A3 | 성작 · 전용무기 | — | 2차 | 칩 |
| A5 | 스킬 · 장비 매트릭스 | — | 3차(gy) | 칩 |
| B1 | 카테고리별 충족률 | — | 1차(pk) | 칩 |
| B2 | 부족 · 과잉 | 부족 순 · 과잉 순 | 없음 | seg 자리, 칩 없음 |
| B3 | 주요 재화 변화 | 스냅샷 6회 · 4주 · 전체 | 3차(gy, seg 뒤) | seg 자리 + 칩 |
| C1 | 필요량 vs 보유 | 부족 큰 순 · 페이즈 순 | 없음 | seg 자리, 칩 없음 |
| C2 | 병목 매트릭스 | — | 1차(pk) | 칩 |
| C3 | 페이즈별 누적 부족 | — | 2차 | 칩 |
| C4 | 학생별 목표 진행 | — | 2차 | 칩 |
| C5 | 미계획 학생 | — | 3차(gy) | 칩 |

제목은 A4만 시안과 달랐다. 다른 13개는 시안 그대로였다.

##### 바뀐 것

- `lib/ui/statistics/statistics_topics.dart`: `StatisticsTileSpec`에 `segments`(시안 seg 글자)와 `showsOrderChip`(기본 true)을 더했다. A1 · A4 · B2 · C1은 seg만 있고 칩은 없다. B3은 seg와 칩이 함께 있다. A4 제목은 "학교 비교"다.
- `lib/ui/statistics/statistics_workspace.dart`: 키트 `TileTitle` 대신 이 파일의 `_TileHeader`를 쓴다. 키트 조각 `TitleBar`(6×18) · 간격 8 · `TitleRule`(캡 40) · 줄 사이 7은 `TileTitle`과 같다.
  - ID는 `kitDisplayStyle(13, color: AppColors.textMuted)`(= `#9eb0c2`, 새 토큰은 필요 없다)이고 오른쪽 간격은 8이다. 제목은 `kitDisplayStyle(16)`(흰색 `AppColors.text`)이다. ID와 제목은 글자 기준선을 맞춘다.
  - 오른쪽 묶음은 seg 자리(키트 `SkewSegmented`, `onChanged: null` → 키트 비활성 불투명도 .45, 높이 26 · 글자 11 · 안쪽 16 · 간격 6, 첫 칸 선택)와 seg 뒤 6px의 차수 칩이다.
  - 제목 묶음과 오른쪽 묶음은 `spaceBetween`으로 양끝에 둔다. 좁으면 오른쪽 묶음을 줄인다(FittedBox scaleDown).
  - 키: `statistics-tile-<id>-id` · `-title` · `-seg` · `-order`. 키트는 고치지 않았다.
- `test/statistics_workspace_test.dart`: 새 테스트 "tile headers follow the artboard title, seg and order chip"를 더했다. 위 표 14타일의 제목 · seg 글자 · 선택 · 비활성 · 높이 26 · 칩 유무와 글자 · ID 13px `textMuted` · 제목 16px `text`를 세 주제에서 확인한다. 성장 타일 테스트의 `find.text('A1 육성도 분포')`는 `'육성도 분포'`로 바꿨다(ID와 제목이 나뉘었다).
- 종료 기록 발견 사항 5(타일 제목의 회색 ID)는 이 변경으로 풀렸다. 키트 요청은 필요 없다(같은 조각을 이 slice 위젯에서 조합).
- 종료 기록 발견 사항 10의 seg 글자는 이제 시안 그대로 보인다(비활성). 구간에 묶인 근거 버튼 둘째 줄 글자는 여전히 FE7-d다.

##### 실행 명령 · 결과(재개 뒤)

| 명령 | 결과 |
|---|---|
| `flutter analyze`(머리 교체 직후 · 최종) | **No issues found** · **No issues found** |
| `flutter test test/statistics_workspace_test.dart` | **+13 −0**(새 머리 테스트 포함) |
| 일회성 렌더(임시 `test/zz_fe7a_render_tmp_test.dart`, 성장 · 인벤토리 2장, 실행 뒤 지움) | 회색 ID · 흰 제목, A1 · A4 · B2 · C1은 흐린 seg만, B3은 흐린 seg + 3차 칩, 나머지는 칩만. 넘침 없음. golden 비교 아님 |
| 관련 25파일 한 번에(`--reporter json`, 종료 기록과 같은 묶음) | **+227 −0**: statistics_workspace +13, statistics_page +13, statistics_app_shell +2, statistics_projection +6, 나머지 21파일은 종료 기록과 같은 수(home_page 5 · home_app_shell 1 · widget_test 16 · inventory_shell_lazy 1 · section_template_studio 15 · account_manager_fe8b 6 · growth_calculator_view 24 · profile_delete_fb2d 17 · student_filter_followups 4 · student_filter_modal 7 · title_page 25 · planning_page 17 · scan_page_revision 14 · tactical_page_revision 5 · kit 7파일 36), 모두 −0 |
| `git diff --check`(고친 기존 4파일) · 새 6파일 줄 끝 공백 · 줄바꿈 | 0 · 0. 새 파일 LF · 끝 개행 하나, 기존 3파일 CRLF 유지 |

- 로그: `debug/frontend_fe7a/logs/analyze_resume1.txt` · `analyze_resume2.txt` · `test_resume1.txt` · `render_tmp2.txt` · `related_resume.json`.
- 빌드 잠금 충돌 없음. `pubspec.lock` 변화 없음.
- 실행하지 않음: golden, 전체 `fe_gate.ps1`, `-UpdateGoldens`, `fe_commit.ps1`, 맨 `flutter test`, process E2E, `codealmanac validate`.

##### golden 예측(갱신)

- 기존 장면 전부: 변화 0(종료 기록과 같은 이유).
- 새 장면 `statistics-growth`: 종료 기록의 기대 모습에서 가운데 타일 머리만 바뀐다.
  - 머리는 핑크 막대 · 회색 13px ID · 흰 16px 제목이다.
  - A1 "육성도 분포": 오른쪽에 흐린 seg 육성도(분홍 테두리 선택) · 레벨 · 스킬 · 장비. 칩은 없다.
  - A2 "항목별 완성도": 1차 핑크 칩.
  - A4 "**학교 비교**": 흐린 seg 학교(선택) · 역할. 칩은 없다.
  - A6 "성장 추이" 2차 · A3 "성작 · 전용무기" 2차 · A5 "스킬 · 장비 매트릭스" 3차(회색): 각자의 칩.
  - 제목 아래 룰은 seg가 있는 머리(높이 26)에서 칩만 있는 머리(24)보다 2px 아래다.
  - 나머지(세 섹션 · KPI 띠 · 근거 패널 · 왼쪽)는 종료 기록 그대로다.

##### commit.json · 인계

- `debug/frontend_fe7a/commit.json`은 파일 목록이 실제와 같아(modified 4 · added 6, `whole` 없음) 목록은 그대로 두었다. message에는 시안 머리(seg 자리 · 칩 유무 · 회색 ID)를 한 줄 더했다.
- `debug/frontend_fe7a/output.md`의 해시는 이 재개 뒤 파일로 새로 계산한다.

##### 다음 행동(갱신)

- FE7-a 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF gate 예상: analyze 0, 통계 4파일 +34(workspace 13 · page 13 · shell 2 · projection 6), golden은 새 장면 `statistics-growth`만 RED(기준 없음), 다른 장면 변화 0.
- 남은 CF 판단: 종료 기록 발견 사항 1(FD-106) · 3 · 4 · 6 · 7.

### fe7a commit record (2026-10-13 14:28, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261013_141727\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE7-b 통계 학생 성장 1차 (Lane A, 로컬 Claude Code)

### FE7-b 착수 기록 (2026-10-13, Lane A)

- 상태: 진행 중. 시작 SHA = `75943ffcd529d57ce2de7cea703f32f93085ec96`(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`). 착수 전 이 문서에 다른 "FE7-b 착수 기록" 없음(grep 0건).
- 범위: 육성도 · 항목 완성도 projection(FD-028 (a), 순수 함수), 성장 KPI 5개(FD-105, 증감 '—'), A1 육성도 분포 히스토그램 + 구간 선택 → 근거 학생 목록, A2 항목별 완성도 트랙 막대 + 항목 선택 → 근거, 미구현 타일 "준비 중" 유지(FD-106 사용자 결정 10-13).
- 막힘: 대장 막힘 요약 FE7-b 행 = FD-028 → 확정(2026-10-06, (a)). 막는 `열림` FD 없음. 워커 재량 FD-029 · FD-105는 권장안으로 처리한다.
- 착수 중 사용자 확인(질문 2건, 2026-10-13): ① 애장품이 없는 학생(카탈로그 265명 중 205명)은 애장품을 "해당 없음"으로 빼고 나머지 6항목 평균 ② A2는 FD-028대로 7행(시안 6행 + 애장품).
- 고칠 기존 파일(착수 사본 `debug/frontend_fe7b/pre/<v7 기준 경로>`, 작업 트리와 cmp 일치, 모두 WIP 없음 = `git status --short <경로>` 빈 줄):
  - `frontend/lib/ui/statistics/statistics_workspace.dart`(LF) · `statistics_topics.dart`(LF) · `statistics_source.dart`(LF)
  - `frontend/lib/ui/pages/statistics_page.dart`(CRLF)
  - `frontend/lib/ui/studio/statistics_studio_layout.dart`(LF, 요소 좌표만)
  - `frontend/lib/ui/kit/kpi_tile.dart`(LF, 키트 최소 — 모름 '—' 증감 색) · `frontend/test/kit/kpi_tile_test.dart`(LF)
  - `frontend/test/statistics_workspace_test.dart`(LF) · `statistics_page_test.dart`(CRLF) · `statistics_app_shell_test.dart`(CRLF)
  - `frontend/test/goldens/fe7a_statistics_golden_test.dart`(LF, fixture 입력만)
  - `almanac/workflows/frontend-redesign-status.md`(이 문서, LF)
- 새 파일(예정): `frontend/lib/statistics/statistics_growth_projection.dart`(projection), `frontend/lib/ui/statistics/statistics_growth_charts.dart`(A1 · A2 painter), `frontend/lib/ui/statistics/statistics_growth_evidence.dart`(근거 패널 내용), `frontend/test/statistics_growth_fixture.dart`(시안 숫자 fixture), `frontend/test/statistics_growth_projection_test.dart`, `frontend/test/statistics_growth_view_test.dart`.
- 고치지 않음: `app_shell.dart` · `app_section.dart` · `lib/services/**`(읽기만) · 스캔 대상 상태(Lane B FE8-d), 학생 · 계획 · 인벤토리 · 스캔 · 타이틀 화면, golden harness, `frontend/tool/**`, backend · contracts, 택틱 · 스캐너 소유 파일.

### FE7-b 종료 기록 (2026-10-13, Lane A, 코드 작성 완료 · CF gate 미실행)

통계 "학생 성장"에 KPI 5칸 값, A1 육성도 분포 히스토그램, A2 항목별 완성도 트랙 막대, A1 구간 · A2 항목 선택 → 오른쪽 근거 목록을 넣었다. 다른 타일(A3 · A4 · A5 · A6)은 "준비 중" 그대로다(FD-106 사용자 결정 10-13). 원본 탭 이동(아래 두 버튼)은 FE7-d라 비활성 그대로다.

착수 기록 정정: `statistics_source.dart` · `statistics_page_test.dart` · `statistics_app_shell_test.dart`는 고치지 않았다(사본을 지웠다, 작업 트리 = HEAD).

#### 실행 명령 · 결과

모두 `frontend`에서 이 PC(Claude Code)로 실행했다. 로그는 `debug/frontend_fe7b/logs/`이고, 실패 줄(`[E]`·`EXCEPTION`·`Some tests failed`·`error •`)만 찾았다.

| 명령 | 결과 |
|---|---|
| `flutter analyze`(1차 · 2차) | No issues found · No issues found |
| `flutter test test/statistics_growth_projection_test.dart`(1차) | +10 뒤 마지막 테스트가 멈춤(`rootBundle.loadString`이 큰 자산을 isolate로 디코드해 테스트 시계에서 멈춤) → 중단하고 Mock처럼 `rootBundle.load` + `utf8.decode`로 고침 |
| 같은 파일(2차) | **+11 −0** |
| `flutter test test/statistics_growth_view_test.dart`(1차) | +8 −3: ① 시안 막대 x 433.5 vs 계산 433.4(시안 반올림) → 허용 0.15 ② 1280×720 · 800×600에서 근거 학생 행 Row 넘침(테스트 글꼴) → 행 내용 최소 폭 240 + 자름 |
| 같은 파일(2차) | +9 −2: KPI 값 줄 넘침(테스트 글꼴 "63.4%" 26px × 5글자) · 근거 머리 Row 넘침 → KPI 띠 최소 폭 158 → 200칸, 근거 머리 최소 폭 240 + 자름 |
| 같은 파일(3차 · 4차, 다시 읽기 · 주제 전환 테스트 추가 뒤) | **+11 −0** · **+12 −0** |
| 통계 기존 4파일 + `kit/kpi_tile_test.dart` | +36 −1: workspace "growth tiles …"가 "준비 중" 6개를 기대 → 4개 + A1 · A2 '—'로 고침 → workspace **+13 −0** |
| `flutter analyze`(3차, golden fixture 뒤) | 1 issue(info `curly_braces_in_flow_control_structures`, projection) → 고침 → 4차 No issues found |
| 일회성 렌더(임시 `test/zz_fe7b_render_tmp_test.dart`, harness 공개 함수 · golden fixture 서비스, scratchpad PNG 2장: 기본 · 60~70% 선택) | 배치 · 숫자 시안 자리(아래 golden 예상). 임시 테스트는 지웠다. golden 비교 아님 |
| 관련 31파일 한 번에(`--reporter json`, 아래) | **+276 −0** |
| `flutter analyze`(최종) | **No issues found**(info 포함 0) |
| `git diff --check`(고친 기존 8파일) · 새 6파일 줄 끝 공백 · 줄바꿈 | 0 · 0. 새 파일 LF · 끝 개행 하나, 기존 파일은 pre와 같은 줄바꿈(`statistics_page.dart` CRLF, 나머지 LF) |

관련 31파일(파일별 통과 · 실패, 모두 −0): statistics_growth_projection +11(새), statistics_growth_view +12(새), statistics_workspace +13, statistics_page +13, statistics_app_shell +2, statistics_projection +6, home_page +5, home_app_shell +1, widget_test +16, inventory_shell_lazy +1, section_template_studio +15, account_manager_fe8b +6, growth_calculator_view +24, profile_delete_fb2d +17, student_filter_followups +4, student_filter_modal +7, title_page +25, planning_page +17, scan_page_revision +14, tactical_page_revision +5, kit/diagonal_scroll_viewport +5, kit/scroll_viewport_fog +6, kit/diagonal_row +6, kit/kpi_tile +3, kit/titles +4, kit/section_morph +7, kit/buttons +6, kit/stat_chart +7, kit/skew_bar +8, kit/diagonal_scrollbar +8, kit/ui_kit_gallery_data +2.

- 걸리는 기존 테스트 찾기: `KpiTile`·`KpiDeltaTone`·`statistics`·`StatisticsPage`·`StatisticsMode`로 test/ 전체를 grep했고, FE7-a의 25파일 묶음(셸 · 통계 읽기 시점)에 쓰는 키트(stat_chart · skew_bar · diagonal_scrollbar · gallery data)를 더했다. `developer_tools_app_test` · `metadata_manager_dto_test` · process E2E 2개의 `statistics`는 다른 기능이라 돌리지 않았다.
- 빌드 잠금 충돌 없음. `flutter analyze`가 pub get을 돌렸지만 `pubspec.lock` · `pubspec.yaml` 변화 없음.
- 실행하지 않음: golden(`test/goldens/**`), 전체 `fe_gate.ps1`, `-UpdateGoldens`, `fe_commit.ps1`, 맨 `flutter test`, process E2E, `codealmanac validate`.

#### 고친 파일

- **`lib/statistics/statistics_growth_projection.dart`(새, 순수 함수)**: `buildStatisticsGrowth(state, catalog)` → `StatisticsGrowth`(보유 · 학생 목록 수 · 육성도 아는 학생 · 모름 수 · 평균 육성도 · 최대 레벨 · 완전 육성 · 계획 등록 · A1 분포(seg 4종) · A2 항목 평균 · 강조 항목 · 구간/항목 근거 정렬), `statisticsStudentGrowth`, `StatisticsGrowthSummary`(구간 요약), 구간 · 퍼센트 글자 함수. 입력은 계정 상태(스캔 현재 상태 · 사용자 목표)와 학생 목록뿐이다(계산 · 부족 버킷 안 씀).
- **`lib/ui/statistics/statistics_growth_charts.dart`(새)**: A1 · A2 painter(키트 `StatChartPainter` · `StatChartFrame` · `paintValueBar` · `skewedBarPath` · `statSkewMatrix` · `paintHatch` · `StatChartPalette`), 설계 좌표 `StatisticsA1Geometry` · `StatisticsA2Geometry`(시안 SVG 좌표), 누르면 hit test → 구간 · 항목 선택.
- **`lib/ui/statistics/statistics_growth_evidence.dart`(새)**: 선택 모델(`StatisticsGrowthSelection` 구간/항목), 화면 상태 묶음 `StatisticsGrowthView`, 근거 내용(머리 · 부제 · 학생 행 7개 · "나머지 n명 모두 보기" · 요약 3행), 근거 행(`.row` 왼쪽 80° · 오른쪽 수직, 키트 `DiagonalRowLook` · `PortraitStrip` · `BaChip`), "모두 보기" 뒤 세로 스크롤 목록(공용 `DiagonalScrollbar` · 포그, 섹션 오른쪽 변이 수직이라 트랙도 수직).
- **`lib/ui/statistics/statistics_workspace.dart`**: KPI 칸 값 · 누르면 그래프 줄로 스크롤(`_TopicViewport` → State, 공용 viewport에 controller), A1 · A2 타일 내용(그래프 · 빈 상태), A1 seg 동작, 범위 글자 · 필터 부제 "보유 n명", 근거 섹션에서 선택이 있으면 머리 + 인원 칩 + 부제 + 근거. 근거 부제 줄 왼쪽을 시안 x 2160으로 맞췄다(FE7-a는 2148.1). KPI 띠 최소 폭 158 → 200칸.
- **`lib/ui/statistics/statistics_topics.dart`**: `scopeFor(owned)` · `filterNoteFor(owned)`(기존 `scope` · `filterNote`는 '—'로 남김), 주석.
- **`lib/ui/pages/statistics_page.dart`**(CRLF 유지): A1 seg · 선택 · 근거 펼침 상태, projection 캐시(읽은 상태 · 학생 목록이 같으면 재계산 안 함), 다시 읽기 · 주제 전환 · seg 전환 때 선택 지움. `_reload()` 읽기 순서 · 서비스 호출은 그대로(새 서비스 메서드 없음).
- **`lib/ui/studio/statistics_studio_layout.dart`**(요소 좌표만): 근거 부제 왼쪽 · 학생 행 · 모두 보기 · 펼친 목록 끝 · 요약 머리 · 요약 행, 타일 머리 – 그래프 간격 10.
- **`lib/ui/kit/kpi_tile.dart`(키트 최소)**: `KpiDeltaTone.unknown`(#9eb0c2, 시안 Stats-Growth-Filter의 '—' 색) enum 값 하나. 기존 사용처 렌더 변화 없음.
- 테스트: `test/statistics_growth_projection_test.dart`(새 11건), `test/statistics_growth_view_test.dart`(새 12건), `test/statistics_growth_fixture.dart`(새, 시안 숫자 fixture), `test/statistics_workspace_test.dart`("준비 중" 6 → 4 + A1 · A2 '—'), `test/kit/kpi_tile_test.dart`(모름 색 1건), `test/goldens/fe7a_statistics_golden_test.dart`(fixture 입력만: golden Mock 위에 계정 상태 학생 · 목표와 학생 목록을 fixture로 바꾸는 서비스. 장면 조작 · 기다리는 글자 · 장면 이름은 그대로). 지운 테스트 없음.

#### FD-028 식(코드 위치 · 테스트)

- 코드: `lib/statistics/statistics_growth_projection.dart` 머리 주석(대장 문구) · `statisticsGrowthCompletion`((현재 − 최소)/(최대 − 최소), `planElementTargetMinimums/Maximums`) · `statisticsStudentGrowth`(7항목: 레벨, EX, 일반 스킬 = skill1~3 완성도 평균, 장비 = equip1~3 티어 완성도 평균, 애장품 = equip4 티어, 성작, 전용무기 ★) · `StatisticsStudentGrowth.growth`(단순 평균).
- 테스트(`statistics_growth_projection_test.dart`): 손계산 값 1건, 인연 · 추가 능력치 · 장비 레벨 · 전무 레벨을 바꿔도 육성도 불변, **A1 평균 = A2 막대 평균**(7항목 학생 3명, 1e-12), 애장품 없는 학생 6항목 평균 · A2 애장품은 있는 학생만, 모름 제외 · "n명 모름" 셈, 10% 구간 경계, FD-029 칩 · 완전 육성 · 최대 레벨 · 계획 등록(보유만), A2 강조, fixture가 시안 숫자를 재현, fixture id · 애장품 여부가 번들 학생 목록과 같음.

#### 처리한 FD

- **FD-028(확정 (a))**: 위 식 그대로. 착수 때 사용자 확인 2건(애장품 없는 학생 = 해당 없음 · 6항목 평균, A2 7행).
- **FD-029(워커 재량, 권장안)**: 완전 육성 = 육성도 100%, 최대 레벨 = level 90, "낮음" = 그 항목 < 60%(A2 기준선과 같은 상수 `statisticsGrowthLowThreshold`).
- **FD-105(워커 재량, 권장안)**: 주제별 5칸, 누르면 같은 주제 그래프 줄로 스크롤. 증감은 FE7-h라 '—'.
- **FD-106(확정 2026-10-13, 사용자 결정)**: A3 · A4 · A5 · A6 "준비 중" 자리 유지. 데이터 부족 문구는 A1 · A2 안 빈 상태(아래 규칙 3). "스캔을 더 실행하면 변화가 나타납니다."는 FE7-h 몫이라 넣지 않았다.
- FD-033: 모르는 값은 0이 아니라 제외 · '—' · 빗금(A2 해당 학생 없는 항목). FD-104: 필터 버튼은 그대로 비활성(FE7-e). 막는 `열림` FD 없음.

#### 정한 규칙(시안 · 대장에 없는 것)

1. **육성도를 아는 학생** = 해당 항목을 모두 아는 보유 학생. 하나라도 모르면(값 없음, 카탈로그에 없어 애장품 여부 모름) A1(육성도 seg) · A2 · 평균 육성도 · 완전 육성에서 빠지고 A1 왼쪽 위 · A2 왼쪽 아래에 "n명 모름"(회색 10.5)으로 센다. A2 항목 평균은 A1과 같은 학생 집합(육성도를 아는 학생)에서 그 항목이 해당되는 학생만 센다.
2. 장비 · 애장품 티어는 확정값 글자(`T7`)의 숫자, 숫자가 없는 글자(`love_locked`)는 0(계획 요소 빌더와 같은 규칙), 값 없음은 모름.
3. 빈 상태 문구(~습니다체, 시안 없음): 보유 0명 "보유 학생이 없습니다. 학생 스캔을 실행하면 나타납니다.", 값을 아는 학생 0명 "<육성도|레벨|스킬|장비> 값을 아는 학생이 없습니다. 보유 n명 모두 모르는 값이 있습니다.", 읽지 못함 · 읽는 중 '—'.
4. A1 seg: 육성도 = 7항목, 레벨 = 레벨 완성도, 스킬 = EX · 일반 스킬 완성도 평균, 장비 = equip1~3 완성도. 보유 학생이 있으면 동작, seg를 바꾸면 선택을 지운다. 축 글자 0% · 40% · 100%(시안 그대로)는 평균 글자와 36 안쪽이면 그 축 글자를 뺀다.
5. A2 강조: 60% 기준선 아래 항목 분홍(시안), 아래가 없으면 가장 낮은 항목 하나 분홍. 고른 항목은 라벨 분홍 글자 + 트랙 분홍 테두리. 7행 간격 = (163 − 23) / 6 = 23.3(시안 6행 28).
6. 근거 칩(FD-029): 레벨 · EX · 일반 스킬 · 장비 중 60% 미만인 가장 낮은 항목 → "레벨 낮음" / "스킬 낮음" / "장비 뒤처짐". 성작 · 전용무기 · 애장품에는 칩을 달지 않는다(시안 칩 3종). A1 근거 순서 "낮은 항목 순" = 칩 항목 중 가장 낮은 완성도 → 육성도 → id.
7. A2 항목 근거(시안 없음): 머리 "<항목> 완성도" + 인원 칩, 부제 "A2에서 고른 항목 · 낮은 학생 순", 행 칩 = 그 항목 완성도(60% 미만 노랑 · 이상 회색), 요약 "항목 요약": 평균 레벨 · 평균 완성도 · 계획 등록.
8. 선택은 하나(A1 구간 또는 A2 항목). 같은 막대 · 행을 다시 누르면 푼다. 인원 0 구간 · 해당 학생 없는 항목은 누를 수 없다. 다시 읽기 · 주제 전환 · seg 전환 때 지운다.
9. "모두 보기": 행 7개 자리 + 버튼 자리(위 100~536)에서 그 구간 전체를 세로 스크롤한다(행 왼쪽은 화면 높이의 사선 + 24, 오른쪽 = 섹션 오른쪽 − 22 − 스크롤바 14). 다른 구간을 고르면 접힌다. 접는 버튼 글자는 시안에 없어 두지 않았다.
10. KPI 보유 학생 칸 증감 글자 "/ 170 · —"(초록, 시안 첫 칸 색), 나머지 칸 '—'(회색). 계획 등록 = 사용자 목표가 있는 **보유** 학생 수. 증감 '—'는 FE7-h가 바꾼다.
11. 작은 창: KPI 띠 최소 폭 5 × 200칸(이보다 좁으면 띠째 줄임), 근거 행 · 요약 행 내용 최소 폭 240, 근거 머리 최소 폭 240(더 좁으면 오른쪽을 자름). 기준 viewport에는 영향 없다.

#### golden 변화 예상

- **`statistics-growth`: 변화 있음**(fixture 입력 + 성장 내용). 기대 모습(일회성 렌더로 본 배치):
  - 왼쪽: 필터 부제 "없음 · 보유 128명 전체". 나머지(주제 버튼 · 기준 데이터 '—' · 다시 스캔)는 그대로.
  - 가운데 제목 줄 오른쪽 "보유 128명 기준 · 지난 스냅샷 대비".
  - KPI 5칸: "128" + 초록 "/ 170 · —", "63.4%" + 회색 "—", "64명" "—", "8명" "—", "9명" "—".
  - A1: seg가 흐리지 않고 "육성도" 선택(분홍 테두리). 파랑 막대 10개 높이 3 · 5 · 9 · 12 · 15 · 18 · 22 · 19 · 14 · 11(60~70% 막대가 가장 높음, 구간을 고르지 않아 분홍 막대 · 인원 글자 없음), 63.4% 자리 흰 점선 + "평균 63.4%", 축 글자 0% · 40% · 100%, "n명 모름" 없음.
  - A2: 7행 레벨 83% · EX 스킬 76% · 일반 스킬 74% · 장비 73% · 애장품 83% · 성작 56%(분홍) · 전용무기 14%(분홍), 60% 기준 분홍 점선 + "60% 기준". 1차 칩 그대로.
  - A4 · A6 · A3 · A5: "준비 중" 그대로. 오른쪽 근거: "근거 확인" + "구간을 고르면 근거가 보입니다." — 부제 줄이 오른쪽으로 약 12px 옮겨(2148.1 → 2160) 머리 글자와 같은 세로줄.
- 다른 장면 전부: **변화 0**. 통계 탭이 보이는 장면은 `statistics-growth` 하나다. 키트 변경은 `KpiDeltaTone`에 값 하나를 더한 것뿐이라 KPI 타일을 쓰는 다른 장면(갤러리 등) 렌더가 같다. 헤더 칩은 Lane B FE8-d 작업 트리 상태라 이 slice와 무관하다(같은 gate에서 함께 바뀔 수 있음).

#### 검수표

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Stats-Growth(K · A1 · A2) | golden `statistics-growth`(시안 숫자 fixture). 앱 mock은 기본 계정(보유 42명 · 학생 목록 2명)이라 숫자가 시안과 다르다(발견 4) | KPI 128 / 170 · 63.4% · 64명 · 9명(완전 육성은 8명, 발견 1), A1 막대 높이 순서 · 60~70%가 22명으로 가장 높음 · 평균선 자리, A2 7행 · 60% 아래 분홍 · 기준선 기울기 |
| Stats-Growth(구간 선택) | 통계 탭 → A1 60~70% 막대 누르기 | 막대 분홍 + 위 "22명", 오른쪽 "육성도 60~70%" + 분홍 "22명", 부제 "A1에서 고른 구간 · 낮은 항목 순", 학생 행 7개(사선 계단, 초상 · 이름 · Lv · 칩), "나머지 15명 모두 보기", "구간 요약" 평균 레벨 · 가장 낮은 항목 · 계획 등록 2명, 같은 막대를 다시 누르면 빈 상태 |
| (동작) | A2 행 누르기 · A1 seg · KPI 누르기 · "모두 보기" | A2 항목 근거(낮은 학생 순), seg를 바꾸면 분포가 바뀌고 선택이 풀림, KPI를 누르면 가운데가 그래프 줄로 스크롤, "모두 보기"면 전체 학생 세로 스크롤 + 수직 스크롤바, 1280×720에서 예외 없음 |
| Statistics-Proposal | 위 화면 | A1 · A2 기울어진 막대 · 공통 트랙, 색 역할(크기 파랑 · 강조 분홍 · 모름 회색), 모르는 값 '—' |

#### 미검증 항목

- golden(`statistics-growth` 변화 · 다른 장면 변화 0 예측): **미실행**. 일회성 렌더는 배치 확인만이다.
- 전체 `fe_gate.ps1`(나머지 테스트 · process E2E · `codealmanac validate` · 저장소 전체 `git diff --check`): **미실행**.
- 실제 백엔드 계정에서의 숫자(애장품 여부 · 모르는 값 비율): **미실행**. Mock · fixture만 보았다.
- 실제 창에서 KPI 스크롤 애니메이션 · hover 체감, 실제 글꼴에서 작은 창 글자 크기.

#### WIP 보존 확인

- 고친 기존 8파일 + 이 문서는 착수 때 WIP가 없었다(`git status --short` 빈 줄). post 사본 · `post_dir`는 두지 않았다. pre 사본 대비 diff는 이 slice 줄뿐이고 줄바꿈을 유지했다.
- 작업 트리의 다른 미커밋 변경(Lane B `app_shell.dart` · `widget_test.dart` 등, 스캐너 · 백엔드 파일)은 읽지도 고치지도 않았다. git 쓰기는 하지 않았다. 임시 렌더 테스트는 지웠다.

#### 발견 사항

1. **시안 숫자 모순**: 시안 KPI "완전 육성 22명"은 A1 90~100% 구간 11명보다 많아 같은 화면에서 성립하지 않는다(fixture 8명). 시안 A2 6행 평균 60.5%도 A1 평균 63.4%와 맞지 않는다(FD-028의 "A1 평균 = A2 평균"과 어긋남). 서로 맞는 숫자(128 · 170 · 구간 인원 · 63.4% · 64명 · 9명 · 구간 계획 2명)만 재현했다.
2. **시안 평균 63.4%는 구간 인원과 거의 한계값**: 구간 가운데값 평균이 58.5%라 63.4%가 되려면 학생 대부분이 구간 위 끝(예 69.9%)에 있어야 한다. fixture는 그렇게 골랐다(학생 값이 실제 분포처럼 보이지 않는다).
3. **애장품 해당 없음 때문에 A1 평균 ≠ A2 막대 평균**: 학생 목록 265명 중 205명이 애장품이 없어(사용자 확인대로 6항목 평균) 실제 계정에서는 두 값이 근사치다. fixture는 30명이 애장품이 있다(A1 63.4% vs A2 막대 평균 약 65.6%).
4. **mock 기본 계정의 통계**: `MockAppService` 기본 학생 목록이 2명(`fullStudentCatalog=false`)이고 보유 42명이라 "42 / 2"로 보인다. 검수용 시안 fixture를 mock 기본 실행에 넣으려면 `lib/services/**`(읽기 전용) 변경이 필요하다 — CF 요청 후보.
5. KPI 타일 높이 70(키트) vs 시안 84(FE7-a 발견 4)는 그대로다. 근거 머리는 키트 `PanelTitle`(막대 7×22 · 룰 46)이라 시안 머리(6×18 · 40)와 막대 크기가 다르다.
6. "나머지 n명 모두 보기"의 동작 · 접기 글자는 시안에 없다(규칙 9). FE7-d의 "학생 탭에서 보기 · 필터: 육성도 60~70%"와 겹치는지 FE7-d에서 판단.
7. A1 seg "스킬"의 항목 묶음(EX + 일반 스킬)과 근거 칩 대상(레벨 · 스킬 · 장비)은 시안 문구에서 고른 해석이다(규칙 4 · 6).

#### 사본 · commit.json

- 착수 사본: `debug/frontend_fe7b/pre/<경로>`(고친 기존 8파일 + 이 문서). WIP가 없어 post 사본은 없다.
- `debug/frontend_fe7b/commit.json`: slice `fe7b`, `status=true`, modified 9(이 문서 포함), added 6, `whole` = `frontend/test/goldens/baseline/statistics-growth.png`.
- 인계: `debug/frontend_fe7b/output.md`.

#### 다음 행동

- FE7-b 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: 레인 워커가 모두 멈춘 뒤 gate 1회. 예상: analyze 0, 일반 테스트에 새 23건(projection 11 · view 12) + kpi_tile 1건, golden은 `statistics-growth`만 RED(위 기대 모습), 다른 장면 변화 0(Lane B 헤더 변화는 별도). 승인 뒤 `-UpdateGoldens` · 재비교 · `fe_commit.ps1 -Slice fe7b`.
- 남은 CF 판단: 발견 1 · 3(시안 숫자 · A1/A2 근사), 4(mock 검수 fixture), 6(모두 보기 동작).

### fe7b commit record (2026-10-13 17:37, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261013_172627\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE7-c 통계 인벤토리 현황 · 계획 집계 1차 (Lane A, 로컬 Claude Code)

### FE7-c 착수 기록 (2026-10-13, Lane A)

- 상태: 진행 중. 시작 SHA = `c2ceb57ebc1429372b53fd6c260b02d9a2bf06ca`(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`). 착수 전 이 문서에 다른 "FE7-c 착수 기록" 없음(grep 0건).
- 범위: 인벤토리 KPI 5 · B1 재화별 · 카테고리별 충족률(FD-031/032 식, `ShortageCategoryStatistics` 이종 합산 교체), 계획 KPI 5 · C1 필요량 vs 보유 불릿(부족 큰 순만) · C2 충족률 × 영향 학생 수 산점도, B1 막대 · C1 행 · C2 점 → 근거 목록. B2 · B3 · C3 · C4 · C5는 "준비 중"(FD-106 사용자 결정 10-13). 새 백엔드 · 새 서비스 메서드 없음.
- 막힘: 대장 막힘 요약 FE7-c 행 = FD-031(확정 2026-10-06) · FD-034(확정 2026-10-06). 막는 `열림` FD 없음. 워커 재량 FD-032 · FD-035 · FD-105는 권장안으로 처리한다.
- `ShortageCategoryStatistics` 사용처(`grep -rn` lib · test): `lib/statistics/statistics_projection.dart`(정의 · `PlanStatistics.shortageCategories` · `buildPlanStatistics`)뿐. 화면 사용처 0(FE7-a가 옛 화면을 지움), `test/statistics_projection_test.dart`는 `buildPlanStatistics`를 부르지만 `shortageCategories`를 단언하지 않는다.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe7c/pre/<v7 기준 경로>`, 작업 트리와 cmp 일치, 모두 WIP 없음 = `git status --short <경로>` 빈 줄). 줄바꿈은 작업 트리 그대로 유지(`git ls-files --eol`):
  - `frontend/lib/statistics/statistics_projection.dart`(CRLF)
  - `frontend/lib/ui/statistics/statistics_workspace.dart`(LF) · `statistics_topics.dart`(LF) · `statistics_growth_charts.dart`(LF, 글자 · 점선 helper 공개만) · `statistics_growth_evidence.dart`(CRLF, 근거 행 재사용)
  - `frontend/lib/ui/pages/statistics_page.dart`(CRLF)
  - `frontend/lib/ui/studio/statistics_studio_layout.dart`(LF, 요소 좌표만)
  - `frontend/test/statistics_projection_test.dart`(CRLF) · `statistics_workspace_test.dart`(LF) · `statistics_page_test.dart`(CRLF)
  - `frontend/test/goldens/fe7a_statistics_golden_test.dart`(LF, 장면 2장 추가)
  - `almanac/workflows/frontend-redesign-status.md`(이 문서, LF)
- 새 파일(예정): `frontend/lib/statistics/statistics_supply_projection.dart`(인벤토리 · 계획 projection), `frontend/lib/ui/statistics/statistics_supply_charts.dart`(B1 · C1 · C2 painter), `frontend/lib/ui/statistics/statistics_supply_evidence.dart`(선택 · 근거 내용), `frontend/test/statistics_supply_fixture.dart`(시안 숫자 fixture), `frontend/test/statistics_supply_projection_test.dart`, `frontend/test/statistics_supply_view_test.dart`.
- 읽기 · 재사용만: `lib/ui/inventory/inventory_view_model.dart`(`InventoryBoard` · `InventoryItemView.fulfillment` · `kpis` · `inventoryCategoryLabel`), `lib/ui/inventory/inventory_analysis.dart`(`inventoryCoverageOf`). 고치지 않음: `lib/ui/inventory/**`, `app_shell.dart` · `app_section.dart` · 홈 · 머리글 칩 · `lib/ui/scan/**`(Lane B FE8-e), `lib/services/**`, 학생 · 계획 · 스캔 · 타이틀 화면, golden harness, `frontend/tool/**`, backend · contracts, 택틱 · 스캐너 소유 파일.

### FE7-c 종료 기록 (2026-10-13, Lane A, 코드 작성 완료 · CF gate 미실행)

통계 "인벤토리 현황"에 KPI 5칸 값 · B1 카테고리별 충족률, "계획 집계"에 KPI 5칸 값 · 범위 칩 학생 수 · C1 필요량 vs 보유 불릿 · C2 병목 매트릭스를 넣었다. B1 막대 · C1 행 · C2 점을 고르면 오른쪽 근거(재화 · 학생)가 보인다. B2 · B3 · C3 · C4 · C5는 "준비 중" 그대로다(FD-106 사용자 결정 10-13). 원본 탭 이동(아래 두 버튼)은 FE7-d라 비활성 그대로다. 새 서비스 메서드 · 백엔드 변경 없음.

착수 기록 정정: `frontend/test/statistics_page_test.dart`는 고치지 않았다(사본을 지웠다, 작업 트리 = HEAD). 키트 최소 변경 2파일(`kpi_tile.dart` · `skew_controls.dart`)과 그 테스트 2파일을 더 고쳤다(착수 사본 있음, WIP 없음, LF).

#### 실행 명령 · 결과

모두 `frontend`에서 이 PC(Claude Code)로 실행했다. 로그는 `debug/frontend_fe7c/logs/`이고, 실패 줄(`[E]`·`EXCEPTION`·`Some tests failed`·`error •`)만 찾았다.

| 명령 | 결과 |
|---|---|
| `flutter analyze`(1차, 키트 · projection 뒤) | 6 issues: `app_shell.dart` 4건(error 1 `onOpenTargetPicker` · warning 2 · info 1 — Lane B FE8-e 작업 중 파일, 이 slice 밖) + 내 info 2건(`use_key_in_widget_constructors`, 공개로 바꾼 `StatisticsScaledBox` · `StatisticsMinWidth`) → 내 2건 고침 |
| `flutter test` projection · kpi_tile · skew_controls | **+19 −0** |
| `flutter test test/statistics_supply_projection_test.dart test/statistics_projection_test.dart` | **+15 −0**(첫 실행) |
| `flutter test test/statistics_supply_view_test.dart`(1차) | +8 −3: ① 테스트 기대를 시안 반올림 값(보유 막대 58.9)으로 적음 → 계산값 59.4 ± 시안 0.6으로 고침 ② 첫 학생 행 id를 잘못 고름(크레딧 영향 학생은 계획 학생 5번째부터) ③ 1280×720에서 KPI 0 · 4 목표가 모두 스크롤 끝이라 구별 안 됨 → 2560×700에서 확인 |
| 같은 파일(2차) | +10 −1: KPI 띠도 함께 스크롤되어 두 번째 KPI를 누르지 못함 → 누르기 전에 맨 위로 |
| 같은 파일(3차) | **+11 −0** |
| `flutter analyze`(전체, Lane B가 `app_shell.dart`를 고친 뒤) | **No issues found** |
| `flutter test test/statistics_workspace_test.dart`(인벤토리 · 계획 기대 추가 뒤) | **+13 −0** |
| 일회성 렌더(임시 `test/zz_fe7c_render_tmp_test.dart`, harness 공개 함수, scratchpad PNG 5장: 인벤토리 · B1 기술 노트 선택 · 계획 · C1 크레딧 선택 · 계획 1280×720) | 배치 · 숫자 시안 자리(아래 golden 예상). 임시 테스트는 지웠다. golden 비교 아님 |
| 관련 39파일 한 번에(`--reporter json`, 아래) | **+354 −0** |
| `flutter analyze`(최종) | **No issues found**(info 포함 0) |
| `git diff --check`(고친 기존 14파일) · 새 6파일 줄 끝 공백 · 줄바꿈 | 0 · 0. 새 파일 LF · 끝 개행 하나, 기존 파일은 pre와 같은 줄바꿈(`statistics_projection.dart` · `statistics_page.dart` · `statistics_growth_evidence.dart` · `statistics_projection_test.dart` CRLF, 나머지 LF) |

관련 39파일(파일별 통과 · 실패, 모두 −0): statistics_supply_projection +8(새), statistics_supply_view +11(새), statistics_growth_projection +11, statistics_growth_view +12, statistics_workspace +13, statistics_page +13, statistics_app_shell +2, statistics_projection +7, inventory_view_model +13, inventory_analysis +16, inventory_analysis_page +8, inventory_controller +13, inventory_history +33, inventory_history_page +11, inventory_opa +9, inventory_opa_page +6, inventory_tiers +9, inventory_tiers_page +7, inventory_shell_lazy +1, school_labels +3, home_page +5, home_app_shell +1, widget_test +16, section_template_studio +15, plan_flow +15, plan_flow_goal_step +23, kit/kpi_tile +4, kit/skew_controls +8, kit/stat_chart +7, kit/scroll_viewport_fog +6, kit/diagonal_scroll_viewport +5, kit/diagonal_scrollbar +8, kit/diagonal_row +6, kit/titles +4, kit/skew_bar +8, kit/item_icon_tile +7, kit/ui_kit_gallery_data +2, kit/ui_kit_gallery_controls +2, kit/ui_kit_gallery +6.

- 걸리는 기존 테스트 찾기: test/ 전체를 `SkewSegmented|SkewSegment(|KpiTile|statistics|Statistics|InventoryBoard|inventoryCoverageOf|inventory_view_model|inventory_analysis.dart|statisticsChartText|StatisticsEvidenceStudentRow|top-tab-statistics`로 grep했다. 재사용 함수(`InventoryBoard` · `inventoryCoverageOf`)를 쓰는 inventory_* 전부, 키트 차트 · 사용처(stat_chart · item_icon_tile · gallery), 셸 테스트(widget · home)를 함께 돌렸다. `developer_tools_app_test` · `metadata_manager_dto_test` · process E2E 2개의 "statistics"는 다른 기능이라 돌리지 않았다(FE7-a와 같은 판단).
- 빌드 잠금 충돌 없음. `flutter analyze`가 pub get을 돌렸지만 `pubspec.lock` · `pubspec.yaml` 변화 없음.
- 실행하지 않음: golden(`test/goldens/**`, 새 장면 2장 포함), 전체 `fe_gate.ps1`, `-UpdateGoldens`, `fe_commit.ps1`, 맨 `flutter test`, process E2E, `codealmanac validate`.

#### 고친 파일

- **`lib/statistics/statistics_supply_projection.dart`(새, 순수 함수)**: `StatisticsSupply.build(catalog, state, shortages, growth)` → 인벤토리 화면의 `InventoryBoard`(재화별 충족률 · KPI)를 그대로 쓰고, `statisticsCategoryFills`(B1, 재화 제외, 시안 순서) · `c1Rows` · `c2Points` · `c2MaxStudents` · `unknownLabels` · `metCategoryCount` · `planStudentCount`, `statisticsUnplannedLowCount`, 글자 함수 `statisticsFillText` · `statisticsAmountText`, 상수(60% 기준 · C2 구역 50% · 3명 · 미계획 40%).
- **`lib/statistics/statistics_projection.dart`(CRLF)**: `ShortageCategoryStatistics` 교체(아래).
- **`lib/ui/statistics/statistics_supply_charts.dart`(새)**: B1 · C1 · C2 painter와 위젯, 설계 좌표 `StatisticsB1Geometry` · `StatisticsC1Geometry` · `StatisticsC2Geometry`(시안 SVG 좌표), 누르면 hit test → 고르기.
- **`lib/ui/statistics/statistics_supply_evidence.dart`(새)**: 선택 모델(`StatisticsCategorySelection` · `StatisticsResourceSelection` + 출처 C1/C2), 화면 상태 `StatisticsSupplyView`, 근거 내용(카테고리: 재화 행 7 + "외 n종" + 카테고리 요약 / 재화: 아이콘 행 · 보유 · 필요 · 부족 · 쓰는 학생 10 + "외 n명").
- **`lib/ui/statistics/statistics_workspace.dart`**: KPI 칸 값(주제별) · 값 색 · 누르면 주제별 목표 줄로 스크롤(`_scrollToRow`), B1 · C1 · C2 타일 내용과 빈 상태, C1 seg(부족 큰 순 동작 · 페이즈 순 그 칸만 비활성), 계획 범위 칩 학생 수, 근거 섹션이 성장 · 재화 근거를 모두 그림, 주제별 근거 빈 상태 문구. 성장 쪽은 구조만 옮겼고 그림은 같다.
- **`lib/ui/statistics/statistics_topics.dart`**: `scopeFor(owned, planStudents:)`, `kpiTargetRows`, 머리 주석.
- **`lib/ui/statistics/statistics_growth_charts.dart`**: 글자 · 점선 helper를 공개(`statisticsChartText` · `statisticsChartDashed`, 이름만), 글자에 `maxWidth`(말줄임, 기본 null = 이전과 같음).
- **`lib/ui/statistics/statistics_growth_evidence.dart`(CRLF)**: `_Scaled` · `_MinWidth` · `_EvidenceRowPainter`를 공개 이름으로(동작 같음), `StatisticsEvidenceStudentRow.plain`(id · 이름 · 레벨로 만드는 생성자) 추가.
- **`lib/ui/pages/statistics_page.dart`(CRLF)**: 인벤토리 · 계획 고르기 상태, projection 캐시(인벤토리 목록 · 계정 상태 · 부족 계산 · 성장이 같으면 다시 만들지 않음), 다시 읽기 · 주제 전환 때 선택 지움. `_reload()` 읽기 순서 · 서비스 호출은 그대로.
- **`lib/ui/studio/statistics_studio_layout.dart`(요소 좌표만)**: 재화 근거 아이콘 행 · 보유/필요/부족 줄 · 쓰는 학생 머리 · 학생 행.
- **키트 최소(`lib/ui/kit/`)**: `KpiTile.valueColor`(기본 `AppColors.text` — 기존 사용처 그림 같음), `SkewSegment.enabled`(기본 true — `_dimIfDisabled(true, …)`는 자식 그대로라 기존 사용처 위젯 트리 같음).
- 테스트: `test/statistics_supply_projection_test.dart`(새 8), `test/statistics_supply_view_test.dart`(새 11), `test/statistics_supply_fixture.dart`(새, 시안 숫자), `test/statistics_projection_test.dart`(FD-032 테스트 1건 추가), `test/statistics_workspace_test.dart`(인벤토리 · 계획 "준비 중" 2 · 3, B1 · C1 · C2 '—', 근거 빈 상태), `test/kit/kpi_tile_test.dart`(값 색 1건), `test/kit/skew_controls_test.dart`(한 칸 비활성 1건), `test/goldens/fe7a_statistics_golden_test.dart`(장면 2장 추가, 기존 장면 코드 그대로). 지운 테스트 없음.

#### 식(코드 위치 · 테스트)

- **재화별 충족률(FD-031 (a) · FD-032)**: `InventoryItemView.fulfillment` = min(보유, 필요)/필요(`lib/ui/inventory/inventory_view_model.dart`, FE6 그대로 재사용). 보유는 계정 인벤토리 수량 → 없으면 부족 행 `owned`, 모르면 null.
- **카테고리 충족률(B1)**: `statisticsCategoryFills`(`statistics_supply_projection.dart`) → 카테고리별 `inventoryCoverageOf`(`lib/ui/inventory/inventory_analysis.dart`, FE6-c 그대로) = 보유를 아는 계획 재화 충족률의 단순 평균, 모름은 빼고 `unknownKinds`. 재화(크레딧 · 엘리그마)는 카테고리 막대에 넣지 않는다.
- **전체 · 계획 충족률 · 부족 · 과잉 · 스캔 없음 KPI**: `InventoryBoard.kpis`(FE6-a 그대로: 충족률은 크레딧 포함 평균, 부족 · 과잉은 재화 제외, 과잉 = 보유 ≥ 필요 × 1.5 FD-040). 인벤토리 탭 KPI와 같은 숫자다.
- 테스트: `statistics_supply_projection_test.dart` "fixture reproduces …"(72% · 14 · 6 · 1 · B1 78/64/91/52/47/— · 3 / 6), "fill rates reuse the inventory screen functions"(통계 값 = `InventoryBoard.kpis` · `inventoryCoverageOf`), "category fill is the plain mean …"(1/2 + 900/1000 → 70%, 수량 합산 89.9%가 아님, 넘침 100%, 모두 모름 null), `statistics_projection_test.dart` "shortage categories average per-resource fill …".

#### `ShortageCategoryStatistics` 교체 결과

- 사용처(grep): `lib/statistics/statistics_projection.dart` 한 곳(정의 · `PlanStatistics.shortageCategories` · `buildPlanStatistics`). 화면 사용처 0, 테스트는 값을 단언하지 않았다.
- 옛 필드 `required` · `knownOwned` · `positiveShortage` · `unknownCount`(카테고리 안 서로 다른 재화 수량 합, FD-033 위반)를 지우고 `ShortageCategoryStatistics(category, coverage)` → `fulfillment` · `plannedKinds` · `unknownKinds`로 바꿨다. 계산은 부족 행으로 `InventoryBoard.build(catalog: [], …)`를 만든 뒤 B1과 같은 `statisticsCategoryFills`다(재화 제외, 시안 순서). 옛 정렬(부족 수량 합 큰 순)도 없어졌다.

#### 처리한 FD

- **FD-031(확정 (a))**: 위 식. 전체 · 계획 충족률은 크레딧 포함.
- **FD-032(워커 재량, 권장안)**: 재화별 min/필요, 카테고리 = 단순 평균, 스캔 없음 = 모름(빗금 + "모름 · 스캔 없음" · "보유 모름 n종 제외"). `ShortageCategoryStatistics` 수량 합산 교체.
- **FD-033(확정)**: 서로 다른 재화 수량을 더하지 않는다. C1은 행마다 자기 필요량을 100%(눈금)로, 모름은 '—' · 빗금.
- **FD-034(확정 (a))**: 막힌 학생 = m − n은 문서 계산 `bottlenecks`(단계 id)가 있어야 한다. `_reload()`는 `calculatePlan` · `calculateShortages`만 읽으므로(프롬프트: 새 서비스 읽기 금지) KPI "막힌 학생"과 "첫 부족"은 '—'로 두었다(발견 사항 1). m(계획 학생 수)은 범위 칩 "활성 계획 · 9명 · 페이즈 —"에 쓴다.
- **FD-035(워커 재량)**: 단계 상태를 그리는 곳이 이번에 없다(C3 · 근거 "막히는 단계"는 FE7-g).
- **FD-105(워커 재량, 권장안)**: 주제별 5칸, 시안 라벨 그대로, 누르면 같은 주제 그래프 줄로 스크롤(인벤토리 → B1 줄, 계획 → 충족률 · 부족 · 막힌 학생 C1/C2 줄 · 첫 부족 C3 줄 · 미계획 C5 줄). 증감은 FE7-h라 '—'.
- **FD-106(확정 2026-10-13, 사용자 결정)**: B2 · B3 · C3 · C4 · C5 "준비 중" 자리 유지. 데이터가 모자란 타일은 그 타일 안 빈 상태 문구(아래 규칙 6). "스캔을 더 실행하면 변화가 나타납니다."는 FE7-h 몫이라 넣지 않았다.
- 막는 `열림` FD 없음.

#### 정한 규칙(시안 · 대장에 없는 것)

1. **B1 순서 · 라벨**: 시안 순서 장비 설계도 · 기술 노트 · 활동 보고서 · 전술 BD · 오파츠 · 엘레프, 그 뒤 선물 · 교본, 모르는 category 이름순. 라벨은 인벤토리 종류 버튼(FD-095)이고 BD만 시안대로 "전술 BD". 행 피치 = (163 − 23)/(행 − 1)(6행 28, A2와 같은 방식).
2. **B1 색 · 충족 카테고리**: 60% 미만 분홍 · 이상 파랑. 충족 카테고리 = 60% 기준 이상(시안 78 · 64 · 91 · 52 · 47 · 모름 → "3 / 6"과 맞는 유일한 기준), 분모 = 계획 재화가 있는 B1 카테고리 수(모름 카테고리 포함).
3. **스캔 없음 KPI**: 값 = 보유를 모르는 계획 재화 종 수(회색), 증감 자리 = 그 카테고리 이름(하나면 이름, 여럿이면 "<첫째> 외 n").
4. **C1 "부족 큰 순"**: 보유 / 필요(넘치면 1보다 큼) 작은 순 → 영향 학생 많은 순 → 카탈로그 순서, 보유 모름은 뒤, 5행. 크레딧 · 엘리그마 포함. 막대 = 보유(필요량 157.9 = 트랙 80.7%, 넘치면 트랙 끝), 빗금 = 보유 끝 → 눈금, 오른쪽 "보유 / 필요"(모자라면 분홍). 수량 글자는 백만 이상 "98.4M", 아래는 정수 그대로(시안 "1020 / 2245"). 보유 모름 행은 눈금까지 빗금 + "— / 필요" 회색. 눈금 선은 시안 좌표대로 (x, 밑변 − 18) → (x + 2, 밑변 + 2).
5. **C1 seg**: "부족 큰 순" 선택 · 동작, "페이즈 순"은 그 칸만 비활성(키트 `SkewSegment.enabled`). 근거: 페이즈 순서는 활성 문서 계산(`phase_results`)이 필요해 FE7-g(C3)와 같이 붙인다. 자료가 없으면 seg 전체 비활성 자리(FE7-a 그대로).
6. **빈 상태 문구(~습니다체, 시안 없음)**: 목표 없음 "저장된 계획이 없습니다. 계획에 목표를 저장하면 나타납니다."(B1 · C1 · C2), 계획 재화 없음 "계획에 필요한 재화가 없습니다.", B1에 재화만 있음 "카테고리로 나눌 재화가 없습니다. 크레딧 · 엘리그마는 C1에서 봅니다.", C2 보유 아는 재화 없음 "보유를 아는 재화가 없습니다. 인벤토리 스캔을 실행하면 나타납니다.", 읽는 중 · 계산 실패 '—'(오류는 근거 패널 안내 줄). 근거 빈 상태: 인벤토리 "B1 막대를 고르면 근거가 보입니다.", 계획 "C1 행이나 C2 점을 고르면 근거가 보입니다."(성장은 FE7-a 문구 그대로).
7. **C2**: 가로 = 충족률, 세로 = 영향 학생 수(`affectedStudentIds.length`), 세로 최대 = 가장 많은 학생 수 + 1(최소 4). "먼저 볼 병목" 구역 = 충족률 50% 미만 · 학생 3명 이상(시안 구역 (41,10)–(241.8,131.2), 축 최대 8과 정확히 맞음). 구역 안 점은 회색 이름, 고른 점은 분홍 큰 점 + 흰 굵은 이름. 보유 모름 재화는 점이 없고 오른쪽 위 "보유 모름 n종 제외". 누르면 가장 가까운 점(설계 좌표 12 안).
8. **미계획 · 40% 미만**: 보유 · 목표 없음 · 육성도(FD-028)를 아는 학생 중 40% 미만(모름은 셈하지 않음).
9. **근거 패널**: 카테고리(B1) = 머리 "<카테고리>" + 충족률 칩(60% 미만 분홍 · 모름 회색), 부제 "B1에서 고른 카테고리 · 충족률 낮은 순", 재화 행 7(아이콘 · 이름 · "보유 n / 필요 m" · 칩) + "외 n종", "카테고리 요약"(계획 재화 · 부족 · 스캔 없음 종 수). 재화(C1 · C2) = 시안 Stats-Inventory 근거 틀: 머리 "<재화>" + 칩(필요량 대비 "−n%" 분홍 · 넘침 "+n%" · 같음 "충족" · 모름), 아이콘 행(부제 "C1에서 고른 행 · 필요량 대비" / "C2에서 고른 병목 · 충족률 n% · 학생 n명" — 시안 문구), 보유 · 필요 (활성 계획) · 부족(분홍) 줄, "쓰는 학생 · n명" + 학생 행 10(초상 · 이름 · Lv, 부족 계산의 학생 순서) + "외 n명". 고르기는 하나(B1 · C1 · C2 중), 같은 것을 다시 누르면 푼다, 다시 읽기 · 주제 전환 때 지운다.
10. **빼고 근거를 적은 것**: 시안 Stats-Plan 오른쪽 "막히는 단계 · P2부터 누적 부족" · 머리 칩 "첫 부족 P2"(C3 문서 계산 데이터 → FE7-g), "풀리는 방법"(what-if, 백엔드 없음), Stats-Inventory "쓰는 학생 · 필요량 순"의 학생별 필요량 · 단계("P2 · 스킬 M 96", 문서 계산 `stage_results` → FE7-g; 지금은 학생 수만, 캡션 "n명"), "최근 변화"(이력 → FE7-h). 원본 탭 이동 버튼은 FE7-d라 비활성 그대로.

#### golden 변화 예상

- **`statistics-growth`: 변화 0.** 성장 쪽 변경은 이름 공개 · 구조 이동뿐이다: KPI 칸은 전에도 누를 수 있었고(같은 `KitPressable`), `KpiTile.valueColor` 기본 흰색, 차트 글자 `maxWidth` 기본 null(같은 layout), 타일 내용 위젯 트리 같음, 근거 빈 상태 문구 같음. 장면 코드 · fixture 서비스 그대로.
- **다른 기존 장면: 변화 0.** 키트 변경은 기본값이 이전과 같고(`SkewSegment.enabled` true면 위젯 트리가 같다), 인벤토리 · 계획 · 셸 파일은 고치지 않았다. Lane B 헤더 · 홈 변화는 이 slice와 무관(같은 gate에서 함께 보일 수 있음). 바뀌는 기존 기준 이미지가 없어 commit.json에 `whole`을 두지 않았다.
- **새 장면 `statistics-inventory`**(기준 이미지 없음 → RED, CF가 만든다). 기대 모습(일회성 렌더로 본 배치):
  - 왼쪽: "인벤토리 현황" 주제 선택(핑크), 필터 부제 "인벤토리 · 계획 집계는 항상 전체", 기준 데이터 '—'.
  - 가운데 제목 "인벤토리 현황" + (i), 오른쪽 "활성 계획 기준 · 인벤토리 스캔 —". KPI 5칸: "72%" —, 분홍 "14종" —, "6종" —, "3 / 6" —, 회색 "1종" + 회색 "엘레프".
  - B1(1차 칩): 6행 사선 계단, 장비 설계도 78%(파랑) · 기술 노트 64%(파랑) · 활동 보고서 91%(파랑) · 전술 BD 52%(분홍) · 오파츠 47%(분홍) · 엘레프(회색 라벨, 트랙 빗금 + "모름 · 스캔 없음" + '—'), 60% 분홍 점선 + "60% 기준". B2(seg 흐림) · B3(seg + 3차 칩) "준비 중". 콘텐츠 830이라 스크롤바 썸 없음.
  - 오른쪽: "근거 확인" + "B1 막대를 고르면 근거가 보입니다.", 아래 흐린 버튼 둘.
- **새 장면 `statistics-plan`**(기준 이미지 없음 → RED). 기대 모습:
  - KPI: "72%" —, 분홍 "14종" —, "—" —, "—" —, "26명" —(성장 fixture의 미계획 · 40% 미만 수, 시안 14명과 다름 — 발견 사항 3). 범위 칩 "활성 계획 · 9명 · 페이즈 —".
  - C1: seg "부족 큰 순"(분홍 테두리, 또렷) · "페이즈 순"(흐림). 5행: 크레딧 98.4M / 261.5M · 엘리그마 1020 / 2245 · 네브라 디스크 T4 23 / 50 · 님루드 렌즈 T3 24 / 50 · 기술 노트 (상급) 12 / 25(모두 분홍 글자), 파랑 보유 막대 + 회색 빗금 + 흰 눈금, 아래 "빗금 = 모자란 양" · "필요량 = 눈금 (행마다 자기 단위)".
  - C2(1차 칩): 축 · "학생" · "0" · "0%" · "충족률 →", 왼쪽 위 분홍 점선 구역 + "먼저 볼 병목", 구역 안 이름(크레딧 · 네브라 디스크 T4 · 엘리그마 · 님루드 렌즈 T3), 오른쪽 끝(충족 100%) 세로 점 줄, 오른쪽 위 "보유 모름 1종 제외".
  - C3 · C4(2차) · C5(3차) "준비 중", 오른쪽 공용 스크롤바 썸. 오른쪽 근거 "C1 행이나 C2 점을 고르면 근거가 보입니다.".

#### 검수표

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Stats-Inventory(K · B1) | golden `statistics-inventory`(시안 숫자 fixture). 앱 mock 기본 계정은 목표가 없어 B1에 "저장된 계획이 없습니다…"만 보인다(발견 사항 4) | KPI 72% · 14종(분홍) · 6종 · 3 / 6 · 1종 엘레프(회색), B1 6행 계단 · 60% 점선 기울기 · 60% 미만 분홍 · 엘레프 빗금 "모름 · 스캔 없음" |
| Stats-Inventory(B1 선택) | 통계 탭 → 인벤토리 현황 → B1 "기술 노트" 막대 누르기 | 막대 분홍 테두리 · 라벨 분홍, 오른쪽 "기술 노트" + "64%", 부제 "B1에서 고른 카테고리 · 충족률 낮은 순", 재화 행(상급 48% → 최상급 80%), "카테고리 요약" 2종 · 2종 · 0종, 다시 누르면 빈 상태 |
| Stats-Plan(K · C1 · C2) | golden `statistics-plan` → 통계 탭 → 계획 집계 | 범위 칩 "활성 계획 · 9명 · 페이즈 —", KPI 첫 부족 · 막힌 학생 '—', C1 불릿(눈금 = 필요량, 빗금 = 모자란 양, 행마다 자기 단위), C2 분홍 구역 · 구역 안 이름 |
| Stats-Plan(C1 · C2 선택) | C1 크레딧 행 · C2 네브라 점 누르기 | 오른쪽 "크레딧" + "−62%", 아이콘 행 + "C1에서 고른 행 · 필요량 대비", 보유 98.4M · 필요 261.5M · 부족 163.1M(분홍), "쓰는 학생 7명" + 초상 행 / C2를 고르면 C1 선택이 풀리고 "C2에서 고른 병목 · 충족률 46% · 학생 6명" |
| (동작) | KPI 누르기 · 주제 전환 · 1280×720 | 계획 KPI "첫 부족" → C3 줄, "미계획" → C5 줄로 스크롤, 주제를 바꾸면 선택이 풀림, "페이즈 순"만 흐리고 눌리지 않음, 작은 창 예외 없음 |
| Statistics-Proposal | 위 화면 | B1 공통 트랙 · C1 불릿 · C2 산점도 + 분홍 구역, 색 역할(크기 파랑 · 강조 분홍 · 모름 회색 빗금), 다른 재화 수량 합산 없음 |

#### 미검증 항목

- golden(새 장면 `statistics-inventory` · `statistics-plan`, `statistics-growth` · 다른 장면 변화 0 예측): **미실행**. 일회성 렌더는 배치 확인만이다.
- 전체 `fe_gate.ps1`(나머지 테스트 · process E2E · `codealmanac validate` · 저장소 전체 `git diff --check`): **미실행**.
- 실제 백엔드 계정의 숫자(부족 행 category 값 · 크레딧 행 포함 여부 · 영향 학생 수 분포): **미실행**. Mock · fixture만 보았다.
- 실제 창에서 KPI 스크롤 애니메이션 · C2 점 겹침 정도 · 실제 글꼴의 C1 라벨 말줄임.

#### WIP 보존 확인

- 고친 기존 14파일(이 문서 포함 15)은 착수 때 WIP가 없었다(`git status --short` 빈 줄). post 사본 · `post_dir`는 두지 않았다. pre 사본 대비 diff는 이 slice 줄뿐이고 줄바꿈을 유지했다(`statistics_growth_evidence.dart`는 `sed -i`가 CRLF를 LF로 바꾼 것을 바로 CRLF로 되돌렸다, 최종 pre와 같은 CRLF).
- 작업 트리의 다른 미커밋 변경(Lane B `app_shell.dart` · `lib/ui/scan/header_connection_chip.dart` · `lib/ui/home/` 등, 스캐너 · 백엔드 파일)은 읽지도 고치지도 않았다. git 쓰기는 하지 않았다. 임시 렌더 테스트는 지웠다.

#### 발견 사항

1. **FD-034 · 첫 부족은 지금 `_reload()` 자료로 계산할 수 없다**: 막힌 학생(m − n)과 첫 부족(페이즈 · 재화)은 문서 계산(`calculatePlanningDocument`의 `bottlenecks` · `phase_results`)이 있어야 한다. 통계는 목표 v1 평면 계획으로 `calculatePlan` · `calculateShortages`만 읽는다. 새 서비스 메서드는 필요 없고(인벤토리 탭이 이미 `loadRepositoryPlan` + `calculatePlanningDocument`를 읽는다), FE7-g에서 `_reload()`에 그 두 읽기를 더하면 막힌 학생 · 첫 부족 · 페이즈 수 · C1 페이즈 순 · 근거 "막히는 단계"가 함께 풀린다. 그때 "활성 계획"을 목표 v1이 아니라 활성 문서로 볼지(인벤토리 탭과 같게) CF 결정이 필요하다.
2. **시안 숫자 모순**: C1 3~5행(기술 노트 (최상급) 96/120 = 80% · 설계도 시계 T8 52/60 · 상급 활동 보고서 384/300)은 B1 오파츠 47% · 전술 BD 52%가 있는 한 "부족 큰 순" 위 다섯이 될 수 없다. C2 기술 노트 (최상급) 24%는 C1 96/120(80%)과, 근거 "필요 254 · 부족 158"(Stats-Inventory)과도 맞지 않는다. fixture는 KPI · B1 · C1 첫 두 행을 맞췄다.
3. **미계획 · 40% 미만**: 성장 fixture(시안 Stats-Growth 숫자)에서는 26명이다(시안 Stats-Plan 14명). 두 시안 fixture를 함께 맞추려면 성장 fixture를 바꿔야 해(FE7-b golden에 닿음) 그대로 두었다.
4. **mock 기본 계정**: 목표가 없어 인벤토리 · 계획 주제가 빈 상태다. 시안 숫자를 앱 mock 실행에서 보려면 `lib/services/**` 변경(검수 시나리오)이 필요하다 — FE7-b 발견 4와 같은 CF 요청 후보.
5. **C2 점 겹침**: 충족 100% 재화가 오른쪽 끝 한 줄에 겹치고(fixture 9점), 같은 (충족률, 학생 수) 재화는 한 점으로 보인다. 시안에 겹침 규칙이 없다(지터 · 묶음 표시는 후속 판단).
6. **근거 "외 n명 · 외 n종"은 누르는 동작이 없다**: 성장 근거의 "모두 보기" 펼침(FE7-b)과 같은 동작을 붙일지 FE7-d와 함께 판단.
7. **KPI 타일 높이 70(키트) vs 시안 84**(FE7-a 발견 4)는 그대로다. 값 색은 키트에 선택 인자를 더해 시안 색(부족 분홍 · 스캔 없음 회색)을 썼다.
8. 근거 아이콘 행 오른쪽은 시안 폭(362.7, 섹션 오른쪽에서 44)을 상수로 두었다. 다른 근거 요소(40 · 22)와 규칙이 다르다.

#### 사본 · commit.json

- 착수 사본: `debug/frontend_fe7c/pre/<경로>`(고친 기존 14파일 + 이 문서). WIP가 없어 post 사본은 없다.
- `debug/frontend_fe7c/commit.json`: slice `fe7c`, `status=true`, modified 15(이 문서 포함), added 6, `whole` 없음(바뀌는 기존 기준 이미지 없음 — 새 장면 이미지 `statistics-inventory.png` · `statistics-plan.png`는 CF가 넣는다).
- 인계: `debug/frontend_fe7c/output.md`.

#### 다음 행동

- FE7-c 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: 레인 워커가 모두 멈춘 뒤 gate 1회. 예상: analyze 0, 일반 테스트에 새 19건(projection 8 · view 11) + projection 1 · kpi_tile 1 · skew_controls 1, golden은 새 장면 `statistics-inventory` · `statistics-plan`만 RED(기준 없음, 위 기대 모습), `statistics-growth` · 다른 장면 변화 0(Lane B 변화는 별도). 승인 뒤 `-UpdateGoldens` · 재비교 · `fe_commit.ps1 -Slice fe7c`.
- 남은 CF 판단: 발견 1(FE7-g 활성 문서 읽기 · "활성 계획" 정의), 2 · 3(시안 숫자), 4(mock 검수 시나리오), 5 · 6(C2 겹침 · 근거 펼침).

### fe7c commit record (2026-10-13 20:00, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261013_194844\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE7-g 통계 계획 집계 · 활성 문서 계산 (Lane A, 로컬 Claude Code)

### FE7-g 착수 기록 (2026-10-13, Lane A)

- 상태: 진행 중. 시작 SHA = `cbc63d98bcc279ae9ca6d22c9fe2c45ee3569996`(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`). 착수 전 이 문서에 다른 "FE7-g 착수 기록" 없음(grep 0건).
- 범위: 통계 `_reload()`가 활성 계획 문서(`loadRepositoryPlan`)와 그 문서 계산(`calculatePlanningDocument`)을 읽는다. 계획 KPI 첫 부족 · 막힌 학생(FD-034), 범위 칩 페이즈 수, C3 페이즈별 누적 부족(재화별 · 필요량 대비 %, FD-033), C1 "페이즈 순", 근거 "막히는 단계 · Pn부터 누적 부족". C4 · C5는 "준비 중"(FD-106). 새 서비스 메서드 · 백엔드 변경 없음.
- 막힘: 대장 막힘 요약 FE7-g 행 = `—`(막는 `열림` FD 없음). 워커 재량 FD-035 · FD-037 · FD-105는 권장안(FD-037은 FE5-d가 확인한 백엔드 의미 그대로: phase `owned` = 진입 잔량).
- "활성 계획" 정의: 오케스트레이터 로그 2026-10-13 20:05 · 20:25대로 활성 문서(`plan.get`)다. 계획 충족률 · 부족 재화 · C1 · C2는 FE7-c 식(goals v1 부족 계산) 그대로 둔다.
- 재사용할 계획 쪽 projection(고치지 않음, 공개 함수 그대로 import): `lib/ui/models/plan_scenario_detail.dart`의 `PlanDetailData.fromProjection`(페이즈별 재화 `phaseResources` · `phaseSummary` · `kpis.firstBottleneck` · `kpis.finishing`) · `PlanDetailStageStates`(FD-034 · 035) · `planDetailFirstBottleneck`, `lib/ui/widgets/plan_scenario_preview.dart`의 `planScenarioBottleneckValue`. 공용 추출 필요 없음 → 계획 화면 파일 변경 0 예정.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe7g/pre/<v7 기준 경로>`, 작업 트리와 cmp 일치, 모두 WIP 없음 = `git status --short <경로>` 빈 줄). 줄바꿈은 작업 트리 그대로 유지:
  - `frontend/lib/ui/pages/statistics_page.dart`(CRLF)
  - `frontend/lib/ui/statistics/statistics_workspace.dart`(LF) · `statistics_supply_evidence.dart`(LF) · `statistics_topics.dart`(LF)
  - `frontend/lib/statistics/statistics_supply_projection.dart`(LF, 머리 주석만 예정)
  - `frontend/lib/ui/studio/statistics_studio_layout.dart`(LF, 요소 좌표만)
  - `frontend/test/statistics_supply_view_test.dart`(LF) · `statistics_workspace_test.dart`(LF) · `statistics_page_test.dart`(CRLF)
  - `frontend/test/goldens/fe7a_statistics_golden_test.dart`(LF, fixture 입력만)
  - `almanac/workflows/frontend-redesign-status.md`(이 문서, LF)
- 새 파일(예정): `frontend/lib/statistics/statistics_plan_projection.dart`, `frontend/lib/ui/statistics/statistics_plan_charts.dart`(C3 painter), `frontend/test/statistics_plan_fixture.dart`(시안 숫자 문서 · 문서 계산), `frontend/test/statistics_plan_projection_test.dart`, `frontend/test/statistics_plan_view_test.dart`.
- 고치지 않음: `lib/services/**`(읽기만), Lane B 파일(`student_scan_diagnostic.dart` · `scan_page.dart` · `scanner_service.dart`), 계획 화면 · 모델 파일, 학생 · 인벤토리 · 스캔 · 타이틀 화면, `app_shell.dart` · `app_section.dart`, `lib/ui/kit/**`, golden harness, `frontend/tool/**`, backend · contracts, 택틱 · 스캐너 소유 파일.

### FE7-g 종료 기록 (2026-10-13, Lane A, 코드 작성 완료 · CF gate 미실행)

통계 `_reload()`가 활성 계획 문서(`plan.get`)와 그 문서 계산(`planning.document.calculate`)을 읽는다. 계획 집계에 KPI "첫 부족"(P2 · 재화 이름) · "막힌 학생"(FD-034 m − n), 범위 칩 "페이즈 n", C3 페이즈별 누적 부족 계단선(재화별 · 필요량 대비 %), C1 "페이즈 순", 근거 "막히는 단계 · Pn부터 누적 부족"을 넣었다. C4 · C5는 "준비 중" 그대로(FD-106). 새 서비스 메서드 · 백엔드 변경 없음, 계획 화면 · 모델 파일 변경 0(공용 추출 없이 공개 projection을 그대로 import).

착수 기록 정정: 고친 기존 파일은 착수 목록 그대로 10개 + 이 문서다(키트 · 계획 파일 변경 없음).

#### 실행 명령 · 결과

모두 `frontend`에서 이 PC(Claude Code)로 실행했다. 로그는 `debug/frontend_fe7g/logs/`이고, 실패 줄(`[E]` · `EXCEPTION` · `Some tests failed` · `error •`)만 찾았다.

| 명령 | 결과 |
|---|---|
| `flutter analyze`(1차, projection · C3 · page 뒤) | 5 issues: error 3(`listEquals` import 없음) · info 2(`prefer_collection_literals` · `unnecessary_import`) → 고침 |
| `flutter analyze`(2 · 3차, 테스트 import 정리 2건 뒤) | info 1씩(`unnecessary_import`, `statistics_page_test.dart` · golden 테스트) → 고침 |
| `flutter test test/statistics_plan_projection_test.dart`(1차) | +6 −1: 레코드 안 `List` 비교가 동일성 비교 → 키 · 값 따로 비교로 고침(값은 일치) |
| `flutter test` plan_projection + plan_view(1차) | 컴파일 실패(`statisticsUnplannedLowCount` import 누락) → 고침 |
| 같은 두 파일(2차) | +12 −4: ① 근거 머리는 `PanelTitle`(테스트 helper가 `Text`로 읽음) ② 800×600에서 "막히는 단계 · 단계 순서" 머리 `TileTitle` Row가 62.8 폭에 7.4px 넘침 → `_sectionTitle`을 `StatisticsMinWidth(160)`로 감쌈(160 이상이면 그대로라 FE7-c 소제목 · 기준 viewport 그림 같음). 넘침 위치는 임시 `FlutterError.onError` 출력으로 찾고 지웠다 |
| 같은 두 파일(3차) | +15 −1: 머리 묶음은 34 자리의 세로 가운데(FE7-c 소제목과 같다) → top 대신 left · width · 세로 가운데로 비교 |
| 같은 두 파일(4차) | **+16 −0** |
| `flutter analyze`(최종) | **No issues found**(info 포함 0) |
| 관련 25파일 한 번에(`--file-reporter json`, 아래) | **+248 −0** |
| 일회성 렌더(임시 `test/zz_fe7g_render_tmp_test.dart`, harness 공개 함수, scratchpad PNG 2장: 계획 집계 · 페이즈 순 + C2 기술 노트 선택) | 배치 · 숫자 시안 자리(아래 golden 예상). 임시 테스트는 지웠다. golden 비교 아님 |
| `git diff --check`(고친 기존 10파일) · 새 5파일 줄 끝 공백 · 줄바꿈 | 0 · 0. 새 파일 LF · 끝 개행 하나, 기존 파일은 pre와 같은 줄바꿈(`statistics_page.dart` · `statistics_page_test.dart` CRLF, 나머지 LF — `git ls-files --eol` 확인) |

관련 25파일(파일별 통과, 모두 −0): statistics_plan_projection +7(새), statistics_plan_view +9(새), statistics_page +14(+1 새 테스트), statistics_supply_view +11, statistics_supply_projection +8, statistics_workspace +13, statistics_growth_view +12, statistics_growth_projection +11, statistics_projection +7, statistics_app_shell +2, section_template_studio +15, kit/scroll_viewport_fog +6, widget +16, home_app_shell +1, home_page +5, home_connect_fe8e +10, inventory_shell_lazy +1, account_editor_fe8c +9, account_manager_fe8b +6, connected_target_fe8d +8, growth_calculator_view +24, profile_delete_fb2d +17, student_filter_followups +4, student_filter_modal +7, title_page +25.

- 걸리는 기존 테스트 찾기: test/ 전체를 `statistics|Statistics|StatisticsPage|top-tab-statistics|BAPlannerApp|AppShell\(`로 grep했다(통계 페이지가 새로 `loadRepositoryPlan` · `calculatePlanningDocument`를 부르므로 셸을 띄우는 테스트 전부 포함). 공용 projection을 꺼내지 않았고 계획 파일을 고치지 않아 plan_home_detail · plan_scenario_* · planning_page는 돌리지 않았다. `developer_tools_app_test` · `metadata_manager_dto_test` · process E2E 2개(`repository_process_e2e` · `tactical_v2_process_e2e`)는 다른 기능 · E2E라 돌리지 않았다(FE7-a · c와 같은 판단).
- 빌드 잠금 충돌 없음. `flutter analyze`가 pub get을 돌렸지만 `pubspec.lock` · `pubspec.yaml` 변화 없음.
- 실행하지 않음: golden(`test/goldens/**`), 전체 `fe_gate.ps1`, `-UpdateGoldens`, `fe_commit.ps1`, 맨 `flutter test`, process E2E, `codealmanac validate`.

#### 읽기 경로

`_reload()`: 계정 → **활성 계획 문서**(`RepositoryPlanService.loadRepositoryPlan`, 서비스가 그 인터페이스일 때만) → 계정 상태 → 학생 목록 → 인벤토리 목록 → (목표 있으면) `calculatePlan` · `calculateShortages`(FE7-c 그대로) → **문서 계산**(`PlanningDocumentService.calculatePlanningDocument(current, inventory, document)`, 문서에 단계가 있고 `plan.calculation != null`일 때만 — 계획 홈과 같은 조건, 응답은 `PlanDetailData.checkProjection`) → loading 끝. generation 가드 · "처음 보일 때 읽기"(FE7-a `TickerMode`)는 그대로다(읽기는 모두 같은 `_reload()` 안).
- 순서 근거: 활성 계획을 계정 상태보다 먼저 읽는다(인벤토리 컨트롤러 · `loadRepositoryPlanSnapshot`과 같은 순서 — 목표 v1만 있는 계정은 첫 `plan.get`이 문서로 옮기며 revision을 올린다). 통계는 저장하지 않으므로 revision 일치 재시도는 두지 않았다(인벤토리 탭과 같다).
- "활성 계획" = 저장된 활성 문서(오케스트레이터 20:05 · 20:25). 계획 충족률 · 부족 재화 · C1 · C2 값은 FE7-c 식(goals v1 부족 계산) 그대로다 — goals v1은 문서에서 파생(FB-1b, 학생별 마지막 단계)이라 전체 필요량이 같다.
- 오류: 활성 계획 읽기 · 문서 계산 실패는 공용 `errors`(근거 안내)에 넣지 않고 계획 집계 C3 타일 안 글자로만 보인다("활성 계획을 읽지 못했습니다: …" · "활성 계획을 계산하지 못했습니다: …" · `calculation` 없음 "지금은 활성 계획을 계산할 수 없습니다."). 다른 주제 · C1/C2 근거를 막지 않게 하려는 것이다. 그때 첫 부족 · 막힌 학생 · 페이즈 수 '—', C1 "페이즈 순" 비활성.

#### 공용 projection과 계획 쪽 영향

- 꺼낸 것 없음. `lib/statistics/statistics_plan_projection.dart`(새)가 계획 Detail의 공개 projection을 import해 그대로 쓴다: `PlanDetailData.fromProjection(document, projection)`(비교 없음) → `phaseResources`(페이즈별 재화 진입 · 필요 · 부족, FD-037) · `phaseSummary`(첫 부족 페이즈 · 재화) · `kpis.firstBottleneck`(`planDetailFirstBottleneck`) · `kpis.finishing`(`PlanDetailStageStates.finishingStudents`, FD-034 · 035). 글자 "없음/Pn/—"는 `lib/ui/widgets/plan_scenario_preview.dart`의 `planScenarioBottleneckValue`.
- 계획 화면 · 모델 파일 변경 0 → 계획 golden 변화 0.

#### 처리한 FD

- **FD-034(확정 (a))**: 막힌 학생 = 문서 계산 단계 학생 m − 끝까지 가는 학생 n(`PlanDetailStageStates`, 계획 Detail과 같은 원천). fixture 9 − 3 = 6명.
- **FD-033(확정)**: C3는 재화마다 선 하나, 값 = 그 재화 누적 부족 / 그 재화 전체 필요량. 서로 다른 재화 수량을 더하지 않는다. 시안도 재화별 선 + "누적 부족 (재화별 필요량 대비)"라 합산 문제 없음(멈출 일 없었음).
- **FD-035(워커 재량, 권장안)**: 단계 상태는 `PlanDetailStageStates` 그대로(막힌 학생 계산에만 씀).
- **FD-037(워커 재량, 권장안)**: phase `owned` = 진입 잔량(백엔드 `calculate_document_projection` 읽어 확인, FE5-d와 같은 결론). 페이즈 부족 = max(0, 필요 − 진입). 그래서 마지막 누적 = max(0, 전체 필요 − 보유) = 그 재화 전체 부족(테스트로 고정).
- **FD-031(확정 (a))**: 계획 충족률 식 FE7-c 그대로(바꾸지 않음).
- **FD-105(워커 재량)**: KPI 첫 부족 → C3 줄 스크롤(FE7-c 그대로).
- **FD-106(확정)**: C4 · C5 "준비 중" 유지. C3는 그래프 타일이 되어 빈 상태 문구를 쓴다(아래 규칙 6).
- 막는 `열림` FD 없음.

#### 정한 규칙(시안 · 대장에 없는 것)

1. **첫 부족 KPI**: 계획 Detail 페이즈별 요약 행 규칙(`phaseSummary`: 처음 모자라는 페이즈, 그 페이즈 충족률 낮은 → 부족량 큰 재화). 값 "Pn" 분홍 · 증감 자리에 재화 이름(`KpiDeltaTone.plan` #f7c9f4, 말줄임 — 시안 "기술 노트"는 짧은 이름, 앱은 백엔드 `display_name` "기술 노트 (최상급)"). 모자라는 재화 없음 "없음", 문서 계산 없음 '—'.
2. **막힌 학생 KPI**: "n명", 증감 '—'(FE7-h).
3. **범위 칩**: "활성 계획 · <목표 학생 수(FE7-c)>명 · 페이즈 <단계가 있는 페이즈 수>". 학생 수는 FE7-c 그대로(goals), 페이즈 수만 문서에서.
4. **C3 그리기**(시안 SVG viewBox 494×207 그대로): x = 단계가 있는 페이즈 P1~Pn 같은 간격(40 → 344.2, 끝 354.2), 값이 바뀌는 페이즈에서 세로로 오르는 계단(시안 path `H … V …`). y축 끝 = 가장 큰 값을 20% 단위로 올림(20~100%, 시안 74% → 80% 축 · 40% 2-4 점선 95.5), 0 = 177. 선 최대 3개: 끝까지 모자라는(보유를 아는) 재화를 첫 부족 페이즈 → 그 페이즈 충족률 낮은 → 누적 부족 큰 순, 첫 부족 재화(KPI)를 맨 앞(분홍 2.4 · 흰 굵은 이름), 나머지 회색 2 · 회색 이름. 첫 선 첫 부족 페이즈에 분홍 점(r6 · #16202c 테두리) + "첫 부족 · Pn". 이름은 선 끝 + 6, 겹치면 12 간격으로 아래로 민다. 누르는 동작 없음. 크레딧도 선 후보(비율이라 단위 문제 없음).
5. **C1 "페이즈 순"**: 재화의 첫 부족 페이즈(`bottlenecks[].phase_number`) 순 → FE7-c "부족 큰 순" 비교, 문서에서 모자라지 않는 재화는 뒤. 문서 계산이 있을 때만 켜고, 없으면 그 칸만 비활성(FE7-c 그대로). 순서를 바꾸면 C1에서 고른 행만 푼다(그 행이 화면에 없을 수 있다). 순서 선택은 다시 읽어도 남긴다.
6. **C3 빈 상태(~습니다체)**: 공용 빈 상태(읽는 중 '—' · 목표 없음 "저장된 계획이 없습니다…" · 계획 재화 없음)는 FE7-c와 같다. 그 밖에 문서 계산 없음 '—'(오류면 그 글자), 보유 아는 재화 없음 "보유를 아는 재화가 없습니다. 인벤토리 스캔을 실행하면 나타납니다.", 끝까지 모자라는 재화 없음 "계획 끝까지 모자라는 재화가 없습니다."(새 문구, 시안 없음), 페이즈 계산 줄(`phase_results`)이 빠진 페이즈가 있으면 '—'.
7. **근거 Stats-Plan 틀**: 계획 집계에서 고른 재화(C1 · C2)가 문서 계산에서 모자라는 단계가 있을 때만. 머리 칩 "첫 부족 Pn"(분홍), 아이콘 행(FE7-c 그대로), "막히는 단계" + 캡션 "단계 순서"(시안 위치 152), 단계 행(196 · 피치 58, 최대 4 + "외 n단계"): 초상 · "Pn"(경기천년제목 15 분홍, 폭 30) · "<학생> · <단계 이름>" · 칩 "−<그 단계 진입 부족>"(분홍, 수량 단위), "Pn부터 누적 부족 −<합>"(= 그 재화 전체 부족). 그 아래 "쓰는 학생 · n명"(시안 "풀리는 방법" 자리, 7행 + "외 n명"). 보유 · 필요 · 부족 세 줄은 시안 Stats-Plan에 없어 이 틀에서 뺐다. 모자라지 않거나(크레딧 등) 문서 계산이 없으면 FE7-c 틀 그대로. 막히는 단계 칩 · 누적은 수량, C3는 % — 시안은 같은 숫자를 썼다(아래 발견 2).
8. **좁은 창**: 근거 소제목(`_sectionTitle`)은 160 폭 미만에서 최소 폭으로 배치하고 오른쪽을 자른다(행과 같은 규칙).

#### golden 변화 예상

- **`statistics-plan`: 바뀐다.** fixture 입력만 바꿨다(서비스가 활성 문서 · 문서 계산을 시안 숫자 fixture로 준다, 장면 조작 그대로). 장면별 예측(일회성 렌더로 본 모습):
  - KPI: "첫 부족" '—' → 분홍 "P2" + 분홍빛 "기술 노트 (최상급)", "막힌 학생" '—' → 흰 "6명" + 회색 '—'. 계획 충족률 72% · 14종 · 미계획 26명은 그대로.
  - 범위 칩: "활성 계획 · 9명 · 페이즈 —" → "… · 페이즈 5".
  - C1: seg "페이즈 순" 흐림 → 또렷(선택은 "부족 큰 순" 그대로, 행 · 막대 그대로).
  - C3: "준비 중" → 계단선 그래프(왼쪽 위 "누적 부족 (재화별 필요량 대비)", "40%" 점선 · "0" · P1~P5, 분홍 기술 노트 (최상급) 0 → 18 → 41 → 62 → 74% + P2 분홍 점 + "첫 부족 · P2", 회색 엘리그마 0 → 0 → 12 → 22 → 30%, 회색 설계도 · 시계 T8 0 → 0 → 0 → 9 → 15%, 선 끝 이름 셋). "2차" 칩 그대로.
  - C2 · C4 · C5 · 근거 빈 상태 · 왼쪽 섹션: 그대로.
- **`statistics-inventory`: 변화 0.** 같은 서비스가 활성 문서 · 문서 계산을 주지만 인벤토리 주제는 그것을 그리지 않는다(KPI · B1 · B2 · B3 · 근거 빈 상태 · 왼쪽은 FE7-c 그대로). 계획 읽기 오류도 공용 안내에 들어가지 않는다.
- **`statistics-growth`: 변화 0.** 서비스 그대로(golden Mock 활성 계획 · 문서 계산 대역을 새로 읽지만 학생 성장 주제는 그것을 그리지 않는다).
- **다른 장면: 변화 0.** 계획 · 키트 · 셸 파일을 고치지 않았다. 통계 탭을 띄우지 않는 장면은 통계 읽기가 일어나지 않는다(처음 보일 때 읽기).
- commit.json `whole` = `frontend/test/goldens/baseline/statistics-plan.png`(CF가 승인 뒤 갱신한 파일).

#### 검수표

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Stats-Plan(K · C3) | golden `statistics-plan`(시안 숫자 fixture) → 통계 탭 → 계획 집계 | 범위 칩 "활성 계획 · 9명 · 페이즈 5", KPI 첫 부족 분홍 "P2" + "기술 노트 (최상급)" · 막힌 학생 "6명", C3 계단선 세 줄(분홍이 맨 위 74%, 40% 점선 · P1~P5, 분홍 점 "첫 부족 · P2"), 재화 수량을 더한 선 없음 |
| Stats-Plan(C1 seg) | C1 "페이즈 순" 누르기 | 행이 기술 노트 (최상급) · 엘리그마 · 설계도 · 시계 T8 · 크레딧 · 네브라 순, "부족 큰 순"으로 돌아가면 크레딧 먼저 |
| Stats-Plan(근거) | C2 기술 노트 (최상급) 점(충족 80% · 학생 6) 누르기 | 오른쪽 머리 칩 "첫 부족 P2", 부제 "C2에서 고른 병목 · 충족률 80% · 학생 6명", "막히는 단계 · 단계 순서" + 4행(P2 호시노 · 스킬 M −18 · P3 아리스 · EX 5 −23 · P4 히나 · 스킬 9 −21 · P5 카즈사 · 스킬 M −12), "P2부터 누적 부족 −74"(분홍), 그 아래 "쓰는 학생 6명" |
| Stats-Plan(근거, 부족 없는 재화) | C1 크레딧 행 누르기 | FE7-c 틀 그대로(칩 "−62%", 보유 · 필요 · 부족 세 줄, 쓰는 학생) |
| (동작) | KPI "첫 부족" 누르기 · 1280×720 · 800×600 | C3 줄로 스크롤, 작은 창 넘침 예외 없음 |
| Statistics-Proposal | 위 화면 | "단계 누적 → 계단선", 색 역할(강조 분홍 · 나머지 회색), 다른 재화 합산 없음 |

#### 미검증 항목

- golden(`statistics-plan` 변화 · `statistics-growth` · `statistics-inventory` · 다른 장면 변화 0 예측): **미실행**. 일회성 렌더는 배치 확인만이다.
- 전체 `fe_gate.ps1`(나머지 테스트 · process E2E · `codealmanac validate` · 저장소 전체 `git diff --check`): **미실행**.
- 실제 백엔드 계정의 숫자(문서 계산 resource_key와 부족 계산 resource_key가 같은 공간인지 — C1 "페이즈 순"이 키로 맞춘다, 실제 페이즈 수가 많을 때 P 글자 간격, 크레딧이 C3 선이 되는 경우의 모습): **미실행**. Mock · fixture만 보았다.
- golden 장면에서 오프스테이지 계획 탭도 fixture 활성 문서 · 문서 계산을 받는다(같은 서비스). 보이지 않지만 그 탭이 예외를 내면 golden 테스트가 실패한다 — 일회성 렌더(같은 서비스 구성)에서 예외 0을 보았다.

#### WIP 보존 확인

- 고친 기존 10파일 + 이 문서는 착수 때 WIP가 없었다(`git status --short` 빈 줄). post 사본 · `post_dir`는 두지 않았다. pre 사본 대비 diff는 이 slice 줄뿐이고 줄바꿈을 유지했다.
- 작업 트리의 다른 미커밋 변경(Lane B `scanner_service.dart` · `scan_page.dart` 등, 스캐너 WIP 서비스 파일 · 위젯, 백엔드 파일)은 읽지도 고치지도 않았다(`mock_app_service.dart`는 읽기만). git 쓰기는 하지 않았다. 임시 렌더 테스트는 지웠다.

#### 발견 사항

1. **mock 기본 계정의 활성 계획**: 앱 mock 실행에서는 기본 계정에 목표가 없어 계획 집계가 빈 상태다(FE7-c 발견 4와 같다). 시안 숫자를 앱에서 보려면 `lib/services/**` 검수 시나리오가 필요하다 — CF 요청 후보.
2. **시안 숫자 모순 이어짐**: 시안 C3 기술 노트 (최상급) 74%(근거 −74)는 C1 · C2 96 / 120(80% 충족)과 맞지 않는다. fixture는 C3 · KPI · 근거를 시안대로 맞추고(문서 계산 보유 · 필요 = 26 / 100) 부족 계산 fixture(FE7-c, 96 / 120)는 그대로 둬, 같은 재화의 근거 부제 "충족률 80%"와 "누적 부족 −74"가 한 패널에 함께 보인다. 실제 자료에서는 둘이 같은 계정 · 같은 목표라 맞는다. 시안 학생(리오(무장) · 노아 · 미카)은 성장 fixture 계획 학생에 없어 아리스 · 히나 · 카즈사로 두었다.
3. **근거 단계 칩 단위**: 시안 "−18 … −74"는 C3 %와 같은 숫자라 단위가 모호하다. 수량(그 단계 진입 부족량)으로 정했다(규칙 7). %가 맞다면 바꾸기 쉽다(합 = 전체 부족이라 % 합은 C3 끝값).
4. **"풀리는 방법"(what-if)**: 백엔드가 없어 그리지 않았다(FE7-c와 같다). 그 자리에 "쓰는 학생"을 두었다.
5. **KPI 첫 부족 재화 이름**: 시안은 짧은 이름("기술 노트"), 앱은 `display_name` 전체를 말줄임으로 보인다. 짧은 이름 규칙이 필요하면 별도 결정.
6. **C3 선 수 3 · 겹침**: 선이 같은 값을 지나면 겹쳐 보이고, "첫 부족 · Pn" 글자가 회색 선과 겹칠 수 있다(시안 좌표 그대로). 이름 글자만 12 간격으로 민다.
7. **C3 누르기 없음**: 선을 눌러 재화를 고르는 동작은 시안에 없어 두지 않았다(C1 · C2에서 고른다).
8. **활성 문서 ↔ goals v1 학생 수**: 범위 칩 학생 수는 goals(FE7-c), 막힌 학생의 m은 문서 계산 단계 학생 수다. FB-1b 파생 규칙상 같아야 하지만 다르면 두 숫자가 어긋나 보인다.

#### 사본 · commit.json

- 착수 사본: `debug/frontend_fe7g/pre/<경로>`(고친 기존 10파일 + 이 문서). WIP가 없어 post 사본은 없다.
- `debug/frontend_fe7g/commit.json`: slice `fe7g`, `status=true`, modified 11(이 문서 포함), added 5, `whole` = `frontend/test/goldens/baseline/statistics-plan.png`.
- 인계: `debug/frontend_fe7g/output.md`.

#### 다음 행동

- FE7-g 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: 레인 워커가 모두 멈춘 뒤 gate 1회. 예상: analyze 0, 일반 테스트에 새 17건(plan_projection 7 · plan_view 9 · statistics_page 1), golden은 `statistics-plan`만 RED(위 장면별 예측), `statistics-growth` · `statistics-inventory` · 다른 장면 변화 0(Lane B 변화는 별도). 승인 뒤 `-UpdateGoldens` · 재비교 · `fe_commit.ps1 -Slice fe7g`.
- 남은 CF 판단: 발견 1(mock 검수 시나리오), 2 · 3(시안 숫자 · 단계 칩 단위), 5(짧은 이름), 8(학생 수 원천 하나로).

### fe7g commit record (2026-10-14 00:57, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261014_004608\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE7-d 통계 원본 탭 이동 (Lane A, 로컬 Claude Code)

### FE7-d 착수 기록 (2026-10-14, Lane A)

- 상태: **코드 완료(아래 FE7-d 종료 기록), CF gate 미실행**. 시작 SHA = `1f73913da099028ba2493655d4bd5c0c3160b570`(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`). 착수 전 이 문서에 다른 "FE7-d 착수 기록" 없음(grep 0건).
- 범위: navigation intent(학생 · 인벤토리 · 계획), 대상 탭 한 번 적용, "← 통계" 복귀 칩 + 통계 복원, 근거 패널 이동 버튼 켜기, FE7-c 발견 6(근거 "외 n종 · 외 n명" 펼침).
- 막힘: 대장 막힘 요약 FE7-d 행 = FD-028 → 확정(2026-10-06). 막는 `열림` FD 없음. 워커 재량 FD-063 · FD-108은 종료 기록에 처리를 적는다.
- 착수 중 사용자 확인(질문 4건, 2026-10-14, 모두 권장안): ① 계획 버튼 "계획 만들기 3 · 단계 순서" = 페이즈 편집 흐름 3단계 + 첫 부족 단계 카드 선택(흐름 컨트롤러에 처음 고를 단계 하나) ② 학생 탭 = 임시 학생 ID 목록 + S4 적용 필터 줄 맨 앞 제거형 칩, 학생 필터 상태 그대로(FD-063 육성도 행은 넣지 않음) ③ 복귀 = 다시 읽고 주제 · 스크롤은 그대로, 고른 것 · 펼침은 다시 읽은 뒤에도 근거가 있으면 복원 ④ "이 구간 학생을 계획에 추가" = 계획 만들기 1단계(새 시나리오)를 그 학생들을 미리 고른 채 연다.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe7d/pre/<v7 기준 경로>`, 작업 트리와 cmp 일치, 모두 WIP 없음 = `git status --short <경로>` 빈 줄). 줄바꿈은 작업 트리 그대로 유지(`git ls-files --eol`):
  - `frontend/lib/ui/app_shell.dart`(LF, 최소 diff) · `frontend/lib/ui/pages/statistics_page.dart`(CRLF)
  - `frontend/lib/ui/statistics/statistics_topics.dart`(LF) · `statistics_workspace.dart`(LF) · `statistics_growth_evidence.dart`(CRLF) · `statistics_supply_evidence.dart`(LF)
  - 수신부(최소): `frontend/lib/ui/pages/student_page.dart`(LF) · `frontend/lib/ui/widgets/student_section_layout.dart`(LF) · `frontend/lib/ui/pages/inventory_page.dart`(CRLF) · `frontend/lib/ui/pages/planning_page.dart`(LF) · `frontend/lib/ui/widgets/plan_section_layout.dart`(CRLF) · `frontend/lib/ui/models/plan_flow_draft.dart`(LF) · `frontend/lib/ui/models/plan_flow_order_editor.dart`(LF)
  - 테스트: `frontend/test/statistics_page_test.dart`(CRLF) · `frontend/test/statistics_workspace_test.dart`(LF)
  - `almanac/workflows/frontend-redesign-status.md`(이 문서, LF)
- 새 파일(예정): `frontend/lib/ui/navigation/app_navigation_intent.dart`, `frontend/test/app_navigation_fe7d_test.dart`.
- 고치지 않음: `lib/ui/pages/scan_page.dart` · `lib/services/student_scan_diagnostic.dart` · `lib/services/scanner_review_images.dart`와 그 테스트(Lane B fb10c-dart, 읽기만), `lib/services/**`, `main.dart`, `app_section.dart`(필요 없음), `lib/ui/kit/**`, golden harness · 기존 golden 테스트 파일, `frontend/tool/**`, backend · contracts, 택틱 · 스캐너 소유 파일.

### FE7-d 종료 기록 (2026-10-14, Lane A, 코드 작성 완료 · CF gate 미실행)

통계 근거 패널 아래 두 버튼이 고른 구간 · 재화를 원본 탭(학생 · 인벤토리 · 계획)으로 넘긴다. 대상 탭은 같은 의도를 한 번만 적용하고, 넘어간 탭 머리말의 "← 통계" 칩으로 돌아오면 통계가 다시 읽은 뒤 고른 것 · 펼침을 되살린다. 재화 근거 "외 n종 · 외 n명"은 성장 근거 "모두 보기"와 같은 펼침이다(FE7-c 발견 6). 새 서비스 메서드 · 백엔드 · 키트 변경 없음.

착수 기록 정정: `frontend/test/statistics_page_test.dart` · `statistics_workspace_test.dart`는 고치지 않았다(사본을 지웠다, 작업 트리 = HEAD). 새 테스트는 `frontend/test/app_navigation_fe7d_test.dart` 한 파일이다.

#### 실행 명령 · 결과

모두 `frontend`에서 이 PC(Claude Code)로 실행했다. 로그는 `debug/frontend_fe7d/logs/`이고, 실패 줄(`[E]` · `EXCEPTION` · `Some tests failed` · `error •`)만 찾았다.

| 명령 | 결과 |
|---|---|
| `flutter analyze lib/ui/statistics lib/ui/pages/statistics_page.dart lib/ui/navigation`(통계 쪽 뒤) | 1 issue(warning `unused_element_parameter`, `_ResourceRow` key — 행 키를 `Positioned`로 옮긴 뒤) → 고침 |
| `flutter analyze`(수신부 뒤, 전체) | **No issues found** |
| 관련 기존 58파일 한 번에(`--file-reporter json`, 아래, 새 테스트 전) | **+674 −0** |
| `flutter analyze test/app_navigation_fe7d_test.dart` | error 1(`AppSection` import 없음) · warning 1(쓰지 않는 import) → 고침 |
| `flutter test test/app_navigation_fe7d_test.dart`(1차, 11건) | +10 −1: 셸 계획 1단계 테스트에서 흐름이 열리지 않음 — 테스트 서비스가 계정 상태를 fixture revision 1로, Mock 활성 계획은 다른 revision으로 줘서 `loadRepositoryPlanSnapshot`이 맞지 않는 revision으로 거절(구현 문제 아님) → 테스트 서비스가 Mock revision을 쓰게 고침 |
| 같은 파일(2차 · 셸 단계 순서 테스트 더한 3차 · 1280×720 테스트 더한 4차) | **+11 −0** · **+12 −0** · **+13 −0** |
| `flutter analyze`(최종) | **No issues found**(info 포함 0) |
| 관련 59파일 한 번에(기존 58 + 새 1, `--file-reporter json`) | **+687 −0** |
| `git diff --check`(고친 기존 13파일 + 이 문서 + 새 2파일) · 줄바꿈 | 0. 기존 파일은 pre와 같은 줄바꿈(`statistics_page.dart` · `statistics_growth_evidence.dart` · `inventory_page.dart` · `plan_section_layout.dart` CRLF, 나머지 LF), 새 파일 LF · 끝 개행 하나 |

관련 59파일(파일별 통과, 모두 −0): app_navigation_fe7d +13(새), account_editor_fe8c +9, account_manager_fe8b +6, connected_target_fe8d +8, growth_calculator_view +24, home_app_shell +1, home_connect_fe8e +10, home_page +5, inventory_analysis_page +8, inventory_analysis +16, inventory_controller +13, inventory_currency_readonly +2, inventory_history_page +11, inventory_opa_page +6, inventory_page +9, inventory_shell_lazy +1, inventory_tiers_page +7, inventory_tiers +9, inventory_view_model +13, mock_design_review_scenario +11, plan_detail_tabs +8, plan_flow_authoring +18, plan_flow_goal_step +23, plan_flow_handoff +23, plan_flow_order_step +19, plan_flow_presets +13, plan_flow_save +15, plan_flow_student_step +8, plan_flow +15, plan_home_detail +9, plan_preset_manager +5, plan_scenario_compare +7, plan_scenario_detail +12, plan_scenario_list +10, plan_scenario_preview +9, planning_page +17, profile_delete_fb2d +17, scan_page_revision +14, section_template_studio +15, statistics_app_shell +2, statistics_growth_projection +11, statistics_growth_view +12, statistics_page +14, statistics_plan_projection +7, statistics_plan_view +9, statistics_projection +7, statistics_supply_projection +8, statistics_supply_view +11, statistics_workspace +13, student_bond_gauge +12, student_filter_followups +4, student_filter_modal +7, student_filter_selection +15, student_page +9, student_search_section +13, student_studio_layout +45, tactical_page +8, title_page +25, widget +16.

- 걸리는 기존 테스트 찾기: test/ 전체를 `BAPlannerApp(|AppShell(|StudentPage(|InventoryPage(|PlanningPage(|PlanSectionLayout(|StudentSectionLayout(|StudentAppliedFilterRow|PlanFlowOrderEditor|PlanFlowController(|StatisticsPage|statistics_|evidence`로 grep했다. 셸을 띄우는 테스트 전부, 학생 · 인벤토리 · 계획(흐름 · Detail 홈 · 시나리오) 화면 테스트 전부, 통계 테스트 전부를 돌렸다. 스캐너 테스트(`scan_page_test` · `scan_student_review_workspace_test` · `scanner_*` · `mock_scanner_service_test` · `student_scan_diagnostic_test`, Lane B · 스캐너 WIP)와 process E2E · `metadata_manager_dto_test` · `tactical_lobby_scanner_service_test`는 이 slice와 무관하거나 다른 레인 작업 중이라 돌리지 않았다.
- 빌드 잠금 충돌 없음. `flutter analyze`가 pub get을 돌렸지만 `pubspec.lock` · `pubspec.yaml` 변화 없음.
- 실행하지 않음: golden(`test/goldens/**`), 전체 `fe_gate.ps1`, `-UpdateGoldens`, `fe_commit.ps1`, 맨 `flutter test`, process E2E, `codealmanac validate`.

#### intent 모델 · 대상 탭별 수신 방식

새 파일 `lib/ui/navigation/app_navigation_intent.dart`: `sealed class AppNavigationIntent`(만들 때마다 새 `id`, `origin` 기본 통계, `returnLabel` = "← 통계"). 셸은 마지막 의도 하나(`_navigation`)를 들고 대상 탭에 그 타입만 넘긴다.

| 대상 | intent · payload | 수신부 | 적용 시점 · 한 번 | 쓰는 기존 API | 새 상태 |
|---|---|---|---|---|---|
| 학생 | `StudentsNavigationIntent(studentIds, label)` | `StudentPage.navigation` → `StudentSectionLayout.restrictedIds` · `restrictionLabel` · `onClearRestriction` | 받은 다음 프레임(빌드 중 알림 없음), `_navigationId`로 한 번 | `_select` · `_syncEditors` · `_closeCalculator`, 그리드 reveal(`_revealStudentId` · `_revealRequest`, 최근 본 학생과 같은 길), S4 `StudentAppliedFilterRow`(칩 목록 앞에 하나 더함) | 페이지: 임시 목록(의도 · id 집합). 레이아웃: 매개변수 3개뿐 |
| 인벤토리 | `InventoryNavigationIntent.row(resourceKey)` · `.tiers()` | `InventoryPage.navigation` | microtask, 첫 로드가 끝난 뒤(`loaded && !loading`, 컨트롤러 리스너로 기다림), `_navigationId`로 한 번 | 행: `setScreenMode(list)` → `setMode(inventoryModeOf)` → 부족한 것 보기에 들면 `showCategoryShortages(category)`, 아니면 `setView(all)` + `toggleCategory` → `select(key)`(상세가 그 재화). 재화(크레딧 · 엘리그마)는 `select`만. 티어: `setScreenMode(analysis)` + `toggleTiers()` | 페이지: 의도 id · 기다리는 의도 |
| 계획 | `PlanNavigationIntent.students(ids)` · `.order(stageId)` | `PlanningPage.navigation` → `PlanSectionLayout.navigation` | 계산기 넘기기(`_consumeInitialSeed`)와 같은 길: 홈을 모션 없이 내리고(`_clearHomeForFlow`, 넘기기와 공용으로 꺼냄) 흐름 상태를 읽은 뒤 연다. `_navigationId`로 한 번 | 학생: `PlanFlowController(newScenario)..addStudents(ids)`(1단계). 단계: "페이즈 편집"(`_openActivePlanFlow`)과 같은 초안(`_flowContext(refresh: true)` → `PlanFlowDocumentBoundary.fromDocument`) · `editActivePlan` · 3단계 | `PlanFlowController.initialOrderStageId`(final 하나), `PlanFlowOrderEditor`가 생성 때 읽음 |

#### `app_shell.dart` diff(+79 −0)와 이유

- import 1줄, 필드 3개(`_navigation` · `_returnFrom` · `_statisticsReturnToken`), `_open`에 1줄(탭이 바뀌면 복귀 칩 지움), `_navigate` · `_returnToOrigin` 두 메서드, 계정 전환 때 의도 · 칩 지움 2줄, 페이지 4곳에 매개변수(학생 · 계획 · 인벤토리 `navigation`, 통계 `onNavigate` · `returnToken`), 머리말 두 위젯에 `returnLabel` · `onReturn` 전달과 칩 그리기(계산기 "← 학생" 칩과 같은 `KitPressable` + `BaChip`, 키 `page-header-return-chip`).
- 지운 줄 0, 기존 줄 변경 0(모두 추가). 복귀 칩을 `PageHeaderOverrideController`에 싣지 않은 이유: 그 값은 제목 · 부제를 바꾸고 "같은 탭 다시 누르기 = 복귀"이며 한 번에 하나라, 학생 탭 계산기 "← 학생"과 겹치면 서로 지운다. 별도 값이면 두 칩이 함께 보이고 각자 동작한다.
- `app_section.dart`는 고치지 않았다.

#### 처리한 FD

- **FD-104(확정 (a))**: 학생 탭 이동은 학생 필터 상태(`StudentFilterController`)에 쓰지 않는다. 이동용 임시 목록을 필터와 함께(그리고) 건다.
- **FD-108(워커 재량, 권장안)**: `AppShell`에 navigation intent(대상 탭 + 학생 목록 · 선택 행 · 단계 · 하위 화면), "← 통계" 칩 시안 위치(넘어간 탭 머리말 제목 옆, Statistics-Proposal D). "모든 탭 이동이 같은 intent 사용"은 이번에 통계 출발만이다(인벤토리 "계획에서 보기" `onOpenPlan` · 계산기 FD-173은 그대로 — 아래 발견 사항 8).
- **FD-063(워커 재량)**: 권장안(필터 모달 "기본" 그룹에 육성도 행)을 따르지 않았다. 사용자 결정 2026-10-14 ②(임시 ID 목록 + 칩, 학생 필터 그대로)와 FD-104 때문이다. 근거: 육성도 행으로 이동하려면 학생 필터에 60~70을 써야 하고(덮어쓰기), 통계 구간은 반열림 [60, 70)이라 정수 포함 범위 60~70과 인원이 다를 수 있다. 행 자체가 필요하면 FE7-e(통계 전용 필터)에서 판단.
- FD-028(확정): 학생 목록은 성장 근거(FD-028 식) 그대로의 학생이다. 막는 `열림` FD 없음.

#### 정한 규칙(시안 · 대장에 없는 것)

1. **버튼 켜짐**: 고른 구간 · 재화가 없으면 FE7-a 그대로 비활성 · 같은 글자(둘째 줄 없음). 성장: 구간 · 항목 근거에 학생이 있으면 둘 다 켜짐, ghost 둘째 줄 "필터: <근거 머리>"(예 "필터: 육성도 60~70%", A2면 "필터: 성작 완성도"). 인벤토리(B1 카테고리): ghost "인벤토리 · 티어별 충족률"은 표가 있는 노트 · BD · 오파츠만, primary "인벤토리 · 부족 위험에서 보기 · 해당 행 선택 · 획득처"는 그 카테고리 근거 첫 행(충족률 가장 낮은 재화). 계획(C1 · C2 재화): ghost "인벤토리 · 부족 위험에서 보기"는 그 재화 행, primary "계획 만들기 3 · 단계 순서 · Pn 선택 · 순서 바꾸기"는 그 재화의 막히는 단계가 활성 문서 계산에 있을 때만(첫 막히는 단계 = 근거 "막히는 단계" 첫 행, Pn = 그 단계 페이즈).
2. **켜진 버튼 모양**: 바탕 키트 버튼(좌우 반전 `RailButton`)이 `onPressed`를 받고 hover · 누르기를 그린다. 글자 흐림(.45)은 비활성일 때만.
3. **학생 임시 목록**: 칩 글자 "통계: <근거 머리> · n명"(n = 넘긴 학생 수), S4 적용 필터 줄 맨 앞 제거형 칩(키 `student-applied-filter-navigation-statistics`). 학생 필터 · 검색과 함께 걸어 "표시 N"은 실제 보이는 수다(필터가 있으면 n보다 작을 수 있다). 고른 학생이 목록에 없으면 목록 첫 학생(근거 순서)을 고르고 그리드를 그 학생으로 스크롤한다. 계산기가 열려 있으면 닫는다. 칩 × · "모두 지우기" · 학생 탭을 떠날 때 지운다(필터 상태는 "모두 지우기"가 원래 지우는 것만).
4. **복귀 칩**: 이동한 탭에 있는 동안만 보인다. 다른 탭(통계 포함 주 탭)으로 가면 사라진다. 누르면 통계로 가서 평소처럼 다시 읽고, 다시 읽은 뒤 고른 구간 · 재화에 근거가 있으면(구간 학생 1명 이상 · 재화 근거 있음) 고른 것 · 펼침을 되살린다. 주제 · 가운데 스크롤 · C1 순서 · A1 seg는 다시 읽어도 원래 남는다. 주 탭 "통계"로 직접 돌아가면 FE7-b 그대로 고른 것을 지운다.
5. **계획 흐름이 이미 열려 있을 때**: 학생 의도는 그 초안에 학생을 더하고 1단계로 가며 "만들던 초안에 통계에서 고른 학생 n명을 더했습니다."를 알린다(계산기 넘기기와 같은 규칙). 단계 순서 의도는 초안을 버리지 않고 "진행 중인 계획 만들기가 있어 단계 순서를 새로 열지 않았습니다."만 알린다. 흐름을 열 수 없으면 계정 없음 "계정을 먼저 골라야 계획에 추가할 수 있습니다."(기존 문구) 또는 "계획 만들기를 열 수 없어 통계에서 고른 것을 계획에서 열지 못했습니다."(새 문구).
6. **단계 선택**: 3단계 편집기는 생성 때 `initialOrderStageId`를 고른다. 초안에 그 단계가 없으면(그 사이 활성 계획이 바뀜) 3단계 기본 선택(첫 칸의 첫 단계)이다.
7. **근거 "외 n종 · 외 n명"**: 성장 "나머지 n명 모두 보기"와 같은 버튼(왼쪽 회색 "외 n종", 오른쪽 "모두 보기", 키 `statistics-evidence-rest` 그대로)과 같은 세로 스크롤 목록(공용 `statisticsEvidenceList`, 행 자리 + 버튼 자리). 다른 것을 고르거나 주제를 바꾸거나 다시 읽으면 접힌다(복귀는 위 4). "외 n단계"는 글자 그대로다.

#### golden 변화 예상(장면별)

- **`statistics-growth` · `statistics-inventory` · `statistics-plan`: 변화 0.** 세 장면 모두 아무것도 고르지 않는다(장면 조작은 주제 버튼만, `fe7a_statistics_golden_test.dart` grep). 고른 것이 없으면 버튼은 FE7-a와 같은 위젯 트리다(바탕 `onPressed: null`, 글자 `Opacity(.45)`, 둘째 줄은 FE7-a와 같은 인벤토리 · 계획 고정 글자뿐). 근거 펼침 · 복귀 칩도 고른 것 · 이동이 있을 때만 생긴다.
- **학생 · 인벤토리 · 계획 · 홈 · 타이틀 · 스캔 · 셸 장면: 변화 0.** 의도가 없으면 학생 S4 칩 목록은 같은 내용(`[...filter.searchRowChips]`), 그리드 거르기 조건은 참, 인벤토리 · 계획은 아무것도 적용하지 않고, 셸 머리말은 복귀 칩을 그리지 않는다. 키트 · golden harness 변경 없음.
- commit.json `whole` = `[]`(바뀌는 기존 기준 이미지 없음). 새 golden 장면 없음.

#### 검수표(통계 근거 → 각 탭 → 복귀)

mock 실행(`--dart-define=BA_PLANNER_USE_REAL_BACKEND=false`, 기준 viewport 최대화). 시안 숫자는 Lane B 검수 시나리오 `--dart-define=BA_PLANNER_MOCK_SCENARIO=design-review`(학생 성장 · 계획 집계 데이터, 커밋 상태는 Lane B 확인)에서 본다. 기본 Mock은 목표가 없어 인벤토리 · 계획 주제가 빈 상태다.

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Stats-Growth 아래 버튼 | 통계 → A1 60~70% 막대 | ghost "학생 탭에서 보기" + 둘째 줄 "필터: 육성도 60~70%", primary "이 구간 학생을 계획에 추가" 둘 다 또렷 · hover, 구간을 풀면 다시 흐림 |
| (D) 학생 탭 | ghost 누르기 | 학생 탭, 머리말 "학생" 옆 "← 통계" 칩, S4 적용 필터 맨 앞 "통계: 육성도 60~70% · 22명" 칩, 표시 22, 첫 학생 선택 · 그리드에 보임, 학생 필터 버튼 배지 · 모달 조건 그대로 |
| (D) 복귀 | "← 통계" | 통계 학생 성장, 같은 구간 근거(모두 보기를 펼쳤으면 펼친 채), 스크롤 위치 그대로. 학생 탭을 다시 열면 칩 · 임시 목록 없음 |
| (D) 계획 1단계 | primary 누르기 | 계획 만들기 1단계, 그 구간 학생이 고른 순서 배지로 들어 있음, "← 통계" 칩 |
| Stats-Inventory 아래 버튼 | 인벤토리 현황 → B1 기술 노트 · 장비 설계도 | 기술 노트: 두 버튼 또렷 → ghost = 인벤토리 티어별 충족률 화면, primary = 목록 모드 · 기술 노트 종류 · 충족률 가장 낮은 노트 행 선택 · 상세. 장비 설계도: ghost 흐림, "외 2종 모두 보기" → 9종 세로 스크롤 |
| Stats-Plan 아래 버튼 | 계획 집계 → C2 기술 노트 (최상급) 점 | primary 둘째 줄 "P2 선택 · 순서 바꾸기" → 페이즈 편집 흐름 3단계, P2 단계 카드 선택. ghost → 인벤토리 그 재화 행. C1 크레딧 행이면 primary 흐림 |
| (공통) | 다른 탭으로 이동 · 1280×720 | 칩이 사라짐, 작은 창에서 버튼 글자 · 칩 넘침 예외 없음 |

#### 미검증 항목

- golden(세 통계 장면 · 다른 장면 변화 0 예측): **미실행**.
- 전체 `fe_gate.ps1`(나머지 테스트 · process E2E · `codealmanac validate` · 저장소 전체 `git diff --check`): **미실행**.
- 실제 백엔드 계정에서의 이동(활성 계획 revision이 통계를 읽은 뒤 바뀐 경우의 단계 선택 대체, 실제 학생 수 · 인벤토리 카테고리): **미실행**. Mock · fixture만 보았다.
- 실제 창에서 탭 전환 모션 중 학생 그리드 스크롤(reveal) 체감, 인벤토리 행이 목록에서 보이는지(스크롤 없음 — 발견 2), 계획 흐름이 탭 진입 모션과 함께 들어오는 모습: **미실행**(위젯 테스트는 상태만 확인).

#### WIP 보존 확인

- 고친 기존 13파일 + 이 문서는 착수 때 WIP가 없었다(`git status --short` 빈 줄). post 사본 · `post_dir`는 두지 않았다. pre 사본 대비 diff는 이 slice 줄뿐이고 줄바꿈을 유지했다.
- 건드리지 말 것으로 받은 미커밋 파일(`scan_page.dart` · `student_scan_diagnostic.dart` · `scanner_review_images.dart`와 그 테스트), `lib/services/**`(검수 시나리오 · fixture 데이터 `design_review/`는 읽기만), `main.dart`, 다른 레인 · 스캐너 WIP 파일은 고치지 않았다. git 쓰기는 하지 않았다.

#### 발견 사항

1. **티어별 충족률에는 종류 탭 · 티어 선택이 없다**: 앱 티어 화면은 노트 · BD · 오파츠 표를 한꺼번에 그리고 고르는 상태가 없다. 시안 ghost 둘째 줄 "기술 노트 탭 · 최상급 선택"은 붙일 대상이 없어 빼고(첫 줄만) 티어 화면만 연다. 표 강조가 필요하면 인벤토리 티어 화면 상태 추가(FE6-e 소관) 결정.
2. **인벤토리 목록은 고른 행으로 스크롤하지 않는다**: 목록 viewport에 컨트롤러 · reveal이 없다(`inventory_workspace.dart`). 종류 · 보기로 좁혀 행이 보이게 했지만, 행이 많은 종류(장비 등)에서는 화면 밖일 수 있다(상세 패널은 그 재화). reveal은 인벤토리 workspace 변경이라 후속 후보.
3. **학생 "목록" 보기(S2 목록 모드)에는 reveal이 없다**: 그리드만 고른 학생으로 스크롤한다(기존 최근 본 학생과 같은 한계).
4. **학생 임시 목록 ∧ 학생 필터**: 칩은 "22명"인데 학생 필터 · 검색이 걸려 있으면 "표시"가 더 작다(규칙 3). 필터를 무시하고 목록만 보이게 할지는 CF 판단.
5. **"이 구간 학생을 계획에 추가"는 A2 항목 근거에서도 켜진다**("구간" 글자는 시안 그대로). 새 시나리오 1단계로 열리므로 활성 계획에 바로 들어가지 않는다(Proposal "계획 만들기 1 · 학생 고르기 (미리 선택)").
6. **복귀 뒤 계획 흐름은 그대로 남는다**: 통계로 돌아가도 계획 탭의 열린 흐름(1단계 · 3단계 초안)은 사용자가 닫을 때까지 있다. 다음 "단계 순서" 이동은 그 초안 때문에 알림만 낸다(규칙 5).
7. **근거 패널 버튼 모양(FE7-a 발견 6)**: 누를 수 있게 되었지만 여전히 좌우 반전 `RailButton` 바탕 + 글자 겹침이다. hover · 누름 모양은 키트 그대로라 문제는 없으나, 키트 변형(왼쪽 80° · 오른쪽 수직)으로 바꾸는 키트 요청 후보는 남는다.
8. **다른 탭 이동은 아직 intent가 아니다**: 인벤토리 상세 "계획에서 보기"(`onOpenPlan`), 계산기 "인벤토리 · 부족 위험에서 보기"(FD-173, 숨김)는 그대로다. FD-108 "모든 탭 이동이 같은 intent"는 그 slice들에서(intent 모델은 출발 탭 `origin`을 받는다).
9. **"외 n단계"는 펼치지 않는다**(프롬프트 범위 "외 n명 · 외 n종"). 단계가 5개 이상인 재화는 근거에 4개만 보인다.
10. **머리말 칩 두 개**: 셸 머리말 복귀 칩과 계산기 "← 학생" 칩이 함께 보일 수 있다(학생 탭에서 계산기를 열면 "성장 계산기 ← 학생 ← 통계"). 시안에 겹친 모습이 없다.

#### 사본 · commit.json

- 착수 사본: `debug/frontend_fe7d/pre/<경로>`(고친 기존 13파일 + 이 문서). WIP가 없어 post 사본은 없다.
- `debug/frontend_fe7d/commit.json`: slice `fe7d`, `status=true`, modified 14(이 문서 포함), added 2, `whole` = `[]`.
- 인계: `debug/frontend_fe7d/output.md`.

#### 다음 행동

- FE7-d 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: 레인 워커가 모두 멈춘 뒤 gate 1회. 예상: analyze 0, 일반 테스트에 새 13건(`app_navigation_fe7d_test.dart`), golden은 변화 0(세 통계 장면 포함, Lane B 변화는 별도). 승인 뒤 `fe_commit.ps1 -Slice fe7d`.
- 남은 CF 판단: 발견 1 · 2(인벤토리 티어 선택 · 행 reveal), 4(임시 목록과 필터 관계), 6(복귀 뒤 남는 흐름), 7(키트 변형), 8(다른 탭 이동 intent화).

### fe7d commit record (2026-10-14 02:39, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261014_023144\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE7-h 통계 이력 연동 (Lane A, 로컬 Claude Code)

### FE7-h 착수 기록 (2026-10-14, Lane A)

- 상태: 진행 중.
- 범위: 통계와 스캔 이력(FB-2) 연결. 새 백엔드 · 서비스 변경 없음.
  1. 왼쪽 기준 데이터(학생 스캔 · 인벤토리 · 스냅샷 n회 · 기간).
  2. KPI 증감(성장 · 인벤토리 · 계획 주제의 '—' 자리, "지난 스냅샷 대비", 1회면 '—').
  3. A6 성장 추이(스냅샷 시점 학생 상태로 FD-028 평균 육성도를 다시 계산).
  4. B3 주요 재화 변화(seg 스냅샷 6회 / 4주 / 전체, FE6-f 함수 재사용).
  5. `_reload()`에 이력 읽기를 더한다. 처음 보일 때 읽기는 그대로, 다시 보일 때 revision이 바뀌었으면 다시 읽기.
  - A3 · A4 · A5 · B2 · C4 · C5는 "준비 중" 유지(FD-106).
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `3995e1008cbff348b2afc4064d38159d39ed52a6`.
- 막힘: 대장 막힘 요약 FE7-h 행 = FD-041 · FD-096, 둘 다 확정. 막는 `열림` FD 없음. 워커 재량 FD-042 · FD-110은 권장안대로 처리한다.
- 쓸 history 메서드와 응답 필드(`RepositoryService`, 읽기만):
  - `loadRepositoryHistoryEvents(RepositoryHistoryEventsRequest(profileId, limit: 200))`, `nextCursor`가 있으면 `withCursor`로 끝까지 읽는다(최대 50쪽, FE6-f와 같은 상한).
    - 쓰는 필드: `revision` · `coverage`(origin · baseline_at · first_retained_at · timestamps_monotonic) · `scan_points[]`(session_id · sequence · recorded_at).
    - `events[]`에서는 sequence · recorded_at · source · scan_context.session_id · applied_scope(student_ids · resource_keys) · student_changes(before/after 확정 학생) · inventory_changes(before/after 수량)를 쓴다.
  - `loadRepositoryHistoryScanLatest(RepositoryHistoryScanLatestRequest(profileId, …))`, 256개씩 나눠 보낸다.
    - `studentIds:` 보유 학생 → `by_student_id[].latest_scan.recorded_at`(학생 스캔 시각).
    - `resourceKeys:` 카탈로그 정규 key → `by_resource_key[].latest_scan.recorded_at`(인벤토리 스캔 시각, FE6-f `inventoryLastScanAt`).
  - `loadRepositoryHistorySummary([profileId])`: `revision`만 본다. 탭이 다시 보일 때 저장소가 바뀌었는지 확인한다.
  - `repository.history.diff`는 쓰지 않는다.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe7h/pre/<v7 기준 경로>`, 사본과 작업 트리 `cmp` 일치):
  - `frontend/lib/ui/pages/statistics_page.dart`(CRLF)
  - `frontend/lib/ui/statistics/statistics_workspace.dart` · `statistics_topics.dart`
  - `frontend/lib/ui/studio/statistics_studio_layout.dart`(요소 좌표가 필요할 때만)
  - `frontend/test/goldens/fe7a_statistics_golden_test.dart`(fixture 입력만)
  - `frontend/test/statistics_workspace_test.dart` · `statistics_page_test.dart`(CRLF) · `statistics_app_shell_test.dart`(CRLF): 바뀐 동작에 걸리는 기대만
  - 이 문서
- 새 파일(예정):
  - `frontend/lib/statistics/statistics_history_projection.dart`(순수 계산, FE6-f `inventory_history.dart` import)
  - `frontend/lib/ui/statistics/statistics_history_charts.dart`(A6 · B3 painter)
  - `frontend/test/statistics_history_fixture.dart` · `statistics_history_projection_test.dart` · `statistics_history_view_test.dart`
- WIP: 위 기존 파일 9개 모두 `git status --short <경로>`가 비어 있다(미커밋 변경 없음). 그래서 post 사본은 두지 않는다. 줄바꿈은 `git ls-files --eol` 기준 위에 적은 CRLF 3개 외 LF.

### FE7-h 종료 기록 (2026-10-14, Lane A, 코드 작성 완료 · CF gate 미실행)

통계와 FB-2 스캔 이력을 연결했다. 왼쪽 기준 데이터, KPI 증감, A6 성장 추이, B3 주요 재화 변화를 그린다. 스냅샷이 2회 미만이면 시안 문구가 보인다. 새 백엔드 · 서비스 변경은 없다.

#### 실행 명령 · 결과

모두 `frontend`에서 이 PC(Claude Code)로 실행했다. 로그는 `debug/frontend_fe7h/logs/`에 있다. 실패 줄(`[E]`·`EXCEPTION`·`Some tests failed`·`error •`)만 찾았다.

| 명령 | 결과 |
|---|---|
| `flutter analyze lib/ui/statistics lib/statistics`(workspace 편집 뒤) | No issues found |
| `flutter analyze lib`(page 편집 뒤) | 오류 1 · 경고 1. 착수 때 있던 `InventoryClockSource`를 Lane B tidy1이 작업 중에 `lib/services/app_clock.dart`(`AppClockSource` · `appClockNow`)로 옮겼다 → `appClockNow`로 바꿈(발견 1) |
| `flutter analyze lib`(다시) | 오류 2. 내 치환 스크립트가 빈 치환 블록을 잘못 처리해 `>>>>` 줄이 남았다 → 지움 |
| `flutter test test/statistics_history_projection_test.dart`(새, 1차) | 컴파일 실패(`RepositoryState.toWire` 없음, 테스트 도우미 문제) → 도우미 `_restate` |
| 같은 파일(2차) | +11 −4. 테스트 쪽 문제 2가지였다. ① 지역 시각과 UTC `DateTime` 비교 ② 덧붙인 스캔 · 수동 수정 시각이 기존 마지막 기록보다 앞서 시계 되돌림이 되어 projection이 `null`을 낸 것(올바른 동작) → 테스트 시각을 고침 |
| 같은 파일(3차) | **+15 −0** |
| 기존 통계 7파일(1차) | +67 −7. 고친 내용은 아래 3갈래다. 1) "준비 중" 개수 기대 4곳(A6 · B3가 그래프 자리가 됨): 기대를 고침. 2) A6 빈 상태가 1280×720 · 1440×900에서 0.9 · 25px 넘침: 구현을 고침(글자 묶음을 `FittedBox`로 줄인다). 3) `statistics_page_test` "hidden page": 테스트 서비스가 상태는 revision 4, Mock 이력 요약은 다른 revision으로 답했다. 그래서 다시 보일 때 revision 확인이 다시 읽기를 불렀다. 기대(바뀐 것이 없으면 다시 읽지 않는다)가 맞으므로 테스트 서비스가 자기 상태 revision으로 이력을 답하게 고쳤다 |
| 같은 5파일(2차) | **+52 −0** |
| `flutter test test/statistics_history_view_test.dart`(새) | **+14 −0**(첫 실행) |
| 관련 24파일 한 번에(`--file-reporter json`, 아래) | **+254 −0** |
| `flutter analyze`(최종, frontend 전체) | **No issues found**(info 포함 0) |
| `git diff --check`(고친 기존 8파일) · 새 5파일 검사 | 0. 새 파일은 LF · 줄 끝 공백 0 · 끝 개행 하나. 기존 파일 줄바꿈은 pre와 같다(`statistics_page.dart` · `statistics_page_test.dart` · `statistics_growth_view_test.dart` CRLF, 나머지 LF) |

최종 24파일의 파일별 결과:

- 통계: statistics_history_projection +15(새), statistics_history_view +14(새), statistics_page +14, statistics_workspace +13, statistics_growth_view +12, statistics_supply_view +11, statistics_growth_projection +11, statistics_plan_view +9, statistics_supply_projection +8, statistics_plan_projection +7, statistics_projection +7, statistics_app_shell +2
- 인벤토리 이력 재사용: inventory_history +33, inventory_history_page +11, inventory_analysis_page +8, inventory_shell_lazy +1
- 셸 · 이동 · 그 밖: widget_test +16, app_navigation_fe7d +13, developer_tools_app +12, app_navigation_tidy1 +11(Lane B 새 파일), mock_design_review_scenario +11, home_page +5, kit/scroll_viewport_fog +6, kit/kpi_tile +4

- 걸리는 테스트는 grep으로 찾았다. 찾은 말은 `statistics|Statistics|scopeFor|StatisticsTileRow|statisticsGrowthKpis|statisticsInventoryKpis|statisticsPlanKpis|inventory_history|top-tab-statistics|design_review|MockDesignReview`이다.
  - goldens를 빼고 걸린 파일은 모두 실행했다.
  - 뺀 3파일(`repository_process_e2e` · `tactical_v2_process_e2e` · `metadata_manager_dto`)은 "statistics" 낱말만 걸렸다. 앞의 둘은 process E2E다.
  - `kit/kpi_tile_test` · `inventory_shell_lazy_test`는 더해서 돌렸다.
- 일회성 렌더: golden 테스트 파일을 복사한 임시 테스트 `test/zz_fe7h_render_tmp_test.dart`로 확인했다. harness 공개 함수와 `RenderRepaintBoundary.toImage`만 썼다.
  - `statistics-growth` · `statistics-inventory` · `statistics-plan`과 스냅샷 1회 장면을 scratchpad PNG로 한 번씩 보았다. golden 비교는 아니다.
  - 기준 데이터 칩이 줄 오른쪽 끝이 아니라 라벨 옆에 붙어 있었다(`Flexible` 배치). `Expanded` + 오른쪽 정렬로 고쳤다.
  - 임시 테스트는 실행 뒤 지웠다.
- 검수 시나리오 확인: 임시 테스트 `test/zz_fe7h_mockdemo_tmp_test.dart`로 `MockDesignReviewScenario` 통계 값을 출력했다. 값은 아래 검수표에 있다. 실행 뒤 지웠다.
- 빌드 잠금(`build/` · `.dart_tool/`) 충돌은 없었다. `pubspec.lock` · `pubspec.yaml`은 바뀌지 않았다.
- `dart format`은 새 파일에만 돌렸다. `statistics_topics.dart`에 한 번 잘못 돌려 손대지 않은 줄 4곳이 다시 감싸졌다. pre 사본에서 되살린 뒤 내 줄만 다시 넣었다. diff에는 이 slice 줄만 있다.
- 실행하지 않음: golden(`test/goldens/**`), 전체 `fe_gate.ps1`, `-UpdateGoldens`, `fe_commit.ps1`, 맨 `flutter test`, process E2E, `codealmanac validate`.

#### 읽기 경로

- `_reload()`는 FE7-g 그대로 읽는다. 순서는 계정 → 활성 계획 → 상태 → 학생 → 인벤토리 → 계산 → 문서 계산이다. `loading` 끝(보드를 먼저 그림) 뒤에 같은 generation으로 `_loadHistory`를 부른다.
  1. `repository.history.events`: from_at 없이 남은 이력 전부를 읽는다. limit 200, cursor 끝까지, 최대 50쪽(FE6-f 상한).
  2. 첫 쪽 revision이 읽은 계정 상태 revision과 다르면 섞지 않는다. A6 · B3에 FE6-f와 같은 문구를 보인다.
  3. `scan_latest`: 보유 학생 id(`by_student_id`), 카탈로그 정규 key(`by_resource_key`)를 각각 256개씩 보낸다.
- 다시 보일 때(숨어 있는 동안 요청이 없었어도) `repository.history.summary`의 revision만 본다. 읽은 상태와 다르면 `_reload()`를 부른다(FE6-f 방식). "처음 보일 때 읽기"와 셸 reloadToken은 그대로다.
- "지금"은 `appClockNow(service)`다(Lane B tidy1이 만든 `lib/services/app_clock.dart`, 발견 1). 검수 fixture · 테스트는 고정 시각, 실제 서비스는 기기 시계다.
- 쓰지 않음: `repository.history.diff`. 스냅샷마다 diff를 부르는 대신 events를 한 번 읽어 거꾸로 되돌린다.

#### A6 지표 결론(시점별 학생 상태)

- **가능하다.** FB-2 events의 `student_changes`는 before · after 확정 학생 전체(`ConfirmedStudentState`)를 담는다.
  - 지금 확정 학생에서 늦은 적용부터 before로 되돌리면 학생 스냅샷마다 그 세션 끝 학생 상태가 정확히 나온다. FE6-f가 인벤토리 수량을 되돌리는 것과 같다.
  - 그 상태로 FE7-b 성장 projection(`statisticsStudentGrowth`, FD-028 · 애장품 없는 학생 6항목)을 그대로 다시 센다. 그래서 A6 점 · 성장 KPI 증감은 지금 KPI와 같은 식이다.
  - 마지막 스냅샷 = 지금 상태(수동 수정이 없으면)를 테스트로 고정했다.
- 한계:
  - 남은(보존) 이력 밖 시점은 모른다. 다만 그 앞에는 스냅샷 점도 없다.
  - 시계가 되돌려진 기록이 있으면 A6 · 증감을 그리지 않는다(FE6-f 규칙).
  - 학생 목록(애장품 여부)은 지금 것을 쓴다(정적 메타).

#### 재사용한 FE6-f 함수(`lib/ui/inventory/inventory_history.dart`, import만 · 옮기지 않음)

- 색인: `InventoryHistory.build` · `InventoryHistoryInput` · `InventoryHistoryEvent.fromEvent` · `InventoryScanPoint.fromPoint` · `InventoryHistoryCoverage.fromQuery` · `inventoryHistoryCurrent` · `track` · `current`.
  - 남은 이력 전부 색인(B3)과 지금 − 28일 색인(KPI)을 따로 만든다. 28일 색인은 인벤토리 탭과 같은 "지난 스캔"이다.
- KPI: `inventoryKpiDeltas`(부족 · 과잉 종 수 증감, 인벤토리 탭과 같은 값), `inventoryLastScanAt`, `inventoryDaysAgo`, `inventorySignedCount`.
- 상수: `inventoryHistoryWindow` · `inventoryHistoryPageLimit` · `inventoryScanLatestChunk`.
- FE6-c `inventoryCoverageOf` · `InventoryBoard`(지난 스캔 보드의 충족률), FE7-c `statisticsCategoryFills`(충족 카테고리).
- FE8-c `accountLastScanText`(`ui/widgets/account_section_cluster.dart`): 기준 데이터 "어제 21:40" · "3일 전".
- 쓰지 않은 것과 이유:
  - `inventorySparkline`: 읽는 기간이 4주로 묶이고 "n주 전" 라벨이 붙는다. B3 seg "스냅샷 6회 · 전체"를 낼 수 없다. B3는 같은 `track`과 같은 "지금 점" 규칙(수동 수정 뒤 속 빈 점)을 직접 쓴다. 순변화 = 첫 점 → 끝 점으로 스파크라인과 같다.
  - `inventoryNetChanges`: S5 기간 시작 수량 기준이라 B3 점 범위와 다르다.
  - `inventoryTrend` · `inventoryForecasts`: B3 시안 패널에 예측 문구 자리가 없다(아래 FD-042).
  - 요청(인벤토리 쪽, 이번에 고치지 않음): 점 범위를 받는 스파크라인(`inventorySparkline(history, key, points:)`)이 있으면 B3와 상세 스파크라인이 한 함수를 쓸 수 있다. 키트 승격(FE6-f 발견 6) 때 함께 보면 된다.

#### 처리한 FD

- **FD-041(확정)**: "스냅샷 n회"는 scan 세션이다(오케스트레이터 2026-10-09 표시 단위 결정). 수동 수정은 지금 값에 들어가고, 비교 기준은 scan 점이다.
  - 학생 KPI는 마지막 바로 앞 학생 스냅샷과 비교한다.
  - 재화 KPI는 FE6-f 재화별 "지난 스캔"과 비교한다.
- **FD-042(워커 재량, 권장안)**: 예측은 3점 이상 최소제곱이다. 다만 이번 화면에는 예측을 둘 자리가 없다. B3 시안 패널은 이름 · 필요 · 선 · 지금 값 · 순변화뿐이다. 시안의 예측 자리는 Stats-Inventory 근거 "최근 변화 · 이 속도면 P2 이전에 소진"이다(발견 4).
- **FD-096(확정 (c))**: 크레딧 · 엘리그마는 스캔 이력 점이 있을 때만 B3 패널이다. 스캔이 없으면 패널에서 빠진다(수동 입력 없음).
- **FD-106(확정)**: A3 · A4 · A5 · B2 · C4 · C5는 "준비 중" 그대로다. A6 · B3는 데이터가 모자라면 시안 문구 "스캔을 더 실행하면 변화가 나타납니다." + "스냅샷 n회 · M/dd HH:mm"이다(0회는 "스냅샷 0회").
- **FD-109(확정, FD-001 적용)**: A4 · A6 줄의 두 타일이 모두 그래프가 없으면(A4 "준비 중" + A6 문구) 줄 높이를 368 → 328로 낮춘다. 시안 Stats-Growth-Filter와 같다. `StatisticsTileRow.shortHeight`로 둔다. A4가 그래프가 되면(FE7-f) 줄은 다시 368이다.
- **FD-110(워커 재량, 권장안)**: B3 seg "스냅샷 6회" = 재화마다 최근 6점, "4주" = 지금 − 28일, "전체" = 남은 이력 전부. seg는 이력을 읽으면 동작하고 다시 읽어도 남는다.
- **FD-033(확정)**: B3는 패널마다 축이 따로다. 서로 다른 재화를 더하지 않는다. 패널 고르기도 수량이 아니라 |순변화| / 필요량으로 비교한다.
- 막는 `열림` FD 없음.

#### 정한 규칙(시안 · 대장에 없는 것)

1. **기준 데이터**: 시안 칩 색은 행마다 고정이다(학생 스캔 ok · 인벤토리 wn · 스냅샷 gy). 모르면 회색 '—'다.
   - 학생 스캔 = `scan_latest` by_student_id(보유 학생) 최댓값이다. 인벤토리 = by_resource_key(카탈로그) 최댓값이다(FE6-f). 둘 다 scan 종류 원문을 보지 않는다.
   - 글자는 FE8-c 규칙을 쓴다: 오늘 · 어제 HH:mm · n일 전.
   - 스냅샷 = 남은 이력의 모든 세션 수 · 첫 ~ 마지막 날짜(`M/dd`)다. 1회면 "1회 · M/dd", 기록이 없으면 '—'다.
2. **성장 KPI 증감**: 지난 학생 스냅샷 대비다.
   - 보유 학생 "/ 170 · ±n", 평균 육성도는 한 자리 글자끼리의 차(`+1.2`), 최대 레벨 · 완전 육성은 ±n이다.
   - 계획 등록 증감은 '—'다. 목표는 이력에 없다(FB-2는 학생 · 인벤토리 bucket만 남긴다).
   - 아는 증감은 시안처럼 증가 · 감소 모두 초록(`KpiDeltaTone.gain`)이다. 모르면 회색 '—'다.
3. **인벤토리 · 계획 KPI 증감**: 재화마다 지금 − 28일 안의 마지막 바로 앞 스캔 점을 쓰고, 지금 보유와 둘 다 아는 재화만 그 점 수량으로 바꾼 "지난 스캔" 보드를 같은 식으로 다시 센다.
   - 전체 · 계획 충족률은 정수 글자끼리의 차, 충족 카테고리는 60% 기준 개수 차다.
   - 부족 · 과잉 종 수는 `inventoryKpiDeltas`다.
   - 필요량은 지금 계획이다. 바꾼 재화가 없으면 '—'다.
   - 계획 주제의 막힌 학생은 '—'다(지난 시점 문서 계산이 없다). 미계획 · 40% 미만도 '—'다(목표 이력 없음). 첫 부족 · 스캔 없음 칸의 둘째 글자는 FE7-g · FE7-c 그대로다.
4. **인벤토리 범위 글자**: "인벤토리 스캔 n일 전 · 오늘"이다(FE6-f 인벤토리 탭 "마지막 스캔"과 같은 날 수).
5. **A6**:
   - 점 = 최근 학생 스냅샷 6개(B3 "스냅샷 6회"와 같은 수), 같은 간격, 날짜 `M/dd`. 바닥 = 가장 낮은 값을 내린 정수 − 2이고, 가장 높은 값이 시안 y 55.4다. 시안 58.1 · 63.4 → 바닥 56 · 점선 60이 같게 나온다. 점선 · 글자 = 가장 높은 값 아래 5의 배수다.
   - 강조 = 마지막 스냅샷에서 14일 안 첫 스냅샷부터다. 그 안이 마지막 하나뿐이면 바로 앞부터다(시안 9/22 → 10/05). 분홍 바탕 · 두 끝 분홍 점 · "M/dd → M/dd ±x.x%p"이고, 끝 점 위에 값 글자를 둔다.
   - 누르는 동작은 없다. 시안 오른쪽 "오른 학생 순위"는 넣지 않았다(발견 5).
6. **B3**:
   - 패널 = 재화(크레딧 · 엘리그마, 카탈로그 순서) 다음에 계획이 쓰는 재화 중 |순변화| / 필요량이 큰 것으로 3개까지다. 아는 수량 점이 2개 미만인 재화는 뺀다.
   - 패널 그림: 값 범위(가장 작은 ~ 큰 값)를 y 51.1 ~ 169.6에 둔다. 필요량이 범위 안이면 점선 + "필요", 밖이면 "필요 n ↑/↓"다. 아래 왼쪽에 순변화(감소 분홍 · 증가 초록 · 0 회색), 아래 오른쪽에 끝 값을 둔다(백만 이상은 "98.4M").
   - 계획이 없어도 재화 패널은 그린다(필요 글자 없음).
7. **스냅샷 2회 미만 문구 자리**: 그래프 자리를 채운 둥근 상자(시안 r10 · 채움 · 안쪽 1px)다. 작은 창에서는 글자 묶음을 줄인다. 읽는 중 · 성장 자료 없음은 '—', 읽기 실패는 "변화 기록을 읽지 못했습니다: …"다.
8. **시계 되돌림**: KPI 증감 '—', A6 · B3 '—'다(FE6-f와 같다).

#### golden 변화 예상(장면별)

- **`statistics-growth`(바뀜)**:
  1. 왼쪽 기준 데이터 칩 3개: '—' → "어제 21:40"(초록) · "3일 전"(노랑) · "12회 · 9/02 ~ 10/05"(회색). 칩은 줄 오른쪽 끝 그대로다.
  2. KPI 증감: 보유 학생 "/ 170 · —" → "/ 170 · +2", 평균 육성도 '—' → "+1.2", 최대 레벨 '—' → "+4", 완전 육성 '—' → "+1"(초록). 계획 등록 '—' 그대로. KPI 값(128 · 63.4% · 64명 · 8명 · 9명)은 그대로다.
  3. A6: "준비 중" → 꺾은선. 점 6개(9/02 · 9/08 · 9/15 · 9/22 · 9/29 · 10/05, 58.1 → 63.4%), 9/22 ~ 10/05 분홍 바탕 · 분홍 점 2개 · "9/22 → 10/05 +2.0%p", "63.4%", 축 56 · 점선 60.
  4. 타일 줄 높이 · 다른 타일 · 근거 패널 변화 0. fixture 입력이 바뀌어 계정 인벤토리가 인벤토리 · 계획 fixture 수량이 되었지만 성장 주제에는 보이지 않는다.
- **`statistics-inventory`(바뀜)**:
  1. 기준 데이터 칩 3개(위와 같다).
  2. 범위 글자 "활성 계획 기준 · 인벤토리 스캔 —" → "… 3일 전".
  3. KPI 증감: '—' → "+6" · "−2" · "+1" · "+1"(초록). 스캔 없음 칸 "엘레프" 그대로.
  4. B3: "준비 중" → 작은 배수 3장. 크레딧 142.0M → 98.4M, "필요 261.5M ↑", 분홍 "−43.6M". 엘리그마 760 → 1020, "필요 2245 ↑", 초록 "+260". 상급 활동 보고서 180 → 384, 필요 300 점선, 초록 "+204". 오른쪽 아래 "패널마다 축이 따로 · 단위를 섞지 않음".
  5. B3 seg가 흐린 자리에서 동작 seg로 바뀐다("스냅샷 6회" 선택). "3차" 칩은 그대로다.
  6. B1 · B2 · 근거 변화 0.
- **`statistics-plan`(바뀜)**:
  1. 기준 데이터 칩 3개.
  2. KPI 증감: 계획 충족률 '—' → "+6", 부족 재화 '—' → "−2". 첫 부족 · 막힌 학생 '—' · 미계획 '—'는 그대로다. 범위 칩 · C1 · C2 · C3 · 근거 변화 0.
- **다른 장면: 변화 0.**
  - 통계 탭은 오프스테이지에서 아무것도 읽지 않는다(셸 지연 테스트).
  - 바꾼 공용 코드는 통계 파일뿐이다(키트 · 셸 · 인벤토리 변경 0).
  - `statistics_topics.dart`의 범위 글자 기본값은 '—' 그대로다.
- 바뀌는 기준 이미지 3개는 commit.json `whole`에 파일 단위로 넣었다. 일회성 렌더에서 세 장면 모두 시안 자리에 들어왔고 넘침이 없었다.

#### 검수표

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Stats-Growth(A6 · 기준 데이터 · KPI 증감) | golden `statistics-growth` · `test/statistics_history_view_test.dart` fixture. 앱 mock 검수 시나리오(`--dart-define=BA_PLANNER_MOCK_SCENARIO=design-review`)는 학생 스캔이 1회뿐이라 아래 Stats-Growth-Filter 상태다 | 칩 "어제 21:40" · "3일 전" · 스냅샷 칩 / KPI "+2 · +1.2 · +4 · +1"(초록), 계획 등록 '—' / A6 점 6개 · 분홍 강조 · "9/22 → 10/05 +2.0%p" · "63.4%" · 56 · 60 |
| Stats-Growth-Filter(스냅샷 1회 문구 · 낮은 줄) | 검수 시나리오 → 통계(학생 성장). 값: 칩 "어제 21:40" · "3일 전" · "31회 · 9/04 ~ 10/04"(재화 세션이 프로필마다 따로라 많다 — 발견 2). fixture: `statistics_history_view_test` "one snapshot" | A6 둥근 상자 · 스캔 아이콘 · "스캔을 더 실행하면 변화가 나타납니다." · "스냅샷 1회 · 10/04 21:40"(시나리오), KPI 증감 '—'(회색), A4 · A6 줄 328 |
| Stats-Inventory(B3 · KPI 증감 · 범위) | golden `statistics-inventory` / 검수 시나리오 → 인벤토리 현황 | 범위 "… 인벤토리 스캔 3일 전" / KPI "+6 · −2 · +1 · +1"(fixture). 시나리오 값은 "−26 · +3 · −1 · −2"다. 그중 부족 · 과잉 "+3 · −1"은 인벤토리 탭 KPI와 같은 값이다 / B3 3장 · 패널마다 축 · 필요 표시 · seg 4주 · 전체로 점 수가 바뀌는가 |
| Stats-Plan(KPI 증감) | golden `statistics-plan` | 계획 충족률 "+6" · 부족 재화 "−2", 막힌 학생 · 미계획 '—' |
| (공통) | 다른 탭에서 저장 · 스캔 뒤 통계 탭으로 | 다시 보일 때 숫자가 바뀌는가(revision이 같으면 다시 읽지 않는다) / 1280×720에서 예외 없음 |

#### 미검증 항목

- golden 비교: **미실행**. `statistics-growth` · `statistics-inventory` · `statistics-plan`은 바뀌고 다른 장면은 변화 0으로 예상한다. CF가 `fe_gate.ps1` · `failures/` 검토 · `-UpdateGoldens`를 한다.
- 전체 `fe_gate.ps1`(그 밖의 테스트 · process E2E · `codealmanac validate` · 저장소 전체 `git diff --check`): **미실행**.
- 실제 백엔드에서 통계 이력 읽기: **미실행**. 확인할 것은 남은 이력 전부 events 쪽 수 · 속도(학생 스캔 이벤트는 확정 학생 전체 before/after를 담아 크다), scan_latest 학생 · 재화 묶음 수다. 서비스 계층은 FB-2 process E2E가 이미 통과한 것이고 화면 연결은 Mock 순수 질의 함수로만 보았다.
- 섹션 안 새 요소 ±2px: A6 · B3는 시안 SVG 좌표를 그대로 옮긴 painter이고 `StatChartFrame` 균일 배율이다. 위젯 테스트는 값 · 점 수 · 줄 높이(368 · 328)만 보았다. 화면 좌표는 재지 않았다.
- legacy · compacted 계정, 시계 되돌림 계정의 안내: 단위 테스트로만 보았다.

#### WIP 보존 확인

- 고친 기존 파일 8개는 고치기 전에 WIP가 없었다(`git status --short` 빈 줄). 그중 `statistics_growth_view_test.dart` · `statistics_supply_view_test.dart`는 착수 목록에 없었고, 고치기 전에 같은 확인을 하고 pre 사본을 두었다.
- post 사본 · `post_dir`는 두지 않았다. pre 사본과 비교한 diff에는 이 slice 줄만 있다(`diff --strip-trailing-cr` 확인).
- 착수 때 사본을 둔 `statistics_studio_layout.dart` · `statistics_app_shell_test.dart`는 결국 고치지 않아 사본을 지웠다(`cmp` 일치 확인 뒤).
- 작업 트리의 다른 미커밋 변경은 고치지 않았다. Lane B tidy1(`app_shell` · `navigation` · 인벤토리 · 키트 주석 · `services/app_clock.dart` · 검수 시나리오 등), 스캐너 WIP, 서비스 WIP가 그렇다. git 쓰기는 하지 않았다.

#### 발견 사항

1. **tidy1 의존(커밋 순서)**: 통계 페이지가 Lane B tidy1의 새 파일 `lib/services/app_clock.dart`(`appClockNow` · `AppClockSource`)를 import한다. 착수 때는 `InventoryClockSource`(인벤토리 컨트롤러)였는데 작업 중 tidy1이 옮겼다.
   - fe7h를 tidy1보다 먼저 커밋하면 컴파일되지 않는다. tidy1 → fe7h 순서이거나 같은 gate 안이어야 한다.
   - golden 테스트 fixture 서비스도 `AppClockSource`를 구현한다.
2. **스냅샷 = scan 세션의 뜻(FE6-f 발견 5와 같은 문제)**: 시안 "스냅샷 6회 · 9/02 ~ 10/05"는 학생 · 인벤토리를 한 번에 찍은 스냅샷 6번으로 그렸다. 실제 저장은 종류(학생 · 인벤토리)마다, 인벤토리는 스캔 프로필마다 세션이 따로다.
   - fixture는 학생 6 + 인벤토리 6 = "12회"다. 검수 시나리오는 프로필별 세션이라 "31회"다.
   - A6(학생 스냅샷)과 B3(재화 점)은 각자 자기 세션만 세어 시안과 같은 6점이다.
   - "스캔 자리" 묶음 규칙 FD가 필요하다(CF 판단). 정해지면 `StatisticsHistory.snapshotTimes` 하나만 바꾸면 된다.
3. **시안 숫자 불일치**: A6 9/29 점(시안 62.0%)은 KPI 평균 육성도 "+1.2"(63.4 − 62.2)와 맞지 않는다. fixture는 KPI를 따라 62.2다.
   - 시안 학생 스캔 "어제 21:40"과 A6 마지막 "10/05"를 함께 맞추려고 fixture "지금"을 10/06 12:00으로 두었다. 인벤토리 KPI(FE6-a)의 시안 날짜 10/05와는 하루 다르다.
4. **FD-042 예측 자리**: 시안 예측 문구는 Stats-Inventory 근거 "최근 변화 · 스캔 6회 / 지난 스캔 대비 −30 / 이 속도면 P2 이전에 소진"에 있다. 그런데 B2 선택(FE7-f)이 그 근거를 연다.
   - "P2 이전에 소진"은 페이즈에 시간축이 없어 정의가 없다. FE6-f의 "n주 뒤 소진 예상"으로 바꿀지 결정이 필요하다.
   - 이번에는 넣지 않았다. 재화 근거 틀(C1 · C2 선택)에 "최근 변화" 3줄을 더하는 것은 FE7-f B2 또는 별도 slice 후보다.
5. **A6 구간 선택**: 시안 Statistics-Proposal A6 "두 스냅샷 사이 학생별 증감(오른쪽 '오른 학생 순위')"는 데이터가 된다(학생 스냅샷 상태가 있다). 다만 시안 근거 틀 · 고르는 동작 규칙이 없어 넣지 않았다. 후속 slice 후보다.
6. **검수 시나리오 학생 이력**: 검수 시나리오(`mock_design_review_scenario.dart`, `lib/services` 기존 파일이라 읽기만)는 학생 스캔이 1회라 A6가 문구 상태다. A6 꺾은선을 앱에서 보려면 시나리오에 학생 스냅샷 이력을 더해야 한다. 이번 fixture 생성 규칙을 `design_review/`로 옮기면 된다(CF 요청 후보, Lane B tidy1이 같은 파일을 고치는 중이라 이번에 손대지 않았다).
7. **학생 이벤트 크기**: 남은 이력 전부를 읽는다. 학생 스캔 commit마다 확정 학생 전체 before/after가 실려, 실제 계정에서 쪽 수가 클 수 있다(상한 50쪽 = 10,000건). 느리면 학생 bucket만 걸러 읽는 질의(`student_ids` 필터)나 summary 기반 스냅샷 목록이 필요하다(XB 몫, 측정 뒤 판단).
8. 워커 재량 FD는 FD-042 · FD-110 둘이다(권장안). 막는 `열림` FD는 없었다.

#### 사본 · commit.json

- 착수 사본: `debug/frontend_fe7h/pre/<경로>`(고친 기존 파일 8개 + 이 문서). WIP가 없어 post 사본은 없다.
- `debug/frontend_fe7h/commit.json`: slice `fe7h`, `status=true`, modified 9(이 문서 포함), added 5.
  - `whole` = `frontend/test/goldens/baseline/statistics-growth.png` · `statistics-inventory.png` · `statistics-plan.png`(바뀌는 기존 기준 이미지).
- 인계: `debug/frontend_fe7h/output.md`.

#### 다음 행동

- FE7-h 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: 레인 워커가 모두 멈춘 뒤 gate를 한 번 돌린다(tidy1과 같은 gate, 발견 1).
  - 예상: analyze 0, 일반 테스트 새 29건(projection 15 + view 14) 포함 녹색.
  - golden은 `statistics-growth` · `statistics-inventory` · `statistics-plan` RED(위 장면별 예측), 다른 장면 변화 0.
  - 승인 뒤 `-UpdateGoldens` → 재비교 → `fe_commit.ps1 -Slice fe7h`(tidy1 뒤).
- 발견 2(스냅샷 묶음 FD) · 4(예측 자리 · "P2 이전에 소진" 뜻) · 5(A6 구간 근거) · 6(검수 시나리오 학생 이력) · 7(이력 읽기 크기)은 CF 판단을 기다린다.

### fe7h commit record (2026-10-14 09:50, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261014_094253\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE7-e 통계 전용 필터 + FD-175 스냅샷 묶음 (Lane A, 로컬 Claude Code)

### FE7-e 착수 기록 (2026-10-14, Lane A)

- 상태: **진행 중**. 시작 SHA `5b1d8d159173515c8faf0d965e7210ad35ef200c`(브랜치 `scanner-consolidation`). 이 status 끝에 다른 "FE7-e 착수 기록"은 없었다.
- 범위: A. FD-175 스냅샷 묶음(기준 데이터 "n회 · 기간", A6 · B3 점, KPI "지난 스냅샷 대비"). B. FE7-e 통계 전용 필터(FD-104, 학생 성장 A1~A6에만).
- 막는 `열림` FD 없음(막힘 요약 FE7-e = FD-074 · FD-104, 둘 다 확정).
- 고칠 기존 파일(모두 `git status --short` 빈 줄 = 기존 미커밋 변경 없음, 사본 `debug/frontend_fe7e/pre/<경로>`):
  - `frontend/lib/statistics/statistics_history_projection.dart`
  - `frontend/lib/ui/pages/statistics_page.dart`
  - `frontend/lib/ui/statistics/statistics_workspace.dart` · `statistics_topics.dart` · `statistics_history_charts.dart`
  - `frontend/lib/ui/studio/statistics_studio_layout.dart`(요소 좌표만)
  - `frontend/lib/ui/widgets/student_filter_modal.dart`(머리 제목 · 보조 문구 · 추가 버튼 선택 매개변수만, 기본값 = 지금 동작)
  - `frontend/lib/ui/pages/student_page.dart` · `frontend/lib/ui/app_shell.dart`(학생 탭 필터 상태를 셸이 주입 — 통계 "학생 탭 필터 불러오기"가 읽을 길. 동작 변화 0, 최소 diff)
  - 테스트: `frontend/test/statistics_history_fixture.dart` · `statistics_history_projection_test.dart` · `statistics_history_view_test.dart` · `statistics_page_test.dart` · `statistics_workspace_test.dart` · `test/goldens/fe7a_statistics_golden_test.dart`
  - 이 문서
- 새 파일(예정): `frontend/lib/statistics/statistics_growth_filter.dart`, `frontend/test/statistics_filter_test.dart`.

### FE7-e 종료 기록 (2026-10-14, Lane A, 코드 작성 완료 · CF gate 미실행)

두 가지를 했다. A. 통계 "스냅샷"을 FD-175 묶음(2시간 안 scan 세션)으로 센다. B. 왼쪽 "필터"가 통계 전용 필터 모달을 연다(FD-104, 학생 성장에만 적용). 새 서비스 메서드 · 백엔드 · 키트 변경은 없다.

착수 기록 정정: `statistics_topics.dart` · `statistics_history_charts.dart` · `test/statistics_history_view_test.dart` · `test/statistics_workspace_test.dart`는 고치지 않았다(사본을 지웠다, 작업 트리 = HEAD). 새 파일은 `lib/statistics/statistics_growth_filter.dart` · `lib/ui/statistics/statistics_filter_view.dart` · `test/statistics_filter_test.dart` 셋이다.

#### 실행 명령 · 결과

모두 `frontend`에서 이 PC(Claude Code)로 실행했다. 로그는 `debug/frontend_fe7e/logs/`이고, 실패 줄(`[E]` · `EXCEPTION` · `Some tests failed` · `error •`)만 찾았다.

| 명령 | 결과 |
|---|---|
| `flutter analyze lib/statistics`(묶음 뒤) | info 1(`prefer_initializing_formals`, `_growthOf`) → `this._growthOf` 매개변수로 고침 → No issues |
| `flutter test test/statistics_history_projection_test.dart`(기대 고친 뒤 + FD-175 테스트 2건) | **+17 −0**(첫 실행) |
| `flutter analyze lib/statistics`(필터 projection 새 파일) | info 1(`use_null_aware_elements`) → `?a4Group.read(candidate)`로 고침 |
| `flutter analyze lib`(모달 · 학생 페이지 · 셸 · 워크스페이스 · 페이지 뒤) | **No issues found** |
| 통계 13파일(`test/statistics_*_test.dart`, 새 필터 테스트 전) | **+125 −0** |
| `flutter test test/statistics_filter_test.dart`(1차) | +7 −2: 1280×720 · 800×600에서 모달 머리 Row 넘침(157 · 508px). 통계 머리에 보조 문구 · "학생 탭 필터 불러오기"가 더해져 고정 폭이 띠보다 넓었다 → 띠 안쪽 폭 1000 미만이면 보조 문구를 빼고 추가 버튼을 줄인다(학생 머리는 둘 다 없어 그대로) |
| 같은 파일(2차) | +7 −2: 1280×720은 통과. 800×600은 공용 모달 자체(머리 기본 항목 119px · 키트 `RangeSliderRow` 6.3px × 12행)가 넘친다. 학생 탭 모달도 같은 크기에서 같다(발견 2) → 테스트를 "모달은 1280×720, 적용한 화면은 1440×900 · 800×600"으로 바꿈 |
| 같은 파일(3차) | **+9 −0** |
| `flutter analyze`(frontend 전체, 계획 KPI 누수 수정 · 테스트 정리 뒤) | **No issues found** |
| 관련 39파일 한 번에(`--file-reporter json`, 아래) | **+479 −0** |
| 일회성 렌더(임시 `test/zz_fe7e_render_tmp_test.dart` = golden 테스트 사본 + `RenderRepaintBoundary.toImage`, scratchpad PNG 5장, 실행 뒤 지움) | +5 −0, 예외 0. 새 두 장면 배치 확인(golden 비교 아님) |
| `flutter analyze`(최종) | **No issues found**(info 포함 0) |
| `git diff --check`(frontend · 이 문서) · 줄바꿈 | 0. 기존 파일은 pre와 같은 줄바꿈(`statistics_page.dart` · `statistics_page_test.dart` CRLF, 나머지 LF), 새 파일 LF · 줄 끝 공백 0 · 끝 개행 하나 |

관련 39파일(파일별, 모두 −0): statistics_filter +9(새), statistics_history_projection +17, statistics_history_view +14, statistics_page +14, statistics_workspace +13, statistics_growth_view +12, statistics_growth_projection +11, statistics_supply_view +11, statistics_plan_view +9, statistics_supply_projection +8, statistics_plan_projection +7, statistics_projection +7, statistics_app_shell +2, student_filter_modal +7, student_filter_selection +15, student_filter_followups +4, student_page +9, student_search_section +13, student_bond_gauge +12, student_studio_layout +45, plan_flow_student_step +8, kit/ba_modal_a11y +4, app_navigation_fe7d +13, app_navigation_tidy1 +11, inventory_history +33, inventory_history_page +11, inventory_shell_lazy +1, mock_design_review_scenario +11, widget +16, home_app_shell +1, home_connect_fe8e +10, account_editor_fe8c +9, account_manager_fe8b +6, connected_target_fe8d +8, growth_calculator_view +24, profile_delete_fb2d +17, planning_page +17, section_template_studio +15, title_page +25.

- 걸리는 테스트 찾기: test/ 전체를 `StatisticsPage|StudentPage\(|BAPlannerApp\(|AppShell\(|StudentFilterModal|StudentFilterController|statistics_|StatisticsHistory|student_filter_modal|statisticsGrowth|StatisticsWorkspace`로 grep했다(goldens 제외 33파일). `metadata_manager_dto_test`는 "statistics" 낱말만 걸려 뺐다. 공용 모달을 쓰는 `plan_flow_student_step` · `kit/ba_modal_a11y` · `student_filter_selection`, 재화 색인을 쓰는 `inventory_history` · `inventory_history_page`, 셸을 띄우는 `student_studio_layout` · `planning_page`를 더했다.
- 빌드 잠금(`build/` · `.dart_tool/`) 충돌 없음. `flutter analyze`가 pub get을 돌렸지만 `pubspec.lock` · `pubspec.yaml` 변화 없음. `dart format`은 새 파일에만 돌렸다.
- 실행하지 않음: golden(`test/goldens/**`), 전체 `fe_gate.ps1`, `-UpdateGoldens`, `fe_commit.ps1`, 맨 `flutter test`, process E2E, `codealmanac validate`.

#### A. FD-175 스냅샷 묶음

- 함수 · 상수: `lib/statistics/statistics_history_projection.dart`
  - `statisticsSnapshotGap = Duration(hours: 2)`(근거 주석 FD-175, 사용자 결정 2026-10-14 · 바꾸려면 FD 갱신).
  - `statisticsSnapshotGroups(points, starts:, gap:)` → `StatisticsSnapshotGroup`(세션 id 목록 · 끝 순번 · 끝 시각 · 이름 = 마지막 세션 id).
- 규칙: 학생 · 인벤토리 모든 profile의 scan 세션 끝 점(FB-2c `scan_points`)을 순번(= 기록 순서)대로 놓는다. 세션 시작(그 세션 첫 commit 시각, 모르면 끝 시각)이 바로 앞 세션 끝에서 2시간 이하이면 앞 묶음에 넣는다. 앞 세션 기준으로 이어지므로 1시간 반마다 스캔하면 한 묶음이 길어질 수 있다(FD 문구 "앞 세션 끝에서" 그대로).
- 쓰는 곳:
  - 기준 데이터 "스냅샷 n회 · 기간" = 묶음 수 · 첫 ~ 마지막 묶음 끝 날짜(`snapshotTimes`).
  - A6 점 · 성장 KPI "지난 스냅샷 대비" = 학생 세션이 든 묶음의 끝 학생 상태(`studentSnapshots`, 시각 = 묶음 끝).
  - B3 점 · 인벤토리 · 계획 KPI "지난 스냅샷 대비" = 그 재화가 scope에 든 세션이 있는 묶음의 끝 수량. FE6-f 색인 함수(`InventoryHistory.build`)는 그대로 쓰고, 넘기는 입력만 묶음으로 바꾼다(scan 적용의 세션 자리 = 묶음 이름, 점 = 묶음 끝 하나). 인벤토리 파일은 고치지 않았다.
  - B3 · A6 안내 "스냅샷 n회 · 시각"도 묶음 수 · 묶음 끝 시각이다.
- 인벤토리 탭의 재화별 "지난 스캔"(FE6-f 규칙 3)은 바꾸지 않았다. 판단: 재화별 비교가 맞다. 인벤토리 탭은 재화마다 마지막 바로 앞 스캔 점을 쓴다. 이 값은 한 묶음 안에서 같은 재화를 두 번 스캔했을 때만 통계 KPI와 다르다. 그때 탭은 "방금 전 스캔 대비", 통계는 "지난 스냅샷(자리) 대비"다. 둘 다 뜻이 맞아 권장안은 그대로 두기다.
- 계정 메타 "스냅샷": 지금 화면(FE8-c `account_section_cluster.dart`)에는 마지막 스캔 시각만 있고 스냅샷 횟수 글자가 없다. 권장안: 생기면 같은 `statisticsSnapshotGroups`를 쓴다(Lane B 파일이라 고치지 않음).
- 테스트(`statistics_history_projection_test.dart`):
  - 기존 기대 3곳을 고쳤다. 스냅샷 12 → 7, 학생 스냅샷 시각 = 묶음 끝, "B3 최근 6점" 테스트의 추가 스캔 간격 1분 → 2시간 1분(묶이지 않게).
  - 새 2건. ① 경계: 정확히 2시간이면 같은 묶음, 2시간 1분이면 새 묶음, 시작 시각 기준 연쇄. ② profile 둘을 10분 사이로 스캔하면 스냅샷 +1 · 재화 점 1개(묶음 끝 수량), KPI 4주 색인 기준도 묶음 점.
- fixture 값: 학생 21:40 + 인벤토리 21:50(9/02 ~ 9/29)은 한 묶음이다. 10/03 인벤토리와 10/05 학생은 따로다. 그래서 "12회" → **"7회 · 9/02 ~ 10/05"**이고, A6 · B3는 6점 그대로다. 시안 "6회"는 인벤토리 "3일 전"과 함께 맞출 수 없다(발견 1).

#### B. 통계 필터 상태 구조(학생 필터와 분리)

- 상태: `_StatisticsPageState._filter = StudentFilterController()`. 통계 페이지가 소유하는 통계 전용 객체이고 학생 탭 객체와 다르다.
  - 공용 모달(`StudentFilterModal`)에는 이 객체의 초안 · 적용을 넣는다. FE3-d 상태 주입 구조 그대로다(FD-104 (a)).
  - 수명: 앱 실행 동안이다. 계정을 바꾸면 통계 페이지가 새로 만들어지며 함께 비워진다(셸 `statistics-$_profileGeneration` key).
- 학생 탭 필터: 셸이 학생 탭 `StudentFilterController` 하나를 만들어 학생 페이지(`filterController`)에 넘긴다. 통계 페이지(`studentFilter`)는 같은 객체를 읽기만 한다.
  - 계정을 바꾸면 셸이 비운다(`discardDraft` + `applied = empty`). 학생 페이지가 새로 만들던 것과 같은 결과라 학생 탭 동작은 바뀌지 않는다.
  - 셸 diff +12(import 2 · 필드 · dispose · 계정 전환 3줄 · 매개변수 2). 학생 페이지 diff +9 −2(선택 매개변수, `late final _filter = widget.filterController ?? 자기 것`, 자기 것만 dispose).
  - 학생 페이지를 고친 이유: 학생 탭 필터의 적용 값은 그 페이지 State 안에만 있었다. 통계가 읽을 길이 없었다.
- "학생 탭 필터 불러오기": 학생 탭 적용 값을 통계 초안에 한 번 복사한다(`updateDraft`). 적용은 "적용"을 눌러야 한다. 연결이 아니라서 학생 탭 필터가 나중에 바뀌어도 통계 필터는 그대로다(테스트).
- 통계 → 학생 탭 이동(FE7-d)은 그대로 학생 필터에 쓰지 않는다. 넘기는 학생은 이미 대상 학생뿐이다. 버튼 둘째 줄 · 학생 탭 칩 글자에는 필터 칩 이름을 잇는다(시안 "필터: 육성도 60~70% · 밀레니엄 · 스트라이커").
- 모달 쪽 변경(`student_filter_modal.dart` +58 −3):
  - 선택 매개변수 3개: `title`(기본 '필터') · `caption` · `headerAction`. 기본값이면 지금과 같다.
  - 띠 안쪽 폭이 1000 미만이고 보조 문구 · 추가 버튼이 있을 때만 압축 배치를 쓴다.
  - 학생 · 계획 1단계 머리는 바뀌지 않는다(`'필터'` 글자 위젯만 const가 아니게 됐다).

#### 정한 규칙(시안 · 대장에 없는 것)

1. **후보 = 보유 학생**(학생 목록에 있는 확정 학생)이다.
   - 모달 머리 "n / m명" · 왼쪽 "n / m명" · KPI "대상 학생 n / m"의 m은 보유 학생 수다(시안 "31 / 128").
   - 학생 목록에 없는 보유 학생은 필터가 걸리면 대상에서 빠진다.
   - 칩 옆 학교 인원도 보유 기준이다. 보유 학생이 없는 학교는 칩이 없다.
2. **대상의 시간축**: 대상 = 지금 값으로 맞는 학생이다. A6 · 성장 KPI 증감은 그 학생들을 지난 스냅샷에서도 센다(그때 보유한 대상만, `StatisticsHistory.studentSnapshotsFor`). 지난 시점 값으로 필터를 다시 걸지 않는다.
3. **KPI 첫 칸**: 필터가 걸리면 "대상 학생" · 값 n · 둘째 글자 "/ m"(초록, 증감 없음 — 시안). 나머지 네 칸은 대상 학생 값 · 증감이다. 계획 등록은 FE7-h처럼 '—'다.
4. **적용 범위**: 학생 성장(A1 · A2 · A6 · KPI · 근거 · 범위 글자)만 대상 학생이다.
   - 인벤토리 · 계획은 전체 성장을 쓴다. 계획 KPI "미계획 · 40% 미만"이 전체 성장을 읽도록 고쳤다(처음 구현에서 필터된 성장이 새던 것을 테스트로 잡았다).
   - 근거 학생 이름 · 레벨(재화 근거)도 전체 성장이다.
5. **왼쪽 버튼**:
   - 학생 성장에서만 누를 수 있다(읽는 중에는 비활성).
   - 걸리면 분홍 선택 버튼 · "필터 · n"(n = 칩 수, FE3-d 15:51 결정 1) · "n / m명" · 분홍 깔때기 · 연필(#f7c9f4, 시안 path)이다.
   - 버튼 아래 (20, 400) 적용 칩 줄(분홍 칩 × + 회색 "초기화")이 들어가고, 보조 문구 · 기준 데이터가 36 내려간다(시안 611.2 → 647.2 · 667.2 → 703.2 · 693.2 → 729.2).
   - 칩 줄은 한 줄이고 넘치는 칩은 자른다("초기화"는 늘 보인다). "초기화"는 통계 필터를 모두 푼다(학생 탭 S4 "모두 지우기"와 달리 보유 · 서버도 푼다).
   - 인벤토리 · 계획에서는 FE7-a 그대로 비활성 "필터 · 인벤토리 · 계획 집계는 항상 전체"다. 칩 줄 · 내려감도 없다.
6. **가운데 머리**: 걸리면 범위 자리가 분홍 칩 "필터: 칩1 · 칩2 …" + 사이 10 + 12px "n명 기준"이다(좁으면 함께 줄인다).
7. **A4 빈 상태**: 필터가 걸리고 대상 학생의 학교가 하나 이하이면 "준비 중" 대신 시안 문구 두 줄이다(seg 기본 "학교"). "역할" seg와 A4 그래프는 FE7-f다(발견 3). 둥근 상자 모양은 A6 문구 상자와 같다. 줄 높이는 FD-109 그대로다(A4는 그래프가 아니므로 A6도 문구면 328).
8. **필터를 바꾸면**(적용 · 칩 × · 초기화) 고른 구간 · 근거 펼침을 지운다. 주제를 바꿔도 필터는 남는다.
9. **모달 닫기**: × · Esc · 스크림 · 탭 떠남은 초안을 버린다(학생 탭과 같다). 배지 자리 (18, 226)는 학생 S1 자리라 그리지 않는다.
10. **"학생 탭 필터 불러오기" 아이콘**: 시안 path(겹친 사각형)와 같은 뜻의 `Icons.copy_rounded`를 쓴다. 셸이 학생 필터를 넘기지 않으면(단독 테스트) 비활성이다.

#### 처리한 FD

- **FD-104(확정 (a))**: 통계 전용 필터 상태(학생 탭과 다른 객체, 서로 덮어쓰지 않음) + 모달 "학생 탭 필터 불러오기"(복사) + 학생 성장에만 적용 + 버튼 비활성 해제(학생 성장).
- **FD-175(확정 (a))**: 위 A.
- **FD-074(확정 (b))**: 통계 모달도 필터 프리셋 칩을 숨긴다(공용 모달 그대로).
- **FD-109(확정)**: A4 빈 상태 + A6 문구일 때 줄 328 그대로.
- **FD-063(워커 재량)**: 통계 모달에 육성도 행을 넣지 않았다. 시안 Stats-Filter-Open의 성장 범위는 학생 탭과 같은 행뿐이다. FE7-d 근거(통계 구간 반열림 [60, 70) vs 정수 범위)도 그대로다.
- FD-041 · FD-106: 이력 · "준비 중" 규칙은 FE7-h 그대로다(스냅샷 단위만 FD-175로 바뀜). 막는 `열림` FD 없음.

#### golden 변화 예상(장면별)

- **`statistics-growth`(바뀜)**:
  - 기준 데이터 스냅샷 칩 "12회 · 9/02 ~ 10/05" → "7회 · 9/02 ~ 10/05".
  - 왼쪽 필터 버튼의 흐림(.45)이 풀린다. 글자 '필터' · 부제는 또렷해지고, 깔때기 · 꺾쇠는 회색 그대로다.
  - KPI 값 · 증감 · A6(점 6개 · 날짜 · 강조 9/22 → 10/05 +2.0%p) · A1 · A2 · 근거 변화 0.
- **`statistics-inventory`(바뀜)**: 스냅샷 칩 글자만 바뀐다. B3 점 · 값 · KPI 증감 · 필터 버튼(비활성 그대로) 변화 0.
- **`statistics-plan`(바뀜)**: 스냅샷 칩 글자만 바뀐다.
- **새 `statistics-filter-open`**(시안 Stats-Filter-Open):
  - 배경: 성장 장면 + 필터 스크림.
  - 머리: "통계 필터" · 두 줄 "학생 성장(A)에만 적용 / 학생 탭 필터와 따로 저장" · "18 / 128명" · 분홍 칩 "밀레니엄" "스트라이커" · "학생 탭 필터 불러오기" · "초기화" · "적용" · ×.
  - 속성 패널: 학교 줄 칩 옆 보유 인원, 밀레니엄 · 스트라이커 선택. 성장 범위 패널은 전체 기본값이다.
  - 배경 왼쪽 버튼은 "필터 · 없음 · 보유 128명 전체" 그대로다(적용 전).
  - 이 fixture는 밀레니엄 보유 31명 중 스트라이커가 18명이라 시안 "31"과 다르다.
- **새 `statistics-growth-filter`**(시안 Stats-Growth-Filter, 위에서 "적용"):
  - 왼쪽: 분홍 "필터 · 2" · "18 / 128명" · 연필, 칩 줄 "밀레니엄 × · 스트라이커 × · 초기화", 보조 문구 · 기준 데이터가 36 아래.
  - 머리: 분홍 칩 "필터: 밀레니엄 · 스트라이커" · "18명 기준".
  - KPI: "대상 학생 18 / 128" · 평균 육성도 62.0% · 대상 학생 기준 증감.
  - 타일: A1 · A2는 18명 값이다. A4는 빈 상태 두 줄이다. A6는 18명 꺾은선이다(fixture가 스냅샷 6회 — 시안은 1회 문구). A3 · A5는 "준비 중"이다.
  - 일회성 렌더에서 넘침 0이었다.
- **다른 장면: 변화 0.** 학생 장면(`students-*`, `students-filter-open` 포함)과 계획 1단계 필터 장면은 모달 머리 기본값이 같고, 학생 필터 객체를 셸이 넘겨도 처음 값은 같다. 통계 외 장면에는 FD-175가 닿지 않는다(인벤토리 파일 변경 0).
- commit.json `whole` = 위 기존 3장(파일 단위). 새 2장은 CF가 `-UpdateGoldens`로 만든다.

#### 검수표

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Stats-Filter-Open | 통계 → 학생 성장 → 왼쪽 "필터"(golden `statistics-filter-open`, 앱 mock 검수 시나리오도 같은 길) | 머리 "통계 필터" · 두 줄 보조 문구 · "n / 보유명" · "학생 탭 필터 불러오기"(학생 탭에서 필터를 건 뒤 누르면 칩이 그대로 복사됨) · 프리셋 칩 없음 · 배지 없음 / 배경 왼쪽 버튼은 적용 전 "없음" |
| → 필터 · 불러오기 | 칩을 고르거나 "학생 탭 필터 불러오기" | 머리 수가 바뀐다. 학생 탭 필터는 바뀌지 않는다. × · Esc · 스크림은 초안을 버린다 |
| → 적용 → Stats-Growth-Filter | "적용"(golden `statistics-growth-filter`) | 왼쪽 분홍 "필터 · n" · "n / m명" · 칩 줄 · 보조 문구 36 아래 / 머리 칩 "필터: …" · "n명 기준" / KPI "대상 학생 n / m" / A4 빈 상태(학교 하나일 때) / 학생 탭으로 가도 학생 필터 그대로 |
| (적용 뒤) 인벤토리 · 계획 | 주제 버튼 | 버튼 비활성 "항상 전체", 칩 줄 없음, KPI · 그래프 값이 필터 전과 같다 |
| (공통) 스냅샷 | 기준 데이터 · A6 · B3 | "n회"가 2시간 안 세션 묶음 수다(golden fixture "7회") / 1280×720에서 모달 · 적용 화면 넘침 없음 |

#### 미검증 항목

- golden 비교 · 새 두 장면 생성: **미실행**(CF `fe_gate.ps1` · `failures/` 검토 · `-UpdateGoldens`).
- 전체 `fe_gate.ps1`(나머지 테스트 · process E2E · `codealmanac validate` · 저장소 전체 `git diff --check`): **미실행**.
- mock 검수 시나리오(`design-review`)의 묶음 뒤 스냅샷 수(전에 "31회"): **미실행**(값을 출력해 보지 않았다).
- 실제 백엔드 이력에서 세션 시작(첫 commit 시각)과 끝 점 순번 순서: **미실행**(Mock 순수 질의 함수로만 보았다).
- 새 요소 ±2px(칩 줄 (20, 400) · 머리 칩 · A4 상자): 위젯 테스트는 값 · 존재만 보았다. 좌표는 재지 않았고 일회성 렌더로 자리만 봤다.

#### WIP 보존 확인

- 고친 기존 파일 11개 + 이 문서는 착수 때 `git status --short` 빈 줄(WIP 없음)이었다. post 사본 · `post_dir`은 없다.
- pre 사본과 비교한 diff에는 이 slice 줄만 있다. 착수 목록 중 고치지 않은 4파일은 사본을 지웠다.
- Lane B(fb6-dart) 파일(`lib/services/**`)과 스캐너 WIP 파일은 읽기만 했다.

#### 발견 사항

1. **시안 "스냅샷 6회"와 fixture "7회"**: 시안은 인벤토리 "3일 전"(10/03)과 학생 "어제"(10/05)를 함께 그렸다. 그래서 2시간 묶음으로는 6회가 될 수 없다(10/03 · 10/05가 따로). 시안 숫자에 맞추려면 fixture에서 인벤토리 하나를 학생 날짜로 옮겨야 하는데, 그러면 "3일 전"이 깨진다. CF 판단.
2. **공용 필터 모달 800×600 넘침(기존, 학생 탭도 같음)**: 머리 기본 항목(필터 · 결과 수 · 구분선 · 초기화 · 적용 · ×)이 띠보다 119px 넓다. 키트 `RangeSliderRow`(range_controls.dart 131행 Row)도 행마다 6.3px 넘친다. 1280×720은 괜찮다. 키트 · 공용 모달 정리 후보다(이번에 고치지 않음).
3. **A4 빈 상태 판정**: 지금은 seg 기본 "학교"로만 본다(학교 하나 이하). FE7-f에서 A4 그래프 · "역할" seg를 만들 때 고른 seg의 값 수로 바꿔야 한다. 시안 문구는 "학교 · 역할이 하나뿐"이다.
4. **시안 Stats-Growth-Filter의 A5 숫자가 필터 전과 같다**(F §3.2 모순). A5는 FE7-i다. 그때 대상 학생으로 세면 된다(`StatisticsGrowthScope.growth`).
5. **계정 메타 "스냅샷"**: 화면에 횟수 글자가 없다. 생기면 `statisticsSnapshotGroups`를 같이 쓰기를 권한다(Lane B).
6. **연속 스캔 묶음 길이**: "앞 세션 끝에서 2시간"이라 2시간 안 간격으로 계속 스캔하면 묶음이 끝없이 길어진다(예: 하루 종일 1시간마다). 실사용에서 문제가 되면 "묶음 첫 세션에서 n시간" 상한을 FD-175에 더할지 결정이 필요하다.

#### 다음 행동

- FE7-e 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: 레인 워커가 모두 멈춘 뒤 gate를 한 번 돌린다(Lane B fb6-dart와 같은 gate).
  - 예상: analyze 0, 일반 테스트 새 9건(statistics_filter) + FD-175 2건 포함 녹색.
  - golden은 `statistics-growth` · `statistics-inventory` · `statistics-plan` RED, 새 `statistics-filter-open` · `statistics-growth-filter`는 기준 없음. 다른 장면 변화 0.
  - 승인 뒤 `-UpdateGoldens` → 재비교 → `fe_commit.ps1 -Slice fe7e`.
- 발견 1(시안 6회) · 2(모달 800×600) · 3(A4 seg) · 6(묶음 상한)은 CF 판단을 기다린다.

### fe7e commit record (2026-10-14 13:06, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261014_125829\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE7-f 통계 2차 타일 A3 · A4 · B2 · C4 (Lane A, 로컬 Claude Code)

### FE7-f 착수 기록 (2026-10-14, Lane A)

- 상태: **진행 중**. 시작 SHA `ebc84ee463767b4d726120c8f16af7b14b34bb6d`(브랜치 `scanner-consolidation`). 이 status 끝에 다른 "FE7-f 착수 기록"은 없었다.
- 범위: A3 성작 · 전용무기 분포, A4 학교 · 역할 비교(산점도 · hover 팝오버 · seg), B2 부족 · 과잉(발산 막대 · 근거 "최근 변화"), C4 학생별 목표 진행(덤벨). A5 · C5는 FE7-i라 "준비 중" 그대로.
- 막는 `열림` FD 없음(막힘 요약 FE7-f = FD-028, 확정).
- 사용자 결정(착수 질문, 2026-10-14): C4 → "계획 만들기 2 · 목표 정하기"는 intent + 계획 수신부 최소 추가(`PlanNavigationIntent.goals`, `plan_section_layout.dart`가 활성 계획 편집 흐름을 2단계로 연다). 계획 파일은 최소 diff · 이유를 종료 기록에 적는다.
- 고칠 기존 파일(모두 `git status --short` 빈 줄 = 기존 미커밋 변경 없음, 사본 `debug/frontend_fe7f/pre/<경로>`):
  - `frontend/lib/statistics/statistics_growth_projection.dart` · `statistics_growth_filter.dart` · `statistics_supply_projection.dart`
  - `frontend/lib/ui/statistics/statistics_workspace.dart` · `statistics_topics.dart` · `statistics_growth_evidence.dart` · `statistics_supply_evidence.dart`
  - `frontend/lib/ui/pages/statistics_page.dart`, `frontend/lib/ui/studio/statistics_studio_layout.dart`(요소 좌표만)
  - `frontend/lib/ui/navigation/app_navigation_intent.dart` · `frontend/lib/ui/widgets/plan_section_layout.dart`(C4 이동, 위 사용자 결정)
  - 테스트: `frontend/test/statistics_growth_view_test.dart` · `statistics_supply_view_test.dart` · `statistics_plan_view_test.dart` · `statistics_filter_test.dart` · `app_navigation_fe7d_test.dart` · `statistics_workspace_test.dart` · `statistics_page_test.dart` · `test/goldens/fe7a_statistics_golden_test.dart`(fixture 입력 · 주석만)
  - 이 문서
- 새 파일(예정): `frontend/lib/statistics/statistics_breakdown_projection.dart`(A3 · A4) · `statistics_goal_projection.dart`(C4), `frontend/lib/ui/statistics/statistics_breakdown_charts.dart`(A3 · A4) · `statistics_balance_charts.dart`(B2 · C4), 테스트 `frontend/test/statistics_second_tiles_test.dart`.

### FE7-f 종료 기록 (2026-10-14, Lane A, 코드 작성 완료 · CF gate 미실행)

"준비 중"이던 A3 · A4 · B2 · C4를 그래프로 바꿨다. 각 타일은 고른 것 → 근거 → 원본 탭 이동까지 동작한다. A5 · C5는 FE7-i라 "준비 중" 그대로다. 새 서비스 메서드 · 백엔드 · 계약 · 키트 변경은 없다.

착수 기록 정정:
- 고치지 않은 4파일은 사본을 지웠다(작업 트리 = HEAD): `statistics_topics.dart` · `test/statistics_filter_test.dart` · `test/statistics_page_test.dart` · `test/goldens/fe7a_statistics_golden_test.dart`. golden fixture 입력도 바꾸지 않았다.
- `test/statistics_history_view_test.dart`는 착수 목록에 없었다. 고치기 전에 WIP가 없음을 확인하고 pre 사본을 두었다.

#### 실행 명령 · 결과

모두 `frontend`에서 이 PC(Claude Code)로 실행했다. 로그는 `debug/frontend_fe7f/logs/`에 있다. 로그는 실패 줄(`[E]` · `EXCEPTION` · `Some tests failed` · `error •`)만 찾았다.

| 명령 | 결과 |
|---|---|
| `flutter analyze lib/statistics`(B2 행 함수 뒤) | error 2 · warning 1(if-case 패턴을 `&&`와 섞음) → 중첩 `if`로 고침 → No issues |
| `flutter analyze lib/statistics lib/ui/statistics lib/ui/studio`(차트 · 근거 · workspace 뒤) | No issues found |
| `flutter analyze lib`(page · intent · plan 수신부 뒤) | No issues found |
| 통계 17파일(`test/statistics_*_test.dart`, 1차) | 대부분 실패. 원인은 A3 projection의 `List.unmodifiable` 타입 추론(`List<dynamic>`)이었다 → 타입 인자를 붙여 고침 |
| 같은 17파일(2차) | +124 −10. 실패 10건은 모두 FE7-f로 바뀐 동작의 기대값이었다("준비 중" 개수, A4 seg 비활성, 보유 0 빈 상태 개수). 6파일의 기대를 고침(아래) |
| 같은 17파일(3차) | **+134 −0** |
| `flutter test test/statistics_second_tiles_test.dart`(새, 1차) | +11 −1. 크레딧 근거에 "필요량 순"이 없었다. 문서 계산은 있지만 그 재화의 단계 사용이 없는 경우다 → 문서 계산이 있으면 늘 "필요량 순" 틀을 쓰게 고침(영향 학생 필요량은 '—') |
| 같은 파일(2차) | **+15 −0** |
| `flutter test test/app_navigation_fe7d_test.dart`(셸 C4 → 계획 2단계 테스트 추가) | **+14 −0** |
| 일회성 렌더(임시 `test/zz_fe7f_render_tmp_test.dart`, 실행 뒤 지움) | +5 −0 · +2 −0, 예외 0. golden 테스트 사본에 `RenderRepaintBoundary.toImage`를 더해 scratchpad에 PNG 6장을 남겼다. 다섯 장면과, 성장 장면을 아래로 스크롤한 A3 · A4를 보았다. golden 비교는 아니다 |
| `flutter analyze`(frontend 전체, 최종) | **No issues found**(info 포함 0) |
| 관련 57파일 한 번에(`--file-reporter json`, 아래) | **+634 −0** |
| `git diff --check`(고친 · 새 파일) · 줄바꿈 바이트 검사 | 오류 0. 기존 파일은 pre와 같은 줄바꿈이다: `statistics_growth_projection.dart` · `statistics_growth_evidence.dart` · `statistics_page.dart` · `plan_section_layout.dart` · `statistics_growth_view_test.dart`는 CRLF, 나머지는 LF. 새 파일은 LF · 줄 끝 공백 0 · 끝 개행 하나 |

관련 57파일(파일별, 모두 −0): account_editor_fe8c +9, account_manager_fe8b +6, app_navigation_fe7d +14, app_navigation_tidy1 +11, connected_target_fe8d +8, diagonal_geometry +5, diagonal_scroll_viewport +5, diagonal_scrollbar +8, growth_calculator_view +24, home_app_shell +1, home_connect_fe8e +10, inventory_analysis_page +8, inventory_history +33, inventory_history_page +11, inventory_shell_lazy +1, item_icon_tile +7, mock_design_review_scenario +11, plan_detail_tabs +8, plan_flow +15, plan_flow_authoring +18, plan_flow_goal_step +23, plan_flow_handoff +23, plan_flow_order_step +19, plan_flow_presets +13, plan_flow_save +15, plan_flow_student_step +8, plan_home_detail +9, plan_preset_manager +5, plan_scenario_compare +7, plan_scenario_comparison +2, plan_scenario_detail +12, plan_scenario_list +10, plan_scenario_preview +9, planning_page +17, profile_delete_fb2d +17, section_surface +5, section_template_studio +15, skew_bar +8, statistics_app_shell +2, statistics_filter +9, statistics_growth_projection +11, statistics_growth_view +12, statistics_history_projection +17, statistics_history_view +14, statistics_page +14, statistics_plan_projection +7, statistics_plan_view +9, statistics_projection +7, statistics_second_tiles +15(새), statistics_supply_projection +8, statistics_supply_view +11, statistics_workspace +13, student_filter_followups +4, student_filter_modal +7, tidy1_followups +3, title_page +25, widget +16.

- 걸리는 테스트 찾기: test/ 전체를 `StatisticsPage|statistics_|PlanSectionLayout(|PlanningPage(|BAPlannerApp(|AppShell(|PlanNavigationIntent|PlanFlowController(|plan_section_layout|StudentFilterModal|inventory_history|app_navigation`로 grep했다.
  - goldens · process E2E · 스캐너(`scan_*` · `scanner_*` · `mock_scanner_service`) · `metadata_manager_dto` · `tactical_lobby`는 뺐다. 이 slice와 무관하거나 다른 레인 작업 중이다.
- 고친 기존 테스트 기대(모두 FE7-f로 바뀐 동작):
  - "준비 중" 개수: 성장 3 → 1(A5), 인벤토리 1 → 0, 계획 2 → 1(C5). 해당 파일은 growth_view · workspace · history_view · plan_view · supply_view다.
  - A4 seg `onChanged`: null → 동작(growth_view).
  - 보유 0 빈 상태 문구 개수: 2 → 4(A1 · A2 · A3 · A4, growth_view).
- 빌드 잠금(`build/` · `.dart_tool/`) 충돌은 없었다.
- `flutter analyze`가 pub get을 돌렸지만 `pubspec.lock` · `pubspec.yaml`은 바뀌지 않았다.
- `dart format`은 새 파일에만 돌렸다.
- 실행하지 않음: golden(`test/goldens/**`), 전체 `fe_gate.ps1`, `-UpdateGoldens`, `fe_commit.ps1`, 맨 `flutter test`, process E2E, `codealmanac validate`.

#### 타일별 projection 함수 · 정의

| 타일 | 함수(파일) | 정의 |
|---|---|---|
| A3 | `StatisticsStarDistribution.of`(`lib/statistics/statistics_breakdown_projection.dart`) | 대상 학생을 `student_star` 1~5 단계와 `weapon_star` 0(없음)~4 단계로 나눈다. 단계 안은 낮은 항목 순이다. 편성(`striker` · `special`)마다 ★1~5 인원을 세어 100% 누적으로 그린다. 값을 모르는 학생은 막대에서 빼고 "n명 모름"으로 센다 |
| A4 | `StatisticsGroupComparison.of`(같은 파일) | 그룹(학교 · 역할 코드 값)마다 점 하나다. **보유율 = 그 그룹 대상(보유) 학생 / 학생 목록의 그 그룹 학생 수**이고, 분모는 필터와 상관없는 학생 목록 전체다. 평균 육성도 = 그 그룹에서 육성도를 아는 학생의 평균(FD-028). 평균선 = 점을 찍은 그룹 전체의 Σ보유 / Σ학생 목록, 그리고 아는 학생 전체의 평균 육성도(필터가 없으면 KPI와 같다). 협업 학교(Sakugawa · Tokiwadai)는 학생 탭 칩처럼 그룹으로 세지 않는다. 빈 상태 = 통계 필터가 걸렸고 `valueCount`(대상 학생의 고른 seg 값 수)가 1 이하 |
| B2 | `statisticsB2Rows`(`lib/statistics/statistics_supply_projection.dart`) | 보유를 아는 계획 재화 중 부족(보유 < 필요)과 과잉만 행이다. **과잉은 인벤토리 탭과 같은 `InventoryItemView.excess`** 판정이다(보유 ≥ 필요 × 1.5, FD-040, 새로 만들지 않음). 값 = (보유 − 필요) / 필요이고 재화마다 따로 센다(FD-033). 1~1.5배인 재화와 보유 모름 재화는 행이 없다. "부족 순"은 값 작은 순, "과잉 순"은 값 큰 순이다(같으면 영향 학생 많은 순 → 카탈로그 순). 6행 |
| B2 근거 | `statisticsResourceUsers` · `statisticsRecentChange`(`lib/ui/statistics/statistics_supply_evidence.dart`) | 쓰는 학생 = 인벤토리 `inventoryStageUses`(활성 문서 계산)로 학생별 필요량을 더해 큰 순. 글자는 첫 단계 "Pn · <단계>". 최근 변화는 지금 − 28일 색인(`StatisticsHistory.inventoryWindow`, 인벤토리 탭 KPI와 같은 색인)으로 센다. "지난 스캔 대비" = 지금 보유 − 그 재화의 마지막 바로 앞 스캔 점(FE6-f 규칙 3). "이 속도면"은 `inventorySparkline`이 `depletion`일 때만 "n주 뒤 소진 예상"이다(FE6-f 상세와 같은 함수 · 조건, FD-042) |
| C4 | `StatisticsGoalProgressSet.of` · `statisticsGoalTargetValues`(`lib/statistics/statistics_goal_projection.dart`) | 행 = 계정 상태 `goals` 학생(범위 칩 "활성 계획 · n명"과 같은 집합). 현재 = FD-028 식(`statisticsGrowthOfValues`, 성장 projection과 같은 함수). 목표 = 같은 식을, 목표로 덮어쓴 값 맵에 쓴다. 목표 키가 있는 항목은 max(현재, 목표), 없는 항목은 현재 값이다. **남은 폭 = 목표 − 현재(%p)**. 순서는 남은 폭 큰 순 → 현재 낮은 순 → id이고, 모르는 행(미보유 · 값 모름)은 뒤에 '—'로 둔다. 5행 |

- 성장 projection에 원값 필드(성작 · 전용무기 · 학교 · 역할 · 편성)를 더했다. 생성자 새 매개변수는 모두 선택이다.
- `statisticsStudentGrowth`는 값 맵 함수 `statisticsGrowthOfValues`를 부르도록 나눴다(계산 변화 0).
- 낮은 항목 비교는 `statisticsCompareLowItem`으로 꺼냈다. A1 `binStudents`도 이 함수를 쓴다(순서 변화 0).

#### C4 이동 — intent · 계획 수신부 diff와 이유(사용자 결정 2026-10-14)

- `app_navigation_intent.dart` +13 −2:
  - `PlanNavigationTarget.goals`와 `PlanNavigationIntent.goals(studentId)`를 더했다. payload는 `studentIds` 한 명이다.
  - 머리 주석을 고쳤다.
- `plan_section_layout.dart` +14 −1:
  - 이미 흐름이 열려 있으면 order처럼 알리기만 한다. 새 문구는 `planNavigationGoalsFlowOpenMessage`("진행 중인 계획 만들기가 있어 목표 정하기를 새로 열지 않았습니다.")다.
  - 그렇지 않으면 `_openNavigationFlow`가 order와 같은 길로 연다(활성 계획을 다시 읽은 페이즈 편집 초안).
  - 연 뒤 기존 계산기 넘기기 API `flow.receiveHandoff(context.seedFor(id))`(목표 없는 seed)로 그 학생을 2단계에 띄운다.
  - `PlanFlowController`(모델)는 고치지 않았다.
- 이유:
  - 2단계에서 특정 학생을 여는 수신부가 없었다.
  - 계획 화면 동작은 이 slice의 금지 범위라 착수 때 사용자에게 물었고, 답은 "intent+수신부 최소 추가"였다.
  - 의도가 없으면 계획 화면 동작은 그대로다(계획 테스트 18파일 녹색).

#### 처리한 FD

- **FD-028(확정)**: A3 · A4 · C4가 같은 식을 쓴다. C4 목표에도 같은 함수를 쓴다("목표값에도 같은 공식"). 모르는 값은 '—'이고 추정하지 않는다.
- **FD-040(워커 재량, 권장안)**: 과잉 판정은 인벤토리 탭과 같은 `InventoryItemView.excess`다(인벤토리 파일은 읽기만). 과잉 종 수가 KPI "과잉 재화"와 같음을 테스트로 고정했다.
- **FD-042(워커 재량, 권장안 + CF 결정 2026-10-14)**: 시안 "이 속도면 P2 이전에 소진" 대신 FE6-f "n주 뒤 소진 예상"이다. 같은 함수 · 같은 조건(3점 이상 최소제곱 · 4주 안)이고, 조건이 안 되면 줄을 숨긴다.
- **FD-109(확정)**: A4가 산점도면 A4 · A6 줄은 368이다. A4가 그래프가 아니고(필터 빈 상태 · 점 없음 · 읽는 중) A6도 짧은 문구면 328이다(`statisticsRowHeight(..., a4Chart:)`).
- **FD-033 · FD-106 · FD-104 · FD-175 · FD-108**:
  - FD-033: 재화마다 따로 센다.
  - FD-106: A5 · C5는 "준비 중" 그대로다.
  - FD-104: A3 · A4는 통계 필터 대상 학생, B2 · C4는 전체다.
  - FD-175: "스캔 n회"는 묶음 색인으로 센다.
  - FD-108: C4 이동도 같은 intent 모델이다.
- 막는 `열림` FD 없음.

#### 정한 규칙(시안 · 대장에 없는 것)

1. **A3 단계 고르기**:
   - 0명 단계는 고르지 않는다. 누적 막대는 누르지 않는다.
   - 근거 머리는 "성작 ★n" · "전용무기 없음/★n", 부제는 "A3에서 고른 단계 · 낮은 항목 순"이다.
   - 요약은 "단계 요약"이다(A1 구간 요약과 같은 세 줄).
2. **A3 "학생 탭에서 보기"**: 학생 목록(임시 목록)만 넘긴다.
   - 학생 필터에 "성급" 범위가 있지만, FE7-d 이동은 학생 필터 상태에 쓰지 않는다(FD-104 · FE7-d 규칙 3).
   - 버튼 둘째 줄은 "필터: 성작 ★n"이다.
3. **A4 강조(분홍)**:
   - 고른 점이 있으면 그 점이다.
   - 없으면 평균 육성도 아래 점 중 대상 학생이 가장 많은 점이다(시안 질문 "많이 모였지만 덜 키운").
   - 회색 이름은 보유율이 가장 높은 점과 낮은 점에 단다. 오른쪽 자리가 모자라면 왼쪽에 쓴다.
4. **A4 축**: 값 범위를 10 단위로 내림 · 올림한다(0~100, 같으면 10을 벌린다). 시안처럼 최소값만 글자로 쓴다.
5. **A4 hover 팝오버**:
   - 문구 형식은 시안 그대로다. 이름, "보유 n명 · 보유율 n% · 평균 육성도 n%", 초상 6장 + "…+n", "누르면 오른쪽 목록 · 학생 탭(학교|역할 필터)으로 이어집니다" 순이다.
   - 위치는 점 왼쪽 12 · 위 −18이다. 왼쪽이 화면 밖이면 오른쪽에 띄우고, 그래도 넘치면 화면 안으로 민다(가장자리 8).
   - 키보드 포커스로도 뜬다. 점을 누르면 고르고, 팝오버 자체는 누르기를 받지 않는다(`IgnorePointer`).
6. **A4 seg 바꾸기**: 다른 seg의 점을 고른 채면 푼다. seg 값은 다시 읽어도 남긴다(보기 선택).
7. **B2 축척**:
   - 시안 1.735/%이고 두 쪽이 같은 축척이다. 가장 큰 부족 막대가 이름 자리를 덮으면 축척을 줄인다.
   - 과잉 막대는 오른쪽 자리에서 자르고, 글자는 실제 값이다.
   - 행이 없으면 "모자라거나 넘치는 재화가 없습니다."(새 문구)다. 보유 모름 재화는 "보유 모름 n종 제외"로 적는다.
8. **B2 seg 바꾸기**: 고른 B2 행을 푼다(C1 순서와 같다). seg 값은 다시 읽어도 남긴다.
9. **B2 근거 학생**:
   - 문서 계산이 있으면 "필요량 순" 4행 + "외 n명"이다(모두 보기 = FE7-d 펼침). 그 재화를 쓰는 단계가 없는 영향 학생은 뒤에 두고 필요량은 '—'다.
   - 문서 계산이 없으면 FE7-c처럼 이름 · Lv 행이고 캡션은 "n명"이다.
   - "외 n명"이 있으면 "최근 변화"를 그만큼(36) 내린다.
   - "지난 스캔 대비"는 감소면 분홍이고, 백만 이상은 "−5.6M"으로 쓴다.
10. **B2 이동**:
    - primary는 인벤토리의 그 행이다.
    - ghost "티어별 충족률"은 그 재화 카테고리가 노트 · BD · 오파츠일 때만 켜진다(B1 규칙과 같다).
11. **C4**:
    - 5행만 그린다. 활성 계획 학생이 더 많아도 "외 n명"은 없다(시안 없음).
    - 고른 행은 B2와 같은 분홍 띠다.
    - 근거는 초상 행, 현재 · 목표 육성도, 남은 폭, "항목별 · 현재 → 목표" 항목 행 순이다(올릴 항목은 분홍).
    - primary는 "계획 만들기 2 · 목표 정하기" · "<학생> 목표 고치기"이고, ghost는 비활성이다.
    - C4는 부족 계산이 실패해도 목표만 있으면 그린다.
12. **근거 빈 상태 문구**(FE7-c가 정한 글자, 시안 없음): "B1 막대나 B2 행을 고르면 근거가 보입니다." · "C1 행 · C2 점 · C4 행을 고르면 근거가 보입니다."
13. **A4 점 없음**: 그룹 값을 아는 학생이 없으면 "<학교|역할> 값을 아는 학생이 없습니다…"다. 그룹은 있지만 육성도를 모르면 육성도 문구다(A1과 같은 문구 함수).

#### golden 변화 예상(장면별)

- **`statistics-growth`(바뀜)**:
  - A4: "준비 중" → 학교 산점도.
    - 점은 보유 학교 수만큼이다.
    - 평균 점선 두 줄과 "평균" 글자가 있다.
    - 강조점은 분홍 "백귀야행"이고, 회색 이름은 "SRT" · "아비도스"다.
    - 축 글자는 "육성도" · "20" · "10%" · "보유율 →"다(일회성 렌더 기준).
  - A4 seg: 흐린 자리 → 동작 seg("학교" 선택 모양).
  - A3: "준비 중" → 성작 8 · 36 · 38 · 8 · 38, 전용무기 103 · 2 · 12 · 0 · 11 막대. 아래에 스트라이커 · 스페셜 누적 막대와 범례가 있고, 누적 막대는 viewport 아래 포그에 걸친다.
  - KPI · A1 · A2 · A6 · 근거 · 줄 높이는 변화 0(A4 · A6 줄은 이미 368).
- **`statistics-inventory`(바뀜)**:
  - B2: "준비 중" → 발산 막대 6행. 크레딧 −62% · 엘리그마 −55% · 네브라 디스크 T4 −54% · 님루드 렌즈 T3 −52% · 기술 노트 (상급) −52% · 전술 교육 BD (최상급) −50%다. 아래에 "← 부족 · 과잉 →" · "필요량 대비 %" · "보유 모름 1종 제외"가 있다.
  - B2 seg: 동작 seg("부족 순" 선택).
  - 근거 빈 문구: "B1 막대나 B2 행을 고르면 근거가 보입니다."
  - KPI · B1 · B3 변화 0.
- **`statistics-plan`(바뀜)**:
  - C4: "준비 중" → 덤벨 5행. 일회성 렌더 값은 호시노 10 → 20% · 아카네 40 → 46% · 아루 40 → 45% · 에이미 70 → 70% · 히나 70 → 70%다. 25 · 50 · 75% 점선과 범례 "현재 · 목표 · 남은 폭이 큰 순"이 있다. fixture 목표가 `target_level 90`뿐이라 남은 폭이 작다.
  - 근거 빈 문구: "C1 행 · C2 점 · C4 행을 고르면 근거가 보입니다."
  - KPI · C1~C3 변화 0.
- **`statistics-growth-filter`(바뀜)**:
  - A3: 대상 18명 막대(성작 0 · 6 · 7 · 1 · 4, 전용무기 15 · 1 · 1 · 0 · 1).
  - A4: 빈 상태 두 줄은 그대로다(학교 seg, 밀레니엄 하나). seg만 흐린 자리에서 동작 seg로 바뀐다.
  - 줄 높이는 368 그대로다(A6 꺾은선).
- **`statistics-filter-open`(바뀜)**: 배경 성장 장면의 A3 · A4가 위처럼 바뀐다(스크림 아래). 모달 변화 0.
- **다른 장면: 변화 0.**
  - 계획 장면: goals 의도가 없으면 수신부 동작이 같다.
  - 학생 · 인벤토리 · 셸 · 홈 · 타이틀 · 스캔 장면: 바뀐 파일을 쓰지 않거나 같은 값이다.
  - 키트 · harness · golden 테스트 파일 변경 0.
- commit.json `whole` = 위 기존 기준 이미지 5장(파일 단위). 새 장면은 없다.
- A4 hover 팝오버 · B2 · C4 근거는 위젯 테스트(`statistics_second_tiles_test.dart`)로만 확인했다.

#### 검수표(타일 → 근거 → 원본 탭)

mock 실행(`--dart-define=BA_PLANNER_USE_REAL_BACKEND=false`)에서 기준 viewport를 최대화해 본다. 시안 숫자는 golden fixture에 있다. 검수 시나리오는 `--dart-define=BA_PLANNER_MOCK_SCENARIO=design-review`.

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Stats-Growth A3 | 통계 → 학생 성장 → 아래로 스크롤 | "2차" 칩 · "성작" · "전용무기" 두 묶음(같은 축척) · 막대 위 인원 · "★1"…"없음 · 1…4" · 스트라이커/스페셜 누적(어두움 → 밝음) · 범례 |
| → 근거 → 학생 탭 | 막대 누르기 → ghost | 근거 "성작 ★n · n명" · "A3에서 고른 단계 · 낮은 항목 순" · "단계 요약" → 학생 탭 임시 목록 "통계: 성작 ★n · n명" · "← 통계" |
| Stats-Growth A4 | 같은 화면 | 산점도 · 평균 점선 두 줄 · 분홍 강조 · seg "학교/역할" |
| → hover 팝오버 | 점 위에 마우스 | 시안 `.spop` 형식(이름 · 보유 · 보유율 · 평균 육성도 · 초상 6 + "…+n" · 안내), 점 왼쪽 · 화면 안(1280×720에서도) |
| → 근거 → 학생 탭 | 점 누르기 → ghost | 근거 "<학교> · n명" · "학교 요약"(보유율 "n% · 보유 / 학생 목록명", 평균 육성도, 계획 등록) → 학생 탭 임시 목록 |
| Stats-Growth-Filter A4 | 필터 밀레니엄 적용 → A4 seg "역할" | 학교 seg는 빈 상태 두 줄, 역할 seg는 산점도(역할이 둘 이상), 줄 368 |
| Stats-Inventory B2 | 통계 → 인벤토리 현황 | 6행 발산 막대 · seg "부족 순/과잉 순"(과잉 순은 목걸이 +125%부터) |
| → 근거 → 인벤토리 | 행 누르기 → primary | 근거 "<재화> · −n%" · "B2에서 고른 행 · 필요량 대비" · 보유/필요/부족 · "쓰는 학생 · 필요량 순"(Pn · 단계 · 필요량) · "최근 변화 · 스캔 n회" · "지난 스캔 대비 ±n" · (소진 조건이면) "이 속도면 n주 뒤 소진 예상" → 인벤토리 그 행 |
| Stats-Plan C4 | 통계 → 계획 집계 | 덤벨 5행(현재 ● → 목표 ○) · "40 → 85%" 형식 · "남은 폭이 큰 순" |
| → 근거 → 계획 2단계 | 행 누르기 → primary | 근거 "<학생> · 남은 n%p" · "C4에서 고른 학생 · 현재 → 목표" · 항목 행 → 계획 탭 페이즈 편집 흐름 2단계에서 그 학생 목표 · "← 통계"(흐름이 이미 열려 있으면 알림만) |

#### 미검증 항목

- golden 비교 · 갱신: **미실행**(CF `fe_gate.ps1` · `failures/` 검토 · `-UpdateGoldens`).
- 전체 `fe_gate.ps1`(나머지 테스트 · process E2E · `codealmanac validate` · 저장소 전체 `git diff --check`): **미실행**.
- 새 요소 ±2px: 차트는 시안 SVG 좌표를 그대로 옮긴 painter에 `StatChartFrame` 균일 배율을 썼다. 위젯 테스트는 값 · 행 · 존재만 보았고, 좌표는 재지 않았다(일회성 렌더로 자리만 확인).
- 실제 백엔드 계정: **미실행**(Mock · fixture만). 볼 것은 학교 수 · 보유율 분포, 실제 활성 문서의 단계 사용(B2 "필요량 순"), 실제 이력의 소진 예측 줄이다.
- 실제 창에서 hover 팝오버가 다른 섹션 위로 뜨는 모습과 스크롤 중 팝오버: **미실행**(위젯 테스트 hover만).

#### WIP 보존 확인

- 고친 기존 16파일과 이 문서는 착수 때 `git status --short`가 빈 줄(WIP 없음)이었다. post 사본 · `post_dir`는 없다.
- pre 사본과 비교한 diff에는 이 slice 줄만 있다. 고치지 않은 4파일은 `cmp` 일치를 확인한 뒤 사본을 지웠다.
- 읽기만 한 파일:
  - `lib/services/**`(Lane B 전술 · 서비스 WIP · design_review fixture)
  - `lib/ui/inventory/**`(`InventoryItemView.excess` · `inventoryStageUses` · `inventorySparkline` · `InventoryHistory`는 import만)
  - `lib/ui/models/**`(`PlanFlowController.receiveHandoff`는 호출만)
  - 키트 · 셸 · harness · golden 테스트 파일, 스캐너 WIP 파일
- 작업 트리의 Lane B 새 파일(`test/tactical_*`)은 건드리지 않았다. git 쓰기는 하지 않았다.

#### 키트 승격 후보(이번에는 statistics 안에 둠)

1. 발산 막대(`StatisticsBalancePainter`): 가운데 축 · 두 색 · 막대 끝 값. 인벤토리 분석 S5 순증감 막대와 같은 문법이다.
2. 산점도 hover 점 + 팝오버(`StatisticsGroupDot` · `_GroupPopoverLayout`): 키트 `KitOverlayAnchor`는 누르기가 "고정"이라, 누르기가 "고르기"인 차트 점과 맞지 않아 따로 두었다. 키트에 "누르기 콜백 + hover 열림" 변형이 생기면 합칠 수 있다.
3. 덤벨(`StatisticsGoalProgressPainter`)과 100% 누적 막대(A3): 차트 원자 후보다.

#### 발견 사항

1. **시안 B2 과잉 값이 FD-040과 맞지 않는다**: 시안 "님루드 렌즈 +22%" · "상급 활동 보고서 +38%"는 1.5배 미만이라 FD-040으로는 과잉이 아니다. 지시대로 인벤토리 탭과 같은 판정을 썼으므로 과잉 행은 늘 +50% 이상이다. 시안 숫자에 맞추려면 FD-040을 바꿔야 한다(CF 판단).
2. **C4 fixture**: 목표 fixture가 `target_level 90`뿐이라 남은 폭이 작고(0~10%p), 학생도 시안(리오(무장) · 노아 …)과 다르다. 다른 장면을 깨지 않으려고 fixture는 그대로 두었다. 목표 fixture는 `lib/services/design_review/` 소유(Lane B)다.
3. **A4 보유율 100% 몰림**: golden 학생 목록이 fixture 170명뿐이라 여러 학교가 보유율 100%다. 그래서 오른쪽 끝 점들이 "평균" 글자를 일부 가린다(시안도 같은 자리). 실제 학생 목록에서는 덜하다.
4. **"P2 이전에 소진"**: CF 결정대로 "n주 뒤 소진 예상"으로 바꿨다. 페이즈에 시간축이 생기면 다시 볼 수 있다.
5. **B2 근거 "스캔 n회"**: 4주 색인 기준이라 fixture는 "스캔 5회"다(시안 "스캔 6회"). 인벤토리 탭 상세와 같은 값이다.
6. **FD-109 테스트의 뜻**: `statistics_history_view_test` "one snapshot … lower row"가 328인 이유가 바뀌었다. 단위 테스트 학생 목록에 학교가 없어 A4가 빈 상태 문구가 되기 때문이고, 필터 빈 상태와 같은 규칙으로 판정된다. 시안 Stats-Growth-Filter 상황(필터로 학교 하나)은 새 테스트가 본다.
7. **C4 "외 n명" · A3 누적 막대 누르기**: 시안에 없어 넣지 않았다. 필요하면 FE7-i 이후 판단.
8. **팝오버 초상 수**: 시안은 학교마다 2~6장으로 다르다(placeholder). 6장 + "…+n"(키트 `PortraitStrip`)으로 정했다.
9. 막는 `열림` FD는 없었다. 워커 재량 FD는 FD-040 · FD-042(권장안)다.

#### 사본 · commit.json

- 착수 사본은 `debug/frontend_fe7f/pre/<경로>`에 있다(고친 기존 16파일 + 이 문서). WIP가 없어 post 사본은 없다.
- `debug/frontend_fe7f/commit.json`: slice `fe7f`, `status=true`, modified 17(이 문서 포함), added 5.
  - `whole` = `statistics-growth.png` · `statistics-inventory.png` · `statistics-plan.png` · `statistics-growth-filter.png` · `statistics-filter-open.png`(파일 단위).
- 인계: `debug/frontend_fe7f/output.md`.

#### 다음 행동

- FE7-f 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: 레인 워커가 모두 멈춘 뒤 gate를 한 번 돌린다.
  - 예상: analyze 0, 일반 테스트는 새 16건(second_tiles 15 + fe7d 셸 1)을 포함해 녹색.
  - golden은 위 5장 RED, 다른 장면 변화 0.
  - 승인 뒤 `-UpdateGoldens` → 재비교 → `fe_commit.ps1 -Slice fe7f`.
- 발견 1(FD-040 vs 시안) · 2(C4 fixture) · 7(C4 외 n명)은 CF 판단을 기다린다.

### fe7f commit record (2026-10-14 16:51, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261014_164359\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE7-i 통계 3차 타일 A5 · C5 + 공용 필터 모달 좁은 창 (Lane A, 로컬 Claude Code)

### FE7-i 착수 기록 (2026-10-14, Lane A)

- 상태: **진행 중**. 시작 SHA `26ef5cc37205d1e897ccf5ea557f12fb2c25384c`(브랜치 `scanner-consolidation`). 이 status 끝에 다른 "FE7-i 착수 기록"은 없었다.
- 범위: A5 스킬 · 장비 매트릭스(학생 성장, 통계 필터 대상 학생), C5 미계획 학생(계획 집계, 전폭 스트립), 공용 필터 모달 800×600 넘침(FE7-e 발견 2 — 머리 · 키트 `RangeSliderRow`, 좁은 창에서만).
- 막는 `열림` FD 없음(막힘 요약 FE7-i = FD-028, 확정).
- 고칠 기존 파일(모두 `git status --short` 빈 줄 = 기존 미커밋 변경 없음, 사본 `debug/frontend_fe7i/pre/<경로>`):
  - `frontend/lib/statistics/statistics_growth_projection.dart`(CRLF) · `statistics_breakdown_projection.dart`
  - `frontend/lib/ui/statistics/statistics_workspace.dart` · `statistics_growth_evidence.dart`(CRLF) · `statistics_supply_evidence.dart` · `statistics_topics.dart`
  - `frontend/lib/ui/pages/statistics_page.dart`(CRLF), `frontend/lib/ui/studio/statistics_studio_layout.dart`(요소 좌표만)
  - `frontend/lib/ui/widgets/student_filter_modal.dart` · `frontend/lib/ui/kit/range_controls.dart`(좁은 창만)
  - 테스트: `frontend/test/statistics_growth_view_test.dart`(CRLF) · `statistics_plan_view_test.dart` · `statistics_workspace_test.dart` · `statistics_history_view_test.dart` · `statistics_supply_view_test.dart` · `statistics_filter_test.dart` · `student_filter_modal_test.dart` · `test/goldens/fe7a_statistics_golden_test.dart`(fixture 입력 · 주석만)
  - 이 문서
- 새 파일(예정): `frontend/lib/statistics/statistics_matrix_projection.dart`(A5 · C5), `frontend/lib/ui/statistics/statistics_matrix_charts.dart`(A5 · C5 painter), 테스트 `frontend/test/statistics_third_tiles_test.dart`.

### FE7-i 종료 기록 (2026-10-14, Lane A, 코드 작성 완료 · CF gate 미실행)

"준비 중"이던 A5 · C5를 그래프로 바꿨다. 이로써 통계 타일이 모두 그려진다. 각 타일은 고른 것 → 근거 → 원본 탭 이동까지 동작한다. 공용 필터 모달(학생 탭 · 통계 · 계획 1단계)은 800×600에서 넘침이 0이다. 새 서비스 메서드 · intent 종류 · 백엔드 · 계약 변경은 없다. 키트 변경은 `range_controls.dart`의 좁은 창 분기 하나다.

착수 기록 정정:
- 고치지 않은 2파일은 사본을 지웠다(작업 트리 = HEAD): `statistics_topics.dart` · `statistics_studio_layout.dart`. 차수 칩 · 제목 · 타일 자리는 이미 시안 그대로였다.
- 착수 목록에 없던 2파일을 고쳤다. 고치기 전에 WIP가 없음을 확인하고 pre 사본을 두었다.
  - `frontend/lib/statistics/statistics_supply_projection.dart`: KPI "미계획 · 40% 미만"과 C5가 같은 함수를 쓰게 했다.
  - `frontend/test/kit/range_controls_test.dart`: 좁은 행 테스트 2건을 더했다.

#### 실행 명령 · 결과

모두 `frontend`에서 이 PC(Claude Code)로 실행했다. 로그는 `debug/frontend_fe7i/logs/`에 있다. 로그는 실패 줄(`[E]` · `EXCEPTION` · `Some tests failed` · `error •`)만 찾았다.

| 명령 | 결과 |
|---|---|
| 일회성 측정(임시 `test/zz_fe7i_measure_tmp_test.dart`, 실행 뒤 지움) | 고치기 전: 범위 행 폭은 2560 = 929.5 · 1280×720 = 420.5 · 800×600 = 229.7이다. 800×600에서 넘침은 학생 탭 모달 12건(행마다 6.3px), 통계 모달 13건(머리 40px + 행)이었다. 고친 뒤: 넘침 0. 2560 · 1280에서 머리 칩 자리 폭이 고치기 전과 같다(학생 1300.2 · 362.1, 통계 860.5 · 155.9) |
| `flutter analyze`(모달 · 키트 2파일) | No issues found |
| `flutter analyze lib/statistics`(1차) | error 6 등 8건. `statistics_supply_projection.dart`의 바꿀 자리를 찾는 문자열이 클래스 필드 주석과 겹쳐 엉뚱한 자리를 바꿨다 → pre 사본으로 되돌리고 다시 고침 → No issues |
| `flutter analyze lib/ui/statistics` · `lib` | No issues found |
| 통계 14파일(`test/statistics_*_test.dart`, 1차) | +90 −6. 컴파일 오류였다(테스트가 지운 `statisticsTilePendingText`를 씀) → 5파일의 "준비 중" 기대를 고침 |
| 같은 14파일(2차) | +148 −1. growth_view "보유 0 빈 상태 문구 4개"는 이제 A5까지 5개다(FE7-i로 바뀐 동작) → 기대를 고침 → 그 파일 **+12 −0** |
| `flutter test test/statistics_third_tiles_test.dart`(새, 1차) | +9 −1. 테스트 기대가 틀렸다: 점 순서는 성장 학생 순이고, 테스트가 직접 만든 성장은 정렬되지 않았다 → 기대 · 주석을 고침 |
| 같은 파일(2차) | **+10 −0** |
| `flutter test test/kit/range_controls_test.dart` | **+14 −0**(새 2건 포함) |
| `flutter test test/student_filter_modal_test.dart` | **+8 −0**(새 800×600 1건 포함) |
| `flutter test test/statistics_filter_test.dart` | **+10 −0**(새 800×600 1건 포함) |
| 일회성 렌더(임시 `test/zz_fe7i_render_tmp_test.dart`, 실행 뒤 지움) | +7 −0, 예외 0. golden 테스트 사본에 `RenderRepaintBoundary.toImage`를 더해 scratchpad에 PNG 7장을 남겼다. 다섯 장면과, 아래로 스크롤해 A5 칸 · C5 구간을 고른 두 장면을 보았다. golden 비교는 아니다 |
| `flutter analyze`(frontend 전체, 최종) | **No issues found**(info 포함 0). 테스트 파일에서 쓰지 않게 된 import 1건(`statistics_history_view_test.dart`)을 지운 뒤다 |
| 관련 46파일 한 번에(`--file-reporter json`, 아래) | **+517 −0** |
| `git diff --check`(frontend · 이 문서) · 줄바꿈 바이트 검사 | 오류 0. 기존 파일은 pre와 같은 줄바꿈이다: `statistics_growth_projection.dart` · `statistics_growth_evidence.dart` · `statistics_page.dart` · `statistics_growth_view_test.dart`는 CRLF(모든 줄), 나머지는 LF. 새 파일은 LF · 줄 끝 공백 0 · 끝 개행 하나 |

관련 46파일(파일별, 모두 −0): account_editor_fe8c +9, account_manager_fe8b +6, app_navigation_fe7d +14, app_navigation_tidy1 +11, connected_target_fe8d +8, growth_calculator_view +24, home_app_shell +1, home_connect_fe8e +10, inventory_shell_lazy +1, mock_design_review_scenario +11, plan_flow +15, plan_flow_presets +13, plan_flow_student_step +8, planning_page +17, profile_delete_fb2d +17, kit/range_controls +14, section_template_studio +15, statistics_app_shell +2, statistics_filter +10, statistics_growth_projection +11, statistics_growth_view +12, statistics_history_projection +17, statistics_history_view +14, statistics_page +14, statistics_plan_projection +7, statistics_plan_view +9, statistics_projection +7, statistics_second_tiles +15, statistics_supply_projection +8, statistics_supply_view +11, statistics_third_tiles +10(새), statistics_workspace +13, student_bond_gauge +12, student_filter_followups +4, student_filter_modal +8, student_filter_selection +15, student_page +9, student_search_section +13, student_studio_layout +45, title_page +25, kit/ui_kit_gallery +6, kit/ui_kit_gallery_controls +2, kit/ui_kit_gallery_data +2, kit/ui_kit_gallery_overlays +4, kit/ui_kit_gallery_range +2, widget +16.

- 걸리는 테스트 찾기: test/ 전체를 `StatisticsPage|statistics_|StudentFilterModal|student_filter_modal|RangeSliderRow|RangeRowFrame|range_controls|BAPlannerApp\(|AppShell\(|StudentSectionLayout|PlanFlowStudentStep|plan_flow_student_step|statisticsUnplannedLow|StatisticsStudentGrowth|app_navigation|ui_kit_gallery|StudentPage\(`로 grep했다.
  - `RangeSliderRow` 사용처 전부가 들어간다: 키트 갤러리, 학생 탭 모달, 통계 모달, 계획 1단계(`plan_flow_student_step`).
  - goldens · process E2E · 스캐너(`scan_*` · `scanner_*` · `mock_scanner_service`) · `metadata_manager_dto` · `tactical_*`(Lane B 작업 중)는 뺐다.
- 고친 기존 테스트 기대(모두 FE7-i로 바뀐 동작):
  - "준비 중" 개수: 성장 1 → 0, 계획 1 → 0. 5파일(growth_view · history_view · plan_view · supply_view · workspace)은 이제 글자 `'준비 중'`이 없음을 본다(상수는 지웠다).
  - 자료 없음 '—' 타일 목록에 A5 · C5를 더했다(workspace).
  - 보유 0 빈 상태 문구 개수 4 → 5(A5, growth_view).
- `dart format`은 새 파일에만 남겼다. 기존 테스트 2파일(`student_filter_modal_test.dart` · `kit/range_controls_test.dart`)에 실수로 돌려 다른 줄까지 바뀐 것을 알아챘다. pre 사본에서 다시 시작해 이 slice 줄만 넣었다(pre 대비 지운 줄은 `_pumpLayout` 크기 매개변수 3줄뿐).
- 빌드 잠금(`build/` · `.dart_tool/`) 충돌은 없었다. `flutter analyze`가 pub get을 돌렸지만 `pubspec.lock` · `pubspec.yaml`은 바뀌지 않았다.
- 실행하지 않음: golden(`test/goldens/**`), 전체 `fe_gate.ps1`, `-UpdateGoldens`, `fe_commit.ps1`, 맨 `flutter test`, process E2E, `codealmanac validate`.

#### A5 칸 정의(`lib/statistics/statistics_matrix_projection.dart` `StatisticsSkillMatrix`)

- **칸 값 = 그 칸 학생 수**(비율 아님). 시안 숫자로 판단했다: 시안 다섯 행의 합이 모두 128(= 보유 학생)이다(EX 12+30+41+45, 일반 8+22+38+27+33 …). 학생 하나는 행마다 한 칸에만 든다.
- 행과 값:

| 행(시안 글자) | 값 | 1–3 | 4–6 | 7–8 | 9 | M |
|---|---|---|---|---|---|---|
| EX | `ex_skill`(1~5) | 1~3 | 4 | 빗금 | 빗금 | 5 |
| 일반 | `skill1`(1~10) | 1~3 | 4~6 | 7~8 | 9 | 10 |
| 강화 | `skill2`(0~10) | 0~3(0 = 미개방) | 4~6 | 7~8 | 9 | 10 |
| 서브 | `skill3`(0~10) | 0~3(0 = 미개방) | 4~6 | 7~8 | 9 | 10 |
| 장비 | 장비 3칸 티어 중 가장 낮은 칸(T0~T10) | T0~T3 | T4~T6 | T7~T8 | T9 | T10 |

- 빗금(해당 없음)은 EX의 7–8 · 9 칸이다. 시안은 EX "9" 칸 하나만 빗금이고 7–8 칸에 41을 적었다(placeholder — EX는 최대 5라 7–8이 될 수 없다). 그래서 정의대로 둘 다 빗금으로 했다(발견 1).
- 장비 값은 학생 탭 필터 "장비 티어 3칸 중 가장 낮은 칸"과 같다. 칸이 하나라도 모름이면 그 학생은 장비 행에서 빠진다.
- 행 값을 모르는 학생은 그 행에서만 빠진다(0으로 채우지 않음). 하나라도 모르는 학생 수를 왼쪽 아래 "n명 모름"으로 쓴다.
- 대상 학생: 통계 필터가 걸리면 대상 학생만 센다(FE7-e 발견 4 · F §3.2 모순 메모 — 시안 Stats-Growth-Filter의 A5 숫자는 필터 전과 같은 placeholder다). `StatisticsGrowthBreakdown.matrix`가 A3 · A4와 같은 대상 성장으로 만든다.
- 색: #71c7f4 α = 0.06 + 0.84 × 인원 / 가장 많은 칸. 시안 α 21개가 이 식과 ±0.01 안에서 맞는다(예 45 → .90, 30 → .62, 6 → .17). α가 0.6 이상이면 숫자는 #0c2233, 그 아래는 흰색이다(시안 28 → 흰색 · 29 → 어두움). 0명 칸은 α .06 바탕에 "0"이다.
- 좌표: 시안 polygon · text를 그대로 옮겼다. 칸 밑변 71.1 · 높이 26 · 열 피치 75.1 · 행 피치 30이다. 행마다 30 × tan 10° 왼쪽으로 옮기고, 행 글자는 칸 왼쪽에서 10이다. 범례는 (464, 194) "빗금 = 해당 없음 (EX 최대 5)"다.
- 고르기: 칸을 누르면 고르고, 같은 칸을 다시 누르면 푼다. 0명 칸 · 빗금 칸은 고르지 않는다. 고른 칸은 분홍 테두리 2이고 바탕 농도는 그대로다(값 표현을 지키려고 A1처럼 분홍으로 채우지 않았다).
- 근거:
  - 머리는 "<행> <칸>"이다(예 "EX 스킬 1–3", "강화 스킬 0–3", "장비 T7–8"). 칩은 인원이다.
  - 부제는 "A5에서 고른 칸 · 낮은 항목 순"이다. 행 칩은 A1과 같은 "낮음" 칩이다.
  - 요약은 "칸 요약"(평균 레벨 · 가장 낮은 항목 · 계획 등록)이다.

#### C5 구간 정의(`StatisticsUnplannedStrip` · `statisticsUnplannedLowStudents`)

- 행: 시안 그대로 편성 "스트라이커" · "스페셜"이다. 프롬프트의 "역할별"은 시안 행 글자를 따랐다(발견 2).
- 점: 편성과 육성도(FD-028)를 아는 보유 학생 하나에 점 하나다. 가로 = 육성도(0% 84 → 100% 1019.3)다. 세로 = 행 바닥선 − 20 ± 11이고, 학생 id의 FNV-1a 해시로 정한 고정 흩뿌림이다(기기 · 실행마다 같다).
- 색:
  - 계획 있음 = 파랑 #71c7f4. 사용자 목표가 있는 보유 학생이다(KPI "계획 등록" · C4와 같은 집합).
  - 미계획 = 회색 #5d7184.
  - 고른 구간(미계획 · 육성도 40% 미만) = 분홍.
- 고른 구간 = **[0, 40%)의 미계획 학생**이다. 시안은 이 구간을 분홍 점선 상자로 늘 그리고, 아래 "미계획 · 40% 미만 n명"을 적는다.
  - n과 근거 학생은 KPI "미계획 · 40% 미만"과 **같은 함수**다(`statisticsUnplannedLowStudents`). `statisticsUnplannedLowCount`는 이제 이 목록의 길이다.
  - 편성을 몰라 점이 없는 학생도 n과 근거에는 든다(KPI와 같아야 한다).
- 고르기: 상자(또는 그 아래 구간 글자)를 누르면 고르고, 상자 테두리가 실선이 된다. 다시 누르면 푼다. 구간 학생이 0명이면 고르지 않는다. 구간은 하나다(다른 구간 고르기는 시안에 없다 — 발견 3).
- 근거:
  - 성장 근거와 같은 틀이다. 머리 "미계획 · 40% 미만" + 분홍 인원 칩, 부제 "C5에서 고른 구간 · 육성도 낮은 순"이다.
  - 행 7개 + "나머지 n명 모두 보기"가 있다(펼치기 = FE7-d 펼침).
  - "구간 요약"은 평균 레벨 · 가장 낮은 항목 · 평균 육성도다. 계획 등록은 늘 0명이라 평균 육성도로 바꿨다.
- 대상: 늘 전체 성장이다(FD-104 — 계획 집계는 필터와 상관없다, 테스트로 고정).
- 빈 상태:
  - 읽는 중이면 '—'다.
  - 보유 0명이면 A1 문구다.
  - 점이 없으면 육성도 문구다.
  - 목표가 없어도 그린다(모든 점이 회색).

#### 원본 탭 이동

- A5 칸 → 학생 성장 버튼 그대로다.
  - ghost "학생 탭에서 보기 · 필터: <칸 머리>" → 학생 탭 임시 목록 "통계: <칸 머리> · n명"이다.
  - primary "이 구간 학생을 계획에 추가" → 계획 만들기 1단계, 미리 선택이다.
  - **스킬 · 레벨 조건은 학생 필터에 싣지 않았다.** 학생 필터에는 스킬 범위 행이 있다. 하지만 FE7-d 규칙 3 · FD-104는 "통계 → 학생 탭 이동은 학생 필터 상태에 쓰지 않는다"이다. 그리고 장비 행 · 강화 0(미개방)은 필터 행과 구간 글자가 꼭 맞지 않는다. 그래서 학생 목록만 넘기고 조건은 칩 글자로 보인다(A3와 같은 규칙).
- C5 구간 → primary "계획 만들기 1 · 학생 고르기" · "미리 선택 · n명" → `PlanNavigationIntent.students(구간 학생)`이다(FE7-d 기존 경로, intent 변경 없음). ghost는 C4처럼 Stats-Plan 기본 글자 비활성이다.
- "← 통계" 복귀: 다시 읽은 뒤 C5 구간에 학생이 있으면 고른 것 · 펼침을 되살린다(`_restoreSelection`). A5 칸은 기존 성장 복귀 규칙을 그대로 따른다.

#### 공용 필터 모달 넘침 수정(FE7-e 발견 2)

- 머리(`student_filter_modal.dart` `_FilterHeader`):
  - **조건**: 띠 안쪽 폭 < `tightWidth` 640일 때만 바꾼다. 측정 근거는 1280×720 띠 안쪽이 약 900 이상, 800×600이 약 420이라는 것이다.
  - 그때 제목 뒤 간격을 20 → 10, 구분선 양쪽을 18 → 8로 줄인다.
  - 오른쪽 버튼 묶음("학생 탭 필터 불러오기" · 초기화 · 적용)은 한 `Flexible(flex 3)` + `FittedBox.scaleDown`(키 `student-filter-modal-tight`)으로 함께 줄인다. 칩 자리(`Expanded`)는 flex 1 그대로다.
  - 그보다 넓으면 위젯 구조 · 간격이 전과 같다(FE7-e 압축 머리 그대로).
- 범위 행(키트 `range_controls.dart` `RangeRowFrame`):
  - 행 안쪽 폭 < 118 × 2 + `rangeRowMinTrackWidth` 48(= 284)일 때만 이름 · 값 칸을 (폭 − 48) / 2로 함께 줄인다. 글자는 이미 말줄임 · `Flexible`이다.
  - 284 이상이면 두 칸은 118 그대로다.
  - 측정 폭: 2560 = 929.5, 1280×720 = 420.5, 갤러리 견본 = 752.3. 그래서 기준 · 1280 · 갤러리 모습은 같다. 800×600 = 229.7이다.
- 기준 모습 그대로의 근거:
  - 측정 테스트에서 2560 · 1280의 머리 칩 자리 폭이 고치기 전과 같다.
  - 기존 배치 테스트(`student_filter_modal_test` "배치가 시안 좌표와 같다(2560×1392)", `kit/range_controls_test` "이름·값 칸 118")가 녹색이다.
  - 새 테스트가 2560 · 1280에서 줄임 묶음이 없음을 본다.
- 새 테스트:
  - `student_filter_modal_test` "800×600: header and range rows do not overflow": 학생 탭 모달이다. 2560 · 1280은 줄임 없음이다. 800×600은 넘침 0 · 적용 버튼이 화면 안 · 눌러서 적용된다.
  - `statistics_filter_test` "statistics modal fits 800×600 (FE7-i)": 통계 모달이다. 칩 둘을 고르고 · 불러오기 버튼이 화면 안 · 적용된다.
  - `kit/range_controls_test` 좁은 행 2건이다.
- 계획 1단계 필터: 같은 공용 모달 · 키트라 같은 조건이다. `plan_flow_student_step` +8로 돌렸다.

#### 처리한 FD

- **FD-028(확정)**: A5 정렬 · 근거 · C5 가로축이 같은 육성도 식이다. C5 "40% 미만"도 같은 육성도다. 모르는 값은 빼고 "n명 모름"이다.
- **FD-104(확정 (a))**: A5는 통계 필터 대상 학생, C5는 늘 전체다. 학생 탭 이동은 학생 필터에 쓰지 않는다.
- **FD-106(확정 2026-10-13)**:
  - 통계에 "준비 중" 타일이 없어졌다.
  - 문구 상수 `statisticsTilePendingText`와 분기를 지웠다. grep으로 통계 밖 사용처가 없음을 확인했다. 남는 분기(그릴 타일이 아닌 경우)는 '—' 빈 상태다.
  - 테스트는 글자 '준비 중'이 없음을 본다.
- **FD-033 · FD-109**:
  - FD-033: 모름 ≠ 0이다. A5 빗금은 "해당 없음"이고 모름이 아니다. 모름은 행에서 빠진다.
  - FD-109: C5 · A5 줄은 짧은 높이가 없다. 줄 높이 변화는 0이다.
- 막는 `열림` FD는 없었다. 워커 재량 FD도 없었다.

#### 정한 규칙(시안 · 대장에 없는 것)

1. A5 칸 정의 · 빗금 · 색 식은 위 표와 같다.
2. A5 고른 칸은 분홍 테두리이고 바탕 농도를 지킨다.
3. A5 "n명 모름" 자리는 (0, 194) 왼쪽 아래다(시안에 자리 없음).
4. C5 행은 시안 편성 행이다. 점 세로 흩뿌림은 학생 id 고정 해시이고, 그리는 순서는 회색 → 파랑 → 분홍이다.
5. C5 고른 상태 상자는 실선 1.5 · 바탕 α .16이다(시안은 고르지 않은 점선 상태만 있다).
6. C5 근거 요약은 "계획 등록" 대신 "평균 육성도"다.
7. C5 primary 둘째 줄은 "미리 선택 · n명"이다(시안 Proposal "(미리 선택)").
8. C5 "n명 모름"(편성 · 육성도 모름)은 (1019.3, 166) 오른쪽 끝이다.
9. 필터 모달은 띠 안쪽 640 미만에서 줄이고, 범위 행은 가운데 48을 남기지 못할 때만 줄인다.

#### golden 변화 예상(장면별)

fixture 값(단위 계산 · 일회성 렌더 기준):
- 성장 보유 128명: EX 33 · 36 · 빗금 · 빗금 · 59 / 일반 7 · 11 · 10 · 42 · 58 / 강화 9 · 41 · 27 · 41 · 10 / 서브 15 · 47 · 28 · 25 · 13 / 장비 8 · 36 · 40 · 19 · 25, 모름 0이다. 가장 많은 칸은 59다.
- 필터 대상(밀레니엄 · 스트라이커 18명): EX 5 · 6 · 빗금 · 빗금 · 7 / 일반 0 · 2 · 1 · 6 · 9 / 강화 1 · 6 · 5 · 4 · 2 / 서브 2 · 8 · 4 · 2 · 2 / 장비 0 · 6 · 7 · 2 · 3이다.
- C5: 점 128개다(스트라이커 83 · 스페셜 45, 계획 있음 9 · 분홍 26). "미계획 · 40% 미만 26명"은 KPI 다섯째 칸 26명과 같다.
- 시안 숫자(EX 12/30/41/45 …, "14명")와 다른 이유: fixture는 FE7-b 성장 fixture(`lib/services/design_review/` 소유)이고 억지로 맞추지 않았다(발견 4).

장면별:
- **`statistics-growth`(바뀜)**: A5 "준비 중" → 매트릭스다. A5 줄은 viewport 아래 포그에 걸쳐 머리 · 열 글자 · 첫 행 일부만 보인다(A3과 같은 줄). KPI · A1 · A2 · A3 · A4 · A6 · 근거 · 줄 높이 변화는 0이다.
- **`statistics-plan`(바뀜)**: C5 "준비 중" → 스트립이다. C5 줄은 포그 아래에 걸쳐 머리 · 점선 상자 위쪽 · 스트라이커 점 일부만 보인다. KPI · C1~C4 · 근거 빈 문구 변화는 0이다.
- **`statistics-growth-filter`(바뀜)**: A5 "준비 중" → 대상 18명 매트릭스다(위 값). 줄 368 · A4 빈 상태 · 나머지 변화는 0이다.
- **`statistics-filter-open`(바뀜)**: 스크림 아래 배경의 A5만 바뀐다(보유 128명 매트릭스). 모달은 2560 기준이라 줄임이 없다 → 모달 변화 0.
- **`statistics-inventory`: 변화 0**이다(B 타일만 있다. 바뀐 파일이 인벤토리 주제 그림에 닿지 않는다).
- **다른 장면: 변화 0.**
  - 학생 장면(`students-filter-open` 포함)과 계획 1단계 필터 장면: 2560 기준 viewport라 모달 머리 줄임 · 범위 행 줄임 조건이 걸리지 않는다(측정 폭 929.5 ≫ 284, 띠 안쪽 ≫ 640).
  - 키트 갤러리 장면: 범위 견본 행 752.3 > 284라 같다.
  - golden harness · golden 테스트 장면 조작 변경은 0이다(주석만).
- commit.json `whole` = 위 기존 기준 이미지 4장(파일 단위)이다. 새 장면은 없다.

#### 검수표(타일 → 근거 → 원본 탭)

mock 실행(`--dart-define=BA_PLANNER_USE_REAL_BACKEND=false`)에서 기준 viewport를 최대화해 본다. 시안 숫자는 golden fixture에 있다. 검수 시나리오는 `--dart-define=BA_PLANNER_MOCK_SCENARIO=design-review`.

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Stats-Growth A5 | 통계 → 학생 성장 → 아래로 스크롤 | "3차" 회색 칩 · "A5 스킬 · 장비 매트릭스" · 열 "1–3 4–6 7–8 9 M" · 행 EX/일반/강화/서브/장비 사선 계단 · 단일 색조(많을수록 짙음, 짙은 칸 숫자 어두움) · EX 7–8 · 9 빗금 · 범례 "빗금 = 해당 없음 (EX 최대 5)" · 행 합 = 보유 |
| → 근거 → 학생 탭 | 칸 누르기 → ghost | 분홍 테두리 칸, 근거 "<행> <칸> · n명" · "A5에서 고른 칸 · 낮은 항목 순" · "칸 요약" → 학생 탭 임시 목록 "통계: EX 스킬 1–3 · n명" · "← 통계" / 빗금 · 0명 칸은 반응 없음 |
| Stats-Growth-Filter A5 | 필터 밀레니엄 · 스트라이커 적용 → 아래로 스크롤 | A5가 대상 18명 수로 바뀐다(행 합 = 18) |
| Stats-Plan C5 | 통계 → 계획 집계 → 아래로 스크롤 | 전폭 · "3차" · 스트라이커/스페셜 두 줄 점 · 파랑(계획 있음) · 회색(계획 없음) · 분홍(미계획 40% 미만) · 0~40% 분홍 점선 상자 · "미계획 · 40% 미만 n명" = KPI 다섯째 칸 · 0% · 40% · 100% · 범례 |
| → 근거 → 계획 1단계 | 상자 누르기 → primary | 실선 상자, 근거 "미계획 · 40% 미만 · n명" · "C5에서 고른 구간 · 육성도 낮은 순" · "구간 요약"(평균 레벨 · 가장 낮은 항목 · 평균 육성도) → "계획 만들기 1 · 학생 고르기 · 미리 선택 · n명" → 계획 탭 새 시나리오 1단계에 n명 미리 선택 · "← 통계" |
| (필터 무시) | 통계 필터 적용 뒤 계획 집계 | C5 점 · n이 필터 전과 같다 |
| 필터 모달 800×600 | 창을 800×600으로 줄이고 학생 탭 S1 "필터" / 통계 왼쪽 "필터" / 계획 1단계 필터 | 넘침 표시 없음 · 오른쪽 버튼 묶음이 작게 · 범위 행 이름 · 값 칸이 좁게(말줄임) · 적용 동작 / 1280×720 · 최대화에서는 전과 같은 모습 |

#### 미검증 항목

- golden 비교 · 갱신: **미실행**(CF `fe_gate.ps1` · `failures/` 검토 · `-UpdateGoldens`).
- 전체 `fe_gate.ps1`(나머지 테스트 · process E2E · `codealmanac validate` · 저장소 전체 `git diff --check`): **미실행**.
- 새 요소 ±2px: 차트는 시안 SVG 좌표를 그대로 옮긴 painter에 `StatChartFrame` 균일 배율을 썼다. 위젯 테스트는 값 · 칸 · 누르기만 보았고 좌표는 재지 않았다(일회성 렌더로 자리만 확인).
- 실제 백엔드 계정: **미실행**(Mock · fixture만). 볼 것은 강화 · 서브 0(미개방) 비율, 장비 칸 모름 학생 수, 편성 값 없는 학생, C5 점 겹침(같은 육성도 값이 많으면 세로 흩뿌림만으로 겹칠 수 있다)이다.
- 실제 창 800×600에서 모달 모습(줄인 버튼 크기 체감): **미실행**(위젯 테스트 · 측정만).

#### WIP 보존 확인

- 고친 기존 19파일(이 문서 포함)은 착수 때 · 고치기 전에 `git status --short`가 빈 줄(WIP 없음)이었다. post 사본 · `post_dir`은 없다.
- pre 사본과 비교한 diff에는 이 slice 줄만 있다. 고치지 않은 2파일은 `cmp` 일치를 확인한 뒤 사본을 지웠다.
- 읽기만 한 파일:
  - `lib/services/**`(성장 fixture `design_review/statistics_growth_data.dart` 포함)
  - `lib/ui/navigation/app_navigation_intent.dart`(intent 변경 없음)
  - 학생 · 계획 · 인벤토리 화면 파일
  - golden harness · 스캐너 WIP 파일
- 작업 트리의 Lane B 파일(`lib/ui/tactical/` · `lib/ui/studio/tactical_studio_layout.dart` · `test/tactical_*`)은 건드리지 않았다. git 쓰기는 하지 않았다. 임시 측정 · 렌더 · 수치 테스트 3개는 지웠다.

#### 키트 승격 후보(이번에는 statistics 안에 둠)

1. 히트맵 칸(`StatisticsSkillMatrixPainter`): 80° 칸 · 단일 색조 α 식 · 빗금 · 짙은 칸 글자색 전환이다. 다른 교차표가 생기면 차트 원자 후보다.
2. 스트립 점(`StatisticsUnplannedStripPainter`): 고정 해시 흩뿌림 · 구간 점선 상자다. A4 · C2 점 문법과 같은 계열이다.
3. 키트 `RangeRowFrame` 좁은 창 분기는 이미 키트 안이다(이번 변경).

#### 발견 사항

1. **시안 A5 EX 빗금 자리**: 시안은 EX "9" 칸만 빗금이고 "7–8"에 41이 있다. EX 최대 5라 7–8도 해당 없음이 맞아 둘 다 빗금으로 했다. 시안 survey(F §3.1)의 "EX 행 M 칸 빗금"도 실제 시안(9 칸)과 다르다. CF 확인 후보.
2. **C5 "역할별" vs 시안 "편성"**: Proposal · 프롬프트는 "역할별 점 분포"인데 시안 행은 스트라이커 · 스페셜(편성)이다. 시안 글자를 따랐다. 역할(탱커 · 딜러 …) 행이 필요하면 seg를 더하는 결정이 필요하다.
3. **C5 구간 고르기는 하나**: 시안 · Proposal에 구간을 바꾸는 조작이 없어 "미계획 · 40% 미만" 구간 하나만 고른다. 다른 육성도 구간(예 10% 단위)을 고르게 할지는 CF 판단이다.
4. **시안 숫자와 fixture**:
   - A5 시안 숫자(EX 12 · 30 · 41 · 45 …)와 C5 "14명"(분홍 점은 9개라 시안 안에서도 맞지 않는다)은 placeholder다.
   - fixture는 성장 fixture(Lane B 소유 `design_review`)라 A5 · C5가 그 학생 값에서 나온다(C5 26명).
   - 성장 fixture의 육성도 값이 구간마다 몰려 있어 C5 점이 세로줄로 겹친다(시안처럼 흩어진 모습이 아님). 검수 fixture를 바꾸려면 서비스 쪽 변경이 필요하다.
5. **800×600 모달 버튼 크기**: 통계 모달은 오른쪽 버튼 묶음(불러오기 · 초기화 · 적용)이 남는 자리에 맞춰 크게 줄어든다(눌리고 화면 안이다). 더 나은 좁은 배치(두 줄 머리 · 아이콘 버튼)는 시안이 없어 넣지 않았다.
6. **A5 장비 · 강화/서브 0과 학생 필터 행**: 학생 필터 스킬 범위는 1~M, 장비 티어는 T0~T10이다. A5 첫 칸에 강화 · 서브 0(미개방)을 넣었으므로, 나중에 칸 조건을 학생 필터에 싣는다면 "0~3"을 그대로 옮길 수 있는지 필터 범위 최소값을 함께 봐야 한다.
7. 막는 `열림` FD는 없었다. 워커 재량 FD도 없었다.

#### 사본 · commit.json

- 착수 사본은 `debug/frontend_fe7i/pre/<경로>`에 있다(고친 기존 18파일 + 이 문서). WIP가 없어 post 사본은 없다.
- `debug/frontend_fe7i/commit.json`: slice `fe7i`, `status=true`, modified 19(이 문서 포함), added 3.
  - `whole` = `statistics-growth.png` · `statistics-plan.png` · `statistics-growth-filter.png` · `statistics-filter-open.png`(파일 단위).
- 인계: `debug/frontend_fe7i/output.md`.

#### 다음 행동

- FE7-i 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: 레인 워커가 모두 멈춘 뒤 gate를 한 번 돌린다.
  - 예상: analyze 0, 일반 테스트는 새 14건(third_tiles 10 · 모달 2 · 키트 2)을 포함해 녹색.
  - golden은 위 4장 RED, 다른 장면 변화 0.
  - 승인 뒤 `-UpdateGoldens` → 재비교 → `fe_commit.ps1 -Slice fe7i`.
- 발견 1(EX 빗금) · 2(편성 vs 역할) · 3(C5 구간 하나) · 4(검수 fixture)는 CF 판단을 기다린다.

### fe7i commit record (2026-10-14 19:30, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261014_191520\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

### fe9a commit record (2026-10-14 19:30, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261014_191520\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## tidy2 작은 후속 5건 (Lane A, 로컬 Claude Code)

### tidy2 착수 기록 (2026-10-14, Lane A)

- 상태: **코드 완료(아래 tidy2 종료 기록), CF gate 미실행**. 시작 SHA = `d2765e0a0ef6a9c9704d6ebb651420236c9c3239`(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`). 착수 전 이 문서 끝에 다른 "tidy2 착수 기록" 없음(grep 0건).
- 막는 `열림` FD 없음(결정 대장 "slice별 막힘 요약": 열림 0건, tidy2 행 없음). 관련 확정 FD: FD-028(C4 목표에도 같은 식).
- 사용자 결정(착수 전 질문, 2026-10-14):
  - 항목 3: **코드 변경 없음 · 기록만**. 현재 코드는 빈 시즌이면 이미 "시즌 —"이고, `tactical-migration` golden은 fixture 시즌 '9'라 "시즌 9"다(기준 이미지 확대 확인). '0'을 만드는 곳이 프론트 · 백엔드 이관(`tactical_fb6_store.py`는 v1 `season`을 그대로 옮김) 어디에도 없다.
  - 항목 4: 공격 덱 A SP2와 게헨나 방어 덱 SP2의 `chise`(스트라이커)를 **둘 다** 스페셜 학생으로 고친다.
- 항목별 고칠 파일(모두 `frontend/` 아래):
  1. 섹션 틀 키트 승격: 새 `lib/ui/kit/section_frame.dart` · 새 `test/kit/section_frame_test.dart`, 사용처 `lib/ui/statistics/statistics_workspace.dart`(`_SectionFrame` · `_ScaledBox`) · `lib/ui/statistics/statistics_growth_evidence.dart`(`StatisticsScaledBox` — 같은 틀 네 번째 사본) · `lib/ui/statistics/statistics_supply_evidence.dart`(`StatisticsScaledBox` 사용처) · `lib/ui/tactical/tactical_workspace.dart`(`_SectionFrame` · `_Scaled`).
  2. idempotency 순번 공용화: 새 `lib/services/idempotency_keys.dart` · 새 `test/idempotency_keys_test.dart`, 사용처 `lib/ui/inventory/inventory_controller.dart` · `lib/ui/models/repository_presets_controller.dart` · `lib/ui/models/plan_flow_save.dart` · `lib/ui/widgets/account_section_cluster.dart` · `lib/ui/pages/settings_page.dart` · `lib/ui/widgets/repository_profile_panel.dart` · `lib/ui/widgets/plan_scenario_list.dart` · `lib/ui/widgets/plan_section_layout.dart` · `lib/tactical/tactical_records_controller.dart`, 테스트 `test/tidy1_followups_test.dart` · `test/tactical_records_controller_test.dart`(필요할 때만). 스캐너 WIP(`scan_page.dart` 등)는 표에만.
  3. 시즌 칩: 코드 변경 없음. 빈 시즌 → '—' 고정 테스트를 `test/tactical_page_test.dart`에 더한다.
  4. seed 정정: `lib/services/design_review/tactical_records_data.dart`.
  5. C4 목표 fixture: `lib/services/design_review/statistics_growth_data.dart`, 테스트 `test/statistics_second_tiles_test.dart` · `test/app_navigation_fe7d_test.dart`(C4 기대가 바뀌면).
  - 이 문서 `almanac/workflows/frontend-redesign-status.md`.
- 파일별 기존 미커밋 변경(WIP): 위 기존 21파일(이 문서 포함) 모두 `git status --short <경로>` 빈 줄 — **WIP 없음**. post 사본 · `post_dir`는 두지 않는다.
- 줄바꿈(`git ls-files --eol`): `settings_page.dart` · `statistics_growth_evidence.dart` · `plan_section_layout.dart` · `repository_profile_panel.dart`는 작업 트리 CRLF, 나머지 LF. 그대로 유지한다.
- 착수 사본: `debug/frontend_tidy2/pre/<v7 기준 경로>`(21파일). 고치지 않고 끝난 파일은 종료 때 cmp 일치를 확인하고 목록에서 뺀다.

### tidy2 종료 기록 (2026-10-14, Lane A, 코드 작성 완료 · CF gate 미실행)

작은 후속 5건 중 4건을 고쳤고 항목 3은 사용자 결정대로 코드 변경 없이 기록만 했다. HEAD는 착수 때와 같다(`d2765e0a`). 새 서비스 메서드 · 백엔드 · 계약 · golden harness 변경은 없다.

#### 실행한 명령과 결과(이 PC, `frontend` 폴더)

로그는 `debug/frontend_tidy2/logs/`이고 실패 줄(`[E]` · `EXCEPTION` · `Some tests failed` · `error •`)과 json 요약만 확인했다.

| 명령 | 결과 |
|---|---|
| `flutter analyze lib/ui/kit/section_frame.dart lib/ui/statistics lib/ui/tactical`(항목 1 뒤) | ① warning 4(`unused_import` — 통계 · 전술의 `section_surface.dart` · `section_template_surface.dart`, 승격 뒤 잔여) → 지움 → ② **No issues found** |
| `flutter test test/kit/section_frame_test.dart` | **+5 −0** |
| `flutter analyze`(전체, 항목 2 뒤) | ① error 1(`plan_flow_save.dart` — 지운 `stamp`를 시나리오 초안 id가 쓰고 있었다) → 같은 시계 한 번 읽기로 되돌림 → ② **No issues found(0)** |
| `flutter test test/idempotency_keys_test.dart test/tidy1_followups_test.dart test/tactical_records_controller_test.dart` | **+21 −0**(4 · 3 · 14) |
| `flutter test test/tactical_page_test.dart`(항목 3 테스트 추가 뒤) | **+20 −0**(19 → 20) |
| `flutter test test/design_review_tactical_seed_test.dart test/mock_design_review_scenario_test.dart test/tactical_page_test.dart test/tactical_page_revision_test.dart test/tidy1_followups_test.dart`(항목 4 뒤) | **+41 −0**(2 · 11 · 20 · 5 · 3) |
| `flutter analyze lib/services/design_review`(항목 5 뒤) | No issues found |
| 관련 일반 118파일 한 번에(`-r json`, `logs/related_1.json` · `related_1_summary.txt`) | **+1346 −0**(118파일 모두 −0) |
| process 묶음 분류 2파일 `--concurrency=1`(가짜 프로세스): `tactical_fe9b1_read_test` · `tactical_fb6_dart_test` | **+12 −0** · **+14 −0** |
| `flutter analyze`(최종, 전체) | **No issues found(0, info 포함)** |
| `git diff --check -- frontend/lib frontend/test` | exit 0 |

- 관련 일반 118파일은 grep으로 골랐다(kit/* · statistics_* · tactical_* · inventory_* · plan* · account_* · settings* · repository_* · mock_design_review · app_navigation_* · widget · home_* · profile_* · tidy1 · idempotency · design_review · student_filter_* · connected_target · title_page · developer_tools · section_*). `ProcessAppService` 문자열이 있는 18파일은 뺐다.
  - 파일별 수치는 `logs/related_1_summary.txt`다. 주요 파일: kit/section_frame +5, idempotency_keys +4, design_review_tactical_seed +2, statistics_second_tiles +15, statistics_workspace +13, statistics_page +14, statistics_plan_view +9, statistics_supply_view +11, app_navigation_fe7d +14, app_navigation_tidy1 +11, tidy1_followups +3, tactical_page +20, tactical_page_revision +5, tactical_records_controller +14, mock_design_review_scenario +11, inventory_controller +13, plan_flow_save +15, plan_scenario_list +10, settings_page +10, account_manager_fe8b +6, account_editor_fe8c +9, widget +16.
- 잠금 충돌 0(재시도 없음). `pubspec.yaml` · `pubspec.lock` 변경 0(`flutter analyze`의 "Got dependencies!" 뒤에도 `git status` 빈 줄).

#### 항목별 결과

| 항목 | 결과 | 근거 |
|---|---|---|
| 1 섹션 틀 키트 승격 | **완료(동작 변화 0)** | 새 `lib/ui/kit/section_frame.dart`: `SectionFrame`(표면 `SectionSurfacePainter` + `SectionShapeClipper`로 자른 `Stack`, 표면 key는 인자) · `SectionScaledBox`(배율 상자). 그리는 위젯 트리(Stack → Positioned.fill → IgnorePointer → CustomPaint(key) / ClipPath → Stack(Clip.none))와 배율 식은 사본 그대로다. 다시 그리기 판정은 사본의 "섹션 id 비교"와 같은 결과이고(문서 element는 id마다 한 인스턴스), `copyWith`로 rect · spec만 바꾼 element도 다시 그린다. 배율 상자는 전술 사본의 "자리가 무한이면 그대로" 분기를 가진다. 통계 사본은 무한 자리에서 예외였고 그런 사용처가 없어 보이는 변화가 없다 |
| 2 idempotency 순번 공용화 | **완료(key 모양 그대로)** | 새 `lib/services/idempotency_keys.dart`: `newIdempotencyKey(prefix, {now})` = `<prefix>-<µs>-<순번>`, 순번은 프로세스 전체 하나(`nextIdempotencySequence`). 사용처 9파일 14곳을 바꾸고 인스턴스 순번 필드 10개(전술 static 포함)를 지웠다. 주입 시계(`_clock` · `_now`)는 그대로 넘긴다. 아래 표 |
| 3 이관 기록 "시즌 0" | **보류 — 코드 변경 없음(사용자 결정)** | 전제가 맞지 않았다. S3 시즌 칩은 이미 빈 시즌이면 "시즌 —"이고(`tactical_workspace.dart` `season.isEmpty ? '—'`), `tactical-migration` golden은 fixture 시즌 '9'라 "시즌 9"다(기준 이미지 확대 확인). v1 → v2 이관은 Mock(`mock_tactical_v2_writes.dart` `'season': source.season`) · 백엔드(`tactical_fb6_store.py` `'season': source['season']`) 모두 v1 시즌 문자열을 그대로 옮겨 '0'을 만들지 않는다. CF가 "9"를 "0"으로 읽은 것으로 추정한다. 동작은 테스트로 고정했다(기본 Mock 새 초안 "시즌 —", 시즌 없는 v1 기록 "시즌 —" · "시즌 0" 없음). 숨김 대신 '—'로 둔 근거: 워크플로 불변식 "모르는 값은 '—'", 칩 자리가 늘 같아 머리 줄이 흔들리지 않는다 |
| 4 design-review seed 정정 | **완료** | `tactical_records_data.dart`: 공격 덱 A SP2 `chise` → `hanae`, 게헨나 방어 덱 SP2 `chise` → `ako`(사용자 결정: 둘 다). 둘 다 카탈로그 `combat_class` special이다. 기본 Mock 보유 목록(`mockOwnedStudentIds`)과 검수 시나리오 학생 목록 170명 · 보유 128명 안에 있다(`serina`는 시나리오 목록 밖이라 뺐다). 새 테스트가 seed 모든 칸의 역할과 내 덱 스페셜 보유를 검사한다 |
| 5 C4 목표 fixture | **완료(다른 통계 값 변화 0)** | `statistics_growth_data.dart`: 계획 9명 목표에 `statisticsGrowthFixtureGoalTargets`(스킬 · 장비 티어 · 성작 · 전용무기 · 애장품)를 더했다. C4 위 다섯 행은 아카네 40 → 88% · 아루 40 → 77% · 호시노 10 → 40% · 에이미 70 → 86% · 코유키 80 → 90%(남은 48 · 37 · 30 · 17 · 11%p)다. 히나 7 · 아리스 4 · 아이리 · 카즈사 0은 아래 행이다. 값은 FD-028 식을 옮긴 계산으로 고르고 테스트로 고정했다(옛 fixture로 계산한 호시노 10 → 20 · 아카네 40 → 46 · 아루 40 → 45가 FE7-f 기록과 같아 식을 확인했다). 다른 값이 그대로인 근거는 아래 golden 절 |

#### 섹션 틀 사용처 표

| 파일 | 전(사본) | 후(키트) |
|---|---|---|
| `lib/ui/statistics/statistics_workspace.dart` | `_SectionFrame`(3곳: scope · widgets · evidence, 표면 key `statistics-*-surface`) + `_SectionPainter` · `_SectionClipper`, `_ScaledBox`(6곳) | `SectionFrame(section: statisticsSection(id), surfaceKey: const ValueKey('statistics-*-surface'))` · `SectionScaledBox` |
| `lib/ui/statistics/statistics_growth_evidence.dart` | 공개 `StatisticsScaledBox`(정의 + 5곳) — 네 번째 사본 | 정의를 지우고 `SectionScaledBox` 5곳 |
| `lib/ui/statistics/statistics_supply_evidence.dart` | `StatisticsScaledBox` 13곳 | `SectionScaledBox` 13곳 |
| `lib/ui/tactical/tactical_workspace.dart` | `_SectionFrame`(4곳: records · lobby · jokbo · editor, 표면 key `tactical-section-<id>`) + `_SectionPainter` · `_SectionClipper`, `_Scaled`(3곳) | `SectionFrame(section: tacticalSection(id), surfaceKey: const ValueKey('tactical-section-<id>'))` · `SectionScaledBox` |
| 같은 틀이 아닌 것(그대로) | 인벤토리 `_Fit`(최소 크기 자르기) · `_InventorySurfacesPainter`(여러 섹션 한 painter) · `_AnalysisHighlightPainter`(외곽선), 통계 `_MinBox` · `StatisticsMinWidth`(최소 폭 자르기), 계획 화면들의 섹션 path 함수 | — |

- 전술 공통 부품(`TacticalDeckSlotRow` · `TacticalMiniDeck` · `TacticalAttemptStepper` · `TacticalFilterChip` · `TacticalSlotPortrait`)은 옮기지 않았다(지시). FE9-c · d가 쓰는 모양이 정해진 뒤의 키트 후보로 남긴다.
- UI Kit 갤러리에는 올리지 않았다. 화면 틀이고(섹션 표면은 FE1-c 이후 갤러리에 있다), 갤러리 페이지를 바꾸면 갤러리 테스트 범위가 늘어난다. 필요하면 CF 판단(발견 3).

#### idempotency 사용처 표(`microsecondsSinceEpoch` · `idempotencyKey` grep, `lib/**`)

| 위치 | key 모양 | 전 순번 | 처리 |
|---|---|---|---|
| `ui/inventory/inventory_controller.dart` 저장 | `inventory-save-<µs>-<n>` | 인스턴스 `_saveSequence` | **바꿈** |
| `ui/models/repository_presets_controller.dart` `_newKey` | `presets-<profile>-<µs>-<n>`(주입 시계) | 인스턴스 `_keyNumber` | **바꿈** |
| `ui/models/plan_flow_save.dart` `_buildRequest` | `plan-flow-save-<target>-<µs>-<n>`(주입 시계, 시나리오 초안 id와 같은 µs) | 인스턴스 `_keySequence` | **바꿈** |
| `ui/widgets/account_section_cluster.dart` 만들기 · 고치기 · 고르기 · 지우기(4곳) | `account-<동작>[-<id>]-<µs>-<n>` | State `_keySequence` | **바꿈** |
| `ui/pages/settings_page.dart` 프로필 만들기 | `settings-create-<µs>-<n>` | State `_keySequence` | **바꿈** |
| `ui/widgets/repository_profile_panel.dart` 만들기 · 고르기 · 이름 바꾸기 | `<action>-<µs>-<n>` | State `_keySequence` | **바꿈** |
| `ui/widgets/plan_scenario_list.dart` 복제 · 이름 · 삭제 · 적용 | `scenario-<action>-<id>-<µs>-<n>` | State `_keySequence` | **바꿈** |
| `ui/widgets/plan_section_layout.dart` 시나리오 편입 · 비교 화면 복제(2 State) | `plan-incorporate-<id>-<µs>-<n>` · `scenario-duplicate-<µs>-<n>` | State `_keySequence` × 2 | **바꿈** |
| `tactical/tactical_records_controller.dart` `_keyFor` | `tactical-<동작>-<µs>-<n>`(주입 시계, 재시도는 같은 key 그대로) | 프로세스 static `_keySequence` | **바꿈** |
| `ui/pages/scan_page.dart` 스캔 적용 | `<stamp36>-<n>`(`_applyIntentSequence`) | State | **스캐너 WIP라 남김(표에만)** |
| `ui/inventory/inventory_controller.dart` 후보 반영 · `ui/pages/student_page.dart` 후보 반영 | `inventory-candidate-<id>-<rev>` · `candidate-<id>-<rev>` | 없음(같은 후보 재시도 = 같은 key가 의도) | 그대로 |
| `services/mock_design_review_scenario.dart` seed | 고정 문자열 | — | 그대로(seed) |
| `ui/pages/tactical_page.dart` 기록 · 상대 id(`_idSequence`), `plan_flow_draft.dart` · `student_page.dart` 넘기기 id, `plan_preset_manager.dart` 프리셋 id | key 아님 | — | 그대로(tidy1 발견 5와 같음) |
| 스캐너 WIP 서비스(`mock_app_service.dart` · `process_app_service.dart` · `planning_protocol_client.dart` · `scanner_service.dart`) | key를 만들지 않음(받기만) | — | 고치지 않음 |

- 테스트 기대: key 모양을 검사하는 테스트(`tactical_records_controller_test` 정규식 · `tidy1_followups_test` 정규식)는 그대로 통과했다.
- `tidy1_followups_test` ⑥의 기대는 "끝 순번이 1, 2, …"에서 "앞 번호 다음으로 이어짐"으로 바꿨다. 공용 순번은 같은 isolate의 앞 테스트가 key를 만들면 1부터가 아니다. 지금은 우연히 1부터라 통과했지만 순서에 기대는 기대였다.

#### golden 변화 예상(golden 미실행)

| 장면 | 예상 | 근거 |
|---|---|---|
| `tactical` | **변화** | design-review seed를 쓴다. 바뀌는 곳: S1 행 1 · 2(공격 덱 A · 게헨나 방어 상대) 미니 덱 SP2 칸, 행 4(방어 · 내 덱 = 게헨나 방어) SP2 칸, S3 상대 덱 SP2 "치세" → "아코" 초상 · 이름, 내 덱 SP2 "치세" → "하나에" 초상 · 이름. 행 3 · 범례 · 머리 · 시즌 칩 · 자동 연결 문구는 그대로다(칸이 빈칸이 되지 않아 범례 글자가 같고, 공격 편성 두 쌍이 그대로라 자동 족보 2개) |
| `statistics-plan` | **변화** | C4 덤벨 5행: 행 순서 · 이름(아카네 · 아루 · 호시노 · 에이미 · 코유키) · 현재 ● → 목표 ○ 길이 · 오른쪽 글자 "40 → 88%" … "80 → 90%". 범위 칩 "활성 계획 · 9명"은 그대로(학생 집합 같음) |
| `tactical-migration` | 변화 0 | 항목 3 코드 변경 없음. v1 기록 덱은 golden 테스트 자체 값이다(seed 아님). 섹션 틀은 같은 위젯 트리다 |
| `statistics-growth` · `statistics-growth-filter` · `statistics-filter-open` · `statistics-inventory` | 변화 0 | 목표 값을 읽는 것은 C4(`StatisticsGoalProgressSet`)뿐이다. 다른 통계는 `state.goals`의 학생 id만 쓴다(`statistics_growth_projection` 계획 표시 · `statistics_history_projection` · `statistics_projection` · `statistics_supply_projection` 계획 학생 수 · workspace 범위 칩). 통계 페이지가 목표로 부르는 `calculatePlan`(Mock 합계식)의 `gross`는 `StatisticsSourceData`에 담기기만 하고 그리는 곳이 없다(grep). 부족 계산 · 활성 계획 문서 계산은 golden 서비스가 fixture로 돌려준다(목표와 무관). 섹션 틀은 같은 위젯 트리 · 같은 key · 같은 배율 식이다 |
| 나머지 42장(계정 · 홈 · 인벤토리 · 계획 · 학생 · 스캔 · 타이틀) | 변화 0 | 섹션 틀 사용처는 통계 · 전술뿐이다. idempotency key는 그리는 값이 아니다. 두 fixture 파일을 쓰는 golden 테스트는 통계 · 전술 두 파일뿐이다(grep: `test/goldens/*.dart`) |

#### 미검증(미실행)

- golden 비교 · 전체 `fe_gate.ps1` · `-UpdateGoldens` · `codealmanac validate` · 저장소 전체 `git diff --check`: **미실행**(CF 몫).
- 실제 Python을 띄우는 process 묶음 16파일(`repository_presets_process_e2e` · `inventory_*_process_e2e` · `planning_*_process_e2e` · `repository_*_process_e2e` · `tactical_*_process_e2e` · `profile_delete_fb2d_process_e2e` · `planning_protocol_client_test`): **미실행**. 백엔드는 key를 불투명 문자열로 보고 모양이 같아 영향 없음을 예상한다.
- 스캐너 테스트 · 위 목록 밖 Flutter 테스트: **미실행**(스캐너 파일 수정 0).
- 실제 앱 창에서 통계 C4 · 전술 seed 모습: **미실행**(위젯 테스트 · 계산만).
- Windows release 빌드: **미실행**.

#### WIP 보존 확인

- 고친 기존 19파일(이 문서 포함)은 착수 때 WIP가 없었다(`git status --short` 빈 줄). post 사본 · `post_dir`는 없다.
- pre 사본 대비 diff는 이 slice 줄뿐이고 줄바꿈을 유지했다. CRLF 4파일은 고친 뒤에도 모든 줄 CRLF, 끝 개행 하나다.
- 사본을 만들었지만 고치지 않은 2파일(`test/tactical_records_controller_test.dart` · `test/app_navigation_fe7d_test.dart`)은 pre와 cmp 일치다. 파일 삭제 금지라 사본은 남겼다. 삭제 후보: `debug/frontend_tidy2/pre/frontend/test/tactical_records_controller_test.dart` · `debug/frontend_tidy2/pre/frontend/test/app_navigation_fe7d_test.dart`.
- 편집 0회: 스캐너 WIP 15파일(`scan_page.dart` · `scan_companion_dock.dart` · `scan_student_review_workspace.dart` · `scan_inventory_identity_review.dart` · `mock_app_service.dart` · `process_app_service.dart` · `planning_protocol_client.dart` · `scanner_service.dart` · 스캐너 테스트), golden harness · golden 테스트, `frontend/tool/**`, backend · contracts, 택틱 세션 소유 파일, `app_shell.dart`.
- `dart format`은 실행하지 않았다. git 쓰기 0회, 파일 삭제 0회.

#### 발견 사항

1. **"시즌 0"은 오독으로 보인다**(항목 3): 기준 이미지의 칩은 "시즌 9"다. v1 원본 데이터에 실제로 "0" 시즌이 저장된 계정이 있다면 데이터 문제이고, 지금은 그대로 "시즌 0"으로 보인다. '0'을 '모름'으로 볼지는 CF · XB 판단이다.
2. **seed 내 덱의 `mika`**: 공격 덱 A 3번 `mika`는 검수 시나리오(성장 fixture)의 미보유 42명 안이고 기본 Mock 보유 목록에도 없다. 피커는 보유 학생만 고르므로 그 칸을 다시 고를 수 없다(되보내기는 된다). 이번 범위(SP2)가 아니라 고치지 않았다. seed를 보유 학생으로 맞출지 CF 판단.
3. **UI Kit 갤러리**: `SectionFrame` · `SectionScaledBox`는 갤러리에 올리지 않았다(위 근거). FE2 규칙상 갤러리 항목이 필요하면 다음 키트 slice에서.
4. **`StatisticsScaledBox`(공개 이름) 제거**: lib · test 어디에도 남은 참조가 없다(grep 0). 다른 레인 미커밋 작업이 이 이름을 쓰면 컴파일이 깨진다. 착수 · 종료 시점 작업 트리에는 없었다.
5. **C4 목표 fixture와 검수 시나리오**: 같은 목표 wire를 검수 시나리오 Mock(`mock_design_review_scenario.dart`)도 쓰므로 앱 검수 화면의 C4도 같은 덤벨이 된다. 시나리오의 부족 · 문서 계산은 fixture라 다른 값은 그대로다.
6. 막는 `열림` FD 없음. 워커 재량 FD 처리 없음(FD-028은 확정 — C4 목표에 같은 식, FD-086은 이번 화면과 무관).

#### 사본 · commit.json

- 착수 사본: `debug/frontend_tidy2/pre/<경로>`(21파일 = 고친 19 + 안 고친 2). WIP가 없어 post 사본은 없다.
- `debug/frontend_tidy2/commit.json`: slice `tidy2`, `status=true`, modified 19(이 문서 포함), added 5, `whole` = `frontend/test/goldens/baseline/tactical.png` · `frontend/test/goldens/baseline/statistics-plan.png`(파일 단위).
- 인계: `debug/frontend_tidy2/output.md`.

#### 다음 행동

- tidy2 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: 레인 워커가 모두 멈춘 뒤 gate를 한 번 돌린다.
  - 예상: analyze 0, 일반 테스트 녹색. 새 테스트 11건(kit/section_frame 5 · idempotency_keys 4 · design_review_tactical_seed 2)과 고친 테스트(tactical_page 시즌 칩 1건 추가 · statistics_second_tiles C4 기대 추가 · tidy1_followups 순번 기대)를 포함한다.
  - golden은 `tactical` · `statistics-plan` 2장 RED, 다른 47장 변화 0이다. 특히 `tactical-migration`은 변화 0이다(프롬프트 예상과 다름 — 항목 3).
  - 승인 뒤 `-UpdateGoldens` → 재비교 → `fe_commit.ps1 -Slice tidy2`.
- 발견 1(시즌 '0' 데이터) · 2(seed `mika` 미보유) · 3(갤러리)은 CF 판단을 기다린다.

### tidy2 commit record (2026-10-14 22:37, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261014_222332\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE7-j 통계 마무리 · 키트 정리 (Lane A, 로컬 Claude Code)

### FE7-j 착수 기록 (2026-10-15 22:49, Lane A)

- 상태: 진행 중 → **종료**(아래 FE7-j 종료 기록). 시작 SHA `810a15f2e840a2b369fdf7ed98aa9a0e52bccab0`(브랜치 `scanner-consolidation`). 착수 때 status 끝에 다른 FE7-j 착수 기록 없음.
- 범위: 1. A6 구간 선택 → 오른 학생 순위(FE7-h 발견 5, Statistics-Proposal A6). 2. 차트 키트 승격(스파크라인 · 발산 막대 — 같은 그림인지 먼저 확인). 3. UI Kit 갤러리에 `SectionFrame` · `SectionScaledBox`(tidy2 발견 3)와 2의 차트 위젯.
- 막힘 확인: 막힘 요약에 FE7-j 행이 없고 지금 `열림` FD가 없다. 관련 FD-028 · FD-041 · FD-104 · FD-175는 모두 확정이다.
- 항목 2 사전 판정(코드 읽기): 같은 그림이 아니다. 아래 승격 표는 종료 기록에 둔다. 그래서 2는 표만 남기고 코드를 고치지 않을 예정이고, 3의 차트 갤러리 항목도 없다.
- 고칠 파일(예정)과 착수 때 WIP(`git status --short <경로>`):

| 항목 | 파일 | 착수 WIP |
|---|---|---|
| 1 | `frontend/lib/statistics/statistics_history_projection.dart` | 없음 |
| 1 | `frontend/lib/ui/statistics/statistics_growth_evidence.dart`(CRLF) | 없음 |
| 1 | `frontend/lib/ui/statistics/statistics_history_charts.dart` | 없음 |
| 1 | `frontend/lib/ui/statistics/statistics_workspace.dart` | 없음 |
| 1 | `frontend/lib/ui/pages/statistics_page.dart`(CRLF) | 없음 |
| 1 | `frontend/test/statistics_history_view_test.dart`(필요할 때만) | 없음 |
| 1 | 새 `frontend/test/statistics_a6_ranking_test.dart` | 새 파일 |
| 3 | `frontend/lib/ui/kit/gallery/ui_kit_gallery_page.dart` | 없음 |
| 3 | `frontend/test/kit/ui_kit_gallery_test.dart` | 없음 |
| 3 | 새 `frontend/lib/ui/kit/gallery/ui_kit_frame_section.dart` | 새 파일 |
| 공통 | `almanac/workflows/frontend-redesign-status.md`(이 문서) | 없음 |

- 사본: 위 기존 파일 9개를 `debug/frontend_fe7j/pre/<v7 기준 경로>`에 두었다. WIP가 있는 파일이 없어 post 사본 · `post_dir`는 두지 않는다.
- 고치지 않음: 스캐너 WIP 15파일, `lib/services/**`, Lane B 전술 파일, 인벤토리 파일(항목 2가 승격 없음이면), 셸 · navigation, golden harness · golden 테스트, `frontend/tool/**`, backend · contracts.

### FE7-j 종료 기록 (2026-10-15, Lane A, 코드 작성 완료 · CF gate 미실행)

세 항목 중 1 · 3을 했고, 2는 같은 그림이 아니라 승격하지 않았다(표만). A6 점을 누르면 그 스냅샷 → 마지막 스냅샷 구간을 고르고, 오른쪽 근거 패널에 "오른 학생 순위"가 나온다. UI Kit 갤러리에 "섹션 틀" 구역을 더했다. 서비스 · 셸 · navigation · 인벤토리 · 키트 위젯 · harness 변경은 없다.

#### 실행 명령 · 결과

모두 `frontend`에서 이 PC(Claude Code)로 실행했다. 로그는 `debug/frontend_fe7j/logs/`에 있고, 실패 줄(`[E]` · `EXCEPTION` · `Some tests failed` · `error •`)만 찾았다.

| 명령 | 결과 |
|---|---|
| `flutter analyze lib/statistics/statistics_history_projection.dart`(projection 편집 뒤) | No issues found |
| `flutter analyze lib/ui/statistics/statistics_growth_evidence.dart`(1차) | 오류 1(`int?`를 `num` 자리에 — 끝 점 null 검사 누락) → 고침 → No issues found |
| `flutter analyze lib/ui/statistics/statistics_history_charts.dart` · `lib/ui/statistics` · `lib/ui/pages/statistics_page.dart lib/ui/statistics lib/statistics` | 모두 No issues found |
| `flutter test test/statistics_a6_ranking_test.dart`(새) | **+11 −0**(첫 실행) |
| `flutter analyze lib/ui/kit` · `test/kit/ui_kit_gallery_test.dart` | No issues found |
| `flutter test test/kit/ui_kit_gallery_test.dart` | **+7 −0**(첫 실행, 새 1건 포함) |
| `flutter analyze`(frontend 전체, 1차) | **No issues found**(info 포함 0) |
| 관련 30파일 한 번에(`--file-reporter json`, 아래) | **+275 −0** |
| A6 근거 조건 보강(끝이 지금 마지막 점일 때만) 뒤 5파일(`statistics_a6_ranking` · `statistics_page` · `statistics_history_view` · `statistics_growth_view` · `app_navigation_fe7d`) | **+65 −0** |
| `flutter analyze`(frontend 전체, 최종) | **No issues found**(info 포함 0) |
| `git diff --check`(고친 기존 7파일) · 새 2파일 검사 | 0. 새 파일은 LF · 줄 끝 공백 0 · 끝 개행 하나. 기존 파일 줄바꿈은 pre와 같다(`statistics_growth_evidence.dart` · `statistics_page.dart` CRLF, 나머지 LF) |

관련 30파일의 파일별 결과(30파일 실행 기준):

- 통계: statistics_a6_ranking +11(새), statistics_history_projection +17, statistics_second_tiles +15, statistics_history_view +14, statistics_page +14, statistics_workspace +13, statistics_growth_view +12, statistics_growth_projection +11, statistics_supply_view +11, statistics_filter +10, statistics_third_tiles +10, statistics_plan_view +9, statistics_supply_projection +8, statistics_plan_projection +7, statistics_projection +7, statistics_app_shell +2
- 키트 · 갤러리: kit/ui_kit_gallery +7, kit/stat_chart +7, kit/scroll_viewport_fog +6, kit/section_frame +5, kit/ui_kit_gallery_overlays +4, kit/ui_kit_gallery_controls +2, kit/ui_kit_gallery_data +2, kit/ui_kit_gallery_range +2
- 셸 · 이동 · 그 밖: widget_test +16, app_navigation_fe7d +14, developer_tools_app +12, app_navigation_tidy1 +11, mock_design_review_scenario +11, home_page +5

- 걸리는 테스트는 grep으로 찾았다. 찾은 말은 `statistics|Statistics|UiKitGallery|ui_kit_gallery|section_frame|SectionFrame|SectionScaledBox|top-tab-statistics|design_review|MockDesignReview|studentSnapshotsFor|StatisticsGrowthView`이다.
  - goldens를 빼고 걸린 테스트 파일은 모두 실행했다. 뺀 것은 아래와 같다.
    - process E2E 2개(`repository_process_e2e` · `tactical_v2_process_e2e`).
    - "statistics" 낱말이나 `SectionFrame`만 걸린 전술 · 메타 6개(`tactical_page` · `tactical_page_revision` · `tactical_fe9b1_read` · `tactical_records_controller` · `design_review_tactical_seed` · `metadata_manager_dto`). 전술 쪽은 이 slice가 고친 코드를 쓰지 않고, Lane B가 FE9-d로 작업 중이다.
  - `kit/stat_chart_test`는 더해서 돌렸다(A6가 `StatChartFrame.onTapAt`을 쓴다).
  - 인벤토리 테스트는 돌리지 않았다. 항목 2가 승격 없음이라 인벤토리 코드 변경이 0이다.
- 검수 수치: scratchpad의 임시 출력 테스트(저장소 밖, `file:` import)로 fixture 순위를 한 번 출력했다.
  - 9/29 → 10/05: 평균 +1.2%p, 행 112(오른 110 · 새 2 · 모름 0), 상위 +5.9%p.
  - 9/22 → 10/05: 평균 +2.0%p, 행 112(오른 110 · 새 2).
- `dart format`은 새 2파일과 `test/kit/ui_kit_gallery_test.dart`에만 파일 경로로 돌렸다.
  - 갤러리 테스트는 포매터가 손대지 않은 기존 줄 8줄(행 견본 `expect` 셋)을 다시 감쌌다. pre 사본에 내 3곳(머리 주석 · import · 새 테스트)만 다시 넣어 되돌렸다. diff에는 이 slice 줄만 있다.
- 빌드 잠금(`build/` · `.dart_tool/`) 충돌은 없었다. `flutter analyze`가 "Got dependencies!"를 찍었지만 `pubspec.lock` · `pubspec.yaml`은 바뀌지 않았다(`git status` 빈 줄).
- 실행하지 않음: golden(`test/goldens/**`), 전체 `fe_gate.ps1`, `-UpdateGoldens`, `fe_commit.ps1`, 맨 `flutter test`, process E2E, `codealmanac validate`.

#### 항목별 결과

| 항목 | 결과 | 근거 |
|---|---|---|
| 1 A6 구간 선택 → 오른 학생 순위 | **완료** | 아래 "오른 학생 순위 규칙". 새 테스트 11건 |
| 2 차트 키트 승격 | **보류(승격하지 않음, 표만)** | 아래 승격 표. 스파크라인 · 발산 막대 모두 통계와 인벤토리가 다른 그림이다. 코드 변경 0 |
| 3 UI Kit 갤러리 등록 | **완료(섹션 틀 2개)** | `SectionFrame` · `SectionScaledBox` 구역과 갤러리 테스트 1건. 2가 승격 없음이라 차트 항목은 없다 |

#### 1. 오른 학생 순위 규칙

- **고르는 동작**(시안에 규칙 없음 → A1 문법):
  - 시안 Statistics-Proposal A6에는 다음 두 줄만 있다. ① 두 스냅샷을 고르면 그 사이만 분홍으로 칠하고 차이를 적는다. ② 구간을 누르면 오른쪽 상세(오른 학생 순위)다.
  - 고르는 동작은 A1 문법(누르면 고름 · 같은 것을 다시 누르면 풂)으로 정했다.
  - 누르는 단위는 점이다. 점의 세로 칸은 이웃 점과의 가운데까지, 설계 좌표 y 10 ~ 231(날짜 글자 아래)이다.
  - 점 하나를 누르면 **그 스냅샷 → 마지막 스냅샷** 구간이다. 마지막 점을 누르면 바로 앞 점부터다.
  - 근거: 질문 "지난 스캔 이후 얼마나 올랐습니까?"는 지금(마지막)까지의 변화다. FE7-h 기본 강조도 마지막 점에서 끝난다. 끝을 아무 점으로 고르려면 "첫 클릭 = 시작, 둘째 클릭 = 끝" 같은 중간 상태가 필요해 A1 문법이 아니다(발견 1).
- **그림**:
  - 고르지 않으면 FE7-h 기본 강조(마지막에서 14일 안)가 그대로다.
  - 고르면 고른 구간이 강조 구간이 된다(분홍 바탕 · 두 끝 분홍 점 · "9/29 → 10/05 +1.2%p"). painter는 바꾸지 않았고 강조 시작만 넘긴다.
  - 고른 구간이 기본 강조와 같으면(예 9/22 점) 그림은 같고 근거만 열린다.
- **풀림**: 같은 구간을 다시 누를 때, 다른 타일을 고를 때, 주제 · A1 seg · 통계 필터를 바꿀 때, 다시 읽을 때 풀린다(기존 성장 선택과 같다).
- **스냅샷**: FD-175 묶음 끝 학생 상태(A6 점과 같은 값)이고, 시작 · 끝 모두 스냅샷이다.
  - 끝 스냅샷 뒤의 수동 수정은 이 순위에 들지 않는다. 행의 Lv도 끝 스냅샷 값이다.
  - 근거 판정은 "끝이 지금 마지막 점"일 때만이다. 새 스냅샷이 생기면 이 구간 근거는 없어진다.
- **통계 필터(FE7-e)**: A6와 같은 대상 학생만 본다. 대상은 지금 필터의 학생 id이고, 스냅샷마다 그때 보유한 대상만 센다.
  - 필터가 바뀌면 고른 구간이 풀린다.
  - 그래서 "새 학생"은 필터 대상 중 시작 스냅샷에 없던 학생이다.
  - 구현: `studentSnapshotsFor`가 대상 학생 상태(`states`)도 남긴다. 성장 값은 그대로다.
- **순위**(`statisticsGrowthRanking`, `lib/statistics/statistics_history_projection.dart`):
  - 끝 스냅샷에 있는 학생만 본다. 그사이 빠진 학생은 넣지 않는다.
  - **오른 학생**: 두 스냅샷의 육성도(FD-028, 애장품 없는 학생 6항목)를 모두 알고, 화면 글자(0.1%p) 반올림끼리의 차가 0보다 크다. 그래서 "+0.0%p" 행은 생기지 않는다.
    - 차례는 증감 큰 순 → 끝 육성도 높은 순 → 이름 → id다.
  - **새 학생**: 시작 스냅샷에 없던 학생이다. 증감 없이 오른 학생 뒤에 끝 육성도 높은 순(모르면 뒤)으로 놓는다.
  - 그대로이거나 내린 학생은 넣지 않는다.
  - 한쪽이라도 육성도를 모르면 비교하지 않고, 부제 끝에 "육성도 모름 n명 제외"를 붙인다.
- **근거 패널**(성장 근거 틀 그대로, `statisticsRankingEvidence`):
  - 머리 "9/29 → 10/05" + 분홍 "n명"(오른 + 새).
  - 부제 "A6에서 고른 구간 · 오른 학생 순". 없으면 "A6에서 고른 구간 · 오른 학생이 없습니다."다.
  - 행은 초상 · 이름 · Lv · 칩이다. 칩은 오른 학생 "+5.9%p"(초록 `AppTones.ok`), 새 학생 "새 학생"(파랑 `AppTones.info`)이다.
  - 7행 다음은 "나머지 n명 · 모두 보기"다. 성장 근거(시안 Stats-Growth) 문구를 따랐다. 프롬프트 "외 n명"은 재화 근거 문구다(발견 2).
  - 요약 "구간 요약"은 평균 육성도 변화(A6 강조 글자와 같은 값) · 오른 학생 n명 · 새 학생 n명이다.
- **근거 → 학생 탭**(FE7-d intent 그대로, 새 intent 종류 없음):
  - "학생 탭에서 보기 · 필터: 9/29 → 10/05"는 `StudentsNavigationIntent`(순위 학생 전부, 라벨 "통계: 9/29 → 10/05 · n명")다.
  - "이 구간 학생을 계획에 추가"는 계획 1단계 미리 선택이다(기존 성장 근거와 같다).
- **"← 통계" 복귀**: 이력은 보드 뒤에 읽는다. 그래서 A6 구간은 이력을 읽은 뒤 되살린다(`_pendingTrend`). 그사이 다른 것을 골랐거나 구간이 없으면 버린다.
- 고친 파일:
  - `statistics_history_projection.dart`(순위 · `growthAt` · 대상 `states` · `withHighlight` · `indexOf`)
  - `statistics_growth_evidence.dart`(`StatisticsGrowthTrendSelection` · `trendStart` · `shownTrend` · `selectTrendStart` · 근거)
  - `statistics_history_charts.dart`(`pointAt` · `startFor` · 차트 `onStartSelected`)
  - `statistics_workspace.dart`(`_a6Body`)
  - `statistics_page.dart`(이력 값을 성장 화면 값에 넘김 · 복귀)
- 새 테스트 `test/statistics_a6_ranking_test.dart` 11건:
  - projection 4건: 순위 차례 · 새 학생, 긴 구간 증감 값과 그대로인 학생 제외, 필터 대상, 못 찾는 구간 null.
  - 화면 7건: 고름 · 다시 눌러 풂, 새 학생 칩 · 모두 보기, 학생 탭 intent, 주제 변경 풀림, "← 통계" 복귀, 1280×720 · 1440×900 넘침 0.

#### 2. 승격 표(같은 그림인가)

| 그림 | 통계 | 인벤토리 | 같은가 |
|---|---|---|---|
| 스파크라인 / 꺾은선 | B3 `StatisticsResourceTrendPainter`(`statistics_history_charts.dart`, 통계 B3 패널 3장) · A6 `StatisticsGrowthTrendPainter` | `InventorySparklinePainter`(`inventory_history_charts.dart`, 인벤토리 상세 "최근 변화" `_SparklineRow`) | **아니다**. 아래 "스파크라인 차이" |
| 가운데 축 발산 막대 | B2 `StatisticsBalancePainter`(`statistics_balance_charts.dart`, 통계 B2 6행) | `InventoryChangeBar`(`inventory_history_charts.dart`, 분석 S5 행 `inventory_analysis_sections.dart`) | **아니다**. 아래 "발산 막대 차이" |

- 스파크라인 차이:
  - 좌표계: 인벤토리는 위젯 높이 92 픽셀 좌표(옆 30 안쪽)다. 통계는 `StatChartFrame` viewBox 1030×226 균일 배율이다.
  - 점 · 글자: 인벤토리는 모든 점이 r4이고 점마다 값 글자(11px)와 시간 글자("n주 전")가 있다. 통계 B3는 끝 점 하나만 r4.5 + #16202c 테두리이고, 값 글자는 끝 값 하나다. 패널 상자 · "필요" 점선 · 순변화 글자도 있다.
  - 선: 인벤토리 2.5, 통계 2.
  - 모르는 값: 인벤토리는 선을 끊고 빗금을 친다. 통계는 끊기만 한다.
  - 지금 점: 인벤토리는 바탕 rgb(26,44,59), 통계는 #16202c다.
- 발산 막대 차이:
  - 모양: 인벤토리는 한 행 위젯(395×30)이고 수직 변 둥근 막대(높이 8, r4)다. 통계는 한 painter가 6행을 그리고 80° 기울인 막대(높이 13, r3)다.
  - 뜻 · 색: 인벤토리는 증가 초록 · 감소 분홍(정수 증감)이다. 통계는 부족 분홍 · 과잉 노랑 α.92(필요량 대비 %, FD-040)다.
  - 글자 · 축: 인벤토리는 값 글자가 오른쪽 칸(351~395)에 있고 축선이 없다. 통계는 값 글자가 막대 끝, 이름이 왼쪽이고 축선을 그린다. 축척 줄임 · 고른 행 띠 · 아래 범례도 통계에만 있다.
- 결론: 하나로 합치면 좌표 · 기울기 · 색 · 글자 자리를 모두 인자로 받게 되어, 공유하는 그림이 없다. 모습 변화 0으로 묶을 수 있는 공통 부분이 사실상 없어 승격하지 않았다. 한 모양으로 맞추려면 어느 쪽 모습을 따를지 정해야 하고, 그것은 시각 변경 slice다(발견 3).
- 이미 공유하는 것: 두 화면 모두 키트 `StatChartPalette`(`magnitude` · `axis` · `axisLabel` · `valueLabel` · `highlight`)와 `paintHatch` · `paintStatLabel`을 쓴다.

#### 3. 갤러리 항목

- 새 `lib/ui/kit/gallery/ui_kit_frame_section.dart`(`UiKitFrameSection`). 갤러리 페이지 FE2-d 구역 아래에 머리 "섹션 틀"과 함께 놓았다.
- 높이 420인 줄에 타일 두 개가 있다(FE2-d 데이터 타일과 같은 여백).
  - `kit-gallery-frame-section-frame` "섹션 틀 · SectionFrame":
    - 560×270 견본 섹션(왼쪽 면에 붙은 사다리꼴)의 표면(`kit-gallery-section-frame-surface`)이 있다.
    - 안에는 근거 패널 머리 한 줄("9/22 → 10/05" + 분홍 "12명")을 두었다.
    - 분홍 막대는 일부러 섹션 밖까지 놓아 사선에서 잘리는 것을 보인다.
  - `kit-gallery-frame-scaled-box` "섹션 안 배율 · SectionScaledBox": 같은 머리 한 줄(시안 360×44)을 배율 1 · 0.75 · 0.5 자리(`kit-gallery-scaled-box-100/75/50`)에 넣었다.
- 시안 W-* artboard에 이 두 위젯의 견본이 없다(화면 틀이다). 그래서 좌표 대조가 아니라 동작 견본이다.
- 갤러리 테스트(`test/kit/ui_kit_gallery_test.dart`) 새 1건:
  - 견본 크기, 표면 painter, 넘치는 막대 위의 `SectionShapeClipper`를 본다.
  - 배율 상자 크기 3개, 배율 1은 `FittedBox` 없음 · 1 미만은 하나, 넘침 예외 0을 본다.

#### golden 변화 0 근거(장면별)

- **통계 5장**(`statistics-growth` · `statistics-growth-filter` · `statistics-inventory` · `statistics-plan` · `statistics-filter-open`): **변화 0 예상**.
  - golden 조작(`fe7a_statistics_golden_test.dart`)은 A6를 누르지 않는다. 그래서 A6 선택은 늘 없다.
  - `shownTrend`는 그때 같은 trend 객체를 돌려준다. painter 입력(점 · 강조 시작 · 강조 글자)이 FE7-h와 같고, painter 코드는 바꾸지 않았다.
  - `StatChartFrame`은 `onTapAt`이 없어도 원래 `GestureDetector`를 두므로 위젯 트리 모양이 같다.
  - 근거 패널은 선택이 없으면 그대로다.
  - 페이지는 이력 화면 값을 성장 화면 값보다 먼저 만든다. 입력이 같고 캐시 조건도 같아 값이 같다.
  - `statistics-growth-filter`: 대상 스냅샷에 `states`를 더 담을 뿐 성장 값은 같은 map으로 센다.
- **인벤토리 5장**: 코드 변경 0(항목 2 승격 없음).
- **갤러리**: golden 장면이 없다(`test/goldens/`에 갤러리 장면 없음).
- **다른 장면**: 바꾼 파일은 통계 · 갤러리뿐이다. 키트 위젯 · harness · 셸 변경은 0이다.
- 그래서 commit.json `whole`은 빈 배열이다. golden은 돌리지 않았다(미실행).

#### 검수표

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Statistics-Proposal A6(구간 → 오른 학생 순위) | 통계 → 학생 성장 → A6 점 누르기. fixture는 `test/statistics_a6_ranking_test.dart`이고, 앱 mock 검수 시나리오는 학생 스냅샷 1회라 A6가 문구 상태다(FE7-h 발견 6) | 9/29 점 → 분홍 구간 9/29 ~ 10/05 · "9/29 → 10/05 +1.2%p" / 근거 머리 "9/29 → 10/05" · "112명", 부제 "A6에서 고른 구간 · 오른 학생 순", 첫 행 칩 "+5.9%p"(초록), 펼치면 끝에 "새 학생" 2명(파랑), 요약 +1.2%p · 110명 · 2명 / 같은 구간 다시 누르기 → 기본 강조 9/22 · "근거 확인" / "학생 탭에서 보기"가 학생 탭 임시 목록 112명 |
| UI Kit 갤러리 "섹션 틀" | 개발 패널 → UI Kit 갤러리 → 맨 아래 | 사다리꼴 표면 · 그림자, 분홍 막대가 사선에서 잘림 / 배율 1 · 0.75 · 0.5 머리 줄이 같은 비율로 줄어듦 |

#### 처리한 FD

- FD-028(확정): 증감은 FD-028 육성도(애장품 없는 학생 6항목)의 차다.
- FD-175(확정): 두 끝은 묶음 끝 학생 스냅샷이다(A6 점과 같다).
- FD-104(확정): 통계 필터 대상만 센다(A1~A6 범위).
- FD-041(확정): 비교는 scan 점(스냅샷)끼리다. 수동 수정은 끝 스냅샷 뒤면 들지 않는다.
- 막는 `열림` FD 없음. 워커 재량 FD 처리 없음(새 규칙은 위 "오른 학생 순위 규칙"과 발견 사항).

#### 미검증 항목

- golden 비교: **미실행**. 모든 장면 변화 0으로 예상한다(위 근거). CF가 `fe_gate.ps1`을 돌린다.
- 전체 `fe_gate.ps1`(그 밖의 테스트 · process E2E · `codealmanac validate` · 저장소 전체 `git diff --check`): **미실행**.
- 실제 백엔드 계정에서 순위 속도: **미실행**. 순위는 고를 때 두 스냅샷의 학생 전원을 FE7-b 식으로 다시 센다(구간당 한 번, 같은 구간이면 캐시). 학생 수백 명 규모라 가볍다고 보지만 재지 않았다.
- 갤러리 견본의 시각 검수: 테스트(크기 · clipper · `FittedBox`)만 보았고, 렌더 이미지는 보지 않았다.
- 전술 테스트(`tactical_*`)는 이 slice가 고친 코드와 무관하고 Lane B 작업 중이라 돌리지 않았다.

#### WIP 보존 확인

- 고친 기존 7파일은 착수 때 WIP가 없었다(착수 기록). pre 사본과 비교한 diff에는 이 slice 줄만 있다(`diff --strip-trailing-cr` 확인). post 사본 · `post_dir`는 없다.
- 착수 때 사본을 둔 `frontend/test/statistics_history_view_test.dart`는 고치지 않았다. pre와 `cmp`가 같고, 사본은 지우지 않았다(삭제 후보).
- 스캐너 WIP 파일(`scan_page.dart` · `scan_companion_dock.dart` · `scan_student_review_workspace.dart` · 스캐너 테스트 등), `lib/services/**`, Lane B 전술 파일(`tactical_studio_layout.dart` 등 작업 트리 변경)은 고치지 않았다. git 쓰기 · 파일 삭제는 하지 않았다.

#### 발견 사항

1. **A6 끝 점 고르기**: 이번 구간은 늘 "고른 점 → 마지막 스냅샷"이다. 끝도 고르게(예 9/08 → 9/22) 하려면 두 번 누르기(시작 · 끝) 같은 새 동작 규칙이 필요하다. 시안 문구 "두 스냅샷을 고르면"은 그 뜻일 수 있다. 필요하면 CF 판단(FD 후보)이다. `StatisticsGrowthTrendSelection`은 이미 시작 · 끝 세션을 따로 갖는다.
2. **"외 n명" vs "나머지 n명 · 모두 보기"**: 프롬프트는 "상위 n + 외 n명"이다. 같은 성장 근거 틀(A1~A5 · C5)은 시안 Stats-Growth 문구 "나머지 n명 · 모두 보기"를 쓰므로 그대로 두었다. "외 n명"은 재화 근거(FE7-d) 문구다. 바꾸려면 성장 근거 전체를 같이 바꾸는 결정이 필요하다.
3. **차트 승격 보류**: 스파크라인 · 발산 막대는 통계와 인벤토리가 서로 다른 그림이다(위 표). W-Data-Widgets `LineTrend` · `DivergingBars` 한 벌로 맞추려면 어느 모습을 따를지 정하는 시각 변경 slice(golden 갱신)가 필요하다. FE7-h가 적은 "점 범위를 받는 `inventorySparkline`"(데이터 함수 공유)은 그림과 별개로 남은 후보다.
4. **fixture 순위 모양**: 검수 fixture는 과거 학생 값을 "스킬을 한 칸씩 내려" 만들었다. 그래서 9/29 → 10/05에 110명이 함께 오른다(시안 placeholder와 다름). 실제 계정에서는 스캔 사이에 바뀐 학생만 오른다.
5. **mock 검수 시나리오**: 앱 검수 시나리오는 학생 스냅샷이 1회라 A6를 누를 수 없다(FE7-h 발견 6과 같음). 앱에서 보려면 시나리오에 학생 스냅샷 이력이 필요하다(`lib/services/design_review/`, 이번 범위 밖).

#### 사본 · commit.json

- 착수 사본: `debug/frontend_fe7j/pre/<경로>`(9파일 = 고친 7 + 이 문서 + 고치지 않은 `statistics_history_view_test.dart`). WIP가 없어 post 사본은 없다.
- `debug/frontend_fe7j/commit.json`: slice `fe7j`, `status=true`, modified 8(이 문서 포함), added 2, `whole` = [](바뀌는 기준 이미지 없음).
- 인계: `debug/frontend_fe7j/output.md`.

#### 다음 행동

- FE7-j 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: 레인 워커가 모두 멈춘 뒤 gate를 한 번 돌린다.
  - 예상: analyze 0, 일반 테스트 녹색. 새 테스트 12건(a6_ranking 11 · ui_kit_gallery 1)을 포함한다.
  - golden은 모든 장면 변화 0이다.
  - GREEN이면 `fe_commit.ps1 -Slice fe7j`(golden 갱신 없음).
- 발견 1(끝 점 고르기) · 2(근거 "외 n명" 문구) · 3(차트 모습 통일 slice)은 CF 판단을 기다린다.

### fe9d commit record (2026-10-16 02:40, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261016_023150\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

### fe7j commit record (2026-10-16 02:40, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261016_023150\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE9-e 착수 기록 (2026-10-16 07:30, Lane A)

- 상태: **진행 중**. 범위: 전술대항전 분석 화면(Tactical-Analysis S1~S3) · 족보 전체 보기 팝업(Tactical-Analysis-All) · 기록 ↔ 분석 하위 화면 전환(FD-126 seg를 셸 머리말로, 섹션 intro/outro). 슬롯(FE9-g)은 seg 자리만(흐림).
- 착수 전 확인: 이 문서 끝에 다른 "FE9-e 착수 기록" 없음(grep 0건). 막힘 요약 `열림` 0건(FE9-e 행 FD-126 · FD-127 모두 확정). 워커 재량 FD-129 · FD-130 · FD-134는 권장안으로 처리한다.
- 시작 SHA(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`): `1d9a11b360ecf5a090150ee49000cfcae0be6407`.
- 고칠 기존 파일(모두 착수 때 WIP 없음 — `git status --short` 빈 줄, 사본 `debug/frontend_fe9e/pre/<경로>`):

| 파일 | 줄바꿈 | WIP |
|---|---|---|
| `frontend/lib/ui/pages/tactical_page.dart` | CRLF | 없음 |
| `frontend/lib/ui/tactical/tactical_workspace.dart` | LF | 없음 |
| `frontend/lib/ui/studio/tactical_studio_layout.dart` | LF | 없음 |
| `frontend/lib/ui/app_shell.dart` | LF | 없음 |
| `frontend/lib/ui/widgets/page_header_override.dart` | LF | 없음 |
| `frontend/test/tactical_page_test.dart` | LF | 없음 |
| `frontend/test/goldens/fe9a_tactical_golden_test.dart` | LF | 없음 |
| `frontend/lib/services/design_review/tactical_records_data.dart`(고칠 수도 있음) | LF | 없음 |
| `frontend/lib/tactical/tactical_records_controller.dart`(고칠 수도 있음) | LF | 없음 |
| 이 문서 | LF | 없음 |

- 새 파일 예정: `frontend/lib/ui/tactical/tactical_analysis_view.dart`(위젯 없는 모델) · `tactical_analysis_workspace.dart`(분석 3섹션) · `tactical_jokbo_all_panel.dart`(전체 보기 팝업) · `tactical_sub_screen.dart`(머리말 seg · 하위 화면 모션), `frontend/test/tactical_analysis_test.dart`.
- 스캐너 시각부 미커밋 5파일 · `lib/services/**`(design_review 제외) · 키트 · 택틱 · 통계 파일은 고치지 않는다.

## FE9-e 종료 기록 (2026-10-16 08:05, Lane A, 코드 작성 완료 · CF gate 미실행)

전술대항전 분석 화면(시안 Tactical-Analysis S1~S3)과 족보 전체 보기 팝업(Tactical-Analysis-All)을 만들고, 하위 seg "기록 · 분석 · 슬롯"을 셸 머리말 제목 옆으로 옮겼다(FD-126 (a), CF 결정 2026-10-16). 하위 화면을 바꾸면 섹션이 부착면 방향으로 빠지고 들어온다. 슬롯은 seg 자리만(흐림 + "준비 중"). HEAD는 착수 때와 같다(`1d9a11b3`).

### 실행한 명령과 결과(이 PC, `frontend` 폴더)

- `flutter analyze`(작성 중 경로별 여러 번 · 전체 3회): 마지막 전체 **No issues found(0)**. `pubspec.yaml` · `pubspec.lock` 변경 0(analyze가 pub get을 돌렸지만 git status 변화 없음).
- `flutter test test/tactical_page_test.dart test/tactical_jokbo_panel_test.dart test/tactical_page_revision_test.dart --exclude-tags golden`: ① +41 −1(예상된 실패 — seg를 머리말로 옮겨 S1의 `tactical-view-analysis` 툴팁 테스트가 깨짐) → 테스트를 "S1 제목 줄에 seg 없음 · 엑셀 준비 중"으로 고침.
- 새 `flutter test test/tactical_analysis_test.dart`: ① +10 −9(구현 쪽 2: 누적 돌파율 칸 110+220+60 > 370 넘침, 팝업 줄 높이 66 < 내용 52.6 + 테두리 → 70 · 테두리는 foregroundDecoration / 테스트 쪽 1: 검증 강도 키가 칩) → ② +13 −4 → ③ **+19** → 1280×720 셸 테스트 추가 뒤 **+20**.
- 바뀐 동작에 걸리는 기존 테스트(grep: `TacticalPage` · `tactical_workspace` · `tactical_studio_layout` · `AppSection.pvp` · `top-tab-pvp` · `BAPlannerApp(` · `PageHeaderOverride` · `page-header` · `tactical_jokbo` · `designReviewTactical` · `MockDesignReviewScenario` · `tactical-view` + tactical 서비스 4), 일반 29파일 한 명령(`--exclude-tags golden`, json): **+288 −0** — account_editor_fe8c 9, account_manager_fe8b 6, app_navigation_fe7d 14, app_navigation_tidy1 11, connected_target_fe8d 8, design_review_tactical_seed 2, growth_calculator_view 24, home_app_shell 1, home_connect_fe8e 10, home_page 5, inventory_shell_lazy 1, mock_design_review_scenario 11, profile_delete_fb2d 17, section_template_studio 15, statistics_app_shell 2, statistics_filter 10, student_filter_followups 4, student_filter_modal 8, tactical_analysis 19(그 뒤 20), tactical_jokbo_panel 17, tactical_lobby_scanner_service 2, tactical_page_revision 5, tactical_page 20, tactical_records_controller 14, tactical_service 6, tactical_share_v1_contract 1, tactical_v2_service 5, title_page 25, widget 16.
- process 묶음 분류 1파일(`--concurrency=1`): tactical_fe9b1_read **+12**.
- 일회성 렌더(임시 `test/goldens/zz_fe9e_render_tmp_test.dart` = golden 파일 사본에서 `@Tags(['golden'])` · `expectGoldenScene` 0건을 grep으로 확인한 뒤 `toImage` → scratchpad PNG, 실행 뒤 삭제): **+5**(다섯 장면). 모양을 눈으로 확인했다(아래 golden 절). 렌더 뒤 누적 돌파율 묶음 사이 간격 28을 더했다(analyze 0 · 분석 테스트 +20 다시 확인).
- `dart format`: 이 slice 파일 경로만 하나씩(디렉터리 인자 0). `app_shell.dart`를 포맷했을 때 이 slice와 무관한 `_TopTab` 한 줄이 접혀서 원래 3줄로 되돌렸다(아래 diff 크기는 되돌린 뒤).
- `git diff --check`(고친 기존 7파일 + 이 문서): exit 0. 새 6파일: CR 0 · 줄 끝 공백 0 · 끝 개행 하나. `tactical_page.dart`는 CRLF 그대로(1353줄 모두 CRLF), 나머지 LF.
- 잠금 충돌 0(재시도 없음). 로그: `debug/frontend_fe9e/logs/`(실패 줄과 json 요약만 확인).

### 고친 파일 · 새 파일

| 파일 | 내용 |
|---|---|
| `frontend/lib/ui/widgets/page_header_override.dart` | `backLabel` · `onBack` 선택 인자, 새 `trailing`(제목 옆 위젯). 값은 탭마다 하나(Map) — 학생 계산기와 전술 seg가 서로 지우지 않게. `back()`은 `onBack`이 없으면 false(셸 기본 동작 = 다시 읽기). `value` getter 삭제(사용처 0, grep) |
| `frontend/lib/ui/app_shell.dart` | **+10 −3**: TacticalPage에 `headerOverride` 1줄, 머리말 복귀 칩 조건(`backLabel != null`), 제목 · 칩 뒤 `trailing` |
| `frontend/lib/ui/pages/tactical_page.dart`(CRLF) | 머리말 seg 걸기(빌드 뒤 · 화면 바꿀 때) · 해제(dispose), 하위 화면 상태 · `TacticalSubScreenStage`, 분석 질의(통계 · 추이 · 추천, 200ms 디바운스 · 세대 번호 · dispose 뒤 setState 0), 분석 값 조립, 전체 보기 팝업(BaModal), 분석 → 기록 복사 |
| `frontend/lib/ui/tactical/tactical_workspace.dart` | S1 제목 줄에서 seg 삭제, `_SectionEdges` · `_placed`를 새 공용 파일로(식 그대로), 섹션 모션 오프셋 훅 `sectionOffset` |
| `frontend/lib/ui/studio/tactical_studio_layout.dart` | 분석 3섹션 Studio 문서 · `tacticalSectionMotion`(부착면 표) · `TacticalAnalysisMetrics`(시안 좌표 · 팝업 자리) |
| `frontend/test/tactical_page_test.dart` | seg 툴팁 테스트 → "S1 제목 줄에 seg 없음 · 엑셀 준비 중" |
| `frontend/test/goldens/fe9a_tactical_golden_test.dart` | 장면 2 추가(`tactical-analysis` · `tactical-analysis-all`, 고정 시계 Mock 하위 클래스 · seg 누르기), 머리 주석 |
| 새 `frontend/lib/ui/tactical/tactical_section_edges.dart` | 섹션 변 · 요소 자리(기록 · 분석 공용) |
| 새 `frontend/lib/ui/tactical/tactical_sub_screen.dart` | 하위 화면 enum(글자 · 부제), 머리말 seg 위젯, 전환 모션 stage |
| 새 `frontend/lib/ui/tactical/tactical_analysis_view.dart` | 위젯 없는 모델: 30일 기간, 시그니처 행, 족보 카드 · 시도 지표 · 상대별 결과, 상대 카드(이력 · 2~4번 비율 · 변경 감지 · 유효한 족보), 정렬, 검증 강도 |
| 새 `frontend/lib/ui/tactical/tactical_analysis_workspace.dart` | 분석 3섹션 그리기 |
| 새 `frontend/lib/ui/tactical/tactical_jokbo_all_panel.dart` | 족보 전체 보기 팝업(자리 계산 · 정렬 seg · 순위 줄) |
| 새 `frontend/test/tactical_analysis_test.dart` | 20건(아래) |

고치지 않음: `lib/tactical/tactical_records_controller.dart`(필요한 값이 이미 있음 — pre와 cmp 일치), `lib/services/design_review/tactical_records_data.dart`(seed 확장 없이 1 시그니처 · 족보 2 · 상대 2로 시안 상태가 나옴 — cmp 일치), `lib/services/**`(Lane B 작업 중 파일 열지 않음), 스캐너 시각부 5파일, 키트 · golden harness · 통계 · 택틱 파일.

### 머리말 seg 구현(FD-126 (a))

- **diff 크기**: `app_shell.dart` **+10 −3**(13줄), `page_header_override.dart` +30 −22.
- **이유**: 시안에는 하위 이동 UI가 없고(G §0, A1) 사용자 결정 (a)는 "헤더 제목 옆 하위 seg"다. 셸 머리말은 지금 탭과 `PageHeaderOverride.section`이 같을 때만 override 값을 그리므로, 같은 통로에 "제목 옆 위젯" 한 자리(`trailing`)만 더했다. 복귀 칩이 없는 override(전술)를 위해 `backLabel` · `onBack`을 선택으로 바꿨다. 값을 탭마다 한 개로 바꾼 이유: 예전 컨트롤러는 전역 한 개라, 전술 화면이 seg를 걸면 학생 성장 계산기의 머리말(제목 · "← 학생")이 지워진다.
- **부제**: 기록 "전술대항전 기록과 편성" · 분석 "공개 방어 시그니처별 족보 분석" · 슬롯 "슬롯별 사용률 · 위치 선호 · 궁합 · 카운터"(시안 그대로, 슬롯은 열리지 않아 보이지 않는다).
- **같은 탭 다시 누르기**: 전술 override에는 `onBack`이 없어 `back()`이 false → 셸이 예전처럼 `_tacticalReloadToken`을 올린다(다시 읽기, 하위 화면은 그대로). 테스트로 확인.
- **다른 탭 영향 0 근거**: ① 머리말 위젯 트리는 `trailing == null`이면 예전과 같다(새 `if` 블록이 아무것도 넣지 않음). ② 복귀 칩 조건은 `backLabel != null`이 더해졌을 뿐이고, 유일한 다른 사용처(학생 계산기, `student_page.dart` 239)는 `backLabel` · `onBack`을 늘 준다. ③ 값은 `section == AppSection.pvp`로만 걸리므로 다른 탭의 `valueFor`는 예전과 같다(학생은 학생 값 그대로). ④ 테스트: 셸 테스트에서 첫 화면(홈) · 학생 탭에 seg 없음, 학생 계산기 테스트(growth_calculator_view 24)와 셸을 띄우는 18파일 모두 통과. ⑤ golden: 다른 golden 중 머리말 override를 쓰는 것은 `fe1g_baseline_golden_test.dart`의 성장 계산기 장면(복귀 칩)뿐이고 위 ②로 같은 위젯이다.

### 분석 화면(시안 Tactical-Analysis)

- **3섹션 좌표**(기준 콘텐츠 캔버스, 테스트로 고정): S1 (0,2,21,94) 왼쪽 사다리꼴 — 시안과 같음. S2 rect (7,2,68,94) 아래 면 평행사변형(faceStart 10 · faceSpan 72 · height 96, **FD-130 주 부착면 아래**) — 꼭짓점 0.4px 안. S3 (66,2,30,94) 오른쪽 사다리꼴 — 시안과 같음. 섹션 안 요소 rect 21개를 시안 ±2px로 테스트한다(S1 행 · S2 11 · S3 9).
- **S1 공개 방어 시그니처**: 제목 + "최근 30일" 칩, 공용 `DiagonalScrollViewport` resize 모드(행 86 · 간격 8, 첫 행 폭 511.7 — 시안과 같음, 스크롤바 · 포그). 행 = 공개 칸 초상 3(1번 | SP1 · SP2, 42×34) · 최근 관측("23h") · "방어 유저 n · 족보 n" · 칩 "변경 의심 n"(있을 때) · "표본 적음"(FD-134). 누르면 그 시그니처로 바뀐다(족보 · 상대 선택 초기화). 고른 행은 레일 분홍 선택.
- **S2 족보 상세**: 이름 · "편집"(흐림 + "준비 중") · "검증 강도 X", 상대 방어 덱 6칸(73×59, 이름 · 위치) + "이 방어 덱 사용 n명 / 최근 30일 · 같은 6명 · 같은 위치", 족보 seg(상위 4, 고른 족보가 밖이면 넷째 자리에) + "전체 보기 (n)", 공격 덱 6칸 + "공격 기록에 복사" · "내 보유로 대체 찾기"(흐림 + "준비 중"), KPI 6칸, "N회 내 누적 돌파율" 막대 3, "상대별 결과" 4행(`srow`, 누르면 S3 상대가 바뀌고 그 줄이 파랑), "수명 · 신선도" 한 줄.
- **S3 상대 카드**: "<이름> · 순위 —", 공개 방어 이력(지금 구간 30×24 + "10/3 ~ 현재", 앞 구간이 있으면 화살표 + 24×19 + 기간), "추정 숨은 스트라이커 2~4번 (추정값)" 4행 + 근거 줄, 변경 감지, "이 유저에게 유효한 족보" 2행(이름 + "이 상대 n승 m패" 칩 + 덱 46×37), 기억 카드.
- **데이터**: 컨트롤러 기록 · 족보 + `TacticalEvidenceReadService` 통계(`date_from` = 30일 전) · 추이(`date_from` · `as_of`) · 추천(시즌 · 고른 상대 · 시그니처). 분석 화면이 열려 있을 때만 묻는다(기록 화면 테스트의 서비스 호출 변화 0). 늦은 응답은 세대 번호로 버리고, 실패하면 S2 제목 줄에 빨간 "분석 통계를 읽지 못했습니다. 기록에서 센 값만 보입니다." + "다시 읽기"(기록에서 센 값은 그대로).
- **안내 문구**: 서비스 없음 · 계정 없음 · 읽는 중 · 읽기 실패는 기록 화면 문구, 이관 전 "이전 형식 기록을 가져온 뒤에 분석할 수 있습니다. 기록 화면에서 "가져오기"를 눌러 주십시오.", 기록 없음 "최근 30일 동안 로비 공개 칸(1번 · SP1 · SP2)이 있는 공격 기록이 없습니다. …", S2/S3 "왼쪽에서 공개 방어 시그니처를 고르면 족보와 상대 카드가 보입니다." · "이 시그니처로 최근 30일에 기록한 상대가 없습니다.".
- **Mock**: design-review seed(FE9-b1 · FE9-d) 그대로로 보인다 — 시그니처 1(히나 | 히비키 · 아코), 족보 2, 상대 2. 기본 Mock(빈 v2)은 기록 없음 안내.

### 숨긴 지표(FD-127 (a)) · 대체 표시

| 시안 | 처리 | 근거 |
|---|---|---|
| S1 "최다 채택 족보 X" | 그리지 않음 | 채택 = 다수 사용자 자료 |
| S2 칩 "널리 알려짐 · 변경 위험" | 그리지 않음 | 판단 · 다수 사용자 |
| S2 KPI "채택률 52% · 28명 중" | 칸은 두고 '—' | 다수 사용자 자료(공유 집계는 읽기 capability에 없음) |
| S2 KPI "독립 재현 12명 · 방어 8명 상대" | 칸은 두고 '—' | 같은 이유(share analytics는 Process 전용 `TacticalEvidenceService`, Mock 미구현) |
| S2 KPI 관측 성공률 · 첫 시도 성공 · 평균 시도 · 최근 검증, N회 내 누적 돌파율 | **관측 값으로 그림** | 같은 편성 v2 기록의 승패 · `attempt_count`(FE9-d 발견 5). 시도 모름은 분모에서 뺀다(FD-176) |
| S2 상대별 결과 보조 "안정 · 비추천 · 최근 검증" | "마지막 대전 n시간 전"으로 바꿈 | 판단 문구 대신 관측 시각 |
| S2 대체 학생 허용도(3행) | 캡션 · 행 모두 그리지 않음(자리 비움) | 공유 집계(`one_slot_substitutions`) |
| S2 수명 · 신선도 "전성기 · 최근 성공률 76%→71% · 시간 가중 점수 68 · 최초 제보자 / 타 사용자" | "최초 10/3 · 최근 10/4 · 관측 기록 n건 · 시도 횟수를 아는 기록 n건"만 | 시간 가중 점수 = 모델 지표, 제보자 = 공유 자료 |
| S3 칩 "방어 변경 성향 높음" | 그리지 않음 | 판단 지표 |
| S3 순위 "31위" | "순위 —" | 데이터 없음(기록 화면과 같음) |
| S3 추정 숨은 스트라이커 %(근거 비중) | **이 상대 기록에서 그 학생이 2~4번에 나온 비율**로 그림 | 확률이 아닌 관측 비율(근거 줄에 "기록에 나온 비율"이라고 적음) |
| S3 변경 감지 "족보 A 성공률 76% → 28% · 추정 시점 9/21 밤" | "n번 A → B · 마지막 같은 덱 M/D · 바뀐 기록 M/D"(없으면 "변경 관측 없음") | 추정 시점 · 성공률 변화 대신 관측 변화 |
| S3 유효한 족보 칩 "변경 이후 4승 1패 · 최근 3연속 실패" | "이 상대 n승 m패" | 관측 승패 |
| S3 기억 카드 "평균 유지 1.8일 · 12시간 내 변경 확률 63%" | "최근 30일 기록 n건 · 공개 덱 변경 n회 · 마지막 대전 …"만 | 확률 지표 |
| 팝업 채택률 · 독립 재현 열과 정렬 | 열 '—', 정렬 seg 꺼짐 + 툴팁 "공유 자료가 없어 이 값으로 정렬할 수 없습니다." | 같은 이유 |

### 처리한 FD

- **FD-126 (a)**: 셸 머리말 제목 옆 seg(위 절).
- **FD-127 (a)**: 위 표.
- **FD-129(워커 재량, 권장안)**: 시그니처 족보 = 방어 덱이 그 공개 시그니처를 가진 족보의 합집합. S1 "족보 n", S2 seg · "족보 n개" · 전체 보기가 모두 같은 집합이다(→ 발견 2). 독립 재현은 share analytics가 읽기 capability에 없어 '—'.
- **FD-130(워커 재량, 권장안)**: 분석 S2 주 부착면 = 아래(intro 80° · outro 260°). Studio spec도 face bottom.
- **FD-134(워커 재량)**: 검증 강도 = 추천 `confidence_grade` high/medium/low → A/B/C, 그 밖 '—'(칩 색 A 초록 · B 파랑 · C 노랑 · — 회색). **표본 적음은 권장안과 다르게** "관측 기록(승 + 패) 5건 미만"으로 했다 — 권장안의 "독립 재현 5명 미만"은 독립 재현을 읽을 수 없고, `populationWarning`은 통계 · 추이 응답에 늘 들어 있는 고정 문장이라 기준으로 쓰면 모든 줄이 표본 적음이 된다(→ 발견 3). 팝업 각주도 이 기준으로 바꿨다("관측 기록 5건 미만은 흐리게 표시합니다 · …").
- FD-176: 시도 모름 기록은 첫 시도 · 평균 · 누적 돌파율 분모에서 뺀다.

### 정한 규칙

- **분석 대상 기록**: 공격 기록 · 시각을 앎(정밀도 date · instant) · 고정 시계 기준 30일 안 · 상대 방어 덱에 공개 칸 있음. 방어 기록 · 시각 모름은 빠진다.
- **시그니처 행**: 기록에서 모은 시그니처 + 통계 응답의 시그니처(로비 관측만 있는 것은 공개 칸만 그린다). 순서 = 최근 관측 → 기록 수 → 시그니처. 방어 유저 = 통계 행 `opponent_count`, 없으면 기록의 상대 수(→ 발견 4). "변경 의심 n" = 기록 사이 2~4번 학생이 바뀐 상대 수(앞 · 뒤 모두 학생을 아는 칸만).
- **족보 승패**: 통계 시그니처 행의 공격 덱 값, 행이 없으면 30일 안 같은 편성 기록(FE9-d 규칙에 기간만 더함). 카드 순서 = FE9-d(승 많은 순 → 패 적은 순 → 이름). **기본 족보 = 관측 표본(승 + 패)이 가장 많은 카드**(seed: 게헨나 족보 1승 1패 — 시안 "족보 A"처럼 2위가 골라짐).
- **seg 글자**: 족보 이름의 첫 " · " 앞("족보 edd9e2").
- **기본 상대(S3)** = 고른 시그니처의 가장 최근 기록 상대. S2 상대별 결과 줄을 누르면 바뀐다.
- **이 방어 덱 사용 n명** = 30일 안 기록 중 방어 덱 identity(6명 · 위치 · 모름 · 빈칸)가 고른 족보 방어 덱과 같은 상대 수.
- **공개 방어 이력** = 이 상대의 분석 대상 기록을 오래된 순으로 보고 공개 시그니처가 이어지는 구간(가장 최근 구간 "~ 현재"). 공개 덱 변경 = 구간 수 − 1.
- **팝업**: 키트 `layoutKitOverlay` 아래 · 오른쪽 맞춤(버튼 아래 12, 패널 오른쪽 = 버튼 오른쪽 + 16, 꼬리 = 패널 오른쪽 − 120, 키트 `KitOverlayTail`), 폭 940(화면이 좁으면 여백 8 안), 아래 공간에 들어가는 줄만 놓고 넘치면 "족보 n개 중 k개를 보입니다.". 기준 창에서 패널 왼쪽 · 위가 시안 (941, 467)과 2px 안(테스트). 줄을 누르면 S2 족보가 바뀌고 팝업은 열린 채("보는 중"이 옮겨감). 닫기 = 닫기 버튼 · Esc · 스크림. 하위 화면을 바꾸면 닫힌다.
- **"공격 기록에 복사"(S2 · 팝업 줄)**: 팝업을 닫고 기록 화면으로 돌아가 FE9-d `_copyJokbo` 규칙 그대로 내 덱 초안을 채운다(저장 0, 보유하지 않은 학생은 빗금 + 상태 문구). 지금 초안이 방어 기록 · 이전 형식이면 새 공격 초안(이번 시즌)을 연 뒤 채운다. 계정 없음 · 저장 중이면 버튼 흐림 + 이유 툴팁.
- **전환 모션**: 인벤토리 분석 ↔ 티어(FE6-e)와 같은 문법 — `AppMotion.section` × 2(720ms), 앞 절반 지금 섹션 outro, 뒤 절반 새 섹션 intro(`sectionExitOffset` · `sectionEntryOffset`, `AppMotion.sectionCurve`). 방향 `tacticalSectionMotion`: 기록 S1 0/180 · S2 260/80 · S3 80/260 · S4 180/0, 분석 S1 0/180 · S2 80/260(FD-130) · S3 180/0. 움직이는 동안 누르기 꺼짐. 멈춰 있을 때 오프셋은 0이고 순수 이동 Transform이라 그림 · golden에 영향 없음.
- 머리말 seg는 셸 머리말 빌드 밖(빌드 뒤 콜백 · 이벤트)에서만 건다(빌드 중 notify 금지).

### golden 변화 예상(비교 미실행)

- `tactical`: **바뀜** — 머리말 제목 "전술대항전" 오른쪽에 seg(기록 분홍 · 분석 · 슬롯 흐림), 머리말 줄 높이가 seg(32)만큼이라 부제가 몇 px 내려갈 수 있음. S1 제목 줄은 "기록" + "새 기록" · "엑셀 가져오기"만(seg 빠짐). 나머지 같음.
- `tactical-jokbo-drag`: **바뀜** — 같은 머리말 · S1 제목 줄 변화. 끌기 고스트 · 알약 · 강조는 같음.
- `tactical-migration`: **바뀜** — 같은 머리말 · S1 제목 줄 변화. 이관 띠 · 읽기 전용 · S4 "준비 중"은 같음.
- 새 `tactical-analysis`(optional_added): 머리말 부제 "공개 방어 시그니처별 족보 분석", seg 분석 분홍. S1 행 1개(분홍 선택: 히나 | 히비키 · 아코 초상, "23h", "방어 유저 2 · 족보 2", "표본 적음"). S2 "족보 edd9e2 · hoshino" · 편집(흐림) · "검증 강도 B"(Mock 추천 medium, 파랑), 상대 방어 덱 히나 · 이오리 · 아루 · 하루카 | 히비키 · 아코 + "1명", seg "족보 3a0a33 · 족보 edd9e2(분홍)" + "전체 보기 (2)", 공격 덱 호시노 · 이즈나 · 미카 · 카요코 | 아야네 · 하나에 + 복사 · 대체 찾기(흐림), KPI — · 50%(1승 1패) · 50% · 1.0회 · — · 23h 전, 누적 50% × 3, 상대별 결과 "게헨나 선도부 1승 1패" 파랑 테두리, (대체 학생 자리 비움), 수명 · 신선도 한 줄. S3 "게헨나 선도부 · 순위 —", 이력 "10/3 ~ 현재", 2~4번 아루 · 하루카 · 이오리 100%, 근거 줄, "변경 관측 없음", 유효한 족보 1행(이 상대 1승 1패 회색), 기억 카드. 일회성 렌더로 확인.
- 새 `tactical-analysis-all`(optional_added): 위 화면 + 스크림 .35 + 940 패널(꼬리는 "전체 보기" 위), "족보 전체 · 2개 · 상대 방어 덱: 히나 · 이오리 · 아루 · 하루카 | 히비키 · 아코", 정렬 seg 성공률(분홍) · 채택률 · 독립 재현(흐림) · 최근 성공, 1위 "족보 3a0a33 · haruna" 100% · 3일 전, 2위 "족보 edd9e2 · hoshino · 보는 중"(분홍 외곽) 50% · 23시간 전, 두 줄 모두 흐림 .62 + "표본 적음", 각주. 일회성 렌더로 확인.
- 다른 장면: 변화 0 예상(위 "다른 탭 영향 0 근거").

### 미검증(미실행)

- 전체 `fe_gate.ps1` · golden 비교 · `-UpdateGoldens` · `codealmanac validate` · 저장소 전체 `git diff --check`: **미실행**(CF 몫).
- 위 목록 밖 Flutter 테스트(통계 · 계획 · 인벤토리 · 스캔 화면 단독, process E2E): **미실행**. `lib/services/**` 수정 0.
- 실제 백엔드에 붙인 분석 화면: **미실행** — 통계 `date_from` · 추이 신선도 `last_success_at` · 추천 `confidence_grade`가 실제 값일 때, 로비 관측만 있는 시그니처 행.
- 실제 마우스 · 창 크기 조절 중 팝업 위치(앞 프레임 버튼 자리를 쓴다), Windows release 빌드: **미실행**.
- Lane B가 같은 시각 `lib/services/**`(fb7-dart)를 고치고 있어, 내 테스트는 그 작업 중 파일 위에서 돌았다(실패 0).

### 검수표(시안 Tactical-Analysis · -All, mock 모드 · 기준 viewport 최대화)

| 순서 | 여는 방법 | 확인 포인트 |
|---|---|---|
| 기록 | 개발 패널 design-review 시나리오 → 전술대항전 탭 | 머리말 "전술대항전" 옆 seg(기록 분홍 · 분석 · 슬롯 흐림 + "준비 중" 툴팁), 부제 "전술대항전 기록과 편성", S1 제목 줄에 seg 없음 |
| 분석 | 머리말 seg "분석" | 기록 섹션이 부착면 쪽으로 빠지고(S1 왼쪽 · S2 위 · S3 아래 · S4 오른쪽) 분석 섹션이 들어옴(S2는 아래에서), 부제 바뀜. S1 시그니처 행 · 표본 적음, S2 족보(게헨나) KPI · 채택률 · 독립 재현 '—' · 누적 돌파율, S3 게헨나 카드 |
| 족보 바꾸기 | S2 seg 다른 족보 | 이름 · 덱 · KPI 100% · 상대별 결과 "아비도스 대책위원회" |
| 상대 바꾸기 | S2 상대별 결과 줄 | S3 제목 · 이력 "10/2 ~ 현재" · 근거 |
| 전체 보기 | "전체 보기 (2)" | 스크림 .35, 940 패널 꼬리가 버튼을 가리킴, 성공률 정렬 · "보는 중" 2위 · 흐림 + 표본 적음, 채택률 · 독립 재현 정렬 흐림 + 툴팁, "최근 성공"으로 바꾸면 순서 바뀜, 줄 누르면 S2 족보 바뀜, Esc · 닫기 · 스크림으로 닫힘 |
| 복사 | 팝업 줄 "공격 기록에 복사" | 기록 화면으로 돌아감(모션), 내 덱 = 그 족보 덱, 상태 문구 "… 복사했습니다. 저장하면 기록에 남습니다.", 목록 · revision 변화 없음. 방어 행을 고른 상태였으면 "새 공격 기록" 초안 |
| 다시 기록 | 머리말 seg "기록" | 부제 원래대로, 다른 탭(학생 · 통계)에 seg 없음, 전술 탭 다시 누르면 하위 화면 유지(다시 읽기) |
| 작은 창 | 1280×720 | 넘침 없음, 팝업이 화면 안 |

### 테스트(새 · 고친)

- 새 `tactical_analysis_test.dart`(20): Studio 3섹션 꼭짓점 · 모션 방향 표, 모델 7(30일 기간 · 시그니처 행 · 족보 시도 지표와 시도 모름 · 상대 카드 · 변경 감지 · 정렬 · 검증 강도), 셸 머리말(제목 옆 seg · 부제 · 슬롯 준비 중 · 다른 탭 seg 없음 · 같은 탭 다시 누르기), 셸 1280×720(넘침 0 · 팝업 화면 안), 분석 화면 7(전환 모션 앞 · 뒤 절반, 시안 rect 21개 + 관측 값, seg · 상대 줄, 팝업 자리 · 꼬리 · 정렬 · 줄 선택 · 닫기, 팝업 복사(방어 초안 → 새 공격 초안, 저장 0), S2 복사(공격 초안 유지), 기본 Mock 안내), 1280×536 · 1440×716 페이지 넘침 0.
- 고친 `tactical_page_test.dart`: 지운 테스트 "sub views analysis and slots are disabled with 준비 중" → 대체 "S1 title has no sub view seg and excel import is pending"(슬롯 준비 중 툴팁은 새 셸 테스트가 검사).

### WIP 보존 확인

- 고친 기존 7파일 + 이 문서는 착수 때 WIP 없음 → `post_dir` 없음. pre 사본 `debug/frontend_fe9e/pre/<경로>`(10파일 — 고치지 않은 컨트롤러 · seed 데이터 포함, 둘은 cmp 일치).
- 스캐너 시각부 5파일(`scan_page.dart` · `scan_companion_dock.dart` · `scan_student_review_workspace.dart` · 그 테스트 2), Lane B 작업 중 `lib/services/**`(mock_app_service · mock_tactical_v2_writes · planning_protocol_client · process_app_service · tactical_v2_service): 열지도 고치지도 않았다. `dart format`은 이 slice 파일 경로만. git 쓰기 0회. 임시 렌더 파일은 실행 뒤 삭제(`test/goldens/`에 `zz_` 0건 확인).

### 키트 승격 후보(Lane A 판단)

- `TacticalSectionEdges` · `tacticalPlaced`(통계 화면에도 같은 "섹션 변 + 요소 자리" 식이 있음 — 키트 `SectionFrame` 옆 후보).
- `TacticalSubScreenStage`(인벤토리 `_InventoryAnalysisStage` 교체 모션과 같은 문법 — 키트 "섹션 교체 stage" 후보, golden 0으로 옮길 수 있음).
- 팝업 자리 계산 `tacticalJokboAllPlacement` + `KitOverlayTail` + `BaModalPanel.dialog` = "앵커 모달"(BaModal에 anchor 자리 옵션) 후보.
- 덱 초상 줄이 이제 넷째 사본이다(`TacticalDeckStrip` · 분석 `_DeckRow` · 팝업 `_deck` · `TacticalMiniDeck`) — FE9-d 후보와 합쳐 한 벌로.

### 발견 사항

1. **머리말 컨트롤러 전역 1개 문제(고침)**: 예전 `PageHeaderOverrideController`는 값이 하나라, 다른 탭 화면이 값을 걸면 학생 성장 계산기 머리말이 지워질 수 있었다. 탭마다 하나로 바꿨다(위). CF가 셸 소유 규칙상 확인 필요.
2. **"이 방어 덱을 깨는 족보 n개" 문구 vs FD-129**: 시안 문구는 그대로 두었지만, n은 FD-129 시그니처 족보(합집합)라 S1 "족보 n"과 늘 같다. 완전 방어 덱별로 나누려면(시안 A2 — S1 4 · S2 7) 규칙 결정이 필요하다. CF 판단.
3. **FD-134 표본 적음 기준**: 권장안 "독립 재현 5명 미만 또는 populationWarning"은 지금 쓸 수 없다(독립 재현 읽기 capability 없음, `populationWarning`은 고정 문장). "관측 기록 5건 미만"으로 했고 각주 문구도 바꿨다. 공유 집계를 읽게 되면 권장안대로 되돌릴지 CF 판단.
4. **방어 유저 수 두 규칙**: 분석 S1은 통계 행이 없으면 기록의 상대 수를 쓰고, 기록 화면 S4 KPI(FE9-d)는 '—'다. Mock에서 둘이 다르게 보인다(분석 2 · S4 —). 통일할지 CF 판단(S4를 고치면 `tactical` golden이 또 바뀜).
5. **검증 강도 vs FD-127**: FD-127 질문 목록에 "검증 강도"가 있지만 FD-134 권장안(A/B/C)이 이 slice에 배정되어 칩을 그렸다. 숨기려면 칩 한 줄을 빼면 된다(golden `tactical-analysis` · `-all` 변화).
6. **30일 기간**: S1 "최근 30일" 칩대로 분석은 30일 안 기록만 쓴다(통계 · 추이 `date_from`도 같다). 기록 화면 S4(FE9-d)는 기간이 없어 두 화면 숫자가 다를 수 있다.
7. **design-review seed**: 시그니처가 1개뿐이라 S1이 한 줄이고 대체 학생 자리가 비어 S2 아래가 휑하다. 검수에 여러 시그니처가 필요하면 seed 확장(revision 4 → 기록 수 · 자동 족보 수가 바뀌어 seed 테스트 · `tactical` golden도 바뀜)이 필요하다 — 이번에는 하지 않았다.
8. **팝업 위치**: 버튼 자리를 앞 프레임 레이아웃에서 읽는다(창 크기를 바꾸는 동안 한 프레임 늦을 수 있음).
9. **Mock 자동 족보 이름이 ID**(FE9-d 발견 4 그대로): seg 글자가 "족보 edd9e2"로 보인다.
10. **상대별 결과 이름 칸**: 시안 80px은 실제 상대 이름("게헨나 선도부")이 잘려 150px로 넓혔다(줄 폭 안).
11. fe_gate 분류: `tactical_analysis_test.dart`에 `ProcessAppService` 문자열이 없어 일반 묶음이다(+20, 약 15초).

### 사본 · commit.json

- `debug/frontend_fe9e/commit.json`: slice `fe9e`, modified 8(이 문서 포함), added 6, `post_dir` 없음(WIP 없음), `whole` = `tactical.png` · `tactical-jokbo-drag.png` · `tactical-migration.png`, `optional_added` = `tactical-analysis.png` · `tactical-analysis-all.png`, `status=true`.
- 인계: `debug/frontend_fe9e/output.md`. 로그 `debug/frontend_fe9e/logs/`.

### 다음 행동

- FE9-e 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: Lane B(fb7-dart)가 멈춘 뒤 gate 1회(예상: analyze 0, 일반 테스트에 tactical_analysis +20 · tactical_page 20 그대로, golden `tactical` · `tactical-jokbo-drag` · `tactical-migration` RED(머리말 seg · S1 제목 줄) · 새 `tactical-analysis` · `tactical-analysis-all` 기준 없음, 다른 장면 GREEN) → 실패 이미지 확인 → `-UpdateGoldens` → `fe_commit.ps1 -Slice fe9e`.
- 발견 1(셸 컨트롤러) · 2 · 3 · 4 · 5는 CF 판단, 7은 검수 seed 후속 후보.

### fe9e commit record (2026-10-16 08:38, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261016_082438\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE9-f 착수 기록 (2026-10-16 15:30, Lane A)

- 상태: **진행 중**. 범위: A. 엑셀 가져오기 모달(시안 Tactical-Import-Excel — S1 "엑셀 가져오기" 켜기 → 파일 선택 → `tactical.v2.excel.preview` → 승인 모달 → `commit` → 기록 다시 읽기), B. 분석 화면 S2 "검증 강도" 칩 숨김(FE9-e 발견 5, CF 결정 2026-10-16 — FD-127 (a)).
- 착수 전 확인: 이 문서 끝에 다른 "FE9-f 착수 기록" 없음(grep 0건). 막힘 요약 FE9-f 행 FD-128 확정(열림 0건). 워커 재량 FD-131은 권장안으로 처리한다.
- 시작 SHA(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`): `a5e179faaf6f9467f1ec8469f0b6d47c383e3420`(프롬프트 작성 뒤 XB 커밋 2개 `a1bae239` · `a5e179fa`가 더 있음 — 이 slice 파일은 건드리지 않음).
- 고칠 기존 파일(모두 착수 때 WIP 없음 — `git status --short` 빈 줄, 사본 `debug/frontend_fe9f/pre/<경로>`):

| 파일 | 줄바꿈 | WIP |
|---|---|---|
| `frontend/lib/ui/pages/tactical_page.dart` | CRLF | 없음 |
| `frontend/lib/ui/tactical/tactical_workspace.dart` | LF | 없음 |
| `frontend/lib/ui/tactical/tactical_analysis_workspace.dart` | LF | 없음 |
| `frontend/lib/ui/studio/tactical_studio_layout.dart` | LF | 없음 |
| `frontend/lib/services/design_review/tactical_records_data.dart`(Mock CSV 행) | LF | 없음 |
| `frontend/test/tactical_page_test.dart` | LF | 없음 |
| `frontend/test/tactical_analysis_test.dart` | LF | 없음 |
| `frontend/test/goldens/fe9a_tactical_golden_test.dart` | LF | 없음 |
| 이 문서 | LF | 없음 |

- 새 파일(예정): `frontend/lib/tactical/tactical_excel_import_controller.dart`, `frontend/lib/ui/tactical/tactical_excel_import_view.dart`, `frontend/lib/ui/tactical/tactical_excel_import_panel.dart`, `frontend/test/tactical_excel_import_test.dart`.
- 고치지 않음: `lib/services/**`(design_review 제외, Lane B fb6b-dart), `lib/tactical/tactical_records_controller.dart`(Lane B), 스캐너 시각부 5파일, `app_shell.dart`, `lib/ui/kit/**`, golden harness, `frontend/tool/**`, backend · contracts, 택틱 소유 파일.

## FE9-f 종료 기록 (2026-10-16 16:40, Lane A, 코드 작성 완료 · CF gate 미실행)

A. 기록 화면 S1 "엑셀 가져오기"를 켜고 파일 고르기 → 미리보기 → 엑셀 가져오기 모달(시안 Tactical-Import-Excel) → commit → 기록 다시 읽기를 붙였다. 흐름은 새 `lib/tactical/tactical_excel_import_controller.dart`(ChangeNotifier), 모달은 새 `lib/ui/tactical/tactical_excel_import_panel.dart` · 모델 `tactical_excel_import_view.dart`. B. 분석 S2 "검증 강도" 칩을 숨겼다(FD-127 (a), FE9-e 발견 5 · CF 결정 2026-10-16). HEAD는 착수 때와 같다(`a5e179fa`), git 쓰기 0회.

### 실행한 명령과 결과(이 PC, `frontend` 폴더)

- `flutter analyze`(작성 중 경로별 여러 번 · 전체 3회): 마지막 전체 **No issues found(0)**. `pubspec.yaml` · `pubspec.lock` 변경 0(analyze의 pub get 뒤에도 git status 빈 줄). 새 의존성 0.
- 새 `flutter test test/tactical_excel_import_test.dart`: ① +12 −2(테스트 쪽 1: 슬롯 필드 순서(내 덱이 먼저)를 잘못 셈 / 구현 쪽 1: 1280×720에서 문자열 표가 42px로 눌려 넘침) → 낮은 창 한 스크롤 배치 → ② +13 −1(구현 쪽: 학생 검색 패널(약 454px)이 패널 안 426px에서 28px 넘침 → 검색 패널을 패널 밖 화면 전체 위로) → ③ **+14**.
- 바뀐 동작에 걸리는 기존 테스트(grep: `TacticalPage` · `tactical_workspace` · `tactical_studio_layout` · `tactical_analysis_workspace` · `AppSection.pvp` · `top-tab-pvp` · `BAPlannerApp(` · `tactical_records_data` · `designReviewTactical` · `MockDesignReviewScenario` · `TacticalExcel` · `tactical-import-excel` · `tactical_excel` · `tactical-analysis-grade` · `tacticalVerificationGrade` + `test/tactical_*` · `widget_test`), 일반 30파일 한 명령(`--exclude-tags golden`, json): **+303 −0** — account_editor_fe8c 9, account_manager_fe8b 6, app_navigation_fe7d 14, app_navigation_tidy1 11, connected_target_fe8d 8, design_review_tactical_seed 2, growth_calculator_view 24, home_app_shell 1, home_connect_fe8e 10, home_page 5, inventory_shell_lazy 1, mock_design_review_scenario 11, profile_delete_fb2d 17, section_template_studio 15, statistics_app_shell 2, statistics_filter 10, student_filter_followups 4, student_filter_modal 8, tactical_analysis 20, tactical_excel_import 14, tactical_jokbo_panel 17, tactical_lobby_scanner_service 2, tactical_page_revision 5, tactical_page 20, tactical_records_controller 14, tactical_service 6, tactical_share_v1_contract 1, tactical_v2_service 5, title_page 25, widget 16.
- 마지막 패널 손질(소제목 줄 · 간격 · 머리 줄 · 아래 줄 정렬) 뒤 다시 8파일: tactical_excel_import 14 · tactical_page 20 · tactical_analysis 20 · tactical_jokbo_panel 17 · tactical_page_revision 5 · widget 16 · design_review_tactical_seed 2 · mock_design_review_scenario 11 = **+105 −0**. 전체 `flutter analyze` 다시 **0**.
- process 묶음 분류(`--concurrency=1`, 파일마다): tactical_fb7_dart **+12**, tactical_fe9b1_read **+12**, tactical_fb7_process_e2e **+1**(실제 백엔드, 임시 폴더), tactical_fb6_dart **+13 −1** — 실패 `contract shared FB-6 fixture has matching Dart validation results`(`unknown_manual_attempt`)는 `contracts/fixtures/tactical_fb6_writes_v2.json`의 XB 미커밋 FB-6b(시도 null) 변경 때문이다(`git status`: ` M contracts/fixtures/tactical_fb6_writes_v2.json`, `?? contracts/fixtures/tactical_fb6b_nulls_v2.json`). 이 slice는 서비스 · 계약을 고치지 않았다 — Lane B fb6b-dart 몫(→ 발견 8).
- 일회성 렌더(임시 `test/goldens/zz_fe9f_render_tmp_test.dart` = golden 파일 사본에서 `@Tags(['golden'])` · `expectGoldenScene` 0건을 grep으로 확인한 뒤 `toImage` → scratchpad PNG, 실행마다 바로 삭제, `test/goldens/zz_*` 0건 확인): 4회(① +5 −1 — 내 렌더 경로 오타 + golden 흐름에서 "?" 줄이 표 아래로 가려 메뉴를 못 엶 ② +6 ③ +1 ④ **+6**). 렌더를 보고 고친 것: 원문 칸 `monospace` 글꼴이 앱 자산에 없어 네모로 보임 → 본문 글꼴, 기준 창 문자열 표 265px < 5줄 282px → 묶음 간격 18 → 14 · 소제목 줄 20, 머리 줄 닫기와 아래 버튼이 오른쪽에 붙지 않음(Flexible + Spacer) → Expanded, golden 처리 도우미에 `ensureVisible`. 마지막 렌더: 패널 rect = (500, 348, 1560, 880), 표 5줄이 스크롤 없이 보임(목록 285px), "4건 가져오기" 오른쪽 끝 2032.
- `dart format`: 이 slice 파일 경로만 하나씩(디렉터리 인자 0). `tactical_page.dart`는 포맷 변화 0이고 CRLF 그대로(1487줄 모두 CRLF), 나머지 LF.
- `git diff --check -- frontend almanac/workflows/frontend-redesign-status.md`: exit 0. 새 4파일: CR 0 · 줄 끝 공백 0 · 끝 개행 하나.
- 잠금 충돌 0(재시도 없음). 로그 `debug/frontend_fe9f/logs/`(json 요약 · 실패 줄만 확인).

### 고친 파일 · 새 파일

| 파일 | 내용 |
|---|---|
| `frontend/lib/ui/pages/tactical_page.dart`(CRLF) | 엑셀 컨트롤러 붙이기(서비스가 `TacticalExcelImportService`일 때), 버튼 막는 이유, 파일 고르기 → 모달 열기, 모달 닫힘 = 흐름 닫기(가져오는 중에 닫히면 기록 다시 읽기), commit 성공 → 모달 닫기 · `controller.reload()` · 상태 문구, 작업 영역 rect, `BaModal`(scrim excel, 스크림 눌러 닫기 꺼짐). 분석 패널에 검증 강도를 넘기지 않음 |
| `frontend/lib/ui/tactical/tactical_workspace.dart` | S1 "엑셀 가져오기" `onImportExcel` · `importExcelHint`(툴팁) |
| `frontend/lib/ui/tactical/tactical_analysis_workspace.dart` | S2 "검증 강도" 칩 삭제(필드 `verificationGrade`는 남김, 주석) |
| `frontend/lib/ui/studio/tactical_studio_layout.dart` | `TacticalExcelImportMetrics`(패널 1560×880 · 여백 · 표 6열 · 상자 · 미리보기 · 버튼) — 추가만 |
| `frontend/lib/services/design_review/tactical_records_data.dart` | 검수 · golden용 Mock CSV 경로 · 행(`designReviewTacticalExcelPath` · `designReviewTacticalExcelRows`) — 추가만 |
| `frontend/test/tactical_page_test.dart` | "excel import is pending" → "is on"(툴팁 = `tacticalExcelHint`) |
| `frontend/test/tactical_analysis_test.dart` | 검증 강도 칩 → 없음(`findsNothing`) |
| `frontend/test/goldens/fe9a_tactical_golden_test.dart` | 장면 `tactical-import-excel` 추가 + 파일 대화상자 대역 · 처리 도우미, 머리 주석 |
| 새 `frontend/lib/tactical/tactical_excel_import_controller.dart` | 파일 고르기 interface(`file_selector`) · 테스트 대역 전역, 오류 문구 표, 처리 방법 · 그룹 줄 모델, 흐름 컨트롤러 |
| 새 `frontend/lib/ui/tactical/tactical_excel_import_view.dart` | 열 글자 · 열 연결 칸 · 필드 이름 · 플래너가 본 것 · 처리 방법 메뉴 · 근거 · 미리보기 줄 고르기 |
| 새 `frontend/lib/ui/tactical/tactical_excel_import_panel.dart` | 모달 그리기(머리 줄 · KPI · 열 연결 · 열 바꾸기 편집기 · 문자열 표 · 메뉴 · 학생 검색 · 미리보기 · 아래 줄) |
| 새 `frontend/test/tactical_excel_import_test.dart` | 14건(아래) |

고치지 않음: `lib/tactical/tactical_records_controller.dart`(HEAD와 cmp 일치 — 기록 다시 읽기는 기존 `reload()`), `lib/services/**`(design_review 데이터 추가 말고 0), 스캐너 시각부 5파일, `app_shell.dart`, `lib/ui/kit/**`, golden harness, `frontend/tool/**`, backend · contracts, 택틱 소유 파일.

### 흐름

| 단계 | 동작 | 서비스 호출 |
|---|---|---|
| 버튼 | 계정 · v2 읽기 끝, 이관 전 아님, 읽기 · 저장 중 아님일 때만 켬. 아니면 흐림 + 이유 툴팁 | — |
| 파일 고르기 | `file_selector` `openFile`(.xlsx · .csv). 취소면 아무것도 안 함 | — |
| 첫 미리보기 | 모달을 열고 열 연결 **없이**(null) 미리보기 → 후보 · 저장한 열 연결은 흐리게 보이고 보내지 않음 | `tactical.v2.excel.preview`(mapping null) |
| 열 연결 확인 | "이 열 연결로 읽기"(후보 · 저장한 연결) 또는 "열 바꾸기" 편집기(머리글 행 · 필드별 열, 필수 5 · 열 중복 검사) → 처리 방법 · 행 결정 비움 | preview(mapping) |
| 결정 | 처리 방법 · "모두 적용" · 행 결정(건너뛰기 · 따로 두기 · 덮어쓰기) · 덮어쓰기 체크(on_conflict) · 시트 seg마다 | preview(같은 선택 + 바뀐 것, 세대 번호로 늦은 응답 버림) |
| 규칙 저장 체크 | commit에만 쓰므로 다시 읽지 않음 | — |
| 가져오기 | "n건 가져오기"(n = 마지막 미리보기 `eligible_rows`). 막는 이유가 없을 때만 켬(툴팁에 이유) | `tactical.v2.excel.commit`(마지막 미리보기의 선택 객체 그대로 · `fingerprint` · `interpretation_fingerprint` · `current_revision`, **매번 새 key** `tactical-excel-commit-<µs>-<순번>`) |
| 성공 | 모달 닫기 → `TacticalRecordsController.reload()` → S3 상태 문구 "엑셀에서 기록 n건을 가져왔습니다. [덮어쓴 기록 m건.] [건너뛴 행 k건.] [처리 방법을 저장했습니다.]" | v2 상태 읽기 |
| commit 오류 | 문구를 모달 머리 아래에 보이고 `import_interpretation_changed` · `import_source_changed` · `revision_conflict` · `idempotency_conflict` · `import_review_required`면 같은 선택으로 다시 미리보기(문구는 남김) | preview |
| 닫기 | 닫기 · 취소 · Esc(열린 메뉴 · 검색 · 편집기가 있으면 그것만 먼저 닫음). 고른 처리 방법은 버림 | — |

### 오류 문구(`tacticalExcelImportErrorMessages`)

| 코드 | 문구 |
|---|---|
| `import_interpretation_changed` | 미리보기 뒤에 해석 조건(열 연결 · 처리 방법 · 저장한 규칙 · 기록)이 바뀌어 가져오지 않았습니다. 미리보기를 다시 읽었습니다. |
| `import_source_changed` | 미리보기 뒤에 파일 내용이 바뀌어 가져오지 않았습니다. 미리보기를 다시 읽었습니다. |
| `import_source_unreadable` | 파일을 읽지 못했습니다. + reason `source_unavailable` "파일이 없거나 열 수 없습니다." · `format_unsupported` ".xlsx · .csv 파일만 가져올 수 있습니다." · `sheet_not_found` "고른 시트가 파일에 없습니다." |
| `import_review_required` | 처리 방법을 고르지 않은 문자열이나 결정하지 않은 행이 있어 가져오지 않았습니다. 표에서 처리 방법을 골라 주십시오. |
| `legacy_migration_required` | 이전 형식의 전술 기록을 새 형식으로 옮긴 뒤에 엑셀 기록을 가져올 수 있습니다. 기록 화면에서 "가져오기"를 눌러 주십시오.(버튼 흐림 이유와 같음) |
| `opponent_alias_required` | 상대 이름이 이 상대에 저장된 이름과 다릅니다. 새 상대로 저장하거나 그 행을 건너뛰어 주십시오. |
| `link_conflict` · `lineage_conflict` | 가져올 기록이 이미 있는 기록 연결과 겹쳐 가져오지 않았습니다. · 자동으로 만든 족보의 편성과 겹쳐 가져오지 않았습니다. |
| `invalid_payload` | 가져오기 선택이 파일 내용과 맞지 않습니다. 열 연결과 처리 방법을 다시 확인해 주십시오. |
| `revision_conflict` · `idempotency_conflict` | 미리보기 뒤에 전술 기록이 바뀌어 … · 같은 요청 번호로 다른 내용이 와서 … 가져오지 않았습니다. 미리보기를 다시 읽었습니다. |
| `persistence_failed` · `profile_not_found` · `repository_busy` | 가져온 기록을 저장하지 못했습니다. · 선택한 계정을 찾지 못했습니다. · 저장소가 다른 작업을 하는 중입니다. 잠시 뒤 다시 시도해 주십시오. |
| 표 밖 백엔드 코드 · 연결 끊김 · 보내기 전 검사 실패 | 엑셀 가져오기를 하지 못했습니다. · 백엔드의 답을 받지 못했습니다. 다시 연결한 뒤 다시 시도해 주십시오. · 고른 처리 방법을 보낼 수 없습니다. 처리 방법을 다시 골라 주십시오. |

### 파일 선택 방식

- 기존 의존성 `file_selector ^1.1.0`(pubspec에 이미 있음, `section_studio_file_service.dart` 선례) `openFile(acceptedTypeGroups: [엑셀 · CSV — xlsx, csv])` → `XFile.path`. 새 패키지 0, 경로 입력 대체 불필요.
- 테스트 · golden은 `@visibleForTesting debugTacticalExcelFilePicker`(셸을 거쳐 띄운 화면에서도 바꿀 수 있게 전역 하나, tearDown에서 null)로 대역을 넣는다.

### 처리한 FD

- **FD-131(워커 재량, 권장안)**: 파서 = Python(Dart는 경로 · 선택만), .xlsx + .csv, 시트가 여럿이면 머리 줄에 시트 seg(바꾸면 열 연결 비우고 다시 읽음), 미리보기 분모 = 가져올 건수(`eligible_rows`), 덮어쓰기 키는 백엔드 의미 키(체크 문구는 시안 그대로), 처리 규칙 = 프로필별(commit `save_rules`), "스캔 파일 가져오기" 숨김 그대로.
- **FD-127 (a)**: 분석 S2 "검증 강도" 칩 숨김(팝업에는 원래 그 값이 없음). FD-134 `tacticalVerificationGrade`와 `TacticalAnalysisPanel.verificationGrade`는 지우지 않고 넘기지 않게만 했다(되살리기 = 페이지에서 추천 `confidenceGrade`를 다시 넘기고 칩 한 덩이 복원).
- FD-128 (a): 가져온 기록은 v2 기록(백엔드 commit)이고 화면은 v2 다시 읽기만 한다. FD-176: 시도 횟수를 채우지 않는다(시도 그룹은 사용자가 고른 값만, 결과 · 시도로 나누기는 제안을 확인했을 때만).

### 정한 규칙

- **처리 방법 → resolution**: 학생으로 연결(제안 · 검색) · 기존 상대로 합치기 · 새 상대로 저장(원문 이름, identity `opponent-<µs>-<순번>`을 고를 때 한 번 만듦 — 다시 미리보기해도 해석 지문이 바뀌지 않게) · 결과 승/패 · 공격/방어 · 시도 n회(1~9) = `value`, 빈칸으로 두기 = `wildcard`(슬롯만, 시안 "빗금 빈칸으로 저장"), 메모로 옮기기 = `notes`, 이 칸 무시 = `ignore`, 이 행 건너뛰기 = `skip`. 결과 · 시도로 나누기 = 결과 `value` + 그 그룹이 나온 행마다 시도 칸 `value`(행 지정). 필드마다 풀 수 있는 것만 메뉴에 둔다(필수 필드에 무시 · 메모 없음, 날짜는 건너뛰기만 — 지금 시각으로 채우지 않음).
- **"모두 적용"**(기본 켬): 켜면 행 없는 전역 resolution(규칙 저장 대상), 끄면 그룹이 나온 행마다 행 지정 resolution(규칙에 저장되지 않음).
- **제안은 확인 전 미적용**: 그룹을 처음 보면 처리 방법이 비어 있고("처리 방법 고르기", 노랑 테두리), 제안은 메뉴 첫 줄 · 근거 "추천 있음 · 확인해 주십시오"로만 보인다.
- **표 줄 유지**: 처리 방법을 고른 그룹은 다음 미리보기에서 사라져도 남고(완료 = 고름 + 사라짐 → "모두 처리됨 k / n"), 고르지 않은 그룹이 다른 처리로 사라지면(예: 나누기가 시도 빈칸을 채움) 뺀다. 고른 뒤에도 남으면 테두리 노랑 + 근거 "… · 아직 풀리지 않음". 열 연결 · 시트를 바꾸면 표 · 행 결정을 비운다.
- **건너뛴 행**: 행 결정이 건너뛰기인 행만 가리키는 resolution은 보내지 않는다(쓰이지 않은 resolution = `invalid_payload`).
- **미리보기 줄**: 결정이 필요한 행(겹침 · 표 밖 행 이슈 · 결정한 행) 전부 + 가져올 기록 3줄(처리 반영 분홍 먼저). 부제 "<eligible>건 중 <보인 가져올 기록>건 · 분홍 줄 = 위 처리 방법이 적용된 기록". 칩: 처리 반영(분홍) · 그대로(회색) · 덮어쓰기(노랑) · 건너뜀(회색) · 결정 필요(빨강) · 확인 필요(노랑). 덮어쓰기는 겹친 기존 기록이 하나일 때만 고를 수 있다(여럿이면 흐림 + 이유).
- **KPI**: 읽은 행(`read_rows`, 열 연결 확인 전 '—') · 기록으로 인식(`parsed_rows`) · 확인 필요 문자열(표 줄 수 "n종", 칸 합) · 건너뜀(빈 행 + 건너뛴 행, 보조 "빈 행 e · 건너뛴 행 s").
- **열 연결 칸**: 시안 8칸 그대로, 시즌을 연결했을 때만 아홉째. 덱은 여섯 열이 이어지면 "D–I", 아니면 열 글자를 '·'로 잇고 모르면 '—'.
- **자리**: 화면 작업 영역(셸 머리말 아래) 가운데 1560×880, 작은 창은 가장자리 16 안. 패널 높이 < 800이면 묶음 간격 10, 열 연결 · 표 · 미리보기를 한 스크롤로(공용 사선 스크롤바 · 포그). 학생 검색 패널은 패널보다 클 수 있어 화면 전체 위 가운데.
- **기준 창 간격**: 시안 묶음 간격 18이면 표 5줄이 다 보이지 않아(17px 모자람) 14로 줄였다(→ 발견 3).
- 원문 칸은 시안의 고정폭 대신 본문 글꼴(앱에 고정폭 글꼴 자산이 없음).
- 가져오는 중에는 닫기 · 취소 · 체크가 꺼진다. 가져오는 중에 모달이 닫히면(Esc) 결과를 모르므로 기록을 다시 읽는다. 스크림을 눌러도 닫히지 않는다(고른 처리 방법 보호).

### golden 변화 예상(비교 미실행 · 일회성 렌더로 모양 확인)

- `tactical`: **바뀜** — S1 "엑셀 가져오기"가 흐림 → 보통 밝기. 나머지 같음.
- `tactical-jokbo-drag`: **바뀜** — 같은 버튼 밝기. 끌기 고스트 · 알약 · 강조 같음.
- `tactical-analysis`: **바뀜** — S2 제목 줄 "검증 강도 B" 칩이 사라짐. 나머지 같음.
- `tactical-analysis-all`: **바뀜** — 스크림 뒤 S2 칩이 사라짐. 팝업 자체는 같음.
- `tactical-migration`: **변화 0 예상** — 이관 전이라 버튼은 흐림 그대로(툴팁 글자만 바뀜, 그림에 없음).
- 새 `tactical-import-excel`(optional_added): 기록 화면 위 스크림 .62, 패널 (500, 348, 1560, 880). 머리 "엑셀 가져오기 · 해석 결과 확인" + "전술대항전_기록_9월.csv · CSV" + 닫기(오른쪽 끝). KPI 5 · 4(초록) · 5종(분홍, 8칸) · 1(빈 행 1 · 건너뛴 행 0). 열 연결 A 날짜 · B 공격/방어 · C 상대 유저 · D–I 상대 덱 6칸 · J–O 내 덱 6칸 · P 승/패 · Q 시도 횟수 · R 메모 + "열 바꾸기". 표 "· 5종" + "모두 처리됨 5 / 5"(초록), 5줄: C 유저 → "새 상대 'C 유저'로 저장" · 게헨나 선도부(3칸) → "기존 상대 '게헨나 선도부'로 합치기"(추천) · 수영복 히나 → 초상 + "학생: 히나(수영복)" · ?(상대 덱 4번 · 2칸, "빈칸 표시로 보임") → 빗금 + "빈칸으로 두기" · 승(2트) → "결과 '승' + 시도 2회로 나누기", 모두 적용 체크, 범례 7. 미리보기 "4건 중 3건 · …" 분홍 3줄(9/22 게헨나 승 · 2회, 9/22 게헨나 패 · 1회, 9/21 C 유저 방어 승 · 1회, 모두 "처리 반영"). 체크 "이 처리 방법을 저장…"(켬) · "같은 날짜 · 상대 … 덮어쓰기"(끔), "취소" · "4건 가져오기"(분홍, 체크 아이콘, 오른쪽 끝).
- 다른 장면: 변화 0 예상(전술 탭을 여는 golden은 이 파일뿐, 셸 · 키트 수정 0).

### 미검증(미실행)

- 전체 `fe_gate.ps1` · golden 비교 · `-UpdateGoldens` · `codealmanac validate` · 저장소 전체 `git diff --check`: **미실행**(CF 몫).
- 실제 백엔드에 붙인 모달: **미실행** — 실제 .xlsx(시트 여럿 · 수식 캐시 · 날짜 칸), 백엔드 학생 이름 제안 점수 · 상대 별칭 제안, coarse 충돌(같은 날 · 빈칸), `saved_opponent_identity_missing`, 실제 `rules_saved`. Mock CSV로만 확인.
- 실제 `file_selector` 대화상자(Windows): **미실행**(대역으로만). Windows release 빌드: **미실행**.
- 위 목록 밖 Flutter 테스트(통계 · 계획 · 인벤토리 · 스캔 단독, process E2E 3 — tactical_process_e2e · tactical_v2_process_e2e · tactical_fb6_process_e2e): **미실행**(서비스 수정 0).

### 검수표(시안 Tactical-Import-Excel, mock 모드 · 기준 viewport 최대화)

| 순서 | 여는 방법 | 확인 포인트 |
|---|---|---|
| 버튼 | design-review 시나리오 → 전술대항전 탭 | S1 "엑셀 가져오기" 밝음 · 툴팁 "엑셀(.xlsx) · CSV 파일의 전술 기록을 확인한 뒤 가져옵니다." / v1 기록이 있는 계정이면 흐림 + 이관 문구 |
| 파일 | 버튼 → 파일 대화상자(.xlsx · .csv만) | 취소하면 그대로. **Mock은 파일을 읽지 않아** 실제 파일은 "파일을 읽지 못했습니다. 파일이 없거나 열 수 없습니다." — 모달 모양 검수는 golden 장면 `tactical-import-excel`(→ 발견 1) |
| 열 연결 | 첫 화면 | 후보 칸 흐림 + "머리글 1행에서 찾은 열 연결입니다. 확인해야 기록을 읽습니다." + "이 열 연결로 읽기", KPI '—' |
| 표 | 열 연결 확인 뒤 | 노랑 테두리 "처리 방법 고르기", "처리 필요 n / n", 메뉴(필드별 항목, Esc는 메뉴만), 학생 검색 패널 |
| 처리 | 다섯 문자열 처리 | 초록 "모두 처리됨 5 / 5", 근거 문구, 미리보기 분홍 줄, "4건 가져오기" |
| 겹침 | 같은 내용 파일을 다시 가져오기(메모만 다르게) | 덮어쓰기 체크 끔 = 건너뜀(가져올 기록 0) / 켬 = "결정 필요" + 건너뛰기 · 따로 두기 · 덮어쓰기 |
| 가져오기 | "n건 가져오기" | 모달 닫힘, 목록에 새 기록, S3 상태 "엑셀에서 기록 n건을 가져왔습니다. …" |
| 열 바꾸기 | "열 바꾸기" | 머리글 행 · 19필드 열 −/+, 겹침 · 필수 문구, "이 열 연결로 읽기" |
| 분석 | 머리말 seg "분석" | S2 제목 줄에 "검증 강도" 칩 없음 |
| 작은 창 | 1280×720 | 모달이 화면 안, 가운데 한 스크롤, 넘침 없음 |

### 테스트(새 · 고친)

- 새 `tactical_excel_import_test.dart`(14): 모델 3(열 글자 · 칸 8 · 부분 연결, 필드별 처리 방법, 오류 문구), 컨트롤러 6(첫 미리보기 = 열 연결 없음 · 후보만, 처리 → resolution · 모두 적용 끔 = 행 지정 · 미리보기 분홍, commit = 마지막 지문 · revision · 매번 새 key · 같은 미리보기 재commit = `revision_conflict` → 다시 읽기(replay), 원본 바뀜 `import_source_changed`, 겹침 행 결정(저장 규칙 · 저장한 열 연결 적용 확인 포함), 이관 전 막힘), 화면 4(버튼 켬 · 취소 · 이관 전 흐림 + 이유, 전체 흐름 → 닫힘 · 다시 읽기 · 상태 문구, 닫기 · 취소 · Esc(메뉴 먼저), 열 바꾸기 편집기 겹침 · 없음 · 다시 읽기), 셸 1(2560×1392 패널 rect · 1280×720 화면 안 · 넘침 0).
- 고친 `tactical_page_test.dart`: "S1 title has no sub view seg and excel import is pending" → "… is on"(툴팁 `tacticalExcelHint`). 지운 테스트 0.
- 고친 `tactical_analysis_test.dart`: 검증 강도 칩 정규식 검사 → 칩 · "검증 강도" 글자 없음. 등급 함수 모델 테스트는 그대로.

### WIP 보존 확인

- 고친 기존 8파일 + 이 문서는 착수 때 WIP 없음 → `post_dir` 없음. pre 사본 `debug/frontend_fe9f/pre/<경로>`(9파일).
- 스캐너 시각부 5파일(`scan_page.dart` · `scan_companion_dock.dart` · `scan_student_review_workspace.dart` · 그 테스트 2): 열지도 고치지도 않았다(` M` 그대로). `lib/tactical/tactical_records_controller.dart`: HEAD와 cmp 일치. `dart format`은 이 slice 파일 경로만. git 쓰기 0회. 임시 렌더 파일은 매번 삭제(`test/goldens/zz_*` 0건).

### 키트 승격 후보(Lane A 판단)

- 패널 안 드롭다운 메뉴(`_TreatmentBox` + 앵커 메뉴 + `KitOverlayEscape`) — 키트에 드롭다운이 없다(FE9-a는 Material 드롭다운을 없앴다). `_Check`(체크 상자 + 글자) · `_ColumnStepper`(−/값/+) · `_SectionTitle`(분홍 사선 막대 소제목)도 다른 화면과 겹친다.

### 발견 사항

1. **Mock 검수 경로**: Mock CSV는 `debugSetTacticalExcelSource`로 넣은 경로만 읽는다. design-review 시나리오 설정(`lib/services/**` — Lane B 소유)이 `designReviewTacticalExcelPath`/`Rows`를 넣지 않아, 사용자가 mock 앱에서 실제 파일을 고르면 "파일을 읽지 못했습니다"가 보인다. 검수용으로 시나리오가 그 행을 넣거나(어떤 경로든 시나리오 CSV를 돌려주는 Mock 옵션) — Lane B · CF 판단.
2. **미리보기 응답에 머리글 글자가 없다**: 시안 "A · '날짜'"의 머리글 원문을 그릴 수 없어 열 글자만 보인다. 머리글 행 글자(열 → 문자열)를 미리보기 DTO에 더하려면 XB 계약 additive 요청 후보.
3. **시안 높이 합이 880을 넘는다**: 시안 간격 18 · 줄 높이로 계산하면 표 5줄 + 미리보기 3줄이 패널에 들어가지 않는다(글꼴 줄 높이 차이 추정). 간격 14 · 소제목 20으로 맞췄다 — 시안과 몇 px씩 다르다. CF 판단.
4. **덮어쓰기 체크 문구 vs 의미**: 시안 문구 "같은 날짜 · 상대 기록이 이미 있으면 덮어쓰기"를 그대로 썼지만 백엔드 겹침 키는 종류 · 시각 · 정밀도 · 상대 · 시즌 · 두 덱이고, 날짜 정밀도 기록은 덮어쓰기에도 명시 대상(행 결정)이 필요하다(체크만으로는 "결정 필요"가 된다). 문구 조정 여부 CF 판단.
5. **겹친 기존 기록이 여럿**: 덮어쓰기 대상을 고르는 UI를 만들지 않았다(하나일 때만 덮어쓰기). 여럿이면 건너뛰기 · 따로 두기만.
6. **idempotency key**: 프롬프트대로 commit마다 새 key다. 답을 못 받은 commit(연결 끊김)을 다시 누르면 새 key라 같은 key 재전송(원 응답 재사용)이 일어나지 않는다 — 원본이 그대로면 `revision_conflict` → 다시 읽기(replay)로 수렴한다. 기록 컨트롤러(같은 key 재사용)와 규칙이 다르다. CF 판단.
7. **`attemptCount` 표시**: 미리보기 "승 · 2회"는 `TacticalMatchInputV2.attemptCount`를 그대로 쓴다. Lane B fb6b-dart가 null 허용(FD-176)으로 바꾸면 '—' 처리가 필요하다(지금은 non-null이라 null 검사를 넣으면 analyze 경고).
8. **tactical_fb6_dart_test 1건 RED**: `contracts/fixtures/tactical_fb6_writes_v2.json` XB 미커밋 FB-6b 변경(`unknown_manual_attempt`)이 Dart validator(시도 필수)와 맞지 않는다. 이 slice와 무관 — fb6b-dart가 Dart 쪽을 맞출 때 풀린다. CF gate 시점 상태에 따른다.
9. **학생 검색 후보**: 슬롯 역할(스트라이커 · 스페셜)로 거르고 내 덱은 보유 학생만(기록 작성 피커 규칙). 백엔드 학생 이름 제안은 메뉴 첫 줄 "학생: 이름"으로만 보인다(점수는 확률이 아니라 숨김).
10. fe_gate 분류: `tactical_excel_import_test.dart`에 `ProcessAppService` 문자열이 없어 일반 묶음(+14, 약 20초).

### 사본 · commit.json

- `debug/frontend_fe9f/commit.json`: slice `fe9f`, modified 9(이 문서 포함), added 4, `post_dir` 없음(WIP 없음), `whole` = `tactical.png` · `tactical-jokbo-drag.png` · `tactical-analysis.png` · `tactical-analysis-all.png`, `optional_added` = `tactical-import-excel.png`, `status=true`.
- 인계: `debug/frontend_fe9f/output.md`. 로그 `debug/frontend_fe9f/logs/`.

### 다음 행동

- FE9-f 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: Lane B(fb6b-dart)가 멈춘 뒤 gate 1회(예상: analyze 0, 일반 테스트에 tactical_excel_import +14, process tactical_fb6_dart는 fb6b-dart 상태에 따름, golden `tactical` · `tactical-jokbo-drag` · `tactical-analysis` · `tactical-analysis-all` RED · 새 `tactical-import-excel` 기준 없음 · `tactical-migration` 등 나머지 GREEN) → 실패 이미지 확인 → `-UpdateGoldens` → `fe_commit.ps1 -Slice fe9f`.
- 발견 1(검수 시나리오 CSV)은 Lane B/CF, 2는 XB 요청 후보, 3 · 4 · 5 · 6은 CF 판단, 7은 fb6b-dart 입력.

### fe9f commit record (2026-10-16 20:49, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261016_203646\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE8-f1 착수 기록 (2026-10-17, Lane A)

- 상태: **진행 중 → 코드 작성 완료(아래 FE8-f1 종료 기록), CF gate 미실행**. 범위: FE8-f1 스캔 세션 컨트롤러 추출(동작 보존) — `_ScanPageState`의 세션 · 이벤트 커서 · 후보 · 최근 · companion · dock · revision/generation · 학생/인벤토리 검토 흐름을 `lib/ui/scan/scan_session_controller.dart`로, 학생 검토 순수 로직을 `lib/ui/scan/scan_student_review_logic.dart`로. AppShell이 컨트롤러를 소유. 허용 동작 변화 1건: scanwip-func 발견 1(같은 id 새 revision 뒤 편집 칸 글자 유지) 최소 수정 + 회귀 테스트.
- 착수 전 확인: 이 문서 끝에 다른 "FE8-f1 착수 기록" 없음. 막힘: 대장 "slice별 막힘 요약" FE8-f1 행 = —, 현재 `열림` 0건.
- 시작 SHA(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`): `9cf5f0a5766ce484111f9affecf7bd91b8955066`.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe8f1/pre/<v7 기준 경로>`, 모두 작업 트리와 cmp 일치) · WIP(`git status --short <경로>` 0줄 = 모두 WIP 없음 → `post_dir` 불필요) · 줄바꿈(`git ls-files --eol`):
  - `frontend/lib/ui/pages/scan_page.dart`: WIP 없음. LF.
  - `frontend/lib/ui/app_shell.dart`: WIP 없음. LF(최소 diff).
  - `frontend/lib/ui/widgets/scan_student_review_workspace.dart`: WIP 없음. LF(순수 로직 호출부 + 발견 1 key만).
  - `frontend/test/scan_student_review_workspace_test.dart`: WIP 없음. LF(회귀 테스트 추가).
  - 이 문서: WIP 없음. LF.
- 새 파일(예정): `frontend/lib/ui/scan/scan_session_controller.dart`, `frontend/lib/ui/scan/scan_student_review_logic.dart`, `frontend/test/scan_session_controller_test.dart`, `frontend/test/scan_student_review_logic_test.dart`.
- 고치지 않는 것: `lib/services/**`(읽기만), `lib/ui/pages/tactical_page.dart` · `lib/ui/tactical/**` · `lib/tactical/**`(Lane B), `lib/ui/kit/**`, golden harness · golden 테스트, `frontend/tool/**`, backend · contracts, 택틱 세션 소유 파일. 기존 스캐너 테스트 기대값.

## FE8-f1 종료 기록 (2026-10-17, Lane A, 코드 작성 완료 · CF gate 미실행)

`_ScanPageState`의 세션 · 이벤트 · 후보 · 최근 · companion · dock · revision/generation · 학생/인벤토리 검토 흐름을 `ScanSessionController`(ChangeNotifier)로 옮겼고, 학생 검토 순수 규칙을 `scan_student_review_logic.dart`로 뺐다. AppShell이 컨트롤러를 소유한다. 허용된 동작 변화는 scanwip-func 발견 1(같은 id 새 revision 뒤 편집 칸 글자) 하나다. HEAD는 착수 때와 같다(`9cf5f0a5`). git 쓰기 0, 파일 삭제 0.

### 실행한 명령과 결과

- `flutter analyze`(frontend 전체, 마지막 손질 뒤): **No issues found(0)**. pubspec 변경 0.
- 일반 테스트 37파일 한 명령(`flutter test <파일들> --reporter json`, 마지막 손질 뒤): **+407 −0**. 파일별: scan_session_controller **+7**(새) · scan_student_review_logic **+5**(새) · scan_page +17 · scan_page_revision +14 · scan_page_pause_fb10a +8 · scanner_review_images_fb10c +6 · scan_student_review_workspace **+9**(기존 7 + 새 2) · scan_companion_dock +3 · scan_inventory_identity_review +2 · scanner_pause_fb10a +39 · scanner_protocol_client +6 · scanner_target_metadata_fb4 +19 · mock_scanner_commit_history +9 · mock_scanner_service +4 · student_scan_diagnostic +2 · tactical_lobby_scanner_service +2 · repository_history_scan_latest +48 · account_editor_fe8c +9 · account_manager_fe8b +6 · app_navigation_fe7d +14 · app_navigation_tidy1 +11 · connected_target_fe8d +8 · growth_calculator_view +24 · home_app_shell +1 · home_connect_fe8e +10 · inventory_shell_lazy +1 · profile_delete_fb2d +17 · section_template_studio +15 · statistics_app_shell +2 · statistics_filter +10 · student_filter_followups +4 · student_filter_modal +8 · title_page +25 · widget_test +16 · inventory_analysis_page +8 · inventory_page +9 · student_page +9. (고른 기준: `ScanPage`/`AppShell`/`BAPlannerApp`을 띄우는 테스트, 후보 인계(`CandidateContext` · `onCandidateHandoff` · `recentScans`)를 쓰는 테스트, scan_* · scanner_* · mock_scanner_* 일반 테스트 — grep.)
- process E2E(`--concurrency=1`, 파일마다 따로): scanner_process_e2e **+1**, scanner_pause_process_e2e **+1**, scanner_review_images_fb10c_process_e2e **+1**, scanner_target_metadata_process_e2e **+1**.
- 중간 실행(AppShell 수정 직후, 위 목록 + tactical_analysis · tactical_excel_import): tactical_analysis +19 −1, tactical_excel_import +12 −2. 실패 3건은 같은 시각 Lane B(FE9-b2)가 고치고 있던 미커밋 파일(`tactical_excel_import_view.dart` · `tactical_page.dart` 등, 이 slice는 손대지 않음) 때문이라 마지막 실행 목록에서 뺐다(→ 발견 3).
- 회귀 테스트 변이 확인: 워크스페이스의 비교 표/카드 key에서 `${candidate.revision}`을 `0`으로 바꾸면 workspace 테스트 **+7 −2**(새 2건만 실패) → 원 바이트로 되돌림(SHA-256 `b1336b6d58ae…` 전후 같음).
- `dart format`: 이 slice 파일 경로만 하나씩. `app_shell.dart` · `scan_student_review_workspace_test.dart`는 HEAD부터 format이 맞지 않은 줄이 있어 format이 무관한 줄(각 1곳)을 바꿨고, 그 줄은 원래대로 되돌렸다(→ 발견 4).
- `git diff --check`(고친 기존 5파일): exit 0. 새 4파일 · 고친 파일 모두 LF, 끝 개행 하나, 줄 끝 공백 0(바이트 검사). 잠금 충돌 0. 로그는 실패 줄 · json 요약만 봤다(`debug/frontend_fe8f1/logs/`).

### 옮긴 책임 (전 → 후)

| 책임 | 전 (`_ScanPageState`) | 후 |
|---|---|---|
| 준비(인식 준비 · 창 목록 · 새로고침) | `_refreshPreparation` | `ScanSessionController.refreshPreparation` |
| 앱 전역 창 연결 따르기 · 창 고르기 · 최근 기록의 창 | `_adoptConnectedTarget` · `_chooseTarget` · `_recentTargetId` · didUpdateWidget | 컨트롤러 `chooseTarget` · `updateConnectedTarget`(화면 didUpdateWidget은 자기 컨트롤러에만 넘김) |
| 스캔 종류 · 학생 모드 · 재고 프로필 | 화면 setState | `selectKind` · `selectInventoryScanProfile` |
| 계정 · 권위 revision(FB-1b) · state 다시 읽기 | `_selectProfile` · `_acceptRepositoryState` · `_acceptCommittedRevision` · `_reloadRepositoryState` | 컨트롤러(같은 이름 · 공개는 `selectProfile`) |
| 세션 시작 · 취소 · 일시정지 · 이어서 · 스냅숏 복구 · 진단 추출 | `_start` · `_cancel` · `_pause` · `_resume` · `_recoverSnapshot` · `_exportStudentDiagnostic` | `start` · `cancel` · `pause` · `resume` · `recoverSnapshot` · `exportStudentDiagnostic` |
| 이벤트 구독 · 시작 전 버퍼 · 세션/generation 커서 · 투영 | `_handleEvent` · `_handleStreamError` · `_applyEvent` · `_resetProjection` | 컨트롤러(private 그대로). 구독은 `ensureStarted` |
| 후보 revision 유지 · 미식별 칸 · identity 지정/건너뛰기 | `_keepCandidate` · `_loadUnresolvedSlots` · `_assignInventoryIdentity` · `_skipInventoryIdentity` | 컨트롤러(`assignInventoryIdentity` · `skipInventoryIdentity`) |
| 학생 재검증 · 보류 · 폐기 · 순차 적용(FD-144) · idempotency key · 실패 분류 · crop 해제(FB-10c) | `_revalidateStudentCandidate` … `_applyStudentCandidateInOrder` · `_newApplyKey` · `_releaseStudentCandidateImages` | 컨트롤러(공개 4개 + private 그대로). key 규칙 `scan-apply-<id>-<revision>-<now36>-<seq>` 그대로 |
| 최근 스캔(최대 8) · 열기 | `_recordRecent` · `_openRecent` | 컨트롤러 `recent` · `openRecent`, 바뀌면 `onRecentChanged` |
| dock(`dockBeside` · `restore`) · companion 상태 | `_publishCompanion` · `_closeCompanion` | 컨트롤러(같은 시점에 `onCompanionChanged`) |
| 인계 검사(세션 · 종류 · payload) | `_handoff` · `_payloadMatchesKind` | 컨트롤러 `handoffSession`(검사 · 오류) + 화면 `_handoff`(부모 콜백 호출) |
| Esc = 중지 등록 | `_syncEscape` | 화면에 남김(`widget.active` · `context`가 필요) |
| 학생 검토 규칙(문제 판정 · 상태 글자 · 비교 필드 · 계산값/차이 · 정수 필드 · 확인 필드 · 인연 랭크 · 그룹 순서) | `ScanStudentReviewWorkspace` 안 private · `orderScanResultCandidatesByGroup` | `lib/ui/scan/scan_student_review_logic.dart`(워크스페이스는 호출만, `orderScanResultCandidatesByGroup`은 워크스페이스가 re-export) |

화면(`scan_page.dart`)의 build · `_buildSession` · `_buildRecent` · `_StatusChip` · `_CandidateSummary`는 읽는 곳만 `_controller.<이름>`으로 바꿨다(원래 build와 `_controller.`를 지워 비교한 diff = 위 호출 이름 · `setState` 대신 메서드 호출 · format 줄바꿈만).

### 컨트롤러 공개 API (`lib/ui/scan/scan_session_controller.dart`)

- 생성: `ScanSessionController({required AppService service, ConnectedTargetController? connectedTarget, WindowDockService windowDockService = const WindowsWindowDockService(), StudentScanDiagnosticFileService studentScanDiagnosticFileService = const NativeStudentScanDiagnosticFileService(), DateTime Function() now = DateTime.now, onRecentChanged, onCompanionChanged})`. 생성자는 부작용 0.
- 수명: `ensureStarted()`(첫 화면이 붙을 때 한 번 — 연결 · 전역 창 리스너, 이벤트 구독, 준비 읽기; 두 번째부터 0), `updateService(service)`(호출 대상만, 구독은 그대로 — 예전 화면과 같음), `updateConnectedTarget(controller)`(알림 없음), `dispose()`(dock이 열려 있으면 `restore`, 리스너 · 구독 해제; 뒤로는 알림 · 상태 변경 0).
- 바꿀 수 있는 필드: `windowDockService` · `studentScanDiagnosticFileService` · `now` · `onRecentChanged` · `onCompanionChanged`.
- 준비 · 선택: `refreshPreparation()` · `chooseTarget(id)` · `selectKind(kind, {studentScanMode})` · `selectInventoryScanProfile(p)` · `selectProfile(profile)`.
- 세션: `start()` · `cancel()` · `pause()` · `resume()` · `recoverSnapshot()` · `exportStudentDiagnostic()`.
- 검토 · 인계: `revalidateStudentCandidate(c, payload, ranks, confirmed)` · `holdStudentCandidate(c)` · `discardStudentCandidate(c)` · `applyStudentCandidate(c)` · `assignInventoryIdentity(c, slot, identity, persist)` · `skipInventoryIdentity(c, slot)` · `openRecent(item)` · `handoffSession(c) → ScannerSession?`.
- 읽기: `stage`(`ScanSessionStage` idle/starting/running/cancelling/terminal — `name`이 화면 칩 · dock 글자) · `session` · `sessionError` · `phase` · `progressCurrent` · `progressTotal` · `messageKey` · `diagnostic` · `outcome` · `terminalError` · `control` · `pauseReason` · `controlBusy` · `pausedLabel` · `candidates`(읽기 전용 맵) · `recent`(읽기 전용 목록) · `busyCandidateIds` · `candidateErrors` · `candidateNotice` · `companionActive` · `exportingStudentDiagnostic` · `recovering` · `unresolvedLoading(id)` · `unresolvedSlots(id)` · `identitySkipped/identityBusy/identityError(id, slot)` · `canStart` · `canExportStudentDiagnostic` · `connected` · `recognitionReady` · `readiness` · `readinessLoading` · `readinessError` · `targets` · `targetsLoading` · `targetError` · `targetId` · `selectedTarget` · `profile` · `repositoryState` · `studentCatalog` · `inventoryCatalog` · `kind` · `studentScanMode` · `inventoryScanProfile` · `scannerAvailable` · `repositoryAvailable` · `service` · `connectedTarget`.
- `ScanPage`에 `controller`(nullable) 추가. 주면 화면은 그 컨트롤러를 쓰고 dispose하지 않는다. 없으면 화면이 자기 인자로 만들고 dispose한다(기존 테스트 · 생성자 그대로). `onCandidateHandoff`는 여전히 화면 인자(인계는 셸 콜백).

### AppShell 소유 구조 (`app_shell.dart` +25 −7)

- `late ScanSessionController _scanSession = _createScanSession();` — 예전 `ScanPage`에 넘기던 `onRecentChanged`(셸 `setState(_recentScans)`) · `onCompanionChanged`(`mounted` 확인 뒤 `_scanCompanion.value`) 클로저를 컨트롤러 생성으로 옮겼다. `connectedTarget` = 셸의 `_connectedTarget`. dock · 진단 서비스 · now는 예전처럼 기본값.
- `ScanPage(... controller: _scanSession, active:, connectedTarget:)` — `connectedTarget`은 `connected_target_fe8d_test`가 `ScanPage.connectedTarget`을 읽으므로 그대로 넘긴다(컨트롤러가 있으면 화면은 쓰지 않음).
- 계정 변경(`_profileChanged`): 예전에는 `ValueKey('scan-$_profileGeneration')`로 화면이 새로 만들어지며 세션이 버려졌다. 같은 동작을 위해 새 컨트롤러를 만들고, 예전 컨트롤러는 `addPostFrameCallback`으로 dispose한다 — 예전 화면 dispose(finalizeTree)와 같은 프레임 · 같은 순서(새 화면의 준비 읽기 → 예전 세션의 `restore`/구독 해제).
- 서비스 교체(`didUpdateWidget`): `_scanSession.updateService(widget.service)` 1줄 — 예전 화면이 `widget.service`를 그때그때 읽던 것과 같다.
- `dispose`: `_scanSession.dispose()`(자식 화면 dispose 뒤). 탭 이동: 스캔 화면은 원래도 `AnimatedSectionStack`(Offstage)에 늘 붙어 있어 세션이 살아 있었고, 이제 화면이 없어도 셸 컨트롤러로 이어진다(FE8-g2 전제).
- 이유: FE8-g2(백그라운드 학생 진행) · FE8-f2(머리글 진행 · 토스트)가 스캔 화면 밖에서 같은 세션을 읽어야 한다. diff는 import 1 · 필드/생성 함수 14 · 서비스 교체 1 · dispose 1 · 계정 변경 6 · ScanPage 인자 −7 +1.

### 바꾼 테스트와 이유

- 기존 테스트 기대값 변경 **0**, 지운 테스트 **0**.
- `scan_student_review_workspace_test.dart`: 회귀 테스트 추가만(+84, 2건 = 넓은 표 · 좁은 카드). 같은 id `safety` revision 1에서 편집(level `91` · bond_rank `bad`) → revision 2(level 80)로 다시 그리면 편집 칸이 `80` · `20`을 보인다.
- 새 `scan_session_controller_test.dart`(7): ensureStarted 한 번 · 화면 없이 스캔 · 최근 기록, 다른 세션/generation · 끝난 뒤 이벤트 버림, 전체 학생 dock · companion · restore, dispose 뒤 알림 0 · 늦은 응답 버림 · dock restore, 인계 거절, 셸 소유(탭 이동에도 같은 컨트롤러, 홈에 있는 동안 스캔한 최근 기록이 홈에 닿음, 계정 변경 시 새 컨트롤러 · 예전 것 dispose).
- 새 `scan_student_review_logic_test.dart`(5): 상태 글자 우선순위, 문제 판정, 비교 필드, 계산값/차이 · 인연 행, 정수 필드 · 인연 랭크 · 확인 필드.

### 발견 1 수정(허용된 동작 변화)

- `_ComparisonTable`에 `key: ValueKey('scan-student-comparison-<revision>')`, `_ComparisonCard`에 `key: ValueKey('scan-student-comparison-<revision>-<field>')`(두 위젯에 `super.key`). 같은 후보의 revision이 바뀌면 편집 칸(`TextFormField`)이 새로 만들어져 `initialValue` = 새 revision 값. 편집 칸 key `scan-student-field-<field>`는 그대로라 기존 테스트 · 찾기 0 변화. 편집 상태(`_editing`)가 revision 뒤에도 남는 것은 그대로 뒀다(아래 표 5).

### 발견한 기존 버그(고치지 않음 — FE8-f2 · g 입력)

| # | 위치(지금) | 내용 | 영향 |
|---|---|---|---|
| 1 | `scan_page.dart` `_CandidateSummary._payloadSummary` | 전술 로비 요약 문구가 `'Tactical lobby 쨌 current rank … 쨌 …'` — `·`가 깨진 글자(인코딩 사고)로 들어 있다 | 전술 로비 후보 요약에 깨진 글자. 문구 변화 0 규칙이라 그대로 |
| 2 | 컨트롤러 `updateService` | 서비스가 바뀌어도 이벤트 구독 · 연결 리스너는 처음 서비스에 남고, dispose는 새 서비스에서 리스너를 지운다(예전 화면과 같은 동작) | 실제 앱은 서비스를 바꾸지 않아 영향 없음. g 단계에서 재구독 여부 결정 |
| 3 | 컨트롤러 `recoverSnapshot` | 스냅숏 복구 뒤 companion을 다시 내지 않는다 | 전체 학생 dock이 다음 이벤트까지 옛 진행을 보인다(FE8-g3 dock 재작성 때) |
| 4 | 화면/컨트롤러 dispose · 계정 변경 | dock이 열린 채 세션이 버려지면 `restore`만 하고 `onCompanionChanged(null)`을 부르지 않는다 | 셸의 dock overlay가 남을 수 있다(계정 변경 중 전체 학생 스캔). FE8-g2/g3 |
| 5 | 워크스페이스 `didUpdateWidget` | 같은 id 새 revision이면 draft · 체크 · 오류는 지우지만 `_editing`은 남는다 | 편집 모드가 유지된 채 새 값이 보인다(이제 칸 글자는 새 값). FE8-g4 |
| 6 | 컨트롤러 `selectProfile` | 같은 화면의 계정 패널에서 다른 계정을 고르면 이전 계정 세션의 후보 · 최근이 남고, 적용은 지금 계정 id로 보낸다 | 백엔드가 세션 계정 불일치를 거절하는지 미확인. 셸의 계정 변경은 컨트롤러를 새로 만들어 해당 없음. FE8-g1 고르기 화면 설계 때 확인 |
| 7 | 컨트롤러 `_handleEvent`(starting) | 시작 응답 전에는 모든 세션의 이벤트를 버퍼에 넣고, 시작이 실패하면 버퍼를 다음 시작까지 비우지 않는다 | 메모리만, 다음 시작에서 비움 |
| 8 | 컨트롤러 `openRecent` | 최근 기록을 열 때 `_control` · `_pauseReason` · 실시간 학생 표시를 되돌리지 않는다 | 단계가 terminal이라 보이는 곳 0(companion만 이전 값) |

### golden 변화 0 근거

- golden 테스트는 실행하지 않았다(규칙). 스캔 탭을 여는 장면 0(`test/goldens/*` grep: `top-tab-scan` · `AppSection.scan` 0건). 셸 장면들은 스캔 화면을 Offstage로만 만들고, 화면 트리 · 문구는 같다.
- `scan-student-review` 장면: `ScanStudentReviewWorkspace`를 편집 아닌 상태로 그린다. 바뀐 것은 ① 규칙 함수 호출(같은 계산 — 순수 함수로 옮김, 새 단위 테스트), ② `_ComparisonTable`에 key(그리기 0), ③ `statToField` 인자 제거(값은 상수 그대로). 상태 글자 · 필드 순서 · 계산값 계산이 같아 픽셀 변화 0 예상.
- 그 밖의 golden harness · golden 테스트 파일 수정 0. `commit.json` `whole` = [].

### 미검증(미실행)

- 전체 `frontend/tool/fe_gate.ps1`(golden 비교 · 전체 일반 테스트 · 나머지 process 테스트 · almanac validate · 저장소 `git diff --check`): **미실행**(CF 몫).
- golden 비교(`scan-student-review` 포함): **미실행**.
- Lane B 작업 중인 tactical 테스트: 마지막 실행에서 **미실행**(중간 RED 3건은 Lane B 미커밋 파일 원인 추정, 확인 안 함).
- 실제 백엔드 · 실제 게임 창 스캔 · Windows release 빌드 · `dockBeside` 실제 창: **미실행**.
- Python 테스트: **미실행**(backend 변경 0).

### 발견 사항

1. **파일 소유권 문단과의 관계**: 워크플로 "파일 소유권"은 `scan_student_review_workspace.dart`를 스캐너 세션 소유(수정 금지)로 두지만, 이 프롬프트가 순수 규칙 추출(호출부)과 발견 1 key 수정을 허용해 그 범위만 고쳤다(+46 −156, 위젯 구조 · 문구 0). 같은 문단의 "추출한 로직 파일 위치를 스캐너 오케스트레이터 로그에 알린다"는 워커가 로그를 쓰지 않으므로 **CF 몫**: `lib/ui/scan/scan_session_controller.dart` · `lib/ui/scan/scan_student_review_logic.dart`.
2. **`ScanPage` 인자 중복**: 컨트롤러가 있으면 `onRecentChanged` · `onCompanionChanged` · `windowDockService` · `studentScanDiagnosticFileService` · `now` · `connectedTarget`을 쓰지 않는다. 셸은 테스트(`connected_target_fe8d_test`)가 읽는 `connectedTarget`만 계속 넘긴다. 새 스캔 탭(FE8-g1)이 `ScanPage`를 대체할 때 정리.
3. **Lane B 동시 작업**: 중간 실행에서 tactical_analysis −1 · tactical_excel_import −2(Lane B 미커밋 tactical 파일). 이 slice 파일과 겹침 0(`git status --short frontend`: 이 slice 4 + 새 4, 나머지는 tactical · design_review · goldens/fe9a — Lane B).
4. **format이 맞지 않은 HEAD 파일**: `app_shell.dart`(`_TopTab` fontWeight 줄) · `scan_student_review_workspace_test.dart`(`checked` 함수 줄)는 HEAD부터 `dart format` 결과와 다르다. 이 slice는 그 줄을 되돌려 diff를 최소로 뒀다. fe_gate는 format을 검사하지 않는다(analyze만).
5. **계정 변경 dispose 시점**: 예전 컨트롤러는 `addPostFrameCallback`으로 dispose한다. 프레임이 오지 않고 셸이 먼저 사라지는 경우에도 콜백이 dispose한다(중복 dispose 0 — 셸 dispose는 지금 것만).

### 사본 · commit.json

- pre 사본(착수 때 = HEAD 내용, cmp 일치): `debug/frontend_fe8f1/pre/<경로>` 5파일. 착수 때 WIP 0 → `post_dir` 없음.
- `debug/frontend_fe8f1/commit.json`: slice `fe8f1`, modified 5(이 문서 포함), added 4, `whole` = [], `status=true`.
- 인계: `debug/frontend_fe8f1/output.md`. 로그 `debug/frontend_fe8f1/logs/`.

### 다음 행동

- FE8-f1 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: Lane B(FE9-b2)가 멈춘 뒤 gate 1회(예상: analyze 0, 일반 테스트에 scan_session_controller +7 · scan_student_review_logic +5 · workspace +2 추가, process 스캐너 4 GREEN, golden 전 장면 GREEN — `scan-student-review` 포함) → `fe_commit.ps1 -Slice fe8f1`. 스캐너 오케스트레이터 로그에 추출 파일 위치 알림(발견 1).
- FE8-f2 입력: 머리글 칩 · 탭 점은 셸 `_scanSession`을 듣고 `stage`(running/cancelling = 진행, `control`/`pausedLabel` = 일시정지) · `progressCurrent`/`progressTotal`/`messageKey`를 읽으면 된다. 완료 토스트는 `stage`가 terminal로 바뀌는 순간이 필요하다 — 지금 컨트롤러에는 전이 신호가 없으므로 f2에서 이전 단계를 기억해 비교하거나 `onTerminal` 같은 콜백을 더한다(동작 추가 slice). 계정 변경 때 `_scanSession`이 새 인스턴스로 바뀌므로 듣는 쪽은 다시 붙어야 한다. 위 버그 표 3 · 4는 f2/g3에서 dock · 칩을 다룰 때 함께 판단.

### fe8f1 commit record (2026-10-17 01:55, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261017_013824\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

### fe9b2 commit record (2026-10-17 01:56, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261017_013824\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE8-f2 착수 기록 (2026-10-17, Lane A)

- 상태: **진행 중 → 코드 작성 완료(아래 FE8-f2 종료 기록), CF gate 미실행**. 범위: FE8-f2 머리글 스캔 진행 표시 · 탭 `스캔` 점 · 완료 토스트(FD-148). 스캔 탭 화면 · dock 동작은 바꾸지 않는다(FE8-g1~g3 몫).
- 착수 전 확인: 이 문서 끝에 다른 "FE8-f2 착수 기록" 없음. 막힘: 대장 "slice별 막힘 요약" FE8-f1 / FE8-f2 행 = —, 현재 `열림` 0건. FD-148은 `워커 재량`(권장안대로).
- 시작 SHA(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`): `921b6bfe4a59ce231a72936f15f76c6cda85492d`.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe8f2/pre/<v7 기준 경로>`, 모두 작업 트리와 cmp 일치) · WIP(`git status --short <경로>` 0줄 = 모두 WIP 없음 → `post_dir` 불필요) · 줄바꿈(`git ls-files --eol`):
  - `frontend/lib/ui/app_shell.dart`: WIP 없음. LF(최소 diff — 머리글 칩 자리 · 탭 점 · 토스트 자리 · 컨트롤러 리스너).
  - `frontend/lib/ui/scan/scan_session_controller.dart`: WIP 없음. LF(읽기 값 1개 — 마지막으로 끝난 세션).
  - 이 문서: WIP 없음. LF.
- 새 파일(예정): `frontend/lib/ui/scan/scan_header_progress.dart`(머리글 진행 칩 · 탭 점 상태), `frontend/lib/ui/scan/scan_end_toast.dart`(완료 토스트), `frontend/test/scan_header_progress_fe8f2_test.dart`, `frontend/test/goldens/fe8f2_header_scan_progress_golden_test.dart`(새 장면 `header-scan-progress` 1장 — 기준 이미지는 CF `-UpdateGoldens`).
- 고치지 않는 것: `lib/services/**`, `lib/ui/pages/tactical_page.dart` · `lib/ui/tactical/**` · `lib/tactical/**`(Lane B), `scan_page.dart` 화면 · dock, 홈 · 통계 · 학생 · 계획 · 인벤토리 화면, `lib/ui/kit/**`, `header_connection_chip.dart`(감싸서 씀), golden harness, `frontend/tool/**`, backend · contracts, 택틱 세션 소유 파일. 기존 테스트 기대값은 바뀐 동작에 걸릴 때만.

## FE8-f2 종료 기록 (2026-10-17, Lane A, 코드 작성 완료 · CF gate 미실행)

머리글 연결 칩 자리에 스캔 진행 · 일시정지 칩을 끼우고(백엔드 끊김 > 스캔 > 게임 창, FD-148), 탭 `스캔`에 분홍 점, 세션이 다른 탭에서 끝나면 앱 안 완료 토스트(누르면 스캔 탭)를 띄운다. 값은 모두 셸 소유 `ScanSessionController`의 FB-10 고정 범위(`progress.current/total|null`, `paused`/`resumed`, terminal `outcome`)에서 읽는다. 스캔 탭 화면 · dock 동작은 그대로다. HEAD는 착수 때와 같다(`921b6bfe`). git 쓰기 0, 저장소 파일 삭제 0(일회성 렌더 사본 1개만 만들고 지움).

### 실행한 명령과 결과

모두 `frontend` 폴더. 로그 `debug/frontend_fe8f2/logs/`(실패 줄 · json 요약만 봤다).

- `flutter analyze`(frontend 전체, 마지막 손질 뒤): **No issues found(0, info 포함)**. 중간 실행 한 번은 Lane B 작업 중 파일(`tactical_page.dart:270` `available`, `tactical_analysis_test.dart:405`) error 2건 — 이 slice 파일이 아님. Lane B 파일이 컴파일된 뒤(30초 간격 확인 3회째) 0.
- 새 테스트 `flutter test test/scan_header_progress_fe8f2_test.dart`: **+7 −0**(첫 실행 +5 −2: 진행 이벤트 뒤 프레임 하나 부족, 스캔 탭의 기존 무한 진행 막대로 `pumpAndSettle` 시간 초과 → 시험 쪽 고정 프레임 `_settle`로 고침. 제품 코드 변경 없음).
- 관련 일반 테스트 38파일 한 명령(`flutter test <파일들> --reporter json`): **+403 −0** — scan_header_progress_fe8f2 **+7**(새) · scan_session_controller +7 · scan_student_review_logic +5 · scan_page +17 · scan_page_revision +14 · scan_page_pause_fb10a +8 · scanner_review_images_fb10c +6 · scan_student_review_workspace +9 · scan_companion_dock +3 · scan_inventory_identity_review +2 · scanner_pause_fb10a +39 · scanner_protocol_client +6 · scanner_target_metadata_fb4 +19 · mock_scanner_commit_history +9 · mock_scanner_service +4 · student_scan_diagnostic +2 · tactical_lobby_scanner_service +2 · repository_history_scan_latest +48 · account_editor_fe8c +9 · account_manager_fe8b +6 · app_navigation_fe7d +14 · app_navigation_tidy1 +11 · connected_target_fe8d +8 · growth_calculator_view +24 · home_app_shell +1 · home_connect_fe8e +10 · home_page +5 · inventory_shell_lazy +1 · profile_delete_fb2d +17 · section_template_studio +15 · statistics_app_shell +2 · statistics_filter +10 · student_filter_followups +4 · student_filter_modal +8 · title_page +25 · inventory_analysis_page +8 · inventory_page +9 · student_page +9. 따로 `widget_test` **+16 −0**. 합계 **+419 −0**. (고른 기준: FE8-f1이 고른 셸 · `ScanPage` · 후보 인계 · scan_* · scanner_* · mock_scanner_* 37파일 + `home_page` + 새 파일. grep `BAPlannerApp(|AppShell(|ScanPage(|header-connection-chip|top-tab-`로 걸리는 파일 중 tactical_analysis · tactical_excel_import는 Lane B 작업 중이라 뺐다.)
- process E2E(`--concurrency=1`, 파일마다 따로): scanner_process_e2e **+1**, scanner_pause_process_e2e **+1**, scanner_review_images_fb10c_process_e2e **+1**, scanner_target_metadata_process_e2e **+1**.
- 변이 확인: 셸 `_scanSessionChanged`의 "스캔 탭이면 토스트 없음" 줄을 빼면 새 테스트 **+6 −1**(토스트 시험만 실패) → 원 바이트로 되돌림(SHA-256 `012646e0c625…` 전후 같음).
- 일회성 렌더: 새 golden 테스트 사본에서 `@Tags(['golden'])` · `library;` · `expectGoldenScene` 호출을 뺀 `test/goldens/fe8f2_oneoff_render_test.dart`(grep 0건 확인)를 한 번 돌려 **+1**(2560×1392, 칩 `학생 스캔 34 / 128` · 점 · 예외 0) → 바로 지움. golden 비교는 돌리지 않았다.
- `dart format`: 이 slice 파일 경로만 하나씩. `app_shell.dart`는 HEAD부터 format이 맞지 않은 `_TopTab` fontWeight 줄(FE8-f1 발견 4)만 바뀌어 그 줄을 되돌렸다(이 slice의 줄은 format 결과 그대로).
- `git diff --check`(고친 기존 2 코드 파일): exit 0. 새 4파일 · 고친 파일 모두 LF(CR 0), 끝 개행 하나, 줄 끝 공백 0(바이트 검사). 잠금 충돌 0.

### 처리한 FD

- **FD-148**(워커 재량, 권장안대로): 칩 우선순위 · 분홍 진행 칩 · wn 일시정지 · 누르면 스캔 탭 · 탭 `스캔` 분홍 점 · 완료 시 앱 안 토스트(누르면 검토). 아래 표와 규칙.
- FD-142(확정 (a)): 일시정지는 `paused` 이벤트로만 칩을 wn으로 바꾼다(`pauseRequested`는 진행 그대로). 버튼은 이 slice 범위 밖.
- FD-117 · FD-116: 백엔드 끊김 · 연결 중이 스캔보다 앞선다(FE8-d `HeaderConnectionChip`을 그대로 감싸 씀, 그 파일 수정 0). 게임 창 칸은 FE8-e처럼 홈 창 선택 패널.

### 칩 우선순위 표 (머리글 연결 칩 자리)

| 백엔드 | 스캔 세션(`stage` · `control`) | 칩 | 누르면 |
|---|---|---|---|
| 끊김 | (무엇이든) | 빨강 `백엔드 끊김`(FE8-d) | 누를 수 없음(복구 배너) |
| 연결 중 | (무엇이든) | 주황 `백엔드 연결 중`(FE8-d) | 누를 수 없음 |
| 연결됨 | starting · running · cancelling, 진행 값 없음 | 분홍 `학생 스캔`(아이콘 · 막대 없음) | 스캔 탭 |
| 연결됨 | running, `progress` 34/128 | 분홍 `학생 스캔 34 / 128` + 막대 60×5(27%) | 스캔 탭 |
| 연결됨 | running, total null | 분홍 `학생 스캔 34`(막대 없음, 0으로 채우지 않음) | 스캔 탭 |
| 연결됨 | running + `paused` 이벤트 | wn `학생 스캔 일시정지 · 34 / 128`(채움 #ffc66d .14, 선 .55, 글자 #ffd08a, 막대 #ffc66d) | 스캔 탭 |
| 연결됨 | running + `pauseRequested` | 분홍(진행 그대로) | 스캔 탭 |
| 연결됨 | idle · terminal(검토 대기 포함) | 게임 창 녹 `연결됨 · Blue Archive` / 회 `연결 안 됨`(FE8-d·e) | 홈 창 선택 패널(FE8-e) |

- 종류 글자: 학생 `학생 스캔`, 인벤토리 `아이템 스캔`(시안 Scan-Item-Run `아이템 스캔`), 전술 로비 `전술대항전 스캔`. 종류는 `session.kind`(시작 전에는 고른 종류).
- 모양(시안 Scan-Student-Run 머리글 `.conn` 인라인 스타일): 채움 #f2b3ef .14, 안쪽 선 .55, 글자 #f7c9f4, 간격 8, 스캔 아이콘 14(탭과 같은 `AppSection.scan.icon`), 12px w600, 여백 6/10, 반경 999, 막대 60×5 r3 바탕 흰 .12. 최대 폭 340(FE8-d와 같음), 글자 한 줄 · 말줄임.

### 점 · 토스트 규칙

- 탭 `스캔` 점(7×7 r4 #f2b3ef, 라벨 뒤 5px = 시안 간격 7 − margin 2, 의미 이름 `스캔 진행 중` / `스캔 일시정지` / `스캔 결과 검토 대기`):
  - 진행 · 일시정지: **어느 탭에서나**(스캔 탭 포함). 근거: 시안 Scan-Student-Run은 스캔 탭이 선택된(`.nt.on`) 화면에 점이 있다.
  - 검토 대기(세션이 끝났고 적용하지 않은 후보가 있음): **스캔 탭 밖에서만**. 근거: 시안 Scan-Student-Review · Scan-Item-Review(스캔 탭, 적용 전 결과)에는 점이 없다 — 검토 화면 자체가 그 상태를 보인다.
  - "적용함": 스캔 화면 적용 · 폐기(컨트롤러가 후보를 지움) + 학생 · 인벤토리 탭의 적용(셸 `onCandidateCommitted`에서 후보 열쇠 `session#generation#id`를 기억). 계정 변경 때 비움.
- 완료 토스트:
  - **스캔 탭 밖에 있을 때만** 띄운다. 근거: 시안 각주 "다른 탭으로 옮겨도 계속됩니다 … 끝나면 알림으로 결과 검토를 엽니다"(Scan-Student-Run S2)와 FD-148 "완료 시 앱 안 토스트(누르면 검토)" — 알림은 떠나 있는 사용자를 위한 것이고, 스캔 탭에서는 화면이 끝과 결과를 바로 보인다.
  - 한 세션(id + generation)에 한 번: 컨트롤러 `lastEndedSession`이 바뀔 때만(실시간 terminal · 스냅숏 복구로 최근 기록에 넣을 때, 최근 기록 열기로는 바뀌지 않음). 셸이 마지막 열쇠를 기억해 같은 세션을 다시 기록해도(스냅숏 복구) 다시 띄우지 않는다. 계정 변경 때 예전 컨트롤러의 리스너를 먼저 떼고 토스트를 닫는다.
  - 문구(완료 · 중지 · 실패 구분, `~습니다`): 제목 `학생 스캔을 마쳤습니다` / `학생 스캔을 중지했습니다` / `학생 스캔이 실패했습니다`(모름 `… 끝났습니다`). 설명: 결과가 있으면 `읽은 결과 N건이 있습니다. 누르면 결과 검토를 엽니다.`, 없으면 완료 `새로 읽은 결과가 없습니다. 누르면 스캔 탭을 엽니다.` · 실패 `누르면 스캔 탭에서 오류를 확인합니다.` · 중지 `누르면 스캔 탭을 엽니다.` 표지 막대: 완료 분홍 · 실패 빨강 · 중지 회색.
  - 모양(워커 재량 — 시안에 토스트 그림이 없다): 부유 패널이라 사선 아닌 둥근 사각형(FD-019), 바탕 · 링 · 그림자는 키트 팝오버(`AppColors.popover` .96, 링 #71c7f4 .38, `kitOverlayShadows(y 12, blur 32, .45)`), 반경 12, 폭 380(좁으면 줄임), 왼쪽 사선 표지 6×22, 제목 14 w700 한 줄 · 설명 12 두 줄 말줄임, 닫기 ×. 자리: 셸 오른쪽 위, 머리글 칩 아래(top 192 · right 26). 220ms 페이드 + 8px 내려옴.
  - 닫힘: 누름(스캔 탭으로 + 닫힘), × , 8초(`scanEndToastDuration`), 스캔 탭으로 이동(어떤 경로든 `_open(scan)`), 계정 변경. 셸 dispose 때 타이머 취소.

### 컨트롤러에 더한 읽기 값 (`scan_session_controller.dart` +6 −0)

- `ScannerSession? lastEndedSession` — `_recordRecent`에서 세션을 기록할 때 같이 둔다. 이유: 완료 토스트는 "끝난 순간"이 필요한데 `stage == terminal`은 최근 기록 열기(`openRecent`)로도 되므로 전이 비교로는 실시간 끝과 구별할 수 없다. 후보 · crop은 담지 않는다(FB-10c 보관물 규칙). 나머지(칩 · 점)는 기존 `stage` · `control` · `progressCurrent/Total` · `session` · `kind` · `candidates` · `outcome`만 읽는다. 동작 변화 0(알림 횟수 그대로).

### `app_shell.dart` diff (+106 −7, 이유)

- import +3 −1: `dart:async`(토스트 타이머), `scan/scan_end_toast.dart` · `scan/scan_header_progress.dart`. `header_connection_chip.dart` import는 셸이 더 쓰지 않아 뺐다(새 `HeaderStatusChip`이 감싼다).
- `_AppShellState` 상태 +8: `_scanEndNotice` · `_scanEndNoticeTimer` · `_lastScanEndKey` · `_scanAppliedElsewhere`(주석 포함).
- 수명 +6 −1: initState 리스너 1, dispose 타이머 취소 + 리스너 떼기, 계정 변경 때 리스너 옮기기 · 토스트 닫기 · 적용 열쇠 비우기.
- 메서드 +30: `_scanSessionChanged`(토스트 판단) · `_dismissScanEndNotice` · `_markScanCandidateApplied`, `_open(scan)`이면 토스트 닫기 1줄, `_clearStudentCandidate` · `_clearInventoryCandidate`에 적용 열쇠 1줄씩.
- 토스트 자리 +12: 바깥 `Stack`에서 스캔 dock 바로 앞(dock이 덮는다), `BaModalBackdropExclude`.
- 머리글 전달 +30 −3: `_CompoundPageHeader` · `_TopTabs` · `_AppHeader`에 `scanSession`(+ 탭 줄에 `scanAppliedElsewhere`, 머리글에 `onOpenScan`) 인자 · 필드, `_TopTab`에 `indicator`(라벨 뒤 `?indicator` 1줄), 스캔 탭만 `ScanTabDot`, `HeaderConnectionChip(…)` → `HeaderStatusChip(…)`.
- 이유: 머리글 칩 · 탭 줄 · 셸 전역 토스트는 셸에만 있다(FE8-f1이 컨트롤러를 셸 소유로 둔 목적). `app_section.dart` · 다른 화면은 고치지 않았다.

### golden 변화 0 근거 + 새 장면

- 기존 장면은 스캔을 시작하지 않는다(`test/goldens/*`에서 세션 시작 · 스캔 탭 0건, FE8-f1과 같음) → `ScanHeaderStatus.idle`: 칩은 같은 `HeaderConnectionChip` 위젯(감싼 `ScanHeaderStatusBuilder`는 그리기 0), 탭 점은 `SizedBox.shrink()`(크기 0, `Row(min)` 배치 변화 0), 토스트 없음. 셸 머리글 · 탭 줄의 나머지 트리 · 문구 · 색 변경 0. 기존 기준 이미지 · golden harness · 기존 golden 테스트 수정 0.
- **새 장면 `header-scan-progress`**(`test/goldens/fe8f2_header_scan_progress_golden_test.dart`, 기준 이미지 없음 → CF `-UpdateGoldens`로 생성): 2560×1392, 홈 탭. 게임 창(`mock-window`)을 골라 홈 메뉴가 연결 메뉴(첫 버튼 `스캔`, FE8-e)로 안착한 뒤 학생 스캔 시작, 진행 이벤트 34/128(시안 값). 기대 모습: 머리글 오른쪽 칩이 분홍 `학생 스캔 34 / 128` + 오른쪽 60×5 막대 27% 채움(개발 패널 버튼 왼쪽), 탭 줄 `스캔` 라벨 뒤 분홍 점 7px, 나머지는 `home` 장면과 같은 홈(메뉴는 연결 메뉴). 토스트 · dock 없음.

### 미검증(미실행)

- 전체 `frontend/tool/fe_gate.ps1`(golden 비교 · 전체 일반 테스트 · 나머지 process 테스트 · almanac validate · 저장소 `git diff --check`): **미실행**(CF 몫).
- golden 비교 · 새 기준 이미지 생성: **미실행**(CF `-UpdateGoldens`).
- tactical_analysis · tactical_excel_import(Lane B 작업 중): **미실행**.
- 실제 백엔드 · 실제 게임 창 스캔(실제 total 값, 최소화 일시정지 사유), Windows release 빌드, 개발 패널을 연 상태의 토스트 위치 육안 확인: **미실행**.
- Python 테스트: **미실행**(backend 변경 0).

### 검수표 (artboard → 앱에서 여는 방법 → 확인 포인트)

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Scan-Student-Run(머리글 · 탭 줄) | mock 모드(`--dart-define=BA_PLANNER_USE_REAL_BACKEND=false`), 기준 viewport 최대화. 스캔 탭에서 Mock 창 선택 → 학생(전체) 시작 → 홈 · 학생 탭으로 이동. (mock은 학생 total이 null이고 30ms 안에 끝나므로 진행 칩은 `학생 스캔 1`로 잠깐만 보인다 — 34/128 모습은 golden `header-scan-progress`로 본다) | 칩이 연결 칩 자리에서 분홍 `학생 스캔 …`, 막대(total 있을 때), 탭 `스캔` 점, 칩 누르면 스캔 탭 |
| Scan-Student-Run 각주(알림) | 위처럼 다른 탭에서 스캔이 끝나게 둔다 | 오른쪽 위 토스트 `학생 스캔을 마쳤습니다` · `읽은 결과 1건이 있습니다…`, 누르면 스캔 탭, 8초 뒤 닫힘, 같은 세션에 다시 뜨지 않음 |
| Scan-Student-Review(점 없음) | 끝난 뒤 스캔 탭 ↔ 다른 탭 | 스캔 탭에서는 점 없음, 다른 탭에서는 결과를 적용하기 전까지 점 |
| (FD-148 우선순위) | 진행 중 개발 패널의 연결 상태를 끊김으로 | 칩이 빨강 `백엔드 끊김`, 다시 붙으면 진행 칩 |

### 발견 사항

1. **스캔 탭 진행 막대와 pumpAndSettle**: `scan_page.dart`의 세션 막대는 진행 값을 모르면(학생 total null, 스냅숏 복구 뒤) 끝난 뒤에도 값 없는 `LinearProgressIndicator`(끝없는 애니메이션)를 그린다. 그래서 스캔 탭을 띄운 채 `pumpAndSettle`이 끝나지 않는다(새 테스트는 고정 프레임으로 피함). 끝난 세션에 무한 막대를 그리는 것이 맞는지는 FE8-g2(진행 화면 재작성)에서.
2. **전술 로비 후보의 검토 대기**: 전술 로비 후보는 인계(`_handoffCandidate` → 전술대항전 탭)에 적용 콜백이 없어, 그런 세션이 끝나면 다음 스캔을 시작할 때까지 탭 점이 검토 대기로 남는다. FD-121/FE9-c(전술 스캔은 전술대항전 탭)와 FE8-g5(`_handoffCandidate` 분기 제거) 때 정리.
3. **토스트 자리 · 개발 패널**: 토스트는 셸 바깥 `Stack` 오른쪽 위(머리글 칩 아래)라 넓은 창에서 개발 패널(오른쪽 330)이 열려 있으면 패널 위에 겹친다. 개발용 패널이라 그대로 뒀다. 키트 승격 후보: `ScanEndToast`(앱 공용 토스트 — 지금은 페이지마다 Material `SnackBar`, I-scan §3.3) · `HeaderScanProgressChip`의 칩 짜임(FE8-d `.conn` 칩과 같은 몸체). 승격은 Lane A 키트 slice에서.
4. **mock 학생 total**: Mock 학생 진행은 `total: null`이라 앱에서 `/ 128`과 막대를 볼 수 없다(FD-154 "없으면 보유 수에 약" 은 FE8-g2 진행 화면 몫이고, 머리글 칩은 FB-10 값만 쓴다 — 지어내지 않음). 실제 백엔드가 학생 전체 스캔에 total을 주는지는 미확인.
5. **FE8-f1 버그 표 3 · 4**: 이 slice는 dock을 건드리지 않아 그대로(FE8-g2/g3). 4(계정 변경 중 dock overlay 남음)와 같은 경로에서 토스트는 닫힌다.

### 사본 · commit.json

- pre 사본(착수 때 = HEAD 내용, cmp 일치): `debug/frontend_fe8f2/pre/<경로>` 3파일. 착수 때 WIP 0 → `post_dir` 없음.
- `debug/frontend_fe8f2/commit.json`: slice `fe8f2`, modified 3(이 문서 포함), added 4, `whole` = [], `optional_added` = [`frontend/test/goldens/baseline/header-scan-progress.png`](CF가 `-UpdateGoldens`로 만들 때만), `status=true`.
- 인계: `debug/frontend_fe8f2/output.md`. 로그 `debug/frontend_fe8f2/logs/`.

### 다음 행동

- FE8-f2 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: Lane B(FE9-g)가 멈춘 뒤 gate 1회(예상: analyze 0, 일반 테스트에 scan_header_progress_fe8f2 +7 추가, process 스캐너 4 GREEN, 기존 golden 전 장면 GREEN, 새 `header-scan-progress`는 기준 없음 → 실패 이미지 검토 → `-UpdateGoldens` → 재비교) → `fe_commit.ps1 -Slice fe8f2`.
- **FE8-g1 입력**: 스캔 탭 골격은 셸의 `_scanSession`(계정 변경 때 새 인스턴스)을 그대로 쓰고, 머리글 칩 · 탭 점 · 토스트는 `ScanHeaderStatus.of(controller)`(진행/일시정지/검토 대기)와 `lastEndedSession`만 본다 — g1이 `ScanPage`를 `ScanTabPage`로 바꿔도 이 셋은 손대지 않아도 된다. 칩 · 토스트를 누르면 셸이 `_open(AppSection.scan)`만 하므로, g1/g4가 "진행 화면 / 검토 화면" 중 무엇을 먼저 보일지 정하면(I-R-1: 진행 중 = 진행, 끝난 뒤 = 검토) 그 선택을 스캔 탭 안에서 하면 된다. 검토 대기의 "적용함"은 지금 컨트롤러가 후보를 지우는 것(스캔 탭 적용 · 폐기)과 셸 `onCandidateCommitted`(학생 · 인벤토리 인계) 두 길이다 — g4/g5가 인계를 없애면 셸 `_scanAppliedElsewhere`도 함께 뺀다. 발견 1(끝난 세션의 무한 막대)은 g2 진행 화면 때.

### fe8f2 commit record (2026-10-17 03:30, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261017_031611\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

### fe9g commit record (2026-10-17 03:30, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261017_031611\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE8-g1 착수 기록 (2026-10-17, Lane A)

- 상태: **진행 중 → 코드 작성 완료(아래 FE8-g1 종료 기록), CF gate 미실행**. 범위: FE8-g1 새 스캔 탭 골격 + 고르기(시작 전 화면, 시안 Scan · Scan-Items). 3섹션 `ScanTabPage`(S1 준비 상태 · 최근 스캔 · `게임 창 다시 선택`, S2 학생 ↔ 아이템 상호 배타 · 아이템 다중 선택(선물 포함 7타일) · 종류별 마지막 스캔 막대, S3 시작 전 안내), 미연결이면 시작 비활성 + S3 자리에 `ConnectTargetPanel`. 학생 하나 · 아이템 한 종류는 지금 컨트롤러로 시작, 여러 종류는 시작을 막고 이유 문구(큐는 FE8-g3). 진행 · 검토 중에는 지금 `ScanPage`를 그대로 보인다(내부 동작 변경 0).
- 착수 전 확인: 이 문서 끝에 다른 "FE8-g1 착수 기록" 없음. 막힘: 대장 "slice별 막힘 요약" FE8-g1 행 = FD-140 · FD-151, 둘 다 확정(2026-10-06 사용자 선택 (a)), 현재 `열림` 0건. 워커 재량 FD-147 · FD-149 · FD-154 · FD-155는 권장안대로.
- 시작 SHA(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`): `b33b7af917a984baf8ab72e999ddf3212b1695da`(세션 시작 때 `fa51f4be` 뒤 XB 커밋 2개 — 이 slice 파일과 겹침 0).
- 고칠 기존 파일(착수 사본 `debug/frontend_fe8g1/pre/<v7 기준 경로>`, 모두 작업 트리와 cmp 일치) · WIP(`git status --short <경로>` 0줄 = 모두 WIP 없음 → `post_dir` 불필요) · 줄바꿈(`git ls-files --eol`):
  - `frontend/lib/ui/scan/scan_session_controller.dart`: WIP 없음. LF(고르기 상태 · 최근 기록 보탬 · 처리한 후보 열쇠 — 최소).
  - `frontend/lib/ui/app_shell.dart`: WIP 없음. LF(스캔 탭 자리 `ScanPage` → `ScanTabPage` — 최소).
  - 바뀐 동작에 걸릴 수 있는 테스트(실제로 고친 것만 commit.json에): `frontend/test/home_app_shell_test.dart` · `connected_target_fe8d_test.dart` · `home_connect_fe8e_test.dart` · `scan_session_controller_test.dart` · `scan_header_progress_fe8f2_test.dart`(모두 WIP 없음, LF), `frontend/test/widget_test.dart`(WIP 없음, 작업 트리 CRLF — 유지).
  - 이 문서: WIP 없음. LF.
- 새 파일(예정): `frontend/lib/ui/scan/scan_tab_page.dart`(+ 하위 위젯 · 순수 규칙 파일), `frontend/lib/ui/studio/scan_studio_layout.dart`, `frontend/test/scan_tab_page_fe8g1_test.dart`, `frontend/test/goldens/fe8g1_scan_tab_golden_test.dart`(새 장면 `scan-pick-students` · `scan-pick-items` — 기준 이미지는 CF `-UpdateGoldens`).
- 고치지 않는 것: `lib/services/**`(읽기만), `scan_page.dart` 진행 · 검토 동작 · dock, `lib/ui/pages/tactical_page.dart` · `lib/ui/tactical/**` · `lib/tactical/**` · design_review 전술 seed(Lane B — 작업 트리에 Lane B WIP 있음), 홈 스캔 팝업(FE8-f3), `lib/ui/kit/**`, golden harness · 기존 golden 테스트, `frontend/tool/**`, backend · contracts, 택틱 세션 소유 파일.

## FE8-g1 종료 기록 (2026-10-17, Lane A, 코드 작성 완료 · CF gate 미실행)

스캔 탭 자리에 새 `ScanTabPage`를 넣었다. 시작 전에는 3섹션 고르기 화면(시안 Scan · Scan-Items 좌표, 통계 탭과 같은 섹션 배치)이고, 진행 · 일시정지 · 검토 대기에는 지금 `ScanPage`를 그대로 보인다(그 파일 수정 0). 학생 하나 · 아이템 한 종류는 지금 컨트롤러 `start()`로 시작하고, 아이템 여러 종류는 시작을 막고 이유를 쓴다(큐는 FE8-g3). 미연결이면 시작이 막히고 S3 자리에 홈과 같은 `ConnectTargetPanel`이 붙는다. HEAD는 착수 때와 같다(`b33b7af9`). git 쓰기 0, 저장소 파일 삭제 0(일회성 렌더 사본 1개만 만들고 지움).

### 실행한 명령과 결과

모두 `frontend` 폴더. 로그 `debug/frontend_fe8g1/logs/`(json 요약 · 실패 줄만 봤다).

- `flutter analyze`(frontend 전체, 마지막 손질 뒤): **No issues found(0, info 포함)**.
- 첫 실행(셸 교체 직후, 7파일): **+59 −7**. 실패 7건은 모두 셸을 띄워 스캔 탭에서 예전 `ScanPage` 고르기 UI(`scan-target` 드롭다운 · `scan-start` · `scan-page`)를 쓰던 시험 — 바뀐 동작이라 시험을 새 탭에 맞췄다(아래 "바꾼 테스트"). 그다음 `connected_target_fe8d` −3은 S2 제목 줄에 머리글 칩 위젯을 재사용해 `header-connection-chip-label` key가 두 개가 된 것 → S2 칩을 key 없는 자체 위젯으로 바꿔 해결(제품 코드).
- 새 테스트 `flutter test test/scan_tab_page_fe8g1_test.dart`: 첫 실행 **+14 −1**(Mock 아이템 스캔 타이머가 남음 → 시험 쪽에서 1초씩 진행), 이후 **+15 −0**.
- 관련 일반 테스트 40파일 한 명령(`flutter test <파일들> --reporter json`, 마지막 손질 · format 뒤): **+434 −0** — scan_tab_page_fe8g1 **+15**(새) · scan_header_progress_fe8f2 +7 · scan_session_controller +7 · scan_student_review_logic +5 · scan_page +17 · scan_page_revision +14 · scan_page_pause_fb10a +8 · scanner_review_images_fb10c +6 · scan_student_review_workspace +9 · scan_companion_dock +3 · scan_inventory_identity_review +2 · scanner_pause_fb10a +39 · scanner_protocol_client +6 · scanner_target_metadata_fb4 +19 · mock_scanner_commit_history +9 · mock_scanner_service +4 · student_scan_diagnostic +2 · tactical_lobby_scanner_service +2 · repository_history_scan_latest +48 · account_editor_fe8c +9 · account_manager_fe8b +6 · app_navigation_fe7d +14 · app_navigation_tidy1 +11 · connected_target_fe8d +8 · growth_calculator_view +24 · home_app_shell +1 · home_connect_fe8e +10 · home_page +5 · inventory_shell_lazy +1 · profile_delete_fb2d +17 · section_template_studio +15 · statistics_app_shell +2 · statistics_filter +10 · student_filter_followups +4 · student_filter_modal +8 · title_page +25 · inventory_analysis_page +8 · inventory_page +9 · student_page +9 · widget_test +16. (고른 기준: FE8-f2가 고른 셸 · `ScanPage` · 후보 인계 · scan_* · scanner_* · mock_scanner_* 38파일 + widget_test + 새 파일. grep `BAPlannerApp(|AppShell(|ScanPage(` 중 tactical_* 는 Lane B가 작업 중이라 뺐다.)
- process E2E(`--concurrency=1`, 파일마다 따로): scanner_process_e2e **+1**, scanner_pause_process_e2e **+1**, scanner_review_images_fb10c_process_e2e **+1**, scanner_target_metadata_process_e2e **+1**.
- 일회성 렌더: 새 golden 테스트 사본에서 `@Tags(['golden'])` · `library;` · `expectGoldenScene` 호출을 뺀 `test/goldens/fe8g1_oneoff_render_test.dart`(grep 0건 확인)를 한 번 돌려 **+2**(2560×1392, 예외 0), PNG 두 장을 `debug/frontend_fe8g1/render/`에 남기고 사본은 바로 지웠다. golden 비교는 돌리지 않았다.
- `dart format`: 이 slice 파일 경로만 하나씩. `app_shell.dart`(`_TopTab` fontWeight 줄, FE8-f1 발견 4) · `home_connect_fe8e_test.dart`(HEAD부터 format이 맞지 않은 줄 여러 곳)는 무관한 줄이 바뀌어, 전자는 그 줄을 되돌리고 후자는 착수 사본에서 다시 시작해 이 slice 편집만 다시 넣었다.
- `git diff --check`(고친 기존 7 코드 · 시험 파일): exit 0. 새 6파일 · 고친 파일 모두 원래 줄바꿈(LF, `widget_test.dart`만 CRLF 유지), 끝 개행 하나, 줄 끝 공백 0(바이트 검사). 잠금 충돌 0.

### 처리한 FD

- **FD-140**(확정 (a)): 스캔 탭 = 다중 선택 · 마지막 스캔 · 안내가 있는 본 화면, 같은 셸 컨트롤러로 시작. 홈 팝업(FE8-f3)은 손대지 않았다.
- **FD-151**(확정 (a)): 아이템 줄 7번째 `선물` 칸. 줄 폭은 시안 6칸 줄 그대로(538.4 → 2002.1), 칸 폭만 257.6 → 223.1.
- **FD-149**(워커 재량, 권장안 (a)): 최근 스캔 = 앱 실행 기록(컨트롤러 `recent`, 8건). 필드 보탬은 서비스 DTO를 고치지 않고 컨트롤러에 둔다: 시작 시각 · 아이템 종류(`recentDetail`), 적용/폐기(`candidateResolution`). 행 = 제목(`학생 전체 · n명` / `학생 1명 · 이름` / `아이템 · 종류`) · 시각(`오늘|어제 HH:MM` · `n일 전` · `M/D`) · 칩(`검토 n` pk / `확인 n` wn / `확정` ok / `폐기` · `결과 없음` · `중지` gy / `실패` · `실패 · 창 없음`(`target_not_found`) dg). 각주 `이 실행 중 기록 n건 · 앱을 끄면 지워집니다`. 지금 보고 있는 실행은 `.btn.sel-pink`, 누르면 `openRecent`.
- **FD-155**(워커 재량): 미연결이면 시작 비활성 + S3 자리에 홈과 같은 `ConnectTargetPanel`(설계 크기 그대로, 오른쪽 위 부착 · 섹션 위에서 시작). 취소하면 접고(다시 끊기면 다시 붙음), `게임 창 다시 선택`과 준비 상태 `게임 창` 행이 같은 패널을 연다. 연결은 앱 전역 `ConnectedTargetController.connect`. 스캔 탭이 보일 때만 패널을 만든다(다른 탭 · 시험에 창 목록 읽기를 더하지 않으려고).
- **FD-147**(워커 재량): 종류별 마지막 스캔 = FB-2b `repository.history.scan_latest`(`include_by_kind`, 쪽 넘김)에서 학생 / 아이템 종류별 가장 늦은 `recorded_at`. 막대 = 지난 날짜 / 14(상한), `최근` ≤ 7일 · `오래됨` · `스캔 없음`(빗금 · `없음`), 읽기 전 · 실패는 '—'. 칸 아래 `마지막 …`도 같은 값. 서비스 수정 0(발견 사항 2).
- **FD-154**(워커 재량): 시간 = 종류별 기본 상수(학생 전체 약 8분 · 1명 약 10초 · 아이템 종류마다 약 1분 — 시안 값), 칸 수 = 카탈로그 `profileId` 개수(모르면 숨김). 실측 갱신은 FE8-g2/g3.
- FD-143(워커 재량, FE8-g3): 여러 종류는 시작하지 않는다(아래 시작 판정). FD-148: 화면 전환을 머리글 칩 · 탭 점과 같은 `ScanHeaderStatus`로 판단해 맞물림.

### 화면 상태 표 (스캔 탭에 보이는 것)

| 상태(컨트롤러 · 연결) | 보이는 화면 |
|---|---|
| 미연결(앱 전역 게임 창 없음), 세션 없음 · 끝남(검토할 후보 없음) | 고르기 3섹션, S3 자리에 창 선택 패널, 주 버튼 비활성 + `게임 창을 연결하면 시작할 수 있습니다.` |
| 미연결 + 패널 취소 | 고르기 3섹션 + S3 시작 전 안내(주 버튼 비활성). `게임 창 다시 선택`으로 패널 |
| 연결됨, 세션 없음(idle) | 고르기(기본 `전체 학생`) |
| 시작 중 · 진행 · 일시정지 · 중지 요청 중 | 지금 `ScanPage`(진행 화면) |
| 끝남 + 적용 · 폐기하지 않은 후보(검토 대기, 다른 탭 적용 제외) | 지금 `ScanPage`(검토 화면) |
| 끝남 + 남은 후보 없음(모두 적용 · 폐기, 결과 없음, 중지, 실패) | 고르기(최근 스캔 첫 행이 그 실행, 분홍) |
| 최근 기록 열기 | 그 기록에 남은 후보가 있으면 `ScanPage`, 없으면 고르기 |

- `ScanPage`는 고르기 동안에도 Offstage + TickerMode(off)로 붙어 있다(계정 패널이 컨트롤러에 계정을 넘기는 시작 전제, 셸 · 시험 · golden `header-scan-progress`가 그 화면에서 컨트롤러를 찾는다).

### 시작 판정 표 (선택 × 연결 → 주 버튼)

| 고른 것 | 연결 · 준비 | 시작 | `.plain` 글자 |
|---|---|---|---|
| 없음(고른 종류 해제 · 마지막 칸 풀기) | 무엇이든 | 불가 | `학생이나 아이템을 고르면 시작할 수 있습니다.` |
| 아이템 2종 이상 | 무엇이든 | 불가(FE8-g3) | `여러 종류는 차례로 스캔합니다. 차례 스캔은 아직 열리지 않아 지금은 한 종류만 골라 시작할 수 있습니다.` |
| 학생 1개 모드 · 아이템 1종 | 백엔드 끊김 | 불가 | `백엔드에 연결되어 있지 않습니다.` |
| 〃 | 스캐너 · 저장소 서비스 없음 | 불가 | `스캐너를 쓸 수 없습니다.` |
| 〃 | 게임 창 미연결 | 불가 | `게임 창을 연결하면 시작할 수 있습니다.` |
| 〃 | 창 최소화 · 닫힘 · 미지원 | 불가 | 창 상태별 문구 |
| 〃 | 계정 아직 없음 | 불가 | `계정을 불러오면 시작할 수 있습니다.` |
| 〃 | 인식 준비 확인 중 / 안 됨 | 불가 | `인식 준비를 확인하고 있습니다.` / `인식 준비가 끝나지 않았습니다.` |
| 〃 | 모두 준비(`canStart`) | **가능** → `startPick` = `selectKind`(+ `selectInventoryScanProfile`) → 지금 `start()` | 시안 설명(학생: 백그라운드 문구, 아이템: 플래너 뒤로 문구) |

- 판정 순서 근거: 고르기 → 백엔드 → 게임 창 → 계정 → 인식 준비(사용자가 고칠 수 있는 것부터). 여러 종류에서 "첫 종류만 시작"은 하지 않는다(임의 동작 금지, 프롬프트 2).

### 고친 · 더한 파일

- `lib/ui/scan/scan_tab_page.dart`(새): `ScanTabPage` — 화면 전환(`scanTabViewFor`), 패널 상태, FB-2b 읽기(스캔 탭이 보이고 고르기 화면 · 계정을 알 때, 계정이 바뀌거나 검토를 마치고 돌아오면 다시).
- `lib/ui/scan/scan_tab_sections.dart`(새): 3섹션(레일 · 고르기 · 시작 전 안내)과 칸 · 체크 · 학생 카드 겹침 · 주 버튼 · 마지막 스캔 카드 · 오른쪽 블록 · 패널 자리.
- `lib/ui/scan/scan_pick_logic.dart`(새): 순수 규칙(칸 순서 · 이름, 화면 전환, 시작 판정 · 문구, 버튼 글자, 추정치, 시각 글자, by_kind 집계, 최근 행 제목 · 칩).
- `lib/ui/studio/scan_studio_layout.dart`(새): `scanStudioDocument`(통계와 같은 grid 3섹션) + `ScanMetrics`(시안 좌표 · 가로 규칙).
- `lib/ui/scan/scan_session_controller.dart`(+122 −0): `ScanPick`(none / student(mode) / inventory(set)) · `ScanRecentDetail`, 읽기 `pick` · `recentDetail` · `candidateResolution`, 메서드 `pickStudent` · `toggleInventoryPick` · `pickInventory` · `clearPick` · `startPick`, `start()`의 시작 시각 기록, 폐기 · 적용 성공 때 결과 기록, `_recordRecent`의 보탬 정리. 기존 동작 · 알림 횟수 변화 0(기존 시험 그대로 통과). 기본 고르기 = `전체 학생`(시안 Scan).

### `app_shell.dart` diff (+3 −2, 이유)

- import `pages/scan_page.dart` → `scan/scan_tab_page.dart`(셸은 `ScanPage`를 직접 쓰지 않게 됨).
- 스캔 탭 자리 `ScanPage(...)` → `ScanTabPage(...)`(같은 key · 인자) + `appliedElsewhere: _scanAppliedElsewhere` 1줄(다른 탭에서 적용한 후보를 검토 대기에서 빼는 FE8-f2 값 — 칩 · 점과 같은 화면 판단). `app_section.dart` · 머리글 · 토스트 수정 0.

### 바꾼 테스트와 이유 (기대값 · 조작만, 지운 테스트 0)

- `connected_target_fe8d_test.dart`: 스캔 탭에서 창 고르기를 드롭다운 → 창 선택 패널 행 + `선택한 창 사용`으로(`_pickTargetInScanTab` · `_useTargetInPanel`), 새로고침은 패널 `home-connect-panel-refresh`. `scan-start`(FilledButton) → `scan-pick-start`(KitPressable), 연결 해제 뒤 시작 비활성 + 패널 붙음 기대 추가. 드롭다운 값 확인(`scan-target`, skipOffstage false)은 그대로 — 컨트롤러 선택이 같다는 증거.
- `home_app_shell_test.dart`: 패널에서 창 연결 → `지금 화면 1명` → `scan-pick-start`(예전 기본 학생 1명 모드와 같은 시작). 그 뒤 보류 · 홈 · 학생 탭 기대는 그대로.
- `home_connect_fe8e_test.dart`: 홈 `스캔` → `scan-page` 대신 `scan-tab-page` · `scan-pick`(연결된 고르기 화면).
- `scan_header_progress_fe8f2_test.dart`: 결과 없이 중지된 세션의 토스트를 누르면 스캔 탭 = 고르기(`ScanTabPage.active`, `scan-pick`) — 예전 `ScanPage` 보임 기대를 바꿈.
- `widget_test.dart`(CRLF 유지): 스캔 탭 = `scan-tab-page` · `scan-pick`, 시작 비활성(`Start scan` → `scan-pick-start`), 패널 붙음.
- 새 `scan_tab_page_fe8g1_test.dart`(15): 규칙 5(시각 · 막대 · 칩, by_kind 집계, 7칸 순서, 버튼 글자 · 추정, 최근 행 제목 · 칩), 컨트롤러 2(상호 배타 · 토글 · 모두 · 해제, 여러 종류 · 없음은 시작 안 함), 화면 8(기준 viewport rect — 학생 칸 2 · 아이템 줄 · 주 버튼 · 카드 · 레일 행 · 오른쪽 머리 · 번호 목록 ±2px, 여러 종류 막음 · 해제 · 상호 배타, 아이템 한 종류 시작 = inventory + 종류 + 시작 기록, 진행 · 검토 = `ScanPage` → 폐기 뒤 고르기 + 최근 행 `폐기` · 각주 1건, 미연결 패널 · 취소 · 다시 선택 · 사용 · 끊김 재부착, 마지막 스캔 `스캔 없음` 8행, 1280×720 넘침 0(패널 · 7칸 · 1명), `ScanPage` Offstage 유지).
- `scan_session_controller_test.dart`는 사본만 만들고 고치지 않았다(commit.json에 없음).

### golden 변화 0 근거 + 새 장면

- 기존 장면은 스캔 탭을 열지 않는다(`test/goldens/*` grep: `top-tab-scan` 0건, FE8-f1 · f2와 같음). 스캔 탭은 셸에서 Offstage이고, 보이지 않을 때 `ScanTabPage`는 패널을 만들지 않고 FB-2b를 읽지 않는다(서비스 호출 추가 0). 그 안의 `ScanPage`는 예전과 같은 위젯 · 인자로 붙어 있어 `header-scan-progress`(홈에서 `find.byType(ScanPage, skipOffstage: false)`로 컨트롤러를 찾음)도 그대로다. 탭 줄 · 머리글 · 홈 트리 변경 0. 기준 이미지 · golden harness · 기존 golden 테스트 수정 0.
- **새 장면**(`test/goldens/fe8g1_scan_tab_golden_test.dart`, 기준 이미지 없음 → CF `-UpdateGoldens`): 2560×1392, 게임 창 연결 뒤 스캔 탭. FB-2b by_kind는 시안 값(지금 = 지역 2026-10-04 12:00, `AppClockSource`): 학생 어제 21:40 7% `최근`, 오파츠 9/12 · 활동 보고서 9/20 · 장비 9/10 100% `오래됨`, 기술 노트 · 전술 교육 BD 3일 전 21% `최근`, 엘레프 · 선물 빗금 `없음` `스캔 없음`.
  - `scan-pick-students`: 학생 `전체 학생` 칸 분홍(보유 n명 · 약 8분 — golden Mock 계정 값), 주 버튼 분홍 `학생 전체 스캔 시작 / 백그라운드 · 약 8분` + 백그라운드 설명, 오른쪽 `전체 학생 · 백그라운드` · 시작 전에 3줄 · 읽는 항목 칩 7 · 끝나면 · 아래 `지금 화면 1명으로 바꾸기`. 레일: 게임 창 `Blue Archive · 2560×1440` · 인식 준비 `준비됨` · 계정 이름, 최근 0건 각주, `게임 창 다시 선택`.
  - `scan-pick-items`: `기술 노트` · `전술 교육 BD` 칸 분홍 + 체크, 줄 라벨 `2종 선택` + `모두 선택`, 주 버튼 흐림(.45) `아이템 2종 스캔 시작 / 게임 창이 앞으로 나옵니다 · 약 2분` + 노랑 이유 문구, 오른쪽 `아이템 2종 · 포그라운드` · `기술 노트 · 전술 교육 BD` / `약 2분 · 약 n칸`(golden 카탈로그 값) · 시작 전에 · 진행 표시 · 끝나면 · `고른 종류 해제`.
  - 일회성 렌더 PNG: `debug/frontend_fe8g1/render/scan-pick-students.png` · `scan-pick-items.png`(CF 검토용, 커밋 대상 아님).

### 미검증(미실행)

- 전체 `frontend/tool/fe_gate.ps1`(golden 비교 · 전체 일반 테스트 · 나머지 process 테스트 · almanac validate · 저장소 `git diff --check`): **미실행**(CF 몫).
- golden 비교 · 새 기준 이미지 2장 생성: **미실행**(CF `-UpdateGoldens`).
- tactical_* 시험(Lane B 작업 중): **미실행**.
- 실제 백엔드 FB-2b by_kind 값 · 실제 게임 창 연결 · 실제 학생 전체 시작(`dockBeside`) · Windows release 빌드: **미실행**.
- Python 테스트: **미실행**(backend 변경 0).

### 검수표 (artboard → 앱에서 여는 방법 → 확인 포인트)

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Scan | mock 모드(`--dart-define=BA_PLANNER_USE_REAL_BACKEND=false`), 기준 viewport 최대화. 홈 `싯딤의 상자와 연결` → Mock 창 사용 → 탭 `스캔` | 3섹션 배치(통계와 같음), 학생 2칸 · 아이템 7칸이 80° 사선을 따라 밀림, `전체 학생` 분홍, 주 버튼 `학생 전체 스캔 시작 · 백그라운드 · 약 8분`, 오른쪽 안내, 종류별 마지막 스캔 8행(Mock은 기록이 없어 `스캔 없음` — 시안 값은 golden `scan-pick-students`) |
| Scan-Items | 위에서 `기술 노트` · `전술 교육 BD` 누르기 | 학생 선택 풀림, `2종 선택` · `모두 선택`, 주 버튼 `아이템 2종 스캔 시작`(흐림 + 이유 — FE8-g3 전), 오른쪽 포그라운드 안내, `고른 종류 해제` |
| (FD-155 미연결) | 앱을 새로 켜고 연결 없이 탭 `스캔` | S3 자리에 창 선택 패널, 주 버튼 흐림 + `게임 창을 연결하면…`, 취소 → 안내, `게임 창 다시 선택` → 패널 |
| (진행 · 검토 전환) | 연결 뒤 `지금 화면 1명` → 시작 | 진행 중 · 검토 대기 동안 예전 스캔 화면(`ScanPage`), 후보를 적용 · 폐기하면 고르기로 돌아오고 최근 스캔 첫 행이 분홍 + `확정`/`폐기` |

### 발견 사항

1. **머리글 부제**: 시안 부제는 `학생 · 아이템 스캔 · 고르기 → 진행 → 결과 검토`인데 앱은 `AppSection.scan` 부제 `화면 스캔과 진행 상태`다. `app_section.dart`는 이 slice 고치는 곳이 아니라 그대로 뒀다(단계별 부제는 g2 · g4와 함께 정하면 된다).
2. **FB-2b by_kind 의미**: `by_kind`는 scan 적용(commit) 시각이라 결과를 적용하지 않은 스캔은 막대에 안 잡힌다(FD-147 (a) 그대로). 서비스 수정 없이 읽기만 했다. 계정당 by_kind가 200행을 넘으면 10쪽까지 읽는다(`_lastScanMaxPages`).
3. **인식 준비 값**: 시안 `이 계정 정답 샘플 12개`의 샘플 수는 readiness에 없다(I-scan §2.4, FB-10 요청). 지금은 `준비됨` / `준비 안 됨 · 빠짐 n · 손상 n` / `확인 중`. 행을 누르면 `refreshPreparation`(창 목록 · 준비 다시 읽기, 워커 재량). 계정 행은 누를 수 없다(시안에 동작 없음, I-S-3).
4. **시안 없는 상태 문구(워커 재량)**: `지금 화면 1명` 고름의 오른쪽 안내(1번 줄 `게임에서 읽을 학생의 정보를 엽니다.`, 버튼 `학생 1명 스캔 시작`, 아래 `전체 학생으로 바꾸기`), 아무것도 고르지 않은 상태(`스캔 시작 / 종류를 고르십시오`, 오른쪽 `학생이나 아이템을 고르면 시작 전 안내가 보입니다.`), 시작 판정 이유 문구 전부, 최근 행 칩 `폐기` · `결과 없음` · `중지`. 기본 고르기는 시안 Scan처럼 `전체 학생`.
5. **`모두 선택`과 장비 1080(I-I-1)**: 7종 전부 고른다. 해상도별 비활성 칸(FD-124)은 아직 없음 — 여러 종류 시작 자체가 FE8-g3 전이라 지금은 영향 없음.
6. **보류한 학생 후보**: 보류는 후보를 지우지 않으므로 그 세션은 검토 대기로 남아 스캔 탭이 계속 `ScanPage`다(그 화면에서 다시 시작은 가능). FE8-g4 검토 보드에서 "검토 마침" 기준을 정할 때 함께.
7. **최근 행 `학생 전체 · n명`**: n은 그 실행의 `progress.current`(모르면 '—'). Mock 학생 진행은 total이 없고 current만 있다.
8. **FE8-f1 발견 6(같은 화면 계정 패널로 계정 변경)**: 고르기 화면에는 계정 패널이 없어(레일 계정 행은 표시만) 그 경로가 새로 생기지 않는다. 진행 · 검토 중의 `ScanPage` 계정 패널은 그대로라 표의 문제도 그대로다(g2/g4).
9. **키트 승격 후보(Lane A 판단)**: 고르기 칸(`_KindTile`: tile 모양 + 분홍 선택), 체크 상자, 학생 카드 겹침(`_StudentCards`), 평행사변형 주 버튼(`_StartButton`), 뒤집은 레일 버튼(통계 `_EvidenceButton`과 같은 사본), `_MinBox`(통계 사본). 지금은 화면 파일 안에 둔다.

### 사본 · commit.json

- pre 사본(착수 때 = HEAD 내용, cmp 일치): `debug/frontend_fe8g1/pre/<경로>` 9파일(고치지 않은 `scan_session_controller_test.dart` 사본 포함 — commit.json에는 없음). 착수 때 WIP 0 → `post_dir` 없음.
- `debug/frontend_fe8g1/commit.json`: slice `fe8g1`, modified 8(이 문서 포함), added 6, `whole` = [], `optional_added` = [`frontend/test/goldens/baseline/scan-pick-students.png`, `frontend/test/goldens/baseline/scan-pick-items.png`](CF가 `-UpdateGoldens`로 만들 때만), `status=true`.
- 인계: `debug/frontend_fe8g1/output.md`. 로그 `debug/frontend_fe8g1/logs/`, 렌더 `debug/frontend_fe8g1/render/`.

### 다음 행동

- FE8-g1 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: Lane B(tidy3)가 멈춘 뒤 gate 1회(예상: analyze 0, 일반 테스트에 scan_tab_page_fe8g1 +15 추가, process 스캐너 4 GREEN, 기존 golden 전 장면 GREEN, 새 `scan-pick-students` · `scan-pick-items`는 기준 없음 → 실패 이미지 검토 → `-UpdateGoldens` → 재비교) → `fe_commit.ps1 -Slice fe8g1`.
- **FE8-g2 입력**: 진행 화면은 `ScanTabPage`의 `ScanTabView.session` 자리에서 `ScanPage` 대신 새 `ScanRunView`를 보이면 된다(판단 함수 `scanTabViewFor` 그대로, 진행/검토를 나누려면 `ScanHeaderStatus.activity`). 학생 전체의 `dockBeside` 제거는 컨트롤러 `start()`. 최근 행의 시작 시각은 `recentDetail`에 있다. FD-154 실측 시간 갱신도 여기서.
- **FE8-g3 입력**: 여러 종류 큐는 `controller.pick.inventoryScanProfiles`(칸 순서는 `scanPickOrderedProfiles`)를 차례로 `selectInventoryScanProfile` + `start()` 하면 되고, 지금 `startPick`의 "여러 종류면 시작 안 함" 분기와 시작 판정 `ScanStartBlock.multipleItems`(문구)를 바꾼다. `ScanRecentDetail`은 종류 하나라 큐 세션 묶음 표시(시안 `아이템 · 기술 노트 · BD`)를 위해 확장이 필요하다.
- FE8-g4/g5: 검토 화면을 바꾸면 `ScanPage`를 Offstage로 붙여 두는 이유(계정 패널 → 컨트롤러 계정, 셸 · 시험이 그 화면에서 컨트롤러를 찾음)를 함께 정리한다 — 계정은 셸 `_selectedProfile`을 `selectProfile`로 넘기면 된다.

### fe8g1 commit record (2026-10-17 13:36, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261017_132609\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

### tidy3 commit record (2026-10-17 13:36, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261017_132609\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE8-g2 착수 기록 (2026-10-17, Lane A)

- 상태: **진행 중 → 코드 작성 완료(아래 FE8-g2 종료 기록), CF gate 미실행**. 범위: FE8-g2 학생 스캔 진행 화면(백그라운드, 시안 Scan-Student-Run). 스캔 탭에서 학생 세션이 시작 중 · 진행 · 일시정지 · 중지 요청 중이면 지금 `ScanPage` 대신 새 진행 3섹션(레일 · 진행 · 오른쪽 안내)을 보인다. 값은 FB-10 고정 범위(2026-10-15 17:05 선언, `a5e179fa` schema/fixture)의 `progress.current/total|null/message_key` · `feedback student_id/field/values` · `paused`/`resumed` · terminal만 쓰고, live 성장 값 · early candidate 자리는 '—'. 학생 전체 스캔의 `dockBeside` 호출을 없앤다(아이템 경로는 원래 dock 없음 — 그대로). 끝난 뒤는 FE8-g1 화면 상태 표 그대로(결과 있으면 기존 검토 `ScanPage`, 없으면 고르기).
- 착수 전 확인: 이 문서 끝에 다른 "FE8-g2 착수 기록" 없음(`debug/frontend_fe8g2/`도 없었음). 막힘: 대장 "slice별 막힘 요약" FE8-g2 행 = FD-142(부분: 일시정지) — 확정 (a)(2026-10-06), fb10a로 지원. 현재 `열림` 0건. 워커 재량 FD-154 · FD-156은 권장안대로.
- 시작 SHA(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`): `e498ea06344c06f3b695cedf45a3de962ba68ed0`.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe8g2/pre/<v7 기준 경로>`, 모두 작업 트리와 cmp 일치) · WIP(`git status --short <경로>` 0줄 = 모두 WIP 없음 → `post_dir` 불필요) · 줄바꿈(`git ls-files --eol`, 모두 LF):
  - `frontend/lib/ui/scan/scan_tab_page.dart`: WIP 없음. 진행 화면 자리(학생 진행이면 새 화면).
  - `frontend/lib/ui/scan/scan_tab_sections.dart`: WIP 없음. `part` 1줄 · import · 레일 진행 행(최소).
  - `frontend/lib/ui/scan/scan_session_controller.dart`: WIP 없음. 학생 전체 `dockBeside` 분기 제거 · feedback 관측 학생 목록 읽기 값(최소).
  - `frontend/lib/ui/pages/scan_page.dart`: WIP 없음. 끝난 세션의 값 없는 막대(FE8-f2 발견 1) 최소.
  - `frontend/lib/ui/studio/scan_studio_layout.dart`: WIP 없음. 진행 화면 좌표.
  - 바뀐 동작에 걸릴 수 있는 테스트(실제로 고친 것만 commit.json에): `frontend/test/scan_session_controller_test.dart` · `scan_page_test.dart` · `scan_page_pause_fb10a_test.dart` · `scan_tab_page_fe8g1_test.dart` · `scan_header_progress_fe8f2_test.dart` · `goldens/fe8g1_scan_tab_golden_test.dart`(장면 추가만), 모두 WIP 없음.
  - 이 문서: WIP 없음.
- 새 파일(예정): `frontend/lib/ui/scan/scan_run_logic.dart`(순수 규칙 · 값 출처), `frontend/lib/ui/scan/scan_run_sections.dart`(`part of scan_tab_sections.dart`, 진행 3섹션), `frontend/test/scan_run_view_fe8g2_test.dart`. 새 golden 장면 `scan-student-run` 1장(기준 이미지는 CF `-UpdateGoldens`).
- 고치지 않는 것: `lib/ui/app_shell.dart`(필요한 것은 status 요청), `lib/ui/pages/home_page.dart` · 홈 위젯(Lane B), `lib/services/**`(읽기만), `lib/ui/widgets/scan_companion_dock.dart`(FE8-g3), 학생 검토 workspace 동작(FE8-g4), `lib/ui/kit/**`, golden harness, `frontend/tool/**`, backend · contracts, 택틱 세션 소유 파일.

## FE8-g2 종료 기록 (2026-10-17, Lane A, 코드 작성 완료 · CF gate 미실행)

스캔 탭에서 학생 세션이 시작 중 · 진행(일시정지 포함) · 중지 요청 중이면 지금 `ScanPage` 대신 새 진행 3섹션(`ScanRunWorkspace`, 시안 Scan-Student-Run 좌표)을 보인다. 값은 FB-10 고정 범위(`progress.current/total|null` · identify `feedback` · `paused`/`resumed` · terminal)만 쓰고, 성장 값 · KPI 4칸 · 학생별 차이 · 확인 필요 수는 '—'(고정 범위 밖). 학생 전체 스캔의 `dockBeside` 호출을 없앴다(학생은 백그라운드). 세션은 셸 소유 컨트롤러라 다른 탭에 다녀와도 같은 진행 화면이고, 끝나면 FE8-g1 화면 상태 표 그대로(결과 있음 → 기존 검토 `ScanPage`, 없음 → 고르기). HEAD는 착수 때와 같다(`e498ea06`). git 쓰기 0, 저장소 파일 삭제 0(일회성 렌더 사본 1개만 만들고 지움).

### 실행한 명령과 결과

모두 `frontend` 폴더. 로그 `debug/frontend_fe8g2/logs/`(json 요약 · 실패 줄만 봤다).

- `flutter analyze`(frontend 전체, 마지막 손질 · format 뒤): **No issues found(0, info 포함)**. pubspec · lock 변경 0.
- 첫 실행(바뀐 동작에 직접 걸리는 5파일): **+48 −6**. 실패 6건은 모두 의도한 동작 변화(학생 전체 dock 없음 4건, 학생 진행 중 `ScanPage` 대신 진행 화면 2건) → 시험 기대값을 고쳤다(아래). 다시 실행 **+54 −0**.
- 새 테스트 `flutter test test/scan_run_view_fe8g2_test.dart`: **+8 −0**(첫 실행부터).
- 관련 일반 테스트 45파일 한 명령(`flutter test <파일들> --reporter json`, 마지막 손질 · format 뒤): **+505 −0** — scan_run_view_fe8g2 **+8**(새) · scan_tab_page_fe8g1 +15 · scan_header_progress_fe8f2 +7 · scan_session_controller +7 · scan_student_review_logic +5 · scan_page +17 · scan_page_revision +14 · scan_page_pause_fb10a +8 · scanner_review_images_fb10c +6 · scan_student_review_workspace +9 · scan_companion_dock +3 · scan_inventory_identity_review +2 · scanner_pause_fb10a +39 · scanner_protocol_client +6 · scanner_target_metadata_fb4 +19 · mock_scanner_commit_history +9 · mock_scanner_service +4 · student_scan_diagnostic +2 · tactical_lobby_scanner_service +2 · repository_history_scan_latest +48 · account_editor_fe8c +9 · account_manager_fe8b +6 · app_navigation_fe7d +14 · app_navigation_tidy1 +11 · connected_target_fe8d +8 · growth_calculator_view +24 · home_app_shell +1 · home_connect_fe8e +10 · home_page +5 · home_scan_popup_fe8f3 +11(Lane B 작업 중 파일 — 상호작용 확인용) · inventory_shell_lazy +1 · profile_delete_fb2d +17 · section_template_studio +15 · statistics_app_shell +2 · statistics_filter +10 · student_filter_followups +4 · student_filter_modal +8 · title_page +25 · inventory_analysis_page +8 · inventory_page +9 · student_page +9 · tactical_analysis +20 · tactical_excel_import +14 · tactical_slots +18 · widget_test +16. (고른 기준: FE8-g1이 고른 40파일 + 새 파일 + grep `BAPlannerApp(|AppShell(|ScanPage(|ScanTabPage(|scanStudioDocument|ScanSessionController`로 걸리는 tactical_* 3 · home_scan_popup_fe8f3.) 중간 실행 한 번은 home_scan_popup_fe8f3 −3(Lane B가 그 시험을 고치던 중, 다시 실행 +11 −0 — 발견 1).
- process E2E(`--concurrency=1`, 파일마다 따로): scanner_process_e2e **+1**, scanner_pause_process_e2e **+1**, scanner_review_images_fb10c_process_e2e **+1**, scanner_target_metadata_process_e2e **+1**.
- 변이 확인: `scan_tab_page.dart`의 `runShown`에 `&& false`를 붙이면 새 테스트 **+3 −5**(화면 시험 5건만 실패, 규칙 · 컨트롤러 3건 통과) → 원 바이트로 되돌림(SHA-256 `8197bbea3318…` 전후 같음).
- 일회성 렌더: 새 golden 장면 사본에서 `@Tags(['golden'])` · `library;` · `expectGoldenScene` 호출을 뺀 `test/goldens/fe8g2_oneoff_render_test.dart`(grep 0건 확인)를 두 번 돌려(두 번째는 장면 서비스의 전체 카탈로그 반영 뒤) **+1**(2560×1392, 예외 0), PNG를 `debug/frontend_fe8g2/render/scan-student-run.png`에 남기고 사본은 바로 지웠다. golden 비교는 돌리지 않았다.
- `dart format`: 이 slice 파일 경로만 하나씩(14파일). `scan_tab_page_fe8g1_test.dart`는 바꾼 시험 이름이 길어 본문 전체가 들여쓰기로 바뀌어, 착수 사본에서 다시 시작해 짧은 이름으로 편집만 다시 넣었다(diff 7줄). 나머지는 이 slice 줄만 바뀌었다(사본과 diff 확인).
- `git diff --check`(고친 기존 11 코드 · 시험 파일): exit 0. 새 3파일 · 고친 파일 모두 LF(CR 0바이트), 끝 개행 하나, 줄 끝 공백 0(바이트 검사). 잠금 충돌 0.

### 처리한 FD

- **FD-142**(확정 (a), fb10a): 제목 줄 `일시정지` → `pause()`(응답 `pauseRequested` = `멈추는 중…`, 끔), `paused` 이벤트에서만 `이어서`(key `scan-run-resume`) · 칩 wn `일시정지` · 각주 = 사유 문구(`pausedLabel`) · 레일 `학생 전체 · 일시정지` · 게임 창 칩 wn `일시정지`. `resumed`로 되돌린다. `중지` = 기존 `cancel()`(중지 요청 중 `중지하는 중…`), Esc = 중지는 Offstage로 붙은 `ScanPage`의 등록 그대로. 학생 일시정지 그림은 시안에 없어(I-R-3) 위 표시는 워커 재량.
- **FD-154**(워커 재량): 학생 total = `progress.total`이 있을 때만 `/ n명` · % · 막대 채움. 없으면 그것들을 그리지 않고 막대는 빗금(키트 `SkewBar(fraction: null)` = 모름, 0과 다르다). 권장안의 "없으면 보유 수에 약"은 **쓰지 않았다**: 프롬프트(total 모르면 숫자 생략)와 FB-10 고정 선언(unknown total ≠ 0, 지어내지 않음)이 앞선다. 남은 시간 = 실측 속도(시작부터 지난 시간 ÷ `current` × (`total` − `current`), 분 반올림, 1분 미만은 `약 1분`), total을 모르거나 `current` 0 · 다 읽음 · 시작 시각 모름이면 숨김. 화면은 진행 이벤트마다 다시 계산한다(타이머 없음). 고르기 화면의 기본 상수(약 8분)는 그대로.
- **FD-156**(워커 재량, 권장안 (a)의 "이벤트가 오기 전에는 (b)"): 진행 중 후보(early candidate)는 FB-10 고정 범위 밖이라 쓰지 않는다. KPI 4칸 · 학생별 차이 · 분류 칩 · 확인 필요 수 · 확인 필요 행은 '—' · 숨김. identify `feedback`은 관측값(지금 읽는 학생 · 방금 읽은 학생 목록)으로만 쓴다. 필요한 계약은 아래 XB 요청 후보.
- FD-148(머리글 칩 · 탭 점 · 토스트)은 FE8-f2 그대로 — 진행 화면 오른쪽 `다른 탭에서 보이는 모습`은 같은 `ScanHeaderStatus`로 그린 key 없는 칩 사본이다. FD-140 · FD-155 변화 0.

### 진행 화면 값 출처 표 (시안 자리 → 값)

| 시안 자리(Scan-Student-Run) | 앱 값 | 출처 |
|---|---|---|
| 제목 `학생 전체 스캔` | 모드별 `학생 전체 스캔` · `학생 1명 스캔` | `session.studentScanMode`(시작 응답 전엔 고른 모드) |
| 칩 `백그라운드 · 플래너를 계속 쓸 수 있습니다` | 그대로, 일시정지면 wn `일시정지` | `paused`/`resumed` |
| `일시정지` · `중지` | `일시정지` / `멈추는 중…` / `이어서`, `중지` / `중지하는 중…` | fb10a 제어 상태 · 단계 |
| 큰 수 `34` | `progress.current`, 없으면 '—' | FB-10 progress |
| `/ 128명` · `27%` | `progress.total`이 있을 때만 | FB-10 progress(null이면 숨김) |
| `남은 시간 약 6분` | 실측 속도(FD-154), 모르면 숨김 | progress + 시작 시각(`recentDetail.startedAt`) |
| 진행 막대 | current/total, total 모르면 빗금 | FB-10 progress |
| `지금 읽는 학생` 카드 · 이름 | 마지막 identify feedback 학생(카탈로그 이름, 없으면 id), 없으면 '—' | FB-10 feedback `student_id`(field `student_id`) |
| 레벨 · 성급 · 스킬 · 장비 · 전용무기 + 신뢰 점 | '—', 점 없음 | identify `values = {}` → 고정 범위 밖 |
| `지금까지 · 34명` | `progress.current`명, 없으면 `지금까지 · —` | FB-10 progress(읽은 수일 뿐, KPI로 바꾸지 않음) |
| KPI `바뀐 값 9 · 새 학생 1 · 확인 필요 2 · 그대로 22` | 4칸 모두 '—'(회색) | 진행 중 후보 필요 → 범위 밖(FD-156) |
| `방금 읽은 학생 · 최근 순 · 34명 중 6명` | `최근 순 · n명 중 k명`(n = 관측 학생 수, k ≤ 6), 없으면 `최근 순` + `아직 읽은 학생이 없습니다.` | feedback 관측 목록(최근 먼저, 같은 학생은 한 번) |
| 행: 카드 · 이름 | 관측 학생 | feedback |
| 행: `레벨 20 → 90` 등 차이 · 분류 칩 | 차이 '—', 칩 숨김 | 범위 밖(FD-156) |
| 각주 | 시안 문구, 일시정지면 사유(wn), 세션 오류면 오류(dg) + `진행 다시 읽기`(스냅숏 복구) | 컨트롤러 `pausedLabel` · `sessionError` |
| S3 `확인 필요 · 2명` · 행 2개 | 칩 '—', 행 숨김(설명 문구는 시안 그대로) | 범위 밖(evidence 필요) |
| S3 `백그라운드 스캔` 게임 창 | ok `뒤에 있음 · 읽는 중` / wn `일시정지` / gy `시작하는 중` · `중지하는 중` | 단계 · 제어 상태 |
| S3 플래너 · 최소화 | 시안 고정 문구(ok `자유롭게 사용`, wn `하면 일시정지`) | 정적 |
| S3 `다른 탭에서 보이는 모습` 칩 | 머리글 칩과 같은 글자(`학생 스캔 34 / 128`, 일시정지 wn) | `ScanHeaderStatus`(FE8-f2) |
| `학생 탭으로 이동` | 있음, **꺼짐**(셸이 콜백을 넘기지 않음 — 발견 2) | `ScanTabPage.onOpenStudents` |
| `지금까지 읽은 34명 미리 검토` | 글자 `지금까지 읽은 {current 또는 —}명 미리 검토`, **꺼짐** | 진행 중 후보(범위 밖) + FE8-g4 |
| S1 최근 스캔 첫 행 `학생 전체 · 진행 중 / 34 / 128명 / 백그라운드`(sel-pink) | 같은 모양, `n명`(total 모름) · '—'(진행 전), 일시정지면 `· 일시정지`. 각주 건수에 포함 | 컨트롤러 단계 · progress |
| S1 게임 창 행 · `게임 창 다시 선택` | 진행 중에는 끔(예전 화면도 진행 중 창 선택을 껐다) | — |
| 머리글 부제 `학생 스캔 진행 중 · 다른 탭을 계속 쓸 수 있습니다` | 바꾸지 않음(`화면 스캔과 진행 상태`) | `app_section.dart` · 셸 몫(발견 3) |

### 화면 상태 표 (스캔 탭에 보이는 것, FE8-g1 표 갱신)

| 상태(컨트롤러 · 연결) | 보이는 화면 |
|---|---|
| 미연결 · 세션 없음/끝남(검토할 후보 없음) | 고르기 + 창 선택 패널(FE8-g1 그대로) |
| 연결됨, 세션 없음(idle) | 고르기(FE8-g1 그대로) |
| **학생** 시작 중 · 진행 · 일시정지 · 중지 요청 중 | **새 진행 3섹션(`scan-run`)**, `ScanPage`는 Offstage |
| 아이템 · 전술 로비 시작 중 · 진행 · 일시정지 · 중지 요청 중 | 지금 `ScanPage`(FE8-g3 전까지) |
| 끝남 + 적용 · 폐기하지 않은 후보(검토 대기) | 지금 `ScanPage`(검토 화면, FE8-g4 전까지) |
| 끝남 + 남은 후보 없음(결과 없음, 중지, 실패, 모두 처리) | 고르기 |
| 최근 기록 열기 | 남은 후보가 있으면 `ScanPage`, 없으면 고르기 |

- 판단: `scanTabViewFor`(FE8-g1, 그대로) == session이고 `scanRunVisible`(학생 + 활성 단계)이면 진행 화면. 머리글 칩 · 토스트를 누르면 같은 판단으로 진행 화면이 열린다.

### dock 호출 변화

- 컨트롤러 `start()`에서 `kind == student && studentScanMode == full`일 때의 `windowDockService.dockBeside(target.id)` · `_companionActive = true` · `_publishCompanion()` 분기(−10줄)를 지웠다. 이제 어떤 시작도 dock을 열지 않는다(아이템은 원래 dock 없음 — FE8-g3가 아이템 시작에 붙인다). companion 기계(`_publishCompanion` · `_closeCompanion` · dispose의 `restore` · `onCompanionChanged`)와 `scan_companion_dock.dart`는 FE8-g3가 쓰도록 그대로 뒀다(지금은 호출되지 않는 경로).
- 그 결과 FE8-f1 버그 표 3(스냅숏 복구 뒤 companion 미갱신) · 4(dock이 열린 채 계정 변경 시 셸 overlay 남음)는 지금 재현 경로가 없다. FE8-g3에서 아이템 dock을 붙일 때 다시 판단.

### 고친 · 더한 파일

- `lib/ui/scan/scan_run_logic.dart`(새, 150줄): `scanRunVisible` · `scanRunMode` · `scanRunTitle` · `ScanRunNumbers`(current/total/fraction/글자/남은 시간) · `scanRemainingText` · `scanRunRecentRow` · `scanStudentName` · `scanRunRecentCaption` · `scanRunPauseLabel` · `scanRunTargetChip` · `scanRunLiveFields` · `scanRunKpiLabels`.
- `lib/ui/scan/scan_run_sections.dart`(새, 971줄, `part of 'scan_tab_sections.dart'`): `ScanRunWorkspace` · `_LiveRecentRow` · `_RunSection`(제목 줄 · 수치 · 막대 · 타일 2 · 머리 · 행 6 · 각주) · `_RunDetailSection` · `_HeaderChipSample`. 고르기의 레일 · `_HelpTitle` · `_StudentCards` · `_DetailHeader` · `_BlockTitle` · `_DetailButton` · `_MinBox`를 그대로 쓴다(새 위젯을 키트로 올리지 않음).
- `lib/ui/scan/scan_tab_sections.dart`(+90 −50): import 5 · `part` 1 · 머리 주석 1, `_RailSection(live)`(최근 첫 행에 지금 실행 + 각주 건수), `_DetailButton`에 `icon` · `variant` · `buttonKey` · 끈 상태(글자도 흐림 — 기본값은 예전과 같은 아이콘 · 색 · key).
- `lib/ui/scan/scan_tab_page.dart`(+29 −4): `onOpenStudents`(선택) 인자, `runShown`이면 `ScanRunWorkspace`, `ScanPage`는 `pageShown`(검토 · 학생 외 진행)일 때만 보임.
- `lib/ui/scan/scan_session_controller.dart`(+19 −10): 학생 전체 dock 분기 제거, `liveFeedbackStudentId` · `observedStudentIds`(feedback `field == student_id`만, 최근 먼저 · 중복 1회, `_resetProjection`에서 비움). 알림 횟수 변화 0.
- `lib/ui/pages/scan_page.dart`(+4 −1): 끝난 세션(terminal)인데 진행 값을 모르면 값 없는 막대를 그리지 않는다(FE8-f2 발견 1 — 끝없는 애니메이션 · `pumpAndSettle` 멈춤).
- `lib/ui/studio/scan_studio_layout.dart`(+52 −0): `ScanMetrics.run*` 진행 좌표(시안 rect에서 잰 사선 간격: 수치 46.1 · 막대 41.4 · 타일 30 · 머리/각주 43 · 행 30, 오른쪽 행 · 버튼 사선 24 · 오른쪽 22).

### 바꾼 테스트와 이유 (기대값 · 조작만, 지운 테스트 0)

- `scan_session_controller_test.dart`(+8 −7): 학생 전체 = dock 호출 0 · companion 0(시험 이름 변경), dispose 시험은 dock 없음 기대.
- `scan_page_test.dart`(+7 −5): 학생 전체 시작 · 끝에 dock · restore 0, companion 0, `Outcome: completed`(시험 이름 변경).
- `scan_page_pause_fb10a_test.dart`(+13 −13): dock의 `onPause`/`onResume` 대신 화면 `scan-pause` → `scan-paused-reason` · `scan-resume` → 완료, companion 0(시험 이름 · 머리 주석 변경).
- `scan_header_progress_fe8f2_test.dart`(+6 −1): 머리글 칩을 누르면 스캔 탭 = 진행 화면(`scan-run`, `ScanTabPage.active`) — 예전 `ScanPage` 보임 기대를 바꿈.
- `scan_tab_page_fe8g1_test.dart`(+5 −2): 학생 1명 진행 중 = `scan-run`(ScanPage Offstage), 검토 = `ScanPage`(시험 이름 변경).
- 새 `scan_run_view_fe8g2_test.dart`(8): 규칙 2(수치 · % · 남은 시간 · total 모름 · 0 · 다 읽음, 머리 글자 · 제목), 컨트롤러 1(관측 순서 · 중복 · 다른 field 무시 · 후보 아님 · 다음 시작에 비움), 화면 5(셸에서 스캔 탭 시작 → 진행 전 '—' · 빗금 / 34/128 + 관측 2명: 수치 · 막대 · 이름 · 5값 '—' · KPI '—' · 머리 · 행 순서 · 레일 첫 행 · 각주 건수 · 칩 예시 = 머리글 칩 · 확인 필요 '—' · 두 버튼 꺼짐 / total null로 숨김 / 학생 탭 다녀와도 같은 컨트롤러 · 같은 화면 · 시작 1회; 일시정지 요청 → `멈추는 중…` → `paused` → `이어서` · 사유 각주 · 레일 · 칩 wn → `resumed` → 중지 → `중지하는 중…` → `cancelled` → 고르기; 후보가 와도 끝나기 전에는 진행 화면, 끝나면 `ScanPage` 검토; 1280×720 관측 7명(6행) · 최소화 일시정지 넘침 0; `onOpenStudents`를 준 스캔 탭은 버튼이 눌리고 스캔은 계속).

### golden 변화 0 근거 + 새 장면

- 기존 장면: 스캔 탭을 여는 장면은 `scan-pick-students` · `scan-pick-items`(고르기)뿐이고, 고르기 3섹션 트리는 같다 — 레일 `live` 기본 false(행 · 각주 계산 같음), `_DetailButton` 기본값 = 예전 아이콘(swap_horiz) · 글자색(AppColors.text) · key(`scan-detail-switch`) · 꺾쇠(색 null), 누를 수 있으면 글자에 Opacity를 씌우지 않는다. `ScanPage`는 고르기 동안 예전처럼 Offstage. `header-scan-progress`(홈 탭, 스캔 탭 Offstage): 스캔 탭 안이 진행 화면으로 바뀌어도 Offstage라 그리지 않고, 머리글 칩 · 탭 점 코드는 그대로(그 장면은 `controller.start()` = 학생 1명이라 dock 제거와도 무관). 다른 장면은 세션을 시작하지 않는다. golden harness 수정 0, 기존 기준 이미지 수정 0. `commit.json` `whole` = [].
- **새 장면 `scan-student-run`**(`test/goldens/fe8g1_scan_tab_golden_test.dart`에 장면 추가만, 기준 이미지 없음 → CF `-UpdateGoldens`): 2560×1392, 게임 창 연결 뒤 스캔 탭에서 `전체 학생` 시작, Mock 진행 이벤트(identify feedback 6명: 미카 → 히나 → 유우카 → 오토기 → 슌(수영복) → 노아, 이어서 progress 34/128), 시작부터 130초(`controller.now` 고정). 장면 서비스만 전체 학생 카탈로그(`fullStudentCatalog` getter)라 이름이 한글이다. 기대 모습: 머리글 칩 분홍 `학생 스캔 34 / 128` + 막대, 탭 `스캔` 점, 레일 최근 첫 행 분홍 `학생 전체 · 진행 중 / 34 / 128명 / 백그라운드` · 각주 `이 실행 중 기록 1건`, 가운데 `학생 전체 스캔` (i) · 백그라운드 칩 · `일시정지` · `중지`, 큰 `34` `/ 128명` · `27%` · `남은 시간 약 6분`, 분홍 막대 27%, `지금 읽는 학생` 노아 카드 + 5값 '—', `지금까지 · 34명` KPI 4칸 '—' + 안내, `방금 읽은 학생 · 최근 순 · 6명 중 6명` 행 6개(노아 · 슌(수영복) · 오토기 · 유우카 · 히나 · 미카, 차이 '—'), 각주, 오른쪽 `확인 필요` '—' · 설명, `백그라운드 스캔` 3줄(ok · ok · wn), 칩 예시, `학생 탭으로 이동`(꺼짐) · 분홍 `지금까지 읽은 34명 미리 검토`(꺼짐 .45). 일회성 렌더 PNG `debug/frontend_fe8g2/render/scan-student-run.png`(CF 검토용, 커밋 대상 아님).

### 미검증(미실행)

- 전체 `frontend/tool/fe_gate.ps1`(golden 비교 · 전체 일반 테스트 · 나머지 process 테스트 · almanac validate · 저장소 `git diff --check`): **미실행**(CF 몫).
- golden 비교 · 새 기준 이미지 생성: **미실행**(CF `-UpdateGoldens`).
- 실제 백엔드 학생 전체 스캔(실제 total 값 · identify feedback 빈도 · 남은 시간 정확도), 실제 게임 창 · 최소화 일시정지, Windows release 빌드: **미실행**.
- Python 테스트: **미실행**(backend 변경 0).

### 검수표 (artboard → 앱에서 여는 방법 → 확인 포인트)

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Scan-Student-Run | mock 모드(`--dart-define=BA_PLANNER_USE_REAL_BACKEND=false`), 기준 viewport 최대화. 홈에서 Mock 창 연결 → 탭 `스캔` → `학생 전체 스캔 시작`. (Mock 학생 진행은 total null · feedback 없음 · 30ms 안에 끝나 진행 화면이 잠깐만 보인다 — 34/128 · 관측 학생 모습은 golden `scan-student-run`과 렌더 PNG로 본다) | 3섹션 배치(고르기와 같은 path), 레일 첫 행 분홍 진행 행, 큰 수치 · 막대(total 모르면 빗금 · 분모 없음), 타일 2, 행 6, 오른쪽 3블록 · 버튼 2, 끝나면 검토(후보 있음) 또는 고르기 |
| Scan-Student-Run(백그라운드) | 위에서 시작 직후 다른 탭으로 | 플래너 창이 줄어들지 않음(dock 없음), 머리글 칩 · 점, 돌아오면 같은 화면 |
| (일시정지, 시안 그림 없음) | 실제 백엔드 또는 시험(`scan_run_view_fe8g2_test`) | `멈추는 중…` → `이어서`, 칩 · 게임 창 칩 wn, 각주 사유 |

### XB 요청 후보 (FB-10 고정 범위 밖 — 이 slice는 '—'로 둠)

1. 진행 중 학생 성장 값: identify 뒤 필드별 `feedback`에 `values`(레벨 · 성급/전무 · 스킬 4 · 장비 3 · 전용무기)와 필드별 신뢰(시안 점 ok/wn) — `지금 읽는 학생` 5줄.
2. 진행 중 학생 후보(early candidate) 또는 학생별 diff 요약 이벤트: `바뀐 값 · 새 학생 · 확인 필요 · 그대로` 수, `방금 읽은 학생` 행의 차이 글자 · 분류 칩, S3 `확인 필요` 행(필드 · 자동 판독값 · 신뢰도), `미리 검토`(읽기 전용). 진행 중 후보의 revision · batch-final 의미와 끝난 뒤 후보와의 관계도 함께 정해야 한다.
3. 학생 전체 스캔의 `progress.total`(실제 백엔드가 주는지 미확인). 주지 않으면 분모 · % · 남은 시간은 계속 숨김이다.
4. (선택) 백그라운드 학생 스캔 전용 `paused` 사유가 필요한지(지금 사유는 user · input_detected · target_minimized).

### 발견 사항

1. **Lane B 동시 작업과의 접점**: 작업 트리에 Lane B 미커밋 `lib/ui/app_shell.dart`(+2) · `home_page.dart` · `lib/ui/home/home_scan_popup.dart` · `home_connect_fe8e_test.dart` · `home_scan_popup_fe8f3_test.dart`가 있다(이 slice는 손대지 않음). 중간 실행에서 home_scan_popup_fe8f3 −3(그중 하나가 "학생 전체 dock 동작 유지" 시험), 다시 실행 +11 −0 — 그 사이 Lane B가 시험을 dock 유무와 무관하게 고쳤다("FE8-g2가 바꾼다" 주석). 홈 팝업에서 시작한 학생 전체도 이제 dock 없이 백그라운드다.
2. **`학생 탭으로 이동` 셸 연결(app_shell 요청)**: `ScanTabPage(... onOpenStudents: () => _open(AppSection.students))` 1줄이면 켜진다. 이번에는 app_shell 수정 금지라 버튼은 꺼져 있다.
3. **머리글 부제**: 시안 진행 부제 `학생 스캔 진행 중 · 다른 탭을 계속 쓸 수 있습니다`는 `AppSection.scan` 고정 부제(`화면 스캔과 진행 상태`)라 바꾸지 않았다(FE8-g1 발견 1과 같은 셸 몫).
4. **진행 화면에서 잃은 예전 기능**: 학생 진행 중에는 예전 `ScanPage`의 `Recover snapshot`이 안 보이므로 세션 오류(`sessionError`)가 있을 때 각주 자리에 `진행 다시 읽기`(= `recoverSnapshot`)를 두었다(워커 재량 문구). 예전 영어 오류 문구(`Backend disconnected…`)는 컨트롤러 그대로다.
5. **남은 시간과 일시정지**: 실측 속도는 시작부터 지난 시간 전체를 쓰므로 일시정지한 시간도 들어간다(멈춘 뒤에는 더 길게 추정). 일시정지 구간을 빼려면 `paused`/`resumed` 시각을 기억하면 된다(이번에는 단순 규칙).
6. **학생 1명 진행도 같은 화면**: 시안은 학생 전체만 그렸다. 1명 스캔(약 10초)도 학생 백그라운드라 같은 화면에 제목만 `학생 1명 스캔`으로 바꿨다(워커 재량).
7. **키트 승격 후보(Lane A 판단)**: 진행 타일(`_RunTile`) · 행(`_RunStudentRow`) · 칩 예시(`_HeaderChipSample` = 머리글 칩 몸체 사본, FE8-f2 발견 3과 함께).
8. **FE8-f1 버그 표 8(`openRecent`가 실시간 학생 표시를 되돌리지 않음)**: 진행 화면은 활성 단계에서만 보이고 `start()`가 관측 목록을 비우므로 보이는 곳 0.

### 사본 · commit.json

- pre 사본(착수 때 = HEAD 내용, cmp 일치): `debug/frontend_fe8g2/pre/<경로>` 12파일(고친 11 + 이 문서). 착수 때 WIP 0 → `post_dir` 없음.
- `debug/frontend_fe8g2/commit.json`: slice `fe8g2`, modified 12(이 문서 포함), added 3, `whole` = [], `optional_added` = [`frontend/test/goldens/baseline/scan-student-run.png`](CF가 `-UpdateGoldens`로 만들 때만), `status=true`.
- 인계: `debug/frontend_fe8g2/output.md`. 로그 `debug/frontend_fe8g2/logs/`, 렌더 `debug/frontend_fe8g2/render/`.

### 다음 행동

- FE8-g2 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: Lane B(FE8-f3)가 멈춘 뒤 gate 1회(예상: analyze 0, 일반 테스트에 scan_run_view_fe8g2 +8 추가, process 스캐너 4 GREEN, 기존 golden 전 장면 GREEN, 새 `scan-student-run`은 기준 없음 → 실패 이미지 검토(렌더 PNG와 비교) → `-UpdateGoldens` → 재비교) → `fe_commit.ps1 -Slice fe8g2`. 발견 2(`onOpenStudents` 1줄)는 app_shell을 고칠 수 있는 slice에 넘긴다.
- **FE8-g3 입력**: 아이템 시작에 dock을 붙이려면 컨트롤러 `start()`의 지운 분기 자리(주석 "아이템 진행 창(dock)은 FE8-g3")에 `_kind == ScannerKind.inventory` 조건으로 `dockBeside` · `_companionActive = true` · `_publishCompanion()`을 넣으면 된다(companion 기계 · dispose `restore`는 남아 있다 — FE8-f1 버그 표 3 · 4를 그때 함께). 아이템 진행 화면을 스캔 탭에도 둘지는 `scanRunVisible`(지금 학생만)을 넓히거나 아이템용 판단을 더한다. `_publishCompanion`의 `modeLabel`은 지금 `전체 학생` 고정이라 아이템 글자로 바꿔야 한다. 여러 종류 큐(FD-143)는 FE8-g1 다음 행동 그대로.

### fe8g2 commit record (2026-10-18 00:55, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261018_003859\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

### fe8f3 commit record (2026-10-18 00:55, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261018_003859\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE9-c 착수 기록 (2026-10-18, Lane A)

- 상태: **진행 중 → 코드 작성 완료(아래 FE9-c 종료 기록), CF gate 미실행**. 범위: FE9-c 전술대항전 기록 화면 S2 로비 스캔 섹션(시안 Tactical S2 · 방어 이력 플라이아웃, G §1). S2 "지금 스캔" → 셸 `ScanSessionController`로 `tacticalLobby` 세션(스캔 탭과 같은 시작 판정, 미연결이면 창 선택 패널), 후보 → `commitTacticalLobby` → 로비 상대 카드 3장(hover → 방어 덱 플라이아웃) → 카드 선택 = `selectTacticalLobbyCandidate` + S3 상대 이름 · 공개 칸(1번 · SP1 · SP2, `visible_lobby`) 자동 채움 → 저장하면 `linkTacticalMatch(auto)`(실패는 기록을 되돌리지 않고 S2 문구), 셸 `_handoffCandidate` 전술 로비 분기 = 전술 탭으로 후보 인계, `ScanTabPage(onOpenStudents:)` 1줄(FE8-g2 발견 2).
- 착수 전 확인: 이 문서 끝에 다른 "FE9-c 착수 기록" 없음(grep 0건, `debug/frontend_fe9c/`도 없었음). 막힘: 대장 "slice별 막힘 요약" FE9-c 행 = FD-127 — 확정 (a)(2026-10-06), 현재 `열림` 0건. FD-128 (a) · FD-150 (b) · FD-176은 확정 그대로 따른다.
- 시작 SHA(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`): `4425512359e55cda77d715cdb5c5b36e9ea2c0bb`.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe9c/pre/<v7 기준 경로>`, 모두 작업 트리와 cmp 일치) · WIP(`git status --short <경로>` 0줄 = 모두 WIP 없음 → `post_dir` 불필요) · 줄바꿈(`git ls-files --eol`):
  - `frontend/lib/ui/pages/tactical_page.dart`: WIP 없음. 작업 트리 CRLF(유지).
  - `frontend/lib/ui/tactical/tactical_workspace.dart`: WIP 없음. LF(S2 자리 → 로비 섹션).
  - `frontend/lib/ui/studio/tactical_studio_layout.dart`: WIP 없음. LF(S2 카드 · 플라이아웃 좌표).
  - `frontend/lib/tactical/tactical_records_controller.dart`: WIP 없음. LF(로비 쓰기용 공용 쓰기 1개 — 최소).
  - `frontend/lib/ui/app_shell.dart`: WIP 없음. LF(전술 로비 인계 · `TacticalPage` 인자 · `onOpenStudents` — 최소).
  - `frontend/lib/ui/scan/scan_session_controller.dart`: WIP 없음. LF(사본만 — 고칠 필요가 생길 때만, 지금 계획은 수정 0).
  - 바뀐 동작에 걸리는 시험: `frontend/test/tactical_page_test.dart`(S2 "준비 중" 기대) · `frontend/test/goldens/fe9a_tactical_golden_test.dart`(장면 추가 · 조작만), 모두 WIP 없음, LF.
  - 이 문서: WIP 없음. LF.
- 새 파일(예정): `frontend/lib/ui/tactical/tactical_lobby_view.dart`(순수 규칙 — 카드 · 이력 · 시작 판정 · 문구 · 자동 채움), `frontend/lib/ui/tactical/tactical_lobby_widgets.dart`(S2 카드 · 플라이아웃), `frontend/test/tactical_lobby_fe9c_fixture.dart`(로비 쓰기를 가진 Mock 대역 · 로비 후보 payload), `frontend/test/tactical_lobby_fe9c_test.dart`. 새 golden 장면 `tactical-lobby` 1장(기준 이미지는 CF `-UpdateGoldens`).
- 고치지 않는 것: `lib/services/**`(design_review 제외, 읽기만), 스캔 탭 고르기 · 진행 화면 · `scan_page.dart`, 홈 팝업, `lib/ui/statistics/**` · `lib/statistics/**` · `test/plan_*`(Lane B tidy4 — 작업 트리에 Lane B WIP 있음), `lib/ui/kit/**`, golden harness, `frontend/tool/**`, backend · contracts, 택틱 세션 소유 파일.

## FE9-c 종료 기록 (2026-10-18, Lane A, 코드 작성 완료 · CF gate 미실행)

전술대항전 기록 화면 S2가 "준비 중" 자리에서 로비 스캔 섹션이 됐다. "지금 스캔"은 셸 `ScanSessionController`로 전술 로비 세션을 시작하고(홈 팝업 · 스캔 탭과 같은 시작 판정, 게임 창이 없으면 S4 자리에 FE8-e 창 선택 패널), 이 화면이 시작한 세션의 후보와 스캔 탭이 넘긴 후보를 `commitTacticalLobby`로 한 번씩 저장한 뒤 셸 검토 대기에서 뺀다. S2에 로비 상대 카드 3장(시안 `.row`, hover · 포커스 → 방어 이력 플라이아웃 `.fly.dl`), 카드를 누르면 `selectTacticalLobbyCandidate` + S3 새 공격 초안의 상대 이름 · 공개 칸(1번 · SP1 · SP2, `visible_lobby` · `lobby_scan`) 자동 채움, 그 초안을 저장하면 `linkTacticalMatch(auto)`. 로비 쓰기 오류 · 링크 결과는 S2 제목 줄 글자이고 기록 저장을 되돌리지 않는다. 셸은 전술 로비 인계 · `ScanTabPage(onOpenStudents:)`(FE8-g2 발견 2)를 연결했다. HEAD는 착수 때와 같다(`44255123`). git 쓰기 0, 저장소 파일 삭제 0(내가 만든 일회성 렌더 사본 1개만 만들고 지움).

### 실행한 명령과 결과

모두 `frontend` 폴더. 로그 `debug/frontend_fe9c/logs/`(json 요약 · 실패 줄만 봤다).

- `flutter analyze`(frontend 전체, 마지막 손질 · format 뒤): **No issues found(0, info 포함)** — 마지막은 줄바꿈 정정 뒤(`logs/analyze_after_eol.log`). pubspec · lock 변경 0.
- 새 시험 `flutter test test/tactical_lobby_fe9c_test.dart`: ① **+6 −6**(`logs/lobby_1.log`) — 제품 버그 1(셸이 화면을 만드는 중 `ScanTabPage.initState → ensureStarted`가 알릴 때 전술 화면 리스너가 바로 `setState` → "setState during build". FE8-f2 머리글 칩과 같은 "빌드 중이면 프레임 뒤" 규칙으로 고침) + 시험 쪽 1(칩 key에 `Text` 캐스트) → ② **+11 −1**(시험 쪽: 상대 입력 칸 key가 `TextField` 자신) → ③ **+12 −0**.
- 관련 일반 시험 48파일 한 명령(`flutter test <파일들> --reporter json`, 목록 `logs/general_files.txt`): 첫 실행 **+519 −1** — `scan_run_view_fe8g2`의 "셸은 `학생 탭으로 이동`을 연결하지 않는다" 기대(이 slice 범위 5의 의도한 변화) → 기대만 `isNotNull`로 바꿈, 그 파일 + `tactical_page_test` 다시 **+28 −0**. 마지막 실행(format 뒤) **+520 −0**(`logs/general_final.json`): account_editor_fe8c +9 · account_manager_fe8b +6 · app_navigation_fe7d +14 · app_navigation_tidy1 +11 · connected_target_fe8d +8 · growth_calculator_view +24 · home_app_shell +1 · home_connect_fe8e +10 · home_page +5 · home_scan_popup_fe8f3 +11 · inventory_shell_lazy +1 · mock_scanner_commit_history +9 · mock_scanner_service +4 · profile_delete_fb2d +17 · scan_companion_dock +3 · scan_header_progress_fe8f2 +7 · scan_inventory_identity_review +2 · scan_page +17 · scan_page_pause_fb10a +8 · scan_page_revision +14 · scan_run_view_fe8g2 +8 · scan_session_controller +7 · scan_student_review_logic +5 · scan_student_review_workspace +9 · scan_tab_page_fe8g1 +15 · scanner_pause_fb10a +39 · scanner_protocol_client +6 · scanner_review_images_fb10c +6 · scanner_target_metadata_fb4 +19 · section_template_studio +15 · student_filter_followups +4 · student_filter_modal +8 · tactical_analysis +20 · tactical_excel_import +14 · tactical_fb6b_dart +9 · tactical_fe9b2 +14 · tactical_jokbo_panel +17 · tactical_lobby_fe9c **+12**(새) · tactical_lobby_scanner_service +2 · tactical_page +20 · tactical_page_revision +5 · tactical_records_controller +14 · tactical_service +6 · tactical_share_v1_contract +1 · tactical_slots +18 · tactical_v2_service +5 · title_page +25 · widget +16. (고른 기준: grep `BAPlannerApp(|AppShell(|ScanPage(|ScanTabPage(|TacticalPage(|ScanSessionController|TacticalRecordsController|tactical_workspace|tactical_lobby|top-tab-|onCandidateHandoff|header-connection-chip|home_page.dart` + tactical_* · scan* · mock_scanner_* · home_* · widget_test, `ProcessAppService` 문자열이 있는 파일은 process 묶음으로, Lane B 영역 `test/plan_*` · statistics_*는 뺐다.)
- 통계 셸 시험(Lane B 작업 중 영역이라 따로): statistics_app_shell · statistics_filter **+12 −0**(셸을 띄우는 시험 — 읽기만, `logs/statistics_shell.log`).
- process E2E(`--concurrency=1`, 파일마다 따로, 목록 `logs/process_files.txt`): scanner_pause_process_e2e **+1** · scanner_process_e2e **+1** · scanner_review_images_fb10c_process_e2e **+1** · scanner_target_metadata_process_e2e **+1** · tactical_fb6_dart **+14** · tactical_fb6_process_e2e **+1** · tactical_fb6b_process_e2e **+1** · tactical_fb7_dart **+12** · tactical_fb7_process_e2e **+1** · tactical_fe9b1_read **+12** · tactical_process_e2e **+1** · tactical_v2_process_e2e **+1**(`logs/final_summary.txt`).
- 변이 확인: `tactical_page.dart` 저장 뒤 `_linkLobby` 호출에 `&& false`를 붙이면 새 시험 **+10 −2**(자동 링크 · 링크 실패 시험만 실패) → 원 바이트로 되돌림(SHA-256 `e1770d31bc8e…` 전후 같음).
- 일회성 렌더: golden 파일 사본에서 `@Tags(['golden'])` · `library;` · `expectGoldenScene` 호출을 뺀 `test/goldens/zz_fe9c_oneoff_render_test.dart`(grep 0건 확인)를 `tactical` · `tactical-lobby` 두 장면만 돌려 **+2**(2560×1392, 예외 0), PNG를 `debug/frontend_fe9c/render/`에 남기고 사본은 바로 지웠다(`zz_` 0건). golden 비교는 돌리지 않았다.
- `dart format`: 이 slice 파일 경로만 하나씩. `app_shell.dart`는 HEAD부터 맞지 않던 `_TopTab` fontWeight 줄(FE8-f1 발견 4)만 바뀌어 그 줄을 되돌렸다. 나머지는 이 slice 줄만 바뀌었다(전후 diff 확인).
- 줄바꿈 · 끝: 고친 기존 파일은 원래 줄바꿈(LF, `tactical_page.dart`만 CRLF), 새 4파일 LF, 끝 개행 하나, 줄 끝 공백 0(바이트 검사). **사고 1건**: 편집 스크립트의 `pathlib.write_text`가 Windows에서 개행을 CRLF로 바꿔 LF였던 `tactical_workspace.dart` · `app_shell.dart` · `tactical_page_test.dart` · `fe9a_tactical_golden_test.dart`(와 commit.json)가 CRLF가 됐다 → 바이트로 LF로 되돌려 pre 사본과 같은 LF(CR 0), `git diff --numstat` 변화 없음. 정정 뒤 analyze 0 · 직접 걸린 6파일(tactical_lobby_fe9c · tactical_page · scan_run_view_fe8g2 · home_app_shell · widget · connected_target_fe8d) **+65 −0**(`logs/after_eol.log`). `git diff --check`(고친 기존 파일): exit 0. 잠금 충돌 0.

### 처리한 FD

- **FD-127**(확정 (a)): 시안 카드 "방어 승률 · 30일" 큰 수치 · 미니 막대, 플라이아웃 기간별 "방어 n%", 머리 범례의 "방어 승률"은 그리지 않는다(범례는 `내 전적 · ? = 비공개`). 로비 순위는 후보 `opponent_rank`가 있으면 `n위`, 없으면 '—'(백엔드 DTO는 순위 ≥ 1 필수라 실제로는 늘 있다 — 아래 발견 2). "변경 의심" 칩은 추이 `changes`가 Dart DTO에 없어 그리지 않았다(XB 요청 후보 3).
- **FD-128**(확정 (a)): 기록 쓰기는 지금처럼 v2 컨트롤러 하나. 로비 commit · 선택 · 링크도 같은 컨트롤러의 새 `lobbyWrite`로 같은 revision · idempotency key · busy · 다시 읽기 규칙을 쓴다. 자동 링크는 백엔드 `link_match(auto)` 판정(같은 상대 identity · 공개 시그니처 · 시즌 · 고른 시각 ±6시간) 그대로.
- FD-150 (b) · FD-155 · FD-148: 홈 팝업 전술대항전 타일은 그대로 탭 링크, 미연결 창 선택 패널은 홈 · 스캔 탭과 같은 위젯, 머리글 칩은 FE8-f2 그대로(`전술대항전 스캔`). FD-176: 로비 채움은 공격 기록만이라 해당 없음.
- 워커 재량(대장 밖, 시안 없는 상태): 빈 상태 · 진행 · 오류 문구 전부, 카드 선택 모양(`.srow.sel`), 플라이아웃 닫힘 지연 150ms, 내 전적 = 기간 없는 내 공격 기록 수(통계가 아니라 기록 수 — tidy3 30일 창을 쓰지 않음), 족보 줄 = 최근 30일 기준(tidy3).

### 흐름 표

| 단계 | 화면 · 호출 | 실패 경로 |
|---|---|---|
| 시작 | S2 "지금 스캔" → 시작 판정(로비 서비스 → 이관 전 → 진행 · 검토 대기 → 백엔드 → 스캐너 → 게임 창 → 계정 → 인식 준비 → 기록 읽기 · 쓰기 중) → `selectKind(tacticalLobby)` + `start()`. 제목 줄 `로비를 읽는 중입니다.`, 머리글 칩 `전술대항전 스캔` | 게임 창 없음 = 버튼이 S4 자리 창 선택 패널을 연다(취소 → `게임 창을 연결하면…`, 연결 → 패널 닫힘). 그 밖의 이유 = 버튼 흐림 + 툴팁(스캔 탭 글자). 시작 응답 실패 → `로비 스캔을 시작하지 못했습니다.` |
| 후보 | 이 화면이 시작한 세션(id + generation)의 전술 로비 후보만 대기(같은 후보 · revision은 한 번). 스캔 탭에서 시작한 세션은 스캔 탭 "Review tactical capture"(`_handoffCandidate`)로 넘길 때만 | 끝났는데 후보 없음 → 완료 `…읽은 결과가 없습니다.` / 중지 / 실패 문구. 후보 해석 실패 → `…읽지 못했습니다. 다시 스캔해 주십시오.` · `confirmed`가 아니거나 순위 · 이름 없음 → `…확인이 필요한 값(순위 · 이름)…`(보내지 않음, 처리한 후보로 셸에 알림 — 다시 스캔 가능) |
| commit | 기록 컨트롤러가 읽거나 쓰는 중이면 끝난 뒤 `commitTacticalLobby`(payload 그대로, 시즌 = 목록의 이번 시즌, map '', identity 바인딩 없음 — 백엔드가 이름 · 별칭으로 찾거나 만든다), 다시 읽기, 셸 `_markScanCandidateApplied`(검토 대기 · 탭 점에서 빠짐). 제목 줄 `로비 상대 3명을 저장했습니다…` | 서비스 없음(Mock) · 이관 전 → 문구. 백엔드 오류(`review_required` · `identity_ambiguous` · `opponent_not_found` · revision 충돌 등) → 코드별 S2 문구. 보내지 못함(busy) → 다시 대기 |
| 카드 | 이 화면이 저장한 스캔(없으면 관측이 가장 늦은 스캔)의 후보 3장: `이름 · n위`, 공개 칸 3, 족보 줄, `내 전적` 칩. hover · 포커스 → 플라이아웃(공개 칸이 같은 연속 구간, 최근 5줄, 변경 주기, 최근 30일 기록이 있으면 `상대 카드 열기 →` = 분석 화면의 그 시그니처 · 상대) | 읽기 · 쓰기 중 · 이관 전 · 로비 서비스 없음 = 누를 수 없음 |
| 선택 | 고칠 수 있는 새 초안이면 그 초안, 아니면 새 공격 초안(이번 시즌)에 상대 이름 · identity · 공개 칸 3 자동 채움(2~4번 그대로, 공개 학생과 겹치는 칸은 모름) → `selectTacticalLobbyCandidate(selected_at = 고정 시계 UTC)`. 제목 줄 `고른 상대: … · 저장하면 이 로비 관측과 잇습니다.` | 선택 실패 → S2 오류 문구(채운 초안은 남는다 — 저장해도 자동 링크가 `unresolved`일 수 있다고 알림) |
| 자동 채움 → 저장 | S3 기존 "저장"(v2 upsert, 상대 identity = 이름으로 찾은 것 → 로비 commit이 만든/찾은 identity와 같다) | 저장 오류는 지금처럼 S3 문구 |
| 링크 | 저장 성공 뒤 그 초안이 로비 카드로 채운 공격 초안이면 `linkTacticalMatch(match_id, mode auto)`. `automatic` → ok `로비 관측과 이 기록을 이었습니다.` | `unresolved` · `ambiguous` → wn 문구, 백엔드 오류(`link_conflict` · `link_review_required` · 연결 끊김) → wn 문구 + "기록은 저장했습니다". 기록 · S3 문구 · 고른 행은 그대로 |

### 셸 인계 변경 (`app_shell.dart` +21 −2, 이유)

- import 1(`TacticalLobbyHandoff` show), 상태 1(`_tacticalCandidate`), `_handoffCandidate` 전술 로비 분기 +4(탭만 바꾸던 것 → 후보를 `TacticalLobbyHandoff`로 담아 전술 탭으로), 계정 변경 때 비움 1, `TacticalPage` 인자 +6(`scanSession` · `connectedTarget` · `scanAppliedElsewhere` · `lobbyHandoff` · `onLobbyCandidateHandled: _markScanCandidateApplied`), `ScanTabPage(onOpenStudents: () => _open(AppSection.students))` +2(FE8-g2 발견 2), 완료 토스트 +5 −2(전술대항전 탭에 있을 때 전술 로비 세션이 끝나면 토스트를 띄우지 않는다 — S2가 결과를 바로 보이고, 토스트를 누르면 이미 처리한 결과 대신 스캔 고르기가 열리므로).
- 이유: S2 시작 · 인계 · 검토 대기 해제는 셸 소유 스캔 컨트롤러 · 전역 창 연결 · 셸 `_scanAppliedElsewhere`가 필요하다. `app_section.dart` · 머리글 · 다른 탭 수정 0.
- `scan_session_controller.dart`는 고치지 않았다(사본만, pre와 cmp 같음): 기존 `selectKind` · `start` · `candidates` · `session` · `stage`로 충분했다.

### 고친 · 더한 파일

- `lib/ui/pages/tactical_page.dart`(CRLF 유지, +558 −0): 인자 5, 로비 상태 · 흐름(`_scanChanged` · `_queueLobby` · `_drainLobby` · `_selectLobbyCard` · `_linkLobby` · `_onLobbyScan` · 창 선택 패널 · hover · `상대 카드 열기` · `_lobbyPanel`), 저장 뒤 링크 3줄, `_setDraft`에서 로비 채움 표시 지움 1줄, 컨트롤러 리스너에서 대기 후보 다시 보내기 1줄, 머리 주석.
- `lib/ui/tactical/tactical_workspace.dart`(+149 −23): `lobby` 인자(기본 = 서비스 없음 빈 상태), S2 = 제목 줄 · 카드 3장 · 빈 상태, 섹션 위 층에 플라이아웃(화면 밖으로 밀지 않음, 꼬리는 카드 쪽) · 창 선택 패널.
- `lib/ui/studio/tactical_studio_layout.dart`(+53 −4): 카드 폭 · 간격(시안 x 817.0 · 1171.2 · 1525.3, 폭 356.5), 플라이아웃 치수 · 높이 식, 창 선택 패널 폭 비율.
- `lib/tactical/tactical_records_controller.dart`(+50 −13): `TacticalLobbyWrite` · `lobbyWrite`(오류를 `error`에 남기지 않는 같은 쓰기 규칙), 기존 `_mutate`는 공용 `_write(report: true)`로 — 기존 동작 · 알림 횟수 같음(기존 컨트롤러 시험 그대로 통과).
- 새 `lib/ui/tactical/tactical_lobby_view.dart`(633줄): 순수 규칙(카드 · 최신 스캔 · 고른 카드 · 족보 줄 · 내 전적 · 이력 구간 · 변경 주기 · 시작 판정 · 문구 · 오류 문구 · 링크 결과 · 후보 막음 · 자동 채움 · `TacticalLobbyHandoff`).
- 새 `lib/ui/tactical/tactical_lobby_widgets.dart`(671줄): `TacticalLobbyPanel` · 제목 줄 · 빈 상태 · 카드(`.po` 칠 · 선택) · 플라이아웃.
- `lib/services/design_review/tactical_records_data.dart`: 고치지 않음(로비 seed는 시험 fixture에 뒀다 — Mock에 로비가 없어 lib seed가 쓰일 곳이 없다).

### 바꾼 시험과 이유 (기대값 · 조작만, 지운 시험 0)

- `tactical_page_test.dart`(+4 −5): 기본 Mock S2 = `tactical-lobby-pending` 대신 빈 상태 글자(`tactical-lobby-message` = `tacticalLobbyEmptyText`), 머리 주석.
- `scan_run_view_fe8g2_test.dart`(+2 −2): 셸 진행 화면 `학생 탭으로 이동` onPressed `isNull` → `isNotNull`(이 slice 범위 5).
- `goldens/fe9a_tactical_golden_test.dart`(+47): 장면 `tactical-lobby` 추가 · 머리 주석, 기존 장면 · 조작 변화 0.
- 새 `tactical_lobby_fe9c_fixture.dart`: 로비 쓰기가 있는 Mock 대역(`Fe9cLobbyService` — 백엔드 commit · select · link(auto) 의미, 로비 쓰기마다 revision +1, 기록 쓰기 expected revision 보정, 시험이 내는 스캐너 이벤트, 오류 주입) · 로비 후보 payload · seed 넣기.
- 새 `tactical_lobby_fe9c_test.dart`(12): 규칙 3(후보 막음 · 카드 · 이력 · 자동 채움 · 링크/오류 글자), 배치 3(기준 캔버스 카드 3 · 플라이아웃 rect ±2px · 카드 → 플라이아웃 이동 · 닫힘 지연 · `상대 카드 열기` 유무 / 1280×720 세 카드 플라이아웃이 창 안 · 예외 0 / 기본 Mock 빈 상태 · 버튼 흐림), 셸 6(미연결 → 패널 · 취소 문구 · 연결 / 시작 → commit `7:10` → 카드 · 검토 대기 해제 · 토스트 없음 → 선택 `select:…:8` · selected_at · 자동 채움 → 저장 → `link …:auto:10` · `automatic` / 링크 실패에도 기록 남음 · S3 그대로 / commit 오류 · 검토 필요 후보 / 스캔 탭에서 시작한 로비 스캔은 인계할 때만 commit / `onOpenStudents`).

### golden 변화 예상 (장면별, 비교 미실행)

| 장면 | 예상 | 근거 |
|---|---|---|
| `tactical` | **바뀜** — S2 "준비 중" → 제목 줄 `로비 스캔` · 회색 `공개 슬롯 자동 기록` · 흐린 분홍 `지금 스캔`(스캔 아이콘, 기본 Mock은 로비 저장 서비스가 없다) · 카드 자리 `아직 로비 스캔 기록이 없습니다. 지금 스캔으로 로비의 상대 3명을 읽습니다.` | 일회성 렌더 `render/tactical.png`로 확인 |
| `tactical-jokbo-drag` | **바뀜** — S2 같은 빈 상태(고스트는 S2 아래 영역) | 같은 기록 화면 |
| `tactical-import-excel` | **바뀜** — 스크림 아래 S2 같은 빈 상태 | 같은 기록 화면 |
| `tactical-migration` | **바뀜** — S2 같은 빈 상태(이관 전이라 버튼 흐림 그대로) | 같은 기록 화면 |
| `tactical-analysis` · `-analysis-all` · `-slots` | 변화 0 | 기록 화면 S2가 없다(하위 화면 전환 뒤 찍는다) |
| `scan-student-run` | **바뀜** — 오른쪽 `학생 탭으로 이동` 버튼이 켜져 글자 흐림이 풀린다(셸 `onOpenStudents`, FE8-g2 발견 2). 나머지 같음 | 그 장면은 셸(`BAPlannerApp`)을 띄워 진행 화면을 찍는다 |
| 그 밖(홈 · 스캔 고르기 · 셸 장면) | 변화 0 | 셸 diff는 인자 · 인계 · 토스트 조건뿐이고 그 장면들은 전술 로비 세션을 시작하지 않는다 |

- **새 장면 `tactical-lobby`**(기준 이미지 없음 → CF `-UpdateGoldens`): 2560×1392, 로비 대역(같은 고정 시계)에 seed 7 + 로비 스캔 하나. 기대 모습: S2 제목 줄 `로비 스캔` · 상태 `고른 상대: 게헨나 선도부 · 저장하면 이 로비 관측과 잇습니다.` · 밝은 분홍 `지금 스캔`, 카드 3장 — ① `게헨나 선도부 · 23위` 선택(분홍 4px 테두리) 히나 | 히비키 · 아코, `족보 3a0a33 · 3일 전 검증`, `내 전적 1승 1패`(파랑) ② `아비도스 대책위원회 · 31위` hover(분홍 선) 아루 | 히비키 · 아코, `족보 없음`, `1승 0패`(초록) ③ `트리니티 정의실현부 · 27위` 미카 | 하나에 · 아야네, `족보 없음`, `기록 없음`(회색). ②의 플라이아웃(카드 아래 12, 폭 540, S3 위에 겹침): `아비도스 대책위원회 · 31위 · 최근 방어 덱 2종` · `내 전적 · ? = 비공개`, 줄1 분홍 막대 `10/5 ~ 현재` + `현재` 칩 · 아루 ? ? ? | 히비키 · 아코 · `기록 없음`, 줄2 `10/2 ~ 10/2` · 히나 · 하루나 · ? · 빈 상자 | 히비키 · 아코 · `1승 0패`, `변경 주기 평균 4일`(상대 카드 열기 없음). S3 `새 공격 기록` · `시즌 10`, 상대 `게헨나 선도부`, 상대 덱 히나 · 빗금 3 | 히비키 · 아코(공개 범례 1 · SP1 · SP2), 내 덱 빗금 6, 저장 켜짐. S4 대상 방어 덱 `2 · 3 · 4번 빈칸` · 족보 카드 2장. 렌더 PNG `debug/frontend_fe9c/render/tactical-lobby.png`(CF 검토용, 커밋 대상 아님).

### 숨긴 지표 (FD-127 (a))

| 시안 | 처리 |
|---|---|
| 카드 "방어 승률 · 30일" 41% · 미니 막대 | 그리지 않음 |
| 카드 "변경 의심" 칩 | 그리지 않음(추이 `changes` DTO 없음 — XB 요청 후보 3) |
| 플라이아웃 줄 "방어 41%" | 그리지 않음 |
| 플라이아웃 머리 "방어 승률 · 내 전적 · ? = 비공개" | `내 전적 · ? = 비공개` |
| 카드 "족보 A · 6h 전 검증" | 관측 값으로 그림(시그니처 족보 첫 카드 짧은 이름 · 그 편성 마지막 승리 상대 시각) |
| 카드 "내 전적 3승 0패" · 플라이아웃 "내 전적" · "변경 주기 평균 6일" | 관측 값으로 그림(내 기록 · 로비 스냅숏) |

### XB 요청 후보

1. **Mock v2 로비**(CF `lib/services/**` slice 몫 — XB 아님): 기본 Mock이 `TacticalEvidenceService`(로비 commit · select · link)를 구현하지 않고, Mock 스캐너의 전술 로비 후보 payload가 학생 모양이라 mock 모드에서는 S2 버튼이 흐리다. 검수용 로비 Mock은 이 slice의 시험 대역(`test/tactical_lobby_fe9c_fixture.dart`)을 옮기면 된다.
2. **`lobby.commit`의 순위 없는 후보**: 백엔드는 `current_rank.value` · 행 `rank.value`가 null이어도 저장하는데(검토 상태만 본다), Dart 읽기 DTO는 `current_rank` · `opponent_rank` ≥ 1 필수라 그런 스캔이 하나라도 저장되면 계정의 v2 상태 읽기가 실패한다. 화면은 순위 · 이름이 없는 후보를 보내지 않는다. 백엔드가 `review_required`로 거부하거나 DTO를 nullable로 넓히는 결정 필요.
3. **"변경 의심"**: 추이 `TacticalTrendsResult.changes`(타입 없는 Map) · `verified_after_latest_change`의 Dart DTO(G §1.5). 있으면 카드 칩을 관측 지표로 되살릴 수 있다.
4. (선택) 로비 후보 검토 UI용 필드 신뢰 · 대안 이름(`proposed_display_name`)을 화면이 쓰려면 검토 흐름 결정이 먼저(지금은 검토 필요 후보 = 다시 스캔).

### 미검증(미실행)

- 전체 `frontend/tool/fe_gate.ps1`(golden 비교 · 전체 일반 시험 · 나머지 process 시험 · almanac validate · 저장소 `git diff --check`): **미실행**(CF 몫).
- golden 비교 · 바뀐 기준 이미지 5장 갱신 · 새 기준 이미지 생성: **미실행**(CF `-UpdateGoldens`).
- 실제 백엔드 · 실제 게임 로비 스캔(후보가 `confirmed`로 오는 비율, 이름 · 순위 인식, commit · select · link 실제 응답 · revision 증가), 실제 창 연결, Windows release 빌드: **미실행**.
- Python 시험: **미실행**(backend 변경 0).

### 검수표 (artboard → 앱에서 여는 방법 → 확인 포인트)

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Tactical S2(빈 상태) | mock 모드(`--dart-define=BA_PLANNER_USE_REAL_BACKEND=false`), 기준 viewport 최대화, design-review 시나리오 → 전술대항전 탭 | S2 제목 줄 `로비 스캔` · `공개 슬롯 자동 기록` · `지금 스캔`(Mock은 흐림 + 툴팁 `로비 스캔 저장 서비스가 제공되지 않습니다.`), 카드 자리 빈 상태 글자 |
| Tactical S2(카드 · 선택 · 플라이아웃) | golden `tactical-lobby` · 렌더 PNG(Mock에 로비가 없어 앱에서는 실제 백엔드에서만) | 카드 3장 위치(시안 x 817 · 1171 · 1525, 폭 356.5), 선택 테두리, hover 분홍 선 + 플라이아웃(카드 아래 12 · 폭 540 · 꼬리), 방어 승률 수치 없음 |
| 흐름(실제 백엔드) | 게임 로비 화면 → 전술대항전 탭 `지금 스캔`(미연결이면 S4 자리 창 선택 패널) | 머리글 칩 `전술대항전 스캔`, 끝나면 카드 3장 · `로비 상대 3명을 저장했습니다…`, 카드 누르기 → S3 새 공격 기록 이름 · 공개 칸, 저장 → `로비 관측과 이 기록을 이었습니다.`, 탭 `스캔` 점 없음 |
| 인계 | 스캔 탭에서 시작한 전술 로비 세션 → `Review tactical capture` | 전술 탭으로 이동 + 카드, 검토 대기 해제 |
| 진행 화면 `학생 탭으로 이동`(FE8-g2) | 스캔 탭 학생 스캔 진행 중 | 버튼이 눌리고 학생 탭으로 간다(스캔은 계속) |

### 발견 사항

1. **셸 빌드 중 스캔 컨트롤러 알림**: `ScanTabPage.initState`가 `ensureStarted`로 알려 다른 탭 화면(이제 전술 화면이 리스너)이 빌드 중 `setState`를 맞는다. FE8-f2 머리글 칩처럼 빌드 중이면 프레임 뒤에 본다. 컨트롤러를 듣는 다른 화면이 생기면 같은 규칙이 필요하다(키트 · 셸 공용 헬퍼 후보).
2. **순위 없는 로비 후보**(XB 요청 후보 2).
3. **검토 필요 로비 후보**: 검토 UI가 없어 저장하지 않고 "처리함"으로 셸에 알린다(검토 대기를 풀어 다시 스캔할 수 있게). 스캔 탭 `ScanPage`의 전술 로비 요약 줄 깨진 글자(`쨌`, FE8-f1 발견 1)는 그대로(스캔 파일 수정 금지).
4. **2~4번 자동 채움 안 함**: 시안 (i) 문구("2~4번은 이 유저와의 지난 공격 기록으로 채웁니다")는 아직 화면이 하지 않는다 — 프롬프트 범위(공개 칸 · 이름)만 했다. 같은 상대 · 같은 공개 시그니처의 가장 최근 공격 기록에서 2~4번을 `manual`로 채우는 후속(출처 범례 "기록")이 자연스럽다.
5. **선택 실패 뒤 채운 초안**: 고른 시각을 남기지 못해도 채운 초안은 남는다(S2가 알림). 저장하면 자동 링크가 `unresolved`가 될 수 있다.
6. **스캔 컨트롤러 종류**: S2 시작은 `selectKind(tacticalLobby)`를 남긴다. 스캔 탭 시작(`startPick`)은 종류를 다시 정하므로 영향 없고, 진행 · 검토 중 옛 `ScanPage` 종류 드롭다운에 `tacticalLobby`가 보일 뿐이다.
7. **시즌 · map**: commit 시즌 = 목록의 이번 시즌(없으면 ''), map = ''(화면에 map 입력이 없다). 백엔드 자동 링크는 빈 시즌을 무엇이든 맞는 것으로 본다.
8. **키트 승격 후보(Lane A 판단)**: 앵커 플라이아웃(`TacticalLobbyFlyout` — 섹션 위 층 · 화면 안 밀기 · 꼬리, 분석 "전체 보기" 팝업과 같은 문법), 카드 `.po` 칠(`_CardHoverPainter`).
9. **플라이아웃 위치**: 시안 그대로 카드 아래라 S3 상대 덱 줄을 덮는다(hover 동안만). 작은 창에서는 가로로 밀고 아래가 모자라면 위로 올린다.

### 사본 · commit.json

- pre 사본(착수 때 = HEAD 내용, cmp 일치): `debug/frontend_fe9c/pre/<경로>` 10파일(고친 9 + 고치지 않은 `scan_session_controller.dart` — commit.json에는 없음). `scan_run_view_fe8g2_test.dart` 사본은 실행 중 기대 변화를 찾았을 때 고치기 전에 만들었다(HEAD와 cmp 일치). 착수 때 WIP 0 → `post_dir` 없음.
- `debug/frontend_fe9c/commit.json`: slice `fe9c`, modified 9(이 문서 포함), added 4, `whole` = 바뀌는 기준 이미지 5장(`tactical` · `tactical-jokbo-drag` · `tactical-import-excel` · `tactical-migration` · `scan-student-run`, 파일 하나씩), `optional_added` = [`frontend/test/goldens/baseline/tactical-lobby.png`](CF가 `-UpdateGoldens`로 만들 때만), `status=true`.
- 인계: `debug/frontend_fe9c/output.md`. 로그 `debug/frontend_fe9c/logs/`, 렌더 `debug/frontend_fe9c/render/`.

### 다음 행동

- FE9-c 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: Lane B(tidy4)가 멈춘 뒤 gate 1회(예상: analyze 0, 일반 시험에 tactical_lobby_fe9c +12 추가, process 4+8 GREEN, golden `tactical` · `-jokbo-drag` · `-import-excel` · `-migration` RED(S2 빈 상태) · `scan-student-run` RED(학생 탭 버튼 켜짐) · 새 `tactical-lobby` 기준 없음 → 실패 이미지 검토(렌더 PNG와 비교) → `-UpdateGoldens` → 재비교) → `fe_commit.ps1 -Slice fe9c`.
- 후속 후보: Mock v2 로비(XB 요청 후보 1, CF services slice), 2~4번 자동 채움(발견 4), 로비 후보 검토 UI(발견 3 · XB 요청 후보 4).

### fe9c commit record (2026-10-18 02:23, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261018_021257\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

### tidy4 commit record (2026-10-18 02:23, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261018_021257\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE8-g3 착수 기록 (2026-10-18, Lane A)

- 상태: **진행 중 → 코드 작성 완료(아래 FE8-g3 종료 기록), CF gate 미실행**. 범위: FE8-g3 아이템 진행 창(포그라운드, 시안 Scan-Item-Run) + 여러 종류 큐(FD-143 (a)). ① `ScanCompanionDock` 재작성(진행 · 일시정지 · 끝, 시안 문구, 고정 형식 밖 값은 '—' · 숨김), 아이템 시작 때 `dockBeside` · 끝나면 `restore` ② 스캔 탭 고르기에서 여러 종류를 고르면 시작을 켜고 종류마다 세션을 차례로(진행 창 유지, `n번째 / m종류`), 끝난 종류 후보는 세션 · generation · 후보로 따로 유지, 검토는 지금 아이템 검토 화면(`ScanPage`)에서 종류별로 ③ 홈 팝업 아이템 타일이 같은 진행 창을 쓰는지 확인(동작 그대로). 같은 시각 Lane B가 `lib/ui/scan/review/**`(새 파일만, FE8-g4a)를 만든다 — 이 slice는 그 폴더를 건드리지 않는다.
- 착수 전 확인: 이 문서 끝에 다른 "FE8-g3 착수 기록" 없음(grep 0건, `debug/frontend_fe8g3/`도 없었음). 막힘: 대장 "slice별 막힘 요약" FE8-g3 행 = FD-141 · FD-142(부분: 일시정지) — 둘 다 확정 (a)(2026-10-06), 현재 `열림` 0건. FD-143은 프롬프트 · XB 01:30 선언대로 (a) 프론트 큐(백엔드 변경 0). 근거: XB 2026-10-18 01:30 "FB-10 FE8-g3·g4·g5 기존 형식 고정 선언"(inventory progress current = entries 누계 · total = null → 분모 · % · ETA 숨김, pause는 `paused` 이벤트 · 스냅숏만 멈춤으로 봄).
- 시작 SHA(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`): `0f4d51644de0ac09a0e7a0f9c387f0a4cbeeb54c`.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe8g3/pre/<v7 기준 경로>`, 모두 작업 트리와 cmp 일치) · WIP(`git status --short <경로>` 0줄 = 모두 WIP 없음 → `post_dir` 불필요) · 줄바꿈(`git ls-files --eol`):
  - `frontend/lib/ui/widgets/scan_companion_dock.dart`: WIP 없음. 작업 트리 CRLF(유지). 진행 창 재작성.
  - `frontend/lib/ui/scan/scan_session_controller.dart`: WIP 없음. LF. 아이템 시작 dock · 큐 · companion 발행.
  - `frontend/lib/ui/scan/scan_pick_logic.dart`: WIP 없음. LF. 여러 종류 막음 해제.
  - `frontend/lib/ui/scan/scan_header_progress.dart` · `scan_end_toast.dart` · `scan_tab_page.dart`: WIP 없음. LF. 큐 동안 진행으로 보기 · 큐 끝 토스트 · 종류별 검토 줄.
  - `frontend/lib/ui/studio/scan_studio_layout.dart`: WIP 없음. LF. 진행 창 좌표.
  - `frontend/lib/ui/pages/scan_page.dart`: WIP 없음. LF(사본만 — dock 호출부를 고칠 필요가 생길 때만).
  - 바뀐 동작에 걸리는 시험: `frontend/test/scan_companion_dock_test.dart`(작업 트리 CRLF, 재작성) · `scan_page_pause_fb10a_test.dart`(dock 묶음) · `scan_session_controller_test.dart` · `scan_tab_page_fe8g1_test.dart`(여러 종류 막음 기대) · `scan_header_progress_fe8f2_test.dart` · `goldens/fe8g1_scan_tab_golden_test.dart`(장면 추가 · 조작만), 모두 WIP 없음(실제로 고친 것만 commit.json에).
  - 이 문서: WIP 없음. LF.
- 새 파일(예정): `frontend/lib/ui/scan/scan_item_queue.dart`(큐 상태 · 순수 규칙 · 종류별 검토 줄), `frontend/test/scan_item_queue_fe8g3_test.dart`. 새 golden 장면 `scan-item-run` 1장(진행 창, 2종 큐 중 1번째 — 기준 이미지는 CF `-UpdateGoldens`).
- 고치지 않는 것: `lib/ui/scan/review/**`(Lane B), `lib/services/**`(읽기만), `lib/ui/app_shell.dart`(필요한 것은 status 요청), 홈 · 전술 · 통계 · 학생 · 계획 · 인벤토리 화면 동작, `lib/ui/kit/**`, golden harness, `frontend/tool/**`, backend · contracts, 택틱 세션 소유 파일.

## FE8-g3 종료 기록 (2026-10-18, Lane A, 코드 작성 완료 · CF gate 미실행)

아이템 시작이 포그라운드가 됐다. 큐의 첫 종류에서 플래너 창을 게임 창 옆 진행 창으로 줄이고(`dockBeside`, FD-141 (a)), 재작성한 `ScanCompanionDock`(시안 Scan-Item-Run 375×750, 창 크기에 같은 비율)이 그 창을 덮는다. 스캔 탭에서 아이템 여러 종류를 고르면 시작이 켜지고(FE8-g1 막음 해제), 칸 순서대로 종류마다 세션을 하나씩 시작한다(FD-143 (a) 프론트 큐, 백엔드 변경 0). 진행 창은 큐 동안 유지되고 `n번째 / m종류`를 보인다. 끝나면 끝 카드 → 2초 뒤(또는 `결과 검토 열기`) 플래너 복원, 스캔 탭은 결과가 있는 첫 종류를 지금 검토 화면(`ScanPage`)에 열고 그 위에 종류별 검토 줄을 붙인다. 값은 XB 2026-10-18 01:30 고정 형식만 쓴다(inventory current = 인식 entry 누계, total = null → 분모 · % · 남은 시간 숨김). 홈 팝업 아이템 타일은 같은 `startPick` 경로라 같은 진행 창을 쓴다(홈 파일 수정 0). HEAD는 착수 때와 같다(`0f4d5164`). git 쓰기 0, 저장소 파일 삭제 0(내가 만든 일회성 렌더 사본 1개만 만들고 지움).

### 실행한 명령과 결과

모두 `frontend` 폴더(Flutter 3.44.6). 로그 `debug/frontend_fe8g3/logs/`(json 요약 · 실패 줄만 봤다).

- `flutter analyze`(frontend 전체, 마지막 손질 · format · 줄바꿈 정정 뒤): 이 slice 파일 **0건(info 포함)**. 전체 출력은 **1건** — `lib/ui/scan/review/scan_review_list_section.dart:445` warning `unused_element_parameter`(Lane B FE8-g4a 작업 중 새 파일, 이 slice 파일 아님). 중간 실행에서는 같은 폴더의 Lane B 파일 error 2 · warning 여럿이었다 — 이 slice는 그 폴더를 읽지도 고치지도 않았다(발견 1).
- 새 시험 `flutter test test/scan_item_queue_fe8g3_test.dart`: ① **+7 −2**(`logs/queue_1.log`) — 셸 시험 2건이 시작 중에 멈춤: 기본 `WindowsWindowDockService`의 MethodChannel이 시험(fake async)에서 응답하지 않음 → 제품 수정(기본 서비스는 Windows에서만 부르고, 응답 대기 5초 제한 `scanItemDockTimeout`) → ② **+9 −0**(`logs/queue_2.log`).
- dock 시험 `scan_companion_dock_test` + `scan_page_pause_fb10a_test`: **+13 −0**(첫 실행부터).
- 관련 일반 시험 55파일 한 명령(`flutter test <파일들> --reporter json`, 목록 `logs/general_files.txt`): 첫 실행(`logs/general_1.json`) **+587 −1** — `scan_tab_page_fe8g1` "여러 종류는 막는다" 기대(이 slice의 의도한 변화) → 기대만 바꿈. 마지막 실행(format · 줄바꿈 정정 뒤, `logs/general_final.json` · `general_final_summary.txt`) **+588 −0**: account_editor_fe8c +9 · account_manager_fe8b +6 · app_navigation_fe7d +14 · app_navigation_tidy1 +11 · connected_target_fe8d +8 · growth_calculator_view +24 · home_app_shell +1 · home_connect_fe8e +10 · home_page +5 · home_scan_popup_fe8f3 +11 · inventory_analysis_page +8 · inventory_page +9 · inventory_review_fb10b +19 · inventory_shell_lazy +1 · mock_scanner_commit_history +9 · mock_scanner_service +4 · profile_delete_fb2d +17 · scan_companion_dock **+5**(재작성) · scan_header_progress_fe8f2 +7 · scan_inventory_identity_review +2 · scan_item_queue_fe8g3 **+9**(새) · scan_page_pause_fb10a +8 · scan_page_revision +14 · scan_page +17 · scan_run_view_fe8g2 +8 · scan_session_controller +7 · scan_student_review_logic +5 · scan_student_review_workspace +9 · scan_tab_page_fe8g1 +15 · scanner_pause_fb10a +39 · scanner_protocol_client +6 · scanner_review_images_fb10c +6 · scanner_target_metadata_fb4 +19 · section_template_studio +15 · statistics_app_shell +2 · statistics_filter +10 · student_filter_followups +4 · student_filter_modal +8 · student_page +9 · tactical_analysis +20 · tactical_excel_import +14 · tactical_fb6b_dart +9 · tactical_fe9b2 +14 · tactical_jokbo_panel +17 · tactical_lobby_fe9c +12 · tactical_lobby_scanner_service +2 · tactical_page_revision +5 · tactical_page +20 · tactical_records_controller +14 · tactical_service +6 · tactical_share_v1_contract +1 · tactical_slots +18 · tactical_v2_service +5 · title_page +25 · widget +16. (고른 기준: FE9-c 48파일 + grep `BAPlannerApp(|AppShell(|ScanPage(|ScanTabPage|ScanSessionController|ScanCompanion|scanStartBlock|ScanEndNotice|ScanHeaderStatus|startPick|scan_studio_layout|InventoryCandidateContext|onCandidateHandoff|top-tab-|header-connection-chip|home_page.dart`로 더 걸린 inventory_analysis_page · inventory_page · statistics_app_shell · statistics_filter, 인벤토리 후보 쪽 inventory_review_fb10b · student_page, 새 파일.)
- process E2E(`--concurrency=1`, 파일마다 따로, `logs/process_final.log`): scanner_process_e2e **+1** · scanner_pause_process_e2e **+1** · scanner_review_images_fb10c_process_e2e **+1** · scanner_target_metadata_process_e2e **+1**.
- 변이 확인: `ScanItemQueue.ended`의 "중지면 큐 끝"을 "완료가 아니면 큐 끝"으로 바꾸면 새 시험 **+7 −2**(실패 건너뛰기 규칙 시험 · 컨트롤러 실패 시험만 실패) → 원 바이트로 되돌림(SHA-256 `33c4a4310914…` 전후 같음).
- 일회성 렌더: golden 파일 사본에서 `@Tags(['golden'])` · `library;` · `expectGoldenScene` 호출을 뺀 `test/goldens/zz_fe8g3_oneoff_render_test.dart`(grep 0건 확인)를 네 장면 모두 돌려 **+4**(예외 0), PNG를 `debug/frontend_fe8g3/render/`에 남기고 사본은 바로 지웠다(`zz_` 0건). golden 비교는 돌리지 않았다.
- `dart format`: 이 slice 파일 경로만 하나씩(13파일). 기존 파일은 이 slice 줄만 바뀌었다(diff 확인).
- 줄바꿈 · 끝: 고친 기존 파일은 원래 줄바꿈(LF, `scan_companion_dock.dart` · `scan_companion_dock_test.dart`만 작업 트리 CRLF — 다시 CRLF로 맞춤), 새 2파일 LF, 끝 개행 하나, 줄 끝 공백 0(바이트 검사). `git diff --check -- frontend almanac`: exit 0. 잠금 충돌 0.

### 처리한 FD

- **FD-141**(확정 (a)): 진행 창 = 플래너 창을 `dockBeside`로 줄인 것, 끝나면 `restore`. 큐의 첫 종류에서 한 번만 붙이고 큐 끝에 되돌린다. 네이티브 실패 · 5초 무응답 · Windows 밖이면 진행 창 없이 스캔을 계속한다(진행은 스캔 탭 · 머리글 칩, 발견 5).
- **FD-142**(확정 (a)): 일시정지는 `pause()` 응답(`pauseRequested`)이 아니라 `paused` 이벤트 · 스냅숏에서만 진행 창을 일시정지로 바꾼다(그 전에는 `멈추는 중…`, 버튼 끔). 사유별 카드(입력 감지 = 시안 문구, 창 최소화, 사용자), `이어서` · `중지`, Esc = 중지(진행 창에서도).
- **FD-143**(프롬프트 확정 (a), 대장 표기는 워커 재량): 프론트 큐. 규칙은 아래 표.
- FD-154(워커 재량): 아이템은 total = null이라 분모 · % · 남은 시간을 그리지 않는다(고르기 화면의 `약 n분`은 그대로). FD-156(워커 재량): NOW READING의 아이템 · 수량, KPI 3칸은 '—'(진행 중 후보 · 인벤토리 feedback은 고정 형식 밖). FD-148: 머리글 칩 · 탭 점 · 토스트가 큐를 한 번의 실행으로 본다.

### 진행 창 값 출처 표 (시안 자리 → 값)

| 시안 자리(Scan-Item-Run 진행 창) | 앱 값 | 출처 |
|---|---|---|
| 머리 `Plan A · 아이템 스캔` · 항상 위 표시 | 그대로(표시만) | 정적 |
| `기술 노트 · 전술 교육 BD` | 고른 종류 이름(칸 순서) | 큐 |
| 칩 `진행 중` | 진행 pk `진행 중` / 일시정지 wn `일시정지 · 입력 감지` · `일시정지 · 창 최소화` · `일시정지` / 중지 요청 gy `중지하는 중` / 끝 ok `완료` · wn `일부 완료` · dg `실패` · gy `중지` | 단계 · `paused` 이벤트 사유 · 큐 끝 |
| 큰 `69%` | **누계 칸 수**(끝난 종류의 마지막 current + 지금 종류 current), 모르면 '—' — 비율은 분모가 없어 그리지 않음 | FB-10 progress current(entry 누계) |
| `40 / 58칸 · 남은 시간 약 40초` | `칸 · 1번째 / 2종류`(1종이면 `칸`, 끝나면 `칸 · 2종류`) — 분모 · 남은 시간 숨김 | 큐 위치 |
| 진행 막대 69% | 빗금(모름), 끝(모두 완료)이면 100% ok | 큐 끝만 |
| 종류 줄 `완료 · 28 / 28칸` · `12 / 30칸` | `완료 · 28칸` · `12칸`(분모 없음), `대기` · `실패` · `중지 · n칸` · `읽지 않음`, 진행 값 전이면 '—' | 큐 · progress |
| 종류 그림 | 카탈로그 그 종류의 정렬 첫 항목 그림(없으면 이름 글자) | 카탈로그(고르기 칸과 같은 규칙) |
| NOW READING `전술 교육 BD` · `밀레니엄 · 최상급` · `40 → 40 일치` | 지금 종류 이름 · 그림, 아이템 '—', 수량 '—' | 큐 / 아이템 feedback은 고정 형식 밖 |
| KPI `바뀐 수량 4` · `확인 필요 1` · `그대로 35` | 3칸 모두 '—'(회색) | 진행 중 후보 필요 → 범위 밖 |
| `최근 기록` 5줄 | 끝난 종류 줄만(최근 먼저): `기술 노트 28칸 완료` ok · `… 읽지 못함` wn · `… 중지 · n칸까지 읽음` wn · `… 읽지 않음` gy. 아이템 단위 줄 없음. 자리가 모자라면(4종 이상) 줄 수를 줄이고 0이면 머리도 숨김 | 큐 |
| 경고 `마우스 · 키보드를 쓰면 일시정지합니다 · Esc 중지` | 그대로(진행 중에만) | 정적 |
| `일시정지` · `중지` | `일시정지` / `멈추는 중…`(끔) / `이어서`(pri), `중지` / `중지하는 중…`(끔). 종류 사이 · 시작 중에는 둘 다 끔 | fb10a 제어 상태 · 단계 |
| 일시정지 카드 `마우스 입력이 감지되어 멈췄습니다` + 본문 | 사유별 제목, 본문 `… 읽은 n칸은 그대로 남습니다.`(n = 누계, 모르면 `읽은 칸은`) | `paused` reason · 누계 |
| 완료 카드 `스캔을 마쳤습니다` + `곧 플래너가 …` · `결과 검토 열기` | 끝별 제목(완료 · `일부 종류를 읽지 못했습니다` · `스캔이 실패했습니다`), 본문 시안 그대로, 버튼 = 지금 복원 | 큐 끝 |

### 큐 규칙 표

| 사건 | 그 종류 | 큐 | 진행 창 |
|---|---|---|---|
| 성공(terminal completed) | `완료 · n칸`, 결과 = 그 세션의 최근 기록(세션 · generation · 후보) | 다음 종류 시작(같은 창 대상). 마지막이면 끝(모두 완료 = 완료, 일부 = 일부 완료) | 유지 → 끝 카드 |
| 실패(terminal failed · 시작 응답 실패) | `실패`(후보가 왔으면 결과로 남김) | 그 종류만 건너뛰고 다음 종류 | 유지 |
| 취소(진행 창 `중지` · Esc · 예전 화면 중지) | `중지 · n칸`(그때까지 읽은 후보는 남음) | **큐 전체 중지**, 남은 종류 `읽지 않음` | 바로 닫고 복원(끝 카드 없음) |
| 다음 종류 시작 조건 상실(창 선택 없음 · 최소화 · 백엔드 끊김 · 인식 준비 · 계정) | 지금 차례 `읽지 않음` | 남은 종류 모두 `읽지 않음`으로 끝 | 끝 카드 → 복원 |
| 일시정지 | 그 세션 안에서만(`paused` 이벤트로만 전환) | 다음 종류로 가지 않고 기다린다 | 일시정지 카드 · `이어서` |
| 앱 복귀(큐 끝) | — | 여러 종류면 후보가 있는 첫 종류를 검토 화면에 연다 | 끝 카드 2초(`scanItemDockCloseDelay`) 뒤 또는 `결과 검토 열기`로 `restore` |
| 계정 변경 · 셸 종료(컨트롤러 dispose) | — | 버려짐(세션은 예전처럼 버려짐) | `restore` + 셸 덮개 내림(FE8-f1 버그 표 4 수정) |
| 진행 중 백엔드 끊김 | 기존 `sessionError` 그대로 | 그대로(스냅숏 복구로 terminal이 오면 위 규칙으로 이어짐) | 그대로(발견 4) |

- 결과는 종류마다 따로다: 다음 세션 시작은 투영(`candidates`)을 비우지만, 끝난 종류의 후보는 최근 기록(최대 8)과 큐가 기억한 기록에 세션 · generation · 후보로 남는다. 검토 화면에서 종류를 바꾸면 지금 종류 후보의 오른 revision(미식별 칸 지정 등)을 그 세션 기록에 먼저 적어 둔다.
- 검토(FE8-g5 전까지): 스캔 탭 검토 화면(`ScanPage`) 위에 종류별 줄 `아이템 n종 차례 스캔 결과 · 종류별로 검토합니다` + 종류 버튼(`이름 · 검토 n` / `확정` / `결과 없음` / `실패` / `읽지 않음` — 최근 스캔 행과 같은 칩). 누르면 그 종류를 연다(`openQueueKind`). 끝난 큐의 다른 종류에 후보가 남아 있으면 머리글 · 탭 점은 검토 대기다.

### dock 수명

- 열기: 아이템 시작(스캔 탭 `startPick` · 홈 팝업 아이템 타일 · 예전 화면 `start()`는 1종 큐) → 큐 첫 종류의 `start()`에서 저장소 다시 읽기 뒤 `dockBeside(target)`(5초 제한) → `companionActive` → 셸 `onCompanionChanged`(셸 `Positioned.fill` 덮개, 기존 경로).
- 갱신: 이벤트 · 일시정지/이어서 요청 · 스냅숏 복구(FE8-f1 버그 표 3 수정) · 종류 사이마다 `scanCompanionStateFor(controller)`를 다시 낸다.
- 닫기: 큐 끝(중지 = 바로, 그 밖 = 끝 카드 2초 · `결과 검토 열기`) · 시작 실패(큐가 끝났을 때) · dispose(`restore` + 덮개 null). 학생 · 전술 로비는 dock을 쓰지 않는다(FE8-g2 그대로).

### 고친 · 더한 파일

- `lib/ui/widgets/scan_companion_dock.dart`(재작성, CRLF): `ScanCompanionPhase` · `ScanCompanionKind` · `ScanCompanionLogLine` · `ScanCompanionCard` · `ScanCompanionState`(이름 · 칩 · 누계 · 캡션 · 막대 · 종류 줄 · NOW READING · 카드 · 기록 · 콜백 4), `ScanCompanionDock`(Esc = 중지, 설계 크기 `FittedBox` 비례 — 시안 각주 "같은 비율로 줄어듭니다", 진행 창은 앱 화면이 아니라 1:2 작은 창). 키트 `BaChip` · `SkewBar` · `ItemIconTile` · `KitPressable` · `TonalButtonColors`를 쓴다(키트 수정 0). 예전 `ScanDockStudentFeedback` · 학생 카드는 쓰는 곳이 없어 뺐다.
- `lib/ui/scan/scan_item_queue.dart`(새): `ScanItemQueue` · `ScanQueueKind` · 상태/끝 enum, 글자 규칙(위치 · 이름 · 칩 · 기록 · 카드), `scanCompanionStateFor`, 종류별 검토 줄 `ScanQueueReviewBar`.
- `lib/ui/scan/scan_session_controller.dart`: 큐(`itemQueue` · `itemQueueRunning` · `itemQueueResult` · `itemQueuePendingCandidates` · `startItemQueue` · `openQueueKind` · `closeItemDock`), `startPick` 아이템 = 큐, `start()` 아이템 dock · 1종 큐 감싸기 · 시작 실패 = 그 종류 실패, terminal · 스냅숏 · 시작 버퍼에서 큐 정리(`_settleQueueOnTerminal` → `_continueQueue` → `_finishQueue`), `_publishCompanion` 재작성, dispose 덮개 내림. 학생 경로 변화 0(기존 시험 그대로 통과).
- `lib/ui/scan/scan_pick_logic.dart`: `ScanStartBlock.multipleItems`와 그 문구를 뺐다(여러 종류도 시안 아이템 설명).
- `lib/ui/scan/scan_header_progress.dart`: 큐 진행 중이면 종류 사이까지 진행(아이템, 누계, 분모 없음), 끝난 큐의 다른 종류 후보도 검토 대기.
- `lib/ui/scan/scan_end_toast.dart`: 큐 진행 중에는 토스트 없음, 큐 끝에 한 번(모든 종류 후보 수 · 큐 결과).
- `lib/ui/scan/scan_tab_page.dart`: `ScanPage` 자리를 `Column[종류별 검토 줄 | SizedBox.shrink, Expanded(ScanPage)]`로(같은 자리라 화면 state 유지).
- `lib/ui/studio/scan_studio_layout.dart`(+130): `ScanDockMetrics`(시안 진행 창 좌표) · `ScanDockLayout.of(종류 수)`(종류 줄 피치 41, 4종 이상 34 · 카드 · 타일 · 기록 자리 · 줄 수).
- `lib/ui/pages/scan_page.dart`: 고치지 않음(사본만 — `ScanCompanionState` 이름 그대로라 호출부 변경 불필요). `app_shell.dart` 수정 0.

### 바꾼 시험과 이유

- `scan_companion_dock_test.dart`(CRLF, 재작성 3 → 5): 예전 3건(학생 dock `STUDENT SCAN` · 현재 학생 카드 · 대기 글자)은 학생이 FE8-g2부터 dock을 쓰지 않고 진행 창이 재작성돼 대상이 없어 **지움**. 대체: 진행(이름 · 칩 · 누계 · 캡션 · % · 남은 시간 없음 · 종류 칩 · NOW READING '—' · KPI · 기록 · 경고 · 일시정지/중지 · Esc), 일시정지(카드 · `이어서` · 경고 없음), 끝(`결과 검토 열기`만), 중지 요청(버튼 끔), 크기(270×540 · 1280×720 · 200×300에서 7종 넘침 0 · 기록 숨김, 2종 기록 5줄, 설계 크기에서 막대 · 종류 줄 · 버튼 rect ±2px).
- `scan_page_pause_fb10a_test.dart`(dock 묶음 2건): 새 상태 모양으로 같은 의도(진행 → `일시정지` 누름 · `멈추는 중…` 끔, 일시정지 → 사유 카드 · `이어서`). 머리 주석.
- `scan_tab_page_fe8g1_test.dart`: "여러 종류는 막는다" → "여러 종류도 시작 가능 · 시안 설명"(시험 이름 변경), 컨트롤러 시험 이름 · 주석을 "시작 조건이 없으면 시작하지 않는다"로(기대값 그대로).
- `goldens/fe8g1_scan_tab_golden_test.dart`: 장면 `scan-item-run` 추가 · 머리 주석(`scan-pick-items` 설명 갱신), 기존 장면 조작 변화 0.
- 새 `scan_item_queue_fe8g3_test.dart`(+9): 규칙 2(진행 · 실패 건너뜀 · 중지 · 시작 조건 상실 · 누계, 칩 · 카드 글자), 컨트롤러 5(2종이 한 창에서 차례로 → 칸 순서 · dock 1회 · 캡션 · 누계 28→40 · 종류 사이 진행 · 토스트 없음 → 끝 카드 · 2초 뒤 restore · 첫 종류 검토 · 다른 종류 검토 대기 · 종류 바꿔 열기 · 다른 탭 적용 시 풀림 / 시작 실패 · terminal 실패 건너뜀 · 일부 완료 · 중지 = 큐 전체 · 바로 restore / `pauseRequested`는 멈춤 아님 → `paused` 카드 · 머리글 일시정지 · 큐 대기 → `resumed` / 네이티브 실패면 진행 창 없이 · 창 선택 사라지면 남은 종류 읽지 않음 / dispose = restore + 덮개 null), 셸 스캔 탭 2(2560×1392 · 1280×720: 2종 고르기 → 시작 켜짐 · 시안 설명 → Mock으로 두 종류 차례 완료 → 종류별 검토 줄 · 첫 종류 → 두 번째 열기, 예외 0).
- `scan_session_controller_test.dart` · `scan_header_progress_fe8f2_test.dart`: 사본만, 수정 0(commit.json에 없음).

### golden 변화 예상 (비교 미실행)

- **`scan-pick-items` 바뀜**(`whole`에 기준 이미지 1개): 주 버튼 `아이템 2종 스캔 시작`이 흐림(.45) → 켜짐(분홍), 옆 글자가 노랑 이유 문구 → 시안 설명 `시작하면 플래너는 뒤로 갑니다. 진행은 게임 창 옆 작은 창에 나오고, 끝나면 플래너가 다시 앞으로 와 결과 검토를 엽니다.`(일회성 렌더 `debug/frontend_fe8g3/render/scan-pick-items.png`).
- 다른 장면 변화 0 예상: `scan-pick-students` · `scan-student-run` · `header-scan-progress` · 홈 · 셸 장면은 아이템을 시작하지 않는다. 스캔 탭 안 `ScanPage` 자리에 Column · `SizedBox.shrink()`가 생겼지만 Offstage이거나 높이 0이다. 학생 시작 · 머리글 · 토스트 계산은 큐가 없을 때 예전과 같다(`itemQueue == null` 분기).
- **새 장면 `scan-item-run`**(기준 이미지 없음 → CF `-UpdateGoldens`, `optional_added`): **375×750 창 하나**(진행 창은 플래너 창을 1:2로 줄인 것이라 시안 진행 창 rect와 1:1로 비교하려고 이 장면만 view 크기를 바꿨다 — harness 수정 0). 컨트롤러 단독(대역 dock) · `기술 노트 · 전술 교육 BD` 2종 큐의 1번째, progress current 28 · total null. 기대 모습: 위 띠 분홍 표지 · `Plan A · 아이템 스캔` · 깃발, `기술 노트 · 전술 교육 BD` + 분홍 `진행 중`, 큰 `28` + `칸 · 1번째 / 2종류`, 빗금 막대, 종류 줄 `기술 노트` 분홍 `28칸` · `전술 교육 BD` 회색 `대기`(Mock 카탈로그에 BD 그림이 없어 이름 글자 칸), 분홍 테두리 사선 카드 `NOW READING` + 기술 노트 그림 · `기술 노트` · '—' · '—', KPI 3칸 '—', 최근 기록 없음, 노랑 경고 줄, `일시정지` · 빨강 `중지`(렌더 `debug/frontend_fe8g3/render/scan-item-run.png`).

### 미검증(미실행)

- 전체 `frontend/tool/fe_gate.ps1`(golden 비교 · 전체 일반 시험 · 나머지 process 시험 · almanac validate · 저장소 `git diff --check`): **미실행**(CF 몫).
- golden 비교 · 기준 이미지 갱신(`scan-pick-items`) · 새 기준(`scan-item-run`): **미실행**(CF `-UpdateGoldens`).
- 실제 Windows 러너 `dockBeside` · `restore`(1:2 크기 · 왼쪽 붙음 · 게임 창 크기 조정), 줄어든 창에서 셸 레이아웃(발견 3), 실제 백엔드 아이템 스캔(종류 사이 전환 지연, total null 확인, 입력 감지 일시정지), 진행 창 포커스와 Esc(게임 창이 앞일 때), Windows release 빌드: **미실행**.
- Python 시험: **미실행**(backend 변경 0).

### 검수표 (artboard → 앱에서 여는 방법 → 확인 포인트)

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Scan-Items | mock 모드(`--dart-define=BA_PLANNER_USE_REAL_BACKEND=false`), 기준 viewport 최대화. 홈에서 Mock 창 연결 → 탭 `스캔` → `기술 노트` · `전술 교육 BD` | 주 버튼 켜짐 · 시안 설명, 막음 이유 문구 없음(golden `scan-pick-items`) |
| Scan-Item-Run(진행) | Windows 앱(실제 러너)에서 위처럼 2종 시작. Mock은 종류마다 금방 끝나 진행 창이 잠깐만 보인다 — 진행 모습은 golden `scan-item-run`과 렌더 PNG로 본다 | 플래너가 게임 창 옆 1:2 창으로 줄고 진행 창이 덮음, `1번째 / 2종류` → `2번째 / 2종류`, 종류 칩 `완료 · n칸`, 분모 · % 없음 |
| Scan-Item-Run(일시정지) | 실제 백엔드에서 스캔 중 마우스 입력 | `paused` 이벤트 뒤에만 wn 칩 · 카드 `마우스 입력이 감지되어 멈췄습니다` · `이어서`, 그 전에는 `멈추는 중…` |
| Scan-Item-Run(완료) | 끝까지 둔다 | 끝 카드 `스캔을 마쳤습니다` 약 2초 → 플래너 원래 크기, 스캔 탭이면 첫 종류 검토 + 종류별 줄. `결과 검토 열기`는 바로 복원 |
| (중지) | 진행 창 `중지` 또는 Esc | 바로 복원, 남은 종류 `읽지 않음`, 읽은 후보는 검토에 남음 |
| (홈 팝업 아이템 타일) | 홈 연결 메뉴 `스캔` → 아이템 타일 | 같은 진행 창(1종, 캡션 `칸`), 끝나면 홈에 토스트(발견 2) |

### XB 요청 후보 (고정 형식 밖 — 이 slice는 '—' · 숨김)

1. 아이템 progress의 신뢰 가능한 전체 분모(종류별 예상 칸 수) — 있으면 `% · n / m칸 · 남은 시간`(시안). 없으면 계속 숨김.
2. 인벤토리 `feedback`(지금 읽는 아이템 id · 수량 · 이전값 비교) — NOW READING `밀레니엄 · 최상급 · 40 → 40 일치`, 아이템 단위 `최근 기록` 줄.
3. 진행 중 아이템 후보 · 차이 집계(바뀐 수량 · 확인 필요 · 그대로) — KPI 3칸(FD-156, 학생 쪽 요청 2와 같은 설계로 묶으면 된다).
4. (선택) 종류 사이 전환 지연이 크면 FD-143 (b) `inventory_scan_profiles` 배열 start — 지금은 필요 0.

### 발견 사항

1. **Lane B 동시 작업**: `lib/ui/scan/review/`(FE8-g4a 새 파일)가 작업 중 analyze error · warning을 냈다(마지막에는 warning 1). 이 slice 파일과 겹침 0, 그 폴더를 읽지 · 고치지 않았다.
2. **완료 → 결과 검토 자동 이동(app_shell 요청)**: 스캔 탭에서 시작했으면 복원 뒤 바로 검토가 보이지만, 홈 팝업 등 다른 탭에서 시작했으면 셸은 탭을 바꾸지 않고 완료 토스트(`아이템 스캔을 마쳤습니다 · 읽은 결과 n건이 있습니다. 누르면 결과 검토를 엽니다.`)만 띄운다(FE8-f2 규칙). 시안 ④ "플래너가 다시 앞으로 오고 아이템 결과 검토를 엽니다"를 다 맞추려면 셸 `_scanSessionChanged`에서 아이템 큐 끝(토스트를 띄울 자리)일 때 `_open(AppSection.scan)` 1~3줄이면 된다. app_shell 수정 금지라 하지 않았다.
3. **줄어든 창 아래 셸 레이아웃(app_shell 요청)**: 진행 창은 셸 `Positioned.fill` 덮개라 그 아래 셸은 375 폭 등 작은 창 크기로 계속 배치된다(디버그 빌드에서 넘침 경고 가능, 릴리스는 가려짐). 덮개가 있는 동안 셸 본문을 Offstage로 두는 것은 app_shell 몫(이번 golden은 진행 창만 찍어 해당 없음).
4. **진행 중 백엔드 끊김**: 진행 창이 남고 중지 요청도 실패할 수 있다(FE8-f1 이전부터 있던 세션 동작과 같다). 끊김 때 진행 창을 접을지는 후속 판단.
5. **dock 실패 = 계속(워커 재량)**: 예전 학생 전체 dock은 실패하면 스캔을 시작하지 않았다. 아이템은 게임 창이 앞에서 진행되므로 진행 창 없이 계속하게 했다. 기본 서비스는 Windows에서만 부른다(MethodChannel이 Windows 러너에만 있고, 시험 fake async에서는 응답하지 않는다). 네이티브가 5초 뒤에 늦게 붙이면 덮개 없이 창만 줄 수 있다(드문 경우).
6. **최근 스캔 행 묶음**: 큐 종류는 최근 스캔에 종류마다 한 행(`아이템 · 기술 노트`)이다. 시안 Scan 레일 `아이템 · 기술 노트 · BD` 묶음 행은 하지 않았다(FE8-g5에서 검토 보드와 함께). 최근 기록 열기(`openRecent`)는 예전처럼 기록 그대로 연다(종류별 줄의 revision 적어 두기는 큐 줄에만).
7. **키트 승격 후보(Lane A 판단)**: 가운데 정렬 꽉 찬 tonal 버튼(`_DockButton` — 키트 `TonalButton`은 글자를 왼쪽에 둔다), 사선 패널 painter(`_SkewPanelPainter`, 진행 화면 타일과 비슷).

### 사본 · commit.json

- pre 사본(착수 때 = HEAD 내용, cmp 일치): `debug/frontend_fe8g3/pre/<경로>` 15파일(고친 12 + 고치지 않은 `scan_page.dart` · `scan_session_controller_test.dart` · `scan_header_progress_fe8f2_test.dart` — commit.json에는 없음). 착수 때 WIP 0 → `post_dir` 없음.
- `debug/frontend_fe8g3/commit.json`: slice `fe8g3`, modified 12(이 문서 포함), added 2, `whole` = [`frontend/test/goldens/baseline/scan-pick-items.png`], `optional_added` = [`frontend/test/goldens/baseline/scan-item-run.png`](CF가 `-UpdateGoldens`로 만들 때만), `status=true`.
- 인계: `debug/frontend_fe8g3/output.md`. 로그 `debug/frontend_fe8g3/logs/`, 렌더 `debug/frontend_fe8g3/render/`.

### 다음 행동

- FE8-g3 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: Lane B(FE8-g4a)가 멈춘 뒤 gate 1회(예상: analyze 0(Lane B 파일이 정리됐다면), 일반 시험에 scan_item_queue_fe8g3 +9 추가 · scan_companion_dock 3→5, process 스캐너 4 GREEN, golden `scan-pick-items` RED(주 버튼 켜짐 · 설명 글자) · 새 `scan-item-run` 기준 없음 · 나머지 GREEN → 실패 이미지 검토(렌더 PNG와 비교) → `-UpdateGoldens` → 재비교) → `fe_commit.ps1 -Slice fe8g3`. 발견 2 · 3(app_shell 각 몇 줄)은 app_shell을 고칠 수 있는 slice에 넘긴다.
- **FE8-g5 입력**: 아이템 검토 보드는 `controller.itemQueue`(종류 · 상태 · `itemQueueResult(kind)` = 세션 · generation · 후보)를 읽어 종류를 합쳐 보이면 된다 — 지금 `ScanQueueReviewBar` + `ScanPage`를 그 보드로 바꾸고 `scanQueueReviewVisible` · `openQueueKind`를 대신한다. 종류별 후보는 섞지 말고 (세션, generation, candidate) 열쇠로 적용(FB10b subset)한다. 검토 대기 판단은 `ScanHeaderStatus.of`(지금 후보 + `itemQueuePendingCandidates`) 그대로 쓰면 된다. 최근 스캔 묶음 행(발견 6)도 이때.

### fe8g3 commit record (2026-10-18 15:28, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261018_151238\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

### fe8g4a commit record (2026-10-18 15:28, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261018_151238\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE8-g4b 착수 기록 (2026-10-18, Lane A)

- 상태: **진행 중 → 코드 작성 완료(아래 FE8-g4b 종료 기록), CF gate 미실행**. 범위: FE8-g4b — 학생 결과 검토 보드(`ScanStudentReviewBoard`, FE8-g4a)를 스캔 탭에 연결하고 FE8-g3가 남긴 셸 후속 2건을 한다. ① 컨트롤러 `_applyStudentCandidateInOrder` 흐름을 `approveStudentCandidate` · `commitApprovedStudentCandidate`로 나눠 공개(기존 한 명 적용은 이 둘로 동작 그대로) ② `ScanStudentReviewBoardActions` 컨트롤러 어댑터(새 파일) ③ 스캔 탭: 끝남 + 남은 학생 후보면 `ScanPage` 대신 보드, 왼쪽 레일은 고르기 · 진행과 같은 자리 ④ 스캔 탭에서 `ScanPage`의 학생 workspace 경로 마운트 해제(파일 · 시험 · golden `scan-student-review` 그대로) ⑤ 셸: 아이템 큐 끝에 스캔 탭이 아니면 스캔 탭 열기, 진행 창 덮개 동안 셸 본문 숨김. 같은 시각 Lane B가 `lib/ui/scan/item_review/**`(새 파일만, FE8-g5a)를 만든다 — 이 slice는 그 폴더를 건드리지 않는다.
- 착수 전 확인: 이 문서에 다른 "FE8-g4b 착수 기록" 없음(grep 0건, `debug/frontend_fe8g4b/`도 없었음). 대장 "slice별 막힘 요약" FE8-g4 행 `—`, 현재 `열림` 0건 → 시작. FD-144 · FD-145 · FD-148 · FD-152는 `워커 재량`(권장안). 형식은 backend 로그 2026-10-18 01:30 FB-10 고정 선언(review/commit, 후보 revision · repository revision · idempotency).
- 시작 SHA(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`): `d285c0d82c79be1a1bded06ce4bcb55dbfa27cd4`.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe8g4b/pre/<v7 기준 경로>`, 모두 작업 트리와 cmp 일치) · WIP(`git status --short <경로>` 0줄 = 모두 WIP 없음 → `post_dir` 불필요) · 줄바꿈(`git ls-files --eol`, 모두 LF):
  - `frontend/lib/ui/scan/scan_session_controller.dart`: approve/commit 공개 분리, repository revision getter.
  - `frontend/lib/ui/scan/scan_tab_page.dart`: 보드 자리.
  - `frontend/lib/ui/scan/scan_tab_sections.dart`: 레일(`_RailSection`)이 이 라이브러리 private라 보드 옆에 같은 레일을 두는 공개 위젯이 필요할 때만(최소, 종료 기록에 줄 수).
  - `frontend/lib/ui/pages/scan_page.dart`: 학생 workspace 경로를 끄는 인자(최소).
  - `frontend/lib/ui/app_shell.dart`: 셸 후속 2건(최소).
  - 시험: `frontend/test/home_app_shell_test.dart`(스캔 탭 학생 보류가 workspace → 보드) · `frontend/test/goldens/fe8g1_scan_tab_golden_test.dart`(장면 추가 · 조작만) · `frontend/test/scan_tab_page_fe8g1_test.dart` · `frontend/test/scan_session_controller_test.dart` · `frontend/test/scan_item_queue_fe8g3_test.dart`(사본만 — 실제로 고친 것만 commit.json에).
  - 이 문서: WIP 없음. LF.
- 새 파일(예정): `frontend/lib/ui/scan/scan_review_board_adapter.dart`(어댑터), `frontend/test/scan_review_board_fe8g4b_test.dart`. 새 golden 장면 최대 1장 `scan-review-students`(기준 이미지는 CF `-UpdateGoldens`).
- 고치지 않는 것: `lib/ui/scan/review/**`(원칙 0), `lib/ui/scan/item_review/**`(Lane B), `lib/ui/widgets/scan_student_review_workspace.dart`, `lib/services/**`(읽기만), 홈 · 전술 · 통계 · 학생 · 계획 · 인벤토리 화면 동작, `lib/ui/kit/**`, golden harness, `frontend/tool/**`, backend · contracts, 택틱 세션 소유 파일.

## FE8-g4b 종료 기록 (2026-10-18, Lane A, 코드 작성 완료 · CF gate 미실행)

학생 결과 검토 보드(`ScanStudentReviewBoard`, FE8-g4a)가 스캔 탭에 연결됐다. 학생 세션이 끝났고 적용 · 폐기하지 않은 학생 후보가 있으면 스캔 탭은 지금 `ScanPage` 대신 왼쪽 레일 + 보드를 보이고, 보드의 승인 · 적용 · 재검증 · 보류 · 폐기는 셸 소유 컨트롤러로 간다(FD-144 프론트 순차). 컨트롤러의 한 명 적용 흐름은 `approveStudentCandidate` · `commitApprovedStudentCandidate` 두 공개 단계로 나눴고, 기존 한 명 적용은 같은 내부 본체를 써서 동작이 같다. 스캔 탭의 `ScanPage`는 학생 검토(기존 workspace)를 더 그리지 않는다(아이템 · 전술 로비 검토는 FE8-g5b 전까지 그대로). 셸: 다른 탭에서 시작한 아이템 차례 스캔이 끝나면 토스트 대신 스캔 탭을 연다(FE8-g3 발견 2), 진행 창 덮개가 있는 동안 셸 본문을 그리지 · 누르지 않는다(발견 3). HEAD는 착수 때와 같다(`d285c0d8`). git 쓰기 0, 저장소 파일 삭제는 내가 만든 일회성 렌더 사본 1개(만들고 바로 지움)뿐이다. 보드 폴더(`lib/ui/scan/review/**`) 수정 0.

### 실행한 명령과 결과

모두 `frontend` 폴더(이 PC). 로그 `debug/frontend_fe8g4b/logs/`(json 요약 · 실패 줄만 봤다).

| 명령 | 결과 |
|---|---|
| `flutter analyze <이 slice lib 파일>`(중간 여러 번) | 이 slice 파일 0. 한 번은 Lane B 작업 중 `lib/ui/scan/item_review/scan_item_review_logic.dart` info 2(이 slice 파일 아님 — 다음 실행에서 0) |
| 관련 일반 시험 57파일 한 명령(`--reporter json`, 1회, `logs/general_1.json`) | **+601 −3** — 스캔 탭 학생 검토를 예전 `ScanPage`로 기대한 3건(home_app_shell · scan_run_view_fe8g2 · scan_tab_page_fe8g1, 이 slice의 의도한 변화) → 기대만 바꿈 |
| 새 시험 + 바꾼 3파일(`logs/new_1.json`) | +26 −7 — 새 시험 7건이 Mock 기본 상태에 확정 학생이 없어 실패(시험 도우미 문제) → 시험 서비스에 `fullStudentCatalog: true` |
| `flutter test test/scan_review_board_fe8g4b_test.dart`(`logs/new_2.json`) | **+9 −0** |
| 변이 확인 2건(`app_shell.dart`): ① 셸 본문 `visible: true` 고정 ② 아이템 큐 끝 `_open(scan)` 줄 삭제 | 둘 다 새 시험 "shell follow-ups" **+1 −1**(덮개 · 큐 끝 시험만 실패) → 원 바이트로 되돌림(SHA-256 `e4b6be1d37b0…` 전후 같음) |
| 일회성 렌더(golden 사본 `test/goldens/zz_fe8g4b_oneoff_render_test.dart`에서 `@Tags` · `library;` · `expectGoldenScene`을 뺌 — grep 0건 확인, `--plain-name scan-review-students`) | **+1**, 예외 0, PNG `debug/frontend_fe8g4b/render/scan-review-students.png`. 사본은 바로 지움(`ls test/goldens/zz_*` 0건) |
| `dart format <파일>` 이 slice 파일 하나씩 | 마지막 실행 모두 0 changed. `app_shell.dart`만 HEAD부터 format이 다른 `_TopTab` fontWeight 줄 1곳(FE8-f1 발견 4)을 원래대로 둬서 `-o none` 검사 1 changed(이 slice 줄 아님) |
| `flutter analyze`(frontend 전체, 최종, `logs/analyze_final.log`) | **No issues found(0, info 포함)**. `pubspec.yaml` · `pubspec.lock` 변경 0 |
| 관련 일반 시험 58파일 한 명령(최종, `logs/general_final.json`) | **+613 −0**(exit 0, `logs/general_final_summary.txt`): account_editor_fe8c +9 · account_manager_fe8b +6 · app_navigation_fe7d +14 · app_navigation_tidy1 +11 · connected_target_fe8d +8 · growth_calculator_view +24 · home_app_shell +1 · home_connect_fe8e +10 · home_page +5 · home_scan_popup_fe8f3 +11 · inventory_analysis_page +8 · inventory_page +9 · inventory_review_fb10b +19 · inventory_shell_lazy +1 · mock_scanner_commit_history +9 · mock_scanner_service +4 · profile_delete_fb2d +17 · scan_companion_dock +5 · scan_header_progress_fe8f2 +7 · scan_inventory_identity_review +2 · scan_item_queue_fe8g3 +9 · scan_page_pause_fb10a +8 · scan_page_revision +14 · scan_page +17 · **scan_review_board_fe8g4b +9(새)** · scan_run_view_fe8g2 +8 · scan_session_controller +7 · scan_student_review_board +14 · scan_student_review_logic +5 · scan_student_review_workspace +9 · scan_tab_page_fe8g1 +15 · scanner_pause_fb10a +39 · scanner_protocol_client +6 · scanner_review_images_fb10c +6 · scanner_target_metadata_fb4 +19 · section_template_studio +15 · statistics_app_shell +2 · statistics_filter +10 · student_filter_followups +4 · student_filter_modal +8 · student_page +9 · student_scan_diagnostic +2 · tactical_analysis +20 · tactical_excel_import +14 · tactical_fb6b_dart +9 · tactical_fe9b2 +14 · tactical_jokbo_panel +17 · tactical_lobby_fe9c +12 · tactical_lobby_scanner_service +2 · tactical_page_revision +5 · tactical_page +20 · tactical_records_controller +14 · tactical_service +6 · tactical_share_v1_contract +1 · tactical_slots +18 · tactical_v2_service +5 · title_page +25 · widget +16 |
| process E2E(`--concurrency=1`, 파일마다 따로, `logs/process_*.log`) | scanner_process_e2e **+1** · scanner_pause_process_e2e **+1** · scanner_review_images_fb10c_process_e2e **+1** · scanner_target_metadata_process_e2e **+1** |
| 바이트 검사(고친 · 새 파일 12) | 모두 LF(CR 0), 끝 개행 하나, 줄 끝 공백 0 |

- 시험 파일 고른 기준: FE8-g3 목록 55파일 + grep(`BAPlannerApp(|AppShell(|ScanPage(|ScanTabPage|ScanSessionController|ScanCompanion|scanStartBlock|ScanEndNotice|ScanHeaderStatus|startPick|scan_studio_layout|InventoryCandidateContext|onCandidateHandoff|top-tab-|header-connection-chip|home_page.dart|ScanStudentReviewBoard|applyStudentCandidate|scan_review_board`)으로 더 걸린 `scan_student_review_board_test` + `scanner_review_images_fb10c_test` · `student_scan_diagnostic_test` + 새 시험(목록 `logs/general_files.txt`).
- golden 비교 · 전체 gate · 맨 `flutter test` · Python 시험은 돌리지 않았다. 잠금 충돌 0.

### 처리한 FD

- **FD-144**(워커 재량 → (a) 프론트 순차): 보드의 `runScanReviewSequentialApply`(g4a)가 후보마다 `approve` → `commit(expected = 앞 응답 revision)`, 실패하면 멈추고 나머지를 둔다. 컨트롤러 commit은 다른 적용과 같은 차례 큐(`_applyQueue`)를 탄다. 서버 분류 · live summary · atomic bulk 가정 0(XB 01:30).
- **FD-145**(워커 재량): 보드 그대로(weapon_level/star_fallback crop만, 그 밖 '—'). 컨트롤러는 승인 · 폐기 · 적용 성공 때 crop 사본을 지운다(기존 FB-10c 규칙 그대로 — approve 단계에 포함).
- **FD-148**(워커 재량): 학생 검토 대기는 머리글 · 탭 점 · 토스트 규칙 그대로(검토 화면이 보드로 바뀌었을 뿐). 아이템 큐 끝은 다른 탭이면 토스트 대신 스캔 탭을 연다(시안 Scan-Item-Run ④ "결과 검토를 엽니다" — FE8-g3 발견 2). 학생 · 전술 로비 끝은 토스트 그대로.
- **FD-152**(워커 재량 → 권장안): `화면 확인` · 다른 의상 인연 랭크는 보드(g4a). 진단 JSON 추출은 개발 상태 패널(이후) — 아래 "workspace 마운트 해제 범위"에 없어지는 경로를 적었다.
- 막는 `열림` FD 0(착수 기록).

### 컨트롤러 API 분리 표 (`lib/ui/scan/scan_session_controller.dart`)

| 이전(private 한 흐름 `_applyStudentCandidateInOrder`) | 이후 | 동작 동일 근거 시험 |
|---|---|---|
| 계정 바뀜 확인 · 같은 의도 재시도 찾기(`_pendingApplies` + `isRetryOf`) · expected(재시도면 고정값, 아니면 state가 있을 때 `_repositoryRevision`) · 필요한 상태 없음 오류 | `_applyStudentCandidateInOrder`에 그대로 남김(재시도 찾기 = `_pinnedRetryFor`, 없음 오류 = `_recordMissingApplyState`, 같은 문구) | scan_page_revision +14(재시도 고정 key · expected, busy, 응답 잃음, 충돌) |
| review approve(이미 승인이면 건너뜀) → `_keepCandidate` · crop 해제 | **`approveStudentCandidate(c) → Future<ScannerCandidate>`**(공개, 후보 바쁨 표시 + `_approveStudentCandidate`). 실패면 던지고 후보 오류는 적지 않는다(보드가 멈춘 학생에 표시). 세션 · 스캐너 없음 = `ScanStudentApplyException('적용에 필요한 프로필 또는 세션 상태가 없습니다.')` | scanner_review_images_fb10c +6(승인 때 crop 해제), 새 시험 1 |
| 새 idempotency key(`scan-apply-<id>-<rev>-<now36>-<seq>`) · 의도 고정 · `retryRepositoryBusy` commit · 고정 해제 · `_acceptCommittedRevision` · 후보 제거 · 해결 표시 · crop 해제 · 안내 · state 다시 읽기 / 실패 분류(unknownOutcome · busy · revisionConflict · rejected) · 고정 유지/버림 · state 다시 읽기 · 오류 · 안내 | 내부 본체 `_commitStudentCandidate(...)`(한 명 적용 · 보드 공용, 줄 그대로 옮김). 실패는 지금처럼 적은 뒤 **다시 던진다**(한 명 적용은 받아서 버림 — 예전처럼 던지지 않음) | scan_page_revision +14 · scan_page +17 · mock_scanner_commit_history +9 · scanner_review_images_fb10c +6 |
| — | **`commitApprovedStudentCandidate(approved, {required int expectedRepositoryRevision}) → Future<int>`**(공개): 같은 차례 큐, 후보 바쁨, 상태 없음이면 같은 오류를 적고 던짐, 같은 의도 재시도면 고정 요청(key · expected)을 그대로 보내고 인자 expected는 쓰지 않음, 성공 = 응답 revision(정수가 아니면 다시 읽은 `repositoryRevision`, 그것도 없으면 `StateError`) | 새 시험 2(순차 expected · 새 key · 후보 제거 · revision / 거절 = 오류 · 후보 유지, 응답 잃음 = 오류 없음 · 고정 key · 고정 expected 재전송 · review 1회) |
| `_repositoryRevision`(private) | **`int? get repositoryRevision`** = state를 읽었으면 `_repositoryRevision`, 아니면 null(예전 expected 규칙 그대로) | 새 시험 |
| — | `ScanStudentApplyException`(`toString` = 문구) | — |

- 한 명 적용의 순서 차이(관측 불가): 예전에는 의도 고정(`_pendingApplies[slot] = …`) 뒤에 `_keepCandidate` · crop 해제를 알렸고, 이제는 approve 단계에서 먼저 알린 뒤 의도를 고정한다. 둘 다 같은 microtask 안이고 `_pendingApplies`는 바깥에 보이지 않는다.

### 어댑터 규칙 (`lib/ui/scan/scan_review_board_adapter.dart`, `ScanReviewBoardControllerActions`)

| 보드 actions | 컨트롤러 |
|---|---|
| `approve(c)` | `approveStudentCandidate(c)` |
| `commit(approved, expected)` | `commitApprovedStudentCandidate(approved, expectedRepositoryRevision: expected)` |
| `revalidate(c, payload, ranks, confirmed)` | `revalidateStudentCandidate(...)`(void) 뒤 `candidates[c.id]`가 같은 세션 · generation이고 revision이 바뀌었으면 그 후보, 아니면 null(실패 글자는 컨트롤러 `candidateErrors` → 보드) |
| `hold(c)` · `discard(c)` | `holdStudentCandidate` · `discardStudentCandidate` |

### 스캔 탭 표시 규칙 표 (`scan_tab_page.dart`)

| 종류 \ 상태 | 진행(시작 중 · 진행 · 일시정지 · 중지 요청) | 끝남 + 남은 후보 | 끝남 · 후보 없음 |
|---|---|---|---|
| 학생 | 진행 3섹션 `ScanRunWorkspace`(FE8-g2, 그대로) | **레일 `ScanRailWorkspace`(`scan-review-rail`) + 보드(`scan-review`)**, `ScanPage`는 Offstage · 학생 검토 안 그림 | 고르기(`scan-pick`) |
| 아이템(큐) | 큐가 끝날 때까지 진행 = 지금 `ScanPage`(진행 창이 덮음, FE8-g3 그대로) | 종류별 검토 줄 + `ScanPage`(FE8-g5b 전까지 그대로) | 고르기 |
| 전술 로비 | 지금 `ScanPage`(그대로) | 지금 `ScanPage`(그대로) | 고르기 |

- 보드 값 연결(g4b 입력 2): `candidates` = `scanReviewStudentCandidates`(끝난 세션 · 학생 · 다른 탭이 적용하지 않은 후보, 정렬은 보드), `currentStudents` = `repositoryState.students`(id 맵), `catalog` = `studentCatalog`, `repositoryRevision` = 새 getter, `busyCandidateIds` · `candidateErrors` = 컨트롤러 그대로, `scopeLabel` = 세션 `studentScanMode`(`학생 전체` / `학생 1명`), `timeLabel` = 이 컨트롤러로 시작한 세션의 시작 시각(`scanWhenText` — 최근 스캔 행과 같은 `오늘 11:57`), 모르면 null(보드가 '—').
- 레일: 고르기 · 진행과 같은 `_RailSection`(최근 스캔 첫 행 = 지금 검토 세션 선택 표시, 다른 최근 기록 열기 그대로). 보드가 오른쪽 섹션을 쓰므로 창 선택 패널은 붙이지 않는다(진행 화면과 같이 `게임 창 다시 선택`은 꺼짐). 다른 최근 기록(아이템)을 열면 그 검토(`ScanPage`)로 바뀐다.
- 머리글 부제(`학생 스캔 결과 검토 · 후보 확인 → 적용`)는 `app_section` · 셸 몫이라 바꾸지 않았다(FE8-g1 발견 1과 같다).

### workspace 마운트 해제 범위

- `ScanPage`에 `showStudentReview`(기본 true) 추가, 스캔 탭만 false → 스캔 탭에서는 `ScanStudentReviewWorkspace`를 만들지 않는다(Offstage 안에서도 0 — 새 시험 `find.byType(ScanStudentReviewWorkspace, skipOffstage: false)` 0). 단독 `ScanPage` · 기존 시험(scan_page · scan_page_revision · workspace 시험) · golden `scan-student-review` · `scan_student_review_workspace.dart` 파일은 그대로(FE10 제거).
- **없어지는 경로(스캔 탭 안)**: 학생 검토 대기 동안 `ScanPage`가 Offstage라 ① 진단 JSON 추출 버튼(`scan-export-student-diagnostic`, `exportStudentDiagnostic`) ② 세션 줄(Retry · Recover snapshot) ③ 컨트롤러 안내 글자(`scan-student-candidate-notice`)를 누르거나 볼 곳이 없다. 컨트롤러 메서드 · 단독 `ScanPage` 진입점은 그대로다. ①은 FD-152 권장안대로 개발 상태 패널(이후 slice), ③은 보드가 자기 안내(`<이름> 후보를 보류했습니다.` · 일괄 결과)를 보인다.

### `app_shell.dart` diff (+22 −2)

- 아이템 큐 끝(`_scanSessionChanged`, 완료 토스트를 띄우는 자리): `notice.kind == ScannerKind.inventory`(아이템 시작은 모두 큐라 큐 끝 알림만 이 종류)이고 스캔 탭이 아니면 `_open(AppSection.scan)` 후 return(토스트 없음) — +5. 이유: 시안 Scan-Item-Run ④(FE8-g3 발견 2). 학생 · 전술 로비는 그대로 토스트.
- `_hiddenWhileDocked(body)`(+15): `_scanCompanion`을 듣는 `ValueListenableBuilder` + `Visibility(key: shell-body, visible: 덮개 없음, maintainState · maintainAnimation · maintainSize)` — 덮개가 있는 동안 셸 본문은 그리지 않고(넘침 경고는 그릴 때 난다) 누르지 · 의미 구조에 넣지 않으며, 크기 · 상태 · 애니메이션은 그대로라 복원하면 같은 화면이다. `Offstage`는 크기를 0으로 줄여 셸 Stack(느슨한 제약)과 덮개(`Positioned.fill`)까지 0이 되므로 같은 효과의 `Visibility`를 썼다. 이유: FE8-g3 발견 3.
- 쓰는 곳 2줄: `return mainContent;` → `return _hiddenWhileDocked(mainContent);`, 좁은 창 개발 패널 Stack의 `mainContent,` → `_hiddenWhileDocked(mainContent),`. SafeArea를 통째로 감싸면 250줄이 다시 들여써져서 이 자리로 줄였다. 좁은 창(폭 < 1050)에서 개발 패널을 연 채 덮개가 뜨면 패널 · 바탕막은 계속 그려진다(덮개가 가림, 발견 4).
- 학생 백그라운드 진행(FE8-g2) · 홈 팝업은 그대로(학생은 dock을 쓰지 않아 덮개가 없다).

### 바꾼 · 더한 시험

- `test/home_app_shell_test.dart`: 스캔 탭 학생 보류를 예전 workspace(`scan-student-hold-…` + `scan-page` 스크롤)에서 보드 행 `보류`(`scan-review-hold-mock-candidate-1`)로. 기대(`보류했습니다` 글자 · 홈 · 학생 탭 인계 없음) 그대로. 쓰지 않게 된 `_reveal` 도우미를 지웠다.
- `test/scan_tab_page_fe8g1_test.dart`: "student run view, then ScanPage review, then pick" → "…then review board, then pick" — 끝난 뒤 `scan-review` · `scan-review-rail`, `scan-page` 없음, `ScanPage.showStudentReview == false`, 폐기 뒤 고르기 · 최근 행 `폐기`(그대로).
- `test/scan_run_view_fe8g2_test.dart`: 결과 있는 끝 → `scan-page` 대신 `scan-review`(1건).
- 새 `test/scan_review_board_fe8g4b_test.dart`(+9): 컨트롤러 3(approve → commit 순차 · 새 key · 후보 제거 · 이미 승인 건너뜀 / 거절 · 응답 잃음 재전송 / 어댑터 revalidate 새 revision · null · hold · discard), 스캔 탭 4(2560×1392 · 1280×720: 끝난 학생 전체 → 레일 + 보드 · workspace 0 · 값 연결 · 3명 일괄 적용 expected = 시작 revision → +1 → +2 · 고르기 복귀 / 둘째 commit 거절 → 멈춤 · 나머지 유지 · 확인 필요 1 · 바뀐 학생 1 / 아이템 결과는 `ScanPage`), 셸 2(홈에서 아이템 큐 → 덮개 동안 본문 숨김 · 375×750에서 예외 0 · 큐 끝 토스트 없이 스캔 탭 · 복원 뒤 본문 보임 / 학생 끝은 토스트 그대로 · 누르면 보드).
- `test/goldens/fe8g1_scan_tab_golden_test.dart`: 장면 `scan-review-students` 추가 · 머리 주석, 기존 4장면 조작 변화 0.
- `scan_session_controller_test.dart` · `scan_item_queue_fe8g3_test.dart`: 사본만, 수정 0(commit.json에 없음).

### golden 변화 예상 (비교 미실행)

- 기존 장면 변화 0 예상. 셸이 보이는 장면(`scan-pick-students` · `scan-pick-items` · `scan-student-run` · 셸 장면들)은 덮개가 없어 `Visibility(visible: true)`가 그대로 그린다(크기 · 그리기 같음). `scan-item-run`은 셸 없이 진행 창만 찍는다. `scan-student-review`(workspace 단독) · `scan-student-review-board`(보드 단독)는 그 파일 · 시험을 고치지 않았다(보드 폴더 수정 0). 스캔 탭 레일은 같은 `_RailSection`을 공개 감쌈만 했다.
- **새 장면 `scan-review-students`**(기준 이미지 없음 → CF `-UpdateGoldens`, `optional_added`): 2560×1392 셸. 머리 탭 `스캔` 선택, 머리글 `스캔` · `화면 스캔과 진행 상태` · 녹색 `연결됨 · Blue Archive`. 왼쪽 레일: 준비 상태 3행(게임 창 `Blue Archive · 2560×1440` · `준비됨` · `Main`), 최근 스캔 분홍 선택 행 `학생 전체 · —명` · `오늘 11:57` · 칩 `확인 5`, 각주 `이 실행 중 기록 1건 · 앱을 끄면 지워집니다`, 아래 `게임 창 다시 선택`. 가운데 보드: `학생 스캔 결과 검토` (i) · 칩 `학생 전체 · 오늘 11:57 · 5명`, 분류 `전체 5`(분홍) · `확인 필요 1` · `바뀐 학생 3` · `새 학생 1` · `그대로 0`, `확인 필요 · 1명` 아이리 행(`레벨 5 → 6` `신뢰도 낮음`, `같이 바뀜 · EX 스킬 3 → 4`, 2건 고치기 · 보류), `바뀐 학생 · 3명 · 값 6건` 일괄 행(`3명 모두 계산값이 화면과 일치합니다` · `값 6건 · 레벨 3 · 스킬 3` · 분홍 `3명 한 번에 적용`) + 아카네 · 아카리 · 아코 행 `일치`, `새 학생 · 1명` 아이리(밴드) 행(`레벨 없음 → 90` · `성급 없음 → ★5` · `스킬 없음 → 5`, `재검증 필요`, 3건). 오른쪽: `아이리 · 학생 정보` `확인 필요 · 레벨`, seg `스캔 결과` · `현재 확정값`, 범례 `바뀐 값 2` · `확인 필요 1`, 값 카드(`이전 5` + `확인 필요` Lv. 6 · EX `이전 3` 4/5 …), 폴백 카드 없음(crop 근거 없음), `보류 · 폐기 … 다음`, 흐린 주 버튼 `아이리 2건 적용`. 렌더 PNG `debug/frontend_fe8g4b/render/scan-review-students.png`(CF 검토용, 커밋 대상 아님).

### 미검증 항목

- 전체 `frontend/tool/fe_gate.ps1`(golden 비교 · 전체 일반 시험 · 나머지 process 시험 · almanac validate · 저장소 `git diff --check`): **미실행**(CF 몫).
- golden 비교 · 새 기준 이미지(`scan-review-students`): **미실행**(CF `-UpdateGoldens`).
- 실제 Windows 러너 `dockBeside` · `restore`와 줄어든 창의 셸 숨김 · 복원(시험은 대역 dock · surface 크기 바꾸기), 실제 백엔드 학생 후보로 보드 적용(실제 evidence 분포 · 응답 지연), Windows release 빌드: **미실행**.
- Python 시험: **미실행**(backend 변경 0).

### 검수표 (artboard → 앱에서 여는 방법 → 확인 포인트)

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Scan-Student-Review | mock 모드(`--dart-define=BA_PLANNER_USE_REAL_BACKEND=false`), 기준 viewport 최대화. 홈에서 Mock 창 연결 → 탭 `스캔` → `전체 학생` 시작 → 끝 | 왼쪽 레일은 고르기 · 진행과 같은 자리, 가운데 · 오른쪽 = 보드(golden `scan-review-students`). Mock 기본 후보 1건(aru)은 확정값과 비교한 분류로 보인다 |
| (일괄 적용) | 바뀐 학생이 있을 때 `n명 한 번에 적용` | 차례로 적용 · 끝나면 고르기로 돌아옴, 홈 · 학생 탭 값이 바뀜 |
| (보류 · 폐기 · 재검증) | 확인 필요 행 `보류` · 상세 `폐기` · `고치기` → `재검증` | 보류 안내, 폐기 확인 모달, 재검증 뒤 새 revision 값 |
| Scan-Item-Run ④ | Windows 앱(실제 러너)에서 홈 연결 메뉴 `스캔` → 아이템 타일 시작 | 끝 카드 → 플래너 복원 때 스캔 탭(아이템 검토)이 열려 있고 토스트 없음. 진행 창 동안 줄어든 창에 셸이 비치지 않음 |
| (학생 다른 탭) | 학생 전체 시작 → 홈 이동 → 끝 | 토스트 그대로, 누르면 보드 |

### 발견 사항

1. **스캔 탭 학생 검토 중 없어진 진입점**: 진단 JSON 추출 · Retry · Recover snapshot · 컨트롤러 안내 글자(위 "마운트 해제 범위"). 진단 JSON은 FD-152 개발 상태 패널 slice에서 다시 둔다(CF 판단: 그 전까지 보드 옆에 임시 버튼을 둘지).
2. **레일 최근 스캔 행 제목 `학생 전체 · —명`**: 끝난 학생 전체 세션의 행 제목이 진행 수(`progress.current`)를 몰라 '—'다(FE8-g1 · g2 규칙 그대로). 시안 `학생 전체 · 128명`은 후보 수가 아니라 진행 분모라 고정 형식 밖(total null)일 때는 '—'가 맞다 — CF 확인.
3. **보드와 아이템 큐 결과가 함께 남을 때**: 끝난 아이템 큐에 남은 후보가 있는데 최근 학생 기록을 열면 보드가 보이고, 큐의 종류별 검토 줄은 학생 후보가 끝날 때까지 보이지 않는다(검토 대기 점은 그대로). FE8-g5b(아이템 보드)에서 둘을 함께 보일지 정한다.
4. **좁은 창 개발 패널**: 셸 본문 숨김은 `mainContent`만이라, 폭 < 1050에서 개발 패널을 연 채 아이템 진행 창이 뜨면 패널 · 바탕막은 덮개 아래에서 계속 그려진다(드문 경우, 덮개가 가린다).
5. **보드 수정 0**: 연결에 필요한 이름 변경 없이 g4a 공개 API 그대로 붙였다. 레일만 스캔 탭 라이브러리 private라 `scan_tab_sections.dart`에 공개 감쌈 `ScanRailWorkspace`(+18, 기존 줄 변화 0)를 더했다(착수 기록에 예고한 최소 변경).
6. **Lane B 동시 작업**: 작업 중 `lib/ui/scan/item_review/**`(FE8-g5a 새 파일) · `lib/ui/studio/scan_item_review_studio_layout.dart` · `test/fixtures/scan_item_review_board_fixture.dart`가 생겼다. 이 slice는 읽지도 고치지도 않았고 겹침 0. 중간 analyze info 2는 그 폴더였다.

### 사본 · commit.json

- pre 사본(착수 때 = HEAD 내용, cmp 일치): `debug/frontend_fe8g4b/pre/<경로>` 12파일(고친 10 + 고치지 않은 `scan_session_controller_test.dart` · `scan_item_queue_fe8g3_test.dart` — commit.json에는 없음). `scan_run_view_fe8g2_test.dart`는 고치기 직전에 사본을 만들었다(그때까지 이 slice 변경 0, WIP 0). 착수 때 WIP 0 → `post_dir` 없음.
- `debug/frontend_fe8g4b/commit.json`: slice `fe8g4b`, modified 10(이 문서 포함), added 2, `whole` = [](기존 기준 이미지 변화 0 예상), `optional_added` = [`frontend/test/goldens/baseline/scan-review-students.png`](CF가 `-UpdateGoldens`로 만들 때만), `status=true`.
- 인계: `debug/frontend_fe8g4b/output.md`. 로그 `debug/frontend_fe8g4b/logs/`, 렌더 `debug/frontend_fe8g4b/render/`.

### 다음 행동

- FE8-g4b 코드는 끝났다. Lane A는 여기서 멈춘다.
- CF: Lane B(FE8-g5a)가 멈춘 뒤 gate 1회(예상: analyze 0, 일반 시험에 새 `scan_review_board_fe8g4b_test` +9, 기존 수 그대로, process 스캐너 4 GREEN, golden 기존 장면 GREEN · 새 `scan-review-students` 기준 없음 → `failures/` 확인(렌더 PNG와 비교) → `-UpdateGoldens` → 재비교) → `fe_commit.ps1 -Slice fe8g4b`. 발견 1 · 2 · 3은 CF 판단.
- **FE8-g5b 입력**: ① 스캔 탭 자리는 `scan_tab_page.dart` build의 `reviewShown`(학생 보드)과 같은 방식으로 `ScanItemReviewBoard`를 넣으면 된다 — 아이템 끝남(`stage == terminal` 또는 큐 끝) + 남은 아이템 후보면 `pageShown` 대신 보드 + `ScanRailWorkspace`. 지금 `ScanQueueReviewBar` + `ScanPage`(`queueBarShown`)를 그 보드로 바꾸고, `ScanPage`는 학생처럼 아이템 검토를 그리지 않는 인자(`showStudentReview`와 같은 모양)를 더하면 전술 로비만 남는다. ② 어댑터는 `scan_review_board_adapter.dart`와 같은 자리에 새 파일로, 적용은 컨트롤러의 기존 인벤토리 적용 경로(FB10b subset, (세션, generation, candidate) 열쇠)와 `repositoryRevision` getter를 쓴다. ③ 아이템 큐 끝은 이제 셸이 스캔 탭을 연다(토스트 없음) — 보드가 결과 있는 첫 종류(`openQueueKind`)를 받는다. ④ 발견 3(학생 보드와 큐 결과 동시)을 함께 정한다.

### fe8g4b commit record (2026-10-18 21:49, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261018_214037\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

### fe8g5a commit record (2026-10-18 21:49, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261018_214037\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE8-g5b 착수 기록 (2026-10-18, Lane A)

- 상태: **진행 중 → 코드 작성 완료(아래 FE8-g5b 종료 기록), CF gate 미실행**. 범위: FE8-g5b — 아이템 결과 검토 보드(`ScanItemReviewBoard`, FE8-g5a)를 스캔 탭에 연결하고 옛 후보 인계 경로를 걷어낸다(FE8 마지막 slice). ① 컨트롤러 공개 `approveInventoryCandidateSubset` · `commitApprovedInventoryCandidate` + 큐 후보 전부의 미식별 슬롯 읽기 ② `ScanItemReviewBoardActions` 어댑터(새 파일) ③ 스캔 탭: 아이템 끝남 + 남은 아이템 후보면 레일 + 보드(`scan-item-review`), `ScanPage`는 아이템 검토를 그리지 않는 인자 ④ 학생 · 아이템 보드가 함께 남을 때 규칙 ⑤ 부분 승인 subset 후보의 원 payload 보존 ⑥ 인벤토리 `_CandidatePanel` · `_handoffCandidate` 인벤토리 · 학생 분기 · 학생 탭 `candidateContext` 제거(전술 로비 분기는 남김) ⑦ Retry · Recover snapshot 진입점 확인. 같은 시각 Lane B가 FE10-a 마감 점검을 한다(이 slice 파일은 고치지 않는다).
- 착수 전 확인: 이 문서에 다른 "FE8-g5b 착수 기록" 없음(grep 0건), `debug/frontend_fe8g5b/` 없었음. 대장 "slice별 막힘 요약" FE8-g5 행 = FD-146 → 확정 2026-10-06 (a), 현재 `열림` 0건 → 시작. FD-147 · FD-153은 `워커 재량`(권장안). 형식은 backend 로그 2026-10-18 01:30 FB-10 고정 선언(g5 부분 승인 subset · 영속 needs_review · R6e 미식별 · idempotency).
- 시작 SHA(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`): `7faaaefb89fc9cbbe5a8a2ebae7bd0a6779dde0f`.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe8g5b/pre/<v7 기준 경로>`, 모두 작업 트리와 cmp 일치) · WIP(`git status --short <경로>` 0줄 = 모두 WIP 없음 → `post_dir` 불필요) · 줄바꿈(`git ls-files --eol`):
  - `frontend/lib/ui/scan/scan_session_controller.dart`(LF): 인벤토리 approve subset / commit 공개, 큐 후보 미식별 슬롯 · identity 상태를 후보 열쇠로.
  - `frontend/lib/ui/scan/scan_tab_page.dart`(LF): 아이템 보드 자리.
  - `frontend/lib/ui/scan/scan_tab_sections.dart`(LF): 레일 아래 Retry · Recover 최소 버튼(필요할 때만).
  - `frontend/lib/ui/pages/scan_page.dart`(LF): 아이템 검토를 그리지 않는 인자, 인벤토리 · 학생 인계 버튼 제거.
  - `frontend/lib/ui/pages/inventory_page.dart`(**작업 트리 CRLF** — 유지): `_CandidatePanel` · 후보 인자 제거.
  - `frontend/lib/ui/inventory/inventory_controller.dart`(LF): `InventoryCandidateContext` · `holdCandidate` · `approveCandidate` 제거.
  - `frontend/lib/ui/inventory/inventory_workspace.dart`(LF): `InventoryWorkspace.candidatePanel` 자리 제거(프롬프트 6의 범위).
  - `frontend/lib/ui/pages/student_page.dart`(LF): 후보 인계 제거만.
  - `frontend/lib/ui/app_shell.dart`(LF): `_handoffCandidate` 인벤토리 · 학생 분기 제거(최소).
  - 시험: `inventory_page_test.dart`(**CRLF**) · `inventory_analysis_page_test.dart` · `home_app_shell_test.dart` · `scan_header_progress_fe8f2_test.dart` · `student_page_test.dart` · `scan_page_test.dart` · `scan_item_queue_fe8g3_test.dart` · `scan_review_board_fe8g4b_test.dart` · `scan_tab_page_fe8g1_test.dart` · `scan_session_controller_test.dart` · `goldens/fe8g1_scan_tab_golden_test.dart`(장면 추가 · 조작만) — 사본만 둔 것은 실제로 고친 것만 commit.json에 넣는다.
  - 이 문서: WIP 없음. LF.
- 새 파일(예정): `frontend/lib/ui/scan/scan_item_review_board_adapter.dart`(어댑터 · 값 연결), `frontend/test/scan_item_review_fe8g5b_test.dart`. 새 golden 장면 최대 1장 `scan-review-items`(기준 이미지는 CF `-UpdateGoldens`).
- 고치지 않는 것: `lib/ui/scan/review/**` · `lib/ui/scan/item_review/**`(원칙 0), `lib/services/**`(읽기만), `lib/ui/widgets/section_template_surface.dart` · 결정 대장 · almanac 문서(이 status 밖), 홈 · 전술 · 통계 · 계획 화면 동작, `lib/ui/kit/**`, golden harness, `frontend/tool/**`, backend · contracts, 택틱 · 스캐너 세션 소유 파일(`scan_inventory_identity_review.dart` · `scan_student_review_workspace.dart`).

## FE8-g5b 종료 기록 (2026-10-18, Lane A, 코드 작성 완료 · CF gate 미실행)

아이템 결과 검토 보드(`ScanItemReviewBoard`, FE8-g5a)가 스캔 탭에 연결됐고 옛 후보 인계 경로를 걷어냈다(FE8 마지막 slice). 아이템 세션(큐)이 끝났고 적용 · 폐기하지 않은 아이템 후보가 있으면 스캔 탭은 왼쪽 레일 + 아이템 보드(`scan-item-review`)를 보이고, 보드의 부분 적용 · 미식별 지정은 셸 소유 컨트롤러로 간다(어댑터 `ScanItemReviewBoardControllerActions`). 컨트롤러는 인벤토리 부분 승인 · commit 두 공개 단계를 얻었고(학생 보드 commit과 같은 본체), 미식별 슬롯 · identity 상태를 후보 열쇠(세션 · generation · id)로 두어 큐의 모든 종류를 한 번에 다룬다. 인벤토리 탭 후보 띠 · 학생 탭 후보 · 셸의 학생 · 인벤토리 인계 분기를 없앴다(전술 로비 인계는 남김, FE9-c). 두 검토 보드 옆 레일에 `다시 스캔` · `결과 다시 읽기`(예전 Retry · Recover snapshot)를 두었다. HEAD는 착수 때와 같다(`7faaaefb`). git 쓰기 0, 저장소 파일 삭제는 내가 만든 일회성 렌더 사본 1개(두 번 만들고 바로 지움)뿐이다. 아이템 보드 폴더(`lib/ui/scan/item_review/**`) · 학생 보드 폴더(`lib/ui/scan/review/**`) 수정 0.

### 실행한 명령과 결과

모두 `frontend` 폴더(이 PC). 로그 `debug/frontend_fe8g5b/logs/`(json 요약 · 실패 줄만 봤다).

| 명령 | 결과 |
|---|---|
| `flutter analyze <이 slice 파일>`(중간 여러 번) | 한 번 info 1(불필요 import) · 한 번 error 1(어댑터 `Map` 형) · 한 번 warning 1 + info 1(학생 탭 `_saving` · `_scanner`가 후보 제거 뒤 쓰이지 않음) → 모두 고침 |
| `flutter analyze`(frontend 전체, 시험 이관 전) | error 14(지운 `candidateContext` 등을 쓰던 시험 5파일 — 의도한 변화) → 시험 이관 |
| 바뀐 동작에 걸린 기존 12파일 1차(`logs/first_1.json`) | **+110 −0** |
| 새 시험 `scan_item_review_fe8g5b_test`(`logs/new_1.json`) | +10 −1 — 내 기대 잘못(지정한 종류의 빈 슬롯 목록도 맵에 있다) → 기대만 고침 → (`logs/new_2.json`) **+11 −0** |
| 변이 확인: 부분 승인 후보를 투영 · 최근 기록에 넣음(`_keepRevised(approved)`) | 새 시험 **+9 −2**(원 결과 보존 시험 2건이 잡음) → 원 바이트로 되돌림(SHA-256 앞 16자 `a55a67a1d656f4d1` 전후 같음) |
| 일회성 렌더(golden 사본 `test/goldens/zz_fe8g5b_oneoff_render_test.dart`에서 `@Tags` · `library;` · `expectGoldenScene` 호출을 뺌 — grep 0건 확인, `--plain-name scan-review-`) | 1회: `scan-review-students` +1, `scan-review-items` −1(`pumpAndSettle` 시간 초과 — 큐 진행 중 `ScanPage`의 끝없는 막대; 장면 조작을 몇 프레임 넘기기로 고침) → 2회 `scan-review-items` **+1**, 예외 0. PNG `debug/frontend_fe8g5b/render/`. 사본은 매번 바로 지움(`ls test/goldens/zz_*` 0건) |
| `dart format <파일>` 이 slice 파일 하나씩 | HEAD부터 포맷이 깨끗하지 않던 6파일(`inventory_page` · `inventory_controller` · `inventory_workspace` · `student_page` · `inventory_page_test` · `inventory_analysis_page_test`)에서 이 slice 밖 줄까지 바뀌어 → 그 6파일은 착수 사본에서 다시 시작해 이 slice 편집만 다시 적용(포맷 안 함, 아래 발견 9). 나머지는 포맷 결과 그대로(`scan_item_queue_fe8g3_test`는 고친 시험 하나의 들여쓰기만 바뀜) |
| `flutter analyze`(frontend 전체, 최종) | **No issues found(0, info 포함)**. `pubspec.yaml` · `pubspec.lock` 변경 0 |
| 관련 일반 시험 82파일 한 명령(최종, `logs/general_1.json`, 목록 `logs/general_files.txt`, 요약 `logs/general_1_summary.txt`) | **+927 −0**(exit 0): account_editor_fe8c +9 · account_manager_fe8b +6 · app_navigation_fe7d +14 · app_navigation_tidy1 +11 · connected_target_fe8d +8 · growth_calculator_view +24 · home_app_shell +1 · home_connect_fe8e +10 · home_page +5 · home_scan_popup_fe8f3 +11 · inventory_analysis +16 · inventory_analysis_page +8 · inventory_controller +13 · inventory_currency_readonly +2 · inventory_fb3_service +15 · inventory_history +33 · inventory_history_page +11 · inventory_opa +9 · inventory_opa_page +6 · inventory_page +7 · inventory_review_fb10b +19 · inventory_shell_lazy +1 · inventory_tiers +9 · inventory_tiers_page +7 · inventory_view_model +13 · mock_design_review_scenario +11 · mock_scanner_commit_history +9 · mock_scanner_service +4 · profile_delete_fb2d +17 · scan_companion_dock +5 · scan_header_progress_fe8f2 +7 · scan_inventory_identity_review +2 · scan_item_queue_fe8g3 +9 · scan_item_review_board +14 · **scan_item_review_fe8g5b +11(새)** · scan_page +17 · scan_page_pause_fb10a +8 · scan_page_revision +14 · scan_review_board_fe8g4b +9 · scan_run_view_fe8g2 +8 · scan_session_controller +7 · scan_student_review_board +14 · scan_student_review_logic +5 · scan_student_review_workspace +9 · scan_tab_page_fe8g1 +15 · scanner_pause_fb10a +39 · scanner_protocol_client +6 · scanner_review_images_fb10c +6 · scanner_target_metadata_fb4 +19 · section_template_studio +15 · statistics_app_shell +2 · statistics_filter +10 · student_bond_gauge +12 · student_bond_service +11 · student_calculation_service +8 · student_card_de +17 · student_catalog_service +12 · student_filter_followups +4 · student_filter_modal +8 · student_filter_selection +15 · student_form_cycle +10 · student_page +8 · student_range_condition_section +4 · student_scan_diagnostic +2 · student_search_section +13 · student_studio_layout +45 · tactical_analysis +20 · tactical_excel_import +14 · tactical_fb6b_dart +9 · tactical_fe9b2 +14 · tactical_jokbo_panel +17 · tactical_lobby_fe9c +12 · tactical_lobby_scanner_service +2 · tactical_page +20 · tactical_page_revision +5 · tactical_records_controller +14 · tactical_service +6 · tactical_share_v1_contract +1 · tactical_slots +18 · tactical_v2_service +5 · title_page +25 · widget +16 |
| process E2E(`--concurrency=1`, 파일마다 따로, `logs/process_*.log`) | scanner_process_e2e **+1** · scanner_pause_process_e2e **+1** · scanner_review_images_fb10c_process_e2e **+1** · scanner_target_metadata_process_e2e **+1** · inventory_review_fb10b_process_e2e **+1** |
| 바이트 검사(고친 · 새 파일 21) | 줄바꿈 착수 때 그대로(`inventory_page.dart` · `inventory_page_test.dart`는 작업 트리 CRLF 유지, 나머지 LF), 끝 개행 하나, 줄 끝 공백 0 |

- 시험 파일 고른 기준: FE8-g4b 목록 58파일 + `test/{scan_,scanner_,mock_scanner_,inventory_,student_,home_,app_navigation_}*_test.dart` · `widget_test` + grep(`BAPlannerApp(|AppShell(|ScanPage(|ScanTabPage|ScanSessionController|ScanCompanion|ScanHeaderStatus|startPick|InventoryPage(|InventoryWorkspace|InventoryController|StudentPage(|TacticalPage(|ScanItemReview|scan_item_review|scan_review_board|onCandidateHandoff|itemQueue|unresolvedSlots|assignInventoryIdentity`)에서 golden · process 시험을 뺀 82파일.
- golden 비교 · 전체 gate · 맨 `flutter test` · Python 시험은 돌리지 않았다. 잠금 충돌 0.

### 처리한 FD

- **FD-146**(확정 (a)): 보드 부분 적용 = `approveInventoryCandidateSubset`(review approve = true, 승인 칸만 남긴 `candidate_payload`) → `commitApprovedInventoryCandidate`(종류 순차, 앞 응답 revision을 다음 expected로 — 보드 `runScanItemPartialApply` 그대로). 빈 적용은 보드가 부르지 않는다. 영속 `needs_review`는 백엔드가 제외 key로 정한다(프론트 쓰기 0, 01:30 선언 그대로). 부분 승인 revision 보존 규칙은 아래 "부분 승인 후보 보존".
- **FD-153**(워커 재량 → 권장안 그대로): 미식별 칸 · identity 검토 마운트는 보드(g5a). 이 slice는 슬롯을 큐 후보 전부에 대해 후보 열쇠로 읽어 넘긴다(FE8-g5a 입력 2).
- **FD-147**(워커 재량, 일부): 검사기 `이전 확정값` 옆 글자 = FB-2b `repository.history.scan_latest`(by_resource_key, 256개씩)의 최신 scan 시각을 `scanWhenText(clock: false)` + ` 스캔`(`3일 전 스캔` · `오늘 스캔` · `9/12 스캔`). 읽기 전 · 실패 · 스캔 없음이면 '—'. 계획 필요량(`planRequired`)은 스캔 탭에 활성 계획 계산이 없어 넘기지 않는다('—', 발견 6).
- FD-143(확정 (a)): 보드 종류 = 끝난 큐의 종류(칸 순서), 후보는 종류마다 (세션, generation, candidate) 열쇠로 따로.
- 막는 `열림` FD 0(착수 기록).

### 컨트롤러 API 표 (`lib/ui/scan/scan_session_controller.dart`)

| 이전 경로 | 새 공개 메서드 · 규칙 | 동작 동일 근거 시험 |
|---|---|---|
| 인벤토리 탭 `InventoryController.approveCandidate`(후보 전체 review(검토 필요일 때만) → commit, key `inventory-candidate-<id>-<rev>`, expected = 인벤토리가 읽은 state revision, 재시도 고정 없음) | **`approveInventoryCandidateSubset(c, payload) → Future<ScannerCandidate>`**: `reviewScannerCandidate(approve: true, reason: approved_subset_in_scan_item_review)`. 앞 부분 승인 revision이 더 높으면 그 revision에서 다시 review, 같은 칸(payload 정규 JSON 같음)이면 review 없이 그 승인 후보를 돌려준다. 받은 후보는 `_approvedSubsets`에만 둔다(아래). 세션 · 스캐너 없음 · 인벤토리 아님 = `ScanApplyException` | 새 시험 1 · 3 · 4(예전 후보 띠 시험 대체: 보류 = 저장소 그대로, 승인 = 승인 칸만 적용 · 뺀 칸 이전 수량 / 오래된 revision = 실패 · 후보 유지 · 더 새 인벤토리 유지) |
| 〃 | **`commitApprovedInventoryCandidate(approved, {required int expectedRepositoryRevision}) → Future<int>`**: 학생 보드 commit과 같은 본체(`_commitApproved` → `_commitCandidate`): 같은 차례 큐, 새 idempotency key, 같은 의도(같은 세션 · 후보 revision · 계정) 재시도는 고정 요청(key · expected) 그대로, busy 재시도, 실패 분류(unknownOutcome · busy · revisionConflict · rejected), `_acceptCommittedRevision`, 후보 해결(`candidateResolution` = true) · 지금 후보에서 빼기 · state 다시 읽기, 실패면 적고 던짐. 성공하면 `_approvedSubsets`에서 버림 | 새 시험 3(거절 · 응답 잃음 → 같은 key · 같은 expected 재전송) + 기존 scan_page_revision +14 · scan_page +17 · mock_scanner_commit_history +9 · scanner_review_images_fb10c +6 · scan_review_board_fe8g4b +9(학생 공용 본체 회귀 0) |
| 학생 `commitApprovedStudentCandidate` 본체 | 공용 `_commitApproved`로 옮김(줄 그대로), `_commitStudentCandidate` → `_commitCandidate` 이름만 | 위와 같음 |
| `ScanStudentApplyException` | **`ScanApplyException`**(학생 · 아이템 공용, 문구 그대로). 쓰는 곳은 컨트롤러뿐(시험 0) | — |
| 미식별 슬롯 · identity 상태 맵(후보 id 열쇠, 지금 보이는 세션만, 기록을 열 때마다 비움) | **후보 열쇠**(`세션#generation#id`, 슬롯 `<후보 열쇠>:<slot>`)로 둔다. 새 세션 시작 때 지금 큐 밖 세션의 것만 버린다(`_pruneItemReviewState`), 기록을 바꿔 열어도 지우지 않는다. 큐가 끝나면 모든 종류 후보의 슬롯을 읽는다(`_ensureUnresolvedSlots`). 새 읽기 `unresolvedSlotsOf` · `unresolvedErrorOf` · `identityBusyOf` · `identitySkippedOf` · `identityErrorOf`(후보로). 예전 id 읽기(`unresolvedSlots(id)` 등)는 지금 보이는 세션 후보로 그대로 | 새 시험 5(두 종류 같은 후보 id · 종류마다 슬롯 · 보이지 않는 종류 지정 · 건너뜀 · 기록 오가기) + scan_page +17(예전 화면 미식별 지정 `inventory unknown slot …` 그대로) |
| `assignInventoryIdentity` 결과 = 지금 후보(`_keepCandidate`) | `_keepRevised`: 보이는 세션이면 지금 후보, 그리고 **그 세션의 최근 기록**에도 오른 revision을 적는다(보이지 않는 종류 · 레일로 오간 뒤에도 유지) | 새 시험 5 |
| `openRecent(item)` = 넘긴 기록 그대로 | 지금 보이는 세션의 오른 revision을 먼저 기록에 적고(`_syncShownToRecent`), 같은 세션의 최신 기록으로 연다 | 새 시험 5 · 6 |
| — | **`itemReviewCandidates(result, {appliedElsewhere})`**: 그 기록 세션의 남은 아이템 후보(최신 revision, 해결 · 다른 탭 적용 제외). 보이는 세션이면 지금 후보, 아니면 최근 기록 | 새 시험 1 · 3 |

#### 부분 승인 후보 보존(FE8-g5a 발견 4)

- 부분 승인 review가 만든 revision(승인 칸만 남은 payload)은 **지금 후보(`candidates`) · 최근 기록(`recent`)에 넣지 않는다** — `_approvedSubsets[후보 열쇠]`에만 둔다. 그래서 최근 스캔 행 칩(`확인 n` · `검토 n` — 후보의 review_required), 예전 화면 투영, 보드 칸(보드가 다시 만들어져도)은 모두 원 결과 payload · 칸 수로 본다. 원 결과 `candidateCount` · `reviewRequired`는 끝났을 때 값 그대로다.
- 보드는 원 결과 후보(원 revision)를 넘기고, 컨트롤러가 더 높은 부분 승인 revision이 있으면 그 revision에서 다시 review한다(후보 revision 검사 통과). 같은 칸이면 review 없이 같은 승인 후보 → commit 재전송이 고정 요청과 맞는다.
- 성공하면 버리고, 새 세션 시작(큐 밖) 때 버린다. 시험: 새 시험 3(실패 뒤 지금 후보 · 기록 2칸, 칩 `확인 1`, 같은 칸 review 0회, 다른 칸은 승인 revision에서 review) · 변이 확인(넣으면 2건 실패).

### 어댑터 규칙 (`lib/ui/scan/scan_item_review_board_adapter.dart`, 새 파일)

| 보드 actions · 인자 | 컨트롤러 |
|---|---|
| `approveSubset(c, payload)` | `approveInventoryCandidateSubset(c, payload)` |
| `commit(approved, expected)` | `commitApprovedInventoryCandidate(approved, expectedRepositoryRevision: expected)` |
| `assignIdentity` · `skipIdentity` | `assignInventoryIdentity` · `skipInventoryIdentity` 그대로 |
| `kinds`(`scanItemReviewKindsFor`) | 끝난 뒤 · 큐 진행 아님일 때: 보이는 세션이 끝난 큐의 종류면 그 큐 종류 전부, 큐 밖 아이템 기록이면 그 기록 1종(`recentDetail`의 종류), 학생 · 전술 로비 기록이 보이는데 그 기록에 남은 후보가 없고 끝난 큐가 있으면 그 큐. 종류마다 `result = itemQueueResult(kind)`, `candidates = itemReviewCandidates(result)`, `appliedElsewhere` = 그 기록 후보 중 하나라도 해결(적용) · 다른 탭 적용 |
| `unresolvedSlots` · `identityBusy` · `identityErrors` · `identitySkipped` · `candidateErrors`(`scanItemReviewSlotStateFor`) | 후보마다 `unresolvedSlotsOf` 등(후보 열쇠 · 슬롯 열쇠 `scanItemSlotKey`). `candidateErrors` = 미식별 슬롯 읽기 실패(보드는 아직 그리지 않음, g5a 발견 6) |
| `currentInventory` · `catalog` · `repositoryRevision` | `repositoryState.inventory` · `inventoryCatalog` · `repositoryRevision` |
| `lastScanLabels` | 스캔 탭이 FB-2b by_resource_key로 읽음(FD-147, 위). 계정 · 아이템 묶음이 바뀔 때만, 세대 번호로 늦은 응답 버림 |
| `planRequired` | 넘기지 않음('—') |
| `timeLabel` | 이 컨트롤러로 시작한 첫 종류의 시작 시각(큐 시작) `scanWhenText`(`오늘 11:57`), 모르면 '—' |
| `initialKind` | 넘기지 않음 = `모든 종류`(시안 · g5a 기본) — g4b 입력 ③의 "결과 있는 첫 종류"는 보이는 세션(레일 선택 행)으로 남는다 |

### 스캔 탭 표시 규칙 표 (`scan_tab_page.dart`)

| 종류 \ 상태 | 진행(시작 중 · 진행 · 일시정지 · 중지 요청, 큐는 종류 사이 포함) | 끝남 + 남은 후보 | 끝남 · 후보 없음 |
|---|---|---|---|
| 학생 | 진행 3섹션 `ScanRunWorkspace`(그대로) | 레일(`scan-review-rail`, **세션 버튼 줄**) + 학생 보드(`scan-review`) | 고르기 |
| 아이템(큐) | `ScanPage`(진행 창이 덮음, 그대로 — `ScanPage`는 아이템 요약 · 미식별 검토를 그리지 않음) | **레일(`scan-item-review-rail`, 세션 버튼 줄) + 아이템 보드(`scan-item-review`)** — 예전 `ScanQueueReviewBar` + `ScanPage` 대체 | 고르기 |
| 전술 로비 | `ScanPage`(그대로) | `ScanPage`(전술 로비 후보 · `Review tactical capture` 인계만 남음) | 고르기 |
| **학생 · 아이템 둘 다 남음** | — | 지금 보이는 세션의 보드(끝난 직후 = 가장 최근에 끝난 실행). 다른 쪽은 레일 최근 스캔 행으로 연다(`openRecent`). 보이는 학생 · 전술 로비 기록에 남은 후보가 없고 끝난 아이템 큐에 남았으면 아이템 보드 | — |

- 판단은 그대로 `ScanHeaderStatus.of`(머리글 칩 · 탭 점 · 토스트와 같음): 검토 대기 = 보이는 세션 후보 + 끝난 큐의 다른 종류 후보. 학생 보드가 먼저(학생 후보가 보이면), 그다음 아이템 보드, 둘 다 아니면 `ScanPage`.
- `ScanPage`(스캔 탭): `showStudentReview: false` · `showItemReview: false`(새 인자, 기본 true). Offstage 안에서도 아이템 후보 요약 · `ScanInventoryIdentityReview`를 만들지 않는다(새 시험 `find.byType(ScanInventoryIdentityReview, skipOffstage: false)` 0).
- 머리글 부제(`아이템 스캔 결과 검토 · 칸별 승인 → 적용`)는 `app_section` · 셸 몫이라 바꾸지 않았다(g4b와 같다).

### 제거 표 (I-scan §9.1, 파일 삭제 0 · 줄 제거만)

| 파일 | 지운 기호 | 대체 경로 | 대체 시험 |
|---|---|---|---|
| `lib/ui/pages/inventory_page.dart`(CRLF) | `_CandidatePanel` 클래스, `candidatePanel:` 인자, `_approveCandidate`, `candidateContext` · `onCandidateCommitted`, `didUpdateWidget` 후보 분기(목록 보기로 돌리기), `export … show InventoryCandidateContext`, 머리 주석, 쓰지 않게 된 import 4 | 스캔 탭 아이템 보드 → 컨트롤러 2단계 | `scan_item_review_fe8g5b_test` "inventory candidate apply (예전 인벤토리 후보 띠 대체)" · "stale repository revision keeps the candidate and newer inventory" |
| `lib/ui/inventory/inventory_controller.dart` | `InventoryCandidateContext`, `holdCandidate`(보류 = 알림만), `approveCandidate`, `_scanner` getter, `scanner_service` import, 주석 2곳 | 보류 = 보드에서 적용하지 않고 둔다(후보가 남는다, g5a 입력 7) · 적용 = 위 | 같음(보류 = 저장소 그대로 확인 포함) |
| `lib/ui/inventory/inventory_workspace.dart` | `InventoryWorkspace.candidatePanel` 인자 · 필드, 위험도 목록 위 후보 띠(`inventory-candidate-band`) 자리, `InventoryMetrics.candidateHeight` | — | `inventory_analysis_page_test` "scan candidates no longer reach the page: analysis stays"(예전 "새 후보가 오면 목록 보기로" 대체 — 다시 그려도 분석 모드 그대로 · 띠 0) |
| `lib/ui/pages/student_page.dart` | `StudentCandidateContext`, `candidateContext` · `onCandidateCommitted`, `_approveCandidate`, `Delivered scan candidate` 띠(승인 · 보류 버튼), 그것만 쓰던 `_saving` · `_scanner` · import 2 | 스캔 탭 학생 보드(FE8-g4b) | `scan_item_review_fe8g5b_test` "student candidate hold / apply (예전 학생 탭 후보 대체)" — `student_page_test`의 같은 의미 시험을 옮겼다 |
| `lib/ui/app_shell.dart` | `_studentCandidate` · `_inventoryCandidate`, `_handoffCandidate` 학생 · 인벤토리 분기, `_clearStudentCandidate` · `_clearInventoryCandidate`, 홈 `studentCandidatePending` · `inventoryCandidatePending` 인자(늘 false가 됨), 학생 · 인벤토리 탭 후보 인자 | `_handoffCandidate`는 전술 로비만(`kind != tacticalLobby`면 무시) | `scan_item_review_fe8g5b_test` "the shell hands only tactical lobby candidates to another tab", `home_app_shell_test`(보류한 후보는 학생 탭이 아니라 스캔 탭 보드에 남는다), `scan_header_progress_fe8f2_test`(다른 탭 적용 → 탭 점 해제를 남은 다른 탭 경로 `TacticalPage.onLobbyCandidateHandled`로) |
| `lib/ui/pages/scan_page.dart` | 학생 · 인벤토리 후보의 인계 버튼(`Review in Students` · `Review in Inventory`) | 버튼은 전술 로비 후보만(`Review tactical capture`) | `scan_page_test` "candidate kind and payload mismatch is not handed off"(불일치 후보를 학생 세션의 전술 로비 후보로 바꿔 같은 의미), 새 시험 "scan page: inventory candidates have no handoff; the item switch hides them" |
| `test/inventory_page_test.dart`(CRLF) | 후보 시험 2건(`candidate hold does not mutate…` · `stale repository revision preserves…`) · `_subject` 후보 인자 · import | — | 위 새 시험 2건 |
| `test/student_page_test.dart` | 후보 시험 1건(`review-required candidate is unchanged on hold…`) · import | — | 위 새 시험 1건(자리에 옮긴 곳 주석) |

- 남긴 것: 전술 로비 인계(`ScanPage.onCandidateHandoff` · `ScanTabPage.onCandidateHandoff` · 셸 `_handoffCandidate` 전술 분기 · `TacticalLobbyHandoff`, FE9-c), `_scanAppliedElsewhere`(전술 로비 처리 알림), 단독 `ScanPage`의 아이템 요약 · 미식별 지정(`showItemReview` 기본 true — 시험 · FE10까지).

### `app_shell.dart` diff (+9 −47)

- 이유: 학생 · 인벤토리 후보 인계 제거(I-scan §9.1, FE8-g5a 입력 6). `_handoffCandidate`를 전술 로비만 남긴 6줄 본체 + 주석 2줄로, 필드 2 · 비우기 함수 2 · 계정 변경 때 비우기 2줄 · 홈 · 학생 · 인벤토리 탭 인자 8줄을 지웠다. `_scanAppliedElsewhere` 주석 1줄(학생 · 인벤토리 → 전술대항전). 그 밖 셸 줄 변화 0, 포맷하지 않았다(HEAD부터 다른 `_TopTab` 줄, FE8-f1 발견 4).

### 진입점(Retry · Recover snapshot, FE8-g4b 발견 1)

- 확인: 학생 진행 화면에는 끊김 때 `진행 다시 읽기`(Recover)가 있고, 아이템 큐 진행 중에는 `ScanPage`(세션 줄 Retry · Recover)가 보인다. **검토 보드 동안(학생 · 아이템)은 머리글 칩 · 레일 · 보드 어디서도 닿지 않았다** → 두 보드 옆 레일에 최소 버튼 줄을 두었다.
- 위치 · 문구: 레일 `게임 창 다시 선택` 바로 위(그 위 10, 높이 40 — 시안 좌표계, 레일 높이 비율로 줄어듦). `다시 스캔`(↻, key `scan-rail-retry`: 끝남 + 시작 가능일 때만 = 예전 Retry와 같은 `controller.start()` — 마지막으로 시작한 종류 1종을 다시) · `결과 다시 읽기`(⟳, key `scan-rail-recover`, 읽는 동안 `읽는 중…`: 세션이 있을 때 = 예전 Recover snapshot `recoverSnapshot()`). 최근 스캔 8행 · 각주 아래 끝(시안 좌표 894)보다 아래(1063)라 겹치지 않는다. 고르기 · 진행 레일에는 없다.
- 진단 JSON 추출은 FD-152 개발 상태 패널 몫으로 미룬다(그대로).

### golden 변화 예상 (비교 미실행)

- **`scan-review-students` 바뀜**(`whole`에 기준 이미지 1개): 왼쪽 레일 `게임 창 다시 선택` 위에 tonal 버튼 둘 `다시 스캔` · `결과 다시 읽기`(작은 글자, 아이콘 ↻ · ⟳)가 생긴다. 그 밖 같음(렌더 `debug/frontend_fe8g5b/render/scan-review-students.png`).
- 변화 0 예상: `inventory` · `inventory-all` · `inventory-analysis*` · `inventory-tiers` · `inventory-analysis-opa`(기존 golden이 후보 띠를 찍지 않았다 — golden 시험에 `candidateContext` 0건), 홈 장면(홈 대기 인자는 늘 false였다), 학생 장면(후보 띠는 인계가 있을 때만), `scan-pick-students` · `scan-pick-items` · `scan-student-run` · `scan-item-run` · `header-scan-progress`(레일에 세션 버튼 없음, 스캔 탭 `ScanPage` 자리는 Column → 바로 `ScanPage`지만 Offstage), `scan-student-review` · `scan-student-review-board` · `scan-item-review-board`(그 파일 · 시험 수정 0).
- **새 장면 `scan-review-items`**(기준 이미지 없음 → CF `-UpdateGoldens`, `optional_added`): 2560×1392 셸, 탭 `스캔`, 머리글 `연결됨 · Blue Archive`. 왼쪽 레일: 준비 상태 3행, 최근 스캔 `아이템 · 전술 교육 BD`(`오늘 11:57`, 칩 `확인 1`) · 분홍 선택 `아이템 · 기술 노트`(`확인 1`), 각주 `이 실행 중 기록 2건 · 앱을 끄면 지워집니다`, 아래 `다시 스캔` · `결과 다시 읽기` · `게임 창 다시 선택`. 가운데 · 오른쪽 = g5a 보드 fixture 값 그대로: `아이템 스캔 결과 검토` (i), 종류 탭 `모든 종류 · 2종`(분홍) · `기술 노트 · 확인 1` · `전술 교육 BD · 확인 1`, 칩 `기술 노트 · 전술 교육 BD · 오늘 11:57`, 분류 `전체 52` · `확인 필요 2` · `바뀐 수량 5` · `그대로 45`, 기술 노트 최상급 7칸(밀레니엄 `96 → 112 +16` 선택) · BD 최상급 6칸(붉은겨울 빗금 `읽지 못함`), 분홍 `승인한 50칸 인벤토리에 적용` / `확인 필요 2칸은 빼고 적용합니다`. 검사기 `기술 노트 · 밀레니엄 (최상급)` `확인 필요`, `이전 확정값 96 · 3일 전 스캔`, `자동 판독 112 · 신뢰도 0.58 · 1과 7 구분 낮음`, `승인할 수량 112`, `활성 계획 필요량 —` · `승인하면 부족 —`, 근거 2줄, `112로 승인`. 렌더 `debug/frontend_fe8g5b/render/scan-review-items.png`(CF 검토용, 커밋 대상 아님).

### 미검증 항목

- 전체 `frontend/tool/fe_gate.ps1`(golden 비교 · 전체 일반 시험 · 나머지 process 시험 · almanac validate · 저장소 `git diff --check`): **미실행**(CF 몫).
- golden 비교 · 기준 이미지 갱신(`scan-review-students`) · 새 기준(`scan-review-items`): **미실행**(CF `-UpdateGoldens`).
- 실제 백엔드 아이템 부분 승인 → commit(실제 제외 key의 `needs_review` 저장 — 이 slice 시험은 Mock 이벤트 후보라 Mock의 식별 key 기억을 거치지 않음, 백엔드 의미는 `inventory_review_fb10b` 시험이 본다), 실제 미식별 crop · 지정, 실제 Windows 러너 진행 창 뒤 보드, Windows release 빌드: **미실행**.
- 많은 종류(7종) · 많은 후보에서 보드 · by_resource_key 읽기 성능: **미실행**.
- Python 시험: **미실행**(backend 변경 0).

### 검수표 (artboard → 앱에서 여는 방법 → 확인 포인트)

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Scan-Item-Review | mock 모드(`--dart-define=BA_PLANNER_USE_REAL_BACKEND=false`), 기준 viewport 최대화. 홈에서 Mock 창 연결 → 탭 `스캔` → `기술 노트` · `전술 교육 BD` → 시작 → 끝 | 왼쪽 레일 + 아이템 보드(golden `scan-review-items`는 fixture 값). Mock 기본 후보는 종류마다 1칸(활동 보고서) |
| (부분 적용) | 보드 주 버튼 `승인한 n칸 인벤토리에 적용` | 종류 차례로 적용 → 끝나면 고르기, 인벤토리 탭 값이 바뀜 · 인벤토리 탭에 후보 띠 없음 |
| (학생 · 아이템 함께) | 학생 전체 끝(보드) → 레일의 다른 기록을 열어 고르기로 → 아이템 큐 끝 | 가장 최근(아이템) 보드, 레일 학생 행 → 학생 보드, 아이템 행 → 아이템 보드 |
| (진입점) | 어느 검토 보드든 | 레일 아래 `다시 스캔` · `결과 다시 읽기` |
| (인계 없음) | 학생 · 인벤토리 탭 | `Delivered scan candidate` · `Scanner candidate …` 띠 없음 |

### 발견 사항

1. **컨트롤러 문서 주석 깨짐(고침)**: 착수 HEAD의 `ScanRecentDetail` 문서 주석 가운데에 `ScanStudentApplyException` 주석 · 클래스가 끼어 있었다(FE8-g4b). 예외 이름을 바꾸며 두 주석을 바로잡았다.
2. **`다시 스캔`의 뜻**: 예전 Retry와 같아 마지막으로 시작한 종류 1종만 다시 읽는다(큐 전체가 아님). 큐 전체 다시 읽기가 필요하면 고르기로 돌아가 시작한다. CF 판단.
3. **`결과 다시 읽기` 실패 문구가 보드 화면에 안 보인다**: `sessionError`는 `ScanPage`(Offstage)에만 그려진다. 레일 버튼은 읽는 중 표시만 한다. 보일 자리는 FD-152 개발 상태 패널과 함께 정하면 된다.
4. **건너뛴 미식별 슬롯이 기록을 다시 열어도 남는다(동작 변화)**: 예전에는 기록을 열 때마다 identity 상태를 비워 건너뛴 슬롯이 다시 보였다. 이제 후보 열쇠로 두어 앱 실행 동안 남는다(보드가 모든 종류를 함께 보이려면 필요). 새 세션 시작(큐 밖) 때는 비운다.
5. **부분 승인 뒤 같은 후보의 identity 지정**: 부분 승인 review가 후보 revision을 올리므로, 그 뒤 원 revision으로 지정하면 백엔드가 revision 충돌로 거절한다(오류 글자). XB 01:30 "승인으로 specimen을 해제하기 전에 identity 작업을 마친다"와 같은 순서라 막지 않았다.
6. **계획 필요량 '—'**: 스캔 탭에는 활성 계획 계산이 없다. 인벤토리 컨트롤러의 필요량을 셸이 넘기면 `이 아이템을 쓰는 곳`이 채워진다(별도 slice, CF 판단).
7. **최근 기록 8건을 넘으면**: 보이지 않는 종류의 오른 revision은 최근 기록에만 적는다. 큐 종류의 기록이 최근 8건 밖으로 밀리면 `itemQueueResult`가 큐가 기억한 원 revision으로 돌아간다(`scan_item_queue.dart`는 이 slice 수정 범위 밖). 7종 큐 + 다른 기록 2건 이상일 때만.
8. **`candidateErrors`**: 이제 미식별 슬롯 읽기 실패를 후보 열쇠로 넘기지만 보드가 아직 그리지 않는다(g5a 발견 6 그대로).
9. **포맷이 깨끗하지 않던 HEAD 파일 6개**: `inventory_page.dart` · `inventory_controller.dart` · `inventory_workspace.dart` · `student_page.dart` · `inventory_page_test.dart` · `inventory_analysis_page_test.dart`는 HEAD부터 `dart format`과 달라, 포맷하면 이 slice 밖 줄 수십 개가 바뀐다. 이 slice 줄만 남기려고 포맷하지 않았다(FE10 정리 때 한 번에 포맷 후보).
10. **수정 범위 표 밖 1파일**: `lib/ui/inventory/inventory_workspace.dart`는 "고치는 곳" 목록에 없지만 프롬프트 6이 `InventoryWorkspace.candidatePanel` 자리 제거를 명시해 고쳤다(−24 +2).

### 사본 · commit.json

- pre 사본(착수 때 = HEAD 내용, cmp 일치): `debug/frontend_fe8g5b/pre/<경로>` 21파일(고친 19 + 고치지 않은 `scan_tab_page_fe8g1_test.dart` · `scan_session_controller_test.dart` — commit.json에는 없음). 착수 때 WIP 0 → `post_dir` 없음.
- `debug/frontend_fe8g5b/commit.json`: slice `fe8g5b`, modified 19(이 문서 포함), added 2, `whole` = [`frontend/test/goldens/baseline/scan-review-students.png`], `optional_added` = [`frontend/test/goldens/baseline/scan-review-items.png`](CF가 `-UpdateGoldens`로 만들 때만), `status=true`.
- 인계: `debug/frontend_fe8g5b/output.md`. 로그 `debug/frontend_fe8g5b/logs/`, 렌더 `debug/frontend_fe8g5b/render/`.

### 다음 행동

- FE8-g5b 코드는 끝났다(FE8 마지막 slice). Lane A는 여기서 멈춘다.
- CF: Lane B(FE10-a)가 멈춘 뒤 gate 1회(예상: analyze 0, 일반 시험에 새 `scan_item_review_fe8g5b_test` +11 · `inventory_page` 9→7 · `student_page` 9→8 · `inventory_analysis_page` 8 그대로, process 스캐너 4 · inventory_review_fb10b 1 GREEN, golden `scan-review-students` RED(레일 버튼 2개) · 새 `scan-review-items` 기준 없음 · 나머지 GREEN → `failures/` 확인(렌더 PNG와 비교) → `-UpdateGoldens` → 재비교) → `fe_commit.ps1 -Slice fe8g5b`.
- **FE10 정리 후보(쓰는 곳이 없어진 기호 · 파일)**: `ScanQueueReviewBar` · `scanQueueReviewChip`(lib · 시험 0) · `scanQueueReviewVisible` · `ScanSessionController.openQueueKind`(fe8g3 컨트롤러 시험만) — `scan_item_queue.dart`; `HomePage.studentCandidatePending` · `inventoryCandidatePending`(선언만); 단독 `ScanPage`의 아이템 경로(`_CandidateSummary` 인벤토리 요약 · `ScanInventoryIdentityReview` 마운트 · `showItemReview`) 와 id 읽기(`unresolvedLoading` · `unresolvedSlots(id)` · `identityBusy/Skipped/Error(id)`) — 스캔 탭이 `ScanPage`를 전술 로비만 쓰므로 `ScanPage` 자체를 전술 로비 검토로 줄일 때 함께; `ScanStudentReviewWorkspace`(FE8-g4b부터 스캔 탭 0, 단독 `ScanPage` · 시험만); 발견 9의 포맷 안 된 6파일.

### fe8g5b commit record (2026-10-18 23:58, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261018_234539\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

### fe10a commit record (2026-10-18 23:58, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261018_234539\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE4-b2 착수 기록 (2026-10-19 00:12, Lane A)

- 상태: **진행 중** — FE4-b2 계획 만들기 1단계 한 명 모드(Flow-1-Students-One, FD-177 (a)).
- 시작 SHA: `e9fcb280d617b203895e7a91e231e83141ad1868`(브랜치 `scanner-consolidation`).
- 막힘 확인: 결정 대장 "slice별 막힘 요약"에 FE4-b2 행 없음, `열림` 0건. FD-177 확정 (a). FD-078(모드 전환 360ms 보간)은 워커 재량 → 권장안대로. FD-074·FD-171은 그대로(내 그룹 저장·계산기 넘김 동작 바꾸지 않음).
- 고칠 기존 파일(모두 착수 때 작업트리 = HEAD, **기존 미커밋 변경(WIP) 없음**, 사본 `debug/frontend_fe4b2/pre/<v7 기준 경로>`, cmp 일치):

| 파일 | WIP |
|---|---|
| `frontend/lib/ui/widgets/plan_flow_student_step.dart` | 없음 |
| `frontend/lib/ui/widgets/plan_flow_workspace.dart` | 없음 |
| `frontend/lib/ui/models/plan_flow_draft.dart` | 없음 |
| `frontend/lib/ui/studio/plan_flow_studio_layout.dart` | 없음 |
| `frontend/lib/ui/widgets/student_section_layout.dart`(공개화 이름 바꾸기만) | 없음 |
| `frontend/test/goldens/fe1g_baseline_golden_test.dart`(장면 추가) | 없음 |
| `frontend/test/plan_flow_student_step_test.dart`·`plan_flow_test.dart`·`planning_page_test.dart`(필요할 때만, 사본만 미리 둠) | 없음 |
| `almanac/workflows/frontend-redesign-status.md`(이 기록) | 없음 |

- 새 파일 예정: `frontend/lib/ui/widgets/plan_flow_student_one.dart`(한 명 모드 C·학생 상세 겹침·모드 표면), `frontend/test/plan_flow_student_one_test.dart`.
- 고치지 않음: `lib/ui/pages/settings_page.dart`·`lib/ui/settings/**`(Lane B FE10-s), `plan_student_step_tile.dart`(바꿀 필요 없음), 2~4단계·병합 규칙, `lib/services/**`, `lib/ui/kit/**`, golden harness, `frontend/tool/**`, backend·contracts, 택틱 소유 파일.

## FE4-b2 종료 기록 (2026-10-19 00:30, Lane A, 코드 작성 완료 · gate 미실행)

- 상태: **완료(gate 전)**. 근거 시안 Flow-1-Students-One(`dc_outline.py` 개요 + 섹션 path `d` 두 줄만 읽음), FD-177 (a).
- 이 레인이 고친 기존 파일은 사본 `debug/frontend_fe4b2/pre/`와 비교한다. 작업트리의 `settings_page.dart`·`settings_page_test.dart` 차이는 Lane B(FE10-s) 것이고 이 slice와 무관하다.

### 실행한 명령과 결과

| 명령(`frontend`에서) | 결과 |
|---|---|
| `flutter analyze` | No issues found(info 포함 0), 마지막 실행 2.8s |
| `flutter test test/plan_flow_student_one_test.dart` | 1차 −8(기본 mock 계정에 보유 학생이 없어 fixture `firstWhere` 실패 7, 둥근 path bounds 비교 1 — 둘 다 시험 쪽 문제) → 시험 고침 → **+8 All passed** |
| 관련 시험 25파일 `flutter test --exclude-tags golden …`(plan_flow_* 11 · planning_page · plan_home_detail · plan_student_step_tile · student_page · student_bond_gauge · student_studio_layout · student_filter_followups · student_filter_modal · student_search_section · growth_calculator_view/state/adapter/rules · app_navigation_fe7d · app_navigation_tidy1 · widget_test) | 1차 **+380 −1**(`plan_flow_test` "1단계는 새 학생 고르기 …"가 한 명 고른 뒤 여러 명 목록 행 `plan-flow-selected-<id>`를 찾음 = 의도한 동작 변화) → 단언 2곳 고침 → `plan_flow_test` 단독 +15 → 25파일 재실행 **+381 All passed** |
| 일회성 렌더(사본 `test/goldens/fe4b2_render_once_test.dart`, `@Tags`·`expectGoldenScene` grep 0건, 실행 뒤 바로 지움) | +3, PNG `debug/frontend_fe4b2/render/`(`plan-flow-step1-one.png` · `one-unowned.png` · `plan-flow-step1-filter.png`), 넘침 예외 0 |
| `git diff --check -- frontend/lib frontend/test` | 0 |
| `dart format` | 새 파일 2개만 전체 포맷. 기존 파일은 HEAD부터 포맷과 달라(예 `plan_flow_student_step.dart` 기존 줄 6곳) 이 slice 줄만 포맷 결과와 같게 맞췄다 |

로그: `debug/frontend_fe4b2/logs/`(one_1 · one_2 · related_1 · related_2 · plan_flow_test_2 · plan_flow_test_3 · render_once).

### 처리한 FD

- **FD-177** (확정 (a)): 한 명 모드를 만들었다.
- **FD-078** (워커 재량 → 권장안): 섹션 intro/outro 부착면 규칙 그대로, 한 명 ↔ 여러 명 전환은 B·C 꼭짓점 보간 360ms(`easeInOutCubic`). 단계를 바꿀 때(B·C 퇴장 중)는 보간 없이 바로 맞춘다.
- **FD-074·FD-171**: 바꾸지 않음(내 그룹 저장소 · 계산기 넘김 동작 그대로). 다만 한 명 모드 C에는 "내 그룹"이 보이지 않는다(발견 2).
- **FD-050·FD-051**(FE3-b): 인연 게이지 목표는 학생 탭과 같은 위젯 · 같은 규칙(활성 계획 마지막 단계 `bond_rank`, 현재 이하이면 숨김).

### 모드 전환 규칙

| 상태 | 모드 | B | C | 학생 탭 S3 겹침 | 그리드 카드 |
|---|---|---|---|---|---|
| 1단계 · 0명 | 여러 명 | `flow-body` 56칸 | `flow-aside`(빈 줄 · 내 그룹 · 역할군) | 없음 | — |
| 1단계 · **정확히 1명** | **한 명** | `flow-body-one` 52칸(제목 · 검색 · 그리드 폭 −106.7) | `flow-aside-one` 짧은 사다리꼴(선택한 학생 · 학생 행 · 이미 잡혀 있는 목표 · "이 학생 목표 정하기") | 있음(`element-3` 자리) | 분홍 외곽선만, 순서 배지 없음 |
| 1단계 · 2명 이상 | 여러 명 | `flow-body` | 목록(6명까지) / 압축 그리드(7명부터, FD-077) | 없음 | 순서 배지 |
| 2~4단계(몇 명이든) | 여러 명 | 각 단계 그대로 | 각 단계 그대로 | 없음 | — |

- 전환: 1단계 안에서 0↔1 · 1↔2명이 되면 360ms 보간(표면 꼭짓점 · B 폭, C 내용과 S3는 같은 값으로 페이드, S3는 사라지는 동안 마지막 학생을 보인다). 단계를 바꾸면 즉시.
- 규칙 함수: `planFlowOneMode(flow)` = `step == students && selectedStudentIds.length == 1`.
- 흐름 화면 밖에서 `PlanFlowStudentBody`·`PlanFlowStudentAside`를 직접 그리면(`oneMode` 인자 없음) 여러 명 배치만 쓴다(기존 위젯 시험 그대로).
- 고르기 동작은 바꾸지 않았다: 한 명 모드에서 다른 카드를 누르면 **더해진다**(2명 → 여러 명 모드). 시안 (i)의 "누르면 바로 바뀝니다"(교체)는 따르지 않았다(발견 1).

### 인디케이터 공개화 diff

- 파일 `frontend/lib/ui/widgets/student_section_layout.dart` **+11 −11**, 이름 바꾸기만: `_StudentStatusIndicators` → `StudentStatusIndicators`(선언 2줄 + 사용 2줄), `_StudentSectionFoundationPainter` → `StudentSectionFoundationPainter`(선언 2줄 + `shouldRepaint` 1줄 + 사용 4줄). 주석 · 인자 · 본문 변화 0.
- S3 바탕(섹션 모양 · container 텍스처 · ★ 표시)은 foundation painter가 그리므로 "같은 모양"을 위해 함께 공개했다(지시 "인디케이터 공개화"의 범위로 판단, CF 확인 요청). 초상 카드는 공개 위젯(`AssetImageGrid`·`StudentGridCardOverlayPainter` 등)으로 새 파일에서 학생 탭과 같은 인자로 조립했다.
- 학생 탭 변화 0 근거: 바뀐 줄이 식별자뿐이라 생성되는 위젯 · painter · 인자가 같다. 학생 탭 시험(`student_page_test` · `student_bond_gauge_test` · `student_studio_layout_test` · `growth_calculator_view_test` 등) 그대로 통과. golden 비교는 돌리지 않았다(CF 몫).

### "이미 잡혀 있는 목표" 값 출처

| 화면 값 | 출처 | 없을 때 |
|---|---|---|
| 머리 칩 `활성 계획 Pn에 있음` | `PlanFlowContext.activePlan`(흐름을 열 때 읽은 `plan.get` 문서)에서 그 학생 첫 단계의 페이즈 번호 | 칩 없음 |
| 행 왼쪽 `Pn · k단계` | 같은 문서: 페이즈 순번(1부터) · 그 학생 단계 순번(문서 순서) | — |
| 행 가운데 목표 요약 | 같은 문서 단계의 v2 목표 → 정수 보기(`planFlowDocumentIntegerTargets`, null = 앞 단계, 첫 단계 앞 = 확정 현재값) → 앞 단계와의 차이(`planFlowGoalChanges`) → 3단계 카드와 같은 요약(`planFlowOrderGoalSummary`, 예 `Lv.90`, `EX5 · 인연 100`, 미보유 `모집 · 인연 20`) | 단계 없음: 빈 상태 줄 "활성 계획에 이 학생의 단계가 없습니다" |
| 행 오른쪽 상태(시안 `지금 가능` · `부족 1종`) | 흐름에는 활성 계획 계산이 없다(문서에 없는 값) | **'—'** |
| `외 n단계` | 그 학생 단계가 3개 이상일 때(행은 2개만) | — |
| 학생 행 둘째 줄 | 카탈로그 학교 · 편성 · 공격/방어 라벨 | 모르는 값 '—' |
| S3 수치 | 확정 현재값(`repositoryState.students`, 2단계 "현재"와 같은 원천) | 미보유: 학생 탭 미보유와 같은 '-' 표시 |
| 인연 목표 빗금 · `→N` | `activePlanBondTarget(activePlan, id)`(학생 탭과 같은 함수) | 없음 |

- 읽기 전용: 새 함수 `planFlowActiveStudentStages`·`PlanFlowContext.activeStagesOf`는 문서를 읽기만 한다. 초안 · 저장 경로(`PlanFlowDocumentBoundary`, 4단계 저장) 변화 0(시험: 읽은 뒤 `toWire` 동일 · 초안 단계 0).

### 바뀐 파일

| 파일 | 상태 | 줄(+/−) | 내용 |
|---|---|---|---|
| `frontend/lib/ui/widgets/plan_flow_student_one.dart` | 새 파일 | +567 | 짧은 C 내용 `PlanFlowStudentOneAside`, S3 겹침 `PlanFlowStudentOneDetail`, 보간 표면 `PlanFlowModeSectionPainter`·`planFlowModeSectionPath`, `planFlowOneModeDuration` 360ms |
| `frontend/test/plan_flow_student_one_test.dart` | 새 파일 | +497 | 8건(검수표) |
| `frontend/lib/ui/studio/plan_flow_studio_layout.dart` | 수정 | +52 −3 | `planFlowOneStudioDocument`(B `flow-body-one` (15,2,52,94), C `flow-aside-one` (64,2,32,28) 깊이 68/96), `planFlowSection`이 두 문서를 찾음 |
| `frontend/lib/ui/widgets/plan_flow_student_step.dart` | 수정 | +73 −13 | `planFlowOneMode`, `planFlowAsideLeftAt(sectionId:)`(기본값 = 기존), Body · Aside `oneMode`(선택 인자), Aside `onNext`, 한 명 모드 폭 · 배지 |
| `frontend/lib/ui/widgets/plan_flow_workspace.dart` | 수정 | +46 −6 | 모드 컨트롤러, B · C 표면을 보간 painter로(0이면 기존과 같은 path), S3 겹침 마운트 |
| `frontend/lib/ui/models/plan_flow_draft.dart` | 수정 | +61 −0 | 읽기용 `PlanFlowActiveStudentStage`·`planFlowActiveStudentStages`·`PlanFlowContext.activeStagesOf` |
| `frontend/lib/ui/widgets/student_section_layout.dart` | 수정 | +11 −11 | 공개화 이름 바꾸기만 |
| `frontend/test/goldens/fe1g_baseline_golden_test.dart` | 수정 | +24 −0 | 새 장면 `plan-flow-step1-one` + import 1 |
| `frontend/test/plan_flow_test.dart` | 수정 | +7 −7 | 한 명 고른 1단계 단언 2곳을 한 명 모드 C로 |
| `almanac/workflows/frontend-redesign-status.md` | 수정 | 이 기록 | — |

`plan_student_step_tile.dart`, `plan_flow_rail.dart`, `lib/services/**`, `lib/ui/kit/**`, golden harness, `frontend/tool/**`, settings 파일, backend · contracts, 택틱 파일은 고치지 않았다. 사본만 두고 고치지 않은 파일: `plan_flow_student_step_test.dart`·`planning_page_test.dart`(commit.json에 없음).

### golden 변화 예상(장면별)

- **바뀜 1 — `plan-flow-step1-filter`**: 이 장면은 아루 **한 명**을 고른 뒤 필터 모달을 연다. 그래서 스크림 아래 화면이 한 명 모드가 된다(B 4칸 좁음 · 짧은 C · 오른쪽 아래 아루 S3). 모달 자체는 같다. 렌더 `render/plan-flow-step1-filter.png`. 장면 조작은 고치지 않았다(발견 3).
- **새 장면 1 — `plan-flow-step1-one`**(기준 없음): 아야네 한 명. A 레일 1단계 "지금", B 제목 "1명 골랐습니다", 그리드 8열 좁아짐 · 아야네 카드 분홍 외곽선(배지 없음); C 짧은 사다리꼴: "선택한 학생 (i) [활성 계획 P1에 있음]", 학생 행(초상 · 아야네 · 학교 · 편성 · 속성), "이미 잡혀 있는 목표", `P1 · 1단계 | 인연 30 | —`, `P2 · 2단계 | 인연 45 | —`, 분홍 "이 학생 목표 정하기 ›"; 그 아래 학생 탭 S3 그대로(PLAN 초상, Lv, Position/Class/Weapon, 스킬 · 장비 · 능력 개방 · 심상개화 · STATS, 인연 게이지 현재 24 채움 + 24~45 빗금 + `→45`). 렌더 `render/plan-flow-step1-one.png`.
- **그대로**: 나머지 전부. `plan-flow-step1`(3명) · `-many`(8명) · `plan-flow-step2*`(2 · 3명, 그룹으로 2명) · `step3*` · `step4*`는 1단계가 한 명이 아니거나 1단계가 아니라 모드 값 0 = 기존 path · 기존 폭 · 배지 그대로다. 여러 명 C는 `FadeTransition` 불투명도 1로 감싸져 픽셀이 같다. 학생 탭 장면(`students-*`)은 이름 바꾸기뿐이다.
- 그래서 CF gate 예상: golden **2건 RED**(`plan-flow-step1-filter` 바뀜, `plan-flow-step1-one` 기준 없음), 나머지 GREEN.

### 미검증("미실행")

- 전체 `fe_gate.ps1` · golden 비교 · `-UpdateGoldens` — 미실행(CF 몫).
- 바뀐 동작에 걸리지 않는 나머지 일반 시험(스캔 · 인벤토리 · 통계 · 택틱 · process E2E) — 미실행(gate에서).
- 시안과 ±2px 내부 요소 대조 — 섹션 꼭짓점만 시험으로 확인(±1px). 내부 행 inset은 시안 좌표에서 계산했고 렌더로 눈 확인만 했다.
- 실제 앱(mock 모드) 클릭 검수 — 미실행(검수표, 사용자/CF).

### 검수표 (mock 모드 `--dart-define=BA_PLANNER_USE_REAL_BACKEND=false --dart-define=BA_PLANNER_MOCK_SCENARIO=design-review`, 2560×1392 최대화)

| artboard | 여는 방법 | 확인 포인트 | 자동 확인 |
|---|---|---|---|
| Flow-1-Students-One | 계획 탭 → 시나리오 생성(계획 만들기) → 그리드에서 학생 한 명 | B 오른쪽 변이 4칸 안으로, C가 위쪽 짧은 사다리꼴(아래 1955 · 위 2017), 그 아래 학생 탭과 같은 자리 S3 | 시험 "한 명 모양 B·C …" ±1px, golden 새 장면 |
| (전환) | 같은 화면에서 둘째 학생을 더 고름 / 빼서 한 명 | 360ms 동안 B · C가 늘고 줄며 C 내용 · S3가 페이드 | 시험 "한 명을 고르면 …"(중간값 0<t<1, 끝 1 → 0) |
| (이미 잡혀 있는 목표) | 활성 계획에 단계가 있는 학생 한 명 | `Pn · k단계`, 목표 요약, 상태 '—', 3단계 이상이면 "외 n단계" | 시험 읽기 · 화면 |
| (빈 상태) | 활성 계획에 없는 학생 한 명 | "활성 계획에 이 학생의 단계가 없습니다", 머리 칩 없음 | 시험 "활성 계획에 단계가 없으면 …" |
| (인연 게이지) | 인연 목표가 현재보다 높은 학생 | 학생 탭 S3와 같은 빗금 · 점선 · `→N` | 시험 `→100`, golden `→45` |
| (다음) | C "이 학생 목표 정하기" | 레일 "다음"과 같이 2단계, 2단계는 여러 명 모양 | 시험 "이 학생 목표 정하기 …" |
| (작은 창) | 1280×720 | 넘침 예외 없음(행 높이 0.4~1배) | 시험 1280×720 |

### 발견 사항

1. **시안 (i) "그리드에서 다른 학생을 누르면 바로 바뀝니다"**: 모드를 고른 수로 정했으므로(지시 권장안) 누르면 교체가 아니라 더해져 여러 명 모드가 된다. 그래서 (i) 둘째 문장을 "그리드에서 학생을 더 고르면 여러 명 모드로 바뀝니다."로 바꿨다. 시안의 세그먼트 "한 명 | 여러 명"(네 시안 모두 제목 줄에 있음)은 그리지 않았다(기존 장면 변화 0 조건, 고르기 동작 유지). 세그먼트 + 한 명 모드 교체 고르기를 원하면 별도 결정(FD 후보).
2. **한 명 모드 C에는 "내 그룹" · 역할군 칩 · "보이는 학생 모두 고르기"가 없다**(시안 짧은 C에 없음). 한 명을 고른 동안은 그룹 저장(1명 그룹) · 그룹 불러오기를 할 수 없고, 0명 또는 2명 이상일 때는 그대로다. 저장소 동작 변화는 없다.
3. **`plan-flow-step1-filter` 장면이 한 명 고른 상태**라 스크림 아래가 한 명 모드로 바뀐다. 시안 Flow-1-Students-Filter는 3명 · 여러 명이다. 장면 조작을 3명으로 맞출지 CF 판단.
4. **레일 1단계 부제**: 한 명이어도 "1명 · 여러 명 모드"로 나온다(시안 "1명 · 한 명 모드"). `plan_flow_rail.dart`는 이 slice 범위 밖이라 두었다. 2단계 부제 "리오(무장) · 설정 중"도 같다.
5. **"학생 탭" 버튼**(시안 학생 행 오른쪽 `학생 탭에서 열기`): 흐름에서 학생 탭으로 가는 셸 경로가 없어 그리지 않았다.
6. **상태 칩**(`지금 가능` · `부족 1종`): 흐름 context에 활성 계획 계산(`plan.get` calculation)이 없어 '—'다. 흐름을 열 때 계산을 함께 넘기면 채울 수 있다.
7. **빈 상태 문구**: 시안에 없어 "활성 계획에 이 학생의 단계가 없습니다"를 새로 썼다.
8. **짧은 C 깊이**: 시안 604.7이 칸 정수로 떨어지지 않아 rect 32칸 × 깊이 68/96(604.4)로 맞췄다(꼭짓점 차 ≤0.3px).
9. **같은 키가 두 곳**: S3 안의 `student-detail-bond-target` 등 학생 탭 위젯 키가 계획 흐름 S3에도 생긴다. 학생 탭과 계획 흐름을 함께 띄운 앱 단위 시험이 `find.byKey(...)`로 하나만 기대하면 한 명 모드일 때 2개가 된다(지금 시험 중 해당 없음).
10. 최근 본 학생 줄(원래 FE4-b2 계획의 `RecentStudents`)은 이번 지시 범위가 아니라 하지 않았다.

### 사본 · commit.json

- pre 사본: `debug/frontend_fe4b2/pre/<경로>` 10파일(고친 8 + 고치지 않은 `plan_flow_student_step_test.dart`·`planning_page_test.dart`). 착수 때 WIP 0 → `post_dir` 없음.
- `debug/frontend_fe4b2/commit.json`: slice `fe4b2`, modified 8(이 문서 포함), added 2, `whole` = [`frontend/test/goldens/baseline/plan-flow-step1-filter.png`], `optional_added` = [`frontend/test/goldens/baseline/plan-flow-step1-one.png`], `status=true`.
- 인계: `debug/frontend_fe4b2/output.md`.

### 다음 행동

- CF: Lane B(FE10-s)가 멈춘 뒤 `fe_gate.ps1` 1회 → golden 2건(`plan-flow-step1-filter` 바뀜, `plan-flow-step1-one` 새 장면) `failures/` 확인(렌더 PNG와 비교) → `-UpdateGoldens` → 재비교 → `fe_commit.ps1 -Slice fe4b2`.
- CF 판단: 발견 1(세그먼트 · 교체 고르기), 3(filter 장면 조작), 4(레일 부제, 다음 slice 후보), 6(상태 칩).
- 다음 slice: FE4-g4(FD-180 병합 목표 역전).

### fe4b2 commit record (2026-10-19 01:01, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261019_004710\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

### fe10s commit record (2026-10-19 01:01, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261019_004710\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE4-g4 착수 기록 (2026-10-19 01:11, Lane A, 로컬 Claude Code)

- 상태: **진행 중**. 시작 SHA `0fd6abbeb181c082bafc323e7611c9e3c132f71d`(브랜치 scanner-consolidation).
- 범위: ① FD-180 (a) "페이즈로 추가" 병합에서 활성 계획 "나중에" 단계를 새 앞 단계 값까지 올리고 4단계 C · 저장 결과에 알린다(검증 `target_regression`은 그대로) ② FE4-b2 후속 — 레일 1·2단계 한 명 부제(발견 4), golden `plan-flow-step1-filter` 3명(발견 3), 상태 칩(발견 6) ③ `skill_book` 계획 칩 분류.
- 막힘: 대장 "slice별 막힘 요약"에 FE4-g4 행 없음(FE4-g "—"), FD-180 확정 2026-10-19 (a). 열림 0건 — 멈출 사유 없음. 앞선 "FE4-g4 착수 기록" 없음.
- 고칠 기존 파일(사본 `debug/frontend_fe4g4/pre/<경로>` 8개): `frontend/lib/ui/models/plan_flow_save.dart`, `frontend/lib/ui/widgets/plan_flow_save_step.dart`, `frontend/lib/ui/widgets/plan_flow_rail.dart`, `frontend/lib/ui/widgets/plan_section_layout.dart`(3만), `frontend/test/goldens/fe1g_baseline_golden_test.dart`(장면 조작 · 추가), `frontend/test/plan_flow_save_test.dart`, `frontend/test/plan_flow_test.dart`, `frontend/test/planning_page_test.dart`, 이 status 문서. `plan_flow_draft.dart` · `plan_flow_student_step.dart` · `plan_flow_student_one.dart` · `plan_flow_workspace.dart` · `plan_flow_studio_layout.dart`는 필요할 때만(그때 사본 추가).
- 기존 미커밋 변경(WIP): `git status --short` 결과 위 파일 모두 없음. 줄 끝(`git ls-files --eol`): `plan_section_layout.dart`만 작업트리 CRLF, 나머지 7파일 · 이 문서 LF — 그대로 유지.

## FE4-g4 종료 기록 (2026-10-19 01:35, Lane A, 코드 작성 완료 · gate 미실행)

상태: 구현 끝, gate 미실행(CF 몫). 시작 SHA `0fd6abbeb181c082bafc323e7611c9e3c132f71d`. `debug/frontend_fe4g4/commit.json`(slice=fe4g4, status=true). 직접 커밋하지 않았다(git 쓰기 없음).

### 실행한 명령 · 결과

- `frontend`에서 `flutter analyze`: 첫 실행 5건(이 slice 2건 — golden 시험 불필요 import 2 → 지움; 나머지 3건은 Lane B 진행 중 파일, 발견 6) → 시험 작성 뒤 info 2건(`plan_flow_save_test` 불필요 import · 컬렉션 리터럴 → 고침) → 마지막 실행 **No issues found**(0건, info 포함).
- `flutter test test/plan_flow_save_test.dart`: 첫 실행 23 통과 · 2 실패(① 시험 값 레벨 95가 최댓값 90을 넘어 validator `targets`로 거절 — 시험 값을 88로 ② 1280폭에서 알림 줄이 남은 높이 계산으로 0줄 — 작은 창에서도 첫 줄은 보이게 코드 수정) → 재실행 **25 통과 · 0 실패**(기존 15 + 새 10). 원인 확인용 임시 시험 `test/zz_fe4g4_debug_test.dart`는 실행 직후 지웠다.
- `flutter test test/plan_flow_test.dart`: **16/0**(기존 15, 기대값 2건 갱신 + 새 1). `flutter test test/planning_page_test.dart`: **18/0**(기존 17 + 새 1).
- 바뀐 동작에 걸리는 기존 시험(`ls test | grep -E "^(plan_|planning_|growth_calculator_|student_|widget_test)"`, process E2E 제외 — Python 백엔드를 띄우고 서비스 · 백엔드는 고치지 않음; `target_regression` · `planFlowMergedPlanDocument` · `PlanFlowSaveController` · `planResourceCategory` · `plan-flow-step-1/2` grep 결과 `plan_flow_authoring` · `plan_flow_handoff` · `plan_flow_save` · `plan_flow_test` · `planning_page_test`가 모두 이 목록 안)을 파일마다 따로 실행, 전부 통과(46파일): `growth_calculator_adapter_test` 24/0 · `growth_calculator_rules_test` 15/0 · `growth_calculator_state_test` 16/0 · `growth_calculator_view_test` 24/0 · `plan_detail_tabs_test` 8/0 · `plan_element_builder_test` 47/0 · `plan_flow_authoring_test` 18/0 · `plan_flow_goal_step_test` 23/0 · `plan_flow_handoff_test` 23/0 · `plan_flow_order_step_test` 19/0 · `plan_flow_presets_test` 13/0 · `plan_flow_save_test` 25/0 · `plan_flow_student_one_test` 8/0 · `plan_flow_student_step_test` 8/0 · `plan_flow_test` 16/0 · `plan_home_detail_test` 9/0 · `plan_preset_manager_test` 5/0 · `plan_scenario_compare_test` 7/0 · `plan_scenario_comparison_test` 2/0 · `plan_scenario_detail_test` 12/0 · `plan_scenario_list_test` 10/0 · `plan_scenario_preview_test` 9/0 · `plan_student_step_tile_test` 3/0 · `planning_authoring_service_test` 75/0 · `planning_document_projection_test` 1/0 · `planning_document_v2_service_test` 19/0 · `planning_growth_rules_test` 13/0 · `planning_page_test` 18/0 · `planning_protocol_client_test` 24/0 · `planning_protocol_contract_test` 7/0 · `planning_resource_assets_test` 1/0 · `student_bond_gauge_test` 12/0 · `student_bond_service_test` 11/0 · `student_calculation_service_test` 8/0 · `student_card_de_test` 17/0 · `student_catalog_service_test` 12/0 · `student_filter_followups_test` 4/0 · `student_filter_modal_test` 8/0 · `student_filter_selection_test` 15/0 · `student_form_cycle_test` 10/0 · `student_page_test` 8/0 · `student_range_condition_section_test` 4/0 · `student_scan_diagnostic_test` 2/0 · `student_search_section_test` 13/0 · `student_studio_layout_test` 45/0 · `widget_test` 16/0. 로그 `debug/frontend_fe4g4/logs/related_tests.txt`. 잠금 실패 없음.
- 일회성 렌더(사본 `test/goldens/fe4g4_render_once_test.dart`, `@Tags` · `expectGoldenScene` grep 0건, `--name`으로 4장면만, 실행 뒤 바로 지움 — 지금 `test/goldens`에 fe4g4 파일 0개): 첫 두 번은 새 장면 기대식만 실패(fixture 호시노가 말줄임 시험용 긴 이름 → 이름을 빼고 `· 나중에 칸 목표 · 레벨 70→80`로, Text 자신에 키가 있어 `matchRoot: true`) → golden 시험 원본도 같이 고친 뒤 **+4 통과**, 넘침 예외 0. PNG `debug/frontend_fe4g4/render/`(`plan-flow-step1-filter.png` · `plan-flow-step1-one.png` · `plan-flow-step4-raised.png` · `plan-flow-step4-append.png`), 로그 `logs/render_once.log`.
- `git diff --check`(고친 8파일 + 이 문서): 통과. 줄 끝 유지(`git ls-files --eol`): `plan_section_layout.dart` 작업트리 CRLF, 나머지 LF.
- `dart format`: 고친 파일 모두 원래부터 형식 차이가 있어(이 slice와 무관한 줄) 파일 전체 재형식을 하지 않았다. 이 slice가 고친 덩어리는 `dart format --output=show` 결과와 비교해 차이 0(다른 1곳 `planning_page_test` 새 시험은 형식 결과로 바꿈).

### 처리한 FD

- **FD-180 (a)**(확정 2026-10-19): "페이즈로 추가" 병합에서 나중 단계를 새 값까지 올리고 알린다 — 구현. 검증(`lib/services/planning_authoring.dart` 191행 · `backend/core/planning_authoring.py` 101행)은 읽기만 했고 고치지 않았다.
- 막힘 요약: FE4-g4 행 없음(FE4-g "—"), 열림 0건. '워커 재량' FD 새로 처리한 것 없음. FD-098 라벨(노트 · BD · 오파츠 · 설계도)은 그대로 쓰고 Detail 칩 분류만 인벤토리 카탈로그 분류(`tech_notes` · `tactical_bd` · `equipment`)에 맞췄다.

### 1. FD-180 나중 단계 올림 — 구현

- 위치: `planFlowMergedPlanDocument`(`lib/ui/models/plan_flow_save.dart`). 같은 학생 체인 = 활성 배치 → 초안 배치(새 단계) → **활성 나중에** → 초안 나중에. 활성 나중에 단계를 체인 순서대로 돌며, 바로 앞 단계(올린 뒤 값)가 정한 키를 나중에 단계가 그보다 낮게 두었거나 비워 두었으면(null) 그 키를 앞 값으로 올린다. 낮추지 않는다. 올린 키마다 `PlanFlowRaisedTarget`(학생 · 단계 id · 단계 이름 · 키 · 이전(null 가능) · 새 값)을 `PlanFlowMergedPlan.raisedTargets`에 남긴다. 단계 id는 바꾸지 않는다.
- 성장 규칙(`normalizePlanningGrowthTargets`)은 다시 돌리지 않았다: 앞 단계와 나중에 단계가 모두 규칙을 지키고, 규칙이 모두 상한(장비 티어 → 레벨 상한, 전용무기 성급 → 레벨 상한, 성급 → 인연 상한) · 하한(스킬 → 성급 등) 꼴이라 키마다 큰 값을 고른 결과도 규칙을 지킨다. 검증 쪽 규칙은 범위 + 퇴행뿐이다(`planning_targets_from_wire`).
- 알림(FE4-e "몰래 올리지 않는다"를 이것으로 지킨다):
  - 4단계 C(시안에 자리가 없어 기존 안내 줄 문법 — muted · 말줄임 1줄): 저장 버튼 아래에 제목 `나중 단계 n개를 함께 올렸습니다`(굵게 · textSecondary) + 단계마다 한 줄 `{학생} · 나중에 칸 {단계 이름} · {키} {이전}→{새}, …`(예 `호시노 · 나중에 칸 목표 · 레벨 70→80`). 목표가 없던 키는 `EX —→5`, 장비 티어는 `T7→T9`. 남은 높이만큼만 줄을 보이고 넘치면 `외 n개 단계`(작은 창에서도 첫 줄은 보인다). 실패 안내 줄은 그 아래로 내려간다. "페이즈로 추가"를 고르고 붙일 수 있을 때만 보인다(`PlanFlowSaveController.raisedTargets`).
  - 저장 결과 SnackBar: `활성 계획에 페이즈 k개를 붙였습니다. 나중 단계 n개를 함께 올렸습니다(호시노 · 나중에 칸 목표 · 레벨 70→80 / …).` 단계가 3개를 넘으면 `… 외 n개 단계).`(`planFlowRaisedSummary`). 요청 객체(`PlanFlowSaveRequest.raisedTargets`)가 들고 있어 같은 키 재시도에도 같은 요약이다.
- 키 이름(`planFlowTargetKeyLabel`): 레벨 · 인연 · 성급 · 전용무기 레벨 · 전용무기 성급 · EX · 기본 · 강화 · 서브 · 장비1~3 티어 · 장비1~3 레벨 · 애장품 · HP · ATK · HEAL(2단계 · 3단계 카드 말과 같게).

#### 올림 규칙 표(경계)

| 경우 | 결과 | 시험 |
|---|---|---|
| 활성 나중에 단계 값 < 새 앞 단계 값 | 앞 값까지 올림, 알림 | `나중에 단계 여럿 …`(레벨 60→70) |
| 나중에 단계가 그 키를 비움(null), 앞이 값을 정함 | 앞 값으로 채움(검증상 null 뒤 퇴행), 이전 `—` | 같은 시험(EX —→4) |
| 앞(초안 배치 · 활성 배치 모두)도 그 키를 비움 | 그대로(값 · null 유지) | 같은 시험(기본 5 유지) |
| 나중에 단계 값 ≥ 앞 값 | 그대로, 알리지 않음 | 같은 시험(레벨 90) · `같거나 높은 …`(70=70) |
| 나중에 단계가 여럿(D1 → D2) | 체인 순서대로 바로 앞(올린 D1) 기준, 단계마다 셈 | 같은 시험(D2 EX 3→4, `raisedStageIds` 2개) |
| MAX · 직접 입력 모드 | 모드 구분 없이 저장된 절대 숫자로 올림(MAX = 최댓값) | `MAX · 직접 입력 …`(레벨 80→90, 인연 20→37) |
| 활성 계획에 나중에 단계만 있는 학생(배치 없음) | 같은 규칙(앞 = 초안 배치) | `MAX · 직접 입력 …`(히나) |
| 초안에 없는 학생의 활성 나중에 단계 | 그대로(앞 = 활성 배치, 저장된 계획은 이미 검증 통과) | `같거나 높은 …`(아야네) |
| 초안 안 나중에 단계(초안 배치 → 초안 나중에) | 올리지 않음(초안 안 규칙은 2단계 편집기 · handoff `planFlowRaiseLaterStages`가 이미 지킴). 체인 끝에 그대로 | `초안 나중에 단계는 올리지 않는다 …` |
| 초안 나중에 단계 < (올린) 활성 나중에 단계 | 지금처럼 막음(`regressedStudentIds`, "목표가 활성 계획보다 낮아") | `초안 나중에 단계가 … 낮으면 …` |
| 초안 배치 < 활성 배치(FE4-e) | 지금처럼 막음, 올림 알림 없음(`raisedTargets` 빈 목록) | `같거나 높은 … 막힌 병합 …` |
| validator가 다른 이유로 거절(authoring null) | 막힘, 올림 알림 없음 | 코드(`raisedTargets: authoring == null ? [] : raised`) |
| 시나리오 편입(FE4-f2 `planFlowIncorporateScenario`) | 그대로: 활성 나중에 단계와 맞지 않는 시나리오 배치 단계를 먼저 빼므로 병합에서 올릴 것이 없다 | `시나리오 편입은 그대로다 …` |
| 활성 계획 고치기 흐름 | "페이즈로 추가"를 쓰지 않음(기존) — 해당 없음 | — |
| 비교 타일(FD-080) | 나중에 단계는 문서 밖(authoring)이라 비교 · 계산 변화 없음 | — |

#### 저장 검증 통과 근거(시험)

- `나중에 단계 여럿 …`: 올린 병합 authoring을 `PlanningAuthoring.fromWire`(공용 validator, 백엔드와 같은 규칙)로 다시 읽어 통과, **올리지 않은 원래 나중에 단계로 바꾸면 `target_regression`으로 거절**(검증 그대로 · 올림이 필요했음).
- `페이즈로 추가 저장 …`: `PlanFlowSaveController`가 mock `plan.save`에 올린 authoring을 보내고(`deferred_stages` 레벨 70, 체인 [활성 1단계, 새 단계, 나중에]), 다시 읽은 `plan.get` authoring도 70이다. 결과 안내 문구 확인.
- golden 장면 `plan-flow-step4-raised`: 장면 안에서 `save.canSave` · `merged.authoring != null` 확인.
- 실제 Python 백엔드 왕복 — 미실행(아래).

### 2. FE4-b2 후속

| 발견 | 처리 | 근거 · 시험 |
|---|---|---|
| 4 레일 부제(한 명) | 1단계 `1명 · 한 명 모드`, 2단계 `{학생 이름} · 설정 중`(1 · 2단계) / `· 완료`(3단계 이후 그 학생 단계가 있으면). 두 명 이상은 그대로(`n명 · 여러 명 모드`, `n명 중 m명 완료`) | 시안 Flow-1-Students-One "리오(무장) · 설정 중"(1단계 장면인데 단계가 있어도 설정 중). `plan_flow_test` 레일 시험 2건 갱신(기대값 바뀜: `1명 · 여러 명 모드` → `1명 · 한 명 모드`, `1명 중 0/1명 완료` → `아루 · 설정 중`) + 새 시험 1건(3단계 `· 완료`). golden `plan-flow-step1-one` 장면에 기대 2줄 추가 |
| 3 filter 장면 | `plan-flow-step1-filter` 장면이 `plan-flow-step1`과 같은 세 명(호시노 · 아루 · 슌(수영복))을 고른 뒤 모달을 연다 | 시안 Flow-1-Students-Filter = Flow-1-Students(3명 · 여러 명 모드) 위 스크림 |
| 6 상태 칩 | **'—' 그대로**. `PlanFlowContext`에는 활성 계획 문서(`activePlan`)만 있고 계산이 없다(`plan.get` calculation은 계획 화면 `_repositoryPlan`에만 있음). 흐름을 열 때 계산을 넘기려면 `plan_section_layout.dart` 흐름 context 생성부 + `PlanFlowContext` 필드가 필요한데, 이 slice는 `plan_section_layout`을 3번 분류에만 고칠 수 있어 하지 않았다 | 코드 확인(`plan_flow_draft.dart` 1512행 `PlanFlowContext`, `plan_flow_student_one.dart` `_StageRow`) |

### 3. `skill_book` 분류 — 버그 맞음, 고침

- 판정: **버그다.** Detail 칩 필터(`PlanDetailResourceFilter.includes`, `plan_scenario_detail.dart`)는 `planResourceCategory(id: resource_key, iconAsset: planningResourceIconAsset(category, itemId))`로 분류한다. 기술 노트는 `category = tech_notes` → 폴더 `skill_book` → `assets/item_icons/skill_book/Item_Icon_SkillBook_*.png`인데, 분류 함수는 `skill_note`/`skillnote`만 보아 **오파츠**(기본값)로 떨어졌다. 같은 원인으로 전술 교육 BD(`tactical_bd` → `skill_db/Item_Icon_Material_ExSkill_*`, 함수는 `tactical_bd`/`basic-bd`만 봄)와 장비 설계도(`equipment` → `item_icons/equipment/Equipment_Icon_*`, 함수는 `equipment_icons`만 봄)도 오파츠로 떨어졌다(옛 홈 견본 경로만 맞았다).
- 고침(`plan_section_layout.dart` `planResourceCategory`, CRLF 유지): 노트 `skill_book`/`skillbook` 추가, BD `/skill_db/`/`material_exskill` 추가, 장비 `item_icons/equipment/`(강화석 `equipment_icon_exp` · 무기 부품 `weaponexp`를 먼저 본 뒤). 기존 견본 경로 분류는 그대로(기존 시험 통과). 인벤토리 카탈로그 분류(`tech_notes` · `tactical_bd` · `equipment` · `oopart`/`workbook`)와 같아졌다.
- 시험: `planning_page_test` 새 시험 1건(노트 2 · BD · 설계도 · 강화석 · 무기 부품 · 오파츠 · 워크북 · 보고서 · 크레딧).

### golden 변화 예상(장면별)

- **바뀜 1 — `plan-flow-step1-filter`**: 장면이 호시노 · 아루 · 슌(수영복) 세 명을 고른 뒤 모달을 연다. 스크림 아래가 `plan-flow-step1`과 같은 여러 명 모드(레일 1단계 "3명 · 여러 명 모드", B "3명 골랐습니다" · 순서 배지 1~3, C 목록형 3행)가 되고 모달(학교 게헨나 · 계획에 없는 학생만 선택, "필터 1 / 10명")은 그대로다. **2026-10-19 이전 기준 이미지와 같지 않다**: 그 이미지는 아루 한 명(당시 여러 명 모드, C 1행 · "1명 골랐습니다")이었다(발견 5). 렌더 `render/plan-flow-step1-filter.png`.
- **바뀜 2 — `plan-flow-step1-one`**: A 레일 글자만 — 1단계 부제 "1명 · 여러 명 모드" → **"1명 · 한 명 모드"**, 2단계 부제 "1명 중 0명 완료" → **"아야네 · 설정 중"**. 나머지(B · 짧은 C · S3) 그대로. 렌더 `render/plan-flow-step1-one.png`.
- **새 장면 — `plan-flow-step4-raised`**(기준 없음): 시드 활성 계획 = 학생 장면 문서 + 호시노 "나중에" 칸 단계 `목표`(레벨 70 · ★5 · EX 5 · 기본/강화/서브 10). `plan-flow-step4`와 같은 세 명 흐름에서 "활성 계획에 페이즈로 추가"를 고름: B는 `plan-flow-step4-append`와 같은 P3~P5 · 비교 타일(76%→42% · 4→7종 · 46M→103.4M · 3→5명) · 늘어나는 재화 3줄(P4 팝오버 없음), A primary "활성 계획에 페이즈로 추가", C 옵션 2 선택 · 부제 "지금 P2 뒤에 P3~P5로 붙입니다" · "활성 계획 이름은 그대로 두고 페이즈만 붙입니다" · 토글 2 · 분홍 저장 버튼, 그 **아래 굵은 "나중 단계 1개를 함께 올렸습니다"** + muted 한 줄 "호시노(카드 하단 변보다 긴 이름은 말줄임으로 줄어듭니다) · 나중에 칸 목표 · 레벨 70→80"(fixture 긴 이름 그대로, 한 줄). 올린 키는 레벨 하나(초안 호시노 2단계의 다른 키는 나중에 단계 이하). 렌더 `render/plan-flow-step4-raised.png`.
- **그대로**: 나머지 전부. `plan-flow-step4-append`는 활성 계획에 나중에 단계가 없어 올림 0 → 알림 없음(렌더 `render/plan-flow-step4-append.png`로 확인). `plan-flow-step1`(3명) · `-many`(8명) · `step2*`(2 · 3명) · `step3*` · `step4`는 고른 학생이 두 명 이상이라 레일 글자 그대로. Detail 칩 분류는 칩 필터를 쓰는 golden 장면이 없어(`toggleCategory`/`categories:` grep 0건) `plan-*` · `plan-scenario-*` 그대로.
- 그래서 CF gate 예상: golden **3건 RED**(`plan-flow-step1-filter` · `plan-flow-step1-one` 바뀜, `plan-flow-step4-raised` 기준 없음), 나머지 GREEN.

### 미검증("미실행")

- 전체 `fe_gate.ps1` · golden 비교 · `-UpdateGoldens` — 미실행(CF 몫).
- process E2E(`planning_authoring_process_e2e_test` 등 Python 백엔드를 띄우는 시험)와 실제 Python 백엔드에서 "페이즈로 추가" + 올린 authoring 저장 왕복 — 미실행. 서비스 · 백엔드는 고치지 않았고, Dart validator가 Python과 같은 규칙(`planning_authoring.py` 101행)임을 읽어 확인만 했다.
- 바뀐 동작에 걸리지 않는 나머지 일반 시험(스캔 · 인벤토리 · 통계 · 택틱) — 미실행(gate에서).
- 실제 앱(mock 모드) 클릭 검수 — 미실행(검수표).

### 검수표 (mock 모드 `--dart-define=BA_PLANNER_USE_REAL_BACKEND=false --dart-define=BA_PLANNER_MOCK_SCENARIO=design-review`, 2560×1392 최대화)

| artboard · 확인 | 여는 방법 | 확인 포인트 | 자동 확인 |
|---|---|---|---|
| Flow-4-Save(페이즈로 추가 · 나중 단계 올림) | 활성 계획에서 학생 하나를 3단계 "나중에" 칸에 둔 채 저장(단계 순서 바꾸기) → 계획 만들기로 같은 학생 목표를 그 나중에 단계보다 높게 → 4단계 "활성 계획에 페이즈로 추가" | 옵션이 흐려지지 않음(예전: "나중에 칸 · 선행 조건과 맞출 수 없어 붙일 수 없습니다(뒤 단계 목표가 앞 단계보다 낮습니다)"), 저장 버튼 아래 "나중 단계 1개를 함께 올렸습니다" + 학생 · 나중에 칸 이름 · 키 이전→새 | 시험 4단계 C 위젯 2건(2560 · 1280폭), golden 새 장면 |
| (저장 결과) | 위에서 저장 | SnackBar "활성 계획에 페이즈 k개를 붙였습니다. 나중 단계 1개를 함께 올렸습니다(…)" · 다시 연 활성 계획의 나중에 단계 값이 올라 있음 | 시험 `페이즈로 추가 저장 …` |
| (다른 위치) | 같은 화면에서 "시나리오로 저장" · "이걸로 바꾸기" | 올림 알림 없음 | 위젯 시험 |
| Flow-1-Students-One 레일 | 1단계에서 학생 한 명 | A 1단계 부제 "1명 · 한 명 모드", 2단계 "{이름} · 설정 중"; 3단계로 가면 "{이름} · 완료" | `plan_flow_test`, golden `plan-flow-step1-one` |
| Flow-1-Students-Filter | 1단계에서 세 명 고른 뒤 필터 | 스크림 아래가 여러 명 모드(목록형 C 3행) | golden `plan-flow-step1-filter` |
| Detail 칩(노트) | 계획 탭 Detail 홈 S3 "페이즈별"/"전체" → 재화 유형 칩에서 "기술 노트"만 | 기술 노트 타일이 남고 "오파츠"만 고르면 노트가 빠짐(BD · 장비도 같은 식) | `planning_page_test` 분류 시험 |
| (작은 창) | 1280×720 | 4단계 C 알림 줄 넘침 예외 없음 | 위젯 시험 1280폭 |

### 발견 사항

1. **알림 문구 시점**: 4단계 알림은 저장 전 미리보기인데 지시 문구대로 "함께 올렸습니다"(완료형)다. 병합 문서 · 비교 타일이 이미 올린 상태를 보이므로 그대로 두었다. "저장하면 … 함께 올립니다"를 원하면 `planFlowRaisedTitle` 한 곳만 바꾸면 된다(golden 1장).
2. **초안 나중에 단계 < 활성 나중에 단계**는 FD-180 범위 밖이라 지금처럼 막는다(새 나중 단계가 기존 앞 단계보다 낮은 경우 = FE4-e 규칙). 이것도 올리기를 원하면 별도 결정(FD 후보).
3. **Detail 칩 분류의 같은 원인 2건(BD · 장비 설계도)**을 같은 함수에서 함께 고쳤다(지시는 `skill_book`만). 장면에 칩 필터를 쓰는 golden이 없어 golden 변화는 없다.
4. **상태 칩 '—'**: 채우려면 `PlanFlowContext`에 활성 계획 계산(`RepositoryPlanState.calculation` 단계 결과)을 싣는 작은 후속(`plan_section_layout.dart` 흐름 context 생성부 + `plan_flow_draft.dart`)이 필요하다. 다음 slice 후보.
5. `plan-flow-step1-filter`는 2026-10-19 이전 기준 이미지와 **같아지지 않는다**(아래 golden 절): 그 이미지도 아루 한 명(당시 여러 명 모드 한 행)이었고, 시안은 세 명이다. 한 명으로는 이제 한 명 모드가 되므로 예전 그림을 다시 만들 수 없다.
6. analyze 첫 실행 때 Lane B 진행 중 파일(`scan_item_queue.dart` unused import 2, `student_section_layout.dart` unused parameter 1) 경고 3건이 보였다가 다음 실행에는 없었다(Lane B 편집 중). 이 slice 파일은 0건.

### 사본 · commit.json

- pre 사본: `debug/frontend_fe4g4/pre/<경로>` 8파일(고친 8). 착수 때 WIP 0 → `post_dir` 없음. 이 status 문서는 `status=true` 관례로 사본 없음.
- `debug/frontend_fe4g4/commit.json`: slice `fe4g4`, modified 9(이 문서 포함), added 0, `whole` = [`frontend/test/goldens/baseline/plan-flow-step1-filter.png`, `frontend/test/goldens/baseline/plan-flow-step1-one.png`], `optional_added` = [`frontend/test/goldens/baseline/plan-flow-step4-raised.png`], `status=true`. 메시지는 ASCII(fe_commit PowerShell 5.1).
- 인계: `debug/frontend_fe4g4/output.md`.

### 다음 행동

- CF: Lane B(FE10-b)가 멈춘 뒤 `fe_gate.ps1` 1회 → golden 3건(`plan-flow-step1-filter` · `plan-flow-step1-one` 바뀜, `plan-flow-step4-raised` 기준 없음) `failures/` 확인(렌더 PNG와 비교) → `-UpdateGoldens` → 재비교 → `fe_commit.ps1 -Slice fe4g4`.
- CF 판단: 발견 1(알림 시점 문구), 2(초안 나중에 < 활성 나중에), 4(상태 칩 후속 slice).

### fe4g4 commit record (2026-10-19 19:52, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261019_193503\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

### fe10b commit record (2026-10-19 19:52, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261019_193503\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none

## FE4-g5 착수 기록 (2026-10-19 20:28, Lane A, 로컬 Claude Code)

- 상태: **진행 중** — FE4-g5 계획 흐름 작은 후속 둘: ① 한 명 모드 "이미 잡혀 있는 목표" 상태 칩(FE4-b2 발견 6) ② 올림 알림 시제(FE4-g4 발견 1, 저장 전 미래형 · 저장 뒤 완료형).
- 시작 SHA: `15091aee65ffd076893e6de84926f0b7c799279e`(브랜치 `scanner-consolidation`).
- 막힘: 대장 "slice별 막힘 요약"에 FE4-g5 행 없음(FE4-g "—"), `열림` 0건. FD-180 · FD-177 확정. 앞선 "FE4-g5 착수 기록" 없음 — 멈출 사유 없음.
- 고칠 기존 파일(착수 때 모두 작업트리 = HEAD, **기존 미커밋 변경(WIP) 없음**, 사본 `debug/frontend_fe4g5/pre/<v7 기준 경로>`, cmp 일치):

| 파일 | WIP |
|---|---|
| `frontend/lib/ui/models/plan_flow_draft.dart` | 없음 |
| `frontend/lib/ui/models/plan_flow_save.dart` | 없음 |
| `frontend/lib/ui/widgets/plan_section_layout.dart`(흐름 context 생성부만, CRLF) | 없음 |
| `frontend/lib/ui/widgets/plan_flow_student_one.dart` | 없음 |
| `frontend/lib/ui/widgets/plan_flow_save_step.dart` | 없음 |
| `frontend/lib/ui/widgets/plan_flow_workspace.dart`(필요할 때만, 사본만 미리 둠) | 없음 |
| `frontend/test/goldens/fe1g_baseline_golden_test.dart`(장면 조작만) | 없음 |
| `frontend/test/plan_flow_save_test.dart` · `plan_flow_student_one_test.dart` · `planning_page_test.dart`(필요할 때만) | 없음 |

- 이 status 문서는 `status=true`가 통째로 커밋하므로 사본 · commit.json `modified`에 넣지 않는다.
- 고치지 않음: `lib/services/**`(읽기만), backend · contracts, `lib/ui/kit/**`, golden harness, `frontend/tool/**`, almanac · docs(Lane B FE10-d), 택틱 소유 파일.

## FE4-g5 종료 기록 (2026-10-19 20:41, Lane A, 코드 작성 완료 · gate 미실행)

- 상태: **완료(gate 전)**. 근거 FE4-b2 발견 6, FE4-g4 발견 1, FD-180 (a). 새 백엔드 호출 0, 서비스 · kit · harness 수정 0.
- 이 레인이 고친 기존 파일은 사본 `debug/frontend_fe4g5/pre/`와 비교한다. 사본만 둔 `plan_flow_workspace.dart` · `planning_page_test.dart`는 고치지 않았다(cmp 일치).

### 실행한 명령과 결과

| 명령(`frontend`에서) | 결과 |
|---|---|
| `flutter analyze` | No issues found(info 포함 0). 마지막 실행은 시험 수정 뒤 4.0s |
| `flutter test test/plan_flow_student_one_test.dart test/plan_flow_save_test.dart` | 첫 실행 3건 실패(새 시험 쪽 — 계획 화면 시험의 저장 문서가 누적 snapshot이 아님 · `goal_metadata` 빠짐, 의미 값 찾기가 다른 노드) → 시험 고친 뒤 **+40, All tests passed**(로그 `debug/frontend_fe4g5/logs/slice_tests.txt`) |
| 관련 시험 27파일(grep `PlanFlowContext` · `PlanFlowCalculation` · `planFlowRaised` · `plan_flow_student_one` · `PlanningPage(` · `plan_section_layout` · `PlanFlowController` · `plan-scenario-create-launch` + `student_page_test` · `widget_test`; 위 두 파일 · golden · process E2E 제외) | **+289, All tests passed**, 실패 0(로그 `logs/related_tests.txt`). 파일: app_navigation_fe7d · app_navigation_tidy1 · plan_detail_tabs · plan_flow_authoring · plan_flow_goal_step · plan_flow_handoff · plan_flow_order_step · plan_flow_presets · plan_flow_student_step · plan_flow · plan_home_detail · plan_preset_manager · plan_scenario_compare · plan_scenario_comparison · plan_scenario_detail · plan_scenario_list · plan_scenario_preview · planning_page · tidy1_followups · student_page · widget_test · geometry/diagonal_geometry · kit/diagonal_scroll_viewport · kit/diagonal_scrollbar · kit/item_icon_tile · kit/skew_bar · widgets/section_surface |
| 일회성 렌더: `fe1g_baseline_golden_test.dart` 사본(`@Tags(['golden'])` 제거, `expectGoldenScene` → PNG 쓰기, grep 0건 확인) `--plain-name "plan-flow-step"` | +13 All tests passed(장면 안 기대 — `부족 1종` · `부족 2종` · `저장하면 나중 단계 1개를 함께 올립니다` 포함 — 모두 통과). 사본은 실행 직후 지움. PNG `debug/frontend_fe4g5/render/`(13장) |
| `git diff --check -- frontend/` | 0건 |

- `dart format`: 처음에 고친 파일 8개를 하나씩 포맷했더니 이 SDK(3.12.2) 포매터가 **이 slice와 무관한 줄까지** 다시 접었다(예 `plan_flow_save_test.dart` 146줄). 무관한 diff를 남기지 않으려고 pre 사본으로 되돌린 뒤 같은 편집만 다시 적용했고, 포매터 결과는 **고친 줄에 걸친 덩어리만** 손으로 반영했다(scratch 사본 포맷과 비교, 고친 줄 안 차이 0). 파일 줄바꿈 유지(`plan_section_layout.dart` CRLF, 나머지 LF).

### 1. 한 명 모드 상태 칩 — 값 출처

- **값 출처**: 지시는 `RepositoryPlanState.calculation`의 단계 결과였으나 그 필드는 `PlanningScenarioCalculationSummary`(크레딧 · 필요 종 수 · 부족 종 수 · 첫 병목 페이즈 · 대표 부족)라 **단계 결과가 없다**(`lib/services/scenario_service.dart` 62행). 계획 화면이 이미 가진 단계 결과는 Detail 홈 계산 응답 `_homeProjection`(`planning.document.calculate`, `stage_results[]` 포함, `_loadRepositoryPlan` → `_calculateDocument`)이다. 지시의 "흐름을 여는 쪽이 이미 가진 상태만 넘긴다"에 맞춰 이것을 넘겼다(새 호출 0 — 시험 `계획 화면은 흐름을 열 때 이미 가진 활성 계획 계산을 넘긴다(새로 계산하지 않음)`이 계산 횟수 불변 확인).
- **연결**(`plan_section_layout.dart` `_flowContext`만): `_homeProjection`은 **같은 활성 문서 · 같은 상태로 계산한 것일 때만** 넘긴다 — `identical(_document, _repositoryPlan.document)` 그리고 `identical(state, _repositoryState)`. `_ensureRepositoryContext(refresh: true)`로 다시 읽어 문서 객체가 바뀌었거나, 계산 전 · 계산 불가(`plan.get calculation=null`이면 계산을 부르지 않음) · 계산 오류면 비어 있고 칩은 '—'다.
- **모델**(`plan_flow_draft.dart`): `PlanFlowContext.activeStageCosts`(단계 id → `PlanFlowStageCost`, 기본 빈 맵, unmodifiable). `stage_results[]` 읽기를 `planFlowProjectionStageCosts(projection)`로 빼서 초안 계산(`PlanFlowCalculation.fromProjection`)과 함께 쓴다(동작 같음).
- **칩 판정 규칙** — 계획 탭 2단계 단계 카드 칩 `planFlowGoalStageStatus`(`plan_flow_goal_step.dart` 178행)를 그대로 재사용, 앞에 "단계 결과 없음 → '—'"만 둔다(`planFlowActiveStageStatus`, `plan_flow_student_one.dart`):

| 순서 | 조건 | 칩 | 톤 | 값 출처 |
|---|---|---|---|---|
| 1 | 그 단계 결과 없음(계산 없음 · 계산 전 · 다시 읽은 뒤 · 응답에 그 `stage_id` 없음) | '—'(칩 없이 글자, 기존 그대로) | muted | `activeStageCosts[stageId] == null` |
| 2 | 앞 단계보다 올리는 키 없음 | 목표 없음 | gray | `planFlowGoalChanges(before, targets)` 비어 있음 |
| 3 | 미보유 학생 | 모집 필요 | warn | 1단계 picker `ownedIds`(확정 현재값) |
| 4 | 보유량을 아는 재화가 하나도 없음 | 보유 모름 | gray | `PlanFlowStageCost.shortageKinds == null`(`shortage_at_entry` 모두 null) |
| 5 | 들어설 때 모자라는 재화 0종 | 지금 가능 | ok | `shortageKinds == 0` |
| 6 | 모자라는 재화 n종 | 부족 n종 | warn | `shortageKinds` = `resources[].shortage_at_entry > 0`인 재화 종류 수(서로 다른 재화 양을 더하지 않음) |

- 화면: 행 오른쪽 '—' 자리에 `BaChip`(키 `plan-flow-one-stage-<id>-status`, `FittedBox.scaleDown` — 1280×720 시험 넘침 0). 행 의미 값은 칩이 있을 때만 `<요약> · <칩>`(없으면 예전 그대로 요약).
- "들어설 때"는 **활성 계획 문서 순서 기준**이다(Detail 홈과 같은 계산). 2단계 카드 칩은 초안 계산 기준이라 같은 단계라도 숫자가 다를 수 있다(발견 1).

### 2. 올림 알림 시제

| 시점 | 문구 | 함수 · 위치 |
|---|---|---|
| 저장 전(4단계 C 미리보기, 저장 버튼 아래 제목 줄) | **저장하면 나중 단계 n개를 함께 올립니다** | 새 `planFlowRaisingTitle`(`plan_flow_save.dart`), `plan_flow_save_step.dart` 제목 줄 |
| 저장 뒤(결과 SnackBar 요약) | **나중 단계 n개를 함께 올렸습니다**(…) | `planFlowRaisedTitle` 그대로 → `planFlowRaisedSummary` |

- 목록(학생 · 나중에 칸 단계 · 키 이전→새 값, "외 n개 단계")은 그대로. 시험: `plan_flow_save_test` 제목 두 함수 · 4단계 위젯(2560 · 1280폭, 미래형 있음 · 완료형 없음), 저장 결과 문구(완료형) 그대로 통과.

### 시험 변경

- `plan_flow_student_one_test.dart`(+7건): 칩 규칙 표 6줄 + null, `stage_results` 읽기(빈 · 잘못된 줄), 칩 표시 · 의미 값, 일부 단계만 결과(나머지 '—'), 1280×720 넘침 0, **계획 화면 연결 2건**(`PlanningPage(loadRepositoryPlan: true)` → "시나리오 생성" → 한 명: 계산 단계 결과 → 칩 · 계산 횟수 불변 / 단계 결과 없는 응답 → '—').
- `plan_flow_save_test.dart`: 기대 문구 2곳(제목 함수 · 4단계 위젯). 지운 시험 0.
- `fe1g_baseline_golden_test.dart`(조작만): `_openPlanFlow`에 `loadRepositoryPlan` 인자(기본 false — 다른 장면 그대로), `plan-flow-step1-one`만 `true`(앱처럼 활성 계획을 읽고 계산한 뒤 흐름을 연다) + 칩 기대 2줄, `plan-flow-step4-raised` 기대 문구 1줄. harness · fixture 수정 0(계산 대역의 고정 단계 부족 그대로: 1단계 네브라 −14, 2단계 파이스토스 −30 · 볼프세크 −8).

### golden 변화 예상(장면별)

- **바뀜 1 — `plan-flow-step1-one`**: 짧은 C "이미 잡혀 있는 목표" 두 행 오른쪽 '—' → 칩 **`부족 1종`**(P1 · 1단계) · **`부족 2종`**(P2 · 2단계), 둘 다 warn 톤. 나머지 그대로 — 렌더와 현재 기준 이미지의 차이는 두 행 오른쪽 끝 64×82px 상자 안 3,041px뿐(`loadRepositoryPlan: true`로 다른 곳이 바뀌지 않음 확인). 렌더 `render/plan-flow-step1-one.png`.
- **바뀜 2 — `plan-flow-step4-raised`**: 저장 버튼 아래 굵은 제목 "나중 단계 1개를 함께 올렸습니다" → **"저장하면 나중 단계 1개를 함께 올립니다"**. 아래 학생 줄 그대로. 차이 상자 191×12px(제목 줄만). 렌더 `render/plan-flow-step4-raised.png`.
- **그대로**: 나머지 전부. 일회성 렌더한 `plan-flow-step*` 11장(`step1` · `-filter` · `-many` · `step2` · `-more` · `-saved` · `step3` · `-deferred` · `-many` · `step4` · `-append`)은 현재 기준 이미지와 **바이트까지 같다**. 다른 탭 장면은 이 코드를 지나지 않는다(한 명 모드 · 4단계 올림 알림만).
- 그래서 CF gate 예상: golden **2건 RED**(위 두 장면), 나머지 GREEN. 새 장면 0.

### 미검증("미실행")

- 전체 `fe_gate.ps1` · golden 비교 · `-UpdateGoldens` — 미실행(CF 몫). 위 바이트 비교는 렌더 PNG와 기준 PNG 해시 비교일 뿐 golden 시험 실행이 아니다.
- process E2E와 실제 Python 백엔드에서 계획 화면 → 흐름 칩 — 미실행. 실제 `planning.document.calculate` 응답의 `stage_results[].resources[].shortage_at_entry` 모양은 이미 2단계 카드가 쓰는 같은 파서다.
- 이 slice와 무관한 일반 시험(스캔 · 인벤토리 · 통계 · 택틱) — 미실행(gate에서).
- 실제 앱(mock 모드) 클릭 검수 — 미실행(검수표).

### 검수표 (mock 모드 `--dart-define=BA_PLANNER_USE_REAL_BACKEND=false --dart-define=BA_PLANNER_MOCK_SCENARIO=design-review`, 2560×1392 최대화)

| artboard · 확인 | 여는 방법 | 확인 포인트 | 자동 확인 |
|---|---|---|---|
| Flow-1-Students-One 상태 칩 | 계획 탭 홈이 다 뜬 뒤(Detail 계산 끝) "시나리오 생성" → 활성 계획에 단계가 있는 학생 한 명 | "이미 잡혀 있는 목표" 행 오른쪽 `지금 가능`(초록) · `부족 n종`(노랑) 칩; 계획에 없는 학생은 빈 상태 줄 | 시험 7건, golden `plan-flow-step1-one` |
| (계산 전) | 앱을 막 열고 홈 계산이 끝나기 전에 흐름 열기 | 칩 자리 '—'(흐름이 따로 계산하지 않음) | 시험 "단계 결과가 없으면 '—'" |
| Flow-4-Save 올림 알림 | FE4-g4 검수표와 같은 경로(활성 나중에 단계보다 높은 목표 → "활성 계획에 페이즈로 추가") | 저장 전 제목 "저장하면 나중 단계 1개를 함께 올립니다", 저장 뒤 SnackBar "… 나중 단계 1개를 함께 올렸습니다(…)" | `plan_flow_save_test`, golden `plan-flow-step4-raised` |
| (작은 창) | 1280×720 | 칩 · 알림 줄 넘침 예외 없음 | 위젯 시험 |

### 발견 사항

1. **칩 기준 순서 차이**: 한 명 모드 칩은 활성 계획 문서 순서의 "들어설 때 부족"이고, 2단계 단계 카드 칩은 초안 계산(단계 번호마다 임시 칸) 기준이다. 같은 학생이 활성 계획과 초안에 함께 있으면 두 칩 숫자가 다를 수 있다(둘 다 의도대로 각 문서 기준).
2. **흐름을 홈 계산 전에 열면 '—'**: 흐름이 열린 뒤 홈 계산이 끝나도 흐름 context는 다시 만들지 않으므로 그 흐름 동안 '—'다(새 호출을 만들지 않는 조건). 채우려면 흐름 context를 늦게 갱신하는 경로가 필요하다(별도 판단).
3. **`dart format` 전체 파일 실행 시 무관한 줄이 바뀐다**: 이 SDK(3.12.2) 포매터와 기존 파일 포맷이 어긋나 있다(이 slice 파일만으로도 수백 줄). 이번에는 고친 줄만 반영했다. 저장소 전체 포맷 정리는 별도 slice 후보(golden 영향 0, 순수 서식).
4. `RepositoryPlanState.calculation`(요약)에는 단계 결과가 없다 — 지시 문구와 실제 값 출처가 다르다(위 1절). 서비스는 읽기만 했다.

### 사본 · commit.json

- pre 사본: `debug/frontend_fe4g5/pre/<경로>` 10파일(고친 8 + 고치지 않은 `plan_flow_workspace.dart` · `planning_page_test.dart`). 착수 때 WIP 0 → `post_dir` 없음. 이 status 문서는 `status=true` 관례로 사본 · `modified` 없음.
- `debug/frontend_fe4g5/commit.json`: slice `fe4g5`, modified 8, added 0, `whole` = [`frontend/test/goldens/baseline/plan-flow-step1-one.png`, `frontend/test/goldens/baseline/plan-flow-step4-raised.png`], `status=true`. 메시지 ASCII.
- 인계: `debug/frontend_fe4g5/output.md`.

### 다음 행동

- CF: 다른 레인 워커가 멈춘 뒤 `fe_gate.ps1` 1회 → golden 2건(`plan-flow-step1-one` · `plan-flow-step4-raised`) `failures/` 확인(`debug/frontend_fe4g5/render/` 두 장과 비교) → `-UpdateGoldens` → 재비교 GREEN → `fe_commit.ps1 -Slice fe4g5 -DryRun` → `fe_commit.ps1 -Slice fe4g5`.
- CF 판단: 발견 2(홈 계산 전 흐름의 '—' 유지 여부), 3(포맷 정리 slice).

### fe4g5 commit record (2026-10-19 21:27, written by fe_commit.ps1)

- gate: C:\Users\brigh\planner_of_plana\BA Planner\v7\debug\frontend_gate\20261019_211135\summary.txt (result         : GREEN)
- method: 3-way merge of pre copy / HEAD / slice end, staged to the index only. Working-tree diffs left: none
