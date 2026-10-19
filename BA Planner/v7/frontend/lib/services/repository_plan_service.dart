import '../ui/models/planning_models.dart';
import 'scenario_service.dart';
export 'planning_authoring.dart';

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
    required this._storedAuthoring,
  });

  final String profileId;
  final int revision;
  final PlanningDocument document;
  final PlanningScenarioCalculationSummary? calculation;
  final PlanningAuthoring? _storedAuthoring;
  bool get hasAuthoring => _storedAuthoring != null;
  PlanningAuthoring get authoring =>
      _storedAuthoring ?? PlanningAuthoring.defaultForDocument(document);

  factory RepositoryPlanState.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {
          'profile_id',
          'revision',
          'document',
          'calculation',
          if (value.containsKey('authoring')) 'authoring',
        }) ||
        !_profileId(value['profile_id']) ||
        value['revision'] is! int ||
        value['revision'] < 0 ||
        (value['calculation'] != null && value['calculation'] is! Map)) {
      throw const FormatException('Invalid repository plan state');
    }
    final document = repositoryActiveDocument(value['document']);
    return RepositoryPlanState._(
      profileId: value['profile_id'] as String,
      revision: value['revision'] as int,
      document: document,
      storedAuthoring: value.containsKey('authoring')
          ? PlanningAuthoring.fromWire(value['authoring'], document)
          : null,
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
    this.authoring,
  });
  final String profileId;
  final int expectedRevision;
  final String idempotencyKey;
  final PlanningDocument document;
  final PlanningAuthoring? authoring;

  factory RepositoryPlanSaveRequest.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {
          'profile_id',
          'expected_revision',
          'idempotency_key',
          'document',
          if (value.containsKey('authoring')) 'authoring',
        }) ||
        !_profileId(value['profile_id']) ||
        value['expected_revision'] is! int ||
        value['idempotency_key'] is! String) {
      throw const FormatException('Invalid plan save request');
    }
    final document = repositoryActiveDocument(value['document']);
    final request = RepositoryPlanSaveRequest(
      profileId: value['profile_id'] as String,
      expectedRevision: value['expected_revision'] as int,
      idempotencyKey: value['idempotency_key'] as String,
      document: document,
      authoring: value.containsKey('authoring')
          ? PlanningAuthoring.fromWire(value['authoring'], document)
          : null,
    );
    request.toWire();
    return request;
  }

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
      if (authoring != null)
        'authoring': PlanningAuthoring.fromWire(
          authoring!.toWire(),
          document,
        ).toWire(),
    };
  }
}

class RepositoryPlanReplaceRequest extends RepositoryPlanSaveRequest {
  const RepositoryPlanReplaceRequest({
    required super.profileId,
    required super.expectedRevision,
    required super.idempotencyKey,
    required super.document,
    super.authoring,
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
          if (value.containsKey('authoring')) 'authoring',
        }) ||
        !_profileId(value['profile_id']) ||
        value['expected_revision'] is! int ||
        value['expected_scenario_revision'] is! int ||
        value['idempotency_key'] is! String ||
        value['archive_name'] is! String ||
        value['archive_description'] is! String) {
      throw const FormatException('Invalid plan replace request');
    }
    final document = repositoryActiveDocument(value['document']);
    final request = RepositoryPlanReplaceRequest(
      profileId: value['profile_id'] as String,
      expectedRevision: value['expected_revision'] as int,
      expectedScenarioRevision: value['expected_scenario_revision'] as int,
      idempotencyKey: value['idempotency_key'] as String,
      document: document,
      authoring: value.containsKey('authoring')
          ? PlanningAuthoring.fromWire(value['authoring'], document)
          : null,
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
    PlanningAuthoring? authoring,
    required int expectedRevision,
    required String idempotencyKey,
  });
  Future<RepositoryPlanReplaceResult> replaceRepositoryPlan({
    required String profileId,
    required PlanningDocument document,
    PlanningAuthoring? authoring,
    required int expectedRevision,
    required int expectedScenarioRevision,
    required String idempotencyKey,
    required String archiveName,
    required String archiveDescription,
  });
}
