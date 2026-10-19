part of 'repository_history_service.dart';

const historyFilterOmitted = Object();
const _historyQueryReasons = [
  'unrecorded',
  'before_retention',
  'legacy_time_unknown',
  'clock_rollback',
  'scan_not_found',
  'unknown_quantity',
  'unknown_student',
];
const _historyCursorMaxBytes = 8 * 1024 * 1024;

Map<String, dynamic> _queryShape(
  Object? value,
  Set<String> required, [
  Set<String> optional = const {},
]) {
  final d = _map(value, null);
  if (!d.keys.toSet().containsAll(required) ||
      !required.union(optional).containsAll(d.keys)) {
    _bad('Unexpected history query fields');
  }
  return _copy(d);
}

String _queryTime(Object? value) {
  if (value is! String ||
      !RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|\+00:00)$',
      ).hasMatch(value)) {
    _bad('UTC RFC3339 query timestamp expected');
  }
  final date = DateTime.tryParse(value);
  if (date == null || date.year < 1 || date.year > 9999) {
    _bad('Invalid UTC date');
  }
  final normalized = historyUtcTimestamp(date);
  // DateTime.parse normalizes impossible dates; check every calendar component.
  if (normalized.substring(0, 19) != value.substring(0, 19)) {
    _bad('Invalid UTC calendar date');
  }
  return normalized;
}

int _historyIdCompare(String a, String b) {
  final x = a.runes.toList(), y = b.runes.toList();
  for (var i = 0; i < x.length && i < y.length; i++) {
    final result = x[i].compareTo(y[i]);
    if (result != 0) return result;
  }
  return x.length.compareTo(y.length);
}

void _queryTargets(Map<String, dynamic> d) {
  for (final key in ['student_ids', 'resource_keys']) {
    if (!d.containsKey(key)) continue;
    final ids = _list(d[key], (v) => _text(v, raw: true)).cast<String>();
    if (ids.length > 256) _bad('History target filter exceeds 256 IDs');
    d[key] = ids.toList()..sort(_historyIdCompare);
  }
}

void _queryRaw(Map<String, dynamic> d) {
  if (d.containsKey('scan_kind')) _text(d['scan_kind'], raw: true);
  if (d.containsKey('inventory_scan_profile') &&
      d['inventory_scan_profile'] != null) {
    _text(d['inventory_scan_profile'], raw: true);
  }
}

Map<String, dynamic> _eventsRequest(Object? value) {
  final d = _queryShape(
    value,
    {'profile_id'},
    {
      'from_at',
      'to_at',
      'source',
      'scan_kind',
      'inventory_scan_profile',
      'student_ids',
      'resource_keys',
      'cursor',
      'limit',
    },
  );
  _profileId(d['profile_id']);
  _queryRaw(d);
  _queryTargets(d);
  for (final key in ['from_at', 'to_at']) {
    if (d.containsKey(key)) d[key] = _queryTime(d[key]);
  }
  if (d.containsKey('from_at') &&
      d.containsKey('to_at') &&
      (d['from_at'] as String).compareTo(d['to_at'] as String) > 0) {
    _bad('History time interval is reversed');
  }
  if (d.containsKey('source') && !currentHistorySources.contains(d['source'])) {
    _bad('Unknown history source');
  }
  final limit = _int(d.containsKey('limit') ? d['limit'] : 100, 1);
  if (limit > 200) _bad('History limit must be 1..200');
  d['limit'] = limit;
  if (d.containsKey('cursor')) {
    final cursor = _text(d['cursor']);
    if (cursor.length > _historyCursorMaxBytes) _bad('Invalid history cursor');
  }
  return d;
}

Map<String, dynamic> _endpoint(Object? value) {
  final d = _map(value, null);
  if (d.length == 1 && d.containsKey('at')) return {'at': _queryTime(d['at'])};
  if (d.length == 1 && d.containsKey('sequence')) {
    _int(d['sequence']);
    return _copy(d);
  }
  if (d.length == 1 && d['current'] == true) return {'current': true};
  final scan = _queryShape(
    d,
    {'scan'},
    {'scan_kind', 'inventory_scan_profile', 'student_id', 'resource_key'},
  );
  if (!['latest', 'previous'].contains(scan['scan'])) {
    _bad('Invalid scan selector');
  }
  _queryRaw(scan);
  if (scan.containsKey('student_id') && scan.containsKey('resource_key')) {
    _bad('Scan selector may identify only one target');
  }
  for (final key in ['student_id', 'resource_key']) {
    if (scan.containsKey(key)) _text(scan[key], raw: true);
  }
  return scan;
}

Map<String, dynamic> _diffRequest(Object? value) {
  final d = _queryShape(
    value,
    {'profile_id', 'from', 'to'},
    {'student_ids', 'resource_keys'},
  );
  _profileId(d['profile_id']);
  _queryTargets(d);
  d['from'] = _endpoint(d['from']);
  d['to'] = _endpoint(d['to']);
  final a = d['from'] as Map, b = d['to'] as Map;
  for (final key in ['at', 'sequence']) {
    if (a.containsKey(key) &&
        b.containsKey(key) &&
        (key == 'at'
            ? (a[key] as String).compareTo(b[key] as String) > 0
            : (a[key] as int) > (b[key] as int))) {
      _bad('History endpoints are reversed');
    }
  }
  return d;
}

class RepositoryHistoryEndpoint {
  RepositoryHistoryEndpoint.fromWire(Map<String, dynamic> value)
    : _wire = _freeze(_endpoint(value)) as Map<String, dynamic>;
  RepositoryHistoryEndpoint.at(DateTime at)
    : this.fromWire({'at': historyUtcTimestamp(at)});
  RepositoryHistoryEndpoint.sequence(int sequence)
    : this.fromWire({'sequence': sequence});
  RepositoryHistoryEndpoint.current() : this.fromWire({'current': true});
  RepositoryHistoryEndpoint.scan({
    required String position,
    String? scanKind,
    Object? inventoryScanProfile = historyFilterOmitted,
    String? studentId,
    String? resourceKey,
  }) : this.fromWire({
         'scan': position,
         'scan_kind': ?scanKind,
         if (!identical(inventoryScanProfile, historyFilterOmitted))
           'inventory_scan_profile': inventoryScanProfile,
         'student_id': ?studentId,
         'resource_key': ?resourceKey,
       });
  final Map<String, dynamic> _wire;
  Map<String, dynamic> toWire() => _copy(_wire);
}

class RepositoryHistoryEventsRequest {
  RepositoryHistoryEventsRequest.fromWire(Map<String, dynamic> value)
    : _wire = _freeze(_eventsRequest(value)) as Map<String, dynamic>;
  RepositoryHistoryEventsRequest({
    required String profileId,
    DateTime? fromAt,
    DateTime? toAt,
    String? source,
    String? scanKind,
    Object? inventoryScanProfile = historyFilterOmitted,
    List<String>? studentIds,
    List<String>? resourceKeys,
    String? cursor,
    int? limit,
  }) : this.fromWire({
         'profile_id': profileId,
         if (fromAt != null) 'from_at': historyUtcTimestamp(fromAt),
         if (toAt != null) 'to_at': historyUtcTimestamp(toAt),
         'source': ?source,
         'scan_kind': ?scanKind,
         if (!identical(inventoryScanProfile, historyFilterOmitted))
           'inventory_scan_profile': inventoryScanProfile,
         'student_ids': ?studentIds,
         'resource_keys': ?resourceKeys,
         'cursor': ?cursor,
         'limit': ?limit,
       });
  final Map<String, dynamic> _wire;
  String get profileId => _wire['profile_id'] as String;
  String? get cursor => _wire['cursor'] as String?;
  int get limit => _wire['limit'] as int;
  DateTime? get fromAt => _wire['from_at'] == null
      ? null
      : DateTime.parse(_wire['from_at'] as String);
  DateTime? get toAt =>
      _wire['to_at'] == null ? null : DateTime.parse(_wire['to_at'] as String);
  String? get source => _wire['source'] as String?;
  String? get scanKind => _wire['scan_kind'] as String?;
  bool get hasInventoryScanProfile =>
      _wire.containsKey('inventory_scan_profile');
  String? get inventoryScanProfile =>
      _wire['inventory_scan_profile'] as String?;
  List<String>? get studentIds =>
      (_wire['student_ids'] as List?)?.cast<String>();
  List<String>? get resourceKeys =>
      (_wire['resource_keys'] as List?)?.cast<String>();
  RepositoryHistoryEventsRequest withCursor(String cursor) =>
      RepositoryHistoryEventsRequest.fromWire({..._wire, 'cursor': cursor});
  Map<String, dynamic> toWire() => _copy(_wire);
}

class RepositoryHistoryDiffRequest {
  RepositoryHistoryDiffRequest.fromWire(Map<String, dynamic> value)
    : _wire = _freeze(_diffRequest(value)) as Map<String, dynamic>;
  RepositoryHistoryDiffRequest({
    required String profileId,
    required RepositoryHistoryEndpoint from,
    required RepositoryHistoryEndpoint to,
    List<String>? studentIds,
    List<String>? resourceKeys,
  }) : this.fromWire({
         'profile_id': profileId,
         'from': from.toWire(),
         'to': to.toWire(),
         'student_ids': ?studentIds,
         'resource_keys': ?resourceKeys,
       });
  final Map<String, dynamic> _wire;
  String get profileId => _wire['profile_id'] as String;
  RepositoryHistoryEndpoint get from =>
      RepositoryHistoryEndpoint.fromWire(_map(_wire['from'], null));
  RepositoryHistoryEndpoint get to =>
      RepositoryHistoryEndpoint.fromWire(_map(_wire['to'], null));
  List<String>? get studentIds =>
      (_wire['student_ids'] as List?)?.cast<String>();
  List<String>? get resourceKeys =>
      (_wire['resource_keys'] as List?)?.cast<String>();
  Map<String, dynamic> toWire() => _copy(_wire);
}

class RepositoryHistoryQueryCoverage {
  RepositoryHistoryQueryCoverage._(this._wire);
  final Map<String, dynamic> _wire;
  String get origin => _wire['origin'] as String;
  int get baselineSequence => _wire['baseline_sequence'] as int;
  String? get baselineAt => _wire['baseline_at'] as String?;
  String? get firstRetainedAt => _wire['first_retained_at'] as String?;
  bool get complete => _wire['complete'] as bool;
  bool get timestampsMonotonic => _wire['timestamps_monotonic'] as bool;
  List<String> get reasons =>
      List.unmodifiable((_wire['reasons'] as List).cast<String>());
  Map<String, dynamic> toWire() => _copy(_wire);
}

class HistoryScanPoint {
  HistoryScanPoint._(this._wire);
  final Map<String, dynamic> _wire;
  String get sessionId => _wire['session_id'] as String;
  int get sequence => _wire['sequence'] as int;
  String get recordedAt => _wire['recorded_at'] as String;
  String get scanKind => _wire['scan_kind'] as String;
  String? get inventoryScanProfile =>
      _wire['inventory_scan_profile'] as String?;
  Map<String, dynamic> toWire() => _copy(_wire);
}

class HistoryStatePoint {
  HistoryStatePoint._(this._wire);
  final Map<String, dynamic> _wire;
  RepositoryHistoryEndpoint get selector =>
      RepositoryHistoryEndpoint.fromWire(_map(_wire['selector'], null));
  int? get sequence => _wire['sequence'] as int?;
  String? get recordedAt => _wire['recorded_at'] as String?;
  bool get available => _wire['available'] as bool;
  List<ConfirmedStudentState> get students =>
      List.unmodifiable((_wire['students'] as List).map(_student));
  Map<String, String?> get inventory => Map.unmodifiable({
    for (final row in _wire['inventory'] as List)
      row['resource_key'] as String: row['quantity'] as String?,
  });
  Map<String, dynamic> toWire() => _copy(_wire);
}

class HistoryInventoryComparison extends HistoryInventoryChange {
  HistoryInventoryComparison._(super.wire) : super._();
  String? get delta => _wire['delta'] as String?;
}

abstract class RepositoryHistoryQueryResult {
  RepositoryHistoryQueryResult._(Map<String, dynamic> wire)
    : _wire = _freeze(wire) as Map<String, dynamic>;
  final Map<String, dynamic> _wire;
  String get profileId => _wire['profile_id'] as String;
  int get revision => _wire['revision'] as int;
  int get historySequence => _wire['history_sequence'] as int;
  RepositoryHistoryQueryCoverage get coverage =>
      RepositoryHistoryQueryCoverage._(_map(_wire['coverage'], null));
  int get scanCommitCount => _wire['scan_commit_count'] as int;
  int get scanSessionCount => _wire['scan_session_count'] as int;
  bool get trendEligible => _wire['trend_eligible'] as bool;
  List<HistoryScanPoint> get scanPoints => List.unmodifiable(
    (_wire['scan_points'] as List).map(
      (p) => HistoryScanPoint._(_map(p, null)),
    ),
  );
  Map<String, dynamic> toWire() => _copy(_wire);
}

class RepositoryHistoryEventsResult extends RepositoryHistoryQueryResult {
  RepositoryHistoryEventsResult._(super.wire) : super._();
  factory RepositoryHistoryEventsResult.fromWire(Map<String, dynamic> value) =>
      RepositoryHistoryEventsResult._(_eventsResult(value));
  int get matchingEventCount => _wire['matching_event_count'] as int;
  String? get nextCursor => _wire['next_cursor'] as String?;
  List<CurrentHistoryEvent> get events => List.unmodifiable(
    (_wire['events'] as List).map((e) => CurrentHistoryEvent._(_map(e, null))),
  );
}

class RepositoryHistoryDiffResult extends RepositoryHistoryQueryResult {
  RepositoryHistoryDiffResult._(super.wire) : super._();
  factory RepositoryHistoryDiffResult.fromWire(Map<String, dynamic> value) =>
      RepositoryHistoryDiffResult._(_diffResult(value));
  HistoryStatePoint get fromPoint =>
      HistoryStatePoint._(_map(_wire['from_point'], null));
  HistoryStatePoint get toPoint =>
      HistoryStatePoint._(_map(_wire['to_point'], null));
  List<HistoryStudentChange> get studentChanges => List.unmodifiable(
    (_wire['student_changes'] as List).map(
      (r) => HistoryStudentChange._(_map(r, null)),
    ),
  );
  List<HistoryInventoryComparison> get inventoryChanges => List.unmodifiable(
    (_wire['inventory_changes'] as List).map(
      (r) => HistoryInventoryComparison._(_map(r, null)),
    ),
  );
}

const _queryResultKeys = {
  'profile_id',
  'revision',
  'history_sequence',
  'coverage',
  'scan_commit_count',
  'scan_session_count',
  'scan_points',
  'trend_eligible',
};

void _queryResultCommon(Map<String, dynamic> d) {
  _profileId(d['profile_id']);
  _int(d['revision']);
  final anchor = _int(d['history_sequence']);
  final c = _map(d['coverage'], {
    'origin',
    'baseline_sequence',
    'baseline_at',
    'first_retained_at',
    'complete',
    'timestamps_monotonic',
    'reasons',
  });
  final floor = _int(c['baseline_sequence']);
  _time(c['baseline_at'], nullable: true);
  _time(c['first_retained_at'], nullable: true);
  final reasons = _list(c['reasons'], (v) {
    if (!_historyQueryReasons.contains(v)) _bad('Unknown coverage reason');
    return v as String;
  });
  if (!['empty', 'legacy', 'compacted', 'unrecorded'].contains(c['origin']) ||
      floor > anchor ||
      c['complete'] is! bool ||
      c['timestamps_monotonic'] is! bool ||
      c['complete'] != reasons.isEmpty ||
      (c['timestamps_monotonic'] == false) !=
          reasons.contains('clock_rollback') ||
      (floor == 0
          ? c['baseline_at'] != null || c['origin'] == 'compacted'
          : c['baseline_at'] == null || c['origin'] != 'compacted')) {
    _bad('Invalid query coverage');
  }
  var previous = 0;
  final points = _list(d['scan_points'], (raw) {
    final p = _map(raw, {
      'session_id',
      'sequence',
      'recorded_at',
      'scan_kind',
      'inventory_scan_profile',
    });
    final seq = _int(p['sequence'], 1);
    _time(p['recorded_at']);
    _text(p['scan_kind'], raw: true);
    if (p['inventory_scan_profile'] != null) {
      _text(p['inventory_scan_profile'], raw: true);
    }
    if (seq <= previous || seq > anchor || seq <= floor) {
      _bad('Invalid scan point ordering');
    }
    previous = seq;
    return _text(p['session_id'], raw: true);
  });
  if (points.length > currentHistoryMaxEvents ||
      _int(d['scan_session_count']) != points.length ||
      _int(d['scan_commit_count']) > anchor ||
      d['trend_eligible'] is! bool ||
      d['trend_eligible'] != (c['complete'] == true && points.length >= 3)) {
    _bad('Invalid scan counts/trend eligibility');
  }
}

Map<String, dynamic> _eventsResult(Object? value) {
  final d = _map(
    value,
    _queryResultKeys.union({'events', 'matching_event_count', 'next_cursor'}),
  );
  _queryResultCommon(d);
  var previous = (d['coverage'] as Map)['baseline_sequence'] as int;
  final events = _list(d['events'], (v) {
    final e = _validatedHistoryEvent(v);
    final seq = e['sequence'] as int;
    if (seq <= previous || seq > (d['history_sequence'] as int)) {
      _bad('Invalid event page ordering');
    }
    previous = seq;
    return seq;
  });
  final count = _int(d['matching_event_count']);
  if (events.length > 200 ||
      count < events.length ||
      count > (d['history_sequence'] as int) ||
      (d['scan_commit_count'] as int) > count ||
      (d['events'] as List).where((e) => e['source'] == 'scan').length >
          (d['scan_commit_count'] as int)) {
    _bad('Invalid matching/page counts');
  }
  if (d['next_cursor'] != null &&
      (_text(d['next_cursor']).length > _historyCursorMaxBytes ||
          events.isEmpty)) {
    _bad('Invalid next cursor');
  }
  return _copy(d);
}

Map<String, dynamic> _statePoint(Object? value, int anchor) {
  final p = _map(value, {
    'selector',
    'sequence',
    'recorded_at',
    'available',
    'students',
    'inventory',
  });
  _endpoint(p['selector']);
  _time(p['recorded_at'], nullable: true);
  _list(p['students'], (v) => _student(v).studentId);
  _list(p['inventory'], (v) {
    final row = _map(v, {'resource_key', 'quantity'});
    _quantity(row['quantity']);
    return _text(row['resource_key']);
  });
  if (p['available'] is! bool ||
      (p['available'] == true
          ? p['sequence'] == null ||
                _int(p['sequence']) > anchor ||
                (p['sequence'] != 0 && p['recorded_at'] == null)
          : p['sequence'] != null ||
                p['recorded_at'] != null ||
                (p['students'] as List).isNotEmpty ||
                (p['inventory'] as List).isNotEmpty)) {
    _bad('Invalid history state point');
  }
  final selector = p['selector'] as Map;
  if (p['available'] == true &&
      (selector.containsKey('sequence') &&
              p['sequence'] != selector['sequence'] ||
          selector.containsKey('current') && p['sequence'] != anchor)) {
    _bad('Endpoint/sequence mismatch');
  }
  return p;
}

Map<String, dynamic> _presenceValue(Map values, String key, bool quantity) => {
  'present': values.containsKey(key),
  quantity ? 'quantity' : 'value': values[key],
};

Map<String, dynamic> _diffResult(Object? value) {
  final d = _map(
    value,
    _queryResultKeys.union({
      'from_point',
      'to_point',
      'student_changes',
      'inventory_changes',
    }),
  );
  _queryResultCommon(d);
  final a = _statePoint(d['from_point'], d['history_sequence'] as int),
      b = _statePoint(d['to_point'], d['history_sequence'] as int);
  if (a['sequence'] != null &&
      b['sequence'] != null &&
      (a['sequence'] as int) > (b['sequence'] as int)) {
    _bad('Reversed point sequences');
  }
  final reasons = (d['coverage'] as Map)['reasons'] as List;
  final temporal = reasons.every(
    (r) => ['unknown_quantity', 'unknown_student'].contains(r),
  );
  if ((a['available'] == false || b['available'] == false) && temporal) {
    _bad('Unavailable point requires incomplete coverage');
  }
  var unknownQuantity = false, unknownStudent = false;
  for (final row in [
    ('students', 'student_id', 'student_changes', false),
    ('inventory', 'resource_key', 'inventory_changes', true),
  ]) {
    final (bucket, id, field, quantity) = row;
    final x = {
          for (final item in a[bucket] as List)
            item[id] as String: quantity ? item['quantity'] : item,
        },
        y = {
          for (final item in b[bucket] as List)
            item[id] as String: quantity ? item['quantity'] : item,
        };
    final keys = _list(d[field], (raw) {
      final r = _map(raw, {id, 'before', 'after', if (quantity) 'delta'});
      final key = _text(r[id]);
      final before = _presenceValue(x, key, quantity),
          after = _presenceValue(y, key, quantity);
      if (!_same(r['before'], before) || !_same(r['after'], after)) {
        _bad('Comparison does not match point state');
      }
      final known =
          before['present'] == true &&
          after['present'] == true &&
          (!quantity ||
              before['quantity'] != null && after['quantity'] != null);
      if (!known) {
        if (quantity) {
          unknownQuantity = true;
        } else {
          unknownStudent = true;
        }
      }
      if (quantity) {
        final expected = known && temporal
            ? (BigInt.parse(after['quantity'] as String) -
                      BigInt.parse(before['quantity'] as String))
                  .toString()
            : null;
        if (r['delta'] != expected) _bad('Invalid inventory delta');
      }
      return key;
    }).map((r) => _text((r as Map)[id])).toList();
    if (!keys.toSet().containsAll(x.keys.toSet().union(y.keys.toSet()))) {
      _bad('Missing point comparison');
    }
  }
  if (unknownQuantity != reasons.contains('unknown_quantity') ||
      unknownStudent != reasons.contains('unknown_student')) {
    _bad('Unknown value coverage mismatch');
  }
  for (final p in d['scan_points'] as List) {
    if (a['sequence'] == null ||
        b['sequence'] == null ||
        (p['sequence'] as int) <= (a['sequence'] as int) ||
        (p['sequence'] as int) > (b['sequence'] as int)) {
      _bad('Scan point outside diff range');
    }
  }
  return _copy(d);
}

bool _queryScopeMatches(Map scope, Map data) {
  final keys = [
    'student_ids',
    'resource_keys',
  ].where(data.containsKey).toList();
  return keys.isEmpty ||
      keys.any(
        (key) =>
            (scope[key] as List).any((id) => (data[key] as List).contains(id)),
      );
}

bool _queryRawMatches(Map event, Map data) => [
  'scan_kind',
  'inventory_scan_profile',
].every((key) => !data.containsKey(key) || event[key] == data[key]);
bool _queryTimeMatches(Map event, Map data) =>
    (!data.containsKey('from_at') ||
        (event['recorded_at'] as String).compareTo(data['from_at'] as String) >=
            0) &&
    (!data.containsKey('to_at') ||
        (event['recorded_at'] as String).compareTo(data['to_at'] as String) <
            0);
bool _queryMatches(Map event, Map data) =>
    (!data.containsKey('source') || event['source'] == data['source']) &&
    _queryRawMatches(event, data) &&
    _queryTimeMatches(event, data) &&
    _queryScopeMatches(event['applied_scope'] as Map, data);

List<Map<String, dynamic>> _querySessions(List events) {
  final sessions = <String, Map<String, dynamic>>{};
  for (final raw in events) {
    final e = _map(raw, null);
    if (e['source'] != 'scan') continue;
    final id = e['scan_context']['session_id'] as String,
        prior = sessions[e['scan_context']['session_id']];
    sessions[id] = {
      'event': e,
      'scope': {
        for (final key in ['student_ids', 'resource_keys'])
          key: <String>{
            ...(e['applied_scope'][key] as List).cast<String>(),
            ...?((prior?['scope'][key] as List?)?.cast<String>()),
          }.toList()..sort(_historyIdCompare),
      },
    };
  }
  return sessions.values.toList()..sort(
    (a, b) => (a['event']['sequence'] as int).compareTo(
      b['event']['sequence'] as int,
    ),
  );
}

List<Map<String, dynamic>> _queryPointIndex(
  List<Map<String, dynamic>> sessions,
) => [
  for (final item in sessions)
    {
      'session_id': item['event']['scan_context']['session_id'],
      for (final key in [
        'sequence',
        'recorded_at',
        'scan_kind',
        'inventory_scan_profile',
      ])
        key: item['event'][key],
    },
];

Map<String, dynamic> _queryCoverage(
  RepositoryState state,
  RepositoryCurrentHistory? history, {
  int? anchor,
}) {
  final c = _map(
    (history?.summarize(state.profileId, state.revision) ??
            RepositoryHistorySummary.unrecorded(
              state.profileId,
              state.revision,
            ))
        .toWire()['coverage'],
    null,
  );
  if (anchor != null && history != null) {
    final h = history._wire,
        events = (h['events'] as List)
            .where((e) => (e['sequence'] as int) <= anchor)
            .toList();
    final times = <String>[
      if (h['baseline']['recorded_at'] != null)
        h['baseline']['recorded_at'] as String,
      for (final e in events) e['recorded_at'] as String,
    ];
    c['first_retained_at'] = events.isEmpty
        ? null
        : events.first['recorded_at'];
    c['timestamps_monotonic'] = true;
    for (var i = 1; i < times.length; i++) {
      if (times[i - 1].compareTo(times[i]) > 0) {
        c['timestamps_monotonic'] = false;
      }
    }
  }
  c['reasons'] = <String>[];
  return c;
}

void _queryFinishCoverage(Map<String, dynamic> c, Set<String> reasons) {
  c['reasons'] = [
    for (final r in _historyQueryReasons)
      if (reasons.contains(r)) r,
  ];
  c['complete'] = (c['reasons'] as List).isEmpty;
}

Map<String, dynamic> _cursorQuery(Map<String, dynamic> d) => {
  for (final e in d.entries)
    if (!['cursor', 'limit'].contains(e.key)) e.key: e.value,
};
String _encodeHistoryCursor(Map<String, dynamic> d) =>
    base64Url.encode(utf8.encode(historyCanonicalJson(d))).replaceAll('=', '');
Map<String, dynamic> _decodeHistoryCursor(String value) {
  try {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
      _bad('Malformed history cursor');
    }
    final d = _map(
      jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(value)))),
      {
        'version',
        'query',
        'anchor_sequence',
        'baseline_sequence',
        'after_sequence',
      },
    );
    if (d['version'] is! int ||
        d['version'] != 1 ||
        _encodeHistoryCursor(d) != value) {
      _bad('Malformed history cursor');
    }
    final floor = _int(d['baseline_sequence']),
        after = _int(d['after_sequence']),
        anchor = _int(d['anchor_sequence']);
    if (after < floor || after >= anchor) {
      _bad('Invalid cursor sequence bounds');
    }
    return d;
  } on Object {
    _bad('Invalid history cursor');
  }
}

/// Repository-only Mock query boundary. Never samples a clock or writes state.
RepositoryHistoryEventsResult repositoryHistoryEvents(
  RepositoryState state,
  RepositoryCurrentHistory? history,
  RepositoryHistoryEventsRequest request,
) {
  if (request.profileId != state.profileId) {
    _bad('History query profile mismatch');
  }
  final d = request.toWire(), h = history?._wire;
  final total = h == null ? 0 : (h['next_sequence'] as int) - 1,
      floor = h?['baseline']['sequence'] as int? ?? 0;
  var anchor = total, after = floor;
  if (d.containsKey('cursor')) {
    final c = _decodeHistoryCursor(d['cursor'] as String);
    if (!_same(c['query'], _cursorQuery(d))) {
      _bad('Cursor does not match profile/filters');
    }
    anchor = c['anchor_sequence'] as int;
    after = c['after_sequence'] as int;
    if (anchor > total || (c['baseline_sequence'] as int) < floor) {
      throw StateError('history_cursor_expired');
    }
    if (c['baseline_sequence'] != floor) {
      _bad('Cursor baseline does not match history');
    }
  }
  final events = (h?['events'] as List? ?? [])
      .where((e) => (e['sequence'] as int) <= anchor)
      .toList();
  final selected = events.where((e) => _queryMatches(e as Map, d)).toList();
  final page = selected
      .where((e) => (e['sequence'] as int) > after)
      .take(request.limit)
      .toList();
  final cursor =
      page.isNotEmpty &&
          selected.any(
            (e) => (e['sequence'] as int) > (page.last['sequence'] as int),
          )
      ? _encodeHistoryCursor({
          'version': 1,
          'query': _cursorQuery(d),
          'anchor_sequence': anchor,
          'baseline_sequence': floor,
          'after_sequence': page.last['sequence'],
        })
      : null;
  final coverage = _queryCoverage(state, history, anchor: anchor),
      reasons = <String>{};
  if (h == null) {
    reasons.add('unrecorded');
  } else if (h['baseline']['origin'] != 'empty') {
    final lower = d['from_at'] as String?;
    if (h['baseline']['origin'] == 'legacy') {
      if (lower == null ||
          events.isEmpty ||
          lower.compareTo(events.first['recorded_at'] as String) < 0) {
        reasons.add('legacy_time_unknown');
      }
    } else if (lower == null ||
        lower.compareTo(h['baseline']['recorded_at'] as String) <= 0) {
      reasons.add('before_retention');
    }
  }
  if (coverage['timestamps_monotonic'] == false) reasons.add('clock_rollback');
  _queryFinishCoverage(coverage, reasons);
  final sessions = (d['source'] ?? 'scan') == 'scan'
      ? _querySessions(events)
            .where(
              (s) =>
                  _queryRawMatches(s['event'] as Map, d) &&
                  _queryTimeMatches(s['event'] as Map, d) &&
                  _queryScopeMatches(s['scope'] as Map, d),
            )
            .toList()
      : <Map<String, dynamic>>[];
  return RepositoryHistoryEventsResult.fromWire({
    'profile_id': state.profileId,
    'revision': state.revision,
    'history_sequence': anchor,
    'coverage': coverage,
    'events': page,
    'matching_event_count': selected.length,
    'scan_commit_count': selected.where((e) => e['source'] == 'scan').length,
    'scan_session_count': sessions.length,
    'scan_points': _queryPointIndex(sessions),
    'trend_eligible': coverage['complete'] == true && sessions.length >= 3,
    'next_cursor': cursor,
  });
}

(Map<String, dynamic>, String?) _resolveHistoryPoint(
  Map<String, dynamic> selector,
  Map<String, dynamic>? h,
  Map<String, dynamic> current,
  List<Map<String, dynamic>> sessions,
  bool monotonic,
) {
  final total = h == null ? 0 : (h['next_sequence'] as int) - 1,
      baseline = h?['baseline'] as Map?;
  final events = h?['events'] as List? ?? [];
  String? reason;
  int? sequence;
  if (selector.containsKey('current')) {
    return (
      {
        'selector': selector,
        'sequence': total,
        'recorded_at': events.isNotEmpty
            ? events.last['recorded_at']
            : baseline?['recorded_at'],
        'available': true,
        ..._copy(current),
      },
      null,
    );
  }
  if (h == null) {
    reason = 'unrecorded';
  } else if (selector.containsKey('sequence')) {
    sequence = selector['sequence'] as int;
    if (sequence > total) _bad('Sequence is beyond query anchor');
    if (sequence < (baseline!['sequence'] as int)) reason = 'before_retention';
  } else if (selector.containsKey('scan')) {
    final targets = {
      for (final key in ['student_id', 'resource_key'])
        if (selector.containsKey(key)) '${key}s': [selector[key]],
    };
    final matching = sessions
        .where(
          (s) =>
              _queryRawMatches(s['event'] as Map, selector) &&
              _queryScopeMatches(s['scope'] as Map, targets),
        )
        .toList();
    final offset = selector['scan'] == 'latest' ? 1 : 2;
    if (matching.length >= offset) {
      sequence = matching[matching.length - offset]['event']['sequence'] as int;
    } else {
      reason = baseline!['origin'] == 'compacted'
          ? 'before_retention'
          : 'scan_not_found';
    }
  } else {
    final at = selector['at'] as String;
    if (!monotonic) {
      reason = 'clock_rollback';
    } else if (baseline!['origin'] == 'compacted' &&
        at.compareTo(baseline['recorded_at'] as String) <= 0) {
      reason = 'before_retention';
    } else if (baseline['origin'] == 'legacy' &&
        (events.isEmpty ||
            at.compareTo(events.first['recorded_at'] as String) <= 0)) {
      reason = 'legacy_time_unknown';
    } else {
      sequence = baseline['sequence'] as int;
      for (final e in events) {
        if ((e['recorded_at'] as String).compareTo(at) >= 0) break;
        sequence = e['sequence'] as int;
      }
    }
  }
  if (reason != null) {
    return (
      {
        'selector': selector,
        'sequence': null,
        'recorded_at': null,
        'available': false,
        'students': <dynamic>[],
        'inventory': <dynamic>[],
      },
      reason,
    );
  }
  var projection = <String, dynamic>{
    'students': baseline!['students'],
    'inventory': baseline['inventory'],
  };
  var at = baseline['recorded_at'];
  for (final e in events) {
    if ((e['sequence'] as int) > sequence!) break;
    projection = _apply(projection, e as Map);
    at = e['recorded_at'];
  }
  return (
    {
      'selector': selector,
      'sequence': sequence,
      'recorded_at': at,
      'available': true,
      ...projection,
    },
    null,
  );
}

RepositoryHistoryDiffResult repositoryHistoryDiff(
  RepositoryState state,
  RepositoryCurrentHistory? history,
  RepositoryHistoryDiffRequest request,
) {
  if (request.profileId != state.profileId) {
    _bad('History query profile mismatch');
  }
  final d = request.toWire(),
      h = history?._wire,
      coverage = _queryCoverage(state, history);
  final reasons = <String>{
    if (h == null) 'unrecorded',
    if (coverage['timestamps_monotonic'] == false) 'clock_rollback',
  };
  final sessions = _querySessions(h?['events'] as List? ?? []);
  final (a, ar) = _resolveHistoryPoint(
    _map(d['from'], null),
    h,
    _projection(state),
    sessions,
    coverage['timestamps_monotonic'] as bool,
  );
  final (b, br) = _resolveHistoryPoint(
    _map(d['to'], null),
    h,
    _projection(state),
    sessions,
    coverage['timestamps_monotonic'] as bool,
  );
  if (ar != null) reasons.add(ar);
  if (br != null) reasons.add(br);
  if (a['sequence'] != null &&
      b['sequence'] != null &&
      (a['sequence'] as int) > (b['sequence'] as int)) {
    _bad('History endpoints are reversed');
  }
  final temporal = reasons.isEmpty,
      students = <Map<String, dynamic>>[],
      inventory = <Map<String, dynamic>>[];
  for (final row in [
    ('students', 'student_id', 'student_ids', false, students),
    ('inventory', 'resource_key', 'resource_keys', true, inventory),
  ]) {
    final (bucket, id, filter, quantity, rows) = row;
    final x = {
          for (final item in a[bucket] as List)
            item[id] as String: quantity ? item['quantity'] : item,
        },
        y = {
          for (final item in b[bucket] as List)
            item[id] as String: quantity ? item['quantity'] : item,
        };
    final ids =
        d.containsKey(filter)
              ? (d[filter] as List).cast<String>()
              : x.keys.toSet().union(y.keys.toSet()).toList()
          ..sort(_historyIdCompare);
    for (final key in ids) {
      final before = _presenceValue(x, key, quantity),
          after = _presenceValue(y, key, quantity);
      final known =
          before['present'] == true &&
          after['present'] == true &&
          (!quantity ||
              before['quantity'] != null && after['quantity'] != null);
      if (!known) {
        reasons.add(quantity ? 'unknown_quantity' : 'unknown_student');
      }
      rows.add({
        id: key,
        'before': before,
        'after': after,
        if (quantity)
          'delta': known && temporal
              ? (BigInt.parse(after['quantity'] as String) -
                        BigInt.parse(before['quantity'] as String))
                    .toString()
              : null,
      });
    }
  }
  var points = <Map<String, dynamic>>[], rawCount = 0;
  if (a['sequence'] != null && b['sequence'] != null) {
    bool inPeriod(Map e) =>
        (e['sequence'] as int) > (a['sequence'] as int) &&
        (e['sequence'] as int) <= (b['sequence'] as int);
    points = sessions
        .where(
          (s) =>
              inPeriod(s['event'] as Map) &&
              _queryScopeMatches(s['scope'] as Map, d),
        )
        .toList();
    rawCount = (h?['events'] as List? ?? [])
        .where(
          (e) =>
              e['source'] == 'scan' &&
              inPeriod(e as Map) &&
              _queryScopeMatches(e['applied_scope'] as Map, d),
        )
        .length;
  }
  for (final p in [a, b]) {
    for (final row in [
      ('students', 'student_id', 'student_ids'),
      ('inventory', 'resource_key', 'resource_keys'),
    ]) {
      final (bucket, id, filter) = row;
      p[bucket] = (p[bucket] as List)
          .where(
            (item) =>
                !d.containsKey(filter) ||
                (d[filter] as List).contains(item[id]),
          )
          .toList();
    }
  }
  _queryFinishCoverage(coverage, reasons);
  return RepositoryHistoryDiffResult.fromWire({
    'profile_id': state.profileId,
    'revision': state.revision,
    'history_sequence': h == null ? 0 : (h['next_sequence'] as int) - 1,
    'coverage': coverage,
    'from_point': a,
    'to_point': b,
    'student_changes': students,
    'inventory_changes': inventory,
    'scan_commit_count': rawCount,
    'scan_session_count': points.length,
    'scan_points': _queryPointIndex(points),
    'trend_eligible': coverage['complete'] == true && points.length >= 3,
  });
}

void validateRepositoryHistoryCurrent(
  RepositoryCurrentHistory history,
  RepositoryState current,
) {
  final baseline = history._wire['baseline'] as Map;
  var state = <String, dynamic>{
    'students': baseline['students'],
    'inventory': baseline['inventory'],
  };
  for (final event in history._wire['events'] as List) {
    if ((event['revision_after'] as int) > current.revision) {
      _bad('History is ahead of current revision');
    }
    state = _apply(state, event as Map);
  }
  if (!_same(state, _projection(current))) {
    _bad('History does not reconstruct confirmed current');
  }
}

Map<String, dynamic> _validatedHistoryEvent(Object? value) {
  final e = _map(value, {
    'sequence',
    'recorded_at',
    'source',
    'revision_before',
    'revision_after',
    'scan_kind',
    'inventory_scan_profile',
    'scan_context',
    'applied_scope',
    'student_changes',
    'inventory_changes',
    'catalog_revision',
  });
  if (_int(e['sequence'], 1) < 1 ||
      !currentHistorySources.contains(e['source'])) {
    _bad('Invalid application sequence/source');
  }
  _time(e['recorded_at']);
  final source = e['source'] as String;
  if (source == 'import' && e['sequence'] != 1) {
    _bad('Import is the single initial seed');
  }
  final before = _int(e['revision_before']);
  final after = _int(e['revision_after']);
  if ((source == 'import' ? before != 0 || after != 0 : after != before + 1)) {
    _bad('Invalid application revisions');
  }
  final scope = _map(e['applied_scope'], {'student_ids', 'resource_keys'});
  _list(scope['student_ids'], _text);
  _list(scope['resource_keys'], _text);
  if (source == 'scan') {
    _text(e['scan_kind'], raw: true);
    if (e['inventory_scan_profile'] != null) {
      _text(e['inventory_scan_profile'], raw: true);
    }
    final context = _map(e['scan_context'], {
      'session_id',
      'generation',
      'candidate_id',
      'candidate_revision',
    });
    _text(context['session_id'], raw: true);
    _text(context['candidate_id'], raw: true);
    _int(context['generation'], 1);
    _int(context['candidate_revision']);
    if (((scope['student_ids'] as List).isEmpty &&
        (scope['resource_keys'] as List).isEmpty)) {
      _bad('Invalid scan session/scope');
    }
  } else if ([
    'scan_kind',
    'inventory_scan_profile',
    'scan_context',
  ].any((key) => e[key] != null)) {
    _bad('Non-scan metadata');
  }
  final sha = e['catalog_revision'];
  if (sha != null &&
      (sha is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha))) {
    _bad('Invalid catalog revision');
  }
  for (final row in [
    ('student_changes', 'student_id', 'value', 'student_ids'),
    ('inventory_changes', 'resource_key', 'quantity', 'resource_keys'),
  ]) {
    final (changes, id, name, scopeKey) = row;
    _list(e[changes], (raw) {
      final change = _map(raw, {id, 'before', 'after'});
      final identity = _text(change[id]);
      for (final side in ['before', 'after']) {
        final p = _map(change[side], {'present', name});
        if (p['present'] is! bool ||
            (p['present'] == false && p[name] != null)) {
          _bad('Invalid history presence');
        }
        if (name == 'value' &&
            p['present'] == true &&
            _student(p[name]).studentId != identity) {
          _bad('Student diff identity mismatch');
        }
        if (name == 'quantity') _quantity(p[name]);
      }
      if (_same(change['before'], change['after']) ||
          !(scope[scopeKey] as List).contains(identity)) {
        _bad('Invalid diff/scope');
      }
      return identity;
    });
  }
  return e;
}
