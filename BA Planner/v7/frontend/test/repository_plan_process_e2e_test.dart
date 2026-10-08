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
    'legacy first get, v2 save, restart and goals/document calculation parity',
    () async {
      final storage = await Directory.systemTemp.createTemp('ba_planner_fb1b_');
      const pid = 'aaaaaaaaaaaaaaaaaaaaaaaa';
      final policies =
          (jsonDecode(
                    File(
                      '../contracts/fixtures/repository_plan_migration_v1.json',
                    ).readAsStringSync(),
                  )
                  as Map)['cases']
              as List;
      final policy =
          policies.singleWhere(
                (entry) => entry['id'] == 'null_bond_known_current',
              )
              as Map;
      final profileFile = File('${storage.path}/profiles/$pid.json');
      await profileFile.parent.create(recursive: true);
      await profileFile.writeAsString(
        jsonEncode({
          'version': 1,
          'profile_id': pid,
          'revision': 4,
          'students': policy['students'],
          'inventory': {'version': 1, 'entries': []},
          'goals': policy['legacy_goals'],
          'idempotency': {},
        }),
      );
      await File('${storage.path}/catalog.json').writeAsString(
        jsonEncode({
          'version': 1,
          'selected_profile_id': pid,
          'profiles': [
            {'profile_id': pid, 'display_name': 'Legacy', 'revision': 4},
          ],
        }),
      );
      final config = BackendProcessConfig.resolve(
        backendDirectory: '${Directory.current.parent.path}/backend',
        environment: {'BA_PLANNER_STORAGE_ROOT': storage.path},
      );
      final service = ProcessAppService(
        PlanningProtocolClient(
          () => startBackendProcess(config),
          defaultTimeout: const Duration(seconds: 30),
          waitForStartupProbe: true,
          startupProbeTimeout: const Duration(seconds: 30),
        ),
      );
      try {
        await service.reconnect();
        expect((await service.listProfiles()).single.revision, 4);
        final migrated = await service.loadRepositoryPlan(pid);
        expect(migrated.revision, 5);
        expect(migrated.document.toWire(), policy['expected_document']);
        expect(
          migrated.document.stages.single.nullableTargets['bond_rank'],
          isNull,
        );
        expect((await service.loadRepositoryState(pid)).revision, 5);
        expect((await service.listProfiles()).single.revision, 5);
        final bytesAfterMigration = await profileFile.readAsBytes();
        await service.loadRepositoryPlan(pid);
        expect(await profileFile.readAsBytes(), bytesAfterMigration);

        final wire = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(migrated.document.toWire())) as Map,
        );
        wire['phases'][0]['stages'][0]['targets']['level'] = 20;
        wire['goal_metadata']['aru']['notes'] = 'cross-process plan';
        final document = repositoryActiveDocument(wire);
        Future<int> request() => service.saveRepositoryPlan(
          profileId: pid,
          document: document,
          expectedRevision: 5,
          idempotencyKey: 'v2-save',
        );
        expect(await request(), 6);
        expect(await request(), 6);
        final bytesAfterSave = await profileFile.readAsBytes();
        await expectLater(
          service.saveRepositoryPlan(
            profileId: pid,
            document: document,
            expectedRevision: 5,
            idempotencyKey: 'stale',
          ),
          throwsA(
            isA<BackendRemoteException>().having(
              (e) => e.code,
              'code',
              'revision_conflict',
            ),
          ),
        );
        expect(await profileFile.readAsBytes(), bytesAfterSave);
        await service.restartBackend();
        final restored = await service.loadRepositoryPlan(pid);
        final state = await service.loadRepositoryState(pid);
        expect(restored.revision, 6);
        expect(state.revision, 6);
        expect(restored.document.toWire(), wire);
        expect(state.goals.single.values['target_level'], 20);
        expect(state.goals.single.values['notes'], 'cross-process plan');
        expect(state.goals.single.values.containsKey('bond_rank'), isFalse);
        expect(await profileFile.readAsBytes(), bytesAfterSave);
        final current = [
          for (final student in state.students)
            {'student_id': student.studentId, ...student.values},
        ];
        final goals = {
          'version': 1,
          'goals': [for (final goal in state.goals) goal.values],
        };
        final projection = await service.calculatePlanningDocument(
          currentStudents: current,
          inventory: state.inventory.toWire(),
          document: wire,
        );
        final oldGross = await service.calculatePlan(
          currentStudents: state.students
              .map(confirmedStudentPlanningCurrent)
              .toList(),
          plan: goals,
        );
        Map<String, dynamic> amounts(Map value) =>
            Map<String, dynamic>.from(value)..remove('warnings');
        expect(
          amounts(projection['overall']['cost'] as Map),
          amounts(oldGross),
        );
        expect(restored.calculation!.credits, oldGross['credits']);
        final shortages = await service.calculateShortages(
          currentStudents: state.students
              .map(confirmedStudentPlanningCurrent)
              .toList(),
          plan: goals,
          inventory: state.inventory.toWire(),
        );
        expect(
          {
            for (final raw in projection['overall']['resources'] as List)
              if (raw['resource_key'] != 'credits')
                raw['resource_key']: [
                  raw['required'],
                  raw['owned'],
                  raw['shortage'],
                ],
          },
          {
            for (final row in shortages.rows)
              row.resourceKey: [row.requiredAmount, row.owned, row.shortage],
          },
        );
        expect(
          (projection['overall']['resources'] as List).singleWhere(
            (row) => row['resource_key'] == 'credits',
          )['required'],
          oldGross['credits'],
        );
        wire['phases'][0]['stages'][0]['targets']['bond_rank'] = 40;
        expect(
          await service.saveRepositoryPlan(
            profileId: pid,
            document: repositoryActiveDocument(wire),
            expectedRevision: 6,
            idempotencyKey: 'bond-only',
          ),
          7,
        );
        final bondBytes = await profileFile.readAsBytes();
        final bondProjection = await service.calculatePlanningDocument(
          currentStudents: current,
          inventory: state.inventory.toWire(),
          document: wire,
        );
        expect(
          (bondProjection['warnings'] as List).any(
            (warning) =>
                warning.toString().contains('Bond growth cost is unavailable'),
          ),
          isTrue,
        );
        await expectLater(
          service.saveRepositoryGoals(pid, goals, 7, 'loss'),
          throwsA(
            isA<BackendRemoteException>().having(
              (e) => e.code,
              'code',
              'plan_lossy_write',
            ),
          ),
        );
        expect(await profileFile.readAsBytes(), bondBytes);
        final empty = repositoryActiveDocument(
          policies.singleWhere(
            (p) => p['id'] == 'saved_empty_is_authoritative',
          )['document'],
        );
        expect(
          await service.saveRepositoryPlan(
            profileId: pid,
            document: empty,
            expectedRevision: 7,
            idempotencyKey: 'empty',
          ),
          8,
        );
        await service.restartBackend();
        expect(
          (await service.loadRepositoryPlan(pid)).document.phases,
          isEmpty,
        );
        expect((await service.loadRepositoryState(pid)).goals, isEmpty);
        expect((await service.loadRepositoryPlan(pid)).revision, 8);
      } finally {
        await service.dispose();
        await storage.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
