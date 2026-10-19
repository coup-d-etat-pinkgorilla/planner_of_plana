// 통계 "인벤토리 현황" B2 · "계획 집계" C4 그래프(FE7-f, 시안 Stats-Inventory · Stats-Plan, F §2 시각 문법 · §5).
//
// 둘 다 시안 SVG viewBox(설계 좌표)에서 그린 뒤 키트 [StatChartFrame]이 균일 배율한다(FE7-b · c와 같은 방식, 차트
// 라이브러리 없음).
// - B2 부족 · 과잉(viewBox 483×196): 가운데 축(x 319.8) 발산 막대. 행마다 (보유 − 필요) / 필요를 재화마다 따로 그린다
//   (FD-033). 부족은 왼쪽 분홍(α.92), 과잉(FD-040)은 오른쪽 노랑(#ffc66d α.92), 막대 끝에 "−62%" · "+22%", 왼쪽에 재화
//   이름. 축척은 시안 1.735/% 이고, 가장 큰 부족이 이름 자리를 덮으면 그만큼 줄인다(두 쪽 같은 축척). 과잉 막대는 오른쪽
//   자리에서 자르고 글자는 실제 값이다. 고른 행은 분홍 테두리 띠, 아래 "← 부족" · "과잉 →" · "필요량 대비 %".
// - C4 학생별 목표 진행(viewBox 442×196): 덤벨(현재 ● 파랑 → 목표 ○, FD-028 식, x 89.9 = 0% · 339.9 = 100%), 25 · 50 ·
//   75% 점선, 오른쪽 "40 → 85%", 아래 범례 "현재 · 목표" · "남은 폭이 큰 순". 모르는 행은 이름과 '—'뿐이다(추정하지
//   않는다). 고른 행은 B2와 같은 분홍 띠다.
// 행을 누르면 그 재화 · 학생을 고른다(같은 행을 다시 누르면 푼다).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../statistics/statistics_goal_projection.dart';
import '../../statistics/statistics_supply_projection.dart';
import '../kit/stat_chart.dart';
import 'statistics_growth_charts.dart';

/// B2 · C4 설계 좌표(시안 viewBox).
const statisticsB2ViewBox = Size(483, 196);
const statisticsC4ViewBox = Size(442, 196);

/// B2 빈 상태: 보유를 아는 계획 재화 중 모자라거나 과잉(FD-040)인 재화가 없다(시안 없음, FE7-f가 정함).
const statisticsB2NoRowsText = '모자라거나 넘치는 재화가 없습니다.';

/// 부족 분홍 · 과잉 노랑 막대(α.92), "과잉 →" 글자(#ffd08a).
const _shortageBar = Color.fromRGBO(242, 179, 239, 0.92);
const _excessBar = Color.fromRGBO(255, 198, 109, 0.92);
const _excessText = Color(0xffffd08a);

/// 가운데 축(rgba(158,176,194,.55) 1.2).
const _centerAxis = Color.fromRGBO(158, 176, 194, 0.55);

/// 고른 행 띠(분홍 α.1 · 테두리 α.7 1.5).
const _selectedFill = Color.fromRGBO(242, 179, 239, 0.1);
const _selectedStroke = Color.fromRGBO(242, 179, 239, 0.7);

/// C4 선(rgba(158,176,194,.6) 3) · 점 테두리 · 목표 점 바탕.
const _dumbbellLine = Color.fromRGBO(158, 176, 194, 0.6);
const _dotStroke = Color(0xff16202c);

/// 고른 행 띠(시안 B2 rect: 행 밑변 − 18에서 높이 24, r6).
void _paintSelectedBand(Canvas canvas, Rect rect) {
  final band = RRect.fromRectAndRadius(rect, const Radius.circular(6));
  canvas
    ..drawRRect(band, Paint()..color = _selectedFill)
    ..drawRRect(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _selectedStroke,
    );
}

// --- B2 ----------------------------------------------------------------------

/// B2 설계 좌표(시안 rect · text 좌표).
abstract final class StatisticsB2Geometry {
  static const axisX = 319.8;
  static const firstBaseline = 22.0;
  static const pitch = 26.0;
  static const barHeight = 13.0;
  static const labelRight = 118.0;
  static const labelMaxWidth = 112.0;

  /// 시안 축척(필요량 대비 1% = 1.735).
  static const unitWidth = 1.735;

  /// 부족 막대 왼쪽 끝 한계: 이름 끝 118 + 6 + 값 글자 자리 34 + 6.
  static const shortageLimit = labelRight + 46;

  /// 과잉 막대 오른쪽 끝 한계: viewBox 오른쪽 − 값 글자 자리 40 − 8.
  static const excessLimit = 483.0 - 48;

  static double baselineOf(int index) => firstBaseline + pitch * index;

  /// 행 [index]의 누르는 자리(시안 고른 띠와 같은 높이, 가로 전체).
  static Rect rowBand(int index) {
    final baseline = baselineOf(index);
    return Rect.fromLTRB(
      0,
      baseline - 18,
      statisticsB2ViewBox.width,
      baseline + 6,
    );
  }

  /// 고른 행 띠.
  static Rect selectedBand(int index) {
    final baseline = baselineOf(index);
    return Rect.fromLTWH(4, baseline - 18, 475.4, 24);
  }

  /// 행들의 축척(%당 폭): 시안 1.735, 가장 큰 부족이 [shortageLimit]을 넘으면 줄인다.
  static double unitFor(Iterable<double> ratios) {
    var shortage = 0.0;
    for (final ratio in ratios) {
      if (ratio < 0) shortage = math.max(shortage, -ratio * 100);
    }
    if (shortage <= 0) return unitWidth;
    return math.min(unitWidth, (axisX - shortageLimit) / shortage);
  }
}

/// B2 한 행 값.
@immutable
class StatisticsB2Bar {
  const StatisticsB2Bar({
    required this.key,
    required this.label,
    required this.ratio,
  });

  factory StatisticsB2Bar.of(StatisticsBalanceRow row) => StatisticsB2Bar(
    key: row.view.key,
    label: row.view.item.displayName,
    ratio: row.ratio,
  );

  final String key;
  final String label;

  /// (보유 − 필요) / 필요.
  final double ratio;

  /// 막대 글자(시안 "−62%" · "+22%"). 0이 아닌 값은 0%로 쓰지 않는다.
  String get text {
    final percent = (ratio * 100).round();
    if (ratio < 0) return '−${math.max(1, -percent)}%';
    return '+${math.max(1, percent)}%';
  }

  @override
  bool operator ==(Object other) =>
      other is StatisticsB2Bar &&
      other.key == key &&
      other.label == label &&
      other.ratio == ratio;

  @override
  int get hashCode => Object.hash(key, label, ratio);
}

/// B2 발산 막대 painter.
class StatisticsBalancePainter extends StatChartPainter {
  const StatisticsBalancePainter({
    required this.bars,
    required this.unknownKinds,
    this.selectedKey,
  });

  final List<StatisticsB2Bar> bars;

  /// 보유를 모르는 계획 재화 수(행이 없다).
  final int unknownKinds;
  final String? selectedKey;

  @override
  void paint(Canvas canvas, Size viewBox) {
    for (final (index, bar) in bars.indexed) {
      if (bar.key == selectedKey) {
        _paintSelectedBand(canvas, StatisticsB2Geometry.selectedBand(index));
      }
    }
    canvas.drawLine(
      const Offset(StatisticsB2Geometry.axisX, 2),
      const Offset(StatisticsB2Geometry.axisX, 158),
      Paint()
        ..color = _centerAxis
        ..strokeWidth = 1.2,
    );
    final unit = StatisticsB2Geometry.unitFor([
      for (final bar in bars) bar.ratio,
    ]);
    for (final (index, bar) in bars.indexed) {
      final baseline = StatisticsB2Geometry.baselineOf(index);
      statisticsChartText(
        canvas,
        bar.label,
        Offset(StatisticsB2Geometry.labelRight, baseline - 3),
        align: TextAlign.end,
        fontSize: 11.5,
        maxWidth: StatisticsB2Geometry.labelMaxWidth,
      );
      final shortage = bar.ratio < 0;
      final width = shortage
          ? -bar.ratio * 100 * unit
          : math.min(
              bar.ratio * 100 * unit,
              StatisticsB2Geometry.excessLimit - StatisticsB2Geometry.axisX,
            );
      final left = shortage
          ? StatisticsB2Geometry.axisX - width
          : StatisticsB2Geometry.axisX;
      final rect = Rect.fromLTWH(
        left,
        baseline - StatisticsB2Geometry.barHeight,
        math.max(1.0, width),
        StatisticsB2Geometry.barHeight,
      );
      canvas.drawPath(
        (Path()..addRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(3)),
            ))
            .transform(statSkewMatrix(Offset(left, baseline)).storage),
        Paint()..color = shortage ? _shortageBar : _excessBar,
      );
      statisticsChartText(
        canvas,
        bar.text,
        shortage
            ? Offset(left - 6, baseline - 3)
            : Offset(left + rect.width + 8, baseline - 3),
        align: shortage ? TextAlign.end : TextAlign.start,
        fontSize: 11.5,
        fontWeight: AppType.bold,
      );
    }
    statisticsChartText(
      canvas,
      '← 부족',
      const Offset(StatisticsB2Geometry.axisX - 8, 176),
      align: TextAlign.end,
      fontWeight: AppType.bold,
      color: StatChartPalette.highlight,
    );
    statisticsChartText(
      canvas,
      '과잉 →',
      const Offset(StatisticsB2Geometry.axisX + 8, 176),
      align: TextAlign.start,
      fontWeight: AppType.bold,
      color: _excessText,
    );
    statisticsChartText(
      canvas,
      '필요량 대비 %',
      const Offset(StatisticsB2Geometry.axisX, 191),
      fontSize: 10,
      color: StatChartPalette.axisLabel,
    );
    if (unknownKinds > 0) {
      statisticsChartText(
        canvas,
        '보유 모름 $unknownKinds종 제외',
        const Offset(4, 191),
        align: TextAlign.start,
        color: StatChartPalette.valueLabel,
      );
    }
  }

  @override
  bool shouldRepaint(StatisticsBalancePainter oldPainter) =>
      oldPainter.selectedKey != selectedKey ||
      oldPainter.unknownKinds != unknownKinds ||
      !_listEquals(oldPainter.bars, bars);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

/// B2 그래프. 행을 누르면 [onResourceSelected](같은 행을 다시 누르면 null).
class StatisticsBalanceChart extends StatelessWidget {
  const StatisticsBalanceChart({
    super.key,
    required this.rows,
    required this.unknownKinds,
    required this.selectedKey,
    required this.onResourceSelected,
  });

  final List<StatisticsBalanceRow> rows;
  final int unknownKinds;
  final String? selectedKey;
  final ValueChanged<String?> onResourceSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final bars = [for (final row in rows) StatisticsB2Bar.of(row)];
      return Align(
        alignment: Alignment.centerLeft,
        child: StatChartFrame(
          key: const ValueKey('statistics-b2-chart'),
          viewBox: statisticsB2ViewBox,
          scale: statisticsChartScale(constraints.biggest, statisticsB2ViewBox),
          semanticLabel: '부족 · 과잉',
          painter: StatisticsBalancePainter(
            bars: bars,
            unknownKinds: unknownKinds,
            selectedKey: selectedKey,
          ),
          onTapAt: (point) {
            for (final (index, bar) in bars.indexed) {
              if (StatisticsB2Geometry.rowBand(index).contains(point)) {
                onResourceSelected(bar.key == selectedKey ? null : bar.key);
                return;
              }
            }
          },
        ),
      );
    },
  );
}

// --- C4 ----------------------------------------------------------------------

/// C4 설계 좌표(시안 line · circle · text 좌표).
abstract final class StatisticsC4Geometry {
  static const zeroX = 89.9;
  static const fullX = 339.9;
  static const firstY = 16.0;
  static const pitch = 30.0;
  static const nameRight = 78.0;
  static const nameMaxWidth = 74.0;
  static const valueRight = 437.8;
  static const dotRadius = 6.0;
  static const gridTop = 2.0;
  static const gridBottom = 150.0;
  static const legendY = 172.0;

  static double xOf(double fraction) =>
      zeroX + (fullX - zeroX) * fraction.clamp(0.0, 1.0);

  static double yOf(int index) => firstY + pitch * index;

  static Rect rowBand(int index) {
    final y = yOf(index);
    return Rect.fromLTRB(
      0,
      y - pitch / 2,
      statisticsC4ViewBox.width,
      y + pitch / 2,
    );
  }

  static Rect selectedBand(int index) {
    final y = yOf(index);
    return Rect.fromLTWH(2, y - 12, 438, 24);
  }
}

/// C4 한 행 값.
@immutable
class StatisticsC4Row {
  const StatisticsC4Row({
    required this.studentId,
    required this.label,
    required this.current,
    required this.target,
  });

  factory StatisticsC4Row.of(StatisticsGoalProgress row) => StatisticsC4Row(
    studentId: row.studentId,
    label: row.displayName,
    current: row.known ? row.currentGrowth : null,
    target: row.known ? row.targetGrowth : null,
  );

  final String studentId;
  final String label;

  /// 현재 · 목표 육성도(0~1). 둘 다 알 때만 있다.
  final double? current;
  final double? target;

  /// 오른쪽 글자(시안 "40 → 85%"). 모르면 '—'.
  String get text {
    final now = current, goal = target;
    if (now == null || goal == null) return '—';
    return '${(now * 100).round()} → ${(goal * 100).round()}%';
  }

  @override
  bool operator ==(Object other) =>
      other is StatisticsC4Row &&
      other.studentId == studentId &&
      other.label == label &&
      other.current == current &&
      other.target == target;

  @override
  int get hashCode => Object.hash(studentId, label, current, target);
}

/// C4 덤벨 painter.
class StatisticsGoalProgressPainter extends StatChartPainter {
  const StatisticsGoalProgressPainter({required this.rows, this.selectedId});

  final List<StatisticsC4Row> rows;
  final String? selectedId;

  @override
  void paint(Canvas canvas, Size viewBox) {
    for (final (index, row) in rows.indexed) {
      if (row.studentId == selectedId) {
        _paintSelectedBand(canvas, StatisticsC4Geometry.selectedBand(index));
      }
    }
    final grid = Paint()
      ..color = StatChartPalette.axis
      ..strokeWidth = 1;
    for (final fraction in const [0.25, 0.5, 0.75]) {
      final x = StatisticsC4Geometry.xOf(fraction);
      // 시안 stroke-dasharray "2 4".
      for (
        var y = StatisticsC4Geometry.gridTop;
        y < StatisticsC4Geometry.gridBottom;
        y += 6
      ) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, math.min(y + 2, StatisticsC4Geometry.gridBottom)),
          grid,
        );
      }
    }
    for (final (index, row) in rows.indexed) {
      final y = StatisticsC4Geometry.yOf(index);
      statisticsChartText(
        canvas,
        row.label,
        Offset(StatisticsC4Geometry.nameRight, y + 4),
        align: TextAlign.end,
        fontSize: 12,
        maxWidth: StatisticsC4Geometry.nameMaxWidth,
      );
      final now = row.current, goal = row.target;
      if (now != null && goal != null) {
        final from = Offset(StatisticsC4Geometry.xOf(now), y);
        final to = Offset(StatisticsC4Geometry.xOf(goal), y);
        canvas.drawLine(
          from,
          to,
          Paint()
            ..color = _dumbbellLine
            ..strokeWidth = 3,
        );
        _currentDot(canvas, from, StatisticsC4Geometry.dotRadius);
        _targetDot(canvas, to, StatisticsC4Geometry.dotRadius);
      }
      statisticsChartText(
        canvas,
        row.text,
        Offset(StatisticsC4Geometry.valueRight, y + 4),
        align: TextAlign.end,
        fontSize: 11.5,
        fontWeight: AppType.bold,
        color: now == null ? StatChartPalette.valueLabel : AppColors.text,
      );
    }
    const legendY = StatisticsC4Geometry.legendY;
    canvas.drawCircle(
      const Offset(96, legendY),
      5,
      Paint()..color = StatChartPalette.magnitude,
    );
    statisticsChartText(
      canvas,
      '현재',
      const Offset(106, legendY + 4),
      align: TextAlign.start,
      color: StatChartPalette.valueLabel,
    );
    _targetDot(canvas, const Offset(150, legendY), 5);
    statisticsChartText(
      canvas,
      '목표',
      const Offset(160, legendY + 4),
      align: TextAlign.start,
      color: StatChartPalette.valueLabel,
    );
    statisticsChartText(
      canvas,
      '남은 폭이 큰 순',
      const Offset(StatisticsC4Geometry.valueRight, legendY + 4),
      align: TextAlign.end,
      fontSize: 10,
      color: StatChartPalette.axisLabel,
    );
  }

  void _currentDot(Canvas canvas, Offset center, double radius) => canvas
    ..drawCircle(center, radius, Paint()..color = StatChartPalette.magnitude)
    ..drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _dotStroke,
    );

  void _targetDot(Canvas canvas, Offset center, double radius) => canvas
    ..drawCircle(center, radius, Paint()..color = _dotStroke)
    ..drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.text,
    );

  @override
  bool shouldRepaint(StatisticsGoalProgressPainter oldPainter) =>
      oldPainter.selectedId != selectedId ||
      !_listEquals(oldPainter.rows, rows);
}

/// C4 그래프. 행을 누르면 [onStudentSelected](같은 행을 다시 누르면 null).
class StatisticsGoalProgressChart extends StatelessWidget {
  const StatisticsGoalProgressChart({
    super.key,
    required this.rows,
    required this.selectedId,
    required this.onStudentSelected,
  });

  final List<StatisticsGoalProgress> rows;
  final String? selectedId;
  final ValueChanged<String?> onStudentSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final values = [for (final row in rows) StatisticsC4Row.of(row)];
      return Align(
        alignment: Alignment.centerLeft,
        child: StatChartFrame(
          key: const ValueKey('statistics-c4-chart'),
          viewBox: statisticsC4ViewBox,
          scale: statisticsChartScale(constraints.biggest, statisticsC4ViewBox),
          semanticLabel: '학생별 목표 진행',
          painter: StatisticsGoalProgressPainter(
            rows: values,
            selectedId: selectedId,
          ),
          onTapAt: (point) {
            for (final (index, row) in values.indexed) {
              if (StatisticsC4Geometry.rowBand(index).contains(point)) {
                onStudentSelected(
                  row.studentId == selectedId ? null : row.studentId,
                );
                return;
              }
            }
          },
        ),
      );
    },
  );
}
