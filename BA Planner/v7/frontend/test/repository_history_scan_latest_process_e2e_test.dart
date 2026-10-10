import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:flutter_test/flutter_test.dart';

// fb2b-dart: real Python `repository.history.scan_latest` and summary exact13
// through the strict Dart client, with the shared FB-2b fixture histories.
Map<String, dynamic> copy(Object? value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = copy(
    jsonDecode(
      File(
        '../contracts/fixtures/repository_history_scan_latest_v1.json',
      ).readAsStringSync(),
    ),
  );
  test(
    'fixture histories, summary last_scan_at and stale anchor survive the real backend',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'ba_planner_fb2b_scan_latest_',
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
      final cases = [
        for (final raw in fixture['valid_history_cases'] as List) copy(raw),
      ];
      var service = start();
      try {
        await service.reconnect();
        final ids = <String, String>{};
        for (final row in cases) {
          final profile = await service.createProfile(
            'FB-2b ${row['id']}',
            'fb2b-${row['id']}',
          );
          ids[row['id'] as String] = profile.id;
        }
        await service.dispose();
        // Inject each fixture history as the persisted profile history.
        final catalogFile = File('${root.path}/catalog.json');
        final catalog = copy(jsonDecode(await catalogFile.readAsString()));
        for (final row in cases) {
          final id = ids[row['id']]!;
          final path = File('${root.path}/profiles/$id.json');
          final wire = copy(jsonDecode(await path.readAsString()));
          wire['revision'] = row['revision'];
          wire['students'] = <dynamic>[];
          wire['inventory'] = {'version': 1, 'entries': <dynamic>[]};
          if (row['history'] == null) {
            wire.remove('current_history');
          } else {
            wire['current_history'] = row['history'];
          }
          await path.writeAsString(jsonEncode(wire));
          for (final summary in catalog['profiles'] as List) {
            if (summary['profile_id'] == id) {
              summary['revision'] = row['revision'];
            }
          }
        }
        await catalogFile.writeAsString(jsonEncode(catalog));
        service = start();
        await service.reconnect();
        for (final row in cases) {
          final id = ids[row['id']]!;
          final request = RepositoryHistoryScanLatestRequest.fromWire(
            copy(row['request'])..['profile_id'] = id,
          );
          final expected = copy(row['expected'])..['profile_id'] = id;
          final result = await service.loadRepositoryHistoryScanLatest(
            request,
          );
          expect(result.toWire(), expected, reason: row['id'] as String);
          final summary = (await service.loadRepositoryHistorySummary([
            id,
          ])).profiles.single;
          // Summary exact13: the same persisted profile scan time.
          expect(summary.toWire().length, 13);
          expect(
            summary.lastScanAt,
            expected['last_scan_at'],
            reason: row['id'] as String,
          );
          expect(summary.revision, row['revision']);
        }

        // Paging: first page anchors the snapshot; a new current application
        // makes the old anchor stale (invalid_payload, not retryable).
        final pagedId = ids['first_kind_page_latest_sequence_order']!;
        final first = await service.loadRepositoryHistoryScanLatest(
          RepositoryHistoryScanLatestRequest(
            profileId: pagedId,
            includeByKind: true,
            byKindLimit: 1,
          ),
        );
        expect(first.historySequence, 3);
        expect(first.byKindNextAfterSequence, 2);
        final firstRequest = RepositoryHistoryScanLatestRequest(
          profileId: pagedId,
          includeByKind: true,
          byKindLimit: 1,
        );
        final second = await service.loadRepositoryHistoryScanLatest(
          firstRequest.nextKindPage(first),
        );
        expect(second.byKind.single.sequence, 3);
        expect(second.byKindNextAfterSequence, isNull);
        final state = await service.loadRepositoryState(pagedId);
        await service.saveRepositoryInventory(
          pagedId,
          state.inventory,
          state.revision,
          'fb2b-manual-after-first-page',
        );
        await expectLater(
          service.loadRepositoryHistoryScanLatest(
            firstRequest.nextKindPage(first),
          ),
          throwsA(
            isA<BackendRemoteException>()
                .having((e) => e.code, 'code', 'invalid_payload')
                .having(
                  (e) => e.details?['reason'],
                  'reason',
                  'stale_scan_latest',
                )
                .having((e) => e.retryable, 'retryable', isFalse),
          ),
        );
        final restarted = await service.loadRepositoryHistoryScanLatest(
          RepositoryHistoryScanLatestRequest(
            profileId: pagedId,
            includeByKind: true,
          ),
        );
        // A manual write never becomes the profile scan time.
        expect(restarted.historySequence, 4);
        expect(restarted.lastScanAt, first.lastScanAt);
        expect(restarted.byKind.length, 2);
        final summary = (await service.loadRepositoryHistorySummary([
          pagedId,
        ])).profiles.single;
        expect(summary.lastScanAt, first.lastScanAt);
        expect(summary.lastManualAt, isNotNull);
        expect(summary.totalCounts['scan'], 3);

        // Reads are read-only across restart: same file bytes, same result.
        final path = File('${root.path}/profiles/$pagedId.json');
        final bytes = await path.readAsString();
        await service.dispose();
        service = start();
        await service.reconnect();
        expect(
          (await service.loadRepositoryHistoryScanLatest(
            RepositoryHistoryScanLatestRequest(
              profileId: pagedId,
              includeByKind: true,
            ),
          )).toWire(),
          restarted.toWire(),
        );
        expect(await path.readAsString(), bytes);
      } finally {
        await service.dispose();
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 180)),
  );
}
