import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
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
        final inventoryCatalog = await firstService.listInventoryItems();
        expect(inventoryCatalog.length, greaterThan(100));
        expect(
          inventoryCatalog.any(
            (item) => item.resourceKey == 'Item_Icon_ExpItem_0',
          ),
          isTrue,
        );
        final shortages = await firstService.calculateShortages(
          currentStudents: const [
            {'student_id': 'ayane', 'level': 1},
          ],
          plan: const {
            'version': 1,
            'goals': [
              {'student_id': 'ayane', 'target_level': 10},
            ],
          },
          inventory: const {
            'version': 1,
            'entries': [
              {
                'key': 'Item_Icon_ExpItem_0',
                'item_id': 'Item_Icon_ExpItem_0',
                'quantity': '0',
              },
            ],
          },
        );
        final explicitZero = shortages.rows.singleWhere(
          (row) => row.resourceKey == 'Item_Icon_ExpItem_0',
        );
        expect(explicitZero.owned, 0);
        expect(explicitZero.shortage, 1);
        expect(explicitZero.affectedStudentIds, ['ayane']);
        final unknown = shortages.rows.singleWhere(
          (row) => row.resourceKey == 'Item_Icon_ExpItem_1',
        );
        expect(unknown.owned, isNull);
        expect(unknown.shortage, isNull);

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
        final studentRevision = await firstService.saveRepositoryStudents(
          created.id,
          [
            ConfirmedStudentState.fromValues('ayane', {'level': 1}),
          ],
          selectedRevision,
          'repository-e2e-save-student',
        );
        final inventoryRevision = await firstService.saveRepositoryInventory(
          created.id,
          RepositoryInventoryState.fromEntries([
            {
              'key': 'Item_Icon_ExpItem_0',
              'item_id': 'Item_Icon_ExpItem_0',
              'quantity': '0',
              'name': 'Basic activity report',
              'index': 0,
              'profile_id': 'activity_reports',
            },
          ]),
          studentRevision,
          'repository-e2e-save-inventory',
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
          inventoryRevision,
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
        expect(afterRestart.students, hasLength(1));
        expect(afterRestart.students.single.studentId, 'ayane');
        expect(afterRestart.students.single.values['level'], 1);
        expect(afterRestart.inventory.entries, hasLength(1));
        expect(afterRestart.inventory.entries.single['quantity'], '0');
        expect(afterRestart.goals, hasLength(1));
        expect(afterRestart.goals.single.studentId, 'ayane');
        expect(afterRestart.goals.single.values['target_level'], 12);
        expect(afterRestart.goals.single.values['favorite'], isTrue);
        expect(
          afterRestart.goals.single.values['notes'],
          'cross-language restart',
        );
        final homeShortages = await secondService.calculateShortages(
          currentStudents: afterRestart.students
              .map(confirmedStudentPlanningCurrent)
              .toList(growable: false),
          plan: {
            'version': 1,
            'goals': afterRestart.goals
                .map((goal) => Map<String, dynamic>.from(goal.values))
                .toList(growable: false),
          },
          inventory: afterRestart.inventory.toWire(),
        );
        expect(homeShortages.rows, isNotEmpty);
        expect(
          homeShortages.rows.any(
            (row) =>
                row.requiredAmount > 0 &&
                row.owned == 0 &&
                row.shortage != null &&
                row.shortage! > 0,
          ),
          isTrue,
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
