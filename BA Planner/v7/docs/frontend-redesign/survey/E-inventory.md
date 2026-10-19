> 오케스트레이터 조사 보고서(2026-10-05, 읽기 전용 조사). 본문의 `/mnt/user-data/uploads/v7/`는 저장소 루트, `.../scratchpad/canvas/project/`는 `docs/frontend-redesign/prototype/2026-10-05/`에 해당한다. [확인]은 grep·파싱으로 확인한 사실, (추정)·[추정]은 해석이다. 결정은 `docs/frontend-redesign/decision-register.md`가 우선한다.

# 그룹 E — 인벤토리 시안 ↔ Flutter 매핑 조사

대상 artboard(canvas.json `page: inventory`, 모두 2560×1392):

| 파일 | canvas 제목 | 캔버스 x |
|---|---|---|
| Inventory.dc.html | 인벤토리 · 부족 위험 + 상세 | 0 |
| Inventory-Analysis.dc.html | 인벤토리 · 분석 (학교별·오파츠·설계도·변화) | 2640 |
| Inventory-Analysis-Opa.dc.html | 인벤토리 · 분석 — 오파츠 확장 (확장 버튼 → 다른 섹션 퇴장 → 오파츠 확대 · 선택 오파츠 상세) | 5280 |
| Inventory-All.dc.html | 인벤토리 · 전체 아이템 (종류별 타일) | 7920 |
| Inventory-Tiers.dc.html | 인벤토리 · 티어별 충족률 (기술 노트 · BD · 오파츠) | 10560 |

캔버스 노트 `new2`: "인벤토리 — 부족 위험도 · 분석(오파츠 확장 포함) · 전체 아이템 · 티어별 충족률".

조사 방법: `<helmet>` 공통 CSS 제거 후 HTML 파서로 절대좌표 트리를 덤프(scratchpad/e/*.txt), 섹션 `.sw` 첫 path의 꼭짓점으로 형상 판정. **5개 파일 모두 `<script type="text/x-dc">`가 `class Component extends DCLogic { renderVals() { return {}; } }` 뿐** — 상태 로직·애니메이션 정의는 없다(확인). 상호작용은 정적 상태 스냅샷과 CSS `:hover`(flyout)로만 표현되어 있다.

표기: **[확인]** = 파일/코드에서 직접 확인, **[추정]** = 해석·추론.

---

## 공통 사항 (5개 artboard)

- 상단 크롬: 주 탭 nav(`aria-label=주 탭`, 8개 탭, 인벤토리 `.nt.on`), 헤더 @23,67 2511×109 — 제목 "인벤토리", 부제 "보유 재화와 장비"(Analysis는 "· 분석", Opa는 "· 분석 · 오파츠 확장", Tiers는 "· 티어별 충족률"), `.conn` "연결됨", `.devbtn`(개발 상태 패널). 작업영역은 `clip-path:inset(184px 0 0 0)`. [확인] → 다른 그룹(셸/헤더) 공통 요소이므로 여기서는 범위 외.
- 섹션 표면: `.sw`(drop-shadow 2단) + svg path 5겹(그림자 4 + 본체 `rgba(29,42,58,.76)`) + 동일 path clip. 사선은 높이 1000px당 약 176px 수평 이동 = 80°. [확인]
- 섹션 내부 헤더 행 패턴(이하 **SectionTitleRow**): 7×22 skewX(-10°) 핑크 바 + `.dsp` 제목 + chip/seg/버튼 + 아래 1px 그라디언트 라인 + 46×3 핑크 액센트. [확인]
- 사선 행(이하 **SlantRow**): 행마다 x가 사선을 따라 8~12px씩 이동하는 clip-path 행. `.srow`(선택 가능, `.sel` 핑크 4px 테두리) / `.row`(정보) / `.plain`(투명). [확인]
- 아이템 아이콘(이하 **ItemTile .pt**): `background-image`(배경판 blob) + `img`(아이콘 blob) 2겹. 같은 배경 blob(6aa789…)이 학생 초상 배경에도 쓰인다. 오파츠 일부·학교 일부는 아이콘 대신 두 글자 텍스트("아우", "볼프", "아리" 등) 폴백. [확인] → asset 누락을 시안에서 텍스트로 대체한 것 [추정].
- 학생 미니 초상(이하 **StudentChip34**): 34×28 또는 38×30 배경+초상 2겹, 초과분 "…+N" skew 칩. [확인]
- 진행 막대 `.bar2`(8~10px, 일부 skewX(-10°)), 색: 핑크=부족, 파랑=충분, 노랑=과잉(도움말 문구 기준). [확인]
- Flyout(**HoverFlyout**, `.flyw/.flyt/.fly`): `:hover`/`:focus-within`/`.open`에서 420px 패널을 오른쪽에 띄움. Inventory-All과 Analysis/Opa에 있음. [확인]
- (i) 팝오버 `.info > button.ib + span.pop`. [확인]

### 섹션 부착면 규칙 대비 (frontend-section-direction-and-user-flows.md §1.2/§1.4)

판정: 왼쪽 면 수직=왼쪽 부착, 오른쪽 면 수직=오른쪽 부착, 양쪽 사선=중앙(위/아래 부착).

---

## 1. Inventory.dc.html — 부족 위험 + 상세

### 1.1 목적·섹션
"부족한 것" 보기의 기본 진입 화면 [추정: 사이드바 "부족한 것"이 `sel-blue`]. 4섹션 [확인]:

| # | 역할 | rect (x,y,w,h) | 형상 | 부착면 / intro·outro(문서표) |
|---|---|---|---|---|
| A | 필터 사이드바 | 0,209,693,1183 | 사다리꼴(우측 사선) | 왼쪽 / 0·180 |
| B | KPI 띠 | 693,209,1867,138 | 사다리꼴(좌측 사선) | 오른쪽(위) / 180·0 |
| C | 부족 위험도 순위 목록 | 509,365,1231,1027 | 평행사변형 | 아래 / 80·260 |
| D | 선택 재화 상세 | 1583,365,977,1027 | 사다리꼴(좌측 사선) | 오른쪽(아래) / 180·0 |

C와 D는 x 1583~1740 구간에서 사선끼리 겹쳐 맞물림. [확인]

### 1.2 요소
- A: seg "아이템 | 장비"(아이템 on), cap "보기" + 버튼 2개 "부족한 것 14종"(sel-blue)/"전체 183종", cap "종류" + **CategoryFilterButton** 7개(엘레프 38·부족3 / 오파츠 48·부족2 / 활동 보고서 4 / 기술 노트 34·부족4 / BD 34·부족3 / 장비 설계도 20·부족1 / 선택권·상자 5) — 각 버튼 폭이 사선 따라 8px씩 감소, cap "주요 재화" + **KeyCurrencyCard** 2개(크레딧 98.4M / 필요 261.5M / −163.1M + skew bar, 엘리그마 1,020 / 2,245 / −1,225). [확인]
- B: **KpiStrip** 6개 kv: 보유 품목 183종 · 부족 재화 14종(+3 지난 스캔 대비) · 과잉 재화 8종(−1) · 계획 충족률 72% · 최근 감소 6종 · 마지막 스캔 3일 전. [확인]
- C: SectionTitleRow "부족 위험도 순위" + (i) "위험도: 필요량 대비 보유량이 적을수록, 그 재화를 쓰는 학생이 많을수록 높습니다. 100에 가까울수록 계획을 오래 막습니다." + 정렬 chip "위험도(pk)/충족률/부족량". **RiskRow**(`button.srow` 1010×58, 첫 행 `.sel`): ItemTile 54×44 · 이름 · "보유 1 / 필요 450 · 사용 학생 1명" · bar(폭=위험도%) · 위험도 숫자(98/88/76/71/62/40) · 78px 빈 슬롯. 하단 1203×36 빈 div(스크롤 포그 자리 [추정]). [확인]
- D: 제목 "상세 · 엘레프", 헤더 카드(ItemTile 111×90, "마지막 확인 · 인벤토리 스캔 3일 전 · 인식 성공"), kv 행(보유 1 / 필요 450 / 부족 449 / 충족률 0%), "사용하는 학생 · 막히는 단계 1" + 행("리오(무장) · 페이즈 1 · 1단계 (성급 3→5) −449"), "보충 방법" 3행(엘리그마 변환: 2,245개 필요·보유 1,020 / 총력전 상점: 주 5개·약 90주 / 선택권: 해당 선택권 없음), "최근 변화 · 스캔 4회 / 순변화 +1 · 이전 스캔과 이상 없음" + **ScanHistorySparkline**(svg polyline, 3주 전·2주 전·1주 전·지금), 액션 `.tonal` skew 버튼 3개 "계획에서 보기(pri) / 수량 직접 고치기 / 인벤토리 스캔". [확인]

### 1.3 상태·상호작용
script 없음. 표현된 상태: 목록 행 선택(.sel) ↔ 상세 바인딩, 정렬 chip 3종, 보기(부족/전체) 2종, 종류 필터. 전환은 Inventory-All(전체 보기)로 이어짐 [추정].

### 1.4 현재 코드 대응
- `ui/pages/inventory_page.dart` `InventoryPage`/`_InventoryPageState`: ListView + `RepositoryProfilePanel` + `DiagonalSection`(구형 클리퍼) + Material 드롭다운/TextField 행(`_InventoryRow`, `_Metric`, `_InventoryNotice`, `_CandidatePanel`). **레이아웃은 폐기·재작성 대상**, 로직(`_loadCatalog`, `_syncEditors`, `_inventoryWire`, `_save`, `_calculateShortages`, `_approveCandidate`, `_visible` 정렬)은 **재사용(추출) 대상**. [확인]
- 프로필 선택: 페이지 내 `RepositoryProfilePanel` → 시안엔 없음. 셸 `app_shell.dart`의 `_selectedProfile`을 쓰도록 **수정** 필요(현재 InventoryPage 생성자에 profile 인자 없음). [확인]
- 섹션 셸: 다른 탭의 `SectionCanvasElement`+`AttachedSectionSpec`(trapezoid/parallelogram, face) 체계(`ui/studio/section_template.dart`, `section_template_surface.dart`의 `AttachedSectionClipper`)로 **신규 구성**. 기존 `DiagonalSection`은 폐기 대상. [확인/추정]
- RiskRow·상세 kv 행: `PlanBottleneckDiagonalList`(plan_section_layout.dart) 및 `DiagonalMediaListItem`의 사선 행 렌더 방식이 가장 가까움 → 공통 SlantRow로 추출 권장 [추정].
- 아이콘: `planningResourceIconAsset({category,itemId})`(ui/models/planning_resource_assets.dart) **재사용** — 카테고리 매핑 `tech_notes→skill_book`, `tactical_bd→skill_db`, `oopart|workbook→ooparts`, `activity_report→activity_reports`, `equipment→equipment`, `present→presents`, `student_eleph→assets/student_elephs/`, `credits→currency/Currency_Icon_Gold.png`. 배경판은 `planDefaultItemBackgroundAsset` 하나뿐(티어별 배경 없음) → 티어별 item_backgrounds 매핑 **신규**. [확인]

### 1.5 데이터 요구
| 표시값 | 현재 제공 | 근거 |
|---|---|---|
| 보유/필요/부족/사용 학생 수 | **있음** | `AppService.calculateShortages`(`planning.plan.shortages`) → `InventoryShortageRow{requiredAmount, owned, shortage, affectedStudentIds, resolved}` (입력: repository `state.goals`) |
| 위험도 0~100 | **없음(공식 미정)** | 클라이언트에서 shortage/required, affectedStudentIds.length로 계산 가능하나 가중치 미정 |
| 충족률 % | 클라이언트 계산 가능 | owned/required |
| 막히는 단계(페이즈·단계·성급 3→5·학생별 수량) | **부분** | `affectedStudentIds`는 학생 ID만. 단계·학생별 수량은 `PlanningDocumentService.calculatePlanningDocument`(`planning.document.calculate`)의 `stage_results[].resources`, `bottlenecks[].affected_stage_ids/phase_number/remaining_at_entry`에 있음(plan_section_layout.dart에서 bottlenecks/affected_stage_ids 사용 확인, stage_results는 UI 미사용, mock은 빈 리스트) — 단, 문서(시나리오) 기준이며 "활성 계획" 개념은 서비스에 없음 |
| 마지막 확인 시각·인식 성공 | **없음** | `RepositoryInventoryState.entries` 허용 키 = key, quantity, item_id, name, index, profile_id, observed_slot (타임스탬프·출처 없음) |
| 최근 변화(스캔 4회 시계열), KPI "+3 지난 스캔 대비", "최근 감소 6종", "마지막 스캔 3일 전" | **없음** | 인벤토리 스냅샷 이력 API 없음. `ScannerRecentSummary`/`ScannerSession`/`ScannerCandidate`에도 시각 필드 없음 → `repository.inventory.history`(가칭) 같은 백엔드 이력 저장·조회 신규 필요 |
| 보충 방법(획득처·주간량·선택권) | **없음** | 아이템 획득처 메타 없음 → 백엔드 메타 신규 |
| 과잉 재화 수 | 부분 | owned>required는 계산 가능, 계획에 안 쓰는 품목의 과잉 정의 미정 |
| 계획 충족률 72% | 공식 미정 | 집계식(품목 평균/가중) 미정 |
| 크레딧·엘리그마 보유 | **확인 불가** | 프론트 카탈로그 카테고리 집합(developer_tools_main.dart `_itemCategoryLabel`: equipment, activity_report, tech_notes, tactical_bd, oopart, workbook, student_eleph)에 통화 없음, 스캔 프로필(`InventoryScanProfile`)에도 없음. 필요량 크레딧은 `calculatePlan`의 `credits`로 있음 |
| 종류별 개수·부족 수 | 있음 | `listInventoryItems().items[].category` + shortage rows 집계 |
| 수량 직접 고치기 | 있음 | `RepositoryService.saveRepositoryInventory`(전체 bucket 저장, revision 충돌 처리) |
| 계획에서 보기 | 부분 | `onOpenPlan`은 인자 없는 VoidCallback → 재화/단계 포커스 인계 파라미터 신규 |

### 1.6 모호점
1. 위험도 공식(부족비·학생 수 가중)과 "계획 충족률" 집계식.
2. "활성 계획" = repository `goals`(calculateShortages 경로)인가, 시나리오 문서(calculatePlanningDocument 경로)인가. 막히는 단계 표시는 후자가 필요.
3. 사이드바 종류 "장비 설계도"/"선택권·상자"는 현 카테고리(equipment, present, workbook…)와 1:1이 아님. present(선물)·workbook(교본)이 시안에 없음.
4. 크레딧·엘리그마 보유량의 출처(스캔 대상 아님).
5. flows 문서 §6 검수 포인트 "기본 진입을 보유량 목록/부족 진단 중 어디에" → 시안은 부족 진단(부족한 것) 기본으로 보임. 결정문화 필요.
6. 스캔 후보 비교(`_CandidatePanel`, 흐름 C)가 시안 5장 어디에도 없음 → 인벤토리 탭에서 제거하고 스캔 탭으로 이관하는지 결정 필요.

---

## 2. Inventory-All.dc.html — 전체 아이템(종류별 타일)

### 2.1 섹션
Inventory.dc와 **섹션 rect 완전히 동일**(A/B/C/D) [확인]. 사이드바 "전체 183종"이 sel-blue, C 내용만 타일 그리드로 교체, D는 "기술 노트 (최상급)" 상세.

### 2.2 요소
- C: SectionTitleRow "전체 아이템" + (i) "타일 읽는 법: 숫자는 보유량… 분홍=부족, 파랑=충분, 노랑=과잉, 막대가 없으면 계획에 안 쓰는 재화" + chip "종류순(pk)/계획에 쓰는 것만/보유 0 숨기기". 그룹 헤더(**TileGroupHeader**: ihdr 이름 + "38종" + chip "부족 3") 다음에 **InventoryTile** 74×74(ItemTile 74×60 + 하단 skew 보유량 숫자 + 65×4 skew 충족 막대, `aria-label="보유 N"`). 그룹: 엘레프(3)·오파츠(6)·기술 노트(8)·장비 재료(7). 행 시작 x가 그룹마다 사선을 따라 21px씩 이동. [확인]
- HoverFlyout 9개: 타일 그룹 헤더의 "부족 N" chip 4개(@783,448 등, 기술 노트는 `.open` 상태로 표시) + 사이드바 종류 버튼 chip 5개(@516,463 등). 내용: "부족한 기술 노트 7종 · 부족량 순 · 상위 5", 행(아이콘 42×34, 이름, −30, bar, 보유 6 / 필요 36), "… 외 2종 · 모두 보기 →". [확인]
- D: 사용하는 학생 3행(리오(무장)·스킬 M (EX 4→5) −20 등), 보충 방법 3행(선택권 "최상급 기술 노트 선택권 5장 · 해당", 학원 교류회 "하루 약 1.2개", 주간 합동 화력 연습 "주 4개"), 최근 변화(18→15→12→12, "순변화 −6 · 2주 뒤 소진 예상"). [확인]

### 2.3 상태
보기=전체, 그룹=종류순, 선택 타일=기술 노트(최상급), flyout 1개 open. 필터 chip 2개는 off 상태만 표시.

### 2.4 코드 대응
- 타일 그리드: `AssetImageGrid`(ui/widgets/asset_image_grid.dart — `rowHorizontalOffsets`, `selectedCell`, `onCellTap`, 셀 painter 방식)를 **재사용** 가능 [확인: API 존재 / 추정: 사선 행 오프셋으로 시안 재현 가능]. 수량·막대 오버레이는 신규.
- HoverFlyout: 기존 대응 위젯 없음(grep 결과 flyout/hover 패널 미발견) → **신규** 공통 위젯(W-Info-Popover 계열 그룹과 공유 권장).
- 정렬 'catalog'은 `_visible`의 `catalogRank`(=`order_index`) 재사용. 문서(inventory-catalog-order.md): 정렬 기준은 `order_index`(카탈로그 revision 내에서만 유효), 동일성은 `resource_key`. [확인]

### 2.5 데이터
- 보유량·카테고리·순서: 있음(`listInventoryItems`, repository inventory).
- 막대 색(부족/충분/과잉/미사용): shortage rows로 계산 가능(미포함=미사용). 단 "과잉" 임계 정의 필요.
- "소진 예상 2주 뒤": 이력 기반 추세 → 이력 API 필요(없음).
- 보유 미확인(quantity null) 표시: 시안에 상태 없음. 문서는 "스캔 데이터 없는 상태를 0으로 표시 금지" [확인: flows §6].

### 2.6 모호점
1. 그룹 "기술 노트" 타일에 BD 아이콘(전술 교육 BD) 포함, 사이드바엔 BD 별도 → 그룹 경계 불일치.
2. 사이드바 "장비 설계도"인데 타일 그룹은 "장비 재료"(헤어핀 등 포함). seg "아이템 | 장비"와의 관계도 모호.
3. 기술 노트 부족 수가 Inventory.dc "부족 4" vs All "부족 7"(목업 숫자 불일치).
4. 보유 미확인(Unknown) 타일 표현 누락.

---

## 3. Inventory-Analysis.dc.html — 분석(학교별·오파츠·설계도·변화)

### 3.1 섹션 (5) [확인]
| # | 역할 | rect | 형상 | 부착면 |
|---|---|---|---|---|
| A | 사이드바(분석 모드) | 0,209,693,1183 | 사다리꼴(우사선) | 왼쪽 |
| S1 | 학교별 BD·기술 노트 충족률 | 613,209,947,591 | 평행사변형 | 위 |
| S2 | 오파츠 · 보유율 × 수요 | 1484,209,1076,568 | 사다리꼴(좌사선) | 오른쪽(위) |
| S4 | 종류 × 티어 충족률 + 부족 상위 | 1375,801,1185,591 | 사다리꼴(좌사선) | 오른쪽(아래) |
| S5 | 최근 변화 | 509,824,943,568 | 평행사변형 | 아래 |

### 3.2 요소
- A: seg "목록 | 분석"(분석 on) — **Inventory/All의 "아이템 | 장비" 자리와 동일 위치**, cap "비교 기준" seg "계획 요구량(on) | 이론상 전체 요구량" + 설명 "활성 계획의 학생·목표에 필요한 양과 비교합니다", cap "이 화면에 보이는 분석" 버튼 4개(학교별 BD·노트 / 오파츠 균형 / 장비 설계도 / 변화 추이 — 앵커 스크롤/포커스 [추정]), cap "따로 여는 화면" 버튼 2개(티어별 충족률 → Tiers artboard / 과잉 재화 "넘치는 재화 정리" — artboard 없음). [확인]
- S1: SchoolRow 6개(밀레니엄·게헨나·트리니티·아비도스·백귀야행·산해경): 학교 엠블럼 30×26 · 이름 · "BD" bar+% · "기술 노트" bar+% · "부족 상급 BD/최상급 노트/—" · chip "계획 5명". 각 행 "계획 N명" 위에 HoverFlyout(밀레니엄 `.open`): "밀레니엄 · 계획 학생 5명 · 부족 필요량 · BD · 노트" + 학생별 "상급 BD 12 / 최상급 노트 8" + "계획에서 보기 →". chip "계획 필요 환산량 기준". [확인]
- S2: **OopartScatter** — svg 1012×420, 플롯 영역 자체가 평행사변형 polygon(56,380 → 935,380 → 1002,0 → 123,0), x축 "계획 대비 보유율 →", y축 "사용 학생 수 →", 4분면 점선, 점 색=티어(T1 #b8c4cf, T2 #71c7f4, T3 #ffc66d, T4 #c89cf5), 같은 오파츠 티어끼리 선 연결, 핵심 병목 링 표시, 8종×4티어 `<title>` 툴팁. 헤더 chip "왼쪽 위 = 핵심 병목", `button.tonal aria-label="오파츠 패널 확장"` "확장", 티어 토글 seg T1~T4(전부 on). [확인]
- S4: SectionTitleRow "종류 × 티어 충족률" + seg "설계도(on)/기술 노트/BD/오파츠" + chip "충족률(pk)/보유량/부족량". **TierHeatmap**(`.hm.sk` CSS grid, skewX(-10°) 셀·내부 역skew): 9 장비 부위(모자·장갑·신발·가방·배지·헤어핀·시계·목걸이·부적) × T1~T10 % 셀 + 범례 "0% … 100% 충족". "부족 상위" 행 3개(시계 T8 설계도 −36 · 학생 7명 + StudentChip34 5개 + "…+2" 등). [확인]
- S5: SectionTitleRow "최근 변화" + seg "1주(on)/2주/4주", cap "주간 순증감 상위 (오른쪽 증가 · 왼쪽 감소)", **DivergingBarRow** 6개(상급 활동 보고서 +120, 로혼치 사본 +86, 밀레니엄 BD(최상급) +24, 설계도·시계 T8 −9, 게헨나 기술 노트(최상급) −14, 네브라 디스크 −6) 중앙축 x=1002, cap "이 추세라면" + 예측 행 2개("기술 노트 (최상급) 부족이 커지는 중" chip dg "4주 뒤 −66", "밀레니엄 BD는 곧 충분" chip ok "2주 뒤 0"). [확인]

### 3.3 상태·상호작용
분석 모드 기본 상태. 확장 버튼 → Analysis-Opa(§4). 비교 기준 seg 토글, 섹션별 seg/chip 토글, 학교 flyout. script 없음.

### 3.4 코드 대응
- 분석 화면 전체 **신규**. 현재 InventoryPage에 분석 모드 없음(`_showShortages` bool만). 
- 집계 로직 일부는 `statistics/statistics_projection.dart`의 `buildPlanStatistics`(category별 `ShortageCategoryStatistics`)·`buildInventoryStatistics`(category별 known/unknown/zero/positive)를 참고·확장 가능 — 단 둘 다 **category 단위**이고 학교·티어 축은 없음. [확인]
- 차트(scatter/heatmap/diverging bar): 기존 차트 위젯 없음(코드 grep 결과 해당 painter 없음) → **신규** CustomPainter. 통계 그룹(Stats-Inventory artboard: "B1 충족률 · B2 부족/과잉 · B3 재화 변화")과 차트·집계 재사용 가능성 높음 [추정].

### 3.5 데이터
| 표시값 | 현재 | 비고 |
|---|---|---|
| 학교 축(BD·노트) | **없음(필드)** | `InventoryCatalogEntry` 필드 = resourceKey, itemId, displayName, category, profileId, orderIndex, zeroFillAllowed. 학교·티어 필드 없음. itemId 패턴(`Item_Icon_SkillBook_Gehenna_0`, `Item_Icon_Material_Nebra_0` — mock 기준)에서 파싱은 가능하나 계약 외 [추정·위험] → 카탈로그에 `school`, `tier`, `family`(오파츠 종류/장비 부위) 메타 추가 권장 |
| 학교별 계획 학생 수·학생별 부족 필요량 | 부분 | 학생 학교는 `StudentCatalogEntry.school` 있음. 학생별·재화별 필요량은 `affectedStudentIds`로 불가 → per-student breakdown 필요(`stage_results` 또는 shortage row 확장) |
| "계획 필요 환산량" | 정의 미정 | BD/노트 하위 티어 환산(상급→최상급 환산?) 규칙 백엔드 정의 필요 |
| 이론상 전체 요구량 | **없음** | 계획 외 "전체 육성" 요구량 계산 API 없음 (flows §6 검수 포인트 "계획 부족과 전체 육성 부족" 미결) |
| 오파츠 보유율×사용 학생 수, 티어 연결 | 부분 | shortage rows(category `oopart`) + affectedStudentIds.length로 가능, 오파츠 종류·티어 그룹핑은 메타 필요 |
| 장비 부위×티어 충족률 | 부분 | 장비 설계도 행의 부위·티어 메타 필요 |
| 주간 순증감·추세 예측 | **없음** | 스냅샷 이력 필요 + 예측 규칙 정의 필요 |

### 3.6 모호점
1. 사이드바 최상단 seg가 화면별로 "아이템|장비" vs "목록|분석" — 두 seg 공존인지, 목록 모드 안에서만 아이템/장비가 보이는지.
2. "과잉 재화" 별도 화면 artboard 없음.
3. "이 화면에 보이는 분석" 버튼 4개의 동작(스크롤 앵커? 섹션 강조?) 미표현.
4. S1 학교 6개만 표시(Tiers는 9개) — 표시 기준(계획 학생 있는 학교만?) 미정.
5. 오파츠 종류 목록이 Analysis(8종: 네브라·로혼치·파에스토스·안티키테라·아우름 코인·오브 오브 위트·구스타프 총알·토리노 수의)와 Tiers(13종: 볼프세크·님루드·만드라고라·에테르·보이니치·하니와·토템 폴·고대 전지·황금 나사 등)가 다름 — 목업 데이터인지, Analysis는 "계획 사용 오파츠만"인지.

---

## 4. Inventory-Analysis-Opa.dc.html — 오파츠 확장

### 4.1 섹션
**섹션 1개만 존재**: 12,209,2548,1183, 사다리꼴(좌사선 222.6→14, 우측 수직) = 오른쪽 부착 [확인]. 사이드바 포함 다른 4개 섹션이 모두 퇴장한 최종 상태. 확장 전 S2 rect(1484,209,1076,568) → 확장 후(12,209,2548,1183): 오른쪽·위 부착을 유지한 채 왼쪽·아래로 확대 [추정: 제목의 "확대"].

### 4.2 요소
- 헤더 행: 제목 동일, 버튼 "축소"(aria-label 없음), 티어 seg T1~T4.
- Scatter 1974×1035: 점이 **오파츠 아이콘 이미지**(`g > clippath + image + text "T1"`)로 바뀜(아이콘 없는 4종은 "아우/오브/구스/토리" 텍스트 폴백). [확인]
- 우측 상세 열 @2056,325 474px(**SelectedOopartPanel**): 아이콘 64×52 "선택한 오파츠 · 네브라 디스크" + chip "핵심 병목", "티어별 보유 / 필요 (계획 요구량)" 4행(T1 보유 210/필요 180 충분 … T4 12/58 −46, skew bar), "사용 학생" StudentChip34 5개+"…+1" + HoverFlyout("네브라 디스크 · 사용 학생 6명 · 부족한 티어별 필요량", 학생별 "T4 12 / T3 8"), "병목 순위 · 가장 부족한 티어 기준" 5행(1 네브라 디스크 T4 −46 … 5 토리노 수의 T3 −9), 버튼 `.tonal.pri` "계획에서 쓰는 단계 보기". [확인]

### 4.3 상태·애니메이션
script 없음 → 시퀀스는 제목 문구로만 정의: **확장 버튼 → 다른 섹션 퇴장 → 오파츠 확대 → 선택 오파츠 상세**. 문서 부착면표 적용 시 퇴장 방향: A(왼쪽) 180, S1(위) 80, S4(오른쪽) 0, S5(아래) 260 [추정]. 축소는 역순 [추정].

### 4.4 animated_section_stack로 가능한가 — **단독으로는 불가** [확인]
`ui/widgets/animated_section_stack.dart`의 `AnimatedSectionStack`은 `children` 중 `index` 하나를 페이지 단위로 교체(전체 페이지를 `motions[i].outro`로 밀어내고 다음 페이지를 `intro`로 들여옴, 120+300+360+190ms)한다. 페이지 안의 **섹션별 개별 퇴장 방향**도, **남는 섹션의 rect/형상 morph**도 지원하지 않는다. `independentMotionIndices`는 해당 페이지의 이동을 끄는 옵션일 뿐이다.
재사용 가능한 선례:
- `sectionMotionOffset(size, angle)` (같은 파일) — 섹션별 방향 오프셋 계산 **재사용**.
- `studentSectionMotionTranslation(...)`(student_section_layout.dart) — 섹션별 intro/outro 진행 **재사용 패턴**.
- `plan_phase_editor.dart`의 `phaseEditorElements(completionProgress)` + `_lerpGridRect(from,to,progress)` + `phaseEditorMotionFor(id)` + 섹션별 `_PhaseEditorMotion` — **섹션 rect morph + 섹션별 퇴장의 직접 선례**. 단 `_lerpGridRect`는 private이고 `SectionGridRect`가 정수 그리드(`sectionTemplateGridSize` = 12×8 = 96)라 `.round()` 보간 → 2560px 기준 1칸 ≈26.7px 계단 현상 우려. 실수 rect 보간 + 사선 path 재계산으로 공통화 필요 [추정].
→ 권장: 인벤토리 분석 페이지 내부를 phase editor 패턴으로 구성(섹션별 AnimationController/progress, 퇴장 완료 후 S2 rect 보간, 확대 중 scatter 레이아웃 보간 또는 크로스페이드), 탭 간 전환만 기존 `AnimatedSectionStack` 사용.

### 4.5 데이터
§3.5와 동일 + 티어별 보유/필요(오파츠 family×tier 메타 필요), 학생별 티어별 필요량(per-student breakdown 필요), "계획에서 쓰는 단계 보기"(계획 탭으로 재화+단계 포커스 인계 신규).

### 4.6 모호점
1. 확장 시 점이 dot→아이콘으로 바뀌는 전환 방식(즉시 교체/크로스페이드).
2. 확장 상태에서 헤더 부제 변경("· 분석 · 오파츠 확장") — 라우팅 상태인지 로컬 상태인지.
3. "축소" 버튼 aria-label 누락(확장은 있음).
4. 점 선택(선택 오파츠) 상호작용이 확장 전 S2에도 있는지.

---

## 5. Inventory-Tiers.dc.html — 티어별 충족률

### 5.1 섹션 (6) [확인]
| # | 역할 | rect | 형상 | 부착면 |
|---|---|---|---|---|
| A | 사이드바(분석, "티어별 충족률" sel-pink) | 0,209,693,1183 | 사다리꼴 | 왼쪽 |
| T1 | 기술 노트 · 학교 × 티어 충족률 | 640,209,920,436 | 평행사변형 | 위 |
| T2 | 전술 교육 BD · 학교 × 티어 충족률 | 559,669,920,436 | 평행사변형 | **어느 경계에도 안 닿음**(y 669~1105, x 559~1479) |
| T4 | 오파츠 · 종류 × 티어 충족률 | 1480,209,1080,591 | 사다리꼴(좌사선) | 오른쪽(위) |
| T5 | 티어 품목 · 부족 상위 | 1375,824,1185,568 | 사다리꼴(좌사선) | 오른쪽(아래) |
| T6 | 티어 충족 요약 | 509,1129,889,263 | 평행사변형 | 아래 |

### 5.2 요소
- T1/T2: TierHeatmap(grid 96px + 4열 + 128px): 학교 9개(백귀야행·붉은겨울·트리니티·게헨나·아비도스·밀레니엄·아리우스·산해경·발키리) × 초급/일반/상급/최상급 % + "가장 부족"(아이콘 + "최상급 −27"). chip "충족률/보유량/부족량". [확인]
- T4: TierHeatmap 오파츠 13종 × T1~T4 + "가장 부족"(T3 −37 등). [확인]
- T5: "부족 상위" 행 6개(오파츠·네브라 디스크 T3 −37 · 학생 3명 / BD·트리니티 상급 −31 / 기술 노트·게헨나 최상급 −30 …) + StudentChip34. [확인]
- T6: KPI kv(기술 노트 충족률 68% · BD 충족률 77% · 오파츠 충족률 61% · 최상급 부족 품목 14종) + **TierDistributionBar**("부족 품목 25종 · 티어 분포" 초급 0/일반 2/상급 9/최상급 14, skew 누적 막대). [확인]

### 5.3 상태
사이드바 "따로 여는 화면 → 티어별 충족률"이 선택된 별도 화면(Analysis와 사이드바 동일, 나머지 섹션 교체). chip 3종(충족률/보유량/부족량) 표시 모드 토글. script 없음.

### 5.4 코드 대응
전부 **신규**. TierHeatmap은 Analysis S4와 동일 컴포넌트로 공유. 사이드바는 Analysis와 공유.

### 5.5 데이터
- 학교×티어(노트·BD), 오파츠 종류×티어: 카탈로그 `school/tier/family` 메타 **필요(없음)**. 충족률·부족량은 shortage rows로 계산 가능.
- 티어별/카테고리별 충족률 집계식(품목 평균? 필요량 가중?) 미정.
- "가장 부족" 셀: 클라이언트 계산 가능(메타 전제).

### 5.6 모호점
1. **T2가 중앙에 떠 있음** — flows 문서 §1.1 "어느 경계에도 연결되지 않은 채 중앙에 독립적으로 떠 있는 섹션은 만들지 않는다"와 충돌. intro/outro 방향도 미정(문서 §1.4 "중앙 섹션을 띄우지 않는 이유" 참조).
2. 티어 표기: 노트·BD는 초급/일반/상급/최상급, 오파츠는 T1~T4, 설계도는 T1~T10 — 카탈로그 tier 값 체계 통일 필요.
3. 학교 목록(9개)이 Analysis S1(6개)과 다름.
4. 이 화면이 분석 모드의 하위 화면(같은 페이지 내 섹션 교체)인지, 별도 라우트인지.

---

## 6. 핵심 질문 답변

| 질문 | 답 |
|---|---|
| 부족 위험도 데이터 | 계획 필요량·보유·부족·영향 학생 ID는 **있음**(`calculateShortages` → `InventoryShortageRow`). 위험도 점수 공식은 **없음**(클라이언트 계산 가능하나 정의 필요). 막히는 단계는 `calculatePlanningDocument`의 `bottlenecks`/`stage_results` 경로로만 가능하고 "활성 계획 문서" 선택 개념이 필요. |
| 변화(스냅샷 간) | **없음**. 인벤토리는 단일 현재 스냅샷(`RepositoryInventoryState`)뿐, 항목별 시각·출처·이력 없음. 스캐너 recent summary도 시각 없음·메모리 bounded. → 백엔드에 인벤토리 스냅샷 이력(커밋 시각, 출처 scan/manual, 항목 diff) 저장 + 조회 메서드 신규 필요. KPI "+3 지난 스캔 대비", "최근 감소", "마지막 스캔 N일 전", 스파크라인, 주간 순증감, 소진 예측 전부 여기에 의존. |
| 학교별 집계 | 학생 쪽 `StudentCatalogEntry.school`은 있음. 아이템 쪽 학교·티어·family 메타 **없음**(카탈로그 7필드 고정, `fromWire`가 키 집합 정확히 일치 검사 → 필드 추가 시 프론트 파서도 동시 수정 필요). 학생별·재화별 필요량 breakdown도 없음. |
| 티어별 충족률 | tier 메타 부재로 불가. 메타 추가 후 shortage rows 집계로 가능. |
| 섹션 퇴장/확대 애니메이션 | `AnimatedSectionStack` 단독 불가(페이지 단위 교체). `sectionMotionOffset` + plan_phase_editor의 rect morph 패턴(`phaseEditorElements`/`_lerpGridRect`/`phaseEditorMotionFor`) 공통화로 구현. |

추가 확인 사항:
- 기존 테스트 `inventory_page_test`(로컬 없음, 파일명만)는 현 키(`ValueKey('inventory-page')`, `inventory-quantity-<resourceKey>`)에 의존할 가능성이 높아 재작성 시 함께 갱신 필요 [추정].
- inventory-catalog-order.md: 정렬은 `order_index`(catalog_revision 범위), 동일성은 `resource_key`, 스캔 위치는 `observed_slot` — 이력/변화 기능의 키는 반드시 `resource_key`로 해야 함 [확인].

---

## 7. 그룹 전체 요약 — 구현 단위(vertical slice) 제안

| 순서 | 슬라이스 | 내용 | 난이도 | 선행 의존 |
|---|---|---|---|---|
| E0 | 상태·로직 추출 | `_InventoryPageState`의 카탈로그 로드·편집·저장·shortage 계산·후보 승인 로직을 컨트롤러로 분리, 셸 `_selectedProfile` 연동(페이지 내 RepositoryProfilePanel 제거) | S | 없음 |
| E1 | 목록 셸 + 부족 위험 목록 | 4섹션(A/B/C/D) 사선 배치, 사이드바 보기·종류 필터, RiskRow 목록(위험도는 임시 공식), 상세 kv·사용 학생(ID→학생 카탈로그 이름)·수량 직접 고치기·스캔/계획 이동. 이력·보충 방법·마지막 확인은 빈 상태로 | M | 공통 SlantRow, SectionTitleRow, ItemTile(티어 배경), StudentChip34, (i) 팝오버, `AttachedSectionSpec` 기반 섹션 배치 |
| E2 | 전체 아이템 타일 | 종류별 그룹 타일(AssetImageGrid 기반), 충족 막대 색, 필터 chip, HoverFlyout | M | E1, 공통 HoverFlyout |
| E3 | 카탈로그 메타 확장(백엔드) | `planning.inventory.catalog` 행에 school/tier/family(부위·오파츠 종류)·획득처 메타 추가, `InventoryCatalogEntry.fromWire` 동시 수정 | M | 백엔드 |
| E4 | per-student/stage breakdown | shortage row 또는 document 계산에 학생별·단계별 필요량 노출, "활성 계획" 정의 결정 | M | 백엔드 + 사용자 결정 |
| E5 | 분석 화면 | 사이드바 분석 모드, 학교별 BD·노트, 장비 부위×티어 heatmap, 부족 상위 행 | L | E3, E4, 신규 차트 painter(heatmap) |
| E6 | 오파츠 scatter + 확장 | 평행사변형 scatter, 티어 토글, 확장/축소(섹션별 퇴장 + rect morph), 선택 오파츠 상세 | L | E5, morph 공통화(phase editor 패턴 추출, 실수 rect 보간) |
| E7 | 티어별 충족률 화면 | 노트/BD 학교×티어, 오파츠 종류×티어 heatmap, 요약 KPI·분포 막대 | M | E3, E5 heatmap |
| E8 | 스냅샷 이력(백엔드+UI) | 인벤토리 커밋 이력 저장·조회, KPI 델타, 상세 스파크라인, 최근 변화 섹션, 소진 예측 | L | 백엔드 이력 API, 예측 규칙 결정 |

공통 위젯(타 그룹과 공유 가능): SlantRow(.srow/.row/.plain), SectionTitleRow, KpiStrip, ItemTile(아이콘+티어 배경), StudentChip34, HoverFlyout, (i) InfoPopover, skew bar, TierHeatmap, DivergingBarRow, 섹션 morph 컨트롤러. 통계 그룹(Stats-Inventory)과 집계·차트 중복 가능성이 높으므로 집계는 `statistics_projection.dart` 쪽에 순수 함수로 두는 것을 권장 [추정].

### 사용자 확인 필요 목록(우선순위)
1. 위험도·계획 충족률·티어 충족률 집계 공식.
2. "활성 계획" = repository goals vs 시나리오 문서.
3. 사이드바 seg "아이템|장비" vs "목록|분석" 관계, "장비 설계도"/"선택권·상자" 카테고리 정의, present/workbook 처리.
4. 스캔 후보 비교 기능의 인벤토리 탭 잔류 여부.
5. 크레딧·엘리그마 보유량 출처.
6. Tiers T2 부유 섹션 처리(부착면 규칙 예외 허용 여부).
7. "이론상 전체 요구량", "과잉 재화" 화면의 범위와 시안.
8. 이력 기능(스냅샷 간 변화)을 백엔드 범위에 넣을지.
