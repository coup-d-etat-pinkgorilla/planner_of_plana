// fb4-dart: 실제 Python 백엔드(ApplicationProtocolV1 + ScannerSessionService + stdio_server)가
// FB-4 target metadata를 직렬화하고 Dart ProcessAppService가 DTO로 받는지 확인한다.
// 실제 게임 창은 필요 없다: target provider는 공유 fixture의 valid 행을 그대로 돌려준다.
// Windows 창 열거·DPI·프로세스 이름 판별 자체는 XB Python 테스트(test_scanner_target_metadata_fb4)의
// 범위이고, 실게임 관측은 아직 없다(NOT_VERIFIED).
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 테스트 전용 백엔드 진입점. backend 폴더를 sys.path 앞에 두고 실제 core 모듈을 쓴다.
const _backendScript = r'''
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, os.environ["FB4_E2E_BACKEND_DIR"])

from core.application_protocol_v1 import ApplicationProtocolV1
from core.repository_store import JsonRepository
from core.scanner_session import ScannerSessionService
from core.stdio_server import serve


def main() -> None:
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8")
    fixture = json.loads(Path(os.environ["FB4_E2E_FIXTURE"]).read_text(encoding="utf-8"))
    rows = [
        target
        for case in fixture["cases"]
        if case["valid"]
        for target in case["message"]["payload"]["targets"]
    ]
    storage_root = Path(os.environ["BA_PLANNER_STORAGE_ROOT"])
    service = ScannerSessionService(
        target_provider=lambda: rows,
        student_matcher=lambda *_args: [],
        inventory_matcher=lambda *_args: [],
        repository=JsonRepository(storage_root),
        asset_status=lambda: {
            "ready": True,
            "manifest_version": 1,
            "asset_count": 0,
            "missing": [],
            "corrupt": [],
        },
    )
    serve(protocol=ApplicationProtocolV1(
        storage_root=storage_root,
        scanner_service=service,
    ))


if __name__ == "__main__":
    main()
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'real Python scanner.target.list carries FB-4 metadata into ScannerTarget',
    () async {
      final fixtureFile = File(
        '${Directory.current.parent.path}${Platform.pathSeparator}contracts'
        '${Platform.pathSeparator}fixtures'
        '${Platform.pathSeparator}scanner_target_metadata_fb4_v1.json',
      );
      final fixture =
          jsonDecode(fixtureFile.readAsStringSync()) as Map<String, dynamic>;
      final expectedRows = [
        for (final testCase in (fixture['cases'] as List).cast<Map>())
          if (testCase['valid'] == true)
            for (final row
                in ((testCase['message'] as Map)['payload'] as Map)['targets']
                    as List)
              Map<String, dynamic>.from(row as Map),
      ];
      expect(expectedRows, hasLength(9));

      final storageRoot = await Directory.systemTemp.createTemp(
        'ba_planner_v7_fb4_target_e2e_',
      );
      // 진입점 스크립트는 저장 폴더와 분리한 별도 임시 폴더에 둔다.
      final scriptRoot = await Directory.systemTemp.createTemp(
        'ba_planner_v7_fb4_target_script_',
      );
      final script = File(
        '${scriptRoot.path}${Platform.pathSeparator}fb4_target_backend.py',
      )..writeAsStringSync(_backendScript);
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
          script.absolute.path,
        ],
        workingDirectory: backendDirectory.absolute.path,
        environment: {
          'BA_PLANNER_STORAGE_ROOT': storageRoot.path,
          'BA_PLANNER_ASSET_DIR': backendDirectory.absolute.path,
          'FB4_E2E_BACKEND_DIR': backendDirectory.absolute.path,
          'FB4_E2E_FIXTURE': fixtureFile.absolute.path,
        },
      );
      final startedProcesses = <BackendProcessHandle>[];
      final service = ProcessAppService(
        PlanningProtocolClient(() async {
          final process = await startBackendProcess(config);
          startedProcesses.add(process);
          return process;
        }, defaultTimeout: const Duration(seconds: 10)),
      );

      var completed = false;
      try {
        await service.reconnect();
        final targets = await service.listScannerTargets();
        expect(targets, hasLength(expectedRows.length));
        for (var index = 0; index < expectedRows.length; index += 1) {
          final wire = expectedRows[index];
          final target = targets[index];
          expect(target.id, wire['target_id']);
          expect(target.title, wire['title']);
          expect(target.status.name, wire['status']);
          expect(target.foreground, wire['foreground'] == true);
          expect(target.clientWidth, wire['client_width'], reason: target.id);
          expect(target.clientHeight, wire['client_height'], reason: target.id);
          expect(target.game?.wireName, wire['game'], reason: target.id);
        }
        final byId = {for (final target in targets) target.id: target};
        expect(byId['hwnd:102']!.clientWidth, 2560);
        expect(byId['hwnd:102']!.clientHeight, 1440);
        expect(byId['hwnd:102']!.game, ScannerTargetGame.blueArchive);
        // 구 provider 행(키 생략)과 null 행은 둘 다 "모름"이다.
        expect(byId['fixture']!.hasClientSize, isFalse);
        expect(byId['fixture']!.game, isNull);
        expect(byId['hwnd:106']!.hasClientSize, isFalse);
        expect(byId['hwnd:106']!.game, isNull);
        completed = true;
      } finally {
        await service.dispose();
        final exitCodes = <int>[];
        for (final process in startedProcesses) {
          exitCodes.add(
            await process.exitCode.timeout(const Duration(seconds: 5)),
          );
        }
        for (final directory in [storageRoot, scriptRoot]) {
          if (directory.existsSync()) {
            await directory.delete(recursive: true);
          }
        }
        if (completed) {
          expect(startedProcesses, hasLength(1));
          expect(exitCodes, everyElement(0));
        }
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
