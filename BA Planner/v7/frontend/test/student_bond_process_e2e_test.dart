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
    'one bond process round trip preserves gross costs and repository bytes',
    () async {
      final storage = await Directory.systemTemp.createTemp(
        'ba_planner_fb11b_',
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
        final profile = await service.createProfile('FB11b', 'fb11b-profile');
        final before = await service.loadRepositoryState(profile.id);
        final files = _files(storage);
        final fixture =
            jsonDecode(
                  File(
                    '../contracts/fixtures/planning_student_bond_v1.json',
                  ).readAsStringSync(),
                )
                as Map;
        final entry =
            (fixture['cases'] as List).singleWhere(
                  (entry) => entry['name'] == 'owned_then_shortage',
                )
                as Map;
        final input = Map<String, dynamic>.from(
          entry['request']['payload'] as Map,
        );
        final AppService app = service;
        final result = await app.calculateStudent(
          currentStudent: Map<String, dynamic>.from(
            input['current_student'] as Map,
          ),
          targets: Map<String, int>.from(input['targets'] as Map),
          inventory: Map<String, dynamic>.from(input['inventory'] as Map),
          bond: StudentBondRequest(
            currentRank: input['bond']['current_rank'] as int?,
          ),
        );
        expect(result.reservedBond, entry['response']['payload']['bond']);
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
        expect(result.bond!.preferredLarge.shortage, 1);
        expect(result.bond!.petting.requiredCount, 24);
        expect(result.bond!.petting.minimumHours, 69);
        expect(result.bond!.petting.availableCount, isNull);
        expect(
          result.resources.any((row) => row.category == 'present'),
          isFalse,
        );
        expect(
          (await service.loadRepositoryState(profile.id)).revision,
          before.revision,
        );
        expect(_files(storage), files);
      } finally {
        await service.dispose();
        await storage.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
