// 인벤토리 이력 그림(FE6-f). 키트에 스파크라인 · 증감 막대 원자가 없어 인벤토리 쪽에 둔다(키트 승격 후보, W-Data-Widgets
// `LineTrend` · `DivergingBars`).
//
// - [InventorySparklinePainter]: 시안 Inventory · Inventory-All 상세 "최근 변화" svg(높이 92). 바닥선 y 76(양옆 30 안쪽),
//   점은 x 30 → 폭 − 30에 같은 간격, 값은 y 68(최소) → 24(최대), 값 글자는 점 위 9(11px #9eb0c2), 시간 글자는 y 88
//   (10px #6f8397), 선 #71c7f4 2.5, 점 r 4. 모르는 값은 점 없이 선을 끊고 그 이웃 구간을 빗금으로 칠한다. 마지막 스캔 뒤
//   바뀐 지금 수량(수동 수정 등)은 속이 빈 점이다.
// - [InventoryChangeBar]: 시안 Inventory-Analysis S5 막대 칸(395 × 30). 가운데 축 x 171, 증가는 축 오른쪽(171부터),
//   감소는 축 왼쪽(169까지), 막대 높이 8 · 위 11 · 둥글기 4, 가장 긴 막대 156, 값 글자는 오른쪽 44 칸(351~395) 오른쪽 맞춤
//   12px 700, 증가 #58d6a7 · 감소 #f2b3ef.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../kit/hatch.dart';
import '../kit/stat_chart.dart';
import 'inventory_history.dart';

/// 스파크라인 치수(시안 svg).
abstract final class InventorySparklineMetrics {
  static const height = 92.0;
  static const sideInset = 30.0;
  static const baselineY = 76.0;
  static const lowY = 68.0;
  static const highY = 24.0;
  static const valueLabelGap = 9.0;
  static const timeLabelY = 88.0;
  static const lineWidth = 2.5;
  static const pointRadius = 4.0;
}

/// 상세 "최근 변화" 스파크라인.
class InventorySparklinePainter extends CustomPainter {
  const InventorySparklinePainter({required this.points});

  final List<InventorySparkPoint> points;

  /// [index] 점의 x(같은 간격, 점 하나면 왼쪽 안쪽).
  static double pointX(Size size, int count, int index) {
    const inset = InventorySparklineMetrics.sideInset;
    if (count <= 1) return inset;
    return inset + (size.width - inset * 2) * index / (count - 1);
  }

  /// [value]의 y. 값이 모두 같으면 가운데다.
  static double valueY(int value, int low, int high) {
    const lowY = InventorySparklineMetrics.lowY;
    const highY = InventorySparklineMetrics.highY;
    if (high == low) return (lowY + highY) / 2;
    return lowY + (value - low) / (high - low) * (highY - lowY);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(
        InventorySparklineMetrics.sideInset,
        InventorySparklineMetrics.baselineY,
      ),
      Offset(
        math.max(
          InventorySparklineMetrics.sideInset,
          size.width - InventorySparklineMetrics.sideInset,
        ),
        InventorySparklineMetrics.baselineY,
      ),
      Paint()
        ..color = StatChartPalette.axis
        ..strokeWidth = 1,
    );
    final known = [
      for (final point in points)
        if (point.value != null) point.value!,
    ];
    final low = known.isEmpty ? 0 : known.reduce(math.min);
    final high = known.isEmpty ? 0 : known.reduce(math.max);
    final count = points.length;
    Offset? at(int index) {
      final value = points[index].value;
      return value == null
          ? null
          : Offset(pointX(size, count, index), valueY(value, low, high));
    }

    // 모르는 점: 이웃 점 사이를 빗금으로.
    for (var index = 0; index < count; index++) {
      if (points[index].value != null) continue;
      final left = pointX(size, count, math.max(0, index - 1));
      final right = pointX(size, count, math.min(count - 1, index + 1));
      final rect = Rect.fromLTRB(
        left == right ? left - 12 : left,
        InventorySparklineMetrics.highY,
        left == right ? right + 12 : right,
        InventorySparklineMetrics.lowY,
      );
      paintHatch(canvas, Path()..addRect(rect));
    }
    // 선: 이웃 두 점을 다 알 때만 잇는다(모르는 구간은 끊긴다).
    final line = Paint()
      ..color = StatChartPalette.magnitude
      ..strokeWidth = InventorySparklineMetrics.lineWidth
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    for (var index = 1; index < count; index++) {
      final from = at(index - 1), to = at(index);
      if (from == null || to == null) continue;
      canvas.drawLine(from, to, line);
    }
    for (var index = 0; index < count; index++) {
      final point = points[index];
      final x = pointX(size, count, index);
      final center = at(index);
      if (center != null) {
        if (point.scan) {
          canvas.drawCircle(
            center,
            InventorySparklineMetrics.pointRadius,
            Paint()..color = StatChartPalette.magnitude,
          );
        } else {
          canvas.drawCircle(
            center,
            InventorySparklineMetrics.pointRadius,
            Paint()..color = const Color.fromRGBO(26, 44, 59, 1),
          );
          canvas.drawCircle(
            center,
            InventorySparklineMetrics.pointRadius,
            Paint()
              ..color = StatChartPalette.magnitude
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
      paintStatLabel(
        canvas,
        point.value == null ? '—' : '${point.value}',
        Offset(
          x,
          (center?.dy ??
                  (InventorySparklineMetrics.lowY +
                          InventorySparklineMetrics.highY) /
                      2) -
              InventorySparklineMetrics.valueLabelGap,
        ),
        alignment: Alignment.bottomCenter,
        fontSize: 11,
        color: StatChartPalette.valueLabel,
        fontWeight: AppType.regular,
      );
      if (point.label.isNotEmpty) {
        paintStatLabel(
          canvas,
          point.label,
          Offset(x, InventorySparklineMetrics.timeLabelY),
          alignment: Alignment.bottomCenter,
          fontSize: 10,
          color: StatChartPalette.axisLabel,
          fontWeight: AppType.regular,
        );
      }
    }
  }

  @override
  bool shouldRepaint(InventorySparklinePainter oldDelegate) {
    if (oldDelegate.points.length != points.length) return true;
    for (var index = 0; index < points.length; index++) {
      final a = oldDelegate.points[index], b = points[index];
      if (a.label != b.label || a.value != b.value || a.scan != b.scan) {
        return true;
      }
    }
    return false;
  }
}

/// S5 증감 막대 칸 치수(시안 `div` 395 × 30).
abstract final class InventoryChangeBarMetrics {
  static const width = 395.0;
  static const height = 30.0;
  static const axisX = 171.0;
  static const negativeEnd = 169.0;
  static const barTop = 11.0;
  static const barHeight = 8.0;
  static const barRadius = 4.0;
  static const maxBar = 156.0;
  static const valueLeft = 351.0;
  static const valueWidth = 44.0;
}

/// S5 증감 막대 한 칸(가운데 축 기준 오른쪽 증가 · 왼쪽 감소).
class InventoryChangeBar extends StatelessWidget {
  const InventoryChangeBar({
    super.key,
    required this.delta,
    required this.maxMagnitude,
  });

  final int delta;

  /// 가장 긴 막대(156px)에 해당하는 |증감|.
  final int maxMagnitude;

  @override
  Widget build(BuildContext context) {
    final color = delta >= 0 ? AppColors.success : AppColors.accent;
    final length = maxMagnitude <= 0
        ? 0.0
        : InventoryChangeBarMetrics.maxBar * delta.abs() / maxMagnitude;
    return SizedBox(
      width: InventoryChangeBarMetrics.width,
      height: InventoryChangeBarMetrics.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: delta >= 0
                ? InventoryChangeBarMetrics.axisX
                : InventoryChangeBarMetrics.negativeEnd - length,
            top: InventoryChangeBarMetrics.barTop,
            width: length,
            height: InventoryChangeBarMetrics.barHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(
                  InventoryChangeBarMetrics.barRadius,
                ),
              ),
            ),
          ),
          Positioned(
            left: InventoryChangeBarMetrics.valueLeft,
            top: 0,
            width: InventoryChangeBarMetrics.valueWidth,
            height: InventoryChangeBarMetrics.height,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                inventorySignedCount(delta),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: AppType.bodySmallSize,
                  fontWeight: AppType.bold,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
