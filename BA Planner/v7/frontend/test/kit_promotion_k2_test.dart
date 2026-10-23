// K2 키트 교체 시험: 튜토리얼 안 사본 부품을 K1 키트로 바꾼 뒤에도 그림이 같다(path 대조 · 같은 자리에 그린 픽셀 ·
// 크기 대조). 옛 공개 이름은 얇은 별칭으로 남았다.
//
// 기준: K2 직전(F3c-8 반영 작업 트리) 튜토리얼 부품을 아래 `_Pre*`에 그대로 옮겨 두었다(이름만 바꿈, 값은 그때 상수).
// `tutorial_tokens.dart`(글리프 · 그만두기 버튼 · 강조 값), `tutorial_highlight.dart`(강조 path · 그리기 · 빛 · 위젯),
// `tutorial_step_card.dart`(도는 표시 · 머리글 칩 · 체크), `tutorial_quit_dialog.dart`(패널 · `_PanelButton` · 텍스처 ·
// 외곽선), `tutorial_overlay.dart`(완료 패널 path).
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/geometry/diagonal_geometry.dart';
import 'package:ba_planner_v7/ui/kit/ba_chip.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/kit/focus_ring.dart';
import 'package:ba_planner_v7/ui/kit/kit_glyph.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:ba_planner_v7/ui/kit/kit_spinner.dart';
import 'package:ba_planner_v7/ui/kit/panel_button.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_highlight.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_quit_dialog.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_script.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_step_card.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_tokens.dart';
import 'package:ba_planner_v7/ui/widgets/account_create_modal.dart';
import 'package:ba_planner_v7/ui/widgets/ba_triangle_background.dart';
import 'package:ba_planner_v7/ui/widgets/lifted_path_shadow.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 두 path가 같은 모양인가(윤곽 수 · 길이 · 길이를 따라 고른 점 · bounds).
void _expectSamePath(Path actual, Path expected, {String? reason}) {
  final a = actual.computeMetrics().toList();
  final b = expected.computeMetrics().toList();
  expect(a.length, b.length, reason: reason);
  for (var index = 0; index < a.length; index++) {
    expect(a[index].length, closeTo(b[index].length, 1e-6), reason: reason);
    for (var step = 0; step <= 16; step++) {
      final offset = a[index].length * step / 16;
      final pa = a[index].getTangentForOffset(offset)!.position;
      final pb = b[index].getTangentForOffset(offset)!.position;
      expect((pa - pb).distance, lessThan(1e-6), reason: reason);
    }
  }
  final ab = actual.getBounds();
  final bb = expected.getBounds();
  for (final pair in [
    (ab.left, bb.left),
    (ab.top, bb.top),
    (ab.right, bb.right),
    (ab.bottom, bb.bottom),
  ]) {
    expect(pair.$1, closeTo(pair.$2, 1e-6), reason: reason);
  }
}

const _boxKey = ValueKey('k2-box');

/// [child]를 [size] 자리 가운데에 그려 RGBA 바이트와 [child] 크기를 돌려준다. [hover]면 마우스를 [child] 가운데에 둔다.
Future<(Uint8List, Size)> _pixels(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(320, 120),
  Duration pump = Duration.zero,
  bool hover = false,
}) async {
  final key = GlobalKey();
  // hover 표시는 마우스 강조 모드에서만 보인다(시험 기본 플랫폼은 터치 모드).
  final strategy = FocusManager.instance.highlightStrategy;
  if (hover) {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: BAPlannerTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox.fromSize(
              size: size,
              child: Center(
                child: KeyedSubtree(key: _boxKey, child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  TestGesture? mouse;
  if (hover) {
    mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byKey(_boxKey)));
    // 마우스 추적은 다음 그리기 뒤에 hover를 알리고, 그 setState는 한 장 더 그려야 보인다.
    await tester.pump();
    await mouse.moveBy(const Offset(1, 0));
    await tester.pump();
  }
  await tester.pump(pump);
  final childSize = tester.getSize(find.byKey(_boxKey));
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  await mouse?.removePointer();
  FocusManager.instance.highlightStrategy = strategy;
  return (bytes!, childSize);
}

/// 두 위젯을 같은 자리에 그려 픽셀 · 크기가 같은지 본다. 하나라도 그린 픽셀이 있어야 한다(빈 그림끼리 같다는 착각 방지).
Future<void> _expectSamePicture(
  WidgetTester tester,
  Widget actual,
  Widget expected, {
  Size size = const Size(320, 120),
  Duration pump = Duration.zero,
  bool hover = false,
  String? reason,
}) async {
  final (empty, _) = await _pixels(
    tester,
    const SizedBox.shrink(),
    size: size,
    pump: pump,
  );
  final (a, aSize) = await _pixels(
    tester,
    actual,
    size: size,
    pump: pump,
    hover: hover,
  );
  final (b, bSize) = await _pixels(
    tester,
    expected,
    size: size,
    pump: pump,
    hover: hover,
  );
  expect(a, isNot(equals(empty)), reason: 'draws something: $reason');
  expect(aSize, bSize, reason: reason);
  expect(a, equals(b), reason: reason);
}

void _stillAnimations(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

// ---- K2 직전 사본(그대로 옮김) -------------------------------------------------------------------

enum _PreGlyph { check, flag }

class _PreGlyphPainter extends CustomPainter {
  const _PreGlyphPainter({
    required this.glyph,
    required this.color,
    this.strokeWidth,
  });

  final _PreGlyph glyph;
  final Color color;
  final double? strokeWidth;

  Path _path() => switch (glyph) {
    _PreGlyph.check =>
      Path()
        ..moveTo(5, 12.5)
        ..lineTo(9.5, 17)
        ..lineTo(19, 7.5),
    _PreGlyph.flag =>
      Path()
        ..moveTo(5, 21)
        ..lineTo(5, 4)
        ..moveTo(5, 4)
        ..lineTo(16, 4)
        ..lineTo(14, 8)
        ..lineTo(16, 12)
        ..lineTo(5, 12),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      _path(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth ?? (glyph == _PreGlyph.check ? 2.8 : 1.9)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PreGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

class _PreQuitButton extends StatelessWidget {
  const _PreQuitButton({required this.onPressed})
    : height = 30,
      horizontalPadding = 12,
      gap = 5,
      fontSize = AppType.popoverBodySize,
      iconSize = 13;

  const _PreQuitButton.band({required this.onPressed})
    : height = 40,
      horizontalPadding = 16,
      gap = 7,
      fontSize = AppType.bodyPlusSize,
      iconSize = 15;

  const _PreQuitButton.inline({required this.onPressed})
    : height = 26,
      horizontalPadding = 9,
      gap = 4,
      fontSize = AppType.captionPlusSize,
      iconSize = 12;

  final VoidCallback? onPressed;
  final double height;
  final double horizontalPadding;
  final double gap;
  final double fontSize;
  final double iconSize;
  static const label = '그만두기';

  static const _fill = Color(0xff3a4b58);
  static const _hoverFill = Color(0xff455866);
  static const _foreground = Color(0xffd6e4f0);

  @override
  Widget build(BuildContext context) {
    final button = KitPressable(
      onPressed: onPressed,
      builder: (context, state) => Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          color: state.hovered ? _hoverFill : _fill,
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadii.control),
          ),
          boxShadow: state.focused
              ? const [BoxShadow(color: kitFocusColor, spreadRadius: 1.5)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: iconSize,
              child: const CustomPaint(
                painter: KitGlyphPainter(
                  glyph: KitGlyph.close,
                  color: _foreground,
                ),
              ),
            ),
            SizedBox(width: gap),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tutorialText(fontSize, color: _foreground, height: 1.2),
            ),
          ],
        ),
      ),
    );
    return onPressed == null
        ? Opacity(opacity: kitDisabledOpacity, child: button)
        : button;
  }
}

// 강조 테두리 값(K2 직전 tutorial_tokens.dart).
const _preHighlightColor = AppColors.primary;
const _preHighlightStroke = 2.5;
const _preGlowStroke = 9.0;
const _preGlowBlur = 5.0;
const _preGlowPeriod = Duration(milliseconds: 1800);
const _preGlowMinOpacity = 0.35;
const _preGlowMaxOpacity = 0.9;
const _preGlowStillOpacity = 0.6;
const _preHighlightOffset = 5.0;

enum _PreShape { parallelogram, roundedRect }

Path _preHighlightPath(
  Rect target, {
  _PreShape shape = _PreShape.parallelogram,
  double? targetRadius,
}) {
  const d = _preHighlightOffset;
  switch (shape) {
    case _PreShape.roundedRect:
      final radius = (targetRadius ?? 10) + d;
      return Path()..addRRect(
        RRect.fromRectAndRadius(target.inflate(d), Radius.circular(radius)),
      );
    case _PreShape.parallelogram:
      final outer = Rect.fromLTRB(
        target.left - diagonalCutDepth(d) - diagonalNormalInset(d),
        target.top - d,
        target.right + diagonalCutDepth(d) + diagonalNormalInset(d),
        target.bottom + d,
      );
      final cut = diagonalCutDepth(outer.height);
      return diagonalRoundedPolygon(
        [
          Offset(outer.left + cut, outer.top),
          Offset(outer.right, outer.top),
          Offset(outer.right - cut, outer.bottom),
          Offset(outer.left, outer.bottom),
        ],
        radius: (targetRadius ?? 8) + d,
        corner: DiagonalCornerStyle.quadratic,
      );
  }
}

void _prePaintRing(Canvas canvas, Path path, double glowOpacity) {
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _preGlowStroke
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _preGlowBlur)
      ..color = _preHighlightColor.withValues(alpha: glowOpacity),
  );
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _preHighlightStroke
      ..strokeJoin = StrokeJoin.round
      ..color = _preHighlightColor,
  );
}

class _PreGlowBuilder extends StatefulWidget {
  const _PreGlowBuilder({required this.builder});

  final Widget Function(BuildContext context, Animation<double> glowOpacity)
  builder;

  @override
  State<_PreGlowBuilder> createState() => _PreGlowBuilderState();
}

class _PreGlowBuilderState extends State<_PreGlowBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _preGlowPeriod ~/ 2,
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: _preGlowMinOpacity,
    end: _preGlowMaxOpacity,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = tutorialReduceMotion(context);
    if (_reduce) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    _reduce
        ? const AlwaysStoppedAnimation<double>(_preGlowStillOpacity)
        : _opacity,
  );
}

class _PreRingPainter extends CustomPainter {
  _PreRingPainter({required this.glow, required this.pathFor})
    : super(repaint: glow);

  final Animation<double> glow;
  final Path Function(Size size) pathFor;

  @override
  void paint(Canvas canvas, Size size) =>
      _prePaintRing(canvas, pathFor(size), glow.value);

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_PreRingPainter oldDelegate) =>
      oldDelegate.glow != glow || oldDelegate.pathFor != pathFor;
}

class _PreHighlight extends StatelessWidget {
  const _PreHighlight({
    required this.child,
    this.shape = _PreShape.parallelogram,
    this.targetRadius,
  });

  final Widget child;
  final _PreShape shape;
  final double? targetRadius;

  @override
  Widget build(BuildContext context) => _PreGlowBuilder(
    builder: (context, glow) => CustomPaint(
      foregroundPainter: _PreRingPainter(glow: glow, pathFor: _pathFor),
      child: child,
    ),
  );

  Path _pathFor(Size size) => _preHighlightPath(
    Offset.zero & size,
    shape: shape,
    targetRadius: targetRadius,
  );
}

class _PreHighlightRing extends StatelessWidget {
  const _PreHighlightRing({
    required this.target,
    this.shape = _PreShape.parallelogram,
    this.targetRadius,
  });

  final Rect target;
  final _PreShape shape;
  final double? targetRadius;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: _PreGlowBuilder(
        builder: (context, glow) => CustomPaint(
          painter: _PreRingPainter(glow: glow, pathFor: _pathFor),
        ),
      ),
    ),
  );

  Path _pathFor(Size size) =>
      _preHighlightPath(target, shape: shape, targetRadius: targetRadius);
}

Rect _preHighlightBounds(
  Rect target, {
  _PreShape shape = _PreShape.parallelogram,
}) {
  final path = _preHighlightPath(target, shape: shape);
  const glow = _preGlowStroke / 2 + _preGlowBlur * 2;
  return path.getBounds().inflate(math.max(glow, _preHighlightStroke));
}

class _PreSpinner extends StatefulWidget {
  const _PreSpinner();

  @override
  State<_PreSpinner> createState() => _PreSpinnerState();
}

class _PreSpinnerState extends State<_PreSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (tutorialReduceMotion(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _controller,
    child: const SizedBox.square(
      dimension: 16,
      child: CustomPaint(painter: _PreSpinnerPainter()),
    ),
  );
}

class _PreSpinnerPainter extends CustomPainter {
  const _PreSpinnerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.4;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      math.pi * 3 / 4,
      math.pi * 3 / 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.primary,
    );
  }

  @override
  bool shouldRepaint(_PreSpinnerPainter oldDelegate) => false;
}

class _PreHeaderChip extends StatelessWidget {
  const _PreHeaderChip();

  static const _fill = Color.fromRGBO(113, 199, 244, 0.18);
  static const _ring = Color.fromRGBO(113, 199, 244, 0.55);

  @override
  Widget build(BuildContext context) => Semantics(
    label: TutorialCopy.headerChip,
    excludeSemantics: true,
    child: Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.chip)),
        border: Border.all(color: _ring, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 13,
            child: CustomPaint(
              painter: _PreGlyphPainter(
                glyph: _PreGlyph.flag,
                color: tutorialInfoText,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            TutorialCopy.headerChip,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tutorialText(
              AppType.bodySmallSize,
              color: tutorialInfoText,
              height: 1.2,
            ),
          ),
        ],
      ),
    ),
  );
}

// 그만두기 확인 패널(K2 직전 tutorial_quit_dialog.dart — 키만 뺐다).
const _prePanelFill = Color.fromRGBO(29, 42, 58, 0.98);
const _preQuitOutline = Color.fromRGBO(56, 81, 107, 0.72);
const _preContinueOutline = Color.fromRGBO(242, 179, 239, 0.9);
const _preQuitLabel = Color(0xffffb3bb);

const _preQuitTexture = BATriangleTextureConfig(
  baseColor: BATrianglePalette.softTitlePinkBase,
  panelColor: BATrianglePalette.softTitlePinkPanel,
  softColor: BATrianglePalette.softTitlePinkSoft,
  accentColor: BATrianglePalette.softTitlePinkAccent,
  triangleSize: 30,
  tessellationContrast: 0.09,
  randomSeed: 7411,
  macroTriangleChance: 0.14,
  macroTriangleScale: 2.1,
  macroTriangleContrast: 0.06,
  lightStrength: 0.22,
  edgeVignetteStrength: 0.12,
  fogStrength: 0.08,
);

class _PreQuitPanel extends StatelessWidget {
  const _PreQuitPanel({required this.onContinue, required this.onQuit});

  final VoidCallback onContinue;
  final VoidCallback onQuit;
  static const accountName = TutorialCopy.sampleAccount;

  @override
  Widget build(BuildContext context) {
    const size = tutorialQuitPanelSize;
    final panelPath = accountCreateParallelogram(Offset.zero & size, 18);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox.fromSize(
        size: size,
        child: Semantics(
          container: true,
          label: TutorialCopy.quitTitle,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              LiftedPathShadow(path: panelPath),
              Positioned.fill(
                child: ClipPath(
                  clipper: _PrePathClipper(panelPath),
                  child: const ColoredBox(color: _prePanelFill),
                ),
              ),
              Positioned(
                left: 81,
                top: 30,
                right: 60,
                child: Row(
                  children: [
                    Transform(
                      transform: Matrix4.skewX(-10 * math.pi / 180),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 7,
                        height: 24,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.all(Radius.circular(2)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        TutorialCopy.quitTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tutorialDisplay(AppType.headlineLargeSize),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 70,
                top: 92,
                width: 820,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TutorialCopy.quitBody(accountName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tutorialText(
                        AppType.titleMediumSize,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      TutorialCopy.quitNote,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tutorialText(
                        AppType.bodyPlusSize,
                        color: AppColors.textMuted,
                        weight: AppType.regular,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              _PrePanelButton(
                rect: const Rect.fromLTWH(541.8, 206, 170, 56),
                texture: _preQuitTexture,
                outline: _preQuitOutline,
                label: TutorialCopy.quitConfirm,
                labelColor: _preQuitLabel,
                onTap: onQuit,
              ),
              _PrePanelButton(
                rect: const Rect.fromLTWH(723.8, 206, 170, 56),
                texture: titlePrimaryActionTexture,
                outline: _preContinueOutline,
                label: TutorialCopy.quitContinue,
                labelColor: Colors.white,
                autofocus: true,
                onTap: onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrePanelButton extends StatelessWidget {
  const _PrePanelButton({
    required this.rect,
    required this.texture,
    required this.outline,
    required this.label,
    required this.labelColor,
    required this.onTap,
    this.autofocus = false,
  });

  final Rect rect;
  final BATriangleTextureConfig texture;
  final Color outline;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final path = accountCreateParallelogram(Offset.zero & rect.size, 8);
    return Positioned.fromRect(
      rect: rect,
      child: KitPressable(
        onPressed: onTap,
        autofocus: autofocus,
        semanticLabel: label,
        builder: (context, state) => Stack(
          fit: StackFit.expand,
          children: [
            ClipPath(
              clipper: _PrePathClipper(path),
              child: BATriangleBackground(config: texture),
            ),
            Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tutorialText(15, color: labelColor, height: 1.2),
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _PreOutlinePainter(
                  path,
                  color: state.focused ? AppColors.primary : outline,
                  strokeWidth: state.focused ? 2.6 : 1.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrePathClipper extends CustomClipper<Path> {
  const _PrePathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PrePathClipper oldClipper) => oldClipper.path != path;
}

class _PreOutlinePainter extends CustomPainter {
  const _PreOutlinePainter(
    this.path, {
    required this.color,
    required this.strokeWidth,
  });

  final Path path;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..color = color,
  );

  @override
  bool shouldRepaint(_PreOutlinePainter oldDelegate) =>
      oldDelegate.path != path ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

// ---- 시험 ---------------------------------------------------------------------------------------

void main() {
  group('glyphs', () {
    test('tutorial glyph aliases map to the kit with the tutorial strokes', () {
      expect(TutorialGlyph.values, hasLength(2));
      expect(TutorialGlyph.check.kit, KitGlyph.check);
      expect(TutorialGlyph.check.strokeWidth, 2.8);
      expect(tutorialCheckStroke, 2.8);
      expect(TutorialGlyph.flag.kit, KitGlyph.flag);
      expect(TutorialGlyph.flag.strokeWidth, 1.9);
      expect(
        const TutorialGlyphPainter(
          glyph: TutorialGlyph.check,
          color: tutorialCheckColor,
        ).shouldRepaint(
          const TutorialGlyphPainter(
            glyph: TutorialGlyph.check,
            color: tutorialCheckColor,
            strokeWidth: 2,
          ),
        ),
        isTrue,
      );
    });

    testWidgets('alias painter draws the pre-K2 tutorial glyphs', (
      tester,
    ) async {
      for (final (glyph, pre) in const [
        (TutorialGlyph.check, _PreGlyph.check),
        (TutorialGlyph.flag, _PreGlyph.flag),
      ]) {
        for (final size in const [13.0, 24.0, 40.0]) {
          for (final stroke in const <double?>[null, 1.5]) {
            await _expectSamePicture(
              tester,
              SizedBox.square(
                dimension: size,
                child: CustomPaint(
                  painter: TutorialGlyphPainter(
                    glyph: glyph,
                    color: tutorialInfoText,
                    strokeWidth: stroke,
                  ),
                ),
              ),
              SizedBox.square(
                dimension: size,
                child: CustomPaint(
                  painter: _PreGlyphPainter(
                    glyph: pre,
                    color: tutorialInfoText,
                    strokeWidth: stroke,
                  ),
                ),
              ),
              reason: '$glyph $size $stroke',
            );
          }
        }
      }
    });

    testWidgets('step card checks (13 · 24, stroke 2.8) draw the same', (
      tester,
    ) async {
      for (final size in const [13.0, 24.0]) {
        await _expectSamePicture(
          tester,
          KitGlyphIcon(
            KitGlyph.check,
            size: size,
            color: tutorialCheckColor,
            strokeWidth: tutorialCheckStroke,
          ),
          SizedBox.square(
            dimension: size,
            child: const CustomPaint(
              painter: _PreGlyphPainter(
                glyph: _PreGlyph.check,
                color: tutorialCheckColor,
              ),
            ),
          ),
          reason: 'check $size',
        );
      }
      // 키트 기본 굵기(1.9)로는 다르게 그려진다 — 2.8을 빠뜨리면 시험이 잡는다.
      final (thin, _) = await _pixels(
        tester,
        const KitGlyphIcon(KitGlyph.check, size: 24, color: tutorialCheckColor),
      );
      final (pre, _) = await _pixels(
        tester,
        const SizedBox.square(
          dimension: 24,
          child: CustomPaint(
            painter: _PreGlyphPainter(
              glyph: _PreGlyph.check,
              color: tutorialCheckColor,
            ),
          ),
        ),
      );
      expect(thin, isNot(equals(pre)));
    });
  });

  group('quit button', () {
    testWidgets('three sizes draw the same as the pre-K2 button', (
      tester,
    ) async {
      void onPressed() {}
      for (final (actual, expected, name) in [
        (
          TutorialQuitButton(onPressed: onPressed),
          _PreQuitButton(onPressed: onPressed),
          'card 30',
        ),
        (
          TutorialQuitButton.band(onPressed: onPressed),
          _PreQuitButton.band(onPressed: onPressed),
          'band 40',
        ),
        (
          TutorialQuitButton.inline(onPressed: onPressed),
          _PreQuitButton.inline(onPressed: onPressed),
          'inline 26',
        ),
      ]) {
        await _expectSamePicture(tester, actual, expected, reason: name);
        await _expectSamePicture(
          tester,
          actual,
          expected,
          hover: true,
          reason: '$name hover',
        );
      }
      await _expectSamePicture(
        tester,
        const TutorialQuitButton(onPressed: null),
        const _PreQuitButton(onPressed: null),
        reason: 'disabled',
      );
      // hover 대조가 뜻이 있는지: hover 바탕(#455866)이 실제로 그려진다.
      final (plain, _) = await _pixels(
        tester,
        TutorialQuitButton(onPressed: onPressed),
      );
      final (hovered, _) = await _pixels(
        tester,
        TutorialQuitButton(onPressed: onPressed),
        hover: true,
      );
      expect(hovered, isNot(equals(plain)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the button is the kit tonal button and still taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: BAPlannerTheme.dark(),
          home: Scaffold(
            body: Center(
              child: TutorialQuitButton(
                key: TutorialStepCard.quitKey,
                onPressed: () => taps++,
              ),
            ),
          ),
        ),
      );
      final tonal = tester.widget<TonalButton>(find.byType(TonalButton));
      expect(tonal.fontWeight, AppType.bold);
      expect(tonal.gap, 5);
      expect(tonal.height, 30);
      expect(tonal.leading, isA<KitGlyphIcon>());
      await tester.tap(find.byKey(TutorialStepCard.quitKey));
      expect(taps, 1);
    });
  });

  group('focus ring', () {
    test('paths, bounds and values match the pre-K2 highlight', () {
      for (final target in const [
        Rect.fromLTWH(0, 0, 300, 60),
        Rect.fromLTWH(40, 12, 760, 58),
        Rect.fromLTWH(-8, 30, 260, 160),
      ]) {
        for (final radius in const <double?>[null, 7, 14]) {
          _expectSamePath(
            tutorialHighlightPath(target, targetRadius: radius),
            _preHighlightPath(target, targetRadius: radius),
            reason: '$target $radius parallelogram',
          );
          _expectSamePath(
            tutorialHighlightPath(
              target,
              shape: TutorialHighlightShape.roundedRect,
              targetRadius: radius,
            ),
            _preHighlightPath(
              target,
              shape: _PreShape.roundedRect,
              targetRadius: radius,
            ),
            reason: '$target $radius roundedRect',
          );
        }
        expect(tutorialHighlightBounds(target), _preHighlightBounds(target));
        expect(
          tutorialHighlightBounds(
            target,
            shape: TutorialHighlightShape.roundedRect,
          ),
          _preHighlightBounds(target, shape: _PreShape.roundedRect),
        );
      }
      expect(tutorialHighlightOffset, _preHighlightOffset);
      expect(tutorialHighlightColor, _preHighlightColor);
      expect(tutorialHighlightStroke, _preHighlightStroke);
      expect(tutorialGlowStroke, _preGlowStroke);
      expect(tutorialGlowBlur, _preGlowBlur);
      expect(tutorialGlowPeriod, _preGlowPeriod);
      expect(tutorialGlowMinOpacity, _preGlowMinOpacity);
      expect(tutorialGlowMaxOpacity, _preGlowMaxOpacity);
      expect(tutorialGlowStillOpacity, _preGlowStillOpacity);
    });

    test('old names are aliases of the kit', () {
      expect(TutorialHighlightShape.values, KitFocusRingShape.values);
      expect(
        TutorialHighlightShape.parallelogram,
        KitFocusRingShape.parallelogram,
      );
      expect(TutorialHighlightRing, KitFocusRingAt);
      expect(TutorialHighlight, KitFocusRing);
      expect(TutorialGlowBuilder, KitFocusGlowBuilder);
      expect(TutorialSpinner, KitSpinner);
    });

    testWidgets('still rings draw the same as the pre-K2 rings', (
      tester,
    ) async {
      _stillAnimations(tester);
      const target = Rect.fromLTWH(60, 38, 200, 44);
      await _expectSamePicture(
        tester,
        const SizedBox(
          width: 320,
          height: 120,
          child: Stack(children: [TutorialHighlightRing(target: target)]),
        ),
        const SizedBox(
          width: 320,
          height: 120,
          child: Stack(children: [_PreHighlightRing(target: target)]),
        ),
        reason: 'ring',
      );
      await _expectSamePicture(
        tester,
        const SizedBox(
          width: 320,
          height: 120,
          child: Stack(
            children: [
              TutorialHighlightRing(
                target: target,
                shape: TutorialHighlightShape.roundedRect,
                targetRadius: 12,
              ),
            ],
          ),
        ),
        const SizedBox(
          width: 320,
          height: 120,
          child: Stack(
            children: [
              _PreHighlightRing(
                target: target,
                shape: _PreShape.roundedRect,
                targetRadius: 12,
              ),
            ],
          ),
        ),
        reason: 'rounded ring',
      );
      await _expectSamePicture(
        tester,
        const TutorialHighlight(child: SizedBox(width: 160, height: 44)),
        const _PreHighlight(child: SizedBox(width: 160, height: 44)),
        reason: 'wrap',
      );
      await _expectSamePicture(
        tester,
        const TutorialHighlight(
          shape: TutorialHighlightShape.roundedRect,
          targetRadius: 10,
          child: SizedBox(width: 120, height: 40),
        ),
        const _PreHighlight(
          shape: _PreShape.roundedRect,
          targetRadius: 10,
          child: SizedBox(width: 120, height: 40),
        ),
        reason: 'wrap rounded',
      );
      // 프라나 밝히기 테두리(plana_dialogue `_DimPainter`): 같은 둥근 사각형 path를 두 그리기로.
      final reveal = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(40, 30, 220, 60),
            const Radius.circular(14),
          ),
        );
      await _expectSamePicture(
        tester,
        SizedBox(
          width: 320,
          height: 120,
          child: CustomPaint(
            painter: _PathPainter((c) => paintKitFocusRing(c, reveal, 0.6)),
          ),
        ),
        SizedBox(
          width: 320,
          height: 120,
          child: CustomPaint(
            painter: _PathPainter((c) => _prePaintRing(c, reveal, 0.6)),
          ),
        ),
        reason: 'reveal ring',
      );
    });

    testWidgets('breathing glow matches the pre-K2 glow over time', (
      tester,
    ) async {
      const target = Rect.fromLTWH(60, 38, 200, 44);
      for (final at in const [
        Duration.zero,
        Duration(milliseconds: 300),
        Duration(milliseconds: 1250),
      ]) {
        await _expectSamePicture(
          tester,
          const SizedBox(
            width: 320,
            height: 120,
            child: Stack(children: [TutorialHighlightRing(target: target)]),
          ),
          const SizedBox(
            width: 320,
            height: 120,
            child: Stack(children: [_PreHighlightRing(target: target)]),
          ),
          pump: at,
          reason: 'glow $at',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('spinner', () {
    testWidgets('still spinner draws the same as the pre-K2 spinner', (
      tester,
    ) async {
      _stillAnimations(tester);
      await _expectSamePicture(
        tester,
        const TutorialSpinner(),
        const _PreSpinner(),
      );
      await _expectSamePicture(tester, const KitSpinner(), const _PreSpinner());
    });

    testWidgets('turning spinner matches over time', (tester) async {
      for (final at in const [
        Duration(milliseconds: 125),
        Duration(milliseconds: 375),
        Duration(milliseconds: 820),
      ]) {
        await _expectSamePicture(
          tester,
          const KitSpinner(),
          const _PreSpinner(),
          pump: at,
          reason: 'spin $at',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('header chip', () {
    testWidgets('kit ringed chip draws the pre-K2 header chip', (tester) async {
      await _expectSamePicture(
        tester,
        const TutorialHeaderChip(),
        const _PreHeaderChip(),
      );
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: TutorialHeaderChip())),
      );
      final chip = tester.widget<BaChip>(find.byType(BaChip));
      expect(chip.shape, BaChipShape.ringed);
      expect(chip.height, 26);
      expect(chip.tone.background, const Color.fromRGBO(113, 199, 244, 0.18));
      expect(
        chip.tone.base.withValues(alpha: chip.shape.borderAlpha),
        const Color.fromRGBO(113, 199, 244, 0.55),
      );
    });

    testWidgets('semantics stay one label without the inner text', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: TutorialHeaderChip())),
      );
      expect(find.bySemanticsLabel(TutorialCopy.headerChip), findsOneWidget);
      final node = tester.getSemantics(find.byType(TutorialHeaderChip));
      expect(node.label, TutorialCopy.headerChip);
      var children = 0;
      node.visitChildren((_) {
        children++;
        return true;
      });
      expect(children, 0);
      handle.dispose();
    });
  });

  group('quit panel', () {
    test('parallelogram paths and texture match the pre-K2 helpers', () {
      for (final (size, radius) in const [
        (Size(980, 290), 18.0), // 그만두기 확인 패널
        (Size(170, 56), 8.0), // 패널 버튼
        (Size(1080, 480), 18.0), // tutorial_overlay 완료 패널
      ]) {
        _expectSamePath(
          kitParallelogramPath(Offset.zero & size, radius),
          accountCreateParallelogram(Offset.zero & size, radius),
          reason: '$size r$radius',
        );
      }
      expect(kitPanelCancelTexture, _preQuitTexture);
    });

    testWidgets('quit panel draws the same as the pre-K2 panel', (
      tester,
    ) async {
      void noop() {}
      await _expectSamePicture(
        tester,
        TutorialQuitPanel(onContinue: noop, onQuit: noop),
        _PreQuitPanel(onContinue: noop, onQuit: noop),
        size: const Size(1040, 360),
        reason: 'panel',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('keyboard focus outline on the buttons is unchanged', (
      tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      void noop() {}
      // autofocus '계속하기'가 하늘 2.6 외곽선을 그린다.
      await _expectSamePicture(
        tester,
        TutorialQuitPanel(onContinue: noop, onQuit: noop),
        _PreQuitPanel(onContinue: noop, onQuit: noop),
        size: const Size(1040, 360),
        reason: 'focused continue',
      );
      final (focused, _) = await _pixels(
        tester,
        TutorialQuitPanel(onContinue: noop, onQuit: noop),
        size: const Size(1040, 360),
      );
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      final (touch, _) = await _pixels(
        tester,
        TutorialQuitPanel(onContinue: noop, onQuit: noop),
        size: const Size(1040, 360),
      );
      expect(touch, isNot(equals(focused)), reason: 'focus outline visible');
    });
  });
}

class _PathPainter extends CustomPainter {
  _PathPainter(this.draw);

  final void Function(Canvas canvas) draw;

  @override
  void paint(Canvas canvas, Size size) => draw(canvas);

  @override
  bool shouldRepaint(_PathPainter oldDelegate) => true;
}
