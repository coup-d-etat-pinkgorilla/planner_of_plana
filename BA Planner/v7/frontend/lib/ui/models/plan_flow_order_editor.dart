// 계획 만들기 3단계 단계 순서 화면 상태(FE4-d1, 시안 Flow-3-Order, FD-035·FD-069·FD-070·FD-071).
//
// 칸 배치 자체는 초안([PlanFlowController])에 있다. 이 상태는 화면에만 필요한 값(고른 카드, 거부 이유)과 C 보조에
// 쓰는 읽기 값을 맡는다.
// FE4-d2(시안 Flow-3-Order-Many): 크게·작게 보기(단계가 [planFlowOrderCompactThreshold]개를 넘으면 작게), 작게
// 보기 툴바(학생별 묶음 · 부족 있는 단계만 · 선택 풀기)와 보이는 카드 목록.
// FE4-f1: "나중에" 칸으로 옮기기, 직접 선행 잇기(카드 아래 점 끌기 · C "선행 단계 추가" 뒤 카드 누르기)·지우기,
// 고른 카드와 이어진 직접 선행, 규칙 위반 안내.
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

/// 단계가 이 수를 넘으면 3단계는 작게 보기로 연다(시안 Flow-3-Order-Many).
const planFlowOrderCompactThreshold = 12;

/// 3단계 화면 상태: 고른 카드, 마지막 거부 이유, 크게·작게 보기와 작게 보기 툴바.
class PlanFlowOrderEditor extends ChangeNotifier {
  PlanFlowOrderEditor({required this.flow});

  final PlanFlowController flow;

  String? _selectedStageId;
  bool _selectionCleared = false;
  String? _message;
  bool _linking = false;
  bool? _compactOverride;
  bool _groupByStudent = false;
  bool _shortOnly = false;
  bool _disposed = false;

  PlanFlowDraft get draft => flow.draft;

  /// 단계가 [planFlowOrderCompactThreshold]개를 넘는다(크게·작게 세그먼트를 보인다).
  bool get many => draft.stageCount > planFlowOrderCompactThreshold;

  /// 작게 보기(204×44 칩). 세그먼트로 고르지 않았으면 [many]를 따른다.
  bool get compact => _compactOverride ?? many;

  void setCompact(bool compact) {
    if (_disposed || this.compact == compact && _compactOverride != null) {
      return;
    }
    _compactOverride = compact;
    notifyListeners();
  }

  /// 작게 보기에서 칸 안 카드를 고른 학생 순서로 묶어 보인다(배치는 그대로).
  bool get groupByStudent => _groupByStudent;

  void toggleGroupByStudent() {
    if (_disposed) return;
    _groupByStudent = !_groupByStudent;
    notifyListeners();
  }

  /// 작게 보기에서 부족·막힘 단계(와 고른 카드)만 보인다. 계산 전이면 모두 보인다.
  bool get shortOnly => _shortOnly;

  void toggleShortOnly() {
    if (_disposed) return;
    _shortOnly = !_shortOnly;
    notifyListeners();
  }

  /// 고른 카드를 푼다(작게 보기 툴바 "선택 중 ×"). 다시 고르기 전까지 [selectedStageId]는 null이다.
  void clearSelection() {
    if (_disposed || _selectionCleared) return;
    _selectionCleared = true;
    _selectedStageId = null;
    _message = null;
    _linking = false;
    notifyListeners();
  }

  /// 고른 카드. 고르지 않았거나 그 단계가 없어지면 첫 칸의 첫 단계다. [clearSelection] 뒤에는 null이다.
  String? get selectedStageId {
    if (_selectionCleared) return null;
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

  /// 마지막으로 거부한 이동·잇기의 이유. 다음 이동·정렬·선택에서 지운다.
  String? get message => _message;

  /// C "선행 단계 추가"를 눌러 먼저 끝나야 하는 단계 카드를 고르는 중이다(FE4-f1).
  bool get linking => _linking && selectedStage != null;

  /// 고르는 중 안내.
  String? get linkingHint => linking
      ? '${flow.stageLabel(selectedStage!)}보다 먼저 끝나야 하는 단계 카드를 누릅니다.'
      : null;

  /// 본문 머리 안내: 거부 이유 → 잇기 안내 → 초안 규칙 위반 → 저장 거절 순서.
  ({String text, bool error})? get notice {
    final message = _message;
    if (message != null) return (text: message, error: true);
    final hint = linkingHint;
    if (hint != null) return (text: hint, error: false);
    final issue = flow.orderIssues.firstOrNull ?? flow.savedIssue;
    if (issue != null) return (text: issue.message, error: true);
    return null;
  }

  /// 3단계를 열 때 칸에 없는 단계(임시 미배치)를 칸에 넣는다([PlanFlowController.placeUnassignedStages]). 명시
  /// "나중에" 칸 단계는 다시 놓지 않는다.
  void ensurePlaced() {
    if (_disposed || draft.unassignedStages.isEmpty) return;
    flow.placeUnassignedStages();
  }

  void select(String stageId) {
    if (_disposed) return;
    if (_selectedStageId == stageId &&
        _message == null &&
        !_selectionCleared &&
        !_linking) {
      return;
    }
    _selectedStageId = stageId;
    _selectionCleared = false;
    _message = null;
    _linking = false;
    notifyListeners();
  }

  /// 카드·칩 누르기. 선행 단계를 고르는 중이면 누른 카드를 고른 카드의 먼저 끝나야 하는 단계로 잇고, 아니면 고른다.
  void tapCard(String stageId) {
    if (_disposed) return;
    final selected = selectedStageId;
    if (linking && selected != null && selected != stageId) {
      link(requiresStageId: stageId, stageId: selected);
      return;
    }
    select(stageId);
  }

  /// C "선행 단계 추가": 고르기 시작·그만두기.
  void toggleLinking() {
    if (_disposed || selectedStage == null) return;
    _linking = !_linking;
    _message = null;
    notifyListeners();
  }

  /// 직접 선행을 잇는다: [stageId]는 [requiresStageId]가 끝나야 한다(카드 아래 점 끌기, C 고르기). 거부하면 이유를
  /// [message]에 두고 false다. 이은 뒤 [stageId]를 고른다.
  bool link({required String requiresStageId, required String stageId}) {
    if (_disposed) return false;
    final violation = flow.addPrerequisite(
      stageId: stageId,
      requiresStageId: requiresStageId,
    );
    _selectedStageId = stageId;
    _selectionCleared = false;
    _linking = false;
    _message = violation;
    notifyListeners();
    return violation == null;
  }

  /// 직접 선행을 지운다(C ×).
  void unlink({required String requiresStageId, required String stageId}) {
    if (_disposed) return;
    flow.removePrerequisite(stageId: stageId, requiresStageId: requiresStageId);
    if (_message != null) {
      _message = null;
      notifyListeners();
    }
  }

  /// 카드를 칸 [phaseId]의 [index] 자리로 옮긴다. 거부하면 이유를 [message]에 두고 false다.
  bool move(String stageId, {required String phaseId, int? index}) {
    if (_disposed) return false;
    final violation = flow.moveStage(stageId, phaseId: phaseId, index: index);
    _selectedStageId = stageId;
    _selectionCleared = false;
    _linking = false;
    _message = violation;
    notifyListeners();
    return violation == null;
  }

  /// [stageId]를 [phaseId] 칸([planFlowDeferredLaneId]면 "나중에" 칸)에 놓을 수 없으면 그 이유(끌고 있는 동안 칸
  /// 표시에 쓴다).
  String? violationFor(String stageId, String phaseId) {
    final index = phaseId == planFlowDeferredLaneId
        ? draft.phases.length
        : draft.phases.indexWhere((phase) => phase.id == phaseId);
    return index < 0 ? null : flow.orderViolation(stageId, index);
  }

  /// "나중에" 칸(보드 칸 하나로 그린다). 칸 이름은 고칠 수 없다.
  PlanFlowPhase get deferredLane => PlanFlowPhase(
    id: planFlowDeferredLaneId,
    name: '나중에',
    stageIds: draft.deferredStageIds,
  );

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

  /// 칸 [phase]에서 보이는 카드 순서. 작게 보기([compact])에서만 [shortOnly]·[groupByStudent]를 쓴다. 고른 카드는
  /// 늘 보인다.
  List<String> visibleStageIds(
    PlanFlowPhase phase, {
    Map<String, PlanFlowStageStatus>? statuses,
  }) {
    if (!compact) return phase.stageIds;
    final selected = selectedStageId;
    var ids = phase.stageIds;
    final known = statuses ?? this.statuses;
    if (_shortOnly && known.isNotEmpty) {
      ids = [
        for (final id in ids)
          if (id == selected ||
              known[id] == PlanFlowStageStatus.short ||
              known[id] == PlanFlowStageStatus.blocked)
            id,
      ];
    }
    if (_groupByStudent) {
      final order = <String, int>{
        for (final (index, id) in draft.studentIds.indexed) id: index,
      };
      final position = {for (final (index, id) in ids.indexed) id: index};
      int rank(String id) {
        final stage = draft.stageById(id);
        return stage == null ? 1 << 20 : order[stage.studentId] ?? 1 << 20;
      }

      ids = [...ids]
        ..sort((a, b) {
          final byStudent = rank(a).compareTo(rank(b));
          return byStudent != 0
              ? byStudent
              : position[a]!.compareTo(position[b]!);
        });
    }
    return ids;
  }

  /// 보이는 목록의 [displayIndex] 자리를 칸 [phase]의 실제 자리로 바꾼다(그 자리 카드 앞, 끝이면 마지막 보이는 카드
  /// 뒤).
  int stageIndexFor(PlanFlowPhase phase, List<String> visible, int displayIndex) {
    if (displayIndex < visible.length) {
      final index = phase.stageIds.indexOf(visible[displayIndex]);
      return index < 0 ? phase.stageIds.length : index;
    }
    if (visible.isEmpty) return phase.stageIds.length;
    final last = phase.stageIds.indexOf(visible.last);
    return last < 0 ? phase.stageIds.length : last + 1;
  }

  /// 고른 카드와 이어진 카드(고른 카드 · 같은 학생 바로 앞·뒤 단계 · 직접 선행으로 이은 단계). 고른 카드가 없으면
  /// 모두 true다.
  bool isConnected(String stageId) {
    final stage = selectedStage;
    if (stage == null || stage.id == stageId) return true;
    return predecessorOf(stage)?.id == stageId ||
        successorOf(stage)?.id == stageId ||
        draft.prerequisites.any(
          (item) =>
              (item.stageId == stage.id && item.requiresStageId == stageId) ||
              (item.requiresStageId == stage.id && item.stageId == stageId),
        );
  }

  /// [stage]의 직접 선행(먼저 끝나야 하는 단계, 만든 순서). 초안에 없는 단계를 가리키면 단계가 null이다.
  List<({PlanFlowPrerequisite prerequisite, PlanFlowStage? stage})>
  directPrerequisitesOf(PlanFlowStage stage) => [
    for (final prerequisite in draft.prerequisites)
      if (prerequisite.stageId == stage.id)
        (
          prerequisite: prerequisite,
          stage: draft.stageById(prerequisite.requiresStageId),
        ),
  ];

  /// [stage]를 직접 선행으로 기다리는 단계.
  List<PlanFlowStage> directDependentsOf(PlanFlowStage stage) => [
    for (final prerequisite in draft.prerequisites)
      if (prerequisite.requiresStageId == stage.id)
        ?draft.stageById(prerequisite.stageId),
  ];

  /// [stageId] 카드에 걸린 규칙 위반(초안 확인 + 저장 거절).
  List<PlanFlowOrderIssue> issuesOf(String stageId) => flow.issuesOf(stageId);

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
