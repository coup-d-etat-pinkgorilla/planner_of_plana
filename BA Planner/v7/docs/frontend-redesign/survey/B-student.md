> 오케스트레이터 조사 보고서(2026-10-05, 읽기 전용 조사). 본문의 `/mnt/user-data/uploads/v7/`는 저장소 루트, `.../scratchpad/canvas/project/`는 `docs/frontend-redesign/prototype/2026-10-05/`에 해당한다. [확인]은 grep·파싱으로 확인한 사실, (추정)·[추정]은 해석이다. 결정은 `docs/frontend-redesign/decision-register.md`가 우선한다.

# 그룹 B — 학생 탭 + 학생 관련 부품 조사 보고

조사 대상 artboard 9개: Student, Student-Filter, W-Card-Variants, W-Card-States, W-Card-Grid-DE, W-Student-Detail, W-Student-Search, W-Student-Actions, W-Bond-Variants.
비교 코드: `frontend/lib/ui/pages/student_page.dart`, `ui/widgets/student_section_layout.dart`(4858줄), `ui/studio/student_studio_layout.dart`, `ui/widgets/{bond_rank_portrait, student_portrait_status_overlay, student_grid_warmup, asset_image_grid, student_range_condition_section, diagonal_media_list_item}.dart`, almanac `student-card-rendering-lessons-2026-08-02.md`, `student-detail-indicator-lessons-2026-08-01.md`, `section-template-studio.md`(학생 탭 절: 508–579, 642–670, 771–849행).

표기 규칙
- **[확인]**: artboard HTML 또는 코드를 grep/파싱해 직접 확인한 사실. **[추측]**: 확인 근거가 없는 해석.
- 좌표: 학생 탭 artboard는 2560×1392 page 안에서 Section canvas가 `(0,184)`부터 `2560×1208`이다. 아래 Section rect는 **canvas 로컬 좌표**(page y = canvas y + 184). 팝업 rect는 **page 좌표**.
- 모든 학생 탭 artboard의 `<script type="text/x-dc">`는 `class Component extends DCLogic { renderVals() { return {}; } }` 뿐이라 **상태 로직은 없음 [확인]**. 상태는 정적 변형과 라벨로만 표현된다. 애니메이션은 CSS `@keyframes stuform2/3/4`(다중 폼 교대) 하나뿐이다.

---

## 0. 핵심 결론: 채택안 판정과 Student.dc.html ↔ 현재 코드 diff

### 0-1. 대안 artboard별 "채택" 근거

| 대안 묶음 | 채택안 | 근거 (원문) | 판정 |
|---|---|---|---|
| 인연도 표현 (W-Bond-Variants: v7 현재 / A / B / C / D) | **B · 목표 겹쳐 보기** | canvas.json 제목 `"인연도 표현 대안 (S3 삼각형 자리) · B 채택"`. 보드 안 라벨 `"B · 목표 겹쳐 보기 ✓ 채택"`, 설명 `"채택됨 · 학생 상세에 적용. 지금 랭크는 진하게, 계획 목표(30)는 빗금으로 겹칩니다. 숫자 위에 →30."` B 카드에만 `border:2px solid #7fe3bd` 강조 박스. Student.dc.html의 bond 삼각형 SVG가 B 변형과 **바이트 단위로 같음**(`pattern id="hat56"`, `→30`). Flow-1-Students-One에도 같은 hatch가 있음 | **명시적 채택 [확인]** |
| 학생 카드 속성/이름 표현 (W-Card-Variants: v7 현재 / A / B / C / D / E) | **D + E 조합** (D = 오른쪽 위 글자 칩, E = 이름은 카드 밖) | W-Card-Variants 자체에는 "채택" 표시가 **없음**. 그러나 ① 별도 보드 W-Card-Grid-DE 제목 `"학생 그리드 · 글자 칩 + 이름 카드 밖"`, 부제 `"그리드 미리보기 · 글자 칩(D) + 이름은 카드 밖(E)"`, ② `UI-Elements.dc.html`(제목 "UI 요소 사전 (v7 수치)")의 카드 사양 문구 `"학생 카드: 252:204 · … · 속성 = 오른쪽 위 글자 칩 2개(공격·방어색, h max(14,.11h), 80° 변 따라 계단) · 이름 = 카드 밖 아래 20px 줄(미보유는 흐리게) · 흰 외곽선 1% / 선택 #ff72b6 2%"`, ③ Student.dc.html·Student-Filter·Flow-1-Students(-Many/-One) 전부가 DE 카드 구조(스큐 칩 96개, 카드 밖 이름 span) 사용 | **사실상 채택 [확인]**, 단 "채택" 단어는 없음 → 모호점 B-1 |
| E안 세부: "2색 밑줄" | **미채택(제외)** | E안 설명은 `"카드 맨 아래 가장자리에 2색 밑줄만 남기고 이름은 카드 아래로"`이고 E 카드 HTML에는 내부 `<svg>`(밑줄)가 있지만, DE 그리드와 Student.dc.html 카드에는 그 밑줄이 **없음**. 속성 색은 D의 칩이 담당 | [확인] (칩과 밑줄 중복을 뺀 것으로 [추측]) |
| 필터 (현행 Section 5 + 범위 카드 2장 vs 팝업) | **팝업 재구성** | canvas 노트 `studentTab`: `"학생 탭 — v7 원형 · 필터 팝업 재구성"`, 보드 제목 `"학생 · 필터 팝업 (속성 칩 + 성장 범위 슬라이더)"`, W-Filter-Widgets 설명 `"학생 탭 · 계획 만들기 1의 필터 팝업 조각. 속성은 토글 칩, 성장 값은 최소~최대 한 줄 슬라이더(v7 이상/이하 두 패널을 합침)."` | **명시적 [확인]** (대안 비교 보드가 없고 단일안) |
| 학생 카드 상태 (W-Card-States) | 대안이 아니라 상태 카탈로그 | 라벨: `선택 + PLAN · 인연 20+`, `보유 · 인연 50+`, `보유 · 인연 100`, `UNOWNED + PLAN`, `태그 3개 · 폼 2개(3초)`, `폼 2개(3초)` | 해당 없음 |

### 0-2. "1:1 이식"이라는 Student.dc.html이 실제로 현재 코드와 다른 점 (정확한 diff)

Section 외곽 기하(S1~S4 rect, 사선, 12px seam)는 `studentStudioDocument` 격자값과 일치한다 **[확인: 계산]**:
S3 = `SectionGridRect(68,32,28,62)` → x=68/96·2560=1813.33, y=32/96·1208=402.67, w=746.67, h=780.17 = artboard `(1813.33,402.67,746.67,780.17)`. S1 = `(0,2,7,58)` → `(0,25.17,186.67,729.83)` 일치. S4는 `studentSectionRect`의 `element-4` 보정식(`detail.left + (detail.bottom − rect.bottom)/tan80°` = 1955.3)과 artboard `left:1955.34` 일치. S2 path 시작점 x≈198.7 = `actionRect.right(186.67) + studentSectionBevelGap(12)` 일치.
따라서 **"1:1"은 Section/Container 기하와 S1·S3 내용에 대해서는 맞고, 아래 항목들은 1:1이 아니다.**

| # | 영역 | 현재 코드 (근거 심볼) | Student.dc.html | 출처 |
|---|---|---|---|---|
| D1 | 카드 속성 표시 | `StudentGridCardOverlayPainter._paintCardOverlay`: 카드 하단 16%(`studentCardInfoAreaFraction=0.16`) 중 위 3%(`studentCardAttributeAreaFraction=0.03`)를 좌우로 나눈 공격/방어 **색 띠** | 카드 **오른쪽 위 글자 칩 2개**(`신비`/`중장`), `skewX(-10deg)`, h 18.4, font 10.1px w800, 첫 칩 `right:10 top:4`, 둘째 칩 `right:13.7 top:25.4`(80° 계단, 3.7 = 21.4/tan80°). 색은 `studentAttackTypeColor`/`studentDefenseTypeColor`와 동일(예: Mystic `#226f9b`, Heavy→`#bd8901`) | DE 채택 |
| D2 | 방어 타입 라벨 | `studentFilterValueLabels['defense_type']` = `경장갑/중장갑/특수장갑/탄력장갑/복합장갑` | 카드 칩은 **축약형** `경장/중장/특수/탄력`(필터 팝업은 여전히 `경장갑…`) | 신규 라벨 맵 필요 |
| D3 | 이름 위치 | 카드 **안** 하단 13% 회색 띠(`0xb35b626b`) + 흰 글자, `studentCardNameFontSize` 6~12px | 카드 **밖 아래** 별도 span: 카드 bottom+3, 높이 16, 폭 = 카드 하단 변 길이(206.87−29.53=177.34), 13px w700, 보유 `#f4f8fb`, **미보유 `#9eb0c2`(흐리게)** | DE 채택 |
| D4 | 그리드 행 기하 | `_StudentDiagonalGridState`: 셀이 **정사각형**(`cellSize` 폭=높이), 카드(252:204)를 셀 안에 `BoxFit.contain` 세로 중앙 → 행 피치 = cellSize+3.84 ≈ **210.7px** (카드 위아래 약 19.7px 여백) | 카드가 셀 **위에 붙고**(top 8 = `_gridInset`) 아래에 이름 줄. 행 피치 **191.31px**(카드 167.47 + 이름/간격 23.84), 행별 x 이동 33.73 = 191.31/tan80°, 행 중심 = 카드 중심 기준 | 8열·열 피치 211.67(=206.87+4.8)은 동일 |
| D5 | 상태 배지 배치 | `studentGridStatusBadgeRects`: **고정 슬롯** — UNOWNED 좌상, PLAN은 항상 UNOWNED 아래, **JP는 카드 우상 모서리** | **채워 쌓기(packing)**: 존재하는 배지만 80° 좌변을 따라 위에서부터 UNOWNED → PLAN → JP 순. 보유+PLAN이면 PLAN이 1번 슬롯 `(29.53,0.84)`, UNOWNED+PLAN+JP면 `(29.53,0.84)/(25.10,25.96)/(20.67,51.08)`. 우상단은 속성 칩이 차지 | 크기(87/58/37×23)와 pill 스타일은 코드값 그대로 |
| D6 | 다중 폼 교대 | 없음 (`StudentCatalogEntry`에 폼 필드 없음, 그리드 아이템은 `assets/student_portraits/<id>.png` 1장) | 폼이 2개인 학생(호시노(무장), 슌(수영복))은 초상 `<img class="stuform2">` 2장을 6초 주기 `step-end`로 교대(각 3초). CSS에 `stuform3/4`(9s/12s)도 정의 | W-Card-States `"폼 2개(3초)"` |
| D7 | S3 인연 게이지 | `StudentBondStatus(bondRank, outerPath)` + `_StudentTriangleBondGaugePainter`: rank/100 분홍 fill(`studentSortAccentColor` α0.78) | B안: 현재 랭크 fill `#e9b0ee`(불투명) + **계획 목표까지 빗금 패턴**(`rgba(233,176,238,.55)` 2.4px 줄, −35° 회전) + 목표 높이 **점선**(`stroke-dasharray 3 2`) + 텍스트 **`→30`**(GyeonggiTitle 10px w800). 숫자 43.2px는 동일 | B 채택 |
| D8 | S4 내용 | `container-14` 검색 + 토글 4개만 | 토글 4개 아래 신규: 구분선(y226.2) / **결과 수 줄** `표시 48 / 전체 170 · 보유 128 · 계획 중 8`(y232.2) / **적용 필터 칩**(`밀레니엄 ×` 등, 분홍 `rgba(233,176,238,.12)`+`× `, 우측 `모두 지우기` `#71c7f4`)(y264.2) / **최근 본 학생** 라벨(y300.2) + 50×40.5 미니 카드 6개(y322.2). 각 줄 left가 80° rail을 따라 감소(2003→1998.7→1992.7→1987.4→1980) | 신규 |
| D9 | 필터 진입 방식 | S1 필터 버튼 → `_toggleFilterSection`: Section 2를 260°로 퇴장 후 **Section 5(폭 1/4 평행사변형)** + `filterCompanion`(`StudentRangeConditionSection`)으로 교체 | Student.dc.html에는 Section 5가 **없음**. 필터는 Student-Filter.dc.html의 **전체 화면 모달**(scrim `rgba(6,10,16,.8)` + blur 2px, z 9000) | 팝업 재구성 |
| D10 | 정렬 표시값 | 기본 `StudentGridSort.nameAscending`(`이름 ↑`) | 닫힌 드롭다운에 `LV ↓`, 그런데 그리드 순서는 이름순(나구사, 나기사, 나기사(수영복)…)이고 맨 앞에만 폼 데모용 호시노(무장)·슌(수영복) | 샘플 상태로 [추측] → 모호점 B-7 |

**바뀌지 않은 것 [확인]**: S1 버튼 6개(aria-label `리스트 보기/그리드 보기/학생 정렬/포커스 학생으로 계획 열기/학생 스캔 열기/필터 열기` = 코드 tooltip과 동일), 정렬 드롭다운(투명 + `#e9b0ee` 1px 사다리꼴 + 15px), S4 검색과 토글 4개(16.5px, 27px cadence), S3의 LEVEL+학교, Position/Class/Weapon, SKILL SUMMARY, EQUIPMENT, Ability Release, 심상개화(잠금), STATS(아이콘+숫자), 성작 9칸(`aria-label="성작 3 · 전무 0"`), 선택 외곽선 `#ff72b6` 2%, 흰 외곽선 1%, 미보유 암전 `rgba(6,8,14,.46)`, 인연 배경 구간(`bondRankPortraitBackgroundAsset` 20/50/100), 그리드 스크롤 포그 36px, 사선 스크롤바.

---

## 1. Student.dc.html — "학생 — v7 원형 (student_section_layout 1:1 이식)"

### 1-1. 화면 목적과 섹션 구성 [확인]
학생 탐색(그리드) + 선택 학생 상세(읽기 전용) + 검색/표시 옵션 + 작업 버튼. 탭 헤더(`학생 / 학생 목록과 육성 상태`, `연결됨`)는 공통 AppShell(그룹 A 범위).

| Section | rect (canvas 로컬) | 형상 / 부착면 | 내용 |
|---|---|---|---|
| S1 `element-1` | (0, 25.17, 186.67, 729.83) | 사다리꼴, face left | 리스트(22.4,68.96,63.9×49.33)·그리드(83.6,68.96,72.6×49.33) 보기 토글, 정렬(22.4,154.77,118.67×49.33), 계획 열기(22.4,240.59,103.54×132.54), 스캔(22.4,409.63,73.73×132.54), 필터(22.4,578.67,43.92×132.54) |
| S2 `element-2` | (0, 25.17, 1968.57, 1182.83) | 평행사변형, face bottom, 좌상단 x≈198.7 | `container-12` (38.71,48.77,1913.69,1140.62) 안에 8열 사선 그리드, 하단 36px 포그, 사선 스크롤바 |
| S4 `element-4` | (1955.34, 25.17, 604.66, 352.33) | 사다리꼴, face right (S3 좌변 80° 연장선 공유) | 검색 `container-14` (2027.9,56.88,495.83×49.33), 토글 4개, 결과 수, 적용 필터, 최근 본 학생 |
| S3 `element-3` | (1813.33, 402.67, 746.67, 780.17) | 사다리꼴, face right | 초상 카드(1957.57,416.09,296.39×239.93), 성작 strip(svg @1934.84,671.96), LEVEL(2304.47,427.12,216.81×81.89), Position(2297.13,520.06), Class(2290.06,561.04), Weapon(2280.39,609.47), SKILL(1913.61,710.43,451.76×107.07), EQUIPMENT(1880.76,830.91,463.36×172.88), Ability Release(1873.75,1017.21,437.52×26.35), 심상개화(1856.88,1056.98,447.38×82.23), STATS(2303.39,710.49,217.07×428.68), 인연 삼각형(2464.77,824.32,56.10×318.16) |

paint 순서(DOM 순) = S2 → S4 → S3 → S1, 코드의 Stack 순서(list→4→3→1)와 같음.

### 1-2. 사용 요소
- **StudentCard(DE)** ×48(+S3 1장): 252:204 둥근 평행사변형 clip, 인연 배경 img + 초상 img(98%, `clip-path:inset(0 round 19.7px)` = `clipRadiusFraction 0.12`), 흰 1.67px 외곽선, 속성 칩 2, 상태 배지 pill(최대 3), 카드 밖 이름.
- **AttributeChip**: 스큐 −10° 사각, 공격/방어 색 배경, 흰 10.1px w800, 그림자 `0 1px 2px rgba(0,0,0,.4)`.
- **StatusBadgePill**: 기존 `paintStudentPortraitStatusBadge`와 같은 스타일(`rgba(6,8,14,.87)`, inset white .16, 10.1px w700).
- **DisplayToggleRow**(`.stutog`) ×4, **SearchField**, **CountSummaryRow**, **AppliedFilterChip**(×, 분홍), **TextLink**(`모두 지우기`), **RecentStudentThumb**(50×40.5 미니 카드, aria-label `최근 본 학생`).
- S1: **ViewToggle** 쌍, **SortDropdown**, **ActionButton**(연핑크 삼각 텍스처) ×3.
- S3: **LevelSchoolIndicator**, **MetadataRow**×3, **SkillSummary**, **EquipmentSummary**, **AbilityRelease**, **PotentialLocked**, **CombatStats**, **StarStrip**(9칸), **BondTriangle(B)**.
- 스크롤 포그(`div @(…,1104.6,1913.7,36)`), 사선 스크롤바(svg).

### 1-3. 상태·상호작용
- 정적 변형뿐. 표시 상태: 토글 1·2 켜짐, 3·4 꺼짐(`aria-pressed`), 정렬 `LV ↓`, 적용 필터 3개, 선택 학생 = 리오(무장)(S3).
- 애니메이션: 다중 폼 카드만 `stuform2`(6s step-end, `animation-delay:-6s/-3s`). intro/outro 표현 없음 → 현행 `studentSection1Motion(0/180)`, 2·5 `80/260`, `studentSection3Motion/4Motion(180/0)`를 그대로 유지한다고 [추측].

### 1-4. 현재 코드 대응
| 대상 | 분류 | 근거 |
|---|---|---|
| `studentStudioDocument`(student_studio_layout.dart), `studentSectionRect/Path`, `studentRuntimeContainers` | **그대로 재사용** | 기하 일치(0-2 머리말) |
| `StudentSectionLayout` / `_StudentSectionLayoutState` | **수정** | S4 신규 행(D8), 필터 진입을 모달로(D9), 상태 lift(적용 필터·최근 본 학생) |
| `StudentGridCardOverlayPainter` (`_paintCardOverlay`, `_paintName`, `_rowBounds`) | **수정(재작성 수준)** | D1·D3·D5. 이 painter는 `plan_element_builder.dart:1630`(1×1, name/attr off)과 `student_grid_warmup.dart:122`에서도 사용 → 시그니처 호환 필요 |
| `studentGridStatusBadgeRects` | **수정** | 고정 3슬롯 → 존재 배지만 채워 쌓기, JP 우상단 슬롯 폐기 |
| `studentCardInfoAreaFraction`, `studentCardAttributeAreaFraction`, `studentCardNameFontSize` | **폐기 대상** | 카드 안 정보 띠가 사라짐 |
| `StudentDiagonalGrid` / `_StudentDiagonalGridState` | **수정** | D4: 셀 높이 = 카드 높이 + 이름 줄, 행 offset 기준을 카드 중심으로. `_hitTargets`도 같은 셀 기하 공유. `plan_student_selector.dart:549`도 이 위젯을 사용 → 계획 그룹과 동시 변경 |
| `AssetImageGrid` / `AssetImageGridItem` | **재사용 + 확장 [추측]** | D6 폼 교대에는 같은 셀에 asset 교체 또는 아이템별 opacity가 필요. 현 필드(`asset, column, row, scale, clipRadiusFraction, edgeCropFraction, alphaThreshold, clipPathBuilder…`)에 시간 축 없음 |
| `StudentBondStatus`, `_StudentTriangleBondGaugePainter`, `studentBondGaugeFillRect` | **수정** | D7: `targetRank` 입력, 빗금 패턴, 점선, `→N` 텍스트 추가. `plan_element_builder.dart:1263`도 사용 |
| `_StudentStatusIndicators` 나머지(Level/Skill/Equipment/Ability/Potential/Combat/Star) | **그대로** | 텍스트·배치 동일 |
| `_StudentActionButton`, `_StudentSortDropdown`, `_StudentViewModeButtons`, `_StudentGridDisplayToggle` | **그대로** | 동일 |
| `bond_rank_portrait.dart`(`bondRankPortraitBackgroundAsset`) | **그대로** | 20/50/100 구간 동일(W-Card-States 라벨로 확인) |
| `student_portrait_status_overlay.dart`(`paintStudentPortraitStatusBadge`, `paintUnownedStudentPortraitStatus`) | **그대로** | 배지 색·크기·암전 동일 |
| `student_grid_warmup.dart`(`StudentGridImageWarmup`) | **수정** | warmup painter 인자(showAttributes/showNames) 의미 변경, 폼 이미지 사전 decode 대상 추가 |
| `diagonal_media_list_item.dart` / `StudentDiagonalList` | **그대로(시안 없음)** | 리스트 보기 artboard가 없음 → 모호점 B-8 |
| `student_page.dart` `StudentPage` | **수정** | 적용 필터·범위 조건을 닫아도 유지(현재 `onFilterVisibilityChanged(false)`에서 `_rangeConditions = initial()`로 초기화), 최근 본 학생 목록, 인연 목표 공급 |

### 1-5. 데이터 요구
| 값 | 출처 | 판정 |
|---|---|---|
| 공격/방어 타입, jpOnly, 학교, 이름 | `StudentCatalogEntry`(`planning.student.catalog`) | 있음 [확인] |
| 칩 축약 라벨(경장/중장/특수/탄력) | 없음 | 클라이언트 라벨 맵 추가(백엔드 불필요) |
| 보유 / PLAN | `RepositoryState.students`, `RepositoryState.goals[].studentId` (student_page.dart 304–342행) | 있음 |
| `표시 48 / 전체 170 · 보유 128 · 계획 중 8` | 필터 결과 길이, catalog 길이, ownedIds, plannedIds | 클라이언트 계산으로 충분 |
| 최근 본 학생 | 없음 | 클라이언트 상태 신규. 세션 한정인지 저장인지 미정 → B-6 |
| 다중 폼 초상 | `StudentCatalogEntry`에 폼 필드 없음. 폼 데이터는 개발자 도구 전용 `metadata.forms.get`/`metadata.forms.save`(developer_tools_main.dart 324·394행)에만 있음 | **catalog 프로토콜 확장 필요**(폼 목록 + 폼별 초상 asset 경로). 배포 정책상 이미지는 사용자 설치본에서 추출하므로 폼 초상 추출 대상 추가도 필요 [추측] |
| 인연 목표(→30) | `RepositoryGoalState.fromWire`의 허용 키에 `target_bond_rank`가 **없음**(repository_service.dart 237–262행; 넣으면 `FormatException`). 반면 `planningDocumentTargets`는 `goal['target_bond_rank']`를 읽고(planning_models.dart 299행), 계획 문서 stage targets에는 `bond_rank`가 있음(`planningDocumentTargetKeys`) | **출처 미정**: goal 프로토콜에 `target_bond_rank` 추가 또는 활성 계획 문서 stage 목표에서 가져오기 → B-3 |

### 1-6. 모호점
B-1(DE 채택 명시 없음), B-2(JP 배지 이동 vs 문서), B-3(인연 목표 출처), B-6(최근 본 학생 저장), B-7(정렬 샘플), B-9(이름 끄기 시 행 높이) — 아래 "모호점 목록" 참조.

---

## 2. Student-Filter.dc.html — "학생 · 필터 팝업 (속성 칩 + 성장 범위 슬라이더)"

### 2-1. 목적과 구성 [확인]
배경은 Student.dc.html과 **같은 화면**(텍스트 diff 결과 앞 235줄 동일) 위에 전체 화면 scrim(`inset:0; rgba(6,10,16,.8); backdrop-filter:blur(2px); z-index:9000`)과 모달(z 9001)을 올린 상태. Section 5 인라인 필터는 없다.

| 블록 | rect (page) | 형상 | 내용 |
|---|---|---|---|
| 헤더 바 | (453.8, 206, 1876.2, 92), 내부 (486.2,220,1807.3,64) | 사선 띠(`class="sw"` 그림자) | `필터` 제목, 결과 미리보기 `38 / 170명`, 적용 중 칩 `게헨나·딜러·폭발·레벨 70~90·EX 3~5`, `프리셋`(chip gy), `초기화`(tonal), `적용`(tonal pri), 닫기(aria-label `닫기`) |
| 왼쪽 패널 "속성" | (285.9, 320, 984, 930) | 행마다 평행사변형 strip, 행 x가 80° rail로 왼쪽 이동(461.4@y338 → 352.8@y984) | 제목 `속성` + 도움말 `같은 줄은 "또는", 줄끼리는 "그리고"`; 그룹 헤더(24h) + 칩 행(34h, 학교는 76h 2줄): 학교(13개 값+개수), 초기 성급(★1~★3), 공격 타입(폭발/관통/신비/진동, 색 막대), 방어 타입(경장갑~복합장갑, 색 막대), 편성, 역할, 포지션, **보유 · 서버**(보유/미보유/일본 서버 전용 제외) |
| 오른쪽 패널 "성장 범위" | (1127.9, 320, 1182, 930) | 같은 사선 행 stack(행 48h, x 1293.2@y412 → 1160.6@y1168) | 제목 `성장 범위` + `한 줄에서 최소 ~ 최대 · 좁힌 항목만 분홍` + `범위 모두 풀기`; 그룹 `기본`(학생 레벨, 성급=학생★+전용무기★ 9칸, 전용무기 레벨, 인연 랭크), `스킬`(EX, 기본, 강화, 서브), `장비 · 능력치`(장비 티어·장비 레벨 = "3칸 중 가장 낮은 칸", 애장품 T0~T2, 추가 능력치 = "HP · ATK · HEAL 합" 0~25), `심상개화`(상관없음/개방/미개방 + `v7 "준비 중" 자리`) |
| 상태 배지 | (18, 226) | 사각 pill, 분홍 테두리 `#f2b3ef` | 필터 아이콘 + `필터 · 5` (z 9002, scrim 위) |

### 2-2. 사용 요소
- **ToggleChip**(스큐 −10°, 켜짐 = `rgba(242,179,239,.2)` + `inset 1.5px #f2b3ef`, 꺼짐 = `rgba(255,255,255,.05)` + 1px outline, 우측 학생 수), **TypeChip**(앞에 8×14 색 막대), **RangeSliderRow**(`.srow`, 선택 시 `.srow.sel` 분홍, 눈금 `<i>`, 핸들 2개 12×16, 우측 `min ~ max`), **StarRangeBar**(9칸: 5칸 학생★ + 4칸 무기★), **SegmentChoice**(심상개화 3택), 헤더 **AppliedFilterChip**(`chip pk`), **PresetChip**, tonal 버튼 2, **ScrimModal**.
- 조각 정의는 W-Filter-Widgets.dc.html(다른 그룹 담당)에 있음: `"토글 칩 · 꺼짐 · 켜짐 · 개수 표시"`, `"범위 슬라이더 · 핸들 두 개 = 최소·최대. 기본값(전체)이 아니면 줄 전체를 분홍으로 강조."`, `"성급 + 전용무기 성급을 v7 9칸 막대 하나로."`, `"× 로 하나씩 뺍니다. 개수는 적용 전 미리보기."`, 필터 버튼 상태 `없음 / 필터 / 적용 중 / 필터 · 3`.

### 2-3. 상태·상호작용
- 정적 1상태: 게헨나·딜러·폭발 켜짐, 레벨 70~90·성급 ★3~무기★1·EX 3~M 좁힘(`.srow sel`).
- **적용 버튼이 있다 → 초안(draft) 편집 후 일괄 적용** 모델 [확인: 버튼 존재] / 현재 코드는 칩 토글 즉시 반영(`_toggleCatalogFilter` → setState). 헤더 숫자는 "적용 전 미리보기"(W-Filter-Widgets 문구).
- 같은 팝업이 Flow-1-Students-Filter(계획 그룹)에서 **`계획` 칩 그룹(계획 만들기 전용: 계획에 없는 학생만 / 다른 계획에 있는 학생 포함 / 목표를 이미 채운 학생 숨기기)** 을 더한 형태로 재사용됨 [확인: 텍스트 diff] → 공용 위젯 + 그룹 주입 구조가 필요.
- 열기/닫기 애니메이션 표현 없음.

### 2-4. 현재 코드 대응
| 대상 | 분류 | 근거 |
|---|---|---|
| `StudentFilterDefinition`, `studentFilterDefinitions`, `studentFilterValueLabels`, `studentFilterValueLabel`, `studentMatchesCatalogFilters` | **재사용(+ 확장)** | 학교/초기 성급/공격/방어/편성/역할/포지션 7그룹과 OR·AND 의미가 시안 도움말과 동일. `ownership` 라벨 맵은 이미 있으나 정의 목록에는 없음 → `보유 · 서버` 그룹 추가 |
| `StudentDiagonalFilterList`, `_StudentFilterGroupCard`, `_StudentFilterGroupPainter`, `studentFilterSectionPolygon/Path`, `studentFilterContainerPolygon/Path`, `studentFilterResetPath`, `studentFilterCompanionSectionRect`, `studentFilterSectionHorizontalInterval`, `studentDiagonalFilterRowWidth`, `studentFilterGroupContentInset`, `studentFoundationUsesLegacySectionChildren`, `studentFilterResetButtonSize`, `_toggleFilterSection`의 Section 2↔5 교체 | **폐기 대상** (팝업이 Section 5를 대체한다면) | D9. 단, 행이 80° rail을 따라 이동하는 계산(`studentDiagonalRowHorizontalOffset`)은 팝업 행 stack에도 필요 → 일반화해 재사용 [추측] |
| `student_range_condition_section.dart`의 `StudentRangeConditionSection`, `StudentRangeConditionGeometry`, `_ConditionEnabledControl`, `_ConditionResetButton`(이상/이하 `PlanPresetElementCard` 2장) | **폐기 대상** | W-Filter-Widgets: "v7 이상/이하 두 패널을 합침" |
| `StudentRangeConditions`(lower/upperEnabled + lower/upperTargets, `matchesStudent`) | **수정** | 행별 min/max로 재구성. 단 합성 행(성급 9칸, 장비 "가장 낮은 칸", 능력치 "합")은 기존 키별 비교와 의미가 다름(2-5) |
| `planElementTargetMinimums/Maximums`(planning_growth_rules.dart) | **재사용** | 행 기본 범위의 근거 |
| 팝업 셸, ToggleChip, RangeSliderRow, StarRangeBar, 프리셋 | **신규** | 현재 대응 위젯 없음 |

### 2-5. 데이터 요구
- 칩 옆 학생 수(`게헨나 28`), 헤더 `38 / 170명`: catalog + 현재 값으로 클라이언트 계산 가능. 개수가 "다른 그룹 선택을 반영한 조건부 개수"인지 "전체 대비 고정 개수"인지 미정(B-11).
- 범위 필터 값: `ConfirmedStudentState.values`의 `level, student_star, weapon_star, weapon_level, bond_rank, ex_skill, skill1~3, equip1~3, equip1~3_level, equip4, stat_hp/atk/heal` — 전부 있음 [확인: `_studentFields`, `_defaultValues`].
- 의미 차이 [확인: 코드]: 현재 `matchesStudent`는 `equip1_tier…equip3_tier`를 칸별로 비교. 시안 "3칸 중 가장 낮은 칸"은 **하한에서는 동치, 상한에서는 다름**(현행 = 모든 칸 ≤ U, 시안 = 최저 칸 ≤ U).
- 심상개화: 현재 `StudentPotentialStatus`는 잠금 표시만, 값 필드 없음 → 백엔드 데이터 없음.
- 프리셋: 저장 위치·형식 불명(B-10).

### 2-6. 모호점
B-4(모달 vs 확정 문서의 Section 5 계약), B-5(심상개화 빈 그룹), B-10(프리셋), B-11(개수 의미), B-12(추가 능력치 0~25), B-13(S4 토글과 `보유 · 서버` 중복), B-14(`필터 · 5` 배지 위치), B-15(화학 타입·스킬 최소값).

---

## 3. W-Card-Variants.dc.html — "학생 카드 · 속성/이름 표현 대안" (1498×1590)

1. 목적: 배경·초상 크기·비율은 고정하고 속성 색 2개와 이름 표현만 바꾼 비교(부제 원문). 6행(각 행 y=114/364/614/864/1114/1364, 행 구분선 1440×1), 각 행 = 왼쪽 설명(340w) + 카드 5장(리오(무장), 네루, 노아, 렌게, 나구사, 190×153.81).
2. 행별 내용 [확인: 라벨 원문]
   - `v7 현재` — "정보 영역 위쪽 3% 띠를 반으로 나눠 공격/방어 색, 아래 13%에 이름." (= 현재 코드)
   - `A · 이름 띠 = 속성 띠` — 이름 띠 자체를 공격색→방어색 그라데이션.
   - `B · 색 알약 + 이름` — 어두운 이름 띠 왼쪽 끝에 사선 알약 2개.
   - `C · 양쪽 사선 테두리` — 좌변 공격색, 우변 방어색.
   - `D · 글자 칩` — "오른쪽 위에 "폭발 / 특수" 같은 글자 칩 2개. 색만으로 구분이 어려운 사람도 읽을 수 있습니다. 태그(왼쪽 위)와 겹치지 않습니다."
   - `E · 이름은 카드 밖` — "카드 맨 아래 가장자리에 2색 밑줄만 남기고 이름은 카드 아래로. 초상화가 가장 많이 보이지만 행 높이가 20px 늘어납니다." (상단에 각 열 속성 `폭발 / 특수` 등 캡션)
3. 상태: 정적. 폼 교대 없음(stuform 0개).
4. 코드 대응: 채택 결과(DE)만 구현 대상. A/B/C 및 E의 밑줄은 **구현하지 않음**. `StudentGridCardOverlayPainter` 수정(1장 참조).
5. 데이터: 1장과 동일.
6. 모호점: B-1(이 보드에 채택 표시 없음), B-9(E의 "행 높이 20px 늘어남" 문구는 카드만 있는 행 기준이며, 실제 현재 코드는 정사각 셀이라 Student.dc의 DE 그리드가 오히려 행 피치가 19.4px 짧음 — D4).

## 4. W-Card-States.dc.html — "학생 카드 · 상태별" (1410×360)

1. 목적: DE 카드 6장의 상태 카탈로그(카드 200×161.9, 한 줄).
2. 요소: DE 카드, 라벨 텍스트.
3. 상태 [확인: 라벨·스트로크]
   - `선택 + PLAN · 인연 20+`(리오(무장)): `stroke #ff72b6 3.24`(= 0.02×161.9) + 흰 1.62, 파랑 배경.
   - `보유 · 인연 50+`(노아), `보유 · 인연 100`(네루): 노랑/보라 배경.
   - `UNOWNED + PLAN`(나구사): 암전 + 2배지 세로 스택.
   - `태그 3개 · 폼 2개(3초)`(슌(수영복)): UNOWNED/PLAN/JP 3배지 + `stuform2`.
   - `폼 2개(3초)`(호시노(무장)): 보유, 배지 없음 + `stuform2`.
4. 코드 대응: 선택·외곽선·배경 구간·암전은 **그대로**(`studentGridCardSelectionColor`, `studentGridCardSelectionWidthFraction 0.02`, `bondRankPortraitBackgroundAsset`). 배지 스택은 `studentGridStatusBadgeRects` **수정**(D5). 폼 교대 **신규**(D6). 이 보드는 위젯 테스트 fixture 목록으로 그대로 쓸 수 있음 [추측].
5. 데이터: 폼 데이터(1-5 참조).
6. 모호점: B-2, 폼 교대 주기 3초가 고정인지(CSS는 폼 수×3초).

## 5. W-Card-Grid-DE.dc.html — "학생 그리드 · 글자 칩 + 이름 카드 밖" (1708×940)

1. 목적: DE 채택안의 그리드 미리보기. 컨테이너 (46.68,84,1614.75×812) CLIP, 하단 포그 36px.
2. 요소: DE 카드 41장, **7열**, 카드 200.80×162.55, 행 피치 192.55, 행 x 이동 33.95(=192.55/tan80°).
3. 상태: 정적, 폼 교대 2장.
4. 코드 대응: `StudentDiagonalGrid` 수정. 열 수는 위젯 폭이 1708이라 7열로 보인 것이고, 실제 탭(Student.dc)은 **8열 유지**(`columns = 8` 기본값) [확인: Student.dc 8장/행].
5. 데이터: 1장과 동일.
6. 모호점: 없음(Student.dc가 8열이므로 7열은 미리보기 폭 탓으로 판단 [추측]).

## 6. W-Student-Detail.dc.html — "학생 상세 (S3 · 인디케이터)" (802×836)

1. 목적: S3 단독 부품. 텍스트 목록이 Student.dc S3와 동일(`LEVEL Lv. 78 … STATS 48,210 5,812 412 1,180 →30 20`) [확인].
2. 요소: 1-2의 S3 요소 전부 + 인연 B.
3. 상태: 정적(리오(무장), PLAN 배지, 인연 20 → 목표 30).
4. 코드 대응: `_StudentStatusIndicators` **그대로**, `StudentBondStatus` **수정(B안)**. 나머지 인디케이터 클래스(`StudentLevelStatus`, `_StudentMetadataValue`, `StudentSkillStatus`, `StudentEquipmentStatus`, `StudentAbilityStatus`, `StudentPotentialStatus`, `_StudentCombatStatus`, `StudentStarStatus`) 변경 없음.
5. 데이터: 인연 목표 출처(B-3). 그 외 `ConfirmedStudentState.values`로 충분.
6. 모호점: B-3. 또 B안의 채움은 여전히 rank/100 비율이라 W-Bond-Variants의 "v7 현재" 비판("20은 늘 거의 비어 보입니다")은 해소되지 않음 — 의도된 것인지 확인 필요(B-16).

## 7. W-Student-Search.dc.html — "학생 검색 (S4)" (660×408)

1. 목적: S4 단독. 텍스트 = `학생 이름 검색 / 토글 4 / 표시 48 / 전체 170 · 보유 128 · 계획 중 8 / 적용 필터 밀레니엄× 스트라이커× 폭발× 모두 지우기 / 최근 본 학생` [확인].
2. 요소: SearchField, DisplayToggleRow×4, CountSummaryRow, AppliedFilterChip×n + `모두 지우기`, RecentStudentThumb×6.
3. 상태: 정적. 칩 `×`로 개별 해제, `모두 지우기`로 전체 해제(W-Filter-Widgets 문구 "× 로 하나씩 뺍니다").
4. 코드 대응: `TextField(key: 'student-search')`, `_StudentGridDisplayToggle` **그대로**. 아래 3행 **신규**. 적용 필터 칩은 팝업과 상태를 공유해야 하므로 필터 상태를 `_StudentSectionLayoutState`의 `_selectedCatalogFilters`에서 꺼내 page 또는 별도 controller로 올려야 함 [추측].
5. 데이터: 1-5와 동일(전부 클라이언트 계산 + 최근 본 학생 신규 상태).
6. 모호점: B-6, B-13. 적용 칩이 범위 조건(레벨 70~90 등)도 보여 주는지 — S4 샘플에는 속성 칩만 있음(B-17). 칩이 많을 때 줄바꿈/스크롤 규칙 없음(B-17).

## 8. W-Student-Actions.dc.html — "학생 액션 (S1)" (242×785)

1. 목적: S1 단독. rect·aria-label 전부 Student.dc S1과 동일 [확인].
2. 요소: ViewToggle(리스트/그리드), SortDropdown(`LV ↓`), ActionButton 3(계획 열기/스캔/필터).
3. 상태: 그리드 보기 선택, 정렬 LV↓. 필터 버튼에 적용 개수 표시는 **없음**.
4. 코드 대응: `_StudentViewModeButtons`, `_StudentSortDropdown`, `_StudentActionButton` **그대로**. 필터 버튼 아이콘의 `groups_2_outlined` 전환(Section 5가 열린 동안)은 모달 방식에서는 불필요해질 수 있음 [추측].
5. 데이터: 없음.
6. 모호점: B-14(적용 개수 배지를 S1 필터 버튼에 붙일지).

## 9. W-Bond-Variants.dc.html — "인연도 표현 대안 (S3 삼각형 자리) · B 채택" (1947×776)

1. 목적: 같은 자리(S3 오른쪽 삼각형)의 인연 표현 5안 비교. 전제 문구: `"현재 인연 랭크 20 · 계획 목표 30 · 다음 랭크까지 62% 기준. 모양과 크기는 그대로, 채우는 방식만 바꿨습니다."` 각 안은 S3 전체 복제(텍스트 반복) + 하단 라벨.
2. 대안 [확인: 라벨 원문]
   - `v7 현재` — "삼각형을 아래부터 분홍으로 채우고 아래에 랭크 숫자. 100 기준 비율이라 20은 늘 거의 비어 보입니다."
   - `A · 카드 배경 구간` — 채움 색이 배경 단계(20 파랑·50 노랑·100 보라), 20·50 눈금.
   - **`B · 목표 겹쳐 보기 ✓ 채택`** — 현재 진하게 + 목표 빗금 + `→30`.
   - `C · 10칸 계단` — 10랭크씩 10칸.
   - `D · 하트 + 다음 랭크` — 하트 안 숫자, 게이지 = 다음 랭크 진행률 62%.
3. 상태: 정적.
4. 코드 대응: `StudentBondStatus` / `_StudentTriangleBondGaugePainter` **수정**(B만). 기존 inset·host path 계약(`studentBondGaugeHostPath`, `studentBondGaugeEdgeGap`, `studentBondGaugeBottomRadius`)은 유지. `inverted`(계획 화면 좌향) 모드에도 같은 B 표현이 필요한지는 계획 그룹과 조율(Flow-1-Students-One에 hatch 1건 [확인]).
5. 데이터: 목표 랭크 출처(B-3). A·C·D는 미채택이라 "다음 랭크 진행률"(경험치) 데이터는 불필요.
6. 모호점: B-3, B-16.

---

## 모호점 목록 (사용자 확인 필요)

| ID | 내용 | 근거 / 충돌 상대 |
|---|---|---|
| B-1 | 카드 표현 DE 채택이 **어디에도 "채택"으로 적혀 있지 않음**. UI-Elements 사양과 모든 학생 그리드 보드가 DE라 사실상 채택으로 판단했으나 명시 확인 필요 | W-Card-Variants(채택 표시 없음) vs W-Card-Grid-DE·UI-Elements |
| B-2 | **JP 배지를 우상단에서 좌측 스택 3번째로 옮김**(우상단은 속성 칩) + 배지 채워 쌓기. 확정 문서와 충돌 | `student-card-rendering-lessons` "JP: UNOWNED 오른쪽이 아니라 카드 상단 우측 rounded corner에 접함", "PLAN: UNOWNED 아래 …" (고정 슬롯) |
| B-3 | **인연 목표(→30) 데이터 출처**: ① repository goal에 `target_bond_rank` 추가(현재 `RepositoryGoalState.fromWire`가 거부 → 백엔드·프로토콜 변경), ② 활성 계획 문서 stage의 `bond_rank` 목표(여러 계획/단계가 있으면 어느 것?), ③ 목표가 없을 때 빗금·`→` 숨김 여부 | repository_service.dart 237–262행, planning_models.dart 299행 |
| B-4 | 필터를 **전체 화면 모달**로 바꾸면 Section 5(폭 축소 평행사변형, 260°/80° 교체 motion), filter companion, 44px 초기화 버튼 계약이 폐기됨. 확정 문서 갱신·삭제 여부 | `section-template-studio.md` 771–818행 "학생 Section 5 필터…" 및 표 "Section 5" 행 |
| B-5 | 심상개화 그룹(상관없음/개방/미개방, `v7 "준비 중" 자리`)을 빈 동작으로 노출할지 | 같은 문서: "현재 planning catalog protocol이 직접 제공하지 않는 v6 성장·스킬 metadata 그룹은 빈 동작으로 노출하지 않는다." |
| B-6 | 최근 본 학생: 개수(시안 6), 세션 한정/프로필별 저장, 클릭 시 선택만인지 스크롤 이동도 하는지 | 시안에 동작 설명 없음 |
| B-7 | 정렬 `LV ↓`는 샘플 상태인지 기본값 변경인지(현재 기본 `nameAscending`). 시안 그리드 순서는 이름순이라 라벨과 불일치 | `_gridSort = StudentGridSort.nameAscending` |
| B-8 | 리스트 보기(`StudentDiagonalList`) 시안이 없음 → 현행 유지로 볼지, DE 규칙(칩·배지 스택)을 리스트에도 적용할지 | S1에 리스트 버튼은 남아 있음 |
| B-9 | `학생 이름 표시`를 끄면 이름 줄(약 20px)을 접어 행 높이를 줄이는지, 빈 줄로 남기는지. 또 행 피치 191.3(시안) vs 210.7(현재 정사각 셀) 중 시안 값을 따르는지 | D4 계산 |
| B-10 | 팝업 `프리셋` 칩의 의미(필터 조합 저장?)와 저장 위치 | W-Filter-Widgets "모달 오른쪽 위 · 프리셋" 외 설명 없음 |
| B-11 | 칩 옆 학생 수가 "다른 조건 반영 후 개수"인지 "전체 catalog 기준 고정 개수"인지; 헤더 `38 / 170명`은 적용 전 미리보기로 명시됨 | W-Filter-Widgets "개수는 적용 전 미리보기" |
| B-12 | `추가 능력치 = HP·ATK·HEAL 합`인데 범위가 `0 ~ 25`. 각 능력치 최대가 25(`planElementTargetMaximums`)라 합은 0~75여야 함 — 합인지 "각각"인지 | Student-Filter 텍스트 vs planning_growth_rules.dart |
| B-13 | 팝업 `보유 · 서버`(보유/미보유/일본 서버 전용 제외)와 S4 토글(`미보유 학생 숨김`, `일본 서버 전용 숨김`)이 같은 상태인지, 하나를 없앨지 | 두 artboard에 동시 존재 |
| B-14 | `필터 · 5` 적용 개수 배지 위치: Student-Filter에서는 page (18,226)에 떠 있고, W-Filter-Widgets는 "검색 줄 끝"(계획 흐름 기준)이라 함. 학생 탭에서는 S1 필터 버튼(폭 43.92)에 붙이는지 | W-Student-Actions에는 배지 없음 |
| B-15 | 소소한 값 차이: 공격 타입에 `화학`(Chemical) 라벨이 코드에는 있으나 시안 칩에 없음(값이 catalog에 있으면 자동 노출 예정인지); 강화/서브 스킬 최소 `1`(시안) vs `0`(코드, 미개방) | `studentFilterValueLabels`, `planElementTargetMinimums` |
| B-16 | B안 채움 비율이 여전히 rank/100이라 "20은 거의 비어 보임" 문제는 그대로 — 의도인지 | W-Bond-Variants "v7 현재" 설명 |
| B-17 | S4 적용 필터 칩에 범위 조건(예: `레벨 70~90`)도 표시하는지, 칩이 넘칠 때 처리 | 팝업 헤더는 범위 칩 표시, S4 샘플은 속성 칩만 |
| B-18 | 범위 의미 변경 승인: 장비 티어·레벨 "3칸 중 가장 낮은 칸"은 상한 판정이 현행(칸별)과 달라짐; 성급은 학생★·무기★를 9단계 하나로 합침; 닫아도 범위 유지(현재는 닫으면 초기화) | `StudentRangeConditions.matchesStudent`, student_page.dart 353–360행 |

---

## 그룹 B 요약 — 구현 단위(vertical slice) 제안

| 순서 | slice | 내용 | 난이도 | 선행 의존 |
|---|---|---|---|---|
| B-S1 | **DE 학생 카드 painter** | `StudentGridCardOverlayPainter` 재작성(속성 칩, 카드 밖 이름, 미보유 이름 흐림), `studentGridStatusBadgeRects` 채워 쌓기, 칩 축약 라벨 맵, warmup 갱신. 외부 소비자(`plan_element_builder` 1×1, `student_grid_warmup`) 호환 | M | B-1·B-2 확인. 계획 그룹과 공용 painter라 동시 회귀 테스트(`student_studio_layout_test`, `plan_element_builder_test`) |
| B-S2 | **그리드 셀 기하 변경** | `StudentDiagonalGrid` 셀 높이 = 카드 + 이름 줄, 행 offset 기준을 카드 중심으로, `_hitTargets`·overlay·image grid가 같은 기하 공유. `plan_student_selector` 영향 확인 | M | B-S1, B-9 |
| B-S3 | **인연 B 게이지** | `StudentBondStatus(targetRank)` + 빗금/점선/`→N`, `inverted` 모드 포함 | S(UI) / M(데이터) | B-3 결정. ①안이면 백엔드 goal 스키마 + `RepositoryGoalState` 허용 키 추가 |
| B-S4 | **S4 확장** | 결과 수 줄, 적용 필터 칩(×/모두 지우기), 최근 본 학생 strip. 필터 상태를 layout state에서 page/controller로 lift | M | B-6, B-13, B-17. 공통 위젯: AppliedFilterChip(W-Filter-Widgets와 공유) |
| B-S5 | **필터 팝업** | 공용 모달 셸(scrim, 헤더 바, 2패널 사선 행 stack), ToggleChip/TypeChip, RangeSliderRow, StarRangeBar, draft→적용 흐름, `StudentRangeConditions` 재구성, Section 5·range card 코드 폐기 | L | 공통 위젯(W-Filter-Widgets, 다른 그룹), B-4·B-5·B-10·B-11·B-12·B-18 결정. 계획 흐름(Flow-1-Students-Filter)이 `계획` 그룹을 주입해 재사용하므로 인터페이스를 먼저 합의 |
| B-S6 | **다중 폼 교대** | catalog 프로토콜에 폼 목록·폼 초상 경로 추가, `AssetImageGrid` 시간 기반 asset 교체(3초), warmup에 폼 이미지 포함 | M~L | 백엔드: `planning.student.catalog` 확장(현재 폼은 `metadata.forms.get` 개발자 도구 전용), 사용자 설치본 이미지 추출 대상 확장 |

권장 순서: B-S1 → B-S2(카드·그리드는 한 번에 시각 확인) → B-S3 → B-S4 → B-S5 → B-S6.
B-S1~B-S3은 계획 그룹이 쓰는 공용 위젯(`StudentDiagonalGrid`, `StudentGridCardOverlayPainter`, `StudentBondStatus`)을 바꾸므로 계획 그룹 slice보다 먼저 끝내거나 같은 slice로 묶는다. B-S5는 공통 필터 위젯 구현 이후에 둔다.
문서 갱신 대상: `student-card-rendering-lessons-2026-08-02.md`(카드 정보 영역·배지 슬롯 절), `section-template-studio.md`(학생 카드 16% overlay, Section 5 필터, 카드 이름 크기 계약 절), `student-detail-indicator-lessons-2026-08-01.md`(인연 게이지 계약에 목표 겹침 추가).
