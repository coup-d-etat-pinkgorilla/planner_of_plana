import '../ui/models/planning_models.dart';
import 'scenario_service.dart';

bool _exact(Map<String, dynamic> value, Set<String> keys) =>
    value.length == keys.length && value.keys.toSet().containsAll(keys);
bool _profileId(Object? value) =>
    value is String && RegExp(r'^[0-9a-f]{24}$').hasMatch(value);

PlanningDocument repositoryActiveDocument(Object? value) {
  if (value is! Map) throw const FormatException('Invalid active document');
  try {
    final document = PlanningDocument.fromWire(
      Map<String, dynamic>.from(value),
    );
    if (document.version != 2 || document.kind != PlanningDocumentKind.plan) {
      throw const FormatException('Active document requires v2 kind=plan');
    }
    return document;
  } on TypeError {
    throw const FormatException('Invalid active document fields');
  }
}

class RepositoryPlanState {
  const RepositoryPlanState._({
    required this.profileId,
    required this.revision,
    required this.document,
    required this.calculation,
  });

  final String profileId;
  final int revision;
  final PlanningDocument document;
  final PlanningScenarioCalculationSummary? calculation;

  factory RepositoryPlanState.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {'profile_id', 'revision', 'document', 'calculation'}) ||
        !_profileId(value['profile_id']) ||
        value['revision'] is! int ||
        value['revision'] < 0 ||
        (value['calculation'] != null && value['calculation'] is! Map)) {
      throw const FormatException('Invalid repository plan state');
    }
    return RepositoryPlanState._(
      profileId: value['profile_id'] as String,
      revision: value['revision'] as int,
      document: repositoryActiveDocument(value['document']),
      calculation: value['calculation'] == null
          ? null
          : PlanningScenarioCalculationSummary.fromWire(
              Map<String, dynamic>.from(value['calculation'] as Map),
            ),
    );
  }
}

class RepositoryPlanSaveRequest {
  const RepositoryPlanSaveRequest({
    required this.profileId,
    required this.expectedRevision,
    required this.idempotencyKey,
    required this.document,
  });
  final String profileId;
  final int expectedRevision;
  final String idempotencyKey;
  final PlanningDocument document;

  Map<String, dynamic> toWire() {
    if (!_profileId(profileId) ||
        expectedRevision < 0 ||
        idempotencyKey.isEmpty) {
      throw const FormatException('Invalid plan save request');
    }
    final wire = document.toWire();
    repositoryActiveDocument(wire);
    return {
      'profile_id': profileId,
      'expected_revision': expectedRevision,
      'idempotency_key': idempotencyKey,
      'document': wire,
    };
  }
}

/// Capability keeps existing RepositoryService test doubles source compatible.
abstract interface class RepositoryPlanService {
  Future<RepositoryPlanState> loadRepositoryPlan(String profileId);
  Future<int> saveRepositoryPlan({
    required String profileId,
    required PlanningDocument document,
    required int expectedRevision,
    required String idempotencyKey,
  });
}
