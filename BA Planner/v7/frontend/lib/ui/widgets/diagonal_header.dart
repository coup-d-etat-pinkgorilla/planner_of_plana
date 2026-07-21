import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

Path buildRightCutRoundedPath(
  Size size, {
  double radius = 16,
  double angleDegrees = 80,
  double? cutDepth,
}) {
  final width = size.width;
  final height = size.height;
  final safeRadius = radius
      .clamp(0.0, width / 2)
      .clamp(0.0, height / 2)
      .toDouble();
  final resolvedCut =
      cutDepth ??
      math.max(0, height - safeRadius * 2) /
          math.max(0.01, math.tan(angleDegrees * math.pi / 180));
  final safeCut = resolvedCut.clamp(0.0, width - safeRadius * 2).toDouble();

  return Path()
    ..moveTo(safeRadius, 0)
    ..lineTo(width - safeRadius, 0)
    ..quadraticBezierTo(width, 0, width, safeRadius)
    ..lineTo(width - safeCut, height - safeRadius)
    ..quadraticBezierTo(
      width - safeCut,
      height,
      width - safeCut - safeRadius,
      height,
    )
    ..lineTo(safeRadius, height)
    ..quadraticBezierTo(0, height, 0, height - safeRadius)
    ..lineTo(0, safeRadius)
    ..quadraticBezierTo(0, 0, safeRadius, 0)
    ..close();
}

class DiagonalHeaderSurface extends StatelessWidget {
  const DiagonalHeaderSurface({
    super.key,
    required this.child,
    this.radius = 16,
    this.angleDegrees = 80,
    this.cutDepth,
    this.background,
  });

  final Widget child;
  final double radius;
  final double angleDegrees;
  final double? cutDepth;
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final resolvedCut = _resolvedHeaderCutDepth(
          size,
          radius: radius,
          angleDegrees: angleDegrees,
          cutDepth: cutDepth,
        );
        final clipper = _RightCutClipper(
          radius: radius,
          angleDegrees: angleDegrees,
          cutDepth: resolvedCut,
        );

        return CustomPaint(
          painter: _DiagonalHeaderPainter(
            radius: radius,
            angleDegrees: angleDegrees,
            cutDepth: resolvedCut,
          ),
          child: ClipPath(
            clipper: clipper,
            clipBehavior: Clip.antiAlias,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ?background,
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20 + resolvedCut, 16),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

double _resolvedHeaderCutDepth(
  Size size, {
  required double radius,
  required double angleDegrees,
  required double? cutDepth,
}) {
  final safeRadius = radius
      .clamp(0.0, size.width / 2)
      .clamp(0.0, size.height / 2)
      .toDouble();
  final resolved =
      cutDepth ??
      math.max(0, size.height - safeRadius * 2) /
          math.max(0.01, math.tan(angleDegrees * math.pi / 180));
  return resolved
      .clamp(0.0, math.max(0, size.width - safeRadius * 2))
      .toDouble();
}

class _RightCutClipper extends CustomClipper<Path> {
  const _RightCutClipper({
    required this.radius,
    required this.angleDegrees,
    required this.cutDepth,
  });

  final double radius;
  final double angleDegrees;
  final double cutDepth;

  @override
  Path getClip(Size size) => buildRightCutRoundedPath(
    size,
    radius: radius,
    angleDegrees: angleDegrees,
    cutDepth: cutDepth,
  );

  @override
  bool shouldReclip(_RightCutClipper oldClipper) =>
      oldClipper.radius != radius ||
      oldClipper.angleDegrees != angleDegrees ||
      oldClipper.cutDepth != cutDepth;
}

class _DiagonalHeaderPainter extends CustomPainter {
  const _DiagonalHeaderPainter({
    required this.radius,
    required this.angleDegrees,
    required this.cutDepth,
  });

  final double radius;
  final double angleDegrees;
  final double cutDepth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = buildRightCutRoundedPath(
      size,
      radius: radius,
      angleDegrees: angleDegrees,
      cutDepth: cutDepth,
    );
    final fill = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.surfaceRaised.withValues(alpha: 0.68),
          AppColors.surface.withValues(alpha: 0.58),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);

    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(_DiagonalHeaderPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.angleDegrees != angleDegrees ||
      oldDelegate.cutDepth != cutDepth;
}
