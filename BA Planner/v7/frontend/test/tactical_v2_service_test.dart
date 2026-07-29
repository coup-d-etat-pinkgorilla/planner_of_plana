import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared tactical v2 fixture has matching Dart validation results', () {
    final fixture =
        jsonDecode(
              File(
                '../contracts/fixtures/tactical_protocol_v2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    for (final item in fixture['cases'] as List) {
      final entry = Map<String, dynamic>.from(item as Map);
      expect(
        isValidTacticalV2ProtocolMessage(entry['message']),
        entry['valid'],
        reason: entry['name'] as String,
      );
    }
  });

  Map<String, dynamic> slot({
    required int position,
    String? studentId,
    String state = 'unknown',
    bool wildcard = false,
  }) => {
    'version': 2,
    'position': position,
    'student_id': studentId,
    'state': state,
    'source': 'v6_import',
    'confidence': null,
    'review_status': studentId == null && !wildcard
        ? 'unreviewed'
        : 'confirmed',
    'wildcard': wildcard,
  };

  test('slot observations preserve unknown, empty and wildcard separately', () {
    final unknown = TacticalSlotObservation.fromWire(slot(position: 0));
    final empty = TacticalSlotObservation.fromWire(
      slot(position: 1, state: 'empty'),
    );
    final wildcard = TacticalSlotObservation.fromWire(
      slot(position: 2, wildcard: true),
    );
    expect(unknown.state, 'unknown');
    expect(empty.state, 'empty');
    expect(wildcard.wildcard, isTrue);
    expect([
      unknown.studentId,
      empty.studentId,
      wildcard.studentId,
    ], everyElement(isNull));
  });

  test('observed slot requires a canonical ID and hidden slot rejects one', () {
    expect(
      () =>
          TacticalSlotObservation.fromWire(slot(position: 0, state: 'manual')),
      throwsFormatException,
    );
    expect(
      () => TacticalSlotObservation.fromWire(
        slot(position: 0, studentId: 'hoshino'),
      ),
      throwsFormatException,
    );
    final observed = TacticalSlotObservation.fromWire(
      slot(position: 0, studentId: 'hoshino', state: 'manual'),
    );
    expect(observed.studentId, 'hoshino');
  });

  test('deck enforces fixed ordered positions and unique student IDs', () {
    Map<String, dynamic> deck({bool duplicate = false}) => {
      'version': 2,
      'strikers': [
        slot(position: 0, studentId: 'hoshino', state: 'manual'),
        slot(
          position: 1,
          studentId: duplicate ? 'hoshino' : null,
          state: duplicate ? 'manual' : 'unknown',
        ),
        slot(position: 2),
        slot(position: 3),
      ],
      'specials': [slot(position: 0), slot(position: 1)],
    };
    expect(TacticalDeckV2.fromWire(deck()).strikers, hasLength(4));
    expect(
      () => TacticalDeckV2.fromWire(deck(duplicate: true)),
      throwsFormatException,
    );
    final wrongOrder = deck();
    (wrongOrder['strikers'] as List)[1] = slot(position: 2);
    expect(() => TacticalDeckV2.fromWire(wrongOrder), throwsFormatException);
  });

  test('P9 mutation results keep refresh and link ambiguity typed', () {
    final committed = TacticalLobbyCommitResult.fromWire({
      'revision': 2,
      'scan_id': 'scan-1',
      'candidate_ids': ['candidate-1', 'candidate-2', 'candidate-3'],
      'created': true,
    });
    expect(committed.candidateIds, hasLength(3));
    expect(committed.created, isTrue);

    final ambiguous = TacticalLinkResult.fromWire({
      'revision': 4,
      'status': 'ambiguous',
      'candidate_id': null,
      'match_id': 'match-1',
      'candidate_count': 2,
    });
    expect(ambiguous.status, 'ambiguous');
    expect(ambiguous.candidateCount, 2);
    expect(ambiguous.candidateId, isNull);
  });
}
