// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/diagnostics_service.dart';
import '../../services/idempotency_keys.dart';
import '../../services/repository_service.dart';
import '../../services/scanner_service.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../settings/settings_sections.dart';
import '../studio/settings_studio_layout.dart';

/// 설정 탭(FE10-s, FD-179 (a)): 머리 띠 + 2×2 사선 섹션([settingsStudioDocument]). 내용 · 순서 · 문구 · 콜백은 옛 카드
/// 화면(프로필 → Backend 연결 → Scanner 준비 상태 → 고급 진단)과 같다(동작 변화 0).
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
        newIdempotencyKey('settings-create'),
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

  Future<void> _importV6Profile() async {
    final repository = _repository;
    if (repository == null || _profileAction) return;
    setState(() {
      _profileAction = true;
      _actionError = null;
    });
    try {
      final accounts = await repository.previewV6Accounts();
      if (!mounted) return;
      if (accounts.isEmpty) {
        throw StateError('가져올 수 있는 v6 계정을 찾지 못했습니다.');
      }
      final selected = accounts.length == 1
          ? accounts.single
          : await showDialog<RepositoryV6AccountPreview>(
              context: context,
              builder: (context) => SimpleDialog(
                key: const ValueKey('settings-v6-account-dialog'),
                title: const Text('v6 계정 가져오기'),
                children: [
                  for (final account in accounts)
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, account),
                      child: ListTile(
                        title: Text(account.displayName),
                        subtitle: Text(
                          '학생 ${account.studentCount}명 · 인벤토리 '
                          '${account.inventoryCount}종 · 계획 '
                          '${account.goalCount}개',
                        ),
                      ),
                    ),
                ],
              ),
            );
      if (selected == null || !mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('settings-v6-import-confirm'),
          title: const Text('v6 계정을 v7로 복사'),
          content: Text(
            '${selected.displayName}의 학생·인벤토리·계획 데이터를 '
            '새 v7 계정으로 복사합니다. v6 원본은 변경하지 않습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('가져오기'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await repository.importV6Account(selected.sourceProfileKey);
      await _reload();
      widget.onProfileChanged();
    } catch (error) {
      if (mounted) setState(() => _actionError = '$error');
    } finally {
      if (mounted) setState(() => _profileAction = false);
    }
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
    final actionError = _actionError;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        // 그리기 순서: 머리 띠 → 위 줄 → 아래 줄(인벤토리 KPI 띠 · 분석 섹션과 같은 순서).
        return Stack(
          children: [
            Positioned.fill(
              child: SettingsHeaderBand(
                size: size,
                caption: 'SETTINGS / RECOVERY',
                title: '프로필과 연결',
                subtitle:
                    '${_selected?.displayName ?? '선택 없음'} · ${connection.name}',
                loading: _loading,
                refreshTooltip: '설정 새로고침',
                onRefresh: _loading ? null : _reload,
                error: actionError == null
                    ? null
                    : SettingsHeaderError(
                        title: '작업을 완료하지 못했습니다.',
                        detail: actionError,
                        actionLabel: '다시 불러오기',
                        onAction: _reload,
                      ),
              ),
            ),
            Positioned.fill(child: _profilesSection(size)),
            Positioned.fill(child: _connectionSection(size, connection)),
            Positioned.fill(child: _scannerSection(size)),
            Positioned.fill(child: _diagnosticsSection(size, diagnostics)),
          ],
        );
      },
    );
  }

  Widget _profilesSection(Size size) {
    const id = settingsProfilesSectionId;
    final profileError = _profileError;
    final List<SettingsRowSpec> rows;
    final String kind;
    if (profileError != null) {
      kind = 'error';
      rows = [_errorRow(id, profileError)];
    } else if (_profiles.isEmpty) {
      kind = 'empty';
      rows = [_textRow(id, '프로필이 없습니다. 새 프로필을 만들어 시작하세요.', muted: false)];
    } else {
      kind = 'list';
      rows = [
        for (final profile in _profiles)
          SettingsRowSpec(
            height: SettingsMetrics.profileRowHeight,
            builder: (context) => _profileRow(profile),
          ),
        _textRow(
          id,
          'v6 원본은 읽기 전용으로 유지되며 새 v7 계정으로 복사됩니다. '
          '백업은 아직 지원하지 않습니다.',
        ),
      ];
    }
    return SettingsSection(
      size: size,
      sectionId: id,
      title: '프로필',
      listKey: ValueKey('$id-list-$kind'),
      rows: rows,
      actions: [
        TonalButton(
          label: '새 프로필',
          icon: Icons.add,
          variant: TonalButtonVariant.primary,
          onPressed: _profileAction ? null : _createProfile,
        ),
        TonalButton(
          key: const ValueKey('settings-profile-v6-import'),
          label: 'v6 가져오기',
          icon: Icons.drive_file_move_outline,
          variant: TonalButtonVariant.ghost,
          onPressed: _profileAction ? null : _importV6Profile,
        ),
        TonalButton(
          label: '이름 변경',
          icon: Icons.edit_outlined,
          variant: TonalButtonVariant.ghost,
          onPressed: _profileAction || _selected == null
              ? null
              : _renameProfile,
        ),
      ],
    );
  }

  Widget _profileRow(RepositoryProfile profile) => SettingsRow(
    key: ValueKey('settings-profile-${profile.id}'),
    sectionId: settingsProfilesSectionId,
    height: SettingsMetrics.profileRowHeight,
    look: profile.selected ? SettingsRowLook.selected : SettingsRowLook.filled,
    child: Row(
      children: [
        Icon(
          profile.selected
              ? Icons.radio_button_checked
              : Icons.radio_button_off,
          size: 18,
          color: profile.selected ? AppColors.accent : AppColors.textMuted,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: settingsTextStyle(
                  AppType.bodyPlusSize,
                  weight: AppType.bold,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                'ID ${profile.id} · revision ${profile.revision}',
                maxLines: 1,
                style: settingsTextStyle(
                  AppType.captionPlusSize,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (profile.selected)
          const BaChip(label: '현재 적용', tone: AppTones.pink)
        else
          TonalButton(
            label: '전환',
            height: SettingsMetrics.rowButtonHeight,
            fontSize: AppType.bodySmallSize,
            onPressed: _profileAction ? null : () => _selectProfile(profile),
          ),
      ],
    ),
  );

  Widget _connectionSection(Size size, BackendConnection connection) {
    const id = settingsBackendSectionId;
    return SettingsSection(
      size: size,
      sectionId: id,
      title: 'Backend 연결',
      listKey: const ValueKey('$id-list'),
      rows: [
        SettingsRowSpec(
          height: SettingsMetrics.statusRowHeight,
          builder: (context) => SettingsRow(
            key: const ValueKey('settings-backend-status'),
            sectionId: id,
            height: SettingsMetrics.statusRowHeight,
            child: _statusLine(
              icon: connection == BackendConnection.connected
                  ? Icons.check_circle_outline
                  : connection == BackendConnection.connecting
                  ? Icons.sync
                  : Icons.cloud_off_outlined,
              ok: connection == BackendConnection.connected,
              title: switch (connection) {
                BackendConnection.connected => '연결됨',
                BackendConnection.connecting => '연결 중',
                BackendConnection.disconnected => '연결 끊김',
              },
              subtitle: _recoveryAction
                  ? '복구 작업이 진행 중입니다. 중복 실행은 차단됩니다.'
                  : '재연결과 재시작은 저장되지 않은 draft나 scan 후보를 자동 확정하지 않습니다.',
              subtitleLines: 2,
            ),
          ),
        ),
      ],
      actions: [
        TonalButton(
          label: '재연결',
          icon: Icons.link,
          variant: TonalButtonVariant.ghost,
          onPressed: _recoveryAction ? null : () => _recover(false),
        ),
        TonalButton(
          label: 'Backend 재시작',
          icon: Icons.restart_alt,
          onPressed: _recoveryAction ? null : () => _recover(true),
        ),
      ],
    );
  }

  Widget _scannerSection(Size size) {
    const id = settingsScannerSectionId;
    final ready = _readiness?['ready'] == true;
    final scannerError = _scannerError;
    return SettingsSection(
      size: size,
      sectionId: id,
      title: 'Scanner 준비 상태',
      listKey: ValueKey('$id-list-${scannerError == null ? 'state' : 'error'}'),
      rows: scannerError != null
          ? [_errorRow(id, scannerError)]
          : [
              SettingsRowSpec(
                height: SettingsMetrics.lineRowHeight,
                builder: (context) => SettingsRow(
                  key: const ValueKey('settings-scanner-readiness'),
                  sectionId: id,
                  height: SettingsMetrics.lineRowHeight,
                  child: Text(
                    ready ? '인식 asset 준비됨' : '인식 asset 확인 필요',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: settingsTextStyle(
                      AppType.bodyPlusSize,
                      weight: AppType.bold,
                    ),
                  ),
                ),
              ),
              _textRow(id, '감지된 대상 ${_targets.length}개', muted: false),
              for (final target in _targets.take(4))
                SettingsRowSpec(
                  height: SettingsMetrics.targetRowHeight,
                  builder: (context) => SettingsRow(
                    sectionId: id,
                    height: SettingsMetrics.targetRowHeight,
                    child: _statusLine(
                      icon: target.status == ScannerTargetStatus.ready
                          ? Icons.check
                          : Icons.warning_amber,
                      ok: target.status == ScannerTargetStatus.ready,
                      title: target.title,
                      subtitle:
                          '${target.status.name}${target.foreground ? ' · foreground' : ''}',
                    ),
                  ),
                ),
              _textRow(id, '대상 선택과 스캔 시작은 스캔 탭에서만 수행하며 설정에 저장하지 않습니다.'),
            ],
      actions: [
        TonalButton(
          label: '스캔 탭 열기',
          icon: Icons.open_in_new,
          onPressed: widget.onOpenScan,
        ),
      ],
    );
  }

  Widget _diagnosticsSection(Size size, BackendDiagnostics? value) {
    const id = settingsDiagnosticsSectionId;
    return SettingsSection(
      size: size,
      sectionId: id,
      title: '고급 진단',
      listKey: ValueKey('$id-list-${value == null ? 'none' : 'process'}'),
      rows: value == null
          ? [_textRow(id, '이 서비스는 process 진단 정보를 제공하지 않습니다.', muted: false)]
          : [
              SettingsRowSpec(
                height: SettingsMetrics.processRowHeight,
                builder: (context) => SettingsRow(
                  key: const ValueKey('settings-diagnostics-process'),
                  sectionId: id,
                  height: SettingsMetrics.processRowHeight,
                  child: SelectableText(
                    'protocol ${value.protocolVersion} · generation ${value.processGeneration}\n'
                    'launcher ${value.launch.configured ? 'configured' : 'default'} / '
                    '${value.launch.resolved ? 'resolved' : 'unresolved'}\n'
                    '${value.launch.executable} ${value.launch.arguments.join(' ')}\n'
                    '${value.launch.workingDirectory}',
                    maxLines: 4,
                    style: settingsTextStyle(
                      AppType.bodySmallSize,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              _textRow(
                id,
                '최근 lifecycle ${value.lifecycle.length}건 · stderr ${value.stderr.length}건',
                muted: false,
              ),
              for (final item in value.lifecycle.reversed.take(4))
                _textRow(id, item, height: SettingsMetrics.lifecycleRowHeight),
              _textRow(
                id,
                '진단 보고서는 환경 변수 값, token, 사용자 payload와 프로필 데이터를 포함하지 않습니다.',
              ),
            ],
      actions: [
        TonalButton(
          label: '진단 복사',
          icon: Icons.copy_outlined,
          variant: TonalButtonVariant.ghost,
          onPressed: value == null ? null : _copyDiagnostics,
        ),
        TonalButton(
          label: 'Adaptive-Sync',
          icon: Icons.display_settings_outlined,
          onPressed: widget.onOpenDiagnostics,
        ),
      ],
    );
  }

  /// 아이콘 + 제목 + 흐린 설명 한 줄(옛 `ListTile`).
  Widget _statusLine({
    required IconData icon,
    required bool ok,
    required String title,
    required String subtitle,
    int subtitleLines = 1,
  }) => Row(
    children: [
      Icon(
        icon,
        size: 18,
        color: ok ? AppTones.ok.foreground : AppTones.warn.foreground,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: settingsTextStyle(
                AppType.bodyPlusSize,
                weight: AppType.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: subtitleLines,
              overflow: TextOverflow.ellipsis,
              style: settingsTextStyle(
                AppType.bodySmallSize,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  /// 투명 행 글(각주 · 설명, 두 줄까지).
  SettingsRowSpec _textRow(
    String sectionId,
    String text, {
    bool muted = true,
    double height = SettingsMetrics.noteRowHeight,
  }) => SettingsRowSpec(
    height: height,
    builder: (context) => SettingsRow(
      sectionId: sectionId,
      height: height,
      look: SettingsRowLook.plain,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: settingsTextStyle(
          muted ? AppType.bodySmallSize : AppType.bodyPlusSize,
          color: muted ? AppColors.textMuted : AppColors.text,
        ),
      ),
    ),
  );

  SettingsRowSpec _errorRow(String sectionId, String message) =>
      SettingsRowSpec(
        height: SettingsMetrics.errorRowHeight,
        builder: (context) => SettingsRow(
          sectionId: sectionId,
          height: SettingsMetrics.errorRowHeight,
          child: SettingsInlineError(message),
        ),
      );
}
