import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> copied(Object value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
Map<String, dynamic> stateWire(String id, int revision, Map current) => {
  'profile_id': id,
  'revision': revision,
  'students': current['students'],
  'inventory': {
    'version': 1,
    'entries': [
      for (final r in current['inventory'] as List)
        {'key': r['resource_key'], 'quantity': r['quantity']},
    ],
  },
  'goals': {'version': 1, 'goals': <dynamic>[]},
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final f = copied(
    jsonDecode(
      File(
        '../contracts/fixtures/repository_history_query_v1.json',
      ).readAsStringSync(),
    ),
  );
  final id = f['profile_id'] as String, revision = f['revision'] as int;
  for (final raw in f['cases'] as List) {
    final row = copied(raw);
    test('history query shared policy ${row['id']}', () async {
      final history = row.containsKey('history')
          ? row['history']
          : f['history'];
      final current = row.containsKey('current')
          ? row['current']
          : f['current'];
      final state = RepositoryState.fromWire(
        stateWire(id, revision, current as Map),
      );
      final h = history == null
          ? null
          : RepositoryCurrentHistory.fromWire(copied(history));
      RepositoryHistoryQueryResult result;
      if (row['method'] == 'events') {
        final request = RepositoryHistoryEventsRequest.fromWire(
          copied(row['request']),
        );
        result = repositoryHistoryEvents(state, h, request);
      } else {
        final request = RepositoryHistoryDiffRequest.fromWire(
          copied(row['request']),
        );
        result = repositoryHistoryDiff(state, h, request);
      }
      expect(result.toWire(), row['result']);
      final method = 'repository.history.${row['method']}';
      expect(
        isValidRepositoryProtocolMessage({
          'protocol': 1,
          'id': 'fixture',
          'type': 'request',
          'method': method,
          'payload': row['request'],
        }),
        isTrue,
      );
      expect(
        isValidRepositorySuccessPayload(method, copied(row['result'])),
        isTrue,
      );
      final exported = result.toWire();
      exported['coverage']['reasons'].add('mutation');
      expect(result.toWire(), row['result']);
      expect(
        () => result.coverage.reasons.add('mutation'),
        throwsUnsupportedError,
      );
      final mock = MockAppService(
        profiles: [
          RepositoryProfile(
            id: id,
            displayName: 'Fixture',
            revision: revision,
            selected: true,
          ),
        ],
        repositoryStates: {id: stateWire(id, revision, current)},
        repositoryHistories: h == null ? null : {id: h},
      );
      final mocked = row['method'] == 'events'
          ? await mock.loadRepositoryHistoryEvents(
              RepositoryHistoryEventsRequest.fromWire(copied(row['request'])),
            )
          : await mock.loadRepositoryHistoryDiff(
              RepositoryHistoryDiffRequest.fromWire(copied(row['request'])),
            );
      expect(mocked.toWire(), row['result']);
      mock.dispose();
    });
  }
  for (final raw in f['invalid_requests'] as List) {
    final row = copied(raw);
    test('history query invalid ${row['id']}', () {
      final state = RepositoryState.fromWire(
            stateWire(id, revision, f['current'] as Map),
          ),
          h = RepositoryCurrentHistory.fromWire(copied(f['history']));
      expect(
        () => row['method'] == 'events'
            ? repositoryHistoryEvents(
                state,
                h,
                RepositoryHistoryEventsRequest.fromWire(copied(row['request'])),
              )
            : repositoryHistoryDiff(
                state,
                h,
                RepositoryHistoryDiffRequest.fromWire(copied(row['request'])),
              ),
        throwsFormatException,
      );
    });
  }
  for (final raw in f['invalid_results'] as List) {
    final row = copied(raw);
    test('history query strict response ${row['id']}', () {
      expect(
        () => row['method'] == 'events'
            ? RepositoryHistoryEventsResult.fromWire(copied(row['result']))
            : RepositoryHistoryDiffResult.fromWire(copied(row['result'])),
        throwsFormatException,
      );
      expect(
        isValidRepositorySuccessPayload(
          'repository.history.${row['method']}',
          copied(row['result']),
        ),
        isFalse,
      );
    });
  }
  test(
    'typed null filter and omitted filter are different; empty target disables bucket',
    () {
      final absent = RepositoryHistoryEventsRequest(profileId: id),
          null_ = RepositoryHistoryEventsRequest(
            profileId: id,
            inventoryScanProfile: null,
          );
      expect(absent.toWire().containsKey('inventory_scan_profile'), isFalse);
      expect(null_.toWire().containsKey('inventory_scan_profile'), isTrue);
      expect(null_.toWire()['inventory_scan_profile'], isNull);
      final diff = RepositoryHistoryDiffRequest(
        profileId: id,
        from: RepositoryHistoryEndpoint.sequence(7),
        to: RepositoryHistoryEndpoint.current(),
        studentIds: [],
        resourceKeys: ['a'],
      );
      final result = repositoryHistoryDiff(
        RepositoryState.fromWire(stateWire(id, revision, f['current'] as Map)),
        RepositoryCurrentHistory.fromWire(copied(f['history'])),
        diff,
      );
      expect(result.studentChanges, isEmpty);
      expect(result.inventoryChanges.single.delta, '11');
      expect(result.fromPoint.inventory, {'a': '21'});
      expect(
        () => result.fromPoint.inventory['a'] = '0',
        throwsUnsupportedError,
      );
    },
  );
  test(
    'mock manual cursor anchor, replay and metadata do not change earlier cohort',
    () async {
      var clock = DateTime.utc(2026, 1, 1);
      final mock = MockAppService(historyClock: () => clock);
      final profile = await mock.createProfile('Query', 'create');
      Future<int> save(String value, int revision, String key) =>
          mock.saveRepositoryInventory(
            profile.id,
            RepositoryInventoryState.fromEntries([
              {'key': 'a', 'quantity': value},
            ]),
            revision,
            key,
          );
      for (var i = 0; i < 4; i++) {
        clock = clock.add(const Duration(seconds: 1));
        await save('$i', i, '$i');
      }
      final first = await mock.loadRepositoryHistoryEvents(
        RepositoryHistoryEventsRequest(profileId: profile.id, limit: 2),
      );
      clock = clock.add(const Duration(seconds: 1));
      await save('9', 4, 'new');
      expect(await save('9', 4, 'new'), 5);
      final page = await mock.loadRepositoryHistoryEvents(
        RepositoryHistoryEventsRequest(
          profileId: profile.id,
          limit: 200,
          cursor: first.nextCursor,
        ),
      );
      expect(page.historySequence, 4);
      expect(page.matchingEventCount, 4);
      expect(page.events.map((e) => e.sequence), [3, 4]);
      final d = await mock.loadRepositoryHistoryDiff(
        RepositoryHistoryDiffRequest(
          profileId: profile.id,
          from: RepositoryHistoryEndpoint.sequence(1),
          to: RepositoryHistoryEndpoint.current(),
          resourceKeys: ['a'],
          studentIds: [],
        ),
      );
      expect(d.inventoryChanges.single.delta, '9');
      expect(d.scanSessionCount, 0);
      await mock.renameProfile(profile.id, 'Renamed', 5, 'name');
      final after = await mock.loadRepositoryHistoryEvents(
        RepositoryHistoryEventsRequest(profileId: profile.id),
      );
      expect(after.historySequence, 5);
      expect(after.revision, 6);
      await expectLater(
        mock.loadRepositoryHistoryEvents(
          RepositoryHistoryEventsRequest(
            profileId: profile.id,
            cursor: first.nextCursor,
            source: 'scan',
          ),
        ),
        throwsFormatException,
      );
      mock.dispose();
    },
  );
  test(
    'clock rollback suppresses time endpoint and sequence delta without changing state',
    () {
      final wire = copied(f['history']);
      wire['events'][7]['recorded_at'] = '2026-01-01T00:00:01.000000Z';
      wire['last_applied_at']['manual'] = '2026-01-01T00:00:01.000000Z';
      final h = RepositoryCurrentHistory.fromWire(wire),
          state = RepositoryState.fromWire(
            stateWire(id, revision, f['current'] as Map),
          );
      final d = repositoryHistoryDiff(
        state,
        h,
        RepositoryHistoryDiffRequest(
          profileId: id,
          from: RepositoryHistoryEndpoint.sequence(2),
          to: RepositoryHistoryEndpoint.current(),
          resourceKeys: ['a'],
          studentIds: [],
        ),
      );
      expect(d.coverage.reasons, contains('clock_rollback'));
      expect(d.inventoryChanges.single.delta, isNull);
      expect(d.toPoint.inventory['a'], '32');
    },
  );
  test(
    'query refuses malformed cursor and cursor expires after age compaction',
    () async {
      final h = RepositoryCurrentHistory.fromWire(copied(f['history'])),
          state = RepositoryState.fromWire(
            stateWire(id, revision, f['current'] as Map),
          );
      final first = repositoryHistoryEvents(
        state,
        h,
        RepositoryHistoryEventsRequest(profileId: id, limit: 2),
      );
      final mock = MockAppService(
        profiles: [
          RepositoryProfile(
            id: id,
            displayName: 'Fixture',
            revision: revision,
            selected: true,
          ),
        ],
        repositoryStates: {id: stateWire(id, revision, f['current'] as Map)},
        repositoryHistories: {id: h},
        historyClock: () => DateTime.utc(2027, 1, 2),
      );
      final live = await mock.loadRepositoryState(id);
      await mock.saveRepositoryInventory(
        id,
        state.inventory,
        live.revision,
        'prune',
      );
      await expectLater(
        mock.loadRepositoryHistoryEvents(
          RepositoryHistoryEventsRequest(
            profileId: id,
            cursor: first.nextCursor,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'reason',
            'history_cursor_expired',
          ),
        ),
      );
      for (final cursor in ['!', '${first.nextCursor}=', 'W10']) {
        expect(
          () => repositoryHistoryEvents(
            state,
            h,
            RepositoryHistoryEventsRequest(profileId: id, cursor: cursor),
          ),
          throwsFormatException,
        );
      }
      mock.dispose();
    },
  );
}
