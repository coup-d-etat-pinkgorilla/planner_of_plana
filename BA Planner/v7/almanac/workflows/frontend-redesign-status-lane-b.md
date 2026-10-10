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

**FE8-a 코드 작성 완료, gate ① 대기(2026-10-10 새벽).** 시작 커밋 `c9258cb1`. 분할하지 않았다(아래 "FE8-a 착수 기록"·"FE8-a 종료 기록"). 예상: golden `title` 1건 RED(나머지 장면 불변), 일반 테스트는 녹색 예상(실행하지 못함).

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
