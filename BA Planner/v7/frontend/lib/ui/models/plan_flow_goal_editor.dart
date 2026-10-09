// 계획 만들기 2단계 목표 정하기 편집 상태(FE4-c, 시안 Flow-2-Goals, C 보고서 §2, FD-072·FD-073·FD-075·FD-076).
//
// 학생마다 정수 작업 단계(`PlanElementStageDraft`, 19키 누적 절대 목표)를 들고 고친다. 고칠 때마다 "앞 단계보다
// 하나라도 올린" 단계만 골라 [PlanFlowController.setStudentStages]로 초안에 넣는다(기존 요소 편집기 확정과 같은
// 규칙). 초안은 문서 v2이고 정수 → v2 변환은 [PlanFlowGoalCodec.fromEditor]가 한다: 끝까지 지금 값과 같은 키는
// 모든 단계에서 null(목표 없음)이다. 현재값으로 채우는 `planningDocumentTargets`는 쓰지 않고, 계산 결과(유효 상태)를
// 작업 단계에 되쓰지 않는다.
//
// 동작은 기존 요소 편집기(`plan_element_builder.dart` `_PlanElementBuilderState`)를 옮긴 것이다.
// - 값 바꾸기: 아래 한계는 앞 단계 값(첫 단계는 지금 값), 위 한계는 목표 최댓값. 성장 규칙으로 정규화하고, 올린
//   값은 뒤 단계에도 올려 준다(바뀐 칸은 900ms 동안 표시).
// - 단계 추가: 고른 단계 바로 뒤에 그 단계 복사본. 단계 삭제: 1개는 남긴다. 기본 이름(`n단계`)은 번호를 다시 매긴다.
// - 프리셋 적용: 프리셋의 듬성한 단계를 앞 단계 값에 누적해 펼치고, 앞 단계보다 올린 단계만 남긴다. 저장된
//   프리셋(FE4-i)은 단계 이름도 옮긴다.
// 새로 더한 것:
// - 모드(FD-075): "한 번에 MAX" = 1단계에 모든 목표 최댓값, "직접 입력" = 지금 값 그대로인 빈 1단계. 저장하지 않는다.
// - 목표 지우기: 고른 키를 그 학생의 모든 단계에서 지금 값으로 되돌린다(v2에서는 모든 단계 null, 누적 회귀 방지).
// - 다른 학생에도 적용: 지금 학생의 모드(프리셋·MAX)를 다른 학생 또는 모두에게 적용한다.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../widgets/plan_element_builder.dart'
    show planElementCurrentTargets, planStudentHasFavoriteItemMetadata;
import 'plan_flow_draft.dart';
import 'planning_growth_rules.dart';
import 'planning_models.dart';

/// "한 번에 MAX" 모드 id.
const planFlowGoalModeMax = 'max';

/// "직접 입력" 모드 id.
const planFlowGoalModeDirect = 'direct';

/// 프리셋 [presetId]를 적용한 모드 id.
String planFlowGoalPresetMode(String presetId) => 'preset:$presetId';

/// 앞 단계에서 이어받아 올라간 칸을 보여 주는 시간(기존 요소 편집기와 같다).
const planFlowGoalPropagationHighlight = Duration(milliseconds: 900);

/// 현재 → 최종 줄의 항목과 그 항목을 지울 때 지우는 목표 키.
enum PlanFlowGoalGroup {
  level('LEVEL', {'level'}),
  star('STAR', {'student_star'}),
  weapon('WEAPON', {'weapon_level', 'weapon_star'}),
  skill('SKILL', {'ex_skill', 'skill1', 'skill2', 'skill3'}),
  equipment('EQUIPMENT', {
    'equip1_tier',
    'equip2_tier',
    'equip3_tier',
    'equip1_level',
    'equip2_level',
    'equip3_level',
    'equip4_tier',
  }),
  bond('BOND', {'bond_rank'}),
  ability('ABILITY', {'stat_hp', 'stat_atk', 'stat_heal'});

  const PlanFlowGoalGroup(this.label, this.keys);

  final String label;
  final Set<String> keys;
}

/// 2단계 학생 탭 상태(시안 `설정 중`·`완료`·`미설정`).
enum PlanFlowGoalTabState { editing, done, unset }

/// 2단계 편집 상태. 흐름([flow]) 동안 하나를 둔다(1단계로 갔다 와도 학생별 작업 단계·모드가 남는다).
class PlanFlowGoalEditor extends ChangeNotifier {
  PlanFlowGoalEditor({
    required this.flow,
    List<PlanElementPreset> presets = const [],
  }) : _presets = List.unmodifiable(presets) {
    _studentId = flow.goalSeed?.studentId;
    flow.addListener(_flowChanged);
  }

  final PlanFlowController flow;

  List<PlanElementPreset> _presets;
  final Map<String, List<PlanElementStageDraft>> _stages = {};
  final Map<String, String?> _modes = {};
  final Map<String, String> _selectedStages = {};
  final Map<String, PlanningStudentSeed> _seeds = {};

  /// 학생별로 마지막으로 읽거나 넣은 초안 단계 id. 초안이 밖에서 바뀌었는지 이것과 비교한다.
  final Map<String, List<String>> _syncedIds = {};
  PlanFlowDraft? _seenDraft;
  final Set<String> _propagated = {};
  Timer? _propagationTimer;
  String? _studentId;
  String? _expandedStageId;
  int _nextStageNumber = 1;
  bool _syncing = false;
  bool _disposed = false;

  /// 프리셋 바·C 목록에 보이는 단계 프리셋. 프로필 저장소(FB-14)의 프리셋이 먼저, 계획 화면 프리셋 관리의
  /// 인메모리 프리셋이 뒤다(FE4-i).
  List<PlanElementPreset> get presets => _presets;

  /// 프리셋 목록을 바꾼다(위젯 갱신에서 부르므로 알리지 않는다).
  void updatePresets(List<PlanElementPreset> presets) {
    if (listEquals(presets, _presets)) return;
    _presets = List.unmodifiable(presets);
  }

  PlanElementPreset? presetById(String id) {
    for (final preset in _presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  // --- 학생 탭 ---------------------------------------------------------------

  /// 탭 순서(1단계에서 고른 순서).
  List<String> get studentIds => flow.draft.studentIds;

  /// 지금 고치는 학생. 고른 학생이 없으면 null.
  String? get studentId {
    final ids = studentIds;
    final selected = _studentId;
    if (selected != null && ids.contains(selected)) return selected;
    return ids.firstOrNull;
  }

  void selectStudent(String studentId) {
    if (_disposed || studentId == this.studentId) return;
    if (!studentIds.contains(studentId)) return;
    _studentId = studentId;
    _expandedStageId = null;
    notifyListeners();
  }

  PlanFlowGoalTabState tabStateOf(String studentId) {
    if (studentId == this.studentId) return PlanFlowGoalTabState.editing;
    final stages = flow.draft.stagesByStudent[studentId];
    return stages == null || stages.isEmpty
        ? PlanFlowGoalTabState.unset
        : PlanFlowGoalTabState.done;
  }

  // --- 학생 정보 --------------------------------------------------------------

  PlanningStudentSeed seedOf(String studentId) =>
      flow.draft.seedOf(studentId) ??
      _seeds.putIfAbsent(studentId, () => flow.context.seedFor(studentId));

  /// 학생의 지금 값(미보유면 목표 최솟값, FD-076).
  Map<String, int> currentOf(String studentId) =>
      planElementCurrentTargets(seedOf(studentId));

  bool hasFavoriteItem(String studentId) =>
      planStudentHasFavoriteItemMetadata(seedOf(studentId).metadata);

  bool isOwned(String studentId) => seedOf(studentId).owned;

  String displayName(String studentId) => flow.context.displayName(studentId);

  // --- 단계 -------------------------------------------------------------------

  /// [studentId]의 작업 단계(앞 단계보다 올린 것이 없는 단계도 들어 있다).
  List<PlanElementStageDraft> stagesOf(String studentId) =>
      List.unmodifiable(_ensure(studentId));

  /// 단계가 앞 단계(첫 단계는 지금 값)보다 하나라도 올렸다(초안·계산에 들어간다).
  bool isEffective(String studentId, String stageId) =>
      _effective(studentId).any((stage) => stage.id == stageId);

  /// [stageIndex] 단계의 바로 앞 값(첫 단계는 지금 값).
  Map<String, int> previousTargetsOf(String studentId, int stageIndex) {
    final stages = _ensure(studentId);
    return stageIndex <= 0 || stageIndex > stages.length
        ? currentOf(studentId)
        : stages[stageIndex - 1].targets;
  }

  /// 마지막 단계 값(현재 → 최종의 최종).
  Map<String, int> finalTargetsOf(String studentId) {
    final stages = _ensure(studentId);
    return stages.isEmpty ? currentOf(studentId) : stages.last.targets;
  }

  String? selectedStageIdOf(String studentId) {
    final stages = _ensure(studentId);
    final selected = _selectedStages[studentId];
    if (selected != null && stages.any((stage) => stage.id == selected)) {
      return selected;
    }
    return stages.lastOrNull?.id;
  }

  void selectStage(String stageId) {
    final studentId = this.studentId;
    if (_disposed || studentId == null) return;
    if (!_ensure(studentId).any((stage) => stage.id == stageId)) return;
    if (_selectedStages[studentId] == stageId) return;
    _selectedStages[studentId] = stageId;
    notifyListeners();
  }

  /// "더 보기"(FD-072: 카드에 칸이 없는 목표)를 연 단계.
  String? get expandedStageId => _expandedStageId;

  void toggleExpanded(String stageId) {
    if (_disposed) return;
    _expandedStageId = _expandedStageId == stageId ? null : stageId;
    notifyListeners();
  }

  /// 앞 단계에서 이어받아 방금 올라간 칸.
  bool isPropagated(String stageId, String key) =>
      _propagated.contains('$stageId:$key');

  /// [studentId]의 모드(프리셋·MAX·직접 입력). 값을 고쳐도 남는다(기존 요소 편집기의 고른 프리셋과 같다).
  String? modeOf(String studentId) {
    _ensure(studentId);
    return _modes[studentId];
  }

  /// [key]의 아래 한계(앞 단계 값, 첫 단계는 지금 값).
  int minimumOf(String studentId, int stageIndex, String key) => math.max(
    planElementTargetMinimums[key] ?? 0,
    previousTargetsOf(studentId, stageIndex)[key] ??
        planElementTargetMinimums[key] ??
        0,
  );

  /// [key]의 위 한계(애장품이 없는 학생의 애장품은 0).
  int maximumOf(String studentId, String key) =>
      key == 'equip4_tier' && !hasFavoriteItem(studentId)
      ? 0
      : planElementTargetMaximums[key] ?? 0;

  /// 지금 학생 [stageId] 단계의 [key]를 [requested]로 바꾼다.
  void setTarget(String stageId, String key, int requested) {
    final studentId = this.studentId;
    if (_disposed || studentId == null) return;
    final stages = _ensure(studentId);
    final stageIndex = stages.indexWhere((stage) => stage.id == stageId);
    if (stageIndex < 0) return;
    final value = requested.clamp(
      minimumOf(studentId, stageIndex, key),
      math.max(
        minimumOf(studentId, stageIndex, key),
        maximumOf(studentId, key),
      ),
    ).toInt();
    final hasFavorite = hasFavoriteItem(studentId);
    final selected = Map<String, int>.from(stages[stageIndex].targets);
    selected[key] = value;
    final normalized = normalizePlanningGrowthTargets(
      selected,
      changedKeys: {key},
      hasFavoriteItem: hasFavorite,
    );
    final affectedKeys = {
      for (final entry in normalized.entries)
        if (entry.value != stages[stageIndex].targets[entry.key]) entry.key,
    };
    if (affectedKeys.isEmpty) return;
    stages[stageIndex] = stages[stageIndex].copyWith(targets: normalized);
    final propagated = <String>{};
    for (var index = stageIndex + 1; index < stages.length; index++) {
      final targets = Map<String, int>.from(stages[index].targets);
      var changed = false;
      for (final affectedKey in affectedKeys) {
        final required = normalized[affectedKey]!;
        if ((targets[affectedKey] ?? required) >= required) continue;
        targets[affectedKey] = required;
        propagated.add('${stages[index].id}:$affectedKey');
        changed = true;
      }
      if (!changed) continue;
      stages[index] = stages[index].copyWith(
        targets: normalizePlanningGrowthTargets(
          targets,
          changedKeys: affectedKeys,
          hasFavoriteItem: hasFavorite,
        ),
      );
    }
    _selectedStages[studentId] = stageId;
    _markPropagated(propagated);
    _commit(studentId);
  }

  /// 고른 단계 바로 뒤에 그 단계 복사본을 넣고 고른다.
  void addStage() {
    final studentId = this.studentId;
    if (_disposed || studentId == null) return;
    final stages = _ensure(studentId);
    final selectedId = selectedStageIdOf(studentId);
    final selectedIndex = stages.indexWhere((stage) => stage.id == selectedId);
    final insertIndex = selectedIndex >= 0 ? selectedIndex + 1 : stages.length;
    final source = selectedIndex >= 0 ? stages[selectedIndex] : stages.last;
    final stage = PlanElementStageDraft(
      id: _newStageId(studentId),
      name: '${insertIndex + 1}단계',
      targets: source.targets,
    );
    stages.insert(insertIndex, stage);
    _renumberDefaultNames(stages);
    _selectedStages[studentId] = stage.id;
    _commit(studentId);
  }

  /// 단계를 지운다(하나는 남긴다). 앞 단계를 고른다.
  void removeStage(String stageId) {
    final studentId = this.studentId;
    if (_disposed || studentId == null) return;
    final stages = _ensure(studentId);
    final index = stages.indexWhere((stage) => stage.id == stageId);
    if (index < 0 || stages.length <= 1) return;
    stages.removeAt(index);
    _renumberDefaultNames(stages);
    _selectedStages[studentId] = stages[math.max(0, index - 1)].id;
    if (_expandedStageId == stageId) _expandedStageId = null;
    _commit(studentId);
  }

  /// 단계 이름을 바꾼다(카드 머리 인라인 편집, FD-073). 비우면 기본 이름(`n단계`)으로 돌아간다.
  void renameStage(String stageId, String name) {
    final studentId = this.studentId;
    if (_disposed || studentId == null) return;
    final stages = _ensure(studentId);
    final index = stages.indexWhere((stage) => stage.id == stageId);
    if (index < 0) return;
    final trimmed = name.trim();
    final next = trimmed.isEmpty ? '${index + 1}단계' : trimmed;
    if (stages[index].name == next) return;
    stages[index] = stages[index].copyWith(name: next);
    if (flow.draft.stageById(stageId) != null) {
      _syncing = true;
      try {
        flow.renameStage(stageId, next);
      } finally {
        _syncing = false;
      }
    }
    notifyListeners();
  }

  /// 모드를 적용한다(프리셋 바·C 프리셋 행). [studentId]가 없으면 지금 학생.
  void applyMode(String mode, {String? studentId}) {
    final target = studentId ?? this.studentId;
    if (_disposed || target == null) return;
    final stages = _stagesForMode(target, mode);
    if (stages == null) return;
    _stages[target] = stages;
    _modes[target] = mode;
    _selectedStages[target] = stages.last.id;
    if (target == this.studentId) _expandedStageId = null;
    _commit(target);
  }

  /// 지금 학생의 모드(프리셋·MAX)를 [studentIds]에 적용한다(C "다른 학생에도 적용", "고른 n명 모두").
  void applyCurrentModeTo(Iterable<String> studentIds) {
    final current = studentId;
    final mode = current == null ? null : modeOf(current);
    if (_disposed || mode == null || mode == planFlowGoalModeDirect) return;
    for (final id in studentIds.toList()) {
      if (id != current && this.studentIds.contains(id)) {
        applyMode(mode, studentId: id);
      }
    }
  }

  /// 지금 학생의 모든 단계에서 [keys] 목표를 지운다(지금 값으로 되돌린다). 성장 규칙상 그 키에 묶인 목표도 함께
  /// 내려간다(예: 성급을 지우면 5성이 필요한 전용무기 목표).
  void clearGoal(Set<String> keys) {
    final studentId = this.studentId;
    if (_disposed || studentId == null || keys.isEmpty) return;
    final current = currentOf(studentId);
    final hasFavorite = hasFavoriteItem(studentId);
    final stages = _ensure(studentId);
    for (var index = 0; index < stages.length; index++) {
      stages[index] = stages[index].copyWith(
        targets: normalizePlanningGrowthTargets(
          {
            ...stages[index].targets,
            for (final key in keys) key: current[key]!,
          },
          changedKeys: keys,
          hasFavoriteItem: hasFavorite,
        ),
      );
    }
    _commit(studentId);
  }

  /// 그 학생의 어느 단계에서든 [keys] 중 하나를 지금 값보다 올렸다.
  bool hasGoal(String studentId, Set<String> keys) {
    final current = currentOf(studentId);
    return _ensure(studentId).any(
      (stage) => keys.any((key) => stage.targets[key]! > current[key]!),
    );
  }

  /// "지금 구성을 프리셋으로"(FE4-i)에 넣을 [studentId]의 단계: 초안의 v2 단계(앞 단계보다 올린 단계만, 이름과
  /// 19키 nullable 목표 원본). 지금 값으로 null을 채우지 않는다. 단계가 없으면 빈 목록이다.
  List<PlanFlowStageDraft> presetStagesOf(String studentId) =>
      flow.draft.stagesByStudent[studentId] ?? const <PlanFlowStageDraft>[];

  /// 모드 이름(프리셋 바·C 행 글자).
  String modeLabel(String mode) {
    if (mode == planFlowGoalModeMax) return '한 번에 MAX';
    if (mode == planFlowGoalModeDirect) return '직접 입력';
    final preset = presetById(mode.substring('preset:'.length));
    return preset?.name ?? '프리셋';
  }

  // --- 내부 -------------------------------------------------------------------

  List<PlanElementStageDraft> _ensure(String studentId) =>
      _stages.putIfAbsent(studentId, () => _load(studentId));

  List<PlanElementStageDraft> _load(String studentId) {
    final hasFavorite = hasFavoriteItem(studentId);
    final loaded = [
      for (final stage in flow.editorStagesFor(studentId))
        stage.copyWith(
          targets: normalizePlanningGrowthTargets(
            stage.targets,
            hasFavoriteItem: hasFavorite,
          ),
        ),
    ];
    _modes[studentId] = loaded.isEmpty ? planFlowGoalModeDirect : null;
    _syncedIds[studentId] = _draftIds(studentId);
    return loaded.isEmpty ? [_blankStage(studentId)] : loaded;
  }

  List<String> _draftIds(String studentId) => [
    for (final stage
        in flow.draft.stagesByStudent[studentId] ??
            const <PlanFlowStageDraft>[])
      stage.id,
  ];

  PlanElementStageDraft _blankStage(String studentId) => PlanElementStageDraft(
    id: _newStageId(studentId),
    name: '1단계',
    targets: currentOf(studentId),
  );

  String _newStageId(String studentId) {
    final used = {
      for (final stage in _stages[studentId] ?? const <PlanElementStageDraft>[])
        stage.id,
      for (final stage in flow.draft.stages) stage.id,
    };
    while (true) {
      final id = '$studentId-stage-${_nextStageNumber++}';
      if (!used.contains(id)) return id;
    }
  }

  void _renumberDefaultNames(List<PlanElementStageDraft> stages) {
    for (var index = 0; index < stages.length; index++) {
      if (RegExp(r'^\d+단계$').hasMatch(stages[index].name)) {
        stages[index] = stages[index].copyWith(name: '${index + 1}단계');
      }
    }
  }

  /// 모드가 만드는 작업 단계. 프리셋을 못 찾으면 null.
  List<PlanElementStageDraft>? _stagesForMode(String studentId, String mode) {
    final current = currentOf(studentId);
    final hasFavorite = hasFavoriteItem(studentId);
    if (mode == planFlowGoalModeDirect) return [_blankStage(studentId)];
    if (mode == planFlowGoalModeMax) {
      final maximum = normalizePlanningGrowthTargets({
        for (final key in planningDocumentTargetKeys)
          key: math.max(planElementTargetMaximums[key] ?? 0, current[key]!),
      }, hasFavoriteItem: hasFavorite);
      return [
        PlanElementStageDraft(
          id: _newStageId(studentId),
          name: '1단계',
          targets: maximum,
        ),
      ];
    }
    final preset = mode.startsWith('preset:')
        ? presetById(mode.substring('preset:'.length))
        : null;
    if (preset == null) return null;
    var previous = Map<String, int>.from(current);
    final next = <PlanElementStageDraft>[];
    for (final (presetIndex, sparse) in preset.stages.indexed) {
      final expanded = {...previous};
      for (final entry in sparse.entries) {
        expanded[entry.key] = math.max(
          previous[entry.key] ?? planElementTargetMinimums[entry.key] ?? 0,
          entry.value,
        );
      }
      final effective = normalizePlanningGrowthTargets(
        {
          for (final entry in expanded.entries)
            entry.key: math.max(entry.value, current[entry.key] ?? entry.value),
        },
        changedKeys: sparse.keys.toSet(),
        hasFavoriteItem: hasFavorite,
      );
      if (_hasIncreaseOver(effective, previous)) {
        next.add(
          PlanElementStageDraft(
            id: _newStageId(studentId),
            // 저장된 프리셋의 단계 이름(FD-074). 없으면 기본 이름이다.
            name: preset.stageNameAt(presetIndex) ?? '${next.length + 1}단계',
            targets: effective,
          ),
        );
        previous = effective;
      }
    }
    return next.isEmpty ? [_blankStage(studentId)] : next;
  }

  static bool _hasIncreaseOver(
    Map<String, int> target,
    Map<String, int> baseline,
  ) => target.entries.any(
    (entry) => entry.value > (baseline[entry.key] ?? entry.value),
  );

  /// 앞 단계보다 하나라도 올린 단계(기존 요소 편집기 확정 규칙).
  List<PlanElementStageDraft> _effective(String studentId) {
    final effective = <PlanElementStageDraft>[];
    var baseline = currentOf(studentId);
    for (final stage in _ensure(studentId)) {
      if (_hasIncreaseOver(stage.targets, baseline)) {
        effective.add(stage);
        baseline = stage.targets;
      }
    }
    return effective;
  }

  void _commit(String studentId) {
    _syncing = true;
    try {
      flow.setStudentStages(studentId, List.unmodifiable(_effective(studentId)));
    } finally {
      _syncing = false;
    }
    _syncedIds[studentId] = _draftIds(studentId);
    _seenDraft = flow.draft;
    notifyListeners();
  }

  void _markPropagated(Set<String> fields) {
    _propagationTimer?.cancel();
    _propagated
      ..clear()
      ..addAll(fields);
    if (fields.isEmpty) {
      _propagationTimer = null;
      return;
    }
    _propagationTimer = Timer(planFlowGoalPropagationHighlight, () {
      _propagationTimer = null;
      if (_disposed) return;
      _propagated.clear();
      notifyListeners();
    });
  }

  /// 초안이 밖에서 바뀌면(1단계에서 학생을 빼는 등) 작업 단계를 버리고 다음에 초안에서 다시 읽는다. 계산 결과만
  /// 바뀐 알림(초안은 그대로)은 건너뛴다. 이 편집기가 넣은 단계 id와 같으면 작업 단계(앞 단계보다 올린 것이 없는
  /// 단계 포함)를 그대로 둔다.
  void _flowChanged() {
    if (_syncing || _disposed) return;
    final draft = flow.draft;
    if (identical(draft, _seenDraft)) return;
    _seenDraft = draft;
    final ids = draft.studentIds.toSet();
    var changed = false;
    for (final studentId in _stages.keys.toList()) {
      final stale =
          !ids.contains(studentId) ||
          !listEquals(_draftIds(studentId), _syncedIds[studentId]);
      if (!stale) continue;
      _stages.remove(studentId);
      _modes.remove(studentId);
      _selectedStages.remove(studentId);
      _seeds.remove(studentId);
      _syncedIds.remove(studentId);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    flow.removeListener(_flowChanged);
    _propagationTimer?.cancel();
    _propagationTimer = null;
    super.dispose();
  }
}
