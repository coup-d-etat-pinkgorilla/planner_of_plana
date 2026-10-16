import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scanner_review_images.dart';
import '../../services/scanner_service.dart';
import '../../services/student_scan_diagnostic.dart';
import '../../services/window_dock_service.dart';
import '../kit/kit_overlay.dart' show KitOverlayEscape;
import '../scan/connected_target_controller.dart';
import '../scan/scan_repository_sync.dart';
import '../widgets/account_section_cluster.dart'
    show repositoryLoadErrorText, repositoryProfileWithRevision;
import '../widgets/diagonal_section.dart';
import '../widgets/repository_profile_panel.dart';
import '../widgets/scan_companion_dock.dart';
import '../widgets/scan_inventory_identity_review.dart';
import '../widgets/scan_student_review_workspace.dart';

enum _SessionStage { idle, starting, running, cancelling, terminal }

class ScanPage extends StatefulWidget {
  const ScanPage({
    super.key,
    required this.service,
    required this.onCandidateHandoff,
    this.onRecentChanged,
    this.onCompanionChanged,
    this.windowDockService = const WindowsWindowDockService(),
    this.studentScanDiagnosticFileService =
        const NativeStudentScanDiagnosticFileService(),
    this.now = DateTime.now,
    this.active = true,
    this.connectedTarget,
  });

  final AppService service;
  final void Function(ScannerSession session, ScannerCandidate candidate)
  onCandidateHandoff;
  final ValueChanged<List<ScannerRecentSummary>>? onRecentChanged;
  final ValueChanged<ScanCompanionState?>? onCompanionChanged;
  final WindowDockService windowDockService;
  final StudentScanDiagnosticFileService studentScanDiagnosticFileService;
  final DateTime Function() now;

  /// 스캔 탭이 보이는가. 보일 때만 Esc가 진행 중(일시정지 포함) 스캔을 중지한다(FD-142, fb10a-dart).
  final bool active;

  /// 앱 전역 게임 창 연결(FE8-d). 있으면 대상 창 선택은 이 값을 읽고 쓴다. 없으면 이 화면만의 선택이다.
  final ConnectedTargetController? connectedTarget;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  ScannerService? get _scanner => widget.service is ScannerService
      ? widget.service as ScannerService
      : null;
  RepositoryService? get _repository => widget.service is RepositoryService
      ? widget.service as RepositoryService
      : null;

  StreamSubscription<ScannerEvent>? _subscription;
  List<ScannerTarget> _targets = const [];
  Map<String, dynamic>? _readiness;
  RepositoryProfile? _profile;
  RepositoryState? _repositoryState;

  /// 다음 적용의 expected revision(권위값). state 응답과 commit 응답에서만 받는다. catalog summary(목록)
  /// revision은 legacy 첫 이관(+1) 전 값일 수 있으므로 쓰지 않는다(FB-1b).
  int? _repositoryRevision;
  final Map<String, ScanPendingApply> _pendingApplies = {};
  int _applyIntentSequence = 0;
  Future<void> _applyQueue = Future<void>.value();
  Map<String, StudentCatalogEntry> _studentCatalog = const {};
  List<InventoryCatalogEntry> _inventoryCatalog = const [];
  String? _targetId;
  ScannerKind _kind = ScannerKind.student;
  StudentScanMode _studentScanMode = StudentScanMode.single;
  InventoryScanProfile _inventoryScanProfile = InventoryScanProfile.techNotes;
  bool _targetsLoading = true;
  bool _readinessLoading = true;
  bool _recovering = false;
  String? _targetError;
  String? _readinessError;
  String? _sessionError;

  _SessionStage _stage = _SessionStage.idle;
  ScannerSession? _session;
  final List<ScannerEvent> _pendingStartEvents = [];
  String? _phase;
  int? _progressCurrent;
  int? _progressTotal;
  String? _messageKey;
  String? _diagnostic;
  String? _outcome;
  Map<String, dynamic>? _terminalError;
  final Map<String, ScannerCandidate> _candidates = {};
  final List<ScannerRecentSummary> _recent = [];
  final Set<String> _busyCandidateIds = {};
  final Map<String, String> _candidateErrors = {};
  final Map<String, List<ScannerUnresolvedSlot>> _unresolvedSlots = {};
  final Set<String> _unresolvedLoading = {};
  final Set<String> _identityBusy = {};
  final Set<String> _identitySkipped = {};
  final Map<String, String> _identityErrors = {};
  String? _candidateNotice;
  bool _companionActive = false;
  bool _exportingStudentDiagnostic = false;

  /// FB-10a 세션 제어(진행 단계 안의 하위 상태). pause 응답의 `pauseRequested`는 수락일 뿐이고,
  /// `paused` 이벤트를 받아야 멈춘 것으로 본다.
  ScannerControlState _control = ScannerControlState.running;
  ScannerPauseReason? _pauseReason;
  bool _controlBusy = false;
  bool _escapeRegistered = false;

  bool get _connected =>
      widget.service.state.value.connection == BackendConnection.connected;
  bool get _recognitionReady => _readiness?['ready'] == true;
  ScannerTarget? get _selectedTarget {
    for (final target in _targets) {
      if (target.id == _targetId) return target;
    }
    return null;
  }

  bool get _canStart =>
      _connected &&
      _scanner != null &&
      _repository != null &&
      _profile != null &&
      _recognitionReady &&
      _selectedTarget?.status == ScannerTargetStatus.ready &&
      (_stage == _SessionStage.idle || _stage == _SessionStage.terminal);

  bool get _canExportStudentDiagnostic =>
      !_exportingStudentDiagnostic &&
      _stage == _SessionStage.terminal &&
      _outcome == 'completed' &&
      _session?.kind == ScannerKind.student &&
      _repository != null &&
      _profile != null &&
      _candidates.values.any((item) => item.kind == ScannerKind.student);

  @override
  void initState() {
    super.initState();
    widget.service.state.addListener(_connectionChanged);
    final connectedTarget = widget.connectedTarget;
    if (connectedTarget != null) {
      connectedTarget.addListener(_connectedTargetChanged);
      _adoptConnectedTarget();
    }
    final scanner = _scanner;
    if (scanner != null) {
      _subscription = scanner.scannerEvents.listen(
        _handleEvent,
        onError: _handleStreamError,
      );
    }
    _refreshPreparation();
  }

  @override
  void dispose() {
    KitOverlayEscape.remove(this);
    if (_companionActive) unawaited(widget.windowDockService.restore());
    widget.service.state.removeListener(_connectionChanged);
    widget.connectedTarget?.removeListener(_connectedTargetChanged);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ScanPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.connectedTarget, widget.connectedTarget)) return;
    oldWidget.connectedTarget?.removeListener(_connectedTargetChanged);
    widget.connectedTarget?.addListener(_connectedTargetChanged);
    if (widget.connectedTarget != null) _adoptConnectedTarget();
  }

  /// 앱 전역 연결 대상(FE8-d)을 이 화면의 선택으로 받는다. 목록에 없으면 넣고, 같은 id면 새 창 정보로 바꾼다.
  void _adoptConnectedTarget() {
    final connected = widget.connectedTarget?.target;
    _targetId = connected?.id;
    if (connected == null) return;
    final index = _targets.indexWhere((item) => item.id == connected.id);
    if (index < 0) {
      _targets = [..._targets, connected];
    } else {
      _targets = [..._targets]..[index] = connected;
    }
  }

  void _connectedTargetChanged() {
    if (!mounted) return;
    setState(_adoptConnectedTarget);
  }

  /// 드롭다운에서 고른 창. 앱 전역 연결이 있으면 그 창에 연결하고, 화면 선택은 리스너가 맞춘다.
  void _chooseTarget(String? targetId) {
    final connectedTarget = widget.connectedTarget;
    final target = _targets.where((item) => item.id == targetId).firstOrNull;
    if (connectedTarget == null || target == null) {
      setState(() => _targetId = targetId);
      return;
    }
    connectedTarget.connect(target);
  }

  /// 최근 기록을 열 때 고를 창. 앱 전역 연결이 있으면 기록의 창이 목록에 있을 때 그 창에 연결하고,
  /// 없으면 지금 연결을 그대로 둔다(기록의 창이 사라졌다고 지금 연결을 끊지 않는다).
  String? _recentTargetId(ScannerRecentSummary item) {
    final target = _targets
        .where((candidate) => candidate.id == item.targetId)
        .firstOrNull;
    final connectedTarget = widget.connectedTarget;
    if (connectedTarget == null) return target?.id;
    if (target != null) connectedTarget.connect(target);
    return connectedTarget.target?.id;
  }

  void _connectionChanged() {
    if (!mounted) return;
    setState(() {
      if (!_connected &&
          (_stage == _SessionStage.running ||
              _stage == _SessionStage.cancelling)) {
        _sessionError =
            'Backend disconnected. Reconnect, then recover the active snapshot.';
      }
    });
  }

  Future<void> _refreshPreparation() async {
    final scanner = _scanner;
    if (scanner == null) {
      setState(() {
        _targetsLoading = false;
        _readinessLoading = false;
        _targetError = 'Scanner service is unavailable.';
        _readinessError = 'Scanner service is unavailable.';
      });
      return;
    }
    setState(() {
      _targetsLoading = true;
      _readinessLoading = true;
      _targetError = null;
      _readinessError = null;
    });
    try {
      final readiness = await scanner.scannerReadiness();
      if (readiness['ready'] is! bool ||
          readiness['missing'] is! List ||
          readiness['corrupt'] is! List) {
        throw const FormatException('Invalid recognition readiness');
      }
      if (mounted) setState(() => _readiness = readiness);
    } catch (error) {
      if (mounted) {
        setState(() => _readinessError = 'Readiness failed: $error');
      }
    } finally {
      if (mounted) setState(() => _readinessLoading = false);
    }
    try {
      final targets = await scanner.listScannerTargets();
      if (!mounted) return;
      widget.connectedTarget?.updateTargets(targets);
      setState(() {
        _targets = targets;
        if (!targets.any((item) => item.id == _targetId)) _targetId = null;
      });
    } catch (error) {
      if (mounted) setState(() => _targetError = 'Target list failed: $error');
    } finally {
      if (mounted) setState(() => _targetsLoading = false);
    }
  }

  Future<void> _selectProfile(RepositoryProfile profile) async {
    final repository = _repository;
    final profileChanged = _profile?.id != profile.id;
    // 위 계정 패널은 목록(ListView)이 화면 밖으로 밀어내면 버려졌다가 다시 만들어지며, 그때마다 같은 계정을 다시
    // 넘긴다. 이미 이 계정의 state와 그 이상인 권위 revision이 있으면 다시 읽지 않는다(이름 등 표시만 받는다).
    // 목록 revision이 더 높을 때(다른 곳의 저장·이름 변경)만 다시 읽는다.
    final known = profileChanged ? null : _repositoryRevision;
    final current =
        !profileChanged &&
        _repositoryState != null &&
        known != null &&
        profile.revision <= known;
    setState(() {
      if (profileChanged) {
        _profile = profile;
        _repositoryRevision = null;
        _repositoryState = null;
        _pendingApplies.clear();
        _candidateNotice = null;
      } else {
        // 같은 계정을 목록이 다시 넘기면 이름 등 표시만 받고 revision은 권위값(state·commit 응답)을 유지한다.
        // 목록 값이 더 높으면 아래에서 state를 다시 읽어 맞춘다.
        _profile = known != null
            ? repositoryProfileWithRevision(profile, known)
            : profile;
      }
    });
    if (repository == null || current) return;
    try {
      final results = await Future.wait<Object>([
        retryRepositoryBusy(() => repository.loadRepositoryState(profile.id)),
        widget.service.listStudents(),
        widget.service.listInventoryItems(),
      ]);
      if (!mounted || _profile?.id != profile.id) return;
      final state = results[0] as RepositoryState;
      final catalog = results[1] as List<StudentCatalogEntry>;
      final inventoryCatalog = results[2] as InventoryCatalogResult;
      setState(() {
        _acceptRepositoryState(state);
        _studentCatalog = {for (final item in catalog) item.studentId: item};
        _inventoryCatalog = inventoryCatalog.items;
      });
    } catch (error) {
      if (mounted && _profile?.id == profile.id) {
        final failure =
            '프로필 현재값을 다시 읽지 못했습니다: ${repositoryLoadErrorText(error)}';
        setState(() {
          final previous = _candidateNotice;
          // 같은 계정 재선택의 실패는 직전 안내(적용 결과 등)를 지우지 않고 뒤에 덧붙인다. 처음 고른 계정이면
          // 기존 문구 그대로 바꾼다. 이미 같은 실패를 덧붙였으면 다시 붙이지 않는다.
          _candidateNotice = profileChanged || previous == null
              ? '프로필 현재값을 불러오지 못했습니다: ${repositoryLoadErrorText(error)}'
              : previous.endsWith(failure)
              ? previous
              : '$previous\n$failure';
        });
      }
    }
  }

  /// state 응답을 cache·권위 revision·profile 표시에 반영한다(setState 안에서 부른다). 같은 계정의 더 낮은
  /// revision 응답(늦게 도착한 이전 읽기)은 버린다. 반영했으면 true.
  bool _acceptRepositoryState(RepositoryState state) {
    final profile = _profile;
    if (profile == null || state.profileId != profile.id) return false;
    final known = _repositoryRevision;
    if (known != null && state.revision < known) return false;
    _repositoryState = state;
    _repositoryRevision = state.revision;
    _profile = repositoryProfileWithRevision(profile, state.revision);
    return true;
  }

  /// commit 응답 revision을 권위값으로 받는다(setState 안에서 부른다). state를 다시 읽지 못해도 다음 순차
  /// 적용이 이 값을 expected로 쓴다(FD-144).
  void _acceptCommittedRevision(String profileId, int revision) {
    final profile = _profile;
    if (profile == null || profile.id != profileId) return;
    final known = _repositoryRevision;
    if (known != null && revision <= known) return;
    _repositoryRevision = revision;
    _profile = repositoryProfileWithRevision(profile, revision);
  }

  /// [profileId]의 state를 다시 읽어 반영한다(busy면 같은 읽기를 backoff 재시도). 실패하면 오류를 던진다.
  Future<RepositoryState?> _reloadRepositoryState(String profileId) async {
    final repository = _repository;
    if (repository == null) return null;
    final state = await retryRepositoryBusy(
      () => repository.loadRepositoryState(profileId),
    );
    if (mounted && _profile?.id == profileId) {
      setState(() => _acceptRepositoryState(state));
    }
    return state;
  }

  Future<void> _start() async {
    final scanner = _scanner;
    final target = _selectedTarget;
    if (!_canStart || scanner == null || target == null) return;
    setState(() {
      _stage = _SessionStage.starting;
      _session = null;
      _sessionError = null;
      _pendingStartEvents.clear();
      _resetProjection();
      _control = ScannerControlState.running;
      _pauseReason = null;
    });
    // 세션의 첫 적용 base revision: 시작 직전 state를 다시 읽어 권위값을 맞춘다. 읽지 못하면 이미 받은 값을
    // 그대로 쓰고 알린다(적용은 revision_conflict 재조회로 다시 맞춘다).
    final baseProfileId = _profile?.id;
    if (baseProfileId != null) {
      try {
        await _reloadRepositoryState(baseProfileId);
      } catch (error) {
        if (mounted && _profile?.id == baseProfileId) {
          setState(
            () => _candidateNotice =
                '스캔 시작 전 현재값을 다시 읽지 못했습니다: ${repositoryLoadErrorText(error)}',
          );
        }
      }
      if (!mounted) return;
    }
    try {
      if (_kind == ScannerKind.student &&
          _studentScanMode == StudentScanMode.full) {
        await widget.windowDockService.dockBeside(target.id);
        if (!mounted) {
          await widget.windowDockService.restore();
          return;
        }
        _companionActive = true;
        _publishCompanion();
      }
      final session = await scanner.startScannerSession(
        _kind,
        target.id,
        profileId: _profile?.id,
        studentScanMode: _studentScanMode,
        inventoryScanProfile: _kind == ScannerKind.inventory
            ? _inventoryScanProfile
            : null,
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _stage = _SessionStage.running;
        final buffered = List<ScannerEvent>.from(_pendingStartEvents);
        _pendingStartEvents.clear();
        for (final event in buffered) {
          if (event.sessionId == session.id &&
              event.generation == session.generation) {
            _applyEvent(event);
          }
        }
      });
      _publishCompanion();
    } catch (error) {
      if (_companionActive) await _closeCompanion();
      if (mounted) {
        setState(() {
          _stage = _SessionStage.idle;
          _sessionError = 'Could not start scan: $error';
        });
      }
    }
  }

  Future<void> _cancel() async {
    final scanner = _scanner;
    final session = _session;
    if (scanner == null || session == null || _stage != _SessionStage.running) {
      return;
    }
    setState(() {
      _stage = _SessionStage.cancelling;
      _sessionError = null;
    });
    _publishCompanion();
    try {
      await scanner.cancelScannerSession(session);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        setState(() {
          _stage = _SessionStage.running;
          _sessionError = 'Cancel request failed: $error';
        });
      }
    }
  }

  /// FB-10a 일시정지 요청. 응답이 `pauseRequested`면 "멈추는 중"으로 두고, 실제 멈춤은 `paused` 이벤트로 바꾼다.
  /// `paused` 이벤트가 응답보다 먼저 와도 상태를 되돌리지 않는다.
  Future<void> _pause() async {
    final scanner = _scanner;
    final session = _session;
    if (scanner == null ||
        session == null ||
        _stage != _SessionStage.running ||
        _control != ScannerControlState.running ||
        _controlBusy) {
      return;
    }
    setState(() {
      _controlBusy = true;
      _sessionError = null;
    });
    _publishCompanion();
    try {
      final control = await scanner.pauseScannerSession(session);
      if (!mounted || !identical(_session, session)) return;
      setState(() {
        if (_stage != _SessionStage.running ||
            _control != ScannerControlState.running) {
          return;
        }
        if (control.controlState == ScannerControlState.pauseRequested ||
            control.controlState == ScannerControlState.paused) {
          _control = control.controlState;
          _pauseReason = control.reason;
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _sessionError = '일시정지 요청이 실패했습니다: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _controlBusy = false);
        _publishCompanion();
      }
    }
  }

  /// FB-10a 이어서. 받아들여지면 `resumed` 이벤트와 함께 진행으로 돌아간다. 대상 창이 준비되지 않아 거절되면
  /// 일시정지에 남고 사유만 바꾼다(이벤트 없이 응답으로만 온다).
  Future<void> _resume() async {
    final scanner = _scanner;
    final session = _session;
    if (scanner == null ||
        session == null ||
        _stage != _SessionStage.running ||
        _control != ScannerControlState.paused ||
        _controlBusy) {
      return;
    }
    setState(() {
      _controlBusy = true;
      _sessionError = null;
    });
    _publishCompanion();
    try {
      final control = await scanner.resumeScannerSession(session);
      if (!mounted || !identical(_session, session)) return;
      setState(() {
        // 받아들여졌으면 백엔드가 `resumed` 이벤트를 응답보다 먼저 낸다. 진행으로의 전환은 그 이벤트만 따른다
        // (그 사이 새 `paused`가 왔다면 응답으로 덮지 않는다).
        if (_stage != _SessionStage.running || control.accepted) return;
        if (control.controlState == ScannerControlState.paused &&
            _control == ScannerControlState.paused) {
          _pauseReason = control.reason;
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _sessionError = '이어서 요청이 실패했습니다: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _controlBusy = false);
        _publishCompanion();
      }
    }
  }

  /// Esc 처리 등록을 단계에 맞춘다. 탭이 보이고 세션이 진행 중(일시정지 포함)일 때만 Esc = 중지(기존 cancel)다.
  /// 단계는 여러 곳에서 바뀌므로 build마다 맞춘다. 이미 등록돼 있으면 다시 넣지 않는다(뒤에 열린 팝오버의 Esc가 먼저).
  void _syncEscape() {
    final wanted =
        widget.active && _stage == _SessionStage.running && _session != null;
    if (wanted == _escapeRegistered) return;
    _escapeRegistered = wanted;
    if (wanted) {
      KitOverlayEscape.push(this, context, _cancelByEscape);
    } else {
      KitOverlayEscape.remove(this);
    }
  }

  /// [KitOverlayEscape]는 부른 항목을 스스로 지운다.
  void _cancelByEscape() {
    _escapeRegistered = false;
    unawaited(_cancel());
  }

  Future<void> _recoverSnapshot() async {
    final scanner = _scanner;
    final session = _session;
    if (scanner == null || session == null || _recovering) return;
    setState(() {
      _recovering = true;
      _sessionError = null;
    });
    try {
      final snapshot = await scanner.scannerSnapshot(session);
      if (!mounted) return;
      setState(() {
        _resetProjection();
        _stage = _SessionStage.running;
        for (final candidate in snapshot.candidates) {
          _keepCandidate(candidate);
        }
        for (final event in snapshot.events) {
          _applyEvent(event, recordRecent: false);
        }
        if (snapshot.terminal != null && _stage != _SessionStage.terminal) {
          _outcome = snapshot.terminal;
          _stage = _SessionStage.terminal;
        }
        // FB-10a: 이벤트 틈·거절된 이어서의 사유 변경은 snapshot의 제어 상태가 권위값이다.
        _control = snapshot.controlState == ScannerControlState.terminal
            ? ScannerControlState.running
            : snapshot.controlState;
        _pauseReason = snapshot.reason;
        if (_stage == _SessionStage.terminal) _recordRecent();
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _sessionError =
              'Snapshot recovery failed; the previous projection was kept: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _recovering = false);
    }
  }

  Future<void> _exportStudentDiagnostic() async {
    final scanner = _scanner;
    final repository = _repository;
    final profile = _profile;
    final session = _session;
    if (!_canExportStudentDiagnostic ||
        scanner == null ||
        repository == null ||
        profile == null ||
        session == null) {
      return;
    }
    setState(() {
      _exportingStudentDiagnostic = true;
      _candidateNotice = null;
    });
    try {
      final results = await Future.wait<Object>([
        scanner.scannerSnapshot(session),
        retryRepositoryBusy(() => repository.loadRepositoryState(profile.id)),
      ]);
      final generatedAt = widget.now();
      final document = buildStudentScanDiagnosticDocument(
        session: session,
        snapshot: results[0] as ScannerSessionSnapshot,
        repositoryState: results[1] as RepositoryState,
        generatedAt: generatedAt,
      );
      final path = await widget.studentScanDiagnosticFileService.save(
        suggestedName: defaultStudentScanDiagnosticFileName(
          session,
          generatedAt,
        ),
        contents: encodeStudentScanDiagnosticDocument(document),
      );
      if (!mounted || path == null) return;
      setState(() {
        _acceptRepositoryState(results[1] as RepositoryState);
        _candidateNotice = '학생 스캔 진단 파일을 저장했습니다.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _candidateNotice = '학생 스캔 진단 추출 실패: $error');
      }
    } finally {
      if (mounted) setState(() => _exportingStudentDiagnostic = false);
    }
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    if (!mounted || _session == null) return;
    setState(
      () => _sessionError = 'Scanner event stream needs recovery: $error',
    );
    unawaited(_recoverSnapshot());
  }

  void _handleEvent(ScannerEvent event) {
    if (!mounted) return;
    if (_stage == _SessionStage.starting && _session == null) {
      _pendingStartEvents.add(event);
      return;
    }
    final session = _session;
    if (session == null ||
        event.sessionId != session.id ||
        event.generation != session.generation ||
        _stage == _SessionStage.terminal) {
      return;
    }
    setState(() => _applyEvent(event));
    if (_companionActive) {
      _publishCompanion();
      if (event.eventKind == ScannerEventKind.terminal) {
        unawaited(_closeCompanion());
      }
    }
  }

  void _publishCompanion() {
    if (!_companionActive) return;
    final target = _selectedTarget;
    final feedback = _liveStudentFeedback;
    widget.onCompanionChanged?.call(
      ScanCompanionState(
        targetTitle: target?.title ?? target?.id ?? 'Blue Archive',
        modeLabel: '전체 학생',
        stageLabel: _stage.name,
        phase: _phase,
        recognizedCount: _progressCurrent ?? 0,
        progressCurrent: _progressCurrent,
        progressTotal: _progressTotal,
        messageKey: _messageKey,
        student: feedback,
        cancelling: _stage == _SessionStage.cancelling,
        onCancel: _stage == _SessionStage.running
            ? () => unawaited(_cancel())
            : null,
        pausedLabel: _pausedLabel,
        pauseRequested:
            _stage == _SessionStage.running &&
            _control == ScannerControlState.pauseRequested,
        onPause:
            _stage == _SessionStage.running &&
                _control == ScannerControlState.running &&
                !_controlBusy
            ? () => unawaited(_pause())
            : null,
        onResume:
            _stage == _SessionStage.running &&
                _control == ScannerControlState.paused &&
                !_controlBusy
            ? () => unawaited(_resume())
            : null,
      ),
    );
  }

  ScanDockStudentFeedback? get _liveStudentFeedback {
    final studentId = _liveFeedbackStudentId;
    if (studentId == null) return null;
    return ScanDockStudentFeedback(
      studentId: studentId,
      displayName: _studentCatalog[studentId]?.displayName ?? studentId,
    );
  }

  String? _liveFeedbackStudentId;

  Future<void> _closeCompanion() async {
    if (!_companionActive) return;
    _companionActive = false;
    try {
      await widget.windowDockService.restore();
    } finally {
      if (mounted) widget.onCompanionChanged?.call(null);
    }
  }

  void _applyEvent(ScannerEvent event, {bool recordRecent = true}) {
    switch (event.eventKind) {
      case ScannerEventKind.phase:
        _phase = event.payload['phase'] as String?;
        break;
      case ScannerEventKind.progress:
        _progressCurrent = event.payload['current'] as int?;
        _progressTotal = event.payload['total'] as int?;
        _messageKey = event.payload['message_key'] as String?;
        break;
      case ScannerEventKind.feedback:
        final studentId = event.payload['student_id'];
        final field = event.payload['field'];
        if (field == 'student_id' && studentId is String) {
          _liveFeedbackStudentId = studentId;
        }
        break;
      case ScannerEventKind.diagnostic:
        final code = event.payload['code'];
        final message = event.payload['message'];
        _diagnostic = [
          code,
          message,
        ].where((item) => item is String && item.isNotEmpty).join(': ');
        break;
      case ScannerEventKind.candidate:
        final raw = event.payload['candidate'];
        if (raw is Map) {
          _keepCandidate(
            ScannerCandidate.fromWire(Map<String, dynamic>.from(raw)),
          );
        }
        break;
      case ScannerEventKind.paused:
        _control = ScannerControlState.paused;
        _pauseReason = event.pauseReason;
        break;
      case ScannerEventKind.resumed:
        _control = ScannerControlState.running;
        _pauseReason = null;
        break;
      case ScannerEventKind.terminal:
        _outcome = event.payload['outcome'] as String?;
        final error = event.payload['error'];
        _terminalError = error is Map ? Map<String, dynamic>.from(error) : null;
        _stage = _SessionStage.terminal;
        if (recordRecent) _recordRecent();
        break;
    }
  }

  void _keepCandidate(ScannerCandidate candidate) {
    final current = _candidates[candidate.id];
    if (current == null || candidate.revision > current.revision) {
      _candidates[candidate.id] = candidate;
      if (candidate.kind == ScannerKind.inventory &&
          !_unresolvedSlots.containsKey(candidate.id) &&
          !_unresolvedLoading.contains(candidate.id)) {
        unawaited(
          Future<void>.microtask(() => _loadUnresolvedSlots(candidate)),
        );
      }
    }
  }

  String _identitySlotKey(String candidateId, int slot) => '$candidateId:$slot';

  Future<void> _loadUnresolvedSlots(ScannerCandidate candidate) async {
    final scanner = _scanner;
    final session = _sessionFor(candidate);
    if (scanner == null || session == null || !mounted) return;
    setState(() {
      _unresolvedLoading.add(candidate.id);
      _candidateErrors.remove(candidate.id);
    });
    try {
      final result = await scanner.scannerUnresolvedSlots(session, candidate);
      if (!mounted) return;
      final current = _candidates[candidate.id];
      if (current == null || current.revision != result.candidateRevision) {
        return;
      }
      setState(() => _unresolvedSlots[candidate.id] = result.slots);
    } catch (error) {
      if (mounted) {
        setState(() {
          _candidateErrors[candidate.id] = '미식별 슬롯을 불러오지 못했습니다: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _unresolvedLoading.remove(candidate.id));
    }
  }

  Future<void> _assignInventoryIdentity(
    ScannerCandidate candidate,
    ScannerUnresolvedSlot slot,
    String identity,
    bool persist,
  ) async {
    final scanner = _scanner;
    final session = _sessionFor(candidate);
    if (scanner == null || session == null) return;
    final key = _identitySlotKey(candidate.id, slot.slot);
    setState(() {
      _identityBusy.add(key);
      _identityErrors.remove(key);
      _candidateNotice = null;
    });
    try {
      final result = await scanner.assignScannerIdentity(
        session,
        candidate,
        slot: slot.slot,
        identity: identity,
        persist: persist,
      );
      if (!mounted) return;
      setState(() {
        _keepCandidate(result.candidate);
        _unresolvedSlots[candidate.id] = result.slots;
        _identitySkipped.remove(key);
        _identityErrors.remove(key);
        _candidateNotice = persist
            ? '슬롯 ${slot.slot + 1} identity를 영구 승인 샘플로 저장했습니다.'
            : '슬롯 ${slot.slot + 1} identity를 이번 실행의 세션 은행에 추가했습니다.';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _identityErrors[key] = 'identity 지정 실패: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _identityBusy.remove(key));
    }
  }

  Future<void> _skipInventoryIdentity(
    ScannerCandidate candidate,
    ScannerUnresolvedSlot slot,
  ) async {
    setState(() {
      _identitySkipped.add(_identitySlotKey(candidate.id, slot.slot));
      _candidateNotice = '슬롯 ${slot.slot + 1}을 건너뛰었습니다. 후보는 partial 상태로 유지됩니다.';
    });
  }

  ScannerSession? _sessionFor(ScannerCandidate candidate) {
    final active = _session;
    if (active != null &&
        active.id == candidate.sessionId &&
        active.generation == candidate.generation) {
      return active;
    }
    for (final item in _recent) {
      if (item.sessionId == candidate.sessionId &&
          item.generation == candidate.generation) {
        return item.session;
      }
    }
    return null;
  }

  Future<void> _revalidateStudentCandidate(
    ScannerCandidate candidate,
    Map<String, dynamic> payload,
    Map<int, int> relationshipRanks,
    Set<String> confirmedFields,
  ) async {
    final scanner = _scanner;
    final session = _sessionFor(candidate);
    if (scanner == null || session == null) return;
    setState(() {
      _busyCandidateIds.add(candidate.id);
      _candidateErrors.remove(candidate.id);
      _candidateNotice = null;
    });
    try {
      final revised = await scanner.reviewScannerCandidate(
        session,
        candidate,
        payload,
        approve: false,
        reason: 'edited_and_revalidated_in_scan_page',
        relationshipRanks: relationshipRanks,
        confirmedFields: confirmedFields,
      );
      if (!mounted) return;
      setState(() {
        _keepCandidate(revised);
        _candidateErrors.remove(candidate.id);
        _candidateNotice = '수정값을 revision ${revised.revision}에서 재검증했습니다.';
      });
    } catch (error) {
      if (mounted) {
        final message = '재검증 실패: $error';
        setState(() {
          _candidateErrors[candidate.id] = message;
          _candidateNotice = message;
        });
      }
    } finally {
      if (mounted) setState(() => _busyCandidateIds.remove(candidate.id));
    }
  }

  Future<void> _holdStudentCandidate(ScannerCandidate candidate) async {
    setState(() {
      _candidateNotice = '후보를 보류했습니다. 확정된 현재값은 변경되지 않았습니다.';
    });
  }

  Future<void> _discardStudentCandidate(ScannerCandidate candidate) async {
    final scanner = _scanner;
    final session = _sessionFor(candidate);
    if (scanner == null || session == null) return;
    setState(() {
      _busyCandidateIds.add(candidate.id);
      _candidateNotice = null;
    });
    try {
      await scanner.reviewScannerCandidate(
        session,
        candidate,
        candidate.payload,
        approve: false,
        reason: 'discarded_in_scan_page',
      );
      if (!mounted) return;
      setState(() {
        _candidates.remove(candidate.id);
        _candidateErrors.remove(candidate.id);
        _releaseStudentCandidateImages(candidate);
        _candidateNotice = '후보를 폐기했습니다. 확정된 현재값은 변경되지 않았습니다.';
      });
    } catch (error) {
      if (mounted) {
        final message = '후보 폐기 실패: $error';
        setState(() {
          _candidateErrors[candidate.id] = message;
          _candidateNotice = message;
        });
      }
    } finally {
      if (mounted) setState(() => _busyCandidateIds.remove(candidate.id));
    }
  }

  /// FB-10c: 승인·폐기·적용 성공 뒤 그 학생 후보의 검토 이미지(crop)를 이 화면의 보관물(지금 후보, 최근 스캔 요약,
  /// 시작 전 버퍼 이벤트)에서 지운다. 백엔드는 같은 시점에 자기 사본만 지우고 이미 보낸 사본은 회수하지 못한다.
  /// 보류·수정·재검증·적용 실패 동안과 다른 후보의 crop은 그대로 둔다. setState 안에서 부른다.
  void _releaseStudentCandidateImages(ScannerCandidate candidate) {
    if (candidate.kind != ScannerKind.student) return;
    bool sameSession(String sessionId, int generation) =>
        sessionId == candidate.sessionId && generation == candidate.generation;
    final shown = _candidates[candidate.id];
    if (shown != null && sameSession(shown.sessionId, shown.generation)) {
      _candidates[candidate.id] = scannerCandidateWithoutReviewImages(shown);
    }
    for (var index = 0; index < _pendingStartEvents.length; index += 1) {
      final event = _pendingStartEvents[index];
      if (sameSession(event.sessionId, event.generation)) {
        _pendingStartEvents[index] = scannerEventWithoutCandidateImages(
          event,
          candidate.id,
        );
      }
    }
    var recentChanged = false;
    for (var index = 0; index < _recent.length; index += 1) {
      final item = _recent[index];
      if (!sameSession(item.sessionId, item.generation)) continue;
      final released = scannerRecentWithoutCandidateImages(item, candidate.id);
      if (identical(released, item)) continue;
      _recent[index] = released;
      recentChanged = true;
    }
    if (recentChanged) {
      widget.onRecentChanged?.call(
        List<ScannerRecentSummary>.unmodifiable(_recent),
      );
    }
  }

  String _newApplyKey(ScannerCandidate approved) {
    _applyIntentSequence += 1;
    final stamp = widget.now().microsecondsSinceEpoch.toRadixString(36);
    return 'scan-apply-${approved.id}-${approved.revision}-'
        '$stamp-$_applyIntentSequence';
  }

  /// 학생 결과 적용은 한 번에 하나씩 차례로 한다(FD-144 순차 적용). 뒤 적용은 앞 commit 응답 revision을
  /// expected로 쓴다. 기다리는 동안에도 후보 버튼은 바쁨으로 표시한다.
  Future<void> _applyStudentCandidate(ScannerCandidate candidate) {
    final tappedProfileId = _profile?.id;
    setState(() => _busyCandidateIds.add(candidate.id));
    final run = _applyQueue.then((_) async {
      try {
        if (mounted) {
          await _applyStudentCandidateInOrder(candidate, tappedProfileId);
        }
      } finally {
        if (mounted) setState(() => _busyCandidateIds.remove(candidate.id));
      }
    });
    _applyQueue = run.catchError((Object _) {});
    return run;
  }

  /// [candidate]가 아직 지금 보이는 후보(같은 세션·generation)인가. 차례를 기다리거나 재시도하는 사이 새 스캔이
  /// 시작되면 이전 세션의 결과로 새 후보를 지우거나 빨갛게 만들지 않는다.
  bool _isShownCandidate(ScannerCandidate candidate) {
    final shown = _candidates[candidate.id];
    return shown != null &&
        shown.sessionId == candidate.sessionId &&
        shown.generation == candidate.generation;
  }

  Future<void> _applyStudentCandidateInOrder(
    ScannerCandidate candidate,
    String? tappedProfileId,
  ) async {
    final scanner = _scanner;
    final repository = _repository;
    final profile = _profile;
    final session = _sessionFor(candidate);
    if (profile != null &&
        tappedProfileId != null &&
        profile.id != tappedProfileId) {
      setState(
        () => _candidateNotice = '적용 차례를 기다리는 동안 계정이 바뀌어 적용하지 않았습니다.',
      );
      return;
    }
    final pinned = session == null
        ? null
        : _pendingApplies[scanPendingApplySlot(session, candidate.id)];
    // 같은 의도의 재시도: 고정한 요청을 그대로 다시 보낸다(review 재호출·새 expected 없음). 고정한 expected를
    // 쓰므로 지금 state cache가 비어 있어도 보낼 수 있다.
    final retry =
        pinned != null &&
            session != null &&
            profile != null &&
            pinned.isRetryOf(session, candidate, profile.id)
        ? pinned
        : null;
    final expected = retry != null
        ? retry.expectedRepositoryRevision
        : (_repositoryState == null ? null : _repositoryRevision);
    if (scanner == null ||
        repository == null ||
        profile == null ||
        expected == null ||
        session == null) {
      setState(() {
        const message = '적용에 필요한 프로필 또는 세션 상태가 없습니다.';
        _candidateErrors[candidate.id] = message;
        _candidateNotice = message;
      });
      return;
    }
    final slot = scanPendingApplySlot(session, candidate.id);
    if (retry == null) _pendingApplies.remove(slot);
    // 안내 문구는 지우지 않는다: 앞 적용의 "다시 적용하면 같은 요청을…" 안내가 이 적용의 결과가 나올 때까지 남는다.
    setState(() => _busyCandidateIds.add(candidate.id));
    ScanPendingApply? sent;
    try {
      final ScanPendingApply request;
      if (retry != null) {
        request = retry;
      } else {
        final approved = candidate.approved
            ? candidate
            : await scanner.reviewScannerCandidate(
                session,
                candidate,
                candidate.payload,
                approve: true,
                reason: 'applied_in_scan_page',
              );
        if (!mounted) return;
        final created = ScanPendingApply(
          session: session,
          candidate: approved,
          profileId: profile.id,
          expectedRepositoryRevision: expected,
          idempotencyKey: _newApplyKey(approved),
        );
        _pendingApplies[slot] = created;
        request = created;
        setState(() {
          _keepCandidate(approved);
          // 백엔드는 승인 때 자기 crop을 지웠다. 이미 받은 사본도 같은 시점에 지운다.
          _releaseStudentCandidateImages(approved);
        });
      }
      sent = request;
      final committed = await retryRepositoryBusy(
        () => scanner.commitScannerCandidate(
          request.session,
          request.candidate,
          profileId: request.profileId,
          expectedRepositoryRevision: request.expectedRepositoryRevision,
          idempotencyKey: request.idempotencyKey,
        ),
      );
      if (identical(_pendingApplies[slot], request)) {
        _pendingApplies.remove(slot);
      }
      if (!mounted) return;
      final committedRevision = committed['revision'];
      setState(() {
        if (committedRevision is int) {
          _acceptCommittedRevision(request.profileId, committedRevision);
        }
        if (_isShownCandidate(candidate)) {
          _candidates.remove(candidate.id);
          _candidateErrors.remove(candidate.id);
        }
        _releaseStudentCandidateImages(candidate);
        _candidateNotice =
            '결과를 repository revision $committedRevision에 적용했습니다.';
      });
      try {
        await _reloadRepositoryState(request.profileId);
      } catch (error) {
        if (mounted) {
          setState(
            () => _candidateNotice =
                '결과를 repository revision $committedRevision에 적용했습니다. '
                '현재값을 다시 읽지 못했습니다: ${repositoryLoadErrorText(error)}',
          );
        }
      }
    } catch (error) {
      final request = sent;
      final failure = request == null
          ? ScanApplyFailure.rejected
          : classifyScanApplyFailure(error);
      // 저장 여부를 모르거나(busy를 다 쓴 경우 포함) 아직 저장되지 않은 같은 의도만 고정해 둔다. 거절·충돌은
      // 저장되지 않았으므로 버린다. 다음 적용은 새 key·새 expected다.
      if (request != null &&
          failure != ScanApplyFailure.unknownOutcome &&
          failure != ScanApplyFailure.busy &&
          identical(_pendingApplies[slot], request)) {
        _pendingApplies.remove(slot);
      }
      if (!mounted) return;
      try {
        await _reloadRepositoryState(profile.id);
      } catch (_) {}
      if (!mounted) return;
      final wasRetry = retry != null;
      setState(() {
        final shown = _isShownCandidate(candidate);
        switch (failure) {
          case ScanApplyFailure.unknownOutcome:
            // 후보를 빨간 상태로 바꾸지 않는다: "적용"을 다시 누르면 같은 요청을 다시 보낸다.
            if (shown) _candidateErrors.remove(candidate.id);
            _candidateNotice =
                '적용 결과를 확인하지 못했습니다: $error. '
                '다시 적용하면 같은 요청을 다시 보냅니다.';
          case ScanApplyFailure.busy:
            if (shown) _candidateErrors.remove(candidate.id);
            _candidateNotice =
                '저장소가 다른 작업을 하고 있어 '
                '${scanRepositoryBusyRetryDelays.length}번 다시 시도한 뒤 멈췄습니다. '
                '잠시 뒤 다시 적용하면 같은 요청을 다시 보냅니다.';
          case ScanApplyFailure.revisionConflict:
            {
              final message = wasRetry
                  ? '적용 실패: 같은 요청을 다시 보냈지만 그사이 저장소가 바뀌어 적용되지 '
                        '않았습니다. 현재값을 다시 읽었습니다. 재검증한 뒤 다시 적용해 주십시오.'
                  : '적용 실패: $error. 현재값을 다시 읽었습니다. 후보와 수정값을 유지했습니다.';
              if (shown) _candidateErrors[candidate.id] = message;
              _candidateNotice = message;
            }
          case ScanApplyFailure.rejected:
            {
              final message = '적용 실패: $error. 후보와 수정값을 유지했습니다.';
              if (shown) _candidateErrors[candidate.id] = message;
              _candidateNotice = message;
            }
        }
      });
    } finally {
      if (mounted) setState(() => _busyCandidateIds.remove(candidate.id));
    }
  }

  void _resetProjection() {
    _phase = null;
    _progressCurrent = null;
    _progressTotal = null;
    _messageKey = null;
    _diagnostic = null;
    _outcome = null;
    _terminalError = null;
    _candidates.clear();
    _liveFeedbackStudentId = null;
    _candidateErrors.clear();
    _unresolvedSlots.clear();
    _unresolvedLoading.clear();
    _identityBusy.clear();
    _identitySkipped.clear();
    _identityErrors.clear();
  }

  void _recordRecent() {
    final session = _session;
    final target = _selectedTarget;
    if (session == null) return;
    _recent.removeWhere(
      (item) =>
          item.sessionId == session.id && item.generation == session.generation,
    );
    _recent.insert(
      0,
      ScannerRecentSummary(
        session: session,
        targetId: target?.id ?? _targetId ?? '',
        targetTitle: target?.title ?? _targetId ?? 'Unknown target',
        outcome: _outcome ?? 'unknown',
        phase: _phase,
        diagnostic: _diagnostic ?? _terminalError?['message'] as String?,
        candidateCount: _candidates.length,
        reviewRequired: _candidates.values.any((item) => item.reviewRequired),
        progressCurrent: _progressCurrent,
        progressTotal: _progressTotal,
        messageKey: _messageKey,
        terminalError: _terminalError,
        candidates: _candidates.values.toList(growable: false),
      ),
    );
    if (_recent.length > 8) _recent.removeRange(8, _recent.length);
    widget.onRecentChanged?.call(
      List<ScannerRecentSummary>.unmodifiable(_recent),
    );
  }

  void _openRecent(ScannerRecentSummary item) {
    final recentTargetId = _recentTargetId(item);
    setState(() {
      _session = item.session;
      _kind = item.kind;
      _targetId = recentTargetId;
      _stage = _SessionStage.terminal;
      _phase = item.phase;
      _diagnostic = item.diagnostic;
      _progressCurrent = item.progressCurrent;
      _progressTotal = item.progressTotal;
      _messageKey = item.messageKey;
      _outcome = item.outcome;
      _terminalError = item.terminalError;
      _candidateErrors.clear();
      _unresolvedSlots.clear();
      _unresolvedLoading.clear();
      _identityBusy.clear();
      _identitySkipped.clear();
      _identityErrors.clear();
      _candidates.clear();
      for (final candidate in item.candidates) {
        _keepCandidate(candidate);
      }
      _sessionError = null;
    });
  }

  void _handoff(ScannerCandidate candidate) {
    final session = _session;
    if (session == null ||
        candidate.sessionId != session.id ||
        candidate.generation != session.generation ||
        candidate.kind != session.kind ||
        !_payloadMatchesKind(candidate)) {
      setState(() => _sessionError = 'Candidate kind or payload mismatch.');
      return;
    }
    widget.onCandidateHandoff(session, candidate);
  }

  bool _payloadMatchesKind(ScannerCandidate candidate) {
    if (candidate.payload['version'] != 1) return false;
    return switch (candidate.kind) {
      ScannerKind.student =>
        candidate.payload['student_id'] is String &&
            candidate.payload['values'] is Map,
      ScannerKind.inventory => candidate.payload['entries'] is List,
      ScannerKind.tacticalLobby =>
        candidate.payload['current_rank'] is Map &&
            candidate.payload['rows'] is List &&
            (candidate.payload['rows'] as List).length == 3,
    };
  }

  /// 일시정지 중일 때 보일 문구(FD-142). 진행 중이 아니면 null.
  String? get _pausedLabel {
    if (_stage != _SessionStage.running ||
        _control != ScannerControlState.paused) {
      return null;
    }
    final reason = switch (_pauseReason) {
      ScannerPauseReason.inputDetected => '마우스·키보드 입력이 감지되어 일시정지했습니다.',
      ScannerPauseReason.targetMinimized =>
        '게임 창이 최소화되어 일시정지했습니다. 창을 다시 연 뒤 이어서를 누르십시오.',
      ScannerPauseReason.user || null => '일시정지했습니다.',
    };
    return '$reason 읽은 칸은 남아 있습니다. 이어서를 누르면 계속하고, Esc를 누르면 중지합니다.';
  }

  @override
  Widget build(BuildContext context) {
    _syncEscape();
    final scannerMissing = _scanner == null;
    final repositoryMissing = _repository == null;
    final readinessMissing = (_readiness?['missing'] as List?)?.length ?? 0;
    final readinessCorrupt = (_readiness?['corrupt'] as List?)?.length ?? 0;
    final selectedTarget = _selectedTarget;
    final total = _progressTotal;
    final progress = total == null || total <= 0 || _progressCurrent == null
        ? null
        : (_progressCurrent! / total).clamp(0.0, 1.0).toDouble();

    return ListView(
      key: const ValueKey('scan-page'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        RepositoryProfilePanel(
          service: widget.service,
          onSelected: _selectProfile,
        ),
        const SizedBox(height: AppSpacing.sm),
        DiagonalSection(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 36, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Scan preparation',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _StatusChip(
                      label: _connected
                          ? 'Backend connected'
                          : 'Backend disconnected',
                      ok: _connected,
                    ),
                    _StatusChip(
                      label: _recognitionReady
                          ? 'Recognition ready'
                          : 'Recognition not ready',
                      ok: _recognitionReady,
                    ),
                    _StatusChip(
                      label: _profile == null
                          ? 'No profile selected'
                          : 'Profile: ${_profile!.displayName} · '
                                'r${_profile!.revision}',
                      ok: _profile != null,
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('scan-refresh'),
                      onPressed: _targetsLoading || _readinessLoading
                          ? null
                          : _refreshPreparation,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_readinessLoading || _targetsLoading)
                  const LinearProgressIndicator(),
                Text(
                  'Manifest ${_readiness?['manifest_version'] ?? 'unknown'} · '
                  'missing $readinessMissing · corrupt $readinessCorrupt',
                  key: const ValueKey('scan-readiness-summary'),
                ),
                if (scannerMissing)
                  const Text('Scanner service is unavailable.'),
                if (repositoryMissing)
                  const Text('Repository service is unavailable.'),
                if (_readinessError != null)
                  Text(
                    _readinessError!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                if (_targetError != null)
                  Text(
                    _targetError!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                if (!_targetsLoading && _targets.isEmpty)
                  const Text(
                    'No game windows were found. Open Blue Archive and refresh.',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DiagonalSection(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 36, 18),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 420,
                  child: DropdownButtonFormField<String>(
                    key: const ValueKey('scan-target'),
                    initialValue: _targetId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Game window target',
                    ),
                    items: [
                      for (final target in _targets)
                        DropdownMenuItem(
                          value: target.id,
                          child: Text(
                            '${target.title} · ${target.status.name}'
                            '${target.foreground ? ' · foreground' : ''} · ${target.id}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged:
                        _stage == _SessionStage.running ||
                            _stage == _SessionStage.cancelling ||
                            _stage == _SessionStage.starting
                        ? null
                        : _chooseTarget,
                  ),
                ),
                SegmentedButton<String>(
                  key: const ValueKey('scan-kind'),
                  segments: const [
                    ButtonSegment(
                      value: 'student_single',
                      label: Text('1명'),
                      icon: Icon(Icons.school_outlined),
                    ),
                    ButtonSegment(
                      value: 'student_full',
                      label: Text('전체'),
                      icon: Icon(Icons.groups_outlined),
                    ),
                    ButtonSegment(
                      value: 'inventory',
                      label: Text('재고'),
                      icon: Icon(Icons.inventory_2_outlined),
                    ),
                  ],
                  selected: {
                    _kind == ScannerKind.inventory
                        ? 'inventory'
                        : _studentScanMode == StudentScanMode.full
                        ? 'student_full'
                        : 'student_single',
                  },
                  onSelectionChanged:
                      _stage == _SessionStage.running ||
                          _stage == _SessionStage.cancelling ||
                          _stage == _SessionStage.starting
                      ? null
                      : (value) => setState(() {
                          final selection = value.first;
                          _kind = selection == 'inventory'
                              ? ScannerKind.inventory
                              : ScannerKind.student;
                          if (_kind == ScannerKind.student) {
                            _studentScanMode = selection == 'student_full'
                                ? StudentScanMode.full
                                : StudentScanMode.single;
                          }
                        }),
                ),
                if (_kind == ScannerKind.inventory)
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<InventoryScanProfile>(
                      key: const ValueKey('scan-inventory-profile'),
                      initialValue: _inventoryScanProfile,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: '재고 스캔 프로필'),
                      items: [
                        for (final profile in InventoryScanProfile.values)
                          DropdownMenuItem(
                            value: profile,
                            child: Text(profile.wireName),
                          ),
                      ],
                      onChanged:
                          _stage == _SessionStage.running ||
                              _stage == _SessionStage.cancelling ||
                              _stage == _SessionStage.starting
                          ? null
                          : (value) =>
                                setState(() => _inventoryScanProfile = value!),
                    ),
                  ),
                FilledButton.icon(
                  key: const ValueKey('scan-start'),
                  onPressed: _canStart ? _start : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start scan'),
                ),
                if (selectedTarget != null &&
                    selectedTarget.status != ScannerTargetStatus.ready)
                  Text(
                    'Selected target is ${selectedTarget.status.name}; choose a ready target.',
                    style: const TextStyle(color: AppColors.warning),
                  ),
              ],
            ),
          ),
        ),
        if (_stage != _SessionStage.idle) ...[
          const SizedBox(height: AppSpacing.sm),
          _buildSession(progress),
        ],
        if (_candidates.values.any(
          (item) => item.kind == ScannerKind.student,
        )) ...[
          const SizedBox(height: AppSpacing.sm),
          ScanStudentReviewWorkspace(
            candidates: _candidates.values
                .where((item) => item.kind == ScannerKind.student)
                .toList(growable: false),
            currentStudents: {
              for (final item
                  in _repositoryState?.students ??
                      const <ConfirmedStudentState>[])
                item.studentId: item,
            },
            catalog: _studentCatalog,
            busyCandidateIds: _busyCandidateIds,
            candidateErrors: _candidateErrors,
            singleScan: _session?.studentScanMode != StudentScanMode.full,
            onRevalidate: _revalidateStudentCandidate,
            onHold: _holdStudentCandidate,
            onDiscard: _discardStudentCandidate,
            onApply: _applyStudentCandidate,
          ),
        ],
        if (_candidateNotice != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _candidateNotice!,
            key: const ValueKey('scan-student-candidate-notice'),
          ),
        ],
        if (_recent.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _buildRecent(),
        ],
      ],
    );
  }

  Widget _buildSession(double? progress) => DiagonalSection(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 36, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Session ${_session?.id ?? 'starting'} · generation ${_session?.generation ?? '-'}',
                key: const ValueKey('scan-session'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Chip(label: Text(_stage.name)),
              if (_phase != null) Chip(label: Text('Phase: $_phase')),
              if (_outcome != null) Chip(label: Text('Outcome: $_outcome')),
              FilledButton.tonalIcon(
                key: const ValueKey('scan-cancel'),
                onPressed: _stage == _SessionStage.running ? _cancel : null,
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(
                  _stage == _SessionStage.cancelling ? 'Cancelling…' : 'Cancel',
                ),
              ),
              // FB-10a(FD-142): 진행 중에는 일시정지, 멈춘 뒤에는 이어서. 끝나면 둘 다 숨긴다.
              if (_stage == _SessionStage.running &&
                  _control == ScannerControlState.paused)
                FilledButton.icon(
                  key: const ValueKey('scan-resume'),
                  onPressed: _controlBusy ? null : _resume,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('이어서'),
                )
              else if (_stage == _SessionStage.running)
                FilledButton.tonalIcon(
                  key: const ValueKey('scan-pause'),
                  onPressed:
                      _controlBusy || _control != ScannerControlState.running
                      ? null
                      : _pause,
                  icon: const Icon(Icons.pause),
                  label: Text(
                    _control == ScannerControlState.pauseRequested
                        ? '멈추는 중…'
                        : '일시정지',
                  ),
                ),
              if (_pausedLabel case final label?)
                Text(
                  label,
                  key: const ValueKey('scan-paused-reason'),
                  style: const TextStyle(color: AppColors.warning),
                ),
              OutlinedButton.icon(
                key: const ValueKey('scan-retry'),
                onPressed: _stage == _SessionStage.terminal && _canStart
                    ? _start
                    : null,
                icon: const Icon(Icons.replay),
                label: const Text('Retry'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('scan-recover'),
                onPressed: _session == null || _recovering
                    ? null
                    : _recoverSnapshot,
                icon: const Icon(Icons.sync),
                label: Text(_recovering ? 'Recovering…' : 'Recover snapshot'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('scan-export-student-diagnostic'),
                onPressed: _canExportStudentDiagnostic
                    ? _exportStudentDiagnostic
                    : null,
                icon: const Icon(Icons.file_download_outlined),
                label: Text(
                  _exportingStudentDiagnostic ? '추출 중…' : '진단 JSON 추출',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!_companionActive)
            Semantics(
              label: progress == null
                  ? 'Scan progress indeterminate'
                  : 'Scan progress ${_progressCurrent ?? 0} of $_progressTotal',
              child: LinearProgressIndicator(value: progress),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _progressCurrent == null
                ? 'Waiting for progress'
                : _progressTotal == null || _progressTotal == 0
                ? '${_progressCurrent!} · total unknown'
                : '${_progressCurrent!} / $_progressTotal',
            key: const ValueKey('scan-progress'),
          ),
          if (_messageKey != null) Text('Message: $_messageKey'),
          if (_diagnostic != null) SelectableText('Diagnostic: $_diagnostic'),
          if (_terminalError != null)
            SelectableText(
              'Terminal error: ${_terminalError!['code']} · ${_terminalError!['message']}',
              style: const TextStyle(color: AppColors.danger),
            ),
          if (_sessionError != null)
            SelectableText(
              _sessionError!,
              style: const TextStyle(color: AppColors.danger),
            ),
          for (final candidate in _candidates.values.where(
            (item) => item.kind != ScannerKind.student,
          )) ...[
            const Divider(),
            _CandidateSummary(
              candidate: candidate,
              onHandoff: () => _handoff(candidate),
            ),
            if (candidate.kind == ScannerKind.inventory) ...[
              if (_unresolvedLoading.contains(candidate.id))
                const LinearProgressIndicator(),
              if ((_unresolvedSlots[candidate.id] ?? const [])
                      .where(
                        (slot) => !_identitySkipped.contains(
                          _identitySlotKey(candidate.id, slot.slot),
                        ),
                      )
                      .toList(growable: false)
                  case final slots when slots.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: ScanInventoryIdentityReview(
                    slots: slots,
                    catalog: _inventoryCatalog,
                    busySlots: {
                      for (final slot in slots)
                        if (_identityBusy.contains(
                          _identitySlotKey(candidate.id, slot.slot),
                        ))
                          slot.slot,
                    },
                    errors: {
                      for (final slot in slots)
                        slot.slot:
                            ?_identityErrors[_identitySlotKey(
                              candidate.id,
                              slot.slot,
                            )],
                    },
                    onAssign: (slot, identity, persist) =>
                        _assignInventoryIdentity(
                          candidate,
                          slot,
                          identity,
                          persist,
                        ),
                    onSkip: (slot) => _skipInventoryIdentity(candidate, slot),
                  ),
                ),
            ],
          ],
        ],
      ),
    ),
  );

  Widget _buildRecent() => DiagonalSection(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 36, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent sessions in this app run',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final item in _recent)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${item.kind.name} · ${item.targetTitle} · ${item.outcome}',
              ),
              subtitle: Text(
                'generation ${item.generation} · phase ${item.phase ?? 'unknown'} · '
                '${item.candidateCount} candidate(s)'
                '${item.reviewRequired ? ' · review required' : ''}'
                '${item.diagnostic == null ? '' : ' · ${item.diagnostic}'}',
              ),
              trailing: OutlinedButton(
                key: ValueKey('scan-recent-${item.session.id}'),
                onPressed: () => _openRecent(item),
                child: const Text('Open'),
              ),
            ),
        ],
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.ok});
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(ok ? Icons.check_circle : Icons.error_outline, size: 18),
    label: Text(label),
  );
}

class _CandidateSummary extends StatelessWidget {
  const _CandidateSummary({required this.candidate, required this.onHandoff});
  final ScannerCandidate candidate;
  final VoidCallback onHandoff;

  String get _payloadSummary {
    if (candidate.kind == ScannerKind.student) {
      final values = candidate.payload['values'];
      return 'Student ${candidate.payload['student_id']} · '
          '${values is Map ? values.length : 0} observed field(s)';
    }
    if (candidate.kind == ScannerKind.tacticalLobby) {
      final rank = candidate.payload['current_rank'];
      final rows = candidate.payload['rows'];
      final current = rank is Map
          ? rank['value'] ?? rank['proposed_value']
          : '?';
      return 'Tactical lobby 쨌 current rank $current 쨌 '
          '${rows is List ? rows.length : 0} opponent row(s)';
    }
    final entries = candidate.payload['entries'];
    final unknown = entries is List
        ? entries
              .where((item) => item is Map && item['quantity'] == null)
              .length
        : 0;
    return 'Inventory · ${entries is List ? entries.length : 0} entry(s) · '
        '$unknown unknown quantity';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Candidate ${candidate.id} · revision ${candidate.revision}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Chip(label: Text(candidate.kind.name)),
          if (candidate.reviewRequired)
            const Chip(label: Text('Review required')),
          if (candidate.approved) const Chip(label: Text('Approved')),
        ],
      ),
      Text(_payloadSummary),
      for (final evidence in candidate.evidence)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${evidence.field}: ${evidence.status} · ${evidence.source}'
            '${evidence.confidence == null ? '' : ' · ${(evidence.confidence! * 100).toStringAsFixed(1)}%'}'
            '${evidence.note.isEmpty ? '' : ' · ${evidence.note}'}',
          ),
        ),
      const SizedBox(height: AppSpacing.sm),
      FilledButton.icon(
        key: ValueKey('scan-review-${candidate.id}'),
        onPressed: onHandoff,
        icon: const Icon(Icons.rate_review_outlined),
        label: Text(switch (candidate.kind) {
          ScannerKind.student => 'Review in Students',
          ScannerKind.inventory => 'Review in Inventory',
          ScannerKind.tacticalLobby => 'Review tactical capture',
        }),
      ),
    ],
  );
}
