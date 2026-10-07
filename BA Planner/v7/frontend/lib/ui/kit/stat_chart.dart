// 통계·인벤토리 차트 원자 (FE2-d, F §7, FD-023 (a)).
//
// 차트 라이브러리를 쓰지 않고 CustomPainter로 그린다. 완성 그래프(히스토그램·꺾은선·히트맵 등)는 FE6·FE7이
// 이 원자 위에 만든다.
// - [StatChartFrame]: 시안 차트는 SVG viewBox(설계 좌표)에서 그린 뒤 `width = viewBox × 1.25`로 선·글자·마크를
//   함께 키운다(균일 배율, 종횡비 그대로). 여기서도 설계 좌표로 그리고 canvas를 한 번 배율한다.
// - [skewedBarPath]: 80° 막대(skewX −10°, 위 모서리 r4, 밑변 기준).
// - 빗금은 `hatch.dart`의 [paintHatch]다. 모르는 값은 빗금, 0은 빈 막대(바닥 표시만)로 그린다.
// - [StatChartScale]·[paintStatGridLine]·[paintStatLabel]: 축·기준선·눈금.
// - [StatChartPalette]: 크기 파랑, 강조·부족 분홍, 나머지 회색, 과잉 노랑, 상태 초록, 축·격자·라벨.
// - [StatChartHitMap]: 막대·칸·점의 path를 설계 좌표로 모아 두고 누른 자리를 찾는다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'hatch.dart';

/// 시안 차트 공통 배율(viewBox × 1.25).
const statChartScale = 1.25;

/// 차트 색.
abstract final class StatChartPalette {
  /// 크기(기본 막대·선) #71c7f4.
  static const magnitude = AppColors.primary;

  /// 히스토그램 기본 막대(#71c7f4, 불투명도 .78).
  static const magnitudeSoft = Color.fromRGBO(113, 199, 244, 0.78);

  /// 강조·부족·고른 구간 #f2b3ef.
  static const highlight = AppColors.accent;

  /// 나머지(회색) #9eb0c2.
  static const rest = AppColors.textMuted;

  /// 과잉(노랑) #ffc66d.
  static const excess = AppColors.warning;

  /// 상태·증가(초록) #7fe3bd.
  static const status = Color(0xff7fe3bd);

  /// ± 증감 막대: 증가 #58d6a7 / 감소 #f2b3ef.
  static const increase = AppColors.success;
  static const decrease = AppColors.accent;

  /// 축선 rgba(158,176,194,.22).
  static const axis = Color.fromRGBO(158, 176, 194, 0.22);

  /// 눈금·격자 rgba(158,176,194,.18).
  static const grid = Color.fromRGBO(158, 176, 194, 0.18);

  /// 축 라벨 #6f8397 / 값 라벨 #9eb0c2.
  static const axisLabel = AppColors.textDim;
  static const valueLabel = AppColors.textMuted;

  /// 차트 바탕 rgba(16,24,35,.55).
  static const surface = Color.fromRGBO(16, 24, 35, 0.55);
}

/// 값 → 설계 좌표 선형 변환.
@immutable
class StatChartScale {
  const StatChartScale({
    required this.domainMin,
    required this.domainMax,
    required this.rangeStart,
    required this.rangeEnd,
  }) : assert(domainMax != domainMin);

  final double domainMin;
  final double domainMax;

  /// [domainMin]이 놓이는 좌표(세로 축이면 보통 아래쪽 y).
  final double rangeStart;
  final double rangeEnd;

  double map(double value) =>
      rangeStart +
      (value - domainMin) / (domainMax - domainMin) * (rangeEnd - rangeStart);

  /// 좌표 → 값([map]의 역).
  double invert(double position) =>
      domainMin +
      (position - rangeStart) / (rangeEnd - rangeStart) * (domainMax - domainMin);
}

/// −10° 기울기 행렬(CSS `skewX(-10deg)`)을 [origin] 기준으로 적용한 행렬.
Matrix4 statSkewMatrix(Offset origin) =>
    Matrix4.translationValues(origin.dx, origin.dy, 0)
      ..multiply(Matrix4.skewX(-10 * math.pi / 180))
      ..multiply(Matrix4.translationValues(-origin.dx, -origin.dy, 0));

/// 80° 막대: [rect]를 위 모서리 [topRadius]로 둥글린 뒤 밑변 가운데 기준으로 −10° 기울인다.
///
/// 막대 위쪽이 오른쪽으로 기운다(밑변은 그대로). [origin]을 주면 그 점 기준으로 기울인다.
Path skewedBarPath(
  Rect rect, {
  double topRadius = 4,
  double bottomRadius = 0,
  Offset? origin,
}) {
  final top = Radius.circular(math.min(topRadius, rect.shortestSide / 2));
  final bottom = Radius.circular(math.min(bottomRadius, rect.shortestSide / 2));
  final path = Path()
    ..addRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: top,
        topRight: top,
        bottomLeft: bottom,
        bottomRight: bottom,
      ),
    );
  return path.transform(statSkewMatrix(origin ?? rect.bottomCenter).storage);
}

/// 가로 트랙(막대 행): 가운데 기준 −10°.
Path skewedTrackPath(Rect rect, {double radius = 3}) => (Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius))))
    .transform(statSkewMatrix(rect.center).storage);

/// 값 막대 하나를 그린다. [value]가 `null`이면 빗금(모름), 0이면 바닥에 1px 표시만(빈 막대).
///
/// [slot]은 막대가 놓일 칸(높이 전체), [scale]은 값 → y. 그린 막대의 path를 돌려준다(hit-test용).
Path paintValueBar(
  Canvas canvas, {
  required Rect slot,
  required double? value,
  required StatChartScale scale,
  required Color color,
  double topRadius = 4,
  HatchStyle hatch = HatchStyle.unknown,
}) {
  final baseY = scale.map(scale.domainMin);
  if (value == null) {
    final path = skewedBarPath(
      Rect.fromLTRB(slot.left, slot.top, slot.right, baseY),
      topRadius: topRadius,
    );
    paintHatch(canvas, path, style: hatch);
    return path;
  }
  final y = scale.map(value);
  if ((baseY - y).abs() < 1) {
    // 0: 막대 대신 바닥선만(빈 막대). 모름(빗금)과 구분된다.
    final path = skewedBarPath(
      Rect.fromLTRB(slot.left, baseY - 1, slot.right, baseY),
      topRadius: 0,
    );
    canvas.drawPath(path, Paint()..color = StatChartPalette.grid);
    return skewedBarPath(
      Rect.fromLTRB(slot.left, slot.top, slot.right, baseY),
      topRadius: 0,
    );
  }
  final path = skewedBarPath(
    Rect.fromLTRB(slot.left, math.min(y, baseY), slot.right, baseY),
    topRadius: topRadius,
  );
  canvas.drawPath(path, Paint()..color = color);
  return path;
}

/// 눈금·기준선·축선. [dashed]면 4-3 점선.
void paintStatGridLine(
  Canvas canvas,
  Offset from,
  Offset to, {
  Color color = StatChartPalette.grid,
  double width = 1,
  bool dashed = false,
}) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = width;
  if (!dashed) {
    canvas.drawLine(from, to, paint);
    return;
  }
  final total = (to - from).distance;
  if (total == 0) return;
  final direction = (to - from) / total;
  const dash = 4.0;
  const gap = 3.0;
  for (var start = 0.0; start < total; start += dash + gap) {
    final end = math.min(start + dash, total);
    canvas.drawLine(from + direction * start, from + direction * end, paint);
  }
}

/// 차트 글자. [anchor]에 [alignment] 기준으로 놓는다(예: 오른쪽 가운데 = 축 라벨).
void paintStatLabel(
  Canvas canvas,
  String text,
  Offset anchor, {
  Alignment alignment = Alignment.center,
  double fontSize = 10,
  Color color = StatChartPalette.axisLabel,
  FontWeight fontWeight = AppType.semiBold,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: AppFonts.body,
        fontFamilyFallback: AppFonts.fallback,
        fontSize: fontSize,
        height: 1.2,
        fontWeight: fontWeight,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final offset = Offset(
    anchor.dx - painter.width * (alignment.x + 1) / 2,
    anchor.dy - painter.height * (alignment.y + 1) / 2,
  );
  painter.paint(canvas, offset);
  painter.dispose();
}

/// 차트 마크의 hit 영역(설계 좌표). 나중에 넣은 것이 위에 있다.
class StatChartHitMap<T> {
  final _regions = <(T, Path)>[];

  /// [id]의 영역을 넣는다. [Path]는 설계 좌표다.
  void add(T id, Path path) => _regions.add((id, path));

  void clear() => _regions.clear();

  int get length => _regions.length;

  /// 설계 좌표 [point]에 있는 마크. 없으면 `null`.
  T? hitTest(Offset point) {
    for (final (id, path) in _regions.reversed) {
      if (path.contains(point)) return id;
    }
    return null;
  }
}

/// 설계 좌표에서 그리는 차트 painter.
abstract class StatChartPainter {
  const StatChartPainter();

  /// [viewBox] 크기의 설계 좌표로 그린다.
  void paint(Canvas canvas, Size viewBox);

  bool shouldRepaint(covariant StatChartPainter oldPainter);
}

/// 차트 틀: [viewBox] 설계 좌표 × [scale] 균일 배율(시안 `width = viewBox × 1.25`).
///
/// 위젯 크기는 `viewBox × scale`이다. [onTapAt]은 누른 자리를 설계 좌표로 넘긴다.
class StatChartFrame extends StatelessWidget {
  const StatChartFrame({
    super.key,
    required this.viewBox,
    required this.painter,
    this.scale = statChartScale,
    this.onTapAt,
    this.semanticLabel,
  });

  final Size viewBox;
  final StatChartPainter painter;
  final double scale;
  final ValueChanged<Offset>? onTapAt;
  final String? semanticLabel;

  /// 화면 크기.
  Size get size => viewBox * scale;

  /// 위젯 안 좌표 → 설계 좌표.
  Offset toViewBox(Offset local) => local / scale;

  /// 설계 좌표 → 위젯 안 좌표.
  Offset toLocal(Offset point) => point * scale;

  @override
  Widget build(BuildContext context) {
    final onTapAt = this.onTapAt;
    return Semantics(
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: onTapAt == null
            ? null
            : (details) => onTapAt(toViewBox(details.localPosition)),
        child: CustomPaint(
          size: size,
          painter: _ScaledChartPainter(painter: painter, scale: scale, viewBox: viewBox),
        ),
      ),
    );
  }
}

class _ScaledChartPainter extends CustomPainter {
  const _ScaledChartPainter({
    required this.painter,
    required this.scale,
    required this.viewBox,
  });

  final StatChartPainter painter;
  final double scale;
  final Size viewBox;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(scale);
    painter.paint(canvas, viewBox);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScaledChartPainter oldDelegate) =>
      oldDelegate.scale != scale ||
      oldDelegate.viewBox != viewBox ||
      oldDelegate.painter.runtimeType != painter.runtimeType ||
      painter.shouldRepaint(oldDelegate.painter);
}

/// 차트 바탕 rgba(16,24,35,.55) r8(꺾은선 바탕 등).
void paintStatSurface(Canvas canvas, Rect rect, {double radius = 8}) =>
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = StatChartPalette.surface,
    );
