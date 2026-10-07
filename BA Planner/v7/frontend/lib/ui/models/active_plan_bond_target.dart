// 학생 탭 인연 게이지의 목표(→N) 조회 (FE3-b, FD-003·FD-049·FD-050).
//
// 목표의 출처는 활성 계획 문서(PlanningDocument)에서 그 학생 단계 목표의 `bond_rank`다.
// 활성 계획 문서 저장(FB-1)이 아직 없으므로 지금은 이 파일이 유일한 조회 경계다.
// - 서비스가 [ActivePlanDocumentSource]를 구현하면 그 문서를 쓴다(golden fixture가 쓴다).
// - 그 밖에는 문서가 없다(null). goals v1(`RepositoryGoalState`)은 `target_bond_rank`를 받지 않으므로
//   거기서 인연 목표를 만들지 않는다. 없는 값을 현재값이나 0으로 채우지 않는다.
// FB-1에서 repository의 활성 계획 문서 조회가 생기면 [loadStudentActivePlanDocument]만 바꾼다.
import '../../services/app_service.dart';
import 'planning_models.dart';

/// 활성 계획 문서를 줄 수 있는 서비스(FB-1 전 임시 경계).
abstract interface class ActivePlanDocumentSource {
  /// [profileId] 계정의 활성 계획 문서. 없으면 null.
  Future<PlanningDocument?> loadActivePlanDocument(String profileId);
}

/// 학생 탭이 쓰는 활성 계획 문서. 조회할 곳이 없거나 실패하면 null(목표 없음).
Future<PlanningDocument?> loadStudentActivePlanDocument(
  AppService service,
  String profileId,
) async {
  if (service case final ActivePlanDocumentSource source) {
    try {
      return await source.loadActivePlanDocument(profileId);
    } on Object {
      return null;
    }
  }
  return null;
}

/// [plan]에서 [studentId] 학생의 인연 목표. 그 학생 단계가 여러 개면 문서 순서상 마지막(최종)
/// 단계의 `bond_rank`를 쓴다(FD-050). 단계가 없으면 null.
int? activePlanBondTarget(PlanningDocument? plan, String? studentId) {
  if (plan == null || studentId == null) return null;
  int? target;
  for (final stage in plan.stages) {
    if (stage.studentId != studentId) continue;
    target = stage.targets['bond_rank'];
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
