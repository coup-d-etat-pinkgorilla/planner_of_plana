import 'package:flutter/foundation.dart';

bool _exact(Map<String, dynamic> value, Set<String> keys) =>
    value.keys.toSet().containsAll(keys) && keys.containsAll(value.keys);

bool _validRecordId(Object? value) =>
    value is String &&
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$').hasMatch(value);

@immutable
class TacticalDeck {
  TacticalDeck({
    required List<String?> strikers,
    required List<String?> specials,
  }) : strikers = List.unmodifiable(strikers),
       specials = List.unmodifiable(specials) {
    if (strikers.length != 4 || specials.length != 2) {
      throw const FormatException(
        'A tactical deck requires 4 striker and 2 special slots',
      );
    }
    final ids = [...strikers, ...specials].whereType<String>().toList();
    if (ids.any((id) => id.isEmpty) || ids.toSet().length != ids.length) {
      throw const FormatException(
        'Tactical deck IDs must be non-empty and unique',
      );
    }
  }

  factory TacticalDeck.empty() => TacticalDeck(
    strikers: List.filled(4, null),
    specials: List.filled(2, null),
  );
  final List<String?> strikers;
  final List<String?> specials;
  bool get isEmpty => [...strikers, ...specials].every((item) => item == null);

  factory TacticalDeck.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {'version', 'strikers', 'specials'}) ||
        value['version'] != 1 ||
        value['strikers'] is! List ||
        value['specials'] is! List) {
      throw const FormatException('Invalid tactical deck');
    }
    String? slot(Object? value) {
      if (value != null && (value is! String || value.isEmpty)) {
        throw const FormatException('Invalid tactical slot');
      }
      return value as String?;
    }

    return TacticalDeck(
      strikers: (value['strikers'] as List).map(slot).toList(),
      specials: (value['specials'] as List).map(slot).toList(),
    );
  }
  Map<String, dynamic> toWire() => {
    'version': 1,
    'strikers': strikers,
    'specials': specials,
  };
}

@immutable
class TacticalMatch {
  const TacticalMatch({
    required this.id,
    required this.kind,
    required this.occurredOn,
    required this.season,
    required this.opponent,
    required this.result,
    required this.attackDeck,
    required this.defenseDeck,
    required this.notes,
  });
  final String id, kind, season, opponent, result, notes;
  final String? occurredOn;
  final TacticalDeck attackDeck, defenseDeck;
  factory TacticalMatch.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'match_id',
      'kind',
      'occurred_on',
      'season',
      'opponent',
      'result',
      'attack_deck',
      'defense_deck',
      'notes',
    };
    if (!_exact(value, fields) ||
        value['version'] != 1 ||
        value['match_id'] is! String ||
        !RegExp(
          r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$',
        ).hasMatch(value['match_id'] as String) ||
        !{'attack', 'defense'}.contains(value['kind']) ||
        (value['occurred_on'] != null && value['occurred_on'] is! String) ||
        !_validDate(value['occurred_on']) ||
        value['season'] is! String ||
        value['opponent'] is! String ||
        (value['opponent'] as String).trim().isEmpty ||
        !{'win', 'loss'}.contains(value['result']) ||
        value['notes'] is! String) {
      throw const FormatException('Invalid tactical match');
    }
    return TacticalMatch(
      id: value['match_id'] as String,
      kind: value['kind'] as String,
      occurredOn: value['occurred_on'] as String?,
      season: value['season'] as String,
      opponent: value['opponent'] as String,
      result: value['result'] as String,
      attackDeck: TacticalDeck.fromWire(
        Map<String, dynamic>.from(value['attack_deck'] as Map),
      ),
      defenseDeck: TacticalDeck.fromWire(
        Map<String, dynamic>.from(value['defense_deck'] as Map),
      ),
      notes: value['notes'] as String,
    );
  }
  Map<String, dynamic> toWire() => {
    'version': 1,
    'match_id': id,
    'kind': kind,
    'occurred_on': occurredOn,
    'season': season.trim(),
    'opponent': opponent.trim(),
    'result': result,
    'attack_deck': attackDeck.toWire(),
    'defense_deck': defenseDeck.toWire(),
    'notes': notes.trim(),
  };
  TacticalMatch copyWith({String? id}) => TacticalMatch(
    id: id ?? this.id,
    kind: kind,
    occurredOn: occurredOn,
    season: season,
    opponent: opponent,
    result: result,
    attackDeck: attackDeck,
    defenseDeck: defenseDeck,
    notes: notes,
  );
}

@immutable
class TacticalJokbo {
  const TacticalJokbo({
    required this.id,
    required this.defenseDeck,
    required this.attackDeck,
    required this.notes,
  });
  final String id, notes;
  final TacticalDeck defenseDeck, attackDeck;
  factory TacticalJokbo.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {
          'version',
          'jokbo_id',
          'defense_deck',
          'attack_deck',
          'notes',
        }) ||
        value['version'] != 1 ||
        value['jokbo_id'] is! String ||
        !RegExp(
          r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$',
        ).hasMatch(value['jokbo_id'] as String) ||
        value['notes'] is! String) {
      throw const FormatException('Invalid tactical jokbo');
    }
    return TacticalJokbo(
      id: value['jokbo_id'] as String,
      defenseDeck: TacticalDeck.fromWire(
        Map<String, dynamic>.from(value['defense_deck'] as Map),
      ),
      attackDeck: TacticalDeck.fromWire(
        Map<String, dynamic>.from(value['attack_deck'] as Map),
      ),
      notes: value['notes'] as String,
    );
  }
  Map<String, dynamic> toWire() => {
    'version': 1,
    'jokbo_id': id,
    'defense_deck': defenseDeck.toWire(),
    'attack_deck': attackDeck.toWire(),
    'notes': notes.trim(),
  };
}

bool _validDate(Object? value) {
  if (value == null) return true;
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return false;
  }
  final parsed = DateTime.tryParse(value);
  return parsed != null && parsed.toIso8601String().startsWith(value);
}

@immutable
class TacticalState {
  const TacticalState({
    required this.profileId,
    required this.revision,
    required this.matches,
    required this.jokbo,
  });
  final String profileId;
  final int revision;
  final List<TacticalMatch> matches;
  final List<TacticalJokbo> jokbo;
  factory TacticalState.fromWire(Map<String, dynamic> value) {
    if (!_exact(value, {
          'version',
          'profile_id',
          'revision',
          'matches',
          'jokbo',
        }) ||
        value['version'] != 1 ||
        value['profile_id'] is! String ||
        !RegExp(r'^[0-9a-f]{24}$').hasMatch(value['profile_id'] as String) ||
        value['revision'] is! int ||
        (value['revision'] as int) < 0 ||
        value['matches'] is! List ||
        value['jokbo'] is! List) {
      throw const FormatException('Invalid tactical state');
    }
    return TacticalState(
      profileId: value['profile_id'] as String,
      revision: value['revision'] as int,
      matches: List.unmodifiable(
        (value['matches'] as List).map(
          (item) =>
              TacticalMatch.fromWire(Map<String, dynamic>.from(item as Map)),
        ),
      ),
      jokbo: List.unmodifiable(
        (value['jokbo'] as List).map(
          (item) =>
              TacticalJokbo.fromWire(Map<String, dynamic>.from(item as Map)),
        ),
      ),
    );
  }
}

abstract interface class TacticalService {
  Future<TacticalState> loadTacticalState(String profileId);
  Future<int> saveTacticalMatch(
    String profileId,
    TacticalMatch match,
    int expectedRevision,
    String idempotencyKey,
  );
  Future<int> deleteTacticalMatch(
    String profileId,
    String matchId,
    int expectedRevision,
    String idempotencyKey,
  );
  Future<int> saveTacticalJokbo(
    String profileId,
    TacticalJokbo jokbo,
    int expectedRevision,
    String idempotencyKey,
  );
  Future<int> deleteTacticalJokbo(
    String profileId,
    String jokboId,
    int expectedRevision,
    String idempotencyKey,
  );
}

/// Strict fixture-side validation mirroring the tactical v1 schema.
bool isValidTacticalProtocolMessage(Object? input) {
  try {
    if (input is! Map) return false;
    final value = Map<String, dynamic>.from(input);
    if (!_exact(value, {'protocol', 'id', 'type', 'method', 'payload'}) ||
        value['protocol'] != 1 ||
        value['id'] is! String ||
        (value['id'] as String).isEmpty ||
        !{'request', 'response'}.contains(value['type']) ||
        value['method'] is! String ||
        value['payload'] is! Map) {
      return false;
    }
    final method = value['method'] as String,
        payload = Map<String, dynamic>.from(value['payload'] as Map);
    bool profile(Object? id) =>
        id is String && RegExp(r'^[0-9a-f]{24}$').hasMatch(id);
    bool mutation(Set<String> extra) =>
        _exact(payload, {
          'profile_id',
          'expected_revision',
          'idempotency_key',
          ...extra,
        }) &&
        profile(payload['profile_id']) &&
        payload['expected_revision'] is int &&
        (payload['expected_revision'] as int) >= 0 &&
        payload['idempotency_key'] is String &&
        (payload['idempotency_key'] as String).isNotEmpty;
    if (value['type'] == 'request') {
      if (method == 'tactical.state.get') {
        return _exact(payload, {'profile_id'}) &&
            profile(payload['profile_id']);
      }
      if (method == 'tactical.match.upsert') {
        if (!mutation({'match'})) return false;
        TacticalMatch.fromWire(
          Map<String, dynamic>.from(payload['match'] as Map),
        );
        return true;
      }
      if (method == 'tactical.match.delete') {
        return mutation({'match_id'}) && _validRecordId(payload['match_id']);
      }
      if (method == 'tactical.jokbo.upsert') {
        if (!mutation({'jokbo'})) return false;
        TacticalJokbo.fromWire(
          Map<String, dynamic>.from(payload['jokbo'] as Map),
        );
        return true;
      }
      if (method == 'tactical.jokbo.delete') {
        return mutation({'jokbo_id'}) && _validRecordId(payload['jokbo_id']);
      }
      return false;
    }
    if (payload.containsKey('error')) {
      if (!_exact(payload, {'error'}) || payload['error'] is! Map) {
        return false;
      }
      final error = Map<String, dynamic>.from(payload['error'] as Map);
      const required = {'code', 'message', 'retryable'};
      const allowed = {...required, 'details'};
      return error.keys.toSet().containsAll(required) &&
          allowed.containsAll(error.keys) &&
          error['code'] is String &&
          (error['code'] as String).isNotEmpty &&
          error['message'] is String &&
          error['retryable'] is bool &&
          (!error.containsKey('details') || error['details'] is Map);
    }
    if (method == 'tactical.state.get') {
      TacticalState.fromWire(payload);
      return true;
    }
    return _exact(payload, {'revision'}) &&
        payload['revision'] is int &&
        (payload['revision'] as int) > 0;
  } catch (_) {
    return false;
  }
}
