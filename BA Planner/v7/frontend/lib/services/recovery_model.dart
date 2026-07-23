enum RecoverySource { backend, repository, scanner, tactical, planning }

enum RecoveryStatus {
  disconnected,
  connecting,
  loading,
  empty,
  partialFailure,
  revisionConflict,
  failed,
}

enum RecoveryAction {
  reload,
  reconnect,
  restartBackend,
  openSettings,
  openScan,
}

class RecoveryIssue {
  const RecoveryIssue({
    required this.source,
    required this.status,
    required this.summary,
    required this.impact,
    required this.actions,
  });

  final RecoverySource source;
  final RecoveryStatus status;
  final String summary;
  final String impact;
  final List<RecoveryAction> actions;
}
