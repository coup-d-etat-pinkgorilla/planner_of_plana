import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real KR catalog availability matches bundle and mock for every student',
    () async {
      final storage = await Directory.systemTemp.createTemp(
        'ba_planner_fb13_e2e_',
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
      final mock = MockAppService(fullStudentCatalog: true);
      try {
        await service.reconnect();
        final runtime = await service.listStudents();
        final bundled =
            jsonDecode(
                  await rootBundle.loadString('assets/student_catalog.json'),
                )
                as List;
        final mockEntries = await mock.listStudents();
        final expected = {
          for (final raw in bundled)
            (raw as Map)['student_id'] as String:
                raw['has_favorite_item'] as bool,
        };
        expect({
          for (final entry in runtime) entry.studentId: entry.hasFavoriteItem,
        }, expected);
        expect({
          for (final entry in mockEntries)
            entry.studentId: entry.hasFavoriteItem,
        }, expected);
        expect({
          for (final entry in runtime)
            entry.studentId: entry.metadata['has_favorite_item'],
        }, expected);
        // Canonical KR/JP difference: Ayane has a JP favorite item, but not a KR one.
        expect(expected['aru'], isTrue);
        expect(expected['airi'], isFalse);
        expect(expected['ayane'], isFalse);
        expect(expected['asuna'], isFalse);
        expect(
          runtime
              .firstWhere((entry) => entry.studentId == 'hoshino_battle')
              .forms,
          hasLength(2),
        );
      } finally {
        await service.dispose();
        await mock.dispose();
        await storage.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
