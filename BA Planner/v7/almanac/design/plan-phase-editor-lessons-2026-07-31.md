---
title: "계획 페이즈 편집기 시행착오와 프리셋 제조 재발 방지"
summary: "계획 탭의 사선 페이즈 편집기를 구현하며 확인한 레이아웃, 입력, 애니메이션, 검증 원칙과 프리셋 제조 섹션에 재사용할 기준입니다."
topics: [planning, flutter, diagonal-layout, phase-editor, preset]
sources:
  - id: plan-section-layout
    type: file
    path: frontend/lib/ui/widgets/plan_section_layout.dart
  - id: plan-phase-editor
    type: file
    path: frontend/lib/ui/widgets/plan_phase_editor.dart
  - id: planning-page
    type: file
    path: frontend/lib/ui/pages/planning_page.dart
---

# 계획 페이즈 편집기 시행착오와 프리셋 제조 재발 방지

## 적용 기준

- 실화면 판단과 좌표 조정은 프로그램 창을 현재 모니터에서 최대화한
  `2560×1392` 기준으로 한다. 작은 창의 상대 비율만 보고 여백·행간·사선 위치를
  확정하지 않는다.
- Studio JSON은 초기 형상과 배치의 기준이지만, 런타임의 실제 bounds와
  constraints가 최종 기준이다. 저장 좌표를 런타임 직사각형에 그대로 대입하지
  않는다.
- 프리셋 제조 섹션은 기존 페이즈 편집기 JSON이나 위젯을 변형해 덮어쓰지 않고,
  별도 Studio 산출물과 별도 상태 모델로 만든다. 현재 계획 메인과 페이즈 편집기의
  실제 경계는 각각 source를 다시 확인한다. [@plan-section-layout]
  [@plan-phase-editor]

## 이번 세션에서 확인한 시행착오

### 1. 내용 구조와 동작 버튼을 동시에 맞추면 레이아웃 원인 분리가 어려웠다

페이즈 편집기에서는 목록 형상을 안정화하는 동안 동작 버튼을 잠시 제외했고,
내용 영역이 확정된 뒤 남는 측면 공간에 버튼을 복원했다. 프리셋 제조 섹션도
먼저 목록·폼·미리보기의 안전 영역과 스크롤을 확정하고, 이후 생성·복제·삭제·저장
버튼을 배치한다.

### 2. 사선 사이 간격을 수평 거리로 계산하면 화면상 간격이 달라졌다

서로 마주 보는 80° 사선의 간격은 x 좌표 차가 아니라 사선에 대한 법선 거리로
측정해야 한다. 계획 탭의 canonical seam과 컨트롤 간격은 12px이며, 프리셋 제조
섹션도 특별한 사유가 없으면 같은 값을 사용한다.

### 3. 큰 section path와 작은 자식 rect의 교집합은 형상을 망가뜨렸다

`AttachedSectionSpec`에서 만든 전체 경로를 작은 반복 항목의 rect와 교차시키면
돌출부가 잘려 평행사변형이 사다리꼴처럼 보였다. 양쪽 사선이 필요한 자식은 자기
bounds 안에서 `height / tan(80°)` 깊이를 계산해 독립적인 bilateral path를
만든다. fill, border, clip, hit test는 같은 경로를 공유한다.

### 4. 투명한 겹침 영역이 포인터 입력을 가로챘다

`Stack` 안의 투명한 section bounds나 장식 painter도 아래 컨트롤의 클릭을 막을
수 있다. 장식 전용 painter는 `IgnorePointer`로 감싸고, 실제 hit target은 보이는
도형 경로와 일치시킨다.

### 5. 플랫폼 scrollbar와 전용 사선 scrollbar가 중복되었다

사선 목록에 전용 scrollbar를 그릴 때는 상속된 플랫폼 scrollbar painting을
명시적으로 끈다. 프리셋 목록·항목 선택 목록도 같은 원칙을 사용한다.

### 6. 드래그 피드백을 고정 폭으로 만들면 원본과 크기가 달랐다

고정 250px 피드백 대신 원본 render object의 실제 폭과 높이를 사용해야 했다.
프리셋의 드래그 정렬, 팝오버, 메뉴도 임의 상수가 아니라 실제 anchor geometry를
기준으로 배치한다.

### 7. 같은 목록 안의 재정렬과 원위치 복원에는 안정 순서가 필요했다

같은 페이즈 안에서 항목을 옮길 때는 source를 제거한 뒤 destination index를
보정해야 한다. 페이즈에서 제거한 항목은 최초 원본 순서로 복원한다. 프리셋
정렬·복제·삭제에도 표시 순서용 안정 키를 별도로 둔다.

### 8. 수학 좌표와 Flutter 화면 좌표의 Y 방향이 반대였다

방향 벡터는 `(cos d, -sin d)`로 변환한다. 따라서 260°는 실제 화면에서
좌하향이다. 완료 전환에서 Section 4가 메인 Section 2 위치로 이동하는 동작은
단순 controller reverse가 아니라 별도 relocation 경로다.

### 9. 인라인 이름 편집은 Enter만 처리해서는 저장이 누락되었다

바깥 클릭과 focus loss에서도 편집을 커밋해야 하며, 중복 focus event에도
멱등이어야 한다. 외부 상태 변경 시 text controller도 동기화한다. 프리셋 이름
편집에도 동일한 규칙을 적용한다.

### 10. 이미지 배경의 비율과 비활성 상태 표현이 쉽게 어긋났다

`square.png`의 252:204 비율은 `contain`으로 보여야 모서리가 잘리지 않는다.
비활성 버튼은 callback만 null로 두지 않고 도형 경로로 clip한 overlay와
tooltip/semantics를 함께 제공한다.

### 11. 병렬 전체 테스트가 실제 Python 프로세스를 두고 경쟁했다

영향 범위 집중 테스트와 실제 프로세스 테스트를 먼저 분리해서 확인하고, 전체
Flutter 회귀의 최종 gate는 `flutter test --concurrency=1`로 실행한다. 병렬 실행
실패를 즉시 제품 회귀로 단정하지 않되, 테스트 격리 문제는 별도 부채로 남긴다.

## 프리셋 제조 섹션에 적용할 결정 순서

1. 프리셋이 절대 목표값인지 단계별 증가량인지 확정한다.
2. 포함 필드, 미지정 필드의 의미, 기본 프리셋 규칙을 확정한다.
3. 전역/프로필별 scope와 영속화 시점을 확정한다.
4. 상태 전이와 취소·저장·삭제 복구 규칙을 문서로 고정한다.
5. 별도 Studio JSON으로 최대화 화면의 geometry를 만든다.
6. 인메모리 vertical slice를 검증한 뒤 승인된 protocol과 repository에 연결한다.

현재 코드에는 계획 프리셋 DTO, versioned protocol, repository 저장 계약이 없다.
따라서 다음 세션은 이 계약을 임의로 발명하지 말고 사용자 결정을 먼저 받아야
한다. 현재 `PlanningPage`의 주입값이 실제 계획 레이아웃에 연결되는지도 구현 전에
다시 확인한다. [@planning-page]

## 2026-07-31 상위 탭 전환과 중첩 편집기 퇴장

상위 `AnimatedSectionStack`가 계획 페이지를 outgoing child로 유지하더라도, 내부
편집기가 상위 탭의 활성 상태를 전달받지 않으면 편집기 section은 제자리에 남은 채
부모 페이지의 가시성만 사라진다. 계획 메인 section controller만 reverse하는 것으로는
중첩된 페이즈 편집 화면의 outro를 대신할 수 없다.

`PlanSectionLayout.active`를 현재 표시 중인 `PlanPhaseEditor.active`까지 전달하고,
편집기는 `didUpdateWidget`에서 다음 규칙으로 네 section controller를 제어한다.

- 활성화: 각 section을 0에서 forward하여 원래 intro 방향으로 진입시킨다.
- 비활성화: 각 section을 1에서 reverse하여 section별 outro 방향으로 퇴장시킨다.
- 자체 취소·완료가 이미 진행 중이면 상위 active 변경이 같은 controller를 다시
  시작하지 않는다.

이 구조에서는 상위 탭 전환이 outgoing 페이지를 보존하는 420ms 구간 안에서 내부
편집기의 360ms outro가 재생된다. 학생 탭을 포함한 incoming 독립 section은 상위
stack의 `onIncomingReady` 이후 활성화되므로, 계획-페이즈 section의 퇴장과 다음 탭
section의 진입 순서도 유지된다. 테스트에서는 비활성화 중간 프레임의 네 motion
offset이 각 section의 180°·260°·0° outro 방향과 일치하는지 검사한다.
[@plan-section-layout] [@plan-phase-editor]
