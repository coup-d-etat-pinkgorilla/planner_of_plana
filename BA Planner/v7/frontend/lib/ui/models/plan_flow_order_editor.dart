// 계획 만들기 3단계 단계 순서 화면 상태(FE4-d1, 시안 Flow-3-Order, FD-035·FD-069·FD-070·FD-071).
//
// 칸 배치 자체는 초안([PlanFlowController])에 있다. 이 상태는 화면에만 필요한 값(고른 카드, 거부 이유)과 C 보조에
// 쓰는 읽기 값을 맡는다.
import 'package:flutter/foundation.dart';

import '../widgets/plan_element_builder.dart' show planElementCurrentTargets;
import 'plan_flow_draft.dart';
import 'planning_growth_rules.dart';
import 'planning_models.dart';

/// 칸 하나에서 모자라는 재화(C "이 칸(n순위)에서 부족한 재화").
@immutable
class PlanFlowLaneShortage {
  const PlanFlowLaneShortage({
    required this.resourceKey,
    required this.name,
    required this.category,
    required this.shortage,
    this.itemId,
  });

  final String resourceKey;
  final String name;
  final String category;
  final String? itemId;

  /// 그 칸 단계들이 들어설 때 모자라는 양의 합.
  final int shortage;
}

/// 목표 하나의 바뀜(앞 단계 → 이 단계).
@immutable
class PlanFlowGoalChange {
  const PlanFlowGoalChange({
    required this.label,
    required this.from,
    required this.to,
  });

  /// `EX`, `기본`, `Lv.`처럼 앞에 붙는 이름.
  final String label;
  final String from;
  final String to;

  /// 카드 요약(`EX5`, `Lv.90`, `장비 T9 ×3`).
  String get short => switch (label) {
    'Lv.' || '★' || 'EX' => '$label$to',
    _ => '$label $to',
  };

  /// C 상세(`EX 3→5`, `Lv. 70→90`).
  String get detail => switch (label) {
    '★' => '$label$from→$to',
    _ => '$label $from→$to',
  };
}

String _skillText(int value, int maximum) =>
    value >= maximum ? 'M' : '$value';

String _tierText(int value) => value == 0 ? '-' : 'T$value';

/// [previous] → [next]에서 올라간 목표(카드·C 순서: 레벨 · 성급 · 전용무기 · EX · 기본 · 강화 · 서브 · 장비 · 애장품 ·
/// 인연 · HP · ATK · HEAL).
List<PlanFlowGoalChange> planFlowGoalChanges(
  Map<String, int> previous,
  Map<String, int> next,
) {
  int before(String key) => previous[key] ?? planElementTargetMinimums[key] ?? 0;
  int after(String key) => next[key] ?? before(key);
  bool raised(String key) => after(key) > before(key);
  final changes = <PlanFlowGoalChange>[];
  void add(String key, String label, String Function(int value) text) {
    if (raised(key)) {
      changes.add(
        PlanFlowGoalChange(
          label: label,
          from: text(before(key)),
          to: text(after(key)),
        ),
      );
    }
  }

  add('level', 'Lv.', (value) => '$value');
  add('student_star', '★', (value) => '$value');
  add('weapon_level', '전용무기', (value) => value == 0 ? '-' : 'Lv.$value');
  add('ex_skill', 'EX', (value) => '$value');
  add('skill1', '기본', (value) => _skillText(value, 10));
  add('skill2', '강화', (value) => _skillText(value, 10));
  add('skill3', '서브', (value) => _skillText(value, 10));
  const tierKeys = ['equip1_tier', 'equip2_tier', 'equip3_tier'];
  const levelKeys = ['equip1_level', 'equip2_level', 'equip3_level'];
  if ([...tierKeys, ...levelKeys].any(raised)) {
    String tiers(int Function(String key) read) {
      final values = [for (final key in tierKeys) read(key)];
      return values.toSet().length == 1 && values.first > 0
          ? '${_tierText(values.first)} ×3'
          : values.map(_tierText).join('/');
    }

    changes.add(
      PlanFlowGoalChange(label: '장비', from: tiers(before), to: tiers(after)),
    );
  }
  add('equip4_tier', '애장품', _tierText);
  add('bond_rank', '인연', (value) => '$value');
  add('stat_hp', 'HP', (value) => '$value');
  add('stat_atk', 'ATK', (value) => '$value');
  add('stat_heal', 'HEAL', (value) => '$value');
  return changes;
}

/// 3단계 화면 상태: 고른 카드, 마지막 거부 이유.
class PlanFlowOrderEditor extends ChangeNotifier {
  PlanFlowOrderEditor({required this.flow});

  final PlanFlowController flow;

  String? _selectedStageId;
  String? _message;
  bool _disposed = false;

  PlanFlowDraft get draft => flow.draft;

  /// 고른 카드. 고르지 않았거나 그 단계가 없어지면 첫 칸의 첫 단계다.
  String? get selectedStageId {
    final id = _selectedStageId;
    if (id != null && draft.stageById(id) != null) return id;
    for (final phase in draft.phases) {
      if (phase.stageIds.isNotEmpty) return phase.stageIds.first;
    }
    return draft.stages.firstOrNull?.id;
  }

  PlanFlowStage? get selectedStage {
    final id = selectedStageId;
    return id == null ? null : draft.stageById(id);
  }

  /// 마지막으로 거부한 이동의 이유. 다음 이동·정렬·선택에서 지운다.
  String? get message => _message;

  /// 3단계를 열 때 칸에 없는 단계를 칸에 넣는다([PlanFlowController.placeUnassignedStages]).
  void ensurePlaced() {
    if (_disposed || draft.unassignedStages.isEmpty) return;
    flow.placeUnassignedStages();
  }

  void select(String stageId) {
    if (_disposed) return;
    if (_selectedStageId == stageId && _message == null) return;
    _selectedStageId = stageId;
    _message = null;
    notifyListeners();
  }

  /// 카드를 칸 [phaseId]의 [index] 자리로 옮긴다. 거부하면 이유를 [message]에 두고 false다.
  bool move(String stageId, {required String phaseId, int? index}) {
    if (_disposed) return false;
    final violation = flow.moveStage(stageId, phaseId: phaseId, index: index);
    _selectedStageId = stageId;
    _message = violation;
    notifyListeners();
    return violation == null;
  }

  /// [stageId]를 [phaseId] 칸에 놓을 수 없으면 그 이유(끌고 있는 동안 칸 표시에 쓴다).
  String? violationFor(String stageId, String phaseId) {
    final index = draft.phases.indexWhere((phase) => phase.id == phaseId);
    return index < 0 ? null : flow.orderViolation(stageId, index);
  }

  void renamePhase(String phaseId, String name) {
    if (_disposed) return;
    flow.renamePhase(phaseId, name);
  }

  void addPhase() {
    if (_disposed) return;
    flow.addPhase();
    if (_message != null) {
      _message = null;
      notifyListeners();
    }
  }

  void autoArrange(PlanFlowAutoArrange mode) {
    if (_disposed) return;
    flow.autoArrange(mode);
    if (_message != null) {
      _message = null;
      notifyListeners();
    }
  }

  /// 카드 상태(FD-035). 계산 전이면 빈 맵이다.
  Map<String, PlanFlowStageStatus> get statuses =>
      planFlowStageStatuses(draft, flow.calculation);

  /// [stageId]가 든 칸. 칸에 없으면 null.
  PlanFlowPhase? phaseOf(String stageId) {
    for (final phase in draft.phases) {
      if (phase.stageIds.contains(stageId)) return phase;
    }
    return null;
  }

  /// 같은 학생의 바로 앞 단계(자동 선행).
  PlanFlowStage? predecessorOf(PlanFlowStage stage) {
    for (final candidate in draft.stages) {
      if (candidate.studentId == stage.studentId &&
          candidate.step == stage.step - 1) {
        return candidate;
      }
    }
    return null;
  }

  /// 같은 학생의 바로 뒤 단계.
  PlanFlowStage? successorOf(PlanFlowStage stage) {
    for (final candidate in draft.stages) {
      if (candidate.studentId == stage.studentId &&
          candidate.step == stage.step + 1) {
        return candidate;
      }
    }
    return null;
  }

  bool isOwned(String studentId) => draft.seedOf(studentId)?.owned ?? true;

  /// [stage] 앞의 정수 목표(첫 단계는 학생의 지금 값).
  Map<String, int> previousTargetsOf(PlanFlowStage stage) {
    final previous = predecessorOf(stage);
    if (previous != null) return previous.editorTargets;
    final seed = draft.seedOf(stage.studentId);
    if (seed != null) return planElementCurrentTargets(seed);
    return {
      for (final key in planningDocumentTargetKeys)
        key: planElementTargetMinimums[key] ?? 0,
    };
  }

  /// [stage]가 올리는 목표.
  List<PlanFlowGoalChange> changesOf(PlanFlowStage stage) =>
      planFlowGoalChanges(previousTargetsOf(stage), stage.editorTargets);

  /// 칸 [phase]에서 모자라는 재화(모자라는 양이 큰 순). 계산 전이면 null.
  List<PlanFlowLaneShortage>? laneShortages(PlanFlowPhase phase) {
    final calculation = flow.calculation;
    if (calculation == null) return null;
    final totals = <String, PlanFlowLaneShortage>{};
    for (final id in phase.stageIds) {
      for (final resource
          in calculation.stageCosts[id]?.resources ??
              const <PlanFlowStageResource>[]) {
        final shortage = resource.shortageAtEntry ?? 0;
        if (shortage <= 0) continue;
        final previous = totals[resource.resourceKey];
        totals[resource.resourceKey] = PlanFlowLaneShortage(
          resourceKey: resource.resourceKey,
          name: resource.name,
          category: resource.category,
          itemId: resource.itemId,
          shortage: (previous?.shortage ?? 0) + shortage,
        );
      }
    }
    return totals.values.toList()
      ..sort((a, b) => b.shortage.compareTo(a.shortage));
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
