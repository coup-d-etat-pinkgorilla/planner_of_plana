import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared tactical fixture has matching Dart validation results', () {
    final fixture =
        jsonDecode(
              File(
                '../contracts/fixtures/tactical_protocol_v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    for (final item in fixture['cases'] as List) {
      final entry = Map<String, dynamic>.from(item as Map);
      expect(
        isValidTacticalProtocolMessage(entry['message']),
        entry['valid'],
        reason: entry['name'] as String,
      );
    }
  });
  test('deck preserves fixed slots order and nulls', () {
    final deck = TacticalDeck.fromWire({
      'version': 1,
      'strikers': ['hoshino', null, 'shiroko', null],
      'specials': ['ayane', null],
    });
    expect(deck.toWire()['strikers'], ['hoshino', null, 'shiroko', null]);
    expect(deck.toWire()['specials'], ['ayane', null]);
  });
  test('deck rejects wrong counts and duplicates', () {
    expect(
      () => TacticalDeck(strikers: const [], specials: const []),
      throwsFormatException,
    );
    expect(
      () => TacticalDeck(
        strikers: const ['a', 'a', null, null],
        specials: const [null, null],
      ),
      throwsFormatException,
    );
  });
  test('match wire direction and nullable date remain explicit', () {
    final empty = TacticalDeck.empty();
    final match = TacticalMatch(
      id: 'm1',
      kind: 'defense',
      occurredOn: null,
      season: ' S ',
      opponent: ' Rival ',
      result: 'loss',
      attackDeck: empty,
      defenseDeck: empty,
      notes: ' n ',
    );
    expect(match.toWire(), containsPair('kind', 'defense'));
    expect(match.toWire(), containsPair('occurred_on', null));
    expect(match.toWire(), containsPair('opponent', 'Rival'));
  });

  test('strict validator rejects malformed IDs, states, and errors', () {
    Map<String, dynamic> request(String method, Map<String, dynamic> payload) =>
        {
          'protocol': 1,
          'id': 'request',
          'type': 'request',
          'method': method,
          'payload': payload,
        };

    expect(
      isValidTacticalProtocolMessage(
        request('tactical.match.delete', {
          'profile_id': '000000000000000000000001',
          'expected_revision': 0,
          'idempotency_key': 'delete',
          'match_id': '',
        }),
      ),
      isFalse,
    );
    expect(
      isValidTacticalProtocolMessage({
        'protocol': 1,
        'id': 'state',
        'type': 'response',
        'method': 'tactical.state.get',
        'payload': {
          'version': 1,
          'profile_id': 'not-a-profile',
          'revision': 0,
          'matches': [],
          'jokbo': [],
        },
      }),
      isFalse,
    );
    expect(
      isValidTacticalProtocolMessage({
        'protocol': 1,
        'id': 'error',
        'type': 'response',
        'method': 'tactical.state.get',
        'payload': {
          'error': {'code': 'corrupt_data', 'message': 'bad'},
        },
      }),
      isFalse,
    );
  });

  test(
    'MockAppService tactical CRUD and revision conflict are deterministic',
    () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final profile = (await service.listProfiles()).single;
      final deck = TacticalDeck(
        strikers: const ['aru', null, null, null],
        specials: const ['ayane', null],
      );
      final match = TacticalMatch(
        id: 'mock-match',
        kind: 'attack',
        occurredOn: '2026-07-23',
        season: 'S1',
        opponent: 'Rival',
        result: 'win',
        attackDeck: deck,
        defenseDeck: TacticalDeck.empty(),
        notes: 'mock',
      );

      expect(await service.saveTacticalMatch(profile.id, match, 0, 'save'), 1);
      expect(
        () => service.saveTacticalMatch(profile.id, match, 0, 'stale'),
        throwsStateError,
      );
      expect(
        (await service.loadTacticalState(profile.id)).matches.single.id,
        'mock-match',
      );
      expect(
        await service.deleteTacticalMatch(profile.id, match.id, 1, 'delete'),
        2,
      );
      expect((await service.loadTacticalState(profile.id)).matches, isEmpty);
    },
  );
}
