// F2 첫 실행 인식 캐시 준비(`contracts/asset-preparation-v1.*`)의 Dart 쪽: 엄격 요청 검사 · 응답/이벤트 DTO ·
// 오류 해독 · 작업 cursor · Process 클라이언트.
//
// - 알파-1은 인식 캐시만 준비한다(D-ALPHA-SPLIT). 화면 그림은 번들 그대로다.
// - 진행 단위는 번들이다(`unit: "bundles"`). done/total은 그 단계의 번들 수이고 아이콘 수가 아니다. total이 null이면
//   분모 · % · 남은 시간을 숨긴다. 작업 전체의 고정 분모(예: 1,330)는 없다.
// - nullable 수(total · created · reused · failed, 캐시 failed)는 null 그대로 둔다. null은 "모름"이고 0이 아니다.
// - start 응답이 그 작업의 이벤트보다 먼저다. 고른 job_id · generation의 증가하는 sequence만 받고, 빈틈은 snapshot으로
//   메운다(snapshot cursor가 권위값). 백엔드 재시작 뒤에는 이전 작업을 되살리지 않는다 — status를 다시 읽는다.
// - cancel 응답의 `cancel_requested`는 요청 접수일 뿐 terminal이 아니다.
import 'dart:async';

import 'app_service.dart';
import 'planning_protocol_client.dart';

const assetPrepareStatusMethod = 'assets.prepare.status';
const assetPrepareGameDirSetMethod = 'assets.prepare.game_dir.set';
const assetPrepareStartMethod = 'assets.prepare.start';
const assetPrepareCancelMethod = 'assets.prepare.cancel';
const assetPrepareSnapshotMethod = 'assets.prepare.snapshot';
const assetPrepareEventMethod = 'assets.prepare.event';

const assetPrepareMethods = {
  assetPrepareStatusMethod,
  assetPrepareGameDirSetMethod,
  assetPrepareStartMethod,
  assetPrepareCancelMethod,
  assetPrepareSnapshotMethod,
};

/// 계약 오류 코드 7개(schema `$defs.error.code`). 이 밖의 코드는 프로토콜 오류다.
const assetPrepareErrorWireCodes = {
  'invalid_payload',
  'scanner_busy',
  'asset_prepare_busy',
  'invalid_game_dir',
  'asset_prepare_job_not_found',
  'asset_prepare_unavailable',
  'asset_prepare_io_error',
};

enum AssetGameDirSource {
  auto('auto'),
  user('user'),
  none('none');

  const AssetGameDirSource(this.wireName);
  final String wireName;

  static AssetGameDirSource fromWire(Object? value) => values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => throw FormatException('Unknown game folder source: $value'),
  );
}

/// 게임 폴더가 쓸 수 없는 이유(status `game_dir.reason`, `invalid_game_dir` 오류의 `details.reason`).
enum AssetGameDirReason {
  gameDirNotFound('game_dir_not_found'),
  notBlueArchive('not_blue_archive'),
  catalogMissing('catalog_missing'),
  catalogInvalid('catalog_invalid'),
  bundleRevisionMissing('bundle_revision_missing'),
  bundleRevisionInvalid('bundle_revision_invalid'),

  /// Catalog · Preload · GameData 세 BundleRevision이 서로 다르다.
  bundleRevisionMismatch('bundle_revision_mismatch'),
  gameDirUnreadable('game_dir_unreadable');

  const AssetGameDirReason(this.wireName);
  final String wireName;

  static AssetGameDirReason fromWire(Object? value) => values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => throw FormatException('Unknown game folder reason: $value'),
  );
}

/// 인식 캐시 상태. unknown · invalid · stale의 수 0은 "0개 추출 성공"이 아니다(failed는 null).
enum AssetCacheState {
  missing('missing'),
  unknown('unknown'),
  invalid('invalid'),
  stale('stale'),
  ready('ready'),

  /// 선택 아이콘 일부가 없다. 준비를 다시 하면 재시도한다.
  partial('partial');

  const AssetCacheState(this.wireName);
  final String wireName;

  static AssetCacheState fromWire(Object? value) => values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => throw FormatException('Unknown asset cache state: $value'),
  );
}

enum AssetPrepareJobState {
  running('running'),

  /// 취소 요청을 받았고 아직 끝나지 않았다(조작은 계속 busy).
  cancelling('cancelling'),
  succeeded('succeeded'),
  partial('partial'),
  failed('failed'),
  cancelled('cancelled');

  const AssetPrepareJobState(this.wireName);
  final String wireName;

  bool get isTerminal =>
      this != AssetPrepareJobState.running &&
      this != AssetPrepareJobState.cancelling;

  static AssetPrepareJobState fromWire(Object? value) => values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => throw FormatException('Unknown asset job state: $value'),
  );
}

enum AssetPrepareStage {
  validating('validating'),
  icons('icons'),
  sprites('sprites'),
  fonts('fonts'),
  complete('complete');

  const AssetPrepareStage(this.wireName);
  final String wireName;

  static AssetPrepareStage fromWire(Object? value) => values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => throw FormatException('Unknown asset job stage: $value'),
  );
}

enum AssetPrepareReasonCode {
  assetsMissing('assets_missing'),
  cancelled('cancelled'),
  assetCacheInvalid('asset_cache_invalid'),
  assetExtractFailed('asset_extract_failed'),
  resultNotSaved('result_not_saved');

  const AssetPrepareReasonCode(this.wireName);
  final String wireName;

  static AssetPrepareReasonCode fromWire(Object? value) => values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => throw FormatException('Unknown asset job reason: $value'),
  );
}

enum AssetPrepareEventKind { progress, terminal }

enum AssetPrepareErrorCode {
  invalidPayload('invalid_payload'),

  /// 스캔이 진행 중(일시정지 포함)이라 준비 · 폴더 변경을 받지 않는다.
  scannerBusy('scanner_busy'),

  /// 준비 · 폴더 변경이 진행 중이다. 스캔 시작도 이 코드로 거절된다.
  busy('asset_prepare_busy'),

  /// 폴더가 쓸 수 없다. 이유는 [AssetPrepareFailure.reason].
  invalidGameDir('invalid_game_dir'),

  /// 지금 작업이 아니다(재시작 뒤 옛 cursor 포함). status를 다시 읽는다.
  jobNotFound('asset_prepare_job_not_found'),
  unavailable('asset_prepare_unavailable'),
  ioError('asset_prepare_io_error');

  const AssetPrepareErrorCode(this.wireName);
  final String wireName;
}

/// 백엔드 오류를 계약 코드로 해독한다. 계약 밖 오류면 null.
class AssetPrepareFailure {
  const AssetPrepareFailure(this.code, {this.reason});

  final AssetPrepareErrorCode code;
  final AssetGameDirReason? reason;

  static AssetPrepareFailure? fromError(Object error) {
    if (error is! BackendRemoteException) return null;
    for (final code in AssetPrepareErrorCode.values) {
      if (code.wireName != error.code) continue;
      final rawReason = error.details?['reason'];
      AssetGameDirReason? reason;
      for (final item in AssetGameDirReason.values) {
        if (item.wireName == rawReason) reason = item;
      }
      return AssetPrepareFailure(code, reason: reason);
    }
    return null;
  }
}

final _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');
final _dataVersionPattern = RegExp(r'^(jp|steam)-[a-z0-9][a-z0-9._-]*$');

bool _exactKeys(Map<dynamic, dynamic> value, Set<String> keys) =>
    value.length == keys.length && keys.every(value.containsKey);

Map<String, dynamic> _object(Object? value, String label) {
  if (value is! Map) throw FormatException('$label must be an object');
  return Map<String, dynamic>.from(value);
}

void _requireKeys(Map<String, dynamic> value, Set<String> keys, String label) {
  if (!_exactKeys(value, keys)) {
    throw FormatException(
      '$label keys must be ${keys.toList()..sort()} (got ${value.keys.toList()..sort()})',
    );
  }
}

String _boundedString(Object? value, String label, {int maxLength = 128}) {
  if (value is! String || value.isEmpty || value.runes.length > maxLength) {
    throw FormatException('$label must be a 1..$maxLength character string');
  }
  return value;
}

String? _nullableBoundedString(Object? value, String label) =>
    value == null ? null : _boundedString(value, label);

String? _nullableSha256(Object? value, String label) {
  if (value == null) return null;
  if (value is! String || !_sha256Pattern.hasMatch(value)) {
    throw FormatException('$label must be a lowercase sha256 or null');
  }
  return value;
}

int _count(Object? value, String label, {int minimum = 0}) {
  if (value is! int || value < minimum) {
    throw FormatException('$label must be an integer >= $minimum');
  }
  return value;
}

/// null은 "모름"으로 그대로 둔다(0으로 바꾸지 않는다).
int? _nullableCount(Object? value, String label) =>
    value == null ? null : _count(value, label);

bool _flag(Object? value, String label) {
  if (value is! bool) throw FormatException('$label must be a boolean');
  return value;
}

/// `game_dir.set`의 path(schema: null 또는 1..32767자, 백엔드는 공백뿐 · NUL도 거부).
String? _gameDirPath(Object? value) {
  if (value == null) return null;
  if (value is! String ||
      value.trim().isEmpty ||
      value.runes.length > 32767 ||
      value.contains('\u0000')) {
    throw const FormatException('path must be null or a nonempty path');
  }
  return value;
}

/// `assets.prepare.game_dir.set` 요청. null은 자동 탐색으로 되돌린다.
class AssetGameDirRequest {
  AssetGameDirRequest(String? path) : path = _gameDirPath(path);

  final String? path;

  Map<String, dynamic> toWire() => {'path': path};

  static AssetGameDirRequest fromWire(Object? wire) {
    final value = _object(wire, 'game_dir.set payload');
    _requireKeys(value, const {'path'}, 'game_dir.set payload');
    if (value['path'] != null && value['path'] is! String) {
      throw const FormatException('path must be null or a nonempty path');
    }
    return AssetGameDirRequest(value['path'] as String?);
  }
}

/// 작업 cursor(`start` 응답, `cancel` · `snapshot` 요청). generation은 정수만(boolean 거부).
class AssetPrepareJobRef {
  AssetPrepareJobRef({required String jobId, required int generation})
    : jobId = _boundedString(jobId, 'job_id'),
      generation = _count(generation, 'generation', minimum: 1);

  final String jobId;
  final int generation;

  factory AssetPrepareJobRef.fromWire(Object? wire) {
    final value = _object(wire, 'job cursor');
    _requireKeys(value, const {'job_id', 'generation'}, 'job cursor');
    final generation = value['generation'];
    if (generation is! int) {
      throw const FormatException('generation must be an integer');
    }
    return AssetPrepareJobRef(
      jobId: _boundedString(value['job_id'], 'job_id'),
      generation: generation,
    );
  }

  Map<String, dynamic> toWire() => {'job_id': jobId, 'generation': generation};

  bool matches(AssetPrepareJob job) =>
      job.jobId == jobId && job.generation == generation;

  @override
  bool operator ==(Object other) =>
      other is AssetPrepareJobRef &&
      other.jobId == jobId &&
      other.generation == generation;

  @override
  int get hashCode => Object.hash(jobId, generation);

  @override
  String toString() => 'AssetPrepareJobRef($jobId, $generation)';
}

class AssetGameDir {
  const AssetGameDir({
    required this.path,
    required this.source,
    required this.valid,
    required this.reason,
    required this.catalogSha256,
    required this.bundleRevision,
  });

  /// 고른 게임 폴더(없으면 null). 사용자 지정은 나중에 패치 · 이동으로 무효가 돼도 남는다.
  final String? path;
  final AssetGameDirSource source;
  final bool valid;
  final AssetGameDirReason? reason;
  final String? catalogSha256;
  final String? bundleRevision;

  factory AssetGameDir.fromWire(Object? wire) {
    final value = _object(wire, 'game_dir');
    _requireKeys(value, const {
      'path',
      'source',
      'valid',
      'reason',
      'catalog_sha256',
      'bundle_revision',
    }, 'game_dir');
    final path = value['path'];
    if (path != null &&
        (path is! String || path.isEmpty || path.runes.length > 32767)) {
      throw const FormatException('game_dir.path must be a path or null');
    }
    final reason = value['reason'];
    return AssetGameDir(
      path: path as String?,
      source: AssetGameDirSource.fromWire(value['source']),
      valid: _flag(value['valid'], 'game_dir.valid'),
      reason: reason == null ? null : AssetGameDirReason.fromWire(reason),
      catalogSha256: _nullableSha256(
        value['catalog_sha256'],
        'game_dir.catalog_sha256',
      ),
      bundleRevision: _nullableBoundedString(
        value['bundle_revision'],
        'game_dir.bundle_revision',
      ),
    );
  }

  Map<String, dynamic> toWire() => {
    'path': path,
    'source': source.wireName,
    'valid': valid,
    'reason': reason?.wireName,
    'catalog_sha256': catalogSha256,
    'bundle_revision': bundleRevision,
  };
}

class AssetCacheStatus {
  const AssetCacheStatus({
    required this.state,
    required this.catalogSha256,
    required this.bundleRevision,
    required this.icons,
    required this.sprites,
    required this.fonts,
    required this.failed,
  });

  final AssetCacheState state;
  final String? catalogSha256;
  final String? bundleRevision;
  final int icons;
  final int sprites;
  final int fonts;

  /// 없는 선택 아이콘 수. null은 모름(unknown · invalid · stale · missing).
  final int? failed;

  factory AssetCacheStatus.fromWire(Object? wire) {
    final value = _object(wire, 'cache');
    _requireKeys(value, const {
      'state',
      'catalog_sha256',
      'bundle_revision',
      'icons',
      'sprites',
      'fonts',
      'failed',
    }, 'cache');
    return AssetCacheStatus(
      state: AssetCacheState.fromWire(value['state']),
      catalogSha256: _nullableSha256(
        value['catalog_sha256'],
        'cache.catalog_sha256',
      ),
      bundleRevision: _nullableBoundedString(
        value['bundle_revision'],
        'cache.bundle_revision',
      ),
      icons: _count(value['icons'], 'cache.icons'),
      sprites: _count(value['sprites'], 'cache.sprites'),
      fonts: _count(value['fonts'], 'cache.fonts'),
      failed: _nullableCount(value['failed'], 'cache.failed'),
    );
  }

  Map<String, dynamic> toWire() => {
    'state': state.wireName,
    'catalog_sha256': catalogSha256,
    'bundle_revision': bundleRevision,
    'icons': icons,
    'sprites': sprites,
    'fonts': fonts,
    'failed': failed,
  };
}

/// 설치본 데이터 snapshot 메타(M6). 모두 nullable이고 `jp_update_required`는 항상 null이다(로컬 근거로 JP 갱신
/// 필요를 말하지 않는다). [steamMatchesSnapshot]도 로컬 비교일 뿐이다.
class AssetPrepareMetadata {
  const AssetPrepareMetadata({
    required this.dataVersionId,
    required this.dataSnapshotSha256,
    required this.steamBundleRevision,
    required this.steamMatchesSnapshot,
  });

  final String? dataVersionId;
  final String? dataSnapshotSha256;
  final String? steamBundleRevision;
  final bool? steamMatchesSnapshot;

  factory AssetPrepareMetadata.fromWire(Object? wire) {
    final value = _object(wire, 'metadata');
    _requireKeys(value, const {
      'data_version_id',
      'data_snapshot_sha256',
      'steam_bundle_revision',
      'steam_matches_snapshot',
      'jp_update_required',
    }, 'metadata');
    if (value['jp_update_required'] != null) {
      throw const FormatException('metadata.jp_update_required must be null');
    }
    final version = value['data_version_id'];
    if (version != null &&
        (version is! String || !_dataVersionPattern.hasMatch(version))) {
      throw const FormatException('metadata.data_version_id is invalid');
    }
    final matches = value['steam_matches_snapshot'];
    if (matches != null && matches is! bool) {
      throw const FormatException(
        'metadata.steam_matches_snapshot must be a boolean or null',
      );
    }
    return AssetPrepareMetadata(
      dataVersionId: version as String?,
      dataSnapshotSha256: _nullableSha256(
        value['data_snapshot_sha256'],
        'metadata.data_snapshot_sha256',
      ),
      steamBundleRevision: _nullableBoundedString(
        value['steam_bundle_revision'],
        'metadata.steam_bundle_revision',
      ),
      steamMatchesSnapshot: matches as bool?,
    );
  }

  Map<String, dynamic> toWire() => {
    'data_version_id': dataVersionId,
    'data_snapshot_sha256': dataSnapshotSha256,
    'steam_bundle_revision': steamBundleRevision,
    'steam_matches_snapshot': steamMatchesSnapshot,
    'jp_update_required': null,
  };
}

const _jobKeys = {
  'job_id',
  'generation',
  'sequence',
  'state',
  'stage',
  'done',
  'total',
  'unit',
  'created',
  'available',
  'reused',
  'failed',
  'reason_codes',
};

/// 작업 snapshot(status `job` · `last_result`, snapshot 응답, 이벤트 본문).
class AssetPrepareJob {
  AssetPrepareJob({
    required this.jobId,
    required this.generation,
    required this.sequence,
    required this.state,
    required this.stage,
    required this.done,
    required this.total,
    required this.created,
    required this.available,
    required this.reused,
    required this.failed,
    required List<AssetPrepareReasonCode> reasonCodes,
  }) : reasonCodes = List.unmodifiable(reasonCodes);

  /// start가 막 받아들여진 작업(백엔드 초기 snapshot과 같은 값).
  factory AssetPrepareJob.started(AssetPrepareJobRef ref) => AssetPrepareJob(
    jobId: ref.jobId,
    generation: ref.generation,
    sequence: 0,
    state: AssetPrepareJobState.running,
    stage: AssetPrepareStage.validating,
    done: 0,
    total: null,
    created: null,
    available: 0,
    reused: null,
    failed: null,
    reasonCodes: const [],
  );

  final String jobId;
  final int generation;
  final int sequence;
  final AssetPrepareJobState state;
  final AssetPrepareStage stage;

  /// 이 단계에서 끝낸 번들 수(아이콘 수가 아니다).
  final int done;

  /// 이 단계의 번들 분모. null이면 분모 · % · 남은 시간을 숨긴다.
  final int? total;

  /// 새로 만든 파일 수. null은 모름(진행 중, 또는 실패 · 취소로 셀 수 없음).
  final int? created;

  /// 검증 · 게시된 파일 수(처음 0).
  final int available;

  /// 이전 캐시에서 그대로 쓴 파일 수. null은 모름.
  final int? reused;

  /// 없는 선택 아이콘 수. null은 모름.
  final int? failed;
  final List<AssetPrepareReasonCode> reasonCodes;

  AssetPrepareJobRef get ref =>
      AssetPrepareJobRef(jobId: jobId, generation: generation);

  factory AssetPrepareJob.fromWire(Object? wire) {
    final value = _object(wire, 'job');
    _requireKeys(value, _jobKeys, 'job');
    return _jobFromChecked(value);
  }

  static AssetPrepareJob _jobFromChecked(Map<String, dynamic> value) {
    if (value['unit'] != 'bundles') {
      throw const FormatException('job.unit must be bundles');
    }
    final rawReasons = value['reason_codes'];
    if (rawReasons is! List) {
      throw const FormatException('job.reason_codes must be a list');
    }
    final reasons = rawReasons
        .map(AssetPrepareReasonCode.fromWire)
        .toList(growable: false);
    if (reasons.toSet().length != reasons.length) {
      throw const FormatException('job.reason_codes must be unique');
    }
    final generation = value['generation'];
    if (generation is! int) {
      throw const FormatException('job.generation must be an integer');
    }
    return AssetPrepareJob(
      jobId: _boundedString(value['job_id'], 'job.job_id'),
      generation: _count(generation, 'job.generation', minimum: 1),
      sequence: _count(value['sequence'], 'job.sequence'),
      state: AssetPrepareJobState.fromWire(value['state']),
      stage: AssetPrepareStage.fromWire(value['stage']),
      done: _count(value['done'], 'job.done'),
      total: _nullableCount(value['total'], 'job.total'),
      created: _nullableCount(value['created'], 'job.created'),
      available: _count(value['available'], 'job.available'),
      reused: _nullableCount(value['reused'], 'job.reused'),
      failed: _nullableCount(value['failed'], 'job.failed'),
      reasonCodes: reasons,
    );
  }

  Map<String, dynamic> toWire() => {
    'job_id': jobId,
    'generation': generation,
    'sequence': sequence,
    'state': state.wireName,
    'stage': stage.wireName,
    'done': done,
    'total': total,
    'unit': 'bundles',
    'created': created,
    'available': available,
    'reused': reused,
    'failed': failed,
    'reason_codes': [for (final reason in reasonCodes) reason.wireName],
  };
}

/// `assets.prepare.event`(작업 snapshot + event_kind). progress는 running · cancelling과 complete가 아닌 단계,
/// terminal은 끝난 상태와 complete 단계다(schema `allOf`). sequence는 1부터다.
///
/// [recovered]는 빈틈을 snapshot으로 메운 값이다(wire 이벤트가 아니라 snapshot cursor).
class AssetPrepareEvent {
  AssetPrepareEvent({
    required this.kind,
    required this.job,
    this.recovered = false,
  });

  /// 빈틈 복구 snapshot을 이벤트 자리에 둔다. 끝난 상태면 terminal로 본다.
  factory AssetPrepareEvent.recovered(AssetPrepareJob job) => AssetPrepareEvent(
    kind: job.state.isTerminal
        ? AssetPrepareEventKind.terminal
        : AssetPrepareEventKind.progress,
    job: job,
    recovered: true,
  );

  final AssetPrepareEventKind kind;
  final AssetPrepareJob job;
  final bool recovered;

  bool get isTerminal => kind == AssetPrepareEventKind.terminal;

  factory AssetPrepareEvent.fromWire(Object? wire) {
    final value = _object(wire, 'event payload');
    _requireKeys(value, {..._jobKeys, 'event_kind'}, 'event payload');
    final kind = switch (value['event_kind']) {
      'progress' => AssetPrepareEventKind.progress,
      'terminal' => AssetPrepareEventKind.terminal,
      final other => throw FormatException('Unknown asset event kind: $other'),
    };
    final job = AssetPrepareJob._jobFromChecked(
      Map<String, dynamic>.from(value)..remove('event_kind'),
    );
    final terminal = kind == AssetPrepareEventKind.terminal;
    if (job.sequence < 1 ||
        job.state.isTerminal != terminal ||
        (job.stage == AssetPrepareStage.complete) != terminal) {
      throw FormatException(
        'Asset event ${kind.name} has state ${job.state.wireName} / stage ${job.stage.wireName}',
      );
    }
    return AssetPrepareEvent(kind: kind, job: job);
  }

  Map<String, dynamic> toWire() => {'event_kind': kind.name, ...job.toWire()};
}

class AssetPrepareStatus {
  const AssetPrepareStatus({
    required this.gameDir,
    required this.cache,
    required this.busy,
    required this.scannerBusy,
    required this.job,
    required this.lastResult,
    required this.metadata,
  });

  final AssetGameDir gameDir;
  final AssetCacheStatus cache;

  /// 준비나 폴더 변경이 실행 권한을 갖고 있다.
  final bool busy;

  /// 스캔(일시정지 포함)이 실행 권한을 갖고 있다.
  final bool scannerBusy;

  /// 지금 백엔드의 작업(없으면 null). 재시작 뒤에는 null — 옛 작업은 되살리지 않는다.
  final AssetPrepareJob? job;

  /// 저장된 마지막 끝난 결과(없으면 null).
  final AssetPrepareJob? lastResult;
  final AssetPrepareMetadata metadata;

  factory AssetPrepareStatus.fromWire(Object? wire) {
    final value = _object(wire, 'status');
    _requireKeys(value, const {
      'game_dir',
      'cache',
      'busy',
      'scanner_busy',
      'job',
      'last_result',
      'metadata',
    }, 'status');
    return AssetPrepareStatus(
      gameDir: AssetGameDir.fromWire(value['game_dir']),
      cache: AssetCacheStatus.fromWire(value['cache']),
      busy: _flag(value['busy'], 'status.busy'),
      scannerBusy: _flag(value['scanner_busy'], 'status.scanner_busy'),
      job: value['job'] == null ? null : AssetPrepareJob.fromWire(value['job']),
      lastResult: value['last_result'] == null
          ? null
          : AssetPrepareJob.fromWire(value['last_result']),
      metadata: AssetPrepareMetadata.fromWire(value['metadata']),
    );
  }

  Map<String, dynamic> toWire() => {
    'game_dir': gameDir.toWire(),
    'cache': cache.toWire(),
    'busy': busy,
    'scanner_busy': scannerBusy,
    'job': job?.toWire(),
    'last_result': lastResult?.toWire(),
    'metadata': metadata.toWire(),
  };
}

/// `assets.prepare.cancel` 응답. [cancelRequested]가 true여도 terminal이 아니다(조작은 terminal까지 busy).
/// false면 이미 끝난 작업이다.
class AssetPrepareCancelResult {
  const AssetPrepareCancelResult({
    required this.job,
    required this.cancelRequested,
  });

  final AssetPrepareJobRef job;
  final bool cancelRequested;

  factory AssetPrepareCancelResult.fromWire(Object? wire) {
    final value = _object(wire, 'cancel response');
    _requireKeys(value, const {
      'job_id',
      'generation',
      'cancel_requested',
    }, 'cancel response');
    return AssetPrepareCancelResult(
      job: AssetPrepareJobRef.fromWire({
        'job_id': value['job_id'],
        'generation': value['generation'],
      }),
      cancelRequested: _flag(value['cancel_requested'], 'cancel_requested'),
    );
  }

  Map<String, dynamic> toWire() => {
    ...job.toWire(),
    'cancel_requested': cancelRequested,
  };
}

AssetPrepareJob parseAssetPrepareSnapshot(Object? wire) {
  final value = _object(wire, 'snapshot response');
  _requireKeys(value, const {'job'}, 'snapshot response');
  return AssetPrepareJob.fromWire(value['job']);
}

/// 요청 payload 검사(모르는 키 · boolean generation 거부). 틀리면 [FormatException].
void validateAssetPrepareRequestPayload(String method, Object? payload) {
  final value = _object(payload, '$method payload');
  switch (method) {
    case assetPrepareStatusMethod || assetPrepareStartMethod:
      _requireKeys(value, const <String>{}, '$method payload');
    case assetPrepareGameDirSetMethod:
      AssetGameDirRequest.fromWire(value);
    case assetPrepareCancelMethod || assetPrepareSnapshotMethod:
      AssetPrepareJobRef.fromWire(value);
    default:
      throw FormatException('Unknown asset preparation method: $method');
  }
}

/// 성공 응답 payload를 해독한다(메서드별). 틀리면 [FormatException].
Object parseAssetPrepareSuccessPayload(String method, Object? payload) =>
    switch (method) {
      assetPrepareStatusMethod ||
      assetPrepareGameDirSetMethod => AssetPrepareStatus.fromWire(payload),
      assetPrepareStartMethod => AssetPrepareJobRef.fromWire(payload),
      assetPrepareCancelMethod => AssetPrepareCancelResult.fromWire(payload),
      assetPrepareSnapshotMethod => parseAssetPrepareSnapshot(payload),
      _ => throw FormatException('Unknown asset preparation method: $method'),
    };

bool isValidAssetPrepareSuccessPayload(String method, Object? payload) {
  try {
    parseAssetPrepareSuccessPayload(method, payload);
    return true;
  } on Object {
    return false;
  }
}

/// 계약 오류 payload(`{error:{code,message,details}}`, details는 `{}` 또는 `{reason}`).
bool isValidAssetPrepareErrorPayload(Object? payload) {
  if (payload is! Map || !_exactKeys(payload, const {'error'})) return false;
  final error = payload['error'];
  if (error is! Map ||
      !_exactKeys(error, const {'code', 'message', 'details'}) ||
      !assetPrepareErrorWireCodes.contains(error['code']) ||
      error['message'] is! String) {
    return false;
  }
  final details = error['details'];
  if (details is! Map) return false;
  if (details.isEmpty) return true;
  if (!_exactKeys(details, const {'reason'})) return false;
  return AssetGameDirReason.values.any(
    (item) => item.wireName == details['reason'],
  );
}

bool isValidAssetPrepareEventEnvelope(Object? message) {
  if (message is! Map ||
      !_exactKeys(message, const {'protocol', 'type', 'method', 'payload'}) ||
      message['protocol'] != 1 ||
      message['type'] != 'event' ||
      message['method'] != assetPrepareEventMethod) {
    return false;
  }
  try {
    AssetPrepareEvent.fromWire(message['payload']);
    return true;
  } on Object {
    return false;
  }
}

/// 계약 schema 전체(요청 · 응답 · 이벤트 봉투)와 같은 판정. 계약 fixture 왕복 시험이 쓴다.
bool isValidAssetPreparationProtocolMessage(Object? message) {
  if (message is! Map) return false;
  if (message['type'] == 'event') {
    return isValidAssetPrepareEventEnvelope(message);
  }
  if (!_exactKeys(message, const {
        'protocol',
        'id',
        'method',
        'type',
        'payload',
      }) ||
      message['protocol'] != 1 ||
      !assetPrepareMethods.contains(message['method'])) {
    return false;
  }
  final id = message['id'];
  if (id is! String || id.isEmpty || id.runes.length > 128) return false;
  final method = message['method'] as String;
  final payload = message['payload'];
  switch (message['type']) {
    case 'request':
      try {
        validateAssetPrepareRequestPayload(method, payload);
        return true;
      } on Object {
        return false;
      }
    case 'response':
      return isValidAssetPrepareSuccessPayload(method, payload) ||
          isValidAssetPrepareErrorPayload(payload);
    default:
      return false;
  }
}

enum AssetPrepareEventDecision {
  accepted,
  stale,
  duplicateOrOutOfOrder,
  snapshotRequired,
  afterTerminal,
}

/// 한 작업의 이벤트 cursor. 고른 job_id · generation에서 lastSequence+1만 받는다.
class AssetPrepareEventCursor {
  AssetPrepareEventCursor(this.job);

  final AssetPrepareJobRef job;
  int lastSequence = 0;
  bool terminal = false;

  AssetPrepareEventDecision consume(AssetPrepareEvent event) {
    if (!job.matches(event.job)) return AssetPrepareEventDecision.stale;
    if (terminal) return AssetPrepareEventDecision.afterTerminal;
    final sequence = event.job.sequence;
    if (sequence <= lastSequence) {
      return AssetPrepareEventDecision.duplicateOrOutOfOrder;
    }
    if (sequence != lastSequence + 1) {
      return AssetPrepareEventDecision.snapshotRequired;
    }
    lastSequence = sequence;
    if (event.isTerminal) terminal = true;
    return AssetPrepareEventDecision.accepted;
  }

  /// snapshot cursor를 권위값으로 받아들인다. 앞으로 나아갔으면 true.
  ///
  /// 끝난 상태의 snapshot은 cursor를 닫지 않는다: 백엔드는 끝난 상태를 기록한 뒤 terminal 이벤트를 다음 sequence로
  /// 내므로, 그 이벤트(사유 코드 포함)를 여전히 받는다.
  bool reconcile(AssetPrepareJob snapshot) {
    if (!job.matches(snapshot)) {
      throw const FormatException('Asset snapshot is for another job');
    }
    if (snapshot.sequence <= lastSequence) return false;
    lastSequence = snapshot.sequence;
    return true;
  }
}

/// start 경합 버퍼 · cursor 거르기 · 빈틈 snapshot 복구를 한곳에서 한다. Process와 Mock이 같은 규칙을 쓴다.
///
/// - start 응답 전에 온 이벤트는 start가 끝날 때까지 잡아 두었다가 그 작업 것만 순서대로 넣는다.
/// - 지금 작업 밖(옛 job · generation) · 중복 · terminal 뒤 이벤트는 버린다.
/// - 빈틈이면 snapshot을 한 번 요청하고, 그동안 온 이벤트는 잡아 두었다가 snapshot cursor 뒤의 것만 넣는다.
///   snapshot이 실패하면 cursor를 버리고 오류를 낸다(구독자는 status를 다시 읽는다).
/// - [reset](연결 끊김 · 재시작)은 cursor와 버퍼를 모두 버린다. 늦게 온 snapshot 응답은 버린다.
class AssetPrepareEventFilter {
  AssetPrepareEventFilter(this._snapshot);

  final Future<AssetPrepareJob> Function(AssetPrepareJobRef job) _snapshot;
  final StreamController<AssetPrepareEvent> _events =
      StreamController.broadcast();
  AssetPrepareEventCursor? _cursor;
  final List<AssetPrepareEvent> _startBuffer = [];
  final List<AssetPrepareEvent> _recoveryBuffer = [];
  int _pendingStarts = 0;
  bool _recovering = false;
  int _epoch = 0;

  Stream<AssetPrepareEvent> get events => _events.stream;

  AssetPrepareJobRef? get currentJob => _cursor?.job;

  void beginStart() => _pendingStarts += 1;

  /// start가 끝났다. [job]이 있으면 새 cursor로 바꾸고 잡아 둔 그 작업 이벤트를 넣는다.
  void endStart(AssetPrepareJobRef? job) {
    if (_pendingStarts > 0) _pendingStarts -= 1;
    if (job != null) {
      _epoch += 1;
      _recovering = false;
      _recoveryBuffer.clear();
      _cursor = AssetPrepareEventCursor(job);
    }
    if (_pendingStarts > 0) return;
    final buffered = List<AssetPrepareEvent>.of(_startBuffer)
      ..sort((a, b) => a.job.sequence.compareTo(b.job.sequence));
    _startBuffer.clear();
    for (final event in buffered) {
      add(event);
    }
  }

  /// 지금 작업이 없거나 다른 작업이면 [job]을 고른다(status에서 본 진행 중 작업에 붙을 때). snapshot cursor를 맞춘다.
  void adopt(AssetPrepareJob job) {
    final cursor = _cursor;
    if (cursor == null || cursor.job != job.ref) {
      _epoch += 1;
      _recovering = false;
      _recoveryBuffer.clear();
      _cursor = AssetPrepareEventCursor(job.ref)..reconcile(job);
      return;
    }
    cursor.reconcile(job);
  }

  void add(AssetPrepareEvent event) {
    if (_events.isClosed) return;
    final cursor = _cursor;
    if (_pendingStarts > 0 &&
        (cursor == null || !cursor.job.matches(event.job))) {
      _startBuffer.add(event);
      return;
    }
    if (cursor == null) return;
    if (_recovering) {
      if (cursor.job.matches(event.job)) _recoveryBuffer.add(event);
      return;
    }
    switch (cursor.consume(event)) {
      case AssetPrepareEventDecision.accepted:
        _events.add(event);
      case AssetPrepareEventDecision.snapshotRequired:
        _recoveryBuffer.add(event);
        unawaited(_recover(cursor));
      case AssetPrepareEventDecision.stale ||
          AssetPrepareEventDecision.duplicateOrOutOfOrder ||
          AssetPrepareEventDecision.afterTerminal:
        break;
    }
  }

  Future<void> _recover(AssetPrepareEventCursor cursor) async {
    _recovering = true;
    final epoch = _epoch;
    AssetPrepareJob snapshot;
    try {
      snapshot = await _snapshot(cursor.job);
      if (!cursor.job.matches(snapshot)) {
        throw const FormatException('Asset snapshot is for another job');
      }
    } catch (error, stackTrace) {
      if (epoch != _epoch || !identical(_cursor, cursor)) return;
      _recovering = false;
      _recoveryBuffer.clear();
      _cursor = null;
      if (!_events.isClosed) _events.addError(error, stackTrace);
      return;
    }
    if (epoch != _epoch || !identical(_cursor, cursor) || _events.isClosed) {
      return;
    }
    if (cursor.reconcile(snapshot)) {
      _events.add(AssetPrepareEvent.recovered(snapshot));
    }
    _recovering = false;
    final buffered = List<AssetPrepareEvent>.of(_recoveryBuffer)
      ..sort((a, b) => a.job.sequence.compareTo(b.job.sequence));
    _recoveryBuffer.clear();
    for (final event in buffered) {
      add(event);
    }
  }

  void reset() {
    _epoch += 1;
    _cursor = null;
    _startBuffer.clear();
    _recoveryBuffer.clear();
    _pendingStarts = 0;
    _recovering = false;
  }

  Future<void> close() async {
    reset();
    await _events.close();
  }
}

/// F2 준비 서비스 경계. Process와 Mock이 구현한다.
abstract interface class AssetPreparationService {
  /// 고른 작업의 받아들인 이벤트(거르기 · 빈틈 복구 뒤). 복구 실패는 오류로 온다 — status를 다시 읽는다.
  Stream<AssetPrepareEvent> get assetPrepareEvents;

  Future<AssetPrepareStatus> assetPrepareStatus();

  /// 사용자 폴더 지정(null = 자동 탐색으로 되돌림). 쓸 수 없는 폴더는 저장하지 않고 `invalid_game_dir`(이유 포함).
  Future<AssetPrepareStatus> setAssetGameDir(String? path);

  /// 명시적 시작. 진행 중이면 `asset_prepare_busy`, 스캔 중이면 `scanner_busy`, 폴더가 쓸 수 없으면 `invalid_game_dir`.
  Future<AssetPrepareJobRef> startAssetPreparation();

  Future<AssetPrepareCancelResult> cancelAssetPreparation(
    AssetPrepareJobRef job,
  );

  /// 지금 작업 snapshot. 이 cursor로 이벤트를 다시 맞춘다(옛 cursor면 `asset_prepare_job_not_found`).
  Future<AssetPrepareJob> assetPrepareSnapshot(AssetPrepareJobRef job);
}

/// F2 service entry point, without breaking existing AppService test doubles.
extension AppServiceAssetPreparation on AppService {
  /// 준비를 지원하지 않는 서비스면 null.
  AssetPreparationService? get assetPreparation {
    final service = this;
    return service is AssetPreparationService
        ? service as AssetPreparationService
        : null;
  }
}

/// Process 쪽 RPC 5개와 이벤트 구독. [PlanningProtocolClient.assetPreparationEvents]만 듣는다(스캐너 이벤트와 분리).
class AssetPreparationProtocolClient implements AssetPreparationService {
  AssetPreparationProtocolClient(this._client) {
    _filter = AssetPrepareEventFilter(_snapshotWire);
    _subscription = _client.assetPreparationEvents.listen(_handleEnvelope);
    _client.connection.addListener(_handleConnection);
  }

  final PlanningProtocolClient _client;
  late final AssetPrepareEventFilter _filter;
  late final StreamSubscription<Map<String, dynamic>> _subscription;

  @override
  Stream<AssetPrepareEvent> get assetPrepareEvents => _filter.events;

  void _handleConnection() {
    if (_client.connection.value != BackendConnection.connected) {
      _filter.reset();
    }
  }

  void _handleEnvelope(Map<String, dynamic> envelope) {
    // 봉투는 클라이언트가 이미 엄격히 검사했다.
    _filter.add(AssetPrepareEvent.fromWire(envelope['payload']));
  }

  Future<Object> _send(String method, Map<String, dynamic> payload) async {
    validateAssetPrepareRequestPayload(method, payload);
    return parseAssetPrepareSuccessPayload(
      method,
      await _client.send(method, payload),
    );
  }

  Future<AssetPrepareJob> _snapshotWire(AssetPrepareJobRef job) async {
    final snapshot =
        await _send(assetPrepareSnapshotMethod, job.toWire())
            as AssetPrepareJob;
    if (!job.matches(snapshot)) {
      throw const FormatException('Asset snapshot is for another job');
    }
    return snapshot;
  }

  @override
  Future<AssetPrepareStatus> assetPrepareStatus() async =>
      await _send(assetPrepareStatusMethod, const {}) as AssetPrepareStatus;

  @override
  Future<AssetPrepareStatus> setAssetGameDir(String? path) async =>
      await _send(
            assetPrepareGameDirSetMethod,
            AssetGameDirRequest(path).toWire(),
          )
          as AssetPrepareStatus;

  @override
  Future<AssetPrepareJobRef> startAssetPreparation() async {
    _filter.beginStart();
    AssetPrepareJobRef? job;
    try {
      job =
          await _send(assetPrepareStartMethod, const {}) as AssetPrepareJobRef;
      return job;
    } finally {
      _filter.endStart(job);
    }
  }

  @override
  Future<AssetPrepareCancelResult> cancelAssetPreparation(
    AssetPrepareJobRef job,
  ) async {
    final result =
        await _send(assetPrepareCancelMethod, job.toWire())
            as AssetPrepareCancelResult;
    if (result.job != job) {
      throw const FormatException('Asset cancel response is for another job');
    }
    return result;
  }

  @override
  Future<AssetPrepareJob> assetPrepareSnapshot(AssetPrepareJobRef job) async {
    final snapshot = await _snapshotWire(job);
    _filter.adopt(snapshot);
    return snapshot;
  }

  Future<void> dispose() async {
    _client.connection.removeListener(_handleConnection);
    await _subscription.cancel();
    await _filter.close();
  }
}
