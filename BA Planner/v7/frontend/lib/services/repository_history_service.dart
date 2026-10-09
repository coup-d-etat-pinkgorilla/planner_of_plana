import 'dart:convert';

import 'repository_service.dart' show ConfirmedStudentState, RepositoryState;

const currentHistorySources = ['scan', 'manual', 'import', 'unattributed'];
const currentHistoryMaxEvents = 10000;
const currentHistoryMaxBytes = 16 * 1024 * 1024;

Never _bad(String reason) => throw FormatException(reason);
Map<String, dynamic> _map(Object? value, Set<String>? keys) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    _bad('History object expected');
  }
  final result = Map<String, dynamic>.from(value);
  if (keys != null &&
      (result.length != keys.length ||
          !result.keys.toSet().containsAll(keys))) {
    _bad('Unexpected history fields');
  }
  return result;
}

int _int(Object? value, [int minimum = 0]) {
  if (value is! int || value < minimum) _bad('Invalid history integer');
  return value;
}

String _text(Object? value, {bool raw = false}) {
  if (value is! String ||
      value.isEmpty ||
      (raw && utf8.encode(value).length > 1024)) {
    _bad('Invalid history text');
  }
  return value;
}

String? _time(Object? value, {bool nullable = false}) {
  if (value == null && nullable) return null;
  if (value is! String ||
      !RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$',
      ).hasMatch(value)) {
    _bad('UTC history timestamp expected');
  }
  final date = DateTime.tryParse(value);
  if (date == null || historyUtcTimestamp(date) != value) {
    _bad('Invalid UTC date');
  }
  return value;
}

String historyUtcTimestamp(DateTime value) {
  final utc = value.toUtc();
  final result = utc.toIso8601String();
  return utc.microsecond == 0 ? result.replaceFirst('Z', '000Z') : result;
}

List<dynamic> _list(Object? value, Object Function(dynamic) identity) {
  if (value is! List) _bad('History array expected');
  final keys = value.map(identity).toList();
  if (keys.toSet().length != keys.length) _bad('Duplicate history identity');
  return value;
}

Object? _sorted(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _sorted(value[key])};
  }
  if (value is List) return value.map(_sorted).toList();
  return value;
}

String historyCanonicalJson(Object? value) => jsonEncode(_sorted(value));
Map<String, dynamic> _copy(Map value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.map((key, item) => MapEntry(key as String, _freeze(item))),
    );
  }
  if (value is List) return List.unmodifiable(value.map(_freeze));
  return value;
}

bool _same(Object? a, Object? b) =>
    historyCanonicalJson(a) == historyCanonicalJson(b);
ConfirmedStudentState _student(Object? value) {
  final wire = _map(value, null);
  final student = ConfirmedStudentState.fromWire(wire);
  if (wire['version'] is! int || !_same(wire, student.toWire())) {
    _bad('History students must use canonical confirmed records');
  }
  return student;
}

void _quantity(Object? value) {
  if (value != null &&
      (value is! String || !RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(value))) {
    _bad('Invalid history quantity');
  }
}

class HistoryPresence<T> {
  const HistoryPresence(this.present, this.value);
  final bool present;
  final T? value;
}

class HistoryStudentChange {
  HistoryStudentChange._(Map<String, dynamic> wire)
    : _wire = _freeze(wire) as Map<String, dynamic>;
  final Map<String, dynamic> _wire;
  String get studentId => _wire['student_id'] as String;
  HistoryPresence<ConfirmedStudentState> _side(String side) {
    final p = _wire[side] as Map;
    return HistoryPresence(
      p['present'] as bool,
      p['present'] == true
          ? ConfirmedStudentState.fromWire(_map(p['value'], null))
          : null,
    );
  }

  HistoryPresence<ConfirmedStudentState> get before => _side('before');
  HistoryPresence<ConfirmedStudentState> get after => _side('after');
  Map<String, dynamic> toWire() => _copy(_wire);
}

class HistoryInventoryChange {
  HistoryInventoryChange._(Map<String, dynamic> wire)
    : _wire = _freeze(wire) as Map<String, dynamic>;
  final Map<String, dynamic> _wire;
  String get resourceKey => _wire['resource_key'] as String;
  HistoryPresence<String> _side(String side) {
    final p = _wire[side] as Map;
    return HistoryPresence(p['present'] as bool, p['quantity'] as String?);
  }

  HistoryPresence<String> get before => _side('before');
  HistoryPresence<String> get after => _side('after');
  Map<String, dynamic> toWire() => _copy(_wire);
}

class CurrentHistoryEvent {
  CurrentHistoryEvent._(Map<String, dynamic> wire)
    : _wire = _freeze(wire) as Map<String, dynamic>;
  final Map<String, dynamic> _wire;
  int get sequence => _wire['sequence'] as int;
  String get recordedAt => _wire['recorded_at'] as String;
  String get source => _wire['source'] as String;
  String? get scanKind => _wire['scan_kind'] as String?;
  String? get inventoryScanProfile =>
      _wire['inventory_scan_profile'] as String?;
  List<HistoryStudentChange> get studentChanges => List.unmodifiable(
    (_wire['student_changes'] as List).map(
      (item) => HistoryStudentChange._(_map(item, null)),
    ),
  );
  List<HistoryInventoryChange> get inventoryChanges => List.unmodifiable(
    (_wire['inventory_changes'] as List).map(
      (item) => HistoryInventoryChange._(_map(item, null)),
    ),
  );
  Map<String, dynamic> toWire() => _copy(_wire);
}

Map<String, dynamic> _projection(RepositoryState state) => {
  'students': (state.students.map((item) => item.toWire()).toList()
    ..sort(
      (a, b) =>
          (a['student_id'] as String).compareTo(b['student_id'] as String),
    )),
  'inventory':
      (state.inventory.entries
          .map(
            (item) => <String, dynamic>{
              'resource_key': item['item_id'] ?? item['key'],
              'quantity': item['quantity'],
            },
          )
          .toList()
        ..sort(
          (a, b) => (a['resource_key'] as String).compareTo(
            b['resource_key'] as String,
          ),
        )),
};

Map<String, dynamic> _apply(Map state, Map event) {
  final result = <String, dynamic>{};
  for (final row in [
    ('students', 'student_id', 'student_changes', 'value'),
    ('inventory', 'resource_key', 'inventory_changes', 'quantity'),
  ]) {
    final (bucket, id, changes, value) = row;
    final items = {
      for (final item in state[bucket] as List)
        item[id] as String: value == 'quantity' ? item['quantity'] : item,
    };
    for (final change in event[changes] as List) {
      final key = change[id] as String;
      if (!_same(change['before'], {
        'present': items.containsKey(key),
        value: items[key],
      })) {
        _bad('History before does not match current');
      }
      final after = change['after'] as Map;
      if (after['present'] == true) {
        items[key] = after[value];
      } else {
        items.remove(key);
      }
    }
    final keys = items.keys.toList()..sort();
    result[bucket] = [
      for (final key in keys)
        value == 'quantity'
            ? {'resource_key': key, 'quantity': items[key]}
            : items[key],
    ];
  }
  return result;
}

class RepositoryCurrentHistory {
  RepositoryCurrentHistory._(Map<String, dynamic> wire)
    : _wire = _freeze(wire) as Map<String, dynamic>;
  final Map<String, dynamic> _wire;
  int get nextSequence => _wire['next_sequence'] as int;
  List<CurrentHistoryEvent> get events => List.unmodifiable(
    (_wire['events'] as List).map(
      (item) => CurrentHistoryEvent._(_map(item, null)),
    ),
  );
  Map<String, dynamic> toWire() => _copy(_wire);

  factory RepositoryCurrentHistory.fromWire(Map<String, dynamic> value) {
    final data = _map(value, {
      'version',
      'next_sequence',
      'baseline',
      'events',
      'total_counts',
      'last_applied_at',
      'scan_session_ids',
      'latest_scans',
    });
    if (data['version'] is! int || data['version'] != 1) {
      _bad('Unsupported history version');
    }
    final total = _int(data['next_sequence'], 1) - 1;
    final baseline = _map(data['baseline'], {
      'sequence',
      'recorded_at',
      'origin',
      'students',
      'inventory',
    });
    final floor = _int(baseline['sequence']);
    _time(baseline['recorded_at'], nullable: true);
    if (!['empty', 'legacy', 'compacted'].contains(baseline['origin']) ||
        floor > total ||
        (floor == 0 &&
            (baseline['origin'] == 'compacted' ||
                baseline['recorded_at'] != null)) ||
        (floor > 0 &&
            (baseline['origin'] != 'compacted' ||
                baseline['recorded_at'] == null))) {
      _bad('Invalid baseline');
    }
    _list(baseline['students'], (item) => _student(item).studentId);
    _list(baseline['inventory'], (raw) {
      final item = _map(raw, {'resource_key', 'quantity'});
      _quantity(item['quantity']);
      return _text(item['resource_key']);
    });
    if (baseline['origin'] == 'empty' &&
        ((baseline['students'] as List).isNotEmpty ||
            (baseline['inventory'] as List).isNotEmpty)) {
      _bad('Empty baseline must be empty');
    }
    final counts = _map(data['total_counts'], currentHistorySources.toSet());
    if (counts.values.map(_int).fold(0, (a, b) => a + b) != total ||
        (counts['import'] as int) > 1) {
      _bad('History counts mismatch');
    }
    final last = _map(data['last_applied_at'], currentHistorySources.toSet());
    for (final source in currentHistorySources) {
      _time(last[source], nullable: true);
      if ((last[source] == null) != (counts[source] == 0)) {
        _bad('Last application/count mismatch');
      }
    }
    final sessions = _list(
      data['scan_session_ids'],
      (item) => _text(item, raw: true),
    );
    if (sessions.length > (counts['scan'] as int) ||
        sessions.isEmpty != (counts['scan'] == 0)) {
      _bad('Session/commit mismatch');
    }
    final rawEvents = data['events'];
    if (rawEvents is! List ||
        rawEvents.length > currentHistoryMaxEvents ||
        rawEvents.length != total - floor) {
      _bad('Invalid retained events');
    }
    var state = <String, dynamic>{
      'students': baseline['students'],
      'inventory': baseline['inventory'],
    };
    final retained = {for (final source in currentHistorySources) source: 0};
    final retainedLast = <String, String>{};
    var previousRevision = -1;
    for (var i = 0; i < rawEvents.length; i++) {
      final e = _map(rawEvents[i], {
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
      if (_int(e['sequence'], 1) != floor + i + 1 ||
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
      if (before < previousRevision ||
          (source == 'import'
              ? before != 0 || after != 0
              : after != before + 1)) {
        _bad('Invalid application revisions');
      }
      previousRevision = after;
      retained[source] = retained[source]! + 1;
      retainedLast[source] = e['recorded_at'] as String;
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
        if (!sessions.contains(context['session_id']) ||
            ((scope['student_ids'] as List).isEmpty &&
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
      state = _apply(state, e);
    }
    for (final source in currentHistorySources) {
      if (retained[source]! > (counts[source] as int) ||
          (retainedLast.containsKey(source) &&
              retainedLast[source] != last[source])) {
        _bad('Retained counts/time mismatch');
      }
    }
    final index = _map(data['latest_scans'], {
      'by_kind',
      'by_student_id',
      'by_resource_key',
    });
    for (final row in [
      ('by_kind', null),
      ('by_student_id', 'student_id'),
      ('by_resource_key', 'resource_key'),
    ]) {
      final (bucket, id) = row;
      _list(index[bucket], (raw) {
        final item = _map(raw, {
          'sequence',
          'recorded_at',
          'session_id',
          'scan_kind',
          'inventory_scan_profile',
          ?id,
        });
        if (_int(item['sequence'], 1) > total || counts['scan'] == 0) {
          _bad('Invalid latest scan sequence');
        }
        _time(item['recorded_at']);
        _text(item['scan_kind'], raw: true);
        if (item['inventory_scan_profile'] != null) {
          _text(item['inventory_scan_profile'], raw: true);
        }
        if (!sessions.contains(_text(item['session_id'], raw: true))) {
          _bad('Unknown latest scan session');
        }
        return id == null
            ? historyCanonicalJson([
                item['scan_kind'],
                item['inventory_scan_profile'],
              ])
            : _text(item[id]);
      });
    }
    if ((index['by_kind'] as List).isNotEmpty != (counts['scan'] != 0)) {
      _bad('Missing latest scan index');
    }
    final expectedIndex = {
      'by_kind': <String, dynamic>{},
      'by_student_id': <String, dynamic>{},
      'by_resource_key': <String, dynamic>{},
    };
    for (final event in rawEvents) {
      if (event['source'] != 'scan') continue;
      final entry = <String, dynamic>{
        for (final key in [
          'sequence',
          'recorded_at',
          'scan_kind',
          'inventory_scan_profile',
        ])
          key: event[key],
        'session_id': event['scan_context']['session_id'],
      };
      expectedIndex['by_kind']![historyCanonicalJson([
            entry['scan_kind'],
            entry['inventory_scan_profile'],
          ])] =
          entry;
      for (final row in [
        ('by_student_id', 'student_id', 'student_ids'),
        ('by_resource_key', 'resource_key', 'resource_keys'),
      ]) {
        final (bucket, identity, scope) = row;
        for (final key in event['applied_scope'][scope] as List) {
          expectedIndex[bucket]![key as String] = {identity: key, ...entry};
        }
      }
    }
    for (final row in [
      ('by_kind', null),
      ('by_student_id', 'student_id'),
      ('by_resource_key', 'resource_key'),
    ]) {
      final (bucket, identity) = row;
      final persisted = {
        for (final item in index[bucket] as List)
          identity == null
                  ? historyCanonicalJson([
                      item['scan_kind'],
                      item['inventory_scan_profile'],
                    ])
                  : item[identity] as String:
              item,
      };
      for (final entry in expectedIndex[bucket]!.entries) {
        if (!_same(persisted[entry.key], entry.value)) {
          _bad('Latest scan index does not match retained applications');
        }
      }
    }
    if (utf8.encode(historyCanonicalJson(data)).length >
        currentHistoryMaxBytes) {
      _bad('History capacity exceeded');
    }
    return RepositoryCurrentHistory._(_copy(data));
  }

  factory RepositoryCurrentHistory.empty({RepositoryState? legacy}) =>
      RepositoryCurrentHistory.fromWire({
        'version': 1,
        'next_sequence': 1,
        'baseline': {
          'sequence': 0,
          'recorded_at': null,
          'origin': legacy == null ? 'empty' : 'legacy',
          ...?legacy == null ? null : _projection(legacy),
          if (legacy == null) 'students': <dynamic>[],
          if (legacy == null) 'inventory': <dynamic>[],
        },
        'events': <dynamic>[],
        'total_counts': {for (final source in currentHistorySources) source: 0},
        'last_applied_at': {
          for (final source in currentHistorySources) source: null,
        },
        'scan_session_ids': <dynamic>[],
        'latest_scans': {
          'by_kind': <dynamic>[],
          'by_student_id': <dynamic>[],
          'by_resource_key': <dynamic>[],
        },
      });

  /// Mock manual writes use the same wire policy; scanner wiring belongs to FB-2b.
  RepositoryCurrentHistory appendManual(
    RepositoryState before,
    RepositoryState after,
    String bucket,
    DateTime now, {
    String source = 'manual',
  }) {
    if ((source != 'manual' && source != 'unattributed') ||
        !['students', 'inventory', 'current'].contains(bucket)) {
      _bad('This compatibility helper cannot claim scan or import');
    }
    final result = toWire();
    final a = _projection(before), b = _projection(after);
    final diffs = <String, dynamic>{};
    for (final row in [
      ('students', 'student_id', 'value', 'student_changes'),
      ('inventory', 'resource_key', 'quantity', 'inventory_changes'),
    ]) {
      final (key, id, name, changes) = row;
      final aa = {
        for (final item in a[key] as List)
          item[id]: name == 'quantity' ? item['quantity'] : item,
      };
      final bb = {
        for (final item in b[key] as List)
          item[id]: name == 'quantity' ? item['quantity'] : item,
      };
      final keys = {...aa.keys, ...bb.keys}.cast<String>().toList()..sort();
      diffs[changes] = [
        for (final identity in keys)
          if (!_same(
            {'present': aa.containsKey(identity), name: aa[identity]},
            {'present': bb.containsKey(identity), name: bb[identity]},
          ))
            {
              id: identity,
              'before': {
                'present': aa.containsKey(identity),
                name: aa[identity],
              },
              'after': {
                'present': bb.containsKey(identity),
                name: bb[identity],
              },
            },
      ];
    }
    final at = historyUtcTimestamp(now);
    final event = {
      'sequence': nextSequence,
      'recorded_at': at,
      'source': source,
      'revision_before': before.revision,
      'revision_after': after.revision,
      'scan_kind': null,
      'inventory_scan_profile': null,
      'scan_context': null,
      'catalog_revision': after.inventory.catalogRevision,
      'applied_scope': {
        'student_ids': bucket != 'inventory'
            ? ({
                for (final item in [...a['students'], ...b['students']])
                  item['student_id'],
              }.cast<String>().toList()..sort())
            : <String>[],
        'resource_keys': bucket != 'students'
            ? ({
                for (final item in [...a['inventory'], ...b['inventory']])
                  item['resource_key'],
              }.cast<String>().toList()..sort())
            : <String>[],
      },
      ...diffs,
    };
    final events = result['events'] as List;
    events.add(event);
    result['next_sequence'] = nextSequence + 1;
    result['total_counts'][source]++;
    result['last_applied_at'][source] = at;
    void fold() {
      final removed = events.removeAt(0) as Map;
      final baseline = result['baseline'] as Map;
      final projection = _apply({
        'students': baseline['students'],
        'inventory': baseline['inventory'],
      }, removed);
      result['baseline'] = {
        'sequence': removed['sequence'],
        'recorded_at': removed['recorded_at'],
        'origin': 'compacted',
        ...projection,
      };
    }

    final cutoff = now.toUtc().subtract(const Duration(days: 365));
    while (events.length > 1 &&
        (events.length > currentHistoryMaxEvents ||
            DateTime.parse(
              events.first['recorded_at'] as String,
            ).isBefore(cutoff))) {
      fold();
    }
    while (utf8.encode(historyCanonicalJson(result)).length >
        currentHistoryMaxBytes) {
      if (events.length <= 1) _bad('history_capacity_exceeded');
      fold();
    }
    return RepositoryCurrentHistory.fromWire(result);
  }

  RepositoryHistorySummary summarize(String profileId, int revision) =>
      _summarize(profileId, revision, _wire);
}

class RepositoryHistoryCoverage {
  RepositoryHistoryCoverage._(this._wire);
  final Map<String, dynamic> _wire;
  String get origin => _wire['origin'] as String;
  int get baselineSequence => _wire['baseline_sequence'] as int;
  bool get complete => _wire['complete'] as bool;
  bool get timestampsMonotonic => _wire['timestamps_monotonic'] as bool;
  String? get baselineAt => _wire['baseline_at'] as String?;
  String? get firstRetainedAt => _wire['first_retained_at'] as String?;
}

class RepositoryHistorySummary {
  RepositoryHistorySummary._(Map<String, dynamic> wire)
    : _wire = _freeze(wire) as Map<String, dynamic>;
  final Map<String, dynamic> _wire;
  String get profileId => _wire['profile_id'] as String;
  int get revision => _wire['revision'] as int;
  int get historySequence => _wire['history_sequence'] as int;
  String? get lastManualAt => _wire['last_manual_at'] as String?;
  String? get lastImportAt => _wire['last_import_at'] as String?;
  int get totalEventCount => _wire['total_event_count'] as int;
  int get retainedEventCount => _wire['retained_event_count'] as int;
  int get totalScanSessionCount => _wire['total_scan_session_count'] as int;
  int get retainedScanSessionCount =>
      _wire['retained_scan_session_count'] as int;
  Map<String, int> get totalCounts =>
      Map.unmodifiable(Map<String, int>.from(_wire['total_counts'] as Map));
  Map<String, int> get retainedCounts =>
      Map.unmodifiable(Map<String, int>.from(_wire['retained_counts'] as Map));
  RepositoryHistoryCoverage get coverage =>
      RepositoryHistoryCoverage._(_map(_wire['coverage'], null));
  Map<String, dynamic> toWire() => _copy(_wire);

  factory RepositoryHistorySummary.fromWire(Map<String, dynamic> value) {
    final d = _map(value, {
      'profile_id',
      'revision',
      'history_sequence',
      'last_manual_at',
      'last_import_at',
      'total_event_count',
      'retained_event_count',
      'total_counts',
      'retained_counts',
      'total_scan_session_count',
      'retained_scan_session_count',
      'coverage',
    });
    _profileId(d['profile_id']);
    _int(d['revision']);
    _time(d['last_manual_at'], nullable: true);
    _time(d['last_import_at'], nullable: true);
    final total = _int(d['total_event_count']),
        retained = _int(d['retained_event_count']);
    final counts = _map(d['total_counts'], currentHistorySources.toSet()),
        recent = _map(d['retained_counts'], currentHistorySources.toSet());
    if (_int(d['history_sequence']) != total ||
        retained > total ||
        counts.values.map(_int).fold(0, (a, b) => a + b) != total ||
        recent.values.map(_int).fold(0, (a, b) => a + b) != retained) {
      _bad('Summary count mismatch');
    }
    for (final source in currentHistorySources) {
      if (_int(recent[source]) > _int(counts[source])) {
        _bad('Summary retained count exceeds total');
      }
    }
    for (final source in ['manual', 'import']) {
      if ((d['last_${source}_at'] == null) != (counts[source] == 0)) {
        _bad('Summary last application mismatch');
      }
    }
    if (_int(d['total_scan_session_count']) > _int(counts['scan']) ||
        _int(d['retained_scan_session_count']) > _int(recent['scan']) ||
        _int(d['retained_scan_session_count']) >
            _int(d['total_scan_session_count']) ||
        (d['total_scan_session_count'] == 0) != (counts['scan'] == 0) ||
        (d['retained_scan_session_count'] == 0) != (recent['scan'] == 0)) {
      _bad('Summary session count mismatch');
    }
    final coverage = _map(d['coverage'], {
      'origin',
      'baseline_sequence',
      'baseline_at',
      'first_retained_at',
      'complete',
      'timestamps_monotonic',
    });
    _time(coverage['baseline_at'], nullable: true);
    _time(coverage['first_retained_at'], nullable: true);
    if (![
          'empty',
          'legacy',
          'compacted',
          'unrecorded',
        ].contains(coverage['origin']) ||
        _int(coverage['baseline_sequence']) != total - retained ||
        coverage['complete'] is! bool ||
        coverage['timestamps_monotonic'] is! bool ||
        coverage['complete'] != (coverage['origin'] == 'empty')) {
      _bad('Invalid history coverage');
    }
    return RepositoryHistorySummary._(_copy(d));
  }
  factory RepositoryHistorySummary.unrecorded(String profileId, int revision) =>
      _summarize(profileId, revision, null);
}

String _profileId(Object? value) {
  final id = _text(value);
  if (!RegExp(r'^[0-9a-f]{24}$').hasMatch(id)) {
    _bad('Invalid history profile ID');
  }
  return id;
}

class RepositoryHistorySummaryRequest {
  RepositoryHistorySummaryRequest(List<String> profileIds)
    : this.fromWire({'profile_ids': profileIds});
  RepositoryHistorySummaryRequest.fromWire(Map<String, dynamic> value)
    : profileIds = _ids(value);
  final List<String> profileIds;
  static List<String> _ids(Map<String, dynamic> value) {
    final data = _map(value, {'profile_ids'});
    final ids = _list(data['profile_ids'], _profileId).cast<String>();
    if (ids.isEmpty || ids.length > 128) _bad('Expected 1..128 profile IDs');
    return List.unmodifiable(ids);
  }

  Map<String, dynamic> toWire() => {'profile_ids': profileIds.toList()};
}

class RepositoryHistorySummaryResult {
  RepositoryHistorySummaryResult._(this.profiles);
  final List<RepositoryHistorySummary> profiles;
  factory RepositoryHistorySummaryResult.fromWire(Map<String, dynamic> value) {
    final data = _map(value, {'profiles'});
    final raw = _list(
      data['profiles'],
      (item) => RepositoryHistorySummary.fromWire(_map(item, null)).profileId,
    );
    if (raw.isEmpty || raw.length > 128) {
      _bad('Expected 1..128 history summaries');
    }
    return RepositoryHistorySummaryResult._(
      List.unmodifiable(
        raw.map((item) => RepositoryHistorySummary.fromWire(_map(item, null))),
      ),
    );
  }
  Map<String, dynamic> toWire() => {
    'profiles': profiles.map((item) => item.toWire()).toList(),
  };
}

RepositoryHistorySummary _summarize(
  String id,
  int revision,
  Map<String, dynamic>? history,
) {
  final counts =
      history?['total_counts'] as Map? ??
      {for (final source in currentHistorySources) source: 0};
  final events = history?['events'] as List? ?? const [];
  final retained = {
    for (final source in currentHistorySources)
      source: events.where((e) => e['source'] == source).length,
  };
  final baseline = history?['baseline'] as Map?;
  final times = <String>[
    if (baseline?['recorded_at'] != null) baseline!['recorded_at'] as String,
    for (final event in events) event['recorded_at'] as String,
  ];
  var monotonic = true;
  for (var i = 1; i < times.length; i++) {
    if (times[i - 1].compareTo(times[i]) > 0) {
      monotonic = false;
    }
  }
  return RepositoryHistorySummary.fromWire({
    'profile_id': id,
    'revision': revision,
    'history_sequence': history == null
        ? 0
        : (history['next_sequence'] as int) - 1,
    'last_manual_at': history?['last_applied_at']['manual'],
    'last_import_at': history?['last_applied_at']['import'],
    'total_event_count': counts.values.cast<int>().fold(0, (a, b) => a + b),
    'retained_event_count': events.length,
    'total_counts': counts,
    'retained_counts': retained,
    'total_scan_session_count':
        (history?['scan_session_ids'] as List?)?.length ?? 0,
    'retained_scan_session_count': events
        .where((e) => e['source'] == 'scan')
        .map((e) => e['scan_context']['session_id'])
        .toSet()
        .length,
    'coverage': {
      'origin': baseline?['origin'] ?? 'unrecorded',
      'baseline_sequence': baseline?['sequence'] ?? 0,
      'baseline_at': baseline?['recorded_at'],
      'first_retained_at': events.isEmpty ? null : events.first['recorded_at'],
      'complete': baseline?['origin'] == 'empty',
      'timestamps_monotonic': monotonic,
    },
  });
}
