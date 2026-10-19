import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> copy(Object value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final f = copy(
    jsonDecode(
      File(
        '../contracts/fixtures/repository_history_query_v1.json',
      ).readAsStringSync(),
    ),
  );
  test(
    'history manual events anchor persists across restart, writes, replay and diff',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'ba_planner_fb2c_manual_',
      );
      final config = BackendProcessConfig.resolve(
        backendDirectory: '${Directory.current.parent.path}/backend',
        environment: {'BA_PLANNER_STORAGE_ROOT': root.path},
      );
      ProcessAppService start() => ProcessAppService(
        PlanningProtocolClient(
          () => startBackendProcess(config),
          defaultTimeout: const Duration(seconds: 30),
          waitForStartupProbe: true,
          startupProbeTimeout: const Duration(seconds: 30),
        ),
      );
      var service = start();
      try {
        await service.reconnect();
        final profile = await service.createProfile('Period', 'fb2c-profile');
        final id = profile.id;
        for (var i = 0; i < 4; i++) {
          await service.saveRepositoryInventory(
            id,
            RepositoryInventoryState.fromEntries([
              {'key': 'a', 'quantity': '${10 + i}'},
            ]),
            i,
            'item-$i',
          );
        }
        final first = await service.loadRepositoryHistoryEvents(
          RepositoryHistoryEventsRequest(profileId: id, limit: 2),
        );
        expect(first.historySequence, 4);
        expect(first.events.map((e) => e.sequence), [1, 2]);
        expect(first.scanSessionCount, 0);
        final cursor = first.nextCursor;
        await service.dispose();
        service = start();
        await service.reconnect();
        final before = await service.loadRepositoryHistoryDiff(
          RepositoryHistoryDiffRequest(
            profileId: id,
            from: RepositoryHistoryEndpoint.sequence(1),
            to: RepositoryHistoryEndpoint.current(),
            studentIds: [],
            resourceKeys: ['a'],
          ),
        );
        expect(before.inventoryChanges.single.delta, '3');
        expect(before.coverage.complete, isTrue);
        final inventory = RepositoryInventoryState.fromEntries([
          {'key': 'a', 'quantity': '25'},
        ]);
        expect(
          await service.saveRepositoryInventory(
            id,
            inventory,
            4,
            'after-anchor',
          ),
          5,
        );
        expect(
          await service.saveRepositoryInventory(
            id,
            inventory,
            4,
            'after-anchor',
          ),
          5,
        );
        final second = await service.loadRepositoryHistoryEvents(
          RepositoryHistoryEventsRequest(
            profileId: id,
            cursor: cursor,
            limit: 200,
          ),
        );
        expect(second.historySequence, 4);
        expect(second.revision, 5);
        expect(second.matchingEventCount, 4);
        expect(second.events.map((e) => e.sequence), [3, 4]);
        expect(second.nextCursor, isNull);
        final now = await service.loadRepositoryHistoryDiff(
          RepositoryHistoryDiffRequest(
            profileId: id,
            from: RepositoryHistoryEndpoint.sequence(4),
            to: RepositoryHistoryEndpoint.current(),
            studentIds: [],
            resourceKeys: ['a'],
          ),
        );
        expect(now.inventoryChanges.single.delta, '12');
        await expectLater(
          service.loadRepositoryHistoryEvents(
            RepositoryHistoryEventsRequest(
              profileId: id,
              cursor: cursor,
              source: 'scan',
            ),
          ),
          throwsA(
            isA<BackendRemoteException>().having(
              (e) => e.code,
              'code',
              'invalid_payload',
            ),
          ),
        );
        final state = await service.loadRepositoryState(id);
        expect(state.revision, 5);
        expect(state.inventory.entries.single['quantity'], '25');
      } finally {
        await service.dispose();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'scan fixture queries, session snapshots and strict DTO survive process restart',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'ba_planner_fb2c_scan_',
      );
      final config = BackendProcessConfig.resolve(
        backendDirectory: '${Directory.current.parent.path}/backend',
        environment: {'BA_PLANNER_STORAGE_ROOT': root.path},
      );
      ProcessAppService start() => ProcessAppService(
        PlanningProtocolClient(
          () => startBackendProcess(config),
          defaultTimeout: const Duration(seconds: 30),
          waitForStartupProbe: true,
          startupProbeTimeout: const Duration(seconds: 30),
        ),
      );
      var service = start();
      try {
        await service.reconnect();
        final profile = await service.createProfile(
          'Scan fixture',
          'fb2c-scan',
        );
        final id = profile.id;
        await service.dispose();
        final path = File('${root.path}/profiles/$id.json');
        final wire = copy(jsonDecode(await path.readAsString()));
        final current = f['current'] as Map;
        wire['revision'] = f['revision'];
        wire['students'] = current['students'];
        wire['inventory'] = {
          'version': 1,
          'entries': [
            for (final row in current['inventory'] as List)
              {'key': row['resource_key'], 'quantity': row['quantity']},
          ],
        };
        wire['current_history'] = f['history'];
        await path.writeAsString(jsonEncode(wire));
        final catalogFile = File('${root.path}/catalog.json');
        final catalog = copy(jsonDecode(await catalogFile.readAsString()));
        for (final row in catalog['profiles'] as List) {
          if (row['profile_id'] == id) row['revision'] = f['revision'];
        }
        await catalogFile.writeAsString(jsonEncode(catalog));
        service = start();
        await service.reconnect();
        Map<String, dynamic> request(Map row) =>
            copy(row['request'])..['profile_id'] = id;
        for (final raw in f['cases'] as List) {
          final row = raw as Map;
          if (row.containsKey('history')) continue;
          final expected = copy(row['result'])..['profile_id'] = id;
          // Cursor binds profile as well as filters; the fixture cursor targets its own profile.
          if (row['id'] == 'first-page' || row['id'] == 'second-page') continue;
          final result = row['method'] == 'events'
              ? await service.loadRepositoryHistoryEvents(
                  RepositoryHistoryEventsRequest.fromWire(request(row)),
                )
              : await service.loadRepositoryHistoryDiff(
                  RepositoryHistoryDiffRequest.fromWire(request(row)),
                );
          expect(result.toWire(), expected, reason: row['id'] as String);
        }
        final point = await service.loadRepositoryHistoryDiff(
          RepositoryHistoryDiffRequest(
            profileId: id,
            from: RepositoryHistoryEndpoint.scan(
              position: 'latest',
              inventoryScanProfile: null,
              resourceKey: 'a',
            ),
            to: RepositoryHistoryEndpoint.current(),
            resourceKeys: ['a'],
            studentIds: [],
          ),
        );
        expect(point.fromPoint.sequence, 4);
        expect(point.fromPoint.inventory['a'], '20');
        final first = await service.loadRepositoryHistoryEvents(
          RepositoryHistoryEventsRequest(profileId: id, limit: 2),
        );
        await service.dispose();
        service = start();
        await service.reconnect();
        final second = await service.loadRepositoryHistoryEvents(
          RepositoryHistoryEventsRequest(
            profileId: id,
            limit: 200,
            cursor: first.nextCursor,
          ),
        );
        expect(second.historySequence, 10);
        expect(second.events.first.sequence, 3);
        expect(second.scanSessionCount, 4);
        expect(second.scanCommitCount, 6);
        expect(second.trendEligible, isTrue);
        expect(second.scanPoints.map((p) => p.sequence), [4, 7, 9, 10]);
        final failed = await service.loadRepositoryHistoryDiff(
          RepositoryHistoryDiffRequest(
            profileId: id,
            from: RepositoryHistoryEndpoint.scan(
              position: 'previous',
              inventoryScanProfile: null,
            ),
            to: RepositoryHistoryEndpoint.current(),
            studentIds: [],
            resourceKeys: ['a'],
          ),
        );
        expect(failed.fromPoint.available, isFalse);
        expect(failed.inventoryChanges.single.delta, isNull);
        final summary = (await service.loadRepositoryHistorySummary([
          id,
        ])).profiles.single;
        expect(summary.totalScanSessionCount, 4);
        expect(summary.totalCounts['scan'], 6);
        // FB-2b exact13: the persisted latest scan application time.
        expect(summary.toWire().length, 13);
        expect(summary.lastScanAt, f['history']['last_applied_at']['scan']);
        expect(summary.lastScanAt, isNotNull);
        expect((await service.loadRepositoryState(id)).revision, 9);
      } finally {
        await service.dispose();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
