class RepositoryProfile {
  const RepositoryProfile({required this.id, required this.displayName, required this.revision, required this.selected});

  final String id;
  final String displayName;
  final int revision;
  final bool selected;

  factory RepositoryProfile.fromWire(Map<String, dynamic> value) {
    final id = value['profile_id'];
    final name = value['display_name'];
    final revision = value['revision'];
    final selected = value['selected'];
    if (id is! String || !RegExp(r'^[0-9a-f]{24}$').hasMatch(id) || name is! String || name.isEmpty || revision is! int || revision < 0 || selected is! bool) {
      throw const FormatException('Invalid repository profile payload');
    }
    return RepositoryProfile(id: id, displayName: name, revision: revision, selected: selected);
  }
}

bool _exact(Map<String, dynamic> value, Set<String> keys) =>
    value.keys.toSet().containsAll(keys) && keys.containsAll(value.keys);

bool _revision(Object? value) => value is int && value >= 0;

Map<String, dynamic> _wireMap(Object? value, String label) {
  if (value is! Map) throw FormatException('$label must be an object');
  return Map<String, dynamic>.from(value);
}

class ConfirmedStudentState {
  ConfirmedStudentState._(this.studentId, Map<String, dynamic> values)
    : values = Map.unmodifiable(values);

  final String studentId;
  final Map<String, dynamic> values;

  factory ConfirmedStudentState.fromWire(Map<String, dynamic> value) {
    const required = {'version', 'student_id', 'values'};
    const allowed = {'version', 'student_id', 'values', 'provenance'};
    if (!value.keys.toSet().containsAll(required) || !allowed.containsAll(value.keys) ||
        value['version'] != 1 || value['student_id'] is! String || (value['student_id'] as String).isEmpty) {
      throw const FormatException('Invalid confirmed student');
    }
    final values = _wireMap(value['values'], 'confirmed student values');
    const integerFields = {'level','student_star','weapon_star','weapon_level','ex_skill','skill1','skill2','skill3','equip1_level','equip2_level','equip3_level','combat_hp','combat_atk','combat_def','combat_heal','stat_hp','stat_atk','stat_heal'};
    const stringFields = {'weapon_state','equip1','equip2','equip3','equip4'};
    const allowedValues = {...integerFields, ...stringFields, 'form_combat_stats'};
    if (!allowedValues.containsAll(values.keys)) throw const FormatException('Unknown confirmed student value');
    for (final entry in values.entries) {
      if (integerFields.contains(entry.key) && entry.value != null && entry.value is! int) throw const FormatException('Invalid confirmed integer');
      if (stringFields.contains(entry.key) && entry.value != null && entry.value is! String) throw const FormatException('Invalid confirmed string');
      if (entry.key == 'form_combat_stats' && entry.value is! Map) throw const FormatException('Invalid combat stats');
    }
    final provenance = value['provenance'];
    if (provenance != null && (provenance is! Map || provenance.entries.any((entry) => entry.key is! String || entry.value is! String))) {
      throw const FormatException('Invalid confirmed provenance');
    }
    return ConfirmedStudentState._(value['student_id'] as String, values);
  }
}

class RepositoryGoalState {
  RepositoryGoalState._(this.studentId, Map<String, dynamic> values)
    : values = Map.unmodifiable(values);

  final String studentId;
  final Map<String, dynamic> values;

  factory RepositoryGoalState.fromWire(Map<String, dynamic> value) {
    final studentId = value['student_id'];
    if (studentId is! String || studentId.isEmpty) throw const FormatException('Invalid repository goal');
    const maximums = <String, int>{
      'target_level':90,'target_star':5,'target_weapon_level':60,'target_weapon_star':4,
      'target_ex_skill':5,'target_skill1':10,'target_skill2':10,'target_skill3':10,
      'target_equip1_tier':10,'target_equip2_tier':10,'target_equip3_tier':10,
      'target_equip1_level':70,'target_equip2_level':70,'target_equip3_level':70,
      'target_equip4_tier':2,'target_stat_hp':25,'target_stat_atk':25,'target_stat_heal':25,
    };
    final allowed = {'student_id','favorite','notes',...maximums.keys};
    if (!allowed.containsAll(value.keys) || (value.containsKey('favorite') && value['favorite'] is! bool) ||
        (value.containsKey('notes') && value['notes'] is! String)) throw const FormatException('Invalid repository goal fields');
    for (final entry in maximums.entries) {
      final target = value[entry.key];
      if (target != null && (target is! int || target < 0 || target > entry.value)) throw const FormatException('Invalid repository goal target');
    }
    return RepositoryGoalState._(studentId, value);
  }
}

class RepositoryInventoryState {
  RepositoryInventoryState._(List<Map<String, dynamic>> entries)
    : entries = List.unmodifiable(entries.map(Map<String, dynamic>.unmodifiable));

  final List<Map<String, dynamic>> entries;

  factory RepositoryInventoryState.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {'version', 'entries'}) || value['version'] != 1 || value['entries'] is! List) {
      throw const FormatException('Invalid inventory snapshot');
    }
    final entries = <Map<String, dynamic>>[];
    const required = {'key','quantity'};
    const allowed = {'key','quantity','item_id','name','index','profile_id'};
    for (final raw in value['entries'] as List) {
      final item = _wireMap(raw, 'inventory entry');
      if (!item.keys.toSet().containsAll(required) || !allowed.containsAll(item.keys) || item['key'] is! String || (item['key'] as String).isEmpty ||
          (item['quantity'] != null && item['quantity'] is! String) ||
          (item['item_id'] != null && item['item_id'] is! String) || (item['name'] != null && item['name'] is! String) ||
          (item['profile_id'] != null && item['profile_id'] is! String) || (item['index'] != null && item['index'] is! int)) {
        throw const FormatException('Invalid inventory entry');
      }
      entries.add(item);
    }
    return RepositoryInventoryState._(entries);
  }
}

class RepositoryState {
  RepositoryState._({required this.profileId, required this.revision, required this.students, required this.inventory, required this.goals});

  final String profileId;
  final int revision;
  final List<ConfirmedStudentState> students;
  final RepositoryInventoryState inventory;
  final List<RepositoryGoalState> goals;

  factory RepositoryState.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {'profile_id','revision','students','inventory','goals'}) ||
        value['profile_id'] is! String || !RegExp(r'^[0-9a-f]{24}$').hasMatch(value['profile_id'] as String) ||
        !_revision(value['revision']) || value['students'] is! List) {
      throw const FormatException('Invalid repository state');
    }
    final goals = _wireMap(value['goals'], 'goal plan');
    if (!_exact(goals, {'version','goals'}) || goals['version'] != 1 || goals['goals'] is! List) throw const FormatException('Invalid goal plan');
    return RepositoryState._(
      profileId: value['profile_id'] as String,
      revision: value['revision'] as int,
      students: List.unmodifiable((value['students'] as List).map((item) => ConfirmedStudentState.fromWire(_wireMap(item, 'confirmed student')))),
      inventory: RepositoryInventoryState.fromWire(_wireMap(value['inventory'], 'inventory snapshot')),
      goals: List.unmodifiable((goals['goals'] as List).map((item) => RepositoryGoalState.fromWire(_wireMap(item, 'goal')))),
    );
  }
}

bool isValidRepositorySuccessPayload(String method, Map<String, dynamic> payload) {
  try {
    switch (method) {
      case 'repository.profile.list':
        if (!_exact(payload, {'profiles','selected_profile_id'}) || payload['profiles'] is! List) return false;
        for (final item in payload['profiles'] as List) { RepositoryProfile.fromWire(_wireMap(item, 'profile')); }
        final selected = payload['selected_profile_id'];
        return selected == null || (selected is String && RegExp(r'^[0-9a-f]{24}$').hasMatch(selected));
      case 'repository.profile.create':
        if (!_exact(payload, {'profile','revision'}) || !_revision(payload['revision'])) return false;
        RepositoryProfile.fromWire(_wireMap(payload['profile'], 'profile'));
        return true;
      case 'repository.profile.current':
        if (!_exact(payload, {'profile'})) return false;
        if (payload['profile'] != null) RepositoryProfile.fromWire(_wireMap(payload['profile'], 'profile'));
        return true;
      case 'repository.profile.select':
      case 'repository.profile.rename':
      case 'repository.students.update':
      case 'repository.inventory.update':
      case 'repository.goals.save':
        return _exact(payload, {'revision'}) && _revision(payload['revision']);
      case 'repository.state.get':
        RepositoryState.fromWire(payload);
        return true;
      default:
        return false;
    }
  } on FormatException {
    return false;
  }
}

bool isValidRepositoryProtocolMessage(Map<String, dynamic> message) {
  const envelope = {'protocol','id','type','method','payload'};
  if (!_exact(message, envelope) || message['protocol'] != 1 || message['id'] is! String || (message['id'] as String).isEmpty ||
      message['method'] is! String || message['payload'] is! Map) return false;
  final method = message['method'] as String;
  final payload = Map<String, dynamic>.from(message['payload'] as Map);
  if (message['type'] == 'response') {
    if (payload.containsKey('error')) {
      if (!_exact(payload, {'error'}) || payload['error'] is! Map) return false;
      final error = Map<String, dynamic>.from(payload['error'] as Map);
      const required = {'code','message','retryable'};
      const allowed = {'code','message','retryable','details'};
      const codes = {'invalid_payload','profile_not_found','profile_name_conflict','revision_conflict','idempotency_conflict','repository_busy','corrupt_data','migration_required','migration_not_supported','persistence_failed','unknown_method'};
      return error.keys.toSet().containsAll(required) && allowed.containsAll(error.keys) && codes.contains(error['code']) &&
          error['message'] is String && (error['message'] as String).isNotEmpty && error['retryable'] is bool &&
          (!error.containsKey('details') || error['details'] is Map);
    }
    return isValidRepositorySuccessPayload(method, payload);
  }
  if (message['type'] != 'request') return false;
  bool mutation(Set<String> extras) {
    final keys = {'profile_id','expected_revision','idempotency_key',...extras};
    return _exact(payload, keys) && payload['profile_id'] is String && RegExp(r'^[0-9a-f]{24}$').hasMatch(payload['profile_id'] as String) &&
        _revision(payload['expected_revision']) && payload['idempotency_key'] is String && (payload['idempotency_key'] as String).isNotEmpty;
  }
  try {
    switch (method) {
      case 'repository.profile.list':
      case 'repository.profile.current':
        return payload.isEmpty;
      case 'repository.profile.create':
        return _exact(payload, {'display_name','idempotency_key'}) && payload['display_name'] is String && (payload['display_name'] as String).isNotEmpty && payload['idempotency_key'] is String && (payload['idempotency_key'] as String).isNotEmpty;
      case 'repository.profile.select':
        return mutation({});
      case 'repository.profile.rename':
        return mutation({'display_name'}) && payload['display_name'] is String && (payload['display_name'] as String).isNotEmpty;
      case 'repository.state.get':
        return _exact(payload, {'profile_id'}) && payload['profile_id'] is String && RegExp(r'^[0-9a-f]{24}$').hasMatch(payload['profile_id'] as String);
      case 'repository.students.update':
        if (!mutation({'students'}) || payload['students'] is! List) return false;
        for (final item in payload['students'] as List) { ConfirmedStudentState.fromWire(_wireMap(item, 'confirmed student')); }
        return true;
      case 'repository.inventory.update':
        if (!mutation({'inventory'})) return false;
        RepositoryInventoryState.fromWire(_wireMap(payload['inventory'], 'inventory snapshot'));
        return true;
      case 'repository.goals.save':
        if (!mutation({'goals'})) return false;
        final plan = _wireMap(payload['goals'], 'goal plan');
        if (!_exact(plan, {'version','goals'}) || plan['version'] != 1 || plan['goals'] is! List) return false;
        for (final item in plan['goals'] as List) { RepositoryGoalState.fromWire(_wireMap(item, 'goal')); }
        return true;
      case 'repository.migration.preview':
        return _exact(payload, {'source_path','profile_id'}) && payload['source_path'] is String && (payload['source_path'] as String).isNotEmpty &&
            payload['profile_id'] is String && RegExp(r'^[0-9a-f]{24}$').hasMatch(payload['profile_id'] as String);
      default:
        return false;
    }
  } on FormatException {
    return false;
  }
}

abstract interface class RepositoryService {
  Future<List<RepositoryProfile>> listProfiles();
  Future<RepositoryProfile> createProfile(String displayName, String idempotencyKey);
  Future<int> selectProfile(String profileId, int expectedRevision, String idempotencyKey);
  Future<int> renameProfile(String profileId, String displayName, int expectedRevision, String idempotencyKey);
  Future<RepositoryState> loadRepositoryState(String profileId);
  Future<int> saveRepositoryGoals(String profileId, Map<String, dynamic> goals, int expectedRevision, String idempotencyKey);
}
