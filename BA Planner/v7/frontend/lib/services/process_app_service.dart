import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_service.dart';
import 'backend_process.dart';
import 'planning_protocol_client.dart';
import 'repository_service.dart';
import 'scanner_service.dart';

class ProcessAppService with WidgetsBindingObserver implements AppService, RepositoryService, ScannerService {
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
      PlanningProtocolClient(() => startBackendProcess(config)),
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
    return ProcessAppService(
      PlanningProtocolClient(() {
        final config = BackendProcessConfig.resolve(
          pythonExecutable: pythonExecutable,
          backendDirectory: backendDirectory,
        );
        return startBackendProcess(config);
      }),
    );
  }

  final PlanningProtocolClient _client;
  late final ScannerProtocolClient _scanner;
  late final StreamSubscription<ScannerEvent> _scannerSubscription;
  final ValueNotifier<AppServiceState> _state;
  bool _disposed = false;

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
    if (students is! List) throw const FormatException('Invalid student catalog');
    return students
        .map((item) => StudentCatalogEntry.fromWire(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

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
    return values.map((item) => RepositoryProfile.fromWire(Map<String, dynamic>.from(item as Map))).toList();
  }

  @override
  Future<RepositoryProfile> createProfile(String displayName, String idempotencyKey) async {
    final payload = await _client.send('repository.profile.create', {'display_name': displayName, 'idempotency_key': idempotencyKey});
    return RepositoryProfile.fromWire(Map<String, dynamic>.from(payload['profile'] as Map));
  }

  Future<int> _revisionMutation(String method, Map<String, dynamic> payload) async {
    final response = await _client.send(method, payload);
    final revision = response['revision'];
    if (revision is! int) throw const FormatException('Invalid repository revision');
    return revision;
  }

  @override
  Future<int> selectProfile(String profileId, int expectedRevision, String idempotencyKey) => _revisionMutation('repository.profile.select', {'profile_id':profileId,'expected_revision':expectedRevision,'idempotency_key':idempotencyKey});

  @override
  Future<int> renameProfile(String profileId, String displayName, int expectedRevision, String idempotencyKey) => _revisionMutation('repository.profile.rename', {'profile_id':profileId,'display_name':displayName,'expected_revision':expectedRevision,'idempotency_key':idempotencyKey});

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async => RepositoryState.fromWire(await _client.send('repository.state.get', {'profile_id':profileId}));

  @override
  Future<int> saveRepositoryGoals(String profileId, Map<String, dynamic> goals, int expectedRevision, String idempotencyKey) => _revisionMutation('repository.goals.save', {'profile_id':profileId,'goals':goals,'expected_revision':expectedRevision,'idempotency_key':idempotencyKey});

  @override
  Future<int> saveRepositoryStudents(String profileId, List<ConfirmedStudentState> students, int expectedRevision, String idempotencyKey) => _revisionMutation('repository.students.update', {'profile_id':profileId,'students':students.map((student) => student.toWire()).toList(growable:false),'expected_revision':expectedRevision,'idempotency_key':idempotencyKey});

  @override
  Future<void> reconnect() => _client.start();

  @override
  Future<void> restartBackend() => _client.restart();

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
        _state.value = _state.value.copyWith(scanPhase: ScanPhase.failed, scanAvailable: false);
        return;
      }
      _state.value = _state.value.copyWith(scanPhase: ScanPhase.scanning, scanAvailable: true);
      await startScannerSession(ScannerKind.student, target.id);
    } catch (_) {
      _state.value = _state.value.copyWith(scanPhase: ScanPhase.failed);
      rethrow;
    }
  }

  @override
  Stream<ScannerEvent> get scannerEvents => _scanner.scannerEvents;

  @override
  Future<List<ScannerTarget>> listScannerTargets() => _scanner.listScannerTargets();

  @override
  Future<Map<String, dynamic>> scannerReadiness() => _scanner.scannerReadiness();

  @override
  Future<ScannerSession> startScannerSession(ScannerKind kind, String targetId) => _scanner.startScannerSession(kind, targetId);

  @override
  Future<Map<String, dynamic>> cancelScannerSession(ScannerSession session) => _scanner.cancelScannerSession(session);

  @override
  Future<Map<String, dynamic>> scannerSnapshot(ScannerSession session) => _scanner.scannerSnapshot(session);

  @override
  Future<ScannerCandidate> getScannerCandidate(ScannerSession session, String candidateId) => _scanner.getScannerCandidate(session, candidateId);

  @override
  Future<ScannerCandidate> reviewScannerCandidate(ScannerSession session, ScannerCandidate candidate, Map<String, dynamic> payload, {required bool approve, required String reason}) => _scanner.reviewScannerCandidate(session, candidate, payload, approve: approve, reason: reason);

  @override
  Future<Map<String, dynamic>> commitScannerCandidate(ScannerSession session, ScannerCandidate candidate, {required String profileId, required int expectedRepositoryRevision, required String idempotencyKey}) => _scanner.commitScannerCandidate(session, candidate, profileId: profileId, expectedRepositoryRevision: expectedRepositoryRevision, idempotencyKey: idempotencyKey);

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
        scanAvailable: _client.connection.value == BackendConnection.connected ? _state.value.scanAvailable : false,
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
          scanAvailable: readiness['ready'] == true && targets.any((item) => item.status == ScannerTargetStatus.ready),
        );
      }
    } catch (_) {
      if (!_disposed) _state.value = _state.value.copyWith(scanAvailable: false);
    }
  }

  void _handleScannerEvent(ScannerEvent event) {
    if (_disposed || event.eventKind != ScannerEventKind.terminal) return;
    final outcome = event.payload['outcome'];
    _state.value = _state.value.copyWith(
      scanPhase: outcome == 'completed' ? ScanPhase.succeeded : ScanPhase.failed,
    );
  }
}
