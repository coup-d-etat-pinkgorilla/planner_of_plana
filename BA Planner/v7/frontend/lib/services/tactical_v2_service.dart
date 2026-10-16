import 'dart:convert';

import 'package:flutter/foundation.dart';

bool _exactV2(Map<String, dynamic> value, Set<String> keys) =>
    value.keys.toSet().containsAll(keys) && keys.containsAll(value.keys);

bool _recordIdV2(Object? value) =>
    value is String &&
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$').stringMatch(value) == value;

String? _timestampV2(Object? value, {bool nullable = true}) {
  if (value == null && nullable) return null;
  if (value is! String ||
      !value.contains('T') ||
      !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(value) ||
      DateTime.tryParse(value) == null) {
    throw const FormatException('Invalid tactical v2 timestamp');
  }
  return value;
}

const _slotStatesV2 = {
  'unknown',
  'empty',
  'visible_lobby',
  'revealed_after_battle',
  'manual',
  'community_reported',
};
const _sourcesV2 = {
  'v6_import',
  'manual',
  'lobby_scan',
  'battle_result',
  'community_report',
  'prediction',
};

bool _validRecommendationFiltersV2(Object? raw) {
  if (raw is! Map) return false;
  final filters = Map<String, dynamic>.from(raw);
  const fields = {
    'season',
    'opponent_identity_id',
    'public_signature',
    'rank_difference',
    'as_of',
    'half_life_hours',
    'min_target_samples',
    'top_k',
    'owned_student_ids',
  };
  final rank = filters['rank_difference'];
  final owned = filters['owned_student_ids'];
  try {
    return _exactV2(filters, fields) &&
        filters['season'] is String &&
        (filters['season'] as String).isNotEmpty &&
        _recordIdV2(filters['opponent_identity_id']) &&
        filters['public_signature'] is String &&
        (filters['public_signature'] as String).isNotEmpty &&
        (rank == null || rank is int && rank >= -100000 && rank <= 100000) &&
        _timestampV2(filters['as_of'], nullable: false) != null &&
        filters['half_life_hours'] is int &&
        filters['half_life_hours'] >= 1 &&
        filters['half_life_hours'] <= 8760 &&
        filters['min_target_samples'] is int &&
        filters['min_target_samples'] >= 1 &&
        filters['min_target_samples'] <= 20 &&
        filters['top_k'] is int &&
        filters['top_k'] >= 1 &&
        filters['top_k'] <= 10 &&
        owned is List &&
        owned.every((item) => item is String && item.isNotEmpty) &&
        owned.toSet().length == owned.length;
  } catch (_) {
    return false;
  }
}

bool _validSharePayloadV1(Object? raw) {
  if (raw is! Map) return false;
  try {
    TacticalSharePayload.fromWire(Map<String, dynamic>.from(raw));
    return true;
  } catch (_) {
    return false;
  }
}

bool _validShareFiltersV1(Object? raw) {
  if (raw is! Map) return false;
  final value = Map<String, dynamic>.from(raw);
  const fields = {
    'scope_id',
    'season',
    'patch',
    'map',
    'public_signature',
    'defense_signature',
    'rank_difference_min',
    'rank_difference_max',
    'as_of',
    'min_independent_contributors',
    'min_independent_opponents',
    'limit',
  };
  try {
    final min = value['rank_difference_min'];
    final max = value['rank_difference_max'];
    return _exactV2(value, fields) &&
        _recordIdV2(value['scope_id']) &&
        [
          'season',
          'patch',
          'map',
          'public_signature',
          'defense_signature',
        ].every((key) => value[key] == null || value[key] is String) &&
        (min == null || min is int) &&
        (max == null || max is int) &&
        (min == null || max == null || min <= max) &&
        _timestampV2(value['as_of'], nullable: false) != null &&
        value['min_independent_contributors'] is int &&
        value['min_independent_contributors'] >= 1 &&
        value['min_independent_contributors'] <= 100 &&
        value['min_independent_opponents'] is int &&
        value['min_independent_opponents'] >= 1 &&
        value['min_independent_opponents'] <= 100 &&
        value['limit'] is int &&
        value['limit'] >= 1 &&
        value['limit'] <= 100;
  } catch (_) {
    return false;
  }
}

const _reviewStatusesV2 = {
  'unreviewed',
  'review_required',
  'confirmed',
  'rejected',
};

const _occurredPrecisionsV2 = {'date', 'instant', 'unknown'};

bool _sha256V2(Object? value) =>
    value is String && RegExp(r'^[0-9a-f]{64}$').stringMatch(value) == value;

@immutable
class TacticalSlotObservation {
  const TacticalSlotObservation({
    required this.position,
    required this.studentId,
    required this.state,
    required this.source,
    required this.confidence,
    required this.reviewStatus,
    required this.wildcard,
  });

  final int position;
  final String? studentId;
  final String state;
  final String source;
  final double? confidence;
  final String reviewStatus;
  final bool wildcard;

  factory TacticalSlotObservation.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'position',
      'student_id',
      'state',
      'source',
      'confidence',
      'review_status',
      'wildcard',
    };
    final position = value['position'];
    final studentId = value['student_id'];
    final state = value['state'];
    final source = value['source'];
    final confidence = value['confidence'];
    final reviewStatus = value['review_status'];
    final wildcard = value['wildcard'];
    if (!_exactV2(value, fields) ||
        value['version'] != 2 ||
        position is! int ||
        position < 0 ||
        position > 3 ||
        (studentId != null && (studentId is! String || studentId.isEmpty)) ||
        !_slotStatesV2.contains(state) ||
        !_sourcesV2.contains(source) ||
        (confidence != null &&
            (confidence is! num || confidence < 0 || confidence > 1)) ||
        !_reviewStatusesV2.contains(reviewStatus) ||
        wildcard is! bool) {
      throw const FormatException('Invalid tactical slot observation');
    }
    final observed = !{'unknown', 'empty'}.contains(state);
    if ((wildcard && (studentId != null || state != 'unknown')) ||
        (!wildcard && observed && studentId == null) ||
        (!wildcard && !observed && studentId != null)) {
      throw const FormatException('Inconsistent tactical slot observation');
    }
    return TacticalSlotObservation(
      position: position,
      studentId: studentId as String?,
      state: state as String,
      source: source as String,
      confidence: (confidence as num?)?.toDouble(),
      reviewStatus: reviewStatus as String,
      wildcard: wildcard,
    );
  }

  Map<String, dynamic> toWire() => {
    'version': 2,
    'position': position,
    'student_id': studentId,
    'state': state,
    'source': source,
    'confidence': confidence,
    'review_status': reviewStatus,
    'wildcard': wildcard,
  };
}

@immutable
class TacticalDeckV2 {
  TacticalDeckV2({
    required List<TacticalSlotObservation> strikers,
    required List<TacticalSlotObservation> specials,
  }) : strikers = List.unmodifiable(strikers),
       specials = List.unmodifiable(specials) {
    if (strikers.length != 4 ||
        specials.length != 2 ||
        !listEquals(strikers.map((item) => item.position).toList(), const [
          0,
          1,
          2,
          3,
        ]) ||
        !listEquals(specials.map((item) => item.position).toList(), const [
          0,
          1,
        ])) {
      throw const FormatException('Invalid tactical v2 slot positions');
    }
    final ids = [
      ...strikers,
      ...specials,
    ].map((item) => item.studentId).whereType<String>().toList();
    if (ids.length != ids.toSet().length) {
      throw const FormatException('Duplicate tactical v2 student');
    }
  }
  final List<TacticalSlotObservation> strikers;
  final List<TacticalSlotObservation> specials;

  factory TacticalDeckV2.fromWire(Map<String, dynamic> value) {
    if (!_exactV2(value, {'version', 'strikers', 'specials'}) ||
        value['version'] != 2 ||
        value['strikers'] is! List ||
        value['specials'] is! List) {
      throw const FormatException('Invalid tactical v2 deck');
    }
    TacticalSlotObservation slot(Object? item) =>
        TacticalSlotObservation.fromWire(
          Map<String, dynamic>.from(item as Map),
        );
    return TacticalDeckV2(
      strikers: (value['strikers'] as List).map(slot).toList(),
      specials: (value['specials'] as List).map(slot).toList(),
    );
  }
  Map<String, dynamic> toWire() => {
    'version': 2,
    'strikers': strikers.map((item) => item.toWire()).toList(growable: false),
    'specials': specials.map((item) => item.toWire()).toList(growable: false),
  };
}

void _provenanceV2(Map<String, dynamic> value) {
  if (!_sourcesV2.contains(value['source']) ||
      value['source_label'] is! String ||
      !_recordIdV2(value['import_batch_id']) ||
      value['source_record_id'] is! String ||
      (value['source_record_id'] as String).isEmpty ||
      (value['confidence'] != null &&
          (value['confidence'] is! num ||
              value['confidence'] < 0 ||
              value['confidence'] > 1)) ||
      !_reviewStatusesV2.contains(value['review_status'])) {
    throw const FormatException('Invalid tactical v2 provenance');
  }
}

/// FD-176 상대 쌍: identity(record ID)와 이름(빈 문자열 아님)이 둘 다 있거나, 방어 기록에 한해 둘 다 null이다.
/// 한쪽만 null·빈 문자열·공격 기록의 null은 거부한다(schema `match`·`fb6MatchInput` allOf).
bool _validOpponentPairV2(Map<String, dynamic> value) {
  final id = value['opponent_identity_id'];
  final name = value['opponent_display_name'];
  if (id == null && name == null) return value['kind'] == 'defense';
  return _recordIdV2(id) && name is String && name.isNotEmpty;
}

@immutable
class TacticalMatchV2 {
  const TacticalMatchV2({
    required this.id,
    required this.kind,
    required this.occurredAt,
    required this.observedAt,
    required this.importedAt,
    required this.createdAt,
    required this.source,
    required this.sourceLabel,
    required this.importBatchId,
    required this.sourceRecordId,
    required this.confidence,
    required this.reviewStatus,
    required this.season,
    required this.opponentIdentityId,
    required this.opponentDisplayName,
    required this.result,
    required this.attackDeck,
    required this.defenseDeck,
    required this.notes,
    this.attemptCount,
    this.occurredPrecision = 'unknown',
  });
  final String id, kind, importedAt, createdAt, source, sourceLabel;
  final String importBatchId, sourceRecordId, reviewStatus, season;
  final String result, notes;

  /// FD-176: 방어 기록은 상대를 모르면 identity·이름이 둘 다 null이다(공격 기록은 늘 둘 다 있다). 가짜 상대로 바꾸지 않는다.
  final String? opponentIdentityId, opponentDisplayName;
  final String? occurredAt, observedAt;
  final double? confidence;
  final TacticalDeckV2 attackDeck, defenseDeck;

  /// FB-6 시도 횟수. null = 모름(구 v2 기록·v7-v1 이관 기록·FD-176 '모름' 저장). 1로 채우지 않는다.
  final int? attemptCount;

  /// FB-6 `date`·`instant`·`unknown`. 구 v2 기록에 키가 없으면 `unknown`이다. `date`의 `occurredAt`은
  /// KST 자정 표기일 뿐 전투 시각이 아니다.
  final String occurredPrecision;

  factory TacticalMatchV2.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'match_id',
      'kind',
      'occurred_at',
      'observed_at',
      'imported_at',
      'created_at',
      'source',
      'source_label',
      'import_batch_id',
      'source_record_id',
      'confidence',
      'review_status',
      'season',
      'opponent_identity_id',
      'opponent_display_name',
      'result',
      'attack_deck',
      'defense_deck',
      'notes',
    };
    // FB-6 additive optional 키. 그 밖의 모르는 키는 지금처럼 거부한다.
    const optional = {'attempt_count', 'occurred_precision'};
    final attempt = value['attempt_count'];
    if (!value.keys.toSet().containsAll(fields) ||
        !{...fields, ...optional}.containsAll(value.keys) ||
        (attempt != null && (attempt is! int || attempt < 1)) ||
        (value.containsKey('occurred_precision') &&
            !_occurredPrecisionsV2.contains(value['occurred_precision'])) ||
        value['version'] != 2 ||
        !_recordIdV2(value['match_id']) ||
        !{'attack', 'defense'}.contains(value['kind']) ||
        value['season'] is! String ||
        !_validOpponentPairV2(value) ||
        !{'win', 'loss'}.contains(value['result']) ||
        value['notes'] is! String) {
      throw const FormatException('Invalid tactical v2 match');
    }
    _provenanceV2(value);
    return TacticalMatchV2(
      id: value['match_id'] as String,
      kind: value['kind'] as String,
      occurredAt: _timestampV2(value['occurred_at']),
      observedAt: _timestampV2(value['observed_at']),
      importedAt: _timestampV2(value['imported_at'], nullable: false)!,
      createdAt: _timestampV2(value['created_at'], nullable: false)!,
      source: value['source'] as String,
      sourceLabel: value['source_label'] as String,
      importBatchId: value['import_batch_id'] as String,
      sourceRecordId: value['source_record_id'] as String,
      confidence: (value['confidence'] as num?)?.toDouble(),
      reviewStatus: value['review_status'] as String,
      season: value['season'] as String,
      opponentIdentityId: value['opponent_identity_id'] as String?,
      opponentDisplayName: value['opponent_display_name'] as String?,
      result: value['result'] as String,
      attackDeck: TacticalDeckV2.fromWire(
        Map<String, dynamic>.from(value['attack_deck'] as Map),
      ),
      defenseDeck: TacticalDeckV2.fromWire(
        Map<String, dynamic>.from(value['defense_deck'] as Map),
      ),
      notes: value['notes'] as String,
      attemptCount: attempt as int?,
      occurredPrecision: value['occurred_precision'] as String? ?? 'unknown',
    );
  }
}

@immutable
class TacticalJokboV2 {
  const TacticalJokboV2({
    required this.id,
    required this.defenseDeck,
    required this.attackDeck,
    this.name,
    required this.wins,
    required this.losses,
    required this.notes,
    required this.createdAt,
    required this.importedAt,
    required this.source,
    required this.sourceLabel,
    required this.importBatchId,
    required this.sourceRecordId,
    required this.confidence,
    required this.reviewStatus,
  });
  final String id;
  final TacticalDeckV2 defenseDeck, attackDeck;

  /// FB-6 족보 이름(자동 이름 또는 사용자 편집). 구 v2 기록에는 없을 수 있다(null).
  final String? name;

  /// FE9-b1: schema `jokbo.wins`·`losses`. 가져온 족보(v6)의 집계 값이며 v2 기록에서 다시 세지 않는다
  /// (자동 도출 `lineage-` 족보는 0). 기록 기준 승패는 화면 쪽에서 기록을 따로 센다.
  final int wins, losses;

  /// FE9-b1: schema `jokbo.notes`. 족보를 고쳐 저장할 때 입력 6키의 `notes`로 그대로 되보낸다.
  final String notes;

  /// FE9-b1: schema `jokbo`의 출처 필드(백엔드 소유 — 쓰기 입력에 넣지 않는다).
  final String createdAt, importedAt, source, sourceLabel;
  final String importBatchId, sourceRecordId, reviewStatus;
  final double? confidence;
  factory TacticalJokboV2.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'jokbo_id',
      'defense_deck',
      'attack_deck',
      'wins',
      'losses',
      'notes',
      'created_at',
      'imported_at',
      'source',
      'source_label',
      'import_batch_id',
      'source_record_id',
      'confidence',
      'review_status',
    };
    final name = value['name'];
    // FB-6 additive optional `name`. 그 밖의 모르는 키는 지금처럼 거부한다.
    if (!value.keys.toSet().containsAll(fields) ||
        !{...fields, 'name'}.containsAll(value.keys) ||
        (value.containsKey('name') && (name is! String || name.isEmpty)) ||
        value['version'] != 2 ||
        !_recordIdV2(value['jokbo_id']) ||
        value['wins'] is! int ||
        value['wins'] < 0 ||
        value['losses'] is! int ||
        value['losses'] < 0 ||
        value['notes'] is! String) {
      throw const FormatException('Invalid tactical v2 jokbo');
    }
    _provenanceV2(value);
    return TacticalJokboV2(
      id: value['jokbo_id'] as String,
      defenseDeck: TacticalDeckV2.fromWire(
        Map<String, dynamic>.from(value['defense_deck'] as Map),
      ),
      attackDeck: TacticalDeckV2.fromWire(
        Map<String, dynamic>.from(value['attack_deck'] as Map),
      ),
      name: name as String?,
      wins: value['wins'] as int,
      losses: value['losses'] as int,
      notes: value['notes'] as String,
      createdAt: _timestampV2(value['created_at'], nullable: false)!,
      importedAt: _timestampV2(value['imported_at'], nullable: false)!,
      source: value['source'] as String,
      sourceLabel: value['source_label'] as String,
      importBatchId: value['import_batch_id'] as String,
      sourceRecordId: value['source_record_id'] as String,
      confidence: (value['confidence'] as num?)?.toDouble(),
      reviewStatus: value['review_status'] as String,
    );
  }
}

@immutable
class TacticalOpponentIdentity {
  const TacticalOpponentIdentity({
    required this.id,
    required this.currentDisplayName,
    required this.aliases,
    required this.nameTemplateIds,
    required this.firstObservedAt,
    required this.lastObservedAt,
    required this.reviewStatus,
  });
  final String id, currentDisplayName;
  final List<String> aliases;
  final List<String> nameTemplateIds;

  /// FE9-b1: schema `opponent.first_observed_at`·`last_observed_at`(timestamp | null — 모르면 null).
  final String? firstObservedAt, lastObservedAt;
  final String reviewStatus;
  factory TacticalOpponentIdentity.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'identity_id',
      'current_display_name',
      'aliases',
      'first_observed_at',
      'last_observed_at',
      'review_status',
      'name_template_ids',
    };
    final aliases = value['aliases'];
    final templates = value['name_template_ids'];
    if (!_exactV2(value, fields) ||
        value['version'] != 2 ||
        !_recordIdV2(value['identity_id']) ||
        value['current_display_name'] is! String ||
        (value['current_display_name'] as String).isEmpty ||
        aliases is! List ||
        aliases.isEmpty ||
        aliases.any((item) => item is! String || item.isEmpty) ||
        aliases.toSet().length != aliases.length ||
        templates is! List ||
        templates.any((item) => !_recordIdV2(item)) ||
        templates.toSet().length != templates.length ||
        !_reviewStatusesV2.contains(value['review_status'])) {
      throw const FormatException('Invalid tactical opponent identity');
    }
    return TacticalOpponentIdentity(
      id: value['identity_id'] as String,
      currentDisplayName: value['current_display_name'] as String,
      aliases: List.unmodifiable(aliases.cast<String>()),
      nameTemplateIds: List.unmodifiable(templates.cast<String>()),
      firstObservedAt: _timestampV2(value['first_observed_at']),
      lastObservedAt: _timestampV2(value['last_observed_at']),
      reviewStatus: value['review_status'] as String,
    );
  }
}

@immutable
class TacticalDefenseSnapshot {
  const TacticalDefenseSnapshot({
    required this.id,
    required this.opponentIdentityId,
    required this.deck,
    required this.matchId,
    required this.occurredAt,
    required this.observedAt,
    required this.importedAt,
    required this.source,
    required this.season,
    required this.reviewStatus,
  });
  final String id, opponentIdentityId;
  final String? matchId;
  final TacticalDeckV2 deck;

  /// FE9-b1: schema `snapshot.occurred_at`·`observed_at`(timestamp | null), `imported_at`(필수).
  final String? occurredAt, observedAt;
  final String importedAt, source, season, reviewStatus;
  factory TacticalDefenseSnapshot.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'snapshot_id',
      'opponent_identity_id',
      'occurred_at',
      'observed_at',
      'imported_at',
      'source',
      'source_record_id',
      'confidence',
      'review_status',
      'season',
      'deck',
      'match_id',
    };
    if (!_exactV2(value, fields) ||
        value['version'] != 2 ||
        !_recordIdV2(value['snapshot_id']) ||
        !_recordIdV2(value['opponent_identity_id']) ||
        (value['match_id'] != null && !_recordIdV2(value['match_id'])) ||
        !_sourcesV2.contains(value['source']) ||
        value['source_record_id'] is! String ||
        (value['source_record_id'] as String).isEmpty ||
        value['season'] is! String ||
        !_reviewStatusesV2.contains(value['review_status']) ||
        (value['confidence'] != null &&
            (value['confidence'] is! num ||
                value['confidence'] < 0 ||
                value['confidence'] > 1))) {
      throw const FormatException('Invalid tactical defense snapshot');
    }
    return TacticalDefenseSnapshot(
      id: value['snapshot_id'] as String,
      opponentIdentityId: value['opponent_identity_id'] as String,
      deck: TacticalDeckV2.fromWire(
        Map<String, dynamic>.from(value['deck'] as Map),
      ),
      matchId: value['match_id'] as String?,
      occurredAt: _timestampV2(value['occurred_at']),
      observedAt: _timestampV2(value['observed_at']),
      importedAt: _timestampV2(value['imported_at'], nullable: false)!,
      source: value['source'] as String,
      season: value['season'] as String,
      reviewStatus: value['review_status'] as String,
    );
  }
}

@immutable
class TacticalLobbyScan {
  const TacticalLobbyScan({
    required this.id,
    required this.observedAt,
    required this.season,
    required this.map,
    required this.currentRank,
    required this.refreshGeneration,
    required this.confidence,
  });
  final String id, observedAt, season, map, refreshGeneration;
  final int currentRank;
  final double confidence;

  factory TacticalLobbyScan.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'scan_id',
      'observed_at',
      'season',
      'map',
      'current_rank',
      'refresh_generation',
      'screen_hash',
      'roi_profile_id',
      'confidence',
      'review_status',
    };
    if (!_exactV2(value, fields) ||
        value['version'] != 2 ||
        !_recordIdV2(value['scan_id']) ||
        value['season'] is! String ||
        value['map'] is! String ||
        value['current_rank'] is! int ||
        value['current_rank'] < 1 ||
        value['refresh_generation'] is! String ||
        !RegExp(
          r'^refresh-[0-9a-f]{24}$',
        ).hasMatch(value['refresh_generation']) ||
        value['screen_hash'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(value['screen_hash']) ||
        value['roi_profile_id'] is! String ||
        value['confidence'] is! num ||
        value['confidence'] < 0 ||
        value['confidence'] > 1 ||
        !_reviewStatusesV2.contains(value['review_status'])) {
      throw const FormatException('Invalid tactical lobby scan');
    }
    _timestampV2(value['observed_at'], nullable: false);
    return TacticalLobbyScan(
      id: value['scan_id'] as String,
      observedAt: value['observed_at'] as String,
      season: value['season'] as String,
      map: value['map'] as String,
      currentRank: value['current_rank'] as int,
      refreshGeneration: value['refresh_generation'] as String,
      confidence: (value['confidence'] as num).toDouble(),
    );
  }
}

@immutable
class TacticalLobbyCandidateRecord {
  const TacticalLobbyCandidateRecord({
    required this.id,
    required this.scanId,
    required this.displayIndex,
    required this.opponentIdentityId,
    required this.opponentRank,
    required this.publicSignature,
    required this.selectedAt,
    required this.matchId,
    required this.linkStatus,
    required this.snapshotId,
  });
  final String id,
      scanId,
      opponentIdentityId,
      publicSignature,
      linkStatus,
      snapshotId;
  final int displayIndex, opponentRank;
  final String? selectedAt, matchId;

  factory TacticalLobbyCandidateRecord.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'candidate_id',
      'scan_id',
      'display_index',
      'opponent_identity_id',
      'opponent_rank',
      'public_signature',
      'confidence',
      'review_status',
      'selected_at',
      'match_id',
      'link_status',
      'snapshot_id',
    };
    if (!_exactV2(value, fields) ||
        value['version'] != 2 ||
        !_recordIdV2(value['candidate_id']) ||
        !_recordIdV2(value['scan_id']) ||
        !_recordIdV2(value['opponent_identity_id']) ||
        !_recordIdV2(value['snapshot_id']) ||
        value['display_index'] is! int ||
        value['display_index'] < 0 ||
        value['display_index'] > 2 ||
        value['opponent_rank'] is! int ||
        value['opponent_rank'] < 1 ||
        value['public_signature'] is! String ||
        (value['public_signature'] as String).isEmpty ||
        value['confidence'] is! num ||
        value['confidence'] < 0 ||
        value['confidence'] > 1 ||
        !_reviewStatusesV2.contains(value['review_status']) ||
        (value['match_id'] != null && !_recordIdV2(value['match_id'])) ||
        !{
          'unlinked',
          'automatic',
          'manual',
          'review_required',
        }.contains(value['link_status'])) {
      throw const FormatException('Invalid tactical lobby candidate');
    }
    _timestampV2(value['selected_at']);
    return TacticalLobbyCandidateRecord(
      id: value['candidate_id'] as String,
      scanId: value['scan_id'] as String,
      displayIndex: value['display_index'] as int,
      opponentIdentityId: value['opponent_identity_id'] as String,
      opponentRank: value['opponent_rank'] as int,
      publicSignature: value['public_signature'] as String,
      selectedAt: value['selected_at'] as String?,
      matchId: value['match_id'] as String?,
      linkStatus: value['link_status'] as String,
      snapshotId: value['snapshot_id'] as String,
    );
  }
}

@immutable
class TacticalImportBatch {
  const TacticalImportBatch({
    required this.id,
    required this.sourceFingerprint,
  });
  final String id, sourceFingerprint;
  factory TacticalImportBatch.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'import_batch_id',
      'source_fingerprint',
      'imported_at',
      'match_count',
      'jokbo_count',
      'skipped_issue_count',
    };
    if (!_exactV2(value, fields) ||
        value['version'] != 2 ||
        !_recordIdV2(value['import_batch_id']) ||
        value['source_fingerprint'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(value['source_fingerprint']) ||
        [
          value['match_count'],
          value['jokbo_count'],
          value['skipped_issue_count'],
        ].any((item) => item is! int || item < 0)) {
      throw const FormatException('Invalid tactical import batch');
    }
    _timestampV2(value['imported_at'], nullable: false);
    return TacticalImportBatch(
      id: value['import_batch_id'] as String,
      sourceFingerprint: value['source_fingerprint'] as String,
    );
  }
}

@immutable
class TacticalEvidenceState {
  const TacticalEvidenceState({
    required this.profileId,
    required this.revision,
    required this.matches,
    required this.jokbo,
    required this.opponents,
    required this.snapshots,
    required this.lobbyScans,
    required this.lobbyCandidates,
    required this.predictions,
    required this.importBatches,
  });
  final String profileId;
  final int revision;
  final List<TacticalMatchV2> matches;
  final List<TacticalJokboV2> jokbo;
  final List<TacticalOpponentIdentity> opponents;
  final List<TacticalDefenseSnapshot> snapshots;
  final List<TacticalLobbyScan> lobbyScans;
  final List<TacticalLobbyCandidateRecord> lobbyCandidates;
  final List<TacticalSavedPrediction> predictions;
  final List<TacticalImportBatch> importBatches;
  factory TacticalEvidenceState.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'profile_id',
      'revision',
      'matches',
      'jokbo',
      'opponents',
      'snapshots',
      'lobby_scans',
      'lobby_candidates',
      'predictions',
      'import_batches',
    };
    if (!_exactV2(value, fields) ||
        value['version'] != 2 ||
        value['profile_id'] is! String ||
        !RegExp(r'^[0-9a-f]{24}$').hasMatch(value['profile_id']) ||
        value['revision'] is! int ||
        value['revision'] < 0 ||
        [
          value['matches'],
          value['jokbo'],
          value['opponents'],
          value['snapshots'],
          value['lobby_scans'],
          value['lobby_candidates'],
          value['predictions'],
          value['import_batches'],
        ].any((item) => item is! List)) {
      throw const FormatException('Invalid tactical evidence state');
    }
    T parse<T>(Object? item, T Function(Map<String, dynamic>) parser) =>
        parser(Map<String, dynamic>.from(item as Map));
    return TacticalEvidenceState(
      profileId: value['profile_id'] as String,
      revision: value['revision'] as int,
      matches: List.unmodifiable(
        (value['matches'] as List).map(
          (item) => parse(item, TacticalMatchV2.fromWire),
        ),
      ),
      jokbo: List.unmodifiable(
        (value['jokbo'] as List).map(
          (item) => parse(item, TacticalJokboV2.fromWire),
        ),
      ),
      opponents: List.unmodifiable(
        (value['opponents'] as List).map(
          (item) => parse(item, TacticalOpponentIdentity.fromWire),
        ),
      ),
      snapshots: List.unmodifiable(
        (value['snapshots'] as List).map(
          (item) => parse(item, TacticalDefenseSnapshot.fromWire),
        ),
      ),
      lobbyScans: List.unmodifiable(
        (value['lobby_scans'] as List).map(
          (item) => parse(item, TacticalLobbyScan.fromWire),
        ),
      ),
      lobbyCandidates: List.unmodifiable(
        (value['lobby_candidates'] as List).map(
          (item) => parse(item, TacticalLobbyCandidateRecord.fromWire),
        ),
      ),
      predictions: List.unmodifiable(
        (value['predictions'] as List).map(
          (item) => parse(item, TacticalSavedPrediction.fromWire),
        ),
      ),
      importBatches: List.unmodifiable(
        (value['import_batches'] as List).map(
          (item) => parse(item, TacticalImportBatch.fromWire),
        ),
      ),
    );
  }
}

@immutable
class TacticalImportIssue {
  const TacticalImportIssue({
    required this.id,
    required this.sourceRecordId,
    required this.code,
    required this.message,
  });
  final String id, sourceRecordId, code, message;
  factory TacticalImportIssue.fromWire(Map<String, dynamic> value) {
    if (!_exactV2(value, {'issue_id', 'source_record_id', 'code', 'message'}) ||
        !_recordIdV2(value['issue_id']) ||
        [
          value['source_record_id'],
          value['code'],
          value['message'],
        ].any((item) => item is! String || item.isEmpty)) {
      throw const FormatException('Invalid tactical import issue');
    }
    return TacticalImportIssue(
      id: value['issue_id'] as String,
      sourceRecordId: value['source_record_id'] as String,
      code: value['code'] as String,
      message: value['message'] as String,
    );
  }
}

@immutable
class TacticalImportPreview {
  const TacticalImportPreview({
    required this.batchId,
    required this.sourceFingerprint,
    required this.matchCount,
    required this.jokboCount,
    required this.validRecordCount,
    required this.issues,
  });
  final String batchId, sourceFingerprint;
  final int matchCount, jokboCount, validRecordCount;
  final List<TacticalImportIssue> issues;
  factory TacticalImportPreview.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'import_batch_id',
      'source_fingerprint',
      'match_count',
      'jokbo_count',
      'opponent_count',
      'snapshot_count',
      'valid_record_count',
      'issue_count',
      'issues',
    };
    if (!_exactV2(value, fields) ||
        value['version'] != 2 ||
        !_recordIdV2(value['import_batch_id']) ||
        value['source_fingerprint'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(value['source_fingerprint']) ||
        [
          value['match_count'],
          value['jokbo_count'],
          value['opponent_count'],
          value['snapshot_count'],
          value['valid_record_count'],
          value['issue_count'],
        ].any((item) => item is! int || item < 0) ||
        value['issues'] is! List) {
      throw const FormatException('Invalid tactical import preview');
    }
    final issues = (value['issues'] as List)
        .map(
          (item) => TacticalImportIssue.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    if (issues.length != value['issue_count']) {
      throw const FormatException('Tactical import issue count mismatch');
    }
    return TacticalImportPreview(
      batchId: value['import_batch_id'] as String,
      sourceFingerprint: value['source_fingerprint'] as String,
      matchCount: value['match_count'] as int,
      jokboCount: value['jokbo_count'] as int,
      validRecordCount: value['valid_record_count'] as int,
      issues: List.unmodifiable(issues),
    );
  }
}

@immutable
class TacticalImportCommitResult {
  const TacticalImportCommitResult({
    required this.revision,
    required this.importedMatches,
    required this.importedJokbo,
    required this.skippedIssues,
    required this.skippedExisting,
  });
  final int revision,
      importedMatches,
      importedJokbo,
      skippedIssues,
      skippedExisting;
  factory TacticalImportCommitResult.fromWire(Map<String, dynamic> value) {
    const fields = {
      'revision',
      'imported_matches',
      'imported_jokbo',
      'skipped_issues',
      'skipped_existing',
    };
    if (!_exactV2(value, fields) ||
        fields.any((key) => value[key] is! int || value[key] < 0)) {
      throw const FormatException('Invalid tactical import commit result');
    }
    return TacticalImportCommitResult(
      revision: value['revision'] as int,
      importedMatches: value['imported_matches'] as int,
      importedJokbo: value['imported_jokbo'] as int,
      skippedIssues: value['skipped_issues'] as int,
      skippedExisting: value['skipped_existing'] as int,
    );
  }
}

@immutable
class TacticalLobbyCommitResult {
  const TacticalLobbyCommitResult({
    required this.revision,
    required this.scanId,
    required this.candidateIds,
    required this.created,
  });
  final int revision;
  final String scanId;
  final List<String> candidateIds;
  final bool created;

  factory TacticalLobbyCommitResult.fromWire(Map<String, dynamic> value) {
    const fields = {'revision', 'scan_id', 'candidate_ids', 'created'};
    final ids = value['candidate_ids'];
    if (!_exactV2(value, fields) ||
        value['revision'] is! int ||
        value['revision'] < 0 ||
        !_recordIdV2(value['scan_id']) ||
        ids is! List ||
        ids.any((item) => !_recordIdV2(item)) ||
        value['created'] is! bool) {
      throw const FormatException('Invalid tactical lobby commit result');
    }
    return TacticalLobbyCommitResult(
      revision: value['revision'] as int,
      scanId: value['scan_id'] as String,
      candidateIds: List.unmodifiable(ids.cast<String>()),
      created: value['created'] as bool,
    );
  }
}

@immutable
class TacticalLinkResult {
  const TacticalLinkResult({
    required this.revision,
    required this.status,
    required this.candidateId,
    required this.matchId,
    required this.candidateCount,
  });
  final int revision;
  final String status;
  final String? candidateId;
  final String matchId;
  final int? candidateCount;

  factory TacticalLinkResult.fromWire(Map<String, dynamic> value) {
    const required = {'revision', 'status', 'candidate_id', 'match_id'};
    if (!value.keys.toSet().containsAll(required) ||
        !{...required, 'candidate_count'}.containsAll(value.keys) ||
        value['revision'] is! int ||
        value['revision'] < 0 ||
        !{
          'unlinked',
          'automatic',
          'manual',
          'ambiguous',
          'unresolved',
        }.contains(value['status']) ||
        (value['candidate_id'] != null &&
            !_recordIdV2(value['candidate_id'])) ||
        !_recordIdV2(value['match_id']) ||
        (value['candidate_count'] != null &&
            (value['candidate_count'] is! int ||
                value['candidate_count'] < 0))) {
      throw const FormatException('Invalid tactical link result');
    }
    return TacticalLinkResult(
      revision: value['revision'] as int,
      status: value['status'] as String,
      candidateId: value['candidate_id'] as String?,
      matchId: value['match_id'] as String,
      candidateCount: value['candidate_count'] as int?,
    );
  }
}

@immutable
class TacticalStatsFilters {
  const TacticalStatsFilters({
    this.season,
    this.sources = const [],
    this.opponentIdentityId,
    this.publicSignature,
    this.dateFrom,
    this.dateTo,
    this.limit = 50,
  });
  final String? season, opponentIdentityId, publicSignature, dateFrom, dateTo;
  final List<String> sources;
  final int limit;

  Map<String, dynamic> toWire() => {
    'season': season,
    'sources': sources,
    'opponent_identity_id': opponentIdentityId,
    'public_signature': publicSignature,
    'date_from': dateFrom,
    'date_to': dateTo,
    'limit': limit,
  };
}

@immutable
class TacticalStatsPopulation {
  const TacticalStatsPopulation({
    required this.refreshCount,
    required this.exposureCount,
    required this.selectedCount,
    required this.linkedMatchCount,
    required this.matchCount,
    required this.attackMatchCount,
    required this.defenseMatchCount,
    required this.opponentCount,
  });
  final int refreshCount,
      exposureCount,
      selectedCount,
      linkedMatchCount,
      matchCount,
      attackMatchCount,
      defenseMatchCount,
      opponentCount;

  factory TacticalStatsPopulation.fromWire(Map<String, dynamic> value) {
    const fields = {
      'refresh_count',
      'exposure_count',
      'selected_count',
      'linked_match_count',
      'match_count',
      'attack_match_count',
      'defense_match_count',
      'opponent_count',
    };
    if (!_exactV2(value, fields) ||
        fields.any((key) => value[key] is! int || value[key] < 0)) {
      throw const FormatException('Invalid tactical statistics population');
    }
    return TacticalStatsPopulation(
      refreshCount: value['refresh_count'] as int,
      exposureCount: value['exposure_count'] as int,
      selectedCount: value['selected_count'] as int,
      linkedMatchCount: value['linked_match_count'] as int,
      matchCount: value['match_count'] as int,
      attackMatchCount: value['attack_match_count'] as int,
      defenseMatchCount: value['defense_match_count'] as int,
      opponentCount: value['opponent_count'] as int,
    );
  }
}

// FE9-b1: 통계 하위 행. schema(`statsResponse`)는 `public_signatures`·`opponents` 원소를 `{type: object}`로만 두므로
// 키·타입은 백엔드 `core/tactical_stats_v2.py`(`_result`·signature·opponent 행)를 따른다(status-lane-b FE9-b1 DTO 표).

bool _rateV2(Object? item) =>
    item == null || (item is num && item >= 0 && item <= 1);

bool _countV2(Object? item) => item is int && item >= 0;

/// 출처별 개수(`source_counts`). 키는 출처 이름, 값은 0 이상 정수.
Map<String, int> _sourceCountsV2(Object? raw) {
  if (raw is! Map ||
      raw.keys.any((key) => !_sourcesV2.contains(key)) ||
      raw.values.any((item) => !_countV2(item))) {
    throw const FormatException('Invalid tactical source counts');
  }
  return Map.unmodifiable(Map<String, int>.from(raw));
}

/// 관측 결과 묶음(백엔드 `_result`): 기록 수 · 승 · 패 · 관측 승률 · Wilson 95% 구간(표본 0이면 null).
@immutable
class TacticalObservedResult {
  const TacticalObservedResult({
    required this.count,
    required this.wins,
    required this.losses,
    required this.observedWinRate,
    required this.wilson95Low,
    required this.wilson95High,
  });
  final int count, wins, losses;
  final double? observedWinRate, wilson95Low, wilson95High;

  static const fields = {
    'count',
    'wins',
    'losses',
    'observed_win_rate',
    'wilson95_low',
    'wilson95_high',
  };

  factory TacticalObservedResult.fromWire(Map<String, dynamic> value) {
    if (!_exactV2(value, fields)) {
      throw const FormatException('Invalid tactical observed result');
    }
    return TacticalObservedResult._checked(value);
  }

  /// [value]에 다른 키(예 `signature`)가 함께 있는 행에서 결과 6키만 읽는다.
  factory TacticalObservedResult._checked(Map<String, dynamic> value) {
    if (!_countV2(value['count']) ||
        !_countV2(value['wins']) ||
        !_countV2(value['losses']) ||
        !_rateV2(value['observed_win_rate']) ||
        !_rateV2(value['wilson95_low']) ||
        !_rateV2(value['wilson95_high'])) {
      throw const FormatException('Invalid tactical observed result');
    }
    return TacticalObservedResult(
      count: value['count'] as int,
      wins: value['wins'] as int,
      losses: value['losses'] as int,
      observedWinRate: (value['observed_win_rate'] as num?)?.toDouble(),
      wilson95Low: (value['wilson95_low'] as num?)?.toDouble(),
      wilson95High: (value['wilson95_high'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toWire() => {
    'count': count,
    'wins': wins,
    'losses': losses,
    'observed_win_rate': observedWinRate,
    'wilson95_low': wilson95Low,
    'wilson95_high': wilson95High,
  };
}

/// 공개 시그니처에 연결된 공격 덱 한 줄(`attack_decks` 원소: `signature` + 관측 결과).
@immutable
class TacticalSignatureAttackDeck {
  const TacticalSignatureAttackDeck({
    required this.signature,
    required this.result,
  });
  final String signature;
  final TacticalObservedResult result;

  factory TacticalSignatureAttackDeck.fromWire(Map<String, dynamic> value) {
    if (!_exactV2(value, {'signature', ...TacticalObservedResult.fields}) ||
        value['signature'] is! String ||
        (value['signature'] as String).isEmpty) {
      throw const FormatException('Invalid signature attack deck');
    }
    return TacticalSignatureAttackDeck(
      signature: value['signature'] as String,
      result: TacticalObservedResult._checked(value),
    );
  }
}

/// 공개 시그니처 뒤에서 확인된 완전 방어 덱 한 줄(`full_defenses` 원소).
@immutable
class TacticalSignatureFullDefense {
  const TacticalSignatureFullDefense({
    required this.signature,
    required this.count,
  });
  final String signature;
  final int count;

  factory TacticalSignatureFullDefense.fromWire(Map<String, dynamic> value) {
    if (!_exactV2(value, {'signature', 'count'}) ||
        value['signature'] is! String ||
        (value['signature'] as String).isEmpty ||
        !_countV2(value['count'])) {
      throw const FormatException('Invalid signature full defense');
    }
    return TacticalSignatureFullDefense(
      signature: value['signature'] as String,
      count: value['count'] as int,
    );
  }
}

/// 상대 통계의 최근 공개 관측(`latest_public`) 또는 최근 완전 방어(`latest_full`).
@immutable
class TacticalOpponentLatestDeck {
  const TacticalOpponentLatestDeck({
    required this.signature,
    required this.observedAt,
    required this.snapshotId,
  });

  /// `latest_public`이면 공개 시그니처, `latest_full`이면 완전 덱 시그니처.
  final String signature;
  final String observedAt, snapshotId;

  static TacticalOpponentLatestDeck? fromWire(
    Object? raw, {
    required String signatureKey,
  }) {
    if (raw == null) return null;
    if (raw is! Map) {
      throw const FormatException('Invalid opponent latest deck');
    }
    final value = Map<String, dynamic>.from(raw);
    if (!_exactV2(value, {signatureKey, 'observed_at', 'snapshot_id'}) ||
        value[signatureKey] is! String ||
        (value[signatureKey] as String).isEmpty ||
        !_recordIdV2(value['snapshot_id'])) {
      throw const FormatException('Invalid opponent latest deck');
    }
    return TacticalOpponentLatestDeck(
      signature: value[signatureKey] as String,
      observedAt: _timestampV2(value['observed_at'], nullable: false)!,
      snapshotId: value['snapshot_id'] as String,
    );
  }
}

/// 통계 응답 `opponents` 원소: 상대별 노출·선택·기록 수와 공격·방어 결과(따로), 최근 공개·완전 덱.
@immutable
class TacticalOpponentStats {
  const TacticalOpponentStats({
    required this.opponentIdentityId,
    required this.displayName,
    required this.exposureCount,
    required this.selectedCount,
    required this.matchCount,
    required this.attackResults,
    required this.defenseResults,
    required this.latestPublic,
    required this.latestFull,
  });
  final String opponentIdentityId;

  /// 상대 identity가 없으면 백엔드가 빈 문자열을 준다(화면은 '—').
  final String displayName;
  final int exposureCount, selectedCount, matchCount;
  final TacticalObservedResult attackResults, defenseResults;
  final TacticalOpponentLatestDeck? latestPublic, latestFull;

  factory TacticalOpponentStats.fromWire(Map<String, dynamic> value) {
    const fields = {
      'opponent_identity_id',
      'display_name',
      'exposure_count',
      'selected_count',
      'match_count',
      'attack_results',
      'defense_results',
      'latest_public',
      'latest_full',
    };
    if (!_exactV2(value, fields) ||
        !_recordIdV2(value['opponent_identity_id']) ||
        value['display_name'] is! String ||
        !_countV2(value['exposure_count']) ||
        !_countV2(value['selected_count']) ||
        !_countV2(value['match_count']) ||
        value['attack_results'] is! Map ||
        value['defense_results'] is! Map) {
      throw const FormatException('Invalid tactical opponent statistics');
    }
    return TacticalOpponentStats(
      opponentIdentityId: value['opponent_identity_id'] as String,
      displayName: value['display_name'] as String,
      exposureCount: value['exposure_count'] as int,
      selectedCount: value['selected_count'] as int,
      matchCount: value['match_count'] as int,
      attackResults: TacticalObservedResult.fromWire(
        Map<String, dynamic>.from(value['attack_results'] as Map),
      ),
      defenseResults: TacticalObservedResult.fromWire(
        Map<String, dynamic>.from(value['defense_results'] as Map),
      ),
      latestPublic: TacticalOpponentLatestDeck.fromWire(
        value['latest_public'],
        signatureKey: 'public_signature',
      ),
      latestFull: TacticalOpponentLatestDeck.fromWire(
        value['latest_full'],
        signatureKey: 'deck_signature',
      ),
    );
  }
}

@immutable
class TacticalPublicSignatureStats {
  const TacticalPublicSignatureStats({
    required this.signature,
    required this.exposureCount,
    required this.opponentCount,
    required this.selectedCount,
    required this.linkedMatchCount,
    required this.wins,
    required this.losses,
    required this.observedWinRate,
    required this.wilson95Low,
    required this.wilson95High,
    required this.sourceCounts,
    required this.attackDecks,
    required this.attackDeckTotal,
    required this.fullDefenses,
    required this.fullDefenseTotal,
  });
  final String signature;
  final int exposureCount,
      opponentCount,
      selectedCount,
      linkedMatchCount,
      wins,
      losses;
  final double? observedWinRate, wilson95Low, wilson95High;

  /// FE9-b1: 출처별 개수(`lobby_scan` = 노출 수, 그 밖 = 연결 기록의 출처).
  final Map<String, int> sourceCounts;

  /// FE9-b1: 이 시그니처에 연결된 공격 덱(많이 쓴 순, `limit`까지)과 전체 개수.
  final List<TacticalSignatureAttackDeck> attackDecks;
  final int attackDeckTotal;

  /// FE9-b1: 이 시그니처 뒤에서 확인된 완전 방어 덱(많은 순, `limit`까지)과 전체 개수.
  final List<TacticalSignatureFullDefense> fullDefenses;
  final int fullDefenseTotal;

  factory TacticalPublicSignatureStats.fromWire(Map<String, dynamic> value) {
    const fields = {
      'public_signature',
      'exposure_count',
      'opponent_count',
      'selected_count',
      'linked_match_count',
      'wins',
      'losses',
      'observed_win_rate',
      'wilson95_low',
      'wilson95_high',
      'source_counts',
      'attack_decks',
      'attack_deck_total',
      'full_defenses',
      'full_defense_total',
    };
    bool rate(Object? item) =>
        item == null || (item is num && item >= 0 && item <= 1);
    if (!_exactV2(value, fields) ||
        value['public_signature'] is! String ||
        (value['public_signature'] as String).isEmpty ||
        [
          value['exposure_count'],
          value['opponent_count'],
          value['selected_count'],
          value['linked_match_count'],
          value['wins'],
          value['losses'],
          value['attack_deck_total'],
          value['full_defense_total'],
        ].any((item) => item is! int || item < 0) ||
        !rate(value['observed_win_rate']) ||
        !rate(value['wilson95_low']) ||
        !rate(value['wilson95_high']) ||
        value['source_counts'] is! Map ||
        value['attack_decks'] is! List ||
        value['full_defenses'] is! List) {
      throw const FormatException('Invalid public signature statistics');
    }
    return TacticalPublicSignatureStats(
      signature: value['public_signature'] as String,
      exposureCount: value['exposure_count'] as int,
      opponentCount: value['opponent_count'] as int,
      selectedCount: value['selected_count'] as int,
      linkedMatchCount: value['linked_match_count'] as int,
      wins: value['wins'] as int,
      losses: value['losses'] as int,
      observedWinRate: (value['observed_win_rate'] as num?)?.toDouble(),
      wilson95Low: (value['wilson95_low'] as num?)?.toDouble(),
      wilson95High: (value['wilson95_high'] as num?)?.toDouble(),
      sourceCounts: _sourceCountsV2(value['source_counts']),
      attackDecks: List.unmodifiable(
        (value['attack_decks'] as List).map(
          (item) => TacticalSignatureAttackDeck.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
      attackDeckTotal: value['attack_deck_total'] as int,
      fullDefenses: List.unmodifiable(
        (value['full_defenses'] as List).map(
          (item) => TacticalSignatureFullDefense.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
      fullDefenseTotal: value['full_defense_total'] as int,
    );
  }
}

@immutable
class TacticalStatisticsResult {
  const TacticalStatisticsResult({
    required this.population,
    required this.publicSignatures,
    required this.publicSignatureTotal,
    required this.opponentTotal,
    required this.attackPatterns,
    required this.quality,
    required this.populationWarning,
    required this.opponents,
  });
  final TacticalStatsPopulation population;
  final List<TacticalPublicSignatureStats> publicSignatures;

  /// FE9-b1: 상대별 통계(노출 많은 순, `limit`까지). 전체 개수는 [opponentTotal].
  final List<TacticalOpponentStats> opponents;
  final int publicSignatureTotal, opponentTotal;
  final Map<String, dynamic> attackPatterns, quality;
  final String populationWarning;

  factory TacticalStatisticsResult.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'filters',
      'population',
      'public_signatures',
      'public_signature_total',
      'opponents',
      'opponent_total',
      'attack_patterns',
      'quality',
      'terminology',
    };
    final terminology = value['terminology'];
    if (!_exactV2(value, fields) ||
        value['version'] != 2 ||
        value['filters'] is! Map ||
        value['population'] is! Map ||
        value['public_signatures'] is! List ||
        value['public_signature_total'] is! int ||
        value['public_signature_total'] < 0 ||
        value['opponents'] is! List ||
        value['opponent_total'] is! int ||
        value['opponent_total'] < 0 ||
        value['attack_patterns'] is! Map ||
        value['quality'] is! Map ||
        terminology is! Map ||
        terminology['rate_label'] != 'observed_win_rate' ||
        terminology['population_warning'] is! String ||
        (terminology['population_warning'] as String).isEmpty) {
      throw const FormatException('Invalid tactical statistics result');
    }
    return TacticalStatisticsResult(
      population: TacticalStatsPopulation.fromWire(
        Map<String, dynamic>.from(value['population'] as Map),
      ),
      publicSignatures: List.unmodifiable(
        (value['public_signatures'] as List).map(
          (item) => TacticalPublicSignatureStats.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
      publicSignatureTotal: value['public_signature_total'] as int,
      opponents: List.unmodifiable(
        (value['opponents'] as List).map(
          (item) => TacticalOpponentStats.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
      opponentTotal: value['opponent_total'] as int,
      attackPatterns: Map.unmodifiable(
        Map<String, dynamic>.from(value['attack_patterns'] as Map),
      ),
      quality: Map.unmodifiable(
        Map<String, dynamic>.from(value['quality'] as Map),
      ),
      populationWarning: terminology['population_warning'] as String,
    );
  }
}

@immutable
class TacticalTrendFilters {
  const TacticalTrendFilters({
    this.season,
    this.sources = const [],
    this.opponentIdentityId,
    this.publicSignature,
    this.dateFrom,
    this.dateTo,
    this.rankDifferenceMin,
    this.rankDifferenceMax,
    required this.asOf,
    this.staleAfterHours = 168,
    this.limit = 50,
  });
  final String? season, opponentIdentityId, publicSignature, dateFrom, dateTo;
  final List<String> sources;
  final int? rankDifferenceMin, rankDifferenceMax;
  final String asOf;
  final int staleAfterHours, limit;

  Map<String, dynamic> toWire() => {
    'season': season,
    'sources': sources,
    'opponent_identity_id': opponentIdentityId,
    'public_signature': publicSignature,
    'date_from': dateFrom,
    'date_to': dateTo,
    'rank_difference_min': rankDifferenceMin,
    'rank_difference_max': rankDifferenceMax,
    'as_of': asOf,
    'stale_after_hours': staleAfterHours,
    'limit': limit,
  };
}

@immutable
class TacticalTrendFunnel {
  const TacticalTrendFunnel({
    required this.refreshCount,
    required this.opponentCount,
    required this.exposureCount,
    required this.selectionCount,
    required this.battleCount,
    required this.resultCount,
    required this.wins,
    required this.losses,
    required this.exposuresPerRefresh,
    required this.selectionRate,
    required this.observedWinRate,
  });
  final int refreshCount,
      opponentCount,
      exposureCount,
      selectionCount,
      battleCount,
      resultCount,
      wins,
      losses;
  final double? exposuresPerRefresh, selectionRate, observedWinRate;

  factory TacticalTrendFunnel.fromWire(Map<String, dynamic> value) {
    const fields = {
      'refresh_count',
      'opponent_count',
      'exposures_per_refresh',
      'exposure_count',
      'selection_count',
      'selection_rate',
      'battle_count',
      'result_count',
      'wins',
      'losses',
      'observed_win_rate',
    };
    final counts = fields.where(
      (key) => !key.contains('rate') && key != 'exposures_per_refresh',
    );
    bool nullableNumber(Object? item) => item == null || item is num;
    if (!_exactV2(value, fields) ||
        counts.any((key) => value[key] is! int || value[key] < 0) ||
        !nullableNumber(value['exposures_per_refresh']) ||
        !nullableNumber(value['selection_rate']) ||
        !nullableNumber(value['observed_win_rate'])) {
      throw const FormatException('Invalid tactical trend funnel');
    }
    return TacticalTrendFunnel(
      refreshCount: value['refresh_count'] as int,
      opponentCount: value['opponent_count'] as int,
      exposureCount: value['exposure_count'] as int,
      selectionCount: value['selection_count'] as int,
      battleCount: value['battle_count'] as int,
      resultCount: value['result_count'] as int,
      wins: value['wins'] as int,
      losses: value['losses'] as int,
      exposuresPerRefresh: (value['exposures_per_refresh'] as num?)?.toDouble(),
      selectionRate: (value['selection_rate'] as num?)?.toDouble(),
      observedWinRate: (value['observed_win_rate'] as num?)?.toDouble(),
    );
  }
}

@immutable
class TacticalFreshnessEvidence {
  const TacticalFreshnessEvidence({
    required this.opponentIdentityId,
    required this.publicSignature,
    required this.attackSignature,
    required this.lastBattleAt,
    required this.ageHours,
    required this.freshnessWeight,
    required this.stale,
    required this.verifiedAfterLatestPublic,
    required this.lastSuccessAt,
    required this.verifiedAfterLatestChange,
  });
  final String opponentIdentityId,
      publicSignature,
      attackSignature,
      lastBattleAt;
  final double ageHours, freshnessWeight;
  final bool stale, verifiedAfterLatestPublic;

  /// FE9-b1: 마지막 승리 시각(이긴 기록이 없으면 null).
  final String? lastSuccessAt;

  /// FE9-b1: 최근 공개 덱 변경 뒤에 다시 싸워 봤는가. 변경이 관측된 적 없으면 null(모름 — false와 다르다).
  final bool? verifiedAfterLatestChange;

  factory TacticalFreshnessEvidence.fromWire(Map<String, dynamic> value) {
    const fields = {
      'opponent_identity_id',
      'public_signature',
      'attack_signature',
      'is_current_public_signature',
      'last_battle_at',
      'last_success_at',
      'last_failure_at',
      'latest_public_observed_at',
      'latest_public_change_at',
      'verified_after_latest_public',
      'verified_after_latest_change',
      'age_hours',
      'freshness_weight',
      'stale',
    };
    if (!_exactV2(value, fields) ||
        value['opponent_identity_id'] is! String ||
        value['public_signature'] is! String ||
        value['attack_signature'] is! String ||
        value['last_battle_at'] is! String ||
        value['age_hours'] is! num ||
        value['age_hours'] < 0 ||
        value['freshness_weight'] is! num ||
        value['freshness_weight'] < 0 ||
        value['freshness_weight'] > 1 ||
        value['stale'] is! bool ||
        value['verified_after_latest_public'] is! bool ||
        (value['verified_after_latest_change'] != null &&
            value['verified_after_latest_change'] is! bool)) {
      throw const FormatException('Invalid tactical freshness evidence');
    }
    _timestampV2(value['last_battle_at'], nullable: false);
    return TacticalFreshnessEvidence(
      opponentIdentityId: value['opponent_identity_id'] as String,
      publicSignature: value['public_signature'] as String,
      attackSignature: value['attack_signature'] as String,
      lastBattleAt: value['last_battle_at'] as String,
      ageHours: (value['age_hours'] as num).toDouble(),
      freshnessWeight: (value['freshness_weight'] as num).toDouble(),
      stale: value['stale'] as bool,
      verifiedAfterLatestPublic: value['verified_after_latest_public'] as bool,
      lastSuccessAt: _timestampV2(value['last_success_at']),
      verifiedAfterLatestChange: value['verified_after_latest_change'] as bool?,
    );
  }
}

@immutable
class TacticalTrendsResult {
  const TacticalTrendsResult({
    required this.funnel,
    required this.exposure,
    required this.changes,
    required this.freshness,
    required this.freshnessTotal,
    required this.populationWarning,
  });
  final TacticalTrendFunnel funnel;
  final Map<String, dynamic> exposure, changes;
  final List<TacticalFreshnessEvidence> freshness;
  final int freshnessTotal;
  final String populationWarning;

  factory TacticalTrendsResult.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'filters',
      'funnel',
      'exposure',
      'changes',
      'freshness',
      'freshness_total',
      'terminology',
    };
    final terminology = value['terminology'];
    if (!_exactV2(value, fields) ||
        value['version'] != 2 ||
        value['filters'] is! Map ||
        value['funnel'] is! Map ||
        value['exposure'] is! Map ||
        value['changes'] is! Map ||
        value['freshness'] is! List ||
        value['freshness_total'] is! int ||
        value['freshness_total'] < 0 ||
        terminology is! Map ||
        terminology['exposure_rate_label'] != 'observed_exposure_rate' ||
        terminology['selection_rate_label'] != 'observed_selection_rate' ||
        terminology['win_rate_label'] != 'observed_win_rate' ||
        terminology['population_warning'] is! String) {
      throw const FormatException('Invalid tactical trends result');
    }
    return TacticalTrendsResult(
      funnel: TacticalTrendFunnel.fromWire(
        Map<String, dynamic>.from(value['funnel'] as Map),
      ),
      exposure: Map.unmodifiable(
        Map<String, dynamic>.from(value['exposure'] as Map),
      ),
      changes: Map.unmodifiable(
        Map<String, dynamic>.from(value['changes'] as Map),
      ),
      freshness: List.unmodifiable(
        (value['freshness'] as List).map(
          (item) => TacticalFreshnessEvidence.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
      freshnessTotal: value['freshness_total'] as int,
      populationWarning: terminology['population_warning'] as String,
    );
  }
}

@immutable
class TacticalRecommendationFilters {
  const TacticalRecommendationFilters({
    required this.season,
    required this.opponentIdentityId,
    required this.publicSignature,
    this.rankDifference,
    required this.asOf,
    this.halfLifeHours = 168,
    this.minTargetSamples = 3,
    this.topK = 5,
    this.ownedStudentIds = const [],
  });
  final String season, opponentIdentityId, publicSignature, asOf;
  final int? rankDifference;
  final int halfLifeHours, minTargetSamples, topK;
  final List<String> ownedStudentIds;

  Map<String, dynamic> toWire() => {
    'season': season,
    'opponent_identity_id': opponentIdentityId,
    'public_signature': publicSignature,
    'rank_difference': rankDifference,
    'as_of': asOf,
    'half_life_hours': halfLifeHours,
    'min_target_samples': minTargetSamples,
    'top_k': topK,
    'owned_student_ids': ownedStudentIds,
  };
}

@immutable
class TacticalDefenseScenario {
  const TacticalDefenseScenario({
    required this.defenseSignature,
    required this.evidenceWeightShare,
    required this.snapshotCount,
    required this.distinctOpponentCount,
    required this.lastConfirmedAt,
    required this.deck,
  });
  final String defenseSignature, lastConfirmedAt;
  final double evidenceWeightShare;
  final int snapshotCount, distinctOpponentCount;

  /// FE9-b1: schema `recommendResponse.scenarios[].deck`(`#/$defs/deck`) — 가장 최근 근거 스냅샷의 완전 방어 덱.
  final TacticalDeckV2 deck;

  factory TacticalDefenseScenario.fromWire(Map<String, dynamic> value) {
    const fields = {
      'defense_signature',
      'evidence_weight',
      'evidence_weight_share',
      'snapshot_count',
      'target_opponent_snapshot_count',
      'target_opponent_evidence_share',
      'distinct_opponent_count',
      'match_count',
      'last_confirmed_at',
      'supporting_snapshot_ids',
      'source_counts',
      'deck',
    };
    if (!_exactV2(value, fields) ||
        value['defense_signature'] is! String ||
        value['evidence_weight'] is! num ||
        value['evidence_weight'] < 0 ||
        value['evidence_weight_share'] is! num ||
        value['evidence_weight_share'] < 0 ||
        value['evidence_weight_share'] > 1 ||
        value['snapshot_count'] is! int ||
        value['snapshot_count'] < 1 ||
        value['target_opponent_snapshot_count'] is! int ||
        value['target_opponent_snapshot_count'] < 0 ||
        value['target_opponent_evidence_share'] is! num ||
        value['target_opponent_evidence_share'] < 0 ||
        value['target_opponent_evidence_share'] > 1 ||
        value['distinct_opponent_count'] is! int ||
        value['distinct_opponent_count'] < 1 ||
        value['last_confirmed_at'] is! String ||
        value['deck'] is! Map) {
      throw const FormatException('Invalid tactical defense scenario');
    }
    _timestampV2(value['last_confirmed_at'], nullable: false);
    return TacticalDefenseScenario(
      defenseSignature: value['defense_signature'] as String,
      evidenceWeightShare: (value['evidence_weight_share'] as num).toDouble(),
      snapshotCount: value['snapshot_count'] as int,
      distinctOpponentCount: value['distinct_opponent_count'] as int,
      lastConfirmedAt: value['last_confirmed_at'] as String,
      deck: TacticalDeckV2.fromWire(
        Map<String, dynamic>.from(value['deck'] as Map),
      ),
    );
  }
}

@immutable
class TacticalAttackRecommendation {
  const TacticalAttackRecommendation({
    required this.attackSignature,
    required this.score,
    required this.observedMatchCount,
    required this.observedWinRate,
    required this.missingStudentIds,
    required this.allKnownStudentsOwned,
    required this.deck,
    required this.wins,
    required this.losses,
    required this.lastObservedAt,
  });
  final String attackSignature;
  final double score;
  final int observedMatchCount;
  final double? observedWinRate;
  final List<String> missingStudentIds;
  final bool allKnownStudentsOwned;

  /// FE9-b1: 추천 공격 덱(드래그 복사의 원본), 관측 승·패, 마지막 관측 시각.
  final TacticalDeckV2 deck;
  final int wins, losses;
  final String lastObservedAt;

  factory TacticalAttackRecommendation.fromWire(Map<String, dynamic> value) {
    const fields = {
      'attack_signature',
      'score',
      'score_components',
      'observed_match_count',
      'wins',
      'losses',
      'observed_win_rate',
      'wilson95_low',
      'evidence_scope',
      'source_counts',
      'last_observed_at',
      'required_student_ids',
      'missing_student_ids',
      'all_known_students_owned',
      'deck',
    };
    final rate = value['observed_win_rate'];
    if (!_exactV2(value, fields) ||
        value['attack_signature'] is! String ||
        value['score'] is! num ||
        value['score'] < 0 ||
        value['score'] > 1 ||
        value['score_components'] is! Map ||
        value['observed_match_count'] is! int ||
        value['observed_match_count'] < 1 ||
        !(rate == null || rate is num && rate >= 0 && rate <= 1) ||
        value['missing_student_ids'] is! List ||
        value['all_known_students_owned'] is! bool ||
        value['deck'] is! Map ||
        !_countV2(value['wins']) ||
        !_countV2(value['losses'])) {
      throw const FormatException('Invalid tactical attack recommendation');
    }
    return TacticalAttackRecommendation(
      attackSignature: value['attack_signature'] as String,
      score: (value['score'] as num).toDouble(),
      observedMatchCount: value['observed_match_count'] as int,
      observedWinRate: (rate as num?)?.toDouble(),
      missingStudentIds: List.unmodifiable(
        (value['missing_student_ids'] as List).cast<String>(),
      ),
      allKnownStudentsOwned: value['all_known_students_owned'] as bool,
      deck: TacticalDeckV2.fromWire(
        Map<String, dynamic>.from(value['deck'] as Map),
      ),
      wins: value['wins'] as int,
      losses: value['losses'] as int,
      lastObservedAt: _timestampV2(value['last_observed_at'], nullable: false)!,
    );
  }
}

/// FE9-b1: 추천 근거 요약(`evidence_summary`). 날짜 없는 스냅샷은 근거에서 빠지고 따로 센다.
@immutable
class TacticalEvidenceSummary {
  const TacticalEvidenceSummary({
    required this.includedSnapshotCount,
    required this.distinctOpponentCount,
    required this.excludedUndatedSnapshotCount,
  });
  final int includedSnapshotCount,
      distinctOpponentCount,
      excludedUndatedSnapshotCount;

  factory TacticalEvidenceSummary.fromWire(Map<String, dynamic> value) {
    const fields = {
      'included_snapshot_count',
      'distinct_opponent_count',
      'excluded_undated_snapshot_count',
    };
    if (!_exactV2(value, fields) ||
        fields.any((key) => !_countV2(value[key]))) {
      throw const FormatException('Invalid tactical evidence summary');
    }
    return TacticalEvidenceSummary(
      includedSnapshotCount: value['included_snapshot_count'] as int,
      distinctOpponentCount: value['distinct_opponent_count'] as int,
      excludedUndatedSnapshotCount:
          value['excluded_undated_snapshot_count'] as int,
    );
  }
}

const _hiddenSlotPositionsV2 = {
  'striker:0',
  'striker:1',
  'striker:2',
  'striker:3',
  'special:0',
  'special:1',
};

/// FE9-b1: 숨은 칸 후보 한 개. [value]는 학생 ID 또는 `?`(모름)·`*`(와일드카드)·`empty`(빈칸).
/// [evidenceWeightShare]는 근거 가중치 비율이지 확률이 아니다(terminology).
@immutable
class TacticalHiddenSlotCandidate {
  const TacticalHiddenSlotCandidate({
    required this.value,
    required this.evidenceWeightShare,
    required this.supportingSnapshotCount,
  });
  final String value;
  final double evidenceWeightShare;
  final int supportingSnapshotCount;

  factory TacticalHiddenSlotCandidate.fromWire(Map<String, dynamic> value) {
    if (!_exactV2(value, {
          'value',
          'evidence_weight_share',
          'supporting_snapshot_count',
        }) ||
        value['value'] is! String ||
        (value['value'] as String).isEmpty ||
        value['evidence_weight_share'] is! num ||
        !_rateV2(value['evidence_weight_share']) ||
        !_countV2(value['supporting_snapshot_count'])) {
      throw const FormatException('Invalid tactical hidden slot candidate');
    }
    return TacticalHiddenSlotCandidate(
      value: value['value'] as String,
      evidenceWeightShare: (value['evidence_weight_share'] as num).toDouble(),
      supportingSnapshotCount: value['supporting_snapshot_count'] as int,
    );
  }
}

/// FE9-b1: 공개 로비에서 가려진 칸(`hidden_slots` 원소). [position]은 `striker:0`~`3`·`special:0`~`1`.
@immutable
class TacticalHiddenSlot {
  TacticalHiddenSlot({
    required this.position,
    required List<TacticalHiddenSlotCandidate> candidates,
  }) : candidates = List.unmodifiable(candidates);
  final String position;
  final List<TacticalHiddenSlotCandidate> candidates;

  factory TacticalHiddenSlot.fromWire(Map<String, dynamic> value) {
    if (!_exactV2(value, {'position', 'candidates'}) ||
        !_hiddenSlotPositionsV2.contains(value['position']) ||
        value['candidates'] is! List) {
      throw const FormatException('Invalid tactical hidden slot');
    }
    return TacticalHiddenSlot(
      position: value['position'] as String,
      candidates: [
        for (final item in value['candidates'] as List)
          TacticalHiddenSlotCandidate.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
      ],
    );
  }
}

/// FE9-b1: 방어 덱 모호도(`ambiguity`). 근거가 없으면 [grade] `unavailable`·[topEvidenceWeightShare] null.
@immutable
class TacticalRecommendationAmbiguity {
  const TacticalRecommendationAmbiguity({
    required this.grade,
    required this.variantDefensePossible,
    required this.topEvidenceWeightShare,
    required this.publicKnownSlotCount,
  });
  final String grade;
  final bool variantDefensePossible;
  final double? topEvidenceWeightShare;
  final int publicKnownSlotCount;

  factory TacticalRecommendationAmbiguity.fromWire(Map<String, dynamic> value) {
    if (!_exactV2(value, {
          'grade',
          'variant_defense_possible',
          'top_evidence_weight_share',
          'public_known_slot_count',
        }) ||
        !{'low', 'medium', 'high', 'unavailable'}.contains(value['grade']) ||
        value['variant_defense_possible'] is! bool ||
        !_rateV2(value['top_evidence_weight_share']) ||
        !_countV2(value['public_known_slot_count']) ||
        (value['public_known_slot_count'] as int) > 6) {
      throw const FormatException('Invalid tactical recommendation ambiguity');
    }
    return TacticalRecommendationAmbiguity(
      grade: value['grade'] as String,
      variantDefensePossible: value['variant_defense_possible'] as bool,
      topEvidenceWeightShare: (value['top_evidence_weight_share'] as num?)
          ?.toDouble(),
      publicKnownSlotCount: value['public_known_slot_count'] as int,
    );
  }
}

@immutable
class TacticalRecommendationResult {
  const TacticalRecommendationResult({
    required this.available,
    required this.unavailableReason,
    required this.selectedStage,
    required this.scenarios,
    required this.scenarioTotal,
    required this.confidenceGrade,
    required this.calibrationGatePassed,
    required this.recommendations,
    required this.validation,
    required this.warning,
    required this.hiddenSlots,
    required this.ambiguity,
    required this.evidenceSummary,
  });

  /// FE9-b1: 숨은 칸 후보(공개 로비 관측이 없으면 빈 목록), 모호도, 근거 요약.
  final List<TacticalHiddenSlot> hiddenSlots;
  final TacticalRecommendationAmbiguity ambiguity;
  final TacticalEvidenceSummary evidenceSummary;
  final bool available, calibrationGatePassed;
  final String? unavailableReason;
  final int? selectedStage;
  final List<TacticalDefenseScenario> scenarios;
  final int scenarioTotal;
  final String confidenceGrade, warning;
  final List<TacticalAttackRecommendation> recommendations;
  final Map<String, dynamic> validation;

  factory TacticalRecommendationResult.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'filters',
      'availability',
      'selected_stage',
      'fallback_path',
      'evidence_summary',
      'scenarios',
      'scenario_total',
      'hidden_slots',
      'ambiguity',
      'confidence',
      'recommendations',
      'recommendation_total',
      'validation',
      'terminology',
    };
    final availability = value['availability'];
    final confidence = value['confidence'];
    final terminology = value['terminology'];
    if (!_exactV2(value, fields) ||
        value['version'] != 2 ||
        value['filters'] is! Map ||
        availability is! Map ||
        !{'available', 'unavailable'}.contains(availability['status']) ||
        !(availability['reason'] == null || availability['reason'] is String) ||
        !(value['selected_stage'] == null || value['selected_stage'] is int) ||
        value['fallback_path'] is! List ||
        value['evidence_summary'] is! Map ||
        value['scenarios'] is! List ||
        value['scenario_total'] is! int ||
        value['scenario_total'] < 0 ||
        value['hidden_slots'] is! List ||
        value['ambiguity'] is! Map ||
        confidence is! Map ||
        !{
          'high',
          'medium',
          'low',
          'unavailable',
        }.contains(confidence['grade']) ||
        confidence['calibration_gate_passed'] is! bool ||
        value['recommendations'] is! List ||
        value['recommendation_total'] is! int ||
        value['validation'] is! Map ||
        terminology is! Map ||
        terminology['scenario_share_label'] !=
            'evidence_weight_share_not_probability' ||
        terminology['win_rate_label'] != 'observed_win_rate' ||
        terminology['warning'] is! String) {
      throw const FormatException('Invalid tactical recommendation result');
    }
    return TacticalRecommendationResult(
      available: availability['status'] == 'available',
      unavailableReason: availability['reason'] as String?,
      selectedStage: value['selected_stage'] as int?,
      scenarios: List.unmodifiable(
        (value['scenarios'] as List).map(
          (item) => TacticalDefenseScenario.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
      scenarioTotal: value['scenario_total'] as int,
      confidenceGrade: confidence['grade'] as String,
      calibrationGatePassed: confidence['calibration_gate_passed'] as bool,
      recommendations: List.unmodifiable(
        (value['recommendations'] as List).map(
          (item) => TacticalAttackRecommendation.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
      validation: Map.unmodifiable(
        Map<String, dynamic>.from(value['validation'] as Map),
      ),
      warning: terminology['warning'] as String,
      hiddenSlots: List.unmodifiable(
        (value['hidden_slots'] as List).map(
          (item) => TacticalHiddenSlot.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
      ambiguity: TacticalRecommendationAmbiguity.fromWire(
        Map<String, dynamic>.from(value['ambiguity'] as Map),
      ),
      evidenceSummary: TacticalEvidenceSummary.fromWire(
        Map<String, dynamic>.from(value['evidence_summary'] as Map),
      ),
    );
  }
}

@immutable
class TacticalSavedPrediction {
  const TacticalSavedPrediction({
    required this.id,
    required this.asOf,
    required this.stateRevision,
    required this.result,
  });
  final String id, asOf;
  final int stateRevision;
  final TacticalRecommendationResult result;

  factory TacticalSavedPrediction.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'prediction_id',
      'as_of',
      'state_revision',
      'filters',
      'result',
    };
    if (!_exactV2(value, fields) ||
        value['version'] != 2 ||
        !_recordIdV2(value['prediction_id']) ||
        value['as_of'] is! String ||
        value['state_revision'] is! int ||
        value['state_revision'] < 0 ||
        value['filters'] is! Map ||
        value['result'] is! Map) {
      throw const FormatException('Invalid saved tactical prediction');
    }
    _timestampV2(value['as_of'], nullable: false);
    return TacticalSavedPrediction(
      id: value['prediction_id'] as String,
      asOf: value['as_of'] as String,
      stateRevision: value['state_revision'] as int,
      result: TacticalRecommendationResult.fromWire(
        Map<String, dynamic>.from(value['result'] as Map),
      ),
    );
  }
}

@immutable
class TacticalPredictionSaveResult {
  const TacticalPredictionSaveResult({
    required this.revision,
    required this.created,
    required this.prediction,
  });
  final int revision;
  final bool created;
  final TacticalSavedPrediction prediction;

  factory TacticalPredictionSaveResult.fromWire(Map<String, dynamic> value) {
    const fields = {'revision', 'prediction_id', 'created', 'prediction'};
    if (!_exactV2(value, fields) ||
        value['revision'] is! int ||
        value['revision'] < 0 ||
        !_recordIdV2(value['prediction_id']) ||
        value['created'] is! bool ||
        value['prediction'] is! Map) {
      throw const FormatException('Invalid tactical prediction save result');
    }
    final prediction = TacticalSavedPrediction.fromWire(
      Map<String, dynamic>.from(value['prediction'] as Map),
    );
    if (prediction.id != value['prediction_id']) {
      throw const FormatException('Tactical prediction ID mismatch');
    }
    return TacticalPredictionSaveResult(
      revision: value['revision'] as int,
      created: value['created'] as bool,
      prediction: prediction,
    );
  }
}

@immutable
class TacticalShareConsent {
  const TacticalShareConsent({
    required this.scopeId,
    required this.contributorId,
    required this.consentedAt,
  });
  final String scopeId, contributorId, consentedAt;

  Map<String, dynamic> toWire() => {
    'enabled': true,
    'scope_id': scopeId,
    'contributor_id': contributorId,
    'consented_at': consentedAt,
    'include_original_media': false,
  };
}

@immutable
class TacticalSharePayload {
  const TacticalSharePayload(this.wire);
  final Map<String, dynamic> wire;
  String get id => wire['share_id'] as String;
  String get scopeId => wire['scope_id'] as String;
  String get contributorId => wire['contributor_id'] as String;
  int get attemptIndex => wire['attempt_index'] as int;

  factory TacticalSharePayload.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'share_id',
      'scope_id',
      'contributor_id',
      'consent_scope',
      'consented_at',
      'shared_at',
      'occurred_at',
      'attempt_session_id',
      'attempt_index',
      'defense_snapshot_id',
      'anonymous_opponent_id',
      'season',
      'patch',
      'map',
      'rank_difference',
      'public_signature',
      'defense_signature',
      'attack_signature',
      'result',
      'source_identity',
      'source_type',
    };
    if (!_exactV2(value, fields) ||
        value['version'] != 1 ||
        ![
          'share_id',
          'scope_id',
          'contributor_id',
          'consent_scope',
          'attempt_session_id',
          'defense_snapshot_id',
          'anonymous_opponent_id',
          'source_identity',
        ].every((key) => _recordIdV2(value[key])) ||
        value['scope_id'] != value['consent_scope'] ||
        ![
          'consented_at',
          'shared_at',
          'occurred_at',
        ].every((key) => _timestampV2(value[key], nullable: false) != null) ||
        value['attempt_index'] is! int ||
        value['attempt_index'] < 1 ||
        value['rank_difference'] is! int ||
        ![
          'season',
          'patch',
          'map',
          'public_signature',
          'defense_signature',
          'attack_signature',
        ].every(
          (key) => value[key] is String && (value[key] as String).isNotEmpty,
        ) ||
        !{'win', 'loss'}.contains(value['result']) ||
        !{
          'v6_import',
          'manual',
          'battle_result',
          'community_report',
        }.contains(value['source_type'])) {
      throw const FormatException('Invalid tactical share payload');
    }
    return TacticalSharePayload(Map.unmodifiable(value));
  }

  Map<String, dynamic> toWire() => Map<String, dynamic>.from(wire);
}

@immutable
class TacticalSharePrepareResult {
  const TacticalSharePrepareResult({
    required this.share,
    required this.redaction,
  });
  final TacticalSharePayload share;
  final Map<String, dynamic> redaction;

  factory TacticalSharePrepareResult.fromWire(Map<String, dynamic> value) {
    if (!_exactV2(value, {'share', 'redaction'}) ||
        value['share'] is! Map ||
        value['redaction'] is! Map) {
      throw const FormatException('Invalid tactical share prepare result');
    }
    final redaction = Map<String, dynamic>.from(value['redaction'] as Map);
    const fields = {
      'original_media_included',
      'local_identity_included',
      'name_or_roi_included',
      'prediction_included',
    };
    if (!_exactV2(redaction, fields) ||
        redaction.values.any((item) => item is! bool || item)) {
      throw const FormatException('Tactical share redaction boundary failed');
    }
    return TacticalSharePrepareResult(
      share: TacticalSharePayload.fromWire(
        Map<String, dynamic>.from(value['share'] as Map),
      ),
      redaction: Map.unmodifiable(redaction),
    );
  }
}

@immutable
class TacticalShareState {
  const TacticalShareState({
    required this.revision,
    required this.records,
    required this.tombstoneCount,
    required this.aggregateCache,
  });
  final int revision, tombstoneCount;
  final List<TacticalSharePayload> records;
  final Map<String, dynamic> aggregateCache;

  factory TacticalShareState.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'profile_id',
      'revision',
      'records',
      'tombstones',
      'aggregate_cache',
    };
    if (!_exactV2(value, fields) ||
        value['version'] != 1 ||
        value['revision'] is! int ||
        value['revision'] < 0 ||
        value['records'] is! List ||
        value['tombstones'] is! List ||
        value['aggregate_cache'] is! Map) {
      throw const FormatException('Invalid tactical share state');
    }
    return TacticalShareState(
      revision: value['revision'] as int,
      records: List.unmodifiable(
        (value['records'] as List).map(
          (item) => TacticalSharePayload.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
      tombstoneCount: (value['tombstones'] as List).length,
      aggregateCache: Map.unmodifiable(
        Map<String, dynamic>.from(value['aggregate_cache'] as Map),
      ),
    );
  }
}

@immutable
class TacticalShareMutationResult {
  const TacticalShareMutationResult(this.wire);
  final Map<String, dynamic> wire;
  int get revision => wire['revision'] as int;
  int get imported => wire['imported'] as int? ?? 0;
  int get withdrawn => wire['withdrawn'] as int? ?? 0;
  int get activeRecordCount =>
      (wire['aggregate_cache'] as Map)['active_record_count'] as int;

  factory TacticalShareMutationResult.fromWire(Map<String, dynamic> value) {
    if (value['revision'] is! int ||
        value['revision'] < 0 ||
        value['aggregate_cache'] is! Map) {
      throw const FormatException('Invalid tactical share mutation result');
    }
    return TacticalShareMutationResult(Map.unmodifiable(value));
  }
}

@immutable
class TacticalShareAnalyticsFilters {
  const TacticalShareAnalyticsFilters({
    required this.scopeId,
    required this.asOf,
    this.season,
    this.patch,
    this.map,
    this.publicSignature,
    this.defenseSignature,
    this.rankDifferenceMin,
    this.rankDifferenceMax,
    this.minIndependentContributors = 2,
    this.minIndependentOpponents = 2,
    this.limit = 20,
  });
  final String scopeId, asOf;
  final String? season, patch, map, publicSignature, defenseSignature;
  final int? rankDifferenceMin, rankDifferenceMax;
  final int minIndependentContributors, minIndependentOpponents, limit;

  Map<String, dynamic> toWire() => {
    'scope_id': scopeId,
    'season': season,
    'patch': patch,
    'map': map,
    'public_signature': publicSignature,
    'defense_signature': defenseSignature,
    'rank_difference_min': rankDifferenceMin,
    'rank_difference_max': rankDifferenceMax,
    'as_of': asOf,
    'min_independent_contributors': minIndependentContributors,
    'min_independent_opponents': minIndependentOpponents,
    'limit': limit,
  };
}

@immutable
class TacticalShareAnalyticsResult {
  const TacticalShareAnalyticsResult({
    required this.population,
    required this.privacy,
    required this.groups,
    required this.substitutions,
    required this.mlImplemented,
    required this.warning,
  });
  final Map<String, dynamic> population, privacy;
  final List<Map<String, dynamic>> groups, substitutions;
  final bool mlImplemented;
  final String warning;

  factory TacticalShareAnalyticsResult.fromWire(Map<String, dynamic> value) {
    const fields = {
      'version',
      'filters',
      'population',
      'privacy',
      'groups',
      'one_slot_substitutions',
      'revalidation',
      'terminology',
      'ml',
    };
    if (!_exactV2(value, fields) ||
        value['version'] != 1 ||
        value['population'] is! Map ||
        value['privacy'] is! Map ||
        value['groups'] is! List ||
        value['one_slot_substitutions'] is! List ||
        value['ml'] is! Map ||
        value['terminology'] is! Map) {
      throw const FormatException('Invalid tactical share analytics');
    }
    final ml = Map<String, dynamic>.from(value['ml'] as Map);
    final terminology = Map<String, dynamic>.from(value['terminology'] as Map);
    if (ml['implemented'] is! bool || terminology['warning'] is! String) {
      throw const FormatException('Invalid tactical share analytics semantics');
    }
    return TacticalShareAnalyticsResult(
      population: Map.unmodifiable(
        Map<String, dynamic>.from(value['population'] as Map),
      ),
      privacy: Map.unmodifiable(
        Map<String, dynamic>.from(value['privacy'] as Map),
      ),
      groups: List.unmodifiable(
        (value['groups'] as List).map(
          (item) => Map<String, dynamic>.unmodifiable(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
      substitutions: List.unmodifiable(
        (value['one_slot_substitutions'] as List).map(
          (item) => Map<String, dynamic>.unmodifiable(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
      mlImplemented: ml['implemented'] as bool,
      warning: terminology['warning'] as String,
    );
  }
}

// FB-6: 전술 v2 기록·족보 쓰기와 명시적 v7-v1 이관(contracts/tactical-protocol-v2.schema.json `fb6*`,
// contracts/README.md "FB-6a tactical v2 writes and explicit v7-v1 migration").
// FB-6b(FD-176, README "FB-6b FD-176 unknown attempts and anonymous defense"): 기록 입력·읽기의 `attempt_count`는
// null(모름) 또는 양의 정수, 방어 기록만 상대 identity·이름 null 쌍을 허용한다.

bool _validFb6DeckV2(Object? raw) {
  if (raw is! Map) return false;
  try {
    TacticalDeckV2.fromWire(Map<String, dynamic>.from(raw));
    return true;
  } catch (_) {
    return false;
  }
}

bool _validFb6MatchInputV2(Object? raw) {
  if (raw is! Map) return false;
  final value = Map<String, dynamic>.from(raw);
  const fields = {
    'version',
    'match_id',
    'kind',
    'occurred_at',
    'occurred_precision',
    'season',
    'opponent_identity_id',
    'opponent_display_name',
    'result',
    'attack_deck',
    'defense_deck',
    'notes',
    'attempt_count',
  };
  final precision = value['occurred_precision'];
  final attempt = value['attempt_count'];
  try {
    return _exactV2(value, fields) &&
        value['version'] == 2 &&
        _recordIdV2(value['match_id']) &&
        {'attack', 'defense'}.contains(value['kind']) &&
        _occurredPrecisionsV2.contains(precision) &&
        (precision == 'unknown'
            ? value['occurred_at'] == null
            : _timestampV2(value['occurred_at'], nullable: false) != null) &&
        value['season'] is String &&
        _validOpponentPairV2(value) &&
        {'win', 'loss'}.contains(value['result']) &&
        _validFb6DeckV2(value['attack_deck']) &&
        _validFb6DeckV2(value['defense_deck']) &&
        value['notes'] is String &&
        // FD-176: 키는 required(위 exact 검사), 값은 null(모름) 또는 양의 정수. 0·bool·음수·실수·문자열은 거부.
        (attempt == null || (attempt is int && attempt >= 1));
  } catch (_) {
    return false;
  }
}

bool _validFb6JokboInputV2(Object? raw) {
  if (raw is! Map) return false;
  final value = Map<String, dynamic>.from(raw);
  return _exactV2(value, {
        'version',
        'jokbo_id',
        'name',
        'attack_deck',
        'defense_deck',
        'notes',
      }) &&
      value['version'] == 2 &&
      _recordIdV2(value['jokbo_id']) &&
      value['name'] is String &&
      (value['name'] as String).isNotEmpty &&
      _validFb6DeckV2(value['attack_deck']) &&
      _validFb6DeckV2(value['defense_deck']) &&
      value['notes'] is String;
}

/// `date` 정밀도는 KST 자정 표기만 받는다(백엔드 `request_match`와 같다).
bool _kstMidnightV2(String value) =>
    RegExp(r'^\d{4}-\d{2}-\d{2}T00:00(:00(\.0+)?)?\+09:00$').hasMatch(value) &&
    DateTime.tryParse(value) != null;

/// FB-6 `fb6MatchInput`(13키). read DTO의 backend 소유 audit/created/import/source 필드
/// (`observed_at`·`imported_at`·`created_at`·`source`·`source_label`·`import_batch_id`·`source_record_id`·
/// `confidence`·`review_status`)는 넣지 않는다.
@immutable
class TacticalMatchInputV2 {
  TacticalMatchInputV2({
    required this.id,
    required this.kind,
    required this.occurredAt,
    required this.occurredPrecision,
    required this.season,
    required this.opponentIdentityId,
    required this.opponentDisplayName,
    required this.result,
    required this.attackDeck,
    required this.defenseDeck,
    required this.notes,
    required this.attemptCount,
  }) {
    if (!_validFb6MatchInputV2(toWire()) ||
        (occurredPrecision == 'date' && !_kstMidnightV2(occurredAt!))) {
      throw const FormatException('Invalid tactical v2 match input');
    }
  }

  /// 읽은 기록에서 입력 13키만 옮긴다. [attemptCount]를 주면 그 값으로 바꾸고, 주지 않으면 기록 값을 그대로 둔다
  /// (FD-176: 모르는 시도 횟수 null은 null 그대로 보낸다 — 1로 채우지 않는다). 아는 값을 '모름'으로 바꾸려면
  /// 생성자에 `attemptCount: null`을 직접 넘긴다. 키가 없던 정밀도(`unknown`인데 시각이 있음)는 추측하지 않으므로
  /// [occurredPrecision]을 직접 넘겨야 한다.
  factory TacticalMatchInputV2.fromRecord(
    TacticalMatchV2 record, {
    int? attemptCount,
    String? occurredPrecision,
  }) {
    final count = attemptCount ?? record.attemptCount;
    return TacticalMatchInputV2(
      id: record.id,
      kind: record.kind,
      occurredAt: record.occurredAt,
      occurredPrecision: occurredPrecision ?? record.occurredPrecision,
      season: record.season,
      opponentIdentityId: record.opponentIdentityId,
      opponentDisplayName: record.opponentDisplayName,
      result: record.result,
      attackDeck: record.attackDeck,
      defenseDeck: record.defenseDeck,
      notes: record.notes,
      attemptCount: count,
    );
  }

  /// FB-7 미리보기 행의 `match`(`fb6MatchInput` 13키)를 그대로 받는다.
  factory TacticalMatchInputV2.fromWire(Map<String, dynamic> value) {
    if (!_validFb6MatchInputV2(value)) {
      throw const FormatException('Invalid tactical v2 match input');
    }
    TacticalDeckV2 deck(String key) =>
        TacticalDeckV2.fromWire(Map<String, dynamic>.from(value[key] as Map));
    return TacticalMatchInputV2(
      id: value['match_id'] as String,
      kind: value['kind'] as String,
      occurredAt: value['occurred_at'] as String?,
      occurredPrecision: value['occurred_precision'] as String,
      season: value['season'] as String,
      opponentIdentityId: value['opponent_identity_id'] as String?,
      opponentDisplayName: value['opponent_display_name'] as String?,
      result: value['result'] as String,
      attackDeck: deck('attack_deck'),
      defenseDeck: deck('defense_deck'),
      notes: value['notes'] as String,
      attemptCount: value['attempt_count'] as int?,
    );
  }

  final String id, kind, occurredPrecision, season;
  final String result, notes;

  /// FD-176: 방어 기록에 한해 둘 다 null(상대 모름). 공격 기록·한쪽만 null·빈 문자열은 생성자가 거부한다.
  final String? opponentIdentityId, opponentDisplayName;
  final String? occurredAt;
  final TacticalDeckV2 attackDeck, defenseDeck;

  /// FD-176: null = 모름(키는 늘 보낸다), 아니면 1 이상.
  final int? attemptCount;

  Map<String, dynamic> toWire() => {
    'version': 2,
    'match_id': id,
    'kind': kind,
    'occurred_at': occurredAt,
    'occurred_precision': occurredPrecision,
    'season': season,
    'opponent_identity_id': opponentIdentityId,
    'opponent_display_name': opponentDisplayName,
    'result': result,
    'attack_deck': attackDeck.toWire(),
    'defense_deck': defenseDeck.toWire(),
    'notes': notes,
    'attempt_count': attemptCount,
  };
}

/// FB-6 `fb6JokboInput`(6키). 승패 수·출처·생성 시각은 백엔드가 보존한다.
@immutable
class TacticalJokboInputV2 {
  TacticalJokboInputV2({
    required this.id,
    required this.name,
    required this.attackDeck,
    required this.defenseDeck,
    required this.notes,
  }) {
    if (!_validFb6JokboInputV2(toWire())) {
      throw const FormatException('Invalid tactical v2 jokbo input');
    }
  }
  final String id, name, notes;
  final TacticalDeckV2 attackDeck, defenseDeck;

  Map<String, dynamic> toWire() => {
    'version': 2,
    'jokbo_id': id,
    'name': name,
    'attack_deck': attackDeck.toWire(),
    'defense_deck': defenseDeck.toWire(),
    'notes': notes,
  };
}

int _revisionV2(Map<String, dynamic> value) {
  final revision = value['revision'];
  if (revision is! int || revision < 0) {
    throw const FormatException('Invalid tactical v2 revision');
  }
  return revision;
}

@immutable
class TacticalMatchUpsertResult {
  const TacticalMatchUpsertResult({
    required this.revision,
    required this.match,
    required this.jokboIds,
  });
  final int revision;
  final TacticalMatchV2 match;

  /// 이 기록에서 자동 도출된 족보 ID(공격 기록만, 없으면 빈 목록).
  final List<String> jokboIds;

  factory TacticalMatchUpsertResult.fromWire(Map<String, dynamic> value) {
    final ids = value['jokbo_ids'];
    if (!_exactV2(value, {'revision', 'match', 'jokbo_ids'}) ||
        value['match'] is! Map ||
        ids is! List ||
        !ids.every(_recordIdV2) ||
        ids.toSet().length != ids.length) {
      throw const FormatException('Invalid tactical v2 match upsert result');
    }
    return TacticalMatchUpsertResult(
      revision: _revisionV2(value),
      match: TacticalMatchV2.fromWire(
        Map<String, dynamic>.from(value['match'] as Map),
      ),
      jokboIds: List.unmodifiable(ids.cast<String>()),
    );
  }
}

@immutable
class TacticalMatchDeleteResult {
  const TacticalMatchDeleteResult({
    required this.revision,
    required this.matchId,
  });
  final int revision;
  final String matchId;

  factory TacticalMatchDeleteResult.fromWire(Map<String, dynamic> value) {
    if (!_exactV2(value, {'revision', 'match_id'}) ||
        !_recordIdV2(value['match_id'])) {
      throw const FormatException('Invalid tactical v2 match delete result');
    }
    return TacticalMatchDeleteResult(
      revision: _revisionV2(value),
      matchId: value['match_id'] as String,
    );
  }
}

@immutable
class TacticalJokboUpsertResult {
  const TacticalJokboUpsertResult({
    required this.revision,
    required this.jokbo,
  });
  final int revision;
  final TacticalJokboV2 jokbo;

  factory TacticalJokboUpsertResult.fromWire(Map<String, dynamic> value) {
    if (!_exactV2(value, {'revision', 'jokbo'}) || value['jokbo'] is! Map) {
      throw const FormatException('Invalid tactical v2 jokbo upsert result');
    }
    return TacticalJokboUpsertResult(
      revision: _revisionV2(value),
      jokbo: TacticalJokboV2.fromWire(
        Map<String, dynamic>.from(value['jokbo'] as Map),
      ),
    );
  }
}

@immutable
class TacticalJokboDeleteResult {
  const TacticalJokboDeleteResult({
    required this.revision,
    required this.jokboId,
  });
  final int revision;
  final String jokboId;

  factory TacticalJokboDeleteResult.fromWire(Map<String, dynamic> value) {
    if (!_exactV2(value, {'revision', 'jokbo_id'}) ||
        !_recordIdV2(value['jokbo_id'])) {
      throw const FormatException('Invalid tactical v2 jokbo delete result');
    }
    return TacticalJokboDeleteResult(
      revision: _revisionV2(value),
      jokboId: value['jokbo_id'] as String,
    );
  }
}

/// v7-v1 이관 미리보기의 변환 문제. 하나라도 있으면 commit이 `import_review_required`로 전부 거부된다.
@immutable
class TacticalLegacyIssue {
  const TacticalLegacyIssue({
    required this.recordKind,
    required this.recordId,
    required this.code,
    required this.message,
  });
  final String recordKind, recordId, code, message;

  factory TacticalLegacyIssue.fromWire(Map<String, dynamic> value) {
    if (!_exactV2(value, {'record_kind', 'record_id', 'code', 'message'}) ||
        !{'match', 'jokbo'}.contains(value['record_kind']) ||
        value['record_id'] is! String ||
        (value['record_id'] as String).isEmpty ||
        value['code'] is! String ||
        (value['code'] as String).isEmpty ||
        value['message'] is! String) {
      throw const FormatException('Invalid tactical legacy issue');
    }
    return TacticalLegacyIssue(
      recordKind: value['record_kind'] as String,
      recordId: value['record_id'] as String,
      code: value['code'] as String,
      message: value['message'] as String,
    );
  }
}

@immutable
class TacticalLegacyPreview {
  const TacticalLegacyPreview({
    required this.sourceRevision,
    required this.sourceFingerprint,
    required this.matchCount,
    required this.jokboCount,
    required this.issues,
    required this.v1WritesDisabled,
  });

  /// commit 요청에는 `expected_source_revision`·`expected_fingerprint`로 넣는다.
  final int sourceRevision;
  final String sourceFingerprint;
  final int matchCount, jokboCount;
  final List<TacticalLegacyIssue> issues;

  /// 이미 v2가 유일한 쓰기 저장소다(이관 완료 또는 빈 v1 claim). 이관을 다시 제안하지 않는다.
  final bool v1WritesDisabled;

  factory TacticalLegacyPreview.fromWire(Map<String, dynamic> value) {
    const fields = {
      'source_revision',
      'source_fingerprint',
      'match_count',
      'jokbo_count',
      'issues',
      'v1_writes_disabled',
    };
    final issues = value['issues'];
    if (!_exactV2(value, fields) ||
        [
          value['source_revision'],
          value['match_count'],
          value['jokbo_count'],
        ].any((item) => item is! int || item < 0) ||
        !_sha256V2(value['source_fingerprint']) ||
        issues is! List ||
        value['v1_writes_disabled'] is! bool) {
      throw const FormatException('Invalid tactical legacy preview');
    }
    return TacticalLegacyPreview(
      sourceRevision: value['source_revision'] as int,
      sourceFingerprint: value['source_fingerprint'] as String,
      matchCount: value['match_count'] as int,
      jokboCount: value['jokbo_count'] as int,
      issues: List.unmodifiable(
        issues.map(
          (item) => TacticalLegacyIssue.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
      v1WritesDisabled: value['v1_writes_disabled'] as bool,
    );
  }
}

@immutable
class TacticalLegacyCommitResult {
  const TacticalLegacyCommitResult({
    required this.revision,
    required this.importedMatches,
    required this.importedJokbo,
    required this.v1WritesDisabled,
  });
  final int revision, importedMatches, importedJokbo;

  /// 계약상 항상 true(이관 뒤 v1 새 쓰기는 `tactical_v1_read_only`).
  final bool v1WritesDisabled;

  factory TacticalLegacyCommitResult.fromWire(Map<String, dynamic> value) {
    const fields = {
      'revision',
      'imported_matches',
      'imported_jokbo',
      'v1_writes_disabled',
    };
    if (!_exactV2(value, fields) ||
        [
          value['imported_matches'],
          value['imported_jokbo'],
        ].any((item) => item is! int || item < 0) ||
        value['v1_writes_disabled'] != true) {
      throw const FormatException('Invalid tactical legacy commit result');
    }
    return TacticalLegacyCommitResult(
      revision: _revisionV2(value),
      importedMatches: value['imported_matches'] as int,
      importedJokbo: value['imported_jokbo'] as int,
      v1WritesDisabled: true,
    );
  }
}

// FB-7: 전술 엑셀·UTF-8 CSV 가져오기(contracts/tactical-protocol-v2.schema.json `excel*`, contracts/README.md
// "FB7 Excel / UTF-8 CSV import"). Flutter는 파일을 읽지 않는다 — 경로와 명시적 선택만 보내고 해석·지문은 백엔드가
// 만든다. 후보 매핑·저장된 매핑·제안(suggestion)은 사용자가 확인해 요청에 넣기 전까지 적용되지 않는다.

/// 스칼라 의미 필드 7.
const tacticalExcelScalarFields = <String>[
  'date',
  'kind',
  'opponent',
  'season',
  'result',
  'attempts',
  'notes',
];

/// 슬롯 의미 필드 12(내 덱 `own_*` · 상대 덱 `opponent_*`, 위치는 1부터). 빈 슬롯은 모름으로 남고, 와일드카드는
/// 명시 resolution(`wildcard`)으로만 생긴다.
const tacticalExcelSlotFields = <String>[
  'own_striker_1',
  'own_striker_2',
  'own_striker_3',
  'own_striker_4',
  'own_special_1',
  'own_special_2',
  'opponent_striker_1',
  'opponent_striker_2',
  'opponent_striker_3',
  'opponent_striker_4',
  'opponent_special_1',
  'opponent_special_2',
];

const tacticalExcelFields = <String>[
  ...tacticalExcelScalarFields,
  ...tacticalExcelSlotFields,
];

/// 확정 매핑에 반드시 있어야 하는 필드(날짜·결과·양수 시도 횟수는 행마다 풀려야 하고 now·1·0으로 채우지 않는다).
const tacticalExcelRequiredFields = <String>{
  'date',
  'kind',
  'opponent',
  'result',
  'attempts',
};

const _excelResolutionActionsV2 = {
  'value',
  'wildcard',
  'notes',
  'ignore',
  'skip',
};
const _excelRowActionsV2 = {'skip', 'keep_separate', 'overwrite'};
const _excelOnConflictV2 = {'skip', 'overwrite'};
const _excelRowStatusesV2 = {
  'empty',
  'skipped',
  'unresolved',
  'eligible',
  'overwrite',
  'conflict',
  'conflict_skipped',
  'replay',
};
const _excelChoiceKeysV2 = {
  'profile_id',
  'source_path',
  'sheet_name',
  'delimiter',
  'column_mapping',
  'resolutions',
  'row_decisions',
  'on_conflict',
};
const _excelCommitKeysV2 = {
  'save_rules',
  'expected_fingerprint',
  'expected_interpretation_fingerprint',
  'expected_revision',
  'idempotency_key',
};

bool _profileIdV2(Object? value) =>
    value is String && RegExp(r'^[0-9a-f]{24}$').stringMatch(value) == value;

bool _excelColumnV2(Object? value) => value is int && value >= 1 && value <= 64;

bool _excelRowNumberV2(Object? value) =>
    value is int && value >= 1 && value <= 10000;

/// 셀 값(문자열·수·불리언·null). 날짜·시각 셀은 백엔드가 ISO 문자열로 준다.
bool _excelScalarV2(Object? value) =>
    value == null || value is String || value is num || value is bool;

bool _excelIdV2(String prefix, Object? value) =>
    value is String &&
    RegExp('^$prefix-[0-9a-f]{32}\$').stringMatch(value) == value;

List<T> _excelListV2<T>(Object? raw, T Function(Map<String, dynamic>) item) {
  if (raw is! List) {
    throw const FormatException('Invalid tactical Excel list');
  }
  return List.unmodifiable(
    raw.map((entry) => item(Map<String, dynamic>.from(entry as Map))),
  );
}

/// `excelColumns`(필드 → 1부터 센 열). [mapping]이면 필수 5필드와 한 열 = 한 필드(백엔드 `validate_mapping`).
Map<String, int> _excelColumnsV2(Object? raw, {required bool mapping}) {
  if (raw is! Map) {
    throw const FormatException('Invalid tactical Excel columns');
  }
  final columns = Map<String, dynamic>.from(raw);
  if (!tacticalExcelFields.toSet().containsAll(columns.keys) ||
      !columns.values.every(_excelColumnV2) ||
      (mapping &&
          (!columns.keys.toSet().containsAll(tacticalExcelRequiredFields) ||
              columns.values.toSet().length != columns.length))) {
    throw const FormatException('Invalid tactical Excel columns');
  }
  return Map<String, int>.unmodifiable(columns.cast<String, int>());
}

/// 사용자가 확인한 열 매핑(`excelMapping`). 후보(`mapping_candidates`)·저장된 매핑(`saved_mapping`)을 쓰려면 확인한 뒤
/// 이 값으로 요청에 넣는다.
@immutable
class TacticalExcelColumnMapping {
  TacticalExcelColumnMapping({
    required this.headerRow,
    required Map<String, int> columns,
  }) : columns = _excelColumnsV2(columns, mapping: true) {
    if (!_excelRowNumberV2(headerRow)) {
      throw const FormatException('Invalid tactical Excel header row');
    }
  }

  /// 머리글 행(1부터). 데이터는 그 아래 행부터 읽는다.
  final int headerRow;

  /// 의미 필드([tacticalExcelFields]) → 1부터 센 열.
  final Map<String, int> columns;

  factory TacticalExcelColumnMapping.fromWire(Map<String, dynamic> value) {
    if (!_exactV2(value, {'header_row', 'columns'}) ||
        value['header_row'] is! int) {
      throw const FormatException('Invalid tactical Excel column mapping');
    }
    return TacticalExcelColumnMapping(
      headerRow: value['header_row'] as int,
      columns: _excelColumnsV2(value['columns'], mapping: true),
    );
  }

  Map<String, dynamic> toWire() => {
    'header_row': headerRow,
    'columns': {...columns},
  };
}

bool _validExcelMappingV2(Object? raw) {
  if (raw is! Map) return false;
  try {
    TacticalExcelColumnMapping.fromWire(Map<String, dynamic>.from(raw));
    return true;
  } catch (_) {
    return false;
  }
}

/// resolution `value`: 문자열(학생 ID·기존 상대 ID·결과·종류·날짜 같은 해석 값) · 정수(시도 횟수) · 새 상대
/// `{identity_id, display_name}`. 별칭·유사 이름은 제안일 뿐이라 사용자가 고른 값만 넣는다.
sealed class TacticalExcelResolutionValue {
  const TacticalExcelResolutionValue();

  Object toWire();

  static TacticalExcelResolutionValue? fromWire(Object? raw) {
    if (raw == null) return null;
    if (raw is String) return TacticalExcelTextValue(raw);
    if (raw is int) return TacticalExcelIntegerValue(raw);
    if (raw is Map) {
      final value = Map<String, dynamic>.from(raw);
      if (_exactV2(value, {'identity_id', 'display_name'}) &&
          value['identity_id'] is String &&
          value['display_name'] is String) {
        return TacticalExcelNewOpponentValue(
          identityId: value['identity_id'] as String,
          displayName: value['display_name'] as String,
        );
      }
    }
    throw const FormatException('Invalid tactical Excel resolution value');
  }
}

final class TacticalExcelTextValue extends TacticalExcelResolutionValue {
  const TacticalExcelTextValue(this.text);
  final String text;

  @override
  Object toWire() => text;
}

final class TacticalExcelIntegerValue extends TacticalExcelResolutionValue {
  const TacticalExcelIntegerValue(this.value);
  final int value;

  @override
  Object toWire() => value;
}

/// 명시적으로 새로 만드는 상대 identity. 기존 identity에 다른 이름을 붙이면 `opponent_alias_required`다.
final class TacticalExcelNewOpponentValue extends TacticalExcelResolutionValue {
  TacticalExcelNewOpponentValue({
    required this.identityId,
    required this.displayName,
  }) {
    if (!_recordIdV2(identityId) || displayName.isEmpty) {
      throw const FormatException('Invalid tactical Excel opponent value');
    }
  }
  final String identityId, displayName;

  @override
  Object toWire() => {'identity_id': identityId, 'display_name': displayName};
}

/// `value` 행동은 null도 받는다(빈 슬롯 = 모름, 빈 메모). 형식 밖 값은 fromWire가 거부한다.
bool _validExcelResolutionValueV2(Object? raw) {
  try {
    TacticalExcelResolutionValue.fromWire(raw);
    return true;
  } catch (_) {
    return false;
  }
}

bool _validExcelResolutionV2(Object? raw) {
  if (raw is! Map) return false;
  final value = Map<String, dynamic>.from(raw);
  const required = {'field', 'raw', 'action', 'value'};
  final keys = value.keys.toSet();
  final field = value['field'];
  final action = value['action'];
  final resolved = value['value'];
  if (!keys.containsAll(required) || !{...required, 'row'}.containsAll(keys)) {
    return false;
  }
  try {
    return tacticalExcelFields.contains(field) &&
        value['raw'] is String &&
        utf8.encode(value['raw'] as String).length <= 8192 &&
        _excelResolutionActionsV2.contains(action) &&
        (action != 'wildcard' || tacticalExcelSlotFields.contains(field)) &&
        (action == 'value'
            ? _validExcelResolutionValueV2(resolved)
            : resolved == null) &&
        (!keys.contains('row') || _excelRowNumberV2(value['row']));
  } catch (_) {
    return false;
  }
}

/// 미리보기의 문자열 그룹·행 이슈에 대한 사용자 결정(`excelResolution`). [raw]는 미리보기가 준 typed `raw_key`
/// 그대로다. [row]가 없으면 그 필드·원값 전체에 적용되고(commit의 `save_rules`로 프로필 규칙이 될 수 있다), 있으면
/// 그 행에만 적용된다. `skip` 행동·행별 결정은 규칙으로 저장되지 않는다.
@immutable
class TacticalExcelResolution {
  TacticalExcelResolution({
    required this.field,
    required this.raw,
    required this.action,
    required this.value,
    this.row,
  }) {
    if (!_validExcelResolutionV2(toWire())) {
      throw const FormatException('Invalid tactical Excel resolution');
    }
  }

  final String field, raw;

  /// `value`·`wildcard`(슬롯만)·`notes`·`ignore`·`skip`. `value` 밖의 행동은 [value]가 null이다.
  final String action;
  final TacticalExcelResolutionValue? value;
  final int? row;

  factory TacticalExcelResolution.fromWire(Map<String, dynamic> value) {
    if (!_validExcelResolutionV2(value)) {
      throw const FormatException('Invalid tactical Excel resolution');
    }
    return TacticalExcelResolution(
      field: value['field'] as String,
      raw: value['raw'] as String,
      action: value['action'] as String,
      value: TacticalExcelResolutionValue.fromWire(value['value']),
      row: value['row'] as int?,
    );
  }

  Map<String, dynamic> toWire() => {
    'field': field,
    'raw': raw,
    'action': action,
    'value': value?.toWire(),
    if (row != null) 'row': row,
  };
}

bool _validExcelRowDecisionV2(Object? raw) {
  if (raw is! Map) return false;
  final value = Map<String, dynamic>.from(raw);
  final target = value['target_match_id'];
  return _exactV2(value, {'row', 'action', 'target_match_id'}) &&
      _excelRowNumberV2(value['row']) &&
      _excelRowActionsV2.contains(value['action']) &&
      (value['action'] == 'overwrite' ? _recordIdV2(target) : target == null);
}

/// 행 결정(`excelRowDecision`): `skip`·`keep_separate`·`overwrite`. 덮어쓰기는 실제로 충돌한 기록 ID가 있어야 한다.
@immutable
class TacticalExcelRowDecision {
  TacticalExcelRowDecision({
    required this.row,
    required this.action,
    required this.targetMatchId,
  }) {
    if (!_validExcelRowDecisionV2(toWire())) {
      throw const FormatException('Invalid tactical Excel row decision');
    }
  }
  final int row;
  final String action;
  final String? targetMatchId;

  factory TacticalExcelRowDecision.fromWire(Map<String, dynamic> value) {
    if (!_validExcelRowDecisionV2(value)) {
      throw const FormatException('Invalid tactical Excel row decision');
    }
    return TacticalExcelRowDecision(
      row: value['row'] as int,
      action: value['action'] as String,
      targetMatchId: value['target_match_id'] as String?,
    );
  }

  Map<String, dynamic> toWire() => {
    'row': row,
    'action': action,
    'target_match_id': targetMatchId,
  };
}

/// 미리보기·commit 공통 선택 8키. 같은 (행, 필드, 원값) resolution과 같은 행 결정은 두 번 넣지 않는다(백엔드
/// `invalid_payload`와 같은 검사).
bool _validExcelChoicesV2(Map<String, dynamic> payload) {
  final sheet = payload['sheet_name'];
  final mapping = payload['column_mapping'];
  final resolutions = payload['resolutions'];
  final decisions = payload['row_decisions'];
  if (!_profileIdV2(payload['profile_id']) ||
      payload['source_path'] is! String ||
      (payload['source_path'] as String).isEmpty ||
      (sheet != null && (sheet is! String || sheet.isEmpty)) ||
      !{',', '\t'}.contains(payload['delimiter']) ||
      (mapping != null && !_validExcelMappingV2(mapping)) ||
      resolutions is! List ||
      resolutions.length > 4096 ||
      !resolutions.every(_validExcelResolutionV2) ||
      decisions is! List ||
      decisions.length > 10000 ||
      !decisions.every(_validExcelRowDecisionV2) ||
      !_excelOnConflictV2.contains(payload['on_conflict'])) {
    return false;
  }
  final identities = {
    for (final item in resolutions)
      jsonEncode([(item as Map)['row'], item['field'], item['raw']]),
  };
  final rows = {for (final item in decisions) (item as Map)['row']};
  return identities.length == resolutions.length &&
      rows.length == decisions.length;
}

/// FB-7 미리보기·commit 공통 선택(`excelPreviewRequest` payload). [sheetName]은 null(첫 보이는 시트·CSV) 또는 정확한
/// 이름, [delimiter]는 쉼표·탭(CSV에만 의미), [columnMapping]이 null이면 미리보기는 후보만 주고
/// `mapping_confirmation_required` 이슈를 낸다. [onConflict]는 `skip`·`overwrite`.
@immutable
class TacticalExcelImportChoices {
  TacticalExcelImportChoices({
    required this.profileId,
    required this.sourcePath,
    required this.sheetName,
    required this.delimiter,
    required this.columnMapping,
    required List<TacticalExcelResolution> resolutions,
    required List<TacticalExcelRowDecision> rowDecisions,
    required this.onConflict,
  }) : resolutions = List.unmodifiable(resolutions),
       rowDecisions = List.unmodifiable(rowDecisions) {
    if (!_validExcelChoicesV2(toWire())) {
      throw const FormatException('Invalid tactical Excel import choices');
    }
  }

  final String profileId, sourcePath, delimiter, onConflict;
  final String? sheetName;
  final TacticalExcelColumnMapping? columnMapping;
  final List<TacticalExcelResolution> resolutions;
  final List<TacticalExcelRowDecision> rowDecisions;

  factory TacticalExcelImportChoices.fromWire(Map<String, dynamic> value) {
    if (!_exactV2(value, _excelChoiceKeysV2) || !_validExcelChoicesV2(value)) {
      throw const FormatException('Invalid tactical Excel import choices');
    }
    final mapping = value['column_mapping'];
    return TacticalExcelImportChoices(
      profileId: value['profile_id'] as String,
      sourcePath: value['source_path'] as String,
      sheetName: value['sheet_name'] as String?,
      delimiter: value['delimiter'] as String,
      columnMapping: mapping == null
          ? null
          : TacticalExcelColumnMapping.fromWire(
              Map<String, dynamic>.from(mapping as Map),
            ),
      resolutions: _excelListV2(
        value['resolutions'],
        TacticalExcelResolution.fromWire,
      ),
      rowDecisions: _excelListV2(
        value['row_decisions'],
        TacticalExcelRowDecision.fromWire,
      ),
      onConflict: value['on_conflict'] as String,
    );
  }

  Map<String, dynamic> toWire() => {
    'profile_id': profileId,
    'source_path': sourcePath,
    'sheet_name': sheetName,
    'delimiter': delimiter,
    'column_mapping': columnMapping?.toWire(),
    'resolutions': [for (final item in resolutions) item.toWire()],
    'row_decisions': [for (final item in rowDecisions) item.toWire()],
    'on_conflict': onConflict,
  };
}

/// 미리보기 이슈(`excelIssue`). [code] 말고는 모두 선택 키다(있던 키만 [toWire]로 되돌린다). 행 이슈의 [field]는
/// 의미 필드 또는 덱 검사 실패 `deck`, 파일 이슈에는 `mapping_confirmation_required`·`legacy_migration_required`
/// (v1 [sourceRevision]·[sourceFingerprint]) 같은 코드가 온다.
@immutable
class TacticalExcelIssue {
  const TacticalExcelIssue._({
    required this.code,
    required this.field,
    required this.column,
    required this.rawKey,
    required this.raw,
    required this.message,
    required this.fromSavedRule,
    required this.sourceRevision,
    required this.sourceFingerprint,
    required this.wireKeys,
  });

  final String code;
  final String? field, rawKey, message, sourceFingerprint;
  final int? column, sourceRevision;

  /// 셀 원값(문자열·수·불리언·null).
  final Object? raw;

  /// 저장된 프로필 규칙을 적용하다 생긴 이슈인가.
  final bool? fromSavedRule;

  /// 응답에 실제로 있던 키(null 값과 없는 키를 구분해 그대로 되돌린다).
  final Set<String> wireKeys;

  factory TacticalExcelIssue.fromWire(Map<String, dynamic> value) {
    const optional = {
      'field',
      'column',
      'raw_key',
      'raw',
      'message',
      'from_saved_rule',
      'source_revision',
      'source_fingerprint',
    };
    final keys = value.keys.toSet();
    final column = value['column'];
    final rawKey = value['raw_key'];
    if (!keys.contains('code') ||
        !{'code', ...optional}.containsAll(keys) ||
        value['code'] is! String ||
        (value['code'] as String).isEmpty ||
        (keys.contains('field') && value['field'] is! String) ||
        (column != null && !_excelColumnV2(column)) ||
        (rawKey != null && rawKey is! String) ||
        !_excelScalarV2(value['raw']) ||
        (keys.contains('message') && value['message'] is! String) ||
        (keys.contains('from_saved_rule') &&
            value['from_saved_rule'] is! bool) ||
        (keys.contains('source_revision') &&
            !_countV2(value['source_revision'])) ||
        (keys.contains('source_fingerprint') &&
            !_sha256V2(value['source_fingerprint']))) {
      throw const FormatException('Invalid tactical Excel issue');
    }
    return TacticalExcelIssue._(
      code: value['code'] as String,
      field: value['field'] as String?,
      column: column as int?,
      rawKey: rawKey as String?,
      raw: value['raw'],
      message: value['message'] as String?,
      fromSavedRule: value['from_saved_rule'] as bool?,
      sourceRevision: value['source_revision'] as int?,
      sourceFingerprint: value['source_fingerprint'] as String?,
      wireKeys: Set.unmodifiable(keys),
    );
  }

  Map<String, dynamic> toWire() => {
    'code': code,
    if (wireKeys.contains('field')) 'field': field,
    if (wireKeys.contains('column')) 'column': column,
    if (wireKeys.contains('raw_key')) 'raw_key': rawKey,
    if (wireKeys.contains('raw')) 'raw': raw,
    if (wireKeys.contains('message')) 'message': message,
    if (wireKeys.contains('from_saved_rule')) 'from_saved_rule': fromSavedRule,
    if (wireKeys.contains('source_revision')) 'source_revision': sourceRevision,
    if (wireKeys.contains('source_fingerprint'))
      'source_fingerprint': sourceFingerprint,
  };
}

/// 행의 의미 필드 하나에 해당하는 셀(`excelRawCell`). 매핑하지 않은 필드는 [column]이 null이다. 수식 셀은
/// [formula]와 캐시 값 [cachedValue]가 오고, 캐시 값도 명시적으로 받아들이기 전에는 적용되지 않는다.
@immutable
class TacticalExcelRawCell {
  const TacticalExcelRawCell._({
    required this.field,
    required this.column,
    required this.raw,
    required this.rawKey,
    required this.formula,
    required this.cachedValue,
  });
  final String field;
  final int? column;
  final Object? raw, cachedValue;

  /// resolution `raw`에 그대로 넣는 typed 원값 키.
  final String rawKey;
  final String? formula;

  factory TacticalExcelRawCell.fromWire(Map<String, dynamic> value) {
    final column = value['column'];
    final formula = value['formula'];
    if (!_exactV2(value, {
          'field',
          'column',
          'raw',
          'raw_key',
          'formula',
          'cached_value',
        }) ||
        !tacticalExcelFields.contains(value['field']) ||
        (column != null && !_excelColumnV2(column)) ||
        !_excelScalarV2(value['raw']) ||
        value['raw_key'] is! String ||
        (formula != null && formula is! String) ||
        !_excelScalarV2(value['cached_value'])) {
      throw const FormatException('Invalid tactical Excel raw cell');
    }
    return TacticalExcelRawCell._(
      field: value['field'] as String,
      column: column as int?,
      raw: value['raw'],
      rawKey: value['raw_key'] as String,
      formula: formula as String?,
      cachedValue: value['cached_value'],
    );
  }

  Map<String, dynamic> toWire() => {
    'field': field,
    'column': column,
    'raw': raw,
    'raw_key': rawKey,
    'formula': formula,
    'cached_value': cachedValue,
  };
}

/// 미리보기 행(`excelPreviewRow`). [status]: `empty`·`skipped`·`unresolved`·`eligible`·`overwrite`·`conflict`·
/// `conflict_skipped`·`replay`(이미 가져온 원본 행). [match]는 해석이 끝난 행의 FB-6 입력(그대로 v2 기록이 된다),
/// [targetMatchId]는 덮어쓸 기록 또는 replay의 기존 기록.
@immutable
class TacticalExcelPreviewRow {
  TacticalExcelPreviewRow._({
    required this.rowId,
    required this.rowNumber,
    required List<TacticalExcelRawCell> rawCells,
    required this.status,
    required List<TacticalExcelIssue> issues,
    required this.match,
    required this.targetMatchId,
  }) : rawCells = List.unmodifiable(rawCells),
       issues = List.unmodifiable(issues);
  final String rowId, status;
  final int rowNumber;
  final List<TacticalExcelRawCell> rawCells;
  final List<TacticalExcelIssue> issues;
  final TacticalMatchInputV2? match;
  final String? targetMatchId;

  factory TacticalExcelPreviewRow.fromWire(Map<String, dynamic> value) {
    final match = value['match'];
    final target = value['target_match_id'];
    if (!_exactV2(value, {
          'row_id',
          'row_number',
          'raw_cells',
          'status',
          'issues',
          'match',
          'target_match_id',
        }) ||
        !_excelIdV2('excel-row', value['row_id']) ||
        !_excelRowNumberV2(value['row_number']) ||
        !_excelRowStatusesV2.contains(value['status']) ||
        (match != null && match is! Map) ||
        (target != null && !_recordIdV2(target))) {
      throw const FormatException('Invalid tactical Excel preview row');
    }
    return TacticalExcelPreviewRow._(
      rowId: value['row_id'] as String,
      rowNumber: value['row_number'] as int,
      rawCells: _excelListV2(value['raw_cells'], TacticalExcelRawCell.fromWire),
      status: value['status'] as String,
      issues: _excelListV2(value['issues'], TacticalExcelIssue.fromWire),
      match: match == null
          ? null
          : TacticalMatchInputV2.fromWire(
              Map<String, dynamic>.from(match as Map),
            ),
      targetMatchId: target as String?,
    );
  }

  Map<String, dynamic> toWire() => {
    'row_id': rowId,
    'row_number': rowNumber,
    'raw_cells': [for (final item in rawCells) item.toWire()],
    'status': status,
    'issues': [for (final item in issues) item.toWire()],
    'match': match?.toWire(),
    'target_match_id': targetMatchId,
  };
}

/// 문자열 그룹 제안(`excelSuggestion`, 세 변형). 모두 확인이 필요하다 — resolution으로 넣기 전에는 적용되지 않는다.
sealed class TacticalExcelSuggestion {
  const TacticalExcelSuggestion();

  Map<String, dynamic> toWire();

  static TacticalExcelSuggestion fromWire(Map<String, dynamic> value) {
    if (value['requires_confirmation'] == true) {
      if (_exactV2(value, {
            'student_id',
            'display_name',
            'score',
            'requires_confirmation',
          }) &&
          value['student_id'] is String &&
          (value['student_id'] as String).isNotEmpty &&
          value['display_name'] is String &&
          value['score'] is num &&
          (value['score'] as num) >= 0 &&
          (value['score'] as num) <= 1) {
        return TacticalExcelStudentSuggestion._(
          studentId: value['student_id'] as String,
          displayName: value['display_name'] as String,
          score: value['score'] as num,
        );
      }
      if (_exactV2(value, {
            'identity_id',
            'display_name',
            'requires_confirmation',
          }) &&
          _recordIdV2(value['identity_id']) &&
          value['display_name'] is String) {
        return TacticalExcelOpponentSuggestion._(
          identityId: value['identity_id'] as String,
          displayName: value['display_name'] as String,
        );
      }
      if (_exactV2(value, {
            'result',
            'attempt_count',
            'requires_confirmation',
          }) &&
          {'win', 'loss'}.contains(value['result']) &&
          value['attempt_count'] is int &&
          (value['attempt_count'] as int) >= 1) {
        return TacticalExcelResultSuggestion._(
          result: value['result'] as String,
          attemptCount: value['attempt_count'] as int,
        );
      }
    }
    throw const FormatException('Invalid tactical Excel suggestion');
  }
}

/// 학생 이름 후보(유사도 [score] 0~1, 확률이 아니다).
final class TacticalExcelStudentSuggestion extends TacticalExcelSuggestion {
  const TacticalExcelStudentSuggestion._({
    required this.studentId,
    required this.displayName,
    required this.score,
  });
  final String studentId, displayName;
  final num score;

  @override
  Map<String, dynamic> toWire() => {
    'student_id': studentId,
    'display_name': displayName,
    'score': score,
    'requires_confirmation': true,
  };
}

/// 기존 상대 identity 후보(표시 이름·별칭이 같다).
final class TacticalExcelOpponentSuggestion extends TacticalExcelSuggestion {
  const TacticalExcelOpponentSuggestion._({
    required this.identityId,
    required this.displayName,
  });
  final String identityId, displayName;

  @override
  Map<String, dynamic> toWire() => {
    'identity_id': identityId,
    'display_name': displayName,
    'requires_confirmation': true,
  };
}

/// `승(3트)` 같은 결과 칸에서 읽은 결과·시도 횟수 후보.
final class TacticalExcelResultSuggestion extends TacticalExcelSuggestion {
  const TacticalExcelResultSuggestion._({
    required this.result,
    required this.attemptCount,
  });
  final String result;
  final int attemptCount;

  @override
  Map<String, dynamic> toWire() => {
    'result': result,
    'attempt_count': attemptCount,
    'requires_confirmation': true,
  };
}

/// 그룹이 나온 칸(행·열, 매핑하지 않은 필드는 열 null).
typedef TacticalExcelPlace = ({int row, int? column});

/// 같은 필드·원값·이슈 코드의 확인 필요 칸 묶음(`excelStringGroup`). [rawKey]를 resolution `raw`로 쓴다.
@immutable
class TacticalExcelStringGroup {
  TacticalExcelStringGroup._({
    required this.groupId,
    required this.field,
    required this.rawKey,
    required this.raw,
    required this.code,
    required this.count,
    required List<TacticalExcelPlace> places,
    required List<TacticalExcelSuggestion> suggestions,
  }) : places = List.unmodifiable(places),
       suggestions = List.unmodifiable(suggestions);
  final String groupId, field, rawKey, code;
  final Object? raw;
  final int count;
  final List<TacticalExcelPlace> places;
  final List<TacticalExcelSuggestion> suggestions;

  factory TacticalExcelStringGroup.fromWire(Map<String, dynamic> value) {
    if (!_exactV2(value, {
          'group_id',
          'field',
          'raw_key',
          'raw',
          'code',
          'count',
          'places',
          'suggestions',
        }) ||
        !_excelIdV2('excel-group', value['group_id']) ||
        !tacticalExcelFields.contains(value['field']) ||
        value['raw_key'] is! String ||
        !_excelScalarV2(value['raw']) ||
        value['code'] is! String ||
        !_countV2(value['count'])) {
      throw const FormatException('Invalid tactical Excel string group');
    }
    return TacticalExcelStringGroup._(
      groupId: value['group_id'] as String,
      field: value['field'] as String,
      rawKey: value['raw_key'] as String,
      raw: value['raw'],
      code: value['code'] as String,
      count: value['count'] as int,
      places: _excelListV2(value['places'], (place) {
        final column = place['column'];
        if (!_exactV2(place, {'row', 'column'}) ||
            !_excelRowNumberV2(place['row']) ||
            (column != null && !_excelColumnV2(column))) {
          throw const FormatException('Invalid tactical Excel place');
        }
        return (row: place['row'] as int, column: column as int?);
      }),
      suggestions: _excelListV2(
        value['suggestions'],
        TacticalExcelSuggestion.fromWire,
      ),
    );
  }

  Map<String, dynamic> toWire() => {
    'group_id': groupId,
    'field': field,
    'raw_key': rawKey,
    'raw': raw,
    'code': code,
    'count': count,
    'places': [
      for (final place in places) {'row': place.row, 'column': place.column},
    ],
    'suggestions': [for (final item in suggestions) item.toWire()],
  };
}

/// 기존 기록·같은 파일의 다른 행과 겹칠 수 있는 행(`excelConflict`). 날짜·상대만 같다고 합치지 않는다.
@immutable
class TacticalExcelConflict {
  TacticalExcelConflict._({
    required this.rowId,
    required this.rowNumber,
    required List<String> matchIds,
    required List<int> peerRows,
    required this.ambiguous,
  }) : matchIds = List.unmodifiable(matchIds),
       peerRows = List.unmodifiable(peerRows);
  final String rowId;
  final int rowNumber;
  final List<String> matchIds;
  final List<int> peerRows;

  /// 덮어쓰기에 명시적 기록 ID가 필요한가(정밀도·빈칸·여러 후보·같은 파일 행).
  final bool ambiguous;

  factory TacticalExcelConflict.fromWire(Map<String, dynamic> value) {
    final ids = value['match_ids'];
    final peers = value['peer_rows'];
    if (!_exactV2(value, {
          'row_id',
          'row_number',
          'match_ids',
          'peer_rows',
          'ambiguous',
        }) ||
        !_excelIdV2('excel-row', value['row_id']) ||
        !_excelRowNumberV2(value['row_number']) ||
        ids is! List ||
        !ids.every(_recordIdV2) ||
        peers is! List ||
        !peers.every(_excelRowNumberV2) ||
        value['ambiguous'] is! bool) {
      throw const FormatException('Invalid tactical Excel conflict');
    }
    return TacticalExcelConflict._(
      rowId: value['row_id'] as String,
      rowNumber: value['row_number'] as int,
      matchIds: ids.cast<String>(),
      peerRows: peers.cast<int>(),
      ambiguous: value['ambiguous'] as bool,
    );
  }

  Map<String, dynamic> toWire() => {
    'row_id': rowId,
    'row_number': rowNumber,
    'match_ids': [...matchIds],
    'peer_rows': [...peerRows],
    'ambiguous': ambiguous,
  };
}

/// 머리글 후보(`excelMappingCandidate`). 확인 전에는 쓰지 않는다 — 고르면 [TacticalExcelColumnMapping]으로 보낸다.
@immutable
class TacticalExcelMappingCandidate {
  TacticalExcelMappingCandidate._({
    required this.headerRow,
    required this.columns,
    required List<String> ambiguousFields,
  }) : ambiguousFields = List.unmodifiable(ambiguousFields);
  final int headerRow;
  final Map<String, int> columns;

  /// 같은 머리글 이름이 여러 열에 있어 고르지 못한 필드.
  final List<String> ambiguousFields;

  factory TacticalExcelMappingCandidate.fromWire(Map<String, dynamic> value) {
    final ambiguous = value['ambiguous_fields'];
    if (!_exactV2(value, {
          'header_row',
          'columns',
          'ambiguous_fields',
          'requires_confirmation',
        }) ||
        !_excelRowNumberV2(value['header_row']) ||
        ambiguous is! List ||
        !ambiguous.every(tacticalExcelFields.contains) ||
        value['requires_confirmation'] != true) {
      throw const FormatException('Invalid tactical Excel mapping candidate');
    }
    return TacticalExcelMappingCandidate._(
      headerRow: value['header_row'] as int,
      columns: _excelColumnsV2(value['columns'], mapping: false),
      ambiguousFields: ambiguous.cast<String>(),
    );
  }

  Map<String, dynamic> toWire() => {
    'header_row': headerRow,
    'columns': {...columns},
    'ambiguous_fields': [...ambiguousFields],
    'requires_confirmation': true,
  };
}

/// 미리보기 행 수. 가져오기 버튼의 분모는 [eligibleRows](결정 반영 뒤 commit 대상)다 — 고정 예시 분모가 아니다.
/// 빈 행([emptyRows])은 건너뛴 기록 행([skippedRows])과 따로 센다.
@immutable
class TacticalExcelSummary {
  const TacticalExcelSummary._({
    required this.readRows,
    required this.emptyRows,
    required this.skippedRows,
    required this.parsedRows,
    required this.unresolvedRows,
    required this.conflictRows,
    required this.eligibleRows,
  });
  final int readRows, emptyRows, skippedRows, parsedRows;
  final int unresolvedRows, conflictRows, eligibleRows;

  static const _keys = [
    'read_rows',
    'empty_rows',
    'skipped_rows',
    'parsed_rows',
    'unresolved_rows',
    'conflict_rows',
    'eligible_rows',
  ];

  factory TacticalExcelSummary.fromWire(Map<String, dynamic> value) {
    if (!_exactV2(value, _keys.toSet()) ||
        !_keys.every((key) => _countV2(value[key]))) {
      throw const FormatException('Invalid tactical Excel summary');
    }
    return TacticalExcelSummary._(
      readRows: value['read_rows'] as int,
      emptyRows: value['empty_rows'] as int,
      skippedRows: value['skipped_rows'] as int,
      parsedRows: value['parsed_rows'] as int,
      unresolvedRows: value['unresolved_rows'] as int,
      conflictRows: value['conflict_rows'] as int,
      eligibleRows: value['eligible_rows'] as int,
    );
  }

  Map<String, dynamic> toWire() => {
    'read_rows': readRows,
    'empty_rows': emptyRows,
    'skipped_rows': skippedRows,
    'parsed_rows': parsedRows,
    'unresolved_rows': unresolvedRows,
    'conflict_rows': conflictRows,
    'eligible_rows': eligibleRows,
  };
}

/// FB-7 미리보기 결과(`excelPreviewResponse`). commit에는 [fingerprint](원본 바이트)·[interpretationFingerprint]
/// (선택·규칙·카탈로그·프로필·형식 맥락)·[currentRevision]을 `expected_*`로 넣는다. 원본·저장소는 바뀌지 않는다.
@immutable
class TacticalExcelPreview {
  TacticalExcelPreview._({
    required this.fingerprint,
    required this.interpretationFingerprint,
    required this.format,
    required List<String> sheetNames,
    required this.selectedSheet,
    required List<TacticalExcelMappingCandidate> mappingCandidates,
    required this.savedMapping,
    required this.columnMapping,
    required List<TacticalExcelPreviewRow> rows,
    required List<TacticalExcelStringGroup> stringGroups,
    required List<TacticalExcelConflict> conflicts,
    required this.summary,
    required List<TacticalExcelIssue> issues,
    required this.currentRevision,
    required this.rulesRevision,
    required this.legacyMigrationRequired,
  }) : sheetNames = List.unmodifiable(sheetNames),
       mappingCandidates = List.unmodifiable(mappingCandidates),
       rows = List.unmodifiable(rows),
       stringGroups = List.unmodifiable(stringGroups),
       conflicts = List.unmodifiable(conflicts),
       issues = List.unmodifiable(issues);

  final String fingerprint, interpretationFingerprint, format, selectedSheet;
  final List<String> sheetNames;
  final List<TacticalExcelMappingCandidate> mappingCandidates;

  /// 프로필에 저장된 매핑(제안일 뿐, 확인 전에는 [columnMapping]이 아니다).
  final TacticalExcelColumnMapping? savedMapping;
  final TacticalExcelColumnMapping? columnMapping;
  final List<TacticalExcelPreviewRow> rows;
  final List<TacticalExcelStringGroup> stringGroups;
  final List<TacticalExcelConflict> conflicts;
  final TacticalExcelSummary summary;
  final List<TacticalExcelIssue> issues;
  final int currentRevision, rulesRevision;

  /// v1 기록이 남아 있어 FB-6 명시 이관이 먼저다(commit은 `legacy_migration_required`).
  final bool legacyMigrationRequired;

  factory TacticalExcelPreview.fromWire(Map<String, dynamic> value) {
    const fields = {
      'fingerprint',
      'interpretation_fingerprint',
      'format',
      'sheet_names',
      'selected_sheet',
      'mapping_candidates',
      'saved_mapping',
      'column_mapping',
      'rows',
      'string_groups',
      'conflicts',
      'summary',
      'issues',
      'current_revision',
      'rules_revision',
      'legacy_migration_required',
    };
    final sheets = value['sheet_names'];
    final selected = value['selected_sheet'];
    TacticalExcelColumnMapping? mapping(Object? raw) => raw == null
        ? null
        : TacticalExcelColumnMapping.fromWire(
            Map<String, dynamic>.from(raw as Map),
          );
    if (!_exactV2(value, fields) ||
        !_sha256V2(value['fingerprint']) ||
        !_sha256V2(value['interpretation_fingerprint']) ||
        !{'xlsx', 'csv'}.contains(value['format']) ||
        sheets is! List ||
        sheets.isEmpty ||
        !sheets.every((item) => item is String && item.isNotEmpty) ||
        selected is! String ||
        selected.isEmpty ||
        value['summary'] is! Map ||
        !_countV2(value['current_revision']) ||
        !_countV2(value['rules_revision']) ||
        value['legacy_migration_required'] is! bool) {
      throw const FormatException('Invalid tactical Excel preview');
    }
    return TacticalExcelPreview._(
      fingerprint: value['fingerprint'] as String,
      interpretationFingerprint: value['interpretation_fingerprint'] as String,
      format: value['format'] as String,
      sheetNames: sheets.cast<String>(),
      selectedSheet: selected,
      mappingCandidates: _excelListV2(
        value['mapping_candidates'],
        TacticalExcelMappingCandidate.fromWire,
      ),
      savedMapping: mapping(value['saved_mapping']),
      columnMapping: mapping(value['column_mapping']),
      rows: _excelListV2(value['rows'], TacticalExcelPreviewRow.fromWire),
      stringGroups: _excelListV2(
        value['string_groups'],
        TacticalExcelStringGroup.fromWire,
      ),
      conflicts: _excelListV2(
        value['conflicts'],
        TacticalExcelConflict.fromWire,
      ),
      summary: TacticalExcelSummary.fromWire(
        Map<String, dynamic>.from(value['summary'] as Map),
      ),
      issues: _excelListV2(value['issues'], TacticalExcelIssue.fromWire),
      currentRevision: value['current_revision'] as int,
      rulesRevision: value['rules_revision'] as int,
      legacyMigrationRequired: value['legacy_migration_required'] as bool,
    );
  }

  Map<String, dynamic> toWire() => {
    'fingerprint': fingerprint,
    'interpretation_fingerprint': interpretationFingerprint,
    'format': format,
    'sheet_names': [...sheetNames],
    'selected_sheet': selectedSheet,
    'mapping_candidates': [for (final item in mappingCandidates) item.toWire()],
    'saved_mapping': savedMapping?.toWire(),
    'column_mapping': columnMapping?.toWire(),
    'rows': [for (final item in rows) item.toWire()],
    'string_groups': [for (final item in stringGroups) item.toWire()],
    'conflicts': [for (final item in conflicts) item.toWire()],
    'summary': summary.toWire(),
    'issues': [for (final item in issues) item.toWire()],
    'current_revision': currentRevision,
    'rules_revision': rulesRevision,
    'legacy_migration_required': legacyMigrationRequired,
  };
}

/// FB-7 commit 결과(`excelCommitResponse`). [rulesSaved]는 규칙 내용이 실제로 바뀌었는지다(같은 규칙이면 false).
/// 가져올 행·바뀐 규칙이 없으면 [revision]은 그대로다.
@immutable
class TacticalExcelCommitResult {
  TacticalExcelCommitResult._({
    required this.revision,
    required this.importedCount,
    required this.overwrittenCount,
    required this.skippedCount,
    required List<String> skippedRowIds,
    required this.rulesSaved,
    required List<String> matchIds,
  }) : skippedRowIds = List.unmodifiable(skippedRowIds),
       matchIds = List.unmodifiable(matchIds);
  final int revision, importedCount, overwrittenCount, skippedCount;
  final List<String> skippedRowIds;
  final bool rulesSaved;

  /// 새로 만든 기록 ID 다음 덮어쓴 기록 ID.
  final List<String> matchIds;

  factory TacticalExcelCommitResult.fromWire(Map<String, dynamic> value) {
    const fields = {
      'revision',
      'imported_count',
      'overwritten_count',
      'skipped_count',
      'skipped_row_ids',
      'rules_saved',
      'match_ids',
    };
    final skipped = value['skipped_row_ids'];
    final ids = value['match_ids'];
    if (!_exactV2(value, fields) ||
        !_countV2(value['imported_count']) ||
        !_countV2(value['overwritten_count']) ||
        !_countV2(value['skipped_count']) ||
        skipped is! List ||
        !skipped.every((item) => _excelIdV2('excel-row', item)) ||
        value['rules_saved'] is! bool ||
        ids is! List ||
        !ids.every(_recordIdV2)) {
      throw const FormatException('Invalid tactical Excel commit result');
    }
    return TacticalExcelCommitResult._(
      revision: _revisionV2(value),
      importedCount: value['imported_count'] as int,
      overwrittenCount: value['overwritten_count'] as int,
      skippedCount: value['skipped_count'] as int,
      skippedRowIds: skipped.cast<String>(),
      rulesSaved: value['rules_saved'] as bool,
      matchIds: ids.cast<String>(),
    );
  }

  Map<String, dynamic> toWire() => {
    'revision': revision,
    'imported_count': importedCount,
    'overwritten_count': overwrittenCount,
    'skipped_count': skippedCount,
    'skipped_row_ids': [...skippedRowIds],
    'rules_saved': rulesSaved,
    'match_ids': [...matchIds],
  };
}

/// FB-6 요청 payload를 보내기 전에 strict 검사한다(schema `fb6*Request`). 아니면 [FormatException].
Map<String, dynamic> checkedTacticalV2Request(
  String method,
  Map<String, dynamic> payload,
) {
  if (!isValidTacticalV2ProtocolMessage({
    'protocol': 1,
    'id': 'request',
    'type': 'request',
    'method': method,
    'payload': payload,
  })) {
    throw FormatException('Invalid $method request');
  }
  return payload;
}

/// FB-6 쓰기 capability(Process·Mock). [TacticalEvidenceService] 전체(통계·추천·공유)를 구현하지 않는
/// 대역도 v2 기록·족보 쓰기와 이관만 따로 구현할 수 있게 나눈다(RepositoryInventoryReviewService 선례).
///
/// v1 기록이 있으면 새 v2 기록·족보 쓰기는 `legacy_migration_required`다. [previewTacticalLegacyMigration] →
/// [commitTacticalLegacyMigration](미리보기의 source revision·fingerprint) 뒤 v1 새 쓰기는
/// `tactical_v1_read_only`. 같은 key 재요청은 원 응답(삭제된 레코드를 되살리지 않음), 다른 내용은
/// `idempotency_conflict`.
abstract interface class TacticalEvidenceWriteService {
  Future<TacticalEvidenceState> loadTacticalEvidenceState(String profileId);
  Future<TacticalMatchUpsertResult> upsertTacticalMatchV2({
    required String profileId,
    required TacticalMatchInputV2 match,
    required int expectedRevision,
    required String idempotencyKey,
  });
  Future<TacticalMatchDeleteResult> deleteTacticalMatchV2({
    required String profileId,
    required String matchId,
    required int expectedRevision,
    required String idempotencyKey,
  });
  Future<TacticalJokboUpsertResult> upsertTacticalJokboV2({
    required String profileId,
    required TacticalJokboInputV2 jokbo,
    required int expectedRevision,
    required String idempotencyKey,
  });
  Future<TacticalJokboDeleteResult> deleteTacticalJokboV2({
    required String profileId,
    required String jokboId,
    required int expectedRevision,
    required String idempotencyKey,
  });
  Future<TacticalLegacyPreview> previewTacticalLegacyMigration(
    String profileId,
  );
  Future<TacticalLegacyCommitResult> commitTacticalLegacyMigration({
    required String profileId,
    required int expectedSourceRevision,
    required String expectedFingerprint,
    required int expectedRevision,
    required String idempotencyKey,
  });
}

/// FB-7 엑셀·CSV 가져오기 capability(Process·Mock). 미리보기 → 사용자가 매핑·resolution·행 결정을 명시 → 같은
/// 선택으로 다시 미리보기 → commit(그 미리보기의 `fingerprint`·`interpretation_fingerprint`·`current_revision`).
/// 원본 바이트·해석 맥락이 바뀌면 `import_source_changed`·`import_interpretation_changed`, 미해결·충돌 행이나 파일
/// 이슈가 남으면 `import_review_required`(details `row_ids`), v1 기록이 남았으면 `legacy_migration_required`.
/// 원본을 못 읽으면 `import_source_unreadable`(details `reason`). 같은 key·같은 내용 재요청은 원본을 다시 읽거나
/// revision을 보기 전에 원 응답이고, 다른 내용은 `idempotency_conflict`.
abstract interface class TacticalExcelImportService {
  Future<TacticalExcelPreview> previewTacticalExcelImport(
    TacticalExcelImportChoices choices,
  );
  Future<TacticalExcelCommitResult> commitTacticalExcelImport({
    required TacticalExcelImportChoices choices,
    required bool saveRules,
    required String expectedFingerprint,
    required String expectedInterpretationFingerprint,
    required int expectedRevision,
    required String idempotencyKey,
  });
}

/// FB-7 commit payload(선택 8키 + 13키). Process·Mock이 같은 모양으로 만든다.
Map<String, dynamic> tacticalExcelCommitPayload({
  required TacticalExcelImportChoices choices,
  required bool saveRules,
  required String expectedFingerprint,
  required String expectedInterpretationFingerprint,
  required int expectedRevision,
  required String idempotencyKey,
}) => {
  ...choices.toWire(),
  'save_rules': saveRules,
  'expected_fingerprint': expectedFingerprint,
  'expected_interpretation_fingerprint': expectedInterpretationFingerprint,
  'expected_revision': expectedRevision,
  'idempotency_key': idempotencyKey,
};

/// FE9-b1 읽기 capability(Process·Mock): 전술 화면이 쓰는 v2 읽기 묶음 — 상태 읽기 · 통계 · 추이 · 추천.
/// 공유 · v6 가져오기 · 로비 쓰기 · 예측 저장은 [TacticalEvidenceService](Process만)에 남는다. Mock 결과도 같은
/// strict `fromWire`를 거친다(fb6-dart 발견 4).
abstract interface class TacticalEvidenceReadService {
  Future<TacticalEvidenceState> loadTacticalEvidenceState(String profileId);
  Future<TacticalStatisticsResult> queryTacticalStatistics(
    String profileId,
    TacticalStatsFilters filters,
  );
  Future<TacticalTrendsResult> queryTacticalTrends(
    String profileId,
    TacticalTrendFilters filters,
  );
  Future<TacticalRecommendationResult> queryTacticalRecommendations(
    String profileId,
    TacticalRecommendationFilters filters,
  );
}

abstract interface class TacticalEvidenceService {
  Future<TacticalEvidenceState> loadTacticalEvidenceState(String profileId);
  Future<TacticalImportPreview> previewTacticalV6Import(
    String profileId,
    String sourcePath,
    String importBatchId,
  );
  Future<TacticalImportCommitResult> commitTacticalV6Import({
    required String profileId,
    required String sourcePath,
    required String importBatchId,
    required String expectedFingerprint,
    required List<String> acceptedIssueIds,
    required int expectedRevision,
    required String idempotencyKey,
  });
  Future<TacticalLobbyCommitResult> commitTacticalLobby({
    required String profileId,
    required Map<String, dynamic> candidatePayload,
    required String season,
    required String map,
    required Map<int, String> identityBindings,
    required int expectedRevision,
    required String idempotencyKey,
  });
  Future<int> selectTacticalLobbyCandidate({
    required String profileId,
    required String candidateId,
    required String selectedAt,
    required int expectedRevision,
    required String idempotencyKey,
  });
  Future<TacticalLinkResult> linkTacticalMatch({
    required String profileId,
    required String matchId,
    required String? candidateId,
    required String mode,
    required int expectedRevision,
    required String idempotencyKey,
  });
  Future<int> deleteTacticalLobby({
    required String profileId,
    required String scanId,
    required int expectedRevision,
    required String idempotencyKey,
  });
  Future<int> aliasTacticalOpponent({
    required String profileId,
    required String opponentIdentityId,
    required String displayName,
    required String? nameTemplateId,
    required int expectedRevision,
    required String idempotencyKey,
  });
  Future<TacticalStatisticsResult> queryTacticalStatistics(
    String profileId,
    TacticalStatsFilters filters,
  );
  Future<TacticalTrendsResult> queryTacticalTrends(
    String profileId,
    TacticalTrendFilters filters,
  );
  Future<TacticalRecommendationResult> queryTacticalRecommendations(
    String profileId,
    TacticalRecommendationFilters filters,
  );
  Future<TacticalPredictionSaveResult> saveTacticalRecommendation({
    required String profileId,
    required TacticalRecommendationFilters filters,
    required int expectedRevision,
    required String idempotencyKey,
  });
  Future<TacticalSavedPrediction> getTacticalRecommendation(
    String profileId,
    String predictionId,
  );
  Future<TacticalShareState> loadTacticalShareState(String profileId);
  Future<TacticalSharePrepareResult> prepareTacticalShare({
    required String profileId,
    required String matchId,
    required String scopeId,
    required String contributorId,
    required TacticalShareConsent consent,
    required String attemptSessionId,
    required int attemptIndex,
    required String sharedAt,
    required String patch,
  });
  Future<TacticalShareMutationResult> importTacticalShares({
    required String profileId,
    required List<TacticalSharePayload> shares,
    required int expectedRevision,
    required String idempotencyKey,
  });
  Future<TacticalShareMutationResult> withdrawTacticalShares({
    required String profileId,
    required List<String> shareIds,
    required String withdrawnAt,
    required String reason,
    required int expectedRevision,
    required String idempotencyKey,
  });
  Future<TacticalShareAnalyticsResult> queryTacticalShareAnalytics(
    String profileId,
    TacticalShareAnalyticsFilters filters,
  );
}

bool isValidTacticalV2ProtocolMessage(Object? input) {
  try {
    if (input is! Map) return false;
    final value = Map<String, dynamic>.from(input);
    if (!_exactV2(value, {'protocol', 'id', 'type', 'method', 'payload'}) ||
        value['protocol'] != 1 ||
        value['id'] is! String ||
        (value['id'] as String).isEmpty ||
        !{'request', 'response'}.contains(value['type']) ||
        value['method'] is! String ||
        value['payload'] is! Map) {
      return false;
    }
    final method = value['method'] as String;
    final payload = Map<String, dynamic>.from(value['payload'] as Map);
    bool profile(Object? id) =>
        id is String && RegExp(r'^[0-9a-f]{24}$').stringMatch(id) == id;
    if (value['type'] == 'request') {
      if (method == 'tactical.v2.state.get') {
        return _exactV2(payload, {'profile_id'}) &&
            profile(payload['profile_id']);
      }
      if (method == 'tactical.v2.import.preview') {
        return _exactV2(payload, {
              'profile_id',
              'source_path',
              'import_batch_id',
            }) &&
            profile(payload['profile_id']) &&
            payload['source_path'] is String &&
            (payload['source_path'] as String).isNotEmpty &&
            _recordIdV2(payload['import_batch_id']);
      }
      if (method == 'tactical.v2.import.commit') {
        const fields = {
          'profile_id',
          'source_path',
          'import_batch_id',
          'expected_fingerprint',
          'accepted_issue_ids',
          'expected_revision',
          'idempotency_key',
        };
        return _exactV2(payload, fields) &&
            profile(payload['profile_id']) &&
            payload['source_path'] is String &&
            (payload['source_path'] as String).isNotEmpty &&
            _recordIdV2(payload['import_batch_id']) &&
            payload['expected_fingerprint'] is String &&
            RegExp(
                  r'^[0-9a-f]{64}$',
                ).stringMatch(payload['expected_fingerprint']) ==
                payload['expected_fingerprint'] &&
            payload['accepted_issue_ids'] is List &&
            (payload['accepted_issue_ids'] as List).every(_recordIdV2) &&
            (payload['accepted_issue_ids'] as List).toSet().length ==
                (payload['accepted_issue_ids'] as List).length &&
            payload['expected_revision'] is int &&
            payload['expected_revision'] >= 0 &&
            payload['idempotency_key'] is String &&
            (payload['idempotency_key'] as String).isNotEmpty;
      }
      const mutationBase = {
        'profile_id',
        'expected_revision',
        'idempotency_key',
      };
      bool base(Set<String> fields) =>
          _exactV2(payload, {...mutationBase, ...fields}) &&
          profile(payload['profile_id']) &&
          payload['expected_revision'] is int &&
          payload['expected_revision'] >= 0 &&
          payload['idempotency_key'] is String &&
          (payload['idempotency_key'] as String).isNotEmpty;
      if (method == 'tactical.v2.lobby.commit') {
        return base({
              'candidate_payload',
              'season',
              'map',
              'identity_bindings',
            }) &&
            payload['candidate_payload'] is Map &&
            payload['season'] is String &&
            payload['map'] is String &&
            payload['identity_bindings'] is List;
      }
      if (method == 'tactical.v2.candidate.select') {
        return base({'candidate_id', 'selected_at'}) &&
            _recordIdV2(payload['candidate_id']) &&
            _timestampV2(payload['selected_at'], nullable: false) != null;
      }
      if (method == 'tactical.v2.match.link') {
        return base({'match_id', 'candidate_id', 'mode'}) &&
            _recordIdV2(payload['match_id']) &&
            (payload['candidate_id'] == null ||
                _recordIdV2(payload['candidate_id'])) &&
            {'auto', 'manual', 'unlink'}.contains(payload['mode']);
      }
      if (method == 'tactical.v2.lobby.delete') {
        return base({'scan_id'}) && _recordIdV2(payload['scan_id']);
      }
      if (method == 'tactical.v2.opponent.alias') {
        return base({
              'opponent_identity_id',
              'display_name',
              'name_template_id',
            }) &&
            _recordIdV2(payload['opponent_identity_id']) &&
            payload['display_name'] is String &&
            (payload['display_name'] as String).isNotEmpty &&
            (payload['name_template_id'] == null ||
                _recordIdV2(payload['name_template_id']));
      }
      if (method == 'tactical.v2.stats.query') {
        final rawFilters = payload['filters'];
        if (!_exactV2(payload, {'profile_id', 'filters'}) ||
            !profile(payload['profile_id']) ||
            rawFilters is! Map) {
          return false;
        }
        final statsFilters = Map<String, dynamic>.from(rawFilters);
        const fields = {
          'season',
          'sources',
          'opponent_identity_id',
          'public_signature',
          'date_from',
          'date_to',
          'limit',
        };
        return _exactV2(statsFilters, fields) &&
            (statsFilters['season'] == null ||
                statsFilters['season'] is String) &&
            statsFilters['sources'] is List &&
            (statsFilters['sources'] as List).every(_sourcesV2.contains) &&
            (statsFilters['opponent_identity_id'] == null ||
                _recordIdV2(statsFilters['opponent_identity_id'])) &&
            (statsFilters['public_signature'] == null ||
                statsFilters['public_signature'] is String) &&
            (statsFilters['date_from'] == null ||
                _timestampV2(statsFilters['date_from'], nullable: false) !=
                    null) &&
            (statsFilters['date_to'] == null ||
                _timestampV2(statsFilters['date_to'], nullable: false) !=
                    null) &&
            statsFilters['limit'] is int &&
            statsFilters['limit'] >= 1 &&
            statsFilters['limit'] <= 100;
      }
      if (method == 'tactical.v2.trends.query') {
        final rawFilters = payload['filters'];
        if (!_exactV2(payload, {'profile_id', 'filters'}) ||
            !profile(payload['profile_id']) ||
            rawFilters is! Map) {
          return false;
        }
        final filters = Map<String, dynamic>.from(rawFilters);
        const fields = {
          'season',
          'sources',
          'opponent_identity_id',
          'public_signature',
          'date_from',
          'date_to',
          'rank_difference_min',
          'rank_difference_max',
          'as_of',
          'stale_after_hours',
          'limit',
        };
        final sources = filters['sources'];
        final rankMin = filters['rank_difference_min'];
        final rankMax = filters['rank_difference_max'];
        return _exactV2(filters, fields) &&
            (filters['season'] == null || filters['season'] is String) &&
            sources is List &&
            sources.every(_sourcesV2.contains) &&
            sources.toSet().length == sources.length &&
            (filters['opponent_identity_id'] == null ||
                _recordIdV2(filters['opponent_identity_id'])) &&
            (filters['public_signature'] == null ||
                filters['public_signature'] is String) &&
            (filters['date_from'] == null ||
                _timestampV2(filters['date_from'], nullable: false) != null) &&
            (filters['date_to'] == null ||
                _timestampV2(filters['date_to'], nullable: false) != null) &&
            (rankMin == null || rankMin is int) &&
            (rankMax == null || rankMax is int) &&
            (rankMin == null || rankMax == null || rankMin <= rankMax) &&
            _timestampV2(filters['as_of'], nullable: false) != null &&
            filters['stale_after_hours'] is int &&
            filters['stale_after_hours'] >= 1 &&
            filters['stale_after_hours'] <= 8760 &&
            filters['limit'] is int &&
            filters['limit'] >= 1 &&
            filters['limit'] <= 100;
      }
      if (method == 'tactical.v2.recommend.query') {
        return _exactV2(payload, {'profile_id', 'filters'}) &&
            profile(payload['profile_id']) &&
            _validRecommendationFiltersV2(payload['filters']);
      }
      if (method == 'tactical.v2.recommend.save') {
        return _exactV2(payload, {
              'profile_id',
              'filters',
              'expected_revision',
              'idempotency_key',
            }) &&
            profile(payload['profile_id']) &&
            _validRecommendationFiltersV2(payload['filters']) &&
            payload['expected_revision'] is int &&
            payload['expected_revision'] >= 0 &&
            payload['idempotency_key'] is String &&
            (payload['idempotency_key'] as String).isNotEmpty;
      }
      if (method == 'tactical.v2.recommend.get') {
        return _exactV2(payload, {'profile_id', 'prediction_id'}) &&
            profile(payload['profile_id']) &&
            _recordIdV2(payload['prediction_id']);
      }
      if (method == 'tactical.v2.share.state.get') {
        return _exactV2(payload, {'profile_id'}) &&
            profile(payload['profile_id']);
      }
      if (method == 'tactical.v2.share.prepare') {
        const fields = {
          'profile_id',
          'match_id',
          'scope_id',
          'contributor_id',
          'consent',
          'attempt_session_id',
          'attempt_index',
          'shared_at',
          'patch',
        };
        if (!_exactV2(payload, fields) || payload['consent'] is! Map) {
          return false;
        }
        final consent = Map<String, dynamic>.from(payload['consent'] as Map);
        return profile(payload['profile_id']) &&
            _recordIdV2(payload['match_id']) &&
            _recordIdV2(payload['scope_id']) &&
            _recordIdV2(payload['contributor_id']) &&
            _exactV2(consent, {
              'enabled',
              'scope_id',
              'contributor_id',
              'consented_at',
              'include_original_media',
            }) &&
            consent['enabled'] == true &&
            consent['include_original_media'] == false &&
            consent['scope_id'] == payload['scope_id'] &&
            consent['contributor_id'] == payload['contributor_id'] &&
            _timestampV2(consent['consented_at'], nullable: false) != null &&
            _recordIdV2(payload['attempt_session_id']) &&
            payload['attempt_index'] is int &&
            payload['attempt_index'] >= 1 &&
            _timestampV2(payload['shared_at'], nullable: false) != null &&
            payload['patch'] is String &&
            (payload['patch'] as String).isNotEmpty;
      }
      if (method == 'tactical.v2.share.import') {
        final shares = payload['shares'];
        return _exactV2(payload, {
              'profile_id',
              'shares',
              'expected_revision',
              'idempotency_key',
            }) &&
            profile(payload['profile_id']) &&
            shares is List &&
            shares.isNotEmpty &&
            shares.length <= 100 &&
            shares.every(_validSharePayloadV1) &&
            payload['expected_revision'] is int &&
            payload['expected_revision'] >= 0 &&
            payload['idempotency_key'] is String &&
            (payload['idempotency_key'] as String).isNotEmpty;
      }
      if (method == 'tactical.v2.share.withdraw') {
        final ids = payload['share_ids'];
        return _exactV2(payload, {
              'profile_id',
              'share_ids',
              'withdrawn_at',
              'reason',
              'expected_revision',
              'idempotency_key',
            }) &&
            profile(payload['profile_id']) &&
            ids is List &&
            ids.isNotEmpty &&
            ids.every(_recordIdV2) &&
            ids.toSet().length == ids.length &&
            _timestampV2(payload['withdrawn_at'], nullable: false) != null &&
            payload['reason'] is String &&
            (payload['reason'] as String).isNotEmpty &&
            payload['expected_revision'] is int &&
            payload['expected_revision'] >= 0 &&
            payload['idempotency_key'] is String &&
            (payload['idempotency_key'] as String).isNotEmpty;
      }
      if (method == 'tactical.v2.share.analytics.query') {
        return _exactV2(payload, {'profile_id', 'filters'}) &&
            profile(payload['profile_id']) &&
            _validShareFiltersV1(payload['filters']);
      }
      if (method == 'tactical.v2.match.upsert') {
        return base({'match'}) && _validFb6MatchInputV2(payload['match']);
      }
      if (method == 'tactical.v2.match.delete') {
        return base({'match_id'}) && _recordIdV2(payload['match_id']);
      }
      if (method == 'tactical.v2.jokbo.upsert') {
        return base({'jokbo'}) && _validFb6JokboInputV2(payload['jokbo']);
      }
      if (method == 'tactical.v2.jokbo.delete') {
        return base({'jokbo_id'}) && _recordIdV2(payload['jokbo_id']);
      }
      if (method == 'tactical.v2.legacy.preview') {
        return _exactV2(payload, {'profile_id'}) &&
            profile(payload['profile_id']);
      }
      if (method == 'tactical.v2.legacy.commit') {
        return base({'expected_source_revision', 'expected_fingerprint'}) &&
            payload['expected_source_revision'] is int &&
            payload['expected_source_revision'] >= 0 &&
            _sha256V2(payload['expected_fingerprint']);
      }
      if (method == 'tactical.v2.excel.preview') {
        return _exactV2(payload, _excelChoiceKeysV2) &&
            _validExcelChoicesV2(payload);
      }
      if (method == 'tactical.v2.excel.commit') {
        return _exactV2(payload, {
              ..._excelChoiceKeysV2,
              ..._excelCommitKeysV2,
            }) &&
            _validExcelChoicesV2(payload) &&
            payload['save_rules'] is bool &&
            _sha256V2(payload['expected_fingerprint']) &&
            _sha256V2(payload['expected_interpretation_fingerprint']) &&
            _countV2(payload['expected_revision']) &&
            payload['idempotency_key'] is String &&
            (payload['idempotency_key'] as String).isNotEmpty;
      }
      return false;
    }
    if (payload.containsKey('error')) {
      if (!_exactV2(payload, {'error'}) || payload['error'] is! Map) {
        return false;
      }
      final error = Map<String, dynamic>.from(payload['error'] as Map);
      final required = {'code', 'message', 'retryable'},
          allowed = {...required, 'details'};
      return error.keys.toSet().containsAll(required) &&
          allowed.containsAll(error.keys) &&
          error['code'] is String &&
          (error['code'] as String).isNotEmpty &&
          error['message'] is String &&
          error['retryable'] is bool &&
          (!error.containsKey('details') || error['details'] is Map);
    }
    if (method == 'tactical.v2.state.get') {
      TacticalEvidenceState.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.import.preview') {
      TacticalImportPreview.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.import.commit') {
      TacticalImportCommitResult.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.lobby.commit') {
      TacticalLobbyCommitResult.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.match.link') {
      TacticalLinkResult.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.candidate.select') {
      return _exactV2(payload, {'revision', 'candidate_id', 'selected_at'}) &&
          payload['revision'] is int &&
          payload['revision'] >= 0 &&
          _recordIdV2(payload['candidate_id']) &&
          _timestampV2(payload['selected_at'], nullable: false) != null;
    }
    if (method == 'tactical.v2.lobby.delete') {
      return _exactV2(payload, {
            'revision',
            'scan_id',
            'deleted',
            'deleted_candidates',
          }) &&
          payload['revision'] is int &&
          payload['revision'] >= 0 &&
          _recordIdV2(payload['scan_id']) &&
          payload['deleted'] is bool &&
          payload['deleted_candidates'] is int &&
          payload['deleted_candidates'] >= 0;
    }
    if (method == 'tactical.v2.opponent.alias') {
      return _exactV2(payload, {
            'revision',
            'opponent_identity_id',
            'current_display_name',
            'aliases',
            'name_template_ids',
          }) &&
          payload['revision'] is int &&
          payload['revision'] >= 0 &&
          _recordIdV2(payload['opponent_identity_id']) &&
          payload['current_display_name'] is String &&
          payload['aliases'] is List &&
          payload['name_template_ids'] is List;
    }
    if (method == 'tactical.v2.stats.query') {
      TacticalStatisticsResult.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.trends.query') {
      TacticalTrendsResult.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.recommend.query') {
      TacticalRecommendationResult.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.recommend.save') {
      TacticalPredictionSaveResult.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.recommend.get') {
      TacticalSavedPrediction.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.share.state.get') {
      TacticalShareState.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.share.prepare') {
      TacticalSharePrepareResult.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.share.import' ||
        method == 'tactical.v2.share.withdraw') {
      TacticalShareMutationResult.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.share.analytics.query') {
      TacticalShareAnalyticsResult.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.match.upsert') {
      TacticalMatchUpsertResult.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.match.delete') {
      TacticalMatchDeleteResult.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.jokbo.upsert') {
      TacticalJokboUpsertResult.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.jokbo.delete') {
      TacticalJokboDeleteResult.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.legacy.preview') {
      TacticalLegacyPreview.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.legacy.commit') {
      TacticalLegacyCommitResult.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.excel.preview') {
      TacticalExcelPreview.fromWire(payload);
      return true;
    }
    if (method == 'tactical.v2.excel.commit') {
      TacticalExcelCommitResult.fromWire(payload);
      return true;
    }
    return false;
  } catch (_) {
    return false;
  }
}
