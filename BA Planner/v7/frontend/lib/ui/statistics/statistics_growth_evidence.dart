// 통계 "학생 성장" 고른 구간 · 항목과 오른쪽 근거 패널 내용(FE7-b, 시안 Stats-Growth 오른쪽 섹션, F §2.4).
//
// A1에서 구간을 고르면(시안): 머리 "육성도 60~70%" + 분홍 칩 "22명", 부제 "A1에서 고른 구간 · 낮은 항목 순",
// 학생 행 7개(초상 44×36 · 이름 · Lv · "낮음" 칩, 사선 계단), "나머지 n명 모두 보기", "구간 요약"(평균 레벨 ·
// 가장 낮은 항목 · 계획 등록). A2에서 항목을 고르면 같은 틀에 그 항목이 낮은 학생 순이다(머리 "<항목> 완성도",
// 부제 "A2에서 고른 항목 · 낮은 학생 순", 행 칩 = 그 항목 완성도, 요약 "항목 요약": 평균 레벨 · 평균 완성도 · 계획 등록).
// "모두 보기"를 누르면 행 자리와 그 버튼 자리를 합친 곳에서 모든 학생을 세로로 스크롤한다(공용 스크롤바 · 포그).
// 행 모양은 시안 `.row`(왼쪽 변 80° · 오른쪽 변 수직, 바탕 · 테두리는 키트 [DiagonalRowLook] `.row`)다.
// FE7-f: A3 단계(성작 ★n · 전용무기 단계)와 A4 점(학교 · 역할)을 고르면 같은 틀이다. 머리는 "성작 ★3" · "<학교>",
// 부제 "A3에서 고른 단계 · 낮은 항목 순" · "A4에서 고른 학교 · 낮은 항목 순", 행 칩은 A1과 같은 "낮음" 칩, 요약은 A3
// "단계 요약"(A1 구간 요약과 같은 세 줄) · A4 "학교 요약"(보유율 n% · 보유 / 학생 목록, 평균 육성도, 계획 등록)이다.
// FE7-i: A5 칸(행 · 레벨 구간)을 고르면 같은 틀이다. 머리 "EX 스킬 1–3" · "장비 T7–8", 부제 "A5에서 고른 칸 · 낮은
// 항목 순", 요약 "칸 요약"(A1 구간 요약과 같은 세 줄).
// 원본 탭 이동(아래 버튼 · 학생 탭 임시 목록)은 FE7-d(`statistics_page.dart`)다. 펼친 목록 · "모두 보기" 버튼은 재화 근거
// "외 n종 · 외 n명"(FE7-d)도 같이 쓴다([statisticsEvidenceList] · [StatisticsEvidenceMoreButton]).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../statistics/statistics_breakdown_projection.dart';
import '../../statistics/statistics_growth_projection.dart';
import '../../statistics/statistics_matrix_projection.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/ba_chip.dart';
import '../kit/diagonal_row.dart';
import '../kit/diagonal_scrollbar.dart';
import '../kit/kit_pressable.dart';
import '../kit/portrait_strip.dart';
import '../kit/scroll_viewport_fog.dart';
import '../kit/section_frame.dart';
import '../kit/titles.dart';
import '../studio/statistics_studio_layout.dart';
import 'statistics_breakdown_charts.dart' show statisticsGroupLabel;

/// 성장 주제에서 고른 것.
@immutable
sealed class StatisticsGrowthSelection {
  const StatisticsGrowthSelection();
}

/// A1 구간.
final class StatisticsGrowthBinSelection extends StatisticsGrowthSelection {
  const StatisticsGrowthBinSelection(this.metric, this.bin);

  final StatisticsGrowthMetric metric;
  final int bin;

  @override
  bool operator ==(Object other) =>
      other is StatisticsGrowthBinSelection &&
      other.metric == metric &&
      other.bin == bin;

  @override
  int get hashCode => Object.hash(metric, bin);
}

/// A2 항목.
final class StatisticsGrowthItemSelection extends StatisticsGrowthSelection {
  const StatisticsGrowthItemSelection(this.item);

  final StatisticsGrowthItem item;

  @override
  bool operator ==(Object other) =>
      other is StatisticsGrowthItemSelection && other.item == item;

  @override
  int get hashCode => item.hashCode;
}

/// A3 단계(FE7-f).
final class StatisticsGrowthStarSelection extends StatisticsGrowthSelection {
  const StatisticsGrowthStarSelection(this.step);

  final StatisticsStarStep step;

  @override
  bool operator ==(Object other) =>
      other is StatisticsGrowthStarSelection && other.step == step;

  @override
  int get hashCode => step.hashCode;
}

/// A4 점(학교 · 역할, FE7-f).
final class StatisticsGrowthGroupSelection extends StatisticsGrowthSelection {
  const StatisticsGrowthGroupSelection(this.group);

  final StatisticsGroupSelection group;

  @override
  bool operator ==(Object other) =>
      other is StatisticsGrowthGroupSelection && other.group == group;

  @override
  int get hashCode => group.hashCode;
}

/// A5 칸(스킬 · 장비 레벨 구간, FE7-i).
final class StatisticsGrowthMatrixSelection extends StatisticsGrowthSelection {
  const StatisticsGrowthMatrixSelection(this.cell);

  final StatisticsMatrixCell cell;

  @override
  bool operator ==(Object other) =>
      other is StatisticsGrowthMatrixSelection && other.cell == cell;

  @override
  int get hashCode => cell.hashCode;
}

/// 성장 주제 화면 상태(페이지가 들고 있다)와 바꾸는 콜백.
@immutable
class StatisticsGrowthView {
  const StatisticsGrowthView({
    required this.growth,
    this.metric = StatisticsGrowthMetric.growth,
    this.selection,
    this.expanded = false,
    this.onMetricChanged,
    this.onSelectionChanged,
    this.onExpand,
    this.breakdown,
    this.a4Group = StatisticsA4Group.school,
    this.onA4GroupChanged,
  });

  /// 읽지 못했으면 null(KPI · 그래프 '—').
  final StatisticsGrowth? growth;

  /// A3 · A4 값([growth]와 같은 학생, FE7-f). 없으면 두 타일이 '—'다.
  final StatisticsGrowthBreakdown? breakdown;

  /// A4 seg와 바꾸는 콜백(FE7-f).
  final StatisticsA4Group a4Group;
  final ValueChanged<StatisticsA4Group>? onA4GroupChanged;

  /// A1 seg.
  final StatisticsGrowthMetric metric;
  final StatisticsGrowthSelection? selection;

  /// 근거 목록을 모두 펼쳤는가.
  final bool expanded;
  final ValueChanged<StatisticsGrowthMetric>? onMetricChanged;
  final ValueChanged<StatisticsGrowthSelection?>? onSelectionChanged;
  final VoidCallback? onExpand;

  /// 근거 패널에 보일 내용. 고른 것이 없거나 자료가 없으면 null.
  StatisticsGrowthEvidenceContent? get evidence {
    final growth = this.growth;
    final selection = this.selection;
    if (growth == null || selection == null) return null;
    switch (selection) {
      case StatisticsGrowthBinSelection(:final metric, :final bin):
        return _rangeEvidence(
          title: '${metric.label} ${statisticsGrowthBinLabel(bin)}',
          subtitle: 'A1에서 고른 구간 · 낮은 항목 순',
          students: growth.binStudents(metric, bin),
          summaryTitle: '구간 요약',
        );
      case StatisticsGrowthStarSelection(:final step):
        final students = breakdown?.stars.of(step.kind)[step.index];
        if (students == null) return null;
        return _rangeEvidence(
          title: step.kind.titleOf(step.index),
          subtitle: 'A3에서 고른 단계 · 낮은 항목 순',
          students: students,
          summaryTitle: '단계 요약',
        );
      case StatisticsGrowthMatrixSelection(:final cell):
        final matrix = breakdown?.matrix;
        if (matrix == null || !cell.row.appliesTo(cell.column)) return null;
        return _rangeEvidence(
          title: cell.title,
          subtitle: 'A5에서 고른 칸 · 낮은 항목 순',
          students: matrix[cell],
          summaryTitle: '칸 요약',
        );
      case StatisticsGrowthGroupSelection(:final group):
        final point = breakdown?.comparison(group.group)[group.value];
        if (point == null) return null;
        final summary = StatisticsGrowthSummary.of(point.students);
        final ratio = point.ownedRatio;
        final average = point.averageGrowth;
        return StatisticsGrowthEvidenceContent(
          title: statisticsGroupLabel(group.group, group.value),
          subtitle: 'A4에서 고른 ${group.group.label} · 낮은 항목 순',
          students: point.students,
          chipOf: _flagChip,
          summaryTitle: '${group.group.label} 요약',
          summary: [
            (
              'ratio',
              '보유율',
              '${ratio == null ? '—' : statisticsPercentText(ratio)} · '
                  '${point.ownedCount} / ${point.catalogCount}명',
            ),
            (
              'growth',
              '평균 육성도',
              average == null ? '—' : statisticsPercentText(average),
            ),
            ('planned', '계획 등록', '${summary.plannedCount}명'),
          ],
        );
      case StatisticsGrowthItemSelection(:final item):
        final students = growth.itemStudents(item);
        final summary = StatisticsGrowthSummary.of(students);
        final average = statisticsGrowthItemAverages(students)[item];
        return StatisticsGrowthEvidenceContent(
          title: '${item.label} 완성도',
          subtitle: 'A2에서 고른 항목 · 낮은 학생 순',
          students: students,
          chipOf: (student) {
            final value = student.items[item];
            if (value == null) return null;
            return (
              statisticsPercentText(value),
              value < statisticsGrowthLowThreshold
                  ? AppTones.warn
                  : AppTones.gray,
            );
          },
          summaryTitle: '항목 요약',
          summary: [
            ('level', '평균 레벨', _levelText(summary.averageLevel)),
            (
              'average',
              '평균 완성도',
              average == null ? '—' : statisticsPercentText(average),
            ),
            ('planned', '계획 등록', '${summary.plannedCount}명'),
          ],
        );
    }
  }
}

/// A1 구간 · A3 단계 근거: "낮음" 칩 + 요약(평균 레벨 · 가장 낮은 항목 · 계획 등록).
StatisticsGrowthEvidenceContent _rangeEvidence({
  required String title,
  required String subtitle,
  required List<StatisticsStudentGrowth> students,
  required String summaryTitle,
}) {
  final summary = StatisticsGrowthSummary.of(students);
  final lowest = summary.lowestItem;
  return StatisticsGrowthEvidenceContent(
    title: title,
    subtitle: subtitle,
    students: students,
    chipOf: _flagChip,
    summaryTitle: summaryTitle,
    summary: [
      ('level', '평균 레벨', _levelText(summary.averageLevel)),
      (
        'lowest',
        '가장 낮은 항목',
        lowest == null
            ? '—'
            : '${lowest.item.label} ${statisticsPercentText(lowest.value)}',
      ),
      ('planned', '계획 등록', '${summary.plannedCount}명'),
    ],
  );
}

/// C5 고른 구간(미계획 · 40% 미만, FE7-i) 근거: 머리 "미계획 · 40% 미만", 부제 "C5에서 고른 구간 · 육성도 낮은 순",
/// 행 칩은 A1과 같은 "낮음" 칩, 요약 "구간 요약"은 평균 레벨 · 가장 낮은 항목 · 평균 육성도다(계획 등록은 늘 0명이라 뺀다).
/// [students]는 이미 육성도 낮은 순이다.
StatisticsGrowthEvidenceContent statisticsUnplannedEvidence(
  List<StatisticsStudentGrowth> students,
) {
  final summary = StatisticsGrowthSummary.of(students);
  final lowest = summary.lowestItem;
  final known = [
    for (final student in students) ?student.growth,
  ];
  return StatisticsGrowthEvidenceContent(
    title: '미계획 · 40% 미만',
    subtitle: 'C5에서 고른 구간 · 육성도 낮은 순',
    students: students,
    chipOf: _flagChip,
    summaryTitle: '구간 요약',
    summary: [
      ('level', '평균 레벨', _levelText(summary.averageLevel)),
      (
        'lowest',
        '가장 낮은 항목',
        lowest == null
            ? '—'
            : '${lowest.item.label} ${statisticsPercentText(lowest.value)}',
      ),
      (
        'growth',
        '평균 육성도',
        known.isEmpty
            ? '—'
            : statisticsPercentText(
                known.fold<double>(0, (sum, value) => sum + value) /
                    known.length,
              ),
      ),
    ],
  );
}

/// 근거 행 "낮음" 칩(FD-029).
(String, AppTone)? _flagChip(StatisticsStudentGrowth student) {
  final flag = student.flag;
  return flag == null ? null : (flag.label, AppTones.warn);
}

String _levelText(double? value) => value == null ? '—' : '${value.round()}';

/// 근거 패널 한 장 분량.
@immutable
class StatisticsGrowthEvidenceContent {
  const StatisticsGrowthEvidenceContent({
    required this.title,
    required this.subtitle,
    required this.students,
    required this.chipOf,
    required this.summaryTitle,
    required this.summary,
  });

  final String title;
  final String subtitle;
  final List<StatisticsStudentGrowth> students;

  /// 행 오른쪽 칩(글자 · 색). 없으면 null.
  final (String, AppTone)? Function(StatisticsStudentGrowth student) chipOf;
  final String summaryTitle;

  /// 요약 행(key · 글자 · 값).
  final List<(String, String, String)> summary;
}

/// 근거 섹션 안 좌표(섹션 path 왼쪽 변 · 오른쪽 끝 · 세로 비율).
@immutable
class StatisticsEvidenceFrame {
  const StatisticsEvidenceFrame({
    required this.topLeft,
    required this.bottomLeft,
    required this.right,
    required this.scale,
  });

  final Offset topLeft;
  final Offset bottomLeft;
  final double right;
  final double scale;

  double get top => topLeft.dy;

  /// 왼쪽 사선 변의 x(y).
  double leftEdge(double y) {
    final span = bottomLeft.dy - topLeft.dy;
    if (span == 0) return topLeft.dx;
    final t = ((y - topLeft.dy) / span).clamp(0.0, 1.0).toDouble();
    return topLeft.dx + (bottomLeft.dx - topLeft.dx) * t;
  }

  /// 섹션 위에서 [offset](시안 값, 세로 비율 적용) 높이의 행 자리. 왼쪽은 행 아래 높이의 사선에서 24, 오른쪽은 섹션
  /// 오른쪽에서 22(시안 행 · 버튼 공통).
  Rect row(double offset, double height) {
    final y = top + offset * scale;
    final bottom = y + height * scale;
    final left = leftEdge(bottom) + StatisticsMetrics.evidenceButtonEdgeGap;
    return Rect.fromLTRB(
      left,
      y,
      math.max(left, right - StatisticsMetrics.evidenceButtonRight),
      bottom,
    );
  }
}

/// 아주 좁은 창에서 행 내용을 배치하는 최소 폭(초상 · 이름 · Lv · 칩). 더 좁으면 오른쪽을 자른다(넘침 예외 대신,
/// 통계 왼쪽 섹션 행과 같은 규칙).
const _rowContentMinWidth = 240.0;

class StatisticsMinWidth extends StatelessWidget {
  const StatisticsMinWidth({
    super.key,
    required this.minWidth,
    required this.child,
  });

  final double minWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!constraints.maxWidth.isFinite || constraints.maxWidth >= minWidth) {
        return child;
      }
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: minWidth,
          maxWidth: minWidth,
          child: child,
        ),
      );
    },
  );
}

const _mutedStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  height: 1.2,
  color: AppColors.textMuted,
);

/// 근거 패널 머리(제목 자리 · [PanelTitle] + 분홍 인원 칩)와 부제를 뺀 나머지 자리: 행 · 모두 보기 · 요약.
List<Widget> statisticsGrowthEvidenceChildren({
  required StatisticsEvidenceFrame frame,
  required StatisticsGrowthEvidenceContent content,
  required bool expanded,
  required VoidCallback? onExpand,
}) {
  final scale = frame.scale;
  final students = content.students;
  final visible = StatisticsMetrics.evidenceVisibleRows;
  final children = <Widget>[];
  if (expanded && students.length > visible) {
    children.add(
      statisticsEvidenceList(
        key: ValueKey('statistics-evidence-list-${content.title}'),
        frame: frame,
        top: StatisticsMetrics.evidenceRowTop,
        bottom: StatisticsMetrics.evidenceListBottom,
        itemCount: students.length,
        rowKey: (index) =>
            ValueKey('statistics-evidence-row-${students[index].studentId}'),
        itemBuilder: (index) => StatisticsEvidenceStudentRow(
          student: students[index],
          chip: content.chipOf(students[index]),
        ),
      ),
    );
  } else {
    for (final (index, student) in students.take(visible).indexed) {
      children.add(
        Positioned.fromRect(
          rect: frame.row(
            StatisticsMetrics.evidenceRowTop +
                StatisticsMetrics.evidenceRowPitch * index,
            StatisticsMetrics.evidenceRowHeight,
          ),
          child: SectionScaledBox(
            scale: scale,
            child: StatisticsEvidenceStudentRow(
              key: ValueKey('statistics-evidence-row-${student.studentId}'),
              student: student,
              chip: content.chipOf(student),
            ),
          ),
        ),
      );
    }
    final rest = students.length - visible;
    if (rest > 0) {
      children.add(
        Positioned.fromRect(
          rect: frame.row(
            StatisticsMetrics.evidenceRowTop +
                StatisticsMetrics.evidenceRowPitch * visible,
            StatisticsMetrics.evidenceMoreHeight,
          ),
          child: SectionScaledBox(
            scale: scale,
            child: StatisticsEvidenceMoreButton(
              key: const ValueKey('statistics-evidence-more'),
              restText: '나머지 $rest명',
              onPressed: onExpand,
            ),
          ),
        ),
      );
    }
  }
  final titleTop =
      frame.top + StatisticsMetrics.evidenceSummaryTitleTop * scale;
  final titleHeight = StatisticsMetrics.evidenceSummaryTitleHeight * scale;
  final titleLeft =
      frame.leftEdge(titleTop + titleHeight / 2) +
      StatisticsMetrics.evidenceSummaryTitleInset;
  children.add(
    Positioned(
      left: titleLeft,
      top: titleTop,
      width: math.max(
        0.0,
        frame.right - StatisticsMetrics.evidenceTitleRight - titleLeft,
      ),
      height: titleHeight,
      child: SectionScaledBox(
        scale: scale,
        child: Align(
          alignment: Alignment.centerLeft,
          child: TileTitle(
            content.summaryTitle,
            key: const ValueKey('statistics-evidence-summary-title'),
          ),
        ),
      ),
    ),
  );
  for (final (index, (key, label, value)) in content.summary.indexed) {
    children.add(
      Positioned.fromRect(
        rect: frame.row(
          StatisticsMetrics.evidenceSummaryTop +
              StatisticsMetrics.evidenceSummaryPitch * index,
          StatisticsMetrics.evidenceSummaryHeight,
        ),
        child: SectionScaledBox(
          scale: scale,
          child: _SummaryRow(
            rowKey: 'statistics-evidence-summary-$key',
            label: label,
            value: value,
          ),
        ),
      ),
    );
  }
  return children;
}

/// 근거 행 모양: 왼쪽 변 80° · 오른쪽 변 수직(시안 `.row` 근거 행), 모서리 Q 곡선 r8.
Path statisticsEvidenceRowPath(Size size, {double radius = AppRadii.row}) =>
    diagonalRoundedPolygon(
      [
        Offset(diagonalCutDepth(size.height), 0),
        Offset(size.width, 0),
        Offset(size.width, size.height),
        Offset(0, size.height),
      ],
      radius: radius,
      corner: DiagonalCornerStyle.quadratic,
    );

class StatisticsEvidenceRowPainter extends CustomPainter {
  const StatisticsEvidenceRowPainter(this.look);

  final DiagonalRowLook look;

  @override
  void paint(Canvas canvas, Size size) {
    final path = statisticsEvidenceRowPath(size);
    final fill = look.fill;
    if (fill != null) canvas.drawPath(path, Paint()..color = fill);
    final border = look.border;
    if (border != null && look.borderWidth > 0) {
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = look.borderWidth
          ..color = border,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(StatisticsEvidenceRowPainter oldDelegate) =>
      oldDelegate.look != look;
}

/// 근거 학생 행(52 높이): 초상 44×36 · 이름 13px · "Lv.n" 12px · 칩. 간격 10, 안쪽 사선 깊이 + 12 · 14.
/// 성장 근거(FE7-b)는 학생 육성 값에서, 재화 근거(FE7-c)는 id · 이름 · 레벨로 만든다([StatisticsEvidenceStudentRow.plain]).
class StatisticsEvidenceStudentRow extends StatelessWidget {
  StatisticsEvidenceStudentRow({
    super.key,
    required StatisticsStudentGrowth student,
    required this.chip,
  }) : studentId = student.studentId,
       displayName = student.displayName,
       level = student.level;

  const StatisticsEvidenceStudentRow.plain({
    super.key,
    required this.studentId,
    required this.displayName,
    required this.level,
    this.chip,
  });

  static const portraitSize = Size(44, 36);

  final String studentId;
  final String displayName;

  /// 레벨. 모르면(보유하지 않았거나 값 없음) null → "Lv.—".
  final int? level;
  final (String, AppTone)? chip;

  @override
  Widget build(BuildContext context) {
    final chip = this.chip;
    final level = this.level;
    return CustomPaint(
      painter: StatisticsEvidenceRowPainter(DiagonalRowLook.of(DiagonalRowVariant.row)),
      child: Padding(
        padding: EdgeInsets.only(
          left: diagonalCutDepth(StatisticsMetrics.evidenceRowHeight) + 12,
          right: 14,
        ),
        child: StatisticsMinWidth(
          minWidth: _rowContentMinWidth,
          child: Row(
            children: [
              PortraitStrip(
                studentIds: [studentId],
                maxVisible: 1,
                portraitSize: portraitSize,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: AppType.bodySize,
                    height: 1.2,
                    fontWeight: AppType.semiBold,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('Lv.${level ?? '—'}', maxLines: 1, style: _mutedStyle),
              if (chip != null) ...[
                const SizedBox(width: 10),
                BaChip(label: chip.$1, tone: chip.$2),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "나머지 n명 모두 보기"(시안 `.plain` 30 높이). 왼쪽은 [restText](회색), 오른쪽은 "모두 보기"다. 재화 근거
/// "외 n종 · 외 n명"도 같은 버튼이다(FE7-d).
class StatisticsEvidenceMoreButton extends StatelessWidget {
  const StatisticsEvidenceMoreButton({
    super.key,
    required this.restText,
    required this.onPressed,
  });

  final String restText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => KitPressable(
    onPressed: onPressed,
    semanticLabel: '$restText 모두 보기',
    builder: (context, state) => Padding(
      padding: EdgeInsets.only(
        left: diagonalCutDepth(StatisticsMetrics.evidenceMoreHeight) + 12,
        right: 14,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              restText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mutedStyle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '모두 보기',
            maxLines: 1,
            style: _mutedStyle.copyWith(
              color: state.hovered ? AppColors.text : AppTones.info.foreground,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 요약 한 행(시안 `.plain` 48 높이, 글자 20px 회색 + 값 20px 경기천년제목).
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.rowKey,
    required this.label,
    required this.value,
  });

  final String rowKey;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey(rowKey),
    padding: EdgeInsets.only(
      left: diagonalCutDepth(StatisticsMetrics.evidenceSummaryHeight) + 12,
      right: 14,
    ),
    child: StatisticsMinWidth(
      minWidth: _rowContentMinWidth,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mutedStyle.copyWith(fontSize: AppType.headlineSize),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            key: ValueKey('$rowKey-value'),
            maxLines: 1,
            style: kitDisplayStyle(AppType.headlineSize),
          ),
        ],
      ),
    ),
  );
}

/// 근거 섹션 위에서 [top] ~ [bottom](시안 값, 세로 비율 적용) 자리에 모두 펼친 근거 목록을 놓는다. 행은
/// [itemBuilder](시안 크기, 근거 행 높이 · 피치)이고 키는 [rowKey]다.
Widget statisticsEvidenceList({
  required Key key,
  required StatisticsEvidenceFrame frame,
  required double top,
  required double bottom,
  required int itemCount,
  required Key Function(int index) rowKey,
  required Widget Function(int index) itemBuilder,
}) {
  final scale = frame.scale;
  final listTop = frame.top + top * scale;
  final listBottom = frame.top + bottom * scale;
  final left = frame.leftEdge(listBottom);
  return Positioned(
    left: left,
    top: listTop,
    width: math.max(0.0, frame.right - left),
    height: math.max(0.0, listBottom - listTop),
    child: _EvidenceList(
      key: key,
      frame: frame,
      origin: Offset(left, listTop),
      itemCount: itemCount,
      rowKey: rowKey,
      itemBuilder: itemBuilder,
    ),
  );
}

/// 모두 펼친 근거 목록. 행 왼쪽은 지금 화면 높이의 섹션 사선을 따라가고 오른쪽은 고정이다(시안 근거 행과 같은 규칙).
/// 공용 스크롤바(섹션 오른쪽 변이 수직이라 트랙도 수직) · 포그를 쓴다.
class _EvidenceList extends StatefulWidget {
  const _EvidenceList({
    super.key,
    required this.frame,
    required this.origin,
    required this.itemCount,
    required this.rowKey,
    required this.itemBuilder,
  });

  final StatisticsEvidenceFrame frame;

  /// 이 목록 자리의 왼쪽 위(섹션 좌표).
  final Offset origin;
  final int itemCount;
  final Key Function(int index) rowKey;
  final Widget Function(int index) itemBuilder;

  @override
  State<_EvidenceList> createState() => _EvidenceListState();
}

/// 펼친 목록의 스크롤바 자리(행 오른쪽과 섹션 오른쪽 끝 사이).
const _listScrollbarReserve = 14.0;

Offset _verticalTrackPoint(Size size, double y, {double trackInset = 10}) =>
    Offset(
      size.width -
          StatisticsMetrics.evidenceButtonRight +
          _listScrollbarReserve / 2,
      y
          .clamp(trackInset, math.max(trackInset, size.height - trackInset))
          .toDouble(),
    );

class _EvidenceListState extends State<_EvidenceList> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final frame = widget.frame;
      final scale = frame.scale;
      final count = widget.itemCount;
      final rowHeight = StatisticsMetrics.evidenceRowHeight * scale;
      final pitch = StatisticsMetrics.evidenceRowPitch * scale;
      final contentHeight = count == 0 ? 0.0 : pitch * (count - 1) + rowHeight;
      final right =
          frame.right -
          StatisticsMetrics.evidenceButtonRight -
          _listScrollbarReserve -
          widget.origin.dx;
      return DiagonalScrollbar(
        keyPrefix: 'statistics-evidence',
        controller: _controller,
        contentExtent: contentHeight,
        fog: ScrollFogSpec.statistics,
        trackPoint: _verticalTrackPoint,
        child: SingleChildScrollView(
          key: const ValueKey('statistics-evidence-scroll'),
          controller: _controller,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final scroll = _controller.hasClients ? _controller.offset : 0.0;
              final rows = <Widget>[];
              for (var index = 0; index < count; index++) {
                final top = pitch * index;
                final screenBottom =
                    widget.origin.dy + top - scroll + rowHeight;
                final left =
                    frame.leftEdge(screenBottom) +
                    StatisticsMetrics.evidenceButtonEdgeGap -
                    widget.origin.dx;
                rows.add(
                  Positioned(
                    key: widget.rowKey(index),
                    left: left,
                    top: top,
                    width: math.max(0.0, right - left),
                    height: rowHeight,
                    child: SectionScaledBox(
                      scale: scale,
                      child: widget.itemBuilder(index),
                    ),
                  ),
                );
              }
              return SizedBox(
                width: constraints.maxWidth,
                height: contentHeight,
                child: Stack(clipBehavior: Clip.none, children: rows),
              );
            },
          ),
        ),
      );
    },
  );
}
