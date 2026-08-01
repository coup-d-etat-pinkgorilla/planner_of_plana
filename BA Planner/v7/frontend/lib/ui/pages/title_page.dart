// ignore_for_file: unused_element

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../app_section.dart';
import '../app_shell.dart';
import '../studio/section_studio_document.dart';
import '../studio/section_template.dart';
import '../studio/title_studio_layout.dart';
import '../widgets/asset_image_grid.dart';
import '../widgets/account_section_cluster.dart';
import '../widgets/ba_triangle_background.dart';
import '../widgets/lifted_path_shadow.dart';
import '../widgets/section_template_surface.dart';
import '../widgets/student_grid_warmup.dart';

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

const _primaryActionTexture = BATriangleTextureConfig(
  baseColor: BATrianglePalette.softTitlePinkBase,
  panelColor: BATrianglePalette.softTitlePinkPanel,
  softColor: BATrianglePalette.softTitlePinkSoft,
  accentColor: BATrianglePalette.softTitlePinkAccent,
  triangleSize: 105,
  tessellationContrast: 0.09,
  randomSeed: 2077,
  macroTriangleChance: 0.14,
  macroTriangleScale: 2.2,
  macroTriangleContrast: 0.06,
  lightStrength: 0.22,
  edgeVignetteStrength: 0.12,
  fogStrength: 0.08,
);

class TitlePage extends StatefulWidget {
  const TitlePage({super.key, required this.service, this.onExitRequested});

  final AppService service;
  final VoidCallback? onExitRequested;

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
  AccountClusterEntry? _accountClusterEntry;
  StudentCatalogEntry? _studentGridWarmupPreview;
  bool _studentGridWarmupActive = false;
  int _studentGridWarmupRequest = 0;

  RepositoryService? get _repository => widget.service is RepositoryService
      ? widget.service as RepositoryService
      : null;

  @override
  void initState() {
    super.initState();
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _loadAccount();
  }

  @override
  void dispose() {
    _studentGridWarmupRequest += 1;
    _exitController.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    final repository = _repository;
    if (repository == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '계정 저장소를 사용할 수 없습니다.';
        });
      }
      return;
    }
    try {
      final results = await Future.wait<Object>([
        repository.listProfiles(),
        widget.service.listStudents(),
      ]);
      final profiles = results[0] as List<RepositoryProfile>;
      final catalog = results[1] as List<StudentCatalogEntry>;
      var selected = profiles.where((item) => item.selected).firstOrNull;
      if (selected == null && profiles.isNotEmpty) {
        final fallback = profiles.first;
        final revision = await repository.selectProfile(
          fallback.id,
          fallback.revision,
          'title-login-${fallback.id}-${fallback.revision}',
        );
        selected = RepositoryProfile(
          id: fallback.id,
          displayName: fallback.displayName,
          avatarStudentId: fallback.avatarStudentId,
          revision: revision,
          selected: true,
        );
      }
      final state = selected == null
          ? null
          : await repository.loadRepositoryState(selected.id);
      if (!mounted) return;
      setState(() {
        _profile = selected;
        _repositoryState = state;
        _totalStudents = catalog.length;
        _loading = false;
        _error = null;
      });
      _scheduleStudentGridWarmup(catalog);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
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

  Future<void> _activatePrimary() async {
    if (_loading || _actionRunning || _transitioning) return;
    setState(() => _transitioning = true);
    await _exitController.forward();
    if (!mounted) return;
    if (_profile != null) {
      _openShell(AppSection.home);
      return;
    }
    setState(() {
      _accountClusterEntry = AccountClusterEntry.createFirst;
      _transitioning = false;
    });
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

  Future<void> _createAccount() async {
    final repository = _repository;
    if (repository == null) return;
    var accountName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('title-account-dialog'),
        title: const Text('계정 생성'),
        content: TextFormField(
          key: const ValueKey('title-account-name'),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '계정 이름',
            hintText: '예: 메인 계정',
          ),
          onChanged: (value) => accountName = value.trim(),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (value) =>
              Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, accountName),
            child: const Text('생성'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    setState(() {
      _actionRunning = true;
      _error = null;
    });
    try {
      final created = await repository.createProfile(
        name,
        'title-create-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!created.selected) {
        await repository.selectProfile(
          created.id,
          created.revision,
          'title-select-${created.id}-${created.revision}',
        );
      }
      if (mounted) _openShell(AppSection.home);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _actionRunning = false);
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final titleIsActive =
        _accountClusterEntry == null &&
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
                child: Image.asset(
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

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('title-space-key'),
    padding: const EdgeInsets.fromLTRB(8, 3, 8, 2),
    decoration: BoxDecoration(
      color: const Color(0xff263a52),
      border: Border.all(color: Colors.white70),
      borderRadius: BorderRadius.circular(3),
      boxShadow: const [
        BoxShadow(color: Colors.black45, offset: Offset(1, 2), blurRadius: 2),
      ],
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontFamily: 'GyeonggiTitle',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white,
        height: 1,
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
                  Image.asset(
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
                          : Image.asset(
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
      final brandPath = buildSectionCanvasElementPath(size, brand);
      final accountPath = buildSectionCanvasElementPath(size, account);
      final settings = _container('container-4');
      final exit = _container('container-5');
      final primaryContainer = _container('container-2');
      final accountContainer = _container('container-6');
      final settingsPath = buildStudioContainerPath(
        size,
        document.elements,
        settings,
      )!;
      final exitPath = buildStudioContainerPath(size, document.elements, exit)!;
      final primaryContainerPath = buildStudioContainerPath(
        size,
        document.elements,
        primaryContainer,
      )!;
      final accountContainerPath = buildStudioContainerPath(
        size,
        document.elements,
        accountContainer,
      )!;

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
                    path: brandPath,
                  ),
                  _StudioPathSurface(
                    key: const ValueKey('title-brand-glass'),
                    path: brandPath,
                  ),
                  _StudioPathSurface(
                    path: settingsPath,
                    texture: _actionTexture,
                  ),
                  _StudioPathSurface(path: exitPath, texture: _actionTexture),
                  _positionedMarker('title-brand-section', brandRect),
                  _positionedContent(
                    titleRect,
                    Image.asset(
                      titleFeature.imageAsset!,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  _positionedPathAction(
                    'title-settings',
                    settingsPath,
                    onSettings,
                    const Padding(
                      padding: EdgeInsets.all(2),
                      child: FittedBox(child: Icon(Icons.settings)),
                    ),
                  ),
                  _positionedPathAction(
                    'title-exit',
                    exitPath,
                    onExit,
                    const Padding(
                      padding: EdgeInsets.all(2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('나가기', maxLines: 1),
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
                    texture: _primaryActionTexture,
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
                              child: Text(
                                profile == null ? '계정 생성' : '시작',
                                style: const TextStyle(
                                  fontFamily: 'GyeonggiTitle',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    left: primaryBounds.left,
                    width: primaryBounds.width,
                    top: primaryRect.bottom - 5,
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
                      path: accountPath,
                    ),
                    _StudioPathSurface(
                      key: const ValueKey('title-account-glass'),
                      path: accountPath,
                    ),
                    _StudioPathSurface(
                      path: accountContainerPath,
                      texture: _titleTexture,
                    ),
                    _positionedMarker('title-account-section', accountRect),
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
    final divider = _feature('feature-6');
    Rect currentRect(StudioFeatureElement feature) => studioFeatureRect(
      size,
      document.elements,
      document.containers,
      feature,
    )!;
    final accountSectionRect = sectionCanvasElementRect(
      size,
      _section('element-3'),
    );
    final originalTextContainerRect = studioPlacementRectWithin(
      accountSectionRect,
      const StudioPlacementRect(
        0.024340827418844465,
        0.04688686894940833,
        0.9528637057705781,
        0.9153365525292749,
      ),
    );
    Rect originalRect(StudioFeatureElement feature) =>
        studioPlacementRectWithin(originalTextContainerRect, feature.rect);
    final dividerRect = originalRect(divider);
    final originalNameRect = originalRect(name);
    final originalOwnedRect = originalRect(owned);
    final nameRect = Rect.fromLTRB(
      dividerRect.left,
      originalNameRect.top,
      originalNameRect.right,
      originalNameRect.bottom,
    );
    final ownedRect = Rect.fromLTRB(
      dividerRect.left,
      originalOwnedRect.top,
      originalOwnedRect.right,
      originalOwnedRect.bottom,
    );

    return [
      _positionedContent(
        currentRect(portrait),
        AssetImageGrid(
          key: const ValueKey('title-account-image-grid'),
          items: [
            AssetImageGridItem(asset: portrait.imageAsset!, column: 0, row: 0),
            if (portraitStudentId != null)
              AssetImageGridItem(
                asset: 'assets/student_portraits/$portraitStudentId.png',
                column: 0,
                row: 0,
                scale: 0.98,
                clipRadiusFraction: 0.12,
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
              fontFamily: 'GyeonggiTitle',
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      _positionedContent(
        ownedRect,
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
      ),
      _positionedContent(
        dividerRect,
        Center(
          child: Container(
            key: const ValueKey('title-account-divider'),
            width: double.infinity,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.text,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    ];
  }
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
  Widget child,
) {
  final bounds = path.getBounds();
  final localPath = path.shift(-bounds.topLeft);
  return Positioned.fromRect(
    key: ValueKey(key),
    rect: bounds,
    child: ClipPath(
      clipper: _FixedStudioPathClipper(localPath),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: child),
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
    final eased = Curves.easeInOutCubic.transform(progress);
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
  const _StudioPathSurface({super.key, required this.path, this.texture});

  final Path path;
  final BATriangleTextureConfig? texture;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: _FixedStudioPathClipper(path),
    clipBehavior: Clip.antiAlias,
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Material(
        color: Colors.transparent,
        child: texture == null
            ? ColoredBox(
                color: AppColors.surface.withValues(alpha: 0.78),
                child: const SizedBox.expand(),
              )
            : BATriangleBackground(config: texture!),
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
