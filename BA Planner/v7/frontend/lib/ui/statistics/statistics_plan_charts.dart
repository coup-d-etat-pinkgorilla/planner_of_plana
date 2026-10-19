// 통계 "계획 집계" C3 페이즈별 누적 부족 계단선(FE7-g, 시안 Stats-Plan C3 · Statistics-Proposal "단계 누적 → 계단선").
//
// 시안 SVG viewBox(494×207)에서 그린 뒤 키트 [StatChartFrame]이 균일 배율한다(B1 · C1 · C2와 같은 방식, 차트 라이브러리
// 없음). 글자는 성장 차트와 같은 공용 함수([statisticsChartText])다.
// - 재화마다 선 하나(서로 다른 재화 수량을 더하지 않는다, FD-033). 세로 = 그 재화의 누적 부족 / 계획 전체 필요량(시안
//   "누적 부족 (재화별 필요량 대비)"), 가로 = 단계가 있는 페이즈(P1 … Pn, 같은 간격). 값이 바뀌는 페이즈에서 세로로 올라가고
//   마지막 페이즈 뒤로 10 더 그은 끝에 재화 이름을 쓴다.
// - 첫 선(첫 부족 재화)은 분홍 2.4 · 흰 굵은 이름, 나머지는 회색 2 · 회색 이름. 첫 선이 처음 모자라는 페이즈에 분홍 점과
//   "첫 부족 · Pn".
// - 세로축 끝 = 가장 큰 값을 20% 단위로 올린 값(20~100%), 가운데 점선과 그 값의 절반 글자(시안 80% 축 · "40%").
// 누르는 동작은 없다(재화 근거는 C1 · C2에서 고른다).
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../statistics/statistics_plan_projection.dart';
import '../kit/stat_chart.dart';
import 'statistics_growth_charts.dart';

/// C3 설계 좌표(시안 viewBox).
const statisticsC3ViewBox = Size(494, 207);

/// 회색 선(#5d7184) · 첫 점 테두리(#16202c).
const _c3Line = Color(0xff5d7184);
const _c3DotStroke = Color(0xff16202c);

/// C3 설계 좌표(시안 line · path · text 좌표).
abstract final class StatisticsC3Geometry {
  /// P1 · Pn 가로 위치, 선 끝(마지막 페이즈 + 10), 이름 왼쪽(선 끝 + 6).
  static const firstX = 40.0;
  static const lastX = 344.2;
  static const tailX = 354.2;
  static const labelX = 360.2;
  static const labelMaxWidth = 494 - labelX;

  /// 0 기준선 · 축 끝 높이(시안 80% 축: 40%가 95.5).
  static const baseline = 177.0;
  static const plotTop = 14.0;

  /// 페이즈 글자 밑변, 축 글자 오른쪽 끝.
  static const phaseLabelY = 194.0;
  static const axisLabelRight = 34.0;

  /// 이름 글자 사이 최소 간격(겹치지 않게 아래로 민다).
  static const labelGap = 12.0;

  static double xOf(int index, int count) => count <= 1
      ? firstX
      : firstX + (lastX - firstX) * index / (count - 1);

  /// 세로축 끝 비율: 가장 큰 값을 20% 단위로 올린다(20~100%).
  static double axisMaxOf(double maxValue) =>
      ((maxValue * 5).ceil() / 5).clamp(0.2, 1.0).toDouble();

  static double yOf(double value, double axisMax) =>
      baseline - (baseline - plotTop) * value / axisMax;
}

/// C3 선 하나 값(painter 비교용).
@immutable
class StatisticsC3PaintLine {
  StatisticsC3PaintLine({
    required this.key,
    required this.label,
    required this.firstIndex,
    required List<double> values,
  }) : values = List.unmodifiable(values);

  factory StatisticsC3PaintLine.of(StatisticsC3Line line) =>
      StatisticsC3PaintLine(
        key: line.resourceKey,
        label: line.name,
        firstIndex: line.firstIndex,
        values: line.values,
      );

  final String key;
  final String label;
  final int firstIndex;
  final List<double> values;

  @override
  bool operator ==(Object other) =>
      other is StatisticsC3PaintLine &&
      other.key == key &&
      other.label == label &&
      other.firstIndex == firstIndex &&
      listEquals(other.values, values);

  @override
  int get hashCode =>
      Object.hash(key, label, firstIndex, Object.hashAll(values));
}

/// 계단선 경로: P1 값에서 시작해 페이즈마다 가로 → 세로, 마지막은 선 끝까지 가로.
Path statisticsC3StepPath(List<double> values, double axisMax) {
  final count = values.length;
  final path = Path();
  for (final (index, value) in values.indexed) {
    final x = StatisticsC3Geometry.xOf(index, count);
    final y = StatisticsC3Geometry.yOf(value, axisMax);
    if (index == 0) {
      path.moveTo(x, y);
    } else {
      path
        ..lineTo(x, StatisticsC3Geometry.yOf(values[index - 1], axisMax))
        ..lineTo(x, y);
    }
  }
  if (values.isNotEmpty) {
    path.lineTo(
      StatisticsC3Geometry.tailX,
      StatisticsC3Geometry.yOf(values.last, axisMax),
    );
  }
  return path;
}

/// 이름 글자 밑변(선 끝 + 4, 위에서부터 [StatisticsC3Geometry.labelGap] 이상 띄운다). [ends]는 선 끝 높이.
List<double> statisticsC3LabelBaselines(List<double> ends) {
  final order = [for (var index = 0; index < ends.length; index++) index]
    ..sort((a, b) => ends[a].compareTo(ends[b]));
  final result = List<double>.filled(ends.length, 0);
  double? previous;
  for (final index in order) {
    var y = ends[index] + 4;
    if (previous != null && y < previous + StatisticsC3Geometry.labelGap) {
      y = previous + StatisticsC3Geometry.labelGap;
    }
    result[index] = y;
    previous = y;
  }
  return result;
}

/// C3 페이즈별 누적 부족 painter.
class StatisticsCumulativeShortagePainter extends StatChartPainter {
  StatisticsCumulativeShortagePainter({
    required List<StatisticsC3PaintLine> lines,
    required List<int> phases,
  }) : lines = List.unmodifiable(lines),
       phases = List.unmodifiable(phases);

  /// 첫 선이 첫 부족 재화(분홍)다.
  final List<StatisticsC3PaintLine> lines;

  /// 가로축 페이즈 번호.
  final List<int> phases;

  double get axisMax => StatisticsC3Geometry.axisMaxOf(
    lines.fold<double>(
      0,
      (value, line) => math.max(value, line.values.fold(0.0, math.max)),
    ),
  );

  @override
  void paint(Canvas canvas, Size viewBox) {
    final axisMax = this.axisMax;
    final count = phases.length;
    canvas.drawLine(
      const Offset(StatisticsC3Geometry.firstX, StatisticsC3Geometry.baseline),
      const Offset(StatisticsC3Geometry.tailX, StatisticsC3Geometry.baseline),
      Paint()
        ..color = StatChartPalette.axis
        ..strokeWidth = 1,
    );
    final midY = StatisticsC3Geometry.yOf(axisMax / 2, axisMax);
    _dashed(
      canvas,
      Offset(StatisticsC3Geometry.firstX, midY),
      Offset(StatisticsC3Geometry.tailX, midY),
    );
    statisticsChartText(
      canvas,
      '${(axisMax * 50).round()}%',
      Offset(StatisticsC3Geometry.axisLabelRight, midY + 4),
      align: TextAlign.end,
      fontSize: 10,
      color: StatChartPalette.axisLabel,
    );
    statisticsChartText(
      canvas,
      '0',
      const Offset(
        StatisticsC3Geometry.axisLabelRight,
        StatisticsC3Geometry.baseline + 4,
      ),
      align: TextAlign.end,
      fontSize: 10,
      color: StatChartPalette.axisLabel,
    );
    for (final (index, phase) in phases.indexed) {
      statisticsChartText(
        canvas,
        'P$phase',
        Offset(
          StatisticsC3Geometry.xOf(index, count),
          StatisticsC3Geometry.phaseLabelY,
        ),
        color: StatChartPalette.axisLabel,
      );
    }
    final labels = statisticsC3LabelBaselines([
      for (final line in lines)
        StatisticsC3Geometry.yOf(
          line.values.isEmpty ? 0 : line.values.last,
          axisMax,
        ),
    ]);
    // 회색 선을 먼저, 첫 선(분홍)을 맨 위에 그린다.
    for (final (index, line) in lines.indexed.toList().reversed) {
      final first = index == 0;
      canvas.drawPath(
        statisticsC3StepPath(line.values, axisMax),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = first ? 2.4 : 2
          ..strokeJoin = StrokeJoin.round
          ..color = first ? StatChartPalette.highlight : _c3Line,
      );
      statisticsChartText(
        canvas,
        line.label,
        Offset(StatisticsC3Geometry.labelX, labels[index]),
        align: TextAlign.start,
        fontSize: 11,
        fontWeight: first ? AppType.bold : AppType.semiBold,
        color: first ? AppColors.text : StatChartPalette.valueLabel,
        maxWidth: StatisticsC3Geometry.labelMaxWidth,
      );
    }
    if (lines.isNotEmpty && phases.isNotEmpty) {
      final line = lines.first;
      final index = line.firstIndex.clamp(0, line.values.length - 1);
      final center = Offset(
        StatisticsC3Geometry.xOf(index, count),
        StatisticsC3Geometry.yOf(line.values[index], axisMax),
      );
      canvas.drawCircle(center, 6, Paint()..color = StatChartPalette.highlight);
      canvas.drawCircle(
        center,
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _c3DotStroke,
      );
      statisticsChartText(
        canvas,
        '첫 부족 · P${phases[index]}',
        center + const Offset(8, 16),
        align: TextAlign.start,
        fontSize: 11,
        fontWeight: AppType.bold,
        color: StatChartPalette.highlight,
      );
    }
    statisticsChartText(
      canvas,
      '누적 부족 (재화별 필요량 대비)',
      const Offset(42, 16),
      align: TextAlign.start,
      color: StatChartPalette.axisLabel,
    );
  }

  /// 2-4 점선(시안 stroke-dasharray "2 4").
  void _dashed(Canvas canvas, Offset from, Offset to) {
    final paint = Paint()
      ..color = StatChartPalette.axis
      ..strokeWidth = 1;
    final total = (to - from).distance;
    if (total == 0) return;
    final direction = (to - from) / total;
    for (var start = 0.0; start < total; start += 6) {
      canvas.drawLine(
        from + direction * start,
        from + direction * math.min(start + 2, total),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(StatisticsCumulativeShortagePainter oldPainter) =>
      !listEquals(oldPainter.lines, lines) ||
      !listEquals(oldPainter.phases, phases);
}

/// C3 그래프.
class StatisticsCumulativeShortageChart extends StatelessWidget {
  const StatisticsCumulativeShortageChart({
    super.key,
    required this.lines,
    required this.phases,
  });

  final List<StatisticsC3Line> lines;
  final List<int> phases;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: Alignment.centerLeft,
      child: StatChartFrame(
        key: const ValueKey('statistics-c3-chart'),
        viewBox: statisticsC3ViewBox,
        scale: statisticsChartScale(constraints.biggest, statisticsC3ViewBox),
        semanticLabel: '페이즈별 누적 부족',
        painter: StatisticsCumulativeShortagePainter(
          lines: [for (final line in lines) StatisticsC3PaintLine.of(line)],
          phases: phases,
        ),
      ),
    ),
  );
}
