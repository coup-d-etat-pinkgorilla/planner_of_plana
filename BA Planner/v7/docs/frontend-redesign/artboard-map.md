# Frontend Redesign Artboard Map

- **시안 원본**: Design 캔버스 "BA Planner v7 UI 개선 시안" — https://claude.ai/artifact/BqhYfDnvkiQCTjDv8XgYJ3 (2026-10-05 version `1791201546-3bff` 50장, 2026-10-06 version `1791216886-b4f5`에서 스캔 탭 6장·성장 계산기 1장 추가, 2026-10-20 version `1792494343-3aed`에서 page `firstrun` 58장 추가 — 사본 `prototype/2026-10-20/`)
- **저장소 사본**: `docs/frontend-redesign/prototype/2026-10-05/` (artboard 파일명 동일). 택틱 페이지(`Tactic-*`, `Boss-*`, `Tactical-Timeline.dc.html`)는 범위 밖이라 사본에 없다.
- **범위**: canvas.json `boards` 80개 중 택틱 23개(`Tactic-*` 5, `Boss-*` 17, `Tactical-Timeline` 1)를 뺀 **57개** 전부. 모든 화면 artboard는 2560×1392 절대좌표(최대화 작업영역 canonical viewport)이고 부품 보드(page `parts`)는 크기가 제각각이다.
- **Dart 칸**: 조사 보고서 A~J에서 grep으로 확인된 파일·클래스만 적었다(경로는 `frontend/lib/` 기준). "신규"는 대응 코드가 없다는 뜻이다. 결정이 걸린 항목은 `FD-###`(decision-register.md)로 표시했다.
- **검수 방법**: 캔버스 artboard와 앱을 같은 2560×1392 창에서 나란히 띄우고, 검수 포인트의 2~4가지를 먼저 확인한다. 시안 예시 수치 불일치는 판단에 쓰지 않는다(FD-025).

## 타이틀 (page `title`)

| artboard 파일 | 캔버스 제목 | 화면·상태 | 대상 Dart 파일·클래스 | slice | 검수 포인트 |
|---|---|---|---|---|---|
| Title.dc.html | 타이틀 — v7 구성 유지 (계정 카드 · 로고 띠 · 설정/나가기 · 시작) | 계정 있음, 기본 | `ui/pages/title_page.dart` `TitlePage`·`_StudioTitleCanvas`·`_KeyCap`, `ui/studio/title_studio_layout.dart` `titleStudioDocument` | FE8-a | 시작 버튼 380×116·라벨 34px·분홍 외곽선, Space 키캡이 버튼 아래 14px로 떨어짐 / 계정 카드: 구분선 대신 보유율 진행 막대(−10°) + "보유 217 / 265" 숫자 강조 / 계정 카드 전체를 누르면 계정 관리가 열림 / 로고 띠 불투명 .93 + 분홍 radial glow, 설정 92×54·나가기 110×54 |
| Title-Accounts.dc.html | 타이틀 설정 · 계정 관리 (목록 + 수정) | 레일 "수정" pressed, 편집 패널 열림 | `ui/widgets/account_section_cluster.dart` `AccountSectionCluster._buildManager`·`_buildEditor`·`_DiagonalScrollbar`, `ui/studio/account_studio_layout.dart`, `ui/widgets/scroll_viewport_fog.dart` `ScrollViewportFog` | FE8-b(목록·레일), FE8-c(편집기) | 레일 버튼 높이 74·폭이 목록 사선 따라 줄어듦, pressed 분홍 테두리, "이 계정으로 전환" 비활성 + "지금 쓰는 계정" / 계정 행 그라데이션 + 진행 막대 + `지금` 칩, 선택 행 분홍 3.2px, 목록 하단 포그 / 바깥 사다리꼴 표면 없음(FD-113) / 편집 패널 1000×262, 입력 fill + 분홍 포커스, 메타 줄의 "마지막 스캔"은 FB-2 전까지 숨김 |
| Title-Accounts-Portrait.dc.html | 타이틀 설정 · 초상 고르기 | 편집 패널이 아래로 확장된 초상 선택 | `account_section_cluster.dart` `_buildPicker`·`portraitGridTrajectoryOffset`·`portraitScrollbarTrackPoint`, `ui/widgets/asset_image_grid.dart` `AssetImageGrid` | FE8-c | 별도 Section 4가 아니라 편집 패널 하나가 262 → 850으로 확장 / 초상 6열 × 4행 가시, 행마다 −19px 사선 이동, 사선 스크롤바 / "초상 변경" 자리에 "고르는 중"(분홍), 하단 버튼은 닫기·저장만(닫기 = 버림) |
| Title-Accounts-New.dc.html | 타이틀 설정 · 계정 추가 (새 계정) | 계정 추가 모달 열림 | `account_section_cluster.dart` `_startCreate` 경로 대체, `createProfile`(재사용), 신규 `BaModal` | FE8-b | 스크림 .72 + blur 2 위 평행사변형 모달 / 이름 입력만, 초상 선택 없음 / 제목 옆 (i) 문구, X·취소·만들기(분홍) |

## 홈 (page `home`)

| artboard 파일 | 캔버스 제목 | 화면·상태 | 대상 Dart 파일·클래스 | slice | 검수 포인트 |
|---|---|---|---|---|---|
| Home-Connect-Pick.dc.html | 홈 · 싯딤의 상자와 연결 ① 오른쪽 창 선택 패널 (v6 복원) | 미연결, 창 선택 패널 열림 | `ui/pages/home_page.dart` `HomePage`, `ui/widgets/diagonal_menu.dart` `DiagonalMenuButton`, `ui/app_shell.dart` `_AppHeader`·`_ConnectionBadge`, `services/scanner_service.dart` `ScannerTarget`·`listScannerTargets`, 신규 창 선택 패널 | FE8-d(칩·연결 상태), FE8-e(패널) | 헤더 칩 "연결 안 됨" 회색, 지표 숫자만·초상 둥근 사각(FD-115) / 메뉴 행1에 분홍 3.2px 선택 표시 / 오른쪽 부착 사다리꼴 패널: 창 행(BA 태그·제목·해상도), 선택 행 분홍, 수직 스크롤바, 하단 포그 / 새로고침·취소·선택한 창 사용 |
| Home-Connect-Effect.dc.html | 홈 · 싯딤의 상자와 연결 ② 연결 이펙트 — 메뉴 섹션 빠짐 → 스캔으로 교체 → 들어옴 (반복 재생) | 10초 루프 애니메이션 | `home_page.dart` `_HomeCardData`, `ui/widgets/animated_section_stack.dart` `DirectionalSectionEntrance`·`sectionMotionOffset`, 신규 메뉴 교체 전이 | FE8-e | 메뉴가 +14px 예비동작 뒤 왼쪽으로 퇴장하고 패널은 오른쪽으로 동시 퇴장 / 행1이 "스캔"으로 바뀐 메뉴가 왼쪽에서 들어와 −10 → 0 안착 / 안착 직후 #76D7FF flash 페이드, 칩이 "연결됨 · Blue Archive" 녹색으로 / 해제 시 B → A 역전이(FD-116) |
| Home-Connected-Scan.dc.html | 홈 · 연결 후 ③ 스캔 버튼 → 스캔 팝업 (학생 · 아이템 · 기타) | 연결됨, 스캔 팝업 열림 | `ui/pages/scan_page.dart` `_ScanPageState`(세션 로직 추출 대상), `ScannerKind`·`StudentScanMode`·`InventoryScanProfile`, `ui/widgets/scan_companion_dock.dart` `ScanCompanionDock`, `services/window_dock_service.dart`, 신규 스캔 팝업 | FE8-f3 | 학생 2 / 아이템 5 / 기타 2 타일, 행 라벨이 80° 계단으로 왼쪽 이동 / 타일 대표 이미지가 열 때마다 무작위 / 헤더 칩 "연결됨 · Blue Archive · 2560×1440"(FB-4), "창 다시 선택"·X / 전술대항전 타일 처리(FD-150, 권장: 전술대항전 탭 링크), 선물 타일 여부(FD-151) / 타일을 누르면 바로 시작인지 스캔 탭으로 넘기는지(FD-140) |

## 스캔 (page `scan`, 2026-10-06 추가)

캔버스 노트: "스캔 탭 · 학생 — 게임 창을 뒤에 둔 채 백그라운드로 진행: 고르기 → 진행(플래너 계속 사용) → 결과 검토 (전술대항전 스캔은 전술대항전 탭에서만)", "스캔 탭 · 아이템 — 게임 창이 앞으로 나와 포그라운드로 진행: 고르기 → 진행(게임 창 옆 진행 창) → 결과 검토". `Scan-Item-Run`을 뺀 5장은 통계와 같은 3섹션(S1 0,209,587×1183 / S2 400,209,1702×1183 / S3 1920,209,640×1183)이다. 근거: `survey/I-scan.md`.

| artboard 파일 | 캔버스 제목 | 화면·상태 | 대상 Dart 파일·클래스 | slice | 검수 포인트 |
|---|---|---|---|---|---|
| Scan.dc.html | 스캔 · 고르기 — 학생 전체 선택 (백그라운드) · 종류별 마지막 스캔 | 고르기, `전체 학생` 선택 | `ui/pages/scan_page.dart` `_ScanPageState`(세션 로직 → 컨트롤러 추출), 신규 `ScanTabPage`·`ScanKindTile`·`ScanRecentRow`·`LastScanBars` | FE8-g1 (FE8-f1 선행) | S1 준비 상태 3행·최근 스캔 4행·"게임 창 다시 선택" / 학생 2칸·아이템 6칸 타일이 80° 레일을 따라 밀림, 학생↔아이템 상호 배타 / 주 버튼 라벨이 선택 따라 바뀜 / 종류별 마지막 스캔 막대(경과일/14, FB-2 전에는 "—") |
| Scan-Items.dc.html | 스캔 · 고르기 — 아이템 2종 선택 (포그라운드) | 고르기, 아이템 2종 다중 선택 | 위와 같음, `InventoryScanProfile` | FE8-g1 | 아이템 다중 선택 표시·학생 선택 해제 / 주 버튼 "아이템 2종 스캔 시작 · 포그라운드" / S3 안내가 포그라운드 문구로 바뀜 / 선물 타일 유무(FD-151) |
| Scan-Student-Run.dc.html | 스캔 · 학생 전체 진행 중 — 백그라운드 · 머리글 진행 표시 · 다른 탭 사용 가능 | 학생 전체 진행 중 | `scan_page.dart`(학생 전체 `dockBeside` 호출 제거), `app_shell.dart` `_ConnectionBadge`(진행 칩), 신규 `ScanRunView`·`ScanHeaderProgressChip` | FE8-g2, FE8-f2 | 머리글 칩이 분홍 "학생 스캔 34 / 128"로 바뀌고 탭 `스캔`에 점 / 진행 수치·지금 읽는 학생·KPI 4·방금 읽은 학생 행 / "학생 탭으로 이동"으로 떠나도 진행 유지 / 일시정지 버튼(FB-10 전에는 숨김, FD-142) |
| Scan-Student-Review.dc.html | 스캔 · 학생 결과 검토 — 확인 필요 · 계산 일치 일괄 적용 · 새 학생 재검증 | 학생 결과 검토(S3 827px) | `scan_student_review_workspace.dart` `ScanStudentReviewWorkspace`(스캐너 세션 소유 — 마운트 해제만, 파일 유지), 학생 상세 인디케이터(FE3), 신규 `ScanStudentReviewBoard`·`ScanDiffRow` | FE8-g4 | 분류 버튼(전체/확인 필요/바뀐 학생/새 학생/그대로) 숫자 / "계산 일치 n명 한 번에 적용"(순차 commit, FD-144) / S3 학생 상세에 이전값 주석·폴백 카드(crop은 FB-10 뒤) / 새 학생은 재검증 먼저 |
| Scan-Item-Run.dc.html | 스캔 · 아이템 진행 중 — 게임 창이 앞으로 · 옆에 붙는 진행 창 (진행 / 일시정지 / 완료) | 게임 창 옆 진행 창 3상태 | `scan_companion_dock.dart` `ScanCompanionDock`(재작성, 동결 창 필요), `services/window_dock_service.dart` `dockBeside/restore` | FE8-g3 | 진행 창이 게임 창 옆 1:2로 붙음(FD-141) / 진행·일시정지·완료 세 상태 문구·버튼 / 여러 종류 큐 진행 표시(FD-143) / 완료 → 플래너 복원 + 결과 검토로 이동 |
| Scan-Item-Review.dc.html | 스캔 · 아이템 결과 검토 — 칸별 승인 · 읽지 못한 칸은 빗금 | 아이템 결과 검토 | `inventory_page.dart` `_CandidatePanel`(이관 후 제거), `scan_inventory_identity_review.dart` `ScanInventoryIdentityReview`(스캐너 세션 소유 — 그대로 마운트), 신규 `ScanItemReviewBoard`·`ItemCellTile` | FE8-g5, FE6-a(패널 제거) | 칸별 승인·읽지 못한 칸 빗금·확인 필요 칸 표시 / "확인 필요 n칸은 빼고 적용"(부분 적용, FD-146) / S3 검사기: 이전 확정값·n일 전 스캔·스테퍼 / 미식별 칸은 기존 identity 검토 그대로(FD-153) |

## 학생 (page `student`)

| artboard 파일 | 캔버스 제목 | 화면·상태 | 대상 Dart 파일·클래스 | slice | 검수 포인트 |
|---|---|---|---|---|---|
| Student.dc.html | 학생 — v7 원형 (student_section_layout 1:1 이식) | 그리드 보기, 리오(무장) 선택, 필터 3개 적용 | `ui/pages/student_page.dart` `StudentPage`, `ui/widgets/student_section_layout.dart` `StudentSectionLayout`·`StudentDiagonalGrid`·`StudentGridCardOverlayPainter`·`studentGridStatusBadgeRects`·`StudentBondStatus`·`_StudentStatusIndicators`, `ui/studio/student_studio_layout.dart` `studentStudioDocument`, `ui/widgets/student_grid_warmup.dart` | FE3-a(카드·그리드), FE3-b(인연), FE3-c(S4) | 카드 오른쪽 위 속성 글자 칩 2개(축약 라벨), 이름은 카드 밖 아래 줄(미보유 흐림) / 배지가 왼쪽 80° 변을 따라 채워 쌓임, 우상단 JP 없음 / 행 피치 ≈191, 8열 유지 / S4 결과 수·적용 필터 칩·최근 본 학생, S3 인연 게이지 목표 빗금 + 점선 + →N |
| Student-Filter.dc.html | 학생 · 필터 팝업 (속성 칩 + 성장 범위 슬라이더) | 필터 모달 열림, 일부 조건 좁힘 | `student_section_layout.dart` `StudentFilterDefinition`·`studentFilterDefinitions`·`studentMatchesCatalogFilters`, `ui/widgets/student_range_condition_section.dart` `StudentRangeConditions`(재구성), 폐기 `StudentDiagonalFilterList`·`StudentRangeConditionSection` | FE3-d | Section 5가 없고 스크림 .8 + blur 2 전체 모달 / 왼쪽 속성: 토글 칩(개수), 타입 칩 색 막대, "보유 · 서버" 그룹 / 오른쪽 성장 범위: 행마다 최소~최대, 좁힌 행만 분홍, 성급 9칸, 심상개화 비활성 자리 / "적용" 전에는 뒤 그리드가 바뀌지 않음, 헤더 결과 수는 미리보기 |
| Calc-Student.dc.html | 성장 계산기 · 학생 한 명 — 학생 정보 인디케이터 응용 · 목표값 → 인연 선물 · 크레딧 · 재화 필요량 (계획에 저장하지 않음) | 학생 탭 안의 계산기 모드(캔버스 page는 `plan`, 화면 기하·nav는 학생 탭과 같음, 진입점 FD-160) | `student_section_layout.dart`(S1~S4 기하·S3 인디케이터·인연 게이지), `plan_element_builder.dart` `_CompactTargetStepper`·`_MaxBadge`, `ui/models/planning_growth_rules.dart`, `AppService.calculatePlan`/`calculateShortages`, 신규 `GrowthCalculatorView`·`GoalStepperRow`·`BondGiftTile`·`GiftOptionPopover`. 근거 `survey/J-calc.md` | FE3-f, FE3-g(인연 타일), FE4-g(계획에 추가) | 목표 12행이 S2 왼쪽 변을 따라 계단, 바뀐 값 분홍 / S3 인디케이터가 목표값으로 그려지고 "현재 …" 분홍 태그 6개 / 크레딧 타일 합계(내역 막대는 FD-162) + 성장 재화 행 정렬 3종 / 인연 타일 3안과 선물 팝오버(FB-11 뒤) |

## 계획 만들기 (page `plan`)

| artboard 파일 | 캔버스 제목 | 화면·상태 | 대상 Dart 파일·클래스 | slice | 검수 포인트 |
|---|---|---|---|---|---|
| Flow-1-Students.dc.html | 계획 만들기 1 · 학생 고르기 | 여러 명 모드, 3명 선택 | `ui/widgets/plan_student_selector.dart` `PlanStudentSelector`, `student_section_layout.dart` `StudentDiagonalGrid`, `ui/widgets/plan_section_layout.dart` `_PlanSectionLayoutState` | FE4-a(레일·요약), FE4-b(본문·C) | A 레일 4단계 버튼 폭이 17px씩 줄고 상태(지금 분홍/완료/남음) 표시 / 요약 4행, "부족 재화" 플라이아웃(부족량·단계별 seg) / 카드에 선택 순서 번호 배지 / C "고른 학생" 목록형 행(× 빼기), 역할군 칩, 내 그룹(FD-074) |
| Flow-2-Goals.dc.html | 계획 만들기 2 · 목표 정하기 | 호시노 설정 중, 3단계 | `ui/widgets/plan_element_builder.dart` `PlanElementBuilder`·`_CompactTargetStepper`·`_MaxBadge`·`PlanPresetDiagonalList`, `ui/models/planning_models.dart` `PlanElementStageDraft` | FE4-c | 학생 탭 줄 상태 3종(설정 중/완료/미설정), 자유 이동 / "지금 상태"(읽기 전용) + 단계 카드 가로 열 + "단계 추가" 세로 버튼 / 카드 헤더 상태·비용, COST 블록 / 하단 "현재 → 최종" 줄, 프리셋 seg·C 패널(FD-072, FD-074) |
| Flow-3-Order.dc.html | 계획 만들기 3 · 단계 순서 | 단계 7개, 3칸 + 나중에, 호시노 2단계 선택 | `ui/widgets/plan_phase_editor.dart` `PlanPhaseEditor`·`PlanPhaseEditorItem`·`_sequenceOrderIsValid`, `ui/widgets/plan_student_step_tile.dart` `PlanStudentStepTile` | FE4-d(교차 선행·나중에는 FE4-f) | 칸이 80° 레일 따라 40px씩 왼쪽으로 / 같은 학생 단계는 회색 실선 화살표로 자동 연결, 직접 선행은 분홍 점선 / 선행보다 앞 칸 드롭 거부 / 카드 상태 가능·부족·막힘(FD-035), C 상세·자동 정렬 3종 |
| Flow-4-Save.dc.html | 계획 만들기 4 · 계획/시나리오로 저장 | 저장 직전, 시나리오로 저장 선택 | `plan_section_layout.dart` `_saveScenarioDraft`·`_incorporateScenario`, `services/scenario_service.dart` `createScenario`·`compareScenarios` | FE4-e | 페이즈 행 P1~P3, 행 hover 시 필요 재화 팝오버("앞 페이즈에서 쓰고 남은 양 기준") / 활성 계획 비교 타일(충족률·부족·크레딧·학생) / C 3지선다 + 이름 입력이 패널 안(다이얼로그 아님) / A primary와 C 버튼이 같은 동작(FD-079) |
| Flow-1-Students-Many.dc.html | 계획 만들기 1 · 학생 고르기 (많이 고른 경우 · 14명) | 여러 명 모드, 14명 | `plan_student_selector.dart` `PlanStudentSelector` | FE4-b | C가 압축 그리드(86×70, 번호·×)로 바뀜(FD-077) / 정렬 seg "고른 순서·이름·학교", 모두 비우기, 경고 줄 / 그리드 카드 확대(210×179) / A 요약 "—" 표기 |
| Flow-1-Students-Filter.dc.html | 계획 만들기 1 · 필터 팝업 (계획 칩 그룹 포함) | 공용 필터 모달 + 계획 그룹 | 공용 필터 모달(FE3-d) + `plan_student_selector.dart` 계획 필터(`ownership`, `plan_status`) | FE3-d(모달), FE4-b(계획 그룹 주입) | 학생 필터 팝업과 같은 배치에 "계획 · 계획 만들기 전용" 칩 3개 추가 / 헤더 "필터 24 / 170명" 미리보기, 적용 칩 / 프리셋(FD-074)·초기화·적용 |
| Flow-3-Order-Many.dc.html | 계획 만들기 3 · 단계 순서 (단계가 많은 경우 · 30개) | 단계 30개, 작게 보기 | `plan_phase_editor.dart` `PlanPhaseEditor` | FE4-d | 12개 초과면 작게(204×44 칩)로 자동, 크게·작게 seg로 되돌림 / 선택 카드만 398×150 확장, 그 카드에 이어진 선만 그리고 나머지 흐림 / 툴바(학생별 묶음·부족 있는 단계만·선택 중 ×) / 칸이 넘치면 줄바꿈 + 전체 스크롤 |
| Flow-1-Students-One.dc.html | 계획 만들기 1 · 학생 고르기 (한 명 · 학생 탭 인디케이터) | 한 명 모드 | `plan_student_selector.dart` `PlanStudentSelector`, `student_section_layout.dart` `_StudentStatusIndicators`·`StudentBondStatus` | FE4-b(게이지는 FE3-b) | B 폭 1595로 줄고 C가 짧은 사다리꼴로 / 학생 탭과 같은 자리에 상세 인디케이터 / "이미 잡혀 있는 목표" 행(활성 계획 문서, FB-1 전엔 빈 상태) / 인연 게이지 목표 빗금 |

## 시나리오 (page `scenario`, 앱에서는 계획 탭)

| artboard 파일 | 캔버스 제목 | 화면·상태 | 대상 Dart 파일·클래스 | slice | 검수 포인트 |
|---|---|---|---|---|---|
| Scenario-List.dc.html | 시나리오 · 목록 관리 (정렬·필터·비교 담기·미리보기) | 행 1개 선택(펼침), 비교 3/4 담음, 부족 팝오버 열림 | `plan_section_layout.dart` `PlanScenarioListSection`·`PlanScenarioListCard`·`_ScenarioStudentPortraits`·`PlanDiagonalScrollbar`·`planPhaseRowHorizontalOffset` | FE5-a(목록), FE5-b(미리보기) | 목록 맨 위 활성 계획 고정 행(파랑) / 정렬 seg 4·필터 칩·"오래된 시나리오 n개" / 선택 행 146px로 펼쳐져 행 액션, 체크 → S1 슬롯 A~D(A 고정) / 오른쪽 미리보기: 활성 대비 KPI, 학생·단계 차이 칩, 분야별 최대 부족, 부족 재화 팝오버 |
| Scenario-Detail-Bottleneck.dc.html | 시나리오 · 열어 보기 — 병목 (활성 계획 대비) | 보기 모드, 병목 탭, 병목 1 선택 | `plan_section_layout.dart` `_editScenarioFromComparison`(스냅샷 재사용)·`PlanBottleneckDiagonalList`·`PlanBottleneckDetailCard`·`PlanPrimaryBottleneckSummary`·`PlanResourceView`·`PlanResourceControls` | FE5-c | 3섹션(메뉴 400 / 페이즈 864 / 재화 1664) / S3 상단 한 줄에 seg + 칩 3, 요약 행, 활성 대비 KPI 4개(끝까지 가는 학생 포함) / 병목 카드에 같은 단계 재화 묶음 + 지연 단계 / 카드 선택 ↔ 왼쪽 단계 행 분홍 강조 |
| Scenario-Detail-Phase.dc.html | 시나리오 · 열어 보기 — 페이즈별 (활성 계획 대비) | 페이즈별 탭, P1 강조 | `plan_section_layout.dart` `PlanConsumptionCard`·`PlanConsumptionCreditRow`·`PlanInventoryCoverageBar`·`PlanPhaseResourceSummary` | FE5-d | 페이즈 카드 크레딧 진입/필요/종료(FD-037) / 재화 타일 진입·필요·종료 + 충족 막대 % + ± 칩 / 페이즈를 누르면 왼쪽 단계 강조 |
| Scenario-Detail-All.dc.html | 시나리오 · 열어 보기 — 전체 (활성 계획 대비) | 전체 탭, 한 행 4열 | `plan_section_layout.dart` `PlanConsumptionSection`·`_PlanDiagonalTwoColumnGrid`(일반화)·`PlanOverallResourceSummary` | FE5-d | "한 행에 2~5" 열 수 선택 / 분야별 그룹 행 + 크레딧 행 / delta 마크 = / ± / 신규(FD-038) / 요약 행 확보율 + "활성 72% → 81%" 칩(FD-031) |
| Scenario-Compare.dc.html | 시나리오 · 나란히 비교 (최대 4열 · 기준 대비) | 4열, 기준 A | `plan_section_layout.dart` `PlanScenarioComparisonSection`(2개 모드 유지)·`_ComparisonMetric`·`_ComparisonDelta`, 폐기 `_ComparisonCandidateDiagonalList` | FE5-e | 라벨 열 + 4열이 행 높이를 맞추고 함께 세로 스크롤 / 열 A 파랑 "비교 기준" / 보기 토글 3(차이만·최고 값 초록·± 표시) / 기준 라디오를 바꾸면 ±와 같음·다름 재계산 |

## 인벤토리 (page `inventory`)

| artboard 파일 | 캔버스 제목 | 화면·상태 | 대상 Dart 파일·클래스 | slice | 검수 포인트 |
|---|---|---|---|---|---|
| Inventory.dc.html | 인벤토리 · 부족 위험 + 상세 | 부족한 것 보기, 엘레프 선택 | `ui/pages/inventory_page.dart` `InventoryPage`·`_InventoryPageState`(로직 추출), `ui/models/planning_resource_assets.dart` `planningResourceIconAsset`, `services/app_service.dart` `calculateShortages`·`InventoryShortageRow` | FE6-a(KPI 증감·스파크라인은 FE6-f) | 4섹션 A/B/C/D, C·D가 사선으로 맞물림 / 사이드바 종류 버튼 폭이 8px씩 줄고 부족 개수 표기 / 위험도 순위 행(막대 폭 = 점수, FD-030) 선택 ↔ 오른쪽 상세 / 상세 kv·사용 학생·보충 방법·액션 3개 |
| Inventory-Analysis.dc.html | 인벤토리 · 분석 (학교별·오파츠·설계도·변화) | 분석 모드 기본 | 신규(집계는 `statistics/statistics_projection.dart` 참고) | FE6-c(최근 변화는 FE6-f) | 사이드바 최상단 "목록·분석" seg, 비교 기준 seg(이론상 전체는 비활성, FD-097) / 학교별 BD·노트 행 + "계획 n명" 플라이아웃 / 오파츠 산점도가 평행사변형 플롯 / 종류 × 티어 히트맵(80° 칸, 글자는 세움) + 부족 상위 행 |
| Inventory-Analysis-Opa.dc.html | 인벤토리 · 분석 — 오파츠 확장 (확장 버튼 → 다른 섹션 퇴장 → 오파츠 확대 · 선택 오파츠 상세) | 확장 완료 상태 | `plan_phase_editor.dart` `phaseEditorElements`·`_lerpGridRect` 패턴, `animated_section_stack.dart` `sectionMotionOffset` | FE6-d | "확장" → 다른 4섹션이 각 부착면으로 퇴장 → 오파츠 섹션이 (12,209,2548,1183)로 커짐 / 점이 오파츠 아이콘으로 바뀜 / 선택 오파츠 상세(티어별 보유/필요, 사용 학생, 병목 순위) / "축소"는 역순 |
| Inventory-All.dc.html | 인벤토리 · 전체 아이템 (종류별 타일) | 전체 183종, 기술 노트(최상급) 선택, 플라이아웃 1개 열림 | `ui/widgets/asset_image_grid.dart` `AssetImageGrid`, `inventory_page.dart` `_visible`(카탈로그 순서) | FE6-b | 그룹 헤더 + 74×74 타일, 그룹마다 21px 사선 이동 / 타일 막대 색: 부족 분홍·충분 파랑·과잉 노랑(FD-040)·미사용 없음, 스캔 없음 빗금 / "부족 n" 칩 hover → 상위 5 플라이아웃 / 오른쪽 상세 섹션 rect가 Inventory.dc와 같음 |
| Inventory-Tiers.dc.html | 인벤토리 · 티어별 충족률 (기술 노트 · BD · 오파츠) | 사이드바 "티어별 충족률" 선택 | 신규 | FE6-e | 노트·BD 학교 × 티어, 오파츠 종류 × 티어 히트맵 / T2가 중앙에 떠 있는 그대로(FD-019) / 표시 칩 충족률·보유량·부족량 전환 / 요약 KPI + 티어 분포 누적 막대 |

## 전술대항전 (page `pvp`)

| artboard 파일 | 캔버스 제목 | 화면·상태 | 대상 Dart 파일·클래스 | slice | 검수 포인트 |
|---|---|---|---|---|---|
| Tactical.dc.html | 전술대항전 · 기록 + 편성 + 로비 스캔 | 기록 1개 선택, 공격·승리·시도 1, 족보 D 드래그 중 | `ui/pages/tactical_page.dart` `TacticalPage`·`_TacticalPageState`(`_reload`, `_mutation`, `_matches`, `_candidates`, `_editMatch`, `_copyJokboToMatch` 재사용, `_DeckEditor` 폐기), `services/tactical_lobby_scanner_service.dart` `TacticalLobbyScannerService`, `app_shell.dart` `_handoffCandidate` | FE9-a(S1·S3), FE9-c(S2 로비), FE9-d(S4 족보) | 4섹션, 중앙이 위(로비)·아래(기록 작성)로 나뉨 / 기록 목록이 resize 모드 사선 스크롤(행 폭이 사선 추종) / 상대 덱 빗금 빈칸·출처 범례 칩, 시도 스테퍼 / 로비 카드 hover → 방어 덱 5종 플라이아웃, 족보를 끌면 "놓으면 … 복사" 힌트 |
| Tactical-Analysis.dc.html | 전술대항전 · 시그니처 · 족보 · 상대 카드 | 시그니처 1·족보 A·상대 B 열림 | 신규(`TacticalEvidenceService` `queryTacticalStatistics`·`queryTacticalRecommendations`·`queryTacticalTrends`) | FE9-e | 화면 이동 수단(FD-126) / S1 시그니처 행 선택 / S2 족보 seg + 공격 덱 + KPI 6 + 누적 돌파율 막대(FD-127 범위 밖 지표는 숨김) / S3 상대 카드 이력·변경 감지 |
| Tactical-Slots.dc.html | 전술대항전 · 슬롯 통계 · 궁합 · 카운터 | 슬롯 1 선택 | 신규 | FE9-g | 슬롯 클릭 → S2·S3 갱신 / 모집단(상위 500위) 통계는 데이터원 전까지 빈 상태 설명(FD-127) / 내 방어 기록 기반 카운터·유도 덱·덱 안정성 / 내 방어 덱 출처(FD-133) |
| Tactical-Import-Excel.dc.html | 전술대항전 · 엑셀 가져오기 → 해석 결과 승인 팝업 (열 연결 · 이해하지 못한 문자열 처리 · 미리보기) | 모든 문자열 처리됨, 승인 직전 | 신규(기존 `previewTacticalV6Import`·`commitTacticalV6Import` 2단계 패턴만 참고) | FE9-f | 직사각 모달(500,348,1560,880), 스크림 .62 / 요약 KPI 4, 열 연결 8개 + "열 바꾸기" / 문자열 처리표: 원문 하이라이트·처리 방법 드롭다운·"모두 적용" / 미리보기 분홍 줄, 체크 2개, "n건 가져오기" 건수 일치 |
| Tactical-Analysis-All.dc.html | 전술대항전 · 족보 전체 보기 팝업 (같은 방어 덱의 족보 7개 · 정렬 · 공격 기록에 복사) | 성공률 정렬, 족보 A 보는 중 | 신규(`AnchoredFlyout` + `BaModal` 스크림 .35) | FE9-e | "전체 보기 (7)" 버튼에 꼬리가 달린 940px 패널 / 정렬 seg 4 / 독립 재현 5명 미만 행 흐림, "표본 적음" 칩 / 행 클릭 → S2 족보가 바뀜, "공격 기록에 복사" |

## 통계 (page `stats`)

| artboard 파일 | 캔버스 제목 | 화면·상태 | 대상 Dart 파일·클래스 | slice | 검수 포인트 |
|---|---|---|---|---|---|
| Stats-Growth.dc.html | 통계 · 학생 성장 — KPI · A1 분포 · A2 항목 · A4 학교 · A6 추이 · A3 성작 · A5 매트릭스 (가운데 세로 스크롤 · 위젯별 비율 유지) + 구간 근거 | 필터 없음, 스냅샷 6회, A1 60~70% 선택 | `ui/pages/statistics_page.dart` `StatisticsPage`(`_reload` 재사용, `StatisticsMode`), `statistics/statistics_projection.dart` `buildStudentStatistics` | FE7-a(골격), FE7-b(K·A1·A2), FE7-f(A3·A4), FE7-h(A6), FE7-i(A5) | 3열(왼 586.7 / 가운데 1701.9 / 오른 640) / 가운데를 스크롤하면 콘텐츠가 사선 따라 가로로 밀림(translate 모드) + 위·아래 포그 / 차트는 viewBox × 1.25 균일 배율, 비율 유지 / A1 구간 선택 → 오른쪽 학생 목록 + 하단 이동 버튼 2개 |
| Stats-Inventory.dc.html | 통계 · 인벤토리 현황 — B1 충족률 · B2 부족/과잉 · B3 재화 변화 (위젯별 비율 유지) + 선택 재화 근거 | B2 행(기술 노트 최상급) 선택 | `statistics_projection.dart` `buildPlanStatistics`(재화별 충족률로 교체)·`buildInventoryStatistics`(스캔 없음 판정), `InventoryShortageRow` | FE7-c(B1·KPI), FE7-f(B2), FE7-h(B3) | 왼쪽 필터 "인벤토리 · 계획 집계는 항상 전체" / KPI 5 / B1 공통 트랙 + 60% 기준선 + 스캔 없음 빗금 / 오른쪽 쓰는 학생 필요량 순 |
| Stats-Plan.dc.html | 통계 · 계획 집계 — C1 필요량 · C2 병목 · C3 누적 부족 · C4 목표 진행 · C5 미계획 (가운데 세로 스크롤) + 병목 근거 | C2 병목 선택 | `statistics_projection.dart` `buildPlanStatistics`, `PlanningDocumentService.calculatePlanningDocument` | FE7-c(C1·C2), FE7-f(C4), FE7-g(C3), FE7-i(C5) | 헤더 칩 "활성 계획 · n명 · 페이즈 n" / C1 불릿(행마다 자기 단위, 부족분 빗금) / C2 산점도 왼쪽 위 구역만 분홍 / C3 계단선 "첫 부족 · Pn", 하단 이동 버튼 목적지(FD-108) |
| Stats-Growth-Filter.dc.html | 통계 · 학생 성장 — 통계 필터 적용(밀레니엄 · 스트라이커) · 스냅샷 1회 (A4 비교 불가 · A6 빈 상태) | 통계 필터 적용, 스냅샷 1회 | `StatisticsPage` | FE7-e(빈 상태 문구는 FE7-h) | 왼쪽 필터 버튼 "필터 · 2 · 31 / 128명" 분홍 + 칩 / KPI 첫 타일 "대상 학생 31 / 128", 증감은 "—" / A4 빈 상태 문구, A6 "스캔을 더 실행하면 변화가 나타납니다." / 빈 카드는 낮아짐(FD-109) |
| Stats-Filter-Open.dc.html | 통계 · 통계 전용 필터 팝업 (학생 탭과 같은 필터 · 학생 성장에만 적용 · 학생 탭 필터 불러오기) | 팝업 열림, 적용 전 | 공용 필터 모달(FE3-d) | FE7-e | 학생 필터와 같은 배치 + "학생 탭 필터 불러오기" / 헤더 "학생 성장(A)에만 적용 · 학생 탭 필터와 따로 저장"(FD-104) / 적용 전에는 배경 왼쪽 버튼이 "필터 없음" 그대로 |

## 요소 · 위젯 (page `parts`)

| artboard 파일 | 캔버스 제목 | 화면·상태 | 대상 Dart 파일·클래스 | slice | 검수 포인트 |
|---|---|---|---|---|---|
| UI-Elements.dc.html | UI 요소 사전 (v7 수치) | 정적 카탈로그(블록 8개) | `ui/widgets/diagonal_media_list_item.dart` `DiagonalMediaListItem`, `plan_section_layout.dart` `PlanPhaseCard`·`PlanDiagonalScrollbar`·`PlanScenarioListCard`, `ui/widgets/diagonal_flow_indicator.dart` `DiagonalFlowIndicator`, `scroll_viewport_fog.dart` `ScrollViewportFog`, `ui/studio/section_template_surface.dart` `buildAttachedSectionPolygon`, `lifted_path_shadow.dart` `paintLiftedPathShadow`, `animated_section_stack.dart` | FE1(표면·토큰·기하·모션), FE2-a(행·스크롤), FE2-b(스테퍼·MAX 배지) | 섹션 표면 .76 무블러 + lifted shadow 4층(FD-006) / 배치 규칙 수치(S1·S2 간격 24, S2·S6 20, 섹션 inset 10, 리스트 inset 8, 스크롤바 reserve 14) / 모션 360ms·970ms 시퀀스 / 기존 위젯(mrow·페이즈 카드·재화 타일·시나리오 카드) 수치 회귀 없음 |
| W-Card-Variants.dc.html | 학생 카드 · 속성/이름 표현 대안 | 6안 비교(v7 현재/A~E) | `student_section_layout.dart` `StudentGridCardOverlayPainter` | FE3-a | 구현 대상은 D(글자 칩) + E(이름 밖)뿐, A·B·C와 E의 2색 밑줄은 없음(FD-043) / 칩이 왼쪽 위 배지와 겹치지 않음 / 같은 카드 크기·초상 비율 |
| W-Card-States.dc.html | 학생 카드 · 상태별 | 상태 6종 | `student_section_layout.dart` `studentGridCardSelectionColor`, `ui/widgets/student_portrait_status_overlay.dart` `paintStudentPortraitStatusBadge`, `ui/widgets/bond_rank_portrait.dart` `bondRankPortraitBackgroundAsset` | FE3-a(폼 교대는 FE3-e) | 선택 #ff72b6 2% + 흰 외곽선 1% / UNOWNED + PLAN 세로 스택, 3배지 스택 / 인연 20/50/100 배경 구간 / 폼 2개 3초 교대 |
| W-Card-Grid-DE.dc.html | 학생 그리드 · 글자 칩 + 이름 카드 밖 | 7열 미리보기 | `student_section_layout.dart` `StudentDiagonalGrid` | FE3-a | 행 피치 = 카드 + 이름 줄, 행 x 이동 = 피치/tan80 / 이름 줄 폭 = 카드 하단 변 길이 / 실제 학생 탭은 8열(7열은 보드 폭 탓) |
| W-Student-Detail.dc.html | 학생 상세 (S3 · 인디케이터) | 리오(무장), 인연 20 → 목표 30 | `student_section_layout.dart` `_StudentStatusIndicators`·`StudentBondStatus`·`_StudentTriangleBondGaugePainter` | FE3-b | 인디케이터 텍스트·배치가 v7과 같음 / 인연 게이지: 현재 진하게 + 목표까지 빗금 + 목표 높이 점선 + "→30" / 목표가 없으면 빗금·→ 숨김(FD-050) |
| W-Student-Search.dc.html | 학생 검색 (S4) | 토글 4 + 결과 수 + 적용 필터 + 최근 본 학생 | `student_section_layout.dart` `_StudentGridDisplayToggle`, 검색 `TextField('student-search')` | FE3-c | "표시 48 / 전체 170 · 보유 128 · 계획 중 8" 줄 / 적용 필터 칩 ×와 "모두 지우기" / 최근 본 학생 6개(FD-061) / 줄 시작 x가 80° 레일 따라 감소 |
| W-Student-Actions.dc.html | 학생 액션 (S1) | 그리드 보기, 정렬 LV↓ | `student_section_layout.dart` `_StudentViewModeButtons`·`_StudentSortDropdown`·`_StudentActionButton` | FE3-d(필터 진입 변경 확인용, 그 밖 변경 없음) | 버튼 6개 rect·aria-label이 현행과 같음 / 필터 버튼이 Section 5 대신 모달을 엶 / 적용 개수 배지 위치(FD-058) / 기본 정렬은 이름↑ 유지(FD-062) |
| W-Info-Popover.dc.html | 도움말 (i) · 팝오버 | 닫힘 / 열림 왼쪽 정렬 / 열림 오른쪽 정렬 | 신규 `InfoPopover`(현재는 `Tooltip`만) | FE2-c | 24px 원 버튼이 hover·focus·클릭으로 열림 / 330px #0d151f 패널 + 꼬리, 섹션 안에서 왼쪽·오른쪽 정렬 / 제목 앞 분홍 막대, 강조어 분홍 / `role="tooltip"`·aria-label |
| W-Bond-Variants.dc.html | 인연도 표현 대안 (S3 삼각형 자리) · B 채택 | 5안 비교, B 채택 표시 | `student_section_layout.dart` `StudentBondStatus`·`_StudentTriangleBondGaugePainter` | FE3-b | B안만 구현(A·C·D 없음) / 채움은 rank/100 그대로(FD-051) / 숫자 크기 43.2px 동일 / 계획 화면 inverted 모드도 같은 표현 |
| W-Data-Widgets.dc.html | 위젯 · 데이터 표시 | 견본 11개 | 신규 `KpiTile`·`ResourceAmountRow`·`ItemTile`+막대·`RatioBarRows`·`SkewHistogram`·`LineTrend`·`DivergingBars`·`SkewHeatmap`·`RiskRow`·`ShortageTopRow`·`ShortageChipFlyout`, `PlanInventoryCoverageBar` 흡수 | FE2-d(위험도·부족 상위 행은 FE2-a `DiagonalRow` 위) | 막대·타일·트랙이 모두 −10° / 비율 막대 행이 행째로 80° 레일 따라 밀림 / 히트맵 칸은 기울고 글자는 세움 / KPI 증감 색(증가 초록, 계획 분홍) |
| W-Layout-Widgets.dc.html | 위젯 · 구조와 상호작용 | 견본 + 팝오버 열린 상태 | 신규 `PanelTitle`·`TileTitle`·`SubHeader`·`BaChip`·`SkewSegmented`·`StageTag`·`NudgeButtons`·`AnchoredFlyout`, 사선 목록은 `planPhaseRowWidth`·`studentDiagonalRowHorizontalOffset`·`portraitGridTrajectoryOffset` 공용화 | FE2-a(사다리꼴 안 스크롤), FE2-b(제목·칩·seg·단계 태그·변경 강조), FE2-c(플라이아웃·페이즈 팝오버) | 제목 3단계(패널·타일·소제목) / 칩 6색 역할 고정, seg on = 분홍 테두리 / 사다리꼴 안 스크롤에서 행 폭이 레일 추종(resize 모드), 썸이 레일 따라 이동, 포그 페이드 / 팝오버 꼬리·그림자·폭 |
| W-Filter-Widgets.dc.html | 위젯 · 필터 | 견본 6개 | 신규 `SkewToggleChip`·`TypeChip`·`FilterButton`·`RangeSliderRow`·`StarRangeBar`, `_StarIndicator`(표시 재사용) | FE2-b(토글·타입 칩·필터 버튼), FE3-d(범위 슬라이더·성급 범위) | 토글 칩 off/on/개수 / 타입 칩 색 막대 5색(복합 #7a8ea3, FD-024), 이름 항상 표시 / 범위 행 기본 vs 좁힌 행 분홍 / 성급 9칸(학생★5 노랑 + 무기★4 파랑) |
| Statistics-Proposal.dc.html | 통계 · 기능 제안 + 그래프 매핑 (질문 → 그래프 · 1/2/3차 · 확정 사항) | 문서형 보드(2560×3054) | `statistics_page.dart`, `statistics_projection.dart`(기준 문서) | FE7(FE7-a 기준, 차트 견본은 FE2-d) | 확정 사항 4개 반영 여부(범위는 FD-104로 갱신, 1차 목록, C3 계단선, 스냅샷 1회 문구) / 색 역할(크기 파랑, 강조 분홍, 모름 빗금, 과잉 노랑) / 원·도넛·이중 축 없음(FD-033) / 이동한 탭 머리글의 "← 통계" 칩(FD-108) |

---

## 첫 실행 · 안내 (page `firstrun`, 2026-10-20 추가 — 사본 `prototype/2026-10-20/`)

- 출처: 캔버스 version `1792494343-3aed`(F1 2차). 결정: FD-181(그림은 설치본에서) · FD-182(튜토리얼 = 임시 계정 시나리오) · FD-183(프라나 대사 · 움직이는 그림). 흐름 순서는 캔버스 메모 frFlow1~9(첫 실행 ①~③ → 프라나 01 → … → 프라나 11 → 끝, 그만두기 갈래).
- slice 칸: F3a 튜토리얼 부품(새 파일) · F3b 첫 실행 ①~③ · F3c 튜토리얼 흐름(임시 계정 · 단계 진행) · F3d 빈 상태 · F3e 설정 줄 · F3f 프라나 움직이는 그림 · F4 스캔 신고 · F5 그림 출처. Dart 칸은 구현 때 채운다.

| artboard 파일 | 캔버스 제목 | slice | Dart |
|---|---|---|---|
| Empty-Backend.dc.html | 빈 상태 · 계산 엔진 연결 전 — 머리글 칩 빨강 · 본문 반투명 막 + 안내 패널 · 다시 연결 | F3d | 신규 |
| Empty-Inventory.dc.html | 빈 상태 · 인벤토리 (0개) — 스캔하러 가기 | F3d | 신규 |
| Empty-Plan.dc.html | 빈 상태 · 계획 탭 (계획 0개) — 예시 한 줄 · 계획 만들기 | F3d | 신규 |
| Empty-Scan.dc.html | 빈 상태 · 스캔 탭 (스캔 0회) — 창 모드 안내 · 창 인식 상태 · 창 찾기 → 스캔 시작 | F3d | 신규 |
| Empty-Stats.dc.html | 빈 상태 · 통계 (이력 0) — 버튼 없음 | F3d | 신규 |
| Empty-Student.dc.html | 빈 상태 · 학생 탭 (확정 0명) — 스캔하러 가기 · 직접 입력(비활성) | F3d | 신규 |
| Empty-Tactical.dc.html | 빈 상태 · 전술대항전 (기록 0) — 기록하기 | F3d | 신규 |
| FirstRun-1-Game.dc.html | 첫 실행 · ① 게임 설치 찾기 — 자동으로 찾음 / 못 찾았을 때 (타이틀 위 모달 · 건너뛰기 언제나) | F3b (+F2) | 신규 |
| FirstRun-2-Images.dc.html | 첫 실행 · ② 이미지 준비 — 준비 중 / 일부 실패 / 게임 업데이트 뒤 ②만 다시 | F3b (+F2) | 신규 |
| FirstRun-3-Account.dc.html | 첫 실행 · ③ 계정 만들기 — 이름 입력 · 만들고 튜토리얼 시작 (연습 계정 줄 없음 · v6 가져오기 없음) | F3b (+F2) | 신규 |
| Scan-Report-Band.dc.html | 스캔 신고 · 검토 화면 위 띠 (막지 않음) — 신고하기 · 닫기 · 머리 쪽 상시 '스캔 문제 신고' 버튼 | F4 | 신규 |
| Scan-Report-Dialog.dc.html | 스캔 신고 · 신고 창 — 요약 · 그림 조각 포함(기본 켜짐) · 한 줄 입력 · 들어가는 것 / 안 들어가는 것 → 만든 뒤 폴더 열기 · GitHub 새 글 | F4 | 신규 |
| Settings-Help.dc.html | 첫 실행 · 설정 탭에 들어갈 줄 자리 (선택) — 안내 다시 열기 · 그림 다시 준비 · 튜토리얼 다시 하기 · 스캔 신고 · 도움말 · 자동 업데이트 | F3e | 신규 |
| Tutorial-01-Connect.dc.html | 튜토리얼 · 1/10 가상 게임 창에 연결 — Home-Connect-Pick 사본 · 맨 위 줄 '가상 게임 창 · 튜토리얼' · 강조: 선택한 창 사용 | F3c | 신규 |
| Tutorial-02-StudentScan.dc.html | 튜토리얼 · 2/10 학생 가상 스캔 — Scan 사본 · 하위 체크(탭 → 학생 전체 → 시작) · 강조: 학생 전체 스캔 시작 | F3c | 신규 |
| Tutorial-03-StudentApply.dc.html | 튜토리얼 · 3/10 학생 결과 적용 — Scan-Student-Review 사본 · 지난 스캔 1회분 대비 바뀐 6 · 새 1 · 강조: 6명 한 번에 적용 | F3c | 신규 |
| Tutorial-04-StudentCalc.dc.html | 튜토리얼 · 4/10 학생 상세 · 성장 계산기 — Calc-Student 사본 · 하위 체크 4개 · 강조: 레벨 목표 + · 카드는 결과를 가리지 않는 빈자리 | F3c | 신규 |
| Tutorial-05-ItemScan.dc.html | 튜토리얼 · 5/10 아이템 가상 스캔 — Scan-Item-Run 사본 · 플래너가 뒤로 가므로 단계 카드 대신 진행 창 안 한 줄 | F3c | 신규 |
| Tutorial-06-ItemApply.dc.html | 튜토리얼 · 6/10 아이템 결과 적용 — Scan-Item-Review 사본 · 하위 체크(확인 필요 승인 → 적용) · 강조: 승인한 56칸 인벤토리에 적용 | F3c | 신규 |
| Tutorial-07-Plan.dc.html | 튜토리얼 · 7-2/10 계획 · 목표 정하기 — 학생마다 한 단계 · 강조: 고른 7명 모두 한 번에 MAX로 | F3c | 신규 |
| Tutorial-07a-PlanStudents.dc.html | 튜토리얼 · 7-1/10 계획 · 학생 고르기 — 비나 대비 7명(아카네 · 칸나(수영복) · 마키 · 미카 · 히마리(무장) · 시로코(수영복) · 네루(교복)) · 강조: 다음 · 목표 정하기 | F3c | 신규 |
| Tutorial-07b2-PlanMaki1.dc.html | 튜토리얼 · 7-2b/10 계획 · 마키 1단계 — 마키 탭 · 한 번에 MAX로 들어간 1단계를 M/M/1/1로 · 강조: 1단계 스킬 칸 | F3c | 신규 |
| Tutorial-07b3-PlanMaki2.dc.html | 튜토리얼 · 7-2c/10 계획 · 마키 2단계 — 1단계 M/M/1/1 · 단계 추가로 2단계 M/M/7/7 · 강조: 단계 추가 | F3c | 신규 |
| Tutorial-07c-PlanOrder.dc.html | 튜토리얼 · 7-3/10 계획 · 순서 놓기 — 고른 순서대로 놓인 상태 · 1순위 칸나(수영복) · 마키 · 미카 / 2순위 시로코(수영복) · 히마리(무장) / 3순위 아카네로 · 강조: 아카네 카드 | F3c | 신규 |
| Tutorial-07c2-PlanLink.dc.html | 튜토리얼 · 7-4/10 계획 · 칸나 다음 아카네 — 칸나(수영복) 아래 점 → 아카네로 잇기(선행 조건) · 강조: 칸나(수영복) 카드 | F3c | 신규 |
| Tutorial-07c3-PlanLater.dc.html | 튜토리얼 · 7-5/10 계획 · 나중에 — 네루(교복) · 마키 2단계를 나중에 칸으로(페이즈 아님) · 강조: 나중에 칸 | F3c | 신규 |
| Tutorial-07d-PlanSave.dc.html | 튜토리얼 · 7-6/10 계획 · 저장 — P1 칸나(수영복) · 마키 1단계 · 미카 / P2 시로코(수영복) · 히마리(무장) / P3 아카네(칸나 다음) / 나중에 네루(교복) · 마키 2단계 · 강조: 시나리오로 저장 | F3c | 신규 |
| Tutorial-08-Scenario.dc.html | 튜토리얼 · 8/10 시나리오 비교 — 시나리오 목록(비나 대비 · 예시 · 튜토리얼 바탕) · 비교에 A 활성 · B 비나 대비 · C 한 번에 MAX · 강조: 나란히 비교 | F3c | 신규 |
| Tutorial-09-Inventory.dc.html | 튜토리얼 · 9/10 부족한 재화 확인 — Inventory 사본 · 강조: 맨 위 행 · 카드는 상세 자리를 피해 목록 아래 | F3c | 신규 |
| Tutorial-10-Stats.dc.html | 튜토리얼 · 10/10 통계에서 변화 확인 — Stats-Growth 사본 · 강조: 성장 추이 타일 | F3c | 신규 |
| Tutorial-Done.dc.html | 튜토리얼 · 끝 — 써 본 기능 10개 · 실제 게임 창 모드 안내 · '메인 계정'으로 돌아가기 (임시 계정 삭제) | F3c | 신규 |
| Tutorial-Plana-01-Intro.dc.html | 튜토리얼 · 프라나 01 시작 — ③ 계정을 만든 직후 · 타이틀 위 · 아로나 선배 과로 → 따로 마련한 프로세스 → 가상 공간 (대사 3 / 5) | F3c | 신규 |
| Tutorial-Plana-02-Connect.dc.html | 튜토리얼 · 프라나 02 연결 — 프라나 01 뒤 · 1단계 전 · 홈 연결 패널 · 가상 게임 창 고르기 (대사 2 / 2) | F3c | 신규 |
| Tutorial-Plana-03-StudentScan.dc.html | 튜토리얼 · 프라나 03 학생 스캔 — 1단계 뒤 · 2단계 전 · 스캔 탭 · 게임 창을 뒤에 둔 채 학생 스캔 (대사 2 / 2) | F3c | 신규 |
| Tutorial-Plana-04-StudentReview.dc.html | 튜토리얼 · 프라나 04 학생 검토 — 2단계 뒤 · 3단계 전 · 바뀐 6 · 새 1 · '확인 필요' 2명을 밝힘 (대사 2 / 5) | F3c | 신규 |
| Tutorial-Plana-04b-Uncertain.dc.html | 튜토리얼 · 프라나 04b 학생 검토 · 확인 필요 — 같은 장면 대사 4 / 5 · 폴백 캡처와 확정할 값을 밝힘(대사 띠는 왼쪽까지만) | F3c | 신규 |
| Tutorial-Plana-05-StudentCalc.dc.html | 튜토리얼 · 프라나 05 학생 계산 — 3단계 뒤 · 4단계 전 · 학생 탭 · 학생 한 명 · 목표 → 필요량 (대사 2 / 2) | F3c | 신규 |
| Tutorial-Plana-06-ItemScan.dc.html | 튜토리얼 · 프라나 06 아이템 스캔 — 4단계 뒤 · 5단계 전 · 스캔 탭 · 게임 창이 앞으로 · 입력하면 멈춤 (대사 1 / 2) | F3c | 신규 |
| Tutorial-Plana-07-ItemReview.dc.html | 튜토리얼 · 프라나 07 아이템 검토 — 5단계 뒤 · 6단계 전 · 아이템 결과 검토 · 칸별 비교 · 승인한 칸만 (대사 2 / 2) | F3c | 신규 |
| Tutorial-Plana-08-Plan.dc.html | 튜토리얼 · 프라나 08 계획 — 6단계 뒤 · 총력전 비나 대비 · 계획은 네 단계 · 왼쪽 단계 목록을 밝힘 (대사 3 / 4) | F3c | 신규 |
| Tutorial-Plana-08b-PlanStudents.dc.html | 튜토리얼 · 프라나 08b 계획 · 학생 — 같은 장면 대사 4 / 4 · 비나전에 쓸 7명 · 고른 학생을 밝힘 | F3c | 신규 |
| Tutorial-Plana-08c-Goals.dc.html | 튜토리얼 · 프라나 08c 계획 · 목표 — 7-1 뒤 · 이번에는 학생마다 한 단계 · 단계 칸을 밝힘 (대사 2 / 3) | F3c | 신규 |
| Tutorial-Plana-08d-Order.dc.html | 튜토리얼 · 프라나 08d 계획 · 순서 — 7-2 뒤 · 칸 하나 = 페이즈 하나 · 1순위 칸나(수영복) · 마키 · 미카, 2순위 시로코(수영복) · 히마리(무장), 3순위 아카네 (대사 1 / 3) | F3c | 신규 |
| Tutorial-Plana-08e-Link.dc.html | 튜토리얼 · 프라나 08e 계획 · 잇기 — 7-3 뒤 · 아카네는 칸나(수영복)의 대체 학생 · 상위 난이도용 → 칸나 다음에 키우도록 잇기 · 두 카드를 밝힘 (대사 1 / 3) | F3c | 신규 |
| Tutorial-Plana-08f-Later.dc.html | 튜토리얼 · 프라나 08f 계획 · 나중에 — 7-4 뒤 · 네루(교복) · 마키 2단계는 나중에 칸으로 · 대사 띠는 오른쪽에서 (대사 2 / 3) | F3c | 신규 |
| Tutorial-Plana-08g-Maki.dc.html | 튜토리얼 · 프라나 08g 계획 · 마키 — 7-2 뒤 · 마키만 두 단계: 이번엔 M/M/1/1, 나중에 M/M/7/7 · 1단계 스킬 칸을 밝힘 (대사 2 / 3) | F3c | 신규 |
| Tutorial-Plana-09-Scenario.dc.html | 튜토리얼 · 프라나 09 계획 · 저장 — 7-5 뒤 · 순위 칸 → 페이즈 · 나중에 칸은 페이즈 아님 · 페이즈를 밝힘 (대사 1 / 3) | F3c | 신규 |
| Tutorial-Plana-09b-Save.dc.html | 튜토리얼 · 프라나 09b 계획 · 저장 — 같은 장면 대사 2 / 3 · 활성 계획과 시나리오의 차이 · 저장 선택을 밝힘 | F3c | 신규 |
| Tutorial-Plana-09c-Example.dc.html | 튜토리얼 · 프라나 09c 비교 · 예시 — 7-6 뒤 · 시나리오 목록 · 비교용 예시 '비나 대비 · 한 번에 MAX'를 미리 넣어 둠 · 두 안을 밝힘 (대사 1 / 3) | F3c | 신규 |
| Tutorial-Plana-09d-Compare.dc.html | 튜토리얼 · 프라나 09d 비교 — 8단계 뒤 · 나란히 비교 A 활성 / B 비나 대비 / C 한 번에 MAX · 크레딧 −32M · 첫 병목 P1 → P2 · B · C 숫자를 밝힘 (대사 2 / 3) | F3c | 신규 |
| Tutorial-Plana-10-Check.dc.html | 튜토리얼 · 프라나 10 확인 — 8단계 뒤 · 9단계 전 · 인벤토리 · 부족한 것 · 늘어난 것 (대사 2 / 2) | F3c | 신규 |
| Tutorial-Plana-11-End.dc.html | 튜토리얼 · 프라나 11 끝 — 10단계 뒤 · 끝 화면 전 · 통계 · 가상 공간 정리 → '앞으로도 잘 부탁드립니다' (대사 3 / 3) | F3c | 신규 |
| Tutorial-Plana-Quit.dc.html | 튜토리얼 · 프라나 그만둘 때 — 그만두기 확인에서 '그만두기'를 누른 뒤 · 어느 단계에서든 · 가상 공간 정리 · 설정에서 다시 (대사 2 / 2) | F3c | 신규 |
| Tutorial-Plana-Script.dc.html | 튜토리얼 · 프라나 대본 — 장면 18개 + 그만둘 때 · 계획은 총력전 비나 대비(마키 두 단계 · 예시 시나리오와 비교) · 대사마다 표정 | F3a (대본 데이터) | 신규 |
| Tutorial-Quit.dc.html | 튜토리얼 · 그만두기 확인 — 임시 계정을 지우고 '메인 계정'으로 · 계속하기가 기본 버튼 | F3c | 신규 |
| W-Missing-Art.dc.html | 빈 상태 · 그림이 없을 때 (부품) — 준비 중(흐르는 사선) / 만들지 못함(멈춘 빗금) · 카드 · 초상 · 아이템 · 엘레프 · 로고 · 장비 | F5a/F5b | 신규 |
| W-Plana-Dialogue.dc.html | 튜토리얼 · 프라나 대사 띠 (부품) — 어둡게 · 이름표 · 대사 두 줄 · 한 글자씩 · 그림 없을 때 · 밝히기 · ⑤ 메모: 게임 설치본의 움직이는 그림을 꺼내 대사마다 표정 바꾸기 | F3a (+F3f 움직임) | 신규 |
| W-Tutorial-Card.dc.html | 튜토리얼 · 단계 카드 · 강조 테두리 (부품) — 진행 / 하위 체크 / 기다림 / 완료 체크 · #71c7f4 2.5px · 머리글 칩 · 카드 자리 규칙 | F3a (+F3f 움직임) | 신규 |

## slice → artboard 역색인

| slice | artboard |
|---|---|
| FE0 | 없음(사본 반입·결정 대장) |
| FE1 | UI-Elements |
| FE2-a | UI-Elements, W-Layout-Widgets, W-Data-Widgets(행 프리셋) |
| FE2-b | UI-Elements, W-Layout-Widgets, W-Filter-Widgets |
| FE2-c | W-Info-Popover, W-Layout-Widgets |
| FE2-d | W-Data-Widgets, Statistics-Proposal |
| FE3-a | Student, W-Card-Variants, W-Card-States, W-Card-Grid-DE |
| FE3-b | Student, W-Student-Detail, W-Bond-Variants, Flow-1-Students-One(inverted 게이지) |
| FE3-c | Student, W-Student-Search |
| FE3-d | Student-Filter, Flow-1-Students-Filter, W-Filter-Widgets, W-Student-Actions |
| FE3-e | W-Card-States |
| FE3-f | Calc-Student(인연 타일 제외) |
| FE3-g | Calc-Student(인연 타일·선물 팝오버) |
| FB-1 | 없음(Flow-4-Save, Flow-1-Students-One, Scenario-List가 사용) |
| FE4-a | Flow-1-Students(A 레일·요약) |
| FE4-b | Flow-1-Students, Flow-1-Students-Many, Flow-1-Students-One, Flow-1-Students-Filter(계획 그룹) |
| FE4-c | Flow-2-Goals |
| FE4-d | Flow-3-Order, Flow-3-Order-Many |
| FE4-e | Flow-4-Save |
| FE4-f | Flow-3-Order(직접 선행·나중에 칸 부분) |
| FE4-g | Calc-Student("이 목표로 계획에 추가") |
| FE5-a | Scenario-List |
| FE5-b | Scenario-List(미리보기·부족 팝오버) |
| FE5-c | Scenario-Detail-Bottleneck |
| FE5-d | Scenario-Detail-Phase, Scenario-Detail-All |
| FE5-e | Scenario-Compare |
| FE5-f | 없음(옛 계획 메인 정리) |
| FB-2 / FB-3 | 없음(Inventory, Inventory-All, Inventory-Analysis, Inventory-Tiers, Stats-*, Title-Accounts가 사용) |
| FE6-a | Inventory |
| FE6-b | Inventory-All |
| FE6-c | Inventory-Analysis |
| FE6-d | Inventory-Analysis-Opa |
| FE6-e | Inventory-Tiers |
| FE6-f | Inventory(KPI 증감·스파크라인), Inventory-All(최근 변화), Inventory-Analysis(최근 변화) |
| FE7-a | Stats-Growth, Stats-Inventory, Stats-Plan(골격), Statistics-Proposal |
| FE7-b | Stats-Growth(K·A1·A2) |
| FE7-c | Stats-Inventory(B1), Stats-Plan(C1·C2) |
| FE7-d | Stats-Growth·Stats-Inventory·Stats-Plan 하단 이동 버튼, Statistics-Proposal(D) |
| FE7-e | Stats-Filter-Open, Stats-Growth-Filter |
| FE7-f | Stats-Growth(A3·A4), Stats-Inventory(B2), Stats-Plan(C4) |
| FE7-g | Stats-Plan(C3) |
| FE7-h | Stats-Growth(A6), Stats-Inventory(B3), Stats-Growth-Filter(빈 상태) |
| FE7-i | Stats-Growth(A5), Stats-Plan(C5) |
| FB-4 | 없음(Home-Connect-Pick, Home-Connected-Scan이 사용) |
| FE8-a | Title |
| FE8-b | Title-Accounts, Title-Accounts-New |
| FE8-c | Title-Accounts(편집기), Title-Accounts-Portrait |
| FE8-d | Home-Connect-Pick(헤더 칩), Home-Connect-Effect(칩 전환) |
| FE8-e | Home-Connect-Pick, Home-Connect-Effect |
| FE8-f1 | 없음(동작 보존 추출, Scan-*가 사용) |
| FE8-f2 | Scan-Student-Run(머리글 진행 칩·탭 점) |
| FE8-f3 | Home-Connected-Scan |
| FE8-g1 | Scan, Scan-Items |
| FE8-g2 | Scan-Student-Run |
| FE8-g3 | Scan-Item-Run |
| FE8-g4 | Scan-Student-Review |
| FE8-g5 | Scan-Item-Review |
| FB-10 | 없음(Scan-Student-Run·Scan-Item-Run 일시정지, Scan-Student-Review 폴백 crop, Scan-Item-Review 칸별 승인이 사용) |
| FB-11 | 없음(Calc-Student 크레딧 내역·인연 선물이 사용) |
| FB-5 | 없음(W-Card-States가 사용) |
| FB-6 / FB-7 / FB-8 / FB-9 | 없음(각각 Tactical·Tactical-Analysis / Tactical-Import-Excel / Flow-3-Order / Scenario-* 가 사용) |
| FE9-a | Tactical(S1 기록 목록, S3 기록 작성) |
| FE9-b | 없음(데이터 계층) |
| FE9-c | Tactical(S2 로비 스캔) |
| FE9-d | Tactical(S4 이 시그니처의 족보) |
| FE9-e | Tactical-Analysis, Tactical-Analysis-All |
| FE9-f | Tactical-Import-Excel |
| FE9-g | Tactical-Slots |
| FE10 | 전체 57개 최종 둘러보기 |
