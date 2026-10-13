// 통계 "학생 성장" A1 · A2 그래프(FE7-b, 시안 Stats-Growth, F §2.3 · §5 · §7).
//
// 둘 다 시안 SVG viewBox(설계 좌표)에서 그린 뒤 키트 [StatChartFrame]이 균일 배율한다(시안 viewBox × 1.25,
// 다른 창 크기에서는 타일 안 자리에 맞춘 배율). 차트 라이브러리 없이 키트 원자([paintValueBar] · [statSkewMatrix] ·
// [paintHatch] · [StatChartPalette])로 그린다.
// - A1 육성도 분포(viewBox 507×203): 10% 구간 기울어진 막대 10개(크기 파랑 α.72, 고른 구간 분홍), 고른 구간 위 인원,
//   평균 점선 + "평균 n%", 축 글자 0% · 40% · 100%(시안 그대로). 모르는 학생이 있으면 왼쪽 위 "n명 모름".
// - A2 항목별 완성도(viewBox 430×196): 공통 트랙 가로 막대 7행(FD-028 7항목, 시안 6행 + 애장품 — 사용자 확인
//   2026-10-13), 60% 기준 점선 + "60% 기준", 오른쪽 퍼센트. 60% 아래 항목은 분홍(시안), 아래 항목이 없으면 가장 낮은
//   항목 하나를 분홍으로 한다. 해당 학생이 없는 항목은 빗금 + '—'.
// 막대 · 행을 누르면 그 구간 · 항목을 고른다([StatChartFrame.onTapAt] → 설계 좌표 hit test).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../statistics/statistics_growth_projection.dart';
import '../kit/hatch.dart';
import '../kit/stat_chart.dart';

/// A1 · A2 설계 좌표(시안 viewBox).
const statisticsA1ViewBox = Size(507, 203);
const statisticsA2ViewBox = Size(430, 196);

final _tan10 = math.tan(10 * math.pi / 180);

/// A1 히스토그램 막대 색(시안 #71c7f4 · opacity .72).
const _histogramBar = Color.fromRGBO(113, 199, 244, 0.72);

/// A2 채움 막대(시안 #71c7f4 · opacity .8)와 트랙(rgba(255,255,255,.07)).
const _itemBar = Color.fromRGBO(113, 199, 244, 0.8);
const _itemTrack = Color.fromRGBO(255, 255, 255, 0.07);

/// 평균선(rgba(244,248,251,.6)) · 60% 기준선(rgba(242,179,239,.7)).
const _meanLine = Color.fromRGBO(244, 248, 251, 0.6);
const _thresholdLine = Color.fromRGBO(242, 179, 239, 0.7);

/// A1 설계 좌표(시안 path · text 좌표).
abstract final class StatisticsA1Geometry {
  /// 막대 밑변 y와 가장 높은 막대 윗변 y(141 = 최다 구간).
  static const baseline = 177.0;
  static const plotTop = 36.0;

  /// 0% · 100% x(축 글자 자리), 구간 폭 43.7, 막대 폭 31.5.
  static const axisStart = 34.0;
  static const axisEnd = 471.0;
  static const barWidth = 31.5;

  /// 축선 x 범위.
  static const axisLineStart = 28.0;
  static const axisLineEnd = 491.0;

  /// 축 · 평균 글자 기준선, 평균선 아래 끝(밑변 + 4), 위 끝(최다 막대 높이의 90%).
  static const labelBaseline = 194.0;
  static const meanLineBottom = 181.0;
  static double get meanLineTop => baseline - (baseline - plotTop) * 0.9;

  static double get binWidth =>
      (axisEnd - axisStart) / statisticsGrowthBinCount;

  /// [fraction](0~1)의 밑변 x.
  static double xOf(double fraction) =>
      axisStart + (axisEnd - axisStart) * fraction;

  /// 구간 [bin] 막대 칸(높이 전체, 기울이기 전).
  static Rect barSlot(int bin) {
    final left = axisStart + binWidth * bin + (binWidth - barWidth) / 2;
    return Rect.fromLTRB(left, plotTop, left + barWidth, baseline);
  }

  /// 구간 [bin]의 누르는 자리(막대 칸 전체를 80°로 기울인 모양).
  static Path hitPath(int bin) => skewedBarPath(barSlot(bin), topRadius: 0);
}

/// A2 설계 좌표(시안 rect · text 좌표). 행 간격은 첫 행 밑변 23 · 마지막 행 밑변 163 사이를 행 수로 나눈다
/// (시안 6행이면 28, 7행이면 23.3).
abstract final class StatisticsA2Geometry {
  static const firstBaseline = 23.0;
  static const lastBaseline = 163.0;
  static const barHeight = 16.0;
  static const trackLeft = 120.7;
  static const trackWidth = 239.7;
  static const labelLeft = 24.7;
  static const valueRight = 412.4;
  static const thresholdLabel = Offset(245.8, 180);
  static const unknownLabel = Offset(0, 180);

  static double pitch(int rows) =>
      rows <= 1 ? 0 : (lastBaseline - firstBaseline) / (rows - 1);

  /// 행 [index]의 막대 밑변 y.
  static double baselineOf(int index, int rows) =>
      firstBaseline + pitch(rows) * index;

  /// 행이 사선을 따라 왼쪽으로 밀리는 양.
  static double shiftOf(int index, int rows) =>
      (baselineOf(index, rows) - firstBaseline) * _tan10;

  /// 60% 기준선의 x(y).
  static double thresholdX(double y) =>
      trackLeft +
      trackWidth * statisticsGrowthLowThreshold +
      (firstBaseline - y) * _tan10;

  /// 행 [index]의 트랙(기울인 모양). [fraction]을 주면 그 길이의 채움 막대다.
  static Path barPath(int index, int rows, {double fraction = 1}) {
    final baseline = baselineOf(index, rows);
    final left = trackLeft - shiftOf(index, rows);
    final width = trackWidth * fraction.clamp(0.0, 1.0);
    final rect = Rect.fromLTWH(left, baseline - barHeight, width, barHeight);
    final radius = math.min(3.0, math.min(width, barHeight) / 2);
    return (Path()
          ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius))))
        .transform(statSkewMatrix(Offset(left, baseline)).storage);
  }

  /// 행 [index]의 누르는 자리(라벨부터 퍼센트까지 가로 띠).
  static Rect rowBand(int index, int rows) {
    final baseline = baselineOf(index, rows);
    final half = math.max(0.0, (pitch(rows) - barHeight) / 2);
    return Rect.fromLTRB(
      0,
      baseline - barHeight - half,
      statisticsA2ViewBox.width,
      baseline + half,
    );
  }
}

/// 설계 좌표 글자. [anchor]는 SVG처럼 기준선 위 점이고 [align]은 text-anchor(start · middle · end)다.
/// [maxWidth]를 주면 그 폭에서 말줄임한다(FE7-c 재화 이름). 통계 차트 painter 공용(FE7-b · FE7-c).
void statisticsChartText(
  Canvas canvas,
  String text,
  Offset anchor, {
  TextAlign align = TextAlign.center,
  double fontSize = 10.5,
  FontWeight fontWeight = AppType.semiBold,
  Color color = AppColors.text,
  bool display = false,
  double? maxWidth,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: display ? AppFonts.display : AppFonts.body,
        fontFamilyFallback: AppFonts.fallback,
        fontSize: fontSize,
        height: 1.2,
        fontWeight: display ? AppType.bold : fontWeight,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: maxWidth == null ? null : '…',
  )..layout(maxWidth: maxWidth ?? double.infinity);
  final baseline = painter.computeDistanceToActualBaseline(
    TextBaseline.alphabetic,
  );
  final dx = switch (align) {
    TextAlign.left || TextAlign.start => 0.0,
    TextAlign.right || TextAlign.end => painter.width,
    _ => painter.width / 2,
  };
  painter.paint(canvas, Offset(anchor.dx - dx, anchor.dy - baseline));
  painter.dispose();
}

/// 4-4 · 3-3 점선(시안 stroke-dasharray). 통계 차트 painter 공용.
void statisticsChartDashed(
  Canvas canvas,
  Offset from,
  Offset to, {
  required Color color,
  required double width,
  required double dash,
}) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = width;
  final total = (to - from).distance;
  if (total == 0) return;
  final direction = (to - from) / total;
  for (var start = 0.0; start < total; start += dash * 2) {
    final end = math.min(start + dash, total);
    canvas.drawLine(from + direction * start, from + direction * end, paint);
  }
}

String _unknownText(int count) => '$count명 모름';

/// A1 육성도 분포 painter.
class StatisticsGrowthHistogramPainter extends StatChartPainter {
  const StatisticsGrowthHistogramPainter({
    required this.counts,
    required this.mean,
    required this.unknownCount,
    this.selectedBin,
  });

  /// 구간별 인원(10개).
  final List<int> counts;

  /// 평균(0~1). 없으면 평균선을 그리지 않는다.
  final double? mean;
  final int unknownCount;
  final int? selectedBin;

  @override
  void paint(Canvas canvas, Size viewBox) {
    canvas.drawLine(
      const Offset(
        StatisticsA1Geometry.axisLineStart,
        StatisticsA1Geometry.baseline,
      ),
      const Offset(
        StatisticsA1Geometry.axisLineEnd,
        StatisticsA1Geometry.baseline,
      ),
      Paint()
        ..color = StatChartPalette.axis
        ..strokeWidth = 1,
    );
    final maxCount = counts.fold<int>(0, math.max);
    final scale = StatChartScale(
      domainMin: 0,
      domainMax: math.max(1, maxCount).toDouble(),
      rangeStart: StatisticsA1Geometry.baseline,
      rangeEnd: StatisticsA1Geometry.plotTop,
    );
    for (var bin = 0; bin < counts.length; bin++) {
      paintValueBar(
        canvas,
        slot: StatisticsA1Geometry.barSlot(bin),
        value: counts[bin].toDouble(),
        scale: scale,
        color: bin == selectedBin ? StatChartPalette.highlight : _histogramBar,
      );
    }
    final selected = selectedBin;
    if (selected != null && selected < counts.length && counts[selected] > 0) {
      final slot = StatisticsA1Geometry.barSlot(selected);
      final height =
          StatisticsA1Geometry.baseline -
          scale.map(counts[selected].toDouble());
      statisticsChartText(
        canvas,
        '${counts[selected]}명',
        Offset(
          slot.center.dx + height / 2 * _tan10,
          StatisticsA1Geometry.baseline - height - 8,
        ),
        fontSize: 13,
        display: true,
      );
    }
    final mean = this.mean;
    double? meanX;
    if (mean != null) {
      final x = StatisticsA1Geometry.xOf(mean);
      meanX = x;
      double lineX(double y) =>
          x + (StatisticsA1Geometry.baseline - y) * _tan10;
      final top = StatisticsA1Geometry.meanLineTop;
      statisticsChartDashed(
        canvas,
        Offset(
          lineX(StatisticsA1Geometry.meanLineBottom),
          StatisticsA1Geometry.meanLineBottom,
        ),
        Offset(lineX(top), top),
        color: _meanLine,
        width: 1.4,
        dash: 4,
      );
      statisticsChartText(
        canvas,
        '평균 ${statisticsPercentText(mean, decimals: 1)}',
        Offset(x, StatisticsA1Geometry.labelBaseline),
        fontWeight: AppType.bold,
      );
    }
    // 축 글자(시안 0% · 40% · 100%). 평균 글자와 겹치면 그 축 글자는 뺀다.
    for (final fraction in const [0.0, 0.4, 1.0]) {
      final x = StatisticsA1Geometry.xOf(fraction);
      if (meanX != null && (x - meanX).abs() < 36) continue;
      statisticsChartText(
        canvas,
        '${(fraction * 100).round()}%',
        Offset(x, StatisticsA1Geometry.labelBaseline),
        color: StatChartPalette.axisLabel,
      );
    }
    if (unknownCount > 0) {
      statisticsChartText(
        canvas,
        _unknownText(unknownCount),
        const Offset(StatisticsA1Geometry.axisLineStart, 10),
        align: TextAlign.start,
        color: StatChartPalette.valueLabel,
      );
    }
  }

  @override
  bool shouldRepaint(StatisticsGrowthHistogramPainter oldPainter) =>
      oldPainter.mean != mean ||
      oldPainter.unknownCount != unknownCount ||
      oldPainter.selectedBin != selectedBin ||
      !_listEquals(oldPainter.counts, counts);
}

/// A2 항목별 완성도 painter.
class StatisticsItemCompletionPainter extends StatChartPainter {
  const StatisticsItemCompletionPainter({
    required this.averages,
    required this.emphasized,
    required this.unknownCount,
    this.selectedItem,
  });

  final Map<StatisticsGrowthItem, double?> averages;
  final Set<StatisticsGrowthItem> emphasized;
  final int unknownCount;
  final StatisticsGrowthItem? selectedItem;

  @override
  void paint(Canvas canvas, Size viewBox) {
    const items = StatisticsGrowthItem.values;
    final rows = items.length;
    final top = 2.0;
    final bottom = 166.0;
    statisticsChartDashed(
      canvas,
      Offset(StatisticsA2Geometry.thresholdX(top), top),
      Offset(StatisticsA2Geometry.thresholdX(bottom), bottom),
      color: _thresholdLine,
      width: 1.2,
      dash: 3,
    );
    for (final (index, item) in items.indexed) {
      final baseline = StatisticsA2Geometry.baselineOf(index, rows);
      final shift = StatisticsA2Geometry.shiftOf(index, rows);
      final selected = item == selectedItem;
      statisticsChartText(
        canvas,
        item.label,
        Offset(StatisticsA2Geometry.labelLeft - shift, baseline - 3.2),
        align: TextAlign.start,
        fontSize: 12,
        color: selected ? AppColors.accentText : AppColors.text,
      );
      final track = StatisticsA2Geometry.barPath(index, rows);
      canvas.drawPath(track, Paint()..color = _itemTrack);
      final value = averages[item];
      if (value == null) {
        paintHatch(canvas, track);
      } else if (value > 0) {
        canvas.drawPath(
          StatisticsA2Geometry.barPath(index, rows, fraction: value),
          Paint()
            ..color = emphasized.contains(item)
                ? StatChartPalette.highlight
                : _itemBar,
        );
      }
      if (selected) {
        canvas.drawPath(
          track,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = StatChartPalette.highlight,
        );
      }
      statisticsChartText(
        canvas,
        value == null ? '—' : statisticsPercentText(value),
        Offset(StatisticsA2Geometry.valueRight - shift, baseline - 2.7),
        align: TextAlign.end,
        fontSize: 13,
        display: true,
      );
    }
    statisticsChartText(
      canvas,
      '${(statisticsGrowthLowThreshold * 100).round()}% 기준',
      StatisticsA2Geometry.thresholdLabel,
      align: TextAlign.start,
      color: StatChartPalette.highlight,
    );
    if (unknownCount > 0) {
      statisticsChartText(
        canvas,
        _unknownText(unknownCount),
        StatisticsA2Geometry.unknownLabel,
        align: TextAlign.start,
        color: StatChartPalette.valueLabel,
      );
    }
  }

  @override
  bool shouldRepaint(StatisticsItemCompletionPainter oldPainter) =>
      oldPainter.unknownCount != unknownCount ||
      oldPainter.selectedItem != selectedItem ||
      !_setEquals(oldPainter.emphasized, emphasized) ||
      !_mapEquals(oldPainter.averages, averages);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

bool _setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
  }
  return true;
}

/// 차트를 자리 안에 맞춘 배율(가로 · 세로 중 작은 쪽, 기준 viewport에서 시안 1.25).
double statisticsChartScale(Size available, Size viewBox) => math.max(
  0.0,
  math.min(available.width / viewBox.width, available.height / viewBox.height),
);

/// A1 그래프. 구간을 누르면 [onBinSelected](같은 구간을 다시 누르면 null).
class StatisticsGrowthHistogramChart extends StatelessWidget {
  const StatisticsGrowthHistogramChart({
    super.key,
    required this.histogram,
    required this.selectedBin,
    required this.onBinSelected,
  });

  final StatisticsGrowthHistogram histogram;
  final int? selectedBin;
  final ValueChanged<int?> onBinSelected;

  @override
  Widget build(BuildContext context) {
    final counts = [for (final bin in histogram.bins) bin.length];
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = statisticsChartScale(
          constraints.biggest,
          statisticsA1ViewBox,
        );
        return Align(
          alignment: Alignment.centerLeft,
          child: StatChartFrame(
            key: const ValueKey('statistics-a1-chart'),
            viewBox: statisticsA1ViewBox,
            scale: scale,
            semanticLabel: '${histogram.metric.label} 분포',
            painter: StatisticsGrowthHistogramPainter(
              counts: counts,
              mean: histogram.mean,
              unknownCount: histogram.unknownCount,
              selectedBin: selectedBin,
            ),
            onTapAt: (point) {
              for (var bin = 0; bin < counts.length; bin++) {
                if (counts[bin] == 0) continue;
                if (StatisticsA1Geometry.hitPath(bin).contains(point)) {
                  onBinSelected(bin == selectedBin ? null : bin);
                  return;
                }
              }
            },
          ),
        );
      },
    );
  }
}

/// A2 그래프. 항목 행을 누르면 [onItemSelected](같은 항목을 다시 누르면 null).
class StatisticsItemCompletionChart extends StatelessWidget {
  const StatisticsItemCompletionChart({
    super.key,
    required this.averages,
    required this.emphasized,
    required this.unknownCount,
    required this.selectedItem,
    required this.onItemSelected,
  });

  final Map<StatisticsGrowthItem, double?> averages;
  final Set<StatisticsGrowthItem> emphasized;
  final int unknownCount;
  final StatisticsGrowthItem? selectedItem;
  final ValueChanged<StatisticsGrowthItem?> onItemSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = statisticsChartScale(
        constraints.biggest,
        statisticsA2ViewBox,
      );
      const items = StatisticsGrowthItem.values;
      return Align(
        alignment: Alignment.centerLeft,
        child: StatChartFrame(
          key: const ValueKey('statistics-a2-chart'),
          viewBox: statisticsA2ViewBox,
          scale: scale,
          semanticLabel: '항목별 완성도',
          painter: StatisticsItemCompletionPainter(
            averages: averages,
            emphasized: emphasized,
            unknownCount: unknownCount,
            selectedItem: selectedItem,
          ),
          onTapAt: (point) {
            for (final (index, item) in items.indexed) {
              if (averages[item] == null) continue;
              if (StatisticsA2Geometry.rowBand(
                index,
                items.length,
              ).contains(point)) {
                onItemSelected(item == selectedItem ? null : item);
                return;
              }
            }
          },
        ),
      );
    },
  );
}
