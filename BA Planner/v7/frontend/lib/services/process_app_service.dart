import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_service.dart';
import 'backend_process.dart';
import 'diagnostics_service.dart';
import 'planning_protocol_client.dart';
import 'repository_service.dart';
import 'scanner_service.dart';
import 'tactical_service.dart';
import 'tactical_v2_service.dart';

class ProcessAppService
    with WidgetsBindingObserver
    implements
        AppService,
        RepositoryService,
        ScannerService,
        TacticalService,
        TacticalEvidenceService,
        DiagnosticsService {
  ProcessAppService(this._client)
    : _state = ValueNotifier(
        const AppServiceState(
          connection: BackendConnection.disconnected,
          scanPhase: ScanPhase.idle,
          imageLoadState: ImageLoadState.loaded,
          studentCount: 0,
          inventoryItemCount: 0,
          hasData: false,
          scanAvailable: false,
          useLongNames: false,
          hasMissingMetadata: false,
        ),
      ) {
    _scanner = ScannerProtocolClient(_client);
    _scannerSubscription = _scanner.scannerEvents.listen(_handleScannerEvent);
    _client.connection.addListener(_syncConnection);
    WidgetsBinding.instance.addObserver(this);
  }

  factory ProcessAppService.fromConfig(BackendProcessConfig config) {
    return ProcessAppService(
      PlanningProtocolClient(
        () => startBackendProcess(config),
        launchInfo: BackendLaunchInfo(
          configured: true,
          resolved: true,
          executable: config.executable,
          arguments: List.unmodifiable(config.arguments),
          workingDirectory: config.workingDirectory,
        ),
      ),
    );
  }

  /// Resolves the development launcher only when a connection is attempted.
  ///
  /// Keeping resolution inside the starter lets the Flutter shell render a
  /// disconnected state even when a configured backend directory is missing.
  factory ProcessAppService.fromLaunchOptions({
    String pythonExecutable = '',
    String backendDirectory = '',
  }) {
    late PlanningProtocolClient client;
    client = PlanningProtocolClient(
      () {
        final config = BackendProcessConfig.resolve(
          pythonExecutable: pythonExecutable,
          backendDirectory: backendDirectory,
        );
        client.updateLaunchInfo(
          BackendLaunchInfo(
            configured:
                pythonExecutable.isNotEmpty || backendDirectory.isNotEmpty,
            resolved: true,
            executable: config.executable,
            arguments: List.unmodifiable(config.arguments),
            workingDirectory: config.workingDirectory,
          ),
        );
        return startBackendProcess(config);
      },
      launchInfo: BackendLaunchInfo.unresolved(
        configured: pythonExecutable.isNotEmpty || backendDirectory.isNotEmpty,
        executable: pythonExecutable.isEmpty
            ? 'default Python launcher'
            : pythonExecutable,
        workingDirectory: backendDirectory.isEmpty
            ? 'auto-detect on connect'
            : backendDirectory,
      ),
    );
    return ProcessAppService(client);
  }

  final PlanningProtocolClient _client;
  late final ScannerProtocolClient _scanner;
  late final StreamSubscription<ScannerEvent> _scannerSubscription;
  final ValueNotifier<AppServiceState> _state;
  bool _disposed = false;
  Future<void>? _reconnectFlight;
  Future<void>? _restartFlight;

  @override
  ValueListenable<AppServiceState> get state => _state;

  @override
  Future<Map<String, dynamic>?> getStudent(String studentId) async {
    final payload = await _client.send('planning.student.get', {
      'student_id': studentId,
    });
    final student = payload['student'];
    return student == null ? null : Map<String, dynamic>.from(student as Map);
  }

  @override
  Future<List<StudentCatalogEntry>> listStudents() async {
    final payload = await _client.send('planning.student.catalog', {});
    final students = payload['students'];
    if (students is! List) {
      throw const FormatException('Invalid student catalog');
    }
    return students
        .map(
          (item) => StudentCatalogEntry.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<InventoryCatalogEntry>> listInventoryItems() async {
    final payload = await _client.send('planning.inventory.catalog', {});
    return (payload['items'] as List)
        .map(
          (item) => InventoryCatalogEntry.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) async => InventoryShortageResult.fromWire(
    await _client.send('planning.plan.shortages', {
      'current_students': currentStudents,
      'plan': plan,
      'inventory': inventory,
    }),
  );

  @override
  Future<Map<String, dynamic>> validatePlan(Map<String, dynamic> plan) async {
    final payload = await _client.send('planning.plan.validate', {
      'plan': plan,
    });
    return Map<String, dynamic>.from(payload['plan'] as Map);
  }

  @override
  Future<Map<String, dynamic>> calculatePlan({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
  }) async {
    final payload = await _client.send('planning.plan.calculate', {
      'current_students': currentStudents,
      'plan': plan,
    });
    return Map<String, dynamic>.from(payload['totals'] as Map);
  }

  @override
  Future<List<RepositoryProfile>> listProfiles() async {
    final payload = await _client.send('repository.profile.list', {});
    final values = payload['profiles'];
    if (values is! List) throw const FormatException('Invalid profile list');
    return values
        .map(
          (item) => RepositoryProfile.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  @override
  Future<RepositoryProfile> createProfile(
    String displayName,
    String idempotencyKey, {
    String avatarStudentId = 'hasumi',
  }) async {
    final payload = await _client.send('repository.profile.create', {
      'display_name': displayName,
      'idempotency_key': idempotencyKey,
      'avatar_student_id': avatarStudentId,
    });
    return RepositoryProfile.fromWire(
      Map<String, dynamic>.from(payload['profile'] as Map),
    );
  }

  Future<int> _revisionMutation(
    String method,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.send(method, payload);
    final revision = response['revision'];
    if (revision is! int) {
      throw const FormatException('Invalid repository revision');
    }
    return revision;
  }

  @override
  Future<int> selectProfile(
    String profileId,
    int expectedRevision,
    String idempotencyKey,
  ) => _revisionMutation('repository.profile.select', {
    'profile_id': profileId,
    'expected_revision': expectedRevision,
    'idempotency_key': idempotencyKey,
  });

  @override
  Future<int> renameProfile(
    String profileId,
    String displayName,
    int expectedRevision,
    String idempotencyKey,
  ) => _revisionMutation('repository.profile.rename', {
    'profile_id': profileId,
    'display_name': displayName,
    'expected_revision': expectedRevision,
    'idempotency_key': idempotencyKey,
  });

  @override
  Future<int> updateProfile(
    String profileId,
    String displayName,
    String avatarStudentId,
    int expectedRevision,
    String idempotencyKey,
  ) => _revisionMutation('repository.profile.update', {
    'profile_id': profileId,
    'display_name': displayName,
    'avatar_student_id': avatarStudentId,
    'expected_revision': expectedRevision,
    'idempotency_key': idempotencyKey,
  });

  @override
  Future<int> deleteProfile(
    String profileId,
    int expectedRevision,
    String idempotencyKey,
  ) => _revisionMutation('repository.profile.delete', {
    'profile_id': profileId,
    'expected_revision': expectedRevision,
    'idempotency_key': idempotencyKey,
  });

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async =>
      RepositoryState.fromWire(
        await _client.send('repository.state.get', {'profile_id': profileId}),
      );

  @override
  Future<int> saveRepositoryGoals(
    String profileId,
    Map<String, dynamic> goals,
    int expectedRevision,
    String idempotencyKey,
  ) => _revisionMutation('repository.goals.save', {
    'profile_id': profileId,
    'goals': goals,
    'expected_revision': expectedRevision,
    'idempotency_key': idempotencyKey,
  });

  @override
  Future<int> saveRepositoryStudents(
    String profileId,
    List<ConfirmedStudentState> students,
    int expectedRevision,
    String idempotencyKey,
  ) => _revisionMutation('repository.students.update', {
    'profile_id': profileId,
    'students': students
        .map((student) => student.toWire())
        .toList(growable: false),
    'expected_revision': expectedRevision,
    'idempotency_key': idempotencyKey,
  });

  @override
  Future<int> saveRepositoryInventory(
    String profileId,
    RepositoryInventoryState inventory,
    int expectedRevision,
    String idempotencyKey,
  ) => _revisionMutation('repository.inventory.update', {
    'profile_id': profileId,
    'inventory': inventory.toWire(),
    'expected_revision': expectedRevision,
    'idempotency_key': idempotencyKey,
  });

  @override
  Future<TacticalState> loadTacticalState(String profileId) async =>
      TacticalState.fromWire(
        await _client.send('tactical.state.get', {'profile_id': profileId}),
      );
  @override
  Future<int> saveTacticalMatch(
    String profileId,
    TacticalMatch match,
    int expectedRevision,
    String idempotencyKey,
  ) => _revisionMutation('tactical.match.upsert', {
    'profile_id': profileId,
    'match': match.toWire(),
    'expected_revision': expectedRevision,
    'idempotency_key': idempotencyKey,
  });
  @override
  Future<int> deleteTacticalMatch(
    String profileId,
    String matchId,
    int expectedRevision,
    String idempotencyKey,
  ) => _revisionMutation('tactical.match.delete', {
    'profile_id': profileId,
    'match_id': matchId,
    'expected_revision': expectedRevision,
    'idempotency_key': idempotencyKey,
  });
  @override
  Future<int> saveTacticalJokbo(
    String profileId,
    TacticalJokbo jokbo,
    int expectedRevision,
    String idempotencyKey,
  ) => _revisionMutation('tactical.jokbo.upsert', {
    'profile_id': profileId,
    'jokbo': jokbo.toWire(),
    'expected_revision': expectedRevision,
    'idempotency_key': idempotencyKey,
  });
  @override
  Future<int> deleteTacticalJokbo(
    String profileId,
    String jokboId,
    int expectedRevision,
    String idempotencyKey,
  ) => _revisionMutation('tactical.jokbo.delete', {
    'profile_id': profileId,
    'jokbo_id': jokboId,
    'expected_revision': expectedRevision,
    'idempotency_key': idempotencyKey,
  });

  @override
  Future<TacticalEvidenceState> loadTacticalEvidenceState(
    String profileId,
  ) async => TacticalEvidenceState.fromWire(
    await _client.send('tactical.v2.state.get', {'profile_id': profileId}),
  );

  @override
  Future<TacticalImportPreview> previewTacticalV6Import(
    String profileId,
    String sourcePath,
    String importBatchId,
  ) async => TacticalImportPreview.fromWire(
    await _client.send('tactical.v2.import.preview', {
      'profile_id': profileId,
      'source_path': sourcePath,
      'import_batch_id': importBatchId,
    }),
  );

  @override
  Future<TacticalImportCommitResult> commitTacticalV6Import({
    required String profileId,
    required String sourcePath,
    required String importBatchId,
    required String expectedFingerprint,
    required List<String> acceptedIssueIds,
    required int expectedRevision,
    required String idempotencyKey,
  }) async => TacticalImportCommitResult.fromWire(
    await _client.send('tactical.v2.import.commit', {
      'profile_id': profileId,
      'source_path': sourcePath,
      'import_batch_id': importBatchId,
      'expected_fingerprint': expectedFingerprint,
      'accepted_issue_ids': acceptedIssueIds,
      'expected_revision': expectedRevision,
      'idempotency_key': idempotencyKey,
    }),
  );

  @override
  Future<TacticalLobbyCommitResult> commitTacticalLobby({
    required String profileId,
    required Map<String, dynamic> candidatePayload,
    required String season,
    required String map,
    required Map<int, String> identityBindings,
    required int expectedRevision,
    required String idempotencyKey,
  }) async => TacticalLobbyCommitResult.fromWire(
    await _client.send('tactical.v2.lobby.commit', {
      'profile_id': profileId,
      'candidate_payload': candidatePayload,
      'season': season,
      'map': map,
      'identity_bindings': identityBindings.entries
          .map(
            (entry) => {
              'display_index': entry.key,
              'opponent_identity_id': entry.value,
            },
          )
          .toList(growable: false),
      'expected_revision': expectedRevision,
      'idempotency_key': idempotencyKey,
    }),
  );

  @override
  Future<int> selectTacticalLobbyCandidate({
    required String profileId,
    required String candidateId,
    required String selectedAt,
    required int expectedRevision,
    required String idempotencyKey,
  }) async =>
      (await _client.send('tactical.v2.candidate.select', {
            'profile_id': profileId,
            'candidate_id': candidateId,
            'selected_at': selectedAt,
            'expected_revision': expectedRevision,
            'idempotency_key': idempotencyKey,
          }))['revision']
          as int;

  @override
  Future<TacticalLinkResult> linkTacticalMatch({
    required String profileId,
    required String matchId,
    required String? candidateId,
    required String mode,
    required int expectedRevision,
    required String idempotencyKey,
  }) async => TacticalLinkResult.fromWire(
    await _client.send('tactical.v2.match.link', {
      'profile_id': profileId,
      'match_id': matchId,
      'candidate_id': candidateId,
      'mode': mode,
      'expected_revision': expectedRevision,
      'idempotency_key': idempotencyKey,
    }),
  );

  @override
  Future<int> deleteTacticalLobby({
    required String profileId,
    required String scanId,
    required int expectedRevision,
    required String idempotencyKey,
  }) async =>
      (await _client.send('tactical.v2.lobby.delete', {
            'profile_id': profileId,
            'scan_id': scanId,
            'expected_revision': expectedRevision,
            'idempotency_key': idempotencyKey,
          }))['revision']
          as int;

  @override
  Future<int> aliasTacticalOpponent({
    required String profileId,
    required String opponentIdentityId,
    required String displayName,
    required String? nameTemplateId,
    required int expectedRevision,
    required String idempotencyKey,
  }) async =>
      (await _client.send('tactical.v2.opponent.alias', {
            'profile_id': profileId,
            'opponent_identity_id': opponentIdentityId,
            'display_name': displayName,
            'name_template_id': nameTemplateId,
            'expected_revision': expectedRevision,
            'idempotency_key': idempotencyKey,
          }))['revision']
          as int;

  @override
  Future<TacticalStatisticsResult> queryTacticalStatistics(
    String profileId,
    TacticalStatsFilters filters,
  ) async => TacticalStatisticsResult.fromWire(
    await _client.send('tactical.v2.stats.query', {
      'profile_id': profileId,
      'filters': filters.toWire(),
    }),
  );

  @override
  Future<TacticalTrendsResult> queryTacticalTrends(
    String profileId,
    TacticalTrendFilters filters,
  ) async => TacticalTrendsResult.fromWire(
    await _client.send('tactical.v2.trends.query', {
      'profile_id': profileId,
      'filters': filters.toWire(),
    }),
  );

  @override
  Future<TacticalRecommendationResult> queryTacticalRecommendations(
    String profileId,
    TacticalRecommendationFilters filters,
  ) async => TacticalRecommendationResult.fromWire(
    await _client.send('tactical.v2.recommend.query', {
      'profile_id': profileId,
      'filters': filters.toWire(),
    }),
  );

  @override
  Future<TacticalPredictionSaveResult> saveTacticalRecommendation({
    required String profileId,
    required TacticalRecommendationFilters filters,
    required int expectedRevision,
    required String idempotencyKey,
  }) async => TacticalPredictionSaveResult.fromWire(
    await _client.send('tactical.v2.recommend.save', {
      'profile_id': profileId,
      'filters': filters.toWire(),
      'expected_revision': expectedRevision,
      'idempotency_key': idempotencyKey,
    }),
  );

  @override
  Future<TacticalSavedPrediction> getTacticalRecommendation(
    String profileId,
    String predictionId,
  ) async => TacticalSavedPrediction.fromWire(
    await _client.send('tactical.v2.recommend.get', {
      'profile_id': profileId,
      'prediction_id': predictionId,
    }),
  );

  @override
  Future<TacticalShareState> loadTacticalShareState(String profileId) async =>
      TacticalShareState.fromWire(
        await _client.send('tactical.v2.share.state.get', {
          'profile_id': profileId,
        }),
      );

  @override
  Future<TacticalSharePrepareResult> prepareTacticalShare({
    required String profileId,
    required String matchId,
    required String scopeId,
    required String contributorId,
    required TacticalShareConsent consent,
    required String attemptSessionId,
    required int attemptIndex,
    required String sharedAt,
    required String patch,
  }) async => TacticalSharePrepareResult.fromWire(
    await _client.send('tactical.v2.share.prepare', {
      'profile_id': profileId,
      'match_id': matchId,
      'scope_id': scopeId,
      'contributor_id': contributorId,
      'consent': consent.toWire(),
      'attempt_session_id': attemptSessionId,
      'attempt_index': attemptIndex,
      'shared_at': sharedAt,
      'patch': patch,
    }),
  );

  @override
  Future<TacticalShareMutationResult> importTacticalShares({
    required String profileId,
    required List<TacticalSharePayload> shares,
    required int expectedRevision,
    required String idempotencyKey,
  }) async => TacticalShareMutationResult.fromWire(
    await _client.send('tactical.v2.share.import', {
      'profile_id': profileId,
      'shares': shares.map((item) => item.toWire()).toList(),
      'expected_revision': expectedRevision,
      'idempotency_key': idempotencyKey,
    }),
  );

  @override
  Future<TacticalShareMutationResult> withdrawTacticalShares({
    required String profileId,
    required List<String> shareIds,
    required String withdrawnAt,
    required String reason,
    required int expectedRevision,
    required String idempotencyKey,
  }) async => TacticalShareMutationResult.fromWire(
    await _client.send('tactical.v2.share.withdraw', {
      'profile_id': profileId,
      'share_ids': shareIds,
      'withdrawn_at': withdrawnAt,
      'reason': reason,
      'expected_revision': expectedRevision,
      'idempotency_key': idempotencyKey,
    }),
  );

  @override
  Future<TacticalShareAnalyticsResult> queryTacticalShareAnalytics(
    String profileId,
    TacticalShareAnalyticsFilters filters,
  ) async => TacticalShareAnalyticsResult.fromWire(
    await _client.send('tactical.v2.share.analytics.query', {
      'profile_id': profileId,
      'filters': filters.toWire(),
    }),
  );

  @override
  Future<void> reconnect() {
    final restart = _restartFlight;
    if (restart != null) return restart;
    return _reconnectFlight ??= _reconnectOnce();
  }

  Future<void> _reconnectOnce() async {
    try {
      await _client.start();
    } finally {
      _reconnectFlight = null;
    }
  }

  @override
  Future<void> restartBackend() => _restartFlight ??= _restartOnce();

  Future<void> _restartOnce() async {
    try {
      final reconnect = _reconnectFlight;
      if (reconnect != null) await reconnect;
      await _client.restart();
    } finally {
      _restartFlight = null;
    }
  }

  @override
  ValueListenable<BackendDiagnostics> get diagnostics => _client.diagnostics;

  @override
  String buildDiagnosticsReport({
    required bool? scannerReady,
    required int scannerTargetCount,
  }) {
    final value = diagnostics.value;
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

  @override
  Future<void> startScan() async {
    try {
      final readiness = await scannerReadiness();
      final targets = await listScannerTargets();
      ScannerTarget? target;
      for (final item in targets) {
        if (item.status == ScannerTargetStatus.ready) {
          target = item;
          break;
        }
      }
      if (readiness['ready'] != true || target == null) {
        _state.value = _state.value.copyWith(
          scanPhase: ScanPhase.failed,
          scanAvailable: false,
        );
        return;
      }
      _state.value = _state.value.copyWith(
        scanPhase: ScanPhase.scanning,
        scanAvailable: true,
      );
      await startScannerSession(ScannerKind.student, target.id);
    } catch (_) {
      _state.value = _state.value.copyWith(scanPhase: ScanPhase.failed);
      rethrow;
    }
  }

  @override
  Stream<ScannerEvent> get scannerEvents => _scanner.scannerEvents;

  @override
  Future<List<ScannerTarget>> listScannerTargets() =>
      _scanner.listScannerTargets();

  @override
  Future<Map<String, dynamic>> scannerReadiness() =>
      _scanner.scannerReadiness();

  @override
  Future<ScannerSession> startScannerSession(
    ScannerKind kind,
    String targetId,
  ) => _scanner.startScannerSession(kind, targetId);

  @override
  Future<Map<String, dynamic>> cancelScannerSession(ScannerSession session) =>
      _scanner.cancelScannerSession(session);

  @override
  Future<ScannerSessionSnapshot> scannerSnapshot(ScannerSession session) =>
      _scanner.scannerSnapshot(session);

  @override
  Future<ScannerCandidate> getScannerCandidate(
    ScannerSession session,
    String candidateId,
  ) => _scanner.getScannerCandidate(session, candidateId);

  @override
  Future<ScannerCandidate> reviewScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate,
    Map<String, dynamic> payload, {
    required bool approve,
    required String reason,
  }) => _scanner.reviewScannerCandidate(
    session,
    candidate,
    payload,
    approve: approve,
    reason: reason,
  );

  @override
  Future<Map<String, dynamic>> commitScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate, {
    required String profileId,
    required int expectedRepositoryRevision,
    required String idempotencyKey,
  }) => _scanner.commitScannerCandidate(
    session,
    candidate,
    profileId: profileId,
    expectedRepositoryRevision: expectedRepositoryRevision,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await dispose();
    return AppExitResponse.exit;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _client.connection.removeListener(_syncConnection);
    await _scannerSubscription.cancel();
    await _scanner.dispose();
    await _client.dispose();
    _state.dispose();
  }

  void _syncConnection() {
    if (!_disposed) {
      _state.value = _state.value.copyWith(
        connection: _client.connection.value,
        scanAvailable: _client.connection.value == BackendConnection.connected
            ? _state.value.scanAvailable
            : false,
      );
      if (_client.connection.value == BackendConnection.connected) {
        unawaited(_refreshScannerReadiness());
      }
    }
  }

  Future<void> _refreshScannerReadiness() async {
    try {
      final readiness = await scannerReadiness();
      final targets = await listScannerTargets();
      if (!_disposed) {
        _state.value = _state.value.copyWith(
          scanAvailable:
              readiness['ready'] == true &&
              targets.any((item) => item.status == ScannerTargetStatus.ready),
        );
      }
    } catch (_) {
      if (!_disposed) {
        _state.value = _state.value.copyWith(scanAvailable: false);
      }
    }
  }

  void _handleScannerEvent(ScannerEvent event) {
    if (_disposed || event.eventKind != ScannerEventKind.terminal) return;
    final outcome = event.payload['outcome'];
    _state.value = _state.value.copyWith(
      scanPhase: outcome == 'completed'
          ? ScanPhase.succeeded
          : ScanPhase.failed,
    );
  }
}
