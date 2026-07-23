// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/diagnostics_service.dart';
import '../../services/repository_service.dart';
import '../../services/scanner_service.dart';
import '../widgets/diagonal_section.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.service,
    required this.onOpenScan,
    required this.onOpenDiagnostics,
    required this.onProfileChanged,
    required this.onRecoveryCompleted,
  });

  final AppService service;
  final VoidCallback onOpenScan;
  final VoidCallback onOpenDiagnostics;
  final VoidCallback onProfileChanged;
  final VoidCallback onRecoveryCompleted;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  RepositoryService? get _repository => widget.service is RepositoryService
      ? widget.service as RepositoryService
      : null;
  ScannerService? get _scanner => widget.service is ScannerService
      ? widget.service as ScannerService
      : null;
  DiagnosticsService? get _diagnostics => widget.service is DiagnosticsService
      ? widget.service as DiagnosticsService
      : null;

  List<RepositoryProfile> _profiles = const [];
  List<ScannerTarget> _targets = const [];
  Map<String, dynamic>? _readiness;
  String? _profileError;
  String? _scannerError;
  String? _actionError;
  bool _loading = false;
  bool _profileAction = false;
  bool _recoveryAction = false;
  int _generation = 0;
  int _recoveryGeneration = 0;

  RepositoryProfile? get _selected {
    for (final profile in _profiles) {
      if (profile.selected) return profile;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    widget.service.state.addListener(_connectionChanged);
    _diagnostics?.diagnostics.addListener(_diagnosticsChanged);
    _reload();
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service == widget.service) return;
    oldWidget.service.state.removeListener(_connectionChanged);
    if (oldWidget.service is DiagnosticsService) {
      (oldWidget.service as DiagnosticsService).diagnostics.removeListener(
        _diagnosticsChanged,
      );
    }
    widget.service.state.addListener(_connectionChanged);
    _diagnostics?.diagnostics.addListener(_diagnosticsChanged);
    _reload();
  }

  @override
  void dispose() {
    _generation++;
    widget.service.state.removeListener(_connectionChanged);
    _diagnostics?.diagnostics.removeListener(_diagnosticsChanged);
    super.dispose();
  }

  void _diagnosticsChanged() {
    if (mounted) setState(() {});
  }

  void _connectionChanged() {
    if (!mounted) return;
    setState(() {});
    if (widget.service.state.value.connection == BackendConnection.connected) {
      _reload();
    } else {
      _generation++;
      setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    if (widget.service.state.value.connection != BackendConnection.connected) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _profileError = null;
      _scannerError = null;
      _actionError = null;
    });
    final repository = _repository;
    final scanner = _scanner;
    List<RepositoryProfile>? profiles;
    List<ScannerTarget>? targets;
    Map<String, dynamic>? readiness;
    String? profileError;
    String? scannerError;
    if (repository == null) {
      profileError = 'RepositoryService를 사용할 수 없습니다.';
    } else {
      try {
        profiles = await repository.listProfiles();
      } catch (error) {
        profileError = '$error';
      }
    }
    if (scanner == null) {
      scannerError = 'ScannerService를 사용할 수 없습니다.';
    } else {
      try {
        readiness = await scanner.scannerReadiness();
        targets = await scanner.listScannerTargets();
      } catch (error) {
        scannerError = '$error';
      }
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      if (profiles != null) _profiles = profiles;
      if (targets != null) _targets = targets;
      if (readiness != null) _readiness = readiness;
      _profileError = profileError;
      _scannerError = scannerError;
      _loading = false;
    });
  }

  Future<String?> _textDialog(
    String title,
    String label, [
    String value = '',
  ]) => showDialog<String>(
    context: context,
    builder: (context) {
      final controller = TextEditingController(text: value);
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('확인'),
          ),
        ],
      );
    },
  );

  Future<void> _createProfile() async {
    final name = await _textDialog('새 프로필', '프로필 이름');
    if (name == null || name.isEmpty || _repository == null) return;
    await _profileMutation(() async {
      final created = await _repository!.createProfile(
        name,
        'settings-create-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!created.selected) {
        await _repository!.selectProfile(
          created.id,
          created.revision,
          'settings-select-${created.id}-${created.revision}',
        );
      }
      return created;
    }, profileChanged: true);
  }

  Future<void> _renameProfile() async {
    final selected = _selected;
    if (selected == null || _repository == null) return;
    final name = await _textDialog('프로필 이름 변경', '새 이름', selected.displayName);
    if (name == null || name.isEmpty || name == selected.displayName) return;
    await _profileMutation(
      () => _repository!.renameProfile(
        selected.id,
        name,
        selected.revision,
        'settings-rename-${selected.id}-${selected.revision}-$name',
      ),
    );
  }

  Future<void> _selectProfile(RepositoryProfile profile) async {
    if (profile.selected || _repository == null) return;
    await _profileMutation(
      () => _repository!.selectProfile(
        profile.id,
        profile.revision,
        'settings-select-${profile.id}-${profile.revision}',
      ),
      profileChanged: true,
    );
  }

  Future<void> _profileMutation(
    Future<Object?> Function() operation, {
    bool profileChanged = false,
  }) async {
    if (_profileAction) return;
    setState(() {
      _profileAction = true;
      _actionError = null;
    });
    try {
      await operation();
      await _reload();
      if (profileChanged) widget.onProfileChanged();
    } catch (error) {
      if (mounted) {
        await _reload();
        if (mounted) setState(() => _actionError = '$error');
      }
    } finally {
      if (mounted) setState(() => _profileAction = false);
    }
  }

  Future<void> _recover(bool restart) async {
    if (_recoveryAction) return;
    final actionGeneration = ++_recoveryGeneration;
    setState(() {
      _recoveryAction = true;
      _actionError = null;
    });
    try {
      if (restart) {
        await widget.service.restartBackend();
      } else {
        await widget.service.reconnect();
      }
      if (!mounted || actionGeneration != _recoveryGeneration) return;
      await _reload();
      widget.onRecoveryCompleted();
    } catch (error) {
      if (mounted && actionGeneration == _recoveryGeneration) {
        setState(() => _actionError = '$error');
      }
    } finally {
      if (mounted && actionGeneration == _recoveryGeneration) {
        setState(() => _recoveryAction = false);
      }
    }
  }

  Future<void> _copyDiagnostics() async {
    final diagnostics = _diagnostics;
    if (diagnostics == null) return;
    final report = diagnostics.buildDiagnosticsReport(
      scannerReady: _readiness?['ready'] as bool?,
      scannerTargetCount: _targets.length,
    );
    await Clipboard.setData(ClipboardData(text: report));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀 정보가 제거된 진단 보고서를 복사했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = widget.service.state.value.connection;
    final diagnostics = _diagnostics?.diagnostics.value;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: DiagonalSection(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 38, 12),
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SETTINGS / RECOVERY',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        Text(
                          '프로필과 연결',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          '${_selected?.displayName ?? '선택 없음'} · ${connection.name}',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '설정 새로고침',
                    onPressed: _loading ? null : _reload,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                key: const ValueKey('settings-scroll'),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (_loading) const LinearProgressIndicator(),
                  if (_actionError != null)
                    _ErrorCard(
                      title: '작업을 완료하지 못했습니다.',
                      detail: _actionError!,
                      actionLabel: '다시 불러오기',
                      onAction: _reload,
                    ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth >= 980
                          ? (constraints.maxWidth - AppSpacing.lg) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: AppSpacing.lg,
                        runSpacing: AppSpacing.lg,
                        children: [
                          SizedBox(width: width, child: _profilesCard()),
                          SizedBox(
                            width: width,
                            child: _connectionCard(connection),
                          ),
                          SizedBox(width: width, child: _scannerCard()),
                          SizedBox(
                            width: width,
                            child: _diagnosticsCard(diagnostics),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profilesCard() => _SettingsCard(
    title: '프로필',
    icon: Icons.person_outline,
    actions: [
      FilledButton.icon(
        onPressed: _profileAction ? null : _createProfile,
        icon: const Icon(Icons.add),
        label: const Text('새 프로필'),
      ),
      OutlinedButton.icon(
        onPressed: _profileAction || _selected == null ? null : _renameProfile,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('이름 변경'),
      ),
    ],
    child: _profileError != null
        ? _InlineError(_profileError!)
        : _profiles.isEmpty
        ? const Text('프로필이 없습니다. 새 프로필을 만들어 시작하세요.')
        : Column(
            children: [
              for (final profile in _profiles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    profile.selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(profile.displayName),
                  subtitle: SelectableText(
                    'ID ${profile.id} · revision ${profile.revision}',
                  ),
                  trailing: profile.selected
                      ? const Chip(label: Text('현재 적용'))
                      : TextButton(
                          onPressed: _profileAction
                              ? null
                              : () => _selectProfile(profile),
                          child: const Text('전환'),
                        ),
                ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '프로필 삭제·백업·가져오기는 현재 버전에서 지원하지 않습니다.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
  );

  Widget _connectionCard(BackendConnection connection) => _SettingsCard(
    title: 'Backend 연결',
    icon: Icons.dns_outlined,
    actions: [
      OutlinedButton.icon(
        onPressed: _recoveryAction ? null : () => _recover(false),
        icon: const Icon(Icons.link),
        label: const Text('재연결'),
      ),
      FilledButton.tonalIcon(
        onPressed: _recoveryAction ? null : () => _recover(true),
        icon: const Icon(Icons.restart_alt),
        label: const Text('Backend 재시작'),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            connection == BackendConnection.connected
                ? Icons.check_circle_outline
                : connection == BackendConnection.connecting
                ? Icons.sync
                : Icons.cloud_off_outlined,
          ),
          title: Text(switch (connection) {
            BackendConnection.connected => '연결됨',
            BackendConnection.connecting => '연결 중',
            BackendConnection.disconnected => '연결 끊김',
          }),
          subtitle: Text(
            _recoveryAction
                ? '복구 작업이 진행 중입니다. 중복 실행은 차단됩니다.'
                : '재연결과 재시작은 저장되지 않은 draft나 scan 후보를 자동 확정하지 않습니다.',
          ),
        ),
      ],
    ),
  );

  Widget _scannerCard() {
    final ready = _readiness?['ready'] == true;
    return _SettingsCard(
      title: 'Scanner 준비 상태',
      icon: Icons.document_scanner_outlined,
      actions: [
        FilledButton.tonalIcon(
          onPressed: widget.onOpenScan,
          icon: const Icon(Icons.open_in_new),
          label: const Text('스캔 탭 열기'),
        ),
      ],
      child: _scannerError != null
          ? _InlineError(_scannerError!)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ready ? '인식 asset 준비됨' : '인식 asset 확인 필요'),
                const SizedBox(height: AppSpacing.sm),
                Text('감지된 대상 ${_targets.length}개'),
                for (final target in _targets.take(4))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      target.status == ScannerTargetStatus.ready
                          ? Icons.check
                          : Icons.warning_amber,
                    ),
                    title: Text(target.title),
                    subtitle: Text(
                      '${target.status.name}${target.foreground ? ' · foreground' : ''}',
                    ),
                  ),
                const Text(
                  '대상 선택과 스캔 시작은 스캔 탭에서만 수행하며 설정에 저장하지 않습니다.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
    );
  }

  Widget _diagnosticsCard(BackendDiagnostics? value) => _SettingsCard(
    title: '고급 진단',
    icon: Icons.monitor_heart_outlined,
    actions: [
      OutlinedButton.icon(
        onPressed: value == null ? null : _copyDiagnostics,
        icon: const Icon(Icons.copy_outlined),
        label: const Text('진단 복사'),
      ),
      FilledButton.tonalIcon(
        onPressed: widget.onOpenDiagnostics,
        icon: const Icon(Icons.display_settings_outlined),
        label: const Text('Adaptive-Sync'),
      ),
    ],
    child: value == null
        ? const Text('이 서비스는 process 진단 정보를 제공하지 않습니다.')
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                'protocol ${value.protocolVersion} · generation ${value.processGeneration}\n'
                'launcher ${value.launch.configured ? 'configured' : 'default'} / '
                '${value.launch.resolved ? 'resolved' : 'unresolved'}\n'
                '${value.launch.executable} ${value.launch.arguments.join(' ')}\n'
                '${value.launch.workingDirectory}',
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '최근 lifecycle ${value.lifecycle.length}건 · stderr ${value.stderr.length}건',
              ),
              for (final item in value.lifecycle.reversed.take(4))
                Text(
                  item,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                '진단 보고서는 환경 변수 값, token, 사용자 payload와 프로필 데이터를 포함하지 않습니다.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final IconData icon;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: actions,
            ),
          ],
        ],
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.onAction,
  });
  final String title;
  final String detail;
  final String actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      leading: const Icon(Icons.error_outline),
      title: Text(title),
      subtitle: Text(detail),
      trailing: TextButton(onPressed: onAction, child: Text(actionLabel)),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.error_outline),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Text(message)),
    ],
  );
}
