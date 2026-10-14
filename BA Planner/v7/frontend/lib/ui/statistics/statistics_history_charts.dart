// 통계 이력 화면 값과 그림(FE7-h, 시안 Stats-Growth A6 · Stats-Inventory B3 · Stats-Growth-Filter A6 빈 상태).
//
// - [StatisticsHistoryView]: 통계 페이지가 읽은 이력 projection(`statistics_history_projection.dart`)과 B3 seg 상태를 화면에
//   넘기는 값이다. 왼쪽 기준 데이터 · KPI 증감 · A6 · B3가 쓴다. 읽기 전 · 실패면 모두 '—'다.
// - A6 꺾은선(시안 viewBox 462×240): 스냅샷마다 평균 육성도, 같은 간격. 바닥 = 가장 낮은 값을 내린 정수 − 2, 가장 높은 값이
//   y 55.4(시안 63.4%). 가장 높은 값 아래 5의 배수에 점선 · 글자(시안 60), 바닥 글자(56). 강조 구간(분홍 바탕 · 두 끝 분홍 점 ·
//   "9/22 → 10/05 +2.0%p"), 끝 점 위 값 글자.
// - B3 작은 배수(시안 viewBox 1030×226): 패널마다 축이 따로(FD-033). 이름, 필요량이 범위 안이면 점선 + "필요", 위 · 아래면
//   "필요 n ↑ · ↓", 선 + 끝 점, 아래 왼쪽 순변화(감소 분홍 · 증가 초록), 아래 오른쪽 지금 수량. 마지막 스캔 뒤 바뀐 지금 점은
//   속이 빈 원이다(FE6-f 스파크라인과 같다).
// - 스냅샷 2회 미만(Statistics-Proposal 확정 4 · FD-106): 그래프 자리에 스캔 아이콘 · "스캔을 더 실행하면 변화가 나타납니다." ·
//   "스냅샷 n회 · M/dd HH:mm"(시안 Stats-Growth-Filter A6).
// 차트 라이브러리 없이 키트 [StatChartFrame]으로 그린다(B1 · C3와 같은 방식).
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../statistics/statistics_history_projection.dart';
import '../../statistics/statistics_supply_projection.dart';
import '../kit/stat_chart.dart';
import 'statistics_growth_charts.dart';

/// 기준 데이터 한 행 값(시안 칩 색: 학생 스캔 ok · 인벤토리 wn · 스냅샷 gy, 모르면 회색 '—').
typedef StatisticsBaseDataValue = ({String text, bool known});

/// 통계 이력 화면 값.
@immutable
class StatisticsHistoryView {
  const StatisticsHistoryView({
    this.loading = false,
    this.error,
    this.history,
    this.studentScan = '—',
    this.inventoryScan = '—',
    this.inventoryScanDays,
    this.growthDeltas = StatisticsGrowthDeltas.unknown,
    this.supplyDeltas = StatisticsSupplyDeltas.unknown,
    this.growthTrend,
    this.resourceTrends,
    this.b3Range = StatisticsB3Range.recent,
    this.onB3RangeChanged,
  });

  /// 이력을 읽는 중.
  final bool loading;

  /// 읽기 실패 · 상태와 맞지 않음 글자(A6 · B3 타일 안에 보인다).
  final String? error;
  final StatisticsHistory? history;

  /// 기준 데이터 "학생 스캔" · "인벤토리" 값(`어제 21:40` · `3일 전`, 모르면 '—').
  final String studentScan;
  final String inventoryScan;

  /// 마지막 인벤토리 스캔 뒤 날 수(인벤토리 범위 글자 "인벤토리 스캔 n일 전", FE6-f 규칙). 모르면 null.
  final int? inventoryScanDays;
  final StatisticsGrowthDeltas growthDeltas;
  final StatisticsSupplyDeltas supplyDeltas;

  /// A6. 읽기 전 · 실패 · 시계 되돌림이면 null.
  final StatisticsGrowthTrend? growthTrend;

  /// B3. 읽기 전 · 실패 · 시계 되돌림이면 null.
  final StatisticsResourceTrends? resourceTrends;
  final StatisticsB3Range b3Range;
  final ValueChanged<StatisticsB3Range>? onB3RangeChanged;

  /// 기준 데이터 "스냅샷" 값(`6회 · 9/02 ~ 10/05`).
  String get snapshots {
    final history = this.history;
    return history == null
        ? '—'
        : statisticsSnapshotRangeText(history.snapshotTimes);
  }

  /// 인벤토리 범위 글자의 스캔 값(`3일 전` · `오늘`, 모르면 '—', FE6-f `inventoryDaysAgoLabel`과 같다).
  String get inventoryScanAgo {
    final days = inventoryScanDays;
    return days == null
        ? '—'
        : days == 0
        ? '오늘'
        : '$days일 전';
  }

  /// A6 · B3 타일이 그래프 대신 확정 4 문구를 보이는가(FD-109 빈 카드 높이에 쓴다).
  bool get growthTrendShort {
    final trend = growthTrend;
    return trend != null && !trend.drawable;
  }
}

// --- 스냅샷 2회 미만 ---------------------------------------------------------------

/// 시안 Stats-Growth-Filter A6 빈 상태: 둥근 상자(r10, rgba(16,24,35,.45) + 안쪽 1px rgba(56,81,107,.5)) 가운데 스캔
/// 아이콘(26, 파랑) · 굵은 15px 문구 · 12px 회색 스냅샷 줄, 간격 12. 타일이 낮으면(작은 창) 글자 묶음을 줄인다.
class StatisticsHistoryShortState extends StatelessWidget {
  const StatisticsHistoryShortState({super.key, required this.note});

  /// 둘째 줄(`스냅샷 1회 · 9/22 21:40`).
  final String note;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color.fromRGBO(16, 24, 35, 0.45),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color.fromRGBO(56, 81, 107, 0.5)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
            child: _content(),
          ),
        ),
      ),
    ),
  );

  Widget _content() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.document_scanner_outlined,
          size: 26,
          color: AppColors.primary,
        ),
        const SizedBox(height: 12),
        const Text(
          statisticsHistoryMoreScansText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: 15,
            height: 1.25,
            fontWeight: AppType.bold,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          note,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: 12,
            height: 1.25,
            color: AppColors.textMuted,
          ),
        ),
      ],
    ),
  );
}

// --- A6 성장 추이 -------------------------------------------------------------------

/// A6 설계 좌표(시안 viewBox).
const statisticsA6ViewBox = Size(462, 240);

/// 점 테두리(#16202c).
const _dotStroke = Color(0xff16202c);

/// A6 설계 좌표(시안 polyline · circle · text 좌표).
abstract final class StatisticsA6Geometry {
  static const firstX = 44.0;
  static const lastX = 432.2;
  static const baseline = 210.0;
  static const plotTop = 10.0;

  /// 가장 높은 값의 높이(시안 63.4% → 55.4).
  static const maxY = 55.4;

  /// 축 글자 오른쪽 끝, 날짜 글자 밑변, 강조 글자 밑변.
  static const axisLabelRight = 38.0;
  static const dateLabelY = 227.0;
  static const highlightLabelY = 21.0;
  static const dotRadius = 5.0;

  static double xOf(int index, int count) =>
      count <= 1 ? firstX : firstX + (lastX - firstX) * index / (count - 1);

  /// 바닥 값(%): 가장 낮은 값을 내린 정수 − 2(시안 58.1 → 56).
  static double floorOf(double minPercent) => minPercent.floorToDouble() - 2;

  /// 값(%) → 높이. 가장 높은 값이 [maxY]다.
  static double yOf(double percent, double floor, double maxPercent) {
    final span = math.max(maxPercent - floor, 1e-9);
    return baseline - (baseline - maxY) * (percent - floor) / span;
  }

  /// 점선 값(%): 가장 높은 값 아래 5의 배수(바닥보다 커야 한다). 없으면 null.
  static double? gridOf(double floor, double maxPercent) {
    final value = (maxPercent / 5).floorToDouble() * 5;
    return value > floor ? value : null;
  }
}

/// A6 점 값(painter 비교용).
@immutable
class StatisticsA6PaintPoint {
  const StatisticsA6PaintPoint({required this.label, required this.percent});

  final String label;

  /// 평균 육성도(%). 모르면 null(선을 끊는다).
  final double? percent;

  @override
  bool operator ==(Object other) =>
      other is StatisticsA6PaintPoint &&
      other.label == label &&
      other.percent == percent;

  @override
  int get hashCode => Object.hash(label, percent);
}

/// A6 성장 추이 painter.
class StatisticsGrowthTrendPainter extends StatChartPainter {
  StatisticsGrowthTrendPainter({
    required List<StatisticsA6PaintPoint> points,
    this.highlightStart,
    this.highlightText,
  }) : points = List.unmodifiable(points);

  final List<StatisticsA6PaintPoint> points;
  final int? highlightStart;
  final String? highlightText;

  @override
  void paint(Canvas canvas, Size viewBox) {
    final known = [
      for (final point in points)
        if (point.percent != null) point.percent!,
    ];
    if (known.isEmpty) return;
    final maxPercent = known.reduce(math.max);
    final floor = StatisticsA6Geometry.floorOf(known.reduce(math.min));
    double y(double percent) =>
        StatisticsA6Geometry.yOf(percent, floor, maxPercent);
    final count = points.length;
    double x(int index) => StatisticsA6Geometry.xOf(index, count);
    final start = highlightStart;
    if (start != null && start < count - 1) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            x(start),
            StatisticsA6Geometry.plotTop,
            x(count - 1),
            StatisticsA6Geometry.baseline,
          ),
          const Radius.circular(6),
        ),
        Paint()..color = const Color.fromRGBO(242, 179, 239, 0.08),
      );
    }
    canvas.drawLine(
      const Offset(StatisticsA6Geometry.firstX, StatisticsA6Geometry.baseline),
      const Offset(StatisticsA6Geometry.lastX, StatisticsA6Geometry.baseline),
      Paint()
        ..color = StatChartPalette.axis
        ..strokeWidth = 1,
    );
    final grid = StatisticsA6Geometry.gridOf(floor, maxPercent);
    if (grid != null) {
      statisticsChartDashed(
        canvas,
        Offset(StatisticsA6Geometry.firstX, y(grid)),
        Offset(StatisticsA6Geometry.lastX, y(grid)),
        color: StatChartPalette.axis,
        width: 1,
        dash: 2,
      );
      _axisLabel(canvas, grid, y(grid));
    }
    _axisLabel(canvas, floor, StatisticsA6Geometry.baseline);
    // 선(모르는 점에서 끊는다).
    final line = Path();
    var open = false;
    for (final (index, point) in points.indexed) {
      final percent = point.percent;
      if (percent == null) {
        open = false;
        continue;
      }
      final offset = Offset(x(index), y(percent));
      if (open) {
        line.lineTo(offset.dx, offset.dy);
      } else {
        line.moveTo(offset.dx, offset.dy);
        open = true;
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = StatChartPalette.magnitude,
    );
    for (final (index, point) in points.indexed) {
      final percent = point.percent;
      if (percent != null) {
        final center = Offset(x(index), y(percent));
        final pink = start != null && (index == start || index == count - 1);
        canvas.drawCircle(
          center,
          StatisticsA6Geometry.dotRadius,
          Paint()
            ..color = pink
                ? StatChartPalette.highlight
                : StatChartPalette.magnitude,
        );
        canvas.drawCircle(
          center,
          StatisticsA6Geometry.dotRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _dotStroke,
        );
      }
      statisticsChartText(
        canvas,
        point.label,
        Offset(x(index), StatisticsA6Geometry.dateLabelY),
        color: StatChartPalette.axisLabel,
      );
    }
    final last = points.last.percent;
    if (last != null) {
      statisticsChartText(
        canvas,
        '${last.toStringAsFixed(1)}%',
        Offset(x(count - 1) - 6, y(last) - 12),
        align: TextAlign.end,
        fontSize: 13,
        display: true,
      );
    }
    final text = highlightText;
    if (start != null && text != null) {
      statisticsChartText(
        canvas,
        text,
        Offset(
          (x(start) + x(count - 1)) / 2,
          StatisticsA6Geometry.highlightLabelY,
        ),
        fontSize: 11,
        fontWeight: AppType.bold,
        color: StatChartPalette.highlight,
      );
    }
  }

  void _axisLabel(Canvas canvas, double percent, double y) =>
      statisticsChartText(
        canvas,
        '${percent.round()}',
        Offset(StatisticsA6Geometry.axisLabelRight, y + 4),
        align: TextAlign.end,
        fontSize: 10,
        color: StatChartPalette.axisLabel,
      );

  @override
  bool shouldRepaint(StatisticsGrowthTrendPainter oldPainter) =>
      !listEquals(oldPainter.points, points) ||
      oldPainter.highlightStart != highlightStart ||
      oldPainter.highlightText != highlightText;
}

/// A6 그래프.
class StatisticsGrowthTrendChart extends StatelessWidget {
  const StatisticsGrowthTrendChart({super.key, required this.trend});

  final StatisticsGrowthTrend trend;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: Alignment.centerLeft,
      child: StatChartFrame(
        key: const ValueKey('statistics-a6-chart'),
        viewBox: statisticsA6ViewBox,
        scale: statisticsChartScale(constraints.biggest, statisticsA6ViewBox),
        semanticLabel: '성장 추이',
        painter: StatisticsGrowthTrendPainter(
          points: [
            for (final point in trend.points)
              StatisticsA6PaintPoint(
                label: statisticsDateText(point.at),
                percent: point.averageGrowth == null
                    ? null
                    : (point.averageGrowth! * 1000).round() / 10,
              ),
          ],
          highlightStart: trend.highlightStart,
          highlightText: trend.highlightText,
        ),
      ),
    ),
  );
}

// --- B3 주요 재화 변화 -----------------------------------------------------------------

/// B3 설계 좌표(시안 viewBox).
const statisticsB3ViewBox = Size(1030, 226);

/// B3 설계 좌표(시안 rect · polyline · text 좌표).
abstract final class StatisticsB3Geometry {
  static const panelWidth = 328.7;
  static const panelPitch = 350.7;
  static const panelHeight = 208.0;

  /// 패널 안 선 왼쪽 · 오른쪽, 값 위 · 아래 끝(시안 상급 보고서 384 → 51.1, 180 → 169.6).
  static const lineLeft = 8.0;
  static const lineRight = 320.7;
  static const valueTop = 51.1;
  static const valueBottom = 169.6;

  /// 이름 · 필요 글자 · 아래 글자 밑변.
  static const nameY = 18.0;
  static const requiredY = 32.0;
  static const valueY = 200.0;
  static const changeY = 199.0;
  static const captionY = 224.0;
  static const dotRadius = 4.5;

  static double xOf(int panel, int index, int count) {
    final left = panel * panelPitch + lineLeft;
    final right = panel * panelPitch + lineRight;
    return count <= 1 ? right : left + (right - left) * index / (count - 1);
  }

  /// 값 → 높이(패널마다 그 재화의 가장 작은 · 큰 값). 모두 같으면 가운데다.
  static double yOf(int value, int low, int high) => high == low
      ? (valueTop + valueBottom) / 2
      : valueBottom - (valueBottom - valueTop) * (value - low) / (high - low);
}

/// 축 설명(시안 그대로).
const statisticsB3Caption = '패널마다 축이 따로 · 단위를 섞지 않음';

/// B3 패널 값(painter 비교용).
@immutable
class StatisticsB3PaintPanel {
  StatisticsB3PaintPanel({
    required this.name,
    required List<StatisticsResourcePoint> points,
    required this.netChange,
    required this.required,
  }) : points = List.unmodifiable(points);

  factory StatisticsB3PaintPanel.of(StatisticsResourceTrend trend) =>
      StatisticsB3PaintPanel(
        name: trend.name,
        points: trend.points,
        netChange: trend.netChange,
        required: trend.required,
      );

  final String name;
  final List<StatisticsResourcePoint> points;
  final int? netChange;
  final int? required;

  @override
  bool operator ==(Object other) =>
      other is StatisticsB3PaintPanel &&
      other.name == name &&
      other.netChange == netChange &&
      other.required == required &&
      listEquals(other.points, points);

  @override
  int get hashCode =>
      Object.hash(name, netChange, required, Object.hashAll(points));
}

/// B3 작은 배수 painter.
class StatisticsResourceTrendPainter extends StatChartPainter {
  StatisticsResourceTrendPainter({required List<StatisticsB3PaintPanel> panels})
    : panels = List.unmodifiable(panels);

  final List<StatisticsB3PaintPanel> panels;

  @override
  void paint(Canvas canvas, Size viewBox) {
    for (final (index, panel) in panels.indexed) {
      _panel(canvas, index, panel);
    }
    statisticsChartText(
      canvas,
      statisticsB3Caption,
      Offset(statisticsB3ViewBox.width, StatisticsB3Geometry.captionY),
      align: TextAlign.end,
      fontSize: 10,
      color: StatChartPalette.axisLabel,
    );
  }

  void _panel(Canvas canvas, int index, StatisticsB3PaintPanel panel) {
    final left = index * StatisticsB3Geometry.panelPitch;
    final right = left + StatisticsB3Geometry.lineRight;
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        left,
        0,
        StatisticsB3Geometry.panelWidth,
        StatisticsB3Geometry.panelHeight,
      ),
      const Radius.circular(8),
    );
    canvas
      ..drawRRect(box, Paint()..color = const Color.fromRGBO(16, 24, 35, 0.5))
      ..drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color.fromRGBO(56, 81, 107, 0.6),
      );
    statisticsChartText(
      canvas,
      panel.name,
      Offset(left + 10, StatisticsB3Geometry.nameY),
      align: TextAlign.start,
      fontSize: 11.5,
      fontWeight: AppType.bold,
      maxWidth: StatisticsB3Geometry.panelWidth - 20,
    );
    final values = [
      for (final point in panel.points)
        if (point.value != null) point.value!,
    ];
    if (values.isEmpty) return;
    final low = values.reduce(math.min), high = values.reduce(math.max);
    final count = panel.points.length;
    double x(int point) => StatisticsB3Geometry.xOf(index, point, count);
    double y(int value) => StatisticsB3Geometry.yOf(value, low, high);
    final required = panel.required;
    if (required != null) {
      if (required >= low && required <= high && high > low) {
        statisticsChartDashed(
          canvas,
          Offset(left + StatisticsB3Geometry.lineLeft, y(required)),
          Offset(right, y(required)),
          color: const Color.fromRGBO(244, 248, 251, 0.45),
          width: 1,
          dash: 3.5,
        );
        statisticsChartText(
          canvas,
          '필요',
          Offset(right, y(required) - 4),
          align: TextAlign.end,
          fontSize: 10,
          color: StatChartPalette.axisLabel,
        );
      } else {
        statisticsChartText(
          canvas,
          '필요 ${statisticsAmountText(required)} '
          '${required > high ? '↑' : '↓'}',
          Offset(right, StatisticsB3Geometry.requiredY),
          align: TextAlign.end,
          fontSize: 10,
          color: StatChartPalette.axisLabel,
        );
      }
    }
    final line = Path();
    var open = false;
    for (final (point, item) in panel.points.indexed) {
      final value = item.value;
      if (value == null) {
        open = false;
        continue;
      }
      if (open) {
        line.lineTo(x(point), y(value));
      } else {
        line.moveTo(x(point), y(value));
        open = true;
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = StatChartPalette.magnitude,
    );
    final last = panel.points.last;
    final lastValue = last.value;
    if (lastValue != null) {
      final center = Offset(x(count - 1), y(lastValue));
      if (last.scan) {
        canvas.drawCircle(
          center,
          StatisticsB3Geometry.dotRadius,
          Paint()..color = StatChartPalette.magnitude,
        );
        canvas.drawCircle(
          center,
          StatisticsB3Geometry.dotRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = _dotStroke,
        );
      } else {
        canvas.drawCircle(
          center,
          StatisticsB3Geometry.dotRadius,
          Paint()..color = _dotStroke,
        );
        canvas.drawCircle(
          center,
          StatisticsB3Geometry.dotRadius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = StatChartPalette.magnitude,
        );
      }
    }
    statisticsChartText(
      canvas,
      statisticsAmountText(lastValue),
      Offset(right - 2, StatisticsB3Geometry.valueY),
      align: TextAlign.end,
      fontSize: 13,
      display: true,
    );
    final net = panel.netChange;
    statisticsChartText(
      canvas,
      net == null ? '—' : statisticsSignedAmount(net),
      Offset(left + 10, StatisticsB3Geometry.changeY),
      align: TextAlign.start,
      fontSize: 11,
      fontWeight: AppType.bold,
      color: net == null || net == 0
          ? StatChartPalette.valueLabel
          : net < 0
          ? StatChartPalette.highlight
          : StatChartPalette.status,
    );
  }

  @override
  bool shouldRepaint(StatisticsResourceTrendPainter oldPainter) =>
      !listEquals(oldPainter.panels, panels);
}

/// B3 그래프.
class StatisticsResourceTrendChart extends StatelessWidget {
  const StatisticsResourceTrendChart({super.key, required this.trends});

  final StatisticsResourceTrends trends;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Align(
      alignment: Alignment.centerLeft,
      child: StatChartFrame(
        key: const ValueKey('statistics-b3-chart'),
        viewBox: statisticsB3ViewBox,
        scale: statisticsChartScale(constraints.biggest, statisticsB3ViewBox),
        semanticLabel: '주요 재화 변화',
        painter: StatisticsResourceTrendPainter(
          panels: [
            for (final panel in trends.panels) StatisticsB3PaintPanel.of(panel),
          ],
        ),
      ),
    ),
  );
}
