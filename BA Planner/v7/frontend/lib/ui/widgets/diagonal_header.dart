import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

Path buildRightCutRoundedPath(
  Size size, {
  double radius = 16,
  double cutDepth = 34,
}) {
  final width = size.width;
  final height = size.height;
  final safeRadius = radius
      .clamp(0.0, width / 2)
      .clamp(0.0, height / 2)
      .toDouble();
  final safeCut = cutDepth.clamp(0.0, width - safeRadius * 2).toDouble();

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
    this.cutDepth = 34,
  });

  final Widget child;
  final double radius;
  final double cutDepth;

  @override
  Widget build(BuildContext context) {
    final clipper = _RightCutClipper(radius: radius, cutDepth: cutDepth);

    return CustomPaint(
      painter: _DiagonalHeaderPainter(radius: radius, cutDepth: cutDepth),
      child: ClipPath(
        clipper: clipper,
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20 + cutDepth, 16),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _RightCutClipper extends CustomClipper<Path> {
  const _RightCutClipper({required this.radius, required this.cutDepth});

  final double radius;
  final double cutDepth;

  @override
  Path getClip(Size size) =>
      buildRightCutRoundedPath(size, radius: radius, cutDepth: cutDepth);

  @override
  bool shouldReclip(_RightCutClipper oldClipper) =>
      oldClipper.radius != radius || oldClipper.cutDepth != cutDepth;
}

class _DiagonalHeaderPainter extends CustomPainter {
  const _DiagonalHeaderPainter({required this.radius, required this.cutDepth});

  final double radius;
  final double cutDepth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = buildRightCutRoundedPath(
      size,
      radius: radius,
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
      oldDelegate.radius != radius || oldDelegate.cutDepth != cutDepth;
}
