import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/scanner_service.dart';
import '../app_section.dart';
import '../home/connect_target_panel.dart';
import '../home/home_menu_swap.dart';
import '../home/home_scan_popup.dart';
import '../kit/ba_modal.dart' show BaScrim;
import '../kit/game_image.dart';
import '../kit/kit_overlay.dart' show KitOverlayEscape;
import '../scan/connected_target_controller.dart';
import '../scan/scan_pick_logic.dart' show ScanStartBlock, scanStartNote;
import '../scan/scan_session_controller.dart';
import '../widgets/ba_triangle_background.dart';
import '../widgets/diagonal_menu.dart';
import '../widgets/animated_section_stack.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.service,
    required this.onOpen,
    this.reloadToken = 0,
    this.recentScans = const [],
    this.entranceAnimation = const AlwaysStoppedAnimation(1),
    this.connectedTarget,
    this.openTargetPickerRequest = 0,
    this.scanSession,
    this.scanAppliedElsewhere = const {},
  });

  static const menuSectionMaxSize = Size(742, 1018);
  static const shortageLimit = 5;

  final AppService service;
  final ValueChanged<AppSection> onOpen;
  final int reloadToken;
  final List<ScannerRecentSummary> recentScans;
  final Animation<double> entranceAnimation;

  /// 셸의 앱 전역 게임 창 연결(FE8-d). 없으면(단독 화면 테스트) 첫 버튼은 예전처럼 스캔 탭으로 간다.
  final ConnectedTargetController? connectedTarget;

  /// 셸이 창 선택 패널을 열어 달라고 할 때 올리는 값(머리글 칩, FE8-e).
  final int openTargetPickerRequest;

  /// 셸 소유 스캔 세션(FE8-f1). 있으면 연결된 `스캔`이 스캔 팝업을 열고 타일이 이 세션으로 바로 시작한다(FE8-f3,
  /// FD-140 (a)). 없으면(단독 화면 테스트) 예전처럼 스캔 탭으로 간다.
  final ScanSessionController? scanSession;

  /// 다른 탭(학생 · 인벤토리)에서 적용한 스캔 후보(FE8-f2). 팝업의 검토 대기 판정에서 뺀다.
  final Set<String> scanAppliedElsewhere;

  /// 첫 버튼: 미연결이면 창 선택 패널을 여는 `싯딤의 상자와 연결`(A), 연결되면 스캔 팝업을 여는 `스캔`(B,
  /// Home-Connect-Effect · Home-Connected-Scan).
  static const _featured = _HomeCardData(
    AppSection.scan,
    '싯딤의 상자와 연결',
    'shittim.png',
  );
  static const _featuredConnected = _HomeCardData(
    AppSection.scan,
    '스캔',
    'scan.png',
  );
  static const _compactCards = <_HomeCardData>[
    _HomeCardData(AppSection.students, '학생부 확인', 'students.png'),
    _HomeCardData(AppSection.plan, '계획 설정', 'plan.png'),
    _HomeCardData(AppSection.inventory, '인벤토리', 'inventory.png'),
  ];
  static const _wideCards = <_HomeCardData>[
    _HomeCardData(AppSection.pvp, '전술대항전', 'pvp.png'),
    _HomeCardData(AppSection.statistics, '통계', 'statistics.png'),
  ];
  static const _settings = _HomeCardData(
    AppSection.settings,
    '설정',
    'scan.png',
    triangleOnly: true,
  );

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  /// 패널 intro(180°)·outro(0°) 거리(설계 px, 시안 `hmPanel` translateX 820).
  static const _panelTravel = HomeMenuSwapTimeline.panelExitDistance;

  late final AnimationController _panelController = AnimationController(
    vsync: this,
    duration: AppMotion.section,
  )..addStatusListener(_panelStatusChanged);
  late final AnimationController _swapController = AnimationController(
    vsync: this,
  )..addStatusListener(_swapStatusChanged);

  /// 메뉴가 지금 보이는(안착한) 상태. 연결 상태와 다르면 교체 연출을 시작한다.
  late bool _menuConnected;
  HomeMenuSwapTimeline? _timeline;
  bool _swapTarget = false;
  bool _panelVisible = false;

  /// 연결 연출이 열린 패널을 함께 내보내는 중(시안 `hmPanel`).
  bool _panelExitingWithSwap = false;

  ConnectedTargetController? _controller;

  bool get _connected => _controller?.isConnected ?? false;

  /// 스캔 팝업(FE8-f3, 시안 Home-Connected-Scan). 열고 닫을 때 페이드 + 살짝 커짐(시안에 연출 없음 — 공용 섹션 모션).
  late final AnimationController _popupController = AnimationController(
    vsync: this,
    duration: AppMotion.section,
  )..addStatusListener(_popupStatusChanged);
  bool _popupVisible = false;

  /// 열 때마다 올린다. 타일 그림(시안 무작위)을 고르는 씨앗이다.
  int _popupSeed = 0;

  /// 마지막으로 누른 타일이 막힌 이유(FE8-g1 시작 판정 글자).
  String? _popupNote;

  @override
  void initState() {
    super.initState();
    _bind(widget.connectedTarget);
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.connectedTarget, widget.connectedTarget)) {
      _controller?.removeListener(_connectionChanged);
      _swapController.stop();
      _timeline = null;
      _panelExitingWithSwap = false;
      _bind(widget.connectedTarget);
    }
    if (!identical(oldWidget.scanSession, widget.scanSession)) {
      _hidePopup();
    }
    if (oldWidget.openTargetPickerRequest != widget.openTargetPickerRequest) {
      // didUpdateWidget 뒤에는 어차피 build가 돈다.
      _hidePopup();
      _openPanel(rebuilding: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 다른 탭으로 가면(셸 Offstage · TickerMode off) 팝업을 닫는다. 돌아와도 다시 열리지 않는다.
    if (!TickerMode.valuesOf(context).enabled) _hidePopup();
  }

  void _bind(ConnectedTargetController? controller) {
    _controller = controller;
    controller?.addListener(_connectionChanged);
    _menuConnected = _connected;
  }

  @override
  void dispose() {
    _controller?.removeListener(_connectionChanged);
    KitOverlayEscape.remove(this);
    _popupController.dispose();
    _panelController.dispose();
    _swapController.dispose();
    super.dispose();
  }

  void _connectionChanged() {
    // 연결이 끊기면 팝업을 닫는다(메뉴는 해제 연출로 A가 된다).
    if (!_connected) _closePopup();
    // 연출 중에 다시 바뀌면 지금 연출이 끝난 뒤 이어서 맞춘다.
    if (_timeline == null) _startSwapIfNeeded();
  }

  void _startSwapIfNeeded() {
    final connected = _connected;
    if (!mounted || connected == _menuConnected) return;
    final timeline = connected
        ? HomeMenuSwapTimeline.connect
        : HomeMenuSwapTimeline.release;
    setState(() {
      _timeline = timeline;
      _swapTarget = connected;
      _panelExitingWithSwap = timeline.movesPanel && _panelVisible;
    });
    _swapController
      ..duration = timeline.total
      ..forward(from: 0);
  }

  void _swapStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || _timeline == null) return;
    setState(() {
      _menuConnected = _swapTarget;
      _timeline = null;
      if (_panelExitingWithSwap) {
        _panelExitingWithSwap = false;
        _panelVisible = false;
        _panelController.value = 0;
      }
    });
    _startSwapIfNeeded();
  }

  void _panelStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _panelVisible && mounted) {
      setState(() => _panelVisible = false);
    }
  }

  void _openPanel({bool rebuilding = false}) {
    if (_controller == null || _panelExitingWithSwap) return;
    if (!_panelVisible) {
      if (rebuilding) {
        _panelVisible = true;
      } else {
        setState(() => _panelVisible = true);
      }
    }
    _panelController.forward();
  }

  void _closePanel() {
    if (!_panelVisible || _panelExitingWithSwap) return;
    _panelController.reverse();
  }

  void _openFeatured() {
    if (_controller != null && !_connected) {
      _openPanel();
      return;
    }
    if (_controller == null || widget.scanSession == null) {
      // 셸 연결 · 스캔 세션이 없으면(단독 화면 테스트) 스캔 탭으로 간다.
      widget.onOpen(AppSection.scan);
      return;
    }
    _openPopup();
  }

  // ---- 스캔 팝업(FE8-f3) ----

  void _openPopup() {
    final scan = widget.scanSession;
    if (scan == null || _panelExitingWithSwap) return;
    // 스캔 탭이 아직 붙지 않았어도 준비 상태(창 · 인식 준비 · 계정)를 읽게 한다. 두 번째부터는 아무것도 하지 않는다.
    scan.ensureStarted();
    setState(() {
      _popupVisible = true;
      _popupSeed += 1;
      _popupNote = null;
    });
    _popupController.forward(from: 0);
    KitOverlayEscape.push(this, context, _closePopup);
  }

  void _closePopup() {
    KitOverlayEscape.remove(this);
    if (!_popupVisible) return;
    _popupController.reverse();
  }

  /// 연출 없이 바로 닫는다(탭 이동 · 셸 요청 · 세션 교체). build 전에 부르므로 setState를 쓰지 않는다.
  void _hidePopup() {
    KitOverlayEscape.remove(this);
    _popupVisible = false;
    _popupNote = null;
  }

  void _popupStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && _popupVisible && mounted) {
      setState(() => _popupVisible = false);
    }
  }

  /// 타일 누름(FD-140 (a) · FD-150 (b)): 학생은 홈에 머문 채 백그라운드로, 아이템 · 선물은 컨트롤러의 시작 동작
  /// 그대로 시작한다. 전술대항전은 탭 이동, 미연결은 창 선택 패널(FE8-e), 막혔으면 이유를 팝업에 쓴다.
  void _pressTile(HomeScanTile tile) {
    final scan = widget.scanSession;
    if (scan == null) return;
    if (tile is HomeScanTacticalTile) {
      _closePopup();
      widget.onOpen(AppSection.pvp);
      return;
    }
    if (!_connected) {
      _closePopup();
      _openPanel();
      return;
    }
    final block = homeScanStartTile(scan, tile);
    switch (block) {
      case ScanStartBlock.none:
        _closePopup();
      case ScanStartBlock.noTarget:
        _closePopup();
        _openPanel();
      default:
        setState(() => _popupNote = scanStartNote(block, scan));
    }
  }

  void _reselectTarget() {
    _closePopup();
    _openPanel();
  }

  void _openScanTab() {
    _closePopup();
    widget.onOpen(AppSection.scan);
  }

  void _useTarget(ScannerTarget target) {
    final controller = _controller;
    if (controller == null) return;
    final wasConnected = controller.isConnected;
    controller.connect(target);
    // 미연결 → 연결은 교체 연출이 패널을 함께 내보낸다. 이미 연결된 상태에서 다른 창을 고르면 패널만 닫는다.
    if (wasConnected) _closePanel();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.service.state,
      builder: (context, state, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final menuHeight = math
                .min(
                  HomePage.menuSectionMaxSize.height,
                  math.max(320, constraints.maxHeight - 36),
                )
                .toDouble();
            final scan = widget.scanSession;
            // 팝업 층은 늘 같은 Stack 안에 둔다(열고 닫아도 메뉴 · 스크롤 element가 그대로다).
            return Stack(
              fit: StackFit.expand,
              children: [
                _buildPage(state.imageLoadState, menuHeight),
                if (_popupVisible && scan != null)
                  _buildPopupLayer(scan, constraints, menuHeight),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPage(ImageLoadState imageLoadState, double menuHeight) =>
      SingleChildScrollView(
        key: const ValueKey('home-page'),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: menuHeight,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _swapController,
                  _panelController,
                ]),
                builder: (context, _) => _buildSections(imageLoadState),
              ),
            ),
          ],
        ),
      );

  /// 스크림(홈 콘텐츠 영역 — 머리글은 시안처럼 가리지 않는다) + 가운데 팝업. 팝업은 메뉴와 같은 배율이고,
  /// 창이 좁으면 폭에 맞춰 더 줄여 화면 밖으로 나가지 않는다.
  Widget _buildPopupLayer(
    ScanSessionController scan,
    BoxConstraints constraints,
    double menuHeight,
  ) {
    final width = constraints.maxWidth;
    final scale = math.max(
      0.05,
      math.min(
        menuHeight / HomePage.menuSectionMaxSize.height,
        (width - 36) / HomeScanPopup.designSize.width,
      ),
    );
    final size = HomeScanPopup.designSize * scale;
    final left = math.max(18.0, (width - size.width) / 2);
    final top = 18 + HomeScanPopup.menuTopOffset * scale;
    final connected = _controller;
    return AnimatedBuilder(
      animation: Listenable.merge([_popupController, scan, ?connected]),
      builder: (context, _) {
        final t = AppMotion.sectionCurve.transform(_popupController.value);
        const scrim = BaScrim.scan;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('home-scan-popup-scrim'),
                behavior: HitTestBehavior.opaque,
                onTap: _closePopup,
                child: Opacity(
                  opacity: t,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(
                      sigmaX: scrim.blur,
                      sigmaY: scrim.blur,
                    ),
                    child: ColoredBox(color: scrim.color),
                  ),
                ),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: size.width,
              height: size.height,
              child: IgnorePointer(
                ignoring: _popupController.status == AnimationStatus.reverse,
                child: Opacity(
                  opacity: t,
                  child: Transform.scale(
                    scale: 0.96 + 0.04 * t,
                    child: FittedBox(
                      key: const ValueKey('home-scan-popup-section'),
                      fit: BoxFit.contain,
                      child: HomeScanPopup(
                        controller: scan,
                        target: connected?.target,
                        seed: _popupSeed,
                        appliedElsewhere: widget.scanAppliedElsewhere,
                        note: _popupNote,
                        onTile: _pressTile,
                        onReselect: _reselectTarget,
                        onClose: _closePopup,
                        onOpenScanTab: _openScanTab,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 메뉴 섹션(왼쪽 부착)과 창 선택 패널(오른쪽 부착). 둘 다 시안 설계 크기를 같은 높이로 맞춰 축소한다.
  Widget _buildSections(ImageLoadState imageLoadState) {
    final timeline = _timeline;
    final t = timeline?.at(_swapController.value) ?? Duration.zero;
    final showsConnected = timeline == null
        ? _menuConnected
        : timeline.swapped(t)
        ? _swapTarget
        : _menuConnected;
    final panelOffset = _panelExitingWithSwap && timeline != null
        ? timeline.panelOffset(t)
        : _panelTravel *
              (1 - AppMotion.sectionCurve.transform(_panelController.value));
    final panelShown =
        _panelVisible &&
        !(_panelExitingWithSwap && timeline != null && timeline.panelGone(t));
    final controller = _controller;
    return Stack(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: DirectionalSectionEntrance(
            key: const ValueKey('home-menu-entrance'),
            animation: widget.entranceAnimation,
            directionDegrees: 0,
            child: FittedBox(
              key: const ValueKey('home-menu-section'),
              fit: BoxFit.contain,
              alignment: Alignment.topLeft,
              child: SizedBox.fromSize(
                size: HomePage.menuSectionMaxSize,
                child: Transform.translate(
                  key: const ValueKey('home-menu-swap'),
                  offset: Offset(timeline?.menuOffset(t) ?? 0, 0),
                  child: IgnorePointer(
                    ignoring: timeline != null,
                    child: DiagonalTrapezoidSection(
                      child: _HomeMenuLayout(
                        imageLoadState: imageLoadState,
                        onOpen: widget.onOpen,
                        featured: showsConnected
                            ? HomePage._featuredConnected
                            : HomePage._featured,
                        onFeatured: _openFeatured,
                        featuredSelected: showsConnected
                            ? _popupVisible
                            : _panelVisible,
                        flashOpacity: timeline?.flashOpacity(t) ?? 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (panelShown && controller != null)
          Align(
            alignment: Alignment.topRight,
            child: FittedBox(
              key: const ValueKey('home-connect-panel-section'),
              fit: BoxFit.contain,
              alignment: Alignment.topRight,
              child: Transform.translate(
                offset: Offset(panelOffset, 0),
                child: IgnorePointer(
                  ignoring: _panelExitingWithSwap,
                  child: ConnectTargetPanel(
                    service: widget.service,
                    connectedTarget: controller,
                    onCancel: _closePanel,
                    onUse: _useTarget,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeMenuLayout extends StatelessWidget {
  const _HomeMenuLayout({
    required this.imageLoadState,
    required this.onOpen,
    required this.featured,
    required this.onFeatured,
    required this.featuredSelected,
    required this.flashOpacity,
  });

  static const _angle = 80.0;
  static const _radius = 7.0;
  static const _rowGap = 10.0;
  static const _seamGap = 15.0;
  static const _left = 18.0;
  static const _top = 18.0;
  static const _right = 30.0;
  static const _bottom = 18.0;
  static const _shadowInset = 3.0;

  final ImageLoadState imageLoadState;
  final ValueChanged<AppSection> onOpen;
  final _HomeCardData featured;
  final VoidCallback onFeatured;

  /// 창 선택 패널이 열려 있음(시안 Home-Connect-Pick 행1 분홍 3.2px 선).
  final bool featuredSelected;

  /// 연결 직후 flash 불투명도(시안 Home-Connect-Effect `.hm-flash`).
  final double flashOpacity;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sectionSize = Size(constraints.maxWidth, constraints.maxHeight);
        final usableHeight = math.max(
          4,
          constraints.maxHeight - _top - _bottom - _rowGap * 3,
        );
        final rowHeight = usableHeight / 4;
        final rows = <List<_HomeCardData>>[
          [featured],
          HomePage._compactCards,
          HomePage._wideCards,
          [HomePage._settings],
        ];

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
              _buildRow(
                sectionSize,
                rows[rowIndex],
                rowIndex: rowIndex,
                rowHeight: rowHeight,
              ),
          ],
        );
      },
    );
  }

  Widget _buildRow(
    Size sectionSize,
    List<_HomeCardData> cards, {
    required int rowIndex,
    required double rowHeight,
  }) {
    final top = _top + rowIndex * (rowHeight + _rowGap);
    final boundaryInset = rightCutBoundaryInset(
      sectionSize,
      top,
      angleDegrees: _angle,
      radius: _radius,
      inset: _shadowInset,
    );
    final width = math
        .max(1, sectionSize.width - _left - _right - boundaryInset)
        .toDouble();
    final row = DiagonalMenuRow(
      weights: [for (final card in cards) card.imageWidth],
      seamGap: _seamGap,
      angleDegrees: _angle,
      radius: _radius,
      children: [
        for (var index = 0; index < cards.length; index++)
          DiagonalMenuButton(
            key: ValueKey('home-menu-${cards[index].section.name}'),
            caption: cards[index].caption,
            extendLeft: index > 0,
            angleDegrees: _angle,
            radius: _radius,
            onTap: rowIndex == 0
                ? onFeatured
                : () => onOpen(cards[index].section),
            child: _HomeMenuButtonContent(
              data: cards[index],
              imageLoadState: imageLoadState,
            ),
          ),
      ],
    );

    return Positioned(
      key: ValueKey('home-menu-row-$rowIndex'),
      left: _left,
      top: top,
      width: width,
      height: rowHeight,
      child: rowIndex == 0 ? _withFeaturedOverlay(row) : row,
    );
  }

  /// 행1 위에 선택 선·flash를 겹친다. 겹침이 없어도 같은 Stack이라 버튼 element가 유지된다.
  Widget _withFeaturedOverlay(Widget row) => Stack(
    fit: StackFit.expand,
    children: [
      row,
      if (featuredSelected)
        const IgnorePointer(
          child: CustomPaint(
            key: ValueKey('home-menu-featured-selected'),
            painter: _FeaturedOverlayPainter(stroke: AppColors.accent),
          ),
        ),
      if (flashOpacity > 0)
        IgnorePointer(
          child: Opacity(
            key: const ValueKey('home-menu-featured-flash'),
            opacity: flashOpacity,
            child: CustomPaint(
              painter: _FeaturedOverlayPainter(
                stroke: AppColors.connectFlash,
                fill: AppColors.connectFlash.withValues(alpha: 0.16),
              ),
            ),
          ),
        ),
    ],
  );
}

/// 행1 위 겹침 선(시안 691×238, 3.2px). 버튼과 같은 80° path다.
class _FeaturedOverlayPainter extends CustomPainter {
  const _FeaturedOverlayPainter({required this.stroke, this.fill});

  final Color stroke;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final path = buildDiagonalButtonPath(
      size,
      extendLeft: false,
      cutRight: true,
      angleDegrees: _HomeMenuLayout._angle,
      radius: _HomeMenuLayout._radius,
    );
    final fill = this.fill;
    if (fill != null) canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3.2
        ..color = stroke,
    );
  }

  @override
  bool shouldRepaint(_FeaturedOverlayPainter oldDelegate) =>
      oldDelegate.stroke != stroke || oldDelegate.fill != fill;
}

class _HomeCardData {
  const _HomeCardData(
    this.section,
    this.caption,
    this.fileName, {
    this.triangleOnly = false,
  });

  final AppSection section;
  final String caption;
  final String fileName;
  final bool triangleOnly;

  double get imageWidth => switch (fileName) {
    'shittim.png' || 'scan.png' => 692,
    'students.png' || 'plan.png' => 233,
    'inventory.png' => 231,
    'pvp.png' => 315,
    'statistics.png' => 314,
    _ => 1,
  };
}

class _HomeMenuButtonContent extends StatelessWidget {
  const _HomeMenuButtonContent({
    required this.data,
    required this.imageLoadState,
  });

  static const _settingsTexture = BATriangleTextureConfig(
    baseColor: Color(0xff47586b),
    panelColor: AppColors.surfaceRaised,
    softColor: Color(0xffaebdca),
    accentColor: AppColors.textMuted,
    tessellationContrast: 0.1,
    randomSeed: 8417,
    macroTriangleChance: 0.12,
    macroTriangleScale: 2.8,
    macroTriangleContrast: 0.05,
    lightStrength: 0.1,
    lightCenterX: 0.5,
    lightCenterY: 0.5,
    edgeVignetteStrength: 0.06,
    fogDirectionDegrees: 0,
    fogStrength: 0.035,
  );

  final _HomeCardData data;
  final ImageLoadState imageLoadState;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final slant = diagonalSlant(size);
        final captionLeft = math
            .max(10, constraints.maxHeight * 0.08)
            .toDouble();
        final captionRight = slant + math.max(8, constraints.maxHeight * 0.055);
        final captionBottom = math
            .max(7, constraints.maxHeight * 0.055)
            .toDouble();
        final captionTop = constraints.maxHeight * 0.65;
        final captionFontSize = (constraints.maxHeight * 0.14)
            .round()
            .clamp(12, 24)
            .toDouble();

        return Stack(
          fit: StackFit.expand,
          children: [
            if (data.triangleOnly)
              CustomPaint(painter: BATriangleTexturePainter(_settingsTexture))
            else
              _CardImage(fileName: data.fileName, loadState: imageLoadState),
            if (!data.triangleOnly)
              Positioned(
                left: 0,
                top: captionTop,
                right: 0,
                bottom: 0,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00747b86),
                        Color(0x75747b86),
                        Color(0xd6747b86),
                        Color(0xf5747b86),
                        Color(0xff747b86),
                      ],
                      stops: [0, 0.18, 0.30, 0.56, 1],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: captionLeft,
              top: captionTop,
              right: captionRight,
              bottom: captionBottom,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  data.caption,
                  softWrap: true,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'GyeonggiTitle',
                    fontSize: captionFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.fileName, required this.loadState});

  final String fileName;
  final ImageLoadState loadState;

  @override
  Widget build(BuildContext context) {
    return switch (loadState) {
      ImageLoadState.loaded => GameImage(
        'assets/home_menu/$fileName',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => const _ImageFailure(),
      ),
      ImageLoadState.loading => const ColoredBox(
        color: AppColors.surfaceRaised,
        child: Center(child: CircularProgressIndicator()),
      ),
      ImageLoadState.failed => const _ImageFailure(),
    };
  }
}

class _ImageFailure extends StatelessWidget {
  const _ImageFailure();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceRaised,
      child: Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
      ),
    );
  }
}
