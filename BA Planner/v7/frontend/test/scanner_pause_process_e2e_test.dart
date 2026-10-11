// fb10a-dart: 실제 Python 백엔드(JSONL)로 FB-10a pause → paused → snapshot → resume → resumed → cancel을 한 번 돈다.
// 게임 창 없이 되는 범위만 본다. 대상은 고정 목록 1개, matcher는 취소될 때까지 20ms마다 progress를 내는 fixture다
// (XB backend/tests/test_scanner_pause_fb10a.py의 실제 JSONL 테스트와 같은 구성).
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _backendScript = r'''
import os
import sys
sys.path.insert(0, os.getcwd())
sys.stdin.reconfigure(encoding="utf-8")
sys.stdout.reconfigure(encoding="utf-8")
from pathlib import Path
from core.application_protocol_v1 import ApplicationProtocolV1
from core.repository_store import JsonRepository
from core.scanner_session import ScannerSessionService
from core.stdio_server import serve

root = Path(sys.argv[1])


def matcher(target, cancel, progress):
    while not cancel.is_set():
        progress(0, None, "fixture")
        cancel.wait(0.02)
    return []


service = ScannerSessionService(
    target_provider=lambda: [{"target_id": "w1", "title": "fixture", "status": "ready"}],
    student_matcher=matcher,
    inventory_matcher=matcher,
    repository=JsonRepository(root),
    asset_status=lambda: {"ready": True, "manifest_version": 1, "missing": [], "corrupt": []},
)
serve(protocol=ApplicationProtocolV1(storage_root=root, scanner_service=service))
''';

Future<ScannerEvent> _next(
  List<ScannerEvent> events,
  ScannerSession session,
  ScannerEventKind kind,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    for (final event in events) {
      if (event.sessionId == session.id && event.eventKind == kind) {
        return event;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('no ${kind.name} event from the real backend');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real backend pause, paused, snapshot, resume, resumed and cancel', () async {
    final storageRoot = await Directory.systemTemp.createTemp(
      'ba_planner_v7_fb10a_pause_',
    );
    final script = File(
      '${storageRoot.path}${Platform.pathSeparator}fb10a_pause_backend.py',
    )..writeAsStringSync(_backendScript);
    final dataRoot = Directory(
      '${storageRoot.path}${Platform.pathSeparator}data',
    )..createSync();
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
        '-u',
        script.absolute.path,
        dataRoot.absolute.path,
      ],
      workingDirectory: backendDirectory.absolute.path,
      environment: {
        'BA_PLANNER_STORAGE_ROOT': dataRoot.path,
        'BA_PLANNER_ASSET_DIR': backendDirectory.absolute.path,
      },
    );
    final service = ProcessAppService(
      PlanningProtocolClient(
        () => startBackendProcess(config),
        defaultTimeout: const Duration(seconds: 10),
      ),
    );
    final events = <ScannerEvent>[];
    final errors = <Object>[];
    final subscription = service.scannerEvents.listen(
      events.add,
      onError: errors.add,
    );
    try {
      await service.reconnect();
      final targets = await service.listScannerTargets();
      expect(targets.single.id, 'w1');
      final session = await service.startScannerSession(
        ScannerKind.student,
        'w1',
      );

      // 수락은 멈춤이 아니다: 응답은 pause_requested, 실제 멈춤은 sequenced paused 이벤트다.
      final pause = await service.pauseScannerSession(session);
      expect(pause.accepted, isTrue);
      expect(pause.controlState, ScannerControlState.pauseRequested);
      expect(pause.reason, ScannerPauseReason.user);
      final paused = await _next(events, session, ScannerEventKind.paused);
      expect(paused.pauseReason, ScannerPauseReason.user);

      final snapshot = await service.scannerSnapshot(session);
      expect(snapshot.controlState, ScannerControlState.paused);
      expect(snapshot.reason, ScannerPauseReason.user);
      expect(snapshot.terminal, isNull);
      expect(
        snapshot.events.any(
          (event) => event.eventKind == ScannerEventKind.paused,
        ),
        isTrue,
      );

      final resume = await service.resumeScannerSession(session);
      expect(resume.accepted, isTrue);
      expect(resume.controlState, ScannerControlState.running);
      expect(resume.reason, isNull);
      final resumed = await _next(events, session, ScannerEventKind.resumed);
      expect(resumed.sequence, greaterThan(paused.sequence));
      expect(resumed.pauseReason, isNull);

      final cancel = await service.cancelScannerSession(session);
      expect(cancel['accepted'], isTrue);
      final terminal = await _next(events, session, ScannerEventKind.terminal);
      expect(terminal.payload['outcome'], 'cancelled');
      final sessionEvents = events
          .where((event) => event.sessionId == session.id)
          .toList();
      expect(
        sessionEvents.map((event) => event.sequence),
        List.generate(sessionEvents.length, (index) => index + 1),
      );
      expect(
        sessionEvents.where((event) => event.eventKind == ScannerEventKind.paused),
        hasLength(1),
      );
      expect(
        sessionEvents.where(
          (event) => event.eventKind == ScannerEventKind.resumed,
        ),
        hasLength(1),
      );
      expect(errors, isEmpty);
    } finally {
      await subscription.cancel();
      await service.dispose();
      try {
        await storageRoot.delete(recursive: true);
      } on FileSystemException {
        // Windows가 파일을 늦게 놓으면 임시 폴더는 남겨 둔다.
      }
    }
  }, timeout: const Timeout(Duration(minutes: 1)));
}
