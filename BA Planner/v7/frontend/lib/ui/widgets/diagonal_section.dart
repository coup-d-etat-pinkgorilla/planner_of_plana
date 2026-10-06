import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'section_surface.dart';

/// 80° 부착 변을 가진 공용 섹션. 표면은 [SectionSurface](FE1-c, FD-006)를 쓴다:
/// surface@.76, 블러 없음, 테두리 없음, lifted shadow 4층.
class DiagonalSection extends StatelessWidget {
  const DiagonalSection({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SectionSurface(clipper: const DiagonalSectionClipper(), child: child);
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
