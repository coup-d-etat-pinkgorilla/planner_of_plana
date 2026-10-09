import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> copy(Object value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture =
      jsonDecode(
            File(
              '../contracts/fixtures/current_history_v1.json',
            ).readAsStringSync(),
          )
          as Map;
  for (final raw in fixture['cases'] as List) {
    final row = Map<String, dynamic>.from(raw as Map);
    test('strict history fixture ${row['id']}', () {
      final wire = copy(row['history'] as Map);
      if (row['valid'] == true) {
        final parsed = RepositoryCurrentHistory.fromWire(wire);
        expect(parsed.toWire(), wire);
        expect(parsed.events.length, (wire['events'] as List).length);
        wire['events'].clear();
        expect(parsed.toWire(), row['history']);
        parsed.toWire()['events'].clear();
        expect(parsed.toWire(), row['history']);
        if (parsed.events.isNotEmpty) {
          expect(
            () => parsed.events.add(parsed.events.first),
            throwsUnsupportedError,
          );
          final event = parsed.events.first;
          if (event.studentChanges.isNotEmpty) {
            final student = event.studentChanges.first.after.value!;
            expect(student.provenance, {'level': 'user_review'});
            expect(() => student.values['level'] = 999, throwsUnsupportedError);
          }
        }
      } else {
        expect(
          () => RepositoryCurrentHistory.fromWire(wire),
          throwsFormatException,
        );
      }
    });
  }

  test('typed missing/null/zero and whole student missing field survive', () {
    final h = RepositoryCurrentHistory.fromWire(
      copy(fixture['cases'][1]['history'] as Map),
    );
    final changes = h.events[1].inventoryChanges;
    final removed = changes.firstWhere((item) => item.resourceKey == 'zero');
    expect(removed.before.present, isTrue);
    expect(removed.before.value, '0');
    expect(removed.after.present, isFalse);
    expect(removed.after.value, isNull);
    final unknown = changes.firstWhere(
      (item) => item.resourceKey == 'future-present',
    );
    expect(unknown.before.present, isTrue);
    expect(unknown.before.value, isNull);
    expect(unknown.after.value, '0');
    final s = h.events[1].studentChanges.single;
    expect(s.before.value!.values.containsKey('bond_rank'), isTrue);
    expect(s.after.value!.values.containsKey('bond_rank'), isFalse);
    final summary = h.summarize('aaaaaaaaaaaaaaaaaaaaaaaa', 4);
    expect(summary.toWire(), fixture['summary']);
    expect(summary.totalScanSessionCount, 1);
    expect(summary.totalCounts['scan'], 2);
    expect(h.events[2].scanKind, ' 未知 Kind ');
    expect(h.events[2].inventoryScanProfile, ' 未来 profile ');
  });

  test('summary protocol is strict and preserves old mutation response', () {
    for (final case_ in fixture['messages'] as List) {
      expect(
        isValidRepositoryProtocolMessage(copy(case_['message'] as Map)),
        case_['valid'],
        reason: case_['id'] as String,
      );
    }
    final request = {
      'protocol': 1,
      'id': 'summary',
      'type': 'request',
      'method': 'repository.history.summary',
      'payload': {
        'profile_ids': ['aaaaaaaaaaaaaaaaaaaaaaaa'],
      },
    };
    expect(isValidRepositoryProtocolMessage(request), isTrue);
    final response = {
      ...request,
      'type': 'response',
      'payload': {
        'profiles': [fixture['summary']],
      },
    };
    expect(isValidRepositoryProtocolMessage(response), isTrue);
    final payload = copy(response['payload'] as Map);
    payload['profiles'][0]['total_event_count'] = true;
    expect(
      isValidRepositorySuccessPayload('repository.history.summary', payload),
      isFalse,
    );
    for (final ids in [
      <String>[],
      ['aaaaaaaaaaaaaaaaaaaaaaaa', 'aaaaaaaaaaaaaaaaaaaaaaaa'],
      List.filled(129, 'aaaaaaaaaaaaaaaaaaaaaaaa'),
    ]) {
      expect(() => RepositoryHistorySummaryRequest(ids), throwsFormatException);
    }
    final malformed = copy(fixture['summary'] as Map)..['unexpected'] = null;
    expect(
      () => RepositoryHistorySummary.fromWire(malformed),
      throwsFormatException,
    );
    expect(
      isValidRepositorySuccessPayload('repository.students.update', {
        'revision': 1,
      }),
      isTrue,
    );
    expect(
      isValidRepositorySuccessPayload('repository.students.update', {
        'revision': 1,
        'history_sequence': 1,
      }),
      isFalse,
    );
  });

  test('UTC has exactly six digits and invalid rolled dates are rejected', () {
    expect(
      historyUtcTimestamp(DateTime.utc(2026, 10, 9)),
      '2026-10-09T00:00:00.000000Z',
    );
    expect(
      historyUtcTimestamp(DateTime.utc(2026, 10, 9, 0, 0, 0, 1, 5)),
      '2026-10-09T00:00:00.001005Z',
    );
    final h = copy(fixture['cases'][1]['history'] as Map);
    h['events'][0]['recorded_at'] = '2026-02-30T00:00:00.000000Z';
    expect(() => RepositoryCurrentHistory.fromWire(h), throwsFormatException);
  });

  test('confirmed provenance is retained; duplicate student IDs reject', () {
    final wire = {
      'version': 1,
      'student_id': 'aru',
      'values': {'bond_rank': null},
      'provenance': {'bond_rank': 'review'},
    };
    expect(ConfirmedStudentState.fromWire(wire).toWire(), wire);
    final state = {
      'profile_id': 'aaaaaaaaaaaaaaaaaaaaaaaa',
      'revision': 0,
      'students': [wire, wire],
      'inventory': {'version': 1, 'entries': <dynamic>[]},
      'goals': {'version': 1, 'goals': <dynamic>[]},
    };
    expect(() => RepositoryState.fromWire(state), throwsFormatException);
  });

  test(
    'Mock new/manual/nochange/replay/meta/read paths match the history policy',
    () async {
      var calls = 0;
      final at = DateTime.utc(2026, 10, 9, 14, 25, 0, 123, 456);
      final mock = MockAppService(
        profiles: const [],
        historyClock: () {
          calls++;
          return at;
        },
      );
      addTearDown(mock.dispose);
      final profile = await mock.createProfile('History', 'new');
      final id = profile.id;
      Future<RepositoryHistorySummary> load() async =>
          (await mock.loadRepositoryHistorySummary([id])).profiles.single;
      expect((await load()).coverage.origin, 'empty');
      expect(calls, 0);
      final students = [
        ConfirmedStudentState.fromValues('aru', {
          'level': 0,
          'bond_rank': null,
        }),
      ];
      expect(await mock.saveRepositoryStudents(id, students, 0, 'students'), 1);
      final first = (await load()).toWire();
      expect(await mock.saveRepositoryStudents(id, students, 0, 'students'), 1);
      expect((await load()).toWire(), first);
      expect(calls, 1);
      await expectLater(
        mock.saveRepositoryStudents(id, [], 0, 'students'),
        throwsStateError,
      );
      await expectLater(
        mock.saveRepositoryStudents(id, students, 0, 'stale'),
        throwsStateError,
      );
      final inventory = RepositoryInventoryState.fromEntries([
        {'key': 'unknown', 'quantity': null},
        {'key': 'zero', 'quantity': '0'},
      ]);
      expect(
        await mock.saveRepositoryInventory(id, inventory, 1, 'inventory'),
        2,
      );
      expect(
        await mock.saveRepositoryInventory(id, inventory, 2, 'nochange'),
        3,
      );
      expect((await load()).totalCounts, {
        'scan': 0,
        'manual': 3,
        'import': 0,
        'unattributed': 0,
      });
      expect((await load()).lastManualAt, '2026-10-09T14:25:00.123456Z');
      expect((await load()).totalScanSessionCount, 0);
      await mock.renameProfile(id, 'Renamed', 3, 'rename');
      expect((await load()).historySequence, 3);
      expect((await load()).revision, 4);
      expect(calls, 3);
      final duplicate = [students.single, students.single];
      await expectLater(
        mock.saveRepositoryStudents(id, duplicate, 4, 'duplicate'),
        throwsFormatException,
      );
      expect((await load()).historySequence, 3);
    },
  );

  test('Mock legacy summary read does not trigger plan migration', () async {
    const id = 'aaaaaaaaaaaaaaaaaaaaaaaa';
    final mock = MockAppService(
      profiles: const [
        RepositoryProfile(
          id: id,
          displayName: 'Legacy',
          revision: 4,
          selected: true,
        ),
      ],
      repositoryStates: {
        id: {
          'profile_id': id,
          'revision': 4,
          'students': [
            {
              'version': 1,
              'student_id': 'aru',
              'values': {'level': 80},
            },
          ],
          'inventory': {'version': 1, 'entries': <dynamic>[]},
          'goals': {'version': 1, 'goals': <dynamic>[]},
        },
      },
      historyClock: () => DateTime.utc(2026, 10, 9),
    );
    addTearDown(mock.dispose);
    final empty = (await mock.loadRepositoryHistorySummary([
      id,
    ])).profiles.single;
    expect(empty.revision, 4);
    expect(empty.coverage.origin, 'unrecorded');
    final state = await mock.loadRepositoryState(id);
    expect(state.revision, 5);
    await mock.saveRepositoryStudents(id, state.students, 5, 'manual');
    final saved = (await mock.loadRepositoryHistorySummary([
      id,
    ])).profiles.single;
    expect(saved.coverage.origin, 'legacy');
    expect(saved.coverage.baselineAt, isNull);
    expect(saved.totalCounts['manual'], 1);
  });

  test(
    'old Mock scanner writes stay unattributed and following manual writes reconstruct',
    () async {
      final mock = MockAppService(
        historyClock: () => DateTime.utc(2026, 10, 10),
      );
      addTearDown(mock.dispose);
      final profile = await mock.createProfile(
        'Scanner compatibility',
        'scanner-history',
      );
      final id = profile.id;
      await mock.saveRepositoryStudents(
        id,
        [
          ConfirmedStudentState.fromValues('aru', {'level': 1}),
        ],
        0,
        'manual',
      );
      final session = await mock.startScannerSession(
        ScannerKind.student,
        'mock-window',
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final candidate = (await mock.scannerSnapshot(session)).candidates.single;
      await mock.commitScannerCandidate(
        session,
        candidate,
        profileId: id,
        expectedRepositoryRevision: 1,
        idempotencyKey: 'old-scan',
      );
      var summary = (await mock.loadRepositoryHistorySummary([
        id,
      ])).profiles.single;
      expect(summary.totalCounts, {
        'scan': 0,
        'manual': 1,
        'import': 0,
        'unattributed': 1,
      });
      expect(summary.totalScanSessionCount, 0);
      // No-change application is still an application at the old internal port.
      await mock.commitScannerCandidate(
        session,
        candidate,
        profileId: id,
        expectedRepositoryRevision: 2,
        idempotencyKey: 'old-nochange',
      );
      final state = await mock.loadRepositoryState(id);
      await mock.saveRepositoryStudents(id, state.students, 3, 'manual-after');
      summary = (await mock.loadRepositoryHistorySummary([id])).profiles.single;
      expect(summary.totalCounts, {
        'scan': 0,
        'manual': 2,
        'import': 0,
        'unattributed': 2,
      });
      expect(summary.historySequence, 4);
    },
  );
}
