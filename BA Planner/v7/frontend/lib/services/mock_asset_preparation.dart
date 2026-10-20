// F2 Mock: 첫 실행 인식 캐시 준비(backend `core/asset_preparation.py`와 같은 의미, 합성 값만).
//
// - 실행 권한 하나: 준비 중이면 새 준비 · 폴더 변경 · 스캔 시작이 `asset_prepare_busy`, 스캔(일시정지 포함) 중이면
//   준비 · 폴더 변경이 `scanner_busy`.
// - start 응답 뒤에 이벤트가 온다(타이머). 진행 단위는 번들: validating(0/null) → icons(0/2 · 2/2) → sprites(1/null) →
//   fonts(1/1) → terminal. 캐시가 이미 ready면 validating 뒤 바로 succeeded(created 0 · reused 전부).
// - 취소는 요청 접수일 뿐이다(state cancelling, 이벤트 없음). 다음 단계에서 cancelled terminal이 오고 수는 null이다.
// - 실패 · 취소는 이전 캐시를 그대로 둔다. partial은 선택 아이콘 일부가 없는 결과이고, 다시 start하면 재시도해 채운다.
// - 폴더: 자동 탐색 폴더 또는 [MockAssetPreparation.validGameDirs]만 쓸 수 있고, 그 밖은 `game_dir_not_found`(또는
//   지정한 이유). 쓸 수 없는 폴더는 저장하지 않는다. null은 자동 탐색으로 되돌린다.
// - [MockAssetPreparation.simulatePatch]는 게임 BundleRevision을 올린다 → 캐시 stale.
// - [MockAssetPreparation.handleBackendRestart]: 진행 중 작업은 사라지고(되살리지 않음) 폴더 설정 · 마지막 저장 결과 ·
//   캐시는 남는다. generation은 새 백엔드처럼 1부터 다시 센다.
import 'dart:async';

import 'asset_preparation_service.dart';
import 'planning_protocol_client.dart' show BackendRemoteException;

enum MockAssetPreparationScenario {
  /// 자동 탐색 폴더가 있고 캐시가 없다(첫 실행 기본).
  firstRun,

  /// 자동 탐색이 폴더를 찾지 못한다(source none) — 폴더 지정이 필요하다.
  noGameDir,

  /// 지난 준비가 끝나 캐시가 ready다.
  ready,

  /// 지난 준비가 일부만 됐다(partial, 선택 아이콘 2개 없음) — 재시도할 수 있다.
  partial,

  /// 패치 전 캐시가 남아 있다(BundleRevision 다름 → stale).
  stale,

  /// 첫 실행 + 다음 준비 한 번이 실패한다(`asset_extract_failed`).
  extractFails,

  /// 첫 실행 + 다음 준비 한 번이 partial로 끝난다(`assets_missing`).
  extractPartial,
}

const mockAssetAutoGameDir = 'C:/Synthetic/Steam/steamapps/common/BlueArchive';
const mockAssetUserGameDir = 'C:/Synthetic/BlueArchive';
const mockAssetCatalogSha256 =
    '0b6cc9486b251fc25a063376c8759aaf2a88d9f254de1a03fae427308e00dd99';

typedef _MockCache = ({
  String bundleRevision,
  int icons,
  int sprites,
  int fonts,
  int failed,
});

BackendRemoteException _error(
  String code,
  String message, [
  Map<String, dynamic> details = const {},
]) => BackendRemoteException(code: code, message: message, details: details);

AssetPrepareJob _copyJob(
  AssetPrepareJob job, {
  int? sequence,
  AssetPrepareJobState? state,
  AssetPrepareStage? stage,
  int? done,
  int? total,
  bool keepTotal = false,
  ({int? created, int available, int? reused, int? failed})? counts,
  List<AssetPrepareReasonCode>? reasonCodes,
}) => AssetPrepareJob(
  jobId: job.jobId,
  generation: job.generation,
  sequence: sequence ?? job.sequence,
  state: state ?? job.state,
  stage: stage ?? job.stage,
  done: done ?? job.done,
  total: keepTotal ? job.total : total,
  created: counts == null ? job.created : counts.created,
  available: counts == null ? job.available : counts.available,
  reused: counts == null ? job.reused : counts.reused,
  failed: counts == null ? job.failed : counts.failed,
  reasonCodes: reasonCodes ?? job.reasonCodes,
);

class MockAssetPreparation implements AssetPreparationService {
  MockAssetPreparation({
    this.scenario = MockAssetPreparationScenario.firstRun,
    this.step = const Duration(milliseconds: 250),
    bool Function()? scannerActive,
    Set<String> validGameDirs = const {mockAssetUserGameDir},
    Map<String, AssetGameDirReason> gameDirReasons = const {},
  }) : _scannerActive = scannerActive ?? (() => false),
       validGameDirs = Set.unmodifiable(validGameDirs),
       gameDirReasons = Map.of(gameDirReasons) {
    _filter = AssetPrepareEventFilter(_snapshotOf);
    _autoAvailable = scenario != MockAssetPreparationScenario.noGameDir;
    _failNext = scenario == MockAssetPreparationScenario.extractFails;
    _partialNext = scenario == MockAssetPreparationScenario.extractPartial;
    switch (scenario) {
      case MockAssetPreparationScenario.ready:
        _cache = _fullCache(_bundleRevision);
        _lastResult = _initialResult(AssetPrepareJobState.succeeded, 16, 0);
      case MockAssetPreparationScenario.partial:
        _cache = _partialCache(_bundleRevision);
        _lastResult = _initialResult(AssetPrepareJobState.partial, 14, 2);
      case MockAssetPreparationScenario.stale:
        _cache = _fullCache('122');
        _lastResult = _initialResult(AssetPrepareJobState.succeeded, 16, 0);
      case MockAssetPreparationScenario.firstRun ||
          MockAssetPreparationScenario.noGameDir ||
          MockAssetPreparationScenario.extractFails ||
          MockAssetPreparationScenario.extractPartial:
        break;
    }
  }

  final MockAssetPreparationScenario scenario;

  /// 이벤트 사이 간격(테스트는 짧게).
  final Duration step;
  final bool Function() _scannerActive;

  /// 사용자가 지정할 수 있는 합성 폴더.
  final Set<String> validGameDirs;

  /// 폴더별 이유(예: `bundle_revision_mismatch`). 바꾸면 다음 status부터 반영된다.
  final Map<String, AssetGameDirReason> gameDirReasons;

  late final AssetPrepareEventFilter _filter;
  late bool _autoAvailable;
  late bool _failNext;
  late bool _partialNext;
  String? _userPath;
  String _bundleRevision = '123';
  _MockCache? _cache;
  AssetPrepareJob? _job;
  AssetPrepareJob? _lastResult;
  bool _cancelRequested = false;
  int _generation = 0;
  int _restarts = 0;
  int _dropProgress = 0;
  Timer? _timer;
  bool _closed = false;

  /// 준비가 실행 권한을 갖고 있다(running · cancelling).
  bool get busy => _job != null && !_job!.state.isTerminal;

  /// 다음 progress 이벤트 [count]개를 보내지 않는다(sequence는 오른다) — 백엔드 큐 합치기로 생기는 빈틈.
  void dropNextProgressEvents(int count) => _dropProgress = count;

  /// 게임 패치: BundleRevision이 오른다(캐시가 있으면 stale).
  void simulatePatch() => _bundleRevision = '${int.parse(_bundleRevision) + 1}';

  /// 자동 탐색 결과를 바꾼다(Steam 설치 제거 · 재설치 흉내).
  set autoGameDirAvailable(bool value) => _autoAvailable = value;

  /// 백엔드 재시작: 진행 중 작업은 사라지고 되살리지 않는다.
  void handleBackendRestart() {
    _timer?.cancel();
    _timer = null;
    _job = null;
    _cancelRequested = false;
    _generation = 0;
    _restarts += 1;
    _filter.reset();
  }

  String _jobId(int generation) =>
      'f2d${_restarts.toRadixString(16).padLeft(5, '0')}'
      '${generation.toRadixString(16).padLeft(24, '0')}';

  static _MockCache _fullCache(String revision) =>
      (bundleRevision: revision, icons: 12, sprites: 3, fonts: 1, failed: 0);

  static _MockCache _partialCache(String revision) =>
      (bundleRevision: revision, icons: 10, sprites: 3, fonts: 1, failed: 2);

  AssetPrepareJob _initialResult(
    AssetPrepareJobState state,
    int available,
    int failed,
  ) => AssetPrepareJob(
    jobId: 'f2dfffff${'1'.padLeft(24, '0')}',
    generation: 1,
    sequence: 6,
    state: state,
    stage: AssetPrepareStage.complete,
    done: 1,
    total: 1,
    created: available,
    available: available,
    reused: 0,
    failed: failed,
    reasonCodes: failed > 0
        ? const [AssetPrepareReasonCode.assetsMissing]
        : const [],
  );

  AssetGameDir _identity(String path, AssetGameDirSource source) {
    final reason =
        gameDirReasons[path] ??
        (path == mockAssetAutoGameDir || validGameDirs.contains(path)
            ? null
            : AssetGameDirReason.gameDirNotFound);
    final catalogRead =
        reason == null ||
        reason == AssetGameDirReason.bundleRevisionMissing ||
        reason == AssetGameDirReason.bundleRevisionInvalid ||
        reason == AssetGameDirReason.bundleRevisionMismatch;
    return AssetGameDir(
      path: path,
      source: source,
      valid: reason == null,
      reason: reason,
      catalogSha256: catalogRead ? mockAssetCatalogSha256 : null,
      bundleRevision: reason == null ? _bundleRevision : null,
    );
  }

  AssetGameDir _game() {
    final user = _userPath;
    if (user != null) return _identity(user, AssetGameDirSource.user);
    if (_autoAvailable) {
      return _identity(mockAssetAutoGameDir, AssetGameDirSource.auto);
    }
    return const AssetGameDir(
      path: null,
      source: AssetGameDirSource.none,
      valid: false,
      reason: AssetGameDirReason.gameDirNotFound,
      catalogSha256: null,
      bundleRevision: null,
    );
  }

  AssetCacheStatus _cacheStatus(AssetGameDir game) {
    AssetCacheStatus empty(AssetCacheState state) => AssetCacheStatus(
      state: state,
      catalogSha256: null,
      bundleRevision: null,
      icons: 0,
      sprites: 0,
      fonts: 0,
      failed: null,
    );
    if (!game.valid) return empty(AssetCacheState.unknown);
    final cache = _cache;
    if (cache == null) return empty(AssetCacheState.missing);
    if (cache.bundleRevision != game.bundleRevision) {
      return empty(AssetCacheState.stale);
    }
    return AssetCacheStatus(
      state: cache.failed > 0 ? AssetCacheState.partial : AssetCacheState.ready,
      catalogSha256: game.catalogSha256,
      bundleRevision: game.bundleRevision,
      icons: cache.icons,
      sprites: cache.sprites,
      fonts: cache.fonts,
      failed: cache.failed,
    );
  }

  AssetPrepareStatus _status() {
    final game = _game();
    return AssetPrepareStatus(
      gameDir: game,
      cache: _cacheStatus(game),
      busy: busy,
      scannerBusy: _scannerActive(),
      job: _job,
      lastResult: _lastResult,
      metadata: const AssetPrepareMetadata(
        dataVersionId: null,
        dataSnapshotSha256: null,
        steamBundleRevision: null,
        steamMatchesSnapshot: null,
      ),
    );
  }

  void _acquire() {
    if (_closed) {
      throw _error(
        'asset_prepare_unavailable',
        'asset preparation service is closed',
      );
    }
    if (_scannerActive()) {
      throw _error(
        'scanner_busy',
        'another scanner or asset preparation operation is active',
      );
    }
    if (busy) {
      throw _error(
        'asset_prepare_busy',
        'another scanner or asset preparation operation is active',
      );
    }
  }

  AssetPrepareJob _require(AssetPrepareJobRef ref) {
    final job = _job;
    if (job == null || !ref.matches(job)) {
      throw _error(
        'asset_prepare_job_not_found',
        'asset preparation job was not found',
      );
    }
    return job;
  }

  Future<AssetPrepareJob> _snapshotOf(AssetPrepareJobRef ref) async =>
      _require(ref);

  void _emit(AssetPrepareEventKind kind) {
    final job = _copyJob(_job!, sequence: _job!.sequence + 1, keepTotal: true);
    _job = job;
    if (kind == AssetPrepareEventKind.progress && _dropProgress > 0) {
      _dropProgress -= 1;
      return;
    }
    _filter.add(AssetPrepareEvent(kind: kind, job: job));
  }

  void _schedule(List<void Function()> steps) {
    if (steps.isEmpty) return;
    _timer = Timer(step, () {
      _timer = null;
      if (_closed || _job == null) return;
      if (_cancelRequested) {
        _finish(AssetPrepareJobState.cancelled, null, const [
          AssetPrepareReasonCode.cancelled,
        ]);
        return;
      }
      steps.first();
      if (_job != null && !_job!.state.isTerminal) _schedule(steps.sublist(1));
    });
  }

  void _progress(AssetPrepareStage stage, int done, int? total) {
    _job = _copyJob(_job!, stage: stage, done: done, total: total);
    _emit(AssetPrepareEventKind.progress);
  }

  void _finish(
    AssetPrepareJobState state,
    ({int? created, int available, int? reused, int? failed})? counts,
    List<AssetPrepareReasonCode> reasons,
  ) {
    _job = _copyJob(
      _job!,
      state: state,
      stage: AssetPrepareStage.complete,
      keepTotal: true,
      counts:
          counts ?? (created: null, available: 0, reused: null, failed: null),
      reasonCodes: reasons,
    );
    _cancelRequested = false;
    _lastResult = _copyJob(
      _job!,
      sequence: _job!.sequence + 1,
      keepTotal: true,
    );
    _emit(AssetPrepareEventKind.terminal);
  }

  @override
  Stream<AssetPrepareEvent> get assetPrepareEvents => _filter.events;

  @override
  Future<AssetPrepareStatus> assetPrepareStatus() async => _status();

  @override
  Future<AssetPrepareStatus> setAssetGameDir(String? path) async {
    final request = AssetGameDirRequest(path);
    _acquire();
    final value = request.path;
    if (value != null) {
      final game = _identity(value, AssetGameDirSource.user);
      if (!game.valid) {
        throw _error('invalid_game_dir', 'game folder is invalid', {
          'reason': game.reason!.wireName,
        });
      }
    }
    _userPath = value;
    return _status();
  }

  @override
  Future<AssetPrepareJobRef> startAssetPreparation() async {
    _acquire();
    final game = _game();
    if (!game.valid) {
      throw _error('invalid_game_dir', 'game folder is invalid', {
        'reason': game.reason!.wireName,
      });
    }
    _filter.beginStart();
    final ref = AssetPrepareJobRef(
      jobId: _jobId(_generation + 1),
      generation: ++_generation,
    );
    _job = AssetPrepareJob.started(ref);
    _cancelRequested = false;
    final revision = game.bundleRevision!;
    final previous = _cache;
    final cacheHit =
        previous != null &&
        previous.bundleRevision == revision &&
        previous.failed == 0;
    if (cacheHit) {
      final available = previous.icons + previous.sprites + previous.fonts;
      _schedule([
        () => _progress(AssetPrepareStage.validating, 0, null),
        () => _finish(AssetPrepareJobState.succeeded, (
          created: 0,
          available: available,
          reused: available,
          failed: 0,
        ), const []),
      ]);
    } else {
      _schedule([
        () => _progress(AssetPrepareStage.validating, 0, null),
        () => _progress(AssetPrepareStage.icons, 0, 2),
        () => _progress(AssetPrepareStage.icons, 2, 2),
        () {
          if (_failNext) {
            _failNext = false;
            _finish(AssetPrepareJobState.failed, null, const [
              AssetPrepareReasonCode.assetExtractFailed,
            ]);
            return;
          }
          _progress(AssetPrepareStage.sprites, 1, null);
        },
        () => _progress(AssetPrepareStage.fonts, 1, 1),
        () {
          if (_partialNext) {
            _partialNext = false;
            _cache = _partialCache(revision);
            _finish(
              AssetPrepareJobState.partial,
              (created: 14, available: 14, reused: 0, failed: 2),
              const [AssetPrepareReasonCode.assetsMissing],
            );
            return;
          }
          // partial 재시도는 있던 파일을 다시 쓰고 빠진 것만 새로 만든다.
          final reused =
              previous != null &&
                  previous.bundleRevision == revision &&
                  previous.failed > 0
              ? previous.icons + previous.sprites + previous.fonts
              : 0;
          _cache = _fullCache(revision);
          _finish(AssetPrepareJobState.succeeded, (
            created: 16 - reused,
            available: 16,
            reused: reused,
            failed: 0,
          ), const []);
        },
      ]);
    }
    _filter.endStart(ref);
    return ref;
  }

  @override
  Future<AssetPrepareCancelResult> cancelAssetPreparation(
    AssetPrepareJobRef job,
  ) async {
    final current = _require(job);
    final active = !current.state.isTerminal;
    if (active) {
      _cancelRequested = true;
      _job = _copyJob(
        current,
        state: AssetPrepareJobState.cancelling,
        keepTotal: true,
      );
    }
    return AssetPrepareCancelResult(job: job, cancelRequested: active);
  }

  @override
  Future<AssetPrepareJob> assetPrepareSnapshot(AssetPrepareJobRef job) async {
    final snapshot = _require(job);
    _filter.adopt(snapshot);
    return snapshot;
  }

  Future<void> dispose() async {
    _closed = true;
    _timer?.cancel();
    _timer = null;
    await _filter.close();
  }
}
