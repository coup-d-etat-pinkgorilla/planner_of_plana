import '../ui/models/planning_models.dart';

/// Transport bounds, independent of the number of catalog students.
const repositoryPresetLimits = {
  'stage_presets': 100,
  'stages_per_preset': 50,
  'total_stages': 1000,
  'student_groups': 100,
  'students_per_group': 1000,
  'total_memberships': 10000,
  'name_length': 120,
  'id_length': 128,
};

bool _exact(Map<String, dynamic> value, Set<String> keys) =>
    value.length == keys.length && value.keys.toSet().containsAll(keys);

Map<String, dynamic> _map(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected a preset object');
  }
  return Map<String, dynamic>.from(value);
}

String _text(Object? value, {bool name = false}) {
  final maximum = repositoryPresetLimits[name ? 'name_length' : 'id_length']!;
  if (value is! String ||
      value.trim().isEmpty ||
      value.runes.length > maximum) {
    throw FormatException(
      'Expected non-blank text of at most $maximum code points',
    );
  }
  return name ? value.trim() : value;
}

List<dynamic> _array(Object? value, String limit) {
  if (value is! List || value.length > repositoryPresetLimits[limit]!) {
    throw FormatException('Invalid preset array: $limit');
  }
  return value;
}

void _identity(Object? profileId, Object? revision) {
  if (profileId is! String ||
      !RegExp(r'^[0-9a-f]{24}$').hasMatch(profileId) ||
      revision is! int ||
      revision < 0) {
    throw const FormatException(
      'Invalid preset collection identity or revision',
    );
  }
}

class RepositoryPresetStage {
  RepositoryPresetStage({
    required String name,
    required Map<String, int?> targets,
  }) : this._fromWire({'name': name, 'targets': targets});

  RepositoryPresetStage._fromWire(Map<String, dynamic> value)
    : name = _stageName(value),
      targets = _stageTargets(value);

  factory RepositoryPresetStage.fromWire(Map<String, dynamic> value) =>
      RepositoryPresetStage._fromWire(value);

  final String name;
  final Map<String, int?> targets;

  static String _stageName(Map<String, dynamic> value) {
    if (!_exact(value, {'name', 'targets'})) {
      throw const FormatException('Invalid preset stage shape');
    }
    return _text(value['name'], name: true);
  }

  static Map<String, int?> _stageTargets(Map<String, dynamic> value) {
    // Share the document v2 range/key parser, without synthesizing current values.
    try {
      final stage = PlanningDocumentStage.fromWire({
        'stage_id': 'preset-stage',
        'student_id': 'preset-student',
        'name': 'preset-stage',
        'targets': value['targets'],
      }, version: 2);
      return Map<String, int?>.unmodifiable(stage.nullableTargets);
    } on TypeError {
      throw const FormatException('Invalid nullable preset targets');
    }
  }

  Map<String, dynamic> toWire() => {
    'name': name,
    'targets': {...targets},
  };
}

class RepositoryStagePreset {
  RepositoryStagePreset({
    required String presetId,
    required String name,
    required List<RepositoryPresetStage> stages,
  }) : this._fromWire({
         'preset_id': presetId,
         'name': name,
         'stages': stages.map((stage) => stage.toWire()).toList(),
       });

  RepositoryStagePreset._fromWire(Map<String, dynamic> value)
    : presetId = _presetId(value),
      name = _text(value['name'], name: true),
      stages = _stages(value['stages']);

  factory RepositoryStagePreset.fromWire(Map<String, dynamic> value) =>
      RepositoryStagePreset._fromWire(value);

  final String presetId;
  final String name;
  final List<RepositoryPresetStage> stages;

  static String _presetId(Map<String, dynamic> value) {
    if (!_exact(value, {'preset_id', 'name', 'stages'})) {
      throw const FormatException('Invalid stage preset shape');
    }
    return _text(value['preset_id']);
  }

  static List<RepositoryPresetStage> _stages(Object? value) {
    final stages = <RepositoryPresetStage>[];
    Map<String, int?>? previous;
    for (final raw in _array(value, 'stages_per_preset')) {
      final stage = RepositoryPresetStage.fromWire(_map(raw));
      if (previous != null) {
        for (final key in planningDocumentTargetKeys) {
          final before = previous[key];
          final after = stage.targets[key];
          if (before != null && (after == null || after < before)) {
            throw FormatException('Preset target $key regresses');
          }
        }
      }
      stages.add(stage);
      previous = stage.targets;
    }
    return List<RepositoryPresetStage>.unmodifiable(stages);
  }

  Map<String, dynamic> toWire() => {
    'preset_id': presetId,
    'name': name,
    'stages': stages.map((stage) => stage.toWire()).toList(),
  };
}

class RepositoryStudentGroup {
  RepositoryStudentGroup({
    required String groupId,
    required String name,
    required List<String> studentIds,
  }) : this._fromWire({
         'group_id': groupId,
         'name': name,
         'student_ids': studentIds,
       });

  RepositoryStudentGroup._fromWire(Map<String, dynamic> value)
    : groupId = _groupId(value),
      name = _text(value['name'], name: true),
      studentIds = _students(value['student_ids']);

  factory RepositoryStudentGroup.fromWire(Map<String, dynamic> value) =>
      RepositoryStudentGroup._fromWire(value);

  final String groupId;
  final String name;
  final List<String> studentIds;

  static String _groupId(Map<String, dynamic> value) {
    if (!_exact(value, {'group_id', 'name', 'student_ids'})) {
      throw const FormatException('Invalid student group shape');
    }
    return _text(value['group_id']);
  }

  static List<String> _students(Object? value) {
    final ids = _array(value, 'students_per_group').map(_text).toList();
    if (ids.toSet().length != ids.length) {
      throw const FormatException('Student IDs within a group must be unique');
    }
    return List<String>.unmodifiable(ids);
  }

  Map<String, dynamic> toWire() => {
    'group_id': groupId,
    'name': name,
    'student_ids': [...studentIds],
  };
}

class RepositoryPresetsState {
  RepositoryPresetsState._({
    required this.profileId,
    required this.revision,
    required this.stagePresets,
    required this.studentGroups,
  });

  factory RepositoryPresetsState.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {
      'profile_id',
      'revision',
      'stage_presets',
      'student_groups',
    })) {
      throw const FormatException('Invalid preset collection shape');
    }
    _identity(value['profile_id'], value['revision']);
    final presets = _array(
      value['stage_presets'],
      'stage_presets',
    ).map((raw) => RepositoryStagePreset.fromWire(_map(raw))).toList();
    final groups = _array(
      value['student_groups'],
      'student_groups',
    ).map((raw) => RepositoryStudentGroup.fromWire(_map(raw))).toList();
    if (presets.map((preset) => preset.presetId).toSet().length !=
            presets.length ||
        groups.map((group) => group.groupId).toSet().length != groups.length ||
        presets.fold<int>(0, (sum, preset) => sum + preset.stages.length) >
            repositoryPresetLimits['total_stages']! ||
        groups.fold<int>(0, (sum, group) => sum + group.studentIds.length) >
            repositoryPresetLimits['total_memberships']!) {
      throw const FormatException(
        'Duplicate preset/group IDs or total count exceeds limit',
      );
    }
    return RepositoryPresetsState._(
      profileId: value['profile_id'] as String,
      revision: value['revision'] as int,
      stagePresets: List<RepositoryStagePreset>.unmodifiable(presets),
      studentGroups: List<RepositoryStudentGroup>.unmodifiable(groups),
    );
  }

  final String profileId;
  final int revision;
  final List<RepositoryStagePreset> stagePresets;
  final List<RepositoryStudentGroup> studentGroups;

  Map<String, dynamic> toWire() => {
    'profile_id': profileId,
    'revision': revision,
    'stage_presets': stagePresets.map((preset) => preset.toWire()).toList(),
    'student_groups': studentGroups.map((group) => group.toWire()).toList(),
  };
}

class RepositoryPresetsSaveRequest {
  RepositoryPresetsSaveRequest({
    required this.profileId,
    required this.expectedRevision,
    required this.idempotencyKey,
    required List<RepositoryStagePreset> stagePresets,
    required List<RepositoryStudentGroup> studentGroups,
  }) : _state = RepositoryPresetsState.fromWire({
         'profile_id': profileId,
         'revision': expectedRevision,
         'stage_presets': stagePresets
             .map((preset) => preset.toWire())
             .toList(),
         'student_groups': studentGroups
             .map((group) => group.toWire())
             .toList(),
       }) {
    if (idempotencyKey.isEmpty) {
      throw const FormatException('Empty idempotency key');
    }
  }

  factory RepositoryPresetsSaveRequest.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {
          'profile_id',
          'expected_revision',
          'idempotency_key',
          'stage_presets',
          'student_groups',
        }) ||
        value['idempotency_key'] is! String ||
        (value['idempotency_key'] as String).isEmpty) {
      throw const FormatException('Invalid preset save request');
    }
    final state = RepositoryPresetsState.fromWire({
      'profile_id': value['profile_id'],
      'revision': value['expected_revision'],
      'stage_presets': value['stage_presets'],
      'student_groups': value['student_groups'],
    });
    return RepositoryPresetsSaveRequest(
      profileId: state.profileId,
      expectedRevision: state.revision,
      idempotencyKey: value['idempotency_key'] as String,
      stagePresets: state.stagePresets,
      studentGroups: state.studentGroups,
    );
  }

  final String profileId;
  final int expectedRevision;
  final String idempotencyKey;
  final RepositoryPresetsState _state;
  List<RepositoryStagePreset> get stagePresets => _state.stagePresets;
  List<RepositoryStudentGroup> get studentGroups => _state.studentGroups;

  Map<String, dynamic> toWire() => {
    'profile_id': profileId,
    'expected_revision': expectedRevision,
    'idempotency_key': idempotencyKey,
    'stage_presets': stagePresets.map((preset) => preset.toWire()).toList(),
    'student_groups': studentGroups.map((group) => group.toWire()).toList(),
  };
}

/// A capability separate from RepositoryService to preserve existing consumers.
abstract interface class RepositoryPresetsService {
  Future<RepositoryPresetsState> loadRepositoryPresets(String profileId);
  Future<int> saveRepositoryPresets(RepositoryPresetsSaveRequest request);
}
