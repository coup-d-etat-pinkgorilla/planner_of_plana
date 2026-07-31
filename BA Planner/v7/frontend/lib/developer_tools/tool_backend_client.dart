import 'dart:convert';
import 'dart:io';

class ToolBackendException implements Exception {
  const ToolBackendException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ToolBackendClient {
  ToolBackendClient({String? backendDirectory, String? pythonExecutable})
    : backendDirectory = _resolveBackendDirectory(backendDirectory),
      pythonExecutable = pythonExecutable?.trim().isNotEmpty == true
          ? pythonExecutable!.trim()
          : (Platform.environment['BA_PLANNER_PYTHON']?.trim().isNotEmpty ==
                    true
                ? Platform.environment['BA_PLANNER_PYTHON']!.trim()
                : 'py');

  final String backendDirectory;
  final String pythonExecutable;

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

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
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
        'PYTHONUTF8': '1',
        'PYTHONIOENCODING': 'utf-8',
      },
      runInShell: false,
    );
    process.stdin.write(
      jsonEncode({'version': 1, 'method': method, 'params': params}),
    );
    await process.stdin.close();
    final outputFuture = process.stdout.transform(utf8.decoder).join();
    final errorFuture = process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;
    final output = await outputFuture;
    final stderr = await errorFuture;
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
