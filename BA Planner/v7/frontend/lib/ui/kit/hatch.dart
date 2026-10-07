// 빗금 채움 (FE2-d).
//
// 모르는 값(스캔 없음·해당 없음)은 0으로 채우지 않고 빗금으로 그린다(워크플로 불변식 "데이터 의미").
// 시안 Stats-Growth `pattern#hx`: 7×7 칸을 45° 돌리고, 바탕 rgba(158,176,194,.07) 위에 선 rgba(158,176,194,.45).
// 선은 칸 가장자리(x=0)에 2px로 그려 칸에 잘리므로 화면에는 1px 폭으로 보인다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 빗금 모양.
@immutable
class HatchStyle {
  const HatchStyle({
    this.background = const Color.fromRGBO(158, 176, 194, 0.07),
    this.line = const Color.fromRGBO(158, 176, 194, 0.45),
    this.lineWidth = 1,
    this.spacing = 7,
    this.angleDegrees = 45,
  });

  /// 통계 "모름" 빗금(시안 `#hx`).
  static const unknown = HatchStyle();

  final Color background;
  final Color line;
  final double lineWidth;

  /// 선과 선 사이(선에 수직으로 잰 거리).
  final double spacing;

  /// 세로선을 시계 방향으로 돌리는 각도(SVG `rotate`와 같은 방향).
  final double angleDegrees;

  @override
  bool operator ==(Object other) =>
      other is HatchStyle &&
      other.background == background &&
      other.line == line &&
      other.lineWidth == lineWidth &&
      other.spacing == spacing &&
      other.angleDegrees == angleDegrees;

  @override
  int get hashCode =>
      Object.hash(background, line, lineWidth, spacing, angleDegrees);
}

/// [area] 안을 [style] 빗금으로 채운다. 선은 [area] 밖으로 나가지 않는다.
void paintHatch(Canvas canvas, Path area, {HatchStyle style = HatchStyle.unknown}) {
  final bounds = area.getBounds();
  if (bounds.isEmpty) return;
  canvas.save();
  canvas.clipPath(area);
  canvas.drawPath(area, Paint()..color = style.background);
  final paint = Paint()
    ..color = style.line
    ..strokeWidth = style.lineWidth;
  // 영역 가운데를 기준으로 돌린 좌표계에서 세로선을 긋는다. 돌린 뒤에도 덮이도록 대각선 길이만큼 긋는다.
  final reach = math.sqrt(
        bounds.width * bounds.width + bounds.height * bounds.height,
      ) /
      2;
  canvas.translate(bounds.center.dx, bounds.center.dy);
  canvas.rotate(style.angleDegrees * math.pi / 180);
  final count = (reach / style.spacing).ceil();
  for (var index = -count; index <= count; index++) {
    final x = index * style.spacing + style.lineWidth / 2;
    canvas.drawLine(Offset(x, -reach), Offset(x, reach), paint);
  }
  canvas.restore();
}

/// 빗금 사각형([HatchStyle] 견본·범례용).
class HatchBox extends StatelessWidget {
  const HatchBox({
    super.key,
    this.style = HatchStyle.unknown,
    this.radius = 0,
    this.child,
  });

  final HatchStyle style;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: HatchPainter(style: style, radius: radius), child: child);
}

/// 상자 전체를 빗금으로 채우는 painter.
class HatchPainter extends CustomPainter {
  const HatchPainter({this.style = HatchStyle.unknown, this.radius = 0});

  final HatchStyle style;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) => paintHatch(
    canvas,
    Path()..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
    ),
    style: style,
  );

  @override
  bool shouldRepaint(HatchPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.radius != radius;
}
