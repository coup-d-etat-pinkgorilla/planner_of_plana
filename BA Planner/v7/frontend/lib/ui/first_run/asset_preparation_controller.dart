// F2 첫 실행 · 설정의 인식 캐시 준비 상태(화면 없음 — F3b 체크리스트 ①·②와 F3e 설정 줄이 쓴다).
//
// - 진행 단위는 번들이다. [AssetPreparationProgress.total]이 null이면 분모 · % · 남은 시간을 숨긴다
//   ([AssetPreparationProgress.fraction]도 null). 작업 전체의 고정 분모(예: 1,330)는 만들지 않는다.
// - 결과 수(created · reused · failed)의 null은 모름이다. 0으로 바꾸지 않는다.
// - 취소는 요청일 뿐이다: [AssetPreparationViewState.cancelRequested] 동안 busy를 유지하고 terminal 이벤트나 status가
//   작업이 끝났다고 알릴 때 푼다.
// - 연결이 끊기거나 백엔드가 다시 시작되면 지금 작업을 버리고(되살리지 않음) 연결 뒤 status를 다시 읽는다.
// - dispose 뒤에는 늦은 응답 · 이벤트를 모두 버린다(epoch). 지금 작업이 아닌 이벤트도 버린다.
// - JP 데이터 갱신 필요 여부는 말하지 않는다(`jp_update_required`는 항상 null — 배포 업데이터 몫).
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/app_service.dart';
import '../../services/asset_preparation_service.dart';

/// 준비 중 진행(단계 안의 번들 수).
@immutable
class AssetPreparationProgress {
  const AssetPreparationProgress({
    required this.stage,
    required this.done,
    required this.total,
  });

  final AssetPrepareStage stage;

  /// 이 단계에서 끝낸 번들 수.
  final int done;

  /// 이 단계의 번들 분모. null이면 분모를 보이지 않는다.
  final int? total;

  bool get hasDenominator {
    final value = total;
    return value != null && value > 0;
  }

  /// 0..1. 분모가 없으면 null(% · 남은 시간 숨김).
  double? get fraction {
    final value = total;
    if (value == null || value <= 0) return null;
    return (done / value).clamp(0.0, 1.0);
  }
}

/// 끝난 준비의 결과. null 수는 모름이다.
@immutable
class AssetPreparationOutcome {
  const AssetPreparationOutcome({
    required this.state,
    required this.created,
    required this.reused,
    required this.failed,
    required this.available,
    required this.reasonCodes,
  });

  factory AssetPreparationOutcome.fromJob(AssetPrepareJob job) =>
      AssetPreparationOutcome(
        state: job.state,
        created: job.created,
        reused: job.reused,
        failed: job.failed,
        available: job.available,
        reasonCodes: job.reasonCodes,
      );

  final AssetPrepareJobState state;
  final int? created;
  final int? reused;
  final int? failed;
  final int available;
  final List<AssetPrepareReasonCode> reasonCodes;

  bool get succeeded => state == AssetPrepareJobState.succeeded;
}

@immutable
class AssetPreparationViewState {
  const AssetPreparationViewState({
    this.loaded = false,
    this.loading = false,
    this.gameDir,
    this.cache,
    this.metadata,
    this.job,
    this.lastResult,
    this.backendBusy = false,
    this.scannerBusy = false,
    this.cancelRequested = false,
    this.requestInFlight = false,
    this.errorCode,
    this.errorReason,
  });

  /// status를 한 번이라도 읽었다(연결이 끊기면 다시 false).
  final bool loaded;
  final bool loading;
  final AssetGameDir? gameDir;
  final AssetCacheStatus? cache;
  final AssetPrepareMetadata? metadata;

  /// 진행 중 작업(running · cancelling). 끝나면 null이고 결과는 [lastResult]다.
  final AssetPrepareJob? job;

  /// 마지막 끝난 작업(이번 연결의 terminal, 없으면 저장된 status `last_result`).
  final AssetPrepareJob? lastResult;

  /// status `busy`(준비 · 폴더 변경이 실행 권한을 갖고 있다).
  final bool backendBusy;

  /// status `scanner_busy`(스캔 중 — 준비 · 폴더 변경 불가).
  final bool scannerBusy;
  final bool cancelRequested;
  final bool requestInFlight;

  /// 마지막 요청이 거절된 코드. 다음 요청이 성공하면 지운다.
  final AssetPrepareErrorCode? errorCode;

  /// `invalid_game_dir` 거절의 폴더 이유(저장되지 않은 폴더).
  final AssetGameDirReason? errorReason;

  bool get preparing {
    final value = job;
    return value != null && !value.state.isTerminal;
  }

  bool get busy =>
      preparing || backendBusy || requestInFlight || cancelRequested;

  String? get folderPath => gameDir?.path;
  AssetGameDirSource? get folderSource => gameDir?.source;
  bool get folderValid => gameDir?.valid == true;

  /// 지금 폴더가 쓸 수 없는 이유(status). 거절된 지정의 이유는 [errorReason].
  AssetGameDirReason? get folderReason => gameDir?.reason;

  AssetPreparationProgress? get progress {
    final value = job;
    if (value == null || value.state.isTerminal) return null;
    return AssetPreparationProgress(
      stage: value.stage,
      done: value.done,
      total: value.total,
    );
  }

  AssetPreparationOutcome? get outcome {
    final value = lastResult;
    return value == null ? null : AssetPreparationOutcome.fromJob(value);
  }

  /// 인식 캐시가 다 준비됐다.
  bool get ready => cache?.state == AssetCacheState.ready;

  bool get canStart => loaded && folderValid && !busy && !scannerBusy;

  /// 다시 시도할 수 있다(partial 캐시, 또는 마지막 결과가 partial · failed · cancelled).
  bool get canRetry {
    if (!canStart) return false;
    if (cache?.state == AssetCacheState.partial) return true;
    final state = lastResult?.state;
    return state == AssetPrepareJobState.partial ||
        state == AssetPrepareJobState.failed ||
        state == AssetPrepareJobState.cancelled;
  }

  bool get canCancel =>
      preparing &&
      !cancelRequested &&
      job?.state == AssetPrepareJobState.running;

  bool get canChangeFolder => loaded && !busy && !scannerBusy;
}

class AssetPreparationController extends ChangeNotifier {
  AssetPreparationController(
    this._service, {
    ValueListenable<AppServiceState>? appState,
  }) : _appState = appState,
       _connected =
           appState == null ||
           appState.value.connection == BackendConnection.connected {
    _subscription = _service.assetPrepareEvents.listen(
      _onEvent,
      onError: _onEventError,
    );
    _appState?.addListener(_onAppState);
  }

  final AssetPreparationService _service;
  final ValueListenable<AppServiceState>? _appState;
  late final StreamSubscription<AssetPrepareEvent> _subscription;
  AssetPreparationViewState _value = const AssetPreparationViewState();
  bool _connected;
  bool _disposed = false;
  int _epoch = 0;
  int _starts = 0;
  AssetPrepareJobRef? _jobRef;

  /// 이번 연결에서 본 terminal(저장 실패 `result_not_saved`여도 남는다).
  AssetPrepareJob? _sessionResult;
  final List<AssetPrepareEvent> _startBuffer = [];

  AssetPreparationViewState get value => _value;

  void _set(AssetPreparationViewState next) {
    if (_disposed) return;
    _value = next;
    notifyListeners();
  }

  AssetPreparationViewState _copy({
    bool? loaded,
    bool? loading,
    AssetGameDir? gameDir,
    AssetCacheStatus? cache,
    AssetPrepareMetadata? metadata,
    AssetPrepareJob? Function()? job,
    AssetPrepareJob? Function()? lastResult,
    bool? backendBusy,
    bool? scannerBusy,
    bool? cancelRequested,
    bool? requestInFlight,
    AssetPrepareErrorCode? Function()? errorCode,
    AssetGameDirReason? Function()? errorReason,
  }) {
    final current = _value;
    return AssetPreparationViewState(
      loaded: loaded ?? current.loaded,
      loading: loading ?? current.loading,
      gameDir: gameDir ?? current.gameDir,
      cache: cache ?? current.cache,
      metadata: metadata ?? current.metadata,
      job: job == null ? current.job : job(),
      lastResult: lastResult == null ? current.lastResult : lastResult(),
      backendBusy: backendBusy ?? current.backendBusy,
      scannerBusy: scannerBusy ?? current.scannerBusy,
      cancelRequested: cancelRequested ?? current.cancelRequested,
      requestInFlight: requestInFlight ?? current.requestInFlight,
      errorCode: errorCode == null ? current.errorCode : errorCode(),
      errorReason: errorReason == null ? current.errorReason : errorReason(),
    );
  }

  /// status를 다시 읽는다. 진행 중 작업이 있고 지금 고른 작업이 아니면 그 작업에 붙는다(snapshot cursor).
  Future<void> refresh() async {
    if (_disposed) return;
    final epoch = _epoch;
    _set(_copy(loading: true));
    try {
      final status = await _service.assetPrepareStatus();
      if (epoch != _epoch) return;
      _applyStatus(status);
    } catch (error) {
      if (epoch != _epoch) return;
      _set(_copy(loading: false, errorCode: () => _codeOf(error)));
    }
  }

  void _applyStatus(AssetPrepareStatus status) {
    final remote = status.job;
    AssetPrepareJob? active;
    if (remote != null && !remote.state.isTerminal) {
      final ref = remote.ref;
      final current = _value.job;
      if (_jobRef != ref) {
        _jobRef = ref;
        active = remote;
        unawaited(_attach(ref));
      } else if (current == null || remote.sequence >= current.sequence) {
        active = remote;
      } else {
        active = current;
      }
    } else if (remote != null && _jobRef == remote.ref) {
      // 이벤트보다 status가 먼저 끝남을 알렸다.
      _sessionResult = remote;
    }
    final session = _sessionResult;
    final saved = status.lastResult;
    _set(
      _copy(
        loaded: true,
        loading: false,
        gameDir: status.gameDir,
        cache: status.cache,
        metadata: status.metadata,
        job: () => active,
        lastResult: () => session ?? saved,
        backendBusy: status.busy,
        scannerBusy: status.scannerBusy,
        cancelRequested: active == null
            ? false
            : (_value.cancelRequested ||
                  active.state == AssetPrepareJobState.cancelling),
      ),
    );
  }

  Future<void> _attach(AssetPrepareJobRef ref) async {
    final epoch = _epoch;
    try {
      final job = await _service.assetPrepareSnapshot(ref);
      if (epoch != _epoch || _jobRef != ref) return;
      _applyJob(job);
    } catch (_) {
      // 이미 끝나 사라졌으면 다음 status가 알려 준다.
      if (epoch == _epoch && _jobRef == ref) unawaited(refresh());
    }
  }

  /// 게임 폴더를 지정한다(null = 자동 탐색). 성공하면 true. 쓸 수 없는 폴더는 저장되지 않고 [AssetPreparationViewState.errorReason]에 이유가 남는다.
  Future<bool> setGameDir(String? path) async {
    if (_disposed) return false;
    final epoch = _epoch;
    _set(_copy(requestInFlight: true));
    try {
      final status = await _service.setAssetGameDir(path);
      if (epoch != _epoch) return false;
      _set(
        _copy(
          requestInFlight: false,
          errorCode: () => null,
          errorReason: () => null,
        ),
      );
      _applyStatus(status);
      return true;
    } catch (error) {
      if (epoch != _epoch) return false;
      final failure = AssetPrepareFailure.fromError(error);
      _set(
        _copy(
          requestInFlight: false,
          errorCode: () => _codeOf(error),
          errorReason: () => failure?.reason,
        ),
      );
      return false;
    }
  }

  /// 준비를 시작한다(partial · 실패 뒤 재시도도 같다). 받아들여지면 true.
  Future<bool> start() async {
    if (_disposed) return false;
    final epoch = _epoch;
    _starts += 1;
    _set(_copy(requestInFlight: true));
    try {
      final ref = await _service.startAssetPreparation();
      if (epoch != _epoch) return false;
      _jobRef = ref;
      _sessionResult = null;
      _set(
        _copy(
          requestInFlight: false,
          job: () => AssetPrepareJob.started(ref),
          cancelRequested: false,
          backendBusy: true,
          errorCode: () => null,
          errorReason: () => null,
        ),
      );
      return true;
    } catch (error) {
      if (epoch != _epoch) return false;
      final failure = AssetPrepareFailure.fromError(error);
      _set(
        _copy(
          requestInFlight: false,
          errorCode: () => _codeOf(error),
          errorReason: () => failure?.reason,
        ),
      );
      unawaited(refresh());
      return false;
    } finally {
      if (epoch == _epoch) {
        _starts -= 1;
        if (_starts == 0) {
          final buffered = List<AssetPrepareEvent>.of(_startBuffer);
          _startBuffer.clear();
          buffered.forEach(_onEvent);
        }
      }
    }
  }

  /// 취소를 요청한다. 접수돼도 terminal까지 busy가 남는다.
  Future<bool> cancel() async {
    final ref = _jobRef;
    if (_disposed || ref == null || !_value.preparing) return false;
    final epoch = _epoch;
    _set(_copy(cancelRequested: true));
    try {
      final result = await _service.cancelAssetPreparation(ref);
      if (epoch != _epoch || _jobRef != ref) return false;
      if (!result.cancelRequested) {
        // 이미 끝났다: status로 끝을 확인한다.
        unawaited(refresh());
      }
      return result.cancelRequested;
    } catch (error) {
      if (epoch != _epoch || _jobRef != ref) return false;
      _set(_copy(errorCode: () => _codeOf(error)));
      unawaited(refresh());
      return false;
    }
  }

  void _onEvent(AssetPrepareEvent event) {
    if (_disposed) return;
    if (_starts > 0) {
      _startBuffer.add(event);
      return;
    }
    final ref = _jobRef;
    if (ref == null || !ref.matches(event.job)) return;
    _applyJob(event.job);
  }

  void _applyJob(AssetPrepareJob job) {
    final current = _value.job;
    if (current != null &&
        _jobRef != null &&
        _jobRef!.matches(current) &&
        job.sequence < current.sequence) {
      return;
    }
    if (job.state.isTerminal) {
      final seen = _sessionResult;
      if (!_value.preparing && seen != null && seen.ref == job.ref) {
        // 복구 snapshot 뒤에 온 진짜 terminal(사유 코드가 더 있을 수 있다)만 반영한다.
        if (job.sequence > seen.sequence) {
          _sessionResult = job;
          _set(_copy(lastResult: () => job));
        }
        return;
      }
      _sessionResult = job;
      _set(
        _copy(
          job: () => null,
          lastResult: () => job,
          cancelRequested: false,
          backendBusy: false,
        ),
      );
      // 캐시 상태 · 실행 권한 해제를 status로 확인한다.
      unawaited(refresh());
      return;
    }
    _set(
      _copy(
        job: () => job,
        cancelRequested:
            _value.cancelRequested ||
            job.state == AssetPrepareJobState.cancelling,
      ),
    );
  }

  void _onEventError(Object error) {
    // 빈틈 복구 실패: 작업 cursor가 사라졌다. status로 다시 맞춘다.
    if (_disposed) return;
    unawaited(refresh());
  }

  void _onAppState() {
    final appState = _appState;
    if (appState == null || _disposed) return;
    final connected = appState.value.connection == BackendConnection.connected;
    if (connected == _connected) return;
    _connected = connected;
    _epoch += 1;
    _jobRef = null;
    _sessionResult = null;
    _starts = 0;
    _startBuffer.clear();
    _set(
      AssetPreparationViewState(
        gameDir: _value.gameDir,
        cache: _value.cache,
        metadata: _value.metadata,
        lastResult: _value.lastResult,
      ),
    );
    if (connected) unawaited(refresh());
  }

  static AssetPrepareErrorCode? _codeOf(Object error) =>
      AssetPrepareFailure.fromError(error)?.code ??
      (error is FormatException ? AssetPrepareErrorCode.invalidPayload : null);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _epoch += 1;
    _appState?.removeListener(_onAppState);
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
