import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:flutter_test/flutter_test.dart';

// fb2b-dart: FB-2b `repository.history.scan_latest` DTO/validator/Mock against the
// shared fixture contracts/fixtures/repository_history_scan_latest_v1.json.
Map<String, dynamic> copy(Object? value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

const _id = 'aaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, dynamic> _emptyState(int revision) => {
  'profile_id': _id,
  'revision': revision,
  'students': <dynamic>[],
  'inventory': {'version': 1, 'entries': <dynamic>[]},
  'goals': {'version': 1, 'goals': <dynamic>[]},
};

Matcher _scanLatestError(String code, String reason) =>
    isA<BackendRemoteException>()
        .having((e) => e.code, 'code', code)
        .having((e) => e.details?['reason'], 'reason', reason)
        .having((e) => e.retryable, 'retryable', isFalse);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = copy(
    jsonDecode(
      File(
        '../contracts/fixtures/repository_history_scan_latest_v1.json',
      ).readAsStringSync(),
    ),
  );
  // expect는 test 밖(main 본문)에서 부르면 OutsideTestException으로 파일 로드가 실패한다(gate 20261010_204850).
  test('shared fixture targets repository.history.scan_latest', () {
    expect(fixture['method'], 'repository.history.scan_latest');
  });

  group('shared valid full histories', () {
    for (final raw in fixture['valid_history_cases'] as List) {
      final row = copy(raw);
      test('Mock and pure query reproduce ${row['id']}', () async {
        final history = row['history'] == null
            ? null
            : RepositoryCurrentHistory.fromWire(copy(row['history']));
        final request = RepositoryHistoryScanLatestRequest.fromWire(
          copy(row['request']),
        );
        final expected = copy(row['expected']);
        expect(
          RepositoryHistoryScanLatestResult.fromWire(copy(expected)).toWire(),
          expected,
        );
        expect(
          repositoryHistoryScanLatest(
            _id,
            row['revision'] as int,
            history,
            request,
          ).toWire(),
          expected,
        );
        var clockCalls = 0;
        final mock = MockAppService(
          profiles: [
            RepositoryProfile(
              id: _id,
              displayName: 'scan latest',
              revision: row['revision'] as int,
              selected: true,
            ),
          ],
          repositoryStates: {_id: _emptyState(row['revision'] as int)},
          repositoryHistories: {_id: ?history},
          historyClock: () {
            clockCalls++;
            return DateTime.utc(2026, 10, 10);
          },
        );
        addTearDown(mock.dispose);
        final result = await mock.loadRepositoryHistoryScanLatest(request);
        expect(result.toWire(), expected);
        expect(
          isValidRepositoryProtocolMessage({
            'protocol': 1,
            'id': row['id'],
            'type': 'response',
            'method': 'repository.history.scan_latest',
            'payload': expected,
          }),
          isTrue,
        );
        // Read-only: no clock, no plan migration (+1) and detached results.
        expect(clockCalls, 0);
        expect(
          (await mock.listProfiles()).single.revision,
          row['revision'] as int,
        );
        result.toWire()['by_kind'].clear();
        expect(
          (await mock.loadRepositoryHistoryScanLatest(request)).toWire(),
          expected,
        );
        expect(
          (await mock.loadRepositoryHistorySummary([
            _id,
          ])).profiles.single.lastScanAt,
          expected['last_scan_at'],
        );
      });
    }
  });

  group('independent metadata policy oracles', () {
    for (final raw in fixture['metadata_policy_oracles'] as List) {
      final row = copy(raw);
      final model = copy(row['model']);
      final expected = copy(row['expected']);
      test('oracle ${row['id']}', () {
        final index = model['history_recorded'] == true
            ? {
                'next_sequence': (model['history_sequence'] as int) + 1,
                'last_applied_at': {'scan': model['last_scan_at']},
                'latest_scans': model['latest_scans'],
              }
            : null;
        final error = expected['error'] as Map?;
        if (error != null &&
            error['reason'] != 'stale_scan_latest') {
          // invalid_history_query / duplicate_identity: rejected at the new
          // request boundary before anything is sent or read.
          expect(error['code'], 'invalid_payload');
          expect(error['retryable'], isFalse);
          expect(
            () => RepositoryHistoryScanLatestRequest.fromWire(
              copy(row['request']),
            ),
            throwsFormatException,
          );
          expect(
            isValidRepositoryProtocolMessage({
              'protocol': 1,
              'id': 'oracle',
              'type': 'request',
              'method': 'repository.history.scan_latest',
              'payload': row['request'],
            }),
            isFalse,
          );
          return;
        }
        final request = RepositoryHistoryScanLatestRequest.fromWire(
          copy(row['request']),
        );
        if (error != null) {
          expect(
            () => repositoryHistoryScanLatestIndex(
              profileId: _id,
              revision: model['revision'] as int,
              history: index,
              request: request,
            ),
            throwsA(
              isA<RepositoryHistoryScanLatestError>()
                  .having((e) => e.code, 'code', 'invalid_payload')
                  .having((e) => e.reason, 'reason', 'stale_scan_latest')
                  .having((e) => e.retryable, 'retryable', isFalse),
            ),
          );
          return;
        }
        final result = repositoryHistoryScanLatestIndex(
          profileId: _id,
          revision: model['revision'] as int,
          history: index,
          request: request,
        );
        expect(result.toWire(), expected['payload']);
      });
    }
  });

  test(
    'Mock appendScan replays oracle applications into the persisted index',
    () {
      var replayed = 0;
      for (final raw in fixture['metadata_policy_oracles'] as List) {
        final row = copy(raw);
        final model = copy(row['model']);
        final apps = (row['applications'] as List).cast<Map>();
        // Pruned models and v6 import seeds are not producible by the Mock helpers.
        if (apps.isEmpty ||
            model['pruned_through_sequence'] != 0 ||
            apps.any((app) => app['source'] == 'import')) {
          continue;
        }
        var history = RepositoryCurrentHistory.empty();
        var revision = 0;
        for (final (i, app) in apps.indexed) {
          // A receipt replay or a skipped/unidentified row is not an application.
          if (app['skipped'] == true || app['replayed'] == true) continue;
          final before = RepositoryState.fromWire(_emptyState(revision));
          final after = RepositoryState.fromWire(_emptyState(revision + 1));
          final at = DateTime.parse(app['recorded_at'] as String);
          history = app['source'] == 'scan'
              ? history.appendScan(
                  before,
                  after,
                  at,
                  rawScanKind: app['scan_kind'] as String,
                  rawInventoryScanProfile:
                      app['inventory_scan_profile'] as String?,
                  scanContext: {
                    'session_id': app['session_id'],
                    'generation': 1,
                    'candidate_id': 'oracle-$i',
                    'candidate_revision': 0,
                  },
                  studentIds: (app['student_ids'] as List).cast<String>(),
                  // The scanner context canonicalizes approved inventory keys.
                  resourceKeys: [
                    for (final key in app['resource_keys'] as List)
                      historyCanonicalResourceKey(key as String),
                  ],
                )
              : history.appendManual(
                  before,
                  after,
                  'current',
                  at,
                  source: app['source'] as String,
                );
          revision++;
        }
        final wire = history.toWire();
        expect(wire['next_sequence'] - 1, model['history_sequence']);
        expect(wire['last_applied_at']['scan'], model['last_scan_at']);
        expect(wire['total_counts']['scan'], model['scan_commit_count']);
        expect(
          (wire['scan_session_ids'] as List).toSet(),
          (model['scan_session_ids'] as List).toSet(),
        );
        for (final (bucket, identity) in [
          ('by_kind', null),
          ('by_student_id', 'student_id'),
          ('by_resource_key', 'resource_key'),
        ]) {
          Map<String, Object?> keyed(List rows) => {
            for (final item in rows)
              identity == null
                      ? historyCanonicalJson([
                          item['scan_kind'],
                          item['inventory_scan_profile'],
                        ])
                      : item[identity] as String:
                  item,
          };
          expect(
            keyed(wire['latest_scans'][bucket] as List),
            keyed(model['latest_scans'][bucket] as List),
            reason: '${row['id']} $bucket',
          );
        }
        final summary = history.summarize(_id, model['revision'] as int);
        expect(summary.lastScanAt, model['last_scan_at']);
        final expected = copy(row['expected']);
        final request = RepositoryHistoryScanLatestRequest.fromWire(
          copy(row['request']),
        );
        if (expected['payload'] != null) {
          expect(
            repositoryHistoryScanLatest(
              _id,
              model['revision'] as int,
              history,
              request,
            ).toWire(),
            expected['payload'],
            reason: row['id'] as String,
          );
        } else {
          expect(
            () => repositoryHistoryScanLatest(
              _id,
              model['revision'] as int,
              history,
              request,
            ),
            throwsA(isA<RepositoryHistoryScanLatestError>()),
          );
        }
        replayed++;
      }
      // approved/nochange/excluded/unknown raw, replay+skip, clock rollback,
      // last-apply kind order, unknown kind, stale anchor, unidentified skip.
      expect(replayed, 7);
    },
  );

  test('request boundary: Unicode scalar order, surrogates, bytes, aliases', () {
    // Rune comparator: U+E000 sorts before U+10000; UTF-16 String.compareTo reverses them.
    expect('\u{10000}'.compareTo('\u{E000}'), lessThan(0));
    final ordered = RepositoryHistoryScanLatestRequest(
      profileId: _id,
      studentIds: ['\u{10000}', '\u{E000}', 'b', 'a'],
      resourceKeys: ['\u{10000}', '\u{E000}'],
    );
    expect(ordered.studentIds, ['a', 'b', '\u{E000}', '\u{10000}']);
    expect(ordered.resourceKeys, ['\u{E000}', '\u{10000}']);
    for (final bad in [
      '\uD800',
      '\uDC00',
      'a\uD800b',
      '\uDC00\uD800',
      '',
      '가' * 342,
    ]) {
      expect(
        () => RepositoryHistoryScanLatestRequest(
          profileId: _id,
          studentIds: [bad],
        ),
        throwsFormatException,
        reason: bad.codeUnits.toString(),
      );
      expect(
        () => RepositoryHistoryScanLatestRequest(
          profileId: _id,
          resourceKeys: [bad],
        ),
        throwsFormatException,
      );
    }
    expect(
      RepositoryHistoryScanLatestRequest(
        profileId: _id,
        studentIds: ['가' * 341, '💎' * 256, ' raw\t'],
      ).studentIds.length,
      3,
    );
    final alias = RepositoryHistoryScanLatestRequest(
      profileId: _id,
      resourceKeys: ['Item_Icon_SkillBook_Ultimate_Piece', 'credits'],
    );
    expect(alias.resourceKeys, ['Item_Icon_SkillBook_Ultimate', 'credits']);
    expect(alias.toWire()['resource_keys'], alias.resourceKeys);
    expect(
      () => RepositoryHistoryScanLatestRequest(
        profileId: _id,
        resourceKeys: [
          'Item_Icon_SkillBook_Ultimate_Piece',
          'Item_Icon_SkillBook_Ultimate',
        ],
      ),
      throwsFormatException,
    );
    // Student IDs are raw: no alias, trim or case folding.
    expect(
      RepositoryHistoryScanLatestRequest(
        profileId: _id,
        studentIds: ['Aru', 'aru', ' aru'],
      ).studentIds,
      [' aru', 'Aru', 'aru'],
    );
    for (final payload in <Map<String, dynamic>>[
      {'profile_id': _id, 'include_by_kind': 1},
      {'profile_id': _id, 'include_by_kind': null},
      {'profile_id': _id, 'student_ids': null},
      {'profile_id': _id, 'by_kind_after_sequence': 0},
      {'profile_id': _id, 'include_by_kind': false, 'by_kind_limit': 1},
      {'profile_id': _id, 'include_by_kind': true, 'by_kind_limit': 0},
      {'profile_id': _id, 'include_by_kind': true, 'by_kind_after_sequence': -1},
      {
        'profile_id': _id,
        'include_by_kind': true,
        'by_kind_after_sequence': 3,
        'anchor_history_sequence': 2,
      },
      {'profile_id': _id, 'student_ids': List.generate(257, (i) => 's$i')},
      {'profile_id': 'AAAAAAAAAAAAAAAAAAAAAAAA'},
    ]) {
      expect(
        () => RepositoryHistoryScanLatestRequest.fromWire(payload),
        throwsFormatException,
        reason: payload.toString(),
      );
    }
    final defaults = RepositoryHistoryScanLatestRequest(profileId: _id);
    expect(defaults.toWire(), {'profile_id': _id});
    expect(defaults.studentIds, isEmpty);
    expect(defaults.includeByKind, isFalse);
    expect(defaults.byKindLimit, 100);
    expect(defaults.byKindAfterSequence, 0);
    expect(defaults.anchorHistorySequence, isNull);
    // Anchor 0 with after 0 is a valid first page of an empty history.
    expect(
      RepositoryHistoryScanLatestRequest(
        profileId: _id,
        includeByKind: true,
        anchorHistorySequence: 0,
      ).anchorHistorySequence,
      0,
    );
  });

  test('result DTO is strict exact8/exact5/exact3 with null semantics', () {
    final valid = copy(
      (fixture['valid_history_cases'] as List).firstWhere(
        (row) => row['id'] == 'nochange_approved_excluded_unknown_alias',
      )['expected'],
    );
    expect(
      RepositoryHistoryScanLatestResult.fromWire(copy(valid)).toWire(),
      valid,
    );
    final parsed = RepositoryHistoryScanLatestResult.fromWire(copy(valid));
    expect(parsed.lastScanAt, '2026-10-10T11:00:00.000003Z');
    expect(parsed.byKind.first.inventoryScanProfile, ' ??? ');
    expect(parsed.byKind.last.inventoryScanProfile, isNull);
    expect(parsed.byStudentId.last.latestScan, isNull);
    expect(parsed.byStudentId.last.reason, 'scan_not_found');
    expect(parsed.byResourceKey.first.latestScan!.sequence, 1);
    expect(() => parsed.byKind.add(parsed.byKind.first), throwsUnsupportedError);
    void reject(void Function(Map<String, dynamic>) mutate, String reason) {
      final wire = copy(valid);
      mutate(wire);
      expect(
        () => RepositoryHistoryScanLatestResult.fromWire(wire),
        throwsFormatException,
        reason: reason,
      );
      expect(
        isValidRepositorySuccessPayload('repository.history.scan_latest', wire),
        isFalse,
        reason: reason,
      );
    }

    reject((w) => w['extra'] = null, 'unknown top key');
    reject((w) => w.remove('last_scan_at'), 'missing required nullable key');
    reject((w) => w['by_kind'][0]['extra'] = 1, 'scan exact5');
    reject((w) => w['by_kind'][0].remove('inventory_scan_profile'), 'exact5');
    reject((w) => w['by_student_id'][0]['extra'] = 1, 'entity exact3');
    reject((w) => w['by_student_id'][0]['reason'] = 'scan_not_found', 'reason');
    reject((w) => w['by_student_id'][2]['reason'] = null, 'missing reason');
    reject((w) => w['by_student_id'][2]['reason'] = 'zero', 'unknown reason');
    reject(
      (w) => w['by_student_id'] = (w['by_student_id'] as List).reversed.toList(),
      'Unicode scalar row order',
    );
    reject(
      (w) => w['by_kind'] = (w['by_kind'] as List).reversed.toList(),
      'latest sequence order',
    );
    reject((w) => w['by_kind_next_after_sequence'] = 2, 'next must be last');
    reject((w) => w['by_kind'][0]['sequence'] = 4, 'beyond history sequence');
    reject((w) => w['by_kind'][0]['sequence'] = true, 'bool sequence');
    reject((w) => w['by_kind'][0]['recorded_at'] = '2026-10-10', 'utc');
    reject((w) => w['by_kind'][0]['session_id'] = '\uD800', 'surrogate');
    reject(
      (w) => w['by_resource_key'][0]['resource_key'] =
          'Item_Icon_SkillBook_Ultimate_Piece',
      'alias row',
    );
    reject((w) {
      w['last_scan_at'] = null;
      w['by_kind'] = <dynamic>[];
    }, 'null last_scan_at with entity scans');
    reject((w) {
      w['by_student_id'][2]['reason'] = 'unrecorded';
    }, 'unrecorded with a recorded history');
    // Null last_scan_at keeps requested rows but no scan metadata.
    final unrecorded = copy(
      (fixture['valid_history_cases'] as List).first['expected'],
    );
    expect(
      RepositoryHistoryScanLatestResult.fromWire(unrecorded).lastScanAt,
      isNull,
    );
    expect(
      () => RepositoryHistoryScanLatestResult.fromWireFor(
        RepositoryHistoryScanLatestRequest(profileId: _id),
        unrecorded,
      ),
      throwsFormatException,
      reason: 'rows must correspond to the request targets',
    );
  });

  test(
    'Mock stale anchor, corrupt duplicate kinds and clock rollback',
    () async {
      var now = DateTime.utc(2026, 10, 10, 12);
      final mock = MockAppService(historyClock: () => now);
      addTearDown(mock.dispose);
      final profile = await mock.createProfile('Latest', 'latest');
      final id = profile.id;
      Future<int> manualWrite(String key) async {
        final state = await mock.loadRepositoryState(id);
        return mock.saveRepositoryInventory(
          id,
          RepositoryInventoryState.fromEntries([
            for (final entry in state.inventory.entries) entry,
          ]),
          state.revision,
          key,
        );
      }

      // Manual writes never become profile scan time.
      await manualWrite('manual-1');
      var latest = await mock.loadRepositoryHistoryScanLatest(
        RepositoryHistoryScanLatestRequest(
          profileId: id,
          studentIds: ['aru'],
          includeByKind: true,
        ),
      );
      expect(latest.lastScanAt, isNull);
      expect(latest.byKind, isEmpty);
      expect(latest.byStudentId.single.reason, 'scan_not_found');
      final summary = (await mock.loadRepositoryHistorySummary([
        id,
      ])).profiles.single;
      expect(summary.lastScanAt, isNull);
      expect(summary.lastManualAt, isNotNull);

      // Two Mock scan applications through the history helper with a clock rollback.
      final before = await mock.loadRepositoryState(id);
      final seeded = RepositoryCurrentHistory.empty()
          .appendScan(
            RepositoryState.fromWire(_emptyState(0)),
            RepositoryState.fromWire(_emptyState(1)),
            DateTime.utc(2026, 10, 10, 13),
            rawScanKind: 'student',
            rawInventoryScanProfile: null,
            scanContext: {
              'session_id': 'clock-1',
              'generation': 1,
              'candidate_id': 'c1',
              'candidate_revision': 0,
            },
            studentIds: ['aru'],
            resourceKeys: [],
          )
          .appendScan(
            RepositoryState.fromWire(_emptyState(1)),
            RepositoryState.fromWire(_emptyState(2)),
            DateTime.utc(2026, 10, 10, 12),
            rawScanKind: 'student',
            rawInventoryScanProfile: null,
            scanContext: {
              'session_id': 'clock-2',
              'generation': 1,
              'candidate_id': 'c2',
              'candidate_revision': 0,
            },
            studentIds: ['aru'],
            resourceKeys: [],
          );
      latest = repositoryHistoryScanLatest(
        _id,
        2,
        seeded,
        RepositoryHistoryScanLatestRequest(
          profileId: _id,
          studentIds: ['aru'],
          includeByKind: true,
        ),
      );
      // Latest = last application sequence, not the maximum timestamp.
      expect(latest.lastScanAt, '2026-10-10T12:00:00.000000Z');
      expect(latest.byKind.single.sessionId, 'clock-2');
      expect(latest.byStudentId.single.latestScan!.sequence, 2);
      expect(seeded.summarize(_id, 2).coverage.timestampsMonotonic, isFalse);

      // Stale anchor: a new current application moves history_sequence.
      final first = await mock.loadRepositoryHistoryScanLatest(
        RepositoryHistoryScanLatestRequest(
          profileId: id,
          includeByKind: true,
          byKindLimit: 1,
        ),
      );
      final request = RepositoryHistoryScanLatestRequest(
        profileId: id,
        includeByKind: true,
        byKindLimit: 1,
        anchorHistorySequence: first.historySequence,
      );
      await mock.loadRepositoryHistoryScanLatest(request);
      now = DateTime.utc(2026, 10, 10, 14);
      await mock.saveRepositoryInventory(
        id,
        before.inventory,
        before.revision,
        'manual-2',
      );
      await expectLater(
        mock.loadRepositoryHistoryScanLatest(request),
        throwsA(_scanLatestError('invalid_payload', 'stale_scan_latest')),
      );
      // Restart from the first page without the old anchor.
      final restarted = await mock.loadRepositoryHistoryScanLatest(
        RepositoryHistoryScanLatestRequest(profileId: id, includeByKind: true),
      );
      expect(restarted.historySequence, first.historySequence + 1);

      // Impossible duplicate latest kinds are reported even when not requested.
      final corrupt = seeded.toWire();
      corrupt['latest_scans']['by_kind'] = [
        ...corrupt['latest_scans']['by_kind'] as List,
        {
          ...(corrupt['latest_scans']['by_kind'] as List).single as Map,
          'scan_kind': 'other',
        },
      ];
      expect(
        () => repositoryHistoryScanLatestIndex(
          profileId: _id,
          revision: 2,
          history: corrupt,
          request: RepositoryHistoryScanLatestRequest(profileId: _id),
        ),
        throwsA(
          isA<RepositoryHistoryScanLatestError>().having(
            (e) => e.code,
            'code',
            'corrupt_data',
          ),
        ),
      );
      await expectLater(
        mock.loadRepositoryHistoryScanLatest(
          RepositoryHistoryScanLatestRequest(
            profileId: 'bbbbbbbbbbbbbbbbbbbbbbbb',
          ),
        ),
        throwsStateError,
      );
      // Query profile must match the history owner.
      expect(
        () => repositoryHistoryScanLatest(
          'bbbbbbbbbbbbbbbbbbbbbbbb',
          2,
          seeded,
          RepositoryHistoryScanLatestRequest(profileId: _id),
        ),
        throwsFormatException,
      );
    },
  );

  test('summary is exact13 with required nullable last_scan_at', () {
    final history = jsonDecode(
      File('../contracts/fixtures/current_history_v1.json').readAsStringSync(),
    );
    final summary = copy(history['summary']);
    // Intended contract change: 12 → 13 required keys (FB-2b).
    expect(summary.length, 13);
    expect(RepositoryHistorySummary.fromWire(copy(summary)).lastScanAt,
        summary['last_scan_at']);
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (w) => w.remove('last_scan_at'),
      (w) => w['last_scan_at'] = null, // scan count 2
      (w) => w['last_scan_at'] = '2026-10-09',
      (w) => w['last_scan_at'] = w['last_manual_at'].toString().substring(0, 19),
    ]) {
      final wire = copy(summary);
      mutate(wire);
      expect(
        () => RepositoryHistorySummary.fromWire(wire),
        throwsFormatException,
      );
    }
    final manualOnly = copy(summary)
      ..['total_counts'] = {
        'scan': 0,
        'manual': 4,
        'import': 0,
        'unattributed': 0,
      }
      ..['retained_counts'] = {
        'scan': 0,
        'manual': 4,
        'import': 0,
        'unattributed': 0,
      }
      ..['total_scan_session_count'] = 0
      ..['retained_scan_session_count'] = 0;
    // No scan → null; a manual/import time is never substituted.
    expect(
      () => RepositoryHistorySummary.fromWire(copy(manualOnly)),
      throwsFormatException,
    );
    manualOnly['last_scan_at'] = null;
    expect(RepositoryHistorySummary.fromWire(manualOnly).lastScanAt, isNull);
    final unrecorded = RepositoryHistorySummary.unrecorded(_id, 3);
    expect(unrecorded.toWire().length, 13);
    expect(unrecorded.lastScanAt, isNull);
  });
}
