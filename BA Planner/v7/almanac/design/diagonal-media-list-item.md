---
title: "Diagonal Media List Item"
summary: "계획·스캔 결과에서 재사용하는 사선 학생 단계 행의 구조, 확정된 표시 규칙, 조정 이력과 실화면 검증 시행착오를 기록합니다."
topics: [design, flutter, workflow, testing]
sources:
  - id: runtime-widget
    type: file
    path: frontend/lib/ui/widgets/diagonal_media_list_item.dart
  - id: widget-tests
    type: file
    path: frontend/test/diagonal_media_list_item_test.dart
  - id: plan-layout
    type: file
    path: frontend/lib/ui/widgets/plan_section_layout.dart
  - id: viewport-fog
    type: file
    path: frontend/lib/ui/widgets/scroll_viewport_fog.dart
  - id: studio-document
    type: file
    path: release/component-diagonal-media-list-item1.ba-section-studio.json
  - id: workflow-status
    type: file
    path: almanac/workflows/p0-p6-workflow-status.md
---

# Diagonal Media List Item

## 2026-08-01 student-catalog current-state presentation

- The shared row keeps its original planning presentation by default. Student
  Section 2 opts into `currentStudentState`, so other plan call sites retain
  their order number, target suffix, type scale, bond delta, and icon size.
- In the student-catalog presentation the title contains only the student name.
  Title, level, weapon level, skills, equipment values, favorite item, and
  ability-release/stat values use a 1.5 scale factor.
- The left order number is omitted. An unowned row places the `UNOWNED` badge
  in that vacated slot and suppresses the portrait-local badge.
- The vacated status rail has three fixed top-to-bottom slots: `UNOWNED`,
  `PLAN`, and `JP`. Each slot samples the final rounded item path at its own top
  and bottom Y positions, keeps a side inset from the 80-degree edge and the
  portrait, and shares equal vertical spacing. Missing statuses leave their
  reserved slot empty instead of moving the remaining badges.
- The unowned darkening is a `ColorFiltered` operation on the composited
  `BondRankPortrait`, preserving its alpha instead of painting a rectangular
  overlay across the portrait slot. The same final portrait clip still owns the
  image and filter.
- Bond-rank delta text is hidden and equipment icon surfaces are scaled to
  1.15 only in this presentation.

## 1. 목적과 재사용 경계

`DiagonalMediaListItem`은 학생 한 명의 현재 상태와 목표 단계, 그리고 각 값의
변화량을 한 행에 표시하는 중립 Flutter 컴포넌트다. 최초 사용처는 계획 탭의
페이즈별 학생 단계 목록이지만, 스캔 결과 확인 창에서도 같은 정보 구조를
재사용할 수 있도록 계획 계산이나 특정 페이지 상태를 직접 소유하지 않는다.
[@runtime-widget] [@plan-layout]

Studio JSON은 최초 배치와 수동 조정의 원본이며, 런타임 Widget은 해당 비율 좌표를
typed layout constant로 투영한다. `release/` 갱신 과정에서도 Studio 문서는
보존되어야 한다. [@studio-document]

## 2. 현재 확정된 표시 계약

### 2.1 행과 사선 컨테이너

- 행 높이는 정보 밀도를 낮추고 학생 portrait가 잘리지 않도록 65px로 사용한다.
- 행 간 extent는 69px이며, 각 행은 부모 페이즈의 80° 사선 경계를 따라 X 위치를
  다시 계산한다.
- 학생 portrait 뒤에는 인연 랭크에 맞는 `square.png`를 두고 portrait는 그
  배경의 98% 크기로 그린다.
- 장비 아이콘도 `square.png` 위에 98% 크기로 그린다.
- 페이즈 사이에는 아래 방향 삼각형으로 진행 흐름을 표시한다.
- 페이즈 헤더 우측 상단의 내부 아이템 개수는 표시하지 않는다.
- 페이즈 목록에 아래쪽 분량만 남으면 아래 안개, 양쪽 분량이 남으면 위·아래
  안개, 마지막 위치에서는 위 안개만 표시한다. 학생 탭 Section 2와 공용
  `ScrollViewportFog`의 색상·36px 범위·끝점 tolerance를 공유한다.
  [@viewport-fog]

### 2.2 값과 변화량

- 일반 단일 값은 `5(▲2)` 또는 `5(▼2)` 형식을 사용한다.
- 상승은 초록, 하강은 빨강으로 표시한다.
- 스킬·장비·추가 능력치처럼 여러 구성값이 있는 영역은 본문 아래에 별도의
  변화량 행을 둔다.
- 다중 변화량은 `- / - / - / ▲1`처럼 원래 구성 순서를 보존한다.
- 모든 구성값이 무변동이면 하단 변화량 행 자체를 렌더링하지 않고 본문을
  세로 중앙에 둔다.
- 스킬은 EX 최대 5, 나머지 최대 10을 `M`으로 표시한다.
- 장비는 티어와 장비 레벨을 모두 표시하며 각각 독립된 변화량을 가질 수 있다.

### 2.3 성작, 애장품과 인연 랭크

- 성작/무기 성작 indicator는 학생 탭의 표현을 따르며, 높이는 초기값보다 30%
  줄인 비율을 유지한다.
- 애장품 티어는 본문과 변화량이 함께 있어도 본문이 과도하게 축소되지 않는
  독립 폭을 사용한다.
- 인연 하트는 우측 전용 열의 `center x = 0.95`에 고정한다.
- 하트의 실제 렌더링 중심 Y는 학생 portrait 뒤의 큰 `square.png` 중심 Y와
  일치한다.
- 인연 변화량은 하트 바로 아래에 두고 실제 텍스트 중심 X도 하트 중심 X와
  일치시킨다.
- 인연 배경은 1~19 기본, 20~49 파랑, 50~99 노랑, 100 보라를 사용한다.
- 하트 숫자는 100에서 경계를 조금 사용할 수 있도록 15.75px을 유지한다.

## 3. 작업 경과

1. Studio에서 만든 단일 행을 데이터 기반 중립 컴포넌트로 옮기고 계획 탭의
   기존 간이 타일을 교체했다.
2. 최초 배치의 중심선 그룹을 코드와 Widget test로 고정하고, 도형 4는 성작
   indicator, 도형 17은 1~100 인연 하트의 위치 앵커로 해석했다.
3. 초기 행이 너무 조밀하고 portrait가 잘려 보이므로 높이를 54px로 늘린 뒤,
   다시 약 20% 늘려 65px로 확정했다.
4. 학생과 장비 이미지에 공통 `square.png` 배경을 추가하고 실제 이미지를 98%
   크기로 겹쳤다. 인연 랭크별 학생 배경 교체 규칙은 학생·계획·통계 탭에서
   공유하도록 만들었다.
5. 스킬을 학생 레벨과 장비 사이로 옮기고 글자 크기를 1.5배로 키웠다. 장비에는
   티어뿐 아니라 레벨을 추가했다.
6. 좁은 가로폭에서도 다중 변화량이 안전하도록 스킬·장비·추가 능력치의 변화량을
   하단 행으로 분리하고, 무변동 행 생략과 스킬 최대값 `M` 표시를 추가했다.
7. 인연 하트는 정보 열 사이와 우측 끝을 오가며 비교한 뒤 우측 전용 열에
   고정했다. 변화량은 하트 아래의 독립 행으로 유지했다.
8. 현재 모니터의 최대화된 2560×1392 release 화면을 기준으로 학생 배경 중심과
   하트 중심을 다시 맞췄고, 인연 변화량의 실제 글자 중심 X까지 하트와
   일치시켰다. 날짜별 구현·검증 상태는 P0-P6 workflow 상태 기록에도 유지한다.
   [@workflow-status]

## 4. 시행착오와 원인

### 4.1 `square.png` 비교 대상 혼동

학생 portrait 배경과 장비 아이콘 배경이 모두 `square.png`를 사용한다. 처음에는
“하트 centerY를 square.png와 맞춘다”는 요구를 작은 장비 배경 중심으로 해석했다.
코드상 좌표는 그 기준에 정확했지만 사용자가 의도한 학생 portrait 배경보다 하트가
아래에 남았다.

해결 원칙:

- 별도 수식이나 임의 optical offset보다 명시적인 대상 Widget을 기준으로 삼는다.
- 인연 하트의 Y 기준은 `equipmentImages`가 아니라 `portrait`다.
- 테스트에서도 두 layout slot 또는 두 실제 Widget의 중심을 직접 비교한다.

### 4.2 작은 창 검증의 오류

초기 실화면 검증은 작은 release 창을 기준으로 수행해 현재 모니터에서 사용자가
보고 있는 배치와 다른 인상을 만들었다. 3px optical offset을 추가했지만 이는
근본 원인인 비교 대상 혼동을 해결하지 못했다.

해결 원칙:

- 사용자가 현재 모니터 기준 작업을 요구한 계획 탭 검수는 release 창을 먼저
  최대화한다.
- 현재 기준 환경은 2560×1392이며, 전체 화면과 필요한 행 확대 이미지를 함께
  확인한다.
- 좌표 test는 회귀 방지 수단이지 최종 시각 판단의 대체물이 아니다.

### 4.3 슬롯 중심과 실제 그림 중심의 차이

`AspectRatio`, `Center`, `FittedBox`, `Align`이 중첩되면 부모 슬롯 중심이 같아도
실제 그림 또는 글자의 bounds는 다를 수 있다. 특히 하트는 delta 공간을 포함한
전체 열과 실제 하트 렌더링 영역이 서로 다르다.

해결 원칙:

- 하트 Y 검증은 전체 `bondWithDelta`가 아니라 `diagonal-media-heart`의 실제
  render object를 사용한다.
- 하트 아래 delta 검증도 열 전체가 아니라 실제 텍스트를 감싸는 `FittedBox`에
  key를 부여해 측정한다.

### 4.4 `Center`만으로 인연 변화량이 중앙에 오지 않은 이유

인연 변화량을 `Center`로 감쌌어도 공용 `_DeltaLabel` 내부
`Align(Alignment.centerLeft)`가 가로폭 전체를 차지했기 때문에 실제 텍스트는
왼쪽에 남았다. 바깥 부모의 정렬만 바꾸는 것으로는 내부 정렬을 덮어쓸 수 없다.

해결 원칙:

- `_DeltaLabel`은 기본값 `centerLeft`를 유지하되 호출부가 `alignment`를
  지정할 수 있게 한다.
- 인연 변화량에만 `Alignment.center`를 전달한다.
- 실제 delta `FittedBox` 중심 X와 실제 하트 중심 X가 같은지 Widget test로
  검증한다.

## 5. 검증 계약

관련 변경은 최소한 다음을 확인한다. [@widget-tests]

- 계획 탭 더미 데이터는 4개 페이즈와 총 16개 행을 제공해 기준 화면에서도
  실제 세로 스크롤 범위를 만든다.
- 인연 50과 100 더미 행을 포함하며, 각각 노랑과 보라 학생 배경을 사용한다.
- 인연 100은 최대치이므로 추가 상승 변화량을 표시하지 않는다.
- 학생 portrait와 하트의 실제 중심 Y가 일치한다.
- 인연 변화량의 실제 중심 X가 하트의 실제 중심 X와 일치한다.
- 인연 변화량의 상단이 하트 하단보다 아래에 있다.
- 변화량이 0 또는 null이면 해당 하단 행이 보이지 않는다.
- 스킬 최대값은 `M`으로 표시된다.
- 장비 배경과 실제 아이콘의 98% 비율이 유지된다.
- 100 인연 랭크의 하트 숫자와 보라 배경이 유지된다.
- `flutter analyze --no-pub`, 집중 Widget test, Windows release build와
  최대화 실화면 검수를 수행한다.

## 6. 후속 변경 시 주의사항

- Studio 좌표를 바꾸면 런타임 layout constant와 Studio JSON을 함께 갱신한다.
- `square.png`를 기준으로 말할 때는 학생 배경인지 장비 배경인지 코드와 문서에서
  명시한다.
- 하트 열의 위치, 하트 자체, delta 행은 서로 다른 bounds이므로 하나의 중심값으로
  간주하지 않는다.
- 공용 `_DeltaLabel`의 기본 정렬을 바꾸면 학생 레벨, 무기 레벨과 애장품 등 기존
  호출부가 함께 변한다. 인연 전용 정렬은 호출부에서 제한한다.
- 실제 모니터 검수 전 임의의 pixel 보정값을 확정하지 않는다.
- 스크롤 회귀 test는 단순 drag 호출 여부가 아니라 `maxScrollExtent`가 viewport보다
  크고, drag 뒤 현재 offset과 마지막 더미 행의 실제 Y가 함께 변하는지 확인한다.
- 안개 회귀 test는 스크롤 시작·중간·끝에서 각각 아래만·양쪽·위만 보이는지
  확인한다. 최초 build에 controller client가 아직 없을 수 있으므로 계획 scrollbar는
  알려진 content extent로 초기 아래 안개와 handle 크기를 계산한다.
