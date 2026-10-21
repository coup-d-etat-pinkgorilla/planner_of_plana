// ignore_for_file: unused_element

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../app_section.dart';
import '../app_shell.dart';
import '../first_run/first_run_modal.dart';
import '../first_run/first_run_rules.dart';
import '../kit/game_image.dart';
import '../kit/skew_bar.dart';
import '../studio/section_studio_document.dart';
import '../studio/section_template.dart';
import '../studio/title_studio_layout.dart';
import '../widgets/asset_image_grid.dart';
import '../widgets/account_section_cluster.dart';
import '../widgets/ba_triangle_background.dart';
import '../widgets/lifted_path_shadow.dart';
import '../widgets/section_surface.dart';
import '../widgets/section_template_surface.dart';
import '../widgets/student_grid_warmup.dart';
import '../widgets/student_section_layout.dart' show studentGridCardPath;

// FE8-a(2026-10-10): 시안 `Title.dc.html` 값. T 번호는 A 보고서 §2.4의 차이 표다.

/// 로고 띠·계정 카드 path의 모서리 반경(시안 path `Q 16`, T3).
const _titleSurfaceRadius = 16.0;

/// 설정·나가기·시작 버튼 path의 모서리 반경(시안 path `Q 8`, FE8-b: FE8-a 발견 사항 3). Studio 기본은 10이다.
const titleButtonRadius = 8.0;

/// 설정·나가기 외곽선 rgba(56,81,107,.72) 1.8px(FE8-b).
const _titleCornerOutline = Color.fromRGBO(56, 81, 107, 0.72);
const _titleCornerOutlineWidth = 1.8;

/// 계정 카드 채움 rgba(29,42,58,.9) + 외곽선 rgba(56,81,107,.6) 1.2px(FE8-b). 공용 섹션 표면(.76)의 예외다(FD-001).
const titleAccountCardFill = Color.fromRGBO(29, 42, 58, 0.9);
const _titleAccountCardOutline = Color.fromRGBO(56, 81, 107, 0.6);
const _titleAccountCardOutlineWidth = 1.2;

/// 로고 띠 채움 rgba(29,42,58,.93)(T10). 공용 섹션 표면(.76)보다 불투명하다(FD-001 시안 우선).
const _titleBrandFill = Color.fromRGBO(29, 42, 58, 0.93);

/// 로고 띠 glow `radial-gradient(60% 90% at 50% 45%, rgba(242,179,239,.09), transparent 70%)`(T10).
const _titleBrandGlow = Color.fromRGBO(242, 179, 239, 0.09);
const _titleBrandGlowClear = Color.fromRGBO(242, 179, 239, 0);

/// 시작 버튼 분홍 외곽선 rgba(242,179,239,.9) 1.8px(T8).
const _titlePrimaryOutline = Color.fromRGBO(242, 179, 239, 0.9);
const _titlePrimaryOutlineWidth = 1.8;

/// Space 키캡: 버튼 아래 14px, 높이 26, 좌우 12, r5, #0d151f + 안쪽 1px rgba(56,81,107,.9)(T9).
const _titleKeyCapGap = 14.0;
const _titleKeyCapHeight = 26.0;
const _titleKeyCapBorder = Color.fromRGBO(56, 81, 107, 0.9);
const _titleKeyCapText = Color(0xffdfe7ee);

/// 보유율 진행 막대: 높이 5, r3, 트랙 rgba(255,255,255,.14), 채움 #f4f8fb, skewX(−10°)(T4).
const _titleProgressHeight = 5.0;
const _titleProgressStyle = SkewBarStyle(
  trackColor: Color.fromRGBO(255, 255, 255, 0.14),
  radius: 3,
);

/// 초상 stucard 흰 외곽선 1.66px(카드 높이 153.81 기준, T11).
const _titleStucardOutlineFraction = 1.66 / 153.81;

const _titleTexture = BATriangleTextureConfig(
  baseColor: Color(0xb81c2b3b),
  panelColor: Color(0x9931475d),
  softColor: Color(0x889bb3c8),
  accentColor: Color(0x9971c7f4),
  triangleSize: 68,
  tessellationContrast: 0.075,
  randomSeed: 4139,
  macroTriangleChance: 0.12,
  macroTriangleScale: 2.4,
  macroTriangleContrast: 0.05,
  lightStrength: 0.19,
  edgeVignetteStrength: 0.13,
  fogStrength: 0.08,
);

const _actionTexture = BATriangleTextureConfig(
  baseColor: BATrianglePalette.softTitlePinkBase,
  panelColor: BATrianglePalette.softTitlePinkPanel,
  softColor: BATrianglePalette.softTitlePinkSoft,
  accentColor: BATrianglePalette.softTitlePinkAccent,
  triangleSize: 42,
  tessellationContrast: 0.09,
  randomSeed: 2077,
  macroTriangleChance: 0.14,
  macroTriangleScale: 2.2,
  macroTriangleContrast: 0.06,
  lightStrength: 0.22,
  edgeVignetteStrength: 0.12,
  fogStrength: 0.08,
);

enum _InitialAccountAction { create, imported, cancelled }

class TitlePage extends StatefulWidget {
  const TitlePage({
    super.key,
    required this.service,
    this.onExitRequested,
    this.firstRun = FirstRunLaunch.off,
    this.onStartTutorial,
  });

  final AppService service;
  final VoidCallback? onExitRequested;

  /// 첫 실행 ①~③ 모달(F3b). 기본은 띄우지 않는다(실제 앱은 `main.dart`가 켠다).
  final FirstRunLaunch firstRun;

  /// ③에서 계정을 만든 뒤 튜토리얼을 시작한다(F3c). 없으면 홈으로 간다.
  final FirstRunTutorialStarter? onStartTutorial;

  @override
  State<TitlePage> createState() => _TitlePageState();
}

class _TitlePageState extends State<TitlePage>
    with SingleTickerProviderStateMixin {
  final FocusNode _keyboardFocus = FocusNode(debugLabel: 'title-shortcuts');
  late final AnimationController _exitController;
  RepositoryProfile? _profile;
  RepositoryState? _repositoryState;
  final SectionStudioDocument _studioDocument = titleStudioDocument;
  var _totalStudents = 0;
  var _loading = true;
  var _actionRunning = false;
  var _transitioning = false;
  String? _error;

  /// 계정 목록·state를 읽다가 실패했다(이관 실패 포함). 주 버튼은 첫 실행 흐름 대신 다시 읽는다.
  bool _accountLoadFailed = false;
  AccountClusterEntry? _accountClusterEntry;

  /// 첫 실행 모달이 떠 있다(Space 시작을 막는다).
  bool _firstRunOpen = false;
  StudentCatalogEntry? _studentGridWarmupPreview;
  bool _studentGridWarmupActive = false;
  int _studentGridWarmupRequest = 0;
  int _accountLoadGeneration = 0;
  late BackendConnection _lastConnection;

  RepositoryService? get _repository => widget.service is RepositoryService
      ? widget.service as RepositoryService
      : null;

  @override
  void initState() {
    super.initState();
    _exitController = AnimationController(
      vsync: this,
      duration: AppMotion.shell,
    );
    _lastConnection = widget.service.state.value.connection;
    widget.service.state.addListener(_handleConnectionChanged);
    _loadAccount();
  }

  @override
  void didUpdateWidget(covariant TitlePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.service, widget.service)) return;
    oldWidget.service.state.removeListener(_handleConnectionChanged);
    _lastConnection = widget.service.state.value.connection;
    widget.service.state.addListener(_handleConnectionChanged);
    _loadAccount();
  }

  @override
  void dispose() {
    _accountLoadGeneration += 1;
    _studentGridWarmupRequest += 1;
    widget.service.state.removeListener(_handleConnectionChanged);
    _exitController.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  void _handleConnectionChanged() {
    final connection = widget.service.state.value.connection;
    final becameConnected =
        connection == BackendConnection.connected &&
        _lastConnection != BackendConnection.connected;
    _lastConnection = connection;
    if (becameConnected) {
      _loadAccount();
      return;
    }
    if (connection != BackendConnection.connected && _profile == null) {
      _accountLoadGeneration += 1;
      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
    }
  }

  Future<void> _loadAccount() async {
    final generation = ++_accountLoadGeneration;
    if (widget.service.state.value.connection != BackendConnection.connected) {
      if (mounted && generation == _accountLoadGeneration) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
      return;
    }
    if (mounted && !_loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final repository = _repository;
    if (repository == null) {
      if (mounted && generation == _accountLoadGeneration) {
        setState(() {
          _loading = false;
          _error = '계정 저장소를 사용할 수 없습니다.';
        });
      }
      return;
    }
    try {
      final profiles = await repository.listProfiles();
      var selected = profiles.where((item) => item.selected).firstOrNull;
      if (selected == null && profiles.isNotEmpty) {
        // 선택 대상 state를 먼저 읽는다. legacy 프로필은 이 첫 로드에서 활성 문서로 옮겨지며 revision이 오르므로
        // (FB-1b), 목록 revision이 아니라 state가 돌려준 revision으로 고른다.
        final fallback = profiles.first;
        final fallbackState = await loadRepositoryStateRetrying(
          repository,
          fallback.id,
        );
        final revision = await repository.selectProfile(
          fallback.id,
          fallbackState.revision,
          'title-login-${fallback.id}-${fallbackState.revision}',
        );
        selected = RepositoryProfile(
          id: fallback.id,
          displayName: fallback.displayName,
          avatarStudentId: fallback.avatarStudentId,
          revision: revision,
          selected: true,
          isPractice: fallback.isPractice,
        );
      }
      final state = selected == null
          ? null
          : await loadRepositoryStateRetrying(repository, selected.id);
      // state를 읽은 뒤의 revision이 권위값이다(첫 로드 이관으로 목록 값보다 클 수 있다).
      final profile = selected == null || state == null
          ? selected
          : repositoryProfileWithRevision(selected, state.revision);
      if (!mounted || generation != _accountLoadGeneration) return;
      setState(() {
        _profile = profile;
        _repositoryState = state;
        _loading = false;
        _error = null;
        _accountLoadFailed = false;
      });
      unawaited(_loadStudentCatalog(generation));
    } catch (error) {
      if (!mounted || generation != _accountLoadGeneration) return;
      // 이관 실패(legacy_goals_conflict·corrupt_data)는 빈 목표로 열지 않고 문구로 알린다. 계정을 읽지 못한 채로
      // 첫 실행(새 계정·v6 가져오기)으로 넘어가지 않게, 주 버튼은 다시 읽기만 한다.
      setState(() {
        _loading = false;
        _error = repositoryLoadErrorText(error);
        _accountLoadFailed = true;
      });
    }
  }

  Future<void> _loadStudentCatalog(int accountGeneration) async {
    try {
      final catalog = await widget.service.listStudents();
      if (!mounted || accountGeneration != _accountLoadGeneration) return;
      setState(() => _totalStudents = catalog.length);
      _scheduleStudentGridWarmup(catalog);
    } catch (_) {
      // Student catalog warmup is cosmetic and must not block account login.
    }
  }

  void _scheduleStudentGridWarmup(List<StudentCatalogEntry> catalog) {
    final students = studentGridWarmupStudents(catalog);
    if (students.isEmpty) return;
    final request = ++_studentGridWarmupRequest;
    setState(() {
      _studentGridWarmupPreview = students.first;
      _studentGridWarmupActive = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || request != _studentGridWarmupRequest) return;
      await StudentGridImageWarmup.shared.warm(context, students);
      if (!mounted || request != _studentGridWarmupRequest) return;
      setState(() => _studentGridWarmupActive = false);
    });
  }

  void _openShell(AppSection section) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => AppShell(
          service: widget.service,
          initialSection: section,
          animateHomeEntrance: section == AppSection.home,
        ),
      ),
    );
  }

  Future<_InitialAccountAction> _chooseInitialAccountAction() async {
    final repository = _repository;
    if (repository == null) return _InitialAccountAction.create;

    List<RepositoryV6AccountPreview> accounts;
    try {
      accounts = await repository.previewV6Accounts();
    } catch (_) {
      // A missing sibling v6 installation is a normal first-run condition.
      return _InitialAccountAction.create;
    }
    if (!mounted || accounts.isEmpty) return _InitialAccountAction.create;

    final choice = await showDialog<Object>(
      context: context,
      builder: (context) => SimpleDialog(
        key: const ValueKey('title-initial-account-dialog'),
        title: const Text('계정 데이터 선택'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text('v6 원본은 변경하지 않고 새 v7 계정으로 복사합니다.'),
          ),
          SimpleDialogOption(
            key: const ValueKey('title-create-new-account'),
            onPressed: () =>
                Navigator.pop(context, _InitialAccountAction.create),
            child: const ListTile(
              leading: Icon(Icons.person_add_alt_1_outlined),
              title: Text('새 계정 만들기'),
            ),
          ),
          for (final account in accounts)
            SimpleDialogOption(
              key: ValueKey('title-import-v6-${account.sourceProfileKey}'),
              onPressed: () => Navigator.pop(context, account),
              child: ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: Text('${account.displayName} · v6에서 가져오기'),
                subtitle: Text(
                  '학생 ${account.studentCount}명 · 인벤토리 '
                  '${account.inventoryCount}종 · 계획 ${account.goalCount}개',
                ),
              ),
            ),
        ],
      ),
    );
    if (!mounted || choice == null) return _InitialAccountAction.cancelled;
    if (choice == _InitialAccountAction.create) {
      return _InitialAccountAction.create;
    }

    final account = choice as RepositoryV6AccountPreview;
    setState(() {
      _actionRunning = true;
      _error = null;
    });
    try {
      await repository.importV6Account(account.sourceProfileKey);
      return _InitialAccountAction.imported;
    } catch (error) {
      if (mounted) setState(() => _error = 'v6 계정을 가져오지 못했습니다: $error');
      return _InitialAccountAction.cancelled;
    } finally {
      if (mounted) setState(() => _actionRunning = false);
    }
  }

  Future<void> _activatePrimary() async {
    if (_loading ||
        _actionRunning ||
        _transitioning ||
        widget.service.state.value.connection != BackendConnection.connected) {
      return;
    }
    if (_accountLoadFailed) {
      await _loadAccount();
      return;
    }
    var initialAction = _InitialAccountAction.create;
    if (_profile == null) {
      initialAction = await _chooseInitialAccountAction();
      if (!mounted || initialAction == _InitialAccountAction.cancelled) return;
    }
    setState(() => _transitioning = true);
    await _exitController.forward();
    if (!mounted) return;
    if (_profile != null) {
      _openShell(AppSection.home);
      return;
    }
    if (initialAction == _InitialAccountAction.imported) {
      _openShell(AppSection.plan);
      return;
    }
    setState(() {
      _accountClusterEntry = AccountClusterEntry.createFirst;
      _transitioning = false;
    });
  }

  /// F3b ③: 첫 실행에서 만든 계정으로 튜토리얼을 시작한다(F3c 자리). 시작 콜백이 없으면 지금처럼 홈으로 간다.
  void _handleFirstRunAccount(RepositoryProfile account) {
    final startTutorial = widget.onStartTutorial;
    if (startTutorial != null) {
      startTutorial(context, account);
      return;
    }
    _openShell(AppSection.home);
  }

  Future<void> _openAccountManager() async {
    if (_transitioning) return;
    setState(() => _transitioning = true);
    await _exitController.forward();
    if (!mounted) return;
    setState(() {
      _accountClusterEntry = AccountClusterEntry.manage;
      _transitioning = false;
    });
  }

  /// FB-2d: 계정 관리에서 지운 계정이 지금 타이틀에 보이는 계정이면 그 계정 값(프로필·state)만 비운다. 진행 중인
  /// 계정 읽기는 지운 계정을 되살리지 않게 버리고, 타이틀로 돌아올 때 다시 읽는다.
  void _forgetDeletedProfile(String profileId) {
    if (_profile?.id != profileId) return;
    _accountLoadGeneration += 1;
    setState(() {
      _profile = null;
      _repositoryState = null;
    });
  }

  Future<void> _returnFromAccountCluster() async {
    setState(() {
      _accountClusterEntry = null;
      _transitioning = true;
    });
    await _loadAccount();
    if (!mounted) return;
    await _exitController.reverse();
    if (mounted) setState(() => _transitioning = false);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final titleIsActive =
        _accountClusterEntry == null &&
        !_firstRunOpen &&
        !_transitioning &&
        _exitController.isDismissed;
    if (titleIsActive &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.space) {
      _activatePrimary();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final ownedCount = _repositoryState?.students.length ?? 0;
    final portraitStudentId = _profile?.avatarStudentId;
    final studioDocument = _studioDocument;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Focus(
        focusNode: _keyboardFocus,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Stack(
          key: const ValueKey('title-page'),
          children: [
            const Positioned.fill(child: BATriangleBackground()),
            Positioned.fill(
              child: _StudioTitleCanvas(
                document: studioDocument,
                profile: _profile,
                ownedCount: ownedCount,
                totalCount: _totalStudents,
                portraitStudentId: portraitStudentId,
                busy: _loading || _actionRunning,
                exitAnimation: _exitController,
                onPrimary: _activatePrimary,
                onSettings: _openAccountManager,
                onExit:
                    widget.onExitRequested ??
                    () {
                      SystemNavigator.pop();
                    },
              ),
            ),
            if (_studentGridWarmupActive && _studentGridWarmupPreview != null)
              Positioned(
                key: const ValueKey('student-grid-paint-warmup'),
                right: 2,
                bottom: 2,
                child: StudentGridPaintWarmup(
                  student: _studentGridWarmupPreview!,
                ),
              ),
            if (_accountClusterEntry != null)
              Positioned.fill(
                child: AccountSectionCluster(
                  service: widget.service,
                  entry: _accountClusterEntry!,
                  onBackToTitle: _returnFromAccountCluster,
                  onEnterHome: () => _openShell(AppSection.home),
                  onProfileDeleted: _forgetDeletedProfile,
                ),
              ),
            if (widget.firstRun != FirstRunLaunch.off)
              Positioned.fill(
                child: FirstRunGate(
                  service: widget.service,
                  launch: widget.firstRun,
                  hasAccount: _loading || _accountLoadFailed
                      ? null
                      : _profile != null,
                  onOpenChanged: (open) => setState(() => _firstRunOpen = open),
                  onAccountCreated: _handleFirstRunAccount,
                ),
              ),
            if (_error != null)
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: Center(
                  child: Material(
                    color: AppColors.danger.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        '계정 정보를 불러오지 못했습니다: $_error',
                        key: const ValueKey('title-error'),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BrandSection extends StatelessWidget {
  const _BrandSection({required this.onSettings, required this.onExit});

  final VoidCallback onSettings;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => _TitleSurface(
    clipper: const _ParallelogramClipper(),
    texture: _titleTexture,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final buttonHeight = math.max(32.0, constraints.maxHeight * 0.18);
        final buttonWidth = math.max(48.0, constraints.maxWidth * 0.05);
        final bottomGap = constraints.maxHeight * 0.068;
        return Stack(
          children: [
            Positioned.fill(
              child: FractionallySizedBox(
                widthFactor: 0.43,
                alignment: Alignment.center,
                child: GameImage(
                  'assets/studio_features/plan_a_title.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              left: constraints.maxWidth * 0.02,
              bottom: bottomGap,
              width: buttonWidth,
              height: buttonHeight,
              child: _CornerButton(
                key: const ValueKey('title-settings'),
                tooltip: '설정',
                onPressed: onSettings,
                child: const Icon(Icons.settings, size: 20),
              ),
            ),
            Positioned(
              right: constraints.maxWidth * 0.02,
              bottom: bottomGap,
              width: math.max(58.0, buttonWidth),
              height: buttonHeight,
              child: _CornerButton(
                key: const ValueKey('title-exit'),
                tooltip: '나가기',
                onPressed: onExit,
                child: const Text('나가기', maxLines: 1),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _CornerButton extends StatelessWidget {
  const _CornerButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: _TitleSurface(
      clipper: const _ParallelogramClipper(slantFactor: 0.10),
      texture: _actionTexture,
      onTap: onPressed,
      child: Center(child: child),
    ),
  );
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final surfaceHeight = constraints.maxHeight - 24;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: surfaceHeight,
            child: _TitleSurface(
              key: const ValueKey('title-primary-action'),
              clipper: const _ParallelogramClipper(),
              texture: _actionTexture,
              onTap: busy ? null : onPressed,
              child: Center(
                child: busy
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontFamily: 'GyeonggiTitle',
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            top: surfaceHeight - 5,
            left: 0,
            right: 0,
            child: const Center(child: _KeyCap('Space')),
          ),
        ],
      );
    },
  );
}

class _KeyCap extends StatelessWidget {
  const _KeyCap(this.label);

  final String label;

  // T9: 시안 키캡(높이 26, 좌우 12, r5, #0d151f, 안쪽 1px 테두리, Pretendard 13 w700 #dfe7ee). 그림자 없음.
  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('title-space-key'),
    height: _titleKeyCapHeight,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.popover,
        border: Border.all(color: _titleKeyCapBorder),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          widthFactor: 1,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _titleKeyCapText,
              height: 1,
            ),
          ),
        ),
      ),
    ),
  );
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.profileName,
    required this.ownedCount,
    required this.totalCount,
    required this.portraitStudentId,
  });

  final String profileName;
  final int ownedCount;
  final int totalCount;
  final String? portraitStudentId;

  @override
  Widget build(BuildContext context) => _TitleSurface(
    clipper: const _LeftTrapezoidClipper(),
    texture: _titleTexture,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
      child: Row(
        children: [
          Expanded(
            flex: 47,
            child: AspectRatio(
              aspectRatio: 1.4651162790697674,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  GameImage(
                    'assets/studio_features/square.png',
                    fit: BoxFit.contain,
                  ),
                  FractionallySizedBox(
                    widthFactor: 0.98,
                    heightFactor: 0.98,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: portraitStudentId == null
                          ? const _PortraitFallback()
                          : GameImage(
                              'assets/student_portraits/$portraitStudentId.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) =>
                                  const _PortraitFallback(),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 53,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    profileName,
                    key: const ValueKey('title-account-name-label'),
                    style: const TextStyle(
                      fontFamily: 'GyeonggiTitle',
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Divider(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '보유 : $ownedCount/$totalCount',
                    key: const ValueKey('title-owned-count'),
                    style: const TextStyle(
                      fontFamily: 'GyeonggiTitle',
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PortraitFallback extends StatelessWidget {
  const _PortraitFallback();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0x2271c7f4),
    child: Center(
      child: Icon(Icons.person_outline, color: AppColors.primary, size: 38),
    ),
  );
}

class _TitleSurface extends StatelessWidget {
  const _TitleSurface({
    super.key,
    required this.clipper,
    required this.texture,
    required this.child,
    this.onTap,
  });

  final CustomClipper<Path> clipper;
  final BATriangleTextureConfig texture;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _ClippedOutlinePainter(clipper),
    child: ClipPath(
      clipper: clipper,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              BATriangleBackground(config: texture),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}

class _ParallelogramClipper extends CustomClipper<Path> {
  const _ParallelogramClipper({this.slantFactor = 0.12});

  final double slantFactor;

  @override
  Path getClip(Size size) {
    final slant = math.min(size.width * slantFactor, size.height * 0.28);
    return Path()
      ..moveTo(slant, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - slant, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_ParallelogramClipper oldClipper) =>
      oldClipper.slantFactor != slantFactor;
}

class _LeftTrapezoidClipper extends CustomClipper<Path> {
  const _LeftTrapezoidClipper();

  @override
  Path getClip(Size size) {
    final slant = math.min(size.width * 0.08, size.height * 0.28);
    return Path()
      ..moveTo(slant, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_LeftTrapezoidClipper oldClipper) => false;
}

class _ClippedOutlinePainter extends CustomPainter {
  const _ClippedOutlinePainter(this.clipper);

  final CustomClipper<Path> clipper;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      clipper.getClip(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.outline,
    );
  }

  @override
  bool shouldRepaint(_ClippedOutlinePainter oldDelegate) =>
      oldDelegate.clipper != clipper;
}

class _StudioTitleCanvas extends StatelessWidget {
  const _StudioTitleCanvas({
    required this.document,
    required this.profile,
    required this.ownedCount,
    required this.totalCount,
    required this.portraitStudentId,
    required this.busy,
    required this.exitAnimation,
    required this.onPrimary,
    required this.onSettings,
    required this.onExit,
  });

  final SectionStudioDocument document;
  final RepositoryProfile? profile;
  final int ownedCount;
  final int totalCount;
  final String? portraitStudentId;
  final bool busy;
  final Animation<double> exitAnimation;
  final VoidCallback onPrimary;
  final VoidCallback onSettings;
  final VoidCallback onExit;

  SectionCanvasElement _section(String id) =>
      document.elements.singleWhere((item) => item.id == id);

  StudioContainerElement _container(String id) =>
      document.containers.singleWhere((item) => item.id == id);

  StudioFeatureElement _feature(String id) =>
      document.features.singleWhere((item) => item.id == id);

  /// FE8-a: 로고 띠(container-1)와 계정 카드(container-6)는 Studio 컨테이너 polygon을 시안 반경(16)으로
  /// 둥글린다(T3). FE8-b: 버튼(container-2·4·5)은 반경 8이다.
  Path _surfacePath(
    Size size,
    StudioContainerElement container, {
    double radius = _titleSurfaceRadius,
  }) => titleStudioContainerPath(document, size, container.id, radius: radius);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final brand = _section('element-1');
      final primary = _section('element-2');
      final account = _section('element-3');
      final brandRect = sectionCanvasElementRect(size, brand);
      final primaryRect = sectionCanvasElementRect(size, primary);
      final accountRect = sectionCanvasElementRect(size, account);
      // FE8-a: 섹션은 96 grid 정수 칸으로 그림 영역을 덮고, 보이는 표면은 시안 path bounds와 같은 컨테이너다.
      final bandPath = _surfacePath(size, _container('container-1'));
      final accountCardPath = _surfacePath(size, _container('container-6'));
      final settings = _container('container-4');
      final exit = _container('container-5');
      final primaryContainer = _container('container-2');
      final settingsPath = _surfacePath(
        size,
        settings,
        radius: titleButtonRadius,
      );
      final exitPath = _surfacePath(size, exit, radius: titleButtonRadius);
      final primaryContainerPath = _surfacePath(
        size,
        primaryContainer,
        radius: titleButtonRadius,
      );

      final titleFeature = _feature('feature-1');
      final titleRect = studioFeatureRect(
        size,
        document.elements,
        document.containers,
        titleFeature,
      )!;
      final primaryBounds = primaryContainerPath.getBounds();
      return AnimatedBuilder(
        animation: exitAnimation,
        builder: (context, _) => Stack(
          children: [
            _DirectionalTitleExit(
              motionKey: 'brand',
              progress: exitAnimation.value,
              degrees: 270,
              size: size,
              child: Stack(
                children: [
                  LiftedPathShadow(
                    key: const ValueKey('title-brand-section-shadow'),
                    path: bandPath,
                  ),
                  _StudioPathSurface(
                    key: const ValueKey('title-brand-glass'),
                    path: bandPath,
                    color: _titleBrandFill,
                  ),
                  Positioned.fill(
                    key: const ValueKey('title-brand-glow'),
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _TitleBandGlowPainter(bandPath),
                      ),
                    ),
                  ),
                  _StudioPathSurface(
                    path: settingsPath,
                    texture: _actionTexture,
                  ),
                  _StudioPathSurface(path: exitPath, texture: _actionTexture),
                  // FE8-b: 설정·나가기 외곽선(시안 rgba(56,81,107,.72) 1.8px).
                  for (final (key, path) in [
                    ('title-settings-outline', settingsPath),
                    ('title-exit-outline', exitPath),
                  ])
                    Positioned.fill(
                      key: ValueKey(key),
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _TitlePathOutlinePainter(
                            path: path,
                            color: _titleCornerOutline,
                            strokeWidth: _titleCornerOutlineWidth,
                          ),
                        ),
                      ),
                    ),
                  _positionedMarker('title-brand-section', brandRect),
                  _positionedContent(
                    titleRect,
                    GameImage(
                      titleFeature.imageAsset!,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  // T7: 시안 톱니 아이콘(24, stroke 2.1)과 의미 라벨 `계정 관리`.
                  _positionedPathAction(
                    'title-settings',
                    settingsPath,
                    onSettings,
                    const Padding(
                      padding: EdgeInsets.all(2),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox.square(
                            key: ValueKey('title-settings-gear'),
                            dimension: 24,
                            child: CustomPaint(painter: _TitleGearPainter()),
                          ),
                        ),
                      ),
                    ),
                    semanticLabel: '계정 관리',
                  ),
                  _positionedPathAction(
                    'title-exit',
                    exitPath,
                    onExit,
                    // FE8-b: `나가기` 15px w700 흰색(시안).
                    const Padding(
                      padding: EdgeInsets.all(2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '나가기',
                          key: ValueKey('title-exit-label'),
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            fontFamilyFallback: AppFonts.fallback,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _DirectionalTitleExit(
              motionKey: 'primary',
              progress: exitAnimation.value,
              degrees: 270,
              size: size,
              child: Stack(
                children: [
                  LiftedPathShadow(
                    key: const ValueKey('title-primary-section-shadow'),
                    path: primaryContainerPath,
                  ),
                  // The Studio container is the complete visible surface for this
                  // section. Painting the translucent parent section underneath it
                  // changes the texture's intended colors through alpha blending.
                  _StudioPathSurface(
                    key: const ValueKey('title-primary-texture'),
                    path: primaryContainerPath,
                    texture: titlePrimaryActionTexture,
                  ),
                  // T8: 분홍 외곽선.
                  Positioned.fill(
                    key: const ValueKey('title-primary-outline'),
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _TitlePathOutlinePainter(
                          path: primaryContainerPath,
                          color: _titlePrimaryOutline,
                          strokeWidth: _titlePrimaryOutlineWidth,
                        ),
                      ),
                    ),
                  ),
                  _positionedMarker('title-primary-position', primaryRect),
                  _positionedPathAction(
                    'title-primary-action',
                    primaryContainerPath,
                    busy ? null : onPrimary,
                    busy
                        ? const Padding(
                            padding: EdgeInsets.all(4),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(3),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              // T8: 라벨 34px, 경기천년제목 700(시안 `.dsp` + font-weight 700).
                              child: Text(
                                profile == null ? '계정 생성' : '시작',
                                style: const TextStyle(
                                  fontFamily: AppFonts.display,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.34,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                  ),
                  // T9: 키캡은 버튼 path 아래 14px에 띄운다.
                  Positioned(
                    left: primaryBounds.left,
                    width: primaryBounds.width,
                    top: primaryBounds.bottom + _titleKeyCapGap,
                    child: const Center(child: _KeyCap('Space')),
                  ),
                ],
              ),
            ),
            if (profile != null)
              _DirectionalTitleExit(
                motionKey: 'account',
                progress: exitAnimation.value,
                degrees: 90,
                size: size,
                child: Stack(
                  children: [
                    LiftedPathShadow(
                      key: const ValueKey('title-account-section-shadow'),
                      path: accountCardPath,
                    ),
                    // T11: 시안에 삼각 무늬 컨테이너가 없다. 카드 표면은 한 겹이다.
                    // FE8-b: 채움 .9 + 외곽선 rgba(56,81,107,.6) 1.2px(시안).
                    _StudioPathSurface(
                      key: const ValueKey('title-account-glass'),
                      path: accountCardPath,
                      color: titleAccountCardFill,
                    ),
                    Positioned.fill(
                      key: const ValueKey('title-account-outline'),
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _TitlePathOutlinePainter(
                            path: accountCardPath,
                            color: _titleAccountCardOutline,
                            strokeWidth: _titleAccountCardOutlineWidth,
                          ),
                        ),
                      ),
                    ),
                    _positionedMarker('title-account-section', accountRect),
                    // T6: 카드 전체가 `계정 관리 열기` 버튼이다. 내용은 IgnorePointer라 탭이 이 path로 온다.
                    _positionedPathAction(
                      'title-account-card',
                      accountCardPath,
                      onSettings,
                      const SizedBox.shrink(),
                      semanticLabel: '계정 관리 열기',
                    ),
                    ..._accountFeatures(size),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );

  List<Widget> _accountFeatures(Size size) {
    final portrait = _feature('feature-3');
    final name = _feature('feature-4');
    final owned = _feature('feature-5');
    final progress = _feature('feature-6');
    Rect featureRect(StudioFeatureElement feature) => studioFeatureRect(
      size,
      document.elements,
      document.containers,
      feature,
    )!;
    // 이름·막대·보유 줄은 같은 왼쪽 비율을 저장 문서에 둔다(진행 막대 왼쪽 끝이 공통 기준).
    final progressRect = featureRect(progress);
    final nameRect = featureRect(name);
    final ownedRect = featureRect(owned);
    final totalKnown = totalCount > 0;
    // 전체 학생 수를 모르면(카탈로그 읽기 전·실패) 비율을 0으로 만들지 않고 빗금·'—'로 둔다.
    final ownedFraction = totalKnown
        ? (ownedCount / totalCount).clamp(0.0, 1.0).toDouble()
        : null;
    const mutedStyle = TextStyle(
      fontFamily: AppFonts.body,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.textMuted,
    );

    return [
      // T11: 학생 카드와 같은 평행사변형 stucard(square.png 테두리 잘라 채움 + 초상 98%, 흰 1.66px 외곽선).
      _positionedContent(
        featureRect(portrait),
        AssetImageGrid(
          key: const ValueKey('title-account-image-grid'),
          items: [
            AssetImageGridItem(
              asset: portrait.imageAsset!,
              column: 0,
              row: 0,
              edgeCropFraction: 0.11,
              clipPathBuilder: studentGridCardPath,
              outlineColor: Colors.white,
              outlineWidthFraction: _titleStucardOutlineFraction,
            ),
            if (portraitStudentId != null)
              AssetImageGridItem(
                asset: 'assets/student_portraits/$portraitStudentId.png',
                column: 0,
                row: 0,
                scale: 0.98,
                clipRadiusFraction: 0.12,
                alphaThreshold: 0.04,
              ),
          ],
        ),
      ),
      _positionedContent(
        nameRect,
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            profile!.displayName,
            key: const ValueKey('title-account-name-label'),
            style: const TextStyle(
              fontFamily: AppFonts.display,
              fontSize: 22,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.22,
              color: AppColors.text,
            ),
          ),
        ),
      ),
      // T4: 구분선 대신 보유율 진행 막대(300×5, −10°). 높이 5는 창 크기와 상관없이 feature 중심에 둔다.
      _positionedContent(
        Rect.fromCenter(
          center: progressRect.center,
          width: progressRect.width,
          height: _titleProgressHeight,
        ),
        SkewBar(
          key: const ValueKey('title-account-progress'),
          fraction: ownedFraction,
          color: AppColors.text,
          height: _titleProgressHeight,
          style: _titleProgressStyle,
        ),
      ),
      // T5: `보유` 13 muted · 보유 수 경기천년제목 20 w800 · `/ 전체` 13 muted, 기준선 정렬, 간격 8.
      _positionedContent(
        ownedRect,
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            key: const ValueKey('title-owned-count'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('보유', style: mutedStyle),
              const SizedBox(width: 8),
              Text(
                '$ownedCount',
                key: const ValueKey('title-owned-value'),
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '/ ${totalKnown ? totalCount : '—'}',
                key: const ValueKey('title-owned-total'),
                style: mutedStyle,
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

/// 타이틀 Studio 컨테이너 [containerId]의 표면 path: 컨테이너 polygon을 [radius]로 둥글리고 부모 섹션과
/// 교차한다([buildStudioContainerPath]와 같은 다각형, 반경만 다르다). FE8-a 로고 띠·계정 카드(16), FE8-b 버튼(8).
Path titleStudioContainerPath(
  SectionStudioDocument document,
  Size size,
  String containerId, {
  required double radius,
}) {
  final container = document.containers.singleWhere(
    (item) => item.id == containerId,
  );
  final rect = studioContainerRect(size, document.elements, container)!;
  final points = buildAttachedSectionPolygon(
    rect.size,
    container.spec,
    gridSize: sectionTemplateDetailGridSize,
  ).map((point) => point + rect.topLeft).toList(growable: false);
  return Path.combine(
    PathOperation.intersect,
    buildRoundedSectionPolygon(points, radius: radius),
    buildSectionCanvasElementPath(
      size,
      document.elements.singleWhere(
        (item) => item.id == container.parentSectionId,
      ),
    ),
  );
}

Widget _positionedMarker(String key, Rect rect) => Positioned.fromRect(
  key: ValueKey(key),
  rect: rect,
  child: const IgnorePointer(),
);

Widget _positionedContent(Rect rect, Widget child) => Positioned.fromRect(
  rect: rect,
  child: IgnorePointer(child: child),
);

Widget _positionedPathAction(
  String key,
  Path path,
  VoidCallback? onTap,
  Widget child, {
  String? semanticLabel,
}) {
  final bounds = path.getBounds();
  final localPath = path.shift(-bounds.topLeft);
  final action = InkWell(onTap: onTap, child: child);
  return Positioned.fromRect(
    key: ValueKey(key),
    rect: bounds,
    child: ClipPath(
      clipper: _FixedStudioPathClipper(localPath),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: semanticLabel == null
            ? action
            : Semantics(button: true, label: semanticLabel, child: action),
      ),
    ),
  );
}

class _DirectionalTitleExit extends StatelessWidget {
  const _DirectionalTitleExit({
    required this.motionKey,
    required this.progress,
    required this.degrees,
    required this.size,
    required this.child,
  });

  final String motionKey;
  final double progress;
  final double degrees;
  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final eased = AppMotion.sectionCurve.transform(progress);
    final radians = degrees * math.pi / 180;
    final distance = math.max(size.width, size.height) * 1.12;
    return Transform.translate(
      key: ValueKey('title-exit-motion-$motionKey'),
      offset: Offset(
        math.cos(radians) * distance * eased,
        -math.sin(radians) * distance * eased,
      ),
      child: child,
    );
  }
}

class _StudioPathSurface extends StatelessWidget {
  const _StudioPathSurface({
    super.key,
    required this.path,
    this.texture,
    this.color,
  });

  final Path path;
  final BATriangleTextureConfig? texture;

  /// 텍스처가 없을 때의 채움. 없으면 공용 섹션 표면색이다(로고 띠만 시안 .93, T10).
  final Color? color;

  // FE1-c: 텍스처가 없는 섹션 바탕은 공용 섹션 표면(surface@.76, 블러 없음)이다.
  // 그림자는 화면이 따로 그리는 LiftedPathShadow가 맡는다. 텍스처 표면(FD-015)은 그대로 둔다.
  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: _FixedStudioPathClipper(path),
    clipBehavior: Clip.antiAlias,
    child: texture == null
        ? ColoredBox(
            color: color ?? sectionSurfaceColor,
            child: const SizedBox.expand(),
          )
        : BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Material(
              color: Colors.transparent,
              child: BATriangleBackground(config: texture!),
            ),
          ),
  );
}

class _FixedStudioPathClipper extends CustomClipper<Path> {
  const _FixedStudioPathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_FixedStudioPathClipper oldClipper) =>
      oldClipper.path != path;
}

/// T10: 로고 띠 분홍 radial glow. CSS `radial-gradient(60% 90% at 50% 45%, …, transparent 70%)`처럼
/// 띠 bounds 기준 가로 반지름 60%·세로 반지름 90%의 타원을 띠 path 안에만 칠한다.
class _TitleBandGlowPainter extends CustomPainter {
  const _TitleBandGlowPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = path.getBounds();
    if (bounds.isEmpty) return;
    canvas.save();
    canvas.clipPath(path);
    canvas.translate(
      bounds.left + bounds.width * 0.5,
      bounds.top + bounds.height * 0.45,
    );
    canvas.scale(bounds.width * 0.6, bounds.height * 0.9);
    canvas.drawRect(
      const Rect.fromLTRB(-2, -2, 2, 2),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          1,
          const [_titleBrandGlow, _titleBrandGlowClear],
          const [0, 0.7],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TitleBandGlowPainter oldDelegate) =>
      oldDelegate.path != path;
}

/// 버튼 path 외곽선(T8 시작 버튼 분홍 1.8px).
class _TitlePathOutlinePainter extends CustomPainter {
  const _TitlePathOutlinePainter({
    required this.path,
    required this.color,
    required this.strokeWidth,
  });

  final Path path;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = strokeWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_TitlePathOutlinePainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// T7: 시안 설정 버튼 톱니(viewBox 24, 원 r3 + 바퀴살 8개, stroke 2.1, round).
class _TitleGearPainter extends CustomPainter {
  const _TitleGearPainter();

  static final Path _spokes = Path()
    ..moveTo(12, 2)
    ..lineTo(12, 5)
    ..moveTo(12, 19)
    ..lineTo(12, 22)
    ..moveTo(4.2, 4.2)
    ..lineTo(6.3, 6.3)
    ..moveTo(17.7, 17.7)
    ..lineTo(19.8, 19.8)
    ..moveTo(2, 12)
    ..lineTo(5, 12)
    ..moveTo(19, 12)
    ..lineTo(22, 12)
    ..moveTo(4.2, 19.8)
    ..lineTo(6.3, 17.7)
    ..moveTo(17.7, 6.3)
    ..lineTo(19.8, 4.2);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;
    canvas.save();
    canvas.scale(scale);
    canvas.drawCircle(const Offset(12, 12), 3, paint);
    canvas.drawPath(_spokes, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TitleGearPainter oldDelegate) => false;
}
