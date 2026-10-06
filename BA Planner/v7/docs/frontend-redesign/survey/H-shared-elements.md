> 오케스트레이터 조사 보고서(2026-10-05, 읽기 전용 조사). 본문의 `/mnt/user-data/uploads/v7/`는 저장소 루트, `.../scratchpad/canvas/project/`는 `docs/frontend-redesign/prototype/2026-10-05/`에 해당한다. [확인]은 grep·파싱으로 확인한 사실, (추정)·[추정]은 해석이다. 결정은 `docs/frontend-redesign/decision-register.md`가 우선한다.

# 그룹 H — 공통 요소·위젯 사전 (시안 ↔ Flutter 매핑 기반 조사)

조사 대상 artboard: `UI-Elements.dc.html`(canvas.json 제목 "UI 요소 사전 (v7 수치)", 노트 "UI 요소 사전 — v7 재사용 요소 전수 (워커 기준 화면)"), `W-Data-Widgets.dc.html`, `W-Layout-Widgets.dc.html`, `W-Filter-Widgets.dc.html`, `W-Info-Popover.dc.html`.
비교 코드: `frontend/lib/app/theme.dart`, `ui/widgets/*.dart`, `ui/studio/section_template.dart`, `ui/app_shell.dart`, `ui/app_section.dart`, 설계 문서 `section-template-studio.md`, `responsive-diagonal-layout-policy.md`, `diagonal-parent-child-layout-guidelines-2026-08-04.md`.

표기: **[확인]** = 파일을 grep/파싱해 직접 확인한 사실, **(추정)** = 확인한 사실에서 유추한 해석. 사용 빈도는 `canvas/project/*.dc.html` 53개 파일(Boss-*, Tactic-Cancel/Interval/Zoom30은 로컬에 없음)의 본문(`<helmet>`/`<style>` 제거 후)에서 class 토큰·패턴을 센 값이다.

---

## 0. 공통 CSS 계층 구조 [확인]

브리프는 helmet CSS를 무시하라고 했지만, 그룹 H에서는 이것이 곧 "요소 사전"이므로 분석했다.

| 계층 | 크기 | 포함 파일 | 내용 |
|---|---|---|---|
| 기본 CSS | 7,582자 | UI-Elements | 폰트(@font-face Pretendard 500/600/700, GyeonggiTitle 500), `.dsp .mut .cap .glass .sw .nav .nt .conn .devbtn .chip(6색+solid) .btn(pri/ghost/dng/sel-blue/sel-pink/done/tri/icon) .link .bd .srow(.sel/.blue) .row .plain .tile .dash .ord .pt .val .stars .tab .mini .seg/.su .card .chk .tog .devbar/.devcap/.dv/.devsep .mrow .tonal(pri/ghost/done/dng/cur) .viewsel .stp` |
| +13 규칙 | 8,812자 | 화면 대부분 | `.kv .bar2 .hm .ind .ilab .ihdr .slot .deck .pos` |
| +30 규칙 | 9,564자 | W-*, Title*, Statistics-Proposal | 위 + `.stucard .stutog .wlab .wsub` + 학생 카드 폼 순환 애니메이션 `stuform2/3/4` |
| 개별 블록 | — | 화면별 | `.info/.ib/.pop`(29파일), `.flyw/.fly/.fr`(15), `.phw/.php`(2), `.shw/.shp`(5), `.sdot/.spop`(2), `.hm.sk`(5), `.nd`(1), `rs*-{id}` 사선 레일 목록(3), `sv*-{id}` 사선 세로 스크롤(5), Home 연결 이펙트 keyframes(1), Tactical-Timeline 전용 `.blk .lane .card3 …`(1) |

모든 W-*/UI-Elements의 `<script type="text/x-dc">`는 `renderVals(){return {};}` 뿐이다 — **상태 로직 없음, 정적 카탈로그**. 상호작용은 CSS `:hover/:focus-within/.open` 과 scroll-timeline 애니메이션으로만 표현된다.

---

## 1. UI-Elements.dc.html — UI 요소 사전 (2560×1392)

### 1.1 목적과 구성
v7 Flutter 구현의 수치를 그대로 옮긴 "재사용 요소 전수" 보드. 섹션 프레임 없이 8개 번호 블록이 절대좌표로 배치된다.

| # | 블록 | rect(x,y,w,h) | 내용 |
|---|---|---|---|
| 1 | Diagonal Media List Item | (40,80) 520×65 ×3행(gap 7) | `button.mrow` 80° 평행사변형 r7, 채움 canvas@.58 / 테두리 outline@.46 1.4px. 캡션 "65×W · extent 69 · 슬롯 rect는 diagonal_media_list_item.dart:88-149 분수값" |
| 2 | 성작·인연·배지 | (40,345) | 성작 9칸 150×12(학생 #f3c96b@.86, 무기 #71c7f4@.86, 비활성 outline@.48), 인연 하트 38×30 4단계(12/30/60/100), 배지 pill UNOWNED/PLAN/JP(#06080e@.87 + white@.16) |
| 3 | 페이즈 컨테이너·흐름 삼각형·대각 스크롤바·안개 | (36.7,508.6) 513.3×672.1 | 컨테이너 `_planPhaseTexture` + outline@.62, 카드 #35526b@.84 r8, 삼각형 16×10 #f2b3ef@.88, 트랙 3px outline@.48 / 핸들 8px #e5a0ea, 안개 36px #263d52(위·아래) |
| 4 | 재화 타일·커버리지 바·병목 하단 버튼 | (700,470) 300×107 ×3, (700,590) 400×38, (1120,580) 500×94 | 타일 #213c52@.72 r7 / 선택 #f2b3ef@.12+1.5px, 바 트랙 #4f7090@.2 / 채움 #f2b3ef |
| 5 | 탭 선반·S4 컨트롤·런처·세그먼트·스테퍼 | (700,735~915) | 탭 138.7×44 r8(선택 primaryMuted@.34 + 하단 2px primary), S4 90×56 사다리꼴(텍스처, 선택 #f2b3ef 3px + @.1), `.tonal` 200×44(pri/기본/dng), `.seg` 2개, 스테퍼 −/+ 22×24·값 GyeonggiTitle 25.2 w800, MAX 배지 |
| 6 | 시나리오 카드·학생 격자 카드 | (700,1025) 560×74 ×2, (1290~1740,1025) 140×113.33 ×4 | 시나리오 카드 #264359@.85 r8 / 선택 primary@.22+1.5px, 초상 원 38 겹침 10, 상태 pill. 학생 카드 252:204, depth min(.25w,h/tan80), r min(12,.1s), 속성 글자 칩 2개, 이름은 카드 밖 20px 줄, 흰 외곽선 1% / 선택 #ff72b6 2% |
| 7 | 텍스처·표면·모션 | (1700,40) 250×80 ×6 | 텍스처 견본 6종(앱 배경 defaultConfig / `_planPhaseTexture` / `_headerTriangleTexture` / `_planElementTexture` / `_planResourceControlTexture` / `titlePrimaryActionTexture`) + 규칙 문장(아래) |
| 8 | 배치 규칙 | (1700,560) | 96×96 Studio 좌표: S1 (0,2,37,92) trapezoid-left h48 · S2 (12,2,29,94) para-bottom · S3 (45,1,42,95) para-bottom(탭 통합) · S4 (89,14,7,80) triangle-right · S2′ (12,2,52,94) · S6 (65,2,31,94) trapezoid-right · 적용 패널 (42,2,54,94) trapezoid-right |

블록 7의 규칙 문장(원문 요약) [확인]:
- 섹션 표면: **surface@.76 (블러 없음)** + lifted shadow #050911 (2,2)@.077·(1.5)@.113·(1)@.149·(.5)@.184 · 둥근 다각형 r14
- 부착면 → 등장/퇴장: 왼쪽 0°/180° · 오른쪽 180°/0° · 아래 80°/260° · 위 260°/80° · 이동 거리 min((W+40)/|cos|, (H+40)/|sin|)
- 섹션 모션 360ms easeInOutCubic · 탭 본문 전환(AnimatedSectionStack) 970ms: pull 120ms(−5.5%) → exit 300ms easeInCubic → cruise → settle 190ms easeOutCubic · 헤더 220ms fade + slide(0.025,0) · 탭 180ms easeOutCubic
- 사선 스크롤: 행 left = inset + (viewportH − rowBottom + scroll)/tan80 · 스크롤바 P(y)=(W−10−0.1763y, y), 핸들 h=max(28, track×view/(view+max))
- 글꼴 Pretendard 400/500/600/700 · GyeonggiTitle 500(값·제목) · 크기 10/11/12/13/15/14/16/18/20/24/28/36
- 인접 간격 S1|S2 24px · S2|S6 20px · 섹션 내부 inset 10 · 리스트 inset 8 · 스크롤바 reserve 14 · 자식 ΔX = −ΔY/tan80 · 법선 간격 g → X inset g/sin80

### 1.2 사용 요소
DiagonalMediaListItem(mrow), StarBar9, BondHeart, StatusPill, PhaseContainer+PhaseCard, FlowTriangle, DiagonalScrollbar, ScrollFog, ResourceTile, CoverageBar, BottleneckActionBar, BottleneckHeader, InnerTabShelf, S4ControlButton, TonalButton, SkewSegment, Stepper, MaxBadge, ScenarioCard, StudentGridCard, 텍스처 6종.

### 1.3 상태·상호작용
정적. 상태 변형은 나란히 그려 보여 준다: mrow 기본/강조(핑크 1.8px), 타일 기본/선택, S4 기본/선택, seg on/off, 탭 선택/비선택, 시나리오 카드 "현재 데이터 기준"/"저장 시점과 다름", 학생 카드 기본/UNOWNED/PLAN.

### 1.4 현재 코드 대응 [확인]
| 블록 | Dart | 분류 | 근거 |
|---|---|---|---|
| 1 | `ui/widgets/diagonal_media_list_item.dart: DiagonalMediaListItem`, `_ItemSurfacePainter`(canvas@.58, outline@.46), `diagonalMediaHighlightColor=0xfff2b3ef`, `diagonalMediaHighlightStrokeWidth=1.8` | 그대로 재사용 | 수치 1:1 |
| 2 | `_StarIndicator/_StarIndicatorPainter`, `_BondRank`/`_HeartPainter`(#ffb9e3/#ec70bd/#27465a 15.75), `bond_rank_portrait.dart`(≥20/≥50/≥100 단계), `student_portrait_status_overlay.dart: StudentPortraitStatusOverlay`(UNOWNED), `_CatalogStatusBadge`(PLAN/JP) | 재사용 | 색·문턱값 일치 |
| 3 | `plan_section_layout.dart: PlanPhaseCard`, `_planPhaseTexture`, `diagonal_flow_indicator.dart: DiagonalFlowIndicator`(16×10, #f2b3ef@.88), `PlanDiagonalScrollbar`/`planScrollbarTrackPoint`(trackInset 10, 3px@.48, 8px #e5a0ea, max(28,…)), `scroll_viewport_fog.dart: ScrollViewportFog`(36, #263d52) | 재사용 | 수치 1:1 |
| 4 | `PlanBottleneckResourceTile`, `PlanConsumptionResourceTile`, `_PlanResourceTileFrame`, `PlanInventoryCoverageBar`, `_PlanBottleneckActionClipper/Painter`, `PlanPrimaryBottleneckSummary`/`PlanResourceHeader`(`_planResourceHeaderTexture`) | 재사용 | `0xb7213c52`(=.72) 확인 |
| 5 | `_PlanResourceTabs/_PlanResourceTab`(r8, primaryMuted@.34, 12px), `PlanResourceControls/_PlanResourceControlButton`, `_CompactTargetStepper`, `_MaxBadge`(plan_element_builder.dart), 런처=`FilledButton.tonalIcon`(theme r10) | 재사용(대부분 private → 추출 필요) | |
| 6 | `PlanScenarioListCard`(`0xd9264359`=.85), 학생 카드 = `AssetImageGrid` + `studentGridCardSelectionColor=0xffff72b6` | 재사용 / 학생 카드 속성·이름 표현은 W-Card 그룹 결정 따라 수정 | |
| 7 | `ba_triangle_background.dart: BATriangleTextureConfig.defaultConfig`, `titlePrimaryActionTexture`, `app_shell.dart: _headerTriangleTexture`, `plan_element_builder.dart: _planElementTexture`, `plan_section_layout.dart: _planResourceControlTexture/_planPhaseTexture`; 모션 `animated_section_stack.dart`(120/300/360/190ms, −5.5%) | 재사용 | 시안은 텍스처를 PNG(_blob)로 구워 사용, 코드는 `BATriangleTexturePainter` 절차 생성 |
| 8 | `section_template.dart`(96 grid, `AttachedSectionSpec`, `SectionShapeMode`, `SectionAttachmentFace`), `section_template_surface.dart: buildAttachedSectionPolygon/buildRoundedSectionPolygon` | 재사용 | |

### 1.5 데이터 요구
없음(카탈로그). 시나리오 카드의 "크레딧 75.3M · 부족 10종", "저장 시점과 다름"은 시나리오 그룹(D) 범위.

### 1.6 모호점
- 블록 7 "섹션 표면 surface@.76 블러 없음" vs 코드 `DiagonalSection`(surface@.92 + blur 8 + 1px outline), `SectionTemplateSurface`/`AttachedSectionTemplateSurface`(surface@.88, 선택 시 primaryMuted@.78, blur 8). 실제 화면 artboard 섹션은 `fill="rgba(29,42,58,0.76)"` svg path 117개로 그려져 시안 규칙과 일치. 어느 쪽을 표준으로 할지 결정 필요.
- 블록 7 "섹션 모션 360ms easeInOutCubic" vs `DirectionalSectionEntrance`는 `Curves.easeOutCubic`. 360ms·easeInOutCubic은 개별 레이아웃(`student_section_layout.dart _motionDuration`, `plan_section_layout.dart _motionDuration`, `plan_element_builder.dart _sectionMotionDuration`, `plan_phase_editor.dart phaseEditorMotionDuration`, `plan_student_selector.dart`, `plan_preset_manager.dart`)에 각각 상수로 중복.

---

## 2. W-Data-Widgets.dc.html — 위젯 · 데이터 표시 (2560×1570)

### 2.1 목적과 구성
"인벤토리 · 통계 · 계획 만들기에서 새로 만든 표시 위젯. 막대·타일·트랙은 모두 −10° 기울기, 비교가 필요한 막대는 길이를 같게 두고 행째로 사선을 따라 밉니다." 11개 견본 타일(`.tile`, 80° 평행사변형 r8, rgba(16,24,35,.6), 테두리 없음).

| 타일 | rect | 형상 |
|---|---|---|
| KPI 사선 타일 · 전후 비교 | (40,104) 1011.6×300 | 평행사변형 |
| 주요 재화 (숫자형) | (1022.7,104) 763.1×300 | 〃 |
| 아이템 타일 + 충족 막대 | (1756.9,104) 763.1×300 | 〃 |
| 비율 막대 행 (사선 정렬) | (40,428) 812.4×330 | 〃 |
| 기울어진 히스토그램 | (818.3,428) 580.4×330 | 〃 |
| 꺾은선 추이 | (1364.4,428) 638.4×330 | 〃 |
| ± 증감 막대 | (1968.6,428) 551.4×330 | 〃 |
| 히트맵 (단일 색조) | (40,782) 977.2×300 | 〃 |
| 위험도 순위 행 | (988.3,782) 1531.7×300 | 〃 |
| 부족 상위 행 (아이콘 + 학생) | (40,1106) 1421.1×430 | 〃 |
| 부족 칩 → 상위 5 팝업 | (1409.3,1106) 1110.7×430 | 〃 |

타일 공통 머리: 6×18 핑크 사선 막대 + `.dsp` 16px 제목 + 1px 그라데이션 룰(rgba(113,199,244,.65)→.06, 왼쪽 40×3 핑크 캡) + 하단 `.wsub` 설명(11.5px).

### 2.2 사용 요소 (시각 사양) [확인]
- **KpiTile**: 높이 70, 배경 skewX(−10°) r7 #203243 + inset 1px outline@.8, 라벨 `.ihdr` 9px, 값 GyeonggiTitle 26 w800, 변화 11px w700(#7fe3bd 증가, #f7c9f4 계획). 전후형: 이전값 14px #9eb0c2 → 화살표(핑크) → 예상값 24px #7fe3bd.
- **ResourceAmountRow**: 패딩 10/18, skew 배경 rgba(16,24,35,.6)+outline@.6, `.pt` 42×34 아이콘, 이름 13.5 b, 값 `.dsp` 16, "/ 필요 …" 11px muted, 부족량 12px w800 #f2b3ef, 하단 `.bar2` 6px skew.
- **ItemTile+bar**: 74×74, `.pt` 74×60, 수량 `.dsp` 13 흰색+그림자(우하), 하단 막대 64.9×4 skew(부족 #f2b3ef / 충분 #71c7f4 / 과잉 노랑 / 계획 무관 = 막대 없음), 선택 = 2px 핑크 링 + 14px 글로우.
- **RatioBarRow**: 행 높이 32, 이름 70px, 2열 트랙 12px r3 skew, 25/50/75 눈금 rgba(158,176,194,.18), 값 GyeonggiTitle 14 width 44. 행마다 padding-left가 7.1px씩 감소(28.2→0)해 **행 전체가 80° 레일로 밀림**.
- **SkewHistogram**: 열 높이 230, 막대 폭 60% r4 상단, skew −10°, 기본 #71c7f4 opacity .78 / 선택 #f2b3ef 1.0, 값 13px, 축 라벨 10px.
- **LineTrend**: svg viewBox 401×120, 축선 rgba(158,176,194,.22), 선 2.5px #71c7f4, 점 r4, 값 라벨 11px #9eb0c2, x 라벨 10px #6f8397, 바탕 rgba(16,24,35,.55) r8. 요약 문구는 소제목 줄 오른쪽(12px #f2b3ef).
- **DivergingBar(±)**: 행 26, 라벨 118px 우정렬, 트랙 220(중앙 축 1px), 막대 8px skew r2(+ #58d6a7 / − #f2b3ef), 값 12px w800.
- **SkewHeatmap**(`.hm.sk`): grid 48px + 5열, 칸 26px r4, 격자 전체 skewX(−10°) 원점 좌하단, 글자는 역스큐로 세움, 채움 rgba(113,199,244,α) α≈.31~.90, 글자색 명도 의존(#0c2233 / #f4f8fb).
- **RiskRow**: 높이 56, `.pt` 52×42, 이름 13.5 / 보조 11px(폭 210), `.bar2` 10px, 점수 14px w800 (>60 #f2b3ef, ≤60 #ffc66d). 선택 = inset 1.5px #f2b3ef + rgba(242,179,239,.1).
- **ShortageTopRow**: 높이 46, margin-left 17.6→8.8→0(레일), `.pt` 47×38, 이름 13 w600, "−36 · 학생 7명" 12px 핑크, 오른쪽 초상 34×28 ×최대5(폭 246 고정) + "…+n" skew 칩.
- **ShortageChipFlyout**: `.chip.pk` "부족 7"(inset 1.5 핑크) → `.fly` 400px(`.fr` 행: `.pt` 42×34, 이름 13 b, 부족량 `.dsp` 16 핑크, `.bar2` 5px 파랑, "보유 6 / 필요 36" 11px), "… 외 2종 · 모두 보기 →".

### 2.3 상태·상호작용
정적. 문장으로 정의된 상호작용: 히스토그램 구간 클릭 → 오른쪽 목록 교체, 위험도 행 선택, 부족 칩 hover/click → 상위 5 팝업.

### 2.4 현재 코드 대응
| 요소 | Dart | 분류 |
|---|---|---|
| KpiTile | 없음(`app_shell.dart _HeaderMetric`는 헤더 지표용) | 신규 |
| ResourceAmountRow | 없음(`PlanBottleneckCreditShortage`가 크레딧 부족 표시로 부분 유사) | 신규 |
| ItemTile+bar | 없음 | 신규 |
| RatioBarRow / SkewHistogram / LineTrend / DivergingBar / SkewHeatmap | 없음(`statistics_page.dart`는 `SegmentedButton`/`LinearProgressIndicator` 기반, skew 변환은 lib 전체 0건) | 신규 |
| RiskRow / ShortageTopRow | 사선 행 렌더는 `PlanBottleneckDiagonalList`, `DiagonalMediaListItem`이 가장 가까움 | 신규(공통 DiagonalRow 위) |
| 초상 소형 | `AssetImageGrid` | 재사용 + "…+n" 칩 신규 |
| ShortageChipFlyout | 없음 | 신규(AnchoredFlyout 위) |

### 2.5 데이터 요구
- 부족 상위·칩 팝업: `InventoryShortageRow`(`requiredAmount`, `owned`, `shortage`, `affectedStudentIds`)로 충족 [확인].
- 위험도 점수(0~100): AppService에 없음 → 산식·백엔드 필요(E 보고서와 공유).
- 꺾은선(스캔 4회)·±증감: 인벤토리 스냅샷 이력 API 없음(`AppService`는 `listInventoryItems`/`calculateShortages`뿐) → 백엔드 추가 필요.
- 히트맵(설계도 종류×티어 충족률), KPI 전후값: 집계 API 없음.

### 2.6 모호점
- 과잉 색 "노랑"의 정확한 값(타일 견본 #ffc66d 계열로 추정).
- `.tile` 클래스가 UI-Elements(재화 타일 300×107)와 W-*(위젯 카드)에서 다른 의미로 쓰임 → Flutter 이름 분리 필요.

---

## 3. W-Layout-Widgets.dc.html — 위젯 · 구조와 상호작용 (2560×1448)

### 3.1 구성
| 타일 | rect |
|---|---|
| 제목 3단계 | (40,104) 678.3×250 |
| 칩 · 세그먼트 · 버튼 | (698.2,104) 678.3×250 |
| 단계 태그 | (1356.4,104) 563×250 |
| 변경 강조 + 조절 | (1899.4,104) 620.6×250 |
| S3 인디케이터 박스 | (40,378) 727.5×450 |
| 사다리꼴 안 스크롤 | (712.2,378) 1807.8×450 |
| 팝오버 (열린 상태) — 프레임 없음 | 플라이아웃 트리거 (60,888) 380×46 · 페이즈 팝오버 트리거 (1000,888) 530×56 · (i) (2040,896) |

### 3.2 사용 요소 [확인]
- **제목 3단계**: PanelTitle(7×22 핑크 skew 막대 + `.dsp` 19 + 우측 `.chip.gy` + 룰 캡 46px) / TileTitle(6×18 + `.dsp` 16 + 룰 캡 40px) / SubHeader `.ihdr`(GyeonggiTitle 8~10px w800, 5×5 #71c7f4 점).
- **칩 6색** `.chip`(h24 r7 12px w700): 정보(#71c7f4@.16/#a8e0ff) 강조 pk(#f2b3ef@.2/#f7c9f4) 충분 ok(#58d6a7@.16/#7fe3bd) 주의 wn(#ffc66d@.16/#ffd08a) 위험 dg(#ff7e8a@.16/#ffa0a8) 보조 gy(#9eb0c2@.14/#c3cfdb). "칩 6색 역할 고정".
- **SkewSegment** `.seg`: h36(견본 28) padding 16, r5, skewX(−10°), 배경 rgba(16,24,35,.9) + 1px rgba(158,176,194,.35) 테두리, 13px w600 #c3cfdb, 라벨은 `.su`로 역스큐. on = #3a2a44 + 1.5px #f2b3ef 테두리 + #f7c9f4.
- **TonalButton** `.tonal`(r10 13px w600 #3a4b58/#d6e4f0, pri #f2b3ef/#2a1330, dng, ghost, done, cur).
- **StageTag**: h24 r5 skew, 1단계 #71c7f4 / 2단계 #f2b3ef / 3단계 #ffc66d — 외곽 @.16 채움 + @.55 inset, 선택(지금 보는 단계) = 원색 채움 + 글자 #1a1f2a, 12px w800.
- **ChangedValue**: 값 GyeonggiTitle 22 w800, 바뀐 값만 skew 박스(#f2b3ef@.13 + inset 1px @.5), 무관 값은 흐림, 옆에 `.nd` 18×13 ▲▼ 버튼(Flow-2-Goals 전용 CSS).
- **IndicatorBox**: 360×80 평행사변형 r8, fill #203243, stroke outline@.75 1.8, `.ihdr` "LEVEL" + 1px rgba(113,199,244,.42) 룰 + 값 GyeonggiTitle 30 w800 + "→ 90" 12px.
- **DiagonalRailList (rs-* 모드)**: 패널 560×320 사다리꼴 #141e2b, 뷰포트 541.5×292 내부 12개 행(`rsr-wdemo` 52px, gap 6, `.rb` skew 배경 rgba(14,21,31,.45) / hover rgba(36,52,72,.8) / on = 핑크 그라데이션 + inset 3px #f2b3ef 왼쪽 막대). **행 폭이 `animation-timeline: view()`로 472→532.7px 변함**(왼쪽 고정, 오른쪽 끝이 80° 레일 추종). 포그 44px #141e2b(스크롤 0~60px에서 페이드 인, 끝 60px에서 페이드 아웃). 스크롤바 트랙 3px outline@.48 (532.8,10)→(484.8,282), 썸 8px #e5a0ea가 레일을 따라 이동. "구현은 CSS 스크롤 연동 애니메이션(view() · scroll-timeline)만 씁니다."
- **AnchoredFlyout** `.flyw/.fly`: 트리거 위 1.5px 핑크 링, 패널 420px(견본) #0d151f r10, ring 1px rgba(113,199,244,.38) + 그림자 0 12px 30px rgba(0,0,0,.6), 꼬리 11px 회전 사각형. 내용: 제목 14 b + 정렬 seg(부족량/단계별) + `.fr` 행(아이콘 47×38, `.bar2` 5px, 초상 22×18 + StageTag) + 하단 안내 11px + `.tonal` 28px "인벤토리에서 보기".
- **PhasePopover** `.phw/.php`: 트리거가 사선 행(530×56, clip polygon) 전체, hover 시 `.pho` 2px 핑크 외곽선 path, 패널 470px 아래로 열림, `.pr` 행 + `.chip dg/wn/ok`.
- **InfoPopover**(i): §5 참조.

### 3.3 상태·상호작용
팝오버는 "열린 상태로 그렸습니다(실제로는 hover · focus · click)". 사다리꼴 스크롤은 실제로 스크롤 가능(CSS scroll-timeline).

### 3.4 현재 코드 대응
| 요소 | Dart | 분류 |
|---|---|---|
| PanelTitle/TileTitle/SubHeader | 없음(제목은 각 레이아웃이 Text로 직접) | 신규 |
| `.chip` 6색 | 없음(Material `Chip`이 settings/scan/statistics/inventory 페이지 등 11파일 33회) | 신규 + 교체 |
| `.seg` | 없음. Material `SegmentedButton`이 `inventory_page.dart:417`, `tactical_page.dart:581`, `scan_page.dart:1023`, `statistics_page.dart:275`에 사용 | 신규 + 교체 |
| `.tonal` | `FilledButton.tonalIcon` + `filledButtonTheme`(r10, 13px w600) | 토큰만 다름(pri 핑크 변형 없음, 배경색은 ColorScheme 유래) |
| StageTag | 없음 | 신규 |
| ChangedValue | `DiagonalMediaListItem` 강조(핑크 1.8px)와 개념 유사 | 신규(값 박스) |
| `.nd` | 없음 | 신규 |
| IndicatorBox | 학생 상세 인디케이터(`student_section_layout.dart`의 #203243 / `0xc735526b` 페인터) | 재사용(추출) |
| DiagonalRailList | 행 오프셋 함수가 파일마다 중복: `account_section_cluster.dart: portraitGridTrajectoryOffset`, `plan_section_layout.dart: planPhaseRowHorizontalOffset/planPhaseRowWidth`, `student_section_layout.dart: studentDiagonalRowHorizontalOffset`; 스크롤바 `PlanDiagonalScrollbar` + private 4종(`_StudentDiagonalScrollbar`, `account_section_cluster.dart _DiagonalScrollbar`, `_PlanPresetDiagonalScrollbarPainter`, `_PhaseEditorDiagonalScrollbarPainter`) | 수정(공용화) |
| Flyout/PhasePopover | 없음(`OverlayPortal`/`MenuAnchor` 0건, `Tooltip`만 8파일) | 신규 |

### 3.5 데이터 요구
부족 재화 플라이아웃의 "재화 → 들어가는 단계(1/2/3단계) · 사용 학생" 매핑은 계획 계산 결과(`calculatePlan`)의 단계별 분해가 필요 — 현행 반환 형태에 단계별 필요량이 있는지 Flow 그룹 확인 필요.

### 3.6 모호점
- 사선 목록 구현 방식이 시안에 2가지: (a) **resize 모드**(rs-*: 왼쪽 고정, 행 폭이 레일 추종 — 사다리꼴 좌부착 패널), (b) **translate 모드**(통계 sv-*: 콘텐츠 열 전체가 scroll/tan80 만큼 translateX — 평행사변형). `responsive-diagonal-layout-policy.md §9.1`은 "가시 행의 Y에 대응하는 X를 이동"(translate)만 명시. 두 모드 모두 공용 위젯 옵션으로 둘지 확인.
- `.nd` CSS가 Flow-2-Goals 블록에만 있고 W-Layout은 정의 없이 사용(렌더링 차이 가능).

---

## 4. W-Filter-Widgets.dc.html — 위젯 · 필터 (2560×652)

### 4.1 구성
"학생 탭 · 계획 만들기 1의 필터 팝업 조각. 속성은 토글 칩, 성장 값은 최소~최대 한 줄 슬라이더(v7 이상/이하 두 패널을 합침)."

| 타일 | rect |
|---|---|
| 토글 칩 | (40,104) 840.1×250 |
| 타입 칩 | (860,104) 972.7×250 |
| 적용 중 필터 | (1812.6,104) 707.4×250 |
| 범위 슬라이더 | (40,378) 980.5×250 |
| 성급 범위 | (1000.4,378) 980.5×250 |
| 필터 버튼 | (1960.9,378) 559.1×250 |

### 4.2 사용 요소 [확인]
- **SkewToggleChip**: `<button aria-pressed>` h30 padding 13, skew 배경 r5 — off rgba(255,255,255,.05)+inset 1px outline@.9, 12.5px w500 #dfe7ee / on rgba(242,179,239,.2)+inset 1.5px #f2b3ef, w700 #f7c9f4. 오른쪽 개수 10.5px muted. 규칙 "같은 줄 = 또는, 줄끼리 = 그리고".
- **TypeChip**: SkewToggleChip + 앞 막대 8×14 skew(폭발/경장갑 #920008, 관통/중장갑 #bd8901, 신비/특수장갑 #226f9b, 진동/탄력장갑 #9945a8, 복합장갑 #7a8ea3). "색만으로 구분하지 않게 이름을 항상 씀".
- **ActiveFilterChip**: `.chip.pk` + × 아이콘 11px, 결과 수 `.dsp` 22 + "/ 170명".
- **RangeSliderRow**: 행 h44 r6, 라벨 118px(13 b + 10.5 보조), 트랙 6px r3 skew + 25/50/75 눈금, 핸들 12×16 r3 skew(+2px #0d151f 링), 값 GyeonggiTitle 15 w800 "70 ~ 90". 기본값(전체) 아님 → 행 전체 rgba(242,179,239,.1) + inset 1.5px #f2b3ef, 채움·핸들 핑크. 기본 = 채움 #5d7288, 핸들 #c3cfdb.
- **StarRangeBar**: 9칸 h14 skew r3, 학생★ 5칸 #e8c15a + 무기★ 4칸 #71c7f4, 고른 구간만 1.5px 핑크 링, 나머지 rgba(255,255,255,.06).
- **FilterButton**: h30 skew, "필터" / 적용 중 "필터 · 3"(핑크). 모달 하단 `.chip` 아이콘 버튼 "프리셋/초기화/적용(pk)".

### 4.3 상태
off/on/개수, 기본/강조, 적용 없음/적용 중을 나란히 표시. 정적.

### 4.4 현재 코드 대응
| 요소 | Dart | 분류 |
|---|---|---|
| SkewToggleChip | 학생 필터는 `student_section_layout.dart: StudentDiagonalFilterList/_StudentFilterGroupCard`(사선 그룹 카드) — 칩 단위 skew 위젯은 없음 | 신규 |
| TypeChip 색 | `student_section_layout.dart`에 #920008/#bd8901/#226f9b/#9945a8 상수 존재, #7a8ea3 없음 | 토큰 추출 + 1색 추가 |
| RangeSliderRow | `student_range_condition_section.dart: StudentRangeConditionSection`(v7 이상/이하 2패널) — `RangeSlider` 0건 | 신규, 기존 폐기 대상(시안 문구 "v7 이상/이하 두 패널을 합침") |
| StarRangeBar | 표시용 `_StarIndicator`(9칸) 재사용 가능, 입력은 신규 | 수정 |
| FilterButton / ActiveFilterChip | 없음 | 신규 |

### 4.5 데이터 요구
토글 칩의 학생 수(미리보기 개수)는 `listStudents()` 결과로 클라이언트 계산 가능(추정). "계획에 없는 학생만"은 계획 문서 참조 필요.

### 4.6 모호점
- 별 노랑이 `#e8c15a`(필터) vs `#f3c96b`(성작 표시, 코드 `diagonal_media_list_item.dart`/`student_section_layout.dart`). 통일 여부.

---

## 5. W-Info-Popover.dc.html — 도움말 (i) · 팝오버 (1160×400)

### 5.1 구성
"사용법·설명 문장은 화면에 늘 띄우지 않고 제목 옆 (i) 뒤에 둡니다. 마우스를 올리거나, 키보드로 포커스하거나, 누르면 열립니다. 상태·수치·선택지 설명은 그대로 보여 줍니다." 3열: 닫힘 (40,136) / 열림·왼쪽 정렬 (300,136) / 열림·오른쪽 정렬(화면 오른쪽 끝) (820,136).

### 5.2 요소 사양 [확인]
- 버튼 `.ib` 24px 원, 기본 rgba(113,199,244,.12) / 아이콘 #9eb0c2, hover·focus·open rgba(242,179,239,.24) / #f2b3ef. 아이콘 15px(원 r9 + i).
- 팝오버 `.pop`: top 34px, z 60, 폭 330(견본 300), padding 13/15/14, r9, #0d151f, ring 1px rgba(113,199,244,.38) + 0 10px 28px rgba(0,0,0,.55), 12.5px/1.6 #c3cfdb. 제목 `b` 13.5 w700 #f4f8fb + 앞 4×13 핑크 skew 막대. 강조어 `i` #f7c9f4 w700. `ul` 지원. 꼬리 11px 회전 사각형. `.pop.l`(left −7, 꼬리 left 14) / `.pop.r`(right −7) — "섹션 안에서 잘리지 않게 왼쪽/오른쪽 정렬을 고릅니다".
- 접근성: `<button class="ib" aria-label="… 도움말">`, 팝오버 `role="tooltip"`.

### 5.3 사용 빈도
`.info` 40회 / 25개 artboard(Flow 8종, Stats 5종, Inventory·Inventory-All, Scenario-List, Tactical·Slots·Import-Excel, Home-Connected-Scan, Title-Accounts-New/Portrait 등) [확인].

### 5.4 현재 코드 대응
없음. `Tooltip`(theme `tooltipTheme`: surfaceRaised r8 outline) 8파일 17회, `Icons.info_outline_rounded`는 `plan_element_builder.dart:1397` 1곳. → **신규 `InfoPopover`**(hover/focus/tap, 좌/우 정렬, 풍부한 내용). Material `Tooltip`은 탭으로 고정 열기·리치 내용·좌우 정렬 선택 요구를 충족하지 못함(추정).

### 5.5 모호점
화면에 이미 있던 설명 문장을 (i) 뒤로 옮기는 정책 → 기존 화면의 상시 안내문(예: Studio 계열 문서의 안내 문구) 제거 범위 확인 필요.

---

## 6. (a) 시안 요소 카탈로그

빈도 = (본문 등장 횟수 / artboard 수). 상태: **재사용**(그대로) / **토큰만 다름** / **수정**(구조 있음, 추출·옵션 추가) / **신규**.

### 6.1 셸·표면·기하

| 요소 | 시각 사양 (CSS) | 등장 | 대응 Flutter | 상태 |
|---|---|---|---|---|
| 앱 배경 | #101722 + 삼각 텍스처 PNG(`5bb2acb1`) cover | 53 artboard 전부 | `ba_triangle_background.dart: BATriangleBackground`, `BATriangleTextureConfig.defaultConfig`; `AppColors.canvas` | 재사용 |
| L-glass 헤더 선반 | path `M32 14 L764 14 … L778 62 L2528 62 …` (padding 18/14, 선반 폭 760, 높이 170, shelf 48), blur 10, gradient surface@.46→surfaceRaised@.28, lifted shadow 2층 | 36 | `app_shell.dart: _CompoundPageHeader`, `_LGlassClipper`, `_LGlassShadowPainter`, `_buildLGlassPath`(min(760,…)) | 재사용. 단 택틱 3화면은 선반 860·탭 9개 → `AppSection` 추가·선반 폭 규칙 수정 |
| 주 탭 `.nt` | min-w 76, h44, padding 12, 13px w500 #9eb0c2, r8 8 0 0, on: rgba(37,88,123,.34) + 하단 2px #71c7f4 + w700 #f4f8fb, 아이콘 17 | 291 / 36 | `_TopTabs/_TopTab`(`_topTabMinWidth=76`, gap 2, 180ms easeOutCubic) | 재사용(아이콘은 Material vs 시안 stroke svg — 토큰만 다름) |
| 페이지 헤더 | (23,67) 2511×109, 우측 80° 컷 r14, 텍스처 `e1340e8f`, blur 12, 제목 20px w700 + 부제 12px w400 muted | 36 | `diagonal_header.dart: DiagonalHeaderSurface`(radius 14, angle 80), `_headerTriangleTexture`, `_AppHeader`(AppType.headline / bodySmall) | 재사용 |
| 연결 배지 `.conn` | pill 999, padding 6/10, rgba(88,214,167,.12)+inset 1px @.55, 12px w600, 점 8px | 38 / 36 | `_ConnectionBadge` | 토큰만 다름: 시안 "연결 안 됨"=회색(rgba(158,176,194,.12)/#c3cfdb, Home 2화면), 코드=danger 빨강. 게임 창 연결 변형 "연결됨 · Blue Archive · 2560×1440"은 신규 개념 |
| 개발 버튼 `.devbtn` | 40×40 r20 rgba(37,88,123,.7), 아이콘 #cfe9f8 | 36 | `_AppHeader`의 `IconButton.filledTonal(Icons.developer_board_outlined)` → `DevelopmentPanel` | 재사용 |
| dev bar `.devbar/.devcap/.dv/.devsep` | 정의만: (800,10) 패널 rgba(0,0,0,.35) + 핑크 inset | **0** (CSS 정의만, 본문 미사용) | — | 구현 불필요(확인 필요) |
| 섹션 표면 | svg path fill rgba(29,42,58,.76), 블러 없음, 둥근 다각형 r14(Q 곡선), lifted shadow 4층 .077/.113/.149/.184 + 래퍼 `.sw` CSS drop-shadow | path 117개 / `.sw` 111 / 34 | `section_template_surface.dart: buildAttachedSectionPolygon, buildRoundedSectionPolygon, SectionTemplateSurface, AttachedSectionTemplateSurface`; `diagonal_section.dart: DiagonalSection`; `lifted_path_shadow.dart: paintLiftedPathShadow/defaultLiftedSectionShadow`(4층 수식이 시안 알파와 정확히 일치) | 토큰만 다름(fill 알파·blur·테두리) |
| 80° 기하 | cutDepth = h/tan80 ≈ 0.1763h, 자식 ΔX=−ΔY/tan80 | 전 화면(skewX(−10deg) 47 artboard) | 공용 상수 없음: `tan(80 * math.pi / 180)` lib 전체 108회 인라인, `sectionTemplateCutDepth`, `diagonalSlant`, `DiagonalSectionClipper.edgeAngleDegrees` 산재 | 수정(DiagonalGeometry 공용화) |
| 둥근 다각형 | 대부분 Q(2차 곡선) 코너. 반경 빈도: 8(1026) 12(401) 14(184) 10(148) 6 9 | 전 화면 | 3종 공존: `buildRoundedSectionPolygon`(원호 필렛), `diagonal_menu.dart: roundedPolygonPath`(Q), `diagonal_header.dart: buildRightCutRoundedPath`(Q) | 수정(한 함수로) |
| 섹션 모션 | 부착면 intro/outro, 360ms | 화면 전환(정적 시안은 Home-Connect-Effect만 keyframes) | `animated_section_stack.dart: SectionMotionSpec, DirectionalSectionEntrance, sectionMotionOffset(gap 40), AnimatedSectionStack` | 재사용 |
| 모달 스크림 | rgba(6,10,16,.8)+blur2 (필터 팝업 3) / .72 (Home-Connected-Scan, Title-Accounts-New) / .62 (Import-Excel) / .35 (Analysis-All, Title-Accounts*) | 9 | `showDialog`(8파일) | 신규 공통 BaModal |
| 팝업 패널 | #0d151f r10~12, ring 1px #71c7f4@.38, 0 12~18px 30~40px rgba(0,0,0,.6~.65) | `.fly/.php/.shp/.spop/.pop` + Analysis-All | 없음 | 신규 |

### 6.2 행·목록·스크롤

| 요소 | 시각 사양 | 등장 | 대응 Flutter | 상태 |
|---|---|---|---|---|
| 사선 행 `.srow` (+svg `.bd` border) | 80° 평행사변형 r8, rgba(16,24,35,.72), 테두리 path 2px rgba(113,199,244,.16); hover rgba(30,45,62,.9); `.sel` rgba(52,36,58,.85) + 4px #f2b3ef; `.blue` 4px @.65 | 224 / 17 (Scenario-Compare 94) | 부분: `DiagonalMediaListItem._ItemSurfacePainter`, `PlanPhaseCard`, `PlanBottleneckDiagonalList` 각자 구현 | 신규 공통 `DiagonalRow`(상태 default/selected/blue/hover) |
| 일반 행 `.row` / `.plain` / `.tile` | `.row` = srow와 같은 배경·테두리, `.plain` 투명 무테, `.tile` rgba(16,24,35,.6) 무테 | 173/26 · 112/27 · 81/13 | 위와 동일 | 신규(DiagonalRow 변형) |
| `.dash` 점선 행 | rgba(16,24,35,.35) + 3px dasharray 7 5 | **0** | — | 불필요 |
| 사선 스크롤바 | 트랙 3px rgba(56,81,107,.48) round cap, 썸 8px #e5a0ea, trackInset 10, h=max(28,…), 레일 P(y)=(W−10−0.1763y, y) | 썸 28 artboard / 트랙 25 | `plan_section_layout.dart: PlanDiagonalScrollbar`, `planScrollbarTrackPoint`(public, 수치 일치) + private 중복 4종 | 재사용(공용 파일로 이동) |
| 스크롤 포그 A(정적) | 36px #263d52 → 투명 | 20 artboard(대부분 하단만 = 스크롤 0 상태) | `scroll_viewport_fog.dart: ScrollViewportFog`(`scrollViewportFogExtent=36`, color 파라미터), `scrollViewportFogVisibility` | 재사용 |
| 스크롤 포그 B(패널색) | 44px 패널색(#141e2b, #1b2735), 시작 0~60px 페이드 인 / 끝 60px 페이드 아웃 | rs-* 3 (Tactical, Import-Excel, W-Layout) | 같은 위젯, extent 상수 고정 | 수정(extent·페이드 거리 파라미터) |
| 스크롤 포그 C(통계) | 56px rgba(25,36,50,.96), 80px 범위 | sv-* 5 (Stats-*) | 〃 | 수정 |
| 사선 레일 목록 resize 모드 (`rsr-*`) | 행 폭이 레일 위치 따라 변함, 선택 = 핑크 그라데이션 + inset 3px 왼쪽 막대 | 3 | `planPhaseRowWidth`, `studentDiagonalRowHorizontalOffset`, `portraitGridTrajectoryOffset` | 수정(공용화) |
| 사선 세로 스크롤 translate 모드 (`svc-*`) | 콘텐츠 열 전체 translateX = scroll/tan80, 썸 레일 추종 | 5 | `planPhaseRowHorizontalOffset`(행별 오프셋)과 동일 원리 | 수정(공용화) |
| Diagonal Media List Item `.mrow` | 65×W, extent 69, 9칸 성작·하트·장비 3·T2·Lv | UI-Elements 6 (실화면은 계획 단계 행) | `DiagonalMediaListItem` | 재사용 |
| 페이즈 카드 + 흐름 삼각형 | #35526b@.84 r8, 16×10 #f2b3ef@.88 | UI-Elements | `PlanPhaseCard`, `DiagonalFlowIndicator` | 재사용 |
| 시나리오 카드 `.scard` | 560×74 #264359@.85 r8, 선택 primary@.22+1.5 | UI-Elements 2 | `PlanScenarioListCard` | 재사용 |
| 학생 격자 카드 `.stucard` | 252:204, r min(12,.1s), 선택 #ff72b6 2%, 속성 글자 칩 2개, 이름 카드 밖 | 495 / 17 | `AssetImageGrid` + `student_section_layout.dart`(`studentGridCardSelectionColor`) | 수정(W-Card 그룹) |

### 6.3 버튼·입력

| 요소 | 시각 사양 | 등장 | 대응 Flutter | 상태 |
|---|---|---|---|---|
| 레일 버튼 `.btn` | 우측 80° 컷 r8 사다리꼴, 레일 따라 폭 감소(예: 347→299). 기본 #2a3d54(hover #33496a), `.ghost` rgba(14,21,31,.45), `.pri` #f2b3ef/#2a1330, `.sel-pink` 그라데이션 #6b3e6c→#4a3552 + inset 3px 핑크, `.sel-blue` #25587b→#2a4a66 + inset 3px 파랑, `.done` 파랑@.12, `.tri` #c79ac9 | 231 / 25 (ghost 177, sel-pink 20, pri 16, done 8, tri 4, sel-blue 3; dng·icon 0) | 없음(`diagonal_menu.dart: DiagonalMenuButton`은 홈 메뉴용 surface 버튼) | 신규 `RailButton` + 그룹 레이아웃 |
| tonal 버튼 `.tonal` | r10, padding 0 16, 13px w600, #3a4b58/#d6e4f0(hover #455866), pri 핑크, dng, ghost(Tactic-Full) | 97 / 28 | `FilledButton.tonalIcon` + theme(r10, 13px w600) | 토큰만 다름(핑크 pri 변형 신규) |
| 이미지(텍스처) 버튼 | 배경 PNG cover + 80° clip + 외곽 path stroke: 시작 `49ed128a`(titlePrimaryActionTexture, 380×116, 핑크 .9 1.8px), 설정/나가기·S4 `2bcbd28c`(_planResourceControlTexture, 선택 3px 핑크 + @.1), 홈 스캔 `66a41be3`(_planElementTexture) | 49ed: 5 (Title*) · 2bcb: 5 (Title*, UI-Elements) · 66a4: 2 (Home-Connected-Scan 9개) | `BATriangleTexturePainter` + `titlePrimaryActionTexture` / `_planResourceControlTexture`(softTitlePink 팔레트) / `_planElementTexture`, Title `_actionTexture`, 계정 `_accountActionTexture` | 재사용(시안 PNG ↔ 코드 절차 텍스처; 동일 팔레트 확인) |
| 사선 세그먼트 `.seg/.su` | h36 padding 16 r5 skewX(−10°), 배경 rgba(16,24,35,.9) + 1px rgba(158,176,194,.35), 13px w600 #c3cfdb; on #3a2a44 + 1.5px #f2b3ef + #f7c9f4 | 169 / 31 (on 63) | 없음. Material `SegmentedButton` 4페이지 | 신규 `SkewSegmented` + 교체 |
| 토글 칩 (aria-pressed) | h30 skew r5, off rgba(255,255,255,.05)+1px outline@.9, on 핑크 .2 + 1.5px, 개수 10.5px | 139 / 4 (필터 팝업 3 + W-Filter) | 없음 | 신규 `SkewToggleChip` |
| 타입 칩 | 토글 칩 + 8×14 색 막대 | 필터 팝업 | 색 상수 `student_section_layout.dart` | 신규(색 토큰 추출) |
| 범위 슬라이더 | 트랙 6px skew, 핸들 12×16 skew, 강조 행 | 4 (핸들 22개씩) | 없음(`RangeSlider` 0) | 신규 |
| 성급 범위 9칸 | h14 skew, #e8c15a×5 + #71c7f4×4, 선택 1.5 핑크 링 | 필터 팝업 | `_StarIndicator` 시각 일부 | 수정 |
| 필터 버튼 | h30 skew, "필터 · n" 핑크 | 필터 화면 | 없음 | 신규 |
| 토글 스위치 `.tog` | 40×22 r11, off rgba(158,176,194,.25) 손잡이 #c3cfdb, on #f2b3ef 손잡이 #2a1330 | 6 / 3 (Flow-4-Save, Scenario-Compare, Tactic-Full) | Material `Switch`(settings_page 1파일), `_StudentGridDisplayToggle`는 Checkbox | 신규 소형 `BaSwitch` |
| 스테퍼 `.stp` | 22×24 r14 16.5px w800, 값 GyeonggiTitle 25.2 w800 | 17 / 8 | `plan_element_builder.dart: _CompactTargetStepper`, `_MaxBadge` | 재사용(추출) |
| 미세 조절 `.nd` | 18×13 r3 rgba(113,199,244,.1) / hover 핑크 .25 | 62 / 2 (Flow-2-Goals 60) | 없음 | 신규 |
| `.mini` / `.val` / `.link` | mini 30h r8, val 12px 칩, link 13px #a8e0ff | mini·val: Tactical-Timeline 전용, link 2 | 없음 | 범위 밖(이전 초안) / link 신규 소형 |
| `.viewsel(.pink)`, `.chk`, `.card`, `.scard2`, `.tab(.on)`, `.btn.icon/.btn.dng`, `.tonal.cur/.done`, `.chip.solid`, `.ord`, `.stars`, `.ind`, `.ilab`, `.slot`, `.lane` | CSS 정의만 | **0** | — | 구현 불필요(확인 필요) |

### 6.4 칩·태그·텍스트

| 요소 | 시각 사양 | 등장 | 대응 Flutter | 상태 |
|---|---|---|---|---|
| 칩 `.chip` 6색 | h24 padding 0 10 r7 12px w700; 정보/pk/ok/wn/dg/gy 배경 @.14~.2 + 밝은 글자 | 591 / 39 (pk 139, gy 161, ok 110, wn 77, dg 33) | 없음(Material `Chip` 혼용) | 신규 `BaChip(tone)` |
| 제거 칩 | `.chip.pk` + × 11px | 5 | 없음 | 신규(BaChip 옵션) |
| 단계 태그 | h24 r5 skew, 1 파랑/2 핑크/3 노랑, 선택=원색 채움 | 9 (Flow-3-Order-Many 37) | 없음 | 신규 `StageTag` |
| 상태 pill | UNOWNED/PLAN/JP #06080e@.87 | 학생 카드·mrow | `StudentPortraitStatusOverlay`, `_CatalogStatusBadge`, `paintStudentPortraitStatusBadge` | 재사용 |
| 패널 제목 | 7×22 핑크 skew 막대 + `.dsp` 19 + 룰(캡 46) | 7 (Inventory·Scenario 계열) | 없음 | 신규 `PanelTitle` |
| 타일 제목 | 6×18 + `.dsp` 16 + 그라데이션 룰(캡 40) | 9 (Stats 계열 8, W-*) | 없음 | 신규 `TileTitle` |
| 소제목 `.ihdr` | GyeonggiTitle 8~10px w800 + 5×5 #71c7f4 점 | 174 / 22 | 학생 인디케이터 라벨이 유사(추정) | 신규 `SubHeader` |
| 키-값 `.kv` | column gap 3, cap 11px | 72 / 12 | 없음 | 신규 소형 |
| 텍스트 역할 `.dsp/.mut/.cap` | dsp=GyeonggiTitle 500 −.01em, mut=#9eb0c2, cap=12px w600 muted | 792/45 · 1013/41 · 349/32 | `AppFonts.display`, `AppColors.textMuted`, `AppType.bodySmall`/`labelMedium` | 토큰만 다름(§7.2) |

### 6.5 오버레이

| 요소 | 시각 사양 | 등장 | 대응 Flutter | 상태 |
|---|---|---|---|---|
| (i) 도움말 `.info/.ib/.pop` | §5 | 40 / 25 | 없음(`Tooltip`만) | 신규 `InfoPopover` |
| 플라이아웃 `.flyw/.flyt/.fly/.fr` | 트리거 1.5 핑크 링, 패널 #0d151f r10 폭 380~540, 꼬리, 변형 `.fly.dn`(아래, Inventory-Analysis), `.fly.dl`(왼쪽 아래, Tactical), `.flyw.lc`(사선 path 트리거) | 31 / 14 (Inventory-All 9) | 없음 | 신규 `AnchoredFlyout` |
| 페이즈 팝오버 `.phw/.php/.pr` | 사선 행 전체 트리거 + hover path 외곽, 패널 470 아래 | 4 / 2 | 없음 | 신규(AnchoredFlyout 변형) |
| 시나리오 팝오버 `.shw/.shp/.sr_` | 패널 500, 꼬리 left 90 | 5 / 5 | 없음 | 신규(〃) |
| 통계 점 팝오버 `.sdot/.spop` | 26px 원 히트, 패널 왼쪽 | 28 / 2 | 없음 | 신규(〃) |

### 6.6 데이터 표시

| 요소 | 시각 사양 | 등장 | 대응 Flutter | 상태 |
|---|---|---|---|---|
| 진행 막대 `.bar2` | h8 r4 rgba(255,255,255,.09), 채움 #71c7f4(가변), 옵션 skewX(−10°), 높이 4~12 | 179 / 18 | `PlanInventoryCoverageBar`(#4f7090@.2 트랙) / 페이지는 `LinearProgressIndicator`(5파일) | 신규 `SkewBar`(PlanInventoryCoverageBar 흡수) |
| 아이템 아이콘 `.pt` | 배경 rarity PNG(`6aa789`/`869728`/`362f0a`) 100%×100% + 아이콘 92% contain margin 4% | 464 / 22 | 아이콘·배경 asset 상수가 각 위젯에 흩어짐(`planDefaultItemBackgroundAsset`, `square_yellow/purple.png`) | 신규 `ItemIconTile` |
| 초상 소형 + …+n | 34×28(square + 초상 98%), 고정 폭 슬롯, skew "…+n" | 4 | `AssetImageGrid` | 재사용 + 칩 신규 |
| KPI 타일 | §2.2 | 2 (Statistics-Proposal 6, W-Data 6) | 없음 | 신규 |
| 숫자형 재화 행 | §2.2 | W-Data, Inventory | 없음 | 신규 |
| 아이템 타일 + 충족 막대 | §2.2 | Inventory-All 등 | 없음 | 신규 |
| 비율 막대 행 | §2.2 | Stats | 없음 | 신규 |
| 히스토그램 | §2.2 | W-Data(실화면 Stats-Growth A1) | 없음 | 신규 |
| 꺾은선 | polyline 2.5px, 점 r4(#16202c 외곽 2px 변형) | 11 artboard | 없음 | 신규 |
| ± 증감 막대 | §2.2 | W-Data(Inventory-Analysis) | 없음 | 신규 |
| 히트맵 `.hm.sk` | §2.2 | 5 / 3 (Inventory-Analysis, Inventory-Tiers 3, W-Data) ※ Home의 `hm-*`는 이펙트 keyframes로 무관 | 없음 | 신규 |
| 위험도 행 / 부족 상위 행 | §2.2 | Inventory 계열 | 없음 | 신규(DiagonalRow 위) |
| 성작 9칸 / 인연 하트 | §1.1 블록 2 | 학생·계획 | `_StarIndicator`, `_BondRank`, `BondRankPortrait` | 재사용 |
| 인디케이터 박스 `.ind` | #203243 + outline@.75 | W-Layout (CSS `.ind` 본문 0, 인라인) | 학생 상세 인디케이터 | 재사용 |

### 6.7 다른 그룹 보고서 임시 이름 ↔ 본 사전 이름
`ShortagePopover`(D)·`HoverFlyout`(E) → **AnchoredFlyout**, `SlantRow`·`RiskRow`(E) → **DiagonalRow**(+RiskRow 프리셋), `SectionTitleRow` → **PanelTitle/TileTitle**, `ItemTile` → **ItemIconTile**, `TierHeatmap` → **SkewHeatmap**, `SkewedBar` → **SkewBar**, `ToggleSwitch`·`.tog`(D) → **BaSwitch**, `StatChartFrame` → **WidgetTile**(W-* `.tile`), `DeltaChip/ActiveDeltaKpiRow` → **KpiTile**.

---

## 7. (b) 디자인 토큰 비교

### 7.1 색

| 시안 값 | 시안 용도 (빈도: hex / rgba) | theme.dart | 판정 |
|---|---|---|---|
| #101722 | artboard 배경 | `AppColors.canvas` | 일치 |
| #0b111a | `body` 배경(artboard 밖), radialGradient stop | 없음 | 무시 가능 |
| #1d2a3a | 섹션 fill @.76, glass @.80, 헤더 @.46 (rgba 224) | `AppColors.surface` | 값 일치, 알파 다름(코드 .88/.92) |
| #243448 | 헤더 gradient @.28 (rgba 141) | `AppColors.surfaceRaised` | 일치 |
| #38516b | 테두리 @.46~.9 (rgba 837) | `AppColors.outline` | 일치(알파 다양) |
| #71c7f4 | 강조 파랑 (730 / 1257) | `AppColors.primary` | 일치 |
| #25587b | 탭 선택 @.34, devbtn @.7, sel-blue | `AppColors.primaryMuted` | 일치 |
| #f4f8fb / #9eb0c2 | 본문 / 보조 | `text` / `textMuted` | 일치 |
| #58d6a7 / #ffc66d / #ff7e8a | 성공/주의/위험 | `success`/`warning`/`danger` | 일치 |
| #172230 | — | `AppColors.navigation`(`_TopTabEdgeFade`) | **시안 미사용** |
| **#f2b3ef** | 핑크 강조: 선택·세그먼트 on·제목 막대·부족량·팝오버 강조 (1091 / 327) | **없음**(6파일 하드코딩: plan_phase_editor, diagonal_flow_indicator, diagonal_media_list_item(`diagonalMediaHighlightColor`), plan_section_layout, developer_tools_main, theme `AppTextStyles.planPhaseNumber`) | 신규 토큰 `accent` |
| #f7c9f4 | 핑크 위 밝은 글자 (158) | 없음 | 신규 `accentText` |
| #2a1330 | 핑크 배경 위 글자 (79) | 없음 | 신규 `onAccent` |
| #e5a0ea | 스크롤 썸 (33) | 없음(4파일 하드코딩, `BATrianglePalette.softTitlePinkPanel`=0x80e5a0ea) | 신규 `scrollThumb` |
| #e9b0ee | `.ilab`/핑크 라벨 (80 / 33) | `BATrianglePalette.softTitlePinkBase`(0x88e9b0ee) | 토큰화 |
| #c3cfdb | 2차 본문(세그먼트·팝오버 본문) (238) | 없음 | 신규 `textSecondary` |
| #dfe7ee / #e6edf3 / #dbe4ec | 거의 흰 글자 변형 (127/130/44) | 없음 | `text`로 통합 여부 결정 |
| #6f8397 | 차트 축 라벨 (189) | 없음 | 신규 `textDim` |
| #0d151f | 팝오버·모달 패널 (184) | 없음 | 신규 `popover` |
| rgba(16,24,35,·) | 행 배경 .72 / 타일 .6 / 세그먼트 .9 / 차트 .55 (#101823 rgba 166) | 없음 | 신규 `rowSurface` |
| #203243 | KPI 타일·인디케이터 (90) | 없음(2파일 하드코딩) | 신규 `indicatorSurface` |
| #141e2b / #1b2735 / rgba(25,36,50,.96) | 패널 내부·포그 | 없음 | 포그 색 파라미터로 |
| #263d52 | 정적 포그 | `ScrollViewportFog._fogColor` | 일치(위젯 내부 상수) |
| #35526b @.84 / #213c52 @.72 / #264359 @.85 | 페이즈 카드 / 재화 타일 / 시나리오 카드 | 각 painter 하드코딩(`0xd635526b`/`0xc735526b`, `0xb7213c52`, `0xd9264359`) | 일치(토큰화 권장) |
| #a8e0ff #7fe3bd #ffd08a #ffa0a8 | 칩 글자(정보/ok/wn/dg) | 없음 | 신규 tone 쌍 |
| #2a3d54(#33496a) / #3a4b58(#455866) / #c79ac9 | `.btn` / `.tonal` / `.btn.tri` | 없음(tonal은 ColorScheme 유래) | 신규 |
| #6b3e6c→#4a3552 / #25587b→#2a4a66 | sel-pink / sel-blue 그라데이션 | 없음 | 신규 |
| #ff72b6 | 학생 카드 선택 (39) | `studentGridCardSelectionColor`, `AssetImageGrid.selectionColor` 기본값 | 일치(토큰화 권장) |
| #f3c96b vs #e8c15a | 성작 표시 vs 성급 필터 | #f3c96b 코드 2파일, #e8c15a 없음 | **불일치** |
| #920008 #bd8901 #226f9b #9945a8 / #7a8ea3 | 공격·방어 타입 | `student_section_layout.dart` 4색, #7a8ea3 없음 | 추출 + 1색 추가 |
| #5d7288 | 슬라이더 기본 채움 | 없음 | 신규 |
| #050911 | lifted shadow (632 rgba) | `defaultLiftedSectionShadow`, `_tabGlassShadow`, `diagonal_menu.dart _defaultSectionShadow`(3중 정의) | 일치(중복 정리) |
| rgba(6,10,16,.8/.72/.35), rgba(5,9,14,.62), rgba(10,16,24,.35) | 모달 스크림 5종 | 없음(`Color(0x66000000)` dev 패널) | 신규 `scrim`(값 통일 필요) |

### 7.2 글꼴

| 항목 | 시안 | theme.dart (`AppType`) | 판정 |
|---|---|---|---|
| 크기 스케일 | 빈도 상위: 13(1135) 12(1098) 11(1050) 15(381) 14(357) 12.5(305) 11.5(199) 16(188) 10.5(179) 10(159) 19(118) 20(104) 13.5(103) 26(86) 18(78) 30(61) 17(60) 21(50) 34(37) 22·24·28(≈30) 36(6) 43.2(8); 10 미만 다수(8.5 333, 9 222 — 주로 mrow·`.ihdr`·`.ilab` 내부) | 10/11/12/13/14/15/16/18/20/24/28/36 | 시안 전용 크기: **12.5, 11.5, 10.5, 13.5, 19, 17, 21, 22, 26, 30, 34, 25.2, 43.2, 10 미만** |
| 굵기 | 800(1358) 700(1260) 600(255) 500(241) 900(71) 400(36) | 400/500/600/700만 등록(Pretendard), GyeonggiTitle 500 한 종 | **800/900 다수 사용 — 폰트 파일 없음**(시안 @font-face도 500/600/700만 로드 → 브라우저 합성/근사 렌더) |
| 제목 서체 | `.dsp` GyeonggiTitle를 6.5~43px에 사용(15px 214회, 16px 169, 13/14px 각 95, 9px 95) — 값·소제목에도 사용 | 주석: "20px 미만에는 쓰지 않는다" (`displayBrand` 28, `displayBrandLarge` 36). 단 코드도 `diagonal_media_list_item.dart`(8.5), `plan_element_builder.dart`(8/12/17) 등에서 이미 위반 | **충돌** — 규칙 개정 필요 |
| tabular | 시안은 미지정 | `AppType.tabular` | 코드 유지 |
| 자간 | `.dsp` −.01em | 없음 | 소소 |

### 7.3 간격·반경·크기

| 항목 | 시안 | theme.dart / 코드 | 판정 |
|---|---|---|---|
| gap | 10(1329) 8(843) 6(539) 4(539) 7(449) 5(391) 3(297) 12(239) 2(207) 14(77) 18 | `AppSpacing` 6/10/16/24/32 | 시안 전용: 2,3,4,5,7,8,12,14,18 (8·12·14가 주요) |
| 배치 규칙 | 섹션 inset 10, 리스트 inset 8, 스크롤바 reserve 14, 인접 24/20 | `planPhaseRowWidth`(inset 8, reserve 14), `PlanDiagonalScrollbar`(trackInset 10) — 로컬 상수 | 일치(공용 토큰 없음) |
| 섹션 코너 | r14 | `buildRoundedSectionPolygon(radius:14)`, `_buildLGlassPath` 14 | 일치 |
| 행/타일 코너 | path r8(1026) r12(401) r10(148) | 행 radius 10(`planPhase…` `radius: 10`), mrow r7 | 혼재 |
| CSS radius | 3(977) 2 5(341) 4 7 6 1 11 12 8 10 | 탭 r8, 버튼 r10, 카드 r14, tooltip r8 | 시안 전용 소형 반경 다수(스큐 요소) |
| 컨트롤 높이 | 탭 44, 칩 24, 세그먼트 36(28/26), 토글칩 30, tonal 40~44, 스위치 22, 스테퍼 24, (i) 24 | 탭 44, `_StudentGridDisplayToggle` 27 | 신규 토큰 |
| 사선 각 | 80°(path 1564 세그먼트) / skewX(−10°) | `math.tan(80 * math.pi / 180)` 108회 인라인 | 공용 상수 필요 |

### 7.4 모션·그림자

| 항목 | 시안 | 코드 | 판정 |
|---|---|---|---|
| 섹션 intro/outro | 360ms easeInOutCubic | 6개 파일 개별 상수 360ms easeInOutCubic; `DirectionalSectionEntrance`는 easeOutCubic; 셸 460ms(`app_shell.dart:112`, `title_page.dart:97`, `account_section_cluster.dart`) | 토큰 없음(`AppMotion` 신규) |
| 탭 본문 | 970ms(120/300/…/190, −5.5%) | `AnimatedSectionStack`(120+300+360+190) | 일치 |
| 헤더 콘텐츠 | 220ms fade + slide(0.025,0) | `_CompoundPageHeader` AnimatedSwitcher | 일치 |
| 탭 선택 | 180ms easeOutCubic (`transition:background 180ms cubic-bezier(.22,1,.36,1)`) | `_TopTab` AnimatedContainer 180ms | 일치 |
| lifted shadow | 4층 .077/.113/.149/.184 | `paintLiftedPathShadow`(maxAlpha .22×(1−p·.65)) | 정확히 일치 |
| `.sw` CSS drop-shadow | (1,1,0,.18)+(2,2,1,.22) 섹션 래퍼에 추가 | 없음 | 이중 그림자 여부 확인 |
| 팝오버 그림자 | ring 1px #71c7f4@.38 + 0 10~18px 28~40px rgba(0,0,0,.55~.65) | 없음 | 신규 |

---

## 8. (c) 공통 위젯 구현 순서 제안

의존 방향: 토큰·기하 → 표면·행 → 스크롤 → 소형 컨트롤 → 오버레이 → 데이터 위젯 → 필터 조합 → 셸.

| 순서 | 묶음 | 내용 | 근거·의존 화면 | 난이도 |
|---|---|---|---|---|
| H0 | **토큰** | `AppColors` 확장(accent/accentText/onAccent/scrollThumb/textSecondary/textDim/popover/rowSurface/indicatorSurface/scrim, tone 쌍 6, 타입 색 5), `AppMotion`(360/460/970/220/180), `AppRadii`, 컨트롤 높이; `AppType` 개정(12.5/19/26/30 등 채택 여부, GyeonggiTitle 20px 규칙 개정, 800 처리) | 모든 화면. 결정 전 하드코딩 확산 방지 | S(코드) + 사용자 결정 |
| H1 | **DiagonalGeometry** | `tan80` 상수, `cutDepth`, rail left/right(y), 법선 inset(g/sin80), 둥근 다각형 단일 함수(Q vs 원호 결정), 행 오프셋 2모드(translate/resize) | 108개 인라인 계산·3종 다각형 함수 통합 | M |
| H2 | **표면·행** | `SectionSurface`(fill 알파·blur 결정 + `paintLiftedPathShadow`), `DiagonalRow`(.srow/.row/.plain/.tile 변형, default/hover/selected/blue, 테두리 path 공유 hit test), `WidgetTile`(W-* 타일 + TileTitle) | Scenario-Compare(srow 94), Flow·Inventory·Stats·Tactical 전부 | M |
| H3 | **스크롤 스택** | `DiagonalScrollViewport` = 표준 `Scrollable` + H1 오프셋 + `PlanDiagonalScrollbar` 이동·일반화(현 private 4종 대체) + `ScrollViewportFog`(extent·color·페이드 범위 파라미터) | 28 artboard(스크롤바), rs-* 3, sv-* 5 | M |
| H4 | **소형 컨트롤** | `BaChip(tone, removable)`, `StageTag`, `SkewSegmented`, `SkewToggleChip`(+TypeChip), `FilterButton`, `BaSwitch`, `Stepper`(=`_CompactTargetStepper` 추출) + `MaxBadge`, `NudgeButtons`, `TonalButton` 핑크 변형, `RailButton`(+그룹) | chip 39 / seg 31 / btn 25 / stage 9 artboard; Material `SegmentedButton`·`Chip` 교체 | M |
| H5 | **제목·텍스트 원자** | `PanelTitle`, `TileTitle`, `SubHeader(.ihdr)`, `KV` | Stats·Inventory·Scenario | S |
| H6 | **오버레이** | `InfoPopover`(i) → `AnchoredFlyout` 셸(방향 r/l/dn/dl, 꼬리, 사선 path 트리거, hover/focus/tap, 화면 경계 정렬) → `.php/.shp/.spop` 프리셋 → `BaModal`(스크림 + #0d151f 패널) | (i) 25 / fly 14 / 모달 9 artboard. `OverlayPortal` 기반(추정) | M~L |
| H7 | **이미지 원자** | `ItemIconTile`(rarity 배경 + 92% 아이콘), `PortraitStrip`(AssetImageGrid + "…+n"), `SkewBar`(.bar2, `PlanInventoryCoverageBar` 흡수) | `.pt` 22 / `.bar2` 18 artboard | S~M |
| H8 | **데이터 위젯** | `KpiTile`, `ResourceAmountRow`, `ItemTileWithBar`, `RatioBarRows`, `SkewHistogram`, `LineTrend`, `DivergingBars`, `SkewHeatmap`, `RiskRow`, `ShortageTopRow`, `ShortageChipFlyout` (공통 `StatChartGeometry` 안에서) | Stats 5, Inventory 5, W-Data | L |
| H9 | **필터 조합** | `RangeSliderRow`, `StarRangeBar`, `ActiveFilterChips` → 필터 모달 본문(학생 탭·계획 1·통계 공용) | Student-Filter, Flow-1-Students-Filter, Stats-Filter-Open | M |
| H10 | **셸 갱신** | `AppSection.tactic`(9번째 탭) + 선반 폭 규칙(760→860), `_ConnectionBadge` 회색 disconnected·게임 창 연결 변형 | 택틱 3 artboard, Home 3 | S |

---

## 9. 사용자 확인이 필요한 모호점

1. **핑크 강조색의 지위**: 시안은 #f2b3ef를 선택·강조 1순위로 1,400회 이상 사용하나 theme에는 없음(주 탭 선택은 여전히 파랑 primary). `accent` 토큰으로 승격하고 "선택=핑크, 탐색 탭=파랑"을 규칙화할지.
2. **섹션 표면**: 시안 surface@.76·블러 없음·무테 vs 코드 `DiagonalSection`(.92 + blur 8 + outline) / `SectionTemplateSurface`(.88 + blur 8). 어느 쪽을 표준으로.
3. **`.sw` CSS drop-shadow**가 lifted path shadow와 겹치는지(시안 렌더 보조인지 의도된 2중 그림자인지).
4. **GyeonggiTitle 20px 미만 금지 규칙**(theme 주석) vs 시안의 9~19px 값·제목 대량 사용. 규칙을 개정할지, 시안을 Pretendard로 바꿀지.
5. **굵기 800/900**: 폰트 파일이 없음. Pretendard 800/900을 추가 등록할지, 700으로 매핑할지.
6. **비표준 글자 크기**(12.5/11.5/10.5/13.5/19/26/30/34, 10px 미만): AppType에 추가할지 가장 가까운 토큰으로 스냅할지.
7. **연결 배지**: "연결 안 됨" 회색(시안) vs 빨강(코드). 또 Home의 "연결됨 · Blue Archive · 2560×1440"은 백엔드 연결(`BackendConnection`)이 아닌 게임 창 연결 — 별도 상태·배지인지.
8. **스크롤 포그 3종**(36 #263d52 / 44 패널색 / 56 .96)과 **사선 목록 2모드**(resize/translate)를 공용 옵션으로 모두 지원할지 한 가지로 통일할지.
9. **별 노랑** #f3c96b vs #e8c15a.
10. **모달 스크림 알파 5종** 통일 값.
11. **CSS 정의만 있는 클래스**(`.devbar`, `.viewsel`, `.chk`, `.dash`, `.stars`, `.tab`, `.chip.solid`, `.btn.icon/.dng`, `.tonal.cur/.done`, `.ord`, `.card`, `.scard2`)는 구현하지 않아도 되는지.
12. **택틱 탭 추가**: 9개 탭·선반 860px는 현행 `math.min(760, …)` 규칙과 다름 — 선반 폭을 탭 수에 맞춰 늘릴지, 760 유지하고 가로 스크롤(`_TopTabEdgeFade`)에 맡길지.
13. **텍스처 표현**: 시안은 구운 PNG(_blob), 코드는 `BATriangleTexturePainter` 절차 생성. 시안 PNG를 asset으로 쓸지(성능·일치) 절차 생성 유지할지.
14. **`.tile` 이중 의미**(재화 타일 vs 위젯 카드) — Flutter 이름 분리 확인.
15. **v7 학생 범위 조건**(`StudentRangeConditionSection`, 이상/이하 2패널)을 한 줄 범위 슬라이더로 대체(폐기)하는 것이 확정인지.

---

## 10. 그룹 전체 요약

- **재사용 확인**: 셸(L-glass·주 탭·헤더·dev 버튼), 섹션 기하(`buildAttachedSectionPolygon`, 96 grid), lifted shadow(수식이 시안 알파와 정확히 일치), 모션(`AnimatedSectionStack` 970ms), `DiagonalMediaListItem`, 성작·인연·상태 배지, `PlanPhaseCard`·`DiagonalFlowIndicator`, `PlanDiagonalScrollbar`(수치 일치), `ScrollViewportFog`(36/#263d52), 재화 타일·커버리지 바·S4 컨트롤·시나리오 카드·스테퍼·MAX 배지, `AssetImageGrid`, 텍스처 6종.
- **주요 부채**: 핑크 accent·2차 글자색·팝오버색 등 시안 핵심 색이 theme에 없음; 80° 계산 108회 인라인·둥근 다각형 3종·사선 스크롤바 5벌·모션 상수 6벌 중복; 쓸 만한 위젯 다수가 `plan_section_layout.dart`(8,445줄)·`student_section_layout.dart`(4,858줄) 안 private.
- **신규 공통 위젯**(약 30종): skew 계열(seg, 토글 칩, 단계 태그, 필터 버튼, 범위 슬라이더, skew 막대), 칩 6색, 레일 버튼, DiagonalRow, (i)·플라이아웃·모달, 아이템 아이콘 타일, 데이터 위젯 11종. Flutter lib 전체에 skew 변환 0건이라 −10° 요소는 모두 새로 만들어야 함.

### vertical slice 제안

| 슬라이스 | 범위 | 난이도 | 선행 |
|---|---|---|---|
| VS-H1 토큰·기하 기반 | H0 + H1 (+ 기존 private 스크롤바·포그·스테퍼 공용 이동, 동작 불변 리팩터) | M | 사용자 결정 1·2·4·5·6 |
| VS-H2 행·스크롤 | H2 + H3, 시연 대상 Scenario-List 목록 또는 Tactical 기록 목록 | M | VS-H1 |
| VS-H3 컨트롤 키트 | H4 + H5, Material `SegmentedButton`/`Chip` 교체를 한 페이지(statistics_page)로 검증 | M | VS-H1 |
| VS-H4 오버레이 | H6, (i)를 Flow·Stats 화면에 먼저 적용 | M~L | VS-H3(칩·seg가 팝오버 내용에 쓰임) |
| VS-H5 데이터 위젯 | H7 + H8, Stats·Inventory 그룹과 병행 | L | VS-H2, VS-H4; 백엔드(위험도 산식, 인벤토리 스냅샷 이력, 티어 충족 집계) |
| VS-H6 필터 | H9, 학생 탭·계획 1·통계 공용 필터 모달 | M | VS-H3, VS-H4 |
| VS-H7 셸 | H10 (택틱 탭, 연결 배지) | S | 택틱 그룹 범위 확정 |

백엔드 선행(그룹 H 범위에서 드러난 것만): 위험도 점수 산식/필드, 인벤토리 스냅샷 이력(꺾은선·±증감), 설계도 티어별 충족 집계(히트맵), 계획 결과의 단계별 재화 분해(부족 플라이아웃), 게임 창 연결 상태(Home 배지). `InventoryShortageRow.affectedStudentIds`로 부족 상위 행·칩 팝업은 현재 데이터로 충족.
