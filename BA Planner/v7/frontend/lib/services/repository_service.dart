import 'planning_protocol_client.dart' show BackendRemoteException;
import 'repository_plan_service.dart';
import 'repository_presets_service.dart';
import 'repository_history_service.dart';
import 'repository_inventory_review.dart';
export 'repository_plan_service.dart';
export 'repository_presets_service.dart';
export 'repository_history_service.dart';
export 'repository_inventory_review.dart';

class RepositoryProfile {
  const RepositoryProfile({
    required this.id,
    required this.displayName,
    this.avatarStudentId = 'hasumi',
    required this.revision,
    required this.selected,
    this.isPractice = false,
  });

  final String id;
  final String displayName;
  final String avatarStudentId;
  final int revision;
  final bool selected;

  /// 튜토리얼 임시 계정(X4 / FD-182 `is_practice`). 지금 백엔드 profile 응답 schema에는 이 키가 없으므로 wire에서는
  /// 키가 없을 때(= false)만 받는다. 키를 받아들이는 것은 runtime 짝 라운드(계약 "optional boolean, absent means false").
  final bool isPractice;

  factory RepositoryProfile.fromWire(Map<String, dynamic> value) {
    final id = value['profile_id'];
    final name = value['display_name'];
    final revision = value['revision'];
    final selected = value['selected'];
    final avatarStudentId = value['avatar_student_id'] ?? 'hasumi';
    if (value.containsKey('is_practice') ||
        id is! String ||
        !RegExp(r'^[0-9a-f]{24}$').hasMatch(id) ||
        name is! String ||
        name.isEmpty ||
        avatarStudentId is! String ||
        avatarStudentId.isEmpty ||
        revision is! int ||
        revision < 0 ||
        selected is! bool) {
      throw const FormatException('Invalid repository profile payload');
    }
    return RepositoryProfile(
      id: id,
      displayName: name,
      avatarStudentId: avatarStudentId,
      revision: revision,
      selected: selected,
    );
  }
}

class RepositoryV6AccountPreview {
  RepositoryV6AccountPreview.fromWire(Map<String, dynamic> value)
    : sourceProfileKey = value['source_profile_key'] as String,
      displayName = value['display_name'] as String,
      avatarStudentId = value['avatar_student_id'] as String,
      studentCount = value['student_count'] as int,
      inventoryCount = value['inventory_count'] as int,
      goalCount = value['goal_count'] as int,
      warnings = List<String>.unmodifiable(
        (value['warnings'] as List).cast<String>(),
      );

  final String sourceProfileKey;
  final String displayName;
  final String avatarStudentId;
  final int studentCount;
  final int inventoryCount;
  final int goalCount;
  final List<String> warnings;
}

class RepositoryV6ImportResult {
  RepositoryV6ImportResult.fromWire(Map<String, dynamic> value)
    : profile = RepositoryProfile.fromWire(
        Map<String, dynamic>.from(value['profile'] as Map),
      ),
      studentCount = value['student_count'] as int,
      inventoryCount = value['inventory_count'] as int,
      goalCount = value['goal_count'] as int,
      warnings = List<String>.unmodifiable(
        (value['warnings'] as List).cast<String>(),
      );

  final RepositoryProfile profile;
  final int studentCount;
  final int inventoryCount;
  final int goalCount;
  final List<String> warnings;
}

bool _exact(Map<String, dynamic> value, Set<String> keys) =>
    value.keys.toSet().containsAll(keys) && keys.containsAll(value.keys);

bool _revision(Object? value) => value is int && value >= 0;

Map<String, dynamic> _wireMap(Object? value, String label) {
  if (value is! Map) throw FormatException('$label must be an object');
  return Map<String, dynamic>.from(value);
}

class ConfirmedStudentState {
  ConfirmedStudentState._(
    this.studentId,
    Map<String, dynamic> values,
    Map<String, String>? provenance,
  ) : values = Map.unmodifiable(values),
      provenance = provenance == null ? null : Map.unmodifiable(provenance);

  final String studentId;
  final Map<String, dynamic> values;
  final Map<String, String>? provenance;

  factory ConfirmedStudentState.fromValues(
    String studentId,
    Map<String, dynamic> values,
  ) => ConfirmedStudentState.fromWire({
    'version': 1,
    'student_id': studentId,
    'values': values,
  });

  Map<String, dynamic> toWire() => {
    'version': 1,
    'student_id': studentId,
    'values': Map<String, dynamic>.from(values),
    if (provenance != null) 'provenance': Map<String, String>.from(provenance!),
  };

  factory ConfirmedStudentState.fromWire(Map<String, dynamic> value) {
    const required = {'version', 'student_id', 'values'};
    const allowed = {'version', 'student_id', 'values', 'provenance'};
    if (!value.keys.toSet().containsAll(required) ||
        !allowed.containsAll(value.keys) ||
        value['version'] != 1 ||
        value['student_id'] is! String ||
        (value['student_id'] as String).isEmpty) {
      throw const FormatException('Invalid confirmed student');
    }
    final values = _wireMap(value['values'], 'confirmed student values');
    const integerFields = {
      'level',
      'bond_rank',
      'student_star',
      'weapon_star',
      'weapon_level',
      'ex_skill',
      'skill1',
      'skill2',
      'skill3',
      'equip1_level',
      'equip2_level',
      'equip3_level',
      'combat_hp',
      'combat_atk',
      'combat_def',
      'combat_heal',
      'stat_hp',
      'stat_atk',
      'stat_heal',
    };
    const stringFields = {
      'weapon_state',
      'equip1',
      'equip2',
      'equip3',
      'equip4',
    };
    const allowedValues = {
      ...integerFields,
      ...stringFields,
      'form_combat_stats',
    };
    if (!allowedValues.containsAll(values.keys)) {
      throw const FormatException('Unknown confirmed student value');
    }
    for (final entry in values.entries) {
      if (integerFields.contains(entry.key) &&
          entry.value != null &&
          entry.value is! int) {
        throw const FormatException('Invalid confirmed integer');
      }
      if (entry.key == 'bond_rank' &&
          entry.value != null &&
          ((entry.value as int) < 1 || (entry.value as int) > 100)) {
        throw const FormatException('Invalid confirmed bond rank');
      }
      if (stringFields.contains(entry.key) &&
          entry.value != null &&
          entry.value is! String) {
        throw const FormatException('Invalid confirmed string');
      }
      if (entry.key == 'form_combat_stats' && entry.value is! Map) {
        throw const FormatException('Invalid combat stats');
      }
    }
    final provenance = value['provenance'];
    if (provenance != null &&
        (provenance is! Map ||
            provenance.entries.any(
              (entry) => entry.key is! String || entry.value is! String,
            ))) {
      throw const FormatException('Invalid confirmed provenance');
    }
    return ConfirmedStudentState._(
      value['student_id'] as String,
      values,
      provenance == null ? null : Map<String, String>.from(provenance as Map),
    );
  }
}

const planningCurrentFields = <String>{
  'level',
  'student_star',
  'weapon_state',
  'weapon_star',
  'weapon_level',
  'ex_skill',
  'skill1',
  'skill2',
  'skill3',
  'equip1',
  'equip2',
  'equip3',
  'equip4',
  'equip1_level',
  'equip2_level',
  'equip3_level',
  'stat_hp',
  'stat_atk',
  'stat_heal',
};

Map<String, dynamic> confirmedStudentPlanningCurrent(
  ConfirmedStudentState student,
) => {
  'student_id': student.studentId,
  for (final entry in student.values.entries)
    if (planningCurrentFields.contains(entry.key) && entry.value != null)
      entry.key: entry.value,
};

class RepositoryGoalState {
  RepositoryGoalState._(this.studentId, Map<String, dynamic> values)
    : values = Map.unmodifiable(values);

  final String studentId;
  final Map<String, dynamic> values;

  factory RepositoryGoalState.fromWire(Map<String, dynamic> value) {
    final studentId = value['student_id'];
    if (studentId is! String || studentId.isEmpty) {
      throw const FormatException('Invalid repository goal');
    }
    const maximums = <String, int>{
      'target_level': 90,
      'target_star': 5,
      'target_weapon_level': 60,
      'target_weapon_star': 4,
      'target_ex_skill': 5,
      'target_skill1': 10,
      'target_skill2': 10,
      'target_skill3': 10,
      'target_equip1_tier': 10,
      'target_equip2_tier': 10,
      'target_equip3_tier': 10,
      'target_equip1_level': 70,
      'target_equip2_level': 70,
      'target_equip3_level': 70,
      'target_equip4_tier': 2,
      'target_stat_hp': 25,
      'target_stat_atk': 25,
      'target_stat_heal': 25,
    };
    final allowed = {'student_id', 'favorite', 'notes', ...maximums.keys};
    if (!allowed.containsAll(value.keys) ||
        (value.containsKey('favorite') && value['favorite'] is! bool) ||
        (value.containsKey('notes') && value['notes'] is! String)) {
      throw const FormatException('Invalid repository goal fields');
    }
    for (final entry in maximums.entries) {
      final target = value[entry.key];
      if (target != null &&
          (target is! int || target < 0 || target > entry.value)) {
        throw const FormatException('Invalid repository goal target');
      }
    }
    return RepositoryGoalState._(studentId, value);
  }
}

class RepositoryInventoryState {
  RepositoryInventoryState._(
    List<Map<String, dynamic>> entries,
    this.catalogRevision,
  ) : entries = List.unmodifiable(
        entries.map(Map<String, dynamic>.unmodifiable),
      );

  final List<Map<String, dynamic>> entries;
  final String? catalogRevision;

  factory RepositoryInventoryState.fromEntries(
    List<Map<String, dynamic>> entries,
  ) => RepositoryInventoryState.fromWire({'version': 1, 'entries': entries});

  Map<String, dynamic> toWire() => {
    'version': 1,
    if (catalogRevision != null) 'catalog_revision': catalogRevision,
    'entries': entries,
  };

  factory RepositoryInventoryState.fromWire(Map<String, dynamic> value) {
    final keys = value.keys.toSet();
    if (!keys.containsAll({'version', 'entries'}) ||
        !{'version', 'entries', 'catalog_revision'}.containsAll(keys) ||
        value['version'] != 1 ||
        (value['catalog_revision'] != null &&
            (value['catalog_revision'] is! String ||
                !RegExp(
                  r'^[0-9a-f]{64}$',
                ).hasMatch(value['catalog_revision'] as String))) ||
        value['entries'] is! List) {
      throw const FormatException('Invalid inventory snapshot');
    }
    final entries = <Map<String, dynamic>>[];
    const required = {'key', 'quantity'};
    const allowed = {
      'key',
      'quantity',
      'item_id',
      'name',
      'index',
      'profile_id',
      'observed_slot',
    };
    for (final raw in value['entries'] as List) {
      final item = _wireMap(raw, 'inventory entry');
      if (!item.keys.toSet().containsAll(required) ||
          !allowed.containsAll(item.keys) ||
          item['key'] is! String ||
          (item['key'] as String).isEmpty ||
          (item['quantity'] != null &&
              (item['quantity'] is! String ||
                  !RegExp(
                    r'^(0|[1-9][0-9]*)$',
                  ).hasMatch(item['quantity'] as String))) ||
          (item['item_id'] != null && item['item_id'] is! String) ||
          (item['name'] != null && item['name'] is! String) ||
          (item['profile_id'] != null && item['profile_id'] is! String) ||
          (item['index'] != null && item['index'] is! int) ||
          (item['observed_slot'] != null &&
              (item['observed_slot'] is! int ||
                  (item['observed_slot'] as int) < 0))) {
        throw const FormatException('Invalid inventory entry');
      }
      entries.add(item);
    }
    final identities = entries
        .map((item) => item['item_id'] ?? item['key'])
        .toList();
    if (identities.toSet().length != identities.length) {
      throw const FormatException('Duplicate inventory identity');
    }
    return RepositoryInventoryState._(
      entries,
      value['catalog_revision'] as String?,
    );
  }
}

class RepositoryState {
  RepositoryState._({
    required this.profileId,
    required this.revision,
    required this.students,
    required this.inventory,
    required this.goals,
  });

  final String profileId;
  final int revision;
  final List<ConfirmedStudentState> students;
  final RepositoryInventoryState inventory;
  final List<RepositoryGoalState> goals;

  factory RepositoryState.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {
          'profile_id',
          'revision',
          'students',
          'inventory',
          'goals',
        }) ||
        value['profile_id'] is! String ||
        !RegExp(r'^[0-9a-f]{24}$').hasMatch(value['profile_id'] as String) ||
        !_revision(value['revision']) ||
        value['students'] is! List) {
      throw const FormatException('Invalid repository state');
    }
    final goals = _wireMap(value['goals'], 'goal plan');
    if (!_exact(goals, {'version', 'goals'}) ||
        goals['version'] != 1 ||
        goals['goals'] is! List) {
      throw const FormatException('Invalid goal plan');
    }
    final students = (value['students'] as List)
        .map(
          (item) => ConfirmedStudentState.fromWire(
            _wireMap(item, 'confirmed student'),
          ),
        )
        .toList();
    if (students.map((item) => item.studentId).toSet().length !=
        students.length) {
      throw const FormatException('Duplicate confirmed student identity');
    }
    return RepositoryState._(
      profileId: value['profile_id'] as String,
      revision: value['revision'] as int,
      students: List.unmodifiable(students),
      inventory: RepositoryInventoryState.fromWire(
        _wireMap(value['inventory'], 'inventory snapshot'),
      ),
      goals: List.unmodifiable(
        (goals['goals'] as List).map(
          (item) => RepositoryGoalState.fromWire(_wireMap(item, 'goal')),
        ),
      ),
    );
  }
}

bool isValidRepositorySuccessPayload(
  String method,
  Map<String, dynamic> payload,
) {
  try {
    switch (method) {
      case 'repository.profile.list':
        if (!_exact(payload, {'profiles', 'selected_profile_id'}) ||
            payload['profiles'] is! List) {
          return false;
        }
        for (final item in payload['profiles'] as List) {
          RepositoryProfile.fromWire(_wireMap(item, 'profile'));
        }
        final selected = payload['selected_profile_id'];
        return selected == null ||
            (selected is String &&
                RegExp(r'^[0-9a-f]{24}$').hasMatch(selected));
      case 'repository.profile.create':
        if (!_exact(payload, {'profile', 'revision'}) ||
            !_revision(payload['revision'])) {
          return false;
        }
        RepositoryProfile.fromWire(_wireMap(payload['profile'], 'profile'));
        return true;
      case 'repository.profile.current':
        if (!_exact(payload, {'profile'})) return false;
        if (payload['profile'] != null) {
          RepositoryProfile.fromWire(_wireMap(payload['profile'], 'profile'));
        }
        return true;
      case 'repository.profile.select':
      case 'repository.profile.rename':
      case 'repository.profile.update':
      case 'repository.profile.delete':
      case 'repository.students.update':
      case 'repository.inventory.update':
      case 'repository.goals.save':
      case 'repository.plan.save':
      case 'repository.presets.save':
        return _exact(payload, {'revision'}) && _revision(payload['revision']);
      case 'repository.state.get':
        RepositoryState.fromWire(payload);
        return true;
      case 'repository.history.summary':
        RepositoryHistorySummaryResult.fromWire(payload);
        return true;
      case 'repository.history.events':
        RepositoryHistoryEventsResult.fromWire(payload);
        return true;
      case 'repository.history.diff':
        RepositoryHistoryDiffResult.fromWire(payload);
        return true;
      case 'repository.history.scan_latest':
        RepositoryHistoryScanLatestResult.fromWire(payload);
        return true;
      case 'repository.inventory.review.get':
        RepositoryInventoryReview.fromWire(payload);
        return true;
      case 'repository.plan.get':
        RepositoryPlanState.fromWire(payload);
        return true;
      case 'repository.presets.get':
        RepositoryPresetsState.fromWire(payload);
        return true;
      case 'repository.plan.replace':
        RepositoryPlanReplaceResult.fromWire(payload);
        return true;
      case 'repository.migration.preview':
        if (!_exact(payload, {'accounts'}) || payload['accounts'] is! List) {
          return false;
        }
        for (final item in payload['accounts'] as List) {
          RepositoryV6AccountPreview.fromWire(
            _wireMap(item, 'v6 account preview'),
          );
        }
        return true;
      case 'repository.migration.import':
        RepositoryV6ImportResult.fromWire(payload);
        return true;
      case 'repository.practice.create':
      case 'repository.practice.current':
      case 'repository.practice.reset':
        PracticeSessionState.fromWire(payload);
        return true;
      case 'repository.practice.end':
        PracticeEndResult.fromWire(payload);
        return true;
      case 'repository.practice.recover':
        PracticeRecoveryResult.fromWire(payload);
        return true;
      default:
        return false;
    }
  } on Object {
    return false;
  }
}

bool isValidRepositoryProtocolMessage(Map<String, dynamic> message) {
  const envelope = {'protocol', 'id', 'type', 'method', 'payload'};
  if (!_exact(message, envelope) ||
      message['protocol'] != 1 ||
      message['id'] is! String ||
      (message['id'] as String).isEmpty ||
      message['method'] is! String ||
      message['payload'] is! Map) {
    return false;
  }
  final method = message['method'] as String;
  final payload = Map<String, dynamic>.from(message['payload'] as Map);
  if (message['type'] == 'response') {
    if (payload.containsKey('error')) {
      if (!_exact(payload, {'error'}) || payload['error'] is! Map) return false;
      final error = Map<String, dynamic>.from(payload['error'] as Map);
      const required = {'code', 'message', 'retryable'};
      const allowed = {'code', 'message', 'retryable', 'details'};
      const codes = {
        'invalid_payload',
        'profile_not_found',
        'profile_name_conflict',
        'revision_conflict',
        'idempotency_conflict',
        'repository_busy',
        'corrupt_data',
        'migration_required',
        'migration_not_supported',
        'migration_source_invalid',
        'persistence_failed',
        'legacy_goals_conflict',
        'plan_lossy_write',
        'unknown_method',
      };
      // practice 메서드는 계약 schema의 오류 코드 9개만이다.
      final allowedCodes = practiceMethods.contains(method)
          ? {for (final code in PracticeErrorCode.values) code.wireName}
          : codes;
      return error.keys.toSet().containsAll(required) &&
          allowed.containsAll(error.keys) &&
          allowedCodes.contains(error['code']) &&
          error['message'] is String &&
          (error['message'] as String).isNotEmpty &&
          error['retryable'] is bool &&
          (!error.containsKey('details') || error['details'] is Map);
    }
    return isValidRepositorySuccessPayload(method, payload);
  }
  if (message['type'] != 'request') return false;
  bool mutation(Set<String> extras) {
    final keys = {
      'profile_id',
      'expected_revision',
      'idempotency_key',
      ...extras,
    };
    return _exact(payload, keys) &&
        payload['profile_id'] is String &&
        RegExp(r'^[0-9a-f]{24}$').hasMatch(payload['profile_id'] as String) &&
        _revision(payload['expected_revision']) &&
        payload['idempotency_key'] is String &&
        (payload['idempotency_key'] as String).isNotEmpty;
  }

  try {
    switch (method) {
      case 'repository.profile.list':
      case 'repository.profile.current':
        return payload.isEmpty;
      case 'repository.profile.create':
        return payload.keys.toSet().containsAll({
              'display_name',
              'idempotency_key',
            }) &&
            {
              'display_name',
              'idempotency_key',
              'avatar_student_id',
            }.containsAll(payload.keys) &&
            payload['display_name'] is String &&
            (payload['display_name'] as String).isNotEmpty &&
            (!payload.containsKey('avatar_student_id') ||
                payload['avatar_student_id'] is String &&
                    (payload['avatar_student_id'] as String).isNotEmpty) &&
            payload['idempotency_key'] is String &&
            (payload['idempotency_key'] as String).isNotEmpty;
      case 'repository.profile.select':
        return mutation({});
      case 'repository.profile.rename':
        return mutation({'display_name'}) &&
            payload['display_name'] is String &&
            (payload['display_name'] as String).isNotEmpty;
      case 'repository.profile.update':
        return mutation({'display_name', 'avatar_student_id'}) &&
            payload['display_name'] is String &&
            (payload['display_name'] as String).isNotEmpty &&
            payload['avatar_student_id'] is String &&
            (payload['avatar_student_id'] as String).isNotEmpty;
      case 'repository.profile.delete':
        return mutation({});
      case 'repository.state.get':
      case 'repository.plan.get':
      case 'repository.presets.get':
        return _exact(payload, {'profile_id'}) &&
            payload['profile_id'] is String &&
            RegExp(r'^[0-9a-f]{24}$').hasMatch(payload['profile_id'] as String);
      case 'repository.students.update':
        if (!mutation({'students'}) || payload['students'] is! List) {
          return false;
        }
        for (final item in payload['students'] as List) {
          ConfirmedStudentState.fromWire(_wireMap(item, 'confirmed student'));
        }
        final ids = (payload['students'] as List)
            .map((item) => item['student_id'])
            .toList();
        if (ids.toSet().length != ids.length) return false;
        return true;
      case 'repository.inventory.update':
        // FB-10b: optional `applied_resource_keys`(배열, null 금지, 빈 배열 허용, 별칭 중복 거부).
        final scoped = payload.containsKey('applied_resource_keys');
        if (!mutation({'inventory', if (scoped) 'applied_resource_keys'})) {
          return false;
        }
        RepositoryInventoryState.fromWire(
          _wireMap(payload['inventory'], 'inventory snapshot'),
        );
        if (scoped) {
          repositoryInventoryAppliedKeys(payload['applied_resource_keys']);
        }
        return true;
      case 'repository.inventory.review.get':
        RepositoryInventoryReviewRequest.fromWire(payload);
        return true;
      case 'repository.goals.save':
        if (!mutation({'goals'})) return false;
        final plan = _wireMap(payload['goals'], 'goal plan');
        if (!_exact(plan, {'version', 'goals'}) ||
            plan['version'] != 1 ||
            plan['goals'] is! List) {
          return false;
        }
        for (final item in plan['goals'] as List) {
          RepositoryGoalState.fromWire(_wireMap(item, 'goal'));
        }
        return true;
      case 'repository.plan.save':
        RepositoryPlanSaveRequest.fromWire(payload);
        return true;
      case 'repository.plan.replace':
        RepositoryPlanReplaceRequest.fromWire(payload);
        return true;
      case 'repository.presets.save':
        RepositoryPresetsSaveRequest.fromWire(payload);
        return true;
      case 'repository.migration.preview':
        return payload.isEmpty;
      case 'repository.history.summary':
        RepositoryHistorySummaryRequest.fromWire(payload);
        return true;
      case 'repository.history.events':
        RepositoryHistoryEventsRequest.fromWire(payload);
        return true;
      case 'repository.history.diff':
        RepositoryHistoryDiffRequest.fromWire(payload);
        return true;
      case 'repository.history.scan_latest':
        RepositoryHistoryScanLatestRequest.fromWire(payload);
        return true;
      case 'repository.migration.import':
        return _exact(payload, {'source_profile_key'}) &&
            payload['source_profile_key'] is String &&
            (payload['source_profile_key'] as String).isNotEmpty;
      case 'repository.practice.create':
        PracticeCreateRequest.fromWire(payload);
        return true;
      case 'repository.practice.current':
        return payload.isEmpty;
      case 'repository.practice.reset':
        PracticeResetRequest.fromWire(payload);
        return true;
      case 'repository.practice.end':
        PracticeEndRequest.fromWire(payload);
        return true;
      case 'repository.practice.recover':
        PracticeRecoverRequest.fromWire(payload);
        return true;
      default:
        return false;
    }
  } on Object {
    return false;
  }
}

abstract interface class RepositoryService {
  Future<List<RepositoryProfile>> listProfiles();
  Future<RepositoryProfile> createProfile(
    String displayName,
    String idempotencyKey, {
    String avatarStudentId = 'hasumi',
  });
  Future<int> selectProfile(
    String profileId,
    int expectedRevision,
    String idempotencyKey,
  );
  Future<int> renameProfile(
    String profileId,
    String displayName,
    int expectedRevision,
    String idempotencyKey,
  );
  Future<int> updateProfile(
    String profileId,
    String displayName,
    String avatarStudentId,
    int expectedRevision,
    String idempotencyKey,
  );
  Future<int> deleteProfile(
    String profileId,
    int expectedRevision,
    String idempotencyKey,
  );
  Future<RepositoryState> loadRepositoryState(String profileId);
  Future<RepositoryHistorySummaryResult> loadRepositoryHistorySummary(
    List<String> profileIds,
  );
  Future<RepositoryHistoryEventsResult> loadRepositoryHistoryEvents(
    RepositoryHistoryEventsRequest request,
  );
  Future<RepositoryHistoryDiffResult> loadRepositoryHistoryDiff(
    RepositoryHistoryDiffRequest request,
  );

  /// FB-2b `repository.history.scan_latest`: read-only latest scan metadata.
  /// A stale anchor fails with invalid_payload / details.reason=stale_scan_latest
  /// (not retryable): discard the accumulated by-kind pages and restart.
  Future<RepositoryHistoryScanLatestResult> loadRepositoryHistoryScanLatest(
    RepositoryHistoryScanLatestRequest request,
  );
  Future<int> saveRepositoryStudents(
    String profileId,
    List<ConfirmedStudentState> students,
    int expectedRevision,
    String idempotencyKey,
  );
  /// [appliedResourceKeys](FB-10b)가 있으면 그 key의 확인 필요 표시만 해제한다(같은 값 확인 포함). 수량이 바뀐
  /// key가 scope 밖이면 `invalid_payload`(reason `scan_scope_mismatch`). 없으면(기존 호출) 실제로 수량이 바뀐
  /// key만 해제한다. 재시도는 원 expected_revision·key·scope로 하고, 같은 key에 다른 scope는 `idempotency_conflict`.
  Future<int> saveRepositoryInventory(
    String profileId,
    RepositoryInventoryState inventory,
    int expectedRevision,
    String idempotencyKey, {
    List<String>? appliedResourceKeys,
  });
  Future<int> saveRepositoryGoals(
    String profileId,
    Map<String, dynamic> goals,
    int expectedRevision,
    String idempotencyKey,
  );
  Future<List<RepositoryV6AccountPreview>> previewV6Accounts();
  Future<RepositoryV6ImportResult> importV6Account(String sourceProfileKey);
}

// ---- X4 / FD-182 튜토리얼 임시 계정(contracts/tutorial-practice-v1, fixture `runtimeImplemented:false`) ----
// 요청 · 응답 키는 계약 schema 그대로다(모르는 키 거부). revision은 bool · 음수를 거부하고, 문자열은 비어 있지 않아야
// 한다. practice 쪽 profile id는 계약상 일반 계정의 24자리 hex 규칙이 아니다(길이 1 이상 문자열).

/// 임시 계정 데이터 판(고정).
const practiceDatasetVersion = 'tutorial-v1';

/// 임시 계정이 고른 상태일 때만 `scanner.target.list`가 내는 가상 대상 id.
const practiceVirtualTargetId = 'tutorial:1280x720';

/// 가상 대상 제목(계약 그대로).
const practiceVirtualTargetTitle = '가상 게임 창 · 튜토리얼';

/// 계약 메서드 5개.
const practiceMethods = {
  'repository.practice.create',
  'repository.practice.current',
  'repository.practice.reset',
  'repository.practice.end',
  'repository.practice.recover',
};

/// practice 메서드 오류 코드(계약 schema 9개). 지금 백엔드가 내는 `unknown_method`는 여기 없다 — 그것은
/// [TutorialPracticeSupport.unsupported]로 해독한다.
enum PracticeErrorCode {
  invalidPayload('invalid_payload'),
  profileNotFound('profile_not_found'),
  revisionConflict('revision_conflict'),
  idempotencyConflict('idempotency_conflict'),
  practiceProfileRequired('practice_profile_required'),
  practiceSessionActive('practice_session_active'),
  practiceCleanupFailed('practice_cleanup_failed'),
  corruptData('corrupt_data'),
  storageError('storage_error');

  const PracticeErrorCode(this.wireName);
  final String wireName;

  /// 모르는 코드는 null.
  static PracticeErrorCode? fromWire(Object? value) {
    for (final code in values) {
      if (code.wireName == value) return code;
    }
    return null;
  }
}

/// [error]가 practice 계약 오류(`BackendRemoteException`)면 그 코드. 아니면 null.
PracticeErrorCode? practiceErrorCodeOf(Object error) =>
    error is BackendRemoteException
    ? PracticeErrorCode.fromWire(error.code)
    : null;

/// 백엔드가 임시 계정 메서드를 지원하는가. 화면(F3c-3)은 [unsupported]면 튜토리얼을 시작하지 않는다.
enum TutorialPracticeSupport {
  /// 아직 묻지 않았거나 연결이 바뀌었다.
  unknown,

  /// 백엔드가 practice 메서드에 `unknown_method`로 답했다(지금 백엔드, 튜토리얼 실행 불가).
  unsupported,

  /// practice 메서드가 계약 응답(성공 또는 계약 오류)으로 답했다.
  supported,
}

/// practice 메서드에 백엔드가 `unknown_method`로 답했다(백엔드 미지원).
class TutorialPracticeUnsupportedException implements Exception {
  TutorialPracticeUnsupportedException(this.method);

  final String method;

  @override
  String toString() =>
      'TutorialPracticeUnsupportedException: backend does not support $method';
}

bool _practiceText(Object? value) => value is String && value.isNotEmpty;

void _practiceKeys(Map<String, dynamic> wire, Set<String> keys, String label) {
  if (!_exact(wire, keys)) {
    throw FormatException('Invalid $label keys: ${wire.keys.toList()..sort()}');
  }
}

/// `practice` 객체: profile_id · origin_profile_id · is_practice(true) · revision · dataset_version · virtual_target_id.
class PracticeProfile {
  const PracticeProfile({
    required this.profileId,
    required this.originProfileId,
    required this.revision,
  });

  final String profileId;
  final String originProfileId;
  final int revision;

  bool get isPractice => true;
  String get datasetVersion => practiceDatasetVersion;
  String get virtualTargetId => practiceVirtualTargetId;

  static const wireKeys = {
    'profile_id',
    'origin_profile_id',
    'is_practice',
    'revision',
    'dataset_version',
    'virtual_target_id',
  };

  factory PracticeProfile.fromWire(Map<String, dynamic> wire) {
    _practiceKeys(wire, wireKeys, 'practice');
    if (!_practiceText(wire['profile_id']) ||
        !_practiceText(wire['origin_profile_id']) ||
        wire['is_practice'] != true ||
        !_revision(wire['revision']) ||
        wire['dataset_version'] != practiceDatasetVersion ||
        wire['virtual_target_id'] != practiceVirtualTargetId) {
      throw const FormatException('Invalid practice payload');
    }
    return PracticeProfile(
      profileId: wire['profile_id'] as String,
      originProfileId: wire['origin_profile_id'] as String,
      revision: wire['revision'] as int,
    );
  }

  Map<String, dynamic> toWire() => {
    'profile_id': profileId,
    'origin_profile_id': originProfileId,
    'is_practice': true,
    'revision': revision,
    'dataset_version': practiceDatasetVersion,
    'virtual_target_id': practiceVirtualTargetId,
  };
}

String? _practiceSelected(Map<String, dynamic> wire) {
  final selected = wire['selected_profile_id'];
  if (selected != null && selected is! String) {
    throw const FormatException('Invalid practice selected_profile_id');
  }
  return selected as String?;
}

/// create · current · reset 응답: `practice`(없으면 null) · `selected_profile_id`(nullable).
class PracticeSessionState {
  const PracticeSessionState({required this.practice, this.selectedProfileId});

  final PracticeProfile? practice;
  final String? selectedProfileId;

  /// 임시 계정이 있고 지금 고른 계정이다.
  bool get practiceSelected {
    final current = practice;
    return current != null && current.profileId == selectedProfileId;
  }

  static const wireKeys = {'practice', 'selected_profile_id'};

  factory PracticeSessionState.fromWire(Map<String, dynamic> wire) {
    _practiceKeys(wire, wireKeys, 'practice session');
    final practice = wire['practice'];
    return PracticeSessionState(
      practice: practice == null
          ? null
          : PracticeProfile.fromWire(_wireMap(practice, 'practice')),
      selectedProfileId: _practiceSelected(wire),
    );
  }

  Map<String, dynamic> toWire() => {
    'practice': practice?.toWire(),
    'selected_profile_id': selectedProfileId,
  };
}

/// end 응답: 지운 임시 계정 · 되돌린 선택(없으면 null) · 이미 지워져 있었는가.
class PracticeEndResult {
  const PracticeEndResult({
    required this.deletedProfileId,
    required this.selectedProfileId,
    required this.alreadyDeleted,
  });

  final String deletedProfileId;
  final String? selectedProfileId;
  final bool alreadyDeleted;

  static const wireKeys = {
    'deleted_profile_id',
    'selected_profile_id',
    'already_deleted',
  };

  factory PracticeEndResult.fromWire(Map<String, dynamic> wire) {
    _practiceKeys(wire, wireKeys, 'practice end');
    if (!_practiceText(wire['deleted_profile_id']) ||
        wire['already_deleted'] is! bool) {
      throw const FormatException('Invalid practice end payload');
    }
    return PracticeEndResult(
      deletedProfileId: wire['deleted_profile_id'] as String,
      selectedProfileId: _practiceSelected(wire),
      alreadyDeleted: wire['already_deleted'] as bool,
    );
  }

  Map<String, dynamic> toWire() => {
    'deleted_profile_id': deletedProfileId,
    'selected_profile_id': selectedProfileId,
    'already_deleted': alreadyDeleted,
  };
}

/// recover 응답: 지운 고아 임시 계정(중복 없음) · 지금 선택(없으면 null).
class PracticeRecoveryResult {
  PracticeRecoveryResult({
    required List<String> removedProfileIds,
    required this.selectedProfileId,
  }) : removedProfileIds = List.unmodifiable(removedProfileIds);

  final List<String> removedProfileIds;
  final String? selectedProfileId;

  static const wireKeys = {'removed_profile_ids', 'selected_profile_id'};

  factory PracticeRecoveryResult.fromWire(Map<String, dynamic> wire) {
    _practiceKeys(wire, wireKeys, 'practice recover');
    final removed = wire['removed_profile_ids'];
    if (removed is! List ||
        removed.any((item) => !_practiceText(item)) ||
        removed.toSet().length != removed.length) {
      throw const FormatException('Invalid practice recover payload');
    }
    return PracticeRecoveryResult(
      removedProfileIds: removed.cast<String>(),
      selectedProfileId: _practiceSelected(wire),
    );
  }

  Map<String, dynamic> toWire() => {
    'removed_profile_ids': removedProfileIds,
    'selected_profile_id': selectedProfileId,
  };
}

/// end 이유.
enum PracticeEndReason {
  completed,
  dismissed;

  String get wireName => name;

  static PracticeEndReason fromWire(Object? value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => throw FormatException('Invalid practice end reason: $value'),
  );
}

/// `repository.practice.create` 요청. 만들 때 값을 검사한다(빈 문자열 · 음수 revision 거부).
class PracticeCreateRequest {
  const PracticeCreateRequest._(
    this.originProfileId,
    this.expectedOriginRevision,
    this.idempotencyKey,
  );

  factory PracticeCreateRequest({
    required String originProfileId,
    required int expectedOriginRevision,
    required String idempotencyKey,
  }) => PracticeCreateRequest.fromWire({
    'origin_profile_id': originProfileId,
    'expected_origin_revision': expectedOriginRevision,
    'idempotency_key': idempotencyKey,
  });

  final String originProfileId;
  final int expectedOriginRevision;
  final String idempotencyKey;

  static const wireKeys = {
    'origin_profile_id',
    'expected_origin_revision',
    'idempotency_key',
  };

  factory PracticeCreateRequest.fromWire(Map<String, dynamic> wire) {
    _practiceKeys(wire, wireKeys, 'practice create');
    if (!_practiceText(wire['origin_profile_id']) ||
        !_revision(wire['expected_origin_revision']) ||
        !_practiceText(wire['idempotency_key'])) {
      throw const FormatException('Invalid practice create request');
    }
    return PracticeCreateRequest._(
      wire['origin_profile_id'] as String,
      wire['expected_origin_revision'] as int,
      wire['idempotency_key'] as String,
    );
  }

  Map<String, dynamic> toWire() => {
    'origin_profile_id': originProfileId,
    'expected_origin_revision': expectedOriginRevision,
    'idempotency_key': idempotencyKey,
  };
}

/// `repository.practice.reset` 요청.
class PracticeResetRequest {
  const PracticeResetRequest._(
    this.profileId,
    this.expectedRevision,
    this.idempotencyKey,
  );

  factory PracticeResetRequest({
    required String profileId,
    required int expectedRevision,
    required String idempotencyKey,
  }) => PracticeResetRequest.fromWire({
    'profile_id': profileId,
    'expected_revision': expectedRevision,
    'idempotency_key': idempotencyKey,
  });

  final String profileId;
  final int expectedRevision;
  final String idempotencyKey;

  static const wireKeys = {
    'profile_id',
    'expected_revision',
    'idempotency_key',
  };

  factory PracticeResetRequest.fromWire(Map<String, dynamic> wire) {
    _practiceKeys(wire, wireKeys, 'practice reset');
    if (!_practiceText(wire['profile_id']) ||
        !_revision(wire['expected_revision']) ||
        !_practiceText(wire['idempotency_key'])) {
      throw const FormatException('Invalid practice reset request');
    }
    return PracticeResetRequest._(
      wire['profile_id'] as String,
      wire['expected_revision'] as int,
      wire['idempotency_key'] as String,
    );
  }

  Map<String, dynamic> toWire() => {
    'profile_id': profileId,
    'expected_revision': expectedRevision,
    'idempotency_key': idempotencyKey,
  };
}

/// `repository.practice.end` 요청.
class PracticeEndRequest {
  const PracticeEndRequest._(
    this.profileId,
    this.expectedRevision,
    this.idempotencyKey,
    this.reason,
  );

  factory PracticeEndRequest({
    required String profileId,
    required int expectedRevision,
    required String idempotencyKey,
    required PracticeEndReason reason,
  }) => PracticeEndRequest.fromWire({
    'profile_id': profileId,
    'expected_revision': expectedRevision,
    'idempotency_key': idempotencyKey,
    'reason': reason.wireName,
  });

  final String profileId;
  final int expectedRevision;
  final String idempotencyKey;
  final PracticeEndReason reason;

  static const wireKeys = {
    'profile_id',
    'expected_revision',
    'idempotency_key',
    'reason',
  };

  factory PracticeEndRequest.fromWire(Map<String, dynamic> wire) {
    _practiceKeys(wire, wireKeys, 'practice end');
    if (!_practiceText(wire['profile_id']) ||
        !_revision(wire['expected_revision']) ||
        !_practiceText(wire['idempotency_key'])) {
      throw const FormatException('Invalid practice end request');
    }
    return PracticeEndRequest._(
      wire['profile_id'] as String,
      wire['expected_revision'] as int,
      wire['idempotency_key'] as String,
      PracticeEndReason.fromWire(wire['reason']),
    );
  }

  Map<String, dynamic> toWire() => {
    'profile_id': profileId,
    'expected_revision': expectedRevision,
    'idempotency_key': idempotencyKey,
    'reason': reason.wireName,
  };
}

/// `repository.practice.recover` 요청.
class PracticeRecoverRequest {
  const PracticeRecoverRequest._(this.idempotencyKey);

  factory PracticeRecoverRequest({required String idempotencyKey}) =>
      PracticeRecoverRequest.fromWire({'idempotency_key': idempotencyKey});

  final String idempotencyKey;

  static const wireKeys = {'idempotency_key'};

  factory PracticeRecoverRequest.fromWire(Map<String, dynamic> wire) {
    _practiceKeys(wire, wireKeys, 'practice recover');
    if (!_practiceText(wire['idempotency_key'])) {
      throw const FormatException('Invalid practice recover request');
    }
    return PracticeRecoverRequest._(wire['idempotency_key'] as String);
  }

  Map<String, dynamic> toWire() => {'idempotency_key': idempotencyKey};
}

/// 임시 계정 수명(X4 / FD-182). 한 번에 하나: create는 진짜 계정을 그대로 두고 임시 계정을 고르며, end는 임시 계정이
/// 가진 모든 것을 지우고 원래 선택을 되돌린다. 같은 idempotency key 재시도는 원 결과다.
///
/// 지금 백엔드는 다섯 메서드에 `unknown_method`로 답한다 — 그때 메서드는 [TutorialPracticeUnsupportedException]을 던지고
/// [practiceSupport]는 [TutorialPracticeSupport.unsupported]가 된다.
abstract interface class RepositoryPracticeService {
  /// 지금까지 알아낸 지원 여부. 처음과 연결이 끊긴 뒤는 [TutorialPracticeSupport.unknown].
  TutorialPracticeSupport get practiceSupport;

  /// `repository.practice.current {}`로 지원 여부를 알아낸다. `unknown_method`면 예외 없이 unsupported를 돌려준다.
  /// 연결 끊김 같은 다른 실패는 그대로 던진다(값은 unknown 그대로).
  Future<TutorialPracticeSupport> probePracticeSupport();

  Future<PracticeSessionState> createPractice(PracticeCreateRequest request);
  Future<PracticeSessionState> currentPractice();
  Future<PracticeSessionState> resetPractice(PracticeResetRequest request);
  Future<PracticeEndResult> endPractice(PracticeEndRequest request);
  Future<PracticeRecoveryResult> recoverPractice(
    PracticeRecoverRequest request,
  );
}
