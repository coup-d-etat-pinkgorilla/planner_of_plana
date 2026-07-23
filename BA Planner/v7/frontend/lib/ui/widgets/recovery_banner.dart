import 'package:flutter/material.dart';

import '../../services/app_service.dart';
import '../../services/recovery_model.dart';

class RecoveryBanner extends StatefulWidget {
  const RecoveryBanner({
    super.key,
    required this.service,
    required this.onOpenSettings,
    required this.onOpenScan,
  });

  final AppService service;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenScan;

  @override
  State<RecoveryBanner> createState() => _RecoveryBannerState();
}

class _RecoveryBannerState extends State<RecoveryBanner> {
  bool _busy = false;
  String? _error;

  RecoveryIssue? _issue(AppServiceState state) {
    if (state.connection == BackendConnection.connecting) {
      return const RecoveryIssue(
        source: RecoverySource.backend,
        status: RecoveryStatus.connecting,
        summary: 'Backend 연결 중',
        impact: '현재 데이터 작업은 연결이 끝난 뒤 다시 불러옵니다.',
        actions: [RecoveryAction.openSettings],
      );
    }
    if (state.connection == BackendConnection.disconnected) {
      return const RecoveryIssue(
        source: RecoverySource.backend,
        status: RecoveryStatus.disconnected,
        summary: 'Backend 연결 끊김',
        impact: '저장·계산·스캔은 중단되지만 draft와 검토 후보를 자동 변경하지 않습니다.',
        actions: [
          RecoveryAction.reconnect,
          RecoveryAction.restartBackend,
          RecoveryAction.openSettings,
        ],
      );
    }
    if (state.scanPhase == ScanPhase.failed) {
      return const RecoveryIssue(
        source: RecoverySource.scanner,
        status: RecoveryStatus.failed,
        summary: '최근 스캔을 완료하지 못했습니다.',
        impact: '확정되지 않은 후보는 repository에 반영되지 않았습니다.',
        actions: [RecoveryAction.openScan, RecoveryAction.openSettings],
      );
    }
    return null;
  }

  Future<void> _recover(RecoveryAction action) async {
    if (_busy) return;
    if (action == RecoveryAction.openSettings) {
      widget.onOpenSettings();
      return;
    }
    if (action == RecoveryAction.openScan) {
      widget.onOpenScan();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (action == RecoveryAction.restartBackend) {
        await widget.service.restartBackend();
      } else {
        await widget.service.reconnect();
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.service.state,
    builder: (context, state, _) {
      final issue = _issue(state);
      if (issue == null && _error == null) return const SizedBox.shrink();
      final actions = issue?.actions ?? const [RecoveryAction.openSettings];
      return MaterialBanner(
        leading: _busy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.warning_amber_rounded),
        content: Text(
          _error == null
              ? '${issue!.summary}\n${issue.impact}'
              : '복구 작업 실패\n$_error',
        ),
        actions: [
          for (final action in actions)
            TextButton(
              onPressed: _busy ? null : () => _recover(action),
              child: Text(switch (action) {
                RecoveryAction.reload => '다시 불러오기',
                RecoveryAction.reconnect => '재연결',
                RecoveryAction.restartBackend => 'Backend 재시작',
                RecoveryAction.openSettings => '설정 열기',
                RecoveryAction.openScan => '스캔 열기',
              }),
            ),
        ],
      );
    },
  );
}
