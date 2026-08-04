---
title: "평행사변형 부모 안의 자식 요소 배치 가이드"
summary: "Flutter 사선 섹션 안에서 카드·행·버튼을 부모 rail에 맞춰 배치하기 위한 경계 함수, normal inset, 스케일, clip, hit test, 회귀 검증 규칙을 정리한다."
topics: [design, flutter, diagonal-layout, geometry, testing]
sources:
  - id: condition-section
    type: file
    path: frontend/lib/ui/widgets/student_range_condition_section.dart
  - id: preset-card
    type: file
    path: frontend/lib/ui/widgets/plan_element_builder.dart
  - id: condition-tests
    type: file
    path: frontend/test/student_range_condition_section_test.dart
  - id: preset-tests
    type: file
    path: frontend/test/plan_element_builder_test.dart
---

# 평행사변형 부모 안의 자식 요소 배치 가이드

## 핵심 원칙

평행사변형은 직사각형 bounds에 사선 clip을 추가한 것이 아니라, Y에 따라 사용 가능한 X 구간이 이동하는 레이아웃 공간이다. 부모의 painted path와 자식의 배치·paint·clip·hit test를 하나의 geometry 체계로 계산해야 한다.

80도 bilateral section에서 높이가 `H`, 폭이 `W`, `depth = H / tan(80°)`이면 부모 경계는 다음과 같다.

```text
left(y)  = depth * (1 - y / H)
right(y) = W - depth * (y / H)
```

아래로 `ΔY` 이동한 자식은 같은 rail을 따르기 위해 X도 `-ΔY / tan(80°)`만큼 이동해야 한다. 세로로 쌓인 자식의 bounding box를 같은 X에 두면 clip 안에 보이더라도 부모 사선 규칙을 따르는 배치가 아니다.

## 배치 전에 결정할 사항

1. 부모 path의 실제 방향, 각도, 상·하단 endpoint와 rounded-corner 반경을 확인한다.
2. 자식이 직사각형이어도 되는지, 부모와 평행한 사선 surface를 가져야 하는지 구분한다.
3. 부모 local 좌표, 중간 wrapper 좌표, 자식 local 좌표를 혼합하지 않는다.
4. 배치 책임자를 하나로 둔다. `Positioned`/layout 계산과 별도 임의 translate가 같은 축을 중복 소유하지 않게 한다.
5. margin이 수평 거리인지 사선에 대한 법선 거리인지 명시한다. 80도 rail의 normal gap `g`를 X inset으로 바꿀 때는 `g / sin(80°)`를 사용한다.

## 직사각형 자식의 안전 구간

자식이 `[top, bottom]`을 차지한다면 한 Y의 중심점만 보지 않는다. 자식 전체 높이에 안전한 직사각형 구간은 다음 교집합이다.

```text
safeLeft  = max(left(top), left(bottom), corner transition points...) + inset
safeRight = min(right(top), right(bottom), corner transition points...) - inset
```

행마다 top/bottom이 다르므로 세로 stack의 각 행은 서로 다른 X와 width를 가져야 한다. 하나의 공통 safe rectangle을 전체 stack에 적용하면 불필요하게 좁아지거나 특정 행이 rail에서 멀어진다.

## 평행사변형 자식의 배치

자식도 부모와 같은 각도의 평행사변형이면 rectangular intersection보다 넓은 공간을 사용할 수 있다. 자식 높이가 `h`일 때 자식 bounding rect의 cut depth도 `h / tan(80°)`가 된다.

```text
childLeft  = parentLeft(childBottom) + normalInset / sin(80°)
childRight = parentRight(childTop) - normalInset / sin(80°)
```

여분 폭이 있으면 부모 rail 구간 안에서 동일하게 나누되, 자식 top-left/bottom-left와 top-right/bottom-right가 각각 한 직선 rail 위에 남아야 한다. 조건 카드처럼 두 자식을 쌓는 경우 각 카드의 실제 top/bottom으로 이 계산을 별도 수행한다.

## 크기 조정과 aspect ratio

- 사선 path를 고정 크기에서 X/Y로 다르게 stretch하지 않는다. 비균일 scaling은 cut angle을 바꾼다.
- 먼저 자식의 설계 크기와 rail length를 구한 뒤, 세로 슬롯 한계와 부모 rail-length 한계 중 작은 uniform scale을 사용한다.
- 컨트롤 최소 높이보다 작아질 때는 카드 layout width 자체를 줄이지 않는다. 안정적인 설계 크기로 layout한 후 전체를 균일 축소하거나, 제품 정책에 따라 reflow/stack/scroll을 선택한다.
- 공간을 새로 만들 때는 어느 행에서 얼마를 회수하는지 명시하고 전체 높이·행 간격·bottom inset의 보존 여부를 검증한다.

## clip과 hit test

- `ClipPath`는 넘친 요소를 숨길 뿐 올바른 배치를 만들지 않는다.
- 배경, hover/splash, outline, fog, 이미지, scrollbar는 같은 path 또는 명시적으로 파생된 path를 사용한다.
- 버튼과 체크박스의 네 모서리가 painted path 안에 있는지 확인한다. 보이지만 transparent corner에 있으면 hit test가 실패할 수 있다.
- header overlay도 top 한 점만 보지 않고 컨트롤의 top/bottom Y에서 얻은 수평 구간의 교집합에 둔다.

## rounded corner와 효과

- 직선 rail 공식만으로 끝내지 않고 rounded-corner transition Y도 critical point로 검사한다.
- shadow는 clip 안에서 그리면 잘린다. 외곽 foundation이 shadow를 먼저 그리고, content clip은 그 다음 계층에서 소유한다.
- fog나 texture는 실제 visible path bounds를 local canvas로 사용한다. 큰 부모 canvas 좌표를 그대로 쓰면 light center와 vignette가 어긋난다.

## 반응형 검증 체크리스트

- small/normal/wide 크기와 비정수 scale에서 다시 계산되는가.
- 각 자식의 top/middle/bottom에서 부모 path 안에 있는가.
- 세로로 쌓인 자식의 `ΔX = -ΔY / tan(angle)` 관계가 유지되는가.
- 부모와 자식의 좌우 rail slope가 같은가.
- 네 방향 normal gap이 요구값 이상인가.
- 자식끼리 겹치지 않고 지정된 세로 gap이 유지되는가.
- 텍스트, focus, hover, splash, tooltip과 실제 hit target이 clip 안에 있는가.
- callback, focus order, semantics와 상태 styling이 geometry 변경 전과 같은가.

## 다음 평행사변형 작업 시작 전 의무 절차

다음에 평행사변형 섹션 안에 위젯이나 패널을 추가·이동할 때는 아래 순서를 구현 전 체크리스트로 사용한다. 하나라도 결정되지 않았으면 좌표나 padding부터 수정하지 않는다.

### 1. 대상 계층을 먼저 특정한다

- 화면에서 어긋난 대상이 외곽 section, 내부 surface, row, content, overlay 중 어느 계층인지 확인한다.
- 부모 section path, 자식 visible path, 자식의 rectangular layout owner를 각각 찾는다.
- 내부 content가 어긋난 것인지, 자식 panel 전체의 부모 내 host가 어긋난 것인지 구분한다.
- `Center`, `Align`, 공통 `Padding`, 고정 `Positioned`가 부모 rail 이동을 무효화하고 있지 않은지 검사한다.

### 2. geometry 계약을 숫자로 기록한다

- 부모 크기, 사선 방향, 각도, cut depth, top/bottom endpoint를 기록한다.
- 자식별 top/bottom Y와 그 지점의 `left(y)`, `right(y)`를 계산한다.
- 요구 간격이 horizontal gap인지 normal gap인지 명시하고 변환식을 기록한다.
- 자식이 직사각형인지, 부모와 같은 각도의 평행사변형인지, 다른 방향의 사선인지 결정한다.

### 3. 자식별 배치 전략을 고른다

- 직사각형 자식은 자식 전체 높이에서 얻은 안전 구간의 교집합으로 reflow한다.
- 평행한 사선 자식은 `parentLeft(childBottom)`과 `parentRight(childTop)`에서 host를 구한다.
- 세로 stack은 공통 X를 재사용하지 않고 각 자식의 실제 Y로 독립 계산한다.
- 크기가 부족하면 uniform scale, reflow, stack, scroll 중 제품 정책을 선택한다. 비균일 path stretch나 무조건 clip은 선택하지 않는다.

### 4. paint·clip·interaction을 같은 path 계열에 연결한다

- fill, outline, hover, splash, focus, image, fog, scrollbar의 path 소유자를 확인한다.
- interactive child의 실제 hit target과 semantics bounds가 visible path 안에 있는지 확인한다.
- shadow는 content clip 바깥 foundation 계층에서 그린다.
- 좌표 변환이 있는 wrapper/FittedBox/Transform을 통과한 뒤의 실제 렌더 좌표도 검사한다.

### 5. 구현과 동시에 회귀 테스트를 만든다

- pure geometry test: top/middle/bottom 경계, rail slope, normal gap, `ΔX = -ΔY / tan(angle)`.
- rendered widget test: 실제 child rect/path 포함, 형제 비중첩, 텍스트·버튼·focus bounds 포함.
- behavior test: callback, hover/tap, focus order, 상태 초기화와 animation이 유지되는지 확인한다.
- small/normal/wide 및 비정수 scale 중 최소 세 조건을 검증한다.

### 6. 완료 판정

- “clip 밖으로 보이지 않는다”만으로 완료 처리하지 않는다.
- 부모와 자식 rail이 수학적으로 평행하고, 각 Y에서 요구 간격이 유지되며, 실제 렌더·hit test가 모두 일치해야 완료다.
- 시각 피드백이 다시 들어오면 가장 먼저 잘못 수정한 계층이 없는지 재검토하고, 숫자 상수 조정 전에 geometry 소유권을 다시 확인한다.

## 이번 작업에서 확인한 실패 유형

1. **잘못된 계층 수정:** 실제 문제는 두 카드의 부모 내 위치였는데 카드 내부 행만 줄였다. 눈에 보이는 자식의 어느 계층이 rail을 위반하는지 먼저 특정해야 한다.
2. **같은 X의 직사각형 슬롯:** 상·하 카드를 각 슬롯의 `Center`에 놓아 부모가 아래로 기울어도 두 카드 중심이 이동하지 않았다.
3. **고정 header inset:** 사선 envelope 안에서 `left: 14`를 사용해 컨트롤이 clip 밖에 놓이고 hit test가 실패했다.
4. **직접 width 축소:** 카드 내부 최소 크기보다 작아져 스킬·장비 행에서 overflow가 발생했다.
5. **clip 성공을 layout 성공으로 오판:** 겉으로 잘리지 않는 것과 부모 rail을 따른 배치는 별개의 조건이다.

## 자식에 맞춰 외곽 section을 줄일 때

- 사선 자식을 감싸는 외곽을 일반적인 `Rect` union으로 만들지 않는다. 직사각형 bounds는 자식의 투명한 사선 모서리까지 폭으로 간주해 특히 우측에 불필요한 공간을 남긴다.
- 서로 평행한 자식들의 왼쪽 rail 상수 `x + y / tan(angle)`와 오른쪽 rail 상수 `x + y / tan(angle)`의 최솟값·최댓값을 구한다. 외곽 rail은 여기에 요구한 **법선 간격**을 `gap / sin(angle)`로 환산해 확장한다.
- 외곽 top/bottom은 첫 자식 top과 마지막 자식 bottom에 수직 간격을 더해 정한다. 콘텐츠가 이미 그 높이를 모두 사용하면 억지로 더 줄이지 않는다.
- 인접 section과의 seam을 유지해야 하면 새 외곽의 크기만 줄이고 기준 rail은 고정한다. 이번 조건 section은 기존 full-height 왼쪽 rail 상수를 유지해 필터와의 24px 간격을 보존했다.
- paint/clip은 축소된 local path를 사용하되, animation과 상위 layout이 기대하는 host bounds는 그대로 둘 수 있다. 이 경우 실제 foundation만 `Positioned`로 축소하여 형제 배치나 퇴장 벡터 계약을 바꾸지 않는다.
- 회귀 테스트는 외곽 폭/높이뿐 아니라 상·하 수직 여백, 좌·우 법선 여백, 기준 rail 고정, 내부 위젯 간 gap을 각각 수치로 검사한다.

[@condition-section] [@preset-card] [@condition-tests] [@preset-tests]
