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
      final executable = Platform.isWindows ? 'py' : 'python3';
      final config = BackendProcessConfig(
        executable: executable,
        arguments: [
          if (Platform.isWindows) '-3.11',
          'tests/scanner_e2e_backend.py',
        ],
        workingDirectory: backendDirectory.absolute.path,
        environment: {'BA_PLANNER_STORAGE_ROOT': storageRoot.path},
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

      Future<List<ScannerEvent>> runSession() async {
        final targets = await service.listScannerTargets();
        expect(targets, hasLength(1));
        expect(targets.single.status, ScannerTargetStatus.ready);
        final startIndex = events.length;
        final session = await service.startScannerSession(
          ScannerKind.student,
          targets.single.id,
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
        return sessionEvents;
      }

      try {
        await service.reconnect();
        expect((await service.scannerReadiness())['ready'], isTrue);
        await runSession();

        await service.restartBackend();
        await runSession();
        expect(errors, isEmpty);
      } finally {
        await subscription.cancel();
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
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
