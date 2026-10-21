// 강조 테두리 "focus ring" (K1, F3a 튜토리얼 강조 테두리 승격 — 시안 W-Tutorial-Card ④, FD-182).
//
// #71c7f4 · 2.5px · 바깥 빛(굵기 9 · 흐림 5) 1.8초 숨쉬기(.35 ↔ .9), 움직임 줄이기 설정이면 .6에 멈춘다.
// 테두리는 대상의 실제 외곽(80° 사선 · 모서리 둥글기)을 5px 바깥으로 옮긴 모양이다. 화면을 어둡게 하지 않고 대상 위에
// 아무것도 덮지 않는다 — 누르기를 받지 않아 대상을 그대로 누를 수 있다. 키보드 포커스 테두리([kitFocusColor])와는 다르다.
// - [KitFocusRing]: 대상 위젯을 감싸 그 둘레에 그린다.
// - [KitFocusRingAt]: 대상 사각형(부모 Stack 좌표)을 받아 그린다.
// 값 · path · 그리기는 F3a `tutorialHighlightPath` · `paintTutorialRing` · `TutorialGlowBuilder`와 같다(K2가 튜토리얼 사본을
// 이것으로 바꾼다).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';

/// 테두리 · 빛 색 #71c7f4(앱 기본 하늘색).
const kitFocusRingColor = AppColors.primary;

/// 테두리 두께 2.5px.
const kitFocusRingStroke = 2.5;

/// 대상과 테두리 사이(시안 5px).
const kitFocusRingOffset = 5.0;

/// 바깥 빛: 굵기 9 · 흐림 5 · 1.8초 숨쉬기(불투명도 .35 ↔ .9). 움직임 줄이기면 .6에 멈춘다.
const kitFocusGlowStroke = 9.0;
const kitFocusGlowBlur = 5.0;
const kitFocusGlowPeriod = Duration(milliseconds: 1800);
const kitFocusGlowMinOpacity = 0.35;
const kitFocusGlowMaxOpacity = 0.9;
const kitFocusGlowStillOpacity = 0.6;

/// 대상 외곽 모양.
enum KitFocusRingShape {
  /// 80° 사선 평행사변형(버튼 · 행 · 카드).
  parallelogram,

  /// 둥근 사각형(타일 · 작은 버튼).
  roundedRect,
}

/// 대상 사각형 [target]을 감싸는 테두리 path. [targetRadius]는 대상의 모서리 둥글기다(테두리는 +5).
Path kitFocusRingPath(
  Rect target, {
  KitFocusRingShape shape = KitFocusRingShape.parallelogram,
  double? targetRadius,
}) {
  const d = kitFocusRingOffset;
  switch (shape) {
    case KitFocusRingShape.roundedRect:
      final radius = (targetRadius ?? 10) + d;
      return Path()..addRRect(
        RRect.fromRectAndRadius(target.inflate(d), Radius.circular(radius)),
      );
    case KitFocusRingShape.parallelogram:
      // 대상 평행사변형의 각 변을 법선 방향으로 5px 옮긴 것: 위아래 5, 사선 변은 가로로 5/tan80 + 5/sin80.
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

/// 테두리 + 바깥 빛을 그린다. [glowOpacity]는 바깥 빛 불투명도다.
void paintKitFocusRing(Canvas canvas, Path path, double glowOpacity) {
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kitFocusGlowStroke
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, kitFocusGlowBlur)
      ..color = kitFocusRingColor.withValues(alpha: glowOpacity),
  );
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kitFocusRingStroke
      ..strokeJoin = StrokeJoin.round
      ..color = kitFocusRingColor,
  );
}

/// 테두리 바깥 끝까지의 사각형(빛 포함). 겹침 검사 · 시험용.
Rect kitFocusRingBounds(
  Rect target, {
  KitFocusRingShape shape = KitFocusRingShape.parallelogram,
}) {
  final path = kitFocusRingPath(target, shape: shape);
  final glow = kitFocusGlowStroke / 2 + kitFocusGlowBlur * 2;
  return path.getBounds().inflate(math.max(glow, kitFocusRingStroke));
}

/// 바깥 빛 숨쉬기(.35 ↔ .9, 1.8초). 움직임 줄이기면 멈춘 값(.6)을 돌려준다.
class KitFocusGlowBuilder extends StatefulWidget {
  const KitFocusGlowBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, Animation<double> glowOpacity)
  builder;

  @override
  State<KitFocusGlowBuilder> createState() => _KitFocusGlowBuilderState();
}

class _KitFocusGlowBuilderState extends State<KitFocusGlowBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kitFocusGlowPeriod ~/ 2,
  );
  late final Animation<double> _opacity = Tween<double>(
    begin: kitFocusGlowMinOpacity,
    end: kitFocusGlowMaxOpacity,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
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
        ? const AlwaysStoppedAnimation<double>(kitFocusGlowStillOpacity)
        : _opacity,
  );
}

class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter({required this.glow, required this.pathFor})
    : super(repaint: glow);

  final Animation<double> glow;
  final Path Function(Size size) pathFor;

  @override
  void paint(Canvas canvas, Size size) =>
      paintKitFocusRing(canvas, pathFor(size), glow.value);

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) =>
      oldDelegate.glow != glow || oldDelegate.pathFor != pathFor;
}

/// 대상 위젯을 감싸 둘레에 강조 테두리를 그린다. [active]가 false면 아무것도 그리지 않는다. 입력은 [child]가 그대로
/// 받는다.
class KitFocusRing extends StatelessWidget {
  const KitFocusRing({
    super.key,
    required this.child,
    this.active = true,
    this.shape = KitFocusRingShape.parallelogram,
    this.targetRadius,
  });

  final Widget child;
  final bool active;
  final KitFocusRingShape shape;
  final double? targetRadius;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return KitFocusGlowBuilder(
      builder: (context, glow) => CustomPaint(
        foregroundPainter: _FocusRingPainter(glow: glow, pathFor: _pathFor),
        child: child,
      ),
    );
  }

  Path _pathFor(Size size) => kitFocusRingPath(
    Offset.zero & size,
    shape: shape,
    targetRadius: targetRadius,
  );
}

/// 대상 사각형 [target](부모 Stack 좌표)에 강조 테두리를 그린다. 부모 Stack을 채우고 누르기를 받지 않는다.
class KitFocusRingAt extends StatelessWidget {
  const KitFocusRingAt({
    super.key,
    required this.target,
    this.shape = KitFocusRingShape.parallelogram,
    this.targetRadius,
  });

  final Rect target;
  final KitFocusRingShape shape;
  final double? targetRadius;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: KitFocusGlowBuilder(
        builder: (context, glow) => CustomPaint(
          painter: _FocusRingPainter(glow: glow, pathFor: _pathFor),
        ),
      ),
    ),
  );

  Path _pathFor(Size size) =>
      kitFocusRingPath(target, shape: shape, targetRadius: targetRadius);
}
