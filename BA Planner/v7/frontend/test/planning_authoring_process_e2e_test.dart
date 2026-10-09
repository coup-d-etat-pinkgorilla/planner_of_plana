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
    'authoring plan save, restart get, replace, restart get and archived bundle',
    () async {
      final storage = await Directory.systemTemp.createTemp('ba_planner_fb8a_');
      final cases =
          (jsonDecode(
                    File(
                      '../contracts/fixtures/planning_authoring_v1.json',
                    ).readAsStringSync(),
                  )
                  as Map)['cases']
              as List;
      Map policy(String name) =>
          cases.cast<Map>().singleWhere((c) => c['name'] == name);
      final savedCase = policy('deferred-targets-selected-order');
      final saved = repositoryActiveDocument(savedCase['document']);
      final savedAuthoring = PlanningAuthoring.fromWire(
        savedCase['authoring'],
        saved,
      );
      final nextCase = policy('all-deferred');
      final next = repositoryActiveDocument(nextCase['document']);
      final nextAuthoring = PlanningAuthoring.fromWire(
        nextCase['authoring'],
        next,
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
        final profile = await service.createProfile('FB8a', 'create');
        final pid = profile.id;
        final initial = await service.loadRepositoryPlan(pid);
        expect(initial.revision, 0);
        expect(initial.hasAuthoring, false);
        expect(
          await service.saveRepositoryPlan(
            profileId: pid,
            document: saved,
            authoring: savedAuthoring,
            expectedRevision: 0,
            idempotencyKey: 'save',
          ),
          1,
        );
        await service.dispose();
        service = start();
        await service.reconnect();
        final retrieved = await service.loadRepositoryPlan(pid);
        expect(retrieved.document.toWire(), saved.toWire());
        expect(retrieved.authoring.toWire(), savedCase['canonical']);
        expect(retrieved.authoring.studentOrder, [
          'ayane',
          'aru',
          'unknown-selected',
        ]);
        final state = await service.loadRepositoryState(pid);
        expect(state.goals.map((g) => g.studentId), ['aru', 'ayane']);
        final current = [
          for (final student in state.students)
            {'student_id': student.studentId, ...student.values},
        ];
        final beforeProjection = await service.calculatePlanningDocument(
          currentStudents: current,
          inventory: state.inventory.toWire(),
          document: saved.toWire(),
        );
        await expectLater(
          service.saveRepositoryPlan(
            profileId: pid,
            document: next,
            expectedRevision: 1,
            idempotencyKey: 'incompatible',
          ),
          throwsA(
            isA<BackendRemoteException>().having(
              (e) => e.details?['reason'],
              'reason',
              'authoring_required',
            ),
          ),
        );
        Future<RepositoryPlanReplaceResult> replace(ProcessAppService s) =>
            s.replaceRepositoryPlan(
              profileId: pid,
              document: next,
              authoring: nextAuthoring,
              expectedRevision: 1,
              expectedScenarioRevision: 0,
              idempotencyKey: 'replace',
              archiveName: 'Before',
              archiveDescription: 'Full bundle',
            );
        final result = await replace(service);
        expect(result.revision, 2);
        expect(result.scenarioRevision, 1);
        expect(result.archivedScenarioId, isNotNull);
        await service.dispose();
        service = start();
        await service.reconnect();
        final active = await service.loadRepositoryPlan(pid);
        expect(active.revision, 2);
        expect(active.document.toWire(), next.toWire());
        expect(active.authoring.toWire(), nextCase['canonical']);
        expect(active.calculation!.credits, 0);
        expect((await service.loadRepositoryState(pid)).goals, isEmpty);
        final archive = (await service.getScenario(
          pid,
          result.archivedScenarioId!,
        )).scenario;
        expect(archive.authoring.toWire(), savedCase['canonical']);
        expect(archive.document.toWire(), {
          ...saved.toWire(),
          'kind': 'scenario',
          'document_id': archive.id,
        });
        final listed = await service.listScenarios(pid);
        expect(listed.revision, 1);
        expect(listed.scenarios.single.stageCount, 3);
        final comparison = await service.compareScenarios(
          currentStudents: current,
          inventory: state.inventory.toWire(),
          documentA: archive.document,
          documentB: PlanningDocument.fromWire({
            ...next.toWire(),
            'kind': 'scenario',
          }),
        );
        expect(comparison.projectionA['overall'], beforeProjection['overall']);
        expect(comparison.comparison['credits_b'], 0);
        expect((await replace(service)).toWire(), result.toWire());
        // The next replacement must also preserve an all-deferred active bundle.
        final second = await service.replaceRepositoryPlan(
          profileId: pid,
          document: next,
          expectedRevision: 2,
          expectedScenarioRevision: 1,
          idempotencyKey: 'replace-deferred',
          archiveName: 'Later',
          archiveDescription: '',
        );
        expect(second.scenarioRevision, 2);
        expect(second.archivedScenarioId, isNotNull);
        expect(
          (await service.getScenario(
            pid,
            second.archivedScenarioId!,
          )).scenario.authoring.toWire(),
          nextCase['canonical'],
        );
        expect((await service.loadRepositoryPlan(pid)).hasAuthoring, false);
      } finally {
        await service.dispose();
        await storage.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
