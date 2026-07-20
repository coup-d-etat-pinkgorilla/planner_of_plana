import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'lifted_path_shadow.dart';

const _defaultSectionShadow = LiftedPathShadowSpec(
  color: Color(0xff050911),
  offset: Offset(2, 2),
  inset: 3,
  layers: 4,
  maxAlpha: 0.22,
);

double diagonalSlant(
  Size size, {
  double angleDegrees = 80,
  double radius = 7,
  bool fullHeight = false,
}) {
  if (size.isEmpty) {
    return 0;
  }
  final safeRadius = radius.clamp(0, math.min(size.width, size.height) / 2);
  final verticalRun = fullHeight
      ? size.height
      : math.max(0, size.height - safeRadius * 2);
  final requested =
      verticalRun / math.max(0.01, math.tan(angleDegrees * math.pi / 180));
  return math.min(requested, math.min(size.width * 0.24, size.height * 0.48));
}

Path roundedPolygonPath(List<Offset> points, double radius) {
  assert(points.length >= 3);
  final path = Path();
  final starts = <Offset>[];
  final ends = <Offset>[];

  for (var index = 0; index < points.length; index++) {
    final previous = points[(index - 1 + points.length) % points.length];
    final current = points[index];
    final next = points[(index + 1) % points.length];
    final before = (previous - current).distance;
    final after = (next - current).distance;
    final resolvedRadius = math.min(radius, math.min(before, after) / 2);
    starts.add(
      current +
          (previous - current) * (resolvedRadius / math.max(0.001, before)),
    );
    ends.add(
      current + (next - current) * (resolvedRadius / math.max(0.001, after)),
    );
  }

  path.moveTo(ends.last.dx, ends.last.dy);
  for (var index = 0; index < points.length; index++) {
    path
      ..lineTo(starts[index].dx, starts[index].dy)
      ..quadraticBezierTo(
        points[index].dx,
        points[index].dy,
        ends[index].dx,
        ends[index].dy,
      );
  }
  return path..close();
}

Path buildRightCutSectionPath(
  Size size, {
  double angleDegrees = 80,
  double radius = 7,
  double inset = 0,
}) {
  final surface = Size(
    math.max(1, size.width - inset),
    math.max(1, size.height - inset),
  );
  final cut = diagonalSlant(
    surface,
    angleDegrees: angleDegrees,
    radius: radius,
  );
  return roundedPolygonPath([
    Offset.zero,
    Offset(surface.width, 0),
    Offset(surface.width - cut, surface.height),
    Offset(0, surface.height),
  ], radius);
}

double rightCutBoundaryInset(
  Size size,
  double y, {
  double angleDegrees = 80,
  double radius = 7,
  double inset = 0,
}) {
  final surface = Size(
    math.max(1, size.width - inset),
    math.max(1, size.height - inset),
  );
  final safeRadius = radius.clamp(
    0,
    math.min(surface.width, surface.height) / 2,
  );
  final cut = diagonalSlant(
    surface,
    angleDegrees: angleDegrees,
    radius: radius,
  );
  final progress =
      ((y - safeRadius) / math.max(0.001, surface.height - safeRadius * 2))
          .clamp(0, 1);
  return cut * progress;
}

class DiagonalTrapezoidSection extends StatelessWidget {
  const DiagonalTrapezoidSection({
    super.key,
    required this.child,
    this.angleDegrees = 80,
    this.radius = 7,
    this.shadow = _defaultSectionShadow,
  });

  final Widget child;
  final double angleDegrees;
  final double radius;
  final LiftedPathShadowSpec shadow;

  @override
  Widget build(BuildContext context) {
    final clipper = _RightCutSectionClipper(
      angleDegrees: angleDegrees,
      radius: radius,
      inset: shadow.inset,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: CustomPaint(
            painter: _RightCutSectionShadowPainter(
              angleDegrees: angleDegrees,
              radius: radius,
              shadow: shadow,
            ),
          ),
        ),
        ClipPath(
          clipper: clipper,
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.surface.withValues(alpha: 0.58),
                    AppColors.surfaceRaised.withValues(alpha: 0.31),
                  ],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class DiagonalMenuRow extends StatelessWidget {
  const DiagonalMenuRow({
    super.key,
    required this.children,
    this.weights,
    this.seamGap = 10,
    this.angleDegrees = 80,
    this.radius = 7,
  }) : assert(weights == null || weights.length == children.length);

  final List<Widget> children;
  final List<double>? weights;
  final double seamGap;
  final double angleDegrees;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomMultiChildLayout(
      delegate: _DiagonalMenuRowDelegate(
        count: children.length,
        weights: weights,
        seamGap: seamGap,
        angleDegrees: angleDegrees,
        radius: radius,
      ),
      children: [
        for (var index = 0; index < children.length; index++)
          LayoutId(id: index, child: children[index]),
      ],
    );
  }
}

class DiagonalMenuButton extends StatefulWidget {
  const DiagonalMenuButton({
    super.key,
    required this.caption,
    required this.onTap,
    required this.child,
    this.extendLeft = false,
    this.cutRight = true,
    this.angleDegrees = 80,
    this.radius = 7,
  });

  final String caption;
  final VoidCallback onTap;
  final Widget child;
  final bool extendLeft;
  final bool cutRight;
  final double angleDegrees;
  final double radius;

  @override
  State<DiagonalMenuButton> createState() => _DiagonalMenuButtonState();
}

class _DiagonalMenuButtonState extends State<DiagonalMenuButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final clipper = _DiagonalButtonClipper(
      extendLeft: widget.extendLeft,
      cutRight: widget.cutRight,
      angleDegrees: widget.angleDegrees,
      radius: widget.radius,
    );
    return Semantics(
      button: true,
      label: widget.caption,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: ClipPath(
          clipper: clipper,
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: AppColors.surface,
            child: InkWell(
              onTap: widget.onTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  widget.child,
                  if (_hovered) const ColoredBox(color: Color(0x18ffffff)),
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _DiagonalButtonOutlinePainter(
                        extendLeft: widget.extendLeft,
                        cutRight: widget.cutRight,
                        angleDegrees: widget.angleDegrees,
                        radius: widget.radius,
                        color: _hovered ? AppColors.primary : AppColors.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Path buildDiagonalButtonPath(
  Size size, {
  required bool extendLeft,
  required bool cutRight,
  double angleDegrees = 80,
  double radius = 7,
}) {
  final slant = diagonalSlant(size, angleDegrees: angleDegrees, radius: radius);
  return roundedPolygonPath([
    Offset(extendLeft ? slant : 0, 0),
    Offset(size.width, 0),
    Offset(cutRight ? size.width - slant : size.width, size.height),
    Offset(0, size.height),
  ], radius);
}

class _DiagonalMenuRowDelegate extends MultiChildLayoutDelegate {
  _DiagonalMenuRowDelegate({
    required this.count,
    required this.weights,
    required this.seamGap,
    required this.angleDegrees,
    required this.radius,
  });

  final int count;
  final List<double>? weights;
  final double seamGap;
  final double angleDegrees;
  final double radius;

  @override
  void performLayout(Size size) {
    if (count == 0 || size.isEmpty) {
      return;
    }
    final slant = diagonalSlant(
      size,
      angleDegrees: angleDegrees,
      radius: radius,
    );
    final resolvedWeights = weights ?? List.filled(count, 1.0);
    final totalWeight = resolvedWeights.fold<double>(
      0,
      (total, weight) => total + math.max(0.01, weight),
    );
    final totalButtonWidth = size.width + (count - 1) * (slant - seamGap);
    var left = 0.0;

    for (var index = 0; index < count; index++) {
      final width = index == count - 1
          ? size.width - left
          : totalButtonWidth *
                math.max(0.01, resolvedWeights[index]) /
                totalWeight;
      final childSize = layoutChild(
        index,
        BoxConstraints.tightFor(width: math.max(1, width), height: size.height),
      );
      positionChild(index, Offset(left.roundToDouble(), 0));
      left += childSize.width - slant + seamGap;
    }
  }

  @override
  bool shouldRelayout(_DiagonalMenuRowDelegate oldDelegate) =>
      oldDelegate.count != count ||
      oldDelegate.weights != weights ||
      oldDelegate.seamGap != seamGap ||
      oldDelegate.angleDegrees != angleDegrees ||
      oldDelegate.radius != radius;
}

class _RightCutSectionClipper extends CustomClipper<Path> {
  const _RightCutSectionClipper({
    required this.angleDegrees,
    required this.radius,
    required this.inset,
  });

  final double angleDegrees;
  final double radius;
  final double inset;

  @override
  Path getClip(Size size) => buildRightCutSectionPath(
    size,
    angleDegrees: angleDegrees,
    radius: radius,
    inset: inset,
  );

  @override
  bool shouldReclip(_RightCutSectionClipper oldClipper) =>
      oldClipper.angleDegrees != angleDegrees ||
      oldClipper.radius != radius ||
      oldClipper.inset != inset;
}

class _DiagonalButtonClipper extends CustomClipper<Path> {
  const _DiagonalButtonClipper({
    required this.extendLeft,
    required this.cutRight,
    required this.angleDegrees,
    required this.radius,
  });

  final bool extendLeft;
  final bool cutRight;
  final double angleDegrees;
  final double radius;

  @override
  Path getClip(Size size) => buildDiagonalButtonPath(
    size,
    extendLeft: extendLeft,
    cutRight: cutRight,
    angleDegrees: angleDegrees,
    radius: radius,
  );

  @override
  bool shouldReclip(_DiagonalButtonClipper oldClipper) =>
      oldClipper.extendLeft != extendLeft ||
      oldClipper.cutRight != cutRight ||
      oldClipper.angleDegrees != angleDegrees ||
      oldClipper.radius != radius;
}

class _RightCutSectionShadowPainter extends CustomPainter {
  const _RightCutSectionShadowPainter({
    required this.angleDegrees,
    required this.radius,
    required this.shadow,
  });

  final double angleDegrees;
  final double radius;
  final LiftedPathShadowSpec shadow;

  @override
  void paint(Canvas canvas, Size size) {
    paintLiftedPathShadow(
      canvas,
      buildRightCutSectionPath(
        size,
        angleDegrees: angleDegrees,
        radius: radius,
        inset: shadow.inset,
      ),
      shadow,
    );
  }

  @override
  bool shouldRepaint(_RightCutSectionShadowPainter oldDelegate) =>
      oldDelegate.angleDegrees != angleDegrees ||
      oldDelegate.radius != radius ||
      oldDelegate.shadow != shadow;
}

class _DiagonalButtonOutlinePainter extends CustomPainter {
  const _DiagonalButtonOutlinePainter({
    required this.extendLeft,
    required this.cutRight,
    required this.angleDegrees,
    required this.radius,
    required this.color,
  });

  final bool extendLeft;
  final bool cutRight;
  final double angleDegrees;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      buildDiagonalButtonPath(
        size,
        extendLeft: extendLeft,
        cutRight: cutRight,
        angleDegrees: angleDegrees,
        radius: radius,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_DiagonalButtonOutlinePainter oldDelegate) =>
      oldDelegate.extendLeft != extendLeft ||
      oldDelegate.cutRight != cutRight ||
      oldDelegate.angleDegrees != angleDegrees ||
      oldDelegate.radius != radius ||
      oldDelegate.color != color;
}
