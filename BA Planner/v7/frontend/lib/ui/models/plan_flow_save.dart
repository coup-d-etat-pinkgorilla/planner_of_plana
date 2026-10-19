// 계획 만들기 4단계 저장(FE4-e, 시안 Flow-4-Save, FD-031·FD-067·FD-079·FD-080·FD-088).
//
// - 저장 위치 3지선다([PlanFlowSaveTarget]): 시나리오로 저장 / 활성 계획에 페이즈로 추가 / 활성 계획을 이걸로 바꾸기.
//   A 레일 primary와 C 버튼은 같은 동작이고 글자는 고른 위치를 따른다(FD-079).
// - 저장 직전 상태는 [loadPlanFlowSaveSnapshot]으로 읽는다(FB-1c 연결 메모): `plan.get`·`state.get`이 같은 revision,
//   `scenario.list`의 `current_profile_revision`도 그 revision이어야 한 snapshot이다. 이 revision들이 저장 요청의
//   expected revision이다.
// - 저장하는 문서는 흐름 초안(v2) 그대로다. 페이즈로 추가는 활성 문서 뒤에 초안 페이즈를 붙인 문서
//   ([planFlowMergedPlanDocument])이고, 이걸로 바꾸기는 초안을 `kind=plan`으로 만든 문서다. 계획 화면 작업 문서나
//   정수 편집기 보기(v1 재구성)를 거치지 않으므로 v2 null(목표 없음)이 정수로 바뀌지 않는다.
// - FE4-f1: 저장 3지선다 모두 authoring 전체를 보낸다(시나리오 create/update, 이걸로 바꾸기는 초안 authoring, 페이즈로
//   추가는 활성 authoring과 병합한 것, [planFlowMergedPlanDocument]). 보내기 전에 공용 validator로 만든다.
// - 서비스가 `authoring_required`·`revision_conflict`로 거절하면 초안은 두고 최신 상태를 다시 읽어 알린다. authoring
//   규칙 오류(cycle·lane_order·stage_order 등)는 그 reason과 stage ID를 3단계 카드에 잇고 초안을 지우지 않는다.
// - 같은 요청 키로 다시 보낼 때는 같은 문서·revision·이름이다([PlanFlowSaveController] 보류 요청). 연결이 끊기거나
//   저장소가 바쁘면 그 요청을 그대로 다시 보내고, `idempotency_conflict`에서는 새 키를 저절로 만들지 않는다.
// - 비교 타일은 `compareScenarios(활성, 후보)`다(FD-080). 페이즈로 추가는 후보가 병합 문서다. 충족률은 FD-031 (a).
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/idempotency_keys.dart';
import '../../services/planning_protocol_client.dart'
    show BackendDisconnectedException, BackendRemoteException;
import '../../services/repository_service.dart';
import '../../services/scenario_service.dart';
import 'plan_flow_draft.dart';
import 'planning_models.dart';
import 'repository_plan_snapshot.dart';

/// 4단계 저장 위치(시안 C "어디에 넣으시겠습니까").
enum PlanFlowSaveTarget {
  scenario('시나리오로 저장'),
  appendPhases('활성 계획에 페이즈로 추가'),
  replace('활성 계획을 이걸로 바꾸기');

  const PlanFlowSaveTarget(this.label);

  /// 옵션 제목이자 저장 버튼(C 버튼·A primary) 글자.
  final String label;

  /// 활성 계획을 바꾸는 위치.
  bool get changesActivePlan => this != PlanFlowSaveTarget.scenario;
}

/// 저장 직전에 같은 revision으로 읽은 계정 상태·활성 계획·시나리오 목록.
@immutable
class PlanFlowSaveSnapshot {
  const PlanFlowSaveSnapshot({
    required this.state,
    required this.plan,
    required this.scenarios,
  });

  final RepositoryState state;

  /// 서비스가 활성 계획을 주지 않으면 null(페이즈로 추가·이걸로 바꾸기 불가).
  final RepositoryPlanState? plan;

  /// 서비스가 시나리오 저장소가 아니면 null(시나리오로 저장·이걸로 바꾸기 불가).
  final PlanningScenarioListResult? scenarios;

  /// 계정 revision(`plan.get` revision과 같다). 활성 계획 저장의 expectedRevision이다.
  int get revision => state.revision;

  /// 시나리오 목록 revision. 시나리오 저장·이걸로 바꾸기의 expected(Scenario)Revision이다.
  int? get scenarioRevision => scenarios?.revision;

  PlanningDocument? get activeDocument => plan?.document;

  /// 활성 계획의 페이즈 수(빈 페이즈 포함).
  int get activePhaseCount => activeDocument?.phases.length ?? 0;
}

/// 저장 직전 상태를 읽는다(FB-1c 연결 메모 1).
///
/// [service]가 계정 저장소가 아니면 [fallbackState](흐름을 열 때 읽은 상태)를 쓰고 활성 계획은 없다. 시나리오 목록의
/// `current_profile_revision`이 계정 revision과 다르면 [attempts]번까지 모두 다시 읽는다.
Future<PlanFlowSaveSnapshot> loadPlanFlowSaveSnapshot(
  Object? service, {
  required RepositoryState fallbackState,
  int attempts = repositoryPlanSnapshotAttempts,
}) async {
  final profileId = fallbackState.profileId;
  for (var attempt = 1; ; attempt++) {
    final RepositoryState state;
    final RepositoryPlanState? plan;
    if (service is RepositoryService) {
      final snapshot = await loadRepositoryPlanSnapshot(
        service,
        profileId,
        attempts: attempts,
      );
      state = snapshot.state;
      plan = snapshot.plan;
    } else {
      state = fallbackState;
      plan = null;
    }
    PlanningScenarioListResult? scenarios;
    if (service is PlanningScenarioRepositoryService) {
      scenarios = await service.listScenarios(profileId);
      if (service is RepositoryService &&
          scenarios.currentProfileRevision != state.revision) {
        if (attempt >= attempts) {
          // 시나리오 목록이 본 계정 revision과 계정 상태 revision이 끝내 다르다.
          throw RepositoryPlanSnapshotMismatch(
            planRevision: scenarios.currentProfileRevision,
            stateRevision: state.revision,
          );
        }
        continue;
      }
    }
    return PlanFlowSaveSnapshot(
      state: state,
      plan: plan,
      scenarios: scenarios,
    );
  }
}

/// "페이즈로 추가" 병합에서 함께 올린 활성 계획 "나중에" 단계 목표 한 키(FD-180 (a), FE4-g4).
@immutable
class PlanFlowRaisedTarget {
  const PlanFlowRaisedTarget({
    required this.studentId,
    required this.stageId,
    required this.stageName,
    required this.key,
    required this.before,
    required this.after,
  });

  final String studentId;

  /// 올린 활성 계획 나중에 단계 id(병합에서 바꾸지 않는다).
  final String stageId;
  final String stageName;

  /// 목표 키([planningDocumentTargetKeys]).
  final String key;

  /// 올리기 전 값. null이면 그 키에 목표가 없었다.
  final int? before;

  /// 올린 값(같은 학생 체인에서 바로 앞 단계의 값).
  final int after;

  @override
  bool operator ==(Object other) =>
      other is PlanFlowRaisedTarget &&
      other.studentId == studentId &&
      other.stageId == stageId &&
      other.stageName == stageName &&
      other.key == key &&
      other.before == before &&
      other.after == after;

  @override
  int get hashCode =>
      Object.hash(studentId, stageId, stageName, key, before, after);

  @override
  String toString() =>
      'PlanFlowRaisedTarget($studentId, $stageId, $key, $before→$after)';
}

/// 활성 계획 + 초안 페이즈 병합 결과([planFlowMergedPlanDocument]).
@immutable
class PlanFlowMergedPlan {
  PlanFlowMergedPlan._({
    required this.document,
    required this.authoring,
    required Map<String, String> phaseIds,
    required Map<String, String> stageIds,
    required List<String> regressedStudentIds,
    List<PlanFlowRaisedTarget> raisedTargets = const [],
    this.authoringReason,
  }) : phaseIds = Map.unmodifiable(phaseIds),
       stageIds = Map.unmodifiable(stageIds),
       regressedStudentIds = List.unmodifiable(regressedStudentIds),
       raisedTargets = List.unmodifiable(raisedTargets);

  /// 병합 문서(v2 `kind=plan`). [regressedStudentIds]가 있으면 null이다.
  final PlanningDocument? document;

  /// 병합 authoring(FE4-f1): 활성 authoring 뒤에 초안의 나중에 단계·직접 선행·학생을 붙였다. 공용 validator가
  /// 거절하면 null이고 이유는 [authoringReason]이다.
  final PlanningAuthoring? authoring;

  /// [authoring]을 만들지 못한 validator reason.
  final String? authoringReason;

  /// 초안 페이즈 id → 병합 문서 페이즈 id(활성 페이즈 id와 겹치면 바꾼다).
  final Map<String, String> phaseIds;

  /// 초안 단계 id → 병합 단계 id(활성 문서·활성 나중에 단계 id와 겹치면 바꾼다). 나중에 단계·직접 선행 끝점도
  /// 이 표로 함께 바꾼다.
  final Map<String, String> stageIds;

  /// 초안 목표가 활성 계획의 같은 학생 목표보다 낮아 붙일 수 없는 학생(초안 순서). 문서 규칙상 뒤 단계 목표는 앞
  /// 단계보다 낮을 수 없다. 낮은 값을 몰래 올리거나 버리지 않고 이 위치를 막는다.
  final List<String> regressedStudentIds;

  /// 새 앞 단계(초안 배치 단계)보다 낮거나 비어 있어 그 값까지 올린 활성 계획 나중에 단계 목표(FD-180 (a)). 체인
  /// 순서(활성 authoring `deferred_stages` 순서) · 키 순서([planningDocumentTargetKeys])다. 막혔으면 비어 있다.
  final List<PlanFlowRaisedTarget> raisedTargets;

  /// 함께 올린 나중에 단계 id(처음 나온 순서, 겹치지 않음).
  List<String> get raisedStageIds => [
    ...{for (final raised in raisedTargets) raised.stageId},
  ];

  bool get blocked => document == null || authoring == null;
}

/// 활성 계획 [active] 뒤에 초안 [draft]의 페이즈를 붙인 문서와 authoring(FE4-e 페이즈로 추가, FD-080 비교 후보,
/// FE4-f1 authoring 병합).
///
/// - 문서 id·이름은 [id]·[name](저장할 때는 활성 문서 것)이다. 활성 페이즈·단계는 그대로 두고 그 뒤에 초안 페이즈를
///   칸 순서대로 붙인다. 페이즈·단계 id가 활성 문서(나중에 단계 포함)와 겹치면 `-2`, `-3`…을 붙인다.
/// - 초안 목표는 v2 그대로 옮긴다. 다만 같은 학생이 활성 계획에서 이미 정한 키를 초안이 비워 두었으면(null) 그 앞
///   값을 이어 받는다(문서 규칙: 한 번 정한 목표는 뒤 단계에서 null로 돌아가지 않는다). 활성 계획에서도 정하지 않은
///   키는 null로 남는다.
/// - 초안 값이 활성 값보다 낮으면 그 학생을 [PlanFlowMergedPlan.regressedStudentIds]에 넣고 문서를 만들지 않는다.
/// - FD-180 (a)(FE4-g4): 같은 학생 체인에서 활성 나중에 단계는 초안 배치 단계 뒤에 온다. 앞 단계가 정한 키를 나중에
///   단계가 그보다 낮게 두었거나 비워 두었으면(검증 `target_regression`) 그 키를 앞 값까지 올리고
///   [PlanFlowMergedPlan.raisedTargets]에 남긴다(4단계 · 저장 결과가 알린다 — 몰래 올리지 않는다). 낮추지 않는다.
///   나중에 단계가 여럿이면 체인 순서대로 바로 앞(올린 뒤) 단계 값을 기준으로 한다. 초안 나중에 단계는 올리지 않는다
///   (초안 안 규칙은 2단계 편집기 · 계산기 handoff가 이미 지킨다. 활성 나중에 단계보다 낮으면 지금처럼 막는다).
/// - goal_metadata는 활성 문서 → 활성 authoring → 초안 순서로 먼저 있는 것을 쓴다.
/// - authoring([activeAuthoring], 없으면 활성 문서 기본값): 학생 순서는 활성 뒤에 초안의 새 학생, 같은 학생 체인은
///   활성 배치 → 초안 배치 → 활성 나중에 → 초안 나중에, `deferred_stages`는 활성 것 뒤에 초안 것, 직접 선행은 활성
///   것 뒤에 초안 것(끝점은 [PlanFlowMergedPlan.stageIds]로 바꾼다). 끝점이 빠진 직접 선행도 지우지 않고 보내므로
///   validator가 거절한다.
PlanFlowMergedPlan planFlowMergedPlanDocument({
  required PlanningDocument active,
  required PlanFlowDraft draft,
  required String id,
  required String name,
  PlanningAuthoring? activeAuthoring,
}) {
  final activeBundle =
      activeAuthoring ?? PlanningAuthoring.defaultForDocument(active);
  final candidate = PlanFlowDocumentBoundary.toPlanDocument(
    draft,
    id: id,
    name: name,
  );
  final usedPhaseIds = {for (final phase in active.phases) phase.id};
  final usedStageIds = {
    for (final stage in active.stages) stage.id,
    for (final stage in activeBundle.deferredStages) stage.id,
  };
  String unique(String base, Set<String> used) {
    var value = base;
    for (var suffix = 2; used.contains(value); suffix++) {
      value = '$base-$suffix';
    }
    used.add(value);
    return value;
  }

  final last = <String, Map<String, int?>>{
    for (final stage in active.stages) stage.studentId: stage.nullableTargets,
  };
  final regressed = <String>[];
  Map<String, int?> carried(String studentId, Map<String, int?> source) {
    final previous = last[studentId];
    final targets = <String, int?>{};
    for (final key in planningDocumentTargetKeys) {
      final value = source[key];
      final floor = previous?[key];
      if (floor != null &&
          value != null &&
          value < floor &&
          !regressed.contains(studentId)) {
        regressed.add(studentId);
      }
      targets[key] = value ?? floor;
    }
    last[studentId] = targets;
    return targets;
  }

  final phaseIds = <String, String>{};
  final stageIds = <String, String>{};
  final phases = <PlanningDocumentPhase>[...active.phases];
  for (final phase in candidate.phases) {
    final phaseId = unique(phase.id, usedPhaseIds);
    phaseIds[phase.id] = phaseId;
    final stages = <PlanningDocumentStage>[];
    for (final stage in phase.stages) {
      final stageId = unique(stage.id, usedStageIds);
      stageIds[stage.id] = stageId;
      stages.add(
        PlanningDocumentStage(
          id: stageId,
          studentId: stage.studentId,
          name: stage.name,
          targets: carried(stage.studentId, stage.nullableTargets),
        ),
      );
    }
    phases.add(
      PlanningDocumentPhase(id: phaseId, name: phase.name, stages: stages),
    );
  }
  // 체인 순서: 활성 나중에 단계가 초안 배치 뒤에 온다. 앞 값보다 낮거나 비운 키는 앞 값까지 올린다(FD-180 (a)).
  // 성장 규칙은 다시 돌리지 않는다: 앞 단계와 나중에 단계 모두 규칙을 지키고 규칙이 상한 · 하한 꼴(단조)이라 키마다
  // 큰 값을 고른 결과도 규칙을 지킨다. 초안 나중에 단계는 그 뒤 값을 이어 받는다.
  final raised = <PlanFlowRaisedTarget>[];
  final activeDeferred = <PlanningDocumentStage>[
    for (final stage in activeBundle.deferredStages)
      () {
        final previous = last[stage.studentId];
        final targets = <String, int?>{};
        var changed = false;
        for (final key in planningDocumentTargetKeys) {
          final before = stage.nullableTargets[key];
          final floor = previous?[key];
          if (floor != null && (before == null || before < floor)) {
            targets[key] = floor;
            changed = true;
            raised.add(
              PlanFlowRaisedTarget(
                studentId: stage.studentId,
                stageId: stage.id,
                stageName: stage.name,
                key: key,
                before: before,
                after: floor,
              ),
            );
          } else {
            targets[key] = before;
          }
        }
        last[stage.studentId] = targets;
        return changed
            ? PlanningDocumentStage(
                id: stage.id,
                studentId: stage.studentId,
                name: stage.name,
                targets: targets,
              )
            : stage;
      }(),
  ];
  final deferred = <PlanningDocumentStage>[
    for (final stage in draft.deferredStages)
      () {
        final stageId = unique(stage.id, usedStageIds);
        stageIds[stage.id] = stageId;
        return PlanningDocumentStage(
          id: stageId,
          studentId: stage.studentId,
          name: stage.name,
          targets: carried(stage.studentId, stage.targets),
        );
      }(),
  ];
  if (regressed.isNotEmpty) {
    return PlanFlowMergedPlan._(
      document: null,
      authoring: null,
      phaseIds: phaseIds,
      stageIds: stageIds,
      regressedStudentIds: regressed,
    );
  }
  final mergedStudents = {
    for (final phase in phases)
      for (final stage in phase.stages) stage.studentId,
  };
  final document = PlanningDocument(
    id: id,
    name: name,
    kind: PlanningDocumentKind.plan,
    phases: phases,
    version: 2,
    goalMetadata: {
      ...candidate.goalMetadata,
      for (final entry in activeBundle.goalMetadata.entries)
        if (mergedStudents.contains(entry.key)) entry.key: entry.value,
      ...active.goalMetadata,
    },
  );
  final order = [
    ...activeBundle.studentOrder,
    for (final studentId in draft.studentOrder)
      if (!activeBundle.studentOrder.contains(studentId)) studentId,
  ];
  String mapped(String stageId) => stageIds[stageId] ?? stageId;
  final wire = <String, dynamic>{
    'version': 1,
    'prerequisites': [
      for (final prerequisite in activeBundle.prerequisites)
        prerequisite.toWire(),
      for (final prerequisite in draft.prerequisites)
        {
          'stage_id': mapped(prerequisite.stageId),
          'requires_stage_id': mapped(prerequisite.requiresStageId),
        },
    ],
    'deferred_stages': [
      for (final stage in activeDeferred) stage.toWire(),
      for (final stage in deferred) stage.toWire(),
    ],
    'student_order': order,
    'stage_order_by_student': {
      for (final studentId in order)
        studentId: [
          for (final stage in document.stages)
            if (stage.studentId == studentId) stage.id,
          for (final stage in activeBundle.deferredStages)
            if (stage.studentId == studentId) stage.id,
          for (final stage in deferred)
            if (stage.studentId == studentId) stage.id,
        ],
    },
    'goal_metadata': {
      for (final studentId in order)
        if (!mergedStudents.contains(studentId))
          studentId:
              (activeBundle.goalMetadata[studentId] ??
                      draft.goalMetadata[studentId] ??
                      planFlowDefaultGoalMetadata)
                  .toWire(),
    },
  };
  PlanningAuthoring? authoring;
  String? reason;
  try {
    authoring = PlanningAuthoring.fromWire(wire, document);
  } on PlanningAuthoringFormatException catch (error) {
    reason = error.reason;
  }
  return PlanFlowMergedPlan._(
    document: document,
    authoring: authoring,
    authoringReason: reason,
    phaseIds: phaseIds,
    stageIds: stageIds,
    regressedStudentIds: const [],
    raisedTargets: authoring == null ? const [] : raised,
  );
}

/// 목표 키 이름(나중 단계 올림 알림, FE4-g4). 2단계 편집기 · 3단계 카드 요약과 같은 말이다.
String planFlowTargetKeyLabel(String key) => switch (key) {
  'level' => '레벨',
  'bond_rank' => '인연',
  'student_star' => '성급',
  'weapon_level' => '전용무기 레벨',
  'weapon_star' => '전용무기 성급',
  'ex_skill' => 'EX',
  'skill1' => '기본',
  'skill2' => '강화',
  'skill3' => '서브',
  'equip1_tier' => '장비1 티어',
  'equip2_tier' => '장비2 티어',
  'equip3_tier' => '장비3 티어',
  'equip1_level' => '장비1 레벨',
  'equip2_level' => '장비2 레벨',
  'equip3_level' => '장비3 레벨',
  'equip4_tier' => '애장품',
  'stat_hp' => 'HP',
  'stat_atk' => 'ATK',
  'stat_heal' => 'HEAL',
  _ => key,
};

/// 올린 키 한 개(`레벨 70→80`, 목표가 없던 키는 `EX —→5`, 장비 티어는 `T`를 붙인다).
String planFlowRaisedTargetText(PlanFlowRaisedTarget raised) {
  final tier = const {
    'equip1_tier',
    'equip2_tier',
    'equip3_tier',
  }.contains(raised.key);
  String value(int? number) => number == null
      ? '—'
      : tier
      ? 'T$number'
      : '$number';
  return '${planFlowTargetKeyLabel(raised.key)} '
      '${value(raised.before)}→${value(raised.after)}';
}

/// 나중 단계 올림 알림 제목(4단계 C, FD-180 (a)).
String planFlowRaisedTitle(int stageCount) => '나중 단계 $stageCount개를 함께 올렸습니다';

/// 함께 올린 목표를 단계마다 한 줄로 묶는다(학생 · 단계 · 키 이전→새 값): `호시노 · 나중에 칸 목표 · 레벨 70→80, EX
/// —→5`. 단계 순서는 [raised] 순서(체인 순서)다.
List<String> planFlowRaisedStageLines(
  List<PlanFlowRaisedTarget> raised,
  String Function(String studentId) displayName,
) {
  final byStage = <String, List<PlanFlowRaisedTarget>>{};
  for (final item in raised) {
    byStage.putIfAbsent(item.stageId, () => []).add(item);
  }
  return [
    for (final items in byStage.values)
      '${displayName(items.first.studentId)} · 나중에 칸 ${items.first.stageName} · '
          '${items.map(planFlowRaisedTargetText).join(', ')}',
  ];
}

/// 저장 결과 안내에 붙이는 같은 요약(한 문장). 단계가 [maxLines]개를 넘으면 "외 n개 단계"로 줄인다. 올린 것이 없으면
/// null.
String? planFlowRaisedSummary(
  List<PlanFlowRaisedTarget> raised,
  String Function(String studentId) displayName, {
  int maxLines = 3,
}) {
  if (raised.isEmpty) return null;
  final lines = planFlowRaisedStageLines(raised, displayName);
  final shown = lines.take(maxLines).join(' / ');
  final rest = lines.length - maxLines;
  return '${planFlowRaisedTitle(lines.length)}'
      '($shown${rest > 0 ? ' 외 $rest개 단계' : ''}).';
}

/// 시나리오 편입 결과([planFlowIncorporateScenario], FE4-f2).
@immutable
class PlanFlowIncorporation {
  PlanFlowIncorporation._({
    required this.merged,
    required this.skippedStageCount,
    required List<PlanFlowPrerequisite> droppedPrerequisites,
    required this.addedStageCount,
  }) : droppedPrerequisites = List.unmodifiable(droppedPrerequisites);

  /// 활성 계획 + 편입 단계(문서 · authoring, id 재발급 표 포함).
  final PlanFlowMergedPlan merged;

  /// 활성 계획 목표보다 낮아(퇴행) 뺀 시나리오 단계 수.
  final int skippedStageCount;

  /// 뺀 단계가 끝점이라 함께 뺀 직접 선행(시나리오 id 기준). 편입 안내에 수를 보인다.
  final List<PlanFlowPrerequisite> droppedPrerequisites;

  /// 편입하는 단계 수(칸 + 나중에 칸).
  final int addedStageCount;
}

/// 시나리오([scenarioDocument] + [scenarioAuthoring])를 활성 계획([active] + [activeAuthoring]) 뒤에 편입한다(FE4-f2).
///
/// - 시나리오를 초안으로 연다([PlanFlowDocumentBoundary.fromDocument], v2 nullable 그대로, authoring이 없으면 DTO
///   기본값). 같은 학생 체인(활성 배치 → 시나리오 배치 → 활성 나중에 → 시나리오 나중에)에서 앞 목표보다 낮은 키가 있는
///   시나리오 단계는 뺀다(기존 편입 규칙 "퇴행하는 단계는 제외"). null(목표 없음)은 퇴행이 아니다(앞 값을 이어
///   받는다). 활성 나중에 단계가 시나리오 배치 단계보다 낮거나 그 키를 비워 두면(고칠 수 없는 쪽이 뒤) 그 학생의
///   시나리오 배치 단계를 모두 뺀다.
/// - 뺀 단계를 끝점으로 가진 직접 선행은 [PlanFlowIncorporation.droppedPrerequisites]로 명시해 빼고 수를 알린다. 뺀
///   단계의 목표는 이미 활성 계획 앞 단계가 이루므로(편입 페이즈는 늘 활성 페이즈 뒤) 그 순서 뜻은 남는다. 그 밖의
///   직접 선행은 조용히 지우지 않고 그대로 보낸다(끝점이 없으면 validator가 거절해 편입하지 않는다).
/// - 편입 페이즈 이름은 "시나리오 이름 · 페이즈 이름"이다. 병합·id 재발급(페이즈 · 배치 단계 · 나중에 단계 · 직접 선행
///   양 끝 · stage_order_by_student · student_order)은 [planFlowMergedPlanDocument]가 한다.
PlanFlowIncorporation planFlowIncorporateScenario({
  required PlanningDocument active,
  PlanningAuthoring? activeAuthoring,
  required PlanningDocument scenarioDocument,
  PlanningAuthoring? scenarioAuthoring,
  required String scenarioName,
  required PlanningStudentSeed Function(String studentId) seedFor,
}) {
  final activeBundle =
      activeAuthoring ?? PlanningAuthoring.defaultForDocument(active);
  final source = PlanFlowDocumentBoundary.fromDocument(
    scenarioDocument,
    seedFor: seedFor,
    authoring: scenarioAuthoring,
  );
  final stagesById = {for (final stage in source.stages) stage.id: stage};
  final floors = <String, Map<String, int?>>{
    for (final stage in active.stages) stage.studentId: stage.nullableTargets,
  };
  bool regresses(Map<String, int?> targets, Map<String, int?>? floor) =>
      floor != null &&
      planningDocumentTargetKeys.any((key) {
        final before = floor[key];
        final after = targets[key];
        return before != null && after != null && after < before;
      });
  Map<String, int?> carried(
    Map<String, int?> targets,
    Map<String, int?>? floor,
  ) => {
    for (final key in planningDocumentTargetKeys)
      key: targets[key] ?? floor?[key],
  };
  final skipped = <String>{};
  void visit(String stageId) {
    final stage = stagesById[stageId];
    if (stage == null) return;
    final floor = floors[stage.studentId];
    if (regresses(stage.targets, floor)) {
      skipped.add(stageId);
    } else {
      floors[stage.studentId] = carried(stage.targets, floor);
    }
  }

  for (final phase in source.phases) {
    phase.stageIds.forEach(visit);
  }
  // 체인에서 시나리오 배치 단계 뒤에 활성 나중에 단계가 온다. 활성 나중에 단계(고칠 수 없음)가 남긴 시나리오 배치
  // 목표보다 낮거나 그 키를 비워 두면(validator target_regression) 그 학생의 시나리오 배치 단계를 모두 뺀다.
  for (final stage in activeBundle.deferredStages) {
    final floor = floors[stage.studentId];
    final strict =
        floor != null &&
        planningDocumentTargetKeys.any((key) {
          final before = floor[key];
          final after = stage.nullableTargets[key];
          return before != null && (after == null || after < before);
        });
    if (strict) {
      for (final phase in source.phases) {
        for (final id in phase.stageIds) {
          if (stagesById[id]?.studentId == stage.studentId) skipped.add(id);
        }
      }
    }
    floors[stage.studentId] = stage.nullableTargets;
  }
  source.deferredStageIds.forEach(visit);

  final dropped = [
    for (final prerequisite in source.prerequisites)
      if (skipped.contains(prerequisite.stageId) ||
          skipped.contains(prerequisite.requiresStageId))
        prerequisite,
  ];
  final kept = <String, List<PlanFlowStageDraft>>{
    for (final entry in source.stagesByStudent.entries)
      entry.key: [
        for (final stage in entry.value)
          if (!skipped.contains(stage.id)) stage,
      ],
  };
  final draft = source.copyWith(
    // 편입할 단계가 남은 학생만 활성 계획에 더한다(단계 없는 선택 학생은 편입하지 않는다).
    students: [
      for (final seed in source.students)
        if (kept[seed.studentId]?.isNotEmpty ?? false) seed,
    ],
    stagesByStudent: kept,
    phases: [
      for (final phase in source.phases)
        PlanFlowPhase(
          id: phase.id,
          name: '$scenarioName · ${phase.name}',
          stageIds: [
            for (final id in phase.stageIds)
              if (!skipped.contains(id)) id,
          ],
        ),
    ],
    deferredStageIds: [
      for (final id in source.deferredStageIds)
        if (!skipped.contains(id)) id,
    ],
    prerequisites: [
      for (final prerequisite in source.prerequisites)
        if (!dropped.contains(prerequisite)) prerequisite,
    ],
  );
  final added = draft.stageCount;
  return PlanFlowIncorporation._(
    merged: planFlowMergedPlanDocument(
      active: active,
      draft: draft,
      id: active.id,
      name: active.name,
      activeAuthoring: activeBundle,
    ),
    skippedStageCount: skipped.length,
    droppedPrerequisites: dropped,
    addedStageCount: added,
  );
}

/// FD-031 (a) 계획 충족률: 필요량이 있는 재화마다 min(보유, 필요) / 필요의 평균. 크레딧도 넣는다. 보유를 모르는
/// 재화는 빼고 [unknown]에 센다. 셀 재화가 없으면 [rate]는 null이다.
typedef PlanFlowFulfillment = ({double? rate, int unknown});

/// 비교 응답 `resources[]`에서 [side](`a`·`b`) 쪽 충족률을 계산한다.
PlanFlowFulfillment planFlowFulfillment(
  List<Map<String, dynamic>> resources,
  String side,
) {
  var sum = 0.0;
  var counted = 0;
  var unknown = 0;
  for (final row in resources) {
    final required = row['required_$side'];
    if (required is! int || required <= 0) continue;
    final owned = row['owned'];
    if (owned is! int) {
      unknown += 1;
      continue;
    }
    sum += (owned < required ? owned : required) / required;
    counted += 1;
  }
  return (rate: counted == 0 ? null : sum / counted, unknown: unknown);
}

/// "가장 크게 늘어나는 재화" 한 줄(비교 `resources[]`, 필요량 차이 B − A > 0).
@immutable
class PlanFlowSaveIncrease {
  const PlanFlowSaveIncrease({
    required this.resourceKey,
    required this.name,
    required this.category,
    required this.delta,
    required this.requiredB,
    this.itemId,
    this.owned,
    this.shortageA,
    this.shortageB,
  });

  final String resourceKey;
  final String name;
  final String? itemId;
  final String category;

  /// 늘어나는 필요량(양수).
  final int delta;

  /// 후보의 필요량.
  final int requiredB;

  /// 보유량. 모르면 null.
  final int? owned;

  /// 활성 계획·후보의 부족량(0 이상). 보유를 모르면 null.
  final int? shortageA;
  final int? shortageB;

  /// 후보 기준 보유 / 필요(0~1). 보유를 모르면 null.
  double? get coverage {
    final owned = this.owned;
    if (owned == null || requiredB <= 0) return null;
    return (owned / requiredB).clamp(0.0, 1.0).toDouble();
  }
}

/// 활성 계획(A)과 후보(B)의 비교(`compareScenarios`, FD-080).
@immutable
class PlanFlowSaveComparison {
  PlanFlowSaveComparison({
    required this.fulfillmentA,
    required this.fulfillmentB,
    required this.shortageKindsA,
    required this.shortageKindsB,
    required this.creditsA,
    required this.creditsB,
    required this.studentsA,
    required this.studentsB,
    List<PlanFlowSaveIncrease> increases = const [],
    Map<String, List<PlanFlowStageResource>> phaseResourcesB = const {},
  }) : increases = List.unmodifiable(increases),
       phaseResourcesB = Map.unmodifiable(phaseResourcesB);

  final PlanFlowFulfillment fulfillmentA;
  final PlanFlowFulfillment fulfillmentB;

  /// 아는 부족 재화 종류 수(`known_shortage_type_count_a/b`). 응답에 없으면 null.
  final int? shortageKindsA;
  final int? shortageKindsB;
  final int? creditsA;
  final int? creditsB;

  /// 단계가 있는 학생 수(`students[].presence`).
  final int studentsA;
  final int studentsB;

  /// 필요량이 가장 크게 늘어나는 재화(큰 순, 최대 3).
  final List<PlanFlowSaveIncrease> increases;

  /// 후보 문서의 페이즈 id → 재화(`projection_b.phase_results`).
  final Map<String, List<PlanFlowStageResource>> phaseResourcesB;

  factory PlanFlowSaveComparison.fromResult(
    PlanningScenarioComparisonResult result,
  ) {
    final comparison = result.comparison;
    final rawResources = comparison['resources'];
    final resources = [
      for (final raw in rawResources is List ? rawResources : const <Object?>[])
        if (raw is Map) Map<String, dynamic>.from(raw),
    ];
    int? integer(String key) {
      final value = comparison[key];
      return value is int ? value : null;
    }

    var studentsA = 0;
    var studentsB = 0;
    final rawStudents = comparison['students'];
    for (final raw in rawStudents is List ? rawStudents : const <Object?>[]) {
      if (raw is! Map) continue;
      switch (raw['presence']) {
        case 'both':
          studentsA += 1;
          studentsB += 1;
        case 'a_only':
          studentsA += 1;
        case 'b_only':
          studentsB += 1;
      }
    }
    // 크레딧은 크레딧 KPI에서 필요량 차이로 보이므로(FD-038) 재화 증가 목록에서 뺀다(FE5-c2, FE5-b 발견).
    final increases = <PlanFlowSaveIncrease>[
      for (final row in resources)
        if (row['category']?.toString() != 'credits' &&
            row['resource_key']?.toString() != 'credits')
          if (row['required_delta_b_minus_a'] case final int delta
              when delta > 0)
            PlanFlowSaveIncrease(
              resourceKey:
                  row['resource_key']?.toString() ??
                  row['item_id']?.toString() ??
                  '',
              name:
                  row['display_name']?.toString() ??
                  row['item_id']?.toString() ??
                  '알 수 없는 재화',
              itemId: row['item_id']?.toString(),
              category: row['category']?.toString() ?? 'unresolved',
              delta: delta,
              requiredB: row['required_b'] is int ? row['required_b'] as int : 0,
              owned: row['owned'] is int ? row['owned'] as int : null,
              shortageA: row['shortage_a'] is int
                  ? row['shortage_a'] as int
                  : null,
              shortageB: row['shortage_b'] is int
                  ? row['shortage_b'] as int
                  : null,
            ),
    ]..sort((a, b) => b.delta.compareTo(a.delta));
    return PlanFlowSaveComparison(
      fulfillmentA: planFlowFulfillment(resources, 'a'),
      fulfillmentB: planFlowFulfillment(resources, 'b'),
      shortageKindsA: integer('known_shortage_type_count_a'),
      shortageKindsB: integer('known_shortage_type_count_b'),
      creditsA: integer('credits_a'),
      creditsB: integer('credits_b'),
      studentsA: studentsA,
      studentsB: studentsB,
      increases: increases.take(3).toList(),
      phaseResourcesB: planFlowPhaseResources(
        Map<String, dynamic>.from(result.projectionB),
      ),
    );
  }
}

/// authoring validator reason(FB-8, 백엔드 `planning_authoring.py`와 Dart [PlanningAuthoring.fromWire]가 같다).
const planFlowAuthoringReasons = {
  'invalid_shape',
  'unsupported_version',
  'student_order',
  'stage_set',
  'stage_chain',
  'target_regression',
  'targets',
  'goal_metadata',
  'stage_reference',
  'self_reference',
  'same_student_prerequisite',
  'duplicate_prerequisite',
  'cycle',
  'lane_order',
  'stage_order',
};

/// 저장 실패 코드. 백엔드 오류 코드, mock `StateError` 메시지, 연결 끊김(`disconnected`)·시간 초과(`timeout`).
/// `invalid_payload` + `reason: authoring_required`는 `authoring_required`로 읽는다(FB-8a). authoring 규칙 오류
/// (`invalid_payload` + validator reason, 또는 보내기 전 [PlanningAuthoringFormatException])는 `invalid_authoring`이다.
String planFlowSaveErrorCode(Object error) => switch (error) {
  BackendRemoteException(code: 'invalid_payload', :final details?)
      when details['reason'] == 'authoring_required' =>
    'authoring_required',
  BackendRemoteException(code: 'invalid_payload', :final details?)
      when planFlowAuthoringReasons.contains(details['reason']) =>
    'invalid_authoring',
  BackendRemoteException(:final code) => code,
  BackendDisconnectedException() => 'disconnected',
  TimeoutException() => 'timeout',
  StateError(:final message) => message,
  PlanningAuthoringFormatException() => 'invalid_authoring',
  _ => 'unknown',
};

/// authoring 오류의 reason과 카드(stage ID). 백엔드 오류는 `details`(`reason`, `stage_id`, `requires_stage_id`)에서,
/// 보내기 전 오류는 예외의 reason에서 읽는다. reason을 모르면 null.
({String reason, List<String> stageIds})? planFlowAuthoringErrorOf(
  Object error,
) => switch (error) {
  BackendRemoteException(:final details?)
      when planFlowAuthoringReasons.contains(details['reason']) =>
    (
      reason: details['reason'] as String,
      stageIds: [
        for (final key in const ['stage_id', 'requires_stage_id'])
          if (details[key] case final String id) id,
      ],
    ),
  PlanningAuthoringFormatException(:final reason) => (
    reason: reason,
    stageIds: const <String>[],
  ),
  _ => null,
};

/// authoring reason 설명(~습니다체 문장 안에 넣는 말).
String planFlowAuthoringReasonText(String reason) => switch (reason) {
  'cycle' => '선행 조건이 돌고 돌아 이어집니다',
  'lane_order' => '먼저 끝나야 하는 단계가 뒤 칸에 있습니다',
  'stage_order' => '같은 칸에서 먼저 끝나야 하는 단계가 뒤에 있습니다',
  'self_reference' => '단계를 자기 자신의 선행 단계로 이었습니다',
  'same_student_prerequisite' => '같은 학생 단계를 직접 이었습니다',
  'duplicate_prerequisite' => '같은 선행 조건이 두 번 있습니다',
  'stage_reference' => '없어진 단계를 가리키는 선행 조건이 있습니다',
  'target_regression' => '뒤 단계 목표가 앞 단계보다 낮습니다',
  'stage_chain' => '같은 학생 단계 순서가 칸 배치와 맞지 않습니다',
  _ => '나중에 칸·선행 조건 정보 모양이 맞지 않습니다',
};

/// 같은 요청(같은 키·같은 내용)을 다시 보내면 되는 실패.
const planFlowSaveRetryableCodes = {
  'timeout',
  'disconnected',
  'repository_busy',
  'persistence_failed',
};

/// 초안은 두고 최신 상태를 다시 읽어야 하는 실패.
const planFlowSaveRereadCodes = {'revision_conflict', 'authoring_required'};

bool _retryable(Object error, String code) =>
    planFlowSaveRetryableCodes.contains(code) ||
    (error is BackendRemoteException && error.retryable);

/// 저장 실패 안내(~습니다체).
String planFlowSaveErrorMessage(String code) => switch (code) {
  'revision_conflict' =>
    '저장하는 사이에 계획이나 시나리오가 바뀌어 저장하지 않았습니다. 최신 상태를 다시 읽었습니다. '
        '만든 초안은 그대로이니 비교를 확인하고 다시 저장해 주십시오.',
  'authoring_required' =>
    '활성 계획의 페이즈 편집 정보를 새 페이즈에 맞출 수 없어 저장하지 않았습니다. 최신 상태를 다시 읽었습니다. '
        '"활성 계획을 이걸로 바꾸기"나 "시나리오로 저장"을 고를 수 있습니다.',
  'invalid_authoring' =>
    '나중에 칸·선행 조건 정보가 규칙에 맞지 않아 저장하지 않았습니다. 3단계에서 표시한 카드를 고쳐 주십시오. '
        '만든 초안은 그대로입니다.',
  'idempotency_conflict' =>
    '같은 저장 요청 키가 다른 내용에 이미 쓰였습니다. "다시 읽기"로 최신 상태를 읽은 뒤 다시 저장해 주십시오.',
  'timeout' ||
  'disconnected' ||
  'repository_busy' ||
  'persistence_failed' =>
    '연결이 끊기거나 저장소가 바빠 저장을 마치지 못했습니다. 다시 누르면 같은 요청을 그대로 보냅니다.',
  _ => '저장하지 못했습니다($code).',
};

/// authoring 규칙 오류 안내(reason 설명 포함).
String planFlowAuthoringErrorMessage(String reason) =>
    '나중에 칸·선행 조건 정보가 규칙에 맞지 않아 저장하지 않았습니다(${planFlowAuthoringReasonText(reason)}). '
    '3단계에서 표시한 카드를 고쳐 주십시오. 만든 초안은 그대로입니다.';

/// 저장을 마친 결과(계획 화면이 다시 읽기·시나리오 보기 이동에 쓴다).
@immutable
class PlanFlowSaveOutcome {
  const PlanFlowSaveOutcome({
    required this.target,
    required this.message,
    required this.openScenarioList,
    this.archivedScenarioId,
  });

  final PlanFlowSaveTarget target;

  /// 저장 알림 글자.
  final String message;

  /// "저장한 뒤 · 시나리오 보기로 이동".
  final bool openScenarioList;

  /// 이걸로 바꾸기에서 기존 활성 계획을 옮겨 둔 시나리오. 옮길 것이 없었으면 null.
  final String? archivedScenarioId;

  bool get changedActivePlan => target.changesActivePlan;
}

/// 보낸(또는 보낼) 저장 요청. 다시 보낼 때 같은 키·같은 내용을 쓴다.
@immutable
class PlanFlowSaveRequest {
  const PlanFlowSaveRequest({
    required this.target,
    required this.draft,
    required this.profileId,
    required this.idempotencyKey,
    required this.document,
    required this.expectedRevision,
    required this.name,
    this.authoring,
    this.expectedScenarioRevision,
    this.baseProfileRevision,
    this.scenarioId,
    this.description = '',
    this.raisedTargets = const [],
  });

  final PlanFlowSaveTarget target;

  /// 요청을 만든 초안(같은 객체일 때만 다시 쓴다).
  final PlanFlowDraft draft;
  final String profileId;
  final String idempotencyKey;

  /// 보내는 문서(v2). 시나리오는 `kind=scenario`, 활성 계획은 `kind=plan`.
  final PlanningDocument document;

  /// 문서와 함께 보내는 authoring 전체(FE4-f1). 공용 validator로 만든 것이다.
  final PlanningAuthoring? authoring;

  /// 시나리오: 목록 revision. 활성 계획: 계정 revision.
  final int expectedRevision;

  /// 시나리오 고치기: 그 시나리오 revision. 이걸로 바꾸기: 시나리오 목록 revision.
  final int? expectedScenarioRevision;

  /// 시나리오 저장의 기준 계정 revision.
  final int? baseProfileRevision;

  /// 고치는 시나리오 id(새로 만들면 null).
  final String? scenarioId;

  /// 시나리오 이름 또는 옮겨 둘 기존 계획 이름(이걸로 바꾸기). 페이즈로 추가는 활성 문서 이름.
  final String name;
  final String description;

  /// 페이즈로 추가에서 함께 올린 나중에 단계 목표(FD-180 (a)). 저장 결과 안내가 같은 요약을 붙인다.
  final List<PlanFlowRaisedTarget> raisedTargets;
}

/// 4단계 저장 상태: 위치 선택, 이름·저장한 뒤 토글, 저장 직전 상태와 비교, 보류 요청.
///
/// [flow]를 듣는다. 초안이 바뀌면 비교와 보류 요청을 버린다. 4단계에 들어오면 저장 직전 상태를 읽는다.
class PlanFlowSaveController extends ChangeNotifier {
  PlanFlowSaveController({required this.flow, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      _draft = flow.draft,
      _step = flow.step {
    flow.addListener(_flowChanged);
    if (flow.step == PlanFlowStep.save) unawaited(reload());
  }

  final PlanFlowController flow;
  final DateTime Function() _clock;

  Object? get service => flow.service;

  PlanFlowDraft _draft;
  PlanFlowStep _step;
  // 활성 계획을 고치는 흐름(FE4-f2)은 "이걸로 바꾸기"를 먼저 고른다. 시나리오 "계획에 적용…"(FE5-c1)은 고른 위치로
  // 연다. 그 위치를 쓸 수 없으면 [unavailableReason]이 안내하고 [canSave]가 막는다(다른 위치를 고를 수 있다).
  late PlanFlowSaveTarget _target =
      flow.initialSaveTarget ??
      (_editingActivePlan
          ? PlanFlowSaveTarget.replace
          : PlanFlowSaveTarget.scenario);
  String? _scenarioName;
  String? _archiveName;
  bool _openScenarioList = true;
  bool _keepOrderEditable = true;

  PlanFlowSaveSnapshot? _snapshot;
  bool _loading = false;
  Object? _loadError;
  int _loadNumber = 0;
  int _loadCount = 0;
  int? _editingRevision;
  int? _editingCollectionRevision;
  int? _editingPlanRevision;

  /// 활성 계획을 고치는 흐름에서 `revision_conflict` 뒤 다시 읽었다. 그때만 expected revision을 최신으로 옮긴다.
  bool _acceptLatestPlanRevision = false;

  bool get _editingActivePlan =>
      flow.purpose == PlanFlowPurpose.editActivePlan;

  PlanFlowMergedPlan? _merged;
  final Map<bool, PlanFlowSaveComparison> _comparisons = {};
  final Map<bool, Object> _comparisonErrors = {};
  final Set<bool> _comparing = {};
  int _compareNumber = 0;

  PlanFlowSaveRequest? _pending;
  bool _saving = false;
  String? _message;
  bool _messageIsError = false;
  bool _disposed = false;

  PlanFlowSaveTarget get target => _target;
  bool get openScenarioList => _openScenarioList;
  bool get keepOrderEditable => _keepOrderEditable;
  PlanFlowSaveSnapshot? get snapshot => _snapshot;
  bool get loading => _loading;
  Object? get loadError => _loadError;
  bool get saving => _saving;

  /// 마지막 안내(저장 실패·다시 읽음). 없으면 null.
  String? get message => _message;
  bool get messageIsError => _messageIsError;

  /// 보류 중인 요청(다시 보내면 같은 키·같은 내용). 테스트·진단용.
  PlanFlowSaveRequest? get pendingRequest => _pending;

  /// 시나리오 이름 입력값(저장 직전 상태를 읽기 전에는 빈 글자).
  String get scenarioName => _scenarioName ?? '';

  /// 이걸로 바꾸기에서 옮겨 둘 기존 활성 계획 이름.
  String get archiveName =>
      _archiveName ??
      (_editingActivePlan
          ? planFlowEditedArchiveName
          : planFlowDefaultArchiveName);

  /// 병합 결과(페이즈로 추가). 활성 계획을 아직 읽지 못했으면 null.
  PlanFlowMergedPlan? get merged {
    final active = _snapshot?.activeDocument;
    if (active == null) return null;
    return _merged ??= planFlowMergedPlanDocument(
      active: active,
      draft: _draft,
      id: active.id,
      name: active.name,
      activeAuthoring: _snapshot?.plan?.authoring,
    );
  }

  /// "페이즈로 추가"를 고르고 붙일 수 있을 때 함께 올리는 나중에 단계 목표(FD-180 (a)). 4단계 C가 알린다. 그 밖에는
  /// 비어 있다.
  List<PlanFlowRaisedTarget> get raisedTargets {
    if (_target != PlanFlowSaveTarget.appendPhases) return const [];
    final merged = this.merged;
    if (merged == null || merged.blocked) return const [];
    return merged.raisedTargets;
  }

  /// 지금 위치의 비교(페이즈로 추가는 병합 문서 기준). 아직 없으면 null.
  PlanFlowSaveComparison? get comparison =>
      _comparisons[_target == PlanFlowSaveTarget.appendPhases];

  bool get comparing =>
      _comparing.contains(_target == PlanFlowSaveTarget.appendPhases);

  Object? get comparisonError =>
      _comparisonErrors[_target == PlanFlowSaveTarget.appendPhases];

  /// [target]을 고를 수 없는 이유. 고를 수 있으면 null.
  String? unavailableReason(PlanFlowSaveTarget target) {
    final snapshot = _snapshot;
    switch (target) {
      case PlanFlowSaveTarget.scenario:
        if (service is! PlanningScenarioRepositoryService) {
          return '시나리오 저장소를 쓸 수 없습니다';
        }
        if (snapshot != null && snapshot.scenarios == null) {
          return '시나리오 목록을 읽지 못했습니다';
        }
        return null;
      case PlanFlowSaveTarget.appendPhases:
        if (service is! RepositoryPlanService) {
          return '활성 계획 저장소를 쓸 수 없습니다';
        }
        if (_editingActivePlan) {
          return '활성 계획을 고치는 중이라 페이즈로 붙이지 않습니다';
        }
        if (snapshot == null) return null;
        if (snapshot.plan == null) return '활성 계획을 읽지 못했습니다';
        final merged = this.merged;
        if (merged != null &&
            merged.document != null &&
            merged.authoring == null) {
          return '활성 계획의 나중에 칸·선행 조건과 맞출 수 없어 붙일 수 없습니다'
              '(${planFlowAuthoringReasonText(merged.authoringReason ?? '')})';
        }
        if (merged != null && merged.blocked) {
          final names = [
            for (final id in merged.regressedStudentIds)
              flow.context.displayName(id),
          ];
          final who = names.length == 1
              ? names.single
              : '${names.first} 외 ${names.length - 1}명';
          return '$who의 목표가 활성 계획보다 낮아 붙일 수 없습니다';
        }
        return null;
      case PlanFlowSaveTarget.replace:
        if (service is! RepositoryPlanService ||
            service is! PlanningScenarioRepositoryService) {
          return '활성 계획 저장소를 쓸 수 없습니다';
        }
        if (snapshot == null) return null;
        if (snapshot.plan == null) return '활성 계획을 읽지 못했습니다';
        if (snapshot.scenarios == null) return '시나리오 목록을 읽지 못했습니다';
        return null;
    }
  }

  bool isAvailable(PlanFlowSaveTarget target) =>
      unavailableReason(target) == null;

  /// 저장 버튼(C 버튼·A primary)을 누를 수 있다.
  bool get canSave {
    if (_saving || _loading || _snapshot == null) return false;
    if (!flow.orderReady || !isAvailable(_target)) return false;
    return switch (_target) {
      PlanFlowSaveTarget.scenario => scenarioName.trim().isNotEmpty,
      PlanFlowSaveTarget.appendPhases => merged?.blocked == false,
      PlanFlowSaveTarget.replace =>
        archiveName.trim().isNotEmpty || _snapshot?.activePhaseCount == 0,
    };
  }

  void selectTarget(PlanFlowSaveTarget target) {
    if (_disposed || _saving || target == _target || !isAvailable(target)) {
      return;
    }
    _target = target;
    _message = null;
    notifyListeners();
  }

  set scenarioName(String value) {
    if (_disposed || value == _scenarioName) return;
    _scenarioName = value;
    notifyListeners();
  }

  set archiveName(String value) {
    if (_disposed || value == _archiveName) return;
    _archiveName = value;
    notifyListeners();
  }

  set openScenarioList(bool value) {
    if (_disposed || value == _openScenarioList) return;
    _openScenarioList = value;
    notifyListeners();
  }

  /// "단계 순서는 페이즈 편집에서 다시 바꿀 수 있게 유지". 상태만 둔다. FE4-f1부터 authoring은 늘 보낸다(나중에 칸·
  /// 직접 선행을 잃지 않게). 끄면 무엇을 덜 보낼지는 정하지 않았다.
  set keepOrderEditable(bool value) {
    if (_disposed || value == _keepOrderEditable) return;
    _keepOrderEditable = value;
    notifyListeners();
  }

  void _flowChanged() {
    if (_disposed) return;
    final entered =
        flow.step == PlanFlowStep.save && _step != PlanFlowStep.save;
    _step = flow.step;
    if (!identical(flow.draft, _draft)) {
      _draft = flow.draft;
      _merged = null;
      _comparisons.clear();
      _comparisonErrors.clear();
      // 이전 초안으로 하던 비교 응답은 버린다.
      _compareNumber += 1;
      _comparing.clear();
      _pending = null;
      if (!entered && _snapshot != null && flow.step == PlanFlowStep.save) {
        unawaited(_compareAll());
      }
      notifyListeners();
    }
    // 4단계에 들어올 때마다 저장 직전 상태를 새로 읽는다(FB-1c).
    if (entered) unawaited(reload());
  }

  /// 저장 직전 상태를 (다시) 읽고 비교한다. 보류 요청을 버린다. 초안·이름·토글은 그대로다.
  Future<void> reload({String? message}) async {
    if (_disposed) return;
    final number = ++_loadNumber;
    _loading = true;
    _loadError = null;
    _pending = null;
    _message = message;
    _messageIsError = message != null;
    notifyListeners();
    try {
      final snapshot = await loadPlanFlowSaveSnapshot(
        service,
        fallbackState: flow.context.repositoryState,
      );
      if (_disposed || number != _loadNumber) return;
      _loadCount += 1;
      _snapshot = snapshot;
      _merged = null;
      _comparisons.clear();
      _comparisonErrors.clear();
      _compareNumber += 1;
      _comparing.clear();
      final editing = flow.scenario;
      if (editing != null) {
        // 처음에는 연 시나리오의 revision을 지킨다. 충돌 뒤 다시 읽으면 목록의 최신 revision을 쓴다.
        final latest = snapshot.scenarios?.scenarios
            .where((summary) => summary.id == editing.id)
            .firstOrNull;
        _editingRevision = _loadCount == 1 || latest == null
            ? (_editingRevision ?? editing.revision)
            : latest.revision;
        // 목록 revision도 처음에는 편집을 열 때 읽은 값을 쓴다(그 뒤 바뀐 목록을 놓치지 않는다).
        _editingCollectionRevision = _loadCount == 1
            ? (flow.scenarioCollectionRevision ?? snapshot.scenarioRevision)
            : snapshot.scenarioRevision;
      }
      if (_editingActivePlan) {
        // 처음에는 초안을 연 활성 계획 revision을 지킨다(그 사이 바뀌었으면 충돌로 알린다). 충돌을 알리고 다시 읽은
        // 뒤에만 최신으로 옮긴다(3단계에 다녀오는 재읽기로는 옮기지 않는다).
        if (_editingPlanRevision == null) {
          _editingPlanRevision = flow.activePlanRevision ?? snapshot.revision;
        } else if (_acceptLatestPlanRevision) {
          _editingPlanRevision = snapshot.revision;
          _acceptLatestPlanRevision = false;
        }
      }
      _scenarioName ??=
          editing?.name ??
          '새 시나리오 ${(snapshot.scenarios?.scenarios.length ?? 0) + 1}';
      if (!isAvailable(_target)) {
        _target = PlanFlowSaveTarget.values.firstWhere(
          isAvailable,
          orElse: () => _target,
        );
      }
    } on Object catch (error) {
      if (_disposed || number != _loadNumber) return;
      _loadError = error;
    } finally {
      if (!_disposed && number == _loadNumber) {
        _loading = false;
        notifyListeners();
      }
    }
    if (!_disposed && number == _loadNumber && _snapshot != null) {
      await _compareAll();
    }
  }

  Future<void> _compareAll() async {
    final snapshot = _snapshot;
    final active = snapshot?.activeDocument;
    final comparer = service;
    if (snapshot == null ||
        active == null ||
        comparer is! PlanningScenarioComparisonService) {
      return;
    }
    final draft = _draft;
    if (!flow.orderReady) return;
    final number = ++_compareNumber;
    _comparing.clear();
    final stamp = _clock().microsecondsSinceEpoch;
    final candidates = <bool, PlanningDocument>{
      false: PlanFlowDocumentBoundary.toPlanDocument(
        draft,
        id: 'plan-flow-compare-draft-$stamp',
        name: '계획 만들기 초안',
      ),
      // 활성 계획을 고치는 흐름은 페이즈로 추가를 쓰지 않는다.
      if (merged?.document case final document? when !_editingActivePlan)
        true: PlanningDocument(
          id: 'plan-flow-compare-merged-$stamp',
          name: document.name,
          kind: document.kind,
          phases: document.phases,
          version: document.version,
          goalMetadata: document.goalMetadata,
        ),
    };
    _comparing.addAll(candidates.keys);
    notifyListeners();
    final students = [
      for (final student in snapshot.state.students)
        confirmedStudentPlanningCurrent(student),
    ];
    final inventory = snapshot.state.inventory.toWire();
    await Future.wait([
      for (final entry in candidates.entries)
        () async {
          try {
            final result = await comparer.compareScenarios(
              currentStudents: students,
              inventory: inventory,
              documentA: active,
              documentB: entry.value,
            );
            if (_disposed || number != _compareNumber) return;
            _comparisons[entry.key] = PlanFlowSaveComparison.fromResult(
              result,
            );
            _comparisonErrors.remove(entry.key);
          } on Object catch (error) {
            if (_disposed || number != _compareNumber) return;
            _comparisonErrors[entry.key] = error;
          } finally {
            if (!_disposed && number == _compareNumber) {
              _comparing.remove(entry.key);
            }
          }
        }(),
    ]);
    if (!_disposed && number == _compareNumber) notifyListeners();
  }

  /// 시나리오 저장의 목록 revision. 고치기는 편집을 열 때 읽은 값(다시 읽은 뒤에는 최신 값)이다.
  int? _scenarioExpectedRevision(PlanFlowSaveSnapshot snapshot) =>
      flow.scenario == null
      ? snapshot.scenarioRevision
      : _editingCollectionRevision ?? snapshot.scenarioRevision;

  /// 지금 입력으로 만든 요청과 보류 요청이 같은 내용인가.
  bool _pendingMatches(PlanFlowSaveRequest pending, PlanFlowSaveSnapshot snapshot) {
    if (pending.target != _target || !identical(pending.draft, _draft)) {
      return false;
    }
    final expectedRevision = switch (_target) {
      PlanFlowSaveTarget.scenario => _scenarioExpectedRevision(snapshot),
      _ => _planExpectedRevision(snapshot),
    };
    if (pending.expectedRevision != expectedRevision) return false;
    return switch (_target) {
      PlanFlowSaveTarget.scenario =>
        pending.name == scenarioName.trim() &&
            pending.baseProfileRevision == snapshot.revision,
      PlanFlowSaveTarget.appendPhases => true,
      PlanFlowSaveTarget.replace =>
        pending.name == _archiveRequestName(snapshot) &&
            pending.expectedScenarioRevision == snapshot.scenarioRevision,
    };
  }

  PlanFlowSaveRequest? _buildRequest(PlanFlowSaveSnapshot snapshot) {
    final now = _clock();
    final stamp = now.microsecondsSinceEpoch;
    final key = newIdempotencyKey('plan-flow-save-${_target.name}', now: now);
    final profileId = snapshot.state.profileId;
    switch (_target) {
      case PlanFlowSaveTarget.scenario:
        final collection = _scenarioExpectedRevision(snapshot);
        if (collection == null) return null;
        final name = scenarioName.trim();
        final editing = flow.scenario;
        final document = PlanFlowDocumentBoundary.toScenarioDocument(
          _draft,
          id: editing?.document.id ?? 'scenario-draft-$stamp',
          name: name,
        );
        return PlanFlowSaveRequest(
          target: _target,
          draft: _draft,
          profileId: profileId,
          idempotencyKey: key,
          document: document,
          authoring: PlanFlowDocumentBoundary.authoringFor(_draft, document),
          expectedRevision: collection,
          expectedScenarioRevision: editing == null
              ? null
              : (_editingRevision ?? editing.revision),
          baseProfileRevision: snapshot.revision,
          scenarioId: editing?.id,
          name: name,
          description: editing?.description ?? '',
        );
      case PlanFlowSaveTarget.appendPhases:
        final document = merged?.document;
        final authoring = merged?.authoring;
        if (document == null || authoring == null) return null;
        return PlanFlowSaveRequest(
          target: _target,
          draft: _draft,
          profileId: profileId,
          idempotencyKey: key,
          document: document,
          authoring: authoring,
          expectedRevision: snapshot.revision,
          name: document.name,
          raisedTargets: merged?.raisedTargets ?? const [],
        );
      case PlanFlowSaveTarget.replace:
        final active = snapshot.activeDocument;
        final collection = snapshot.scenarioRevision;
        if (active == null || collection == null) return null;
        final document = PlanFlowDocumentBoundary.toPlanDocument(
          _draft,
          id: active.id,
          name: active.name,
        );
        return PlanFlowSaveRequest(
          target: _target,
          draft: _draft,
          profileId: profileId,
          idempotencyKey: key,
          document: document,
          authoring: PlanFlowDocumentBoundary.authoringFor(_draft, document),
          expectedRevision: _planExpectedRevision(snapshot),
          expectedScenarioRevision: collection,
          name: _archiveRequestName(snapshot),
        );
    }
  }

  /// 활성 계획 저장의 계정 revision. 활성 계획을 고치는 흐름은 초안을 연 revision(다시 읽은 뒤에는 최신)이다.
  int _planExpectedRevision(PlanFlowSaveSnapshot snapshot) =>
      _editingActivePlan
      ? _editingPlanRevision ?? snapshot.revision
      : snapshot.revision;

  /// 옮겨 둘 기존 계획 이름. 기존 활성 계획이 비어 있어 이름 칸을 숨겼는데 비어 있으면 기본값을 보낸다(백엔드는
  /// 빈 이름을 받지 않는다).
  String _archiveRequestName(PlanFlowSaveSnapshot snapshot) {
    final name = archiveName.trim();
    return name.isEmpty && snapshot.activePhaseCount == 0
        ? (_editingActivePlan
              ? planFlowEditedArchiveName
              : planFlowDefaultArchiveName)
        : name;
  }

  /// 고른 위치로 저장한다. 마치면 결과를, 실패하면 null을 준다(안내는 [message]).
  Future<PlanFlowSaveOutcome?> save() async {
    final snapshot = _snapshot;
    if (_disposed || !canSave || snapshot == null) return null;
    final pending = _pending;
    final PlanFlowSaveRequest? request;
    try {
      request = pending != null && _pendingMatches(pending, snapshot)
          ? pending
          : _buildRequest(snapshot);
    } on PlanningAuthoringFormatException catch (error) {
      // 보내기 전에 공용 validator가 거절했다(초안 확인을 지나친 경우). 보내지 않는다.
      _rejectAuthoring(
        error,
        merged: _target == PlanFlowSaveTarget.appendPhases,
      );
      notifyListeners();
      return null;
    }
    if (request == null) return null;
    _pending = request;
    _saving = true;
    _message = null;
    notifyListeners();
    try {
      final archivedScenarioId = await _send(request);
      if (_disposed) return null;
      _pending = null;
      return PlanFlowSaveOutcome(
        target: request.target,
        message: _successMessage(request, snapshot, archivedScenarioId),
        openScenarioList: _openScenarioList,
        archivedScenarioId: archivedScenarioId,
      );
    } on Object catch (error) {
      if (_disposed) return null;
      final code = planFlowSaveErrorCode(error);
      final message = planFlowSaveErrorMessage(code);
      if (code == 'invalid_authoring') {
        _rejectAuthoring(
          error,
          merged: request.target == PlanFlowSaveTarget.appendPhases,
        );
        return null;
      }
      if (planFlowSaveRereadCodes.contains(code)) {
        _saving = false;
        if (code == 'revision_conflict') _acceptLatestPlanRevision = true;
        unawaited(reload(message: message));
        return null;
      } else if (_retryable(error, code) || code == 'idempotency_conflict') {
        // 같은 키로 같은 요청을 다시 보낸다. idempotency_conflict는 새 키를 저절로 만들지 않는다.
        _message = message;
        _messageIsError = true;
      } else {
        _pending = null;
        _message = message;
        _messageIsError = true;
      }
      return null;
    } finally {
      if (!_disposed) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  /// authoring 규칙 오류: 같은 내용은 다시 보내도 거절되므로 보류 요청을 버리고, reason과 stage ID를 3단계 카드에
  /// 잇는다([PlanFlowController.reportSavedIssue]). 초안은 지우지 않는다. 페이즈로 추가([merged])의 병합 id는 초안 id로
  /// 되돌린다.
  void _rejectAuthoring(Object error, {required bool merged}) {
    _pending = null;
    final found = planFlowAuthoringErrorOf(error);
    final reason = found?.reason ?? 'invalid_shape';
    final back = {
      if (merged)
        for (final entry
            in (_merged?.stageIds ?? const <String, String>{}).entries)
          entry.value: entry.key,
    };
    final known = {for (final stage in _draft.stages) stage.id};
    final stageIds = <String>{
      for (final id in found?.stageIds ?? const <String>[])
        if (known.contains(back[id] ?? id)) back[id] ?? id,
      for (final issue in flow.orderIssues)
        if (issue.reason == reason) ...issue.stageIds,
    }.toList();
    final text = planFlowAuthoringReasonText(reason);
    _message = planFlowAuthoringErrorMessage(reason);
    _messageIsError = true;
    flow.reportSavedIssue(
      PlanFlowOrderIssue(
        reason: reason,
        stageIds: stageIds,
        message: '저장하지 않았습니다: $text.',
      ),
    );
  }

  /// 요청을 보낸다. 이걸로 바꾸기는 기존 계획을 옮겨 둔 시나리오 id를 준다.
  Future<String?> _send(PlanFlowSaveRequest request) async {
    final service = this.service;
    switch (request.target) {
      case PlanFlowSaveTarget.scenario:
        if (service is! PlanningScenarioRepositoryService) {
          throw StateError('scenario_repository_unavailable');
        }
        final scenarioId = request.scenarioId;
        if (scenarioId == null) {
          await service.createScenario(
            profileId: request.profileId,
            expectedRevision: request.expectedRevision,
            idempotencyKey: request.idempotencyKey,
            name: request.name,
            description: request.description,
            baseProfileRevision: request.baseProfileRevision!,
            document: request.document,
            authoring: request.authoring,
          );
        } else {
          await service.updateScenario(
            profileId: request.profileId,
            scenarioId: scenarioId,
            expectedRevision: request.expectedRevision,
            expectedScenarioRevision: request.expectedScenarioRevision!,
            idempotencyKey: request.idempotencyKey,
            name: request.name,
            description: request.description,
            baseProfileRevision: request.baseProfileRevision!,
            document: request.document,
            authoring: request.authoring,
          );
        }
        return null;
      case PlanFlowSaveTarget.appendPhases:
        if (service is! RepositoryPlanService) {
          throw StateError('plan_repository_unavailable');
        }
        await service.saveRepositoryPlan(
          profileId: request.profileId,
          document: request.document,
          authoring: request.authoring,
          expectedRevision: request.expectedRevision,
          idempotencyKey: request.idempotencyKey,
        );
        return null;
      case PlanFlowSaveTarget.replace:
        if (service is! RepositoryPlanService) {
          throw StateError('plan_repository_unavailable');
        }
        final result = await service.replaceRepositoryPlan(
          profileId: request.profileId,
          document: request.document,
          authoring: request.authoring,
          expectedRevision: request.expectedRevision,
          expectedScenarioRevision: request.expectedScenarioRevision!,
          idempotencyKey: request.idempotencyKey,
          archiveName: request.name,
          archiveDescription: '',
        );
        return result.archivedScenarioId;
    }
  }

  String _successMessage(
    PlanFlowSaveRequest request,
    PlanFlowSaveSnapshot snapshot,
    String? archivedScenarioId,
  ) => switch (request.target) {
    PlanFlowSaveTarget.scenario => '${request.name} 시나리오를 저장했습니다.',
    PlanFlowSaveTarget.appendPhases => [
      '활성 계획에 페이즈 ${request.document.phases.length - snapshot.activePhaseCount}개를 붙였습니다.',
      ?planFlowRaisedSummary(request.raisedTargets, flow.context.displayName),
    ].join(' '),
    PlanFlowSaveTarget.replace =>
      archivedScenarioId == null
          ? '활성 계획을 바꿨습니다.'
          : '활성 계획을 바꾸고 기존 계획을 ${request.name} 시나리오로 옮겨 두었습니다.',
  };

  @override
  void dispose() {
    _disposed = true;
    flow.removeListener(_flowChanged);
    super.dispose();
  }
}

/// 이걸로 바꾸기에서 옮겨 둘 기존 활성 계획 이름의 기본값.
const planFlowDefaultArchiveName = '이전 활성 계획';

/// 활성 계획을 고쳐 바꿀 때(FE4-f2) 옮겨 둘 기존 활성 계획 이름의 기본값.
const planFlowEditedArchiveName = '고치기 전 활성 계획';

/// 숫자 뒤 조사 "로/으로"(받침 없음·ㄹ은 "로").
String planFlowRoParticle(int value) {
  final digit = value.abs() % 10;
  return digit == 0 || digit == 3 || digit == 6 ? '으로' : '로';
}

/// C 옵션 아래 줄(시안 "활성 계획은 그대로 두고 따로 비교합니다" 등).
String planFlowSaveTargetSubtitle(
  PlanFlowSaveTarget target, {
  required PlanFlowSaveController save,
  required int newPhaseCount,
}) {
  final reason = save.unavailableReason(target);
  if (reason != null) return reason;
  final active = save.snapshot?.activePhaseCount;
  switch (target) {
    case PlanFlowSaveTarget.scenario:
      final editing = save.flow.scenario;
      return editing == null
          ? '활성 계획은 그대로 두고 따로 비교합니다'
          : '${editing.name} 시나리오를 고쳐 저장합니다';
    case PlanFlowSaveTarget.appendPhases:
      if (active == null) return '활성 계획 뒤에 페이즈로 붙입니다';
      if (newPhaseCount == 0) return '붙일 페이즈 없이 나중에 칸 단계만 보관합니다';
      final first = active + 1;
      final last = active + newPhaseCount;
      final range = newPhaseCount <= 1 ? 'P$first' : 'P$first~P$last';
      final particle = planFlowRoParticle(newPhaseCount <= 1 ? first : last);
      return active == 0
          ? '비어 있는 활성 계획에 $range$particle 넣습니다'
          : '지금 P$active 뒤에 $range$particle 붙입니다';
    case PlanFlowSaveTarget.replace:
      if (active == null) return '기존 페이즈는 시나리오로 옮겨 둡니다';
      return active == 0
          ? '비어 있는 활성 계획을 이걸로 채웁니다'
          : '기존 페이즈 $active개는 시나리오로 옮겨 둡니다';
  }
}
