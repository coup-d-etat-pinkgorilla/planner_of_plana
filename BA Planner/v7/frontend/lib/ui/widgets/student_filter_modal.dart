// 필터 모달 화면 (FE3-d2, 시안 Student-Filter, W-Filter-Widgets, B §2, FD-052~059·FD-074·FD-104).
//
// 학생 탭·계획 만들기 1단계(FE4-b)·통계(FE7-e)가 함께 쓰는 모달 내용이다. 값은 [StudentFilterSelection] 초안이고,
// 상태 객체([StudentFilterController])는 쓰는 쪽이 주입한다(FD-104). 이 위젯은 초안을 그리고 바뀐 초안을
// [StudentFilterModal.onChanged]로 돌려준다. 바깥 틀(스크림 .8 + blur 2, 포커스·Esc)은 [BaModal]이다.
//
// 시안 값(기준 viewport 2560×1392, 페이지 좌표):
// - 머리 바 `.sw` (453.8, 206, 1876.2×92) r14 사선 + 안쪽 띠 (+32.4, +14, 1807.3×64) r8. 띠 안 좌우 = 띠 컷 + 10.
//   7×26 핑크 사선 막대 · "필터" 경기천년제목 22 · 결과 수 26 w800 + "/ N명" 13 muted · 1×30 구분선(좌우 8) ·
//   적용 칩(`.chip.pk` + ×, 한 줄, 넘치면 잘림) · [프리셋 칩 숨김, FD-074 (b)] · "초기화" tonal h40 pad 14 ·
//   "적용" tonal pri h40 pad 18 · 닫기 × 18. 사이 10.
// - 속성 패널 `.sw` (285.9, 320, 984×930), 성장 범위 패널 (1127.9, 320, 1182×930). r14 사선, 표면 rgba(29,42,58,.97)
//   + lifted shadow 4층. 두 패널은 아래 변에서 22 떨어져 평행하다.
// - 패널 행: 왼쪽 = 패널 왼쪽 80° 변의 행 밑변 높이 + 26, 오른쪽 = 오른쪽 80° 변의 행 윗변 높이 − 30(속성)/34(성장).
//   제목 행만 왼쪽 20(속성)/24(성장), 오른쪽 30. 행 안 좌우 = 행 컷 + 10. 행 모양 r8 사선.
//   속성: 제목 30 → 14 → [소제목 24 → 4 → 칩 줄(한 줄 34, 여러 줄 30·줄 + 8·(줄−1) + 8) → 14]…, 칩 사이 10,
//   줄 사이 8.
//   성장: 제목 30 → 16 → [소제목 22 → 6 → `.srow` 48 (사이 10)…] 그룹 사이 10 → 14 → 심상개화 44.
//   `.srow` 기본 rgba(16,24,35,.5) + 2px rgba(113,199,244,.16)(보이는 1px), 좁힘 rgba(52,36,58,.85) + 4px #f2b3ef.
// - 소제목 `.ihdr`: 5×5 r1 #71c7f4 점 + 4 + 경기천년제목 10.5 w800, 학교 줄만 값 수(11px muted). 칩 옆 학생 수는
//   학교 줄에만(오케스트레이터 15:51 결정 2).
// - "필터 · n" 배지: 모달이 열려 있는 동안 (18, 226), padding 8 12, r8, #0d151f + 1.5px 핑크 링, 깔때기 15 +
//   12px 굵게 #f7c9f4(FD-058). n = 초안의 걸린 조건 수 = 머리 칩 수(15:51 결정 1).
// 다른 창 크기: 가로 위치·폭은 viewport 비율, 머리 바·행 높이는 고정, 패널은 머리 바 아래 22부터 1250/1392 높이까지.
// 패널 내용이 높이를 넘으면 패널 안에서 세로로 스크롤한다(행은 80° 변을 따라 민다, 공용 스크롤바·포그).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_row.dart';
import '../kit/diagonal_scrollbar.dart';
import '../kit/kit_glyph.dart';
import '../kit/kit_pressable.dart';
import '../kit/range_controls.dart';
import '../kit/skew_controls.dart';
import '../models/student_filter_selection.dart';
import 'section_surface.dart';
import 'student_section_layout.dart'
    show studentAttackTypeColor, studentDefenseTypeColor;

/// 시안 기준 viewport.
const studentFilterModalBaseSize = Size(2560, 1392);

/// 머리 바 높이.
const studentFilterHeaderHeight = 92.0;

/// 머리 바와 패널 사이.
const studentFilterPanelGap = 22.0;

/// 패널 표면(시안 rgba(29,42,58,.97)).
final studentFilterPanelFill = AppColors.surface.withValues(alpha: 0.97);

/// 칩 옆 학생 수를 보이는 그룹(15:51 결정 2).
const studentFilterCountedGroups = {'school'};

/// 모달 배치(오버레이 크기 [size] 기준).
@immutable
class StudentFilterModalLayout {
  const StudentFilterModalLayout({
    required this.header,
    required this.attributes,
    required this.growth,
    required this.badge,
  });

  /// 시안 값을 [size]에 놓는다. 가로는 비율, 머리 바 높이는 고정이다.
  factory StudentFilterModalLayout.of(Size size) {
    final sx = size.width / studentFilterModalBaseSize.width;
    final sy = size.height / studentFilterModalBaseSize.height;
    final header = Rect.fromLTWH(
      453.8 * sx,
      206 * sy,
      1876.2 * sx,
      studentFilterHeaderHeight,
    );
    final top = header.bottom + studentFilterPanelGap;
    final bottom = math.max(top + 160, 1250 * sy);
    final height = bottom - top;
    final cut = diagonalCutDepth(height);
    // 두 패널은 아래 변 사이가 22인 평행사변형이다(윗변 길이 820 / 1018).
    final leftBottomLeft = 285.9 * sx;
    final leftTopLength = 820 * sx;
    final rightBottomLeft = leftBottomLeft + leftTopLength + 22 * sx;
    final rightTopLength = 1018 * sx;
    return StudentFilterModalLayout(
      header: header,
      attributes: Rect.fromLTWH(
        leftBottomLeft,
        top,
        leftTopLength + cut,
        height,
      ),
      growth: Rect.fromLTWH(rightBottomLeft, top, rightTopLength + cut, height),
      badge: Offset(18 * sx, 226 * sy),
    );
  }

  final Rect header;
  final Rect attributes;
  final Rect growth;

  /// "필터 · n" 배지 왼쪽 위.
  final Offset badge;
}

/// 패널 안 행 하나의 가로 범위(패널 로컬 좌표). [top]·[bottom]은 화면에 보이는 위치다.
({double left, double right}) studentFilterRowSpan({
  required Size panel,
  required double top,
  required double bottom,
  required double insetLeft,
  required double insetRight,
}) {
  final railLeft = (panel.height - bottom) / diagonalTan80;
  final railRight = panel.width - top / diagonalTan80;
  return (left: railLeft + insetLeft, right: railRight - insetRight);
}

/// 토글 칩 폭(시안 h30 padding 13, 간격 7, 개수 10.5px, 타입 막대 8).
double studentFilterToggleChipWidth(
  String label, {
  required bool selected,
  required TextScaler textScaler,
  int? count,
  bool typeBar = false,
}) {
  double measure(String text, double size, FontWeight weight) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: size,
          height: 1.2,
          fontWeight: weight,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width.ceilToDouble() + 1;
  }

  var width =
      26 +
      measure(
        label,
        AppType.popoverBodySize,
        selected ? AppType.bold : AppType.medium,
      );
  if (count != null) {
    width += 7 + measure('$count', AppType.microPlusSize, AppType.regular);
  }
  if (typeBar) width += 8 + 7;
  return width;
}

/// 칩 [widths]를 폭 [available]에 사이 10으로 채울 때 줄 수(최소 1).
int studentFilterChipLines(List<double> widths, double available) {
  if (widths.isEmpty) return 1;
  var lines = 1;
  var x = 0.0;
  for (final width in widths) {
    if (x > 0 && x + 10 + width > available) {
      lines += 1;
      x = width;
    } else {
      x += (x > 0 ? 10 : 0) + width;
    }
  }
  return lines;
}

/// 칩 줄 높이. 시안 값은 한 줄 34, 여러 줄은 `padding:4px 0` 포함 30·줄 + 8·(줄 − 1) + 8(학교 두 줄 76)이다.
double studentFilterChipRowHeight(int lines) =>
    lines <= 1 ? 34 : 30.0 * lines + 8 * (lines - 1) + 8;

/// 필터 모달 내용(오버레이 전체 크기). [BaModal.builder]가 돌려준다.
class StudentFilterModal extends StatelessWidget {
  const StudentFilterModal({
    super.key,
    required this.selection,
    required this.onChanged,
    required this.candidates,
    required this.groups,
    required this.totalCount,
    required this.onApply,
    required this.onReset,
    required this.onClose,
    this.countedGroups = studentFilterCountedGroups,
    this.showCountBadge = true,
    this.title = '필터',
    this.caption,
    this.headerAction,
  });

  /// 초안.
  final StudentFilterSelection selection;
  final ValueChanged<StudentFilterSelection> onChanged;

  /// 조건을 거는 학생 전부(칩 개수·미리보기 결과 수).
  final List<StudentFilterCandidate> candidates;

  /// 속성 그룹(FD-104: 쓰는 쪽이 넘긴다. 계획 1단계는 계획 그룹을 더한다).
  final List<StudentFilterGroup> groups;

  /// 머리 "/ N명"의 N.
  final int totalCount;
  final VoidCallback onApply;
  final VoidCallback onReset;
  final VoidCallback onClose;

  /// 칩 옆 학생 수를 보이는 그룹 키.
  final Set<String> countedGroups;

  /// "필터 · n" 배지를 그린다. 배지 자리 (18, 226)는 학생 탭 S1 필터 버튼 자리라서, 필터 버튼이 다른 곳에 있는
  /// 화면(계획 만들기 1단계, 버튼은 B 오른쪽 위)은 끈다(FE4-c 확인: 시안 Flow-1-Students-Filter에 떠 있는 배지 없음).
  final bool showCountBadge;

  /// 머리 제목(통계는 "통계 필터", 시안 Stats-Filter-Open).
  final String title;

  /// 제목 옆 작은 보조 문구(두 줄까지, 11.5px muted). 없으면 제목 바로 뒤가 결과 수다.
  final String? caption;

  /// 적용 칩과 "초기화" 사이 버튼(통계 "학생 탭 필터 불러오기"). 없으면 그리지 않는다.
  final Widget? headerAction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final layout = StudentFilterModalLayout.of(constraints.biggest);
      final chips = selection.chips(groups);
      return SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fromRect(
              rect: layout.header,
              child: _FilterHeader(
                key: const ValueKey('student-filter-modal-header'),
                title: title,
                caption: caption,
                action: headerAction,
                chips: chips,
                matching: selection.countMatching(candidates, groups),
                totalCount: totalCount,
                onRemove: (chip) => onChanged(selection.without(chip)),
                onReset: onReset,
                onApply: onApply,
                onClose: onClose,
              ),
            ),
            Positioned.fromRect(
              rect: layout.attributes,
              child: _FilterPanel(
                key: const ValueKey('student-filter-attributes'),
                keyPrefix: 'student-filter-attributes',
                rows: _attributeRows(context),
              ),
            ),
            Positioned.fromRect(
              rect: layout.growth,
              child: _FilterPanel(
                key: const ValueKey('student-filter-growth'),
                keyPrefix: 'student-filter-growth',
                rows: _growthRows(),
              ),
            ),
            if (showCountBadge)
              Positioned(
                left: layout.badge.dx,
                top: layout.badge.dy,
                child: StudentFilterCountBadge(
                  key: const ValueKey('student-filter-modal-badge'),
                  count: chips.length,
                ),
              ),
          ],
        ),
      );
    },
  );

  List<_PanelRow> _attributeRows(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final rows = <_PanelRow>[
      _PanelRow.fixed(
        key: 'title',
        height: 30,
        gapAfter: 14,
        insetLeft: 20,
        insetRight: 30,
        builder: (_) => const _PanelTitle(
          title: '속성',
          caption: '같은 줄은 “또는”, 줄끼리는 “그리고”',
        ),
      ),
    ];
    void addGroup({
      required String key,
      required String label,
      String? note,
      required List<_ChipSpec> chips,
    }) {
      rows.add(
        _PanelRow.fixed(
          key: '$key-header',
          height: 24,
          gapAfter: 4,
          insetLeft: 26,
          insetRight: 30,
          builder: (_) => _GroupHeader(label: label, note: note),
        ),
      );
      final widths = [
        for (final chip in chips)
          studentFilterToggleChipWidth(
            chip.label,
            selected: chip.selected,
            textScaler: scaler,
            count: chip.count,
            typeBar: chip.typeColor != null,
          ),
      ];
      rows.add(
        _PanelRow.chips(
          key: '$key-chips',
          gapAfter: 14,
          insetLeft: 26,
          insetRight: 30,
          lines: (width) => studentFilterChipLines(widths, width),
          builder: (_) => Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final chip in chips)
                chip.typeColor == null
                    ? SkewToggleChip(
                        key: ValueKey('student-filter-chip-$key-${chip.value}'),
                        label: chip.label,
                        count: chip.count,
                        selected: chip.selected,
                        onChanged: (_) =>
                            onChanged(selection.toggle(key, chip.value)),
                      )
                    : TypeChip(
                        key: ValueKey('student-filter-chip-$key-${chip.value}'),
                        label: chip.label,
                        color: chip.typeColor!,
                        count: chip.count,
                        selected: chip.selected,
                        onChanged: (_) =>
                            onChanged(selection.toggle(key, chip.value)),
                      ),
            ],
          ),
        ),
      );
    }

    for (final group in groups) {
      final values = group.valuesIn(candidates);
      final counted = countedGroups.contains(group.key);
      addGroup(
        key: group.key,
        label: group.label,
        note: counted ? '${values.length}' : null,
        chips: [
          for (final value in values)
            _ChipSpec(
              value: value,
              label: studentFilterChipLabel(group.key, value),
              selected: selection.isSelected(group.key, value),
              count: counted
                  ? selection.chipCount(candidates, groups, group.key, value)
                  : null,
              typeColor: switch (group.key) {
                'attack_type' when value != 'Chemical' => studentAttackTypeColor(
                  value,
                ),
                'defense_type' => studentDefenseTypeColor(value),
                _ => null,
              },
            ),
        ],
      );
    }
    addGroup(
      key: studentOwnershipGroupKey,
      label: '보유 · 서버',
      chips: [
        for (final value in const [
          studentOwnedValue,
          studentUnownedValue,
          studentExcludeJpOnlyValue,
        ])
          _ChipSpec(
            value: value,
            label: studentOwnershipChipLabels[value]!,
            selected: selection.isSelected(studentOwnershipGroupKey, value),
          ),
      ],
    );
    return rows;
  }

  List<_PanelRow> _growthRows() {
    final rows = <_PanelRow>[
      _PanelRow.fixed(
        key: 'title',
        height: 30,
        gapAfter: 16,
        insetLeft: 24,
        insetRight: 30,
        builder: (_) => _PanelTitle(
          title: '성장 범위',
          caption: '한 줄에서 최소 ~ 최대 · 좁힌 항목만 분홍',
          trailing: _ResetRangesChip(
            onPressed: selection.ranges.isEmpty
                ? null
                : () => onChanged(selection.clearedRanges()),
          ),
        ),
      ),
    ];
    for (final group in studentGrowthRangeGroups) {
      rows.add(
        _PanelRow.fixed(
          key: '${group.key}-header',
          height: 22,
          gapAfter: 6,
          insetLeft: 26,
          insetRight: 34,
          builder: (_) => _GroupHeader(label: group.label),
        ),
      );
      for (var index = 0; index < group.rows.length; index++) {
        final row = group.rows[index];
        final (low, high) = selection.ranges.bounds(row);
        final narrowed = selection.ranges.isNarrowed(row.key);
        rows.add(
          _PanelRow.fixed(
            key: 'range-${row.key}',
            height: 48,
            gapAfter: 10,
            insetLeft: 26,
            insetRight: 34,
            surface: narrowed ? _RowSurface.selected : _RowSurface.idle,
            builder: (_) => row.style == StudentRangeValueStyle.star
                ? StarRangeBar(
                    key: ValueKey('student-filter-range-${row.key}'),
                    low: low,
                    high: high,
                    label: row.label,
                    caption: row.caption,
                    framed: false,
                    height: 48,
                    onChanged: (lo, hi) =>
                        onChanged(selection.withRange(row, lo, hi)),
                  )
                : RangeSliderRow(
                    key: ValueKey('student-filter-range-${row.key}'),
                    label: row.label,
                    caption: row.caption,
                    min: row.min,
                    max: row.max,
                    low: low,
                    high: high,
                    formatValue: row.formatValue,
                    semanticValue: row.formatSpokenValue,
                    framed: false,
                    height: 48,
                    onChanged: (lo, hi) =>
                        onChanged(selection.withRange(row, lo, hi)),
                  ),
          ),
        );
      }
    }
    // 마지막 그룹 뒤 간격은 14(심상개화 앞).
    rows.last = rows.last.withGapAfter(14);
    rows.add(
      _PanelRow.fixed(
        key: 'potential',
        height: 44,
        gapAfter: 0,
        insetLeft: 26,
        insetRight: 34,
        builder: (_) => const _PotentialRow(),
      ),
    );
    return rows;
  }
}

class _ChipSpec {
  const _ChipSpec({
    required this.value,
    required this.label,
    required this.selected,
    this.count,
    this.typeColor,
  });

  final String value;
  final String label;
  final bool selected;
  final int? count;
  final Color? typeColor;
}

// ---------------------------------------------------------------------------
// 머리 바

/// "필터 · n" 배지(FD-058). 모달이 열려 있는 동안 시안 위치에 둔다.
class StudentFilterCountBadge extends StatelessWidget {
  const StudentFilterCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '필터 · $count',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: AppColors.popover,
          borderRadius: BorderRadius.all(Radius.circular(8)),
          boxShadow: [BoxShadow(color: AppColors.accent, spreadRadius: 1.5)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 15,
              height: 15,
              child: CustomPaint(
                painter: KitGlyphPainter(
                  glyph: KitGlyph.filter,
                  color: AppColors.accentText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '필터 · $count',
              style: const TextStyle(
                fontFamily: AppFonts.body,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: AppType.bodySmallSize,
                height: 1.2,
                fontWeight: AppType.bold,
                color: AppColors.accentText,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FilterHeader extends StatelessWidget {
  const _FilterHeader({
    super.key,
    required this.title,
    required this.caption,
    required this.action,
    required this.chips,
    required this.matching,
    required this.totalCount,
    required this.onRemove,
    required this.onReset,
    required this.onApply,
    required this.onClose,
  });

  final String title;
  final String? caption;
  final Widget? action;
  final List<StudentFilterChipItem> chips;
  final int matching;
  final int totalCount;
  final ValueChanged<StudentFilterChipItem> onRemove;
  final VoidCallback onReset;
  final VoidCallback onApply;
  final VoidCallback onClose;

  /// 안쪽 띠 위치(머리 바 기준).
  static const stripInset = Offset(32.4, 14);
  static const stripRightInset = 36.5;
  static const stripHeight = 64.0;

  /// 띠 안쪽 폭이 이보다 좁으면 보조 문구를 빼고 추가 버튼을 줄인다(통계 필터 머리, 1280×720 등 — 학생 탭 머리는 둘 다 없어
  /// 바뀌지 않는다).
  static const compactWidth = 1000.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final strip = Rect.fromLTWH(
        stripInset.dx,
        stripInset.dy,
        math.max(0, size.width - stripInset.dx - stripRightInset),
        stripHeight,
      );
      final stripPad = diagonalCutDepth(stripHeight) + 10;
      final compact = strip.width - 2 * stripPad < compactWidth;
      return SectionSurface(
        clipper: const _ParallelogramClipper(radius: 14),
        fill: studentFilterPanelFill,
        child: Stack(
          children: [
            Positioned.fromRect(
              rect: strip,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: stripPad),
                child: Row(
                  children: [
                    Transform(
                      transform: Matrix4.skewX(-10 * math.pi / 180),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 7,
                        height: 26,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.all(Radius.circular(2)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: AppFonts.display,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: 22,
                        height: 1.2,
                        fontWeight: AppType.medium,
                        color: AppColors.text,
                      ),
                    ),
                    // 시안 Stats-Filter-Open: 제목 · 보조 문구 사이 14, 보조 문구 · 결과 수 사이 20.
                    if (caption case final caption? when !compact) ...[
                      const SizedBox(width: 14),
                      Text(
                        caption,
                        key: const ValueKey('student-filter-modal-caption'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.body,
                          fontFamilyFallback: AppFonts.fallback,
                          fontSize: 11.5,
                          height: 1.35,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(width: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$matching',
                          key: const ValueKey('student-filter-modal-count'),
                          style: const TextStyle(
                            fontFamily: AppFonts.display,
                            fontFamilyFallback: AppFonts.fallback,
                            fontSize: 26,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '/ $totalCount명',
                          style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontFamilyFallback: AppFonts.fallback,
                            fontSize: AppType.bodySize,
                            height: 1.2,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 18),
                    SizedBox(
                      width: 1,
                      height: 30,
                      child: ColoredBox(
                        color: AppColors.textMuted.withValues(alpha: 0.25),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: ClipRect(
                        child: SingleChildScrollView(
                          key: const ValueKey('student-filter-modal-chips'),
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Row(
                            children: [
                              for (var index = 0; index < chips.length; index++) ...[
                                if (index > 0) const SizedBox(width: 6),
                                BaChip(
                                  key: ValueKey(
                                    'student-filter-modal-chip-${chips[index].id}',
                                  ),
                                  label: chips[index].label,
                                  tone: AppTones.pink,
                                  onRemove: () => onRemove(chips[index]),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (action case final action?) ...[
                      const SizedBox(width: 10),
                      if (compact)
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: action,
                          ),
                        )
                      else
                        action,
                    ],
                    // 필터 프리셋 칩은 숨긴다(FD-074 (b): 영속 저장 범위 밖).
                    const SizedBox(width: 10),
                    TonalButton(
                      key: const ValueKey('student-filter-reset'),
                      label: '초기화',
                      icon: Icons.restart_alt_rounded,
                      horizontalPadding: 14,
                      onPressed: onReset,
                    ),
                    const SizedBox(width: 10),
                    TonalButton(
                      key: const ValueKey('student-filter-apply'),
                      label: '적용',
                      icon: Icons.check_rounded,
                      variant: TonalButtonVariant.primary,
                      horizontalPadding: 18,
                      onPressed: onApply,
                    ),
                    const SizedBox(width: 10),
                    KitPressable(
                      key: const ValueKey('student-filter-close'),
                      onPressed: onClose,
                      semanticLabel: '닫기',
                      builder: (context, state) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CustomPaint(
                            painter: KitGlyphPainter(
                              glyph: KitGlyph.close,
                              color: state.hovered || state.focused
                                  ? AppColors.text
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// 패널

enum _RowSurface { none, idle, selected }

/// 패널 행 하나. 높이는 고정이거나(칩 줄은) 폭에 따라 정해진다.
class _PanelRow {
  const _PanelRow._({
    required this.key,
    required this.gapAfter,
    required this.insetLeft,
    required this.insetRight,
    required this.builder,
    this.height,
    this.lines,
    this.surface = _RowSurface.none,
  });

  factory _PanelRow.fixed({
    required String key,
    required double height,
    required double gapAfter,
    required double insetLeft,
    required double insetRight,
    required WidgetBuilder builder,
    _RowSurface surface = _RowSurface.none,
  }) => _PanelRow._(
    key: key,
    height: height,
    gapAfter: gapAfter,
    insetLeft: insetLeft,
    insetRight: insetRight,
    builder: builder,
    surface: surface,
  );

  factory _PanelRow.chips({
    required String key,
    required double gapAfter,
    required double insetLeft,
    required double insetRight,
    required int Function(double innerWidth) lines,
    required WidgetBuilder builder,
  }) => _PanelRow._(
    key: key,
    gapAfter: gapAfter,
    insetLeft: insetLeft,
    insetRight: insetRight,
    builder: builder,
    lines: lines,
  );

  final String key;
  final double? height;
  final int Function(double innerWidth)? lines;
  final double gapAfter;
  final double insetLeft;
  final double insetRight;
  final WidgetBuilder builder;
  final _RowSurface surface;

  _PanelRow withGapAfter(double value) => _PanelRow._(
    key: key,
    height: height,
    lines: lines,
    gapAfter: value,
    insetLeft: insetLeft,
    insetRight: insetRight,
    builder: builder,
    surface: surface,
  );
}

/// 패널 안 행 배치 결과(콘텐츠 좌표 top).
@immutable
class StudentFilterPanelRowSlot {
  const StudentFilterPanelRowSlot({
    required this.key,
    required this.top,
    required this.height,
    required this.left,
    required this.right,
  });

  final String key;
  final double top;
  final double height;
  final double left;
  final double right;

  double get width => right - left;
}

/// 패널 첫 행 위치.
const studentFilterPanelContentTop = 18.0;

List<StudentFilterPanelRowSlot> _layoutRows(
  List<_PanelRow> rows,
  Size panel,
  double scroll,
) {
  final slots = <StudentFilterPanelRowSlot>[];
  var top = studentFilterPanelContentTop;
  for (final row in rows) {
    var height = row.height ?? studentFilterChipRowHeight(1);
    final lines = row.lines;
    if (lines != null) {
      // 칩 줄: 폭에 따라 줄 수가 바뀌고, 높이가 바뀌면 폭도 조금 바뀌므로 두 번 맞춘다.
      for (var pass = 0; pass < 2; pass++) {
        final span = studentFilterRowSpan(
          panel: panel,
          top: top - scroll,
          bottom: top + height - scroll,
          insetLeft: row.insetLeft,
          insetRight: row.insetRight,
        );
        final inner = span.right - span.left - 2 * (diagonalCutDepth(height) + 10);
        height = studentFilterChipRowHeight(lines(inner));
      }
    }
    final span = studentFilterRowSpan(
      panel: panel,
      top: top - scroll,
      bottom: top + height - scroll,
      insetLeft: row.insetLeft,
      insetRight: row.insetRight,
    );
    slots.add(
      StudentFilterPanelRowSlot(
        key: row.key,
        top: top,
        height: height,
        left: span.left,
        right: span.right,
      ),
    );
    top += height + row.gapAfter;
  }
  return slots;
}

class _FilterPanel extends StatefulWidget {
  const _FilterPanel({super.key, required this.keyPrefix, required this.rows});

  final String keyPrefix;
  final List<_PanelRow> rows;

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final panel = constraints.biggest;
      final unscrolled = _layoutRows(widget.rows, panel, 0);
      final contentHeight = unscrolled.isEmpty
          ? panel.height
          : unscrolled.last.top +
                unscrolled.last.height +
                studentFilterPanelContentTop;
      return SectionSurface(
        clipper: const _ParallelogramClipper(radius: 14),
        fill: studentFilterPanelFill,
        child: DiagonalScrollbar(
          keyPrefix: widget.keyPrefix,
          controller: _controller,
          contentExtent: contentHeight,
          child: SingleChildScrollView(
            key: ValueKey('${widget.keyPrefix}-scroll'),
            controller: _controller,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final scroll = _controller.hasClients ? _controller.offset : 0.0;
                final slots = _layoutRows(widget.rows, panel, scroll);
                return SizedBox(
                  width: panel.width,
                  height: math.max(panel.height, contentHeight),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var index = 0; index < slots.length; index++)
                        Positioned(
                          key: ValueKey(
                            '${widget.keyPrefix}-row-${slots[index].key}',
                          ),
                          left: slots[index].left,
                          top: slots[index].top,
                          width: math.max(0, slots[index].width),
                          height: slots[index].height,
                          child: _PanelRowBox(
                            surface: widget.rows[index].surface,
                            height: slots[index].height,
                            child: Builder(builder: widget.rows[index].builder),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

/// 행 상자: r8 사선 모양, [surface]에 따라 `.srow` 바탕·테두리, 안쪽 좌우 = 컷 + 10.
class _PanelRowBox extends StatelessWidget {
  const _PanelRowBox({
    required this.surface,
    required this.height,
    required this.child,
  });

  final _RowSurface surface;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pad = diagonalCutDepth(height) + 10;
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: pad),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
    if (surface == _RowSurface.none) return content;
    final selected = surface == _RowSurface.selected;
    return CustomPaint(
      painter: StudentFilterRowPainter(selected: selected),
      child: content,
    );
  }
}

/// `.srow` 바탕·테두리 painter.
class StudentFilterRowPainter extends CustomPainter {
  const StudentFilterRowPainter({required this.selected});

  final bool selected;

  /// 기본 바탕(시안 인라인 rgba(16,24,35,.5)).
  static const idleFill = Color.fromRGBO(16, 24, 35, 0.5);

  /// 좁힌 행 바탕(`.srow.sel` rgba(52,36,58,.85)).
  static const selectedFill = Color.fromRGBO(52, 36, 58, 0.85);

  /// 기본 테두리(`.srow>.bd path` rgba(113,199,244,.16) 2px).
  static const idleBorder = Color.fromRGBO(113, 199, 244, 0.16);

  @override
  void paint(Canvas canvas, Size size) {
    final path = diagonalRowPath(size, DiagonalRowVariant.srow);
    canvas.drawPath(path, Paint()..color = selected ? selectedFill : idleFill);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 4 : 2
        ..color = selected ? AppColors.accent : idleBorder,
    );
    canvas.restore();
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(StudentFilterRowPainter oldDelegate) =>
      oldDelegate.selected != selected;
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.title, required this.caption, this.trailing});

  final String title;
  final String caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppFonts.display,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: AppType.titleMediumSize,
            height: 1.2,
            fontWeight: AppType.medium,
            color: AppColors.text,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: AppType.captionPlusSize,
              height: 1.2,
              color: AppColors.textMuted,
            ),
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, this.note});

  final String label;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    return Row(
      children: [
        const SizedBox(
          width: 5,
          height: 5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.all(Radius.circular(1)),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppFonts.display,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: AppType.microPlusSize,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        if (note != null) ...[
          const SizedBox(width: 10),
          Text(
            note,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: AppType.captionSize,
              height: 1.2,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// "범위 모두 풀기"(`.chip.gy` + 되돌리기 아이콘).
class _ResetRangesChip extends StatelessWidget {
  const _ResetRangesChip({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => KitPressable(
    key: const ValueKey('student-filter-reset-ranges'),
    onPressed: onPressed,
    semanticLabel: '범위 모두 풀기',
    builder: (context, state) => Opacity(
      opacity: onPressed == null ? kitDisabledOpacity : 1,
      child: const ExcludeSemantics(
        child: BaChip(
          label: '범위 모두 풀기',
          tone: AppTones.gray,
          leading: Icon(Icons.restart_alt_rounded),
        ),
      ),
    ),
  );
}

/// 심상개화(FD-054): 데이터가 없어 비활성 칩과 "준비 중" 자리만 보인다. 조건에 넣지 않는다.
class _PotentialRow extends StatelessWidget {
  const _PotentialRow();

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('student-filter-potential'),
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // 좁은 창에서는 칩 줄을 자르고 안내 문구를 말줄임한다(넘침 없이).
      Flexible(
        flex: 3,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: rangeRowLabelWidth,
              child: Text(
                studentPotentialFilterLabel,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: AppType.bodySize,
                  height: 1.2,
                  fontWeight: AppType.bold,
                  color: rangeRowIdleLabelColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: ClipRect(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Row(
                    children: [
                      for (
                        var index = 0;
                        index < studentPotentialFilterChoices.length;
                        index++
                      ) ...[
                        if (index > 0) const SizedBox(width: 10),
                        SkewToggleChip(
                          label: studentPotentialFilterChoices[index],
                          selected: index == 0,
                          onChanged: null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      const Flexible(
        flex: 2,
        child: Text(
          studentPotentialFilterNote,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: AppType.captionSize,
            height: 1.2,
            color: AppColors.textMuted,
          ),
        ),
      ),
    ],
  );
}

class _ParallelogramClipper extends CustomClipper<Path> {
  const _ParallelogramClipper({required this.radius});

  final double radius;

  @override
  Path getClip(Size size) =>
      diagonalRowPath(size, DiagonalRowVariant.srow, radius: radius);

  @override
  bool shouldReclip(_ParallelogramClipper oldClipper) =>
      oldClipper.radius != radius;
}
