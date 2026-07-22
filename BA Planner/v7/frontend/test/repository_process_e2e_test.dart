import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real ProcessAppService restores repository state after Python restart',
    () async {
      final storageRoot = await Directory.systemTemp.createTemp(
        'ba_planner_v7_repository_e2e_',
      );
      final backendDirectory = Directory(
        '${Directory.current.parent.path}${Platform.pathSeparator}backend',
      );
      final config = BackendProcessConfig.resolve(
        backendDirectory: backendDirectory.path,
        environment: {'BA_PLANNER_STORAGE_ROOT': storageRoot.path},
      );
      final startedProcesses = <BackendProcessHandle>[];
      ProcessAppService? firstService;
      ProcessAppService? secondService;

      Future<BackendProcessHandle> startTrackedProcess() async {
        final process = await startBackendProcess(config);
        startedProcesses.add(process);
        return process;
      }

      ProcessAppService newService() => ProcessAppService(
        PlanningProtocolClient(
          startTrackedProcess,
          defaultTimeout: const Duration(seconds: 10),
        ),
      );

      try {
        firstService = newService();
        await firstService.reconnect();
        final created = await firstService.createProfile(
          'Restart E2E',
          'repository-e2e-create',
        );
        expect(created.selected, isTrue);
        expect(created.revision, 0);

        final renamedRevision = await firstService.renameProfile(
          created.id,
          'Restart E2E restored',
          created.revision,
          'repository-e2e-rename',
        );
        final selectedRevision = await firstService.selectProfile(
          created.id,
          renamedRevision,
          'repository-e2e-select',
        );
        final savedRevision = await firstService.saveRepositoryGoals(
          created.id,
          {
            'version': 1,
            'goals': [
              {
                'student_id': 'ayane',
                'target_level': 12,
                'favorite': true,
                'notes': 'cross-language restart',
              },
            ],
          },
          selectedRevision,
          'repository-e2e-save-goals',
        );
        final beforeRestart = await firstService.loadRepositoryState(
          created.id,
        );
        expect(beforeRestart.profileId, created.id);
        expect(beforeRestart.revision, savedRevision);
        expect(beforeRestart.goals, hasLength(1));
        expect(beforeRestart.goals.single.studentId, 'ayane');
        expect(beforeRestart.goals.single.values['target_level'], 12);

        await firstService.dispose();
        firstService = null;
        expect(
          await startedProcesses.single.exitCode.timeout(
            const Duration(seconds: 5),
          ),
          0,
        );

        secondService = newService();
        await secondService.reconnect();
        final restoredProfiles = await secondService.listProfiles();
        expect(restoredProfiles, hasLength(1));
        expect(restoredProfiles.single.id, created.id);
        expect(restoredProfiles.single.displayName, 'Restart E2E restored');
        expect(restoredProfiles.single.selected, isTrue);
        expect(restoredProfiles.single.revision, savedRevision);

        final afterRestart = await secondService.loadRepositoryState(
          created.id,
        );
        expect(afterRestart.profileId, beforeRestart.profileId);
        expect(afterRestart.revision, beforeRestart.revision);
        expect(afterRestart.students, isEmpty);
        expect(afterRestart.inventory.entries, isEmpty);
        expect(afterRestart.goals, hasLength(1));
        expect(afterRestart.goals.single.studentId, 'ayane');
        expect(afterRestart.goals.single.values['target_level'], 12);
        expect(afterRestart.goals.single.values['favorite'], isTrue);
        expect(
          afterRestart.goals.single.values['notes'],
          'cross-language restart',
        );

        await secondService.dispose();
        secondService = null;
        expect(startedProcesses, hasLength(2));
        expect(identical(startedProcesses[0], startedProcesses[1]), isFalse);
        expect(
          await startedProcesses[1].exitCode.timeout(
            const Duration(seconds: 5),
          ),
          0,
        );
      } finally {
        await firstService?.dispose();
        await secondService?.dispose();
        if (storageRoot.existsSync()) {
          await storageRoot.delete(recursive: true);
        }
        expect(storageRoot.existsSync(), isFalse);
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
