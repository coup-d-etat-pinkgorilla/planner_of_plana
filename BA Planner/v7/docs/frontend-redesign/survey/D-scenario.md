> 오케스트레이터 조사 보고서(2026-10-05, 읽기 전용 조사). 본문의 `/mnt/user-data/uploads/v7/`는 저장소 루트, `.../scratchpad/canvas/project/`는 `docs/frontend-redesign/prototype/2026-10-05/`에 해당한다. [확인]은 grep·파싱으로 확인한 사실, (추정)·[추정]은 해석이다. 결정은 `docs/frontend-redesign/decision-register.md`가 우선한다.

# 그룹 D — 시나리오 (목록 관리 · 열어 보기 · 나란히 비교) 매핑 조사

조사 대상 artboard 5개(모두 `is_interactive: true`, canvas page `scenario`, 2560×1392):
`Scenario-List`, `Scenario-Detail-Bottleneck`, `Scenario-Detail-Phase`, `Scenario-Detail-All`, `Scenario-Compare`.

표기: **[확인]** = 파일에서 grep/추출로 직접 확인, **[추정]** = 확인한 사실에서 유추.

---

## 0. 핵심 질문 답

### 0-1. 시나리오가 상단 탭으로 독립했는가? → **아니다 [확인]**
- 5개 artboard 모두 `<nav class="nav" aria-label="주 탭">`의 `.nt.on`이 **"계획"**이다. 탭 목록은 `홈 / 학생 / 계획 / 인벤토리 / 전술대항전 / 통계 / 스캔 / 설정` 8개로 `AppSection.primary`(ui/app_section.dart)와 같고 "시나리오" 탭은 없다.
- 헤더 문구는 `계획` / `육성 목표와 필요 재화 · 시나리오`다. 현재 `AppSection.plan`의 description은 `'육성 목표와 필요 재화'`이므로 문구만 바뀐다(`· 시나리오` 추가).
- `<title>`도 모두 `계획 · 시나리오 목록`, `계획 · 시나리오 보기 (병목)`처럼 `계획 · …`으로 시작한다.
- canvas.json의 `page: "scenario"`("시나리오")는 **캔버스 정리용 페이지 구분일 뿐** 앱 탭이 아니다. 계획 page에는 Flow-1~4만 있고, 시나리오 화면은 이 별도 page에 모여 있다.

### 0-2. 기존 "같은 화면 뷰 전환" 결정과 충돌하는가? → **충돌하지 않는다. 결정을 더 구체화한다 [확인 + 추정]**
- 모든 artboard의 왼쪽 섹션(0,209,400,1183 사다리꼴, 좌측 부착)은 계획 탭 Section 1 메뉴 자리다. 맨 위에 `계획` 제목과 `보는 중` / `보는 중 · 시나리오` 상태 버튼(`btn sel-pink`)이 있다. 즉 **계획 탭 안에서 지금 무엇을 보고 있는지**를 바꾸는 구조다.
- Detail 3종은 왼쪽 버튼 `07 3단계 우선순위 / 활성 계획은 바뀌지 않습니다`로 **활성 계획 자리에 시나리오를 보여준다**. 가운데는 페이즈·단계 목록, 오른쪽은 `병목/페이즈별/전체` 세그먼트와 재화 본문이다. 이것이 사용자 결정 "활성 계획 자리에 시나리오를 보여줌"을 그대로 시각화한 것이다.
- List와 Compare는 계획 홈 섹션을 치우고 그 자리에 다른 작업 화면을 띄운다. 이것은 현재 코드 동작과 같다: `_openScenarioWorkspace`가 `element-1`을 뺀 나머지 controller를 reverse하고 `PlanScenarioListSection` / `PlanScenarioComparisonSection`을 `planScenarioListMotion`(intro 80°, outro 260°)으로 띄운다.
- 남는 모호점(6절에 정리): Detail artboard는 3섹션(메뉴 400 / 페이즈 864 / 재화 1664)이다. 그런데 현재 활성 계획 홈은 `planStudioDocument`의 element-1~5, 즉 5섹션이다. 캔버스에는 **활성 계획 홈 자체의 시안이 없다**. 그래서 "같은 화면"이 되려면 활성 계획 홈도 이 3섹션 구성으로 바꿔야 하는지 확인이 필요하다.

### 0-3. 활성 계획 대비 delta · 기준 대비 비교 계산이 서비스/프로토콜에 있는가? → **부분적으로 있다**
- 있는 것 [확인]
  - `planning.scenario.compare`(`PlanningScenarioComparisonService.compareScenarios`): 문서 **2개**(A/B)를 받아 `projection_a`, `projection_b`, `comparison`을 돌려준다.
  - `comparison`의 키는 코드 사용처에서 확인했다: `credits_a/b`, `credits_delta_b_minus_a`(mock), `resource_type_count_a/b`, `known_shortage_type_count_a/b`, `students[]{student_id, presence(both/a_only/b_only), target_differences{key:{a,b}}}`, `resources[]{resource_key, item_id, display_name, category, owned, required_a/b, shortage_a/b}`, `bottlenecks[]{resource_key, shortage_a/b, first_phase_a/b}`.
  - 단, `PlanningScenarioComparisonResult`는 세 필드를 `Map<String,dynamic>`으로만 보관하고 **타입 검증을 하지 않는다**.
  - `planning.document.calculate`(`calculatePlanningDocument`): `phase_results[]{phase_id,name,stage_ids,cost,resources[]{resource_key,item_id,display_name,category,required,owned,affected_stage_ids}}`, `overall{cost,resources}`, `bottlenecks[]{stage_id,phase_number,resource_key,display_name,category,item_id,remaining_at_entry,required_at_entry,shortage,affected_stage_ids}`, `stage_results[]`, `warnings`.
  - `repository.scenario.list` 요약(`PlanningScenarioCalculationSummary`): `credits`, `required_resource_type_count`, `known_shortage_type_count`, `inventory_complete`, `first_bottleneck_phase_number`, `representative_shortage{resource_key,item_id,display_name,category,shortage}`.
- 없는 것
  - **3~4개 동시 비교 / 기준 전환**: 프로토콜이 쌍(pair)만 지원한다. 클라이언트가 기준과 나머지를 N−1번 호출해야 하고, 그때마다 기준 projection이 다시 계산된다.
  - **활성 계획의 요약**(List 상단 `활성 계획` 행, 미리보기의 `활성 계획 대비` KPI): list 결과에 없다. `calculatePlanningDocument(active)`로 클라이언트가 요약을 만들거나, 백엔드가 list에 `active_plan` 요약을 추가해야 한다.
  - **단계(stage) 단위 차이**(`활성 계획과 다른 단계 3`, 단계 행의 `이 시나리오에만`): `comparison.students`는 **학생 최종 목표**만 비교하고, 단계끼리 맞추는 규칙은 없다.
  - **`끝까지 가는 학생 4/9`**, **`필요량의 81% 확보`**: 프로토콜 필드가 없고 정의도 미정이다.
  - **페이즈별 `진입/필요/종료`**: phase resource에는 `required`, `owned`만 있다. `owned`가 페이즈 진입 시점 잔량인지 전체 보유량인지 문서·코드 어디에도 정의가 없다(mock은 빈 배열을 반환).
  - 백엔드 Python 소스는 로컬에 없어서 실제 계산 구현은 확인하지 못했다.

---

## 1. Scenario-List — 목록 관리 (정렬·필터·비교 담기·미리보기)

### 1-1. 목적과 섹션 구성 (3섹션 + 내부 스크롤 영역)
| 섹션 | rect (x,y,w,h) | 형상 | 부착면 | 내용 |
|---|---|---|---|---|
| S1 메뉴 | 0,209,400,1183 | 사다리꼴(왼변 수직, 오른변 80°) | 좌 | 보는 중 / 메뉴 / 비교 슬롯 |
| S2 목록 | 215.4,209,1504.6,1183 | 평행사변형 | 하(바닥까지) | 제목줄·정렬·필터·활성 계획 행·시나리오 목록 |
| └ 스크롤 영역 | 229.5,421,1441.1,959 | 평행사변형(내부 패널, 채움 rgba(26,44,59,.9)) | — | 시나리오 행 6개 |
| S3 미리보기 | 1535.4,209,1024.6,1183 | 사다리꼴(왼변 80°, 오른변 수직) | 우 | 선택한 시나리오 미리보기 |

### 1-2. 사용 요소
- **제목줄**(447.7,227): 분홍 사선 바 + `시나리오` + `6개` + (i) 팝오버(`.info/.ib/.pop.l`, aria `시나리오 목록 도움말`). 오른쪽에는 **정렬 세그먼트** `.seg` 4개: `최근 수정`(on) / `부족 적은 순` / `크레딧 적은 순` / `이름`.
- **필터 칩줄**(445.7,275): `현재 데이터 기준만`(chip) / `학생 · 전체 ▾`(chip gy, 드롭다운) / `🔍 이름·설명 검색`(chip gy). 오른쪽 끝에 `오래된 시나리오 1개`(mut).
- **활성 계획 고정 행**(`srow blue`, 410.7,317,1264×92): `활성 계획` + chip `메인 · 지금 쓰는 계획`, 학생 초상 겹침 + `+4 · 학생 9 · 페이즈 1 · 단계 9`, KPI 3개(`.ihdr` 라벨: 필요 크레딧 186.2M / 부족 재화 14종 / 첫 병목 P1).
- **시나리오 행**(`srow`, 100px, 선택 시 `srow sel` 146px로 펼쳐짐). 80° 레일을 따라 행마다 x가 19.4px씩 줄어든다.
  - 왼쪽 **비교 담기 체크박스**(`button aria-label=비교에 담기`)
  - 이름, 상태 chip(`현재 데이터 기준` 또는 `chip wn 저장 시점과 다름`), `수정 9.22 23:10`, 설명(mut)
  - 지표: `크레딧 112.8M`, `부족 8종`, `첫 병목 P1`(또는 `병목 없음`), `학생 3 · 페이즈 3 · 단계 5`
  - 대표 부족 아이템(`.pt` 아이콘 + 이름 + `−449`) 또는 `부족 없음`
  - 선택 행에만 행 액션: `열기 / 비교에서 빼기 / 복제 / 이름 · 설명 / 삭제`
- **S1 메뉴**: `btn sel-pink`(`시나리오 목록 / 저장된 시나리오 6`), `btn ghost 활성 계획으로`, `btn pri 새 시나리오`, `btn ghost 프리셋 관리`.
  - **비교 슬롯**: `비교할 계획 3 / 4`, 그 아래 A–D 슬롯 버튼. A는 `활성 계획 · 기준 · 뺄 수 없습니다`, D는 빈 슬롯으로 `목록에서 체크해서 담기`.
  - `btn tri 나란히 비교 3개`, 그리고 안내 문구 `최대 4개까지 · 둘만 담으면 A↔B 상세 비교로 열립니다`.
- **S3 미리보기**
  - 제목 `미리보기` + chip, 시나리오 이름·설명·수정시각
  - `활성 계획 대비` KPI 비교 3개(왼쪽 = 활성, 오른쪽 = 이 시나리오)
  - **학생 · 단계** 행 3개(`.row` 56px): 학생명, 단계 경로 `P1 1단계 → P2 2단계`, 목표 요약 `Lv.90 · 스킬 M/M/M/M · T10`, 차이 chip `활성 계획과 같음` / `목표 다름 2` / `활성보다 낮은 목표`
  - **분야별 가장 큰 부족** 행 5개(엘레프/오파츠/노트·BD/장비 설계도/크레딧): 아이템, 위치 `P1 리오 1단계`, 부족량, 활성 대비 chip(`=`, `−6`(ok), `+12`(wn))
  - 하단 액션: `열기 / 비교에서 빼기 / 계획에 적용…`
- **부족 재화 팝오버**(`.shw/.sht/.sho/.shp/.sr_`, List에서는 `open` 상태로 그려져 있음, anchor 2002.4,411)
  - 제목 `부족 재화 8종`, 부제 `활성 계획 14종 · 빠진 6종은 이 시나리오에 없는 학생 몫`
  - 분야별 그룹 헤더 + 행(아이콘, 이름, 부족량, 활성 대비 chip: `활성 계획과 같음` / `−6` / `+12` / `이 시나리오에만`)
  - 하단 문구 `항목을 누르면 그 재화가 막는 단계로 이동합니다`와 `tonal 인벤토리에서 보기`
  - 이 팝오버는 Detail 3종과 Compare에도 같은 내용으로 재사용된다 → 공통 컴포넌트 **ShortagePopover**로 묶는다.
- 스크롤 포그와 사선 스크롤바는 **artboard에 그려져 있지 않다**(mask-image / scrollbar 요소 0건).

### 1-3. 상태·상호작용
- script 블록은 `class Component extends DCLogic { renderVals() { return {}; } }`뿐이라 **로직이 없다**. 상호작용은 (i) 팝오버 문구와 hover CSS(`.srow:hover`, `.shw:hover .shp`)로만 표현돼 있다.
- (i) 문구 기준 동작
  - 카드 클릭 → 오른쪽 미리보기
  - 두 번 클릭 또는 `열기` → Detail(병목/페이즈별/전체)
  - 왼쪽 네모 체크 → 비교 슬롯에 담김(최대 4)
- 나란히 비교: 2개면 A↔B 상세 비교, 3~4개면 Compare 화면.
- intro/outro 애니메이션은 artboard에 정의가 없다(`@keyframes` / animation 0건). 현재 코드의 `planScenarioListMotion(80/260)`을 유지하면 된다 [추정].

### 1-4. 현재 코드 대응
| 시안 요소 | 현재 코드 | 분류 | 근거 |
|---|---|---|---|
| 목록 섹션 전체 | `PlanScenarioListSection` / `_PlanScenarioListSectionState` (plan_section_layout.dart:4921) | **수정** | 로드·에러·빈 상태·선택·대각선 스크롤이 이미 있음. 정렬/필터/체크박스/행 액션/활성 행은 없음. 섹션 path `planScenarioListSectionPath`가 하나뿐 → 미리보기 섹션 분리 필요 |
| 시나리오 행 | `PlanScenarioListCard` (:5138), `_ScenarioStudentPortraits` (:5369, 4명 + `+n`), `_PlanScenarioListCardPainter`, `PlanScenarioParallelogramClipper` | **수정** | 이름·설명·`학생/페이즈/성장 단계`·`_calculationLabel()`(크레딧·부족·최초 병목)·stale 칩(`저장 시점과 다름`/`현재 데이터 기준`)·대표 부족 `−n`·수정시각이 이미 있음. 체크박스, 펼침(146px) 액션 행, 지표 레이아웃 재배치가 필요. 현재 rowHeight는 142 고정 |
| 대각선 스크롤 | `PlanDiagonalScrollbar`(keyPrefix `plan-scenario`, `fogClipper`), `planPhaseRowHorizontalOffset`, `planPhaseRowWidth` | **그대로 재사용** | 시안의 80° 레일 오프셋과 일치 |
| 활성 계획 고정 행 | 없음 | **신규** | |
| 정렬 seg / 필터 칩 / 검색 | 없음 (계획 재화용 `PlanResourceSort`는 다른 대상) | **신규** | 클라이언트 정렬·필터로 충분 |
| 미리보기 섹션 S3 | 없음 | **신규** | |
| ShortagePopover | 없음 (`.shw` 계열) | **신규 공통 위젯** | Detail/Compare와 공용 |
| S1 메뉴 버튼 | `plan-scenario-list-launch`(`시나리오 리스트`/`목록 닫기`), `plan-scenario-create-launch`(`시나리오 생성`), `plan-scenario-compare-launch`(`시나리오 비교`), `plan-preset-manager-launch`(`프리셋 생성·관리`), `plan-phase-editor-launch`(`페이즈 만들기`), `plan-student-selector-launch` | **수정** | 시안은 모드에 따라 메뉴가 바뀌는 구조. `보는 중` 상태 버튼, `활성 계획으로`, 비교 슬롯 A–D, `나란히 비교 n개`는 신규 |
| 복제 / 삭제 / 이름·설명 | `duplicateScenario`는 비교 화면에서만 호출(:3539). `deleteScenario`는 **UI 호출처 없음**. `updateScenario`는 `_saveScenarioDraft`에서만 호출 | **신규 UI + 서비스 재사용** | 서비스 메서드는 모두 있음 |
| 계획에 적용… | `_incorporateScenario`(:2160, 시나리오 페이즈를 활성 계획 뒤에 `이름 · 페이즈명`으로 붙이고 퇴행 단계는 제외) | **수정** | Flow-4-Save의 3가지 선택지(페이즈로 추가 / 활성 계획을 이걸로 바꾸기: 기존 페이즈는 시나리오로 옮김) 중 "바꾸기"는 없음 |

### 1-5. 데이터 요구
- 행 지표, 대표 부족, stale 여부, 수정시각, 학생 ID: `PlanningScenarioSummary` + `PlanningScenarioCalculationSummary`로 **모두 제공된다 [확인]**.
- 정렬·필터는 summary 필드로 클라이언트에서 처리할 수 있다. 학생 필터는 `studentIds`, 오래된 시나리오는 `baseProfileRevision < currentProfileRevision`, `isStaleAgainst`를 쓴다.
- 활성 계획 행: **백엔드 요약이 없다.** 선택지는 둘이다.
  - (a) `calculatePlanningDocument(activePlan)` projection에서 클라이언트가 크레딧·부족 종류·첫 병목을 계산한다.
  - (b) `repository.scenario.list` 응답에 `active_plan` 계산 요약(같은 `PlanningScenarioCalculationSummary` 형태)을 추가한다(**프로토콜 추가**).
  - 요약을 두 곳에서 같은 정의로 계산하려면 (b)가 안전하다 [추정].
- 미리보기의 학생·단계·목표 차이: `getScenario` 문서 + `compareScenarios(active, scenario)`의 `students[].target_differences`를 쓴다. `활성보다 낮은 목표` 같은 방향 판단은 a/b 값으로 클라이언트가 계산할 수 있다.
- 분야별 가장 큰 부족과 활성 대비 ±: `comparison.resources`(`category`, `shortage_a/b`)로 가능하다. 위치(`P1 리오 1단계`)는 `projection_b.bottlenecks[].stage_id`, `phase_number`로 찾는다.
- 팝오버 문구 `빠진 6종은 이 시나리오에 없는 학생 몫`: a에만 있는 부족 재화를 `affected_stage_ids` → 학생으로 귀속시켜야 한다. 클라이언트에서 계산할 수는 있지만 **정의 확인이 필요하다**.
- 선택 행마다 compare를 1회 호출해야 하므로 미리보기 지연과 캐시 정책이 필요하다 [추정].

---

## 2. Scenario-Detail-Bottleneck / -Phase / -All — 열어 보기 (활성 계획 대비)

### 2-1. 목적과 섹션 구성 (3종 공통 골격)
| 섹션 | rect | 형상 | 부착면 | 내용 |
|---|---|---|---|---|
| S1 메뉴 | 0,209,400,1183 | 사다리꼴 | 좌 | 보는 중 · 시나리오 / 액션 / 이 시나리오 정보 |
| S2 페이즈 | 215.4,209,864.6,1183 | 평행사변형 | 하 | 제목줄 + 페이즈·단계 목록 |
| └ 스크롤 영역 | 229.5,281,825.8,1099 | 평행사변형 내부 패널 | — | |
| S3 재화 | 895.4,209,1664.6,1183 | 사다리꼴(우측 수직) | 우 | 세그먼트·요약·활성 대비 KPI·본문 |
| └ 본문 스크롤 | 909.5,471,1638.5,909 (All은 511,869) | 평행사변형 내부 패널 | — | |

- 세 변형의 S1과 S2는 **사실상 동일하다**. diff 결과 차이는 두 가지뿐이다.
  - Bottleneck: 단계 행에 `병목 1 · 여기서 막힘`, `앞 단계 대기` chip이 붙는다.
  - Phase: 페이즈 헤더 P1이 `srow sel`로 강조된다.

### 2-2. 사용 요소
- **S1**
  - `보는 중 · 시나리오`, `btn sel-pink`(`07 3단계 우선순위 / 활성 계획은 바뀌지 않습니다`)
  - `시나리오 목록`, `btn 페이즈 편집`, `복제해서 새로`, `비교에 담기 · 3/4`, `btn tri 계획에 적용…`
  - `이 시나리오` 정보 버튼 5개: `학생 3명 / 페이즈 3개 / 단계 5개 / 저장 9.22 23:10 / 데이터 현재 기준`
- **S2**
  - 제목 `페이즈 3개 · 단계 5` + chip pk `활성 계획과 다른 단계 3`
  - 페이즈 헤더(`plain` 44px): 번호, 이름, `단계 n`, 부족 chip(`부족 3종` wn / `충분` ok)
  - 학생 단계 행(`srow` 70px): 평행사변형 초상 52×42, 이름, `n단계`, 목표 요약, 활성 대비 chip(`활성 계획과 같음` / `목표 다름` / `이 시나리오에만` / `활성보다 낮은 목표`)
- **S3 공통 상단**
  - 세그먼트 `병목 / 페이즈별 / 전체` + 칩 `재화 유형 · 전체`, `충족 재화 숨기기`, `부족량 많은 순`
  - **요약 행**(`row` 70px, 아이콘 + 3줄)
    - 병목: `가장 심한 병목 · 리오(무장)의 엘레프 · 449 부족 / P1 리오 1단계에서 막힙니다 · 확보하면 …`
    - 페이즈: `가장 부족한 재화 · 기술 노트 (최상급) · P1에서 2명 중 1명만 완료 / P1 종료 시 0개 남아서 …`
    - 전체: 아이콘 없이 `전체 요구량 · 필요량의 81% 확보 · 8종 부족 · 3명 중 2명의 계획에 영향` + chip `활성 72% → 81%`
  - **`활성 계획 대비` KPI 4개**(활성 / 시나리오): 필요 크레딧, 부족 재화(ShortagePopover anchor 1459,392), 첫 병목, **끝까지 가는 학생 `4 / 9` vs `2 / 3`**
- **S3 본문 — 병목**: 병목 카드(`srow` 214px)
  - `병목 n` + 페이즈 배지, 학생·단계 + 활성 대비 chip(`활성보다 1페이즈 빨리` / `부족 줄어듦`)
  - 그 단계의 재화 타일 2개: `진입 잔량 1 · 필요 450` → `449 부족` 또는 `충분`, 재화별 활성 대비 chip
  - `이 병목으로 지연되는 단계: 리오 2단계 (P2)`
- **S3 본문 — 페이즈별**: 페이즈 카드(`srow` 300px)
  - 크레딧 `진입 98.4M / 필요 27.6M / 종료 70.8M`
  - 재화 타일: `진입 1 · 필요 450 · 종료 0` + `bar2` 충족률 `0%~100%` + 활성 대비 chip
- **S3 본문 — 전체**
  - 그리드 헤더 `재화 16종 · 한 행에 [2|3|4(on)|5]` + 범례 `= 같음 · 신규 = 이 시나리오에만 · ± 활성 대비`
  - 크레딧 행: 보유/필요/bar/부족/`활성보다 −73.4M`
  - 분야별 그룹 행(엘레프/오파츠/노트·BD/장비 설계도): 그룹 헤더(`n종`, `부족 n종`) + n열 타일(아이콘, 이름, delta 마크 `=`/`−60`/`신규`, `보유 / 필요`, bar2)

### 2-3. 상태·상호작용
- 로직 없음. 화면에 쓰인 안내 문구가 의도를 설명한다.
  - Phase: `페이즈를 누르면 왼쪽 단계가 강조됩니다`
  - All: `재화를 누르면 왼쪽에서 그 재화를 쓰는 단계가 강조됩니다`
  - Bottleneck: 병목 카드 선택(`srow sel`) ↔ 왼쪽 단계 행 강조(분홍 inset 1.5px)
- 이 동작은 현재 계획 홈의 **Section 2 하이라이트 계약**(`_highlightedStudentIds`, `_highlightedStageKeys`, `PlanResourceToggle`, 1.8px `#f2b3ef`)과 같은 개념이다.

### 2-4. 현재 코드 대응
| 시안 요소 | 현재 코드 | 분류 | 근거 |
|---|---|---|---|
| "시나리오를 활성 계획 자리에" 모드 | `_editScenarioFromComparison`(:2081)이 `_captureScenarioPlanSnapshot` 후 `_document = scenario.document`, `_creatingScenario=true`로 **편집 모드**로만 진입. 복귀는 `_restorePlanAfterScenarioCreation` | **수정(모드 신설)** | 읽기 전용 "보기" 모드(`_viewingScenario` 같은 상태)가 없음. 스냅샷·복원 메커니즘은 재사용 가능 |
| 문서 projection → 병목/페이즈/전체 데이터 | `_calculateDocument`(:1574~), `_consumptionResource`, `PlanBottleneckDetailPreview`, `PlanConsumptionGroupPreview`, `PlanDelayedStagePreview` | **그대로 재사용**(시나리오 문서를 넣으면 됨) | |
| 세그먼트 탭 | `PlanResourceView{bottleneck, byPhase, overall}`, `PlanResourceHeader`, `_PlanResourceTabs/_PlanResourceTab` | **재사용 + 배치 수정** | 시안은 탭을 S3 상단 한 줄에 칩과 같이 둠. 현재는 element-5 헤더 섹션 + element-4 컨트롤로 분리 |
| 칩 3개 | `PlanResourceControls`, `PlanResourceTypeFilterSection`(`PlanResourceCategory`), `_PlanResourceSortDropdown`(`PlanResourceSort.shortageDescending` = `부족량 많은 순`) | **재사용(스킨 수정)** | |
| 요약 행 3종 | `PlanPrimaryBottleneckSummary`(:6235), `PlanPhaseResourceSummary`(:6263), `PlanOverallResourceSummary`(:6292), `PlanResourceItemSummary` | **수정(데이터 연결 필수)** | 세 위젯 모두 **타입 상수**(`planPrimaryBottleneckOwned=42`, `planPhaseShortageNumber=2`, `planOverallProgressPercent=72` 등)를 표시. section-template-studio.md도 "sample values remain typed constants until the inventory-derived shortage contract is connected"라고 명시. 활성 계획 화면과 공통 과제 |
| 활성 계획 대비 KPI 줄 | 없음 (비교 화면의 `_ComparisonMetric`, `_ComparisonDelta`는 있음) | **신규**(`_ComparisonMetric` 재활용 검토) | |
| 병목 카드 | `PlanBottleneckDiagonalList`, `PlanBottleneckDetailCard`, `PlanBottleneckResourceTile`, `PlanBottleneckCreditShortage` | **수정** | 현재는 projection bottleneck 1건 = 카드 1장 = 재화 1개. 시안은 같은 단계의 재화 여러 개(충분한 크레딧 포함)를 한 카드에 묶고 활성 대비 chip을 붙임 |
| 페이즈 카드 | `PlanPhaseDiagonalList`, `PlanPhaseCard`, `PlanConsumptionCard`, `PlanConsumptionCreditRow`, `PlanInventoryCoverageBar` | **수정** | 진입/필요/종료 3값과 bar%, delta chip을 추가 |
| 전체 그리드 | `PlanConsumptionSection`, `PlanConsumptionDiagonalList`, `_PlanDiagonalTwoColumnGrid`(2열 고정), `PlanConsumptionResourceTile` | **수정** | 열 수 2~5 선택, 분야별 그룹 행, delta 마크 |
| S2 페이즈·단계 목록 | `PlanPhaseDiagonalList`/`PlanPhaseCard`, `PlanStudentStepTile`(plan_student_step_tile.dart), `PlanPhaseContainerPainter` | **재사용 + chip 슬롯 추가** | 활성 대비 chip과 병목 상태 chip을 넣을 자리가 필요 |
| ShortagePopover | 없음 | **신규 공통** | |
| S1 시나리오 보기 메뉴 | 없음 | **신규** | `페이즈 편집` → `_editScenarioFromComparison` 재사용, `복제해서 새로` → `duplicateScenario`, `계획에 적용…` → `_incorporateScenario` 확장 |

### 2-5. 데이터 요구
- 병목·페이즈·전체 본문의 시나리오 측 값은 `planning.document.calculate`로 **대부분 제공된다**.
  - 병목: `remaining_at_entry`, `required_at_entry`, `shortage`, `affected_stage_ids`
  - 전체: `overall.resources[].required`, `owned`
- **페이즈 `진입/종료`**: phase resource는 `required`와 `owned`뿐이다. `owned`가 진입 잔량이면 종료 = `max(0, owned − required)`로 계산할 수 있다. 하지만 **의미가 문서화돼 있지 않다** → 백엔드에서 확인하거나 `remaining_at_entry`, `remaining_at_exit` 필드를 추가해야 한다.
- **병목 카드의 "충분" 재화**(그 단계에서 쓰지만 부족하지 않은 재화): `stage_results[].resources`가 있다면 쓸 수 있다. mock은 빈 배열이고 실제 키 구성은 확인하지 못했다.
- **활성 대비 delta**
  - 재화별 `+12/−6/=/신규`: `comparison.resources`의 `required_a/b`, `shortage_a/b`로 가능하다. 단, 시안이 보이는 ±가 **부족량 차이**인지 **요구량 차이**인지 혼재한다. 예: Detail-All의 `리오(무장)의 엘레프 =`와 `쿠루미의 엘레프 −60`(212/120, 부족 없음) → 요구량 차이로 보인다 [추정].
  - 병목 `활성보다 1페이즈 빨리`: `comparison.bottlenecks[].first_phase_a/b` ✓
  - 학생 `목표 다름`: `students[].target_differences` ✓, `이 시나리오에만`: `presence=b_only` ✓
  - **단계 단위** `이 시나리오에만` / `활성 계획과 다른 단계 3`: **제공되지 않는다**(stage 매칭 규칙 없음) → 정의와 프로토콜 추가가 필요하다.
- **`끝까지 가는 학생 n/m`**: 필드가 없다. projection의 bottleneck `stage_id` + `affected_stage_ids`로 "막힌 단계가 없는 학생 수"를 클라이언트가 유도할 수는 있다 [추정]. 정의 확정이 필요하다.
- **`필요량의 81% 확보`**: 정의가 없다. 2026-09-08 문서에 "종류가 다른 재화를 하나의 금액으로 더하지 않는다"는 원칙이 있으므로 단순 합산 비율은 이 원칙과 충돌한다. 재화별 충족률 평균인지 등 정의를 확인해야 한다.
- Detail 화면 하나를 열 때 필요한 호출: `getScenario`, `calculatePlanningDocument(scenario)`, `compareScenarios(active, scenario)`. 마지막 호출이 projection_b를 함께 주므로 두 번째 호출은 생략할 수 있다.

---

## 3. Scenario-Compare — 나란히 비교 (최대 4열 · 기준 대비)

### 3-1. 목적과 섹션 구성 (6섹션)
| 섹션 | rect | 형상 | 부착면 | 내용 |
|---|---|---|---|---|
| S1 메뉴 | 0,209,400,1183 | 사다리꼴 | 좌 | 보는 중 · 보기 토글 · 기준 계획 선택 |
| 라벨 열 | 159,209,531,**1503** | 평행사변형 | 하 | 비교 항목 라벨 |
| 열 A~D | 449 / 910.5 / 1372 / 1833.5, 209, 702.5, **1503** | 평행사변형 4개(같은 크기, x 간격 461.5) | 하 | 계획별 값 |

- 라벨 열과 열 A~D의 높이는 1503이라 **viewport(1392) 아래로 넘친다**. 학생 행도 y 1449까지 있다(artboard는 `overflow:hidden`으로 잘려 있음).
- 라벨 열(159~690)은 S1(0~400)과 겹친다(S1이 위에 그려짐).

### 3-2. 사용 요소
- **라벨 열**: `비교 항목` / `초록 = 이 행에서 가장 좋음`. 행 라벨(`srow` 62px)은 `필요 크레딧`(적을수록 좋음), `부족 재화`(누르면 목록), `첫 병목`(늦을수록 좋음), `끝까지 가는 학생`(완료 가능/전체), `규모`. 이어서 `분야별 부족 · 심한 순 3개` 헤더와 분야 4행(50px), `학생 최종 목표 · 9명` 헤더와 학생 9행(46px)이 온다.
- **열 헤더**(`srow` 432×128)
  - A(`srow blue`): `A 활성 계획 / 메인 · 지금 쓰는 계획 / 열기 / chip 비교 기준`
  - B~D: 문자, 이름, `비교에서 빼기`(aria), 수정시각, `열기`, `계획에 적용…`
- **값 셀**
  - 크레딧: 값 + `bar2` + `기준과 같음` 또는 `−73.4M`
  - 부족 재화: `8종 / 목록 / −6종`. ShortagePopover anchor는 B열(1138,439)
  - 첫 병목: `P1 / 리오의 엘레프 −449`
  - 끝까지 가는 학생: `2 / 3` + bar + `67%`
  - 규모: `학생 3 · 페이즈 3 · 단계 5`
  - 분야별 부족: `n종` + 아이콘 칩 최대 3개(`title`에 `이름 −n`) + `+n종 더` + `전체` 또는 `충분`
  - 학생 최종 목표: `Lv 90 ★ 5 무 50 S 5·M·M·M T 10·10·10·2 ♥ 20` + 기준 대비 `같음 / 다름 n / 신규 / 포함 안 됨`
- **S1**
  - `btn sel-pink 나란히 비교 · 4개 / 기준 A · 활성 계획`, `시나리오 목록`
  - `보기` 토글 3개(`.tog`): `차이만 보기`(off), `최고 값 강조`(on), `기준 대비 ± 표시`(on)
  - `기준 계획` 라디오 A(`sel-blue`)~D
  - 안내 문구 `두 개만 남기면 A↔B 상세 비교(학생 목표 · 재화 · 병목 탭)로 바뀝니다`

### 3-3. 상태·상호작용
- 로직 없음. 의도된 동작
  - 기준 계획 변경 → 모든 ±와 "같음/다름"이 다시 계산된다.
  - `차이만 보기` → 같은 행을 숨긴다.
  - `최고 값 강조` → 행마다 가장 좋은 값을 초록으로 표시한다.
  - 열에서 빼기로 2개가 남으면 기존 A↔B 상세 비교로 전환된다.
- 행들이 열 사이에서 **같은 y로 맞춰진 표** 구조다. 라벨 열과 4열이 같은 높이(1503)인 것으로 보아 세로 스크롤이 전체를 함께 움직이는 것으로 보인다 [추정].

### 3-4. 현재 코드 대응
| 시안 요소 | 현재 코드 | 분류 | 근거 |
|---|---|---|---|
| 비교 화면 진입·상태 | `PlanScenarioComparisonSection` / `_PlanScenarioComparisonSectionState`(:3391~), `_PlanComparisonTarget`(`active-plan` 포함) | **수정** | `_toggle`이 **최대 2개**(`_selectedIds.length < 2`), `_compare`도 2개 전제. `'먼저 선택한 계획은 A, 다음은 B로 비교합니다.'` |
| 후보 선택 목록 | `_ComparisonCandidateDiagonalList`, `_ComparisonCandidateCard` | **폐기 대상 [추정]** | 시안은 후보 선택을 List의 체크박스와 S1 슬롯으로 옮김 |
| A↔B 상세(2개일 때) | `_ComparisonSideBySide`, `_ComparisonPaneShell`, `_ComparisonPaneDiagonalList`, `_ComparisonSummaryPane`(`전체 결과`), `_ComparisonStudentWorkspace`(`학생 목표`, `DiagonalMediaListItem`), `_ComparisonResourcePane`(`재화·부족`), `_ComparisonBottleneckPane`(`병목`), `_ComparisonBadge`, `_ComparisonMetric`, `_ComparisonDelta`, `_ComparisonResourceTitle` | **그대로 재사용**(2개 모드) | 시안 문구 "둘만 담으면 A↔B 상세 비교로 열립니다"와 일치. 단 이 화면 자체의 새 시안은 없음 |
| 4열 표 | 없음 | **신규** (`ScenarioCompareGrid` 같은 이름 [제안]) | 열 동기 행, 라벨 열, 최고값 강조, ± 표시 |
| 보기 토글 `.tog` | 없음 | **신규 공통 요소** | |
| 편집 / 편입 / 복제 | `onEdit`(`_editScenarioFromComparison`), `onIncorporate`(`_incorporateScenario`), `_duplicate` | **재사용** | 시안 열 헤더는 `열기 / 계획에 적용…`만 있음(편집·복제 버튼은 Detail과 List로 이동) |
| stale 경고 | `plan-scenario-comparison-stale-warning` | **재사용** | 시안에는 표시 위치가 없음 → 확인 필요 |

### 3-5. 데이터 요구
- 크레딧과 부족 종류 수: 열마다 `comparison.credits_*`, `known_shortage_type_count_*` ✓.
  - 다만 기준 대비 쌍 비교를 N−1번 해야 한다. 기준을 바꾸면 다시 N−1번 호출한다. 호출마다 기준 projection이 재계산되므로 비효율적이다.
  - **제안**: `planning.scenario.compare`를 `documents: [..]`(최대 4) + `baseline_index`로 확장하거나, `planning.scenario.compare_many`를 신설한다(**프로토콜 추가**). 대안으로 클라이언트가 문서마다 `planning.document.calculate`를 1회씩 호출하고 비교 행렬은 클라이언트가 만드는 방법도 가능하다. 이 경우 학생 `target_differences`는 문서끼리 클라이언트에서 비교하면 된다(`planningDocumentTargetKeys` 17키 [확인]).
- 첫 병목(페이즈 + 대표 재화): projection `bottlenecks[0]`의 `phase_number`, `display_name`, `shortage` ✓.
- 분야별 부족 상위 3: projection `overall.resources`의 `category` + 부족량(`required − owned`)으로 클라이언트가 계산할 수 있다 ✓.
- 학생 최종 목표 행(Lv/★/무/S/T/♥): `PlanningDocument.phases[].stages[].targets` 중 학생별 마지막 단계에서 가져온다(클라이언트 ✓, 기존 비교 화면도 같은 방식). `포함 안 됨`은 학생 합집합으로 처리한다.
- 끝까지 가는 학생: 2절과 같이 **정의와 출처가 미정**이다.
- `+n종 더`와 `전체` 링크의 이동 대상(ShortagePopover인지 Detail-All인지)은 미정이다.

---

## 4. 공통 컴포넌트 (그룹 D에서 반복)

| 이름(제안) | 시안 클래스 | 사용처 | 현재 코드 |
|---|---|---|---|
| ScenarioModeMenu (S1 "보는 중" 메뉴) | `btn sel-pink/ghost/pri/tri`, `.cap` | 5개 전부 | element-1 메뉴(`plan-*-launch` 버튼) **수정** |
| CompareSlots (A–D) | `btn ghost` + `.dsp` 문자 | List, Compare(기준 라디오) | 신규 |
| ActiveDeltaKpiRow (활성 / 시나리오 2값 KPI) | `.ihdr` + 2값 | List 미리보기(3개), Detail(4개) | 신규 (`_ComparisonMetric` 참고) |
| DeltaChip (`활성 계획과 같음`/`±n`/`이 시나리오에만`/`목표 다름`/`활성보다 낮은 목표`) | `chip gy/ok/wn/pk` | 전부 | 신규 (`_ComparisonDelta`, `_ComparisonBadge` 참고) |
| ShortagePopover | `.shw/.sht/.sho/.shp/.sr_` | 5개 전부 | 신규. 계획 Flow-4의 `.flyw/.fly`(`부족량/단계별` seg 포함)와는 변형이 다름 → 통합 여부 확인 |
| ScenarioRow (펼침형) | `srow` / `srow sel` / `srow blue` | List | `PlanScenarioListCard` 수정 |
| CoverageBar | `.bar2` | Phase, All, Compare | `PlanInventoryCoverageBar` 재사용 |
| ToggleSwitch | `.tog` | Compare | 신규 |
| 아이템 아이콘 | `.pt`(배경 + 아이콘) | 전부 | `planning_resource_assets.dart`, `_resourceIcon` 재사용 |
| 대각선 리스트 + 스크롤바/포그 | (시안에는 미표시) | List / Detail S2·S3 / Compare | `PlanDiagonalScrollbar`, `planPhaseRowHorizontalOffset` 재사용 |

---

## 5. 데이터·프로토콜 갭 요약

| 필요 값 | 상태 | 조치 |
|---|---|---|
| 시나리오 행 지표, 대표 부족, stale | ✓ `PlanningScenarioSummary` | — |
| 활성 계획 요약(크레딧, 부족 n종, 첫 병목) | ✗ | `repository.scenario.list`에 `active_plan` 요약 추가, 또는 클라이언트가 projection에서 계산 |
| 2문서 비교(학생 목표 차이, 재화 a/b, 병목 a/b) | ✓ `planning.scenario.compare` (단 untyped Map) | `comparison` 타입 모델(fromWire) 추가 권장 |
| 3~4문서 비교, 기준 전환 | △ 쌍 비교 N−1회 | `compare` 다중 문서 확장 제안 |
| 페이즈 진입/종료 잔량 | △ `required`, `owned`만 있음, 의미 미정 | 백엔드 의미 확인 또는 `remaining_at_entry/exit` 추가 |
| 단계 단위 활성 대비 차이 | ✗ | stage 매칭 규칙 정의 + 프로토콜 |
| 끝까지 가는 학생 n/m | ✗ | 정의 확정 → 클라이언트 유도 또는 백엔드 필드 |
| 전체 확보율 % | ✗ (UI 상수 72) | 정의 확정(이종 재화 합산 금지 원칙과 충돌 주의) |
| 요약 행 3종(병목/페이즈/전체) | ✗ UI 상수 | projection 연결(활성 계획 화면과 공통) |
| 시나리오 삭제, 이름·설명 수정 | ✓ 서비스 있음, UI 없음 | UI만 추가 |
| 계획에 적용: "활성 계획을 이걸로 바꾸기" | ✗ (`_incorporateScenario`는 붙이기만 함) | 활성 계획 저장 + 기존 계획을 시나리오로 보존하는 트랜잭션 → 백엔드 원자 연산 검토 |
| mock 데이터 | `MockAppService.calculatePlanningDocument`·`compareScenarios`가 빈 resources/bottlenecks, summary calculation 0 | 시안 수준 fixture 필요(테스트·개발용) |

※ 이름 혼동 주의: `MockScenarioController`(app_service.dart)는 연결·스캔 상태 개발 패널용으로 **계획 시나리오와 무관하다**.

---

## 6. 사용자 확인이 필요한 모호점

1. **활성 계획 홈 레이아웃**: Detail 3종은 3섹션(400 / 864 / 1664)이다. 현재 활성 계획 홈은 5섹션(`planStudioDocument` element-1~5: 헤더 element-5, 컨트롤 element-4 분리)이다. "같은 화면 뷰 전환"을 지키려면 활성 계획 홈도 Detail 레이아웃으로 바꾸는지, 시나리오 보기만 이 레이아웃을 쓰는지 정해야 한다. 캔버스에 활성 계획 홈 시안은 없다.
2. **기준 계획 규칙 충돌**: List의 슬롯 A는 `활성 계획 · 기준 · 뺄 수 없습니다`로 고정이다. Compare에서는 `기준 계획` A~D를 고를 수 있다. 활성 계획이 항상 포함되는지(빼기 불가), 기준만 바뀌는지, 시나리오끼리만 비교할 수 있는지 확인이 필요하다. 현재 코드는 시나리오끼리 2개 비교를 허용한다.
3. **A↔B 상세 비교 화면**: 시안은 "둘만 담으면 A↔B 상세 비교(학생 목표 · 재화 · 병목 탭)"라고만 하고 그 화면의 새 시안은 없다. 기존 `PlanScenarioComparisonSection`의 2-pane UI를 그대로 유지하는지, 후보 목록 부분만 제거하는지 확인이 필요하다.
4. **delta 기준**: 재화 ±가 요구량 차이인지 부족량 차이인지 정해야 한다. Detail-All의 `쿠루미의 엘레프 −60`(부족 없음)은 요구량 차이로 보이고, 팝오버의 `−6`은 부족량 차이로 보인다.
5. **`끝까지 가는 학생`과 `필요량의 n% 확보`의 정의.** 2026-09-08 "이종 재화 합산 금지" 원칙과의 관계도 포함한다.
6. **단계 단위 차이**(`활성 계획과 다른 단계 3`, 단계 행 `이 시나리오에만`): 두 문서의 단계를 무엇으로 매칭할지 정해야 한다. 후보는 stage_id, (학생, 순번), 목표값이다.
7. **Compare 세로 넘침**: 섹션 높이가 1503으로 viewport 1392를 넘는다. 전체가 함께 스크롤되는지, 학생 목표 영역만 내부 스크롤되는지 정해야 한다. 학생이 9명보다 많을 때의 처리도 필요하다.
8. **스크롤바·포그 미표시**: 사용자 원칙은 기존 대각선 스크롤바와 포그를 재사용하는 것이다. 시안에는 그려져 있지 않으므로 List, Detail S2/S3, Compare에 기존 `PlanDiagonalScrollbar`를 적용한다고 가정해도 되는지 확인이 필요하다.
9. **`계획에 적용…` 선택지**: Flow-4-Save와 같은 3지선다(시나리오로 저장은 제외하고 "페이즈로 추가 / 활성 계획을 이걸로 바꾸기")인지 확인이 필요하다. "바꾸기" 때 기존 활성 계획을 시나리오로 자동 보존하는지도 정해야 한다.
10. **미리보기 비용**: 행을 선택할 때마다 compare가 1회 호출된다. 지연 표시(로딩)와 캐시 정책이 필요하다.
11. **ShortagePopover와 Flow-4 `.fly` 팝오버**(`부족량/단계별` 세그먼트가 있음)를 하나의 컴포넌트로 통합할지.
12. **헤더 부제 변경**(`육성 목표와 필요 재화` → `… · 시나리오`) 적용 여부. 사소한 문구 변경이다.

---

## 7. 그룹 D 구현 단위(vertical slice) 제안

선행 공통 의존
- **P-1 (M)** 공통 위젯
  - DeltaChip, ActiveDeltaKpiRow, ShortagePopover, ToggleSwitch(`.tog`), CompareSlots
  - S1 "보는 중" 모드 메뉴 골격(element-1 메뉴를 모드별로 교체)
- **P-2 (M, 백엔드 협의)** 계산 계약 정리
  - phase 진입/종료 의미 확정, `끝까지 가는 학생`·확보율 정의
  - `comparison` 타입 모델(fromWire 검증)
  - 활성 계획 요약 출처 결정
  - MockAppService fixture를 시안 수준으로 보강
- **P-3 (M)** 요약 행 3종(`PlanPrimaryBottleneckSummary` 등)을 상수에서 projection 연결로 전환. 활성 계획 화면과 공통이며, 다른 그룹(계획 홈/통계)과 조율이 필요하다.

슬라이스(권장 순서)
1. **D1 시나리오 목록 v2 (M)**: `PlanScenarioListSection` 수정.
   - 정렬 seg, 필터 칩, 검색, 오래된 개수, 펼침 행 + 행 액션(열기/복제/이름·설명/삭제: 서비스 재사용)
   - 활성 계획 고정 행, 비교 담기 체크박스 → S1 슬롯
   - 선행: P-1 일부. 테스트: planning_page_test 확장.
2. **D2 미리보기 섹션 (M)**: S3 신규 섹션 path, 선택 시 `getScenario` + `compareScenarios(active, s)`, 학생·단계 행, 분야별 최대 부족, ShortagePopover.
   - 선행: D1, P-1, P-2(활성 요약·delta 기준).
3. **D3 시나리오 보기 모드 + 병목 탭 (L)**
   - 읽기 전용 `viewing scenario` 상태 신설(스냅샷·복원 재사용), 3섹션 레이아웃
   - S2 단계 행 delta chip, S3 상단(세그먼트 + 칩 + 요약 + KPI 4개)
   - 병목 카드: 단계별 재화 묶음 + 지연 단계 + 하이라이트 연동
   - 선행: P-1~P-3, 모호점 1 결정.
4. **D4 페이즈별 탭 (M)**: 진입/필요/종료 + bar + delta. 선행: D3, P-2(진입/종료 의미).
5. **D5 전체 탭 (M)**: 열 수 2~5 그리드, 분야별 그룹, 크레딧 행, delta 마크. 선행: D3. `_PlanDiagonalTwoColumnGrid`를 일반화한다.
6. **D6 나란히 비교 4열 (L)**
   - 신규 동기 표 위젯, 기준 선택, 보기 토글 3개
   - N−1 쌍 비교 또는 다중 비교 프로토콜
   - 2개일 때 기존 A↔B 상세로 전환, 후보 목록 위젯 제거
   - 선행: D1(슬롯), P-2(다중 비교 결정). 테스트: plan_scenario_comparison_test 갱신.
7. **D7 계획에 적용… 확장 (S~M)**: 선택 다이얼로그. "바꾸기" 경로는 백엔드 원자 연산 여부에 따라 M이다.

난이도 합계 기준으로 D3과 D6이 가장 크다. D1→D2는 백엔드 변경이 거의 없어 먼저 착수할 수 있다(활성 요약을 클라이언트 계산으로 시작하는 경우).
