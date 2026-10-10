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
    // FB-2b intended change: the shared summary now has 13 keys (required nullable last_scan_at).
    expect(summary.toWire(), fixture['summary']);
    expect(summary.toWire().length, 13);
    expect(summary.lastScanAt, h.toWire()['last_applied_at']['scan']);
    expect(summary.lastScanAt, fixture['summary']['last_scan_at']);
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
    // FB-2b: last_scan_at is required (no missing-key fallback) and null iff scan count is 0.
    final missing = copy(fixture['summary'] as Map)..remove('last_scan_at');
    expect(
      () => RepositoryHistorySummary.fromWire(missing),
      throwsFormatException,
    );
    final nulled = copy(response['payload'] as Map);
    nulled['profiles'][0]['last_scan_at'] = null;
    expect(
      isValidRepositorySuccessPayload('repository.history.summary', nulled),
      isFalse,
    );
    final old12 = copy(response['payload'] as Map);
    (old12['profiles'][0] as Map).remove('last_scan_at');
    expect(
      isValidRepositorySuccessPayload('repository.history.summary', old12),
      isFalse,
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
    'seeded unattributed history is not reclassified; new Mock scanner commits record scan once',
    () async {
      const id = 'aaaaaaaaaaaaaaaaaaaaaaaa';
      var calls = 0;
      final at = DateTime.utc(2026, 10, 10, 9, 30);
      final initial = <String, dynamic>{
        'profile_id': id,
        'revision': 1,
        'students': [
          {
            'version': 1,
            'student_id': 'aru',
            'values': {'level': 1},
          },
        ],
        'inventory': {'version': 1, 'entries': <dynamic>[]},
        'goals': {'version': 1, 'goals': <dynamic>[]},
      };
      // History written before S-FB2b by the old four-argument internal port.
      final seeded = RepositoryCurrentHistory.empty().appendManual(
        RepositoryState.fromWire({
          ...initial,
          'revision': 0,
          'students': <dynamic>[],
        }),
        RepositoryState.fromWire(initial),
        'students',
        DateTime.utc(2026, 10, 9),
        source: 'unattributed',
      );
      final mock = MockAppService(
        profiles: const [
          RepositoryProfile(
            id: id,
            displayName: 'Scanner history',
            revision: 1,
            selected: true,
          ),
        ],
        repositoryStates: {id: initial},
        repositoryHistories: {id: seeded},
        historyClock: () {
          calls++;
          return at;
        },
      );
      addTearDown(mock.dispose);
      Future<RepositoryHistorySummary> load() async =>
          (await mock.loadRepositoryHistorySummary([id])).profiles.single;
      final state = await mock.loadRepositoryState(id);
      final session = await mock.startScannerSession(
        ScannerKind.student,
        'mock-window',
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final candidate = (await mock.scannerSnapshot(session)).candidates.single;
      final first = await mock.commitScannerCandidate(
        session,
        candidate,
        profileId: id,
        expectedRepositoryRevision: state.revision,
        idempotencyKey: 'scan-1',
      );
      expect(first, {
        'candidate_id': candidate.id,
        'candidate_revision': candidate.revision,
        'profile_id': id,
        'revision': state.revision + 1,
      });
      var summary = await load();
      expect(summary.totalCounts, {
        'scan': 1,
        'manual': 0,
        'import': 0,
        'unattributed': 1,
      });
      expect(summary.lastScanAt, historyUtcTimestamp(at));
      expect(summary.totalScanSessionCount, 1);
      expect(calls, 1);
      // Receipt replay: original response, no read/write/clock/history.
      expect(
        await mock.commitScannerCandidate(
          session,
          candidate,
          profileId: id,
          expectedRepositoryRevision: state.revision,
          idempotencyKey: 'scan-1',
        ),
        first,
      );
      expect((await load()).historySequence, 2);
      expect(calls, 1);
      // A same-value apply under a new key is still a scan application.
      await mock.commitScannerCandidate(
        session,
        candidate,
        profileId: id,
        expectedRepositoryRevision: state.revision + 1,
        idempotencyKey: 'scan-nochange',
      );
      final current = await mock.loadRepositoryState(id);
      await mock.saveRepositoryStudents(
        id,
        current.students,
        current.revision,
        'manual-after',
      );
      summary = await load();
      expect(summary.totalCounts, {
        'scan': 2,
        'manual': 1,
        'import': 0,
        'unattributed': 1,
      });
      expect(summary.totalScanSessionCount, 1);
      expect(summary.historySequence, 4);
      expect(summary.lastManualAt, historyUtcTimestamp(at));
      expect(calls, 3);
      final events = (await mock.loadRepositoryHistoryEvents(
        RepositoryHistoryEventsRequest(profileId: id),
      )).events;
      expect(events.map((e) => e.source), [
        'unattributed',
        'scan',
        'scan',
        'manual',
      ]);
      expect(events[1].scanKind, 'student');
      expect(events[1].inventoryScanProfile, isNull);
      expect(events[1].scanSessionId, session.id);
      expect(events[1].appliedStudentIds, ['aru']);
      expect(events[1].studentChanges.single.studentId, 'aru');
      expect(events[2].studentChanges, isEmpty);
      expect(events[2].appliedStudentIds, ['aru']);
    },
  );
}
