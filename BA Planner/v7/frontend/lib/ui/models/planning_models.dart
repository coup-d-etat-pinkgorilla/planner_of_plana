import 'package:flutter/foundation.dart';

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
