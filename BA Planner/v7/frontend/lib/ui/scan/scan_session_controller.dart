import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../../services/scanner_review_images.dart';
import '../../services/scanner_service.dart';
import '../../services/student_scan_diagnostic.dart';
import '../../services/window_dock_service.dart';
import '../widgets/account_section_cluster.dart'
    show repositoryLoadErrorText, repositoryProfileWithRevision;
import '../widgets/scan_companion_dock.dart';
import 'connected_target_controller.dart';
import 'scan_repository_sync.dart';

/// 스캔 세션 단계. 이름(`name`)은 스캔 화면 칩과 dock 단계 글자로 그대로 보인다.
enum ScanSessionStage { idle, starting, running, cancelling, terminal }

/// 스캔 탭 고르기(FE8-g1, 시안 Scan · Scan-Items). 학생 칸(전체/1명)과 아이템 칸은 상호 배타이고, 아이템은 여러 종류를
/// 고를 수 있다(FD-151 선물 포함). 아무것도 고르지 않은 상태도 있다(고른 종류 해제 · 마지막 아이템 칸 풀기).
@immutable
class ScanPick {
  const ScanPick.none()
    : studentScanMode = null,
      inventoryScanProfiles = const {};

  const ScanPick.student(StudentScanMode this.studentScanMode)
    : inventoryScanProfiles = const {};

  ScanPick.inventory(Iterable<InventoryScanProfile> profiles)
    : studentScanMode = null,
      inventoryScanProfiles = Set.unmodifiable(profiles);

  /// 학생 칸을 골랐으면 그 모드, 아니면 null.
  final StudentScanMode? studentScanMode;

  /// 고른 아이템 종류(학생 칸을 골랐으면 비어 있다).
  final Set<InventoryScanProfile> inventoryScanProfiles;

  bool get isNone => studentScanMode == null && inventoryScanProfiles.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is ScanPick &&
      other.studentScanMode == studentScanMode &&
      setEquals(other.inventoryScanProfiles, inventoryScanProfiles);

  @override
  int get hashCode => Object.hash(
    studentScanMode,
    Object.hashAllUnordered(inventoryScanProfiles),
  );
}

/// 최근 스캔 행이 쓰는 앱 실행 기록 보탬(FD-149 (a)): 시작 시각과 아이템 종류. [ScannerRecentSummary]에는 없는 값이라
/// 세션(id + generation)마다 컨트롤러가 기억한다.
@immutable
class ScanRecentDetail {
  const ScanRecentDetail({required this.startedAt, this.inventoryScanProfile});

  final DateTime startedAt;
  final InventoryScanProfile? inventoryScanProfile;
}

/// 스캔 세션 하나의 상태와 흐름(FE8-f1). 예전 `_ScanPageState`가 갖던 준비(창 · 인식 준비),
/// 세션 시작 · 이벤트 커서(session id + generation) · 후보(revision) · 최근 스캔 · companion dock ·
/// 학생/인벤토리 검토 흐름을 그대로 옮겼다. 화면은 이 값을 읽고 메서드를 부른다.
///
/// 셸([AppShell])이 하나를 소유해 탭을 옮겨도 세션이 살아 있다. [ScanPage]를 단독으로 쓰면 화면이 자기 것을 만든다.
/// 첫 화면이 붙을 때 [ensureStarted]로 이벤트 구독과 준비 읽기를 시작한다. [dispose] 뒤에는 알리지 않고,
/// 늦게 온 응답 · 이벤트는 버린다(다른 세션 · generation의 이벤트도 버린다).
class ScanSessionController extends ChangeNotifier {
  ScanSessionController({
    required this._service,
    this._connectedTarget,
    this.windowDockService = const WindowsWindowDockService(),
    this.studentScanDiagnosticFileService =
        const NativeStudentScanDiagnosticFileService(),
    this.now = DateTime.now,
    this.onRecentChanged,
    this.onCompanionChanged,
  });

  AppService _service;
  ConnectedTargetController? _connectedTarget;
  WindowDockService windowDockService;
  StudentScanDiagnosticFileService studentScanDiagnosticFileService;
  DateTime Function() now;

  /// 최근 스캔이 바뀌면 부른다(셸의 홈 최근 스캔).
  ValueChanged<List<ScannerRecentSummary>>? onRecentChanged;

  /// 전체 학생 스캔의 dock 상태. dock을 닫으면 null.
  ValueChanged<ScanCompanionState?>? onCompanionChanged;

  AppService get service => _service;
  ConnectedTargetController? get connectedTarget => _connectedTarget;

  ScannerService? get _scanner =>
      _service is ScannerService ? _service as ScannerService : null;
  RepositoryService? get _repository =>
      _service is RepositoryService ? _service as RepositoryService : null;

  bool _started = false;
  bool _disposed = false;
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

  ScanSessionStage _stage = ScanSessionStage.idle;
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
  String? _liveFeedbackStudentId;

  /// FB-10 `feedback`(field `student_id`)로 관측한 학생(최근 먼저, 같은 학생은 한 번).
  final List<String> _observedStudentIds = [];
  ScannerSession? _lastEndedSession;
  ScanPick _pick = const ScanPick.student(StudentScanMode.full);
  final Map<String, ScanRecentDetail> _recentDetails = {};

  /// 스캔 화면에서 적용(true) · 폐기(false)한 후보(세션 · generation · id). 최근 스캔 행의 "확정"을 판단한다.
  final Map<String, bool> _resolvedCandidates = {};

  /// FB-10a 세션 제어(진행 단계 안의 하위 상태). pause 응답의 `pauseRequested`는 수락일 뿐이고,
  /// `paused` 이벤트를 받아야 멈춘 것으로 본다.
  ScannerControlState _control = ScannerControlState.running;
  ScannerPauseReason? _pauseReason;
  bool _controlBusy = false;

  late final Map<String, ScannerCandidate> _candidatesView =
      UnmodifiableMapView(_candidates);
  late final List<ScannerRecentSummary> _recentView = UnmodifiableListView(
    _recent,
  );
  late final Set<String> _busyCandidateIdsView = UnmodifiableSetView(
    _busyCandidateIds,
  );
  late final Map<String, String> _candidateErrorsView = UnmodifiableMapView(
    _candidateErrors,
  );
  late final List<String> _observedStudentIdsView = UnmodifiableListView(
    _observedStudentIds,
  );

  // ---- 읽기 ----

  bool get scannerAvailable => _scanner != null;
  bool get repositoryAvailable => _repository != null;
  bool get connected =>
      _service.state.value.connection == BackendConnection.connected;
  bool get recognitionReady => _readiness?['ready'] == true;
  Map<String, dynamic>? get readiness => _readiness;
  bool get readinessLoading => _readinessLoading;
  String? get readinessError => _readinessError;
  List<ScannerTarget> get targets => _targets;
  bool get targetsLoading => _targetsLoading;
  String? get targetError => _targetError;
  String? get targetId => _targetId;
  ScannerTarget? get selectedTarget {
    for (final target in _targets) {
      if (target.id == _targetId) return target;
    }
    return null;
  }

  RepositoryProfile? get profile => _profile;
  RepositoryState? get repositoryState => _repositoryState;
  Map<String, StudentCatalogEntry> get studentCatalog => _studentCatalog;
  List<InventoryCatalogEntry> get inventoryCatalog => _inventoryCatalog;
  ScannerKind get kind => _kind;
  StudentScanMode get studentScanMode => _studentScanMode;
  InventoryScanProfile get inventoryScanProfile => _inventoryScanProfile;

  ScanSessionStage get stage => _stage;
  ScannerSession? get session => _session;
  String? get sessionError => _sessionError;
  bool get recovering => _recovering;
  String? get phase => _phase;
  int? get progressCurrent => _progressCurrent;
  int? get progressTotal => _progressTotal;
  String? get messageKey => _messageKey;
  String? get diagnostic => _diagnostic;
  String? get outcome => _outcome;
  Map<String, dynamic>? get terminalError => _terminalError;
  ScannerControlState get control => _control;
  ScannerPauseReason? get pauseReason => _pauseReason;
  bool get controlBusy => _controlBusy;

  /// 이 컨트롤러에서 마지막으로 끝난 세션(실시간 terminal 이벤트 · 스냅숏 복구로 최근 기록에 넣을 때). 최근 기록
  /// 열기로는 바뀌지 않는다. 셸의 완료 토스트가 같은 세션(id + generation)에 한 번만 뜨도록 읽는다(FE8-f2).
  ScannerSession? get lastEndedSession => _lastEndedSession;

  /// 지금 세션에서 마지막으로 관측한 학생(FB-10 `feedback` field `student_id`, 진행 화면 `지금 읽는 학생`). 관측값일 뿐
  /// 후보 · 저장 기록이 아니다. 모르면 null.
  String? get liveFeedbackStudentId => _liveFeedbackStudentId;

  /// 지금 세션에서 관측한 학생 id(최근 먼저, 같은 학생은 한 번 — 진행 화면 `방금 읽은 학생`). 관측값일 뿐이다.
  List<String> get observedStudentIds => _observedStudentIdsView;

  /// 지금 세션(또는 연 최근 기록)의 후보. id → 가장 높은 revision.
  Map<String, ScannerCandidate> get candidates => _candidatesView;

  /// 이 앱 실행의 최근 세션(최신 먼저, 최대 8).
  List<ScannerRecentSummary> get recent => _recentView;

  /// 스캔 탭 고르기(FE8-g1). 시작 전 화면만 쓴다.
  ScanPick get pick => _pick;

  /// [session]을 시작한 시각 · 아이템 종류(이 컨트롤러로 시작한 세션만, 아니면 null).
  ScanRecentDetail? recentDetail(ScannerSession session) =>
      _recentDetails[_sessionKey(session.id, session.generation)];

  /// 스캔 화면에서 적용했으면 true, 폐기했으면 false, 아직이면 null.
  bool? candidateResolution(ScannerCandidate candidate) =>
      _resolvedCandidates[_candidateKey(candidate)];
  Set<String> get busyCandidateIds => _busyCandidateIdsView;
  Map<String, String> get candidateErrors => _candidateErrorsView;
  String? get candidateNotice => _candidateNotice;
  bool get companionActive => _companionActive;
  bool get exportingStudentDiagnostic => _exportingStudentDiagnostic;
  bool unresolvedLoading(String candidateId) =>
      _unresolvedLoading.contains(candidateId);
  List<ScannerUnresolvedSlot>? unresolvedSlots(String candidateId) =>
      _unresolvedSlots[candidateId];
  bool identitySkipped(String candidateId, int slot) =>
      _identitySkipped.contains(_identitySlotKey(candidateId, slot));
  bool identityBusy(String candidateId, int slot) =>
      _identityBusy.contains(_identitySlotKey(candidateId, slot));
  String? identityError(String candidateId, int slot) =>
      _identityErrors[_identitySlotKey(candidateId, slot)];

  bool get canStart =>
      connected &&
      _scanner != null &&
      _repository != null &&
      _profile != null &&
      recognitionReady &&
      selectedTarget?.status == ScannerTargetStatus.ready &&
      (_stage == ScanSessionStage.idle || _stage == ScanSessionStage.terminal);

  bool get canExportStudentDiagnostic =>
      !_exportingStudentDiagnostic &&
      _stage == ScanSessionStage.terminal &&
      _outcome == 'completed' &&
      _session?.kind == ScannerKind.student &&
      _repository != null &&
      _profile != null &&
      _candidates.values.any((item) => item.kind == ScannerKind.student);

  /// 일시정지 중일 때 보일 문구(FD-142). 진행 중이 아니면 null.
  String? get pausedLabel {
    if (_stage != ScanSessionStage.running ||
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

  // ---- 수명 ----

  /// 첫 화면이 붙을 때 한 번: 연결 · 전역 창 리스너, 이벤트 구독, 준비 읽기. 두 번째부터는 아무것도 하지 않는다.
  void ensureStarted() {
    if (_started || _disposed) return;
    _started = true;
    _service.state.addListener(_connectionChanged);
    final connectedTarget = _connectedTarget;
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
    refreshPreparation();
  }

  /// 호출 대상 서비스만 바꾼다. 이벤트 구독과 연결 리스너는 처음 서비스에 남는다(FE8-f1 이전 화면과 같다).
  void updateService(AppService service) => _service = service;

  /// 앱 전역 연결(FE8-d)을 바꾼다. 알리지 않는다(화면의 didUpdateWidget에서 부른다).
  void updateConnectedTarget(ConnectedTargetController? connectedTarget) {
    if (identical(_connectedTarget, connectedTarget)) return;
    _connectedTarget?.removeListener(_connectedTargetChanged);
    _connectedTarget = connectedTarget;
    connectedTarget?.addListener(_connectedTargetChanged);
    if (connectedTarget != null) _adoptConnectedTarget();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_companionActive) unawaited(windowDockService.restore());
    _service.state.removeListener(_connectionChanged);
    _connectedTarget?.removeListener(_connectedTargetChanged);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _update(VoidCallback change) {
    change();
    if (!_disposed) notifyListeners();
  }

  // ---- 대상 창 ----

  /// 앱 전역 연결 대상(FE8-d)을 이 세션의 선택으로 받는다. 목록에 없으면 넣고, 같은 id면 새 창 정보로 바꾼다.
  void _adoptConnectedTarget() {
    final connected = _connectedTarget?.target;
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
    if (_disposed) return;
    _update(_adoptConnectedTarget);
  }

  /// 드롭다운에서 고른 창. 앱 전역 연결이 있으면 그 창에 연결하고, 세션 선택은 리스너가 맞춘다.
  void chooseTarget(String? targetId) {
    final connectedTarget = _connectedTarget;
    final target = _targets.where((item) => item.id == targetId).firstOrNull;
    if (connectedTarget == null || target == null) {
      _update(() => _targetId = targetId);
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
    final connectedTarget = _connectedTarget;
    if (connectedTarget == null) return target?.id;
    if (target != null) connectedTarget.connect(target);
    return connectedTarget.target?.id;
  }

  /// 스캔 종류. 학생이면 [studentScanMode]로 한 명/전체를 고른다(재고를 고를 때는 학생 모드를 그대로 둔다).
  void selectKind(ScannerKind kind, {StudentScanMode? studentScanMode}) {
    _update(() {
      _kind = kind;
      if (kind == ScannerKind.student && studentScanMode != null) {
        _studentScanMode = studentScanMode;
      }
    });
  }

  void selectInventoryScanProfile(InventoryScanProfile profile) =>
      _update(() => _inventoryScanProfile = profile);

  // ---- 스캔 탭 고르기(FE8-g1) ----

  /// 학생 칸(전체/1명). 아이템 선택은 풀린다.
  void pickStudent(StudentScanMode mode) =>
      _update(() => _pick = ScanPick.student(mode));

  /// 아이템 칸 하나를 넣거나 뺀다. 학생 선택은 풀린다. 마지막 칸을 빼면 아무것도 고르지 않은 상태다.
  void toggleInventoryPick(InventoryScanProfile profile) => _update(() {
    final picked = {..._pick.inventoryScanProfiles};
    if (!picked.remove(profile)) picked.add(profile);
    _pick = picked.isEmpty ? const ScanPick.none() : ScanPick.inventory(picked);
  });

  /// 아이템 [profiles]를 모두 고른다(`모두 선택`).
  void pickInventory(Iterable<InventoryScanProfile> profiles) =>
      _update(() => _pick = ScanPick.inventory(profiles));

  /// 고른 종류를 모두 푼다(`고른 종류 해제`).
  void clearPick() => _update(() => _pick = const ScanPick.none());

  /// 고른 것이 학생 하나 또는 아이템 한 종류면 그 종류로 [start]한다(시작 동작 그대로). 아무것도 고르지 않았거나
  /// 아이템을 여러 종류 골랐으면 시작하지 않는다(여러 종류 차례 스캔은 FE8-g3, FD-143).
  Future<void> startPick() async {
    final pick = _pick;
    final studentScanMode = pick.studentScanMode;
    if (studentScanMode != null) {
      selectKind(ScannerKind.student, studentScanMode: studentScanMode);
    } else if (pick.inventoryScanProfiles.length == 1) {
      selectKind(ScannerKind.inventory);
      selectInventoryScanProfile(pick.inventoryScanProfiles.single);
    } else {
      return;
    }
    await start();
  }

  void _connectionChanged() {
    if (_disposed) return;
    _update(() {
      if (!connected &&
          (_stage == ScanSessionStage.running ||
              _stage == ScanSessionStage.cancelling)) {
        _sessionError =
            'Backend disconnected. Reconnect, then recover the active snapshot.';
      }
    });
  }

  Future<void> refreshPreparation() async {
    final scanner = _scanner;
    if (scanner == null) {
      _update(() {
        _targetsLoading = false;
        _readinessLoading = false;
        _targetError = 'Scanner service is unavailable.';
        _readinessError = 'Scanner service is unavailable.';
      });
      return;
    }
    _update(() {
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
      if (!_disposed) _update(() => _readiness = readiness);
    } catch (error) {
      if (!_disposed) {
        _update(() => _readinessError = 'Readiness failed: $error');
      }
    } finally {
      if (!_disposed) _update(() => _readinessLoading = false);
    }
    try {
      final targets = await scanner.listScannerTargets();
      if (_disposed) return;
      _connectedTarget?.updateTargets(targets);
      _update(() {
        _targets = targets;
        if (!targets.any((item) => item.id == _targetId)) _targetId = null;
      });
    } catch (error) {
      if (!_disposed) {
        _update(() => _targetError = 'Target list failed: $error');
      }
    } finally {
      if (!_disposed) _update(() => _targetsLoading = false);
    }
  }

  // ---- 계정 · 저장소 revision ----

  Future<void> selectProfile(RepositoryProfile profile) async {
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
    _update(() {
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
        _service.listStudents(),
        _service.listInventoryItems(),
      ]);
      if (_disposed || _profile?.id != profile.id) return;
      final state = results[0] as RepositoryState;
      final catalog = results[1] as List<StudentCatalogEntry>;
      final inventoryCatalog = results[2] as InventoryCatalogResult;
      _update(() {
        _acceptRepositoryState(state);
        _studentCatalog = {for (final item in catalog) item.studentId: item};
        _inventoryCatalog = inventoryCatalog.items;
      });
    } catch (error) {
      if (!_disposed && _profile?.id == profile.id) {
        final failure =
            '프로필 현재값을 다시 읽지 못했습니다: ${repositoryLoadErrorText(error)}';
        _update(() {
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

  /// state 응답을 cache·권위 revision·profile 표시에 반영한다(_update 안에서 부른다). 같은 계정의 더 낮은
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

  /// commit 응답 revision을 권위값으로 받는다(_update 안에서 부른다). state를 다시 읽지 못해도 다음 순차
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
    if (!_disposed && _profile?.id == profileId) {
      _update(() => _acceptRepositoryState(state));
    }
    return state;
  }

  // ---- 세션 ----

  Future<void> start() async {
    final scanner = _scanner;
    final target = selectedTarget;
    if (!canStart || scanner == null || target == null) return;
    final startedAt = now();
    _update(() {
      _stage = ScanSessionStage.starting;
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
        if (!_disposed && _profile?.id == baseProfileId) {
          _update(
            () => _candidateNotice =
                '스캔 시작 전 현재값을 다시 읽지 못했습니다: ${repositoryLoadErrorText(error)}',
          );
        }
      }
      if (_disposed) return;
    }
    // 학생 스캔은 백그라운드다(FE8-g2, 시안 Scan-Student-Run): 플래너 창을 줄여 붙이지 않고 스캔 탭 진행 화면 · 머리글로
    // 보인다. 아이템 진행 창(dock)은 FE8-g3.
    try {
      final session = await scanner.startScannerSession(
        _kind,
        target.id,
        profileId: _profile?.id,
        studentScanMode: _studentScanMode,
        inventoryScanProfile: _kind == ScannerKind.inventory
            ? _inventoryScanProfile
            : null,
      );
      if (_disposed) return;
      _update(() {
        _session = session;
        _recentDetails[_sessionKey(
          session.id,
          session.generation,
        )] = ScanRecentDetail(
          startedAt: startedAt,
          inventoryScanProfile: session.kind == ScannerKind.inventory
              ? _inventoryScanProfile
              : null,
        );
        _stage = ScanSessionStage.running;
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
      if (!_disposed) {
        _update(() {
          _stage = ScanSessionStage.idle;
          _sessionError = 'Could not start scan: $error';
        });
      }
    }
  }

  Future<void> cancel() async {
    final scanner = _scanner;
    final session = _session;
    if (scanner == null ||
        session == null ||
        _stage != ScanSessionStage.running) {
      return;
    }
    _update(() {
      _stage = ScanSessionStage.cancelling;
      _sessionError = null;
    });
    _publishCompanion();
    try {
      await scanner.cancelScannerSession(session);
      if (!_disposed) _update(() {});
    } catch (error) {
      if (!_disposed) {
        _update(() {
          _stage = ScanSessionStage.running;
          _sessionError = 'Cancel request failed: $error';
        });
      }
    }
  }

  /// FB-10a 일시정지 요청. 응답이 `pauseRequested`면 "멈추는 중"으로 두고, 실제 멈춤은 `paused` 이벤트로 바꾼다.
  /// `paused` 이벤트가 응답보다 먼저 와도 상태를 되돌리지 않는다.
  Future<void> pause() async {
    final scanner = _scanner;
    final session = _session;
    if (scanner == null ||
        session == null ||
        _stage != ScanSessionStage.running ||
        _control != ScannerControlState.running ||
        _controlBusy) {
      return;
    }
    _update(() {
      _controlBusy = true;
      _sessionError = null;
    });
    _publishCompanion();
    try {
      final control = await scanner.pauseScannerSession(session);
      if (_disposed || !identical(_session, session)) return;
      _update(() {
        if (_stage != ScanSessionStage.running ||
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
      if (!_disposed) {
        _update(() => _sessionError = '일시정지 요청이 실패했습니다: $error');
      }
    } finally {
      if (!_disposed) {
        _update(() => _controlBusy = false);
        _publishCompanion();
      }
    }
  }

  /// FB-10a 이어서. 받아들여지면 `resumed` 이벤트와 함께 진행으로 돌아간다. 대상 창이 준비되지 않아 거절되면
  /// 일시정지에 남고 사유만 바꾼다(이벤트 없이 응답으로만 온다).
  Future<void> resume() async {
    final scanner = _scanner;
    final session = _session;
    if (scanner == null ||
        session == null ||
        _stage != ScanSessionStage.running ||
        _control != ScannerControlState.paused ||
        _controlBusy) {
      return;
    }
    _update(() {
      _controlBusy = true;
      _sessionError = null;
    });
    _publishCompanion();
    try {
      final control = await scanner.resumeScannerSession(session);
      if (_disposed || !identical(_session, session)) return;
      _update(() {
        // 받아들여졌으면 백엔드가 `resumed` 이벤트를 응답보다 먼저 낸다. 진행으로의 전환은 그 이벤트만 따른다
        // (그 사이 새 `paused`가 왔다면 응답으로 덮지 않는다).
        if (_stage != ScanSessionStage.running || control.accepted) return;
        if (control.controlState == ScannerControlState.paused &&
            _control == ScannerControlState.paused) {
          _pauseReason = control.reason;
        }
      });
    } catch (error) {
      if (!_disposed) {
        _update(() => _sessionError = '이어서 요청이 실패했습니다: $error');
      }
    } finally {
      if (!_disposed) {
        _update(() => _controlBusy = false);
        _publishCompanion();
      }
    }
  }

  Future<void> recoverSnapshot() async {
    final scanner = _scanner;
    final session = _session;
    if (scanner == null || session == null || _recovering) return;
    _update(() {
      _recovering = true;
      _sessionError = null;
    });
    try {
      final snapshot = await scanner.scannerSnapshot(session);
      if (_disposed) return;
      _update(() {
        _resetProjection();
        _stage = ScanSessionStage.running;
        for (final candidate in snapshot.candidates) {
          _keepCandidate(candidate);
        }
        for (final event in snapshot.events) {
          _applyEvent(event, recordRecent: false);
        }
        if (snapshot.terminal != null && _stage != ScanSessionStage.terminal) {
          _outcome = snapshot.terminal;
          _stage = ScanSessionStage.terminal;
        }
        // FB-10a: 이벤트 틈·거절된 이어서의 사유 변경은 snapshot의 제어 상태가 권위값이다.
        _control = snapshot.controlState == ScannerControlState.terminal
            ? ScannerControlState.running
            : snapshot.controlState;
        _pauseReason = snapshot.reason;
        if (_stage == ScanSessionStage.terminal) _recordRecent();
      });
    } catch (error) {
      if (!_disposed) {
        _update(() {
          _sessionError =
              'Snapshot recovery failed; the previous projection was kept: $error';
        });
      }
    } finally {
      if (!_disposed) _update(() => _recovering = false);
    }
  }

  Future<void> exportStudentDiagnostic() async {
    final scanner = _scanner;
    final repository = _repository;
    final profile = _profile;
    final session = _session;
    if (!canExportStudentDiagnostic ||
        scanner == null ||
        repository == null ||
        profile == null ||
        session == null) {
      return;
    }
    _update(() {
      _exportingStudentDiagnostic = true;
      _candidateNotice = null;
    });
    try {
      final results = await Future.wait<Object>([
        scanner.scannerSnapshot(session),
        retryRepositoryBusy(() => repository.loadRepositoryState(profile.id)),
      ]);
      final generatedAt = now();
      final document = buildStudentScanDiagnosticDocument(
        session: session,
        snapshot: results[0] as ScannerSessionSnapshot,
        repositoryState: results[1] as RepositoryState,
        generatedAt: generatedAt,
      );
      final path = await studentScanDiagnosticFileService.save(
        suggestedName: defaultStudentScanDiagnosticFileName(
          session,
          generatedAt,
        ),
        contents: encodeStudentScanDiagnosticDocument(document),
      );
      if (_disposed || path == null) return;
      _update(() {
        _acceptRepositoryState(results[1] as RepositoryState);
        _candidateNotice = '학생 스캔 진단 파일을 저장했습니다.';
      });
    } catch (error) {
      if (!_disposed) {
        _update(() => _candidateNotice = '학생 스캔 진단 추출 실패: $error');
      }
    } finally {
      if (!_disposed) _update(() => _exportingStudentDiagnostic = false);
    }
  }

  // ---- 이벤트 ----

  void _handleStreamError(Object error, StackTrace stackTrace) {
    if (_disposed || _session == null) return;
    _update(
      () => _sessionError = 'Scanner event stream needs recovery: $error',
    );
    unawaited(recoverSnapshot());
  }

  void _handleEvent(ScannerEvent event) {
    if (_disposed) return;
    if (_stage == ScanSessionStage.starting && _session == null) {
      _pendingStartEvents.add(event);
      return;
    }
    final session = _session;
    if (session == null ||
        event.sessionId != session.id ||
        event.generation != session.generation ||
        _stage == ScanSessionStage.terminal) {
      return;
    }
    _update(() => _applyEvent(event));
    if (_companionActive) {
      _publishCompanion();
      if (event.eventKind == ScannerEventKind.terminal) {
        unawaited(_closeCompanion());
      }
    }
  }

  void _publishCompanion() {
    if (!_companionActive) return;
    final target = selectedTarget;
    final feedback = _liveStudentFeedback;
    onCompanionChanged?.call(
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
        cancelling: _stage == ScanSessionStage.cancelling,
        onCancel: _stage == ScanSessionStage.running
            ? () => unawaited(cancel())
            : null,
        pausedLabel: pausedLabel,
        pauseRequested:
            _stage == ScanSessionStage.running &&
            _control == ScannerControlState.pauseRequested,
        onPause:
            _stage == ScanSessionStage.running &&
                _control == ScannerControlState.running &&
                !_controlBusy
            ? () => unawaited(pause())
            : null,
        onResume:
            _stage == ScanSessionStage.running &&
                _control == ScannerControlState.paused &&
                !_controlBusy
            ? () => unawaited(resume())
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

  Future<void> _closeCompanion() async {
    if (!_companionActive) return;
    _companionActive = false;
    try {
      await windowDockService.restore();
    } finally {
      if (!_disposed) onCompanionChanged?.call(null);
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
          _observedStudentIds
            ..remove(studentId)
            ..insert(0, studentId);
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
        _stage = ScanSessionStage.terminal;
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

  // ---- 인벤토리 미식별 칸 ----

  String _identitySlotKey(String candidateId, int slot) => '$candidateId:$slot';

  Future<void> _loadUnresolvedSlots(ScannerCandidate candidate) async {
    final scanner = _scanner;
    final session = _sessionFor(candidate);
    if (scanner == null || session == null || _disposed) return;
    _update(() {
      _unresolvedLoading.add(candidate.id);
      _candidateErrors.remove(candidate.id);
    });
    try {
      final result = await scanner.scannerUnresolvedSlots(session, candidate);
      if (_disposed) return;
      final current = _candidates[candidate.id];
      if (current == null || current.revision != result.candidateRevision) {
        return;
      }
      _update(() => _unresolvedSlots[candidate.id] = result.slots);
    } catch (error) {
      if (!_disposed) {
        _update(() {
          _candidateErrors[candidate.id] = '미식별 슬롯을 불러오지 못했습니다: $error';
        });
      }
    } finally {
      if (!_disposed) _update(() => _unresolvedLoading.remove(candidate.id));
    }
  }

  Future<void> assignInventoryIdentity(
    ScannerCandidate candidate,
    ScannerUnresolvedSlot slot,
    String identity,
    bool persist,
  ) async {
    final scanner = _scanner;
    final session = _sessionFor(candidate);
    if (scanner == null || session == null) return;
    final key = _identitySlotKey(candidate.id, slot.slot);
    _update(() {
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
      if (_disposed) return;
      _update(() {
        _keepCandidate(result.candidate);
        _unresolvedSlots[candidate.id] = result.slots;
        _identitySkipped.remove(key);
        _identityErrors.remove(key);
        _candidateNotice = persist
            ? '슬롯 ${slot.slot + 1} identity를 영구 승인 샘플로 저장했습니다.'
            : '슬롯 ${slot.slot + 1} identity를 이번 실행의 세션 은행에 추가했습니다.';
      });
    } catch (error) {
      if (!_disposed) {
        _update(() {
          _identityErrors[key] = 'identity 지정 실패: $error';
        });
      }
    } finally {
      if (!_disposed) _update(() => _identityBusy.remove(key));
    }
  }

  Future<void> skipInventoryIdentity(
    ScannerCandidate candidate,
    ScannerUnresolvedSlot slot,
  ) async {
    _update(() {
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

  // ---- 학생 검토 ----

  Future<void> revalidateStudentCandidate(
    ScannerCandidate candidate,
    Map<String, dynamic> payload,
    Map<int, int> relationshipRanks,
    Set<String> confirmedFields,
  ) async {
    final scanner = _scanner;
    final session = _sessionFor(candidate);
    if (scanner == null || session == null) return;
    _update(() {
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
      if (_disposed) return;
      _update(() {
        _keepCandidate(revised);
        _candidateErrors.remove(candidate.id);
        _candidateNotice = '수정값을 revision ${revised.revision}에서 재검증했습니다.';
      });
    } catch (error) {
      if (!_disposed) {
        final message = '재검증 실패: $error';
        _update(() {
          _candidateErrors[candidate.id] = message;
          _candidateNotice = message;
        });
      }
    } finally {
      if (!_disposed) _update(() => _busyCandidateIds.remove(candidate.id));
    }
  }

  Future<void> holdStudentCandidate(ScannerCandidate candidate) async {
    _update(() {
      _candidateNotice = '후보를 보류했습니다. 확정된 현재값은 변경되지 않았습니다.';
    });
  }

  Future<void> discardStudentCandidate(ScannerCandidate candidate) async {
    final scanner = _scanner;
    final session = _sessionFor(candidate);
    if (scanner == null || session == null) return;
    _update(() {
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
      if (_disposed) return;
      _update(() {
        _candidates.remove(candidate.id);
        _candidateErrors.remove(candidate.id);
        _resolvedCandidates[_candidateKey(candidate)] = false;
        _releaseStudentCandidateImages(candidate);
        _candidateNotice = '후보를 폐기했습니다. 확정된 현재값은 변경되지 않았습니다.';
      });
    } catch (error) {
      if (!_disposed) {
        final message = '후보 폐기 실패: $error';
        _update(() {
          _candidateErrors[candidate.id] = message;
          _candidateNotice = message;
        });
      }
    } finally {
      if (!_disposed) _update(() => _busyCandidateIds.remove(candidate.id));
    }
  }

  /// FB-10c: 승인·폐기·적용 성공 뒤 그 학생 후보의 검토 이미지(crop)를 이 세션의 보관물(지금 후보, 최근 스캔 요약,
  /// 시작 전 버퍼 이벤트)에서 지운다. 백엔드는 같은 시점에 자기 사본만 지우고 이미 보낸 사본은 회수하지 못한다.
  /// 보류·수정·재검증·적용 실패 동안과 다른 후보의 crop은 그대로 둔다. _update 안에서 부른다.
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
      onRecentChanged?.call(List<ScannerRecentSummary>.unmodifiable(_recent));
    }
  }

  String _newApplyKey(ScannerCandidate approved) {
    _applyIntentSequence += 1;
    final stamp = now().microsecondsSinceEpoch.toRadixString(36);
    return 'scan-apply-${approved.id}-${approved.revision}-'
        '$stamp-$_applyIntentSequence';
  }

  /// 학생 결과 적용은 한 번에 하나씩 차례로 한다(FD-144 순차 적용). 뒤 적용은 앞 commit 응답 revision을
  /// expected로 쓴다. 기다리는 동안에도 후보 버튼은 바쁨으로 표시한다.
  Future<void> applyStudentCandidate(ScannerCandidate candidate) {
    final tappedProfileId = _profile?.id;
    _update(() => _busyCandidateIds.add(candidate.id));
    final run = _applyQueue.then((_) async {
      try {
        if (!_disposed) {
          await _applyStudentCandidateInOrder(candidate, tappedProfileId);
        }
      } finally {
        if (!_disposed) _update(() => _busyCandidateIds.remove(candidate.id));
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
      _update(() => _candidateNotice = '적용 차례를 기다리는 동안 계정이 바뀌어 적용하지 않았습니다.');
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
      _update(() {
        const message = '적용에 필요한 프로필 또는 세션 상태가 없습니다.';
        _candidateErrors[candidate.id] = message;
        _candidateNotice = message;
      });
      return;
    }
    final slot = scanPendingApplySlot(session, candidate.id);
    if (retry == null) _pendingApplies.remove(slot);
    // 안내 문구는 지우지 않는다: 앞 적용의 "다시 적용하면 같은 요청을…" 안내가 이 적용의 결과가 나올 때까지 남는다.
    _update(() => _busyCandidateIds.add(candidate.id));
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
        if (_disposed) return;
        final created = ScanPendingApply(
          session: session,
          candidate: approved,
          profileId: profile.id,
          expectedRepositoryRevision: expected,
          idempotencyKey: _newApplyKey(approved),
        );
        _pendingApplies[slot] = created;
        request = created;
        _update(() {
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
      if (_disposed) return;
      final committedRevision = committed['revision'];
      _update(() {
        if (committedRevision is int) {
          _acceptCommittedRevision(request.profileId, committedRevision);
        }
        if (_isShownCandidate(candidate)) {
          _candidates.remove(candidate.id);
          _candidateErrors.remove(candidate.id);
        }
        _resolvedCandidates[_candidateKey(candidate)] = true;
        _releaseStudentCandidateImages(candidate);
        _candidateNotice =
            '결과를 repository revision $committedRevision에 적용했습니다.';
      });
      try {
        await _reloadRepositoryState(request.profileId);
      } catch (error) {
        if (!_disposed) {
          _update(
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
      if (_disposed) return;
      try {
        await _reloadRepositoryState(profile.id);
      } catch (_) {}
      if (_disposed) return;
      final wasRetry = retry != null;
      _update(() {
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
      if (!_disposed) _update(() => _busyCandidateIds.remove(candidate.id));
    }
  }

  // ---- 투영 · 최근 ----

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
    _observedStudentIds.clear();
    _candidateErrors.clear();
    _unresolvedSlots.clear();
    _unresolvedLoading.clear();
    _identityBusy.clear();
    _identitySkipped.clear();
    _identityErrors.clear();
  }

  void _recordRecent() {
    final session = _session;
    final target = selectedTarget;
    if (session == null) return;
    _lastEndedSession = session;
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
    // 최근 기록에서 밀려난 세션의 보탬은 버린다(지금 세션은 남긴다).
    final kept = {
      _sessionKey(session.id, session.generation),
      for (final item in _recent) _sessionKey(item.sessionId, item.generation),
    };
    _recentDetails.removeWhere((key, _) => !kept.contains(key));
    onRecentChanged?.call(List<ScannerRecentSummary>.unmodifiable(_recent));
  }

  static String _sessionKey(String sessionId, int generation) =>
      '$sessionId#$generation';

  static String _candidateKey(ScannerCandidate candidate) =>
      '${candidate.sessionId}#${candidate.generation}#${candidate.id}';

  void openRecent(ScannerRecentSummary item) {
    final recentTargetId = _recentTargetId(item);
    _update(() {
      _session = item.session;
      _kind = item.kind;
      _targetId = recentTargetId;
      _stage = ScanSessionStage.terminal;
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

  // ---- 인계 ----

  /// 후보를 다른 탭(학생 · 인벤토리 · 전술 로비)으로 넘길 세션. 후보가 지금 세션 · 종류 · payload 형식과 맞지 않으면
  /// 세션 오류를 띄우고 null.
  ScannerSession? handoffSession(ScannerCandidate candidate) {
    final session = _session;
    if (session == null ||
        candidate.sessionId != session.id ||
        candidate.generation != session.generation ||
        candidate.kind != session.kind ||
        !_payloadMatchesKind(candidate)) {
      _update(() => _sessionError = 'Candidate kind or payload mismatch.');
      return null;
    }
    return session;
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
}
