---
title: "Frontend Redesign Status — Lane B"
summary: "프론트 개편 Lane B(FE8 타이틀·홈·스캔) 워커 진행 상태입니다. slice별 시작 SHA, 고친 파일, 실행 명령과 결과, 처리한 워커 재량 FD, 미검증 항목, 검수표와 다음 행동을 기록합니다."
topics: [workflow, design]
sources:
  - id: workflow
    type: file
    path: almanac/workflows/frontend-redesign-workflow.md
---

# Frontend Redesign — Lane B 워커 상태

규칙: 이 파일은 Lane B 워커만 쓴다. Lane A 워커는 `frontend-redesign-status.md`, 오케스트레이터 결정은 `frontend-redesign-orchestrator-log.md`에 있다. 실행 범위·불변식·gate는 워크플로의 "Lane A·B 프론트 병렬" 문단과 FE8 표를 따른다. [@workflow]

## 현재 상태

**fb3-dart gate ① RED 수정 완료, 같은 소스 gate 재실행 대기(2026-10-11).** 시작 커밋 `84f645c3`. 아래 "fb3-dart 착수 기록"·"fb3-dart 종료 기록"·"fb3-dart gate ① RED 수정 기록"(맨 끝 다음 행동). T-FB1b는 커밋 `5c78c83c`, FE8-b `8268abb3`로 끝났다(오케스트레이터 로그 2026-10-11 03:20). 그 전: S-FB1b `70d1173b`, fb4-dart `63a01318`, FE8-a `815e0589`.

## FE8-a 착수 기록 (2026-10-10)

- 범위: 시안 `Title.dc.html`과 A 보고서 §2.4의 T1~T11(시작 380, 설정·나가기 크기, 계정 카드 위치·반경, 보유율 진행 막대, `보유 217 / 265`, 카드 전체 탭 → 계정 관리, 톱니 아이콘·의미 라벨, 시작 라벨·분홍 외곽선, Space 키캡 간격·색, 로고 띠 불투명도·glow, 초상 평행사변형 stucard). Studio JSON 재저장과 projection 테스트 갱신을 같은 slice에서 한다. 백엔드 추가 없음.
- 범위 밖(현행 유지): 첫 실행·계정 없음 흐름과 v6 가져오기 다이얼로그(FD-114, 새 계정 모달은 FE8-b), 버튼 절차 텍스처(FD-015 (a)), 퇴장 애니메이션.
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `c9258cb1aa9507d3f8ac0dae2dacc408006844f3`.
- 막힘: 대장 막힘 요약에서 FE8-a를 막는 열림 FD 없음(열림 0건).
- 고칠 기존 파일(착수 전 사본을 `debug/frontend_fe8a/pre/<v7 기준 경로>`에 둔다):
  - `frontend/lib/ui/pages/title_page.dart`
  - `frontend/lib/ui/studio/title_studio_layout.dart`
  - `frontend/test/title_page_test.dart`
  - `frontend/assets/studio_sections/section-title.ba-section-studio.json`(Studio 저장 문서 재저장. git이 추적하는 사본이다. `release/`의 같은 이름 파일은 `.gitignore` 대상이다)
  - `almanac/design/section-template-studio.md`(Title 적용 규칙 절에 FE8-a 차이만 덧붙인다, FD-001) → **취소**(종료 기록 "발견 사항" 1). 사본만 남아 있고 commit.json에는 넣지 않았다.
- 새 파일: 이 문서.
- Lane A와 겹치지 않는 것: `app_shell.dart`, `lib/services/**`, 학생·계산기·계획 화면 파일, 키트(`lib/ui/kit/**`)·geometry·`section_surface`·`section_template_surface`, golden harness·golden 테스트 파일, `frontend-redesign-status.md`는 고치지 않는다. 키트 `SkewBar`와 학생 카드 경로 함수(`studentGridCardPath`)는 import해서 쓰기만 한다. 새 golden 장면은 만들지 않는다.
- 시각 변경 slice: golden 갱신은 오케스트레이터 검토 뒤 사용자가 `fe_gate.ps1 -UpdateGoldens`로 한다. golden PNG를 직접 만들거나 지우지 않는다.
- 기기 쓰기: 매번 새 작업 공간 경로에서 쓰고, 쓴 뒤 다시 읽어 바이트로 대조한다.

## FE8-a 종료 기록 (2026-10-10, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없다(SDK 내려받기도 프록시가 막는다). analyze·테스트·golden을 돌리지 못했으므로 통과를 주장하지 않는다.
- 정적 검토만 했다. 별도 검토 에이전트가 바뀐 파일을 사본·의존 파일과 대조해 읽었다(쓴 API의 존재·시그니처, const, import 충돌, 제약 없는 layout, hit test 순서, 새·바뀐 테스트의 기대값 직접 계산).
  - 컴파일·analyze 지적은 없었다.
  - 지적 1건을 고쳤다: 진행 막대가 feature 높이(창 높이 × 0.0065)에 묶여 773px보다 낮은 창에서 5px보다 얇아졌다. 막대는 이제 feature 중심에 높이 5로 놓인다.
- 시안 값은 `Title.dc.html`을 `tools/dc_outline.py`로 읽고, 둥근 path·키캡·glow·진행 막대 style만 원문에서 그 요소를 골라 읽었다.

### 고친 파일

- **`frontend/assets/studio_sections/section-title.ba-section-studio.json`(Studio 저장 문서 재저장, git 추적 사본)**
  - 섹션은 96 grid 정수 칸이라 시안 좌표(계정 카드 y=22 등)를 그대로 못 쓴다. 섹션은 그림 영역을 여백을 두고 덮는다:
    - element-1 로고 띠 (19,32,57,18)
    - element-2 시작 (40,56,15,9)
    - element-3 계정 (0,1,26,17)
  - 보이는 표면은 부모 상대 비율 컨테이너다. 기준 viewport 2560×1392에서 path bounds가 시안과 같다:

    | 컨테이너 | 시안 path bounds |
    |---|---|
    | container-1 로고 띠 | 520,470 1520×250 |
    | container-4 설정 | 544,646 92×54 |
    | container-5 나가기 | 1875,646 110×54 |
    | container-2 시작 | 1090,820 380×116 |
    | container-6 계정 카드 | 0,22 660×226 |

    평행사변형 컨테이너 rect 폭 = 시안 폭 − 높이/tan80°.
  - feature 위치:
    - feature-1 로고 이미지 980,497 600×180
    - feature-3 초상 stucard 52,58.1 190×153.81, 비율 252/204
    - feature-4 이름 280,64 320×30
    - feature-6 진행 막대 자리 280,103.5 300×9(막대 5px는 중심 108)
    - feature-5 보유 줄 280,123.5 320×24
  - feature-2 문구는 `시작`, feature-5 문구는 `보유 217 / 265`다(Studio 표시용).
  - 형식은 Studio 저장과 같은 JSON(들여쓰기 2, 끝 개행 없음)이다.
  - `release/section-title*.ba-section-studio.json`은 `.gitignore` 대상이고 헌장상 XB 폴더라 고치지 않았다(발견 사항 2).
- **`frontend/lib/ui/studio/title_studio_layout.dart`**: 위 문서의 typed projection이다. 이전의 `section-title` + `section-title-1` 병합은 없앴다.
- **`frontend/lib/ui/pages/title_page.dart`**
  - 로고 띠·계정 카드 표면 path는 컨테이너 다각형을 시안 반경 16으로 둥글린다(`_surfacePath`). `buildAttachedSectionPolygon`·`buildRoundedSectionPolygon`·부모 섹션 교차는 `buildStudioContainerPath`와 같고, 반경만 다르다.
  - 그림자(`LiftedPathShadow`)는 각 그룹의 최종 표면 path를 따른다. 섹션 marker key(`title-brand-section`·`title-primary-position`·`title-account-section`)는 섹션 rect 그대로다.
  - T1~T11 반영(아래 검수표).
  - 퇴장 애니메이션(270°·90°), 첫 실행·계정 없음 흐름(`계정 생성` 라벨, v6 가져오기 다이얼로그), 버튼 절차 텍스처는 그대로다.
- **`frontend/test/title_page_test.dart`**(22건 → 25건, 지운 테스트 없음)
  - 바꾼 테스트 2건:
    - `typed title layout matches the saved Studio document`: 이전 이름 `... combines the base and revised Studio documents`. 무시되는 `../release/` 대신 git 추적 사본을 읽는다. Studio 불러오기(`decodeSectionStudioDocument`) 왕복도 확인한다.
    - `title follows the section studio placement and account state`: 1440×900 섹션 rect 새 값, 보유 줄 위젯, 키캡 위치(버튼 아래 14·높이 26·가운데), 톱니(Icon 없음)·의미 라벨, 시작 라벨 34 w700·외곽선, 카드 버튼·라벨, 로고 띠 .93·glow, 계정 카드 공용 표면·삼각 무늬 없음, stucard 경로·외곽선, 진행 막대(높이 5, mock 0/2 → 0), 로고 띠 path를 container-1과 비교.
  - 새 테스트 3건:
    - `title surfaces reproduce the draft bounds at the reference viewport`: 2560×1392 컨테이너·feature bounds를 시안 값과 비교(허용 2px).
    - `tapping the title account card opens the account manager`: 이름 글자 위를 눌러도 관리가 열린다.
    - `title owned count shows an unknown total without a zero`: 카탈로그를 못 읽으면 `/ —`, 막대 fraction null(빗금).
  - golden harness·golden 테스트 파일은 고치지 않았다. 새 golden 장면 없음.

### 검수표 (artboard `Title.dc.html`)

앱에서 여는 방법: mock 모드(`--dart-define=BA_PLANNER_USE_REAL_BACKEND=false`)로 실행하고 2560×1440 모니터에서 최대화한다. 첫 화면이 타이틀이다(계정 `Main`, 보유 0 / 전체는 mock catalog 수). 캔버스의 같은 artboard와 나란히 본다. 숫자 217/265는 시안 예시 값이라 mock과 다르다.

| # | 확인 포인트 | 코드 |
|---|---|---|
| T1 | 시작 버튼 380×116, 위치 1090,820 | container-2 |
| T2 | 설정 92×54 at 544,646, 나가기 110×54 at 1875,646. 두 버튼이 로고 띠 아래쪽 안에 들어간다 | container-4/-5 |
| T3 | 계정 카드 0,22 660×226, 모서리 16(왼쪽 수직·오른쪽 80°) | container-6, `_titleSurfaceRadius` |
| T4 | 이름 아래 보유율 진행 막대(300×5, −10° 기울임, 트랙 흰 .14, 채움 #f4f8fb, 폭 = 보유/전체). 전체를 모르면 빗금 | `title-account-progress` |
| T5 | `보유`(13 muted) · 보유 수(경기천년제목 20 굵게) · `/ 전체`(13 muted), 기준선 정렬 | `title-owned-count` |
| T6 | 계정 카드 아무 곳이나 누르면 계정 관리가 열린다(설정 버튼과 같은 전환) | `title-account-card` |
| T7 | 설정 버튼이 톱니 그림(원 + 바퀴살 8)이고, 화면 읽기 라벨은 `계정 관리` | `title-settings-gear` |
| T8 | 시작 라벨 34px 굵게(흰색), 버튼 분홍 외곽선 rgba(242,179,239,.9) 1.8px | `title-primary-outline` |
| T9 | Space 키캡이 버튼 아래 14px에 떨어져 있다. #0d151f, 안쪽 1px 테두리, 13px 굵게 #dfe7ee, 그림자 없음 | `_KeyCap` |
| T10 | 로고 띠가 더 불투명(.93)하고 가운데 위쪽에 옅은 분홍 glow | `title-brand-glass`·`title-brand-glow` |
| T11 | 초상이 학생 카드 모양 평행사변형 + 흰 외곽선이다. 그 뒤 삼각 무늬 사다리꼴이 없다 | `title-account-image-grid` |

### 처리한 FD

- **FD-114**(워커 재량): 첫 실행 흐름·`title-account-dialog`·v6 가져오기는 현행 유지. 새 계정 추가 모달 통일은 FE8-b다.
- **FD-015 (a)**: 설정·나가기·시작 버튼은 `BATriangleTexturePainter` 절차 텍스처 그대로다.
- **FD-001**: 로고 띠 채움 .93은 공용 섹션 표면 .76의 예외로 시안을 따랐다.

### golden 예측

바뀔 장면(1): `title`. 띠·버튼·카드 위치와 크기, 띠 채움·glow, 외곽선, 키캡, 톱니, 진행 막대, 보유 줄, stucard가 달라진다.
바뀌지 않을 장면:
- `account-manager`·`account-editor`·`account-picker`: 타이틀 세 그룹이 퇴장 애니메이션으로 완전히 화면 밖에 나간 뒤 캡처한다. 이동 거리는 1.12 × max(2560,1392) = 2867px로, 각 그룹 크기보다 크다. 계정 클러스터 파일(`account_section_cluster.dart`·`account_studio_layout.dart`)은 고치지 않았다.
- `home`: 타이틀 없이 셸을 바로 연다(`_openShell`).
- 학생·계획·스캔 장면은 타이틀을 거치지 않는다.

그러므로 commit.json `whole`에는 `frontend/test/goldens/baseline/title.png`만 넣었다. gate ①에서 `account-*`·`home`이 RED면 이 예측이 틀린 것이니 갱신하지 말고 알려 달라.

### 미검증 항목

- analyze·일반 테스트·golden·`codealmanac validate`·`git diff --check` 전부 미실행(사용자 PC gate 필요).
- 둥근 path bounds: Flutter `Path.getBounds`가 제어점 bounds인지 실제 bounds인지에 따라 시작·로고 띠 오른쪽 끝이 최대 약 1.9px 안쪽일 수 있다. 테스트 허용 2px.
- 경기천년제목은 Medium(500) 한 굵기만 등록되어 있다. 시작 라벨 700·보유 수 800은 합성 굵게로 그려질 수 있어 시안보다 얇을 수 있다.
- 키캡 가로 위치: 버튼 bounds 가운데에 둔다. 시안은 left 1246 고정이라 글자 폭에 따라 약 3px 차이가 날 수 있다.
- 이름·막대·보유 줄의 세로 위치는 시안 flex 열(간격 14)과 글꼴 줄 높이로 추정했다(±2px).
- 긴 계정 이름은 기존 Studio 규칙대로 `FittedBox.scaleDown`으로 줄인다. 시안은 말줄임이다.
- stucard 테두리 자름 비율은 학생 그리드 카드와 같은 0.11이다. 시안 그림은 약 0.09 비율로 테두리를 잘라 보인다.

### 발견 사항

1. `almanac/design/section-template-studio.md`에 이 slice 내용(Title 저장 문서 단일화, 컨테이너 표면, 반경 16, 로고 띠 .93 예외, 카드 버튼, 진행 막대)을 덧붙이려 했으나 취소했다.
   - 이유: 작업 트리의 그 파일이 HEAD index와 다르다(줄바꿈 차이 아님, 2026-10-07 이후 다른 레인의 미커밋 변경으로 보인다). 3-way 병합 충돌을 피하려고 고치지 않았다.
   - 사본은 `debug/frontend_fe8a/pre/almanac/design/section-template-studio.md`에 남아 있다(쓰지 않음).
   - 오케스트레이터 문서 커밋에서 "Studio 구성을 실제 화면에 적용할 때의 규칙"의 Title 관련 문단을 갱신해야 한다. 특히 "Section의 기본 표면은 앱 전체에서 하나다(.76)"에 로고 띠 예외를 적어야 한다.
2. `release/section-title.ba-section-studio.json`·`section-title-1`은 git 추적 밖이다(`.gitignore` `release/`). 테스트도 이제 읽지 않는다.
   - Studio에서 이 위치 파일을 열면 FE8-a 이전 배치가 열린다.
   - 맞추려면 사용자가 `Copy-Item "frontend\assets\studio_sections\section-title.ba-section-studio.json" release\ -Force`를 실행한다(선택, 헌장상 `release/**`는 XB 폴더).
   - `frontend/assets/studio_sections/section-title-1.ba-section-studio.json`(추적)은 이제 쓰이지 않는 이전 수정본이다. FE10 죽은 파일 정리 후보다.
3. 시안에는 있으나 T1~T11에 없어 반영하지 않은 차이(FE8-b 또는 오케스트레이터 판단):
   - 설정·나가기 외곽선 rgba(56,81,107,.72) 1.8px
   - `나가기` 15px w700
   - 계정 카드 채움 .9 + 외곽선 rgba(56,81,107,.6) 1.2px(지금은 공용 표면 .76, 외곽선 없음)
   - 버튼 모서리 반경 8(Studio 기본 10)
4. 로고 띠 위치·크기도 바꿨다(533,464 1493×232 → 시안 520,470 1520×250, 로고 이미지 980,497 600×180).
   - T 표에는 없다. 하지만 T2의 설정·나가기 아래 끝(y=700)이 이전 띠 아래 끝(696)을 넘어 잘리므로, T2와 T10을 위해 함께 맞췄다.
5. Lane A 요청(키트, 고치지 않음): 톱니는 `title_page.dart`의 private painter로 그렸다. 다른 화면에서 쓰게 되면 `KitGlyph`에 `gear`(viewBox 24, stroke 2.1)를 올려 달라.

### 다음 행동과 사용자 실행 명령

PowerShell, `C:\Users\brigh\planner_of_plana\BA Planner\v7`에서:

1. Lane A·B 두 워커가 모두 멈춘 뒤 `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1`을 실행하고, 결과(`debug/frontend_gate/` 요약)를 오케스트레이터에게 보낸 뒤 기다린다. 예상: golden `title` 1건만 RED.
2. 오케스트레이터 승인 뒤:
   - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1 -UpdateGoldens`
   - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1`(GREEN 확인)
3. 커밋(순서는 오케스트레이터가 정한다):
   - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice fe8a -DryRun`
   - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice fe8a`

## fb4-dart 착수 기록 (2026-10-10)

- 범위: XB FB-4 커밋 `b685d9ac`(`scanner.target.list`의 optional `client_width`·`client_height`·`game`)의 Dart 연결. 기준은 XB 연결 메모 `debug/xb_fb4_target_metadata_20261010/artifacts/dart-connection-memo.md`와 공유 fixture `contracts/fixtures/scanner_target_metadata_fb4_v1.json`(14 cases, `contract_status: finalized`).
  1. `ScannerTarget`에 nullable `clientWidth`·`clientHeight`·`game`(생략·null 모두 "모름", 0이나 기본값으로 채우지 않음).
  2. 응답 검사(`_validScannerSuccessPayload`의 `scanner.target.list`)에 optional 필드 검사.
  3. `MockAppService` 기본 target에 2560×1440·`blue_archive`.
  4. 공유 fixture 14 cases Dart 테스트, 실제 Python → Dart process E2E.
- 범위 밖: 홈 연결 칩·창 선택 패널 표시(FE8-d·FE8-e), `frontend/lib/ui/**`(Lane A가 FE5-a 진행 중), golden, `app_shell.dart`, `backend/**`·`contracts/**`(XB).
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `1fa861942e15459fc479e8e91cb899b6af3ff0c8`.
- 고칠 기존 파일과 미커밋(WIP) 여부(작업 트리 내용을 git index blob과 비교, 줄바꿈 차이는 제외):

  | 파일 | WIP | 비고 |
  |---|---|---|
  | `frontend/lib/services/scanner_service.dart` | 있음 | HEAD blob이 pack 안이라 WIP 위치는 확인 못 함 |
  | `frontend/lib/services/planning_protocol_client.dart` | 있음(CRLF) | 스캐너 오류 code 5줄, `scanner.review.*` 검사, `_validScannerUnresolvedSlots` 추가. `scanner.target.list` 줄과는 겹치지 않음 |
  | `frontend/lib/services/mock_app_service.dart` | 있음(CRLF) | `_assignedScannerSlots`, `confirmedFields` 재검증, unresolved slot API. 기본 target 줄과는 겹치지 않음 |

  세 파일 모두 착수 전 사본을 `debug/frontend_fb4dart/pre/<경로>`, slice 끝 사본을 `debug/frontend_fb4dart/post/<경로>`에 두고 commit.json에 `post_dir`를 적는다. WIP는 지우거나 정리하지 않는다. 원래 줄바꿈(CRLF/LF)도 그대로 둔다.
- 새 파일(예정): `frontend/test/scanner_target_metadata_fb4_test.dart`, `frontend/test/scanner_target_metadata_process_e2e_test.dart`.
- golden 변화 0 예정. Mock target의 id·제목(`mock-window`·`Mock Blue Archive`)은 그대로 두고 metadata만 더한다.

## fb4-dart 종료 기록 (2026-10-10, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없다. analyze·테스트·process E2E를 돌리지 못했으므로 통과를 주장하지 않는다.
- 정적 검토만 했다. 별도 검토 에이전트가 바뀐 파일을 원본·fixture·Python 모듈과 대조해 읽었다. 확인한 것:
  - 컴파일 쟁점: switch 패턴 완전성, const, 승격, import.
  - 14 cases 각각의 검사 결과와 fake process 흐름(start가 요청 전에 아무것도 쓰지 않음, 오류 응답 → `BackendProtocolException`).
  - E2E 스크립트의 생성자 인자.
  - fe_gate의 process 분류: E2E는 process로, 단위 테스트는 일반으로 분류된다.
  - 줄바꿈.
  - 결과: 막는 문제 없음. 권고 1건을 반영했다(E2E 진입점 스크립트를 저장 폴더와 분리한 임시 폴더로 옮김).
- 내가 직접 한 것: E2E에 넣은 Python 진입점의 문법 검사(`ast.parse`) 통과, fixture valid 행 9개·순서 확인.

### 고친 파일

- **`frontend/lib/services/scanner_service.dart`**
  - 새 enum `ScannerTargetGame { blueArchive('blue_archive') }`. `fromWire`는 모르는 값이면 `FormatException`이다.
  - `ScannerTarget`에 nullable `clientWidth`·`clientHeight`(int, 물리 client 픽셀)·`game`과 `hasClientSize`(둘 다 알 때만 참)를 더했다.
  - `fromWire` 규칙:
    - 키 생략과 null은 둘 다 null(모름)이다. 0이나 기본값으로 채우지 않는다.
    - 크기 값이 있으면 양의 int만 받는다. bool·문자열·double·0·음수는 `FormatException`이다.
    - `game`이 문자열이 아니거나 `blue_archive`가 아니면 `FormatException`이다.
  - 기존 `id`·`title`·`status`·`foreground` 의미는 그대로다.
  - **`game`을 enum으로 한 이유**: 계약 값이 `blue_archive` 하나와 null로 닫혀 있다. 응답 검사가 다른 문자열을 먼저 거부하므로, enum이면 소비자(FE8-d/e)가 오타 없이 비교하고 새 값이 추가될 때 컴파일러가 찾아 준다. "모름"은 별도 enum 값이 아니라 null로 둔다(생략·null 구별 없음, 게임 아님으로 단정하지 않음 — 연결 메모).
- **`frontend/lib/services/planning_protocol_client.dart`**: `scanner.target.list` 응답 검사에 `_validScannerTargetMetadata`를 더했다.
  - 키가 없거나 null이면 통과한다.
  - 값이 있으면 `client_width`·`client_height`는 양의 int, `game`은 `blue_archive`만 받는다.
  - 그 밖의 값은 기존 응답 오류와 같은 방식이다(`BackendProtocolException` + 연결 fatal).
  - 모르는 추가 키는 지금처럼 허용한다.
- **`frontend/lib/services/mock_app_service.dart`**: 기본 scanner target에 `clientWidth: 2560`, `clientHeight: 1440`, `game: blueArchive`를 더했다(연결 메모 Mock 예시 값).
  - id·제목(`mock-window`·`Mock Blue Archive`)은 그대로다. `mock_scanner_service_test`·`home_app_shell_test`(`mock-window` 글자)·Mock 학생 스캔 시작 경로가 그대로 맞는다.
  - 화면은 아직 metadata를 그리지 않으므로 golden 변화가 없다.

### 새 테스트 (지운·고친 기존 테스트 없음)

- **`frontend/test/scanner_target_metadata_fb4_test.dart`(일반 19건)**: 공유 fixture `contracts/fixtures/scanner_target_metadata_fb4_v1.json`을 직접 읽는다(Python과 같은 파일, `../contracts/...` 경로는 기존 계약 테스트 방식).
  - fixture 모양 1건: 14 cases = valid 9 + invalid 5, 모두 `scanner.target.list` 응답.
  - case별 14건: 가짜 backend가 fixture envelope를 그대로 돌려준다(요청 id만 맞춤).
    - valid는 `ScannerProtocolClient.listScannerTargets` DTO가 wire와 같다(생략·null → null, `hasClientSize`).
    - invalid는 `BackendProtocolException`이다.
  - 의미 1건: ready2560x1440, legacy 생략, minimized(크기 모름·game 앎), 제목만 같은 창(game null·크기 앎), unsupported 비율(같은 game, status로만 전달).
  - `fromWire` 직접 거부 1건: invalid 5 + 추가 6가지(bool 높이, 1280.0, 0, game 1·빈 문자열·대문자).
  - 응답 검사 추가 1건: 1280.0·`'720'`·game false 거부, 모르는 추가 키 허용.
  - Mock 기본 target 1건.
- **`frontend/test/scanner_target_metadata_process_e2e_test.dart`(process 1건, fe_gate process 단계에서 직렬 실행)**
  - 실제 Python 백엔드(`ApplicationProtocolV1` + `ScannerSessionService` + `stdio_server`)를 띄운다. target provider는 공유 fixture의 valid 행 9개를 그대로 돌려준다.
  - `ProcessAppService.listScannerTargets` DTO가 9행 모두 wire와 같은지 본다(2560×1440·blue_archive, 생략 행과 null 행은 모름).
  - 실제 게임 창은 필요 없다. 진입점은 테스트가 임시 폴더에 쓰는 Python 스크립트이고, backend 폴더를 `sys.path`에 넣어 실제 `core` 모듈을 쓴다(`backend/**`는 고치지 않음).
  - 실제 Windows 창 열거·DPI·`BlueArchive.exe` 판별은 XB Python 테스트 범위이고 실게임 관측은 아직 없다(XB 기록 NOT_VERIFIED 유지).

### 공유 파일 WIP 보존 확인

착수 사본(pre)과 끝 사본(post)의 차이는 이번 slice 줄뿐이다. 지운 기존 줄은 없고, 바꾼 기존 줄은 1줄이다.

| 파일 | pre → post 차이 | 원래 줄바꿈 |
|---|---|---|
| `scanner_service.dart` | 추가 5덩어리(enum, 생성자 인자 3, 필드·getter, fromWire 3줄, 검사 helper) | LF 유지 |
| `planning_protocol_client.dart` | `_validScannerTargetMetadata` 15줄 추가 + `.contains(item['status'])` 줄 끝 `,` → `&&` 1줄 변경과 호출 1줄 | CRLF 유지(새 줄도 CRLF), 기존 LF 줄 19개 그대로 |
| `mock_app_service.dart` | 기본 target 4줄 추가 | CRLF 유지(새 줄도 CRLF), 기존 LF 줄 그대로 |

- `planning_protocol_client.dart`·`mock_app_service.dart`는 HEAD blob(loose object)을 풀어 WIP 위치와 비교했다. WIP 덩어리는 모두 이번 변경 줄과 떨어져 있어 `fe_commit.ps1`의 3-way 병합이 충돌하지 않을 것으로 본다.
- `scanner_service.dart`는 HEAD blob이 pack 안이라 WIP 위치를 확인하지 못했다. `ScannerTarget` 줄을 WIP가 바꿨다면 fe_commit이 충돌로 멈춘다(그때 `.conflict` 파일을 오케스트레이터에게 보낸다).
- slice 끝 사본은 `debug/frontend_fb4dart/post/<경로>`, commit.json `post_dir: debug/frontend_fb4dart/post`.

### 미검증 항목

- analyze·일반 테스트·process E2E·golden·`codealmanac validate`·`git diff --check` 전부 미실행(사용자 PC gate 필요).
- process E2E의 Python 쪽은 실제 실행하지 않았다(문법 검사만). `JsonRepository`·`PlanningProtocolV1` 초기화는 기존 `tests/scanner_o1_e2e_backend.py`와 같은 import·환경 변수(`BA_PLANNER_STORAGE_ROOT`, `BA_PLANNER_ASSET_DIR`)를 쓴다.
- golden 변화 0 예상: 화면은 새 필드를 읽지 않고, Mock target의 id·제목·status는 그대로다.

### 발견 사항

1. 계약 schema의 `"type": ["integer", "null"]`(`contracts/scanner-protocol-v1.schema.json`)은 JSON Schema 2019 이후·Python `jsonschema`에서 `1280.0`도 통과시킨다. Dart 검사와 `fromWire`는 double을 거부한다. Windows provider는 float를 내지 않으므로 지금 문제는 아니다. 엄격히 맞추려면 XB가 Python 쪽이나 README에 "정수 표기만"을 적을지 판단(XB 소유, 고치지 않음).
2. 화면 표시(연결 칩 "연결됨 · Blue Archive · 2560×1440", 창 선택 패널)와 목록 주기 확인·해제 판단은 FE8-d·FE8-e다. 비율·서버 적격성 표시는 연결 메모대로 별도 의미 결정이 필요하다(같은 `game`이어도 non-16:9·다른 서버를 구별하지 않음).

### 다음 행동과 사용자 실행 명령

PowerShell, `C:\Users\brigh\planner_of_plana\BA Planner\v7`에서:

1. Lane A·B 두 워커가 모두 멈춘 뒤 `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1`을 실행하고, 결과(`debug/frontend_gate/` 요약)를 오케스트레이터에게 보낸 뒤 기다린다. 예상: GREEN, golden 변화 0, 일반 +19, process +1.
2. 커밋(순서는 오케스트레이터가 정한다):
   - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice fb4dart -DryRun`
   - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice fb4dart`
3. 커밋 해시가 나오면 오케스트레이터가 XB 로그 끝에 "CF 보고(fb4-dart)"를 적는다(첫 왕복 완료, 14:20 회신).

## S-FB1b 착수 기록 (2026-10-10)

- 범위: 스캔 탭(`scan_page.dart`)의 revision 전파와 재시도, 같은 파일의 pending apply 고정(CF 프롬프트 `debug/frontend_redesign_handoff/sfb1b-worker-prompt-20261010.md`, 기준 XB 초안 `debug/xb_fb_history_port_review_20261010/artifacts/S-FB1b-work-instruction-draft.md`, FB-1b `11426131`).
  1. `repository.state.get` 반환 revision을 profile 표시·cache·첫 scan session base revision에 전파(catalog summary 값을 권위값으로 계속 쓰지 않음).
  2. 학생 순차 적용(FD-144)에서 앞 commit 응답 revision을 다음 요청 expected로.
  3. `repository_busy` 지수 backoff 최대 3회 재시도(같은 key·같은 요청), 그 뒤에도 busy면 알리고 멈춤.
  4. `revision_conflict`는 state 재조회로 권위값·cache 갱신, 응답 유실 replay와 새 적용 구분.
  5. pending apply 고정(XB 15:30 메모): 최초 승인 candidate·profile·expected·idempotency key 고정, 같은 key 재시도에 review 재호출·새 expected 없음, 새 적용 의도는 새 key.
- 범위 밖: history context(서버가 만든다), scanner public DTO·method·Mock(XB 커밋 뒤 sfb2b-dart), `lib/services/**`, 계획·학생·타이틀 화면(Lane A), golden harness·golden 테스트·기준 이미지, `app_shell.dart`, `backend/**`·`contracts/**`.
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `11281beda57efadbbc2860f374d0367f556ffff4`.
- 막힘: 대장 막힘 요약 열림 0건. XB 초안의 "CM 승인 이후" 조건은 헌장 §3.2(2026-10-10 13:50, XB 커밋 계약부터 연결·CM 승인 없음)와 CF 배정(오케스트레이터 로그 17:05)으로 풀렸다.
- 고칠 기존 파일과 WIP(작업 트리 내용을 git index blob과 비교, 줄바꿈 차이 제외):

  | 파일 | WIP | 비고 |
  |---|---|---|
  | `frontend/lib/ui/pages/scan_page.dart` | 있음(LF) | index `312d4dec` ≠ 작업 트리 `c31aa6bd`. HEAD blob이 pack 안이라 WIP 위치는 확인 못 함 |

  착수 전 사본 `debug/frontend_sfb1b/pre/frontend/lib/ui/pages/scan_page.dart`, slice 끝 사본 `debug/frontend_sfb1b/post/<경로>`, commit.json `post_dir`. WIP는 지우거나 정리하지 않는다.
- 고치지 않는 기존 파일: `frontend/test/scan_page_test.dart`(WIP 있음, index `21f5c17a` ≠ `6af44970`). 새 테스트는 새 파일에 둔다. 기존 기대를 바꿔야 하면 그때 사본을 두고 이 기록에 적는다.
- 새 파일(예정): `frontend/lib/ui/scan/scan_repository_sync.dart`(busy 재시도·오류 분류·pending apply 값), `frontend/test/scan_page_revision_test.dart`.
- golden 변화 0 예정(스캔 화면은 golden 장면에 없다. 새 장면 금지).
- 이 환경에는 Flutter·Dart가 없다. gate는 사용자 PC에서 한다.

## S-FB1b 종료 기록 (2026-10-10, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없다(SDK 내려받기도 프록시가 막는다). analyze·테스트를 돌리지 못했으므로 통과를 주장하지 않는다.
- 정적 검토만 했다. 별도 검토 에이전트가 바뀐 파일을 원본·mock·workspace·기존 `scan_page_test.dart`와 대조해 두 번 읽었다(컴파일·analyze 쟁점, 기존 13개 테스트 회귀 추적, 새 테스트 기대값 수치 추적, fake async 타이머 시각, 목록 지연 생성).
  - 1차: 막는 문제 없음. 고칠 것 4건(대기 중 계정 전환, 고정 재시도가 state cache에 막힘, 대기 적용이 안내 문구를 지움, 새 스캔 뒤 이전 결과가 같은 id 후보를 건드림)과 사소한 것(불필요 import, 칩 문구 길이로 800px 화면 줄바꿈 위험)을 모두 반영했다.
  - 2차(반영분만): 문제 없음.
- 내가 직접 한 것: 괄호 균형, 줄바꿈(LF)·끝 공백·파일 끝 개행 확인, commit.json JSON·ASCII 확인.

### 고친 파일

| 파일 | 내용 |
|---|---|
| `frontend/lib/ui/pages/scan_page.dart`(WIP 있음, pre/post) | 권위 revision `_repositoryRevision`: state 응답(`_acceptRepositoryState`, 같은 계정의 더 낮은 revision은 버림)과 commit 응답(`_acceptCommittedRevision`)에서만 받는다. profile 칩 `Profile: <이름> · r<n>`·`_profile.revision`·`_repositoryState` 함께 갱신. 같은 계정을 목록이 다시 넘기면 이미 받은 권위값보다 낮게 내리지 않는다. `_start`가 세션 시작 전 state를 다시 읽는다(첫 session base, 실패하면 알리고 이전 값으로 진행). 학생 적용은 큐로 한 번에 하나(`_applyStudentCandidate` → `_applyStudentCandidateInOrder`), 탭한 계정과 차례가 온 때의 계정이 다르면 적용하지 않는다. 적용 = pending 고정 + busy 재시도 + 실패 분류(아래). state 읽기(선택·시작·적용 뒤·진단 추출)도 busy면 같은 backoff. 진단 추출의 state도 권위값으로 받는다 |
| 새 `frontend/lib/ui/scan/scan_repository_sync.dart` | `retryRepositoryBusy`(200/400/800ms, 최대 3회 재시도 = 4번 전송, busy 외 오류는 바로), `ScanApplyFailure`·`classifyScanApplyFailure`(BackendRemoteException·mock StateError = 백엔드 응답, 그 밖 = 결과 모름), `ScanPendingApply`(세션·승인 후보·profile·expected·key, `isRetryOf`), `scanPendingApplySlot` |
| 새 `frontend/test/scan_page_revision_test.dart` | 아래 12건 |

적용 흐름(`_applyStudentCandidateInOrder`):
- 같은 세션·generation·후보 revision·계정의 고정 요청이 있으면 **재시도**: review를 다시 부르지 않고 고정한 candidate·expected·key를 그대로 보낸다(그사이 다시 읽은 state revision으로 바꾸지 않음).
- 없으면 **새 의도**: review(approve) → 지금 권위 revision을 expected로, 새 key `scan-apply-<후보>-<revision>-<시각36진>-<순번>`(같은 후보 revision이라도 새 의도는 새 key)로 고정.
- 성공: commit 응답 revision을 권위값으로 받고(다시 읽기에 실패해도 다음 적용 expected가 된다) state를 다시 읽는다. 고정 해제.
- 실패 분류: 결과 모름(연결 끊김·시간 초과·응답 형식 오류) → 고정 유지, 후보는 초록 그대로, "다시 적용하면 같은 요청을 다시 보냅니다". busy 재시도 소진 → 고정 유지, 같은 안내. `revision_conflict` → 고정 해제, state 재조회, 후보 빨강(재검증 = 새 의도), 재시도였으면 "같은 요청을 다시 보냈지만 그사이 저장소가 바뀌어 적용되지 않았습니다". 그 밖의 거절 → 고정 해제, 빨강(기존 문구). 모든 실패 뒤 state를 다시 읽는다(기존 동작).
- history context(source=scan 등)는 RPC에 넣지 않는다. scanner public DTO·method·Mock은 바꾸지 않았다.

### 새 테스트 (지운·고친 기존 테스트 없음)

`frontend/test/scan_page_revision_test.dart` — 대역 `_RevisionScanService`(MockAppService + 백엔드식 idempotency receipt 재생, busy·응답 유실·요청 유실·충돌 주입, commit 기록):
1. `retryRepositoryBusy`: busy를 200/400/800ms 간격으로 3번 재시도하고 4번째 뒤 멈춘다.
2. `retryRepositoryBusy`: busy가 아닌 오류는 재시도하지 않는다.
3. `classifyScanApplyFailure` 분류표.
4. `ScanPendingApply.isRetryOf`·slot(세션 generation·후보 revision·계정이 다르면 다른 의도).
5. legacy 첫 state 로드: 목록 revision 0 → state 1을 칩·적용 expected로, 적용 뒤 2.
6. 시작 전 state 재조회: 화면 로드 뒤 다른 곳의 저장(0 → 1)을 시작 때 받아 첫 적용 expected 1, 충돌 없음.
7. 순차 적용: 적용 뒤·시작 때 state 읽기가 실패해도 두 번째 적용 expected = 첫 commit 응답 revision(expected 0, 1).
8. busy 2번 뒤 성공: 같은 key·같은 expected로 3번, review 1번.
9. busy 소진: 4번 보내고 멈춤, 후보 초록 유지, 다시 적용하면 같은 key·expected로 5번째(review 1번).
10. 응답 유실: 저장됐지만 응답을 못 받은 뒤 다시 적용하면 다시 읽은 revision 1이 아니라 고정 expected 0·같은 key로 보내 receipt 재생(review 1번).
11. 요청 유실 + 그사이 다른 저장: 재시도가 `revision_conflict` → 재시도 문구·칩 1·빨강, 재검증 뒤 새 key·expected 1로 성공.
12. 첫 시도 `revision_conflict`(백엔드 오류 형식): state 재조회(칩 2), 재검증 뒤 새 key·expected 2로 성공.

### WIP 보존 확인

- `scan_page.dart`는 착수 때 작업 트리 내용(index와 다름 = 스캐너 WIP 포함)에서 시작했고 WIP 줄은 지우거나 정리하지 않았다. 착수 전 사본 `debug/frontend_sfb1b/pre/frontend/lib/ui/pages/scan_page.dart`(49,792 bytes, sha256 `82ac04e6…`), slice 끝 사본 `debug/frontend_sfb1b/post/frontend/lib/ui/pages/scan_page.dart`(59,377 bytes, sha256 `033ee8da…`). 새 파일 2개의 끝 사본도 post에 둔다. commit.json `post_dir: debug/frontend_sfb1b/post`.
- HEAD blob이 pack 안이라 WIP 위치를 확인하지 못했다. WIP와 같은 줄을 고쳤다면 fe_commit이 충돌로 멈춘다(그때 `.conflict` 파일을 오케스트레이터에게 보낸다). 고친 곳: import 3줄, 상태 필드, `_selectProfile`, `_start` 앞부분, 진단 추출 2줄, `_applyStudentCandidate` 전체, profile 칩 문구.
- 사본 확인: 기기 도구가 7단계보다 깊은 파일을 다시 읽지 못해 pre/post 사본은 바이트 수로만 대조했다(경로 9단계). status 문서는 다시 읽어 sha256으로 대조했다.
- `frontend/test/scan_page_test.dart`(WIP 있음)는 고치지 않았다.

### 미검증 항목

- analyze·일반 테스트·golden·`codealmanac validate`·`git diff --check` 전부 미실행(사용자 PC gate 필요).
- 실제 Python process에서 busy·conflict·응답 유실 재시도는 돌려 보지 않았다(새 process E2E 없음). 재시도 문구 "적용되지 않았습니다"는 서버의 receipt 우선 재생(`contracts/README.md` "S-FB2b scanner current commit")을 전제로 한다(발견 사항 1).
- golden 변화 0 예상: 스캔 화면은 golden 장면에 없고, 앱 셸 장면에서 스캔 탭은 화면 밖이다.

### 발견 사항

1. **커밋 순서 주의(XB S-FB2b와)**: 같은 key 재시도에서 "이미 저장된 요청이면 원래 응답을 돌려준다"(receipt 우선 재생)는 XB S-FB2b 후보에 있다. S-FB2b가 커밋되기 전의 Python이 저장된 요청의 재전송에 `revision_conflict`를 준다면, 이 화면은 "적용되지 않았습니다"라고 잘못 알린다(데이터는 이미 저장됨, 현재값 재조회로 화면 값은 맞음). S-FB1b를 S-FB2b와 같은 gate 또는 그 뒤에 커밋할지는 오케스트레이터가 정한다.
2. `RepositoryProfilePanel`(`lib/ui/widgets/repository_profile_panel.dart`, 스캔 탭 위 계정 패널)은 목록 revision으로 선택·이름 변경을 한다. legacy 첫 이관(+1) 뒤 스캔 탭 패널에서 이름 변경·선택을 하면 `revision_conflict`가 날 수 있다. 공용 위젯이라 고치지 않았다(fe1brev가 계정 화면에서 한 것과 같은 대응 필요).
3. Mock `commitScannerCandidate`에는 receipt 재생이 없고 profile 목록 revision도 맞추지 않는다. 새 테스트는 대역이 receipt를 흉내 낸다. Mock 쪽은 sfb2b-dart 범위.
4. 안내 문구가 한 줄이라 뒤 적용의 결과가 앞 후보의 "같은 요청을 다시 보냅니다" 안내를 덮는다(고정 요청은 남아 있어 다시 누르면 재시도된다). 후보별 상태 표시는 FE8-g4 결과 검토 보드 몫.
5. "최근 세션 열기"(`_openRecent`)는 승인 전 후보(revision 1)를 되살리므로 그 뒤 적용은 고정 요청(승인 후 revision)과 맞지 않아 새 의도(새 key)로 간다. 값은 같아 결과는 같지만 revision이 하나 더 오를 수 있다.
6. 기존 문구 `_CandidateSummary`의 `Tactical lobby 쨌 current rank … 쨌`는 `·`가 깨진 글자다(기존 코드, 이번 범위 밖이라 그대로 둠).
7. FD-144 "계산 일치 일괄 적용"(여러 학생 순차 commit)은 FE8-g4다. 이번 큐가 그 순서·revision 이어 쓰기의 바탕이다.

### 다음 행동과 사용자 실행 명령

PowerShell, `C:\Users\brigh\planner_of_plana\BA Planner\v7`에서:

1. Lane A·B 두 워커가 모두 멈춘 뒤 `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1`을 실행하고, 결과(`debug/frontend_gate/` 요약)를 오케스트레이터에게 보낸 뒤 기다린다. 예상: GREEN, golden 변화 0, 일반 +12, process 변화 0.
2. 커밋(순서는 오케스트레이터가 정한다, 발견 사항 1 참고):
   - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice sfb1b -DryRun`
   - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice sfb1b`
3. 다음 Lane B slice(오케스트레이터 로그 17:05): XB 최종 후보가 오면 fb2b/sfb2b-dart, 그다음 T-FB1b → FE8-b.

## S-FB1b gate ① RED 수정 기록 (2026-10-10 밤, 코드 수정 완료·gate 미실행)

gate `debug/frontend_gate/20261010_185608`: S-FB1b 새 테스트 1건 실패 — `scan_page_revision_test.dart:311` "sequential applies carry the previous commit revision when rereads fail", 기대 `repository revision 1` 포함, 실제 `프로필 현재값을 불러오지 못했습니다: Bad state: persistence_failed`. 다른 S-FB1b 11건과 기존 scan 테스트는 통과. `repository_history_*` 2건·process 3건(XB 미커밋 summary `last_scan_at`, fb2b-dart 담당)과 golden 10장(FE5-b)은 이번 범위 밖이라 손대지 않았다.

### 원인

오케스트레이터 진단대로 적용 결과 안내를 `_selectProfile`의 catch가 덮었다. 다만 패널이 다시 넘긴 계기는 "commit 응답으로 `_profile` revision이 바뀌어서"가 아니다(패널은 `_profile`을 보지 않는다). 실제 경로:
1. 테스트 도우미 `_seek`가 후보의 "적용" 버튼까지 내려가면, 스캔 페이지 `ListView`가 화면 밖(기본 cache 250px 밖)으로 밀려난 맨 위 `RepositoryProfilePanel`을 버린다(keep-alive 없음).
2. 다음 `_notice`가 맨 위로 돌아오면 패널이 새로 만들어지고 `initState → _reload → listProfiles → onSelected(같은 계정)`이 같은 `pump()` 안에서 돈다.
3. 예전 `_selectProfile`은 같은 계정이어도 `_repositoryState`를 비우고 state를 다시 읽었다. 대역의 `failLoads`로 읽기가 실패하자 catch가 `_candidateNotice`를 통째로 바꿨다.
- 실제 앱에서도 사용자가 스캔 탭을 아래로 내렸다 올리면 같은 일이 생긴다. **같은 계정 재선택이 불필요한 state 재읽기를 하고 있었다**(스크롤로 패널이 다시 만들어질 때마다 목록 1번 + state 1번 + 학생·아이템 목록 읽기, 그동안 `_repositoryState`가 잠깐 비어 적용이 "상태가 없습니다"로 막힐 수 있었다). 별도 검토 에이전트가 같은 경로를 코드로 확인했다(패널의 다른 호출 계기는 만들기·선택·이름 변경·v6 가져오기 탭뿐).

### 수정 (`frontend/lib/ui/pages/scan_page.dart` `_selectProfile`만)

- 같은 계정을 다시 넘겼고 state cache가 있으며 목록 revision ≤ 권위 revision이면 **다시 읽지 않는다**(이름 등 표시만 받는다). 목록 revision이 더 높을 때(다른 곳의 저장·이름 변경)만 다시 읽는다.
- 같은 계정이면 `_profile` revision은 목록 값이 아니라 권위값을 유지한다(다시 읽기에 성공하면 그때 올라간다). `_repositoryState`도 비우지 않는다(다시 읽는 동안 이전 cache로 적용 가능). 다른 계정을 고르면 예전처럼 모두 비운다.
- 같은 계정 다시 읽기가 실패하면 직전 안내(적용 결과 등)를 지우지 않고 뒤에 줄을 바꿔 `프로필 현재값을 다시 읽지 못했습니다: …`를 덧붙인다(같은 실패는 한 번만). 처음 고른 계정의 실패 문구는 예전 그대로다.
- 테스트 기대는 바꾸지 않았다.

### 추가 테스트 (`frontend/test/scan_page_revision_test.dart`, 2건 → S-FB1b 새 테스트 모두 14건)

13. 스크롤로 다시 만들어진 패널(목록 호출 수 증가로 확인)이 최신 state를 다시 읽지 않는다(state 읽기 수 그대로).
14. 다른 곳의 저장으로 목록 revision이 권위값보다 높아진 뒤 같은 계정 다시 읽기가 실패하면, 앞의 "적용 결과를 확인하지 못했습니다" 안내가 남고 실패 줄이 덧붙는다. 그 뒤 다시 적용하면 고정 요청(같은 key·expected 0)이 receipt로 재생된다.
- 대역 `_RevisionScanService`에 `listCalls`(목록 호출 수)를 더했다.

### 검증

- 이 환경에는 Flutter가 없어 실행하지 못했다. 별도 검토 에이전트가 원인 경로, 실패했던 테스트의 통과, 새 2건의 기대값(800×600에서 패널이 실제로 버려졌다 다시 만들어지는지 포함), 나머지 S-FB1b·기존 scan 테스트의 결과 불변을 코드로 추적했다. 문제 없음.
- 괄호 균형, LF·끝 공백·파일 끝 개행 확인.

### 사본·commit.json

- post 사본 갱신: `debug/frontend_sfb1b/post/frontend/lib/ui/pages/scan_page.dart`(60584 bytes, sha256 `1eaa1716…`), `debug/frontend_sfb1b/post/frontend/test/scan_page_revision_test.dart`(25162 bytes). `scan_repository_sync.dart`는 바뀌지 않았다. pre 사본은 그대로(착수 전 내용).
- commit.json은 그대로다(바뀐 파일 집합이 같다: modified `scan_page.dart`, added `scan_repository_sync.dart`·`scan_page_revision_test.dart`).

### 다음 행동

1. 두 워커가 멈춘 뒤 `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1` 재실행 → 결과를 오케스트레이터에게. S-FB1b 쪽 예상: 새 14건 통과, 기존 scan 테스트 통과, golden 변화 0(다른 레인 RED는 위 범위 밖 항목).
2. 커밋 순서는 오케스트레이터가 정한다(종료 기록 발견 사항 1: S-FB2b와의 순서).
3. 발견 사항: 위 계정 패널(`RepositoryProfilePanel`, 공용 위젯)은 스크롤로 버려질 때마다 다시 만들어지며 목록을 다시 읽는다. 이번 수정으로 스캔 탭의 불필요한 state 재읽기는 막았지만 목록 읽기 자체는 남는다. 패널 상태 유지(keep-alive)나 스캔 탭 재구성(FE8-g1)에서 정리할 일이다.

## T-FB1b 착수 기록 (2026-10-10)

- 범위: 전술 탭(`tactical_page.dart`)의 revision 분리(CF 프롬프트 `debug/frontend_redesign_handoff/tfb1b-fe8b-worker-prompt-20261010.md` ①, 기준 XB 초안 `debug/xb_fb_history_port_review_20261010/artifacts/T-FB1b-work-instruction-draft.md`, FB-1b `11426131`).
  1. 병렬 읽기(repository state·tactical state·catalog) 뒤 profile 표시·cache의 profile revision은 반환 repository state가 권위값(목록 summary 값을 그대로 쓰지 않음, legacy 첫 이관 +1 포함).
  2. 필드 이름부터 profile(repository) revision과 tactical collection revision을 분리. tactical write(경기·족보·삭제)는 tactical revision만 쓴다.
  3. 머리 줄 표시 판단은 종료 기록에 적는다.
- 범위 밖: 계산식·battle rules·연구 evidence·v2 삭제 helper, `lib/services/**`, `app_shell.dart`.
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `18c5f0b0a14e95aaa48cbbb6e006db23f6b43f85`.
- 막힘: 열림 FD 없음.
- 고칠 기존 파일과 WIP(작업 트리 내용을 git index blob과 비교, 줄바꿈 차이 제외):

  | 파일 | WIP | 비고 |
  |---|---|---|
  | `frontend/lib/ui/pages/tactical_page.dart` | 없음(CRLF) | 줄바꿈 CRLF 그대로 둔다 |

  착수 전 사본 `debug/frontend_tfb1b/pre/frontend/lib/ui/pages/tactical_page.dart`, slice 끝 사본 `debug/frontend_tfb1b/post/<경로>`, commit.json `post_dir`(규칙대로).
- TacticalPage를 띄우는 테스트(grep): `frontend/test/tactical_page_test.dart`(고치지 않을 예정), 앱 셸(`app_shell.dart`)을 띄우는 테스트는 IndexedStack 안에서 같이 만든다(`widget_test.dart` 등, 기대 변화 없음 예정).
- 새 파일(예정): `frontend/test/tactical_page_revision_test.dart`.
- golden 변화 0 예정(전술 탭은 golden 장면에 없다).

## T-FB1b 종료 기록 (2026-10-10, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없다. analyze·테스트를 돌리지 못했으므로 통과를 주장하지 않는다.
- 정적 검토만 했다. 별도 검토 에이전트가 바뀐 파일을 원본·mock·기존 전술 테스트와 대조해 읽었다(컴파일·lint, 기존 테스트 회귀, 새 테스트 기대값 수치 추적, fake async 타이머, 삭제 버튼·확인 대화상자 탭 경로).
  - 막는 문제 1건을 고쳤다: 새 테스트의 쓰지 않는 `dart:async` import(analyze 실패 원인).
  - 사소한 지적 반영: 의미 없던 repository 쓰기 수 확인을 빼고, 족보 삭제가 tactical revision을 쓰는지 보는 테스트를 더했다.
- 내가 직접 한 것: CRLF 유지(883줄 모두 CRLF), 끝 공백·괄호 확인, commit.json JSON·ASCII 확인.

### 고친 파일

| 파일 | 내용 |
|---|---|
| `frontend/lib/ui/pages/tactical_page.dart`(WIP 없음, CRLF) | `_state` → `_tacticalState`로 이름 분리, getter `_profileRevision`(= 반환 repository state revision)·`_tacticalRevision`(= tactical collection revision). 병렬 읽기 뒤 `_profile`을 목록 summary 대신 `repositoryProfileWithRevision(selected, state.revision)`으로 둔다. 응답의 계정(profileId)이 선택 계정과 다르면 받지 않고 오류로 보인다. 경기·족보 저장과 삭제는 대화상자·확인 뒤에 계정 id와 tactical revision을 final 지역 변수로 받아 그 값만 expected·key에 쓴다. 계정이 없을 때 `_repositoryState`도 비운다. 읽기 오류를 "선택된 프로필이 없습니다"보다 먼저 보인다(첫 읽기 실패가 가려지던 문제) |
| 새 `frontend/test/tactical_page_revision_test.dart` | 아래 5건 |

머리 줄 표시 판단: `이름 · id · profile revision P · tactical revision T`로 둘 다 보인다(key `tactical-revision-line`). 두 값이 다르다는 것이 이 slice의 요점이고, 검수 때 legacy 이관(+1)이 profile 쪽에만 반영되는지 바로 볼 수 있다. 이 화면은 FE9에서 재작성되므로 문구 다듬기는 그때 한다.

### 새 테스트 (지운·고친 기존 테스트 없음)

1. legacy 계정(목록 0 → 첫 state 1)과 tactical 2: 머리 줄 `profile revision 1 · tactical revision 2`, 경기 삭제 expected 2·key `…-2`, 뒤 `tactical revision 3`, profile 1 그대로.
2·3. 병렬 읽기 응답 순서 두 가지(repository 먼저 / tactical 먼저, 50ms 지연): 완료 순서 기록, 머리 줄 `profile revision 7 · tactical revision 2`, 삭제 expected 2(profile 7 아님), 뒤 tactical 3.
4. 족보 삭제: profile 5 · tactical 2에서 expected 2, key `delete-jokbo-1-2`, 뒤 tactical 3.
5. 다른 계정의 tactical 응답: 오류 문구(`선택 계정과 다른 계정의 응답…`)가 보이고 머리 줄은 `tactical revision -`.

TacticalPage를 띄우는 기존 테스트(`tactical_page_test.dart`, 앱 셸을 띄우는 테스트)는 바꾸지 않았다. 바뀐 문구·오류 순서를 찾는 기존 테스트는 없다(grep).

### WIP 보존 확인

- `tactical_page.dart`는 착수 때 index와 같았다(WIP 없음). 착수 전 사본 `debug/frontend_tfb1b/pre/frontend/lib/ui/pages/tactical_page.dart`(31,149 bytes), slice 끝 사본 `debug/frontend_tfb1b/post/frontend/lib/ui/pages/tactical_page.dart`(33,237 bytes, sha256 `6b0278a4…`), 새 테스트 끝 사본 `debug/frontend_tfb1b/post/frontend/test/tactical_page_revision_test.dart`. commit.json `post_dir: debug/frontend_tfb1b/post`, `status=false`, `whole=[]`(이 문서는 FE8-b commit.json이 가져간다).

### 미검증 항목

- analyze·테스트 미실행. golden 변화 0 예상(전술 탭은 golden 장면에 없다).
- 삭제 버튼 탭이 `DiagonalSection` 자르기 밖에 떨어질 가능성은 낮다고 봤다(1440×900, 기존 테스트가 같은 크기에서 같은 tooltip을 찾는다).

### 발견 사항

1. 다시 읽기가 실패해도 이전 tactical state가 남아 이전 revision으로 쓰기가 가능하다(기존 동작). 서버가 `revision_conflict`로 막고, 화면은 "저장하지 못했습니다. 새로고침 후 다시 시도하세요."를 보인다. FE9-a 재작성 때 쓰기 버튼을 오류 상태에서 막을지 정하면 된다.

## FE8-b 착수 기록 (2026-10-10)

- 범위: FD-113 중 FE8-b 몫(레일 높이 74·목록 사선 따라 폭 감소·pressed 분홍 테두리·"이 계정으로 전환" 비활성 + "지금 쓰는 계정", 계정 행 그라데이션 + 진행 막대 + `지금` 칩, 선택 행 #f2b3ef 3.2px, 목록 하단 포그, 바깥 Section 5 사다리꼴 표면 제거)과 계정 추가 = 이름만 받는 모달(스크림 .72 + blur 2, 평행사변형, 제목 옆 (i), X·취소·만들기). FD-114(워커 재량, 권장안): 첫 실행 흐름은 현행, 첫 계정 만들기와 `title-account-dialog`를 새 모달로 통일, v6 가져오기 진입점은 현행. FE8-a에서 넘어온 T 표 밖 차이 4건(설정·나가기 외곽선, `나가기` 15 w700, 계정 카드 채움 .9 + 외곽선, 버튼 반경 8).
- 범위 밖(FE8-c): 편집 패널 1000×262·입력 fill·분홍 포커스·초상 6열·편집 패널 확장·메타 줄 "마지막 스캔".
- 시작 커밋(HEAD): `18c5f0b0a14e95aaa48cbbb6e006db23f6b43f85`(T-FB1b와 같은 세션, T-FB1b는 아직 미커밋이며 파일이 겹치지 않는다).
- 막힘: 대장 막힘 요약에서 FE8-b는 `—`(열림 없음).
- 고칠 기존 파일과 WIP(작업 트리 내용을 git index blob과 비교, 줄바꿈 차이 제외) — 모두 WIP 없음, LF:
  - `frontend/lib/ui/pages/title_page.dart`
  - `frontend/lib/ui/widgets/account_section_cluster.dart`
  - `frontend/lib/ui/studio/account_studio_layout.dart`(계정 클러스터 Studio 저장 문서는 `release/`(git 밖)에만 있어 typed projection만 고친다)
  - `frontend/test/title_page_test.dart`
  착수 전 사본은 `debug/frontend_fe8b/pre/<경로>`.
- 새 파일(예정): `frontend/lib/ui/widgets/account_create_modal.dart`(키트 `BaModal`·`InfoPopover`를 import해서 쓴다. 키트 파일은 고치지 않는다), `frontend/test/account_manager_fe8b_test.dart`, `frontend/test/goldens/fe8b_account_new_golden_test.dart`(harness 공개 함수만), 기준 이미지 `frontend/test/goldens/baseline/account-new.png`(사용자 `-UpdateGoldens`).
- 고치지 않는 것: `lib/services/**`, 계획·학생 화면, `golden_harness.dart`·기존 golden 테스트, `app_shell.dart`, `almanac/design/**`(`section-template-studio.md`는 읽기만, 바뀔 규칙은 발견 사항에), 키트.

## FE8-b 종료 기록 (2026-10-11, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없다(SDK 내려받기도 프록시가 막는다). analyze·테스트·golden을 돌리지 못했으므로 통과를 주장하지 않는다.
- 정적 검토만 했다. 별도 검토 에이전트가 바뀐 파일을 원본·키트·mock·golden harness와 대조해 읽었다(쓴 API의 존재·시그니처, const, record 목록 타입 추론, ParentData 위치, `BaModal` `initiallyOpen` 경로, 새·바뀐 테스트의 key 유일성과 기대값 직접 계산).
  - 컴파일·analyze 지적은 없었다.
  - 테스트가 깨질 지적 3건을 고쳤다:
    - 진행 막대를 key로 바로 `SkewBar`로 읽던 것 → 자손 `SkewBar`로 읽는다.
    - 실패 테스트에서 `enterText` 뒤 pump가 없어 `만들기`가 아직 비활성이던 것.
    - 작은 창 편집기 테스트에서 `뒤로`가 관리 레일과 편집기에 둘인 것 → 버튼 안 글자만 찾는다.
  - 동작 지적 4건을 고쳤다:
    - 만드는 중 Esc로 닫히던 것. 키트 Esc는 컨트롤러 `close`를 직접 부르므로, 만드는 동안 닫지 않는 컨트롤러 하위 클래스를 cluster 안에 두었다.
    - `createProfile` 뒤 mounted 확인이 없던 것.
    - 계정 이름이 줄어든 폭에서 한 번 더 줄던 것 → 기준 폭에서 놓고 한 번만 줄인다.
    - 행 크기 비교를 정확 일치에서 허용 오차 비교로 바꿨다.
- 내가 직접 한 것: 모든 새·바뀐 Dart 파일이 LF·끝 공백 없음·끝 개행 하나·괄호 짝 맞음인지 확인했다. 2560×1392 기준 기하(목록·레일·행·stucard·행 x·모달 위치)는 Python으로 다시 계산해 테스트 값과 맞췄다. commit.json은 JSON·ASCII다.
- 시안 값은 `Title-Accounts.dc.html`·`Title-Accounts-New.dc.html`에서 목록·레일·행·모달 요소를 골라 읽었다.

### 고친 파일

- **`frontend/lib/ui/widgets/account_section_cluster.dart`**
  - 관리 화면(FD-113 FE8-b 몫):
    - 바깥 Section 5 사다리꼴 표면(`account-manager-base-surface`)을 없앴다. 목록 패널(container-11, 평행사변형 r14, 채움 rgba(29,42,58,.9))이 그림자를 가진다. 섹션 rect는 이동·검수용 표지로만 남는다.
    - 레일 5개(전환·추가·수정·삭제·뒤로)는 높이 74, 왼쪽 수직, 오른쪽 사선이 목록 왼쪽 사선과 가로 22px(기준 viewport, 창 크기에 비례) 떨어져 나란하다. 그래서 아래 레일일수록 좁다(`accountManagerRailPath`).
    - 레일 내용: 시안 svg 아이콘 17 + 글자 15 w700, 삭제는 #ffb3bb. 외곽선 rgba(56,81,107,.72) 1.8. 지금 열린 모드(추가 모달, 수정 편집기)의 레일은 누른 상태 #f2b3ef 3.2.
    - "이 계정으로 전환": 고른 계정이 지금 쓰는 계정이면 비활성(덮개 .35, 내용 불투명도 .42)이고 아래에 `지금 쓰는 계정`(10.5 w600 #f7c9f4)을 붙인다.
    - 계정 행:
      - 배경 `linear-gradient(120deg, rgba(47,74,102,.75), rgba(29,42,58,.85))`, 외곽선 rgba(56,81,107,.7) 1.2, 고른 행 #f2b3ef 3.2.
      - 학생 카드와 같은 평행사변형 stucard(흰 외곽선).
      - 이름(경기천년제목 17) 옆에 지금 쓰는 계정이면 분홍 `지금` 칩(키트 `BaChip`).
      - 보유율 진행 막대(키트 `SkewBar`, 높이 4). `보유` · 보유 수 · `/ 전체`. state를 못 읽은 계정은 `보유 읽지 못함`.
      - 행 왼쪽 사선도 목록 왼쪽 사선에서 22px 안쪽이다(`accountManagerRowLeft`, 스크롤해도 유지).
    - 스크롤바는 키트 표준 스타일(썸 #e5a0ea), 목록 오른쪽 사선에서 24px 안쪽이다. 목록 아래에 키트 포그가 있다.
  - 계정 추가(FD-113·FD-114):
    - "추가"는 새 모달을 연다. 이름만 받아 `createProfile`로 빈 계정을 만들고(초상 기본 `hasumi`), 목록을 다시 읽어 그 계정을 고른다. 지금 쓰는 계정은 바꾸지 않는다.
    - 첫 계정 만들기(`AccountClusterEntry.createFirst`)도 같은 모달을 처음부터 열어 둔다. 만들면 선택하고 홈으로 간다. 만들지 않고 닫으면(취소·X·Esc·스크림) 타이틀로 돌아간다.
    - 편집기는 이제 고른 계정의 이름·초상 수정만 한다. 새 계정 만들기 분기를 뺐다.
    - 만드는 동안에는 모달이 닫히지 않는다.
  - `AccountPathOutlinePainter`를 공개했다(테스트가 색·두께를 읽는다).
  - 초상 고르기 스크롤바·편집기는 그대로다(FE8-c).
- **새 `frontend/lib/ui/widgets/account_create_modal.dart`**(패널만, 스크림·포커스·Esc는 키트 `BaModal` + `BaScrim.scan`)
  - 1000×330 평행사변형(r18, 채움 .98, lifted shadow). 2560×1392에서 900,520에 놓이고, 창이 작으면 비율대로 줄어든다.
  - 제목 `계정 추가`(분홍 사선 막대 + 경기천년제목 24) + (i)(키트 `InfoPopover`).
  - X 58×40. `계정 이름` 입력 821.8×56: 채움 rgba(10,16,24,.55), 포커스 #f2b3ef 2.4, 평소 .72 1.2. 열리면 입력에 포커스가 간다.
  - 취소·만들기 130×56. 만들기는 분홍 외곽선이고, 이름이 비었거나 만드는 중이면 비활성이다. 실패 문구는 모달 안에 보인다.
- **`frontend/lib/ui/pages/title_page.dart`**(FE8-a 발견 사항 3)
  - 설정·나가기·시작 버튼 path 반경 8(`titleButtonRadius`, 새 공개 함수 `titleStudioContainerPath`).
  - 설정·나가기 외곽선 rgba(56,81,107,.72) 1.8.
  - `나가기` 15 w700 흰색.
  - 계정 카드 채움 .9 + 외곽선 rgba(56,81,107,.6) 1.2.
  - 쓰이지 않던 `_createAccount`(`title-account-dialog`)를 지웠다(FD-114).
- **`frontend/lib/ui/studio/account_studio_layout.dart`**: 관리 화면 컨테이너 11~16·18·19와 행 feature 5~7을 시안 값으로 바꿨다. 기준 viewport 2560×1392에서:

  | 대상 | 시안 값 |
  |---|---|
  | 목록 | 29.2,36 870.8×1320 |
  | 레일 | x 14, y 44/135/226/317/408, 높이 74 |
  | 첫 행 | 255.4,56 597×142 |
  | stucard | 140.82×114 |

- **새 `frontend/assets/studio_sections/section-account-create-manager.ba-section-studio.json`**(git 추적 사본, 들여쓰기 2, 끝 개행 없음)
  - 착수 기록에서는 typed projection만 고칠 계획이었다. 하지만 projection 테스트의 원본이 git 밖 `release/` 사본이라, FE8-a 선례대로 추적 사본을 새로 두고 테스트가 그것을 읽게 했다.
  - feature-5·7 문구는 시안 예시(`거모이는존재한다 (v7 UI 테스트)`, `보유 217 / 265`)다.
- **`frontend/test/title_page_test.dart`**(25건 → 25건, 지운 테스트 없음)
  - `typed account layout matches the saved Studio document`: assets 사본 + Studio 불러오기 왕복.
  - `title follows the section studio placement and account state`: 버튼 path가 반경 8로 그린 path와 같은지, 설정·나가기 외곽선 색·두께·path, `나가기` 15 w700, 계정 카드 채움 .9·외곽선.
  - `account manager uses Studio paths …`:
    - 바깥 표면 없음.
    - 목록 표면 path·채움·그림자.
    - 레일 높이·간격·목록과 22px·아래로 갈수록 좁음.
    - 행 상자 크기·위치, 행 사선 22px.
    - stucard·이름·진행 막대(높이 4)·보유 줄 위치.
  - `account rows follow the slanted list boundary while scrolling`: 새 목록·행 path.
  - 첫 계정 흐름:
    - `first account editor back returns to the title`를 `first account modal cancel returns to the title`로 바꿨다.
    - `an account can be created from the title then enters home`은 모달로 만든다(빈 이름이면 만들기 비활성).
  - 작은 창 편집기 테스트는 관리 → 수정으로 편집기를 연다.
  - 이관 실패 계정 문구는 `읽지 못함`이다.
- **새 `frontend/test/account_manager_fe8b_test.dart`**(5건)
  - 2560×1392 기하를 시안 값과 비교.
  - CSS 각도 → Alignment.
  - 레일 상태(높이·외곽선·전환 비활성·`지금 쓰는 계정`·수정 누름), 행 상태(칩·외곽선·그라데이션·막대·보유 줄·포그), 다른 계정 고르기.
  - 모달:
    - 스크림 .72 + blur 2, 패널 900,520 1000×330, 제목·(i)·X, 초상 고르기 없음.
    - 추가 레일 누름.
    - 취소·Esc·만들기(새 계정 선택, 지금 쓰는 계정 유지).
  - 실패하면 모달이 열린 채 문구가 보인다.
- **새 `frontend/test/goldens/fe8b_account_new_golden_test.dart`**(golden 태그, harness 공개 함수만)
  - 장면 `account-new`: 타이틀 → 설정 → 추가.
  - 이름 입력에 포커스가 있어 `EditableText.debugDeterministicCursor`를 켜고, 테스트 뒤 되돌린다.
  - 기준 이미지 `frontend/test/goldens/baseline/account-new.png`는 사용자 `-UpdateGoldens`로 만든다.

### 검수표 (artboard `Title-Accounts.dc.html`·`Title-Accounts-New.dc.html`)

앱에서 여는 방법: mock 모드(`--dart-define=BA_PLANNER_USE_REAL_BACKEND=false`)로 실행하고 2560×1440 모니터에서 최대화한다. 타이틀에서 설정(톱니) 또는 계정 카드를 누르면 관리 화면이다. 추가 모달은 "추가" 레일이다. mock 계정은 `Main` 하나(지금 쓰는 계정)라, 전환 활성 상태는 "추가"로 계정을 하나 만든 뒤 그 행을 눌러 본다.

| # | 확인 포인트 | 코드 |
|---|---|---|
| A1 | 바깥 사다리꼴 표면이 없고, 목록 패널(29.2,36 870.8×1320, 모서리 14, 채움 .9)만 그림자와 함께 떠 있다 | `account-profile-list-surface` |
| A2 | 레일 5개 높이 74, x 14, y 44/135/226/317/408. 오른쪽 사선이 목록 사선과 22px 간격으로 나란하고 아래로 갈수록 좁다 | `accountManagerRailPath` |
| A3 | 레일 아이콘(전환·더하기·연필·휴지통·화살표) + 글자 15 굵게, 삭제는 연한 빨강, 외곽선 .72 1.8 | `_AccountRailLabel` |
| A4 | 지금 쓰는 계정을 고르면 "이 계정으로 전환"이 흐려지고 아래에 `지금 쓰는 계정`. 다른 계정을 고르면 활성 | `account-switch-disabled` |
| A5 | 추가 모달·수정 편집기가 열려 있는 동안 그 레일 외곽선이 분홍 3.2 | `<레일>-outline` |
| A6 | 계정 행 597×142, 대각 그라데이션, 외곽선 .7 1.2. 고른 행은 분홍 3.2. 행 왼쪽 사선이 목록 사선에서 22px 안쪽이고 스크롤해도 유지 | `_AccountListItem` |
| A7 | stucard가 학생 카드 모양 평행사변형 + 흰 외곽선 | `account-profile-portrait-<id>` |
| A8 | 이름 옆 분홍 `지금` 칩(지금 쓰는 계정만), 아래 보유율 막대(높이 4, 기울임), `보유 n / 전체` | `account-profile-current-/progress-/count-<id>` |
| A9 | 스크롤바 썸 분홍(#e5a0ea), 계정이 많으면 목록 아래 포그 | `account-profile-fog` |
| N1 | 스크림이 어둡고(.72) 뒤가 살짝 흐리다(blur 2) | `BaScrim.scan` |
| N2 | 패널 1000×330 평행사변형이 900,520에 있다. 제목 `계정 추가` 앞 분홍 막대, 옆 (i). 오른쪽 위 X | `account-create-modal` |
| N3 | `계정 이름` 입력: 열리자마자 포커스, 분홍 2.4 외곽선. 이름 말고 다른 입력(초상 등)은 없다 | `account-create-input-box` |
| N4 | 취소·만들기(분홍 외곽선). 이름이 비면 만들기가 흐리다. 만들면 모달이 닫히고 새 계정이 목록에서 골라진다 | `account-create-cancel`·`-submit` |
| N5 | Esc·스크림·X·취소로 닫힌다. 첫 실행(계정 없음)에서 닫으면 타이틀로 돌아가고, 만들면 바로 홈이다 | `_createModalChanged` |
| T12 | 타이틀: 설정·나가기·시작 모서리가 조금 더 각지다(8). 설정·나가기에 얇은 외곽선, `나가기` 15 굵게, 계정 카드가 더 불투명(.9) + 얇은 외곽선 | `title-*-outline`, `title-exit-label` |

### 처리한 FD

- **FD-113**: FE8-b 몫은 모두 반영했다(고친 파일 참고). 편집 패널 1000×262·입력 채움·분홍 포커스·초상 6열·편집 패널 확장·"마지막 스캔"은 FE8-c라 손대지 않았다.
- **FD-114**(워커 재량, 권장안): 첫 실행 흐름(계정 없음 → `계정 생성` → v6 계정이 있으면 가져오기 대화상자)은 그대로다. "새 계정 만들기"를 고르거나 v6 계정이 없을 때 여는 것이 편집기 대신 새 추가 모달이다. 쓰이지 않던 `title-account-dialog`는 지웠다. v6 가져오기 진입점은 그대로다.
- **FD-001**: 목록 패널 .9와 타이틀 계정 카드 .9는 공용 섹션 표면 .76의 예외로 시안을 따랐다.
- **FD-015 (a)**: 레일 버튼 절차 텍스처(seed 6229)는 그대로다. 모달 취소 버튼도 같은 팔레트 절차 텍스처, 만들기는 타이틀 시작 버튼 텍스처다.

### golden 예측

바뀔 장면(4 + 새 1):
- `title`:
  - 설정·나가기·시작 모서리 반경 10 → 8.
  - 설정·나가기 외곽선이 생긴다.
  - `나가기` 글자가 15 w700 흰색이 된다(이전엔 테마 기본 글자).
  - 계정 카드 채움 .76 → .9, 외곽선이 생긴다.
- `account-manager`:
  - 바깥 Section 5 표면이 사라진다. 그림자는 목록 패널을 따른다.
  - 목록이 시안 위치·크기로 바뀌고 채움 .9가 된다.
  - 레일 5개의 위치·크기·폭·아이콘·글자·외곽선이 바뀐다. mock `Main`은 지금 쓰는 계정이라 전환 레일이 흐리고 `지금 쓰는 계정`이 붙는다.
  - 행: 그라데이션·외곽선(분홍 3.2), stucard 모양, `지금` 칩, 진행 막대, 보유 줄이 바뀐다.
  - 스크롤바 썸 색·위치가 바뀐다. 계정이 하나라 스크롤이 없으므로 포그는 그려지지 않는다.
- `account-editor`: 편집기 자체는 그대로다. 그 뒤에 남은 관리 화면이 위처럼 바뀌고, 수정 레일 외곽선이 분홍 3.2가 된다.
- `account-picker`: `account-editor`와 같은 이유(뒤의 관리 화면 + 수정 레일 누름). 초상 고르기는 그대로다.
- `account-new`(새 기준 이미지): 관리 화면 위 스크림 + 추가 모달, 입력 포커스(커서 고정).

바뀌지 않을 장면: `home`(타이틀 없이 셸), 학생·계획·스캔 장면(타이틀·계정 클러스터를 거치지 않는다).

commit.json `whole`에는 `title.png`·`account-manager.png`·`account-editor.png`·`account-picker.png`를 하나씩 넣었고, `account-new.png`는 `added`다. gate ①에서 이 밖의 장면이 RED면 예측이 틀린 것이니 갱신하지 말고 알려 달라.

### 미검증 항목

- analyze·일반 테스트·golden·`codealmanac validate`·`git diff --check` 전부 미실행(사용자 PC gate 필요).
- `BaModal`을 `initiallyOpen: true` 컨트롤러로 띄우는 것은 이번이 처음이다(키트 테스트에 없다). 코드상으로는 첫 프레임에 오버레이가 열린다.
- 둥근 path bounds: `Path.getBounds`가 실제 bounds이면 80° 꼭짓점에서 약 2.7px 안쪽이다. 테스트는 목록 bounds를 3px까지 허용하고, 22px 간격은 모서리에서 먼 세로 가운데에서 잰다.
- 경기천년제목은 Medium(500) 한 굵기만 등록되어 있다. 모달 제목·계정 이름은 시안과 같은 500이지만 `계정 이름` 머리글(800)은 합성 굵게일 수 있다.
- 레일 아이콘은 시안 svg path를 옮겨 그렸다(선 두께 2, 둥근 끝). 17px 크기에서 원호 방향이 시안과 다를 수 있다(눈 검수 A3).
- 계정 이름이 길면 Studio 규칙대로 `FittedBox.scaleDown` + 말줄임이다. 시안은 말줄임만이다.
- 만드는 중 Esc는 막지만, 키트 Esc 처리는 닫기를 부르기 전에 등록을 지운다. 그래서 만들기가 실패한 뒤에는 그 모달에서 Esc가 듣지 않는다(X·취소·스크림은 된다). 발견 사항 2.
- 진행 막대·보유 줄·이름의 세로 위치는 Studio feature 비율(시안 행 안 y 36/72/88)로 놓았다(±2px).

### 발견 사항

1. `almanac/design/section-template-studio.md`「Title 계정 생성·관리 클러스터」절에 반영할 규칙(이 slice는 고치지 않았다):
   - 관리 섹션(element-5)은 표면을 그리지 않는다. 보이는 표면은 목록 컨테이너(container-11, r14, 채움 .9 = 공용 표면 예외)다.
   - 레일(container-12·13·14·18·19)은 왼쪽 사다리꼴이다. 런타임 폭은 Studio rect 폭이 아니라 "오른쪽 사선이 목록 왼쪽 사선과 22px(기준 viewport 비례)" 규칙으로 정한다. Studio rect 폭은 2560×1392에서 같은 값이 되게 저장했다.
   - 행(container-15)은 템플릿이다. 런타임 x는 목록 왼쪽 사선 + 22px이고 스크롤 위치를 따른다. feature-6은 구분선이 아니라 진행 막대(높이 4, feature 중심)다.
   - 계정 추가는 Studio 섹션이 아니라 키트 모달(고정 1000×330 패널)이다. 첫 계정 만들기도 이 모달이고, 편집기(element-1)는 수정 전용이다.
   - 저장 문서 원본은 `frontend/assets/studio_sections/section-account-create-manager.ba-section-studio.json`(추적)이다. `release/` 같은 이름 사본은 이제 이전 배치다. 맞추려면 `Copy-Item "frontend\assets\studio_sections\section-account-create-manager.ba-section-studio.json" release\ -Force`(선택, `release/**`는 XB 폴더).
2. Lane A 키트 요청(고치지 않음):
   - 레일 아이콘 5종(전환·추가·수정·삭제·뒤로)을 `KitGlyph`로 올려 달라. 지금은 cluster의 private painter다.
   - 평행사변형 모달 패널: `BaModalPanel`의 평행사변형 변형이 있으면 `account_create_modal.dart`의 패널을 옮긴다.
   - `BaModal`에 "지금은 닫지 않음" 옵션이 필요하다(작업 중 Esc 막기). 지금은 컨트롤러 `close`를 막는 하위 클래스로 피했다. 키트 Esc 처리가 닫기를 부르기 전에 등록을 지우므로 막은 뒤에는 Esc가 다시 듣지 않는다.
3. (i) 팝오버(제목 `계정 추가`, 너비 340, 시안 문구 그대로)는 기본으로 닫혀 있다. 시안에서는 마우스를 올리면 뜨는 `.pop` 풍선이다(키트 `InfoPopover` 동작을 따랐다).
4. 첫 계정은 초상 선택 없이 `hasumi`로 만들어진다. 이전 흐름(편집기)은 첫 계정 초상을 고를 수 있었다. 바꾸려면 만든 뒤 "수정"이다(FD-114 권장안대로 이름만).
5. 편집기에 남은 해요체 문구 `계정명을 입력하세요`와 삭제 확인 `…삭제할까요?`는 FE8-c(편집 패널) 때 습니다체로 바꿀 후보다.
6. 계정 만들기 실패 문구는 알려진 저장소 코드만 우리말로 바꾸고(`repositoryLoadErrorText`), 나머지는 원문 오류를 붙인다.

### 다음 행동

- T-FB1b와 FE8-b 코드는 끝났다. Lane B는 여기서 멈춘다.
- gate 결과를 받으면 RED 원인을 보고 고친다. golden은 오케스트레이터 승인 뒤 갱신한다.
- 다음 Lane B slice(FE8-c 편집 패널 등)는 오케스트레이터가 정한다.

## 사용자 실행 명령 (T-FB1b·FE8-b, 2026-10-11)

PowerShell, `C:\Users\brigh\planner_of_plana\BA Planner\v7`에서. 명령은 한 줄씩 실행하고, 하나가 실패하면 거기서 멈추고 결과를 오케스트레이터에게 보낸다.

1. Lane A·B 두 워커가 모두 멈춘 뒤 실행하고, 결과(`debug/frontend_gate/` 요약)를 오케스트레이터에게 보낸 뒤 기다린다. 예상 golden RED: `title`·`account-manager`·`account-editor`·`account-picker`와 기준 이미지가 없는 `account-new`.
   - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1`
2. 오케스트레이터 승인 뒤:
   - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1 -UpdateGoldens`
   - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1`(GREEN 확인)
3. 커밋(순서는 오케스트레이터가 정한다):
   - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice tfb1b -DryRun`
   - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice tfb1b`
   - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice fe8b -DryRun`
   - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice fe8b`

## FE8-b gate ① RED 수정 기록 (2026-10-11, 코드 수정 완료·gate 미실행)

gate ① `debug/frontend_gate/20261011_012751`에서 FE8-b 테스트 13건(`account_manager_fe8b_test.dart` 3건, `title_page_test.dart` 10건)과 golden 4장(`account-manager`·`account-editor`·`account-picker`·`account-new`)이 같은 assertion으로 실패했다:

`ScrollController attached to multiple scroll views ('_positions.length == 1')`

뒤따른 "Looking up a deactivated widget's ancestor"는 이 오류의 연쇄다. T-FB1b는 녹색이었고, `title` 장면 차이는 예측과 같았다(오케스트레이터 확인).

### 원인 (오케스트레이터 추정 확인: 목록 다시 마운트)

- 관리 화면 `_buildManager`의 Stack에서 FE8-b가 목록(`Positioned` → `ClipPath` → 사선 스크롤바 → `ListView`) **앞에** 조건부 자식을 넣었다. 비활성 레일 덮개(`<레일>-disabled`)가 그것이다.
  - 착수 전 코드는 목록 앞 자식 수가 고정이었고, 조건부 자식은 목록 뒤의 빈 목록 문구 하나뿐이었다(pre 사본 확인).
- 관리 화면을 열면 처음에는 로딩 중(바쁨, 계정 0개)이라 레일 5개가 모두 비활성이고 빈 목록 문구가 있다. 로드가 끝나면 덮개가 1개(지금 쓰는 계정의 전환)로 줄고 빈 목록 문구가 사라진다. 이 두 변화가 한 번의 rebuild에 함께 일어난다.
- Flutter의 자식 맞추기(updateChildren)에서 일어난 일:
  - 앞쪽은 덮개가 줄어든 자리에서 맞추기가 멈춘다.
  - 뒤쪽은 key 없는 `Positioned`끼리라 새 목록 `Positioned`가 옛 빈 목록 문구 element에 맞춰졌다. 그 아래가 다른 위젯이라 `ListView`가 새로 마운트되었다.
  - 옛 목록 element는 비활성화만 되고 프레임 끝까지 dispose되지 않는다. 그래서 그 프레임 동안 `_profileListController`에 position이 둘이다.
  - 그때 새 항목 빌더의 `AnimatedBuilder`가 `_profileListController.offset`을 읽어 assertion이 났다.
- 모달 열기·닫기, 진입 모션, `showFog`, BaModal 감싸기는 원인이 아니었다. 모두 위젯 종류·순서가 고정이다.

### 수정 (`frontend/lib/ui/widgets/account_section_cluster.dart`만)

권고 ①·② 둘 다 했다. 테스트 기대는 바꾸지 않았다.
1. 다시 마운트를 없앴다. 상태에 따라 수가 바뀌는 자식의 앞뒤에 key를 두었다:
   - 목록 상자 `Positioned`: `account-profile-list-box`
   - 빈 목록 문구: `account-profile-list-empty`(`_positionedContent`에 선택 `key`)
   - 레일 텍스처 표면: `<레일>-surface`

   이제 목록은 key로 맞춰져 같은 element·같은 ScrollPosition을 유지한다.
2. 행 항목은 컨트롤러 전체 `offset` 대신 자기가 속한 Scrollable의 position(`Scrollable.of(context).position`)을 읽는다. `AnimatedBuilder`의 animation도 그 position이다. 컨트롤러에 position이 잠깐 둘이어도 assertion이 나지 않는다. 사선 스크롤바(키트)는 목록의 조상이라 새 목록이 붙기 전에 빌드되므로 같은 문제가 없다.

초상 고르기 격자(`_portraitGridController.offset`)는 그 Stack에 조건부 자식이 없어 그대로 두었다(FE8-c 범위).

### 추가 테스트 (`frontend/test/account_manager_fe8b_test.dart`, 5건 → 6건)

`the account list stays mounted through entry, loading, switching and the modal`:
- 2560×1392에서 계정 둘로 시작한다. 타이틀 → 관리를 연 첫 프레임의 목록 `ScrollableState`를 잡는다.
- 다음 구간에서 프레임마다 확인한다:
  - 진입 모션 + 첫 로드 30프레임
  - 다른 계정으로 전환(바쁨 → 덮개가 생겼다 사라짐) 10프레임
  - 추가 모달 열기 5프레임, 닫기 5프레임
- 각 프레임에서 확인하는 것: 예외 없음, 목록 Scrollable이 하나, 처음과 같은 `ScrollableState`.

수정 전 코드에서는 첫 로드 프레임에서 실패한다.

### 검증

- 정적 검토만 했다(Flutter·Dart 없음). 바뀐 두 파일은 LF·끝 공백 없음·괄호 짝 맞음이다.
- 실패 13건과 golden 4장은 모두 위 assertion 하나로 그려지지 못했다. 그래서 이 assertion 뒤에 가려진 다른 실패가 있는지는 gate 재실행에서 처음 드러난다.

### 사본·commit.json

- post 사본을 끝 상태로 갱신했다:
  - `debug/frontend_fe8b/post/frontend/lib/ui/widgets/account_section_cluster.dart`
  - `debug/frontend_fe8b/post/frontend/test/account_manager_fe8b_test.dart`
- `debug/frontend_fe8b/commit.json`은 바뀐 파일 목록이 같아 그대로다.

### 다음 행동

위 "사용자 실행 명령"을 1번(`fe_gate.ps1`)부터 다시 한다. 예상 golden RED: `title`·`account-manager`·`account-editor`·`account-picker`, 그리고 기준 이미지가 없는 `account-new`. Lane B는 여기서 멈춘다.

## fb3-dart 착수 기록 (2026-10-11, 진행 중)

- 시작 조건 확인: `almanac/workflows/backend-orchestrator-log.md` 끝에 XB "FB-3 source26 메인 반영 완료·backend/contracts 고정"(XB 보고 03:16)이 있다.
  - 처음 읽었을 때(03:14 무렵)는 XB 세션 시작 항목만 있어서 읽기·계획만 했다.
  - 반영 완료 기록을 확인한 뒤에 코드를 고치기 시작했다.
- 범위: CF 로그 10-11 00:02 "커밋 전 정확 Dart 변경 목록" 표의 행을 그대로 구현한다. 날짜 경계는 00:11(year 1..9999, `0000-01-01` 거부), 재화 guard는 02:09(`invalid_payload` + `reason=currency_read_only`), 소스는 01:27 source26을 따른다. 인벤토리 화면의 재화 행은 읽기 전용으로 바꾼다(00:02 "Currency editor UI follow-up").
- 범위 밖:
  - FD101 UI 어댑터(`PlanFlowStageCost` ID 보존 등)는 FE6-a 몫이다(CF 03:20).
  - backend/**·contracts/**는 XB 소유다.
  - 계획·학생 화면, golden harness·golden 테스트·기준 이미지는 Lane A 소유다.
  - `app_shell.dart`, `scan_page.dart`·`tactical_page.dart`의 동작은 건드리지 않는다.
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `84f645c391f54cc312ce12f21d85ed34789f325b`.
- XB 반영 SHA 대조: 메인 작업 트리 파일을 직접 읽어 SHA256을 XB 03:16 표와 비교했다.
  - 비교한 파일: 계약·fixture 8개, `README.md`, `backend/core/{inventory_catalog,protocol_v1,repository_store,resource_acquisition}.py`, `backend/tests/test_inventory_currencies_fb3b.py`·`test_resource_acquisition_fb3c.py`.
  - 결과: 모두 일치한다. 계약·fixture 8개의 SHA는 아래 표와 같다.

  | 경로 | SHA256 |
  |---|---|
  | `contracts/planning-inventory-catalog-v1.schema.json` | `f54f5f9f2a42e37d7184462b22c68ada06f0f24d679157d968e404f1035ae6bd` |
  | `contracts/planning-inventory-acquisition-get-v1.schema.json` | `40bb6db9b8c2b9ca71430a0f82ad626393e3a43484f96fef463d382b0573cac1` |
  | `contracts/planning-protocol-v1.schema.json` | `bbe811baf4c2e22264075fc37b46760ea5052ec125b66d2a3286c0cb34350071` |
  | `contracts/protocol-error-v1.schema.json` | `8890bc1fcbce8c2e763312c2600634221976b9fcbeeb8c88cf1ca88a16021842` |
  | `contracts/fixtures/inventory_catalog_fb3_metadata.json` | `a25af4aed55947a946665c122ede19562dfa0594841ad34fa508ae655fb40808` |
  | `contracts/fixtures/resource_acquisition_v1.json` | `22eb6845d7c597189c32cf696e38a4608dbd755f5c96e87c2b04edca5f8b7a9d` |
  | `contracts/fixtures/planning_protocol_v1.json` | `64e36b1b4012680a820278bde395af98a53725a20d6d8aba3afe0c374703d183` |
  | `contracts/fixtures/inventory_catalog_v6_parity.json` | `2d6fa950c4a1f395219cf5360fcbea95711afbb1328428bf7c11bab774c05c40` |

- 막힘: 없음.
- 고칠 기존 파일과 미커밋(WIP) 여부. 작업 트리 내용을 git index blob과 비교했고, 줄바꿈 차이는 제외했다. 호출처는 편집 전에 다시 grep했고, XB 목록과 같다.

  | 파일 | WIP | 비고 |
  |---|---|---|
  | `frontend/lib/services/app_service.dart` | 없음(LF) | |
  | `frontend/lib/services/planning_protocol_client.dart` | 있음(CRLF, LF 줄 일부) | 스캐너 WIP: 오류 code 5줄, `scanner.review.*` 검사, `_validScannerUnresolvedSlots`. HEAD blob(loose)을 풀어 위치를 확인했다 |
  | `frontend/lib/services/process_app_service.dart` | 있음(CRLF, LF 줄 일부) | 스캐너 WIP: `confirmedFields`, `scannerUnresolvedSlots`·`assignScannerIdentity` |
  | `frontend/lib/services/mock_app_service.dart` | 있음(CRLF, LF 줄 일부) | 스캐너 WIP: `_assignedScannerSlots`, `confirmedFields` 재검증, unresolved slot API |
  | `frontend/lib/ui/pages/inventory_page.dart` | 없음(CRLF) | |
  | `frontend/test/planning_protocol_contract_test.dart` | 없음(CRLF) | |
  | `frontend/test/planning_protocol_client_test.dart` | 없음(CRLF) | |
  | `frontend/test/inventory_page_test.dart` | 없음(CRLF) | |
  | `frontend/test/statistics_projection_test.dart` | 없음(CRLF) | |
  | `frontend/test/scan_inventory_identity_review_test.dart` | **git 밖(미추적, LF)** | 스캐너 WIP 파일로 보인다. 호출처라서 생성자 인자만 고친다. commit.json에는 넣지 않는다(발견 사항) |

  - 착수 전 사본은 `debug/frontend_fb3dart/pre/<경로>`, slice 끝 사본은 `debug/frontend_fb3dart/post/<경로>`에 둔다.
  - WIP는 지우거나 정리하지 않는다. 원래 줄바꿈도 그대로 두고, 새 줄은 주변 줄바꿈을 따른다.
- 새 파일(예정): fb3 서비스·Mock 테스트, 획득처 process E2E, 인벤토리 재화 읽기 전용 위젯 테스트.
- golden 변화 0 예정. 인벤토리 화면은 golden 장면에 없다. Mock 카탈로그 행이 늘지만, golden 장면 중 카탈로그를 그리는 화면이 있는지는 종료 때 장면별로 확인한다.

## fb3-dart 종료 기록 (2026-10-11, 코드 작성 완료·gate 미실행)

이 환경에는 Flutter·Dart가 없다(SDK 내려받기도 프록시가 막는다). analyze·테스트·process E2E·golden을 돌리지 못했으므로 통과를 주장하지 않는다.
- 정적 검토만 했다. 별도 검토 에이전트가 바뀐 파일을 원본·공유 fixture·백엔드 Python(`inventory_catalog.py`·`resource_acquisition.py`·`repository_store.py`)과 대조해 읽었다. 확인한 것:
  - 컴파일·lint: import, dynamic 승격, record·pattern 문법, const 문맥, `noSuchMethod` 대역.
  - 00:02 목록 행별 의미.
  - 새·바뀐 테스트의 기대값. 검토 에이전트는 새 Dart 검사기를 Python으로 다시 구현해 fixture 전 case를 대조했다.
  - Mock 행 증가가 기존 테스트에 주는 영향.
  - 결과: 막는 문제 없음. 지적 4건을 반영했다.
    - Mock의 잘못된 질의 오류를 Process와 같게 맞췄다(보내기 전 `FormatException`).
    - Mock 오류 순서를 백엔드와 같게 했다(질의 → 카탈로그 → 표 실패).
    - Mock unattributed 기록에 guard를 두지 않은 이유를 주석으로 남겼다.
    - Dart 재화 키 집합과 카탈로그 `currencies` 행이 같은지 Mock·process 테스트에서 고정했다.
- 내가 직접 한 것:
  - 공유 fixture 전 case 대조: 새 Dart 검사기(strict DTO)와 계약 테스트의 JSON Schema 수준 helper를 Python으로 옮겨 `inventory_catalog_fb3_metadata.json`(19)·`resource_acquisition_v1.json`(requests 13·responses 12·strict 32)·`planning_protocol_v1.json` 획득처 case와 대조했다. 불일치 0.
  - 공유 서비스 3파일 병합 모의: HEAD blob(loose object)·착수 사본·끝 사본으로 `git merge-file` 3-way를 모의했다. 충돌 0이고, 병합 결과에 스캐너 WIP 줄이 없다.
  - 파일 형식: 바뀐 기존 줄 0, 새 줄 줄바꿈은 주변을 따른다. 끝 공백 없음, 끝 개행 하나, 괄호 짝 맞음.
  - 빈 획득처 표 revision을 백엔드 `resource_acquisition_payload`와 같은 방법(정렬·압축 JSON의 sha256)으로 다시 계산했다: `d1d01c18…`.

### 계약 SHA 대조

착수 때 확인한 XB 03:16 표와 같다(착수 기록의 표). 연결 기준은 메인 작업 트리 파일이다. 커밋 전까지 XB는 backend/contracts를 고치지 않는다(XB 03:16).

### 고친 파일

- **`frontend/lib/services/app_service.dart`**(WIP 없음, LF)
  - 카탈로그 행:
    - `InventoryCatalogEntry`에 required nullable `school`·`family`·`tier`를 더해 정확히 10키다(null 값도 키는 있어야 한다). 기존 7키 검사는 그대로다.
    - school·family는 유니코드 스칼라 문자열 또는 null이다. 빈 문자열·앞뒤 공백은 허용하고, 고립 surrogate는 거부한다. enum·길이 제한은 없다.
    - tier는 정확한 int ≥ 1 또는 null이다(bool·1.0·문자열·0 거부).
    - 읽기 전용 재화 키 `inventoryReadOnlyCurrencyKeys`(백엔드 guard 집합 사본)와 `isReadOnlyCurrency`를 더했다.
  - 획득처 strict DTO:
    - `ResourceAcquisitionQuery` exact1.
    - `ResourceAcquisitionResult` exact3. revision은 64자 소문자 hex이고, method_id는 응답 안에서 유일하다.
    - `ResourceAcquisitionMethod` exact6:
      - method_id: 소문자 토큰 전체 일치, UTF-8 128바이트 이하.
      - kind: enum `ResourceAcquisitionKind`.
      - weekly_quantity: 정규 정수 문자열 그대로(1024자 이하), 또는 null.
      - selector_resource_keys: null ≠ [], 순서 유지, 중복 금지.
    - `ResourceAcquisitionSource` exact3: server는 KR, reviewed_at은 `isStrictCalendarDate`(정규식 + 연·월·일 왕복 + year 1..9999)다.
    - 문자열은 백엔드 `_text`와 같다: 스칼라 유니코드, UTF-8 1..1024바이트.
    - 토큰·수량·날짜·revision 검사는 모두 전체 문자열 일치다(끝 개행·공백 거부).
    - 목록은 복사본이고 수정할 수 없다.
  - 서비스: 선택적 `ResourceAcquisitionService`와 `AppService` 확장 `getResourceAcquisition`을 더했다(`PlanningDocumentService`·`AppServiceStudentCalculation` 패턴). 지원하지 않는 서비스는 빈 결과가 아니라 `UnsupportedError`를 던진다. 다른 AppService 대역은 소스 호환이다.
  - `InventoryCatalogResult` exact3·정렬·revision·불변 행은 그대로다.
- **`frontend/lib/services/planning_protocol_client.dart`**(스캐너 WIP 보존)
  - `planning.inventory.acquisition.get` 오류 집합은 정확히 `invalid_payload`·`resource_not_found`·`resource_acquisition_failed`다. 이 메서드에 대해 `unknown_method`는 잘못된 오류로 보고 연결을 끊는다.
  - 성공 응답은 strict DTO로 검사한다.
  - 기존 id·method·pending·generation 처리와 다른 메서드 오류 집합은 그대로다. catalog 검사기는 DTO를 통해 exact10이 되었다. 검사기를 느슨하게 한 곳은 없다.
- **`frontend/lib/services/process_app_service.dart`**(스캐너 WIP 보존): `ResourceAcquisitionService`를 구현했다.
  - 질의를 DTO로 먼저 검사하고(형식이 틀리면 보내지 않는다) `planning.inventory.acquisition.get`을 보낸다.
  - 응답 키가 질의의 정규 키와 같은지 본다(`historyCanonicalResourceKey`). 그래서 legacy `Item_Icon_SkillBook_Ultimate_Piece` 질의에 정규 `Item_Icon_SkillBook_Ultimate` 응답을 받는다. 다른 자원의 응답은 `FormatException`이다.
  - repository.history.* API·캐시 의미는 그대로다.
- **`frontend/lib/services/mock_app_service.dart`**(스캐너 WIP 보존)
  - 카탈로그:
    - 기존 3행에 백엔드 매핑과 같은 메타를 넣었다: 보고서 family `activity_report`·tier 1, 게헨나 노트 `Gehenna`·`tech_notes`·1, 네브라 `oopart:Nebra`·1.
    - 끝에 credits(item_id null)와 bare `Item_Icon_SecretStone`(item_id = 키)을 더했다. profile `currencies`, 순서 0·1, `zero_fill_allowed=false`, 메타 null이다(백엔드 `_rows` 끝 두 행과 같다).
  - 획득처: 표는 백엔드 packaged v1처럼 비어 있다.
    - 알려진 키 → 정규 키 + `methods=[]` + `mockEmptyResourceAcquisitionRevision`(검증된 빈 표 hash).
    - 모르는 키 → `resource_not_found`.
    - `failNextResourceAcquisition` → `resource_acquisition_failed`.
    - 잘못된 질의 → `FormatException`.
    - 획득처 행·주간량은 지어내지 않았다.
  - 재화 guard: `_saveMockCurrent`(수동 저장)에서 캐시 재생·revision 확인 뒤, history 시각·쓰기·캐시 앞에서 막는다.
    - 비교 대상은 정규 키 projection의 재화 {키: 수량}이다. 없음·null·'0'이 모두 다르다.
    - 바뀌면 `BackendRemoteException(invalid_payload, details.reason=currency_read_only)`이다.
    - 스캐너 commit 경로(S-FB2b)와 unattributed 기록 경로는 손대지 않았다.
- **`frontend/lib/ui/pages/inventory_page.dart`**(WIP 없음, CRLF): 재화 행은 읽기 전용이다.
  - 입력 칸은 `readOnly`·비활성이고, `onChanged`가 없으며, 도움말 `스캔으로만 바뀝니다.`를 단다.
  - 재화 키는 dirty가 되지 않는다.
  - 재료 저장 때 기존 재화 항목은 dirty 여부와 상관없이 통째로 둔다. 없으면 만들지 않는다.
  - null을 '0'으로 바꾸거나, 재화를 빼거나, catalog 메타를 snapshot에 복사하지 않는다.
- 호출처 생성자(편집 전 다시 grep, XB 목록과 같음):
  - `mock_app_service.dart` 3곳.
  - `test/inventory_page_test.dart` 1곳.
  - `test/statistics_projection_test.dart` 3곳.
  - `test/scan_inventory_identity_review_test.dart` 2곳. 이 파일은 git 밖이다(발견 사항 1).
- **`frontend/test/planning_protocol_contract_test.dart`**(3건 → 7건, 지운 테스트 없음)
  - registry: 새 메서드·오류 code·`planning-inventory-acquisition-get-v1.schema.json`.
  - 공유 fixture의 `valid`·`schema_valid`는 JSON Schema 판정이라, 획득처 판정은 schema 수준 helper로 한다(정수 1.0 허용, 문자 수 기준 길이, surrogate 허용, uniqueItems, pattern).
  - strict DTO 판정은 따로 맞춘다: metadata exact10 19 case, 획득처 requests·responses·errors·strict_response_cases.
  - parity 대표 행: 열 개 키가 다 있는 8행을 DTO로 읽고, 재화 두 행의 값을 확인한다.
  - strict DTO 값: '0'·2^53+1·null·[]·KR·날짜, `toWire` 왕복.
- **`frontend/test/planning_protocol_client_test.dart`**(21건 → 24건, process 단계에서 실행)
  - 실제 catalog 응답 fixture를 10키로 바꾸고 메타 값을 확인한다.
  - 실제 `PlanningProtocolClient`·`ProcessAppService`로 확인하는 것:
    - 빈 표 성공, legacy 별칭, 다른 자원 응답 거부, 오류 3종, 역순 응답 상관, 이모지 label.
    - strict_response_cases 32건과 날짜 경계(`0000-01-01`·한 자리 월·끝 개행·2023-02-29·시각 포함 거부, 2024-02-29 통과).
    - 잘못된 오류 code는 연결을 끊는다.
    - 보내기 전 질의 검사: 빈 값·고립 surrogate·1025바이트는 거부, 1024바이트는 통과.

### 새 테스트

- **`frontend/test/inventory_fb3_service_test.dart`(일반 15건)**
  - 카탈로그 메타 경계, 스칼라 유니코드 판정.
  - 획득처 strict 경계: 수량(null·'0'·큰 값·int·double·bool·선행 0·부호·소수·지수·공백·개행·1025자), selector(null·[]·순서·중복·빈·surrogate·바이트 초과), method_id 토큰, kind, label 바이트, 중복 method, 날짜 15종, revision·exact 키, 질의 9종.
  - 지원하지 않는 서비스는 `UnsupportedError`.
  - Mock: 카탈로그 행·메타·재화 두 행, 읽기 전용 키 집합 = currencies 행, 빈 표·revision, 조회가 저장소·시각을 건드리지 않음, legacy 별칭, 모르는 키·잘못된 질의·표 실패의 구별과 순서.
  - Mock guard:
    - 재화 수량·제거·null↔'0'·없는 재화 추가는 모두 `currency_read_only`로 거부된다. revision·저장 상태·history 시각이 그대로이고, 같은 key로 다시 보내도 같은 거부다(캐시에 남지 않음).
    - 재화 항목을 그대로 둔 재료 저장은 통과한다.
    - 캐시 재생·`idempotency_conflict`·`revision_conflict`가 guard보다 먼저다.
- **`frontend/test/inventory_currency_readonly_test.dart`(위젯 2건)**
  - 재화 행 `readOnly`·비활성·`onChanged` 없음·도움말, null은 빈 칸('0' 아님).
  - 재료만 바꿔 저장하면 credits·엘리그마 항목이 원래 map 그대로 남는다.
  - 재화가 없던 계정은 저장 뒤에도 재화 항목이 없다.
- **`frontend/test/inventory_fb3_process_e2e_test.dart`(process 1건)**: 실제 Python 백엔드(메인 반영본)를 띄운다.
  - 카탈로그 전 행 exact10 파싱, catalog revision = parity fixture 값(`ace36d60…`), 재화 두 행이 끝, Dart 재화 키 집합 = 실제 currencies 행.
  - 획득처: 빈 표·revision, 별칭, 모르는 키, 잘못된 질의(`invalid_payload`).
  - 새 계정의 수동 재화 저장은 `currency_read_only`로 거부되고 revision이 그대로다. 재료 저장은 revision +1이다.

### 00:02 표 행별 검수표

| 00:02 행 | 반영 | 확인 테스트 |
|---|---|---|
| InventoryCatalogEntry exact10·nullable 3키·스칼라·tier | `app_service.dart` | 계약 metadata 19 case, service 테스트, client 카탈로그, E2E |
| InventoryCatalogResult exact3·정렬·revision·불변 | 그대로 | 기존 테스트 |
| 선택적 서비스·확장·지원 안 하면 던짐 | `ResourceAcquisitionService`·`AppServiceResourceAcquisition` | service `UnsupportedError` |
| 획득처 DTO exact1/3/6/KR3·토큰·수량·selector·날짜·UTF-8·revision | `app_service.dart` | 계약 fixture, service 경계, client 날짜 |
| client 오류 집합·strict 성공 분기·기존 보존 | `planning_protocol_client.dart` | client 오류 3종·잘못된 code, 계약 errors |
| Process wrapper·별칭·history 그대로 | `process_app_service.dart` | client 별칭·불일치, E2E 별칭 |
| Mock 카탈로그 3곳·재화 두 행·빈 표·구별·guard·스캐너 경로 보존 | `mock_app_service.dart` | service Mock·guard |
| 계약 테스트 registry·exact10·acquisition·schema/strict 분리 | `planning_protocol_contract_test.dart` | — |
| client 테스트 10키 fixture·실제 client 경로 | `planning_protocol_client_test.dart` | — |
| 호출처(mock 3·inventory_page_test·scan_inventory_identity_review_test·statistics_projection_test) | 모두 | 컴파일 |
| 서비스·process·Mock 테스트(권위 있는 빈 표, 알려진/별칭/모르는/깨진, 수량, selector, 유니코드·날짜) | 새 테스트 3파일 | — |
| Currency editor UI follow-up | `inventory_page.dart` | 위젯 2건 |
| FD101 UI 어댑터 | 범위 밖(FE6-a, CF 03:20) | — |

### golden 예측

변화 0.
- golden 장면(title·account-*·home·students-*·plan-*·scan-student-review)은 인벤토리·통계 화면과 스캔 미확인 슬롯 검토를 그리지 않는다. Mock 카탈로그(`listInventoryItems`)를 읽는 화면은 이 셋뿐이다(grep).
- DTO에 필드가 더해졌지만 화면이 그리는 값은 바뀌지 않았다.

### WIP 보존 확인

착수 사본(pre)과 끝 사본(post)의 차이는 이번 slice 줄뿐이다. 지운 기존 줄은 없고, 바꾼 기존 줄도 없다.

| 파일 | pre → post 차이 | 원래 줄바꿈 |
|---|---|---|
| `planning_protocol_client.dart` | 추가 3덩어리(오류 집합 6줄, 성공 분기 3줄, 검사 함수 9줄) | CRLF 유지(새 줄 CRLF), 기존 LF 줄 18개 그대로 |
| `process_app_service.dart` | 추가 2덩어리(implements 1줄, wrapper 18줄) | CRLF 유지, 기존 LF 줄 그대로 |
| `mock_app_service.dart` | 추가 9덩어리(빈 표 상수, implements, 실패 hook, 카탈로그 메타·재화 두 행, 획득처, guard 호출 5줄(주석 4 + 호출 1), guard 함수) | 주변 줄바꿈을 따름(guard 호출은 LF 구역이라 LF, 나머지 CRLF), 기존 줄 그대로 |

- 세 파일 모두 HEAD blob(loose)을 풀어 `git merge-file`로 HEAD ← (pre → post)를 모의했다. 충돌 0이고, 결과에 스캐너 WIP 줄(`unresolved_slot_not_found`·`_assignedScannerSlots`·`scannerUnresolvedSlots`)이 들어가지 않는다.
- 이번 slice 코드는 HEAD에 있는 import·심볼만 쓴다(`mapEquals`·`BackendRemoteException`·`historyCanonicalResourceKey`).
- 사본 위치:
  - 착수 사본: `debug/frontend_fb3dart/pre/<경로>`.
  - 끝 사본: `debug/frontend_fb3dart/post/<경로>`.
  - commit.json `post_dir: debug/frontend_fb3dart/post`, `status=false`, `whole=[almanac/workflows/frontend-redesign-status-lane-b.md]`.
  - `scan_inventory_identity_review_test.dart`는 git 밖이라 commit.json에 넣지 않았다. post 사본은 두었다.

### 미검증 항목

- analyze·일반 테스트·process 테스트·golden·`codealmanac validate`·`git diff --check` 전부 미실행(사용자 PC gate 필요).
- process E2E는 catalog revision이 parity fixture 값(`ace36d60…`, 631행)과 같다고 본다(XB 00:02 실측값). 같은 소스 gate에서 처음 확인된다.
- process E2E의 "거부된 재화 저장은 revision을 올리지 않는다"는 새로 만든 계정 기준이다. 공통 legacy 이관이 앞설 수 있는 오래된 계정은 다루지 않는다(XB README대로 그쪽은 revision이 오를 수 있다).
- Dart `jsonEncode`/`jsonDecode`의 고립 surrogate 왕복(FakeBackendProcess 경로)은 문자열 그대로 지나간다고 보았다(검토 에이전트 동의). 실제 stdio는 UTF-8이라 고립 surrogate가 오지 않는다.

### 발견 사항

1. `frontend/test/scan_inventory_identity_review_test.dart`가 git 밖(미추적)이다. 스캐너 WIP 파일로 보인다.
   - 이 파일은 `InventoryCatalogEntry`를 만들므로 생성자 인자 3개(school·family·tier)만 더했다. 안 고치면 같은 소스 gate가 컴파일 실패한다.
   - commit.json에는 넣지 않았다. 스캐너 WIP를 커밋할 때 이 작업 트리 내용(새 인자 포함)이 같이 들어가야 한다.
2. 백엔드는 unattributed 쓰기도 재화 guard로 막는다. Mock의 unattributed 기록(`_observeMockCurrentWrite`, 옛 scanner commit 경로)은 00:02 목록("scanner-owned commit path 보존")대로 손대지 않았다. Mock 재화를 그 경로로 바꾸는 테스트가 생기면 백엔드와 다르게 통과한다.
3. `inventoryReadOnlyCurrencyKeys`는 백엔드 `_READ_ONLY_CURRENCY_KEYS`의 손 사본이다. 세 번째 재화가 생기면 Dart도 고쳐야 한다. Mock·process 테스트가 "읽기 전용 키 = 카탈로그 currencies 행"을 고정하므로 어긋나면 gate가 알린다.
4. 공유 fixture `resource_acquisition_v1.json`의 `table_cases`(42)는 백엔드 표 loader 판정이라 Dart가 소비하지 않는다(Dart는 표를 읽지 않는다).
5. 인벤토리 화면의 기존 문구는 영어(`Owned`·`Save inventory` 등)이고, 이번에 더한 도움말만 습니다체다. 화면 재작성은 FE6이다.

### 다음 행동과 사용자 실행 명령

- fb3-dart 코드는 끝났다. Lane B는 여기서 멈춘다.
- PowerShell, `C:\Users\brigh\planner_of_plana\BA Planner\v7`에서 아래 명령을 한 줄씩 실행하고, 하나가 실패하면 거기서 멈추고 결과를 오케스트레이터에게 보낸다.
  1. Lane A(FE5-c2)·Lane B 두 워커가 모두 멈춘 뒤 실행하고, 결과(`debug/frontend_gate/` 요약)를 오케스트레이터에게 보낸 뒤 기다린다. 이번이 FB-3 메인 반영본과 같은 소스 gate다. 예상: golden 변화 0, 일반 +17(service 15 + 위젯 2), 계약 +4, process +4(client 3 + E2E 1).
     - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1`
  2. XB가 FB-3를 먼저 커밋한 뒤(순서는 오케스트레이터가 정한다):
     - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice fb3dart -DryRun`
     - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice fb3dart`

## fb3-dart gate ① RED 수정 기록 (2026-10-11, 코드 수정 완료·gate 미실행)

gate ① `debug/frontend_gate/20261011_124823`(XB FB-3 메인 반영본과 같은 소스)에서 fb3-dart 몫은 3건이었다(오케스트레이터 13:15). golden 6장(plan-bottleneck·by-phase·overall·scenario-compare·flow-step4·-append)은 FE5-c2 예측이라 손대지 않았다.

### 1. analyze info `use_null_aware_elements`

- 위치: `inventory_fb3_service_test.dart:598`. `if (change(entry) case final value?) value`를 `?change(entry)`로 바꿨다.
- 동작은 같다. null이면 원소를 넣지 않고, 아니면 그 map을 넣는다.

### 2. 일반 테스트 `statistics_page_test.dart` "detail and data-owner actions navigate without mutation"

원인(오케스트레이터 추정 확인 + 집계 버그):
- 통계 projection `buildInventoryStatistics`(`lib/statistics/statistics_projection.dart`)는 카탈로그 행을 모두 아이템 보유 범위로 센다.
- fb3-dart가 Mock 카탈로그에 credits(category `credits`)·`Item_Icon_SecretStone`(category `eligma`) 두 행을 더했다. 그래서 통계 Inventory 화면이 바뀌었다:
  - catalog 3 → 5
  - absent가 재화 수만큼 늘었다.
  - Category coverage 행이 3 → 5(`credits`·`eligma`)
- 늘어난 두 ListTile만큼 `statistics-open-inventory` 버튼이 아래로 갔다. `ensureVisible`이 더 내려간 뒤 위쪽 모드 선택(`Plan`)이 ListView 캐시 밖으로 나가 지어지지 않았다(`Bad state: No element`).
- 길이만의 문제가 아니다. FB-3 계약에서 credits·엘리그마는 catalog-only 읽기 전용 재화다. 이 둘을 아이템 보유 범위에 넣으면 실제 백엔드 카탈로그(631행)에서도 catalog·absent·category 보유율이 재화 때문에 달라진다. 그래서 **화면 집계 버그로 판정**했다. 테스트 기대는 바꾸지 않고 구현을 고쳤다.

수정(`statistics_projection.dart`만):
- `buildInventoryStatistics`가 카탈로그의 재화 행(`isReadOnlyCurrency`)을 건너뛴다.
- snapshot의 재화 항목(식별자 `item_id ?? key`가 `inventoryReadOnlyCurrencyKeys`)도 건너뛴다. 그래서 스캔으로 생긴 재화 항목이 `(Missing category)`로 새지 않는다.
- 재화 필요량·부족은 원래대로 계획 통계가 다룬다. gross `credits` 스칼라와 백엔드 shortage 행은 손대지 않았다. 재화 필요·보유 비교는 정당한 계산이라 그대로 두었다.
- 이제 Mock 통계 Inventory 화면은 fb3-dart 이전과 같다(3행, 같은 category 3개). 그래서 고정 drag(0, 600)를 그대로 두었다. 테스트 파일은 고치지 않았다.

추가 테스트(`statistics_projection_test.dart`, 5건 → 6건):
- `inventory projection keeps catalog-only currencies out of item coverage`.
- 재료 2행 + 재화 2행 카탈로그에 재료 1·재화 2 snapshot을 넣는다.
- catalog 2·snapshot 1·absent 1·missing 없음·category는 `notes` 하나·identities는 재료만임을 확인한다.
- 테스트 안 재화 행이 `inventoryReadOnlyCurrencyKeys`와 같은지도 확인한다.

### 3. process `scenario_process_e2e_test.dart` "real Dart to Python scenario lifecycle and comparison are isolated"

원인:
- 테스트 준비가 `saveRepositoryInventory`로 `{'key': 'credits', 'quantity': '0'}`을 수동 저장했다.
- FB-3 guard(`repository_store._assert_currency_quantities_unchanged`, source manual)가 의도대로 거부했다(`invalid_payload`, `currency_read_only`). guard는 그대로 두었다.

수정(테스트 준비만):
- 재화 대신 활동 보고서 `Item_Icon_ExpItem_0~3`(key·item_id 같음)을 `'0'`으로 저장한다.
- 비교 호출(`compareScenarios`)의 `inventory` 인자는 저장이 아닌 순수 계산 입력이다. 앱도 저장된 inventory(스캔으로 생긴 재화 포함)를 그대로 넘기므로 `credits '0'`을 그대로 두었다.

기대가 그대로 성립하는 근거(백엔드 소스 정적 확인, 실행은 안 함). 기대 값은 바꾸지 않았다:
- `calculation.credits > 0`: `planning_summary.calculation_summary`의 credits는 `projection.overall.cost.credits`다. 인벤토리와 무관한 레벨 1→8 비용이다.
- `firstBottleneckPhaseNumber == 1`:
  - `planning_calc.calculate_goal_cost`는 레벨 1→8에서 `level_exp > 0`이다. 그래서 `_exp_item_breakdown("Item_Icon_ExpItem_0", …)`이 T1~T4 중 하나 이상을 낸다.
  - 카탈로그 별칭 `Item_Icon_ExpItem_0 T<n>` → `Item_Icon_ExpItem_<n-1>`이다.
  - 네 키 모두 보유 0이 알려져 있다. 그래서 `calculate_document_projection`이 P1 첫 단계에서 shortage > 0인 병목을 만든다.
  - credits는 이제 보유를 모르므로(None) 병목이 되지 않는다. 병목 phase는 그대로 1이다.
- 격리: 시나리오 생성·복제 뒤 repository revision이 저장 직후 값과 같다. inventory 내용과 무관하다.

### 앱 경로 점검(공개 repository 쓰기로 재화를 보내는 경로)

frontend/lib 전체를 grep했다(`saveRepositoryInventory`·`repository.inventory.update`·`credits`·`SecretStone`·`history_context`·`commitScannerCandidate`).
- 백엔드 guard는 `update_inventory`(`repository.inventory.update`)의 manual·unattributed 쓰기에만 걸린다. scan 출처는 통과한다.
- v6 가져오기(`import_v6_profile`)와 계정 만들기(`create_profile`)는 그 경로를 타지 않는다.
- 결과:
  - `repository.inventory.update`를 보내는 곳은 `ProcessAppService.saveRepositoryInventory` 하나다. 이를 부르는 앱 코드는 `ui/pages/inventory_page.dart` 하나이고, fb3-dart에서 이미 고쳤다(재화 항목 통째 유지).
  - 스캔 쓰기(`scan_page`·`student_page`·`inventory_page`의 `commitScannerCandidate`)는 scanner 출처라 guard 대상이 아니다.
  - v6 가져오기(`repository.migration.import`)·타이틀 첫 실행·계정 만들기(`repository.profile.create`)는 inventory update를 보내지 않는다.
  - `plan_scenario_list.dart`의 `inventory: repository.inventory.toWire()`는 비교 계산 입력이다. 쓰기가 아니다.
  - 개발 도구(`developer_tools_main.dart`·`tool_backend_client.dart`)에도 inventory update가 없다.
- 고칠 앱 경로는 더 없다. 다른 레인 파일 목록도 비었다.
- process 테스트 grep: top-level `*process*` 18파일과 관련 서비스 테스트를 봤다.
  - `saveRepositoryInventory`·`repository.inventory.update`로 재화를 수동 저장하는 것은 `scenario_process_e2e_test.dart` 하나였고, 위에서 고쳤다.
  - `repository_process_e2e_test.dart`의 `credits`는 계산 결과 키다. 저장하지 않는다.
  - `test/widgets`·`test/kit`·`test/geometry`·`test/goldens` 하위 폴더는 보지 않았다(process 테스트가 아니고 golden은 Lane A).

### 검증

- 정적 검토만 했다(Flutter·Dart·백엔드 실행 없음).
- 바꾼 파일의 줄바꿈은 원래대로다:
  - `statistics_projection.dart`·`statistics_projection_test.dart`: CRLF
  - `scenario_process_e2e_test.dart`·`inventory_fb3_service_test.dart`: LF
- `statistics_projection.dart`·`scenario_process_e2e_test.dart`의 작업 트리는 HEAD blob과 같았다(줄바꿈 정규화 기준, WIP 없음). 착수 사본도 두었다.
- `?element`는 null-aware element 문법이다. lint가 이것을 권했으므로 pubspec SDK 하한에서 쓸 수 있다.

### 사본·commit.json

- 착수 사본을 새로 두었다:
  - `debug/frontend_fb3dart/pre/frontend/lib/statistics/statistics_projection.dart`
  - `debug/frontend_fb3dart/pre/frontend/test/scenario_process_e2e_test.dart`
- 끝 사본을 갱신하거나 새로 두었다(`debug/frontend_fb3dart/post/frontend/...`):
  - `lib/statistics/statistics_projection.dart`
  - `test/scenario_process_e2e_test.dart`
  - `test/statistics_projection_test.dart`
  - `test/inventory_fb3_service_test.dart`
- `debug/frontend_fb3dart/commit.json` `modified`에 두 파일을 더했다: `frontend/lib/statistics/statistics_projection.dart`, `frontend/test/scenario_process_e2e_test.dart`. message는 그대로다.

### 발견 사항

- 스캔 미확인 슬롯 검토(`scan_inventory_identity_review.dart`)는 전체 카탈로그에서 고른다. 그래서 재화 행도 후보에 나온다. 그 경로는 scanner 출처라 guard에 걸리지 않는다. 스캔 화면 동작은 이 slice 범위 밖이라 손대지 않았다.
- fb3-dart 종료 기록의 "golden 예측 변화 0"은 그대로다. 통계 화면은 golden 장면이 아니다. 다만 그 기록에서 통계 화면 집계 영향을 놓쳤고, 이번에 고쳤다.

### 다음 행동

- "fb3-dart 종료 기록" 맨 끝 사용자 실행 명령을 1번(`fe_gate.ps1`)부터 다시 한다. Lane B는 여기서 멈춘다.
- fb3-dart 몫 예상:
  - analyze info 0
  - 일반 테스트: `statistics_page_test` 녹색, `statistics_projection_test` +1
  - process: `scenario_process_e2e_test` 녹색
