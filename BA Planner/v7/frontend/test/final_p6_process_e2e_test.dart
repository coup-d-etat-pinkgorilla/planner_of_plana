import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real P6 flow holds then approves scan and restores every saved bucket',
    () async {
      final storageRoot = await Directory.systemTemp.createTemp(
        'ba_planner_v7_final_p6_e2e_',
      );
      final backendDirectory = Directory(
        '${Directory.current.parent.path}${Platform.pathSeparator}backend',
      );
      final config = BackendProcessConfig(
        executable: Platform.isWindows ? 'py' : 'python3',
        arguments: [
          if (Platform.isWindows) '-3.11',
          'tests/scanner_e2e_backend.py',
        ],
        workingDirectory: backendDirectory.absolute.path,
        environment: {'BA_PLANNER_STORAGE_ROOT': storageRoot.path},
      );
      final startedProcesses = <BackendProcessHandle>[];

      Future<BackendProcessHandle> startProcess() async {
        final process = await startBackendProcess(config);
        startedProcesses.add(process);
        return process;
      }

      final service = ProcessAppService(
        PlanningProtocolClient(
          startProcess,
          defaultTimeout: const Duration(seconds: 10),
        ),
      );

      try {
        await service.reconnect();
        final profile = await service.createProfile(
          'Final P6 E2E',
          'final-p6-profile',
        );
        expect(profile.selected, isTrue);

        final target = (await service.listScannerTargets()).single;
        final session = await service.startScannerSession(
          ScannerKind.student,
          target.id,
        );
        await service.scannerEvents
            .firstWhere(
              (event) =>
                  event.sessionId == session.id &&
                  event.eventKind == ScannerEventKind.terminal,
            )
            .timeout(const Duration(seconds: 10));
        final candidate = (await service.scannerSnapshot(
          session,
        )).candidates.single;

        final reviewedPayload = Map<String, dynamic>.from(candidate.payload)
          ..['values'] = {'level': 1};
        final held = await service.reviewScannerCandidate(
          session,
          candidate,
          reviewedPayload,
          approve: false,
          reason: 'Hold keeps repository unchanged',
        );
        final afterHold = await service.loadRepositoryState(profile.id);
        expect(afterHold.revision, 0);
        expect(afterHold.students, isEmpty);

        final approved = await service.reviewScannerCandidate(
          session,
          held,
          reviewedPayload,
          approve: true,
          reason: 'Explicit final P6 approval',
        );
        final commit = await service.commitScannerCandidate(
          session,
          approved,
          profileId: profile.id,
          expectedRepositoryRevision: afterHold.revision,
          idempotencyKey: 'final-p6-candidate-commit',
        );
        expect(commit['revision'], 1);

        final inventoryRevision = await service.saveRepositoryInventory(
          profile.id,
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
          commit['revision'] as int,
          'final-p6-inventory',
        );
        final goals = {
          'version': 1,
          'goals': [
            {
              'student_id': 'airi',
              'target_level': 10,
              'favorite': true,
              'notes': 'final P6 integration',
            },
          ],
        };
        final savedRevision = await service.saveRepositoryGoals(
          profile.id,
          goals,
          inventoryRevision,
          'final-p6-goals',
        );
        final saved = await service.loadRepositoryState(profile.id);
        expect(saved.revision, savedRevision);
        expect(saved.students.single.studentId, 'airi');
        expect(saved.students.single.values['level'], 1);

        final current = saved.students
            .map(confirmedStudentPlanningCurrent)
            .toList(growable: false);
        final gross = await service.calculatePlan(
          currentStudents: current,
          plan: goals,
        );
        expect(gross['level_exp'], greaterThan(0));
        final shortages = await service.calculateShortages(
          currentStudents: current,
          plan: goals,
          inventory: saved.inventory.toWire(),
        );
        expect(
          shortages.rows.any(
            (row) => row.shortage != null && row.shortage! > 0,
          ),
          isTrue,
        );

        final tacticalRevision = await service.saveTacticalMatch(
          profile.id,
          TacticalMatch(
            id: 'final-p6-match',
            kind: 'attack',
            occurredOn: null,
            season: 'P6',
            opponent: 'Fixture rival',
            result: 'win',
            attackDeck: TacticalDeck(
              strikers: const [null, null, null, null],
              specials: const ['airi', null],
            ),
            defenseDeck: TacticalDeck(
              strikers: const ['hoshino', null, null, null],
              specials: const ['ayane', null],
            ),
            notes: 'survives restart',
          ),
          0,
          'final-p6-tactical',
        );
        expect(tacticalRevision, 1);

        await service.restartBackend();
        final restoredProfiles = await service.listProfiles();
        expect(restoredProfiles.single.id, profile.id);
        expect(restoredProfiles.single.selected, isTrue);
        final restored = await service.loadRepositoryState(profile.id);
        expect(restored.revision, savedRevision);
        expect(restored.students.single.studentId, 'airi');
        expect(restored.inventory.entries.single['quantity'], '0');
        expect(restored.goals.single.values['target_level'], 10);
        final restoredTactical = await service.loadTacticalState(profile.id);
        expect(restoredTactical.revision, tacticalRevision);
        expect(restoredTactical.matches.single.id, 'final-p6-match');
      } finally {
        await service.dispose();
        expect(startedProcesses, hasLength(2));
        for (final process in startedProcesses) {
          expect(await process.exitCode.timeout(const Duration(seconds: 5)), 0);
        }
        if (storageRoot.existsSync()) {
          await storageRoot.delete(recursive: true);
        }
        expect(storageRoot.existsSync(), isFalse);
      }
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );

  test(
    'MockAppService mirrors the final P6 review and recovery flow',
    () async {
      final service = MockAppService(
        scannerScenario: MockScannerScenario.reviewRequired,
      );
      addTearDown(service.dispose);
      final originalProfile = (await service.listProfiles()).single;
      final profile = await service.createProfile(
        'Mock final P6',
        'mock-final-p6-profile',
      );
      final session = await service.startScannerSession(
        ScannerKind.student,
        (await service.listScannerTargets()).single.id,
      );
      await service.scannerEvents.firstWhere(
        (event) =>
            event.sessionId == session.id &&
            event.eventKind == ScannerEventKind.terminal,
      );
      final candidate = (await service.scannerSnapshot(
        session,
      )).candidates.single;
      final payload = Map<String, dynamic>.from(candidate.payload)
        ..['values'] = {'level': 1};
      final held = await service.reviewScannerCandidate(
        session,
        candidate,
        payload,
        approve: false,
        reason: 'Mock Hold',
      );
      expect((await service.loadRepositoryState(profile.id)).students, isEmpty);
      expect(
        () => service.commitScannerCandidate(
          session,
          held,
          profileId: profile.id,
          expectedRepositoryRevision: 0,
          idempotencyKey: 'mock-held-commit',
        ),
        throwsA(isA<StateError>()),
      );
      final approved = await service.reviewScannerCandidate(
        session,
        held,
        payload,
        approve: true,
        reason: 'Mock Approve',
      );
      final commit = await service.commitScannerCandidate(
        session,
        approved,
        profileId: profile.id,
        expectedRepositoryRevision: 0,
        idempotencyKey: 'mock-approved-commit',
      );
      final inventoryRevision = await service.saveRepositoryInventory(
        profile.id,
        RepositoryInventoryState.fromEntries([
          {
            'key': 'Item_Icon_ExpItem_0',
            'item_id': 'Item_Icon_ExpItem_0',
            'quantity': '0',
          },
        ]),
        commit['revision'] as int,
        'mock-final-inventory',
      );
      final goals = {
        'version': 1,
        'goals': [
          {'student_id': 'aru', 'target_level': 10},
        ],
      };
      final savedRevision = await service.saveRepositoryGoals(
        profile.id,
        goals,
        inventoryRevision,
        'mock-final-goals',
      );
      final saved = await service.loadRepositoryState(profile.id);
      final current = saved.students
          .map(confirmedStudentPlanningCurrent)
          .toList(growable: false);
      expect(
        await service.calculatePlan(currentStudents: current, plan: goals),
        isNotEmpty,
      );
      expect(
        (await service.calculateShortages(
          currentStudents: current,
          plan: goals,
          inventory: saved.inventory.toWire(),
        )).rows,
        isNotEmpty,
      );
      await service.saveTacticalMatch(
        profile.id,
        TacticalMatch(
          id: 'mock-final-match',
          kind: 'attack',
          occurredOn: null,
          season: 'P6',
          opponent: 'Mock rival',
          result: 'win',
          attackDeck: TacticalDeck(
            strikers: const ['aru', null, null, null],
            specials: const [null, null],
          ),
          defenseDeck: TacticalDeck(
            strikers: const ['hoshino', null, null, null],
            specials: const ['ayane', null],
          ),
          notes: 'mock recovery',
        ),
        0,
        'mock-final-tactical',
      );

      final firstRestart = service.restartBackend();
      expect(identical(firstRestart, service.restartBackend()), isTrue);
      await firstRestart;
      expect(
        (await service.loadRepositoryState(profile.id)).revision,
        savedRevision,
      );
      expect(
        (await service.loadTacticalState(profile.id)).matches.single.id,
        'mock-final-match',
      );
      expect(
        (await service.loadRepositoryState(originalProfile.id)).students,
        isEmpty,
      );
    },
  );
}
