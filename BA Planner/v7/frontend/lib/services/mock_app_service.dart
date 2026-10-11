import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../ui/models/planning_models.dart';
import 'app_service.dart';
import 'diagnostics_service.dart';
import 'mock_student_fixture.dart';
import 'mock_student_calculation_fixture.dart';
import 'mock_student_bond_fixture.dart';
import 'repository_service.dart';
import 'mock_repository_plan.dart';
import 'mock_repository_history.dart';
import 'planning_protocol_client.dart';
import 'scanner_service.dart';
import 'scenario_service.dart';
import 'tactical_service.dart';

enum MockScannerScenario { completed, failed, reviewRequired, inventoryUnknown }

/// 백엔드 packaged v1 빈 획득처 표(`{"resources":{},"version":1}`)의 revision. `resource_acquisition_payload`가 정렬·
/// 압축한 JSON의 sha256이며 공유 fixture `resource_acquisition_v1.json`의 known-empty 응답 값과 같다.
const mockEmptyResourceAcquisitionRevision =
    'd1d01c1803e0005ad126df3ba58dcda51a9f3d08582a32ef1ac7f21c938f85e6';

class MockAppService
    implements
        AppService,
        PlanningStudentCalculationService,
        PlanningStudentBondCalculationService,
        PlanningDocumentService,
        ResourceAcquisitionService,
        PlanningScenarioRepositoryService,
        PlanningScenarioComparisonService,
        MockScenarioController,
        RepositoryService,
        RepositoryPlanService,
        RepositoryPresetsService,
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
    Map<String, Map<String, dynamic>>? repositoryStates,
    DateTime Function()? historyClock,
    Map<String, RepositoryCurrentHistory>? repositoryHistories,
  }) : _historyClock = historyClock ?? (() => DateTime.now().toUtc()),
       _scannerTargets = List.unmodifiable(
         scannerTargets ??
             const [
               ScannerTarget(
                 id: 'mock-window',
                 title: 'Mock Blue Archive',
                 status: ScannerTargetStatus.ready,
                 foreground: true,
                 // FB-4 연결 메모의 Mock 예시 값(물리 client 2560×1440, blue_archive).
                 clientWidth: 2560,
                 clientHeight: 1440,
                 game: ScannerTargetGame.blueArchive,
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
    for (final profile in _profiles) {
      if (repositoryStates?.containsKey(profile.id) != true) {
        _repositoryPlans[profile.id] = mockDocumentFromGoals({'version': 1, 'goals': <dynamic>[]});
      }
    }
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
    for (final entry in repositoryStates?.entries ?? const <MapEntry<String, Map<String, dynamic>>>[]) {
      RepositoryState.fromWire(entry.value);
      _repositoryStates[entry.key] = Map<String, dynamic>.from(jsonDecode(jsonEncode(entry.value)) as Map);
    }
    for (final entry in repositoryHistories?.entries ?? const <MapEntry<String,RepositoryCurrentHistory>>[]) {
      if (!_profiles.any((p)=>p.id==entry.key)) throw StateError('profile_not_found');
      validateRepositoryHistoryCurrent(entry.value,RepositoryState.fromWire(_mockRepositoryState(entry.key)));
      _currentHistories[entry.key]=RepositoryCurrentHistory.fromWire(entry.value.toWire());
    }
    _trackMockCurrentWrites = true;
  }

  List<StudentCatalogEntry>? _studentCatalog;

  final Map<String, List<PlanningScenarioRecord>> _planningScenarios = {};
  final Map<String, int> _planningScenarioRevisions = {};
  final Map<
    String,
    Map<String, ({String fingerprint, PlanningScenarioMutationResult response})>
  >
  _scenarioIdempotency = {};
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
  late final Map<String, Map<String, dynamic>> _repositoryStates =
      MockRepositoryCurrentMap(_observeMockCurrentWrite);
  bool _trackMockCurrentWrites = false;
  bool _manualMockCurrentWrite = false;
  final DateTime Function() _historyClock;
  final Map<String, RepositoryCurrentHistory> _currentHistories = {};
  final Map<String, PlanningDocument> _repositoryPlans = {};
  final Map<String, PlanningAuthoring> _repositoryPlanAuthoring = {};
  final Map<String, RepositoryPresetsState> _repositoryPresets = {};
  final Map<String, Map<String, ({String fingerprint, int revision})>> _presetIdempotency = {};
  final Map<String, Map<String, ({String fingerprint, Map<String, dynamic> response})>> _planIdempotency = {};
  final Map<String, TacticalState> _tacticalStates = {};
  final StreamController<ScannerEvent> _scannerEvents =
      StreamController.broadcast();
  final Map<String, List<ScannerEvent>> _scannerHistory = {};
  late final Map<String, ScannerCandidate> _scannerCandidates =
      MockScannerCandidateMap(_rememberScannerInventoryKeys);
  final Map<String, String> _scannerTerminals = {};
  final List<Timer> _scannerTimers = [];
  var _scannerGeneration = 0;
  bool failNextReconnect = false;
  bool failNextRestart = false;
  bool failNextProfileMutation = false;

  /// 다음 획득처 조회를 `resource_acquisition_failed`(표를 읽지 못함)로 실패시킨다. 모르는 키(`resource_not_found`)와 구별된다.
  bool failNextResourceAcquisition = false;
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
    String targetId, {
    String? profileId,
    StudentScanMode studentScanMode = StudentScanMode.single,
    InventoryScanProfile? inventoryScanProfile,
  }) async {
    final target = _scannerTargets.where((item) => item.id == targetId);
    if (target.isEmpty || target.single.status != ScannerTargetStatus.ready) {
      throw StateError('target_not_ready');
    }
    final session = ScannerSession(
      id: 'mock-session-${++_scannerGeneration}',
      generation: _scannerGeneration,
      kind: kind,
      studentScanMode: studentScanMode,
    );
    _scannerHistory[session.id] = [];
    _scannerSessionRaw[session.id] = (
      scanKind: kind.wireName,
      inventoryScanProfile: kind == ScannerKind.inventory
          ? inventoryScanProfile?.wireName
          : null,
    );
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
    Map<int, int>? relationshipRanks,
  }) async {
    final studentRevalidation =
        session.kind == ScannerKind.student &&
        reason == 'edited_and_revalidated_in_scan_page';
    final reviewed = ScannerCandidate(
      id: candidate.id,
      sessionId: session.id,
      generation: session.generation,
      revision: candidate.revision + 1,
      kind: session.kind,
      payload: payload,
      evidence: [
        for (final item in candidate.evidence)
          studentRevalidation &&
                  !{
                    'ok',
                    'inferred',
                    'skipped',
                    'verified',
                  }.contains(item.status)
              ? ScannerFieldEvidence(
                  field: item.field,
                  status: 'verified',
                  source: 'user_review',
                  confidence: 1,
                  note: 'field confirmed in scanner review workspace',
                  details: item.details,
                )
              : item,
      ],
      reviewRequired: studentRevalidation ? false : candidate.reviewRequired,
      approved: approve,
    );
    _scannerCandidates['${session.id}:${candidate.id}'] = reviewed;
    return reviewed;
  }

  @override
  Future<ScannerCandidate> revalidateScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate, {
    Map<int, int>? relationshipRanks,
  }) async {
    final revised = ScannerCandidate(
      id: candidate.id,
      sessionId: candidate.sessionId,
      generation: candidate.generation,
      revision: candidate.revision + 1,
      kind: candidate.kind,
      payload: candidate.payload,
      evidence: candidate.evidence,
      reviewRequired: candidate.reviewRequired,
      approved: false,
    );
    _scannerCandidates['${session.id}:${candidate.id}'] = revised;
    return revised;
  }

  @override
  Future<Map<String, dynamic>> commitScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate, {
    required String profileId,
    required int expectedRepositoryRevision,
    required String idempotencyKey,
  }) async {
    if (session.kind != ScannerKind.tacticalLobby) {
      return _commitMockScanCurrent(
        session,
        candidate,
        profileId: profileId,
        expectedRepositoryRevision: expectedRepositoryRevision,
        idempotencyKey: idempotencyKey,
      );
    }
    // Tactical lobby keeps its existing four-argument path (no scan history port).
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

  // ---- S-FB2b Mock scanner commit (Python scanner_session parity) ----
  // Raw session metadata, identified inventory keys and the session/key receipt
  // cache are Mock-internal. No public scanner DTO, method or RPC field grows.
  final Map<String, ({String scanKind, String? inventoryScanProfile})>
  _scannerSessionRaw = {};
  final Map<String, List<String>> _scannerIdentifiedInventoryKeys = {};
  final Map<String, _MockScanCommitReceipt> _scannerCommitReceipts = {};
  bool _scannerMockCurrentWrite = false;

  /// Test injection for raw scan metadata the public start API cannot express
  /// (e.g. an unknown future inventory profile). Strings are kept raw.
  @visibleForTesting
  void debugSetScannerSessionRawMetadata(
    ScannerSession session, {
    required String scanKind,
    required String? inventoryScanProfile,
  }) {
    for (final value in [scanKind, ?inventoryScanProfile]) {
      if (value.isEmpty || utf8.encode(value).length > 1024) {
        throw const FormatException('Raw scan metadata must be 1..1024 bytes');
      }
    }
    _scannerSessionRaw[session.id] = (
      scanKind: scanKind,
      inventoryScanProfile: inventoryScanProfile,
    );
  }

  void _rememberScannerInventoryKeys(String key, ScannerCandidate candidate) {
    if (candidate.kind != ScannerKind.inventory) return;
    final known = _scannerIdentifiedInventoryKeys.putIfAbsent(key, () => []);
    final entries = candidate.payload['entries'];
    if (entries is! List) return;
    for (final entry in entries) {
      if (entry is! Map) continue;
      final identity = entry['item_id'] ?? entry['key'];
      if (identity is! String || identity.isEmpty) continue;
      final canonical = historyCanonicalResourceKey(identity);
      if (!known.contains(canonical)) known.add(canonical);
    }
  }

  /// Receipt first: the same session/key with the same public request returns the
  /// first response without reading or writing again; a different public request
  /// under that key is idempotency_conflict. A pending receipt keeps the original
  /// frozen bucket/context, so a retry never re-merges from a later repository.
  Map<String, dynamic> _commitMockScanCurrent(
    ScannerSession session,
    ScannerCandidate candidate, {
    required String profileId,
    required int expectedRepositoryRevision,
    required String idempotencyKey,
  }) {
    final publicRequest = historyCanonicalJson({
      'session_id': session.id,
      'generation': session.generation,
      'candidate_id': candidate.id,
      'candidate_revision': candidate.revision,
      'profile_id': profileId,
      'expected_repository_revision': expectedRepositoryRevision,
      'idempotency_key': idempotencyKey,
    });
    final cacheKey = '${session.id}\u0000$idempotencyKey';
    var receipt = _scannerCommitReceipts[cacheKey];
    if (receipt != null) {
      if (receipt.publicRequest != publicRequest) {
        throw StateError('idempotency_conflict');
      }
      final response = receipt.response;
      if (response != null) return Map<String, dynamic>.from(response);
    } else {
      final stored = _scannerCandidates['${session.id}:${candidate.id}'];
      if (stored != null && stored.revision != candidate.revision) {
        throw StateError('candidate_revision_conflict');
      }
      final item = stored ?? candidate;
      if (item.reviewRequired && !item.approved) {
        throw StateError('review_required');
      }
      receipt = _MockScanCommitReceipt(
        publicRequest,
        _prepareMockScanCommit(session, item, profileId),
      );
      _scannerCommitReceipts[cacheKey] = receipt;
    }
    final frozen = receipt.frozen!;
    final current = _mockRepositoryState(profileId);
    if (current['revision'] != expectedRepositoryRevision) {
      throw StateError('revision_conflict');
    }
    final revision = expectedRepositoryRevision + 1;
    final next = <String, dynamic>{
      ...current,
      'revision': revision,
      frozen.bucket: jsonDecode(frozen.currentJson),
    };
    final before = RepositoryState.fromWire(current);
    final after = RepositoryState.fromWire(next);
    final history =
        _currentHistories[profileId] ??
        RepositoryCurrentHistory.empty(legacy: before);
    final updated = history.appendScan(
      before,
      after,
      _historyClock(),
      rawScanKind: frozen.scanKind,
      rawInventoryScanProfile: frozen.inventoryScanProfile,
      scanContext: frozen.context,
      studentIds: frozen.bucket == 'students' ? frozen.appliedKeys : const [],
      resourceKeys: frozen.bucket == 'inventory'
          ? frozen.appliedKeys
          : const [],
    );
    // The scan event above is the only history record: the current-map observer
    // must not add an unattributed duplicate for this write.
    _scannerMockCurrentWrite = true;
    try {
      _repositoryStates[profileId] = next;
    } finally {
      _scannerMockCurrentWrite = false;
    }
    _currentHistories[profileId] = updated;
    if (_profiles.any((item) => item.id == profileId)) {
      _syncMockPlanRevision(profileId, revision);
    }
    final response = Map<String, dynamic>.unmodifiable({
      'candidate_id': candidate.id,
      'candidate_revision': candidate.revision,
      'profile_id': profileId,
      'revision': revision,
    });
    receipt
      ..response = response
      ..frozen = null; // keep signature + response, release the full bucket.
    return Map<String, dynamic>.from(response);
  }

  _MockFrozenScanCommit _prepareMockScanCommit(
    ScannerSession session,
    ScannerCandidate item,
    String profileId,
  ) {
    final raw =
        _scannerSessionRaw[session.id] ??
        (scanKind: session.kind.wireName, inventoryScanProfile: null);
    final inventory = session.kind == ScannerKind.inventory;
    final bucket = inventory ? 'inventory' : 'students';
    final (scanned, applied) = _mockScanPayload(inventory, item.payload);
    // Validate the scope before reading state: empty/all-excluded never commits.
    if (applied.isEmpty) {
      throw BackendRemoteException(
        code: 'invalid_candidate',
        message: 'Scan applied scope must be non-empty',
        details: const {'reason': 'empty_scan_scope'},
      );
    }
    if (applied.toSet().length != applied.length) {
      throw BackendRemoteException(
        code: 'invalid_candidate',
        message: 'Duplicate canonical scan identity',
        details: const {'reason': 'duplicate_identity'},
      );
    }
    final excluded = inventory
        ? [
            for (final key
                in _scannerIdentifiedInventoryKeys['${session.id}:${item.id}'] ??
                    const <String>[])
              if (!applied.contains(key)) key,
          ]
        : const <String>[];
    final state = _ensureMockRepositoryPlan(profileId);
    final Object current;
    if (inventory) {
      // Upsert by canonical identity; a scan never deletes entries it did not observe.
      final saved = Map<String, dynamic>.from(state['inventory'] as Map);
      String identity(Map entry) =>
          historyCanonicalResourceKey((entry['item_id'] ?? entry['key']) as String);
      final updates = <String, dynamic>{
        for (final entry in scanned['entries'] as List)
          identity(entry as Map): entry,
      };
      final entries = [
        for (final entry in saved['entries'] as List)
          updates.remove(identity(entry as Map)) ?? entry,
        ...updates.values,
      ];
      final catalog = scanned['catalog_revision'] ?? saved['catalog_revision'];
      current = {
        'version': 1,
        'catalog_revision': ?catalog,
        'entries': entries,
      };
    } else {
      current = [
        for (final row in state['students'] as List)
          if ((row as Map)['student_id'] != scanned['student_id']) row,
        scanned,
      ];
    }
    final context = <String, dynamic>{
      'session_id': session.id,
      'generation': session.generation,
      'candidate_id': item.id,
      'candidate_revision': item.revision,
    };
    return _MockFrozenScanCommit(
      bucket: bucket,
      currentJson: jsonEncode(current),
      scanKind: raw.scanKind,
      inventoryScanProfile: raw.inventoryScanProfile,
      context: context,
      appliedKeys: List.unmodifiable(applied),
      // Server-internal provenance (Python flat context): kept with the frozen
      // request, never persisted in history or sent over the public RPC.
      provenance: historyCanonicalJson({
        'source': 'scan',
        ...context,
        'scan_kind': raw.scanKind,
        'inventory_scan_profile': raw.inventoryScanProfile,
        'applied_keys': applied,
        'excluded_keys': excluded,
        'retry_of': null,
      }),
    );
  }

  (Map<String, dynamic>, List<String>) _mockScanPayload(
    bool inventory,
    Map<String, dynamic> raw,
  ) {
    try {
      final payload = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(raw)) as Map,
      );
      if (!inventory) {
        final student = ConfirmedStudentState.fromWire(payload).toWire();
        return (student, [student['student_id'] as String]);
      }
      final scanned = _mockScannedInventory(payload);
      return (
        scanned,
        [
          for (final entry in scanned['entries'] as List)
            historyCanonicalResourceKey(
              (entry['item_id'] ?? entry['key']) as String,
            ),
        ],
      );
    } on FormatException catch (error) {
      throw BackendRemoteException(
        code: 'invalid_candidate',
        message: error.message,
        details: const {'reason': 'invalid_candidate'},
      );
    }
  }

  /// Python `_repository_inventory` + canonical rebase of the scanned entries:
  /// drop scanner-only entry fields and map legacy aliases to current keys.
  Map<String, dynamic> _mockScannedInventory(Map<String, dynamic> payload) {
    final entries = payload['entries'];
    if (entries is! List) throw const FormatException('Invalid inventory');
    final cleaned = <String, dynamic>{
      ...payload,
      'entries': [
        for (final raw in entries)
          if (raw is Map)
            <String, dynamic>{
              for (final entry in raw.entries)
                if (entry.key != 'inventory_scan_profile')
                  entry.key as String:
                      (entry.key == 'key' || entry.key == 'item_id') &&
                          entry.value is String
                      ? historyCanonicalResourceKey(entry.value as String)
                      : entry.value,
            }
          else
            raw,
      ],
    };
    return RepositoryInventoryState.fromWire(cleaned).toWire();
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
        const ScannerFieldEvidence(
          field: 'student_stat_validation',
          status: 'verified',
          source: 'student_stats_v1',
          confidence: 1,
          details: {
            'relationship_contributions': [
              {
                'kind': 'current',
                'student_id': 'aru',
                'schaledb_id': 10000,
                'rank': 20,
                'owned': true,
                'applied': true,
                'modifier': {
                  'flat': {'AttackPower': 126, 'MaxHP': 530},
                  'coefficient_basis_points': <String, int>{},
                  'separated_flat': <String, int>{},
                },
              },
              {
                'kind': 'alternate',
                'student_id': 'aru_new_year',
                'schaledb_id': 10031,
                'rank': 10,
                'owned': true,
                'applied': true,
                'modifier': {
                  'flat': {'AttackPower': 45},
                  'coefficient_basis_points': <String, int>{},
                  'separated_flat': <String, int>{},
                },
              },
            ],
          },
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
          'details': item.details,
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
    'has_favorite_item': student.hasFavoriteItem,
    'search_tags': student.searchTags,
    'kr_search_tags': student.krSearchTags,
    // FB-5: 다중 폼 학생에게만 붙는 선택 필드(Python 응답과 같은 모양).
    if (student.forms.isNotEmpty)
      'forms': [for (final form in student.forms) form.toWire()],
  };

  @override
  Future<InventoryCatalogResult> listInventoryItems() async =>
      const InventoryCatalogResult(
        catalogRevision:
            '0000000000000000000000000000000000000000000000000000000000000000',
        items: [
          InventoryCatalogEntry(
            resourceKey: 'Item_Icon_ExpItem_0',
            itemId: 'Item_Icon_ExpItem_0',
            displayName: 'Basic activity report',
            category: 'activity_report',
            profileId: 'activity_reports',
            orderIndex: 0,
            zeroFillAllowed: true,
            school: null,
            family: 'activity_report',
            tier: 1,
          ),
          InventoryCatalogEntry(
            resourceKey: 'Item_Icon_SkillBook_Gehenna_0',
            itemId: 'Item_Icon_SkillBook_Gehenna_0',
            displayName: 'Gehenna Note T1',
            category: 'tech_notes',
            profileId: 'tech_notes',
            orderIndex: 0,
            zeroFillAllowed: true,
            school: 'Gehenna',
            family: 'tech_notes',
            tier: 1,
          ),
          InventoryCatalogEntry(
            resourceKey: 'Item_Icon_Material_Nebra_0',
            itemId: 'Item_Icon_Material_Nebra_0',
            displayName: 'Nebra Disk T1',
            category: 'oopart',
            profileId: 'ooparts',
            orderIndex: 0,
            zeroFillAllowed: true,
            school: null,
            family: 'oopart:Nebra',
            tier: 1,
          ),
          // FB-3 카탈로그 전용 재화(백엔드 `inventory_catalog._rows` 끝 두 행과 같은 키·순서). 보유량은 스캔만 바꾼다.
          InventoryCatalogEntry(
            resourceKey: 'credits',
            itemId: null,
            displayName: '크레딧',
            category: 'credits',
            profileId: 'currencies',
            orderIndex: 0,
            zeroFillAllowed: false,
            school: null,
            family: null,
            tier: null,
          ),
          InventoryCatalogEntry(
            resourceKey: 'Item_Icon_SecretStone',
            itemId: 'Item_Icon_SecretStone',
            displayName: '엘리그마',
            category: 'eligma',
            profileId: 'currencies',
            orderIndex: 1,
            zeroFillAllowed: false,
            school: null,
            family: null,
            tier: null,
          ),
        ],
      );

  /// FB-3 획득처. 기본 표는 백엔드 packaged v1과 같이 비어 있다(`resources={}`): 카탈로그에 있는 키는 정규 키 +
  /// `methods=[]` + 빈 표 revision, 모르는 키는 `resource_not_found`, 표 실패는 `resource_acquisition_failed`.
  /// Mock은 획득처 행·주간량을 지어내지 않는다.
  @override
  Future<ResourceAcquisitionResult> getResourceAcquisition(
    String resourceKey,
  ) async {
    // 잘못된 질의는 Process와 같이 보내기 전 [FormatException]이다. 순서는 백엔드와 같다(질의 → 카탈로그 → 표).
    final query = ResourceAcquisitionQuery(resourceKey);
    final canonical = historyCanonicalResourceKey(query.resourceKey);
    final catalog = await listInventoryItems();
    if (!catalog.items.any((item) => item.resourceKey == canonical)) {
      throw BackendRemoteException(
        code: 'resource_not_found',
        message: 'Resource is not present in the inventory catalog',
      );
    }
    if (failNextResourceAcquisition) {
      failNextResourceAcquisition = false;
      throw BackendRemoteException(
        code: 'resource_acquisition_failed',
        message: 'Mock acquisition table is unavailable',
      );
    }
    return ResourceAcquisitionResult.fromWire({
      'resource_key': canonical,
      'methods': const <Object>[],
      'acquisition_revision': mockEmptyResourceAcquisitionRevision,
    });
  }

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
  Future<StudentCalculationResult> calculateStudent({
    required Map<String, dynamic> currentStudent,
    required Map<String, int> targets,
    Map<String, dynamic>? inventory,
  }) async {
    // Deterministic mixed-growth sample, not a second implementation of costs.
    final owned = <String, int?>{};
    for (final raw in (inventory?['entries'] as List? ?? const [])) {
      final entry = Map<String, dynamic>.from(raw as Map);
      final quantity = entry['quantity'];
      owned[(entry['item_id'] ?? entry['key']) as String] =
          quantity == null ? null : int.parse(quantity as String);
    }
    return StudentCalculationResult.fromWire({
      ...mockStudentCalculationWire,
      'resources': [
        for (final raw in mockStudentCalculationWire['resources'] as List)
          (() {
            final row = Map<String, dynamic>.from(raw as Map);
            final holding = owned[row['resource_key']];
            final requiredAmount = row['required'] as int;
            return {
              ...row,
              'owned': holding,
              'shortage': holding == null
                  ? null
                  : (requiredAmount > holding ? requiredAmount - holding : 0),
            };
          })(),
      ],
    });
  }

  @override
  Future<StudentCalculationResult> calculateStudentWithBond({
    required Map<String, dynamic> currentStudent,
    required Map<String, int> targets,
    required StudentBondRequest bond,
    Map<String, dynamic>? inventory,
  }) async {
    bond.toWire();
    Map<String, dynamic> holdings(Map<String, dynamic>? snapshot) => {
      for (final raw in snapshot?['entries'] as List? ?? const [])
        (raw['item_id'] ?? raw['key']) as String: raw['quantity'],
    };
    final matching = mockStudentBondCases.where((entry) =>
      entry['student_id'] == currentStudent['student_id'] &&
      entry['current_rank'] == bond.currentRank && entry['target_rank'] == targets['bond_rank'] &&
      mapEquals(holdings(inventory), holdings(Map<String, dynamic>.from(entry['inventory'] as Map))));
    if (matching.isEmpty) {
      throw UnsupportedError('Mock bond calculation supports shared fixture inputs only');
    }
    final growth = await calculateStudent(currentStudent: currentStudent, targets: targets, inventory: inventory);
    return StudentCalculationResult.fromWire({
      'totals': {'credits': growth.credits},
      'credit_breakdown': growth.creditBreakdown,
      'resources': [for (final row in growth.resources) row.toWire()],
      'warnings': growth.warnings,
      'bond': matching.first['bond'],
    });
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
    Map<String, Map<String, int?>> finalTargets(PlanningDocument document) => {
      for (final stage in document.stages) stage.studentId: stage.nullableTargets,
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

  BackendRemoteException _scenarioError(
    String code, [
    Map<String, dynamic> details = const {},
  ]) => BackendRemoteException(code: code, message: code, details: details);

  int _scenarioIndex(
    List<PlanningScenarioRecord> scenarios,
    String id,
    int? expected,
  ) {
    final index = scenarios.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw _scenarioError('scenario_not_found', {'scenario_id': id});
    }
    if (expected != null && scenarios[index].revision != expected) {
      throw _scenarioError('revision_conflict', {
        'current_scenario_revision': scenarios[index].revision,
      });
    }
    return index;
  }

  PlanningScenarioMutationResult _mutateScenario(
    String profileId,
    int expectedRevision,
    String key,
    Map<String, dynamic> operation,
    String Function(List<PlanningScenarioRecord>) mutation,
  ) {
    _profileRevision(profileId);
    _ensureMockRepositoryPlan(profileId);
    final fingerprint = mockPlanFingerprint({
      'operation': operation,
      'expected_revision': expectedRevision,
    });
    final cached = _scenarioIdempotency[profileId]?[key];
    if (cached != null) {
      if (cached.fingerprint != fingerprint) {
        throw _scenarioError('idempotency_conflict');
      }
      return cached.response;
    }
    final actual = _scenarioCollectionRevision(profileId);
    if (actual != expectedRevision) {
      throw _scenarioError('revision_conflict', {'current_revision': actual});
    }
    final scenarios = <PlanningScenarioRecord>[
      ...?_planningScenarios[profileId],
    ];
    final id = mutation(scenarios);
    final response = PlanningScenarioMutationResult(
      revision: actual + 1,
      scenarioId: id,
    );
    _planningScenarios[profileId] = scenarios;
    _planningScenarioRevisions[profileId] = response.revision;
    (_scenarioIdempotency[profileId] ??= {})[key] = (
      fingerprint: fingerprint,
      response: response,
    );
    return response;
  }

  String _newScenarioId(List<PlanningScenarioRecord> scenarios) {
    String id;
    do {
      id = (_nextPlanningScenarioId++).toRadixString(16).padLeft(24, '0');
    } while (scenarios.any((item) => item.id == id));
    return id;
  }

  Map<String, dynamic> _scenarioOperation(
    String type,
    Map<String, dynamic> request,
  ) => {
    'type': type,
    for (final entry in request.entries)
      if (!{
        'profile_id',
        'expected_revision',
        'idempotency_key',
      }.contains(entry.key))
        entry.key: entry.value,
  };

  @override
  Future<PlanningScenarioListResult> listScenarios(String profileId) async {
    _ensureMockRepositoryPlan(profileId);
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
    _ensureMockRepositoryPlan(profileId);
    final scenarios =
        _planningScenarios[profileId] ?? const <PlanningScenarioRecord>[];
    return PlanningScenarioGetResult(
      profileId: profileId,
      revision: _scenarioCollectionRevision(profileId),
      currentProfileRevision: _profileRevision(profileId),
      scenario: scenarios[_scenarioIndex(scenarios, scenarioId, null)],
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
    PlanningAuthoring? authoring,
  }) async {
    final wire = PlanningScenarioCreateRequest(
      profileId: profileId,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
      name: name,
      description: description,
      baseProfileRevision: baseProfileRevision,
      document: document,
      authoring: authoring,
    ).toWire();
    return _mutateScenario(
      profileId,
      expectedRevision,
      idempotencyKey,
      _scenarioOperation('create', wire),
      (scenarios) {
        if (baseProfileRevision > _profileRevision(profileId)) {
          throw _scenarioError('invalid_payload');
        }
        final now = DateTime.now().toUtc().toIso8601String();
        final id = _newScenarioId(scenarios);
        scenarios.add(
          PlanningScenarioRecord.fromWire({
            'version': 1,
            'scenario_id': id,
            'revision': 0,
            'profile_id': profileId,
            'name': wire['name'],
            'description': wire['description'],
            'base_profile_revision': baseProfileRevision,
            'document': wire['document'],
            if (wire.containsKey('authoring')) 'authoring': wire['authoring'],
            'created_at': now,
            'updated_at': now,
          }),
        );
        return id;
      },
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
    PlanningAuthoring? authoring,
  }) async {
    final wire = PlanningScenarioUpdateRequest(
      profileId: profileId,
      scenarioId: scenarioId,
      expectedRevision: expectedRevision,
      expectedScenarioRevision: expectedScenarioRevision,
      idempotencyKey: idempotencyKey,
      name: name,
      description: description,
      baseProfileRevision: baseProfileRevision,
      document: document,
      authoring: authoring,
    ).toWire();
    return _mutateScenario(
      profileId,
      expectedRevision,
      idempotencyKey,
      _scenarioOperation('update', wire),
      (scenarios) {
        final index = _scenarioIndex(
          scenarios,
          scenarioId,
          expectedScenarioRevision,
        );
        final previous = scenarios[index];
        if (baseProfileRevision > _profileRevision(profileId)) {
          throw _scenarioError('invalid_payload');
        }
        PlanningAuthoring? next = authoring;
        if (next == null && previous.storedAuthoring != null) {
          try {
            next = PlanningAuthoring.fromWire(
              previous.authoring.toWire(),
              document,
            );
          } on PlanningAuthoringFormatException catch (error) {
            throw _scenarioError('invalid_payload', {
              'reason': 'authoring_required',
              'authoring_reason': error.reason,
            });
          }
        }
        scenarios[index] = PlanningScenarioRecord.fromWire({
          ...previous.toWire(),
          'revision': previous.revision + 1,
          'name': wire['name'],
          'description': wire['description'],
          'base_profile_revision': baseProfileRevision,
          'document': wire['document'],
          if (next != null) 'authoring': next.toWire(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        return scenarioId;
      },
    );
  }

  Future<PlanningScenarioMutationResult> _mutateScenarioIdentity(
    String type, {
    required String profileId,
    required String scenarioId,
    required int expectedRevision,
    required int expectedScenarioRevision,
    required String idempotencyKey,
  }) async {
    final wire = PlanningScenarioIdentityRequest(
      profileId: profileId,
      scenarioId: scenarioId,
      expectedRevision: expectedRevision,
      expectedScenarioRevision: expectedScenarioRevision,
      idempotencyKey: idempotencyKey,
    ).toWire();
    return _mutateScenario(
      profileId,
      expectedRevision,
      idempotencyKey,
      _scenarioOperation(type, wire),
      (scenarios) {
        final index = _scenarioIndex(
          scenarios,
          scenarioId,
          expectedScenarioRevision,
        );
        final source = scenarios[index];
        if (type == 'delete') {
          scenarios.removeAt(index);
          return scenarioId;
        }
        final existingNames = scenarios
            .map((item) => item.name.toLowerCase())
            .toSet();
        final baseName = '${source.name} (복사본)';
        var name = baseName;
        var suffix = 2;
        while (existingNames.contains(name.toLowerCase())) {
          name = '${source.name} (복사본 $suffix)';
          suffix++;
        }
        final id = _newScenarioId(scenarios);
        final now = DateTime.now().toUtc().toIso8601String();
        scenarios.add(
          PlanningScenarioRecord.fromWire({
            ...source.toWire(),
            'scenario_id': id,
            'revision': 0,
            'name': name,
            'document': {
              ...source.document.toWire(),
              'document_id': id,
              'name': name,
            },
            'created_at': now,
            'updated_at': now,
          }),
        );
        return id;
      },
    );
  }

  @override
  Future<PlanningScenarioMutationResult> deleteScenario({
    required String profileId,
    required String scenarioId,
    required int expectedRevision,
    required int expectedScenarioRevision,
    required String idempotencyKey,
  }) => _mutateScenarioIdentity(
    'delete',
    profileId: profileId,
    scenarioId: scenarioId,
    expectedRevision: expectedRevision,
    expectedScenarioRevision: expectedScenarioRevision,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<PlanningScenarioMutationResult> duplicateScenario({
    required String profileId,
    required String scenarioId,
    required int expectedRevision,
    required int expectedScenarioRevision,
    required String idempotencyKey,
  }) => _mutateScenarioIdentity(
    'duplicate',
    profileId: profileId,
    scenarioId: scenarioId,
    expectedRevision: expectedRevision,
    expectedScenarioRevision: expectedScenarioRevision,
    idempotencyKey: idempotencyKey,
  );

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
    _currentHistories[profile.id] = RepositoryCurrentHistory.empty();
    _repositoryPlans[profile.id] = mockDocumentFromGoals({'version': 1, 'goals': <dynamic>[]});
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
    _ensureMockRepositoryPlan(profileId);
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
    _syncMockRepositoryStateRevision(profileId, expectedRevision + 1);
    return expectedRevision + 1;
  }

  @override
  Future<int> renameProfile(
    String profileId,
    String displayName,
    int expectedRevision,
    String idempotencyKey,
  ) async {
    _ensureMockRepositoryPlan(profileId);
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
    _syncMockRepositoryStateRevision(profileId, expectedRevision + 1);
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
    _ensureMockRepositoryPlan(profileId);
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
    _syncMockRepositoryStateRevision(profileId, expectedRevision + 1);
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
    _currentHistories.remove(profileId);
    _repositoryPlans.remove(profileId);
    _repositoryPlanAuthoring.remove(profileId);
    _planIdempotency.remove(profileId);
    _repositoryPresets.remove(profileId);
    _presetIdempotency.remove(profileId);
    _planningScenarios.remove(profileId);
    _planningScenarioRevisions.remove(profileId);
    _scenarioIdempotency.remove(profileId);
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
      RepositoryState.fromWire(_ensureMockRepositoryPlan(profileId));

  @override
  Future<RepositoryHistorySummaryResult> loadRepositoryHistorySummary(
    List<String> profileIds,
  ) async {
    final request = RepositoryHistorySummaryRequest(profileIds);
    return RepositoryHistorySummaryResult.fromWire({'profiles': [
      for (final id in request.profileIds) _mockHistorySummary(id).toWire(),
    ]});
  }

  RepositoryHistorySummary _mockHistorySummary(String profileId) {
    if (!_profiles.any((item) => item.id == profileId)) {
      throw StateError('profile_not_found');
    }
    final state = _mockRepositoryState(profileId);
    return _currentHistories[profileId]?.summarize(profileId, state['revision'] as int)
        ?? RepositoryHistorySummary.unrecorded(profileId, state['revision'] as int);
  }

  @override
  Future<RepositoryHistoryEventsResult> loadRepositoryHistoryEvents(
    RepositoryHistoryEventsRequest request,
  ) async {
    _mockHistorySummary(request.profileId);
    return repositoryHistoryEvents(RepositoryState.fromWire(_mockRepositoryState(request.profileId)),
      _currentHistories[request.profileId],request);
  }

  @override
  Future<RepositoryHistoryDiffResult> loadRepositoryHistoryDiff(
    RepositoryHistoryDiffRequest request,
  ) async {
    _mockHistorySummary(request.profileId);
    return repositoryHistoryDiff(RepositoryState.fromWire(_mockRepositoryState(request.profileId)),
      _currentHistories[request.profileId],request);
  }

  /// FB-2b read-only query: authoritative profile revision + current history only.
  /// No plan migration, observer, clock, cache or map writes; results are detached.
  @override
  Future<RepositoryHistoryScanLatestResult> loadRepositoryHistoryScanLatest(
    RepositoryHistoryScanLatestRequest request,
  ) async {
    if (!_profiles.any((item) => item.id == request.profileId)) {
      throw StateError('profile_not_found');
    }
    try {
      return repositoryHistoryScanLatest(
        request.profileId,
        _mockRepositoryState(request.profileId)['revision'] as int,
        _currentHistories[request.profileId],
        request,
      );
    } on RepositoryHistoryScanLatestError catch (error) {
      throw BackendRemoteException(
        code: error.code,
        message: error.message,
        details: {'reason': error.reason},
      );
    }
  }

  void _observeMockCurrentWrite(String profileId, Map<String, dynamic>? stored,
    Map<String, dynamic> next) {
    if (!_trackMockCurrentWrites || _manualMockCurrentWrite) return;
    if (_scannerMockCurrentWrite) return;
    final current = stored ?? _mockRepositoryState(profileId);
    final studentsChanged = !identical(current['students'],next['students']);
    final inventoryChanged = !identical(current['inventory'],next['inventory']);
    if (!studentsChanged && !inventoryChanged) return;
    final before = RepositoryState.fromWire(current);
    final after = RepositoryState.fromWire(next);
    if (after.revision != before.revision+1) throw StateError('Invalid current write revision');
    final history = _currentHistories[profileId] ?? RepositoryCurrentHistory.empty(legacy: before);
    _currentHistories[profileId] = history.appendManual(before,after,
      studentsChanged && inventoryChanged ? 'current' : studentsChanged ? 'students' : 'inventory',
      _historyClock(), source:'unattributed');
  }

  Map<String, dynamic> _mockRepositoryState(String profileId) =>
      _repositoryStates[profileId] ??
      {
        'profile_id': profileId,
        'revision':
            _profiles
                .where((profile) => profile.id == profileId)
                .firstOrNull
                ?.revision ??
            0,
        'students': <dynamic>[],
        'inventory': {'version': 1, 'entries': <dynamic>[]},
        'goals': {'version': 1, 'goals': <dynamic>[]},
      };

  void _syncMockPlanRevision(String profileId, int revision) {
    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    if (index < 0) {
      throw StateError('profile_not_found');
    }
    final old = _profiles[index];
    _profiles[index] = RepositoryProfile(
      id: old.id,
      displayName: old.displayName,
      avatarStudentId: old.avatarStudentId,
      revision: revision,
      selected: old.selected,
    );
  }

  void _syncMockRepositoryStateRevision(String profileId, int revision) {
    final state = _repositoryStates[profileId];
    if (state != null) {
      _repositoryStates[profileId] = {...state, 'revision': revision};
    }
  }

  Map<String, dynamic> _ensureMockRepositoryPlan(String profileId) {
    final state = _mockRepositoryState(profileId);
    if (!_repositoryPlans.containsKey(profileId)) {
      final document = mockDocumentFromGoals(
        Map<String, dynamic>.from(state['goals'] as Map),
      );
      if (!_repositoryStates.containsKey(profileId)) {
        _repositoryPlans[profileId] = document;
        return state;
      }
      final revision = (state['revision'] as int) + 1;
      final migrated = {
        ...state,
        'revision': revision,
        'goals': mockGoalsFromDocument(document),
      };
      _repositoryPlans[profileId] = document;
      _repositoryStates[profileId] = migrated;
      _syncMockPlanRevision(profileId, revision);
      return migrated;
    }
    return state;
  }

  @override
  Future<RepositoryPresetsState> loadRepositoryPresets(
    String profileId,
  ) async => _mockPresetsState(profileId);

  RepositoryPresetsState _mockPresetsState(String profileId) {
    if (!RegExp(r'^[0-9a-f]{24}$').hasMatch(profileId)) {
      throw BackendRemoteException(
        code: 'invalid_payload',
        message: 'Invalid profile ID',
      );
    }
    if (!_profiles.any((profile) => profile.id == profileId)) {
      throw BackendRemoteException(
        code: 'profile_not_found',
        message: 'Profile does not exist',
      );
    }
    return _repositoryPresets[profileId] ??
        RepositoryPresetsState.fromWire({
          'profile_id': profileId,
          'revision': 0,
          'stage_presets': <dynamic>[],
          'student_groups': <dynamic>[],
        });
  }

  @override
  Future<int> saveRepositoryPresets(
    RepositoryPresetsSaveRequest request,
  ) async {
    final wire = request.toWire();
    final state = _mockPresetsState(request.profileId);
    final fingerprint = jsonEncode({
      'expected_revision': request.expectedRevision,
      'stage_presets': wire['stage_presets'],
      'student_groups': wire['student_groups'],
    });
    final cache = _presetIdempotency.putIfAbsent(request.profileId, () => {});
    final cached = cache[request.idempotencyKey];
    if (cached != null) {
      if (cached.fingerprint != fingerprint) {
        throw BackendRemoteException(
          code: 'idempotency_conflict',
          message: 'Key belongs to another preset save',
        );
      }
      return cached.revision;
    }
    if (state.revision != request.expectedRevision) {
      throw BackendRemoteException(
        code: 'revision_conflict',
        message: 'Expected preset revision is stale',
        details: {'current_revision': state.revision},
      );
    }
    final revision = state.revision + 1;
    _repositoryPresets[request.profileId] = RepositoryPresetsState.fromWire({
      'profile_id': request.profileId,
      'revision': revision,
      'stage_presets': wire['stage_presets'],
      'student_groups': wire['student_groups'],
    });
    cache[request.idempotencyKey] = (
      fingerprint: fingerprint,
      revision: revision,
    );
    return revision;
  }

  @override
  Future<RepositoryPlanState> loadRepositoryPlan(String profileId) async {
    if (!_profiles.any((profile) => profile.id == profileId)) {
      throw StateError('profile_not_found');
    }
    final state = _ensureMockRepositoryPlan(profileId);
    final document = _repositoryPlans[profileId]!;
    Map<String, dynamic>? calculation;
    try {
      final projection = await calculatePlanningDocument(
        currentStudents: [
          for (final raw in state['students'] as List)
            {
              'student_id': raw['student_id'],
              ...Map<String, dynamic>.from(raw['values'] as Map),
            },
        ],
        inventory: Map<String, dynamic>.from(state['inventory'] as Map),
        document: document.toWire(),
      );
      // Reuse the existing empty mock projection; production calculation is Python.
      calculation = {
        'credits': (projection['overall'] as Map)['cost']['credits'] ?? 0,
        'required_resource_type_count': 0,
        'known_shortage_type_count': 0,
        'inventory_complete': true,
        'first_bottleneck_phase_number': null,
        'representative_shortage': null,
      };
    } catch (_) {
      calculation = null;
    }
    return RepositoryPlanState.fromWire({
      'profile_id': profileId,
      'revision': state['revision'],
      'document': document.toWire(),
      'calculation': calculation,
      if (_repositoryPlanAuthoring.containsKey(profileId))
        'authoring': _repositoryPlanAuthoring[profileId]!.toWire(),
    });
  }

  int _saveMockRepositoryPlan(
    String profileId,
    PlanningDocument document,
    int expectedRevision,
    String idempotencyKey,
    String operation, {
    bool legacy = false,
    PlanningAuthoring? authoring,
  }) {
    final request = RepositoryPlanSaveRequest(
      profileId: profileId,
      document: document,
      authoring: authoring,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
    ).toWire();
    if (!_profiles.any((profile) => profile.id == profileId)) {
      throw StateError('profile_not_found');
    }
    final state = _ensureMockRepositoryPlan(profileId);
    final fingerprint = mockPlanFingerprint({
      'operation': operation,
      'expected_revision': expectedRevision,
      'value': legacy ? mockGoalsFromDocument(document) : request['document'],
      if (request.containsKey('authoring')) 'authoring': request['authoring'],
    });
    final cache = _planIdempotency.putIfAbsent(profileId, () => {});
    final cached = cache[idempotencyKey];
    if (cached != null) {
      if (cached.fingerprint != fingerprint) {
        throw StateError('idempotency_conflict');
      }
      return cached.response['revision'] as int;
    }
    if (state['revision'] != expectedRevision) {
      throw StateError('revision_conflict');
    }
    final previousAuthoring = _repositoryPlanAuthoring[profileId];
    if (legacy &&
        (mockLegacyWriteLosesPlan(_repositoryPlans[profileId]!) ||
            (previousAuthoring != null &&
                !previousAuthoring.isDefaultForDocument(
                  _repositoryPlans[profileId]!,
                )))) {
      throw StateError('plan_lossy_write');
    }
    PlanningAuthoring? nextAuthoring;
    if (authoring != null) {
      nextAuthoring = PlanningAuthoring.fromWire(
        request['authoring'],
        document,
      );
    } else if (previousAuthoring != null) {
      if (legacy) {
        nextAuthoring = PlanningAuthoring.defaultForDocument(document);
      } else {
        try {
          nextAuthoring = PlanningAuthoring.fromWire(
            previousAuthoring.toWire(),
            document,
          );
        } on PlanningAuthoringFormatException catch (error) {
          throw BackendRemoteException(
            code: 'invalid_payload',
            message: error.message.toString(),
            details: {
              'reason': 'authoring_required',
              'authoring_reason': error.reason,
            },
          );
        }
      }
    }
    final revision = expectedRevision + 1;
    _repositoryStates[profileId] = {
      ...state,
      'revision': revision,
      'goals': mockGoalsFromDocument(document),
    };
    _repositoryPlans[profileId] = repositoryActiveDocument(document.toWire());
    if (nextAuthoring != null) {
      _repositoryPlanAuthoring[profileId] = nextAuthoring;
    }
    _syncMockPlanRevision(profileId, revision);
    cache[idempotencyKey] = (
      fingerprint: fingerprint,
      response: Map.unmodifiable({'revision': revision}),
    );
    return revision;
  }

  @override
  Future<int> saveRepositoryPlan({
    required String profileId,
    required PlanningDocument document,
    PlanningAuthoring? authoring,
    required int expectedRevision,
    required String idempotencyKey,
  }) async => _saveMockRepositoryPlan(
    profileId,
    document,
    expectedRevision,
    idempotencyKey,
    'plan',
    authoring: authoring,
  );

  @override
  Future<RepositoryPlanReplaceResult> replaceRepositoryPlan({
    required String profileId,
    required PlanningDocument document,
    PlanningAuthoring? authoring,
    required int expectedRevision,
    required int expectedScenarioRevision,
    required String idempotencyKey,
    required String archiveName,
    required String archiveDescription,
  }) async {
    final wire = RepositoryPlanReplaceRequest(
      profileId: profileId,
      document: document,
      authoring: authoring,
      expectedRevision: expectedRevision,
      expectedScenarioRevision: expectedScenarioRevision,
      idempotencyKey: idempotencyKey,
      archiveName: archiveName,
      archiveDescription: archiveDescription,
    ).toWire();
    if (!_profiles.any((profile) => profile.id == profileId)) {
      throw BackendRemoteException(
        code: 'profile_not_found',
        message: 'Profile does not exist',
      );
    }
    final state = _ensureMockRepositoryPlan(profileId);
    final fingerprint = mockPlanFingerprint({'operation': 'replace', ...wire});
    final cache = _planIdempotency.putIfAbsent(profileId, () => {});
    final cached = cache[idempotencyKey];
    if (cached != null) {
      if (cached.fingerprint != fingerprint) {
        throw BackendRemoteException(
          code: 'idempotency_conflict',
          message: 'Key belongs to another mutation',
        );
      }
      return RepositoryPlanReplaceResult.fromWire(cached.response);
    }
    final currentRevision = state['revision'] as int;
    final collectionRevision = _scenarioCollectionRevision(profileId);
    final profileStale = currentRevision != expectedRevision;
    final scenarioStale = collectionRevision != expectedScenarioRevision;
    if (profileStale || scenarioStale) {
      throw BackendRemoteException(
        code: 'revision_conflict',
        message: 'Plan replacement revisions are stale',
        details: {
          'revision_scope': profileStale && scenarioStale
              ? 'both'
              : profileStale
              ? 'profile'
              : 'scenario',
          'current_revision': currentRevision,
          'current_scenario_revision': collectionRevision,
        },
      );
    }
    final previous = _repositoryPlans[profileId]!;
    final goals = mockGoalsFromDocument(document);
    final scenarios = <PlanningScenarioRecord>[
      ...?_planningScenarios[profileId],
    ];
    String? archivedId;
    var scenarioRevision = collectionRevision;
    final previousAuthoring = _repositoryPlanAuthoring[profileId];
    if (previous.phases.isNotEmpty ||
        (previousAuthoring?.hasContent ?? false)) {
      do {
        archivedId = (_nextPlanningScenarioId++)
            .toRadixString(16)
            .padLeft(24, '0');
      } while (scenarios.any((scenario) => scenario.id == archivedId));
      final now = DateTime.now().toUtc().toIso8601String();
      scenarios.add(
        PlanningScenarioRecord(
          id: archivedId,
          revision: 0,
          profileId: profileId,
          name: wire['archive_name'] as String,
          description: wire['archive_description'] as String,
          baseProfileRevision: currentRevision,
          document: PlanningDocument.fromWire({
            ...previous.toWire(),
            'kind': 'scenario',
            'document_id': archivedId,
          }),
          storedAuthoring: previousAuthoring,
          createdAt: now,
          updatedAt: now,
        ),
      );
      scenarioRevision++;
    }
    final response = RepositoryPlanReplaceResult.fromWire({
      'revision': currentRevision + 1,
      'scenario_revision': scenarioRevision,
      'archived_scenario_id': archivedId,
    });
    // All validation and record construction precede this synchronous commit.
    _repositoryPlans[profileId] = document;
    if (authoring != null) {
      _repositoryPlanAuthoring[profileId] = PlanningAuthoring.fromWire(
        wire['authoring'],
        document,
      );
    } else {
      _repositoryPlanAuthoring.remove(profileId);
    }
    _repositoryStates[profileId] = {
      ...state,
      'revision': response.revision,
      'goals': goals,
    };
    _syncMockPlanRevision(profileId, response.revision);
    if (archivedId != null) {
      _planningScenarios[profileId] = scenarios;
      _planningScenarioRevisions[profileId] = scenarioRevision;
    }
    cache[idempotencyKey] = (
      fingerprint: fingerprint,
      response: Map.unmodifiable(response.toWire()),
    );
    return response;
  }

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
    return _saveMockRepositoryPlan(profileId, mockDocumentFromGoals(goals),
      expectedRevision, idempotencyKey, 'goals', legacy: true);
  }

  @override
  Future<int> saveRepositoryStudents(
    String profileId,
    List<ConfirmedStudentState> students,
    int expectedRevision,
    String idempotencyKey,
  ) async {
    return _saveMockCurrent(profileId, 'students',
      students.map((item) => item.toWire()).toList(), expectedRevision, idempotencyKey);
  }

  @override
  Future<int> saveRepositoryInventory(
    String profileId,
    RepositoryInventoryState inventory,
    int expectedRevision,
    String idempotencyKey,
  ) async {
    return _saveMockCurrent(profileId, 'inventory', inventory.toWire(), expectedRevision, idempotencyKey);
  }

  int _saveMockCurrent(String profileId, String bucket, Object value,
    int expectedRevision, String idempotencyKey) {
    if (!_profiles.any((item) => item.id == profileId)) throw StateError('profile_not_found');
    if (expectedRevision < 0 || idempotencyKey.isEmpty) throw const FormatException('invalid_payload');
    final current = _ensureMockRepositoryPlan(profileId);
    final next = <String, dynamic>{...current, 'revision': expectedRevision + 1, bucket: value};
    final after = RepositoryState.fromWire(next);
    final fingerprint = historyCanonicalJson({'operation': '$bucket:${historyCanonicalJson(value)}', 'expected_revision': expectedRevision});
    final cache = _planIdempotency.putIfAbsent(profileId, () => {});
    final cached = cache[idempotencyKey];
    if (cached != null) {
      if (cached.fingerprint != fingerprint) throw StateError('idempotency_conflict');
      return cached.response['revision'] as int;
    }
    if (current['revision'] != expectedRevision) throw StateError('revision_conflict');
    final before = RepositoryState.fromWire(current);
    // FB-3(02:09): 수동 저장은 재화(credits·엘리그마)의 존재·수량을 바꿀 수 없다. 캐시 재생·revision 확인 뒤,
    // history 시각·쓰기·캐시 앞에서 거부한다. 스캐너 commit 경로는 이 함수를 지나지 않는다. 백엔드는
    // unattributed 쓰기도 막지만, Mock의 unattributed 기록(`_observeMockCurrentWrite`)은 스캐너 소유 commit
    // 경로라 00:02 목록대로 손대지 않는다.
    if (bucket == 'inventory') _rejectMockCurrencyChange(before, after);
    final history = _currentHistories[profileId] ?? RepositoryCurrentHistory.empty(legacy: before);
    final updated = history.appendManual(before, after, bucket, _historyClock());
    _manualMockCurrentWrite = true;
    try {
      _repositoryStates[profileId] = next;
    } finally {
      _manualMockCurrentWrite = false;
    }
    _currentHistories[profileId] = updated;
    _syncMockPlanRevision(profileId, expectedRevision + 1);
    cache[idempotencyKey] = (fingerprint: fingerprint, response: Map.unmodifiable({'revision': expectedRevision + 1}));
    return expectedRevision + 1;
  }

  /// 백엔드 `_assert_currency_quantities_unchanged`: 정규 키 projection의 재화 {키: 수량}을 비교한다
  /// (없음·null·'0'이 모두 다르다).
  void _rejectMockCurrencyChange(RepositoryState before, RepositoryState after) {
    Map<String, Object?> currencies(RepositoryState state) {
      final result = <String, Object?>{};
      for (final entry in state.inventory.entries) {
        final key = historyCanonicalResourceKey(
          (entry['item_id'] ?? entry['key']) as String,
        );
        if (inventoryReadOnlyCurrencyKeys.contains(key)) {
          result[key] = entry['quantity'];
        }
      }
      return result;
    }

    if (!mapEquals(currencies(before), currencies(after))) {
      throw BackendRemoteException(
        code: 'invalid_payload',
        message:
            'Currency quantities can only be changed by a validated internal scan.',
        details: {'reason': 'currency_read_only'},
      );
    }
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

class _MockFrozenScanCommit {
  _MockFrozenScanCommit({
    required this.bucket,
    required this.currentJson,
    required this.scanKind,
    required this.inventoryScanProfile,
    required this.context,
    required this.appliedKeys,
    required this.provenance,
  });
  final String bucket;
  final String currentJson;
  final String scanKind;
  final String? inventoryScanProfile;
  final Map<String, dynamic> context;
  final List<String> appliedKeys;
  final String provenance;
}

class _MockScanCommitReceipt {
  _MockScanCommitReceipt(this.publicRequest, this.frozen);
  final String publicRequest;
  _MockFrozenScanCommit? frozen;
  Map<String, dynamic>? response;
}
