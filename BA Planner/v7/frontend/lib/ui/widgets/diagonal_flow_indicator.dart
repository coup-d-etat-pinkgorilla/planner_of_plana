import 'dart:math' as math;

import 'package:flutter/material.dart';

double diagonalParallelogramBottomCenterX({
  required double width,
  required double height,
}) => (width - height / math.tan(80 * math.pi / 180)) / 2;

class DiagonalFlowIndicator extends StatelessWidget {
  const DiagonalFlowIndicator({
    super.key,
    required this.parallelogramHeight,
    this.paintKey,
  });

  final double parallelogramHeight;
  final Key? paintKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const indicatorSize = Size(16, 10);
      final centerX = diagonalParallelogramBottomCenterX(
        width: constraints.maxWidth,
        height: parallelogramHeight,
      );
      return Stack(
        children: [
          Positioned(
            left: centerX - indicatorSize.width / 2,
            top: (constraints.maxHeight - indicatorSize.height) / 2,
            child: CustomPaint(
              key: paintKey,
              size: indicatorSize,
              painter: const _DiagonalFlowIndicatorPainter(),
            ),
          ),
        ],
      );
    },
  );
}

class _DiagonalFlowIndicatorPainter extends CustomPainter {
  const _DiagonalFlowIndicatorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = const Color(0xfff2b3ef).withValues(alpha: 0.88),
    );
  }

  @override
  bool shouldRepaint(_DiagonalFlowIndicatorPainter oldDelegate) => false;
}
