// 통계 "인벤토리 현황" B1 · "계획 집계" C1 · C2 그래프(FE7-c, 시안 Stats-Inventory · Stats-Plan, F §2.3 · §5 · §7).
//
// 셋 다 시안 SVG viewBox(설계 좌표)에서 그린 뒤 키트 [StatChartFrame]이 균일 배율한다(FE7-b A1 · A2와 같은 방식, 차트
// 라이브러리 없음). 글자 · 점선은 성장 차트와 같은 공용 함수([statisticsChartText] · [statisticsChartDashed])다.
// - B1 카테고리별 충족률(viewBox 457×196): 공통 트랙 가로 막대(행마다 사선을 따라 왼쪽으로), 60% 기준 점선 + "60% 기준",
//   60% 미만 분홍 · 이상 파랑(α.8), 계획 재화를 모두 모르는 카테고리는 트랙 빗금 + "모름 · 스캔 없음" + '—'.
//   일부만 모르면 그 재화를 평균에서 빼고 왼쪽 아래에 "보유 모름 n종 제외"(FD-032).
// - C1 필요량 vs 보유(viewBox 464×196): 행마다 자기 필요량을 100%(눈금)로 맞춘 불릿. 막대 = 보유(넘치면 트랙 끝까지),
//   빗금 = 모자란 양(보유 끝 → 눈금), 오른쪽 "보유 / 필요"(모자라면 분홍). 보유를 모르면 눈금까지 빗금 + "— / 필요".
// - C2 병목 매트릭스(viewBox 464×232): 충족률(가로) × 영향 학생 수(세로) 산점도, "먼저 볼 병목" 분홍 구역(충족률 50% 미만 ·
//   학생 3명 이상), 구역 안 점은 이름, 고른 점은 분홍 큰 점 + 흰 이름. 보유를 모르는 재화는 점이 없고 "보유 모름 n종 제외".
// 막대 · 행 · 점을 누르면 그 카테고리 · 재화를 고른다(같은 것을 다시 누르면 푼다).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../statistics/statistics_supply_projection.dart';
import '../inventory/inventory_view_model.dart';
import '../kit/hatch.dart';
import '../kit/stat_chart.dart';
import 'statistics_growth_charts.dart';

/// B1 · C1 · C2 설계 좌표(시안 viewBox).
const statisticsB1ViewBox = Size(457, 196);
const statisticsC1ViewBox = Size(464, 196);
const statisticsC2ViewBox = Size(464, 232);

final _tan10 = math.tan(10 * math.pi / 180);

/// 트랙(rgba(255,255,255,.07) · C1 .06), 크기 막대(#71c7f4 α.8 · C1 α.85).
const _b1Track = Color.fromRGBO(255, 255, 255, 0.07);
const _b1Bar = Color.fromRGBO(113, 199, 244, 0.8);
const _c1Track = Color.fromRGBO(255, 255, 255, 0.06);
const _c1Bar = Color.fromRGBO(113, 199, 244, 0.85);

/// 60% 기준선(rgba(242,179,239,.7)).
const _thresholdLine = Color.fromRGBO(242, 179, 239, 0.7);

/// C2 점(#5d7184 · 테두리 #16202c), 분홍 구역(바탕 α.09 · 테두리 α.45).
const _c2Dot = Color(0xff5d7184);
const _c2DotStroke = Color(0xff16202c);
const _c2ZoneFill = Color.fromRGBO(242, 179, 239, 0.09);
const _c2ZoneStroke = Color.fromRGBO(242, 179, 239, 0.45);

String _unknownExcludedText(int count) => '보유 모름 $count종 제외';

/// 둥근 사각형을 [anchor](밑변 위 점) 기준으로 −10° 기울인 모양.
Path _skewedRect(Rect rect, Offset anchor, {double radius = 3}) {
  final r = math.min(radius, math.min(rect.width, rect.height) / 2);
  return (Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r))))
      .transform(statSkewMatrix(anchor).storage);
}

// --- B1 ----------------------------------------------------------------------

/// B1 설계 좌표(시안 rect · text 좌표). 행 간격은 첫 행 밑변 23 · 마지막 행 밑변 163 사이를 행 수로 나눈다
/// (시안 6행이면 28).
abstract final class StatisticsB1Geometry {
  static const firstBaseline = 23.0;
  static const lastBaseline = 163.0;
  static const barHeight = 16.0;
  static const trackLeft = 120.7;
  static const trackWidth = 265.9;
  static const labelLeft = 24.7;
  static const labelMaxWidth = 92.0;
  static const valueRight = 438.6;
  static const thresholdLabel = Offset(261.5, 180);
  static const unknownLabel = Offset(0, 180);

  /// "모름 · 스캔 없음"은 트랙 가운데에서 4 오른쪽(시안 232.9).
  static const unknownTextOffset = 4.0;

  static double pitch(int rows) =>
      rows <= 1 ? 0 : (lastBaseline - firstBaseline) / (rows - 1);

  static double baselineOf(int index, int rows) =>
      firstBaseline + pitch(rows) * index;

  static double shiftOf(int index, int rows) =>
      (baselineOf(index, rows) - firstBaseline) * _tan10;

  /// 60% 기준선의 x(y).
  static double thresholdX(double y) =>
      trackLeft +
      trackWidth * statisticsSupplyFillThreshold +
      (firstBaseline - y) * _tan10;

  /// 행 [index]의 트랙(기울인 모양). [fraction]을 주면 그 길이의 채움 막대다.
  static Path barPath(int index, int rows, {double fraction = 1}) {
    final baseline = baselineOf(index, rows);
    final left = trackLeft - shiftOf(index, rows);
    final width = trackWidth * fraction.clamp(0.0, 1.0);
    return _skewedRect(
      Rect.fromLTWH(left, baseline - barHeight, width, barHeight),
      Offset(left, baseline),
    );
  }

  /// 행 [index]의 누르는 자리(라벨부터 퍼센트까지 가로 띠).
  static Rect rowBand(int index, int rows) {
    final baseline = baselineOf(index, rows);
    final half = math.max(0.0, (pitch(rows) - barHeight) / 2);
    return Rect.fromLTRB(
      0,
      baseline - barHeight - half,
      statisticsB1ViewBox.width,
      baseline + half,
    );
  }
}

/// B1 한 행 값.
@immutable
class StatisticsB1Row {
  const StatisticsB1Row({
    required this.category,
    required this.label,
    required this.fulfillment,
    required this.unknownKinds,
  });

  factory StatisticsB1Row.of(StatisticsCategoryFill fill) => StatisticsB1Row(
    category: fill.category,
    label: fill.label,
    fulfillment: fill.fulfillment,
    unknownKinds: fill.coverage.unknownKinds,
  );

  final String category;
  final String label;
  final double? fulfillment;
  final int unknownKinds;

  @override
  bool operator ==(Object other) =>
      other is StatisticsB1Row &&
      other.category == category &&
      other.label == label &&
      other.fulfillment == fulfillment &&
      other.unknownKinds == unknownKinds;

  @override
  int get hashCode => Object.hash(category, label, fulfillment, unknownKinds);
}

/// B1 카테고리별 충족률 painter.
class StatisticsCategoryFillPainter extends StatChartPainter {
  const StatisticsCategoryFillPainter({
    required this.rows,
    this.selectedCategory,
  });

  final List<StatisticsB1Row> rows;
  final String? selectedCategory;

  @override
  void paint(Canvas canvas, Size viewBox) {
    const top = 2.0;
    const bottom = 166.0;
    statisticsChartDashed(
      canvas,
      Offset(StatisticsB1Geometry.thresholdX(top), top),
      Offset(StatisticsB1Geometry.thresholdX(bottom), bottom),
      color: _thresholdLine,
      width: 1.2,
      dash: 3,
    );
    final count = rows.length;
    var excluded = 0;
    for (final (index, row) in rows.indexed) {
      final baseline = StatisticsB1Geometry.baselineOf(index, count);
      final shift = StatisticsB1Geometry.shiftOf(index, count);
      final selected = row.category == selectedCategory;
      final value = row.fulfillment;
      statisticsChartText(
        canvas,
        row.label,
        Offset(StatisticsB1Geometry.labelLeft - shift, baseline - 3.2),
        align: TextAlign.start,
        fontSize: 12,
        color: selected
            ? AppColors.accentText
            : value == null
            ? StatChartPalette.valueLabel
            : AppColors.text,
        maxWidth: StatisticsB1Geometry.labelMaxWidth,
      );
      final track = StatisticsB1Geometry.barPath(index, count);
      canvas.drawPath(track, Paint()..color = _b1Track);
      if (value == null) {
        paintHatch(canvas, track);
        statisticsChartText(
          canvas,
          '모름 · 스캔 없음',
          Offset(
            StatisticsB1Geometry.trackLeft -
                shift +
                StatisticsB1Geometry.trackWidth / 2 +
                StatisticsB1Geometry.unknownTextOffset,
            baseline - 3.2,
          ),
          fontSize: 11,
          color: StatChartPalette.valueLabel,
        );
      } else {
        excluded += row.unknownKinds;
        if (value > 0) {
          canvas.drawPath(
            StatisticsB1Geometry.barPath(index, count, fraction: value),
            Paint()
              ..color = value < statisticsSupplyFillThreshold
                  ? StatChartPalette.highlight
                  : _b1Bar,
          );
        }
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
      if (value == null) {
        statisticsChartText(
          canvas,
          '—',
          Offset(StatisticsB1Geometry.valueRight - shift, baseline - 3.2),
          align: TextAlign.end,
          fontSize: 13,
          color: StatChartPalette.valueLabel,
        );
      } else {
        statisticsChartText(
          canvas,
          statisticsFillText(value),
          Offset(StatisticsB1Geometry.valueRight - shift, baseline - 2.7),
          align: TextAlign.end,
          fontSize: 13,
          display: true,
        );
      }
    }
    statisticsChartText(
      canvas,
      '${(statisticsSupplyFillThreshold * 100).round()}% 기준',
      StatisticsB1Geometry.thresholdLabel,
      align: TextAlign.start,
      color: StatChartPalette.highlight,
    );
    if (excluded > 0) {
      statisticsChartText(
        canvas,
        _unknownExcludedText(excluded),
        StatisticsB1Geometry.unknownLabel,
        align: TextAlign.start,
        color: StatChartPalette.valueLabel,
      );
    }
  }

  @override
  bool shouldRepaint(StatisticsCategoryFillPainter oldPainter) =>
      oldPainter.selectedCategory != selectedCategory ||
      !_listEquals(oldPainter.rows, rows);
}

// --- C1 ----------------------------------------------------------------------

/// C1 설계 좌표(시안 rect · line · text 좌표). 행 밑변 27 + 32 × 행, 트랙 130 → 325.6, 필요량 눈금은 트랙 시작에서
/// 157.9(트랙의 80.7%, 넘치는 보유를 트랙 끝까지 보인다).
abstract final class StatisticsC1Geometry {
  static const firstBaseline = 27.0;
  static const pitch = 32.0;
  static const trackLeft = 130.0;
  static const trackWidth = 195.6;
  static const trackHeight = 16.0;
  static const requiredSpan = 157.9;
  static const barHeight = 10.0;
  static const barLift = 3.0;
  static const labelRight = 120.0;
  static const labelMaxWidth = 118.0;
  static const valueRight = 459.6;

  /// 눈금 위 · 아래 끝(밑변에서 −18 · +2)과 기울기(시안 287.9 → 289.9).
  static const tickTop = 18.0;
  static const tickBottom = 2.0;
  static const tickLean = 2.0;
  static const legendBaseline = 174.0;
  static const legendHatch = Offset(130, legendBaseline);
  static const legendTick = Offset(286.5, legendBaseline);

  static double baselineOf(int index) => firstBaseline + pitch * index;

  static double get tickX => trackLeft + requiredSpan;

  /// 행 [index]의 트랙.
  static Path trackPath(int index) {
    final baseline = baselineOf(index);
    return _skewedRect(
      Rect.fromLTWH(trackLeft, baseline - trackHeight, trackWidth, trackHeight),
      Offset(trackLeft, baseline),
    );
  }

  /// 보유 막대(필요량 대비 [ratio], 트랙 끝에서 자른다).
  static Path ownedPath(int index, double ratio) {
    final base = baselineOf(index) - barLift;
    final width = math.min(trackWidth, requiredSpan * math.max(0.0, ratio));
    return _skewedRect(
      Rect.fromLTWH(trackLeft, base - barHeight, width, barHeight),
      Offset(trackLeft, base),
    );
  }

  /// 모자란 양 빗금(보유 끝 → 눈금, 트랙 높이). 모자라지 않으면 null.
  static Path? shortagePath(int index, double ratio) {
    final from = requiredSpan * ratio.clamp(0.0, 1.0);
    final width = requiredSpan - from;
    if (width <= 0) return null;
    final baseline = baselineOf(index);
    return _skewedRect(
      Rect.fromLTWH(trackLeft + from, baseline - trackHeight, width, trackHeight),
      Offset(trackLeft + from, baseline),
    );
  }

  /// 행 [index]의 누르는 자리.
  static Rect rowBand(int index) {
    final baseline = baselineOf(index);
    return Rect.fromLTRB(
      0,
      baseline - trackHeight - (pitch - trackHeight) / 2,
      statisticsC1ViewBox.width,
      baseline + (pitch - trackHeight) / 2,
    );
  }
}

/// C1 한 행 값.
@immutable
class StatisticsC1Row {
  const StatisticsC1Row({
    required this.key,
    required this.label,
    required this.requiredAmount,
    required this.owned,
  });

  factory StatisticsC1Row.of(InventoryItemView view) => StatisticsC1Row(
    key: view.key,
    label: view.item.displayName,
    requiredAmount: view.requiredAmount ?? 0,
    owned: view.owned,
  );

  final String key;
  final String label;
  final int requiredAmount;
  final int? owned;

  double? get ratio {
    final owned = this.owned;
    if (owned == null || requiredAmount <= 0) return null;
    return owned / requiredAmount;
  }

  @override
  bool operator ==(Object other) =>
      other is StatisticsC1Row &&
      other.key == key &&
      other.label == label &&
      other.requiredAmount == requiredAmount &&
      other.owned == owned;

  @override
  int get hashCode => Object.hash(key, label, requiredAmount, owned);
}

/// C1 필요량 vs 보유 painter.
class StatisticsBulletPainter extends StatChartPainter {
  const StatisticsBulletPainter({required this.rows, this.selectedKey});

  final List<StatisticsC1Row> rows;
  final String? selectedKey;

  @override
  void paint(Canvas canvas, Size viewBox) {
    for (final (index, row) in rows.indexed) {
      final baseline = StatisticsC1Geometry.baselineOf(index);
      final selected = row.key == selectedKey;
      final ratio = row.ratio;
      statisticsChartText(
        canvas,
        row.label,
        Offset(StatisticsC1Geometry.labelRight, baseline - 4),
        align: TextAlign.end,
        fontSize: 11.5,
        color: selected
            ? AppColors.accentText
            : ratio == null
            ? StatChartPalette.valueLabel
            : AppColors.text,
        maxWidth: StatisticsC1Geometry.labelMaxWidth,
      );
      final track = StatisticsC1Geometry.trackPath(index);
      canvas.drawPath(track, Paint()..color = _c1Track);
      final shortage = StatisticsC1Geometry.shortagePath(index, ratio ?? 0);
      if (shortage != null) paintHatch(canvas, shortage);
      if (ratio != null && ratio > 0) {
        canvas.drawPath(
          StatisticsC1Geometry.ownedPath(index, ratio),
          Paint()..color = _c1Bar,
        );
      }
      final tickX = StatisticsC1Geometry.tickX;
      canvas.drawLine(
        Offset(tickX, baseline - StatisticsC1Geometry.tickTop),
        Offset(
          tickX + StatisticsC1Geometry.tickLean,
          baseline + StatisticsC1Geometry.tickBottom,
        ),
        Paint()
          ..color = AppColors.text
          ..strokeWidth = 2.4,
      );
      if (selected) {
        canvas.drawPath(
          track,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = StatChartPalette.highlight,
        );
      }
      final short = ratio == null || ratio < 1;
      statisticsChartText(
        canvas,
        '${statisticsAmountText(row.owned)} / '
        '${statisticsAmountText(row.requiredAmount)}',
        Offset(StatisticsC1Geometry.valueRight, baseline - 4),
        align: TextAlign.end,
        fontSize: 11.5,
        fontWeight: AppType.bold,
        color: ratio == null
            ? StatChartPalette.valueLabel
            : short
            ? StatChartPalette.highlight
            : AppColors.text,
      );
    }
    statisticsChartText(
      canvas,
      '필요량 = 눈금 (행마다 자기 단위)',
      StatisticsC1Geometry.legendTick,
      fontSize: 10,
      color: StatChartPalette.axisLabel,
    );
    statisticsChartText(
      canvas,
      '빗금 = 모자란 양',
      StatisticsC1Geometry.legendHatch,
      align: TextAlign.start,
      fontSize: 10,
      color: StatChartPalette.axisLabel,
    );
  }

  @override
  bool shouldRepaint(StatisticsBulletPainter oldPainter) =>
      oldPainter.selectedKey != selectedKey ||
      !_listEquals(oldPainter.rows, rows);
}

// --- C2 ----------------------------------------------------------------------

/// C2 설계 좌표(시안 line · rect · circle · text 좌표).
abstract final class StatisticsC2Geometry {
  static const originX = 40.0;
  static const axisEndX = 443.6;
  static const baseline = 204.0;
  static const plotTop = 10.0;
  static const dotRadius = 5.5;
  static const selectedRadius = 7.0;
  static const hitRadius = 12.0;
  static const zoneLabel = Offset(50, 26);

  static double get plotWidth => axisEndX - originX;
  static double get plotHeight => baseline - plotTop;

  static double xOf(double fulfillment) =>
      originX + plotWidth * fulfillment.clamp(0.0, 1.0);

  static double yOf(int students, int maxStudents) =>
      baseline - plotHeight * students / math.max(1, maxStudents);

  /// "먼저 볼 병목" 구역(축 안쪽 1 · 충족률 50% · 학생 3명 · 축 위 끝).
  static Rect zone(int maxStudents) => Rect.fromLTRB(
    originX + 1,
    plotTop,
    xOf(statisticsC2ZoneFill),
    yOf(statisticsC2ZoneStudents, maxStudents),
  );
}

/// C2 점 하나 값.
@immutable
class StatisticsC2Dot {
  const StatisticsC2Dot({
    required this.key,
    required this.label,
    required this.fulfillment,
    required this.students,
    required this.inZone,
  });

  factory StatisticsC2Dot.of(StatisticsC2Point point) => StatisticsC2Dot(
    key: point.view.key,
    label: point.view.item.displayName,
    fulfillment: point.fulfillment,
    students: point.students,
    inZone: point.inZone,
  );

  final String key;
  final String label;
  final double fulfillment;
  final int students;
  final bool inZone;

  Offset center(int maxStudents) => Offset(
    StatisticsC2Geometry.xOf(fulfillment),
    StatisticsC2Geometry.yOf(students, maxStudents),
  );

  @override
  bool operator ==(Object other) =>
      other is StatisticsC2Dot &&
      other.key == key &&
      other.label == label &&
      other.fulfillment == fulfillment &&
      other.students == students &&
      other.inZone == inZone;

  @override
  int get hashCode => Object.hash(key, label, fulfillment, students, inZone);
}

/// C2 병목 매트릭스 painter.
class StatisticsBottleneckPainter extends StatChartPainter {
  const StatisticsBottleneckPainter({
    required this.dots,
    required this.maxStudents,
    required this.unknownKinds,
    this.selectedKey,
  });

  final List<StatisticsC2Dot> dots;
  final int maxStudents;
  final int unknownKinds;
  final String? selectedKey;

  @override
  void paint(Canvas canvas, Size viewBox) {
    final axis = Paint()
      ..color = StatChartPalette.axis
      ..strokeWidth = 1;
    canvas.drawLine(
      const Offset(StatisticsC2Geometry.originX, StatisticsC2Geometry.baseline),
      const Offset(StatisticsC2Geometry.axisEndX, StatisticsC2Geometry.baseline),
      axis,
    );
    canvas.drawLine(
      const Offset(StatisticsC2Geometry.originX, StatisticsC2Geometry.baseline),
      const Offset(StatisticsC2Geometry.originX, StatisticsC2Geometry.plotTop),
      axis,
    );
    final zone = RRect.fromRectAndRadius(
      StatisticsC2Geometry.zone(maxStudents),
      const Radius.circular(6),
    );
    canvas.drawRRect(zone, Paint()..color = _c2ZoneFill);
    _strokeDashedRRect(canvas, zone);
    statisticsChartText(
      canvas,
      '먼저 볼 병목',
      StatisticsC2Geometry.zoneLabel,
      align: TextAlign.start,
      fontSize: 11,
      fontWeight: AppType.bold,
      color: StatChartPalette.highlight,
    );
    StatisticsC2Dot? selected;
    for (final dot in dots) {
      if (dot.key == selectedKey) {
        selected = dot;
        continue;
      }
      final center = dot.center(maxStudents);
      canvas.drawCircle(
        center,
        StatisticsC2Geometry.dotRadius,
        Paint()..color = _c2Dot,
      );
      canvas.drawCircle(
        center,
        StatisticsC2Geometry.dotRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _c2DotStroke,
      );
      if (dot.inZone) {
        statisticsChartText(
          canvas,
          dot.label,
          center + const Offset(9, 4),
          align: TextAlign.start,
          color: StatChartPalette.valueLabel,
          maxWidth: 120,
        );
      }
    }
    final chosen = selected;
    if (chosen != null) {
      final center = chosen.center(maxStudents);
      canvas.drawCircle(
        center,
        StatisticsC2Geometry.selectedRadius,
        Paint()..color = StatChartPalette.highlight,
      );
      canvas.drawCircle(
        center,
        StatisticsC2Geometry.selectedRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _c2DotStroke,
      );
      statisticsChartText(
        canvas,
        chosen.label,
        center + const Offset(11, -6),
        align: TextAlign.start,
        fontSize: 12,
        fontWeight: AppType.bold,
        maxWidth: 160,
      );
    }
    statisticsChartText(
      canvas,
      '충족률 →',
      const Offset(StatisticsC2Geometry.axisEndX, 222),
      align: TextAlign.end,
      color: StatChartPalette.axisLabel,
    );
    statisticsChartText(
      canvas,
      '학생',
      const Offset(36, 12),
      align: TextAlign.end,
      color: StatChartPalette.axisLabel,
    );
    statisticsChartText(
      canvas,
      '0',
      const Offset(36, 202),
      align: TextAlign.end,
      fontSize: 10,
      color: StatChartPalette.axisLabel,
    );
    statisticsChartText(
      canvas,
      '0%',
      const Offset(StatisticsC2Geometry.originX, 218),
      fontSize: 10,
      color: StatChartPalette.axisLabel,
    );
    if (unknownKinds > 0) {
      statisticsChartText(
        canvas,
        _unknownExcludedText(unknownKinds),
        const Offset(StatisticsC2Geometry.axisEndX, 12),
        align: TextAlign.end,
        color: StatChartPalette.valueLabel,
      );
    }
  }

  /// 구역 테두리 4-3 점선(시안 stroke-dasharray "4 3").
  void _strokeDashedRRect(Canvas canvas, RRect rrect) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _c2ZoneStroke;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += 7) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + 4, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(StatisticsBottleneckPainter oldPainter) =>
      oldPainter.selectedKey != selectedKey ||
      oldPainter.maxStudents != maxStudents ||
      oldPainter.unknownKinds != unknownKinds ||
      !_listEquals(oldPainter.dots, dots);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

// --- 위젯 ----------------------------------------------------------------------

/// B1 그래프. 카테고리 막대를 누르면 [onCategorySelected](같은 막대를 다시 누르면 null).
class StatisticsCategoryFillChart extends StatelessWidget {
  const StatisticsCategoryFillChart({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final List<StatisticsCategoryFill> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final rows = [for (final fill in categories) StatisticsB1Row.of(fill)];
      return Align(
        alignment: Alignment.centerLeft,
        child: StatChartFrame(
          key: const ValueKey('statistics-b1-chart'),
          viewBox: statisticsB1ViewBox,
          scale: statisticsChartScale(constraints.biggest, statisticsB1ViewBox),
          semanticLabel: '카테고리별 충족률',
          painter: StatisticsCategoryFillPainter(
            rows: rows,
            selectedCategory: selectedCategory,
          ),
          onTapAt: (point) {
            for (final (index, row) in rows.indexed) {
              if (StatisticsB1Geometry.rowBand(index, rows.length)
                  .contains(point)) {
                onCategorySelected(
                  row.category == selectedCategory ? null : row.category,
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

/// C1 그래프. 행을 누르면 [onResourceSelected](같은 행을 다시 누르면 null).
class StatisticsBulletChart extends StatelessWidget {
  const StatisticsBulletChart({
    super.key,
    required this.rows,
    required this.selectedKey,
    required this.onResourceSelected,
  });

  final List<InventoryItemView> rows;
  final String? selectedKey;
  final ValueChanged<String?> onResourceSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final values = [for (final view in rows) StatisticsC1Row.of(view)];
      return Align(
        alignment: Alignment.centerLeft,
        child: StatChartFrame(
          key: const ValueKey('statistics-c1-chart'),
          viewBox: statisticsC1ViewBox,
          scale: statisticsChartScale(constraints.biggest, statisticsC1ViewBox),
          semanticLabel: '필요량 vs 보유',
          painter: StatisticsBulletPainter(
            rows: values,
            selectedKey: selectedKey,
          ),
          onTapAt: (point) {
            for (final (index, row) in values.indexed) {
              if (StatisticsC1Geometry.rowBand(index).contains(point)) {
                onResourceSelected(row.key == selectedKey ? null : row.key);
                return;
              }
            }
          },
        ),
      );
    },
  );
}

/// C2 그래프. 점을 누르면 [onResourceSelected](가장 가까운 점, 같은 점을 다시 누르면 null).
class StatisticsBottleneckChart extends StatelessWidget {
  const StatisticsBottleneckChart({
    super.key,
    required this.points,
    required this.maxStudents,
    required this.unknownKinds,
    required this.selectedKey,
    required this.onResourceSelected,
  });

  final List<StatisticsC2Point> points;
  final int maxStudents;
  final int unknownKinds;
  final String? selectedKey;
  final ValueChanged<String?> onResourceSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final dots = [for (final point in points) StatisticsC2Dot.of(point)];
      return Align(
        alignment: Alignment.centerLeft,
        child: StatChartFrame(
          key: const ValueKey('statistics-c2-chart'),
          viewBox: statisticsC2ViewBox,
          scale: statisticsChartScale(constraints.biggest, statisticsC2ViewBox),
          semanticLabel: '병목 매트릭스',
          painter: StatisticsBottleneckPainter(
            dots: dots,
            maxStudents: maxStudents,
            unknownKinds: unknownKinds,
            selectedKey: selectedKey,
          ),
          onTapAt: (point) {
            StatisticsC2Dot? nearest;
            var best = StatisticsC2Geometry.hitRadius;
            for (final dot in dots) {
              final distance = (dot.center(maxStudents) - point).distance;
              if (distance <= best) {
                best = distance;
                nearest = dot;
              }
            }
            final hit = nearest;
            if (hit == null) return;
            onResourceSelected(hit.key == selectedKey ? null : hit.key);
          },
        ),
      );
    },
  );
}
