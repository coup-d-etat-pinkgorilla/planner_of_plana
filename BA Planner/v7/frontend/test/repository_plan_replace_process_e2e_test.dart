import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'legacy get, save, replace, restart and preserved scenario comparison',
    () async {
      final storage = await Directory.systemTemp.createTemp('ba_planner_fb1c_');
      const pid = 'aaaaaaaaaaaaaaaaaaaaaaaa';
      final policy =
          (jsonDecode(
                    File(
                      '../contracts/fixtures/repository_plan_migration_v1.json',
                    ).readAsStringSync(),
                  )
                  as Map)['cases'][0]
              as Map;
      final profile = File('${storage.path}/profiles/$pid.json');
      await profile.parent.create(recursive: true);
      await profile.writeAsString(
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
        final migrated = await service.loadRepositoryPlan(pid);
        expect(migrated.revision, 5);
        expect(
          migrated.document.stages.single.nullableTargets['bond_rank'],
          isNull,
        );
        final oldWire = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(migrated.document.toWire())) as Map,
        );
        oldWire['phases'][0]['stages'][0]['targets']['level'] = 20;
        oldWire['phases'][0]['stages'][0]['targets']['bond_rank'] = 40;
        oldWire['goal_metadata']['aru'] = {
          'favorite': false,
          'notes': ' retained metadata ',
        };
        final saved = repositoryActiveDocument(oldWire);
        expect(
          await service.saveRepositoryPlan(
            profileId: pid,
            document: saved,
            expectedRevision: 5,
            idempotencyKey: 'save-before',
          ),
          6,
        );
        final savedScenario = PlanningDocument.fromWire({
          ...saved.toWire(),
          'kind': 'scenario',
        });
        final original = await service.createScenario(
          profileId: pid,
          expectedRevision: 0,
          idempotencyKey: 'existing',
          name: 'Existing',
          description: '',
          baseProfileRevision: 6,
          document: savedScenario,
        );
        final state = await service.loadRepositoryState(pid);
        final current = [
          for (final student in state.students)
            {'student_id': student.studentId, ...student.values},
        ];
        final inventory = state.inventory.toWire();
        final oldProjection = await service.calculatePlanningDocument(
          currentStudents: current,
          inventory: inventory,
          document: saved.toWire(),
        );
        final nextWire = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(saved.toWire())) as Map,
        );
        nextWire['phases'][0]['stages'][0]['targets']['level'] = 30;
        nextWire['phases'][0]['stages'][0]['targets']['bond_rank'] = null;
        nextWire['goal_metadata']['aru']['notes'] = 'replacement';
        final next = repositoryActiveDocument(nextWire);
        Future<RepositoryPlanReplaceResult> request(ProcessAppService target) =>
            target.replaceRepositoryPlan(
              profileId: pid,
              document: next,
              expectedRevision: 6,
              expectedScenarioRevision: 1,
              idempotencyKey: 'replace-once',
              archiveName: ' Preserved ',
              archiveDescription: ' before replacement ',
            );
        final response = await request(service);
        expect(response.revision, 7);
        expect(response.scenarioRevision, 2);
        expect(response.archivedScenarioId, isNotNull);
        expect((await request(service)).toWire(), response.toWire());
        await service.dispose();
        service = start();
        await service.reconnect();
        final active = await service.loadRepositoryPlan(pid);
        expect(active.revision, 7);
        expect(active.document.toWire(), next.toWire());
        expect((await service.listProfiles()).single.revision, 7);
        expect(
          (await service.loadRepositoryState(
            pid,
          )).goals.single.values['target_level'],
          30,
        );
        final archive = (await service.getScenario(
          pid,
          response.archivedScenarioId!,
        )).scenario;
        expect(archive.document.toWire(), {
          ...savedScenario.toWire(),
          'document_id': response.archivedScenarioId,
        });
        expect(archive.baseProfileRevision, 6);
        expect(archive.name, 'Preserved');
        expect(archive.description, 'before replacement');
        final listed = await service.listScenarios(pid);
        expect(listed.revision, 2);
        expect(listed.currentProfileRevision, 7);
        expect(listed.scenarios.length, 2);
        expect(
          (await service.getScenario(
            pid,
            original.scenarioId,
          )).scenario.document.toWire(),
          savedScenario.toWire(),
        );
        final comparison = await service.compareScenarios(
          currentStudents: current,
          inventory: inventory,
          documentA: archive.document,
          documentB: PlanningDocument.fromWire({
            ...next.toWire(),
            'kind': 'scenario',
          }),
        );
        expect(comparison.projectionA['overall'], oldProjection['overall']);
        expect(
          comparison.comparison['credits_a'],
          oldProjection['overall']['cost']['credits'],
        );
        expect(comparison.comparison['credits_b'], active.calculation!.credits);
        expect(
          comparison
              .comparison['students']
              .single['target_differences']['bond_rank'],
          {'a': 40, 'b': null},
        );
        final bytes = await profile.readAsBytes();
        expect((await request(service)).toWire(), response.toWire());
        expect(await profile.readAsBytes(), bytes);
        await expectLater(
          service.replaceRepositoryPlan(
            profileId: pid,
            document: next,
            expectedRevision: 6,
            expectedScenarioRevision: 1,
            idempotencyKey: 'stale',
            archiveName: 'Preserved',
            archiveDescription: '',
          ),
          throwsA(
            isA<BackendRemoteException>()
                .having((e) => e.code, 'code', 'revision_conflict')
                .having((e) => e.details?['revision_scope'], 'scope', 'both'),
          ),
        );
        expect(await profile.readAsBytes(), bytes);
        expect(
          await service.saveRepositoryPlan(
            profileId: pid,
            document: saved,
            expectedRevision: 5,
            idempotencyKey: 'save-before',
          ),
          6,
        );
        expect((await service.listScenarios(pid)).scenarios.length, 2);
      } finally {
        await service.dispose();
        await storage.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
