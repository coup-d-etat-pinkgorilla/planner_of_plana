// 통계 탭 3섹션 골격(FE7-a, 시안 Stats-Growth · Stats-Inventory · Stats-Plan, F 보고서 §2).
//
// - 왼쪽 주제 · 범위: "통계" 제목, 주제 버튼 3개(선택 핑크), 필터 버튼(FE7-e 전까지 비활성) + 보조 문구,
//   기준 데이터 3행(값 '—'), 아래 "다시 스캔"(FD-125: 스캔 탭으로).
// - 가운데 KPI + 위젯: 제목 줄(제목 · (i) · 범위) + 공용 사선 스크롤 viewport(translate 모드, 공용 스크롤바 · 포그 C).
//   행 0은 KPI 띠(라벨 + '—'), 그 아래 위젯 타일 줄(80° 평행사변형, 사선 계단은 translate 모드가 행 높이대로 만든다).
//   타일 안은 제목 + 차수 칩 + "준비 중"만 있다(그래프는 FE7-b 이후). 주제를 바꾸면 제목 줄과 viewport를
//   주제별 key로 바꿔 끼운다(같은 자리 다른 내용 — 스크롤 위치를 넘기지 않는다).
// - 오른쪽 근거: "근거 확인" 제목, 읽기 상태 안내 또는 빈 상태 문구, 아래 이동 버튼 2개(FE7-d 전까지 비활성).
// 좌표는 `statistics_studio_layout.dart`의 Studio 문서와 [StatisticsMetrics]다. 창이 낮으면 왼쪽 · 오른쪽 섹션 요소는
// 세로 비율대로 함께 줄고(계획 만들기 A 레일 규칙), 가운데 타일은 viewport 폭 비율로 높이가 바뀐다(타일 모양 유지).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_row.dart';
import '../kit/diagonal_scroll_viewport.dart';
import '../kit/info_popover.dart';
import '../kit/kit_glyph.dart';
import '../kit/kit_pressable.dart';
import '../kit/kpi_tile.dart';
import '../kit/scroll_viewport_fog.dart';
import '../kit/skew_controls.dart';
import '../kit/section_morph.dart' show sectionCanvasElementPolygon;
import '../kit/titles.dart';
import '../studio/statistics_studio_layout.dart';
import '../widgets/section_surface.dart';
import '../widgets/section_template_surface.dart';
import 'statistics_source.dart';
import 'statistics_topics.dart';

/// 근거 패널 빈 상태(구간을 아직 고르지 않음).
const statisticsEvidenceEmptyText = '구간을 고르면 근거가 보입니다.';

/// 타일 빈 상태(그래프는 FE7-b 이후).
const statisticsTilePendingText = '준비 중';

const _mutedColor = AppColors.textMuted;

const _captionStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  height: 1.2,
  fontWeight: AppType.semiBold,
  color: _mutedColor,
);

const _mutedStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  height: 1.35,
  color: _mutedColor,
);

/// 섹션 하나의 콘텐츠 캔버스 좌표 꼭짓점(Studio와 같은 함수).
///
/// 순서는 `buildAttachedSectionPolygon`과 같다. 왼쪽 사다리꼴 = 위 왼 · 위 오 · 아래 오 · 아래 왼,
/// 가운데 평행사변형 = 위 왼 · 위 오 · 아래 오 · 아래 왼, 오른쪽 사다리꼴 = 위 오 · 아래 오 · 아래 왼 · 위 왼.
List<Offset> statisticsSectionPolygon(Size size, String id) =>
    sectionCanvasElementPolygon(size, statisticsSection(id));

/// 가운데 스크롤 viewport 배치(콘텐츠 캔버스 좌표)와 공용 viewport에 넘길 안쪽 값.
@immutable
class StatisticsViewportGeometry {
  const StatisticsViewportGeometry({
    required this.rect,
    required this.horizontalInset,
    required this.scrollbarReserve,
  });

  factory StatisticsViewportGeometry.of(Size size) {
    final points = statisticsSectionPolygon(size, statisticsWidgetsSectionId);
    final top = points[0].dy;
    final bottom = points[3].dy;
    final viewportTop = top + StatisticsMetrics.viewportTop;
    final viewportBottom = bottom - StatisticsMetrics.viewportBottomGap;
    final left = points[3].dx;
    final right =
        _edgeX(points[1], points[2], viewportTop) -
        StatisticsMetrics.scrollbarEdgeGap;
    // 줄 자리 왼쪽 = inset + (viewport 바닥 − 행 바닥) × tan 10°. 행 아래 왼쪽 꼭짓점이 섹션 왼쪽 사선에서
    // tileEdgeGap만큼 떨어지려면 inset = tileEdgeGap + (viewport 바닥에서 섹션 바닥까지의 사선 깊이)다.
    final inset =
        StatisticsMetrics.tileEdgeGap +
        diagonalCutDepth(bottom - viewportBottom);
    // 줄 위 오른쪽 끝 = viewport 오른쪽 − inset − reserve − 행 위 × tan 10°. 섹션 오른쪽 사선에서 tileRightGap.
    final reserve = math.max(
      0.0,
      StatisticsMetrics.tileRightGap -
          StatisticsMetrics.scrollbarEdgeGap -
          inset,
    );
    return StatisticsViewportGeometry(
      rect: Rect.fromLTRB(
        left,
        viewportTop,
        math.max(left, right),
        math.max(viewportTop, viewportBottom),
      ),
      horizontalInset: inset,
      scrollbarReserve: reserve,
    );
  }

  final Rect rect;
  final double horizontalInset;
  final double scrollbarReserve;
}

/// 두 꼭짓점 [a] → [b] 변 위 [y]의 x.
double _edgeX(Offset a, Offset b, double y) {
  final span = b.dy - a.dy;
  if (span == 0) return a.dx;
  final t = ((y - a.dy) / span).clamp(0.0, 1.0).toDouble();
  return a.dx + (b.dx - a.dx) * t;
}

/// 통계 탭 3섹션.
class StatisticsWorkspace extends StatelessWidget {
  const StatisticsWorkspace({
    super.key,
    required this.mode,
    required this.data,
    required this.onModeChanged,
    required this.onRescan,
  });

  final StatisticsMode mode;

  /// `_reload()`가 읽은 원천 자료. FE7-a는 읽기 상태만 쓴다.
  final StatisticsSourceData data;
  final ValueChanged<StatisticsMode> onModeChanged;

  /// 왼쪽 "다시 스캔"(FD-125 권장안 중 지금 되는 부분: 스캔 탭을 연다).
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      // 시안 그리기 순서: 가운데 → 왼쪽 → 오른쪽.
      return Stack(
        children: [
          Positioned.fill(
            child: _WidgetsSection(size: size, mode: mode),
          ),
          Positioned.fill(
            child: _ScopeSection(
              size: size,
              mode: mode,
              onModeChanged: onModeChanged,
              onRescan: onRescan,
            ),
          ),
          Positioned.fill(
            child: _EvidenceSection(size: size, mode: mode, data: data),
          ),
        ],
      );
    },
  );
}

class _SectionPainter extends CustomPainter {
  const _SectionPainter(this.sectionId);

  final String sectionId;

  @override
  void paint(Canvas canvas, Size size) => paintSectionSurface(
    canvas,
    buildSectionCanvasElementPath(size, statisticsSection(sectionId)),
  );

  @override
  bool shouldRepaint(_SectionPainter oldDelegate) =>
      oldDelegate.sectionId != sectionId;
}

class _SectionClipper extends CustomClipper<Path> {
  const _SectionClipper(this.sectionId);

  final String sectionId;

  @override
  Path getClip(Size size) =>
      buildSectionCanvasElementPath(size, statisticsSection(sectionId));

  @override
  bool shouldReclip(_SectionClipper oldClipper) =>
      oldClipper.sectionId != sectionId;
}

/// 섹션 표면 + 섹션 모양으로 자른 내용.
class _SectionFrame extends StatelessWidget {
  const _SectionFrame({
    required this.sectionId,
    required this.surfaceKey,
    required this.children,
  });

  final String sectionId;
  final String surfaceKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: ValueKey(surfaceKey),
            painter: _SectionPainter(sectionId),
          ),
        ),
      ),
      Positioned.fill(
        child: ClipPath(
          clipper: _SectionClipper(sectionId),
          child: Stack(clipBehavior: Clip.none, children: children),
        ),
      ),
    ],
  );
}

/// [scale]이 1보다 작으면 [child]를 시안 크기(자리 ÷ scale)로 배치한 뒤 같은 비율로 줄인다.
class _ScaledBox extends StatelessWidget {
  const _ScaledBox({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (scale >= 1) return child;
    return LayoutBuilder(
      builder: (context, constraints) => FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: constraints.maxWidth / scale,
          height: constraints.maxHeight / scale,
          child: child,
        ),
      ),
    );
  }
}

/// 자리가 [minWidth] · [minHeight]보다 작으면 그 크기로 배치하고 넘친 부분을 자른다(인벤토리 `_Fit`과 같은 규칙).
class _MinBox extends StatelessWidget {
  const _MinBox({required this.minWidth, this.minHeight = 0, required this.child});

  final double minWidth;
  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.max(
        minWidth,
        constraints.maxWidth.isFinite ? constraints.maxWidth : minWidth,
      );
      final height = math.max(
        minHeight,
        constraints.maxHeight.isFinite ? constraints.maxHeight : minHeight,
      );
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: width,
          maxWidth: width,
          minHeight: height,
          maxHeight: height,
          child: child,
        ),
      );
    },
  );
}

/// 자리가 [minWidth]보다 좁으면 [child]를 그 폭으로 배치한 뒤 같은 비율로 줄인다(글자를 자르지 않는다).
class _FitWidth extends StatelessWidget {
  const _FitWidth({required this.minWidth, required this.child});

  final double minWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= minWidth) return child;
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: minWidth,
          height: constraints.maxHeight,
          child: child,
        ),
      );
    },
  );
}

/// KPI 띠를 줄이지 않고 그리는 최소 폭(타일 다섯 칸 × 158 + 간격). 이보다 좁으면 띠 전체를 같은 비율로 줄인다.
const _kpiBandMinWidth = 5 * 158.0 + 4 * StatisticsMetrics.kpiGap;

/// 왼쪽 섹션 행(주제 · 필터 · 기준 데이터 · 다시 스캔)을 그리는 최소 폭.
const _scopeRowMinWidth = 180.0;

// --- 왼쪽 주제 · 범위 --------------------------------------------------------

class _ScopeSection extends StatelessWidget {
  const _ScopeSection({
    required this.size,
    required this.mode,
    required this.onModeChanged,
    required this.onRescan,
  });

  final Size size;
  final StatisticsMode mode;
  final ValueChanged<StatisticsMode> onModeChanged;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    final points = statisticsSectionPolygon(size, statisticsScopeSectionId);
    final top = points[0].dy;
    final bottom = points[3].dy;
    final scale = StatisticsMetrics.scaleFor(bottom - top);
    double railRight(double y) => _edgeX(points[1], points[2], y);
    // 아주 좁은 창에서는 행 내용을 최소 폭으로 배치하고 오른쪽을 자른다(넘침 예외 대신).
    Widget scaled(Widget child) => _ScaledBox(
      scale: scale,
      child: _MinBox(minWidth: _scopeRowMinWidth, child: child),
    );
    Rect row(double offset, double height, double rightMargin) {
      final y = top + offset * scale;
      return Rect.fromLTWH(
        StatisticsMetrics.scopeLeft,
        y,
        math.max(0.0, railRight(y) - StatisticsMetrics.scopeLeft - rightMargin),
        height * scale,
      );
    }

    Widget text(double offset, double height, String value, TextStyle style,
        {String? key, double left = StatisticsMetrics.scopeTextLeft}) {
      final y = top + offset * scale;
      return Positioned(
        left: left,
        top: y,
        width: math.max(0.0, railRight(y) - left - StatisticsMetrics.scopeRightMargin),
        height: height * scale,
        child: _ScaledBox(
          scale: scale,
          child: Text(
            value,
            key: key == null ? null : ValueKey(key),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      );
    }

    final children = <Widget>[
      text(
        StatisticsMetrics.scopeTitleTop,
        StatisticsMetrics.scopeTitleHeight,
        '통계',
        kitDisplayStyle(AppType.headlineSmallSize),
        key: 'statistics-title',
      ),
    ];
    for (final topic in StatisticsMode.values) {
      children.add(
        Positioned.fromRect(
          rect: row(
            StatisticsMetrics.topicTop +
                StatisticsMetrics.topicPitch * topic.index,
            StatisticsMetrics.topicHeight,
            StatisticsMetrics.scopeRightMargin,
          ),
          child: scaled(
            _TopicButton(
              topic: topic,
              selected: topic == mode,
              onPressed: () {
                if (topic != mode) onModeChanged(topic);
              },
            ),
          ),
        ),
      );
    }
    children.addAll([
      text(
        StatisticsMetrics.filterCaptionTop,
        StatisticsMetrics.captionHeight,
        '필터 · 학생 성장에만 적용',
        _captionStyle,
      ),
      Positioned.fromRect(
        rect: row(
          StatisticsMetrics.filterTop,
          StatisticsMetrics.filterHeight,
          StatisticsMetrics.scopeRightMargin,
        ),
        child: scaled(_FilterButton(note: mode.filterNote)),
      ),
      text(
        StatisticsMetrics.filterNoteTop,
        StatisticsMetrics.filterNoteHeight,
        '학생 탭 필터와 따로 저장됩니다.\n'
            "팝업에서 '학생 탭 필터 불러오기'로 가져올 수 있습니다.",
        _mutedStyle.copyWith(fontSize: AppType.captionPlusSize),
        left: StatisticsMetrics.filterNoteLeft,
      ),
      text(
        StatisticsMetrics.baseCaptionTop,
        StatisticsMetrics.captionHeight,
        '기준 데이터',
        _captionStyle,
      ),
    ]);
    const baseRows = [
      ('student-scan', '학생 스캔'),
      ('inventory-scan', '인벤토리'),
      ('snapshots', '스냅샷'),
    ];
    for (final (index, (key, label)) in baseRows.indexed) {
      children.add(
        Positioned.fromRect(
          rect: row(
            StatisticsMetrics.baseTop + StatisticsMetrics.basePitch * index,
            StatisticsMetrics.baseHeight,
            StatisticsMetrics.scopeRightMargin,
          ),
          child: scaled(
            _BaseDataRow(key: ValueKey('statistics-base-$key'), label: label),
          ),
        ),
      );
    }
    final rescanTop =
        bottom -
        top -
        StatisticsMetrics.rescanFromBottom * scale;
    children.add(
      Positioned.fromRect(
        rect: row(
          rescanTop / scale,
          StatisticsMetrics.rescanHeight,
          StatisticsMetrics.scopeRightMargin,
        ),
        child: scaled(
          RailButton(
            key: const ValueKey('statistics-rescan'),
            variant: RailButtonVariant.ghost,
            height: StatisticsMetrics.rescanHeight,
            semanticLabel: '다시 스캔',
            onPressed: onRescan,
            child: const Row(
              children: [
                Icon(Icons.document_scanner_outlined),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '다시 스캔',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppType.titleSmallSize,
                      fontWeight: AppType.bold,
                    ),
                  ),
                ),
                _Chevron(),
              ],
            ),
          ),
        ),
      ),
    );
    return _SectionFrame(
      sectionId: statisticsScopeSectionId,
      surfaceKey: 'statistics-scope-surface',
      children: children,
    );
  }
}

/// 오른쪽 꺾쇠(키트 아래 꺾쇠를 −90° 돌림, 시안 `rotate(-90deg)`).
class _Chevron extends StatelessWidget {
  const _Chevron({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => RotatedBox(
    quarterTurns: 3,
    child: SizedBox.square(
      dimension: 16,
      child: CustomPaint(
        painter: KitGlyphPainter(
          glyph: KitGlyph.chevronDown,
          color: color ?? IconTheme.of(context).color ?? AppColors.text,
        ),
      ),
    ),
  );
}

class _TopicButton extends StatelessWidget {
  const _TopicButton({
    required this.topic,
    required this.selected,
    required this.onPressed,
  });

  final StatisticsMode topic;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => RailButton(
    key: ValueKey('statistics-topic-${topic.key}'),
    variant: selected ? RailButtonVariant.selectedPink : RailButtonVariant.ghost,
    height: StatisticsMetrics.topicHeight,
    semanticLabel: topic.label,
    onPressed: onPressed,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          topic.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: AppType.bodyLargeSize,
            fontWeight: AppType.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          topic.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _mutedStyle.copyWith(height: 1.2),
        ),
      ],
    ),
  );
}

/// 필터 버튼 자리. 통계 전용 필터(FD-104)는 FE7-e라 지금은 누를 수 없다.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) => RailButton(
    key: const ValueKey('statistics-filter'),
    variant: RailButtonVariant.ghost,
    height: StatisticsMetrics.filterHeight,
    semanticLabel: '필터',
    onPressed: null,
    child: Row(
      children: [
        const SizedBox.square(
          dimension: 16,
          child: CustomPaint(
            painter: KitGlyphPainter(glyph: KitGlyph.filter, color: _mutedColor),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '필터',
                maxLines: 1,
                style: TextStyle(
                  fontSize: AppType.bodyPlusSize,
                  fontWeight: AppType.bold,
                ),
              ),
              Text(
                note,
                key: const ValueKey('statistics-filter-note'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _mutedStyle.copyWith(
                  fontSize: AppType.captionPlusSize,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const _Chevron(color: _mutedColor),
      ],
    ),
  );
}

/// 기준 데이터 한 행. 시각 · 횟수는 이력 연동(FE7-h) 전이라 '—'다.
class _BaseDataRow extends StatelessWidget {
  const _BaseDataRow({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: StatisticsMetrics.baseHeight,
    child: DiagonalRow(
      variant: DiagonalRowVariant.rail,
      padding: EdgeInsets.only(
        left: 16,
        right: diagonalCutDepth(StatisticsMetrics.baseHeight) + 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mutedStyle.copyWith(fontSize: AppType.bodySize),
            ),
          ),
          const SizedBox(width: 8),
          const BaChip(label: '—', tone: AppTones.gray),
        ],
      ),
    ),
  );
}

// --- 가운데 KPI + 위젯 --------------------------------------------------------

class _WidgetsSection extends StatelessWidget {
  const _WidgetsSection({required this.size, required this.mode});

  final Size size;
  final StatisticsMode mode;

  @override
  Widget build(BuildContext context) {
    final points = statisticsSectionPolygon(size, statisticsWidgetsSectionId);
    final top = points[0].dy;
    final titleLeft = points[0].dx + StatisticsMetrics.titleLeftInset;
    final titleRight = points[1].dx - StatisticsMetrics.titleRightInset;
    final viewport = StatisticsViewportGeometry.of(size);
    return _SectionFrame(
      sectionId: statisticsWidgetsSectionId,
      surfaceKey: 'statistics-widgets-surface',
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: AppMotion.header,
            switchInCurve: AppMotion.entranceCurve,
            switchOutCurve: AppMotion.entranceCurve,
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.expand,
              children: [...previous, ?current],
            ),
            child: Stack(
              key: ValueKey('statistics-topic-body-${mode.key}'),
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: titleLeft,
                  top: top + StatisticsMetrics.titleTop,
                  width: math.max(0.0, titleRight - titleLeft),
                  height: StatisticsMetrics.titleHeight,
                  child: _TopicTitle(mode: mode),
                ),
                Positioned.fromRect(
                  rect: viewport.rect,
                  child: _TopicViewport(
                    key: ValueKey('statistics-viewport-${mode.key}'),
                    mode: mode,
                    geometry: viewport,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopicTitle extends StatelessWidget {
  const _TopicTitle({required this.mode});

  final StatisticsMode mode;

  @override
  // 제목 묶음은 왼쪽, 범위 글자는 오른쪽 끝(시안 사이 빈 span). 둘 다 느슨한 Flexible이라 남는 폭을
  // spaceBetween이 가운데에 둔다.
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                mode.label,
                key: const ValueKey('statistics-topic-title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kitDisplayStyle(AppType.headlineSize),
              ),
            ),
            const SizedBox(width: 8),
            InfoPopover(
              key: ValueKey('statistics-help-${mode.key}'),
              label: mode.label,
              title: mode.label,
              children: [InfoPopoverText.plain(mode.help)],
            ),
          ],
        ),
      ),
      const SizedBox(width: 16),
      Flexible(
        child: Align(
          widthFactor: 1,
          alignment: Alignment.centerRight,
          child: mode.scopeIsChip
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: BaChip(
                    key: const ValueKey('statistics-scope-label'),
                    label: mode.scope,
                  ),
                )
              : Text(
                  mode.scope,
                  key: const ValueKey('statistics-scope-label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mutedStyle.copyWith(height: 1.2),
                ),
        ),
      ),
    ],
  );
}

/// 주제 하나의 KPI 띠 + 위젯 타일 세로 스크롤(공용 viewport, translate 모드).
class _TopicViewport extends StatelessWidget {
  const _TopicViewport({
    super.key,
    required this.mode,
    required this.geometry,
  });

  final StatisticsMode mode;
  final StatisticsViewportGeometry geometry;

  @override
  Widget build(BuildContext context) {
    final rows = mode.rows;
    final scale = statisticsTileScale(geometry.rect.width);
    // 행: KPI 띠, 타일 줄들, 마지막 줄 아래 여백을 시안(32)에 맞추는 빈 행.
    final spacer =
        StatisticsMetrics.contentBottom -
        StatisticsMetrics.rowGap -
        StatisticsMetrics.contentTop;
    double heightOf(int index) {
      if (index == 0) return StatisticsMetrics.kpiHeight;
      if (index > rows.length) return spacer;
      return rows[index - 1].height * scale;
    }

    return DiagonalScrollViewport(
      keyPrefix: 'statistics-${mode.key}',
      itemCount: rows.length + 2,
      itemHeight: heightOf,
      itemGap: StatisticsMetrics.rowGap,
      verticalInset: StatisticsMetrics.contentTop,
      horizontalInset: geometry.horizontalInset,
      scrollbarReserve: geometry.scrollbarReserve,
      fog: ScrollFogSpec.statistics,
      itemBuilder: (context, index) {
        if (index == 0) return _KpiBand(mode: mode);
        if (index > rows.length) return const SizedBox.shrink();
        return _TileRow(row: rows[index - 1], height: heightOf(index));
      },
    );
  }
}

/// KPI 띠 자리: 라벨 다섯 칸, 값은 FE7-b부터(지금 '—').
class _KpiBand extends StatelessWidget {
  const _KpiBand({required this.mode});

  final StatisticsMode mode;

  @override
  Widget build(BuildContext context) {
    final labels = mode.kpiLabels;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: StatisticsMetrics.kpiInset,
      ),
      child: _FitWidth(
        minWidth: _kpiBandMinWidth,
        child: Row(
          key: ValueKey('statistics-kpis-${mode.key}'),
          children: [
            for (final (index, label) in labels.indexed) ...[
              if (index > 0) const SizedBox(width: StatisticsMetrics.kpiGap),
              Expanded(
                child: Center(
                  child: KpiTile(
                    key: ValueKey('statistics-kpi-${mode.key}-$index'),
                    label: label,
                    value: '—',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 위젯 타일 한 줄. 타일 자리는 [statisticsTileSlots]다.
class _TileRow extends StatelessWidget {
  const _TileRow({required this.row, required this.height});

  final StatisticsTileRow row;
  final double height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final slots = statisticsTileSlots(
        rowWidth: constraints.maxWidth,
        height: height,
        widths: [for (final tile in row.tiles) tile.width],
      );
      return Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (index, tile) in row.tiles.indexed)
            Positioned(
              left: slots[index].left,
              top: 0,
              width: math.max(0.0, slots[index].width),
              height: height,
              child: _StatisticsTile(
                key: ValueKey('statistics-tile-${tile.id}'),
                tile: tile,
                height: height,
              ),
            ),
        ],
      );
    },
  );
}

/// 위젯 타일(키트 [WidgetTile]): 머리(ID · 제목 · seg 자리 · 차수 칩) + "준비 중".
class _StatisticsTile extends StatelessWidget {
  const _StatisticsTile({super.key, required this.tile, required this.height});

  final StatisticsTileSpec tile;
  final double height;

  @override
  Widget build(BuildContext context) {
    final side =
        diagonalCutDepth(height) +
        StatisticsMetrics.tileSideInset +
        StatisticsMetrics.tilePadding;
    return WidgetTile(
      padding: EdgeInsets.fromLTRB(
        side,
        StatisticsMetrics.tilePadding,
        side,
        StatisticsMetrics.tilePadding,
      ),
      child: _MinBox(
        minWidth: 200,
        minHeight: 64,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TileHeader(tile: tile),
            const Expanded(
              child: Center(
                child: Text(
                  statisticsTilePendingText,
                  maxLines: 1,
                  style: _mutedStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 타일 머리(시안 `.dsp` 16px 제목 줄 + 그라데이션 룰). 키트 [TileTitle]은 글자 하나만 받으므로 같은 조각
/// ([TitleBar] 6×18 · 간격 8 · [TitleRule] 캡 40 · 줄 사이 7)으로 ID(13px [AppColors.textMuted], 오른쪽 8)와
/// 제목(16px 흰색)을 나눠 그린다. 오른쪽은 시안 머리 그대로 seg 자리(비활성, 높이 26 · 글자 11 · 안쪽 16 · 간격 6)와
/// 차수 칩(1차 핑크 · 2차 기본 · 3차 회색)이다. 좁으면 오른쪽 묶음을 줄인다.
class _TileHeader extends StatelessWidget {
  const _TileHeader({required this.tile});

  final StatisticsTileSpec tile;

  static const idSize = 13.0;
  static const idGap = 8.0;
  static const segHeight = 26.0;
  static const segFontSize = 11.0;

  @override
  Widget build(BuildContext context) {
    final segments = tile.segments;
    final trailing = <Widget>[
      if (segments.isNotEmpty)
        SkewSegmented<int>(
          key: ValueKey('statistics-tile-${tile.id}-seg'),
          segments: [
            for (final (index, label) in segments.indexed)
              SkewSegment(value: index, label: label),
          ],
          selected: 0,
          onChanged: null,
          height: segHeight,
          fontSize: segFontSize,
        ),
      if (segments.isNotEmpty && tile.showsOrderChip) const SizedBox(width: 6),
      if (tile.showsOrderChip)
        BaChip(
          key: ValueKey('statistics-tile-${tile.id}-order'),
          label: tile.orderLabel,
          tone: switch (tile.order) {
            1 => AppTones.pink,
            2 => AppTones.info,
            _ => AppTones.gray,
          },
        ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TitleBar(width: 6, height: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          tile.id,
                          key: ValueKey('statistics-tile-${tile.id}-id'),
                          maxLines: 1,
                          style: kitDisplayStyle(
                            idSize,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: idGap),
                        Flexible(
                          child: Text(
                            tile.title,
                            key: ValueKey('statistics-tile-${tile.id}-title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: kitDisplayStyle(AppType.titleSize),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (trailing.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(mainAxisSize: MainAxisSize.min, children: trailing),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),
        const TitleRule(),
      ],
    );
  }
}

// --- 오른쪽 근거 --------------------------------------------------------------

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({
    required this.size,
    required this.mode,
    required this.data,
  });

  final Size size;
  final StatisticsMode mode;
  final StatisticsSourceData data;

  @override
  Widget build(BuildContext context) {
    final points = statisticsSectionPolygon(size, statisticsEvidenceSectionId);
    final topLeft = points[3];
    final bottomLeft = points[2];
    final right = points[0].dx;
    final top = topLeft.dy;
    final bottom = bottomLeft.dy;
    final scale = StatisticsMetrics.scaleFor(bottom - top);
    double leftEdge(double y) => _edgeX(topLeft, bottomLeft, y);
    final titleLeft = topLeft.dx + StatisticsMetrics.evidenceTitleLeftInset;
    final titleTop = top + StatisticsMetrics.evidenceTitleTop * scale;
    final noteTop = top + StatisticsMetrics.evidenceNoteTop * scale;
    final noteLeft = leftEdge(noteTop) + StatisticsMetrics.evidenceTitleLeftInset;
    final notice = data.notice;
    Rect button(double fromBottom, double height) {
      final y = bottom - fromBottom * scale;
      final left =
          leftEdge(y + height * scale) + StatisticsMetrics.evidenceButtonEdgeGap;
      return Rect.fromLTRB(
        left,
        y,
        math.max(left, right - StatisticsMetrics.evidenceButtonRight),
        y + height * scale,
      );
    }

    final (secondary, primary) = mode.evidenceActions;
    return _SectionFrame(
      sectionId: statisticsEvidenceSectionId,
      surfaceKey: 'statistics-evidence-surface',
      children: [
        Positioned(
          left: titleLeft,
          top: titleTop,
          width: math.max(
            0.0,
            right - StatisticsMetrics.evidenceTitleRight - titleLeft,
          ),
          height: StatisticsMetrics.evidenceTitleHeight * scale,
          child: _ScaledBox(
            scale: scale,
            child: const Align(
              alignment: Alignment.centerLeft,
              child: PanelTitle('근거 확인', key: ValueKey('statistics-evidence-title')),
            ),
          ),
        ),
        Positioned(
          left: noteLeft,
          top: noteTop,
          width: math.max(
            0.0,
            right - StatisticsMetrics.evidenceButtonRight - noteLeft,
          ),
          height: StatisticsMetrics.evidenceNoteHeight * scale,
          child: _ScaledBox(
            scale: scale,
            child: Text(
              notice ?? statisticsEvidenceEmptyText,
              key: const ValueKey('statistics-evidence-note'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: _mutedStyle.copyWith(
                color: notice != null && data.errors.isNotEmpty
                    ? AppColors.danger
                    : _mutedColor,
              ),
            ),
          ),
        ),
        Positioned.fromRect(
          rect: button(
            StatisticsMetrics.evidenceSecondaryFromBottom,
            StatisticsMetrics.evidenceSecondaryHeight,
          ),
          child: _ScaledBox(
            scale: scale,
            child: _EvidenceButton(
              key: const ValueKey('statistics-evidence-secondary'),
              action: secondary,
              variant: RailButtonVariant.ghost,
              height: StatisticsMetrics.evidenceSecondaryHeight,
            ),
          ),
        ),
        Positioned.fromRect(
          rect: button(
            StatisticsMetrics.evidencePrimaryFromBottom,
            StatisticsMetrics.evidencePrimaryHeight,
          ),
          child: _ScaledBox(
            scale: scale,
            child: _EvidenceButton(
              key: const ValueKey('statistics-evidence-primary'),
              action: primary,
              variant: RailButtonVariant.primary,
              height: StatisticsMetrics.evidencePrimaryHeight,
            ),
          ),
        ),
      ],
    );
  }
}

/// 근거 패널 아래 이동 버튼 자리. 시안 모양은 왼쪽 변 80° · 오른쪽 변 수직이라 키트 [RailButton]을 좌우로 뒤집어
/// 바탕만 쓰고, 글자는 뒤집지 않고 위에 올린다. 원본 탭 이동은 FE7-d라 지금은 누를 수 없다(onPressed 없음).
class _EvidenceButton extends StatelessWidget {
  const _EvidenceButton({
    super.key,
    required this.action,
    required this.variant,
    required this.height,
  });

  final StatisticsEvidenceAction action;
  final RailButtonVariant variant;
  final double height;

  @override
  Widget build(BuildContext context) {
    final foreground = RailButtonLook.of(variant).foreground;
    final detail = action.detail;
    return Stack(
      fit: StackFit.expand,
      children: [
        Transform.flip(
          flipX: true,
          child: RailButton(
            variant: variant,
            height: height,
            semanticLabel: detail == null
                ? action.label
                : '${action.label} · $detail',
            onPressed: null,
            child: const SizedBox.shrink(),
          ),
        ),
        IgnorePointer(
          child: ExcludeSemantics(
            child: Opacity(
              opacity: kitDisabledOpacity,
              child: Padding(
                padding: EdgeInsets.only(
                  left: diagonalCutDepth(height) + 12,
                  right: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppFonts.body,
                              fontFamilyFallback: AppFonts.fallback,
                              fontSize: AppType.titleSmallSize,
                              height: 1.2,
                              fontWeight: AppType.bold,
                              color: foreground,
                            ),
                          ),
                          if (detail != null)
                            Text(
                              detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppFonts.body,
                                fontFamilyFallback: AppFonts.fallback,
                                fontSize: AppType.captionPlusSize,
                                height: 1.25,
                                color: foreground.withValues(alpha: 0.8),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Chevron(color: foreground),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
