import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'manual current + nochange + replay + restart summary preserves first timestamps',
    () async {
      final storage = await Directory.systemTemp.createTemp('ba_planner_fb2a_');
      final config = BackendProcessConfig.resolve(
        backendDirectory: '${Directory.current.parent.path}/backend',
        environment: {'BA_PLANNER_STORAGE_ROOT': storage.path},
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
        final profile = await service.createProfile('History', 'fb2a-profile');
        final id = profile.id;
        Future<RepositoryHistorySummary> summary() async =>
            (await service.loadRepositoryHistorySummary([id])).profiles.single;
        expect((await summary()).coverage.origin, 'empty');
        final students = [
          ConfirmedStudentState.fromWire({
            'version': 1,
            'student_id': 'aru',
            'values': {'level': 0, 'bond_rank': null},
            'provenance': {'level': 'manual-fixture'},
          }),
        ];
        expect(
          await service.saveRepositoryStudents(id, students, 0, 'students'),
          1,
        );
        final first = (await summary()).toWire();
        expect(
          await service.saveRepositoryStudents(id, students, 0, 'students'),
          1,
        );
        expect((await summary()).toWire(), first);
        final inventory = RepositoryInventoryState.fromEntries([
          {'key': 'unknown-future', 'quantity': null},
          {'key': 'unknown-zero', 'quantity': '0'},
          {
            'key': 'unknown-large',
            'quantity': '999999999999999999999999999999999999',
          },
        ]);
        expect(
          await service.saveRepositoryInventory(id, inventory, 1, 'inventory'),
          2,
        );
        expect(
          await service.saveRepositoryInventory(id, inventory, 2, 'nochange'),
          3,
        );
        final saved = (await summary()).toWire();
        expect(saved['total_counts'], {
          'scan': 0,
          'manual': 3,
          'import': 0,
          'unattributed': 0,
        });
        // FB-2b exact13: manual writes never fill the profile scan time.
        expect(saved.length, 13);
        expect(saved.containsKey('last_scan_at'), isTrue);
        expect(saved['last_scan_at'], isNull);
        final current = await service.loadRepositoryState(id);
        expect(current.students.single.toWire(), students.single.toWire());
        final plan = await service.loadRepositoryPlan(id);
        await service.saveRepositoryPlan(
          profileId: id,
          document: plan.document,
          expectedRevision: 3,
          idempotencyKey: 'plan',
        );
        final summaryWithPlan = (await summary()).toWire();
        expect(summaryWithPlan, {...saved, 'revision': 4});
        await service.dispose();
        service = start();
        await service.reconnect();
        expect((await summary()).toWire(), summaryWithPlan);
        expect(
          await service.saveRepositoryInventory(id, inventory, 2, 'nochange'),
          3,
        );
        expect((await summary()).toWire(), summaryWithPlan);
        await expectLater(
          service.saveRepositoryInventory(id, inventory, 2, 'stale'),
          throwsA(
            isA<BackendRemoteException>().having(
              (e) => e.code,
              'code',
              'revision_conflict',
            ),
          ),
        );
        await expectLater(
          service.saveRepositoryStudents(id, [], 0, 'students'),
          throwsA(
            isA<BackendRemoteException>().having(
              (e) => e.code,
              'code',
              'idempotency_conflict',
            ),
          ),
        );
        final raw =
            jsonDecode(
                  await File(
                    '${storage.path}/profiles/$id.json',
                  ).readAsString(),
                )
                as Map;
        final history = RepositoryCurrentHistory.fromWire(
          Map<String, dynamic>.from(raw['current_history'] as Map),
        );
        expect(history.events.last.inventoryChanges, isEmpty);
        expect(history.events.first.recordedAt, first['last_manual_at']);
        expect(
          history.events.first.studentChanges.single.after.value!.provenance,
          {'level': 'manual-fixture'},
        );
      } finally {
        await service.dispose();
        await storage.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'legacy first write baseline and v6 import seed survive restart',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'ba_planner_fb2a_legacy_',
      );
      final storage = Directory('${temp.path}/repository');
      final v6 = Directory('${temp.path}/v6');
      await v6.create(recursive: true);
      await File('${v6.path}/config.json').writeAsString(
        jsonEncode({
          'profiles': [
            {'key': 'profile_deadbeef', 'name': 'Imported'},
          ],
        }),
      );
      final current = Directory(
        '${v6.path}/profiles/profile_deadbeef/data/current',
      );
      await current.create(recursive: true);
      await File('${current.path}/students.json').writeAsString(
        jsonEncode({
          'aru': {'student_id': 'aru', 'level': 80, 'bond_rank': 12},
        }),
      );
      await File('${current.path}/inventory.json').writeAsString(
        jsonEncode({
          'unknown': {'item_id': 'unknown', 'quantity': 7},
        }),
      );
      await File(
        '${current.path}/growth_plan.json',
      ).writeAsString(jsonEncode({'version': 1, 'goals': <dynamic>[]}));
      final config = BackendProcessConfig.resolve(
        backendDirectory: '${Directory.current.parent.path}/backend',
        environment: {
          'BA_PLANNER_STORAGE_ROOT': storage.path,
          'BA_PLANNER_V6_DIR': v6.path,
        },
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
        final profile = await service.createProfile('Legacy', 'legacy');
        final id = profile.id;
        await service.dispose();
        final path = File('${storage.path}/profiles/$id.json');
        final raw = jsonDecode(await path.readAsString()) as Map;
        raw.remove('current_history');
        raw.remove('plan');
        raw['students'] = [
          {
            'version': 1,
            'student_id': 'aru',
            'values': {'level': 80},
          },
        ];
        await path.writeAsString(jsonEncode(raw));
        service = start();
        await service.reconnect();
        final unrecorded = (await service.loadRepositoryHistorySummary([
          id,
        ])).profiles.single;
        expect(unrecorded.revision, 0);
        expect(unrecorded.coverage.origin, 'unrecorded');
        final state = await service.loadRepositoryState(id);
        expect(state.revision, 1);
        await service.saveRepositoryStudents(
          id,
          state.students,
          1,
          'legacy-first',
        );
        final imported = await service.importV6Account('profile_deadbeef');
        final importedId = imported.profile.id;
        final saved = await service.loadRepositoryHistorySummary([
          id,
          importedId,
        ]);
        expect(saved.profiles[0].coverage.origin, 'legacy');
        expect(saved.profiles[0].coverage.baselineAt, isNull);
        expect(saved.profiles[1].lastImportAt, isNotNull);
        expect(saved.profiles[1].totalCounts['import'], 1);
        expect(unrecorded.lastScanAt, isNull);
        expect(saved.profiles[0].lastScanAt, isNull);
        expect(saved.profiles[1].lastScanAt, isNull);
        expect(saved.profiles[1].totalScanSessionCount, 0);
        await service.dispose();
        service = start();
        await service.reconnect();
        expect(
          (await service.loadRepositoryHistorySummary([
            id,
            importedId,
          ])).toWire(),
          saved.toWire(),
        );
        final rawHistory =
            jsonDecode(await path.readAsString())['current_history'] as Map;
        final history = RepositoryCurrentHistory.fromWire(
          Map<String, dynamic>.from(rawHistory),
        );
        expect(history.events.single.studentChanges, isEmpty);
      } finally {
        await service.dispose();
        await temp.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
