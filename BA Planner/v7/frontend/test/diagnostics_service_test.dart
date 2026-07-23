import 'dart:async';
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/diagnostics_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'mock diagnostics report is deterministic and recovery is single flight',
    () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final first = service.reconnect(), second = service.reconnect();
      expect(identical(first, second), isTrue);
      await first;
      final report = service.buildDiagnosticsReport(
        scannerReady: true,
        scannerTargetCount: 1,
      );
      expect(report, contains('protocol=1'));
      expect(report, contains('scanner_ready=true'));
      expect(report, contains('mock process connected'));
    },
  );

  test('process diagnostics are bounded and redact secrets', () async {
    final process = _DiagnosticsProcess();
    final client = PlanningProtocolClient(
      () async => process,
      launchInfo: const BackendLaunchInfo(
        configured: true,
        resolved: true,
        executable: 'python token=launcher-secret',
        arguments: [
          '-m',
          'core.backend_process',
          '--token',
          'argument-secret',
          '--password=inline-secret',
        ],
        workingDirectory: 'backend authorization=path-secret',
      ),
    );
    addTearDown(client.dispose);
    await client.start();
    for (var index = 0; index < 60; index++) {
      process.stderr.add('line $index token=top-secret password:hunter2');
    }
    await Future<void>.delayed(Duration.zero);
    expect(client.diagnostics.value.stderr, hasLength(50));
    final joined = client.diagnostics.value.stderr.join('\n');
    expect(joined, isNot(contains('top-secret')));
    expect(joined, isNot(contains('hunter2')));
    expect(joined, contains('<redacted>'));
    final launch = client.diagnostics.value.launch;
    expect(launch.executable, isNot(contains('launcher-secret')));
    expect(launch.arguments.join(' '), isNot(contains('argument-secret')));
    expect(launch.arguments.join(' '), isNot(contains('inline-secret')));
    expect(launch.workingDirectory, isNot(contains('path-secret')));
  });
}

class _DiagnosticsProcess implements BackendProcessHandle {
  final stdout = StreamController<String>();
  final stderr = StreamController<String>();
  final exit = Completer<int>();
  @override
  Stream<String> get stdoutLines => stdout.stream;
  @override
  Stream<String> get stderrLines => stderr.stream;
  @override
  Future<int> get exitCode => exit.future;
  @override
  void writeLine(String line) {}
  @override
  Future<void> closeInput() async {
    if (!exit.isCompleted) exit.complete(0);
  }

  @override
  bool terminate([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!exit.isCompleted) exit.complete(-1);
    return true;
  }
}
