---
title: "Frontend Redesign Orchestrator Log"
summary: "프론트 개편(시안 구현) 워크플로의 오케스트레이터 결정과 검토 기록입니다."
topics: [workflow, design]
---

# Frontend Redesign — 오케스트레이터 로그

규칙: 이 파일은 오케스트레이터만 append 한다. 워커 상태는 `frontend-redesign-status.md`(워커 소유, FE1 시작 때 생성).

## 2026-10-05 — FE0 조사와 워크플로 수립 (오케스트레이터)

- 사용자 지시: UI/UX 개선 작업과 프로토타입 제작 완료(개발 중인 택틱 제외). 시안을 프론트로 구현하는 작업을 시작한다.
- 입력: Design 캔버스 "BA Planner v7 UI 개선 시안" 73개 artboard(version `1791201546-3bff`) 중 택틱 23개를 뺀 50개, `frontend/lib` 전체, `almanac/design/*`.
- 조사: 8개 그룹(H 공통, A 타이틀·홈, B 학생, C 계획 만들기, D 시나리오, E 인벤토리, F 통계, G 전술대항전)을 병렬 조사해 `docs/frontend-redesign/survey/`에 보고서로 남겼다. 시안 script는 전부 비어 있어 상태 전이는 변형 artboard 차이로 재구성했다. 백엔드 Python 소스는 조사 범위에 넣지 않았으므로 백엔드 쪽 판단은 Dart 클라이언트 검증 코드 기준이다.
- 사용자 결정(2026-10-05): FD-001 시안 우선(충돌 문서는 해당 slice에서 갱신), FD-002 백엔드를 화면별 수직 slice로 포함, FD-003 활성 계획 = 페이즈 문서 저장, FD-004 체크포인트 C 미완료 → 코드 편집은 C 커밋 뒤.
- 산출: `almanac/workflows/frontend-redesign-workflow.md`, `docs/frontend-redesign/decision-register.md`(FD-001~139, 열림 15건), `docs/frontend-redesign/artboard-map.md`, `docs/frontend-redesign/prototype/2026-10-05/`(50 artboard + canvas.json + MANIFEST), `docs/frontend-redesign/tools/dc_outline.py`.
- 열림 15건: FD-028(육성도), 030(위험도), 031(계획 충족률), 034(끝까지 가는 학생), 041(스냅샷 정의), 068(교차 선행 저장), 074(프리셋·내 그룹 영속화), 082(계획 탭 첫 화면), 096(크레딧·엘리그마 출처), 104(통계 필터 모델), 116(게임 창 연결 의미), 120(스캔 탭 역할), 126(전술 하위 화면 전환), 127(다수 사용자·확률 지표), 128(전술 기록 v2 일원화).
- 다음: 체크포인트 C 커밋 확인 → FE1-a. FE3-d 전에 FD-074·FD-104, FE4-a 전에 FD-082를 사용자에게 묻는다.

## 2026-10-06 — 시안 추가분 반영 (오케스트레이터)

- 사용자 지시: GUI 시안이 추가됐으니 반영. 캔버스 version `1791216886-b4f5`에서 새 artboard 7장 확인: 스캔 탭 6장(`Scan`, `Scan-Items`, `Scan-Student-Run`, `Scan-Student-Review`, `Scan-Item-Run`, `Scan-Item-Review`, 캔버스 page `scan` 신설)과 성장 계산기 `Calc-Student`(page `plan`). 기존 50장은 sha256 동일, canvas.json은 page·노트만 추가.
- 조사: `docs/frontend-redesign/survey/I-scan.md`, `J-calc.md`. J 보고서의 백엔드 slice 번호 FB-10은 스캐너 FB-10과 겹쳐 FB-11로 바꿨다.
- 반영: 사본 57장 + MANIFEST(`added` 날짜, history), 대장 FD-140~156(스캔)·FD-160~173(계산기) 추가, FD-120·121 확정(FD-001 적용), FD-122·123 폐기(→ FD-150·151), 막힘 요약 재작성, 지도에 스캔 절·계산기 행·역색인 추가, 워크플로 FE3-f/g·FE4-g·FE8-f1~f3·FE8-g1~g5·FB-10·FB-11.
- 스캐너 워크플로와의 경계: 스캔 탭은 스캐너 세션 소유 위젯 두 개를 수정하지 않고 마운트만 한다. `scan_page.dart`(FE8-f1)·`scan_companion_dock.dart`(FE8-g3)는 동결 창에서만. FB-10 요청 내용은 스캐너 오케스트레이터 로그에 같은 날 남겼다.
- 열림 23건(새로 열린 것: FD-140 홈 팝업 ↔ 스캔 탭 관계, 141 아이템 진행 창 형태, 142 일시정지·D21 개정, 146 칸별 승인·확인 필요 영속, 151 선물 스캔 위치, 160 계산기 진입점, 162 계산 경로·크레딧 내역, 163 인연 선물 데이터, 166 목표 행 구성).

## 2026-10-06 (저녁) — 열림 23건 사용자 결정 (오케스트레이터)

- 사용자 답: FD-166 → (c) 계산기 목표 행 = 시안 12행 + 애장품 행(애장품도 계산·S3에 목표값 표시). FD-096 → (c) 크레딧·엘리그마 보유량을 스캔 대상으로 추가(인식은 스캐너 워크플로 FB-10, 카탈로그 통화 항목은 FB-3, 수동 입력 없음, 스캔 전에는 "스캔 없음" 빗금). 나머지 21건(FD-028, 030, 031, 034, 041, 068, 074, 082, 104, 116, 126, 127, 128, 140, 141, 142, 146, 151, 160, 162, 163)은 권장안.
- 체크포인트 C는 커밋 `2156685ac63a`로 충족(워크플로 FD-004 갱신분 확인). 대장 FD-004에도 충족을 적었다.
- 결과: 대장 열림 0건, 막힘 요약은 새 열림 항목용으로 유지. FD-172(계산기 크레딧 보유 표기) 문구를 FD-096 결과에 맞췄다. 스캐너 쪽 요청(FD-142 일시정지·D21 개정, FD-146 칸별 승인·확인 필요 영속, FD-096 통화 스캔)은 확정으로 스캐너 오케스트레이터 로그에 전달했다.
- 다음 행동: FE1-a.

## 2026-10-06 (밤) — FE1-a 검토와 커밋 방식, golden 기준선 결정 (오케스트레이터)

- FE1-a 워커 결과(`frontend-redesign-status.md`): lib 14파일 + `theme_tokens_test.dart`, gate 미실행(워커 환경에 셸·Flutter 없음). diff 검토로 교체가 전부 같은 값의 토큰화임을 확인했다(`const` → `final` 2개는 non-const 사용처뿐, `AppMotion`·`AppControlHeights`는 `static const`).
- 커밋 위험: C 인계 `unrelated-changes.json` 기준 `theme.dart`·`app_shell.dart`·`plan_section_layout.dart`에 C 이전 미커밋 변경이 있다. 파일째 `git add` 하면 섞인다. 2026-10-05에 받아 둔 FE1-a 이전 사본과 현재 파일을 비교해 FE1-a만 담은 `fe1a.patch`(15파일 +379/−75)를 만들고, gate 실행 → (선택) 개편 문서 커밋 → 패치를 index에만 적용 → 검사 → status 기록 → 커밋을 하는 `commit-fe1a.ps1`을 `debug/frontend_fe1a_commit_20261006/`에 두었다. 공백 이름 경로·하위 디렉터리 실행에서 `git apply --cached --directory`가 동작함을 합성 저장소로 확인했다. PowerShell 자체는 이 환경에서 실행해 보지 못했다.
- golden: 저장소에 Flutter golden이 0개라 "golden diff 0"을 판정할 수 없다. FE1-b 앞에 FE1-g(golden 기준선 + fe_gate.ps1, 사용자 PC에서 생성)를 넣었다. 워크플로 불변식에 "기존 미커밋 변경 파일 처리"와 "워커 환경에 Flutter가 없을 때"를 추가했다.
- 복합장갑 색(#228b22 vs 시안 #7a8ea3)은 FE3-a/FE3-d에서 시안대로 바꾼다(FD-001).
- 다음: 사용자 `commit-fe1a.ps1 -CommitRedesignDocs` → FE1-g 워커 세션.

## 2026-10-06 (밤 2) — FE1-g 인수와 검증 명령 결정 (오케스트레이터)

- FE1-g 인수: golden 17장, 생성·비교 해시 동일, 최종 비교 gate GREEN(`debug/frontend_gate/20261006_222432/summary.txt`: analyze PASS, golden 외 414/414, golden 17/17, almanac validate PASS, diff-check 0). PNG는 사용자 커밋 `8e95d946`.
- 워커 발견 사항 3(맨 `flutter test`가 golden과 E2E를 병렬로 돌려 E2E 4건이 시간 초과) → **결정: Flutter 검증 명령을 `frontend/tool/fe_gate.ps1`로 바꾼다.** AGENTS.md·frontend/README.md를 고쳤다(C 시점에 깨끗했던 파일). 루트 README.md는 C 이전 미커밋 변경이 있어 지금 고치지 않는다. E2E 요청 시간 제한(10s)이 부하에 민감하다는 점은 다른 워크플로가 맨 `flutter test`를 쓸 때도 해당하므로 AGENTS.md 문구로 알린다.
- 커밋 상태: FE1-a는 아직 커밋되지 않았다(`commit-fe1a.ps1` 실행 기록 없음, HEAD `8e95d946`은 PNG만). FE1-b가 같은 파일을 다시 고치기 전에 커밋해야 패치 분리가 단순하다. 도우미를 개정했다: gate는 맨 `flutter test` 대신 fe_gate summary(GREEN)로 확인, AGENTS.md·frontend/README.md를 문서 커밋에 포함, `-IncludeFE1g`로 FE1-g 파일 커밋.
- FE1-b 조건 보강: 스캐너 소유 파일 3곳 제외, 커버리지로 108곳 실행 확인, 착수 전 사본을 `debug/frontend_fe1b/pre/`에 저장.
- (같은 날 22:31) 사용자 요청: 각 slice 커밋을 바로 하거나 커밋 코드를 함께 줄 것. 오케스트레이터·워커 모두 PC 셸이 없어 직접 커밋은 못 한다. 대신 `frontend/tool/fe_commit.ps1`을 만들었다: 워커가 남긴 착수 전 사본(`debug/frontend_<slice>/pre/`)과 `commit.json`으로 slice 변경만 index에 올리고, 최신 fe_gate GREEN(코드보다 나중)을 확인한 뒤 커밋한다. HEAD blob이 CRLF면 패치 줄도 CRLF로 맞춘다. 워크플로 불변식·세션 프롬프트 템플릿에 반영했고, FE1-g 커밋 목록에 이 스크립트를 넣었다. PowerShell은 이 환경에서 실행해 보지 못했으므로 첫 사용은 `-DryRun`부터.
- (22:35) `commit-fe1a.ps1` 실행 결과: 아무것도 stage되지 않았다. ① 개편 문서·AGENTS.md·frontend/README.md는 이미 HEAD에 추적되어 있었다(누가 언제 커밋했는지는 이 세션에서 확인 못 함). ② `fe1a.patch`가 `theme.dart:25`, `plan_section_layout.dart:3838`에서 HEAD 문맥과 맞지 않았다 — 패치 문맥 3줄이 C 이전 미커밋 변경과 겹친 것. 조치: `fe_commit.ps1`을 3-way 병합(base = 착수 전 사본, ours = HEAD, theirs = 현재 파일 → `git merge-file` → `hash-object` + `update-index`) 방식으로 다시 썼다. 합성 데이터로 theme.dart 인접 변경이 충돌 없이 병합됨을 확인했다. FE1-a·FE1-g·문서는 각각 `debug/frontend_fe1a/`, `debug/frontend_fe1g/`, `debug/frontend_redesigndocs/`의 commit.json으로 커밋한다. `commit-fe1a.ps1`은 폐기.
