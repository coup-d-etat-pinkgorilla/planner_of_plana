// 통계 3차 타일 A5 · C5 그래프(FE7-i, 시안 Stats-Growth A5 · Stats-Plan C5, F §2 시각 문법 · §5).
//
// 둘 다 시안 SVG viewBox(설계 좌표)에서 그린 뒤 키트 [StatChartFrame]이 균일 배율한다(FE7-b · FE7-f와 같은 방식, 차트
// 라이브러리 없음). 글자는 성장 차트 공용 함수([statisticsChartText])다.
// - A5 스킬 · 장비 매트릭스(viewBox 470×196): 단일 색조 히트맵. 칸은 80° 평행사변형(밑변 71.1 · 높이 26, 열 피치 75.1,
//   행 피치 30, 행마다 사선을 따라 왼쪽으로 30 × tan 10°). 칸 색 = #71c7f4 α(0.06 + 0.84 × 인원 / 가장 많은 칸 — 시안
//   α 값 21개가 이 식과 ±0.01 안에서 맞는다), α 0.6 이상이면 숫자는 어두운 #0c2233(시안). 해당 없는 칸은 빗금(키트
//   `#hx`)이다. 고른 칸은 분홍 테두리 2. 칸을 누르면 그 칸을 고른다(0명 · 빗금 칸은 고르지 않는다).
// - C5 미계획 학생(viewBox 1035×196, 전폭): 편성 행(스트라이커 · 스페셜)마다 가로축 육성도(0% 84 → 100% 1019.3)에 학생 점
//   (r 4.5 · 테두리 #16202c 2). 계획 있음 파랑 #71c7f4 · 미계획 회색 #5d7184 · 고른 구간(미계획 · 40% 미만) 분홍.
//   구간 자리(0 ~ 40%)는 분홍 점선 상자 + 아래 "미계획 · 40% 미만 n명"(KPI와 같은 함수)이고, 누르면 그 구간을 고른다
//   (고르면 상자 테두리가 실선). 점 세로 자리는 학생 id에서 정한 고정 흩뿌림(±11)이다(같은 학생은 늘 같은 자리).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../statistics/statistics_matrix_projection.dart';
import '../../statistics/statistics_supply_projection.dart'
    show statisticsUnplannedLowGrowth;
import '../kit/hatch.dart';
import '../kit/stat_chart.dart';
import 'statistics_growth_charts.dart';

/// A5 · C5 설계 좌표(시안 viewBox).
const statisticsA5ViewBox = Size(470, 196);
const statisticsC5ViewBox = Size(1035, 196);

final _tan10 = math.tan(10 * math.pi / 180);

/// 짙은 칸 위 숫자(시안 #0c2233).
const _darkValue = Color(0xff0c2233);

/// C5 미계획 점(시안 #5d7184) · 점 테두리(#16202c).
const _unplannedDot = Color(0xff5d7184);
const _dotStroke = Color(0xff16202c);

String _unknownText(int count) => '$count명 모름';

// --- A5 ----------------------------------------------------------------------

/// A5 설계 좌표(시안 polygon · text 좌표).
abstract final class StatisticsA5Geometry {
  /// 첫 행 밑변 · 행 피치 · 칸 높이.
  static const firstBottom = 48.0;
  static const rowPitch = 30.0;
  static const cellHeight = 26.0;

  /// 첫 행 첫 칸 밑변 왼쪽 · 칸 밑변 폭 · 열 피치.
  static const firstLeft = 71.2;
  static const cellWidth = 71.1;
  static const columnPitch = 75.1;

  /// 열 머리 글자(첫 열 가운데 x · y).
  static const headerX = 112.0;
  static const headerY = 14.0;

  /// 행 글자 오른쪽(칸 왼쪽에서 10) · 칸 숫자 기준선(칸 밑변에서 8.3 위).
  static const labelGap = 10.0;
  static const valueRise = 8.3;
  static const legend = Offset(464, 194);
  static const unknown = Offset(0, 194);

  static double bottomOf(int row) => firstBottom + rowPitch * row;
  static double leftOf(int row, int column) =>
      firstLeft - rowPitch * row * _tan10 + columnPitch * column;

  /// 칸 모양(80° 평행사변형, 위가 오른쪽으로).
  static Path cellPath(int row, int column) {
    final bottom = bottomOf(row);
    final left = leftOf(row, column);
    final skew = cellHeight * _tan10;
    return Path()
      ..moveTo(left, bottom)
      ..lineTo(left + cellWidth, bottom)
      ..lineTo(left + cellWidth + skew, bottom - cellHeight)
      ..lineTo(left + skew, bottom - cellHeight)
      ..close();
  }

  /// 칸 숫자 가운데 x(칸 세로 가운데 높이의 가운데).
  static double valueX(int row, int column) =>
      leftOf(row, column) + cellWidth / 2 + cellHeight / 2 * _tan10;

  /// 칸 색 α(시안: 0.06 + 0.84 × 인원 / 가장 많은 칸).
  static double alphaOf(int count, int maxCount) =>
      maxCount <= 0 ? 0.06 : 0.06 + 0.84 * count / maxCount;
}

/// A5 painter.
class StatisticsSkillMatrixPainter extends StatChartPainter {
  StatisticsSkillMatrixPainter({
    required this.counts,
    required this.unknownCount,
    this.selected,
  });

  factory StatisticsSkillMatrixPainter.of(
    StatisticsSkillMatrix matrix, {
    StatisticsMatrixCell? selected,
  }) => StatisticsSkillMatrixPainter(
    counts: [
      for (final row in StatisticsMatrixRow.values)
        [
          for (
            var column = 0;
            column < statisticsMatrixColumns.length;
            column++
          )
            matrix.count(row, column),
        ],
    ],
    unknownCount: matrix.unknownCount,
    selected: selected,
  );

  /// 행 × 열 인원.
  final List<List<int>> counts;
  final int unknownCount;
  final StatisticsMatrixCell? selected;

  @override
  void paint(Canvas canvas, Size viewBox) {
    var maxCount = 0;
    for (final row in counts) {
      for (final value in row) {
        maxCount = math.max(maxCount, value);
      }
    }
    for (var column = 0; column < statisticsMatrixColumns.length; column++) {
      statisticsChartText(
        canvas,
        statisticsMatrixColumns[column],
        Offset(
          StatisticsA5Geometry.headerX +
              StatisticsA5Geometry.columnPitch * column,
          StatisticsA5Geometry.headerY,
        ),
        color: StatChartPalette.axisLabel,
      );
    }
    for (final (rowIndex, row) in StatisticsMatrixRow.values.indexed) {
      final bottom = StatisticsA5Geometry.bottomOf(rowIndex);
      statisticsChartText(
        canvas,
        row.label,
        Offset(
          StatisticsA5Geometry.leftOf(rowIndex, 0) -
              StatisticsA5Geometry.labelGap,
          bottom - StatisticsA5Geometry.valueRise,
        ),
        align: TextAlign.end,
        fontSize: 11.5,
      );
      for (var column = 0; column < statisticsMatrixColumns.length; column++) {
        final path = StatisticsA5Geometry.cellPath(rowIndex, column);
        if (!row.appliesTo(column)) {
          paintHatch(canvas, path);
          continue;
        }
        final count = counts[rowIndex][column];
        final alpha = StatisticsA5Geometry.alphaOf(count, maxCount);
        canvas.drawPath(
          path,
          Paint()..color = AppColors.primary.withValues(alpha: alpha),
        );
        if (selected == StatisticsMatrixCell(row, column)) {
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = StatChartPalette.highlight,
          );
        }
        statisticsChartText(
          canvas,
          '$count',
          Offset(
            StatisticsA5Geometry.valueX(rowIndex, column),
            bottom - StatisticsA5Geometry.valueRise,
          ),
          fontSize: 11,
          fontWeight: AppType.bold,
          color: alpha >= 0.6 ? _darkValue : AppColors.text,
        );
      }
    }
    if (unknownCount > 0) {
      statisticsChartText(
        canvas,
        _unknownText(unknownCount),
        StatisticsA5Geometry.unknown,
        align: TextAlign.start,
        fontSize: 10,
        color: StatChartPalette.valueLabel,
      );
    }
    statisticsChartText(
      canvas,
      '빗금 = 해당 없음 (EX 최대 5)',
      StatisticsA5Geometry.legend,
      align: TextAlign.end,
      fontSize: 10,
      color: StatChartPalette.axisLabel,
    );
  }

  @override
  bool shouldRepaint(StatisticsSkillMatrixPainter oldPainter) {
    if (oldPainter.selected != selected ||
        oldPainter.unknownCount != unknownCount ||
        oldPainter.counts.length != counts.length) {
      return true;
    }
    for (var row = 0; row < counts.length; row++) {
      final a = oldPainter.counts[row];
      final b = counts[row];
      if (a.length != b.length) return true;
      for (var column = 0; column < b.length; column++) {
        if (a[column] != b[column]) return true;
      }
    }
    return false;
  }
}

/// A5 그래프. 칸을 누르면 [onCellSelected](같은 칸을 다시 누르면 null, 0명 · 해당 없는 칸은 고르지 않는다).
class StatisticsSkillMatrixChart extends StatelessWidget {
  const StatisticsSkillMatrixChart({
    super.key,
    required this.matrix,
    required this.selected,
    required this.onCellSelected,
  });

  final StatisticsSkillMatrix matrix;
  final StatisticsMatrixCell? selected;
  final ValueChanged<StatisticsMatrixCell?> onCellSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: Alignment.centerLeft,
      child: StatChartFrame(
        key: const ValueKey('statistics-a5-chart'),
        viewBox: statisticsA5ViewBox,
        scale: statisticsChartScale(constraints.biggest, statisticsA5ViewBox),
        semanticLabel: '스킬 · 장비 매트릭스',
        painter: StatisticsSkillMatrixPainter.of(matrix, selected: selected),
        onTapAt: (point) {
          for (final (rowIndex, row) in StatisticsMatrixRow.values.indexed) {
            for (
              var column = 0;
              column < statisticsMatrixColumns.length;
              column++
            ) {
              if (!row.appliesTo(column) || matrix.count(row, column) == 0) {
                continue;
              }
              if (StatisticsA5Geometry.cellPath(
                rowIndex,
                column,
              ).contains(point)) {
                final cell = StatisticsMatrixCell(row, column);
                onCellSelected(cell == selected ? null : cell);
                return;
              }
            }
          }
        },
      ),
    ),
  );
}

// --- C5 ----------------------------------------------------------------------

/// C5 설계 좌표(시안 line · circle · rect · text 좌표).
abstract final class StatisticsC5Geometry {
  /// 가로축 0% · 100% x.
  static const axisLeft = 84.0;
  static const axisRight = 1019.3;

  /// 행 바닥선 y(스트라이커 · 스페셜), 행 글자 기준선은 바닥선에서 16 위, 오른쪽 74.
  static const rowLines = [54.0, 106.0];
  static const labelRight = 74.0;
  static const labelRise = 16.0;

  /// 점 세로 가운데(바닥선에서 20 위)와 흩뿌림 폭(±11), 반지름.
  static const dotRise = 20.0;
  static const dotSpread = 11.0;
  static const dotRadius = 4.5;

  /// 고른 구간 상자 위 · 아래, 축 글자 · 구간 글자 기준선.
  static const bandTop = 6.0;
  static const bandBottom = 120.0;
  static const axisLabelY = 136.0;
  static const bandLabelY = 140.0;

  /// 범례(점 가운데 · 글자 시작).
  static const plannedLegend = Offset(663.9, 162);
  static const unplannedLegend = Offset(832.3, 162);
  static const legendTextGap = 9.0;
  static const legendTextRise = 4.0;
  static const unknown = Offset(1019.3, 166);

  static double xOf(double growth) =>
      axisLeft + (axisRight - axisLeft) * growth.clamp(0.0, 1.0);

  /// 고른 구간(0 ~ 40%) 상자.
  static Rect get band => Rect.fromLTRB(
    axisLeft,
    bandTop,
    xOf(statisticsUnplannedLowGrowth),
    bandBottom,
  );

  /// 점 세로 자리: 학생 id의 FNV-1a 해시로 정한 고정 흩뿌림(기기 · 실행마다 같다).
  static double yOf(int row, String studentId) {
    var hash = 0x811c9dc5;
    for (final unit in studentId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final fraction = (hash % 1000) / 999;
    return rowLines[row] - dotRise + (fraction * 2 - 1) * dotSpread;
  }
}

/// C5 painter.
class StatisticsUnplannedStripPainter extends StatChartPainter {
  StatisticsUnplannedStripPainter({
    required this.dots,
    required this.lowCount,
    required this.unknownCount,
    this.selected = false,
  });

  factory StatisticsUnplannedStripPainter.of(
    StatisticsUnplannedStrip strip, {
    bool selected = false,
  }) => StatisticsUnplannedStripPainter(
    dots: [
      for (final dot in strip.dots)
        (
          x: StatisticsC5Geometry.xOf(dot.growth),
          y: StatisticsC5Geometry.yOf(dot.row, dot.student.studentId),
          tone: dot.low ? 2 : (dot.planned ? 1 : 0),
        ),
    ],
    lowCount: strip.low.length,
    unknownCount: strip.unknownCount,
    selected: selected,
  );

  /// 점(설계 좌표 · 색: 0 미계획 · 1 계획 있음 · 2 고른 구간).
  final List<({double x, double y, int tone})> dots;
  final int lowCount;
  final int unknownCount;
  final bool selected;

  static const _rowLabels = ['스트라이커', '스페셜'];
  static const _tones = [_unplannedDot, AppColors.primary, AppColors.accent];

  @override
  void paint(Canvas canvas, Size viewBox) {
    final band = StatisticsC5Geometry.band;
    final bandShape = RRect.fromRectAndRadius(band, const Radius.circular(6));
    canvas.drawRRect(
      bandShape,
      Paint()
        ..color = AppColors.accent.withValues(alpha: selected ? 0.16 : 0.08),
    );
    if (selected) {
      canvas.drawRRect(
        bandShape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.accent,
      );
    } else {
      _dashedRRect(canvas, bandShape);
    }
    for (final (row, line) in StatisticsC5Geometry.rowLines.indexed) {
      statisticsChartText(
        canvas,
        _rowLabels[row],
        Offset(
          StatisticsC5Geometry.labelRight,
          line - StatisticsC5Geometry.labelRise,
        ),
        align: TextAlign.end,
        fontSize: 12,
      );
      canvas.drawLine(
        Offset(StatisticsC5Geometry.axisLeft, line),
        Offset(StatisticsC5Geometry.axisRight, line),
        Paint()
          ..color = StatChartPalette.axis
          ..strokeWidth = 1,
      );
    }
    // 미계획 → 계획 있음 → 고른 구간 순으로 위에 그린다.
    for (var tone = 0; tone < _tones.length; tone++) {
      for (final dot in dots) {
        if (dot.tone != tone) continue;
        _dot(canvas, Offset(dot.x, dot.y), _tones[tone]);
      }
    }
    for (final (value, text) in const [
      (0.0, '0%'),
      (statisticsUnplannedLowGrowth, '40%'),
      (1.0, '100%'),
    ]) {
      statisticsChartText(
        canvas,
        text,
        Offset(
          StatisticsC5Geometry.xOf(value),
          StatisticsC5Geometry.axisLabelY,
        ),
        fontSize: 10,
        color: StatChartPalette.axisLabel,
      );
    }
    statisticsChartText(
      canvas,
      statisticsC5BandText(lowCount),
      Offset(band.center.dx, StatisticsC5Geometry.bandLabelY),
      fontSize: 11.5,
      fontWeight: AppType.bold,
      color: StatChartPalette.highlight,
    );
    for (final (center, color, text) in [
      (StatisticsC5Geometry.plannedLegend, AppColors.primary, '계획 있음'),
      (StatisticsC5Geometry.unplannedLegend, _unplannedDot, '계획 없음'),
    ]) {
      canvas.drawCircle(
        center,
        StatisticsC5Geometry.dotRadius,
        Paint()..color = color,
      );
      statisticsChartText(
        canvas,
        text,
        center +
            const Offset(
              StatisticsC5Geometry.legendTextGap,
              StatisticsC5Geometry.legendTextRise,
            ),
        align: TextAlign.start,
        color: StatChartPalette.valueLabel,
      );
    }
    if (unknownCount > 0) {
      statisticsChartText(
        canvas,
        _unknownText(unknownCount),
        StatisticsC5Geometry.unknown,
        align: TextAlign.end,
        color: StatChartPalette.valueLabel,
      );
    }
  }

  void _dot(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(
      center,
      StatisticsC5Geometry.dotRadius,
      Paint()..color = color,
    );
    canvas.drawCircle(
      center,
      StatisticsC5Geometry.dotRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _dotStroke,
    );
  }

  /// 시안 `stroke-dasharray="4 3"` 둥근 상자.
  void _dashedRRect(Canvas canvas, RRect shape) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.accent.withValues(alpha: 0.5);
    for (final metric in (Path()..addRRect(shape)).computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += 7) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + 4, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(StatisticsUnplannedStripPainter oldPainter) {
    if (oldPainter.selected != selected ||
        oldPainter.lowCount != lowCount ||
        oldPainter.unknownCount != unknownCount ||
        oldPainter.dots.length != dots.length) {
      return true;
    }
    for (var index = 0; index < dots.length; index++) {
      if (oldPainter.dots[index] != dots[index]) return true;
    }
    return false;
  }
}

/// C5 구간 글자(시안 "미계획 · 40% 미만 14명", KPI와 같은 수).
String statisticsC5BandText(int count) => '미계획 · 40% 미만 $count명';

/// C5 그래프. 고른 구간 상자(또는 그 안 점)를 누르면 [onBandSelected](이미 골랐으면 false). 구간 학생이 없으면 고르지
/// 않는다.
class StatisticsUnplannedStripChart extends StatelessWidget {
  const StatisticsUnplannedStripChart({
    super.key,
    required this.strip,
    required this.selected,
    required this.onBandSelected,
  });

  final StatisticsUnplannedStrip strip;
  final bool selected;
  final ValueChanged<bool> onBandSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: Alignment.centerLeft,
      child: StatChartFrame(
        key: const ValueKey('statistics-c5-chart'),
        viewBox: statisticsC5ViewBox,
        scale: statisticsChartScale(constraints.biggest, statisticsC5ViewBox),
        semanticLabel: '미계획 학생',
        painter: StatisticsUnplannedStripPainter.of(strip, selected: selected),
        onTapAt: (point) {
          if (strip.low.isEmpty) return;
          // 상자와 그 아래 구간 글자까지 누를 수 있다.
          final band = StatisticsC5Geometry.band;
          final target = Rect.fromLTRB(
            band.left,
            band.top,
            band.right,
            StatisticsC5Geometry.bandLabelY + 4,
          );
          if (target.contains(point)) onBandSelected(!selected);
        },
      ),
    ),
  );
}
