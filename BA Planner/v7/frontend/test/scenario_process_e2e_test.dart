import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, int> _targets(int level) => {
  'level': level,
  'bond_rank': 1,
  'student_star': 1,
  'weapon_level': 0,
  'weapon_star': 0,
  'ex_skill': 1,
  'skill1': 1,
  'skill2': 1,
  'skill3': 1,
  'equip1_tier': 0,
  'equip2_tier': 0,
  'equip3_tier': 0,
  'equip1_level': 0,
  'equip2_level': 0,
  'equip3_level': 0,
  'equip4_tier': 0,
  'stat_hp': 0,
  'stat_atk': 0,
  'stat_heal': 0,
};

PlanningDocument _document(String id, int level) => PlanningDocument(
  id: id,
  name: id,
  kind: PlanningDocumentKind.scenario,
  phases: [
    PlanningDocumentPhase(
      id: '$id-phase',
      name: '페이즈 1',
      stages: [
        PlanningDocumentStage(
          id: '$id-stage',
          studentId: 'ayane',
          name: '목표',
          targets: _targets(level),
        ),
      ],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real Dart to Python scenario lifecycle and comparison are isolated',
    () async {
      final storageRoot = await Directory.systemTemp.createTemp(
        'ba_planner_v7_scenario_e2e_',
      );
      final backendDirectory = Directory(
        '${Directory.current.parent.path}${Platform.pathSeparator}backend',
      );
      final config = BackendProcessConfig.resolve(
        backendDirectory: backendDirectory.path,
        environment: {'BA_PLANNER_STORAGE_ROOT': storageRoot.path},
      );
      BackendProcessHandle? process;
      ProcessAppService? service;
      try {
        service = ProcessAppService(
          PlanningProtocolClient(() async {
            process = await startBackendProcess(config);
            return process!;
          }, defaultTimeout: const Duration(seconds: 10)),
        );
        await service.reconnect();
        final profile = await service.createProfile(
          'Scenario E2E',
          'scenario-profile',
        );
        final documentA = _document('scenario-a', 8);
        final documentB = _document('scenario-b', 10);
        final created = await service.createScenario(
          profileId: profile.id,
          expectedRevision: 0,
          idempotencyKey: 'create-a',
          name: '후보 A',
          description: '',
          baseProfileRevision: profile.revision,
          document: documentA,
        );
        final list = await service.listScenarios(profile.id);
        expect(list.revision, 1);
        expect(list.scenarios.single.id, created.scenarioId);
        expect(list.scenarios.single.studentCount, 1);
        final loaded = await service.getScenario(
          profile.id,
          created.scenarioId,
        );
        expect(loaded.scenario.document.kind, PlanningDocumentKind.scenario);
        expect(
          loaded.scenario.isStaleAgainst(list.currentProfileRevision),
          isFalse,
        );

        final comparison = await service.compareScenarios(
          currentStudents: const [
            {'student_id': 'ayane', 'level': 1, 'student_star': 1},
          ],
          inventory: const {
            'version': 1,
            'entries': [
              {'key': 'credits', 'quantity': '0'},
            ],
          },
          documentA: documentA,
          documentB: documentB,
        );
        expect(
          comparison.comparison['credits_delta_b_minus_a'],
          greaterThan(0),
        );
        expect(comparison.comparison.containsKey('winner'), isFalse);

        final copied = await service.duplicateScenario(
          profileId: profile.id,
          scenarioId: created.scenarioId,
          expectedRevision: created.revision,
          expectedScenarioRevision: loaded.scenario.revision,
          idempotencyKey: 'duplicate-a',
        );
        expect(copied.revision, 2);
        expect(
          (await service.listScenarios(profile.id)).scenarios,
          hasLength(2),
        );
        expect(
          (await service.loadRepositoryState(profile.id)).revision,
          profile.revision,
        );
      } finally {
        await service?.dispose();
        if (process != null) {
          await process!.exitCode.timeout(const Duration(seconds: 5));
        }
        if (await storageRoot.exists()) {
          await storageRoot.delete(recursive: true);
        }
      }
    },
  );
}
