import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_service.dart';
import 'repository_service.dart';
import 'scanner_service.dart';

class MockAppService implements AppService, MockScenarioController, RepositoryService, ScannerService {
  MockAppService({AppServiceState? initialState})
    : _state = ValueNotifier(
        initialState ??
            const AppServiceState(
              connection: BackendConnection.connected,
              scanPhase: ScanPhase.idle,
              imageLoadState: ImageLoadState.loaded,
              studentCount: 42,
              inventoryItemCount: 186,
              hasData: true,
              scanAvailable: true,
              useLongNames: false,
              hasMissingMetadata: false,
            ),
      );

  final ValueNotifier<AppServiceState> _state;
  final List<RepositoryProfile> _profiles = [const RepositoryProfile(id: '000000000000000000000001', displayName: 'Main', revision: 0, selected: true)];
  final Map<String, Map<String, dynamic>> _repositoryStates = {};
  final StreamController<ScannerEvent> _scannerEvents = StreamController.broadcast();
  var _scannerGeneration = 0;

  @override
  ValueListenable<AppServiceState> get state => _state;

  @override
  Future<void> reconnect() async {
    _state.value = _state.value.copyWith(
      connection: BackendConnection.connecting,
    );
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _state.value = _state.value.copyWith(
      connection: BackendConnection.connected,
    );
  }

  @override
  Future<void> restartBackend() async {
    _state.value = _state.value.copyWith(
      connection: BackendConnection.disconnected,
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await reconnect();
  }

  @override
  Future<void> startScan() async {
    _state.value = _state.value.copyWith(scanPhase: ScanPhase.scanning);
    final session = await startScannerSession(ScannerKind.student, 'mock-window');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _scannerEvents.add(ScannerEvent(
      sessionId: session.id,
      generation: session.generation,
      sequence: 1,
      kind: ScannerKind.student,
      eventKind: ScannerEventKind.terminal,
      payload: {'outcome': 'completed'},
    ));
    _state.value = _state.value.copyWith(scanPhase: ScanPhase.succeeded);
  }

  @override
  Stream<ScannerEvent> get scannerEvents => _scannerEvents.stream;

  @override
  Future<List<ScannerTarget>> listScannerTargets() async => const [
    ScannerTarget(id: 'mock-window', title: 'Mock Blue Archive', status: ScannerTargetStatus.ready, foreground: true),
  ];

  @override
  Future<Map<String, dynamic>> scannerReadiness() async => {'ready': true, 'manifest_version': 1, 'missing': <String>[], 'corrupt': <String>[]};

  @override
  Future<ScannerSession> startScannerSession(ScannerKind kind, String targetId) async => ScannerSession(id: 'mock-session-${++_scannerGeneration}', generation: _scannerGeneration, kind: kind);

  @override
  Future<Map<String, dynamic>> cancelScannerSession(ScannerSession session) async => {'accepted': true, 'terminal': 'cancelled'};

  @override
  Future<Map<String, dynamic>> scannerSnapshot(ScannerSession session) async => {'session_id':session.id,'generation':session.generation,'scan_kind':session.kind.name,'last_sequence':0,'terminal':null,'events':<dynamic>[],'candidates':<dynamic>[]};

  @override
  Future<ScannerCandidate> getScannerCandidate(ScannerSession session, String candidateId) async => ScannerCandidate(id:candidateId,sessionId:session.id,generation:session.generation,revision:1,kind:session.kind,payload:const {'version':1,'student_id':'aru','values':<String,dynamic>{}},evidence:const [],reviewRequired:false,approved:false);

  @override
  Future<ScannerCandidate> reviewScannerCandidate(ScannerSession session, ScannerCandidate candidate, Map<String, dynamic> payload, {required bool approve, required String reason}) async => ScannerCandidate(id:candidate.id,sessionId:session.id,generation:session.generation,revision:candidate.revision+1,kind:session.kind,payload:payload,evidence:candidate.evidence,reviewRequired:candidate.reviewRequired,approved:approve);

  @override
  Future<Map<String, dynamic>> commitScannerCandidate(ScannerSession session, ScannerCandidate candidate, {required String profileId, required int expectedRepositoryRevision, required String idempotencyKey}) async {
    if (candidate.reviewRequired && !candidate.approved) {
      throw StateError('review_required');
    }
    final current = _repositoryStates[profileId] ?? {'profile_id':profileId,'revision':0,'students':<dynamic>[],'inventory':{'version':1,'entries':<dynamic>[]},'goals':{'version':1,'goals':<dynamic>[]}};
    if (current['revision'] != expectedRepositoryRevision) {
      throw StateError('revision_conflict');
    }
    final payload = Map<String, dynamic>.from(candidate.payload);
    final studentId = payload['student_id'];
    final existing = List<dynamic>.from(current['students'] as List);
    if (studentId is String) {
      existing.removeWhere((item) => item is Map && item['student_id'] == studentId);
      existing.add(payload);
    }
    final revision = expectedRepositoryRevision + 1;
    _repositoryStates[profileId] = candidate.kind == ScannerKind.inventory
        ? {...current, 'revision':revision, 'inventory':payload}
        : {...current, 'revision':revision, 'students':existing};
    return {'candidate_id':candidate.id,'candidate_revision':candidate.revision,'profile_id':profileId,'revision':revision};
  }

  @override
  Future<Map<String, dynamic>?> getStudent(String studentId) async {
    const students = <String, Map<String, dynamic>>{
      'ayane': {
        'student_id': 'ayane',
        'display_name': '아야네',
        'template_name': 'Ayane',
        'group': 'Abydos',
        'variant': null,
      },
      'aru': {
        'student_id': 'aru',
        'display_name': '아루',
        'template_name': 'Aru',
        'group': 'Gehenna',
        'variant': null,
      },
    };
    final student = students[studentId];
    return student == null ? null : Map<String, dynamic>.from(student);
  }

  @override
  Future<List<StudentCatalogEntry>> listStudents() async {
    final longName = _state.value.useLongNames
        ? 'Aru with an intentionally long display name for responsive layout verification'
        : 'Aru';
    return [
      StudentCatalogEntry(
        studentId: 'aru', displayName: longName, templateName: 'Aru.png',
        group: 'Problem Solver 68', variant: null, school: 'Gehenna',
        rarity: '3', attackType: 'Explosive', defenseType: 'Light',
        combatClass: 'Striker', role: 'Dealer', position: 'Back',
        searchTags: const ['aru'], krSearchTags: const [],
      ),
      StudentCatalogEntry(
        studentId: 'ayane', displayName: 'Ayane', templateName: 'Ayane.png',
        group: 'Foreclosure Task Force', variant: null, school: 'Abydos',
        rarity: '2', attackType: 'Piercing', defenseType: 'Light',
        combatClass: 'Special', role: 'Healer', position: 'Back',
        searchTags: const ['ayane'], krSearchTags: const [],
      ),
      if (_state.value.hasMissingMetadata) StudentCatalogEntry.fallback('missing-student'),
    ];
  }

  @override
  Future<List<InventoryCatalogEntry>> listInventoryItems() async => const [
    InventoryCatalogEntry(resourceKey:'Item_Icon_ExpItem_0',itemId:'Item_Icon_ExpItem_0',
      displayName:'Basic activity report',category:'activity_report',profileId:'activity_reports',orderIndex:0,zeroFillAllowed:true),
    InventoryCatalogEntry(resourceKey:'Item_Icon_SkillBook_Gehenna_0',itemId:'Item_Icon_SkillBook_Gehenna_0',
      displayName:'Gehenna Note T1',category:'tech_notes',profileId:'tech_notes',orderIndex:0,zeroFillAllowed:true),
    InventoryCatalogEntry(resourceKey:'Item_Icon_Material_Nebra_0',itemId:'Item_Icon_Material_Nebra_0',
      displayName:'Nebra Disk T1',category:'oopart',profileId:'ooparts',orderIndex:0,zeroFillAllowed:true),
  ];

  @override
  Future<InventoryShortageResult> calculateShortages({required List<Map<String,dynamic>> currentStudents,
    required Map<String,dynamic> plan, required Map<String,dynamic> inventory}) async {
    final entries = <String,int?>{};
    for (final raw in inventory['entries'] as List? ?? const []) {
      final item = raw as Map;
      final quantity = item['quantity'];
      entries[(item['item_id'] ?? item['key']) as String] = quantity == null ? null : int.parse(quantity as String);
    }
    final affected = (plan['goals'] as List? ?? const []).map((item) => (item as Map)['student_id'] as String).toList();
    const required = 12;
    final owned = entries['Item_Icon_ExpItem_0'];
    return InventoryShortageResult([InventoryShortageRow(resourceKey:'Item_Icon_ExpItem_0',
      itemId:'Item_Icon_ExpItem_0',displayName:'Basic activity report',category:'activity_report',
      requiredAmount:required,owned:owned,shortage:owned == null ? null : (owned >= required ? 0 : required-owned),
      affectedStudentIds:affected,resolved:true)], const []);
  }

  @override
  Future<Map<String, dynamic>> validatePlan(Map<String, dynamic> plan) async {
    return {
      'version': 1,
      'goals': (plan['goals'] as List<dynamic>)
          .map((goal) => Map<String, dynamic>.from(goal as Map))
          .toList(),
    };
  }

  @override
  Future<Map<String, dynamic>> calculatePlan({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
  }) async {
    final goals = (plan['goals'] as List<dynamic>? ?? const []);
    final targetSum = goals.fold<int>(0, (sum, rawGoal) {
      final goal = rawGoal as Map;
      return sum +
          goal.values.whereType<int>().fold<int>(
            0,
            (value, item) => value + item,
          );
    });
    final studentCount = currentStudents.length;
    return {
      'credits': 1000 * studentCount + targetSum * 100,
      'level_exp': targetSum * 10,
      'equipment_exp': targetSum * 3,
      'weapon_exp': targetSum * 2,
      'star_materials': studentCount == 0
          ? <String, int>{}
          : {'mock_eleph': studentCount * 5},
      'equipment_materials': <String, int>{},
      'level_exp_items': targetSum == 0
          ? <String, int>{}
          : {'activity_report': targetSum},
      'equipment_exp_items': <String, int>{},
      'weapon_exp_items': <String, int>{},
      'skill_books': <String, int>{},
      'ex_ooparts': <String, int>{},
      'skill_ooparts': <String, int>{},
      'favorite_item_materials': <String, int>{},
      'stat_materials': <String, int>{},
      'stat_levels': <String, int>{},
      'warnings': <String>[],
    };
  }

  @override
  Future<List<RepositoryProfile>> listProfiles() async => List.unmodifiable(_profiles);

  @override
  Future<RepositoryProfile> createProfile(String displayName, String idempotencyKey) async {
    final profile = RepositoryProfile(id: (_profiles.length + 1).toRadixString(16).padLeft(24, '0'), displayName: displayName, revision: 0, selected: false);
    _profiles.add(profile);
    return profile;
  }

  @override
  Future<int> selectProfile(String profileId, int expectedRevision, String idempotencyKey) async {
    for (var index = 0; index < _profiles.length; index++) {
      final profile = _profiles[index];
      _profiles[index] = RepositoryProfile(id: profile.id, displayName: profile.displayName, revision: profile.id == profileId ? expectedRevision + 1 : profile.revision, selected: profile.id == profileId);
    }
    return expectedRevision + 1;
  }

  @override
  Future<int> renameProfile(String profileId, String displayName, int expectedRevision, String idempotencyKey) async {
    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    final profile = _profiles[index];
    _profiles[index] = RepositoryProfile(id: profile.id, displayName: displayName, revision: expectedRevision + 1, selected: profile.selected);
    return expectedRevision + 1;
  }

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async => RepositoryState.fromWire(Map<String, dynamic>.from(_repositoryStates[profileId] ?? {'profile_id':profileId,'revision':0,'students':<dynamic>[],'inventory':{'version':1,'entries':<dynamic>[]},'goals':{'version':1,'goals':<dynamic>[]}}));

  @override
  Future<int> saveRepositoryGoals(String profileId, Map<String, dynamic> goals, int expectedRevision, String idempotencyKey) async {
    final current = _repositoryStates[profileId] ?? {'profile_id':profileId,'revision':0,'students':<dynamic>[],'inventory':{'version':1,'entries':<dynamic>[]},'goals':{'version':1,'goals':<dynamic>[]}};
    _repositoryStates[profileId] = {...current, 'revision':expectedRevision + 1, 'goals':goals};
    return expectedRevision + 1;
  }

  @override
  Future<int> saveRepositoryStudents(String profileId, List<ConfirmedStudentState> students, int expectedRevision, String idempotencyKey) async {
    final current = _repositoryStates[profileId] ?? {'profile_id':profileId,'revision':0,'students':<dynamic>[],'inventory':{'version':1,'entries':<dynamic>[]},'goals':{'version':1,'goals':<dynamic>[]}};
    _repositoryStates[profileId] = {...current, 'revision':expectedRevision + 1, 'students':students.map((student) => student.toWire()).toList(growable:false)};
    return expectedRevision + 1;
  }

  @override
  Future<int> saveRepositoryInventory(String profileId, RepositoryInventoryState inventory, int expectedRevision, String idempotencyKey) async {
    final current = _repositoryStates[profileId] ?? {'profile_id':profileId,'revision':0,'students':<dynamic>[],'inventory':{'version':1,'entries':<dynamic>[]},'goals':{'version':1,'goals':<dynamic>[]}};
    if (current['revision'] != expectedRevision) throw StateError('revision_conflict');
    _repositoryStates[profileId] = {...current,'revision':expectedRevision+1,'inventory':inventory.toWire()};
    return expectedRevision + 1;
  }

  @override
  Future<void> dispose() async {
    await _scannerEvents.close();
    _state.dispose();
  }

  @override
  void setConnection(BackendConnection value) {
    _state.value = _state.value.copyWith(connection: value);
  }

  @override
  void setScanPhase(ScanPhase value) {
    _state.value = _state.value.copyWith(scanPhase: value);
  }

  @override
  void setImageLoadState(ImageLoadState value) {
    _state.value = _state.value.copyWith(imageLoadState: value);
  }

  @override
  void setHasData(bool value) {
    _state.value = _state.value.copyWith(hasData: value);
  }

  @override
  void setLargeDataset(bool value) {
    _state.value = _state.value.copyWith(
      studentCount: value ? 9999 : 42,
      inventoryItemCount: value ? 999999 : 186,
    );
  }

  @override
  void setLongNames(bool value) {
    _state.value = _state.value.copyWith(useLongNames: value);
  }

  @override
  void setMissingMetadata(bool value) {
    _state.value = _state.value.copyWith(hasMissingMetadata: value);
  }
}
