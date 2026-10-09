import 'package:flutter/foundation.dart';

import 'planning_growth_rules.dart';

@immutable
class PlanningStudentSeed {
  PlanningStudentSeed({
    required this.handoffId,
    required this.studentId,
    required Map<String, dynamic> metadata,
    required Map<String, dynamic> currentValues,
    this.owned = true,
  }) : metadata = Map.unmodifiable(metadata),
       currentValues = Map.unmodifiable(currentValues);

  final String handoffId;
  final String studentId;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> currentValues;
  final bool owned;
}

@immutable
class PlanElementStageDraft {
  PlanElementStageDraft({
    required this.id,
    required this.name,
    required Map<String, int> targets,
  }) : targets = Map.unmodifiable(targets);

  final String id;
  final String name;
  final Map<String, int> targets;

  PlanElementStageDraft copyWith({
    String? id,
    String? name,
    Map<String, int>? targets,
  }) => PlanElementStageDraft(
    id: id ?? this.id,
    name: name ?? this.name,
    targets: targets ?? this.targets,
  );
}

@immutable
class PlanElementPreset {
  PlanElementPreset({
    required this.id,
    required this.name,
    required this.isDefault,
    required List<Map<String, int>> stages,
    List<String> stageNames = const [],
    this.repositoryPresetId,
  }) : stages = List.unmodifiable([
         for (final stage in stages) Map<String, int>.unmodifiable(stage),
       ]),
       stageNames = List.unmodifiable(stageNames);

  final String id;
  final String name;
  final bool isDefault;
  final List<Map<String, int>> stages;

  /// 단계 이름(FD-074, 저장된 단계 프리셋). [stages]와 같은 순서이고, 비어 있으면 적용할 때 "n단계"를 쓴다.
  final List<String> stageNames;

  /// 프로필 저장소(FB-14)의 프리셋 id. 계획 화면 프리셋 관리의 인메모리 프리셋이면 null이다.
  final String? repositoryPresetId;

  /// [index] 단계 이름. 없으면 null.
  String? stageNameAt(int index) =>
      index >= 0 && index < stageNames.length ? stageNames[index] : null;
}

enum PlanningDocumentKind { plan, scenario }

@immutable
class PlanningGoalMetadata {
  const PlanningGoalMetadata({required this.favorite, required this.notes});

  final bool favorite;
  final String notes;

  Map<String, dynamic> toWire() => {'favorite': favorite, 'notes': notes};

  factory PlanningGoalMetadata.fromWire(Map<String, dynamic> value) {
    if (value.length != 2 ||
        !value.keys.toSet().containsAll({'favorite', 'notes'}) ||
        value['favorite'] is! bool ||
        value['notes'] is! String) {
      throw const FormatException('Invalid planning goal_metadata');
    }
    return PlanningGoalMetadata(
      favorite: value['favorite'] as bool,
      notes: value['notes'] as String,
    );
  }
}

@immutable
class PlanningDocumentStage {
  PlanningDocumentStage({
    required this.id,
    required this.studentId,
    required this.name,
    required Map<String, int?> targets,
  }) : nullableTargets = Map.unmodifiable(targets),
       _integerTargets = targets.values.any((value) => value == null)
           ? null
           : Map<String, int>.unmodifiable(targets.cast<String, int>());

  final String id;
  final String studentId;
  final String name;

  /// Lossless v2 absolute targets. Null means no goal; zero is an explicit value.
  final Map<String, int?> nullableTargets;
  final Map<String, int>? _integerTargets;

  /// Compatibility view for existing v1 editors. Never fills or drops nullable goals.
  Map<String, int> get targets {
    if (_integerTargets == null) {
      throw StateError(
        'Use nullableTargets for a nullable planning document stage',
      );
    }
    return _integerTargets;
  }

  Map<String, dynamic> toWire() => {
    'stage_id': id,
    'student_id': studentId,
    'name': name,
    'targets': Map<String, int?>.from(nullableTargets),
  };

  factory PlanningDocumentStage.fromWire(
    Map<String, dynamic> value, {
    int version = 1,
  }) {
    if (value.keys.toSet().length != 4 ||
        !value.keys.toSet().containsAll({
          'stage_id',
          'student_id',
          'name',
          'targets',
        }) ||
        value['stage_id'] is! String ||
        (value['stage_id'] as String).isEmpty ||
        value['student_id'] is! String ||
        (value['student_id'] as String).isEmpty ||
        value['name'] is! String ||
        (value['name'] as String).isEmpty ||
        value['targets'] is! Map) {
      throw const FormatException('Invalid planning document stage');
    }
    final rawTargets = Map<String, dynamic>.from(value['targets'] as Map);
    if (rawTargets.keys.toSet().length != planningDocumentTargetKeys.length ||
        !rawTargets.keys.toSet().containsAll(planningDocumentTargetKeys)) {
      throw const FormatException('Invalid planning document targets');
    }
    final targets = <String, int?>{};
    for (final entry in rawTargets.entries) {
      final maximum = planningDocumentTargetMaximums[entry.key];
      final minimum = entry.key == 'bond_rank' ? 1 : 0;
      if (version == 2 && entry.value == null) {
        targets[entry.key] = null;
        continue;
      }
      if (maximum == null ||
          entry.value is! int ||
          entry.value < minimum ||
          entry.value > maximum) {
        throw const FormatException(
          'Planning document target is outside its range',
        );
      }
      targets[entry.key] = entry.value as int;
    }
    if (version == 1 &&
        planningGrowthRuleViolation(targets.cast<String, int>()) != null) {
      throw const FormatException(
        'Planning document targets violate growth rules',
      );
    }
    return PlanningDocumentStage(
      id: value['stage_id'] as String,
      studentId: value['student_id'] as String,
      name: value['name'] as String,
      targets: targets,
    );
  }
}

@immutable
class PlanningDocumentPhase {
  PlanningDocumentPhase({
    required this.id,
    required this.name,
    required List<PlanningDocumentStage> stages,
  }) : stages = List.unmodifiable(stages);

  final String id;
  final String name;
  final List<PlanningDocumentStage> stages;

  Map<String, dynamic> toWire() => {
    'phase_id': id,
    'name': name,
    'stages': [for (final stage in stages) stage.toWire()],
  };

  factory PlanningDocumentPhase.fromWire(
    Map<String, dynamic> value, {
    int version = 1,
  }) {
    if (value.keys.toSet().length != 3 ||
        !value.keys.toSet().containsAll({'phase_id', 'name', 'stages'}) ||
        value['phase_id'] is! String ||
        (value['phase_id'] as String).isEmpty ||
        value['name'] is! String ||
        (value['name'] as String).isEmpty ||
        value['stages'] is! List) {
      throw const FormatException('Invalid planning document phase');
    }
    return PlanningDocumentPhase(
      id: value['phase_id'] as String,
      name: value['name'] as String,
      stages: [
        for (final item in value['stages'] as List)
          PlanningDocumentStage.fromWire(
            Map<String, dynamic>.from(item as Map),
            version: version,
          ),
      ],
    );
  }
}

@immutable
class PlanningDocument {
  PlanningDocument({
    required this.id,
    required this.name,
    required this.kind,
    required List<PlanningDocumentPhase> phases,
    this.version = 1,
    Map<String, PlanningGoalMetadata> goalMetadata = const {},
  }) : phases = List.unmodifiable(phases),
       goalMetadata = Map.unmodifiable(goalMetadata);

  final String id;
  final String name;
  final PlanningDocumentKind kind;
  final List<PlanningDocumentPhase> phases;
  final int version;
  final Map<String, PlanningGoalMetadata> goalMetadata;

  Iterable<PlanningDocumentStage> get stages =>
      phases.expand((phase) => phase.stages);

  Map<String, dynamic> toWire() => {
    'version': version,
    'document_id': id,
    'name': name,
    'kind': kind.name,
    'phases': [for (final phase in phases) phase.toWire()],
    if (version == 2)
      'goal_metadata': {
        for (final entry in goalMetadata.entries)
          entry.key: entry.value.toWire(),
      },
  };

  factory PlanningDocument.fromWire(Map<String, dynamic> value) {
    final version = value['version'];
    final fields = {
      'version',
      'document_id',
      'name',
      'kind',
      'phases',
      if (version == 2) 'goal_metadata',
    };
    if (value.keys.toSet().length != fields.length ||
        !value.keys.toSet().containsAll(fields) ||
        version is! int ||
        (version != 1 && version != 2) ||
        value['document_id'] is! String ||
        (value['document_id'] as String).isEmpty ||
        value['name'] is! String ||
        (value['name'] as String).isEmpty ||
        value['kind'] is! String ||
        value['phases'] is! List) {
      throw const FormatException('Invalid planning document');
    }
    final kind = PlanningDocumentKind.values
        .where((item) => item.name == value['kind'])
        .firstOrNull;
    if (kind == null) {
      throw const FormatException('Invalid planning document kind');
    }
    final phases = [
      for (final item in value['phases'] as List)
        PlanningDocumentPhase.fromWire(
          Map<String, dynamic>.from(item as Map),
          version: version,
        ),
    ];
    final phaseIds = phases.map((item) => item.id).toSet();
    final stages = phases.expand((item) => item.stages).toList();
    if (phaseIds.length != phases.length ||
        stages.map((item) => item.id).toSet().length != stages.length) {
      throw const FormatException('Planning document IDs must be unique');
    }
    final previous = <String, Map<String, int?>>{};
    for (final stage in stages) {
      final old = previous[stage.studentId];
      if (old != null &&
          planningDocumentTargetKeys.any(
            (key) =>
                old[key] != null &&
                (stage.nullableTargets[key] == null ||
                    stage.nullableTargets[key]! < old[key]!),
          )) {
        throw const FormatException('Planning document stage regresses');
      }
      previous[stage.studentId] = stage.nullableTargets;
    }
    final goalMetadata = <String, PlanningGoalMetadata>{};
    if (version == 2) {
      final raw = value['goal_metadata'];
      if (raw is! Map ||
          raw.keys.toSet().length != previous.length ||
          !raw.keys.toSet().containsAll(previous.keys)) {
        throw const FormatException(
          'goal_metadata must match document students',
        );
      }
      for (final entry in raw.entries) {
        if (entry.value is! Map) {
          throw const FormatException('Invalid planning goal_metadata');
        }
        goalMetadata[entry.key as String] = PlanningGoalMetadata.fromWire(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }
    return PlanningDocument(
      id: value['document_id'] as String,
      name: value['name'] as String,
      kind: kind,
      phases: phases,
      version: version,
      goalMetadata: goalMetadata,
    );
  }
}

const planningDocumentTargetKeys = <String>{
  'level',
  'bond_rank',
  'student_star',
  'weapon_level',
  'weapon_star',
  'ex_skill',
  'skill1',
  'skill2',
  'skill3',
  'equip1_tier',
  'equip2_tier',
  'equip3_tier',
  'equip1_level',
  'equip2_level',
  'equip3_level',
  'equip4_tier',
  'stat_hp',
  'stat_atk',
  'stat_heal',
};

const planningDocumentTargetMaximums = planElementTargetMaximums;

int _tier(Object? value) {
  if (value is int) return value;
  final match = RegExp(r'(\d+)').firstMatch(value?.toString() ?? '');
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

Map<String, int> planningDocumentTargets({
  required Map<String, dynamic> current,
  required Map<String, dynamic> goal,
}) {
  int value(String targetKey, String currentKey, [int fallback = 0]) {
    final target = goal[targetKey];
    if (target is int) return target;
    final existing = current[currentKey];
    return existing is int ? existing : fallback;
  }

  final targets = <String, int>{
    'level': value('target_level', 'level'),
    'bond_rank': value('target_bond_rank', 'bond_rank', 1).clamp(1, 100),
    'student_star': value('target_star', 'student_star'),
    'weapon_level': value('target_weapon_level', 'weapon_level'),
    'weapon_star': value('target_weapon_star', 'weapon_star'),
    'ex_skill': value('target_ex_skill', 'ex_skill'),
    'skill1': value('target_skill1', 'skill1'),
    'skill2': value('target_skill2', 'skill2'),
    'skill3': value('target_skill3', 'skill3'),
    'equip1_tier': goal['target_equip1_tier'] is int
        ? goal['target_equip1_tier'] as int
        : _tier(current['equip1']),
    'equip2_tier': goal['target_equip2_tier'] is int
        ? goal['target_equip2_tier'] as int
        : _tier(current['equip2']),
    'equip3_tier': goal['target_equip3_tier'] is int
        ? goal['target_equip3_tier'] as int
        : _tier(current['equip3']),
    'equip1_level': value('target_equip1_level', 'equip1_level'),
    'equip2_level': value('target_equip2_level', 'equip2_level'),
    'equip3_level': value('target_equip3_level', 'equip3_level'),
    'equip4_tier': goal['target_equip4_tier'] is int
        ? goal['target_equip4_tier'] as int
        : _tier(current['equip4']),
    'stat_hp': value('target_stat_hp', 'stat_hp'),
    'stat_atk': value('target_stat_atk', 'stat_atk'),
    'stat_heal': value('target_stat_heal', 'stat_heal'),
  };
  final changedKeys = <String>{
    for (final entry in const {
      'target_level': 'level',
      'target_bond_rank': 'bond_rank',
      'target_star': 'student_star',
      'target_weapon_level': 'weapon_level',
      'target_weapon_star': 'weapon_star',
      'target_ex_skill': 'ex_skill',
      'target_skill1': 'skill1',
      'target_skill2': 'skill2',
      'target_skill3': 'skill3',
      'target_equip1_tier': 'equip1_tier',
      'target_equip2_tier': 'equip2_tier',
      'target_equip3_tier': 'equip3_tier',
      'target_equip1_level': 'equip1_level',
      'target_equip2_level': 'equip2_level',
      'target_equip3_level': 'equip3_level',
      'target_equip4_tier': 'equip4_tier',
      'target_stat_hp': 'stat_hp',
      'target_stat_atk': 'stat_atk',
      'target_stat_heal': 'stat_heal',
    }.entries)
      if (goal[entry.key] is int) entry.value,
  };
  return normalizePlanningGrowthTargets(targets, changedKeys: changedKeys);
}
