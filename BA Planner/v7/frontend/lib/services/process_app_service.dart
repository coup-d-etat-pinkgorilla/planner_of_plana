import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_service.dart';
import 'backend_process.dart';
import 'planning_protocol_client.dart';

class ProcessAppService with WidgetsBindingObserver implements AppService {
  ProcessAppService(this._client)
    : _state = ValueNotifier(
        const AppServiceState(
          connection: BackendConnection.disconnected,
          scanPhase: ScanPhase.idle,
          imageLoadState: ImageLoadState.loaded,
          studentCount: 0,
          inventoryItemCount: 0,
          hasData: false,
          scanAvailable: false,
          useLongNames: false,
          hasMissingMetadata: false,
        ),
      ) {
    _client.connection.addListener(_syncConnection);
    WidgetsBinding.instance.addObserver(this);
  }

  factory ProcessAppService.fromConfig(BackendProcessConfig config) {
    return ProcessAppService(
      PlanningProtocolClient(() => startBackendProcess(config)),
    );
  }

  /// Resolves the development launcher only when a connection is attempted.
  ///
  /// Keeping resolution inside the starter lets the Flutter shell render a
  /// disconnected state even when a configured backend directory is missing.
  factory ProcessAppService.fromLaunchOptions({
    String pythonExecutable = '',
    String backendDirectory = '',
  }) {
    return ProcessAppService(
      PlanningProtocolClient(() {
        final config = BackendProcessConfig.resolve(
          pythonExecutable: pythonExecutable,
          backendDirectory: backendDirectory,
        );
        return startBackendProcess(config);
      }),
    );
  }

  final PlanningProtocolClient _client;
  final ValueNotifier<AppServiceState> _state;
  bool _disposed = false;

  @override
  ValueListenable<AppServiceState> get state => _state;

  @override
  Future<Map<String, dynamic>?> getStudent(String studentId) async {
    final payload = await _client.send('planning.student.get', {
      'student_id': studentId,
    });
    final student = payload['student'];
    return student == null ? null : Map<String, dynamic>.from(student as Map);
  }

  @override
  Future<Map<String, dynamic>> validatePlan(Map<String, dynamic> plan) async {
    final payload = await _client.send('planning.plan.validate', {
      'plan': plan,
    });
    return Map<String, dynamic>.from(payload['plan'] as Map);
  }

  @override
  Future<Map<String, dynamic>> calculatePlan({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
  }) async {
    final payload = await _client.send('planning.plan.calculate', {
      'current_students': currentStudents,
      'plan': plan,
    });
    return Map<String, dynamic>.from(payload['totals'] as Map);
  }

  @override
  Future<void> reconnect() => _client.start();

  @override
  Future<void> restartBackend() => _client.restart();

  @override
  Future<void> startScan() async {
    _state.value = _state.value.copyWith(scanPhase: ScanPhase.failed);
    throw UnsupportedError(
      'Scanner protocol is not part of planning protocol v1',
    );
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    await dispose();
    return AppExitResponse.exit;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _client.connection.removeListener(_syncConnection);
    await _client.dispose();
    _state.dispose();
  }

  void _syncConnection() {
    if (!_disposed) {
      _state.value = _state.value.copyWith(
        connection: _client.connection.value,
      );
    }
  }
}
