import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paint-only status treatment for a student portrait.
///
/// The overlay occupies its parent's existing bounds, ignores pointer input, and
/// therefore does not participate in layout. Screens with a custom portrait path
/// should clip this widget with the same path used for the portrait itself.
class StudentPortraitStatusOverlay extends StatelessWidget {
  const StudentPortraitStatusOverlay({
    super.key,
    required this.owned,
    this.style = const StudentPortraitStatusStyle(),
    this.showOverlay = true,
    this.showBadge = true,
  });

  final bool owned;
  final StudentPortraitStatusStyle style;
  final bool showOverlay;
  final bool showBadge;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: CustomPaint(
        painter: StudentPortraitStatusPainter(
          owned: owned,
          style: style,
          showOverlay: showOverlay,
          showBadge: showBadge,
        ),
        size: Size.infinite,
      ),
    ),
  );
}

@immutable
class StudentPortraitStatusStyle {
  const StudentPortraitStatusStyle({
    this.unownedLabel = 'UNOWNED',
    this.unownedOverlay = const Color.fromRGBO(6, 8, 14, 0.46),
    this.badgeColor = const Color.fromRGBO(6, 8, 14, 0.87),
    this.badgeBorderColor = const Color.fromRGBO(255, 255, 255, 0.16),
    this.badgeTextColor = const Color(0xfff2f2f2),
    this.badgeShadowColor = const Color.fromRGBO(0, 0, 0, 0.27),
  });

  final String unownedLabel;
  final Color unownedOverlay;
  final Color badgeColor;
  final Color badgeBorderColor;
  final Color badgeTextColor;
  final Color badgeShadowColor;
}

class StudentPortraitStatusPainter extends CustomPainter {
  const StudentPortraitStatusPainter({
    required this.owned,
    this.style = const StudentPortraitStatusStyle(),
    this.showOverlay = true,
    this.showBadge = true,
  });

  final bool owned;
  final StudentPortraitStatusStyle style;
  final bool showOverlay;
  final bool showBadge;

  @override
  void paint(Canvas canvas, Size size) {
    if (owned || size.isEmpty) return;
    paintUnownedStudentPortraitStatus(
      canvas,
      Offset.zero & size,
      style: style,
      showOverlay: showOverlay,
      showBadge: showBadge,
    );
  }

  @override
  bool shouldRepaint(StudentPortraitStatusPainter oldDelegate) =>
      oldDelegate.owned != owned ||
      oldDelegate.style != style ||
      oldDelegate.showOverlay != showOverlay ||
      oldDelegate.showBadge != showBadge;
}

/// Shared painter entry point for batched portrait surfaces such as grids.
///
/// The caller remains responsible for clipping or alpha-masking [portraitRect]
/// to its own portrait shape.
void paintUnownedStudentPortraitStatus(
  Canvas canvas,
  Rect portraitRect, {
  StudentPortraitStatusStyle style = const StudentPortraitStatusStyle(),
  bool showOverlay = true,
  bool showBadge = true,
}) {
  if (portraitRect.isEmpty) return;

  if (showOverlay) {
    canvas.drawRect(portraitRect, Paint()..color = style.unownedOverlay);
  }
  if (!showBadge) return;

  final badgeWidth = (portraitRect.width * 0.42)
      .clamp(
        math.min(32.0, portraitRect.width),
        math.min(92.0, portraitRect.width),
      )
      .toDouble();
  final badgeHeight = (portraitRect.height * 0.14)
      .clamp(
        math.min(14.0, portraitRect.height),
        math.min(28.0, portraitRect.height),
      )
      .toDouble();
  final horizontalInset = math.min(
    portraitRect.width * 0.08,
    math.max(0.0, portraitRect.width - badgeWidth),
  );
  final topInset = math.min(
    (portraitRect.height * 0.06).clamp(4.0, 18.0),
    math.max(0.0, portraitRect.height - badgeHeight),
  );
  final badgeRect = Rect.fromLTWH(
    portraitRect.left + horizontalInset,
    portraitRect.top + topInset,
    badgeWidth,
    badgeHeight,
  );
  paintStudentPortraitStatusBadge(
    canvas,
    badgeRect,
    style.unownedLabel,
    style: style,
  );
}

void paintStudentPortraitStatusBadge(
  Canvas canvas,
  Rect badgeRect,
  String label, {
  StudentPortraitStatusStyle style = const StudentPortraitStatusStyle(),
}) {
  if (badgeRect.isEmpty) return;
  final radius = Radius.circular(badgeRect.height / 2);
  canvas.drawRRect(
    RRect.fromRectAndRadius(badgeRect.shift(const Offset(0, 1)), radius),
    Paint()..color = style.badgeShadowColor,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(badgeRect, radius),
    Paint()..color = style.badgeColor,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(badgeRect, radius),
    Paint()
      ..color = style.badgeBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.75, badgeRect.height / 22),
  );

  final textPainter = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        color: style.badgeTextColor,
        fontSize: (badgeRect.height * 0.43).clamp(6.0, 12.0),
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    ),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: math.max(1, badgeRect.width - 4));
  textPainter.paint(
    canvas,
    Offset(
      badgeRect.center.dx - textPainter.width / 2,
      badgeRect.center.dy - textPainter.height / 2,
    ),
  );
}
