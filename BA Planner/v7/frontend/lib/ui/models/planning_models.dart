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
  }) : stages = List.unmodifiable([
         for (final stage in stages) Map<String, int>.unmodifiable(stage),
       ]);

  final String id;
  final String name;
  final bool isDefault;
  final List<Map<String, int>> stages;
}

enum PlanningDocumentKind { plan, scenario }

@immutable
class PlanningDocumentStage {
  PlanningDocumentStage({
    required this.id,
    required this.studentId,
    required this.name,
    required Map<String, int> targets,
  }) : targets = Map.unmodifiable(targets);

  final String id;
  final String studentId;
  final String name;
  final Map<String, int> targets;

  Map<String, dynamic> toWire() => {
    'stage_id': id,
    'student_id': studentId,
    'name': name,
    'targets': Map<String, int>.from(targets),
  };

  factory PlanningDocumentStage.fromWire(Map<String, dynamic> value) {
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
    final targets = <String, int>{};
    for (final entry in rawTargets.entries) {
      final maximum = planningDocumentTargetMaximums[entry.key];
      final minimum = entry.key == 'bond_rank' ? 1 : 0;
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
    if (planningGrowthRuleViolation(targets) != null) {
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

  factory PlanningDocumentPhase.fromWire(Map<String, dynamic> value) {
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
  }) : phases = List.unmodifiable(phases);

  final String id;
  final String name;
  final PlanningDocumentKind kind;
  final List<PlanningDocumentPhase> phases;

  Iterable<PlanningDocumentStage> get stages =>
      phases.expand((phase) => phase.stages);

  Map<String, dynamic> toWire() => {
    'version': 1,
    'document_id': id,
    'name': name,
    'kind': kind.name,
    'phases': [for (final phase in phases) phase.toWire()],
  };

  factory PlanningDocument.fromWire(Map<String, dynamic> value) {
    if (value.keys.toSet().length != 5 ||
        !value.keys.toSet().containsAll({
          'version',
          'document_id',
          'name',
          'kind',
          'phases',
        }) ||
        value['version'] != 1 ||
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
        PlanningDocumentPhase.fromWire(Map<String, dynamic>.from(item as Map)),
    ];
    final phaseIds = phases.map((item) => item.id).toSet();
    final stages = phases.expand((item) => item.stages).toList();
    if (phaseIds.length != phases.length ||
        stages.map((item) => item.id).toSet().length != stages.length) {
      throw const FormatException('Planning document IDs must be unique');
    }
    final previous = <String, Map<String, int>>{};
    for (final stage in stages) {
      final old = previous[stage.studentId];
      if (old != null &&
          planningDocumentTargetKeys.any(
            (key) => stage.targets[key]! < old[key]!,
          )) {
        throw const FormatException('Planning document stage regresses');
      }
      previous[stage.studentId] = stage.targets;
    }
    return PlanningDocument(
      id: value['document_id'] as String,
      name: value['name'] as String,
      kind: kind,
      phases: phases,
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
