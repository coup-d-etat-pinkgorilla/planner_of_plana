import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/app_service.dart';
import '../../services/scanner_service.dart';

/// 게임 창 연결이 왜 풀렸는가(FD-116 (a)). FE8-e의 해제 연출(메뉴 B → A 역전이)이 읽는다.
enum ConnectedTargetRelease {
  /// 사용자가 해제했다.
  user,

  /// 창 목록(주기 확인 또는 화면의 새로고침)에서 그 창이 사라졌다.
  targetMissing,

  /// 창 목록에서 그 창이 `closed`가 되었다.
  targetClosed,

  /// 백엔드 연결이 끊겼다(재시작 포함). 창 id를 다시 믿지 않는다.
  backendDisconnected,
}

/// 앱 전역 게임 창 연결 상태(FE8-d, FD-116 (a)).
///
/// "연결"은 고른 대상 창([ScannerTarget], FB-4의 client 크기·game 포함)을 기억하는 것뿐이다.
/// 백엔드 attach 세션이나 창 dock은 하지 않는다(dock은 지금처럼 전체 학생 스캔 때만).
/// 셸이 하나를 소유하고, 홈·스캔 화면과 머리글 칩이 같은 값을 읽고 쓴다.
///
/// 끊긴 것으로 보는 조건은 [ConnectedTargetRelease]다. 최소화·미지원 상태는 해제하지 않고
/// 창 정보만 새 값으로 바꾼다. 연결된 동안 백엔드가 연결되어 있으면 창 목록을 [pollInterval]마다 확인한다.
class ConnectedTargetController extends ChangeNotifier {
  ConnectedTargetController({
    required ValueListenable<AppServiceState> backendState,
    this._listTargets,
    this.pollInterval = defaultPollInterval,
  }) : _backendState = backendState {
    _backendConnected =
        backendState.value.connection == BackendConnection.connected;
    backendState.addListener(_backendChanged);
  }

  /// 서비스에서 만든다. 스캐너가 없는 서비스면 주기 확인을 하지 않는다.
  factory ConnectedTargetController.forService(
    AppService service, {
    Duration pollInterval = defaultPollInterval,
  }) => ConnectedTargetController(
    backendState: service.state,
    listTargets: _listTargetsOf(service),
    pollInterval: pollInterval,
  );

  static const defaultPollInterval = Duration(seconds: 5);

  /// 연결된 동안 창 목록을 확인하는 간격. [Duration.zero]면 확인하지 않는다.
  final Duration pollInterval;

  ValueListenable<AppServiceState> _backendState;
  Future<List<ScannerTarget>> Function()? _listTargets;
  late bool _backendConnected;
  ScannerTarget? _target;
  ConnectedTargetRelease? _lastRelease;
  Timer? _pollTimer;
  bool _polling = false;
  var _generation = 0;
  bool _disposed = false;

  /// 지금 연결된 게임 창. null = 미연결.
  ScannerTarget? get target => _target;

  bool get isConnected => _target != null;

  /// 마지막 해제 사유. 새로 연결하면 null로 돌아간다.
  ConnectedTargetRelease? get lastRelease => _lastRelease;

  static Future<List<ScannerTarget>> Function()? _listTargetsOf(
    AppService service,
  ) => service is ScannerService
      ? (service as ScannerService).listScannerTargets
      : null;

  /// 셸의 서비스가 바뀌면 새 백엔드로 다시 묶는다. 다른 백엔드의 창 id는 믿지 않으므로 해제한다.
  void rebindService(AppService service) {
    _backendState.removeListener(_backendChanged);
    _backendState = service.state;
    _listTargets = _listTargetsOf(service);
    _backendConnected =
        service.state.value.connection == BackendConnection.connected;
    service.state.addListener(_backendChanged);
    _release(ConnectedTargetRelease.backendDisconnected);
    _syncPolling();
  }

  /// 고른 창에 연결한다. 이미 연결된 창이면 창 정보만 바꾼다.
  void connect(ScannerTarget target) {
    if (_disposed) return;
    final current = _target;
    if (current != null && _sameTarget(current, target)) return;
    _target = target;
    _lastRelease = null;
    _generation += 1;
    notifyListeners();
    _syncPolling();
  }

  /// 사용자 해제.
  void disconnect() => _release(ConnectedTargetRelease.user);

  /// 새로 읽은 창 목록을 반영한다. 연결된 창이 없거나 `closed`면 해제하고, 있으면 창 정보를 바꾼다.
  void updateTargets(List<ScannerTarget> targets) {
    final current = _target;
    if (_disposed || current == null) return;
    final fresh = targets.where((item) => item.id == current.id).firstOrNull;
    if (fresh == null) {
      _release(ConnectedTargetRelease.targetMissing);
    } else if (fresh.status == ScannerTargetStatus.closed) {
      _release(ConnectedTargetRelease.targetClosed);
    } else if (!_sameTarget(current, fresh)) {
      _target = fresh;
      notifyListeners();
    }
  }

  /// 창 목록을 한 번 읽어 반영한다(주기 확인과 같은 경로). 읽기 실패는 연결을 바꾸지 않는다.
  Future<void> refresh() async {
    final listTargets = _listTargets;
    if (_disposed || _polling || listTargets == null) return;
    if (_target == null || !_backendConnected) return;
    final generation = _generation;
    _polling = true;
    try {
      final targets = await listTargets();
      if (_disposed || generation != _generation) return;
      updateTargets(targets);
    } catch (_) {
      // 일시적인 목록 실패로는 해제하지 않는다. 백엔드가 끊기면 연결 상태 변화가 해제한다.
    } finally {
      _polling = false;
    }
  }

  void _release(ConnectedTargetRelease reason) {
    if (_disposed || _target == null) return;
    _target = null;
    _lastRelease = reason;
    _generation += 1;
    notifyListeners();
    _syncPolling();
  }

  void _backendChanged() {
    final connected =
        _backendState.value.connection == BackendConnection.connected;
    final wasConnected = _backendConnected;
    _backendConnected = connected;
    if (wasConnected && !connected) {
      _release(ConnectedTargetRelease.backendDisconnected);
    }
    _syncPolling();
  }

  void _syncPolling() {
    final shouldPoll =
        !_disposed &&
        _target != null &&
        _backendConnected &&
        _listTargets != null &&
        pollInterval > Duration.zero;
    if (!shouldPoll) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    _pollTimer ??= Timer.periodic(pollInterval, (_) => unawaited(refresh()));
  }

  static bool _sameTarget(ScannerTarget a, ScannerTarget b) =>
      a.id == b.id &&
      a.title == b.title &&
      a.status == b.status &&
      a.foreground == b.foreground &&
      a.clientWidth == b.clientWidth &&
      a.clientHeight == b.clientHeight &&
      a.game == b.game;

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    _backendState.removeListener(_backendChanged);
    super.dispose();
  }
}
