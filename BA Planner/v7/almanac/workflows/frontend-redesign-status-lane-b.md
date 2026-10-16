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

**fb6-dart 코드 작성 완료, CF gate 대기(2026-10-14).** 시작 커밋 `5b1d8d15`. 아래 "fb6-dart 착수 기록"·"fb6-dart 종료 기록". 그 전: tidy1 `7bd7530d`, fb10c-dart `16606c58`(시작 `cbc63d98`), FE8-e `9f11869f`, FE8-d(시작 `75943ffc`, 커밋 `998fe0cc`), FE8-c(시작 `cac83222`, 커밋 `d0964853`), FE6-f(시작 `9c03d50b`, 커밋 `00290cea`), fb10b-dart `b49ce994`, fb2d-dart `3f42cee3`, FE6-e `fe920b81`, FE6-c `6305171c`, fb10a-dart `e53fee9e`, FE6-b `e45194bc`(+ 옛 Studio 문서 삭제 커밋), FE6-a `2f88e65f`, fb3-dart `739f3bfe`, T-FB1b `5c78c83c`, FE8-b `8268abb3`, S-FB1b `70d1173b`, fb4-dart `63a01318`, FE8-a `815e0589`.

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

## FE6-a 착수 기록 (2026-10-11)

- 범위: 인벤토리 로직 추출 + 부족 위험 화면(시안 `Inventory.dc.html`, "부족한 것" 보기·엘레프 선택). 워크플로 FE6 표 FE6-a 행과 워커 프롬프트 `debug/frontend_redesign_handoff/fe6a-worker-prompt-20261011.md`.
  1. `_InventoryPageState`의 로드·편집·저장·부족 계산을 컨트롤러로 옮긴다. fb3-dart의 재화 읽기 전용 규칙(재화 키 dirty 금지, 재화 항목 통째 유지, `currency_read_only` 오류 처리)을 그대로 지키고 컨트롤러 테스트로 고정한다.
  2. 4섹션 A/B/C/D(C·D 사선 맞물림), 사이드바(최상단 "목록·분석" seg — 분석은 FE6-c까지 꺼 둠, "아이템·장비" seg, 종류 버튼 category 1:1 FD-095, 기본 진입 부족 진단 FD-094).
  3. 위험도 행(FD-030 (b)), 막대 폭 = 점수, 행 선택 ↔ 상세.
  4. 상세: kv·사용 학생(FD-101)·보충 방법(FB-3 획득처, 빈 표가 정상)·액션 3개(FD-125). 이력은 빈 상태(FE6-f).
  5. 후보 승인 `_CandidatePanel`은 FE8-g5 전까지 그대로 둔다(위치만 새 배치).
- 범위 밖: 전체 아이템 타일(FE6-b), 분석(FE6-c~e), 이력·KPI 증감·스파크라인(FE6-f), `lib/services/**`, 키트, golden harness·기존 golden 테스트, `app_shell.dart`, `statistics/**`, 백엔드·계약.
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `dfd1d620a8cde99486177f1f571c0848efa33676`.
- 막힘: 대장 막힘 요약의 FE6-a 행(FD-030·FD-031)은 둘 다 확정(2026-10-06)이다. 막는 열림 FD 없음.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe6a/pre/<v7 기준 경로>`):
  - `frontend/lib/ui/pages/inventory_page.dart`
  - `frontend/test/inventory_page_test.dart`
  - `frontend/test/inventory_currency_readonly_test.dart`
- 새 파일(예정): `frontend/lib/ui/inventory/**`(컨트롤러·화면 모델·Studio 배치·4섹션 위젯), 그 테스트, `frontend/test/goldens/fe6a_inventory_golden_test.dart`(harness 공개 함수만)와 기준 이미지 `inventory.png`.
- WIP: 세 파일 모두 미커밋 변경 없음(작업 트리 = index blob, 줄바꿈 정규화 기준). `inventory_page.dart`·`inventory_page_test.dart`는 CRLF, `inventory_currency_readonly_test.dart`는 LF다.

## FE6-a 종료 기록 (2026-10-11, 코드 작성 완료·gate 미실행)

시안 `Inventory.dc.html`("부족한 것" 보기, 엘레프 선택)의 4섹션 화면과 로직 추출을 끝냈다. Flutter·Dart가 이 환경에 없어 analyze·테스트·golden은 돌리지 않았다(정적 검토만 했다).

### 고친 파일

| 파일 | 내용 |
|---|---|
| `frontend/lib/ui/inventory/inventory_controller.dart`(새) | 옛 `_InventoryPageState`의 로드·편집·저장·부족 계산·후보 승인. `InventoryCandidateContext`도 여기로 옮겼다(`inventory_page.dart`가 그대로 export하므로 `app_shell.dart`는 그대로다) |
| `frontend/lib/ui/inventory/inventory_view_model.dart`(새) | 위젯 없는 계산: 위험도(FD-030 (b)), 충족률(FD-031 (a)), 과잉(FD-040), 종류(FD-095), 정렬, KPI, 사용 단계(FD-101), 획득처 상태 |
| `frontend/lib/ui/inventory/inventory_studio_layout.dart`(새) | 4섹션 Studio 문서(typed projection) |
| `frontend/lib/ui/inventory/inventory_workspace.dart`(새) | 4섹션 위젯(사이드바·KPI 띠·위험도 목록·상세) |
| `frontend/lib/ui/pages/inventory_page.dart` | 컨트롤러 + 4섹션으로 다시 썼다. 생성자 인자는 그대로이고 선택 인자 `controller`만 더했다. `_CandidatePanel`은 그대로 두고 위험도 목록 위 띠에 둔다 |

로드 순서:
1. 카탈로그
2. 선택된 계정(`listProfiles`의 selected). 페이지 안 계정 고르기 패널(`RepositoryProfilePanel`)은 시안에 없어 뺐다.
3. 활성 계획(`loadRepositoryPlan`)
4. 저장된 상태(`loadRepositoryState`)
5. 학생 이름
6. 목표가 있으면 부족 계산(`calculateShortages`)과 활성 문서 계산(`calculatePlanningDocument`)

활성 계획을 상태보다 먼저 읽는 이유: 목표 v1만 있던 계정은 그 읽기에서 문서로 옮겨지며 revision이 오를 수 있다(Mock도 같다). 저장 기준 revision은 그 뒤에 읽은 값이어야 한다. 옛 화면의 "Analyze saved plan" 버튼은 없앴고, 로드할 때 계산한다.

### 재화 읽기 전용 규칙(fb3-dart) 유지

모두 컨트롤러 테스트로 고정했다.
- 재화 키(credits·엘리그마)는 거절된다: `setDraft`·`beginEdit`·`canEdit`가 false, dirty·draft가 생기지 않는다. `saveQuantity('credits', …)`는 쓰기 없이 안내만 한다.
- 저장 wire(`inventoryWire`)는 옛 `_inventoryWire`와 같은 규칙이다.
  - 재화와 고치지 않은 품목은 저장된 map을 통째로 둔다(이름 포함).
  - 없는 재화는 만들지 않고, null을 '0'으로 바꾸지 않는다.
  - 카탈로그 밖 항목은 그대로 두고, 빈 칸은 항목을 빼서 모름으로 둔다.
- `invalid_payload` + `details.reason=currency_read_only` 거부는 draft·dirty·편집 칸을 그대로 둔다. `lastSaveErrorReason=currency_read_only`와 안내("재화(크레딧·엘리그마)는 스캔으로만 바뀌어 저장하지 않았습니다. 고친 수량은 그대로 남아 있습니다.")를 보인다. 다른 저장 실패도 draft를 지키고 오류 코드를 남긴다.
- 화면: 재화는 위험도 목록·종류 버튼에 없고 사이드바 "주요 재화" 카드로만 고른다. 고르면 "수량 직접 고치기"가 꺼지고 "재화 수량은 스캔으로만 바뀝니다."가 보인다.

### 화면(4섹션, 시안 좌표·Studio 문서)

섹션 rect(96 grid, 기준 viewport 2560×1392):

| 섹션 | grid | 모양 | 시안 대비 |
|---|---|---|---|
| A 사이드바 | (0,2,26,94) | 왼쪽 사다리꼴 | 같다 |
| B KPI 띠 | (26,2,70,11) | 오른쪽 사다리꼴 | +0.3·+0.4px |
| C 위험도 | (19,14,39,82) | 아래 평행사변형, 아랫변 506.7→1546.7, 윗변 688.6→1728.6 | x −2.1·−12.3px, 위 −5px |
| D 상세 | (59,14,37,82) | 오른쪽 사다리꼴, 왼쪽 변 1573.3→1755.2 | −9.6·−8.8px |

C·D 사이는 다른 화면처럼 한 칸(26.7px)이다. 시안 x가 grid에 맞지 않아서다.

**A 사이드바**
- 맨 위 "목록 · 분석" seg. 분석은 꺼 두었다(FE6-c).
- "아이템 · 장비" seg.
- 보기: "부족한 것 n종"(+ "모름 n") / "전체 n종". 기본은 부족한 것이다(FD-094).
- 종류 버튼: 폭이 사선을 따라 8px씩 줄고, "부족 n" 칩과 개수를 단다. 고른 종류를 다시 누르면 거르기가 풀린다.
- 주요 재화 카드 2개: 보유 / 필요 / −부족 + 막대.

**B KPI 띠**
- 보유 품목, 부족 재화, 과잉 재화(FD-040, 보유 ≥ 필요×1.5), 계획 충족률(FD-031 (a), "n종 모름" 병기).
- 최근 감소·마지막 스캔·증감은 이력 연동(FE6-f) 전이라 `—`다.

**C 부족 위험도 순위**
- 제목 + (i)(시안 문구) + 정렬 칩(위험도·충족률·부족량).
- 위험도 행(1010×58 기준):
  - 왼쪽: 아이콘 54×44, 이름, "보유 1 / 필요 450 · 사용 학생 1명".
  - 막대: 폭 = 점수(50 이상 핑크, 미만 노랑). 보유를 모르면 빗금이다(FD-033).
  - 오른쪽: 점수, 78px 빈 칸.
- 공용 `DiagonalScrollViewport`(translate) · 포그 · 사선 스크롤바를 쓴다.
- 행을 누르면 D가 바뀐다. 처음에는 가장 위험한 행을 고른다.
- 안내 상태: 연결 끊김, 카탈로그 오류(다시 읽기), 계정 없음, 계획 없음("계획 열기"), 부족 계산 오류, 빈 목록.

**D 상세**
- 머리: 아이콘 111×90, 이름, 메타 줄. 메타는 종류 · FB-3 school · `T<tier>`이고, 재화는 "스캔으로만 바뀌는 재화"다.
- kv: 보유 · 필요 · 부족 · 충족률.
- "수량 직접 고치기" 칸: `inventory-quantity-<key>`, 저장 · 취소, "빈 칸은 모름으로 저장합니다.". 다른 품목을 고르면 저장하지 않은 draft를 버린다.
- 사용하는 학생 · 막히는 단계 n(FD-101): 활성 문서 계산 `stage_results[].resources`의 학생 · 페이즈 · 그 학생의 k단계 · (단계 이름) · −들어설 때 부족. 최대 4줄 + "외 n단계".
  - 문서 계산을 못 읽으면 부족 계산의 `affected_student_ids`와 사유를 보인다.
  - 계획에 안 쓰는 재화는 "계획에 쓰지 않는 재화입니다."다.
- 보충 방법(FB-3 `getResourceAcquisition`, 품목마다 한 번 읽고 기억):
  - 빈 표: "아직 정리된 획득처가 없습니다."(지금 packaged 표에서는 이것이 정상)
  - 지원 안 함: "이 연결은 획득처 조회를 지원하지 않습니다."
  - `resource_not_found`: "획득처 표에 없는 재화입니다."
  - 실패: "획득처를 불러오지 못했습니다." + 다시 읽기
  - 표에 줄이 있으면 이름 · 종류 · 주 n개 · 선택 n종을 보인다.
- 최근 변화: 빈 상태("아직 변화 기록이 없습니다.", FE6-f).
- 액션: 계획에서 보기(pri, 계획 탭), 수량 직접 고치기, 인벤토리 스캔(FD-125: 스캔 팝업이 아직 없어 스캔 탭으로).

작은 창: 각 내용 묶음은 시안 최소 크기 아래로 줄이지 않고, 사선을 따라 계산한 자기 상자로 자른다. 화면 전체를 `FittedBox`로 줄이지 않는다. 알림 문구 묶음만 `scaleDown`이다.

### 처리한 FD

- FD-030 (b) 확정: `100 × 부족비율^(1/(1+ln n))`, n = 사용 학생 수(최소 1). 보유를 모르면 점수도 모름(`—`)이다.
- FD-031 (a) 확정: 계획이 쓰는 재화마다 min(보유, 필요)/필요의 평균이다. 크레딧 포함, 보유를 모르는 재화는 빼고 "n종 모름"을 병기한다.
- FD-094 확정: 기본 진입 = 부족 진단.
- FD-040 워커 재량(권장안): 과잉 = 보유 ≥ 필요×1.5. 계획에 안 쓰는 재화는 세지 않는다.
- FD-095 워커 재량:
  - 종류 버튼 = category 1:1, 시안 라벨이다. `student_eleph` 엘레프, `oopart` 오파츠, `activity_report` 활동 보고서, `tech_notes` 기술 노트, `tactical_bd` BD, `equipment` 장비 설계도.
  - 시안에 없는 `present` 선물·`workbook` 교본은 끝에 둔다. 모르는 category는 이름순으로 그 뒤에 둔다. "선택권·상자"는 category가 없어 숨긴다.
  - "아이템·장비" seg는 카탈로그 profile로 나눈다(`equipment` = 장비). 아래 발견 사항 1을 보라.
  - 재화 category(`credits`·`eligma`)는 버튼 대신 주요 재화 카드다.
- FD-101 워커 재량: 활성 문서 계산의 `stage_results[].resources`를 쓴다.
- FD-125 워커 재량: 인벤토리 스캔 = 스캔 탭 이동이다(팝업 FE8-f3 전).
- FD-120: 후보 승인 `_CandidatePanel`은 FE8-g5까지 그대로 두었다(글자·동작 같음, 위치만 위험도 목록 위 띠). 높이는 200이다. Ahem 글꼴의 `Wrap` 줄바꿈에서도 버튼이 띠 안에 들도록 정했다(검토 에이전트 계산).
- FD-146 (a) 확정(영속 "확인 필요"): 지금 저장소 inventory entry에 `needs_review` 같은 영속 필드가 없다(`lib/**`·`backend/core`에 없음, FB-10 범위). 그래서 그리지 않았다. 필드가 생기면 행·상세에 표시를 더한다.
- FD-033: 모름 ≠ 0. 보유 모름은 `—`·빗금이고, 서로 다른 재화 수량은 더하지 않는다.

### 위험도 계산 검증 예

| 재화 | 보유 / 필요 · 사용 학생 | 식 값 | 표시 |
|---|---|---|---|
| 시안 엘레프 | 1 / 450 · 1명 | 부족비율 449/450 = 0.99778, n=1이라 지수 1 → 99.78 | 100 |
| 오파츠 | 3 / 40 · 2명 | 0.925^(1/(1+ln 2)) → 95.4999 | 95 |
| 기술 노트 | 12 / 60 · 4명 | 0.8^(1/(1+ln 4)) = 0.8^0.419 → 91.07 | 91 |
| 토키 엘레프 | 53 / 330 · 1명 | → 83.94 | 84 |
| BD | 20 / 28 · 3명 | → 55.05 | 55 |
| 같은 BD, 1명이면 | 20 / 28 · 1명 | → 28.57 | — |
| 보유 모름 | — | null | `—` |

- 같은 부족비율에서 학생이 많을수록 점수가 오른다(BD 28.57 → 55.05).
- 대장의 "98"은 근사 표현이다. 이 시안 행은 식으로 99.78이고 정수 표시는 100이다. 시안의 다른 행 숫자(88·76·71·62·40)도 식 결과가 아닌 견본 값이다(예: 0/55·2명은 식으로 100).

### 테스트

새 테스트:
- `inventory_view_model_test.dart`(9건): 위험도 식·예외, 부족 보기 정렬·재화 제외·개수, 다른 정렬, 종류 순서·라벨·부족 수, KPI, 계산 없음, 카탈로그 밖 행, FD-101 사용 단계.
- `inventory_controller_test.dart`(13건):
  - 재화 dirty·편집 금지, 재료 저장 때 재화·카탈로그 밖 항목 통째 유지, 없는 재화 미생성·빈 칸 = 모름, 잘못된 수량 거부.
  - `currency_read_only` 거부 때 draft 유지, 다른 실패도 draft 유지.
  - fixture 로드(부족·사용 단계·기본 선택), 활성 계획 뒤 revision으로 저장, 보기 상태, 목표 없음, 끊김·카탈로그 실패.
  - 획득처 빈 표·실패·다시 읽기·표에 없음, 지원 안 함.
- 검수 fixture `test/inventory_fe6a_fixture.dart`(테스트 파일 아님): 시안 예시 값의 Mock 하위 클래스. `MockAppService` 기본값은 바꾸지 않았다.

다시 쓴 테스트(기대를 바꾼 이유: 화면을 시안대로 재작성했다):
- `inventory_page_test.dart`:
  - 순수 wire 테스트는 그대로다.
  - 옛 "loads, filters, saves zero, and exposes plan and scan callbacks"는 "shortage view without a plan, all view edit-save, plan and scan actions"로 바꿨다.
    - 시안에 없는 Material 검색·드롭다운·"Save inventory"·"Analyze saved plan"·"Open Planning"·"Open Scan"을 없앴다.
    - 저장은 상세 칸에서 하고, 부족 계산은 로드 때 한다. 계획·스캔 이동은 상세 액션과 "계획 열기"로 옮겼다. 앱 문구는 습니다체다.
  - 후보 hold/approve·stale 두 건은 동작 기대가 같다. 바뀐 것은 안내 문구(한국어, 예 `comparison was kept` → `비교는 그대로 남아 있습니다`)와 기준 viewport 면적뿐이다(후보 띠가 목록 섹션 안이라).
  - viewport 테스트는 2560×1392를 더하고 "전체" 보기에서 긴 이름을 찾는다(기본 진입이 부족 진단이라).
  - 끊김·카탈로그 오류 테스트는 한국어 문구로 바꿨다.
  - 새 fixture 장면 테스트: 위험도 순서·점수, KPI, 기본 선택 상세, 사용 단계, 빈 획득처, 행 선택·메타, 정렬 칩, 종류 거르기, 장비 모드.
- `inventory_currency_readonly_test.dart`: 저장 결과 기대(재화 map 통째, 없는 재화 미생성, null 유지)는 그대로다. 화면 기대만 바꿨다. 옛 수량 TextField의 readOnly·enabled·helper("스캔으로만 바뀝니다.")는 이제 주요 재화 카드 선택 → 고치기 버튼 꺼짐 + 안내 "재화 수량은 스캔으로만 바뀝니다." + 수량 칸 없음이다.
- 지운 테스트 없음(위 대체 외).

golden:
- 새 장면 `inventory`(`test/goldens/fe6a_inventory_golden_test.dart`). 앱 셸 → 인벤토리 탭, fixture 서비스, harness 공개 함수만 쓴다(`loadGoldenFonts`·`setGoldenViewport`·`goldenBoundary`·`pumpUntilFound`·`expectGoldenScene`·`goldenPlatform`).
- 기준 이미지 `frontend/test/goldens/baseline/inventory.png`는 아직 없다. 그래서 첫 비교에서 이 장면만 RED가 예상된다.

### golden 예측

- 기존 장면 변화 0이다. 인벤토리 탭은 기존 장면 어디에서도 보이지 않는다. 셸 장면(home·students-*·title 등)에서 오프스테이지로 지어지지만 그리지 않는다.
- 새 동작: 셸이 뜨면 인벤토리가 카탈로그·계정·활성 계획·상태·학생 이름을 읽는다. 목표가 있으면 부족·문서 계산도 한다. 모두 Mock의 순수 조회이고 상태를 바꾸지 않는다.
  - 예외: 생성자로 `repositoryStates`를 받은 Mock 계정은 첫 `loadRepositoryPlan`에서 목표 이관 revision이 오른다. 계획 탭이 이미 같은 읽기를 하므로 결과는 같다.
- 새 장면 `inventory`만 기준 이미지가 없어 RED(추가).

### 검수표

artboard `Inventory.dc.html` → 앱:
- Mock 기본 실행: 인벤토리 탭은 "저장된 계획이 없습니다" 안내다(Mock 기본 계정에 목표가 없음). 시안 숫자 장면은 fixture로만 열린다. golden `inventory` 장면이나 `test/inventory_page_test.dart`의 fixture 테스트를 보라.
- 확인 포인트:
  1. 4섹션 A/B/C/D가 들어오고 C·D가 사선으로 맞물리는가(사이 한 칸).
  2. 사이드바:
     - 목록·분석 seg에서 분석이 꺼져 있는가.
     - 아이템·장비 seg, 부족한 것 n종(파랑 선택) / 전체 n종.
     - 종류 버튼이 아래로 갈수록 8px씩 좁아지고 "부족 n" 칩이 붙는가.
     - 주요 재화 카드 두 장.
  3. KPI 띠 6칸: 부족 재화 핑크, 이력 값 `—`.
  4. 위험도 행: 아이콘 · 이름 · 보유/필요/사용 학생 · 막대(폭 = 점수, 핑크/노랑) · 점수. 첫 행 선택 테두리.
  5. 행을 누르면 상세(kv · 사용 학생 · 보충 방법 빈 상태 · 최근 변화 빈 상태 · 액션 3개)가 바뀌는가.
  6. 재화 카드 → 고치기 꺼짐 + 안내.
  7. 작은 창(1280×720)에서 예외 없이 잘리는가.

### 미검증 항목

- analyze·일반 테스트·process·golden·`codealmanac validate`·`git diff --check` 전부 미실행(사용자 PC gate 필요).
- 섹션 path bounds(±1px)·섹션 안 요소(±2px)는 계산으로만 맞췄다. 시안 사이드바·목록 좌표를 섹션 위 기준 상대값으로 옮겼고(`InventoryMetrics`), 화면에서 재지 않았다.
- 섹션 진입·퇴장 모션은 넣지 않았다. 계획 탭의 `PlanSectionMotion`은 Lane A 파일이라 쓰지 않았고, 탭 전환은 셸 모션 그대로다.
- 독립 검토 에이전트가 정적으로 본 결과를 반영했다: 후보 띠 높이, 불필요 import, null-aware element, 다른 품목을 고르면 draft 버리기, 계정 실패 때 이전 계산 비우기, 첫 로드 microtask, 작은 창 KPI 높이.

### 발견 사항

1. FD-095 "아이템·장비" seg의 뜻이 시안과 엇갈린다.
   - 시안은 "아이템" 모드에 "장비 설계도 20 · 부족 1"과 헤어핀 행을 보인다.
   - 카탈로그의 장비 설계도·장비·무기 부품은 모두 profile·category `equipment`라, 시안대로면 "장비" 모드에 남는 것이 없다.
   - 이번에는 profile로 나눴다(장비 = `equipment`). 오케스트레이터 결정이 필요하다.
2. Mock 기본 실행으로 시안 숫자 장면을 볼 수 없다. `lib/services/**`는 이 slice 범위 밖이라 검수 fixture를 테스트 쪽(`test/inventory_fe6a_fixture.dart`)에 두었다. 앱 mock 모드 개발 패널에 이 fixture를 여는 시나리오가 필요하면 서비스 쪽 요청이다.
3. FD-146 영속 "확인 필요" 필드가 계약에 아직 없다(위 처리한 FD).
4. "마지막 스캔"은 FB-2 summary(`last_scan_at`, fb2b-dart)로 지금도 그릴 수 있다. KPI 증감·스파크라인과 함께 FE6-f에서 하는 것으로 두었다.
5. 새 화면 Studio 문서는 워크플로 불변식의 `ui/studio/*_studio_layout.dart` 대신 `lib/ui/inventory/inventory_studio_layout.dart`에 두었다. 워커 프롬프트의 고칠 곳(`lib/ui/inventory/**`)을 지켰다. 옮길지는 오케스트레이터가 정한다.
6. 인벤토리 탭이 셸 시작 때 오프스테이지에서 계산을 부른다. 목표가 있는 실제 백엔드에서는 부족 계산 + 문서 계산이 1회씩 더 든다. 탭을 처음 열 때로 미루려면 `app_shell.dart`가 탭 활성 신호를 넘겨야 한다(Lane A·공용 파일).
7. 시안 `.pt` 54×44(위험도 행)·37×30(재화 카드)·38×30(학생)은 키트 크기 변형에 없다. `ItemIconTile`의 임의 크기로 그렸다.
8. 학생 초상은 `ItemIconTile`(아이템 배경 + 초상 92%)로 그렸다. 키트 `PortraitStrip`(98%)과 미세하게 다르다.

### 사본·commit.json

- 착수 사본: `debug/frontend_fe6a/pre/<경로>`(고친 기존 파일 3개, 착수 때 둠).
- 끝 사본: `debug/frontend_fe6a/post/<경로>`(고친 기존 파일 3개 + 새 코드·테스트 파일 8개).
- `debug/frontend_fe6a/commit.json`:
  - slice `fe6a`, `status=false`, `post_dir`
  - modified 3개
  - added: 새 파일 8개 + `frontend/test/goldens/baseline/inventory.png`(사용자가 `-UpdateGoldens`로 만든다)
  - `whole = [almanac/workflows/frontend-redesign-status-lane-b.md]`

### 다음 행동과 사용자 실행 명령

- FE6-a 코드는 끝났다. Lane B는 여기서 멈춘다.
- PowerShell, `C:\Users\brigh\planner_of_plana\BA Planner\v7`에서 아래 명령을 한 줄씩 실행한다. 하나가 실패하면 거기서 멈추고 결과를 오케스트레이터에게 보낸다. 순서는 오케스트레이터가 정한다.
  1. Lane A(FE5-d)·Lane B 두 워커가 모두 멈춘 뒤 실행하고, 결과(`debug/frontend_gate/` 요약)를 오케스트레이터에게 보낸 뒤 기다린다. 예상: 기존 golden 변화 0, 새 장면 `inventory`만 기준 없음 RED, 일반 테스트 +22(화면 모델 9 + 컨트롤러 13) + 다시 쓴 인벤토리 위젯 테스트.
     - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1`
  2. 오케스트레이터가 `failures/`를 검토하고 승인한 뒤:
     - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1 -UpdateGoldens`
     - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1`
  3. 커밋:
     - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice fe6a -DryRun`
     - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice fe6a`

## FE6-b 착수 기록 (2026-10-11)

- 상태: 진행 중 → 코드 작성 완료(아래 종료 기록).
- 범위: 인벤토리 전체 아이템 보기와 FE6-a 후속 2건. 워커 프롬프트 `debug/frontend_redesign_handoff/fe6b-worker-prompt-20261011.md`.
  1. 전체 아이템(시안 Inventory-All): 그룹 헤더 + 74×74 타일, 그룹마다 사선 이동, 충족 막대(부족 분홍·충분 파랑·과잉 노랑 FD-040·계획 밖 없음·보유 모름 빗금), 그룹 "부족 n" 칩 → 상위 5 플라이아웃(키트 `AnchoredFlyout`·`ShortageBreakdownRow`). 상세 rect는 FE6-a와 같다.
  2. FD-095 재검토: 전체 아이템 그룹을 category·FB-3 family로 그려 보고 권장안을 종료 기록에 적는다.
  3. 후속 A: Studio 문서를 `lib/ui/inventory/inventory_studio_layout.dart` → `lib/ui/studio/inventory_studio_layout.dart`로 옮긴다(옛 경로는 삭제, commit.json `deleted`).
  4. 후속 B: 인벤토리 읽기·계산을 탭을 처음 열 때로 미룬다. `app_shell.dart`는 탭 활성 신호 한 줄만 넘긴다.
- 범위 밖: `lib/services/**`, 계획·학생 화면과 `lib/ui/widgets/plan_*`(Lane A), 키트, golden harness·기존 golden 테스트 파일, `backend/**`·`contracts/**`, `scan_page.dart`, `statistics/**`.
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `1fbc4ddd540124d70cb095267229018152286801`(XB M1 exact18, parent `f1ca4713`. Dart 변경 0).
- 막힘: 대장 막힘 요약에서 FE6-b를 막는 열림 FD 없음. FD-095는 이번 slice에서 재검토한다.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe6b/pre/<v7 기준 경로>`):
  - `frontend/lib/ui/pages/inventory_page.dart`
  - `frontend/lib/ui/app_shell.dart`(최소 diff)
  - `frontend/lib/ui/inventory/inventory_controller.dart`
  - `frontend/lib/ui/inventory/inventory_view_model.dart`
  - `frontend/lib/ui/inventory/inventory_workspace.dart`
  - `frontend/lib/ui/inventory/inventory_studio_layout.dart`(이동 → 삭제)
  - `frontend/test/inventory_page_test.dart`
  - `frontend/test/inventory_currency_readonly_test.dart`
  - `frontend/test/inventory_controller_test.dart`
  - `frontend/test/inventory_view_model_test.dart`
  - `frontend/test/inventory_fe6a_fixture.dart`
- 새 파일(예정): `frontend/lib/ui/studio/inventory_studio_layout.dart`, `frontend/test/inventory_shell_lazy_test.dart`, `frontend/test/goldens/fe6b_inventory_all_golden_test.dart`(harness 공개 함수만)와 기준 이미지 `inventory-all.png`.
- WIP: 고칠 파일 11개 모두 미커밋 변경 없음(작업 트리 = index blob, 줄바꿈 정규화 기준). `inventory_page.dart`·`inventory_page_test.dart`는 CRLF, 나머지는 LF다. `inventory_workspace.dart`는 FE6-a 때 줄 5개가 CRLF로 섞여 있었다(종료 기록 발견 사항).

## FE6-b 종료 기록 (2026-10-11, 코드 작성 완료·gate 미실행)

시안 Inventory-All(전체 아이템, 기술 노트(최상급) 선택, 플라이아웃 1개 열림)의 타일 보기와 FE6-a 후속 2건을 끝냈다.

Flutter·Dart가 이 환경에 없어 analyze·테스트·golden은 돌리지 않았다. 정적 검토만 했고, 통과를 주장하지 않는다.

### 실행 명령·결과

- `flutter analyze`·`flutter test`·golden: 실행하지 않았다(SDK 없음).
- 정적 검토: 별도 검토 에이전트가 바뀐 파일을 pre 사본·키트·서비스·harness와 대조해 읽었다.
  - 확인한 것: 쓴 API의 시그니처, import, record 타입, const, lint, 줄바꿈.
  - 새·바뀐 테스트의 기대값은 fixture에서 손으로 계산해 확인했다.
  - 컴파일·analyze 지적은 없었다.
- 검토 지적 4건을 고쳤다:
  1. 고른 타일의 분홍 테두리·빛이 타일 줄 clip에 위쪽이 잘렸다. 타일 줄은 이제 자르지 않는다(`_Fit(clip: false)`). 배치는 같다.
  2. 그룹 머리가 30px 줄 가운데에 놓여 시안보다 4px 낮았다. 머리 띠를 줄 위에 칩 높이(24)로 붙였다. 24 + 타일까지 6 = 시안 22 + 8과 같은 30이다.
  3. 모르는 category는 id를 이름으로 쓰므로 길면 머리 줄이 넘칠 수 있었다. 이름은 `FittedBox(scaleDown)`로 줄여 맞춘다.
  4. 거르기 칩의 의미 라벨이 정렬 칩 것("… 순 정렬")이었다. 거르기 칩은 켜고 끄는 단추(`toggled`)로 알린다. "종류순"은 누르는 칩이 아니라 지금 정렬을 보이는 표시로 바꿨다(전체 보기 정렬은 시안에 종류순 하나다).
- 기기 쓰기: 바이트 대조는 아래 "사본·commit.json"에 적었다.

### 고친 파일

- **`frontend/lib/ui/studio/inventory_studio_layout.dart`(새 경로, 후속 A)**
  - `lib/ui/inventory/inventory_studio_layout.dart`를 옮겼다. 바뀐 것은 import 2줄(`../widgets/section_studio_document.dart`·`section_template.dart` 기준 상대 경로)뿐이다. A/B/C/D 좌표와 id는 그대로다.
  - 전체 아이템 좌표 `InventoryAllMetrics`를 이 파일에 더했다: 타일 74, 간격 10(pitch 84), 그룹 머리 22 + 8, 그룹 사이 18, 타일 왼쪽 14, 머리 왼쪽 28.
  - 옛 파일은 지운다(commit.json `deleted`). 이 환경의 기기 연결로는 파일을 지울 수 없어 PC 작업 트리에 아직 남아 있다. 아래 사용자 실행 명령 ⓪에서 지운다.
- **`frontend/lib/ui/inventory/inventory_view_model.dart`**
  - `InventoryTileTone`(none · unknown · shortage · enough · excess)과 `inventoryTileTone`:
    - 계획에 안 쓰면 none
    - 보유 모름이면 unknown
    - 부족이면 shortage
    - FD-040 과잉(보유 ≥ 필요 × 1.5)이면 excess
    - 나머지는 enough
  - `inventoryTileGroupId`·`inventoryTileGroupLabel`: 장비 category가 아니면 category 그대로다. 장비는 FB-3 family로 나눈다:
    - `equipment_exp` → 강화석
    - `equipment:<Key>`, tier 없음 → 만능 설계도
    - `equipment:<Key>`, tier 있음 → 장비
    - `weapon_exp:<part>` → 무기 부품
    - 나머지 → 장비 기타
  - `InventoryTileGroup`(부족 수, 부족량 순 목록)과 `InventoryBoard.tileGroups(mode, category, plannedOnly, hideZero)`:
    - 그룹 순서는 FD-095 종류 순서, 장비 안은 위 family 순서다.
    - 그룹 안은 카탈로그 순서다.
    - "보유 0 숨기기"는 보유를 모르는 품목을 남긴다.
- **`frontend/lib/ui/inventory/inventory_controller.dart`**
  - `plannedOnly`·`hideZero` 토글과 `tileGroups`를 더했다.
  - `showCategoryShortages`는 그 종류의 "부족한 것" 보기로 간다.
  - 전체 보기의 `visible`은 타일 순서다. FE6-a 로직(계획을 상태보다 먼저 읽기, 편집 닫기, 재화 규칙, 후보 승인)은 손대지 않았다.
- **`frontend/lib/ui/inventory/inventory_workspace.dart`**
  - C 섹션: 사이드바 "전체"면 제목 "전체 아이템" + InfoPopover "타일 읽는 법"(분홍·파랑·노랑·빗금 설명) + 칩(종류순 표시, 계획에 쓰는 것만, 보유 0 숨기기)을 보인다. 내용은 타일이다.
  - 타일은 공용 `DiagonalScrollViewport`(translate)의 행으로 쌓는다. 머리 줄 30, 타일 줄 84, 그룹 마지막 줄 92이고, 한 줄 타일 수는 가장 좁은 행 자리 폭으로 정한다.
    - translate 사선이라 그룹이 내려갈수록 왼쪽으로 밀린다. fixture 장면에서 그룹 하나가 약 21px이다.
  - `InventoryItemTile`은 키트 `ItemTile` 74×74다. 막대(tone·fraction):
    - 부족: 분홍 + 충족률
    - 충분·과잉: 파랑·노랑 가득
    - 계획 밖: 없음
    - 보유 모름: 빗금(분홍 + fraction 없음), 수량은 `—`
  - 의미 라벨은 "<이름> 보유 …"다.
  - `_TileGroupHeader`는 SubHeader + "n종"이다. 부족이 있으면 "부족 n" 칩에 키트 `AnchoredFlyout`(hover·누름·포커스로 열림)을 단다.
    - 플라이아웃 내용: `FlyoutHeader('부족한 <종류> n종', note: '부족량 순 · 상위 5')`, `ShortageBreakdownRow` 최대 5개, `FlyoutFooter`("… 외 n종" + "모두 보기 →")
    - "모두 보기"는 그 종류의 부족한 것 보기로 간다.
  - 오른쪽 상세는 FE6-a와 같다. 타일을 고르면 같은 상세가 뜬다.
  - FE6-a 때 이 파일에 섞였던 CRLF 줄 5개를 LF로 맞췄다(발견 사항 1).
- **`frontend/lib/ui/pages/inventory_page.dart`(후속 B)**
  - `active`(기본 true)를 더했다. 첫 로드는 `active`가 처음 true가 될 때 한 번 시작한다(`initState`/`didUpdateWidget` → `_start`, microtask).
  - 시작 전에는 연결 변화에도 읽지 않는다.
- **`frontend/lib/ui/app_shell.dart`(후속 B, +1줄)** — 아래 "app_shell diff".
- **테스트**:
  - `inventory_fe6a_fixture.dart`:
    - 장비 강화석 `Equipment_Icon_Exp_3`을 더했다(family `equipment_exp`, 보유 항목 없음 = 모름).
    - 헤어핀에 family `equipment:Hairpin`·tier 7을 주었다.
    - `inventory` 장면 숫자(아이템 모드)는 그대로다.
  - `inventory_view_model_test.dart`에 4개를 더했다:
    - 그룹 순서·이름·부족 수, 장비 family
    - 거르기
    - 타일 색 5종
    - family 그룹 id
  - `inventory_page_test.dart`에 전체 보기 위젯 테스트 1개를 더했다:
    - 그룹 순서와 사선(아래로 갈수록 dy 증가·dx 감소)
    - 타일 tone·fraction·수량
    - 타일 선택 → 상세
    - 플라이아웃 문구와 "모두 보기"
    - 거르기 칩, 장비 모드 family 그룹, 보유 0 숨기기
  - 첫 테스트와 재화 읽기 전용 테스트(`inventory_currency_readonly_test.dart`)는 전체 보기의 행 키를 타일 키로 바꿨다.
  - `inventory_controller_test.dart`는 장비 모드 기대값에 Exp_3과 그룹 id를 더했다.
  - 새 `inventory_shell_lazy_test.dart` 1개: 셸 시작 때 인벤토리 카탈로그·부족·문서 계산 호출이 0이고, 탭을 열면 각 1, 다른 탭에 갔다 오면 그대로 1이다.
    - 다른 탭도 같은 서비스 메서드를 부르므로 `InventoryController.load`·`_calculate`가 부른 것만 호출 스택으로 센다.
  - 새 `goldens/fe6b_inventory_all_golden_test.dart` 1장(`inventory-all`). harness 공개 함수만 쓴다.

### app_shell diff

```diff
@@ InventoryPage(
                                   onCandidateCommitted: _clearInventoryCandidate,
+                                  active: _section == AppSection.inventory,
```

- 크기: +1줄, -0줄.
- 이유: 셸은 모든 탭을 오프스테이지로 짓는다. 인벤토리 페이지가 보이는지 알 길이 없어 탭 활성 신호를 넘겼다.
- 다른 탭과 셸 상태·전환에는 손대지 않았다. `InventoryPage`를 직접 만드는 테스트는 기본 `active = true`라 전처럼 바로 읽는다.

### 처리한 FD

- **FD-040**: 과잉 노랑은 활성 계획이 쓰는 재화 중 보유 ≥ 필요 × 1.5다. FE6-a의 `excess` 판정을 타일 tone으로 그대로 쓴다.
- **FD-095(재검토)**: 아래 권장안. 이번 slice에서는 바꾸지 않았다.
- **FD-030·FD-031**: FE6-a 그대로다(부족한 것 보기·충족률).
- **FD-094**: 기본 진입은 FE6-a 그대로 부족 진단이다. 전체 보기는 사이드바 "전체"로 연다.

### FD-095 권장안 — profile 기준 유지

권장: "아이템·장비" seg는 지금처럼 profile 기준(장비 = category `equipment`)으로 둔다. 장비 모드 안의 그룹을 FB-3 family로 나눠 보이는 것(이번 slice)으로 시안의 "장비 설계도" 요구를 채운다.

근거:
1. 카탈로그에서 장비 설계도(Useall, tier 없음)·장비(T1~T10)·강화석(`equipment_exp`)·무기 부품(`weapon_exp:*`)은 모두 profile·category `equipment`다. 시안대로 장비 설계도를 "아이템" 모드로 옮기면 강화석·장비·무기 부품만 남는다.
   - 같은 category 안에서 family로 모드를 가르는 규칙이 새로 생긴다.
   - 사이드바 종류 버튼의 category 1:1(FD-095 본문)이 깨진다.
2. 스캔 profile(아이템 / 장비)도 같은 경계다. 스캔 후보 승인·"마지막 스캔"이 profile 단위라, 화면 모드와 스캔 단위가 같아야 "이 모드를 다시 스캔" 안내가 맞다.
3. 전체 아이템에서 family로 그려 보니 장비 모드가 강화석 · 만능 설계도 · 장비 · 무기 부품으로 자연스럽게 나뉜다. 시안의 "장비 설계도 20 · 부족 1" 줄은 장비 모드의 "만능 설계도"·"장비" 그룹 머리 "부족 n"으로 같은 정보를 준다.

판단: 위 근거로 바꾸는 쪽이 명확하지 않으므로 그대로 두었다. 오케스트레이터가 시안 쪽(설계도를 아이템 모드로)을 고르면 `InventoryBoard`의 모드 거르기와 `inventoryTileGroupId`만 바꾸면 된다. 컨트롤러·화면 구조는 그대로 쓴다. 결정을 요청한다.

### golden 예측

- **새 장면 `inventory-all`**: 기준 이미지가 없어 RED다(사용자가 `-UpdateGoldens`로 만든다).
  - 내용: 아이템 모드 전체 보기. 엘레프·오파츠·활동 보고서·기술 노트·BD 그룹이 사선으로 내려간다. 기술 노트(최상급)가 골라져 오른쪽 상세에 있다. 기술 노트 그룹 플라이아웃("부족한 기술 노트 1종")이 열려 있다.
  - 게임 그림이 없는 아이콘은 키트 규칙대로 빈 상자다.
- **`inventory`(FE6-a)**: 변화 0으로 예측한다.
  - fixture에 더한 Exp_3·헤어핀 family는 장비 모드에만 보이고, 아이템 모드의 KPI·목록·사이드바 수는 그대로다.
  - 지연 로드는 탭을 연 뒤 같은 상태로 끝난다(장면은 탭을 누르고 행을 기다린다).
  - "부족한 것" 제목·칩은 바꾸지 않았다(`_SortChip` 그대로).
- **다른 장면**: 변화 0. app_shell 변경은 인벤토리 페이지에 `active`만 넘긴다.
  - Mock `loadRepositoryPlan`의 목표 → 문서 이전(revision 증가)은 셸 시작 때 인벤토리가 아니라 홈·통계가 부른다. 인벤토리를 열지 않는 장면의 최종 상태는 같다.

### 검수표

| 항목 | 시안·규칙 | 구현 | 확인 |
|---|---|---|---|
| 전체 보기 진입 | 사이드바 "전체" | `inventory-view-all` → 타일 | 위젯 테스트 |
| 그룹 머리 + 타일 74×74 | Inventory-All | `ItemTile` 74, pitch 84 | 위젯 테스트(크기는 golden) |
| 그룹마다 사선 이동 | 약 21px | translate 뷰포트, 그룹 dy↑ dx↓ | 위젯 테스트 |
| 막대 색 | 분홍·파랑·노랑·없음·빗금 | `inventoryTileTone` → `CoverageTone` | 화면 모델·위젯 테스트 |
| 과잉 | FD-040 ≥ 1.5배 | FE6-a `excess` | 화면 모델 테스트 |
| "부족 n" 플라이아웃 | 상위 5, 부족량 순 | `AnchoredFlyout` + `ShortageBreakdownRow` | 위젯 테스트·golden |
| "모두 보기" | 그 종류 부족 목록 | `showCategoryShortages` | 위젯 테스트 |
| 타일 → 상세 | FE6-a 상세 rect | 같은 D 섹션 | 위젯 테스트·golden |
| 거르기 | 계획에 쓰는 것만·보유 0 숨기기 | 모름은 남김 | 화면 모델·위젯 테스트 |
| 장비 family 그룹 | FD-095 재검토 | 강화석·만능 설계도·장비·무기 부품 | 화면 모델·위젯 테스트 |
| Studio 문서 위치 | `ui/studio/*_studio_layout.dart` | 이동, 옛 경로 삭제 | 정적 확인(옛 경로 import 0) |
| 지연 계산 | 셸 시작 0, 탭 열면 1 | `active` + app_shell 1줄 | `inventory_shell_lazy_test` |
| 재화 읽기 전용(fb3-dart) | 재화 dirty 금지 등 | 손대지 않음 | 기존 테스트(타일 키로만 변경) |
| 앱 문구 | ~습니다체 | 빈 상태 "조건에 맞는 품목이 없습니다." 등 | 정적 확인 |

### 미검증 항목

- analyze(info 포함)·일반 테스트·golden을 돌리지 않았다. 아래 수는 정적 예상이다.
  - 일반 테스트: +6(화면 모델 4, 인벤토리 위젯 1, 셸 지연 1)
  - golden: 새 장면 1(`inventory-all`)
- 그룹 사선 이동 21px, 타일 줄 수(뷰포트 폭에 따른 한 줄 타일 수), 고른 타일 빛이 이웃 줄에 겹치는 모양은 golden에서 본다.
- `inventory_shell_lazy_test`는 호출 스택 프레임 이름(`InventoryController.load`·`InventoryController._calculate`)에 기댄다. Dart VM 스택 형식이 다르면 셈이 0이 된다. 그때는 테스트를 서비스 래퍼 셈으로 바꾸면 되고, 화면 동작과는 무관하다.
- 실제 백엔드 카탈로그의 family 값(`equipment_exp`·`equipment:<Key>`·`weapon_exp:<part>`)은 FB-3 계약과 fixture로만 확인했다.

### 발견 사항

1. FE6-a에서 쓴 패치 도구가 한 줄 치환 때 CRLF 형태로 맞춰 LF 파일인 `inventory_workspace.dart`에 CRLF 줄 5개를 넣었다.
   - autocrlf로 git blob은 LF라 커밋 내용은 문제없다.
   - 작업 트리만 섞여 있던 것을 이번에 LF로 맞췄다. 도구는 파일의 주 줄바꿈으로 바꾸도록 고쳤다.
2. `fe_commit.ps1`에는 `deleted`를 다루는 코드가 없다. commit.json의 `"deleted": ["frontend/lib/ui/inventory/inventory_studio_layout.dart"]`는 오케스트레이터가 처리해야 한다.
   - 작업 트리의 옛 파일은 이 환경에서 지울 수 없어 사용자 명령 ⓪에 두었다.
   - 옛 파일을 import하는 곳은 lib·test·tool에 없다. 지우기 전에도 빌드는 깨지지 않지만 `inventoryStudioDocument`가 두 벌 있다.
3. 전체 보기 정렬은 시안에 종류순 하나다. "종류순"은 누르는 칩이 아니라 표시로 두었다. 다른 정렬이 필요하면 FD로 정한다.
4. 키트 요청은 없다. 그룹 머리는 키트 `SubHeader` + `BaChip`, 플라이아웃은 `AnchoredFlyout`(기본 오른쪽) + `ShortageBreakdownRow`로 충분했다. 통째 프리셋 `ShortageBreakdownFlyout`은 부족량·단계별 seg가 있는 Flow-4 모양이다. 시안 전체 보기(seg 없음, 상위 5 + "모두 보기")와 달라 조각 위젯을 썼다.
5. 시작 커밋이 프롬프트의 `f1ca4713`이 아니라 그 뒤 XB M1 커밋 `1fbc4ddd`(Dart 변경 0)다. 고친 파일 11개는 그 index와 같았다.

### 사본·commit.json

- 착수 사본: `debug/frontend_fe6b/pre/<경로>`. 고친 기존 파일 10개와 옮긴 옛 Studio 문서를 착수 때 두었다.
- 끝 사본: `debug/frontend_fe6b/post/<경로>`. 고친 기존 파일 10개와 새 코드·테스트 파일 3개다.
- `debug/frontend_fe6b/commit.json`:
  - slice `fe6b`, `status=false`, `post_dir`
  - modified 10개
  - added: 새 파일 3개 + `frontend/test/goldens/baseline/inventory-all.png`(사용자가 `-UpdateGoldens`로 만든다)
  - `deleted = [frontend/lib/ui/inventory/inventory_studio_layout.dart]`(fe_commit 미지원 → 오케스트레이터 처리)
  - `whole = [almanac/workflows/frontend-redesign-status-lane-b.md]`. 바뀌는 기존 기준 이미지는 없다고 예측했다.
- PC에 쓴 작업 트리 파일 13개·status·commit.json과 test 쪽 사본은 다시 읽어 바이트로 대조했다. `debug/frontend_fe6b/{pre,post}/frontend/lib/ui/…` 사본은 폴더가 너무 깊어 기기 연결이 다시 읽지 못한다. 그쪽은 쓰기 성공만 확인했다(내용은 작업 트리 파일과 같은 원본에서 썼다).

### 다음 행동과 사용자 실행 명령

- FE6-b 코드는 끝났다. Lane B는 여기서 멈춘다. FD-095 권장안(profile 기준 유지)에 대한 오케스트레이터 결정을 기다린다.
- PowerShell, `C:\Users\brigh\planner_of_plana\BA Planner\v7`에서 아래 명령을 한 줄씩 실행한다. 하나가 실패하면 거기서 멈추고 결과를 오케스트레이터에게 보낸다. 순서는 오케스트레이터가 정한다.
  0. 옮긴 Studio 문서의 옛 파일을 작업 트리에서 지운다(gate가 커밋될 상태로 돌게). 사본은 `debug/frontend_fe6b/pre/`에 있다.
     - `Remove-Item frontend\lib\ui\inventory\inventory_studio_layout.dart`
  1. Lane A(FE5-e)·Lane B 두 워커가 모두 멈춘 뒤 실행한다. 결과(`debug/frontend_gate/` 요약)를 오케스트레이터에게 보내고 기다린다.
     - 예상: 기존 golden 변화 0, 새 장면 `inventory-all`만 기준 없음 RED, 일반 테스트 +6.
     - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1`
  2. 오케스트레이터가 `failures/`를 검토하고 승인한 뒤:
     - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1 -UpdateGoldens`
     - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1`
  3. 커밋. 옛 경로 삭제는 fe_commit이 다루지 않으므로 오케스트레이터가 함께 처리한다:
     - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice fe6b -DryRun`
     - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice fe6b`

## FE6-b gate ① RED 수정 기록 (2026-10-11)

수정 요청 `debug/frontend_redesign_handoff/fe6b-fix-message-20261011.md`(gate `20261011_184427` → 재실행 `20261011_190337`)를 처리했다. Flutter·Dart가 이 환경에 없어 다시 돌리지 않았다(정적 검토만 했다).

### 오케스트레이터 수정 두 줄(유지)

- `inventory_workspace.dart`의 "종류순" 표시: `const Semantics(` → `Semantics(` + `key: const ValueKey('inventory-all-sort-kind')`. `BaChip`이 const가 아니어서 `const_with_non_const`였다. 내 종료 기록의 정적 검토가 놓쳤다.
- 타일 의미 라벨: `${owned == null ? '모름' : owned}` → `${owned ?? '모름'}`.
- 이번 수정은 PC의 이 파일(두 줄이 들어간 상태)에서 시작했고, 두 줄은 그대로다.

### 원인

- 부족 보기의 위험도 목록과 전체 보기의 타일은 둘 다 `_riskContent`가 같은 자리에 돌려주는 키트 `DiagonalScrollViewport`다. 둘 다 key가 없고 타입이 같아, 보기를 바꾸면 Flutter가 같은 State를 다시 쓴다. 그래서 State가 가진 자체 `ScrollController`도 같다.
- 키트 안쪽 `SingleChildScrollView`의 key는 `'<keyPrefix>-scroll'`인데, keyPrefix가 `inventory-risk-diagonal` → `inventory-tiles-diagonal`로 바뀐다. 그래서 스크롤 뷰만 새로 만들어진다.
  - 새 Scrollable이 같은 컨트롤러에 붙는다. 옛 Scrollable의 position은 프레임 끝(finalizeTree)에야 떨어진다.
  - 그 사이 키트의 `AnimatedBuilder`(169행)가 `controller.offset`을 읽어 `_positions.length == 1` assertion이 났다.
- 그 행 subtree를 짓지 못해 그룹 머리·타일이 없었다. 위젯 테스트 267행(`inventory-group-student_eleph`)과 golden(`inventory-tile-Item_Icon_SkillBook_Gehenna_3`)이 못 찾은 것은 그 결과다.
- 오케스트레이터 진단 (b)(viewport가 다시 마운트되며 옛 position이 프레임 끝까지 남음)와 같은 유형이다. (a)(컨트롤러를 같이 넘김)는 아니다. 인벤토리는 컨트롤러를 넘기지 않는다.
- 필터 칩·플라이아웃·종류 바꾸기는 keyPrefix를 바꾸지 않아 스크롤 뷰가 다시 만들어지지 않는다. 다시 만들어지는 것은 보기 전환(사이드바 "전체"↔"부족한 것", "모두 보기")뿐이다.

### 수정

- `inventory_workspace.dart`만 바꿨다. 두 viewport에 서로 다른 key를 주었다: 타일 `inventory-tiles-viewport`, 위험도 목록 `inventory-risk-viewport`.
  - 보기를 바꾸면 State가 통째로 바뀌어 각자 자기 `ScrollController`를 갖는다. 옛 컨트롤러는 옛 State와 함께 정리된다.
  - 같은 보기 안의 칩·플라이아웃·모드 전환은 key가 그대로라 다시 마운트되지 않는다.
- 키트는 고치지 않았다. 키트 요청은 필요 없다고 판단했다(같은 State를 다른 스크롤 뷰에 재사용하지 않으면 position은 하나다).
- 화면 그림은 바뀌지 않는다(key만 더함). `inventory` 장면 변화 0 예측은 그대로다.

### 추가 테스트

- `inventory_page_test.dart`에 "view switches, filter chips and the flyout raise no exception" 1개를 더했다. 기존 테스트 기대는 바꾸지 않았다.
- 2바퀴 동안 아래를 연달아 하고, 끝에 `tester.takeException()`이 null인지 본다:
  1. 전체 보기로 간다(리오 타일 있음).
  2. 엘레프 "부족 2" 플라이아웃을 열고(`부족한 엘레프 2종` 보임), 제목을 눌러 바깥 누르기로 닫는다(사라짐).
  3. 계획에 쓰는 것만·보유 0 숨기기를 켰다 끈다(리오 타일 있음).
  4. 부족한 것 보기로 돌아간다(리오 행 있음).
- 수정 전 코드에서는 1단계 첫 전환에서 같은 assertion이 난다.

### 사본·commit.json

- 끝 사본 갱신: `debug/frontend_fe6b/post/frontend/lib/ui/inventory/inventory_workspace.dart`(오케스트레이터 두 줄 + viewport key 2개), `debug/frontend_fe6b/post/frontend/test/inventory_page_test.dart`.
- commit.json 목록은 바뀌지 않는다. 바뀐 두 파일은 이미 modified에 있다.

### 다음 행동

- Lane B는 여기서 멈춘다. 예상: 일반 테스트 +1(이번 추가), FE6-b 몫 실패 0. golden은 `inventory-all`만 기준 없음 RED(승인 뒤 `-UpdateGoldens`), `inventory` 변화 0.
- 사용자 실행 명령은 FE6-b 종료 기록과 같다:
  0. 옛 Studio 문서가 아직 작업 트리에 있다(gate `20261011_190337`도 이 파일이 있는 채로 돌았다). gate 전에 지운다: `Remove-Item frontend\lib\ui\inventory\inventory_studio_layout.dart`
  1. `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1` → 결과를 오케스트레이터에게 보내고 기다린다.
  2. 승인 뒤 `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1 -UpdateGoldens` → `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1`
  3. `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice fe6b -DryRun` → `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice fe6b`(옛 경로 삭제는 오케스트레이터가 함께 처리)

## fb10a-dart 착수 기록 (2026-10-11)

- 상태: 진행 중 → 코드 작성 완료(아래 종료 기록).
- 범위: FB-10a(스캔 일시정지·이어서)의 Dart 연결과 지금 스캔 화면의 최소 연결. 워커 프롬프트 `debug/frontend_redesign_handoff/fb10adart-worker-prompt-20261011.md`, 목록은 CF 로그 2026-10-11 18:15.
  1. DTO·서비스:
     - `ScannerEventKind`에 paused·resumed를 더한다.
     - 새 `ScannerSessionControl`(accepted·control_state·reason·terminal)과 control state·pause reason enum을 만든다.
     - `ScannerSessionSnapshot`에 control_state·reason을 더한다.
     - `pauseScannerSession`·`resumeScannerSession`을 ScannerService·client·Process·Mock에 연결한다.
     - 검사기는 strict로 둔다.
  2. 새 이벤트 종류로 깨지는 exhaustive 분기를 채운다.
  3. 지금 스캔 화면(`scan_page.dart`)과 dock을 최소로 연결한다: 일시정지 → paused 사유 표시 → 이어서, Esc = 중지(기존 cancel). 새 디자인은 하지 않는다.
- 범위 밖:
  - crop·inventory entry 승인·재화 스캔
  - "FB-10 형식 고정" 선언
  - FE8-f2·g2·g3(본격 일시정지 화면)
  - `backend/**`·`contracts/**`·`frontend/tool/**`
  - developer_tools(Lane A M2)
  - 계획·학생·인벤토리 화면
  - golden harness·기존 golden 테스트
- 시작 조건: backend 로그 끝에 XB "FB-10a 메인 반영 완료"(2026-10-11 20:55, 12경로 SHA 표)가 있다. 충족했다.
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `feb4dc2b67e331892d856bc3d110260b00164183`.
- XB 반영 SHA 대조(메인 작업 트리 SHA256 = XB 20:55 표):
  - `contracts/scanner-protocol-v1.schema.json` `320c7c707c614d71c8d2847d4d2c8b8c1d0ca5785c40ac856cd3fff4948bcbd4`: 일치
  - `contracts/fixtures/scanner_pause_fb10a_v1.json` `e94a59399438793a0e24b7d4180b47b3cfaac9e2f63e6a6acafa0a5c93b67b12`: 일치. 41 cases.
- 고칠 기존 파일(착수 사본 `debug/frontend_fb10adart/pre/<v7 기준 경로>`)과 WIP(작업 트리 ≠ index blob):
  - `frontend/lib/services/scanner_service.dart`: WIP 있음(unresolved slot·identity DTO, `confirmedFields`). LF.
  - `frontend/lib/services/planning_protocol_client.dart`: WIP 있음(identity 오류 코드 5개, unresolved_slots·assign_identity 응답 검사). CRLF 주(LF 줄 섞임).
  - `frontend/lib/services/process_app_service.dart`: WIP 있음(`confirmedFields`, unresolved·assign 위임). CRLF 주.
  - `frontend/lib/services/mock_app_service.dart`: WIP 있음(identity·unresolved Mock). CRLF 주.
  - `frontend/lib/ui/pages/scan_page.dart`: WIP 있음(unresolved slot 검토, dock 학생 피드백 단순화 등). LF.
  - `frontend/lib/ui/widgets/scan_companion_dock.dart`: WIP 있음. CRLF.
  - `frontend/lib/ui/app_shell.dart`: WIP 없음. 스캔 탭 활성 신호 1줄만 넣는다(Esc가 다른 탭에서 스캔을 끊지 않게).
  - `frontend/test/scanner_protocol_client_test.dart`: WIP 있음. snapshot 예시에 새 필수 키 2개만 더한다.
- WIP hunk 위치는 HEAD blob과 맞대어 확인하고, 고치는 줄이 겹치거나 맞닿지 않게 둔다(fe_commit은 `git merge-file`로 slice 변경만 올린다).
  - service 4개와 `scan_page.dart`의 HEAD blob은 작은 pack에서 꺼내 맞댔다.
  - `scan_companion_dock.dart`·`scanner_protocol_client_test.dart`의 HEAD blob은 4 GB pack 안에 있어 꺼내지 못했다(종료 기록에 적는다).
- 새 파일(예정): `test/scanner_pause_fb10a_test.dart`(fixture·DTO·client·Mock), `test/scanner_pause_process_e2e_test.dart`(실제 백엔드 pause → paused → resume), `test/scan_page_pause_fb10a_test.dart`(화면·dock 위젯).
- WIP는 지우거나 정리하지 않는다.

## fb10a-dart 종료 기록 (2026-10-11, 코드 작성 완료·gate 미실행)

FB-10a(스캔 일시정지·이어서)의 Dart 연결과 지금 스캔 화면의 최소 연결을 끝냈다.

Flutter·Dart·Python이 이 환경에 없어 analyze·테스트·process E2E·golden은 돌리지 않았다. 정적 검토만 했고, 통과를 주장하지 않는다.

### 실행 명령·결과

- `flutter analyze`·`flutter test`·process E2E·golden: 실행하지 않았다(SDK 없음).
- 정적 검토: 별도 검토 에이전트가 바뀐 파일을 pre 사본·HEAD blob·계약(schema·fixture 41 cases)·Python `ScannerPauseControl`과 대조해 읽었다.
  - 확인한 것: API 시그니처, Dart 3 패턴, lint, fixture 41개의 Dart 경로별 결과, 위젯 테스트 단계별 기대값, merge 안전성.
  - 컴파일 오류는 없었다.
- 검토 지적 4건을 고쳤다:
  1. process E2E 테스트의 불필요한 `dart:async` import(analyze info)를 지웠다.
  2. 이어서 응답 처리를 바꿨다. 받아들여진 응답으로 상태를 진행으로 돌리지 않고, 응답보다 먼저 오는 `resumed` 이벤트만 따른다. 그 사이 새 `paused`(입력 감지)가 오면 응답이 그것을 덮었기 때문이다.
  3. 거절된 이어서(대상 창 미준비 → paused 유지·사유 target_minimized·이벤트 없음)의 화면 경로가 테스트로 덮이지 않았다. 위젯 테스트 1개를 더했다.
  4. Mock resume의 취소 처리 순서를 Python과 같게 맞췄다(미준비 사유 갱신이 취소 확인보다 먼저).

### 고친 파일

- **`lib/services/scanner_service.dart`**
  - `ScannerEventKind`에 paused·resumed를 더했다.
  - `ScannerControlState`(running·pause_requested·paused·terminal)와 `ScannerPauseReason`(user·input_detected·target_minimized) enum을 만들었다.
  - `ScannerSessionControl`:
    - 네 키를 정확히 받고, 모르는 키·빠진 키는 FormatException이다.
    - running·terminal이면 reason null, 그 밖에는 사유가 필수다.
    - terminal 값은 terminal 상태에서만 있다. terminal이면 accepted=false다.
  - `ScannerSessionSnapshot`에 `controlState`·`reason`을 더했다.
    - wire에서는 control_state·reason·terminal 키가 필수이고 짝 규칙을 지킨다.
    - 생성자 인자는 선택이다. 기본값은 terminal 유무로 정해, 기존 호출부·테스트가 바뀌지 않는다.
  - `ScannerEvent.fromPayload`: paused는 사유를 필수로 받고, resumed는 `reason: null` 키를 필수로 받는다.
  - `ScannerEvent.pauseReason` getter를 더했다.
  - `ScannerService.pauseScannerSession`·`resumeScannerSession`을 더했다. client는 exact `session_id`·`generation`을 보낸다.
  - 이벤트 커서는 그대로다. paused·resumed도 sequence를 따르고, 세션을 끝내지 않는다.
- **`lib/services/planning_protocol_client.dart`**
  - 이벤트 검사:
    - paused: 기본 키 + `reason` 정확히, 사유 셋 중 하나
    - resumed: 기본 키 + `reason: null` 정확히
  - `scanner.session.pause`·`resume` 응답은 `_validScannerSessionControl`(schema `sessionControl` allOf)로 검사한다.
  - `scanner.session.snapshot` 응답은 control 짝 규칙을 더 검사한다.
  - 오류 코드는 기존 scanner 목록 그대로다(`stale_generation` 등).
- **`lib/services/process_app_service.dart`**: pause·resume을 `ScannerProtocolClient`에 위임한다.
- **`lib/services/mock_app_service.dart`**(Python `ScannerPauseControl` 규칙):
  - pause는 진행 중이고 취소 요청이 없을 때만 받는다. 받으면 `pauseRequested`가 된다.
  - 진행 단계(10·20·30ms)는 안전 지점 `_mockScannerStep`을 지난다. 요청 뒤 처음 닿은 안전 지점에서 `paused`를 한 번 내고, 남은 단계는 미룬다.
  - resume은 paused에서만 받는다.
    - 대상이 준비되지 않았으면 거절하고 사유를 `targetMinimized`로 바꾼다. 이벤트는 없다.
    - 받으면 `resumed`를 응답보다 먼저 내고 미룬 단계를 잇는다.
  - 자동 이어서는 없다. 취소는 기존 cancel이고, 멈춘 세션을 취소하면 남은 단계는 하지 않는다.
  - snapshot에 제어 상태를 싣는다.
  - 테스트·개발용 `debugRequestScannerPause(sessionId, reason)`는 입력 감지·최소화 같은 자동 일시정지를 흉내 낸다.
  - 일시정지를 쓰지 않는 기존 흐름의 순서·시각은 그대로다.
- **`lib/ui/pages/scan_page.dart`**(FD-142 최소 연결, 기존 Material 버튼 그대로):
  - 진행 중 "일시정지"(`scan-pause`)를 둔다. 요청을 받아들인 뒤에는 "멈추는 중…"(비활성)이 된다.
  - `paused` 이벤트를 받으면 "이어서"(`scan-resume`)와 사유 문구(`scan-paused-reason`)를 보인다. 사유 문구:
    - user: "일시정지했습니다."
    - input_detected: "마우스·키보드 입력이 감지되어 일시정지했습니다."
    - target_minimized: "게임 창이 최소화되어 일시정지했습니다. 창을 다시 연 뒤 이어서를 누르십시오."
    - 공통 꼬리: "읽은 칸은 남아 있습니다. 이어서를 누르면 계속하고, Esc를 누르면 중지합니다."
  - Esc = 중지(기존 `_cancel`): 키트 `KitOverlayEscape`로 등록한다. 스캔 탭이 보이고(`active`) 세션이 진행 중(일시정지 포함)일 때만 등록하고, 뒤에 열린 팝오버가 Esc를 먼저 받는다.
  - 상태 규칙:
    - `paused` 이벤트가 pause 응답보다 먼저 와도 상태를 되돌리지 않는다.
    - 거절된 이어서는 사유만 바꾼다.
    - snapshot 복구 때는 snapshot 제어 상태가 권위값이다.
  - companion state에 pause·resume·사유를 싣는다.
- **`lib/ui/widgets/scan_companion_dock.dart`**: `ScanCompanionState`에 선택 필드(`pausedLabel`·`pauseRequested`·`onPause`·`onResume`)를 더했다.
  - dock 머리에 일시정지 ↔ 이어서 아이콘(`scan-dock-pause`·`scan-dock-resume`)을 취소 옆에 두고, 사유 문구(`scan-dock-paused`)를 보인다.
  - 기존 생성자 호출은 그대로 컴파일된다. dock 재작성은 FE8-g3 몫이다.
- **`lib/ui/app_shell.dart`(+1줄)**: `ScanPage(... active: _section == AppSection.scan,)`.
  - 이유: 셸은 모든 탭을 오프스테이지로 짓는다. 이 신호가 없으면 다른 탭에서 누른 Esc가 진행 중 스캔을 끊는다.
  - 학생 전체 스캔의 dock이 덮을 때도 section은 scan이라 Esc가 동작한다.
- **`test/scanner_protocol_client_test.dart`(+2줄)**: snapshot 예시에 새 필수 키(`control_state: terminal`, `reason: null`)만 더했다. 기대값은 그대로다.

### 새 테스트

- **`test/scanner_pause_fb10a_test.dart`**(펼치면 39개):
  - fixture 구성: 41 = 유효 15 / 무효 26. 요청 2/8, 제어 응답 7/10, 오류 응답 2, 이벤트 4/8.
  - 요청: client가 유효 요청 payload를 정확히 보낸다.
  - 제어 응답 17개: protocol client를 거쳐 유효는 DTO 값이 일치하고, 무효는 `BackendProtocolException`이다.
  - 오류 응답: `stale_generation`이 그대로 온다.
  - `ScannerSessionControl.fromWire`: fixture와 추가 무효 7개를 확인한다.
  - 이벤트 12개: transport를 거쳐 유효는 sequence 2로 받는다. 무효는 프로토콜 오류 + 연결 끊김이고, `fromPayload`도 거부한다.
  - snapshot: 필수 키·짝 규칙과 무효 8개를 확인한다.
  - 커서: paused·resumed는 sequence를 따르고 세션을 끝내지 않는다.
  - Mock 3개:
    - 순서: phase → paused → resumed → progress → candidate → terminal, sequence 연속
    - 자동 이어서 없음, 끝난 뒤 pause는 terminal
    - 입력 감지 일시정지 → 취소 시 cancelled(resumed·candidate 없음)
    - 모르는 세션은 거부
- **`test/scanner_pause_process_e2e_test.dart`**(process 1개): 실제 Python 백엔드(JSONL)로 한 번 돈다.
  - 대상은 고정 1개, matcher는 취소까지 20ms progress를 내는 fixture다. XB Python 실제 JSONL 테스트와 같은 구성이다.
  - 흐름: pause(응답 pause_requested) → paused(user) → snapshot paused → resume(accepted, running) → resumed → cancel → terminal cancelled.
  - sequence 연속, paused·resumed 각 1번을 확인한다. 게임 창은 쓰지 않는다.
- **`test/scan_page_pause_fb10a_test.dart`**(8개):
  - 일시정지 → "멈추는 중…" → paused 사유 → 자동 이어서 없음 → 이어서 → completed
  - 입력 감지 사유
  - 거절된 이어서(최소화 사유, paused 유지)
  - Esc로 멈춘 스캔 중지(Cancelling… → cancelled, Esc 등록 해제)
  - 숨은 탭에서 Esc 무시
  - 학생 전체 스캔 companion의 onPause·onResume
  - dock 2개(일시정지 버튼·멈추는 중 비활성, 사유·이어서)

### 18:15 목록 검수표

| 18:15 목록 행 | 구현 | 확인 |
|---|---|---|
| `scanner.session.pause/resume` 요청: exact session_id/generation | client가 두 키만 보냄 | fixture 요청 테스트 |
| 응답: exact accepted·control_state(running·pause_requested·paused·terminal)·reason(user·input_detected·target_minimized|null)·terminal(completed·cancelled·failed|null) | `ScannerSessionControl` + protocol 검사(키 정확히, 짝, terminal ⇒ accepted false) | fixture 제어 응답 17 + 추가 무효 7 |
| pause_requested는 수락, paused 이벤트가 실제 멈춤 | 화면은 "멈추는 중…" → paused 이벤트에서만 멈춤 표시. Mock도 안전 지점에서 paused | Mock·위젯·E2E |
| 자동 resume 없음 | Mock·화면 모두 사용자 이어서만 | Mock·위젯 테스트(80ms 대기) |
| 취소는 기존 cancel | Esc·Cancel·dock 취소 모두 `cancelScannerSession` | 위젯(Esc)·Mock·E2E |
| `ScannerEventKind` paused/resumed | enum + 이벤트 검사(paused 사유 필수, resumed null) | fixture 이벤트 12 |
| control/pause reason enum | `ScannerControlState`·`ScannerPauseReason`(wireName) | DTO 테스트 |
| `ScannerSessionSnapshot` control_state/reason | 필드 + wire 필수·짝 검사, 생성자 기본값 | snapshot 테스트·E2E |
| ScannerService·ProtocolClient pause/resume | interface + client | client 테스트 |
| ProcessAppService·MockAppService 위임·같은 응답/이벤트/sequence/snapshot | Process 위임, Mock parity | Mock·E2E |
| 스캔 controller/dock exhaustive 분기 | `_applyEvent`(유일한 exhaustive switch)에 paused·resumed | 정적 확인(grep: 다른 exhaustive switch 없음) |
| paused 표시·이어서·Esc 취소(FD-142) | scan_page 버튼·사유·Esc, dock 아이콘·사유 | 위젯 테스트 |
| CF-HANDOFF: 거절된 resume은 paused·target_minimized, 이벤트 없음 | 응답으로만 사유 갱신 | 위젯(거절)·fixture |
| CF-HANDOFF: snapshot 제어 상태가 권위값 | `_recoverSnapshot`이 snapshot 값을 씀 | 정적 확인 |

### 계약 SHA 대조

착수 때와 같다. 메인 작업 트리 SHA256 = XB 20:55 표.

- `contracts/scanner-protocol-v1.schema.json`: `320c7c707c614d71c8d2847d4d2c8b8c1d0ca5785c40ac856cd3fff4948bcbd4`
- `contracts/fixtures/scanner_pause_fb10a_v1.json`: `e94a59399438793a0e24b7d4180b47b3cfaac9e2f63e6a6acafa0a5c93b67b12`

`contracts/scan-commit-history-context-v1.schema.json`은 바뀌지 않았다(XB 인계). "FB-10 형식 고정" 선언은 아직 아니다.

### golden 예측

- 기존 장면 변화 0.
  - 스캔 장면은 `scan-student-review` 하나다. 그 장면은 `ScanStudentReviewWorkspace`만 그리고, 이 위젯은 고치지 않았다(스캐너 세션 소유).
  - 지금 스캔 화면(`ScanPage`)과 dock을 그리는 golden 장면은 없다.
  - app_shell 1줄은 화면을 바꾸지 않는다.
- 새 장면은 만들지 않았다.

### 미검증 항목

- analyze(info 포함)·일반 테스트(예상 +47)·process E2E(예상 +1)·golden을 돌리지 않았다.
- 실제 게임 일시정지는 사용자 실기로 확인해야 한다(게임 창 최소화·입력 감지·이어서·Esc 중지).
- process E2E는 Python `.venv`(없으면 `py -3.11`)와 `backend` 폴더를 기존 scanner E2E와 같은 방식으로 찾는다. 임시 폴더에 쓴 스크립트를 `backend`에서 실행한다.
- Mock 단위 테스트 3개는 실제 타이머(10ms)를 쓴다. pause 호출이 첫 단계보다 늦으면 순서 기대가 깨질 수 있다. 같은 마이크로태스크 흐름이라 실제로는 안전하다고 보았다.

### WIP 보존 확인

- 고친 기존 파일 8개 중 7개에 다른 세션의 미커밋 변경이 있다. 지우거나 정리하지 않았다.
- 쓰기 직전 PC 파일이 착수 사본과 같은지 바이트로 다시 확인했다.
- merge 안전성(fe_commit `git merge-file`): HEAD blob을 꺼낼 수 있었던 5개는 slice hunk와 WIP hunk 사이에 바뀌지 않은 줄이 4줄 이상 있다.
  - `scan_page.dart`: 4·5줄
  - `planning_protocol_client.dart`: 5줄
  - `scanner_service.dart`: 12줄
  - `mock_app_service.dart`: 24줄
  - `process_app_service.dart`: 17줄
- `scan_companion_dock.dart`·`scanner_protocol_client_test.dart`의 HEAD blob은 4 GB pack 안에 있어 이 환경에서 꺼내지 못했다.
  - 바꾼 곳: dock은 생성자 끝·필드 끝·머리 Row 취소 버튼 앞·대상 제목 뒤, 테스트는 snapshot 예시 2줄이다.
  - `fe_commit -DryRun`이 충돌을 알리면 그 파일만 오케스트레이터가 맞춘다.
- 줄바꿈: 바꾼 줄은 각 파일의 주 줄바꿈을 따른다(CRLF 주 파일은 CRLF, LF 파일은 LF). 새 테스트 3개는 LF다.

### 발견 사항

1. 지금 스캔 화면에는 진행 중 사유 문구(입력 감지 등)만 보이고 머리글 진행 칩은 없다. FD-148(머리글 진행·일시정지 wn)은 FE8-f2 몫이다.
2. 학생 전체 스캔 중 dock이 앱을 덮을 때 Esc는 section이 scan이라 동작한다. 앱 창에 포커스가 없으면(게임 창을 누른 뒤) Esc는 앱에 닿지 않는다. dock의 일시정지·취소 버튼이 그 경우의 수단이다.
3. 실제 백엔드는 진행 중 입력이 감지되면 `paused(input_detected)`를 스스로 낸다. 화면은 이 이벤트로 멈춤을 표시한다. 응답 없이 오는 자동 멈춤이라 "멈추는 중…" 단계가 없다.
4. 이 slice는 공유 서비스 파일 4개와 scan_page를 스캐너 WIP 위에서 고쳤다. 워크플로 불변식("scan_page·dock은 동결 창에서만")에 대해서는 이번 워커 프롬프트가 범위를 명시했다. 추출한 로직 파일은 없다.

### 사본·commit.json

- 착수 사본: `debug/frontend_fb10adart/pre/<경로>`. 고친 기존 파일 8개를 착수 때 두었다.
- 끝 사본: `debug/frontend_fb10adart/post/<경로>`. 고친 기존 파일 8개와 새 테스트 3개다.
- `debug/frontend_fb10adart/commit.json`:
  - slice `fb10adart`, `status=false`, `post_dir`
  - modified 8개, added 3개
  - `whole = [almanac/workflows/frontend-redesign-status-lane-b.md]`. 바뀌는 기준 이미지는 없다.
  - message의 근거: XB source10(backend 로그 20:55, `source10-final.json`), CF 로그 18:15.

### 다음 행동과 사용자 실행 명령

- fb10a-dart 코드는 끝났다. Lane B는 여기서 멈춘다.
- PowerShell, `C:\Users\brigh\planner_of_plana\BA Planner\v7`에서 아래 명령을 한 줄씩 실행한다. 하나가 실패하면 거기서 멈추고 결과를 오케스트레이터에게 보낸다. 순서는 오케스트레이터가 정한다.
  1. Lane A(M2)·Lane B 두 워커가 모두 멈춘 뒤 실행한다. 같은 소스 gate이고, 결과(`debug/frontend_gate/` 요약)를 오케스트레이터에게 보낸 뒤 기다린다.
     - 예상: analyze 0, 일반 테스트 +47, process +1, golden 변화 0(M2 몫 제외).
     - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_gate.ps1`
  2. XB가 FB-10a exact10을 먼저 커밋한 뒤:
     - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice fb10adart -DryRun`
     - `powershell -ExecutionPolicy Bypass -File frontend\tool\fe_commit.ps1 -Slice fb10adart`

## FE6-c 착수 기록 (2026-10-11)

- 상태: 진행 중 → 코드 작성 완료(아래 종료 기록).
- 범위: 인벤토리 분석 모드(시안 `Inventory-Analysis.dc.html`). 워커 프롬프트(CF, 로컬 Claude Code).
  1. 사이드바 분석 모드: 최상단 "목록 | 분석" seg, "비교 기준"(계획 요구량 / 이론상 전체 요구량 비활성 FD-097), "이 화면에 보이는 분석" 버튼 4개, "따로 여는 화면"(티어별 충족률 비활성 FE6-e, 넘치는 재화 정리 숨김 FD-097).
  2. S1 학교별 BD·기술 노트 충족률(FD-031·FD-032·FD-099·FD-100·FD-101), "계획 n명" 플라이아웃.
  3. S2 오파츠 보유율 × 수요 산점도(CustomPainter, 키트 `StatChartFrame`), "확장"은 FE6-d 전까지 비활성.
  4. S4 종류 × 티어 충족률 히트맵 + 부족 상위 3행(FD-033).
  5. S5 최근 변화: 틀·seg·빈 상태만(데이터 FE6-f).
- 범위 밖: 확장 애니메이션(FE6-d), 티어별 충족률 화면(FE6-e), 최근 변화 데이터(FE6-f), `lib/services/**`, 키트, golden harness·기존 golden 테스트, `app_shell.dart`, `statistics/**`, Lane A 파일(`plan_flow_draft.dart`·`plan_section_layout.dart`·`widgets/plan_*`), 백엔드·계약, `scan_page.dart`.
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `9d959d15416b6251e8aaa1d682ea3550d48af524`.
- 막힘: 대장 막힘 요약의 FE6-c 행은 FD-031(확정 2026-10-06)뿐이다. 막는 열림 FD 없음. FD-032·FD-097·FD-098·FD-099·FD-100·FD-101은 워커 재량(권장안대로).
- 고칠 기존 파일(착수 사본 `debug/frontend_fe6c/pre/<v7 기준 경로>`):
  - `frontend/lib/ui/pages/inventory_page.dart`
  - `frontend/lib/ui/inventory/inventory_controller.dart`
  - `frontend/lib/ui/inventory/inventory_workspace.dart`
  - `frontend/lib/ui/studio/inventory_studio_layout.dart`
- 새 파일(예정): `frontend/lib/ui/inventory/inventory_analysis.dart`(집계 순수 함수), `frontend/lib/ui/inventory/inventory_analysis_sections.dart`(분석 섹션 위젯, workspace의 part), `frontend/lib/ui/inventory/inventory_analysis_charts.dart`(산점도·히트맵 painter), 테스트(`test/inventory_analysis_test.dart`, `test/inventory_analysis_page_test.dart`, 검수 fixture `test/inventory_fe6c_fixture.dart`), golden 1장 `test/goldens/fe6c_inventory_analysis_golden_test.dart`(`inventory-analysis`, 실행하지 않음).
- WIP: 고칠 기존 파일 4개 모두 `git status --short`가 비어 있다(미커밋 변경 없음). `inventory_page.dart`는 CRLF, 나머지는 LF다.

## FE6-c 종료 기록 (2026-10-12, 코드 작성 완료·CF gate 미실행)

시안 Inventory-Analysis(분석 모드 기본, 밀레니엄 플라이아웃 열림)의 분석 모드를 끝냈다. 확장 애니메이션(FE6-d)·티어별 충족률 화면(FE6-e)·최근 변화 데이터(FE6-f)는 범위 밖이다.

### 실행 명령·결과

모두 `frontend`에서 이 PC(Claude Code)로 실행했다. 로그는 실패 줄(`[E]`·`EXCEPTION`·`Some tests failed`·`error •`)만 찾았다.

| 명령 | 결과 |
|---|---|
| `flutter analyze`(1차) | 이슈 1(warning `unused_element_parameter`, `_AnalysisGlyphPainter.color`) → 고침 |
| `flutter analyze`(최종) | **No issues found**(info 포함 0) |
| `flutter test test/inventory_analysis_test.dart` | 16 통과 · 0 실패 |
| `flutter test test/inventory_analysis_page_test.dart` | 8 통과 · 0 실패 |
| `flutter test test/inventory_controller_test.dart` | 13 통과 · 0 실패 |
| `flutter test test/inventory_currency_readonly_test.dart` | 2 통과 · 0 실패 |
| `flutter test test/inventory_page_test.dart` | 9 통과 · 0 실패 |
| `flutter test test/inventory_shell_lazy_test.dart` | 1 통과 · 0 실패 |
| `flutter test test/inventory_view_model_test.dart` | 13 통과 · 0 실패 |
| `git diff --check -- frontend/lib/ui frontend/test <status>` | 0(경고는 autocrlf 안내뿐) |

- 걸리는 기존 테스트는 `InventoryPage`·`inventory_workspace`·`InventoryController`·`inventory_studio_layout`·`inventory_view_model`·`top-tab-inventory`·`inventory-page`를 grep해서 찾았다(위 5개 기존 파일 전부 실행). 기존 테스트 기대는 바꾸지 않았다.
- 빌드 잠금(`build/`·`.dart_tool/`) 충돌은 없었다.
- 실행하지 않음: golden(`test/goldens/**`), 전체 `fe_gate.ps1`, `-UpdateGoldens`, `fe_commit.ps1`, 맨 `flutter test`, process E2E, `codealmanac validate`.

### 고친 파일

- **`frontend/lib/ui/studio/inventory_studio_layout.dart`**: 분석 Studio 문서 `inventoryAnalysisStudioDocument`(A 사이드바는 목록과 같은 element + S1·S2·S4·S5), id 상수, `inventoryAnalysisSection`, 섹션 안 좌표 `InventoryAnalysisMetrics`를 더했다. 목록 문서·`InventoryMetrics`·`InventoryAllMetrics`는 그대로다.
- **`frontend/lib/ui/inventory/inventory_controller.dart`**: "목록 · 분석" 상태(`screenMode`), 분석 강조(`analysisFocus`), S2 티어 토글, S4 종류·표시, S5 기간과 집계 메모(`schoolRows`·`oopartAnalysis`·`heatmap`, 보드·사용 단계가 바뀔 때만 다시 센다). FE6-a·b 로직(로드 순서·재화 읽기 전용·편집·후보 승인)은 손대지 않았다.
- **`frontend/lib/ui/inventory/inventory_workspace.dart`**: 최상단 seg를 살렸다(두 칸 `inventory-mode-list`·`inventory-mode-analysis` 키 유지, 간격 6). 분석 모드면 사이드바 아래쪽이 분석 메뉴가 되고 B·C·D 대신 분석 네 섹션을 그린다. 표면 painter는 모드별 섹션을 칠한다. 분석 위젯은 같은 라이브러리의 `part`(`inventory_analysis_sections.dart`)라 `_SectionQuad`·`_Fit`·`_railButton` 등을 그대로 쓴다.
- **`frontend/lib/ui/pages/inventory_page.dart`**(CRLF 유지): 스캔 후보가 새로 오면 build 밖(microtask)에서 목록 보기로 돌린다(후보 승인 띠가 목록 C 섹션에 있으므로).
- 새 파일:
  - `frontend/lib/ui/inventory/inventory_analysis.dart`: 집계 순수 함수(충족률·학교 행·학생별 부족·오파츠 점·히트맵·부족 상위, 라벨 맵, 모드 enum).
  - `frontend/lib/ui/inventory/inventory_analysis_charts.dart`: 산점도 `InventoryOopartScatterPainter`(키트 `StatChartPainter`), 히트맵 `InventoryTierHeatmapPainter`(키트 `paintHatch`).
  - `frontend/lib/ui/inventory/inventory_analysis_sections.dart`: 분석 사이드바 메뉴와 S1·S2·S4·S5 위젯.
  - 테스트 `frontend/test/inventory_analysis_test.dart`(16), `frontend/test/inventory_analysis_page_test.dart`(8), 검수 fixture `frontend/test/inventory_fe6c_fixture.dart`(테스트 파일 아님), golden `frontend/test/goldens/fe6c_inventory_analysis_golden_test.dart`(1장, 실행 안 함).
- 고치지 않음: `lib/services/**`, 키트, golden harness·기존 golden 테스트, `app_shell.dart`, `statistics/**`, Lane A 파일, 백엔드·계약, `scan_page.dart`, FE6-a fixture(`inventory`·`inventory-all` 장면이 쓰므로 분석 fixture를 따로 만들었다).

### 섹션 배치(기준 viewport 2560×1392, Studio 문서)

시안 x가 grid에 맞지 않아 rect만으로는 ±1px를 못 맞춘다(FE6-a C 섹션과 같은 문제). 그래서 같은 path 생성 함수의 `faceStart`·`faceSpan`·`height`(모두 96 grid 정수)까지 골라 꼭짓점을 맞췄다(전수 탐색, scratch 스크립트).

| 섹션 | rect(grid) · spec | 꼭짓점(위 왼·위 오·아래 오·아래 왼) | 시안 대비 최대 |
|---|---|---|---|
| A 사이드바 | (0,2,26,94) 왼쪽 사다리꼴 | 목록과 같음 | 0 |
| S1 학교별 | (20,2,44,47) 위 평행사변형, face 15+69, 깊이 96 | (716.7,209.2)·(1560,209.2)·(1455.7,800.6)·(612.4,800.6) | −0.8 · +0.6px |
| S2 오파츠 | (52,2,44,51) 오른쪽 사다리꼴, face 0+85, 깊이 88 | (1584.6,209.2)·(2560,209.2)·(2560,777.4)·(1484.4,777.4) | +0.6px |
| S4 종류 × 티어 | (47,47,49,49) 오른쪽 사다리꼴, face 4+92, 깊이 87 | (1480.0,801.1)·(2560,801.1)·(2560,1392)·(1375.8,1392) | +0.4px |
| S5 최근 변화 | (14,45,44,51) 아래 평행사변형, face 11+69, 깊이 85 | (608.0,823.8)·(1451.3,823.8)·(1351.1,1392)·(507.8,1392) | −1.0px(왼쪽 두 꼭짓점 −1.03) |

섹션 안 요소(섹션 위·사선 왼쪽 변 기준, 시안 값): 제목 줄 위 20·높이 40·왼쪽 22(S4 24·S5 23.9), 규칙선 위 65·왼쪽 21.8 · 학교 행 위 78·52·피치 70·왼쪽 23.9 · 티어 토글 위 78·왼쪽 30 · 산점도 svg 1012×420 위 120(아래 왼쪽이 변에서 28.9) · 히트맵 .plain 위 78·322(그리드 바닥 왼쪽 87.8, 윗변 오른쪽 여백 36.4) · 부족 상위 캡션 404·행 434/46/50·왼쪽 24.1 · 사이드바 분석 메뉴 78·102·142·172·198(44/52)·422·448(58).

### 처리한 FD

- **FD-031(확정)·FD-032(워커 재량, 권장안)**: 학교 BD · 노트, 히트맵 칸 모두 범위 안 계획 재화의 min(보유, 필요)/필요 단순 평균. 보유 모름은 평균에서 빼고 "n종 모름"(S1 부족 글자 뒤 `· n종 모름`, S2 범례 `보유 모름 n종 제외`, 히트맵 빗금 + `—`).
- **FD-033(확정)**: 서로 다른 재화 수량을 더하지 않는다. 학생별 부족은 같은 재화 안의 단계만 더한다. **히트맵 "보유량 · 부족량" 모드에서 한 칸이 여러 재화를 묶으면** 수량 대신 `n종`을 쓰고 색은 그 칸 충족률 평균이다(지금 카탈로그는 family+티어 · 학교+티어가 재화 하나라 실제로는 생기지 않는다. 단위 테스트로 고정).
- **FD-097(워커 재량)**: "이론상 전체 요구량" seg 칸은 비활성(의미 라벨 "준비 중"), "과잉 재화 / 넘치는 재화 정리" 버튼은 그리지 않는다.
- **FD-098(워커 재량)**: 노트·BD 티어 라벨 1 초급 · 2 중급 · 3 상급 · 4 최상급(히트맵 열 머리·부족 글자·플라이아웃), 오파츠·설계도는 `T<n>`.
- **FD-099(워커 재량)**: S1 학교·S2 오파츠·S4 행은 활성 계획이 쓰는(필요 > 0) 재화가 있는 것만. 히트맵 열은 카탈로그의 그 종류 최고 티어까지(설계도 10, 나머지 4), 계획에 안 쓰는 칸은 옅은 바탕만.
- **FD-100(워커 재량)**: 환산 없이 티어별 그대로, "계획 필요 환산량 기준" 칩 숨김.
- **FD-101(워커 재량)**: 학생별 필요량은 활성 문서 계산 `stage_results[].resources`(FE6-a의 `inventoryStageUses` 경로 재사용). 문서 계산이 없으면 부족 계산 `affected_student_ids`로 학생만 세고 몫은 `—`.

이번에 정한 규칙(시안·대장에 근거 없음, 워커 결정):
1. 학교 행 순서: BD · 노트 충족률 중 낮은 값이 낮은 순(막히는 학교가 위). 모르면 뒤, 같으면 계획 학생 많은 순 → 카탈로그 순서. 시안 순서(밀레니엄 91/76이 맨 위)는 견본 값이라 어떤 규칙과도 맞지 않는다.
2. S1 "부족 티어": 모자라는 재화 중 가장 높은 티어 → 충족률 낮은 것 → BD 먼저. 둘 이상이면 `외 n`.
3. 플라이아웃 학생 줄: 종류마다 그 학생이 모자라는 가장 높은 티어 하나(`상급 BD 12`), 없으면 `—`. 순서는 모자람 있음 → 가장 높은 티어 → 그 부족량 → 이름. 5명 + `… 외 n명` + "계획에서 보기 →"(계획 탭).
4. 오파츠 산점도: y = 사용 학생 수(0명 362 → 최대 18, 가운데 190 = 최대의 절반), x = 보유율(그 높이의 80° 사선을 따라 민다). "핵심 병목" = 보유율 50% 미만 + 학생 수가 최대의 절반 초과(왼쪽 위 4분면) → 반지름 9 + 분홍 테두리, 이름 분홍 굵게. 시안의 티어별 9px y 어긋남은 견본 표현이라 넣지 않았다. 점 위에 마우스를 올리면(누르기도 같다) `<이름> T<n> · 보유율 x% · 학생 n명` 말풍선.
5. 부족 상위: 그 종류의 부족량 큰 순 → 사용 학생 많은 순 → 카탈로그 순서, 3행. 행은 정보 행(누르는 동작 없음, 시안 `.row`).
6. 히트맵 행이 많아 322 안에 안 들어가면 칸 높이를 26에서 최소 16까지 줄인다. 그보다 많으면 섹션 상자에서 잘린다.

### §3.6 모호점별 결론

1. **seg 공존**(dc_outline 확인): 분석 시안의 "목록 | 분석"은 목록 시안의 같은 자리(사이드바 위 +22)다. 분석 시안에는 "아이템 | 장비"가 없고 그 다음 자리(+78)가 "비교 기준" 캡션이다. 결론: 최상단 "목록 | 분석"은 두 모드 공통, "아이템 | 장비"는 목록 모드에서만 그 아래(FD-095 본문과 같다).
2. **과잉 재화 화면**: 시안 artboard가 없다 → 버튼 숨김(FD-097).
3. **"이 화면에 보이는 분석" 버튼 4개**: 최소 동작 = 그 섹션 외곽선을 분홍 2px로 강조하고 버튼을 선택(분홍) 상태로 둔다. 다시 누르면 푼다. "장비 설계도"는 S4 종류를 설계도로 돌린다. 네 섹션이 기준 viewport에 다 보이므로 스크롤·이동은 없다. 시안 버튼 끝 아이콘은 체크 표시(`M5 12.5l4.5 4.5L19 7.5`)라 "이 화면에 있음" 뜻으로 그렸다.
4. **학교 6 vs 9**: FD-099 — 분석은 활성 계획이 쓰는 학교만(티어별 화면은 FE6-e에서 카탈로그 전부).
5. **오파츠 8 vs 13**: FD-099 — 분석은 활성 계획이 쓰는 오파츠만.

### golden 변화 예상

- **`inventory`·`inventory-all`(바뀜, 사이드바 한 칸)**: 최상단 "분석" seg 칸이 FE6-a·b의 비활성(불투명도 .45)에서 활성 · 선택 안 됨(불투명도 1)으로 바뀐다. 위치·크기·"목록" 칸·나머지 화면은 같다(두 칸 배치·간격 6·키 그대로). 이유: 분석 모드가 생겨 그 칸을 눌러야 한다. 시안 Inventory·Inventory-All의 "분석" 칸도 흐리지 않은 `.seg`다. → 두 기준 이미지를 commit.json `whole`에 파일 단위로 넣었다(CF가 `failures/`를 보고 승인).
- **다른 장면**: 변화 0. 인벤토리 탭이 보이지 않고, 오프스테이지 첫 로드 시점(FE6-b `active`)도 그대로다.
- **새 장면 `inventory-analysis`**(`fe6c_inventory_analysis_golden_test.dart`, 기준 이미지 없음 → RED, CF가 만든다). 기대 모습:
  - 왼쪽 사이드바: "목록 | 분석"(분석 핑크), "비교 기준" + "계획 요구량"(선택)·"이론상 전체 요구량"(흐림), 설명 한 줄, "이 화면에 보이는 분석" 버튼 4개(끝 체크), "따로 여는 화면" 티어별 충족률(흐림, 오른쪽 화살표). 과잉 재화 버튼 없음.
  - S1(위 가운데 평행사변형): 학교 6행이 사선을 따라 내려간다. 순서 백귀야행(30%/22%) · 산해경(40/35) · 게헨나(81/41) · 트리니티(68/54) · 밀레니엄(91/76) · 아비도스(95/88). 엠블럼은 학교 로고 그림. 밀레니엄 "계획 5명" 플라이아웃이 아래로 열려 유우카(상급 BD 9 · 중급 노트 20) · 노아(— · 중급 노트 4) · 리오(무장) · 토키(무장) · 히마리(무장)(— · —)와 "계획에서 보기 →". 초상은 리오·토키·히마리(무장)는 `*_battle` 그림이 있다.
  - S2(오른쪽 위): 제목 + "왼쪽 위 = 핵심 병목" 칩 + "확장"(흐림), T1~T4 토글(모두 켜짐) + 범례, 평행사변형 플롯에 8종 × 4티어 점과 선, 네브라 디스크 T3·T4 등 왼쪽 위 점에 분홍 고리, 이름 라벨.
  - S4(오른쪽 아래): "종류 × 티어 충족률" + seg(설계도 선택) + 칩(충족률 핑크), 9부위 × T1~T10 기울인 히트맵(T1~T4 빈 칸, T5~T10 파랑 농담 + %, 목걸이 T9 빗금 `—`), 범례, 부족 상위 3행(시계 T8 −36 · 7명 / 가방 T10 −22 · 2명 / 헤어핀 T10 −12 · 1명 + 초상 줄).
  - S5(아래 가운데): "최근 변화" + 1주·2주·4주 seg, 가운데 "변화 기록이 아직 없습니다." + 보조 글자.

### 검수표

artboard `Inventory-Analysis.dc.html` → 앱:
- 여는 방법: 인벤토리 탭 → 사이드바 맨 위 "분석". Mock 기본 실행은 계획이 없어 S1에 "저장된 계획이 없습니다…" 안내만 보인다. 시안 숫자 장면은 fixture로만 열린다(golden `inventory-analysis` 장면, `test/inventory_analysis_page_test.dart`).
- 확인 포인트:
  1. 다섯 섹션(A·S1·S2·S4·S5)이 시안 자리에 들어오는가(S1·S5 평행사변형, S2·S4 오른쪽 사다리꼴, 사이 간격).
  2. 사이드바: 목록 ↔ 분석 전환, 분석에서 아이템·장비·종류·주요 재화가 사라지고 비교 기준·버튼 4개·티어별 충족률(흐림)이 보이는가. 과잉 재화 버튼 없음.
  3. 버튼 4개: 누르면 해당 섹션에 분홍 외곽선, 다시 누르면 사라짐. "장비 설계도"는 S4를 설계도로.
  4. S1: 학교 행 · 엠블럼 · BD 파랑/노트 분홍 막대 + % · 부족 티어 글자 · "계획 n명" 칩 hover/누름 → 학생별 부족 필요량 플라이아웃, "계획에서 보기 →"로 계획 탭.
  5. S2: 점 색 = 티어, 같은 오파츠 선, 4분면 점선, 병목 고리, 티어 토글로 점이 빠지고 돌아오는가, 점 hover 말풍선, "확장" 흐림.
  6. S4: 종류 seg 4개 전환, 충족률/보유량/부족량 칩, 칸이 80°로 기울고 글자는 똑바른가, 빗금 칸, 범례, 부족 상위 3행.
  7. S5: 1주/2주/4주 seg와 빈 상태 글자.
  8. 작은 창(1280×720)에서 예외 없이 잘리는가.

### 미검증 항목

- golden(새 장면 `inventory-analysis`, 바뀌는 `inventory`·`inventory-all`): 미실행(CF가 `fe_gate.ps1`·`failures/` 검토·`-UpdateGoldens`).
- 전체 `fe_gate.ps1`(다른 테스트·process E2E·`codealmanac validate`): 미실행.
- 섹션 path bounds는 계산으로만 맞췄다(위 표). 섹션 안 요소 ±2px는 시안 좌표를 상대값으로 옮긴 계산이고 화면에서 재지 않았다. 특히 S1 막대 폭(BD 126 · 노트 129)은 시안 flex 축소를 손으로 계산한 값, 히트맵 세로 위치는 시안 가운데 정렬(322 안 287 + 범례 22)을 계산한 값이다.
- 엠블럼 그림(`School_Icon_*.png`)이 실제로 시안 엠블럼과 같은 모양인지, 흰색으로 칠해야 하는지 보지 않았다(지금은 원본 색 그대로 불투명도 .92).
- 실제 백엔드 카탈로그(school `Millennium` 등, family `oopart:<Key>`·`equipment:<Key>`)와는 FB-3 계약·`backend/core/inventory_catalog.py` 읽기로만 맞췄다.

### WIP 보존 확인

- 고친 기존 파일 4개는 착수 때 WIP가 없었다(`git status --short` 빈 줄). 그래서 post 사본·`post_dir`는 두지 않았다.
- 작업 트리의 다른 미커밋 변경(서비스 3개 `mock_app_service.dart`·`planning_protocol_client.dart`·`process_app_service.dart`, Lane A `plan_flow_draft.dart`·`plan_flow_handoff_test.dart`, 스캐너 파일들, `fe_commit.ps1`, 추적 안 된 asset 폴더)은 읽지도 고치지도 않았다.
- git 쓰기는 하지 않았다.

### 발견 사항

1. 시안 S1 숫자는 견본 값이라 서로 맞지 않는다(아비도스 BD 95%·노트 88%인데 "부족 —"). 구현은 규칙대로 "부족 상급 BD 외 1" 류를 보인다.
2. 시안 산점도는 같은 오파츠의 티어 점을 y 9px씩 어긋나게 그렸고, 병목 고리는 T4 두 점에만 있다. 구현은 실제 학생 수(같으면 같은 높이)와 위 4분면 규칙을 쓴다. 점이 겹칠 수 있다.
3. 학교 표시 이름 · 엠블럼 맵을 인벤토리 쪽에 따로 두었다(`inventorySchoolLabel`·`inventorySchoolEmblemAsset`). 학생 화면 `studentSchoolLogoAsset`(student_section_layout.dart)은 학생 catalog 값(`red winter`·`wild hunt` 공백)을 받고, 카탈로그 school 값은 `RedWinter`·`Wildhunt`다. 공용 모델로 합칠지 CF 판단이 필요하다. `InventoryCatalogEntry` 주석("표시 라벨·enum은 프론트가 정하지 않는다")과는 값 검증이 아니라 표시라 충돌하지 않는다고 보았다.
4. 키트 `TonalButton.icon`은 `IconData`만 받는다. 시안 "확장" svg 대신 Material `Icons.open_in_full`을 썼다. 시안 아이콘을 쓰려면 키트 요청(위젯 아이콘 슬롯)이다.
5. FE6-a·b에서 "분석" seg를 비활성으로 그린 것은 시안과 다른 임시 상태였다. 이번에 활성으로 바꿔 `inventory`·`inventory-all` 기준 이미지가 한 칸 바뀐다(위 golden 예상).
6. S5 "주간 순증감 상위" 캡션 · 증감 막대 · "이 추세라면" 예측 행은 FE6-f 몫이라 그리지 않았다. 예측 규칙은 대장에 없다(FE6-f 착수 전 FD 필요).
7. 학생 초상 id: 시안의 리오(무장) 등은 asset이 `rio_battle`·`toki_battle`·`himari_battle`이다(FE6-a fixture의 `rio_armed`는 그림이 없다). 검수 fixture만의 문제다.

### 사본·commit.json

- 착수 사본: `debug/frontend_fe6c/pre/<경로>`(고친 기존 파일 4개). WIP가 없어 post 사본은 없다.
- `debug/frontend_fe6c/commit.json`: slice `fe6c`, `status=false`, modified 4, added 7(golden 기준 이미지 `inventory-analysis.png`는 CF가 넣는다), `whole = [이 문서, frontend/test/goldens/baseline/inventory.png, frontend/test/goldens/baseline/inventory-all.png]`(바뀌는 기존 기준 이미지 파일 단위). message 근거: Inventory-Analysis artboard, E §3, FD-031·032·033·097·098·099·100·101.
- 인계: `debug/frontend_fe6c/output.md`.

### 다음 행동

- FE6-c 코드는 끝났다. Lane B는 여기서 멈춘다.
- CF: 레인 워커가 모두 멈춘 뒤 gate 1회. 예상: analyze 0, 일반 테스트 +24(집계 16 + 위젯 8), golden은 새 장면 `inventory-analysis` 기준 없음 RED + `inventory`·`inventory-all` 사이드바 "분석" 칸만 RED, 다른 장면 변화 0. 승인 뒤 `-UpdateGoldens`·재비교·`fe_commit.ps1 -Slice fe6c`.
- 발견 사항 3·4(학교 맵 공용화, 키트 아이콘 슬롯)는 CF 결정을 기다린다.

## FE6-e 착수 기록 (2026-10-12)

- 상태: 진행 중 → 코드 작성 완료(아래 종료 기록).
- 범위: 인벤토리 "티어별 충족률" 화면(시안 `Inventory-Tiers.dc.html`). 워커 프롬프트 `debug/frontend_redesign_handoff/fe6e-worker-prompt-20261012.md`(CF 01:00 배정).
  1. 분석 사이드바 "따로 여는 화면 → 티어별 충족률"을 켜고, 누르면 같은 페이지 안에서 분석 네 섹션 대신 T1·T2·T4·T5·T6을 그린다(다시 누름 · 분석 버튼 4개 · "목록"이면 돌아감, 기존 섹션 모션 규칙).
  2. T1 기술 노트 · T2 전술 교육 BD 학교 × 티어(카탈로그 전부 FD-099, "가장 부족" 열, 칩 충족률/보유량/부족량), T2는 부유 패널(FD-019).
  3. T4 오파츠 종류 × 티어, T5 티어 품목 부족 상위 6, T6 요약 KPI + 티어 분포 누적 막대.
  4. 학교 이름 · 엠블럼 공용 맵 `lib/ui/models/school_labels.dart`(FE6-c 발견 3, CF 결정), 인벤토리만 옮김.
  5. FE6-c 발견 7(검수 fixture 초상 id).
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `4196525575b8a249fd4dc7811305617c2ce62d82`.
- 막힘: 대장 막힘 요약의 FE6-e 행은 FD-031(확정 2026-10-06)뿐. 막는 열림 FD 없음. FD-019·FD-033은 확정, FD-032·FD-098·FD-099·FD-101은 워커 재량(권장안대로).
- 착수 중 사용자 결정(2026-10-12, 이 세션의 질문): 노트·BD 티어 2 라벨은 앱 전체 "일반"(FE6-c "중급" 대체). `inventory-analysis` 기준 이미지의 플라이아웃 두 줄이 함께 바뀐다.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe6e/pre/<v7 기준 경로>`, 사본과 작업 트리 cmp 일치 확인):
  - `frontend/lib/ui/inventory/inventory_analysis.dart`
  - `frontend/lib/ui/inventory/inventory_analysis_charts.dart`
  - `frontend/lib/ui/inventory/inventory_analysis_sections.dart`
  - `frontend/lib/ui/inventory/inventory_controller.dart`
  - `frontend/lib/ui/inventory/inventory_workspace.dart`
  - `frontend/lib/ui/studio/inventory_studio_layout.dart`
  - `frontend/test/inventory_analysis_page_test.dart`
  - `frontend/test/inventory_analysis_test.dart`
  - `frontend/test/inventory_fe6c_fixture.dart`
- 새 파일(예정): `frontend/lib/ui/models/school_labels.dart`, `frontend/lib/ui/inventory/inventory_tiers.dart`(집계 순수 함수), `frontend/lib/ui/inventory/inventory_tiers_sections.dart`(workspace의 part), 테스트 `frontend/test/school_labels_test.dart`·`frontend/test/inventory_tiers_test.dart`·`frontend/test/inventory_tiers_page_test.dart`, 검수 fixture `frontend/test/inventory_fe6e_fixture.dart`, golden 1장 `frontend/test/goldens/fe6e_inventory_tiers_golden_test.dart`(`inventory-tiers`, 실행하지 않음).
- WIP: 고칠 기존 파일 9개 모두 `git status --short <경로>`가 비어 있다(미커밋 변경 없음). 모두 LF(`git ls-files --eol`: i/lf w/lf).

## FE6-e 종료 기록 (2026-10-12, 코드 작성 완료·CF gate 미실행)

시안 Inventory-Tiers(분석 사이드바 "티어별 충족률" 선택, 칩 모두 충족률)의 티어별 충족률 화면을 끝냈다. 화면 헤더 부제("보유 재화와 장비 · 티어별 충족률")는 `app_section.dart`·`app_shell.dart` 몫이라 범위 밖이다(발견 사항 5).

### 실행 명령·결과

모두 `frontend`에서 이 PC(Claude Code)로 실행했다. 로그는 실패 줄(`[E]`·`EXCEPTION`·`Some tests failed`·`error •`)만 찾았다.

| 명령 | 결과 |
|---|---|
| `flutter analyze`(1차) | 이슈 6(`listEquals` 미정의 · `SectionCanvasElement` import 경로) → 고침 |
| `flutter analyze`(최종, test 포함) | **No issues found**(info 포함 0) |
| `flutter test test/inventory_tiers_page_test.dart`(1차) | 1 통과 · 6 실패: 단계 위젯 `late` 필드가 처음 읽을 때(didUpdateWidget) 새 값으로 초기화돼 티어 화면이 열리지 않음 → `initState`에서 정하도록 고침 |
| 같은 파일(2차) | 6 통과 · 1 실패: 작은 창에서 T6 분포 줄 넘침 38px → 분포 상자 `_Fit` 최소 폭 560 → 640 |
| `flutter test test/inventory_tiers_page_test.dart`(최종) | 7 통과 · 0 실패 |
| `flutter test test/inventory_tiers_test.dart` | 9 통과 · 0 실패 |
| `flutter test test/school_labels_test.dart` | 3 통과 · 0 실패 |
| `flutter test test/inventory_analysis_test.dart` | 16 통과 · 0 실패 |
| `flutter test test/inventory_analysis_page_test.dart` | 8 통과 · 0 실패 |
| `flutter test test/inventory_controller_test.dart` | 13 통과 · 0 실패 |
| `flutter test test/inventory_currency_readonly_test.dart` | 2 통과 · 0 실패 |
| `flutter test test/inventory_page_test.dart` | 9 통과 · 0 실패 |
| `flutter test test/inventory_shell_lazy_test.dart` | 1 통과 · 0 실패 |
| `flutter test test/inventory_view_model_test.dart` | 13 통과 · 0 실패 |
| `flutter test test/student_studio_layout_test.dart`(학생 쪽 `studentSchoolLogoAsset` 회귀 확인, 파일은 고치지 않음) | 45 통과 · 0 실패 |
| `git diff --check -- frontend/lib/ui frontend/test <status>` | 0(경고는 autocrlf 안내뿐), 새 파일 8개도 LF · 끝 개행 하나 |

- 걸리는 기존 테스트는 `top-tab-inventory`·`InventoryWorkspace`·`inventory_analysis_charts`·`InventoryTierHeatmapPainter`·`school_labels`·`inventoryNoteTierLabel`·`InventoryPage`·`InventoryController`·`inventory_studio_layout`·`중급`을 grep해서 찾았다(위 inventory_* 7개 전부 실행).
- 고친 기존 테스트 기대(사유 = 바뀐 동작): `inventory_analysis_page_test.dart` "티어별 충족률은 비활성" → 켜짐 · ghost, 플라이아웃 `중급 노트 20`·`중급 노트 4` → `일반 …`(사용자 결정), `inventory_analysis_test.dart` `tierLabel(2)` `중급` → `일반`(+ `inventoryNoteTierLabel(2)` 검사 추가). 지운 테스트 없음.
- 일회성 렌더 확인: 실제 글꼴(harness `loadGoldenFonts`)로 티어 화면을 그려 scratchpad PNG로 한 번 보았다(임시 테스트 파일은 실행 뒤 지웠다, golden 비교 아님). 다섯 섹션 배치 · 히트맵 · 가장 부족 열 · T5 · T6가 시안 자리에 들어오고 넘침이 없었다.
- 빌드 잠금(`build/`·`.dart_tool/`) 충돌은 없었다. `flutter analyze`가 pub get을 돌렸지만 `pubspec.lock`은 바뀌지 않았다.
- 실행하지 않음: golden(`test/goldens/**`, 새 `fe6e_inventory_tiers_golden_test.dart` 포함), 전체 `fe_gate.ps1`, `-UpdateGoldens`, `fe_commit.ps1`, 맨 `flutter test`, process E2E, `codealmanac validate`.

### 고친 파일

- **`frontend/lib/ui/studio/inventory_studio_layout.dart`**: 티어 Studio 문서 `inventoryTiersStudioDocument`(사이드바는 분석과 같은 element + T1 · T2 · T4 · T5 · T6), id 상수 5개, `inventoryTiersSection`, 섹션 안 좌표 `InventoryTiersMetrics`. 기존 문서 · metrics는 그대로다.
- **`frontend/lib/ui/inventory/inventory_controller.dart`**: `tiersOpen`(분석 모드 안, 목록으로 가면 닫힘), `toggleTiers`, 분석 버튼이 티어 화면에서는 "닫고 그 섹션 강조", 표마다 표시 칩 `tierValue`/`setTierValue`, 집계 메모 `tiersAnalysis`(보드 · 사용 단계가 바뀔 때만 다시 센다). FE6-a·b·c 로직(로드 · 재화 읽기 전용 · 편집 · 후보)은 그대로다.
- **`frontend/lib/ui/inventory/inventory_workspace.dart`**: 분석 모드 본문을 `_InventoryAnalysisStage`(StatefulWidget)로 옮겼다. 멈춰 있을 때는 FE6-c와 같은 그림 순서(한 painter가 표면 전부 → 섹션 내용)이고, 분석 ↔ 티어를 바꿀 때만 섹션마다 표면 + 내용을 함께 옮긴다(앞 360ms 나가는 섹션 outro, 뒤 360ms 들어오는 섹션 intro, 사이드바 표면은 고정, 움직이는 동안 입력 무시). 표면 painter는 element 목록을 받게 일반화(`_InventoryScreen`), `_SectionQuad.of(..., tiers:)`. 목록 ↔ 분석은 FE6-c 그대로 바로 바뀐다.
- **`frontend/lib/ui/inventory/inventory_analysis_sections.dart`**: 티어 버튼 켜기(선택 시 분홍, 의미 라벨 열기/닫기), 티어 화면에서 분석 버튼 4개는 ghost, `content(id)`(섹션 하나 내용), `_title`에 `innerRight`, `_SchoolEmblem` 크기 인자, `_TopShortageRow` 제목 덮어쓰기, `inventorySchoolEmblemAsset`은 공용 맵 위임.
- **`frontend/lib/ui/inventory/inventory_analysis_charts.dart`**: `InventoryTierHeatmapPainter`를 일반화(`labelWidth`·`trailingWidth`·`trailingHeader`·`rowLabels`, 기본값은 FE6-c S4와 같아 S4 그림 변화 없음), `InventoryHeatmapGeometry.columnWidth`·`cellRect`·`uprightRect`(위젯 겹침 자리를 painter와 같은 식으로 센다).
- **`frontend/lib/ui/inventory/inventory_analysis.dart`**: 티어 2 라벨 `일반`, `inventorySchoolLabel`은 공용 맵 위임.
- **테스트 · fixture**: `inventory_analysis_page_test.dart`·`inventory_analysis_test.dart`(위 기대 변경), `inventory_fe6c_fixture.dart`(재화 표시 이름의 티어 2를 `일반`으로 — 화면에 보이지 않는 이름이라 기준 이미지 영향 없음).
- 새 파일:
  - `frontend/lib/ui/models/school_labels.dart`: `schoolKey`(소문자 · 공백 · `_` · `-` 제거), `schoolLabel`, `schoolEmblemName`, `schoolEmblemAsset`(학생 맵에 있던 `etc` → `ETC`/기타 포함).
  - `frontend/lib/ui/inventory/inventory_tiers.dart`: 집계 순수 함수(`inventoryTierTable`·`inventoryTiersAnalysis`, 행 · 가장 부족 · 부족 상위 · 요약 · 분포).
  - `frontend/lib/ui/inventory/inventory_tiers_sections.dart`: 티어 섹션 위젯(workspace의 part).
  - 테스트 `school_labels_test.dart`(3), `inventory_tiers_test.dart`(9), `inventory_tiers_page_test.dart`(7), 검수 fixture `inventory_fe6e_fixture.dart`, golden `goldens/fe6e_inventory_tiers_golden_test.dart`(1장, 실행 안 함).
- 고치지 않음: Lane A 파일(`plan_flow_*`·`plan_section_layout.dart`·`widgets/plan_*`), `student_section_layout.dart`, `lib/services/**`, 키트, golden harness · 기존 golden 테스트(fe6a · fe6b · fe6c 포함), `app_shell.dart`·`app_section.dart`, `statistics/**`, `inventory_page.dart`(바꿀 필요 없음: 새 후보가 오면 `setScreenMode(list)`가 티어 화면도 닫는다), 백엔드 · 계약, `scan_page.dart`, `inventory_fe6a_fixture.dart`.

### 섹션 배치(기준 viewport 2560×1392, Studio 문서)

FE6-c처럼 시안 path의 직선 교점에 맞춰 rect · faceStart · faceSpan · height(96 grid 정수)를 전수 탐색으로 골랐다.

| 섹션 | rect(grid) · spec | 꼭짓점(위 왼 · 위 오 · 아래 오 · 아래 왼) | 시안 대비 최대 |
|---|---|---|---|
| A 사이드바 | 분석과 같은 element | — | 0 |
| T1 기술 노트 | (3,2,74,35) 위 평행사변형, face 31+41, 깊이 95 | (717.2,209.2)·(1560.0,209.2)·(1483.2,645.0)·(640.4,645.0) | −0.2px |
| T2 BD(부유) | (15,35,41,38) 아래 평행사변형, face 14+74, 깊이 87 | (635.9,669.2)·(1478.6,669.2)·(1402.2,1102.6)·(559.4,1102.6) | 아랫변 **−2.6px**, 나머지 ±0.2px |
| T4 오파츠 | (48,2,48,49) 오른쪽 사다리꼴, face 0+92, 깊이 81 | (1584.2,209.2)·(2560,209.2)·(2560,800.1)·(1480.0,800.1) | +0.3px |
| T5 부족 상위 | (44,39,52,57) 오른쪽 사다리꼴, face 20+76, 깊이 82 | (1475.7,824.2)·(2560,824.2)·(2560,1392)·(1375.6,1392) | +0.2px |
| T6 요약 | (16,62,37,34) 아래 평행사변형, face 8+82, 깊이 59 | (555.3,1129.1)·(1398.0,1129.1)·(1351.7,1392)·(508.9,1392) | +0.2px |

- T2는 위(669.2) · 아랫변(1105.2) y가 모두 grid 줄 사이라 위 · 아래 면 평행사변형으로는 한쪽이 grid 줄에 묶인다. 위를 맞추면 아래 −2.6px, 아래를 맞추면 위가 −5.5px 이상 어긋난다 → 위를 맞췄다(±1px 불변식 예외, 발견 사항 1). 단위 테스트가 이 허용치(아래 두 꼭짓점 y 2.7)로 고정한다.
- 섹션 안 요소(섹션 위 · 사선 왼쪽 변 기준, 시안 값): 제목 줄 위 20 · 높이 40 · 왼쪽 22(T4 · T5 24) · 안쪽 17.1/17.1(T4 · T5 19.1/14), 규칙선 위 65 · T1/T2 히트맵 `.plain` 위 78 · 330(그리드 바닥 왼쪽 88.5, 윗변 오른쪽 여백 92.7, 열 96 · 1fr×4 · 128, 간격 3) · T4 히트맵 위 78 · 450(109.3, 36.0, 열 150 · 1fr×4 · 128) · 행 머리 그림 28×24(엠블럼) · 30×24(오파츠) + 간격 7 · T5 캡션 위 82 · 행 위 112 · 46 · 피치 50 · 왼쪽 24.1 · T6 KPI 상자 위 78 · 80 · 안쪽 24.1 · 간격 40 · 최소 120, 분포 상자 위 166 · 56 · 안쪽 19.9.
- 히트맵 세로 위치는 FE6-c와 같이 상자 안 가운데(그리드 + 범례 22)로 계산했다. 행이 많으면 칸 높이를 26 → 16까지 줄이고 행 머리 · 가장 부족 그림도 같은 비율로 줄인다. 실제 백엔드 카탈로그(학교 11 · 오파츠 20)는 T1 · T2 22.3px, T4 17.5px 칸이 된다(시안 fixture 9 · 13행은 26 그대로).

### 처리한 FD

- **FD-019(확정)**: T2는 어느 경계에도 닿지 않는 부유 패널 그대로, 모션은 아래 기준 intro 80° · outro 260°.
- **FD-031(확정)·FD-032(워커 재량, 권장안)**: 칸 = 그 칸 계획 재화의 min(보유, 필요)/필요 평균(카탈로그는 칸마다 재화 하나), T6 종류별 충족률 = 그 표 계획 재화 전체의 단순 평균. 보유 모름은 평균에서 빼고 칸 빗금 + `—`, KPI 값 옆 `n종 모름`.
- **FD-033(확정)**: 보유량 · 부족량 칩에서 한 칸이 여러 재화면 `n종`(FE6-c 칸 규칙 재사용, 단위 테스트). 티어 분포는 품목 수다.
- **FD-098(워커 재량 → 사용자 결정)**: 노트 · BD 티어 1 초급 · 2 **일반** · 3 상급 · 4 최상급(앱 전체, FE6-c `중급` 대체), 오파츠 `T<n>`. 근거: 시안 Inventory-Tiers 열 머리 · 분포 범례가 "일반", 게임 명칭, 카탈로그 활동 보고서 이름(`초급/일반/상급/최상급 활동 보고서`). FD-098 권장안은 "초급~최상급"만 적고 2를 정하지 않았고 FE6-c `중급`은 시안 근거가 없는 추정이었다. 이 세션 질문에 사용자가 "앱 전체 일반"을 골랐다.
- **FD-099(워커 재량)**: Tiers = 카탈로그 전부(계획에 안 쓰는 학교 · 오파츠도 행, 칸은 옅은 바탕만, 가장 부족은 빈 글자).
- **FD-101(워커 재량)**: T5 학생 = 활성 문서 계산 `stage_results[].resources`(FE6-a·c 경로), 없으면 부족 계산 `affected_student_ids`.

이번에 정한 규칙(시안 · 대장에 근거 없음, 워커 결정):
1. "가장 부족" 칸: 보유를 알고 모자라는 칸 중 충족률 가장 낮은 것 → 높은 티어 → 부족량 큰 것 → 카탈로그 순서. 시안 31행(T1 9 · T2 9 · T4 13) 모두 "충족률 가장 낮은 칸"과 맞는다(예 네브라 T3 26% < T4 28% → `T3 −37`). 모자라는 칸이 없으면 계획 행은 `—`, 계획 밖 행은 빈 글자.
2. T5 범위: 세 표(노트 · BD · 오파츠)의 계획 재화만(설계도 · 비의서 제외), 정렬은 FE6-c 부족 상위(부족량 → 학생 수 → 카탈로그 순서), 6행, 글자 `<종류> · <행 이름> <티어>`.
3. T6 색: 세 충족률 중 가장 낮은 값과 최상급 부족 품목(1종 이상)이 분홍(시안 61% · 14종 분홍, 68 · 77 흰색과 맞다).
4. 티어 분포 칸 색은 오파츠 티어 색(T1 #b8c4cf · T2 #71c7f4 · T3 #ffc66d · T4 #c89cf5, 시안 범례와 같다), 0인 티어는 막대 칸이 없다, 부족 품목이 없으면 빈 바탕.
5. 분석 버튼 4개: 티어 화면에서는 고르지 않은 모양이고, 누르면 분석으로 돌아가며 그 섹션을 강조한다(토글이 아니라 켬). "목록"을 누르면 티어 화면도 닫혀, 다시 "분석"이면 분석 첫 화면이다.
6. 계획이 없거나 계산을 못 하면 다섯 섹션 모두 분석과 같은 안내(`저장된 계획이 없습니다…`)를 보인다(카탈로그 행만 있는 빈 표 대신).

### §5.6 모호점별 결론

1. **T2 부유**: FD-019 예외 그대로(어느 경계에도 안 닿음, intro 80° · outro 260°). Studio 문서상 face는 bottom(모양은 같음). 아랫변 −2.6px는 위 표.
2. **티어 표기**: 노트 · BD 초급 · 일반 · 상급 · 최상급, 오파츠 T1~T4(위 FD-098). 카탈로그 tier 정수 그대로, 라벨은 family별 맵.
3. **학교 9 vs 6**: FD-099 — 티어 화면은 카탈로그 전부(실제 카탈로그 11곳: 하이랜더 · 와일드헌트 포함), 분석 S1은 계획이 쓰는 곳만. fixture는 시안처럼 9곳 카탈로그다.
4. **하위 화면 vs 별도 라우트**: 같은 페이지 안 섹션 교체(분석 모드의 하위 상태 `tiersOpen`, 사이드바 유지). 섹션 교체는 §1.4 부착면 모션.

### 학생 화면 학교 맵 이전 권장안

- `student_section_layout.dart`의 `studentSchoolLogoAsset(String? school)`은 `schoolEmblemAsset(school)`과 결과가 같다(학생 값 `red winter`·`wild hunt`·`etc`를 `schoolKey`가 같은 키로 만든다. `school_labels_test.dart`가 학생 꼴 · 카탈로그 꼴 동치를 고정). 그래서 다음 학생 쪽 slice(Lane A)에서 몸체를 `=> schoolEmblemAsset(school);` 한 줄로 바꾸고 import 하나를 더하면 된다. 이름을 남기면 `student_studio_layout_test.dart`(475~482행)를 고칠 필요가 없고, 학생 golden 변화는 0일 것이다(같은 asset 경로).
- 공용 맵의 한 가지 차이: 학생 맵은 `trim()`만 하고 공백을 남긴 키(`red winter`)였고, 공용 키는 공백 · `_` · `-`를 지운다. 학생 카탈로그에 공백 차이로만 다른 두 학교 값은 없으므로 결과는 같다.

### golden 변화 예상

- **`inventory`·`inventory-all`(변화 0)**: 목록 모드 표면 painter가 element 목록을 받게 바뀌었지만 같은 네 섹션을 같은 순서로 칠한다. 사이드바 "목록 | 분석" seg 그대로. fe6a fixture는 고치지 않았다(아래 발견 사항 3).
- **`inventory-analysis`(바뀜, 두 곳)**:
  1. 사이드바 "따로 여는 화면 → 티어별 충족률" 버튼이 비활성(흐림)에서 활성 · ghost(불투명)로. 위치 · 크기 · 글자 · 화살표 그대로.
  2. 밀레니엄 플라이아웃 학생 줄 두 개: 유우카 `중급 노트 20` → `일반 노트 20`, 노아 `중급 노트 4` → `일반 노트 4`(사용자 결정, 글자 폭이 같은 두 글자라 줄 배치는 같다).
  - 초상: 변화 없음. FE6-c fixture는 이미 `rio_battle`·`toki_battle`·`himari_battle`을 쓴다(발견 사항 3).
  - 그 밖(S1 행 · S2 · S4 · S5 · 섹션 표면): 변화 0. 분석 본문이 `_InventoryAnalysisStage` 안으로 옮겨졌지만 멈춰 있을 때 그림 순서(표면 painter → S4 · S5 · S2 · S1 내용 → 사이드바)는 같고 Transform을 끼우지 않는다. S4 히트맵 painter 기본값은 FE6-c와 같은 계산이다.
  - → 기준 이미지 `frontend/test/goldens/baseline/inventory-analysis.png`를 commit.json `whole`에 파일 단위로 넣었다(CF가 `failures/`를 보고 승인).
- **다른 장면**: 변화 0(인벤토리 탭이 보이지 않고 오프스테이지 첫 로드 시점도 그대로).
- **새 장면 `inventory-tiers`**(`fe6e_inventory_tiers_golden_test.dart`, 기준 이미지 없음 → RED, CF가 만든다). 기대 모습(일회성 렌더로 확인한 배치):
  - 왼쪽 사이드바: 분석과 같고 "티어별 충족률" 버튼이 분홍 선택, 분석 버튼 4개 ghost, 과잉 재화 버튼 없음.
  - T1(위 가운데 평행사변형): "기술 노트 · 학교 × 티어 충족률" + 칩(충족률 분홍 · 보유량 · 부족량), 9학교 × 초급 · 일반 · 상급 · 최상급 기울인 히트맵(시안 % 그대로, 예 백귀야행 95 · 89 · 52 · 10), 행 머리 엠블럼 + 학교 이름, "가장 부족" 열 `최상급 −19` · `−24` · `−21` · `−30` · `−30` · `−18` · `−16` · `−20` · `−21`, 범례.
  - T2(가운데 부유 평행사변형): "전술 교육 BD · 학교 × 티어 충족률", 시안 % 그대로, 가장 부족 `최상급 −21`(백귀야행 · 붉은겨울 · 밀레니엄) · `상급 −31`(트리니티) · `최상급 −12`·`−14`·`−12` · `상급 −23`(산해경) · `최상급 −18`(발키리, 시안 −17).
  - T4(오른쪽 위): 오파츠 13종 × T1~T4, 행 머리 그림 + 이름, 가장 부족 `T3 −37`(네브라) · `T4 −23`·`−23`·`−18`·`−21`·`−27`(로혼치, 칸 7%)·`−23`·`−18`·`−23` · `T4 −21` · `T3 −23`·`−23` · `T4 −21`.
  - T5(오른쪽 아래): "티어 품목 · 부족 상위" + "계획 필요량 기준" 칩, "부족 상위" 캡션, 6행(네브라 T3 −37 · 3명 / BD 트리니티 상급 −31 · 2명 / 노트 게헨나 최상급 −30 · 6명 + `…+1` / 노트 아비도스 최상급 −30 · 3명 / 오파츠 로혼치 사본 T4 −27 · 2명 / 노트 붉은겨울 최상급 −24 · 1명), 행은 사선을 따라 왼쪽으로.
  - T6(아래 가운데): "티어 충족 요약" + 칩, KPI 기술 노트 66% · BD 75% · 오파츠 64%(분홍) · 최상급 부족 품목 31종(분홍), "부족 품목 100종 · 티어 분포" 초급 7 · 일반 31 · 상급 31 · 최상급 31과 기울인 누적 막대.
  - 게임 그림이 테스트 asset에 없는 아이콘 · 초상은 FE6-c 장면처럼 빈 상자다.

### 검수표

artboard `Inventory-Tiers.dc.html` → 앱:
- 여는 방법: 인벤토리 탭 → 사이드바 맨 위 "분석" → "따로 여는 화면 → 티어별 충족률". Mock 기본 실행은 계획이 없어 다섯 섹션에 "저장된 계획이 없습니다…" 안내만 보인다. 시안 숫자 장면은 fixture로만 열린다(golden `inventory-tiers` 장면, `test/inventory_tiers_page_test.dart`).
- 확인 포인트:
  1. 다섯 섹션이 시안 자리인가(T1 위 평행사변형, T2 가운데 부유 · 아랫변 2.6px 위, T4 · T5 오른쪽 사다리꼴, T6 아래 평행사변형, 섹션 사이 간격).
  2. 사이드바: 티어 버튼 분홍, 다시 누르면 분석, 분석 버튼 하나를 누르면 분석으로 돌아가며 그 섹션 분홍 외곽선, "목록"이면 목록. 바뀔 때 나가는 섹션이 붙은 면 쪽으로 빠지고 들어오는 섹션이 들어오는가(T2는 아래에서).
  3. T1 · T2 · T4: 칸이 80°로 기울고 글자는 똑바른가, 행 머리 엠블럼 · 오파츠 그림과 이름 정렬, "가장 부족" 그림 + 분홍 글자, 칩 셋이 표마다 따로 바뀌는가(보유량 · 부족량은 수량), 범례.
  4. T5: 6행 글자 · `−n · 학생 n명` 분홍 · 초상 줄과 `…+1`.
  5. T6: KPI 4개와 분홍 강조, 분포 범례 칸 기울기 · 누적 막대 비율.
  6. 작은 창(1280×720)에서 예외 없이 잘리는가. 실제 계정(학교 11 · 오파츠 20)에서 칸이 줄어 들어가는가.

### 미검증 항목

- golden(새 장면 `inventory-tiers`, 바뀌는 `inventory-analysis`, 변화 0 예상 `inventory`·`inventory-all`): 미실행(CF가 `fe_gate.ps1`·`failures/` 검토·`-UpdateGoldens`).
- 전체 `fe_gate.ps1`(다른 테스트 · process E2E · `codealmanac validate`): 미실행.
- 섹션 안 요소 ±2px는 시안 좌표를 상대값으로 옮긴 계산이고 화면에서 재지 않았다(렌더 한 번은 배치 넘침 여부만 보았다). 특히 히트맵 세로 가운데 정렬(범례 22 가정)과 T1 · T2 칩 오른쪽 안쪽 17.1.
- 학교 엠블럼 · 오파츠 그림이 시안 그림과 같은 모양인지(테스트 환경에는 게임 그림이 없다).
- 실제 백엔드 카탈로그(11학교 · 20오파츠)에서의 화면은 단위 계산(칸 22.3 · 17.5px)으로만 보았다.

### WIP 보존 확인

- 고친 기존 파일 9개는 착수 때 WIP가 없었다(`git status --short` 빈 줄). 그래서 post 사본 · `post_dir`는 두지 않았다.
- 작업 트리의 다른 미커밋 변경(Lane A `plan_flow_draft.dart`·`plan_flow_goal_editor.dart`·`plan_section_layout.dart`·`plan_flow_handoff_test.dart`, 스캐너 파일들, 추적 안 된 `scan_inventory_identity_review*`)은 읽지도 고치지도 않았다.
- git 쓰기는 하지 않았다.

### 발견 사항

1. **T2 ±1px 예외**: 시안 T2의 위 · 아랫변 y가 모두 grid 줄 사이라 현재 path 생성 함수(위 · 아래 면 평행사변형)로는 ±1px가 안 된다(최선 −2.6px). 불변식을 지키려면 Studio에 부유 섹션 전용 spec(위 · 아래 y를 grid 밖 값으로)이 필요하다 — 키트 · Studio 몫, 지금은 status 기록만.
2. **시안 견본 값 불일치**: T5 부족 상위(37 · 31 · 30 · 30 · 27 · 24)가 T1 · T2 · T4의 "가장 부족"(백귀야행 −27, 보이니치 −30, 토템 폴 · 고대 전지 −37, BD 산해경 −31 등)과 맞지 않고, T6 KPI(68 · 77 · 61%) · 분포(25종 0/2/9/14)도 히트맵 %와 맞지 않는다. fixture는 히트맵 %와 T5 6행을 지키고, T5와 충돌하는 "가장 부족" 칸의 부족량을 23 이하로 줄이거나 %와 정수로 함께 안 되는 칸을 가장 가까운 값으로 바꿨다(시안과 다른 칸 13개: 노트 2 · BD 5 · 오파츠 6, 로혼치 T4는 −27을 지키려고 8 → 7%). T6는 계산값(66 · 75 · 64% · 31종 · 100종 7/31/31/31)이다. fixture 머리 주석에 칸 목록.
3. **FE6-c 발견 7(초상 id)**: `inventory_fe6c_fixture.dart`는 이미 `rio_battle`·`toki_battle`·`himari_battle`을 쓴다(FE6-c 종료 기록의 "FE6-a fixture의 `rio_armed`"가 원래 지적). 그림 없는 `rio_armed`·`toki_armed`는 `inventory_fe6a_fixture.dart`에만 있는데, 고치면 `inventory`·`inventory-all` 기준 이미지가 바뀌고(이번 조건 "변화 0" 위반) `goldens/fe6a_inventory_golden_test.dart:34`의 키(`inventory-row-Item_Icon_SecretStone_rio_armed`, 이번에 고치지 말 것)와 `inventory_controller_test.dart`·`inventory_page_test.dart`·`inventory_analysis_page_test.dart`의 키도 같이 바뀌어야 한다. 그래서 고치지 않았다. FE6-e fixture는 실제 asset id만 쓴다. 고치려면 fe6a golden 테스트 파일을 고칠 수 있는 slice(Lane A 또는 CF)에서 두 장면 갱신과 함께.
4. **실제 카탈로그 행 수**: 백엔드 카탈로그는 학교 11 · 오파츠 20이라 T4 칸이 17.5px까지 줄고 그림도 그만큼 작다. 더 늘면(오파츠 23종 이상) 최소 16px에서 상자에 잘린다. 그때는 공용 스크롤바 · 포그(기울인 grid 행 스크롤)를 붙이는 후속이 필요하다.
5. **헤더 부제**: 시안 헤더 부제는 "보유 재화와 장비 · 티어별 충족률"(분석은 "· 분석")인데, 부제는 `app_section.dart`·`app_shell.dart` 몫이라 이번 범위 밖이다. FE6-c도 분석 부제를 바꾸지 않았다.
6. **시안 "과잉 재화 / 넘치는 재화 정리" 버튼**: 티어 시안에도 있지만 FD-097대로 숨겼다.

### 사본·commit.json

- 착수 사본: `debug/frontend_fe6e/pre/<경로>`(고친 기존 파일 9개). WIP가 없어 post 사본은 없다.
- `debug/frontend_fe6e/commit.json`: slice `fe6e`, `status=false`, modified 9, added 8(새 기준 이미지 `inventory-tiers.png`는 CF가 넣는다), `whole = [이 문서, frontend/test/goldens/baseline/inventory-analysis.png]`. message 근거: Inventory-Tiers artboard, E §5, FD-019·031·032·033·098·099·101.
- 인계: `debug/frontend_fe6e/output.md`.

### 다음 행동

- FE6-e 코드는 끝났다. Lane B는 여기서 멈춘다.
- CF: 레인 워커가 모두 멈춘 뒤 gate 1회. 예상: analyze 0, 일반 테스트 +19(집계 9 + 위젯 7 + 학교 맵 3), golden은 새 장면 `inventory-tiers` 기준 없음 RED + `inventory-analysis` 두 곳(티어 버튼 · 플라이아웃 두 줄)만 RED, `inventory`·`inventory-all` 포함 다른 장면 변화 0. 승인 뒤 `-UpdateGoldens` · 재비교 · `fe_commit.ps1 -Slice fe6e`.
- 발견 사항 1(부유 섹션 spec) · 3(fe6a fixture 초상 id) · 4(티어 표 스크롤)는 CF 판단을 기다린다. 학생 화면 학교 맵 이전은 위 권장안대로 다음 학생 쪽 slice에서.

## fb2d-dart 착수 기록 (2026-10-12)

- 상태: 진행 중 → 코드 작성 완료(아래 종료 기록).
- 범위: FB-2d 프로필 삭제(7경로)의 Dart 연결. 워커 프롬프트 `debug/frontend_redesign_handoff/fb2ddart-worker-prompt-20261012.md`, 목록은 backend 로그 2026-10-12 01:28("CF fb2d-dart 연결 목록"), 사용자 결정은 CF 로그 2026-10-11 20:50(tactical-share 함께 삭제).
  1. wire 변경 0 확인 + 계약 fixture 양성·음성 테스트(기존 strict DTO·client는 그대로).
  2. 계정 삭제 확인 문구에 전술 공유 데이터를 같은 확인 안에 넣는다(새 확인 단계 없음).
  3. 삭제 성공 뒤 그 프로필의 Dart 쪽 캐시만 비우고 다른 프로필 캐시는 둔다.
  4. 응답 손실 재시도 = 같은 key + 원 expected_revision. `idempotency_conflict`·`profile_not_found` 문구 구분. Mock 의미 맞춤.
  5. process E2E 1개(7번째 파일 삭제·같은 key 재요청 = 원 revision).
- 시작 조건: backend 로그 끝에 XB "FB-2d 메인 반영 완료"(2026-10-12 02:17, 10경로 표)와 02:31 후속이 있다. 충족했다.
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `861eea5629550fa343fe8d6af32af1b17dd3254c`(XB 02:17 head before/after와 같다).
- XB 반영 SHA 대조(메인 작업 트리 bytes/SHA256 = XB 02:17 표): **10개 모두 일치**.
  - `backend/core/repository_transaction.py` 9887 `a335c2b0…7029`
  - `backend/core/repository_store.py` 44276 `713ed632…4739`(working 쪽 값. selected `2fd99bd6…`는 커밋 투영)
  - `backend/core/tactical_store.py` 16556 `023b97b1…95d9`
  - `backend/core/tactical_v2.py` 56905 `c71c881c…9472`
  - `backend/core/tactical_share_v1.py` 30760 `0fae3f63…41b4`
  - `backend/core/profile_delete_transaction.py` 14060 `28446c60…5393`
  - `backend/core/repository_participant_lock.py` 3272 `9fbaee53…ab1f`
  - `backend/tests/test_profile_delete_fb2d.py` 20271 `ebaff54e…8815`
  - `contracts/README.md` 85600 `16562377…84c1a0`(절 "FB-2d durable seven-path profile deletion")
  - `contracts/fixtures/profile_delete_fb2d_v1.json` 952 `704a0cad…989c`
- XB 목록과 메인 코드 대조: 요청 exact 3키·응답 exact `revision`·`deleted_paths` 없음이 `contracts/README.md`와 Dart 검사기(`isValidRepositoryProtocolMessage`의 `mutation({})`, 성공 `_exact({'revision'})`)에 그대로 있다. 백엔드 `delete_profile_locked`의 순서(tombstone: 다른 key → `profile_not_found`, 같은 key·다른 revision → `idempotency_conflict`, 같으면 원 응답)와 `create_profile`(삭제된 stable ID의 옛 create key → `idempotency_conflict`)도 목록과 같다. 차이 없음.
- 막힘: 대장 막힘 요약에 fb2d-dart 행 없음, 현재 열림 0건.
- 고칠 기존 파일(착수 사본 `debug/frontend_fb2ddart/pre/<v7 기준 경로>`)과 WIP(`git status --short <경로>`):
  - `frontend/lib/services/mock_app_service.dart`: **WIP 있음**(스캐너 WIP, hunk 185·496~600줄 부근). CRLF. 고치는 곳은 createProfile·deleteProfile·loadRepositoryState·`_tactical`(2050줄 이후)이라 WIP hunk와 겹치거나 맞닿지 않는다.
  - `frontend/lib/ui/widgets/account_section_cluster.dart`: WIP 없음. LF.
  - `frontend/lib/ui/pages/title_page.dart`: WIP 없음. LF. 삭제 알림 콜백 연결만.
- 고치지 않는다(확인만): `repository_service.dart`·`process_app_service.dart`(wire 그대로라 변경 0. `process_app_service.dart`는 WIP 있음, 손대지 않음), `planning_protocol_client.dart`.
- 새 파일(예정): `frontend/test/profile_delete_fb2d_test.dart`(계약 fixture·Mock 의미·삭제 확인·재시도·캐시), `frontend/test/profile_delete_fb2d_process_e2e_test.dart`(실제 백엔드).
- WIP는 지우거나 정리하지 않는다.

## fb2d-dart 종료 기록 (2026-10-12, 코드 작성 완료·CF gate 미실행)

FB-2d 프로필 삭제(7경로)의 Dart 연결을 끝냈다. wire·strict DTO·Process client는 바꾸지 않았다.

### 실행 명령·결과

- `flutter analyze`(frontend): **이슈 0**. 중간에 Lane A FE6-d가 고치던 `lib/ui/inventory/**`의 일시 오류(최대 7건, 이 slice 파일 0건)가 보였다가 Lane A 쪽에서 풀린 뒤 0건을 다시 확인했다. 마지막 줄바꿈 복원 뒤에도 0.
- 새 테스트:
  - `flutter test test/profile_delete_fb2d_test.dart`: 첫 실행 +16 −1(내 테스트의 잘못된 음성 예 `{'revision': 0}` — 기존 검사기는 revision ≥ 0을 받는다. 검사기는 그대로 두고 예를 `-1`로 고침) → **+17 통과**(마지막 확인도 +17).
  - `flutter test --concurrency=1 test/profile_delete_fb2d_process_e2e_test.dart`: **+1 통과**(18초, 첫 실행).
- 바뀐 동작에 걸리는 기존 테스트(grep: deleteProfile·createProfile·account-delete·loadTacticalState·title·account·settings·repository_*):
  - `title_page_test.dart` +25, `account_manager_fe8b_test.dart` +6, `settings_page_test.dart` +10, `repository_profile_panel_test.dart` +1, `tactical_page_test.dart` +8, `tactical_page_revision_test.dart` +5 — 모두 통과.
  - `repository_presets_service_test.dart` +49, `repository_history_query_service_test.dart` +71, `repository_history_scan_latest_test.dart` +48, `repository_history_service_test.dart` +24, `student_calculation_service_test.dart` +8, `tactical_service_test.dart` +6, `repository_protocol_contract_test.dart` +1, `mock_scanner_commit_history_test.dart` +9 — 모두 통과.
  - process(차례로, `--concurrency=1`): `repository_process_e2e_test.dart` +1, `repository_presets_process_e2e_test.dart` +1, `tactical_v2_process_e2e_test.dart` +1 — 모두 통과.
- 실패 0(위 첫 실행 1건 외), 잠금 충돌 0(재시도 없음). 로그는 `debug/frontend_fb2ddart/*.log`(실패 줄만 확인).
- `git diff --check`(고친 3파일): exit 0.

### 고친 파일

- `frontend/lib/services/mock_app_service.dart`(스캐너 WIP 위, CRLF 주·LF 122줄 섞임 그대로):
  - FB-2d tombstone(`_mockDeleteTombstones`: ID → key·원 expected_revision·응답 revision)과 create key → ID 맵(`_mockCreateKeys`), 다시 쓰지 않는 ID 번호(`_nextMockProfileNumber`). 필드는 WIP가 있는 필드 블록이 아니라 createProfile 바로 앞에 두었다.
  - `createProfile`: 같은 key·같은 이름·초상 = 원 계정, 다른 내용 = `idempotency_conflict`, 삭제된 ID의 옛 key = `idempotency_conflict`. 새 ID는 지운 ID·있는 ID를 다시 쓰지 않는다(삭제가 없으면 예전 `len+1`과 같은 값).
  - `deleteProfile`: tombstone 먼저(다른 key = `profile_not_found`, 같은 key·다른 revision = `idempotency_conflict`, 같으면 원 revision), 없는 계정 `profile_not_found`(예전엔 RangeError), 낡은 revision `revision_conflict`. 지울 때 전술 v1 `_tacticalStates`도 함께 지운다(빠져 있던 곳). `loseNextProfileDeleteResponse`(저장소에서 끝낸 뒤 `TimeoutException`).
  - `loadRepositoryState`·전술 v1(`_tactical`)은 삭제된 ID에 `profile_not_found`(다시 읽기로 빈 state를 되살리지 않는다).
- `frontend/lib/ui/widgets/account_section_cluster.dart`(LF): 확인 문구 함수 `accountDeleteConfirmText`, 오류 코드·재시도 판정·문구(`accountDeleteErrorCode`·`accountDeleteRetryable`·`accountDeleteErrorText`), 보류 요청 `_pendingDelete`, `_forgetDeletedProfile`, 선택 콜백 `onProfileDeleted`.
- `frontend/lib/ui/pages/title_page.dart`(LF): `onProfileDeleted: _forgetDeletedProfile` — 타이틀이 들고 있는 그 계정의 `_profile`·`_repositoryState`만 비우고 진행 중인 계정 읽기를 버린다.
- 새 파일: `frontend/test/profile_delete_fb2d_test.dart`(unit/widget, 17), `frontend/test/profile_delete_fb2d_process_e2e_test.dart`(process, 1).
- 고치지 않음: `repository_service.dart`·`process_app_service.dart`·`planning_protocol_client.dart`(wire 그대로), backend/contracts, app_shell, Lane A·택틱·스캐너 소유 파일, golden harness·golden 테스트, frontend/tool.

### XB 목록(01:28) 행별 검수

| XB 목록 행 | 처리 | 근거 테스트 |
|---|---|---|
| 요청 exact `profile_id, expected_revision, idempotency_key` | 변경 0. fixture 요청 양성, 키 3개 각각 빠짐·`deleted_paths`/`targets`/`include_tactical_share`/`display_name` 더함·음수 revision·빈 key 음성 | `profile_delete_fb2d_test` "요청은 exact 3키만" |
| 응답 exact `revision`, `deleted_paths` 없음 | 변경 0. fixture 응답 양성, 빈 응답·`deleted_paths`·`profile_id` 더함·음수·문자열 revision 음성(성공 payload·응답 메시지 둘 다) | "응답은 exact revision만" |
| fixture `profile_delete_fb2d_v1.json` | 7경로 목록(`tactical-share/{id}.v1.json` 포함)·tombstone 의미 키를 테스트에서 직접 읽음 | "fixture는 shape 변경 0과 7경로" |
| 확인 문구에 local tactical-share를 같은 확인으로 | 같은 AlertDialog 한 개, 문구만 바꿈 | 위젯 "확인 하나로 지우고"(대화상자 1번, 삭제 호출 1번) |
| 삭제 뒤 그 프로필 캐시 비움·다른 프로필 보존 | 아래 캐시 표 | Mock "그 계정의 데이터만", 위젯 "확인 하나로 지우고", E2E |
| 응답 손실 재시도 = 같은 key + 원 expected_revision | `_pendingDelete` 재사용, 목록 revision이 올라도 원 값 | 위젯 "응답 손실 뒤 다시 누르면", "목록 revision이 바뀌어도" |
| 재시작 뒤 같은 요청 = 원 `revision` | 실제 백엔드 재시작 뒤 확인 | E2E |
| 같은 key·revision 변경 = `idempotency_conflict` | Mock·실제 둘 다 | Mock "같은 key·원 revision", E2E |
| 삭제된 ID에 다른 key = `profile_not_found` | Mock·실제 둘 다, 화면 문구 따로 | Mock, E2E, 위젯 "이미 지워진 계정" |
| 옛 create key로 삭제된 ID 재생성 불가, 새 key는 새 ID | Mock·실제 둘 다 | Mock "옛 create key", E2E |
| Dart Mock 의미 맞춤 | 위 "고친 파일" | Mock 그룹 6건 |
| process E2E 실제 삭제·재시도·7번째 파일 | 7경로 파일을 모두 만든 뒤 삭제(아래) | E2E |

### process E2E 내용

- 임시 저장소(`Directory.systemTemp`, 끝에 지움). 실제 게임·사용자 프로필·공용 저장소 접근 0.
- 남길 계정과 지울 계정 둘 다에 같은 데이터를 만든다: 학생 2명, 전술 v1 매치, 전술 v2(v6 가져오기 fixture `tactical_v6_import_v2.json`을 `py -3.11`로 임시 sqlite에 넣어 가져오기 — 기존 `tactical_v2_process_e2e_test`와 같은 방법), 시나리오 1개, 프리셋(`repository_presets_v1.json`), 로컬 전술 공유 기록 1건(`tactical_share_v1.json`의 import 예에서 원문 이름 필드를 뺀 기록을 `importTacticalShares`로). 두 계정 모두 프로필별 파일 6개(`profiles`·`tactical` v1·v2·`scenarios`·`presets`·`tactical-share`)가 생겼는지 먼저 본다.
- 삭제 → 응답 = 원 revision + 1, 지울 계정의 파일 6개 모두 없음(7번째 `tactical-share/{id}.v1.json` 포함), `catalog.json`에는 남길 계정만·선택 유지.
- 백엔드를 끄고 새로 띄운 뒤: 같은 key·원 revision = 같은 revision, 같은 key·revision+1 = `idempotency_conflict`, 다른 key = `profile_not_found`, state 읽기 = `profile_not_found`, 옛 create key = `idempotency_conflict`. 남길 계정의 파일 6개·state revision·학생·공유 기록·시나리오 목록이 그대로. 새 create key는 다른 ID.

### 계약 SHA 대조

- 착수 때 10경로 bytes/SHA256이 XB 02:17 표와 모두 일치(착수 기록). 이 slice는 backend/contracts를 읽기만 했다.
- `contracts/fixtures/profile_delete_fb2d_v1.json` 952 B `704a0cad6180fcf07ef62f7ffdeab6ec20ff47d19b42f87f62c61018bdfa989c`, `contracts/README.md` 85600 B `165623772939a19f06209bac6735bae564aacccb6be5a9c7424164b64584c1a0`.

### 캐시 표(grep: cache·profileId·Map 필드·static shared·프로필 상태를 들고 있는 State)

| 위치 | 키 | 비우는 방법 |
|---|---|---|
| `AccountSectionCluster` `_profiles`·`_studentCounts`·`_selected`·`_editing` | 프로필 ID | 성공·`profile_not_found` 즉시 `_forgetDeletedProfile`(그 ID만 뺌, 선택은 남은 선택 계정 또는 첫 계정) → `_load()`. 다시 읽기가 실패해도 지운 계정은 목록·선택에 남지 않는다 |
| `AccountSectionCluster` `_pendingDelete` | 프로필 ID | 성공·재시도 불가 실패에서 비움. 응답 손실·바쁨·쓰기 실패만 남긴다 |
| `TitlePage` `_profile`·`_repositoryState` | 타이틀에 보이는 계정 | `onProfileDeleted`가 같은 ID면 둘 다 null + 계정 읽기 세대 증가. 타이틀로 돌아올 때 `_loadAccount` |
| `MockAppService` `_profiles`·`_repositoryStates`·`_currentHistories`·`_repositoryPlans`·`_repositoryPlanAuthoring`·`_planIdempotency`·`_repositoryPresets`·`_presetIdempotency`·`_planningScenarios`·`_planningScenarioRevisions`·`_scenarioIdempotency`·**`_tacticalStates`(이번에 추가)** | 프로필 ID | `deleteProfile`에서 그 ID만 remove. 다른 계정 값은 그대로(Mock 테스트로 확인) |
| `MockAppService` `_mockDeleteTombstones`·`_mockCreateKeys` | 프로필 ID·create key | 비우지 않는다(백엔드 tombstone과 같음, 내용은 ID·key·revision뿐) |
| `ProcessAppService` | — | 프로필별 캐시 없음(client·scanner 구독·연결 상태뿐). 7경로는 백엔드가 지운다 |
| AppShell 아래 페이지 상태: 계획(`plan_flow_save`·`repository_presets_controller`·`plan_scenario_preview` `_cache`·`plan_scenario_compare` `_cache`), 인벤토리(`inventory_controller` `_acquisitions`, 자원 key), 전술(`tactical_page`), 스캔(`scan_page` state cache), 학생·통계·홈, `RecentStudents`·`_recentScans` | 프로필(페이지 key `$_profileGeneration`) | 삭제는 타이틀의 계정 관리에서만 된다. 타이틀은 `pushReplacement`로 AppShell을 열고 AppShell에서 타이틀로 돌아오는 길이 없어, 삭제 때 AppShell과 그 캐시는 존재하지 않는다. 다음 AppShell은 새로 만든다. 설정 페이지에는 삭제가 없다(선택·생성·v6 가져오기만, `_profileChanged`로 세대 증가) |
| `StudentGridImageWarmup.shared`, `KitOverlayGroup.shared` | asset·overlay | 프로필 데이터 아님 |
| Mock 스캐너 `_scannerCommitReceipts`·`_scannerSessionRaw`·`_scannerIdentifiedInventoryKeys` | 세션 ID | 대상 아님(세션 단위, 백엔드 scanner_session도 7경로 밖). 발견 사항 1 |

### 확인 문구 전후

- 전: 제목 "계정 삭제", 본문 `'{이름} 계정과 저장 데이터를 삭제할까요?'`, 버튼 취소·삭제.
- 후: 제목·버튼 그대로, 같은 대화상자 하나. 본문 `'{이름} 계정과 저장 데이터를 삭제하시겠습니까?\n학생·인벤토리·계획·이력·프리셋·시나리오·전술대항전 기록과 함께 전술 공유 데이터(이 PC에 저장된 전술대항전 공유 기록)도 지워지며, 되돌릴 수 없습니다.'`(key `account-delete-confirm-text`).
- 실패 문구(`account-cluster-error`):
  - `profile_not_found`: "이미 삭제되었거나 찾을 수 없는 계정입니다. 계정 목록을 다시 읽었습니다."
  - `idempotency_conflict`: "이 삭제 요청은 다른 내용으로 이미 쓰인 요청이라 삭제하지 않았습니다. 계정 목록을 다시 읽었습니다. 다시 삭제하려면 삭제를 한 번 더 눌러 주십시오."(보류 요청을 버리고 다음 삭제는 새 key — 사용자가 다시 누를 때만, 저절로 새 key를 만들지 않는다)
  - `revision_conflict`: "그 사이에 계정이 바뀌어 삭제하지 않았습니다. 계정 목록을 다시 읽었습니다. 확인한 뒤 다시 삭제해 주십시오."
  - 응답 손실(시간 초과·연결 끊김)·`repository_busy`·`persistence_failed`·retryable: "삭제 결과를 확인하지 못했습니다. 삭제를 다시 누르면 같은 요청으로 다시 확인합니다."(목록을 다시 읽지 않음, 같은 key·원 revision 보존)
  - 그 밖: "계정을 삭제하지 못했습니다: {repositoryLoadErrorText}"(예전은 오류 객체 문자열 그대로)

### golden 변화 예상

- **변화 0.** 삭제 확인 대화상자가 열린 golden 장면이 없다(`test/goldens`에서 `account-delete`·AlertDialog 0건). `account-manager`·`account-editor`·`account-picker`(fe1g)·`account-new`(fe8b) 장면은 관리 레일·목록·편집기만 그리고 오류 문구가 없는 상태라 바뀌지 않는다. 타이틀은 콜백만 더해 그림 변화 없음.
- CF gate 예상: analyze 0, 일반 테스트 +17, process +1.

### 미검증 항목

- 전체 `fe_gate.ps1`·golden 비교·almanac validate·저장소 전체 `git diff --check`: **미실행**(CF 몫).
- Python 전체 테스트: **미실행**(XB 몫, XB whole 1211 PASS 보고만 읽음).
- 실제 앱에서 계정 삭제 확인 문구·응답 손실 재시도 화면: 사용자 시각 확인 미실행.
- 실제 응답 손실(백엔드가 지운 뒤 응답 전 끊김)은 process E2E에서 "삭제 후 재시작 → 같은 요청"으로 대신했다. 응답 도중 끊기는 정확한 시점은 XB crash matrix 몫.
- Windows 전원 손실·실제 사용자 프로필 삭제·native symlink fixture: XB가 NOT_VERIFIED로 남긴 경계 그대로.

### WIP 보존 확인

- `mock_app_service.dart`: pre 사본(스캐너 WIP 포함)과 끝 내용의 차이는 이 slice hunk 11개(2058줄 이후: createProfile 앞·안, deleteProfile, loadRepositoryState, `_tactical`)뿐이다. 편집 도구가 손대지 않은 LF 줄 122개를 CRLF로 바꾼 것을 찾아 pre의 줄바꿈으로 되돌렸다(바뀌지 않은 줄은 pre와 바이트까지 같다). WIP hunk(185·496~600줄 부근)는 그대로.
- `account_section_cluster.dart`·`title_page.dart`: WIP 없음, LF 그대로.
- 다른 WIP 파일(`process_app_service.dart`·`planning_protocol_client.dart`·`scanner_service.dart`·scan 계열·스캐너 테스트)은 수정 0.

### 발견 사항

1. Mock 스캐너 commit receipt는 세션 단위라 계정 삭제 뒤에도 남는다. 지운 계정의 pending(frozen) receipt를 같은 key로 재시도하면 Mock이 `_repositoryStates[지운 ID]`를 다시 쓸 수 있다. 백엔드 scanner_session도 7경로 밖이라 그대로 두었다(스캐너 소유. 실제 흐름에서는 삭제가 타이틀에서만 되고 스캔 세션은 AppShell 안이라 겹치기 어렵다). 필요하면 스캐너 slice에서 "commit 대상 프로필이 tombstone이면 `profile_not_found`".
2. Mock `loadRepositoryState`는 처음부터 없던 ID에는 여전히 빈 state를 만들어 준다(삭제된 ID만 `profile_not_found`). 기존 테스트가 seed 없는 ID를 쓰는지 다 확인하지 않아 범위를 좁혔다.
3. Mock `createProfile`은 선택 계정이 없을 때도 `selected: false`다(백엔드는 첫 계정을 선택). 기존 차이이며 호출처가 선택을 따로 한다. 이번에 바꾸지 않았다.
4. 계정 삭제가 AppShell 안(예: 설정 페이지)에 생기면 위 표의 페이지 캐시가 살아 있는 상태에서 지우게 된다. 그때는 `onProfileChanged`(세대 증가)와 같은 경로가 필요하다.
5. 착수 기록에 cluster·title을 처음에 CRLF로 잘못 적었다가 LF로 고쳤다(셸 루프의 줄바꿈 세기가 틀렸다). `mock_app_service.dart`는 CRLF 주 + LF 122줄 섞임이다.
6. Lane A FE6-d 편집 중 `lib/ui/inventory/**` 컴파일 오류가 잠시 보였고, 위젯 테스트는 analyze 0건이 된 뒤 돌렸다. 이 slice와 파일 겹침 0.

### 사본·commit.json

- 착수 사본: `debug/frontend_fb2ddart/pre/<경로>`(고친 기존 파일 3개).
- 끝 사본: `debug/frontend_fb2ddart/post/<경로>`(고친 기존 파일 3개와 새 테스트 2개).
- `debug/frontend_fb2ddart/commit.json`: slice `fb2ddart`, `status=false`, `post_dir`, modified 3, added 2, `whole = [almanac/workflows/frontend-redesign-status-lane-b.md]`(바뀌는 기준 이미지 없음). message 근거: backend 로그 01:28 Dart 목록·02:17 반영 완료, CF 로그 10-11 20:50.
- 인계: `debug/frontend_fb2ddart/output.md`.

### 다음 행동

- fb2d-dart 코드는 끝났다. Lane B는 여기서 멈춘다.
- CF: Lane A FE6-d와 이 slice가 모두 멈춘 뒤 XB source10과 같은 소스로 gate 1회(예상: analyze 0, 일반 +17, process +1, golden 변화 0) → XB FB-2d exact10 커밋 → `fe_commit.ps1 -Slice fb2ddart`(mock은 3-way 병합, WIP 인접 hunk 없음).
- 발견 사항 1·2·4는 CF 판단을 기다린다.

## fb10b-dart 착수 기록 (2026-10-12)

- 상태: 진행 중 → 코드 작성 완료(아래 종료 기록).
- 범위: FB-10b 인벤토리 "확인 필요" 영속 표시의 Dart 연결. 워커 프롬프트 `debug/frontend_redesign_handoff/fb10bdart-worker-prompt-20261012.md`, 목록은 backend 로그 2026-10-12 08:11·09:10과 `debug/xb_fb10b_product_20261012/artifacts/CF-CONNECTION.md`·`DART-HANDOFF.md`, 사용자 결정은 결정 대장 FD-146(해제 범위 2026-10-12).
  1. 새 읽기 `repository.inventory.review.get`: 별도 strict DTO·client·Process·Mock·protocol validator. 수량 스냅숏과 같은 revision에서 읽고 다르면 다시 읽음. `migration_required`·`corrupt_data`는 오류 그대로.
  2. `repository.inventory.update` optional `applied_resource_keys`(배열, null 금지, 빈 배열 허용, 최대 4096, 별칭 중복 거부). 직접 고치기 저장 = 바꾼 key + 같은 값으로 확인한 key. 재시도는 원 revision·key·scope.
  3. 인벤토리 목록 행·상세 "확인 필요" 표시 + 상세 "이 값이 맞습니다"(확인 key로 저장).
  4. Mock(수동·스캐너 commit) 의미 맞춤, 공유 fixture(`scanner_commit_history_sfb2b_v1` partial/replay, `inventory_review_fb10b_v1`)로 Mock·Process 검사.
  5. process E2E(부분 스캔 commit → 재시작 → 표시 → 같은 값 확인 + scope → 재시작 → 해제 → replay, 다른 key·다른 프로필 보존, 같은 key 다른 scope 오류).
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `0566391311e591c4b979a50a19661c8ce110eb3b`.
- XB 09:10 표 9경로 대조(메인 작업 트리 bytes/SHA256): **9개 모두 일치**.
  - `backend/core/inventory_review.py` 3830 `083774af…0b13c`
  - `backend/core/repository_store.py` 46178 `68585c7a…de35d`
  - `backend/core/repository_protocol_v1.py` 9503 `7bc87895…6c983`
  - `backend/tests/test_inventory_review_fb10b.py` 13627 `70b142a0…75f5f`
  - `backend/tests/test_planning_protocol_contract.py` 7642 `88136204…a039`
  - `contracts/README.md` 87563 `0b6aec87…69ee`(절 "FB10b durable inventory review flags v1")
  - `contracts/repository-protocol-v1.schema.json` 24165 `df42bf7b…689b`(`inventoryReviewRequest`, `inventoryRequest`의 `applied_resource_keys`, 응답 갈래)
  - `contracts/repository-inventory-review-v1.schema.json` 1305 `e8536699…2579`
  - `contracts/fixtures/inventory_review_fb10b_v1.json` 2339 `58d1021e…547b`
- XB 목록과 메인 코드 대조: `get_inventory_review`(plan 이관 없이 profile revision과 sparse 목록), `inventory_review.transition`(scan: excluded 추가 후 applied 해제·scope 밖 변경 거부 / manual: scope 없으면 실제 변경 key만, 있으면 scope ⊆ before∪after identity·변경 ⊆ scope, 아니면 `scan_scope_mismatch`), 별칭 정규화 뒤 중복 `duplicate_identity`, operation fingerprint에 scope 포함(같은 key 다른 scope = `idempotency_conflict`), profile 읽기 때 저장 버전 이상 → `migration_required`·모양 이상 → `corrupt_data`가 목록과 같다. 차이 없음. 단 목록에 없는 제약 하나: 수동 scope key는 저장된(또는 이번에 넣는) 항목이어야 한다(수량 없이 표시만 있는 key는 같은 값 확인으로 해제할 수 없고 수량을 넣어야 한다) — 발견 사항으로 종료 기록에 적는다.
- 막힘: 대장 막힘 요약에 fb10b-dart 행 없음, 현재 열림 0건. FD-146은 확정(해제 범위 포함).
- 시안: Inventory·Inventory-All(dc_outline `--text-only`)에 "확인 필요"·같은 값 확인 문구 없음. Scan-Item-Review에만 `.chip.wn` "확인 필요"와 "남은 칸은 인벤토리에 이전 값으로 남고 '확인 필요'로 표시됩니다."가 있다 → 키트 `BaChip`(warn)으로 최소 표시.
- 고칠 기존 파일(착수 사본 `debug/frontend_fb10bdart/pre/<v7 기준 경로>`)과 WIP(`git status --short <경로>`), 줄바꿈:
  - `frontend/lib/services/repository_service.dart`: WIP 없음. CRLF 주 + LF 27줄 섞임.
  - `frontend/lib/services/process_app_service.dart`: **WIP 있음**(스캐너 WIP hunk 1118~1160줄 부근). CRLF 주 + LF 24줄 섞임. 고치는 곳은 implements 목록·`saveRepositoryInventory`(612줄)·새 읽기 메서드라 WIP hunk와 겹치거나 맞닿지 않는다.
  - `frontend/lib/services/mock_app_service.dart`: **WIP 있음**(스캐너 WIP hunk 182~680줄 부근). CRLF 주 + LF 120줄 섞임. 고치는 곳은 implements 목록·Mock 스캐너 commit(810줄 이후)·`deleteProfile`·`saveRepositoryInventory`·`_saveMockCurrent`·`_MockFrozenScanCommit`과 새 읽기 메서드라 WIP hunk와 겹치거나 맞닿지 않는다.
  - `frontend/lib/ui/inventory/inventory_controller.dart`: WIP 없음. LF.
  - `frontend/lib/ui/inventory/inventory_workspace.dart`: WIP 없음. LF.
  - `frontend/test/inventory_controller_test.dart`: WIP 없음. LF(저장 대역 override 시그니처만).
- 고치지 않는다(확인만): `planning_protocol_client.dart`(repository 응답 검사를 `isValidRepositorySuccessPayload`에 맡기고 오류 코드 집합에 `idempotency_conflict`·`corrupt_data`·`migration_required`가 이미 있다. WIP 있음, 손대지 않음).
- 새 파일(예정): `frontend/lib/services/repository_inventory_review.dart`(DTO·요청·key 검사·capability), `frontend/test/inventory_review_fb10b_test.dart`(계약 fixture·Mock 의미·컨트롤러·위젯), `frontend/test/inventory_review_fb10b_process_e2e_test.dart`(실제 백엔드).
- WIP는 지우거나 정리하지 않는다.
- 줄바꿈 정정: 처음 적은 "CRLF"는 셸 줄바꿈 세기를 잘못한 값이었다. 바이트로 다시 센 pre 사본 기준으로 위처럼 고쳤다.

## fb10b-dart 종료 기록 (2026-10-12, 코드 작성 완료·CF gate 미실행)

FB-10b 인벤토리 "확인 필요" 영속 표시의 Dart 연결을 끝냈다. 새 읽기 DTO·client·Process·Mock·검사기, 수동 저장 scope, 인벤토리 행·타일·상세 표시와 "이 값이 맞습니다", Mock 스캐너 commit 의미, process E2E.

### 실행 명령·결과

- `flutter analyze`(frontend): 작업 중에는 Lane A FE5-f 편집 중 파일(`planning_page_test.dart`·`planning_document_projection_test.dart` 등)의 오류가 보였다(최대 108건, 이 slice 파일 0건). 이 slice의 구문 오류 3건(`error is T ? a?[..] : b` 해석)을 switch 패턴으로 고친 뒤 이 slice 파일 0건. 마지막 실행(줄바꿈 복원 뒤): **No issues found(0)**.
- 새 테스트:
  - `flutter test test/inventory_review_fb10b_test.dart`: ① 컴파일 오류 1(테스트의 `RepositoryProfile` `selected:` 빠짐) → ② **+18 −1**(컨트롤러 저장 key `inventory-save-<마이크로초>`가 빠른 두 저장에서 같아짐 — 같은 key·다른 내용이면 `idempotency_conflict`가 되는 실제 결함. key에 순번을 붙여 고침) → ③ **+19**. 마지막 확인 +19.
  - `flutter test --concurrency=1 test/inventory_review_fb10b_process_e2e_test.dart`: **+1**(첫 실행부터 통과, 마지막 확인 +1).
- 바뀐 동작에 걸리는 기존 테스트(grep: `saveRepositoryInventory`·`InventoryController`·`InventoryPage`·`inventory.update`·`isValidRepository`·`commitScannerCandidate`·`MockAppService`, Lane A 계획 테스트 제외):
  - 1차(expanded, 45파일 병렬): +601 −1. 실패 1은 `planning_protocol_client_test.dart`의 실제 Python 테스트 "real Python process serves every P0 planning method"가 병렬 부하로 20초 시간 초과 → 그 파일만 `--concurrency=1`로 다시 돌려 **+24 통과**.
  - 2차(json, 그 파일 뺀 44파일): **+578 −0**. 파일별: account_manager_fe8b +6, diagnostics_service +2, home_app_shell +1, home_page +5, inventory_analysis_page +8, inventory_analysis +16, inventory_controller +13, inventory_currency_readonly +2, inventory_fb3_service +15, inventory_opa_page +6, inventory_opa +9, inventory_page +9, inventory_review_fb10b +19, inventory_shell_lazy +1, inventory_tiers_page +7, inventory_tiers +9, inventory_view_model +13, kit/ui_kit_gallery +6, mock_scanner_commit_history +9, mock_scanner_service +4, profile_delete_fb2d +17, recovery_banner +2, repository_history_query_service +71, repository_history_scan_latest +48, repository_history_service +24, repository_plan_replace_service +7, repository_plan_service +13, repository_presets_service +49, repository_profile_panel +1, repository_protocol_contract +1, scan_page_pause_fb10a +8, scan_page_revision +14, scan_page +17, scanner_pause_fb10a +39, scanner_target_metadata_fb4 +19, settings_page +10, statistics_app_shell +1, statistics_page +9, student_calculation_service +8, tactical_page_revision +5, tactical_page +8, tactical_service +6, title_page +25, widget_test +16.
  - process(`--concurrency=1`, 10파일 차례로): **+13 −0** — inventory_review_fb10b_process_e2e +1, inventory_fb3_process_e2e +1, repository_history_process_e2e +2, repository_history_query_process_e2e +2, repository_history_scan_latest_process_e2e +1, repository_process_e2e +1, final_p6_process_e2e +2, scenario_process_e2e +1, scanner_process_e2e +1, profile_delete_fb2d_process_e2e +1.
  - 줄바꿈 복원 뒤 마지막 확인: inventory_review_fb10b +19, inventory_controller +13, inventory_page +9, mock_scanner_commit_history +9, repository_protocol_contract +1, profile_delete_fb2d +17(합 +68), process E2E +1.
- 잠금 충돌 0(재시도 없음). 로그는 `debug/frontend_fb10bdart/logs/`(실패 줄만 확인).
- `git diff --check`(고친 6파일 + status): exit 0. 새 3파일: 줄 끝 공백 0, 끝 개행 하나.

### 고친 파일

- `frontend/lib/services/repository_inventory_review.dart`(새, LF): `RepositoryInventoryReview`(exact 4키, `version` int 1, profile_id 24hex, revision ≥ 0, key 목록 = 정규·code point 정렬·unique·각 1..1024 UTF-8 바이트·짝 없는 surrogate 거부·최대 4096, `needsReview`, `fromWireFor`), `RepositoryInventoryReviewRequest`(exact `profile_id`), `repositoryInventoryAppliedKeys`(scope: 배열만·별칭 → 현재 key·중복 거부·정렬), capability `RepositoryInventoryReviewService`(기존 대역 소스 호환, presets 선례).
- `frontend/lib/services/repository_service.dart`(WIP 없음): 새 파일 export, 응답 검사 `repository.inventory.review.get`, 요청 검사 `repository.inventory.review.get`·`repository.inventory.update` optional `applied_resource_keys`, 인터페이스 `saveRepositoryInventory`에 optional named `appliedResourceKeys`(문서 주석).
- `frontend/lib/services/process_app_service.dart`(스캐너 WIP 위): implements에 capability, `saveRepositoryInventory` scope 전송(정규화·중복은 보내기 전 FormatException), `loadRepositoryInventoryReview`(`fromWireFor`).
- `frontend/lib/services/mock_app_service.dart`(스캐너 WIP 위): 계정별 저장 메타 원본 `_mockInventoryReviews`(sparse), `debugSetInventoryReviewMetadata`(테스트 주입), `_mockReviewKeys`(모르는 버전 `migration_required`, 깨진 모양 `corrupt_data`), `loadRepositoryInventoryReview`(이관·쓰기 없이 그 revision), 스캐너 commit 전이(쓰기 앞에서 계산: excluded 추가 → applied 해제), `_MockFrozenScanCommit.excludedKeys`, 수동 저장 scope 검사·fingerprint(`inventory-manual-scope-v1`)·전이(`_mockManualReview`), `deleteProfile`에서 표시 삭제.
- `frontend/lib/ui/inventory/inventory_controller.dart`: 표시 읽기(상태 뒤, revision 다르면 둘 다 다시 읽기 최대 2번, 오류는 계정 오류 문구), `needsReview`·`canConfirmReview`·`confirmReview`·`appliedResourceKeys`, 저장 scope 항상 명시, 결과를 모르는 저장(시간 초과·연결 끊김·`repository_busy`·`persistence_failed`·retryable)은 같은 내용이면 원 revision·key·scope·bucket을 그대로 다시 보냄, `scan_scope_mismatch`·`idempotency_conflict`·응답 손실 문구 구분, 저장 key에 순번.
- `frontend/lib/ui/inventory/inventory_workspace.dart`: `InventoryRiskRow.needsReview`(이름 옆 `BaChip` warn "확인 필요"), `InventoryItemTile.needsReview`(왼쪽 위 10px warn 점 + 접근성 이름 "· 확인 필요"), 상세 확인 필요 줄 `_ReviewLine`(칩·설명·"이 값이 맞습니다", `InventoryMetrics.reviewHeight` 40). 표시가 없으면 위젯 트리가 예전과 같다.
- `frontend/test/inventory_controller_test.dart`: `_RejectingService.saveRepositoryInventory` override 시그니처만(optional named 추가).
- 새 테스트: `frontend/test/inventory_review_fb10b_test.dart`(19), `frontend/test/inventory_review_fb10b_process_e2e_test.dart`(1).
- 고치지 않음: `planning_protocol_client.dart`(repository 응답 검사를 `isValidRepositorySuccessPayload`에 맡기고 오류 코드 집합에 필요한 코드가 이미 있다), backend/contracts, kit, app_shell, Lane A 계획 파일·테스트, 택틱·스캐너 소유 파일, golden harness·golden 테스트, frontend/tool.

### XB 목록(08:11·09:10·CF-CONNECTION) 행별 검수

| XB 목록 행 | 처리 | 근거 테스트 |
|---|---|---|
| 새 `repository.inventory.review.get`, 요청 exact `profile_id` | `RepositoryInventoryReviewRequest`·요청 검사(빈·키 더함·짧은 ID 음성) | `inventory_review_fb10b_test` "request is exact profile_id…" |
| 응답 exact `version`(=1)·`profile_id`·`revision`·`needs_review_keys`, 정렬·unique·canonical, 없는 key = false | 별도 DTO(수량 DTO에 끼우지 않음), 음성 14종(키 더함·빠짐·버전 2·문자열·revision −1·bool·ID·null·역순·중복·별칭·빈 key·1025바이트·4097개) | "response DTO is exact…", fixture 5메시지 |
| fixture `inventory_review_fb10b_v1.json` | policy 6항목과 메시지 5개 유효성 그대로 | "fixture policy and every shared message validity" |
| 수량 스냅숏과 같은 revision에서 읽고 다르면 다시 읽기 | 컨트롤러: 상태 → 표시, 다르면 둘 다 다시(최대 2번 더), 계속 다르면 오류 | "a revision mismatch rereads both…" |
| 모르는 버전 `migration_required`, 깨진 메타 `corrupt_data`, 빈 목록으로 삼키지 않음 | Mock 오류 그대로, 컨트롤러는 계정 오류 문구 + 상태 비움(편집 불가) | Mock "unsupported or corrupt…", 컨트롤러 "…block the inventory…" |
| Process·Mock·protocol validator | Process `loadRepositoryInventoryReview`·scope 전송, Mock 구현, 검사기 두 곳 | 위 + process E2E |
| update optional `applied_resource_keys`(null 금지·빈 배열 허용·4096·별칭 중복 거부) | 요청 검사·Process 정규화·Mock `invalid_payload`(`duplicate_identity`/`invalid_inventory_review`) | "request is exact…", Mock "changed quantity outside…" |
| 직접 고치기 = 바꾼 key + 같은 값 확인 key만 | `appliedResourceKeys` = 고친 key 중 전후에 항목이 있는 것 + 확인 key. scope는 항상 명시 | 컨트롤러 "reads flags… saves edited keys as scope" |
| 같은 값 확인("이 값이 맞습니다") | 상세 버튼 → scope = 그 key, 수량 그대로 | 컨트롤러 같은 테스트, 위젯 "rows, tiles and detail…" |
| scope 밖 수량 변경 → `invalid_payload`/`scan_scope_mismatch` | Mock 같은 검사(쓰기 0), 컨트롤러 문구·draft 유지 | Mock, 컨트롤러 "scope mismatch and idempotency conflict…", E2E 6 |
| 재시도 = 원 revision·key·scope, 같은 key 다른 scope = `idempotency_conflict` | 컨트롤러 보류 요청, Mock fingerprint에 scope | 컨트롤러 "a lost save response…", Mock "explicit unchanged…", E2E 3·5 |
| scope 없는 기존 호출은 실제 변경 key만 해제 | Mock `_mockManualReview` | Mock "legacy full snapshot…" |
| 화면: 행·상세 표시(그 행 key만) | 행 칩·상세 줄·타일 점, 정규 key로만 매핑 | 위젯 테스트 |
| Mock: scan applied 해제, identified excluded 이전 수량 + 표시, 이전 수량 없으면 표시만, 빈 승인 scope commit 없음, 수동 scope key만, 가짜 스캔 시각 없음 | 위 "고친 파일" | Mock 스캐너 3건(sfb2b partial 2 + 빈 scope) · 수동 4건 |
| unresolved slot key 없음, 리뷰·취소만으로 표시 없음 | Mock은 식별 key 없는 항목을 기억하지 않는다(기존). 리뷰 후 취소 = 표시 0 | "review or cancel alone never flags…" |
| 공유 fixture `scanner_commit_history_sfb2b_v1` partial/replay | `inventory_partial_first`·`inventory_partial_nochange` 각각 commit + 같은 요청 replay(응답·revision·표시 그대로) | Mock 스캐너 2건 |
| 계정 삭제 때 표시 삭제(FB-2d 범위)·다른 프로필 보존 | Mock `deleteProfile` | Mock "other buckets and the other profile…" |
| 다른 bucket·unattributed 쓰기는 표시를 지우지 않음 | 학생·목표 저장 뒤 그대로 | 같은 테스트 |
| process E2E: 부분 스캔 → 재시작 → B 표시 → B 같은 값 확인 + B scope → 재시작 → 해제 → 원 요청 replay, 관계없는 key·다른 프로필 보존, 같은 key 다른 scope 오류 | 아래 | `inventory_review_fb10b_process_e2e_test` |

### process E2E 내용

- 임시 저장소(`Directory.systemTemp`, 끝에 지움). 실제 게임·사용자 프로필·공용 저장소 접근 0. 백엔드 진입점은 inline(`-c`): 실제 `JsonRepository`·`ApplicationProtocolV1`·`ScannerSessionService`에 고정 인벤토리 matcher(A 7·B 99·C 70·D 5, 카탈로그 revision = `CATALOG_REVISION`)만 붙인다(기존 `tests.scanner_e2e_backend`는 인벤토리 matcher가 빈 목록이라 쓸 수 없다. backend 파일은 바꾸지 않음 — 발견 사항 1).
- 두 계정에 A 3·B 9·C 7을 넣고, 한 계정만 스캔. 후보 A·B·C·D 중 A만 승인 → commit revision +1.
- 재시작 뒤: 수량 A 7·B 9·C 7(D 없음), 표시 `[B, C, D]`(D는 이전 수량이 없어 표시만), 표시 revision = 상태 revision.
- B를 같은 값으로 확인 + scope `[B]` → revision +1. 같은 key·scope `[B, C]` → `idempotency_conflict`.
- 재시작 뒤: 표시 `[C, D]`, 수량 그대로. 원 revision·key·scope 재요청 = 원 revision(쓰기 없음). C를 바꾸면서 scope `[D]` → `invalid_payload`/`scan_scope_mismatch`, revision·표시 그대로.
- 다른 계정: revision·수량 그대로, 표시 없음. 백엔드 프로세스 3개 모두 exit 0.

### 계약 SHA 대조

- 착수·종료 두 번 9경로 bytes/SHA256이 XB 09:10 표와 모두 일치(착수 기록). 이 slice는 backend/contracts를 읽기만 했다.
- `contracts/repository-inventory-review-v1.schema.json` 1305 B `e85366990ae6060e39588f58cbfe1de9f6f48e248706edad76eee2ad74722579`, `contracts/fixtures/inventory_review_fb10b_v1.json` 2339 B `58d1021e1ac36cd84f41a72ca29d183a205c3dfbd75848df73d503d40a6a547b`, `contracts/repository-protocol-v1.schema.json` 24165 B `df42bf7b832eacd06f9988e8fc4585f4ee98f2070a89d9ac78684bc91186689b`, `contracts/README.md` 87563 B `0b6aec87ccf176ed018843f8c13140bcc9341b9bdfd639c202d4e4a7597c69ee`.
- 함께 쓴 기존 fixture: `contracts/fixtures/scanner_commit_history_sfb2b_v1.json` 13433 B `3f7c1df74e640964a4a93b94b7f068b7d6bad129bf061113a862ca77f7386ff9`.

### 화면 표시 근거(시안)

- Inventory·Inventory-All(`dc_outline.py --text-only`): "확인 필요"·같은 값 확인 문구·표시 KPI·필터 없음. 그래서 KPI·필터에는 넣지 않았다.
- Scan-Item-Review: `.chip.wn` "확인 필요"(→ 키트 `BaChip` `AppTones.warn`), "남은 칸은 인벤토리에 이전 값으로 남고 '확인 필요'로 표시됩니다."
- 시안에 없는 문구(이 slice가 정함, ~습니다체): 버튼 "이 값이 맞습니다"(프롬프트 예시), 상세 설명 "스캔에서 적용하지 않아 이전 값으로 남아 있습니다." / "스캔에서 적용하지 않았고 저장된 수량이 없습니다. 수량 직접 고치기로 넣어 주십시오.", 저장 결과 "이 값을 확인했습니다. 확인 필요 표시를 지웠습니다(revision n).", 읽기 오류 문구 4종(모르는 형식·손상·같은 시점·읽기 실패)과 저장 실패 3종(결과 모름·범위 밖·다른 내용의 같은 요청).
- 타일(74px)에는 칩이 들어가지 않아 10px warn 점으로 대신했다(발견 사항 3).

### golden 변화 예상

- **변화 0.** 인벤토리 장면(`inventory`·`inventory-all`·`inventory-analysis`·`inventory-analysis-opa`·`inventory-tiers`)의 fixture(`InventoryFixtureService`)에는 표시 메타가 없어 Mock 읽기가 빈 목록을 준다. 표시가 없을 때 행은 예전 `Text` 그대로, 타일은 예전 `ItemTile` 그대로(접근성 이름도 같음), 상세 확인 줄은 그리지 않는다. 다른 장면은 인벤토리 위젯을 쓰지 않는다. golden 테스트는 돌리지 않았다.
- 표시가 보이는 장면은 만들지 않았다(CF 판단: 행 칩·상세 줄·타일 점이 보이는 장면이 필요하면 fixture에 `debugSetInventoryReviewMetadata`로 key를 두면 된다).
- CF gate 예상: analyze 0, 일반 +19, process +1, golden 변화 0.

### 미검증 항목

- 전체 `fe_gate.ps1`·golden 비교·almanac validate·저장소 전체 `git diff --check`: **미실행**(CF 몫).
- Python 전체 테스트: **미실행**(XB 몫, XB canonical full 1226 PASS 보고만 읽음).
- Lane A 계획 테스트(`plan_*`·`planning_page_test` 등): **미실행**(Lane A FE5-f 편집 중 파일. 이 slice가 바꾼 Mock 경로는 인벤토리 저장·스캔 commit·표시 읽기·계정 삭제뿐이다).
- 실제 게임 인벤토리 스캔에서의 부분 승인 → 인벤토리 표시: **미실행**(사용자 실기). 스캔 탭 쪽 표시(FE8-g5)는 범위 밖.
- 실제 앱에서 행 칩·타일 점·상세 확인 줄의 모양: 사용자 시각 확인 미실행.
- 응답 손실 재시도는 Mock(저장 뒤 시간 초과)과 process(재시작 뒤 같은 요청)로 대신했다. 실제 응답 도중 끊김 시점은 XB 몫.

### WIP 보존 확인

- `mock_app_service.dart`: pre 사본(스캐너 WIP 포함)과 끝 내용의 차이는 이 slice hunk 11개(38·830·861·953·2247·2347·2973·3050·3062·3161·3170줄 부근)뿐이고 WIP hunk(182~680줄)와 겹치거나 맞닿지 않는다.
- `process_app_service.dart`: hunk 2개(29·614줄 부근), WIP hunk(1118줄 이후)와 떨어져 있다.
- 편집 도구가 줄바꿈이 섞인 파일 셋을 CRLF로 통일했던 것을 pre 기준 줄 정렬(difflib)로 되돌렸다: 바뀌지 않은 줄은 pre 줄바꿈 그대로(mock 128·process 24·repository_service 27줄 복원), 새 줄은 바로 앞 줄의 줄바꿈. 다시 검사해 차이 0. 인벤토리 파일·테스트는 LF 그대로.
- 다른 WIP 파일(`planning_protocol_client.dart`·`scanner_service.dart`·scan 계열·스캐너 테스트)은 수정 0. `pubspec.yaml`·`pubspec.lock` 변경 0.

### 발견 사항

1. 인벤토리 스캔을 실제 게임 없이 돌리는 백엔드 E2E 진입점이 없다(`backend/tests/scanner_e2e_backend.py`의 인벤토리 matcher는 빈 목록). process E2E는 백엔드 클래스만 조립하는 inline `-c` 진입점을 테스트 파일 안에 두었다. XB가 `backend/tests/`에 인벤토리 E2E 진입점을 두기를 원하면 그쪽으로 옮길 수 있다(XB 판단).
2. 수동 scope key는 저장 전후 항목에 있어야 한다(`inventory_review.transition`의 `applied ⊆ identities`). 그래서 이전 수량 없이 표시만 있는 key는 "같은 값 확인"으로 지울 수 없고, 수량을 넣어야(또는 스캔이 적용해야) 지워진다. 화면은 그 key에서 확인 버튼을 숨기고 직접 고치기를 안내한다. "모름"으로 두고 확인하는 길이 필요하면 백엔드 규칙 변경이 필요하다(XB·사용자 판단).
3. 시안 Inventory·Inventory-All에 표시가 없어 행·상세는 키트 칩, 타일은 10px warn 점으로 최소 표시했다. 타일 점은 키트에 없는 표시라 디자인 확인이 필요하다(CF). 표시 행 수 KPI·필터는 넣지 않았다.
4. 기존 인벤토리 저장 key `inventory-save-<마이크로초>`는 Windows에서 빠른 두 저장이 같은 key가 될 수 있다(테스트에서 재현). scope가 fingerprint에 들어가면서 `idempotency_conflict`가 될 수 있어 순번을 붙였다(key 모양만 바뀜). 다른 화면의 같은 패턴(`DateTime.now().microsecondsSinceEpoch` key)은 확인하지 않았다.
5. Mock은 깨진·모르는 표시 메타를 표시 읽기와 인벤토리 쓰기에서만 오류로 낸다. 백엔드는 그 프로필의 모든 읽기(`state.get` 포함)가 같은 오류다. 화면 결과(계정 오류)는 같다.
6. 스캔 탭에서 commit한 뒤 인벤토리 탭의 표시 갱신은 기존 탭 진입 때 다시 읽기에 기대고 이 slice에서 바꾸지 않았다. 스캔 탭 쪽 표시는 FE8-g5.
7. `planning_protocol_client_test.dart`의 실제 Python 테스트는 다른 테스트와 병렬로 돌리면 20초 시간 초과가 날 수 있다(기존, 혼자 돌리면 통과). fe_gate의 process 분리 대상인지 CF 확인.
8. 워커 재량 FD 없음(대장 열림 0건).

### 사본·commit.json

- 착수 사본: `debug/frontend_fb10bdart/pre/<경로>`(고친 기존 파일 6개).
- 끝 사본: `debug/frontend_fb10bdart/post/<경로>`(고친 기존 파일 6개와 새 파일 3개).
- `debug/frontend_fb10bdart/commit.json`: slice `fb10bdart`, `status=false`, `post_dir`, modified 6, added 3, `whole = [almanac/workflows/frontend-redesign-status-lane-b.md]`(바뀌는 기준 이미지 없음). message(ASCII) 근거: backend 로그 08:11 Dart 목록·09:10 반영 완료, CF-CONNECTION.md, FD-146.
- 인계: `debug/frontend_fb10bdart/output.md`.

### 다음 행동

- fb10b-dart 코드는 끝났다. Lane B는 여기서 멈춘다.
- CF: Lane A FE5-f와 이 slice가 모두 멈춘 뒤 XB 09:10 9경로와 같은 소스로 gate 1회(예상: analyze 0, 일반 +19, process +1, golden 변화 0) → XB selected exact9 커밋 → `fe_commit.ps1 -Slice fb10bdart`(mock·process는 3-way 병합, WIP 인접 hunk 없음).
- 발견 사항 1·2는 XB, 3은 CF(디자인), 4·7은 CF 판단을 기다린다.

## FE6-f 착수 기록 (2026-10-13)

- 상태: 진행 중 → 코드 작성 완료(아래 종료 기록).
- 범위: 인벤토리 화면과 FB-2 이력(커밋된 백엔드·Dart 서비스)의 연결. 워커 프롬프트(CF, 로컬 Claude Code). 새 백엔드·계약 없음.
  1. KPI 델타(Inventory B): "부족 재화 +n 지난 스캔 대비"·"과잉 재화 ±n"·"최근 감소 n종"·"마지막 스캔 n일 전"(FD-041, 이력 0·1회 → `—`).
  2. 상세 스파크라인(Inventory D "최근 변화 · 스캔 n회", 시안 기간 4주, FD-033 한 재화 안, 모르는 구간은 끊긴 선 · 빗금).
  3. Inventory-All D "최근 변화"(순변화 · 소진 예상)와 Inventory-Analysis S5(1주·2주·4주 순증감 상위 6행 diverging 막대 + "이 추세라면" 예측 행, FD-042).
  4. 이력 읽기: 탭을 처음 열 때 한 번, 저장·스캔 commit 뒤 revision이 바뀌면 다시(오프스테이지 계산 0 유지).
  5. FE6-e 발견 3: `inventory_fe6a_fixture.dart`의 그림 없는 id `rio_armed`·`toki_armed` → 실제 asset id `rio_battle`·`toki_battle`.
- 범위 밖: `lib/services/**`(읽기만), `lib/ui/kit/**`, Lane A 계획 파일·테스트, 통계 화면, golden harness, `app_shell.dart`, `frontend/tool/**`, backend·contracts, 택틱·스캐너 소유 파일. 새 golden 장면 없음.
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `9c03d50b0c00fcf0a0df72da44be0c8694c99629`.
- 막힘: 대장 막힘 요약의 FE6-f 행은 FD-041(확정 2026-10-06)뿐이고 지금 `열림` 0건. FD-042는 워커 재량(권장안대로), FD-031·FD-033·FD-146은 확정.
- 쓸 history 메서드와 응답 필드(`RepositoryService`, 읽기만):
  - `loadRepositoryHistoryEvents(RepositoryHistoryEventsRequest(profileId, fromAt: 지금 − 28일, limit: 200))`(+ `nextCursor` → `withCursor`): `revision`·`coverage`(origin · baseline_at · first_retained_at · timestamps_monotonic · reasons) · `events[]`(sequence · recorded_at · source · scan_context.session_id · applied_scope.resource_keys · inventory_changes before/after present·quantity) · `scan_points[]`(session_id · sequence · recorded_at).
  - `loadRepositoryHistoryScanLatest(RepositoryHistoryScanLatestRequest(profileId, resourceKeys: 카탈로그 정규 key 256개씩))`: `by_resource_key[].latest_scan.recorded_at`(마지막 인벤토리 스캔).
  - `loadRepositoryHistorySummary([profileId])`: `revision`(탭을 다시 열 때 저장소가 바뀌었는지만 본다).
- 고칠 기존 파일(착수 사본 `debug/frontend_fe6f/pre/<v7 기준 경로>`, 사본과 작업 트리 `cmp` 일치):
  - `frontend/lib/ui/inventory/inventory_controller.dart`
  - `frontend/lib/ui/inventory/inventory_workspace.dart`
  - `frontend/lib/ui/inventory/inventory_analysis_sections.dart`
  - `frontend/lib/ui/studio/inventory_studio_layout.dart`
  - `frontend/lib/ui/pages/inventory_page.dart`
  - `frontend/test/inventory_fe6a_fixture.dart`, `frontend/test/inventory_fe6c_fixture.dart`
  - `frontend/test/inventory_page_test.dart`, `inventory_controller_test.dart`, `inventory_view_model_test.dart`, `inventory_shell_lazy_test.dart`, `inventory_analysis_page_test.dart`, `inventory_review_fb10b_test.dart`(id 변경에 걸리는 키·기대)
  - `frontend/test/goldens/fe6a_inventory_golden_test.dart`(fixture id가 들어간 기다림 키 한 줄)
- 새 파일(예정): `frontend/lib/ui/inventory/inventory_history.dart`(집계 순수 함수), `frontend/lib/ui/inventory/inventory_history_charts.dart`(스파크라인 · 증감 막대 painter, 키트 승격 후보), 테스트 `frontend/test/inventory_history_test.dart`·`frontend/test/inventory_history_page_test.dart`.
- WIP: 고칠 기존 파일 14개 모두 `git status --short <경로>`가 비어 있다(미커밋 변경 없음). 줄바꿈은 `inventory_page.dart`·`inventory_page_test.dart`가 작업 트리 CRLF, 나머지는 LF(`git ls-files --eol`).

## FE6-f 종료 기록 (2026-10-13, 코드 작성 완료·CF gate 미실행)

인벤토리 화면과 FB-2 이력(커밋된 서비스 `repository.history.*`)을 연결했다. 새 백엔드 · 계약 · 서비스 변경은 없다.

### 실행 명령·결과

모두 `frontend`에서 이 PC(Claude Code)로 실행했다. 로그는 `debug/frontend_fe6f/logs/`에 있고, 실패 줄(`[E]`·`EXCEPTION`·`Some tests failed`·`error •`)만 찾았다.

| 명령 | 결과 |
|---|---|
| `flutter analyze`(1차) | 이슈 64(오류: `const m = 클래스` 별칭으로 정적 상수를 읽음, info `prefer_initializing_formals` 3) → 고침 |
| `flutter analyze`(2차) | 오류 1(`InventoryClockSource` 승격이 클로저 안에서 안 됨) + info 3 → switch 패턴 · 위치 인자로 고침 |
| `flutter analyze`(fixture · 테스트 작성 중 3회) | warning 1씩(쓰지 않는 import · 매개변수) → 고침 |
| `flutter analyze`(최종) | **No issues found**(info 포함 0) |
| 기존 인벤토리 테스트 13파일(1차) | +125 −2: `inventory_page_test` "fixture plan…"(상세 `inventory-history-empty` 기대), `inventory_analysis_page_test` "…S5 empty state"(S5 빈 상태 기대). 둘 다 이력이 생겨 바뀐 동작이라 기대를 고쳤다(아래) |
| `flutter test test/inventory_history_test.dart`(새) | 33 통과 · 0 실패(첫 실행) |
| `flutter test test/inventory_history_page_test.dart`(새) | 11 통과 · 0 실패(첫 실행) |
| 최종 19파일(json reporter, 아래) | **+323 −0** |
| `flutter test --concurrency=1` process 5파일 | **+7 −0**: inventory_fb3_process_e2e +1, inventory_review_fb10b_process_e2e +1, repository_history_process_e2e +2, repository_history_query_process_e2e +2, repository_history_scan_latest_process_e2e +1 |
| `git diff --check`(고친 14파일 + 이 문서) | exit 0. 새 5파일은 LF · 줄 끝 공백 0 · 끝 개행 하나. 기존 파일 줄바꿈은 pre와 같다(`inventory_page.dart`·`inventory_page_test.dart` CRLF, 나머지 LF) |

최종 19파일의 파일별 결과:

- inventory_analysis_page +8, inventory_analysis +16, inventory_controller +13, inventory_currency_readonly +2, inventory_fb3_service +15
- **inventory_history_page +11**(새), **inventory_history +33**(새)
- inventory_opa_page +6, inventory_opa +9, inventory_page +9, inventory_review_fb10b +19, inventory_shell_lazy +1, inventory_tiers_page +7, inventory_tiers +9, inventory_view_model +13
- mock_scanner_commit_history +9, repository_history_query_service +71, repository_history_scan_latest +48, repository_history_service +24

- 걸리는 기존 테스트는 grep으로 찾았다. 찾은 말: `inventory-kpi`·`inventory-history`·`inventory-analysis-changes`·`InventoryController`·`InventoryPage`·`inventory_workspace`·`inventory_studio_layout`·`InventoryFixtureService`·`InventoryAnalysisFixtureService`·`top-tab-inventory`·`inventory_history`·`rio_armed`·`toki_armed`. goldens를 뺀 걸린 파일은 전부 실행했다. 프롬프트대로 `inventory_*_test` 전부, `repository_history_*`, `mock_scanner_commit_history`도 돌렸다.
- 일회성 렌더 확인: `inventory`·`inventory-all`·`inventory-analysis`와 같은 조작을 실제 글꼴로 그려 scratchpad PNG로 한 번 보았다. harness 공개 함수(`loadGoldenFonts`·`settleGoldenScene`)만 썼고 golden 비교는 아니다. 임시 테스트 `test/zz_fe6f_render_tmp_test.dart`는 실행 뒤 지웠다. KPI 증감 · 스파크라인 · S5 행 · 막대 · 예측 행이 시안 자리에 들어오고 넘침이 없었다.
- `dart format`을 기존 파일에 돌려 손대지 않은 줄 17곳(컨트롤러 7 · 분석 섹션 10)이 다시 감싸졌다. pre 사본 기준으로 그 hunk만 되돌렸고, diff에는 이 slice 줄만 남았다.
- 빌드 잠금(`build/`·`.dart_tool/`) 충돌은 없었다. `flutter analyze`가 pub get을 돌렸지만 `pubspec.lock`·`pubspec.yaml`은 바뀌지 않았다.
- 실행하지 않음: golden(`test/goldens/**`), 전체 `fe_gate.ps1`, `-UpdateGoldens`, `fe_commit.ps1`, 맨 `flutter test`, `codealmanac validate`.

### 고친 파일

- **`lib/ui/inventory/inventory_history.dart`(새)**: 이력 집계 순수 함수다. 위젯 · 서비스 호출이 없어 FE7-h가 다시 쓸 수 있다.
  - `InventoryHistory`: 지금 − 28일 적용(모든 출처)을 지금 확정 수량에서 거꾸로 되돌려, 재화별 스캔 점과 기간(1 · 2 · 4주) 시작 수량을 만든다.
  - 집계: KPI 증감 `inventoryKpiDeltas`, 스파크라인 `inventorySparkline`, 추세 `inventoryTrend`, S5 순증감 `inventoryNetChanges`, 예측 `inventoryForecasts`.
  - 표시 도우미: 부호 · n일 전 · n주 전 · 조사.
  - 서비스 DTO 어댑터: `inventoryHistoryInputFromQuery`·`inventoryLastScanAt`.
- **`lib/ui/inventory/inventory_history_charts.dart`(새)**: 그림 둘. **키트 승격 후보**다(W-Data-Widgets `LineTrend` · `DivergingBars`). 키트는 Lane A 몫이라 고치지 않았다.
  - `InventorySparklinePainter`: 시안 svg 높이 92. 바닥선 76, 값 68↔24, 점 r4, 선 2.5, 값 글자는 점 위 9, 시간 글자는 88. 모르는 점은 선을 끊고 이웃 구간을 빗금으로 칠한다. 지금(수동) 점은 속이 빈 원이다.
  - `InventoryChangeBar`: S5 395 × 30. 축 171, 증가는 171부터 · 감소는 169까지, 높이 8 · 위 11 · 둥글기 4, 최장 156, 값 글자는 351~395.
- **`lib/ui/inventory/inventory_controller.dart`**: FE6-a~e · fb10b 로직은 그대로다.
  - `InventoryClockSource`(서비스가 "지금"을 주는 interface, 없으면 기기 시계)와 생성자 선택 인자 `clock`.
  - 로드 끝(보드를 먼저 그린 뒤)에 `_loadHistory`: events를 cursor 끝까지(최대 50쪽), scan_latest를 256개씩 읽는다. 같은 계정 · 같은 revision이면 다시 읽지 않는다. 이력 revision이 상태 revision과 다르면 버리고 안내한다.
  - `refreshIfChanged`: summary revision만 보고 다르면 `load`.
  - 집계 메모(`kpiDeltas`·`sparklineFor`·`netChanges`·`forecasts`): 보드 · 이력이 바뀔 때만 다시 센다.
- **`lib/ui/inventory/inventory_workspace.dart`**: KPI 띠 증감 · 최근 감소 · 마지막 스캔(노랑). 상세 "최근 변화 · 스캔 n회" + 순변화 글자 + 스파크라인 줄(112) 또는 안내 줄(44). metrics `sparklineRowHeight` 등.
- **`lib/ui/inventory/inventory_analysis_sections.dart`**: S5 캡션 · 증감 행 6 · 축선 · 막대 칸 · "이 추세라면" 캡션 · 예측 행 2(`_ChangeLabel`·`_ForecastRow`). 안내는 기록 없음 · 기간 처음 모름 · 읽는 중 · 오류 · 계획 막힘이다.
- **`lib/ui/studio/inventory_studio_layout.dart`**: `InventoryAnalysisMetrics`에 S5 본문 좌표(시안 값)를 더했다. 섹션 rect 변경 0.
- **`lib/ui/pages/inventory_page.dart`**(CRLF 유지, +7줄): 탭을 다시 열 때(active false → true) `refreshIfChanged`를 부른다.
- 테스트 · fixture:
  - `test/inventory_history_fixture.dart`(새, 테스트 파일 아님): 고정 시계 2026-10-05 12:00 UTC. legacy 기준선 위에 회차 · profile별 scan 세션으로 `current_history`를 쌓는다. Mock 생성자가 이력 → 지금 재구성을 검사한다.
  - `test/inventory_fe6a_fixture.dart`:
    - `rio_armed`·`toki_armed` → `rio_battle`·`toki_battle`(학생 id · 엘레프 key, FE6-e 발견 3).
    - 이력(회차 31 · 24 · 17 · 10 · 3일 전), `InventoryClockSource`.
    - 상태 revision 3 → 40(이력 적용 30건을 담기 위해). 상태 wire를 함수로 정리했다.
    - `history:` 인자. 기본은 `owned`를 바꾸지 않았을 때만 이력을 넣는다.
  - `test/inventory_fe6c_fixture.dart`: S5 이력, 계획 밖 보유 항목 2개(상급 활동 보고서 카탈로그 + 640, 밀레니엄 BD (최상급) 보유 40), `InventoryClockSource`, revision 40, `history:` 인자.
  - 새 테스트: `test/inventory_history_test.dart`(33), `test/inventory_history_page_test.dart`(11).
  - 바뀐 동작으로 기대를 고친 기존 테스트:
    - `inventory_page_test.dart` "fixture plan…": 상세 빈 상태 → "최근 변화 · 스캔 4회" · "순변화 +1 · 이전 스캔과 이상 없음" · 스파크라인.
    - `inventory_analysis_page_test.dart` "S4 heatmap…; S5 empty state" → "…; S5 recent changes": 빈 상태 → 주간 · 4주 캡션.
    - `inventory_shell_lazy_test.dart`: 이력 읽기 셈을 더했다. 셸 시작 0, 탭을 열면 events 1 · scan_latest 1, 다시 열면 summary 1만.
  - id 변경으로 키만 바뀐 곳: `inventory_view_model_test`(8곳), `inventory_controller_test`(4), `inventory_page_test`(9), `inventory_shell_lazy_test`(1), `inventory_analysis_page_test`(1), `inventory_review_fb10b_test`(2), `goldens/fe6a_inventory_golden_test.dart`(기다림 키 1줄). 지운 테스트 없음.
- 고치지 않음: `lib/services/**`(읽기만), `lib/ui/kit/**`, golden harness · 다른 golden 테스트, `app_shell.dart`, Lane A 계획 파일 · 테스트, 통계 화면, FE6-d · FE6-e fixture, backend · contracts, `frontend/tool/**`.
  - `inventory_analysis.dart`도 고치지 않았다. S5 seg 주석 "데이터는 FE6-f"가 남아 있고, 기간 길이 · 캡션은 `inventory_history.dart`의 extension에 두었다.

### 처리한 FD

- **FD-041(확정)**: 이력은 수동 수정도 담는다(지금 수량 · 스파크라인 "지금" 점). "지난 스캔" 기준은 scan 점이다. 이력 0 · 1회 → `—`.
- **FD-042(워커 재량, 권장안)**: 그 재화의 scan 점(수량을 아는 것) 3개 이상일 때 최근 구간(읽는 기간 4주) 최소제곱 직선. 미만이면 문구를 숨긴다. FE6-c 발견 6의 FD는 FD-042로 갈음한다.
- **FD-033(확정)**: 스파크라인 · 순증감 · 예측은 한 재화 안에서만, KPI는 품목 수(종). 모르는 수량은 `—` · 빗금 · 끊긴 선이고 0으로 채우지 않는다.
- **FD-031(확정)**: 예측의 필요량은 활성 계획 필요량(부족 계산 행)이다.
- **FD-146(확정)**: 확인 필요 표시는 이력 수량과 별개다(손대지 않음).

### 정한 규칙(근거)

1. **읽는 기간 4주, 한 번 읽기**: 화면에서 가장 긴 기간(S5 4주, 시안 스파크라인 "3주 전 … 지금")만 읽는다. 비용이 기록량(보존 365일)이 아니라 4주 활동량에 묶여, 저장마다 다시 읽어도 가볍다.
2. **재화별 스캔 점 = 그 세션 승인 scope에 그 재화가 든 세션**: 인벤토리 스캔은 scan profile마다 세션이 따로다(카탈로그 profile = 스캔 profile 이름). 다른 profile 세션은 그 재화를 다시 보지 않았다. scan_kind 원문에는 기대지 않는다(불투명 문자열 규칙).
3. **"지난 스캔" = 재화마다 마지막 바로 앞 스캔 점**(FD-041):
   - 전역 `scan: previous`로 하면 profile을 차례로 스캔한 한 자리에서 바로 앞 profile 세션이 기준이 되어 증감이 뜻을 잃는다.
   - 비교는 지금 보유(수동 수정 포함) vs 그 점 수량이고, 둘 다 아는 품목(재화 제외)만 센다.
   - 부족 · 과잉 증감은 그중 계획 재화의 (지금 부족 − 그때 부족) 합이다. 비교 못 하는 품목을 "변화 없음"으로 둔 것과 같은 수다.
   - 필요량은 지금 계획이다(이력은 지난 계획을 남기지 않는다).
   - 4주 안에 2회 미만 스캔한 재화는 비교하지 않는다. 모두 그러면 `—`다.
4. **최근 감소 = 지난 스캔보다 지금 수량이 적은 품목 수**: 재화를 빼고, 3과 같은 기준이다.
5. **마지막 스캔 = 카탈로그 재화를 적용한 가장 최근 scan**(`scan_latest` by_resource_key 최댓값):
   - 지역 달력 날짜 차 "n일 전", 0이면 "오늘". 색은 시안대로 노랑이다.
   - 학생 · 전술 스캔은 세지 않는다. 요약 `last_scan_at`은 모든 종류라 쓰지 않았다.
6. **스파크라인**:
   - 점 = 4주 안 그 재화의 스캔 점(같은 간격). 시간 라벨은 지난 주 수 반올림(`n주 전`, 0 = `지금`)이고, 같은 라벨이 이어지면 마지막 점에만 쓴다.
   - 지금 수량이 마지막 스캔과 다르면 속 빈 `지금` 점을 더한다.
   - 머리는 "최근 변화 · 스캔 n회"(n = 스캔 점 수).
   - 오른쪽 글자: 순변화(끝 점 − 첫 점) 뒤에 다음 중 하나를 붙인다.
     - 추세로 지금 보유가 4주 안에 0 → `n주 뒤 소진 예상`(분홍).
     - 아니면 끝 두 점이 같으면 `이전 스캔과 이상 없음`, 다르면 `이전 스캔 대비 ±n`(회색).
     - 점이 1개면 `비교할 이전 스캔이 없습니다`만.
7. **S5 순증감 = 지금 수량 − 기간 시작 직전 수량**(모든 출처 포함):
   - 기간 시작을 이력이 덮을 때만 센다: `empty`, 남은 첫 적용 ≤ 시작, compacted 기준선 < 시작, 시계 되돌림 없음.
   - |순증감| 큰 6개를 고르고(같으면 증가 먼저 → 카탈로그 순서), 순증감 큰 순(같으면 카탈로그 순서)으로 놓는다.
   - 재화(크레딧 · 엘리그마)는 뺀다. 막대 축척을 뭉개고, KPI 띠와 같은 범위다.
   - 캡션: 1주 "주간 순증감 상위 …", 2 · 4주 "n주 순증감 상위 …". 막대 길이 = 156 × |Δ| / 행 최댓값.
8. **이 추세라면 = 계획 재화 기준**(활성 계획 필요량, 부족 계산 행). 지금 모자라고 추세가 있는 품목만 본다.
   - 줄어들면 "<이름> 부족이 커지는 중" + 위험 칩 `4주 뒤 −<4주 뒤 예상 부족>`. 보유는 0 아래로 내려가지 않는다.
   - 늘어 4주 안에 필요량에 닿으면 "<이름>은/는 곧 충분" + 충분 칩 `<주 올림>주 뒤 0`.
   - 둘 다 있으면 각 1위(예상 부족 큰 것 · 빠른 것), 한쪽만 있으면 그쪽 2개.
   - 근거: 시안 두 문구가 모두 "부족" · "충분"(필요량 비교)이고, 분석 사이드바의 비교 기준 seg가 "계획 요구량"이다. 계획에 없는 재화는 "부족"이 정의되지 않는다.
9. **다시 읽기**:
   - 저장 · 후보 승인은 `load`를 부르고, revision이 바뀌었으니 이력도 다시 읽는다.
   - 탭을 다시 열면 summary의 revision만 보고, 다르면 `load`(다른 탭의 스캔 commit).
   - 이력 응답 revision이 상태와 다르면 섞지 않고 "수량이 바뀌는 사이에 읽어 이력을 맞추지 못했습니다. 탭을 다시 열면 다시 읽습니다."를 보인다.
10. **시계**: 검수 fixture · 테스트는 `InventoryClockSource`로 고정 시각을 준다. 앱 셸 · golden 테스트 파일을 고치지 않고, golden이 실제 날짜에 흔들리지 않게 하기 위해서다. 실제 서비스는 기기 시계다.

### golden 변화 예상(장면별)

- **`inventory`(바뀜)**:
  1. KPI 띠: 부족 재화 옆 `+3 지난 스캔 대비`, 과잉 재화 옆 `−1`, 최근 감소 `—` → `6종`, 마지막 스캔 `—` → `3일 전`(노랑). 값(7종 · 6종 · 1종 · 33%)은 그대로다.
  2. 상세 최근 변화: 머리 "최근 변화" → "최근 변화 · 스캔 4회" + "순변화 +1 · 이전 스캔과 이상 없음". 안내 줄(44)이 스파크라인 줄(112, 0 · 0 · 1 · 1, 3주 전 · 2주 전 · 1주 전 · 지금)로 바뀌어 아래 액션 3개가 66px 내려간다.
  3. id 변경(FE6-e 발견 3): 리오 · 토키 엘레프 아이콘(목록 행 · 상세 머리)과 사용 학생 줄 리오(무장) 초상이 빈 상자에서 실제 그림(`Item_Icon_SecretStone_*_battle` · `rio_battle`)으로 바뀐다.
- **`inventory-all`(바뀜)**:
  - KPI 띠는 `inventory`와 같은 네 곳이 바뀐다.
  - 엘레프 그룹 타일 두 개에 그림이 보인다.
  - 상세(기술 노트 (최상급)) 최근 변화: "최근 변화 · 스캔 4회" + 분홍 "순변화 −19 · 2주 뒤 소진 예상" + 스파크라인 31 · 24 · 18 · 12. 액션이 66px 내려간다.
  - 플라이아웃 · 타일 수량은 그대로다.
- **`inventory-analysis`(바뀜, S5만)**:
  - "변화 기록이 아직 없습니다." 대신 캡션 "주간 순증감 상위 (오른쪽 증가 · 왼쪽 감소)"가 보인다.
  - 6행: 상급 활동 보고서 +120 · 로혼치 사본 T1 +36 · 밀레니엄 BD (최상급) +24 · 트리니티 기술 노트 (최상급) −7 · 시계 T8 설계도 −9 · 게헨나 기술 노트 (최상급) −14. 아이콘 32 × 26, 행마다 사선 −6px. 가운데 축선과 초록 · 분홍 막대.
  - "이 추세라면" + 두 행: 트리니티 기술 노트 (최상급) 부족이 커지는 중(위험 칩 `4주 뒤 −66`) / 밀레니엄 BD (상급)은 곧 충분(충분 칩 `2주 뒤 0`).
  - 열려 있는 밀레니엄 플라이아웃(FE6-c 장면 조작)이 S5 첫 행 막대 · 값 위를 덮는다(발견 사항 3).
  - S1 · S2 · S4 · 사이드바 변화 0. 더한 두 보유 항목은 계획 밖이라 그리지 않는다.
- **`inventory-tiers` · `inventory-analysis-opa`: 변화 0.** FE6-e · FE6-d fixture는 고치지 않았고 이력이 없다(Mock 기록 없음). 티어 화면에는 KPI · 상세 · S5가 없고, 오파츠 확장 완료 장면에서는 S5가 퇴장해 트리에 없다.
- **다른 장면: 변화 0.** 인벤토리 탭은 오프스테이지에서 아무것도 읽지 않는다(셸 지연 테스트로 고정).
- 바뀌는 기준 이미지 3개는 commit.json `whole`에 파일 단위로 넣었다. CF가 `failures/`를 보고 승인한다.

### 미검증 항목

- golden 비교: **미실행**. `inventory`·`inventory-all`·`inventory-analysis`는 바뀌고 `inventory-tiers`·`inventory-analysis-opa`는 변화 0으로 예상한다. CF가 `fe_gate.ps1` · `failures/` 검토 · `-UpdateGoldens`를 한다. 일회성 렌더는 배치 확인만이다.
- 전체 `fe_gate.ps1`(다른 테스트 · 그 밖의 process E2E · `codealmanac validate` · 저장소 전체 `git diff --check`): **미실행**.
- 실제 백엔드에서 인벤토리 화면의 이력 읽기(실제 계정 4주 events 쪽 수 · 속도, 카탈로그 614개 → scan_latest 3번): **미실행**. 서비스 계층 process E2E는 통과했고, 화면 연결은 Mock으로만 보았다.
- 섹션 안 새 요소 ±2px: 시안 좌표를 상대값으로 옮긴 계산과 위젯 테스트(막대 길이 · 축 · 행 간격 · svg 폭 = 줄 − 70)뿐이고 화면에서 재지 않았다. S5 막대 칸은 섹션 위 왼쪽 꼭짓점 기준이다. Studio S5 꼭짓점이 시안보다 1px 왼쪽이라 막대도 1px 왼쪽이다.
- 실제 기록이 compacted · legacy · 시계 되돌림인 계정에서의 안내: 단위 테스트로만 보았다.

### 검수표

| artboard | 여는 방법 | 확인 포인트 |
|---|---|---|
| Inventory | 인벤토리 탭(기본 "부족한 것"). Mock 기본 실행은 계획 · 이력이 없어 `—`와 "아직 변화 기록이 없습니다."만 보인다. 시안 숫자는 fixture로 본다(golden `inventory`, `test/inventory_history_page_test.dart`) | KPI `+3 지난 스캔 대비` · `−1` · 최근 감소 `6종` · 마지막 스캔 `3일 전`(노랑) / 상세 "최근 변화 · 스캔 4회", "순변화 +1 · 이전 스캔과 이상 없음", 스파크라인 점 4개 · 값 글자 · 시간 글자 / 엘레프 아이콘 · 초상 그림 |
| Inventory-All | 사이드바 "전체" → 기술 노트(최상급) 타일 | 상세 "순변화 −19 · 2주 뒤 소진 예상"(분홍), 스파크라인 31 → 12 / 수량을 "수량 직접 고치기"로 바꿔 저장하면 끝에 속 빈 "지금" 점이 붙는가 |
| Inventory-Analysis | 사이드바 "분석" | S5 캡션 · 6행(왼쪽 아이콘 · 이름은 사선을 따라 밀리고 막대 칸은 세로로 정렬) · 축 오른쪽 초록 / 왼쪽 분홍 · 값 글자 / "이 추세라면" 두 행 · 위험 · 충분 칩 / 1주 · 2주 · 4주 seg로 캡션 · 행이 바뀌는가 / 작은 창(1280 × 720)에서 예외 없음 |
| (공통) | 다른 탭에서 스캔 commit 뒤 인벤토리 탭으로 | 다시 열 때 숫자 · 스파크라인이 새 수량으로 바뀌는가(revision이 같으면 다시 읽지 않는다) |

### WIP 보존 확인

- 고친 기존 파일 14개는 착수 때 WIP가 없었다(`git status --short` 빈 줄). 그래서 post 사본 · `post_dir`는 두지 않았다. pre 사본 대비 diff는 이 slice 줄뿐이다(format 되돌림 확인).
- 작업 트리의 다른 미커밋 변경은 고치지 않았다. Lane A `plan_*`·`planning_page_test` 등, 스캐너 `scan_page`·`scan_companion_dock`·`scan_student_review_workspace`, 서비스 `mock_app_service`·`planning_protocol_client`·`process_app_service`·`scanner_service`, `plan_scenario_detail`, 키트 테스트 등이다. git 쓰기는 하지 않았다.

### 발견 사항

1. **시안 견본 값 불일치**:
   - Inventory-All 상세 "18 · 15 · 12 · 12 / 순변화 −6 · 2주 뒤 소진 예상"은 끝 두 점이 같아 어떤 선형 추세로도 2주 소진이 나오지 않는다. fixture는 31 · 24 · 18 · 12(−19 · 2주)로 두었다.
   - S5의 로혼치 +86 · 네브라 −6은 계획 재화의 지금 보유(S2 · S4 값)를 바꾸지 않고는 낼 수 없다. 로혼치 사본 T1 +36 · 트리니티 노트 −7로 두었다.
   - 시안 숫자 그대로인 것: KPI +3 · −1 · 6종 · 3일 전, 엘레프 0 · 0 · 1 · 1, S5 +120 · +24 · −9 · −14, `4주 뒤 −66` · `2주 뒤 0`.
2. **시안 빼기 기호 혼용**: S5 막대 값은 ASCII `-9`, 칩은 `−66`이다. 앱은 모두 U+2212(`−`)로 썼다.
3. **`inventory-analysis` 장면의 밀레니엄 플라이아웃이 S5 첫 행을 덮는다**: FE6-c 장면 조작(플라이아웃 열기) 그대로라 S5 첫 행 막대 · 값이 가려진다. 장면 조작(테스트 파일)은 고치지 않았다. S5를 기준 이미지로 온전히 보려면 CF가 장면을 정하거나 새 장면이 필요하다(새 장면은 Lane A 몫).
4. **상세 머리 "마지막 확인 · 인벤토리 스캔 n일 전 · 인식 성공"**(시안 상세 메타 줄)은 이번 범위(KPI)에 넣지 않았다. 재화별 마지막 스캔은 이미 읽는 `scan_latest` by_resource_key로 그릴 수 있다. "인식 성공"은 이력에 없다(스캐너 결과). 후속 slice 후보다.
5. **스캔 profile ↔ 세션 묶음**: "지난 스캔"을 재화별로 정한 이유다(규칙 3). 한 자리에서 여러 profile을 차례로 스캔하면 전역 "지난 스캔"은 뜻을 잃는다. 통계(FE7-h) · 타이틀 계정 메타의 "스냅샷 n회"도 세션 단위라 같은 문제가 생길 수 있다(FD 후보: 스캔 "자리" 묶음 규칙).
6. **키트 승격 후보**: `InventorySparklinePainter`·`InventoryChangeBar`(W-Data-Widgets `LineTrend` · `DivergingBars`). 통계 B3 재화 변화가 같은 그림을 쓸 것이다.
7. **`inventory_analysis.dart` S5 seg 주석**("데이터는 FE6-f")이 남아 있다. 다음에 그 파일을 고치는 slice에서 한 줄 고치면 된다.
8. 워커 재량 FD는 FD-042 하나(권장안)다. 막는 `열림` FD는 없었다.

### 사본·commit.json

- 착수 사본: `debug/frontend_fe6f/pre/<경로>`(고친 기존 파일 14개). WIP가 없어 post 사본은 없다.
- `debug/frontend_fe6f/commit.json`: slice `fe6f`, `status=false`, modified 14, added 5.
  - `whole = [이 문서, frontend/test/goldens/baseline/inventory.png, inventory-all.png, inventory-analysis.png]`(바뀌는 기존 기준 이미지는 파일 단위).
  - message 근거: Inventory · Inventory-All · Inventory-Analysis artboard, E §1~3 이력 부분, FD-041 · FD-042.
- 인계: `debug/frontend_fe6f/output.md`.

### 다음 행동

- FE6-f 코드는 끝났다. Lane B는 여기서 멈춘다.
- CF: 레인 워커가 모두 멈춘 뒤 gate를 한 번 돌린다.
  - 예상: analyze 0, 일반 테스트 +44(집계 33 + 위젯 11, 셸 지연 테스트는 기대만 늘었다).
  - golden은 `inventory`·`inventory-all`·`inventory-analysis` RED(위 장면별 예측), `inventory-tiers`·`inventory-analysis-opa`를 포함한 다른 장면 변화 0.
  - 승인 뒤 `-UpdateGoldens` → 재비교 → `fe_commit.ps1 -Slice fe6f`.
- 발견 사항 3(장면 조작) · 4(상세 메타 줄) · 5(스캔 자리 묶음 FD) · 6(키트 승격)은 CF 판단을 기다린다.

## FE8-c 착수 기록 (2026-10-13)

- 상태: 진행 중 → **코드 작성 완료**(아래 종료 기록). 범위: 계정 편집기와 초상 고르기를 시안(`Title-Accounts.dc.html` 편집 패널, `Title-Accounts-Portrait.dc.html`)대로 한 패널로 통합한다 — 레일 "수정" → 편집 패널(부유, FD-019), "초상 변경" → 같은 패널이 1000×262 → 1000×850으로 확장되며 6열 초상 그리드, 메타 줄 `보유 n / 전체 · 마지막 스캔 …`(FD-041, 이력 읽기만), FE8-b 발견 5(편집기 해요체 문구), 계정 클러스터 문서 계약 갱신(FD-001·FD-113).
- 시작 커밋(HEAD): `cac83222bac7cc7ae7bb4b71f562b45713c4e10b`.
- 막힘: 대장 "slice별 막힘 요약"에서 FE8-c는 `—`(열림 FD 없음). 관련 FD: FD-019(확정, 부유 패널 예외), FD-041(확정), FD-113(확정), FD-001.
- 고칠 기존 파일과 WIP(`git status --short`, 줄바꿈은 바이트로 셈):
  - `frontend/lib/ui/widgets/account_section_cluster.dart` — WIP 없음, LF
  - `frontend/lib/ui/studio/account_studio_layout.dart` — WIP 없음, LF
  - `frontend/assets/studio_sections/section-account-create-manager.ba-section-studio.json`(typed 문서와 같이 비교되는 Studio 저장 사본) — WIP 없음, LF, 끝 개행 없음
  - `frontend/test/title_page_test.dart` — WIP 없음, LF
  - `frontend/test/account_manager_fe8b_test.dart`(편집기를 여는 기대가 바뀌면) — WIP 없음, LF
  - `almanac/design/section-template-studio.md`(계정 클러스터 절만) — **기존 미커밋 변경 있음**(다른 세션, 파일 끝 "2026-09-08 시나리오 비교" 두 절 +41줄). 계정 절(243~455줄)과 겹치지 않는다. pre/post 사본 + commit.json `post_dir`.
  - `frontend/lib/ui/pages/title_page.dart` — 고칠 필요가 생기면만(WIP 없음, LF). 지금 계획은 변경 0.
- 착수 사본: `debug/frontend_fe8c/pre/<경로>`(위 6개).
- 새 파일(예정): `frontend/test/account_editor_fe8c_test.dart`.
- 고치지 않는 것: `lib/services/**`(이력 `loadRepositoryHistorySummary` 읽기만), `lib/ui/kit/**`, 통계 화면·통계 Studio 문서(Lane A), golden harness·golden 테스트 파일, `app_shell.dart`, `frontend/tool/**`, backend·contracts.

## FE8-c 종료 기록 (2026-10-13, 코드 작성 완료·CF gate 미실행)

편집기와 초상 고르기를 시안대로 한 부유 패널로 합쳤다. 레일 "수정" → 편집 패널(1010,470 1000×262), "초상 변경" → 같은 패널이 1010,270 1000×850으로 펼쳐지며 6열 그리드. 저장 서비스 호출·revision 처리는 그대로다.

### 실행 명령·결과

- `flutter analyze`(frontend 전체): **이슈 0**(info 포함).
- `flutter test <파일>`(각각 따로, 마지막 실행 결과):

  | 파일 | 결과 |
  |---|---|
  | `test/account_editor_fe8c_test.dart`(새) | +9 −0 |
  | `test/title_page_test.dart` | +25 −0 |
  | `test/account_manager_fe8b_test.dart` | +6 −0 |
  | `test/profile_delete_fb2d_test.dart` | +17 −0 |
  | `test/scan_page_revision_test.dart` | +14 −0 |
  | `test/geometry/diagonal_geometry_test.dart` | +5 −0 |
  | `test/kit/diagonal_scrollbar_test.dart` | +8 −0 |
  | `test/settings_page_test.dart` | +10 −0 |
  | `test/repository_profile_panel_test.dart` | +1 −0 |
  | `test/inventory_shell_lazy_test.dart`(이력 요약 호출 셈) | +1 −0 |

  - 고른 근거(grep): `showTitle: true`·`AccountSectionCluster`·`accountStudioDocument`·`portraitScrollbarTrackPoint`·`portraitGridTrajectoryOffset`·`loadRepositoryHistorySummary`. 잠금 충돌 0(재시도 없음). 로그 `debug/frontend_fe8c/final_*.log`(실패 줄만 확인).
  - 중간 실패와 처리:
    - title 1건: 1440×900에서 stucard↔"초상 변경" 80° 선이 깨짐(가로·세로 축척이 달라서) → 구현에 `accountEditorChangeRect`(가로만 맞춤)를 더했다. 기존 규칙 유지.
    - fe8c 2건: 내 테스트의 칸 index 오류(칸 1의 초상은 `items[3]`), 펼친 첫 프레임에 그리드가 없어 고른 초상 위치로 못 옮김 → 진행률 0에서도 그리드를 붙였다.
    - title 1건: 위 수정 뒤 기존 테스트가 따라가던 2행이 화면 밖(궤적 clamp)이 됨 → 테스트가 viewport 안의 행을 따라가게 고쳤다.
  - 실수 1건: 고친 파일 3개에 `dart format`을 파일째 돌려 손대지 않은 줄까지 바뀌었다. pre 사본을 같은 포매터로 돌린 차이를 역패치로 되돌려 이 slice hunk만 남겼다(`title_page_test.dart` +69/−59). `account_studio_layout.dart`는 생성한 부분 외 변화 없음.
- `git diff --check`(고친 파일): exit 0. 새 테스트 파일은 끝 공백 0·끝 개행 하나 확인.
- 미실행: 전체 `fe_gate.ps1`, golden 비교, `codealmanac validate`(CF 몫).

### 고친 파일

- **`frontend/lib/ui/widgets/account_section_cluster.dart`**
  - `_buildEditor` 하나가 접힘·펼침을 모두 그린다(`_buildPicker`·`_portraitChangePath`·`squareAssetImageSideLength` 삭제). 펼침 진행률(`_pickerMotion`, `AppMotion.sectionCurve`)로 짝 rect를 보간한다.
  - 공개 함수: `accountEditorRect`·`accountEditorBounds`·`accountEditorPath`·`accountEditorChangeRect`·`accountPortraitGridMetrics`·`accountPortraitScrollbarTrackPoint`·`accountLastScanText`·`accountEditorMetaText`, 상수 `accountEditorPanelFill`·입력·저장·viewport 색.
  - 패널: 채움 .95 + lifted shadow, 패널에서 텍스처 버튼만 차감. stucard는 목록 행과 같은 학생 카드 평행사변형(흰 1.5px). 입력 path 채움 .55 + 외곽선(포커스 #f2b3ef 2.4 / 평소 rgba(56,81,107,.9) 1.6, `FocusNode`로 바꿈), TextField 16 w600(작은 창은 축척).
  - 펼침: "고르는 중"(분홍 3.2, 다시 누르면 닫기), 뒤로는 흐려져 사라짐, 닫기·저장·머리 `초상 고르기` + (i)(`InfoPopover`)는 나타남. 전이 중 버튼은 누르지 않는다. 그리드는 펼친 자리에 고정하고 보간되는 패널 path로만 드러낸다.
  - 그리드: 6열, 칸 112×90.67, 간격 14·17.33, stucard + 98% 초상, 선택 #ff72b6 1.88, 흰 1px. 스크롤바는 공용 표준(썸 #e5a0ea) + 공용 포그, 레일 가로 5.94·위아래 10. 펼칠 때 고른 초상 행이 밖이면 가운데로 옮긴다.
  - 메타 줄: `_load`가 state와 함께 `loadRepositoryHistorySummary`(128개씩)를 읽어 `_lastScans`에 둔다. 실패하면 비우고 목록은 그대로다. 삭제 때 `_forgetDeletedProfile`이 그 ID를 뺀다(fb2d 캐시 표 유지). "지금"은 서비스가 `InventoryClockSource`면 그 시각, 아니면 기기 시계.
  - `_DiagonalScrollbar`: 초상 전용 썸 #8edcff 스타일을 없애고 표준만 쓴다(`trackPoint` 인자 추가). 안 쓰게 된 `_PathOutline` 삭제.
  - 문구: 입력 안내 `계정명을 입력하세요` → `계정명을 입력하십시오`(FE8-b 발견 5), 라벨 `계정명 :` → `계정명`, `변경` → `초상 변경`.
- **`frontend/lib/ui/studio/account_studio_layout.dart`**·**`frontend/assets/studio_sections/section-account-create-manager.ba-section-studio.json`**: 아래 배치 표. 같은 Python 생성기(값 = 시안 px)로 둘을 만들어 typed ↔ JSON 비교 테스트가 그대로 통과한다. JSON은 LF·끝 개행 없음 유지.
- **`frontend/test/title_page_test.dart`**(25 → 25, 지운 테스트 없음, 고친 테스트 3):
  - `account manager uses Studio paths …`: 입력 rect·stucard Studio rect·80° 선, 펼침 중간 프레임 패널 높이(접힘과 펼침 사이)·편집기 이동 없음·예외 0, 펼친 패널 bounds, 그리드 폭 = container-8 bounds, 6열, 선택 두께 1.88/90.67, 스크롤 추적 행.
  - `nested account sections exit independently`: 펼침에 편집기 뒤로 없음, "고르는 중" 재클릭 = 닫기, 관리 레일 뒤로로 타이틀 복귀.
  - `account editor text remains inside Studio paths in a small window`: `초상 변경`, 입력 path는 `accountEditorPath`.
- **새 `frontend/test/account_editor_fe8c_test.dart`**(9): Studio 값 ↔ 시안 px(패널 ±1, 요소 ±2), 그리드 metrics·레일, 마지막 스캔 문구, 접힘 화면(문구·색·두께·포커스·메타 줄·요약 1회), 펼침 화면(위치·문구·(i)·그리드 첫 칸·행 이동·선택·스크롤바·포그·중간 프레임 예외 0), 닫기 = 버림·"고르는 중" = 닫기·펼침 저장 = draft만·편집기 저장 = `updateProfile` 1회, 고른 초상 스크롤, 이력 실패·기록 없음 = '—', 1280×720·480×270 펼침·접힘 예외 0과 글자 ⊂ 버튼.
- **`almanac/design/section-template-studio.md`**(계정 클러스터 절만, 아래 문서 갱신).
- 변경 0: `title_page.dart`(고칠 필요 없음), `account_manager_fe8b_test.dart`(pre 사본만 있고 내용 같음 — commit.json에 넣지 않았다).

### 처리한 FD

- **FD-019(확정)**: 편집 패널(접힘·펼침)은 어느 경계에도 붙지 않는 부유 패널 예외, 진입 80°·퇴장 260°. 펼침은 방향 이동이 아니라 rect 보간.
- **FD-041(확정)**: 메타 줄 "마지막 스캔"은 이력 요약의 프로필별 `last_scan_at`. 없으면 '—'.
- **FD-113(확정)**: FE8-c 몫(편집 패널 1000×262·입력 fill + 분홍 포커스·초상 6열·편집 패널 확장) 반영. Studio JSON 재저장.
- **FD-001**: 패널 채움 .95·viewport .45·입력 .55는 공용 표면 .76의 예외로 시안을 따랐다. 문서도 시안으로 고쳤다.
- 막힘 요약: FE8-c `—`. 워커 재량 FD 없음.

### 정한 규칙

1. **마지막 스캔 = 계정의 모든 종류 scan 적용 중 가장 최근**(`repository.history.summary` `last_scan_at`). FE6-f의 "카탈로그 재화 scan"(`scan_latest` by_resource_key)과 다르다.
   - 근거: FE6-f 규칙은 인벤토리 탭 지표(재화 수량)의 기준이다. 계정 메타 줄은 계정 전체 요약이고 시안 문구에 종류 한정이 없다("마지막 스캔 어제 21:40"). FD-041 "마지막 스캔 시각은 같은 이력에서 프로필별로 유도", A §3.4 "프로필별 마지막 스캔 시각"과 맞는다.
   - 한 요청(최대 128 프로필)으로 모든 계정을 읽어 목록 로드 비용이 거의 늘지 않는다. scan_kind 원문에는 기대지 않는다.
2. **표기**: 지역 달력 날짜 차 0 `오늘 HH:mm`, 1 `어제 HH:mm`(시안), 2 이상 `n일 전`(FE6-f와 같은 말), 지금보다 뒤(시계 차이) `M/d HH:mm`. 모르면 '—'. 보유 수를 못 읽으면 `보유 — / 265`, 전체를 모르면 `/ —`.
3. **펼침 저장 = 편집 중인 초상에만 반영**(지금과 같은 의미). 저장소 쓰기는 접힌 편집기의 저장 한 곳이다.
4. **"고르는 중" 다시 누름 = 닫기**(버림). 시안은 누른 상태만 그렸다.
5. **고른 초상 자동 스크롤**: 펼칠 때 고른 초상 행이 viewport 밖이면 가운데로 옮긴다(267명 중 기본 `hasumi`는 10번째 행).
6. **입력 자동 포커스 없음**: 시안 접힘은 포커스(분홍) 상태를 그렸지만, golden에서 깜빡이는 커서를 고정할 수 없어(harness·golden 테스트는 고치지 않는다) 열 때 포커스를 주지 않는다. 누르면 분홍이다(발견 3).

### 섹션 배치 표 (기준 viewport 2560×1392)

| 대상 | Studio | px | 시안 | 차이 |
|---|---|---|---|---|
| 섹션 1(접힘 감싸기) | (37,32,37,19) | 986.7,464 986.7×275.5 | 패널 1010,470 1000×262 | 감싸는 표지(아래 예외) |
| 섹션 4(펼침 감싸기) | (37,18,37,60) | 986.7,261 986.7×870 | 패널 1010,270 1000×850 | 감싸는 표지 |
| 패널 접힘 container-20 | 섹션 1 비율 | 1010,470 953.8×262(사선 포함 1000) | 1010,470 1000×262 | 0(그린 path bounds는 r16이라 ≤3px 안쪽) |
| 패널 펼침 container-21 | 섹션 4 비율 | 1010,270 850.1×850(사선 포함 1000) | 1010,270 1000×850 | 0 |
| stucard 4 / 22 | | 1068.81,501.76 / 1172.49,301.76 176×142.48 | 같음 | 0 |
| 초상 변경 3 / 고르는 중 23 | | 1058.3,660 / 1162,460 158.6×44 | 같음 | 0(다른 비율 창은 가로만 80° 정렬) |
| 계정명 4 / 10 | | 1331,506 / 1434,306 | `.ihdr` 왼쪽 위 | 0 |
| 입력 8 / 11 | | 1310.8,530 569.9×56 / 1414.5,330 535.1×56 | 같음 | 0 |
| 메타 줄 9 / 12 | | 1311,598 / 1414,398 | `.mut` 왼쪽 위 | 0 |
| 뒤로 6 · 저장 7 | | 1691.3,662 · 1819.3,662 118×50 | 같음 | 0 |
| 초상 viewport 8 | | 1057.6,570 859.5×450 | 같음 | 0 |
| 닫기 9 · 저장 10 | | 1587.6,1050 · 1715.6,1050 118×50 | 같음 | 0 |
| 머리 13(`초상 고르기` + (i)) | | 1152,530 126×24, (i) 1254,530 24×24 | 1152,536 글자 · 1254,530 | 0 |

- **±1px 예외**: 시안 패널의 위·아래 y(470·732·270·1120)가 grid 줄(14.5px) 사이라 섹션 rect로는 ±1px가 안 된다(최선 −6px). FE8-b 관리 화면(섹션 5 표지 + 보이는 표면 container-11)과 같이, 섹션 1·4는 grid에 맞춘 감싸는 rect로 두고 보이는 패널을 컨테이너 20·21(소수 비율, 0px)로 그렸다. Studio placement는 0~1이어야 해서 섹션이 짝 요소를 모두 감싼다.

### 문서 갱신 (`section-template-studio.md`, FD-001 대장 "갱신" 칸)

- sources: `account-studio-document` 경로 `release/…`(git 밖, 이전 배치) → `frontend/assets/studio_sections/section-account-create-manager.ba-section-studio.json`. 새 source `account-editor-tests` → `frontend/test/account_editor_fe8c_test.dart`. **source 경로가 바뀌었다 — CF gate의 codealmanac validate 대상.**
- 「Title 계정 생성·관리 클러스터 적용」 문단: FE8-b 몫(관리 섹션 표면 없음·목록 .9·레일 74·22px·행 그라데이션·진행 막대·추가 = 모달)과 FE8-c 몫(부유 편집 패널·펼침 보간·짝 표·닫기/저장 의미·입력 path 채움과 외곽선·메타 줄·6열·stucard 선택선·표준 스크롤바와 포그)으로 바꿨다. IME·tight width·궤적·Space 단축키 규칙은 그대로.
- 「요소별 작업 스타일」: Section 1·4 표를 "펼치는 편집 패널" 표 하나로, Section 5 표를 시안 값으로.
- 「시행착오」: 맨 앞에 "FE8-b·FE8-c가 바꾼 규칙은 위 절이 이긴다" 한 문단. 표는 기록으로 둔다.
- 파일 끝 다른 세션 WIP(2026-09-08 두 절)는 그대로(아래).
- FE8-a 발견 1(Title 관련 문단·로고 띠 .93 예외)은 계정 절 밖이라 이번에도 손대지 않았다.

### golden 변화 예상 (실행하지 않음)

- **`account-editor`**: 편집 패널 전체가 바뀐다 — 위치·크기(853,464 853×232 → 1010,470 1000×262), 채움 .76 → .95, 반경 16, stucard(학생 카드 모양 + 흰 외곽선), `초상 변경`(13 w700, 새 자리), 라벨 `계정명`(파란 점 `.ihdr`, 이전 `계정명 :` 22px), 입력 path 채움 .55 + 평소 외곽선 .9 1.6, 이름 16 w600, 메타 줄 `보유 0 / 2 · 마지막 스캔 —`(golden mock = 기본 Mock: 학생 0·카탈로그 2·이력 없음), 뒤로·저장 새 자리, 저장 분홍 외곽선·시작 버튼 텍스처, 버튼 외곽선. 뒤의 관리 화면은 그대로.
- **`account-picker`**: 별도 섹션 4(720,725 853×667, 4열, 썸 #8edcff) 대신 펼친 패널 1010,270 1000×850. `고르는 중` 분홍 3.2, 머리 + (i), 6열 그리드가 `hasumi` 행(10번째 행)을 가운데로 스크롤한 상태, 선택 분홍 1.88, 표준 썸 #e5a0ea, 아래 포그, 닫기·저장. 관리 화면은 그대로.
- 변화 0: `title`(title_page 변경 0), `account-manager`(관리 화면 렌더 변경 0 — 스크롤바 스타일·포그는 전과 같은 표준·true), `account-new`(모달 뒤 관리 화면 그대로), `home`과 다른 탭 장면(타이틀·클러스터를 거치지 않음). 이 밖의 장면이 RED면 예측이 틀린 것이니 갱신하지 말고 알려 달라.
- 참고: 장면 조작(golden 테스트 파일)은 바꿀 필요가 없었다. `account-picker`가 기다리는 `account-picker-section` 표지를 펼침 상태에 그대로 둔다.
- commit.json `whole`: 이 문서, `account-editor.png`, `account-picker.png`.

### 미검증 항목

- 전체 `fe_gate.ps1`·golden 비교·`codealmanac validate`·저장소 전체 `git diff --check`: **미실행**(CF 몫).
- 실제 백엔드에서 `repository.history.summary`를 타이틀에서 읽는 경로: **미실행**(process E2E 없음, Mock만). 읽기 전용이고 FB-2b 서비스 테스트는 기존 통과분이다.
- 실제 앱 눈 검수(아래 표): **미실행**. 버리는 스크래치 테스트로 2560×1392 접힘·펼침 두 장면을 한 번씩 렌더해 배치만 눈으로 확인했다(저장소 밖 임시 폴더, golden 장면 아님).
- 경기천년제목 800(`.ihdr`)은 등록 굵기가 500뿐이라 합성 굵게일 수 있다(FE8-b와 같음).
- Windows IME 조합 중 펼침·접힘 전환: 같은 TextField가 유지되도록 했지만 실제 IME로는 **미검증**.

### 검수표 (artboard `Title-Accounts.dc.html` 편집 패널 · `Title-Accounts-Portrait.dc.html`)

앱에서 여는 방법: mock 모드(`--dart-define=BA_PLANNER_USE_REAL_BACKEND=false`), 2560×1440 모니터 최대화. 타이틀 → 설정(톱니) → 계정 관리 → "수정" → "초상 변경". mock 기본 계정은 이력이 없어 메타 줄 마지막 스캔이 `—`다(시안 `어제 21:40`은 테스트 fixture로만 재현, 발견 6).

| # | 확인 포인트 | 코드 |
|---|---|---|
| E1 | "수정"을 누르면 편집 패널이 오른쪽 아래(80°)에서 들어와 1010,470 1000×262 평행사변형(모서리 16, 거의 불투명 .95, 그림자)으로 선다. "수정" 레일이 분홍 3.2 | `account-editor-section-shadow` |
| E2 | 왼쪽 stucard 176×142가 학생 카드 모양 + 흰 외곽선, 아래 `초상 변경` 버튼과 중심이 80° 선 위 | `account-editor-portrait`, `account-change-portrait` |
| E3 | `계정명` 머리(파란 점) 아래 입력 569.9×56: 어두운 채움, 평소 외곽선은 회청색, 누르면 분홍 2.4 | `account-name-input-outline` |
| E4 | 입력 아래 `보유 n / 전체 · 마지막 스캔 —`(12px 회색, 한 줄) | `account-editor-meta` |
| E5 | 오른쪽 아래 `뒤로`(회청 외곽선)·`저장`(분홍 외곽선) 118×50 | `account-editor-back`·`-save` |
| P1 | `초상 변경`을 누르면 같은 패널이 위(270)·아래(1120)로 늘어나며 1000×850이 된다. 편집기가 빠졌다 들어오지 않는다 | `_pickerMotion` |
| P2 | 버튼이 `고르는 중` + 분홍 3.2로 바뀌고, 위쪽 요소(stucard·입력·메타 줄)가 패널 사선을 따라 오른쪽으로 옮겨 간다 | 짝 rect 보간 |
| P3 | `뒤로`가 흐려져 사라지고 아래 `닫기`·`저장`(1587.6/1715.6, 1050)이 나타난다 | `account-picker-close`·`-save` |
| P4 | `초상 고르기` 머리 + (i)(누르면 "학생 초상 중 하나를 고릅니다. 저장해야 계정 카드에 반영됩니다.") | `account-picker-info` |
| P5 | viewport(1057.6,570 859.5×450, 어두운 채움 + 얇은 외곽선) 안 6열 그리드, 4행이 보이고 행마다 19px씩 왼쪽(80° 계단) | `account-portrait-grid` |
| P6 | 지금 초상 칸이 분홍 1.88 외곽선이고, 처음 열면 그 행이 보이게 스크롤되어 있다 | `_revealSelectedPortrait` |
| P7 | 오른쪽 사선 스크롤바(분홍 썸), 아래 포그. 휠·끌기·키보드로 행이 80° 사선으로 움직인다 | `account-portrait-*` |
| P8 | 다른 초상을 누르고 `닫기`(또는 `고르는 중`) → 원래 초상 그대로 접힌다. 다시 골라 `저장` → 접힌 stucard만 바뀌고 계정 카드는 아직 그대로 | `_closePicker` |
| P9 | 접힌 패널 `저장` → 패널이 260°로 나가고 목록 행 초상·이름이 바뀐다 | `_saveEditor` |
| P10 | 펼친 채 관리 레일 `뒤로` → 접힘·패널·관리 화면이 차례로 나가고 타이틀로 | `_back` |
| P11 | 창을 작게(예: 1280×720) 해도 펼침·접힘 중 글자가 버튼 밖으로 넘치지 않는다 | small-window 테스트 |

### WIP 보존 확인

- `almanac/design/section-template-studio.md`(기존 미커밋 변경 있음): pre 사본과 끝 내용의 차이는 앞머리 sources(50줄 부근)와 계정 절(248~427줄)뿐이다. 파일 끝 45줄(다른 세션 WIP "2026-09-08 시나리오 비교 UI 정리"·"후속" 두 절)은 pre와 바이트까지 같다. LF·끝 개행 하나 유지. 끝 사본 `debug/frontend_fe8c/post/almanac/design/section-template-studio.md`.
- 나머지 고친 파일은 WIP 없음, LF 유지(JSON은 끝 개행 없음 유지).
- 다른 WIP 파일(서비스·스캔·통계 테스트 등 작업 트리의 `M` 파일)은 수정 0.

### 발견 사항

1. Lane A 키트 요청(고치지 않음): `lib/ui/kit/diagonal_scrollbar.dart` 머리 주석 "계정: 포그가 없고 썸이 #8edcff"는 이제 틀리다(계정 화면 둘 다 표준 + 포그).
2. "지금" 시계로 `InventoryClockSource`(인벤토리 이름)를 재사용했다. 화면 공용 시계 interface(예: `AppClockSource`)로 올리는 것은 서비스·키트 몫이라 요청만 한다.
3. 시안 접힘 입력은 포커스(분홍) 상태다. 앱은 열 때 자동 포커스하지 않는다(정한 규칙 6). 자동 포커스를 원하면 golden 장면에 `debugDeterministicCursor`가 필요하다(harness·`fe1g` 테스트는 Lane A 몫).
4. (i) 문구 "저장해야 계정 카드에 반영됩니다"는 펼침 `저장`이 곧바로 저장소에 쓰는 것으로 읽힐 수 있다. 지금은 프롬프트대로 "편집 중인 값에 반영 → 접힌 패널 저장"의 두 단계다. 한 번에 저장으로 바꿀지는 CF 판단.
5. 펼칠 때 자동 스크롤 때문에 golden `account-picker`는 시안(첫 4행, 15번째 선택)과 다른 행이 보인다. 시안 선택 위치는 예시 데이터다.
6. 검수용 시안 수치(`보유 217 / 265 · 마지막 스캔 어제 21:40`)는 기본 Mock(`lib/services`, 이 slice 범위 밖)에 이력·학생이 없어 앱에서는 재현되지 않는다. 테스트 fixture(`account_editor_fe8c_test.dart`)만 재현한다. 필요하면 Mock 검수 fixture를 서비스 쪽에 요청한다.
7. 메타 줄은 못 읽은 보유 수를 `—`로, 목록 행은 `읽지 못함`으로 쓴다(프롬프트 "없으면 '—'"). 통일 여부는 CF 판단.
8. `release/section-account-create-manager.ba-section-studio.json`(git 밖)은 더 오래된 배치다. Studio에서 같은 문서를 열려면 `frontend/assets/studio_sections/`의 추적 사본을 연다(FE8-b 발견 1과 같음).
9. `account_manager_fe8b_test.dart`는 pre 사본을 만들었지만 고칠 필요가 없었다(내용 같음, commit.json에서 뺐다).

### 사본·commit.json

- 착수 사본: `debug/frontend_fe8c/pre/<경로>`(6개, 그중 `account_manager_fe8b_test.dart`는 변경 없음).
- 끝 사본: `debug/frontend_fe8c/post/<경로>`(고친 기존 파일 5개와 새 테스트 1개).
- `debug/frontend_fe8c/commit.json`: slice `fe8c`, `status=false`, `post_dir`, modified 5, added 1, `whole = [이 문서, account-editor.png, account-picker.png]`. message는 ASCII(근거: Title-Accounts·Title-Accounts-Portrait artboard, A §3·§5, FD-019·FD-041·FD-113).
- 인계: `debug/frontend_fe8c/output.md`.

### 다음 행동

- FE8-c 코드는 끝났다. Lane B는 여기서 멈춘다.
- CF: Lane A(FE7-a)와 이 slice가 모두 멈춘 뒤 gate 1회(예상: analyze 0, 일반 테스트 녹색, golden RED = `account-editor`·`account-picker` 2건) → `failures/` 검토 → `-UpdateGoldens` → 재비교 → `fe_commit.ps1 -Slice fe8c`(`section-template-studio.md`는 3-way 병합, WIP hunk와 떨어져 있다).
- 발견 사항 1·2·3·4·6·7은 CF 판단을 기다린다.

## FE8-d 착수 기록 (2026-10-13)

- 상태: 진행 중 → 코드 작성 완료(아래 종료 기록).
- 범위: 앱 전역 게임 창 연결 상태(`connectedTarget`)와 헤더 칩(FD-116 (a), FD-117, FD-148 중 "백엔드 끊김 > 게임 창 연결"만, FD-115 칩 색). 창 선택 패널·교체 이펙트(FE8-e), 스캔 진행 겹침(FE8-f2), 헤더 지표·초상 모양(FD-115 나머지)은 범위 밖.
- 막힘 확인: 막힘 요약의 FE8-d 행 FD-116은 확정(2026-10-06). 막는 '열림' FD 없음.
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `75943ffcd529d57ce2de7cea703f32f93085ec96`.
- 고칠 기존 파일과 WIP(`git status --short <경로>`), 착수 사본 `debug/frontend_fe8d/pre/<v7 기준 경로>`:

  | 파일 | WIP | 줄바꿈 | 고칠 곳 |
  |---|---|---|---|
  | `frontend/lib/ui/app_shell.dart` | 없음 | LF | 컨트롤러 소유·전달, 헤더 배지 → 새 칩(최소 diff) |
  | `frontend/lib/ui/pages/scan_page.dart` | **있음**(` M`) | LF | 선택 창을 컨트롤러와 공유(생성자·initState·dispose·목록 새로고침·드롭다운·최근 기록 열기). WIP hunk와 떨어진 줄만 |
  | `frontend/test/widget_test.dart` | 없음 | CRLF | 헤더 칩 문구 기대(백엔드 "연결됨" → 게임 창 칩) |

- `frontend/lib/ui/app_section.dart`는 고치지 않는다(필요 없음). `frontend/lib/services/scanner_service.dart`(WIP 있음)는 읽기만 한다.
- 새 파일(예정): `frontend/lib/ui/scan/connected_target_controller.dart`, `frontend/lib/ui/scan/header_connection_chip.dart`, `frontend/test/connected_target_fe8d_test.dart`.
- WIP가 있는 `scan_page.dart`는 끝 사본도 `debug/frontend_fe8d/post/`에 두고 commit.json에 `post_dir`를 적는다. WIP는 지우거나 정리하지 않는다.

## FE8-d 종료 기록 (2026-10-13, 코드 작성 완료·gate 미실행)

앱 전역 게임 창 연결 상태(`ConnectedTargetController`)와 머리글 연결 칩을 만들었다. 셸이 컨트롤러 하나를 소유하고, 스캔 화면의 대상 창 선택과 머리글 칩이 같은 값을 읽고 쓴다.

### 실행 명령·결과

모두 `frontend` 폴더에서 실행했다. golden·process E2E·전체 gate는 돌리지 않았다.

- `flutter analyze`: **No issues found**(0, info 포함). 마지막 실행은 모든 편집 뒤다.
- `flutter test test/<파일>.dart`(파일마다 따로, `--reporter expanded`, 로그 `debug/frontend_fe8d/logs/`): 21개 파일 모두 통과, 실패 0.

  | 파일 | 통과 | 실패 |
  |---|---:|---:|
  | `connected_target_fe8d_test.dart`(새) | 8 | 0 |
  | `widget_test.dart`(기대 2줄 수정) | 16 | 0 |
  | `home_app_shell_test.dart` | 1 | 0 |
  | `home_page_test.dart` | 5 | 0 |
  | `scan_page_test.dart` | 17 | 0 |
  | `scan_page_revision_test.dart` | 14 | 0 |
  | `scan_page_pause_fb10a_test.dart` | 8 | 0 |
  | `mock_scanner_service_test.dart` | 4 | 0 |
  | `scanner_protocol_client_test.dart` | 6 | 0 |
  | `scanner_target_metadata_fb4_test.dart` | 19 | 0 |
  | `scanner_pause_fb10a_test.dart` | 39 | 0 |
  | `account_editor_fe8c_test.dart` | 9 | 0 |
  | `account_manager_fe8b_test.dart` | 6 | 0 |
  | `growth_calculator_view_test.dart` | 24 | 0 |
  | `inventory_shell_lazy_test.dart` | 1 | 0 |
  | `profile_delete_fb2d_test.dart` | 17 | 0 |
  | `section_template_studio_test.dart` | 15 | 0 |
  | `statistics_app_shell_test.dart` | 2 | 0 |
  | `student_filter_followups_test.dart` | 4 | 0 |
  | `student_filter_modal_test.dart` | 7 | 0 |
  | `title_page_test.dart` | 25 | 0 |

  고른 기준: `test/` 중 golden 폴더를 빼고 `BAPlannerApp(`·`AppShell(`·`ScanPage(`·연결 칩 문구를 쓰는 파일 전부, 그리고 대상 목록을 다루는 스캐너 DTO·Mock 테스트. 잠금 충돌은 없었다.
- fe_commit 병합 모의(읽기 전용, `git merge-file -p`를 표준 출력으로): 고친 기존 파일 3개 모두 HEAD·pre·끝 내용 병합에 충돌이 없다. `widget_test.dart`는 줄바꿈을 맞춘 뒤(fe_commit의 `Norm`과 같음) 충돌이 없다.

### 고친 파일

- **`frontend/lib/ui/scan/connected_target_controller.dart`(새)**: `ConnectedTargetController`(ChangeNotifier).
  - API:
    - `target`: 지금 연결된 `ScannerTarget`(FB-4의 client 크기·game 포함)
    - `connect`, `disconnect`(사용자 해제)
    - `updateTargets`(새 목록 반영), `refresh`(목록 한 번 읽기)
    - `lastRelease`: 해제 사유 enum `ConnectedTargetRelease`(user·targetMissing·targetClosed·backendDisconnected). FE8-e 해제 연출용이다.
  - 백엔드 상태를 듣는다. connected에서 벗어나면(끊김·재시작) 해제한다. 다시 붙어도 연결은 돌아오지 않는다.
  - 연결된 동안 백엔드가 연결되어 있으면 창 목록을 5초마다 확인한다(`pollInterval`). 미연결이거나 백엔드가 끊겼으면 타이머가 없다. 목록 읽기 실패는 연결을 바꾸지 않는다.
  - 최소화·미지원은 해제하지 않고 창 정보만 바꾼다. 같은 창·같은 정보면 알리지 않는다.
  - 셸의 서비스가 바뀌면 `rebindService`로 다시 묶고 해제한다.
- **`frontend/lib/ui/scan/header_connection_chip.dart`(새)**: 머리글 칩.
  - `HeaderConnectionChipState.resolve(backend, target)`가 우선순위를 정한다: 백엔드 끊김(빨강 `백엔드 끊김`) > 백엔드 연결 중(주황 `백엔드 연결 중`) > 게임 창 연결됨(녹색) / 연결 안 됨(회색).
  - 문구 `connectedTargetLabel`: `연결됨 · Blue Archive · 2560×1440`. game을 모르면 이름 없이 크기만(`연결됨 · 1600×900`), 크기를 모르면(둘 중 하나라도) `—`.
  - 모양은 시안 `.conn`을 따른다:
    - 여백 6/10(선 1px 포함), 반경 999, 점 8·간격 7, 12px w600
    - 녹색: #58d6a7, 채움 .12, 선 .55
    - 회색: 글자 #c3cfdb, 점 #9eb0c2, 채움 .12, 선 .45
    - 빨강·주황은 녹색과 같은 짜임
  - 게임 창 칸만 누를 수 있다(`header-connection-chip-button`, `KitPressable`). 백엔드 칸은 복구 배너가 맡는다.
  - 칩 폭 최대 340, 글자 한 줄·말줄임.
- **`frontend/lib/ui/app_shell.dart`(+25 −42)**: 아래 "app_shell diff".
- **`frontend/lib/ui/pages/scan_page.dart`(+65 −4, WIP 위)**: 선택 창을 컨트롤러와 공유한다. 컨트롤러가 없으면(단독 테스트) 예전과 같다.
  - 생성자에 선택 인자 `connectedTarget`을 더했다.
  - initState·didUpdateWidget에서 리스너를 붙이고 연결 대상을 받는다(`_adoptConnectedTarget`). `_targetId`를 맞추고, 목록에 없으면 넣고, 같은 id면 새 창 정보로 바꾼다. 스캔 화면이 다시 만들어져도(계정 변경 key) 연결이 그대로 보인다.
  - 목록 새로고침(`_refreshPreparation`)이 `updateTargets`를 부른다(사라진 창 해제).
  - 드롭다운 선택은 `_chooseTarget` → `connect`다. 화면 선택은 리스너가 맞춘다.
  - 최근 기록 열기: 기록의 창이 목록에 있으면 그 창에 연결하고, 없으면 지금 연결을 그대로 둔다(예전: 선택을 비움).
- **`frontend/test/widget_test.dart`(+4 −2)**: `mock state is reflected without replacing widgets`의 칩 기대를 바꿨다.
  - 처음: `연결됨`(백엔드) → `연결 안 됨`(게임 창 미연결).
  - 끊김 뒤: `연결 안 됨` → `백엔드 끊김`.
  - 테스트 이름과 나머지 기대(`42명`·`9999명`)는 그대로다. 옛 기대는 백엔드 배지 사양이었고, FD-117로 바뀌었다.
- **`frontend/test/connected_target_fe8d_test.dart`(새, 8건)**:
  - 칩 상태 3건: 문구(game·크기 모름 4가지), 우선순위·색(시안 값 직접 비교), 좁은 칸에서 한 줄·말줄임.
  - 컨트롤러 2건:
    - 전이 전체(아래 표)
    - 주기 확인: 미연결·백엔드 끊김이면 읽지 않음, 실패는 유지, 사라짐 → 해제 뒤 확인 멈춤
  - 셸 3건:
    - 스캔 탭 선택 → 모든 탭 칩(1280×720, 넘침 없음) → 칩을 누르면 스캔 탭
    - 다른 곳(FE8-e 홈 패널 자리)에서 쓴 값이 스캔 선택·시작 버튼·칩에 보이고, 해제도 같이 보인다
    - 창 사라짐(주기 확인) → 미연결, 백엔드 끊김 → 빨강·누를 수 없음 → 다시 붙으면 미연결
- `frontend/lib/ui/app_section.dart`·`home_page.dart`·`lib/services/**`는 고치지 않았다.

### app_shell diff (+25 −42, 이유)

- import 2줄(새 컨트롤러·칩).
- `_AppShellState`:
  - `late final _connectedTarget = ConnectedTargetController.forService(widget.service)`(주석 1줄)
  - dispose 1줄
  - 서비스 교체(didUpdateWidget) 때 `rebindService` 1줄
- `ScanPage(... connectedTarget: _connectedTarget)` 1줄.
- `_CompoundPageHeader`·`_AppHeader`에 `connectedTarget` 인자·필드를 전달한다. `_AppHeader`에는 `onOpenTargetPicker`도 더했다. 칩을 누르면 `onSelected(AppSection.scan)`이다(창 선택 패널 FE8-e 전, 주석 1줄).
- `_ConnectionBadge(connection: ...)` 한 줄 → `HeaderConnectionChip(...)` 5줄. 쓰이지 않게 된 private `_ConnectionBadge` 클래스 41줄을 지웠다(남기면 analyze `unused_element`).
- 이유:
  - FD-117 (a)대로 칩은 같은 자리의 한 칩이고, 백엔드 상태와 게임 창 연결을 함께 봐야 한다.
  - FD-116 (a)대로 연결 상태는 앱 전역이다. 셸이 소유해야 스캔 화면과 칩이 같은 값을 쓴다.
  - `app_section.dart`는 고칠 필요가 없었다.

### 연결 상태 전이표 (FD-116 (a))

| 지금 | 사건 | 다음(`lastRelease`) | 칩 |
|---|---|---|---|
| 미연결 | 스캔 탭에서 창 고름(또는 `connect`, FE8-e 패널 자리) | 연결됨 | 녹색 `연결됨 · Blue Archive · 2560×1440` |
| 연결됨 | 같은 창을 다시 고름 / 같은 정보의 목록 | 그대로(알림 없음) | 그대로 |
| 연결됨 | 목록(5초 주기·스캔 새로고침)에 같은 창, 정보 바뀜(최소화 등) | 연결됨(창 정보 갱신) | 녹색, 크기 모르면 `—` |
| 연결됨 | 목록에서 사라짐 | 미연결(`targetMissing`) | 회색 `연결 안 됨` |
| 연결됨 | 목록에서 `closed` | 미연결(`targetClosed`) | 회색 |
| 연결됨 | 다른 창 고름 | 연결됨(새 창) | 녹색(새 창 정보) |
| 연결됨 | `disconnect()`(사용자 해제, UI는 FE8-e) | 미연결(`user`) | 회색 |
| 연결됨 | 백엔드 끊김·연결 중(재시작 포함) | 미연결(`backendDisconnected`) | 빨강 `백엔드 끊김` / 주황 `백엔드 연결 중` |
| 미연결 | 백엔드 끊김 | 미연결 | 빨강 `백엔드 끊김` |
| (끊김 뒤) | 백엔드 다시 연결 | 미연결 유지 | 회색 |
| 연결됨 | 목록 읽기 실패 | 그대로 | 그대로 |

### 처리한 FD

- **FD-116 (a)(확정)**: 앱 전역 connectedTarget만 기억하고 창 목록을 주기적으로 확인한다. 창이 닫히거나 목록에서 사라지면 해제한다.
  - dock 시점은 바꾸지 않았다(전체 학생 스캔 때만).
  - 프롬프트의 백엔드 재시작·사용자 해제도 해제 조건으로 넣었다.
  - FD에 주기 수치가 없어 5초는 워커가 정했다(발견 4).
- **FD-117(워커 재량) → 권장안 (a)**: 칩은 하나이고 게임 창 연결을 보인다. 백엔드가 끊기면 `백엔드 끊김`(빨강)이 앞선다. `RecoveryBanner`는 그대로다.
- **FD-148(워커 재량)**: 이번 몫인 "백엔드 끊김 > 게임 창 연결(녹/회)"만 했다. 스캔 진행·일시정지 칸, 탭 점, 토스트는 FE8-f2다.
- **FD-115(확정) 중 칩 색만**: 미연결 회색. 지표 숫자만·초상 둥근 사각은 하지 않았다(발견 3).
- FD-140·FD-155는 읽기만 했다(FE8-f3·g1 몫).

### golden 변화 예상

golden mock(`MockAppService`·`GoldenMockAppService`·각 장면 mock)은 백엔드가 connected이고 고른 창이 없다. 그래서 셸 머리글이 보이는 장면은 모두 칩이 녹색 `연결됨`에서 회색 `연결 안 됨`으로 바뀐다. 함께 바뀌는 것:

- 칩 폭: 약 +30px(글자 2자·공백 추가)
- 칩 높이: 여백 7+1 → 5+1, 4px 낮아짐
- 점: 아이콘 글리프 → 8px 원
- 색: 녹 → 회

바뀔 장면(14, `BAPlannerApp` 셸 머리글이 보임):

1. `home` — 칩에 더해, 칩이 넓어진 만큼 초상·`학생`·`인벤토리` 지표가 왼쪽으로 밀린다.
2. `students-grid`
3. `students-detail`
4. `students-grid-name-off`
5. `students-grid-second-form`
6. `students-filter-open`(모달 아래 머리글)
7. `students-calculator`
8. `students-calculator-bond-popover`
9. `inventory`
10. `inventory-all`
11. `inventory-analysis`
12. `inventory-analysis-opa`
13. `inventory-tiers`
14. `statistics-growth`(Lane A FE7-b가 같은 장면을 바꾸는 중이면 두 변화가 겹친다)

2~14는 머리글 오른쪽 칩 영역만 바뀐다. 제목은 Expanded라 자리가 그대로다.

바뀌지 않을 장면(29):
- `title`·`account-manager`·`account-editor`·`account-picker`·`account-new`: `TitlePage`만 그린다(셸 없음).
- `plan-*` 23장: `goldenMaterialHost(PlanningPage)`로 그린다(셸 없음). `plan-bottleneck`·`plan-by-phase`·`plan-overall`·`plan-preset-manager`, `plan-flow-*` 11장, `plan-scenario-*` 8장이다.
- `scan-student-review`: `ScanStudentReviewWorkspace`만 그린다.

새 golden 장면은 만들지 않았다.

### 미검증 항목

- golden 비교: **미실행**(위 예상 14장).
- 전체 `fe_gate.ps1`·process E2E·`codealmanac validate`·저장소 전체 `git diff --check`: **미실행**(CF 몫).
- 실제 게임 창 연결(Windows 창 목록·최소화·닫기·게임 재시작 뒤 해제): **미실행**(사용자 실기). Mock과 가짜 목록으로만 확인했다.
- 실제 백엔드에서 5초 주기 `scanner.target.list`의 비용과 스캔 중 동시 요청: **미검증**. 프로토콜상 요청 간 순서 제약은 없다(fb10a의 pause도 스캔 중 요청으로 돈다).
- 2560×1392 기준 viewport의 칩 좌표: 시안 칩은 flex 배치라 절대 좌표가 없다. 여백·크기만 시안 CSS와 맞췄다.

### 검수표 (artboard `Home-Connect-Pick.dc.html` 머리글, `Home-Connect-Effect.dc.html` 칩 전환)

앱에서 여는 방법: mock 모드(`--dart-define=BA_PLANNER_USE_REAL_BACKEND=false`), 2560×1440 모니터 최대화. 첫 화면 타이틀 → 시작. 칩은 머리글 오른쪽, 개발 상태 패널 버튼 왼쪽에 있다.

| # | 확인 포인트 | 코드 |
|---|---|---|
| C1 | 홈 머리글 칩이 회색 `연결 안 됨`이다(글자 #c3cfdb, 점 #9eb0c2, 옅은 회색 채움·선) | `HeaderConnectionKind.targetDisconnected` |
| C2 | `스캔` 탭 → `Game window target`에서 `Mock Blue Archive`를 고르면 칩이 녹색 `연결됨 · Blue Archive · 2560×1440`(#58d6a7)이 된다 | `_chooseTarget` → `connect` |
| C3 | 다른 탭(홈·학생·인벤토리·통계)으로 가도 칩이 같다 | 셸 소유 컨트롤러 |
| C4 | 칩(회색이든 녹색이든)을 누르면 `스캔` 탭으로 가고, 드롭다운에 연결된 창이 골라져 있다 | `onOpenTargetPicker` |
| C5 | 개발 상태 패널 → `백엔드 연결`을 `disconnected`로 바꾸면 칩이 빨강 `백엔드 끊김`이고 누를 수 없다. `connecting`이면 주황 `백엔드 연결 중`이다 | `HeaderConnectionChipState.resolve` |
| C6 | 다시 `connected`로 바꾸면 칩이 회색 `연결 안 됨`이다(백엔드 끊김이 연결을 해제했다). 스캔 탭 드롭다운도 비어 있다 | `backendDisconnected` |
| C7 | 창을 작게(예: 1280×720) 해도 칩 글자가 한 줄이고 머리글이 넘치지 않는다 | `HeaderConnectionChip.maxWidth`·말줄임 |
| C8 (실기) | 실제 백엔드에서 게임 창을 고른 뒤 게임을 끄면 5초 안에 칩이 `연결 안 됨`이 된다. 최소화하면 `연결됨 · Blue Archive · —`다 | 주기 확인 |

### WIP 보존 확인

- `frontend/lib/ui/pages/scan_page.dart`(다른 세션 WIP 있음):
  - pre 사본과 끝 내용의 차이는 이 slice의 9곳뿐이다: import 1, 생성자 1, 필드 3, initState 5, dispose 1, 새 메서드 묶음 50, 목록 새로고침 1, `_openRecent` 2, 드롭다운 1.
  - 지운 기존 줄은 `_openRecent`의 3줄(1줄로 바꿈)과 드롭다운 `onChanged` 1줄뿐이다.
  - WIP hunk와 가장 가까운 곳은 `_openRecent`(WIP 줄과 9줄 떨어짐)와 import(6줄)다. 병합 모의 충돌은 0이다.
  - LF를 유지했다. 끝 사본은 `debug/frontend_fe8d/post/frontend/lib/ui/pages/scan_page.dart`이고, 현재 파일과 바이트가 같음을 확인했다.
  - `dart format`은 이 파일 전체에 돌리지 않았다(WIP 줄 1곳이 형식과 다르고, 건드리지 않음). 내 줄만 형식에 맞췄다.
- `app_shell.dart`: WIP 없음, LF 유지. 기존 형식 차이 1곳(`_TopTab` fontWeight 줄바꿈)은 그대로 두었다.
- `widget_test.dart`: WIP 없음, CRLF 유지(새 줄도 CRLF).
- 수정 0: `lib/services/scanner_service.dart`(WIP 있음)를 비롯한 `lib/services/**`, Lane A 파일(`lib/ui/statistics/**`·`statistics_page.dart`·`lib/statistics/**`), `lib/ui/kit/**`, 스캐너 소유 위젯, golden 파일, `frontend/tool/**`, `backend/**`·`contracts/**`.

### 발견 사항

1. 시안 `Home-Connected-Scan`의 **머리글** 칩은 `연결됨 · Blue Archive`(크기 없음)다. `· 2560×1440`은 스캔 팝업 안 칩에만 있다(`Home-Connect-Effect`도 머리글에는 크기가 없다). 워크플로 FE8-d 행과 이번 프롬프트가 머리글에 크기를 넣으라고 해서 그대로 했다. 머리글에서 크기를 뺄지는 CF 판단.
2. `백엔드 연결 중`(주황)은 시안·FD에 문구가 없다. 옛 배지의 connecting 상태를 이어 백엔드 칸으로 두었다(FD-117 확장, 워커 재량).
3. FD-115의 나머지(지표 `217`·`1,284` 숫자만, 초상 둥근 사각 62×52 흰 2px)는 하지 않았다. 막는 slice는 FE8-d로 적혀 있지만 이번 프롬프트 범위가 칩뿐이다. `widget_test`는 아직 `42명`을 기대한다. 다른 slice(FE8-e 또는 작은 정리)로 배정이 필요하다.
4. 주기 확인 간격 5초는 워커가 정했다(FD-116에 수치 없음, `ConnectedTargetController.defaultPollInterval`). 스캔 중에도 확인한다.
5. 지금 홈에는 창 고르기가 없다(홈 `싯딤의 상자와 연결`은 스캔 탭으로 이동한다). 그래서 홈 화면은 아직 컨트롤러를 받지 않는다. FE8-e가 할 일:
   - `HomePage`에 셸의 `_connectedTarget`을 넘긴다(창 선택 패널 → `connect`, 메뉴 교체는 `isConnected`, 해제 연출은 `lastRelease`).
   - 칩을 누르는 동작을 패널 열기로 바꾼다.
   - 테스트는 같은 컨트롤러에 직접 쓰는 방식으로 "다른 화면이 쓴 값"을 확인했다.
6. 최소화된 창도 연결로 본다(FD-116은 닫힘·사라짐만 해제). 칩은 크기를 모르니 `연결됨 · Blue Archive · —`가 되고, 최소화라는 표시는 없다. 스캔 시작은 지금처럼 `ready`일 때만 된다.
7. 최근 스캔 기록을 열면 그 기록의 창에 연결한다. 예전 동작("선택을 기록의 창으로 바꿈")을 전역 연결로 옮긴 것이다. 기록의 창이 목록에 없으면 지금 연결을 그대로 둔다(예전: 선택을 비움).
8. 설정 탭의 `감지된 대상 N개` 목록은 컨트롤러와 따로 읽는다(연결 상태에는 영향 없음).
9. 계정을 바꿔도 게임 창 연결은 유지된다(창은 계정과 무관하다고 보았다). 다르게 원하면 CF 판단.

### 사본·commit.json

- 착수 사본: `debug/frontend_fe8d/pre/<경로>`(고친 기존 파일 3개).
- 끝 사본: `debug/frontend_fe8d/post/frontend/lib/ui/pages/scan_page.dart`(WIP 파일만).
- 테스트 로그: `debug/frontend_fe8d/logs/<파일>.log`(21개, 커밋 대상 아님).
- `debug/frontend_fe8d/commit.json`:
  - slice `fe8d`, `status=false`, `post_dir`
  - modified 3, added 3
  - `whole` = [이 문서 + 바뀌는 기준 이미지 14장]
  - message는 ASCII다(근거: FD-116·FD-117·FD-148·FD-115, A §6, fb4-dart).
- 인계: `debug/frontend_fe8d/output.md`.

### 다음 행동

- FE8-d 코드는 끝났다. Lane B는 여기서 멈춘다.
- CF: Lane A(FE7-b)와 이 slice가 모두 멈춘 뒤 gate를 1회 돌린다.
  - 예상: analyze 0, 일반 테스트 +8(새 파일), golden RED = 위 14장(`statistics-growth`는 Lane A 변화와 겹칠 수 있음).
  - `failures/`를 isolatedDiff로 한 장씩 대조한다. 칩 영역 밖이 바뀌었으면(`home`의 지표 이동 제외) 이 예측이 틀린 것이다.
  - 그 뒤 `-UpdateGoldens` → 재비교 → `fe_commit.ps1 -Slice fe8d`(`scan_page.dart`는 3-way 병합, 모의 충돌 0).
- 발견 1·2·3·4·9는 CF 판단을 기다린다. FE8-e는 발견 5를 이어받는다.

## FE8-e 착수 기록 (2026-10-13)

- 상태: 진행 중.
- 범위: 홈 창 선택 패널(Home-Connect-Pick)과 메뉴 교체 이펙트(Home-Connect-Effect, A §7.2), 머리글 칩 → 패널 열기, FE8-d 후속 3건(머리글 칩에서 크기 빼기, FD-115 나머지 홈 지표 숫자만·초상 62×52, 홈이 셸의 `ConnectedTargetController`를 받음). 스캔 팝업(Home-Connected-Scan, FE8-f3)은 범위 밖.
- 막힘 확인: 막힘 요약의 FE8-e 행 FD-116은 확정(2026-10-06). 막는 '열림' FD 없음(현재 열림 0건). FD-119는 워커 재량.
- 중복 실행 확인: 이 문서 끝에 다른 "FE8-e 착수 기록" 없음.
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `c2ceb57ebc1429372b53fd6c260b02d9a2bf06ca`.
- 고칠 기존 파일과 WIP(`git status --short <경로>`), 착수 사본 `debug/frontend_fe8e/pre/<v7 기준 경로>`:

  | 파일 | WIP | 줄바꿈 | 고칠 곳 |
  |---|---|---|---|
  | `frontend/lib/ui/pages/home_page.dart` | 없음 | CRLF | 컨트롤러 받기, 패널 열기, 행1 선택 표시·flash, 메뉴 교체 연출 |
  | `frontend/lib/ui/app_shell.dart` | 없음 | LF | 홈에 컨트롤러 전달, 칩 → 홈 + 패널 열기, 지표 숫자만·초상 둥근 사각(FD-115, 지표·초상이 `_AppHeader`에 있음) |
  | `frontend/lib/ui/scan/header_connection_chip.dart` | 없음 | LF | 머리글 칩 문구에서 크기 빼기 |
  | `frontend/lib/app/theme.dart` | 없음 | CRLF·LF 섞임 | `AppMotion` 교체 연출 구간 토큰, flash 색 토큰 `connectFlash`(FD-119) — 추가만 |
  | `frontend/test/widget_test.dart` | 없음 | CRLF | `42명`·초상 기대 |
  | `frontend/test/connected_target_fe8d_test.dart` | 없음 | LF | 머리글 칩 문구·칩 누름 동작 기대 |
  | `frontend/test/home_page_test.dart` | 없음 | LF | (필요하면) 컨트롤러 없는 홈 기대 |

- 새 파일(예정): `frontend/lib/ui/home/connect_target_panel.dart`(창 선택 패널), `frontend/lib/ui/home/home_menu_swap.dart`(교체 타임라인), `frontend/test/home_connect_fe8e_test.dart`.
- `lib/services/**`·`lib/ui/kit/**`·`scan_page.dart`·Lane A 파일은 읽기만 한다. WIP 있는 파일은 고치지 않을 예정이라 post 사본은 없을 수 있다.

## FE8-e 종료 기록 (2026-10-13, 코드 작성 완료·CF gate 미실행)

홈 `싯딤의 상자와 연결`이 오른쪽 부착 창 선택 패널을 열고, 고른 창을 셸의 `ConnectedTargetController.connect`로 연결한다. 연결되면 홈 메뉴가 시안 타임라인대로 빠졌다가 첫 버튼이 `스캔`으로 바뀌어 들어오고, 해제되면 역연출한다. 머리글 칩은 어느 탭에서든 홈 패널을 연다. FE8-d 후속 3건(머리글 칩 크기 빼기, FD-115 지표·초상, 홈이 셸 컨트롤러 사용)도 했다.

### 실행 명령·결과

모두 `frontend` 폴더에서 실행했다. golden·process E2E·전체 gate는 돌리지 않았다.

- `flutter analyze`: 마지막 실행(모든 편집 뒤) **No issues found**(0, info 포함).
  - 중간에 Lane A의 작업 중 파일(`lib/ui/statistics/statistics_workspace.dart`, `supply`·`supplyEmpty` 인자 3건 + 안 쓰는 import 1건)로 4건이 보인 때가 있었다. 이 slice 파일의 지적은 아니며, Lane A 파일이 컴파일되자 0이 되었다.
- `flutter test test/<파일>.dart --reporter expanded`(파일마다 따로, 로그 `debug/frontend_fe8e/logs/`): 23개 파일 모두 통과, 실패 0.

  | 파일 | 통과 | 실패 |
  |---|---:|---:|
  | `home_connect_fe8e_test.dart`(새) | 10 | 0 |
  | `connected_target_fe8d_test.dart`(기대 수정) | 8 | 0 |
  | `widget_test.dart`(기대 수정) | 16 | 0 |
  | `home_app_shell_test.dart` | 1 | 0 |
  | `home_page_test.dart`(수정 없음) | 5 | 0 |
  | `theme_tokens_test.dart` | 3 | 0 |
  | `scan_page_test.dart` | 17 | 0 |
  | `scan_page_revision_test.dart` | 14 | 0 |
  | `scan_page_pause_fb10a_test.dart` | 8 | 0 |
  | `mock_scanner_service_test.dart` | 4 | 0 |
  | `scanner_protocol_client_test.dart` | 6 | 0 |
  | `scanner_target_metadata_fb4_test.dart` | 19 | 0 |
  | `scanner_pause_fb10a_test.dart` | 39 | 0 |
  | `account_editor_fe8c_test.dart` | 9 | 0 |
  | `account_manager_fe8b_test.dart` | 6 | 0 |
  | `growth_calculator_view_test.dart` | 24 | 0 |
  | `inventory_shell_lazy_test.dart` | 1 | 0 |
  | `profile_delete_fb2d_test.dart` | 17 | 0 |
  | `section_template_studio_test.dart` | 15 | 0 |
  | `statistics_app_shell_test.dart` | 2 | 0 |
  | `student_filter_followups_test.dart` | 4 | 0 |
  | `student_filter_modal_test.dart` | 7 | 0 |
  | `title_page_test.dart` | 25 | 0 |

  - 고른 기준: FE8-d가 고른 21개(셸·`BAPlannerApp`·`ScanPage`·칩 문구·대상 목록 DTO) + 새 파일 + `theme.dart` 토큰 테스트.
  - 첫 실행에서 아래 10개(`account_editor_fe8c`~`title_page`)가 0초에 컴파일 실패했다. 원인은 위 Lane A 파일의 컴파일 오류다(로그 `Compilation failed … statistics_workspace.dart:216:15`). 잠금 충돌은 아니다. Lane A 파일이 컴파일된 뒤 한 번 다시 돌려 모두 통과했다(표의 수치가 재실행 결과).
- `git diff --check`(이 slice의 기존 파일 6개): 지적 없음. 새 파일 3개는 끝 개행 하나, 줄 끝 공백 없음.

### 고친 파일

- **`frontend/lib/ui/home/connect_target_panel.dart`(새)**: `ConnectTargetPanel`. 시안 Home-Connect-Pick 패널 rect(1822.5,202 719.5×1018)를 원점으로 한 설계 px로 배치한다.
  - 표면: 공용 `SectionSurface`(왼쪽 80° 사선·오른쪽 수직, r14).
  - 제목(분홍 사선 막대 7×24 + `싯딤의 상자와 연결` 24px dsp), 안내 `Blue Archive 창을 선택해 주십시오.`, 상태 줄 `선택 예정 <제목>`·`현재 선택: <연결된 창 | 없음>`.
  - 창 목록: 행 38·피치 44, 오른쪽 끝 고정(시안 2484), 왼쪽 끝은 행 아래 경계 높이의 패널 사선 + 24(스크롤해도 사선을 따라감). viewport clip은 시안 clip-path(사선 + 14, r8).
  - 행: 게임 창이면 `BA` 태그 #3dbf7a·제목 #b9f1d0, 아니면 태그 없음·제목 #f4f8fb. 선택 예정 행은 분홍 .16 + 2.8px, 나머지는 행 표면 .72 + 외곽선 .55 1.2px. 크기 칸 min 90 오른쪽 정렬, 제목은 한 줄 말줄임.
  - 수직 스크롤바: 키트 `DiagonalScrollbar`에 수직 `trackPoint`(오른쪽에서 14, 위아래 8)와 레일 드래그를 넘겼다. 아래 포그는 `ScrollFogSpec.panel`(surface .96, 44px). 키트 파일은 고치지 않았다.
  - 버튼: `새로고침`(왼쪽 사선 200×56, #3a4b58), `취소`(tonal 130×56), `선택한 창 사용`(tonal pri 220×56, 링크 아이콘). 고를 창이 없거나 닫힌 창이면 `선택한 창 사용`은 비활성(.45).
  - 목록 읽기 결과로 `ConnectedTargetController.updateTargets`도 부른다(FE8-d의 스캔 새로고침과 같은 경로).
  - 선택 예정 기본값: 이미 고른 창 → 연결된 창 → 첫 게임 창(FD-118), 닫힌 창 제외.
  - 상태 표시(워커 재량, 발견 1): 크기 칸에 `최소화됨`·`미지원`·`닫힘`. 닫힌 창은 .45로 흐리고 고를 수 없다.
  - 문구(워커 재량, 발견 1): 목록 칸 `창 목록을 읽고 있습니다.`·`창 목록을 읽지 못했습니다.`·`백엔드에 연결되어 있지 않습니다.`·`감지된 창이 없습니다.`
- **`frontend/lib/ui/home/home_menu_swap.dart`(새)**: `HomeMenuSwapTimeline`(connect·release). 아래 "모션 타임라인" 표. 메뉴·패널 거리, 교체 시점, flash 불투명도를 시각으로 계산한다.
- **`frontend/lib/ui/pages/home_page.dart`(CRLF 유지, +340 −43)**:
  - 새 인자 `connectedTarget`(선택), `openTargetPickerRequest`(셸 요청 카운터).
  - 컨트롤러가 없으면(단독 테스트) 첫 버튼은 예전처럼 `onOpen(AppSection.scan)`이다. 있으면 미연결일 때 패널을 열고, 연결되면 첫 버튼이 `스캔`(`scan.png`)이 되어 누르면 스캔 탭으로 간다(스캔 팝업은 FE8-f3).
  - 패널은 메뉴와 같은 높이 배율의 FittedBox로 오른쪽 위에 붙인다. intro 180°·outro 0°(820 설계 px, `AppMotion.section` 360ms·`sectionCurve`).
  - 패널이 열려 있고 메뉴가 A이면 행1에 분홍 3.2px 선택 선(`home-menu-featured-selected`). flash(`home-menu-featured-flash`)는 #76D7FF 3.2px + 채움 .16.
  - 연결 상태가 메뉴 표시와 다르면 교체 연출을 시작한다. 연출 중 다시 바뀌면 끝난 뒤 이어서 맞춘다. 연출 중 메뉴는 누를 수 없다.
  - 미연결 → 연결이면 열린 패널이 연출과 함께 빠진다. 이미 연결된 상태에서 다른 창을 고르면 메뉴 연출 없이 패널만 닫는다.
  - 메뉴 구조: 행1만 `Stack(expand)`로 감싸 겹침을 올린다. 겹침이 없을 때 배치·그림은 예전과 같다.
- **`frontend/lib/ui/app_shell.dart`**: 아래 "app_shell diff".
- **`frontend/lib/ui/scan/header_connection_chip.dart`(+6 −4)**: `connectedTargetLabel(target, {includeSize = true})`. 머리글 칩은 `includeSize: false`로 `연결됨 · Blue Archive`다(game 모름 → `연결됨`). 크기 포함 문구는 그대로 남겨 패널·스캔 팝업 칩이 쓴다. `onOpenTargetPicker` 주석을 바꿨다.
- **`frontend/lib/app/theme.dart`(추가만, +19)**: `AppMotion.connectAnticipate`·`connectMenuExit`·`connectSwapHold`·`connectMenuEnter`·`connectReleaseEnter`·`connectMenuSettle`·`connectFlashIn`·`connectFlashOut`·`connectPanelDelay`·`connectPanelExit`, `AppColors.connectFlash`(#76D7FF). 프롬프트 "AppMotion 안에서"와 FD-119 "flash 색은 토큰(`connectFlash`)으로만 추가"에 따랐다. 이 파일은 프롬프트의 고치는 곳 목록에 없었다(발견 7). 착수 기록 표의 줄바꿈 "CRLF·LF 섞임"은 틀렸다: CR이 없는 LF 파일이다(`file` 오판).
- **`frontend/test/widget_test.dart`(CRLF 유지, +20 −8)**:
  - `selected account portrait is left of the student count`: AssetImageGrid 기대 → 62×52, r9, 흰 2px 링(`boxShadow` spread 2, `AppColors.text`), 이미지 `hasumi.png` cover. 지표 `42명` → `42`, `42명` 없음.
  - `mock state is reflected without replacing widgets`: `42명` → `42`, `9999명` → `9,999`.
  - 안 쓰게 된 `asset_image_grid.dart` import를 지웠다.
- **`frontend/test/connected_target_fe8d_test.dart`(+35 −8)**:
  - 머리글 칩 문구 기대 6곳: `… · 2560×1440`·`… · 1920×1080` → `연결됨 · Blue Archive`.
  - `connectedTargetLabel(…, includeSize: false)` 기대 2건 추가(크기 포함 기대 4건은 그대로).
  - 칩 누름: 스캔 탭 이동 → 홈 패널 열림, `현재 선택: Mock Blue Archive`, 스캔 드롭다운은 그대로 `mock-window`.
- **`frontend/test/home_connect_fe8e_test.dart`(새, 10건)**:
  - 타임라인 2건: 연결 keyframe 값(0.25s +14, 0.9s −820, 0.95s 교체, 1.8s −10, 2.2s 0, flash 2.0→2.2 최대→2.8, 패널 0.2→0.9s +820·숨김), 해제(2.2s, flash·패널 없음).
  - 패널 6건:
    - 기준 viewport(2560×1392, 머리글 184) rect: 패널 1822.5,202 719.5×1018, 메뉴 18,202 742×1018, 행1 1990.7,364 493.3×38, 행2 1983.0,408 501.0×38, 버튼 3개(±1px). intro 중간에 패널이 오른쪽에 있음. 선택 예정·현재 선택·`BA` 태그·크기·`—`, 취소 → 닫힘.
    - 상태 문구·닫힌 창 고를 수 없음·긴 제목 말줄임·새로고침 재조회(1280×720, 넘침 없음).
    - 30행 스크롤: 피치마다 왼쪽 끝 7.76px, 오른쪽 끝 2484, 스크롤 뒤 행이 그 높이의 사선 자리.
    - 연결 연출(1280×720): +14 → 0.25·0.5·0.75 지점 넘침 없음, 교체 전 A·교체 뒤 B, 패널 퇴장, flash 차오름, 안착 → `스캔` 누름 = 스캔 탭. 해제: +14 예비동작, flash 없이 A로 복귀, `lastRelease = user`.
    - 연결된 상태에서 셸 요청으로 열기 → 다른 창 사용 → 메뉴 연출 없이 패널만 닫힘, B 메뉴에는 선택 선 없음.
    - 백엔드 끊김: 패널 문구, 선택 예정 `—`, 사용 불가, 목록 읽지 않음.
  - 셸 2건: 학생 탭에서 칩 → 홈 + 패널 → 창 사용 → 칩 녹색 `연결됨 · Blue Archive`·메뉴 `스캔` → 누르면 스캔 탭. 지표 `217`·`1,284`(단위 없음).
- 지운 테스트 없음. `home_page_test.dart`는 고치지 않았다(컨트롤러 없는 홈은 예전 동작, 5건 통과). 그 착수 사본은 지웠다.

### app_shell diff (+48 −24, 이유)

- FE8-e 몫(+16 −3):
  - `_targetPickerRequest` 필드(주석 포함 3줄)와 `_openTargetPicker()`(5줄: 홈으로 이동 + 요청 올림).
  - `_CompoundPageHeader`에 `onOpenTargetPicker` 인자·필드(2줄), 셸이 넘김(1줄). 옛 람다(`onSelected(AppSection.scan)`)와 그 주석 3줄 → `onOpenTargetPicker: onOpenTargetPicker` 1줄.
  - `HomePage(…)`에 `connectedTarget`·`openTargetPickerRequest` 2줄.
  - 이유: 홈이 셸의 같은 컨트롤러를 써야 한다(FE8-d 발견 5). 칩 → 패널 열기는 홈 상태라 셸은 요청만 보낸다.
- FD-115 몫(+32 −21): 머리글 지표·초상이 `_AppHeader`에 있어서 이 파일을 고쳤다.
  - 초상 `SizedBox.square(62) + AssetImageGrid(square.png 겹침)` → `Container` 62×52 r9, #c9d6e2 바탕, 흰 2px 링, 이미지 cover 50% 22%(시안 `object-position`).
  - 지표 `명`·`개` 단위 문자열 → `_headerCount(n)`(세 자리 쉼표, 9줄 함수).
  - 안 쓰게 된 `asset_image_grid.dart` import 1줄 삭제.
- `app_section.dart`는 고치지 않았다.

### 모션 타임라인 (시안 Home-Connect-Effect 10초 루프 → 앱 1회 재생)

곡선은 구간마다 CSS keyframes 기본 `ease`(`Curves.ease`)다. 거리는 메뉴 설계 px라서 화면에서는 메뉴 배율로 줄어든다.

| 연결 t(ms) | 시안 시각 | 메뉴(`menuOffset`) | 패널 | 첫 버튼 | flash | 토큰 |
|---|---|---|---|---|---|---|
| 0–250 | 1.8–2.05s | 0 → +14 | 그대로 | A | — | `connectAnticipate` 250 |
| 200–900 | 2.0–2.7s | — | 0 → +820(0°), 900 이후 숨김 | — | — | `connectPanelDelay` 200 · `connectPanelExit` 700 |
| 250–900 | 2.05–2.7s | +14 → −820(180°) | — | A | — | `connectMenuExit` 650 |
| 900–1000 | 2.7–2.8s | −820 유지 | 숨김 | 950에 A → B(2.75s) | — | `connectSwapHold` 100 · 교체 = 퇴장 끝 + 50 |
| 1000–1800 | 2.8–3.6s | −820 → −10(0°) | — | B | — | `connectMenuEnter` 800 |
| 1800–2200 | 3.6–4.0s | −10 → 0 | — | B | 2000–2200 0 → 1 | `connectMenuSettle` 400 · `connectFlashIn` 200 |
| 2200–2800 | 4.0–4.6s | 0 | — | B | 1 → 0 | `connectFlashOut` 600 |

| 해제 t(ms) | 시안 시각 | 메뉴 | 첫 버튼 | 토큰 |
|---|---|---|---|---|
| 0–250 | 7.0–7.25s | 0 → +14 | B | `connectAnticipate` |
| 250–900 | 7.25–7.9s | +14 → −820 | B | `connectMenuExit` |
| 900–1800 | 7.9–8.8s | −820 → −10 | 950에 B → A(7.95s) | `connectReleaseEnter` 900 |
| 1800–2200 | 8.8–9.2s | −10 → 0 | A | `connectMenuSettle` |

- 머리글 칩은 컨트롤러 값을 바로 그린다(시안은 2.75s에 칩도 바꾼다, 발견 5).
- 패널 intro/outro(첫 버튼·칩으로 열기, 취소)는 시안에 없어 공용 `AppMotion.section` 360ms·`sectionCurve`, 거리 820이다.

### 처리한 FD

- **FD-116 (a)(확정)**: 홈 패널 → `connect`. 해제(사유 무관: user·targetMissing·targetClosed·backendDisconnected)는 B → A 역연출. dock은 그대로(연결 때 dock 안 함).
- **FD-115(확정) 나머지**: 지표 숫자만(`217`·`1,284`), 초상 둥근 사각 62×52 흰 2px. 칩 색은 FE8-d에서 끝났다.
- **FD-119(워커 재량) → 권장안**: 이 전이 전용 곡선(`HomeMenuSwapTimeline`, 공용 섹션 모션으로 올리지 않음), flash 색은 토큰 `AppColors.connectFlash`로만 추가.
- **FD-001**: 머리글 칩에서 크기를 뺐다(CF 2026-10-13 17:40 결정). 패널은 행마다 크기를 보인다.
- **FD-118(워커 재량)**: 선택 예정 = 첫 게임 창.
- **FD-019(확정)**: 패널은 오른쪽 부착 사다리꼴(왼쪽 80° 사선)이라 부유 섹션 예외가 필요 없다.
- **FD-117(워커 재량)**: 그대로(백엔드 끊김 > 게임 창). 백엔드 끊김이면 칩을 누를 수 없다.
- FD-140·FD-155는 읽기만 했다. 연결된 `스캔` 버튼은 FE8-f3 전까지 스캔 탭 이동이다. 패널 위젯은 `designSize` 단독 위젯이라 FE8-g1(FD-155)이 다시 쓸 수 있다.

### golden 변화 예상 (실행하지 않음)

golden mock은 고른 창이 없다(미연결). 머리글 칩은 미연결 회색 `연결 안 됨` 그대로라 칩 변화는 없다. 홈 메뉴는 미연결 A 그대로이고, 패널은 닫혀 있다.

바뀔 장면(1):
1. `home` — 머리글 지표가 숫자만(단위 글자 없음, 1000 이상이면 쉼표)이라 폭이 줄어 초상·지표가 오른쪽(칩 쪽)으로 붙는다. 초상이 정사각 62(square.png 테두리 겹침) → 62×52 둥근 사각 r9 + 흰 2px 링(시안). 메뉴·칩·탭은 그대로다.

바뀌지 않을 장면(나머지 전부, Lane A 새 장면 포함):
- 셸 머리글이 보이는 다른 장면(`students-*` 7, `inventory*` 5, `statistics-*`): 지표·초상은 홈 탭에서만 보인다(`showMetrics = section == home`). 칩 문구는 미연결이라 같다.
- `title`·`account-*` 4: `TitlePage`만 그린다(셸·머리글 지표 없음).
- `plan-*` 23, `scan-student-review`: 셸 없음.

새 golden 장면은 만들지 않았다.

### 미검증 항목

- golden 비교: **미실행**(위 예상 `home` 1장).
- 전체 `fe_gate.ps1`·process E2E·`codealmanac validate`·저장소 전체 `git diff --check`: **미실행**(CF 몫).
- 실제 게임 창 연결과 연출(Windows 창 목록, 게임 창 고르기 → 이펙트, 게임 종료 → 5초 안 해제 연출): **미실행**(사용자 실기). Mock과 가짜 목록으로만 확인했다.
- 실제 화면에서 연출의 체감(예비동작 14px·overshoot 10px·flash 세기): 테스트는 값만 확인했다. 눈으로 보지 않았다.
- `scan.png`가 시안 `스캔` 이미지(blob `9e57…`)와 같은 그림인지: 확인 못 함(A §7.3과 같음).
- 패널 내부 글자 위치(제목·안내·상태 줄): 시안 좌표로 놓았지만 테스트는 패널·행·버튼 rect만 비교했다.

### 검수표 (artboard `Home-Connect-Pick.dc.html`, `Home-Connect-Effect.dc.html`)

앱에서 여는 방법: mock 모드(`--dart-define=BA_PLANNER_USE_REAL_BACKEND=false`), 2560×1440 모니터 최대화, 타이틀 → 시작.

| # | 확인 포인트 | 코드 |
|---|---|---|
| E1 | 머리글 지표가 숫자만(`학생 N`, `인벤토리 N`, 1000 이상 쉼표), 초상이 62×52 둥근 사각에 흰 2px 테두리 | `_AppHeader`·`_headerCount` |
| E2 | `싯딤의 상자와 연결`을 누르면 오른쪽에서 패널이 들어와 1822,202 720×1018에 붙고, 메뉴 행1에 분홍 선이 생긴다 | `ConnectTargetPanel`, `home-menu-featured-selected` |
| E3 | 패널: 제목·안내·`선택 예정 Mock Blue Archive`·`현재 선택: 없음`, 행 `BA · Mock Blue Archive · 2560×1440`(분홍 선택), 수직 스크롤바 트랙, 새로고침·취소·선택한 창 사용 | 같은 파일 |
| E4 | `취소` → 패널이 오른쪽으로 빠지고 분홍 선이 사라진다 | `_closePanel` |
| E5 | `선택한 창 사용` → 메뉴가 살짝 오른쪽(+14)으로 갔다가 왼쪽으로 빠지고, 패널은 오른쪽으로 빠진다 → 첫 버튼이 `스캔`인 메뉴가 왼쪽에서 들어와 안착 → 행1에 하늘색(#76D7FF) flash가 차올랐다 사라진다. 칩은 녹색 `연결됨 · Blue Archive`(크기 없음) | `HomeMenuSwapTimeline.connect` |
| E6 | 연결된 뒤 `스캔`을 누르면 스캔 탭으로 간다(팝업은 FE8-f3) | `_openFeatured` |
| E7 | 다른 탭(예: 학생)에서 칩을 누르면 홈으로 와서 패널이 열리고, 연결된 상태면 `현재 선택: Mock Blue Archive`다 | `_openTargetPicker` |
| E8 | 개발 상태 패널에서 백엔드를 `disconnected`로 → 홈 메뉴가 같은 방식으로 빠졌다가 `싯딤의 상자와 연결`로 돌아온다(flash 없음). 칩은 빨강 `백엔드 끊김` | `HomeMenuSwapTimeline.release` |
| E9 | 창을 작게(1280×720) 해도 패널·메뉴가 같은 배율로 줄고 넘치지 않는다. 긴 창 제목은 말줄임 | FittedBox 배율 |
| E10 (실기) | 실제 게임 창을 고르면 E5, 게임을 끄면 5초 안에 E8과 같은 해제 연출 | 주기 확인(FE8-d) |

### WIP 보존 확인

- 고친 기존 파일 6개 모두 착수 때 WIP 없음(`git status --short` 빈 출력). 착수 사본 `debug/frontend_fe8e/pre/`는 HEAD와 같다. WIP 파일을 고치지 않아 post 사본·`post_dir`은 없다.
- 줄바꿈: `home_page.dart`·`widget_test.dart` CRLF 유지(편집 스크립트가 CRLF로 다시 썼고 `file`로 확인), 나머지 LF 유지. 새 파일 3개는 LF.
- 수정 0: `lib/services/**`(스캐너 WIP 있음), `lib/ui/kit/**`, `scan_page.dart`, Lane A 파일(`lib/ui/statistics/**`·`lib/statistics/**`·`statistics_page.dart`), 스캐너 소유 위젯, `diagonal_menu.dart`, golden harness·golden 테스트, `frontend/tool/**`, `backend/**`·`contracts/**`.

### 발견 사항

1. 미지원·닫힘·최소화 창 표시는 시안(Home-Connect-Pick 행은 전부 크기만)·FD-116 어디에도 문구가 없다. 크기 칸에 `최소화됨`·`미지원`·`닫힘`을 쓰고, 닫힌 창만 흐리게(.45) 고를 수 없게 했다. 목록 칸 안내 4문구(읽는 중·실패·백엔드 없음·빈 목록)도 워커가 지었다. CF 판단.
2. 사용자 해제(`disconnect`) UI는 시안(Pick·Effect·Connected-Scan)에 없다. 그래서 만들지 않았다. 해제 연출은 창 사라짐·닫힘·백엔드 끊김(그리고 테스트의 `disconnect()`)으로만 일어난다. 해제 버튼이 필요하면 자리를 정해야 한다.
3. 연결된 `스캔` 버튼은 FE8-f3(스캔 팝업) 전까지 스캔 탭으로 간다.
4. 홈이 안 보일 때(다른 탭) 연결이 바뀌면(예: 스캔 탭 드롭다운, 백엔드 끊김) 홈 탭의 ticker가 멈춰 있어 연출이 기다렸다가, 홈으로 돌아올 때 재생된다. 바로 바뀐 메뉴를 원하면 CF 판단.
5. 머리글 칩은 연결 즉시 바뀐다. 시안은 칩도 2.75s(메뉴 교체 시점)에 바꾼다. 칩을 메뉴 연출에 맞추려면 칩이 홈 연출 상태를 알아야 해서 하지 않았다.
6. 패널 표면은 공용 `SectionSurface`(.76, FD-006)이고 시안 패널은 .78이다. 홈 메뉴 섹션은 아직 옛 `DiagonalTrapezoidSection`(블러 + 그라데이션)이라 두 섹션 표면이 다르다(FE1-c가 홈 메뉴에 적용되지 않은 기존 상태). 이 slice에서는 메뉴 표면을 고치지 않았다.
7. `lib/app/theme.dart`는 프롬프트의 고치는 곳 목록에 없지만 "AppMotion 안에서"·FD-119 토큰 지시에 따라 추가만 했다(+19). 공용 토큰 파일이라 Lane A와 겹칠 수 있다(지금은 WIP 없음). CF 확인 필요.
8. 패널 안내 `Blue Archive 창을 선택해 주십시오.`는 사용법 문장이지만 시안이 상시 보이므로 그대로 두었다(FD-001 시안 우선).
9. 패널이 열린 채 칩을 다시 누르면 패널은 그대로이고 목록을 다시 읽지 않는다(새로고침 버튼으로 읽음).
10. 같은 작업 트리에서 Lane A 파일이 컴파일되지 않는 동안 셸을 그리는 테스트 10개가 컴파일 실패했다(위 실행 결과). 동시 실행의 한계로 적어 둔다.

### 사본·commit.json

- 착수 사본: `debug/frontend_fe8e/pre/<경로>`(고친 기존 파일 6개). 끝 사본(post)은 없다(WIP 파일 없음).
- 테스트·analyze 로그: `debug/frontend_fe8e/logs/`(커밋 대상 아님).
- `debug/frontend_fe8e/commit.json`: slice `fe8e`, `status=false`, modified 6, added 3, `whole` = [이 문서, `frontend/test/goldens/baseline/home.png`], message는 ASCII.
- 인계: `debug/frontend_fe8e/output.md`.

### 다음 행동

- FE8-e 코드는 끝났다. Lane B는 여기서 멈춘다.
- CF: Lane A(FE7-c)와 이 slice가 모두 멈춘 뒤 gate를 1회 돌린다.
  - 예상: analyze 0, 일반 테스트 +10(새 파일), golden RED = `home` 1장(+ Lane A 몫).
  - `home` 차이가 머리글 지표·초상 영역 밖(메뉴·칩)에 있으면 이 예측이 틀린 것이다.
  - 그 뒤 `-UpdateGoldens` → 재비교 → `fe_commit.ps1 -Slice fe8e`(기존 파일은 모두 WIP 없음).
- 발견 1·2·4·5·7은 CF 판단을 기다린다.

## fb10c-dart 착수 기록 (2026-10-14)

- 상태: 진행 중 → 코드 작성 완료(아래 종료 기록).
- 범위: XB FB-10c(학생 무기 폴백 crop)의 프론트 개인정보·수명 연결. 근거는 backend 로그 2026-10-13 01:39·02:22·15:21·18:02와 `debug/xb_fb10c_crop_lifecycle_20261013/artifacts/CF-CONNECTION.md`·`MASTER_REQUIRED.md`·`cf-prior-list-notice.md`, 결정 대장 FD-145(워커 재량, 권장안 (a)).
  1. wire 확인: `evidence.details` optional 4키(`crop_png_base64`·`crop_source`=`basic_info`·`crop_width`·`crop_height`, weapon_level_fallback·weapon_star_fallback만) 수용 여부.
  2. 진단 JSON의 candidate.details·중첩 event.payload 두 경로에서 이미지 필드 재귀 제거, `privacy.images_included=false` 유지.
  3. 승인·폐기·적용 성공 뒤 그 후보 crop을 프론트 보관물에서 지움(보류·수정·재검증 동안 유지, 다른 후보 보존).
  4. 테스트(진단 이미지 0건, 승인·폐기 뒤 0건·다른 후보 보존, 보류·재검증 중 유지, 기존 테스트), 가능하면 실제 백엔드 process E2E 1건.
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `cbc63d98bcc279ae9ca6d22c9fe2c45ee3569996`.
- 착수 전 확인: 이 문서 끝에 다른 "fb10c-dart 착수 기록" 없음.
- XB 18:02 표 4경로 대조(메인 작업 트리 bytes/SHA256): **4개 모두 일치**.
  - `backend/core/student_fallback_evidence.py` 2777 `d61f21d9176d807f428017ebe2cfc2cb3451d0773d0268ccee57df4763b0694e`
  - `backend/core/student_matcher_adapter.py` 56511 `6c40249e84d3915805a7b53bceddf985a8aef5a2093961758bc73b09faaab83a`
  - `backend/core/scanner_session.py` 52964 `7e65d180d5381d2f67fce4c880977336cf25d466f661238b5320de9d679c123f`
  - `backend/tests/test_student_fallback_crop_fb10c.py` 11262 `2a33cbfa71bf776d8e1ba2147bdbf9b7fa309f1b26d054a820eb92eb51e461c6`
- XB 목록과 메인 코드 대조(읽기만): `weapon_fallback_review_details`가 4키를 만들고 `attach_student_fallback_details`가 두 폴백 행 details에만 붙인다. `_release_candidate_images`는 승인 review·폐기 review(`discarded_in_scan_page`·`discarded_in_student_page`)·durable commit 성공·close에서 그 후보 evidence와 retained event 안 같은 후보의 evidence에서 `crop_png_base64`만 재귀로 지운다(`crop_source`·`crop_width`·`crop_height` 유지). 목록과 차이 없음.
- Dart 현재 상태(읽기): `ScannerFieldEvidence.fromWire`는 `details`를 임의 Map으로 그대로 받고, `planning_protocol_client.dart`의 `_validScannerCandidate`는 `evidence is List`만 본다 → 새 키를 거부하지 않는다(DTO·검사기 수정 불필요 예상). `student_scan_diagnostic.dart`는 `evidence.details`와 `event.payload`를 그대로 복사한다(XB 지적 그대로).
- 막힘: 대장 막힘 요약에 fb10c-dart 행 없음, 현재 열림 0건. FD-145는 '워커 재량'(권장안 (a): 폴백 필드만 crop additive, 적용·폐기 시 삭제, `images_included:false` 유지) → 권장안대로 처리.
- 고칠 기존 파일(착수 사본 `debug/frontend_fb10cdart/pre/<v7 기준 경로>`)과 WIP(`git status --short <경로>`), 줄바꿈(바이트로 셈):
  - `frontend/lib/services/student_scan_diagnostic.dart`: WIP 없음. LF 171줄.
  - `frontend/lib/ui/pages/scan_page.dart`: **WIP 있음**(스캐너 WIP hunk 19~1765줄 부근 여러 곳, +198/−47). LF 1892줄. 고칠 곳은 폐기 성공·승인 직후·적용 성공 분기와 새 private 메서드 하나로 예정.
- 새 파일(예정): `frontend/lib/services/scanner_review_images.dart`(이미지 키 규칙·재귀 제거·후보/이벤트/최근 요약 사본), `frontend/test/scanner_review_images_fb10c_test.dart`, `frontend/test/scanner_review_images_fb10c_process_e2e_test.dart`.
- 고치지 않음(읽기만): `scanner_service.dart`·`planning_protocol_client.dart`·`mock_app_service.dart`(WIP, 수정 필요 없음 예상), `scan_student_review_workspace.dart`(스캐너 소유), `app_shell.dart`, backend/**·contracts/**.
- WIP는 지우거나 정리하지 않는다.

## fb10c-dart 종료 기록 (2026-10-14, 코드 작성 완료·CF gate 미실행)

FB-10c 학생 무기 폴백 crop의 프론트 개인정보·수명 연결을 끝냈다. wire 수용 확인, 진단 JSON 이미지 재귀 제거, 스캔 화면 보관물의 crop 해제(승인·폐기·적용 성공), 단위·위젯·실제 백엔드 process E2E. crop 표시 카드(FE8-g4)는 범위 밖이라 만들지 않았다.

### 실행 명령·결과

- `flutter analyze`(frontend 전체): 1차 **No issues found(0)**, 메서드 위치 이동·테스트 수정 뒤 2차 **No issues found(0)**. info 포함 0.
- 새 테스트:
  - `flutter test test/scanner_review_images_fb10c_test.dart`: 첫 실행 **+6 −0**. 마지막 확인(아래 묶음 안) +6.
  - `flutter test --concurrency=1 test/scanner_review_images_fb10c_process_e2e_test.dart`: 첫 실행 **+1 −0**. 마지막 확인(아래 process 묶음 안) +1.
- 바뀐 동작에 걸리는 기존 테스트(grep: `ScanPage`·`buildStudentScanDiagnostic`·`student_scan_diagnostic`·`onRecentChanged`·`ScannerRecentSummary`·`reviewScannerCandidate`·`ScannerFieldEvidence`·`ScannerCandidate.fromWire`·`scannerSnapshot`·`recentScans`, golden 제외), json reporter로 파일별 집계. 1차와 최종 모두 **22파일 +276 −0**(실패·skip 0):
  connected_target_fe8d +8, diagnostics_service +2, home_connect_fe8e +10, home_page +5, inventory_review_fb10b +19, mock_scanner_commit_history +9, mock_scanner_service +4, repository_history_scan_latest +48, repository_history_service +24, scan_companion_dock +3, scan_inventory_identity_review +2, scan_page_pause_fb10a +8, scan_page_revision +14, scan_page +17, scan_student_review_workspace +6, scanner_pause_fb10a +39, scanner_protocol_client +6, scanner_review_images_fb10c +6, scanner_target_metadata_fb4 +19, student_page +9, student_scan_diagnostic +2, widget_test +16.
- 중간 확인(메서드 위치 이동 뒤): scanner_review_images_fb10c +6, student_scan_diagnostic +2, scan_page +17, scan_page_revision +14(합 +39).
- process(`--concurrency=1`, 6파일 차례로), 1차와 최종 모두 **+7 −0**: scanner_review_images_fb10c_process_e2e +1, scanner_process_e2e +1, scanner_pause_process_e2e +1, scanner_target_metadata_process_e2e +1, final_p6_process_e2e +2, inventory_review_fb10b_process_e2e +1.
- 잠금 충돌 0(재시도 없음). 로그는 `debug/frontend_fb10cdart/logs/`(실패 줄만 확인).
- `git diff --check`(고친 2파일 + status): exit 0. 새 3파일: 줄 끝 공백 0, 끝 개행 하나. 고친 5파일 모두 LF만(CRLF 0).
- `dart format`: 새 3파일에만 적용. WIP가 있는 `scan_page.dart`와 `student_scan_diagnostic.dart` 전체에는 돌리지 않았다(내 hunk는 손으로 맞춤).
- 3-way 병합 모의(`diff3 -m HEAD사본 pre 현재`, 스크래치 폴더, 저장소·index 변경 없음): `scan_page.dart`·`student_scan_diagnostic.dart` 모두 충돌 0, 병합 결과와 HEAD의 차이는 이 slice 줄뿐(scan_page 45줄). 이 slice가 쓰는 DTO 클래스(`ScannerRecentSummary`·`ScannerFieldEvidence`·`ScannerCandidate`·`ScannerEvent`)는 HEAD와 작업 트리가 같다.

### 고친 파일

- `frontend/lib/services/scanner_review_images.dart`(새, LF): 이미지 규칙 하나. 키 = `crop_png_base64`와 `*_base64`·`*_b64`·`*_png`·`*_jpg`·`*_jpeg`·`*_webp`·`*_image`·`*_images`·`*_screenshot`, `image`·`images`·`screenshot`·`png`·`jpg`·`jpeg`. 값 = 바이트 배열(TypedData), `data:image/`, PNG(`iVBORw0KGgo`)·JPEG(`/9j/`)·GIF(`R0lGOD`)·WEBP(`UklGR`) base64. 재귀 사본(`scannerMapWithoutReviewImages`·`scannerValueWithoutReviewImages`, 원본 불변), 검사(`scannerValueHasReviewImage`), 후보 사본(`scannerCandidateWithoutReviewImages`, 이미지 없으면 같은 객체), 후보 이벤트 사본(`scannerEventWithoutCandidateImages`, 그 후보 id만), 최근 요약 사본(`scannerRecentWithoutCandidateImages`, 그 후보만·개수 그대로).
- `frontend/lib/services/student_scan_diagnostic.dart`(WIP 없음): 후보 `payload`·`evidence.details`·`audit`와 이벤트 `payload`(안의 후보 evidence 포함)를 원래 Map 그대로 넣지 않고 이미지 뺀 재귀 사본을 넣는다. `privacy` 상수(`images_included:false`)는 그대로.
- `frontend/lib/ui/pages/scan_page.dart`(스캐너 WIP 위): import 1줄, `_releaseStudentCandidateImages`(학생 후보만; 지금 후보·`_pendingStartEvents`·`_recent`에서 같은 세션·generation·후보 id 사본만 이미지 없는 사본으로 교체, 최근 요약이 바뀌면 `onRecentChanged` 재게시), 호출 3곳: 폐기 성공, 승인 응답 직후(`_keepCandidate(approved)` 옆), commit 성공.
- 새 테스트: `frontend/test/scanner_review_images_fb10c_test.dart`(6), `frontend/test/scanner_review_images_fb10c_process_e2e_test.dart`(1).
- 고치지 않음: `scanner_service.dart`·`planning_protocol_client.dart`(새 키를 이미 받음), `mock_app_service.dart`(Mock은 학생 crop을 만들지 않음), `process_app_service.dart`, `scan_student_review_workspace.dart`(스캐너 소유, 자체 crop 보관 없음), `app_shell.dart`, `student_page.dart`, backend/**·contracts/**, Lane A 통계 파일, kit, golden harness·golden 테스트, frontend/tool.

### XB 목록 행별 검수(01:39·02:22·15:21·18:02, CF-CONNECTION.md·MASTER_REQUIRED.md)

| XB 목록 행 | 처리 | 근거 테스트 |
|---|---|---|
| optional `evidence.details` 4키(weapon_level/star_fallback만), top-level DTO·method·event 변경 0 | Dart 변경 불필요: `ScannerFieldEvidence.fromWire`가 details를 임의 Map으로 받고, 응답 검사기 `_validScannerCandidate`는 `evidence is List`만 본다. 거부하지 않으므로 타입 검사를 더하지 않았다(프롬프트 조건부 수정) | 단위 "optional crop details pass through…", process E2E 1(실제 응답이 검사기·DTO를 지나 4키 그대로, PNG 매직 바이트 확인) |
| "Existing ScannerFieldEvidence.details is an arbitrary object, so Dart DTO shape changes are zero" | 확인(위) | 같음 |
| 진단: candidate.details와 nested event candidate evidence **두 경로 재귀** 제거, `images_included=false` 유지 | `student_scan_diagnostic.dart` | 단위 "candidate details and nested event candidates…"(중첩 list 안 `panel_png_base64`까지), 위젯(적용 전 저장), process E2E 2 |
| "More generic image-bearing details must also be excluded; do not serialize raw image fields by copying the original map" | 이름·값 규칙 하나로 payload·details·audit·event payload 모두 사본 | 단위 "image keys are removed recursively…" |
| 숫자·문자열 evidence 보존 | 메타·delta·기타 값 유지 | 단위·process E2E(`crop_source` 4건) |
| 진단은 적용 전에도 저장 가능 → 백엔드 삭제만으로 부족 | 백엔드가 crop을 들고 있는 동안 만든 진단도 0건 | 위젯 1(보류·재검증 뒤 저장), process E2E 2 |
| 승인·폐기·적용 성공 뒤 프론트 캐시 후보 **와 이벤트** 사본 정리(또는 fresh snapshot) | 지금 후보·최근 요약(셸 재게시)·시작 전 버퍼 이벤트에서 그 후보만 지움. 화면은 이벤트 원본을 따로 보관하지 않음(아래 표). 진단은 매번 fresh snapshot | 위젯 1·2, 단위 "candidate, event and recent copies…" |
| 보류·수정·재검증·writer 실패/재시도 동안 유지 | 보류·재검증은 해제 호출 없음. 적용 실패는 해제 안 함. 단 스캔 탭 적용은 언제나 승인 review 뒤 commit이라, 백엔드가 승인 때 이미 지운다(아래 근거) | 위젯 1(보류·재검증 유지), 위젯 2(실패 뒤 다른 후보 유지), process E2E 3 |
| 다른 후보 보존 | 같은 세션·generation·후보 id만 | 위젯 1·2, 단위, process E2E 4 |
| Basic Info crop을 상세 패널 캡처로 표시하지 않음 | 표시 자체를 만들지 않음(FE8-g4) | — |
| 저장소 current/history/journal에 crop 없음 | (백엔드 몫) process E2E에서 임시 저장소 전체 파일에 `crop_png_base64`·PNG 시그니처 0 확인 | process E2E 5 |
| inverse_value·다른 폴백 producer 없음 | 이번 범위 아님, Dart에 관련 코드 없음 | — |

### SHA 대조

- 착수·종료 두 번 XB 18:02 표 4경로 bytes/SHA256이 모두 일치(착수 기록과 같은 값). 이 slice는 backend/contracts를 읽기만 했다.

### 이미지 보관 위치(grep: `ScannerCandidate`·`ScannerEvent`·`List<ScannerEvent>`·`Map<String, ScannerCandidate>`·`ScannerRecentSummary`·`recentScans`·`cropPng`·`crop_png_base64`·`Uint8List`, 통계 제외)

| 보관물 | 담는 것 | 학생 crop | 이 slice 뒤 제거 시점 |
|---|---|---|---|
| `ScanPage._candidates` | 지금 후보 | 있음 | 승인 응답 때 이미지 없는 사본(백엔드 응답도 crop 없음), 폐기·적용 성공 때 후보 제거. 보류·재검증(새 revision도 crop)·적용 실패 동안 유지 |
| `ScanPage._recent`(최대 8) | terminal 때 후보 사본 | 있음 | 승인·폐기·적용 성공 때 그 후보만 이미지 없는 사본, `onRecentChanged` 재게시 |
| `AppShell._recentScans` | `_recent` 게시본 | 있음 | 위 재게시로 교체, 계정 변경 때 비움(기존) |
| `HomePage.recentScans` | 셸 목록 전달(후보를 읽지 않음) | 참조만 | 셸 교체를 따름 |
| `ScanPage._pendingStartEvents` | 시작 응답 전 이벤트 | 이론상 | 시작 때 비움(기존) + 해제 때 그 후보 이벤트 사본 교체 |
| `ScanPage._pendingApplies` | 적용 고정 요청(승인된 후보) | 없음(승인 응답은 백엔드가 이미 지움) | 변경 없음(`identical` 비교를 깨지 않음) |
| `ScannerProtocolClient._raceBuffer` | 시작 응답 전 이벤트 | 일시 | 시작 때 remove·연결 끊김 때 clear(기존), 스트림으로만 넘김 |
| `ScannerProtocolClient._events`·`_cursors` | broadcast 스트림 / sequence만 | 보관 없음 | — |
| `ScanStudentReviewWorkspace` 상태 | `widget.candidates`를 읽고 `_drafts`는 payload 값만 | 자체 보관 없음 | —(스캐너 소유, 읽기만) |
| `AppShell._studentCandidate` | handoff 후보 | 현재 없음(학생 후보에는 handoff 버튼이 없다) | 학생 화면 commit 성공 때 비움(기존) |
| 진단 JSON | 매번 새 snapshot으로 만든 문서 | 없음 | 만들 때 재귀 제거 |
| `ScanPage._unresolvedSlots` | 인벤토리 미식별 슬롯 `cropPng` | 학생 아님(인벤토리 정책) | 기존 그대로 |
| `MockAppService._scannerHistory`·`_scannerCandidates` | Mock 백엔드 | 없음(Mock은 crop을 만들지 않음) | — |

### 메타 키 처리 근거

- `crop_source`·`crop_width`·`crop_height`는 남긴다. CF-CONNECTION.md "Crop dimensions/source and other nonimage details can remain for diagnostics."와 백엔드 `remove_student_crop_images`(`crop_png_base64`만 pop)가 같은 결론이다. 진단 검토 때 폴백 행이 crop을 가졌다는 사실과 크기는 계정·화면을 드러내지 않는다.
- 이미지 규칙은 백엔드보다 넓다(이름 규칙 + 값 시그니처). "same kind of base64 image field"를 이름만으로 고정하지 않기 위해서다.

### 승인 시점 근거(writer 실패 재시도)

- 백엔드 `_release_candidate_images`는 승인 review(approve=true)·폐기 review·durable commit 성공·close에서 부른다. writer 실패 동안 crop이 남는 것은 승인 없이 바로 commit하는 경로다(XB 테스트 `test_failed_repository_write_retains_crop_until_successful_original_retry`).
- 스캔 탭 적용은 `candidate.approved`가 아니면 먼저 승인 review를 보내므로, 그 응답 때 백엔드 사본은 이미 없다. 그래서 프론트도 승인 응답 때 지우고, commit 실패(결과 모름·busy·충돌) 때 crop을 되살리지 않는다. 재시도는 고정 요청(id·revision·key)만 다시 보내 crop이 필요 없다.

### golden 변화 예상

- **변화 0.** 화면에 그리는 값(필드·상태·출처·confidence·note)은 바뀌지 않았고 details는 그리지 않는다. golden 장면의 스캔 데이터는 Mock이며 Mock은 crop을 만들지 않는다. golden 테스트는 돌리지 않았다.
- CF gate 예상: analyze 0, 일반 +6, process +1, golden 변화 0.

### 미검증 항목

- 전체 `fe_gate.ps1`·golden 비교·almanac validate·저장소 전체 `git diff --check`: **미실행**(CF 몫).
- Python 전체 테스트: **미실행**(XB 몫; XB 19:27 보고의 현재 RED 1 = C5e 입력 기준, 이 slice와 무관).
- 실제 게임 폴백 crop(실제 Basic Info ROI가 폴백으로 넘어가는 학생): **미실행**(사용자 실기). process E2E는 합성 PIL 이미지를 XB `weapon_fallback_review_details`와 세션 경계 `attach_student_fallback_details`로 보낸 것이다(실제 adapter의 ROI 선택은 XB 테스트 몫).
- 학생 화면(`approved_in_student_page`) 경로: 학생 후보 handoff가 지금 없어 실행 경로가 없다(발견 4).
- 백엔드 재시작·close 뒤 프론트가 들고 있는 보류 후보 crop: 유지된다(발견 2), 실행 확인은 하지 않았다.

### WIP 보존 확인

- `scan_page.dart`: pre 사본(스캐너 WIP 포함)과 끝 내용의 차이는 이 slice hunk 5개(import 5줄, 새 메서드 1016줄, 폐기 1000줄, 승인 1158줄, commit 1187줄 부근)뿐이다. 처음에는 새 메서드를 `_keepCandidate` 바로 뒤(스캐너 WIP가 더한 인벤토리 분기·`_identitySlotKey` 블록과 맞닿음)에 넣었다가, 3-way 병합 충돌을 피하려고 `_newApplyKey` 앞(이 slice hunk 사이, WIP hunk에서 떨어진 곳)으로 옮겼다. 위 diff3 모의에서 충돌 0.
- `student_scan_diagnostic.dart`: WIP 없음, hunk 3개.
- 편집 도구가 줄바꿈을 바꾸지 않았다(편집 뒤 바이트로 셈: 모두 LF, CRLF 0). 복원할 것 없음.
- 다른 WIP 파일(`scanner_service.dart`·`planning_protocol_client.dart`·`mock_app_service.dart`·`process_app_service.dart`·`scan_student_review_workspace.dart`·스캐너 테스트)은 수정 0. `pubspec.yaml`·`pubspec.lock` 변경 0.

### 발견 사항

1. `ScanPage._openRecent`는 최근 요약의 후보를 그대로 되살린다. 이미 적용·폐기한 후보도 다시 검토 목록에 나타날 수 있다(기존 동작, 이 slice에서 바꾸지 않음; 이제 이미지는 없다). FE8-g 결과 검토 slice에서 판단(CF).
2. 보류한 후보의 crop은 `ScanPage._recent`와 `AppShell._recentScans`에 최대 8세션, 계정 변경 전까지 남는다. 백엔드는 close 때 자기 사본을 지우지만 프론트에는 그 신호(세션 종료 이벤트)가 없다. "보류 동안 유지" 규칙대로 두었다. 백엔드 재시작·스캔 탭 이탈 때도 지울지는 CF·XB 판단.
3. 공개 계약 fixture(`contracts/fixtures/scanner_protocol_v1.json`)에 학생 crop details 사례가 없다(인벤토리 `unresolved_slots`의 crop만 있음). 그래서 계약 fixture 양성·음성 테스트는 만들지 못했다. Dart는 4키 타입을 검사하지 않는다(거부가 없어 조건부 수정 대상 아님). FE8-g4에서 crop을 실제로 그릴 때 그 자리에서 base64·양의 정수 검사를 넣는 것을 권한다(CF). fixture 추가는 XB 판단.
4. `AppShell._studentCandidate`(학생 화면 handoff)는 지금 학생 후보를 받지 않는다(스캔 탭 handoff 버튼은 학생이 아닌 후보에만 있음). 학생 handoff를 다시 열면 학생 화면 승인·commit 경로에도 같은 해제가 필요하다(app_shell·student_page, 이 slice 범위 밖).
5. 백엔드 해제(`remove_student_crop_images`)는 `crop_png_base64` 키만 지운다. 다른 폴백 producer가 다른 이미지 키를 쓰면 프론트 진단은 이름·값 규칙으로 빠지지만 백엔드 해제에도 같은 키가 필요하다(XB).
6. Mock은 학생 crop을 만들지 않아 mock 실행에서는 이 경로가 보이지 않는다. FE8-g4에서 crop 카드를 만들 때 Mock 시나리오가 필요하다(CF).
7. 공용 E2E 진입점(`tests.scanner_e2e_backend`)의 학생 matcher는 crop을 내지 않아, process E2E는 테스트 파일 안 inline `-c` 진입점을 썼다(fb10b 발견 1 선례). XB가 공용 진입점에 폴백 crop 행을 두기를 원하면 옮길 수 있다.
8. 위젯 테스트가 부르는 검토 작업 공간 `onRevalidate`는 스캐너 WIP가 인자(`confirmedFields`)를 더했다(HEAD는 3개). 커밋 트리에서도 컴파일되도록 인자 수를 콜백 형태에 맞춰 `Function.apply`로 부른다.
9. 워커 재량 FD: **FD-145** → 권장안 (a)(폴백 필드만 crop additive, 적용·폐기 때 삭제, `images_included:false` 유지)대로 처리.

### 사본·commit.json

- 착수 사본: `debug/frontend_fb10cdart/pre/<경로>`(고친 기존 파일 2개).
- 끝 사본: `debug/frontend_fb10cdart/post/<경로>`(고친 기존 파일 2개와 새 파일 3개).
- `debug/frontend_fb10cdart/commit.json`: slice `fb10cdart`, `status=false`, `post_dir`, modified 2, added 3, `whole = [almanac/workflows/frontend-redesign-status-lane-b.md]`(바뀌는 기준 이미지 없음). message(ASCII) 근거: backend 로그 01:39·02:22·15:21 Dart 목록·18:02 반영 기록, CF-CONNECTION.md·MASTER_REQUIRED.md, README 진단 절, FD-145.
- 인계: `debug/frontend_fb10cdart/output.md`.

### 다음 행동

- fb10c-dart 코드는 끝났다. Lane B는 여기서 멈춘다.
- CF: Lane A(FE7-g)와 이 slice가 모두 멈춘 뒤 XB 18:02 4경로와 같은 소스로 gate 1회(예상: analyze 0, 일반 +6, process +1, golden 변화 0) → XB selected4 커밋(XB 20:20 순서 결정과 C5e RED 1 처리에 따름) → `fe_commit.ps1 -Slice fb10cdart`(scan_page는 3-way 병합, WIP 인접 hunk 없음).
- 발견 1·3·6은 CF, 2는 CF·XB, 5·7은 XB 판단을 기다린다.

## mockdemo 착수 기록 (2026-10-14)

- 상태: 진행 중 → 코드 작성 완료(아래 종료 기록).
- 범위: `--dart-define=BA_PLANNER_MOCK_SCENARIO=design-review`(mock 모드에서만)일 때 main.dart가 검수 시나리오 Mock을 쓴다. 계정 `거모이는존재한다 (v7 UI 테스트)`, 기존 시안 숫자 fixture를 lib 공용 데이터로 옮겨 재사용한다. 값이 없으면 `MockAppService(fullStudentCatalog: true)` 그대로, 실제 백엔드 모드 영향 없음. 화면 코드·golden·서비스 공유 파일(`mock_app_service.dart`) 수정 없음(상속·생성자 주입만). 근거: CF 로그 2026-10-14 01:25 배정, 워크플로 불변식 "mock 기본 실행을 유지한다 … 검수용 fixture".
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `1f73913da099028ba2493655d4bd5c0c3160b570`.
- 착수 전 확인: 이 문서 끝에 다른 "mockdemo 착수 기록" 없음. 대장 막힘 요약: 현재 열림 0건, mockdemo 행 없음 → 막힘 없음.
- 고칠 기존 파일(착수 사본 `debug/frontend_mockdemo/pre/<v7 기준 경로>`, WIP는 `git status --short <경로>`, 줄바꿈은 바이트로 셈):
  - `frontend/lib/main.dart`: WIP 없음. LF 39줄.
  - `frontend/test/statistics_growth_fixture.dart`: WIP 없음. LF 280줄.
  - `frontend/test/statistics_plan_fixture.dart`: WIP 없음. LF 289줄.
  - `frontend/test/inventory_fe6a_fixture.dart`: WIP 없음. LF 373줄.
  - `frontend/test/inventory_history_fixture.dart`: WIP 없음. LF 80줄.
  - `README.md`: **WIP 있음**(다른 세션). LF 196줄. "실제 Python backend로 실행" 절에 한 줄만 더한다(post 사본).
- 옮길 fixture(데이터·순수 함수만 lib로, 테스트 파일은 같은 이름을 export해 기대값 변화 0):
  - `test/statistics_growth_fixture.dart` → `lib/services/design_review/statistics_growth_data.dart`(보유 128 · 학생 목록 170 · 계획 9명 wire). `StatisticsGrowthFixtureExpected`·단위 테스트용 catalog는 test에 남긴다.
  - `test/statistics_plan_fixture.dart` → `lib/services/design_review/statistics_plan_data.dart`(활성 문서 5페이즈 · 문서 계산). `StatisticsPlanFixtureExpected`는 test에 남긴다.
  - `test/inventory_fe6a_fixture.dart` → `lib/services/design_review/inventory_fe6a_data.dart`(카탈로그 · 보유 · 계획 표 · 스캔 표 · 부족 계산). `InventoryFixtureService`(테스트 서비스)는 test에 남기고 옮긴 함수를 부른다.
  - `test/inventory_history_fixture.dart` → `lib/services/design_review/inventory_history_data.dart`(스캔 이력 생성기 · 고정 시계).
  - 옮기지 않음: `statistics_supply_fixture.dart`·`inventory_fe6c_fixture.dart`·`inventory_fe6e_fixture.dart`(한 계정 인벤토리는 FE6-a 하나만 쓴다 — 우선순위 표는 종료 기록), FE8-c 계정 메타(값만 같게 둔다 — 시나리오는 실제 이력 이벤트로 "어제 21:40"을 만든다).
- 새 파일(예정): `frontend/lib/services/mock_design_review_scenario.dart`(스위치 해석 + 시나리오 Mock), 위 데이터 4개, `frontend/test/mock_design_review_scenario_test.dart`.
- 고치지 않음(읽기만): `lib/services/mock_app_service.dart`(스캐너 WIP), `test/goldens/**`(golden_harness 포함), `lib/ui/**`, fb10c-dart 미커밋 파일, `frontend/tool/**`, backend/**·contracts/**.
- WIP는 지우거나 정리하지 않는다.

## mockdemo 종료 기록 (2026-10-14, 코드 작성 완료·CF gate 미실행)

- 상태: 코드 작성 완료. `flutter analyze` 0, 관련 테스트 18파일 188 통과 · 0 실패. golden · 전체 gate · 앱 실행은 실행하지 않았다(CF · 사용자 몫).
- 스위치: `--dart-define=BA_PLANNER_MOCK_SCENARIO=design-review`. `BA_PLANNER_USE_REAL_BACKEND=false`(mock 모드)일 때만 읽는다. 값이 없거나 공백이면 `MockAppService(fullStudentCatalog: true)` 그대로(기본 동작 변화 0), 모르는 이름은 `ArgumentError`(다른 숫자를 조용히 보이지 않도록). 실제 백엔드 분기는 그대로다.
- 앱 실행 명령: `cd frontend; flutter run -d windows --dart-define=BA_PLANNER_USE_REAL_BACKEND=false --dart-define=BA_PLANNER_MOCK_SCENARIO=design-review`

### 바꾼 것

- `frontend/lib/main.dart`: `BA_PLANNER_MOCK_SCENARIO` 상수 하나, mock 분기가 `createMockAppService(scenario:)`를 부른다(import 하나 교체).
- 새 `frontend/lib/services/mock_design_review_scenario.dart`: `createMockAppService`(스위치 해석)와 `MockDesignReviewScenario extends MockAppService implements InventoryClockSource`. `mock_app_service.dart`는 고치지 않았다 — 생성자 주입(`profiles` · `repositoryStates` · `repositoryHistories` · `historyClock`)과 읽기 메서드 상속만 쓴다.
  - 계정 하나 `거모이는존재한다 (v7 UI 테스트)`(id `0000000000000000000000f1`, 초상 airi, 선택됨). Mock 기본 Main 계정은 없다.
  - 계정 상태: 학생 · 목표 = 학생 성장 데이터(보유 128, 목표 9명), 인벤토리 = FE6-a 수량, revision 40.
  - 이력: FE6-a 인벤토리 스캔(31 · 24 · 17 · 10 · 3일 전, 30회) + 학생 스캔 1회(지역 시각 2026-10-04 21:40, 수량 변화 없음, scope airi). 계정 메타 "마지막 스캔"은 모든 스캔(FD-041)이라 "어제 21:40", 인벤토리 KPI "마지막 스캔"은 재화를 적용한 스캔만이라 "3일 전" — 둘 다 시안 그대로.
  - 시계: 지역 시각 2026-10-05 12:00 + 실행 뒤 흐른 시간(`inventoryNow` · `historyClock` 같은 시계, 새 쓰기 이력은 fixture 이력 뒤에 쌓인다).
  - 활성 계획: 생성자에서 Mock 쓰기 경로(`saveRepositoryPlan`)로 Stats-Plan 문서(페이즈 5 · 학생 9명)를 저장한다. 목표 v1 → Mock 문서 이관이 revision을 하나 올려 기대 revision = 41, 저장 뒤 42. Mock 저장은 await 없이 끝나 생성자 반환 전에 반영된다(테스트로 확인).
  - 읽기 상속: `listStudents`(번들 목록에서 성장 데이터 id 170명), `listInventoryItems`(FE6-a 카탈로그), `calculateShortages`(FE6-a 부족 계산), `calculatePlanningDocument`(문서의 페이즈 · 단계 id · 학생 구성이 시안 문서 그대로면 시안 문서 계산, 아니면 Mock 기본 계산), `loadRepositoryPlan`(시안 문서면 계산 요약도 시안 값 — 첫 병목 P2 · 재화 3종).
- 쓰기: 저장 · 스캔 등은 Mock 그대로 메모리 안에서만 바뀌고, 다시 실행하면 위 초기값이다(테스트로 확인). 단계 구성을 바꾸지 않는 계획 편집(이름 · 목표 값)은 시안 문서 계산을 그대로 받는다(발견 7).
- `README.md`: "실제 Python backend로 실행" 절 끝에 검수 시나리오 실행 한 줄(다른 세션 WIP 보존, post 사본).

### 옮긴 fixture와 새 위치

| 테스트 fixture(이름 그대로 `export`) | 새 위치(lib) | test에 남긴 것 |
|---|---|---|
| `test/statistics_growth_fixture.dart` | `lib/services/design_review/statistics_growth_data.dart`(typedef · 보유 128 · 미보유 42 · 애장품 · 계획 9명 · catalog id · 학생 / 목표 wire · 상태) | `StatisticsGrowthFixtureExpected`, 단위 테스트용 `statisticsGrowthFixtureCatalog()` |
| `test/statistics_plan_fixture.dart` | `lib/services/design_review/statistics_plan_data.dart`(재화 키 · 보유 · 페이즈 · 문서 · 계획 상태 · 문서 계산). 계산 요약 map을 `statisticsPlanFixtureCalculationWire`(같은 값, `_resources.length` 그대로)로 꺼냈다 | `StatisticsPlanFixtureExpected` |
| `test/inventory_fe6a_fixture.dart` | `lib/services/design_review/inventory_fe6a_data.dart`(계정 id · revision · 학생 · 단계 이름 · 카탈로그 · 보유 · 계획 표 · 스캔 표 · 상태 wire) + 새 공용 함수 `inventoryFixtureOwnedQuantity` · `inventoryFixtureItem` · `inventoryFixtureShortages`(원래 서비스 안 식 그대로) | `InventoryFixtureService`(호출 수 세기 · 문서 계산, 옮긴 함수를 부른다) |
| `test/inventory_history_fixture.dart` | `lib/services/design_review/inventory_history_data.dart`(전부) | 머리 주석 + export |

- 옮긴 코드는 착수 사본과 같다(`diff`: import 경로만 다름, 위 계산 요약 map 추출, FE6-a 서비스의 `_owned` · `_name` · `_category`를 같은 식의 공용 함수로 바꿈). 테스트 기대값은 고치지 않았다.
- 옮기지 않음: `statistics_supply_fixture.dart` · `inventory_fe6c_fixture.dart` · `inventory_fe6e_fixture.dart`(한 계정의 인벤토리는 FE6-a 하나 — 아래 일치표), FE8-c 계정 메타(`account_editor_fe8c_test.dart`는 요약 응답을 덮어써 마지막 스캔을 만든다. 시나리오는 이름 · 초상 값만 같게 두고 실제 학생 스캔 이력으로 "어제 21:40"을 만든다 — 테스트 파일은 고치지 않았다).

### 화면별 시안 일치표(우선순위)

한 계정에서 화면마다 다른 시안 예시 값을 동시에 맞출 수 없다. 우선순위: ① 인벤토리 탭 KPI · 리오 엘레프(CF 지시 ②, FE6-a) ② Stats-Growth(학생 원천) ③ Stats-Plan · 계획 활성 문서(계획 원천) ④ 계정 메타 마지막 스캔. 학생 수 · 인벤토리 원천을 공유하는 나머지 화면은 근사다.

| 화면(artboard) · 여는 방법 | 일치 | 정확한 값 / 근사 이유 |
|---|---|---|
| Inventory · 인벤토리 탭 "부족한 것" | **정확**(KPI · 리오 엘레프) | KPI `+3 지난 스캔 대비` · `−1` · 최근 감소 `6종` · 마지막 스캔 `3일 전`, 리오(무장)의 엘레프 1 / 450, 스파크라인 0 · 0 · 1 · 1 "순변화 +1 · 이전 스캔과 이상 없음"(golden `inventory`와 같은 데이터). 근사: 사용 학생 이름 — 리오(무장) · 토키(무장)은 학생 목록 170명 밖이라 id(`rio_battle`)로 보인다(발견 2), 단계별 사용처는 활성 계획(Stats-Plan 문서) 계산이라 FE6-a 단계 글자가 없다(발견 3) |
| Inventory-All · 인벤토리 → 전체 보기 | **정확**(수량 · 카탈로그) | golden `inventory-all`과 같은 카탈로그 · 수량. 학생 이름 · 사용처는 위와 같은 근사 |
| Stats-Growth · 통계 → 학생 성장 | **정확** | KPI 128 / 170 · 63.4% · 64명 · 8명 · 9명, A1 3 · 5 · 9 · 12 · 15 · 18 · 22 · 19 · 14 · 11, 60~70% 구간 계획 2명(golden `statistics-growth`와 같은 데이터). 시안끼리 모순인 "완전 육성 22명" · A2 60.5%는 FE7-b 발견 1 · 3 그대로 |
| Stats-Plan · 통계 → 계획 집계 | **정확**(첫 부족 · 막힌 학생 · 범위 · C3) / 근사(충족 · C1 · C2) | 범위 칩 "활성 계획 · 9명 · 페이즈 5", KPI 첫 부족 P2 · 기술 노트 (최상급), 막힌 학생 6명, C3 74 · 30 · 15%(근거 −18 · −23 · −21 · −12, 누적 −74). 충족률 · 부족 재화 KPI와 C1 · C2는 부족 계산(FE6-a 인벤토리) 값이라 golden `statistics-plan`(supply fixture 72% · 14종 등)과 다르다. 크레딧 98.4M / 261.5M · 엘리그마 1020 / 2245는 FE6-a에도 같은 값이라 C1에 보일 것으로 예상한다(미실행) |
| 계획 탭 활성 계획 · Detail | **정확**(Stats-Plan과 같은 문서 · 계산) / 근사(Plan Detail 시안 학생) | 페이즈 5 · 학생 9명 · 첫 병목 P2. 시안 학생 리오(무장) · 노아 · 미카 자리는 아리스 · 히나 · 카즈사(FE7-g 발견 2 그대로) |
| Title-Accounts 편집 · 타이틀 → 설정 → 계정 관리 → 수정 | **정확**(이름 · 초상 · 마지막 스캔) / 근사(보유) | `거모이는존재한다 (v7 UI 테스트)`, 초상 airi, "마지막 스캔 어제 21:40". 보유는 `보유 128 / 170`(시안 217 / 265) — 보유 · 전체는 Stats-Growth와 같은 원천(계정 상태 학생 수 · 학생 목록 수)이라 Stats-Growth가 우선 |
| Stats-Inventory · 통계 → 인벤토리 현황 | 근사 | 인벤토리 탭과 같은 계정 인벤토리(FE6-a 13품목 · 계획 10행)에서 계산된다. 시안 72% · 14종 · 6종 · 3 / 6 · 엘레프 1종 · B1 6행은 golden `statistics-inventory`(supply fixture)로 본다 |
| Inventory-Analysis(S1~S5) · 인벤토리 → 분석 | 근사 | FE6-a 카탈로그(학교 1곳 · 오파츠 1종 · 장비 1종)로 그려져 행이 적고, S5는 FE6-a 이력의 순증감이다(시안 +120 · +24 · −9 · −14 아님). golden `inventory-analysis` · `test/inventory_analysis_page_test.dart`로 본다 |
| Inventory-Tiers · 분석 → 티어별 충족률 | 근사 | 같은 이유. golden `inventory-tiers` · `test/inventory_tiers_page_test.dart` |
| 헤더 지표(학생 · 인벤토리) | 근사 | Mock 고정값 42 · 186(시안 217 · 1,284). 계정 데이터가 아닌 `AppServiceState` 값이라 바꾸지 않았다(발견 1) |

### golden 변화 0 근거(golden 미실행)

1. 기본 Mock · golden Mock 불변: `lib/services/mock_app_service.dart`와 `test/goldens/**`(golden_harness 포함)를 이 세션에서 편집하지 않았다(`git status` 상 `test/goldens` 변경 없음, `mock_app_service.dart`의 diff는 착수 전부터 있던 스캐너 WIP). golden은 `BAPlannerApp(service: …)`를 직접 만들고 `main.dart`를 거치지 않는다.
2. 옮긴 fixture를 import하는 golden 6장면(`inventory` · `inventory-all` · `inventory-analysis` · `statistics-growth` · `statistics-inventory` · `statistics-plan`)의 입력은 같은 이름 · 같은 코드다(`diff`로 확인: import 경로만 다름, 계산 요약 map은 같은 값을 상수로 꺼냄, FE6-a 서비스는 같은 식의 공용 함수를 부름). 다른 golden 파일은 바뀐 파일에 닿지 않는다(import 그래프로 확인).
3. golden 테스트 파일도 `flutter analyze`(test 포함) 0 이슈로 그대로 컴파일된다.
4. 같은 fixture 숫자를 단언하는 비-golden 테스트(통계 성장 · 계획 · 공급, 인벤토리 분석 · 이력 · 페이지 · 티어 등)가 모두 그대로 통과했다.

### 실행한 명령과 결과(사용자 PC, `frontend` 폴더)

- `flutter analyze`: 1차 2 info(`unnecessary_import`, `use_null_aware_elements`) → 고침 → 0, 테스트 추가 뒤 error 2(`RepositoryState.toWire` 없음, 새 테스트) → 고침 → **최종 0 issues**(`debug/frontend_mockdemo/logs/analyze_final.txt`).
- `flutter test test/mock_design_review_scenario_test.dart`: 9 통과(1차), 화면 테스트 2건 추가 뒤 11 통과.
- 최종 `flutter test`(18파일 한 번, `logs/tests_final.json`): `mock_design_review_scenario_test` 11 · `inventory_analysis_page_test` 8 · `inventory_controller_test` 13 · `inventory_history_page_test` 11 · `inventory_page_test` 9 · `inventory_review_fb10b_test` 19 · `inventory_shell_lazy_test` 1 · `inventory_tiers_page_test` 7 · `inventory_view_model_test` 13 · `statistics_growth_projection_test` 11 · `statistics_growth_view_test` 12 · `statistics_plan_projection_test` 7 · `statistics_plan_view_test` 9 · `statistics_supply_projection_test` 8 · `statistics_supply_view_test` 11 · `account_editor_fe8c_test` 9 · `statistics_workspace_test` 13 · `widget_test` 16 — **188 통과 · 0 실패**. 첫 15파일은 새 테스트와 바뀐 fixture에 import로 닿는 비-golden 테스트 전부(import 그래프로 셈), 뒤 3파일은 계정 · 통계 · 앱 셸 확인용. `main.dart`를 import하는 테스트는 없다. 잠금 충돌 없음.
- `git diff --check`(고친 6파일 + status): exit 0. 새 6파일: 줄 끝 공백 0, 끝 개행 하나(`git diff --no-index --check`). 모든 파일 LF(CR 0) — 착수 기록을 처음 덧붙일 때 CRLF로 쓴 23줄을 바로 LF로 되돌렸다(이 문서는 원래 LF).

### 새 테스트(`test/mock_design_review_scenario_test.dart`, 11)

- 스위치: 값 없음 · 공백 → `MockAppService`(계정 · 상태 · 학생 목록 · 인벤토리 카탈로그가 `MockAppService(fullStudentCatalog: true)`와 같음, 시계 없음), `design-review` → 시나리오, 모르는 이름 → `ArgumentError`.
- 시나리오: 계정 선택 · 이름 · 초상, Stats-Growth(128 / 170 · 구간 · 63.4% · 64명 · 9명, 번들 학생 목록으로), 활성 계획(페이즈 5 · 첫 병목 P2 · 목표 9명 · 첫 부족 P2 기술 노트 (최상급) · 막힌 학생 6 · C3), 단계 구성이 바뀌면 Mock 기본 계산, 인벤토리 컨트롤러 KPI(+3 · −1 · 6 · 3일) · 리오 스파크라인 · 1 / 450, 계정 메타 `보유 128 / 170 · 마지막 스캔 어제 21:40`, 쓰기는 메모리 안 · 새 시나리오는 초기값.
- 화면: `StatisticsPage` KPI 띠 `128` · `63.4%` · `64명` · `8명` · `9명` · `/ 170 · —`, `InventoryPage` KPI `+3 지난 스캔 대비` · `−1` · `6종` · `3일 전`(2560×1392, 예외 없음).

### 검수표(사용자 · 미실행)

앱 실행 명령: `cd frontend; flutter run -d windows --dart-define=BA_PLANNER_USE_REAL_BACKEND=false --dart-define=BA_PLANNER_MOCK_SCENARIO=design-review`

| 탭 · 여는 방법 | 볼 숫자 |
|---|---|
| 타이틀 | 계정 `거모이는존재한다 (v7 UI 테스트)` · 초상 airi |
| 타이틀 → 설정(톱니) → 계정 관리 → 수정 | 메타 줄 `보유 128 / 170 · 마지막 스캔 어제 21:40`(시안 217 / 265는 근사) |
| 통계 → 학생 성장 | KPI 128 `/ 170` · 63.4% · 64명 · 8명 · 9명, A1 60~70% 막대 22명이 가장 높음 |
| 통계 → 계획 집계 | 범위 칩 `활성 계획 · 9명 · 페이즈 5`, 첫 부족 `P2` · 기술 노트 (최상급), 막힌 학생 `6명`, C3 세 줄 74 · 30 · 15% |
| 인벤토리(부족한 것) | KPI `+3 지난 스캔 대비` · `−1` · `6종` · `3일 전`, 리오(무장)의 엘레프 1 / 450 · 스파크라인 점 4개 0 · 0 · 1 · 1 |
| 인벤토리 → 전체 보기 | golden `inventory-all`과 같은 수량 |
| 계획 탭 | 활성 계획 페이즈 5 · 학생 9명 · 첫 병목 P2 |

### 미검증(미실행)

- 실제 앱 실행 눈 확인(사용자), golden 비교 · 전체 `fe_gate.ps1`(CF), `flutter build windows --release`. 시나리오 시계는 지역 시각이라 "어제 21:40" · "3일 전"은 어느 시간대에서도 같아야 하지만 이 PC 시간대 밖에서는 확인하지 않았다.
- 일치표의 근사 화면에 실제로 보일 숫자(Stats-Inventory KPI 등)는 계산해 보지 않았다.

### WIP 보존 확인

- `README.md`: 착수 사본 대비 diff = 새 2줄(문장 + 빈 줄)뿐, 다른 세션 WIP 그대로. post 사본 `debug/frontend_mockdemo/post/README.md`.
- `mock_app_service.dart` · fb10c-dart 미커밋 파일(`scan_page.dart` · `student_scan_diagnostic.dart` · `scanner_review_images.dart`와 테스트) · `lib/ui/**` · `test/goldens/**` · `frontend/tool/**` · backend/**·contracts/**: 편집 0회.
- 착수 사본 `debug/frontend_mockdemo/pre/`, 끝 사본 `debug/frontend_mockdemo/post/`(고친 6파일 모두), commit.json `post_dir`.

### 발견 사항

1. **헤더 지표**(학생 · 인벤토리)는 `AppServiceState.studentCount` · `inventoryItemCount`의 Mock 고정값 42 · 186이고 계정 데이터와 무관하다(Process는 0으로 시작). 시안 217 · 1,284가 "보유 학생 수 · 인벤토리 항목 수"인지 메타 수인지 정해지지 않아 시나리오에서 바꾸지 않았다 — CF 판단.
2. **인벤토리 사용 학생 이름**: FE6-a 계획 학생 리오(무장) · 토키(무장)은 성장 데이터 학생 목록 170명(id 앞 170명) 밖이라 인벤토리 상세에 id로 보인다. 학생 목록을 늘리면 Stats-Growth `/ 170`이 바뀐다 — 고치려면 FE6-a 계획 학생을 170명 안 학생으로 바꾸는 fixture 변경(golden `inventory` 변화)이 필요하다. CF 판단.
3. **인벤토리 단계별 사용처**: 활성 계획이 Stats-Plan 문서(재화 3종)라 FE6-a 재화 대부분은 "활성 계획 계산에 이 재화를 쓰는 단계가 없습니다."가 될 것으로 본다(엘리그마만 P1~P5 단계, 미실행 — 코드 읽기 근거). 시안 Inventory 상세의 단계 글자와 다르다.
4. **같은 원천의 시안 모순**: 계정 메타 "보유 217 / 265"와 Stats-Growth "128 / 170"은 같은 원천(계정 상태 학생 수 · 학생 목록 수)이라 동시에 맞출 수 없다. Stats-Inventory(supply fixture)와 Inventory 탭(FE6-a)도 같은 계정 인벤토리라 둘 중 하나다. 화면 묶음을 따로 보려면 시나리오 이름을 늘리는(예 `design-review-inventory-analysis`) 후속이 가능하다 — CF 판단.
5. **레이어**: 시나리오가 시계 계약 `InventoryClockSource`(`lib/ui/inventory/inventory_controller.dart`)를 구현하려고 `lib/services` → `lib/ui` import를 쓴다(기존 `mock_app_service.dart`도 `ui/models`를 import). 계약 위치 정리는 CF 판단.
6. **파일 소유 문구**: 워크플로 "Lane A·B 프론트 병렬" 문단은 `lib/services/**`를 Lane A만 고친다고 적지만 이번 배정은 Lane B가 `lib/services`에 새 파일을 둔다(공유 파일 수정은 없음). 배정대로 진행했다 — 문서 정리는 CF.
7. **계획 편집 뒤 계산**: 시나리오는 문서의 페이즈 · 단계 id · 학생 구성이 시안 문서와 같으면 시안 문서 계산을 준다. 목표 값만 바꾸는 편집에는 계산이 바뀌지 않고(고정 응답), 구성이 바뀌면 Mock 기본 계산(재화 없음)으로 내려간다. Mock 쓰기 동작 자체는 그대로다.
8. FD: 이 slice에 걸린 '열림' · '워커 재량' FD 없음.

### 다음 행동

- CF: 레인 워커가 모두 멈춘 뒤 `fe_gate.ps1` 1회(golden 전 장면 변화 0 예상) → `fe_commit.ps1 -Slice mockdemo -DryRun` → 커밋(README는 post 3-way 병합). 사용자: 위 앱 실행 명령으로 검수표 확인. 발견 1 · 2 · 4 · 5 · 6은 CF 판단.
- 인계: `debug/frontend_mockdemo/output.md`.

## tidy1 착수 기록 (2026-10-14)

- 상태: **코드 완료(아래 tidy1 종료 기록), CF gate 미실행**. 시작 SHA = `3995e1008cbff348b2afc4064d38159d39ed52a6`(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`). 착수 전 이 문서에 다른 "tidy1 착수 기록" 없음(grep 0건).
- 범위: 작은 후속 6건(① FD-108 탭 이동 intent 확장 ② 목록 reveal ③ 키트 · 코드 주석 정정 ④ 시나리오 목록 1280×720 넘침 ⑤ 시계 계약 위치 ⑥ idempotency key 패턴 점검). 화면 디자인 변경 없음(④ 좁은 창만).
- 막힘: 대장 "slice별 막힘 요약" 현재 `열림` 0건. FD-108 · FD-173 · FD-086은 워커 재량(종료 기록에 처리).
- 이번 라운드 예외(프롬프트): `lib/ui/app_shell.dart` · `lib/ui/navigation/**`는 Lane B가 최소 diff, `lib/ui/kit/**`는 주석만.
- 고칠 기존 파일(착수 사본 `debug/frontend_tidy1/pre/<v7 기준 경로>`, 27개 작업 트리와 cmp 일치). **모두 WIP 없음**(`git status --short <경로>` 빈 줄). 줄바꿈은 그대로 유지(`git ls-files --eol`: `inventory_page.dart` · `settings_page.dart` · `plan_section_layout.dart` · `repository_profile_panel.dart` CRLF, 나머지 LF).
  - ① `lib/ui/navigation/app_navigation_intent.dart` · `lib/ui/app_shell.dart` · `lib/ui/pages/inventory_page.dart` · `lib/ui/inventory/inventory_workspace.dart` · `inventory_analysis_sections.dart` · `inventory_opa_sections.dart` · `lib/ui/widgets/plan_section_layout.dart` · `lib/ui/pages/student_page.dart` · `lib/ui/widgets/growth_calculator_section.dart`
  - ② `lib/ui/pages/inventory_page.dart` · `lib/ui/inventory/inventory_workspace.dart` · `lib/ui/widgets/student_section_layout.dart`
  - ③ `lib/ui/kit/section_morph.dart` · `lib/ui/kit/diagonal_scrollbar.dart`(주석만) · `lib/ui/inventory/inventory_analysis.dart`(주석)
  - ④ `lib/ui/widgets/plan_scenario_list.dart`
  - ⑤ 새 `lib/services/app_clock.dart`, `lib/ui/inventory/inventory_controller.dart` · `lib/ui/widgets/account_section_cluster.dart` · `lib/services/mock_design_review_scenario.dart` · `lib/services/design_review/inventory_fe6a_data.dart`(주석), 테스트 `account_editor_fe8c_test.dart` · `inventory_fe6a_fixture.dart` · `inventory_fe6c_fixture.dart` · `inventory_history_page_test.dart`(주석) · `mock_design_review_scenario_test.dart`
  - ⑥ `lib/ui/models/plan_flow_save.dart` · `lib/ui/pages/settings_page.dart` · `lib/ui/widgets/account_section_cluster.dart` · `plan_scenario_list.dart` · `plan_section_layout.dart` · `repository_profile_panel.dart`
  - 이 문서(`almanac/workflows/frontend-redesign-status-lane-b.md`, LF)
- 새 파일(예정): `lib/services/app_clock.dart`, 테스트 `test/app_navigation_tidy1_test.dart` · `test/tidy1_followups_test.dart`.
- 고치지 않음: `lib/ui/statistics/**` · `lib/statistics/**` · `statistics_page.dart`(Lane A), 스캐너 WIP(`scan_page.dart` · `scan_companion_dock.dart` · `scanner_service.dart` · `planning_protocol_client.dart` · `process_app_service.dart` · `mock_app_service.dart`), 스캐너 · 택틱 소유 파일, golden harness · 기존 golden 테스트, `frontend/tool/**`, backend · contracts, 키트 코드.

## tidy1 종료 기록 (2026-10-14, 코드 작성 완료 · CF gate 미실행)

작은 후속 6건을 끝냈다. 화면 디자인 변경은 ④(좁은 창 넘침)뿐이고 기준 viewport 모습은 그대로다. 새 서비스 메서드 · 백엔드 · 계약 · 키트 코드 변경 없음(키트는 주석만). HEAD는 착수 때와 같다(`3995e100`).

### 실행한 명령과 결과(이 PC, `frontend` 폴더)

로그는 `debug/frontend_tidy1/logs/`이고 실패 줄(`[E]` · `EXCEPTION` · `Some tests failed` · `error •`)만 찾았다.

| 명령 | 결과 |
|---|---|
| `flutter test test/tidy1_followups_test.dart`(진단, 고치기 전) | −1: 1280×720 목록에서 RenderFlex 넘침 3건 재현 — `plan_scenario_list.dart` 1139:14(123px, "나란히 비교" 버튼 안 칸 21px) · 1343:12(37px, `plan-scenario-filter-row`) · 2154:25(1.8px, 활성 계획 행 제목 줄). FE5-f1 발견 1과 같은 줄 · 같은 수치 |
| 같은 파일(④ 고친 뒤) | +1 −0 |
| `flutter analyze`(⑤ 뒤 · 인벤토리 · 계획 · 학생 쪽마다 부분 실행) | 1회 error 1(`RenderAbstractViewport` import 없음) → 고침, 나머지 0 |
| `flutter analyze test/app_navigation_tidy1_test.dart` | warning 1(쓰지 않는 import) · error 3(카탈로그 항목 필수 인자) → 고침 → 0 |
| `flutter test test/app_navigation_tidy1_test.dart`(1차) | +6 −2: 인벤토리 reveal(기본 Mock 카탈로그는 종류마다 1개라 스크롤할 것이 없음 — 테스트 서비스가 장비 60종을 더하게 고침) · 학생 목록(없는 초상 그림 — 실제 초상 id 30명으로 고침). 구현 문제 아님 |
| 같은 파일(2차) | 불러오기 실패: Lane A 작업 중 `lib/ui/statistics/statistics_workspace.dart` 컴파일 오류(앱 셸이 통계를 import). 이 slice 파일이 아니어서 고치지 않고 다음 실행으로 넘겼다 |
| 관련 68파일 한 번에(`--file-reporter json`, `logs/related_1.json`) | **+824 −0**(그 사이 Lane A 컴파일 오류가 풀림) |
| `flutter test test/tidy1_followups_test.dart`(④ 기준 · 좁은 창, ⑥ 추가 뒤) | **+3 −0** |
| `flutter analyze`(최종, 전체) | **4 issues — 모두 Lane A 새 파일** `test/statistics_history_projection_test.dart`(error 4, `RepositoryState.toWire` 없음, FE7-h 작업 중). tidy1 파일만 analyze(`logs/analyze_scope.txt`, 수정 · 새 파일 30개): **No issues found**(info 포함 0) |
| 관련 69파일 한 번에(위 68 + `statistics_app_shell_test`, `logs/related_final.json`) | **+826 −2** — 실패 2건은 모두 `statistics_app_shell_test`, 원인은 Lane A 새 파일 `lib/ui/statistics/statistics_history_charts.dart:115` Column 넘침(0.865 · 25px). tidy1이 고친 파일 아님. 나머지 68파일 −0 |
| `git diff --check`(고친 27파일) · 새 3파일 줄 끝 공백 | 0 · 0 |
| 줄바꿈 · 끝 개행(python으로 pre와 비교) | 27파일 모두 착수 때와 같은 줄바꿈(`inventory_page.dart` · `plan_section_layout.dart` · `settings_page.dart` · `repository_profile_panel.dart` CRLF, 나머지 LF), 끝 개행 하나. 새 3파일 LF · 끝 개행 하나(`dart format`은 새 파일에만) |

관련 68파일(최종, 모두 −0): account_editor_fe8c +9, account_manager_fe8b +6, app_navigation_fe7d +13, app_navigation_tidy1 +11(새), connected_target_fe8d +8, developer_tools_app +12, geometry/diagonal_geometry +5, growth_calculator_adapter +24, growth_calculator_rules +15, growth_calculator_state +16, growth_calculator_view +24, home_app_shell +1, home_connect_fe8e +10, inventory_analysis_page +8, inventory_analysis +16, inventory_controller +13, inventory_currency_readonly +2, inventory_history_page +11, inventory_history +33, inventory_opa_page +6, inventory_opa +9, inventory_page +9, inventory_review_fb10b +19, inventory_shell_lazy +1, inventory_tiers_page +7, inventory_tiers +9, inventory_view_model +13, kit/diagonal_scrollbar +8, kit/section_morph +7, mock_design_review_scenario +11, plan_detail_tabs +8, plan_element_builder +47, plan_flow_authoring +18, plan_flow_goal_step +23, plan_flow_handoff +23, plan_flow_order_step +19, plan_flow_presets +13, plan_flow_save +15, plan_flow_student_step +8, plan_flow +15, plan_home_detail +9, plan_preset_manager +5, plan_scenario_compare +7, plan_scenario_comparison +2, plan_scenario_detail +12, plan_scenario_list +10, plan_scenario_preview +9, planning_page +17, profile_delete_fb2d +17, repository_profile_panel +1, scan_inventory_identity_review +2, scan_page_revision +14, scenario_service +2, school_labels +3, section_template_studio +15, settings_page +10, student_bond_gauge +12, student_card_de +17, student_filter_followups +4, student_filter_modal +7, student_form_cycle +10, student_page +9, student_search_section +13, student_studio_layout +45, tidy1_followups +3(새), title_page +25, widget +16, widgets/section_surface +5.

- 걸리는 기존 테스트 찾기: test/ 전체를 `app/app.dart|app_shell|InventoryPage(|inventory_|StudentPage(|student_section_layout|StudentDiagonalList|PlanningPage(|PlanSectionLayout|plan_scenario_list|PlanScenario|plan_flow_save|PlanFlowSaveController|account_section_cluster|AccountSectionCluster|SettingsPage|settings_page|repository_profile_panel|RepositoryProfilePanel|growth_calculator_section|GrowthCalculator|app_navigation_intent|mock_design_review|AppClockSource|diagonal_scrollbar|section_morph`로 grep해(golden · 스캐너 WIP 테스트 · process E2E 제외) 모두 돌렸고, 계획 흐름 2 · 3단계 테스트 2개를 더했다. 뺀 것: `metadata_manager_dto_test` · `planning_protocol_contract_test` · `repository_history_*`(이름만 걸림, 무관), `statistics_*`(Lane A 작업 중, 셸 확인용 `statistics_app_shell_test`만 돌림).
- 빌드 잠금 충돌 없음. `flutter analyze` · `flutter test`가 pub get을 돌렸지만 `pubspec.lock` · `pubspec.yaml` 변화 없음.
- 실행하지 않음: golden(`test/goldens/**`), 전체 `fe_gate.ps1`, `-UpdateGoldens`, `fe_commit.ps1`, 맨 `flutter test`, process E2E, `codealmanac validate`.

### 항목별 결과

| # | 결과 | 내용 |
|---|---|---|
| ① FD-108 intent 확장 | **완료** | 인벤토리 → 계획 버튼 4곳이 이동 의도다. 상세 "계획에서 보기" = `PlanNavigationIntent.resource(그 재화, origin 인벤토리)`, 오파츠 상세 "계획에서 쓰는 단계 보기" = 계획에 쓰는 티어(머리 아이콘 티어가 계획에 있으면 그것, 아니면 계획에 있는 가장 높은 티어, `inventoryOopartPlanResource`), "계획 열기"(계획 없음) · 학교 플라이아웃 "계획에서 보기 →" = `PlanNavigationIntent.home()`(payload 없음, 학교 · 학생 필터가 계획 홈에 없다). 계획 탭: 재화 의도는 흐름을 열지 않고 활성 계획 Detail 홈 S3를 "전체" 탭 + 그 재화 선택으로 바꾼다(S2에 그 재화를 쓰는 단계 강조). 활성 계획을 읽기 전이면 읽은 뒤 고른다. 그대로 열기는 아무것도 바꾸지 않는다(전 `_open`과 같음). 계산기 FD-173: 연결만 준비(아래). 통계 "← 통계" 칩 동작은 그대로 |
| ② 목록 reveal | **완료** | 인벤토리: 이동 의도로 행을 고르면 `InventoryRevealRequest`(의도마다 새로, 한 번만 소비)를 워크스페이스에 넘기고, 그 행(부족 위험 목록 행 · 전체 보기 타일)이 처음 그려진 다음 프레임에 일부라도 화면 밖이면 목록 가운데로 스크롤한다. 키트 `DiagonalScrollViewport`는 고치지 않았다 — 행 안에서 자기 `Scrollable.position`과 `RenderAbstractViewport.getOffsetToReveal`을 쓴다(키트 viewport에는 reveal API가 없고, 기존 `controller` 주입은 같은 자리의 다른 viewport가 컨트롤러를 나눠 쓰는 위험이 있어 피했다). 학생 S2 목록 보기: `StudentDiagonalList`에 그리드와 같은 `revealStudentId` · `revealRequest`(가운데 정렬, `studentListRevealOffset`) — 최근 본 학생 · 통계 이동 둘 다 목록 보기에서도 스크롤한다 |
| ③ 주석 정정 | **완료(코드 변경 0)** | `kit/section_morph.dart` 머리(지운 `plan_phase_editor.dart` → "FE5-f2에서 지웠다"), `kit/diagonal_scrollbar.dart` 머리(계정 = 표준 썸 + 공용 포그, 레일 점 2종 · 페이즈 편집기 지움, 그 값은 쓰는 화면 없음)와 같은 파일 doc 주석 5줄(옛 페이즈 편집기 · 옛 계정 화면), `inventory/inventory_analysis.dart` S5 seg 주석(이력 집계 위치). 키트 diff의 +/− 줄은 모두 `//` · `///` 줄이다(grep 확인) |
| ④ 1280×720 넘침 | **완료** | `plan_scenario_list.dart` 3곳: "나란히 비교" 버튼 = `LayoutBuilder`로 칸이 72px(`PlanScenarioListMetrics.compareRunLabelMinWidth`)보다 좁으면 아이콘만, 넓으면 글자 `Flexible` + 말줄임 · 필터 줄 = `Spacer` + 글자 → `Expanded` + 오른쪽 정렬 말줄임 · 활성 계획 행 칩 = `Flexible(IntrinsicWidth(...))` + 말줄임. 1280×720 넘침 0(테스트), 기준 viewport는 글자 그대로 · 말줄임 없음(테스트) |
| ⑤ 시계 계약 위치 | **완료(동작 변화 0)** | 새 `lib/services/app_clock.dart`: `AppClockSource { DateTime get clockNow; }` + `appClockNow(service)`. 인벤토리 컨트롤러(같은 식), 계정 메타(`appClockNow`), 검수 시나리오(`implements AppClockSource`)가 쓴다. `lib/services/mock_design_review_scenario.dart`의 `lib/ui` import가 없어졌다. 테스트 fixture 3개(`inventory_fe6a_fixture` · `inventory_fe6c_fixture` · `account_editor_fe8c_test`)와 시나리오 테스트를 새 이름으로 바꿨다. **typedef는 두지 않았다**: 멤버 이름도 `inventoryNow` → `clockNow`로 바꿔(인벤토리 이름이 공용 계약에 남지 않게) typedef로는 구현 쪽 소스 호환이 안 되고, 착수 · 종료 때 lib · test 전체 grep에서 옛 이름 참조 0(Lane A 작업 파일 포함)이었다 |
| ⑥ idempotency key | **완료** | 아래 표. 같은 위험 10곳(파일 6개)에 fb10b와 같은 순번(`-${++_keySequence}`, 인스턴스마다)을 붙였다. key 모양만 바뀐다(백엔드는 key를 불투명 문자열로 본다) |

### `app_shell.dart` diff(+2 −1)와 이유

- 학생 페이지에 `onNavigate: _navigate` 1줄(계산기 FD-173 연결 준비), 인벤토리 페이지 `onOpenPlan: () => _open(AppSection.plan)` → `onNavigate: _navigate`(인벤토리 → 계획 이동을 의도로). 다른 줄 변경 0. 복귀 칩을 통계 출발만 보이게 하는 것은 셸이 아니라 의도 모델(`returnLabel`이 통계 출발 밖에서 null)에서 했다 — 셸 머리말은 이미 `returnLabel == null`이면 칩을 그리지 않는다.
- 셸의 다른 `_open` 이동은 그대로 두었다(이유): 스캔 탭(`onOpenScan` 4곳 · 통계 다시 스캔)은 수신 페이지가 스캐너 WIP(`scan_page.dart`)라 의도를 받을 수 없고 payload도 없다. 홈 카드 · 설정 → 진단 · Studio는 주 탭 메뉴와 같은 이동이라 payload가 없다. 계산기 "이 목표로 계획에 추가"는 `_open`이 아니라 기존 학생 넘기기(`PlanningStudentSeed`, FE4-g) 길이다.

### FD 처리

- **FD-108(워커 재량, 권장안 계속)**: 인벤토리 출발 이동이 같은 의도를 쓴다. "← 통계" 칩은 시안대로 통계 출발만(다른 출발은 칩 없음 — 발견 1).
- **FD-173(워커 재량, (c) 유지)**: 계산기 모드 값 `GrowthCalculatorModeData.onOpenInventory`(셸 안에서 `InventoryNavigationIntent.row(재화, origin 학생)`)까지 연결했고 버튼은 그리지 않는다. 근거: 권장안 (a)는 "계산기 부족 재화 **키들**을 강조 필터로" 넘기는 것인데 인벤토리 수신부는 행 하나만 받는다(종류 · 보기로 거른 뒤 한 행 선택). 부족 재화 여러 개를 강조하는 인벤토리 필터 상태는 FE6 쪽 기능 추가라 이번 범위(작은 후속)를 넘는다. (c)의 조건("FE6-a · FE7-d 전까지")은 이제 채워졌으므로 버튼을 켤지는 CF 판단(발견 4).
- **FD-086(워커 재량)**: 이 slice에서 바꾼 것 없음(④는 시나리오 목록 화면이고 4열 비교 화면에 닿지 않는다).
- 막는 `열림` FD 없음.

### idempotency key 표(`microsecondsSinceEpoch` grep, `lib/**`)

| 위치(현재 줄) | 용도 | 같은 위험(빠른 두 요청이 같은 key) | 처리 |
|---|---|---|---|
| `ui/inventory/inventory_controller.dart:1153` | 인벤토리 저장 key | 있었음 | fb10b-dart에서 순번 있음(그대로) |
| `ui/models/repository_presets_controller.dart:423` | 프리셋 저장 key | — | 이미 `++_keyNumber` 순번(그대로) |
| `ui/models/plan_flow_save.dart:1270` | 계획 흐름 저장 key(`plan-flow-save-<위치>-<µs>`) | 있음(같은 흐름에서 보류 요청을 버리고 다시 저장) | **순번 추가** |
| `ui/widgets/account_section_cluster.dart:891` · `959` · `981` · `1026` | 계정 만들기 · 고치기 · 고르기 · 지우기 key | 있음(고르기 두 번 등, 지우기는 계정 id 포함) | **순번 추가**(4곳, 한 State 카운터) |
| `ui/pages/settings_page.dart:196` | 설정 프로필 만들기 key | 있음 | **순번 추가** |
| `ui/widgets/repository_profile_panel.dart:92` | 프로필 만들기 · 고르기 · 이름 바꾸기 key(`<action>-<µs>`) | 있음 | **순번 추가** |
| `ui/widgets/plan_scenario_list.dart:523` | 시나리오 복제 · 이름 · 삭제 · 적용 key(`scenario-<action>-<id>-<µs>`) | 있음(같은 시나리오에 같은 동작 두 번) | **순번 추가** |
| `ui/widgets/plan_section_layout.dart:1593` | 시나리오 편입(활성 계획 저장) key | 있음 | **순번 추가** |
| `ui/widgets/plan_section_layout.dart:2084` | 비교 화면 시나리오 복제 key(id 없음) | 있음 | **순번 추가** |
| `ui/pages/scan_page.dart:1057` | 스캔 적용 key(`widget.now()`) | — | 이미 `_applyIntentSequence` 순번(스캐너 WIP, 표에만) |
| `ui/models/plan_flow_save.dart:1189` | 비교 초안 문서 id(key 아님) | — | 그대로 |
| `ui/models/plan_flow_draft.dart:1483` · `1737` · `1844` | 흐름 학생 넘기기 `handoffId`(key 아님) | 같은 학생 · 같은 시각이면 같은 id(한 번에 여러 학생은 학생 id로 갈림) | 그대로(발견 5) |
| `ui/models/plan_flow_draft.dart:1553` · `2068` | 흐름 문서 id · 칸 id(key 아님) | — | 칸 id는 이미 순번 |
| `ui/pages/student_page.dart:336` | 계산기 넘기기 `handoffId`(key 아님) | 같은 학생을 같은 시각에 두 번 넘기면 둘째가 무시될 수 있음 | 그대로(발견 5) |
| `ui/widgets/plan_preset_manager.dart:342` | 새 프리셋 id(key 아님) | — | 그대로 |
| `ui/pages/tactical_page.dart:357` · `433` | 택틱 경기 · 족보 id(key 아님) | — | 택틱 소유, 표에만 |

새 테스트(⑥): 프로필 패널에서 만들기 두 번(+ 고르기) key가 모두 다르고 끝 순번이 1, 2, …로 오른다.

### 새 테스트

- `test/app_navigation_tidy1_test.dart`(11): 의도 모델(통계 출발만 복귀 칩 글자, 재화 · 그대로 열기 의도), 인벤토리 상세 "계획에서 보기" → 재화 의도 · 셸 밖은 `onOpenPlan`, 오파츠 → 계획에 쓰는 티어, 계획 탭 재화 의도(첫 생성 · 읽은 뒤 · 그대로 열기), 셸 인벤토리 → 계획 Detail 홈 "전체" + 그 재화 · 복귀 칩 없음, 인벤토리 타일 reveal(1280×720, 장비 61종 마지막 타일 → 스크롤 > 0 · viewport 안, 같은 요청은 다시 스크롤하지 않음), 학생 목록 reveal(요청 → 스크롤 · 같은 번호면 다시 안 함), `studentListRevealOffset` 식, 셸 계산기 모드 값 `onOpenInventory` 있음 · 버튼 숨김 · 부르면 인벤토리 탭(복귀 칩 없음), `InventoryRevealRequest` 한 번 소비.
- `test/tidy1_followups_test.dart`(3): ④ 1280×720 넘침 0 · 버튼 아이콘만, ④ 기준 viewport 글자 그대로(말줄임 없음 — `RenderParagraph.didExceedMaxLines` false), ⑥ key 순번.
- 지운 테스트 없음. 기존 테스트 기대는 바꾸지 않았다(⑤ 이름 바꿈만).

### golden 변화 0 근거(golden 미실행)

1. **① ②**: 모든 변화는 버튼을 누르거나 이동 의도 · reveal 요청이 있을 때만 생긴다. golden 테스트(`test/goldens/**`)는 `navigation:` · `onNavigate` · `inventory-action-plan` · `inventory-oopart-open-plan` · `inventory-open-plan`을 쓰지 않는다(grep 0). 학생 golden은 그리드 보기만 쓰고 목록 보기 · 최근 본 학생 누르기가 없다(grep). 의도가 없으면 계획 홈은 `_pendingHomeResource` null → 읽은 뒤 `_homeSelectedResource = null`(전과 같음), 인벤토리 행 래퍼 `_RevealOnRequest`는 자식을 그대로 돌려준다(레이아웃 · 그림 같음). 통계 출발 `returnLabel`은 같은 글자.
2. **③ ⑤ ⑥**: 주석 · 계약 위치 · key 문자열만 바뀐다(그리는 값 없음). 시계는 같은 시각을 준다(fixture `inventoryHistoryFixtureNow` · 시나리오 시계 그대로, 시계를 읽는 테스트 그대로 통과).
3. **④**: golden은 모두 2560×1392(`golden_harness.dart` `goldenViewportSize`)다. 그 크기에서 (a) 비교 버튼 안 칸이 72px 이상이라 같은 Row 자식(아이콘 · 8 · 글자 · 8 · n개, `LayoutBuilder`는 제약을 그대로 넘긴다), 글자가 들어가므로 `Flexible`(loose)은 원래 폭, (b) `Expanded` + 오른쪽 정렬 글자는 `Spacer` + 글자와 같은 x(남는 칸 오른쪽 끝), (c) 칩 `IntrinsicWidth`는 자식 최대 고유 폭(글자 + 좌우 10)을 그대로 줘 전과 같은 크기 · 가운데 정렬이다. 기준 viewport 테스트가 세 글자 모두 말줄임 없음 · 비교 버튼 글자 있음을 확인했다.
4. golden 테스트 파일 · harness는 고치지 않았고 `flutter analyze` 대상(test 포함)으로 그대로 컴파일된다. commit.json `whole`에 기준 이미지 없음.

### 미검증(미실행)

- golden 비교 · 전체 `fe_gate.ps1`(CF) · process E2E · `codealmanac validate` · `flutter build windows --release`: **미실행**.
- 실제 앱 창에서 인벤토리 → 계획 이동 모습(탭 진입 모션과 Detail 홈 "전체" 탭 전환), 인벤토리 · 학생 목록 reveal 스크롤 체감: **미실행**(위젯 테스트는 위치 · 상태만).
- 인벤토리 "부족한 것" 보기의 위험 행 reveal: 같은 래퍼 코드지만 화면 밖 행이 생길 만큼 부족 행이 많은 fixture로는 확인하지 않았다(타일 길만 테스트).
- 실제 백엔드 key 처리(순번 붙은 key의 응답 재사용 · 충돌): **미실행**(Mock만).

### WIP 보존 확인

- 고친 기존 27파일은 착수 때 WIP가 없었다(`git status --short` 빈 줄). post 사본 · `post_dir`는 두지 않았다. pre 사본 대비 diff는 이 slice 줄뿐이고 줄바꿈을 유지했다.
- 스캐너 WIP(`scan_page.dart` · `scan_companion_dock.dart` · `scanner_service.dart` · `planning_protocol_client.dart` · `process_app_service.dart` · `mock_app_service.dart`, 스캐너 테스트), Lane A 파일(`lib/ui/statistics/**` · `lib/statistics/**` · `statistics_page.dart`와 새 통계 테스트), 키트 코드, golden harness · golden 테스트, `frontend/tool/**`, backend · contracts, 택틱 파일: 편집 0회. git 쓰기 0회.

### 발견 사항

1. **다른 탭 출발 복귀 칩**: 인벤토리 → 계획(그리고 준비만 한 학생 → 인벤토리)은 복귀 칩이 없다(시안에 없음, 프롬프트 "디자인 변경 없음"). "← 인벤토리" 칩을 둘지는 CF 판단(의도 모델 `returnLabel` 한 줄).
2. **계획 탭에 다른 화면이 열려 있을 때 재화 의도**: 흐름 · 시나리오 목록 · 비교 · 프리셋 관리가 열려 있으면 그 화면을 그대로 두고 홈 상태만 바꾼다(전 `_open`과 같은 화면, 알림 없음). 홈으로 돌아오면 고른 재화가 보인다. 닫고 홈을 보여 줄지 · 알림을 둘지는 CF 판단.
3. **학교 플라이아웃 "계획에서 보기 →"**: 계획 Detail 홈에 학교 · 학생 필터가 없어 payload 없이 연다. 그 학교 학생을 계획에서 강조하려면 계획 홈 상태 추가가 필요하다.
4. **FD-173 버튼**: 연결은 준비됨. 켜려면 (a) 행 하나로 갈지(지금 의도), (b) 부족 재화 여러 개 강조 필터(인벤토리 상태 추가, FE6 쪽)로 갈지 CF가 정한 뒤 계산기 하단 버튼을 그리는 소단위가 필요하다.
5. **key가 아닌 같은 패턴**: `student_page.dart:336` 계산기 넘기기 `handoffId`와 `plan_flow_draft.dart` 학생 넘기기 id는 같은 학생을 같은 시각에 두 번 넘기면 같은 id가 되어 계획 탭 `_consumedHandoffId` 검사에 둘째가 무시될 수 있다(드묾). idempotency key가 아니라 고치지 않았다.
6. **레이어**: `lib/services` → `lib/ui` import는 시계 쪽이 없어졌지만 `ui/models/planning_models.dart`를 서비스 8개(`mock_app_service.dart` 등 스캐너 WIP 포함)와 `design_review/statistics_plan_data.dart`가 import한다. 계획 모델 위치 정리는 별도 판단.
7. **Lane A 작업 중 상태**: 실행 중 `statistics_workspace.dart` 컴파일 오류(일시), 최종 시점 `statistics_history_charts.dart:115` 넘침(`statistics_app_shell_test` 2 실패) · `statistics_history_projection_test.dart` analyze error 4가 있었다. 모두 Lane A FE7-h 진행 중 파일이다. CF gate는 Lane A가 멈춘 뒤가 맞다.
8. **④ 비교 버튼 기준 폭 72px**은 아이콘 · 간격 · "n개" 폭에서 정한 값이다. 1280×720에서는 칸이 21px라 아이콘만 남는다(글자가 들어갈 자리가 없다). 시안 좁은 창 모습이 따로 있으면 그에 맞춘다.

### 사본 · commit.json

- 착수 사본: `debug/frontend_tidy1/pre/<경로>`(고친 기존 27파일, 이 문서 포함). WIP가 없어 post 사본은 없다.
- `debug/frontend_tidy1/commit.json`: slice `tidy1`, `status=false`, modified 26(코드 · 테스트), added 3, `whole` = `[almanac/workflows/frontend-redesign-status-lane-b.md]`(이 문서는 파일 단위). 바뀌는 기준 이미지 없음. message는 ASCII(항목별 한 줄 + 근거 발견 사항).
- 인계: `debug/frontend_tidy1/output.md`.

### 다음 행동

- tidy1 코드는 끝났다. Lane B는 여기서 멈춘다.
- CF: Lane A(FE7-h)가 멈춘 뒤 `fe_gate.ps1` 1회. 예상: analyze 0(Lane A 새 테스트가 고쳐진 뒤), 일반 테스트에 새 14건(`app_navigation_tidy1_test` 11 · `tidy1_followups_test` 3), golden 전 장면 변화 0. GREEN이면 `fe_commit.ps1 -Slice tidy1 -DryRun` → 커밋.
- CF 판단 대기: 발견 1 · 2 · 3 · 4(FD-173 버튼) · 5 · 6 · 8.

## fb6-dart 착수 기록 (2026-10-14)

- 상태: 진행 중 → 코드 작성 완료(아래 종료 기록).
- 범위: FB-6(전술 v2 기록·족보 쓰기, 명시적 v7-v1 이관)의 Dart 연결 — 새 메서드 6(`tactical.v2.match.upsert`·`match.delete`·`jokbo.upsert`·`jokbo.delete`·`legacy.preview`·`legacy.commit`) DTO·strict request/success validator·Process·Mock v2·process E2E, read DTO additive optional 3키, `PlanningProtocolClient._methodErrorCodes['tactical']` 추가 8. 화면(기록 화면 v2 전환)은 FE9-b라 범위 밖. 근거: backend 로그 2026-10-14 08:26(최종 Dart 목록)·08:27(legacy commit 요청키 `expected_source_revision`·`expected_fingerprint`)·08:36(allowlist 8)·08:43(guarded JSONL fixture)·09:35(표준 1274 재검증 GREEN), 2026-10-13 18:09·18:42(설계·사전목록), `debug/xb_fb6_main_overlay_20261014/artifacts/`(DART-CONNECTION.md·wire-request6.json·CF-tactical-error-allowlist-delta.json·CF-process-fixture-notice.json·fb6_rpc_fixture_backend.py), FB-6 요청서(status-backend 2026-10-13 17:50), FD-127·FD-128·FD-129.
- 착수 전 확인: 이 문서 끝에 다른 "fb6-dart 착수 기록" 없음.
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `5b1d8d159173515c8faf0d965e7210ad35ef200c`.
- XB 08:26 표 9경로 대조(메인 작업 트리 bytes/SHA256): **9개 모두 일치**.
  - `backend/core/tactical_fb6.py` 6798 `f51c3033d7eff25689c39e6926a05aa899c453f6dac83e6d9b246b43a9e7ab59`
  - `backend/core/tactical_fb6_store.py` 20538 `e99f2b03a5f7e0c24ef19434ce44afa76cfb867240f5e723b0c8508be1a4d0df`
  - `backend/core/tactical_store.py` 16790 `9773a7567577cfecdcaf5879b93f09550e17acefe50c2943eaef733b7037b208`
  - `backend/core/tactical_v2.py` 57676 `1ae8b4fd123f630750b6e87468884fe26a552c77cca45c9fa74d083d2f411a36`
  - `backend/tests/test_tactical_fb6_primitives.py` 6166 `d6e2386bab64d1997e6c24b285a484e622237ec15450370910a2de6ceb84ffb2`
  - `backend/tests/test_tactical_fb6_writes.py` 14447 `e32f2b1f5cf229a9640c623531e360196c6432ad79a4146cc987285d4ab1f0dc`
  - `contracts/README.md` 90625 `2f5b642543e8a4963f5ef2b2c72a56fb6a844316a35131638826bf744dd0e56e`(절 "FB-6a tactical v2 writes and explicit v7-v1 migration")
  - `contracts/fixtures/tactical_fb6_writes_v2.json` 39342 `946f9312f477160046516ec76ec29ddc62c7ce95bfd574a8d8836cfddb9c6f10`(11 cases: 유효 요청 6 + 무효 5)
  - `contracts/tactical-protocol-v2.schema.json` 88241 `8a0be074e56a60220c7fa8deef76c7d86be0001535b313a7f7a09fe2e9d1eb51`(`fb6*` 정의 14)
- XB 목록과 메인 schema·코드 대조(읽기): schema `fb6MatchInput` 13키·`fb6JokboInput` 6키·요청 6종·성공 6종·`match`(optional `attempt_count` null|int≥1, `occurred_precision` enum)·`jokbo`(optional `name` minLength 1)이 08:26 목록·`wire-request6.json`과 같다. `fb6LegacyCommitResponse.v1_writes_disabled`는 `const true`, issue `record_kind`는 `match|jokbo`. 08:36 allowlist 8은 `tactical_fb6_store.py`·`tactical_store.py`의 RepositoryError 코드와 같다. 차이 없음.
- 막힘: 대장 막힘 요약에 fb6-dart 행 없음, 현재 열림 0건. FB-6 행의 FD-127·FD-128은 확정(권장안 (a)). FD-129는 '워커 재량'이지만 FE9-d·FE9-e(시그니처 족보 수·독립 재현) 몫이라 이 slice에서 쓰지 않는다.
- 고칠 기존 파일(착수 사본 `debug/frontend_fb6dart/pre/<v7 기준 경로>`)과 WIP(`git status --short <경로>`), 줄바꿈(바이트로 셈):
  - `frontend/lib/services/tactical_v2_service.dart`: WIP 없음. LF.
  - `frontend/lib/services/planning_protocol_client.dart`: **WIP 있음**(스캐너 WIP hunk 188·863·902줄 부근). CRLF 주 + LF 18줄. 고치는 곳은 `_methodErrorCodes['tactical']`(140~158줄)뿐이라 WIP hunk와 겹치거나 맞닿지 않는다.
  - `frontend/lib/services/process_app_service.dart`: **WIP 있음**(스캐너 WIP hunk 1139~1181줄 부근). CRLF 주 + LF 24줄. 고치는 곳은 implements 목록(35줄)·v2 메서드 묶음(722줄 뒤)이라 WIP hunk와 떨어져 있다.
  - `frontend/lib/services/mock_app_service.dart`: **WIP 있음**(스캐너 WIP hunk 186~680줄 부근). CRLF 주 + LF 128줄. 고치는 곳은 import·implements 목록(19·43줄)·`deleteProfile`(2247줄)·전술 v1 Mock(2858줄 뒤)이라 WIP hunk와 겹치거나 맞닿지 않는다.
  - `almanac/workflows/frontend-redesign-status-lane-b.md`: WIP 없음(이 기록). LF.
- 새 파일(예정): `frontend/lib/services/mock_tactical_v2_writes.dart`(Mock v2 쓰기 의미), `frontend/test/tactical_fb6_dart_test.dart`(계약 fixture·DTO·validator·allowlist·Mock), `frontend/test/tactical_fb6_process_e2e_test.dart`(실제 백엔드, inline guarded 진입점).
- WIP는 지우거나 고치거나 옮기지 않는다. WIP 원 diff 사본: `debug/frontend_fb6dart/logs/wip-before.diff`.

## fb6-dart 종료 기록 (2026-10-14, 코드 작성 완료·CF gate 미실행)

FB-6 전술 v2 기록·족보 쓰기와 명시적 v7-v1 이관의 Dart 연결을 끝냈다. 새 메서드 6의 입력·결과 DTO와 strict request/success 검사, read DTO additive optional 3키, tactical 오류 allowlist 8, Process·Mock v2(새 capability `TacticalEvidenceWriteService`), 계약 fixture·Mock 테스트, 실제 백엔드 process E2E. 화면(FE9-b)은 건드리지 않았다.

### 실행 명령·결과

- `flutter analyze`(frontend): 작업 중 info 2(`prefer_initializing_formals`, Mock 새 파일 생성자)·error 1(새 테스트의 `BackendConnection` import 빠짐)을 고쳤다. 마지막 실행(포맷 뒤): **No issues found(0)**. 실행 시점에 Lane A FE7-e 편집 중 파일(`lib/ui/statistics/**` 등)도 함께 분석됐고 이슈 0이었다.
- `flutter test test/tactical_fb6_dart_test.dart`: ① **+13 −1**(ProcessAppService 테스트에 `TestWidgetsFlutterBinding.ensureInitialized()` 빠짐) → ② **+14**. 포맷 뒤 마지막 확인 **+14**.
- `flutter test --concurrency=1 test/tactical_fb6_process_e2e_test.dart`: 첫 실행부터 **+1**, 다시 돌려 +1·+1, 포맷 뒤 마지막 확인 **+1**(단독 약 5초). 기존 v1 E2E(기본 진입점·startup probe, 15초)보다 빨라서, 값을 출력하는 임시 사본(`test/zz_fb6_probe_tmp_test.dart`)으로 실제 백엔드 응답(파이썬 마이크로초 시각, sha256 fingerprint, 카탈로그 표시명이 든 자동 족보 이름 "족보 3e3491 · 시로코", 프로세스 2개)을 확인한 뒤 그 사본을 지웠다(남은 파일 0).
- 바뀐 동작에 걸리는 기존 테스트(grep: `TacticalEvidence`·`tactical_v2_service`·`TacticalMatchV2`·`TacticalJokboV2`·v1 전술 Mock 쓰기·`loadTacticalState`·`deleteProfile`·`_methodErrorCodes`·`tactical.`, MockAppService 공용 테스트 몇 개 추가):
  - 일반(json, 17파일 병렬): **+178 −0** — account_manager_fe8b +6, home_app_shell +1, inventory_review_fb10b +19, mock_design_review_scenario +11, mock_scanner_commit_history +9, mock_scanner_service +4, profile_delete_fb2d +17, repository_presets_service +49, repository_protocol_contract +1, scanner_protocol_client +6, tactical_fb6_dart +14, tactical_page_revision +5, tactical_page +8, tactical_service +6, tactical_share_v1_contract +1, tactical_v2_service +5, widget_test +16.
  - `planning_protocol_client_test.dart`(실제 Python 테스트 포함, `--concurrency=1`): **+24 −0**.
  - process(`--concurrency=1`, 7파일 차례로): **+8 −0** — tactical_fb6_process_e2e +1, tactical_v2_process_e2e +1, tactical_process_e2e +1, profile_delete_fb2d_process_e2e +1, final_p6_process_e2e +2, repository_process_e2e +1, repository_presets_process_e2e +1.
- `dart format`: LF 4파일(`tactical_v2_service.dart`·새 3파일)만 적용했다. pre `tactical_v2_service.dart`는 이미 포맷 상태(변경 0)라 포맷이 이 slice hunk만 바꿨다. WIP가 있는 공유 3파일은 포맷하지 않았고, 임시 사본을 포맷해 비교한 결과 이 slice hunk와 겹치는 포맷 차이 0.
- `git diff --check`(고친 4파일): exit 0. 새 3파일: 줄 끝 공백 0, 끝 개행 하나, LF. `pubspec.yaml`·`pubspec.lock` 변경 0.
- 3-way 병합 모의(스크래치, `fe_commit.ps1`과 같이 LF로 맞춘 뒤 `git merge-file`, base = pre·ours = HEAD·theirs = post): 고친 4파일 모두 충돌 0, HEAD → 병합 결과 차이가 pre → post 차이(이 slice hunk 12·1·2·9개)와 같다(WIP는 커밋에 섞이지 않는다).
- 잠금 충돌 0(재시도 없음). 로그는 `debug/frontend_fb6dart/logs/`(실패 줄과 json 요약만 확인).

### 고친 파일

- `frontend/lib/services/tactical_v2_service.dart`(WIP 없음, LF):
  - `TacticalMatchV2`: optional `attemptCount`(`attempt_count` int ≥ 1 | null, 없으면 null = 모름)·`occurredPrecision`(`date|instant|unknown`, 없으면 `unknown`). 두 키만 더 허용하고 그 밖의 모르는 키(`legacy_v1` 포함)는 계속 거부.
  - `TacticalJokboV2`: optional `name`(빈 문자열·null 거부, 없으면 null).
  - 입력 DTO `TacticalMatchInputV2`(13키, `date`는 KST 자정 표기만, `unknown` ⇔ 시각 null, 시도 ≥ 1)·`fromRecord`(읽은 기록에서 입력 13키만 옮김. 모르는 시도 횟수·키가 없던 정밀도는 직접 넘기지 않으면 FormatException — 추측하지 않음), `TacticalJokboInputV2`(6키, 이름 필수).
  - 결과 DTO `TacticalMatchUpsertResult`(`revision`·`match`·`jokbo_ids` unique)·`TacticalMatchDeleteResult`·`TacticalJokboUpsertResult`·`TacticalJokboDeleteResult`·`TacticalLegacyIssue`(`record_kind` match|jokbo)·`TacticalLegacyPreview`·`TacticalLegacyCommitResult`(`v1_writes_disabled`는 true만). 모두 exact 키.
  - `isValidTacticalV2ProtocolMessage`: 요청 6·성공 6 갈래. `checkedTacticalV2Request`(보내기 전 검사). capability `TacticalEvidenceWriteService`(state 읽기 + 6메서드).
- `frontend/lib/services/planning_protocol_client.dart`(스캐너 WIP 위): `_methodErrorCodes['tactical']`에 8코드 추가(주석 1줄). 그 밖 0.
- `frontend/lib/services/process_app_service.dart`(스캐너 WIP 위): implements에 `TacticalEvidenceWriteService`, `_tacticalV2Write`(검사 후 전송) + 6메서드(legacy commit은 `expected_source_revision`·`expected_fingerprint`로 보냄).
- `frontend/lib/services/mock_app_service.dart`(스캐너 WIP 위): import 2, implements, `_tacticalV2`(새 Mock 파일, v1 상태 = 원본) + 7메서드 위임, v1 쓰기 4곳 앞에 `requireV1Writable`, `deleteProfile`에서 v2 Mock 저장도 지움(주석 갱신).
- 새 `frontend/lib/services/mock_tactical_v2_writes.dart`: backend `tactical_fb6_store.py`와 같은 순서·코드(아래 검수표). 실패한 쓰기는 사본에만 적용돼 상태를 바꾸지 않는다.
- 새 테스트: `frontend/test/tactical_fb6_dart_test.dart`(14), `frontend/test/tactical_fb6_process_e2e_test.dart`(1).
- 고치지 않음: backend/**·contracts/**, `lib/ui/**`(FE9-b 몫), Lane A 파일, 택틱·스캐너 소유 파일, `scanner_service.dart`, golden harness·golden 테스트, `frontend/tool/**`, `app_shell.dart`, 기존 `tactical_v2_service_test.dart`·`tactical_v2_process_e2e_test.dart`(그대로 통과).

### XB 목록(08:26·08:27·08:36·08:43·DART-CONNECTION.md) 행별 검수

| XB 목록 행 | 처리 | 근거 테스트 |
|---|---|---|
| 새 메서드 6, 요청은 schema(`wire-request6.json`) 그대로 | 요청 갈래 6(exact 키, profile 24hex, revision ≥ 0, key 비지 않음, recordId·sha256) | fb6_dart "six requests are exact…", fixture 11 cases |
| match 입력 13키 / jokbo 입력 6키, backend 소유 audit/created/import/source 되보내지 않음 | 입력 DTO 키 = fixture 키, backend 소유 9키(기록)·4키(족보)를 넣으면 요청 거부, `fromRecord`가 13키만 옮김 | "six requests…", "input DTOs carry only input keys…" |
| mutation 공통 `profile_id`·`expected_revision`·`idempotency_key`, preview는 `profile_id`만 | 갈래 `base(...)`·preview exact 1키 | "six requests…"(키 빠짐·더함 음성) |
| legacy commit 요청키 = `expected_source_revision`·`expected_fingerprint`(08:27) | Process가 preview의 `source_revision`·`source_fingerprint`를 이 이름으로 보냄, 응답 이름(`source_*`)으로 보내면 거부 | "six requests…", "ProcessAppService sends exact requests…"(fixture payload와 같음), E2E |
| 성공 strict 6종 + issue 4키, 모르는 키 거부 | 결과 DTO 7종, 키 더함·빠짐·revision −1·중복 jokbo_ids·attempt 0·commit `v1_writes_disabled` false·issue kind/id/code 음성 | "six success payloads are exact", Process 응답 키 더함 → protocol 오류 |
| read DTO additive optional(`attempt_count`·`occurred_precision`·jokbo `name`), 그 밖 거부 | 위 "고친 파일" | "read DTOs accept only the additive optional keys" |
| 오류 allowlist 8(08:36) typed backend error | 8코드 + `revision_conflict` → `BackendRemoteException`·연결 유지, v1 `tactical.match.upsert`의 `tactical_v1_read_only`도 typed, 모르는 코드는 protocol 오류 | "tactical allowlist 8 are typed…", E2E 6코드 실제 수신 |
| Mock: v1 rows → `legacy_migration_required` → preview → commit → v1 read-only | `_ensureWriteMode`·v1 쓰기 4곳 `requireV1Writable` | Mock "v1 rows require explicit migration…" |
| Mock: 빈 v1은 첫 v2 쓰기가 claim | 같은 쓰기에서 빈 표식, 이후 v1 read-only·commit `legacy_already_migrated`, 실패한 v2 쓰기는 claim 안 함 | Mock "empty v1 is claimed…", "failed v2 writes do not claim…" |
| Mock: 같은 key = 원 응답, 다른 payload = `idempotency_conflict`, 삭제 후 재요청이 되살리지 않음 | `_mutation`(캐시 → revision → 적용) | Mock "retry returns the original response…" |
| Mock: attempt_count·occurred_precision 보존, 이관 기록 null/date·unknown | 입력 그대로 저장, 이관 변환 | Mock 두 테스트 |
| Mock: source 변경 `import_source_changed`, 변환 문제 `import_review_required`(전체 거부) | 순서 backend와 같음 | Mock "v1 rows…", "unresolved legacy conversion…" |
| Mock: lineage 족보 자동 도출·이름 유지·`lineage_conflict`, 별칭 `opponent_alias_required`, 부분 덱 스냅샷 없음 | `_derivedJokbo`·`_lineageId`(위치·와일드카드·모름·빈칸 구분) | Mock "identity, lineage and snapshot rules" |
| 기존 v1 Mock 동작 그대로 | 이관 전 v1 저장·삭제·revision 오류 그대로 | "failed v2 writes…", tactical_page·tactical_service 테스트 |
| process E2E(legacy rows → v2 `legacy_migration_required` → preview → commit → v1 read-only → upsert/delete → 재시작 → 원 요청이 되살리지 않음) | 아래 | `tactical_fb6_process_e2e_test` |
| guarded fixture 방식(명시 storage root, prefix `ba_planner_fb6_rpc_`) inline | `-c` 진입점이 `fb6_rpc_fixture_backend.py`와 같은 검사(임시 폴더 아래·prefix·폴더 존재), 스캐너 미결합 | E2E |

### process E2E 내용

- 임시 저장소 `Directory.systemTemp/ba_planner_fb6_rpc_*`(실제 경로로 풀어서 넘김, 끝에 지움). 진입점은 inline `-c`(메인 `ApplicationProtocolV1` + `stdio_server.serve`, `PYTHONDONTWRITEBYTECODE=1`). 실제 게임·사용자 프로필·공용 저장소 접근 0.
- 프로필 1개 + 보유 학생 6(shiroko·akane·yuuka·mika·serina·hibiki). v1 기록 m1(날짜 있음) + v1 족보 j1 → v2 upsert `legacy_migration_required`.
- 미리보기(source revision 2, 기록 1·족보 1, 문제 0, v1 쓰기 가능) → v1 기록 m2(날짜 없음) 추가 → 옛 미리보기로 commit `import_source_changed` → 새 미리보기(revision 3, fingerprint 다름)로 commit = revision 1·기록 2·족보 1·`v1_writes_disabled` true → 미리보기 `v1_writes_disabled` true → 다른 key commit `legacy_already_migrated`.
- v1 새 쓰기 `tactical_v1_read_only`, 원 v1 요청(같은 key·내용) = 원 revision 1, v1 읽기 revision 3·기록 2·족보 1 그대로.
- v2 상태: 이관 기록 2개 시도 횟수 null, 정밀도 {date, unknown}, date 시각 `2026-10-13T00:00:00+09:00`, source_label `v7_v1_migration`, 족보 이름 모두 있음(공개 상태에 `legacy_v1` 없음 — strict 상태 DTO가 받아들임).
- v2 기록 manual-one(시도 3, instant) → revision 2, 자동 족보 1(`lineage-`). 같은 상대 identity에 다른 이름 → `opponent_alias_required`. 족보 manual-jokbo → revision 3·이름 그대로. lineage ID로 다른 방어 덱 → `lineage_conflict`. 같은 key 다른 내용 → `idempotency_conflict`. 옛 revision 삭제 → `revision_conflict`. 족보 삭제 4, 기록 삭제 5(스냅샷도 사라짐).
- 재시작 뒤 같은 상태(revision·기록·족보·상대 ID). 원 이관 commit·원 기록 upsert(revision 2·manual-one)·원 족보 upsert(revision 3) 재전송 = 원 응답, 상태는 revision 5 그대로이고 manual-one·manual-jokbo가 되살아나지 않음. 백엔드 프로세스 2개 모두 exit 0.

### 계약 SHA 대조

- 착수·종료 두 번 XB 08:26 9경로 bytes/SHA256이 모두 일치(착수 기록). 이 slice는 backend/contracts를 읽기만 했다(`git status --short backend contracts`의 기존 변경은 XB·스캐너 쪽, 이 slice 쓰기 0).
- 테스트가 읽는 계약: `contracts/fixtures/tactical_fb6_writes_v2.json` 39342 B `946f9312f477160046516ec76ec29ddc62c7ce95bfd574a8d8836cfddb9c6f10`, schema `contracts/tactical-protocol-v2.schema.json` 88241 B `8a0be074e56a60220c7fa8deef76c7d86be0001535b313a7f7a09fe2e9d1eb51`(Dart validator는 schema를 손으로 옮긴 것, 실행 때 schema를 읽지 않는다).

### allowlist 8 확인

- `PlanningProtocolClient._methodErrorCodes['tactical']`에 `import_review_required`·`import_source_changed`·`legacy_already_migrated`·`legacy_migration_required`·`lineage_conflict`·`migration_conflict`·`opponent_alias_required`·`tactical_v1_read_only` 8개(XB `CF-tactical-error-allowlist-delta.json` `needed_from_source9`와 같은 목록)를 더했다. 기존 17개는 그대로.
- 단위: 8코드 모두 v2 쓰기 응답에서 `BackendRemoteException`(연결 connected 유지), v1 쓰기 응답 `tactical_v1_read_only`도 typed, 집합 밖 코드는 `BackendProtocolException`.
- 실제 백엔드에서 받은 것: `legacy_migration_required`·`import_source_changed`·`legacy_already_migrated`·`tactical_v1_read_only`·`opponent_alias_required`·`lineage_conflict`(+ 기존 `idempotency_conflict`·`revision_conflict`). `import_review_required`·`migration_conflict`는 실제 백엔드에서 만들지 않았다(Mock·단위만).

### golden 변화 예상

- **변화 0.** `lib/ui/**`를 고치지 않았다. Mock 변화는 v2 쓰기 메서드를 부를 때만 생기고(v1 쓰기의 read-only 검사는 v2 쓰기·이관 전에는 항상 통과), golden 테스트·harness는 전술 v2 쓰기·`loadTacticalEvidenceState`를 쓰지 않는다(grep 0, harness의 `tactical` 문자는 재화 `tactical_bd`). golden 테스트는 돌리지 않았다.
- CF gate 예상: analyze 0. 새 두 테스트 파일 모두 `ProcessAppService`를 포함해 fe_gate 분류상 process 묶음(직렬)에 들어간다 → process **+15**(tactical_fb6_dart 14 + E2E 1), 일반 변화 0, golden 변화 0.

### 미검증 항목

- 전체 `fe_gate.ps1`·golden 비교·`codealmanac validate`·저장소 전체 `git diff --check`: **미실행**(CF 몫).
- Python 전체 테스트: **미실행**(XB 몫, XB 09:35 표준 1274 GREEN 보고만 읽음).
- 위 목록 밖 Flutter 테스트(Lane A 통계·계획 테스트, 스캐너·스캔 화면 테스트, 나머지 process E2E): **미실행**. 이 slice가 바꾼 Mock 경로는 전술 v1 쓰기 앞 검사·`deleteProfile`·새 v2 메서드뿐이다.
- 실제 백엔드의 `import_review_required`(카탈로그 밖 v1 ID)·`migration_conflict`(이관 ID 충돌)·`link_conflict`(로비 연결 기록 수정): **미실행**(v1 API로는 카탈로그 밖 ID를 쓸 수 없고 파일 직접 편집은 하지 않았다. XB 백엔드 테스트 몫).
- 실제 사용자 프로필 이관·삭제: **미실행**(금지 범위). 화면 연결(FE9-b)·Windows release 빌드: **미실행**.

### WIP 보존 확인

- 공유 3파일은 pre 사본과 줄 단위(difflib, 줄바꿈 무시 비교)로 맞춰 봤다: 같은 줄은 바이트(줄바꿈 포함)까지 그대로(바뀐 줄 0), 이 slice hunk는 삽입(과 mock 주석 2줄 교체)뿐이고 새 줄은 모두 CRLF(주변 줄과 같음).
  - `planning_protocol_client.dart`: 삽입 1곳(157~165줄, 9줄). WIP hunk(188·863·902줄 부근)와 떨어져 있다.
  - `process_app_service.dart`: 삽입 2곳(36줄 1줄, 729~822줄 94줄). WIP hunk(1139줄 이후)와 떨어져 있다.
  - `mock_app_service.dart`: 삽입 8곳(20~21·46·2251·2862~2945·v1 쓰기 4곳 각 1줄)과 HEAD 주석 2줄 교체(2248~2249, `git show HEAD`에 있는 문장 — WIP 아님). WIP hunk(186~680줄)와 겹치거나 맞닿지 않는다.
- `git diff`로 다시 셈: 착수 때 WIP diff(`logs/wip-before.diff`)의 +/− 줄 220개가 끝 diff(`logs/diff-after.diff`)에 모두 그대로 있다(빠진 줄 0, 늘어난 200줄은 이 slice).
- 공유 3파일 편집은 바이트 단위 삽입으로 했고 편집 도구 줄바꿈 통일은 일어나지 않았다(복원 불필요). `tactical_v2_service.dart`·새 파일은 LF.
- 다른 WIP 파일(`scanner_service.dart`·scan 계열·스캐너 테스트)과 Lane A 파일은 수정 0. git 쓰기 0회.

### 발견 사항

1. **기록 삭제 뒤 자동 족보가 남는다**(백엔드 동작): manual-one을 지워도 그 기록에서 도출된 `lineage-` 족보("족보 3e3491 · 시로코")는 남는다(E2E에서 확인). 템플릿이 관측과 따로 산다는 계약 문장과 맞지만, 결과 0인 자동 족보를 화면에 어떻게 보일지는 FE9-b·CF 판단.
2. **족보 read DTO는 여전히 notes·wins·losses·출처를 버린다**(G-pvp §7.1). 이번 범위는 FB-6 새 키만이라 `name`만 더했다. FE9-b에서 족보를 편집하면 입력 6키에 기존 notes를 넣어야 하므로 그때 DTO 확장이 필요하다(지금 화면 쓰기 0).
3. **Mock과 백엔드의 차이**(모두 Mock 파일 머리 주석에 적음): 카탈로그·보유 학생·역할 검사 없음, 로비 연결 `link_conflict` 없음, 자동 족보 이름이 표시명 대신 학생 ID, ID·fingerprint 해시가 sha256이 아닌 결정적 FNV 값, instant 시각을 Dart UTC 표기(`…000Z`, 백엔드는 `+00:00`)로 둔다. 또 Mock v1에는 idempotency 캐시가 없어 이관 뒤 원 v1 재요청이 Mock에서는 `tactical_v1_read_only`다(백엔드는 원 응답). 기존 v1 Mock 동작을 바꾸지 않으려고 그대로 두었다.
4. **capability 분리**: Mock은 `TacticalEvidenceWriteService`만 구현하고 `TacticalEvidenceService`(통계·추세·추천·공유)는 여전히 Process만이다. FE9-b가 화면에서 v2 읽기를 쓸 때 어느 capability로 검사할지 정해야 한다.
5. **fe_gate 분류**: `tactical_fb6_dart_test.dart`는 가짜 프로세스로 `ProcessAppService`를 만들 뿐인데 이름 패턴 때문에 process(직렬) 묶음에 들어간다(14건, 빠름). 기존 `planning_protocol_client_test`와 같은 처리라 그대로 두었다.
6. **E2E 진입점**: XB 공용 FB-6 진입점이 `backend/tests/`에 생기면 inline `-c`를 그쪽으로 옮긴다(fb10c 선례, XB 판단).
7. **정밀도 표시**: 백엔드는 instant를 UTC(`+00:00`)로, date를 KST 자정(`+09:00`)으로 돌려준다. FE9-b는 date를 시각 없이 날짜로만, instant는 KST로 보여야 한다(UI 몫).
8. 워커 재량 FD 사용 없음(FD-129는 FE9-d·FE9-e 몫).

### 사본·commit.json

- 착수 사본: `debug/frontend_fb6dart/pre/<경로>`(고친 기존 4파일 + 이 문서).
- 끝 사본: `debug/frontend_fb6dart/post/<경로>`(고친 기존 4파일 + 새 3파일).
- `debug/frontend_fb6dart/commit.json`: slice `fb6dart`, `status=false`, `post_dir` = `debug/frontend_fb6dart/post`, modified 4, added 3, `whole = [almanac/workflows/frontend-redesign-status-lane-b.md]`(바뀌는 기준 이미지 없음). message(ASCII) 근거: backend 로그 08:26·08:27·08:36·08:43·09:35, DART-CONNECTION.md·wire-request6.json 경로, FD-128.
- 인계: `debug/frontend_fb6dart/output.md`.

### 다음 행동

- fb6-dart 코드는 끝났다. Lane B는 여기서 멈춘다.
- CF: Lane A(FE7-e + FD-175)가 멈춘 뒤 XB FB-6 source9와 같은 소스로 gate 1회(예상: analyze 0, process +15, 일반 변화 0, golden 변화 0) → XB exact9 커밋 → `fe_commit.ps1 -Slice fb6dart`(mock·process·planning client는 3-way 병합, WIP 인접 hunk 없음) → FB-7.
- 발견 사항 1·2·4·7은 FE9-b(CF), 3·5는 CF 판단, 6은 XB 판단을 기다린다.

## FE9-b1 착수 기록 (2026-10-14)

- 상태: **진행 중 → 코드 작성 완료(아래 FE9-b1 종료 기록), CF gate 미실행**. 범위: 전술 v2 데이터 계층(화면 0) — read DTO 확장(G-pvp §7.1 "버림" 목록), 좁은 읽기 capability `TacticalEvidenceReadService`(Process 선언 + Mock 구현), 화면용 컨트롤러 `lib/tactical/tactical_records_controller.dart`, 도출 족보 "기록 없음" 표식, design-review 전술 v2 seed. 기존 `tactical_page.dart`(v1)는 그대로 둔다.
- 착수 전 확인: 이 문서 끝에 다른 "FE9-b1 착수 기록" 없음(grep 0건).
- 시작 SHA(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`): `ebc84ee463767b4d726120c8f16af7b14b34bb6d`.
- 막힘: 대장 "slice별 막힘 요약" 현재 `열림` 0건, FE9-b 행의 FD-128은 확정(권장안 (a)). FD-129(워커 재량)는 FE9-d·FE9-e 몫이라 쓰지 않을 예정.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe9b1/pre/<v7 기준 경로>`, 6개 모두 작업 트리와 cmp 일치)과 WIP(`git status --short <경로>`), 줄바꿈(`git ls-files --eol`·바이트 셈):
  - `frontend/lib/services/tactical_v2_service.dart`: WIP 없음. LF.
  - `frontend/lib/services/mock_app_service.dart`: **WIP 있음**(스캐너 WIP hunk 189~683줄 부근). CRLF 3148 + LF 128. 고칠 곳은 implements 목록(46줄 부근)·전술 v2 Mock 묶음(2862줄 뒤)뿐이라 WIP hunk와 겹치거나 맞닿지 않는다.
  - `frontend/lib/services/process_app_service.dart`: **WIP 있음**(스캐너 WIP hunk 1234~1276줄 부근). CRLF 1329 + LF 24. 고칠 곳은 implements 목록(36줄 부근) 선언 1줄뿐.
  - `frontend/lib/services/mock_design_review_scenario.dart`: WIP 없음. LF.
  - `frontend/test/tactical_v2_process_e2e_test.dart`: WIP 없음. LF(확장 DTO 확인 expect 추가 예정).
  - 이 문서: WIP 없음. LF.
  - `planning_protocol_client.dart`: 고칠 예정 없음.
- 새 파일(예정): `frontend/lib/services/mock_tactical_v2_reads.dart`, `frontend/lib/tactical/tactical_records_controller.dart`, 테스트 `frontend/test/tactical_fe9b1_read_test.dart`·`frontend/test/tactical_records_controller_test.dart`.
- WIP는 지우거나 고치거나 옮기지 않는다. 착수 때 WIP diff 사본: `debug/frontend_fe9b1/logs/wip-before.diff`(공유 2파일).

## FE9-b1 종료 기록 (2026-10-14, 코드 작성 완료 · CF gate 미실행)

전술 v2 데이터 계층을 끝냈다. read DTO 확장(G-pvp §7.1 "버림" 목록), 좁은 읽기 capability `TacticalEvidenceReadService`(Process 선언 1줄 · Mock 구현), 화면용 컨트롤러 `lib/tactical/tactical_records_controller.dart`(화면에 붙이지 않음), 도출 족보 "기록 없음" 표식, design-review 전술 seed. `lib/ui/**`(`tactical_page.dart` 포함) 수정 0. HEAD는 착수 때와 같다(`ebc84ee4`).

### 실행한 명령과 결과(이 PC, `frontend` 폴더)

- `flutter analyze`(전체): 작업 중 info 2(`prefer_initializing_formals` — 컨트롤러 생성자, `unnecessary_string_escapes` — 테스트 정규식)를 고쳤다. 마지막 실행 **No issues found(0)**. 실행 시점에 Lane A 편집 중 파일도 함께 분석됐고 이슈 0.
- 새 테스트: `flutter test test/tactical_fe9b1_read_test.dart` ① +9 −3(테스트 쪽: record 안 matcher 비교 2, 보유 학생 목록에 `chise` 빠짐 1) → ② **+12**. `flutter test test/tactical_records_controller_test.dart` ① +7 −1(같은 고정 시계의 두 컨트롤러가 같은 key `…-1`을 만들어 `idempotency_conflict` — 구현 수정: 순번을 프로세스 전체 static으로) → ② +6 −1(테스트 정규식 이스케이프) → ③ **+14**.
- 바뀐 동작에 걸리는 기존 테스트(grep: `tactical_v2_service`·v2 DTO 이름·`TacticalEvidence`·`MockDesignReviewScenario`·`createMockAppService`·`design-review`·`tactical.` + Mock 공용 몇 개). 일반(json, 12파일 병렬): **+98 −0** — home_app_shell +1, mock_design_review_scenario +11, profile_delete_fb2d +17, tactical_fe9b1_read +12, tactical_lobby_scanner_service +2, tactical_page_revision +5, tactical_page +8, tactical_records_controller +14, tactical_service +6, tactical_share_v1_contract +1, tactical_v2_service +5, widget_test +16.
- process 묶음(`--concurrency=1`, 파일마다 따로): tactical_fb6_dart **+14**, planning_protocol_client **+24**, tactical_fb6_process_e2e **+1**, tactical_v2_process_e2e **+1**(확장 DTO 확인 expect 추가 전 +1, 추가 뒤 +1), tactical_process_e2e **+1**, profile_delete_fb2d_process_e2e **+1**. 모두 −0.
- `dart format`: LF 파일만(`tactical_v2_service.dart`·`mock_design_review_scenario.dart`·`tactical_v2_process_e2e_test.dart`·새 5파일). WIP 공유 2파일은 포맷하지 않고 바이트 단위로 넣었다.
- `git diff --check`(고친 5파일 + 이 문서): exit 0. 새 5파일: CR 0 · 줄 끝 공백 0 · 끝 개행 하나. `pubspec.yaml`·`pubspec.lock` 변경 0.
- 3-way 병합 모의(스크래치, LF로 맞춘 뒤 `git merge-file`, base = pre · ours = HEAD · theirs = post): 고친 5파일 모두 충돌 0, HEAD → 병합 결과 차이 줄 수가 pre → post 차이와 같다(mock 48 · process 1 · tactical_v2_service 563 · design-review 13 · E2E 31). WIP는 커밋에 섞이지 않는다.
- 잠금 충돌 0(재시도 없음). 로그 `debug/frontend_fe9b1/logs/`(실패 줄과 json 요약만 확인).

### DTO 확장 표(필드 → schema 위치 → Dart 필드)

schema = `contracts/tactical-protocol-v2.schema.json`. "키만"은 schema가 원소를 `{type: object}`로만 두거나 required 키 이름만 준다는 뜻이고, 그때 타입은 백엔드 코드에서 옮겼다(발견 1).

| wire 필드 | schema 위치 · 타입 | Dart |
|---|---|---|
| snapshot `occurred_at`·`observed_at`·`imported_at` | `$defs/snapshot` timestamp\|null · 필수 문자열 | `TacticalDefenseSnapshot.occurredAt`·`observedAt`(String?)·`importedAt` |
| snapshot `source`·`season`·`review_status` | `$defs/snapshot` | `.source`·`.season`·`.reviewStatus` |
| identity `first_observed_at`·`last_observed_at`·`review_status` | `$defs/opponent` timestamp\|null | `TacticalOpponentIdentity.firstObservedAt`·`lastObservedAt`(String?)·`reviewStatus` |
| jokbo `wins`·`losses`·`notes` | `$defs/jokbo` int≥0 · string | `TacticalJokboV2.wins`·`losses`·`notes` |
| jokbo 출처 `created_at`·`imported_at`·`source`·`source_label`·`import_batch_id`·`source_record_id`·`confidence`·`review_status` | `$defs/jokbo`(confidence null\|0~1) | `.createdAt`·`.importedAt`·`.source`·`.sourceLabel`·`.importBatchId`·`.sourceRecordId`·`.confidence`(double?)·`.reviewStatus` |
| signature `source_counts` | `statsResponse…public_signatures.items` 키만 → `core/tactical_stats_v2.py` 236~255 | `TacticalPublicSignatureStats.sourceCounts`(Map<String,int>, 키 = 출처 6종) |
| signature `attack_decks`·`attack_deck_total` | 같은 곳 | `.attackDecks`(List<`TacticalSignatureAttackDeck`{signature, result: `TacticalObservedResult`}>)·`.attackDeckTotal` |
| signature `full_defenses`·`full_defense_total` | 같은 곳 | `.fullDefenses`(List<`TacticalSignatureFullDefense`{signature, count}>)·`.fullDefenseTotal` |
| stats `opponents` | `statsResponse.payload.opponents.items` `{type: object}` → `tactical_stats_v2.py` 264~310 | `TacticalStatisticsResult.opponents`(List<`TacticalOpponentStats`>: id · displayName · 노출/선택/기록 수 · `attackResults`·`defenseResults`(`TacticalObservedResult`) · `latestPublic`·`latestFull`(`TacticalOpponentLatestDeck`?)) |
| freshness `last_success_at` | `trendsResponse…freshness.items` `{type: object}` → `core/tactical_trends_v2.py` 338~353 | `TacticalFreshnessEvidence.lastSuccessAt`(String?) |
| freshness `verified_after_latest_change` | 같은 곳(변경 관측 없으면 null) | `.verifiedAfterLatestChange`(bool? — null = 모름) |
| scenario `deck` | `recommendResponse…scenarios.items.properties.deck` = `$defs/deck` | `TacticalDefenseScenario.deck` |
| recommendation `deck`·`wins`·`losses`·`last_observed_at` | `recommendResponse…recommendations.items` required 키만 → `core/tactical_recommend_v2.py` 316~332 | `TacticalAttackRecommendation.deck`·`wins`·`losses`·`lastObservedAt` |
| `hidden_slots` | `recommendResponse…hidden_slots.items` required `position`·`candidates`만 → 같은 파일 236~266 | `TacticalRecommendationResult.hiddenSlots`(List<`TacticalHiddenSlot`{position `striker:0~3`·`special:0~1`, candidates: `TacticalHiddenSlotCandidate`{value, evidenceWeightShare, supportingSnapshotCount}}>) |
| `ambiguity` | `recommendResponse…ambiguity` required 4키만 → 같은 파일 435~438 | `.ambiguity`(`TacticalRecommendationAmbiguity`: grade low/medium/high/unavailable · variantDefensePossible · topEvidenceWeightShare(double?) · publicKnownSlotCount 0~6) |
| `evidence_summary` | `recommendResponse…evidence_summary` required 3키만 → 같은 파일 427~431 | `.evidenceSummary`(`TacticalEvidenceSummary` 수 3개) |

- schema에 없는 필드는 만들지 않았다. 기존처럼 모든 객체는 exact 키(모르는 키 거부).
- 새 필드는 모두 `required` 생성자 인자다(생성처는 `fromWire`뿐 — grep 확인).

### Map으로 남긴 것

| Dart 필드 | schema 위치 | 이유 |
|---|---|---|
| `TacticalTrendsResult.changes` | `trendsResponse.payload.changes` — 하위 배열 원소 `{type: object}` | 타입 없는 Map(프롬프트) |
| `TacticalTrendsResult.exposure` | `trendsResponse.payload.exposure` — `by_*` 원소 `{type: object}`, `retention` required 키만 | 같음 |
| `TacticalShareAnalyticsResult.groups`·`substitutions` | share analytics 응답(이 schema 밖, `version` 1 공유 계약) `groups`·`one_slot_substitutions` | 같음 |
| `TacticalStatisticsResult.attackPatterns`·`quality` | `statsResponse.payload.attack_patterns`·`quality` required 키만 | §7.1 목록 밖 — 그대로 |
| `TacticalRecommendationResult.validation`, recommendation `score_components`·`evidence_scope`·`source_counts`, scenario `source_counts`·`supporting_snapshot_ids` | `recommendResponse` 하위 | §7.1 목록 밖 — 검사만 하고 노출하지 않음(그대로) |

### capability 구조

- 새 `TacticalEvidenceReadService`(`tactical_v2_service.dart` 3177줄): `loadTacticalEvidenceState` · `queryTacticalStatistics` · `queryTacticalTrends` · `queryTacticalRecommendations`. 공유 · v6 가져오기 · 로비 · 예측 저장은 지금처럼 `TacticalEvidenceService`(Process만).
- `ProcessAppService`: implements 목록에 `TacticalEvidenceReadService` 1줄만(메서드는 이미 있음).
- `MockAppService`: implements 1줄 + import 1줄 + 위임 3메서드(요청을 `checkedTacticalV2Request`로 Process처럼 검사 → 새 `mock_tactical_v2_reads.dart`가 만든 wire → 같은 `fromWire`). `TacticalEvidenceService`는 여전히 구현하지 않는다(테스트로 확인).
- 컨트롤러는 `TacticalEvidenceWriteService`(상태 읽기 + 쓰기 6)를 받는다. 통계 · 추천 패널(FE9-d)은 `TacticalEvidenceReadService`로 검사하면 된다.

### Mock 차이(`mock_tactical_v2_reads.dart` 머리 주석과 같다)

- 같은 계산: 관측 승률 = 승/(승+패), 95% Wilson(z = 1.959963984540054, 표본 0이면 null — p10 statistics-semantics · backend `_result`), 덱 시그니처, 기간 필터(`occurred_at` 없으면 `observed_at`, 기간을 주면 시각 없는 기록 제외), `prediction` 출처 제외. 테스트가 Wilson 값을 따로 계산해 1e-12 안에서 맞춘다.
- Mock에 로비 스캔 · 후보가 없다: 통계 노출 · 선택 · 연결 0, 공개 시그니처 빈 목록, 공개 시그니처 필터 → 0건, 추이는 빈 구조(로비 관측이 없는 백엔드 응답과 같은 모양), 숨은 칸 빈 목록.
- 공격 패턴은 `exact`·`strikers`·`specials`만, `cores`·`one_slot_variants`는 빈 목록.
- 추천: 대상 상대의 확인된 완전 방어 스냅샷(시각 있음 · `as_of` 이전)만 근거(백엔드 3단계 `same_opponent_recent_full`, `selected_stage` 3, 시간 감쇠 없음 — 근거 가중치 = 스냅샷 수). 공격 추천 = 같은 상대(또는 같은 방어 덱)와 싸운 공격 기록 중 한 번이라도 이긴 덱, 승 많은 순 → 패 적은 순 → 시그니처 순. 점수 = Wilson 하한, 점수 구성 `observed_outcome` 하나. 검증(backtest) 0건 · null, 보정 gate 미통과. 신뢰 · 모호도 등급은 백엔드와 같은 문턱.

### 컨트롤러 상태 · 오류 문구 표

- 상태: `profileId` · `state`(v2) · `revision` · `matches`(시각 최신 순, 시각 없음은 뒤) · `jokbo`(`TacticalJokboEntry` 이름 순: 족보 + 같은 편성 v2 공격 기록 수 · 승 · 패) · `legacyPreview` · `legacyStatus`(`none`·`migrationRequired`·`migrated`) · `hasLegacyRecords` · `migrationRequired` · `lastDerivedJokboIds` · `loading` · `busy` · `error`(`TacticalRecordsError` 코드 + 문구).
- 동작: `load(profileId)`(상태 + 이관 미리보기를 함께 읽고, 계정을 바꾸면 늦은 이전 응답을 버림) · `reload()` · `saveMatch`·`deleteMatch`·`saveJokbo`·`deleteJokbo` · `commitMigration()`(미리보기의 `source_revision`·`source_fingerprint` → `expected_source_revision`·`expected_fingerprint`, 이관할 것이 없으면 보내지 않음). 쓰기는 지금 revision을 `expected_revision`으로 보내고 성공하면 다시 읽는다. 쓰기 중에는 다른 쓰기를 보내지 않는다(false). dispose 뒤 notify 0.
- idempotency key: `tactical-<동작>-<µs>-<순번>`(tidy1 방식). 답을 못 받은 요청(연결 끊김 · 시간 초과 · 프로토콜 오류)을 같은 내용(같은 revision)으로 다시 보내면 같은 key, 백엔드가 답한 요청(성공 · 도메인 오류)은 key를 버린다. 순번은 프로세스 전체 static(발견 4).
- 답을 받은 뒤 다시 읽는 오류: `revision_conflict`·`idempotency_conflict`·`legacy_migration_required`·`import_source_changed`·`legacy_already_migrated`·`migration_conflict`·`record_not_found`(문구는 남긴다).

| 코드 | 화면 문구 |
|---|---|
| `legacy_migration_required` | 이전 형식의 전술 기록을 새 형식으로 옮긴 뒤에 저장할 수 있습니다. 옮기기 미리보기를 확인해 주십시오. |
| `import_source_changed` | 미리보기 뒤에 이전 형식 기록이 바뀌어 옮기지 않았습니다. 미리보기를 다시 읽었습니다. |
| `import_review_required` | 옮길 수 없는 이전 형식 기록이 있어 옮기지 않았습니다. 미리보기의 문제 항목을 먼저 고쳐 주십시오. |
| `legacy_already_migrated` | 이전 형식 기록은 이미 새 형식으로 옮겼습니다. |
| `migration_conflict` | 옮길 기록의 ID가 이미 있는 기록과 겹쳐 옮기지 않았습니다. |
| `lineage_conflict` | 자동으로 만든 족보의 편성은 바꿀 수 없습니다. 새 족보로 복사한 뒤 고쳐 주십시오. |
| `opponent_alias_required` | 상대 이름이 이 상대에 저장된 이름과 다릅니다. 이름을 먼저 별칭으로 등록해 주십시오. |
| `tactical_v1_read_only` | 새 형식으로 옮긴 뒤에는 이전 형식 기록을 읽기만 할 수 있습니다. |
| `revision_conflict` | 저장하는 사이에 전술 기록이 바뀌어 저장하지 않았습니다. 최신 상태를 다시 읽었습니다. |
| `idempotency_conflict` | 같은 요청 번호로 다른 내용이 와서 저장하지 않았습니다. 최신 상태를 다시 읽었습니다. |
| (그 밖 백엔드 코드) | 전술 기록을 저장하지 못했습니다. |
| (답 없음 `connection_failed`) | 백엔드의 답을 받지 못했습니다. 다시 연결한 뒤 같은 내용으로 다시 저장해 주십시오. |
| (읽기 실패 `load_failed`) | 전술 기록을 읽지 못했습니다. |

- 시각 표시(fb6-dart 발견 7): `tacticalOccurredText` — `date` 정밀도는 KST 날짜만(`2026-10-13`), `instant`는 KST 시각(`2026-10-04 21:10`, UTC `…Z`·`+00:00`에 9시간을 더함), `unknown`·null은 '—'. `tacticalKstDateText`·`tacticalKstInstantText`는 다른 시각(마지막 관측 등)에 쓴다. 기존 KST helper는 없었다(grep 0) — 새로 만들었다. 기기 시간대와 무관하다(UTC에서 더한다). key 시각은 `now` 주입(화면은 `() => appClockNow(service)`를 넘기면 된다).

### 도출 족보 표시 규칙(fb6-dart 발견 1)

- 족보는 백엔드 동작 그대로 목록에 남긴다. 컨트롤러가 족보마다 방어 · 공격 덱 identity(위치 · 와일드카드 `*` · 모름 `?` · 빈칸 `empty`까지, 백엔드 `deck_identity`와 같은 규칙)가 같은 v2 공격 기록을 세어 `recordCount`·`recordWins`·`recordLosses`를 준다. `lineage-` 족보인데 `recordCount` 0이면 `hasNoRecords` = true("기록 없음" 표식). 수동 · 가져온 족보는 표식 없음.
- `TacticalJokboV2.wins`·`losses`(가져온 v6 집계, 자동 족보는 0)와 기록 집계를 더하지 않고 따로 둔다(계약 "not double counted").
- 테스트: 기록 저장 → 자동 족보(기록 1 · 1승) → 기록 삭제 → 같은 족보가 남고 `hasNoRecords` → 이름 고침(notes 되보냄) 뒤에도 표식 유지 → 족보 삭제.

### design-review seed

- 새 `lib/services/design_review/tactical_records_data.dart` + `mock_design_review_scenario.dart` 생성자에서 같은 Mock 쓰기 경로(`upsertTacticalMatchV2`, 계획 seed와 같은 `unawaited` 방식, 기대 revision 0~3)로 기록 4개: 공격 2(게헨나 선도부, instant, 시도 1 · 3, 승 · 패) · 공격 1(아비도스 대책위원회, date, 시도 2, 모름 칸 2 · 빈칸 1인 부분 방어 덱) · 방어 1(unknown). 자동 족보 2, revision 4, 이관 미리보기 `v1_writes_disabled` true(빈 v1 claim).
- 기본 Mock은 그대로 빈 v2(테스트 확인). design-review는 opt-in이라 golden 영향 없음.

### FE9-a 전환 목록(v1 caller — 고치지 않음)

| `tactical_page.dart` | 메서드 | v1 호출 → Process 줄(이번 implements 1줄로 +1) | FE9-a v2 대체 |
|---|---|---|---|
| 368 | `_editMatch`(448 `_copyJokboToMatch`도 거침) | `saveTacticalMatch` → `tactical.match.upsert` 680 | `TacticalRecordsController.saveMatch` |
| 439 | `_editJokbo` | `saveTacticalJokbo` → `tactical.jokbo.upsert` 704 | `.saveJokbo` |
| 483 | `_deleteMatch` | `deleteTacticalMatch` → `tactical.match.delete` 692 | `.deleteMatch` |
| 498 | `_deleteJokbo` | `deleteTacticalJokbo` → `tactical.jokbo.delete` 716 | `.deleteJokbo` |

- 근거: XB 13:51(`debug/xb_fb6_exact_commit_20261014/artifacts/tactical-v1-editor-caller-proof.json`). 이관 뒤 이 4곳은 `tactical_v1_read_only`이고 지금 화면은 일반 저장 실패로 보인다. FE9-a는 이관 안내(`legacyStatus`·`commitMigration`)와 묶어 전환한다.

### golden 변화 0 근거(golden 미실행)

- `lib/ui/**` 수정 0. golden harness · golden 테스트는 전술 v2 · design-review 시나리오를 쓰지 않는다(grep: harness의 `tactical`은 재화 `tactical_bd`뿐, `MockDesignReviewScenario`·`createMockAppService` 0). Mock 변화는 새 읽기 메서드 3개(부를 때만)와 design-review 생성자 seed뿐이다.
- CF gate 예상: analyze 0. `tactical_fe9b1_read_test.dart`는 컴파일 시점 capability 검사 때문에 `ProcessAppService` 문자열이 있어 fe_gate 분류상 process(직렬) 묶음 → process **+12**(빠름), `tactical_records_controller_test.dart`는 일반 **+14**, `tactical_v2_process_e2e_test`는 1건 그대로(expect만 늘었다). golden 변화 0.

### 미검증(미실행)

- 전체 `fe_gate.ps1` · golden 비교 · `codealmanac validate` · 저장소 전체 `git diff --check`: **미실행**(CF 몫).
- Python 전체 테스트: **미실행**(XB 몫, 백엔드 수정 0).
- 위 목록 밖 Flutter 테스트(Lane A 통계 · 계획, 스캐너 · 스캔 화면, 나머지 process E2E): **미실행**. 이 slice의 Mock 변화는 새 읽기 3메서드와 design-review seed뿐이다.
- 컨트롤러를 실제 백엔드에 붙인 실행: **미실행**(컨트롤러가 부르는 서비스 메서드는 fb6 E2E가 실제 백엔드로 이미 검사). 같은 상태로 Mock 읽기와 실제 백엔드 숫자 대조: **미실행**(차이는 위 "Mock 차이").
- 실제 사용자 프로필 · 화면 연결 · Windows release 빌드: **미실행**.

### WIP 보존 확인

- 공유 2파일을 pre 사본과 줄 단위(difflib, 줄바꿈 무시 비교)로 맞춰 봤다: 같은 줄은 바이트(줄바꿈 포함)까지 그대로(바뀐 줄 0), 새 줄은 모두 CRLF(주변과 같음). LF 줄 수 그대로(mock 128 · process 24).
  - `mock_app_service.dart`: 삽입 3곳(22줄 import 1, 48줄 implements 1, 2948~2989줄 읽기 3메서드 42) + HEAD 주석 1줄 → 2줄 교체(2865~2866, `git show HEAD`에 있는 문장 — WIP 아님). WIP hunk(189~683줄)와 겹치거나 맞닿지 않는다.
  - `process_app_service.dart`: 삽입 1곳(37줄 1줄). WIP hunk(1234~1276줄 부근)와 떨어져 있다.
- `git diff`로 다시 셈: 착수 때 WIP diff(`logs/wip-before.diff`)의 +/− 줄 152개가 끝 diff(`logs/diff-after.diff`)에 모두 그대로 있다(빠진 줄 0, 늘어난 49줄은 이 slice).
- 공유 파일 편집은 바이트 단위 삽입으로 했고 편집 도구 줄바꿈 통일은 일어나지 않았다(복원 불필요). `planning_protocol_client.dart`·`scanner_service.dart`·스캐너 테스트 · Lane A 파일 수정 0. git 쓰기 0회.

### FD 처리

- FD-128(확정, 권장안 (a)): v2 일원화 · 족보 자동 도출 + 이름 편집 — 컨트롤러는 v2 쓰기만 하고 자동 족보를 그대로 보인다.
- 워커 재량 FD 사용 없음(FD-129는 FE9-d · FE9-e 몫).

### 발견 사항

1. **schema가 통계 · 추이 · 추천 하위 원소의 타입을 주지 않는다**(XB 요청 후보): `statsResponse.public_signatures`·`opponents`, `trendsResponse.freshness` 원소는 `{type: object}`, `recommendations`·`hidden_slots`·`ambiguity`·`evidence_summary`는 required 키 이름만 있다. Dart 타입은 백엔드 코드(위 표의 줄)를 따랐고 실제 응답은 E2E로 받았다. schema에 원소 타입을 적으면 Python schema 검사와 Dart strict 검사가 같은 근거를 갖는다. schema와 실제 백엔드 응답이 다른 곳은 찾지 못했다.
2. **족보 승패의 뜻**: `jokbo.wins`·`losses`는 v6 가져오기 집계(자동 족보는 항상 0)이고 v2 기록에서 다시 세지 않는다. 컨트롤러는 기록 집계를 따로 준다. 분석 화면(FE9-d · FE9-e)이 둘 중 무엇을 "족보 승패"로 보일지(또는 나란히)는 CF 판단.
3. **Mock 차이**: 위 "Mock 차이"(로비 없음, 패턴 일부, 추천 단순화). 검수에서 통계 · 추천 숫자가 실제 백엔드와 다를 수 있다.
4. **idempotency 순번을 컨트롤러 사이에서 공유(static)**: tidy1은 State마다 순번이었지만, 같은 µs 시계(고정 시계 · 빠른 재생성)의 두 컨트롤러가 같은 key를 만들어 `idempotency_conflict`가 났다(테스트로 재현 → 수정). 같은 문제가 tidy1의 State별 순번에도 이론상 있다(두 인스턴스가 같은 µs) — CF 판단.
5. **design-review seed는 빈 v1 claim 경로**: 이관 완료 상태를 v1 기록 없이 만든다. 이관된 기록(시도 null · date)의 모습은 seed에 없다(컨트롤러 테스트가 Mock 이관 경로를 검사). 검수에서 이관 안내 화면을 보려면 별도 seed가 필요하다.
6. **fe_gate 분류**: `tactical_fe9b1_read_test.dart`가 process 묶음에 들어간다(fb6-dart 발견 5와 같은 이유, 빠름).
7. **Process 줄 이동**: implements 1줄로 v1 전송 줄이 XB 13:51 표(679 · 703 · 691 · 715)에서 각각 +1(680 · 704 · 692 · 716). `tactical_page.dart` 줄은 그대로.

### 사본 · commit.json

- 착수 사본: `debug/frontend_fe9b1/pre/<경로>`(고친 기존 5파일 + 이 문서).
- 끝 사본: `debug/frontend_fe9b1/post/<경로>`(고친 기존 5파일 + 새 5파일).
- `debug/frontend_fe9b1/commit.json`: slice `fe9b1`, `status=false`, `post_dir` = `debug/frontend_fe9b1/post`, modified 5, added 5, `whole = [almanac/workflows/frontend-redesign-status-lane-b.md]`. message(ASCII) 근거: G-pvp §7.1 · §7.2, FD-128, fb6-dart 발견 1 · 2 · 4 · 7, backend 로그 13:51.
- 인계: `debug/frontend_fe9b1/output.md`.

### 다음 행동

- FE9-b1 코드는 끝났다. Lane B는 여기서 멈춘다.
- CF: Lane A(FE7-f)가 멈춘 뒤 gate 1회(예상: analyze 0, process +12 · 일반 +14 늘어남, golden 변화 0) → `fe_commit.ps1 -Slice fe9b1`(mock · process는 3-way 병합, WIP 인접 hunk 없음).
- 그다음 FE9-a(새 기록 화면, 이 컨트롤러 위, v1 caller 4곳 전환). 발견 1은 XB 요청 후보, 2 · 4 · 5는 CF 판단.

## FE9-a 착수 기록 (2026-10-14)

- 상태: **진행 중 → 코드 작성 완료(아래 FE9-a 종료 기록), CF gate 미실행**. 범위: 전술대항전 기록 화면(Tactical artboard S1 기록 목록 + S3 기록 작성)을 FE9-b1 컨트롤러(`TacticalRecordsController`, v2) 위에 새 디자인으로 만든다. S2 로비 스캔(FE9-c)·S4 시그니처 족보(FE9-d)는 시안 틀 + "준비 중" 자리. v1 쓰기 4곳(`_editMatch`·`_editJokbo`·`_deleteMatch`·`_deleteJokbo`, `_copyJokboToMatch`)과 `_DeckEditor`·AlertDialog를 걷어내고 v2 컨트롤러 호출 + 이관 안내로 바꾼다.
- 착수 전 확인: 이 문서 끝에 다른 "FE9-a 착수 기록" 없음(grep 0건).
- 시작 SHA(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`): `26ef5cc37205d1e897ccf5ea557f12fb2c25384c`.
- 막힘: 대장 "slice별 막힘 요약" FE9-a 행 FD-126은 확정(권장안 (a)), 현재 `열림` 0건. FD-132(워커 재량)는 권장안대로 처리할 예정.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe9a/pre/<v7 기준 경로>`, 6개 모두 작업 트리와 cmp 일치)과 WIP(`git status --short <경로>` 출력 0줄 = 6개 모두 WIP 없음), 줄바꿈(`git ls-files --eol`):
  - `frontend/lib/ui/pages/tactical_page.dart`: WIP 없음. 작업 트리 CRLF(그대로 유지).
  - `frontend/test/tactical_page_test.dart`: WIP 없음. LF.
  - `frontend/test/tactical_page_revision_test.dart`: WIP 없음. LF.
  - `frontend/lib/services/design_review/tactical_records_data.dart`: WIP 없음. LF(고칠 수도 있음 — 고치지 않으면 끝 기록에 적는다).
  - `frontend/lib/tactical/tactical_records_controller.dart`: WIP 없음. LF(화면에 꼭 필요한 최소 추가만 — 고치지 않으면 끝 기록에 적는다).
  - 이 문서: WIP 없음. LF.
- 새 파일(예정): `frontend/lib/ui/tactical/**`(덱 칸 줄·미니 덱·시도 스테퍼·출처 범례 칩·학생/상대 피커·4섹션 workspace), `frontend/lib/ui/studio/tactical_studio_layout.dart`, `frontend/test/goldens/fe9a_tactical_golden_test.dart`(+ 필요하면 새 위젯 테스트 파일).
- 고치지 않는 것: `lib/services/**`(design-review seed 제외), `lib/ui/kit/**`, Lane A 통계 · 필터 모달, `app_shell.dart`, 스캐너 · 택틱 파일, golden harness · 다른 golden, `frontend/tool/**`, backend · contracts.

### FE9-a 사고 기록 — `dart format` 범위 실수 (2026-10-14 17:35, CF 확인 필요)

- 17:35:32 내 명령 `dart format test/tactical_page_test.dart lib/ui`(디렉터리 인자 실수)가 `lib/ui` 전체를 포맷해 이 slice 밖 파일 **79개**를 바꿨다(이 slice 파일 제외). 목록: `debug/frontend_fe9a/format_incident/touched-by-format.txt`.
- 복구 ①(정확): 79개 중 **72개**는 사고 직전 WIP가 없었다(현재 내용 = HEAD 내용을 같은 포매터로 돌린 결과와 바이트 일치). 이 72개를 `git show HEAD:<경로>` 바이트로 되돌렸다(작업 트리 CRLF 4개 — `inventory_page.dart` · `plan_section_layout.dart` · `repository_profile_panel.dart` · `section_template_surface.dart` — 는 CRLF로). 되돌린 뒤 `git status --short lib/ui`에서 72개 모두 사라졌다(= index와 같음). 목록: `clean-restored-to-head.txt`.
- 복구 ②(토큰 일치, 공백 · 줄바꿈 미확인): 나머지 **7개는 다른 레인 WIP 파일**이었다 — Lane A `kit/range_controls.dart` · `pages/statistics_page.dart` · `statistics/statistics_growth_evidence.dart` · `statistics/statistics_supply_evidence.dart` · `statistics/statistics_workspace.dart` · `widgets/student_filter_modal.dart`, 스캐너 `pages/scan_page.dart`. `debug/xb_scanner_functional_select_20261014/artifacts/candidate-v3-v7/frontend/lib/ui/<경로>`(17:15~17:21 사본)를 같은 포매터로 돌리면 사고 뒤 내용과 바이트 일치했으므로(= 같은 토큰), 그 사본으로 되돌렸다(7개 모두 사고 뒤 mtime 그대로임을 확인한 뒤). 사고 뒤 포맷된 내용은 `debug/frontend_fe9a/format_incident/formatted/<경로>`에 남겼다.
  - **미확인**: 되돌린 7개가 사고 직전 바이트(공백 · 줄바꿈 CRLF/LF)와 같은지. 확인 명령이 권한 분류기에 막혀(다른 레인 작업 간섭) 더 보지 않았다. `git`이 `range_controls` · `scan_page` · `statistics_supply_evidence` · `statistics_workspace` · `student_filter_modal`에 "LF will be replaced by CRLF" 경고를 낸다 — 사고 전 줄바꿈과 다를 수 있다. Lane A가 17:21~17:35 사이에 공백만 바꾼 편집이 있었다면 그 공백도 사본 기준으로 돌아갔다.
  - 포맷이 바꾸지 않은 WIP 파일: `statistics/statistics_matrix_charts.dart`(untracked) · `scan_companion_dock.dart` · `scan_student_review_workspace.dart` · `scan_inventory_identity_review.dart`.
- 이후 `dart format`은 이 slice 파일만 경로로 지정한다. CF 요청: Lane A · 스캐너 쪽에 위 7개 파일의 공백 · 줄바꿈을 확인해 달라고 알려 주십시오(필요하면 각 레인의 마지막 사본과 비교).

## FE9-a 종료 기록 (2026-10-14, 코드 작성 완료 · CF gate 미실행)

전술대항전 기록 화면(시안 Tactical S1 기록 목록 + S3 기록 작성)을 FE9-b1 `TacticalRecordsController`(v2) 위에 새 4섹션 화면으로 만들었다. S2 로비 스캔 · S4 시그니처 족보는 시안 틀 + "준비 중" 자리다. v1 화면(`_DeckEditor` · AlertDialog · v1 쓰기 4곳)은 걷어냈다. HEAD는 착수 때와 같다(`26ef5cc3`). 위 "사고 기록"(`dart format` 범위 실수, 다른 레인 파일 79개 → 72개 정확 복구 · 7개 토큰 일치 복구, 공백 · 줄바꿈 미확인)을 CF가 먼저 봐 주십시오.

### 실행한 명령과 결과(이 PC, `frontend` 폴더)

- `flutter analyze`(이 slice 파일만, 작성 중): No issues. 마지막 전체 `flutter analyze`: ① info 1(`curly_braces_in_flow_control_structures`, `tactical_page.dart` — 옛 파일 머리 `ignore_for_file`을 지워서 드러남) → 고침 → ② **No issues found(0)**. `pubspec.yaml` · `pubspec.lock` 변경 0.
- `flutter test test/tactical_page_test.dart`: ① +16 −3 — 테스트 쪽 2(Mock이 instant를 UTC `Z`로 돌려줌 · `TacticalDeckV2`에 `==` 없음) + 구현 1(이관 기록은 새 ID를 받는다 → 고른 v1 행을 `source_record_id` `v7-v1:match:<v1 ID>`로 v2 행에 옮기게 고침) → ② **+19**.
- `flutter test test/tactical_page_revision_test.dart test/tactical_page_test.dart`: **+24**(5 + 19).
- 바뀐 동작에 걸리는 기존 테스트(grep: `TacticalPage` · `전술대항전` · `AppSection.pvp` · 셸을 띄우는 테스트 · 전술 서비스 · design-review), 일반 15파일 json: **+135 −0** — app_navigation_fe7d +14, app_navigation_tidy1 +11, home_app_shell +1, home_page +5, mock_design_review_scenario +11, profile_delete_fb2d +17, student_filter_modal +8, tactical_lobby_scanner_service +2, tactical_page_revision +5, tactical_page +19, tactical_records_controller +14, tactical_service +6, tactical_share_v1_contract +1, tactical_v2_service +5, widget_test +16.
- process 묶음 분류 2파일(`--concurrency=1`, 가짜 프로세스라 빠름): tactical_fb6_dart **+14**, tactical_fe9b1_read **+12**.
- 일회성 렌더(임시 `test/zz_fe9a_render_tmp_test.dart` = golden 파일 사본에서 비교 대신 `toImage` → scratchpad PNG, 실행 뒤 삭제): +2. 두 장면 모양을 눈으로 확인했다(아래 golden 절). 첫 렌더에서 상대 칸 "▾" 글자가 글꼴에 없어 네모로 보여 키트 `KitGlyph.chevronDown` 선 아이콘으로 바꿨다.
- `git diff --check`(고친 3파일): exit 0. 새 6파일: CR 0 · 줄 끝 공백 0 · 끝 개행 하나. `tactical_page.dart`는 CRLF 그대로(686줄 모두 CRLF), 나머지 LF.
- 잠금 충돌 0(재시도 없음). 로그: `debug/frontend_fe9a/logs/`(실패 줄과 json 요약만 확인).

### 고친 파일

| 파일 | 내용 |
|---|---|
| `frontend/lib/ui/pages/tactical_page.dart`(CRLF) | 다시 씀. 상태(계정 · 계정 상태 · 카탈로그 · 컨트롤러 · 이관 전 v1 읽기 · 필터 · 선택 · 초안 · 모달 3개)와 저장 · 복제 · 지우기 · 가져오기 · 피커 흐름. 그리기는 `TacticalWorkspace` |
| 새 `frontend/lib/ui/studio/tactical_studio_layout.dart` | 4섹션 Studio 문서 + `TacticalMetrics`(시안 artboard 숫자) |
| 새 `frontend/lib/ui/tactical/tactical_workspace.dart` | 4섹션 위젯(섹션 표면 · 자르기는 통계와 같은 구성), S1 · S3 요소, S2 · S4 자리 |
| 새 `frontend/lib/ui/tactical/tactical_records_view.dart` | 위젯 없는 모델: 초안(내 덱 · 상대 덱 ↔ 공격 · 방어 덱), 목록 행(FD-132 표기 · 시각 · 시도), 필터, 출처 범례, 상대 identity 찾기, 자동 연결 판정 |
| 새 `frontend/lib/ui/tactical/tactical_deck_widgets.dart` | 덱 칸 줄 · 미니 덱 · 공격/방어 아이콘 칩 · 필터 칩 · 출처 범례 · 시도 스테퍼(모름 가능) |
| 새 `frontend/lib/ui/tactical/tactical_pickers.dart` | 학생 고르기 · 상대 고르기 · 지우기 확인 패널(`BaModalPanel.dialog`) |
| `frontend/test/tactical_page_test.dart` | 새 화면 기준으로 다시 씀(아래) |
| `frontend/test/tactical_page_revision_test.dart` | 같은 규칙을 v2 화면 기준으로 다시 씀(아래) |
| 새 `frontend/test/goldens/fe9a_tactical_golden_test.dart` | 장면 2(`tactical` · `tactical-migration`) |

고치지 않음: `lib/tactical/tactical_records_controller.dart`(화면에 필요한 값이 이미 다 있어 추가 0 — pre 사본과 cmp 일치), `lib/services/design_review/tactical_records_data.dart`(golden · 테스트가 seed 함수를 그대로 부른다 — cmp 일치), `lib/services/**`, `lib/ui/kit/**`, `app_shell.dart`, Lane A · 스캐너 · 택틱 파일(사고 복구 제외), golden harness · 다른 golden.

### 처리한 FD

- **FD-126 (a)**: 하위 seg "기록 · 분석 · 슬롯". 셸 머리말은 `app_shell.dart` 소유(이 slice 수정 금지)이고 `PageHeaderOverride`는 seg 자리가 없어, S1 제목 "기록" 오른쪽에 둔다(FE6-a "목록 · 분석" seg 선례). 분석 · 슬롯은 흐림 + "준비 중" 툴팁. 머리말 부제는 셸의 `AppSection.pvp` 설명 "전술대항전 기록과 편성"(시안과 같음)이라 고치지 않았다. → 발견 2.
- **FD-128 (a)**: v2 일원화 — 화면 쓰기는 컨트롤러 v2 저장 · 지우기 · 이관뿐. 자동 족보 연결은 "같은 시그니처 족보에 자동 연결됨"으로만 보인다.
- **FD-132(워커 재량, 권장안)**: 방어 행 "내 방어덱 · vs <상대>". v2 기록은 상대 이름이 필수라(계약) 늘 이름이 붙는다. "상대 없이도 저장"은 계약상 불가 → 발견 3.
- FD-127: 순위 · 방어 승률 · 채택률 등은 그리지 않는다(상대 칸 "순위 —").
- FD-131: "스캔 파일 가져오기" 숨김, "엑셀 가져오기"는 FE9-f 전까지 흐림 + "준비 중".

### 섹션별 구현

- **4섹션 좌표**(기준 콘텐츠 캔버스 2560×1208, 테스트로 고정): S1 (0,2,30,94) 왼쪽 사다리꼴 — 시안과 같음. S2 rect (23,2,54,17) 위 면 평행사변형(faceStart 14 · faceSpan 73 · height 92) — 꼭짓점 1px 안. S3 rect (18,20,54,76) 아래 면 평행사변형(faceStart 9 · faceSpan 73) — x 0.4px 안, 윗변 y −1.5px(96 grid 한계). S4 (65,2,31,94) 오른쪽 사다리꼴 — −0.7px. 섹션 안 요소는 시안 rect ±2px(테스트 13개 rect). 작은 창: `TacticalMetrics.scaleFor` = min(가로 비율, 세로 비율, 1)(0.4 하한)로 요소 세로 위치 · 높이와 내용을 같이 줄이고, 가로는 섹션 사선을 따른다(화면 전체 축소 없음).
- **S1 기록 목록**: 제목 줄 "기록" · seg · "새 기록"(시안에 없음 — 빈 초안을 여는 자리) · "엑셀 가져오기"(흐림). 칩 줄 전체 · 공격 · 방어 · 승 · 패 · 이번 시즌 · "상대: 전체"(누르면 상대 고르기 모달, "전체" 포함). 목록은 공용 `DiagonalScrollViewport` resize 모드(행 128 · 간격 8, 첫 행 743.9 → 둘째 719.9, 공용 스크롤바 · 포그), 필터마다 viewport key를 바꾼다. 행: 결과 칩 · 상대 표기(FD-132) · 종류 아이콘 · "시도 · 시각"(시도 모름 '—', 시각은 컨트롤러 정밀도 규칙) · 상대 덱 / 내 덱 미니 줄(빗금 = 모름, 흐린 상자 = 확인된 빈칸) · v1이면 "이전 형식" 칩. 행을 누르면 S3에 불러온다(고치지 않은 초안은 버린다 — FE6-a 규칙).
- **S2 · S4**: 제목("로비 스캔" · "이 시그니처의 족보") + "준비 중". 스캔 버튼 없음.
- **S3 기록 작성**: 머리("공격 기록 · 2026-10-04 21:10", 새 기록은 "새 공격 기록", 시즌 칩, v1이면 "이전 형식" 칩, 공격 · 방어 아이콘 칩 = 종류 seg), 상대 덱 캡션 + (i)(시안 문구 그대로), 상대 유저(이름 입력 + 꺾쇠 = 기록한 상대 고르기, "순위 — · 최근 대전 n회"), 상대 덱 6칸 + 출처 범례(공개 = `visible_lobby`, 기록 = 학생 있는 그 밖의 칸, 빈칸 = 학생 없음), 내 덱 캡션, 내 덱 6칸 + "지난 기록 덱 복사"(같은 종류의 다른 v2 기록, 같은 상대 먼저 · 없으면 가장 최근) · "족보에서 가져오기"(FE9-d, 흐림), 결과 seg 승리 · 패배, 시도 스테퍼(1부터, 모르면 '—', +로 1, −는 1에서 멈춤) + 보조 문구("첫 시도 성공" · "n번째 시도에 성공" · "n회 시도 · 패배" · "시도 횟수 모름"), 메모 한 줄, 저장(primary) · 복제해서 새 기록 · 지우기(danger, 시안에 없음) + 상태 문구.
- **덱 칸 = 6칸**(스트라이커 4 + 스페셜 2, 시안 · DTO 그대로). 프롬프트의 "5칸"은 시안 · 계약과 달라 따르지 않았다 → 발견 1.
- **학생 고르기**: 최소 피커(`TacticalStudentPickerPanel`, BaModal 스크림 anchored): 검색 + 8열 초상 격자(공용 사선 스크롤바) + "빈칸으로 두기"(모름) + 닫기. 칸 위치로 스트라이커 · 스페셜을 거르고, 내 덱은 보유 학생만(v1 `_candidates(own:)` 규칙), 같은 덱 다른 칸에 있는 학생은 흐림. 계획 만들기 1단계 학생 고르기는 흐름 초안 · 필터 컨트롤러 · 내 그룹에 묶여 덱 한 칸 고르기에 재사용할 수 없었다(근거).
- **저장**: 이름이 같은(현재 이름 · 별칭) 상대 identity를 쓰고, 없으면 새 ID `opponent-<µs>-<순번>`. 새 기록은 ID `match-<µs>-<순번>`, 시각 = 고정 시계(`appClockNow`) UTC 초 단위 `instant`. 고친 기록은 시각 · 정밀도를 그대로 되보낸다. 저장 성공 뒤 그 기록을 고른다. expected revision · idempotency key는 컨트롤러. 저장할 수 없는 이유(v1 읽기 전용 · 이관 필요 · 이름 없음 · 시도 모름)를 상태 문구로 보이고 저장을 끈다. 저장 오류는 컨트롤러 문구 표 그대로(빨강).
- **복제해서 새 기록**: 같은 내용의 저장 안 된 새 초안(시각은 저장할 때 지금). v1 "새 기록으로 복사" 동작(저장하지 않고 편집기를 연다)과 같다.
- **지우기**: `BaModal` 확인("기록 지우기" — 이 기록에서 만든 족보는 남는다는 문구 포함, fb6-dart 발견 1) → 컨트롤러 지우기 → 첫 행(없으면 새 초안).

### v1 → v2 전환 결과(FE9-b1 "FE9-a 전환 목록")

| v1 | 결과 |
|---|---|
| `_editMatch`(→ `saveTacticalMatch`) | 삭제. S3 저장 = `TacticalRecordsController.saveMatch`(v2 upsert) |
| `_editJokbo`(→ `saveTacticalJokbo`) | 삭제. 족보 편집 UI는 FE9-d 몫(이번 화면에 족보 목록 없음, 컨트롤러 `saveJokbo` 미사용) |
| `_deleteMatch`(→ `deleteTacticalMatch`) | 삭제. S3 지우기 = `.deleteMatch` + BaModal 확인 |
| `_deleteJokbo`(→ `deleteTacticalJokbo`) | 삭제. FE9-d 몫(`.deleteJokbo` 미사용) |
| `_copyJokboToMatch` | 삭제. "족보에서 가져오기" 자리만(흐림 + "준비 중"), FE9-d |
| `_DeckEditor` · AlertDialog · `showDatePicker` · `showDateRangePicker` · `SegmentedButton` · `DropdownButton` | 삭제(덱 칸 줄 + 학생 고르기 BaModal, 칩 필터) |

화면의 v1 서비스 사용은 이관 전 읽기 `loadTacticalState`(읽기 전용 행) 하나뿐이다(grep: `tactical_page.dart`에 `saveTactical` · `deleteTactical` 0건).

### 이관 안내 동작

- 컨트롤러 `migrationRequired`(미리보기 v1 기록 · 족보 수 > 0이고 v1 쓰기가 아직 열림)일 때만 S1 칩 줄 아래(시안에 없음 — FE6-a 후보 띠 문법: 분홍 외곽 · 옅은 채움 · 오른쪽 primary)에 띠: 제목 "이전 형식 전술 기록 · 기록 n건 · 족보 m건", 본문 "가져오면 새 형식으로 옮겨 고치고 저장할 수 있습니다. 가져오기 전에는 읽기만 합니다."(옮길 수 없는 기록이 있으면 "옮길 수 없는 기록 k건이 있어 가져올 수 없습니다. …" + 버튼 꺼짐), 버튼 "가져오기". 목록은 띠 높이만큼 내려간다.
- v1 기록은 v2 행 뒤에 읽기 전용 행("이전 형식" 칩)으로 보인다(권장안 — 이관 전에도 무엇을 옮기는지 보이게). 고르면 S3가 읽기 전용(칸 · 입력 · 버튼 꺼짐, "이전 형식 기록은 가져온 뒤에 고칠 수 있습니다.").
- 이관 전에는 새 기록도 저장을 끄고 컨트롤러 `legacy_migration_required` 문구를 보인다. "가져오기"를 누를 때만 `commitMigration()`(자동 이관 없음). 성공하면 띠 · v1 행이 사라지고, 고른 v1 행은 `source_record_id` `v7-v1:match:<ID>`로 이관된 v2 행에 옮겨진다. 이관 기록은 시도 모름이라 '—'이고, 고쳐 저장하려면 시도 횟수를 정해야 한다.

### 기본 Mock에서 처음 모습

- 기본 `MockAppService`는 v1 · v2 모두 비어 있다 → 이관 안내 없음, S1 "아직 저장한 기록이 없습니다. 기록 작성에서 저장하면 여기에 나타납니다.", S3 새 공격 기록(승리 · 시도 1 · 덱 모두 빗금), 상태 문구 "상대 이름을 입력해 주십시오.", S2 · S4 "준비 중". 기본 Mock은 보유 학생이 없어 내 덱 학생 고르기 후보가 비어 있다("보유한 … 학생이 없습니다. 학생 스캔을 먼저 실행해 주십시오.").
- design-review 시나리오(FE9-b1 seed 4개): 가장 최근 기록(게헨나 선도부 공격 · 승리 · 시도 1)이 골라진 채 열린다.

### 정한 규칙

- 처음 읽은 뒤 첫 행을 자동으로 고른다. 사용자가 행을 고르거나 새 기록을 열면 그 뒤로는 자동 선택하지 않는다. 고른 행이 사라지면(지움 · 이관) 이관 대응 행 → 첫 행 → 새 초안 순.
- "이번 시즌" = 목록 맨 위(가장 최근)부터 처음 나오는 비어 있지 않은 시즌.
- 상대 필터는 이름(표시명)으로 거른다. 상대 고르기 후보 = 목록에 나온 이름(기록 수).
- 계정 상태 revision은 표시 · 보유 학생 읽기에만 쓰고 tactical 쓰기에는 쓰지 않는다. 계정 상태 · v2 상태 응답의 계정이 선택 계정과 다르면 받지 않고 "선택 계정과 다른 계정의 응답을 받았습니다."(쓰기 꺼짐). 셸 `reloadToken`(전술 탭 열기 · 프로필 변경)이 오르면 다시 읽는다.
- 초안 버리기: 다른 행을 고르면 저장하지 않은 초안은 버린다.

### 테스트(지운 · 고친 기존 테스트)

- `tactical_page_test.dart`(다시 씀, 19): Studio 4섹션 꼭짓점 · scaleFor, 모델 3(FD-132 · 정밀도 · 시도 모름, 출처 범례, 새 초안 → 입력), 배치(시안 rect 13 + 기록 행 2), 기본 Mock 빈 화면 · 긴 이름 × 1280×720 · 1440×900 · 1280×960(넘침 예외 0), 분석 · 슬롯 · 엑셀 "준비 중" 툴팁, seed 목록 · 필터 · 상대 필터 · 방어 행 고르기, 새 기록(학생 고르기 모달 3칸 · 결과 · 시도 · 메모 → v2 upsert expected 0), 고쳐 저장(같은 ID · expected 4 · 같은 identity) + 피커 중복 학생 흐림, 복제 → 새 ID 저장 · 지우기 BaModal(그만두기 · 지우기, AlertDialog 0), 저장 오류 문구(`revision_conflict`), v1 이관(띠 · 읽기 전용 · 이관 전 새 기록 저장 불가 · 가져오기 → v2 · 시도 모름 → 정해야 저장).
  - 지운 기존 테스트(v1 화면 전용): 빈 화면 "전술 대전" 문구 × 3크기 → 새 빈 화면 테스트, v1 기록 날짜 필터 · 복사 · 삭제 tooltip × 3크기 → 긴 이름 테스트 + 쓰기 테스트, "대전 기록 · 족보" 모드 → seg 테스트, 족보 → 기록 복사 → FE9-d로 넘김(복제 테스트가 "저장 안 된 초안" 동작을 대신 검사).
- `tactical_page_revision_test.dart`(다시 씀, 5): legacy 계정 상태(summary 0 → 1)와 v2 tactical 2 — 지우기 expected 2 · 고쳐 저장 expected 3, 계정 상태 revision은 1 그대로; 병렬 읽기 순서 2가지(profile 7이 아니라 v2 2); 다른 계정 응답 거부(목록 · 쓰기 0); `reloadToken`으로 다시 읽기. 머리 줄 `tactical-revision-line`은 새 시안에 없어 없앴고, revision은 쓰기 요청 기록으로 검사한다.

### golden(비교 미실행)

- 새 장면 2(`test/goldens/fe9a_tactical_golden_test.dart`, 셸 → 전술대항전 탭, Mock 전체 카탈로그):
  - `tactical`: design-review seed 4개. S1 행 4개(첫 행 분홍 선택 · "vs 게헨나 선도부 · 1회 · 2026-10-04 21:10", 셋째 "2회 · 2026-10-02", 넷째 "내 방어덱 · vs 아비도스 대책위원회 · 1회 · —", 빗금 · 흐린 칸 포함), 칩 "전체" 파랑, seg "기록" 분홍 · 분석 · 슬롯 흐림. S3 "공격 기록 · 2026-10-04 21:10" · "시즌 10" · 공격 칩 분홍, 상대 "게헨나 선도부" · "순위 — · 최근 대전 2회", 상대 덱 히나 · 이오리 · 아루 · 하루카 | 히비키 · 치세, 범례 "공개 — 로비 스캔 / 기록 1 · 2 · 3 · 4 · SP1 · SP2 지난 기록 / 빈칸 — 기록 없음", 내 덱 호시노 · 이즈나 · 미카 · 카요코 | 아야네 · 치세, 승리 분홍 · 시도 1 "첫 시도 성공", 메모 "첫 시도에 돌파했습니다.", 저장 · 복제 · 지우기 + 초록 "같은 시그니처 족보에 자동 연결됨". S2 "로비 스캔 / 준비 중", S4 "이 시그니처의 족보 / 준비 중".
  - `tactical-migration`: v1 기록 2개(공격 2026-07-23 · 방어 2026-07-20). 이관 띠 "기록 2건 · 족보 0건" + "가져오기", v1 행 2개("이전 형식" 칩, "— · 2026-07-23"), S3 "공격 기록 · 2026-07-23" 읽기 전용(버튼 흐림, 시도 '—', "이전 형식 기록은 가져온 뒤에 고칠 수 있습니다.").
  - 셸 머리말 "연결 안 됨" 칩은 Mock 기본 연결 상태 그대로(다른 golden과 같은 셸).
- 기존 장면 변화 0 근거: 바뀐 화면은 전술 탭뿐이고 다른 golden은 전술 탭을 열지 않는다(grep: `golden_harness.dart`의 `tactical`은 재화 `tactical_bd`뿐, 다른 golden 테스트에 `top-tab-pvp` 0). 탭 줄 글자 · 셸 파일 수정 0. 사고 복구 72개는 HEAD 바이트 그대로, 7개는 같은 토큰이라 그림이 바뀌지 않는다.

### 미검증(미실행)

- 전체 `fe_gate.ps1` · golden 비교 · `-UpdateGoldens` · `codealmanac validate` · 저장소 전체 `git diff --check`: **미실행**(CF 몫).
- 위 목록 밖 Flutter 테스트(Lane A 통계 · 계획 · 인벤토리 · 스캔 화면, 나머지 process E2E): **미실행**. `lib/services/**` 수정 0이라 process E2E 영향 없음 예상.
- 실제 백엔드에 붙인 화면 실행: **미실행** — 특히 이관 기록의 `source_record_id`가 백엔드에서도 `v7-v1:match:<ID>`인지(Mock 기준으로만 확인), 보유 학생 검사 · 별칭 검사(`opponent_alias_required`) 화면 문구.
- 사고 복구 7개 파일의 공백 · 줄바꿈 바이트 일치: **미확인**(위 사고 기록).
- 실제 사용자 프로필 · Windows release 빌드: **미실행**.

### 검수표(시안 Tactical, mock 모드 · 기준 viewport 최대화)

| 순서 | 여는 방법 | 확인 포인트 |
|---|---|---|
| 시안 Tactical | 개발 패널 design-review 시나리오 → 전술대항전 탭 | 4섹션 위치 · 모양(S3 윗변 −1.5px), 첫 행 선택 · 공격 · 승리 · 시도 1, S2 · S4 "준비 중", seg 분석 · 슬롯 흐림 + 툴팁 |
| 목록 | 같은 화면 S1 | 행 폭이 사선을 따라 줄어듦, 스크롤바 · 포그, 칩 필터(공격 · 방어 · 승 · 패 · 이번 시즌 · 상대 모달), 방어 행 "내 방어덱 · vs …", 시각 정밀도(날짜만 · KST · '—'), 시도 '—' |
| 고르기 | 행 누르기 | S3에 불러옴, 머리 · 시즌 · 종류 칩 · 범례 갱신, 자동 연결 문구(공격 기록) |
| 작성 | "새 기록" | 이름 입력 · 꺾쇠(상대 고르기), 칸 누르기 → 학생 고르기 모달(보유 학생 · 중복 흐림 · 빈칸으로 두기), 결과 · 시도 스테퍼 · 메모, 저장 불가 이유 문구 |
| 저장 | "저장" | 새 행이 맨 위에 생기고 골라짐, 고쳐 저장은 같은 행 |
| 복제 | "복제해서 새 기록" | "새 공격 기록" 초안(저장 전 목록 변화 없음) → 저장하면 새 행 |
| 삭제 | "지우기" | BaModal 확인(그만두기 · 지우기), 지우면 첫 행이 골라짐 |
| 이관 | v1 기록이 있는 계정(기본 Mock에서 v1 기록 저장 후) | 띠 · 읽기 전용 행 · 저장 불가 → "가져오기" → 띠 사라짐 · v2 행 · 시도 '—' → 시도 정한 뒤 저장 |

### WIP 보존 확인

- 이 slice가 고친 기존 3파일은 착수 때 WIP 없음(착수 기록). pre 사본 `debug/frontend_fe9a/pre/<경로>`, post 사본 `debug/frontend_fe9a/post/<경로>`(고친 3 + 새 6). `tactical_records_controller.dart` · `tactical_records_data.dart`는 pre와 cmp 일치.
- 다른 레인 파일: `dart format` 사고로 79개가 바뀌었다가 복구됨(위 사고 기록 — 72개 정확, 7개 토큰 일치 · 공백 · 줄바꿈 미확인). 스캐너 WIP(`scan_companion_dock.dart` · `scan_student_review_workspace.dart` · `scan_inventory_identity_review.dart`)와 Lane A 새 파일 `statistics_matrix_charts.dart`는 포매터가 바꾸지 않았다. git 쓰기 0회.

### 키트 승격 후보(Lane A 판단)

- `TacticalAttemptStepper`(모름 '—'을 가진 스테퍼 — `BaStepper`는 int 필수), `TacticalFilterChip`(누를 수 있는 `BaChip`), `TacticalDeckSlotRow` · `TacticalMiniDeck`(G §0 `DeckSlotRow` · `MiniDeckStrip`, FE9-c · d · e가 다시 씀), `TacticalSlotPortrait`(초상 · 빗금 · 빈 상자 한 칸).
- `_Scaled` · `_SectionFrame`(통계 `_ScaledBox` · `_SectionFrame`과 같은 코드 — 세 번째 사본).

### 삭제 후보 파일

- 없음(지운 파일 0). `tactical_service.dart` v1 쓰기 메서드는 Mock · process 테스트가 아직 쓴다(이관 전 v1 읽기와 이관 원본).

### 발견 사항

1. **덱 칸 수**: 프롬프트는 "내 덱 5칸 · 상대 덱 5칸"이지만 시안(1~4 · SP1 · SP2)과 계약(`strikers` 4 + `specials` 2)이 6칸이라 6칸으로 했다.
2. **FD-126 seg 자리**: 확정안은 "헤더 제목 옆"인데 머리말은 `app_shell.dart`(이 slice 수정 금지)이고 `PageHeaderOverride`에 seg 자리가 없다. S1 제목 줄에 두었다. FE9-e(분석 화면)에서 머리말로 옮기려면 셸 · `PageHeaderOverride` 확장이 필요하다(부제도 화면마다 바뀜) — CF 판단.
3. **FD-132 "상대 없이도 저장"**: v2 쓰기 입력은 `opponent_display_name` 비어 있지 않음 + `opponent_identity_id` 필수(schema · Dart strict). 방어 기록도 상대 이름이 있어야 저장된다. 권장안 표기는 그대로 따랐다. 상대 없는 방어 기록이 필요하면 계약 변경(XB).
4. **시도 횟수 "모름 가능"**: 쓰기 계약은 `attempt_count` ≥ 1 필수라 모름은 보이기만 하고 저장 전에 정해야 한다. 이관 기록을 고쳐 저장할 때마다 시도 횟수를 새로 정하게 된다(실제 값을 모르면 1을 넣게 될 위험) — 쓰기에서 null 허용 여부는 XB · CF 판단.
5. **이관 기록 ID**: 이관은 기록에 새 ID를 준다(Mock FNV 해시). 화면은 `source_record_id` `v7-v1:match:<v1 ID>`로 고른 행을 옮긴다 — Mock 규칙으로만 확인(백엔드 미확인).
6. **상대 identity**: 이름(현재 이름 · 별칭)이 같으면 그 identity, 아니면 화면이 새 ID를 만든다. 기존 기록의 상대 이름을 고치면 새 상대가 된다(별칭 등록 UI는 범위 밖).
7. **보유 학생**: 내 덱은 보유 학생만 고른다(v1 규칙). 기본 Mock은 보유 0이라 내 덱을 채울 수 없다. 검수 시 학생 스캔 Mock이나 design-review 시나리오가 필요하다.
8. **design-review seed 데이터**: seed 공격 덱 A의 SP2가 `chise`(카탈로그상 스트라이커). Mock은 역할을 검사하지 않아 그대로 보인다. 피커는 스페셜 칸에 스트라이커를 고를 수 없다(칸을 건드리지 않으면 그대로 되보낸다). seed를 고칠지 CF 판단.
9. **시안에 없는 요소**: S1 "새 기록", S3 "지우기", 이관 띠, 상대 칸 꺾쇠의 상대 고르기 모달, 상태 문구(저장 불가 이유 · 오류). 순위는 데이터가 없어 "순위 —".
10. **섹션 모션**: 탭 안 하위 화면 전환이 아직 없어(분석 · 슬롯 꺼짐) 섹션별 intro/outro를 넣지 않았다. 탭 전환 모션은 셸 것 그대로. FE9-e에서 부착면 표(S1 0/180, S2 260/80, S3 80/260, S4 180/0)대로.
11. **`dart format` 사고**: 위 사고 기록. 워커 프롬프트 표준 주의에 "`dart format`에는 디렉터리를 주지 않고 이 slice 파일 경로만"을 더하는 것을 권한다.
12. fe_gate 분류: `tactical_page_test.dart` · `tactical_page_revision_test.dart`에 `ProcessAppService` 문자열이 없어 일반 묶음이다.

### 사본 · commit.json

- `debug/frontend_fe9a/commit.json`: slice `fe9a`, modified 3, added 6, `post_dir` = `debug/frontend_fe9a/post`, `whole = []`, `optional_added` = `frontend/test/goldens/baseline/tactical.png` · `tactical-migration.png`, `status=true`.
- 사고 기록 자료: `debug/frontend_fe9a/format_incident/`. 인계: `debug/frontend_fe9a/output.md`.

### 다음 행동

- FE9-a 코드는 끝났다. Lane B는 여기서 멈춘다.
- CF: ① 사고 기록의 7개 파일(Lane A 6 · 스캐너 1) 공백 · 줄바꿈 확인을 해당 레인에 알림 ② Lane A가 멈춘 뒤 gate 1회(예상: analyze 0, 일반 테스트에서 tactical_page +19 · revision +5, golden 새 2장 RED → 승인 → `-UpdateGoldens`, 기존 golden 변화 0) ③ `fe_commit.ps1 -Slice fe9a`. 발견 1~4 · 8은 CF/XB 판단, 2는 FE9-e 착수 전에.

## scanwip-func 착수 기록 (2026-10-14)

- 상태: **진행 중 → 완료(아래 scanwip-func 종료 기록), CF candidate gate 미실행**. 범위: 스캐너 frontend WIP(tracked 13 + untracked 2)에서 XB `frontend-functional-hunks-390c194a.md/json`의 FUNCTIONAL hunk만 담은 post 사본(`debug/frontend_scanwipfunc/post/`)을 만들고, `candidate-v4-v7/frontend`를 "커밋 뒤 HEAD frontend"(HEAD tracked frontend + post)로 맞춰 사본에서 analyze · 스캐너 테스트. 근거: 사용자 결정 10:05, backend 로그 08:32 · 15:44 · 16:11(checkbox = 기존 5열 + 편집 중 index5 `FixedColumnWidth(84)`) · 18:37 · 19:32, `cf-gate-handoff.md`.
- 착수 전 확인: 이 문서 끝에 다른 "scanwip-func 착수 기록" 없음(grep 0건). 막힘: 대장 `열림` 0건.
- 시작 SHA(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`): `d2765e0a0ef6a9c9704d6ebb651420236c9c3239`. 15파일 모두 HEAD 내용 = `390c194a` 내용(HEAD 블롭 SHA = XB json `HEAD390c194a` SHA, 13/13).
- 15파일 SHA 대조(작업 트리 바이트 SHA-256 앞 12자리 · XB 17:27 캡처 `frontend-390-inputs-actual.json` · hunk json `working_at_capture`/`sha256`):

| 경로 | bytes | 작업 트리 SHA | =17:27 캡처 | =hunk json | 줄바꿈 |
|---|---:|---|---|---|---|
| `frontend/lib/services/mock_app_service.dart` | 121253 | `74f5584c3b45` | 일치 | 일치 | CRLF 주 + LF 128 |
| `frontend/lib/services/planning_protocol_client.dart` | 35678 | `8260f8a84f20` | 일치 | 일치 | CRLF 주 + LF 18 |
| `frontend/lib/services/process_app_service.dart` | 43479 | `12c955f8e5b1` | 일치 | 일치 | CRLF 주 + LF 24 |
| `frontend/lib/services/scanner_service.dart` | 34679 | `b5a2ba990262` | 일치 | 일치 | LF |
| `frontend/lib/ui/pages/scan_page.dart` | 73056 | `287623cc785d` | 일치 | 일치 | LF |
| `frontend/lib/ui/widgets/scan_companion_dock.dart` | 9269 | `57270a5fefda` | 일치 | 일치 | CRLF |
| `frontend/lib/ui/widgets/scan_student_review_workspace.dart` | 50455 | `05b0d8bb3623` | 일치 | 일치 | LF |
| `frontend/test/mock_scanner_service_test.dart` | 3962 | `5625fe9f0fb4` | 일치 | 일치 | CRLF |
| `frontend/test/scan_companion_dock_test.dart` | 3351 | `c9cb4031ade0` | 일치 | 일치 | CRLF |
| `frontend/test/scan_page_test.dart` | 29133 | `ea4b2e0299e7` | 일치 | 일치 | LF |
| `frontend/test/scan_student_review_workspace_test.dart` | 10457 | `5fb0984a834f` | 일치 | 일치 | LF |
| `frontend/test/scanner_process_e2e_test.dart` | 9926 | `e228a5e8e76f` | 일치 | 일치 | LF |
| `frontend/test/scanner_protocol_client_test.dart` | 11135 | `ee55a9d1d6cd` | 일치 | 일치 | LF |
| `frontend/lib/ui/widgets/scan_inventory_identity_review.dart`(untracked) | 8483 | `f7d533462b54` | 일치 | 일치 | LF |
| `frontend/test/scan_inventory_identity_review_test.dart`(untracked) | 3162 | `b26ccfbff52d` | 일치 | 일치 | LF |

- 메인 `git status --short frontend`: tracked 수정 13(위 표) · untracked = 위 2 + `frontend/assets/item_icons/activity_reports/`(4파일) · `frontend/assets/item_icons/ooparts/Item_Icon_WorkBook_Potential{Attack,HealPower,MaxHP}.png`(3파일). item_icons 7파일은 이 slice 밖(표에만). 그 밖 frontend 파일은 HEAD와 같다.
- 현재 `git diff -U3` hunk 머리(파일별 개수 · 옛 시작 줄)가 hunk json `head390c194a_line`과 13파일 모두 같다(mock 5 · client 3 · process 3 · scanner_service 6 · scan_page 16 · dock 7 · workspace 27 · 테스트 1/5/2/5/2/1). 목록 밖 hunk 0.
- 메인 쓰기 계획: `frontend/test/scan_student_review_workspace_test.dart`에 회귀 테스트 추가 1곳만. 그 밖 메인 파일은 이 문서 외 0. git 쓰기 0, `dart format` 0.

## scanwip-func 종료 기록 (2026-10-14, post · candidate 준비 완료 · CF candidate gate 미실행)

스캐너 frontend WIP에서 XB 390c194a 목록의 FUNCTIONAL hunk만 담은 post(tracked 11 + 새 2)를 만들었고, 같은 candidate id 새 revision 회귀 테스트 1건을 post와 메인 WIP 테스트 파일에 똑같이 더했다. `candidate-v4-v7/frontend`를 "커밋 뒤 HEAD frontend"로 맞추고 그 사본에서 analyze · 스캐너 테스트를 돌렸다. HEAD는 착수 때와 같다(`d2765e0a`). git 쓰기 0, `dart format` 0.

### 실행한 명령과 결과

- pre/post 생성: `python debug/frontend_scanwipfunc/tools/build_pre_post.py`(v7 폴더). 파일마다 `git diff -U3` hunk 머리를 hunk json과 대조(13/13 일치)하고, "pre + 모든 hunk = 작업 트리 바이트"를 확인한 뒤 FUNCTIONAL hunk만 작업 트리 바이트 그대로 pre에 이어 붙였다. 결과 `debug/frontend_scanwipfunc/logs/build-report.json`.
- 메인 `frontend`: `flutter analyze` **No issues found(0)**. `flutter test test/scan_student_review_workspace_test.dart` **+7 −0**(회귀 테스트 추가 뒤, 메인 WIP 위).
- 남는 것 검증: `python debug/frontend_scanwipfunc/tools/verify_remainder.py` → **PASS**(아래 표, `logs/remainder-check.json`).
- 3-way 모의(스크래치, LF로 맞춘 뒤 `git merge-file -p`, base = pre · ours = HEAD · theirs = post): 13파일 충돌 0, 병합 결과 = post 13/13(dock 2파일은 HEAD와 같아 변화 없음).
- candidate 맞추기: `python debug/frontend_scanwipfunc/tools/sync_candidate.py` → 대상 1582(HEAD tracked frontend 1580 중 post 13 대체 + 새 2), **바꾼 파일 43**, 다시 돌리면 0(멱등), HEAD 블롭 대체 0(쓰는 동안 다른 레인 편집과 겹친 파일 없음).
- candidate `frontend`: `flutter analyze` 1회차는 pub get이 "Building with plugins requires symlink support … enable Developer Mode" 안내를 내고 끝났다 → 2회차 **No issues found(0)**(exit 0). pub get 뒤 tracked 대상 파일 변화 0(sync dry-run 0).
- candidate 일반 스캐너 테스트 12파일(한 명령, json): **+132 −0** — mock_scanner_commit_history +9, mock_scanner_service +4, scan_companion_dock +3, scan_inventory_identity_review +2, scan_page_pause_fb10a +8, scan_page_revision +14, scan_page +17, scan_student_review_workspace +5, scanner_pause_fb10a +39, scanner_protocol_client +6, scanner_review_images_fb10c +6, scanner_target_metadata_fb4 +19.
- candidate process E2E(`--concurrency=1`, 파일마다 따로, candidate sibling backend): scanner_process_e2e **+1**, scanner_pause_process_e2e **+1**, scanner_review_images_fb10c_process_e2e **+1**, scanner_target_metadata_process_e2e **+1**. 실행 뒤 candidate backend · contracts에 새로 생기거나 바뀐 파일 0(`__pycache__` 포함). selected30 pins 30/30 그대로(`selected30-paths-sha.md` 대조).
- 회귀 테스트 변이 확인(candidate, 바로 원복): 위젯의 revision 비교 조건 앞에 `false &&`를 넣으면 workspace 테스트 **+4 −1**(새 테스트만 실패) → 원 바이트로 되돌림, SHA `2acef6b3b65f…` = post 확인.
- 표시 확인용 임시 테스트(candidate `test/zz_scanwip_probe_tmp_test.dart`, 실행 뒤 삭제): 발견 1.
- `git diff --check`(메인 테스트 파일 · 이 문서): exit 0. post 15파일: 줄 끝 공백 0 · 끝 개행 하나. 잠금 충돌 0(재시도 없음). 로그는 실패 줄 · json 요약만 확인(`debug/frontend_scanwipfunc/logs/`).

### 15파일 SHA 대조(종료)

착수 표와 같다 — 메인 14파일 바이트 그대로(SHA 14/14 착수 값과 일치). 바뀐 것은 `frontend/test/scan_student_review_workspace_test.dart` 하나: 10457 `5fb0984a834f…` → **13408 `2fd54a892cdb8ea5bf6ad940965dff8b5e4e6c0af52141fb1c15681ec31d7e70`**(회귀 테스트 추가만). `git status --short frontend` 항목 수는 착수 때와 같다(19).

### 파일별 hunk 처리

| 파일 | FUNCTIONAL 적용 | VISUAL 제외 | 나눈 hunk · 방법 | pre 줄바꿈 |
|---|---|---|---|---|
| `lib/services/mock_app_service.dart` | 188 · 498 · 512 · 528 · 556 | — | — (FE9-b1 몫은 이미 HEAD, 현재 diff에 없음) | CRLF 3067 + LF 128 |
| `lib/services/planning_protocol_client.dart` | 194 · 864 · 891 | — | — | CRLF 983 + LF 18 |
| `lib/services/process_app_service.dart` | 1232 · 1239 · 1252 | — | — | CRLF 1307 + LF 24 |
| `lib/services/scanner_service.dart` | 1 · 387 · 616 · 795 · 805 · 836 | — | — | LF |
| `lib/ui/pages/scan_page.dart` | 17 · 76 · 100 · 309 · 417 · 839 · 862 · 879 · 1193 · 1245 · 1473 · 1655 | 703 · 733 · 785 · 1620 | — | LF |
| `lib/ui/widgets/scan_companion_dock.dart` | — | 1 · 66 · 81 · 97 · 176 · 219 · 307(전부) | — (post = HEAD 내용, commit.json modified 밖) | CRLF |
| `lib/ui/widgets/scan_student_review_workspace.dart` | 15 · 80 · 89 · 234 · 255 · 484 · 494 · 505 · 554 · 1169 · **1178** · 1221 · 1250 · 1258 · 1297 | 6 · 323 · 785 · 815 · 828 · 911 · 961 · 969 · 1118 · 1131 · 1138 · 1156 | 1178: 실제 내용이 confirmedFields/onConfirmed 필드 · 기존 5열 너비 그대로(값 같음, `const` 맵 → 원소별 `const`) · `if (editing) 5: FixedColumnWidth(84)` · 머리 행 `const` 해제 + 편집 중 '화면 확인' 열뿐이라(media report 구조 0) **통째로 적용**, 쪼갤 것 없음 | LF |
| `test/mock_scanner_service_test.dart` | 24 | — | — | CRLF |
| `test/scan_companion_dock_test.dart` | — | 3 · 22 · 57 · 83 · 114(전부) | — (post = HEAD 내용, modified 밖) | CRLF |
| `test/scan_page_test.dart` | 198 · 250 | — | — | LF |
| `test/scan_student_review_workspace_test.dart` | 101 · 164 · **39(일부)** | 1 · 181 | 39: 새 줄 중 `testWidgets('review confirms edits and checked fields …')` 블록 + 뒤 빈 줄만 넣고, `test('wide scan report prioritizes …')` 5줄 + 뒤 빈 줄은 뺐다(뺀 바이트 `logs/split-dropped-39.txt`) | LF |
| `test/scanner_process_e2e_test.dart` | 35 · 124 | — | — | LF |
| `test/scanner_protocol_client_test.dart` | 220 | — | — | LF |
| `lib/ui/widgets/scan_inventory_identity_review.dart`(새) | 파일 전체 | — | — | LF |
| `test/scan_inventory_identity_review_test.dart`(새) | 파일 전체 | — | — | LF |

- pre = HEAD 내용에, 줄마다 작업 트리의 같은 줄 줄바꿈 바이트를 붙였다. 공유 서비스 3파일은 HEAD에 이미 있는 줄 중 LF로만 끝나는 줄이 작업 트리에 128 · 18 · 24줄 있어(예전 slice가 넣은 줄) 파일 전체를 CRLF로 바꾸면 작업 트리와 어긋난다 — 그래서 줄 단위로 맞췄다. WIP가 지운 줄(mock 1줄 · dock 여러 줄)은 앞 줄의 줄바꿈을 따랐다. 모든 pre는 줄바꿈을 LF로 맞추면 HEAD 블롭과 같다(13/13).
- 목록 밖 hunk 0, 한 줄 안에 기능 · 시각이 섞인 곳 0.

### 추가한 회귀 테스트

- `testWidgets('review resets draft, checked fields and errors when the same candidate gets a new revision')`(workspace 테스트, O1 confirmation 테스트 바로 뒤): 같은 id `safety`의 revision 1에서 편집 → level 91 입력 · weapon_level 화면 확인 체크 · bond_rank `bad`(정수 오류 문구 보임, 체크 켜짐) → 같은 id revision 2(level 80)로 다시 그림 → 오류 문구 없음 · 체크 꺼짐 → 재검증하면 `confirmedFields` 빈 집합 · 보낸 values = revision 2 값(`level 80 · bond_rank 20 · weapon_level 60`, 91 아님).
- post와 메인에 같은 바이트(LF)로 같은 자리(confirmation 테스트 뒤)에 넣었다. 메인에서는 그 뒤에 시각부 wide report 테스트가 그대로 이어진다.

### "작업 트리 − post = 시각부" 검증

`git diff --no-index -U0 <post> <메인>`(원 바이트, 줄바꿈 필터 없음)의 지운/더한 줄 묶음을, HEAD → 메인 diff에서 VISUAL hunk에 속한 줄(+ hunk39에서 뺀 wide 테스트 줄)과 비교했다. 줄바꿈만 다른 줄 0.

| 파일 | VISUAL hunk | post→메인 −/+ | 기대(시각부) −/+ | 일치 |
|---|---:|---|---|---|
| `mock_app_service.dart` · `planning_protocol_client.dart` · `process_app_service.dart` · `scanner_service.dart` | 0 | 0/0 (바이트 같음) | 0/0 | 예 |
| `scan_page.dart` | 4 | 42/12 | 42/12 | 예 |
| `scan_companion_dock.dart` | 7 | 254/56 | 254/56 | 예 |
| `scan_student_review_workspace.dart` | 12 | 56/121 | 56/121 | 예 |
| `mock_scanner_service_test.dart` · `scan_page_test.dart` · `scanner_process_e2e_test.dart` · `scanner_protocol_client_test.dart` | 0 | 0/0 (바이트 같음) | 0/0 | 예 |
| `scan_companion_dock_test.dart` | 5 | 40/14 | 40/14 | 예 |
| `scan_student_review_workspace_test.dart` | 2 + hunk39 일부 | 0/90 | 0/90(import 1 · wide 테스트 6 · hunk181 83) | 예 |
| 새 2파일 | — | 바이트 같음 | — | 예 |

### candidate frontend

- 대상 = 메인 HEAD tracked frontend 1580(post에 있는 13은 post로) + 새 2 = 1582. HEAD 내용과 같은 메인 작업 트리 바이트를 그대로 썼다(= 작업 트리 줄바꿈).
- 바꾼 43(경로 · bytes · SHA · 이전 SHA: `debug/frontend_scanwipfunc/candidate-frontend-pins.json`, 전체 대상 목록 `logs/candidate-target-manifest.json`, 바꾸기 전 `logs/candidate-before.json`):
  - post 5: `scan_page.dart` · `scan_companion_dock.dart` · `scan_student_review_workspace.dart` · `scan_companion_dock_test.dart` · `scan_student_review_workspace_test.dart`(시각부가 빠짐 · 회귀 테스트). 나머지 post 10은 이미 같았다.
  - 17:27 캡처 뒤 커밋(FE7-i `48f5e0ad` · FE9-a `f1422164`) 내용 14 + 새 4(`lib/ui/tactical/tactical_workspace.dart`, `test/goldens/fe9a_tactical_golden_test.dart`, golden `tactical.png` · `tactical-migration.png`). 통계 golden 4장 · `fe7a_statistics_golden_test.dart` 포함.
  - 줄바꿈만 다른 16(candidate는 CRLF, 메인 작업 트리는 LF 또는 다른 섞임): `.metadata` · `README.md` · `dart_test.yaml` · `tool/` 7(`fe_commit.ps1` 등, `fe_gate.ps1`은 이미 같음) · `windows/` 9. lib · test · assets · pubspec은 줄바꿈 차이 없었다.
- 대상 밖(`debug/frontend_scanwipfunc/candidate-extra.txt` 189항목, 지우지 않음 — CF 판단): `test/zz_fe7i_measure_tmp_test.dart` · `test/zz_fe7i_render_tmp_test.dart`(17:27 캡처 때 있던 임시 테스트, 메인에는 지금 없음 — **candidate `fe_gate.ps1`이 일반 테스트로 실행한다**), untracked 자산 7(`assets/item_icons/activity_reports/` 4 · `ooparts/Item_Icon_WorkBook_Potential*.png` 3, 메인에도 untracked로 있음), `test/goldens/failures/` 180(gitignore 대상 gate 출력). 내 analyze가 만든 생성물: `.dart_tool/` · `.flutter-plugins-dependencies` · `windows/flutter/ephemeral/`(목록에 없음).
- candidate backend · contracts · frontend 밖: 쓰기 0.

### 메인 작업 트리 변경 확인

- 바꾼 메인 파일: `frontend/test/scan_student_review_workspace_test.dart`(추가만) + 이 문서. 그 밖 메인 frontend · backend · contracts · `frontend/tool/**`: 0(WIP 14파일 SHA 그대로, `git status --short frontend` 19항목 그대로, HEAD `d2765e0a` 그대로).

### 미검증(미실행)

- candidate 전체 `fe_gate.ps1`(golden 비교 · 전체 일반 테스트 · 나머지 process E2E · almanac · diff check): **미실행**(CF 몫).
- golden 비교: **미실행**. 아래 발견 2의 이유로 candidate의 `scan-student-review` 장면은 RED일 수 있다(예측, 확인 안 함).
- 메인에서 스캐너 테스트 전체: **미실행**(workspace 1파일만).
- 실제 백엔드에 붙인 화면 · 실제 게임 스캔: **미실행**.

### 발견 사항

1. **같은 id 새 revision 뒤 편집 칸 표시**: draft · 체크 · 오류는 비워지지만, 편집 중이던 칸(`TextFormField`, key `scan-student-field-<field>`)은 `initialValue`가 처음 만들 때만 쓰여 예전에 친 글자(`91` · `bad`)를 계속 보여 준다. 재검증은 새 revision 값(80)을 보낸다 — 화면 값과 보내는 값이 다를 수 있다. 편집 상태(`_editing`)도 revision이 바뀌어도 유지된다. 이 slice는 WIP 바이트를 그대로 옮기므로 고치지 않았다(key에 revision을 넣으면 풀림) — FE8-f1 컨트롤러 추출 때 CF 판단.
2. **golden 기준선이 시각부를 포함했을 가능성**: `scan-student-review.png`는 FE1-g/FE1-c(2026-10-06)에 스캐너 WIP 전체(시각부 포함)가 작업 트리에 있는 상태에서 만들어졌고, 그 장면은 결과 목록(시각 hunk 969 `_CandidateResultRow` · 1118~1156 상태 틀 · 323 · 785 보고 너비)을 그린다. 편집 상태가 아니라 기능부(체크 열 · 안내 문구)는 그려지지 않는다. 그래서 candidate(시각부 없음)에서 이 장면이 HEAD 기준선과 다를 수 있다. 다르면: 커밋될 코드(시각부 없음)에 맞춘 새 기준선을 승인하면 메인 작업 트리(시각부 있음)에서는 FE8-g2까지 이 장면이 RED가 된다 — CF 판단. 다른 golden 장면은 스캐너 위젯을 쓰지 않는다(grep).
3. **HEAD 단독 불일치**: HEAD의 `fe1g_baseline_golden_test.dart:1233`은 이미 4인자 `onRevalidate: (_, _, _, _)`인데 HEAD typedef는 3인자다 — 깨끗한 HEAD checkout에서는 golden 테스트가 컴파일되지 않는다. 이 slice(4인자 typedef)를 커밋하면 맞아진다.
4. candidate의 `zz_fe7i_*_tmp_test.dart` 2개는 candidate gate에 섞여 돈다(위). 지울지 CF 판단.
5. candidate pub get이 Developer Mode(심볼릭 링크) 안내를 냈다 — `windows/flutter/ephemeral/.plugin_symlinks`가 비어 있다. analyze · 테스트에는 영향이 없었다. Windows 빌드는 이 사본에서 하지 않는다.
6. checkbox hunk 1178은 16:11 정정 그대로의 내용만 담고 있어 쪼갤 필요가 없었다. FE9-b1 위임 · interface는 현재 diff에 없다(HEAD에 이미 있음).

### 사본 · commit.json

- pre(13, HEAD 내용): `debug/frontend_scanwipfunc/pre/<경로>`. post(15 = tracked 13 + 새 2, dock 2파일은 HEAD 내용): `debug/frontend_scanwipfunc/post/<경로>`. 도구: `debug/frontend_scanwipfunc/tools/`.
- `debug/frontend_scanwipfunc/commit.json`: slice `scanwipfunc`, modified 11(dock 2파일 제외), added 2, `post_dir` = `debug/frontend_scanwipfunc/post`, `status=false`, `whole` = [이 문서]. pre 내용 = HEAD라 커밋 결과 = post(3-way 모의 확인).
- 인계: `debug/frontend_scanwipfunc/output.md`.

### 다음 행동

- Lane B는 여기서 멈춘다.
- CF: ① candidate `frontend/tool/fe_gate.ps1`(발견 2 · 4 확인) → ② 결과(summary 경로 · stamp · source30 unchanged pin · 최종 frontend pin = `candidate-frontend-pins.json`)를 backend 로그로 XB에 회신 → ③ XB source30 커밋 → ④ CF `fe_commit.ps1 -Slice scanwipfunc` → ⑤ FE8-f1(발견 1 반영 여부 포함).

## FE9-d 착수 기록 (2026-10-15)

- 상태: **진행 중 → 코드 작성 완료(아래 FE9-d 종료 기록), CF gate 미실행**. 범위: 전술대항전 기록 화면 S4 "이 시그니처의 족보"(공개 시그니처로 `TacticalEvidenceReadService` 통계 · 추이 · 추천 질의, FD-127 (a) 관측 지표만, FD-129 권장안) + 족보 → 내 덱 복사(끌기 고스트 · "놓으면 … 복사" 힌트, S3 "족보에서 가져오기" 버튼, 초안만 — 저장하지 않음).
- 착수 전 확인: 이 문서 끝에 다른 "FE9-d 착수 기록" 없음(grep 0건).
- 시작 SHA(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`): `810a15f2e840a2b369fdf7ed98aa9a0e52bccab0`.
- 막힘: 대장 "slice별 막힘 요약" FE9-d 행 FD-127은 확정(권장안 (a)), 현재 `열림` 0건. FD-129 · FD-134(워커 재량)는 권장안대로 처리할 예정.
- 고칠 기존 파일(착수 사본 `debug/frontend_fe9d/pre/<v7 기준 경로>`, 모두 작업 트리와 cmp 일치)과 WIP(`git status --short <경로>` 출력 0줄 = 모두 WIP 없음 → post_dir 불필요), 줄바꿈(`git ls-files --eol`):
  - `frontend/lib/ui/pages/tactical_page.dart`: WIP 없음. 작업 트리 CRLF(그대로 유지).
  - `frontend/lib/ui/tactical/tactical_workspace.dart`: WIP 없음. LF.
  - `frontend/lib/ui/studio/tactical_studio_layout.dart`: WIP 없음. LF.
  - `frontend/lib/services/design_review/tactical_records_data.dart`: WIP 없음. LF(seed 공개 칸 · 족보 2개용).
  - `frontend/lib/tactical/tactical_records_controller.dart`: WIP 없음. LF(꼭 필요할 때만 — 고치지 않으면 끝 기록에 적는다).
  - `frontend/test/tactical_page_test.dart` · `frontend/test/tactical_page_revision_test.dart` · `frontend/test/design_review_tactical_seed_test.dart` · `frontend/test/goldens/fe9a_tactical_golden_test.dart`: WIP 없음. LF(고치지 않은 파일은 끝 기록에 적는다).
  - 이 문서: WIP 없음. LF.
- 새 파일(예정): `frontend/lib/ui/tactical/tactical_jokbo_view.dart`(위젯 없는 모델: 공개 시그니처 · FD-129 족보 묶음 · 관측 값 · 복사 규칙), `frontend/lib/ui/tactical/tactical_jokbo_widgets.dart`(카드 · KPI · 대상 덱 · 고스트 · 놓기 힌트), `frontend/test/tactical_jokbo_panel_test.dart`.
- 고치지 않는 것: 스캐너 WIP 15파일, 그 밖의 `lib/services/**`, `lib/ui/kit/**` · `lib/ui/statistics/**` · `lib/statistics/**`(Lane A), `app_shell.dart`, golden harness, `frontend/tool/**`, backend · contracts, 택틱 소유 파일.

## FE9-d 종료 기록 (2026-10-15, 코드 작성 완료 · CF gate 미실행)

S4 "이 시그니처의 족보"(시안 Tactical S4)를 FE9-b1 `TacticalEvidenceReadService` 위에 그렸고, 족보 → 내 덱 복사(끌어 놓기 + "족보에서 가져오기")를 붙였다. 복사는 초안만 바꾸고 저장하지 않는다. HEAD는 착수 때와 같다(`810a15f2`). 아래 "사고 기록"(임시 렌더 파일이 golden 비교로 돈 일)을 CF가 먼저 봐 주십시오.

### 실행한 명령과 결과(이 PC, `frontend` 폴더)

- `flutter analyze`: 작성 중(이 slice 경로만) info 1(`library_private_types_in_public_api` — 고스트 틀 `updateRenderObject` 인자 타입) → 고침. 전체 `flutter analyze` 2회(중간 · 마지막) **No issues found(0)**. `pubspec.yaml` · `pubspec.lock` 변경 0.
- `flutter test test/tactical_page_test.dart`: ① +16 −4(모두 기대 변경 — seed 공개 칸으로 출처 범례 문구, 기본 Mock S4가 "준비 중" 대신 공개 칸 없음 안내) → 테스트 고침 → ② **+20**(S4 요소 rect 5개 추가 포함).
- 새 `flutter test test/tactical_jokbo_panel_test.dart`: ① +14 −3(테스트 쪽 3: 같은 덱에 같은 학생 · 기본 Mock 계정 보유 학생 0 · 800×600 기본 창 넘침) → ② +16 −1(테스트 픽스처 스페셜 칸) → ③ **+17**. 시안 좌표 확인을 더한 뒤 끌기 테스트만 다시 +1.
- 바뀐 동작에 걸리는 기존 테스트(grep: `TacticalPage` · `designReviewTactical` · `MockDesignReviewScenario` · `AppSection.pvp` · `top-tab-pvp` · `BAPlannerApp(` · `tactical_records_data` · `tactical_workspace` · `TacticalEvidenceReadService` + tactical 서비스 4), 일반 28파일 json(`--exclude-tags golden`): **+269 −0** — account_editor_fe8c +9, account_manager_fe8b +6, app_navigation_fe7d +14, app_navigation_tidy1 +11, connected_target_fe8d +8, design_review_tactical_seed +2, growth_calculator_view +24, home_app_shell +1, home_connect_fe8e +10, home_page +5, inventory_shell_lazy +1, mock_design_review_scenario +11, profile_delete_fb2d +17, section_template_studio +15, statistics_app_shell +2, statistics_filter +10, student_filter_followups +4, student_filter_modal +8, tactical_jokbo_panel +17, tactical_lobby_scanner_service +2, tactical_page_revision +5, tactical_page +20, tactical_records_controller +14, tactical_service +6, tactical_share_v1_contract +1, tactical_v2_service +5, title_page +25, widget +16.
- process 묶음 분류 1파일(`--concurrency=1`): tactical_fe9b1_read **+12**.
- 일회성 렌더(임시 `test/goldens/zz_fe9d_render_tmp_test.dart` = golden 파일 사본에서 비교 대신 `toImage` → scratchpad PNG, 실행 뒤 삭제): +3. 세 장면 모양을 눈으로 확인했다(아래 golden 절).
- `dart format`: 이 slice 파일만 경로 하나씩(디렉터리 인자 0). `--set-exit-if-changed` 9파일 모두 0.
- `git diff --check -- frontend almanac/workflows/frontend-redesign-status-lane-b.md`: exit 0. 새 3파일: CR 0 · 줄 끝 공백 0 · 끝 개행 하나. `tactical_page.dart`는 CRLF 그대로(944줄 모두 CRLF), 나머지 LF.
- 잠금 충돌 0(재시도 없음). 로그: `debug/frontend_fe9d/logs/`(실패 줄과 json 요약만 확인).

### 사고 기록 — 임시 렌더 사본이 golden 비교로 돌았다 (2026-10-15 23:10, CF 확인 필요)

- 첫 일회성 렌더에서 사본을 고치는 스크립트가 Windows 경로 이스케이프로 실패했는데, 고치지 않은 사본(= `fe9a_tactical_golden_test.dart` 그대로, `@Tags(['golden'])` 포함)이 그대로 실행됐다. 결과: `tactical` 실패(예상된 변화), `tactical-jokbo-drag` 실패(기준 이미지 없음), **`tactical-migration` 통과(기준 이미지와 같음)**. 의도한 비교가 아니므로 검증으로 세지 않는다(아래 golden 절은 "예상"으로 적는다).
- 부산물: `frontend/test/goldens/failures/tactical_{isolatedDiff,maskedDiff,masterImage,testImage}.png`(23:10, `.gitignore` 대상 — git 상태 변화 0). 지우지 않았다(CF gate가 덮어쓴다). 사본은 즉시 지웠고, 두 번째 렌더는 사본에서 `@Tags`와 비교 호출이 0건인지 grep으로 확인한 뒤 돌렸다.
- `baseline/` PNG 변경 0, `-UpdateGoldens` 실행 0.

### 고친 파일 · 새 파일

| 파일 | 내용 |
|---|---|
| `frontend/lib/ui/pages/tactical_page.dart`(CRLF) | S4 질의(시그니처 · 기록 revision · 상대 · 시즌이 바뀌면 200ms 디바운스 뒤 통계 · 추이 · 추천 병렬, 세대 번호로 늦은 응답 버림, dispose 때 타이머 취소), S4 값 조립, 끌어 놓기 · "족보에서 가져오기" 복사(초안만), 놓을 수 없는 이유, 복사 뒤 상태 문구 |
| `frontend/lib/ui/tactical/tactical_workspace.dart` | `TacticalJokboPanel` 값, S4 그리기(이관 전 · 계정 없음은 FE9-a "준비 중" 그대로), 카드 배치(섹션에 들어가는 만큼 + "족보 n개 중 k개"), 내 덱 줄 `DragTarget`(강조 · 힌트 알약), "족보에서 가져오기" 켬 · 툴팁 |
| `frontend/lib/ui/studio/tactical_studio_layout.dart` | S4 요소 좌표(KPI · 안내 · 카드 · 고스트 · 힌트 알약 · 강조), 주석 |
| `frontend/lib/services/design_review/tactical_records_data.dart` | seed: 공격 기록 상대 방어 덱의 1번 · SP1 · SP2를 `visible_lobby`(`lobby_scan`)로, 아비도스 방어 덱을 같은 공개 시그니처로(아래 seed 절) |
| `frontend/test/tactical_page_test.dart` | 출처 범례 기대값, 기본 Mock S4 기대값, S4 요소 rect 5 |
| `frontend/test/goldens/fe9a_tactical_golden_test.dart` | `tactical`이 S4 질의를 기다림, 새 장면 `tactical-jokbo-drag` |
| 새 `frontend/lib/ui/tactical/tactical_jokbo_view.dart` | 위젯 없는 모델: 공개 시그니처, FD-129 묶음, 관측 값 · 마지막 관측, 복사 규칙, 고른 카드, 상대 시각, KPI |
| 새 `frontend/lib/ui/tactical/tactical_jokbo_widgets.dart` | 대상 덱 줄 · KPI 줄 · 안내 줄 · 카드 · 덱 줄(초상만) · 고스트(화면 안으로 미는 틀) · 힌트 알약 · 강조 painter · 안내 문구 |
| 새 `frontend/test/tactical_jokbo_panel_test.dart` | 모델 6 + 화면 5 + 읽기 6(위 +17) |

고치지 않음: `lib/tactical/tactical_records_controller.dart`(**추가 0** — 화면에 필요한 기록 · 족보 · 기록 집계 · revision · 상대 identity가 이미 있고, 질의 세대는 화면 상태로 충분하다. pre와 cmp 일치), `test/tactical_page_revision_test.dart` · `test/design_review_tactical_seed_test.dart`(seed 바꾼 뒤에도 그대로 통과 — cmp 일치), 그 밖 `lib/services/**`, 키트 · Lane A · 스캐너 · 택틱 파일, `app_shell.dart`, golden harness.

### 처리한 FD

- **FD-127 (a)**: 관측 지표만. 숨긴 시안 지표는 아래 표.
- **FD-129(워커 재량, 권장안)**: 시그니처 족보 = 방어 덱이 그 공개 시그니처를 가진 족보 전부의 합집합(상대 · 완전 덱이 달라도). "연결 족보 n개" = 그 수. 부분 방어 덱(모름 칸이 있는 덱)의 족보도 공개 칸이 맞으면 넣는다(→ 발견 3).
- **FD-134(워커 재량)**: 해당 없음 — 시안 S4에 검증 강도 · 표본 적음 자리가 없고 검증 강도는 FD-127로 숨긴다. FE9-e에 그대로 남긴다.
- FD-128 (a): 복사는 초안만 바꾸고, 저장은 기존 "저장"(v2 upsert → 자동 족보)이다. 이 slice는 족보 쓰기를 하지 않는다.
- FE9-b1 발견 2(CF 결정 2026-10-15): 카드 승/패 = v2 기록에서 센 관측 값, `jokbo.wins/losses`는 0이 아니면 "가져온 집계 n승 m패" 보조 글자, 기록이 0인 자동 족보는 흐림 + "기록 없음" 칩(`TacticalJokboEntry.hasNoRecords`).

### 공개 시그니처 정의 · 질의 시점

- **공개 칸**: 로비에 보이는 세 위치(1번 = 스트라이커 0, SP1, SP2 — 백엔드 `TacticalV2Store._public_signature`와 같은 순서) 가운데 관측 상태 `visible_lobby`이고 학생이 있는 칸. 2~4번은 `visible_lobby`여도 넣지 않는다(백엔드 시그니처 형식에 자리가 없다).
- **시그니처 문자열**: 백엔드와 같은 `1번|SP1|SP2`, 공개 칸이 아니면 `?`(예 `hina|hibiki|ako`, SP2만 공개면 `?|?|ako`). 공개 칸 0이면 시그니처 없음 → 질의하지 않고 빈 상태("상대 덱에 로비 스캔 공개 칸(1번 · SP1 · SP2)이 없어 족보를 찾지 않았습니다.").
- **대상 덱**: S3에서 고른 기록 또는 작성 중 초안의 상대 덱(종류 칩을 바꿔도 상대 덱은 그대로라 시그니처도 그대로다).
- **질의**: 조건(계정 · 시그니처 · v2 revision · 상대 identity(이름 → identity, 없으면 초안 identity) · 시즌)이 바뀌면 200ms 디바운스 뒤 세 질의를 병렬로 보낸다 — 통계 `TacticalStatsFilters(public_signature)`, 추이 `TacticalTrendFilters(public_signature, as_of = 고정 시계)`, 추천 `TacticalRecommendationFilters(season, opponent, public_signature, as_of, top_k 10)`(상대 identity나 시즌을 모르면 추천은 묻지 않는다). 조건이 바뀔 때마다 세대 번호를 올려 이전 응답 · 대기 타이머를 버린다. dispose 뒤 응답은 setState하지 않는다.
- **오류**: 셋 중 하나라도 실패하면 S4 안내 줄이 "족보 통계를 읽지 못했습니다. 기록에서 센 값만 보입니다." + "다시 읽기"로 바뀐다. 카드는 컨트롤러 기록 집계로 남고 화면 다른 곳은 막지 않는다.
- **이관 전**(컨트롤러 `migrationRequired`) · 계정 없음 · 서비스 오류: S4는 FE9-a와 같은 제목 + "준비 중"이고 질의하지 않는다(판단: 이관 전 v2에는 v1 기록이 없어 통계가 비어 보이므로 열지 않는다, `tactical-migration` 변화 0이 목표).

### 카드 · KPI 값의 출처

| 자리(시안) | 값 | 출처 |
|---|---|---|
| 카드 목록 | 시그니처 족보(FD-129), 승 많은 순 → 패 적은 순 → 이름 순 | 컨트롤러 `jokbo`(v2 상태) |
| 관측 승/패 · 관측 성공률 | "관측 n승 m패 · 관측 성공률 x%"(표본 0이면 '—') | 통계 응답에 이 시그니처 행이 있으면 그 행 `attack_decks`의 같은 공격 덱 값(없으면 0승 0패), 행이 없으면 컨트롤러가 같은 편성(방어 · 공격 덱 identity) 기록을 센 값 |
| 마지막 관측("6시간 전 성공" 자리) | "마지막 관측 2026-10-04 21:10"(KST, date 정밀도는 날짜만) | 추이 신선도 `last_battle_at`(시그니처 · 공격 덱) → 추천 `last_observed_at` → 같은 편성 기록 시각 → '—' |
| 가져온 집계 | "가져온 집계 n승 m패"(0이 아닐 때만, 10px 보조) | `jokbo.wins/losses` |
| 방어 유저 | "n명" | 통계 시그니처 행 `opponent_count`(내 로비에 이 시그니처를 보인 상대 수), 행이 없으면 '—' |
| 연결 족보 | "n개" | FD-129 카드 수 |
| 최신 검증 | "n시간 전"(고정 시계 기준 상대 시각) | 추이 신선도 `last_success_at` 최댓값, 없으면 '—' |
| 숨은 편성 다양성 | 높음 · 보통 · 낮음 + "유형 n" | 추천 `ambiguity.grade` · `scenario_total`(관측된 완전 방어 덱 수), 없으면 '—'(→ 발견 8) |

### 숨긴 지표(FD-127 (a))

| 시안 | 처리 | 근거 |
|---|---|---|
| 카드 "채택률 52%" | 그리지 않음 | FD-127 목록(다수 사용자 데이터) |
| 카드 "독립 재현 28명" | 그리지 않음 | FD-127 목록(share analytics 독립 기여자) |
| 카드 "첫 시도 57%" · "평균 1.7회" | 그리지 않음 | 읽기 응답(통계 · 추이 · 추천)에 없음. v2 `attempt_count`로 셀 수는 있다 → 발견 5 |
| 하단 경고 "B 유저에게는 족보 A가 2승 5패 · 숨은 편성 차이 가능성" + "상대 카드 보기" | 그리지 않음 | "숨은 편성 차이 가능성"은 판단 지표, 상대 카드는 FE9-e |
| 상대 방어 승률 30일 · 변경 확률 · 보정 방어 · 검증 강도 | S4에 자리 없음(만들지 않음) | FD-127 |

### 복사 규칙

- 끌어 놓기(카드 → S3 내 덱 줄)와 "족보에서 가져오기"(S4에서 고른 카드 — 기본은 지금 내 덱과 같은 카드, 없으면 첫 카드, 누르면 바뀜) 모두 같은 일을 한다: 내 덱 6칸을 족보 공격 덱으로 **위치 그대로** 바꾼다. 저장 · 서비스 쓰기는 없다(초안만, 테스트로 revision 그대로 확인).
- **보유하지 않은 학생**: 그 칸은 빗금 빈칸(모름, `manual` 출처 `unknown`)으로 두고 상태 문구로 알린다 — "<족보 이름> 덱을 복사했습니다. 보유하지 않은 학생 n명(이름 · …)은 빈칸으로 두었습니다." 모두 보유면 "<족보 이름> 덱을 내 공격 덱에 복사했습니다. 저장하면 기록에 남습니다." 보유 = 계정 상태 학생 목록(내 덱 학생 고르기와 같은 규칙).
- 족보의 모름 · 와일드카드 칸은 모름, 확인된 빈칸은 확인된 빈칸(`empty`)으로 옮긴다. 복사한 칸은 `manual` 관측이다.
- **놓을 수 없는 경우**(드롭 거부 + 버튼 흐림, 이유 = 힌트 알약(회색) · 버튼 툴팁): 방어 기록 "방어 기록에는 족보 덱을 복사할 수 없습니다. 공격 기록에서만 복사합니다.", 이전 형식(v1) 기록 "이전 형식 기록은 가져온 뒤에 고칠 수 있습니다.", 저장 중 "저장하는 중에는 덱을 바꿀 수 없습니다.", 계정 없음 "지금은 덱을 바꿀 수 없습니다.", 카드 없음(버튼) "가져올 족보가 없습니다.". 이관 전에도 새 초안은 고칠 수 있지만 S4가 닫혀 있어 복사할 카드가 없다.
- 복사 뒤 상태 문구는 다음 초안 변경(칸 · 결과 · 시도 · 다른 행)까지 남는다. 순서: 오류 → 입력 오류 → 복사 문구 → 저장할 수 없는 이유 → 자동 연결.

### 정한 규칙

- 카드는 끌 수 있다(`Draggable`, 마우스 즉시 끌기, 커서 grab). 고스트는 포인터가 고스트 안 (237, 90)에 오게(시안 커서 자리) 놓고, 그릴 때 화면 밖으로 나가지 않게 민다(여백 8). 놓을 자리 = 내 덱 줄 자리(hit test). 강조 = 그 자리를 6씩 넓힌 사선 행(분홍 테두리 · 채움 .08), 힌트 알약 = 자리 왼쪽 위 (+49.6, −34.2).
- 카드는 섹션 아랫변 18 위까지 들어가는 만큼 놓고(기준 창 6장), 넘치면 마지막 자리에 "족보 n개 중 k개를 보입니다." 한 줄. 스크롤 없음(→ 발견 6).
- 대상 덱 줄 굵은 글자 = 모르는 칸 위치("4번 빈칸", 여럿이면 "3 · 4번 빈칸", SP가 끼면 "번" 없이, 없으면 "빈칸 없음", 모두면 "모두 빈칸"), 둘째 줄 = 시안 문구 그대로. 방어 기록이면 캡션이 "상대 공격 덱".
- 키보드 · 접근성: 카드는 `KitPressable`(포커스 · Enter로 고르기, 의미 레이블 = 시안 aria "족보 … — 끌어서 내 공격 덱에 놓으면 복사"), 복사는 "족보에서 가져오기" 버튼.

### design-review seed

- 공격 기록 3개의 상대 방어 덱: 1번 · SP1 · SP2 학생 칸 = `visible_lobby` · `lobby_scan`(로비 스캔 공개 칸 모양, Mock 쓰기 · 계약상 허용 — 백엔드 실제 저장은 미확인).
- 아비도스 방어 덱(dr-match-3)을 `aru · haruna · ? · ? | hibiki · empty` → **`hina · haruna · ? · empty | hibiki · ako`**로 바꿨다: 게헨나 덱과 공개 시그니처(`hina|hibiki|ako`)가 같아 게헨나 기록을 고르면 FD-129 합집합 카드 2장(완전 덱 · 부분 덱)이 보인다. 모름 칸 · 확인된 빈칸 예시는 그대로 남는다.
- 방어 기록(dr-match-4)의 덱은 공개 칸 없이 예전 구성 그대로(내 방어 덱 = 게헨나 학생, 상대 공격 덱 = 옛 아비도스 구성). 기록 수 4 · 자동 족보 2 · revision 4는 같다.

### golden 변화 예상(비교 미실행 — 사고 기록의 우연한 실행은 세지 않는다)

- `tactical`: **바뀜**. S4 "준비 중" → 대상 방어 덱 줄("대상 방어 덱 / 게헨나 선도부" · 히나 … 아코 · "빈칸 없음"), KPI(방어 유저 — · 연결 족보 2개 · 최신 검증 — · 숨은 편성 다양성 낮음 / 유형 1), 끌기 안내, 카드 2장 — 위 "족보 3a0a33 · haruna"(마지막 관측 2026-10-02, 관측 1승 0패 · 100%), 아래 "족보 edd9e2 · hoshino"(분홍 선택, 마지막 관측 2026-10-04 21:10, 1승 1패 · 50%). S3 출처 범례 "공개 1 · SP1 · SP2 로비 스캔 / 기록 2 · 3 · 4 지난 기록 / 빈칸 — 기록 없음". S1 셋째 행(아비도스 공격) 상대 덱 미니 줄이 히나 · 하루나 · 빗금 · 빈 상자 | 히비키 · 아코로 바뀜. 일회성 렌더로 모양 확인.
- `tactical-migration`: **변화 0 예상**(S4는 FE9-a와 같은 "준비 중", "족보에서 가져오기"는 흐림 그대로, 놓을 자리는 끌 때만 그린다). 사고 기록의 우연한 실행에서 통과했다.
- 새 `tactical-jokbo-drag`(optional_added): `tactical`과 같은 화면에서 위 카드("족보 3a0a33 · haruna")를 끌어 포인터 (1399, 829)에 둔 상태 — 고스트 (1162, 739, 448×104, −2.5°, 이름 + 덱 6칸 40×32), 내 덱 줄 분홍 강조, 힌트 알약 "놓으면 족보 3a0a33 · haruna 덱으로 복사 · 위치 포함"(783, 679), 내 덱은 그대로. 일회성 렌더로 모양 확인, 위젯 테스트가 고스트 · 알약 · 강조 위치를 시안 ±2px로 고정.
- 다른 장면: 변화 0 예상(전술 탭을 여는 golden은 이 파일뿐, 셸 · 키트 수정 0).

### 미검증(미실행)

- 전체 `fe_gate.ps1` · golden 비교(의도한 실행) · `-UpdateGoldens` · `codealmanac validate` · 저장소 전체 `git diff --check`: **미실행**(CF 몫).
- 위 목록 밖 Flutter 테스트(Lane A 통계 · 계획 · 인벤토리 · 스캔, 나머지 process E2E): **미실행**. `lib/services/**`는 design-review seed 데이터만 바뀌어 process E2E 영향 없음 예상.
- 실제 백엔드에 붙인 S4: **미실행** — 로비 연결 기록이 있을 때 통계 시그니처 행 · 신선도 값, 추천 질의 속도, `visible_lobby` 칸을 가진 기록 저장(백엔드가 이 상태 · 출처를 받는지).
- 마우스 실제 끌기(Windows 앱): **미실행**(위젯 테스트 제스처로만).
- 실제 사용자 프로필 · Windows release 빌드: **미실행**.

### 검수표(시안 Tactical, mock 모드 · 기준 viewport 최대화)

| 순서 | 여는 방법 | 확인 포인트 |
|---|---|---|
| S3 기록 고르기 | 개발 패널 design-review 시나리오 → 전술대항전 탭(첫 행 게헨나 공격이 골라짐) | S3 범례 "공개 1 · SP1 · SP2", S4 대상 덱 줄 · KPI(— · 2개 · — · 낮음 유형 1) · 안내 문구 |
| S4 카드 | 같은 화면 | 카드 2장 위치(왼쪽 사선을 따라 넓어짐), 손잡이 점, 이름 · 마지막 관측, 덱 44×36, 관측 승/패 · 성공률(초록), 지금 내 덱과 같은 카드가 분홍 선택. 채택률 · 독립 재현 · 첫 시도 · 평균 · 하단 경고 없음 |
| 다른 기록 | S1 셋째 행(아비도스 공격) · 넷째 행(방어) | 같은 시그니처라 카드 2장 그대로(대상 이름 바뀜) / 방어 행은 "공개 칸이 없어…" 빈 상태 |
| 끌기 | 위 카드를 S3 내 덱 줄로 끌기 | 고스트(기울어짐, 화면 밖으로 안 나감), 내 덱 줄 분홍 강조, 알약 "놓으면 … 덱으로 복사 · 위치 포함" |
| 놓기 | 내 덱 줄에서 놓기 | 내 덱 6칸 = 그 족보 덱(보유하지 않은 학생은 빗금), 상태 문구, 그 카드가 선택됨, 목록 · revision 변화 없음(저장 안 함) |
| 버튼 | 다른 카드를 눌러 고른 뒤 "족보에서 가져오기" | 끌기와 같은 결과, 툴팁 "오른쪽에서 고른 족보 덱을…" |
| 방어 거부 | S3 종류 칩 방어 | 버튼 흐림 · 툴팁 이유, 끌면 회색 알약 이유, 놓아도 그대로 |
| 이관 전 | v1 기록만 있는 계정 | S4 "준비 중", 버튼 흐림 |

### WIP 보존 확인

- 이 slice가 고친 기존 파일 6개 + 이 문서는 착수 때 WIP 없음(착수 기록) → `post_dir` 없음. pre 사본 `debug/frontend_fe9d/pre/<경로>`. 고치지 않은 3파일(컨트롤러 · revision 테스트 · seed 테스트)은 pre와 cmp 일치.
- 스캐너 WIP 15파일 · Lane A 파일 · 택틱 파일: 열지도 고치지도 않았다(`git status --short`에 보이는 그 밖의 ` M` · `??`는 다른 레인 것 그대로). `dart format`은 이 slice 파일 경로만. git 쓰기 0회.

### 키트 승격 후보(Lane A 판단)

- `TacticalDeckStrip`(덱 6칸 초상 줄 — `TacticalMiniDeck`과 라벨만 다름), `TacticalDropPill`(skew 알약), `TacticalDragGhostFrame`(그릴 때 화면 안으로 미는 틀 — 끌기 고스트 공용), `TacticalDropHighlightPainter`(사선 행 강조).
- `DiagonalScrollViewport`에 왼쪽 사선 레일(오른쪽 사다리꼴 섹션, 아래로 갈수록 넓어지는 행) 모드가 없다 → 발견 6.

### 발견 사항

1. **Mock에는 로비가 없어** 통계 시그니처 행 · 신선도가 늘 비어 있다(FE9-b1 Mock 차이 그대로, 고치지 않음): design-review에서 방어 유저 · 최신 검증은 '—'이고 카드 승/패는 컨트롤러 기록 집계다. 실제 백엔드는 로비 후보에 연결된 기록만 시그니처 통계에 들어간다.
2. **카드 승/패의 두 출처**: 통계 행이 있으면 "이 공개 시그니처에 연결된 기록을 공격 덱별로 센 값"(완전 덱이 달라도 같은 공격 덱은 같은 숫자), 없으면 "같은 완전 방어 덱 + 같은 공격 덱 기록을 센 값"이다. 둘 다 v2 기록 관측 값이지만 뜻이 조금 다르다 — 통일할지(예: 늘 컨트롤러 집계) CF 판단.
3. **대상 덱 안내 문구 vs FD-129**: 시안 "빈칸은 아무 학생이나 일치로 보고 족보를 찾았습니다"는 그대로 두었지만, FD-129는 공개 칸만 맞추므로 기록 칸(2~4번)도 아무 학생이나 맞는 것으로 본다. 부분 덱(모름 칸 있음) 족보도 넣었다. 문구를 바꿀지 CF 판단.
4. **Mock 자동 족보 이름이 학생 ID**("족보 3a0a33 · haruna", FB-6 Mock 차이): golden · 검수 화면에 ID가 보인다. 백엔드는 표시명이다.
5. **첫 시도 · 평균 시도**: v2 `attempt_count`로 같은 편성 기록에서 셀 수 있다(관측 값). 읽기 응답에 없어 이번에는 그리지 않았다 — FE9-e 후보.
6. **S4 스크롤 없음**: 키트 사선 스크롤은 오른쪽 레일만 지원해 카드를 들어가는 만큼만(기준 6장) 놓고 "족보 n개 중 k개" 한 줄로 알린다. 많은 족보 보기는 FE9-e "전체 보기"나 키트 왼쪽 레일 모드(Lane A)가 필요하다.
7. **마지막 관측은 절대 시각**: 시안 "6시간 전 성공"과 달리 KST 시각으로 보인다 — golden의 `MockAppService`는 고정 시계(`AppClockSource`)가 아니라 상대 시각이 실행 시각에 따라 바뀐다. "최신 검증" KPI는 상대 시각(Mock은 늘 '—').
8. **숨은 편성 다양성**: 추천 `ambiguity.grade`(관측된 완전 방어 덱의 근거 비율로 정한 등급)와 `scenario_total`을 그렸다. 확률 · 보정 지표는 아니라 FD-127 숨김 목록 밖으로 판단했다 — 숨길지 CF 판단.
9. **기본 Mock 계정의 보유 학생**: 이 계정의 계정 상태 학생 목록이 비어 있어(FE9-a 발견 7) 기본 Mock에서 복사하면 모든 칸이 빗금이다. 테스트는 `saveRepositoryStudents`로 보유 학생을 넣었다. design-review 시나리오는 확인하지 않았다(미실행).
10. **시안의 끌기 궤적 선**(원래 카드 → 커서 분홍 곡선)과 그려진 커서는 만들지 않았다(앱은 실제 커서). 힌트 알약은 시안처럼 "내 공격 덱 · 위치 포함" 캡션을 덮는다.
11. **seed 덱 구성 변경**(아비도스 방어 덱): 검수 · golden에서 S1 셋째 행 미니 덱이 바뀐다. 다른 seed 소비처(design-review 시나리오 테스트 · seed 역할 테스트 · revision 테스트)는 그대로 통과.
12. 사고 기록(임시 렌더 사본의 golden 비교 실행)과 `failures/tactical_*.png` 부산물 — 위 절.
13. fe_gate 분류: 새 `tactical_jokbo_panel_test.dart`에 `ProcessAppService` 문자열이 없어 일반 묶음이다(+17, 약 5초).

### 사본 · commit.json

- `debug/frontend_fe9d/commit.json`: slice `fe9d`, modified 6(이 문서는 `whole`), added 3, `post_dir` 없음(WIP 없음), `whole` = 이 문서 · `frontend/test/goldens/baseline/tactical.png`, `optional_added` = `frontend/test/goldens/baseline/tactical-jokbo-drag.png`, `status=true`.
- 인계: `debug/frontend_fe9d/output.md`. 로그 `debug/frontend_fe9d/logs/`.

### 다음 행동

- FE9-d 코드는 끝났다. Lane B는 여기서 멈춘다.
- CF: ① 사고 기록 확인 ② Lane A가 멈춘 뒤 gate 1회(예상: analyze 0, 일반 테스트에 tactical_jokbo_panel +17 · tactical_page +20, golden `tactical` RED(변화 예상대로) · `tactical-jokbo-drag` 새 기준 없음 · `tactical-migration` GREEN → 승인 → `-UpdateGoldens`) ③ `fe_commit.ps1 -Slice fe9d`. 발견 2 · 3 · 8은 CF 판단, 5 · 6은 FE9-e · Lane A 후보.

## fb7-dart 착수 기록 (2026-10-16)

- 상태: 진행 중.
- 범위: FB-7(전술 엑셀·UTF-8 CSV 가져오기 해석)의 Dart 연결 — 새 메서드 2(`tactical.v2.excel.preview`·`tactical.v2.excel.commit`)의 요청·성공 strict DTO·validator, `_methodErrorCodes['tactical']` 추가, Process·Mock(CSV 최소 의미), 계약 fixture 왕복 테스트, 실제 백엔드 process E2E 1. 화면(엑셀 가져오기 모달)은 FE9-f라 범위 밖. 근거: XB `810a15f2`, `debug/xb_fb7_interpreter_prepare_20261014/artifacts/dart-handoff-final.md`, `contracts/README.md` "FB7 Excel / UTF-8 CSV import", backend 로그 2026-10-15 16:57·17:15·01:09, FD-128(확정 (a))·FD-131(워커 재량).
- 착수 전 확인: 이 문서 끝에 다른 "fb7-dart 착수 기록" 없음.
- 시작 커밋(HEAD, 브랜치 `scanner-consolidation`): `1d9a11b360ecf5a090150ee49000cfcae0be6407`.
- 막힘: 대장 막힘 요약 현재 `열림` 0건. FB-7·FE9-f 행의 FD-128은 확정. FD-131은 '워커 재량'(권장안 = Python 파서·.xlsx+.csv·시트 선택·분모 = 가져올 건수·규칙 프로필별 저장) — 백엔드가 이미 그 모양으로 커밋했고 이 slice는 그대로 연결만 한다.
- 계약 읽기 기준: excel 정의는 HEAD(`810a15f2`) schema. 메인 작업 트리 schema·README에는 XB 미커밋 변경(typed read 배열·FB-10 절)이 있지만 `excel*` 정의·fixture·FB7 절에는 차이 0(`git diff -U0` 확인).
- 고칠 기존 파일(착수 사본 `debug/frontend_fb7dart/pre/<v7 기준 경로>`), WIP(`git status --short <경로>`), 줄바꿈(바이트로 셈):
  - `frontend/lib/services/tactical_v2_service.dart`: WIP 없음. LF.
  - `frontend/lib/services/planning_protocol_client.dart`: WIP 없음. CRLF 1051 + LF 18.
  - `frontend/lib/services/process_app_service.dart`: WIP 없음. CRLF 1330 + LF 24.
  - `frontend/lib/services/mock_app_service.dart`: WIP 없음. CRLF 3194 + LF 128.
  - `frontend/lib/services/mock_tactical_v2_writes.dart`: WIP 없음. LF.
  - `almanac/workflows/frontend-redesign-status-lane-b.md`: WIP 없음(이 기록). LF.
- 새 파일(예정): `frontend/lib/services/mock_tactical_v2_excel.dart`(Mock CSV 최소 의미, `mock_tactical_v2_writes.dart`의 part), `frontend/test/tactical_fb7_dart_test.dart`(계약 fixture·DTO·validator·allowlist·Process·Mock), `frontend/test/tactical_fb7_process_e2e_test.dart`(실제 백엔드).
- post 사본·`post_dir`: WIP 있는 파일이 없어 만들지 않는다.

## fb7-dart 종료 기록 (2026-10-16, 코드 작성 완료 · CF gate 미실행)

FB-7 엑셀·UTF-8 CSV 가져오기의 Dart 연결을 끝냈다. 새 메서드 2(`tactical.v2.excel.preview`·`tactical.v2.excel.commit`)의 요청·성공 strict DTO와 validator, capability `TacticalExcelImportService`(Process·Mock), tactical 오류 allowlist +2, Mock CSV 최소 의미(새 part 파일), 계약 fixture 왕복 테스트, 실제 백엔드 process E2E. 화면(FE9-f 엑셀 가져오기 모달)은 건드리지 않았다. HEAD는 착수 때와 같다(`1d9a11b3`), git 쓰기 0회.

### 실행한 명령과 결과(이 PC, `frontend` 폴더)

- `flutter analyze lib/services/tactical_v2_service.dart`: ① error 1(`_countV2` 중복 정의 — 같은 뜻의 기존 함수가 있어 내 것을 지움)·warning 1·info 1(`prefer_initializing_formals` — 이슈 키 집합을 공개 `wireKeys`로) → ② **No issues found(0)**.
- `flutter analyze lib/services test/tactical_fb7_dart_test.dart test/tactical_fb7_process_e2e_test.dart`: **0**(여러 번).
- 전체 `flutter analyze`: 작업 중 1회는 error 1(`lib/ui/app_shell.dart:476` `headerOverride` — Lane A FE9-e 편집 중 파일, 이 slice 파일 아님). 마지막 실행 **No issues found(0)**(Lane A가 그사이 맞춤).
- `flutter test test/tactical_fb7_dart_test.dart`: 첫 실행부터 **+12 −0**(process 묶음 실행에서도 +12).
- `flutter test --concurrency=1 test/tactical_fb7_process_e2e_test.dart`: ① +1(약 3초) → 원본 보존·v1 프로필 검사 추가 → ② −1(테스트 쪽: 두 번째 프로필에 보유 학생이 없어 v1 쓰기가 `invalid_payload`) → 보유 학생 저장 추가 → ③ **+1** ④ **+1**(각 약 3초). 남은 임시 폴더 `ba_planner_fb7_*` 0.
- 바뀐 동작에 걸리는 기존 테스트(grep: `tactical_v2_service`·`TacticalEvidence`·`mock_tactical_v2`·`upsertTacticalMatchV2`·`_methodErrorCodes`·`planning_protocol_client`·`deleteProfile`·`saveTacticalMatch` + fb6 선례 목록):
  - 일반(json, 20파일 병렬): **+182 −4**. 성공: design_review_tactical_seed +2, inventory_review_fb10b +19, mock_design_review_scenario +11, mock_scanner_commit_history +9, mock_scanner_service +4, repository_presets_service +49, repository_protocol_contract +1, scanner_protocol_client +6, tactical_fe9b1_read +12, tactical_jokbo_panel +17, tactical_lobby_scanner_service +2, tactical_page_revision +5, tactical_page +19, tactical_records_controller +14, tactical_service +6, tactical_share_v1_contract +1, tactical_v2_service +5. 실패 4: account_manager_fe8b·home_app_shell·profile_delete_fb2d 컴파일 실패(위 `app_shell.dart:476`, Lane A WIP), tactical_page 1건(아래).
  - 재시도 1회(Lane A가 `app_shell.dart`를 맞춘 뒤, 5파일): **+59 −1** — account_manager_fe8b +6, home_app_shell +1, profile_delete_fb2d +17, widget_test +16, tactical_page +19 −1. 남은 실패 `sub views analysis and slots are disabled with 준비 중`(`tactical_page_test.dart:417`, 분석 하위 화면 툴팁이 없어 `No element`)은 Lane A FE9-e가 분석 하위 화면을 켜는 중이라 생긴다(`tactical_workspace.dart` 수정·`tactical_analysis_view.dart` 새 파일, 미커밋). 이 slice는 `lib/ui/**`와 그 테스트를 고치지 않았다 — Lane A 몫.
  - process 묶음(`--concurrency=1`, 파일마다 따로): tactical_fb7_dart **+12**, tactical_fb6_dart **+14**, planning_protocol_client **+24**, tactical_fb7_process_e2e **+1**, tactical_fb6_process_e2e **+1**, tactical_v2_process_e2e **+1**, tactical_process_e2e **+1**, profile_delete_fb2d_process_e2e **+1**. 모두 −0.
- `dart format`: LF 파일만 경로를 하나씩(`tactical_v2_service.dart`·`mock_tactical_v2_writes.dart`·새 3파일). CRLF 공유 3파일은 포맷하지 않고 바이트 삽입했다 — `dart format --output=show` 결과와 비교한 포맷 차이 hunk 수가 pre 사본과 같다(planning 1 · process 1 · mock 38, 모두 기존 줄) → 이 slice 삽입은 포맷 상태. `mock_tactical_v2_writes.dart` 포맷은 이 slice hunk만 바꿨다(pre 대비 diff 블록 = part 지시·`_no_change`·`_applyMatch`).
- `git diff --check -- frontend/lib/services/`: exit 0. 새 3파일: CR 0 · 줄 끝 공백 0 · 끝 개행 하나. `pubspec.yaml`·`pubspec.lock` 변경 0.
- 잠금 충돌 0(재시도 없음). 로그 `debug/frontend_fb7dart/logs/`(실패 줄과 json 요약만 확인).

### 고친 파일 · 새 파일

- `frontend/lib/services/tactical_v2_service.dart`(WIP 없음, LF, 삽입만 1296줄): `dart:convert` import, `TacticalMatchInputV2.fromWire`(13키, 미리보기 행 `match`), FB-7 DTO — `TacticalExcelColumnMapping`·`TacticalExcelResolutionValue`(sealed: `TacticalExcelTextValue`·`TacticalExcelIntegerValue`·`TacticalExcelNewOpponentValue`)·`TacticalExcelResolution`·`TacticalExcelRowDecision`·`TacticalExcelImportChoices`·`TacticalExcelIssue`·`TacticalExcelRawCell`·`TacticalExcelPreviewRow`·`TacticalExcelSuggestion`(sealed: 학생·상대·결과)·`TacticalExcelPlace`(record typedef)·`TacticalExcelStringGroup`·`TacticalExcelConflict`·`TacticalExcelMappingCandidate`·`TacticalExcelSummary`·`TacticalExcelPreview`·`TacticalExcelCommitResult`(모두 exact 키 · `toWire` 왕복), 공개 필드 상수 `tacticalExcelFields`·`…ScalarFields`·`…SlotFields`·`…RequiredFields`, capability `TacticalExcelImportService`, `tacticalExcelCommitPayload`, `isValidTacticalV2ProtocolMessage` 요청 2·성공 2 갈래. 기존 줄 변경 0.
- `frontend/lib/services/planning_protocol_client.dart`(WIP 없음, CRLF 삽입 3줄): `_methodErrorCodes['tactical']`에 `import_interpretation_changed`·`import_source_unreadable` + 주석 1줄.
- `frontend/lib/services/process_app_service.dart`(WIP 없음, CRLF 삽입 31줄): implements `TacticalExcelImportService`, 두 메서드(기존 `_tacticalV2Write` = 보내기 전 strict 검사).
- `frontend/lib/services/mock_app_service.dart`(WIP 없음, CRLF 삽입 34줄): implements, `_tacticalExcel`(늦은 생성), `@visibleForTesting debugSetTacticalExcelSource(path, rows)`(null = 원본 삭제), 두 메서드 위임.
- `frontend/lib/services/mock_tactical_v2_writes.dart`(WIP 없음, LF): `part 'mock_tactical_v2_excel.dart'`, `_mutation`이 apply 결과의 `_no_change`면 revision을 올리지 않음(FB-7만 쓴다), `upsertMatch` 적용 본문을 `_applyMatch(value, input, {recordMetadata})`로 옮김(수동 기록 규칙 그대로 — 출처 4필드 유지·`manual_edit`; FB-7 원본 행 메타데이터면 `created_at`만 유지, backend `apply_match`와 같다).
- 새 `frontend/lib/services/mock_tactical_v2_excel.dart`(part): Mock CSV 최소 의미(아래 "Mock 차이").
- 새 테스트: `frontend/test/tactical_fb7_dart_test.dart`(12), `frontend/test/tactical_fb7_process_e2e_test.dart`(1).
- 고치지 않음: backend/**·contracts/**, `lib/ui/**`(FE9-f · Lane A FE9-e), 스캐너 시각부 5파일, `scanner_service.dart`, 택틱 소유 파일, golden harness·golden 테스트, `frontend/tool/**`, `app_shell.dart`, 기존 테스트 파일.

### handoff 목록(dart-handoff-final.md) 행별 검수

| handoff 행 | 처리 | 근거 테스트 |
|---|---|---|
| 새 메서드 2 | 요청·성공 갈래 2+2, capability `TacticalExcelImportService`, Process·Mock 구현 | fb7_dart "shared FB-7 fixture…"·"ProcessAppService sends exact…", E2E |
| 두 요청 공통 8키(시트 null/정확한 이름, 구분자 쉼표·탭, 매핑 null/명시 `{header_row, columns}`, resolutions, row_decisions, on_conflict skip/overwrite) | `TacticalExcelImportChoices`·`_validExcelChoicesV2`(exact 8키, profile 24hex, 경로·시트 비지 않음) | "requests are exact…"(음성 26종 × preview·commit) |
| commit +5키(`save_rules`·`expected_fingerprint`·`expected_interpretation_fingerprint`·`expected_revision`·`idempotency_key`) | commit 갈래 exact 13키, bool·sha256 2·revision ≥ 0·key 비지 않음, `tacticalExcelCommitPayload` | 같은 테스트 음성 6종, fixture `save-rules-not-int` |
| 매핑 필드 19(1부터), 열 중복 없음, 후보·저장 매핑은 명시 확인 | `TacticalExcelColumnMapping`(필수 5 · 열 1~64 · 머리글 1~10000 · 열 중복 거부), 후보 DTO `requires_confirmation` true만, 매핑 null 미리보기 = 후보 + `mapping_confirmation_required` | 음성(필수 빠짐·모르는 필드·중복 열·열 65·머리글 0), Mock·E2E "매핑 없는 미리보기" |
| 날짜·결과·양수 시도는 풀려야 함, now·1·0 없음, 빈 슬롯 = 모름, 와일드카드는 명시 resolution | Dart는 해석하지 않는다. 와일드카드는 슬롯 필드만(validator) | fixture `wildcard-not-attempts`, Mock·E2E `positive_attempts_required`·`result_resolution_required` 그룹 |
| resolution `{field, raw, action, value, row?}`, raw = typed raw_key, 행동 5, 값 = 학생 ID·기존 상대 ID·새 `{identity_id, display_name}`, 제안은 제안일 뿐, 전역 규칙만 저장(행·skip 제외) | `TacticalExcelResolution` + sealed 값 3종(null 허용), value 밖 행동은 value null, raw ≤ 8192 UTF-8 바이트, (행, 필드, 원값) 중복 거부 | "requests…"·"typed variants…", Mock·E2E 규칙 저장(행 지정 결정은 규칙 아님) |
| 행 결정 `{row, action, target_match_id}`, overwrite는 실제 충돌 ID | `TacticalExcelRowDecision`(overwrite ⇔ recordId, 나머지 null, 같은 행 두 번 거부) | 음성 3종, Mock "conflicts need explicit decisions…"(충돌 아닌 대상 = `invalid_payload`) |
| 미리보기 strict DTO 16키 · 행 7키 · raw cell 6키 · 행 match = FB-6 입력 DTO | `TacticalExcelPreview`·`TacticalExcelPreviewRow`(`match` = `TacticalMatchInputV2.fromWire`)·`TacticalExcelRawCell` | fixture 왕복(`toWire` = 원 payload), 음성 29종(+ commit 결과 7종) |
| 그룹 8키 · 제안 3변형 모두 `requires_confirmation` true · 일반 Map 없음 | `TacticalExcelStringGroup`(places = record), sealed `TacticalExcelSuggestion`, 변형 섞임 거부 | "success payloads…"(확인 false·점수 1.5·섞인 변형), "typed variants…" |
| summary 7, 버튼 분모 = eligible_rows(고정 41/46 없음) | `TacticalExcelSummary` + 주석 | fixture 왕복, Mock·E2E 수치 |
| 성공 7키, `rules_saved` = 내용 변경, 공개 v2 상태 DTO 그대로 | `TacticalExcelCommitResult`, 상태 DTO 변경 0 | E2E(규칙 같으면 false·revision 그대로, 비공개 규칙·receipt가 든 v2 파일을 strict 상태 DTO로 읽음) |
| 오류 `import_interpretation_changed` 추가, 기존 코드 재사용 | allowlist +2(아래) | "FB-7 and reused tactical codes…", E2E 실제 수신 |
| 원본 바이트·해석 맥락이 commit을 묶음, 정확한 재요청은 원본 재독·revision 검사 전 원 응답, 원자 batch, 자동 v1 이관 없음 | Process는 그대로 전달. Mock 순서 같음 | E2E(원본 삭제 뒤·재시작 뒤 원 응답, `import_source_changed`·`import_interpretation_changed`, v1 프로필 `legacy_migration_required`·revision 0) |
| 프론트 후속: DTO·validator·위임·Mock·guarded 실제 E2E(XLSX/CSV 원본 보존, resolution 변경, 원본 없는 재요청, 중복, 규칙, 옛 프로필 read-only) | CSV 전부 + 중복은 replay(재가져오기 0)까지. XLSX·같은 파일 행끼리 중복은 미검증(아래) | E2E |

### allowlist 확인

- 추가 2: `import_interpretation_changed`(handoff 명시 신규), `import_source_unreadable` — handoff는 "기존 재사용"이라 했지만 Dart `_methodErrorCodes['tactical']`에 없었다(fb6-dart 8개 목록 밖). 근거: `backend/core/tactical_excel_store.py:41`(`RepositoryError('import_source_unreadable', …, details={'reason': …})`), E2E에서 실제 수신(reason `source_unavailable`). 발견 3.
- 이미 있던 재사용 코드 확인(추가 0): `import_source_changed`·`import_review_required`·`legacy_migration_required`·`opponent_alias_required`·`link_conflict`·`lineage_conflict`·`invalid_payload`·`revision_conflict`·`idempotency_conflict`·`persistence_failed`·`profile_not_found`·`repository_busy`·`unknown_method`.
- 단위: 위 14코드 모두 `tactical.v2.excel.commit` 응답에서 `BackendRemoteException`(연결 유지), `details.reason` 보존, 집합 밖 코드는 `BackendProtocolException`.
- 실제 백엔드에서 받은 것: `import_review_required`·`import_interpretation_changed`·`idempotency_conflict`·`import_source_unreadable`·`import_source_changed`·`legacy_migration_required`.

### process E2E 내용

- 임시 저장소 `ba_planner_fb7_rpc_*`(fb6과 같은 inline `-c` 가드, prefix만 다름), 원본 CSV는 별도 임시 폴더 `ba_planner_fb7_src_*`, 둘 다 끝에 지움. 실제 사용자 프로필·게임·공용 저장소 접근 0.
- 프로필 + 보유 학생 6. UTF-8 BOM CSV(영문 머리글 19 + 날짜 행 + 확인 필요 행(`공격`·`승(3트)`·빈 시도·오타 학생 `shirok`) + 빈 행).
- 매핑 없는 미리보기 = 후보 1(19열, 모호 0)·`mapping_confirmation_required`·행 0 → 후보를 확인한 매핑으로 미리보기: 행 `unresolved, unresolved, empty`, 그룹 상대(2칸, raw_key `{"type":"str","value":"라이벌"}`)·학생(`student_unknown`)·시도·결과(제안 win/3) → 미해결 commit `import_review_required`.
- resolution 4(새 상대 `rival-one`, 학생 `shiroko`, 3행만 결과·시도) → 그룹 0, eligible 2(날짜 행 `date` `2026-10-14T00:00:00+09:00` 시도 2, 시각 행 `instant` UTC 12:10 시도 3) → 옛 해석 지문 commit `import_interpretation_changed` → commit = revision 1·가져옴 2·규칙 저장 true.
- 원본 바이트 그대로. 같은 요청 = 원 응답, 원본 삭제 뒤도 원 응답, 같은 key 다른 내용 `idempotency_conflict`, 미리보기 `import_source_unreadable`(reason `source_unavailable`).
- v2 상태: 기록 2(`csv_import`, source_record_id = 행 ID, 시도 [2, 3], 메모 그대로), 상대 `rival-one`, 가져오기 묶음 1(원본 지문).
- 같은 바이트를 다시 두면 두 행 `replay`(대상 = 가져온 기록), eligible 0, rules revision 1, 저장 매핑 = 매핑 → commit = revision 1 그대로·건너뜀 2·규칙 저장 false. 원본을 바꾸면 `import_source_changed`, on_conflict만 바꾸면 `import_interpretation_changed`(쓰기 0).
- v1 기록이 있는 두 번째 프로필: 미리보기 `legacy_migration_required` true·이슈(source revision 1), commit `legacy_migration_required`, v2 revision 0.
- 재시작 뒤 같은 상태, 원본 없이 원 commit 재전송 = 원 응답, 기록 2 그대로. 백엔드 프로세스 2개 모두 exit 0.

### Mock 차이(`mock_tactical_v2_excel.dart` 머리 주석과 같다)

- 같은 것: 매핑 null = 후보 + `mapping_confirmation_required`(머리글 이름표 · 필수 3개 이상 기준 같음), typed raw_key(`str`·모자란 칸 `NoneType`), resolution 우선순위(행 → 전역 → 저장 규칙), 그룹(필드·원값·코드), 날짜·결과·양수 시도·`승(n트)` 제안, 쓰이지 않은 resolution·행 결정 `invalid_payload`, receipt·source_record_id `replay`, 행 결정 3종·on_conflict, commit 순서(캐시 → revision → 원본 재독 → 지문 → 해석 지문 → v1 → 검토), revision 1회(변화 없으면 그대로), 원본 삭제 뒤 재요청 원 응답, 규칙 = 행·skip 제외 전역 resolution + 매핑(내용이 같으면 저장 안 함).
- 다른 것: 파일을 읽지 않는다(`debugSetTacticalExcelSource`로 넣은 행). CSV만 — `.csv`가 아니면 `format_unsupported`, 없는 경로 `source_unavailable`, 시트 null·`CSV`만. 수식·인코딩·구분자 해석 없음. 지문은 FNV 결정값(sha256 아님), 해석 지문 맥락에 카탈로그 없음. 학생 카탈로그·보유·역할 검사 없음 — 소문자 ASCII ID면 받고 그 밖은 `student_unknown`(학생 제안 없음). 충돌은 의미 키가 정확히 같을 때만(같은 날·빈칸 coarse 충돌 없음, coarse면 자동 덮어쓰기 안 함은 같음). instant는 Dart UTC 표기(`…Z`, fb6 Mock과 같음). 가져오기 묶음(`import_batches`)을 남기지 않는다.
- 기존 Mock 동작 변화 0: `_no_change`는 FB-7 apply만 돌려준다. `_applyMatch` 옮김은 수동 기록 규칙 그대로(tactical_fb6_dart Mock 테스트 +14, tactical_page·jokbo_panel·design_review seed 테스트 통과).

### golden 변화 0 근거

- `lib/ui/**` 수정 0. Mock 변화는 새 FB-7 메서드를 부를 때만 생기고, `_applyMatch` 옮김은 같은 결과다. golden 테스트·harness에 `TacticalExcel`·`excel` 0건(grep). golden 테스트는 돌리지 않았다.
- CF gate 예상: analyze 0. 새 두 테스트 파일 모두 `ProcessAppService` 문자열을 포함해 process 묶음 → process **+13**(tactical_fb7_dart 12 + E2E 1), 일반 변화 0(단 Lane A FE9-e가 끝나기 전이면 `tactical_page_test` 1건 RED — Lane A 몫), golden 변화 0.

### 미검증(미실행)

- 전체 `fe_gate.ps1`·golden 비교·`codealmanac validate`·저장소 전체 `git diff --check`: **미실행**(CF 몫).
- Python 전체 테스트: **미실행**(XB 몫, `810a15f2` 커밋 메시지의 main1345 OK만 읽음).
- XLSX 실제 백엔드 E2E: **미실행** — 계약 fixture에 XLSX 바이트가 없다(프롬프트 조건). 수식 캐시·네이티브 시각 칸·여러 시트·탭 구분자도 실제 백엔드에서 보지 않았다.
- 실제 백엔드의 같은 파일 행끼리 충돌·coarse(날짜·빈칸) 충돌·덮어쓰기 commit·`opponent_alias_required`·`saved_opponent_identity_missing`: **미실행**(Mock·단위만).
- 위 목록 밖 Flutter 테스트(Lane A 통계·계획, 스캐너·스캔 화면, 나머지 process E2E): **미실행**.
- 화면 연결(FE9-f)·Windows release 빌드: **미실행**.

### 발견 사항

1. **schema와 backend 길이 단위 차이**: `excelResolution.raw` `maxLength` 8192는 JSON Schema상 글자 수인데 backend `validate_resolutions`는 UTF-8 바이트 8192다. Dart는 바이트(더 엄격) — 한글 2731자 raw는 schema 통과·backend 거부. XB 요청 후보(schema 주석 또는 단위 통일).
2. **schema가 표현하지 않는 backend 거부 3개**: 매핑 열 중복, 같은 (행, 필드, 원값) resolution 중복, 같은 행 결정 중복. Dart validator는 backend처럼 거부한다(보내기 전 `FormatException`). 응답 매핑(`saved_mapping`·`column_mapping`)도 열 중복을 거부하고 후보(`mapping_candidates`)는 schema대로 검사하지 않는다. XB 확인 후보.
3. **`import_source_unreadable` 누락**: handoff는 "기존 코드 재사용"으로 적었지만 Dart allowlist에 없었다(추가함). fb6-dart allowlist 8은 FB-6 코드만이었다.
4. **변화 없는 commit도 key를 쓴다**: 가져올 행·바뀐 규칙이 없으면 revision은 그대로지만 idempotency 캐시에는 남는다(backend `_no_change`). FE9-f는 다음 commit에 새 key를 써야 한다(Mock 같음).
5. **미리보기 응답에 구분자·on_conflict 메아리가 없다**: 해석 지문이 묶으므로 FE9-f는 미리보기에 쓴 선택(`TacticalExcelImportChoices`)을 그대로 들고 commit해야 한다(바꾸면 `import_interpretation_changed`).
6. **행 이슈 `field`는 의미 필드 밖 값 `deck`도 온다**(덱 검사 실패, backend interpreter 431줄). schema가 자유 문자열이라 DTO도 `String?`로 두었다 — FE9-f 표시 몫.
7. **Lane A 동시 편집 영향**: 작업 중 `app_shell.dart:476` 컴파일 오류(이후 해소)와 `tactical_page_test` "sub views analysis and slots are disabled" 실패(FE9-e가 분석 하위 화면을 켬, 미커밋)는 이 slice와 무관하다. CF gate 때 Lane A 상태를 따른다.
8. **fe_gate 분류**: `tactical_fb7_dart_test.dart`는 가짜 프로세스로 `ProcessAppService`를 만들어 process(직렬) 묶음에 들어간다(12건, 약 2초). fb6 선례와 같이 두었다.
9. **E2E 진입점**: fb6과 같이 inline `-c`. XB 공용 FB-7 진입점이 생기면 옮긴다(XB 판단).
10. 워커 재량 FD: FD-131 — 권장안(Python 파서·.xlsx+.csv·시트 선택·분모 = 가져올 건수·규칙 프로필별 저장)이 backend에 이미 들어가 있어 Dart는 그대로 연결만 했다. "스캔 파일 가져오기" 숨김은 FE9-f 화면 몫. FD-128은 확정 (a).

### 사본 · commit.json

- 착수 사본: `debug/frontend_fb7dart/pre/<경로>`(고친 기존 5파일 + 이 문서). WIP 있는 파일이 없어 `post/`·`post_dir` 없음.
- `debug/frontend_fb7dart/commit.json`: slice `fb7dart`, modified 5, added 3, `whole = [almanac/workflows/frontend-redesign-status-lane-b.md]`, `status=false`. message(ASCII) 근거: XB `810a15f2`, `dart-handoff-final.md`, FD-128·FD-131.
- 인계: `debug/frontend_fb7dart/output.md`. 로그 `debug/frontend_fb7dart/logs/`.

### 다음 행동

- fb7-dart 코드는 끝났다. Lane B는 여기서 멈춘다.
- CF: Lane A(FE9-e)가 멈춘 뒤 gate 1회(예상: analyze 0, process +13, 일반 변화 0, golden 변화 0) → `fe_commit.ps1 -Slice fb7dart`(공유 3파일은 WIP 없음, 삽입만).
- 발견 1·2는 XB 요청 후보, 4·5·6은 FE9-f 입력, 7은 Lane A, 3·8·9는 CF 판단.

## fb6b-dart 착수 기록 — BLOCKED (2026-10-16 15:24)

- 상태: **BLOCKED(시작 조건 미충족)**. 코드·테스트 수정 0, pre/ 사본 0, flutter 명령 실행 0.
- 시작 SHA: `77e3e6e5`(브랜치 `scanner-consolidation`). 이 파일 끝에 다른 "fb6b-dart 착수 기록" 없음을 확인했다.
- 시작 조건: XB가 FB-6b **source11**을 메인에 반영하고 `backend-orchestrator-log.md`에 반영 표(경로·bytes·SHA)를 게시했어야 한다(CF 요청 2026-10-16 08:45).
  - `backend-orchestrator-log.md`(2799줄, mtime 08:39)의 마지막 항목은 CF 08:45 요청 자체다. 그 뒤 XB의 source11 메인 반영 항목·반영 표 **없음**.
  - 대신 XB 격리 manifest `debug/xb_fb6b_isolated_20261015/artifacts/final-source11-manifest.json`(11경로)을 메인 파일과 대조했다: **일치 0/11**.

| 경로 | source11 bytes | 메인 bytes | 결과 |
| --- | ---: | ---: | --- |
| `backend/core/tactical_fb6.py` | 6787 | 6798 | 다름 |
| `backend/core/tactical_fb6_store.py` | 21502 | 21222 | 다름 |
| `backend/core/tactical_stats_v2.py` | 18197 | 17980 | 다름 |
| `backend/core/tactical_share_v1.py` | 30956 | 30760 | 다름 |
| `contracts/tactical-protocol-v2.schema.json` | 132069 | 129508 | 다름 |
| `contracts/README.md` | 97788 | 96717 | 다름 |
| `backend/tests/test_tactical_fb6_primitives.py` | 6217 | 6166 | 다름 |
| `backend/tests/test_tactical_fb6b.py` | 12178 | — | 메인에 없음 |
| `contracts/fixtures/tactical_fb6b_nulls_v2.json` | 56078 | — | 메인에 없음 |
| `contracts/fixtures/tactical_fb6_writes_v2.json` | 38146 | 39342 | 다름 |
| `backend/tests/test_tactical_excel_contract.py` | 4446 | 4446 | 다름(SHA) |

- 메인 `contracts/README.md`·`tactical-protocol-v2.schema.json`의 미커밋 변경은 source8(typed-read·FB-10) 쪽으로 보이며 source11 내용이 아니다(새 fixture 부재로 확인).
- 판단: 표가 없고 대조도 전부 다르므로 프롬프트 규칙대로 코드를 고치지 않고 멈춘다. 격리본(`candidate/`)을 기준으로 먼저 구현하는 것은 "메인 기준" 규칙과 맞지 않아 하지 않았다.
- 고칠 예정이던 파일(WIP 확인만, 모두 미커밋 변경 없음): `frontend/lib/services/tactical_v2_service.dart`, `mock_tactical_v2_writes.dart`, `mock_tactical_v2_reads.dart`, `frontend/lib/tactical/tactical_records_controller.dart`, `frontend/test/tactical_fb6_dart_test.dart`·`tactical_fb6_process_e2e_test.dart`·`tactical_records_controller_test.dart`(+ 새 테스트 파일 예정).

### 다음 행동

- XB: source11 메인 반영 → 표준 Python 전체 → 반영 표(경로·bytes·SHA, 예상 RED Dart 테스트 목록) 게시.
- CF: 표 게시 뒤 같은 프롬프트로 fb6b-dart를 새 세션에 다시 배정한다(이 세션 기록은 BLOCKED로 남김 — 재배정 세션은 이 BLOCKED 기록을 "다른 착수 기록"으로 보지 않도록 CF가 프롬프트에 적어 주면 좋다).

## fb6b-dart 착수 기록 (2026-10-16)

- 상태: **진행 중**. 범위: FD-176의 Dart 데이터 계층(strict request validator · read DTO · Mock 쓰기/읽기 · 컨트롤러 테스트 · fixture 대조 · process E2E 1) + 기존 화면의 null 안전 최소 호환(XB 15:40 정적 영향 목록 경로만). 새 화면 기능(S3 시도 '모름' 저장 · 상대 없는 방어 저장 UI)은 다음 slice.
- 착수 전 확인: 이 문서 끝의 "fb6b-dart 착수 기록 — BLOCKED (2026-10-16 15:24)"는 이전 세션(코드 0) 기록이라 다른 착수 기록으로 보지 않는다(CF 프롬프트). 그 밖의 "fb6b-dart 착수 기록" 없음.
- 시작 SHA(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`): `a5e179faaf6f9467f1ec8469f0b6d47c383e3420`.
- XB source11 반영 표(backend-orchestrator-log 2026-10-16 15:51) 대조 — 메인 작업 트리 bytes/SHA256 **11/11 일치**:

| 경로 | 표 bytes | 메인 bytes | SHA256 일치 |
| --- | ---: | ---: | --- |
| `backend/core/tactical_fb6.py` | 6787 | 6787 | 예 |
| `backend/core/tactical_fb6_store.py` | 21502 | 21502 | 예 |
| `backend/core/tactical_stats_v2.py` | 18197 | 18197 | 예 |
| `backend/core/tactical_share_v1.py` | 30956 | 30956 | 예 |
| `contracts/tactical-protocol-v2.schema.json` | 132069 | 132069 | 예 |
| `contracts/README.md` | 97788 | 97788 | 예 |
| `backend/tests/test_tactical_fb6_primitives.py` | 6217 | 6217 | 예 |
| `backend/tests/test_tactical_fb6b.py` | 12178 | 12178 | 예 |
| `contracts/fixtures/tactical_fb6b_nulls_v2.json` | 56078 | 56078 | 예 |
| `contracts/fixtures/tactical_fb6_writes_v2.json` | 38146 | 38146 | 예 |
| `backend/tests/test_tactical_excel_contract.py` | 4446 | 4446 | 예 |

- 막힘: 대장 "slice별 막힘 요약" 현재 `열림` 0건. FD-176 확정(2026-10-15, 사용자 선택: (A) null 허용 · (B) 방어 한정 null 쌍), FD-128 확정, FD-132 워커 재량(기존 "내 방어덱" 표기 그대로).
- 고칠 기존 파일(착수 사본 `debug/frontend_fb6bdart/pre/<v7 기준 경로>`, 모두 cmp 일치)과 WIP(`git status --short`), 줄바꿈(작업 트리 바이트 셈):
  - `frontend/lib/services/tactical_v2_service.dart`: WIP 없음. LF.
  - `frontend/lib/services/mock_tactical_v2_writes.dart`: WIP 없음. LF.
  - `frontend/lib/services/mock_tactical_v2_reads.dart`: WIP 없음. LF.
  - `frontend/lib/ui/tactical/tactical_analysis_view.dart`: WIP 없음(XB addendum bytes/SHA 25919 `fae4b076…`와 같음). LF.
  - `frontend/lib/ui/tactical/tactical_records_view.dart`: WIP 없음(addendum 17446 `f4708a46…`와 같음). LF.
  - `frontend/test/tactical_fb6_dart_test.dart`: WIP 없음. LF.
  - 이 문서: WIP 있음(위 BLOCKED 기록, 이 문서는 commit.json `whole`). LF.
- 확인만 하고 고치지 않을 예정: `frontend/lib/ui/pages/tactical_page.dart`(**FE9-f WIP 있음**, CRLF, addendum 736행은 지금 783행 — 초안의 `opponentIdentityId`는 이미 `String?`라 타입 영향 없음, 970~973행 분석 상대 선택은 공격 기록만 받음), `tactical_records_controller.dart`(null 필드를 그대로 전달 — 새 거부 코드 없음: 백엔드 거부는 기존 `invalid_payload`). 고쳐야 하면 그때 pre(FE9-f 포함)·post·post_dir를 남긴다.
- 새 파일(예정): `frontend/test/tactical_fb6b_dart_test.dart`(FD-176 fixture 13 · DTO · Mock · 컨트롤러 · 화면 집계), `frontend/test/tactical_fb6b_process_e2e_test.dart`(실제 백엔드, 임시 `BA_PLANNER_STORAGE_ROOT`).
- 고치지 않음: backend/**·contracts/**, FE9-f 줄, 스캐너 시각부 5파일, `scanner_service.dart`, 택틱 소유 파일, golden harness·golden 테스트, frontend/tool/**, app_shell.dart.

## fb6b-dart 종료 기록 (2026-10-16, 코드 작성 완료 · CF gate 미실행)

FD-176의 Dart 데이터 계층과 기존 화면의 null 안전 최소 호환을 끝냈다. 시도 횟수 null(모름) 요청·읽기, 방어 기록 한정 상대 identity·이름 null 쌍, Mock 쓰기·읽기 의미, 계약 fixture 대조, 실제 백엔드 process E2E. 새 화면 기능(S3 '모름' 저장 · 상대 없는 방어 저장 UI)은 하지 않았다. HEAD는 착수 때와 같다(`a5e179fa`), git 쓰기 0회.

### 실행한 명령과 결과(이 PC, `frontend` 폴더)

- `flutter analyze`: 첫 실행(서비스 DTO를 nullable로 바꾼 직후) **error 4** — `tactical_analysis_view.dart` 174·443·682, `tactical_records_view.dart` 141(XB addendum이 짚은 곳과 같음). 고친 뒤 **No issues found(0)**, 포맷 뒤 마지막 실행도 0(`logs/analyze_final.log`). 실행 시점의 FE9-f 미커밋 파일도 함께 분석됐고 이슈 0.
- `flutter test test/tactical_fb6_dart_test.dart`: 갱신 뒤 **+14 −0**(XB 15:29 예상 RED "shared FB-6 fixture has matching Dart validation results"의 `unknown_manual_attempt`를 validator 수정으로 맞춤. 수정 전 RED는 이 세션에서 돌려 보지 않았다 — null attempt를 거부하던 validator라 코드상 RED였다).
- 새 `flutter test test/tactical_fb6b_dart_test.dart`: ① **+8 −1**(테스트 쪽: 분석 대상 기록은 공개 칸이 `visible_lobby`여야 하는데 테스트 덱이 `manual`) → ② **+9 −0**.
- 새 `flutter test --concurrency=1 test/tactical_fb6b_process_e2e_test.dart`: ① **−1**(테스트 쪽: 상대 덱 학생 역할이 카탈로그와 다름 — 백엔드 `invalid_payload` "slot student combat class does not match role") → ② **+1**(fb6 E2E와 같은 검증된 편성을 양쪽에 씀).
- 바뀐 동작에 걸리는 기존 테스트(grep: `TacticalMatchV2`·`TacticalMatchInputV2`·`tactical_v2_service`·`mock_tactical_v2`·`TacticalRecordsController`·`tactical_analysis_view`·`tactical_records_view`·`tactical_page`·`MockDesignReviewScenario`·`queryTacticalStatistics`·`upsertTacticalMatchV2` + 전술 v1·Mock 공용 몇 개):
  - 일반(17파일 한 번에): **+172 −0** — design_review_tactical_seed, mock_design_review_scenario, tactical_analysis, tactical_excel_import(FE9-f), tactical_fb6b_dart, tactical_fe9b1_read, tactical_jokbo_panel, tactical_page_revision, tactical_page, tactical_records_controller, tactical_share_v1_contract, tactical_v2_service, tactical_service, tactical_lobby_scanner_service, profile_delete_fb2d, home_app_shell, widget_test(`logs/general_1.log`).
  - process(`--concurrency=1`, 파일마다 따로): tactical_fb6_dart **+14**, tactical_fb7_dart **+12**, planning_protocol_client **+24**, tactical_fb6_process_e2e **+1**, tactical_fb6b_process_e2e **+1**, tactical_fb7_process_e2e **+1**, tactical_v2_process_e2e **+1**, tactical_process_e2e **+1**, profile_delete_fb2d_process_e2e **+1**. 모두 −0(`logs/proc_*.log`).
- `dart format`: 고친·새 파일 8개를 하나씩. pre 6개는 이미 포맷 상태(`--set-exit-if-changed` 0), 마지막 포맷은 8개 모두 변경 0.
- `git diff --check`(고친 6파일): exit 0. 고친·새 8파일 모두 LF(CR 0)·줄 끝 공백 0·끝 개행 하나. `pubspec.yaml`·`pubspec.lock` 변경 0.
- 3-way 병합 모의(스크래치, LF로 맞춘 뒤 `git merge-file`, base = pre · ours = HEAD · theirs = post): 고친 6파일 모두 HEAD = pre(WIP 없음), 충돌 0, 병합 결과 = 끝 파일.
- FE9-f 고정본 `debug/frontend_fe9f/post/`의 13파일을 작업 트리와 cmp: **13/13 같음**(FE9-f 줄 수정 0, `tactical_page.dart` SHA `46f89a5e…` 그대로).
- 잠금 충돌 0(재시도 없음). 로그는 실패 줄·요약 줄만 확인했다.

### source11 대조

- 착수(위 착수 기록 표)와 종료 두 번 XB 15:51 반영 표 11경로 bytes/SHA256 **11/11 일치**. 이 slice는 backend/**·contracts/**를 읽기만 했다.
- handoff(`dart-handoff.md`)·addendum과 메인 schema·코드 차이: 없음. 메인 schema에서 nullable이 된 것은 `$defs/match`·`$defs/fb6MatchInput`의 상대 쌍(allOf: null이면 kind = defense, 다른 쪽도 null)과 `attempt_count`(null | 정수 ≥ 1)뿐이다. 통계 `opponents` 행·스냅샷·로비·추천 필터의 상대 ID는 여전히 non-null record ID라 그 DTO는 넓히지 않았다(handoff 3행과 같음). 백엔드 거부 코드는 기존 `invalid_payload`뿐이라 allowlist·컨트롤러 문구 표 변경 0.

### 고친 파일

- `frontend/lib/services/tactical_v2_service.dart`(WIP 없음, LF): 새 `_validOpponentPairV2`(둘 다 있거나 방어에 한해 둘 다 null, 한쪽 null·빈 문자열·공격 null 거부)를 read DTO `TacticalMatchV2.fromWire`와 요청 `_validFb6MatchInputV2`가 같이 쓴다. 요청 `attempt_count`는 키 required(exact) + null 또는 int ≥ 1(0·bool·음수·실수·문자열 거부). `TacticalMatchV2`·`TacticalMatchInputV2`의 `opponentIdentityId`·`opponentDisplayName`은 `String?`, 입력 `attemptCount`는 `required int?`. `fromWire`(FB-7 행 포함)는 `as String?`·`as int?`. `fromRecord`는 모르는 시도를 null 그대로 옮긴다(예외 제거). 정밀도 추측 금지는 그대로.
- `frontend/lib/services/mock_tactical_v2_writes.dart`(WIP 없음, LF): `_applyMatch`가 상대 identity null이면 상대 identity·별칭을 만들지 않는다(backend `apply_match` 158행과 같은 조건). 머리 주석 3줄.
- `frontend/lib/services/mock_tactical_v2_reads.dart`(WIP 없음, LF): 통계 상대 ID 집합에서 null 제외(상대별 행·`opponent_count`·`distinct_opponent_count`), 중복 의심 지문은 null 상대를 기록 ID별 키로(backend `("unknown-match", match_id)`). 머리 주석 3줄.
- `frontend/lib/ui/tactical/tactical_analysis_view.dart`(WIP 없음, LF): `_byOpponent`가 null ID를 묶지 않음(171·174), `defenseUsers`가 null을 한 명으로 세지 않음(417~), 이름은 `?? '—'`(443·682 — null ID는 묶음에서 빠지므로 실제로는 오지 않는다). 전체 기록 수(`sampleCount`·`records`)에는 남는다.
- `frontend/lib/ui/tactical/tactical_records_view.dart`(WIP 없음, LF): `fromMatch`가 null 이름을 빈 문자열로(141) → 기존 FD-132 "내 방어덱" 표기·초안 identity null. 180행 `opponentName` 필드 타입(String)은 그대로.
- `frontend/test/tactical_fb6_dart_test.dart`(WIP 없음, LF): `fromRecord` 기대를 FD-176으로 갱신(모르는 시도 = null 그대로, 정밀도 추측 금지는 유지). 그 밖 0.
- 새 `frontend/test/tactical_fb6b_dart_test.dart`(9): FD-176 fixture 13 대조(유효 3은 `fromWire → toWire` = 원 입력), writes fixture `unknown_manual_attempt` 유효, 입력·read DTO 음성, Mock 쓰기·이관 기록 null 편집·통계, 컨트롤러, 기록 목록 행·분석 집계.
- 새 `frontend/test/tactical_fb6b_process_e2e_test.dart`(1): 아래.
- 확인만 하고 고치지 않음: `lib/ui/pages/tactical_page.dart`(FE9-f WIP — addendum 736행 = 지금 783행: `current.opponentIdentityId`는 초안 필드라 이미 `String?`, 이름도 ID도 없으면 추천 질의를 보내지 않는다. 970~973행 분석 상대 선택은 `tacticalAnalysisMatches`가 공격 기록만 넘겨 null이 오지 않는다), `tactical_records_controller.dart`(입력 DTO를 그대로 보내므로 null도 그대로 — 코드 변경 0), `tactical_workspace.dart`·`design_review/tactical_records_data.dart`(FE9-f WIP, 컴파일 영향 0), `process_app_service.dart`·`mock_app_service.dart`·`planning_protocol_client.dart`(새 메서드·키·코드 0).

### handoff 목록 행별 검수(`dart-handoff.md` + `dart-ui-static-addendum.json`)

| 행 | 처리 | 근거 테스트 |
|---|---|---|
| `_validFb6MatchInputV2`: 13키 required, attempt null 또는 양의 int(누락·0·bool·음수 거부), 방어만 상대 null 쌍, 공격·한쪽 null·빈 문자열 거부 | 위 "고친 파일". 실수 1.5·문자열 "1"도 거부(fixture `float`·`text`) | fb6b "FD-176 fixture: 13 cases…", "input DTO…" |
| `TacticalMatchInputV2`/fromRecord/toWire: `required int?`·`required String?` 쌍, fromRecord 강제 입력 오류 제거, null을 1/0으로 대체 안 함, "지정 안 함 vs 명시적 null" 판단 | sentinel 없이: `fromRecord(attemptCount:)`는 주면 바꾸고 안 주면 기록 값(null 포함) 그대로, 아는 값을 '모름'으로 바꾸려면 생성자에 `attemptCount: null`(문서 주석). 키는 늘 보낸다 | fb6 "input DTOs…", fb6b "migrated null attempt can be edited…" |
| read DTO: attempt nullable(기존), legacy 키 없음과 FD-176 required write 구분, 상대 쌍 `String?`, opponent/snapshot/prediction DTO는 넓히지 않음 | read는 `attempt_count` optional 그대로(키 없음 = 구 v2), 쓰기 입력은 required. 상대 쌍만 nullable | fb6 "read DTOs accept only…", fb6b "read DTO…" |
| Mock writes: null attempt 보존, 익명 방어에 상대·별칭·가짜 identity 0, revision·idempotency·원자성 보존, legacy null 편집 | `_applyMatch` 조건 하나 | fb6b Mock 두 테스트, fb6 Mock 6건 그대로 |
| Mock reads stats: 전체·방어 집계 포함, 상대별 행·상대 수·이름 재사용 제외, unknown을 공통 상대로 만들지 않음, 추이·추천 범위 유지 | 상대 ID 집합 null 제외, 중복 지문 기록별. 추이(Mock 빈 구조)·추천(대상 상대 필수) 변경 0 | fb6b "statistics keep anonymous rows…" |
| 테스트: FD-176 fixture 13, required-vs-null, 익명 방어, 재시도, legacy edit, Mock parity, `unknown_manual_attempt` 유효, 기존 positive fixture 동일 | fixture 13 + writes fixture 11 일치 | fb6 "shared FB-6 fixture…"(+14), fb6b 9, E2E 1 |
| 컴파일 점검 대상(controller·records_view·workspace·page·design_review data·테스트) | records_view만 수정, 나머지 컴파일 0 · 동작 확인 | analyze 0, 일반 +172 |
| addendum `tactical_analysis_view.dart` 171·174·417·443·682 | 수정(위) | fb6b "analysis aggregates exclude unknown opponents…" |
| addendum `tactical_records_view.dart` 141·180 | 141 수정, 180은 String 유지(빈 이름 → "내 방어덱") | fb6b "controller saves null attempt…"(행 표기) |
| addendum `tactical_page.dart` 736 | 확인만(지금 783, 가짜 ID 없음) | tactical_page·page_revision(일반 묶음) |

### process E2E 내용(`tactical_fb6b_process_e2e_test.dart`)

- 임시 저장소 `Directory.systemTemp/ba_planner_fb6_rpc_*`(실제 경로로 풀어서 `BA_PLANNER_STORAGE_ROOT`, 끝에 지움), fb6 E2E와 같은 inline guarded 진입점. 실제 게임·사용자 프로필·공용 저장소 접근 0.
- 프로필 + 보유 학생 6. 시도 모르는 공격 기록(상대 opponent-one) → revision 1, 시도 null, 자동 족보 1. 상대 없는 방어 기록(시도 null) → revision 2, 상대 쌍 null, 족보 없음. 같은 key 재요청 = 원 응답(revision 2 · 같은 `created_at`). 같은 내용 두 번째 익명 방어(다른 ID) → revision 3.
- 읽기: 기록 3, 상대 identity는 opponent-one 하나(별칭 `['Rival']`), 익명 행 2(kind defense · 이름 null · 시도 null), 익명 행 스냅샷 0.
- 통계: match 3 · attack 1 · defense 2 · `opponent_count` 1 · 상대 행 1(opponent-one, match 1) · `distinct_opponent_count` 1 · `match_kind_counts` {attack 1, defense 2} · `suspected_duplicate_count` 0(같은 내용 익명 2건이 중복으로 묶이지 않음). 추이 strict 읽기 성공(신선도 0).
- 익명 방어를 시도 2로 고침 → revision 4(상대는 여전히 null). 재시작 뒤 revision 4, 원 익명 요청 재전송 = 원 응답(revision 2 · 시도 null)이고 저장값(시도 2)을 되돌리지 않음. 상대 identity 1 그대로. 백엔드 프로세스 2개 exit 0.

### Mock 차이(파일 머리 주석과 같다)

- 백엔드와 같음: null 시도 저장, 익명 방어에 상대 identity·별칭 없음, 익명 행은 상대별 통계·상대 수 제외·전체/방어 수 포함, 중복 지문에서 익명 행은 기록마다 다른 키.
- 남은 차이(기존과 같음): Mock 추이는 늘 빈 구조, 공유(share) Mock 없음(백엔드는 상대 없는 기록 공유를 `not_shareable` — 방어 기록은 원래 공유 대상이 아니다), Mock은 카탈로그·역할·보유 검사 없음(E2E 첫 실패 원인이 바로 이 차이), 지문 키 표기(문자열 vs Python 튜플)는 의미만 같다.
- 기존 Mock 동작 변화 0: 상대가 있는 기록은 같은 경로(조건 `input['opponent_identity_id'] != null`은 상대 있는 기록에 늘 참), 통계도 null이 없으면 같은 집합·같은 키. fb6 Mock 6건·fe9b1 12건·controller 14건 그대로 통과.

### 다음 화면 slice에 넘길 것(S3)

1. 시도 '모름'으로 저장: 지금 `_saveBlocker`가 `_draft.attemptCount == null`이면 `tacticalNeedAttemptHint`로 막고, `TacticalRecordDraft.toInput`도 시도 null이면 `StateError`. FD-176에 맞춰 '모름' 선택 UI와 저장 허용이 필요하다(이관 기록 고치기 포함 — 지금은 이관 기록을 고치려면 시도를 정해야 한다).
2. 상대 없는 방어 저장: 지금 상대 이름이 비면 `tacticalNeedOpponentHint`로 막고, `toInput(identityId: String)`이 non-null identity를 요구한다. 방어 기록에 한해 이름·identity를 둘 다 비워 저장하는 UI(공격은 지금처럼 필수)가 필요하다. 익명 방어 기록을 열면 상대 칸이 비어 있고 지금은 저장할 수 없다(읽기·목록 표시만 됨).
3. 목록 표기: 익명 방어 = "내 방어덱"(FD-132), 시도 모름 = '—'·"시도 횟수 모름" — 이 slice에서 확인한 현재 표기를 유지하면 된다.
4. FE9-f `tacticalExcelResultText`(`tactical_excel_import_view.dart` 502)는 `${match.attemptCount}회`라 null이면 "null회"가 된다. 지금 백엔드 엑셀은 빈 시도를 review-required로 막아 행 `match`에 null이 오지 않지만, 주석("시도 없으면 결과만")과 맞추려면 FE9-f 또는 다음 slice에서 null 분기가 필요하다(FE9-f 줄이라 고치지 않음).

### golden 변화 0 근거

- design-review seed(`tactical_records_data.dart`)의 v2 기록 4건은 모두 상대 identity·이름·시도가 있다(84~132행). golden 테스트(`fe9a_tactical_golden_test.dart`)도 상대 있는 기록만 쓴다. 바뀐 화면 코드는 null일 때만 다른 값을 낸다(`?? ''`·`?? '—'`·null ID 제외). golden 테스트·harness는 돌리지 않았고 고치지 않았다.
- CF gate 예상: analyze 0, 일반 **+9**(`tactical_fb6b_dart_test` — process 패턴 문자열 0), process **+1**(`tactical_fb6b_process_e2e_test`), 기존 수 변화 0(`tactical_fb6_dart_test` 14 그대로), golden 변화 0.

### 미검증 항목

- 전체 `fe_gate.ps1`·golden 비교·`codealmanac validate`·저장소 전체 `git diff --check`: **미실행**(CF 몫).
- Python 전체 테스트: **미실행**(XB 몫, XB 15:51 1384 OK 보고만 읽음).
- 위 목록 밖 Flutter 테스트(Lane A·스캐너·통계·계획, 나머지 process E2E): **미실행**.
- 실제 백엔드가 공격 null 쌍·한쪽 null·0/bool 시도를 거부하는지: Dart가 보내기 전에 막아서 이 slice E2E로는 **미실행**(XB Python `test_tactical_fb6b.py` 몫).
- 실제 백엔드 추천(`recommend`)·공유(`share`)에 익명 행이 섞였을 때: **미실행**(추천은 대상 상대가 필요해 익명 행이 쓰이지 않고, 공유는 방어 기록이 원래 대상 밖).
- 수정 전 `tactical_fb6_dart_test`의 RED: **미실행**(코드로만 판단).
- Windows release 빌드·사용자 시각 검수: **미실행**.

### 발견 사항

1. `fromRecord` API(handoff "CF 판단"): sentinel 없이 두었다 — 아는 시도를 '모름'으로 바꾸는 편집은 생성자로 만든다. S3 화면이 `fromRecord`를 쓰게 되면 다시 볼 것(지금 lib 호출처 0, 화면은 `TacticalRecordDraft.toInput`).
2. 위 "다음 화면 slice" 4(FE9-f 엑셀 결과 글자 null 분기) — FE9-f·CF 판단.
3. `tactical_page.dart` 970~973: 분석 대상이 공격 기록만이라 지금은 안전하지만, 나중에 방어 기록을 분석에 넣으면 `summary.matches.firstOrNull?.opponentIdentityId`가 null을 고를 수 있다(그때 추천 질의를 보내지 않을 뿐 가짜 ID는 없다).
4. 착수 기록 줄바꿈: 이 세션 첫 바이트 셈(Git Bash grep의 CR 셈)이 틀려 CRLF로 적을 뻔했다가 Python 바이트 셈으로 고쳐 LF로 적었다(파일은 처음부터 LF, 바뀐 것 없음). `tactical_page.dart`만 CRLF.
5. handoff·메인 schema·코드 차이 없음(XB 요청 후보 0). 워커 재량 FD: FD-132(기존 "내 방어덱" 표기를 익명 방어에 그대로).

### 사본 · commit.json

- 착수 사본: `debug/frontend_fb6bdart/pre/<경로>`(고친 기존 6파일 + 이 문서). 고친 코드 파일에 WIP가 없어 `post/`·`post_dir` 없음(이 문서는 `whole`).
- `debug/frontend_fb6bdart/commit.json`: slice `fb6bdart`, modified 6, added 2, `whole = [almanac/workflows/frontend-redesign-status-lane-b.md]`, `status=false`. message(ASCII) 근거: FD-176, XB source11 반영 표(backend 로그 15:51), `dart-handoff.md`·`dart-ui-static-addendum.json`.
- 인계: `debug/frontend_fb6bdart/output.md`. 로그 `debug/frontend_fb6bdart/logs/`.

### 다음 행동

- fb6b-dart 코드는 끝났다. Lane B는 여기서 멈춘다.
- CF: FE9-f와 같은 소스로 gate 1회(예상: analyze 0, 일반 +9, process +1, golden 변화 0, FE9-f 몫은 FE9-f 기록대로) → XB source11 exact11 커밋 → `fe_commit.ps1 -Slice fe9f`·`-Slice fb6bdart`(두 slice가 겹치는 파일 0 — FE9-f post 13파일과 이 slice 8파일은 서로 다르다).
- 다음 화면 slice(S3 '모름' 저장 · 상대 없는 방어 저장)는 위 "다음 화면 slice에 넘길 것" 1~3을 입력으로.

## FE9-b2 착수 기록 (2026-10-17)

- 상태: **진행 중**. 범위: FD-176을 기록 화면에서 쓸 수 있게 — S3 시도 '모름' 저장 · 방어 기록 상대 없이 저장(identity · 이름 null 쌍) · 목록 · S4 · 분석 · 엑셀 결과 글자의 null 표시 정리 · design-review seed 2행 추가.
- 착수 전 확인: 이 문서에 다른 "FE9-b2 착수 기록" 없음(grep 0건). 대장 "slice별 막힘 요약" 현재 `열림` 0건(FE9-b 행 FD-128 확정). FD-176 확정(2026-10-15, (A) null 허용 · (B) 방어 한정 null 쌍). FD-132 워커 재량 → 권장안("내 방어덱 · vs …", 상대 없으면 "내 방어덱").
- 시작 SHA(`git rev-parse HEAD`, 브랜치 `scanner-consolidation`): `9cf5f0a5766ce484111f9affecf7bd91b8955066`.
- 고칠(수 있는) 기존 파일 — 착수 사본 `debug/frontend_fe9b2/pre/<v7 기준 경로>`(모두 cmp 일치), WIP(`git status --short`)는 모두 **없음**, 줄바꿈은 Python 바이트 셈:
  - `frontend/lib/ui/pages/tactical_page.dart`(CRLF), `frontend/lib/ui/tactical/tactical_records_view.dart` · `tactical_deck_widgets.dart` · `tactical_workspace.dart` · `tactical_excel_import_view.dart` · `tactical_excel_import_panel.dart`(LF), `frontend/lib/tactical/tactical_records_controller.dart`(LF, 꼭 필요할 때만), `frontend/lib/services/design_review/tactical_records_data.dart`(LF).
  - 테스트(LF): `frontend/test/tactical_page_test.dart` · `tactical_page_revision_test.dart` · `tactical_records_controller_test.dart` · `tactical_analysis_test.dart` · `tactical_jokbo_panel_test.dart` · `tactical_excel_import_test.dart` · `mock_design_review_scenario_test.dart` · `design_review_tactical_seed_test.dart` · `test/goldens/fe9a_tactical_golden_test.dart`(조작 · 주석만).
  - 이 문서(LF, commit.json `whole`).
- 새 파일(예정): `frontend/test/tactical_fe9b2_test.dart`(저장 판정 · 표시 · 화면 흐름).
- 고치지 않음: `lib/services/**`(design_review 제외), 스캔 파일(Lane A FE8-f1), `app_shell.dart`, `lib/ui/kit/**`, golden harness, `frontend/tool/**`, backend/** · contracts/**, 택틱 소유 파일.

## FE9-b2 종료 기록 (2026-10-17, 코드 작성 완료 · CF gate 미실행)

FD-176을 기록 화면에서 쓸 수 있게 했다 — S3 시도 '모름' 저장, 방어 기록 상대 없이 저장(identity · 이름 null 쌍), null 행의 표시 정리, design-review seed 2행. HEAD는 착수 때와 같다(`9cf5f0a5`), git 쓰기 0회.

### 실행한 명령과 결과(이 PC, `frontend` 폴더)

- `flutter analyze`: ① 이 slice 몫 error 1(`tactical_page_test.dart` — 지운 `tacticalNeedAttemptHint` 참조) + 그 시점 Lane A FE8-f1 작업 중 파일(`scan_page.dart` · `lib/ui/scan/**`)의 error · info 13(이 slice 무관) → ② 고친 뒤 **No issues found(0)**, 마지막 실행도 0(`logs/analyze_final.log`, 그때는 Lane A 파일 포함 전체 0).
- `flutter test test/tactical_page_test.dart test/design_review_tactical_seed_test.dart test/tactical_fb6b_dart_test.dart`: ① **+24 −7**(모두 seed 수 4 → 6에 묶인 기대: 행 수 · revision · 긴 이름 seed의 expected 4) → ② **+31 −0**.
- 새 `flutter test test/tactical_fe9b2_test.dart`: ① −1(테스트 쪽: S4 대상 글자는 "상대 공격 덱\n—" 한 Text) → ② **+14 −0**(행 위치 검사를 더한 뒤 다시 +14).
- 바뀐 동작에 걸리는 기존 테스트(grep: `TacticalPage` · `tactical_records_view` · `tactical_deck_widgets` · `tactical_workspace` · `tactical_excel_import_view/panel` · `tactical_records_data` · `designReviewTactical` · `MockDesignReviewScenario` · `top-tab-pvp` · `AppSection.pvp` + 셸 · 전술 서비스 묶음), 일반 20파일 한 번에: ① **+198 −6**(`logs/general_1.log` — 모두 seed 수: excel commit revision · 기록 수 2, controller revision · 순서, jokbo panel revision 2, analysis 기록 수) → ② **+203 −1**(excel 재미리보기 revision 5) → excel 단독 **+14** → 마지막 20파일 **+204 −0**(`logs/general_final.log`): design_review_tactical_seed, home_page, mock_design_review_scenario, tactical_analysis, tactical_excel_import, tactical_fb6b_dart, tactical_fe9b2, tactical_jokbo_panel, tactical_page_revision, tactical_page, tactical_records_controller, tactical_v2_service, tactical_service, tactical_share_v1_contract, tactical_lobby_scanner_service, app_navigation_fe7d, app_navigation_tidy1, home_app_shell, widget_test, profile_delete_fb2d.
- process 묶음(`ProcessAppService` 문자열) 중 seed를 쓰는 것: `flutter test --concurrency=1 test/tactical_fe9b1_read_test.dart` ① −1(seed 4건 기대) → ② **+12 −0**. 실제 백엔드 process E2E는 `lib/services/**` 변경 0이라 돌리지 않았다(미실행).
- 일회성 렌더: `test/goldens/zz_fe9b2_render_tmp_test.dart`(`@Tags` · `expectGoldenScene` grep 0건, `toImage` → scratchpad PNG) +1, 실행 직후 삭제. 첫 시도는 PNG 경로 문자열 실수로 한 장만 엉뚱한 이름으로 남아(그 파일 삭제) 고쳐 다시 돌렸다 +1, 삭제(`test/goldens/zz_*` 0건). 장면 `tactical`과 6행을 고른 화면을 눈으로 확인했다.
- `dart format`: 고친 · 새 15파일을 하나씩. 마지막 `--set-exit-if-changed` 모두 0.
- `git diff --check`(고친 14파일): exit 0. 줄바꿈: `tactical_page.dart` CRLF 그대로(모든 줄 CRLF), 나머지 LF, 끝 개행 하나, 줄 끝 공백 0. `pubspec.yaml` · `pubspec.lock` 변경 0.
- 잠금 충돌 0(재시도 없음). 로그는 실패 줄 · 요약 줄만 읽었다.

### 고친 파일 · 새 파일

| 파일 | 내용 |
|---|---|
| `frontend/lib/ui/tactical/tactical_records_view.dart` | `tacticalDraftSaveBlocker`(공격 + 상대 없음만 막음) · `tacticalNeedOpponentHint`(페이지에서 옮김, 문구 그대로) · `TacticalRecordDraft.anonymous` · `opponentLabel`(FD-132, 행과 지우기 확인이 같이 씀) · `toInput(identityId: String?)` — 상대 없는 방어면 identity · 이름 null 쌍, 시도 null 그대로, 이름이 있는데 identity가 없거나 공격 + 상대 없음이면 `StateError` |
| `frontend/lib/ui/pages/tactical_page.dart`(CRLF) | `tacticalNeedAttemptHint` 삭제, `_saveBlocker`가 `tacticalDraftSaveBlocker(_current)`(지금 종류로 판정), 저장 때 상대가 없으면 identity를 만들지 않음, 스테퍼 null 반영(`clearAttempt`), 지우기 확인 문구가 `opponentLabel` |
| `frontend/lib/ui/tactical/tactical_deck_widgets.dart` | `TacticalAttemptStepper`: `ValueChanged<int?>`, 1에서 − = '—'(모름), '—'에서 + = 1, '—'에서 −는 꺼짐 |
| `frontend/lib/ui/tactical/tactical_workspace.dart` | `onAttempt` 타입 `ValueChanged<int?>?` |
| `frontend/lib/ui/tactical/tactical_excel_import_view.dart` | `tacticalExcelResultText`: 시도 null이면 결과만("패") — fb6b-dart 인계 4 · FE9-f 발견 7 |
| `frontend/lib/ui/tactical/tactical_excel_import_panel.dart` | 미리보기 줄 상대: 해석 전 "n행", 상대 없는 방어 '—'(전에는 "n행"으로 보였을 자리) |
| `frontend/lib/services/design_review/tactical_records_data.dart` | seed `dr-match-5`(방어 · 아비도스 · 패 · 시도 null · 시각 모름) · `dr-match-6`(방어 · 상대 null 쌍 · 승 · 시도 2 · 시각 모름 · 메모 "상대 이름을 확인하지 못했습니다.") + 그 상대 공격 덱(무츠키 · 카요코 · 모름 · 모름 / 아야네 · 모름) |
| 테스트 7 | `tactical_page_test`(seed 수 `_seedCount`, 행 라벨 6, 필터 기대, 이관 기록은 시도 '—' 그대로 저장), `tactical_records_controller_test` · `tactical_analysis_test` · `tactical_jokbo_panel_test` · `tactical_excel_import_test` · `tactical_fe9b1_read_test`(seed 수 · 순서 · 시도 집합 · 전체 수 6 · 상대 행 2), `goldens/fe9a_tactical_golden_test`(주석 + 존재 확인 `row-3` → `row-5`만, 장면 · 조작 동일) |
| 새 `frontend/test/tactical_fe9b2_test.dart`(14) | 저장 판정 12조합, null 쌍 입력, 이름 있는 기록, 예외 2, 라벨, 엑셀 결과 글자, seed, 분석은 공격만 · 족보 2 · 상대 identity 2, 스테퍼, 새 방어 기록 상대 없이 · 모름 저장, 종류 전환 상대 보존 · 저장 시점 판정, seed null 행 고쳐 저장(지우기 문구 · S4 '—' · 6행이 기준 캔버스 안), 1280×720 · 1440×900 넘침 0 |

확인만 하고 고치지 않음: `lib/tactical/tactical_records_controller.dart`(입력 DTO를 그대로 보냄 — 변경 0, pre와 같음), `tactical_analysis_view.dart`(fb6b-dart에서 null 처리 끝 · 분석은 공격 기록만), `tactical_jokbo_*`(대상 이름 `name.isEmpty ? '—'`), `lib/services/**`.

### 처리한 FD

- **FD-176**(확정): (A) 시도 null 저장 — 스테퍼에서 '모름'을 고를 수 있고 저장을 막지 않는다, 0 · 1로 바꾸지 않는다. (B) 방어 한정 null 쌍 — 상대 이름이 비면 identity · 이름 둘 다 null, 공격은 그대로 필수.
- **FD-132**(워커 재량 → 권장안): 방어 "내 방어덱 · vs <상대>", 상대 없으면 "내 방어덱". 지우기 확인도 같은 표기(전에는 "내 방어덱 · vs  · …"였을 자리).
- FD-128: 쓰기는 지금처럼 v2 컨트롤러 하나.

### 저장 판정 표(저장할 때의 종류 기준. 읽기 전용 · 이관 전 이유는 기존 그대로 먼저 본다)

| 종류 | 상대 이름 | 시도 | 저장 | 이유 문구 / 보내는 값 |
|---|---|---|---|---|
| 공격 | 있음 | 있음 | 가능 | identity = 이름으로 찾은 것 또는 새 ID |
| 공격 | 있음 | 모름 | 가능 | `attempt_count` null |
| 공격 | 없음(공백 포함) | 있음 · 모름 | **불가** | "상대 이름을 입력해 주십시오."(그대로) |
| 방어 | 있음 | 있음 · 모름 | 가능 | 이름 · identity 있음, 시도 그대로 |
| 방어 | 없음(공백 포함) | 있음 · 모름 | 가능 | `opponent_identity_id` · `opponent_display_name` null 쌍(가짜 identity 0) |

종류를 바꿔도 상대 입력 칸 글자는 그대로다(공격 → 방어 → 공격으로 돌아오면 같은 이름, 비워 둔 채 공격으로 오면 다시 막힘).

### 화면별 null 표시

| 화면 | 시도 모름 | 상대 없음(방어) |
|---|---|---|
| S1 목록 행 | "— · <시각>"(seed `dr-match-5` "— · —") | "내 방어덱", 메타 "2회 · —" |
| S3 작성 | 스테퍼 '—' + "시도 횟수 모름", 저장 가능 | 상대 칸 비어 있음(힌트 "상대 이름"), "순위 — · 최근 대전 —", 저장 가능 |
| 지우기 확인 | — | "\"내 방어덱 · —\" 기록을 지웁니다. …" |
| S4 족보 패널 | — | 대상 "상대 공격 덱 / —", 공개 칸이 없으면 시그니처 안내(질의 없음) |
| 분석 | 공격 기록의 모름은 기존 known/unknown 분모(fb6b-dart) | 분석 대상은 공격 기록만이라 나오지 않음(확장 안 함, fb6b-dart 발견 3) |
| 엑셀 미리보기 | 결과만("패") | 상대 '—'(해석 전은 "n행") |

### design-review seed 변화

- 4건 → **6건**(revision 6). 새 두 건은 방어 기록이라 자동 족보 2개 그대로, 분석 대상(공격 3건) 그대로, 통계 상대 행 2 그대로(상대 없는 행은 전체 수에만 든다). 시각 모름끼리는 ID 순이라 목록 순서 1 · 2 · 3 · 4 · 5 · 6(기존 네 행 위치 변화 0). 기준 캔버스에서 6행 아래 끝 ≤ 1208(스크롤 없이 보임 — 테스트로 고정).
- 게헨나 선도부 "최근 대전 2회" 그대로(새 행은 아비도스 · 상대 없음).

### golden 변화 예상(비교 미실행)

| 장면 | 예상 | 근거 |
|---|---|---|
| `tactical` | **바뀜** — S1 목록 아래에 행 2개: "패 · 내 방어덱 · vs 아비도스 대책위원회 · — · —", "승 · 내 방어덱 · 2회 · —"(일회성 렌더로 확인). S2 · S3 · S4 변화 0 | seed 6건 |
| `tactical-jokbo-drag` | **바뀜** — 같은 목록 2행 추가(고스트 · 힌트 자리 그대로) | 같은 seed |
| `tactical-import-excel` | **바뀔 수 있음** — 스크림(.62) 뒤 S1 목록 왼쪽(패널 x 500 왼쪽)에 같은 2행. 패널 내용("4건 가져오기" · 5/5)은 테스트로 그대로 확인 | 같은 seed(프롬프트 예측에 없던 장면 → 발견 1) |
| `tactical-analysis` · `-analysis-all` | 변화 0 | 분석은 공격 기록만, Mock 공개 시그니처 통계는 빈 목록 |
| `tactical-migration` | 변화 0 | seed 미사용(v1 기록만), 스테퍼 '—' 표시 같음 |
| 그 밖 | 변화 0 | 다른 golden은 전술 탭 · seed를 쓰지 않음 |

### 미검증 항목

- 전체 `fe_gate.ps1` · golden 비교 · `-UpdateGoldens` · `codealmanac validate` · 저장소 전체 `git diff --check`: **미실행**(CF 몫).
- 실제 백엔드 process E2E(tactical_fb6/fb6b/fb7/v2 process, planning_protocol_client): **미실행**(`lib/services/**` 변경 0 — 보내는 null 쌍 · null 시도는 fb6b-dart E2E가 실제 백엔드로 확인).
- 실제 백엔드에서 상대 있던 기록을 상대 없는 방어로 고쳐 저장(identity → null): **미실행**(Mock만 — fb6b-dart E2E는 null → null 편집만).
- 위 목록 밖 Flutter 테스트(Lane A 통계 · 계획 · 스캔 등): **미실행**.
- Windows release 빌드 · 사용자 시각 검수: **미실행**.

### 검수표(mock 모드 design-review 시나리오 · 기준 viewport 최대화 → 전술대항전 탭)

| 순서 | 여는 방법 | 확인 포인트 |
|---|---|---|
| 목록 | 탭 열기 | 5행 "내 방어덱 · vs 아비도스 대책위원회 · — · —"(패), 6행 "내 방어덱 · 2회 · —"(승), 기존 4행 그대로 |
| 상대 없는 방어 | 6행 누르기 | 머리 "방어 기록 · —", 상대 칸 비어 있음, S4 대상 '—' + 시그니처 안내, 저장 가능(상태 문구 없음) |
| 시도 모름 | 5행 누르기 | 스테퍼 '—' · "시도 횟수 모름", 저장 가능 |
| 새 방어 | "새 기록" → 방어 칩 → 이름 비움 → − 한 번 | '—' · "시도 횟수 모름", 저장 → 맨 위 "내 방어덱 · — · <시각>" |
| 공격 필수 | "새 기록"(공격), 이름 비움 | "상대 이름을 입력해 주십시오.", 저장 꺼짐 → 방어로 바꾸면 풀림 → 공격으로 돌아오면 다시 |
| 지우기 | 6행 → "지우기" | "\"내 방어덱 · —\" 기록을 지웁니다." |

### WIP 보존 확인

- 고친 14파일 + 이 문서는 착수 때 WIP 없음 → `post_dir` 없음. 사본 `debug/frontend_fe9b2/pre/<경로>`(고친 14 + 이 문서 + 확인만 한 4: controller · page_revision_test · design_review_tactical_seed_test · mock_design_review_scenario_test — 이 4개는 끝에도 pre와 같음). `tactical_fe9b1_read_test.dart` 사본은 고치기 직전에 만들었다(WIP 없음 확인).
- 고친 14파일 모두 HEAD = pre(`tactical_page.dart`는 CR만 다름 — 저장소 LF · 작업 트리 CRLF). 3-way 병합 충돌 없음 예상.
- Lane A 파일(`scan_page.dart` · `lib/ui/scan/**` · `app_shell.dart`): 열지도 고치지도 않았다. `dart format`은 이 slice 파일 경로만. 임시 렌더 파일 삭제 확인. git 쓰기 0회.

### 발견 사항

1. **golden `tactical-import-excel`**: 프롬프트 예측(`tactical` · `tactical-jokbo-drag`)에 없지만 같은 seed를 넣고 스크림 뒤 S1 목록이 보여 바뀔 수 있다 — CF가 failures 이미지로 확인. commit.json `whole`에 넣었다(안 바뀌면 빼면 된다).
2. **스테퍼 '모름' 고르기**(새 모호점, 권장안으로 처리): 시안 스테퍼는 −/값/+뿐이라 '모름'을 고르는 자리가 없다. 1에서 −를 누르면 '—'(모름)이 되게 했다(FE9-a의 "−는 1에서 멈춤"을 바꿈). 실수로 모름이 되면 보조 문구 "시도 횟수 모름"이 보인다. 별도 '모름' 버튼이 필요하면 CF 판단.
3. **상대 칸 안내**: 방어 기록에서 상대를 비워도 된다는 안내는 상시 띄우지 않았다(힌트 "상대 이름" 그대로, 사용법 문장 규칙). (i) 팝오버 문구 보강 여부는 CF 판단.
4. **S4 추천 질의 상대**: `_jokboPanel`은 이름이 비어도 초안의 기존 identity(`current.opponentIdentityId`)로 추천을 묻는다 — 상대 있던 기록의 이름을 지운 경우에만 해당, 가짜 ID는 없다. 동작 변경 범위 밖이라 고치지 않았다.
5. **seed 시각**: 새 두 행은 기존 행 순서를 지키려고 시각 모름으로 두었다(시각이 있으면 `dr-match-4`보다 위로 올라가 기존 테스트 · golden 행 위치가 바뀐다).
6. 워커 재량 FD: FD-132(권장안). 열림 FD 0.
7. fe_gate 분류: `tactical_fe9b2_test.dart`에 `ProcessAppService` 문자열이 없어 일반 묶음(+14).

### 사본 · commit.json

- `debug/frontend_fe9b2/commit.json`: slice `fe9b2`, modified 14, added 1, `status=true`, `whole` = 이 문서 + `frontend/test/goldens/baseline/tactical.png` · `tactical-jokbo-drag.png` · `tactical-import-excel.png`. message(ASCII) 근거: FD-176 · FD-132, fb6b-dart 인계.
- 인계: `debug/frontend_fe9b2/output.md`. 로그 `debug/frontend_fe9b2/logs/`.

### 다음 행동

- FE9-b2 코드는 끝났다. Lane B는 여기서 멈춘다.
- CF: Lane A(FE8-f1)가 멈춘 뒤 gate 1회(예상: analyze 0, 일반 +14(`tactical_fe9b2_test`) · 기존 수 변화 0, process 변화 0, golden `tactical` · `tactical-jokbo-drag` RED, `tactical-import-excel` RED 가능, 나머지 GREEN) → failures 확인 → `-UpdateGoldens` → `fe_commit.ps1 -Slice fe9b2`.
