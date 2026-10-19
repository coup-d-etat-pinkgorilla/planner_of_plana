// 전술대항전 섹션 안 요소 자리(FE9-a `_SectionEdges` · `_placed`를 FE9-e 분석 화면과 함께 쓰려고 옮겼다, 식은 그대로).
//
// 섹션 변은 Studio element 꼭짓점(`sectionCanvasElementPolygon`)에서 읽는다. 오른쪽 면에 붙은 사다리꼴은 꼭짓점 순서가
// 위 오 · 아래 오 · 아래 왼 · 위 왼이고, 그 밖(왼쪽 사다리꼴 · 평행사변형)은 위 왼 · 위 오 · 아래 오 · 아래 왼이다.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../kit/section_frame.dart';
import '../kit/section_morph.dart' show sectionCanvasElementPolygon;
import '../studio/section_template.dart';
import '../studio/tactical_studio_layout.dart';

/// 요소 하나를 [rect]에 놓고 내용을 [scale]로 줄여 그린다.
Widget tacticalPlaced(String key, Rect rect, double scale, Widget child) =>
    Positioned.fromRect(
      key: ValueKey(key),
      rect: rect,
      child: SectionScaledBox(scale: scale, child: child),
    );

/// 섹션 변(콘텐츠 캔버스 좌표).
class TacticalSectionEdges {
  TacticalSectionEdges._(this._left, this._right, this.top, this.bottom);

  factory TacticalSectionEdges.of(Size size, SectionCanvasElement element) {
    final points = sectionCanvasElementPolygon(size, element);
    final rightTrapezoid =
        element.spec.mode == SectionShapeMode.trapezoid &&
        element.spec.face == SectionAttachmentFace.right;
    // 오른쪽 사다리꼴: 위 오 · 아래 오 · 아래 왼 · 위 왼.
    if (rightTrapezoid) {
      return TacticalSectionEdges._(
        (points[3], points[2]),
        (points[0], points[1]),
        points[0].dy,
        points[1].dy,
      );
    }
    // 왼쪽 사다리꼴 · 평행사변형: 위 왼 · 위 오 · 아래 오 · 아래 왼.
    return TacticalSectionEdges._(
      (points[0], points[3]),
      (points[1], points[2]),
      points[0].dy,
      points[3].dy,
    );
  }

  final (Offset, Offset) _left, _right;
  final double top, bottom;

  double leftX(double y) => _edgeX(_left.$1, _left.$2, y);
  double rightX(double y) => _edgeX(_right.$1, _right.$2, y);

  /// [spec] 자리: 왼쪽 = 요소 아래 높이의 왼쪽 변 + 간격, 오른쪽 = 요소 위 높이의 오른쪽 변 − 간격.
  Rect slot(TacticalSlotSpec spec, double scale) {
    final y = top + spec.top * scale;
    final height = spec.height * scale;
    final left = leftX(y + height) + spec.leftGap * scale;
    final right = rightX(y) - spec.rightGap * scale;
    return Rect.fromLTWH(left, y, math.max(0, right - left), height);
  }
}

double _edgeX(Offset a, Offset b, double y) {
  final span = b.dy - a.dy;
  if (span == 0) return a.dx;
  final t = ((y - a.dy) / span).clamp(0.0, 1.0).toDouble();
  return a.dx + (b.dx - a.dx) * t;
}
