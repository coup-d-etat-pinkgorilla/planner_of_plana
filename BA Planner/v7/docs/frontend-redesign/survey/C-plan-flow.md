> 오케스트레이터 조사 보고서(2026-10-05, 읽기 전용 조사). 본문의 `/mnt/user-data/uploads/v7/`는 저장소 루트, `.../scratchpad/canvas/project/`는 `docs/frontend-redesign/prototype/2026-10-05/`에 해당한다. [확인]은 grep·파싱으로 확인한 사실, (추정)·[추정]은 해석이다. 결정은 `docs/frontend-redesign/decision-register.md`가 우선한다.

# 그룹 C — 계획 만들기 흐름 (학생 → 목표 → 단계 순서 → 계획/시나리오) 조사 보고서

조사 범위: `canvas/project/Flow-1-Students*.dc.html`(4), `Flow-2-Goals`, `Flow-3-Order*`(2), `Flow-4-Save`, 비교용 `Scenario-*`(5) / `frontend/lib` 계획 관련 Dart / `almanac/design` 계획 문서.
표기: **[확인]** = 파일에서 직접 grep·추출해 확인한 사실, **[추정]** = 확인한 사실에서 끌어낸 해석.
좌표는 모두 2560×1392 artboard 절대좌표(px). 페이지 헤더(AppShell 공용 compound header)는 전 artboard 공통으로 `(0,0,2560,184)`이며 아래에서는 생략한다.

---

## 0. 먼저 알아야 할 전제 (그룹 전체 공통)

1. **script 로직은 비어 있다. [확인]** 8개 Flow artboard와 5개 Scenario artboard 모두 `<script type="text/x-dc">` 본문이 `class Component extends DCLogic { renderVals() { return {}; } }` 한 줄뿐이다. `onclick` 등 inline handler 0개, `{{` 바인딩 0개. 즉 "interactive" 표시는 **CSS `:hover/:focus-within`로만 열리는 팝오버**(`.info .pop`, `.flyw .fly`, `.phw .php`)와 hover 색 변화가 전부이며, **상태 전이(단계 이동·드래그·선택 토글)는 각 정적 artboard 사이의 차이로만 표현**된다. 상태 머신은 아래 3절의 artboard 간 diff에서 재구성했다.
2. **애니메이션 [확인]**: Flow-1 계열에만 `@keyframes stuform2/3/4`(다중 형태 학생 초상 6s step-end 교차 표시, 예: 슌(수영복) 카드 `img.stuform2`)가 있다. Section intro/outro 방향 정보는 artboard에 **없다**(현재 코드의 `planSection*Motion` 같은 값은 시안에 대응값 없음).
3. **스크롤 [확인]**: Flow artboard 전부 `overflow:auto|scroll` 0건, 스크롤 포그(mask/gradient) 0건, 사선 스크롤바 0건. Flow-3-Order-Many의 도움말 문구("칸이 넘치면 줄이 바뀌고, 전체는 스크롤됩니다")로만 스크롤 의도가 있다.
4. **탭 위치 [확인]**: Flow·Scenario 모두 주 탭 `계획`이 `nt on`. Flow 헤더 제목은 `계획 만들기 / 학생 → 목표 → 단계 순서 → 저장`, Scenario 헤더는 `계획 / 육성 목표와 필요 재화 · 시나리오`. 즉 **계획 만들기 흐름은 계획 탭 안의 모드**이고, 계획 탭의 평상시 첫 화면은 Scenario-List다 [추정: canvas 페이지가 `plan`(계획 만들기)과 `scenario`(시나리오) 둘로 나뉘어 있고, 계획 탭 단독 "활성 계획 보기" artboard는 존재하지 않음].
5. **백엔드 소스는 로컬에 없다. [확인]** `/mnt/user-data/uploads/v7`에는 `AGENTS.md, README.md, almanac, frontend`만 있다. 프로토콜 판단은 Dart 클라이언트 검증 코드(`planning_protocol_client.dart`, `scenario_service.dart`, `repository_service.dart`, `planning_models.dart`)와 `mock_app_service.dart` 기준이다.

### 0-1. Flow 공통 3-Section 골격 [확인]

| Section | rect (x,y,w,h) | 형상 | 부착면 | 내용 |
|---|---|---|---|---|
| A 진행 레일 | (0, 209, 587, 1183) | 사다리꼴 (윗변 0→587, 아랫변 0→378, 오른쪽 80° 사선) | 왼쪽·아래 | 4단계 스텝퍼 + 요약 + 다음/이전 |
| B 본문 | (400, 209, 1702, 1183) | 평행사변형 (양쪽 80° 사선, 위 x+209 오프셋) | 아래 | 단계별 본문 |
| C 보조 | (1920, 209, 640, 1183) | 사다리꼴 (왼쪽 80° 사선) | 오른쪽·아래 | 단계별 보조 패널 |

- [추정] 96×96 grid(가로 26.67px, 세로 헤더 아래 1208px/96≈12.6px)로 환산하면 A≈(0,2,22,94) trapezoid-left, B≈(15,2,64,94) parallelogram-bottom, C≈(72,2,24,94) trapezoid-right. 현재 `planStudioDocument`(S1 `(0,2,37,92)`, S2 `(12,2,29,94)`, S3 `(45,2,42,92)`, S4 `(89,14,7,80)` triangle-right, S5 `(53,1,42,14)`)나 `planStarterStudioDocument`(element-3 `(0,2,27,62)`, element-5 `(0,66,22,28)`, element-6 `(21,2,21,92)`, element-7 `(76,3,20,90)`)와 **어느 것과도 일치하지 않는 새 Studio 문서**가 필요하다.
- A의 공통 내용 [확인]:
  - 제목 `계획 만들기` + (i) 팝오버: "아래 네 단계는 순서와 상관없이 언제든 눌러서 이동할 수 있습니다 / 학생 탭 *이 학생 목표 정하기* → 2단계 / 계획 탭 페이즈 *순서 바꾸기* → 3단계 / 시나리오 *이걸로 새로 만들기* → 1단계".
  - **스텝 버튼 4개** `a.btn` (14,287,537×84)·(14,383,520×84)·(14,479,503×84)·(14,575,486×84) — 80° 레일을 따라 폭이 17px씩 줄어드는 사다리꼴, 사이에 2×12 연결선. aria `1단계 학생 고르기`…`4단계 계획으로 만들기`. 각 버튼은 번호·제목·부제(예 `3명 · 여러 명 모드`, `3명 중 2명 완료`, `단계 7개 · 순서 3칸`, `시나리오 또는 활성 계획`)·상태(`지금`=`sel-pink`, `완료`=`done`, `남음`=`ghost`).
  - **"지금까지 만든 것" 요약 4행** ghost 버튼 (14,713)~(14,851) 폭 462→438: `학생 n명 / 단계 n개 / 필요 크레딧 / 부족 재화 n종`. 마지막 행은 `.flyw` 플라이아웃(aria `부족 재화 자세히 보기`)으로 오른쪽에 420px 팝오버: `부족량 | 단계별` 세그먼트, 재화 행(아이콘·이름·`−30`·`보유 66 / 필요 96`·`2단계` 칩), "항목을 누르면 그 재화가 들어가는 단계로 이동합니다", `인벤토리에서 보기`.
  - **하단 버튼** primary (14,1260,365×56) `다음 · …` / secondary (14,1324,354×48) `그만두기`(1단계) 또는 `이전 · …`(2~4단계). 4단계 primary는 `저장하고 닫기`.

---

## 1. Flow-1-Students — 계획 만들기 1 · 학생 고르기 (기본, 3명 · 여러 명 모드)

### 1.1 목적·섹션
여러 학생을 고른 순서대로 계획에 넣는다. A/B/C 골격 그대로.
- B (400,209,1702×1183) 평행사변형:
  - 제목줄 (636,229,1425×40): `계획에 넣을 학생 / 3명 골랐습니다` + 세그먼트 `한 명 | 여러 명`.
  - 검색·필터 바 `div.row` (614,281,1449×44) 사선: 검색 `이름, 학교, 역할`, 빠른 칩 `계획에 없는 학생만`·`보유만`, 적용 중 칩 `밀레니엄 ×`·`레벨 70~90 ×`, 버튼 `필터 · 3`(aria `필터 열기 · 적용 3`).
  - 학생 그리드 (417,353,1648×1013) 사선 container: `button.stucard` 48개(8열×6행, 열 간격≈180px, 행 간격≈170px, 행마다 30px씩 왼쪽으로 밀려 80° 레일을 따름). 카드 배지: 공격/방어 타입, 선택 순서 번호 원(26×26, `1`,`2`,`3`), `UNOWNED`, `PLAN`, `JP`.
- C (1920,209,640×1183) 사다리꼴:
  - `고른 학생` + (i): "고른 순서대로 *목표 정하기* 탭에 놓입니다. 그리드에서 카드를 한 번 더 누르거나 × 를 누르면 빠집니다."
  - 선택 행 `div.row` 3개 (2128,279,410×70)…: 번호·초상·이름·`Lv.78 · ★3 · 스킬 3/7/7/4`, 미보유는 `미보유 · 모집 후 목표 적용`, aria `… 빼기`.
  - `내 그룹` + (i) "학생 탭이나 여기서 직접 만든 묶음… 누르면 그룹 학생이 한꺼번에 선택되고, 이미 고른 학생은 그대로 둡니다." + `지금 고른 학생으로 그룹 만들기`; 그룹 행 `button.row` 3개 (`총력전 · 신비 딜러 6명`, `전술대항전 방어덱 6명`, `장기 육성 4명`).
  - `역할군으로 한꺼번에` 칩 7개(카운트 포함: 스트라이커 102/스페셜 26/탱커 21/딜러 63/힐러 14/서포터 26/T.S 4).
  - 상태 행 `딜러 63명 · 필터를 그리드에 적용 중` + `보이는 학생 모두 고르기`.
  - `최근 본 학생 6명` 행.

### 1.2 요소
- **StepRail**(A 공통), **SummaryFlyout**(부족 재화 플라이아웃), **SearchFilterBar**, **StudentCard+OrderBadge**, **SelectedStudentRow**(번호·초상·요약·×), **GroupRow**, **RoleChipBank**, (i) **InfoPopover** 3개.

### 1.3 상태·상호작용 (변형 artboard diff)
| artboard | 차이 |
|---|---|
| Flow-1-Students | 3명, 여러 명 모드. C=목록형 선택 행(번호 1~3, 상세 요약) |
| Flow-1-Students-Many | 14명. A: `학생 14명 / 단계 0개 / 필요 크레딧 — / 부족 재화 —`, 2단계 부제 `14명 중 0명 완료`. 그리드 카드 크기 확대(210×179). **C가 압축 그리드로 전환**: 86×70 카드에 순서 번호(21×21)·× 버튼(22×22, aria `… 빼기`), 정렬 세그먼트 `고른 순서 | 이름 | 학교`, `모두 비우기`, 경고 `미보유 1명 · 이미 계획에 있는 학생 2명`, `이 14명을 그룹으로 저장`. 내 그룹/역할군/최근 본 학생 영역은 그대로 아래에 유지 |
| Flow-1-Students-One | 1명, 한 명 모드. B 폭 1595로 축소 (400,209,1595×1183). C가 **짧은 사다리꼴** (1955,209,605×352)로 바뀌고 그 아래 (1785,559,802×836)에 **학생 탭과 같은 상세 인디케이터**(LEVEL/Position/Class/Weapon, SKILL SUMMARY, EQUIPMENT, Ability Release, 심상개화, STATS, 인연 20 게이지) 오버레이. C 내용: `선택한 학생` + (i) "한 명만 고르면 학생 탭과 같은 자리에 상세 인디케이터가 뜹니다. 여기 보이는 값이 *지금 상태*의 값이 됩니다…", 학생 행 `리오(무장) 밀레니엄 · 스트라이커 · 폭발 / 특수 | 학생 탭`, `이미 잡혀 있는 목표` 2행(`P1 · 1단계 Lv.90 · EX 4 지금 가능`, `P2 · 2단계 장비 T10 ×3 부족 1종`), primary `이 학생 목표 정하기`. A의 2단계 부제 `리오(무장) · 설정 중`, 요약 `단계 2개 / 21.6M / 부족 1종` |
| Flow-1-Students-Filter | Flow-1-Students 위에 **전면 scrim**(`rgba(6,10,16,.8)` + blur 2px, z 9000) + 필터 팝업 3 Section(아래 1.5) |

### 1.4 현재 코드 대응
| 시안 요소 | 현재 코드 | 분류 | 근거 |
|---|---|---|---|
| 학생 고르기 화면 전체 | `PlanStudentSelector` (`plan_student_selector.dart`) | **수정(대폭)** | 이미 다중 선택·순서 유지(`List<String> _selectedStudentIds`, `_toggleStudent`, `_confirmSelection` → `List<PlanningStudentSeed>`), 계획 전용 필터 `ownership`(보유 상태)·`plan_status`(계획 상태) 존재. 그러나 그리드가 `planStudentSelectorGridColumns = 4`, `StudentDiagonalGrid(selectedIds: Set)`로 **순서 번호 배지 불가**, C 패널(고른 학생/그룹/역할군/최근) 없음, Section 1 유지·두 패널 260° 퇴장 구조 |
| 학생 그리드 카드 | `StudentDiagonalGrid` (`student_section_layout.dart`) | 수정 | `selectedIds: Set<String>`만 받음 → 선택 순서(int) 파라미터 추가 필요. PLAN/UNOWNED 배지는 `plannedIds`,`ownedIds`로 이미 공급 |
| 한 명 모드 상세 인디케이터 | 학생 탭 상세 인디케이터(그룹 B 범위, `student_section_layout.dart`) | 재사용 | (i) 문구가 "학생 탭과 같은 자리"를 명시 |
| 한 명 모드 `이미 잡혀 있는 목표` | 없음 | 신규 | 활성 계획 문서에서 해당 학생 stage+phase를 뽑아 표시 — 활성 계획 문서가 영속되지 않는 현재 상태에선 데이터 원천 부재(5절) |
| 내 그룹 / 그룹 저장 | 없음 (`studentgroup`, `내 그룹` grep 0건) | 신규 | 저장소 필요 |
| 최근 본 학생 | 없음 (grep 0건) | 신규 | 로컬 상태로 충분할 수도 있음 |
| 역할군 일괄 선택·보이는 학생 모두 고르기 | 없음 | 신규 | 클라이언트 로직(카탈로그 metadata로 가능) |
| StepRail(A) | 없음. 현재 계획 메인 Section 1은 버튼 6개(`페이즈 만들기`, `학생 추가`, `프리셋 생성·관리`, `시나리오 비교`, `시나리오 생성`, `시나리오 리스트`; ValueKey `plan-phase-editor-launch` 등) | **신규**(현 Section 1 버튼 묶음은 폐기 대상) | 흐름 진입/이동 모델이 완전히 다름 |

### 1.5 Flow-1-Students-Filter (필터 팝업)
- Section [확인]:
  - 헤더 바 (454,206,1876×92) 평행사변형(작은 깊이 16px): `필터 24 / 170명`, 적용 칩 `밀레니엄 · 계획에 없는 학생만 · 레벨 70~90`, 버튼 `프리셋`·`초기화`·`적용`(pri).
  - 왼쪽 `속성` (286,320,984×930) 평행사변형(깊이 164): "같은 줄은 "또는", 줄끼리는 "그리고"". 그룹: 학교(13, 학교별 카운트), **계획 · 계획 만들기 전용**(`계획에 없는 학생만` / `다른 계획에 있는 학생 포함` / `목표를 이미 채운 학생 숨기기`), 초기 성급, 공격 타입, 방어 타입, 편성, 역할, 포지션, 보유·서버(`보유 / 미보유 / 일본 서버 전용 제외`).
  - 오른쪽 `성장 범위` (1128,320,1182×930) 평행사변형: "한 줄에서 최소 ~ 최대 · 좁힌 항목만 분홍", `범위 모두 풀기`. `div.srow` 행(좁힌 행은 `sel`): 학생 레벨 70~90(sel), 성급 `학생 ★ + 전용무기 ★` ★3~무기★1(sel), 전용무기 레벨, 인연 랭크, EX/기본/강화/서브, 장비 티어(3칸 중 가장 낮은 칸), 장비 레벨(가장 낮은 칸), 애장품 T0~T2, 추가 능력치(HP·ATK·HEAL 합) 0~25, 심상개화(상관없음/개방/미개방, "v7 "준비 중" 자리").
- 대응: 학생 탭 `Student-Filter.dc.html`(그룹 B)와 동일 구조 + "계획" 칩 그룹만 추가 [canvas 제목 "필터 팝업 (계획 칩 그룹 포함)"]. 현재 범위 필터는 `StudentRangeConditions`(`student_range_condition_section.dart`) — **lower/upper 전체 on/off 2개 + 키별 값** 모델이라 시안의 "행마다 최소~최대, 좁힌 행만 강조", "3칸 중 가장 낮은 칸", "HP·ATK·HEAL 합", "학생★+무기★ 합성 축" 표현과 맞지 않는다 → **수정(모델 변경)**. 필터 프리셋(`프리셋` 버튼)은 신규.

### 1.6 데이터 요구
- 카탈로그·보유·현재값: `AppService.listStudents()`, `RepositoryService.loadRepositoryState()` — **충분** [확인].
- 학교별·역할별 카운트: 카탈로그 metadata로 클라이언트 집계 [추정].
- 계획 상태 3종(`계획에 없는 학생만`/`다른 계획에 있는 학생 포함`/`목표를 이미 채운 학생 숨기기`): "다른 계획" = 시나리오들의 `PlanningScenarioSummary.studentIds`로 가능, "목표를 이미 채운 학생"은 현재값 ≥ 최종 목표 비교가 필요 → 활성 계획 문서 필요(5절).
- 내 그룹/필터 프리셋: **repository 신규 메서드 필요**(현재 `repository.*` 메서드 목록에 없음: profile.*, state.get, students.update, inventory.update, goals.save, migration.*, scenario.* 뿐 [확인]).
- A 요약(필요 크레딧·부족 재화 n종)과 플라이아웃: 1단계 시점에도 값이 있으므로 **초안 문서를 매번 `planning.document.calculate`로 계산**해야 함. 단 v1 문서는 모든 stage가 phase 안에 있어야 하므로(아래 4.3) 순서 미정 초안용 임시 phase 배치 규칙이 필요 [추정].

### 1.7 모호점
- C 패널이 3명(목록형)↔14명(압축 그리드형)으로 바뀌는 **전환 임계값**이 시안에 없다.
- 한 명 모드에서 B 폭·C 형상이 바뀌는데(1702→1595, C 높이 352) 모드 전환 애니메이션 정의 없음.
- 그리드 48장 이상일 때 스크롤 표현(사선 스크롤바·포그)이 시안에 없다 — 기존 `StudentDiagonalGrid` 사선 스크롤을 그대로 쓸지 확인 필요.
- `미보유 · 모집 후 목표 적용`: 미보유 학생의 "지금 상태" 기준값(현재 `planElementCurrentTargets`는 seed currentValues 없으면 최소값) — 시안 Flow-3에서 슌 1단계가 `모집 · Lv.80 / 엘리그마 80`으로 **모집(★ 획득) 자체를 단계 목표로** 표시. 현재 `planningDocumentTargetKeys`에 "보유/모집" 키 없음 → 엘리그마 비용 계산이 `student_star` 증가로 표현 가능한지 백엔드 확인 필요.

---

## 2. Flow-2-Goals — 계획 만들기 2 · 목표 정하기 (단계로 나누기)

### 2.1 목적·섹션
학생별로 **누적 절대 목표 단계(1단계, 2단계, 3단계…)** 를 만든다. A: 1단계 `완료`, 2단계 `지금`, 하단 `다음 · 단계 순서` / `이전 · 학생 고르기`.
- B (400,209,1702×1183):
  - 학생 탭 줄 (622,229,1450×50) 사선: `호시노 설정 중 | 리오(무장) 완료 | 슌(수영복) 미설정`.
  - 프리셋 바 (624,291,1425×44): `단계 프리셋` 세그먼트 `총력전 3단계 · 내 프리셋 | 기본 육성 2단계 | 한 번에 MAX | 직접 입력`, 버튼 `지금 구성을 프리셋으로`, (i) "단계 여러 개를 한 묶음으로 저장해 두고 불러옵니다. 불러온 뒤 칸마다 값을 고칠 수 있고, 목표가 현재보다 낮은 항목은 자동으로 현재 값에 맞춰집니다."
  - **단계 카드 열** (모두 사선 평행사변형, 높이 716):
    - `지금 상태` (483,351,398×716) "스캔 기준 · 고칠 수 없습니다" — LEVEL/WEAPON, SKILL SUMMARY(EX/Normal/Passive/Sub), EQUIPMENT(티어+Lv/최대), ABILITY(HP|ATK|HEAL), COST "오른쪽에 단계마다 드는 재화가 나옵니다".
    - `1단계 성장 기반 · 지금 가능 · 크레딧 18.2M · 설계도 170` (772,351,473×716)
    - `2단계 스킬 · 인연 · 부족 2종 · 노트 96 · BD 18 · 오파츠 52` (1135,351,473×716)
    - `3단계 성급 · 전용무기 · 부족 1종 · 엘레프 120 · 크레딧 1.8M` (1498,351,473×716)
    - 각 카드 COST 블록: 재화별 `필요 / 충분|−부족`.
    - `단계 추가` 세로 버튼 (1861,351,190×716).
  - 스테퍼 aria(카드당 1세트×3): `레벨 올리기/낮추기`, `전용무기 올리기/낮추기`, `인연 올리기/낮추기`, `EX/Normal/Passive/Sub 올리기/낮추기`, `장비 1~3 티어 올리기/내리기` [확인].
  - `호시노 · 현재 → 최종` 줄 (479,1087~1217): LEVEL 78→90, STAR ★3→★5, WEAPON —→Lv.30, SKILL 3/7/7/4→5/M/M/7, EQUIPMENT T8/T8/T7→T9×3, BOND 20→30 + 진행 막대. (i) "마지막 단계까지 끝났을 때의 모습…".
- C (1920,209,640×1183): `단계 프리셋` + (i) "프리셋은 학생과 상관없이 단계 구성만 담습니다. 학생에게 적용하면 그 학생의 현재 값에서 시작해 목표만 채웁니다." 프리셋 행 3(`총력전 3단계 · 적용 중 · 성장 기반 → 스킬·인연 → 성급·전용무기`, `기본 육성 2단계 · Lv.90·장비 T9 → 스킬 M`, `전술대항전 1단계 · EX 5 · 장비 T10`), `다른 학생에도 적용`(학생별 행: `리오(무장) 기본 육성 2단계 · 완료 | 바꾸기`, `슌(수영복) 프리셋 없음 | 총력전 3단계 적용`), `고른 3명 모두 총력전 3단계로`, 요약 `이 학생 재화 11종 · 새로 부족 3종`.

### 2.2 요소
**StudentTabStrip**(상태 3종), **PresetSegment**, **StageCard**(지금 상태 읽기전용 변형 포함; 내부 Level/Weapon, SkillSummary, Equipment, Ability, Cost 블록), **AddStageColumnButton**, **CurrentToFinalStrip**, **PresetRow**, **PerStudentPresetRow**, InfoPopover.

### 2.3 상태·상호작용
- 변형 artboard 없음. 학생 탭 상태 `설정 중/완료/미설정`, 단계 카드 상태 `지금 가능/부족 n종`, 프리셋 행 `적용 중`이 정적으로 표현됨.
- Flow-2에 **성급(★) 스테퍼 aria가 없다**. 그런데 3단계 카드 제목이 "성급 · 전용무기"이고 현재→최종에 ★3→★5가 있음 [확인] → 성급 편집 컨트롤 누락 또는 WEAPON 블록에 포함된 것으로 보임 [추정].
- 장비 **레벨**·애장품(equip4)·ABILITY 스테퍼 aria가 없다(장비는 티어만, ABILITY는 0|0|0 표시만) [확인].

### 2.4 현재 코드 대응
| 시안 | 현재 | 분류 | 근거 |
|---|---|---|---|
| 단계 개념 | `PlanElementStageDraft {id, name, targets}` (`planning_models.dart`) | **그대로 재사용** | lessons 문서 확정 계약: "단계는 누적 절대 목표 snapshot… 새 단계는 선택 단계 바로 뒤에 snapshot 복제… 이전 단계 값을 올리면 이후 단계 자동 상향" (`plan-element-builder-lessons-2026-08-02.md` §단계와 프리셋의 확정 계약). 시안의 1·2·3단계 = 동일 개념 |
| 지금 상태 + 단계 카드 + 단계 추가 | `PlanElementBuilder` (`plan_element_builder.dart`: Section 3 현재 상태 읽기전용, Section 6 단계 카드 `PlanPresetElementCard`, `_CompactTargetStepper`, `_StarTargetStrip`, `_PresetEquipmentEditor`, `_PresetFavoriteItemSlot`) | **수정** | 카드를 가로 열 배치로 재구성, 카드 헤더에 단계 이름·상태·비용 요약 추가, COST 블록 신규. 현 카드는 장비 레벨·애장품·스탯 편집까지 있음 → 시안에서 빠진 것인지 확인 필요 |
| 학생 탭 줄 | `_builderStudentQueue` / `_builderStudentQueueIndex` (`plan_section_layout.dart`) | 수정 | 현재는 큐를 순서대로 `onConfirm`할 때만 다음 학생으로 넘어감(`_confirmPlanElementStages`). 시안은 자유 탭 이동 + 학생별 상태(설정 중/완료/미설정) |
| 프리셋 로더 | `_PlanPresetLoaderDiagonalList` / `PlanPresetDiagonalList` (builder Section 5) | 수정 | 세그먼트 + C 패널로 재배치 |
| `한 번에 MAX`, `직접 입력` | 없음 (MAX 배지 `_MaxBadge`는 필드 단위) | 신규 | 일괄 MAX 프리셋 |
| `지금 구성을 프리셋으로` | `PlanPresetManager._save` 경로 존재(별도 관리 화면) | 수정 | 흐름 안 바로 저장 |
| 다른 학생에도 적용 / 고른 n명 모두 | 없음 | 신규 | 프리셋 sparse 승계 규칙(`planElementCurrentTargets` + normalize)으로 클라이언트 계산 가능 [추정] |
| 미배정 요소 목록(Section 7, `_UnassignedDiagonalList`, `PlanElementUnassignedItem`) | 있음 | **폐기 대상** | 시안 Flow-2에 대응 영역 없음. 미배정 상태는 Flow-3 "나중에" 칸이 대신함 [추정] |
| 현재 → 최종 | 없음 | 신규 | targets 마지막 단계 vs 현재값, 클라이언트 계산 |

### 2.5 데이터 요구
- 단계 targets: 기존 19개 키(`planningDocumentTargetKeys`) — 충분 [확인].
- **단계별 비용(COST)**: `planning.document.calculate` 응답의 `stage_results[].cost/resources`가 존재 [확인: mock이 `stage_results`에 `cost`,`resources` 반환]. 현재 UI는 `phase_results`·`overall`·`bottlenecks`만 소비하고 `stage_results`는 미사용 [확인: `_calculateDocument`]. → 클라이언트 매핑만 추가.
- 단계 상태 `지금 가능/부족 n종`: 2단계 시점엔 순서(phase)가 없다 → **어떤 재고 기준으로 판정하는지 시안 미정**(단독? 그 학생 단계만 순차?).
- **프리셋 영속화: 없음.** `defaultPlanElementPresets = []`, 주석 "Persistence is deferred until the v6 user-data migration supplies the repository/protocol boundary" [확인]. `PlanElementPreset {id, name, isDefault, stages: List<Map<String,int>>}` — **단계 이름 필드가 없다**. 시안은 프리셋이 단계 이름(`성장 기반 → 스킬·인연 → 성급·전용무기`)을 담음 → 모델에 stage name 추가 + repository `preset.*` 신규 메서드 필요.

### 2.6 모호점
- 성급 컨트롤 위치, 장비 레벨/애장품/스탯 편집 제거 여부.
- 단계 이름(`성장 기반` 등)을 사용자가 어디서 편집하는지 시안에 없음(프리셋 적용 시 자동?).
- 2단계 시점 단계별 `지금 가능/부족` 판정 기준.
- `목표가 현재보다 낮은 항목은 자동으로 현재 값에 맞춰집니다`는 현 계약과 일치하나, "이후 단계 자동 상향"(현 계약)이 카드 간에도 유지되는지 명시 없음.

---

## 3. Flow-3-Order / Flow-3-Order-Many — 계획 만들기 3 · 단계 순서 (선행 관계)

### 3.1 목적·섹션 (Flow-3-Order)
모든 학생의 단계를 **우선순위 칸(lane)** 에 배치한다. A: 1·2단계 `완료`, 3단계 `지금`, `다음 · 계획으로 만들기` / `이전 · 목표 정하기`.
- B:
  - 제목 `단계 순서 정하기` + (i) `단계 순서 정하는 법`: "카드를 끌어 *1순위 · 2순위 · 3순위 · 나중에* 칸을 옮깁니다. 카드 아래쪽 점을 다른 카드로 끌면 *먼저 끝나야 하는 단계* 가 이어집니다. 같은 학생의 단계는 자동으로 이어지고, **선행 단계보다 앞 칸에는 놓을 수 없습니다.** **칸이 그대로 계획의 페이즈가 됩니다.**" [확인 원문]
  - 칸(`div.tile`, 1479×214, 80° 레일 따라 40px씩 왼쪽): `1순위 · 모두 지금 가능` (583,285), `2순위 · 부족 3종` (543,513), `3순위 · 부족 1종` (503,741), `나중에 · 아직 급하지 않은 단계를 여기로` (`div.plain` 474,969,1468×150, 빈칸 `여기로 끌어다 놓기`).
  - 단계 카드 `button.srow` 398×150 사선: `학생 · n단계 · 목표 요약 · 비용 요약 · 상태(가능/부족/막힘)` (예 `호시노 3단계 · ★5 · 전용무기 2성 · 엘레프 120 부족 · 막힘`).
  - **연결선 SVG**(2560×1392 오버레이, pointer-events none): 같은 학생 = 회색 실선 곡선+화살촉, 직접 이은 선행 = 분홍 점선(`stroke-dasharray 7 5`)+화살촉. 범례 (442,1348) `같은 학생 · 자동` / `직접 이은 선행 조건`.
- C (선택 카드 상세): `호시노 2단계` / `포함한 목표 EX 3→5 · 기본 7→M · 강화 7→M · 인연 20→30` / `먼저 끝나야 하는 단계`: `호시노 1단계 · 자동`, `리오(무장) 1단계 · 노트 먼저 쓰기`(aria `선행 조건 지우기`) / `선행 단계 추가` / `이 칸(2순위)에서 부족한 재화` 3행 / `자동으로 정렬`: `부족이 적은 단계부터 · 지금 가능한 단계를 앞 칸으로`, `고른 학생 순서대로 · 호시노 → 리오 → 슌`, `학생마다 한 단계씩 · 모두 1단계 → 모두 2단계`.

### 3.2 Flow-3-Order-Many (30단계, 14명)
- (i) `많을 때`: "단계가 12개를 넘으면 자동으로 *작게* 보기로 바뀝니다. 선은 고른 카드와 이어진 것만 그립니다. 나머지 카드는 흐려집니다. 칸이 넘치면 줄이 바뀌고, 전체는 스크롤됩니다."
- 툴바 (633,279,1413×34): `단계 30개`, 세그먼트 `크게 | 작게`, 토글 `학생별 묶음`, `학생 +6`, `부족 있는 단계만`, `호시노 선택 중 ×`.
- 큰 container (436,325,1620×1011) 하나 안에 칸 4개, 단계는 **컴팩트 칩** 204×44 (aria `호시노 1단계` 등, `cursor:grab` 29건 [확인]). 칸 헤더: `1순위 단계 14개 부족 없음`, `2순위 단계 10개 부족 3종`, `3순위 단계 2개 부족 2종`, `나중에 단계 4개`. 선택 카드만 398×150 확장 srow (aria `호시노 2단계 (선택됨)`).
- 범례에 상태색 `가능 | 부족 | 막힘` 추가.
- A: `단계 30개 · 순서 3칸`, `212.4M`, `부족 재화 9종`.

### 3.3 현재 코드 대응
| 시안 | 현재 | 분류 | 근거 |
|---|---|---|---|
| 칸 = 페이즈 | `PlanPhaseEditor<T>` (`plan_phase_editor.dart`), `PlanPhaseEditorGroup{id,name,items}`, 드래그(`_PhaseInsertionTarget` DragTarget, 삽입선) | **수정(대폭)** | 이미 "단계 → 페이즈 배정 + 드래그 + 페이즈 내 재정렬" 기능 보유. 레이아웃(현재 Section 1~4: 요소 목록/미배정/페이즈 이름 목록/페이즈 카드)은 시안의 가로 lane 보드와 전혀 다름 |
| 같은 학생 단계 순서 강제 | `PlanPhaseEditorItem.sequenceGroup/sequenceIndex` + `_sequenceOrderIsValid` (위반 시 스낵바 "같은 학생의 단계 순서를 지켜 배치하세요.") | **재사용** | 시안 "같은 학생의 단계는 자동으로 이어지고"와 동일. 단, 현 검증은 `index <= previous`면 거부 → 같은 페이즈 안에서도 학생 단계가 순서대로면 허용됨. 시안은 같은 학생 단계가 항상 다른 칸에 있음(같은 칸 허용 여부 미정) |
| 직접 이은 선행 조건(교차 학생) | **없음** | **신규** | 모델·편집기·프로토콜 어디에도 prerequisite 필드 없음 (`PlanningDocumentStage.fromWire`가 키 4개만 허용) |
| `나중에` 칸 | 미배정 목록(`_PhaseUnassignedSection`) 개념은 있으나 "미배정이 0개일 때만 완료 활성화" | 수정 | 시안은 나중에 칸을 둔 채로 다음 단계로 진행 가능 |
| 연결선 오버레이·크게/작게·학생별 묶음·흐림 | 없음 | 신규 | |
| 자동 정렬 3종 | 없음 | 신규 | 클라이언트 알고리즘. "부족이 적은 단계부터"는 단계별 부족 데이터 필요 |
| 칸별/단계별 상태(가능/부족/막힘, 부족 n종) | `planning.document.calculate`의 `phase_results`, `bottlenecks[]{stage_id, affected_stage_ids, phase_number, remaining_at_entry, required_at_entry, shortage}` 소비 코드 있음(`_calculateDocument`) | 수정 | [추정] `부족` = bottleneck의 `stage_id`, `막힘` = 다른 병목의 `affected_stage_ids`에 포함(선행 단계 때문에 지연). 호시노 3단계가 자체 부족(엘레프)이 있으면서 `막힘`인 것도 이 해석과 모순되지 않음 |
| 단계 카드 | `PlanStudentStepTile` / `PlanStudentStepPreview{studentId, displayName, step, target, bondRank, stageId, targetValues}` | 수정 | 시안 카드엔 상태·비용 요약이 추가됨 |

### 3.4 핵심 질문 답: "단계로 나누기 / 선행 관계"가 현 모델에 있는가
- **단계(stage)로 나누기: 이미 있다. [확인]** `PlanningDocumentStage {stage_id, student_id, name, targets}`가 학생별 여러 개 존재 가능하고, `PlanningDocument.fromWire`는 문서 순서상 같은 학생 stage의 targets가 **감소하면 `Planning document stage regresses`로 거부**한다. 즉 "같은 학생 단계의 묵시적 선행"은 **문서 내 순서(phase 순서 → phase 내 stage 순서)** 로 이미 표현된다.
- **칸 = 페이즈: 이미 있다. [확인]** `PlanningDocumentPhase {phase_id, name, stages}`. "1순위/2순위/3순위" = phases[0..2].
- **직접 이은 선행 조건(교차 학생): 없다. [확인]** v1 wire는 `stage`에 정확히 4키, `phase`에 3키, 문서에 5키(`version, document_id, name, kind, phases`)만 허용하는 **엄격 검증**이라 필드를 덧붙이면 클라이언트 자신이 응답/문서를 거부한다. → **`version: 2` 문서 또는 별도 authoring 메타 저장소 필요.** 최소안 [추정]: stage에 `prerequisites: [{stage_id, note}]`(시안의 `노트 먼저 쓰기`처럼 사유 라벨 포함) + 검증 규칙 "prerequisite stage의 phase index < (또는 ≤) 자신의 phase index".
- **"선행 단계보다 앞 칸 불가"** 는 클라이언트 편집 규칙으로 구현 가능(현 `_sequenceOrderIsValid` 확장). 같은 칸 허용 여부는 확인 필요(아래 모호점).
- **`나중에` 칸: 없다.** v1에는 phase에 속하지 않은 stage를 담을 자리가 없다. Flow-4 미리보기는 1~3순위만 P1~P3로 만들고 나중에 칸을 언급하지 않음 → (a) 저장 시 제외, (b) 마지막 phase로 저장, (c) 문서 v2에 `deferred_stages` 추가 중 결정 필요. Flow-4 문구 "학생·목표·단계는 한 묶음으로 남아서, 나중에 1~3단계 어디로든 돌아와 고칠 수 있습니다"는 (c)를 시사 [추정].

### 3.5 데이터 요구
- 칸별 부족 n종, `이 칸에서 부족한 재화`(−18 등): `phase_results[].resources` + 보유. 단 현재 Dart는 phase resource에서 `required`, `owned`만 읽는다 [확인: `_consumptionResource`]. "이 칸에서 부족" = **진입 잔량 기준**이어야 하는데(Scenario-Detail-Phase의 `진입/필요/종료`, Flow-4 팝오버 "앞 페이즈에서 쓰고 남은 양 기준입니다"), phase resource에 진입 잔량 필드가 있는지 Dart 측에서 확인 불가(백엔드 소스 부재). `bottlenecks[]`에만 `remaining_at_entry`가 있다 → **백엔드 응답 스키마 확인 또는 phase resource에 `remaining_at_entry/remaining_at_exit` 추가 필요**.
- 선행 조건을 계산에 반영하려면(예: 노트를 리오 1단계에 먼저 배분) **phase 내 stage 순서가 소비 순서인지** 백엔드 규칙 확인 필요. 현재 projection은 phase 진입 시점 단위(`phase_number`, `remaining_at_entry`)로 보이며 phase 내 우선순위 의미는 Dart 코드로는 확인 불가.

### 3.6 모호점
- 선행 단계와 **같은 칸**에 둘 수 있는가("앞 칸 불가"만 명시). 같은 학생 단계가 같은 칸에 있으면 현 검증은 허용.
- `순서 3칸` 표기 vs 실제 칸 4개(나중에 포함). 칸 추가/삭제/이름 변경 UI가 시안에 없다 — 현 페이즈 편집기는 페이즈 생성·제거·인라인 이름 편집을 지원하고, Scenario-Detail은 `리오 먼저 / 스킬 마무리 / 호시노 완성` 같은 **이름 있는 페이즈**를 보여 줌. 흐름에서 페이즈 이름을 어디서 정하는지 불명.
- 드래그 거부 시 피드백(현재 스낵바) 표현 없음.
- `막힘`의 정확한 정의.
- 12개 초과 시 자동 `작게` 전환 후 사용자가 `크게`로 되돌릴 수 있는지(세그먼트는 있음).

---

## 4. Flow-4-Save — 계획 만들기 4 · 계획/시나리오로 저장

### 4.1 목적·섹션
A: 1~3단계 `완료`, 4단계 `지금`, primary `저장하고 닫기`, `이전 · 단계 순서`.
- B:
  - `이렇게 만들어집니다 · 페이즈 3개 · 단계 7개`.
  - 페이즈 행 `div.srow` 1458×92 ×3 (605,285)/(587,389)/(568,493): `P1 페이즈 1 · 1순위 칸에서 · 호시노 1단계 · 리오(무장) 1단계 · 슌(수영복) 1단계 · 모두 지금 가능 · 재화`. 각 행은 `.phw` 팝오버(aria `페이즈 n 필요 재화 보기`): `Pn 필요 재화 · 부족 n종`, 재화 행 `필요 90 −14`, 크레딧 `필요 27.6M 여유 41.2M`, "앞 페이즈에서 쓰고 남은 양 기준입니다", `인벤토리에서 보기`.
  - `지금 활성 계획과 비교` 타일 (539,643,1461×110): `계획 충족률 72% → 64% · 부족 재화 14 → 17종 · 필요 크레딧 186M → 234M · 학생 9 → 12명`.
  - `가장 크게 늘어나는 재화` 3행: `기술 노트 (최상급) +96 · 부족 −12 → −30`, `크레딧 +48.2M · 여유 있음`, `설계도 · 시계 +90 · 부족 0 → −14`.
- C: `어디에 넣으시겠습니까` + (i) `저장`: "어느 쪽을 골라도 학생·목표·단계는 한 묶음으로 남아서, 나중에 1~3단계 어디로든 돌아와 고칠 수 있습니다." 선택 행 3: `시나리오로 저장 · 활성 계획은 그대로 두고 따로 비교합니다` / `활성 계획에 페이즈로 추가 · 지금 P2 뒤에 P3~P5로 붙입니다` / `활성 계획을 이걸로 바꾸기 · 기존 페이즈 2개는 시나리오로 옮겨 둡니다`. `시나리오 이름` 입력(기본 `총력전 준비 · 호시노 외 2명`). `저장한 뒤`: `시나리오 보기로 이동`, `단계 순서는 페이즈 편집에서 다시 바꿀 수 있게 유지`. primary `시나리오로 저장` (2044,767,494×58).

### 4.2 현재 코드 대응
| 시안 | 현재 | 분류 | 근거 |
|---|---|---|---|
| 시나리오로 저장 | `_saveScenarioDraft` → `PlanningScenarioRepositoryService.createScenario/updateScenario` (`repository.scenario.create/update`), `AlertDialog` 이름·설명 입력 | **수정** | 기능 있음. 다이얼로그 → C 패널 인라인 입력으로. 설명(description) 필드는 시안에 없음 |
| 활성 계획에 페이즈로 추가 | `_incorporateScenario` (시나리오 phase를 현재 계획 뒤에 붙이고, 퇴행 stage는 `_targetsAtLeast`로 제외, 스낵바 "퇴행하는 n개 단계는 제외했습니다") | 재사용(로직) / 수정(진입점) | 동일 의미. 단 **메모리 내 변경만** 하고 저장하지 않음 |
| 활성 계획을 이걸로 바꾸기 (+ 기존 페이즈를 시나리오로 옮김) | 없음 | **신규** | |
| 미리보기 P1~P3 + 필요 재화 팝오버 | `PlanPhaseDiagonalList` / `PlanConsumptionSection` 일부 | 수정 | 데이터는 `phase_results` |
| 활성 계획 대비 비교 | `PlanningScenarioComparisonService.compareScenarios` → `planning.scenario.compare` | 수정 | comparison payload에 `credits_a/b`, `resource_type_count_a/b`, `known_shortage_type_count_a/b`, `students[].presence/target_differences`, `resources`, `bottlenecks` [확인: mock]. **계획 충족률(%)은 없음** → `overall.resources`의 required/owned로 클라이언트 산출 또는 백엔드 추가. "추가했을 때"의 비교는 documentB = 활성+신규 병합 문서를 만들어 compare해야 함 [추정] |
| `저장하고 닫기`(A) vs `시나리오로 저장`(C) | — | — | 두 저장 버튼 중복(모호점) |

### 4.3 핵심 질문 답: "계획/시나리오로 저장"이 현 모델·프로토콜에 있는가
- **문서 종류 구분: 있다. [확인]** `PlanningDocumentKind { plan, scenario }`, wire `kind: "plan" | "scenario"`. `PlanningScenarioRecord.fromWire`는 `kind == scenario`가 아니면 거부.
- **시나리오 저장: 있다. [확인]** `repository.scenario.list/get/create/update/delete/duplicate`, `baseProfileRevision`(→ `isStaleAgainst`로 "저장 시점과 다름" 표시 가능).
- **활성 계획(kind=plan) 저장: 없다. [확인]**
  - repository 메서드에 plan/document 저장이 없다. 영속되는 "계획"은 `repository.goals.save`의 `{version:1, goals:[RepositoryGoalState…]}` — v6식 **학생당 목표 1개** 평면 목록뿐이다.
  - `PlanSectionLayout._loadRepositoryPlan`은 그 goals를 읽어 **학생당 stage 1개(`v6-<id>-1`), phase 1개(`v6-imported-plan`)** 의 `PlanningDocument(id:'active-plan', kind: plan)`로 메모리에 변환할 뿐이다.
  - UI 어디에서도 `saveRepositoryGoals`를 호출하지 않는다(grep: `mock_app_service.dart`, `repository_service.dart`, `process_app_service.dart` 정의만 존재). 페이즈 편집 완료(`_completePhaseEditor`)·편입(`_incorporateScenario`)·요소 확정(`_confirmPlanElementStages`) 모두 `_rebuildDocumentFromPhases()`로 **계산만** 하고 저장하지 않는다. section-template-studio.md 페이즈 편집 절도 "repository 저장… 재시작 복원은 후속 범위"라고 명시.
  - → 시안의 `활성 계획에 페이즈로 추가` / `활성 계획을 이걸로 바꾸기`, Scenario-List의 `활성 계획 · 학생 9 · 페이즈 1 · 단계 9`, 한 명 모드의 `이미 잡혀 있는 목표 P1·1단계/P2·2단계`는 모두 **활성 계획 PlanningDocument 영속화**를 전제한다. **신규 백엔드 필요**: 예 `repository.plan.get` / `repository.plan.save`(expected revision, idempotency, document kind=plan) + 활성 계획 → 시나리오 이동(교체 시 기존 페이즈 보존)을 원자적으로 처리하는 메서드 또는 클라이언트 2단 트랜잭션. 기존 goals(v1)와의 관계(대체/병행/마이그레이션) 결정 필요. AGENTS.md의 "five data buckets(… user goals …) 보존" 규칙과도 맞춰야 함.
- **"학생·목표·단계는 한 묶음으로 남아서 1~3단계로 돌아와 고칠 수 있다"**: 학생 선택 순서, 학생별 프리셋 적용 상태, 나중에 칸, 직접 선행 조건 사유(`노트 먼저 쓰기`)는 v1 문서로 복원 불가 → **문서 v2 또는 authoring 메타 필드 필요**. (학생 목록·단계·phase 배치 자체는 v1으로 복원 가능.)

### 4.4 모호점
- `지금 P2 뒤에 P3~P5로 붙입니다`, `기존 페이즈 2개` (활성 계획 2페이즈) vs Scenario-List 활성 계획 `페이즈 1` — **시안끼리 수치 충돌**. 또 새 계획은 페이즈 3개인데 "P3~P5"는 3개라 일관.
- `저장하고 닫기`(A)와 `시나리오로 저장`(C)의 관계(C 선택에 따라 라벨이 바뀌는 같은 동작인지).
- `저장한 뒤` 두 항목이 체크박스인지 라디오인지(둘 다 46px `div.plain`, 선택 표시 없음).
- `단계 순서는 페이즈 편집에서 다시 바꿀 수 있게 유지`: 페이즈 편집기가 흐름 3단계와 별도로 남는다는 뜻인지(Scenario-Detail 왼쪽 레일에도 `페이즈 편집` 버튼 존재), 3단계로 재진입한다는 뜻인지((i) 문구 "계획 탭 페이즈 *순서 바꾸기* → 3단계").
- 시나리오 `설명(description)` 입력이 시안에 없음(목록 카드에는 설명 표시).

---

## 5. 기존 계획 탭 "활성 계획 보기"는 어디로 갔나

[확인] 현재 계획 메인은 Section 2 = 읽기 전용 페이즈 목록(`PlanPhaseDiagonalList`, `PlanPhaseCard`), Section 5 = 재화 헤더/탭(`PlanResourceHeader`, `PlanResourceView { bottleneck, byPhase, overall }`, `PlanPrimaryBottleneckSummary` / `PlanPhaseResourceSummary` / `PlanOverallResourceSummary`), Section 3 = 탭 본문(`PlanBottleneckDiagonalList`/`PlanBottleneckDetailCard`, `PlanConsumptionSection`, 전체), Section 4 = 제어(`PlanResourceControls`: 유형 필터·충족 숨기기·정렬 `PlanResourceSort`), Section 6 = 유형 필터(`PlanResourceTypeFilterSection`, `PlanResourceCategory`), Section 1 = 진입 버튼 6개.

[확인] 시안에서 동일 요소가 **Scenario-Detail-Bottleneck / -Phase / -All** 에 그대로 있다:
- 오른쪽 큰 Section (895,209,1665×1183) 상단 `div.plain`: 탭 `병목 | 페이즈별 | 전체`, `재화 유형 · 전체`(유형 필터), `충족 재화 숨기기`, `부족량 많은 순`(정렬) → 현 Section 5+4+6.
- 헤더 행: `가장 심한 병목 리오(무장)의 엘레프 · 449 부족 · P1 리오 1단계에서 막힙니다…`(병목) / `가장 부족한 재화 기술 노트… P1 종료 시 0개 남아서 P2 스킬 단계가 모두 막힙니다`(페이즈별) / `전체 요구량 필요량의 81% 확보 · 8종 부족 · 3명 중 2명의 계획에 영향`(전체) → 현 `PlanPrimaryBottleneckSummary`·`PlanPhaseResourceSummary`·`PlanOverallResourceSummary`.
- 본문: 병목 카드(`병목 1 · P1 · 리오(무장) 1단계… 진입 잔량 1 · 필요 450 · 449 부족 · 이 병목으로 지연되는 단계 리오 2단계 (P2)`) → 현 `PlanBottleneckDetailCard`/`PlanDelayedStagePreview`. 페이즈별(`P1 리오 먼저 · 크레딧 진입 98.4M 필요 27.6M 종료 70.8M · 재화별 진입/필요/종료 %`) → 현 `PlanConsumptionCard`/`PlanInventoryCoverageBar`.
- 왼쪽 단계 목록 Section (215,209,865×1183): `페이즈 3개 · 단계 5 · 활성 계획과 다른 단계 3`, 페이즈별 단계 행(`병목 1 · 여기서 막힘`, `앞 단계 대기`, `활성 계획과 같음/목표 다름/이 시나리오에만/활성보다 낮은 목표`) → 현 Section 2 페이즈 목록 + 비교 배지.
- 새로 추가된 것: **모든 값이 "활성 계획 대비"** (`활성 계획 대비` 4지표: 필요 크레딧·부족 재화·첫 병목·끝까지 가는 학생, 재화 행마다 `±` 델타, `활성 계획과 같음/이 시나리오에만`), 왼쪽 레일 `시나리오 목록 / 페이즈 편집 / 복제해서 새로 / 비교에 담기 · 3/4 / 계획에 적용…`.

결론 [추정]: **활성 계획 보기 화면은 독립 artboard로 남지 않고 Scenario-Detail-* 의 3탭 구조로 흡수**되었다. 활성 계획 자체를 볼 때는 Scenario-List 왼쪽 레일 `활성 계획으로` 버튼 / 목록 첫 행(`srow blue` `활성 계획 · 메인 · 지금 쓰는 계획`)으로 같은 Detail 화면을 "비교 대상 없음"으로 여는 것으로 보이나, **활성 계획 단독 Detail artboard는 없다** → 사용자 확인 필요(비교 열·델타 배지가 빠진 상태의 시안).

현재 코드의 시나리오 UI(`PlanScenarioListSection`/`PlanScenarioListCard`, `PlanScenarioComparisonSection` A/B 2열)는 Scenario-List(미리보기·체크로 비교 담기 최대 4)·Scenario-Compare(최대 4열)와 구조가 달라 **수정/재구성 대상**(시나리오 그룹 범위).

또한 [확인] 현 계획 메인의 재화 뷰는 초기값이 더미(`dummyPlanPhases`, `dummyPlanBottleneckDetails`, `dummyPlanPhaseConsumptions`, `dummyPlanOverallConsumption`, `planPrimaryBottleneck*`/`planPhaseShortage*`/`planOverall*` 상수)이며 repository 로드 시 projection으로 교체된다. 헤더 요약 위젯 일부가 상수(`planOverallProgressPercent = 72` 등)를 참조하는지 구현 시 점검 필요.

---

## 6. 데이터·프로토콜 요구 종합

| 화면 값 | 현재 제공 | 필요 조치 |
|---|---|---|
| 학생 카탈로그·보유·현재값 | `listStudents`, `loadRepositoryState` | 없음 |
| 단계 targets·검증 | `PlanningDocumentStage`, `normalizePlanningGrowthTargets`, `planningGrowthRuleViolation` | 없음 |
| 단계별 비용(Flow-2 COST, Flow-3 카드) | `planning.document.calculate` → `stage_results[].cost/resources` | 클라이언트 매핑 추가 |
| 칸/페이즈별 부족, 진입·종료 잔량 | `phase_results[].resources`(Dart는 required/owned만 읽음), `bottlenecks[].remaining_at_entry` | **백엔드 응답에 진입/종료 잔량 존재 여부 확인**, 없으면 추가 |
| 가능/부족/막힘 | `bottlenecks[].stage_id/affected_stage_ids` | 정의 확정 후 클라이언트 매핑 |
| 계획 충족률 % | 없음 | overall required/owned로 산출 규칙 확정 또는 백엔드 추가 |
| 활성 계획 대비 비교 | `planning.scenario.compare` | 병합 문서 생성 규칙(클라이언트) |
| 시나리오 저장/목록/복제/삭제 | `repository.scenario.*` | 없음 |
| **활성 계획 문서 저장/로드** | 없음(goals v1 평면만, 저장 호출도 없음) | **신규 repository 메서드** |
| **교차 학생 선행 조건, 나중에 칸, 학생 선택 순서** | 없음(v1 엄격 키 검증) | **PlanningDocument v2 또는 authoring 메타** + 백엔드 검증/계산 반영 |
| **단계 프리셋 영속화(+단계 이름)** | 없음(인메모리, `stages`에 이름 없음) | 모델 확장 + 신규 repository 메서드 |
| 내 그룹, 필터 프리셋, 최근 본 학생 | 없음 | 신규(그룹·필터 프리셋은 repository, 최근은 로컬 가능) |
| 미보유 학생 "모집" 단계 비용(엘리그마) | 불명 | 백엔드 확인 |

---

## 7. 사용자 확인이 필요한 모호점 (요약)

1. **활성 계획 영속화 범위**: 활성 계획을 PlanningDocument로 저장하는 새 repository 계약을 만들지, 기존 `goals v1`을 확장할지. (Flow-4의 두 활성 계획 옵션, 한 명 모드 "이미 잡혀 있는 목표", Scenario-List 활성 계획 행 모두 이 결정에 의존.)
2. **문서 v2**: 교차 학생 선행 조건·나중에 칸·학생 순서·프리셋 적용 기록을 계산 문서(v2)에 넣을지, 계산과 무관한 authoring 메타로 분리 저장할지. 선행 조건이 **계산(재화 배분 순서)에 영향**을 주는지.
3. 선행 단계와 **같은 칸** 허용 여부, `나중에` 칸 단계의 저장 처리(제외/마지막 phase/보존).
4. 흐름 3단계가 **현 페이즈 편집기를 대체**하는지, Scenario-Detail의 `페이즈 편집`이 별도 화면으로 남는지. 페이즈 이름 편집 위치.
5. Flow-2에서 빠진 컨트롤(성급, 장비 레벨, 애장품, 추가 능력치) 제거 의도 여부.
6. 2단계 시점 단계 상태(지금 가능/부족)의 판정 기준.
7. Flow-4 활성 계획 페이즈 수(2) vs Scenario-List(1) 수치 충돌, `저장하고 닫기`/`시나리오로 저장` 중복, `저장한 뒤` 옵션 형태, 설명 입력 부재.
8. 활성 계획 단독 Detail 화면(비교 없음)의 모습.
9. 고른 학생 패널 목록형↔압축 그리드 전환 임계값, 한 명/여러 명 모드 전환 애니메이션, 각 Section intro/outro 방향(시안에 없음 — 현 `SectionMotionSpec` 관례 적용 여부).
10. 프리셋 정의: 시안 프리셋은 단계 이름을 가짐(`성장 기반 → …`), 현 `PlanElementPreset`은 없음. `한 번에 MAX`/`직접 입력`이 프리셋인지 모드인지.

---

## 8. 그룹 전체 요약 — 구현 단위(vertical slice) 제안

선행 공통 의존: (W) **Flow 3-Section 골격 Studio 문서 + StepRail(A) + SummaryFlyout** — 4개 화면이 공유. (S) **흐름 상태 컨트롤러**(현 `_PlanSectionLayoutState`의 `_showStudentSelector/_showElementBuilder/_showPhaseEditor/_creatingScenario` 플래그 묶음을 "단계 1~4 + 초안 문서" 상태로 대체). (B) **백엔드 계약 결정**(7절 1·2).

| 순서 | slice | 내용 | 난이도 | 선행 |
|---|---|---|---|---|
| 0 | 계약 결정·백엔드 | 활성 계획 문서 저장(`repository.plan.*` 류), 문서 v2/메타(선행 조건·나중에·학생 순서), 프리셋 영속화, phase resource 진입/종료 잔량 확인 | L | 사용자 결정 |
| 1 | 흐름 골격 | 계획 탭 내 "계획 만들기" 모드, A 레일(스텝 4개·요약 4행·다음/이전), 초안 `PlanningDocument` 상태 + 디바운스 `calculatePlanningDocument`, 부족 재화 플라이아웃 | M | W, S |
| 2 | 1단계 학생 고르기 | `PlanStudentSelector` 재구성(8열 그리드·순서 배지·C 패널 목록/압축 2형·역할군 일괄·보이는 학생 모두 고르기), 한 명 모드(학생 탭 상세 인디케이터 재사용) | M | 1, 학생 그룹 B의 그리드/인디케이터 |
| 2b | 필터 팝업 | 학생 탭 필터 팝업 재사용 + 계획 칩 그룹, `StudentRangeConditions` 행 단위 범위 모델로 변경 | M | 그룹 B 필터 |
| 2c | 내 그룹·최근 본 학생·필터 프리셋 | 저장소 포함 | M | 0 |
| 3 | 2단계 목표 정하기 | `PlanElementBuilder` 재구성(학생 탭 줄·가로 단계 카드·COST·현재→최종), 미배정 목록 폐기, 프리셋 세그먼트/C 패널·일괄 적용 | L | 1, (프리셋 저장은 0) |
| 4 | 3단계 단계 순서 | lane 보드(드래그, 같은 학생 순서 강제 재사용), 연결선 오버레이, 상태 배지, C 상세, 자동 정렬 3종, Many 모드(작게/학생별 묶음/필터/흐림) | L | 1, 3; 교차 선행 조건은 0 |
| 5 | 4단계 저장 | 미리보기 P1~Pn+팝오버, 활성 계획 비교(병합 문서 compare), 시나리오로 저장(기존 `createScenario` 재사용) | M | 1, 4 |
| 5b | 활성 계획 옵션 | 페이즈로 추가(`_incorporateScenario` 로직 이전)·이걸로 바꾸기(기존 페이즈 → 시나리오 이동) + 영속화 | M | 0, 5 |
| 6 | 정리 | 현 계획 메인 Section 1 버튼 묶음·페이즈 편집 진입점·`_PlanWorkspaceSnapshot` 왕복 로직 폐기/이관, 활성 계획 보기는 시나리오 그룹의 Scenario-Detail로 이관. `planning_page_test`, `plan_element_builder_test` 등 ValueKey(`plan-student-selector-launch`, `plan-phase-editor-launch` 등 `plan-student|phase|preset|scenario-…` 계열 ValueKey가 `plan_section_layout.dart`에서 37줄) 기반 테스트 재작성 | M | 2~5, 시나리오 그룹 |

권장 순서: **0(결정) → 1 → 2 → 3 → 4(같은 학생 선행만) → 5(시나리오 저장만) → 0(백엔드 구현) → 4의 교차 선행·나중에 보존 → 5b → 2b/2c → 6.** 시나리오 저장까지는 현 v1 프로토콜만으로 끝까지 동작하는 최초 vertical slice를 만들 수 있다(교차 선행 조건·나중에 칸 제외, 활성 계획 옵션 비활성).
