import 'dart:convert';
import 'dart:io';

class ToolBackendException implements Exception {
  const ToolBackendException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract interface class ToolBackend {
  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]);
}

/// 요청 envelope를 그대로 보내고 응답 envelope를 해석하지 않고 돌려주는 전송(M2 메타데이터 관리자 새 메서드용).
///
/// 기존 20 메서드는 [ToolBackend.call]의 레거시 해석(`ok`가 아니면 예외, `result`만 반환)을 그대로 쓴다. 새 6 메서드는
/// strict DTO(`metadata_manager_dto.dart`)가 envelope 전체(`version/ok/result` · `version/ok/error`)를 검사하므로
/// 해석 전 원본이 필요하다.
abstract interface class ToolEnvelopeTransport {
  /// [request]를 보내고 JSON으로 읽은 응답을 그대로 돌려준다. JSON이 아니면 [ToolBackendException].
  Future<Object?> send(Map<String, Object?> request);
}

class ToolBackendClient implements ToolBackend, ToolEnvelopeTransport {
  factory ToolBackendClient({
    String? backendDirectory,
    String? pythonExecutable,
    Map<String, String> environment = const {},
  }) {
    final resolvedBackend = _resolveBackendDirectory(backendDirectory);
    return ToolBackendClient._(
      backendDirectory: resolvedBackend,
      pythonExecutable: _resolvePythonExecutable(
        pythonExecutable,
        resolvedBackend,
      ),
      environment: Map.unmodifiable(environment),
    );
  }

  const ToolBackendClient._({
    required this.backendDirectory,
    required this.pythonExecutable,
    required this.environment,
  });

  final String backendDirectory;
  final String pythonExecutable;

  /// Python 도구 프로세스에 더 얹는 환경 변수(시험이 `BA_PLANNER_USER_DIR`로 사용자 폴더를 격리할 때). 앱은 비워 둔다.
  final Map<String, String> environment;

  static String _resolveBackendDirectory(String? explicit) {
    if (explicit?.trim().isNotEmpty == true) return explicit!.trim();
    final fromEnvironment = Platform.environment['BA_PLANNER_BACKEND_DIR'];
    if (fromEnvironment?.trim().isNotEmpty == true) {
      return fromEnvironment!.trim();
    }
    final current = Directory.current;
    final direct = Directory('${current.path}${Platform.pathSeparator}backend');
    if (direct.existsSync()) return direct.path;
    return Directory(
      '${current.path}${Platform.pathSeparator}..${Platform.pathSeparator}backend',
    ).absolute.path;
  }

  static String _resolvePythonExecutable(String? explicit, String backend) {
    if (explicit?.trim().isNotEmpty == true) return explicit!.trim();
    final fromEnvironment = Platform.environment['BA_PLANNER_PYTHON'];
    if (fromEnvironment?.trim().isNotEmpty == true) {
      return fromEnvironment!.trim();
    }
    final localVirtualEnvironment = File(
      '$backend${Platform.pathSeparator}.venv'
      '${Platform.pathSeparator}${Platform.isWindows ? 'Scripts' : 'bin'}'
      '${Platform.pathSeparator}${Platform.isWindows ? 'python.exe' : 'python'}',
    );
    if (localVirtualEnvironment.existsSync()) {
      return localVirtualEnvironment.absolute.path;
    }
    return Platform.isWindows ? 'py' : 'python3';
  }

  /// Python 도구를 한 번 실행한다(요청 [body]를 stdin으로 보낸다).
  Future<({int exitCode, String output, String stderr})> _run(
    String body,
  ) async {
    final arguments =
        pythonExecutable.toLowerCase().endsWith('py.exe') ||
            pythonExecutable.toLowerCase() == 'py'
        ? <String>['-3.11', '-m', 'tools.developer_tools']
        : <String>['-m', 'tools.developer_tools'];
    final process = await Process.start(
      pythonExecutable,
      arguments,
      workingDirectory: backendDirectory,
      environment: {
        ...Platform.environment,
        ...environment,
        'PYTHONUTF8': '1',
        'PYTHONIOENCODING': 'utf-8',
      },
      runInShell: false,
    );
    process.stdin.write(body);
    await process.stdin.close();
    final outputFuture = process.stdout.transform(utf8.decoder).join();
    final errorFuture = process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;
    final output = await outputFuture;
    final stderr = await errorFuture;
    return (exitCode: exitCode, output: output, stderr: stderr);
  }

  @override
  Future<Object?> send(Map<String, Object?> request) async {
    final (:exitCode, :output, :stderr) = await _run(jsonEncode(request));
    try {
      return jsonDecode(output);
    } on FormatException {
      throw ToolBackendException(
        'Python 도구 응답을 읽을 수 없습니다 (exit $exitCode).\n$stderr\n$output',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    final (:exitCode, :output, :stderr) = await _run(
      jsonEncode({'version': 1, 'method': method, 'params': params}),
    );
    Map<String, dynamic> response;
    try {
      response = jsonDecode(output) as Map<String, dynamic>;
    } catch (_) {
      throw ToolBackendException(
        'Python 도구 응답을 읽을 수 없습니다 (exit $exitCode).\n$stderr\n$output',
      );
    }
    if (response['ok'] != true) {
      final error = response['error'];
      final message = error is Map ? error['message'] : null;
      throw ToolBackendException(
        '${message ?? '도구 작업이 실패했습니다.'}${stderr.trim().isEmpty ? '' : '\n$stderr'}',
      );
    }
    return (response['result'] as Map).cast<String, dynamic>();
  }
}
