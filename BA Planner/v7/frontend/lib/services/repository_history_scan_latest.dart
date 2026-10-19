part of 'repository_history_service.dart';

// FB-2b `repository.history.scan_latest` (contracts/repository-history-scan-latest-v1.schema.json).
// Read-only latest scan metadata taken from the persisted `latest_scans` index and
// `last_applied_at.scan`. Never reconstructs from retained events, never samples a clock,
// migrates, prunes or writes. The strict Unicode-scalar text policy below belongs only to this
// new query/DTO boundary; existing stored history/cache validators are not tightened.

const _scanLatestReasons = ['unrecorded', 'scan_not_found'];
const _scanLatestControls = [
  'by_kind_limit',
  'by_kind_after_sequence',
  'anchor_history_sequence',
];
const _scanLatestEntryKeys = {
  'sequence',
  'recorded_at',
  'session_id',
  'scan_kind',
  'inventory_scan_profile',
};

/// Valid Unicode scalar text of 1..1024 UTF-8 bytes, raw (no trim/enum).
/// Isolated surrogates are rejected before UTF-8 encoding: `utf8.encode` would
/// silently replace them with U+FFFD and hide the error.
String _scalarText(Object? value) {
  if (value is! String || value.isEmpty) {
    _bad('Expected non-empty Unicode scalar text');
  }
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (i + 1 >= value.length) _bad('Isolated surrogate');
      final next = value.codeUnitAt(i + 1);
      if (next < 0xDC00 || next > 0xDFFF) _bad('Isolated surrogate');
      i++;
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      _bad('Isolated surrogate');
    }
  }
  if (utf8.encode(value).length > 1024) _bad('Text exceeds 1024 UTF-8 bytes');
  return value;
}

Map<String, dynamic> _scanLatestRequest(Object? value) {
  final d = _queryShape(
    value,
    {'profile_id'},
    {'student_ids', 'resource_keys', 'include_by_kind', ..._scanLatestControls},
  );
  _profileId(d['profile_id']);
  if (d.containsKey('include_by_kind') && d['include_by_kind'] is! bool) {
    _bad('include_by_kind must be boolean');
  }
  final include = d['include_by_kind'] == true;
  if (!include && _scanLatestControls.any(d.containsKey)) {
    _bad('Kind paging controls require include_by_kind=true');
  }
  if (d.containsKey('by_kind_limit') && _int(d['by_kind_limit'], 1) > 200) {
    _bad('by_kind_limit must be 1..200');
  }
  final after = d.containsKey('by_kind_after_sequence')
      ? _int(d['by_kind_after_sequence'])
      : 0;
  final anchor = d.containsKey('anchor_history_sequence')
      ? _int(d['anchor_history_sequence'])
      : null;
  if (after > 0 && anchor == null) {
    _bad('Positive by_kind_after_sequence requires anchor_history_sequence');
  }
  if (anchor != null && after > anchor) {
    _bad('by_kind_after_sequence exceeds the anchor');
  }
  for (final (key, resources) in [
    ('student_ids', false),
    ('resource_keys', true),
  ]) {
    if (!d.containsKey(key)) continue;
    final raw = d[key];
    if (raw is! List || raw.length > 256) _bad('Expected at most 256 targets');
    // Canonical resource aliases precede the uniqueness check.
    final ids = [
      for (final item in raw)
        resources
            ? _scalarText(historyCanonicalResourceKey(_scalarText(item)))
            : _scalarText(item),
    ];
    if (ids.toSet().length != ids.length) _bad('duplicate_identity');
    d[key] = ids..sort(_historyIdCompare);
  }
  return d;
}

class RepositoryHistoryScanLatestRequest {
  RepositoryHistoryScanLatestRequest.fromWire(Map<String, dynamic> value)
    : _wire = _freeze(_scanLatestRequest(value)) as Map<String, dynamic>;
  RepositoryHistoryScanLatestRequest({
    required String profileId,
    List<String>? studentIds,
    List<String>? resourceKeys,
    bool? includeByKind,
    int? byKindLimit,
    int? byKindAfterSequence,
    int? anchorHistorySequence,
  }) : this.fromWire({
         'profile_id': profileId,
         'student_ids': ?studentIds,
         'resource_keys': ?resourceKeys,
         'include_by_kind': ?includeByKind,
         'by_kind_limit': ?byKindLimit,
         'by_kind_after_sequence': ?byKindAfterSequence,
         'anchor_history_sequence': ?anchorHistorySequence,
       });
  final Map<String, dynamic> _wire;
  String get profileId => _wire['profile_id'] as String;

  /// Requested IDs in Unicode scalar order (resource keys already canonical).
  List<String> get studentIds =>
      List.unmodifiable((_wire['student_ids'] as List? ?? const []).cast<String>());
  List<String> get resourceKeys => List.unmodifiable(
    (_wire['resource_keys'] as List? ?? const []).cast<String>(),
  );
  bool get includeByKind => _wire['include_by_kind'] == true;
  int get byKindLimit => _wire['by_kind_limit'] as int? ?? 100;
  int get byKindAfterSequence => _wire['by_kind_after_sequence'] as int? ?? 0;
  int? get anchorHistorySequence => _wire['anchor_history_sequence'] as int?;

  /// The next by-kind page of the same snapshot (anchor = first page history_sequence).
  RepositoryHistoryScanLatestRequest nextKindPage(
    RepositoryHistoryScanLatestResult page,
  ) {
    final after = page.byKindNextAfterSequence;
    if (after == null) _bad('No further by-kind page');
    return RepositoryHistoryScanLatestRequest.fromWire({
      ..._copy(_wire),
      'include_by_kind': true,
      'by_kind_after_sequence': after,
      'anchor_history_sequence': page.historySequence,
    });
  }

  Map<String, dynamic> toWire() => _copy(_wire);
}

/// One latest scan application (exact5). `inventoryScanProfile` is the raw
/// profile string or null; unknown raw strings are kept as they are.
class HistoryLatestScan {
  HistoryLatestScan._(this._wire);
  final Map<String, dynamic> _wire;
  int get sequence => _wire['sequence'] as int;
  String get recordedAt => _wire['recorded_at'] as String;
  String get sessionId => _wire['session_id'] as String;
  String get scanKind => _wire['scan_kind'] as String;
  String? get inventoryScanProfile =>
      _wire['inventory_scan_profile'] as String?;
  Map<String, dynamic> toWire() => _copy(_wire);
}

/// `latestScan == null` means `reason` is `unrecorded` (no history) or
/// `scan_not_found` (history exists). It never means quantity/value zero.
class HistoryStudentScanLatest {
  HistoryStudentScanLatest._(this._wire);
  final Map<String, dynamic> _wire;
  String get studentId => _wire['student_id'] as String;
  HistoryLatestScan? get latestScan => _wire['latest_scan'] == null
      ? null
      : HistoryLatestScan._(_map(_wire['latest_scan'], null));
  String? get reason => _wire['reason'] as String?;
  Map<String, dynamic> toWire() => _copy(_wire);
}

class HistoryResourceScanLatest {
  HistoryResourceScanLatest._(this._wire);
  final Map<String, dynamic> _wire;
  String get resourceKey => _wire['resource_key'] as String;
  HistoryLatestScan? get latestScan => _wire['latest_scan'] == null
      ? null
      : HistoryLatestScan._(_map(_wire['latest_scan'], null));
  String? get reason => _wire['reason'] as String?;
  Map<String, dynamic> toWire() => _copy(_wire);
}

Map<String, dynamic> _latestScanEntry(Object? value, int historySequence) {
  final scan = _map(value, _scanLatestEntryKeys);
  final sequence = _int(scan['sequence'], 1);
  if (sequence > historySequence) _bad('Latest scan is beyond history sequence');
  _time(scan['recorded_at']);
  _scalarText(scan['session_id']);
  _scalarText(scan['scan_kind']);
  if (scan['inventory_scan_profile'] != null) {
    _scalarText(scan['inventory_scan_profile']);
  }
  return scan;
}

Map<String, dynamic> _scanLatestResult(Object? value) {
  final d = _map(value, {
    'profile_id',
    'revision',
    'history_sequence',
    'last_scan_at',
    'by_kind',
    'by_student_id',
    'by_resource_key',
    'by_kind_next_after_sequence',
  });
  _profileId(d['profile_id']);
  _int(d['revision']);
  final hseq = _int(d['history_sequence']);
  final lastScan = _time(d['last_scan_at'], nullable: true);
  final kinds = d['by_kind'];
  if (kinds is! List || kinds.length > 200) _bad('Invalid by_kind page');
  var previous = 0;
  _list(kinds, (raw) {
    final scan = _latestScanEntry(raw, hseq);
    if ((scan['sequence'] as int) <= previous) {
      _bad('by_kind must be in ascending latest sequence order');
    }
    previous = scan['sequence'] as int;
    return historyCanonicalJson([
      scan['scan_kind'],
      scan['inventory_scan_profile'],
    ]);
  });
  final next = d['by_kind_next_after_sequence'];
  if (next != null &&
      (_int(next, 1) != previous || kinds.isEmpty)) {
    _bad('Invalid by_kind_next_after_sequence');
  }
  final reasons = <String>{};
  var found = false;
  for (final (bucket, identity, resources) in [
    ('by_student_id', 'student_id', false),
    ('by_resource_key', 'resource_key', true),
  ]) {
    final rows = d[bucket];
    if (rows is! List || rows.length > 256) _bad('Invalid $bucket rows');
    String? prior;
    for (final raw in rows) {
      final row = _map(raw, {identity, 'latest_scan', 'reason'});
      final id = _scalarText(row[identity]);
      if (resources && historyCanonicalResourceKey(id) != id) {
        _bad('Resource rows use canonical keys');
      }
      if (prior != null && _historyIdCompare(prior, id) >= 0) {
        _bad('$bucket must be unique in Unicode scalar order');
      }
      prior = id;
      if (row['latest_scan'] == null) {
        if (!_scanLatestReasons.contains(row['reason'])) {
          _bad('Missing latest scan requires a reason');
        }
        reasons.add(row['reason'] as String);
      } else {
        if (row['reason'] != null) _bad('Recorded latest scan has no reason');
        _latestScanEntry(row['latest_scan'], hseq);
        found = true;
      }
    }
  }
  if (lastScan == null && (kinds.isNotEmpty || next != null || found)) {
    _bad('No profile scan time means no scan metadata');
  }
  if (reasons.contains('unrecorded') &&
      (reasons.length != 1 || found || hseq != 0 || lastScan != null)) {
    _bad('Unrecorded rows require an absent history');
  }
  return _copy(d);
}

class RepositoryHistoryScanLatestResult {
  RepositoryHistoryScanLatestResult._(Map<String, dynamic> wire)
    : _wire = _freeze(wire) as Map<String, dynamic>;
  factory RepositoryHistoryScanLatestResult.fromWire(
    Map<String, dynamic> value,
  ) => RepositoryHistoryScanLatestResult._(_scanLatestResult(value));

  /// Strict decode plus the request correspondence the endpoint guarantees:
  /// one row per requested target in request order, no by-kind rows unless
  /// requested, page bounds, and the same anchor.
  factory RepositoryHistoryScanLatestResult.fromWireFor(
    RepositoryHistoryScanLatestRequest request,
    Map<String, dynamic> value,
  ) {
    final result = RepositoryHistoryScanLatestResult.fromWire(value);
    final kinds = result.byKind;
    final anchor = request.anchorHistorySequence;
    if (result.profileId != request.profileId ||
        !_sameIds(
          result.byStudentId.map((row) => row.studentId),
          request.studentIds,
        ) ||
        !_sameIds(
          result.byResourceKey.map((row) => row.resourceKey),
          request.resourceKeys,
        ) ||
        (!request.includeByKind &&
            (kinds.isNotEmpty || result.byKindNextAfterSequence != null)) ||
        kinds.length > request.byKindLimit ||
        kinds.any((scan) => scan.sequence <= request.byKindAfterSequence) ||
        (result.byKindNextAfterSequence != null &&
            kinds.length != request.byKindLimit) ||
        (anchor != null && result.historySequence != anchor)) {
      _bad('scan_latest response does not match its request');
    }
    return result;
  }

  final Map<String, dynamic> _wire;
  String get profileId => _wire['profile_id'] as String;
  int get revision => _wire['revision'] as int;
  int get historySequence => _wire['history_sequence'] as int;

  /// Profile latest scan time; null iff no scan was ever applied. Filters that
  /// match nothing or `include_by_kind=false` do not make this null.
  String? get lastScanAt => _wire['last_scan_at'] as String?;
  List<HistoryLatestScan> get byKind => List.unmodifiable(
    (_wire['by_kind'] as List).map((s) => HistoryLatestScan._(_map(s, null))),
  );
  List<HistoryStudentScanLatest> get byStudentId => List.unmodifiable(
    (_wire['by_student_id'] as List).map(
      (r) => HistoryStudentScanLatest._(_map(r, null)),
    ),
  );
  List<HistoryResourceScanLatest> get byResourceKey => List.unmodifiable(
    (_wire['by_resource_key'] as List).map(
      (r) => HistoryResourceScanLatest._(_map(r, null)),
    ),
  );
  int? get byKindNextAfterSequence =>
      _wire['by_kind_next_after_sequence'] as int?;
  Map<String, dynamic> toWire() => _copy(_wire);
}

bool _sameIds(Iterable<String> a, List<String> b) {
  final x = a.toList();
  if (x.length != b.length) return false;
  for (var i = 0; i < x.length; i++) {
    if (x[i] != b[i]) return false;
  }
  return true;
}

/// Backend-equivalent failure of the scan_latest query (`details.reason`).
/// `stale_scan_latest`: a new current application moved the anchor; discard the
/// accumulated pages and restart from the first page. Never retryable as is.
class RepositoryHistoryScanLatestError implements Exception {
  const RepositoryHistoryScanLatestError(this.code, this.reason, this.message);
  final String code;
  final String reason;
  final String message;
  bool get retryable => false;
  @override
  String toString() => 'RepositoryHistoryScanLatestError($code/$reason): $message';
}

Map<String, dynamic> _storedLatestScan(
  Object? value,
  int historySequence,
  String? identity,
) {
  try {
    final item = _map(value, {..._scanLatestEntryKeys, ?identity});
    final scan = {for (final key in _scanLatestEntryKeys) key: item[key]};
    return _latestScanEntry(scan, historySequence);
  } on FormatException catch (error) {
    throw RepositoryHistoryScanLatestError(
      'corrupt_data',
      'corrupt_data',
      'Invalid stored latest scan entry: ${error.message}',
    );
  }
}

RepositoryHistoryScanLatestResult _scanLatest(
  String profileId,
  int revision,
  Map<String, dynamic>? history,
  RepositoryHistoryScanLatestRequest request,
) {
  if (request.profileId != profileId) _bad('History query profile mismatch');
  final hseq = history == null ? 0 : (history['next_sequence'] as int) - 1;
  final anchor = request.anchorHistorySequence;
  if (anchor != null && anchor != hseq) {
    throw const RepositoryHistoryScanLatestError(
      'invalid_payload',
      'stale_scan_latest',
      'History changed; restart scan_latest from the first page',
    );
  }
  final lastScan = history == null
      ? null
      : (history['last_applied_at'] as Map)['scan'] as String?;
  // A null profile scan time means no scan metadata; requested rows still stay.
  final index = history != null && lastScan != null
      ? _map(history['latest_scans'], null)
      : null;
  var byKind = <Map<String, dynamic>>[];
  int? next;
  if (index != null) {
    final kinds = [
      for (final item in index['by_kind'] as List)
        _storedLatestScan(item, hseq, null),
    ];
    final sequences = kinds.map((item) => item['sequence']).toSet();
    final tuples = kinds
        .map(
          (item) => historyCanonicalJson([
            item['scan_kind'],
            item['inventory_scan_profile'],
          ]),
        )
        .toSet();
    if (sequences.length != kinds.length || tuples.length != kinds.length) {
      // Impossible duplicates are reported, not repaired.
      throw const RepositoryHistoryScanLatestError(
        'corrupt_data',
        'corrupt_data',
        'Impossible duplicate latest kind sequence or identity',
      );
    }
    if (request.includeByKind) {
      final page =
          kinds
              .where(
                (item) =>
                    (item['sequence'] as int) > request.byKindAfterSequence,
              )
              .toList()
            ..sort(
              (a, b) => (a['sequence'] as int).compareTo(b['sequence'] as int),
            );
      byKind = page.take(request.byKindLimit).toList();
      if (page.length > request.byKindLimit) {
        next = byKind.last['sequence'] as int;
      }
    }
  }
  final reason = history == null ? 'unrecorded' : 'scan_not_found';
  final rows = <String, List<Map<String, dynamic>>>{};
  for (final (bucket, identity, targets) in [
    ('by_student_id', 'student_id', request.studentIds),
    ('by_resource_key', 'resource_key', request.resourceKeys),
  ]) {
    final mapping = <String, Object?>{
      if (index != null)
        for (final item in index[bucket] as List)
          (item as Map)[identity] as String: item,
    };
    final list = rows[bucket] = <Map<String, dynamic>>[];
    for (final key in targets) {
      final entry = mapping.containsKey(key)
          ? _storedLatestScan(mapping[key], hseq, identity)
          : null;
      list.add({
        identity: key,
        'latest_scan': entry,
        'reason': entry == null ? reason : null,
      });
    }
  }
  return RepositoryHistoryScanLatestResult.fromWireFor(request, {
    'profile_id': profileId,
    'revision': revision,
    'history_sequence': hseq,
    'last_scan_at': lastScan,
    'by_kind': byKind,
    'by_student_id': rows['by_student_id'],
    'by_resource_key': rows['by_resource_key'],
    'by_kind_next_after_sequence': next,
  });
}

/// Repository-only Mock query boundary for `repository.history.scan_latest`.
/// Read-only: no migration, observer, clock, cache or map writes.
RepositoryHistoryScanLatestResult repositoryHistoryScanLatest(
  String profileId,
  int revision,
  RepositoryCurrentHistory? history,
  RepositoryHistoryScanLatestRequest request,
) => _scanLatest(profileId, revision, history?._wire, request);

/// The same query over a bare persisted index (`next_sequence`,
/// `last_applied_at.scan`, `latest_scans`), as the backend reads it. Used by the
/// shared metadata policy oracles, which are not full persisted histories.
RepositoryHistoryScanLatestResult repositoryHistoryScanLatestIndex({
  required String profileId,
  required int revision,
  required Map<String, dynamic>? history,
  required RepositoryHistoryScanLatestRequest request,
}) => _scanLatest(
  profileId,
  revision,
  history == null ? null : _copy(history),
  request,
);
