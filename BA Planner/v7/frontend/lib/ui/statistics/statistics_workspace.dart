// 통계 탭 3섹션 골격(FE7-a, 시안 Stats-Growth · Stats-Inventory · Stats-Plan, F 보고서 §2).
//
// - 왼쪽 주제 · 범위: "통계" 제목, 주제 버튼 3개(선택 핑크), 필터 버튼(FE7-e 전까지 비활성) + 보조 문구,
//   기준 데이터 3행(FE7-h 이력: 학생 스캔 · 인벤토리 시각, 스냅샷 n회 · 기간, 모르면 '—'), 아래 "다시 스캔"(FD-125: 스캔 탭으로).
// - 가운데 KPI + 위젯: 제목 줄(제목 · (i) · 범위) + 공용 사선 스크롤 viewport(translate 모드, 공용 스크롤바 · 포그 C).
//   행 0은 KPI 띠, 그 아래 위젯 타일 줄(80° 평행사변형, 사선 계단은 translate 모드가 행 높이대로 만든다).
//   학생 성장(FE7-b)은 KPI 5칸 값(누르면 그래프 줄로 스크롤)과 A1 · A2 그래프를 그린다
//   (`statistics_growth_charts.dart`). 인벤토리 현황 · 계획 집계(FE7-c)는 KPI 5칸 값과 B1 · C1 · C2 그래프를 그린다
//   (`statistics_supply_charts.dart`, FD-031 · 032 · 034 · 105). 계획 집계는 활성 문서 계산으로 KPI 첫 부족 · 막힌 학생,
//   범위 칩 페이즈 수, C1 "페이즈 순", C3 페이즈별 누적 부족을 더한다(FE7-g, `statistics_plan_charts.dart`). FE7-h는 이력으로
//   KPI 증감("지난 스냅샷 대비", 모르면 회색 '—'), A6 성장 추이 · B3 주요 재화 변화(seg 동작)를 그린다
//   (`statistics_history_charts.dart`). 스냅샷이 2회 미만이면 그 타일 안에 확정 4 문구고(FD-106), 그 줄 타일이 모두 그래프가
//   없으면 줄을 시안대로 낮춘다(FD-109). 다른 타일은 제목 + 차수 칩 + "준비 중"이다(FD-106 사용자 결정 10-13). 계획이 없으면
//   그래프 타일 안에 빈 상태 문구다.
//   주제를 바꾸면 제목 줄과 viewport를 주제별 key로 바꿔 끼운다(같은 자리 다른 내용 — 스크롤 위치를 넘기지 않는다).
// - 오른쪽 근거: "근거 확인" 제목, 읽기 상태 안내 또는 빈 상태 문구, 아래 이동 버튼 2개(FE7-d: 고른 구간 · 재화가 있으면
//   원본 탭으로 넘긴다, 버튼 글자 · 동작은 [StatisticsWorkspace.evidenceActions]).
//   학생 성장에서 A1 구간 · A2 항목을 고르면 그 근거 목록이다(`statistics_growth_evidence.dart`). B1 막대 · C1 행 · C2 점을
//   고르면 재화 · 학생 근거다(`statistics_supply_evidence.dart`).
// 좌표는 `statistics_studio_layout.dart`의 Studio 문서와 [StatisticsMetrics]다. 창이 낮으면 왼쪽 · 오른쪽 섹션 요소는
// 세로 비율대로 함께 줄고(계획 만들기 A 레일 규칙), 가운데 타일은 viewport 폭 비율로 높이가 바뀐다(타일 모양 유지).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../statistics/statistics_growth_projection.dart';
import '../../statistics/statistics_history_projection.dart';
import '../../statistics/statistics_plan_projection.dart';
import '../../statistics/statistics_supply_projection.dart';
import '../geometry/diagonal_geometry.dart';
import '../inventory/inventory_history.dart' show inventorySignedCount;
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
import '../widgets/plan_scenario_preview.dart' show planScenarioBottleneckValue;
import '../widgets/section_surface.dart';
import '../widgets/section_template_surface.dart';
import 'statistics_growth_charts.dart';
import 'statistics_growth_evidence.dart';
import 'statistics_history_charts.dart';
import 'statistics_plan_charts.dart';
import 'statistics_source.dart';
import 'statistics_supply_charts.dart';
import 'statistics_supply_evidence.dart';
import 'statistics_topics.dart';

/// 근거 패널 빈 상태(구간을 아직 고르지 않음).
const statisticsEvidenceEmptyText = '구간을 고르면 근거가 보입니다.';

/// 인벤토리 현황 · 계획 집계 근거 패널 빈 상태(FE7-c, 시안 없음 — 고르는 그래프 이름을 쓴다).
const statisticsInventoryEvidenceEmptyText = 'B1 막대를 고르면 근거가 보입니다.';
const statisticsPlanEvidenceEmptyText = 'C1 행이나 C2 점을 고르면 근거가 보입니다.';

/// B1 · C1 · C2 빈 상태: 저장된 계획(사용자 목표)이 없다(시안에 없는 문구, FE7-c가 정함).
const statisticsSupplyNoPlanText = '저장된 계획이 없습니다. 계획에 목표를 저장하면 나타납니다.';

/// B1 · C1 · C2 빈 상태: 계획은 있지만 계획이 쓰는 재화가 없다.
const statisticsSupplyNoNeedsText = '계획에 필요한 재화가 없습니다.';

/// B1 빈 상태: 계획 재화가 재화(크레딧 · 엘리그마)뿐이다.
const statisticsSupplyNoCategoriesText = '카테고리로 나눌 재화가 없습니다. 크레딧 · 엘리그마는 C1에서 봅니다.';

/// C2 빈 상태: 보유를 아는 계획 재화가 없다.
const statisticsSupplyNoKnownText = '보유를 아는 재화가 없습니다. 인벤토리 스캔을 실행하면 나타납니다.';

/// C3 빈 상태: 활성 문서 계산에서 끝까지 모자라는 재화가 없다(FE7-g, 시안 없음).
const statisticsPlanNoShortageText = '계획 끝까지 모자라는 재화가 없습니다.';

/// 아직 그리지 않는 타일(FD-106 사용자 결정 10-13: 자리를 유지하고 "준비 중").
const statisticsTilePendingText = '준비 중';

/// A1 · A2 빈 상태: 보유 학생이 없다(시안에 없는 문구, FE7-b가 정함).
const statisticsGrowthNoStudentsText = '보유 학생이 없습니다. 학생 스캔을 실행하면 나타납니다.';

/// A1 · A2 빈 상태: 보유 학생은 있지만 값을 아는 학생이 없다.
String statisticsGrowthNoKnownText(String label, int owned) =>
    '$label 값을 아는 학생이 없습니다. 보유 $owned명 모두 모르는 값이 있습니다.';

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
    this.growth = const StatisticsGrowthView(growth: null),
    this.supply = const StatisticsSupplyView(supply: null),
    this.history = const StatisticsHistoryView(),
    this.evidenceActions,
  });

  final StatisticsMode mode;

  /// `_reload()`가 읽은 원천 자료(읽기 상태 · 안내).
  final StatisticsSourceData data;

  /// 학생 성장 projection과 고른 구간 · seg(FE7-b).
  final StatisticsGrowthView growth;

  /// 인벤토리 · 계획 projection과 고른 카테고리 · 재화(FE7-c).
  final StatisticsSupplyView supply;

  /// 이력 projection(기준 데이터 · KPI 증감 · A6 · B3, FE7-h).
  final StatisticsHistoryView history;
  final ValueChanged<StatisticsMode> onModeChanged;

  /// 왼쪽 "다시 스캔"(FD-125 권장안 중 지금 되는 부분: 스캔 탭을 연다).
  final VoidCallback onRescan;

  /// 근거 패널 아래 ghost · primary 버튼(FE7-d). 없으면 주제 기본 글자(비활성)다.
  final (StatisticsEvidenceAction, StatisticsEvidenceAction)? evidenceActions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      // 시안 그리기 순서: 가운데 → 왼쪽 → 오른쪽.
      return Stack(
        children: [
          Positioned.fill(
            child: _WidgetsSection(
              size: size,
              mode: mode,
              data: data,
              growth: growth,
              supply: supply,
              history: history,
            ),
          ),
          Positioned.fill(
            child: _ScopeSection(
              size: size,
              mode: mode,
              owned: growth.growth?.ownedCount,
              history: history,
              onModeChanged: onModeChanged,
              onRescan: onRescan,
            ),
          ),
          Positioned.fill(
            child: _EvidenceSection(
              size: size,
              mode: mode,
              data: data,
              growth: growth,
              supply: supply,
              actions: evidenceActions ?? mode.evidenceActions,
            ),
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

/// KPI 띠를 줄이지 않고 그리는 최소 폭(타일 다섯 칸 × 200 + 간격). 이보다 좁으면 띠 전체를 같은 비율로 줄인다.
/// FE7-b에서 값("63.4%" 26px · "/ 170 · —")이 들어와 158 → 200으로 넓혔다(기준 viewport 띠 1373.3에는 영향 없음).
const _kpiBandMinWidth = 5 * 200.0 + 4 * StatisticsMetrics.kpiGap;

/// 근거 머리(제목 + 인원 칩)를 그리는 최소 폭. 더 좁으면 오른쪽을 자른다.
const _evidenceTitleMinWidth = 240.0;

/// 왼쪽 섹션 행(주제 · 필터 · 기준 데이터 · 다시 스캔)을 그리는 최소 폭.
const _scopeRowMinWidth = 180.0;

// --- 왼쪽 주제 · 범위 --------------------------------------------------------

class _ScopeSection extends StatelessWidget {
  const _ScopeSection({
    required this.size,
    required this.mode,
    required this.owned,
    required this.history,
    required this.onModeChanged,
    required this.onRescan,
  });

  final Size size;
  final StatisticsMode mode;

  /// 보유 학생 수(필터 부제). 모르면 null.
  final int? owned;

  /// 기준 데이터 값(FE7-h).
  final StatisticsHistoryView history;
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
        child: scaled(_FilterButton(note: mode.filterNoteFor(owned))),
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
    // 시안 칩 색: 학생 스캔 ok · 인벤토리 wn · 스냅샷 gy(값을 모르면 회색 '—').
    final baseRows = [
      ('student-scan', '학생 스캔', history.studentScan, AppTones.ok),
      ('inventory-scan', '인벤토리', history.inventoryScan, AppTones.warn),
      ('snapshots', '스냅샷', history.snapshots, AppTones.gray),
    ];
    for (final (index, (key, label, value, tone)) in baseRows.indexed) {
      children.add(
        Positioned.fromRect(
          rect: row(
            StatisticsMetrics.baseTop + StatisticsMetrics.basePitch * index,
            StatisticsMetrics.baseHeight,
            StatisticsMetrics.scopeRightMargin,
          ),
          child: scaled(
            _BaseDataRow(
              key: ValueKey('statistics-base-$key'),
              valueKey: 'statistics-base-$key-value',
              label: label,
              value: value,
              tone: value == '—' ? AppTones.gray : tone,
            ),
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

/// 기준 데이터 한 행(FE7-h): 라벨 + 오른쪽 칩(값, 모르면 회색 '—'). 칩은 좁으면 줄인다.
class _BaseDataRow extends StatelessWidget {
  const _BaseDataRow({
    super.key,
    required this.valueKey,
    required this.label,
    required this.value,
    required this.tone,
  });

  final String valueKey;
  final String label;
  final String value;
  final AppTone tone;

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
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: BaChip(
                  key: ValueKey(valueKey),
                  label: value,
                  tone: tone,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// --- 가운데 KPI + 위젯 --------------------------------------------------------

class _WidgetsSection extends StatelessWidget {
  const _WidgetsSection({
    required this.size,
    required this.mode,
    required this.data,
    required this.growth,
    required this.supply,
    required this.history,
  });

  final Size size;
  final StatisticsMode mode;
  final StatisticsSourceData data;
  final StatisticsGrowthView growth;
  final StatisticsSupplyView supply;
  final StatisticsHistoryView history;

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
                  child: _TopicTitle(
                    mode: mode,
                    owned: growth.growth?.ownedCount,
                    planStudents: statisticsPlanStudentCount(data),
                    phases: supply.planning?.phaseCount,
                    inventoryScan: history.inventoryScanAgo,
                  ),
                ),
                Positioned.fromRect(
                  rect: viewport.rect,
                  child: _TopicViewport(
                    key: ValueKey('statistics-viewport-${mode.key}'),
                    mode: mode,
                    geometry: viewport,
                    data: data,
                    growth: growth,
                    supply: supply,
                    history: history,
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

/// 계획(사용자 목표) 학생 수(계획 집계 범위 칩). 계정 상태를 못 읽었으면 null.
int? statisticsPlanStudentCount(StatisticsSourceData data) {
  final state = data.state;
  if (data.loading || state == null) return null;
  return {for (final goal in state.goals) goal.studentId}.length;
}

class _TopicTitle extends StatelessWidget {
  const _TopicTitle({
    required this.mode,
    required this.owned,
    required this.planStudents,
    required this.phases,
    required this.inventoryScan,
  });

  final StatisticsMode mode;
  final int? owned;
  final int? planStudents;

  /// 활성 계획 문서의 페이즈 수(FE7-g). 문서 계산이 없으면 null.
  final int? phases;

  /// 마지막 인벤토리 스캔(`3일 전`, FE7-h). 모르면 '—'.
  final String inventoryScan;

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
                    label: mode.scopeFor(
                      owned,
                      planStudents: planStudents,
                      phases: phases,
                    ),
                  ),
                )
              : Text(
                  mode.scopeFor(owned, inventoryScan: inventoryScan),
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

//// 주제 하나의 KPI 띠 + 위젯 타일 세로 스크롤(공용 viewport, translate 모드).
class _TopicViewport extends StatefulWidget {
  const _TopicViewport({
    super.key,
    required this.mode,
    required this.geometry,
    required this.data,
    required this.growth,
    required this.supply,
    required this.history,
  });

  final StatisticsMode mode;
  final StatisticsViewportGeometry geometry;
  final StatisticsSourceData data;
  final StatisticsGrowthView growth;
  final StatisticsSupplyView supply;
  final StatisticsHistoryView history;

  @override
  State<_TopicViewport> createState() => _TopicViewportState();
}

class _TopicViewportState extends State<_TopicViewport> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// KPI를 누르면 같은 주제의 그래프 줄 [row]로 스크롤한다(FD-105, 줄은 [StatisticsModeSpec.kpiTargetRows]). 그 줄 위로
  /// 맞추고, 스크롤 범위보다 아래면 끝까지다.
  void _scrollToRow(int row, double scale) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    var offset =
        StatisticsMetrics.contentTop +
        StatisticsMetrics.kpiHeight +
        StatisticsMetrics.rowGap;
    final rows = widget.mode.rows;
    for (var index = 0; index < row && index < rows.length; index++) {
      offset +=
          statisticsRowHeight(rows[index], widget.history) * scale +
          StatisticsMetrics.rowGap;
    }
    _controller.animateTo(
      offset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble(),
      duration: AppMotion.header,
      curve: AppMotion.entranceCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final geometry = widget.geometry;
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
      return statisticsRowHeight(rows[index - 1], widget.history) * scale;
    }

    final growth = mode == StatisticsMode.students ? widget.growth : null;
    final supply = mode == StatisticsMode.students ? null : widget.supply;
    final targets = mode.kpiTargetRows;
    return DiagonalScrollViewport(
      keyPrefix: 'statistics-${mode.key}',
      controller: _controller,
      itemCount: rows.length + 2,
      itemHeight: heightOf,
      itemGap: StatisticsMetrics.rowGap,
      verticalInset: StatisticsMetrics.contentTop,
      horizontalInset: geometry.horizontalInset,
      scrollbarReserve: geometry.scrollbarReserve,
      fog: ScrollFogSpec.statistics,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _KpiBand(
            mode: mode,
            values: switch (mode) {
              StatisticsMode.students => statisticsGrowthKpis(
                widget.growth.growth,
                widget.history.growthDeltas,
              ),
              StatisticsMode.inventory => statisticsInventoryKpis(
                widget.supply.supply,
                widget.history.supplyDeltas,
              ),
              StatisticsMode.plan => statisticsPlanKpis(
                widget.supply.supply,
                unplannedLow: statisticsUnplannedLowCount(widget.growth.growth),
                planning: widget.supply.planning,
                deltas: widget.history.supplyDeltas,
              ),
            },
            onPressed: (kpi) => _scrollToRow(targets[kpi], scale),
          );
        }
        if (index > rows.length) return const SizedBox.shrink();
        return _TileRow(
          row: rows[index - 1],
          height: heightOf(index),
          history: widget.history,
          growth: growth,
          supply: supply,
          supplyEmpty: supply == null
              ? null
              : statisticsSupplyEmptyText(widget.data, supply),
        );
      },
    );
  }
}

/// KPI 한 칸 값(값 · 증감 · 증감 색 · 값 색). 값 색이 null이면 키트 기본(흰색)이다.
typedef StatisticsKpiValue = ({
  String value,
  String? delta,
  KpiDeltaTone tone,
  Color? color,
});

const StatisticsKpiValue _unknownKpi = (
  value: '—',
  delta: null,
  tone: KpiDeltaTone.unknown,
  color: null,
);

/// 값 + 증감 '—'(지난 스냅샷 대비로 비교할 수 없는 칸, 회색 '—' — 시안 Stats-Growth-Filter의 스냅샷 1회 표기).
StatisticsKpiValue _plainKpi(String value, {Color? color}) =>
    (value: value, delta: '—', tone: KpiDeltaTone.unknown, color: color);

/// 값 + 지난 스냅샷 대비 증감(FE7-h). 증감을 모르면 회색 '—', 알면 시안처럼 증가 · 감소 모두 초록이다.
StatisticsKpiValue _deltaKpi(String value, String? delta, {Color? color}) =>
    delta == null
    ? _plainKpi(value, color: color)
    : (value: value, delta: delta, tone: KpiDeltaTone.gain, color: color);

String? _signed(int? value) =>
    value == null ? null : inventorySignedCount(value);

/// 성장 KPI 5칸(FD-105 · 시안 Stats-Growth 라벨 순서): 보유 학생 · 평균 육성도 · 최대 레벨 · 완전 육성 · 계획 등록.
/// 증감은 지난 학생 스냅샷 대비(FE7-h, [deltas])다. 학생 스냅샷이 2회 미만이면 '—'(시안 Stats-Growth-Filter, 회색).
/// 보유 학생 칸은 "/ 학생 목록 수 · 증감"이다. 계획 등록은 목표 이력이 없어(FB-2는 학생 · 인벤토리만 남긴다) 늘 '—'다.
/// 자료를 못 읽었으면 값도 '—'다.
List<StatisticsKpiValue> statisticsGrowthKpis(
  StatisticsGrowth? growth, [
  StatisticsGrowthDeltas deltas = StatisticsGrowthDeltas.unknown,
]) {
  if (growth == null) return List.filled(5, _unknownKpi);
  String count(int? value) => value == null ? '—' : '$value명';
  final average = growth.averageGrowth;
  final tenths = deltas.averageTenths;
  return [
    (
      value: '${growth.ownedCount}',
      delta: '/ ${growth.catalogCount ?? '—'} · ${_signed(deltas.owned) ?? '—'}',
      tone: KpiDeltaTone.gain,
      color: null,
    ),
    _deltaKpi(
      average == null ? '—' : statisticsPercentText(average, decimals: 1),
      tenths == null ? null : statisticsSignedTenths(tenths),
    ),
    _deltaKpi(count(growth.maxLevelCount), _signed(deltas.maxLevel)),
    _deltaKpi(count(growth.fullGrowthCount), _signed(deltas.fullGrowth)),
    _plainKpi(count(growth.plannedCount)),
  ];
}

String _kinds(int? value) => value == null ? '—' : '$value종';

/// 인벤토리 KPI 5칸(FD-105 · 시안 Stats-Inventory 라벨 순서): 전체 충족률(FD-031) · 부족 재화(분홍) · 과잉 재화(FD-040) ·
/// 충족 카테고리(B1 60% 기준 이상 / B1 카테고리 수) · 스캔 없음(회색, 증감 자리에 모르는 카테고리 이름).
/// 증감은 재화별 지난 스캔 대비(FE7-h, [deltas], FE6-f 규칙)이고 모르면 '—'다. 스캔 없음 칸의 증감 자리는 카테고리 이름이다.
/// 부족 계산이 없으면(목표 없음 · 읽는 중 · 실패) 모두 '—'다.
List<StatisticsKpiValue> statisticsInventoryKpis(
  StatisticsSupply? supply, [
  StatisticsSupplyDeltas deltas = StatisticsSupplyDeltas.unknown,
]) {
  if (supply == null) return List.filled(5, _unknownKpi);
  final kpis = supply.kpis;
  final labels = supply.unknownLabels;
  return [
    _deltaKpi(statisticsFillText(kpis.fulfillment), _signed(deltas.fulfillment)),
    _deltaKpi(
      _kinds(kpis.shortageKinds),
      _signed(deltas.shortageKinds),
      color: AppColors.accent,
    ),
    _deltaKpi(_kinds(kpis.excessKinds), _signed(deltas.excessKinds)),
    _deltaKpi(
      '${supply.metCategoryCount} / ${supply.categories.length}',
      _signed(deltas.metCategories),
    ),
    (
      value: _kinds(kpis.unknownKinds),
      delta: switch (labels.length) {
        0 => null,
        1 => labels.single,
        _ => '${labels.first} 외 ${labels.length - 1}',
      },
      tone: KpiDeltaTone.unknown,
      color: AppColors.textMuted,
    ),
  ];
}

/// 계획 KPI 5칸(FD-105 · 시안 Stats-Plan 라벨 순서): 계획 충족률(FD-031) · 부족 재화(분홍) · 첫 부족 · 막힌 학생 ·
/// 미계획 · 40% 미만. 첫 부족 · 막힌 학생은 활성 문서 계산([planning], FE7-g)에서 온다:
/// - 첫 부족 = 분홍 "Pn" + 증감 자리에 그 재화 이름(시안 `P2` · `기술 노트`, 계획 색). 모자라는 재화가 없으면 "없음"
///   (계획 Detail과 같은 글자), 문서 계산이 없으면 '—'.
/// - 막힌 학생 = 문서 계산 단계 학생 m − 끝까지 가는 학생 n(FD-034 (a)). 증감은 '—'다: 지난 스냅샷 시점 문서 계산이 없다.
/// 계획 충족률 · 부족 재화 증감은 인벤토리 주제와 같은 값([deltas], FE7-h)이다. 미계획 학생은 목표 이력이 없어 '—'다.
/// [unplannedLow]는 보유 · 목표 없음 · 육성도 40% 미만 학생 수(성장 자료가 없으면 null).
List<StatisticsKpiValue> statisticsPlanKpis(
  StatisticsSupply? supply, {
  required int? unplannedLow,
  StatisticsPlanning? planning,
  StatisticsSupplyDeltas deltas = StatisticsSupplyDeltas.unknown,
}) {
  final first = planning?.firstShortage;
  final phase = planning?.firstShortagePhase;
  final blocked = planning?.blockedStudents;
  return [
    supply == null
        ? _unknownKpi
        : _deltaKpi(
            statisticsFillText(supply.kpis.fulfillment),
            _signed(deltas.fulfillment),
          ),
    supply == null
        ? _unknownKpi
        : _deltaKpi(
            _kinds(supply.kpis.shortageKinds),
            _signed(deltas.shortageKinds),
            color: AppColors.accent,
          ),
    first != null
        ? (
            value: 'P${first.phase}',
            delta: first.tile.name,
            tone: KpiDeltaTone.plan,
            color: AppColors.accent,
          )
        : _plainKpi(planScenarioBottleneckValue(phase)),
    _plainKpi(blocked == null ? '—' : '$blocked명'),
    unplannedLow == null ? _unknownKpi : _plainKpi('$unplannedLow명'),
  ];
}

/// 인벤토리 · 계획 그래프 타일의 빈 상태 문구. 그릴 자료가 있으면 null(타일별 빈 상태는 타일이 더 정한다).
String? statisticsSupplyEmptyText(
  StatisticsSourceData data,
  StatisticsSupplyView view,
) {
  if (data.loading || view.loading) return '—';
  final state = data.state;
  if (state != null && state.goals.isEmpty) return statisticsSupplyNoPlanText;
  final supply = view.supply;
  if (supply == null) return '—';
  if (supply.planned.isEmpty) return statisticsSupplyNoNeedsText;
  return null;
}

/// 타일 줄 높이(기준 viewport). 줄에 짧은 높이가 있고(FD-109) 줄의 타일이 모두 그래프 없이 빈 상태 · "준비 중"이면 그
/// 높이다. 지금 그런 줄은 A4 · A6뿐이다: A4는 "준비 중"(FE7-f 전), A6은 스냅샷 2회 미만 문구일 때(시안 Stats-Growth-Filter).
double statisticsRowHeight(StatisticsTileRow row, StatisticsHistoryView history) {
  final short = row.shortHeight;
  if (short == null) return row.height;
  final empty = row.tiles.every(
    (tile) => tile.id == 'A6'
        ? history.growthTrendShort
        : !_chartTileIds.contains(tile.id),
  );
  return empty ? short : row.height;
}

/// 그래프를 그리는 타일(나머지는 "준비 중").
const _chartTileIds = {'A1', 'A2', 'A6', 'B1', 'B3', 'C1', 'C2', 'C3'};

/// KPI 띠: 다섯 칸. [onPressed]가 있으면 칸을 누를 수 있다(누른 칸 순번).
class _KpiBand extends StatelessWidget {
  const _KpiBand({required this.mode, this.values, this.onPressed});

  final StatisticsMode mode;
  final List<StatisticsKpiValue>? values;
  final ValueChanged<int>? onPressed;

  @override
  Widget build(BuildContext context) {
    final labels = mode.kpiLabels;
    final values = this.values;
    final onPressed = this.onPressed;
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
                  child: _KpiCell(
                    key: ValueKey('statistics-kpi-${mode.key}-$index'),
                    label: label,
                    value: values?[index],
                    onPressed: onPressed == null
                        ? null
                        : () => onPressed(index),
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

class _KpiCell extends StatelessWidget {
  const _KpiCell({
    super.key,
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final StatisticsKpiValue? value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    final tile = KpiTile(
      label: label,
      value: value?.value ?? '—',
      delta: value?.delta,
      deltaTone: value?.tone ?? KpiDeltaTone.unknown,
      valueColor: value?.color ?? AppColors.text,
    );
    final onPressed = this.onPressed;
    if (onPressed == null) return tile;
    return KitPressable(
      onPressed: onPressed,
      semanticLabel: '$label ${value?.value ?? '—'}',
      builder: (context, state) => tile,
    );
  }
}

/// 위젯 타일 한 줄. 타일 자리는 [statisticsTileSlots]다.
class _TileRow extends StatelessWidget {
  const _TileRow({
    required this.row,
    required this.height,
    required this.history,
    this.growth,
    this.supply,
    this.supplyEmpty,
  });

  final StatisticsTileRow row;
  final double height;
  final StatisticsHistoryView history;

  /// 학생 성장 주제일 때만 있다.
  final StatisticsGrowthView? growth;

  /// 인벤토리 · 계획 주제일 때만 있다. [supplyEmpty]는 그래프 타일 공통 빈 상태 문구(그릴 수 있으면 null).
  final StatisticsSupplyView? supply;
  final String? supplyEmpty;

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
                history: history,
                growth: growth,
                supply: supply,
                supplyEmpty: supplyEmpty,
              ),
            ),
        ],
      );
    },
  );
}

/// 위젯 타일(키트 [WidgetTile]): 머리(ID · 제목 · seg · 차수 칩) + 내용. 학생 성장의 A1 · A2(FE7-b) · A6(FE7-h), 인벤토리의
/// B1(FE7-c) · B3(FE7-h), 계획의 C1 · C2(FE7-c) · C3(FE7-g)는 그래프, 나머지는 "준비 중"이다.
class _StatisticsTile extends StatelessWidget {
  const _StatisticsTile({
    super.key,
    required this.tile,
    required this.height,
    required this.history,
    this.growth,
    this.supply,
    this.supplyEmpty,
  });

  final StatisticsTileSpec tile;
  final double height;

  /// 이력(A6 · B3, FE7-h).
  final StatisticsHistoryView history;

  /// 학생 성장 주제일 때만 있다.
  final StatisticsGrowthView? growth;

  /// 인벤토리 · 계획 주제일 때만 있다.
  final StatisticsSupplyView? supply;
  final String? supplyEmpty;

  bool get _isGrowthChart => tile.id == 'A1' || tile.id == 'A2';
  bool get _isSupplyChart =>
      tile.id == 'B1' || tile.id == 'C1' || tile.id == 'C2' || tile.id == 'C3';

  @override
  Widget build(BuildContext context) {
    final side =
        diagonalCutDepth(height) +
        StatisticsMetrics.tileSideInset +
        StatisticsMetrics.tilePadding;
    final growth = this.growth;
    final supply = this.supply;
    final onMetricChanged = growth?.onMetricChanged;
    // A1 seg(육성도 · 레벨 · 스킬 · 장비)는 보유 학생이 있을 때 동작한다.
    final metricSeg =
        tile.id == 'A1' &&
        growth != null &&
        (growth.growth?.ownedCount ?? 0) > 0;
    // C1 seg: "부족 큰 순"은 부족 계산이 있으면, "페이즈 순"은 활성 문서 계산(FE7-g)도 있으면 동작한다.
    final orderSeg = tile.id == 'C1' && supply?.supply != null;
    final phaseOrder = orderSeg && supply?.planning != null;
    final onC1OrderChanged = supply?.onC1OrderChanged;
    // B3 seg(스냅샷 6회 · 4주 · 전체, FD-110)는 이력을 읽었을 때 동작한다.
    final onB3RangeChanged = history.onB3RangeChanged;
    final rangeSeg =
        tile.id == 'B3' &&
        supply != null &&
        history.resourceTrends != null &&
        onB3RangeChanged != null;
    final Widget body;
    if (growth != null && tile.id == 'A6') {
      body = _a6Body();
    } else if (supply != null && tile.id == 'B3') {
      body = _b3Body();
    } else if (growth != null && _isGrowthChart) {
      body = _growthBody(growth);
    } else if (supply != null && _isSupplyChart) {
      body = _supplyBody(supply);
    } else {
      body = const Center(
        child: Text(statisticsTilePendingText, maxLines: 1, style: _mutedStyle),
      );
    }
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
            _TileHeader(
              tile: tile,
              selectedSegment: metricSeg
                  ? growth.metric.index
                  : orderSeg
                  ? supply!.effectiveC1Order.index
                  : rangeSeg
                  ? history.b3Range.index
                  : 0,
              onSegmentChanged: metricSeg && onMetricChanged != null
                  ? (index) =>
                        onMetricChanged(StatisticsGrowthMetric.values[index])
                  : orderSeg
                  ? (index) =>
                        onC1OrderChanged?.call(StatisticsC1Order.values[index])
                  : rangeSeg
                  ? (index) => onB3RangeChanged(StatisticsB3Range.values[index])
                  : null,
              disabledSegments: orderSeg && !phaseOrder ? const {1} : const {},
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  /// 빈 상태 문구(타일 가운데, 두 줄까지).
  Widget _empty(String text) => Center(
    child: Text(
      text,
      key: ValueKey('statistics-tile-${tile.id}-empty'),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: _mutedStyle,
    ),
  );

  /// 시안: 머리와 그래프 사이 10, 그래프는 남는 자리의 세로 가운데 · 왼쪽.
  Widget _chart(Widget chart) => Padding(
    padding: const EdgeInsets.only(top: StatisticsMetrics.tileChartGap),
    child: chart,
  );

  /// 스냅샷 2회 미만(확정 4 · FD-106): 그래프 자리를 채운 둥근 상자.
  Widget _short(String note) => _chart(
    StatisticsHistoryShortState(
      key: ValueKey('statistics-tile-${tile.id}-short'),
      note: note,
    ),
  );

  /// A6 내용(FE7-h). 읽는 중 · 성장 자료 없음 '—', 읽기 실패는 그 글자, 학생 스냅샷 2회 미만은 확정 4 문구다.
  Widget _a6Body() {
    final error = history.error;
    if (error != null) return _empty(error);
    final trend = history.growthTrend;
    if (history.loading || trend == null || growth?.growth == null) {
      return _empty('—');
    }
    if (!trend.drawable) return _short(trend.note);
    return _chart(StatisticsGrowthTrendChart(trend: trend));
  }

  /// B3 내용(FE7-h). 계획이 없어도 재화(크레딧 · 엘리그마) 변화는 그린다. 아는 수량 점이 2개 이상인 재화가 없으면 확정 4
  /// 문구다.
  Widget _b3Body() {
    final error = history.error;
    if (error != null) return _empty(error);
    final trends = history.resourceTrends;
    if (history.loading || trends == null) return _empty('—');
    if (!trends.drawable) return _short(trends.note);
    return _chart(StatisticsResourceTrendChart(trends: trends));
  }

  /// A1 · A2 내용. 자료가 없으면 '—', 보유 학생 0이나 값을 아는 학생 0이면 빈 상태 문구다(FD-106 · 시안식).
  Widget _growthBody(StatisticsGrowthView view) {
    final data = view.growth;
    final String? empty;
    if (data == null) {
      empty = '—';
    } else if (data.ownedCount == 0) {
      empty = statisticsGrowthNoStudentsText;
    } else if (tile.id == 'A1' && data.histogram(view.metric).knownCount == 0) {
      empty = statisticsGrowthNoKnownText(view.metric.label, data.ownedCount);
    } else if (tile.id == 'A2' && data.known.isEmpty) {
      empty = statisticsGrowthNoKnownText(
        StatisticsGrowthMetric.growth.label,
        data.ownedCount,
      );
    } else {
      empty = null;
    }
    if (data == null || empty != null) return _empty(empty ?? '—');
    final selection = view.selection;
    final onSelectionChanged = view.onSelectionChanged;
    if (tile.id == 'A1') {
      final metric = view.metric;
      return _chart(
        StatisticsGrowthHistogramChart(
          histogram: data.histogram(metric),
          selectedBin: switch (selection) {
            StatisticsGrowthBinSelection(metric: final selected, :final bin)
                when selected == metric =>
              bin,
            _ => null,
          },
          onBinSelected: (bin) => onSelectionChanged?.call(
            bin == null ? null : StatisticsGrowthBinSelection(metric, bin),
          ),
        ),
      );
    }
    return _chart(
      StatisticsItemCompletionChart(
        averages: data.itemAverages,
        emphasized: data.emphasizedItems,
        unknownCount: data.unknownCount,
        selectedItem: switch (selection) {
          StatisticsGrowthItemSelection(:final item) => item,
          _ => null,
        },
        onItemSelected: (item) => onSelectionChanged?.call(
          item == null ? null : StatisticsGrowthItemSelection(item),
        ),
      ),
    );
  }

  Widget _c3Body(StatisticsSupplyView view) => _c3BodyFor(view, _empty, _chart);

  /// B1 · C1 · C2 내용(FE7-c). 계획이 없거나 계획 재화가 없으면 빈 상태 문구, 읽는 중 · 계산 실패면 '—'다(FD-106).
  Widget _supplyBody(StatisticsSupplyView view) {
    final data = view.supply;
    final common = supplyEmpty;
    if (data == null || common != null) return _empty(common ?? '—');
    final onSelectionChanged = view.onSelectionChanged;
    switch (tile.id) {
      case 'B1':
        if (data.categories.isEmpty) {
          return _empty(statisticsSupplyNoCategoriesText);
        }
        return _chart(
          StatisticsCategoryFillChart(
            categories: data.categories,
            selectedCategory: view.selectedCategory,
            onCategorySelected: (category) => onSelectionChanged?.call(
              category == null ? null : StatisticsCategorySelection(category),
            ),
          ),
        );
      case 'C1':
        return _chart(
          StatisticsBulletChart(
            rows: view.c1Rows,
            selectedKey: view.selectedResource(StatisticsResourceSource.c1),
            onResourceSelected: (key) => onSelectionChanged?.call(
              key == null
                  ? null
                  : StatisticsResourceSelection(
                      key,
                      StatisticsResourceSource.c1,
                    ),
            ),
          ),
        );
      case 'C3':
        return _c3Body(view);
      default:
        final points = data.c2Points;
        if (points.isEmpty) return _empty(statisticsSupplyNoKnownText);
        return _chart(
          StatisticsBottleneckChart(
            points: points,
            maxStudents: data.c2MaxStudents,
            unknownKinds: data.planned.length - points.length,
            selectedKey: view.selectedResource(StatisticsResourceSource.c2),
            onResourceSelected: (key) => onSelectionChanged?.call(
              key == null
                  ? null
                  : StatisticsResourceSelection(
                      key,
                      StatisticsResourceSource.c2,
                    ),
            ),
          ),
        );
    }
  }
}

/// C3 내용(FE7-g). 활성 문서 계산이 없으면 '—'(읽기 오류면 그 글자), 보유를 아는 재화가 없거나 끝까지 모자라는 재화가
/// 없으면 빈 상태 문구다.
Widget _c3BodyFor(
  StatisticsSupplyView view,
  Widget Function(String text) empty,
  Widget Function(Widget chart) chart,
) {
  final planning = view.planning;
  if (planning == null || !planning.phasesCalculated) {
    return empty(view.planningError ?? '—');
  }
  if (planning.knownResources == 0) return empty(statisticsSupplyNoKnownText);
  final lines = planning.c3Lines;
  if (lines.isEmpty) return empty(statisticsPlanNoShortageText);
  return chart(
    StatisticsCumulativeShortageChart(
      lines: lines,
      phases: planning.phaseNumbers,
    ),
  );
}

/// 타일 머리(시안 `.dsp` 16px 제목 줄 + 그라데이션 룰). 키트 [TileTitle]은 글자 하나만 받으므로 같은 조각
/// ([TitleBar] 6×18 · 간격 8 · [TitleRule] 캡 40 · 줄 사이 7)으로 ID(13px [AppColors.textMuted], 오른쪽 8)와
/// 제목(16px 흰색)을 나눠 그린다. 오른쪽은 시안 머리 그대로 seg 자리(비활성, 높이 26 · 글자 11 · 안쪽 16 · 간격 6)와
/// 차수 칩(1차 핑크 · 2차 기본 · 3차 회색)이다. 좁으면 오른쪽 묶음을 줄인다.
class _TileHeader extends StatelessWidget {
  const _TileHeader({
    required this.tile,
    this.selectedSegment = 0,
    this.onSegmentChanged,
    this.disabledSegments = const {},
  });

  final StatisticsTileSpec tile;

  /// seg 선택 칸과 바꾸는 콜백. 콜백이 없으면 비활성 자리다(A1은 성장 자료가 있을 때 동작, FE7-b).
  final int selectedSegment;
  final ValueChanged<int>? onSegmentChanged;

  /// 콜백이 있어도 누를 수 없는 칸(C1 "페이즈 순", FE7-c).
  final Set<int> disabledSegments;

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
              SkewSegment(
                value: index,
                label: label,
                enabled: !disabledSegments.contains(index),
              ),
          ],
          selected: selectedSegment,
          onChanged: onSegmentChanged,
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
    required this.growth,
    required this.supply,
    required this.actions,
  });

  final Size size;
  final StatisticsMode mode;
  final StatisticsSourceData data;
  final StatisticsGrowthView growth;
  final StatisticsSupplyView supply;
  final (StatisticsEvidenceAction, StatisticsEvidenceAction) actions;

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
    final noteLeft = topLeft.dx + StatisticsMetrics.evidenceNoteLeftInset;
    final notice = data.notice;
    // 학생 성장에서 구간 · 항목을 고르면 머리 · 부제 · 근거 목록(FE7-b), 인벤토리 · 계획에서 막대 · 행 · 점을 고르면 재화 ·
    // 학생 근거(FE7-c). 읽기 상태 안내가 있으면 안내가 먼저다.
    final growthEvidence = mode == StatisticsMode.students && notice == null
        ? growth.evidence
        : null;
    final supplyEvidence = mode != StatisticsMode.students && notice == null
        ? supply.evidence
        : null;
    final String? title;
    final (String, AppTone)? chip;
    final String? subtitle;
    if (growthEvidence != null) {
      title = growthEvidence.title;
      chip = ('${growthEvidence.students.length}명', AppTones.pink);
      subtitle = growthEvidence.subtitle;
    } else if (supplyEvidence != null) {
      title = supplyEvidence.title;
      chip = supplyEvidence.chip;
      subtitle = supplyEvidence.subtitleInHeader
          ? null
          : supplyEvidence.subtitle;
    } else {
      title = null;
      chip = null;
      subtitle = null;
    }
    final emptyText = switch (mode) {
      StatisticsMode.students => statisticsEvidenceEmptyText,
      StatisticsMode.inventory => statisticsInventoryEvidenceEmptyText,
      StatisticsMode.plan => statisticsPlanEvidenceEmptyText,
    };
    final showNote = supplyEvidence == null || subtitle != null;
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

    final frame = StatisticsEvidenceFrame(
      topLeft: topLeft,
      bottomLeft: bottomLeft,
      right: right,
      scale: scale,
    );
    final (secondary, primary) = actions;
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: title == null || chip == null
                  ? const PanelTitle(
                      '근거 확인',
                      key: ValueKey('statistics-evidence-title'),
                    )
                  : _MinBox(
                      minWidth: _evidenceTitleMinWidth,
                      minHeight: StatisticsMetrics.evidenceTitleHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: PanelTitle(
                          title,
                          key: const ValueKey('statistics-evidence-title'),
                          trailing: BaChip(
                            key: const ValueKey('statistics-evidence-count'),
                            label: chip.$1,
                            tone: chip.$2,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        if (showNote)
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
                notice ?? subtitle ?? emptyText,
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
        if (growthEvidence != null)
          ...statisticsGrowthEvidenceChildren(
            frame: frame,
            content: growthEvidence,
            expanded: growth.expanded,
            onExpand: growth.onExpand,
          ),
        if (supplyEvidence != null)
          ...statisticsSupplyEvidenceChildren(
            frame: frame,
            content: supplyEvidence,
            expanded: supply.expanded,
            onExpand: supply.onExpand,
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

// 근거 패널 아래 이동 버튼. 시안 모양은 왼쪽 변 80° · 오른쪽 변 수직이라 키트 [RailButton]을 좌우로 뒤집어
/// 바탕만 쓰고, 글자는 뒤집지 않고 위에 올린다. [StatisticsEvidenceAction.onPressed]가 없으면 비활성(FE7-a 모양 그대로),
/// 있으면 누를 수 있고 글자를 흐리게 하지 않는다(FE7-d). 누르기 · hover는 바탕 키트 버튼이 받는다.
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
    final enabled = action.onPressed != null;
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
            onPressed: action.onPressed,
            child: const SizedBox.shrink(),
          ),
        ),
        IgnorePointer(
          child: ExcludeSemantics(
            child: Opacity(
              opacity: enabled ? 1 : kitDisabledOpacity,
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
