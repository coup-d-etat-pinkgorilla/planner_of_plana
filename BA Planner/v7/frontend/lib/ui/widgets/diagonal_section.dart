import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Shared clipped glass surface with the v7 80-degree attachment edge.
class DiagonalSection extends StatelessWidget {
  const DiagonalSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const DiagonalSectionClipper(),
    clipBehavior: Clip.antiAlias,
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          border: Border.all(color: AppColors.outline),
        ),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    ),
  );
}

class DiagonalSectionClipper extends CustomClipper<Path> {
  const DiagonalSectionClipper();

  static const edgeAngleDegrees = 80.0;

  @override
  Path getClip(Size size) {
    final edgeHeight = math.min(126.0, size.height * 0.42);
    final edgeInset = edgeHeight / math.tan(edgeAngleDegrees * math.pi / 180);
    return Path()
      ..moveTo(0, 0)
      ..lineTo(math.max(0.0, size.width - edgeInset), 0)
      ..lineTo(size.width, edgeHeight)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(DiagonalSectionClipper oldDelegate) => false;
}
