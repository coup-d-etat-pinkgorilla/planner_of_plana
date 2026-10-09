// 활성 계획 문서 읽기(FE4-h, FB-1b 프런트 연결 메모 1·2).
//
// 계획 화면·계획 만들기 흐름·학생 탭이 같은 경로로 저장 문서를 읽는다.
// - 문서는 `plan.get`(`RepositoryPlanService.loadRepositoryPlan`)이 준다. goals v1에서 문서를 다시 만들지 않는다.
//   빈 문서는 빈 계획이다.
// - `plan.get`과 `state.get`의 revision이 같아야 한 snapshot이다. 다르면 둘 다 다시 읽는다. 이 revision이
//   나중 저장(FE4-e)의 `expectedRevision`이다.
// - `plan.get`을 먼저 부른다. 레거시 프로필 첫 읽기는 goals를 활성 문서로 옮기며 revision을 +1 한다. 그 뒤
//   `state.get`이 같은 revision을 본다.
// 통계·인벤토리는 goals 호환 경로를 그대로 쓴다(FE6·FE7).
import 'package:flutter/foundation.dart' show immutable;

import '../../services/repository_service.dart';
import 'planning_models.dart';

/// revision이 같을 때까지 다시 읽는 최대 횟수(첫 읽기 포함).
const repositoryPlanSnapshotAttempts = 3;

/// 같은 revision에서 읽은 계정 상태와 활성 계획.
@immutable
class RepositoryPlanSnapshot {
  const RepositoryPlanSnapshot({required this.state, required this.plan});

  final RepositoryState state;

  /// 서비스가 활성 계획 문서를 주지 않으면(`RepositoryPlanService`가 아님) null이다.
  final RepositoryPlanState? plan;

  int get revision => state.revision;

  /// 저장된 활성 계획 문서(v2). [plan]이 없으면 null.
  PlanningDocument? get document => plan?.document;
}

/// `plan.get`과 `state.get`이 정해진 횟수 안에 같은 revision을 주지 않았다.
class RepositoryPlanSnapshotMismatch implements Exception {
  const RepositoryPlanSnapshotMismatch({
    required this.planRevision,
    required this.stateRevision,
  });

  final int planRevision;
  final int stateRevision;

  @override
  String toString() =>
      '계획과 계정 상태의 revision이 맞지 않습니다(계획 $planRevision, 계정 $stateRevision).';
}

/// [profileId] 계정의 상태와 활성 계획을 같은 revision으로 읽는다.
Future<RepositoryPlanSnapshot> loadRepositoryPlanSnapshot(
  RepositoryService repository,
  String profileId, {
  int attempts = repositoryPlanSnapshotAttempts,
}) async {
  if (repository case final RepositoryPlanService plans) {
    for (var attempt = 1; ; attempt++) {
      final plan = await plans.loadRepositoryPlan(profileId);
      final state = await repository.loadRepositoryState(profileId);
      if (plan.revision == state.revision) {
        return RepositoryPlanSnapshot(state: state, plan: plan);
      }
      if (attempt >= attempts) {
        throw RepositoryPlanSnapshotMismatch(
          planRevision: plan.revision,
          stateRevision: state.revision,
        );
      }
    }
  }
  return RepositoryPlanSnapshot(
    state: await repository.loadRepositoryState(profileId),
    plan: null,
  );
}

/// 활성 계획 문서에 단계가 있는 학생(PLAN 배지·계획 칩·계산기 "현재 계획에 있음"의 원천).
Set<String> activePlanStudentIds(PlanningDocument? plan) => {
  for (final stage in plan?.stages ?? const <PlanningDocumentStage>[])
    stage.studentId,
};
