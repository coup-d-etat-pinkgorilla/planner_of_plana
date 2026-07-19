# v6 knowledge baseline

v7 이전 작업은 v6 코드를 폴더 단위로 복제하지 않고 아래 지식 문서를 먼저 읽고
각 수직 슬라이스의 계약을 고정한 뒤 진행합니다.

## 참조 문서

- `../../v6/almanac/architecture/runtime-boundaries.md`: UI, scanner, repository 경계
- `../../v6/almanac/decisions/data-bucket-separation.md`: 데이터 다섯 버킷
- `../../v6/almanac/gotchas/large-module-change-safety.md`: 대형 모듈 이전 절차
- `../../v6/almanac/flows/student-scan.md`: 학생 스캔 상태·검토·저장 흐름
- `../../v6/almanac/flows/inventory-scan.md`: 인벤토리 confidence·scroll 불변식
- `../../v6/STUDENT_PLANNER_HANDOFF.md`: 플래너와 통계의 데이터 의미
- `../../v6/docs/inventory_scan_algorithm.md`: 그리드·상세 fallback 알고리즘
- `../../v6/docs/inventory_sorting.md`: 프로필별 정렬·zero-fill 계약

## 보존할 불변식

1. 현재 스캔 상태, 정적 메타데이터, 사용자 목표, 총 필요량, 인벤토리 부족량을
   서로 다른 필드와 계산 단계로 유지한다.
2. `calculate_goal_cost()`와 `calculate_plan_totals()`은 보유량을 차감하지 않은
   총 필요량을 반환한다.
3. 비어 있는 목표는 현재 값을 유지한다는 의미다.
4. scanner의 낮은 confidence 결과를 확정 저장값으로 승격하지 않는다.
5. repository만 프로필 JSON과 SQLite 병합을 소유한다.
6. 인벤토리 정렬과 프로필 순서는 표시용 정보가 아니라 후보 제한과 zero-fill 계약이다.
7. scanner status 이벤트는 로그 문자열이 아니라 UI와 scanner 사이의 계약이다.

## 첫 이전 분류

| 분류 | 모듈 | 이유 |
| --- | --- | --- |
| 이전 완료 | planning, planning_calc | UI 비의존 계산 수직 슬라이스 |
| 이전 완료 | student_meta API/types/data | 계산과 필터의 정적 데이터 계약 |
| 이전 완료 | equipment_items, skill material map | planning_calc의 직접 의존성 |
| 보류 | repository | scanner DTO와 config/profile storage에 결합 |
| 보류 | scanner/matcher | 캡처·입력·ROI·callback·patch point 결합 |
| 제외 | Qt/QML/QWidget/Tk | Flutter에서 재작성할 presentation/UI orchestration |

`repository` 이전 전에는 scanner 결과 dataclass를 독립 DTO 모듈로 추출하고,
v6 repository의 JSON/SQLite 병합 결과를 fixture로 고정해야 합니다. scanner 이전
전에는 callback, cancellation, status event, template/region asset 계약을 protocol
method와 event schema로 먼저 표현해야 합니다.

