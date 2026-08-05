import '../ui/models/planning_models.dart';

final _scenarioId = RegExp(r'^[0-9a-f]{24}$');

Map<String, dynamic> _map(Object? value, String label) {
  if (value is! Map) throw FormatException('$label must be an object');
  return Map<String, dynamic>.from(value);
}

bool _exact(Map<String, dynamic> value, Set<String> keys) =>
    value.keys.toSet().length == keys.length &&
    value.keys.toSet().containsAll(keys);

class PlanningScenarioSummary {
  const PlanningScenarioSummary({
    required this.id,
    required this.revision,
    required this.name,
    required this.description,
    required this.baseProfileRevision,
    required this.phaseCount,
    required this.stageCount,
    required this.studentCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int revision;
  final String name;
  final String description;
  final int baseProfileRevision;
  final int phaseCount;
  final int stageCount;
  final int studentCount;
  final String createdAt;
  final String updatedAt;

  factory PlanningScenarioSummary.fromWire(Map<String, dynamic> value) {
    const keys = {
      'scenario_id',
      'revision',
      'name',
      'description',
      'base_profile_revision',
      'phase_count',
      'stage_count',
      'student_count',
      'created_at',
      'updated_at',
    };
    if (!_exact(value, keys) ||
        value['scenario_id'] is! String ||
        !_scenarioId.hasMatch(value['scenario_id'] as String) ||
        value['revision'] is! int ||
        value['revision'] < 0 ||
        value['name'] is! String ||
        (value['name'] as String).isEmpty ||
        value['description'] is! String ||
        value['base_profile_revision'] is! int ||
        value['base_profile_revision'] < 0 ||
        value['phase_count'] is! int ||
        value['phase_count'] < 0 ||
        value['stage_count'] is! int ||
        value['stage_count'] < 0 ||
        value['student_count'] is! int ||
        value['student_count'] < 0 ||
        value['created_at'] is! String ||
        (value['created_at'] as String).isEmpty ||
        value['updated_at'] is! String ||
        (value['updated_at'] as String).isEmpty) {
      throw const FormatException('Invalid scenario summary');
    }
    return PlanningScenarioSummary(
      id: value['scenario_id'] as String,
      revision: value['revision'] as int,
      name: value['name'] as String,
      description: value['description'] as String,
      baseProfileRevision: value['base_profile_revision'] as int,
      phaseCount: value['phase_count'] as int,
      stageCount: value['stage_count'] as int,
      studentCount: value['student_count'] as int,
      createdAt: value['created_at'] as String,
      updatedAt: value['updated_at'] as String,
    );
  }
}

class PlanningScenarioRecord {
  const PlanningScenarioRecord({
    required this.id,
    required this.revision,
    required this.profileId,
    required this.name,
    required this.description,
    required this.baseProfileRevision,
    required this.document,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int revision;
  final String profileId;
  final String name;
  final String description;
  final int baseProfileRevision;
  final PlanningDocument document;
  final String createdAt;
  final String updatedAt;

  bool isStaleAgainst(int currentProfileRevision) =>
      baseProfileRevision != currentProfileRevision;

  factory PlanningScenarioRecord.fromWire(Map<String, dynamic> value) {
    const keys = {
      'version',
      'scenario_id',
      'revision',
      'profile_id',
      'name',
      'description',
      'base_profile_revision',
      'document',
      'created_at',
      'updated_at',
    };
    if (!_exact(value, keys) ||
        value['version'] != 1 ||
        value['scenario_id'] is! String ||
        !_scenarioId.hasMatch(value['scenario_id'] as String) ||
        value['profile_id'] is! String ||
        !_scenarioId.hasMatch(value['profile_id'] as String) ||
        value['revision'] is! int ||
        value['revision'] < 0 ||
        value['name'] is! String ||
        (value['name'] as String).isEmpty ||
        value['description'] is! String ||
        value['base_profile_revision'] is! int ||
        value['base_profile_revision'] < 0 ||
        value['created_at'] is! String ||
        (value['created_at'] as String).isEmpty ||
        value['updated_at'] is! String ||
        (value['updated_at'] as String).isEmpty) {
      throw const FormatException('Invalid scenario record');
    }
    final document = PlanningDocument.fromWire(
      _map(value['document'], 'scenario document'),
    );
    if (document.kind != PlanningDocumentKind.scenario) {
      throw const FormatException('Scenario document must use scenario kind');
    }
    return PlanningScenarioRecord(
      id: value['scenario_id'] as String,
      revision: value['revision'] as int,
      profileId: value['profile_id'] as String,
      name: value['name'] as String,
      description: value['description'] as String,
      baseProfileRevision: value['base_profile_revision'] as int,
      document: document,
      createdAt: value['created_at'] as String,
      updatedAt: value['updated_at'] as String,
    );
  }
}

class PlanningScenarioListResult {
  const PlanningScenarioListResult({
    required this.profileId,
    required this.revision,
    required this.currentProfileRevision,
    required this.scenarios,
  });

  final String profileId;
  final int revision;
  final int currentProfileRevision;
  final List<PlanningScenarioSummary> scenarios;

  factory PlanningScenarioListResult.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {
          'profile_id',
          'revision',
          'current_profile_revision',
          'scenarios',
        }) ||
        value['profile_id'] is! String ||
        !_scenarioId.hasMatch(value['profile_id'] as String) ||
        value['revision'] is! int ||
        value['revision'] < 0 ||
        value['current_profile_revision'] is! int ||
        value['current_profile_revision'] < 0 ||
        value['scenarios'] is! List) {
      throw const FormatException('Invalid scenario list');
    }
    return PlanningScenarioListResult(
      profileId: value['profile_id'] as String,
      revision: value['revision'] as int,
      currentProfileRevision: value['current_profile_revision'] as int,
      scenarios: List.unmodifiable([
        for (final item in value['scenarios'] as List)
          PlanningScenarioSummary.fromWire(_map(item, 'scenario summary')),
      ]),
    );
  }
}

class PlanningScenarioGetResult {
  const PlanningScenarioGetResult({
    required this.profileId,
    required this.revision,
    required this.currentProfileRevision,
    required this.scenario,
  });

  final String profileId;
  final int revision;
  final int currentProfileRevision;
  final PlanningScenarioRecord scenario;

  factory PlanningScenarioGetResult.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {
          'profile_id',
          'revision',
          'current_profile_revision',
          'scenario',
        }) ||
        value['profile_id'] is! String ||
        value['revision'] is! int ||
        value['revision'] < 0 ||
        value['current_profile_revision'] is! int ||
        value['current_profile_revision'] < 0) {
      throw const FormatException('Invalid scenario get result');
    }
    final scenario = PlanningScenarioRecord.fromWire(
      _map(value['scenario'], 'scenario'),
    );
    if (scenario.profileId != value['profile_id']) {
      throw const FormatException('Scenario profile mismatch');
    }
    return PlanningScenarioGetResult(
      profileId: value['profile_id'] as String,
      revision: value['revision'] as int,
      currentProfileRevision: value['current_profile_revision'] as int,
      scenario: scenario,
    );
  }
}

class PlanningScenarioMutationResult {
  const PlanningScenarioMutationResult({
    required this.revision,
    required this.scenarioId,
  });

  final int revision;
  final String scenarioId;

  factory PlanningScenarioMutationResult.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {'revision', 'scenario_id'}) ||
        value['revision'] is! int ||
        value['revision'] < 1 ||
        value['scenario_id'] is! String ||
        !_scenarioId.hasMatch(value['scenario_id'] as String)) {
      throw const FormatException('Invalid scenario mutation result');
    }
    return PlanningScenarioMutationResult(
      revision: value['revision'] as int,
      scenarioId: value['scenario_id'] as String,
    );
  }
}

class PlanningScenarioComparisonResult {
  const PlanningScenarioComparisonResult({
    required this.projectionA,
    required this.projectionB,
    required this.comparison,
  });

  final Map<String, dynamic> projectionA;
  final Map<String, dynamic> projectionB;
  final Map<String, dynamic> comparison;

  factory PlanningScenarioComparisonResult.fromWire(
    Map<String, dynamic> value,
  ) {
    if (!_exact(value, {'projection_a', 'projection_b', 'comparison'})) {
      throw const FormatException('Invalid scenario comparison');
    }
    return PlanningScenarioComparisonResult(
      projectionA: Map.unmodifiable(
        _map(value['projection_a'], 'projection A'),
      ),
      projectionB: Map.unmodifiable(
        _map(value['projection_b'], 'projection B'),
      ),
      comparison: Map.unmodifiable(_map(value['comparison'], 'comparison')),
    );
  }
}

bool isValidScenarioSuccessPayload(
  String method,
  Map<String, dynamic> payload,
) {
  try {
    switch (method) {
      case 'repository.scenario.list':
        PlanningScenarioListResult.fromWire(payload);
      case 'repository.scenario.get':
        PlanningScenarioGetResult.fromWire(payload);
      case 'repository.scenario.create':
      case 'repository.scenario.update':
      case 'repository.scenario.delete':
      case 'repository.scenario.duplicate':
        PlanningScenarioMutationResult.fromWire(payload);
      default:
        return false;
    }
    return true;
  } on Object {
    return false;
  }
}

abstract interface class PlanningScenarioRepositoryService {
  Future<PlanningScenarioListResult> listScenarios(String profileId);
  Future<PlanningScenarioGetResult> getScenario(
    String profileId,
    String scenarioId,
  );
  Future<PlanningScenarioMutationResult> createScenario({
    required String profileId,
    required int expectedRevision,
    required String idempotencyKey,
    required String name,
    required String description,
    required int baseProfileRevision,
    required PlanningDocument document,
  });
  Future<PlanningScenarioMutationResult> updateScenario({
    required String profileId,
    required String scenarioId,
    required int expectedRevision,
    required int expectedScenarioRevision,
    required String idempotencyKey,
    required String name,
    required String description,
    required int baseProfileRevision,
    required PlanningDocument document,
  });
  Future<PlanningScenarioMutationResult> deleteScenario({
    required String profileId,
    required String scenarioId,
    required int expectedRevision,
    required int expectedScenarioRevision,
    required String idempotencyKey,
  });
  Future<PlanningScenarioMutationResult> duplicateScenario({
    required String profileId,
    required String scenarioId,
    required int expectedRevision,
    required int expectedScenarioRevision,
    required String idempotencyKey,
  });
}

abstract interface class PlanningScenarioComparisonService {
  Future<PlanningScenarioComparisonResult> compareScenarios({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required PlanningDocument documentA,
    required PlanningDocument documentB,
  });
}
