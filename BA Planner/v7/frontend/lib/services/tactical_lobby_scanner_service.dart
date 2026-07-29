import 'scanner_service.dart';

class TacticalLobbySlotObservation {
  const TacticalLobbySlotObservation({
    required this.position,
    required this.studentId,
    required this.state,
    required this.confidence,
    required this.reviewStatus,
  });

  final int position;
  final String? studentId;
  final String state;
  final double? confidence;
  final String reviewStatus;

  factory TacticalLobbySlotObservation.fromWire(Map<String, dynamic> wire) {
    if (wire['version'] != 2 ||
        wire['position'] is! int ||
        (wire['student_id'] != null && wire['student_id'] is! String) ||
        wire['state'] is! String ||
        (wire['confidence'] != null && wire['confidence'] is! num) ||
        wire['review_status'] is! String) {
      throw const FormatException('Invalid tactical lobby slot');
    }
    return TacticalLobbySlotObservation(
      position: wire['position'] as int,
      studentId: wire['student_id'] as String?,
      state: wire['state'] as String,
      confidence: (wire['confidence'] as num?)?.toDouble(),
      reviewStatus: wire['review_status'] as String,
    );
  }
}

class TacticalLobbyOpponentRow {
  TacticalLobbyOpponentRow({
    required this.index,
    required this.rank,
    required this.proposedRank,
    required this.displayName,
    required this.proposedDisplayName,
    required this.strikers,
    required this.specials,
    required this.confidence,
    required this.reviewStatus,
  });

  final int index;
  final int? rank;
  final int proposedRank;
  final String? displayName;
  final String? proposedDisplayName;
  final List<TacticalLobbySlotObservation> strikers;
  final List<TacticalLobbySlotObservation> specials;
  final double confidence;
  final String reviewStatus;

  factory TacticalLobbyOpponentRow.fromWire(Map<String, dynamic> wire) {
    final rank = wire['rank'];
    final opponent = wire['opponent'];
    final deck = wire['public_defense'];
    if (wire['index'] is! int ||
        rank is! Map ||
        opponent is! Map ||
        deck is! Map ||
        rank['proposed_value'] is! int ||
        (rank['value'] != null && rank['value'] is! int) ||
        (opponent['display_name'] != null &&
            opponent['display_name'] is! String) ||
        (opponent['proposed_display_name'] != null &&
            opponent['proposed_display_name'] is! String) ||
        deck['version'] != 2 ||
        deck['strikers'] is! List ||
        (deck['strikers'] as List).length != 4 ||
        deck['specials'] is! List ||
        (deck['specials'] as List).length != 2 ||
        wire['confidence'] is! num ||
        wire['review_status'] is! String) {
      throw const FormatException('Invalid tactical lobby opponent row');
    }
    List<TacticalLobbySlotObservation> slots(Object? value) => (value as List)
        .map(
          (item) => TacticalLobbySlotObservation.fromWire(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
    return TacticalLobbyOpponentRow(
      index: wire['index'] as int,
      rank: rank['value'] as int?,
      proposedRank: rank['proposed_value'] as int,
      displayName: opponent['display_name'] as String?,
      proposedDisplayName: opponent['proposed_display_name'] as String?,
      strikers: slots(deck['strikers']),
      specials: slots(deck['specials']),
      confidence: (wire['confidence'] as num).toDouble(),
      reviewStatus: wire['review_status'] as String,
    );
  }
}

class TacticalLobbyScanCandidate {
  TacticalLobbyScanCandidate({
    required this.source,
    required this.roiProfileId,
    required this.observedAt,
    required this.screenHash,
    required this.refreshGeneration,
    required this.frameComplete,
    required this.currentRank,
    required this.proposedCurrentRank,
    required this.rows,
    required this.overallConfidence,
    required this.reviewStatus,
  });

  final ScannerCandidate source;
  final String roiProfileId;
  final DateTime observedAt;
  final String screenHash;
  final String refreshGeneration;
  final bool frameComplete;
  final int? currentRank;
  final int proposedCurrentRank;
  final List<TacticalLobbyOpponentRow> rows;
  final double overallConfidence;
  final String reviewStatus;

  factory TacticalLobbyScanCandidate.fromScannerCandidate(
    ScannerCandidate candidate,
  ) {
    final wire = candidate.payload;
    final currentRank = wire['current_rank'];
    final rows = wire['rows'];
    if (candidate.kind != ScannerKind.tacticalLobby ||
        wire['version'] != 1 ||
        wire['roi_profile_id'] is! String ||
        wire['observed_at'] is! String ||
        wire['screen_hash'] is! String ||
        wire['refresh_generation'] is! String ||
        wire['frame_complete'] is! bool ||
        currentRank is! Map ||
        currentRank['proposed_value'] is! int ||
        (currentRank['value'] != null && currentRank['value'] is! int) ||
        rows is! List ||
        rows.length != 3 ||
        wire['overall_confidence'] is! num ||
        wire['review_status'] is! String) {
      throw const FormatException('Invalid tactical lobby candidate');
    }
    return TacticalLobbyScanCandidate(
      source: candidate,
      roiProfileId: wire['roi_profile_id'] as String,
      observedAt: DateTime.parse(wire['observed_at'] as String),
      screenHash: wire['screen_hash'] as String,
      refreshGeneration: wire['refresh_generation'] as String,
      frameComplete: wire['frame_complete'] as bool,
      currentRank: currentRank['value'] as int?,
      proposedCurrentRank: currentRank['proposed_value'] as int,
      rows: rows
          .map(
            (item) => TacticalLobbyOpponentRow.fromWire(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      overallConfidence: (wire['overall_confidence'] as num).toDouble(),
      reviewStatus: wire['review_status'] as String,
    );
  }
}

/// P8 boundary: capture/review only. Tactical persistence is deliberately P9.
class TacticalLobbyScannerService {
  const TacticalLobbyScannerService(this.scanner);

  final ScannerService scanner;

  Future<ScannerSession> start(String targetId) =>
      scanner.startScannerSession(ScannerKind.tacticalLobby, targetId);

  TacticalLobbyScanCandidate decode(ScannerCandidate candidate) =>
      TacticalLobbyScanCandidate.fromScannerCandidate(candidate);
}
