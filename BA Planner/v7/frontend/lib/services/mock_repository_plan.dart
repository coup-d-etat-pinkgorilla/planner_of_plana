import 'dart:convert';

import '../ui/models/planning_models.dart';
import 'repository_service.dart';

final _targetToGoal = <String, String>{
  for (final key in planningDocumentTargetKeys)
    if (key != 'bond_rank')
      key: key == 'student_star' ? 'target_star' : 'target_$key',
};

PlanningDocument mockDocumentFromGoals(Map<String, dynamic> value) {
  if (value.length != 2 || value['version'] != 1 || value['goals'] is! List) {
    throw const FormatException('Invalid legacy goal plan');
  }
  final goals = [
    for (final raw in value['goals'] as List)
      RepositoryGoalState.fromWire(Map<String, dynamic>.from(raw as Map)),
  ];
  if (goals.map((goal) => goal.studentId).toSet().length != goals.length) {
    throw StateError('legacy_goals_conflict');
  }
  return repositoryActiveDocument({
    'version': 2,
    'document_id': 'active-plan',
    'name': '활성 계획',
    'kind': 'plan',
    'phases': [
      if (goals.isNotEmpty)
        {
          'phase_id': 'v6-imported-plan',
          'name': 'v6 목표',
          'stages': [
            for (final goal in goals)
              {
                'stage_id': 'v6-${goal.studentId}-1',
                'student_id': goal.studentId,
                'name': (goal.values['notes'] as String? ?? '').trim().isEmpty
                    ? 'v6 목표'
                    : (goal.values['notes'] as String).trim(),
                'targets': {
                  for (final entry in _targetToGoal.entries)
                    entry.key: goal.values[entry.value],
                  'bond_rank': null,
                },
              },
          ],
        },
    ],
    'goal_metadata': {
      for (final goal in goals)
        goal.studentId: {
          'favorite': goal.values['favorite'] ?? true,
          'notes': goal.values['notes'] ?? '',
        },
    },
  });
}

Map<String, dynamic> mockGoalsFromDocument(PlanningDocument value) {
  final document = repositoryActiveDocument(value.toWire());
  final finalStages = <String, PlanningDocumentStage>{};
  for (final stage in document.stages) {
    finalStages[stage.studentId] = stage;
  }
  return {
    'version': 1,
    'goals': [
      for (final stage in finalStages.values)
        {
          'student_id': stage.studentId,
          'favorite': document.goalMetadata[stage.studentId]!.favorite,
          'notes': document.goalMetadata[stage.studentId]!.notes,
          for (final entry in _targetToGoal.entries)
            entry.value: stage.nullableTargets[entry.key],
        },
    ],
  };
}

bool mockLegacyWriteLosesPlan(PlanningDocument document) =>
    document.phases.length > 1 ||
    document.stages.map((stage) => stage.studentId).toSet().length !=
        document.stages.length ||
    document.stages.any((stage) => stage.nullableTargets['bond_rank'] != null);

String mockPlanFingerprint(Object? value) {
  Object? sorted(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: sorted(value[key])};
    }
    if (value is List) return value.map(sorted).toList();
    return value;
  }

  return jsonEncode(sorted(value));
}
