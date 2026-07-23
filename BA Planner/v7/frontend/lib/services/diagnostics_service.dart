import 'package:flutter/foundation.dart';

import 'app_service.dart';

String redactDiagnosticText(String value) {
  final fields = value.replaceAllMapped(
    RegExp(
      r'(token|password|secret|authorization)\s*[:=]\s*\S+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}=<redacted>',
  );
  final options = fields.replaceAllMapped(
    RegExp(
      r'(--?(?:token|password|secret|authorization))(?:\s+|=)\S+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}=<redacted>',
  );
  return options.replaceAll(
    RegExp(r'bearer\s+\S+', caseSensitive: false),
    'Bearer <redacted>',
  );
}

List<String> redactDiagnosticArguments(List<String> values) {
  final result = <String>[];
  var redactNext = false;
  final secretOption = RegExp(
    r'^--?(?:token|password|secret|authorization)$',
    caseSensitive: false,
  );
  for (final value in values) {
    if (redactNext) {
      result.add('<redacted>');
      redactNext = false;
    } else {
      result.add(redactDiagnosticText(value));
      redactNext = secretOption.hasMatch(value);
    }
  }
  return List.unmodifiable(result);
}

@immutable
class BackendLaunchInfo {
  const BackendLaunchInfo({
    required this.configured,
    required this.resolved,
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
  });

  const BackendLaunchInfo.unresolved({
    this.configured = false,
    this.executable = 'default Python launcher',
    this.workingDirectory = 'auto-detect on connect',
  }) : resolved = false,
       arguments = const [];

  final bool configured;
  final bool resolved;
  final String executable;
  final List<String> arguments;
  final String workingDirectory;

  BackendLaunchInfo redacted() => BackendLaunchInfo(
    configured: configured,
    resolved: resolved,
    executable: redactDiagnosticText(executable),
    arguments: redactDiagnosticArguments(arguments),
    workingDirectory: redactDiagnosticText(workingDirectory),
  );
}

@immutable
class BackendDiagnostics {
  const BackendDiagnostics({
    required this.protocolVersion,
    required this.connection,
    required this.processGeneration,
    required this.launch,
    required this.lifecycle,
    required this.stderr,
  });

  final int protocolVersion;
  final BackendConnection connection;
  final int processGeneration;
  final BackendLaunchInfo launch;
  final List<String> lifecycle;
  final List<String> stderr;

  BackendDiagnostics copyWith({
    BackendConnection? connection,
    int? processGeneration,
    BackendLaunchInfo? launch,
    List<String>? lifecycle,
    List<String>? stderr,
  }) => BackendDiagnostics(
    protocolVersion: protocolVersion,
    connection: connection ?? this.connection,
    processGeneration: processGeneration ?? this.processGeneration,
    launch: launch ?? this.launch,
    lifecycle: lifecycle ?? this.lifecycle,
    stderr: stderr ?? this.stderr,
  );
}

abstract interface class DiagnosticsService {
  ValueListenable<BackendDiagnostics> get diagnostics;

  String buildDiagnosticsReport({
    required bool? scannerReady,
    required int scannerTargetCount,
  });
}
