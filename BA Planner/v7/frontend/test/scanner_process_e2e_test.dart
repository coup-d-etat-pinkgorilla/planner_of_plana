import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real ProcessAppService preserves scanner events across restart and dispose',
    () async {
      final storageRoot = await Directory.systemTemp.createTemp(
        'ba_planner_v7_scanner_e2e_',
      );
      final backendDirectory = Directory(
        '${Directory.current.parent.path}${Platform.pathSeparator}backend',
      );
      final virtualEnvironmentPython = File(
        '${backendDirectory.path}${Platform.pathSeparator}.venv'
        '${Platform.pathSeparator}${Platform.isWindows ? 'Scripts' : 'bin'}'
        '${Platform.pathSeparator}${Platform.isWindows ? 'python.exe' : 'python'}',
      );
      final executable = virtualEnvironmentPython.existsSync()
          ? virtualEnvironmentPython.absolute.path
          : Platform.isWindows
          ? 'py'
          : 'python3';
      final usesPyLauncher =
          executable.split(RegExp(r'[/\\]')).last.toLowerCase() == 'py';
      final config = BackendProcessConfig(
        executable: executable,
        arguments: [
          if (Platform.isWindows && usesPyLauncher) '-3.11',
          '-m',
          'tests.scanner_e2e_backend',
        ],
        workingDirectory: backendDirectory.absolute.path,
        environment: {
          'BA_PLANNER_STORAGE_ROOT': storageRoot.path,
          'BA_PLANNER_ASSET_DIR': backendDirectory.absolute.path,
        },
      );
      final startedProcesses = <BackendProcessHandle>[];
      Future<BackendProcessHandle> startTrackedProcess() async {
        final process = await startBackendProcess(config);
        startedProcesses.add(process);
        return process;
      }

      final service = ProcessAppService(
        PlanningProtocolClient(
          startTrackedProcess,
          defaultTimeout: const Duration(seconds: 10),
        ),
      );
      final events = <ScannerEvent>[];
      final errors = <Object>[];
      final subscription = service.scannerEvents.listen(
        events.add,
        onError: errors.add,
      );

      Future<List<ScannerEvent>> runSession(int cycle) async {
        final profile = await service.createProfile(
          'Scanner E2E $cycle',
          'scanner-e2e-profile-$cycle',
          avatarStudentId: 'airi',
        );
        final targets = await service.listScannerTargets();
        expect(targets, hasLength(1));
        expect(targets.single.status, ScannerTargetStatus.ready);
        final startIndex = events.length;
        final session = await service.startScannerSession(
          ScannerKind.student,
          targets.single.id,
          profileId: profile.id,
        );
        await service.scannerEvents
            .firstWhere(
              (event) =>
                  event.sessionId == session.id &&
                  event.eventKind == ScannerEventKind.terminal,
            )
            .timeout(const Duration(seconds: 10));
        final sessionEvents = events
            .skip(startIndex)
            .where((event) => event.sessionId == session.id)
            .toList();
        expect(
          sessionEvents.map((event) => event.sequence),
          orderedEquals(
            List.generate(sessionEvents.length, (index) => index + 1),
          ),
        );
        expect(
          sessionEvents.map((event) => event.eventKind),
          containsAllInOrder([
            ScannerEventKind.phase,
            ScannerEventKind.progress,
            ScannerEventKind.candidate,
            ScannerEventKind.terminal,
          ]),
        );
        expect(sessionEvents.last.payload['outcome'], 'completed');
        final snapshot = await service.scannerSnapshot(session);
        expect(snapshot.sessionId, session.id);
        expect(snapshot.generation, session.generation);
        expect(snapshot.terminal, 'completed');
        expect(snapshot.lastSequence, sessionEvents.last.sequence);
        expect(snapshot.candidates.single.id, 'scanner-e2e-candidate');
        final original = snapshot.candidates.single;
        expect(original.reviewRequired, isTrue);
        expect(
          original.evidence
              .singleWhere((item) => item.field == 'student_stat_validation')
              .status,
          'suspicious',
        );

        final editedPayload = Map<String, dynamic>.from(original.payload);
        editedPayload['values'] = {
          ...Map<String, dynamic>.from(original.payload['values'] as Map),
          'level': 91,
        };
        final edited = await service.reviewScannerCandidate(
          session,
          original,
          editedPayload,
          approve: false,
          reason: 'edited_and_revalidated_in_scan_page',
        );
        expect(edited.revision, original.revision + 1);
        expect(edited.reviewRequired, isFalse);
        expect(edited.payload['values']['level'], 91);

        final revalidated = await service.revalidateScannerCandidate(
          session,
          edited,
        );
        expect(revalidated.revision, edited.revision + 1);
        expect(
          revalidated.evidence
              .singleWhere((item) => item.field == 'student_stat_validation')
              .details?['profile_id'],
          profile.id,
        );
        final approved = await service.reviewScannerCandidate(
          session,
          revalidated,
          revalidated.payload,
          approve: true,
          reason: 'applied_in_scan_page',
        );
        expect(approved.approved, isTrue);

        await expectLater(
          service.commitScannerCandidate(
            session,
            revalidated,
            profileId: profile.id,
            expectedRepositoryRevision: profile.revision,
            idempotencyKey: 'scanner-e2e-stale-candidate-$cycle',
          ),
          throwsA(
            predicate(
              (error) => '$error'.contains('candidate_revision_conflict'),
            ),
          ),
        );

        final interveningRevision = await service.saveRepositoryGoals(
          profile.id,
          const {'version': 1, 'goals': <dynamic>[]},
          profile.revision,
          'scanner-e2e-conflict-write-$cycle',
        );
        await expectLater(
          service.commitScannerCandidate(
            session,
            approved,
            profileId: profile.id,
            expectedRepositoryRevision: profile.revision,
            idempotencyKey: 'scanner-e2e-repository-conflict-$cycle',
          ),
          throwsA(predicate((error) => '$error'.contains('revision_conflict'))),
        );
        final committed = await service.commitScannerCandidate(
          session,
          approved,
          profileId: profile.id,
          expectedRepositoryRevision: interveningRevision,
          idempotencyKey: 'scanner-e2e-commit-$cycle',
        );
        expect(committed['revision'], interveningRevision + 1);
        final repository = await service.loadRepositoryState(profile.id);
        final saved = repository.students.singleWhere(
          (student) => student.studentId == 'airi',
        );
        expect(saved.values['level'], 91);
        return sessionEvents;
      }

      var completed = false;
      try {
        await service.reconnect();
        expect((await service.scannerReadiness())['ready'], isTrue);
        await runSession(1);

        await service.restartBackend();
        await runSession(2);
        expect(errors, isEmpty);
        completed = true;
      } finally {
        await subscription.cancel();
        await service.dispose();
        final exitCodes = <int>[];
        for (final process in startedProcesses) {
          exitCodes.add(
            await process.exitCode.timeout(const Duration(seconds: 5)),
          );
        }
        if (storageRoot.existsSync()) {
          await storageRoot.delete(recursive: true);
        }
        expect(storageRoot.existsSync(), isFalse);
        if (completed) {
          expect(startedProcesses, hasLength(2));
          expect(exitCodes, everyElement(0));
        }
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
