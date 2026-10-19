// 통계 "학생 성장" A3 · A4 그래프(FE7-f, 시안 Stats-Growth, F §2 시각 문법 · §5).
//
// 둘 다 시안 SVG viewBox(설계 좌표)에서 그린 뒤 키트 [StatChartFrame]이 균일 배율한다(FE7-b A1 · A2와 같은 방식, 차트
// 라이브러리 없음). 글자 · 점선은 성장 차트 공용 함수([statisticsChartText] · [statisticsChartDashed])다.
// - A3 성작 · 전용무기(viewBox 470×196): 단계 막대 두 묶음(성작 ★1~5 · 전용무기 없음 · 1~4, 같은 축척, 크기 파랑 α.78, 고른
//   단계 분홍) + 막대 위 인원 + 아래 단계 글자, 아래에 편성(스트라이커 · 스페셜)별 ★1~5 100% 누적 막대(한 색조 명도
//   #2c4a62 → #b4e3fb, 행마다 사선을 따라 왼쪽으로) + "★1 → ★5 어두움 → 밝음". 단계 막대를 누르면 그 단계를 고른다.
// - A4 학교 · 역할 비교(viewBox 462×240): 보유율(가로) × 평균 육성도(세로) 산점도, 평균선 두 줄(점선)이 4분면을 만든다
//   + "평균". 축은 값 범위를 10 단위로 내림 · 올림한 자리이고 시안처럼 최소값만 글자로 쓴다("40%" · "30"). 점은 크기
//   파랑, 강조(고른 점, 없으면 "평균 아래에서 가장 많이 모인 그룹" — 질문 "많이 모였지만 덜 키운")는 분홍 큰 점 + 흰
//   굵은 이름, 보유율 가장 높은 · 낮은 점은 회색 이름(시안 직접 라벨). 점마다 26px 버튼(`.sdot`)이 있고 마우스를 올리거나
//   포커스하면 팝오버(`.spop`: 이름 · "보유 n명 · 보유율 n% · 평균 육성도 n%" · 초상 6 + "…+n" · 안내)가 점 왼쪽에 뜬다
//   (화면 밖으로 나가면 오른쪽 · 안쪽으로 민다). 누르면 그 그룹을 고른다(오른쪽 목록 → 학생 탭).
// 키트 승격 후보: 발산 막대(B2)와 함께 산점도 hover 점(`StatisticsGroupDot`)은 statistics 안에 두었다(status FE7-f).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../statistics/statistics_breakdown_projection.dart';
import '../../statistics/statistics_growth_projection.dart';
import '../kit/kit_overlay.dart';
import '../kit/portrait_strip.dart';
import '../kit/stat_chart.dart';
import '../models/student_filter_selection.dart' show studentFilterChipLabel;
import 'statistics_growth_charts.dart';

/// A3 · A4 설계 좌표(시안 viewBox).
const statisticsA3ViewBox = Size(470, 196);
const statisticsA4ViewBox = Size(462, 240);

final _tan10 = math.tan(10 * math.pi / 180);

/// A3 단계 막대(#71c7f4 α.78).
const _stepBar = StatChartPalette.magnitudeSoft;

/// A3 누적 막대 한 색조 명도(★1 → ★5, 시안).
const statisticsA3MixColors = [
  Color(0xff2c4a62),
  Color(0xff3f6d8c),
  Color(0xff5294b8),
  Color(0xff71c7f4),
  Color(0xffb4e3fb),
];

/// A3 누적 막대 트랙(편성을 아는 학생이 없을 때).
const _mixTrack = Color.fromRGBO(255, 255, 255, 0.07);

/// A4 점(#71c7f4 · 테두리 #16202c), 평균선(rgba(158,176,194,.5)), hover 고리(rgba(242,179,239,.85)).
const _dotStroke = Color(0xff16202c);
const _meanLine = Color.fromRGBO(158, 176, 194, 0.5);
const _dotRing = Color.fromRGBO(242, 179, 239, 0.85);

/// A4 팝오버 바탕(시안 `.spop` #0d151f).
const _popoverColor = Color(0xff0d151f);

String _unknownText(int count) => '$count명 모름';

// --- A3 ----------------------------------------------------------------------

/// A3 설계 좌표(시안 path · text 좌표).
abstract final class StatisticsA3Geometry {
  static const baseline = 116.0;

  /// 가장 많은 단계 막대 높이(시안 52명 = 84).
  static const maxBarHeight = 84.0;
  static const barWidth = 25.4;
  static const barPitch = 41.0;

  /// 묶음 첫 막대 x · 제목 x · 바닥선 끝.
  static double barLeft(StatisticsStarKind kind, int index) =>
      (kind == StatisticsStarKind.star ? 26.1 : 261.1) + barPitch * index;
  static double groupLeft(StatisticsStarKind kind) =>
      kind == StatisticsStarKind.star ? 20 : 255;
  static double groupRight(StatisticsStarKind kind) =>
      kind == StatisticsStarKind.star ? 217 : 452;

  static const stepLabelY = 131.0;
  static const titleY = 12.0;

  /// 누적 막대: 첫 행 밑변 158, 행 피치 24, 높이 16, 첫 행 왼쪽 75.2, 폭 368(칸 사이 2), 이름 오른쪽 66.2.
  static const mixBaseline = 158.0;
  static const mixPitch = 24.0;
  static const mixHeight = 16.0;
  static const mixLeft = 75.2;
  static const mixWidth = 368.0;
  static const mixGap = 2.0;
  static const mixLabelRight = 66.2;
  static const legend = Offset(464, 194);

  static double barHeight(int count, int maxCount) =>
      maxCount <= 0 ? 0 : maxBarHeight * count / maxCount;

  /// 단계 막대의 누르는 자리(막대 칸 전체 높이, 기울인 모양).
  static Path hitPath(StatisticsStarKind kind, int index) {
    final left = barLeft(kind, index);
    return skewedBarPath(
      Rect.fromLTRB(
        left,
        baseline - maxBarHeight - 14,
        left + barWidth,
        baseline,
      ),
      topRadius: 0,
    );
  }

  /// 누적 행 [row]의 밑변 y · 왼쪽 x(사선을 따라 왼쪽으로).
  static double mixBaselineOf(int row) => mixBaseline + mixPitch * row;
  static double mixLeftOf(int row) => mixLeft - mixPitch * row * _tan10;
}

/// A3 painter.
class StatisticsStarDistributionPainter extends StatChartPainter {
  StatisticsStarDistributionPainter({
    required this.stars,
    required this.weapons,
    required this.mix,
    required this.unknownStars,
    required this.unknownWeapons,
    this.selected,
  });

  factory StatisticsStarDistributionPainter.of(
    StatisticsStarDistribution data, {
    StatisticsStarStep? selected,
  }) => StatisticsStarDistributionPainter(
    stars: [for (final list in data.stars) list.length],
    weapons: [for (final list in data.weapons) list.length],
    mix: [
      for (final value in statisticsA3CombatClasses)
        data.classMix[value] ?? const [0, 0, 0, 0, 0],
    ],
    unknownStars: data.unknownStars,
    unknownWeapons: data.unknownWeapons,
    selected: selected,
  );

  final List<int> stars;
  final List<int> weapons;

  /// 편성(스트라이커 · 스페셜) → ★1~5 인원.
  final List<List<int>> mix;
  final int unknownStars;
  final int unknownWeapons;
  final StatisticsStarStep? selected;

  static const _mixLabels = ['스트라이커', '스페셜'];

  @override
  void paint(Canvas canvas, Size viewBox) {
    final maxCount = math.max(1, [...stars, ...weapons].fold(0, math.max));
    final scale = StatChartScale(
      domainMin: 0,
      domainMax: maxCount.toDouble(),
      rangeStart: StatisticsA3Geometry.baseline,
      rangeEnd:
          StatisticsA3Geometry.baseline - StatisticsA3Geometry.maxBarHeight,
    );
    for (final kind in StatisticsStarKind.values) {
      final counts = kind == StatisticsStarKind.star ? stars : weapons;
      final unknown = kind == StatisticsStarKind.star
          ? unknownStars
          : unknownWeapons;
      final groupLeft = StatisticsA3Geometry.groupLeft(kind);
      final groupRight = StatisticsA3Geometry.groupRight(kind);
      canvas.drawLine(
        Offset(groupLeft, StatisticsA3Geometry.baseline),
        Offset(groupRight, StatisticsA3Geometry.baseline),
        Paint()
          ..color = StatChartPalette.axis
          ..strokeWidth = 1,
      );
      statisticsChartText(
        canvas,
        kind.label,
        Offset(groupLeft, StatisticsA3Geometry.titleY),
        align: TextAlign.start,
        fontSize: 11.5,
        fontWeight: AppType.bold,
      );
      if (unknown > 0) {
        statisticsChartText(
          canvas,
          _unknownText(unknown),
          Offset(groupRight, StatisticsA3Geometry.titleY),
          align: TextAlign.end,
          color: StatChartPalette.valueLabel,
        );
      }
      for (var index = 0; index < kind.steps; index++) {
        final count = index < counts.length ? counts[index] : 0;
        final left = StatisticsA3Geometry.barLeft(kind, index);
        final chosen = selected == StatisticsStarStep(kind, index);
        paintValueBar(
          canvas,
          slot: Rect.fromLTRB(
            left,
            StatisticsA3Geometry.baseline - StatisticsA3Geometry.maxBarHeight,
            left + StatisticsA3Geometry.barWidth,
            StatisticsA3Geometry.baseline,
          ),
          value: count.toDouble(),
          scale: scale,
          color: chosen ? StatChartPalette.highlight : _stepBar,
        );
        final height = StatisticsA3Geometry.barHeight(count, maxCount);
        final center = left + StatisticsA3Geometry.barWidth / 2;
        statisticsChartText(
          canvas,
          kind.stepLabel(index),
          Offset(center, StatisticsA3Geometry.stepLabelY),
          color: chosen
              ? StatChartPalette.highlight
              : StatChartPalette.axisLabel,
          fontWeight: chosen ? AppType.bold : AppType.semiBold,
        );
        statisticsChartText(
          canvas,
          '$count',
          Offset(
            center + height * _tan10,
            StatisticsA3Geometry.baseline - height - 5,
          ),
          color: chosen ? AppColors.text : StatChartPalette.valueLabel,
          fontWeight: chosen ? AppType.bold : AppType.semiBold,
        );
      }
    }
    for (final (row, counts) in mix.indexed) {
      final baseline = StatisticsA3Geometry.mixBaselineOf(row);
      final left = StatisticsA3Geometry.mixLeftOf(row);
      statisticsChartText(
        canvas,
        _mixLabels[row],
        Offset(
          StatisticsA3Geometry.mixLabelRight -
              StatisticsA3Geometry.mixPitch * row * _tan10,
          baseline - 3,
        ),
        align: TextAlign.end,
        fontSize: 11,
      );
      _paintMix(canvas, counts, left, baseline);
    }
    statisticsChartText(
      canvas,
      '★1 → ★5 어두움 → 밝음',
      StatisticsA3Geometry.legend,
      align: TextAlign.end,
      fontSize: 10,
      color: StatChartPalette.axisLabel,
    );
  }

  /// 100% 누적 막대 한 행. 0명 칸은 자리를 차지하지 않는다(칸 사이 2는 있는 칸 사이에만).
  void _paintMix(
    Canvas canvas,
    List<int> counts,
    double left,
    double baseline,
  ) {
    const height = StatisticsA3Geometry.mixHeight;
    final skew = height * _tan10;
    final total = counts.fold<int>(0, (sum, value) => sum + value);
    if (total <= 0) {
      canvas.drawPath(
        _parallelogram(left, StatisticsA3Geometry.mixWidth, baseline, skew),
        Paint()..color = _mixTrack,
      );
      return;
    }
    final present = counts.where((value) => value > 0).length;
    final available =
        StatisticsA3Geometry.mixWidth -
        StatisticsA3Geometry.mixGap * (present - 1);
    var x = left;
    for (final (index, count) in counts.indexed) {
      if (count <= 0) continue;
      final width = available * count / total;
      canvas.drawPath(
        _parallelogram(x, width, baseline, skew),
        Paint()..color = statisticsA3MixColors[index],
      );
      x += width + StatisticsA3Geometry.mixGap;
    }
  }

  Path _parallelogram(
    double left,
    double width,
    double baseline,
    double skew,
  ) => Path()
    ..moveTo(left, baseline)
    ..lineTo(left + width, baseline)
    ..lineTo(left + width + skew, baseline - StatisticsA3Geometry.mixHeight)
    ..lineTo(left + skew, baseline - StatisticsA3Geometry.mixHeight)
    ..close();

  @override
  bool shouldRepaint(StatisticsStarDistributionPainter oldPainter) =>
      oldPainter.selected != selected ||
      oldPainter.unknownStars != unknownStars ||
      oldPainter.unknownWeapons != unknownWeapons ||
      !_listEquals(oldPainter.stars, stars) ||
      !_listEquals(oldPainter.weapons, weapons) ||
      oldPainter.mix.length != mix.length ||
      [
        for (var row = 0; row < mix.length; row++)
          _listEquals(oldPainter.mix[row], mix[row]),
      ].contains(false);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

/// A3 그래프. 단계 막대를 누르면 [onStepSelected](같은 단계를 다시 누르면 null, 0명 단계는 고르지 않는다).
class StatisticsStarDistributionChart extends StatelessWidget {
  const StatisticsStarDistributionChart({
    super.key,
    required this.data,
    required this.selected,
    required this.onStepSelected,
  });

  final StatisticsStarDistribution data;
  final StatisticsStarStep? selected;
  final ValueChanged<StatisticsStarStep?> onStepSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: Alignment.centerLeft,
      child: StatChartFrame(
        key: const ValueKey('statistics-a3-chart'),
        viewBox: statisticsA3ViewBox,
        scale: statisticsChartScale(constraints.biggest, statisticsA3ViewBox),
        semanticLabel: '성작 · 전용무기 분포',
        painter: StatisticsStarDistributionPainter.of(data, selected: selected),
        onTapAt: (point) {
          for (final kind in StatisticsStarKind.values) {
            final lists = data.of(kind);
            for (var index = 0; index < kind.steps; index++) {
              if (lists[index].isEmpty) continue;
              if (StatisticsA3Geometry.hitPath(kind, index).contains(point)) {
                final step = StatisticsStarStep(kind, index);
                onStepSelected(step == selected ? null : step);
                return;
              }
            }
          }
        },
      ),
    ),
  );
}

// --- A4 ----------------------------------------------------------------------

/// A4 설계 좌표(시안 line · text 좌표).
abstract final class StatisticsA4Geometry {
  static const left = 40.0;
  static const right = 442.2;
  static const bottom = 212.0;
  static const top = 10.0;
  static const dotRadius = 5.5;
  static const emphasizedRadius = 7.0;

  /// 점 버튼(`.sdot` 26px, 시안 화면 크기). 설계 좌표로는 26 / 1.25.
  static const buttonSize = 26.0;
}

/// 산점도 축 범위(퍼센트, 10 단위). 값 범위를 내림 · 올림하고 같으면 10을 벌린다. 0~100 안이다.
({double min, double max}) statisticsA4Range(Iterable<double> percents) {
  var low = 100.0, high = 0.0;
  for (final value in percents) {
    low = math.min(low, value);
    high = math.max(high, value);
  }
  if (low > high) return (min: 0, max: 100);
  var min = (low / 10).floor() * 10.0;
  var max = (high / 10).ceil() * 10.0;
  if (max <= min) {
    if (max < 100) {
      max = min + 10;
    } else {
      min = max - 10;
    }
  }
  return (min: math.max(0, min), max: math.min(100, max));
}

/// A4 점 하나(그릴 값).
@immutable
class StatisticsA4Dot {
  const StatisticsA4Dot({
    required this.value,
    required this.label,
    required this.ratio,
    required this.growth,
  });

  final String value;
  final String label;

  /// 보유율 · 평균 육성도(0~1).
  final double ratio;
  final double growth;

  @override
  bool operator ==(Object other) =>
      other is StatisticsA4Dot &&
      other.value == value &&
      other.label == label &&
      other.ratio == ratio &&
      other.growth == growth;

  @override
  int get hashCode => Object.hash(value, label, ratio, growth);
}

/// A4 점 좌표 변환(설계 좌표).
@immutable
class StatisticsA4Axes {
  const StatisticsA4Axes({required this.x, required this.y});

  factory StatisticsA4Axes.of(
    List<StatisticsA4Dot> dots, {
    double? meanRatio,
    double? meanGrowth,
  }) {
    final x = statisticsA4Range([
      for (final dot in dots) dot.ratio * 100,
      ?meanRatio == null ? null : meanRatio * 100,
    ]);
    final y = statisticsA4Range([
      for (final dot in dots) dot.growth * 100,
      ?meanGrowth == null ? null : meanGrowth * 100,
    ]);
    return StatisticsA4Axes(
      x: StatChartScale(
        domainMin: x.min,
        domainMax: x.max,
        rangeStart: StatisticsA4Geometry.left,
        rangeEnd: StatisticsA4Geometry.right,
      ),
      y: StatChartScale(
        domainMin: y.min,
        domainMax: y.max,
        rangeStart: StatisticsA4Geometry.bottom,
        rangeEnd: StatisticsA4Geometry.top,
      ),
    );
  }

  final StatChartScale x;
  final StatChartScale y;

  Offset center(StatisticsA4Dot dot) =>
      Offset(x.map(dot.ratio * 100), y.map(dot.growth * 100));
}

/// A4 painter.
class StatisticsGroupComparisonPainter extends StatChartPainter {
  const StatisticsGroupComparisonPainter({
    required this.dots,
    required this.axes,
    required this.meanRatio,
    required this.meanGrowth,
    required this.unknownCount,
    this.emphasized,
  });

  final List<StatisticsA4Dot> dots;
  final StatisticsA4Axes axes;
  final double? meanRatio;
  final double? meanGrowth;
  final int unknownCount;

  /// 분홍 큰 점(고른 점, 없으면 강조 그룹).
  final String? emphasized;

  @override
  void paint(Canvas canvas, Size viewBox) {
    final axis = Paint()
      ..color = StatChartPalette.axis
      ..strokeWidth = 1;
    const origin = Offset(
      StatisticsA4Geometry.left,
      StatisticsA4Geometry.bottom,
    );
    canvas
      ..drawLine(
        origin,
        const Offset(StatisticsA4Geometry.right, StatisticsA4Geometry.bottom),
        axis,
      )
      ..drawLine(
        origin,
        const Offset(StatisticsA4Geometry.left, StatisticsA4Geometry.top),
        axis,
      );
    final ratio = meanRatio;
    if (ratio != null) {
      final x = axes.x.map(ratio * 100);
      statisticsChartDashed(
        canvas,
        Offset(x, StatisticsA4Geometry.bottom),
        Offset(x, StatisticsA4Geometry.top),
        color: _meanLine,
        width: 1,
        dash: 4,
      );
    }
    final growth = meanGrowth;
    if (growth != null) {
      final y = axes.y.map(growth * 100);
      statisticsChartDashed(
        canvas,
        Offset(StatisticsA4Geometry.left, y),
        Offset(StatisticsA4Geometry.right, y),
        color: _meanLine,
        width: 1,
        dash: 4,
      );
      statisticsChartText(
        canvas,
        '평균',
        Offset(StatisticsA4Geometry.right, y - 5),
        align: TextAlign.end,
        fontSize: 10,
        color: StatChartPalette.axisLabel,
      );
    }
    // 직접 라벨: 보유율 가장 높은 · 낮은 점(강조 점은 따로 쓴다).
    StatisticsA4Dot? highest, lowest, chosen;
    for (final dot in dots) {
      if (dot.value == emphasized) chosen = dot;
      if (highest == null || dot.ratio > highest.ratio) highest = dot;
      if (lowest == null || dot.ratio < lowest.ratio) lowest = dot;
    }
    for (final dot in dots) {
      if (identical(dot, chosen)) continue;
      final center = axes.center(dot);
      canvas
        ..drawCircle(
          center,
          StatisticsA4Geometry.dotRadius,
          Paint()..color = StatChartPalette.magnitude,
        )
        ..drawCircle(
          center,
          StatisticsA4Geometry.dotRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _dotStroke,
        );
    }
    for (final dot in {?highest, ?lowest}) {
      if (identical(dot, chosen)) continue;
      final center = axes.center(dot);
      // 오른쪽 자리가 모자라면 점 왼쪽에 쓴다(차트 틀이 viewBox 밖을 자른다).
      final fits = center.dx + 9 + 48 <= statisticsA4ViewBox.width;
      statisticsChartText(
        canvas,
        dot.label,
        center + Offset(fits ? 9 : -9, 4),
        align: fits ? TextAlign.start : TextAlign.end,
        color: StatChartPalette.valueLabel,
        maxWidth: 96,
      );
    }
    final emphasis = chosen;
    if (emphasis != null) {
      final center = axes.center(emphasis);
      canvas
        ..drawCircle(
          center,
          StatisticsA4Geometry.emphasizedRadius,
          Paint()..color = StatChartPalette.highlight,
        )
        ..drawCircle(
          center,
          StatisticsA4Geometry.emphasizedRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _dotStroke,
        );
      final left = center.dx - 10 >= StatisticsA4Geometry.left + 30;
      statisticsChartText(
        canvas,
        emphasis.label,
        Offset(center.dx + (left ? -10 : 10), center.dy - 12),
        align: left ? TextAlign.end : TextAlign.start,
        fontSize: 12,
        fontWeight: AppType.bold,
        maxWidth: 120,
      );
    }
    statisticsChartText(
      canvas,
      '보유율 →',
      const Offset(StatisticsA4Geometry.right, 230),
      align: TextAlign.end,
      color: StatChartPalette.axisLabel,
    );
    statisticsChartText(
      canvas,
      '육성도',
      const Offset(36, 12),
      align: TextAlign.end,
      color: StatChartPalette.axisLabel,
    );
    statisticsChartText(
      canvas,
      axes.y.domainMin.round().toString(),
      const Offset(36, 210),
      align: TextAlign.end,
      fontSize: 10,
      color: StatChartPalette.axisLabel,
    );
    statisticsChartText(
      canvas,
      '${axes.x.domainMin.round()}%',
      const Offset(StatisticsA4Geometry.left, 226),
      fontSize: 10,
      color: StatChartPalette.axisLabel,
    );
    if (unknownCount > 0) {
      statisticsChartText(
        canvas,
        _unknownText(unknownCount),
        const Offset(StatisticsA4Geometry.right, 12),
        align: TextAlign.end,
        color: StatChartPalette.valueLabel,
      );
    }
  }

  @override
  bool shouldRepaint(StatisticsGroupComparisonPainter oldPainter) =>
      oldPainter.emphasized != emphasized ||
      oldPainter.meanRatio != meanRatio ||
      oldPainter.meanGrowth != meanGrowth ||
      oldPainter.unknownCount != unknownCount ||
      oldPainter.axes.x.domainMin != axes.x.domainMin ||
      oldPainter.axes.x.domainMax != axes.x.domainMax ||
      oldPainter.axes.y.domainMin != axes.y.domainMin ||
      oldPainter.axes.y.domainMax != axes.y.domainMax ||
      !_listEquals(oldPainter.dots, dots);
}

/// 그룹 이름(학교 · 역할 코드 값 → 학생 탭 필터 칩 이름).
String statisticsGroupLabel(StatisticsA4Group group, String value) =>
    studentFilterChipLabel(group.key, value);

/// 팝오버 둘째 줄(시안 "보유 28명 · 보유율 93% · 평균 육성도 71%").
String statisticsGroupSummaryText(StatisticsGroupPoint point) =>
    '보유 ${point.ownedCount}명 · 보유율 '
    '${point.ownedRatio == null ? '—' : statisticsPercentText(point.ownedRatio!)} · 평균 육성도 '
    '${point.averageGrowth == null ? '—' : statisticsPercentText(point.averageGrowth!)}';

/// A4 그래프. 점을 누르면 [onGroupSelected](같은 점을 다시 누르면 null). 점 위 hover · 포커스는 팝오버다.
class StatisticsGroupComparisonChart extends StatelessWidget {
  const StatisticsGroupComparisonChart({
    super.key,
    required this.comparison,
    required this.selected,
    required this.onGroupSelected,
  });

  final StatisticsGroupComparison comparison;
  final String? selected;
  final ValueChanged<String?> onGroupSelected;

  @override
  Widget build(BuildContext context) {
    final group = comparison.group;
    final points = comparison.points;
    final dots = [
      for (final point in points)
        StatisticsA4Dot(
          value: point.value,
          label: statisticsGroupLabel(group, point.value),
          ratio: point.ownedRatio!,
          growth: point.averageGrowth!,
        ),
    ];
    final meanRatio = comparison.meanRatio;
    final meanGrowth = comparison.meanGrowth;
    final axes = StatisticsA4Axes.of(
      dots,
      meanRatio: meanRatio,
      meanGrowth: meanGrowth,
    );
    final emphasized = selected ?? comparison.emphasized?.value;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = statisticsChartScale(
          constraints.biggest,
          statisticsA4ViewBox,
        );
        final button = StatisticsA4Geometry.buttonSize * scale / statChartScale;
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            key: const ValueKey('statistics-a4-chart'),
            width: statisticsA4ViewBox.width * scale,
            height: statisticsA4ViewBox.height * scale,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: StatChartFrame(
                    viewBox: statisticsA4ViewBox,
                    scale: scale,
                    semanticLabel: '${group.label} 비교',
                    painter: StatisticsGroupComparisonPainter(
                      dots: dots,
                      axes: axes,
                      meanRatio: meanRatio,
                      meanGrowth: meanGrowth,
                      unknownCount: comparison.unknownCount,
                      emphasized: emphasized,
                    ),
                  ),
                ),
                for (final (index, point) in points.indexed)
                  Positioned(
                    left: axes.center(dots[index]).dx * scale - button / 2,
                    top: axes.center(dots[index]).dy * scale - button / 2,
                    width: button,
                    height: button,
                    child: StatisticsGroupDot(
                      key: ValueKey('statistics-a4-dot-${point.value}'),
                      label: dots[index].label,
                      group: group,
                      point: point,
                      onPressed: () => onGroupSelected(
                        point.value == selected ? null : point.value,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A4 점 버튼(시안 `.sdot`, aria-label "<그룹> 학생 목록"): 누르면 고르고, 마우스를 올리거나 포커스하면 팝오버를 띄운다.
class StatisticsGroupDot extends StatefulWidget {
  const StatisticsGroupDot({
    super.key,
    required this.label,
    required this.group,
    required this.point,
    required this.onPressed,
  });

  final String label;
  final StatisticsA4Group group;
  final StatisticsGroupPoint point;
  final VoidCallback onPressed;

  @override
  State<StatisticsGroupDot> createState() => _StatisticsGroupDotState();
}

class _StatisticsGroupDotState extends State<StatisticsGroupDot> {
  final _controller = OverlayPortalController(debugLabel: 'StatisticsGroupDot');
  bool _hovered = false;
  bool _focused = false;

  void _update({bool? hovered, bool? focused}) {
    setState(() {
      _hovered = hovered ?? _hovered;
      _focused = focused ?? _focused;
    });
    if (_hovered || _focused) {
      _controller.show();
    } else {
      _controller.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _focused;
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _controller,
      overlayChildBuilder: (context, info) {
        final trigger = MatrixUtils.transformRect(
          info.childPaintTransform,
          Offset.zero & info.childSize,
        );
        return CustomSingleChildLayout(
          delegate: _GroupPopoverLayout(
            trigger: trigger,
            overlay: Offset.zero & info.overlaySize,
          ),
          child: IgnorePointer(
            child: StatisticsGroupPopover(
              key: ValueKey('statistics-a4-popover-${widget.point.value}'),
              label: widget.label,
              group: widget.group,
              point: widget.point,
            ),
          ),
        );
      },
      child: Semantics(
        button: true,
        label: '${widget.label} 학생 목록',
        child: FocusableActionDetector(
          onFocusChange: (focused) => _update(focused: focused),
          mouseCursor: SystemMouseCursors.click,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed();
                return null;
              },
            ),
          },
          child: MouseRegion(
            onEnter: (_) => _update(hovered: true),
            onExit: (_) => _update(hovered: false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPressed,
              child: CustomPaint(painter: _DotRingPainter(active: active)),
            ),
          ),
        ),
      ),
    );
  }
}

/// hover · 포커스 고리(시안 `box-shadow: 0 0 0 2px rgba(242,179,239,.85)`, 26px 원).
class _DotRingPainter extends CustomPainter {
  const _DotRingPainter({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2 + 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _dotRing,
    );
  }

  @override
  bool shouldRepaint(_DotRingPainter oldDelegate) =>
      oldDelegate.active != active;
}

/// 팝오버 자리: 시안 `right: calc(100% + 12px); top: -18px`(점 왼쪽). 왼쪽이 화면 밖이면 점 오른쪽, 그래도 넘치면 화면
/// 안으로 민다(위아래도 화면 안). 화면 가장자리에서 8 띄운다.
class _GroupPopoverLayout extends SingleChildLayoutDelegate {
  const _GroupPopoverLayout({required this.trigger, required this.overlay});

  final Rect trigger;
  final Rect overlay;

  static const gap = 12.0;
  static const crossOffset = -18.0;
  static const margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          math.max(0, overlay.width - margin * 2),
          math.max(0, overlay.height - margin * 2),
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var left = trigger.left - gap - childSize.width;
    if (left < overlay.left + margin) left = trigger.right + gap;
    left = _clamp(
      left,
      overlay.left + margin,
      overlay.right - margin - childSize.width,
    );
    final top = _clamp(
      trigger.top + crossOffset,
      overlay.top + margin,
      overlay.bottom - margin - childSize.height,
    );
    return Offset(left, top);
  }

  static double _clamp(double value, double min, double max) =>
      max < min ? min : value.clamp(min, max).toDouble();

  @override
  bool shouldRelayout(_GroupPopoverLayout oldDelegate) =>
      oldDelegate.trigger != trigger || oldDelegate.overlay != overlay;
}

/// A4 팝오버(시안 `.spop`: 안쪽 12 · 14, r10, #0d151f, 1px 링 + 0 12 30 그림자, 줄 사이 8).
class StatisticsGroupPopover extends StatelessWidget {
  const StatisticsGroupPopover({
    super.key,
    required this.label,
    required this.group,
    required this.point,
  });

  /// 초상 수(시안 6).
  static const portraits = 6;

  final String label;
  final StatisticsA4Group group;
  final StatisticsGroupPoint point;

  @override
  Widget build(BuildContext context) => KitOverlayPanel(
    color: _popoverColor,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                fontFamily: AppFonts.body,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 13,
                height: 1.3,
                fontWeight: AppType.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              statisticsGroupSummaryText(point),
              maxLines: 1,
              style: const TextStyle(
                fontFamily: AppFonts.body,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 11.5,
                height: 1.3,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PortraitStrip(
          studentIds: [for (final student in point.students) student.studentId],
          maxVisible: portraits,
          portraitSize: const Size(44, 36),
        ),
        const SizedBox(height: 8),
        Text(
          '누르면 오른쪽 목록 · 학생 탭(${group.label} 필터)으로 이어집니다',
          maxLines: 1,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: 11,
            height: 1.3,
            color: AppColors.textMuted,
          ),
        ),
      ],
    ),
  );
}
