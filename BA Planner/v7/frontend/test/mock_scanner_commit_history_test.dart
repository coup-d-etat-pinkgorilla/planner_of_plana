import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

// sfb2b Mock: the Mock scanner commit matches the Python scanner session
// (contracts/fixtures/scanner_commit_history_sfb2b_v1.json): approved identity
// upsert, frozen original bucket + exact7 public request, receipt-first replay,
// one internal scan application and no duplicate observer record.
Map<String, dynamic> copy(Object? value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

const _id = 'aaaaaaaaaaaaaaaaaaaaaaaa';

class _Rig {
  _Rig(this.mock, this.at);
  final MockAppService mock;
  final DateTime at;
  int clockCalls = 0;
}

_Rig _rig({required bool student, required Object initial}) {
  late _Rig rig;
  final at = DateTime.utc(2026, 10, 10, 9, 0, 0, 0, 7);
  final mock = MockAppService(
    profiles: const [
      RepositoryProfile(
        id: _id,
        displayName: 'SFB',
        revision: 0,
        selected: true,
      ),
    ],
    repositoryStates: {
      _id: {
        'profile_id': _id,
        'revision': 0,
        'students': student ? initial : <dynamic>[],
        'inventory': student
            ? {'version': 1, 'entries': <dynamic>[]}
            : initial,
        'goals': {'version': 1, 'goals': <dynamic>[]},
      },
    },
    historyClock: () {
      rig.clockCalls++;
      return at;
    },
  );
  return rig = _Rig(mock, at);
}

Future<(ScannerSession, ScannerCandidate)> _scan(
  MockAppService mock, {
  required bool student,
  required String? rawProfile,
  required Map<String, dynamic> candidate,
  required Map<String, dynamic> reviewed,
}) async {
  InventoryScanProfile? known;
  for (final profile in InventoryScanProfile.values) {
    if (profile.wireName == rawProfile) known = profile;
  }
  final session = await mock.startScannerSession(
    student ? ScannerKind.student : ScannerKind.inventory,
    'mock-window',
    inventoryScanProfile: known,
  );
  if (rawProfile != null && known == null) {
    // Unknown future raw profile: not expressible by the public start API.
    mock.debugSetScannerSessionRawMetadata(
      session,
      scanKind: 'inventory',
      inventoryScanProfile: rawProfile,
    );
  }
  await Future<void>.delayed(const Duration(milliseconds: 40));
  var item = (await mock.scannerSnapshot(session)).candidates.single;
  // The scanned candidate, then the user's reviewed (approved) payload.
  item = await mock.reviewScannerCandidate(
    session,
    item,
    candidate,
    approve: false,
    reason: 'fixture_candidate',
  );
  item = await mock.reviewScannerCandidate(
    session,
    item,
    reviewed,
    approve: true,
    reason: 'fixture_review',
  );
  return (session, item);
}

String _identity(Map entry) =>
    historyCanonicalResourceKey((entry['item_id'] ?? entry['key']) as String);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = copy(
    jsonDecode(
      File(
        '../contracts/fixtures/scanner_commit_history_sfb2b_v1.json',
      ).readAsStringSync(),
    ),
  );

  for (final raw in fixture['cases'] as List) {
    final row = copy(raw);
    test('SFB fixture ${row['id']}: upsert, one scan application, replay', () async {
      final student = row['kind'] == 'student';
      final rig = _rig(student: student, initial: row['initial'] as Object);
      final mock = rig.mock;
      addTearDown(mock.dispose);
      final state = await mock.loadRepositoryState(_id);
      final reviewed = copy(row['reviewed'] ?? row['candidate']);
      final (session, candidate) = await _scan(
        mock,
        student: student,
        rawProfile: row['raw_profile'] as String?,
        candidate: copy(row['candidate']),
        reviewed: reviewed,
      );
      final request = {
        'profile_id': _id,
        'expected_repository_revision': state.revision,
        'idempotency_key': 'sfb-${row['id']}',
      };
      Future<Map<String, dynamic>> commit([int? expected]) =>
          mock.commitScannerCandidate(
            session,
            candidate,
            profileId: _id,
            expectedRepositoryRevision:
                expected ?? request['expected_repository_revision'] as int,
            idempotencyKey: request['idempotency_key'] as String,
          );
      final response = await commit();
      // Public success stays exact4; no source/flat/excluded/retry_of field.
      expect(
        response.keys.toSet(),
        (fixture['public_success_keys'] as List).toSet(),
      );
      expect(response, {
        'candidate_id': candidate.id,
        'candidate_revision': candidate.revision,
        'profile_id': _id,
        'revision': state.revision + 1,
      });
      final after = await mock.loadRepositoryState(_id);
      final applied = (row['applied_keys'] as List).cast<String>();
      if (student) {
        final scanned = ConfirmedStudentState.fromWire(reviewed).toWire();
        expect({for (final s in after.students) s.studentId: s.toWire()}, {
          for (final s in row['initial'] as List)
            s['student_id'] as String: s['student_id'] == scanned['student_id']
                ? scanned
                : s,
        });
      } else {
        final expected = <String, Object?>{
          for (final entry in (row['initial'] as Map)['entries'] as List)
            _identity(entry as Map): entry['quantity'],
        };
        for (final entry in reviewed['entries'] as List) {
          expected[_identity(entry as Map)] = entry['quantity'];
        }
        // Unrelated existing entries are kept; excluded entries keep their prior value.
        expect({
          for (final entry in after.inventory.entries)
            _identity(entry): entry['quantity'],
        }, expected);
        for (final key in row['excluded_keys'] as List) {
          expect(
            after.inventory.entries
                .firstWhere((entry) => _identity(entry) == key)['quantity'],
            ((row['initial'] as Map)['entries'] as List).firstWhere(
              (entry) => _identity(entry as Map) == key,
            )['quantity'],
          );
        }
      }
      var summary = (await mock.loadRepositoryHistorySummary([
        _id,
      ])).profiles.single;
      expect(summary.totalCounts, {
        'scan': 1,
        'manual': 0,
        'import': 0,
        'unattributed': 0,
      });
      expect(summary.lastScanAt, historyUtcTimestamp(rig.at));
      expect(summary.totalScanSessionCount, 1);
      final event = (await mock.loadRepositoryHistoryEvents(
        RepositoryHistoryEventsRequest(profileId: _id),
      )).events.single;
      expect(event.source, 'scan');
      expect(event.scanKind, student ? 'student' : 'inventory');
      expect(event.inventoryScanProfile, row['raw_profile']);
      expect(event.scanSessionId, session.id);
      expect(
        student ? event.appliedStudentIds : event.appliedResourceKeys,
        applied,
      );
      expect(
        student ? event.appliedResourceKeys : event.appliedStudentIds,
        isEmpty,
      );
      final changed = student
          ? event.studentChanges.map((c) => c.studentId)
          : event.inventoryChanges.map((c) => c.resourceKey);
      expect(changed, row['nochange'] == true ? isEmpty : applied);
      // Nested context stays exact4; provenance is not persisted.
      expect((event.toWire()['scan_context'] as Map).keys.toSet(), {
        'session_id',
        'generation',
        'candidate_id',
        'candidate_revision',
      });
      final latest = await mock.loadRepositoryHistoryScanLatest(
        RepositoryHistoryScanLatestRequest(
          profileId: _id,
          studentIds: student ? applied : null,
          resourceKeys: student
              ? null
              : [...applied, ...(row['excluded_keys'] as List).cast<String>()],
          includeByKind: true,
        ),
      );
      expect(latest.lastScanAt, historyUtcTimestamp(rig.at));
      expect(latest.byKind.single.inventoryScanProfile, row['raw_profile']);
      for (final row2 in [...latest.byStudentId, ...latest.byResourceKey]) {
        final key = row2 is HistoryStudentScanLatest
            ? row2.studentId
            : (row2 as HistoryResourceScanLatest).resourceKey;
        final scan = row2 is HistoryStudentScanLatest
            ? row2.latestScan
            : (row2 as HistoryResourceScanLatest).latestScan;
        if (applied.contains(key)) {
          expect(scan!.sequence, event.sequence);
        } else {
          // Excluded keys are not freshened.
          expect(scan, isNull);
        }
      }
      expect(rig.clockCalls, 1);

      // Receipt-first replay, even after an unrelated repository write.
      await mock.saveRepositoryGoals(
        _id,
        const {'version': 1, 'goals': <dynamic>[]},
        state.revision + 1,
        'outside-write',
      );
      final before = await mock.loadRepositoryState(_id);
      expect(await commit(), response);
      final replayed = await mock.loadRepositoryState(_id);
      expect(replayed.revision, before.revision);
      expect(
        replayed.students.map((s) => s.toWire()).toList(),
        before.students.map((s) => s.toWire()).toList(),
      );
      expect(replayed.inventory.toWire(), before.inventory.toWire());
      summary = (await mock.loadRepositoryHistorySummary([
        _id,
      ])).profiles.single;
      expect(summary.historySequence, 1);
      expect(summary.totalCounts['unattributed'], 0);
      expect(rig.clockCalls, 1);
      // The same key with another public field is a conflict, not a new apply.
      await expectLater(
        commit(state.revision + 5),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'idempotency_conflict',
          ),
        ),
      );
    });
  }

  test(
    'empty or all-excluded scope never commits and stores no receipt',
    () async {
      final rig = _rig(
        student: false,
        initial: {
          'version': 1,
          'entries': [
            {'key': 'Item_Icon_ExpItem_0', 'quantity': '5'},
          ],
        },
      );
      final mock = rig.mock;
      addTearDown(mock.dispose);
      final state = await mock.loadRepositoryState(_id);
      final (session, candidate) = await _scan(
        mock,
        student: false,
        rawProfile: 'activity_reports',
        candidate: {
          'version': 1,
          'entries': [
            {'key': 'Item_Icon_ExpItem_0', 'quantity': '9'},
          ],
        },
        reviewed: {'version': 1, 'entries': <dynamic>[]},
      );
      Future<Map<String, dynamic>> commit() => mock.commitScannerCandidate(
        session,
        candidate,
        profileId: _id,
        expectedRepositoryRevision: state.revision,
        idempotencyKey: 'empty',
      );
      for (var i = 0; i < 2; i++) {
        await expectLater(
          commit(),
          throwsA(
            isA<BackendRemoteException>()
                .having((e) => e.code, 'code', 'invalid_candidate')
                .having((e) => e.details?['reason'], 'reason', 'empty_scan_scope'),
          ),
        );
      }
      final after = await mock.loadRepositoryState(_id);
      expect(after.revision, state.revision);
      expect(after.inventory.entries.single['quantity'], '5');
      expect(rig.clockCalls, 0);
      final summary = (await mock.loadRepositoryHistorySummary([
        _id,
      ])).profiles.single;
      expect(summary.historySequence, 0);
      expect(summary.lastScanAt, isNull);
    },
  );

  test(
    'pending loss keeps the original frozen bucket; a stale retry never re-merges',
    () async {
      final rig = _rig(
        student: true,
        initial: [
          {
            'version': 1,
            'student_id': 'aru',
            'values': {'level': 1},
          },
        ],
      );
      final mock = rig.mock;
      addTearDown(mock.dispose);
      final state = await mock.loadRepositoryState(_id);
      final (session, candidate) = await _scan(
        mock,
        student: true,
        rawProfile: null,
        candidate: {
          'version': 1,
          'student_id': 'aru',
          'values': {'level': 50},
        },
        reviewed: {
          'version': 1,
          'student_id': 'aru',
          'values': {'level': 50},
        },
      );
      // Another writer moves the repository first: the original request fails.
      await mock.saveRepositoryGoals(
        _id,
        const {'version': 1, 'goals': <dynamic>[]},
        state.revision,
        'outside',
      );
      Future<Map<String, dynamic>> commit(int expected, String key) =>
          mock.commitScannerCandidate(
            session,
            candidate,
            profileId: _id,
            expectedRepositoryRevision: expected,
            idempotencyKey: key,
          );
      for (var i = 0; i < 2; i++) {
        await expectLater(
          commit(state.revision, 'pending'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'revision_conflict',
            ),
          ),
        );
      }
      // The same key may not be resubmitted with a refreshed expected revision.
      await expectLater(
        commit(state.revision + 1, 'pending'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'idempotency_conflict',
          ),
        ),
      );
      expect(rig.clockCalls, 0);
      // A new apply intent uses a new key and the current revision.
      final ok = await commit(state.revision + 1, 'new-intent');
      expect(ok['revision'], state.revision + 2);
      final summary = (await mock.loadRepositoryHistorySummary([
        _id,
      ])).profiles.single;
      expect(summary.totalCounts['scan'], 1);
      expect(summary.totalCounts['unattributed'], 0);
      expect(rig.clockCalls, 1);
    },
  );

  test('stale candidate revision and review-required are rejected before reading', () async {
    final mock = MockAppService(
      scannerScenario: MockScannerScenario.reviewRequired,
      historyClock: () => DateTime.utc(2026, 10, 10),
    );
    addTearDown(mock.dispose);
    final profile = (await mock.listProfiles()).single;
    final state = await mock.loadRepositoryState(profile.id);
    final session = await mock.startScannerSession(
      ScannerKind.student,
      'mock-window',
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final candidate = (await mock.scannerSnapshot(session)).candidates.single;
    await expectLater(
      mock.commitScannerCandidate(
        session,
        candidate,
        profileId: profile.id,
        expectedRepositoryRevision: state.revision,
        idempotencyKey: 'review',
      ),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', 'review_required'),
      ),
    );
    final approved = await mock.reviewScannerCandidate(
      session,
      candidate,
      candidate.payload,
      approve: true,
      reason: 'test',
    );
    await expectLater(
      mock.commitScannerCandidate(
        session,
        candidate,
        profileId: profile.id,
        expectedRepositoryRevision: state.revision,
        idempotencyKey: 'stale-candidate',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'candidate_revision_conflict',
        ),
      ),
    );
    final committed = await mock.commitScannerCandidate(
      session,
      approved,
      profileId: profile.id,
      expectedRepositoryRevision: state.revision,
      idempotencyKey: 'approved',
    );
    expect(committed['candidate_revision'], approved.revision);
    expect(
      (await mock.loadRepositoryHistorySummary([
        profile.id,
      ])).profiles.single.totalCounts['scan'],
      1,
    );
  });
}
