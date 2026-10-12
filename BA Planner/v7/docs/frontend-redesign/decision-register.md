# Frontend Redesign Decision Register

- **ID 규칙**: `FD-###` 일련번호. 새 항목은 절과 상관없이 다음 빈 번호를 받고, 번호는 지우거나 재사용하지 않는다(폐기는 상태에 `폐기`와 날짜를 적는다). slice ID는 `almanac/workflows/frontend-redesign-workflow.md`의 정의를 그대로 쓴다.
- **상태 값**: `확정`(사용자가 정함, 날짜 표기) · `확정(FD-001 적용)`/`확정(FD-003 적용)`(이미 확정된 결정으로 답이 정해짐, 근거 칸에 갱신할 문서·절) · `열림`(사용자 결정 필요, 그 전에는 "막는 slice"를 시작하지 않는다) · `워커 재량`(되돌리기 쉬운 것, 권장안대로 처리).
- **갱신 규칙**: 오케스트레이터만 사용자 답을 받아 `열림` → `확정 YYYY-MM-DD`로 바꾸고 고른 선택지를 권장안 칸에 적는다. 워커는 `워커 재량` 항목만 권장안대로 처리하고, 처리 결과(또는 권장안과 다르게 한 이유)를 slice status 보고에 FD ID로 남긴다. 워커가 새 모호점을 찾으면 status에 보고만 하고 이 대장은 고치지 않는다.
- **근거 문서**: 출처 ID가 가리키는 조사 보고서는 `docs/frontend-redesign/survey/<A~J>-*.md`, artboard는 `docs/frontend-redesign/prototype/2026-10-05/`(읽기 도구 `docs/frontend-redesign/tools/dc_outline.py`)에 있다.
- **출처 표기**: 근거 칸의 `A-H-1`, `B-12`처럼 보고서 고유 ID는 그대로, 번호 목록은 `C-7`(C §7 n번), `D-4`(D §6), `F-1`(F §6), `H-9`(H §9), `E-1`(E 마지막 '사용자 확인 필요 목록'), `E§1.6-2`(E 해당 절 모호점 n번), 전술 보고서 G의 `A1`~`A13`은 `G-A1`처럼 쓴다. 코드 위치는 `frontend/lib/` 기준 상대 경로.

---

## §0 확정

| ID | 결정 | 결정일 | 상태 |
|---|---|---|---|
| FD-001 | 시안이 기존 확정 문서(theme.dart 주석, section-template-studio.md 계정·학생 Section 5 계약, student-card-rendering-lessons JP 배지 등)보다 우선한다. 충돌 문서는 해당 slice에서 시안에 맞춰 갱신한다. | 2026-10-05 | 확정 |
| FD-002 | 백엔드·프로토콜 추가를 이번 워크플로에 포함하고 화면별 수직 slice로 진행한다(프론트만으로 되는 화면 먼저). | 2026-10-05 | 확정 |
| FD-003 | 활성 계획 = 페이즈 문서(PlanningDocument)로 저장하는 새 repository 계약. goals v1은 거기서 파생. | 2026-10-05 | 확정 |
| FD-004 | 체크포인트 C 미완료 → FE0은 코드 편집 없이, 코드 착수는 C 커밋 확인 후. **충족 2026-10-06**: C 커밋 `2156685ac63a` 확인, FE1-a부터 착수 가능. | 2026-10-05 | 확정 |

---

## §1 공통 요소·토큰 (FE1/FE2)

| ID | 질문(한 문장) | 근거 | 선택지 | 권장안과 이유 | 막는 slice | 상태 |
|---|---|---|---|---|---|---|
| FD-005 | 핑크 #f2b3ef를 theme 토큰으로 올리고 "선택·강조 = 핑크, 탐색 탭 = 파랑"을 규칙으로 삼는가? | 갱신: `app/theme.dart` AppColors 주석(색 역할 서술). 출처 H-1, H §7.1(6파일 하드코딩) | — | `accent #f2b3ef`, `accentText #f7c9f4`, `onAccent #2a1330`, `scrollThumb #e5a0ea` 신설, 하드코딩 6곳 교체. 주 탭 선택은 파랑 primary 유지 | FE1 | 확정(FD-001 적용) |
| FD-006 | 섹션 표면을 시안의 surface@.76·블러 없음·무테로 바꾸는가? | 갱신: section-template-studio.md 표면·선택 상태 서술, `app/theme.dart` 주석. 코드 `ui/widgets/diagonal_section.dart` `DiagonalSection`(.92+blur8+outline), `section_template_surface.dart` `SectionTemplateSurface`(.88+blur8). 출처 H-2, UI-Elements 블록 7 | — | `SectionSurface`(.76, 무블러, lifted shadow 4층)로 통일. 실화면 artboard path 117개가 모두 이 값 | FE1 | 확정(FD-001 적용) |
| FD-007 | 시안 `.sw` 래퍼의 CSS drop-shadow를 lifted path shadow 위에 한 번 더 그리는가? | H-3, H §7.4 | (a) lifted shadow 4층만 (b) 2중 그림자 | (a). `paintLiftedPathShadow`가 시안 4층 알파와 정확히 일치하고, `.sw`는 HTML 렌더 보조로 보임(추정). 캔버스 대조에서 테두리 대비가 약하면 (b) | FE1 | 워커 재량 |
| FD-008 | GyeonggiTitle를 20px 미만(값·소제목)에도 쓰는가? | 갱신: `app/theme.dart` AppType 주석 "20px 미만에는 쓰지 않는다". 출처 H-4, H §7.2 | — | 시안대로 6.5~43px에 사용. 주석을 "값·제목 서체, 크기 제한 없음"으로 개정 | FE1 | 확정(FD-001 적용) |
| FD-009 | 폰트 파일이 없는 굵기 800/900을 어떻게 그리는가? | H-5, H §7.2 | (a) 700으로 매핑 (b) Pretendard 800/900 asset 추가 | (a). 시안 @font-face가 Pretendard 500/600/700만 로드하므로 브라우저도 800/900을 700 face로 그림(CSS 글꼴 매칭 규칙, 추정). GyeonggiTitle w800은 500 face 합성 굵게일 수 있어 FE1 검수에서 대조 | FE1 | 워커 재량 |
| FD-010 | 시안 전용 글자 크기(12.5/11.5/10.5/13.5/19/26/30/34/25.2/43.2, 10 미만)를 AppType에 넣는가, 가까운 토큰으로 맞추는가? | H-6, H §7.2 | (a) 역할 토큰으로 추가 (b) 가까운 토큰으로 스냅 | (a). 캔버스와 나란히 비교하는 검수 방식에서 스냅은 차이를 만든다 | FE1 | 워커 재량 |
| FD-011 | 거의 흰 글자 변형(#dfe7ee/#e6edf3/#dbe4ec)과 2차·축 글자색을 어떻게 토큰화하는가? | H §7.1 | — | 변형 3종은 `text`로 통합, `textSecondary #c3cfdb`, `textDim #6f8397`, `popover #0d151f`, `rowSurface rgba(16,24,35,·)`, `indicatorSurface #203243` 신설 | FE1 | 워커 재량 |
| FD-012 | 별 노랑 #f3c96b(성작 표시)와 #e8c15a(성급 필터)를 통일하는가? | H-9, W-Filter-Widgets, UI-Elements 블록 2 | (a) 둘 다 유지 (b) 하나로 통일 | (a) `starDisplay`/`starFilter` 두 토큰. 둘 다 시안 값 | FE1 | 워커 재량 |
| FD-013 | 모달 스크림 알파 5종을 하나로 통일하는가? | H-10, H §6.1 | (a) artboard 값 프리셋 (b) 한 값으로 통일 | (a) `BaModal` 스크림 프리셋: .8+blur2(필터 팝업) / .72+blur2(홈 스캔·계정 추가) / .62(엑셀) / .35(앵커 팝업). 통일하면 캔버스 대조가 어긋남 | FE2-c | 워커 재량 |
| FD-014 | CSS 정의만 있고 본문에서 안 쓰는 클래스(`.devbar`, `.viewsel`, `.chk`, `.dash`, `.stars`, `.tab`, `.chip.solid`, `.btn.icon/.dng`, `.tonal.cur/.done`, `.ord`, `.card`, `.scard2`)를 구현하는가? | H-11, H §6 | — | 구현하지 않는다(사용 0회) | FE2 | 워커 재량 |
| FD-015 | 버튼·배경 텍스처를 시안 PNG로 바꾸는가, 절차 텍스처를 유지하는가? | H-13, A-T-2, UI-Elements 블록 7 | (a) `BATriangleTexturePainter` 유지 (b) 시안 PNG asset | (a). 같은 팔레트로 확인됨, 시안 PNG는 코드 텍스처 캡처로 보임(추정). 검수에서 차이가 크면 해당 버튼만 재검토 | FE1 | 워커 재량 |
| FD-016 | 둥근 다각형 함수 3종(원호 필렛/Q 곡선 2종)을 어떻게 합치는가? | H §6.1, H §8 H1. `section_template_surface.dart` `buildRoundedSectionPolygon`, `diagonal_menu.dart` `roundedPolygonPath`, `diagonal_header.dart` `buildRightCutRoundedPath` | — | FE1에서는 기존 형상을 그대로 내는 단일 API(코너 모드 파라미터)로만 묶고(동작 불변), 시안의 Q 코너 전환은 각 화면 slice에서 캔버스 대조 후 | FE1 | 워커 재량 |
| FD-017 | 섹션 모션 값을 어떻게 토큰화하는가? | H §7.4, UI-Elements 블록 7. 상수 6벌(`student_section_layout.dart`, `plan_section_layout.dart`, `plan_element_builder.dart`, `plan_phase_editor.dart`, `plan_student_selector.dart`, `plan_preset_manager.dart`), `DirectionalSectionEntrance`(easeOutCubic) | — | `AppMotion`(섹션 360ms easeInOutCubic, 셸 460ms, 탭 본문 970ms, 헤더 220ms, 탭 180ms). FE1에서는 현재 값 그대로 토큰화(곡선 변경 없음) | FE1 | 워커 재량 |
| FD-018 | 사선 목록 2모드(resize·translate)와 스크롤 포그 3종을 모두 공용 옵션으로 두는가? | H-8, H §3.6, W-Layout-Widgets, Stats-* `sv*`, Tactical `rs*` | (a) 둘 다 옵션 (b) 하나로 통일 | (a) `DiagonalScrollViewport(mode: resize/translate)` + `ScrollViewportFog`(extent·color·fade 파라미터). slice FE2-a 정의와 같음 | FE2-a | 워커 재량 |
| FD-019 | 모달·앵커 팝업·시안이 그린 부유 패널을 "부유 섹션 금지·모든 섹션 사선" 규칙의 예외로 보는가? | 갱신: frontend-section-direction-and-user-flows.md §1.1(부유 섹션 금지), §1.2(모든 섹션 사선). 출처 G-A12, A-S-5, A-P-2, E§5.6-1 | — | 예외로 명시: 모달(홈 스캔, 계정 추가, 필터, 엑셀), 앵커 팝업(족보 전체), 부유 패널(Title-Accounts 편집 패널, Inventory-Tiers T2). T2 intro/outro는 아래 기준 80°/260° | FE2-c, FE6-e, FE8-c, FE8-f | 확정(FD-001 적용) |
| FD-020 | 화면의 상시 안내 문장을 (i) 도움말 뒤로 옮기는가? | 갱신: section-template-studio.md의 화면별 안내 문구 서술. 출처 H §5.5, W-Info-Popover | — | 시안이 있는 화면은 (i)로 이동. 시안 없는 스캔·설정 탭은 현행 유지 | FE2-c 이후 각 화면 slice | 확정(FD-001 적용) |
| FD-021 | (i)·플라이아웃을 무엇으로 구현하는가? | H §5.4, H §8 H6 | (a) `OverlayPortal` 기반 `AnchoredFlyout` (b) Material `Tooltip` | (a). Tooltip은 탭 고정 열기·리치 내용·좌/우 정렬 선택을 못 함(추정) | FE2-c | 워커 재량 |
| FD-022 | 시안 `.tile`의 두 의미(재화 타일·위젯 카드)를 Flutter에서 어떻게 부르는가? | H-14, H §2.6 | — | `ResourceTile`(재화 타일)과 `WidgetTile`(위젯 카드)로 분리 | FE2 | 워커 재량 |
| FD-023 | 통계·인벤토리 차트를 라이브러리로 그리는가? | F §7, `pubspec.yaml`(차트 패키지 없음) | (a) CustomPainter primitive (b) 차트 패키지 추가 | (a). 80° 막대·빗금·viewBox×1.25 균일 배율은 일반 라이브러리 마크로 안 나오고, 의존성 추가는 Release 재빌드를 부름 | FE2-d | 워커 재량 |
| FD-024 | 공격·방어 타입 색을 어디에 두는가? | H §7.1, W-Filter-Widgets. `student_section_layout.dart`의 4색 상수 | — | theme 토큰으로 추출하고 복합장갑 `#7a8ea3` 추가 | FE1 | 워커 재량 |
| FD-025 | 시안끼리 예시 수치가 맞지 않을 때(예: 기술 노트 96/120 vs 254/158, 계획 페이즈 1 vs 2, 족보 4 vs 7) 무엇을 따르는가? | F-10, C §4.4, G-A2·A3, E§2.6-3 | — | 예시 수치는 구현 판단에 쓰지 않는다. 배치·라벨·상태 표현만 시안을 따른다 | 전체 | 워커 재량 |

## §2 공통 지표 정의 (여러 탭이 공유하는 산식)

| ID | 질문(한 문장) | 근거 | 선택지 | 권장안과 이유 | 막는 slice | 상태 |
|---|---|---|---|---|---|---|
| FD-026 | 화면에 나오는 "활성 계획" 수치(인벤토리 필요·부족, 통계 B·C, 시나리오 대비, Flow-4 비교, 한 명 모드 "이미 잡혀 있는 목표")의 원천은 무엇인가? | 갱신: section-template-studio.md 페이즈 편집 절("repository 저장·재시작 복원은 후속 범위"). 출처 E-2, F-9, C-1, D §0-3 | — | 저장된 활성 PlanningDocument를 `planning.document.calculate`로 계산한 결과 하나. `calculateShortages`(goals v1) 경로는 새 화면에서 쓰지 않는다 | FB-1, FE5, FE6, FE7 | 확정(FD-003 적용) |
| FD-027 | FB-1이 들어오기 전 활성 계획 기반 화면은 무엇으로 그리는가? | `ui/widgets/plan_section_layout.dart` `_loadRepositoryPlan`(goals → 학생당 단계 1·페이즈 1 문서), C §4.3 | — | 같은 변환으로 임시 활성 문서를 만들어 계산하고, FB-1 후 같은 자리에서 저장 문서로 교체 | — | 워커 재량 |
| FD-028 | 학생별 "육성도(%)"와 A2 "항목별 완성도"를 어떤 항목·가중치로 계산하는가? | Stats-Growth KPI·A1·A2, Statistics-Proposal A1·A2·K, `ui/models/planning_growth_rules.dart` `planElementTargetMinimums/Maximums`, `statistics/statistics_projection.dart`(정의 없음). 출처 F-4, F-5, F §5 A1·A2 | (a) 항목 완성도 = (현재−최소)/(최대−최소)(최소·최대는 planElementTargetMinimums/Maximums), 육성도 = 7항목 단순 평균: 레벨, EX, 일반 스킬(skill1~3 평균), 장비(equip1~3 티어 평균), 애장품(equip4), 성작(student_star), 전용무기(weapon_star); 미보유 제외 (b) 4그룹(레벨 / 스킬 4종 / 장비 3칸+애장품 / 성작·전용무기) 각 25% (c) 계획 목표 키 19개 전부 단순 평균(인연·장비 레벨·전무 레벨·추가 능력치 포함) | **사용자 선택: 권장안 (a)** — (a). A1 평균이 A2 막대들의 평균과 같아 두 그래프가 서로 설명되고, 근거 패널 "가장 낮은 항목 애장품"과 맞는다. 인연·추가 능력치는 성장 축이 달라 제외 | FE7-b, FE7-d, FE7-f, FE7-i | 확정 2026-10-06 |
| FD-029 | "완전 육성", "최대 레벨", 근거 패널의 "스킬 낮음/레벨 낮음/장비 뒤처짐"은 어떻게 판정하는가? | Stats-Growth KPI·오른쪽 근거, F-4 | — | 완전 육성 = FD-028 모든 항목 최대(육성도 100%), 최대 레벨 = level이 planElementTargetMaximums 값, "낮음" = 그 항목 완성도 < 60%(A2 기준선과 같은 값). FD-028 확정 후 적용 | FE7-b | 워커 재량 |
| FD-030 | 인벤토리 "부족 위험도(0~100)"는 어떤 식인가? | Inventory C (i) "필요량 대비 보유량이 적을수록, 그 재화를 쓰는 학생이 많을수록 높습니다", W-Data-Widgets 위험도 행, `services/app_service.dart` `InventoryShortageRow`(required/owned/shortage/affectedStudentIds). 출처 E-1, E§1.6-1, H §2.5 | (a) 100 × 부족비율(shortage/required), 동점은 사용 학생 수 (b) 100 × 부족비율^(1/(1+ln n)), n = 사용 학생 수(n=1이면 (a)와 같고 학생이 많을수록 100에 가까워짐) (c) (a) × 첫 부족 페이즈 가중(이를수록 높음, 활성 문서 필요) | **사용자 선택: 권장안 (b)** — (b). (i) 문구의 두 요인을 다 쓰면서 단일 학생 재화(시안 엘레프 1/450·1명 → 98)와 근사하고, 현재 데이터로 클라이언트 계산 가능. (c)는 FE6-f 이후 재검토 | FE6-a | 확정 2026-10-06 |
| FD-031 | "계획 충족률"(인벤토리 KPI 72%, 통계 KPI, Flow-4 비교 72%→64%)과 시나리오 "필요량의 81% 확보"(활성 72% → 81%)는 어떤 집계인가? | Inventory B, Stats-Inventory·Stats-Plan KPI, Flow-4-Save 비교 타일, Scenario-Detail-All 요약, Statistics-Proposal "다른 재화 합산 금지". 출처 E-1, F §5 K, C §4.2, D-5. 같은 지표로 합침 | (a) 활성 계획이 쓰는 재화별 충족률 min(보유, 필요)/필요의 단순 평균(크레딧 포함, 스캔 없는 재화는 빼고 "n종 모름" 병기) (b) 충족된 재화 종 수 / 필요 재화 종 수 (c) 막히지 않는 단계 수 / 전체 단계 수 | **사용자 선택: 권장안 (a)** — (a). 이종 재화 합산 금지(FD-033)를 지키고, B1 카테고리·티어 충족률을 같은 식에 범위만 바꿔 쓸 수 있다 | FE4-e, FE5-d, FE6-a, FE6-c, FE6-e, FE7-c | 확정 2026-10-06 |
| FD-032 | 재화별·카테고리별·티어별 충족률은 어떻게 계산하는가? | Stats-Inventory B1, Inventory-Analysis S1, Inventory-Tiers, `statistics/statistics_projection.dart` `ShortageCategoryStatistics`(수량 합산). 출처 F §4, E §5.5 | — | 재화별 = min(owned, required)/required, 스캔 없음은 모름. 카테고리·학교·티어 = 그 범위 재화별 충족률의 단순 평균(FD-031과 같은 식). `ShortageCategoryStatistics`의 수량 합산은 교체 | FE6-c, FE6-e, FE7-c | 워커 재량 |
| FD-033 | 통계 데이터 규칙(모름 ≠ 0 빗금, 다른 재화 합산 금지, 원·도넛·이중 축 금지, 색은 역할별 하나)을 그대로 따르는가? | 갱신: frontend-section-direction-and-user-flows.md §8 사용자 검수 포인트(결정문으로), §3 "병목 시각화는 후속" 문구(→ C3 계단선). 출처 Statistics-Proposal 1.4·1.6, F §1.6 | — | 그대로 따른다. 인벤토리 타일의 스캔 없음 상태도 빗금 + "스캔 없음"(E§2.6-4) | FE6, FE7 | 확정(FD-001 적용) |
| FD-034 | "끝까지 가는 학생 n/m"(시나리오)과 "막힌 학생 n명"(통계)은 무엇을 세는가? | Scenario-Detail-* 활성 대비 KPI, Scenario-Compare 행, Stats-Plan KPI. 출처 D-5, D §2.5, C §3.3 | (a) 문서 계산 `bottlenecks`의 `stage_id`·`affected_stage_ids` 어디에도 그 학생 단계가 없으면 끝까지 가는 학생, 나머지는 막힌 학생(클라이언트 유도) (b) 학생의 마지막 단계만 보고 판정 (c) 백엔드가 학생별 완료 여부 필드 제공(FB-9) | **사용자 선택: 권장안 (a)** — (a). 현재 응답으로 계산되고 단계 상태 정의(FD-035)와 같은 원천이라 Flow-3·시나리오·통계 숫자가 서로 맞는다. 막힌 학생 = m − n | FE5-c, FE5-e, FE7-c | 확정 2026-10-06 |
| FD-035 | 단계 카드·행의 "가능/부족/막힘"(Flow-3), "여기서 막힘/앞 단계 대기"(Scenario-Detail)는 어떻게 정하는가? | Flow-3-Order(-Many), Scenario-Detail-Bottleneck, `plan_section_layout.dart` `_calculateDocument`(bottlenecks 파싱). 출처 C §3.3, C-6 | — | 부족 = 그 단계가 어떤 병목의 `stage_id`, 막힘 = 다른 병목의 `affected_stage_ids`에 포함(자체 부족과 겹치면 막힘으로 표기, 시안 호시노 3단계), 가능 = 둘 다 아님 | FE4-d, FE5-c | 워커 재량 |
| FD-036 | 단계 순서를 정하기 전(계획 만들기 1·2단계)의 요약·단계 카드 상태는 어떤 임시 배치로 계산하는가? | Flow-1/2 A 요약 4행, Flow-2 카드 "지금 가능/부족 n종". 출처 C §1.6, C §2.6, C-6 | — | 단계 번호별 페이즈(모든 학생 1단계 → P1, 2단계 → P2 …)로 임시 문서를 만들어 계산. 시안 자동 정렬의 "학생마다 한 단계씩"과 같은 배치 | FE4-a, FE4-c | 워커 재량 |
| FD-037 | 페이즈별 "진입/필요/종료" 잔량을 어디서 얻는가? | Scenario-Detail-Phase, Flow-4-Save 팝오버 "앞 페이즈에서 쓰고 남은 양 기준", Stats-Plan C3. phase resource는 `required`·`owned`만. 출처 D §2.5, C §3.5 | — | 백엔드 계산 코드에서 phase resource `owned`의 의미를 먼저 확인. 진입 잔량이면 종료 = max(0, owned − required)를 클라이언트 계산, 아니면 FB-9로 `remaining_at_entry/exit` 추가 | FE4-e, FE5-d, FE7-g | 워커 재량 |
| FD-038 | 재화 행의 ±(활성 대비)는 요구량 차이인가 부족량 차이인가? | Scenario-Detail-All "쿠루미의 엘레프 −60"(부족 없음), ShortagePopover "−6". 출처 D-4 | (a) 부족량 차이 (b) 요구량 차이 (c) 혼합 | (c) 기본은 부족량 차이(shortage_b − shortage_a), 두 문서 모두 부족 0인 재화는 요구량 차이를 회색으로, 크레딧은 요구량 차이. 시안의 두 예를 모두 설명한다. 검수 때 문구 확인 | FE5-b, FE5-c, FE5-d, FE5-e | 워커 재량 |
| FD-039 | "활성 계획과 다른 단계 n", 단계 행 "이 시나리오에만"을 위해 두 문서의 단계를 무엇으로 맞추는가? | Scenario-Detail S2, Scenario-List 미리보기. 출처 D-6 | — | `stage_id` 일치 우선, 없으면 (학생, 학생 안 순번). 맞으면 targets 비교 → 같음/목표 다름/활성보다 낮은 목표, 없으면 이 시나리오에만 | FE5-b, FE5-c | 워커 재량 |
| FD-040 | "과잉 재화"는 어디서부터인가? | Inventory KPI 과잉 8종, Inventory-All 노랑 막대, Stats-Inventory B2. 출처 E§2.5, F §5 B2, H §2.6 | — | 활성 계획이 쓰는 재화 중 보유 ≥ 필요 × 1.5(추정 임계). 계획에 안 쓰는 재화는 과잉으로 세지 않고 막대 없음. 노랑 = `#ffc66d` 계열 | FE6-b, FE7-f | 워커 재량 |
| FD-041 | 이력에 남는 "스냅샷" 1회는 무엇이며 무엇을 저장하는가(FB-2)? | Inventory KPI "+3 지난 스캔 대비"·"마지막 스캔 3일 전"·상세 스파크라인, Inventory-Analysis 최근 변화, Stats 기준 데이터 "스냅샷 6회 · 9/02~10/05", A6·B3, Title-Accounts 메타 줄. `services/repository_service.dart` `RepositoryState`·`RepositoryProfile`(시각 필드 없음). 출처 E-8, E §6, F §5 백엔드 1·2, A §3.4 | (a) 학생·인벤토리 저장(스캔 승인·수동 수정)마다 이력 1건(시각, source=scan/manual, `resource_key`·학생 단위 diff), "스냅샷 n회"·"지난 스캔 대비"는 scan 커밋만 셈 (b) 스캔 커밋만 저장, 수동 수정은 최신 스냅샷에 덮어씀 (c) 하루 단위 마지막 상태 1건 | **사용자 선택: 권장안 (a)** — (a). 수동 수정도 변화 그래프에 남고 "지난 스캔" 기준은 흐려지지 않음. diff 저장이라 작고, 키는 `resource_key`(inventory-catalog-order.md). 마지막 스캔 시각은 같은 이력에서 프로필별로 유도 | FB-2, FE6-f, FE7-h | 확정 2026-10-06 |
| FD-042 | 소진 예측("2주 뒤 소진 예상", "4주 뒤 −66", "이 속도면 P2 이전에 소진")은 어떻게 계산하는가? | Inventory-All D, Inventory-Analysis S5, Stats-Inventory 오른쪽. 출처 E §2.5, F §5 B3 | — | scan 스냅샷 3회 이상일 때 최근 구간 선형 추세, 미만이면 문구 숨김 | FE6-f, FE7-h | 워커 재량 |

## §3 학생 (FE3)

| ID | 질문(한 문장) | 근거 | 선택지 | 권장안과 이유 | 막는 slice | 상태 |
|---|---|---|---|---|---|---|
| FD-043 | 학생 카드를 D(오른쪽 위 글자 칩) + E(이름 카드 밖)로 바꾸고 E의 2색 밑줄은 빼는가? | 갱신: student-card-rendering-lessons-2026-08-02.md 카드 정보 영역 절, section-template-studio.md 학생 카드 16% overlay·카드 이름 크기 계약 절. 출처 B-1, B §0-1 | — | 그대로. 모든 학생 그리드 artboard와 UI-Elements 사양이 DE, 밑줄 없음 | FE3-a | 확정(FD-001 적용) |
| FD-044 | 상태 배지를 고정 슬롯(JP 우상단)에서 왼쪽 80° 변 채워 쌓기(UNOWNED → PLAN → JP)로 바꾸는가? | 갱신: student-card-rendering-lessons-2026-08-02.md 배지 슬롯 절("JP: 카드 상단 우측…", "PLAN: UNOWNED 아래"). 출처 B-2, B §0-2 D5 | — | 그대로. 우상단은 속성 칩 자리 | FE3-a | 확정(FD-001 적용) |
| FD-045 | 그리드 행 피치를 시안(카드 + 이름 줄 ≈191.3, 카드 중심 기준 행 이동)으로 바꾸는가? | `student_section_layout.dart` `_StudentDiagonalGridState`(정사각 셀 ≈210.7). 출처 B-9, B §0-2 D4 | — | 시안 기하로 변경, `_hitTargets`·overlay·image grid가 같은 기하 공유. `plan_student_selector.dart`도 같이 회귀 | FE3-a | 확정(FD-001 적용) |
| FD-046 | "학생 이름 표시"를 끄면 이름 줄을 접는가? | B-9 | (a) 접어서 행 피치 축소 (b) 빈 줄 유지 | (a) | FE3-a | 워커 재량 |
| FD-047 | 카드 속성 칩 라벨을 어떻게 줄이는가? | Student.dc 칩 "신비/중장", `studentFilterValueLabels`. 출처 B §0-2 D2, B-15 | — | 카드 칩은 축약(경장/중장/특수/탄력/복합 — "복합"은 추정), 공격은 폭발/관통/신비/진동(+화학은 catalog에 값이 있으면). 필터 팝업은 전체 라벨 | FE3-a | 워커 재량 |
| FD-048 | 리스트 보기(시안 없음)에도 DE 칩·배지 규칙을 적용하는가? | B-8, `StudentDiagonalList` | — | 현행 유지 | FE3-a | 워커 재량 |
| FD-049 | 인연 목표(→N)는 어디서 가져오는가? | 갱신: student-detail-indicator-lessons-2026-08-01.md 인연 게이지 계약. `services/repository_service.dart` `RepositoryGoalState.fromWire`(target_bond_rank 없음). 출처 B-3 | — | 활성 계획 문서에서 그 학생 단계 목표의 `bond_rank` | FE3-b | 확정(FD-003 적용) |
| FD-050 | 활성 계획에 그 학생 단계가 여러 개이거나 없을 때(FB-1 전 포함) 게이지는? | B-3, W-Student-Detail, Flow-1-Students-One | — | 마지막(최종) 단계 목표를 표시, 목표가 없거나 현재 이하이면 빗금·점선·→N 숨김. 계획 화면 inverted 모드도 같은 표현 | FE3-b | 워커 재량 |
| FD-051 | 인연 B안 채움을 rank/100 비율 그대로 두는가("20은 거의 비어 보임" 미해소)? | 갱신: student-detail-indicator-lessons-2026-08-01.md(목표 겹침 추가). 출처 B-16, W-Bond-Variants | — | 시안 B안 그대로(rank/100 + 목표 빗금 + 점선 + →N) | FE3-b | 확정(FD-001 적용) |
| FD-052 | 필터를 Section 5에서 전체 화면 모달로 바꾸고 Section 5·범위 카드 2장 코드를 폐기하는가? | 갱신: section-template-studio.md 771–818행 "학생 Section 5 필터…"와 표 Section 5 행. 출처 B-4, H-15 | — | 그대로. 폐기 목록은 B §2-4(`StudentDiagonalFilterList`, `StudentRangeConditionSection` 등) | FE3-d | 확정(FD-001 적용) |
| FD-053 | 범위 필터 의미 변경(행마다 최소~최대, 장비 티어·레벨 = 3칸 중 가장 낮은 칸, 성급 = 학생★+무기★ 9단계, 초안 → 적용, 닫아도 유지)을 받아들이는가? | 코드 계약: `student_range_condition_section.dart` `StudentRangeConditions.matchesStudent`, `ui/pages/student_page.dart` 353–360행(닫으면 초기화). 출처 B-18, F-8, W-Filter-Widgets | — | 시안 의미로 재구성. 문서 갱신 대상 없음 | FE3-d | 확정(FD-001 적용) |
| FD-054 | 데이터가 없는 심상개화 그룹을 보이는가? | 갱신: section-template-studio.md "catalog protocol이 직접 제공하지 않는 v6 성장·스킬 metadata 그룹은 빈 동작으로 노출하지 않는다"(예외 추가). 출처 B-5 | — | 시안의 "v7 준비 중 자리"대로 비활성 그룹으로 표시, 조건에는 넣지 않음 | FE3-d | 확정(FD-001 적용) |
| FD-055 | "추가 능력치 = HP·ATK·HEAL 합"의 범위 0~25를 그대로 쓰는가? | B-12, F-8, `planElementTargetMaximums`(각 25) | (a) 합, 0~75 (b) 각각, 0~25 | (a) 라벨은 시안대로 "합", 범위만 바로잡음 | FE3-d | 워커 재량 |
| FD-056 | 토글 칩 옆 학생 수는 무엇을 세는가? | B-11, W-Filter-Widgets "개수는 적용 전 미리보기" | (a) 다른 그룹 조건만 반영한 조건부 개수 (b) 전체 catalog 기준 고정 개수 | (a) 같은 그룹(OR)은 무시하고 다른 그룹 조건만 반영 | FE3-d | 워커 재량 |
| FD-057 | S4 토글(미보유 숨김·일본 서버 전용 숨김)과 팝업 "보유·서버" 그룹은 같은 상태인가? | B-13 | — | 같은 상태 하나를 두 곳에서 보이고 바꾼다 | FE3-c, FE3-d | 워커 재량 |
| FD-058 | "필터 · n" 적용 개수 배지는 어디에 붙는가? | B-14, Student-Filter (18,226), W-Student-Actions(배지 없음) | — | 모달 열림 중에는 시안 위치, 닫힌 뒤에는 S1 필터 버튼에 개수 배지 | FE3-d | 워커 재량 |
| FD-059 | 강화·서브 스킬 최소값(시안 1, 코드 0 = 미개방)과 화학 타입 칩은? | B-15 | — | 최소 0 유지하고 0은 "–"로 표시, 화학은 catalog 값이 있으면 자동 노출 | FE3-d | 워커 재량 |
| FD-060 | S4 적용 필터 칩에 범위 조건(레벨 70~90 등)도 보이는가? | B-17, W-Student-Search | — | 포함(팝업 헤더와 같은 목록), 넘치면 한 줄 + "+n" | FE3-c | 워커 재량 |
| FD-061 | "최근 본 학생"은 몇 명을, 얼마나 오래, 어떻게 쓰는가? | B-6, W-Student-Search, Flow-1-Students C | — | 6명, 앱 실행 동안만(저장 안 함), 누르면 선택 + 그리드 스크롤. 학생 탭과 계획 1단계가 같은 목록 공유 | FE3-c, FE4-b | 워커 재량 |
| FD-062 | 기본 정렬을 "LV ↓"로 바꾸는가? | B-7, `_gridSort = StudentGridSort.nameAscending` | — | 현행 이름 ↑ 유지(시안 그리드 순서가 이름순이라 라벨은 샘플) | FE3-c | 워커 재량 |
| FD-063 | 통계 D 이동 목적지 "학생 탭 · 필터: 육성도 60~70%"를 위해 필터 모달에 육성도 행을 넣는가? | Statistics-Proposal D, Stats-Growth 하단 버튼, 필터 팝업 3종(육성도 행 없음). 출처 F-7 | — | 성장 범위 "기본" 그룹 첫 줄에 육성도 행(FD-028 식) 추가. FE3-d는 행을 늘릴 수 있는 구조만 두고 행 자체는 FE7-d에서 | FE7-d | 워커 재량 |
| FD-064 | 다중 폼 초상 교대 주기는? | W-Card-States "폼 2개(3초)", CSS `stuform2/3/4` | — | 폼 수 × 3초, 계단식(step) 전환 | FE3-e | 워커 재량 |

### §3-1 성장 계산기 (FE3-f, FE3-g, FE4-g, FB-11) — 2026-10-06 추가

| ID | 질문(한 문장) | 근거 | 선택지 | 권장안과 이유 | 막는 slice | 상태 |
|---|---|---|---|---|---|---|
| FD-160 | 성장 계산기는 어디에 있고 어디서 들어가는가? (캔버스 page `plan`, 화면은 nav `학생` on·학생 4섹션과 같은 기하, 진입 버튼은 시안에 없음) | Calc-Student, 출처 `survey/J-calc.md` §9 | (a) 학생 탭 모드: 학생 S1 "포커스 학생으로 계획 열기" 자리를 "성장 계산기 열기"로 바꾸고, 계산기 S1 같은 자리 = "이 목표로 계획에 추가" (b) 학생 탭 모드 + 학생 S1에 7번째 버튼 추가, 기존 계획 열기 유지 (c) 계획 탭 계획 만들기 1단계 한 명 모드 C 패널에서 진입(계획 탭 안의 화면) | **사용자 선택: 권장안 (a)** — (a). 기하·nav·버튼 자리가 학생 탭과 1:1이고, 학생 → 계획 경로가 목표를 싣고 이어진다. 계산기 목표는 휘발이며 학생 탭 인연 게이지(FD-049 활성 계획 목표)와 섞지 않는다. 한 명 모드 C에 보조 링크는 워커 재량 | FE3-f | 확정 2026-10-06 |
| FD-161 | 계산기에서 학생 목록으로 어떻게 돌아가는가? | Calc-Student, 출처 `survey/J-calc.md` §9 | (a) 헤더 제목 옆 "← 학생" 복귀 칩(FE7-d 복귀 칩과 같은 위젯) + Esc + 주 탭 `학생` 다시 누르기 (b) S1 첫 버튼 쌍을 목록/계산기 토글로 | (a). 시안 S1의 첫 버튼 쌍은 "확정값/직접 입력"이라 자리가 없다 | FE3-f | 워커 재량 |
| FD-162 | 계산기의 크레딧·재화 숫자는 어떤 호출로 얻고, 크레딧 범주별 내역은 어디서 오는가? | Calc-Student, 출처 `survey/J-calc.md` §9 | (a) 기존 조합: 임시 1페이즈 1단계 문서 `planning.document.calculate`(재화 행) + 크레딧 내역은 숨김 (b) FB-11에 단일 학생 계산 메서드(가칭 `planning.student.calculate`): totals + 범주별 크레딧 + `InventoryShortageRow` 모양 재화 행 + 인연 블록을 한 번에 (c) `calculatePlan` + `calculateShortages`(goals v1) + 범주별 부분 목표로 `calculatePlan` 4회 | **사용자 선택: 권장안 (b)** — (b). 디바운스 1회 호출로 끝나고, 범주별 크레딧을 정규화 중복 없이 백엔드 계산 코어에서 나눌 수 있다. 활성 계획 수치가 아니므로 FD-026(문서 계산 단일 원천)과 충돌하지 않는다. FB-11 전에는 (a)로 그리고 내역 막대를 숨긴다 | FE3-f(내역 막대), FB-11 | 확정 2026-10-06 |
| FD-163 | 인연 선물 계산(필요 경험치, 선물 3안)의 데이터와 계산 위치는? (경험치 표·쓰다듬기 상수 없음, 선물 `exp_value`·`gift_affinities`는 백엔드 메타데이터에만 있고 개발 도구 전용, 랭크 안 진행도 없음) | Calc-Student, 출처 `survey/J-calc.md` §9 | (a) 백엔드 계산(FB-11): 메타데이터에 랭크별 누적 경험치 표·쓰다듬기 상수 추가, 선물 카탈로그·affinity 배수·인벤토리 `present` 보유로 3안 계산, 현재 경험치는 "현재 랭크 시작" 가정을 응답에 표기 (b) 메타데이터를 카탈로그로 노출하고 Flutter가 계산 (c) 이번 범위 제외: 인연 타일에 필요 랭크만 표시 | **사용자 선택: 권장안 (a)** — (a). runtime-boundaries.md "Python backend는 계산을 소유" 원칙과 맞고, 선물 데이터가 이미 백엔드 정규 catalog에 있다. 랭크 안 진행도는 학생 스캔이 읽게 되면 후속으로 반영 | FB-11, FE3-g | 확정 2026-10-06 |
| FD-164 | 선물 안마다 수량을 어떻게 배분하는가? (각주 "보유가 많은 선물부터" vs 예시 gp1 경험치 순) | Calc-Student, 출처 `survey/J-calc.md` §9 | (a) 보유 선물을 보유 많은 순으로 먼저 쓰고, 모자라면 1개 경험치가 가장 높은 선물로 부족분을 채움 (b) 경험치 높은 순으로 채우고 보유는 표시만 (c) 보유 무시, 최소 개수 | (a). 각주가 명시 규칙이고, "부족 n"이 실제로 구해야 할 수량이 된다. 예시 수치는 FD-025로 무시 | FE3-g | 워커 재량 |
| FD-165 | 고른 선물 안(g1 on)은 화면의 다른 숫자에 반영되는가? | Calc-Student, 출처 `survey/J-calc.md` §9 | (a) 반영 안 함: 고르기는 팝오버 고정·강조만, 성장 재화 목록·"부족 n종"은 성장 재화만 (b) 고른 안의 부족 선물을 성장 재화 목록과 "부족 n종"에 넣음 | (a). 시안 재화 목록에 선물 행이 없고 "부족 3종"이 오파츠·설계도·BD 3행과 맞는다 | FE3-g | 워커 재량 |
| FD-166 | 목표 행 구성은 시안 12행 그대로인가? (장비 레벨·애장품 행 없음, S3는 T10을 Lv.70/70으로 그림, 전용무기는 ★+Lv 한 행, 능력 개방은 3값 한 행. 현 `normalizePlanningGrowthTargets`는 티어를 올려도 장비 레벨을 올리지 않음) | Calc-Student, 출처 `survey/J-calc.md` §9 | (a) 12행 유지. 장비 티어를 올리면 장비 레벨 목표 = 그 티어 최대 레벨(계산기 한정 규칙), 전용무기 행은 ★ 단위로 움직이고 Lv은 그 ★ 최대, 능력 개방 행은 누르면 HP/ATK/HEAL 3스테퍼 플라이아웃, 애장품은 계산하지 않음 (b) Flow-2 단계 카드처럼 장비 레벨·애장품·능력치 개별 행 추가 (c) (a)이되 애장품 행 추가 | **사용자 선택 (c)**: 시안 12행 + 애장품 행(13행). 장비 티어를 올리면 장비 레벨 목표 = 그 티어 최대 레벨(계산기 한정), 전용무기 행은 ★ 단위·Lv은 그 ★ 최대, 능력 개방 행은 누르면 HP/ATK/HEAL 3스테퍼 플라이아웃. 애장품은 계산에 포함하고 S3 애장품 칸도 목표값으로 그린다 | FE3-f | 확정 2026-10-06 |
| FD-167 | S3 학생 정보 칸을 누르면 무엇을 하는가? ((i) "칸을 누르면 필요 재화가 바로 다시 계산") | Calc-Student, 출처 `survey/J-calc.md` §9 | (a) 그 항목 목표를 현재값 ↔ 직전 목표로 토글(분홍 = 바뀌는 칸) (b) 그 항목을 MAX로 (c) 왼쪽 해당 스테퍼 행으로 포커스만 | (a). 재계산 문구와 "바뀌는 칸 n · 그대로 m" 칩을 함께 설명한다. 바뀐 칸은 목표값을 분홍, 그대로인 칸은 흰색으로 통일(시안 흰/분홍 예시 불일치 해소) | FE3-f | 워커 재량 |
| FD-168 | S1 "확정값 기준 / 직접 입력"은 무엇인가? | Calc-Student, 출처 `survey/J-calc.md` §9 | (a) 현재값 출처 토글: 확정값 = repository 학생 상태, 직접 입력 = 목표 행의 "현재" 칸이 스테퍼로 바뀌어 고칠 수 있음(저장 안 함, 미보유 학생도 계산) (b) 직접 입력 = 학생 탭 기존 `_studentFields` 편집으로 저장까지 | (a). 화면 부제 "계획에는 저장하지 않음"과 같은 휘발 원칙. S4 칩 "기준: 확정값"도 같이 바뀜 | FE3-f | 워커 재량 |
| FD-169 | "빠른 목표 고르기"(완전 육성)에 무엇이 들어가는가? | Calc-Student, 출처 `survey/J-calc.md` §9 | (a) 고정 항목(완전 육성 = 전 항목 MAX, 레벨·장비만 MAX, 스킬만 MAX) + 단계 프리셋 마지막 단계(FD-074에서 영속화되면) (b) 완전 육성만 | (a). Flow-2 "한 번에 MAX"와 같은 개념이고, 프리셋 연결은 FD-074 결과를 따른다 | FE3-f | 워커 재량 |
| FD-170 | "최근 계산"은 무엇을 몇 개, 얼마나 오래 담는가? | Calc-Student, 출처 `survey/J-calc.md` §9 | (a) 학생 + 기준 + 목표 맵, 6개, 앱 실행 동안만(FD-061과 같음), 누르면 그 목표로 다시 열기 (b) 프로필별 영속 | (a). FD-061과 같은 수명이라 저장소 신설이 필요 없다 | FE3-f | 워커 재량 |
| FD-171 | "이 목표로 계획에 추가"는 무엇을 넘기고, 이미 계획에 있는 학생이면 어떻게 하는가? (`PlanningStudentSeed`에 목표 필드 없음) | Calc-Student, 출처 `survey/J-calc.md` §9 | (a) seed에 `targets` 추가. 계획 만들기 2단계를 그 학생 1단계 = 계산기 목표로 열고, 진행 중 초안이 있으면 학생을 덧붙임. 활성 계획에 이미 있으면 그 학생 마지막 단계 뒤 새 단계로 (b) 1단계로만 넘기고 목표는 버림 | (a). 버튼 부제 "계획 만들기 2 · 목표 정하기로 넘깁니다"와 맞고, 단계 누적 snapshot 계약(plan-element-builder-lessons)과 충돌하지 않는다 | FE4-g | 워커 재량 |
| FD-172 | 아직 데이터가 없는 표기(인벤토리 스캔 시각, 학생 스캔 시각, 크레딧 보유, 계획에 없음)는 어떻게 그리는가? | Calc-Student, 출처 `survey/J-calc.md` §9 | — | 스캔 시각 2개는 FB-2 전까지 숨김(FD-041), 크레딧 보유는 통화 스캔(FD-096 (c), FB-10)이 생기기 전까지 "스캔 없음" 빗금(부족 칩 숨김), "계획에 없음/있음"은 FB-1 전에는 goals v1 기준(FD-027 방식) | FE3-f | 워커 재량 |
| FD-173 | "인벤토리 · 부족 위험에서 보기 / 부족 3종 · 획득처"는 어디로 가는가? (인벤토리 부족 위험은 활성 계획 기준) | Calc-Student, 출처 `survey/J-calc.md` §9 | (a) 인벤토리 탭을 열고 계산기 부족 재화 키를 강조 필터로 넘김(FE7-d navigation intent 재사용) (b) 계산기 안에서 획득처 플라이아웃(FB-3 보충 방법) (c) FE6-a·FE7-d 전까지 버튼 숨김 | (a). 연결 수단이 생기기 전에는 (c) | FE3-f(숨김), 후속 연결 | 워커 재량 |
| FD-174 | Studio 편집기(`SectionCanvasPainter`)와 `SectionTemplateSurface` 계열의 섹션 선택 표시(primaryMuted 채움 + primary 외곽선)를 FD-005 핑크로 바꾸는가? | FE1-c 발견 사항 2(status), H §6.1~6.3 | (a) 유지 (b) 핑크 accent | (a). 시안의 섹션에는 선택 상태가 없고(핑크는 행·세그먼트 선택), Studio 편집기는 시안 범위 밖 개발 도구다. `SectionTemplateSurface` 계열은 런타임 사용처가 없어 FE10에서 지운다 | FE1-c | 확정(오케스트레이터, 2026-10-06) |

## §4 계획 만들기 (FB-1, FB-8, FE4)

| ID | 질문(한 문장) | 근거 | 선택지 | 권장안과 이유 | 막는 slice | 상태 |
|---|---|---|---|---|---|---|
| FD-065 | 활성 계획을 어디에 어떻게 저장하는가? | `services/repository_service.dart`(plan 저장 메서드 없음, goals v1뿐), `planning_models.dart` `PlanningDocumentKind`. 출처 C-1, C §4.3 | — | repository에 활성 계획 PlanningDocument(kind=plan) get/save(expected revision, idempotency) 신설, goals v1은 거기서 파생 | FB-1 | 확정(FD-003 적용) |
| FD-066 | goals v1은 언제 어떻게 파생하고, 기존 goals만 있는 프로필은 어떻게 옮기는가? | `_loadRepositoryPlan`, AGENTS.md five data buckets 보존 규칙, C §4.3 | — | 백엔드가 활성 문서 저장 때 학생별 최종 단계 targets로 goals v1을 같은 revision 안에서 재생성(UI는 goals를 쓰지 않음). goals만 있는 프로필은 첫 로드 때 `_loadRepositoryPlan` 규칙으로 문서화해 저장 | FB-1 | 워커 재량 |
| FD-067 | "활성 계획을 이걸로 바꾸기"(기존 페이즈는 시나리오로 옮겨 둠)를 원자적으로 처리하는가? | Flow-4-Save C, Scenario "계획에 적용…". 출처 C §4.2, D-9, D §5 | (a) 백엔드 단일 메서드(기존 활성 → 시나리오 생성 + 새 활성 저장, 한 revision) (b) 클라이언트 2단 호출 | (a). 중간 실패 시 기존 계획이 사라지는 상태를 막는다. 기존 활성 자동 보존은 시안 문구(FD-001) | FB-1, FE4-e | 워커 재량 |
| FD-068 | Flow-3의 "직접 이은 선행 조건", "나중에" 칸, 학생 선택 순서를 어디에 저장하고 계산에 반영하는가(FB-8)? | Flow-3-Order (i) 문구, Flow-4-Save (i) "학생·목표·단계는 한 묶음으로 남아서…", `planning_models.dart` `PlanningDocumentStage.fromWire`(키 4개 엄격 검증). 출처 C-2, C-3, C §3.4, C §4.3 | (a) PlanningDocument v2(stage.prerequisites, deferred_stages, student_order)로 계산 문서에 넣고 백엔드 검증·계산 반영 (b) 계산 문서 v1은 그대로, 활성 계획·시나리오 레코드 옆 authoring 메타로 분리 저장 — 선행은 편집 규칙(선행보다 앞 칸 금지)으로만 쓰고 "나중에" 칸 단계는 계산에서 제외 (c) 이번 워크플로에서 교차 선행·나중에 칸 제외(FE4-f 보류) | **사용자 선택: 권장안 (b)** — (b). 앞 칸 금지가 지켜지면 페이즈 순서만으로 계산이 맞아 계산 문서·백엔드 계산을 건드리지 않고, "한 묶음 복원" 요구는 충족. 단 같은 칸 안 선행의 재화 배분 순서는 백엔드 페이즈 내 순서 규칙 확인 필요(추정) | FB-8, FE4-f | 확정 2026-10-06 |
| FD-069 | 선행 단계와 같은 칸에 놓을 수 있는가? | Flow-3 (i) "선행 단계보다 앞 칸에는 놓을 수 없습니다", `plan_phase_editor.dart` `_sequenceOrderIsValid`. 출처 C-3 | — | 허용(시안은 앞 칸만 금지). 같은 칸에서는 선행 → 후행 순으로 자동 정렬 | FE4-d | 워커 재량 |
| FD-070 | 흐름 3단계가 기존 페이즈 편집기를 대체하는가? | 갱신: section-template-studio.md 페이즈 편집 절(현 `PlanPhaseEditor` 4섹션 계약). Flow (i) "계획 탭 페이즈 순서 바꾸기 → 3단계", Scenario-Detail "페이즈 편집". 출처 C-4 | — | 대체. "페이즈 편집"은 그 문서로 3단계에 진입 | FE4-d, FE5-c | 확정(FD-001 적용) |
| FD-071 | 칸(페이즈) 이름과 칸 추가·삭제는 어디서 하는가? | Flow-3 "순서 3칸" vs 칸 4개, Scenario-Detail 이름 있는 페이즈. 출처 C §3.6, C-4 | — | 칸 헤더 이름 인라인 편집(기본 "n순위"), 마지막 칸 아래 "칸 추가", 빈 칸은 저장 때 제거. "n칸" 표기는 "나중에" 제외 | FE4-d | 워커 재량 |
| FD-072 | Flow-2 단계 카드에 없는 성급·장비 레벨·애장품·추가 능력치 편집을 빼는가? | Flow-2-Goals 스테퍼 aria, `plan_element_builder.dart`(현재 모두 편집 가능), `planningDocumentTargetKeys`. 출처 C-5, C §2.3 | (a) 목표 키 모두 유지, 성급은 WEAPON 옆 스테퍼, 나머지는 카드 하단 접힘 "더 보기" (b) 시안대로 제거 | (a). 3단계 카드 제목 "성급 · 전용무기"와 현재→최종 ★ 표기가 성급 편집을 전제하고, 기능 손실 없이 되돌리기 쉽다. 검수에서 확인 | FE4-c | 워커 재량 |
| FD-073 | 단계 이름("성장 기반" 등)은 어디서 정하는가? | Flow-2 카드 제목, C §2.6 | — | 프리셋 적용 시 프리셋 단계 이름, 카드 헤더 인라인 편집, 기본 "n단계" | FE4-c | 워커 재량 |
| FD-074 | 시안의 단계 프리셋, 내 그룹, 필터 프리셋을 이번 워크플로에서 영속 저장하는가, 어디에(프로필별/앱 전역) 두는가? | Flow-2-Goals 프리셋 바·C 패널, Flow-1-Students "내 그룹", Student-Filter·Flow-1-Students-Filter·Stats-Filter-Open "프리셋" 칩. `planning_models.dart` `defaultPlanElementPresets = []`(영속화 유예 주석), `PlanElementPreset`(단계 이름 없음). 출처 B-10, C-10, C §1.6, C §2.5 | (a) 셋 다 프로필별 repository 신규 버킷(백엔드+프로토콜+mock) (b) 단계 프리셋·내 그룹은 (a), 필터 프리셋은 이번 범위 제외(칩 숨김) (c) 셋 다 인메모리 유지(재시작 시 사라짐) (d) 앱 전역 저장(프로필 무관) | **사용자 선택: 권장안 (b)** — (b). 단계 프리셋은 Flow-2의 중심이라 사라지면 흐름이 깨지고, 내 그룹은 학생 ID 목록이라 프로필에 묶인다. 필터 프리셋은 시안에 동작 설명이 없다. 단계 프리셋에 단계 이름 필드 추가 | FE3-d, FE4-b, FE4-c, FE7-e | 확정 2026-10-06 |
| FD-075 | "한 번에 MAX"·"직접 입력"은 프리셋인가 모드인가? | Flow-2 프리셋 세그먼트. 출처 C-10 | — | 모드(MAX = 1단계에 최대값, 직접 입력 = 빈 1단계). 저장 대상 아님 | FE4-c | 워커 재량 |
| FD-076 | 미보유 학생의 "모집"(엘리그마) 단계를 계산하는가? | Flow-3 "슌 1단계 · 모집 · Lv.80 / 엘리그마 80", `planningDocumentTargetKeys`(보유 키 없음). 출처 C §1.7 | — | 1차는 미보유 학생 현재값을 최소값으로 보고 "모집 필요" 칩만, 모집 비용은 백엔드 지원 확인 후 FB-9 | FE4-b, FE4-c | 워커 재량 |
| FD-077 | "고른 학생" 패널이 목록형에서 압축 그리드로 바뀌는 기준은? | Flow-1-Students(3명) vs -Many(14명). 출처 C-9, C §1.7 | — | 7명 이상이면 압축 그리드 | FE4-b | 워커 재량 |
| FD-078 | 한 명/여러 명 모드 전환과 흐름 섹션 intro/outro는? | 시안에 정의 없음. 출처 C-9, C §0 | — | 부착면 규칙(frontend-section-direction-and-user-flows.md §1.4), 모드 전환은 B·C rect 보간 360ms | FE4-a, FE4-b | 워커 재량 |
| FD-079 | A의 "저장하고 닫기"와 C의 "시나리오로 저장", "저장한 뒤" 2항목, 설명 입력은? | Flow-4-Save. 출처 C-7 | — | 같은 저장 동작, 두 버튼 라벨은 C 선택을 따름. "저장한 뒤" 2항목은 독립 토글. 설명 입력 없음(목록 "이름 · 설명"에서) | FE4-e | 워커 재량 |
| FD-080 | "활성 계획에 페이즈로 추가했을 때" 비교는 어떻게 계산하는가? | Flow-4-Save "지금 활성 계획과 비교". 출처 C §4.2 | — | 클라이언트가 활성 + 새 페이즈 병합 문서를 만들어 `compareScenarios(active, merged)` | FE4-e | 워커 재량 |
| FD-081 | 계획 만들기 흐름의 진입점은? | Flow A (i) "학생 탭 이 학생 목표 정하기 → 2단계 / 계획 탭 페이즈 순서 바꾸기 → 3단계 / 시나리오 이걸로 새로 만들기 → 1단계". 갱신: frontend-section-direction-and-user-flows.md 계획 흐름 서술(절 번호 미확인) | — | (i) 문구대로. 계획 탭 S1 "새 시나리오" → 1단계 | FE4-a | 확정(FD-001 적용) |

## §5 시나리오 (FE5)

| ID | 질문(한 문장) | 근거 | 선택지 | 권장안과 이유 | 막는 slice | 상태 |
|---|---|---|---|---|---|---|
| FD-082 | 계획 탭을 열면 무엇이 보이며, 활성 계획은 시나리오 Detail과 같은 3섹션 레이아웃으로 보이는가? | Scenario-Detail-*(3섹션 400/864/1664), Scenario-List "활성 계획으로"·고정 행, 현 `planStudioDocument` element-1~5(활성 계획 홈 시안 없음). 출처 D-1, C §5, C-8 | (a) 첫 화면 = 활성 계획을 Detail 3섹션 레이아웃으로(비교 KPI·delta 칩 숨김), S1에 시나리오 목록·계획 만들기·페이즈 편집 (b) 첫 화면 = Scenario-List, 활성 계획은 고정 행 → Detail (c) 활성 계획 홈은 현 5섹션 유지, 시나리오 보기만 Detail 레이아웃 | **사용자 선택: 권장안 (a)** — (a). 탭 설명 "육성 목표와 필요 재화"와 지금의 첫 화면(활성 계획)을 지키고, "같은 화면 뷰 전환" 결정과 맞으며, 병목/페이즈별/전체 탭 코드가 한 벌이 된다 | FE4-a, FE5-c, FE5-f | 확정 2026-10-06 |
| FD-083 | 목록 고정 행·미리보기 KPI의 활성 계획 요약은 어디서 계산하는가? | Scenario-List 활성 계획 행, `scenario_service.dart` `PlanningScenarioCalculationSummary`. 출처 D §1.5 | (a) 클라이언트 projection 계산 (b) 백엔드 요약 | FB-1의 활성 계획 get 응답에 scenario.list와 같은 요약 형태를 포함(같은 계산 경로). FB-1 전에는 클라이언트 계산 | FE5-a | 워커 재량 |
| FD-084 | 비교 슬롯 A(활성 고정)와 Compare의 "기준 계획 A~D 선택"을 어떻게 함께 두는가? | Scenario-List S1 "활성 계획 · 기준 · 뺄 수 없습니다", Scenario-Compare "기준 계획". 출처 D-2 | — | 활성 계획은 슬롯 A 고정, Compare 기준은 A~D 중 선택(± 기준만 바뀜). 시나리오끼리 비교는 기준을 B로 바꿔서 | FE5-a, FE5-e | 워커 재량 |
| FD-085 | 두 개만 담았을 때의 A↔B 상세 비교(새 시안 없음)는? | Scenario-List "둘만 담으면 A↔B 상세 비교로 열립니다". 출처 D-3 | — | 기존 `PlanScenarioComparisonSection` 2-pane 유지, 후보 목록(`_ComparisonCandidateDiagonalList`)만 제거 | FE5-e | 워커 재량 |
| FD-086 | Compare가 viewport보다 길 때(섹션 높이 1503)는? | Scenario-Compare. 출처 D-7 | — | 라벨 열 + 4열을 한 Scrollable로 함께 세로 스크롤, 학생 수 제한 없음 | FE5-e | 워커 재량 |
| FD-087 | 시안에 안 그려진 사선 스크롤바·포그를 시나리오 화면에 넣는가? | 출처 D-8 | — | 기존 사선 스크롤바·포그를 List, Detail S2·S3, Compare에 적용 | FE5-a~e | 워커 재량 |
| FD-088 | "계획에 적용…"은 어떤 선택지인가? | Flow-4-Save C, Scenario-List·Detail·Compare. 출처 D-9 | — | 활성 계획 2선택(페이즈로 추가 / 이걸로 바꾸기, 기존 활성은 시나리오로 자동 보존 — FD-067) | FE5-c | 워커 재량 |
| FD-089 | 행을 고를 때마다 compare 호출하는 미리보기 비용은? | 출처 D-10 | — | 선택 시 1회 호출 + (시나리오 revision, 활성 revision, 프로필 revision) 키 캐시, 로딩 표시 | FE5-b | 워커 재량 |
| FD-090 | ShortagePopover(시나리오)와 Flow-4 부족 재화 플라이아웃을 하나로 만드는가? | 출처 D-11, H §6.5 | — | `AnchoredFlyout` 위 프리셋 2종(분야별 그룹 / 부족량·단계별 seg) | FE2-c, FE5-b | 워커 재량 |
| FD-091 | 계획 탭 헤더 부제를 "육성 목표와 필요 재화 · 시나리오"로 바꾸는가? | 코드 `ui/app_section.dart` `AppSection.plan` description(문서 없음). 출처 D-12 | — | 바꾼다 | FE5-a | 확정(FD-001 적용) |
| FD-092 | 3~4개 비교는 어떤 호출로 하는가? | `planning.scenario.compare`(쌍만). 출처 D §3.5 | — | 우선 클라이언트 N−1회 쌍 비교, 체감 지연이 크면 FB-9 다중 비교 | FE5-e | 워커 재량 |
| FD-093 | Compare의 "+n종 더"·"전체" 링크와 stale 경고 위치는? | Scenario-Compare. 출처 D §3.4, D §3.5 | — | "+n종 더" → ShortagePopover, "전체" → 그 열 Detail 전체 탭, stale은 열 헤더 "저장 시점과 다름" 칩 | FE5-e | 워커 재량 |

## §6 인벤토리 (FB-2, FB-3, FE6)

| ID | 질문(한 문장) | 근거 | 선택지 | 권장안과 이유 | 막는 slice | 상태 |
|---|---|---|---|---|---|---|
| FD-094 | 인벤토리 기본 진입을 부족 진단("부족한 것")으로 하는가? | 갱신: frontend-section-direction-and-user-flows.md §6 검수 포인트("기본 진입을 보유량 목록/부족 진단 중 어디에"). 출처 E§1.6-5, Inventory.dc 사이드바 | — | 부족 진단 기본 | FE6-a | 확정(FD-001 적용) |
| FD-095 | 사이드바 최상단 seg("아이템·장비" vs "목록·분석")와 종류 버튼은 백엔드 category와 어떻게 대응하는가? | Inventory/-All vs -Analysis 사이드바, `developer_tools_main.dart` `_itemCategoryLabel`. 출처 E-3, E§2.6-1·2, E§3.6-1 | — | 최상단 "목록·분석" seg, 목록 모드에서 그 아래 "아이템·장비" seg. 종류 버튼 = category 1:1(시안 라벨), 시안에 없는 present·workbook은 끝에 추가, "선택권·상자"는 해당 category가 생길 때까지 숨김(추정) | FE6-a, FE6-b, FE7-c | 워커 재량 |
| FD-096 | 크레딧·엘리그마 보유량은 어디서 오는가(스캔 대상·카탈로그에 없음)? | Inventory A 주요 재화 카드, Stats-Inventory B3, `developer_tools_main.dart` `_itemCategoryLabel`(통화 없음), `InventoryScanProfile`. 출처 E-5, E§1.6-4 | (a) FB-3에서 카탈로그에 통화 항목을 추가하고 수동 입력(수량 직접 고치기), 스캔은 후속 (b) 이번 범위 제외, 항상 "스캔 없음" 빗금 (c) 스캔 대상 추가(FB-4 범위 확장) | **사용자 선택 (c)**: 크레딧·엘리그마를 스캔 대상에 추가한다. 인식은 스캐너 워크플로 소관(FB-10 요청에 추가), 카탈로그에 통화 항목을 넣는 것은 FB-3. 스캔이 생기기 전에는 "스캔 없음" 빗금으로 그리고 수동 입력은 두지 않는다 | FB-3, FE7-h | 확정 2026-10-06 |
| FD-097 | 시안에 없는 "이론상 전체 요구량"·"과잉 재화 정리" 화면은? | Inventory-Analysis 사이드바. 출처 E-7, E§3.6-2 | — | 이번 범위 제외: "이론상 전체 요구량" seg 옵션은 비활성(준비 중), "넘치는 재화 정리" 버튼은 숨김 | FE6-c | 워커 재량 |
| FD-098 | 티어 표기(노트·BD 초급~최상급, 오파츠 T1~T4, 설계도 T1~T10)를 카탈로그에서 어떻게 담는가(FB-3)? | Inventory-Tiers, Inventory-Analysis S4. 출처 E§5.6-2, E §3.5 | — | `tier` = family 안 정수 순위(1부터), 표시 라벨은 family별 맵. `school`·`family`(오파츠 종류·장비 부위)와 함께 `InventoryCatalogEntry.fromWire` 동시 수정. **노트·BD 라벨은 1 초급 · 2 일반 · 3 상급 · 4 최상급(앱 전체, 사용자 결정 2026-10-12 FE6-e 세션 — FE6-c의 "중급" 대체)**, 오파츠·설계도 `T<n>` | FB-3, FE6-c, FE6-e | 워커 재량 · 라벨 사용자 결정 |
| FD-099 | 분석·티어 화면의 학교·오파츠 목록 범위(6 vs 9, 8종 vs 13종)는? | 출처 E§3.6-4·5, E§5.6-3 | — | Analysis = 활성 계획이 쓰는 학교·오파츠만, Tiers = 카탈로그 전부 | FE6-c, FE6-e | 워커 재량 |
| FD-100 | "계획 필요 환산량 기준"(하위 티어 환산)을 계산하는가? | Inventory-Analysis S1 칩. 출처 E §3.5 | — | 환산 없이 티어별 그대로, 칩 숨김(환산 규칙 근거 없음, 추정) | FE6-c | 워커 재량 |
| FD-101 | 학생별·단계별 필요량 분해("막히는 단계", "쓰는 학생 · 필요량 순")는 어디서 가져오는가? | Inventory D, Inventory-Analysis 플라이아웃, Stats-Inventory 오른쪽. 출처 E-2, E §1.5 | — | 활성 문서 계산의 `stage_results[].resources` 사용, 부족한 키는 FB-3에서 확장 | FE6-a, FE6-c | 워커 재량 |
| FD-102 | "보충 방법"(획득처·주간량·선택권) 데이터는 어디서 오는가? | Inventory D, Inventory-All D. 출처 E §1.5 | — | FB-3에서 백엔드 메타데이터 파일에 수기 표로 시작, 항목이 없으면 "획득처 정보 없음" | FB-3, FE6-a | 워커 재량 |
| FD-103 | 오파츠 확장의 세부(점 → 아이콘 전환, 부제 변경, 축소 aria, 확장 전 점 선택)는? | Inventory-Analysis-Opa. 출처 E§4.6 | — | 크로스페이드, 확장 상태는 탭 안 로컬 상태(부제 포함), "축소"에 aria-label 추가, 확장 전에도 점 선택 가능 | FE6-d | 워커 재량 |

## §7 통계 (FE7)

| ID | 질문(한 문장) | 근거 | 선택지 | 권장안과 이유 | 막는 slice | 상태 |
|---|---|---|---|---|---|---|
| FD-104 | 학생 성장(A) 범위는 Proposal 확정 사항 1의 "머리글 토글로 학생 탭 필터 사용"인가, 화면 시안의 "통계 전용 필터 + 학생 탭 필터 불러오기"인가? | Statistics-Proposal 확정 사항 1 vs Stats-Growth-Filter·Stats-Filter-Open("학생 탭 필터와 따로 저장"). 출처 F-1 | (a) 통계 전용 필터(앱 실행 동안 유지, 학생 탭과 별개) + "학생 탭 필터 불러오기" (b) Proposal대로 머리글 토글(프로필 전체 / 학생 탭 필터), 별도 필터 없음 (c) (a)이되 통계 필터를 영속 저장 | **사용자 선택: 권장안 (a)** — (a). 더 구체적인 화면 시안 3장이 일관되게 이 모델이고, 두 탭 필터가 서로 덮어쓰지 않는다. 공용 필터 모달(FE3-d)은 상태 객체를 받는 구조로 만든다 | FE3-d, FE7-a, FE7-e | 확정 2026-10-06 |
| FD-105 | KPI는 Proposal의 주제 횡단 한 줄인가, 화면 시안의 주제별 5개인가? | 출처 F-2 | — | 주제별 5개(화면 시안), 누르면 같은 주제 안 그래프로 스크롤 | FE7-b, FE7-c | 워커 재량 |
| FD-106 | 1차/2·3차는 무슨 뜻이며, 아직 없는 위젯 자리는 어떻게 두는가? | Statistics-Proposal 확정 사항 2·4, slices FE7-b~i. 출처 F-3 | — | 차수 = 구현 순서(FE7 하위 slice). 미구현 위젯은 빈 카드 없이 레이아웃을 당기고, A6·B3는 스냅샷 1회 문구(확정 사항 4) | FE7-a | 워커 재량 |
| FD-107 | A5 히트맵 "장비" 행은 스킬 레벨 열(1–3/4–6/7–8/9/M)과 어떻게 맞추는가? | 출처 F-6 | — | equip1~3 최저 티어를 T1–3/T4–6/T7–8/T9/T10으로 같은 5열에 대응 | FE7-i | 워커 재량 |
| FD-108 | 원본 탭 이동(D)과 다른 탭의 "계획에서 보기"·"인벤토리에서 보기"는 어떻게 전달하는가? | Statistics-Proposal D("← 통계" 칩), `ui/app_shell.dart` 179행 `_open(AppSection)`(payload 없음), Inventory D "계획에서 보기"(`onOpenPlan` VoidCallback). 출처 F-7, E §1.5 | — | `AppShell._open`에 navigation intent(대상 탭 + 필터·범위, 선택 행, 페이즈·단계, 하위 화면)를 더하고 모든 탭 이동이 같은 intent 사용. "← 통계" 칩은 시안대로 | FE7-d | 워커 재량 |
| FD-109 | 빈 상태 카드가 원래 비율보다 낮아지는가? | Stats-Growth-Filter A4·A6(368 → 328). 출처 F-11 | — | 시안대로 낮게 | FE7-e, FE7-h | 확정(FD-001 적용) |
| FD-110 | B3 seg "스냅샷 6회 / 4주 / 전체"의 뜻은? | 출처 F-12 | — | 최근 6회 / 최근 28일 / 모든 이력 | FE7-h | 워커 재량 |
| FD-111 | 근거 패널 "풀리는 방법"(what-if)은 언제 넣는가? | Stats-Plan 오른쪽. 출처 F §5 근거 | — | FE7-i 이후. 그 전에는 "획득처 보기" 행만 | FE7-c, FE7-i | 워커 재량 |
| FD-112 | C1에 크레딧 행을 넣는가(shortage rows 포함 여부 미확인)? | 출처 F §5 C1 | — | rows에 없으면 `grossScalars['credits']`로 크레딧 행 추가 | FE7-c | 워커 재량 |

## §8 타이틀·홈·스캔 (FB-4, FB-10, FE8) — 스캔 탭 행 FD-140~156은 2026-10-06 추가

| ID | 질문(한 문장) | 근거 | 선택지 | 권장안과 이유 | 막는 slice | 상태 |
|---|---|---|---|---|---|---|
| FD-113 | 계정 관리 클러스터를 시안대로(초상 4열 → 6열, 삼각 무늬 행 → 그라데이션, 구분선 → 진행 막대, Section 4 독립 → 편집 패널 확장, 추가 = 모달, 바깥 Section 5 사다리꼴 표면 제거, 입력 fill + 분홍 포커스, 선택 행 #f2b3ef 3.2px) 바꾸는가? | 갱신: section-template-studio.md「Title 계정 생성·관리 클러스터 적용」~「계정 클러스터 적용 시행착오」절. 출처 A-A-1, A-A-2, A-A-3, A-P-1, A-N-2 | — | 시안대로. Studio JSON(`account_studio_layout.dart`) 재저장 | FE8-b, FE8-c | 확정(FD-001 적용) |
| FD-114 | 계정이 없을 때의 첫 실행, 기존 계정 추가 다이얼로그, v6 가져오기 진입점은? | `title_page.dart` `_createAccount`(`title-account-dialog`), `AccountClusterEntry.createFirst`. 출처 A-T-1, A-N-1, A-N-3 | — | 첫 실행 흐름은 현행 유지(시안 없음), 첫 계정 만들기와 `title-account-dialog`도 새 계정 추가 모달로 통일, v6 가져오기는 현행 진입점(첫 실행 다이얼로그·설정 탭) | FE8-b | 워커 재량 |
| FD-115 | 헤더 지표 표기와 초상 모양, "연결 안 됨" 칩 색을 시안대로 바꾸는가? | `app_shell.dart` `_AppHeader`(`'${n}명'`, square.png 62), `_ConnectionBadge`(disconnected 빨강). 출처 A-H-4, H-7 | — | 숫자만("217", "1,284"), 초상 둥근 사각 62×52 흰 2px, 미연결 회색 | FE8-d | 확정(FD-001 적용) |
| FD-116 | "싯딤의 상자와 연결"은 무엇을 하며 언제 끊긴 것으로 보는가? | Home-Connect-Pick/-Effect/-Connected-Scan, `home_page.dart` 36–40행(현재 스캔 탭 이동), `services/window_dock_service.dart` `dockBeside`(현재 전체 학생 스캔 시작 때만). 출처 A-H-1, A-H-2, A-E-1 | (a) 앱 전역 connectedTarget만 기억 + 창 목록 주기 확인, 창이 닫히거나 목록에서 사라지면 해제(메뉴 B → A 역전이), dock은 지금처럼 전체 학생 스캔 때만 (b) (a) + 연결 즉시 플래너 창을 게임 옆에 dock(v6식) (c) 백엔드 attach 세션(백엔드가 창 감시·해제 이벤트 발행) | **사용자 선택: 권장안 (a)** — (a). 현재 서비스만으로 되고, dock 시점 변경은 사용자 창 배치를 바꾸는 큰 동작이라 따로 정하는 게 안전. Effect 루프 후반 B → A는 해제 연출로 사용 | FB-4, FE8-d, FE8-e | 확정 2026-10-06 |
| FD-117 | 헤더 칩을 게임 창 연결로 바꾸면 백엔드 연결 상태는 어디에 보이는가? | `_ConnectionBadge`(백엔드 상태). 출처 A-H-3 | (a) 칩 하나, 백엔드 끊김이 우선 (b) 칩 2개 | (a) 칩은 게임 창 연결, 백엔드가 끊기면 칩이 "백엔드 끊김"(빨강)으로 우선 표시 + RecoveryBanner | FE8-d | 워커 재량 |
| FD-118 | 창 해상도와 BA 창 판별을 어떻게 받는가(FB-4)? | `services/scanner_service.dart` `ScannerTarget.fromWire`(target_id/title/status만). 출처 A §6.5 | — | `scanner.target.list`에 client 영역 width/height와 백엔드 판별 `is_game` 추가, 프로토콜 검증·mock 갱신. "선택 예정"은 첫 is_game 창 | FB-4 | 워커 재량 |
| FD-119 | 홈 교체 이펙트의 예비동작·overshoot 곡선과 flash 색 #76D7FF를 공용으로 올리는가? | Home-Connect-Effect 타임라인. 출처 A-E-2, A §7.3 | — | 이 전이 전용 곡선, flash 색은 토큰(`connectFlash`)으로만 추가 | FE8-e | 워커 재량 |
| FD-120 | 홈 스캔 팝업이 생긴 뒤 스캔 탭에는 무엇을 남기는가? | 2026-10-06 스캔 탭 시안 6장(Scan, Scan-Items, Scan-Student-Run/-Review, Scan-Item-Run/-Review), 출처 A-S-1, `survey/I-scan.md` §8 Q2 | — | 시안대로: 스캔 탭 = 준비 상태·최근 스캔(앱 실행 기록)·고르기(학생/아이템, 아이템 다중 선택, 종류별 마지막 스캔)·진행·결과 검토. 게임 창 선택만 홈 패널(스캔 탭에는 "게임 창 다시 선택"). 인벤토리 `_CandidatePanel`과 학생 탭 후보 인계는 스캔 탭 결과 검토로 옮긴다. 팝업과의 관계는 FD-140 | FE6-a, FE8-g1~g5 | 확정(FD-001 적용, 2026-10-06 시안) |
| FD-121 | 스캔을 시작한 뒤 진행·후보 검토는 어디서 보이는가? | Scan-Student-Run, Scan-Item-Run, `scan_page.dart` 245–253행(`dockBeside`), 출처 `survey/I-scan.md` §0-3 | — | 학생 = 백그라운드(진행 창 없음, 머리글 칩 + 스캔 탭 진행 화면, 다른 탭 사용 가능), 아이템 = 게임 창 옆 진행 창(진행/일시정지/완료). 끝나면 스캔 탭 결과 검토. 현행 `onCandidateHandoff` 인계는 폐기(전술 로비는 FE9-c). 학생 전체 스캔의 `dockBeside` 호출은 아이템 쪽으로 옮긴다 | FE8-g2, FE8-g3 | 확정(FD-001 적용, 2026-10-06 시안) |
| FD-122 | (폐기 2026-10-06) 스캔 팝업 전술대항전 타일 — FD-150으로 대체 | 스캔 탭 노트 "전술대항전 스캔은 전술대항전 탭에서만" | — | FD-150 참조 | — | 폐기 2026-10-06 |
| FD-123 | (폐기 2026-10-06) 선물(presents) 스캔 위치 — FD-151로 대체 | 스캔 탭 시안에도 선물 타일 없음 | — | FD-151 참조 | — | 폐기 2026-10-06 |
| FD-124 | 해상도에 따라 스캔 타일을 비활성하는가? | post-consolidation-status.md O0-6(창 크기별 활성 정보). 출처 A §8.3 | — | FB-4 해상도 + 인식 프로필 활성 정보로 비활성, 이유는 (i)로 | FE8-f | 워커 재량 |
| FD-125 | 다른 탭의 스캔 버튼(통계 "다시 스캔", 인벤토리 "인벤토리 스캔", 전술 "지금 스캔")은 어디로 가는가? | 출처 A §1 | — | 통계·인벤토리 = 스캔 팝업을 해당 종류 강조로 열기(미연결이면 창 선택 패널 먼저), 전술 = 탭 안 로비 스캔 | FE6-a, FE7-a, FE8-f, FE9-c | 워커 재량 |
| FD-140 | 홈 스캔 팝업과 스캔 탭 고르기는 어떤 관계인가? | Scan·Scan-Items·Scan-*-Run·Scan-*-Review, 출처 `survey/I-scan.md` §9.3 | (a) 팝업 타일 = 그 종류 하나 바로 시작(학생은 머문 자리에서 백그라운드, 아이템은 진행 창), 검토는 스캔 탭. 스캔 탭 = 다중 선택·마지막 스캔·안내가 있는 본 화면. 둘 다 같은 컨트롤러 (b) 팝업 타일 = 스캔 탭 고르기로 이동 + 그 종류 미리 선택(시작은 스캔 탭) (c) 팝업 폐기, 홈 `스캔` 버튼 = 스캔 탭 이동 | **사용자 선택: 권장안 (a)** — (a). 팝업 (i) "열어 둔 뒤 누르십시오"와 맞고 홈에서 한 번에 시작된다. 전제조건·추정치는 컨트롤러 한 곳에 있다 | FE8-g1, FE8-f3 | 확정 2026-10-06 |
| FD-141 | 아이템 진행 창은 플래너 창을 줄여 붙이는가(현행 `dockBeside`), 별도 작은 창인가? | Scan·Scan-Items·Scan-*-Run·Scan-*-Review, 출처 `survey/I-scan.md` §9.3 | (a) 현행 `dockBeside`/`restore` 재사용: 플래너 창이 1:2 진행 창이 되고 끝나면 복원 (b) Windows 러너에 별도 top-level 창 추가(플래너는 뒤에 그대로) (c) 진행 창 없이 게임 창만 앞으로, 진행은 플래너(뒤) | **사용자 선택: 권장안 (a)** — (a). 이미 동작하는 네이티브 경로이고 포그라운드 스캔 동안 플래너를 쓸 수 없는 점은 시안과 같다. 시안 그림의 "플래너 뒤로 감"은 "진행 창으로 바뀜"으로 해석 | FE8-g3 | 확정 2026-10-06 |
| FD-142 | 일시정지·이어서(버튼, 최소화, 입력 감지)를 지원하는가? | Scan·Scan-Items·Scan-*-Run·Scan-*-Review, 출처 `survey/I-scan.md` §9.3 | (a) 스캐너 워크플로에 `scanner.session.pause/resume` + `paused` 이벤트(reason) 추가, D21을 "입력 감지 → 일시정지 → 사용자 이어서"로 개정, Esc = 중지 (b) 일시정지 없음: 버튼 숨기고 입력 감지는 D21(재시도 → partial), 최소화는 실패로 끝남 (c) 프론트 일시정지 = 중지 후 같은 종류 새 세션(읽은 칸 유지 안 됨) | **사용자 선택: 권장안 (a)** — (a). 시안 3장이 일관되게 요구하고 "읽은 칸은 남습니다"는 같은 세션 안에서만 지킬 수 있다. FB-10 전에는 (b)로 동작 | FB-10, FE8-g2·g3 일시정지 부분 | 확정 2026-10-06 |
| FD-143 | 아이템 여러 종류를 한 번에 스캔할 때 세션을 어떻게 돌리는가? | Scan·Scan-Items·Scan-*-Run·Scan-*-Review, 출처 `survey/I-scan.md` §9.3 | (a) 프론트 큐: 종류마다 세션을 차례로, 진행 창은 유지, 검토는 합쳐 표시 (b) `scanner.session.start`에 `inventory_scan_profiles` 목록 additive | (a). 프로토콜 변경 없이 되고 종류별 진행·후보 commit이 이미 세션 단위다. 종류 사이 전환 지연이 크면 (b) | FE8-g3 | 워커 재량 |
| FD-144 | 학생 검토 분류와 "계산 일치 일괄 적용"은 어떻게 하는가? | Scan·Scan-Items·Scan-*-Run·Scan-*-Review, 출처 `survey/I-scan.md` §9.3 | (a) 프론트 순차: 학생마다 review(approve) → commit, 응답 revision을 다음 expected로, 실패하면 멈추고 남은 후보 유지 (b) 백엔드 일괄 commit 원자 처리 | (a). 분류 = 확인 필요(`_hasProblem`) / 새 학생(확정값 없음, 재검증 먼저) / 바뀐 학생(diff 있음 + 문제 없음 + 계산 delta 0) / 그대로(diff 없음, 적용 불필요) | FE8-g4 | 워커 재량 |
| FD-145 | 학생 폴백 캡처 crop과 "계산 역산" 값은 어디서 오는가? | Scan·Scan-Items·Scan-*-Run·Scan-*-Review, 출처 `survey/I-scan.md` §9.3 | (a) 스캐너 워크플로가 폴백으로 넘어간 필드만 evidence details에 crop(png base64)·역산값을 additive로 추가하고 적용·폐기 시 삭제(시안 각주), 프론트는 있으면 표시 (b) 이번 범위 제외(카드에 판독값·신뢰도만) | (a). 시안이 보관 정책까지 적어 두었다. 진단 JSON의 `images_included:false`는 유지 | FB-10, (FE8-g4는 막지 않음) | 워커 재량(백엔드 요청) |
| FD-146 | 아이템 칸별 승인·부분 적용과 남은 칸의 "확인 필요" 표시는 어떻게 저장하는가? | Scan·Scan-Items·Scan-*-Run·Scan-*-Review, 출처 `survey/I-scan.md` §9.3 | (a) 백엔드: commit에 승인 entry 목록(또는 review payload에서 제외 = 이전 값 유지 의미 명시) + 승인 entry만 정답 샘플 + repository entry별 `needs_review` 영속 표시 (b) 부분 적용은 하되 `확인 필요`는 앱 실행 동안만(보류 후보에서 유도) (c) 현행처럼 후보 전체 승인만 | **사용자 선택: 권장안 (a)** — (a). 시안 문구 "인벤토리에 이전 값으로 남고 '확인 필요'로 표시"는 영속 표시로 읽힌다. **해제 범위(사용자 결정 2026-10-12, XB 02:31 권장안)**: 수동 편집·가져오기는 실제로 적용한 resource key의 표시만 해제하고 나머지 key는 유지. 스캔은 승인(applied) key만 해제, 인식했지만 제외한 key는 이전 수량 + 확인 필요 유지, 식별 못 한 slot에는 key를 만들지 않음. 수동·가져오기에 가짜 스캔 시각을 붙이지 않음(FB-10b). 인벤토리 탭(FE6-a)도 같은 필드를 그린다 | FB-10, FE8-g5, FE6-a | 확정 2026-10-06 |
| FD-147 | "종류별 마지막 스캔"·"아이템별 n일 전 스캔"은 어디서 오는가? | Scan·Scan-Items·Scan-*-Run·Scan-*-Review, 출처 `survey/I-scan.md` §9.3 | (a) FD-041 이력 레코드에 `scan_kind`·`inventory_scan_profile`을 더하고 종류별·resource_key별 최신 scan 커밋 시각을 조회. 전부 "그대로"인 적용도 시각 기록 (b) 세션 완료 시각(적용 여부 무관)을 프로필 메타에 종류별로 저장 | (a). FB-2 하나로 계정 메타 줄·통계·인벤토리와 출처가 같아진다. 표시 규칙: 막대 = 경과일/14(상한), `최근` ≤ 7일, `오래됨` > 7일, `스캔 없음` | FB-2, FE8-g1(막대는 FB-2 전 "—") | 워커 재량(FD-041 확정 후) |
| FD-148 | 머리글 연결 칩 자리에 스캔 진행을 어떻게 겹쳐 보이는가? | Scan·Scan-Items·Scan-*-Run·Scan-*-Review, 출처 `survey/I-scan.md` §9.3 | — | 우선순위 백엔드 끊김(빨강) > 스캔 진행/일시정지(분홍 `학생 스캔 34 / 128`, 일시정지는 wn) > 게임 창 연결(녹/회). 누르면 스캔 탭 진행·검토. 탭 `스캔`에 분홍 점. 완료 시 앱 안 토스트(누르면 검토) | FE8-f2 | 워커 재량(FD-117 확장) |
| FD-149 | 스캔 탭 "최근 스캔"은 앱 실행 기록인가, 영속 기록인가? | Scan·Scan-Items·Scan-*-Run·Scan-*-Review, 출처 `survey/I-scan.md` §9.3 | (a) 앱 실행 기록(현행 `ScannerRecentSummary`, 8건) + 시작 시각·종류 라벨·확정 여부 필드 추가 (b) 영속 세션 기록 | (a). 시안 각주가 명시한다. 날짜 예시는 표본 값 | FE8-g1 | 워커 재량 |
| FD-150 | 홈 팝업의 `전술대항전(준비 중)` 타일은? (FD-122 개정) | Scan·Scan-Items·Scan-*-Run·Scan-*-Review, 출처 `survey/I-scan.md` §9.3 | (a) 제거 (b) 전술대항전 탭으로 이동하는 링크 타일(로비 스캔은 탭 안, FE9-c) (c) FD-122대로 FE9-c 후 팝업에서 로비 스캔 시작 | (b). 스캔 탭 노트 "전술대항전 탭에서만"을 지키면서 찾기 쉬움은 남는다 | FE8-f3 | 워커 재량 |
| FD-151 | 선물(presents) 스캔은 어디서 하는가? (FD-123 개정) | Scan·Scan-Items·Scan-*-Run·Scan-*-Review, 출처 `survey/I-scan.md` §9.3 | (a) 스캔 탭 아이템 줄 7번째 타일(타일 폭 축소)과 팝업 "기타" 줄 추가 (b) 이번 범위 제외(enum·백엔드는 유지, UI 없음) | **사용자 선택: 권장안 (a)** — (a). 1080에서 활성 프로필이라(O0-6) 기능을 잃지 않는다. 두 시안 모두 생략했으므로 확인 필요 | FE8-g1, FE8-f3 | 확정 2026-10-06 |
| FD-152 | 시안에 없는 학생 검토 기능(`화면 확인` 표시, 다른 의상 인연 랭크 입력, 진단 JSON 추출)은 어디에 두는가? | Scan·Scan-Items·Scan-*-Run·Scan-*-Review, 출처 `survey/I-scan.md` §9.3 | — | `화면 확인` = S3 폴백 카드와 값 주석 옆 토글(README 학습 규칙 유지, 고치지 않은 값은 학습 안 함). 인연 랭크 = 해당 학생 S3에 입력 줄. 진단 JSON = 개발 상태 패널 | FE8-g4 | 워커 재량 |
| FD-153 | 아이템 검토에서 미식별(identity) 칸은 어떻게 보이는가? | Scan·Scan-Items·Scan-*-Run·Scan-*-Review, 출처 `survey/I-scan.md` §9.3 | — | `확인 필요` 칸 변형(아이콘 `?` + 호박색 테두리). 선택하면 S3에 기존 `ScanInventoryIdentityReview`(1 슬롯)를 그대로 마운트(파일 수정 없음). "그리드 스캔은 캡처를 남기지 않습니다" 문구는 미식별 칸에서는 숨김 | FE8-g5 | 워커 재량 |
| FD-154 | 진행 추정치(`약 8분`, `약 58칸`, `남은 시간`, 학생 total)는 무엇으로 계산하는가? | Scan·Scan-Items·Scan-*-Run·Scan-*-Review, 출처 `survey/I-scan.md` §9.3 | — | 칸 수 = 카탈로그 `profileId` 개수, 학생 total = `progress.total`이 있으면 그것, 없으면 보유 수에 "약"을 붙임, 시간 = 종류별 기본 상수 → 진행 중에는 실측 속도로 갱신, 모르면 숨김 | FE8-g1, FE8-g2 | 워커 재량 |
| FD-155 | 스캔 탭의 미연결 상태와 `게임 창 다시 선택`은? | Scan·Scan-Items·Scan-*-Run·Scan-*-Review, 출처 `survey/I-scan.md` §9.3 | — | 미연결이면 시작 버튼 비활성 + S3 자리에 홈과 같은 `ConnectTargetPanel`(오른쪽 부착) 표시. `게임 창 다시 선택`도 같은 패널. 연결 상태는 FE8-d 전역 `connectedTarget` | FE8-g1 | 워커 재량(FD-116 확정 후) |
| FD-156 | 진행 중 실시간 정보(지금 읽는 학생 값, 방금 읽은 학생 diff, 아이템 NOW READING·최근 기록)는 어디서 오는가? | Scan·Scan-Items·Scan-*-Run·Scan-*-Review, 출처 `survey/I-scan.md` §9.3 | (a) 학생·종류 단위 후보를 진행 중에 바로 `candidate` 이벤트로 내보내고 인벤토리 `feedback`에 아이템 id·수량을 넣도록 스캐너 워크플로에 요청, 프론트는 받은 만큼 계산 (b) 끝나기 전에는 진행 수치만 | (a). 이벤트가 오기 전에는 (b)처럼 숨김. mock은 진행 중 후보 스트리밍으로 확장 | FB-10, FE8-g2·g3 일부 | 워커 재량(백엔드 요청) |

## §9 전술대항전 (FB-6, FB-7, FE9)

| ID | 질문(한 문장) | 근거 | 선택지 | 권장안과 이유 | 막는 slice | 상태 |
|---|---|---|---|---|---|---|
| FD-126 | 기록·분석·슬롯 통계 세 화면을 무엇으로 오가는가? | Tactical/-Analysis/-Slots(헤더 부제만 다르고 이동 UI 없음, Slots 진입점 0, "상대 카드 보기" 링크만). 출처 G-A1 | (a) 헤더 제목 옆 하위 seg "기록·분석·슬롯" (b) 각 화면 S1 위쪽에 계획 탭식 "보는 중" 레일 버튼 (c) 링크만(기록 S4 → 분석, 분석 → 슬롯 등) | **사용자 선택: 권장안 (a)** — (a). 세 화면 S1 내용이 모두 달라 공통 레일 자리가 없고, seg는 FE2-b `SkewSegmented` 재사용. 헤더 부제가 이미 화면 이름 역할 | FE9-a, FE9-e, FE9-g | 확정 2026-10-06 |
| FD-127 | 다수 사용자 데이터가 필요하거나 확률·보정 성격인 지표(상대 방어 승률 30일, 채택률, 독립 재현, 상위 500위 슬롯 통계, 변경 확률 63%, 보정 방어, 검증 강도)를 어디서 얻고 어떻게 부르는가? | Tactical S2·S4, Tactical-Analysis S2·S3, Tactical-Slots S1·S2, v2 terminology(`observed_win_rate`, `evidence_weight_share_not_probability`, `population_warning`), frontend-section-direction-and-user-flows.md §7 "고급 추천과 승률 분석은 별도 범위". 출처 G-A4, G-A5, G-A6, G-A8 | (a) 관측 지표만: 내 기록 + v2 공유 파일 가져오기(`importTacticalShares`) 집계로 나오는 것만 표시, 확률·보정 지표와 상위 500위 모집단 통계는 숨김(빈 상태 설명) (b) (a) + 백엔드 모델 지표 신설(변경 확률·보정 방어 등, terminology 개정) (c) 내 기록만(공유 데이터 제외) | **사용자 선택: 권장안 (a)** — (a). 기존 v2 계약(관측 원칙)을 깨지 않고 대부분 화면을 채운다. Slots S2는 데이터원이 생길 때까지 빈 상태. §7 문구는 FD-001에 따라 갱신 | FB-6, FE9-c, FE9-d, FE9-e, FE9-g | 확정 2026-10-06 |
| FD-128 | 시도 횟수·빈칸·슬롯 출처·상대 identity를 저장하려면 기록·족보를 v2로 일원화하는가, 족보는 수동 등록인가 기록에서 도출하는가(FB-6)? | Tactical S3(시도 스테퍼·빗금 빈칸·출처 범례), Tactical-Analysis "족보 편집"·"족보 A · 호시노 중심", `ui/pages/tactical_page.dart`(v1 `TacticalService`만), `TacticalEvidenceService`(v2 쓰기 메서드 없음), `MockAppService`(v2 미구현). 출처 G-A9 | (a) v2 일원화: v2 match/jokbo upsert 신설, v1 기록은 v2로 이관 후 v1 쓰기 중단, 족보 = 기록에서 자동 도출 + 사용자가 이름·편집(자동 이름 "족보 X · 중심 학생") (b) v1 쓰기 유지 + 시도·빈칸만 v2 보조 저장 (c) v2 일원화하되 족보는 지금처럼 수동 등록만 | **사용자 선택: 권장안 (a)** — (a). 저장 경로가 하나라 빈칸·출처·시도가 분석에 바로 쓰이고, 시안 "같은 시그니처 족보에 자동 연결됨"과 맞는다 | FB-6, FB-7, FE9-b, FE9-f | 확정 2026-10-06 |
| FD-129 | "시그니처 족보 수"와 "완전 방어 덱 족보 수", "독립 재현"은 어떻게 정의하는가? | Tactical S4 "연결 족보 4개", Analysis "족보 7개", 독립 재현 28 vs 12. 출처 G-A2, G-A3 | — | 시그니처 족보 = 그 공개 시그니처를 가진 모든 완전 덱을 깬 족보의 합집합(⊇ 완전 덱 족보), 독립 재현 = share analytics 독립 기여자 수. 시안 수치 차이는 예시(FD-025) | FE9-d, FE9-e | 워커 재량 |
| FD-130 | 위·아래 모두 닿는 중앙 평행사변형(Analysis S2, Slots S2)의 주 부착면은? | 출처 G-A7 | — | 아래(intro 80° / outro 260°) | FE9-e, FE9-g | 워커 재량 |
| FD-131 | 엑셀 가져오기 세부(파서 위치, 형식, 시트 선택, 미리보기 분모, 덮어쓰기 키, 처리 규칙 저장 위치, "스캔 파일 가져오기")는(FB-7)? | Tactical-Import-Excel, almanac/architecture/runtime-boundaries.md, 기존 `previewTacticalV6Import`/`commitTacticalV6Import`. 출처 G-A10, G §5.5 | — | Python 백엔드 파서(preview/commit, 경계 문서·기존 가져오기 선례), .xlsx + .csv, 시트가 여럿이면 모달 헤더에 시트 seg, 미리보기 분모 = 가져올 건수, 덮어쓰기 키 = 날짜·시각(있으면) + 상대 + 구분, 처리 규칙은 프로필별 저장, "스캔 파일 가져오기"는 이번 범위 제외(버튼 숨김) | FB-7, FE9-f | 워커 재량 |
| FD-132 | 기록 목록의 방어 기록 행은 어떻게 표기하는가? | 출처 G-A11 | — | "내 방어덱 · vs 공격자"(이름 있으면), v2에서는 상대 없이도 저장 | FE9-a | 워커 재량 |
| FD-133 | 슬롯 화면 S1 "내 방어 덱"은 어디서 오는가? | 출처 G-A13 | — | 가장 최근 방어 기록의 덱으로 유추, 화면에서 바꿔 볼 수 있으나 저장 안 함 | FE9-g | 워커 재량 |
| FD-134 | "검증 강도 A"와 "표본 적음" 기준은? | `TacticalRecommendationResult.confidenceGrade`, `populationWarning`, Analysis-All 각주. 출처 G §2.5 | — | high/medium/low → A/B/C, unavailable "—". 표본 적음 = 독립 재현 5명 미만 또는 `populationWarning` | FE9-e | 워커 재량 |

## §10 마감 (FE10)

| ID | 질문(한 문장) | 근거 | 선택지 | 권장안과 이유 | 막는 slice | 상태 |
|---|---|---|---|---|---|---|
| FD-135 | 택틱 탭(9탭, 선반 860px)을 위해 셸 규칙을 어떻게 바꾸는가? | `app_shell.dart` `_buildLGlassPath`(min(760, …)), Tactic-*(범위 밖). 출처 H-12 | (a) 선반 폭을 탭 수로 계산 (b) 760 유지 + 가로 스크롤 | (a) 8탭 760 → 9탭 860. 택틱 탭 추가 자체는 택틱 워크플로 소관 | FE10 | 워커 재량 |
| FD-136 | FE10에서 정리할 문서는 무엇인가? | FD-001 적용 행의 "갱신" 목록 | — | FD-001 적용 문서는 각 slice에서 갱신(FD-001). FE10은 frontend-section-direction-and-user-flows.md §8·§13 결정문화 확인, README·테스트 목록 갱신, 이 대장의 확정 행에 문서 링크를 달아 마감 | FE10 | 워커 재량 |
| FD-137 | 어떤 코드를 죽은 코드로 지우는가? | B §1-4·§2-4, C §8(slice 6), D §3.4, E §1.4, G §1.4 | — | 학생 Section 5 필터 코드와 `StudentRangeConditionSection`, `studentCardInfoAreaFraction` 등 카드 정보 띠 상수, `DiagonalSection`(교체 완료 후), `_DeckEditor`, `_ComparisonCandidate*`, 계획 메인 Section 1 버튼 묶음과 `_PlanWorkspaceSnapshot` 왕복 로직, `dummyPlan*`·`planPrimaryBottleneck*` 등 상수(projection 연결 후) | FE10 | 워커 재량 |
| FD-138 | goals v1과 `calculateShortages` 경로를 남기는가? | FD-003, FD-026 | — | 남긴다(파생 goals로 동작, 백엔드 메서드 삭제 안 함). 새 화면은 활성 문서 경로만 사용 | FE10 | 워커 재량 |
| FD-139 | ValueKey 기반 기존 테스트는 언제 고치는가? | `planning_page_test`, `plan_element_builder_test`, `statistics_page_test`, `inventory_page_test`, `tactical_page_test`, `title_page_test` 등. 출처 C §8, F §4, G §7.2, A §2.4 | — | 각 화면 slice에서 재작성, FE10은 전체 회귀만 | FE10 | 워커 재량 |

---

## slice별 막힘 요약

현재 `열림` 0건(2026-10-06 사용자 일괄 결정: FD-166 (c), FD-096 (c), 나머지 21건 권장안). 아래 표는 새 `열림` 항목이 생길 때를 위해 남긴다.
아래 표의 FD가 `열림`인 동안 그 slice를 시작하지 않는다. 표에 없는 slice는 열림 항목에 막히지 않는다(slice 간 선행 의존은 `almanac/workflows/frontend-redesign-workflow.md`를 따른다).
"(부분)"은 그 FD가 slice 전체가 아니라 적힌 부분만 막는다는 뜻이다. 그 부분은 숨기거나 빈 상태로 두고 나머지를 진행한다.

| slice ID | 시작 전에 '열림'이어서는 안 되는 FD |
|---|---|
| FE0 | — |
| FE1 | — |
| FE2-a / FE2-b / FE2-c / FE2-d | — |
| FE3-a / FE3-b / FE3-c | — |
| FE3-d | FD-074, FD-104 |
| FE3-e | — |
| FE3-f | FD-160, FD-166, FD-162(부분: 크레딧 내역 막대) |
| FE3-g | FD-163 |
| FB-1 | — |
| FE4-a | FD-082 |
| FE4-b | FD-074 |
| FE4-c | FD-074 |
| FE4-d | — |
| FE4-e | FD-031 |
| FE4-f | FD-068 |
| FE4-g | — |
| FE5-a / FE5-b | — |
| FE5-c | FD-034, FD-082 |
| FE5-d | FD-031 |
| FE5-e | FD-034 |
| FE5-f | FD-082 |
| FB-2 | FD-041 |
| FB-3 | — |
| FE6-a | FD-030, FD-031 |
| FE6-b | — |
| FE6-c | FD-031 |
| FE6-d | — |
| FE6-e | FD-031 |
| FE6-f | FD-041 |
| FE7-a | FD-104 |
| FE7-b | FD-028 |
| FE7-c | FD-031, FD-034 |
| FE7-d | FD-028 |
| FE7-e | FD-074, FD-104 |
| FE7-f | FD-028 |
| FE7-g | — |
| FE7-h | FD-041, FD-096 |
| FE7-i | FD-028 |
| FB-4 | FD-116 |
| FE8-a / FE8-b / FE8-c | — |
| FE8-d | FD-116 |
| FE8-e | FD-116 |
| FE8-f1 / FE8-f2 | — |
| FE8-f3 | FD-140, FD-151 |
| FE8-g1 | FD-140, FD-151 |
| FE8-g2 | FD-142(부분: 일시정지) |
| FE8-g3 | FD-141, FD-142(부분: 일시정지) |
| FE8-g4 | — |
| FE8-g5 | FD-146 |
| FB-5 | — |
| FB-6 | FD-127, FD-128 |
| FB-7 | FD-128 |
| FB-8 | FD-068 |
| FB-9 | — |
| FB-10 | FD-142, FD-146 |
| FB-11 | FD-162, FD-163 |
| FE9-a | FD-126 |
| FE9-b | FD-128 |
| FE9-c | FD-127 |
| FE9-d | FD-127 |
| FE9-e | FD-126, FD-127 |
| FE9-f | FD-128 |
| FE9-g | FD-126, FD-127 |
| FE10 | 모든 열림 항목 종결 |
