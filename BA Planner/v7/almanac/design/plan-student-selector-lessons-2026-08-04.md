---
title: "계획 메인 학생 선택 패널 구현·피드백·시행착오 기록"
summary: "seed 없는 계획 시작을 위한 학생 선택 패널의 요구 결정, 대각선 간격과 중첩 컨테이너 보정, 필터 구조, 안개·테두리·그림자, 진입·퇴장 전환, 호감도 게이지 방향 수정에서 얻은 재발 방지 규칙을 기록합니다."
topics: [design, flutter, planning, diagonal-layout, testing]
sources:
  - id: plan-student-selector
    type: file
    path: frontend/lib/ui/widgets/plan_student_selector.dart
  - id: plan-section-layout
    type: file
    path: frontend/lib/ui/widgets/plan_section_layout.dart
  - id: student-section-layout
    type: file
    path: frontend/lib/ui/widgets/student_section_layout.dart
  - id: plan-element-builder
    type: file
    path: frontend/lib/ui/widgets/plan_element_builder.dart
  - id: planning-page-tests
    type: file
    path: frontend/test/planning_page_test.dart
  - id: plan-element-tests
    type: file
    path: frontend/test/plan_element_builder_test.dart
---

# 계획 메인 학생 선택 패널 구현·피드백·시행착오 기록

## 작업 목적과 최종 동작

계획 화면에 외부 `PlanningStudentSeed`가 없어도 계획을 시작할 수 있도록 계획
메인의 Section 1에 학생 선택 진입점을 추가했다. 선택 화면에서는 Section 1을
남겨 두고 중앙과 우측의 기존 섹션을 퇴장시킨 뒤, 네 열 학생 그리드와 필터 패널을
표시한다. 학생을 선택하면 두 패널이 260도 방향으로 완전히 퇴장한 다음 선택한
학생의 계획 요소 추가 화면을 연다.

최종 구현 경계는 다음과 같다.

- `frontend/lib/ui/widgets/plan_student_selector.dart`가 학생 목록 로드, 검색,
  필터, 네 열 그리드, 두 패널의 표면과 독립 모션을 소유한다.
  [@plan-student-selector]
- `frontend/lib/ui/widgets/plan_section_layout.dart`가 Section 1 유지, 기존 섹션
  퇴장·복귀, 선택 패널과 계획 요소 화면 사이의 지연 전환을 소유한다.
  [@plan-section-layout]
- `frontend/lib/ui/widgets/student_section_layout.dart`의 공용 학생 그리드와
  필터 목록을 선택 화면에서도 재사용한다. [@student-section-layout]
- `frontend/lib/ui/widgets/plan_element_builder.dart`는 선택한 학생 seed를 받아
  기존 단계 또는 새 단계를 편집하며, 학생 인디케이터의 호감도 게이지는 아래에서
  위로 채운다. [@plan-element-builder]

## 요구 확인에서 확정된 사항

초기 구현 전에 다음 모호성을 사용자 피드백으로 확정했다.

- 선택 모드에서도 Section 1은 남긴다.
- 기존 중앙·우측 섹션은 즉시 교체하지 않고 먼저 퇴장한다.
- 학생 그리드와 필터 패널은 서로 붙이지 않고 명시적인 간격을 둔다.
- 이미 계획이 있는 학생은 새 계획으로 덮지 않고 기존 단계 편집으로 연다.
- 학생 탭 필터에 계획 전용 `보유 상태`, `계획 상태`만 추가한다.
- 선택 화면을 나가면 검색어와 모든 필터를 초기화한다.
- 검색 입력은 필터 패널의 최상단에 둔다.

초기에는 학생 초상 선택 후 계획 요소 화면에 즉시 진입하는 것으로 결정했지만,
시각 검토 뒤 “선택 패널의 퇴장이 먼저 보여야 한다”는 요구로 갱신되었다. 최신
피드백이 이전 전환 규칙을 대체하며, 현재 계약은 `선택 -> 두 패널 outro 완료 ->
계획 요소 화면 mount`이다.

## 피드백별 시행착오와 최종 규칙

### 1. 스크롤 효과가 패널 밖으로 튀어나옴

- **증상:** 학생 그리드의 스크롤바와 안개 효과가 외곽 사선 패널 경계를 넘어
  보였다.
- **불충분했던 접근:** 그리드를 외곽 `SectionTemplateSurface`에 바로 넣고
  외곽 패널의 clip만으로 모든 자식 효과가 정리될 것으로 가정했다.
- **원인:** 학생 탭은 외곽 섹션과 실제 스크롤 viewport 사이에 불투명한 내부
  컨테이너를 하나 더 두고 있었다. 선택 화면에는 이 계층이 빠져 있었다.
- **최종 규칙:** 외곽 섹션 안에 별도의 bilateral 내부 컨테이너를 두고 그리드,
  스크롤바, 안개를 그 내부 path로 clip한다. 외곽 섹션은 배치와 그림자를,
  내부 컨테이너는 스크롤 효과의 경계를 담당한다.
- **회귀 검증:** `frontend/test/planning_page_test.dart`는 그리드와 필터 내부
  컨테이너에 각각 `ClipPath`가 존재하는지 확인한다.

### 2. 검색과 초기화 버튼이 평행사변형에서 돌출됨

- **증상:** 직사각형 기준으로 배치한 검색창과 초기화 버튼의 모서리가 높이에 따라
  좁아지는 외곽 사선 경계를 침범했다.
- **불충분했던 접근:** 패널 전체에 동일한 좌우 padding을 적용했다.
- **원인:** bilateral 패널의 사용 가능한 좌우 X는 Y마다 다르므로 하나의 고정
  safe rect가 위·아래 컨트롤을 동시에 설명하지 못한다.
- **최종 규칙:** 각 컨트롤의 세로 중심에서 외곽 path의 수평 구간을 구하고,
  그 구간에 별도의 안전 inset을 적용한다. 필터 구조는 요청대로
  `검색 버튼/컨트롤 -> 필터 스크롤 컴포넌트 -> 초기화 버튼`이며 위·아래 버튼은
  내부 필터 컴포넌트의 자식이 아니다.
- **회귀 검증:** 검색창과 초기화 버튼의 네 모서리가 외곽 path 안에 있는지
  좌표로 확인한다.

### 3. 12px로 설정했는데 실제 간격이 더 멀어 보임

- **증상:** Section 1과 그리드의 사각 bounds 차이를 12px로 설정했지만 화면의
  사선 테두리 사이 간격은 12px보다 컸다.
- **실패한 접근:** 두 위젯의 `Rect.left/right` 차이를 곧바로 시각적 간격으로
  사용했다.
- **원인:** 각 bilateral 패널의 bounds 안에는 80도 cut depth가 포함된다.
  직사각 bounds 사이 간격에는 한쪽 또는 양쪽 cut depth가 추가되어 보였다.
- **최종 규칙:** 하나의 공통 reference Y에서 실제 facing edge의 X를 계산하고
  그 차이를 간격으로 정의한다. 후속 피드백으로 최종 간격은 Section 1↔그리드와
  그리드↔필터 모두 24px이다. 두 bilateral 패널 사이에서는 양쪽 cut depth를
  모두 반영한다.
- **회귀 검증:** 테스트는 bounds 간격이 아니라 reference Y의 실제 edge 간격이
  정확히 24px인지 확인한다.

### 4. 패널 높이만 늘고 내부 구조는 따라오지 않음

- **증상:** 새 두 패널을 Section 1 높이에 맞추는 과정에서 외곽 섹션만 늘어나고
  내부 그리드·필터 구성과 테두리 간격은 이전 높이에 머물 위험이 있었다.
- **최종 규칙:** 두 선택 패널의 top/bottom을 Section 1 path bounds와 동일하게
  만들고, 모든 내부 path와 컨트롤 rect를 실제 `LayoutBuilder` 크기에서 다시
  계산한다. 외곽만 고정 크기로 늘리지 않는다.
- **회귀 검증:** 두 패널의 top/bottom이 Section 1과 같고 내부 컨테이너의
  지정 inset이 유지되는지 함께 검사한다.

### 5. 필터 목록이 내부 테두리에 붙음

- **증상:** 필터 스크롤 컴포넌트와 첫 항목의 왼쪽 면이 사선 컨테이너 테두리에
  붙어 보였다.
- **불충분했던 접근:** 외곽 패널에만 padding을 주고 내부 스크롤 콘텐츠가 그
  여백을 상속할 것으로 기대했다.
- **원인:** filter viewport와 필터 row는 내부 컨테이너의 local 좌표를 사용하며
  외곽 섹션 padding과 독립적이다.
- **최종 규칙:** 외곽 필터 path와 평행한 내부 path 사이에 10px을 두고, 내부
  path와 실제 필터 항목 사이에 추가 12px content inset을 둔다. 직선 좌우
  padding이 아니라 내부 path 자체도 외곽 80도 궤적에서 유도한다.
- **회귀 검증:** 필터 목록의 좌우 bounds가 내부 컨테이너에서 각각 12px 떨어져
  있는지 검사한다.

### 6. 학생 목록 위쪽 여백이 과도함

- **증상:** 학생 카드 첫 행 위에 사용되지 않는 큰 빈 영역이 남았다.
- **원인:** 선택 화면에 필요하지 않은 제목용 상단 band와 중복 padding이 남아
  있었다.
- **최종 규칙:** 선택 전용 그리드에서는 제목 행을 제거하고 내부 컨테이너를 외곽
  섹션 top에서 10px 아래에 바로 시작한다. 학생 탭의 카드 렌더링은 재사용하되
  학생 탭 전체 레이아웃의 상단 chrome까지 복사하지 않는다.

### 7. 필터 안개 색이 내부 표면과 맞지 않음

- **증상:** 필터 스크롤 상·하단 안개가 잘못된 색으로 보여 컨테이너 위에 별도
  띠처럼 드러났다.
- **불충분했던 접근:** 학생 탭에서 사용하던 기본 fog 색을 그대로 재사용했다.
- **원인:** 선택 화면의 내부 필터 컨테이너는 학생 탭의 기본 표면과 다른 불투명
  `#162431`을 사용한다.
- **최종 규칙:** 재사용 가능한 viewport fog가 배경색을 입력받게 하고, 선택
  필터는 실제 내부 컨테이너 색을 전달한다. 안개는 콘텐츠를 가리는 장식이 아니라
  바로 아래 표면으로 자연스럽게 소실되어야 한다.
- **회귀 검증:** 필터 fog의 color가 내부 컨테이너 색과 같은지 검사한다.

### 8. 외곽 테두리와 그림자가 Section 1과 다름

- **증상:** 새 두 패널에는 색상 outline이 보이고 Section 1과 같은 lift가 없었다.
- **불충분했던 접근:** 일반 `SectionTemplateSurface`를 그대로 사용했다.
- **원인:** 일반 template surface의 기본 paint 계약에는 outline이 있지만 계획
  Section 1 foundation은 outline 없이 반투명 fill과 lifted path shadow만 그린다.
- **최종 규칙:** 선택 패널 전용 foundation painter에서 Section 1과 동일한
  `paintLiftedPathShadow -> translucent fill` 순서를 사용하고 외곽 stroke는 그리지
  않는다. 내부 그리드·필터 컨테이너의 경계선은 계층 구분을 위해 유지한다.
- **회귀 검증:** 두 외곽 패널 아래에 `SectionTemplateSurface`가 없고 전용 shadow
  painter가 하나씩 존재하는지 검사한다.

### 9. 하나의 FadeTransition으로는 개별 퇴장과 탭 전환을 보장할 수 없음

- **증상:** 두 패널이 단순 fade로 함께 등장했으며, 다른 탭을 누를 때 명시적인
  260도 퇴장이 보장되지 않았다.
- **실패한 접근:** 선택 화면 전체를 하나의 entrance controller와
  `FadeTransition`으로 감쌌다.
- **원인:** 패널별 모션 상태가 없고 부모 탭의 `active=false`가 controller reverse로
  전달되지 않았다.
- **최종 규칙:** 그리드와 필터가 각각 360ms controller를 소유하고 둘 다
  `intro 80 / outro 260`을 사용한다. 계획 탭의 active 상태를 두 controller에
  전달하며, 탭 비활성화 시 위젯을 유지한 채 reverse한다.
- **회귀 검증:** 두 모션 spec을 각각 검사하고 탭 비활성화 절반 시점에 두 패널이
  좌측·아래쪽으로 실제 이동했는지 확인한다.

### 10. 학생 초상 선택이 퇴장 애니메이션을 잘라냄

- **증상:** 초상을 클릭하면 선택 패널이 즉시 사라지고 계획 요소 화면이 바로
  나타났다.
- **실패한 접근:** 선택 callback에서 `_showStudentSelector=false`와
  `_showElementBuilder=true`를 같은 `setState`에서 처리했다.
- **원인:** 모션 controller를 가진 선택 위젯이 첫 reverse frame 전에 unmount되어
  outro를 재생할 수 없었다. 계획 요소 builder에서 이미 경험한 “애니메이션
  소유자를 먼저 제거한 전환”과 같은 실패 유형이다.
- **최종 규칙:** 선택 callback은 먼저 `_switchingStudentSelector=true`로 만들어
  두 패널에 `active=false`를 전달한다. 360ms outro가 끝난 후에만 선택 화면을
  제거하고 builder를 mount한다. 전환 중 추가 선택 callback은 무시한다.
- **회귀 검증:** 절반 시점에는 선택 패널이 남고 builder가 없어야 하며, 두 패널의
  offset은 260도 방향이어야 한다. settle 후에만 선택한 학생의 builder가 보인다.

### 11. 뒤집힌 호감도 섹션이 채움 방향까지 뒤집음

- **증상:** 계획 요소 추가 화면의 학생 인디케이터에서 호감도 게이지가 위에서
  아래로 찼다. 요구 방향은 아래에서 위이다.
- **원인:** 공용 `StudentBondStatus`의 `inverted` 값이 숫자·삼각형 배치와 게이지
  fill origin을 동시에 결정했다. 레이아웃 방향과 값 증가 방향이 불필요하게
  결합되어 있었다.
- **최종 규칙:** `inverted`는 삼각형과 rank 배치만 결정한다. 별도의
  `fillFromBottom` 계약이 채움 기준점을 결정하며 계획 요소 화면은 이를 명시적으로
  true로 전달한다. 진행률 계산과 색은 변경하지 않는다.
- **회귀 검증:** 계획 요소 화면의 `StudentBondStatus`가 inverted와
  fillFromBottom을 모두 true로 갖는지 확인하고, 40% 진행률의 clip rect가 게이지
  bounds의 하단 40%와 일치하는지 검사한다.

### 12. 필터 패널 너비만 절반으로 축소

- **요구 확인:** 축소 기준은 필터 패널의 왼쪽 끝이다. 그리드와 필터 사이의 실제
  24px 간격, 두 패널의 높이, 필터 내부 세로 구조는 변경하지 않는다.
- **최종 규칙:** 기존 필터가 사용하던 `filterLeft -> viewport 98.5%` 가용 폭을
  계산한 뒤 그 폭에 0.5를 적용한다. `filterLeft`는 그대로 두고 right만 다시
  계산한다. 화면 전체 X 비율을 절반으로 만들면 왼쪽 경계와 24px 간격까지 이동할
  수 있으므로 사용하지 않는다. [@plan-student-selector]
- **회귀 검증:** 필터의 실제 왼쪽 경계와 두 패널 사이 24px 간격이 유지되며,
  렌더링된 필터 너비가 이전 가용 폭의 정확히 50%인지 확인한다.
  [@planning-page-tests]

### 13. 다른 탭에서 돌아오면 선택 창과 계획 메인이 겹침

- **증상:** 학생 선택 창을 연 상태로 다른 탭을 방문했다가 계획 탭으로 돌아오면
  학생 그리드·필터와 계획 메인의 Section 2~5가 함께 진입했다.
- **원인:** 계획 탭의 `_setActive(true)`가 현재 하위 화면 상태를 확인하지 않고
  계획 메인 controller 전체를 0에서 forward했다. 선택 모드 진입 때 Section 2~5를
  퇴장시켰던 상태가 탭 복귀 과정에서 무효화되었다.
- **최종 규칙:** `_showStudentSelector`가 true이면 탭 active 전환은 Section 1
  controller만 정상적으로 reverse/forward한다. Section 2~5 controller는 0에
  고정하고, 그리드·필터 패널은 자신들의 active 입력으로 별도 복귀한다.
  [@plan-section-layout]
- **회귀 검증:** 선택 창에서 탭을 나갔다 돌아온 뒤 그리드와 필터는 offset 0,
  Section 1도 offset 0이어야 한다. Section 2~5는 모두 non-zero off-screen offset을
  유지해야 한다. [@planning-page-tests]

## 반복 작업에서 얻은 공통 원칙

- 대각선 UI의 간격은 사각 bounds가 아니라 같은 Y에서 마주 보는 실제 path edge로
  측정한다.
- 재사용은 카드·필터 같은 기능 컴포넌트를 대상으로 한다. 원본 탭의 여백, 제목,
  surface 색까지 무조건 복사하지 않는다.
- outer section, inner surface, scroll viewport, item content의 네 계층은 각각
  별도의 inset과 clip 책임을 가진다.
- 전환 대상 위젯이 animation controller를 소유하면 부모는 outro 완료 전에 해당
  위젯을 unmount하지 않는다.
- 하나의 boolean으로 레이아웃 반전, 채움 방향, 텍스트 배치처럼 서로 다른 의미를
  함께 제어하지 않는다.
- 시각 피드백으로 계약이 변경되면 과거 요구보다 최신 동작을 우선하고 테스트 이름과
  문서도 함께 갱신한다.
- palette나 숫자 상수만 검사하지 않는다. 실제 path containment, rendered bounds,
  중간 animation frame, fill rect처럼 사용자가 보는 결과를 테스트한다.

## 검증 결과

- 계획 화면과 계획 요소 집중 테스트 84개 통과.
- 전체 Flutter 테스트 318개 통과.
- `flutter analyze` 통과.
- Windows release 빌드 통과.
- `codealmanac validate`와 `git diff --check` 통과.

선택 화면의 기하와 중간 전환 frame은 계획 화면 테스트가, 계획 요소 화면의
호감도 fill rect 계약은 계획 요소 테스트가 각각 고정한다.
[@planning-page-tests] [@plan-element-tests]

### 14. 필터의 수치 범위 조건은 독립된 동반 섹션으로 유지한다

- **요구 계약:** 학생 탭과 계획 학생 선택 화면에서 필터를 열면 바로 오른쪽에 같은 높이의 조건 섹션이 함께 나타난다. 상단 `PlanPresetElementCard`는 이상 조건, 하단 카드는 이하 조건이며 중앙의 세로 교환 아이콘으로 관계를 표시한다. 각 카드 좌상단 체크박스만 조건 활성화를 담당하고 우상단 리셋은 그 카드의 수치만 기본 하한/상한으로 되돌린다.
- **필터 의미:** 활성화된 이상 조건은 학생의 모든 현재 수치가 카드 값 이상인지, 활성화된 이하 조건은 모든 현재 수치가 카드 값 이하인지 검사한다. 두 조건이 활성화되면 양 끝을 포함하는 범위 조건이다.
- **레이아웃 시행착오:** 제한된 슬롯에 맞추려고 카드의 layout width 자체를 줄이면 외곽 크기는 맞지만 내부 스킬·장비 행이 최소 높이 아래로 압축되어 RenderFlex overflow가 발생했다. 안정적인 680px 설계 폭으로 카드를 먼저 layout한 뒤 `FittedBox`로 전체를 비례 축소해야 두 장을 스크롤 없이 안전하게 표시할 수 있다.
- **사선 안전영역 시행착오:** 헤더 위젯을 단순 `left: 14`로 두면 외곽 사선 clip 밖에 놓여 보이지 않거나 클릭되지 않는다. 카드 외곽 path의 헤더 상·하단 수평 교차 구간을 계산하고, 두 구간 모두에 포함되는 inset을 사용한다.
- **상태 수명:** 학생 탭은 필터가 닫힐 때 범위 조건을 초기화한다. 계획 선택 화면은 선택기 전체가 퇴장·dispose되므로 재호출 시 초기 상태로 생성된다. 검색/카탈로그 필터의 기존 수명 계약과 혼합하지 않는다.
- **퇴장 계약:** 계획 선택기의 grid, filter, condition 세 패널 모두 intro 80 / outro 260을 사용하며 탭 비활성화와 학생 선택 handoff에서 함께 reverse된다.
- **회귀 검증:** 두 카드가 한 섹션 안에 있고 Scrollable이 없는지, 중앙 아이콘 순서, 편집·리셋, 포괄적 상·하한 비교, 24px path-edge gap, 학생 탭 닫기/재열기 초기화, 계획 선택기 재호출 초기화, 세 패널의 중간 outro frame을 검사한다.

### 15. 조건 카드의 헤더와 내부 행도 부모 사선 rail을 공유한다

- **증상:** 체크박스와 리셋을 기존 카드 위에 overlay하면 첫 번째 레벨 행과 겹치며, 패널 묶음이 평행사변형의 진행 방향을 따르지 않는 것처럼 보였다.
- **폐기한 접근:** 카드 전체를 더 작게 축소하거나 헤더만 고정 좌표로 위에 얹는 방식. 전자는 편집 컨트롤 가독성을 떨어뜨리고 후자는 사선 안전영역과 내부 행 공간을 침범한다.
- **최종 규칙:** 조건 카드 전용 `PlanPresetElementLayout.condition`은 기존 전체 높이를 유지한 채 헤더 40px을 먼저 예약한다. 필요한 40px은 스킬 레벨 행과 추가 능력치 행을 각각 20px 줄여 확보한다. 이후 모든 행은 새 top에서 기존 80도 rail 계산을 다시 수행하므로 상·하단마다 부모 경계와 같은 진행 방향을 갖는다.
- **검증:** 표준/조건 카드의 전체 높이 동일, 헤더 reserve 40px, 두 대상 행의 각 20px 축소, 모든 행 간격 유지, full-width 행의 80도 left rail 일치, 헤더와 첫 행 비중첩, 체크박스·리셋 네 모서리의 envelope path 포함을 검사한다.

### 16. 내부 사선과 부모 내 배치는 서로 다른 계층의 문제다

- **재발 증상:** 카드 내부 행과 header는 정리됐지만 상·하 카드가 여전히 각 직사각형 슬롯의 같은 X축 중심에 놓였다. 부모 bilateral section은 아래로 갈수록 좌우 rail이 모두 왼쪽으로 이동하므로 하단 카드도 그만큼 왼쪽으로 진행해야 한다.
- **원인:** `Positioned.fromRect(slot) -> Center -> FittedBox`가 각 슬롯의 rectangular center를 사용했다. 부모 path clip은 넘침만 숨겼고 자식 host의 X를 바꾸지 않았다.
- **최종 규칙:** 카드의 uniform scale은 세로 슬롯 높이와 부모의 실제 rail length 한계에서 구한다. 카드 top/bottom의 부모 경계를 각각 계산하고, `left = parentLeft(bottom) + normalInset`, `right = parentRight(top) - normalInset`으로 같은 각도의 child host를 만든다. 상·하 카드는 각자의 Y로 독립 계산한다. 중앙 화살표도 자신의 center Y에서 부모 수평 구간의 중심을 사용한다.
- **검증:** 두 카드 크기는 같고 중심 이동은 `ΔX = -ΔY / tan(80°)`여야 한다. 각 카드의 top-left/top-right/bottom-left/bottom-right rail gap은 12px 이상이어야 하며 실제 렌더링된 카드에서도 같은 중심 이동을 확인한다.
- **일반화 문서:** 부모 경계, normal inset, rectangular reflow, parallel child fitting, clip/hit test, 반응형 검증 기준은 [평행사변형 부모 안의 자식 요소 배치 가이드](diagonal-parent-child-layout-guidelines-2026-08-04.md)에 정리했다.

### 17. 조건 section 외곽은 내부 카드 rail envelope에 맞춘다

- **증상:** 내부 카드 두 장은 부모 사선을 올바르게 따라갔지만, 외곽 section은 필터 동반 영역 전체 폭을 계속 칠해 카드 오른쪽에 큰 빈 공간이 남았다.
- **원인:** 외곽 path가 상위 layout이 제공한 전체 `Size`로 생성되어 내부 카드의 실제 painted envelope와 무관했다. 카드의 사선 bounds를 직사각형으로 합치는 방식도 투명 모서리 때문에 같은 과잉 폭을 만들 수 있다.
- **최종 규칙:** 두 카드의 공통 80도 좌·우 rail 상수를 구하고 12px 법선 여백만큼 외곽 rail을 확장한다. top/bottom도 첫·마지막 카드에서 12px만 남긴다. 축소된 외곽의 왼쪽 rail은 기존 full-height rail에 고정해 필터와의 24px seam은 그대로 유지한다. 상위 host는 animation·형제 layout 계약을 위해 유지하고 실제 foundation과 clip만 최소 envelope로 그린다.
- **세로 예외:** 가용 높이가 카드 두 장과 화살표·간격에 이미 정확히 사용되는 경우 높이는 더 줄이지 않는다. “축소”보다 내부 간격 보존이 우선이다.
- **검증:** 외곽 너비 축소, top anchor, 상·하 12px, 양 rail 법선거리 12px, 카드-화살표 간격, 기준 왼쪽 rail 고정을 pure geometry와 rendered widget 테스트에서 함께 검사한다.

### 18. 학생 탭 필터 section도 현재 너비의 절반으로 줄인다

- **요구 해석:** 학생 탭 Section 5는 이미 원래 Section 2 수평 edge의 1/2 너비였다. 이번 “절반”은 현재 표시 너비를 다시 1/2로 줄이는 것이므로 원래 Section 2 기준 최종 1/4이다.
- **고정 기준:** 필터의 왼쪽 80도 rail과 전체 높이는 바꾸지 않는다. 오른쪽 rail만 왼쪽으로 이동시키므로 Section 1과의 기존 연결 위치가 움직이지 않는다.
- **동반 section:** 범위 조건 section은 축소된 필터의 오른쪽 rail에서 기존 24px seam을 다시 계산한다. 조건 section 자체의 카드 envelope·12px 여백 규칙은 변경하지 않는다.
- **검증:** 상·하 edge가 모두 원래 Section 2 edge의 1/4인지, 필터 내부 컨테이너와 리셋 버튼이 새 path 안에 남는지, 조건 동반 section과의 24px 간격 및 닫기/재열기 동작이 유지되는지 검사한다.
