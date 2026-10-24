// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/asset_preparation_service.dart';
import '../../services/diagnostics_service.dart';
import '../../services/idempotency_keys.dart';
import '../../services/repository_service.dart';
import '../../services/scanner_service.dart';
import '../first_run/asset_preparation_controller.dart';
import '../first_run/first_run_folder_picker.dart';
import '../first_run/first_run_modal.dart';
import '../first_run/first_run_rules.dart';
import '../kit/ba_chip.dart';
import '../kit/ba_modal.dart';
import '../kit/buttons.dart';
import '../kit/skew_bar.dart';
import '../kit/skew_controls.dart' show BaSwitch;
import '../settings/settings_sections.dart';
import '../tutorial_host/tutorial_session.dart';
import '../studio/settings_studio_layout.dart';
import '../widgets/empty_backend_overlay.dart'
    show EmptyBackendHeaderChip, userDataMigrationReasonText;

// F3e 비활성 이유 · 줄 설명(시안 Settings-Help에 없는 문구는 워커 문구 — CF 검수, status F3e 종료 기록 표).
const settingsFirstRunUnavailableReason = '이 연결에서는 첫 실행 안내를 열 수 없습니다';
const settingsHelpDisabledReason = '설명서 주소가 아직 정해지지 않았습니다';
const settingsTutorialDescription = '임시 계정에서 처음부터 · 끝나면 지워짐';
const settingsTutorialDisabledReason = '튜토리얼은 아직 다시 시작할 수 없습니다';
const settingsTutorialNoAccountReason = '지금 쓰는 계정이 없습니다';
const settingsAutoUpdateDescription = '켜 두면 앱을 열 때 새 버전을 받습니다 · 다음 버전에 들어갑니다';
const settingsAutoUpdateDisabledReason = '자동 업데이트는 다음 버전에 들어갑니다';
const settingsImagesDescription = '② 이미지 준비를 다시 합니다';
const settingsImagesUnavailableReason = '이 연결에서는 그림을 준비할 수 없습니다';
const settingsImagesStatusFailedReason = '준비 상태를 읽지 못했습니다';
const settingsImagesScannerBusyReason = '스캔 중에는 다시 준비할 수 없습니다';
const settingsImagesNoFolderReason = '게임 설치 폴더를 먼저 정해 주십시오';
const settingsImagesBusyReason = '다른 준비 작업이 끝나기를 기다리는 중입니다';
const settingsScanReportDescription = '최근 스캔의 못 읽은 칸으로 신고 파일을 만듭니다';
const settingsScanReportDisabledReason = '신고 기능은 아직 쓸 수 없습니다';

/// 설정 탭(FE10-s, FD-179 (a)): 머리 띠 + 2×2 사선 섹션([settingsStudioDocument]). 내용 · 순서 · 문구 · 콜백은 옛 카드
/// 화면(프로필 → Backend 연결 → Scanner 준비 상태 → 고급 진단)과 같다(동작 변화 0).
///
/// F3e(시안 Settings-Help, FD-182, D-ALPHA-SPLIT): 첫 실행 · 안내 줄을 더한다.
/// - 머리 띠 "첫 실행 안내 다시 열기" → F3b [FirstRunPanel] entry full을 지금 화면 위 모달로(③은 F3b 규칙 그대로 새 계정을
///   만든다). "도움말 · GitHub 설명서"는 주소가 정해지지 않아 꺼 둔다.
/// - Scanner 준비 상태 "그림 다시 준비" → entry imagesOnly(ready여도 다시 시작). 줄에 지금 cache.state와 진행 중이면 진행을
///   보인다. 준비 상태는 이 화면의 [AssetPreparationController] 하나를 줄과 모달이 함께 본다.
/// - 프로필 "튜토리얼 다시 하기"는 [onRestartTutorial](F3c)이 없으면 꺼진다. "스캔 문제 신고"(XB X5 전) · "자동 업데이트"
///   (XB X2 전 — 플래그 파일을 쓰지 않는다)는 자리만 둔다.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.service,
    required this.onOpenScan,
    required this.onOpenDiagnostics,
    required this.onProfileChanged,
    required this.onRecoveryCompleted,
    this.onRestartTutorial,
    this.folderPicker = const NativeFirstRunFolderPicker(),
  });

  final AppService service;
  final VoidCallback onOpenScan;
  final VoidCallback onOpenDiagnostics;
  final VoidCallback onProfileChanged;
  final VoidCallback onRecoveryCompleted;

  /// "튜토리얼 다시 하기"와 설정에서 다시 연 첫 실행 ③ 뒤에 부르는 자리(F3c가 연결한다). account는 튜토리얼이 끝나면
  /// 돌아올 계정이다 — 줄은 지금 쓰는 계정, ③은 방금 만들고 고른 계정. null이면 "튜토리얼 다시 하기"를 끈다.
  final FirstRunTutorialStarter? onRestartTutorial;

  /// 설정에서 다시 연 첫 실행 ①의 폴더 고르기(시험은 가짜).
  final FirstRunFolderPicker folderPicker;

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

  /// F3e: 첫 실행 모달(설정에서 다시 엶)과 준비 상태.
  final _firstRunModal = FirstRunModalController();
  AssetPreparationController? _preparation;
  FirstRunEntry? _firstRunEntry;
  bool _firstRunRestart = false;

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
    _firstRunModal.addListener(_firstRunModalChanged);
    _attachPreparation();
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
    _firstRunModal
      ..locked = false
      ..close();
    _firstRunEntry = null;
    _detachPreparation();
    _attachPreparation();
    _reload();
  }

  @override
  void dispose() {
    _generation++;
    widget.service.state.removeListener(_connectionChanged);
    _diagnostics?.diagnostics.removeListener(_diagnosticsChanged);
    _firstRunModal
      ..removeListener(_firstRunModalChanged)
      ..dispose();
    _detachPreparation();
    super.dispose();
  }

  /// 준비를 지원하지 않는 서비스면 컨트롤러를 두지 않는다(그림 다시 준비 · 첫 실행 안내가 꺼진다).
  void _attachPreparation() {
    final service = widget.service.assetPreparation;
    if (service == null) return;
    _preparation = AssetPreparationController(
      service,
      appState: widget.service.state,
    )..addListener(_preparationChanged);
  }

  void _detachPreparation() {
    _preparation
      ?..removeListener(_preparationChanged)
      ..dispose();
    _preparation = null;
  }

  void _preparationChanged() {
    if (mounted) setState(() {});
  }

  void _firstRunModalChanged() {
    if (_firstRunModal.isOpen || _firstRunEntry == null || !mounted) return;
    setState(() => _firstRunEntry = null);
  }

  /// 첫 실행 모달을 지금 화면 위에 연다. [restart]면 ②에서 캐시가 ready여도 준비를 다시 시작한다.
  void _openFirstRun(FirstRunEntry entry, {bool restart = false}) {
    if (_preparation == null || _firstRunModal.isOpen) return;
    setState(() {
      _firstRunEntry = entry;
      _firstRunRestart = restart;
    });
    _firstRunModal.open();
  }

  /// 설정에서 다시 연 ③: F3b 규칙대로 새 계정을 만들고 골랐다. 모달을 닫고 목록 · 셸을 새로 읽은 뒤 튜토리얼 시작 자리를
  /// 부른다(없으면 설정 탭에 남는다).
  void _firstRunAccountCreated(RepositoryProfile account) {
    _firstRunModal
      ..locked = false
      ..close();
    unawaited(_reload());
    widget.onProfileChanged();
    widget.onRestartTutorial?.call(context, account);
  }

  /// 튜토리얼 중(임시 계정은 일반 목록에 없다)이면 돌아갈 계정은 튜토리얼 세션의 첫 계정이다(F3c-3).
  RepositoryProfile? get _tutorialAccount =>
      _selected ?? TutorialHostScope.sessionOf(context)?.origin;

  void _restartTutorial() {
    final start = widget.onRestartTutorial;
    final account = _tutorialAccount;
    if (start == null || account == null) return;
    start(context, account);
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
    unawaited(_preparation?.refresh());
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
                actions: [
                  SettingsActionButton(
                    key: const ValueKey('settings-first-run-open'),
                    label: '첫 실행 안내 다시 열기',
                    icon: Icons.replay,
                    onPressed: _preparation == null
                        ? null
                        : () => _openFirstRun(FirstRunEntry.full),
                    disabledReason: settingsFirstRunUnavailableReason,
                  ),
                  const SettingsActionButton(
                    key: ValueKey('settings-help'),
                    label: '도움말 · GitHub 설명서',
                    icon: Icons.menu_book_outlined,
                    onPressed: null,
                    disabledReason: settingsHelpDisabledReason,
                  ),
                ],
              ),
            ),
            Positioned.fill(child: _profilesSection(size)),
            Positioned.fill(child: _connectionSection(size, connection)),
            Positioned.fill(child: _scannerSection(size)),
            Positioned.fill(child: _diagnosticsSection(size, diagnostics)),
            // F3e: 설정에서 다시 여는 첫 실행 모달(F3b 타이틀 자리와 같이 내용 없는 BaModal).
            Positioned.fill(
              child: BaModal(
                controller: _firstRunModal,
                scrim: BaScrim.scan,
                label: firstRunTitle,
                barrierDismissible: false,
                builder: _buildFirstRun,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 설정에서 다시 연 첫 실행 패널(F3b 그대로, 모달 · 준비 상태는 이 화면 것).
  Widget _buildFirstRun(BuildContext context) {
    final entry = _firstRunEntry;
    final preparation = _preparation;
    if (entry == null || preparation == null) return const SizedBox.shrink();
    return FirstRunPanel(
      key: ValueKey('settings-first-run-${entry.name}'),
      entry: entry,
      preparation: preparation,
      repository: _repository,
      folderPicker: widget.folderPicker,
      restart: _firstRunRestart,
      onClose: _firstRunModal.close,
      onAccountCreated: _firstRunAccountCreated,
      onLockChanged: (locked) => _firstRunModal.locked = locked,
    );
  }

  Widget _profilesSection(Size size) {
    const id = settingsProfilesSectionId;
    final profileError = _profileError;
    final List<SettingsRowSpec> rows;
    final String kind;
    if (profileError != null) {
      kind = 'error';
      rows = [_errorRow(id, profileError), _tutorialRow()];
    } else if (_profiles.isEmpty) {
      kind = 'empty';
      rows = [
        _textRow(id, '프로필이 없습니다. 새 프로필을 만들어 시작하세요.', muted: false),
        _tutorialRow(),
      ];
    } else {
      kind = 'list';
      rows = [
        for (final profile in _profiles)
          SettingsRowSpec(
            height: SettingsMetrics.profileRowHeight,
            builder: (context) => _profileRow(profile),
          ),
        _tutorialRow(),
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
    // SU1: 사용자 데이터 이관 실패면 재연결을 끈다(풀리지 않는다).
    // SU2: 'Backend 재시작'은 켠다 — 원인을 해결한 뒤 새 프로세스로 다시 시도한다(또 실패하면 같은 상태).
    final failure = widget.service.state.value.userDataMigrationFailure;
    final recoveryDisabled = _recoveryAction || failure != null;
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
              icon: failure != null
                  ? Icons.error_outline
                  : connection == BackendConnection.connected
                  ? Icons.check_circle_outline
                  : connection == BackendConnection.connecting
                  ? Icons.sync
                  : Icons.cloud_off_outlined,
              ok: failure == null && connection == BackendConnection.connected,
              title: failure != null
                  ? EmptyBackendHeaderChip.userDataLabel
                  : switch (connection) {
                      BackendConnection.connected => '연결됨',
                      BackendConnection.connecting => '연결 중',
                      BackendConnection.disconnected => '연결 끊김',
                    },
              subtitle: failure != null
                  ? '${userDataMigrationReasonText(failure.reason)} '
                        "기존 데이터는 그대로이며, 원인을 해결한 뒤 'Backend 재시작'으로 다시 시도합니다."
                  : _recoveryAction
                  ? '복구 작업이 진행 중입니다. 중복 실행은 차단됩니다.'
                  : '재연결과 재시작은 저장되지 않은 draft나 scan 후보를 자동 확정하지 않습니다.',
              subtitleLines: 2,
            ),
          ),
        ),
        _lineRow(
          id,
          key: 'settings-auto-update',
          title: '자동 업데이트',
          description: settingsAutoUpdateDescription,
          trailing: const [
            BaSwitch(
              key: ValueKey('settings-auto-update-switch'),
              value: false,
              onChanged: null,
              semanticLabel: '자동 업데이트',
            ),
            SettingsActionButton(
              key: ValueKey('settings-auto-update-check'),
              label: '지금 확인',
              icon: Icons.refresh,
              onPressed: null,
              disabledReason: settingsAutoUpdateDisabledReason,
            ),
          ],
        ),
      ],
      actions: [
        TonalButton(
          label: '재연결',
          icon: Icons.link,
          variant: TonalButtonVariant.ghost,
          onPressed: recoveryDisabled ? null : () => _recover(false),
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
    // F3e 줄(시안 Settings-Help 스캐너 판 순서). 스캐너 서비스 오류와 상관없이 보인다.
    final helpRows = [_gameDirRow(), _imagesRow(), _scanReportRow()];
    return SettingsSection(
      size: size,
      sectionId: id,
      title: 'Scanner 준비 상태',
      listKey: ValueKey('$id-list-${scannerError == null ? 'state' : 'error'}'),
      rows: scannerError != null
          ? [_errorRow(id, scannerError), ...helpRows]
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
              ...helpRows,
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

  // --- F3e 줄 -------------------------------------------------------------

  /// 시안 Settings-Help 프로필 판 "튜토리얼 다시 하기"(F3c가 [SettingsPage.onRestartTutorial]을 넘긴다).
  SettingsRowSpec _tutorialRow() {
    final reason = widget.onRestartTutorial == null
        ? settingsTutorialDisabledReason
        : _tutorialAccount == null
        ? settingsTutorialNoAccountReason
        : null;
    return _lineRow(
      settingsProfilesSectionId,
      key: 'settings-tutorial-restart',
      title: '튜토리얼 다시 하기',
      description: settingsTutorialDescription,
      reason: reason,
      trailing: [
        SettingsActionButton(
          key: const ValueKey('settings-tutorial-restart-button'),
          label: '다시 하기',
          icon: Icons.play_arrow_rounded,
          onPressed: reason == null && !_profileAction
              ? _restartTutorial
              : null,
          disabledReason: reason,
        ),
      ],
    );
  }

  /// 시안 "게임 설치 폴더 · — · 찾음": 지금 폴더와 상태(F3b ① 칩 문구). 모르면 '—'.
  SettingsRowSpec _gameDirRow() {
    final value = _preparation?.value;
    final dir = value?.gameDir;
    var text = '—';
    if (value != null && value.loaded && dir != null) {
      final reason = dir.reason;
      final state = dir.valid
          ? (dir.source == AssetGameDirSource.user ? '지정함' : '찾음 · Steam')
          : reason == null
          ? '찾지 못함'
          : firstRunGameDirReasonTexts[reason]!.chip;
      text = '${dir.path ?? '—'} · $state';
    }
    return SettingsRowSpec(
      height: SettingsMetrics.folderRowHeight,
      builder: (context) => SettingsRow(
        key: const ValueKey('settings-game-dir'),
        sectionId: settingsScannerSectionId,
        height: SettingsMetrics.folderRowHeight,
        child: SettingsInfoLine(
          title: '게임 설치 폴더',
          value: text,
          valueKey: const ValueKey('settings-game-dir-value'),
        ),
      ),
    );
  }

  /// 시안 "그림 다시 준비": 지금 준비 상태 · 진행(번들 단위, 분모가 없으면 숨김). 준비 중이면 "진행 보기"로 같은 모달을 연다.
  SettingsRowSpec _imagesRow() {
    final value = _preparation?.value;
    final preparing = value?.preparing ?? false;
    final progress = value?.progress;
    final enabled = value != null && (preparing || value.canStart);
    final reason = enabled ? null : _imagesDisabledReason(value);
    return _lineRow(
      settingsScannerSectionId,
      key: 'settings-images',
      title: '그림 다시 준비',
      description: '$settingsImagesDescription · ${_imagesStateText(value)}',
      reason: reason,
      progress: preparing
          ? SizedBox(
              key: const ValueKey('settings-images-progress'),
              width: SettingsMetrics.progressBarWidth,
              height: SettingsMetrics.progressBarHeight,
              child: SkewBar(
                fraction: progress?.fraction,
                color: AppColors.accent,
                height: SettingsMetrics.progressBarHeight,
              ),
            )
          : null,
      trailing: [
        SettingsActionButton(
          key: const ValueKey('settings-images-button'),
          label: preparing ? '진행 보기' : '다시 준비',
          icon: preparing ? Icons.visibility_outlined : Icons.refresh,
          variant: TonalButtonVariant.primary,
          onPressed: !enabled
              ? null
              : preparing
              ? () => _openFirstRun(FirstRunEntry.imagesOnly)
              : () => _openFirstRun(FirstRunEntry.imagesOnly, restart: true),
          disabledReason: reason,
        ),
      ],
    );
  }

  /// cache.state → 한국어(모르면 '—'). 준비 중이면 단계 · 번들 수.
  String _imagesStateText(AssetPreparationViewState? value) {
    if (value == null) return '—';
    final progress = value.progress;
    if (progress != null) {
      final activity = value.cancelRequested
          ? '취소하는 중'
          : firstRunStageActivity[progress.stage]!;
      return '준비 중 · $activity · '
          '${firstRunStageCount(progress.done, progress.total)}개 번들';
    }
    final cache = value.cache;
    if (!value.loaded || cache == null) return '—';
    final failed = cache.failed;
    return switch (cache.state) {
      AssetCacheState.ready => '준비됨',
      AssetCacheState.partial =>
        failed == null || failed <= 0
            ? '일부 준비됨'
            : '만들지 못한 스캔용 그림 ${firstRunGrouped(failed)}개',
      AssetCacheState.missing => '준비 안 됨',
      AssetCacheState.stale => '게임 업데이트로 다시 준비 필요',
      AssetCacheState.invalid => '준비한 그림 확인 실패',
      AssetCacheState.unknown => '—',
    };
  }

  /// 그림 다시 준비가 꺼진 이유. status를 읽는 중이면 이유 없이 꺼 둔다.
  String? _imagesDisabledReason(AssetPreparationViewState? value) {
    if (value == null) return settingsImagesUnavailableReason;
    if (value.scannerBusy) return settingsImagesScannerBusyReason;
    if (!value.loaded) {
      return value.loading ? null : settingsImagesStatusFailedReason;
    }
    if (!value.folderValid) return settingsImagesNoFolderReason;
    if (value.busy) return settingsImagesBusyReason;
    return null;
  }

  /// 시안 "스캔 문제 신고"(F4 · XB X5 전 — 자리만).
  SettingsRowSpec _scanReportRow() => _lineRow(
    settingsScannerSectionId,
    key: 'settings-scan-report',
    title: '스캔 문제 신고',
    description: settingsScanReportDescription,
    reason: settingsScanReportDisabledReason,
    trailing: const [
      SettingsActionButton(
        key: ValueKey('settings-scan-report-button'),
        label: '신고하기',
        icon: Icons.flag_outlined,
        onPressed: null,
        disabledReason: settingsScanReportDisabledReason,
      ),
    ],
  );

  /// F3e 줄(제목 · 설명 · 오른쪽 버튼). 꺼진 이유가 있으면 설명 뒤에 " · 이유"로 붙인다(시안 "… · 다음 버전에 들어갑니다").
  SettingsRowSpec _lineRow(
    String sectionId, {
    required String key,
    required String title,
    required String description,
    String? reason,
    Widget? progress,
    required List<Widget> trailing,
  }) => SettingsRowSpec(
    height: SettingsMetrics.actionRowHeight,
    builder: (context) => SettingsRow(
      key: ValueKey(key),
      sectionId: sectionId,
      height: SettingsMetrics.actionRowHeight,
      child: SettingsActionLine(
        title: title,
        description: reason == null ? description : '$description · $reason',
        descriptionKey: ValueKey('$key-description'),
        progress: progress,
        trailing: trailing,
      ),
    ),
  );

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
