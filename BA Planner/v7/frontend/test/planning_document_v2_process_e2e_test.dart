import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _case(String name) {
  final fixture =
      jsonDecode(
            File(
              '../contracts/fixtures/planning_document_v2.json',
            ).readAsStringSync(),
          )
          as Map;
  return Map<String, dynamic>.from(
    (fixture['cases'] as List).singleWhere((entry) => entry['name'] == name)
        as Map,
  );
}

ProcessAppService _service(Directory storage) {
  final config = BackendProcessConfig.resolve(
    backendDirectory: '${Directory.current.parent.path}/backend',
    environment: {'BA_PLANNER_STORAGE_ROOT': storage.path},
  );
  return ProcessAppService(
    PlanningProtocolClient(
      () => startBackendProcess(config),
      defaultTimeout: const Duration(seconds: 15),
      waitForStartupProbe: true,
      startupProbeTimeout: const Duration(seconds: 30),
    ),
  );
}

Map<String, String> _activeFiles(Directory storage) => {
  for (final file in storage.listSync(recursive: true).whereType<File>())
    if (!file.path.contains(
      '${Platform.pathSeparator}scenarios${Platform.pathSeparator}',
    ))
      file.path: base64Encode(file.readAsBytesSync()),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'v2 document calculation carries inferred growth and preserves null goals',
    () async {
      final storage = await Directory.systemTemp.createTemp(
        'ba_planner_fb1a_calc_',
      );
      final service = _service(storage);
      try {
        await service.reconnect();
        final entry = _case('partial_weapon');
        final document = PlanningDocument.fromWire(
          Map<String, dynamic>.from(entry['document'] as Map),
        );
        final before = jsonEncode(document.toWire());
        final result = await service.calculatePlanningDocument(
          currentStudents: (entry['current_students'] as List)
              .map((value) => Map<String, dynamic>.from(value as Map))
              .toList(),
          inventory: Map<String, dynamic>.from(entry['inventory'] as Map),
          document: document.toWire(),
        );
        final stages = result['stage_results'] as List;
        expect(stages.first['cost']['star_materials'], isNotEmpty);
        expect(stages.last['cost']['star_materials'], isEmpty);
        expect(result['overall']['cost']['credits'], greaterThan(0));
        expect(jsonEncode(document.toWire()), before);
        expect(document.stages.first.nullableTargets['student_star'], isNull);
        expect(document.stages.first.nullableTargets['weapon_star'], isNull);
        expect(document.stages.first.nullableTargets['bond_rank'], isNull);
      } finally {
        await service.dispose();
        await storage.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'v2 scenario save restart get and mixed v1/v2 comparison round trip',
    () async {
      final storage = await Directory.systemTemp.createTemp(
        'ba_planner_fb1a_scenario_',
      );
      var service = _service(storage);
      try {
        await service.reconnect();
        final profile = await service.createProfile(
          'FB1a scenario',
          'fb1a-profile',
        );
        final entry = _case('partial_weapon');
        final current = Map<String, dynamic>.from(
          (entry['current_students'] as List).single as Map,
        );
        final values = {...current}..remove('student_id');
        final revision = await service.saveRepositoryStudents(
          profile.id,
          [ConfirmedStudentState.fromValues('aru', values)],
          profile.revision,
          'fb1a-students',
        );
        final activeBefore = _activeFiles(storage);
        final document = PlanningDocument.fromWire(
          Map<String, dynamic>.from(entry['document'] as Map),
        );
        final created = await service.createScenario(
          profileId: profile.id,
          expectedRevision: 0,
          idempotencyKey: 'fb1a-create',
          name: 'Nullable',
          description: '',
          baseProfileRevision: revision,
          document: document,
        );
        await service.dispose();
        service = _service(storage);
        await service.reconnect();
        final loaded = (await service.getScenario(
          profile.id,
          created.scenarioId,
        )).scenario;
        expect(loaded.documentVersion, 2);
        expect(loaded.document.toWire(), document.toWire());
        expect(loaded.goalMetadata['aru']!.favorite, isFalse);
        expect(loaded.goalMetadata['aru']!.notes, 'original notes');
        final listed = await service.listScenarios(profile.id);
        expect(listed.scenarios.single.studentIds, ['aru']);
        final v1Fixture =
            jsonDecode(
                  File(
                    '../contracts/fixtures/planning_document_v1_fb1a_parity.json',
                  ).readAsStringSync(),
                )
                as Map;
        final legacy = PlanningDocument.fromWire({
          ...Map<String, dynamic>.from(v1Fixture['document_a'] as Map),
          'document_id': 'legacy',
          'kind': 'scenario',
        });
        final comparison = await service.compareScenarios(
          currentStudents: [current],
          inventory: Map<String, dynamic>.from(entry['inventory'] as Map),
          documentA: loaded.document,
          documentB: legacy,
        );
        expect(
          comparison.projectionA['overall']['cost']['credits'],
          greaterThan(0),
        );
        expect(comparison.comparison['students'], hasLength(2));
        expect(loaded.document.stages.first.nullableTargets['level'], isNull);
        expect(_activeFiles(storage), activeBefore);
      } finally {
        await service.dispose();
        await storage.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
