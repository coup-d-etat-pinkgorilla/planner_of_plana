// 작은 도는 표시 (K1, F3a `TutorialSpinner` 승격 — 시안 `.tut-spin`).
//
// 16px 원, 테두리 2.4 하늘색 · 오른쪽 한 변만 비움(원의 3/4), 1초에 한 바퀴. 움직임 줄이기 설정이면 멈춘다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 작은 도는 표시. 기본값은 시안 `.tut-spin`(16 · 2.4 · #71c7f4)이다.
class KitSpinner extends StatefulWidget {
  const KitSpinner({
    super.key,
    this.size = 16,
    this.strokeWidth = 2.4,
    this.color = AppColors.primary,
  });

  final double size;
  final double strokeWidth;
  final Color color;

  @override
  State<KitSpinner> createState() => _KitSpinnerState();
}

class _KitSpinnerState extends State<KitSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
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
    child: SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        painter: KitSpinnerPainter(
          strokeWidth: widget.strokeWidth,
          color: widget.color,
        ),
      ),
    ),
  );
}

/// 도는 표시 한 장(돌리기 전).
class KitSpinnerPainter extends CustomPainter {
  const KitSpinnerPainter({
    this.strokeWidth = 2.4,
    this.color = AppColors.primary,
  });

  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    // CSS: 테두리 4변 중 오른쪽만 투명 → 원의 3/4.
    canvas.drawArc(
      rect,
      math.pi * 3 / 4,
      math.pi * 3 / 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(KitSpinnerPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth || oldDelegate.color != color;
}
