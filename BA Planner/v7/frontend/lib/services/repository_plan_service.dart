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

class RepositoryPlanReplaceRequest extends RepositoryPlanSaveRequest {
  const RepositoryPlanReplaceRequest({
    required super.profileId,
    required super.expectedRevision,
    required super.idempotencyKey,
    required super.document,
    required this.expectedScenarioRevision,
    required this.archiveName,
    required this.archiveDescription,
  });

  final int expectedScenarioRevision;
  final String archiveName;
  final String archiveDescription;

  factory RepositoryPlanReplaceRequest.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {
          'profile_id',
          'expected_revision',
          'expected_scenario_revision',
          'idempotency_key',
          'document',
          'archive_name',
          'archive_description',
        }) ||
        !_profileId(value['profile_id']) ||
        value['expected_revision'] is! int ||
        value['expected_scenario_revision'] is! int ||
        value['idempotency_key'] is! String ||
        value['archive_name'] is! String ||
        value['archive_description'] is! String) {
      throw const FormatException('Invalid plan replace request');
    }
    final request = RepositoryPlanReplaceRequest(
      profileId: value['profile_id'] as String,
      expectedRevision: value['expected_revision'] as int,
      expectedScenarioRevision: value['expected_scenario_revision'] as int,
      idempotencyKey: value['idempotency_key'] as String,
      document: repositoryActiveDocument(value['document']),
      archiveName: value['archive_name'] as String,
      archiveDescription: value['archive_description'] as String,
    );
    request.toWire();
    return request;
  }

  @override
  Map<String, dynamic> toWire() {
    if (expectedScenarioRevision < 0 || archiveName.trim().isEmpty) {
      throw const FormatException('Invalid plan replace archive/revision');
    }
    return {
      ...super.toWire(),
      'expected_scenario_revision': expectedScenarioRevision,
      'archive_name': archiveName.trim(),
      'archive_description': archiveDescription.trim(),
    };
  }
}

class RepositoryPlanReplaceResult {
  const RepositoryPlanReplaceResult._({
    required this.revision,
    required this.scenarioRevision,
    required this.archivedScenarioId,
  });

  final int revision;
  final int scenarioRevision;
  final String? archivedScenarioId;

  factory RepositoryPlanReplaceResult.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {
          'revision',
          'scenario_revision',
          'archived_scenario_id',
        }) ||
        value['revision'] is! int ||
        value['revision'] < 0 ||
        value['scenario_revision'] is! int ||
        value['scenario_revision'] < 0 ||
        (value['archived_scenario_id'] != null &&
            !_profileId(value['archived_scenario_id']))) {
      throw const FormatException('Invalid plan replace result');
    }
    return RepositoryPlanReplaceResult._(
      revision: value['revision'] as int,
      scenarioRevision: value['scenario_revision'] as int,
      archivedScenarioId: value['archived_scenario_id'] as String?,
    );
  }

  Map<String, dynamic> toWire() => {
    'revision': revision,
    'scenario_revision': scenarioRevision,
    'archived_scenario_id': archivedScenarioId,
  };
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
  Future<RepositoryPlanReplaceResult> replaceRepositoryPlan({
    required String profileId,
    required PlanningDocument document,
    required int expectedRevision,
    required int expectedScenarioRevision,
    required String idempotencyKey,
    required String archiveName,
    required String archiveDescription,
  });
}
