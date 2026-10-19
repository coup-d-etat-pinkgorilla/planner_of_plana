// 사선(skewX −10°) 바탕 (FE2-b).
//
// 시안의 세그먼트·토글 칩·단계 태그·필터 버튼은 버튼 상자는 그대로 두고 그 안의 바탕 span만
// `transform: skewX(-10deg)`(가운데 기준)로 기울인다. 그래서 바탕은 상자 밖으로 위·아래 각각
// 높이/tan80/2만큼 삐져나가고, 글자는 기울지 않는다.
// 여기서는 그 바탕을 r5 둥근 평행사변형(Q 곡선)으로 그린다. 테두리는 `box-shadow: inset`처럼
// 바탕 안쪽에만 그린다(path로 자른 2배 두께 stroke).
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';

/// [size] 상자를 가운데 기준으로 −10° 기울인 둥근 평행사변형.
Path skewBoxPath(Size size, {double radius = AppRadii.skew}) {
  final half = diagonalCutDepth(size.height) / 2;
  return diagonalRoundedPolygon(
    [
      Offset(half, 0),
      Offset(size.width + half, 0),
      Offset(size.width - half, size.height),
      Offset(-half, size.height),
    ],
    radius: radius,
    corner: DiagonalCornerStyle.quadratic,
  );
}

/// 사선 바탕 painter. [fill]·[gradient]로 채우고 [border]를 안쪽 [borderWidth]만큼 그린다.
class SkewBoxPainter extends CustomPainter {
  const SkewBoxPainter({
    this.fill,
    this.gradient,
    this.border,
    this.borderWidth = 0,
    this.radius = AppRadii.skew,
  });

  final Color? fill;
  final Gradient? gradient;
  final Color? border;
  final double borderWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = skewBoxPath(size, radius: radius);
    final gradient = this.gradient;
    final fill = this.fill;
    if (gradient != null) {
      canvas.drawPath(
        path,
        Paint()..shader = gradient.createShader(Offset.zero & size),
      );
    } else if (fill != null) {
      canvas.drawPath(path, Paint()..color = fill);
    }
    final border = this.border;
    if (border != null && borderWidth > 0) {
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth * 2
          ..color = border,
      );
      canvas.restore();
    }
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(SkewBoxPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.gradient != gradient ||
      oldDelegate.border != border ||
      oldDelegate.borderWidth != borderWidth ||
      oldDelegate.radius != radius;
}

/// 사선 바탕 위에 [child]를 올린다. 바탕은 상자 밖으로 조금 삐져나간다(시안과 같다).
class SkewBox extends StatelessWidget {
  const SkewBox({
    super.key,
    required this.child,
    this.fill,
    this.gradient,
    this.border,
    this.borderWidth = 0,
    this.radius = AppRadii.skew,
  });

  final Widget child;
  final Color? fill;
  final Gradient? gradient;
  final Color? border;
  final double borderWidth;
  final double radius;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: SkewBoxPainter(
      fill: fill,
      gradient: gradient,
      border: border,
      borderWidth: borderWidth,
      radius: radius,
    ),
    child: child,
  );
}
