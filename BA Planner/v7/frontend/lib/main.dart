import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/app_service.dart';
import 'services/mock_design_review_scenario.dart';
import 'services/process_app_service.dart';
import 'ui/first_run/first_run_rules.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const useRealBackend = bool.fromEnvironment(
    'BA_PLANNER_USE_REAL_BACKEND',
    defaultValue: true,
  );
  const backendDirectory = String.fromEnvironment('BA_PLANNER_BACKEND_DIR');
  const pythonExecutable = String.fromEnvironment('BA_PLANNER_PYTHON');
  // mock 모드에서만 읽는다(mockdemo): 비어 있으면 기본 Mock, `design-review`면 검수 시나리오.
  const mockScenario = String.fromEnvironment('BA_PLANNER_MOCK_SCENARIO');
  // 첫 실행 ①~③(F3b): 비어 있으면 규칙대로, `full`이면 계정이 있어도 ①부터(검수), `off`면 띄우지 않는다.
  const firstRun = String.fromEnvironment('BA_PLANNER_FIRST_RUN');

  final AppService service;
  if (useRealBackend) {
    service = ProcessAppService.fromLaunchOptions(
      pythonExecutable: pythonExecutable,
      backendDirectory: backendDirectory,
    );
    unawaited(_connect(service));
  } else {
    service = createMockAppService(scenario: mockScenario);
  }
  runApp(
    BAPlannerApp(
      service: service,
      showTitle: true,
      firstRun: FirstRunLaunch.fromDefine(firstRun),
      // F3c-3: 첫 실행 ③ · 설정 다시 하기의 튜토리얼과 앱 시작 때 남은 임시 계정 정리.
      tutorial: true,
    ),
  );
}

Future<void> _connect(AppService service) async {
  try {
    await service.reconnect();
  } catch (error, stackTrace) {
    debugPrint('Failed to start the BA Planner backend: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
