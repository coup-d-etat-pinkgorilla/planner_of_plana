---
title: "P0-P6 Workflow Status"
summary: "새 대화에서도 P0~P6 작업의 정의, 진행 상태, 산출물과 다음 행동을 복원하기 위한 활성 진행 기록입니다."
topics: [workflow, architecture, migration]
sources:
  - id: agent-instructions
    type: file
    path: AGENTS.md
---

# P0-P6 Workflow Status

이 문서는 P0~P6 워크플로가 모두 완료될 때까지 유지하는 활성 작업 기록이다. 새
대화에서 관련 작업을 시작할 때 가장 먼저 읽고, 단계의 상태·결정·산출물·다음 행동이
바뀐 작업이 끝날 때마다 갱신한다. [@agent-instructions]

## 기록 원칙

- 저장소나 사용자가 제공한 근거 없이 단계의 목적과 완료 상태를 추측하지 않는다.
- 각 단계의 `input.md`, `output.md`와 `artifacts/` 위치를 기록한다.
- 완료 판정은 마스터가 결과물을 직접 확인한 뒤에만 기록한다.
- 슬레이브의 완료 보고만 받은 상태는 `검증 중`이며 `완료`가 아니다.
- 중요한 설계 결정, 실패 원인, 보류 이유와 다음 행동을 남긴다.
- 코드와 문서가 이 기록과 다르면 코드 및 검증 결과를 우선하고 이 문서를 바로잡는다.
- P0~P6 전체가 완료되기 전에는 이 문서를 삭제하거나 완료 기록을 축약하지 않는다.
- 전체 완료 후에는 최종 상태와 검증 근거를 남긴 뒤 장기 결정 문서로 정리할 수 있다.

## 상태 값

| 상태 | 의미 |
|---|---|
| `정의 필요` | 단계 이름이나 완료 조건이 아직 확인되지 않음 |
| `대기` | 정의됐지만 선행 작업 또는 명령을 기다림 |
| `진행 중` | 마스터 또는 슬레이브가 작업 중 |
| `인계 대기` | 슬레이브가 결과를 만들었으나 `output.md`와 결과물 인계가 끝나지 않음 |
| `검증 중` | 마스터가 전달된 결과물을 확인 중 |
| `차단됨` | 구체적인 장애 때문에 진행할 수 없음 |
| `완료` | 마스터가 결과물과 완료 조건을 직접 확인함 |

## 단계 정의

단계의 고정된 목적과 완료 조건은
[P0-P6 Implementation Workflow](p0-p6-workflow)를 따른다. 이 문서는 그 정의를
반복하지 않고 현재 상태, 실제 산출물, 검증과 다음 행동을 기록한다.

## 현재 단계 현황

2026-07-23 P0 계약부터 P6 전 기본 탭 실제 데이터 통합까지 마스터가 완료 조건과 대조해 보완하고
인수했다. 최종 P6 검증은 Python 79개, Flutter 136개, `flutter analyze`, 실제 Python process와
MockAppService의 scan Hold/Approve → current → goal → gross → shortage → tactical → restart restore,
세 viewport, Almanac과 Windows release build를 통과했다. P6-7 변경은 아직 커밋되지 않았다.

| 단계 | 목적 | 상태 | 근거 또는 산출물 | 다음 행동 |
|---|---|---|---|---|
| P0 | planning IPC 계약과 공용 fixture | `완료` | schema·fixture, Python/Dart contract 및 parity test 통과 | 계약 변경 시 양쪽 fixture test 유지 |
| P1 | Python JSONL process와 Dart client | `완료` | lifecycle·오류·실제 세 method E2E 및 release build 통과 | P2가 `AppService` planning method만 사용하도록 유지 |
| P2 | 실제 계획 화면 수직 슬라이스 | `완료` | 인계 patch 적용 후 마스터 보완, Widget test 8개와 전체 39개·실제 backend·Mock·release 통과 | P4/P6 전까지 in-memory·총 필요량 경계 유지 |
| P3 | repository 특성화와 DTO 분리 | `완료` | 원본과 followup 2건 적용, DTO·fixture·비중첩·전체 검증 통과 | P4에서 승인된 DTO·병합 계약 유지 |
| P4 | 프로필과 repository 영구 저장 | `완료` | nested schema·40-case Python/Dart contract, typed state, atomic persistence와 실제 Dart↔Python restart E2E; Python 40·Flutter 43·analyze·release 통과 | P5에서 repository 확정과 분리된 scanner session 경계 작성 |
| P5 | scanner/matcher session protocol과 backend | `완료` | 40-path follow-up 인수와 마스터 보완; Python 59·Flutter 47·실제 process E2E·release asset gate 통과 | 2학생·2인벤토리 아이콘 제한 coverage를 유지하고 P6에서 scanner UI 연결 |
| P6 | 전 기본 탭 실제 데이터 통합 | `완료` | P6-1~P6-7 완료; Python 79·Flutter 136·analyze·release·실제 process/Mock 최종 E2E·3 viewport·Almanac 통과 | P7은 별도 승인 전 시작하지 않음 |

## 현재 결정

- P0은 planning wire 계약, P1은 그 계약의 실제 process transport로 분리한다.
- P2에서 계획 탭을 먼저 실제화하고 P6에서는 repository·scanner 결과까지 통합한다.
- P3는 실제 repository 쓰기보다 DTO와 v6 병합 parity를 먼저 완료한다.
- P5는 scanner 결과 생성과 repository 확정을 분리한다.
- P5 event는 session ID, generation과 단조 증가 sequence를 가지며 terminal 뒤 event와
  이전 generation의 지연 event는 typed state와 repository를 바꾸지 않는다.
- 낮은 confidence candidate는 자동 저장하지 않고 검토·수정과 expected repository
  revision/idempotency key를 가진 별도 commit만 P4 경계를 호출한다.
- recognition template·region·adaptive sample은 Flutter UI asset과 분리하며 manifest와
  SHA-256으로 배포 경계를 검증한다.
- P6은 총 7개 하위 단계다: P6-1 학생 → P6-2 인벤토리 → P6-3 스캔 → P6-4 홈 →
  P6-5 통계 → P6-6 전술대항전 → P6-7 설정 및 통합 오류 처리.
- P6 전체 완료는 P6-7까지 구현한 뒤 모든 기본 탭과 스캔 → 현재 상태 검토 → 목표 설정 →
  총 필요량 → 부족량 → 저장·복원 통합 흐름을 검증한 경우에만 판정한다. 이는 정식 출시가
  아니라 통합 베타 기준이다.
- P6 화면 설계 전 입력으로 `almanac/design/frontend-section-direction-and-user-flows.md`를
  사용한다. 이 문서는 사용자가 정한 80도 사선·글라스·부착면·전환 방향을 확정 규칙으로,
  계획 외 탭의 기능별 행동 순서를 검수 전 가설로 구분한다.
- 창 비율 대응은 `almanac/design/responsive-diagonal-layout-policy.md`의 제한된 레이아웃
  상태 제안을 검수한 뒤 확정한다. 전체 캔버스 일괄 축소와 제약 없는 자동 재배치는
  기본 전략으로 사용하지 않는다.
- 기능 화면은 한 섹션에 많은 기능을 압축하기보다 사용자 목적 단위의 여러 부착 섹션으로
  나눈다. 중앙에 독립적으로 떠 있는 섹션은 만들지 않는다.
- backend launcher 설정은 연결 시점에 지연 해석해 잘못된 경로에서도 shell을 띄운다.
- timeout 후 늦은 response ID는 진단만 남기지만, malformed response·method mismatch,
  허용되지 않은 오류 code·성공 payload와 stdin 실패는 연결 전체를 종료한다.
- P1의 실제 backend에는 scanner capability가 없으며 스캔 버튼을 비활성화한다.
- 슬레이브와 마스터가 다른 PC이면 로컬 절대경로를 인계로 인정하지 않고 ZIP,
  SHA-256, manifest와 마스터 실행 프롬프트 네 파일을 마스터 inbox로 옮긴다.
- 같은 신뢰 가능한 사설 Wi-Fi/LAN에서는 일회용 token 수신기로 네 파일을 무선
  전송하고 ZIP 검증 후 자동 종료한다. token은 결과물이나 장기 문서에 기록하지 않는다.
- 마스터는 `$HOME/.codex/ba-planner-slave/Receive-SlaveResult.ps1` 단일 래퍼로 결과
  수신·staging 검사·`MASTER_PROMPT.md` 클립보드 복사를 수행한다.
- 슬레이브는 `$HOME/.codex/ba-planner-slave/Send-SlaveResult.ps1` 단일 래퍼로
  패키징·UDP 마스터 자동 발견·무선 업로드를 수행하며 IP·port·token을 수동 입력하지 않는다.
- 현재 슬레이브 PC는 저장 공간 제약으로 Flutter/Dart SDK를 설치·사용하지 않으며
  CodeAlmanac CLI도 지원되지 않는다. 이는 작업 차단 사유가 아니라 검증 책임 분리 조건이다.
  슬레이브는 Python·정적 검사·patch·패키징을 수행하고 Flutter/Dart/analyze/release,
  실제 Dart↔Python E2E와 Almanac 검증은 `MASTER_REQUIRED`로 인계한다.
- 슬레이브가 작성한 Flutter/Dart code와 test는 마스터 검증 전 통과로 간주하지 않으며,
  슬레이브의 `COMPLETED`는 산출물 준비 완료일 뿐 단계 완료 승인이 아니다.
- Windows UDP discovery는 도달 불가능한 가상 어댑터의 ICMP connection-reset을 개별
  probe 잡음으로 무시하고 nonce가 일치하는 수신기 응답을 계속 기다린다.

## 확인된 P0/P1 산출물

- 계약: `contracts/planning-protocol-v1.schema.json`과 method/error schema
- fixture: `contracts/fixtures/planning_protocol_v1.json`
- Python: `backend/core/protocol_v1.py`, `stdio_server.py`, `backend_process.py`
- Dart: `backend_process.dart`, `planning_protocol_client.dart`, `process_app_service.dart`
- test: Python contract/stdio test와 Dart contract/client test
- 실행 선택: 기본 mock을 유지하며 dart-define으로 실제 backend를 선택

기존 슬레이브 `input.md`, `output.md`와 `artifacts/` 위치는 확인되지 않았다. 이후
사용자가 현재 작업 트리의 P0/P1을 이 워크플로에 맞게 직접 수정하도록 지시했고,
마스터가 코드·diff·테스트를 직접 보완하고 검증했으므로 기존 인계 누락은 P0/P1의
완료를 막지 않는 일회성 예외로 판정했다. P2부터는 Slave Artifact Handoff 계약을
생략하지 않는다.

## 현재 검증

- `codealmanac validate`: 통과, 6 pages
- `py -3.11 -m unittest discover -s tests -v`: 27 tests 통과
- P3 repository parity: 10 tests와 fixture 26 cases 통과; current/metadata field 교집합 없음, `display_name` confirmed/commit 유입 두 사례 거부
- `flutter analyze`: 문제 없음
- `flutter test`: 39 tests 통과
- P2 Widget test: 8 tests 통과(조회·중복·삭제·오류·Mock·목표 의미·합산·stale·좁은 화면)
- 실제 Python process의 student lookup, plan validation, calculation: 통과
- timeout, late response, malformed response, method mismatch, invalid error/success
  payload, stdin failure, unexpected exit, restart와 dispose: 통과
- `flutter build windows --release`: 통과
- `git diff --check`: 통과
- 금지된 GUI/v6 runtime import 검사: 유입 없음

## 다음 행동

1. `docs/migration/p5-scanner-matcher/slave-execution-prompt.md`를 슬레이브에게 전달한다.
2. 슬레이브는 P4 승인 baseline gate가 모두 통과한 경우에만 P5 구현을 시작한다.
3. P5 인계 전까지 scanner capability와 스캔 버튼은 비활성 상태를 유지한다.
4. P6 전까지 P2 결과는 보유량 차감 전 총 필요량이며 부족량을 표시하지 않는다.
5. P6 하위 단계의 화면 구성을 확정하기 전에 탭별 흐름 가설의 `사용자 검수 포인트`를
   사용자와 확인하고, 승인된 흐름만 실제 섹션 구성으로 변환한다.

## P6 UX 선행 입력 — 섹션 방향과 탭별 사용자 흐름

- 상태: `진행 중`
- 목적: 실제 P6 화면 배치 전에 공통 섹션 규칙과 계획 외 탭의 기능별 행동 흐름을 고정
- 입력: 사용자 제공 프론트엔드 디자인 방향, P6 탭별 기능, v6 사용자 흐름 감사
- 출력 보고서: `almanac/design/frontend-section-direction-and-user-flows.md`,
  `almanac/design/responsive-diagonal-layout-policy.md`
- 결과물: 80도 사선·부착면·글라스·모션 계약, 탭별 기능 그룹·주 흐름·탭 간 인계·검수 질문,
  창 비율별 제한된 레이아웃 상태와 사선 안전 폭 계약 제안
- 검증: `AppSection.primary`, P6 탭별 기능과 v6 보존 흐름 대조; `codealmanac validate`와
  `codealmanac health` 통과(8 pages, orphan·dead ref·broken link·citation 문제 없음)
- 결정 및 제약: 계획 탭은 사용자가 이미 기획한 기준 사례로만 기록하며 재설계하지 않음;
  나머지 탭의 흐름은 화면 배치가 아니라 검수 전 가설임
- 차단 사항: 없음
- 다음 행동: 사용자가 탭별 우선순위·흐름 분기점과 반응형 정책의 승인 항목을 검수한 뒤
  실제 섹션 구성 및 지원 최소 창 크기를 별도 확정
- 최종 갱신: 2026-07-22

## P6 이후 섹션 템플릿 Studio

- 상태: `초기 구현 완료`
- 목적: 실제 탭 재디자인 전에 섹션 점유 공간·80도 형상·허용 조합을 개발 화면에서 검증
- 산출물: `frontend/lib/ui/studio/section_template.dart`,
  `frontend/lib/ui/pages/section_template_studio_page.dart`,
  `frontend/lib/ui/widgets/section_template_surface.dart`,
  `frontend/test/section_template_studio_test.dart`,
  `almanac/design/section-template-studio.md`
- 결정: 단일/조합 모드와 고정 조합 preset을 제거하고 사용자 정의 요소 목록 하나로 통합한다.
  Section이 하나면 단일, 둘 이상이면 조합이며 사용자가 Section을 직접 추가·삭제·선택하고
  X·Y·폭·높이를 편집한다. 전역 96×96 논리 사선 격자에서 8칸마다 major line을
  표시하고 한 칸을 섹션 사이 기본 간격으로 사용한다. 모든 사선은
  우측 위 `/` 방향 80도로 고정하고 반대 방향 및 상·하 방향 사선은 허용하지 않는다.
  형상 입력은 삼각형·사다리꼴·평행사변형 모드, 붙는 면과 면 내부 96분할 범위로 구성하고
  사다리꼴·평행사변형만 높이를 추가로 받는다. 채팅 전달용 요약 복사를 제공한다.
  모든 요소는 별도 Positioned clip 영역 없이 하나의 콘텐츠 캔버스 Size·원점에서 절대
  좌표 path로 함께 그린다. 따라서 사선이 요소 rect를 넘어도 공용 캔버스 안에서는 잘리지
  않는다. 선택 요소의 본체 drag는 이동, 네 모서리 handle drag는 resize이며 두 조작 모두
  실제 pointer delta를 정수 grid cell로 snap하고 최소 1칸과 96×96 캔버스 경계에서 clamp한다.
  프리뷰 상단 고정 헤더는 0/96~48/96 비율을 선택하고 남은
  콘텐츠 영역만 섹션 geometry에 사용한다. 모든 polygon 꼭짓점에 corner radius를 적용하며
  예각은 직선 구간을 더 유지하는 36% 접점과 polygon winding 방향의 볼록한 원형 fillet로
  더 깊게 잘라 둥글리며 반대 원 중심에서 생기는 오목한 패임을 허용하지 않는다.
  구성 저장은 version 5 UTF-8 JSON(`*.ba-section-studio.json`)을 사용하고 version 1~4 read 호환을
  유지하며 format/version, Section 96×96 grid, 하위 부모 상대 배치·공통 간격, 우측 위 80° 사선
  계약, workspace 표시 상태와 모든 요소 설정을 기록한다.
  불러오기는 문서 전체의 타입·범위·중복 ID·선택 ID를 검증한 뒤에만 캔버스를 원자적으로
  교체하며 손상·비호환 파일은 기존 상태를 보존한다. Windows 기본 파일 대화상자는 Flutter
  공식 `file_selector`로 연결하고 service 주입 경계로 실제 파일 시스템 없이 회귀 test한다.
  개발 상태 패널에서만 Studio에 진입하며 기존 실제 탭의 `DiagonalSection`은 아직 교체하지 않는다.
- 검증: Section 범위·중첩과 하위 부모 경계·아이템 간격 validator, 공용 캔버스 rect 외 경로
  보존과 hit test, 형상 geometry, 요소 추가·선택·편집, Section grid snap과 하위 간격 snap,
  resize·경계 clamp, viewport 전환,
  AppShell 개발 패널 진입과 전체 요소
  채팅용 요약 복사, versioned JSON round-trip·schema 거부·저장·원자적 불러오기 Widget test;
  `flutter analyze`, Flutter 전체 tests, `flutter build windows --release`, `git diff --check`,
  `codealmanac validate`, `codealmanac health` 통과. 현재 host의 Windows 개발자 모드는 꺼져 있어
  Flutter가 plugin symlink를 직접 만들 수 없으므로 ignored ephemeral 폴더에 같은 package target의
  directory junction을 생성한 뒤 release를 검증했으며 시스템 설정은 변경하지 않음
- 후속 레이어 확장: Section은 전역 96×96 좌표계를 유지하고 Container → Feature는 각 부모의
  경계 상자에 대한 0~1 비율 rect를 사용하도록 정리했다. 하위 요소 drag는 부모 테두리와 형제
  아이템 사이의 선택 간격에 snap하며 resize는 부모 경계에서 clamp된다. 2026-07-26 후속 보정으로
  이 간격 계산을 rect의 네 변 비교에서 실제 둥근 polygon path 사이 최단거리로 교체했다.
  부모의 짧은 변에 대한 비율을 pixel 거리로 환산하고 평행사변형 사선의 법선 방향 snap,
  경계 밖 이동 복귀, 실제 path 중첩·간격 validator와 최단거리 guide를 같은 계산으로 통일했다.
  Container와 shape
  Feature는 삼각형·사다리꼴·평행사변형 및 80° 계약을 공유하고 부모 path 안에서 렌더링·hit
  test한다. image Feature는 252×172 기본 이미지, 863×250 Plan A 타이틀과 둥근 화살표 preset을
  사용하며 입력·handle resize 모두 선택 preset 비율을 고정한다. 저장 문서는
  계층·부모 ID·image metadata·부모 상대 배치·공통 간격을 포함하는 version 4를 거쳐, 0% 헤더,
  Container BA 삼각 무늬와 image preset·text·line Feature를 저장하는 version 5로 올렸다. v1~v4를
  읽으며 v1~v3의
  하위 96 좌표를 읽을 때 비율 rect로 변환한다.
  Windows release 동기화는 기존 `release/` 루트의 `*.ba-section-studio.json`을 staging으로
  승계한 뒤 번들을 교체해 사용자 배치 문서를 삭제하지 않는다.
  `저장 파일에서 섹션 추가`는 현재 workspace에 section을 append하며 모든 자식 ID와 parent 참조를
  충돌 없는 새 ID로 remap한다. 제공받은 863×250 Plan A 타이틀 PNG는 Studio asset으로 복사하고,
  화살표 preset은 별도 bitmap 없이 둥근 stroke path로 렌더링한다. Container 삼각 무늬는 기존
  `BATriangleTexturePainter`를 고정 seed·저대비 설정으로 재사용한다. Flutter 전체 161 tests,
  `flutter analyze`, Windows release build,
  `codealmanac validate`·`health`와 `git diff --check`를 후속 확장 기준으로 통과했다.
- 2026-07-26 최신 Studio v5 빌드는 `flutter build windows --release`까지 통과했다. 현재 사용자가
  `release/ba_planner_v7.exe`를 실행 중이어서 release 동기화의 실행 파일 교체만 Windows 파일 잠금으로
  보류했다. 앱을 닫은 뒤 `frontend/tool/build_windows_release.ps1`을 다시 실행하면 기존 Studio JSON을
  보존하면서 새 번들로 교체된다.
- 2026-07-26 Title 계정 생성·관리 클러스터를
  `release/section-account-create-manager.ba-section-studio.json`에서 typed projection했다. 재저장된
  문서를 다시 확인해 이전 export에 없었던 Section 5·Container 11~16·18·19·Feature 5~8의 임시
  runtime 배치를 폐기하고 저장 좌표와 polygon으로 교체했다. typed 문서 encode 결과와 저장 JSON
  전체를 비교하는 회귀 test를 추가했으며 Container 15 목록 행, Container 16 portrait, Feature
  5·6·7의 계정명·구분선·학생 수, Feature 8 입력 영역의 실제 배치도 검증한다. 부모 Section fill은
  자식 입력·텍스처·목록 path를 차감해 반투명 표면이 중복 합성되지 않게 했다. 첫 계정은 Section 1만,
  Title 설정은 Section 5만 진입하고 추가·수정은 Section 1,
  사진 선택은 Section 4를 호출한다. 4열 portrait scroll grid는 asset manifest의 전체 portrait를
  `AssetImageGrid`로 직접 paint하며 square→98% portrait, 내부 여백·간격·2% pink 선택 stroke를 같은
  painter가 처리한다. profile summary에 `avatar_student_id`를 호환 추가하고 update/delete protocol,
  Mock·Python atomic store와 실제 Dart↔Python restart E2E를 확장했다. 계정 삭제는 UI 확인 후에만
  실행한다. Python 80개, Flutter 174개, `flutter analyze`, Windows release build,
  `codealmanac validate`·`health`와 `git diff --check`가 통과했다.
- 2026-07-26 계정 클러스터 후속 조정으로 Section 5 호출/퇴장을 0°/180°, Section 1·4를
  80°/260°로 분리하고 비직교 벡터의 X·Y 성분과 진행 방향을 Widget test로 고정했다. Section 5의
  Container 12·13·14·18·19는 동일 높이·세로 간격과 Container 11 사선까지의 동일 간격으로
  재배치했다. Container 11에는 삼각 무늬를 그리지 않으며, Container 15·16을 내부 여백 안으로
  옮기고 각 목록 행이 scroll offset에 따라 80° 경계를 따라 이동하도록 변경했다. 저장 Studio
  JSON과 typed projection을 함께 갱신했다. Flutter 171개, `flutter analyze`, Windows release
  build, `codealmanac validate`·`health`와 `git diff --check`를 검증 기준으로 사용한다.
- 2026-07-26 재수정된 계정 Studio JSON의 Container 11~19와 Feature 5~7 좌표 및 workspace 선택을
  typed projection에 다시 반영했다. Section 4 portrait grid는 행별 viewport 위치에 따라 위쪽
  80°·아래쪽 역방향 260°가 되는 직선 scroll 궤적을 사용하고 painter와 hit test가 같은 X offset을
  공유한다. 선택 stroke는 cell RRect 대신 `square.png` alpha silhouette를 확장·내부 제거해 그린다.
  Flutter 172개와 `flutter analyze`가 통과했다.
- 2026-07-26 Section 5·1·4를 독립 animation controller로 분리했다. 관리 화면의 추가·수정은 Section
  5를 유지한 채 Section 1을 열고, Section 4 닫기·저장은 Section 4만 퇴장한다. Section 1 뒤로는
  첫 계정 경로에서 Title로, 관리 경로에서는 Section 4와 Section 1만 퇴장해 Section 5로 돌아간다.
  관리 버튼 폭은 매 viewport에서 Container 11 실제 polygon 경계를 기준으로 같은 간격이 되도록
  재계산한다. Section 4에는 grid 궤적을 따르는 custom scrollbar track·handle과 drag mapping을
  추가했다. Flutter 174개와 `flutter analyze`가 통과했다.
- 2026-07-26 Section 4 portrait grid와 custom scrollbar의 위치별 곡선 보간을 제거하고, 전체
  viewport에서 고정 80° 직선(역방향 260°) 하나를 공유하도록 수정했다. 행 painter·hit test와
  scrollbar track·handle은 동일한 선형 X offset을 사용한다. Flutter 174개, `flutter analyze`,
  Windows release build, `codealmanac validate`·`health`와 `git diff --check`가 통과했다.
- 2026-07-26 Section 4 grid painter가 loose cross-axis constraint에서 폭 0으로 축소되던 경로를
  `StackFit.expand`로 고쳐 Container 8 폭을 사용하게 했다. Section 5 계정 행은 Container 11의
  중앙 80° 기준선에 맞추고 기존 사선 scroll translation을 유지한다. Title Space 단축키는 Title이
  실제 활성 상태일 때만 시작 동작을 호출한다. Flutter 174개, `flutter analyze`, Windows release
  build, `codealmanac validate`·`health`와 `git diff --check`가 통과했다.
- 2026-07-26 계정명 입력의 별도 진한 표면·border·fill을 제거하고, 기존 이름 편집 시 selection을
  문자열 끝으로 설정해 한글 IME cursor 위치를 고정했다. Container 3은 Container 4 square의 실제
  path 폭과 80° 중심선을 공유한다. Section 5·1·4가 모두 열린 상태의 Section 1 뒤로는 세 Section을
  모두 퇴장시켜 Title로 돌아가며, Container 11에는 행과 같은 80° custom scrollbar를 추가했다.
  Flutter 174개, `flutter analyze`, Windows release build, `codealmanac validate`·`health`와
  `git diff --check`가 통과했다.
- 2026-07-26 후속 수정으로 계정명 controller가 각 Windows IME composing update의 selection을
  `composing.end`로 정규화하도록 변경했다. Container 3 폭은 `square.png` 252×204 전체 캔버스가
  아니라 중앙 정사각 이미지의 204px 한 변에 실제 contain 배율을 적용한 길이를 사용한다.
  Flutter 174개, `flutter analyze`, Windows release build, `codealmanac validate`·`health`와
  `git diff --check`가 통과했다.
- 2026-07-26 위 selection 정규화가 Windows 한글 IME와 편집 상태를 왕복해 `ㄱ거거` 중복 입력을
  일으키는 것을 실기기 재현으로 확인했다. 정규화 listener를 제거해 IME의 composing text·selection·
  range를 그대로 보존하고, 조합 중에만 기본 cursor를 숨긴 뒤 commit 시 다시 표시하도록 교체했다.
  Flutter 174개, `flutter analyze`, Windows release build, `codealmanac validate`·`health`와
  `git diff --check`가 통과했다.
- 2026-07-26 이번 계정 클러스터 적용의 시행착오를 `almanac/design/section-template-studio.md`의
  `계정 클러스터 적용 시행착오와 재발 방지`에 통합했다. 저장 전후 Studio 좌표 불일치, polygon
  경계 기반 동적 버튼 폭, 80° 직선 scroll의 painter·hit test·scrollbar 좌표 공유, loose constraint로
  폭 0이 된 grid, square alpha silhouette 선택선, 중첩 Section 상태 전이, Title Space shortcut 범위,
  Windows IME composing selection 강제 변경에 따른 중복 입력과 최종 cursor-only 대응을 원인·실패
  방식·재발 방지 규칙으로 기록했다.
- 2026-07-26 Section 1 editor, Section 4 asset picker, Section 5 manager를 요소 번호별 작업 스타일로
  문서화했다. Container 3~16·18·19와 Feature 4~8의 표면·이미지·text·click·상태 전이 계약을
  기록하고, 유사 위젯에는 별도 지시가 없으면 list/grid의 표준 수직 ScrollController를 유지하면서
  row·자식·hit test·custom scrollbar를 같은 80° 직선으로 투영하는 기본 경향을 적용하기로 했다.
  이 공통 scroll 계약은 `almanac/design/responsive-diagonal-layout-policy.md`에도 반영했다.
- 2026-07-27 Title의 밝은 삼각 무늬 행동 버튼 팔레트를 하늘색에서 공용 핑크색 계열로 변경했다.
  메인 시작·설정·종료와 계정 클러스터의 변경·뒤로·저장·닫기·전환·추가·수정·삭제가 같은
  공용 action 색상군을 사용하며, 어두운 계정 row와 scrollbar는 범위에서
  제외했다. 밝은 삼각 무늬 버튼은 핑크색 계열을 사용한다는 공통 스타일도 Almanac에 기록했다.
  Title 집중 14개와 Flutter 전체 171개 test, `flutter analyze`, Windows release build가 통과했다.
- 2026-07-27 후속 검수에서 첫 핑크 팔레트의 base·panel이 너무 진한 자주색으로 보이는 문제를
  확인해, 테두리 강조색에 가까운 저채도 연핑크색으로 올렸다. texture geometry·seed·대비는
  변경하지 않았으며 Almanac의 밝은 삼각 무늬 버튼 규칙도 진한 자주색을 사용하지 않도록 구체화했다.
  연핑크 hue·명도 계약을 추가했고 Title 집중 15개, Flutter 전체 172개 test, `flutter analyze`,
  Windows release build가 통과했다.
- 2026-07-27 두 번째 연핑크 팔레트도 넓은 버튼 면에서 너무 튄다는 검수에 따라 Title 로고 PNG의
  대표 핑크 `#E08EE6`을 직접 추출했다. 이를 흰색 쪽으로 옅게 섞고 base alpha를 약 53%로 낮춘
  `BATrianglePalette.softTitlePink*`로 교체해 로고 hue는 공유하되 표면 대비는 낮췄다. Title 집중
  15개와 Flutter 전체 172개 test, `flutter analyze`, Windows release build가 통과했다.
- 2026-07-27 Title 패널의 기본 brand·primary·account Section과 계정 editor·picker·manager Section
  모두에 공용 `paintLiftedPathShadow` 기반 그림자를 추가했다. 각 그림자는 차감 전 Section polygon을
  사용하고 motion subtree 안에서 표면과 함께 이동하며 버튼·목록에는 중복 적용하지 않는다. Title
  집중 15개와 Flutter 전체 172개 test, `flutter analyze`, Windows release build가 통과했다.
- 다음 행동: 사용자가 0% 헤더, Container 삼각 무늬, 세 image preset과 text·line Feature를 수동
  검수하고 Title 계정 클러스터를 수동 확인한 뒤 Dart spec export와 공용 `SectionGeometry` 승격
  범위를 결정
- 최종 갱신: 2026-07-27

## 마스터 사용량 중단 시 슬레이브 작업 규칙

마스터의 사용량이 중간에 끊기거나 마스터가 결과를 즉시 검사할 수 없을 때도 슬레이브는
이미 전달받은 현재 단계의 `input.md` 범위 안에서 작업을 계속할 수 있다. 다만 슬레이브의
`COMPLETED` 보고는 마스터의 수신·검증·적용을 대신하지 않으며, 마스터 검증 없이 다음 의존
단계를 구현하지 않는다.

### 공통으로 계속할 수 있는 작업

1. 이미 지시받은 현재 단계의 구현, 테스트, 문서화와 자체 검증을 끝낸다.
2. 최종 patch, fixture, 검증 로그 등 실제 결과물을 `artifacts/`에 저장한다.
3. 각 결과물의 크기와 SHA-256을 기록한 `output.md`를 작성하고 인계 패키지를 준비한다.
4. 실패·미검증·환경 제한과 마스터가 결정해야 할 사항을 `output.md`에 명시한다.
5. 다음 단계에 필요한 v6 동작 조사, 현재 코드 경계 목록, 위험 목록과 테스트 사례를 읽기
   전용 조사 산출물로 준비할 수 있다.
6. 마스터가 복귀할 때까지 원래 결과물과 전송 패키지를 보존하며, 임의로 재생성하거나
   다른 단계 결과와 합치지 않는다.

### 마스터 검증 전 금지 작업

- 슬레이브가 자신의 결과를 승인·적용된 것으로 간주하거나 이 상태 문서를 `완료`로 바꾸는 일
- 현재 단계 결과를 전제로 다음 의존 단계의 production 구현을 시작하는 일
- 아직 승인되지 않은 DTO, protocol, event schema 또는 repository 경계를 사실상 확정하는 일
- 마스터 작업공간에 patch를 직접 적용하거나 여러 단계 patch를 하나로 합치는 일
- `../v6` runtime import, 실제 사용자 프로필 변경 또는 명시되지 않은 migration 실행
- 마스터 지시 없이 기존 결과물을 폐기·재생성하거나 파일명과 인계 경로를 바꾸는 일

### 단계별 대기 작업

| 마스터 중단 시점 | 슬레이브가 할 수 있는 작업 | 넘어가면 안 되는 경계 |
|---|---|---|
| P3 검증 전 | P3 follow-up 완료·자체 테스트·패키징, P4의 atomic write·손상·migration·revision 시험 항목 조사 | P4 영구 저장 구현 |
| P4 지시 전 | v6 프로필 저장 동작과 오류 사례 조사, 저장 파일 소유권·migration 위험·contract test 표 초안 | 승인되지 않은 P3 DTO를 사용한 P4 코드 |
| P4 작업 중 | 전달받은 P4 범위 구현·전체 검증·패키징 | 자신의 P4 결과를 전제로 한 P5 구현 |
| P5 지시 전 | v6 scanner/capture/matcher 의존성 조사, event 종류·취소·stale·confidence fixture 후보와 recognition asset 목록 작성 | session protocol 확정, backend 연결, repository commit 구현 |
| P5 작업 중 | 전달받은 P5 범위 구현·headless test·asset 검사·패키징 | 자신의 P5 결과를 전제로 한 P6 실제 연결 |
| P6 지시 전 | 탭별 placeholder·공용 widget·필요 service 목록, loading/empty/error/disconnected 및 대용량 UI test matrix 작성 | 실제 repository/scanner client 연결 |
| P6 작업 중 | 마스터가 지정한 단일 P6 하위 단계만 구현·검증·패키징 | 다음 P6 하위 단계나 미승인 service 계약으로 범위 확대 |

P4, P5와 P6은 순차 의존하므로 마스터가 없는 동안 자동 연쇄 실행하지 않는다. 병렬 준비는
선행 계약을 바꾸지 않는 조사, fixture 후보, 테스트 계획과 UI 현황 목록으로 제한한다.

## P2 — 계획 화면 수직 슬라이스

- 상태: `완료`
- 목적: 계획 placeholder를 학생 목표 편집과 총 필요량 계산이 가능한 실제 화면으로 교체
- 완료 조건: AppService planning method만 사용하는 학생별·전체 계산, 필수 상태와 Widget test, 전체 검증 통과
- 입력: `docs/migration/p2-planning-screen/input.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p2-planning-screen/staging/master-verify-20260722-000001-a8bb6fea/output.md`
- 결과물: 같은 staging의 `artifacts/p2-planning-screen.patch`, `artifacts/verification.txt`; 수신 ZIP SHA-256 `16b833cde5201f3dd90e08d56ccbce223f5ee40d78c4f1257ea15daf063cdc87`
- 검증: ZIP·manifest·산출물 크기/SHA-256 일치, 무중첩 확인, `git apply --check` 후 적용; Python 17, Flutter 39, analyze, 실제 Python process E2E, Mock flow, Windows release, Almanac와 diff 검사 통과
- 결정 및 제약: 정확한 학생 ID 조회, in-memory 임시 현재 상태, AppService planning method만 사용, 부족량·저장·scanner 제외
- 차단 사항: 없음
- 다음 행동: 작성된 P3 작업 지시를 슬레이브에게 전달하고 DTO·병합 fixture 결과 인계 대기
- 최종 갱신: 2026-07-22

## P3 — Repository 특성화와 DTO 분리

- 상태: `완료`
- 목적: v6 repository의 scanner·storage 결합을 특성화하고 독립 DTO와 순수 병합 parity 경계를 확정
- 완료 조건: scanner/matcher 없이 fixture 재생, 다섯 데이터 버킷 매핑 고정, v6 runtime import 없는 parity test, 실제 사용자 저장소 쓰기 없음
- 입력: `docs/migration/p3-repository-dto/input.md`
- 추가 입력: `docs/migration/p3-repository-dto-followup-1/input.md`
- 추가 입력 2: `docs/migration/p3-repository-dto-followup-2/input.md`
- 출력 보고서: 원본 `docs/migration/handoffs/incoming/ba-planner-v7-p3-repository-dto/staging/20260722-004918-138dd469/output.md`; followup-1 `docs/migration/handoffs/incoming/ba-planner-v7-p3-repository-dto-followup-1/staging/20260722-012000-57ed5103/output.md`; followup-2 `docs/migration/handoffs/incoming/ba-planner-v7-p3-repository-dto-followup-2/staging/20260722-020150-bead4898/output.md`
- 결과물: followup-2 staging의 `artifacts/p3-repository-dto-followup-2.patch`, `artifacts/verification.txt`; followup-2 ZIP SHA-256 `af07c2538b63cdb9cd03601a4bde8d28ce5324372f439884f052853e30823560`
- 검증: 세 패키지의 ZIP·manifest·sidecar·artifact 해시와 단계별 baseline·무중첩 확인, 각 `git apply --check` 후 증분 적용; P3 10 tests·fixture 26 cases, Python 27, Flutter 39, analyze, Windows release, Almanac, diff, 실제 backend 세 method E2E와 Mock 계획 흐름 통과; current/metadata 교집합 `set()`, `display_name` confirmed/commit 유입 두 사례 모두 `RepositoryDTOError`
- 결정 및 제약: P3는 DTO·순수 병합·fixture·문서·test만 구현하며 영구 저장은 P4, scanner session/backend는 P5에 남김
- 차단 사항: 없음
- 다음 행동: P4가 아래 승인 baseline을 변경 전 gate로 재현하도록 유지
- 최종 갱신: 2026-07-22

### P3 승인 baseline

P3 완료는 현재 작업 트리의 다음 파일과 실행 결과를 P4의 불변 입력으로 승인한 것을
뜻한다. P4 슬레이브는 구현 전에 이 baseline을 재현하며, 하나라도 다르면 P3를 임의로
수정하지 않고 `BLOCKED`로 반환한다.

- 승인 파일: `backend/core/repository_dto.py`, `backend/core/repository_merge.py`,
  `backend/tests/test_repository_parity.py`, `contracts/fixtures/repository_v6_parity.json`,
  `docs/migration/p3-repository-dto/repository-characterization.md`,
  `docs/migration/p3-repository-dto/repository-protocol-draft.md`
- fixture 기준: version 1, 26 cases(`student_merge` 6, `inventory_normalize` 3,
  `inventory_merge` 2, `inventory_order` 1, `inventory_diff` 1, `resolve` 2,
  `dto_error` 10, `bucket_mapping` 1)
- test 기준: `tests.test_repository_parity` 10 tests, 변경 전 전체 Python 27 tests
- field 기준: `CONFIRMED_STUDENT_VALUE_FIELDS`와 `StudentMeta.__annotations__` 교집합
  `set()`; `display_name`의 confirmed-current 및 student commit 유입 모두 거부
- 책임 기준: P3는 독립 DTO, 순수 병합, fixture와 특성화만 소유한다. filesystem/SQLite
  I/O, profile catalog, atomic persistence와 migration은 P4가 소유한다.
- 금지 기준: 실제 사용자 저장소 쓰기, `../v6`·scanner·GUI runtime import, 정적 metadata,
  goal, 총 계산 결과 또는 shortage의 confirmed-current/inventory 유입 없음

## P4 — Repository와 프로필 영구 저장

- 상태: `완료`
- 목적: Python backend가 프로필, 확정 현재 상태, 인벤토리와 사용자 목표의 안전한 저장·복원을 소유
- 완료 조건: 재실행 복원, atomic failure 시 기존 데이터 보존, revision/idempotency 및 손상·병합 fixture, Python/Dart contract와 전체 검증 통과
- 입력: `docs/migration/p4-repository-persistence/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p4-repository-persistence/slave-execution-prompt.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p4-repository-persistence/staging/20260722-124720-98185035/output.md`
- 결과물: 같은 staging의 `artifacts/p4-repository-persistence.patch`, `artifacts/verification.txt`; ZIP SHA-256 `f14f7d07f7908b71d87af136e3afbe027cf9c6c338c958a40eea52d73776143f`
- 검증: ZIP 21,647 bytes와 SHA-256이 사용자 값·manifest·sidecar에 일치하고 내부 artifact 2개의 크기·해시도 `output.md`와 일치함. 21개 patch path가 모두 `BA Planner/v7/...`이고 기존 Almanac 변경과 중첩 없이 `git apply --check` 및 적용 통과. P3+P4 집중 Python 20, 전체 Python 37, `flutter analyze`, Windows release build, `codealmanac validate`, `git diff --check` 통과. Flutter 전체 41개 중 나머지 40개는 통과했으나 신규 profile panel test 1개가 disposed `TextEditingController` 재사용으로 실패. 수동 corruption probe에서 malformed catalog entry는 raw `KeyError`, malformed profile `idempotency`는 raw `AttributeError`를 발생시켜 구조화된 `corrupt_data` fail-closed 조건을 충족하지 못함. repository schema는 임의 success payload도 유효 판정하며 Dart fixture test는 case별 `valid`를 검증하지 않음
- 결정 및 제약: P4는 저장·profile·repository protocol과 최소 profile UI만 구현하며 scanner session/backend는 P5, 전 탭 통합은 P6에 남김
- 원본 인계 차단 이력: profile dialog lifecycle과 손상 catalog/idempotency raw 예외는 follow-up-1에서 해결됨; method별 success response schema와 Dart contract 검증은 미해결
- 보완 입력: `docs/migration/p4-repository-persistence-followup-1/input.md`
- 보완 슬레이브 실행 프롬프트: `docs/migration/p4-repository-persistence-followup-1/slave-execution-prompt.md`
- 보완 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p4-repository-persistence-followup-1/staging/20260722-141231-dda5ceb6/output.md`
- 보완 결과물: 같은 staging의 `artifacts/p4-repository-persistence-followup-1.patch`, `artifacts/verification.txt`; ZIP SHA-256 `d1cc336970efcd1ae8dac08163452102af22b526f17f770072d854c2d04c33c9`
- 보완 검증: ZIP 6,982 bytes와 SHA-256이 사용자 값·manifest·sidecar에 일치하고 내부 artifact 2개의 크기·해시도 `output.md`와 일치함. 4개 증분 path가 모두 `BA Planner/v7/...`이며 현재 상태 문서와 중첩 없이 apply-check·적용 통과. 집중 Python 22, 전체 Python 39, Flutter 41, analyze, Windows release, Almanac와 diff 검사 통과. profile create/select/rename/cancel/빈 입력 lifecycle test 통과; malformed catalog와 idempotency가 모두 `corrupt_data`로 fail-closed함. 반면 `{ "nonsense": true }` profile-list success가 schema에서 여전히 유효하며 method별 success schema, Dart valid/invalid validator와 runtime rejection, typed repository state 및 real Dart/Python restart E2E는 미구현임
- 차단 사항: follow-up-1은 lifecycle/corruption을 해결했고 follow-up-2 부분 증분은 method별 top-level success schema만 해결함. Dart fixture validator, runtime malformed-success 차단, typed repository state, real Dart/Python restart E2E와 nested request/state schema가 미구현임. 전달문이 P4 follow-up task를 P2 및 `p2-planning-screen.patch`로 부르는 복사 오류도 남아 있음
- 보완 입력 2: `docs/migration/p4-repository-persistence-followup-2/input.md`
- 보완 슬레이브 실행 프롬프트 2: `docs/migration/p4-repository-persistence-followup-2/slave-execution-prompt.md`
- 보완 출력 보고서 2: `docs/migration/handoffs/incoming/ba-planner-v7-p4-repository-persistence-followup-2/staging/20260722-150536-0faf9415/output.md`
- 보완 결과물 2: 같은 staging의 `artifacts/p4-repository-persistence-followup-2.patch`, `artifacts/verification.txt`; ZIP SHA-256 `2d985e43867337843da811e08b02876cf4b340c575846f7028f03e717bb5085e`
- 보완 검증 2: ZIP 5,539 bytes와 SHA-256이 사용자 값·manifest·sidecar에 일치하고 내부 artifact 2개의 크기·해시도 `output.md`와 일치함. schema·fixture 2개 증분 path가 `BA Planner/v7/...`이며 apply-check·적용 통과. repository fixture는 28 cases(valid 14/invalid 14), Python 집중 22·전체 39, Flutter 41, analyze와 Windows release 통과. 모든 repository method의 top-level nonsense success는 schema에서 거부됨. 그러나 confirmed current의 `display_name`/`shortages`와 goal `target_level: 999`가 포함된 state response, junk student update, 빈 inventory/goals update request가 여전히 schema에서 유효함. Dart test는 `valid`를 읽지 않고 runtime client는 `repository.*` success를 무조건 허용하며 service/UI는 raw state map을 사용함. 실제 Dart↔Python restart E2E 없음
- 보완 입력 3: `docs/migration/p4-repository-persistence-followup-3/input.md`
- 보완 슬레이브 실행 프롬프트 3: `docs/migration/p4-repository-persistence-followup-3/slave-execution-prompt.md`
- 보완 출력 보고서 3: `docs/migration/handoffs/incoming/ba-planner-v7-p4-repository-persistence-followup-3/staging/20260722-161431-fa2a3481/output.md` (`BLOCKED`)
- 보완 결과물 3: 같은 staging의 `artifacts/p4-repository-persistence-followup-3.patch` 50,024 bytes, SHA-256 `79b403e7a44a175c58ad37cc95f8b503ab74c7e61a2999337710988285af4982`; `artifacts/verification.txt` 3,733 bytes, SHA-256 `14980ff4d86dd5141306ad80b527a0304777267407c4b342a890e94dfd410bed`; ZIP 12,769 bytes, SHA-256 `2d032d42a459e9e788ac7658bb45bd5f47ff61354c54035595e5d24dd2dda809`
- 보완 검증 3: ZIP 크기·SHA-256이 사용자 값, manifest와 sidecar에 일치하고 내부 artifact 2개의 크기·해시도 `output.md`와 일치함. unique staging에만 해제했고 10개 patch path가 모두 `BA Planner/v7/...`이며 기존 상태 문서 변경과 중첩 없이 `git apply --check --verbose` 및 적용 통과. repository fixture는 40 cases(valid 14/invalid 26)이며 Dart가 모든 case의 `valid`를 비교하고 Python schema·DTO contract 집중 23 및 전체 Python 40 tests가 통과함. malformed repository success fatal/restart test, typed repository state, Mock profile flow, Python 자체 child-process 재시작 복원, Flutter 전체 42 tests, Windows release, Almanac와 diff 검사가 통과함. 그러나 `flutter analyze`는 `repository_service.dart` 82·181행의 `curly_braces_in_flow_control_structures` 2건으로 실패함
- follow-up-3 차단 이력: 필수 실제 Dart `ProcessAppService` ↔ Python child-process temporary-root 종료·재시작·복원 E2E, analyzer 정리와 nested strict contract·typed state·E2E 문서 갱신이 누락됐음
- 보완 입력 4: `docs/migration/p4-repository-persistence-followup-4/input.md`
- 보완 슬레이브 실행 프롬프트 4: `docs/migration/p4-repository-persistence-followup-4/slave-execution-prompt.md`
- 마스터 직접 보완: 슬레이브 환경에 Flutter/Dart/CodeAlmanac이 없어 follow-up-4 실행이 불가능했으므로 마스터 작업트리에서 `BackendProcessConfig`의 immutable test environment override, 실제 repository process restart E2E, analyzer block 수정과 계약·저장·runtime 문서를 직접 완성함
- 최종 검증: P3/P4 집중 Python 23, 전체 Python 40, repository fixture 40 cases(valid 14/invalid 26), Flutter 전체 43, `flutter analyze`, Windows release build, `codealmanac validate`, `git diff --check` 통과. 실제 E2E는 Dart가 시작한 서로 다른 Python child process 2개를 순차 종료·실행하고 같은 temporary `BA_PLANNER_STORAGE_ROOT`에서 profile ID, display name, revision 3과 canonical goal을 typed state로 복원했으며 두 process exit code 0과 temporary root 삭제를 확인함. 금지된 v6/Qt runtime import 0건
- 슬레이브용 완료 선언: P4는 마스터 승인으로 최종 완료되었으며 follow-up-4는 재실행 대기
  작업이 아닌 이력 문서다. P5 슬레이브는 현재 작업 트리를 승인 baseline으로 사용하고,
  baseline이 다르면 P4를 수정하지 않고 `BLOCKED`로 보고한다.
- 차단 사항: 없음
- 다음 행동: P4 typed repository boundary를 유지한 채 P5 scanner/matcher session protocol을 시작
- 최종 갱신: 2026-07-22

## P5 — Scanner/Matcher session protocol과 backend

- 상태: `완료`
- 목적: v6 capture·scanner·matcher를 UI callback과 repository 저장에서 분리해 학생·인벤토리
  session, 구조화 event, 검토 가능한 candidate와 명시적 commit을 제공
- 완료 조건: 공용 Python/Dart event fixture, headless student/inventory session test, 취소·stale·낮은
  confidence 보존, 실제 adapter, recognition asset 분리와 전체 검증 통과
- 입력: `docs/migration/p5-scanner-matcher/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p5-scanner-matcher/slave-execution-prompt.md`
- 보완 입력: `docs/migration/p5-scanner-matcher-followup-1/input.md`
- 보완 슬레이브 실행 프롬프트: `docs/migration/p5-scanner-matcher-followup-1/slave-execution-prompt.md`
- 보완 수신 패키지: `docs/migration/handoffs/incoming/ba-planner-v7-p5-scanner-matcher-followup-1/ba-planner-v7-p5-scanner-matcher-followup-1-20260723-003156.zip`, 659,635 bytes, SHA-256 `dc3b04c7daae432c323e96adfdd8e5d526f3385a7da9697eb6fbef8feb59a920`
- 보완 출력 보고서: 같은 incoming 아래 `staging/20260723-003914-39a9bda9/output.md` (`COMPLETED`)
- 보완 결과물: 같은 staging의 `artifacts/p5-scanner-matcher-followup-1.patch` 924,250 bytes, SHA-256 `29faa865c125c52ca3485b98b26bb2cda3f0a10d06e50fc994e4edf7b312e005`; `artifacts/verification.txt` 4,322 bytes, SHA-256 `1438517ea731904d63fc5663aefb7ef719c55233ed1a5df923fa9fa3349e2012`
- 수신 패키지: `docs/migration/handoffs/incoming/ba-planner-v7-p5-repository-persistence/ba-planner-v7-p5-repository-persistence-20260722-222844.zip`, 17,273 bytes, SHA-256 `5ee0b0492c264d6c4ff2f542cdd8fbbe0bd4de57ce019e2b078cbedd4201d22d`
- 출력 보고서: 같은 incoming 아래 `staging/20260722-223045-00ae52e9/output.md` (`BLOCKED`)
- 결과물: 같은 staging의 `artifacts/p5-scanner-matcher.patch` 59,809 bytes, SHA-256 `8ef763d5ad294e803bfb6a2cea7a6e8b56bf2d69efd8b85a084e66a37ae291c0`; `artifacts/verification.txt` 4,188 bytes, SHA-256 `8345024909aaafc3c1ce51f3eb243e7512951beda38c8298033dab8628155f80`
- 인계 식별 오류: 외부 task ID는 `ba-planner-v7-p5-repository-persistence`, 동봉 master prompt는 P2와 `p2-planning-screen.patch`로 잘못 표기됐지만 내부 `output.md`와 artifact는 `ba-planner-v7-p5-scanner-matcher` 부분 증분이다.
- 마스터 검증: ZIP 크기·SHA-256이 사용자 값·manifest·sidecar와 일치하고 artifact 2개의
  크기·SHA-256도 `output.md`와 일치함. HEAD가 슬레이브 baseline `e0740be`와 같고 기존
  worktree 변경과 10개 patch path의 중첩이 없었으며 `git apply --check --verbose` 후 patch를
  clean 적용함. P5 집중 Python 8, 전체 Python 48, Flutter 전체 43, `flutter analyze`, Windows
  release build, `codealmanac validate`, `codealmanac health`, `git diff --check` 통과. 계획 화면
  Widget test 8개에서 current/goal 분리·빈 goal/숫자 0·총 필요량·MockAppService 흐름이
  통과했고 실제 Python stdio 8 tests와 실제 `ProcessAppService` repository restart E2E도 통과함.
- 결정 및 제약: P4 baseline을 선행 gate로 사용하고 candidate 생성과 repository 확정을 분리한다.
  event는 session ID·generation·sequence·정확히 하나의 terminal을 가지며, 낮은 confidence는
  review 없이 commit할 수 없다. 실제 student/inventory adapter 중 하나라도 placeholder이면
  완료가 아니다. UI asset과 recognition asset은 별도 manifest/path를 사용한다.
- 슬레이브 환경: Flutter/Dart SDK와 CodeAlmanac CLI 없음. Python test와 scanner backend,
  fixture·schema·asset·patch 검증은 슬레이브가 수행하고 Dart/Flutter test·analyze·release,
  실제 Dart↔Python event E2E와 Almanac 검증은 마스터 인계 후 필수 gate로 수행한다.
- 인계 차단 이력: 원본 패키지는 실제 Windows student/inventory adapter, recognition asset
  manifest, JSONL event transport와 Dart typed client 미구현으로 `BLOCKED`였고 P5 완료 조건을
  충족하지 못했다. 부분 증분 자체는 마스터가 검증·인수했다.
- follow-up-1 마스터 인수: ZIP 659,635 bytes와 SHA-256이 사용자 값·manifest·sidecar에
  일치하고, unique staging의 artifact 2개도 `output.md`의 크기·SHA-256과 일치함. baseline
  `9f533d8523dee54ca16f27c26d0b3af95668a66a`과 기존 변경 무중첩을 확인하고 40-path patch를
  `git apply --check --verbose` 후 clean 적용함.
- 마스터 직접 보완: 슬레이브가 작성한 Dart scanner source의 누락 import와 analyzer lint를
  수정하고, 실제 OS Python child process 2개를 순차 실행하는 `ProcessAppService` scanner event
  E2E 및 결정적 `MockAppService` scanner flow test를 추가함. E2E는 start response 뒤의
  phase·progress·candidate·terminal 단조 sequence, restart 후 새 session, 두 process exit code 0,
  dispose와 temporary storage 삭제를 확인함.
- 최종 검증: scanner 집중 Python 19, 전체 Python 59, Flutter 전체 47, `flutter analyze`,
  `flutter build windows --release`, `codealmanac validate`, `codealmanac health`,
  `git diff --check` 통과. 격리 wheel은 recognition manifest 1개와 production asset 16개를
  포함하고 설치된 runtime path에서 `ready=true`, missing/corrupt 0으로 해석됨. production
  student/inventory adapter, manifest 크기·SHA-256, bounded JSONL progress coalescing과
  candidate/terminal 보존을 독립 확인함.
- 결정 및 제약: production catalog는 학생 2명(`airi`, `aru`)과 inventory icon 2개의 제한된
  coverage이며 전체 catalog parity가 아니다. 실제 Blue Archive 게임 창 smoke scan은
  `NOT_VERIFIED`로 남지만 명시된 P5 완료 차단 조건은 아니다.
- 차단 사항: 없음. P5는 마스터 승인으로 완료되었고 슬레이브 follow-up 작업은 남아 있지 않다.
- 다음 행동: `docs/migration/p6-1-student-integration/slave-execution-prompt.md`를 슬레이브에 전달하고 결과 artifact를 인수·검증
- 최종 갱신: 2026-07-23

## P6-1 — 학생 실제 데이터 통합

- 상태: `완료`
- 목적: 학생 탭 placeholder를 실제 catalog·선택 프로필 repository state·scanner candidate와
  연결하고 검색·필터·정렬, 현재값 수정, 계획 탭 인계를 완성
- 완료 조건: catalog protocol, typed repository 학생 저장, service-backed StudentPage,
  계획 인계와 candidate review 경계, Python·Flutter·release·Almanac 검증 통과
- 입력: `docs/migration/p6-1-student-integration/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p6-1-student-integration/slave-execution-prompt.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p6-1-student-integration/staging/manual-20260723-015330-774c2d1a/output.md` (`COMPLETED`, 마스터 검증·인수 완료)
- 결과물: 같은 staging의 `artifacts/p6-1-student-integration.patch` 68,299 bytes,
  SHA-256 `da25a312a5f50501024f0c67d15c889ee66e591d7a925a3f996d1af875a329bc`와
  `artifacts/verification.txt` 1,934 bytes,
  SHA-256 `a780f23311210a358b0bd4e19e30d1896e6570f093d855a03c3bbe7e670a0e77`
- 수신 package: `ba-planner-v7-p6-1-student-integration-20260723-014628.zip` 18,347 bytes,
  SHA-256 `8229c01db4e992f0885e95e58acf856df6c9f857d8dc9718e883e02e33a83ccc`;
  사용자 제공값·manifest·sidecar와 일치하고 고유 staging에 독립 추출
- 검증: baseline HEAD `8f4ffd4` 일치, 기존 변경과 patch 20경로 비중첩,
  `git apply --check --verbose`와 clean 적용 통과. Python 61 tests, Windows release build,
  실제 Dart↔Python catalog·학생 저장·restart 복원 임시 acceptance E2E, 계획 draft 인계,
  candidate approve/hold, MockAppService 흐름, 1280×720·1440×900·1280×960 viewport,
  `flutter analyze`, Flutter 전체 58 tests, `codealmanac validate`, `codealmanac health`,
  `git diff --check`가 최종 통과했다. 임시 acceptance test는 실행 후 제거했다.
- 마스터 보완: deprecated dropdown 초기화를 `initialValue`로 교체하고 expanded/ellipsis로
  selection overflow를 제거했다. diagonal glass 내부에 투명 Material 경계를 추가하고,
  catalog test를 method별 request correlation으로 수정했다. candidate·off-screen action test는
  실제 scroll 동작을 사용하며 shell reachability test는 실제 StudentPage key를 확인한다.
- 결정 및 제약: P6 전체가 아닌 첫 수직 슬라이스다. scanner session 시작·진행·취소 UI는
  P6-3이 소유하며, 승인되지 않은 계획 preset protocol과 최종 반응형 layout state를
  추측하지 않는다. 현재값·정적 metadata·goal·계산·inventory shortage 경계를 유지한다.
- 차단 사항: 없음
- 다음 행동: `docs/migration/p6-2-inventory-integration/slave-execution-prompt.md`를 슬레이브에 전달
- 최종 갱신: 2026-07-23

## P6-2 — 인벤토리 실제 데이터 통합

- 상태: `완료`
- 목적: 인벤토리 탭 placeholder를 실제 catalog·선택 프로필 snapshot·저장된 plan shortage와
  scanner candidate에 연결하고 탐색·수정·부족 분석·검토 확정을 완성
- 완료 조건: inventory order parity와 catalog protocol, typed repository inventory 저장,
  gross totals와 분리된 shortage derivation, service-backed InventoryPage, candidate review 경계,
  Python·Flutter·release·실제 process E2E·Almanac 검증 통과
- 입력: `docs/migration/p6-2-inventory-integration/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p6-2-inventory-integration/slave-execution-prompt.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p6-2-inventory-integration/staging/manual-20260723-031217-6a77d237/output.md`
  (`COMPLETED`, 마스터 독립 검증 완료)
- 결과물: 수신 패키지 `ba-planner-v7-p6-2-inventory-integration-20260723-031020.zip`
  27,601 bytes, SHA-256 `480af0570516341daeebb05f210a78f8aec401da9888f9228acfc5b0d8ee328a`.
  같은 staging의 `artifacts/p6-2-inventory-integration.patch` 105,961 bytes,
  SHA-256 `86774247fc59593e5fc8d248bb7f98d64857043d73ec4f9fe5aa59c5e1275885`와
  `artifacts/verification.txt` 3,498 bytes,
  SHA-256 `bc9d476a1a8b4ae7143392e889fd23fc3669d350b181aa69e91d4e5560d87d9d`
- 검증: ZIP 사용자 제공값·manifest·sidecar와 artifact `output.md` 크기·SHA-256 일치,
  baseline HEAD `8d53673e8a0b9832725fb3cda9c9d3d415060856` 일치, 기존 사용자 변경 없음,
  29-path `git apply --check --verbose`와 적용 통과. Python 72, Flutter 65,
  `flutter analyze`, Windows release build, 실제 Dart↔Python catalog·shortage·inventory
  save/restart restore, Mock hold·approve·stale conflict, P6-1/planning 회귀,
  1280×720·1440×900·1280×960 layout, `codealmanac validate`, `codealmanac health`,
  금지 GUI/v6 runtime 참조 0건, `git diff --check` 통과
- 결정 및 제약: 기본 진입은 보유량 목록이며 부족 분석은 선택 프로필의 저장된 plan만
  대상으로 한다. snapshot 부재는 0이 아니라 unknown이고 명시적 zero-fill만 0이다.
  scanner session 시작·진행·취소 UI는 P6-3이 소유하며 전체 육성 부족·장기 pressure·추천은
  이 단계에서 구현하지 않는다.
- 마스터 보완: analyzer 중괄호 lint를 수정하고 InventoryPage widget test에 실제 Scaffold와
  lazy-list reveal을 적용했다. catalog 오류가 프로필 자동 선택에 지워지는 상태 경합을 분리했으며,
  실제 Dart↔Python catalog·명시적 0/unknown shortage·affected student 검증을 restart E2E에 추가했다.
- 전달 메모: 수신물의 `P2`/`p2-planning-screen.patch` 표기는 오래된 master prompt 문구였으나
  Task ID·manifest·output·실제 patch 29경로는 모두 P6-2로 일치했다.
  `WIRELESS_HANDOFF_RECEIVED`는 수신 디렉터리와 ZIP에 없으며 무선 전달이라는 별도 주장은 없었다.
- 차단 사항: 없음
- 다음 행동: P6-3 절의 승인된 범위와 실행 프롬프트를 사용해 슬레이브 작업 전달
- 최종 갱신: 2026-07-23

## P6-3 — 스캔 실제 UI 통합

- 상태: `완료`
- 목적: 스캔 탭 placeholder를 P5 typed scanner service에 연결하고 readiness·profile·target·kind,
  session start·phase·progress·cancel·retry·terminal과 candidate handoff 흐름을 완성
- 완료 조건: 단일 active session, cancel/terminal 분리, event gap snapshot 복구, bounded in-memory
  recent result, student/inventory candidate의 data-owner 탭 전달과 성공 commit 뒤 context 정리,
  Python·Flutter·release·실제 process E2E·Mock·viewport·Almanac 검증 통과
- 입력: `docs/migration/p6-3-scan-integration/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p6-3-scan-integration/slave-execution-prompt.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p6-3-scan-integration/staging/manual-20260723-121648-35b503de/output.md`
  (`COMPLETED`, 마스터 검증·인수 완료)
- 결과물: 수신 패키지 `ba-planner-v7-p6-3-scan-integration-20260723-121532.zip`
  (23,705 bytes, SHA-256 `2ba963e2f2b7a5ed1f816d3f3b53f8060b2064301ecb21e9f278dc2dee4d7e3b`),
  같은 staging의 `artifacts/p6-3-scan-integration.patch` (80,805 bytes,
  SHA-256 `e4bbd86b49ca9babbe8c41a29e7c5e040d68726cb1042760b28f4596b6eb4bcc`)와
  `artifacts/verification.txt` (4,470 bytes,
  SHA-256 `6f39b5373d140d90f78b1041d84b5893c312d14a60847a61d1d808e0e39fa744`)
- 검증: ZIP·manifest·sidecar·`output.md`의 크기와 SHA-256을 독립 대조했고 고유 staging에만
  해제했다. baseline `00b995d`의 깨끗한 작업 트리에서 기존 사용자 변경과 대상 경로 중첩이 없음을
  확인하고 `git apply --check` 뒤 patch를 적용했다. Python 3.11 전체 72 tests, Flutter 전체 78 tests,
  scanner 집중 16 tests, `flutter analyze`, Windows release build, 실제 Dart↔Python scanner process E2E,
  typed snapshot·event gap·cancel/retry·terminal, MockAppService, student/inventory candidate handoff와
  성공 commit 뒤 context 정리 및 hold 경계, 1280×720·1440×900·1280×960 Widget layout,
  `codealmanac validate`, `codealmanac health`, 금지 GUI/v6 runtime 참조 0건과 `git diff --check`를
  마스터에서 통과했다.
- 마스터 보정: nullable terminal payload lint, StudentPage test callback 위치, Mock cancel terminal의
  결정적 지연, offscreen/indeterminate progress Widget test와 retry timer 정리를 보정하고 실제 process
  E2E에 typed snapshot 복구 assertion을 추가했다.
- 결정 및 제약: ScanPage는 session 실행과 candidate 요약·handoff만 소유하며 repository review/commit은
  StudentPage/InventoryPage가 계속 소유한다. cancel acknowledgement만으로 terminal 처리하지 않고,
  최근 결과는 backend에 없는 영구 history를 만들지 않은 현재 앱 실행 중 bounded memory로 제한한다.
- baseline gate: P6-2 승인본은 현재 마스터 작업 트리의 미커밋 증분이므로 슬레이브가 정확한 accepted
  snapshot을 받지 못했다면 P6-1/P6-2를 재구성하지 않고 `BLOCKED`로 동일 snapshot을 요청한다.
- 인계 메모: 마스터 요청문의 P2·`p2-planning-screen.patch` 표기는 오래된 문구로 판단하고 실제
  Task ID·manifest·`output.md`·patch의 일치된 P6-3 범위를 기준으로 검증했다.
  `WIRELESS_HANDOFF_RECEIVED`는 수신 디렉터리·ZIP·현재 터미널 출력에 없었고 무선 전달이라는 별도
  주장은 없었다. 무선 전달이었다면 해당 수신 표식은 별도 운송 증빙으로 재확인이 필요하다.
- 차단 사항: 없음
- 다음 행동: 승인된 P6-3 snapshot과 P6-4 홈 통합 프롬프트를 슬레이브에 전달
- 최종 갱신: 2026-07-23

## P6-4 — 홈 실제 데이터 통합

- 상태: `완료`
- 목적: 기존 80° 홈 이미지 메뉴를 보존하면서 선택 프로필·backend, 실제 repository count,
  저장된 계획·부족 재화, 최신 scan과 검토 대기 상태를 읽는 시작 대시보드로 통합
- 완료 조건: 실제 typed source의 loading·empty·disconnected·partial error와 refresh/resume,
  profile/repository/plan/shortage/scan read model, data-owner quick action, 기존 홈 geometry와
  3개 viewport, Python·Flutter·release·실제 process E2E·Mock·Almanac 검증 통과
- 입력: `docs/migration/p6-4-home-integration/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p6-4-home-integration/slave-execution-prompt.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p6-4-home-integration/staging/20260723-151610-cb9794de/output.md`
  (`COMPLETED`, 마스터 검증·인수 완료)
- 결과물: 수신 패키지 `ba-planner-v7-p6-4-home-integration-20260723-151510.zip`
  (16,930 bytes, SHA-256 `c71c89e5b576551c6769b8216af085411d060461f605b2a46796a45401fa4283`),
  같은 staging의 `artifacts/p6-4-home-integration.patch` (48,288 bytes,
  SHA-256 `f243b7206ac45ca73db5859305a4b3116f72165c4e18078ddf7d6e7e90e352dc`)와
  `artifacts/verification.txt` (7,145 bytes,
  SHA-256 `2ae67543e492fb0e67dbc831f74674105553a5f4e5bdcbd28c7685aec691e365`)
- 검증: ZIP·manifest·sidecar·`output.md`의 크기와 SHA-256을 독립 대조하고 고유 staging에
  해제했다. HEAD `7fe68856`의 깨끗한 accepted P6-3 작업 트리와 patch 8경로의 비중첩을 확인하고
  `git apply --check --verbose` 뒤 깨끗하게 적용했다. Python 3.11 전체 72 tests, Flutter 전체
  91 tests와 홈·AppShell·scan·실제 process 집중 23 tests, `flutter analyze`, Windows release build,
  실제 Dart ProcessAppService↔Python profile/repository 저장·restart 복원·shortage E2E,
  Mock pending candidate Hold·commit 후 Home context 정리, typed recent scan handoff, refresh/race와
  partial failure, 기존 742×1018·80° home geometry/navigation, 1280×720·1440×900·1280×960 layout,
  `codealmanac validate`, `codealmanac health`, 금지 GUI/v6 runtime 참조 0건과 `git diff --check`를
  마스터에서 통과했다.
- 마스터 보정: 테스트의 Flutter foundation import와 fixture parameter를 정리하고, repository current
  envelope를 shortage API에 잘못 전달하던 결함을 Inventory/Home 공용 planning-current 변환으로 수정했다.
  실제 E2E에 confirmed student 저장을 추가했으며 홈 pending action key를 실제 button에 배치하고 lazy
  scroll test를 안정화하고 변경된 P6-4 Dart source를 formatter로 정규화했다.
- 결정 및 제약: 홈은 read model이며 repository save, plan mutation, candidate review/commit을 하지 않는다.
  inventory unknown을 0으로 만들지 않고 임시 planning draft를 저장된 plan으로 표현하지 않는다.
  최근 scan은 P6-3의 앱 실행 중 typed summary만 공유하며 backend에 없는 timestamp나 영구 history를
  만들지 않는다. P6-5~P6-7과 새 backend protocol은 범위 밖이다.
- 전달 메모: 마스터 요청문의 `P2`/`p2-planning-screen.patch` 표기는 오래된 문구였으나 실제
  Task ID·manifest·`output.md`·patch 8경로는 모두 P6-4로 일치했다. `WIRELESS_HANDOFF_RECEIVED`는
  수신 디렉터리와 현재 작업 터미널에서 확인되지 않았고 무선 전달이라는 별도 주장은 없었다.
- 차단 사항: 없음
- 다음 행동: 승인된 P6-4 snapshot과 P6-5 통계 통합 프롬프트를 슬레이브에 전달
- 최종 갱신: 2026-07-23

## P6-5 — 통계 실제 데이터 통합

- 상태: `완료`
- 목적: 통계 탭을 선택 프로필 전체의 실제 student/inventory catalog, repository current·goals,
  gross calculation과 shortage 결과에 연결하고 근거 detail에서 data-owner 탭으로 이동
- 완료 조건: 학생·인벤토리·계획 3 mode, 고정 KPI/분포와 pure typed projection,
  missing·unknown·zero·분모·gross/shortage 의미 보존, loading·empty·disconnected·partial error와
  refresh/re-entry, Python·Flutter·release·실제 process E2E·Mock·3 viewport·Almanac 검증 통과
- 입력: `docs/migration/p6-5-statistics-integration/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p6-5-statistics-integration/slave-execution-prompt.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p6-5-statistics-integration/staging/20260723-164735-0b236e6c/output.md`
  (`COMPLETED`, 마스터 독립 검증 완료)
- 결과물: 수신 패키지 `ba-planner-v7-p6-5-statistics-integration-20260723-164645.zip`
  (16,888 bytes, SHA-256 `8c377b4d6e2f9ac935e0e7f4649ecf85a1fb1fc07ddd7d158790aa8022a772d5`),
  같은 staging의 patch와 verification artifact
- 결정 및 제약: v6 통계는 StudentPage filtered set을 사용했지만 v7에는 filter 공유 계약이 없으므로
  P6-5 범위는 선택 프로필 전체로 고정한다. StudentPage filter handoff, 새 chart dependency,
  statistics protocol/storage/history를 만들지 않는다. 통계는 read-only이며 학생 current·metadata·goal,
  gross result와 inventory shortage bucket을 섞거나 mutation하지 않는다.
- 마스터 검증: package/manifest/output artifact의 크기와 SHA-256을 독립 확인하고 고유 staging에서만
  추출했다. accepted P6-4 baseline과 clean worktree를 확인한 뒤 7-path patch에 `git apply --check`를
  선행하고 적용했다. Python 72개, Flutter 전체 106개와 P6-5 집중 16개, `flutter analyze`, Windows
  release build, 실제 Dart↔Python catalog/repository/gross/shortage process E2E, MockAppService,
  1280×720·1440×900·1280×960 Widget layout, `codealmanac validate`·`health`, `git diff --check`를 통과했다.
- 마스터 보정: Widget test의 `ValueListenable` import, private test helper, lazy-scroll navigation과
  stable identity assertion을 정리했다. 인벤토리 snapshot 부재를 null 수량과 분리해 `absent`로
  집계하고 category known coverage의 분모를 catalog로 고정했으며, 범위 밖 학생 level/star가
  known-only 평균과 고정 bucket에 섞이지 않도록 pure projection과 회귀 test를 보강했다.
- 전달 메모: 마스터 요청문의 `P2`/`p2-planning-screen.patch` 표기는 오래된 문구였으나 실제
  Task ID·manifest·`output.md`·patch 7경로는 모두 P6-5로 일치했다. `WIRELESS_HANDOFF_RECEIVED`는
  수신 디렉터리와 현재 작업 터미널에서 확인되지 않았고 무선 전달이라는 별도 주장은 없었다.
- 선행 조건: P6-4 완료
- 차단 사항: 없음
- 다음 행동: 승인된 P6-6 snapshot을 기준으로 P6-7 설정 및 통합 오류 처리 프롬프트 작성
- 최종 갱신: 2026-07-23

## P6-6 — 전술대항전 실제 데이터 통합

- 상태: `완료`
- 목적: 실제 학생 ID 기반 4 Striker+2 Special 공격·방어 편성, 프로필별 전적·메모·수동
  족보 저장·복원과 검색·필터·재사용 통합
- 완료 조건: strict tactical contract/fixture, profile-scoped atomic persistence와 revision/idempotency,
  실제 Dart↔Python restart E2E, Mock, P6-1~P6-5 회귀, 3 viewport, release와 Almanac 검증 통과
- 입력: `docs/migration/p6-6-tactical-integration/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p6-6-tactical-integration/slave-execution-prompt.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p6-6-tactical-integration/staging/20260723-184006-136eea9c/output.md`
  (`COMPLETED`, 마스터 독립 검증 완료)
- 결과물: 수신 패키지 `ba-planner-v7-p6-6-tactical-integration-20260723-183844.zip`
  (22,658 bytes, SHA-256 `4e3226cb73cf05b8eb17196b6306541567385388ea88f3cf9e541ab54a174492`),
  같은 staging의 patch와 verification artifact
- 결정 및 제약: P6-6은 수동 match/jokbo 기본 기능만 소유한다. 로비 scan, 상대 identity/history,
  provenance, 전술 통계, 변경 감지, 예상 방어덱·추천·공유는 P7~P13에 남긴다. canonical student ID와
  fixed 4+2 slot 순서를 저장하며 v6 Qt/QML/PySide/SQLite facade를 복사하거나 runtime import하지 않는다.
- 마스터 검증: package/manifest/output artifact의 크기와 SHA-256을 독립 확인하고 고유 staging에서만
  추출했다. accepted P6-5 `e58281e`와 clean worktree를 확인하고 17-path patch에 `git apply --check`를
  선행한 뒤 적용했다. Python 79개, Flutter 전체 121개와 P6-6 집중 15개, `flutter analyze`, Windows
  release build, 실제 Dart↔Python tactical save→restart→restore, Mock CRUD/revision, strict schema/fixture,
  atomic failure·profile isolation·candidate Hold/Approve 회귀, 세 viewport의 empty/populated layout,
  `codealmanac validate`·`health`, `git diff --check`를 통과했다.
- 마스터 보정: 슬레이브 미실행 Dart source의 괄호/import 오류와 analyzer lint를 수정했다. Mock catalog의
  combat class 대소문자 때문에 own-deck 후보가 사라지던 문제를 정규화하고, 족보 복사가 가짜 상대·승리
  기록을 즉시 저장하지 않고 새 편집 draft를 열도록 수정했다. 날짜 범위 filter, profile/revision과 실제 덱
  evidence 표시, canonical record/profile/error strict Dart 검증, Mock CRUD/revision 및 copy-before-save와
  긴 데이터 세 viewport 회귀 test를 보강했다.
- 전달 메모: 마스터 요청문의 `P2`/`p2-planning-screen.patch` 표기는 오래된 문구였으나 실제 Task ID,
  manifest, `output.md`와 patch 17경로는 모두 P6-6으로 일치했다. 송신 보고서에는 wireless wrapper와
  `CROSS_PC_HANDOFF_READY`가 있으나 master 측 `WIRELESS_HANDOFF_RECEIVED` 터미널 출력은 보존되지 않았다.
  수신 ZIP은 master에서 사용자 값·manifest와 독립적으로 동일 byte/hash임을 확인했다.
- 선행 조건: P6-5 완료
- 차단 사항: 없음
- 다음 행동: accepted P6-6 snapshot과 P6-7 설정 및 통합 오류 처리 프롬프트를 슬레이브에 전달
- 최종 갱신: 2026-07-23

## P6-7 — 설정 및 통합 오류 처리

- 상태: `완료`
- 목적: 설정 탭을 실제 profile·backend·scanner·진단 source에 연결하고 전 탭 공통 오류·복구 흐름을
  통합한 뒤 P6 전체 독립 검증을 준비
- 완료 조건: profile 생성·선택·이름 변경, reconnect/restart, secret-safe diagnostics, Scan·Adaptive-Sync
  진입, 전 탭 reload/stale 보호와 스캔 → 현재 상태 검토 → 목표 설정 → 총 필요량 → 부족량 → 저장·복원
  통합 흐름이 실제 process·Mock·3 viewport·release·Almanac gate를 모두 통과
- 입력: `docs/migration/p6-7-settings-error-integration/input.md`
- 슬레이브 실행 프롬프트: `docs/migration/p6-7-settings-error-integration/slave-execution-prompt.md`
- 출력 보고서: `docs/migration/handoffs/incoming/ba-planner-v7-p6-7-settings-error-integration/staging/master-verify-20260723-200655-009bf168/output.md`
- 결과물: 같은 staging의 `artifacts/p6-7-settings-error-integration.patch`, `artifacts/verification.txt`
- 수신 패키지: `ba-planner-v7-p6-7-settings-error-integration-20260723-200126.zip`, 17,803 bytes,
  SHA-256 `1754b4a55ca8e9d7b7bce9995ba73d4016c9234d11595692fd74517ed81bc095`
- 인계 검증: manifest·sidecar·사용자 제공 byte/hash가 일치하고 새 고유 staging에 독립 추출했다.
  `output.md`의 patch 63,263 bytes/SHA-256 `ed090da2a33d59459f729d84db0e0f9afbf9871ccb1fa39bd09be424d5983370`,
  verification 4,106 bytes/SHA-256 `27e50cc43180ac581651b1b21439b37d37647ac52e586da4a5f9a8d86fbdb7ee`가
  실제 artifact와 일치했다. 보존된 `WIRELESS_HANDOFF_RECEIVED` 터미널 출력은 없지만 수신 ZIP을
  마스터가 다시 검증했으며 무선 전송 자체를 구현 검증으로 간주하지 않았다.
- patch 인수: baseline `4225ab3`, clean worktree와 11개 frontend path의 무중첩을 확인하고 저장소
  루트에서 `git apply --check --verbose`를 통과한 뒤 적용했다. 요청문의 `P2`와
  `p2-planning-screen.patch`는 오래된 템플릿 문구이며 Task ID·manifest·output·실제 patch는 P6-7로 일치했다.
- 마스터 보완: callback 반환 누락과 화면 밖 deep-link test를 수정하고, 설정 primary-tab 회귀를 갱신했다.
  launcher executable/args/working-directory까지 token/password/secret/authorization/Bearer를 제거하도록
  진단 경계를 강화했다. 실제 scanner fixture를 사용한 최종 process E2E와 동일 Mock 흐름을 추가해 Hold
  불변, Approve commit, current/inventory/goal/gross/shortage/tactical, profile 격리와 restart 복원을 검증했다.
- 독립 검증: Python 79개, Flutter 136개, P6-7 변경 13경로 Dart format, `flutter analyze`,
  `flutter build windows --release`, 1280×720·1440×900·1280×960 populated/disconnected/long-text layout,
  `codealmanac validate`, `codealmanac health`, 금지 GUI/v6 runtime import 0건과 `git diff --check` 통과.
- 결정 및 제한: profile 삭제·backup/import, 새 settings 저장소, 설정에서 scan 시작·target persistence,
  P7+ 기능은 제외한다. reconnect/restart는 draft/candidate를 자동 commit·삭제하지 않는다. 실제 Blue
  Archive 게임 창 smoke는 수행하지 않았고 fixture/Mock 결과를 실제 게임 검증으로 표현하지 않는다.
- 선행 조건: accepted P6-1~P6-6이 포함된 baseline `4225ab3` 확인
- 차단 사항: 없음
- 다음 행동: P0~P6 workflow 완료 상태를 유지하고 명시적 승인 전 P7을 시작하지 않음
- 최종 갱신: 2026-07-23

최종 갱신: 2026-07-23

## 단계별 기록 양식

단계 정의 또는 상태가 확인되면 아래 항목을 해당 단계 섹션으로 추가한다.

```markdown
## P<n> — <단계명>

- 상태: `<상태 값>`
- 목적: `<이 단계가 달성할 결과>`
- 완료 조건: `<마스터가 검증할 조건>`
- 입력: `<input.md 절대경로 또는 저장소 상대경로>`
- 출력 보고서: `<output.md 경로>`
- 결과물: `<artifacts/ 경로와 주요 파일>`
- 검증: `<마스터가 실행하거나 확인한 내용>`
- 결정 및 제약: `<유지해야 할 판단>`
- 차단 사항: `<없음 또는 구체적인 원인>`
- 다음 행동: `<다음 대화에서 바로 수행할 일>`
- 최종 갱신: `<YYYY-MM-DD>`
```

## 대화 간 인계 절차

1. 새 대화에서 이 문서와 현재 대상 단계의 `input.md`를 읽는다.
2. `다음 행동`과 실제 작업 트리·산출물의 상태가 일치하는지 확인한다.
3. 슬레이브 명령에는 [Slave Artifact Handoff](slave-artifact-handoff)의 인계 계약을
   포함한다.
4. 결과를 받은 마스터는 `output.md`와 결과물을 직접 확인한다.
5. 검증 결과, 새 결정과 다음 행동을 이 문서에 기록한 뒤 대화를 마친다.

## P6 이후 학생 탭 Section 토대

- 상태: `현행 계약 구현 및 검증 완료`
- 목적: 학생 탭의 Studio Section 1~4, 행동 버튼, 사선 학생 grid, 선택 학생 indicator 토대를 실제 Flutter 화면에 적용
- 산출물: `frontend/lib/ui/studio/student_studio_layout.dart`,
  `frontend/lib/ui/widgets/student_section_layout.dart`, `frontend/lib/ui/pages/student_page.dart`,
  `frontend/test/student_studio_layout_test.dart`
- 결정 및 제약: Section 1 버튼 세 개는 Section inset·gap에서 같은 크기를 유도하고 기존 색의 삼각형
  texture를 적용한다. Section 1·2의 80° 빗면 간격은 12 px로 고정한다. Section 1~4에는 shadow만 있고
  Section outline은 없다. Section 2는 Container 12 하나 안의 8열 direct-painted portrait grid이며
  265명 bundled catalog를 전부 표시한다. Section 3의 Container 1·3은 surface 없는 placeholder이고
  portrait·성작·Container 5·6·7·9는 공통 좌측 80° rail, Container 5·6·7·9는 공통 우측 rail에 맞춘다.
  Section 4 검색 높이는 Studio 제안의 절반으로 줄였다. 상단 repository profile selector는 제거하고
  선택 profile을 service에서 자동 복원한다. Section 4의 표시·미보유·JP 전용 checkbox와 Section 5의
  catalog filter는 구현됐으며, Section 3 세부 text와 Container 4~7·9·10의 실제 indicator 내용만
  후속 범위다. 기존 repository 편집 Section은 제거하고 scanner candidate 검토 flow만 canvas 아래에
  조건부로 유지한다.
- 검증: `flutter analyze --no-pub` 통과, 학생 layout 7개·학생 페이지 9개 집중 test 통과,
  전체 Flutter 189개 test 통과, Windows release build 통과, 265명 catalog generator 재실행 및
  Python compile 통과, `codealmanac validate`, `codealmanac health`, `git diff --check` 통과
- 2026-07-27 후속 보정: 학생 grid의 외곽 8 px inset은 유지하고 양축 cell gap을 4.8 px로 줄여
  셀 이미지를 100%/98%로 확대했다. 80° custom scrollbar와 14 px 전용 폭을 grid 산식에 포함했고,
  성작 bar·scroll track의 80°를 수치 검증한다. Container 5·6·7·9의 세로 gap과 Container 4까지의
  법선 gap을 같은 값으로 맞추고, Section 1 버튼 폭은 오른쪽 80° 경계 inset에서 행별 역산한다.
  검색 입력을 수직 중앙에 놓고 Section 4 윗변 inset을 0.18→0.09로 줄였으며 세 행동 버튼에만
  연핑크 삼각 texture를 적용했다. 학생 layout 10개·학생 페이지 9개 집중 test와 analyze가 통과했다.
- 2026-07-27 추가 보정: Section 4의 오른쪽 끝은 유지하고 왼쪽 길이를 조정해 Section 3 왼쪽과 같은
  80° 직선에 맞췄다. Section 1 버튼의 빗면 법선 여백은 왼쪽 직선면 여백 이상이며 아이콘은 명시적
  중앙 정렬을 사용한다. 네 Section의 기본 alpha는 0.76으로 검증하고 canvas 아래 legacy repository
  editor Section을 제거했다. 학생 grid 행 gap은 4.8의 80%인 3.84 px, scrollbar handle은 pink로
  변경했다. full mock catalog의 아루·아야네 영문 override를 제거해 한국어 이름 정렬에 포함했다.
- 2026-07-27 motion/effect 보정: Section 1 아이콘은 사다리꼴 중간 Y의 실제 수평 선분 중앙에서
  계산한다. Container 12·2·4는 5·6·7·9와 같은 status texture, Container 10은 Section 1과 같은 action
  texture를 사용한다. Filter 버튼은 Section 2를 퇴장시킨 뒤 Section 5를 등장시키며
  역전환도 지원한다. motion은 Section 1=0/180, Section 2·5=80/260, Section 3·4=180/0으로 고정했다.
  분리된 foundation layer는 IgnorePointer로 grid hit test를 보존한다.
- 2026-07-27 학생 card/filter 보정: Container 4의 action texture를 원래 status texture로 되돌리고
  Container 10에 action texture를 적용했다. 학생 grid는 `square.png` alpha 내부의 하단 16%만
  overlay로 사용하며, 상단 3%에 v6 공격/방어 색상 띠를 좌우로 나누고 남은 13% 회색 반투명 영역에
  흰색 학생 이름을 표시한다. Section 4의 두 checkbox로 속성 띠와 이름을 각각 토글한다. Section 5는
  높이와 왼쪽 80° rail을 유지하며 후속 보정에서 양쪽 수평변을 Section 2의 50%로 줄였다.
- 2026-07-27 학생 card/filter 후속 보정: card 정보 영역을 하단 16%로 확대하고 상단 3% 속성 띠와
  나머지 13% 이름 영역으로 나눴다. Filter→목록 복귀 시 행동 버튼 아이콘은 학생 탭의
  `groups_2_outlined`로 전환한다. Section 5는 윗변·밑변을 모두 Section 2의 50%로 줄여 평행사변형을
  유지하고 내부 Container도 축소 path에 맞췄다. Section 4에는 미보유 학생·일본 서버 전용 숨김
  checkbox를 추가했으며, `jp_only`를 backend metadata, catalog protocol/schema/fixture, Flutter DTO와
  265명 mock asset에 이관했다.
- 2026-07-27 학생 Section 회고 문서화: 최초 토대·초기 해석과 반복 피드백 뒤 확정된 geometry,
  texture, placeholder, grid, card overlay, filter, data, motion 계약의 차이를
  `almanac/design/section-template-studio.md`에 비교표로 남겼다. 유사 Section을 새로 만들거나 기존
  Section과 유사하다고 판단할 때 범위·형상·효과·반응형·데이터·상호작용을 확인할 22개 질문과
  질문 순서·재질문 방지 원칙도 함께 기록했다.
- 2026-07-27 Section 사전 협의 절차 보강: 독립 요구가 많은 Section 작업은 geometry, container,
  effect, data/filter, motion 단위의 분리안을 먼저 제안하고 그 순서로 진행해도 되는지 사용자 승인을
  받도록 했다. 유사 Section 후보가 있으면 추상적으로 유사 여부만 묻지 않고 기존 Section에서 그대로
  참고할 속성, 다르게 만들 속성, 미정인 속성을 명시하는 질문 형식과 기존 widget 호출·형상 복제의
  구분 질문을 `almanac/design/section-template-studio.md`에 추가했다.
- 2026-07-27 학생 이름/정렬 보정: 학생 카드 이름 글꼴을 4~8px에서 6~12px로 1.5배 확대하고
  이름 영역 높이의 80%를 목표값으로 유지했다. Section 1에는 검색 입력과 같은 실제 높이, action과
  같은 inset·gap·80° 형상 계산을 쓰는 정렬 드롭다운을 추가했다. 닫힌 control은 투명 바탕에
  1px 연핑크 사다리꼴 테두리·연핑크 축약 text·연핑크 하향 삼각형만 표시한다. 이름·LV·성작·인연
  랭크의 오름/내림차순을 지원하며, 결측값은 방향과 관계없이 뒤로 보내고 이름순 tie-break를
  적용한다. 인연 랭크는 protocol 미구현 동안 이름순 fallback이다. 학생 집중 26개와 Flutter 전체
  198개 test, `flutter analyze`, Windows release build를 통과했다.
- 2026-07-28 학생 정렬 control 위치 보정: Section 1의 정렬 드롭다운을 최상단으로 이동하고,
  계획·스캔·필터 action을 그 아래 기존 순서로 배치했다. 검색 입력과 같은 높이, 공통 세로 gap,
  Section 상대 inset과 오른쪽 80° 경계 역산 규칙은 유지한다.
- 2026-07-28 학생 control text 보정: 정렬 드롭다운의 닫힌 label을 10→15px, 펼친 menu label을
  12→18px로 확대했다. Section 4의 네 checkbox label도 11→16.5px로 1.5배 확대하되 기존 control
  높이·간격과 한 줄 ellipsis는 유지한다.
- 2026-07-28 학생 motion 실행 계약 보정: Section 1은 0° intro/180° outro, Section 3·4는
  180° intro/0° outro의 독립 `SectionMotionSpec`을 사용한다. 공용 motion widget이 intro 값만으로
  reverse 궤적을 추론하지 않고 forward에는 intro, reverse에는 outro 벡터를 직접 적용하도록 했다.
  학생 집중 28개와 Flutter 전체 200개 test, `flutter analyze`, Windows release build를 통과했다.
- 2026-07-28 학생 탭 호출 lifecycle 보정: AppShell의 공용 90°/270° 페이지 translation이 학생
  Section별 motion과 합성되던 것이 일괄 호출처럼 보이던 원인이었다. 학생 페이지 index는 공용
  translation에서 제외하고, 이전 탭 퇴장 완료 callback에서 `StudentPage.active`를 켜 Section 1~4를
  각자의 intro로 호출한다. 학생 탭을 떠날 때는 `active`를 먼저 끄고 각 controller를 reverse하여
  독립 outro를 실행한다. 페이지 instance와 학생 선택·filter 상태의 기존 보존 방식은 유지한다.
  관련 집중 44개와 Flutter 전체 200개 test, `flutter analyze`, Windows release build를 통과했다.
- 2026-07-28 almanac 정합성 정리: 날짜별 이력보다 design 문서의 현행 계약과 runtime·회귀 test를
  우선하도록 판정 순서를 명시했다. 초기 요약에 남아 있던 Section 4·5 filter 미구현 표기와
  repository 편집 Section 유지 표기를 현재 구현에 맞게 정정하고, 페이지 전체 motion과 내부
  Section motion을 분리하는 탭 호출 lifecycle을 회고 비교표에도 추가했다.
- 다음 행동: Section 3의 텍스트·세부 상태 indicator와 Container 4~7·9·10의 실제 데이터를
  사용자 승인 디자인으로 채운다. 계획 버튼의 최종 계획 탭 연결 범위는 별도로 확정한다.
- 최종 갱신: 2026-07-28

## P6 이후 학생 Section 5 필터와 Section 2 viewport 후속 보정

- 상태: `완료`
- 목적: 학생 Section 5에 실제 v6 계열 filter group/list/check box를 배치하고 Section 2·5의
  scroll content가 container 크기를 바꾸지 않도록 고정 viewport와 상하 fog를 적용한다.
- 산출물: `frontend/lib/ui/widgets/student_section_layout.dart`,
  `frontend/test/student_studio_layout_test.dart`, `almanac/design/section-template-studio.md`
- 결정 및 제약: 현재 v7 catalog protocol에 존재하는 학교·초기 성급·공격/방어 타입·편성·역할·
  포지션만 v6 명칭과 값 mapping으로 노출한다. 선택은 같은 group OR/서로 다른 group AND이며
  Section 2 복귀 후에도 유지하고 별도 초기화 action으로만 제거한다. 성장·스킬 metadata는
  protocol 확장 전까지 표시하지 않는다.
- 검증: Flutter 전체 199개, 학생 layout 집중 test 27개, 학생 page test 9개,
  `flutter analyze --no-pub`, Windows release build 통과.
  1280x720·1440x900·1280x960 overflow 검증과 filter 유지·초기화·경계·fog test를 포함한다.
- 차단 사항: 없음
- 다음 행동: 전체 Flutter test와 Almanac/diff gate를 유지한다.
- 최종 갱신: 2026-07-28
- 2026-07-27 실화면 재검수: container를 부모 path와 강제 교차해 외부를 숨기던 계산을 제거하고,
  부모 Section의 위·아래 실제 80도 경계에서 10px 안쪽 polygon을 직접 계산했다. filter group은
  중심 Y와 자체 사선 깊이의 이중 이동을 밑변 Y 기반 단일 이동으로 바꾸고, 전체 사선 깊이를
  포함한 좌우 content-safe inset을 적용했다. Windows 1280x720과 최대화 화면에서 최초·중간 scroll
  위치를 직접 검수했으며 잘린 `학교` 제목, clipped corner와 행 궤적을 확인·보정했다.
## 2026-07-27 학생 Section viewport 실화면 재검수

- 첨부 화면에서 `StudentPage`가 상하 16px padding을 적용하면서도 내부
  `StudentSectionLayout` 높이에 차감 전 `constraints.maxHeight`를 사용해 Section 2·5 하단과
  필터 초기화 버튼이 viewport 아래로 총 32px 밀리는 원인을 확인했다.
- canvas 높이를 `max(590, maxHeight - padding.vertical)`로 고치고
  1280x720·1440x900·1280x960 page test에서 실제 `StudentSectionLayout` 높이를 검증한다.
- 추가 크기 역추적에서 필터 전용 paint 분기 이후의 공통 runtime container loop가 기존
  `container-12`를 원래 Section 2 크기로 다시 칠하는 것을 확인했다. 필터 모드에서는
  `element-2`의 legacy container/feature를 제외하고, 새 Section 5 container와 reset surface만
  그리도록 수정했다. 최대화 Windows release에서 중복 면·윤곽 제거를 직접 확인했다.
- Section 2·5의 고정 상·하 fog를 공통 `_StudentDiagonalScrollbar`의 `ScrollPosition` 기반
  overlay로 교체했다. scroll range가 없으면 양쪽을 숨기고, 최상단은 위쪽, 최하단은 아래쪽을
  숨기며 중간에서만 양쪽을 표시한다. 최대화 Windows release의 Section 2 최상단에서 위 fog
  제거를 확인하고, 무스크롤·최상단·중간·최하단 네 상태를 집중 test로 고정했다.
- 2026-07-28 Section 5의 높이가 서로 다른 filter group row에 같은 폭을 적용해 우측 사선
  끝점이 어긋나던 문제를 수정했다. row 높이에 따른 자체 사선 깊이를 폭 산식에 포함하여
  위·아래 우측 끝점이 하나의 80도 rail에 놓이게 했고, scroll offset이 있는 경우까지 수치
  test로 고정했다. Flutter 전체 199개와 학생 layout 27개·page 9개 집중 test,
  `flutter analyze --no-pub`, Windows release build를 통과했다.

## P6 이후 계획 탭 본문 초기화

- 상태: `완료`
- 목적: 계획 탭의 새 구성을 시작할 수 있도록 기존 헤더 아래의 학생 조회·빈 상태·학생 카드·
  계산·결과 섹션을 모두 제거한다.
- 산출물: `frontend/lib/ui/pages/planning_page.dart`,
  `frontend/test/planning_page_test.dart`
- 결정 및 제약: 여기서 헤더는 `AppShell`이 제공하는 상위 탭 헤더를 뜻한다. 계획 페이지
  내부에 있던 공용 프로필 패널과 `성장 계획` 카드도 하위 섹션으로 보아 함께 제거하고,
  본문은 빈 canvas만 유지한다. 학생 탭이 사용하는 `PlanningStudentSeed` 전달 계약은
  유지하되, 새 계획 본문이 정해지기 전까지 계획 탭에서 seed를 표시하거나 처리하지 않는다.
  기존 planning backend와 repository 계약은 변경하지 않는다.
- 검증: `flutter analyze --no-pub`, 계획 탭 집중 Widget test와 Flutter 전체 192개,
  `git diff --check` 통과.
- 차단 사항: 없음
- 다음 행동: 사용자 기획에 맞춰 계획 헤더 아래의 새 섹션을 순서대로 구성한다.
- 최종 갱신: 2026-07-28

## P6 이후 계획 탭 Section 1~4 초기 배치

- 상태: `초기 구현 완료`
- 목적: `release/section-plan-main.ba-section-studio.json`을 시작점으로 계획 탭에 내용이
  비어 있는 Section 4개를 배치하고, 사용자 실화면 검수 전에 motion과 shadow 계약을 고정한다.
- 산출물: `frontend/lib/ui/studio/plan_studio_layout.dart`,
  `frontend/lib/ui/widgets/plan_section_layout.dart`,
  `frontend/lib/ui/pages/planning_page.dart`, `frontend/lib/ui/app_shell.dart`,
  `frontend/test/planning_page_test.dart`, `almanac/design/section-template-studio.md`
- 결정 및 제약: JSON의 96×96 좌표와 shape를 그대로 초기 투영한다. Section 1은
  `0°/180°`, Section 2·3은 `80°/260°`, Section 4는 `180°/0°`의 intro/outro를 사용한다.
  네 Section 모두 최종 path에 공용 lifted shadow를 한 번씩 적용하고, 아직 내부 콘텐츠는
  추가하지 않는다. 계획 탭은 페이지 전체 motion 대신 Section별 motion을 사용한다.
- 검증: `flutter analyze --no-pub`, 계획 탭 집중 test 3개, Flutter 전체 194개,
  Windows release build 통과.
- 차단 사항: 없음
- 다음 행동: 사용자가 갱신된 Windows release에서 초기 배치를 확인한 뒤 Section별 크기를
  세부 조절한다.
- 최종 갱신: 2026-07-28
- 2026-07-28 밝기 보정: 실화면 비교에서 계획 페이지 전용 `AppColors.canvas` 72% fill이
  AppShell 공용 BA 배경과 Section surface 사이에 추가 합성되어 탭 전체를 어둡게 만드는 것을
  확인했다. 전용 fill을 제거하고 투명 host로 교체했으며 Section 색·alpha·그림자·motion은
  유지했다. 집중 test 3개와 Flutter 전체 194개, `flutter analyze --no-pub`를 통과했고
  실행 중 release를 종료한 뒤 Windows release bundle을 갱신했다.
- 2026-07-28 Section 2 페이즈 표시 토대: 계획은 공통 페이즈, 시나리오는 계산에서 분리된
  개별 페이즈를 가진다는 경계를 기록했다. Section 2 안에 80° 내부 texture Container,
  80° 궤적을 따르는 페이즈 카드와 scrollbar를 추가하고, 페이즈 내부 순서를 가진 학생 단계
  더미를 배치했다. 시로코 1·2·3단계가 페이즈 1·2·3에 순서대로 나타나며 기존 v6 이관 portrait
  asset을 사용한다. 편집 기능과 Section 1 메뉴·Section 3 재화 탭은 후속 Studio 배치 이후로
  남긴다. 계획 탭 집중 test 5개, Flutter 전체 196개, `flutter analyze --no-pub`, Windows
  release build를 통과했고 1280×720 실화면에서 초기·scroll 위치의 clipping과 80° rail을
  검수했다.
## 2026-07-28 계획 단계 공용 DiagonalMediaListItem

- 상태: `구현 및 전체 검증 완료`
- 목적: Studio JSON으로 만든 단계 아이템을 계획·스캔 결과에서 재사용 가능한
  중립 컴포넌트로 만들고 계획 탭의 기존 간이 타일을 즉시 교체한다.
- 산출물: `release/component-diagonal-media-list-item1.ba-section-studio.json`,
  `frontend/lib/ui/widgets/diagonal_media_list_item.dart`,
  `frontend/lib/ui/widgets/plan_section_layout.dart`,
  `frontend/assets/equipment_icons/`,
  `frontend/test/diagonal_media_list_item_test.dart`
- 결정 및 제약: 도형 4와 17은 배치 앵커로만 유지하며 각각 5+4 성작 표시와
  1~100 하트 랭크로 렌더링한다. 값 변화는 `5(▲2)`/`5(▼2)` 형식과
  초록/빨강을 사용한다. v6 장비 이미지는 scanner template을 runtime에서
  참조하지 않고 필요한 세 파일만 v7 UI asset으로 분리 복제했다.
- 검증: 세 중심선 그룹의 정규화 좌표, delta 색상, 하트·성작 semantics,
  계획 단계 전체 교체와 기존 사선 스크롤 집중 Widget test 통과.
  `flutter analyze --no-pub`, 전체 Flutter 198개 test, Windows release build,
  release bundle 동기화, `codealmanac validate`, `codealmanac health`,
  `git diff --check`를 통과했다.
- 다음 행동: 다시 실행한 최신 release 화면을 기준으로 섹션별 크기를 세부 조절한다.
- 최종 갱신: 2026-07-28

### 2026-07-28 아이템 높이·인연 배경·페이즈 흐름 후속 조정

- 상태: `구현 및 전체 검증 완료`
- 변경: 계획 아이템을 54px로 높이고 58px 행 단위로 배치했다. 각 행은 페이즈
  평행사변형의 현재 Y 좌우 경계를 직접 계산해 부모 사선과 평행하게 맞춘다.
  성작 바 높이 비율 0.22는 유지하고 장비 아이콘과 하트 높이·폭을 확대했다.
- 이미지: 학생 portrait 앞에는 98% 크기를 적용하고 뒤에는 인연 랭크별
  `square.png`를 둔다. 1~19 기본, 20~49 파랑, 50~99 노랑, 100 보라 규칙을
  학생 목록·포커스, 계획 아이템, 통계 학생 근거 행에서 공유한다.
- 데이터: confirmed student repository DTO와 schema에 1~100 `bond_rank`를
  추가하되 planning 계산 입력에는 전달하지 않아 기존 계산 계약을 유지한다.
- 흐름: 페이즈 사이 20px 간격에 아래 방향 삼각형을 배치한다.
- 검증: 관련 Flutter 46개 집중 test와 전체 Flutter 200개 test,
  `flutter analyze --no-pub`, 전체 Python 80개 test, Windows release build 및
  release bundle 동기화를 통과했다. 최신 Windows release에서 학생 이미지 무잘림,
  행/부모 사선 정렬, 페이즈 화살표, 하트 비율을 직접 확인했다.
- 다음 행동: 사용자 화면 검수 결과에 따라 세부 크기만 추가 조절한다.

### 2026-07-28 계획 아이템 밀도 및 인연 하트 후속 조정

- 상태: `구현 및 실화면 검증 완료`
- 변경: 계획 페이즈 아이템 높이를 54px에서 65px로 약 20% 확대하고, 행 간격을
  유지하도록 item extent를 69px로 조정했다. Studio 원본 섹션 높이도 20에서
  24로 맞췄다.
- 장비: 세 장비 아이콘 모두 `square.png`를 배경으로 사용하고 실제 장비 이미지는
  배경의 98% 크기로 겹쳐 그린다.
- 인연 하트: 참고 이미지의 넓은 연분홍 하트, 진분홍 외곽선, 짙은 숫자 스타일을
  반영했다. 하트 자체는 1.28:1 비율로 고정해 부모 폭에 따라 납작해지지 않으며,
  delta가 없어도 동일한 배치 공간을 유지한다.
- 검증: 관련 Widget test 11개, `flutter analyze --no-pub`, Windows release
  build를 통과했다. 최신 Windows 빌드의 계획 탭에서 사선 행 정렬, 장비 배경,
  하트 숫자와 페이즈 사이 흐름 표시를 확인했다.
- 다음 행동: 사용자의 실화면 판단에 따라 개별 텍스트와 아이콘 간격을 세부
  조정한다.

### 2026-07-28 계획 아이템 정보 열 재배치

- 상태: `구현 및 실화면 검증 완료`
- 인연: 하트를 아이템 우측 끝으로 이동하고 인연 상승치를 하트 바로 아래에
  독립된 줄로 배치했다.
- 하단 정보: 애장품 영역 폭을 확대해 `T2(▲1)`처럼 상승치가 포함되어도 본문이
  과도하게 축소되지 않게 했다. 각 장비 `square.png`와 티어 텍스트 사이에는
  0.008 이상의 정규화 간격을 둔다.
- 강조: 스킬은 학생 레벨과 첫 장비 사이에 유지하면서 기본 9.5px의 1.5배인
  14.25px로 키웠다.
- 성작: indicator 높이를 0.22에서 0.154로 30% 줄이고 기존 중심선을 유지했다.
- 검증: 관련 Widget test 11개와 `flutter analyze --no-pub`, Windows release
  build 및 실화면 검수를 통과했다. 정식 release bundle을 동기화했다.

### 2026-07-28 다중 값 변동 행 및 장비 레벨 추가

- 상태: `구현 및 실화면 검증 완료`
- 인연: 하트를 우측 끝에서 정보 영역 중앙 쪽으로 되돌리고 상승치는 하단 행에
  유지했다. 하트 내부 숫자는 10.5px에서 15.75px로 1.5배 확대해 100도 배지
  경계를 약간 사용할 수 있게 했다.
- 장비 데이터: 각 장비가 티어와 장비 레벨을 별도로 갖도록
  `DiagonalMediaEquipment`를 확장했다. 더미 데이터도 `T5 Lv.25` 형태와 각각의
  변동값을 제공한다.
- 다중 변동: 스킬·장비·추가 능력치는 본문을 위쪽에, 대응 변동값을 아래쪽에
  배치한다. 값이 변하지 않는 칸은 `-`, 변동 칸은 `▲n` 또는 `▼n`으로 표시하고
  `/`로 구분한다.
- 검증: 관련 Widget test 11개, `flutter analyze --no-pub`, Windows release
  build와 확대 실화면 검수를 통과했다. 정식 release bundle을 동기화했다.

### 2026-07-28 인연 열 고정 및 무변동 행 생략

- 상태: `구현 및 실화면 검증 완료`
- 인연: 하트가 기존 정보 열 위치로 되돌아가지 않도록 우측 전용 열
  (`center x = 0.95`) 안에 중앙 정렬했다. 상승치는 하트 아래에 유지한다.
- 변동 행: 스킬·장비·추가 능력치의 구성값이 모두 무변동이면 하단 행 자체를
  렌더링하지 않고 본문을 세로 중앙에 둔다. 하나라도 변동하면 기존처럼 무변동
  구성값은 `-`로 남겨 대응 관계를 보존한다.
- 스킬: EX 최대 5, 나머지 스킬 최대 10을 기준으로 최대값을 `M`으로 표시한다.
  실화면에서 3단계 시로코가 `M/6/6/6`으로 표시됨을 확인했다.
- 검증: 관련 Widget test 12개, `flutter analyze --no-pub`, Windows release
  build와 확대 실화면 검수를 통과했다. 정식 release bundle을 동기화했다.

### 2026-07-28 인연 하트 수직 정렬 및 페이즈 개수 제거

- 상태: `구현 및 코드 검증 완료, 사용자 육안 검수 대기`
- 정렬: 인연 하트의 실제 렌더링 영역 중심 Y를 장비 `square.png` 중심 Y와
  동일한 `0.67614347305232`로 맞췄다. 하단 인연 변화량 공간은 유지한다.
- 페이즈: 각 페이즈 컨테이너 우측 상단에 표시하던 내부 아이템 개수 텍스트를
  제거했다.
- 검증: 관련 Widget test 12개와 `flutter analyze --no-pub`를 통과했다.
  요청에 따라 자동 육안 검수는 수행하지 않고 release bundle만 동기화했다.

### 2026-07-28 최대화 화면 기준 인연 하트 중심 재정렬

- 상태: `구현·코드 검증·최대화 실화면 검증 완료`
- 원인: 이전 검증은 작은 장비 아이콘 뒤의 `square.png`를 비교 대상으로 삼아,
  사용자가 지칭한 학생 portrait 뒤의 큰 `square.png`보다 하트가 아래에 남았다.
- 변경: 하트의 실제 렌더링 영역 중심 Y를 학생 portrait 영역 중심 Y와 정확히
  일치시켰다. Studio 원본의 `feature-17` 위치와 Widget test도 같은 학생 portrait
  기준으로 변경했다.
- 검증: 관련 Widget test와 `flutter analyze --no-pub`, Windows release build 및
  release bundle 동기화를 통과했다. 최신 release를 현재 모니터의 2560×1392
  최대화 창으로 실행하여 학생 `square.png`와 하트 중심선이 일치하는 것을 확인했다.

### 2026-07-29 인연 변화량 중앙 정렬 및 작업 이력 문서화

- 상태: `구현·코드 검증·최대화 실화면 검증 완료`
- 변경: 인연 변화량을 하트 아래에 유지하면서 실제 텍스트 중심 X가 하트 중심 X와
  일치하도록 `_DeltaLabel`에 호출부별 alignment와 실제 콘텐츠 검증 key를 추가했다.
  공용 기본 정렬은 기존 `centerLeft`로 유지해 다른 값 열에는 영향을 주지 않는다.
- 문서: 계획·스캔 공용 `DiagonalMediaListItem`의 표시 계약, 단계별 조정 이력,
  학생/장비 `square.png` 혼동, 작은 창 검증, slot과 실제 render bounds 차이,
  중첩 `Align` 때문에 바깥 `Center`가 무효였던 원인과 향후 검증 규칙을
  `almanac/design/diagonal-media-list-item.md`에 기록했다.
- 검증: 집중 Widget test 5개, `flutter analyze --no-pub`,
  `codealmanac validate`, `codealmanac health`, Windows release build와 bundle
  동기화를 통과했다. 최신 release를 현재 모니터의 2560×1392 최대화 창에서
  확대 확인해 각 행의 인연 변화량이 하트 바로 아래에서 같은 중심 X를 사용하는
  것을 확인했다.

### 2026-07-29 계획 스크롤·인연 경계 더미 확장

- 상태: `구현·코드 검증·release 동기화 완료, 사용자 실행 검수 대기`
- 데이터: 4개 페이즈의 더미 학생 단계를 11개에서 16개로 늘려 기준 화면에서도
  충분한 세로 scroll extent가 생기게 했다. 인연 50은 유우카·히나, 인연 100은
  아즈사·아코 행에 배치했으며 100은 최대치이므로 추가 상승치를 생략한다.
- 테스트: 총 행 수와 50·100 존재 여부, 실제 `BondRankPortrait` 투영값과
  파랑·보라 배경 경계를 검증한다. 스크롤은 `maxScrollExtent`가 viewport보다
  큰지 확인하고 drag 뒤 offset, 중간 페이즈와 마지막 아코 행의 Y 이동을 함께
  검증하도록 강화했다.
- 검증: 계획·공용 아이템 집중 test 12개, `flutter analyze --no-pub`와 Windows
  release build 및 bundle 동기화를 통과했다. 실행·육안 검증은 사용자 요청에
  따라 수행하지 않았다.
- 다음 행동: 사용자가 최신 release를 실행해 추가 행, 인연 50·100 배경과
  scrollbar 이동을 확인한다.

### 2026-07-29 인연 50 배경 경계 수정

- 상태: `구현·코드 검증·release 동기화 완료, 사용자 실행 검수 대기`
- 원인: 노랑 배경 조건이 `bondRank > 50`이어서 정확히 50인 더미 행이 파랑
  `square_blue.png`로 분류됐다.
- 변경: 노랑 시작 조건을 `bondRank >= 50`으로 고쳐 1~20 기본, 21~49 파랑,
  50~99 노랑, 100 보라 경계를 적용했다.
- 검증: 49·50·99·100 경계값과 계획 탭의 인연 50·100 투영을 포함한 집중 test
  12개, `flutter analyze --no-pub`, Windows release build와 bundle 동기화를
  통과했다. 실행 검증은 사용자에게 맡긴다.

### 2026-07-29 계획 페이즈 스크롤 상·하단 안개 적용

- 상태: `구현·코드 검증·release 동기화 완료, 사용자 실행 검수 대기`
- 공용화: 학생 탭 Section 2의 안개 색상, 36px gradient와 scroll endpoint 판정을
  `ScrollViewportFog`와 `scrollViewportFogVisibility`로 분리했다. 학생 탭의 기존
  `StudentViewportFog` API와 key는 wrapper로 유지했다.
- 계획: 페이즈 목록 시작에서는 아래쪽, 중간에서는 위·아래, 끝에서는 위쪽 안개만
  표시한다. 최초 build에 `ScrollController`가 아직 연결되지 않은 경우에도 알려진
  content extent와 viewport로 초기 아래 안개를 계산한다.
- 검증: 계획 탭 test 7개, 학생 탭 test 28개, `flutter analyze --no-pub`,
  Windows release build와 bundle 동기화를 통과했다. 실행 검증은 사용자에게
  맡긴다.

### 2026-07-29 인연 20 파랑 배경 경계 수정

- 상태: `구현·코드 검증·release 동기화 완료, 사용자 실행 검수 대기`
- 원인: 파랑 배경 조건이 `bondRank > 20`이어서 정확히 20인 학생이 기본
  `square.png`로 분류됐다.
- 변경: 파랑 시작 조건을 `bondRank >= 20`으로 고쳐 1~19 기본, 20~49 파랑,
  50~99 노랑, 100 보라 경계를 적용했다.
- 검증: 19·20·49·50·99·100 경계와 계획 탭 투영을 포함한 집중 test 12개,
  `flutter analyze --no-pub`, Windows release build와 bundle 동기화를 통과했다.
  실행 검증은 사용자에게 맡긴다.

### 2026-07-29 계획 Section 3 재화 헤더

- 상태: `헤더 구현·코드 검증·최대화 실화면 검증 완료`
- 범위: Section 3 본문과 실제 부족 데이터 연결은 만들지 않고 헤더 부분만 구현했다.
- 구조: Section 3 평행사변형을 공용 compound header의 바깥 glass에 대응시키고,
  상단 `페이즈별 / 전체 / 병목` 탭 선반, divider와 중첩 재화 헤더를 추가했다.
  탭 선택 배경·primary 하단선·icon·label과 title 전환은 AppShell 헤더 문법을 따른다.
- 사선 적합: 탭 선반과 중첩 헤더의 좌우 끝을 각 Y의 Section 3 80° 경계에서 계산한다.
  title·subtitle도 위쪽 왼쪽과 아래쪽 오른쪽 경계가 만드는 공통 안전 폭 안에 둔다.
- 검증: 계획 탭 집중 test 9개, Flutter 전체 205 tests, `flutter analyze`, Windows
  debug·release build, `codealmanac validate`·`health`와 `git diff --check`를 통과했다.
  최신 debug 앱을 2560×1440 최대화 화면에서 열어 Section 2·4 침범 없음, 세 탭의 안전 폭,
  활성 탭 표현, 양쪽 80° 중첩 표면과 삼각 texture를 확인했다.
- 다음 행동: 사용자 검수 뒤 Section 3의 선택 탭별 본문 토대와 실제 부족 데이터 계약을
  별도 단계로 구현한다.

### 2026-07-29 계획 재화 Section 3·5 분리

- 상태: `구현·집중 검증·최대화 실화면 검증 완료`
- 입력: 갱신된 `release/section-plan-main.ba-section-studio.json`의 Section 3
  bottom 깊이 80과 신규 Section 5 `(53,1,42,14)`, top 깊이 96을 runtime projection에 반영했다.
- 역할: 기존 Section 3의 재화 헤더를 Section 5로 옮기고 Section 3은 탭별 결과 본문 자리로
  남겼다. Section 5는 독립 foundation에서 alpha 0.76 glass fill과 lifted shadow를 가진다.
- motion: Section 5는 사용자 지정 `intro 260° / outro 80°`를 독립 controller로 실행한다.
  Section 3은 기존 `80° / 260°`를 유지한다.
- 반응형: Section 5 높이에 따라 탭 선반과 중첩 헤더를 축소한다. 두 줄 copy가 넘치는
  낮은 viewport에서는 title만 유지하며 1280×720 Widget test에서도 overflow가 없다.
- 정렬·간격: Section 5를 x=53으로 옮겨 Section 3과 같은 80° rail에 맞췄다. y=1로
  내려 공용 헤더와 거리를 늘리고 Section 3과의 간격은 약 2.33 grid로 줄여 Section 3
  하단의 2 grid 바닥 여백과 유사하게 했다.
- 검증: 계획 탭 집중 test 9개, 전체 Flutter test 205개, `flutter analyze`,
  Windows debug/release build, `codealmanac validate`, `codealmanac health`,
  `git diff --check`를 통과했다. 최신 Windows debug 앱을 최대화 화면과
  1265×711 작은 창에서 열어 Section 5와 Section 3의 분리, 이어지는 80° rail,
  Section 5 외곽 glass·shadow와 내부 texture 및 세로 overflow가 없음을 확인했다.
- 다음 행동: 탭별 스위칭 시 Section 3 본문 교체 motion과 각 재화 보기의 내부 토대를 정한다.

### 2026-07-29 Section 5 병목 탭 우선 구현

- 상태: `구현·집중 검증·최대화 실화면 검증 완료`
- 탭 순서: `병목 / 페이즈별 / 전체`로 변경하고 병목을 초기 선택으로 지정했다.
- 병목 요약: Section 5의 기존 제목·설명 copy를 제거하고, 좌측에
  v6의 네브라 디스크 T3 아이콘과 tier index 2의 `square_yellow.png` 배경을
  런타임 UI 자산으로 분리 복사해 배치했다. 아이콘은 content 높이의 85%를 차지한다.
- 3행 정보: `가장 심한 병목 요소`, `보유량 : 42 / 필요량 : 60`,
  `확보 시 학생 3명의 목표 단계가 가능해집니다` 순서로 표시한다.
- 연동: 병목 아이템을 누르면 Section 2에서 네브라 T3 소모 학생으로 지정한
  아즈사·노노미·하루카의 모든 단계 행에 1.2px 핑크 테두리가 표시된다.
  병목 외 탭으로 전환하면 강조를 해제한다.
- 데이터: 실제 inventory-derived shortage 연결 전까지 수량 42/60과 영향 학생 3명은
  typed sample constants로 유지한다. 나머지 두 탭은 기존 placeholder copy를 복원하지 않는다.
- 반응형: 낮은 Section 5에서는 아이콘, 글꼴, 간격과 line height를 함께 축소해
  3행 정보를 유지하면서 세로 overflow를 방지한다.
- 검증: 계획·공용 행 집중 test 15개, 전체 Flutter test 206개, `flutter analyze`,
  Windows debug/release build를 통과했다. 최신 Windows debug 앱의 1265×711 및
  2560×1440 화면에서 아이콘 크기, 3행 copy, 하루카·노노미 2단계·아즈사의
  얇은 핑크 테두리와 비대상 행 유지 상태를 확인했다.
- 다음 행동: 실제 inventory-derived shortage DTO를 연결하고 병목 우선순위 산식을 정한다.

### 2026-07-29 Section 5 병목 가시성 조정

- 상태: `구현·Windows 실화면 검증 완료`
- Section 2 연동 강조선은 `1.2px → 1.8px`로 1.5배 확대했다.
- Section 5의 3행 copy 간격은 일반 화면 `3/4px → 4.5/6px`, compact 화면
  `1/1px → 1.5/1.5px`로 각각 1.5배 확대했다.
- 검증: 사용자 요청에 따라 자동 테스트는 생략했다. 최신 Windows debug 앱의
  2560×1440 계획 화면에서 3행 copy 간격과 선택된 하루카·노노미·아즈사 행의
  1.8px 핑크 테두리 가시성을 확인했다.

### 2026-07-29 Section 5 페이즈별 요약

- 상태: `구현 완료·사용자 검증 대기`
- 공용화: 병목과 페이즈별 탭이 동일한 `PlanResourceItemSummary` 표현 구조를 사용한다.
  병목의 클릭 강조 동작은 기존 wrapper에만 유지한다.
- 페이즈별 copy: `가장 부족한 재화`, `보유량 : 42 / 필요량 : 60`,
  `3단계에서 4명 중 1명만 완료 가능`을 3행으로 표시한다.
- 아이콘: 병목 탭과 동일한 네브라 디스크 T3 및 노란 등급 배경을 사용한다.
- 검증: 사용자 요청에 따라 자동 테스트와 실화면 검증을 수행하지 않았다.
