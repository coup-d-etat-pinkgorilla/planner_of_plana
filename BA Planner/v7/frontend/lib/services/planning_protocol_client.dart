import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_service.dart';
import 'backend_process.dart';
import 'repository_service.dart';

class BackendProtocolException implements Exception {
  BackendProtocolException(this.message);

  final String message;

  @override
  String toString() => 'BackendProtocolException: $message';
}

class BackendRemoteException implements Exception {
  BackendRemoteException({
    required this.code,
    required this.message,
    this.details,
    this.retryable = false,
  });

  final String code;
  final String message;
  final Map<String, dynamic>? details;
  final bool retryable;

  @override
  String toString() => 'BackendRemoteException($code): $message';
}

class BackendDisconnectedException implements Exception {
  BackendDisconnectedException(this.message);

  final String message;

  @override
  String toString() => 'BackendDisconnectedException: $message';
}

class PlanningProtocolClient {
  PlanningProtocolClient(
    this._startProcess, {
    this.defaultTimeout = const Duration(seconds: 10),
    this.stopGracePeriod = const Duration(milliseconds: 750),
  });

  final BackendProcessStarter _startProcess;
  final Duration defaultTimeout;
  final Duration stopGracePeriod;
  final ValueNotifier<BackendConnection> connection = ValueNotifier(
    BackendConnection.disconnected,
  );
  final StreamController<BackendProtocolException> _protocolErrors =
      StreamController<BackendProtocolException>.broadcast();
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, _PendingRequest> _pending = {};

  BackendProcessHandle? _process;
  Future<void>? _starting;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  var _nextRequestId = 0;
  var _generation = 0;
  bool _stopping = false;
  bool _disposed = false;

  static const _methodErrorCodes = <String, Set<String>>{
    'planning.student.get': {'invalid_payload', 'metadata_lookup_failed'},
    'planning.student.catalog': {'invalid_payload', 'metadata_lookup_failed'},
    'planning.plan.validate': {'invalid_payload'},
    'planning.plan.calculate': {'invalid_payload', 'calculation_failed'},
    'planning.inventory.catalog': {'invalid_payload', 'inventory_catalog_failed'},
    'planning.plan.shortages': {'invalid_payload', 'shortage_calculation_failed'},
    'repository': {
      'invalid_payload', 'profile_not_found', 'profile_name_conflict',
      'revision_conflict', 'idempotency_conflict', 'repository_busy',
      'corrupt_data', 'migration_required', 'migration_not_supported',
      'persistence_failed', 'unknown_method',
    },
    'scanner': {
      'invalid_payload', 'target_not_found', 'target_provider_failed',
      'scanner_busy', 'scanner_unavailable', 'session_not_found',
      'stale_generation', 'candidate_not_found',
      'candidate_revision_conflict', 'session_not_committable',
      'review_required', 'invalid_candidate', 'capture_failed',
      'capture_timeout', 'target_closed', 'target_minimized',
      'matcher_failed', 'template_missing', 'region_missing',
      'asset_manifest_invalid', 'asset_version_mismatch',
      'unknown_method',
    },
  };

  Stream<BackendProtocolException> get protocolErrors => _protocolErrors.stream;
  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<void> start() async {
    if (_disposed) {
      throw StateError('PlanningProtocolClient is disposed');
    }
    if (_process != null) {
      return;
    }
    final activeStart = _starting;
    if (activeStart != null) {
      return activeStart;
    }
    final operation = _startNewProcess();
    _starting = operation;
    try {
      await operation;
    } finally {
      if (identical(_starting, operation)) {
        _starting = null;
      }
    }
  }

  Future<void> _startNewProcess() async {
    connection.value = BackendConnection.connecting;
    final generation = ++_generation;
    try {
      final process = await _startProcess();
      if (_disposed || _stopping || generation != _generation) {
        await process.closeInput();
        process.terminate();
        return;
      }
      _process = process;
      _stdoutSubscription = process.stdoutLines.listen(
        (line) => _handleLine(line, generation),
        onError: (Object error, StackTrace stackTrace) {
          _disconnect('Backend stdout failed: $error', generation);
        },
        cancelOnError: true,
      );
      _stderrSubscription = process.stderrLines.listen((line) {
        debugPrint('[backend] $line');
      });
      unawaited(
        process.exitCode.then(
          (code) => _handleExit(code, generation),
          onError: (Object error, StackTrace stackTrace) {
            _disconnect('Backend exit status failed: $error', generation);
          },
        ),
      );
      connection.value = BackendConnection.connected;
    } catch (_) {
      _process = null;
      await _cancelSubscriptions();
      connection.value = BackendConnection.disconnected;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> send(
    String method,
    Map<String, dynamic> payload, {
    Duration? timeout,
  }) async {
    if (_disposed) {
      throw StateError('PlanningProtocolClient is disposed');
    }
    final process = _process;
    if (process == null || connection.value != BackendConnection.connected) {
      throw BackendDisconnectedException('Backend process is not connected');
    }
    final id = '$_generation-${++_nextRequestId}';
    final completer = Completer<Map<String, dynamic>>();
    final timer = Timer(timeout ?? defaultTimeout, () {
      final pending = _pending.remove(id);
      pending?.completer.completeError(
        TimeoutException(
          'Backend request timed out: $method',
          timeout ?? defaultTimeout,
        ),
      );
    });
    _pending[id] = _PendingRequest(method, completer, timer);
    try {
      process.writeLine(
        jsonEncode({
          'protocol': 1,
          'id': id,
          'type': 'request',
          'method': method,
          'payload': payload,
        }),
      );
    } catch (error) {
      process.terminate();
      _disconnect('Backend stdin failed: $error', _generation);
    }
    return completer.future;
  }

  Future<void> restart() async {
    await stop();
    await start();
  }

  Future<void> stop() async {
    _stopping = true;
    _generation += 1;
    final activeStart = _starting;
    if (activeStart != null) {
      try {
        await activeStart;
      } catch (_) {
        // start() already restored the disconnected state.
      }
    }
    final process = _process;
    if (process == null) {
      _failPending(BackendDisconnectedException('Backend process stopped'));
      await _cancelSubscriptions();
      connection.value = BackendConnection.disconnected;
      _stopping = false;
      return;
    }
    _process = null;
    _failPending(BackendDisconnectedException('Backend process stopped'));
    try {
      await process.closeInput();
      final exited = await Future.any<bool>([
        process.exitCode.then((_) => true, onError: (_) => true),
        Future<bool>.delayed(stopGracePeriod, () => false),
      ]);
      if (!exited) {
        process.terminate();
        final terminated = await Future.any<bool>([
          process.exitCode.then((_) => true, onError: (_) => true),
          Future<bool>.delayed(stopGracePeriod, () => false),
        ]);
        if (!terminated) {
          process.terminate(ProcessSignal.sigkill);
        }
      }
    } finally {
      await _cancelSubscriptions();
      _stopping = false;
      connection.value = BackendConnection.disconnected;
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await stop();
    connection.dispose();
    await _protocolErrors.close();
    await _events.close();
  }

  void _handleLine(String line, int generation) {
    if (generation != _generation || _stopping) {
      return;
    }
    Object decoded;
    try {
      decoded = jsonDecode(line);
    } catch (_) {
      _fatalProtocolError('Malformed JSON response from backend', generation);
      return;
    }
    if (decoded is! Map<String, dynamic>) {
      _fatalProtocolError('Invalid protocol response envelope', generation);
      return;
    }
    if (decoded['type'] == 'event') {
      if (!_validEventEnvelope(decoded)) {
        _fatalProtocolError('Invalid protocol event envelope', generation);
        return;
      }
      if (!_events.isClosed) _events.add(Map<String, dynamic>.from(decoded));
      return;
    }
    if (!_validEnvelope(decoded)) {
      _fatalProtocolError('Invalid protocol response envelope', generation);
      return;
    }
    final id = decoded['id'] as String;
    final pending = _pending[id];
    if (pending == null) {
      _emitProtocolError('Unknown or duplicate response id: $id');
      return;
    }
    if (decoded['method'] != pending.method) {
      _fatalProtocolError(
        'Response method mismatch for $id: ${decoded['method']}',
        generation,
      );
      return;
    }
    _pending.remove(id);
    pending.timer.cancel();
    final payload = Map<String, dynamic>.from(decoded['payload'] as Map);
    final error = payload['error'];
    if (error != null) {
      final wireError = _validRemoteError(error, pending.method);
      if (wireError == null || payload.length != 1) {
        pending.completer.completeError(
          BackendProtocolException('Invalid error response for $id'),
        );
        _fatalProtocolError('Invalid error response for $id', generation);
        return;
      }
      pending.completer.completeError(
        BackendRemoteException(
          code: wireError['code'] as String,
          message: wireError['message'] as String,
          details: wireError['details'] is Map
              ? Map<String, dynamic>.from(wireError['details'] as Map)
              : null,
          retryable: wireError['retryable'] == true,
        ),
      );
      return;
    }
    if (!_validSuccessPayload(pending.method, payload)) {
      pending.completer.completeError(
        BackendProtocolException('Invalid success response for $id'),
      );
      _fatalProtocolError('Invalid success response for $id', generation);
      return;
    }
    pending.completer.complete(payload);
  }

  bool _validSuccessPayload(String method, Map<String, dynamic> payload) {
    return switch (method) {
      'planning.student.get' =>
        payload.keys.toSet().length == 1 &&
            payload.containsKey('student') &&
            (payload['student'] == null || payload['student'] is Map),
      'planning.student.catalog' => _validStudentCatalog(payload),
      'planning.plan.validate' =>
        payload.keys.toSet().length == 2 &&
            payload['valid'] == true &&
            payload['plan'] is Map,
      'planning.plan.calculate' =>
        payload.keys.toSet().length == 1 && payload['totals'] is Map,
      'planning.inventory.catalog' => _validInventoryCatalog(payload),
      'planning.plan.shortages' => _validInventoryShortages(payload),
      _ when method.startsWith('repository.') =>
        isValidRepositorySuccessPayload(method, payload),
      _ when method.startsWith('scanner.') =>
        _validScannerSuccessPayload(method, payload),
      _ => false,
    };
  }

  bool _validStudentCatalog(Map<String, dynamic> payload) {
    if (payload.keys.toSet().length != 2 ||
        payload['sort'] != 'display_name_then_id' ||
        payload['students'] is! List) {
      return false;
    }
    try {
      for (final item in payload['students'] as List) {
        StudentCatalogEntry.fromWire(Map<String, dynamic>.from(item as Map));
      }
      return true;
    } on Object {
      return false;
    }
  }

  bool _validInventoryCatalog(Map<String,dynamic> payload) {
    if (payload.keys.toSet().length != 2 || payload['sort'] != 'profile_order' || payload['items'] is! List) return false;
    try {
      for (final item in payload['items'] as List) {
        InventoryCatalogEntry.fromWire(Map<String,dynamic>.from(item as Map));
      }
      return true;
    } on Object { return false; }
  }

  bool _validInventoryShortages(Map<String,dynamic> payload) {
    try { InventoryShortageResult.fromWire(payload); return true; }
    on Object { return false; }
  }

  Map<String, dynamic>? _validRemoteError(Object value, String method) {
    if (value is! Map) {
      return null;
    }
    final error = Map<String, dynamic>.from(value);
    const requiredKeys = {'code', 'message'};
    const allowedKeys = {'code', 'message', 'details', 'retryable'};
    final code = error['code'];
    final allowedCodes = method.startsWith('repository.')
        ? _methodErrorCodes['repository']!
        : method.startsWith('scanner.')
            ? _methodErrorCodes['scanner']!
            : (_methodErrorCodes[method] ?? const {'unknown_method'});
    if (!error.keys.toSet().containsAll(requiredKeys) ||
        !allowedKeys.containsAll(error.keys) ||
        code is! String ||
        !allowedCodes.contains(code) ||
        error['message'] is! String ||
        (error['message'] as String).isEmpty ||
        (error.containsKey('details') && error['details'] is! Map) ||
        (error.containsKey('retryable') && error['retryable'] is! bool)) {
      return null;
    }
    return error;
  }

  bool _validEnvelope(Map<String, dynamic> message) {
    const keys = {'protocol', 'id', 'type', 'method', 'payload'};
    return message.keys.toSet().containsAll(keys) &&
        keys.containsAll(message.keys) &&
        message['protocol'] == 1 &&
        message['type'] == 'response' &&
        message['id'] is String &&
        (message['id'] as String).isNotEmpty &&
        message['method'] is String &&
        (message['method'] as String).isNotEmpty &&
        message['payload'] is Map;
  }

  bool _validEventEnvelope(Map<String, dynamic> message) {
    const keys = {'protocol', 'type', 'method', 'payload'};
    final payload = message['payload'];
    if (!message.keys.toSet().containsAll(keys) ||
        !keys.containsAll(message.keys) ||
        message['protocol'] != 1 ||
        message['type'] != 'event' ||
        message['method'] != 'scanner.session.event' ||
        payload is! Map) {
      return false;
    }
    final value = Map<String, dynamic>.from(payload);
    const baseKeys = {'session_id', 'generation', 'sequence', 'scan_kind', 'event_kind'};
    final baseValid = value['session_id'] is String &&
        (value['session_id'] as String).isNotEmpty &&
        value['generation'] is int &&
        (value['generation'] as int) > 0 &&
        value['sequence'] is int &&
        (value['sequence'] as int) > 0 &&
        (value['scan_kind'] == 'student' || value['scan_kind'] == 'inventory') &&
        const {'phase', 'progress', 'candidate', 'diagnostic', 'terminal'}
            .contains(value['event_kind']);
    if (!baseValid) return false;
    return switch (value['event_kind']) {
      'phase' => value.keys.toSet().difference({...baseKeys, 'phase'}).isEmpty &&
          value['phase'] is String && (value['phase'] as String).isNotEmpty,
      'progress' => value.keys.toSet().difference({...baseKeys, 'current', 'total', 'message_key'}).isEmpty &&
          value['current'] is int &&
          ((value['total'] is int && (value['total'] as int) >= 0) || value['total'] == null) &&
          value['message_key'] is String && (value['message_key'] as String).isNotEmpty,
      'candidate' => value.keys.toSet().difference({...baseKeys, 'candidate'}).isEmpty &&
          _validScannerCandidate(value['candidate']),
      'diagnostic' => value.keys.toSet().difference({...baseKeys, 'code', 'message'}).isEmpty &&
          value['code'] is String && (value['code'] as String).isNotEmpty && value['message'] is String,
      'terminal' => value.keys.toSet().difference({...baseKeys, 'outcome', 'error'}).isEmpty &&
          const {'completed', 'cancelled', 'failed'}.contains(value['outcome']) &&
          (!value.containsKey('error') || _validScannerTerminalError(value['error'])),
      _ => false,
    };
  }

  bool _validScannerTerminalError(Object? value) {
    if (value is! Map) return false;
    return value.keys.toSet().difference(const {'code', 'message'}).isEmpty &&
        value.length == 2 &&
        value['code'] is String &&
        (value['code'] as String).isNotEmpty &&
        value['message'] is String;
  }

  bool _validScannerSuccessPayload(String method, Map<String, dynamic> payload) {
    return switch (method) {
      'scanner.target.list' => payload.keys.toSet().containsAll({'targets'}) &&
          payload['targets'] is List &&
          (payload['targets'] as List).every((item) => item is Map && item['target_id'] is String && item['title'] is String && const {'ready','minimized','closed','unsupported'}.contains(item['status'])),
      'scanner.recognition.status' => payload['ready'] is bool &&
          payload['manifest_version'] is int && payload['missing'] is List,
      'scanner.session.start' => payload['session_id'] is String &&
          payload['generation'] is int && const {'student','inventory'}.contains(payload['scan_kind']),
      'scanner.session.cancel' => payload['accepted'] is bool,
      'scanner.session.snapshot' => payload['session_id'] is String &&
          payload['generation'] is int && payload['events'] is List && payload['candidates'] is List,
      'scanner.candidate.get' || 'scanner.candidate.review' =>
          _validScannerCandidate(payload['candidate']),
      'scanner.candidate.commit' => payload['candidate_id'] is String &&
          payload['candidate_revision'] is int && payload['profile_id'] is String && payload['revision'] is int,
      _ => false,
    };
  }

  bool _validScannerCandidate(Object? value) {
    if (value is! Map) return false;
    return value['candidate_id'] is String &&
        value['session_id'] is String &&
        value['generation'] is int &&
        value['revision'] is int &&
        const {'student','inventory'}.contains(value['scan_kind']) &&
        value['payload'] is Map &&
        value['evidence'] is List &&
        value['review_required'] is bool &&
        value['approved'] is bool &&
        value['audit'] is List;
  }

  void _fatalProtocolError(String message, int generation) {
    final error = BackendProtocolException(message);
    _emitProtocolError(message);
    _failPending(error);
    _process?.terminate();
    _disconnect(message, generation);
  }

  void _emitProtocolError(String message) {
    if (!_protocolErrors.isClosed) {
      _protocolErrors.add(BackendProtocolException(message));
    }
  }

  void _handleExit(int code, int generation) {
    if (generation != _generation || _stopping) {
      return;
    }
    _disconnect(
      'Backend process exited unexpectedly with code $code',
      generation,
    );
  }

  void _disconnect(String message, int generation) {
    if (generation != _generation) {
      return;
    }
    _process = null;
    _failPending(BackendDisconnectedException(message));
    connection.value = BackendConnection.disconnected;
    unawaited(_cancelSubscriptions());
  }

  void _failPending(Object error) {
    final requests = _pending.values.toList();
    _pending.clear();
    for (final pending in requests) {
      pending.timer.cancel();
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(error);
      }
    }
  }

  Future<void> _cancelSubscriptions() async {
    final stdoutSubscription = _stdoutSubscription;
    final stderrSubscription = _stderrSubscription;
    _stdoutSubscription = null;
    _stderrSubscription = null;
    await stdoutSubscription?.cancel();
    await stderrSubscription?.cancel();
  }
}

class _PendingRequest {
  _PendingRequest(this.method, this.completer, this.timer);

  final String method;
  final Completer<Map<String, dynamic>> completer;
  final Timer timer;
}
