// 메타데이터 관리자 새 6 메서드 strict DTO(M2, 계약 `contracts/developer-tools-metadata-manager-v1.schema.json`,
// 필드 정의 `debug/xb_m1_actual_20261011/artifacts/dart-new-method-fields.json`, XB M1 커밋 `1fbc4ddd`).
//
// - 요청은 exact `{version: 1, method, params}`이다. params도 계약의 키만 보낸다.
// - 응답은 exact `{version: 1, ok: true, result}` 또는 `{version: 1, ok: false, error: {type, message}}`이다. 키가 더 있거나
//   빠지거나, 타입 · enum · const · 해시 모양 · 조건(if/then)이 계약과 다르면 [MetadataManagerProtocolException]이다.
//   `ok: false`는 [MetadataManagerRemoteError]다(서버가 알린 실패, 예: 저장소 해시 불일치 · 섞인 버전).
// - 기존 20 메서드의 레거시 envelope 허용(`ToolBackend.call`)은 이 파일과 관계없다.
// - 값은 지어내지 않는다: 미입증 출처(`provenance: null` · `source_state: unknown` · `comparisons: []`), 기존 보고서가
//   없는 diff(`missing` · `disconnected`), 실물 검증 없는 자산 검사(`local_structure_only` · `M4_required`)를 그대로 담는다.
import 'package:flutter/foundation.dart';

/// 계약 버전.
const metadataManagerProtocolVersion = 1;

/// 새 6 메서드 이름.
abstract final class MetadataManagerMethod {
  static const storeStatus = 'store.status';
  static const storeVersions = 'store.versions';
  static const storeDiff = 'store.diff';
  static const sourceView = 'metadata.source.view';
  static const assetMapList = 'asset_map.list';
  static const assetMapCheck = 'asset_map.check';

  static const all = {
    storeStatus,
    storeVersions,
    storeDiff,
    sourceView,
    assetMapList,
    assetMapCheck,
  };
}

/// 응답(또는 요청)이 계약 모양과 다르다.
class MetadataManagerProtocolException implements Exception {
  const MetadataManagerProtocolException(this.message);

  final String message;

  @override
  String toString() => '메타데이터 관리자 응답이 계약과 다릅니다: $message';
}

/// 서버가 `ok: false`로 알린 실패.
class MetadataManagerRemoteError implements Exception {
  const MetadataManagerRemoteError({required this.type, required this.message});

  final String type;
  final String message;

  @override
  String toString() => '$type: $message';
}

final _sha256 = RegExp(r'^[a-f0-9]{64}$');
final _versionId = RegExp(r'^[a-z0-9][a-z0-9._-]*$');
final _studentId = RegExp(r'^[a-z0-9_]+$');
final _bundleName = RegExp(r'^[^/\\]+\.bundle$');

/// RFC 3339 날짜 · 시각(계약 `format: date-time`).
final _dateTime = RegExp(
  r'^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])[Tt]([01]\d|2[0-3]):[0-5]\d:[0-5]\d(\.\d+)?([Zz]|[+-]([01]\d|2[0-3]):[0-5]\d)$',
);

/// asset-map-v1 `plannerPath`: 상대 경로, 드라이브 · 역슬래시 · `..` 구간 없음.
bool _isPlannerPath(String value) {
  if (value.isEmpty || value.startsWith('/') || value.contains(r'\')) {
    return false;
  }
  // 계약 정규식의 `.`은 줄바꿈 문자를 받지 않는다.
  if (RegExp('[\n\r\u2028\u2029]').hasMatch(value)) return false;
  if (RegExp(r'^[A-Za-z]:').hasMatch(value)) return false;
  return !value.split('/').contains('..');
}

/// JSON 객체 하나를 계약대로 읽는다. 키 집합이 정확히 [keys]여야 한다.
class _Obj {
  _Obj(Object? raw, this.path, Set<String> keys) : _map = _exact(raw, path, keys);

  final String path;
  final Map<String, Object?> _map;

  static Map<String, Object?> _exact(
    Object? raw,
    String path,
    Set<String> keys,
  ) {
    if (raw is! Map) {
      throw MetadataManagerProtocolException('$path: 객체가 아닙니다');
    }
    final map = <String, Object?>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String) {
        throw MetadataManagerProtocolException('$path: 문자열이 아닌 키');
      }
      map[key] = entry.value;
    }
    final extra = map.keys.toSet().difference(keys);
    final missing = keys.difference(map.keys.toSet());
    if (extra.isNotEmpty || missing.isNotEmpty) {
      throw MetadataManagerProtocolException(
        '$path: 키가 다릅니다(더 있음 ${extra.toList()..sort()}, 빠짐 ${missing.toList()..sort()})',
      );
    }
    return map;
  }

  Object? raw(String key) => _map[key];

  String _at(String key) => '$path.$key';

  String string(String key, {bool nonEmpty = false}) {
    final value = _map[key];
    if (value is! String || (nonEmpty && value.isEmpty)) {
      throw MetadataManagerProtocolException('${_at(key)}: 문자열이 아닙니다');
    }
    return value;
  }

  String? nullableString(String key, {bool nonEmpty = false}) {
    final value = _map[key];
    if (value == null) return null;
    if (value is! String || (nonEmpty && value.isEmpty)) {
      throw MetadataManagerProtocolException('${_at(key)}: 문자열 또는 null이 아닙니다');
    }
    return value;
  }

  bool boolean(String key) {
    final value = _map[key];
    if (value is! bool) {
      throw MetadataManagerProtocolException('${_at(key)}: bool이 아닙니다');
    }
    return value;
  }

  /// 값이 정확히 [expected]여야 한다(정수는 bool과 구별한다).
  void constant(String key, Object expected) {
    final value = _map[key];
    final same = expected is int
        ? value is int && value == expected
        : value == expected;
    if (!same) {
      throw MetadataManagerProtocolException('${_at(key)}: $expected 이어야 합니다');
    }
  }

  T choice<T>(String key, Map<String, T> values) {
    final value = _map[key];
    final picked = value is String ? values[value] : null;
    if (picked == null) {
      throw MetadataManagerProtocolException(
        '${_at(key)}: ${values.keys.join(' / ')} 중 하나가 아닙니다',
      );
    }
    return picked;
  }

  String pattern(String key, RegExp expression) {
    final value = string(key);
    if (!expression.hasMatch(value)) {
      throw MetadataManagerProtocolException('${_at(key)}: 모양이 다릅니다');
    }
    return value;
  }

  List<Object?> list(String key) {
    final value = _map[key];
    if (value is! List) {
      throw MetadataManagerProtocolException('${_at(key)}: 배열이 아닙니다');
    }
    return value;
  }

  List<String> strings(String key) {
    final result = <String>[];
    for (final (index, item) in list(key).indexed) {
      if (item is! String) {
        throw MetadataManagerProtocolException('${_at(key)}[$index]: 문자열이 아닙니다');
      }
      result.add(item);
    }
    return result;
  }

  /// 값이 문자열 → SHA-256 hex인 객체(빈 객체 금지).
  Map<String, String> hashes(String key) {
    final value = _map[key];
    if (value is! Map || value.isEmpty) {
      throw MetadataManagerProtocolException('${_at(key)}: 파일 해시가 없습니다');
    }
    final result = <String, String>{};
    for (final entry in value.entries) {
      final name = entry.key;
      final hash = entry.value;
      if (name is! String || hash is! String || !_sha256.hasMatch(hash)) {
        throw MetadataManagerProtocolException('${_at(key)}: SHA-256 모양이 아닙니다');
      }
      result[name] = hash;
    }
    return Map.unmodifiable(result);
  }
}

/// 응답 envelope를 읽는다. 성공이면 [parse]의 결과, `ok: false`면 [MetadataManagerRemoteError].
T parseMetadataManagerResponse<T>(
  Object? message,
  T Function(Object? result) parse,
) {
  if (message is! Map) {
    throw const MetadataManagerProtocolException('envelope: 객체가 아닙니다');
  }
  final ok = message['ok'];
  if (ok is! bool) {
    throw const MetadataManagerProtocolException('envelope.ok: bool이 아닙니다');
  }
  final envelope = _Obj(
    message,
    'envelope',
    ok ? const {'version', 'ok', 'result'} : const {'version', 'ok', 'error'},
  );
  envelope.constant('version', metadataManagerProtocolVersion);
  if (!ok) {
    final error = _Obj(envelope.raw('error'), 'envelope.error', const {
      'type',
      'message',
    });
    throw MetadataManagerRemoteError(
      type: error.string('type'),
      message: error.string('message'),
    );
  }
  return parse(envelope.raw('result'));
}

// --- 요청 ---------------------------------------------------------------------

/// 서버(계약 enum).
enum StoreServer {
  jp('jp'),
  steam('steam');

  const StoreServer(this.wire);

  final String wire;

  static const byWire = {'jp': jp, 'steam': steam};
}

/// `store.diff`의 from · to.
@immutable
class StoreVersionRef {
  const StoreVersionRef({required this.server, required this.versionId});

  factory StoreVersionRef.fromJson(Object? raw, String path) {
    final object = _Obj(raw, path, const {'server', 'version_id'});
    return StoreVersionRef(
      server: object.choice('server', StoreServer.byWire),
      versionId: object.pattern('version_id', _versionId),
    );
  }

  final StoreServer server;
  final String versionId;

  /// 계약 모양(`^[a-z0-9][a-z0-9._-]*$`)인가.
  bool get isValid => _versionId.hasMatch(versionId);

  Map<String, Object?> toJson() => {
    'server': server.wire,
    'version_id': versionId,
  };

  @override
  bool operator ==(Object other) =>
      other is StoreVersionRef &&
      other.server == server &&
      other.versionId == versionId;

  @override
  int get hashCode => Object.hash(server, versionId);

  @override
  String toString() => '${server.wire}/$versionId';
}

/// `asset_map.check` 범위.
enum AssetCheckScope {
  all('all'),
  ui('ui'),
  recognition('recognition');

  const AssetCheckScope(this.wire);

  final String wire;

  static const byWire = {'all': all, 'ui': ui, 'recognition': recognition};
}

/// 새 6 메서드 요청 하나(exact `version/method/params`).
@immutable
class MetadataManagerRequest {
  const MetadataManagerRequest._(this.method, this.params);

  const MetadataManagerRequest.storeStatus()
    : this._(MetadataManagerMethod.storeStatus, const {});

  const MetadataManagerRequest.storeVersions()
    : this._(MetadataManagerMethod.storeVersions, const {});

  const MetadataManagerRequest.assetMapList()
    : this._(MetadataManagerMethod.assetMapList, const {});

  /// [from] · [to]의 version_id가 계약 모양이 아니면 [MetadataManagerProtocolException](보내지 않는다).
  /// 서버가 다른 두 버전(섞인 버전)은 계약 모양으로는 맞으므로 보내고, 서버가 `store_mixed_version`으로 거절한다.
  factory MetadataManagerRequest.storeDiff({
    required StoreVersionRef from,
    required StoreVersionRef to,
  }) {
    if (!from.isValid || !to.isValid) {
      throw const MetadataManagerProtocolException(
        'store.diff params: version_id 모양이 다릅니다',
      );
    }
    return MetadataManagerRequest._(MetadataManagerMethod.storeDiff, {
      'from': from.toJson(),
      'to': to.toJson(),
    });
  }

  /// [studentId]가 `^[a-z0-9_]+$`가 아니면 [MetadataManagerProtocolException].
  factory MetadataManagerRequest.sourceView(String studentId) {
    if (!_studentId.hasMatch(studentId)) {
      throw const MetadataManagerProtocolException(
        'metadata.source.view params: student_id 모양이 다릅니다',
      );
    }
    return MetadataManagerRequest._(MetadataManagerMethod.sourceView, {
      'student_id': studentId,
    });
  }

  MetadataManagerRequest.assetMapCheck(AssetCheckScope scope)
    : this._(MetadataManagerMethod.assetMapCheck, {'scope': scope.wire});

  /// 요청 envelope를 계약대로 읽는다(계약 fixture 검사용). 모양이 다르면 [MetadataManagerProtocolException].
  factory MetadataManagerRequest.fromJson(Object? raw) {
    final envelope = _Obj(raw, 'request', const {'version', 'method', 'params'});
    envelope.constant('version', metadataManagerProtocolVersion);
    final method = envelope.choice('method', {
      for (final name in MetadataManagerMethod.all) name: name,
    });
    final paramsRaw = envelope.raw('params');
    switch (method) {
      case MetadataManagerMethod.storeStatus:
      case MetadataManagerMethod.storeVersions:
      case MetadataManagerMethod.assetMapList:
        _Obj(paramsRaw, 'request.params', const {});
        return MetadataManagerRequest._(method, const {});
      case MetadataManagerMethod.storeDiff:
        final params = _Obj(paramsRaw, 'request.params', const {'from', 'to'});
        return MetadataManagerRequest.storeDiff(
          from: StoreVersionRef.fromJson(params.raw('from'), 'request.params.from'),
          to: StoreVersionRef.fromJson(params.raw('to'), 'request.params.to'),
        );
      case MetadataManagerMethod.sourceView:
        final params = _Obj(paramsRaw, 'request.params', const {'student_id'});
        return MetadataManagerRequest.sourceView(params.string('student_id'));
      default:
        final params = _Obj(paramsRaw, 'request.params', const {'scope'});
        return MetadataManagerRequest.assetMapCheck(
          params.choice('scope', AssetCheckScope.byWire),
        );
    }
  }

  final String method;
  final Map<String, Object?> params;

  Map<String, Object?> toJson() => {
    'version': metadataManagerProtocolVersion,
    'method': method,
    'params': params,
  };
}

// --- store.status --------------------------------------------------------------

/// 저장소 연결 상태.
enum StoreConnection { connected, disconnected }

const _connectionByWire = {
  'connected': StoreConnection.connected,
  'disconnected': StoreConnection.disconnected,
};

/// lock에 고정된 서버 버전 하나(`pins.jp` · `pins.steam`).
@immutable
class StorePin {
  const StorePin({
    required this.versionId,
    required this.clientVersion,
    required this.bundleRevision,
    required this.files,
  });

  factory StorePin.fromJson(Object? raw, String path) {
    final object = _Obj(raw, path, const {
      'version_id',
      'client_version',
      'bundle_revision',
      'files',
    });
    return StorePin(
      versionId: object.string('version_id'),
      clientVersion: object.nullableString('client_version'),
      bundleRevision: object.nullableString('bundle_revision'),
      files: object.hashes('files'),
    );
  }

  final String versionId;
  final String? clientVersion;
  final String? bundleRevision;

  /// 파일 이름 → SHA-256.
  final Map<String, String> files;
}

/// lock의 extract 하나.
@immutable
class StoreExtract {
  const StoreExtract({
    required this.server,
    required this.versionId,
    required this.kind,
    required this.path,
    required this.provenanceSha256,
    required this.files,
  });

  factory StoreExtract.fromJson(Object? raw, String path) {
    final object = _Obj(raw, path, const {
      'server',
      'version_id',
      'kind',
      'path',
      'provenance_sha256',
      'files',
    });
    return StoreExtract(
      server: object.choice('server', StoreServer.byWire),
      versionId: object.string('version_id'),
      kind: object.string('kind'),
      path: object.string('path'),
      provenanceSha256: object.pattern('provenance_sha256', _sha256),
      files: object.hashes('files'),
    );
  }

  final StoreServer server;
  final String versionId;
  final String kind;
  final String path;
  final String provenanceSha256;
  final Map<String, String> files;
}

/// `store.status` 결과. `verification`은 늘 `not_verified`다(해시를 다시 계산하지 않았다).
@immutable
class StoreStatus {
  const StoreStatus({
    required this.state,
    required this.storeRoot,
    required this.pins,
    required this.extracts,
    required this.missingKinds,
  });

  factory StoreStatus.fromJson(Object? raw) {
    final object = _Obj(raw, 'store.status', const {
      'state',
      'store_root',
      'pins',
      'extracts',
      'verification',
      'missing_kinds',
    });
    object.constant('verification', 'not_verified');
    final pinsRaw = object.raw('pins');
    if (pinsRaw is! Map || pinsRaw.isEmpty) {
      throw const MetadataManagerProtocolException('store.status.pins: 고정 버전이 없습니다');
    }
    final pins = <StoreServer, StorePin>{};
    for (final entry in pinsRaw.entries) {
      final key = entry.key;
      final server = key is String ? StoreServer.byWire[key] : null;
      if (server == null) {
        throw MetadataManagerProtocolException('store.status.pins: 모르는 서버 $key');
      }
      pins[server] = StorePin.fromJson(entry.value, 'store.status.pins.$key');
    }
    return StoreStatus(
      state: object.choice('state', _connectionByWire),
      storeRoot: object.string('store_root'),
      pins: Map.unmodifiable(pins),
      extracts: List.unmodifiable([
        for (final (index, item) in object.list('extracts').indexed)
          StoreExtract.fromJson(item, 'store.status.extracts[$index]'),
      ]),
      missingKinds: List.unmodifiable(object.strings('missing_kinds')),
    );
  }

  final StoreConnection state;
  final String storeRoot;
  final Map<StoreServer, StorePin> pins;
  final List<StoreExtract> extracts;
  final List<String> missingKinds;

  bool get connected => state == StoreConnection.connected;
}

// --- store.versions ------------------------------------------------------------

/// 저장소에 등록된 버전 하나. `verification`은 늘 `manifest_only`다.
@immutable
class StoreVersion {
  const StoreVersion({
    required this.server,
    required this.versionId,
    required this.pinned,
    required this.clientVersion,
    required this.bundleRevision,
    required this.manifestSha256,
  });

  factory StoreVersion.fromJson(Object? raw, String path) {
    final object = _Obj(raw, path, const {
      'server',
      'version_id',
      'pinned',
      'client_version',
      'bundle_revision',
      'manifest_sha256',
      'verification',
    });
    object.constant('verification', 'manifest_only');
    return StoreVersion(
      server: object.choice('server', StoreServer.byWire),
      versionId: object.string('version_id'),
      pinned: object.boolean('pinned'),
      clientVersion: object.nullableString('client_version'),
      bundleRevision: object.nullableString('bundle_revision'),
      manifestSha256: object.pattern('manifest_sha256', _sha256),
    );
  }

  final StoreServer server;
  final String versionId;
  final bool pinned;
  final String? clientVersion;
  final String? bundleRevision;
  final String manifestSha256;

  StoreVersionRef get ref => StoreVersionRef(server: server, versionId: versionId);
}

/// `store.versions` 결과. 미연결이면 버전 목록은 비어 있어야 한다.
@immutable
class StoreVersions {
  const StoreVersions({required this.state, required this.versions});

  factory StoreVersions.fromJson(Object? raw) {
    final object = _Obj(raw, 'store.versions', const {'state', 'versions'});
    final state = object.choice('state', _connectionByWire);
    final versions = [
      for (final (index, item) in object.list('versions').indexed)
        StoreVersion.fromJson(item, 'store.versions.versions[$index]'),
    ];
    if (state == StoreConnection.disconnected && versions.isNotEmpty) {
      throw const MetadataManagerProtocolException(
        'store.versions: 미연결인데 버전 목록이 있습니다',
      );
    }
    return StoreVersions(state: state, versions: List.unmodifiable(versions));
  }

  final StoreConnection state;
  final List<StoreVersion> versions;
}

// --- store.diff ----------------------------------------------------------------

/// `store.diff` 상태. `missing` · `disconnected`는 "차이 0"이 아니다(보고서가 없다).
enum StoreDiffState { disconnected, missing, available }

/// L1 파일 판정.
enum StoreFileChange {
  same('same'),
  changed('changed'),
  onlyInA('only_in_a'),
  onlyInB('only_in_b');

  const StoreFileChange(this.wire);

  final String wire;

  static const byWire = {
    'same': same,
    'changed': changed,
    'only_in_a': onlyInA,
    'only_in_b': onlyInB,
  };
}

/// 저장소에 이미 있는 차이 보고서(`ba-client-data.changelog.v1`). 새로 비교하지 않는다.
@immutable
class StoreDiffReport {
  const StoreDiffReport({
    required this.server,
    required this.a,
    required this.b,
    required this.generatedUtc,
    required this.levelOneFiles,
    required this.levelTwoExtracts,
    required this.levelThreeBehavior,
  });

  factory StoreDiffReport.fromJson(Object? raw, String path) {
    final object = _Obj(raw, path, const {
      'schema',
      'server',
      'a',
      'b',
      'generated_utc',
      'level1_files',
      'level2_extracts',
      'level3_behavior',
    });
    object.constant('schema', 'ba-client-data.changelog.v1');
    final generated = object.string('generated_utc');
    if (!_dateTime.hasMatch(generated)) {
      throw MetadataManagerProtocolException('$path.generated_utc: 날짜가 아닙니다');
    }
    final levelOneRaw = object.raw('level1_files');
    if (levelOneRaw is! Map) {
      throw MetadataManagerProtocolException('$path.level1_files: 객체가 아닙니다');
    }
    final levelOne = <String, StoreFileChange>{};
    for (final entry in levelOneRaw.entries) {
      final name = entry.key;
      final value = entry.value;
      final change = value is String ? StoreFileChange.byWire[value] : null;
      if (name is! String || change == null) {
        throw MetadataManagerProtocolException('$path.level1_files: 판정이 다릅니다');
      }
      levelOne[name] = change;
    }
    final levelTwoRaw = object.raw('level2_extracts');
    if (levelTwoRaw is! Map) {
      throw MetadataManagerProtocolException('$path.level2_extracts: 객체가 아닙니다');
    }
    final levelTwo = <String, Map<String, Object?>>{};
    for (final entry in levelTwoRaw.entries) {
      final kind = entry.key;
      final value = entry.value;
      if (kind is! String || value is! Map) {
        throw MetadataManagerProtocolException('$path.level2_extracts: kind 값이 객체가 아닙니다');
      }
      levelTwo[kind] = Map.unmodifiable({
        for (final item in value.entries) item.key.toString(): item.value,
      });
    }
    return StoreDiffReport(
      server: object.choice('server', StoreServer.byWire),
      a: object.string('a'),
      b: object.string('b'),
      generatedUtc: generated,
      levelOneFiles: Map.unmodifiable(levelOne),
      levelTwoExtracts: Map.unmodifiable(levelTwo),
      levelThreeBehavior: object.string('level3_behavior'),
    );
  }

  final StoreServer server;
  final String a;
  final String b;
  final String generatedUtc;
  final Map<String, StoreFileChange> levelOneFiles;

  /// kind → 표별 요약(원문 그대로).
  final Map<String, Map<String, Object?>> levelTwoExtracts;
  final String levelThreeBehavior;
}

/// `store.diff` 결과. `available`이면 보고서가 있고 `report_identity_only`, 그 밖은 보고서 없음 · `not_verified`.
@immutable
class StoreDiff {
  const StoreDiff({
    required this.state,
    required this.from,
    required this.to,
    required this.report,
    required this.coverage,
  });

  factory StoreDiff.fromJson(Object? raw) {
    final object = _Obj(raw, 'store.diff', const {
      'state',
      'from',
      'to',
      'report',
      'coverage',
      'verification',
    });
    final state = object.choice('state', const {
      'disconnected': StoreDiffState.disconnected,
      'missing': StoreDiffState.missing,
      'available': StoreDiffState.available,
    });
    final reportRaw = object.raw('report');
    final StoreDiffReport? report;
    if (state == StoreDiffState.available) {
      if (reportRaw == null) {
        throw const MetadataManagerProtocolException('store.diff: available인데 보고서가 없습니다');
      }
      object.constant('verification', 'report_identity_only');
      report = StoreDiffReport.fromJson(reportRaw, 'store.diff.report');
    } else {
      if (reportRaw != null) {
        throw MetadataManagerProtocolException(
          'store.diff: ${state.name}인데 보고서가 있습니다',
        );
      }
      object.constant('verification', 'not_verified');
      report = null;
    }
    return StoreDiff(
      state: state,
      from: StoreVersionRef.fromJson(object.raw('from'), 'store.diff.from'),
      to: StoreVersionRef.fromJson(object.raw('to'), 'store.diff.to'),
      report: report,
      coverage: object.string('coverage'),
    );
  }

  final StoreDiffState state;
  final StoreVersionRef from;
  final StoreVersionRef to;
  final StoreDiffReport? report;
  final String coverage;
}

// --- metadata.source.view -------------------------------------------------------

/// 필드 값 상태.
enum SourceValueState { present, unknown }

/// 필드 하나. M1 계약에서 출처는 늘 미입증이다(`source_state: unknown`, `provenance: null`, `comparisons: []`).
@immutable
class SourceField {
  const SourceField({
    required this.field,
    required this.value,
    required this.valueState,
  });

  factory SourceField.fromJson(Object? raw, String path) {
    final object = _Obj(raw, path, const {
      'field',
      'value',
      'value_state',
      'source_state',
      'provenance',
      'comparisons',
    });
    object.constant('source_state', 'unknown');
    if (object.raw('provenance') != null) {
      throw MetadataManagerProtocolException('$path.provenance: M1 계약에서는 null이어야 합니다');
    }
    if (object.list('comparisons').isNotEmpty) {
      throw MetadataManagerProtocolException('$path.comparisons: M1 계약에서는 비어 있어야 합니다');
    }
    return SourceField(
      field: object.string('field'),
      value: object.raw('value'),
      valueState: object.choice('value_state', const {
        'present': SourceValueState.present,
        'unknown': SourceValueState.unknown,
      }),
    );
  }

  final String field;

  /// 현재 값(JSON 그대로).
  final Object? value;
  final SourceValueState valueState;

  /// 출처를 아는가. M1 계약에서는 늘 false(확인되지 않음)다.
  bool get sourceKnown => false;
}

/// `metadata.source.view` 결과. `comparison_state`는 늘 `not_verified`다.
@immutable
class SourceView {
  const SourceView({
    required this.studentId,
    required this.fields,
    required this.unavailableGroups,
    required this.note,
  });

  factory SourceView.fromJson(Object? raw) {
    final object = _Obj(raw, 'metadata.source.view', const {
      'student_id',
      'fields',
      'comparison_state',
      'unavailable_groups',
      'note',
    });
    object.constant('comparison_state', 'not_verified');
    return SourceView(
      studentId: object.string('student_id'),
      fields: List.unmodifiable([
        for (final (index, item) in object.list('fields').indexed)
          SourceField.fromJson(item, 'metadata.source.view.fields[$index]'),
      ]),
      unavailableGroups: List.unmodifiable(object.strings('unavailable_groups')),
      note: object.string('note'),
    );
  }

  final String studentId;
  final List<SourceField> fields;
  final List<String> unavailableGroups;
  final String note;
}

// --- asset_map.list · asset_map.check ------------------------------------------

/// 자산 역할.
enum AssetRole { ui, recognition }

const _roleByWire = {'ui': AssetRole.ui, 'recognition': AssetRole.recognition};

/// 매핑 출처(`catalog` = 카탈로그 역추적, `manual` = 수동).
enum AssetMappingSource { catalog, manual }

const _mappingByWire = {
  'catalog': AssetMappingSource.catalog,
  'manual': AssetMappingSource.manual,
};

/// asset-map-v1 자산 하나(M0 초안).
@immutable
class AssetMapEntry {
  const AssetMapEntry({
    required this.plannerPath,
    required this.role,
    required this.addressKey,
    required this.bundle,
    required this.textureName,
    required this.source,
    required this.clientKind,
    required this.note,
  });

  factory AssetMapEntry.fromJson(Object? raw, String path) {
    final object = _Obj(raw, path, const {
      'plannerPath',
      'role',
      'addressKey',
      'bundle',
      'textureName',
      'source',
      'clientKind',
      'note',
    });
    final plannerPath = object.string('plannerPath');
    if (!_isPlannerPath(plannerPath)) {
      throw MetadataManagerProtocolException('$path.plannerPath: 상대 경로가 아닙니다');
    }
    final source = object.choice('source', _mappingByWire);
    final addressKey = object.nullableString('addressKey', nonEmpty: true);
    final bundle = object.nullableString('bundle', nonEmpty: true);
    final textureName = object.nullableString('textureName', nonEmpty: true);
    if (source == AssetMappingSource.catalog) {
      if (addressKey == null || bundle == null || !_bundleName.hasMatch(bundle)) {
        throw MetadataManagerProtocolException('$path: catalog 매핑에 주소 키 · 번들이 없습니다');
      }
    } else if (addressKey != null || bundle != null || textureName != null) {
      throw MetadataManagerProtocolException('$path: manual 매핑은 주소 키 · 번들 · 텍스처가 null이어야 합니다');
    }
    return AssetMapEntry(
      plannerPath: plannerPath,
      role: object.choice('role', _roleByWire),
      addressKey: addressKey,
      bundle: bundle,
      textureName: textureName,
      source: source,
      clientKind: object.choice('clientKind', StoreServer.byWire),
      note: object.string('note', nonEmpty: true),
    );
  }

  final String plannerPath;
  final AssetRole role;
  final String? addressKey;
  final String? bundle;
  final String? textureName;
  final AssetMappingSource source;
  final StoreServer clientKind;
  final String note;
}

/// `asset_map.list` 결과(M0 초안, 실물 검증 없음).
@immutable
class AssetMapList {
  const AssetMapList({required this.assets});

  factory AssetMapList.fromJson(Object? raw) {
    final object = _Obj(raw, 'asset_map.list', const {
      'map_version',
      'inventory_status',
      'assets',
      'verification',
    });
    object.constant('map_version', 1);
    object.constant('inventory_status', 'M0-draft');
    object.constant('verification', 'M0_mapping_draft; physical_not_verified');
    return AssetMapList(
      assets: List.unmodifiable([
        for (final (index, item) in object.list('assets').indexed)
          AssetMapEntry.fromJson(item, 'asset_map.list.assets[$index]'),
      ]),
    );
  }

  final List<AssetMapEntry> assets;
}

/// 로컬 파일 상태.
enum AssetLocalFile { present, missing }

/// `asset_map.check` 행 하나. 구조만 확인했다(`structure_state: valid`, `physical_state: not_verified`).
@immutable
class AssetCheckRow {
  const AssetCheckRow({
    required this.plannerPath,
    required this.role,
    required this.localFile,
    required this.mapping,
  });

  factory AssetCheckRow.fromJson(Object? raw, String path) {
    final object = _Obj(raw, path, const {
      'plannerPath',
      'role',
      'structure_state',
      'local_file_state',
      'mapping_state',
      'physical_state',
    });
    object.constant('structure_state', 'valid');
    object.constant('physical_state', 'not_verified');
    return AssetCheckRow(
      plannerPath: object.string('plannerPath'),
      role: object.choice('role', _roleByWire),
      localFile: object.choice('local_file_state', const {
        'present': AssetLocalFile.present,
        'missing': AssetLocalFile.missing,
      }),
      mapping: object.choice('mapping_state', _mappingByWire),
    );
  }

  final String plannerPath;
  final AssetRole role;
  final AssetLocalFile localFile;
  final AssetMappingSource mapping;
}

/// `asset_map.check` 결과. 실물 검증은 M4가 한다(`physical_validation: M4_required`,
/// `source_verification: local_structure_only`).
@immutable
class AssetCheck {
  const AssetCheck({required this.scope, required this.rows});

  factory AssetCheck.fromJson(Object? raw) {
    final object = _Obj(raw, 'asset_map.check', const {
      'scope',
      'rows',
      'physical_validation',
      'source_verification',
    });
    object.constant('physical_validation', 'M4_required');
    object.constant('source_verification', 'local_structure_only');
    return AssetCheck(
      scope: object.choice('scope', AssetCheckScope.byWire),
      rows: List.unmodifiable([
        for (final (index, item) in object.list('rows').indexed)
          AssetCheckRow.fromJson(item, 'asset_map.check.rows[$index]'),
      ]),
    );
  }

  final AssetCheckScope scope;
  final List<AssetCheckRow> rows;
}
