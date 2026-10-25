import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../ui/models/planning_models.dart';
import 'app_service.dart';
import 'asset_preparation_service.dart';
import 'diagnostics_service.dart';
import 'mock_asset_preparation.dart';
import 'mock_student_fixture.dart';
import 'mock_student_calculation_fixture.dart';
import 'mock_student_bond_fixture.dart';
import 'repository_service.dart';
import 'mock_repository_plan.dart';
import 'mock_repository_history.dart';
import 'mock_tutorial_practice.dart';
import 'planning_protocol_client.dart';
import 'scanner_service.dart';
import 'scenario_service.dart';
import 'tactical_service.dart';
import 'tactical_v2_service.dart';
import 'mock_tactical_v2_writes.dart';
import 'mock_tactical_v2_reads.dart';

enum MockScannerScenario { completed, failed, reviewRequired, inventoryUnknown }

/// 백엔드 packaged v1 빈 획득처 표(`{"resources":{},"version":1}`)의 revision. `resource_acquisition_payload`가 정렬·
/// 압축한 JSON의 sha256이며 공유 fixture `resource_acquisition_v1.json`의 known-empty 응답 값과 같다.
const mockEmptyResourceAcquisitionRevision =
    'd1d01c1803e0005ad126df3ba58dcda51a9f3d08582a32ef1ac7f21c938f85e6';

/// SU2: 개발 상태 패널이 흉내 내는 이관 실패의 백엔드 안내 문구(화면은 reason별 앱 문구를 쓴다).
const mockUserDataMigrationFailureMessage =
    'Mock: 사용자 자료 이관을 완료하지 못했습니다. 기존 자료는 보존되어 있습니다.';

class MockAppService
    implements
        AppService,
        AssetPreparationService,
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
        RepositoryInventoryReviewService,
        RepositoryPracticeService,
        ScannerService,
        TacticalService,
        TacticalEvidenceWriteService,
        TacticalEvidenceReadService,
        TacticalExcelImportService,
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
    this.assetPreparationScenario = MockAssetPreparationScenario.firstRun,
    this.assetPreparationStep = const Duration(milliseconds: 250),
    this.tutorialPracticeSupported = true,
    bool? goalAwareCalculation,
  }) : goalAwareCalculation = goalAwareCalculation ?? fullStudentCatalog,
       _historyClock = historyClock ?? (() => DateTime.now().toUtc()),
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
  final MockAssetPreparationScenario assetPreparationScenario;
  final Duration assetPreparationStep;

  /// F2 Mock 준비(합성 값). 스캔(일시정지 포함)이 끝나지 않았으면 준비 · 폴더 변경은 `scanner_busy`다.
  late final MockAssetPreparation assetPreparationMock = MockAssetPreparation(
    scenario: assetPreparationScenario,
    step: assetPreparationStep,
    scannerActive: () =>
        _scannerHistory.keys.any((id) => !_scannerTerminals.containsKey(id)),
  );
  final bool fullStudentCatalog;

  /// MC1: [calculateStudent] follows current → target (rule table in
  /// `mock_student_calculation_fixture.dart`). Defaults to [fullStudentCatalog], so the Windows mock
  /// app (`createMockAppService`) grows with the goal while `MockAppService()` in tests keeps the canned
  /// sample. The shared fixture input always returns the canned sample.
  final bool goalAwareCalculation;
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
  final Set<String> _assignedScannerSlots = {};
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
  Stream<AssetPrepareEvent> get assetPrepareEvents =>
      assetPreparationMock.assetPrepareEvents;

  @override
  Future<AssetPrepareStatus> assetPrepareStatus() =>
      assetPreparationMock.assetPrepareStatus();

  @override
  Future<AssetPrepareStatus> setAssetGameDir(String? path) =>
      assetPreparationMock.setAssetGameDir(path);

  @override
  Future<AssetPrepareJobRef> startAssetPreparation() =>
      assetPreparationMock.startAssetPreparation();

  @override
  Future<AssetPrepareCancelResult> cancelAssetPreparation(
    AssetPrepareJobRef job,
  ) => assetPreparationMock.cancelAssetPreparation(job);

  @override
  Future<AssetPrepareJob> assetPrepareSnapshot(AssetPrepareJobRef job) =>
      assetPreparationMock.assetPrepareSnapshot(job);

  @override
  Future<void> reconnect() {
    // SU2: 이관 실패는 재연결로 풀리지 않는다(실제 client와 같은 오류). flight 밖에서 거절해 실패 future가 남지 않게 한다.
    final blocked = _state.value.userDataMigrationFailure;
    if (blocked != null) {
      _recordLifecycle('reconnect blocked: user data migration failed');
      return Future.error(_userDataMigrationError(blocked));
    }
    return _reconnectFlight ??= _mockReconnect();
  }

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
      // SU2: 재시작은 이관 실패를 비우고 다시 시도한다. 토글이 켜져 있으면(원인 그대로) 새 프로세스도 다시 실패한다.
      final blocked = _state.value.userDataMigrationFailure;
      _state.value = _state.value.copyWith(
        connection: BackendConnection.disconnected,
        clearUserDataMigrationFailure: true,
      );
      _diagnostics.value = _diagnostics.value.copyWith(
        processGeneration: _diagnostics.value.processGeneration + 1,
      );
      _syncDiagnostics();
      assetPreparationMock.handleBackendRestart();
      // X4: 백엔드 시작 때 남은 임시 계정을 지운다(계약 recover, 선택 · 노출 전).
      _removeMockPractice();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (blocked != null) {
        _state.value = _state.value.copyWith(userDataMigrationFailure: blocked);
        _recordLifecycle('user data migration failed: ${blocked.reason.wire}');
        throw _userDataMigrationError(blocked);
      }
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
  Future<List<ScannerTarget>> listScannerTargets() async =>
      _mockPracticeSelected ? const [tutorialPracticeTarget] : _scannerTargets;

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
    // F2: 준비 · 폴더 변경이 실행 권한을 가진 동안 스캔 시작은 거절된다(backend 공용 gate).
    if (assetPreparationMock.busy) {
      throw BackendRemoteException(
        code: 'asset_prepare_busy',
        message: 'another scanner or asset preparation operation is active',
      );
    }
    // X4: 가상 대상은 고른 임시 계정으로만, 임시 계정은 가상 대상으로만 시작한다(실제 캡처 · 입력으로 넘어가지 않음).
    final practice = _mockPracticeProfile;
    final virtual = targetId == practiceVirtualTargetId;
    if (virtual !=
        (practice != null && profileId == practice.id && practice.selected)) {
      throw _practiceError(
        'practice_profile_required',
        'the tutorial target needs the selected practice profile',
      );
    }
    if (virtual &&
        !tutorialPracticeReplaySupported(
          kind,
          studentScanMode,
          inventoryScanProfile,
        )) {
      throw _practiceError(
        'invalid_payload',
        'no tutorial replay for this scan kind',
      );
    }
    final target = (virtual ? const [tutorialPracticeTarget] : _scannerTargets)
        .where((item) => item.id == targetId);
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
    _scannerSessionTargets[session.id] = targetId;
    _scannerSessionRaw[session.id] = (
      scanKind: kind.wireName,
      inventoryScanProfile: kind == ScannerKind.inventory
          ? inventoryScanProfile?.wireName
          : null,
    );
    _scannerSessionProfiles[session.id] = profileId;
    _emitScannerEvent(session, ScannerEventKind.phase, {'phase': 'capturing'});
    if (virtual) {
      _practiceSessions[session.id] = session;
      _startMockPracticeReplay(session, inventoryScanProfile);
      return session;
    }
    // 각 단계는 FB-10a 안전 지점([_mockScannerStep])을 지난다. 일시정지 요청이 있으면 그 단계 대신 멈춘다.
    _startMockScannerReplay(session, [
      () {
        if (_scannerTerminals.containsKey(session.id)) return;
        _emitScannerEvent(session, ScannerEventKind.progress, {
          'current': 1,
          'total': kind == ScannerKind.student ? null : 2,
          'message_key': 'scanner.${kind.name}.recognizing',
        });
      },
      () {
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
      },
      () {
        if (!_scannerTerminals.containsKey(session.id)) {
          _emitTerminal(session, 'completed');
        }
      },
    ]);
    return session;
  }

  @override
  Future<Map<String, dynamic>> cancelScannerSession(
    ScannerSession session,
  ) async {
    final terminal = _scannerTerminals[session.id];
    if (terminal != null) return {'accepted': false, 'terminal': terminal};
    _scannerCancelRequested.add(session.id);
    _scannerTimers.add(
      Timer(
        const Duration(milliseconds: 10),
        () => _emitTerminal(session, 'cancelled'),
      ),
    );
    return {'accepted': true, 'terminal': null};
  }

  /// FB-10a(Python `ScannerPauseControl`와 같은 규칙): 진행 중이고 취소 요청이 없을 때만 받아들여
  /// `pauseRequested`가 된다. 다음 안전 지점에서 `paused` 이벤트를 낸다.
  @override
  Future<ScannerSessionControl> pauseScannerSession(
    ScannerSession session,
  ) async {
    _requireMockScannerSession(session);
    return _requestMockScannerPause(session.id, ScannerPauseReason.user);
  }

  /// FB-10a: `paused`일 때만 받는다. 대상 창이 준비되지 않았으면 거절하고 사유를 `targetMinimized`로 바꾼다
  /// (이벤트 없음). 받아들이면 `resumed`를 응답보다 먼저 내고 재생 커서에서 다시 잇는다(F3c-8).
  @override
  Future<ScannerSessionControl> resumeScannerSession(
    ScannerSession session,
  ) async {
    _requireMockScannerSession(session);
    final id = session.id;
    if (_scannerTerminals.containsKey(id) ||
        _scannerControlStates[id] != ScannerControlState.paused) {
      return _mockScannerControl(id);
    }
    final targetId = _scannerSessionTargets[id];
    final ready = targetId == practiceVirtualTargetId
        ? _mockPracticeSelected
        : _scannerTargets.any(
            (item) =>
                item.id == targetId && item.status == ScannerTargetStatus.ready,
          );
    if (!ready) {
      _scannerPauseReasons[id] = ScannerPauseReason.targetMinimized;
      return _mockScannerControl(id);
    }
    if (_scannerCancelRequested.contains(id)) return _mockScannerControl(id);
    _scannerControlStates[id] = ScannerControlState.running;
    _scannerPauseReasons.remove(id);
    _emitScannerEvent(session, ScannerEventKind.resumed, {'reason': null});
    _scheduleMockScannerStep(session);
    return _mockScannerControl(id, accepted: true);
  }

  @override
  Future<ScannerSessionSnapshot> scannerSnapshot(ScannerSession session) async {
    final events = _scannerHistory[session.id] ?? const <ScannerEvent>[];
    final control = _mockScannerControl(session.id);
    return ScannerSessionSnapshot(
      sessionId: session.id,
      generation: session.generation,
      kind: session.kind,
      lastSequence: events.isEmpty ? 0 : events.last.sequence,
      terminal: _scannerTerminals[session.id],
      controlState: control.controlState,
      reason: control.reason,
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
    Set<String>? confirmedFields,
  }) async {
    final values = payload['values'];
    if ((confirmedFields ?? const <String>{}).any(
      (field) =>
          session.kind != ScannerKind.student ||
          values is! Map ||
          !values.containsKey(field),
    )) {
      throw StateError(
        'invalid_payload: confirmed_fields must belong to student values',
      );
    }
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
                  ((confirmedFields ?? const <String>{}).contains(item.field) ||
                      item.field == 'student_stat_validation') &&
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
      reviewRequired: studentRevalidation
          ? candidate.evidence.any(
              (item) =>
                  !{
                    'ok',
                    'inferred',
                    'skipped',
                    'verified',
                    'deferred',
                    'shadow',
                  }.contains(item.status) &&
                  !(item.field == 'student_stat_validation' ||
                      (confirmedFields ?? const <String>{}).contains(
                        item.field,
                      )),
            )
          : candidate.reviewRequired,
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
  Future<ScannerUnresolvedSlots> scannerUnresolvedSlots(
    ScannerSession session,
    ScannerCandidate candidate,
  ) async {
    final key = '${session.id}:${candidate.id}:1';
    final slots =
        scannerScenario == MockScannerScenario.inventoryUnknown &&
            candidate.kind == ScannerKind.inventory &&
            !_assignedScannerSlots.contains(key)
        ? [
            ScannerUnresolvedSlot(
              slot: 1,
              profile: InventoryScanProfile.activityReports,
              width: 1280,
              height: 720,
              cropPng: base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL1WQAAAABJRU5ErkJggg==',
              ),
              candidates: const [
                ScannerIdentitySuggestion(
                  identity: 'Item_Icon_ExpItem_1',
                  score: 0.81,
                ),
              ],
            ),
          ]
        : <ScannerUnresolvedSlot>[];
    return ScannerUnresolvedSlots(
      candidateId: candidate.id,
      candidateRevision: candidate.revision,
      slots: slots,
    );
  }

  @override
  Future<ScannerIdentityAssignmentResult> assignScannerIdentity(
    ScannerSession session,
    ScannerCandidate candidate, {
    required int slot,
    required String identity,
    required bool persist,
  }) async {
    final current = await getScannerCandidate(session, candidate.id);
    if (current.revision != candidate.revision) {
      throw StateError('candidate_revision_conflict');
    }
    final key = '${session.id}:${candidate.id}:$slot';
    if (_assignedScannerSlots.contains(key)) {
      throw StateError('unresolved_slot_not_found');
    }
    final payload = Map<String, dynamic>.from(current.payload);
    final entries = List<dynamic>.from(payload['entries'] as List? ?? const []);
    entries.add({
      'key': identity,
      'quantity': null,
      'item_id': identity,
      'name': identity,
      'observed_slot': slot,
      'profile_id': 'activity_reports',
      'inventory_scan_profile': 'activity_reports',
    });
    payload['entries'] = entries;
    final revised = ScannerCandidate(
      id: current.id,
      sessionId: current.sessionId,
      generation: current.generation,
      revision: current.revision + 1,
      kind: current.kind,
      payload: payload,
      evidence: [
        ...current.evidence,
        ScannerFieldEvidence(
          field: 'entries[$slot].item_id',
          status: 'verified',
          source: 'user_label',
          confidence: 1,
        ),
      ],
      reviewRequired: true,
      approved: false,
      audit: [
        ...current.audit,
        {
          'source': 'user_identity_assignment',
          'slot': slot,
          'identity': identity,
          'persistence': persist ? 'user_confirmed' : 'session',
        },
      ],
    );
    _assignedScannerSlots.add(key);
    _scannerCandidates['${session.id}:${candidate.id}'] = revised;
    return ScannerIdentityAssignmentResult(candidate: revised, slots: const []);
  }

  @override
  Future<Map<String, dynamic>> commitScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate, {
    required String profileId,
    required int expectedRepositoryRevision,
    required String idempotencyKey,
  }) async {
    _requireMockPracticeScope(session, profileId);
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
    // FB-10b: 승인 key는 확인 필요 표시를 지우고, 인식했지만 뺀 key는 이전 수량 그대로 표시를 단다(이전 수량이
    // 없으면 표시만, 수량은 만들지 않는다). 쓰기 앞에서 계산해 깨진 메타면 아무것도 쓰지 않는다.
    final reviewKeys = frozen.bucket == 'inventory'
        ? (_mockReviewKeys(profileId).toSet()
            ..addAll(frozen.excludedKeys)
            ..removeAll(frozen.appliedKeys))
        : null;
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
    if (reviewKeys != null) _storeMockReview(profileId, reviewKeys);
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
      excludedKeys: List.unmodifiable(excluded),
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
    _scannerControlStates.remove(session.id);
    _scannerPauseReasons.remove(session.id);
    _scannerReplays.remove(session.id);
  }

  // ---- FB-10a Mock pause/resume (Python ScannerPauseControl parity) ----
  // 진행 단계 사이(안전 지점)에서만 멈춘다. 자동으로 이어 가지 않는다. 취소는 기존 cancel 그대로다.
  final Map<String, ScannerControlState> _scannerControlStates = {};
  final Map<String, ScannerPauseReason> _scannerPauseReasons = {};
  final Map<String, _MockScannerReplay> _scannerReplays = {};
  final Map<String, String> _scannerSessionTargets = {};
  final Set<String> _scannerCancelRequested = {};

  void _requireMockScannerSession(ScannerSession session) {
    if (!_scannerHistory.containsKey(session.id)) {
      throw StateError('session_not_found');
    }
  }

  ScannerSessionControl _mockScannerControl(
    String sessionId, {
    bool accepted = false,
  }) {
    final terminal = _scannerTerminals[sessionId];
    if (terminal != null) {
      return ScannerSessionControl(
        accepted: false,
        controlState: ScannerControlState.terminal,
        terminal: terminal,
      );
    }
    final state =
        _scannerControlStates[sessionId] ?? ScannerControlState.running;
    return ScannerSessionControl(
      accepted: accepted,
      controlState: state,
      reason: state == ScannerControlState.running
          ? null
          : _scannerPauseReasons[sessionId],
    );
  }

  ScannerSessionControl _requestMockScannerPause(
    String sessionId,
    ScannerPauseReason reason,
  ) {
    final accepted =
        !_scannerTerminals.containsKey(sessionId) &&
        !_scannerCancelRequested.contains(sessionId) &&
        (_scannerControlStates[sessionId] ?? ScannerControlState.running) ==
            ScannerControlState.running;
    if (accepted) {
      _scannerControlStates[sessionId] = ScannerControlState.pauseRequested;
      _scannerPauseReasons[sessionId] = reason;
    }
    return _mockScannerControl(sessionId, accepted: accepted);
  }

  /// 입력 감지·창 최소화 같은 자동 일시정지를 흉내 낸다(테스트·개발용). 다음 안전 지점에서 [reason]으로 멈춘다.
  @visibleForTesting
  ScannerSessionControl debugRequestScannerPause(
    String sessionId,
    ScannerPauseReason reason,
  ) => _requestMockScannerPause(sessionId, reason);

  /// 재생을 시작한다(F3c-8): [steps]를 순서대로 10ms 간격으로 하되, 한 번에 다음 단계 하나만 예약한다. 일시정지면
  /// 예약을 멈추고 재개가 커서에서 이어 가므로, 미룬 단계와 원래 일정의 뒤 단계(끝 포함)가 뒤섞이지 않는다.
  void _startMockScannerReplay(
    ScannerSession session,
    List<void Function()> steps,
  ) {
    _scannerReplays[session.id] = _MockScannerReplay(steps);
    _scheduleMockScannerStep(session);
  }

  /// 커서의 다음 단계를 10ms 뒤로 예약한다. 단계가 다 끝났으면 재생을 지운다.
  void _scheduleMockScannerStep(ScannerSession session) {
    final replay = _scannerReplays[session.id];
    if (replay == null) return;
    if (replay.next >= replay.steps.length) {
      _scannerReplays.remove(session.id);
      return;
    }
    _scannerTimers.add(
      Timer(const Duration(milliseconds: 10), () => _mockScannerStep(session)),
    );
  }

  /// 안전 지점. 진행 중이면 커서의 단계를 하고 다음을 예약한다. 일시정지 요청·일시정지 중이면 커서를 그대로 두고
  /// 멈춘다(재개가 다시 예약한다). 요청 뒤 처음 닿은 안전 지점에서 `paused`를 한 번 낸다.
  void _mockScannerStep(ScannerSession session) {
    final id = session.id;
    final replay = _scannerReplays[id];
    if (replay == null) return;
    final state = _scannerControlStates[id] ?? ScannerControlState.running;
    if (state == ScannerControlState.running) {
      replay.steps[replay.next++]();
      _scheduleMockScannerStep(session);
      return;
    }
    // 멈춘(또는 멈추려던) 세션을 취소했으면 남은 단계는 하지 않고 paused도 내지 않는다. 끝은 cancel이 낸다.
    if (_scannerCancelRequested.contains(id)) {
      _scannerReplays.remove(id);
      return;
    }
    if (state == ScannerControlState.pauseRequested) {
      _scannerControlStates[id] = ScannerControlState.paused;
      _emitScannerEvent(session, ScannerEventKind.paused, {
        'reason': _scannerPauseReasons[id]!.wireName,
      });
    }
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
    // X4: 임시 계정을 고른 동안은 대본 학생(아카네 · 칸나(수영복) …)이 보이도록 전체 카탈로그다.
    final fullStudentCatalog = this.fullStudentCatalog || _mockPracticeSelected;
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
  Future<InventoryCatalogResult>
  listInventoryItems() async => _withMockPracticeCatalog(
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
    ),
  );

  /// X4: 임시 계정을 고른 동안은 가상 스캔의 노트 · BD 60칸(백엔드 카탈로그와 같은 키 · 이름 · 학교 · 티어)을 덧붙인다.
  InventoryCatalogResult _withMockPracticeCatalog(InventoryCatalogResult base) {
    if (!_mockPracticeSelected) return base;
    final known = {for (final item in base.items) item.resourceKey};
    return InventoryCatalogResult(
      catalogRevision: base.catalogRevision,
      items: [
        ...base.items,
        for (final item in tutorialPracticeCatalogEntries())
          if (!known.contains(item.resourceKey)) item,
      ],
    );
  }

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
    // Deterministic mixed-growth sample, or (MC1) the goal-aware mock rule table — neither is a
    // second implementation of real costs.
    final owned = <String, int?>{};
    for (final raw in (inventory?['entries'] as List? ?? const [])) {
      final entry = Map<String, dynamic>.from(raw as Map);
      final quantity = entry['quantity'];
      owned[(entry['item_id'] ?? entry['key']) as String] =
          quantity == null ? null : int.parse(quantity as String);
    }
    var wire = mockStudentCalculationWire;
    if (goalAwareCalculation &&
        !mockStudentCalculationIsSample(currentStudent, targets)) {
      final studentId = currentStudent['student_id'];
      final student = (await _loadStudentCatalog())
          .where((entry) => entry.studentId == studentId)
          .firstOrNull;
      wire = mockGoalAwareStudentCalculationWire(
        currentStudent: currentStudent,
        targets: targets,
        displayName: student?.displayName,
        school: student?.school,
        equipmentSlots: [
          student?.equipmentSlot1,
          student?.equipmentSlot2,
          student?.equipmentSlot3,
        ],
      );
    }
    return StudentCalculationResult.fromWire({
      ...wire,
      'resources': [
        for (final raw in wire['resources'] as List)
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
  Future<List<RepositoryProfile>> listProfiles() async => List.unmodifiable(
    // X4: 일반 계정 목록에는 임시 계정이 없다(수명은 repository.practice.*).
    _profiles.where((profile) => !profile.isPractice),
  );

  // ---- FB-2d profile delete (Python profile_delete_transaction parity) ----
  // The backend derives a stable ID from the create key and keeps a deletion
  // tombstone (key, original expected revision, response) per deleted ID. Mock
  // keeps the same two facts; IDs are never reused after a delete.
  final Map<String, String> _mockCreateKeys = {};
  final Map<String, ({String idempotencyKey, int expectedRevision, int revision})>
  _mockDeleteTombstones = {};
  int? _nextMockProfileNumber;

  /// 다음 삭제는 저장소에서 끝내고 응답만 잃는다(`TimeoutException`). 같은 key·원 revision 재요청은 원 응답이다.
  bool loseNextProfileDeleteResponse = false;

  void _requireNotDeletedProfile(String profileId) {
    if (_mockDeleteTombstones.containsKey(profileId) ||
        _mockPracticeDeleted.contains(profileId)) {
      throw StateError('profile_not_found');
    }
  }

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
    final knownId = _mockCreateKeys[idempotencyKey];
    if (knownId != null) {
      // 같은 create key: 삭제된 stable ID는 다시 만들지 않고, 살아 있으면 같은 내용일 때만 원 계정이다.
      if (_mockDeleteTombstones.containsKey(knownId)) {
        throw StateError('idempotency_conflict');
      }
      final existing = _profiles.where((item) => item.id == knownId).firstOrNull;
      if (existing != null) {
        if (existing.displayName != displayName ||
            existing.avatarStudentId != avatarStudentId) {
          throw StateError('idempotency_conflict');
        }
        return existing;
      }
    }
    final next = _nextMockProfileNumber ?? 0;
    var number = next > _profiles.length ? next : _profiles.length + 1;
    String idOf(int value) => value.toRadixString(16).padLeft(24, '0');
    while (_profiles.any((item) => item.id == idOf(number)) ||
        _mockDeleteTombstones.containsKey(idOf(number))) {
      number += 1;
    }
    _nextMockProfileNumber = number + 1;
    final profile = RepositoryProfile(
      id: idOf(number),
      displayName: displayName,
      avatarStudentId: avatarStudentId,
      revision: 0,
      selected: false,
    );
    _mockCreateKeys[idempotencyKey] = profile.id;
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
        isPractice: profile.isPractice,
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
      isPractice: profile.isPractice,
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
      isPractice: profile.isPractice,
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
    if (failNextProfileMutation) {
      failNextProfileMutation = false;
      throw StateError('revision_conflict');
    }
    // tombstone 먼저(백엔드와 같은 순서): 다른 key = profile_not_found, 같은 key·다른 revision =
    // idempotency_conflict, 같은 key·원 revision = 원 응답.
    final tombstone = _mockDeleteTombstones[profileId];
    if (tombstone != null) {
      if (tombstone.idempotencyKey != idempotencyKey) {
        throw StateError('profile_not_found');
      }
      if (tombstone.expectedRevision != expectedRevision) {
        throw StateError('idempotency_conflict');
      }
      return tombstone.revision;
    }
    final index = _profiles.indexWhere((profile) => profile.id == profileId);
    // X4: 임시 계정은 일반 삭제로 지우지 않는다(repository.practice.end).
    if (index < 0 || _profiles[index].isPractice) {
      throw StateError('profile_not_found');
    }
    final profile = _profiles[index];
    if (profile.revision != expectedRevision) {
      throw StateError('revision_conflict');
    }
    final wasSelected = profile.selected;
    _profiles.removeAt(index);
    _dropMockProfileData(profileId);
    if (wasSelected && _profiles.isNotEmpty) {
      final first = _profiles.first;
      _profiles[0] = RepositoryProfile(
        id: first.id,
        displayName: first.displayName,
        avatarStudentId: first.avatarStudentId,
        revision: first.revision,
        selected: true,
        isPractice: first.isPractice,
      );
    }
    final revision = expectedRevision + 1;
    _mockDeleteTombstones[profileId] = (
      idempotencyKey: idempotencyKey,
      expectedRevision: expectedRevision,
      revision: revision,
    );
    if (loseNextProfileDeleteResponse) {
      loseNextProfileDeleteResponse = false;
      throw TimeoutException('Mock profile delete response lost');
    }
    return revision;
  }

  /// 7경로와 같은 범위: 프로필(학생·인벤토리·목표·이력)·계획·프리셋·시나리오·전술 v1·전술 v2 FB-6 쓰기.
  /// Mock에는 전술 v2 로비·통계·로컬 공유 저장이 없다(ProcessAppService만). 임시 계정 end · reset도 같은 범위를 지운다.
  void _dropMockProfileData(String profileId) {
    _tacticalStates.remove(profileId);
    _tacticalV2.remove(profileId);
    _repositoryStates.remove(profileId);
    _currentHistories.remove(profileId);
    _mockInventoryReviews.remove(profileId); // FB-10b 표시는 프로필 파일 안(FB-2d 삭제 범위).
    _repositoryPlans.remove(profileId);
    _repositoryPlanAuthoring.remove(profileId);
    _planIdempotency.remove(profileId);
    _repositoryPresets.remove(profileId);
    _presetIdempotency.remove(profileId);
    _planningScenarios.remove(profileId);
    _planningScenarioRevisions.remove(profileId);
    _scenarioIdempotency.remove(profileId);
  }

  // ---- X4 / FD-182 임시 계정(contracts/tutorial-practice-v1, F3c-1) ----
  // 한 번에 하나. 임시 계정은 `_profiles` 안에 `isPractice`로 두되 일반 목록(listProfiles)에는 내지 않는다. revision은
  // 임시 계정 저장소 revision이다(스캔 적용 · 저장마다 오른다). reset은 고정 seed를 더 높은 revision으로 다시 놓는다.
  // 같은 메서드 · 같은 key 재시도는 원 응답, 다른 요청이면 idempotency_conflict(실패한 요청은 기록하지 않는다).

  /// false면 practice 메서드가 지금 백엔드처럼 `unknown_method`로 답한다(화면의 "백엔드 미지원" 경로 시험용).
  final bool tutorialPracticeSupported;
  var _mockPracticeSupport = TutorialPracticeSupport.unknown;
  String? _mockPracticeOrigin;
  int _mockPracticeNumber = 0;
  final Map<String, ({String request, Map<String, dynamic> response})>
  _mockPracticeReceipts = {};

  /// 지운 임시 계정 id. 다른 key로 다시 end하면 already_deleted다.
  final Set<String> _mockPracticeDeleted = {};

  /// 시작한 세션의 profile_id(교차 적용 거부) · 임시 계정 세션(reset · end 때 닫는다) · 그렇게 무효가 된 세션.
  final Map<String, String?> _scannerSessionProfiles = {};
  final Map<String, ScannerSession> _practiceSessions = {};
  final Set<String> _invalidatedScannerSessions = {};

  RepositoryProfile? get _mockPracticeProfile =>
      _profiles.where((profile) => profile.isPractice).firstOrNull;

  bool get _mockPracticeSelected => _mockPracticeProfile?.selected == true;

  String? get _mockSelectedProfileId =>
      _profiles.where((profile) => profile.selected).firstOrNull?.id;

  BackendRemoteException _practiceError(String code, String message) =>
      BackendRemoteException(code: code, message: message);

  PracticeSessionState _mockPracticeState() {
    final profile = _mockPracticeProfile;
    return PracticeSessionState(
      practice: profile == null
          ? null
          : PracticeProfile(
              profileId: profile.id,
              originProfileId: _mockPracticeOrigin!,
              revision: profile.revision,
            ),
      selectedProfileId: _mockSelectedProfileId,
    );
  }

  /// 지원 여부 · 영수증(같은 key 재시도는 원 응답)을 거쳐 [run]을 한다.
  Map<String, dynamic> _mockPracticeCall(
    String method,
    Map<String, dynamic> request,
    Map<String, dynamic> Function() run,
  ) {
    if (!tutorialPracticeSupported) {
      _mockPracticeSupport = TutorialPracticeSupport.unsupported;
      throw TutorialPracticeUnsupportedException(method);
    }
    _mockPracticeSupport = TutorialPracticeSupport.supported;
    final key = request['idempotency_key'];
    if (key is! String) return run();
    final fingerprint = historyCanonicalJson(request);
    final receiptKey = '$method\u0000$key';
    final receipt = _mockPracticeReceipts[receiptKey];
    if (receipt != null) {
      if (receipt.request != fingerprint) {
        throw _practiceError(
          'idempotency_conflict',
          'idempotency key was used for a different practice request',
        );
      }
      return Map<String, dynamic>.from(
        jsonDecode(jsonEncode(receipt.response)) as Map,
      );
    }
    final response = run();
    _mockPracticeReceipts[receiptKey] = (
      request: fingerprint,
      response: Map<String, dynamic>.from(
        jsonDecode(jsonEncode(response)) as Map,
      ),
    );
    return response;
  }

  /// [profileId]가 지금 임시 계정이고 revision이 맞는가. 일반 계정이면 practice_profile_required.
  RepositoryProfile _requireMockPractice(
    String profileId,
    int expectedRevision,
  ) {
    final practice = _mockPracticeProfile;
    if (practice == null || practice.id != profileId) {
      if (_profiles.any((profile) => profile.id == profileId)) {
        throw _practiceError(
          'practice_profile_required',
          'profile is not the practice profile',
        );
      }
      throw _practiceError('profile_not_found', 'practice profile not found');
    }
    if (practice.revision != expectedRevision) {
      throw _practiceError('revision_conflict', 'practice revision changed');
    }
    return practice;
  }

  /// 고정 seed를 [baseRevision]부터 놓는다(지난 스캔 이력 하나, 목표 · 계획 0, 예시 시나리오 1). 끝 revision을 돌려준다.
  int _seedMockPractice(String profileId, int baseRevision) {
    final seed = tutorialPracticeSeed(
      profileId,
      baseRevision: baseRevision,
      recordedAt: _historyClock().subtract(const Duration(days: 1)),
    );
    _manualMockCurrentWrite = true;
    try {
      _repositoryStates[profileId] = seed.state;
    } finally {
      _manualMockCurrentWrite = false;
    }
    _currentHistories[profileId] = seed.history;
    _repositoryPlans[profileId] = mockDocumentFromGoals({
      'version': 1,
      'goals': <dynamic>[],
    });
    final revision = seed.state['revision'] as int;
    // F3c-5: 예시 시나리오 하나(대본 09c · 8단계, CF 결정 2026-10-21 — 계약 "scenarios start empty"와 다름, CF가 XB에
    // 요청). 시나리오 모음 revision은 0 그대로다.
    _planningScenarios[profileId] = [
      PlanningScenarioRecord.fromWire(
        tutorialPracticeExampleScenario(
          profileId,
          scenarioId: _newScenarioId(const []),
          baseProfileRevision: revision,
          recordedAt: _historyClock(),
        ),
      ),
    ];
    return revision;
  }

  /// 임시 계정의 열린 가상 세션을 취소하고 그 후보를 무효로 한다(이전 revision · generation은 더 쓰지 않는다).
  void _closeMockPracticeSessions() {
    for (final session in _practiceSessions.values) {
      if (!_scannerTerminals.containsKey(session.id)) {
        _scannerCancelRequested.add(session.id);
        _emitTerminal(session, 'cancelled');
      }
      _scannerCandidates.removeWhere(
        (key, _) => key.startsWith('${session.id}:'),
      );
      _invalidatedScannerSessions.add(session.id);
    }
    _practiceSessions.clear();
  }

  /// 임시 계정이 가진 모든 것을 지우고 원래 선택을 되돌린다(원 계정이 없으면 첫 일반 계정, 없으면 선택 없음). 원 계정의
  /// revision은 바꾸지 않는다. 지운 id(없었으면 null).
  String? _removeMockPractice() {
    final practice = _mockPracticeProfile;
    if (practice == null) return null;
    _closeMockPracticeSessions();
    _profiles.removeWhere((profile) => profile.id == practice.id);
    _dropMockProfileData(practice.id);
    _mockPracticeDeleted.add(practice.id);
    final origin = _mockPracticeOrigin;
    _mockPracticeOrigin = null;
    if (practice.selected && _profiles.isNotEmpty) {
      final restored = _profiles.any((profile) => profile.id == origin)
          ? origin
          : _profiles.first.id;
      for (var index = 0; index < _profiles.length; index += 1) {
        final profile = _profiles[index];
        _profiles[index] = RepositoryProfile(
          id: profile.id,
          displayName: profile.displayName,
          avatarStudentId: profile.avatarStudentId,
          revision: profile.revision,
          selected: profile.id == restored,
          isPractice: profile.isPractice,
        );
      }
    }
    return practice.id;
  }

  @override
  TutorialPracticeSupport get practiceSupport => _mockPracticeSupport;

  @override
  Future<TutorialPracticeSupport> probePracticeSupport() async {
    try {
      await currentPractice();
    } on TutorialPracticeUnsupportedException {
      // _mockPracticeCall이 unsupported로 바꿨다.
    }
    return _mockPracticeSupport;
  }

  @override
  Future<PracticeSessionState> createPractice(
    PracticeCreateRequest request,
  ) async => PracticeSessionState.fromWire(
    _mockPracticeCall('repository.practice.create', request.toWire(), () {
      if (_mockPracticeProfile != null) {
        throw _practiceError(
          'practice_session_active',
          'a practice profile is already active',
        );
      }
      final origin = _profiles
          .where(
            (profile) =>
                profile.id == request.originProfileId && !profile.isPractice,
          )
          .firstOrNull;
      if (origin == null) {
        throw _practiceError('profile_not_found', 'origin profile not found');
      }
      if (origin.revision != request.expectedOriginRevision) {
        throw _practiceError('revision_conflict', 'origin revision changed');
      }
      _mockPracticeNumber += 1;
      final id = '7e${_mockPracticeNumber.toRadixString(16).padLeft(22, '0')}';
      final revision = _seedMockPractice(id, 0);
      for (var index = 0; index < _profiles.length; index += 1) {
        final profile = _profiles[index];
        _profiles[index] = RepositoryProfile(
          id: profile.id,
          displayName: profile.displayName,
          avatarStudentId: profile.avatarStudentId,
          revision: profile.revision,
          selected: false,
          isPractice: profile.isPractice,
        );
      }
      _profiles.add(
        RepositoryProfile(
          id: id,
          displayName: '튜토리얼',
          avatarStudentId: origin.avatarStudentId,
          revision: revision,
          selected: true,
          isPractice: true,
        ),
      );
      _mockPracticeOrigin = origin.id;
      return _mockPracticeState().toWire();
    }),
  );

  @override
  Future<PracticeSessionState> currentPractice() async =>
      PracticeSessionState.fromWire(
        _mockPracticeCall(
          'repository.practice.current',
          const {},
          () => _mockPracticeState().toWire(),
        ),
      );

  @override
  Future<PracticeSessionState> resetPractice(
    PracticeResetRequest request,
  ) async => PracticeSessionState.fromWire(
    _mockPracticeCall('repository.practice.reset', request.toWire(), () {
      final practice = _requireMockPractice(
        request.profileId,
        request.expectedRevision,
      );
      _closeMockPracticeSessions();
      _dropMockProfileData(practice.id);
      final revision = _seedMockPractice(practice.id, practice.revision + 1);
      final index = _profiles.indexWhere((item) => item.id == practice.id);
      _profiles[index] = RepositoryProfile(
        id: practice.id,
        displayName: practice.displayName,
        avatarStudentId: practice.avatarStudentId,
        revision: revision,
        selected: practice.selected,
        isPractice: true,
      );
      return _mockPracticeState().toWire();
    }),
  );

  @override
  Future<PracticeEndResult> endPractice(PracticeEndRequest request) async =>
      PracticeEndResult.fromWire(
        _mockPracticeCall('repository.practice.end', request.toWire(), () {
          if (_mockPracticeDeleted.contains(request.profileId)) {
            return PracticeEndResult(
              deletedProfileId: request.profileId,
              selectedProfileId: _mockSelectedProfileId,
              alreadyDeleted: true,
            ).toWire();
          }
          _requireMockPractice(request.profileId, request.expectedRevision);
          final deleted = _removeMockPractice()!;
          return PracticeEndResult(
            deletedProfileId: deleted,
            selectedProfileId: _mockSelectedProfileId,
            alreadyDeleted: false,
          ).toWire();
        }),
      );

  @override
  Future<PracticeRecoveryResult> recoverPractice(
    PracticeRecoverRequest request,
  ) async => PracticeRecoveryResult.fromWire(
    _mockPracticeCall('repository.practice.recover', request.toWire(), () {
      final removed = _removeMockPractice();
      return PracticeRecoveryResult(
        removedProfileIds: [?removed],
        selectedProfileId: _mockSelectedProfileId,
      ).toWire();
    }),
  );

  /// 가상 세션 재생: 기존 이벤트 모양(progress · feedback · candidate · terminal)을 FB-10a 안전 지점마다 하나씩 낸다.
  void _startMockPracticeReplay(
    ScannerSession session,
    InventoryScanProfile? inventoryScanProfile,
  ) {
    final steps = tutorialPracticeReplay(
      session,
      inventoryScanProfile: inventoryScanProfile,
    );
    bool closed() =>
        _scannerTerminals.containsKey(session.id) ||
        _scannerCancelRequested.contains(session.id);
    _startMockScannerReplay(session, [
      for (var index = 0; index <= steps.length; index += 1)
        () {
          if (closed()) return;
          final step = index < steps.length ? steps[index] : null;
          switch (step) {
            case TutorialReplayProgress():
              _emitScannerEvent(session, ScannerEventKind.progress, {
                'current': step.current,
                'total': step.total,
                'message_key': step.messageKey,
              });
              final studentId = step.feedbackStudentId;
              if (studentId != null) {
                _emitScannerEvent(session, ScannerEventKind.feedback, {
                  'student_id': studentId,
                  'field': 'student_id',
                  'values': <String, dynamic>{},
                });
              }
            case TutorialReplayCandidate(:final candidate):
              _scannerCandidates['${session.id}:${candidate.id}'] = candidate;
              _emitScannerEvent(session, ScannerEventKind.candidate, {
                'candidate': _candidateWire(candidate),
              });
            case null:
              _emitTerminal(session, 'completed');
          }
        },
    ]);
  }

  /// 진짜 계정 ↔ 임시 계정 교차 적용 거부(계약): 임시 계정 세션은 그 임시 계정에만, 임시 계정에는 그 세션만 적용한다.
  /// reset · end로 무효가 된 세션은 적용하지 않는다.
  void _requireMockPracticeScope(ScannerSession session, String profileId) {
    if (_invalidatedScannerSessions.contains(session.id)) {
      throw StateError('session_not_found');
    }
    final owner = _scannerSessionProfiles[session.id];
    bool practiceId(String? id) =>
        id != null &&
        (id == _mockPracticeProfile?.id || _mockPracticeDeleted.contains(id));
    if ((practiceId(owner) || practiceId(profileId)) && owner != profileId) {
      throw _practiceError(
        'practice_profile_required',
        'scan candidates cannot cross between practice and real profiles',
      );
    }
  }

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async {
    _requireNotDeletedProfile(profileId);
    return RepositoryState.fromWire(_ensureMockRepositoryPlan(profileId));
  }

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

  // ---- FB-10b 확인 필요 표시(백엔드 profile 안 private `inventory_review` v1) ----
  // 계정마다 저장된 메타 원본(`{version, needs_review_keys}`)을 든다. 없으면 표시 없음(sparse). 수량·이력과
  // 따로 두고, 계정 삭제 때 함께 지운다. 스캔: 승인 key 해제·인식했지만 뺀 key 표시(수량은 만들지 않음).
  // 수동: scope key만 해제(scope 없으면 실제 수량이 바뀐 key만). 그 밖의 쓰기(목표·학생·unattributed)는 손대지 않는다.
  final Map<String, Object?> _mockInventoryReviews = {};

  /// 테스트 주입: 저장된 표시 메타를 원본 그대로 둔다(모르는 버전·깨진 모양 재현). null이면 지운다.
  @visibleForTesting
  void debugSetInventoryReviewMetadata(String profileId, Object? metadata) {
    if (metadata == null) {
      _mockInventoryReviews.remove(profileId);
    } else {
      _mockInventoryReviews[profileId] = jsonDecode(jsonEncode(metadata));
    }
  }

  /// 저장된 표시(정렬된 정규 key). 모르는 버전은 `migration_required`, 깨진 모양은 `corrupt_data`(빈 목록으로
  /// 바꾸지 않는다).
  List<String> _mockReviewKeys(String profileId) {
    if (!_mockInventoryReviews.containsKey(profileId)) return const [];
    final raw = _mockInventoryReviews[profileId];
    if (raw is! Map ||
        raw.length != 2 ||
        !raw.containsKey('version') ||
        !raw.containsKey('needs_review_keys') ||
        raw['version'] is! int) {
      throw BackendRemoteException(
        code: 'corrupt_data',
        message: 'profile contains invalid repository data',
        details: const {'reason': 'invalid_inventory_review'},
      );
    }
    if (raw['version'] != 1) {
      throw BackendRemoteException(
        code: 'migration_required',
        message: 'Inventory review version is unsupported',
        details: const {'reason': 'unsupported_version'},
      );
    }
    final stored = raw['needs_review_keys'];
    try {
      final keys = repositoryInventoryAppliedKeys(stored);
      if (!listEquals<Object?>(keys, stored as List)) {
        throw const FormatException('Stored review keys must be sorted');
      }
      return keys;
    } on FormatException {
      throw BackendRemoteException(
        code: 'corrupt_data',
        message: 'profile contains invalid repository data',
        details: const {'reason': 'invalid_inventory_review'},
      );
    }
  }

  /// 표시를 쓴다. 표시가 없던 계정은 빈 목록을 새로 만들지 않는다(백엔드와 같은 sparse 규칙).
  void _storeMockReview(String profileId, Iterable<String> keys) {
    final sorted = repositoryInventoryAppliedKeys(keys.toList());
    if (_mockInventoryReviews.containsKey(profileId) || sorted.isNotEmpty) {
      _mockInventoryReviews[profileId] = {
        'version': 1,
        'needs_review_keys': sorted,
      };
    }
  }

  @override
  Future<RepositoryInventoryReview> loadRepositoryInventoryReview(
    String profileId,
  ) async {
    final request = RepositoryInventoryReviewRequest(profileId);
    _requireNotDeletedProfile(request.profileId);
    if (!_profiles.any((item) => item.id == request.profileId)) {
      throw StateError('profile_not_found');
    }
    // 읽기는 계획 이관·빈 표시 쓰기를 하지 않는다(그 revision 그대로).
    return RepositoryInventoryReview.fromWireFor(request.profileId, {
      'version': 1,
      'profile_id': request.profileId,
      'revision': _mockRepositoryState(request.profileId)['revision'] as int,
      'needs_review_keys': _mockReviewKeys(request.profileId),
    });
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
      isPractice: old.isPractice,
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

  // FB-6: 전술 v2 기록·족보 쓰기와 명시적 v7-v1 이관(mock_tactical_v2_writes.dart). v1 기록은 위 Mock v1
  // 상태를 그대로 읽고, 이관 뒤 v1 새 쓰기는 `tactical_v1_read_only`. Mock에는 v2 로비·공유가 없고, 통계·추이·추천은
  // FE9-b1 Mock 읽기(mock_tactical_v2_reads.dart)가 같은 strict DTO로 준다.
  late final _tacticalV2 = MockTacticalV2Writes(
    legacyState: _tactical,
    clock: _historyClock,
  );

  @override
  Future<TacticalEvidenceState> loadTacticalEvidenceState(
    String profileId,
  ) async => _tacticalV2.state(profileId);

  @override
  Future<TacticalMatchUpsertResult> upsertTacticalMatchV2({
    required String profileId,
    required TacticalMatchInputV2 match,
    required int expectedRevision,
    required String idempotencyKey,
  }) async => _tacticalV2.upsertMatch(
    profileId: profileId,
    match: match,
    expectedRevision: expectedRevision,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<TacticalMatchDeleteResult> deleteTacticalMatchV2({
    required String profileId,
    required String matchId,
    required int expectedRevision,
    required String idempotencyKey,
  }) async => _tacticalV2.deleteMatch(
    profileId: profileId,
    matchId: matchId,
    expectedRevision: expectedRevision,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<TacticalJokboUpsertResult> upsertTacticalJokboV2({
    required String profileId,
    required TacticalJokboInputV2 jokbo,
    required int expectedRevision,
    required String idempotencyKey,
  }) async => _tacticalV2.upsertJokbo(
    profileId: profileId,
    jokbo: jokbo,
    expectedRevision: expectedRevision,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<TacticalJokboDeleteResult> deleteTacticalJokboV2({
    required String profileId,
    required String jokboId,
    required int expectedRevision,
    required String idempotencyKey,
  }) async => _tacticalV2.deleteJokbo(
    profileId: profileId,
    jokboId: jokboId,
    expectedRevision: expectedRevision,
    idempotencyKey: idempotencyKey,
  );

  @override
  Future<TacticalLegacyPreview> previewTacticalLegacyMigration(
    String profileId,
  ) async => _tacticalV2.preview(profileId);

  @override
  Future<TacticalLegacyCommitResult> commitTacticalLegacyMigration({
    required String profileId,
    required int expectedSourceRevision,
    required String expectedFingerprint,
    required int expectedRevision,
    required String idempotencyKey,
  }) async => _tacticalV2.commit(
    profileId: profileId,
    expectedSourceRevision: expectedSourceRevision,
    expectedFingerprint: expectedFingerprint,
    expectedRevision: expectedRevision,
    idempotencyKey: idempotencyKey,
  );

  // FB-7: 엑셀·CSV 가져오기 Mock(mock_tactical_v2_excel.dart, CSV 한 형식 최소 의미). 파일을 읽지 않고
  // debugSetTacticalExcelSource로 넣은 행을 그 경로의 CSV로 쓴다. 같은 v2 저장·revision·idempotency를 쓴다.
  late final _tacticalExcel = MockTacticalV2Excel(_tacticalV2);

  /// [sourcePath]에 CSV 행(머리글 포함)을 둔다. null이면 지운다(원본 파일 삭제).
  @visibleForTesting
  void debugSetTacticalExcelSource(
    String sourcePath,
    List<List<String>>? rows,
  ) => _tacticalExcel.setSource(sourcePath, rows);

  @override
  Future<TacticalExcelPreview> previewTacticalExcelImport(
    TacticalExcelImportChoices choices,
  ) async => _tacticalExcel.preview(choices);

  @override
  Future<TacticalExcelCommitResult> commitTacticalExcelImport({
    required TacticalExcelImportChoices choices,
    required bool saveRules,
    required String expectedFingerprint,
    required String expectedInterpretationFingerprint,
    required int expectedRevision,
    required String idempotencyKey,
  }) async => _tacticalExcel.commit(
    choices: choices,
    saveRules: saveRules,
    expectedFingerprint: expectedFingerprint,
    expectedInterpretationFingerprint: expectedInterpretationFingerprint,
    expectedRevision: expectedRevision,
    idempotencyKey: idempotencyKey,
  );

  // FE9-b1: 좁은 읽기 capability(TacticalEvidenceReadService). 요청은 Process와 같은 검사를 거친다.
  @override
  Future<TacticalStatisticsResult> queryTacticalStatistics(
    String profileId,
    TacticalStatsFilters filters,
  ) async {
    checkedTacticalV2Request('tactical.v2.stats.query', {
      'profile_id': profileId,
      'filters': filters.toWire(),
    });
    return TacticalStatisticsResult.fromWire(
      mockTacticalStatisticsWire(_tacticalV2.state(profileId), filters),
    );
  }

  @override
  Future<TacticalTrendsResult> queryTacticalTrends(
    String profileId,
    TacticalTrendFilters filters,
  ) async {
    checkedTacticalV2Request('tactical.v2.trends.query', {
      'profile_id': profileId,
      'filters': filters.toWire(),
    });
    return TacticalTrendsResult.fromWire(
      mockTacticalTrendsWire(_tacticalV2.state(profileId), filters),
    );
  }

  @override
  Future<TacticalRecommendationResult> queryTacticalRecommendations(
    String profileId,
    TacticalRecommendationFilters filters,
  ) async {
    checkedTacticalV2Request('tactical.v2.recommend.query', {
      'profile_id': profileId,
      'filters': filters.toWire(),
    });
    return TacticalRecommendationResult.fromWire(
      mockTacticalRecommendationsWire(_tacticalV2.state(profileId), filters),
    );
  }

  TacticalState _tactical(String profileId) {
    _requireNotDeletedProfile(profileId);
    return _tacticalStates[profileId] ??
        TacticalState(
          profileId: profileId,
          revision: 0,
          matches: const [],
          jokbo: const [],
        );
  }
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
    _tacticalV2.requireV1Writable(profileId);
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
    _tacticalV2.requireV1Writable(profileId);
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
    _tacticalV2.requireV1Writable(profileId);
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
    _tacticalV2.requireV1Writable(profileId);
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
    String idempotencyKey, {
    List<String>? appliedResourceKeys,
  }) async {
    // FB-10b scope는 쓰기·캐시 앞에서 검사한다(상한·빈 key = invalid_inventory_review, 별칭 중복 = duplicate_identity).
    List<String>? scope;
    if (appliedResourceKeys != null) {
      try {
        scope = repositoryInventoryAppliedKeys(appliedResourceKeys);
      } on FormatException catch (error) {
        throw BackendRemoteException(
          code: 'invalid_payload',
          message: error.message,
          details: {
            'reason': error.message == 'Duplicate canonical review identity'
                ? 'duplicate_identity'
                : 'invalid_inventory_review',
          },
        );
      }
    }
    return _saveMockCurrent(profileId, 'inventory', inventory.toWire(), expectedRevision, idempotencyKey,
      appliedResourceKeys: scope);
  }

  /// 수동 저장의 확인 필요 전이(백엔드 `inventory_review.transition` manual). scope가 없으면 실제로 수량이 바뀐
  /// key만 해제한다. scope key는 before·after에 있는 항목이어야 하고, 바뀐 key는 모두 scope 안이어야 한다(아니면
  /// `invalid_payload` + `scan_scope_mismatch`).
  Set<String> _mockManualReview(String profileId, RepositoryState before,
    RepositoryState after, List<String>? scope) {
    Map<String, Object?> quantities(RepositoryState state) => {
      for (final entry in state.inventory.entries)
        historyCanonicalResourceKey((entry['item_id'] ?? entry['key']) as String):
            entry['quantity'],
    };
    final old = quantities(before);
    final next = quantities(after);
    final identities = {...old.keys, ...next.keys};
    final changed = {
      for (final key in identities)
        if (!old.containsKey(key) || !next.containsKey(key) || old[key] != next[key]) key,
    };
    final applied = scope?.toSet() ?? changed;
    if (!identities.containsAll(applied) || !applied.containsAll(changed)) {
      throw BackendRemoteException(
        code: 'invalid_payload',
        message: 'Manual quantities changed outside explicit applied identities',
        details: const {'reason': 'scan_scope_mismatch'},
      );
    }
    return _mockReviewKeys(profileId).toSet()..removeAll(applied);
  }

  int _saveMockCurrent(String profileId, String bucket, Object value,
    int expectedRevision, String idempotencyKey, {List<String>? appliedResourceKeys}) {
    if (!_profiles.any((item) => item.id == profileId)) throw StateError('profile_not_found');
    if (expectedRevision < 0 || idempotencyKey.isEmpty) throw const FormatException('invalid_payload');
    final current = _ensureMockRepositoryPlan(profileId);
    final next = <String, dynamic>{...current, 'revision': expectedRevision + 1, bucket: value};
    final after = RepositoryState.fromWire(next);
    // FB-10b: scope가 있는 요청은 scope까지 fingerprint에 넣는다(같은 key·다른 scope = idempotency_conflict).
    final operation = appliedResourceKeys == null
        ? '$bucket:${historyCanonicalJson(value)}'
        : '$bucket-manual-scope-v1:${historyCanonicalJson({'current': value, 'applied_resource_keys': appliedResourceKeys})}';
    final fingerprint = historyCanonicalJson({'operation': operation, 'expected_revision': expectedRevision});
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
    final reviewKeys = bucket == 'inventory'
        ? _mockManualReview(profileId, before, after, appliedResourceKeys)
        : null;
    final history = _currentHistories[profileId] ?? RepositoryCurrentHistory.empty(legacy: before);
    final updated = history.appendManual(before, after, bucket, _historyClock());
    _manualMockCurrentWrite = true;
    try {
      _repositoryStates[profileId] = next;
    } finally {
      _manualMockCurrentWrite = false;
    }
    _currentHistories[profileId] = updated;
    if (reviewKeys != null) _storeMockReview(profileId, reviewKeys);
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
    await assetPreparationMock.dispose();
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

  /// SU2: 켜면 시작 probe가 이관 실패로 끝난 것처럼 연결 끊김 + 실패, 끄면(원인 해결) 실패를 비우고 연결됨으로 돌아간다.
  @override
  void setUserDataMigrationFailure(UserDataMigrationReason? reason) {
    if (reason == null && _state.value.userDataMigrationFailure == null) return;
    _state.value = reason == null
        ? _state.value.copyWith(
            connection: BackendConnection.connected,
            clearUserDataMigrationFailure: true,
          )
        : _state.value.copyWith(
            connection: BackendConnection.disconnected,
            userDataMigrationFailure: UserDataMigrationFailure(
              reason: reason,
              message: mockUserDataMigrationFailureMessage,
            ),
          );
    _recordLifecycle(
      'scenario user_data_migration_failed=${reason?.wire ?? 'off'}',
    );
    _syncDiagnostics();
  }

  BackendRemoteException _userDataMigrationError(
    UserDataMigrationFailure failure,
  ) => BackendRemoteException(
    code: userDataMigrationFailedCode,
    message: failure.message,
    details: failure.toWireDetails(),
  );
}

class _MockFrozenScanCommit {
  _MockFrozenScanCommit({
    required this.bucket,
    required this.currentJson,
    required this.scanKind,
    required this.inventoryScanProfile,
    required this.context,
    required this.appliedKeys,
    this.excludedKeys = const [],
    required this.provenance,
  });
  final String bucket;
  final String currentJson;
  final String scanKind;
  final String? inventoryScanProfile;
  final Map<String, dynamic> context;
  final List<String> appliedKeys;

  /// FB-10b: 인식했지만 승인에서 뺀 정규 key(이전 수량 + 확인 필요). 서버 내부 값이라 이력·RPC에 남지 않는다.
  final List<String> excludedKeys;
  final String provenance;
}

/// 세션 하나의 Mock 스캔 재생(F3c-8): 단계 목록과 다음에 할 단계(커서).
class _MockScannerReplay {
  _MockScannerReplay(this.steps);
  final List<void Function()> steps;
  int next = 0;
}

class _MockScanCommitReceipt {
  _MockScanCommitReceipt(this.publicRequest, this.frozen);
  final String publicRequest;
  _MockFrozenScanCommit? frozen;
  Map<String, dynamic>? response;
}
