import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/services/tactical_lobby_scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes a typed P8 tactical lobby candidate', () {
    Map<String, dynamic> slot(int position, String? id) => {
      'version': 2,
      'position': position,
      'student_id': id,
      'state': id == null ? 'unknown' : 'visible_lobby',
      'source': id == null ? 'hidden_lobby' : 'visible_lobby',
      'confidence': id == null ? null : 0.99,
      'review_status': id == null ? 'review_required' : 'confirmed',
      'wildcard': false,
    };
    Map<String, dynamic> row(int index) => {
      'index': index,
      'rank': {
        'value': index + 5,
        'proposed_value': index + 5,
        'confidence': 0.99,
        'margin': 0.1,
        'review_status': 'confirmed',
      },
      'opponent': {
        'display_name': 'opponent-$index',
        'proposed_display_name': 'opponent-$index',
        'confidence': 0.98,
        'margin': 0.08,
        'review_status': 'confirmed',
      },
      'public_defense': {
        'version': 2,
        'strikers': [
          slot(0, 'tsubaki'),
          slot(1, null),
          slot(2, null),
          slot(3, null),
        ],
        'specials': [slot(0, 'hibiki'), slot(1, 'michiru_dress')],
      },
      'confidence': 0.98,
      'review_status': 'confirmed',
    };
    final source = ScannerCandidate(
      id: 'candidate',
      sessionId: 'session',
      generation: 1,
      revision: 1,
      kind: ScannerKind.tacticalLobby,
      payload: {
        'version': 1,
        'roi_profile_id': 'tactical-lobby-2560x1440-v1',
        'observed_at': '2026-07-29T00:00:00Z',
        'screen_hash': 'abc',
        'refresh_generation': 'refresh-abc',
        'frame_complete': true,
        'current_rank': {
          'value': 8,
          'proposed_value': 8,
          'confidence': 1.0,
          'margin': 0.2,
          'review_status': 'confirmed',
        },
        'rows': [row(0), row(1), row(2)],
        'overall_confidence': 0.98,
        'review_status': 'confirmed',
      },
      evidence: const [],
      reviewRequired: false,
      approved: false,
    );

    final candidate = TacticalLobbyScanCandidate.fromScannerCandidate(source);
    expect(candidate.currentRank, 8);
    expect(candidate.rows, hasLength(3));
    expect(candidate.rows.first.strikers.first.studentId, 'tsubaki');
    expect(
      candidate.rows.first.strikers
          .skip(1)
          .every((slot) => slot.studentId == null),
      isTrue,
    );
    expect(candidate.refreshGeneration, 'refresh-abc');
  });

  test('rejects a non-tactical candidate at the boundary', () {
    final source = ScannerCandidate(
      id: 'candidate',
      sessionId: 'session',
      generation: 1,
      revision: 1,
      kind: ScannerKind.student,
      payload: const {},
      evidence: const [],
      reviewRequired: false,
      approved: false,
    );
    expect(
      () => TacticalLobbyScanCandidate.fromScannerCandidate(source),
      throwsFormatException,
    );
  });
}
