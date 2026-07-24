---
title: "Responsive Diagonal Layout Policy"
summary: "80도 사선 글라스 섹션의 형상과 부착면을 보존하면서 여러 창 비율에 대응하기 위한 제한된 Flutter 레이아웃 정책 제안입니다."
topics: [design, architecture, workflow]
sources:
  - id: section-direction
    type: file
    path: almanac/design/frontend-section-direction-and-user-flows.md
  - id: diagonal-home-migration
    type: file
    path: docs/migration/v6-diagonal-home-menu-migration.md
  - id: current-home-page
    type: file
    path: frontend/lib/ui/pages/home_page.dart
  - id: current-app-shell
    type: file
    path: frontend/lib/ui/app_shell.dart
  - id: current-widget-tests
    type: file
    path: frontend/test/widget_test.dart
  - id: current-planning-tests
    type: file
    path: frontend/test/planning_page_test.dart
  - id: v6-ui-scaling
    type: file
    path: ../v6/docs/design/ui-scaling.md
  - id: v6-flutter-plan
    type: file
    path: ../v6/docs/design/flutter-migration-plan.md
---

# Responsive Diagonal Layout Policy

## 1. 문서 상태와 목적

이 문서는 **사용자 검수 전 제안**이다. Flutter의 constraint 기반 UI가 제공하는 자유를
그대로 사용하지 않고, BA Planner의 80도 사선·부착면·글라스·모션 규칙을 보존하는 범위
안에서만 창 크기와 비율에 대응하는 방법을 정의한다.

핵심 원칙은 다음 한 문장으로 요약한다.

> 화면을 비율마다 새로 디자인하지 않고, 각 탭이 미리 승인받은 소수의 레이아웃 상태 중
> 현재 사선 안전 영역을 만족하는 상태 하나만 선택한다.

기존 확정 규칙은 [Frontend Section Direction and User Flows](frontend-section-direction-and-user-flows)를
따른다. 이 문서는 기존 규칙을 완화하는 예외가 아니다. [@section-direction]

## 2. 고정할 것과 적응을 허용할 것

### 2.1 창 크기가 바뀌어도 고정할 항목

- 80도 사선 각도
- 좌측 섹션의 우측 빗면, 우측 섹션의 좌측 빗면, 중앙 섹션의 양측 빗면
- 섹션의 주 부착면과 그에 대응하는 intro/outro 방향
- 둥근 글라스 실루엣과 실루엣을 따르는 테두리·그림자
- 한 섹션이 담당하는 기능 기믹과 섹션 ID
- 기능의 의미 순서와 키보드·스크린리더 탐색 순서
- 현재값·목표값·총 필요량·보유량·부족량의 데이터 의미
- 핵심 행동의 존재와 접근 가능성

### 2.2 제한적으로 적응을 허용할 항목

- 승인된 레이아웃 상태 안의 섹션 폭·높이 비율
- 같은 섹션 안에서 행의 줄바꿈 또는 1행/2행 전환
- 목록·그리드의 열 수와 한 번에 보이는 행 수
- 보조 설명, 상세 근거와 진단 정보의 접기·펼치기
- 섹션 내부 스크롤 여부
- 미리 승인된 경우에 한해 위·아래 분할 또는 좌·우 배치 사이 전환
- 장식 여백, 텍스처 밀도와 이미지 crop

### 2.3 허용하지 않을 항목

- 80도를 창 비율에 따라 더 눕히거나 세우는 것
- 전체 화면을 `FittedBox`처럼 일괄 축소해 글자와 클릭 영역까지 작게 만드는 것
- Flutter `Wrap`이나 grid가 임의로 섹션의 의미 순서를 바꾸게 두는 것
- 공간이 부족하다는 이유로 핵심 행동을 숨기거나 다른 기믹 섹션 안으로 합치는 것
- 넓은 화면이라는 이유만으로 새 기능이나 새 통계를 자동 노출하는 것
- 중앙 섹션을 어느 면에도 붙지 않은 카드처럼 띄우는 것
- 창 리사이즈를 탭 이동으로 취급해 intro/outro 비행 애니메이션을 재생하는 것

v6의 전체 캔버스 일괄 배율 방식은 다양한 비율에서 정보 레이아웃을 재구성하지 못했고,
Flutter 이전 계획도 절대 크기 장식과 실제 정보 레이아웃을 분리하도록 정했다.
[@v6-ui-scaling] [@v6-flutter-plan]

## 3. 화면 비율보다 사선 안전 영역을 먼저 계산

80도 사선이 섹션의 전체 높이 `h`를 가로지르면 사선이 소비하는 수평 깊이의 기본값은
다음과 같다.

```text
cutDepth(h) = h / tan(80°) ≈ 0.1763 × h
```

따라서 높이가 큰 섹션은 같은 외곽 폭을 가져도 실제 콘텐츠 폭이 더 좁다. 반응형 상태를
단순히 `windowWidth / windowHeight`만으로 고르면 이 차이를 놓친다.

섹션별 가용 폭은 최소한 다음 값으로 판정한다.

```text
safeWidth = outerWidth
            - leftCutDepth
            - rightCutDepth
            - contentPaddingLeft
            - contentPaddingRight
            - shadowAndRadiusReserve
```

- 단측 사선 섹션은 해당 방향의 cut depth 하나를 뺀다.
- 양측 사선 섹션은 두 방향을 모두 뺀다.
- 실제 path의 둥근 모서리와 inset은 공용 geometry 함수가 계산한다.
- 같은 섹션에서도 Y 위치에 따라 경계가 달라지므로 각 행은 자신의 상단과 하단에서
  사용할 수 있는 폭 중 작은 값을 사용한다.
- 텍스트와 컨트롤의 최소 폭은 외곽 사각형이 아니라 이 `safeWidth`와 비교한다.

홈 메뉴는 이미 행마다 우측 사선 경계를 다시 계산한다. 이 접근을 일반 섹션의 공용
안전 영역 계약으로 확대하는 것이 적합하다. [@diagonal-home-migration]

## 4. 섹션별 반응형 계약

각 실제 섹션은 구현 전에 다음 항목을 명시한다.

| 항목 | 의미 |
|---|---|
| `sectionId` | 창 크기가 변해도 유지되는 기능·상태 ID |
| `gimmick` | 이 섹션이 완결하는 단일 사용자 목적 |
| `primaryAnchor` | left, right, top, bottom 중 주 부착면 |
| `cutSides` | left, right 또는 bilateral 사선 |
| `allowedVariants` | 승인된 wide, standard, compact 형상 |
| `minSafeWidth` | 사선·padding을 제외한 콘텐츠 최소 폭 |
| `minSafeHeight` | 핵심 행과 조작 영역에 필요한 최소 높이 |
| `minRatio` / `maxRatio` | 섹션 외곽 형상이 허용되는 종횡비 범위 |
| `stretchAxis` | 여유 공간을 받아도 되는 축 |
| `overflowPolicy` | wrap, inner scroll, detail collapse 중 허용 방식 |
| `priority` | 공간 부족 시 먼저 보존할 핵심/보조 정보 등급 |
| `readingOrder` | 다른 섹션과의 의미·접근성 순서 |

`allowedVariants`는 기본적으로 섹션당 3개 이하로 제한한다. Flutter가 계산 가능한 모든
배치를 허용하지 않고, 디자인 검수를 받은 변형만 코드로 표현한다.

## 5. 권장 레이아웃 상태

비율 이름은 테스트와 대화를 위한 분류다. 실제 상태 전환은 창 비율 하나가 아니라 모든
핵심 섹션의 `minSafeWidth`, `minSafeHeight` 충족 여부로 결정한다.

### 5.1 Wide 상태

주로 16:9보다 넓거나 큰 창에서 사용한다.

- 좌측·중앙·우측 기믹을 동시에 보여줄 수 있다.
- 좌우 외곽 섹션은 자신의 창 경계에 계속 붙는다.
- 목록, 그리드, 타임라인처럼 데이터 밀도가 늘어나도 의미가 유지되는 영역이 여유 폭을
  우선 받는다.
- 입력기, 숫자 필드, 버튼과 상세 카드에는 최대 폭을 두어 과도하게 늘어나지 않게 한다.
- 남는 폭 때문에 기능을 추가하지 않는다. 좌우 클러스터 사이의 배경 여백 또는 승인된
  연결 섹션의 유연 폭으로 흡수한다.

### 5.2 Standard 상태

16:10과 16:9의 일반 데스크톱 창을 기준 상태로 사용한다.

- 디자인 검수의 기준본이며 모든 핵심 기믹이 동시에 또는 한 번의 명확한 모드 전환으로
  접근 가능해야 한다.
- 섹션 비율과 내부 행 구성이 가장 안정적인 canonical variant다.
- Wide와 Compact는 이 상태의 의미 순서와 섹션 ID를 보존해 파생한다.

### 5.3 Compact 상태

4:3에 가깝거나 절대 폭이 부족하지만 높이는 확보된 창에서 사용한다.

- 여러 열을 억지로 압축하지 않고, 승인된 섹션을 위·아래로 분할하거나 좌우에 번갈아
  부착한다.
- 좌측에 배치된 섹션은 오른쪽 빗면, 우측에 배치된 섹션은 왼쪽 빗면을 계속 유지한다.
- 중앙 기능이 위 또는 아래 경계에 붙는 variant를 가진다면 해당 부착면의 80/260 모션
  계약을 사용한다.
- 상세 근거와 보조 통계는 접을 수 있지만 핵심 결과와 다음 행동은 남긴다.
- 긴 목록은 섹션 내부에서 스크롤하며 헤더와 주 행동을 고정한다.

### 5.4 Constrained 상태

모든 승인 variant가 최소 안전 폭·높이를 만족하지 못하는 크기다. 이 상태는 자유로운
축소 디자인이 아니라 지원 하한을 명확히 보여 주는 안전장치다.

- 제품이 보장할 최소 창 크기는 P6 섹션 계약이 모인 뒤 가장 큰 최소 요구량으로 정한다.
- 가능하면 Windows 창 자체에 그 최소 크기를 적용한다.
- 운영체제나 테스트 환경이 더 작은 크기를 강제하면 글자·버튼을 축소하거나 사선을
  제거하지 않는다.
- 대신 현재 핵심 섹션 하나를 정상 크기로 유지하고, 다른 승인 섹션으로 이동할 수 있는
  명확한 compact navigation 또는 제한 안내를 제공한다.
- 데이터 편집 상태는 크기 전환 전후에 유지한다.

이 정책은 “모든 크기를 똑같이 지원한다”는 목표를 버리고, 디자인 규칙과 사용 가능성을
보장할 수 있는 지원 영역을 명시한다.

## 6. 비율별 구체적 적응 전략

### 6.1 세로 공간이 부족한 넓은 창

- 헤더 높이는 승인된 범위 안에서만 줄인다.
- 위·아래로 쪼갠 작은 섹션을 먼저 합치지 말고 각 섹션의 보조 행을 접는다.
- 목록과 상세 본문은 내부 스크롤을 사용한다.
- 사선 높이를 무리하게 낮춰 내부 컨트롤과 충돌시키지 않는다.

### 6.2 폭이 부족한 높은 창

- 3열을 2열, 2열을 위·아래 배치로 전환한다.
- 양측 사선 중앙 섹션이 최소 안전 폭을 잃으면, 승인된 top/bottom 부착 variant로 바꾼다.
- 한 행의 컨트롤은 미리 정의된 2행 variant로 바꾸며 임의 순서 Wrap은 사용하지 않는다.
- 마스터 목록과 상세는 동시에 찌그러뜨리지 않고, 목록 선택 후 상세 모드로 전환할 수 있다.

### 6.3 울트라와이드 창

- 모든 요소를 비례 확대하지 않는다.
- 외곽 섹션은 좌우 창 경계에 붙이고 중앙의 여유는 목록 열 수, 그래프 plot 폭, 의미 있는
  연결 공간에만 배분한다.
- 중앙에 기능 카드가 떠 있는 형태는 사용하지 않는다. 중앙 섹션이 필요하면 위·아래 또는
  양옆 구조에 실제로 연결한다.
- 텍스트 행 길이와 폼 폭에는 최대값을 둔다.

### 6.4 높은 DPI와 텍스트 배율

- 창 비율 적응과 텍스트 배율을 같은 값으로 처리하지 않는다.
- 글자가 커지면 먼저 행 높이, 줄바꿈과 내부 스크롤이 반응해야 한다.
- 사선 각도와 핵심 클릭 영역을 줄여 공간을 만들지 않는다.
- 텍스트가 잘리면 장식 또는 보조 정보보다 텍스트와 조작 가능성을 우선한다.

## 7. 공간이 부족할 때의 고정 우선순위

공간 부족은 다음 순서로 해결한다.

1. 섹션 내부의 탄력 여백과 장식 여백을 줄인다.
2. 데이터 목록·그리드의 열 수를 줄인다.
3. 승인된 행 variant로 줄바꿈한다.
4. 보조 설명과 상세 근거를 접되 사용자가 다시 열 수 있게 한다.
5. 섹션 내부 스크롤을 사용한다.
6. Standard에서 Compact 같은 승인된 레이아웃 상태로 전환한다.
7. 그래도 최소 안전 영역을 만족하지 못하면 Constrained 상태로 들어간다.

다음 항목은 이 순서에서 제거하거나 축소할 수 없다.

- 현재 대상과 프로필 표시
- 저장·확정·취소처럼 결과를 바꾸는 핵심 행동
- 오류, disconnected와 review-required 상태
- 현재값·목표값 또는 필요·보유·부족을 구분하는 라벨
- 키보드 포커스 표시와 최소 클릭 영역

## 8. 리사이즈 중 상태와 애니메이션

- 창 크기 변경은 탭 전환이 아니므로 섹션 intro/outro를 재생하지 않는다.
- 같은 variant 안에서는 section path와 bounds만 연속적으로 다시 계산한다.
- variant가 바뀌어도 같은 `sectionId`, 선택 대상, 스크롤 기준점과 입력 draft를 유지한다.
- 부착면이 바뀌는 variant 전환은 route motion 대신 승인된 geometry transition 또는 즉시
  재배치를 사용한다.
- breakpoint 경계에서 창을 조금 움직일 때 상태가 반복 전환되지 않도록 진입·이탈 기준에
  작은 hysteresis 구간을 둔다.
- 리사이즈 중 backend 재요청, 프로필 재로드 또는 계산 결과 초기화를 하지 않는다.

## 9. Flutter 구현 경계 제안

실제 구현 시 공용 계층을 다음처럼 제한한다.

- `ResponsiveSectionScaffold`: 가용 rect와 등록된 section contract로 승인 variant 선택
- `SectionLayoutSpec`: anchor, cut side, min/max ratio와 variant 목록 보유
- `DiagonalSafeArea`: 80도 path의 Y별 안전 폭을 계산해 내부 행에 제공
- `SectionGeometry`: clip, hit test, border와 shadow가 공유하는 단일 path
- `SectionOverflowPolicy`: 허용된 wrap, scroll, collapse만 명시적으로 적용
- `ResponsiveStateStore`: variant 변경 중 선택·입력·스크롤 상태 보존

각 탭이 임의의 `LayoutBuilder` breakpoint를 추가하지 못하게 하고, breakpoint와 geometry
결정은 공용 scaffold와 section spec에 모은다. 탭은 승인된 variant별 내부 구성만 제공한다.

## 10. 현재 구현에서 확인된 출발점과 부족한 부분

- 홈 메뉴는 742×1018 최대 크기의 고정 비율 캔버스를 `FittedBox`로 축소한다. 사선과 이미지
  비율 보존에는 유효하지만 글자·클릭 영역까지 함께 줄어드는 방식이므로 일반 기능 탭의
  반응형 기본 전략으로 확대하지 않는다. [@current-home-page]
- 앱 shell은 1050px에서 개발 패널의 dock/overlay를 전환하고 헤더 shelf를 최대 760px로
  제한한다. 이는 특정 보조 패널 대응이며 제품 섹션 전체의 비율 정책은 아니다.
  [@current-app-shell]
- 계획 화면은 `Wrap`과 좁은 360×700 Widget test를 갖지만, 사선 섹션의 승인 variant와
  안전 폭 계약은 아직 없다. [@current-planning-tests]
- 현재 공용 Widget test는 1280×720, 1440×900, 1440×1300과 900×640 등의 일부 크기를
  확인한다. 4:3, 16:10과 울트라와이드 전 탭 회귀 기준은 아직 없다.
  [@current-widget-tests]
- 개발용 `Section Template Studio`는 세로 track이 모두 우측 위 `/` 방향 80도로 기운
  공용 48×48 논리 캔버스에 사용자가 요소를 직접 추가·삭제·배치한다. 단일과 조합은 요소
  수로 자연스럽게 결정하며 고정 조합 preset은 제공하지 않는다. Standard·Wide·Compact
  비율에서 요소의 범위·중첩·부착면과 형상 적합성을 먼저 검증할 수 있다. 8칸마다 이전
  1/6 major line을 유지하고 한 칸을 섹션 사이 기본 간격으로 사용한다. 도형은 삼각형·
  사다리꼴·평행사변형 모드와 붙는 면, 면 내부 48분할 범위로 정의하며 사다리꼴·
  평행사변형만 높이를 추가로 받는다. 모든 요소는 동일한 캔버스 좌표에서 그려지며 요소
  점유 rect는 clipping viewport로 사용하지 않는다. 실제 탭의 `DiagonalSection` 승격과
  사용자 구성 저장은 후속 경계다. 프리뷰의 고정 헤더는 1/48~24/48 높이를 선택할 수 있고
  섹션 그리드와 geometry는
  헤더를 제외한 남은 콘텐츠 rect만 기준으로 계산한다. 선택 요소는 본체 drag로 이동하고
  네 모서리 handle로 resize하며, 위치와 크기는 viewport 픽셀 비율과 무관하게 48×48 정수
  셀에 snap되고 캔버스 경계에서 clamp된다.

## 11. 검증 매트릭스 제안

정확한 최종 최소 창 크기는 실제 P6 섹션 계약을 작성한 뒤 확정한다. 그 전까지 다음
비율군을 설계·golden·Widget test 대상으로 사용한다.

| 비율군 | 후보 크기 | 확인 목적 |
|---|---|---|
| 최소 wide/standard | 1280×720 | 기존 Flutter 기준과 최소 높이 후보 |
| 16:10 | 1440×900 또는 1920×1200 | 높이 여유가 있는 일반 창 |
| 16:9 | 1600×900, 1920×1080 | canonical desktop |
| 4:3 compact | 1280×960 | 폭 부족·세로 재배치 |
| ultrawide | 2560×1080, 3440×1440 | 과도한 신장과 중앙 부유 방지 |
| constrained probe | 최종 최소값보다 작은 크기 | 안전한 제한 상태와 state 보존 |

각 크기에서 다음을 자동 검증한다.

- section path와 hit test path 일치
- 모든 행의 콘텐츠가 사선 안전 polygon 안에 존재
- 핵심 컨트롤의 최소 크기와 텍스트 overflow 없음
- 섹션 부착면, cut side와 reading order 유지
- variant 전환 전후 선택·입력·스크롤 상태 유지
- resize가 intro/outro나 backend reload를 발생시키지 않음
- loading, empty, error, disconnected, review-required 상태에서도 동일 계약 유지
- Windows 100%, 125%, 150%, 200% 배율과 긴 한국어 이름 확인

## 12. 사용자 승인 필요 항목

다음 항목은 제안 단계이며 실제 디자인 계약으로 확정하기 전에 사용자가 결정해야 한다.

1. 한 탭이 가질 수 있는 승인 레이아웃 상태를 Wide/Standard/Compact 최대 3개로 제한할지
2. 모든 탭의 완전 기능 지원 하한을 둘지, 하한 아래 Constrained 단일 섹션 모드를 제공할지
3. 좁은 창에서 마스터 목록과 상세를 동시 표시하지 않고 순차 모드로 전환해도 되는지
4. 울트라와이드의 중앙 여유를 배경 여백으로 허용할지, 연결 섹션이 항상 채워야 하는지
5. Compact variant에서 섹션의 주 부착면 변경을 허용할지
6. 보조 설명·상세 통계·진단 정보를 접을 수 있는 정보로 분류할지

승인 후 각 탭은 기능별 사용자 흐름을 실제 section contract에 매핑하고, 그때 계산된
최대 최소 요구량으로 제품의 지원 최소 창 크기를 확정한다.
