// 인벤토리 분석 차트 painter(FE6-c, 시안 Inventory-Analysis S2·S4). 차트 라이브러리 없이 키트 차트 원자
// (`StatChartFrame`·`StatChartPainter`·`paintStatGridLine`·`paintStatLabel`·`paintHatch`) 위에 그린다.
//
// - S2 오파츠 산점도 [InventoryOopartScatterPainter]: 시안 svg 1012×420(배율 1). 플롯 영역 자체가 80° 평행사변형
//   (56,380)→(935,380)→(1002,0)→(123,0)이고, x = 계획 대비 보유율, y = 사용 학생 수다. 점의 x는 그 높이의 사선을
//   따라 민다. 점 색 = 티어(T1 #b8c4cf · T2 #71c7f4 · T3 #ffc66d · T4 #c89cf5), 반지름 T1~T3 5 · T4 7, 핵심 병목은
//   9 + 분홍 테두리 2.5. 같은 오파츠 티어끼리 선(rgba(56,81,107,.9) 1px)으로 잇고, 가장 높은 티어 점 왼쪽에 이름을 쓴다
//   (병목이면 분홍 굵게). 4분면 점선은 보유율 50% · 학생 수 축 절반이다.
//   확장(FE6-d, 시안 Inventory-Analysis-Opa svg 1974×1034.8)에서는 배치를 [InventoryScatterGeometry.at]으로 보간하고
//   점이 오파츠 아이콘 원(r 15 · 병목 22, 티어 색 28% + 테두리, 티어 글자)으로 크로스페이드한다(FD-103).
// - S4 히트맵 [InventoryTierHeatmapPainter]: 시안 `.hm.sk` CSS grid(라벨 열 56 + 티어 열 1fr, 간격 3, 칸 높이 26 r4)를
//   아래 왼쪽 기준 skewX(−10°)로 기울이고 글자는 세운다. 칸 색 rgba(113,199,244, .065 + .835 × 충족률), 글자는
//   65% 이상 #0c2233 · 20% 미만 #9eb0c2 · 나머지 #f4f8fb. 보유 모름은 빗금 + `—`, 계획에 안 쓰는 칸은 옅은 바탕만이다.
//   FE6-e 티어 화면(시안 Inventory-Tiers T1 · T2 · T4)도 같은 painter다: 라벨 열 폭(96 · 150)과 끝 "가장 부족" 열(128)을
//   받고, 그림이 들어가는 행 머리 · 가장 부족 칸 내용은 위젯이 [InventoryHeatmapGeometry.cellRect] 자리에 얹는다.
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/hatch.dart';
import '../kit/stat_chart.dart';
import 'inventory_analysis.dart';

/// 오파츠 티어 색(시안 T1~T4). 그 밖의 티어는 회색이다.
Color inventoryOopartTierColor(int tier) => switch (tier) {
  1 => const Color(0xffb8c4cf),
  2 => AppColors.primary,
  3 => AppColors.warning,
  4 => const Color(0xffc89cf5),
  _ => AppColors.textMuted,
};

/// S2 산점도 설계 좌표. 접힘(시안 Inventory-Analysis svg 1012×420)과 확장(시안 Inventory-Analysis-Opa svg 1974×1034.8)
/// 사이를 [InventoryScatterGeometry.at]으로 실수 보간한다(FE6-d, 확대 중 산점도 레이아웃 보간). 0에서는 FE6-c 값 그대로다.
@immutable
class InventoryScatterGeometry {
  const InventoryScatterGeometry._({
    required this.progress,
    required this.viewBox,
    required this.bottom,
    required this.width,
    required this.skew,
    required this.yZero,
    required this.ySpan,
    required this.xLabel,
    required this.yLabel,
    required this.labelSize,
    required this.nameOffset,
  });

  /// 접힘 → 확장 진행 [t](0~1)의 배치.
  factory InventoryScatterGeometry.at(double t) {
    double lerp(double a, double b) => lerpDouble(a, b, t)!;
    return InventoryScatterGeometry._(
      progress: t,
      viewBox: Size.lerp(collapsedViewBox, expandedViewBox, t)!,
      bottom: lerp(380, 994.8),
      // 플롯 아래 변 폭: 접힘 879(시안 56→935), 확장 1732.6(시안 56→1788.6).
      width: lerp(879, 1732.6),
      skew: diagonalCutDepth(lerp(380, 994.8)),
      // 학생 수 축: 0명 → 아래에서 18(확장은 같은 비율 47.1), 최대 → 위에서 18.
      yZero: lerp(362, 947.7),
      ySpan: lerp(344, 900.6),
      xLabel: Offset.lerp(const Offset(495, 406), const Offset(922, 1020.8), t)!,
      yLabel: Offset.lerp(const Offset(76, 190), const Offset(130, 497), t)!,
      labelSize: lerp(AppType.captionSize, 14.3),
      nameOffset: Offset.lerp(const Offset(-14, 4), const Offset(-28, 5.5), t)!,
    );
  }

  static const collapsedViewBox = Size(1012, 420);
  static const expandedViewBox = Size(1974, 1034.8);
  static const left = 56.0;

  /// 접힘 상태(FE6-c).
  static final collapsed = InventoryScatterGeometry.at(0);

  /// 확장 완료 상태.
  static final expanded = InventoryScatterGeometry.at(1);

  /// 접힘 0 → 확장 1.
  final double progress;
  final Size viewBox;

  /// 플롯 아래 변 y(위 변은 0).
  final double bottom;

  /// 플롯 아래 변 폭.
  final double width;

  /// 80° 사선이 플롯 높이에서 가로로 가는 거리(접힘 67 · 확장 175.4).
  final double skew;
  final double yZero;
  final double ySpan;

  /// 축 이름 자리("계획 대비 보유율 →" 가운데 · "사용 학생 수 →" 회전 중심)와 글자 크기(접힘 11 · 확장 14.3).
  final Offset xLabel;
  final Offset yLabel;
  final double labelSize;

  /// 오파츠 이름: 가장 높은 티어 점에서 떨어진 거리(오른쪽 끝 맞춤).
  final Offset nameOffset;

  double yFor(int students, int maxStudents) =>
      yZero - students / math.max(1, maxStudents) * ySpan;

  Offset pointFor(double fulfillment, int students, int maxStudents) {
    final y = yFor(students, maxStudents);
    return Offset(
      left + fulfillment.clamp(0.0, 1.0) * width + skew * (bottom - y) / bottom,
      y,
    );
  }

  /// 점 반지름: 접힘 T1~T3 5 · T4 7 · 핵심 병목 9, 아이콘(확장) 15 · 병목 22. [icons]는 점 → 아이콘 크로스페이드 진행이다.
  static double radiusFor(InventoryOopartPoint point, {double icons = 0}) {
    final dot = point.bottleneck ? 9.0 : (point.tier >= 4 ? 7.0 : 5.0);
    return lerpDouble(dot, iconRadiusFor(point), icons)!;
  }

  /// 아이콘 원 반지름(시안 r 15 · 병목 22).
  static double iconRadiusFor(InventoryOopartPoint point) =>
      point.bottleneck ? 22 : 15;

  /// 아이콘 그림이 잘리는 원 반지름(시안 clipPath r 13 · 병목 20).
  static double iconClipRadiusFor(InventoryOopartPoint point) =>
      iconRadiusFor(point) - 2;

  @override
  bool operator ==(Object other) =>
      other is InventoryScatterGeometry && other.progress == progress;

  @override
  int get hashCode => progress.hashCode;
}

/// S2 오파츠 산점도. 확장(FE6-d)에서는 [geometry]가 커지고, 점이 오파츠 아이콘 원으로 크로스페이드한다([icons], FD-103).
/// 아이콘 그림 자체는 위젯이 [iconSlots] 자리에 얹는다(그림이 없으면 이름 앞 두 글자).
class InventoryOopartScatterPainter extends StatChartPainter {
  InventoryOopartScatterPainter({
    required this.analysis,
    required this.tiers,
    this.hovered,
    InventoryScatterGeometry? geometry,
    this.icons = 0,
    this.selectedFamily,
  }) : geometry = geometry ?? InventoryScatterGeometry.collapsed;

  final InventoryOopartAnalysis analysis;

  /// 보이는 티어(티어 토글).
  final Set<int> tiers;

  /// 마우스가 올라간 점(재화 key).
  final String? hovered;

  /// 배치(접힘 · 확대 중 · 확장).
  final InventoryScatterGeometry geometry;

  /// 점 → 아이콘 크로스페이드 진행(0 점 · 1 아이콘).
  final double icons;

  /// 사용자가 고른 오파츠(선 · 점 고리 강조). 기본 선택은 표시하지 않는다(시안 확장 장면에 선택 표시가 없다).
  final String? selectedFamily;

  static const _axis = Color.fromRGBO(56, 81, 107, 0.8);
  static const _quadrant = Color.fromRGBO(56, 81, 107, 0.5);
  static const _line = Color.fromRGBO(56, 81, 107, 0.9);

  /// 아이콘 tier 글자 테두리(시안 #141e2b 3px).
  static const _tagStroke = Color(0xff141e2b);

  /// 보이는 점과 그 위치(그리는 순서).
  List<(InventoryOopartPoint, Offset)> visiblePoints() => [
    for (final series in analysis.series)
      for (final point in series.points)
        if (tiers.contains(point.tier))
          (
            point,
            geometry.pointFor(
              point.fulfillment,
              point.students,
              analysis.maxStudents,
            ),
          ),
  ];

  /// 아이콘 그림 자리(점, 중심, 잘리는 원 반지름).
  List<(InventoryOopartPoint, Offset, double)> iconSlots() => [
    for (final (point, center) in visiblePoints())
      (point, center, InventoryScatterGeometry.iconClipRadiusFor(point)),
  ];

  /// 설계 좌표 [position]에 있는 점(반지름 + 4 안, 위에 그린 것 먼저). 없으면 null.
  InventoryOopartPoint? hitTest(Offset position) {
    for (final (point, center) in visiblePoints().reversed) {
      if ((center - position).distance <=
          InventoryScatterGeometry.radiusFor(point, icons: icons) + 4) {
        return point;
      }
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size viewBox) {
    const left = InventoryScatterGeometry.left;
    final bottom = geometry.bottom;
    final width = geometry.width;
    final skew = geometry.skew;
    final plot = Path()
      ..moveTo(left, bottom)
      ..lineTo(left + width, bottom)
      ..lineTo(left + width + skew, 0)
      ..lineTo(left + skew, 0)
      ..close();
    canvas.drawPath(plot, Paint()..color = const Color.fromRGBO(255, 255, 255, 0.02));
    paintStatGridLine(
      canvas,
      Offset(left, bottom),
      Offset(left + width, bottom),
      color: _axis,
    );
    paintStatGridLine(
      canvas,
      Offset(left, bottom),
      Offset(left + skew, 0),
      color: _axis,
    );
    paintStatGridLine(
      canvas,
      Offset(left + width / 2, bottom),
      Offset(left + width / 2 + skew, 0),
      color: _quadrant,
      dashed: true,
    );
    paintStatGridLine(
      canvas,
      Offset(left + skew / 2, bottom / 2),
      Offset(left + width + skew / 2, bottom / 2),
      color: _quadrant,
      dashed: true,
    );
    paintStatLabel(
      canvas,
      '계획 대비 보유율 →',
      geometry.xLabel,
      fontSize: geometry.labelSize,
      color: AppColors.textMuted,
      fontWeight: AppType.regular,
    );
    canvas.save();
    canvas.translate(geometry.yLabel.dx, geometry.yLabel.dy);
    canvas.rotate(-80 * math.pi / 180);
    paintStatLabel(
      canvas,
      '사용 학생 수 →',
      Offset.zero,
      fontSize: geometry.labelSize,
      color: AppColors.textMuted,
      fontWeight: AppType.regular,
    );
    canvas.restore();

    final dots = (1 - icons).clamp(0.0, 1.0).toDouble();
    final rings = icons.clamp(0.0, 1.0).toDouble();
    for (final series in analysis.series) {
      final selected = series.family == selectedFamily;
      final points = [
        for (final point in series.points)
          if (tiers.contains(point.tier))
            (
              point,
              geometry.pointFor(
                point.fulfillment,
                point.students,
                analysis.maxStudents,
              ),
            ),
      ];
      if (points.isEmpty) continue;
      if (points.length > 1) {
        final path = Path()..moveTo(points.first.$2.dx, points.first.$2.dy);
        for (final (_, center) in points.skip(1)) {
          path.lineTo(center.dx, center.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 2 : 1
            ..color = selected ? AppColors.text.withValues(alpha: 0.8) : _line,
        );
      }
      for (final (point, center) in points) {
        final color = inventoryOopartTierColor(point.tier);
        if (dots > 0) {
          final radius = InventoryScatterGeometry.radiusFor(point);
          canvas.drawCircle(
            center,
            radius,
            Paint()..color = color.withValues(alpha: 0.95 * dots),
          );
          if (point.bottleneck) {
            canvas.drawCircle(
              center,
              radius,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5
                ..color = AppColors.accent.withValues(alpha: dots),
            );
          }
        }
        if (rings > 0) {
          // 확장: 티어 색 28% 원 + 테두리(티어 색 2px, 핵심 병목은 분홍 3px), 아래 오른쪽에 티어 글자.
          final radius = InventoryScatterGeometry.iconRadiusFor(point);
          canvas.drawCircle(
            center,
            radius,
            Paint()..color = color.withValues(alpha: 0.28 * rings),
          );
          canvas.drawCircle(
            center,
            radius,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = point.bottleneck ? 3 : 2
              ..color = (point.bottleneck ? AppColors.accent : color)
                  .withValues(alpha: rings),
          );
          _paintTierTag(
            canvas,
            'T${point.tier}',
            center + Offset(radius * 0.72, radius + 2),
            color.withValues(alpha: rings),
            _tagStroke.withValues(alpha: rings),
          );
        }
        final radius = InventoryScatterGeometry.radiusFor(point, icons: icons);
        if (point.key == hovered || selected) {
          canvas.drawCircle(
            center,
            radius + 3,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = AppColors.text,
          );
        }
      }
      // 이름: 가장 높은 티어 점의 왼쪽(시안 text-anchor end, 접힘 점 왼쪽 14 · 아래 4, 확장 왼쪽 28 · 아래 5.5).
      final (_, anchor) = points.last;
      paintStatLabel(
        canvas,
        series.label,
        anchor + geometry.nameOffset,
        alignment: const Alignment(1, 0.6),
        fontSize: geometry.labelSize,
        color: series.bottleneck ? AppColors.accentText : AppColors.textSecondary,
        fontWeight: series.bottleneck ? AppType.bold : AppType.medium,
      );
    }
  }

  /// 아이콘 아래 오른쪽 티어 글자(10px 800, 테두리 3px, 시안 paint-order stroke). [baseline]은 글자 기준선 왼쪽이다.
  static void _paintTierTag(
    Canvas canvas,
    String text,
    Offset baseline,
    Color fill,
    Color stroke,
  ) {
    TextPainter painter(Paint foreground) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w800,
          foreground: foreground,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final outline = painter(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..color = stroke,
    );
    final top = baseline - Offset(0, outline.computeDistanceToActualBaseline(TextBaseline.alphabetic));
    outline.paint(canvas, top);
    outline.dispose();
    final body = painter(Paint()..color = fill);
    body.paint(canvas, top);
    body.dispose();
  }

  @override
  bool shouldRepaint(InventoryOopartScatterPainter oldPainter) =>
      oldPainter.analysis != analysis ||
      oldPainter.hovered != hovered ||
      oldPainter.geometry != geometry ||
      oldPainter.icons != icons ||
      oldPainter.selectedFamily != selectedFamily ||
      !_sameSet(oldPainter.tiers, tiers);

  static bool _sameSet(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}

/// S4 히트맵 배치.
abstract final class InventoryHeatmapGeometry {
  static const labelWidth = 56.0;
  static const gap = 3.0;
  static const rowHeight = 26.0;
  static const minRowHeight = 16.0;
  static const radius = 4.0;

  /// skewX(−10°)의 가로 이동 비율(tan 10°).
  static final skew = 1 / diagonalTan80;

  /// 행 [rows]개(머리 줄 포함)가 [height] 안에 들도록 칸 높이를 줄인다(시안 26, 최소 16).
  static double rowHeightFor(int rows, double height) {
    if (rows <= 0) return rowHeight;
    final fit = (height - gap * (rows - 1)) / rows;
    return fit.clamp(minRowHeight, rowHeight).toDouble();
  }

  static double gridHeight(int rows, double rowHeight) =>
      rows * rowHeight + math.max(0, rows - 1) * gap;

  /// 티어 열 하나의 폭: 기울이기 전 grid 폭 [gridWidth]에서 라벨 열 · 끝 열([trailingWidth], 0이면 없음) · 간격을 뺀 몫.
  static double columnWidth(
    double gridWidth,
    int columns, {
    double labelWidth = InventoryHeatmapGeometry.labelWidth,
    double trailingWidth = 0,
  }) {
    final trailing = trailingWidth > 0 ? trailingWidth + gap : 0.0;
    return math.max(
      0.0,
      (gridWidth - labelWidth - trailing - gap * columns) / columns,
    );
  }

  /// 기울이기 전 칸 자리(행 [row]은 머리 줄 0부터, [column]은 −1 = 라벨 열 · 0부터 티어 열 · [columns] = 끝 열).
  static Rect cellRect(
    int row,
    int column, {
    required int columns,
    required double columnWidth,
    required double rowHeight,
    double labelWidth = InventoryHeatmapGeometry.labelWidth,
    double trailingWidth = 0,
  }) {
    final top = row * (rowHeight + gap);
    if (column < 0) return Rect.fromLTWH(0, top, labelWidth, rowHeight);
    return Rect.fromLTWH(
      labelWidth + gap + column * (columnWidth + gap),
      top,
      column >= columns ? trailingWidth : columnWidth,
      rowHeight,
    );
  }

  /// 기울인 grid(높이 [height])에서 칸 [rect]의 세운 내용이 놓이는 자리(칸 가운데 높이만큼 오른쪽으로 민다).
  static Rect uprightRect(Rect rect, double height) =>
      rect.shift(Offset(skew * (height - rect.center.dy), 0));
}

/// 칸 글자 색(시안 규칙).
Color inventoryHeatmapTextColor(double fulfillment) {
  if (fulfillment >= 0.65) return const Color(0xff0c2233);
  if (fulfillment < 0.2) return AppColors.textMuted;
  return AppColors.text;
}

/// 종류 × 티어 히트맵(S4 · FE6-e T1 · T2 · T4). 캔버스는 기울인 grid 전체(폭 = 기울이기 전 grid 폭 + `높이 × tan10°`)이고,
/// 아래 왼쪽이 원점이다.
class InventoryTierHeatmapPainter extends CustomPainter {
  const InventoryTierHeatmapPainter({
    required this.heatmap,
    required this.value,
    required this.amount,
    required this.rowHeight,
    this.labelWidth = InventoryHeatmapGeometry.labelWidth,
    this.trailingWidth = 0,
    this.trailingHeader,
    this.rowLabels = true,
  });

  final InventoryHeatmap heatmap;
  final InventoryHeatmapValue value;
  final String Function(int) amount;
  final double rowHeight;

  /// 라벨 열 폭(S4 56, 티어 화면 96 · 150).
  final double labelWidth;

  /// 끝 열 폭(티어 화면 "가장 부족" 128). 0이면 끝 열이 없다.
  final double trailingWidth;

  /// 끝 열 머리 글자(`가장 부족`).
  final String? trailingHeader;

  /// 행 라벨 글자를 painter가 쓴다. 티어 화면은 그림이 들어가 위젯이 쓴다(false).
  final bool rowLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final columns = heatmap.tiers;
    final rows = heatmap.rows.length + 1;
    final height = InventoryHeatmapGeometry.gridHeight(rows, rowHeight);
    final skew = InventoryHeatmapGeometry.skew;
    // 캔버스 폭 = 기울이기 전 grid 폭 + 윗변이 넘치는 폭.
    final gridWidth = size.width - skew * height;
    final columnWidth = InventoryHeatmapGeometry.columnWidth(
      gridWidth,
      columns,
      labelWidth: labelWidth,
      trailingWidth: trailingWidth,
    );
    Offset shift(double y) => Offset(skew * (height - y), 0);
    final fontSize = math.min(AppType.captionSize, rowHeight * 0.45);

    void cell(Rect rect, {Color? fill, bool hatch = false}) {
      final path = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            rect,
            const Radius.circular(InventoryHeatmapGeometry.radius),
          ),
        );
      // 아래 왼쪽 기준 skewX(−10°): x' = x + tan10° × (height − y).
      final skewed = path
          .transform(Matrix4.skewX(-math.atan(skew)).storage)
          .shift(Offset(skew * height, 0));
      if (hatch) {
        paintHatch(canvas, skewed);
      } else if (fill != null) {
        canvas.drawPath(skewed, Paint()..color = fill);
      }
    }

    void label(Rect rect, String text, Color color) {
      if (text.isEmpty) return;
      final center = rect.center + shift(rect.center.dy);
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: fontSize,
            height: 1.2,
            fontWeight: AppType.bold,
            color: color,
          ),
        ),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(0.0, rect.width - 4));
      painter.paint(
        canvas,
        Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
      );
      painter.dispose();
    }

    Rect rectAt(int row, int column) => InventoryHeatmapGeometry.cellRect(
      row,
      column,
      columns: columns,
      columnWidth: columnWidth,
      rowHeight: rowHeight,
      labelWidth: labelWidth,
      trailingWidth: trailingWidth,
    );

    for (var tier = 1; tier <= columns; tier++) {
      label(rectAt(0, tier - 1), heatmap.tierLabel(tier), AppColors.textMuted);
    }
    final trailingHeader = this.trailingHeader;
    if (trailingWidth > 0 && trailingHeader != null) {
      label(rectAt(0, columns), trailingHeader, AppColors.textMuted);
    }
    for (var index = 0; index < heatmap.rows.length; index++) {
      final row = heatmap.rows[index];
      if (rowLabels) {
        label(rectAt(index + 1, -1), row.label, AppColors.textMuted);
      }
      for (final item in row.cells) {
        final rect = rectAt(index + 1, item.tier - 1);
        if (!item.planned) {
          cell(rect, fill: const Color.fromRGBO(255, 255, 255, 0.03));
          continue;
        }
        final fulfillment = item.coverage.fulfillment;
        if (fulfillment == null) {
          cell(rect, hatch: true);
          label(rect, item.text(value, amount), AppColors.textMuted);
          continue;
        }
        cell(
          rect,
          fill: AppColors.primary.withValues(
            alpha: inventoryHeatmapAlpha(fulfillment),
          ),
        );
        label(rect, item.text(value, amount), inventoryHeatmapTextColor(fulfillment));
      }
    }
  }

  @override
  bool shouldRepaint(InventoryTierHeatmapPainter oldDelegate) =>
      oldDelegate.heatmap != heatmap ||
      oldDelegate.value != value ||
      oldDelegate.rowHeight != rowHeight ||
      oldDelegate.labelWidth != labelWidth ||
      oldDelegate.trailingWidth != trailingWidth ||
      oldDelegate.trailingHeader != trailingHeader ||
      oldDelegate.rowLabels != rowLabels;
}
