// 키트 선 아이콘 (FE2-b). 시안 svg(viewBox 24, stroke 1.9, round cap·join)를 그대로 옮긴 것만 둔다.
// K1: 튜토리얼 체크 · 깃발(F3a `TutorialGlyph`)과 빈 상태 글리프(F3d `EmptyStateGlyph`, 같은 svg path)를 더했다. 빈 상태
// × 는 [KitGlyph.close]와 같은 path다. 튜토리얼 체크는 굵기 2.8을 [KitGlyphPainter.strokeWidth]로 준다.
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

  /// 체크 `M5 12.5l4.5 4.5L19 7.5`(튜토리얼은 굵기 2.8)
  check,

  /// 깃발 `M5 21V4M5 4h11l-2 4 2 4H5`
  flag,

  /// 스캔 틀 `M4 8V5a1 1 0 011-1h3M16 4h3…M4 12h16`
  scanFrame,

  /// 학생 둘 `circle 9 8 3.2 · M3 20c.8-3.6…`
  students,

  /// 상자 `M3 7l9-4 9 4v10l-9 4-9-4z · M3 7l9 4 9-4M12 11v10`
  box,

  /// 막대 `M4 20V10M10 20V4M16 20v-8M22 20H2`
  bars,

  /// 엇갈린 칼 `M4 4l10 10M14 18l4-4M4 20l5-5M20 4L10 14M6 14l4 4`
  swords,

  /// 돋보기 `circle 11 11 6 · M20 20l-4.5-4.5`
  search,

  /// 재생 `M7 4l13 8-13 8z`
  play,

  /// 연필 `M4 20h4L19 9l-4-4L4 16z`
  pencil,

  /// 더하기 `M12 5v14M5 12h14`
  plus,

  /// 오른쪽 화살표 `M5 12h14M13 6l6 6-6 6`
  arrowRight,
}

/// 키트 선 아이콘 굵기(시안 stroke 1.9).
const kitGlyphStroke = 1.9;

/// [glyph]의 path(24 단위).
Path kitGlyphPath(KitGlyph glyph) {
  const r1 = Radius.circular(1);
  return switch (glyph) {
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
    KitGlyph.check =>
      Path()
        ..moveTo(5, 12.5)
        ..lineTo(9.5, 17)
        ..lineTo(19, 7.5),
    KitGlyph.flag =>
      Path()
        ..moveTo(5, 21)
        ..lineTo(5, 4)
        ..moveTo(5, 4)
        ..lineTo(16, 4)
        ..lineTo(14, 8)
        ..lineTo(16, 12)
        ..lineTo(5, 12),
    KitGlyph.scanFrame =>
      Path()
        ..moveTo(4, 8)
        ..lineTo(4, 5)
        ..arcToPoint(const Offset(5, 4), radius: r1)
        ..lineTo(8, 4)
        ..moveTo(16, 4)
        ..lineTo(19, 4)
        ..arcToPoint(const Offset(20, 5), radius: r1)
        ..lineTo(20, 8)
        ..moveTo(20, 16)
        ..lineTo(20, 19)
        ..arcToPoint(const Offset(19, 20), radius: r1)
        ..lineTo(16, 20)
        ..moveTo(8, 20)
        ..lineTo(5, 20)
        ..arcToPoint(const Offset(4, 19), radius: r1)
        ..lineTo(4, 16)
        ..moveTo(4, 12)
        ..lineTo(20, 12),
    KitGlyph.students =>
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(9, 8), radius: 3.2))
        ..moveTo(3, 20)
        ..cubicTo(3.8, 16.4, 6.2, 14.5, 9, 14.5)
        ..cubicTo(11.8, 14.5, 14.2, 16.4, 15, 20)
        ..moveTo(15.5, 5.2)
        ..arcToPoint(const Offset(15.5, 10.8), radius: const Radius.circular(3))
        ..moveTo(17.5, 14.8)
        ..cubicTo(19.3, 15.4, 20.5, 17.2, 21, 20),
    KitGlyph.box =>
      Path()
        ..moveTo(3, 7)
        ..lineTo(12, 3)
        ..lineTo(21, 7)
        ..lineTo(21, 17)
        ..lineTo(12, 21)
        ..lineTo(3, 17)
        ..close()
        ..moveTo(3, 7)
        ..lineTo(12, 11)
        ..lineTo(21, 7)
        ..moveTo(12, 11)
        ..lineTo(12, 21),
    KitGlyph.bars =>
      Path()
        ..moveTo(4, 20)
        ..lineTo(4, 10)
        ..moveTo(10, 20)
        ..lineTo(10, 4)
        ..moveTo(16, 20)
        ..lineTo(16, 12)
        ..moveTo(22, 20)
        ..lineTo(2, 20),
    KitGlyph.swords =>
      Path()
        ..moveTo(4, 4)
        ..lineTo(14, 14)
        ..moveTo(14, 18)
        ..lineTo(18, 14)
        ..moveTo(4, 20)
        ..lineTo(9, 15)
        ..moveTo(20, 4)
        ..lineTo(10, 14)
        ..moveTo(6, 14)
        ..lineTo(10, 18),
    KitGlyph.search =>
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(11, 11), radius: 6))
        ..moveTo(20, 20)
        ..lineTo(15.5, 15.5),
    KitGlyph.play =>
      Path()
        ..moveTo(7, 4)
        ..lineTo(20, 12)
        ..lineTo(7, 20)
        ..close(),
    KitGlyph.pencil =>
      Path()
        ..moveTo(4, 20)
        ..lineTo(8, 20)
        ..lineTo(19, 9)
        ..lineTo(15, 5)
        ..lineTo(4, 16)
        ..close(),
    KitGlyph.plus =>
      Path()
        ..moveTo(12, 5)
        ..lineTo(12, 19)
        ..moveTo(5, 12)
        ..lineTo(19, 12),
    KitGlyph.arrowRight =>
      Path()
        ..moveTo(5, 12)
        ..lineTo(19, 12)
        ..moveTo(13, 6)
        ..lineTo(19, 12)
        ..lineTo(13, 18),
  };
}

/// [KitGlyph]를 상자 크기에 맞춰 그린다(24 단위를 상자 폭으로 늘린다). [strokeWidth]는 24 단위 굵기다(없으면
/// [kitGlyphStroke]).
class KitGlyphPainter extends CustomPainter {
  const KitGlyphPainter({
    required this.glyph,
    required this.color,
    this.strokeWidth,
  });

  final KitGlyph glyph;
  final Color color;
  final double? strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      kitGlyphPath(glyph),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth ?? kitGlyphStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(KitGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// 선 아이콘 한 개([size] 정사각형).
class KitGlyphIcon extends StatelessWidget {
  const KitGlyphIcon(
    this.glyph, {
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth,
  });

  final KitGlyph glyph;
  final double size;
  final Color color;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: KitGlyphPainter(
        glyph: glyph,
        color: color,
        strokeWidth: strokeWidth,
      ),
    ),
  );
}
