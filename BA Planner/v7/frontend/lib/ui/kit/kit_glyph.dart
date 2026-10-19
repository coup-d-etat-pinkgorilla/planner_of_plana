// 키트 선 아이콘 (FE2-b). 시안 svg(viewBox 24, stroke 1.9, round cap·join)를 그대로 옮긴 것만 둔다.
import 'package:flutter/material.dart';

/// 키트 안에서 쓰는 선 아이콘(시안 svg, viewBox 24, stroke 1.9, round).
enum KitGlyph {
  /// × `M6 6l12 12M18 6L6 18`
  close,

  /// 깔때기 `M4 5h16l-6 7v6l-4 2v-8z`
  filter,

  /// 아래 꺾쇠 `M6 9l6 6 6-6`
  chevronDown,

  /// 위 꺾쇠(아래 꺾쇠를 뒤집음)
  chevronUp,
}

/// [KitGlyph]를 상자 크기에 맞춰 그린다(24 단위를 상자 폭으로 늘린다).
class KitGlyphPainter extends CustomPainter {
  const KitGlyphPainter({required this.glyph, required this.color});

  final KitGlyph glyph;
  final Color color;

  Path _path() => switch (glyph) {
    KitGlyph.close =>
      Path()
        ..moveTo(6, 6)
        ..lineTo(18, 18)
        ..moveTo(18, 6)
        ..lineTo(6, 18),
    KitGlyph.filter =>
      Path()
        ..moveTo(4, 5)
        ..lineTo(20, 5)
        ..lineTo(14, 12)
        ..lineTo(14, 18)
        ..lineTo(10, 20)
        ..lineTo(10, 12)
        ..close(),
    KitGlyph.chevronDown =>
      Path()
        ..moveTo(6, 9)
        ..lineTo(12, 15)
        ..lineTo(18, 9),
    KitGlyph.chevronUp =>
      Path()
        ..moveTo(6, 15)
        ..lineTo(12, 9)
        ..lineTo(18, 15),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      _path(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(KitGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
