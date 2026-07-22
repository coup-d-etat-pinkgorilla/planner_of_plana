import 'dart:async';
import 'dart:convert';
import 'dart:io';

class BackendProcessConfig {
  BackendProcessConfig({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    Map<String, String> environment = const {},
  }) : environment = Map.unmodifiable(environment);

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
  final Map<String, String> environment;

  static BackendProcessConfig resolve({
    String pythonExecutable = '',
    String backendDirectory = '',
    Map<String, String> environment = const {},
  }) {
    final directory = backendDirectory.isNotEmpty
        ? Directory(backendDirectory)
        : _findBackendDirectory();
    if (!directory.existsSync()) {
      throw StateError('Backend directory does not exist: ${directory.path}');
    }
    final executable = pythonExecutable.isEmpty
        ? (Platform.isWindows ? 'py' : 'python3')
        : pythonExecutable;
    final executableName = executable
        .split(RegExp(r'[/\\]'))
        .last
        .toLowerCase();
    final arguments = <String>[
      if (Platform.isWindows && executableName == 'py') '-3.11',
      '-m',
      'core.backend_process',
    ];
    return BackendProcessConfig(
      executable: executable,
      arguments: arguments,
      workingDirectory: directory.absolute.path,
      environment: environment,
    );
  }

  static Directory _findBackendDirectory() {
    var directory = File(Platform.resolvedExecutable).parent;
    for (var index = 0; index < 8; index += 1) {
      final candidate = Directory(
        '${directory.path}${Platform.pathSeparator}backend',
      );
      if (File(
        '${candidate.path}${Platform.pathSeparator}core'
        '${Platform.pathSeparator}backend_process.py',
      ).existsSync()) {
        return candidate;
      }
      directory = directory.parent;
    }
    throw StateError(
      'Could not locate backend relative to ${Platform.resolvedExecutable}. '
      'Set BA_PLANNER_BACKEND_DIR.',
    );
  }
}

abstract interface class BackendProcessHandle {
  Stream<String> get stdoutLines;

  Stream<String> get stderrLines;

  Future<int> get exitCode;

  void writeLine(String line);

  Future<void> closeInput();

  bool terminate([ProcessSignal signal = ProcessSignal.sigterm]);
}

typedef BackendProcessStarter = Future<BackendProcessHandle> Function();

Future<BackendProcessHandle> startBackendProcess(
  BackendProcessConfig config,
) async {
  final process = await Process.start(
    config.executable,
    config.arguments,
    workingDirectory: config.workingDirectory,
    environment: config.environment,
    includeParentEnvironment: true,
    runInShell: false,
  );
  return IoBackendProcessHandle(process);
}

class IoBackendProcessHandle implements BackendProcessHandle {
  IoBackendProcessHandle(this._process);

  final Process _process;

  @override
  Stream<String> get stdoutLines =>
      _process.stdout.transform(utf8.decoder).transform(const LineSplitter());

  @override
  Stream<String> get stderrLines => _process.stderr
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  void writeLine(String line) {
    _process.stdin.writeln(line);
  }

  @override
  Future<void> closeInput() => _process.stdin.close();

  @override
  bool terminate([ProcessSignal signal = ProcessSignal.sigterm]) {
    return _process.kill(signal);
  }
}
