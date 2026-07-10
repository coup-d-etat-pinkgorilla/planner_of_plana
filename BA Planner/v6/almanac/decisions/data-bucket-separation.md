---
title: "Data Bucket Separation"
summary: "현재 스캔 상태, 정적 메타데이터, 플랜 목표, 계산 결과, 인벤토리 파생값을 서로 다른 의미로 유지합니다."
topics: [data, planning]
sources:
  - id: planner-handoff
    type: file
    path: STUDENT_PLANNER_HANDOFF.md
  - id: planning-model
    type: file
    path: core/planning.py
  - id: planning-calculation
    type: file
    path: core/planning_calc.py
  - id: viewer-model
    type: file
    path: gui/viewer_app_qt.py
---

# Data Bucket Separation

학생·플래너 기능에서는 다음 다섯 종류의 값을 같은 필드나 같은 계산 단계로
합치지 않습니다.

1. 스캔으로 얻은 현재 학생 상태
2. 학생의 정적 분류·성장 메타데이터
3. 사용자가 정한 성장 목표
4. 현재 상태에서 목표까지의 계산 결과
5. 보유 인벤토리와 계산 결과를 결합한 부족량

이 구분은 기존 handoff 문서가 명시한 핵심 불변식입니다. `StudentRecord`는 UI에서
현재 상태와 메타데이터를 함께 보여주는 뷰 모델이지만, 그 편의 때문에 목표나 부족량의
원본 저장소가 되어서는 안 됩니다. [@planner-handoff] [@viewer-model]

`StudentGoal`은 목표만 표현합니다. 비어 있는 목표는 기존 의미대로 현재 값을 유지하는
것으로 취급해야 하며, 스캔 결과를 목표 필드에 복사해 확정값처럼 저장하지 않습니다.
[@planning-model]

`calculate_goal_cost()`와 `calculate_plan_totals()`의 결과는 총 필요량입니다. 보유량을
차감한 부족량이 아닙니다. UI에서 부족량이 필요하면 `required`, `owned`, `shortage`를
별도로 계산하고 표시해야 합니다. [@planning-calculation]

## 변경 판단

- 새 필드가 현재 상태인지, 메타데이터인지, 목표인지 먼저 결정합니다.
- 표시 형식 변경을 이유로 비용 계산식을 수정하지 않습니다.
- 통계는 의도적으로 필터된 학생 집합을 사용하는지 확인합니다.
- 계산 결과를 저장 원본처럼 재사용하지 않습니다.

학생 메타데이터 자체를 바꾸는 경우에는
[Generated Student Metadata](generated-student-metadata)를 함께 따릅니다.
