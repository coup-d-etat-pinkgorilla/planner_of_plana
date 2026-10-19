> 오케스트레이터 조사 보고서(2026-10-06, 읽기 전용 조사). 본문의 `/mnt/user-data/uploads/v7/`·`/mnt/user-data/outputs/v7/`는 저장소 루트, `.../scratchpad/canvas2/project/`는 `docs/frontend-redesign/prototype/2026-10-05/`에 해당한다. [확인]은 grep·파싱으로 확인한 사실, [추정]은 해석이다. 결정은 `docs/frontend-redesign/decision-register.md`가 우선한다.
> 이 보고서의 백엔드 slice 'FB-10'은 워크플로에서 **FB-11**(학생 성장 계산 + 인연 선물)로 번호를 바꿨다. FB-10은 스캐너 프로토콜 추가(I 보고서)다.

# J — 성장 계산기 · 학생 한 명 (Calc-Student.dc.html)

- 대상: `canvas2/project/Calc-Student.dc.html` (2026-10-06 추가). canvas.json 제목 "성장 계산기 · 학생 한 명 — 학생 정보 인디케이터 응용 · 목표값 → 인연 선물 · 크레딧 · 재화 필요량 (계획에 저장하지 않음)", page `plan`, 배치 (x 2640, y 3024) = `Flow-1-Students-One`(x 0, y 3024) 오른쪽 [확인: canvas.json].
- 표기: **[확인]** = 파일·코드에서 직접 본 것, **[추정]** = 해석. 좌표는 2560×1392 절대값(@abs).
- script: `class Component extends DCLogic { renderVals() { return {}; } }` 뿐(로직 없음). 상호작용은 CSS `:hover/:focus`와 `:has()`로 선물 팝오버 전환만 있다 [확인].

---

## 1. 화면 목적과 섹션 구성

목적: 학생 한 명의 목표값을 스테퍼로 바꾸면 목표까지 드는 크레딧·인연 선물·성장 재화를 바로 보여 준다. 계획 문서에 저장하지 않으며, 원하면 "이 목표로 계획에 추가"로 계획 만들기 2단계에 넘긴다.

**섹션 기하가 학생 탭(Student.dc.html)과 같다** [확인: 네 `.stusec`의 left/top/width/height와 SVG path `d` 문자열이 Student.dc.html과 똑같다]. 주 탭 nav도 `학생`이 `.on`이고, 헤더 제목만 `학생` → `성장 계산기`로 바뀐다 [확인].

| 섹션 | rect @abs (x,y,w,h) | 형상 | 부착면 | 내용 |
|---|---|---|---|---|
| S1 (학생 S1 자리) | (0, 209.2, 186.7, 729.8) | 사다리꼴, 왼쪽 직선·오른쪽 80° | 왼쪽 | 레일 버튼 6개(아래 §2) |
| S2 (학생 S2 자리, 본문) | (0, 209.2, 1968.6, 1182.8) | 평행사변형(왼쪽 변 80°가 S1 아래를 감싸고 왼쪽 아래 모서리만 직각) | 아래 | 왼쪽 열 "목표 정하기", 오른쪽 열 "필요 재화", 맨 아래 큰 버튼 2개 |
| S4 (학생 S4 자리) | (1955.3, 209.2, 604.7, 352.3) | 짧은 사다리꼴, 왼쪽 80°·오른쪽 직선 | 오른쪽·위 | 학생 검색, 선택 학생 요약, "최근 계산" 초상 6개 |
| S3 (학생 S3 자리) | (1813.3, 586.7, 746.7, 780.2) | 사다리꼴, 왼쪽 80°·오른쪽 직선 | 오른쪽 | 학생 상세 인디케이터를 **목표값으로** 그림 + "현재 …" 분홍 태그 6개 |

페인트 순서(DOM): S2 → S4 → S3 → S1, 헤더·nav는 맨 끝 [확인]. 학생 탭과 같은 순서다.

### S2 내부 배치 [확인]

- **왼쪽 열 "목표 정하기"** (제목 @233,234, w740). 제목 + (i)(`목표 정하기 도움말`, 팝오버 340px: "오른쪽 아래 학생 정보는 목표값으로 그린 모습입니다. 분홍 칸이 바뀌는 칸이고, '현재 …' 표시가 지금 값입니다. 여기서 값을 바꾸거나 학생 정보의 칸을 누르면 필요 재화가 바로 다시 계산됩니다.") + 칩 `바뀌는 칸 10 · 그대로 2`.
  - 목표 행 `.tile` 760×54, 12행, 행 간격 63, 행마다 x가 −11.1씩(= 63·tan10°) S2 왼쪽 변을 따라 계단 이동: 첫 행 @(209.6,286), 마지막 행 @(87.4,979).
  - 행 구성: 항목명(118px, 13.5 w700) · 현재값(`.mut` 76px) · 화살표 · 줄이기 `.tonal` 30×30 · 목표값(17px w800, 바뀐 값은 `#f2b3ef`, 아니면 `#f4f8fb`) · 늘리기 · `MAX`(`.tonal.ghost` 30h).
  - 12행: 레벨 70→Lv.90 / 성급 ★3→★5 / 전용무기 없음→★1 · Lv.30 / EX 스킬 2→5 / 일반 스킬 5→M / 강화 스킬 5→M / 서브 스킬 4→M / 장비 1 · 모자 T7→T10 / 장비 2 · 머리핀 T7→T10 / 장비 3 · 시계 T6→T10 / 인연 12→20 / 능력 개방 0 · 0 · 0→0 · 0 · 0.
  - "바꾼 목표" 줄 @(87,1054, w730): 제목 + `.tonal` "현재값으로 되돌리기", 변화 칩 6개(레벨 +20, 성급 +2, 전용무기 ★1 · Lv.30, 스킬 +17단계, 장비 +10티어, 인연 +8), 각주 (i)색 아이콘 + "값은 게임의 단계 제한을 따릅니다 · 전용무기는 ★5 이후에 고를 수 있습니다."
- **오른쪽 열 "필요 재화"** (제목 @1029,234, w860): 제목 + 칩 `목표까지` + `.mut` "보유는 인벤토리 스캔 3일 전 기준".
  - **크레딧 타일** `.tile` @(992.5,286, 932.5×128): 아이콘 79×64, "크레딧", 30px 값 `18,420,000`, `보유 9.8M` + 분홍 칩 `부족 8.6M`, 오른쪽에 내역 막대 4줄(레벨 3.1M 39%, 스킬 7.9M 100%, 장비 4.6M 58%, 성급 · 전무 2.8M 35%; 8px 막대 `#71c7f4`, 가장 큰 값 기준 비율).
  - **인연 타일** `.tile` @(969.6,432, 929.6×112): "인연 12 → 20" + "필요 경험치 2,860 · 셋 중 하나로 채웁니다", 선택 버튼 `.gbtn` 3개: `g1` 선호 선물 (대) "추천 · 경험치 높음" ×9 (`.on`), `g2` 일반 선물 "선호 없음" ×36, `g3` 카페 · 쓰다듬기 "하루 2회" 41일.
  - **선물 팝오버** `.gpop` 520w, `#0d151f`, 꼬리 rotate45 (role=dialog): `gp1` @(995,548) `.open` 기본 표시, `gp2` @(1295,548). 표 머리 `선물 | 경험치 | 수량 | 보유`, 행 grid `40px 1fr 64px 70px 92px`. gp1 3행(선호 선물 1·2 (대) "최애 · 1개 경험치 320", 선호 선물 3 (대) "좋아함 · 1개 경험치 310"; 1,280 ×4 보유 2 부족 2 / 960 ×3 보유 0 부족 3 / 620 ×2 보유 5 충분), 합계 "×9 · 경험치 2,860 / 필요 2,860". gp2 2행(선물 상자 (일반) "보통 · 80" ×30 보유 41 충분, 간식 세트 "좋아함 · 120" ×6 보유 0 부족 6), 합계 "×36 · 3,120 / 2,860". 각주 "보유가 많은 선물부터 씁니다 · 예시 목록". g3는 팝오버 없음.
  - **성장 재화** 머리 @(971,562): 제목 + "정렬" + `.seg` 3개(필요 많은 순 / 보유 많은 순 / **부족 큰 순** on).
  - 재화 행 `.row` 919×52, 6행, 간격 58, 행마다 −10.2 계단(@949.5,606 → @898.4,896): 아이콘 49×40 · 이름 · 필요 수 · `보유 n` · `부족 n`/`충분`/`스캔 없음`. 예: 오파츠 · 안티키테라 48/31/부족 17, 설계도 · 시계 T10 90/76/부족 14, 전술 교육 BD · 밀레니엄 (최상급) 22/18/부족 4, 활동 보고서 (최상급) 64/120/충분, 기술 노트 · 밀레니엄 (최상급) 96/96/충분, 리오(무장)의 엘레프 170/스캔 없음.
  - `.plain` 접힘 줄 @(892,954, 915×30): "하급 재화 · 설계도 모자 · 머리핀 등 9종 더" + "모두 보기".
- **맨 아래 버튼**: `.btn.pri` @(34,1284, 760×64) "이 목표로 계획에 추가 / 계획 만들기 2 · 목표 정하기로 넘깁니다", `.btn.ghost` @(830,1284, 919×64) "인벤토리 · 부족 위험에서 보기 / 부족 3종 · 획득처".

### S4 내부 [확인]
검색창 @(2027.9,240.9, 495.8×49.3) "학생 이름 검색" → 선택 학생 행 @(2004.4,331.9): "리오(무장)" / "밀레니엄 · 스트라이커 · 계획에 없음" + 칩 "기준: 확정값", "학생 스캔 어제 21:40" → 구분선 → "최근 계산" + "누르면 그때 목표로 다시 엽니다" → 초상 버튼 6개(83.9×67.9, aria `리오(무장)/호시노/노아/미카/유우카/아루 최근 계산`). 학생 탭 S4의 토글 4개·적용 필터 칩·"최근 본 학생" 자리를 이 내용이 대신한다.

### S3 내부 [확인]
학생 탭 S3와 같은 컨테이너(초상 카드 + PLAN 배지, LEVEL+학교, Position/Class/Weapon, SKILL SUMMARY, EQUIPMENT, Ability Release, 심상개화, STATS, 인연 삼각형)를 **목표값**으로 채웠다: LEVEL `Lv. 90`, Weapon `Lv. 30`, EX `5/5`, Normal/Passive/Sub `M`, 장비 3칸 `T10 Lv.70/70`, 애장품 `-`, Ability `HP 0 | ATK 0 | HEAL 0`, 인연 게이지 `12` + `→20`(B안 빗금, `pattern id=hat56`). 그 위에 분홍 pill(bg `#f2b3ef`, 글자 `#2a1330`, 13px w800, 22h) 6개: "현재 70"(@2421,599), "현재 없음 · ★1 필요"(@2290,780), "현재 ★3 → ★5 · 전무 ★1"(@1939,834), "현재 2 · 5 · 5 · 4"(@2175,884), "현재 T7 · T7 · T6"(@2154,1005), "현재 12 → 20"(@2401,1334).

### 헤더 [확인]
제목 "성장 계산기", 부제 "학생 한 명 · 목표까지 필요한 인연 선물 · 크레딧 · 재화를 바로 계산 (계획에는 저장하지 않음)", 연결 칩 "연결됨", 개발 상태 버튼. 학생 탭 헤더("학생 / 학생 목록과 육성 상태")와 같은 틀이다.

---

## 2. 사용 요소

| 이름(제안) | 시안 근거 | 반복 | 비고 |
|---|---|---|---|
| **CalcRailButtons** | S1 버튼 6개(학생 S1과 rect가 같고 aria만 다름) [확인] | 1세트 | `확정값 기준`(22.4,253, 63.9×49.3) + `직접 입력`(83.6,253, 72.6×49.3) = 학생 S1의 리스트/그리드 보기 토글 자리, `빠른 목표 고르기`("완전 육성", 22.4,338.8, 118.7×49.3) = 정렬 드롭다운 자리, `이 목표로 계획에 추가`(22.4,424.6, 103.5×132.5) = "포커스 학생으로 계획 열기" 자리, `학생 스캔으로 현재값 갱신`(22.4,593.6, 73.7×132.5) = "학생 스캔 열기" 자리, `현재값으로 되돌리기`(22.4,762.7, 43.9×132.5) = "필터 열기" 자리 |
| **GoalStepperRow** | `.tile` 760×54 + `.tonal` 줄이기/늘리기 + `.tonal.ghost` MAX | 12 | 80° 계단 행. 목표 값 색으로 변경 여부 표시 |
| **ChangedGoalChips** | "바꾼 목표" 칩 6개 + 되돌리기 | 1 | 클라이언트 계산(현재와 목표의 차) |
| **CreditBreakdownTile** | 크레딧 `.tile` + 4줄 막대 | 1 | 큰 값 + 보유/부족 칩 + SkewBar 계열 막대 |
| **BondGiftTile** | 인연 `.tile` + `.gbtn` 3개 | 1 | 셋 중 하나 고르기(on 상태 = 분홍 inset 테두리) |
| **GiftOptionPopover** | `.gpop` (role=dialog, 꼬리) | 2 | 선물 표(아이콘·이름·선호도·1개 경험치·경험치 합·수량·보유·부족/충분) + 합계 + 각주 |
| **ResourceNeedRow** | `.row` 919×52 | 6 + 접힘 | 아이콘·이름·필요·보유·부족/충분/스캔 없음, 80° 계단 |
| **SortSegment** | `.seg` 3개 | 1 | FE2-b `SkewSegmented` |
| **MoreRow** | `.plain` "9종 더 · 모두 보기" | 1 | 펼치기 |
| **BigActionButton** | `.btn.pri`/`.btn.ghost` 64h 2줄 라벨 | 2 | 기존 BA 버튼 2줄 변형 |
| **CurrentValueTag** | S3 위 분홍 pill "현재 …" | 6 | 새 오버레이(인디케이터 블록 옆에 붙임) |
| **RecentCalcStrip** | S4 초상 버튼 6개 | 1 | FE3-c "최근 본 학생" 줄과 같은 꼴(제목·부제만 다름) [추정] |
| InfoPopover (i) | "목표 정하기 도움말" | 1 | FE2-c |
| BaChip | `.chip.pk` 3곳 | 3 | FE2-b |

스크롤: 목표 12행·재화 6행+접힘이 섹션 안에 다 들어가게 그려져 있어 스크롤바·포그가 없다 [확인]. "모두 보기"로 9종이 펼쳐지면 재화 목록은 스크롤이 필요하다(높이 계산상 아래 버튼과 겹침) [추정].

---

## 3. 상태·상호작용

- 변형 artboard 없음. 한 장이 "리오(무장) · 확정값 기준 · 목표 10칸 바뀜 · 선호 선물(대) 고름(팝오버 열림)" 상태를 보여 준다 [확인].
- CSS 상호작용 [확인]: `.gbtn:hover/:focus-visible/.on` → 분홍 배경 + inset 테두리. `body:has(#g1:hover|:focus) #gp1` 표시, `#g2`에 hover/focus하면 gp2를 띄우고 gp1을 숨김. `.gpop:hover`도 열림 유지. g3(카페)는 팝오버 없음.
- 시안이 문장으로 말하는 동작 [확인]: (i) "값을 바꾸거나 학생 정보의 칸을 누르면 필요 재화가 바로 다시 계산" → 스테퍼 변경과 S3 칸 누르기가 둘 다 재계산 트리거. S4 "누르면 그때 목표로 다시 엽니다". 아래 버튼 부제 "계획 만들기 2 · 목표 정하기로 넘깁니다".
- 애니메이션: 정의 없음. 학생 탭과 같은 4섹션이므로 학생 목록 → 계산기 전환은 S2·S1·S4 내용 교체(S3는 같은 자리 유지)로 보는 것이 자연스럽다 [추정].
- 시안 안의 예시 수치 불일치 [확인]: 칩 "바뀌는 칸 10 · 그대로 2"이지만 12행 중 값이 그대로인 행은 능력 개방 1개다. 목표값이 흰색인 행은 전용무기·인연·능력 개방 3개인데 "바꾼 목표" 칩에는 전용무기·인연이 들어 있다. "스킬 +17단계"는 EX+3·일반+5·강화+5·서브+6 = 19와 다르다. gp1은 "보유가 많은 선물부터"라는 각주와 달리 경험치 순으로 썼다. FD-025에 따라 예시 수치는 구현 근거로 쓰지 않는다. 다만 **흰/분홍 의미**와 **선물 배분 규칙**은 정해야 한다(FD-166, FD-164).

---

## 4. 현재 코드 대응

| 시안 요소 | Dart 위치(확인한 이름) | 분류 | 근거 |
|---|---|---|---|
| 4섹션 기하 | `ui/widgets/student_section_layout.dart`(`studentContainerPath`, `studentSectionRect`), `ui/studio/student_studio_layout.dart` | **그대로 재사용** | path `d`가 Student.dc와 같음 |
| S3 인디케이터 | `_StudentStatusIndicators(canvasSize, student, values)`, `StudentLevelStatus`, `StudentSkillStatus`, `StudentEquipmentStatus`, `StudentAbilityStatus`, `StudentPotentialStatus`, `_StudentCombatStatus`, `StudentStarStatus(selectedValues)` | **재사용**(values에 목표 맵을 넣음) | `values`만 받는 구조라 목표 맵을 넣으면 그대로 그려진다 [확인: 생성자] |
| 인연 게이지 12→20 | `StudentBondStatus(bondRank, outerPath)` | **FE3-b 결과 재사용** | FE3-b가 `targetRank`를 추가한다. 계산기에서는 목표 = 계산기 목표값(FD-049의 활성 계획 원천과 다름 → 위젯은 목표를 값으로만 받게 해야 함) |
| "현재 …" 분홍 태그 | 없음 | **신규** `CurrentValueTag` 오버레이 | — |
| S1 버튼 | `_StudentActionButton`, `_StudentViewModeButtons`, `_StudentSortDropdown` (student_section_layout.dart 1483~1520행) | **수정**(모드별 버튼 세트) | 같은 container id 자리에 다른 버튼 |
| S4 검색 | FE3-c의 S4(검색 + 최근 본 학생) | **재사용 + 수정** | 선택 학생 요약 행·"최근 계산" 줄은 신규 |
| 목표 스테퍼 | `plan_element_builder.dart` `_CompactTargetStepper`, `_MaxBadge`, `_StarTargetStrip`, `Widget _stepper(label, key)` | **FE2-b `Stepper`+`MaxBadge` 추출본 재사용** | 시안 행은 가로 1줄형(라벨·현재·→·−·값·+·MAX)이라 행 레이아웃은 신규 `GoalStepperRow` |
| 목표 제약 | `ui/models/planning_growth_rules.dart` `planElementTargetMinimums/Maximums`, `normalizePlanningGrowthTargets(changedKeys, hasFavoriteItem)`, `studentStarMaximumBondRanks`, `favoriteItemUnlockBondRanks` | **그대로 재사용** | 각주 "전용무기는 ★5 이후"는 `studentStar < 5 → weapon 0`과 같다 [확인] |
| 현재값 → 목표 초기값 | `plan_element_builder.dart` `planElementCurrentTargets(PlanningStudentSeed)`, `planStudentHasFavoriteItemMetadata` | **재사용** | 미보유 학생 초기값까지 처리 |
| 직접 입력 필드 | `ui/pages/student_page.dart` `_studentFields`(15필드, min/max), `_draftValues()` | **참고/일부 재사용** | "직접 입력" 기준 모드(FD-168) |
| 계획으로 넘기기 | `PlanningStudentSeed{handoffId, studentId, metadata, currentValues, owned}`(planning_models.dart), `StudentPage.onAddToPlan` → `AppShell._addStudentToPlan` → `PlanningPage(initialSeed)` | **수정** | seed에 목표 필드가 없다 [확인] → `targets` 추가 필요(FD-171) |
| 크레딧·재화 계산 | `AppService.calculatePlan` → `planning.plan.calculate`(totals), `calculateShortages` → `planning.plan.shortages`(행: resource_key·required·owned·shortage·affected·resolved), `PlanningDocumentService.calculatePlanningDocument` → `planning.document.calculate`(stage_results[].cost/resources) | **재사용(조합)** 또는 FB-11 | FD-162 |
| 재화 아이콘 | `ui/models/planning_resource_assets.dart` `planningResourceIconAsset(category, itemId)`(`present` → `assets/item_icons/presents`) | **재사용** | 선물 아이콘도 이미 경로가 있다 [확인] |
| 재화 분류 | `plan_section_layout.dart` `PlanResourceCategory`(… `gift('선물')`), 키에 `present`/`gift`가 있으면 gift | 참고 | UI 쪽에는 선물 분류 자리가 이미 있다 |
| 인연 선물 타일·팝오버 | 없음(제품 코드). 개발 도구 `developer_tools_main.dart` `_giftAffinityStrip`, `_giftCard`만 있음 | **신규** | §5 |
| 새 화면 셸 | 없음 | **신규** `GrowthCalculatorView`(학생 탭 모드) | FD-160 |

폐기 대상: 없음.

---

## 5. 데이터 요구

### 5.1 그대로 되는 것 [확인]
- 학생 현재값·메타: `AppService.getStudent`, `listStudents`(`StudentCatalogEntry`), repository 학생 상태.
- 목표 제약·정규화: `planning_growth_rules.dart`(클라이언트).
- 목표까지 총 크레딧: `planning.plan.calculate` totals `credits` (mock 키: `credits, level_exp, equipment_exp, weapon_exp, star_materials, equipment_materials, level_exp_items, equipment_exp_items, weapon_exp_items, skill_books, ex_ooparts, skill_ooparts, favorite_item_materials, stat_materials, stat_levels, warnings`). 목표 1명짜리 임시 plan/document로 부르면 된다.
- 재화별 필요·보유·부족·스캔 없음: `planning.plan.shortages`의 `InventoryShortageRow`(`owned == null` → "스캔 없음")가 시안 행과 1:1. 또는 임시 1페이즈 1단계 문서의 `planning.document.calculate` `stage_results[].resources`(mock은 빈 배열이라 필드 모양은 미확인).
- 선물 보유 수량: 인벤토리 스캔 프로필 `InventoryScanProfile.presents`, 카탈로그 category `present`, 아이콘 경로 [확인: scanner_service.dart, planning_resource_assets.dart].
- "바꾼 목표" 칩, "바뀌는 칸 n", 정렬 3종: 클라이언트 계산.

### 5.2 안 되는 것 / 출처 미정
| 값 | 현재 상태 | 필요한 것 |
|---|---|---|
| **크레딧 내역**(레벨/스킬/장비/성급·전무) | totals에 `credits` 합계 하나뿐 [확인] | (a) 범주별 부분 목표로 `calculatePlan`을 4번 더 부르기: 정규화가 다른 항목을 끌어올리면(예: 장비 칸 개방 → 레벨) 중복 계산이 생김 [추정] (b) 백엔드가 범주별 크레딧을 돌려줌(FB-11) |
| **크레딧 보유**(보유 9.8M) | 통화가 스캔·카탈로그에 없음 | FD-096(FB-3)과 같은 문제. 그전에는 "보유 모름" 빗금 |
| **인연 랭크 → 누적 경험치 표**(12→20 = 2,860) | Dart·프로토콜 어디에도 없음 [확인: `bond_exp`·`favor_exp`·인연 경험치 grep 0건]. `planning_growth_rules.dart`에는 랭크 상한(`studentStarMaximumBondRanks`)과 애용품 개방 랭크(`favoriteItemUnlockBondRanks`)만 있다 | 백엔드 메타데이터 신설 |
| **현재 랭크 안의 진행 경험치** | 학생 상태에 `bond_rank`만 있다 [확인: `_studentFields`, mock fixture] | 없음 → "현재 랭크 시작 기준" 가정과 표기 필요 |
| **선물 1개 경험치·선호도 배수** | 제품 프로토콜에는 없다. 단 **백엔드 정규 메타데이터에는 있다**: 개발 도구가 `metadata.schaledb.preview/apply`로 선물 카탈로그(`gifts`: `id`, `name`, `exp_value`, `icon_asset`)와 학생별 `special_gifts`/`preferred_gifts`(`name`, `points`, `multiplier`, `icon_asset`), `favor_item_tags`/`favor_item_unique_tags`를 다룬다 [확인: developer_tools_main.dart 426~474·1022~1290행]. almanac `canonical-metadata.md`: catalog 영역 `gift_affinities`("normalized preference and unique tag lists keyed by canonical ID"), "gift item definitions remain separate bounded catalogs". `developer-tools.md`: "Apply atomically updates the three student fields and the separate four-field gift catalog", "Student bond-stat fields are intentionally not part of this sync" [확인] | `planning.*` 쪽으로 노출하거나 백엔드에서 계산. `StudentCatalogEntry.fromWire`·`InventoryCatalogEntry.fromWire`는 키 집합이 정확히 맞아야 통과하는 strict 검증이라 필드를 붙이려면 Dart DTO도 같이 고쳐야 한다 [확인] |
| **카페 쓰다듬기 경험치·하루 횟수**(41일) | 없음 | 백엔드 상수(메타데이터) |
| 선물 배분 결과(×9, 부족 2 …) | 없음 | 계산 위치 결정(FD-163), 배분 규칙(FD-164) |
| "보유는 인벤토리 스캔 3일 전 기준", "학생 스캔 어제 21:40" | 시각 필드 없음 | FB-2(FD-041). 그전에는 숨김 |
| "계획에 없음" | 활성 계획 문서 소속 | FB-1(FD-026). 그전에는 goals v1으로 판정 |
| "부족 3종 · 획득처" | 획득처 없음 | FB-3(FD-102) |
| 최근 계산 6개 | 없음 | 앱 실행 동안 메모리(FD-170) |

**인연 선물 계산이 지금 어디에 있는가 (질문 2 답)**: 제품 코드(AppService·`planning_protocol_client`·`process_app_service`·`mock_app_service`)와 계산 응답 키 어디에도 없다 [확인]. 선물 데이터는 백엔드 정규 메타데이터(`gift_affinities` + 선물 카탈로그)에만 있고, 이것을 읽고 쓰는 쪽은 별도 프로세스 개발 도구(`tools.developer_tools`, `metadata.schaledb.*`)뿐이다. 랭크별 경험치 표와 쓰다듬기 상수는 로컬 근거 어디에도 없다(백엔드 소스가 로컬에 없어서 백엔드 내부 존재 여부는 확인 불가). `PlanResourceCategory.gift`가 UI 분류에 있지만, 계산 응답이 선물 자원을 내보낸다는 근거는 없다 [확인].

---

## 6. 사용자 확인이 필요한 모호점

1. **진입점** (질문 1): 캔버스 page는 `plan`(계획 만들기 보드 아래, 한 명 모드 옆)인데, 화면 자체는 nav `학생` on, 학생 탭과 같은 4섹션, S1 버튼 자리 대응이다. 학생 탭 S1에는 계산기 버튼이 없다(W-Student-Actions 6개 그대로) [확인]. 계획 탭 쪽에도 계산기로 가는 버튼은 시안에 없다. → **시안만으로는 진입점이 정해지지 않는다**(FD-160).
2. 계산기에서 학생 목록으로 **돌아가는 길**이 그려져 있지 않다(S1에 목록 버튼 없음, 헤더에 뒤로 없음) (FD-161).
3. **계산 경로**: 임시 문서 계산·plan 계산·shortages 중 어느 조합을 쓸지, 크레딧 내역을 어떻게 낼지 (FD-162).
4. **인연 선물 데이터**: 경험치 표·쓰다듬기 상수 신설, 현재 랭크 안 진행도 부재 (FD-163).
5. **선물 배분 규칙**: 각주("보유 많은 것부터")와 예시(경험치 순)가 다르다 (FD-164). 고른 선물 옵션(g1 on)이 아래 재화 목록이나 "부족 n종"에 들어가는지도 미정 (FD-165).
6. **목표 행 범위**: 장비 레벨·애장품 행이 없고, S3는 T10을 `Lv.70/70`으로 그린다. 그런데 `normalizePlanningGrowthTargets`는 티어를 올려도 장비 레벨을 올리지 않는다 [확인]. 전용무기는 ★와 Lv이 한 행, 능력 개방은 세 값이 한 행이다. Flow-2-Goals 단계 카드와 행 구성이 다르다 (FD-166).
7. **S3 칸 누르기** 동작 미정 (FD-167). **흰/분홍 목표값** 의미가 예시와 맞지 않는다(§3).
8. **확정값 기준 / 직접 입력**의 의미와 직접 입력값 저장 여부 (FD-168).
9. **빠른 목표 고르기** 목록("완전 육성" 외) (FD-169).
10. **"이 목표로 계획에 추가"**: seed에 목표 필드가 없다. 이미 계획 초안이나 활성 계획에 있는 학생일 때 동작 (FD-171).
11. **"인벤토리 · 부족 위험에서 보기"**: 인벤토리 부족 위험은 활성 계획 기준이라 계산기의 부족 재화와 집합이 다르다 (FD-173). 아직 데이터가 없는 표기(스캔 시각, 크레딧 보유, 계획 소속)는 FD-172.
12. "계획에 저장하지 않음"은 FE4 초안과도 다르다. 계산기 목표는 활성 계획(FB-1)·FE4 초안 어디에도 쓰지 않는 휘발 상태다. 학생 탭 인연 게이지(FE3-b)는 계속 활성 계획 목표를 보여 주고, 계산기 안에서만 계산기 목표를 보여 준다 [추정. FD-049와 충돌하지 않게 하려면 이 해석이 필요] (FD-160 권장안에 포함).

---

## 7. 핵심 질문별 답

1. **진입점**: 시안 근거 없음(위 6-1). 권장은 **학생 탭 안의 모드**다. 학생 S1 "포커스 학생으로 계획 열기" 자리를 "성장 계산기 열기"로 바꾸고, 계산기 S1의 같은 자리에 "이 목표로 계획에 추가"를 둔다. 이렇게 하면 학생 → 계획 흐름(Flow 안내 "학생 탭 *이 학생 목표 정하기* → 2단계")이 계산기를 거쳐 목표까지 실어 나른다. 보조 진입으로 계획 만들기 1단계 한 명 모드 C 패널에 "계산기로 보기" 링크를 두는 것은 선택 사항이다(FD-160).
2. **입력·출력**: 입력은 학생 1명, 현재값(확정값 또는 직접 입력), 목표 12항목, 인벤토리 보유다. 출력은 총 크레딧(+보유·부족·범주별 내역), 인연 필요 경험치와 선물 3안(선호 대형 / 일반 / 쓰다듬기 일수, 안마다 선물별 수량·보유·부족), 성장 재화별 필요·보유·부족이다. 지금 프로토콜로 되는 것은 총 크레딧과 재화별 필요·보유·부족이다. 안 되는 것은 크레딧 내역, 크레딧 보유, 인연 경험치 표, 선물 경험치·선호 배수 노출, 쓰다듬기 상수, 랭크 안 진행도다(§5.2).
3. **저장 관계**: 계산기 상태는 휘발 상태다(최근 계산 6개만 앱 실행 동안 유지). "이 목표로 계획에 추가"는 FE4 계획 만들기 2단계로 seed(현재값 + 목표)를 넘기는 **유일한 쓰기 경로**이고, 실제 저장은 FE4-e/FB-1이 한다. 학생 탭 "이 학생 목표 정하기"(Flow 안내 문구)와 한 명 모드 "이 학생 목표 정하기"는 목표 없이 2단계를 연다. 계산기 버튼은 같은 2단계를 1단계 목표가 채워진 상태로 연다.
4. **재사용 범위**: S3 인디케이터 전부(FE3) + 인연 B 게이지(FE3-b, 목표를 값으로 받게), S4 검색(FE3-c), 목표 정규화·한계(`planning_growth_rules.dart`), `planElementCurrentTargets`, FE2-b `Stepper`/`MaxBadge`/`SkewSegmented`/`BaChip`/`RailButton`, FE2-a `DiagonalRow`(.tile/.row/.plain), FE2-c `InfoPopover`/`AnchoredFlyout`(선물 팝오버), FE2-d `ItemIconTile`/`SkewBar`, FE4-a 초안 계산 컨트롤러의 디바운스 계산(있으면). 신규는 `GrowthCalculatorView`(모드 셸), `GoalStepperRow`, `ChangedGoalChips`, `CreditBreakdownTile`, `BondGiftTile`+`GiftOptionPopover`, `ResourceNeedRow` 목록(정렬·접힘), `CurrentValueTag`, `RecentCalcStrip`, 계산기 상태 컨트롤러.
5. **워크플로 위치**: 아래 §8.

---

## 8. slice 제안

| slice | 범위 | 난이도 | 선행 | gate |
|---|---|---|---|---|
| **FE3-f 성장 계산기 골격·목표·재화** | 학생 탭 계산기 모드(진입·복귀, S1 버튼 세트, 헤더 제목 교체), S2 왼쪽 목표 12행(GoalStepperRow + 정규화 + MAX + 되돌리기 + 바꾼 목표 칩), S3 목표값 인디케이터 + CurrentValueTag + 인연 게이지 목표, S4 선택 학생 행 + 최근 계산 6개, 오른쪽 크레딧 타일(합계, 내역은 FD-162 결과) + 성장 재화 목록(정렬·접힘·스캔 없음), 디바운스 재계산. 인연 타일은 "필요 경험치 계산 준비 중" 빈 상태 | M | FE3-a~c(인디케이터·게이지·S4), FE2-a~d, FD-160·FD-162·FD-166 | Calc-Student 검수(인연 타일 제외), `student_studio_layout_test`에 모드 전환 테스트 |
| **FB-11 학생 성장 계산 + 인연 선물** | 백엔드 메타데이터에 인연 랭크별 누적 경험치 표·쓰다듬기 상수 추가, 선물 카탈로그(`exp_value`)·`gift_affinities` 배수로 선물 3안 계산, 범주별 크레딧(FD-162가 (b)이면). 새 메서드(가칭 `planning.student.calculate` 또는 `planning.bond.calculate`), `contracts/`, Dart DTO, `MockAppService`, 계약 테스트 | M | FD-162·FD-163 | 계약·E2E 테스트, 개발 도구 SchaleDB 동기화 경로 회귀 0 |
| **FE3-g 인연 선물 타일** | BondGiftTile(3안, on 상태), GiftOptionPopover(AnchoredFlyout, hover·focus·tap 고정), 선물 아이콘·보유·부족, 배분 규칙 | S | FE3-f, FB-11, FD-164·FD-165 | Calc-Student 인연 타일·gp1/gp2 검수 |
| **FE4-g 계산기 → 계획 넘김** | `PlanningStudentSeed`에 `targets` 추가, FE4 2단계가 seed 목표로 1단계를 채워 열기, 이미 초안·활성 계획에 있는 학생 처리, S4 "계획에 없음/있음" 표기(활성 문서) | S | FE4-c, FB-1(표기), FD-171 | `planning_page_test`에 seed 목표 넘김 테스트 |
| (후속) 계산기 보조 연결 | "인벤토리 · 부족 위험에서 보기" navigation intent, 스캔 시각 표기, 크레딧 보유 | S | FE6-a·FE7-d(이동), FB-2(시각), FB-3/FD-096(크레딧 보유) | 각 slice gate에 묶음 |

순서 제안: Lane A `FE3-a~c → FE3-f → (FB-1 → FE4 …) → FE4-c → FE4-g`. FB-11은 백엔드 lane에서 FE3-f와 병렬로 진행하고, 끝나는 대로 FE3-g를 붙인다. FE3-f는 FB-1 없이 동작한다(계획 소속은 goals v1으로 임시 판정, FD-027과 같은 방식). 워크플로 문서에는 FE3 표에 FE3-f·FE3-g 행, FE4 표에 FE4-g 행, "FB-4 ~ FB-9" 표에 FB-11 행을 넣고, artboard 지도의 계획 만들기 절(또는 학생 절, FD-160 결과에 따라)에 Calc-Student 행을 추가한다.

---

## 9. 결정 대장 추가 초안 (FD-160~)

| FD | 질문 | 선택지 | 권장안 | 상태 | 막는 slice |
|---|---|---|---|---|---|
| FD-160 | 성장 계산기는 어디에 있고 어디서 들어가는가? (캔버스 page `plan`, 화면은 nav `학생` on·학생 4섹션과 같은 기하, 진입 버튼은 시안에 없음) | (a) 학생 탭 모드: 학생 S1 "포커스 학생으로 계획 열기" 자리를 "성장 계산기 열기"로 바꾸고, 계산기 S1 같은 자리 = "이 목표로 계획에 추가" (b) 학생 탭 모드 + 학생 S1에 7번째 버튼 추가, 기존 계획 열기 유지 (c) 계획 탭 계획 만들기 1단계 한 명 모드 C 패널에서 진입(계획 탭 안의 화면) | (a). 기하·nav·버튼 자리가 학생 탭과 1:1이고, 학생 → 계획 경로가 목표를 싣고 이어진다. 계산기 목표는 휘발이며 학생 탭 인연 게이지(FD-049 활성 계획 목표)와 섞지 않는다. 한 명 모드 C에 보조 링크는 워커 재량 | 열림 | FE3-f |
| FD-161 | 계산기에서 학생 목록으로 어떻게 돌아가는가? | (a) 헤더 제목 옆 "← 학생" 복귀 칩(FE7-d 복귀 칩과 같은 위젯) + Esc + 주 탭 `학생` 다시 누르기 (b) S1 첫 버튼 쌍을 목록/계산기 토글로 | (a). 시안 S1의 첫 버튼 쌍은 "확정값/직접 입력"이라 자리가 없다 | 워커 재량 | FE3-f |
| FD-162 | 계산기의 크레딧·재화 숫자는 어떤 호출로 얻고, 크레딧 범주별 내역은 어디서 오는가? | (a) 기존 조합: 임시 1페이즈 1단계 문서 `planning.document.calculate`(재화 행) + 크레딧 내역은 숨김 (b) FB-11에 단일 학생 계산 메서드(가칭 `planning.student.calculate`): totals + 범주별 크레딧 + `InventoryShortageRow` 모양 재화 행 + 인연 블록을 한 번에 (c) `calculatePlan` + `calculateShortages`(goals v1) + 범주별 부분 목표로 `calculatePlan` 4회 | (b). 디바운스 1회 호출로 끝나고, 범주별 크레딧을 정규화 중복 없이 백엔드 계산 코어에서 나눌 수 있다. 활성 계획 수치가 아니므로 FD-026(문서 계산 단일 원천)과 충돌하지 않는다. FB-11 전에는 (a)로 그리고 내역 막대를 숨긴다 | 열림 | FE3-f(내역 막대), FB-11 |
| FD-163 | 인연 선물 계산(필요 경험치, 선물 3안)의 데이터와 계산 위치는? (경험치 표·쓰다듬기 상수 없음, 선물 `exp_value`·`gift_affinities`는 백엔드 메타데이터에만 있고 개발 도구 전용, 랭크 안 진행도 없음) | (a) 백엔드 계산(FB-11): 메타데이터에 랭크별 누적 경험치 표·쓰다듬기 상수 추가, 선물 카탈로그·affinity 배수·인벤토리 `present` 보유로 3안 계산, 현재 경험치는 "현재 랭크 시작" 가정을 응답에 표기 (b) 메타데이터를 카탈로그로 노출하고 Flutter가 계산 (c) 이번 범위 제외: 인연 타일에 필요 랭크만 표시 | (a). runtime-boundaries.md "Python backend는 계산을 소유" 원칙과 맞고, 선물 데이터가 이미 백엔드 정규 catalog에 있다. 랭크 안 진행도는 학생 스캔이 읽게 되면 후속으로 반영 | 열림 | FB-11, FE3-g |
| FD-164 | 선물 안마다 수량을 어떻게 배분하는가? (각주 "보유가 많은 선물부터" vs 예시 gp1 경험치 순) | (a) 보유 선물을 보유 많은 순으로 먼저 쓰고, 모자라면 1개 경험치가 가장 높은 선물로 부족분을 채움 (b) 경험치 높은 순으로 채우고 보유는 표시만 (c) 보유 무시, 최소 개수 | (a). 각주가 명시 규칙이고, "부족 n"이 실제로 구해야 할 수량이 된다. 예시 수치는 FD-025로 무시 | 워커 재량 | FE3-g |
| FD-165 | 고른 선물 안(g1 on)은 화면의 다른 숫자에 반영되는가? | (a) 반영 안 함: 고르기는 팝오버 고정·강조만, 성장 재화 목록·"부족 n종"은 성장 재화만 (b) 고른 안의 부족 선물을 성장 재화 목록과 "부족 n종"에 넣음 | (a). 시안 재화 목록에 선물 행이 없고 "부족 3종"이 오파츠·설계도·BD 3행과 맞는다 | 워커 재량 | FE3-g |
| FD-166 | 목표 행 구성은 시안 12행 그대로인가? (장비 레벨·애장품 행 없음, S3는 T10을 Lv.70/70으로 그림, 전용무기는 ★+Lv 한 행, 능력 개방은 3값 한 행. 현 `normalizePlanningGrowthTargets`는 티어를 올려도 장비 레벨을 올리지 않음) | (a) 12행 유지. 장비 티어를 올리면 장비 레벨 목표 = 그 티어 최대 레벨(계산기 한정 규칙), 전용무기 행은 ★ 단위로 움직이고 Lv은 그 ★ 최대, 능력 개방 행은 누르면 HP/ATK/HEAL 3스테퍼 플라이아웃, 애장품은 계산하지 않음 (b) Flow-2 단계 카드처럼 장비 레벨·애장품·능력치 개별 행 추가 (c) (a)이되 애장품 행 추가 | (a). 시안·S3 표시와 맞고 "한 화면에 다 보이는 계산기" 의도를 지킨다. 계획으로 넘길 때는 같은 목표 맵을 그대로 넘기므로 FE4 2단계에서 세부 조정 가능 | 열림 | FE3-f |
| FD-167 | S3 학생 정보 칸을 누르면 무엇을 하는가? ((i) "칸을 누르면 필요 재화가 바로 다시 계산") | (a) 그 항목 목표를 현재값 ↔ 직전 목표로 토글(분홍 = 바뀌는 칸) (b) 그 항목을 MAX로 (c) 왼쪽 해당 스테퍼 행으로 포커스만 | (a). 재계산 문구와 "바뀌는 칸 n · 그대로 m" 칩을 함께 설명한다. 바뀐 칸은 목표값을 분홍, 그대로인 칸은 흰색으로 통일(시안 흰/분홍 예시 불일치 해소) | 워커 재량 | FE3-f |
| FD-168 | S1 "확정값 기준 / 직접 입력"은 무엇인가? | (a) 현재값 출처 토글: 확정값 = repository 학생 상태, 직접 입력 = 목표 행의 "현재" 칸이 스테퍼로 바뀌어 고칠 수 있음(저장 안 함, 미보유 학생도 계산) (b) 직접 입력 = 학생 탭 기존 `_studentFields` 편집으로 저장까지 | (a). 화면 부제 "계획에는 저장하지 않음"과 같은 휘발 원칙. S4 칩 "기준: 확정값"도 같이 바뀜 | 워커 재량 | FE3-f |
| FD-169 | "빠른 목표 고르기"(완전 육성)에 무엇이 들어가는가? | (a) 고정 항목(완전 육성 = 전 항목 MAX, 레벨·장비만 MAX, 스킬만 MAX) + 단계 프리셋 마지막 단계(FD-074에서 영속화되면) (b) 완전 육성만 | (a). Flow-2 "한 번에 MAX"와 같은 개념이고, 프리셋 연결은 FD-074 결과를 따른다 | 워커 재량 | FE3-f |
| FD-170 | "최근 계산"은 무엇을 몇 개, 얼마나 오래 담는가? | (a) 학생 + 기준 + 목표 맵, 6개, 앱 실행 동안만(FD-061과 같음), 누르면 그 목표로 다시 열기 (b) 프로필별 영속 | (a). FD-061과 같은 수명이라 저장소 신설이 필요 없다 | 워커 재량 | FE3-f |
| FD-171 | "이 목표로 계획에 추가"는 무엇을 넘기고, 이미 계획에 있는 학생이면 어떻게 하는가? (`PlanningStudentSeed`에 목표 필드 없음) | (a) seed에 `targets` 추가. 계획 만들기 2단계를 그 학생 1단계 = 계산기 목표로 열고, 진행 중 초안이 있으면 학생을 덧붙임. 활성 계획에 이미 있으면 그 학생 마지막 단계 뒤 새 단계로 (b) 1단계로만 넘기고 목표는 버림 | (a). 버튼 부제 "계획 만들기 2 · 목표 정하기로 넘깁니다"와 맞고, 단계 누적 snapshot 계약(plan-element-builder-lessons)과 충돌하지 않는다 | 워커 재량 | FE4-g |
| FD-172 | 아직 데이터가 없는 표기(인벤토리 스캔 시각, 학생 스캔 시각, 크레딧 보유, 계획에 없음)는 어떻게 그리는가? | — | 스캔 시각 2개는 FB-2 전까지 숨김(FD-041), 크레딧 보유는 FD-096 결과 전까지 "보유 모름" 빗금(부족 칩 숨김), "계획에 없음/있음"은 FB-1 전에는 goals v1 기준(FD-027 방식) | 워커 재량 | FE3-f |
| FD-173 | "인벤토리 · 부족 위험에서 보기 / 부족 3종 · 획득처"는 어디로 가는가? (인벤토리 부족 위험은 활성 계획 기준) | (a) 인벤토리 탭을 열고 계산기 부족 재화 키를 강조 필터로 넘김(FE7-d navigation intent 재사용) (b) 계산기 안에서 획득처 플라이아웃(FB-3 보충 방법) (c) FE6-a·FE7-d 전까지 버튼 숨김 | (a). 연결 수단이 생기기 전에는 (c) | 워커 재량 | FE3-f(숨김), 후속 연결 |
