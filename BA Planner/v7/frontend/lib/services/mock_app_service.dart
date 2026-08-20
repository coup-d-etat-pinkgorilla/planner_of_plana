import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../ui/models/planning_models.dart';
import 'app_service.dart';
import 'diagnostics_service.dart';
import 'mock_student_fixture.dart';
import 'repository_service.dart';
import 'scanner_service.dart';
import 'scenario_service.dart';
import 'tactical_service.dart';

enum MockScannerScenario { completed, failed, reviewRequired, inventoryUnknown }

class MockAppService
    implements
        AppService,
        PlanningDocumentService,
        PlanningScenarioRepositoryService,
        PlanningScenarioComparisonService,
        MockScenarioController,
        RepositoryService,
        ScannerService,
        TacticalService,
        DiagnosticsService {
  MockAppService({
    AppServiceState? initialState,
    this.scannerScenario = MockScannerScenario.completed,
    this.fullStudentCatalog = false,
    List<ScannerTarget>? scannerTargets,
    Map<String, dynamic>? scannerReadiness,
    List<RepositoryProfile>? profiles,
  }) : _scannerTargets = List.unmodifiable(
         scannerTargets ??
             const [
               ScannerTarget(
                 id: 'mock-window',
                 title: 'Mock Blue Archive',
                 status: ScannerTargetStatus.ready,
                 foreground: true,
               ),
             ],
       ),
       _scannerReadiness = Map.unmodifiable(
         scannerReadiness ??
             const {
               'ready': true,
               'manifest_version': 1,
               'missing': <String>[],
               'corrupt': <String>[],
             },
       ),
       _profiles = List.of(
         profiles ??
             const [
               RepositoryProfile(
                 id: '000000000000000000000001',
                 displayName: 'Main',
                 revision: 0,
                 selected: true,
               ),
             ],
       ),
       _state = ValueNotifier(
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
       ) {
    if (fullStudentCatalog && _profiles.isNotEmpty) {
      final profile = _profiles.firstWhere(
        (item) => item.selected,
        orElse: () => _profiles.first,
      );
      _repositoryStates[profile.id] = {
        'profile_id': profile.id,
        'revision': 0,
        'students': buildMockOwnedStudents(),
        'inventory': {'version': 1, 'entries': <dynamic>[]},
        'goals': {'version': 1, 'goals': <dynamic>[]},
      };
    }
  }

  List<StudentCatalogEntry>? _studentCatalog;

  final Map<String, List<PlanningScenarioRecord>> _planningScenarios = {};
  final Map<String, int> _planningScenarioRevisions = {};
  int _nextPlanningScenarioId = 1;

  final MockScannerScenario scannerScenario;
  final bool fullStudentCatalog;
  final List<ScannerTarget> _scannerTargets;
  final Map<String, dynamic> _scannerReadiness;

  final ValueNotifier<AppServiceState> _state;
  final ValueNotifier<BackendDiagnostics> _diagnostics = ValueNotifier(
    const BackendDiagnostics(
      protocolVersion: 1,
      connection: BackendConnection.connected,
      processGeneration: 1,
      launch: BackendLaunchInfo(
        configured: false,
        resolved: true,
        executable: 'mock-python',
        arguments: ['-m', 'core.backend_process'],
        workingDirectory: 'mock/backend',
      ),
      lifecycle: ['g1: mock process connected'],
      stderr: [],
    ),
  );
  final List<RepositoryProfile> _profiles;
  final Map<String, Map<String, dynamic>> _repositoryStates = {};
  final Map<String, TacticalState> _tacticalStates = {};
  final StreamController<ScannerEvent> _scannerEvents =
      StreamController.broadcast();
  final Map<String, List<ScannerEvent>> _scannerHistory = {};
  final Map<String, ScannerCandidate> _scannerCandidates = {};
  final Map<String, String> _scannerTerminals = {};
  final List<Timer> _scannerTimers = [];
  var _scannerGeneration = 0;
  bool failNextReconnect = false;
  bool failNextRestart = false;
  bool failNextProfileMutation = false;
  Future<void>? _reconnectFlight;
  Future<void>? _restartFlight;

  @override
  ValueListenable<AppServiceState> get state => _state;

  @override
  Future<void> reconnect() => _reconnectFlight ??= _mockReconnect();

  Future<void> _mockReconnect() async {
    try {
      _recordLifecycle('reconnect requested');
      if (failNextReconnect) {
        failNextReconnect = false;
        _recordLifecycle('reconnect failed');
        throw StateError('mock reconnect failed');
      }
      _state.value = _state.value.copyWith(
        connection: BackendConnection.connecting,
      );
      _syncDiagnostics();
      await Future<void>.delayed(const Duration(milliseconds: 450));
      _state.value = _state.value.copyWith(
        connection: BackendConnection.connected,
      );
      _recordLifecycle('mock process connected');
      _syncDiagnostics();
    } finally {
      _reconnectFlight = null;
    }
  }

  @override
  Future<void> restartBackend() => _restartFlight ??= _mockRestart();

  Future<void> _mockRestart() async {
    try {
      _recordLifecycle('restart requested');
      if (failNextRestart) {
        failNextRestart = false;
        _recordLifecycle('restart failed');
        throw StateError('mock restart failed');
      }
      _state.value = _state.value.copyWith(
        connection: BackendConnection.disconnected,
      );
      _diagnostics.value = _diagnostics.value.copyWith(
        processGeneration: _diagnostics.value.processGeneration + 1,
      );
      _syncDiagnostics();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await reconnect();
    } finally {
      _restartFlight = null;
    }
  }

  @override
  ValueListenable<BackendDiagnostics> get diagnostics => _diagnostics;

  @override
  String buildDiagnosticsReport({
    required bool? scannerReady,
    required int scannerTargetCount,
  }) {
    final value = _diagnostics.value;
    return [
      'BA Planner diagnostics v1',
      'protocol=${value.protocolVersion}',
      'connection=${value.connection.name}',
      'process_generation=${value.processGeneration}',
      'launcher_configured=${value.launch.configured}',
      'launcher_resolved=${value.launch.resolved}',
      'executable=${value.launch.executable}',
      'arguments=${value.launch.arguments.join(' ')}',
      'working_directory=${value.launch.workingDirectory}',
      'scanner_ready=${scannerReady ?? 'unknown'}',
      'scanner_target_count=$scannerTargetCount',
      'lifecycle:',
      ...value.lifecycle.map((item) => '- $item'),
      'stderr:',
      ...value.stderr.map((item) => '- $item'),
    ].join('\n');
  }

  void _recordLifecycle(String item) {
    final values = [
      ..._diagnostics.value.lifecycle,
      'g${_diagnostics.value.processGeneration}: $item',
    ];
    _diagnostics.value = _diagnostics.value.copyWith(
      lifecycle: List.unmodifiable(
        values.length > 30 ? values.sublist(values.length - 30) : values,
      ),
    );
  }

  void _syncDiagnostics() {
    _diagnostics.value = _diagnostics.value.copyWith(
      connection: _state.value.connection,
    );
  }

  @override
  Future<void> startScan() async {
    _state.value = _state.value.copyWith(scanPhase: ScanPhase.scanning);
    await startScannerSession(ScannerKind.student, 'mock-window');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    _state.value = _state.value.copyWith(
      scanPhase: scannerScenario == MockScannerScenario.failed
          ? ScanPhase.failed
          : ScanPhase.succeeded,
    );
  }

  @override
  Stream<ScannerEvent> get scannerEvents => _scannerEvents.stream;

  @override
  Future<List<ScannerTarget>> listScannerTargets() async => _scannerTargets;

  @override
  Future<Map<String, dynamic>> scannerReadiness() async => _scannerReadiness;

  @override
  Future<ScannerSession> startScannerSession(
    ScannerKind kind,
    String targetId,
  ) async {
    final target = _scannerTargets.where((item) => item.id == targetId);
    if (target.isEmpty || target.single.status != ScannerTargetStatus.ready) {
      throw StateError('target_not_ready');
    }
    final session = ScannerSession(
      id: 'mock-session-${++_scannerGeneration}',
      generation: _scannerGeneration,
      kind: kind,
    );
    _scannerHistory[session.id] = [];
    _emitScannerEvent(session, ScannerEventKind.phase, {'phase': 'capturing'});
    _scannerTimers.add(
      Timer(const Duration(milliseconds: 10), () {
        if (_scannerTerminals.containsKey(session.id)) return;
        _emitScannerEvent(session, ScannerEventKind.progress, {
          'current': 1,
          'total': kind == ScannerKind.student ? null : 2,
          'message_key': 'scanner.${kind.name}.recognizing',
        });
      }),
    );
    _scannerTimers.add(
      Timer(const Duration(milliseconds: 20), () {
        if (_scannerTerminals.containsKey(session.id)) return;
        if (scannerScenario == MockScannerScenario.failed) {
          _emitTerminal(
            session,
            'failed',
            error: const {
              'code': 'mock_failure',
              'message': 'Mock scan failed',
            },
          );
          return;
        }
        final candidate = _mockCandidate(session);
        _scannerCandidates['${session.id}:${candidate.id}'] = candidate;
        _emitScannerEvent(session, ScannerEventKind.candidate, {
          'candidate': _candidateWire(candidate),
        });
      }),
    );
    _scannerTimers.add(
      Timer(const Duration(milliseconds: 30), () {
        if (!_scannerTerminals.containsKey(session.id)) {
          _emitTerminal(session, 'completed');
        }
      }),
    );
    return session;
  }

  @override
  Future<Map<String, dynamic>> cancelScannerSession(
    ScannerSession session,
  ) async {
    final terminal = _scannerTerminals[session.id];
    if (terminal != null) return {'accepted': false, 'terminal': terminal};
    _scannerTimers.add(
      Timer(
        const Duration(milliseconds: 10),
        () => _emitTerminal(session, 'cancelled'),
      ),
    );
    return {'accepted': true, 'terminal': null};
  }

  @override
  Future<ScannerSessionSnapshot> scannerSnapshot(ScannerSession session) async {
    final events = _scannerHistory[session.id] ?? const <ScannerEvent>[];
    return ScannerSessionSnapshot(
      sessionId: session.id,
      generation: session.generation,
      kind: session.kind,
      lastSequence: events.isEmpty ? 0 : events.last.sequence,
      terminal: _scannerTerminals[session.id],
      events: events,
      candidates: _scannerCandidates.entries
          .where((entry) => entry.key.startsWith('${session.id}:'))
          .map((entry) => entry.value)
          .toList(growable: false),
    );
  }

  @override
  Future<ScannerCandidate> getScannerCandidate(
    ScannerSession session,
    String candidateId,
  ) async =>
      _scannerCandidates['${session.id}:$candidateId'] ??
      (throw StateError('candidate_not_found'));

  @override
  Future<ScannerCandidate> reviewScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate,
    Map<String, dynamic> payload, {
    required bool approve,
    required String reason,
  }) async => ScannerCandidate(
    id: candidate.id,
    sessionId: session.id,
    generation: session.generation,
    revision: candidate.revision + 1,
    kind: session.kind,
    payload: payload,
    evidence: candidate.evidence,
    reviewRequired: candidate.reviewRequired,
    approved: approve,
  );

  @override
  Future<Map<String, dynamic>> commitScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate, {
    required String profileId,
    required int expectedRepositoryRevision,
    required String idempotencyKey,
  }) async {
    if (candidate.reviewRequired && !candidate.approved) {
      throw StateError('review_required');
    }
    final current =
        _repositoryStates[profileId] ??
        {
          'profile_id': profileId,
          'revision': 0,
          'students': <dynamic>[],
          'inventory': {'version': 1, 'entries': <dynamic>[]},
          'goals': {'version': 1, 'goals': <dynamic>[]},
        };
    if (current['revision'] != expectedRepositoryRevision) {
      throw StateError('revision_conflict');
    }
    final payload = Map<String, dynamic>.from(candidate.payload);
    final studentId = payload['student_id'];
    final existing = List<dynamic>.from(current['students'] as List);
    if (studentId is String) {
      existing.removeWhere(
        (item) => item is Map && item['student_id'] == studentId,
      );
      existing.add(payload);
    }
    final revision = expectedRepositoryRevision + 1;
    _repositoryStates[profileId] = candidate.kind == ScannerKind.inventory
        ? {...current, 'revision': revision, 'inventory': payload}
        : {...current, 'revision': revision, 'students': existing};
    return {
      'candidate_id': candidate.id,
      'candidate_revision': candidate.revision,
      'profile_id': profileId,
      'revision': revision,
    };
  }

  ScannerCandidate _mockCandidate(ScannerSession session) {
    final inventory = session.kind == ScannerKind.inventory;
    final review =
        scannerScenario == MockScannerScenario.reviewRequired ||
        scannerScenario == MockScannerScenario.inventoryUnknown;
    return ScannerCandidate(
      id: 'mock-candidate-${session.generation}',
      sessionId: session.id,
      generation: session.generation,
      revision: 1,
      kind: session.kind,
      payload: inventory
          ? {
              'version': 1,
              'entries': [
                {
                  'key': 'Item_Icon_ExpItem_0',
                  'quantity':
                      scannerScenario == MockScannerScenario.inventoryUnknown
                      ? null
                      : '12',
                  'item_id': 'Item_Icon_ExpItem_0',
                  'name': 'Basic activity report',
                  'index': 0,
                  'profile_id': 'activity_reports',
                },
              ],
            }
          : {
              'version': 1,
              'student_id': 'aru',
              'values': {'level': 90},
            },
      evidence: [
        ScannerFieldEvidence(
          field: inventory ? 'quantity' : 'level',
          status: review ? 'uncertain' : 'ok',
          source: 'mock_fixture',
          confidence: review ? 0.62 : 0.98,
          note: review ? 'Manual review required' : '',
        ),
      ],
      reviewRequired: review,
      approved: false,
    );
  }

  Map<String, dynamic> _candidateWire(ScannerCandidate candidate) => {
    'candidate_id': candidate.id,
    'session_id': candidate.sessionId,
    'generation': candidate.generation,
    'revision': candidate.revision,
    'scan_kind': candidate.kind.name,
    'payload': candidate.payload,
    'evidence': [
      for (final item in candidate.evidence)
        {
          'field': item.field,
          'status': item.status,
          'source': item.source,
          'confidence': item.confidence,
          'note': item.note,
        },
    ],
    'review_required': candidate.reviewRequired,
    'approved': candidate.approved,
    'audit': <dynamic>[],
  };

  void _emitScannerEvent(
    ScannerSession session,
    ScannerEventKind kind,
    Map<String, dynamic> payload,
  ) {
    final history = _scannerHistory[session.id];
    if (history == null || _scannerTerminals.containsKey(session.id)) return;
    final event = ScannerEvent(
      sessionId: session.id,
      generation: session.generation,
      sequence: history.length + 1,
      kind: session.kind,
      eventKind: kind,
      payload: {
        'session_id': session.id,
        'generation': session.generation,
        'sequence': history.length + 1,
        'scan_kind': session.kind.name,
        'event_kind': kind.name,
        ...payload,
      },
    );
    history.add(event);
    _scannerEvents.add(event);
  }

  void _emitTerminal(
    ScannerSession session,
    String outcome, {
    Map<String, dynamic>? error,
  }) {
    if (_scannerTerminals.containsKey(session.id)) return;
    final payload = <String, dynamic>{'outcome': outcome};
    if (error != null) {
      payload['error'] = error;
    }
    _emitScannerEvent(session, ScannerEventKind.terminal, payload);
    _scannerTerminals[session.id] = outcome;
  }

  @override
  Future<Map<String, dynamic>?> getStudent(String studentId) async {
    for (final student in await _loadStudentCatalog()) {
      if (student.studentId == studentId) return student.metadata;
    }
    return null;
  }

  @override
  Future<List<StudentCatalogEntry>> listStudents() async {
    final catalog = await _loadStudentCatalog();
    final visibleCatalog = fullStudentCatalog
        ? catalog
        : catalog
              .where(
                (student) => const {'aru', 'ayane'}.contains(student.studentId),
              )
              .toList(growable: false);
    final longName = _state.value.useLongNames
        ? 'Aru with an intentionally long display name for responsive layout verification'
        : null;
    return [
      for (final student in visibleCatalog)
        if (student.studentId == 'aru' &&
            (!fullStudentCatalog || longName != null))
          StudentCatalogEntry.fromWire({
            ..._studentCatalogWire(student),
            'display_name': longName ?? 'Aru',
          })
        else if (student.studentId == 'ayane' && !fullStudentCatalog)
          StudentCatalogEntry.fromWire({
            ..._studentCatalogWire(student),
            'display_name': 'Ayane',
          })
        else
          student,
      if (_state.value.hasMissingMetadata)
        StudentCatalogEntry.fallback('missing-student'),
    ];
  }

  Future<List<StudentCatalogEntry>> _loadStudentCatalog() async {
    final cached = _studentCatalog;
    if (cached != null) return cached;
    final data = await rootBundle.load('assets/student_catalog.json');
    final source = utf8.decode(data.buffer.asUint8List());
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      throw const FormatException('Invalid bundled student catalog');
    }
    final result = List<StudentCatalogEntry>.unmodifiable(
      decoded.map(
        (item) => StudentCatalogEntry.fromWire(
          Map<String, dynamic>.from(item as Map),
        ),
      ),
    );
    _studentCatalog = result;
    return result;
  }

  Map<String, dynamic> _studentCatalogWire(StudentCatalogEntry student) => {
    'student_id': student.studentId,
    'display_name': student.displayName,
    'template_name': student.templateName,
    'group': student.group,
    'variant': student.variant,
    'school': student.school,
    'rarity': student.rarity,
    'attack_type': student.attackType,
    'defense_type': student.defenseType,
    'combat_class': student.combatClass,
    'role': student.role,
    'position': student.position,
    'equipment_slot_1': student.equipmentSlot1,
    'equipment_slot_2': student.equipmentSlot2,
    'equipment_slot_3': student.equipmentSlot3,
    'jp_only': student.jpOnly,
    'search_tags': student.searchTags,
    'kr_search_tags': student.krSearchTags,
  };

  @override
  Future<List<InventoryCatalogEntry>> listInventoryItems() async => const [
    InventoryCatalogEntry(
      resourceKey: 'Item_Icon_ExpItem_0',
      itemId: 'Item_Icon_ExpItem_0',
      displayName: 'Basic activity report',
      category: 'activity_report',
      profileId: 'activity_reports',
      orderIndex: 0,
      zeroFillAllowed: true,
    ),
    InventoryCatalogEntry(
      resourceKey: 'Item_Icon_SkillBook_Gehenna_0',
      itemId: 'Item_Icon_SkillBook_Gehenna_0',
      displayName: 'Gehenna Note T1',
      category: 'tech_notes',
      profileId: 'tech_notes',
      orderIndex: 0,
      zeroFillAllowed: true,
    ),
    InventoryCatalogEntry(
      resourceKey: 'Item_Icon_Material_Nebra_0',
      itemId: 'Item_Icon_Material_Nebra_0',
      displayName: 'Nebra Disk T1',
      category: 'oopart',
      profileId: 'ooparts',
      orderIndex: 0,
      zeroFillAllowed: true,
    ),
  ];

  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) async {
    final entries = <String, int?>{};
    for (final raw in inventory['entries'] as List? ?? const []) {
      final item = raw as Map;
      final quantity = item['quantity'];
      entries[(item['item_id'] ?? item['key']) as String] = quantity == null
          ? null
          : int.parse(quantity as String);
    }
    final affected = (plan['goals'] as List? ?? const [])
        .map((item) => (item as Map)['student_id'] as String)
        .toList();
    const required = 12;
    final owned = entries['Item_Icon_ExpItem_0'];
    return InventoryShortageResult([
      InventoryShortageRow(
        resourceKey: 'Item_Icon_ExpItem_0',
        itemId: 'Item_Icon_ExpItem_0',
        displayName: 'Basic activity report',
        category: 'activity_report',
        requiredAmount: required,
        owned: owned,
        shortage: owned == null
            ? null
            : (owned >= required ? 0 : required - owned),
        affectedStudentIds: affected,
        resolved: true,
      ),
    ], const []);
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
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async {
    final phases = (document['phases'] as List<dynamic>? ?? const []);
    final stageResults = <Map<String, dynamic>>[];
    final phaseResults = <Map<String, dynamic>>[];
    for (final rawPhase in phases) {
      final phase = Map<String, dynamic>.from(rawPhase as Map);
      final stages = (phase['stages'] as List<dynamic>? ?? const []);
      final stageIds = <String>[];
      for (final rawStage in stages) {
        final stage = Map<String, dynamic>.from(rawStage as Map);
        stageIds.add(stage['stage_id'] as String);
        stageResults.add({
          'stage_id': stage['stage_id'],
          'phase_id': phase['phase_id'],
          'student_id': stage['student_id'],
          'name': stage['name'],
          'cost': <String, dynamic>{},
          'resources': <dynamic>[],
        });
      }
      phaseResults.add({
        'phase_id': phase['phase_id'],
        'name': phase['name'],
        'stage_ids': stageIds,
        'cost': <String, dynamic>{},
        'resources': <dynamic>[],
      });
    }
    return {
      'document_id': document['document_id'],
      'kind': document['kind'],
      'stage_results': stageResults,
      'phase_results': phaseResults,
      'overall': {'cost': <String, dynamic>{}, 'resources': <dynamic>[]},
      'bottlenecks': <dynamic>[],
      'warnings': <dynamic>[],
    };
  }

  @override
  Future<PlanningScenarioComparisonResult> compareScenarios({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required PlanningDocument documentA,
    required PlanningDocument documentB,
  }) async {
    if (documentA.id == documentB.id) throw StateError('invalid_payload');
    final projectionA = await calculatePlanningDocument(
      currentStudents: currentStudents,
      inventory: inventory,
      document: documentA.toWire(),
    );
    final projectionB = await calculatePlanningDocument(
      currentStudents: currentStudents,
      inventory: inventory,
      document: documentB.toWire(),
    );
    Map<String, Map<String, int>> finalTargets(PlanningDocument document) => {
      for (final stage in document.stages) stage.studentId: stage.targets,
    };
    final targetsA = finalTargets(documentA);
    final targetsB = finalTargets(documentB);
    final studentIds = {...targetsA.keys, ...targetsB.keys}.toList()..sort();
    return PlanningScenarioComparisonResult(
      projectionA: projectionA,
      projectionB: projectionB,
      comparison: {
        'credits_a': 0,
        'credits_b': 0,
        'credits_delta_b_minus_a': 0,
        'resource_type_count_a': 0,
        'resource_type_count_b': 0,
        'known_shortage_type_count_a': 0,
        'known_shortage_type_count_b': 0,
        'students': [
          for (final studentId in studentIds)
            {
              'student_id': studentId,
              'presence':
                  targetsA.containsKey(studentId) &&
                      targetsB.containsKey(studentId)
                  ? 'both'
                  : targetsA.containsKey(studentId)
                  ? 'a_only'
                  : 'b_only',
              'target_differences': {
                for (final key in planningDocumentTargetKeys)
                  if (targetsA[studentId]?[key] != targetsB[studentId]?[key])
                    key: {
                      'a': targetsA[studentId]?[key],
                      'b': targetsB[studentId]?[key],
                    },
              },
            },
        ],
        'resources': <dynamic>[],
        'bottlenecks': <dynamic>[],
      },
    );
  }

  int _scenarioCollectionRevision(String profileId) =>
      _planningScenarioRevisions[profileId] ?? 0;

  int _profileRevision(String profileId) =>
      _profiles.firstWhere((profile) => profile.id == profileId).revision;

  PlanningScenarioSummary _scenarioSummary(PlanningScenarioRecord record) {
    final studentIds = <String>{};
    var stageCount = 0;
    for (final phase in record.document.phases) {
      stageCount += phase.stages.length;
      studentIds.addAll(phase.stages.map((stage) => stage.studentId));
    }
    return PlanningScenarioSummary(
      id: record.id,
      revision: record.revision,
      name: record.name,
      description: record.description,
      baseProfileRevision: record.baseProfileRevision,
      phaseCount: record.document.phases.length,
      stageCount: stageCount,
      studentCount: studentIds.length,
      studentIds: List.unmodifiable(studentIds),
      calculation: const PlanningScenarioCalculationSummary(
        credits: 0,
        requiredResourceTypeCount: 0,
        knownShortageTypeCount: 0,
        inventoryComplete: true,
        firstBottleneckPhaseNumber: null,
        representativeShortage: null,
      ),
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }

  void _requireScenarioRevision(String profileId, int expectedRevision) {
    if (_scenarioCollectionRevision(profileId) != expectedRevision) {
      throw StateError('revision_conflict');
    }
  }

  @override
  Future<PlanningScenarioListResult> listScenarios(String profileId) async {
    final scenarios = _planningScenarios[profileId] ?? const [];
    return PlanningScenarioListResult(
      profileId: profileId,
      revision: _scenarioCollectionRevision(profileId),
      currentProfileRevision: _profileRevision(profileId),
      scenarios: List.unmodifiable(scenarios.map(_scenarioSummary)),
    );
  }

  @override
  Future<PlanningScenarioGetResult> getScenario(
    String profileId,
    String scenarioId,
  ) async {
    final scenario = (_planningScenarios[profileId] ?? const []).firstWhere(
      (item) => item.id == scenarioId,
    );
    return PlanningScenarioGetResult(
      profileId: profileId,
      revision: _scenarioCollectionRevision(profileId),
      currentProfileRevision: _profileRevision(profileId),
      scenario: scenario,
    );
  }

  @override
  Future<PlanningScenarioMutationResult> createScenario({
    required String profileId,
    required int expectedRevision,
    required String idempotencyKey,
    required String name,
    required String description,
    required int baseProfileRevision,
    required PlanningDocument document,
  }) async {
    _requireScenarioRevision(profileId, expectedRevision);
    if (document.kind != PlanningDocumentKind.scenario) {
      throw StateError('invalid_payload');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final scenarioId = (_nextPlanningScenarioId++)
        .toRadixString(16)
        .padLeft(24, '0');
    final record = PlanningScenarioRecord(
      id: scenarioId,
      revision: 0,
      profileId: profileId,
      name: name,
      description: description,
      baseProfileRevision: baseProfileRevision,
      document: document,
      createdAt: now,
      updatedAt: now,
    );
    _planningScenarios[profileId] = <PlanningScenarioRecord>[
      ...(_planningScenarios[profileId] ?? const <PlanningScenarioRecord>[]),
      record,
    ];
    final revision = expectedRevision + 1;
    _planningScenarioRevisions[profileId] = revision;
    return PlanningScenarioMutationResult(
      revision: revision,
      scenarioId: scenarioId,
    );
  }

  @override
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
  }) async {
    _requireScenarioRevision(profileId, expectedRevision);
    final scenarios = <PlanningScenarioRecord>[
      ...(_planningScenarios[profileId] ?? const <PlanningScenarioRecord>[]),
    ];
    final index = scenarios.indexWhere((item) => item.id == scenarioId);
    final previous = scenarios[index];
    if (previous.revision != expectedScenarioRevision) {
      throw StateError('revision_conflict');
    }
    scenarios[index] = PlanningScenarioRecord(
      id: scenarioId,
      revision: expectedScenarioRevision + 1,
      profileId: profileId,
      name: name,
      description: description,
      baseProfileRevision: baseProfileRevision,
      document: document,
      createdAt: previous.createdAt,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    _planningScenarios[profileId] = scenarios;
    final revision = expectedRevision + 1;
    _planningScenarioRevisions[profileId] = revision;
    return PlanningScenarioMutationResult(
      revision: revision,
      scenarioId: scenarioId,
    );
  }

  @override
  Future<PlanningScenarioMutationResult> deleteScenario({
    required String profileId,
    required String scenarioId,
    required int expectedRevision,
    required int expectedScenarioRevision,
    required String idempotencyKey,
  }) async {
    _requireScenarioRevision(profileId, expectedRevision);
    final scenarios = <PlanningScenarioRecord>[
      ...(_planningScenarios[profileId] ?? const <PlanningScenarioRecord>[]),
    ];
    final index = scenarios.indexWhere((item) => item.id == scenarioId);
    if (scenarios[index].revision != expectedScenarioRevision) {
      throw StateError('revision_conflict');
    }
    scenarios.removeAt(index);
    _planningScenarios[profileId] = scenarios;
    final revision = expectedRevision + 1;
    _planningScenarioRevisions[profileId] = revision;
    return PlanningScenarioMutationResult(
      revision: revision,
      scenarioId: scenarioId,
    );
  }

  @override
  Future<PlanningScenarioMutationResult> duplicateScenario({
    required String profileId,
    required String scenarioId,
    required int expectedRevision,
    required int expectedScenarioRevision,
    required String idempotencyKey,
  }) async {
    final source = (await getScenario(profileId, scenarioId)).scenario;
    if (source.revision != expectedScenarioRevision) {
      throw StateError('revision_conflict');
    }
    return createScenario(
      profileId: profileId,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
      name: '${source.name} (복사본)',
      description: source.description,
      baseProfileRevision: source.baseProfileRevision,
      document: PlanningDocument(
        id: '${source.document.id}-copy',
        name: '${source.document.name} (복사본)',
        kind: PlanningDocumentKind.scenario,
        phases: source.document.phases,
      ),
    );
  }

  @override
  Future<List<RepositoryProfile>> listProfiles() async =>
      List.unmodifiable(_profiles);

  @override
  Future<RepositoryProfile> createProfile(
    String displayName,
    String idempotencyKey, {
    String avatarStudentId = 'hasumi',
  }) async {
    if (failNextProfileMutation) {
      failNextProfileMutation = false;
      throw StateError('revision_conflict');
    }
    final profile = RepositoryProfile(
      id: (_profiles.length + 1).toRadixString(16).padLeft(24, '0'),
      displayName: displayName,
      avatarStudentId: avatarStudentId,
      revision: 0,
      selected: false,
    );
    _profiles.add(profile);
    return profile;
  }

  @override
  Future<int> selectProfile(
    String profileId,
    int expectedRevision,
    String idempotencyKey,
  ) async {
    if (failNextProfileMutation) {
      failNextProfileMutation = false;
      throw StateError('revision_conflict');
    }
    final target = _profiles.firstWhere((profile) => profile.id == profileId);
    if (target.revision != expectedRevision) {
      throw StateError('revision_conflict');
    }
    for (var index = 0; index < _profiles.length; index++) {
      final profile = _profiles[index];
      _profiles[index] = RepositoryProfile(
        id: profile.id,
        displayName: profile.displayName,
        avatarStudentId: profile.avatarStudentId,
        revision: profile.id == profileId
            ? expectedRevision + 1
            : profile.revision,
        selected: profile.id == profileId,
      );
    }
    return expectedRevision + 1;
  }

  @override
  Future<int> renameProfile(
    String profileId,
    String displayName,
    int expectedRevision,
    String idempotencyKey,
  ) async {
    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    final profile = _profiles[index];
    if (failNextProfileMutation || profile.revision != expectedRevision) {
      failNextProfileMutation = false;
      throw StateError('revision_conflict');
    }
    _profiles[index] = RepositoryProfile(
      id: profile.id,
      displayName: displayName,
      avatarStudentId: profile.avatarStudentId,
      revision: expectedRevision + 1,
      selected: profile.selected,
    );
    return expectedRevision + 1;
  }

  @override
  Future<int> updateProfile(
    String profileId,
    String displayName,
    String avatarStudentId,
    int expectedRevision,
    String idempotencyKey,
  ) async {
    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    final profile = _profiles[index];
    if (failNextProfileMutation || profile.revision != expectedRevision) {
      failNextProfileMutation = false;
      throw StateError('revision_conflict');
    }
    _profiles[index] = RepositoryProfile(
      id: profile.id,
      displayName: displayName,
      avatarStudentId: avatarStudentId,
      revision: expectedRevision + 1,
      selected: profile.selected,
    );
    return expectedRevision + 1;
  }

  @override
  Future<int> deleteProfile(
    String profileId,
    int expectedRevision,
    String idempotencyKey,
  ) async {
    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    final profile = _profiles[index];
    if (failNextProfileMutation || profile.revision != expectedRevision) {
      failNextProfileMutation = false;
      throw StateError('revision_conflict');
    }
    final wasSelected = profile.selected;
    _profiles.removeAt(index);
    _repositoryStates.remove(profileId);
    _planningScenarios.remove(profileId);
    _planningScenarioRevisions.remove(profileId);
    if (wasSelected && _profiles.isNotEmpty) {
      final first = _profiles.first;
      _profiles[0] = RepositoryProfile(
        id: first.id,
        displayName: first.displayName,
        avatarStudentId: first.avatarStudentId,
        revision: first.revision,
        selected: true,
      );
    }
    return expectedRevision + 1;
  }

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async =>
      RepositoryState.fromWire(
        Map<String, dynamic>.from(
          _repositoryStates[profileId] ??
              {
                'profile_id': profileId,
                'revision': 0,
                'students': <dynamic>[],
                'inventory': {'version': 1, 'entries': <dynamic>[]},
                'goals': {'version': 1, 'goals': <dynamic>[]},
              },
        ),
      );

  TacticalState _tactical(String profileId) =>
      _tacticalStates[profileId] ??
      TacticalState(
        profileId: profileId,
        revision: 0,
        matches: const [],
        jokbo: const [],
      );
  @override
  Future<TacticalState> loadTacticalState(String profileId) async =>
      _tactical(profileId);
  int _tacticalRevision(String profileId, int expected) {
    final state = _tactical(profileId);
    if (state.revision != expected) throw StateError('revision_conflict');
    return expected + 1;
  }

  @override
  Future<int> saveTacticalMatch(
    String profileId,
    TacticalMatch match,
    int expectedRevision,
    String idempotencyKey,
  ) async {
    final state = _tactical(profileId),
        revision = _tacticalRevision(profileId, expectedRevision);
    _tacticalStates[profileId] = TacticalState(
      profileId: profileId,
      revision: revision,
      matches: [...state.matches.where((item) => item.id != match.id), match],
      jokbo: state.jokbo,
    );
    return revision;
  }

  @override
  Future<int> deleteTacticalMatch(
    String profileId,
    String matchId,
    int expectedRevision,
    String idempotencyKey,
  ) async {
    final state = _tactical(profileId),
        revision = _tacticalRevision(profileId, expectedRevision);
    _tacticalStates[profileId] = TacticalState(
      profileId: profileId,
      revision: revision,
      matches: state.matches.where((item) => item.id != matchId).toList(),
      jokbo: state.jokbo,
    );
    return revision;
  }

  @override
  Future<int> saveTacticalJokbo(
    String profileId,
    TacticalJokbo jokbo,
    int expectedRevision,
    String idempotencyKey,
  ) async {
    final state = _tactical(profileId),
        revision = _tacticalRevision(profileId, expectedRevision);
    _tacticalStates[profileId] = TacticalState(
      profileId: profileId,
      revision: revision,
      matches: state.matches,
      jokbo: [...state.jokbo.where((item) => item.id != jokbo.id), jokbo],
    );
    return revision;
  }

  @override
  Future<int> deleteTacticalJokbo(
    String profileId,
    String jokboId,
    int expectedRevision,
    String idempotencyKey,
  ) async {
    final state = _tactical(profileId),
        revision = _tacticalRevision(profileId, expectedRevision);
    _tacticalStates[profileId] = TacticalState(
      profileId: profileId,
      revision: revision,
      matches: state.matches,
      jokbo: state.jokbo.where((item) => item.id != jokboId).toList(),
    );
    return revision;
  }

  @override
  Future<int> saveRepositoryGoals(
    String profileId,
    Map<String, dynamic> goals,
    int expectedRevision,
    String idempotencyKey,
  ) async {
    final current =
        _repositoryStates[profileId] ??
        {
          'profile_id': profileId,
          'revision': 0,
          'students': <dynamic>[],
          'inventory': {'version': 1, 'entries': <dynamic>[]},
          'goals': {'version': 1, 'goals': <dynamic>[]},
        };
    _repositoryStates[profileId] = {
      ...current,
      'revision': expectedRevision + 1,
      'goals': goals,
    };
    return expectedRevision + 1;
  }

  @override
  Future<int> saveRepositoryStudents(
    String profileId,
    List<ConfirmedStudentState> students,
    int expectedRevision,
    String idempotencyKey,
  ) async {
    final current =
        _repositoryStates[profileId] ??
        {
          'profile_id': profileId,
          'revision': 0,
          'students': <dynamic>[],
          'inventory': {'version': 1, 'entries': <dynamic>[]},
          'goals': {'version': 1, 'goals': <dynamic>[]},
        };
    _repositoryStates[profileId] = {
      ...current,
      'revision': expectedRevision + 1,
      'students': students
          .map((student) => student.toWire())
          .toList(growable: false),
    };
    return expectedRevision + 1;
  }

  @override
  Future<int> saveRepositoryInventory(
    String profileId,
    RepositoryInventoryState inventory,
    int expectedRevision,
    String idempotencyKey,
  ) async {
    final current =
        _repositoryStates[profileId] ??
        {
          'profile_id': profileId,
          'revision': 0,
          'students': <dynamic>[],
          'inventory': {'version': 1, 'entries': <dynamic>[]},
          'goals': {'version': 1, 'goals': <dynamic>[]},
        };
    if (current['revision'] != expectedRevision) {
      throw StateError('revision_conflict');
    }
    _repositoryStates[profileId] = {
      ...current,
      'revision': expectedRevision + 1,
      'inventory': inventory.toWire(),
    };
    return expectedRevision + 1;
  }

  @override
  Future<List<RepositoryV6AccountPreview>> previewV6Accounts() async =>
      const [];

  @override
  Future<RepositoryV6ImportResult> importV6Account(String sourceProfileKey) =>
      throw UnsupportedError('Mock v6 migration is unavailable');

  @override
  Future<void> dispose() async {
    for (final timer in _scannerTimers) {
      timer.cancel();
    }
    await _scannerEvents.close();
    _diagnostics.dispose();
    _state.dispose();
  }

  @override
  void setConnection(BackendConnection value) {
    _state.value = _state.value.copyWith(connection: value);
    _recordLifecycle('scenario connection=${value.name}');
    _syncDiagnostics();
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
