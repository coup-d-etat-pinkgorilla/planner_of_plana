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

const _reviewStatusesV2 = {
  'unreviewed',
  'review_required',
  'confirmed',
  'rejected',
};

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
  });
  final String id, kind, importedAt, createdAt, source, sourceLabel;
  final String importBatchId, sourceRecordId, reviewStatus, season;
  final String opponentIdentityId, opponentDisplayName, result, notes;
  final String? occurredAt, observedAt;
  final double? confidence;
  final TacticalDeckV2 attackDeck, defenseDeck;

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
    if (!_exactV2(value, fields) ||
        value['version'] != 2 ||
        !_recordIdV2(value['match_id']) ||
        !{'attack', 'defense'}.contains(value['kind']) ||
        value['season'] is! String ||
        !_recordIdV2(value['opponent_identity_id']) ||
        value['opponent_display_name'] is! String ||
        (value['opponent_display_name'] as String).isEmpty ||
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
      opponentIdentityId: value['opponent_identity_id'] as String,
      opponentDisplayName: value['opponent_display_name'] as String,
      result: value['result'] as String,
      attackDeck: TacticalDeckV2.fromWire(
        Map<String, dynamic>.from(value['attack_deck'] as Map),
      ),
      defenseDeck: TacticalDeckV2.fromWire(
        Map<String, dynamic>.from(value['defense_deck'] as Map),
      ),
      notes: value['notes'] as String,
    );
  }
}

@immutable
class TacticalJokboV2 {
  const TacticalJokboV2({
    required this.id,
    required this.defenseDeck,
    required this.attackDeck,
  });
  final String id;
  final TacticalDeckV2 defenseDeck, attackDeck;
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
    if (!_exactV2(value, fields) ||
        value['version'] != 2 ||
        !_recordIdV2(value['jokbo_id']) ||
        value['wins'] is! int ||
        value['wins'] < 0 ||
        value['losses'] is! int ||
        value['losses'] < 0 ||
        value['notes'] is! String) {
      throw const FormatException('Invalid tactical v2 jokbo');
    }
    _timestampV2(value['created_at'], nullable: false);
    _timestampV2(value['imported_at'], nullable: false);
    _provenanceV2(value);
    return TacticalJokboV2(
      id: value['jokbo_id'] as String,
      defenseDeck: TacticalDeckV2.fromWire(
        Map<String, dynamic>.from(value['defense_deck'] as Map),
      ),
      attackDeck: TacticalDeckV2.fromWire(
        Map<String, dynamic>.from(value['attack_deck'] as Map),
      ),
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
  });
  final String id, currentDisplayName;
  final List<String> aliases;
  final List<String> nameTemplateIds;
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
    _timestampV2(value['first_observed_at']);
    _timestampV2(value['last_observed_at']);
    return TacticalOpponentIdentity(
      id: value['identity_id'] as String,
      currentDisplayName: value['current_display_name'] as String,
      aliases: List.unmodifiable(aliases.cast<String>()),
      nameTemplateIds: List.unmodifiable(templates.cast<String>()),
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
  });
  final String id, opponentIdentityId;
  final String? matchId;
  final TacticalDeckV2 deck;
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
    _timestampV2(value['occurred_at']);
    _timestampV2(value['observed_at']);
    _timestampV2(value['imported_at'], nullable: false);
    return TacticalDefenseSnapshot(
      id: value['snapshot_id'] as String,
      opponentIdentityId: value['opponent_identity_id'] as String,
      deck: TacticalDeckV2.fromWire(
        Map<String, dynamic>.from(value['deck'] as Map),
      ),
      matchId: value['match_id'] as String?,
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
  });
  final String signature;
  final int exposureCount,
      opponentCount,
      selectedCount,
      linkedMatchCount,
      wins,
      losses;
  final double? observedWinRate, wilson95Low, wilson95High;

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
  });
  final TacticalStatsPopulation population;
  final List<TacticalPublicSignatureStats> publicSignatures;
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
  });
  final String opponentIdentityId,
      publicSignature,
      attackSignature,
      lastBattleAt;
  final double ageHours, freshnessWeight;
  final bool stale, verifiedAfterLatestPublic;

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
        value['verified_after_latest_public'] is! bool) {
      throw const FormatException('Invalid tactical freshness evidence');
    }
    return TacticalFreshnessEvidence(
      opponentIdentityId: value['opponent_identity_id'] as String,
      publicSignature: value['public_signature'] as String,
      attackSignature: value['attack_signature'] as String,
      lastBattleAt: value['last_battle_at'] as String,
      ageHours: (value['age_hours'] as num).toDouble(),
      freshnessWeight: (value['freshness_weight'] as num).toDouble(),
      stale: value['stale'] as bool,
      verifiedAfterLatestPublic: value['verified_after_latest_public'] as bool,
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
  });
  final String defenseSignature, lastConfirmedAt;
  final double evidenceWeightShare;
  final int snapshotCount, distinctOpponentCount;

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
    TacticalDeckV2.fromWire(Map<String, dynamic>.from(value['deck'] as Map));
    return TacticalDefenseScenario(
      defenseSignature: value['defense_signature'] as String,
      evidenceWeightShare: (value['evidence_weight_share'] as num).toDouble(),
      snapshotCount: value['snapshot_count'] as int,
      distinctOpponentCount: value['distinct_opponent_count'] as int,
      lastConfirmedAt: value['last_confirmed_at'] as String,
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
  });
  final String attackSignature;
  final double score;
  final int observedMatchCount;
  final double? observedWinRate;
  final List<String> missingStudentIds;
  final bool allKnownStudentsOwned;

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
        value['deck'] is! Map) {
      throw const FormatException('Invalid tactical attack recommendation');
    }
    TacticalDeckV2.fromWire(Map<String, dynamic>.from(value['deck'] as Map));
    return TacticalAttackRecommendation(
      attackSignature: value['attack_signature'] as String,
      score: (value['score'] as num).toDouble(),
      observedMatchCount: value['observed_match_count'] as int,
      observedWinRate: (rate as num?)?.toDouble(),
      missingStudentIds: List.unmodifiable(
        (value['missing_student_ids'] as List).cast<String>(),
      ),
      allKnownStudentsOwned: value['all_known_students_owned'] as bool,
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
  });
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
    return false;
  } catch (_) {
    return false;
  }
}
