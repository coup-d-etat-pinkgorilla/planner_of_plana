import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _files(Directory root) => {
  for (final file in root.listSync(recursive: true).whereType<File>())
    file.path: base64Encode(file.readAsBytesSync()),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'one real student calculation round trip preserves repository and document parity',
    () async {
      final storage = await Directory.systemTemp.createTemp(
        'ba_planner_fb11a_e2e_',
      );
      final config = BackendProcessConfig.resolve(
        backendDirectory: '${Directory.current.parent.path}/backend',
        environment: {'BA_PLANNER_STORAGE_ROOT': storage.path},
      );
      final service = ProcessAppService(
        PlanningProtocolClient(
          () => startBackendProcess(config),
          defaultTimeout: const Duration(seconds: 15),
          waitForStartupProbe: true,
          startupProbeTimeout: const Duration(seconds: 30),
        ),
      );
      try {
        await service.reconnect();
        final profile = await service.createProfile(
          'FB11a process',
          'fb11a-process-profile',
        );
        final before = await service.loadRepositoryState(profile.id);
        final scenariosBefore = await service.listScenarios(profile.id);
        final filesBefore = _files(storage);
        final fixture =
            jsonDecode(
                  File(
                    '${Directory.current.parent.path}/contracts/'
                    'fixtures/planning_student_calculate_v1.json',
                  ).readAsStringSync(),
                )
                as Map;
        final entry =
            (fixture['cases'] as List).singleWhere(
                  (raw) => raw['name'] == 'mixed_inventory',
                )
                as Map;
        final input = Map<String, dynamic>.from(
          entry['request']['payload'] as Map,
        );
        final current = Map<String, dynamic>.from(
          input['current_student'] as Map,
        );
        final targets = Map<String, int>.from(input['targets'] as Map);
        final inventory = Map<String, dynamic>.from(input['inventory'] as Map);
        final AppService appService = service;
        final result = await appService.calculateStudent(
          currentStudent: current,
          targets: targets,
          inventory: inventory,
        );
        expect(
          result.credits,
          entry['response']['payload']['totals']['credits'],
        );
        expect(
          result.creditBreakdown,
          entry['response']['payload']['credit_breakdown'],
        );
        expect(
          result.resources.map((row) => row.toWire()).toList(),
          entry['response']['payload']['resources'],
        );
        expect(result.reservedBond, isNull);

        final projection = await service.calculatePlanningDocument(
          currentStudents: [current],
          inventory: inventory,
          document: {
            'version': 1,
            'document_id': 'growth-calculator',
            'name': '성장 계산기',
            'kind': 'scenario',
            'phases': [
              {
                'phase_id': 'growth-calculator-phase',
                'name': '성장 계산기',
                'stages': [
                  {
                    'stage_id': 'growth-calculator-stage',
                    'student_id': current['student_id'],
                    'name': '계산기 목표',
                    'targets': targets,
                  },
                ],
              },
            ],
          },
        );
        expect(result.credits, projection['overall']['cost']['credits']);
        expect(
          result.resources.map((row) => row.toWire()).toList(),
          projection['overall']['resources'],
        );
        expect(result.warnings, projection['warnings']);
        final after = await service.loadRepositoryState(profile.id);
        expect(after.revision, before.revision);
        expect(after.goals, before.goals);
        expect(
          (await service.listScenarios(profile.id)).scenarios,
          scenariosBefore.scenarios,
        );
        expect(
          _files(storage),
          filesBefore,
          reason: 'both calculations must leave saved files byte-identical',
        );
      } finally {
        await service.dispose();
        await storage.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
