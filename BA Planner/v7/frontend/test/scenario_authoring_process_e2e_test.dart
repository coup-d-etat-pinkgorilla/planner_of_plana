import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/scenario_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'scenario authoring create/update/duplicate/restart/get/compare and first replay',
    () async {
      final storage = await Directory.systemTemp.createTemp('ba-fb8b-');
      final cases =
          (jsonDecode(
                    File(
                      '../contracts/fixtures/planning_authoring_v1.json',
                    ).readAsStringSync(),
                  )
                  as Map)['cases']
              as List;
      ({PlanningDocument document, PlanningAuthoring authoring}) bundle(
        String name,
      ) {
        final c = cases.cast<Map>().singleWhere((c) => c['name'] == name);
        final doc = scenarioDocumentFromWire({
          ...Map<String, dynamic>.from(c['document'] as Map),
          'kind': 'scenario',
        });
        return (
          document: doc,
          authoring: PlanningAuthoring.fromWire(c['canonical'], doc),
        );
      }

      final b = bundle('deferred-targets-selected-order');
      final later = bundle('all-deferred');
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
      var s = start();
      try {
        await s.reconnect();
        final profile = await s.createProfile('FB8b', 'profile');
        final pid = profile.id;
        final initial = await s.loadRepositoryState(pid);
        final active = (await s.loadRepositoryPlan(pid)).document.toWire();
        Future<PlanningScenarioMutationResult> create() => s.createScenario(
          profileId: pid,
          expectedRevision: 0,
          idempotencyKey: 'create',
          name: 'Candidate',
          description: 'Full authoring',
          baseProfileRevision: 0,
          document: b.document,
          authoring: b.authoring,
        );
        final created = await create();
        final changed = PlanningAuthoring.fromWire({
          ...b.authoring.toWire(),
          'student_order': b.authoring.studentOrder.reversed.toList(),
        }, b.document);
        Future<PlanningScenarioMutationResult> metadata() => s.updateScenario(
          profileId: pid,
          scenarioId: created.scenarioId,
          expectedRevision: 1,
          expectedScenarioRevision: 0,
          idempotencyKey: 'metadata',
          name: 'Candidate',
          description: 'Full authoring',
          baseProfileRevision: 0,
          document: b.document,
          authoring: changed,
        );
        final updated = await metadata();
        expect(updated.revision, 2);
        Future<PlanningScenarioMutationResult> duplicate() =>
            s.duplicateScenario(
              profileId: pid,
              scenarioId: created.scenarioId,
              expectedRevision: 2,
              expectedScenarioRevision: 1,
              idempotencyKey: 'copy',
            );
        final copied = await duplicate();
        expect((await duplicate()).scenarioId, copied.scenarioId);
        await s.dispose();
        s = start();
        await s.reconnect();
        final source = (await s.getScenario(pid, created.scenarioId)).scenario;
        final restored = (await s.getScenario(pid, copied.scenarioId)).scenario;
        expect(source.revision, 1);
        expect(restored.revision, 0);
        expect(source.authoring.toWire(), changed.toWire());
        expect(restored.authoring.toWire(), changed.toWire());
        expect(restored.document.toWire(), {
          ...b.document.toWire(),
          'document_id': copied.scenarioId,
          'name': 'Candidate (복사본)',
        });
        final listed = await s.listScenarios(pid);
        expect(listed.revision, 3);
        expect(listed.scenarios.length, 2);
        for (final item in listed.scenarios) {
          expect(item.phaseCount, 2);
          expect(item.stageCount, 3);
          expect(item.studentCount, 2);
          expect(item.studentIds, isNot(contains('unknown-selected')));
        }
        final current = [
          for (final student in initial.students)
            {'student_id': student.studentId, ...student.values},
        ];
        final projection = await s.calculatePlanningDocument(
          currentStudents: current,
          inventory: initial.inventory.toWire(),
          document: source.document.toWire(),
        );
        final comparison = await s.compareScenarios(
          currentStudents: current,
          inventory: initial.inventory.toWire(),
          documentA: source.document,
          documentB: restored.document,
        );
        expect(comparison.projectionA['overall'], projection['overall']);
        expect(comparison.projectionB['overall'], projection['overall']);
        expect(
          comparison.comparison['credits_a'],
          comparison.comparison['credits_b'],
        );
        await expectLater(
          s.updateScenario(
            profileId: pid,
            scenarioId: created.scenarioId,
            expectedRevision: 3,
            expectedScenarioRevision: 1,
            idempotencyKey: 'incompatible',
            name: 'Later',
            description: '',
            baseProfileRevision: 0,
            document: later.document,
          ),
          throwsA(
            isA<BackendRemoteException>().having(
              (e) => e.details?['reason'],
              'reason',
              'authoring_required',
            ),
          ),
        );
        await s.updateScenario(
          profileId: pid,
          scenarioId: created.scenarioId,
          expectedRevision: 3,
          expectedScenarioRevision: 1,
          idempotencyKey: 'later',
          name: 'Later',
          description: '',
          baseProfileRevision: 0,
          document: later.document,
          authoring: later.authoring,
        );
        await expectLater(
          s.updateScenario(
            profileId: pid,
            scenarioId: created.scenarioId,
            expectedRevision: 3,
            expectedScenarioRevision: 2,
            idempotencyKey: 'stale',
            name: 'Later',
            description: '',
            baseProfileRevision: 0,
            document: later.document,
            authoring: later.authoring,
          ),
          throwsA(
            isA<BackendRemoteException>().having(
              (e) => e.code,
              'code',
              'revision_conflict',
            ),
          ),
        );
        await s.dispose();
        s = start();
        await s.reconnect();
        final deferred = (await s.getScenario(
          pid,
          created.scenarioId,
        )).scenario;
        expect(deferred.authoring.toWire(), later.authoring.toWire());
        final emptySummary = (await s.listScenarios(
          pid,
        )).scenarios.singleWhere((v) => v.id == created.scenarioId);
        expect(emptySummary.stageCount, 0);
        expect(emptySummary.studentCount, 0);
        expect(emptySummary.calculation!.credits, 0);
        final excluding = await s.compareScenarios(
          currentStudents: current,
          inventory: initial.inventory.toWire(),
          documentA: restored.document,
          documentB: deferred.document,
        );
        expect(excluding.comparison['credits_b'], 0);
        expect((await metadata()).revision, updated.revision);
        expect((await create()).scenarioId, created.scenarioId);
        expect((await duplicate()).scenarioId, copied.scenarioId);
        expect((await s.listScenarios(pid)).revision, 4);
        expect((await s.loadRepositoryState(pid)).revision, initial.revision);
        expect((await s.loadRepositoryPlan(pid)).document.toWire(), active);
        // Metadata-free v1 still follows the old record shape/default and replay.
        final legacy = scenarioDocumentFromWire({
          'version': 1,
          'document_id': 'legacy',
          'name': 'Legacy',
          'kind': 'scenario',
          'phases': <dynamic>[],
        });
        final old = await s.createScenario(
          profileId: pid,
          expectedRevision: 4,
          idempotencyKey: 'legacy',
          name: 'Legacy',
          description: '',
          baseProfileRevision: 0,
          document: legacy,
        );
        await s.dispose();
        s = start();
        await s.reconnect();
        final oldRecord = (await s.getScenario(pid, old.scenarioId)).scenario;
        expect(oldRecord.hasAuthoring, false);
        expect(oldRecord.documentVersion, 1);
        expect(oldRecord.document.toWire(), legacy.toWire());
      } finally {
        await s.dispose();
        await storage.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
