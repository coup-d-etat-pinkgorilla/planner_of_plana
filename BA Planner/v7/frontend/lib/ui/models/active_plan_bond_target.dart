// 학생 탭 인연 게이지의 목표(→N) 조회 (FE3-b, FD-003·FD-049·FD-050).
//
// 목표의 출처는 저장된 활성 계획 문서(FE4-h부터 `plan.get`, [loadRepositoryPlanSnapshot])에서 그 학생 단계
// 목표의 `bond_rank`다. 문서 v2의 null은 "목표 없음"이다. 없는 값을 현재값이나 0으로 채우지 않는다.
// goals v1(`RepositoryGoalState`)은 `target_bond_rank`를 받지 않으므로 거기서 인연 목표를 만들지 않는다.
import 'planning_models.dart';

/// [plan]에서 [studentId] 학생의 인연 목표. 그 학생 단계가 여러 개면 문서 순서상 마지막(최종)
/// 단계의 `bond_rank`를 쓴다(FD-050). 마지막 단계가 null(목표 없음)이거나 단계가 없으면 null.
///
/// v2 문서는 한 번 정한 목표를 뒤 단계에서 null로 되돌리지 않으므로 마지막 단계 값이 그 학생의 최종 목표다.
int? activePlanBondTarget(PlanningDocument? plan, String? studentId) {
  if (plan == null || studentId == null) return null;
  int? target;
  for (final stage in plan.stages) {
    if (stage.studentId != studentId) continue;
    target = stage.nullableTargets['bond_rank'];
  }
  return target;
}

/// 게이지에 그릴 목표. 목표가 없거나 현재 랭크 이하이면 null(빗금·점선·→N 숨김, FD-050).
/// 현재 랭크를 모르면(미보유 등) 목표가 1 이상일 때 그린다. 현재 채움은 그리지 않는다.
int? studentBondVisibleTarget({required int? current, required int? target}) {
  if (target == null || target <= 0) return null;
  if (current != null && target <= current) return null;
  return target.clamp(1, 100);
}
