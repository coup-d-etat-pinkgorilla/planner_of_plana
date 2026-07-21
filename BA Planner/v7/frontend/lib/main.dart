import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/app_service.dart';
import 'services/mock_app_service.dart';
import 'services/process_app_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const useRealBackend = bool.fromEnvironment('BA_PLANNER_USE_REAL_BACKEND');
  const backendDirectory = String.fromEnvironment('BA_PLANNER_BACKEND_DIR');
  const pythonExecutable = String.fromEnvironment('BA_PLANNER_PYTHON');

  final AppService service;
  if (useRealBackend) {
    service = ProcessAppService.fromLaunchOptions(
      pythonExecutable: pythonExecutable,
      backendDirectory: backendDirectory,
    );
    unawaited(_connect(service));
  } else {
    service = MockAppService();
  }
  runApp(BAPlannerApp(service: service));
}

Future<void> _connect(AppService service) async {
  try {
    await service.reconnect();
  } catch (error, stackTrace) {
    debugPrint('Failed to start the BA Planner backend: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
