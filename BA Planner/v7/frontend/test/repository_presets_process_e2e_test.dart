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
    'presets save, restart get, stale revision and original idempotent replay',
    () async {
      final storage = await Directory.systemTemp.createTemp('ba_planner_fb14_');
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
        final profile = await service.createProfile('Presets', 'fb14-profile');
        final pid = profile.id;
        final plan = await service.loadRepositoryPlan(pid);
        final state = await service.loadRepositoryState(pid);
        final fixture =
            jsonDecode(
                  File(
                    '../contracts/fixtures/repository_presets_v1.json',
                  ).readAsStringSync(),
                )
                as Map;
        final source = Map<String, dynamic>.from(
          (fixture['cases'][0]['message']['payload']) as Map,
        );
        RepositoryPresetsSaveRequest request({
          int revision = 0,
          String key = 'first',
          bool empty = false,
        }) => RepositoryPresetsSaveRequest.fromWire({
          ...source,
          'profile_id': pid,
          'expected_revision': revision,
          'idempotency_key': key,
          if (empty) 'stage_presets': <dynamic>[],
          if (empty) 'student_groups': <dynamic>[],
        });
        expect((await service.loadRepositoryPresets(pid)).revision, 0);
        expect(await service.saveRepositoryPresets(request()), 1);
        final saved = (await service.loadRepositoryPresets(pid)).toWire();
        expect((await service.loadRepositoryPlan(pid)).revision, plan.revision);
        expect(
          (await service.loadRepositoryState(pid)).revision,
          state.revision,
        );
        expect(
          (await service.loadRepositoryPlan(pid)).document.toWire(),
          plan.document.toWire(),
        );
        service.dispose();
        service = start();
        await service.reconnect();
        final resumed = await service.loadRepositoryPresets(pid);
        expect(resumed.toWire(), saved);
        expect(resumed.studentGroups.first.studentIds, [
          'aru',
          'future-student',
        ]);
        expect(resumed.stagePresets.first.stages[1].targets['level'], 0);
        expect(
          resumed.stagePresets.first.stages[1].targets['student_star'],
          isNull,
        );
        expect(await service.saveRepositoryPresets(request()), 1);
        await expectLater(
          service.saveRepositoryPresets(request(key: 'stale')),
          throwsA(
            isA<BackendRemoteException>()
                .having((error) => error.code, 'code', 'revision_conflict')
                .having(
                  (error) => error.details?['current_revision'],
                  'collection revision',
                  1,
                ),
          ),
        );
        await expectLater(
          service.saveRepositoryPresets(request(revision: 1)),
          throwsA(
            isA<BackendRemoteException>().having(
              (error) => error.code,
              'code',
              'idempotency_conflict',
            ),
          ),
        );
        await service.renameProfile(pid, 'Renamed', profile.revision, 'rename');
        expect((await service.loadRepositoryPresets(pid)).toWire(), saved);
        expect(
          await service.saveRepositoryPresets(
            request(revision: 1, key: 'clear', empty: true),
          ),
          2,
        );
        service.dispose();
        service = start();
        await service.reconnect();
        expect(await service.saveRepositoryPresets(request()), 1);
        final cleared = await service.loadRepositoryPresets(pid);
        expect(cleared.revision, 2);
        expect(cleared.stagePresets, isEmpty);
        expect(cleared.studentGroups, isEmpty);
        await service.deleteProfile(pid, profile.revision + 1, 'delete');
        expect(File('${storage.path}/presets/$pid.json').existsSync(), isFalse);
        await expectLater(
          service.loadRepositoryPresets(pid),
          throwsA(
            isA<BackendRemoteException>().having(
              (error) => error.code,
              'code',
              'profile_not_found',
            ),
          ),
        );
      } finally {
        service.dispose();
        await storage.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
