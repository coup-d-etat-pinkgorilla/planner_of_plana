// 계획 Detail 3섹션(FE5-c1, 시안 Scenario-Detail-Bottleneck, D 보고서 §2, FD-082 (a)).
//
// [PlanDetailWorkspace]는 S1 메뉴 · S2 페이즈 · S3 재화 3섹션을 그린다. 시나리오 보기 모드가 먼저 쓰고, FE5-c2의
// 활성 계획 홈이 같은 위젯을 쓴다(비교 KPI · delta 칩은 [PlanDetailWorkspace.showComparison]으로 끈다). S1 내용은
// 화면마다 다르므로 [PlanDetailWorkspace.menuBuilder]가 [PlanDetailMenuFrame] 자리에 채운다.
// - S2: 제목 줄(페이즈 n개 · 단계 n + "활성 계획과 다른 단계 n"), 패널 안 사선 목록. 페이즈 헤더(44px, 번호 · 이름 ·
//   단계 수 · 부족 n종/충분)와 단계 행(70px, 초상 · 이름 · 단계 · 상태 칩 "병목 n · 여기서 막힘"/"앞 단계 대기"(FD-035) ·
//   목표 요약 · 활성 대비 칩(FD-039)). 고른 병목 카드의 단계 행은 분홍 테두리다.
// - S3: 맨 위 한 줄 = seg 병목/페이즈별/전체 + 칩 3개, 요약 행(가장 심한 병목), "활성 계획 대비" + KPI 4칸(필요 크레딧 ·
//   부족 재화 · 첫 병목 · 끝까지 가는 학생, FD-034 (a)), 본문 패널 = 병목 카드(214px, 같은 단계 재화 묶음 · 지연 단계).
//   페이즈별 · 전체 탭: [PlanDetailWorkspace.onResourceTab]을 넘기면 seg가 켜지고 그 탭 본문은
//   [PlanDetailWorkspace.tabBody](활성 계획 홈은 기존 계획 홈의 페이즈별 · 전체 위젯, FE5-c2)가 채운다. 넘기지 않으면
//   (시나리오 보기, FE5-c1) seg 자리만 두고 꺼 둔다. 칩 3개는 [PlanDetailWorkspace.toolbarChips]로 바꿀 수 있다
//   (기본은 자리 · 상태 표시만). 시안대로 다시 그리는 것은 FE5-d다.
// 좌표는 시안(기준 viewport, 섹션 위 y=209.2)의 값이고, 섹션 rect는 Studio 문서([planDetailStudioDocument])를 따른다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_row.dart';
import '../kit/diagonal_scroll_viewport.dart';
import '../kit/item_icon_tile.dart';
import '../kit/portrait_strip.dart';
import '../kit/scroll_viewport_fog.dart';
import '../kit/skew_box.dart';
import '../kit/skew_controls.dart';
import '../kit/titles.dart';
import '../models/plan_scenario_detail.dart';
import '../models/plan_scenario_preview.dart';
import '../models/planning_resource_assets.dart';
import '../studio/plan_scenario_detail_studio_layout.dart';
import 'growth_calculator_section.dart' show growthCalculatorCompactNumber;
import 'plan_scenario_preview.dart';
import 'plan_section_layout.dart' show PlanSectionMotion;
import 'section_surface.dart';
import 'section_template_surface.dart';

/// 섹션 모션(부착면 규칙 FD-078): S1 0/180(왼쪽), S2 80/260(아래), S3 180/0(오른쪽). 시나리오 목록과 같다.
const planDetailMenuMotion = (intro: 0.0, outro: 180.0);
const planDetailPhaseMotion = (intro: 80.0, outro: 260.0);
const planDetailResourceMotion = (intro: 180.0, outro: 0.0);

/// S3 맨 위 seg. 페이즈별 · 전체는 FE5-d에서 연다.
enum PlanDetailResourceTab { bottleneck, byPhase, overall }

/// 시안 값(섹션 위 y=209.2 기준).
abstract final class PlanDetailMetrics {
  // S1 메뉴: 왼쪽 안쪽 14, 레일 여백 22(시나리오 목록 S1과 같다).
  static const menuLeft = 14.0;
  static const menuRightMargin = 22.0;
  static const menuTitleTop = 22.0;
  static const menuCaptionTop = 72.0;
  static const menuCurrentTop = 96.0;
  static const menuCurrentHeight = 58.0;
  static const menuActionTops = [166.0, 228.0, 280.0, 332.0, 384.0];
  static const menuActionHeight = 44.0;
  static const menuInfoCaptionTop = 454.0;
  static const menuInfoTop = 480.0;
  static const menuInfoPitch = 40.0;
  static const menuInfoHeight = 36.0;

  // S2 페이즈.
  static const phaseTitleTop = 18.0;
  static const phaseTitleHeight = 36.0;
  static const phaseTitleLeft = 33.0;
  static const phaseTitleRight = 36.0;
  static const phasePanelTop = 72.0;
  static const phasePanelInset = 12.0;
  static const phasePanelRight = 24.0;
  static const phaseHeaderHeight = 44.0;
  static const stageHeight = 70.0;
  static const stageGap = 8.0;

  /// 페이즈 사이 추가 간격(시안: 마지막 단계 행 → 다음 헤더 20 = 8 + 12).
  static const phaseGap = 12.0;

  /// 단계 행이 헤더보다 들어가는 폭(시안 431.3 − 423.1 + 레일 이동 13.75).
  static const stageIndent = 22.0;
  static const listTop = 14.0;
  static const listInset = 18.0;
  static const listScrollbarReserve = 10.0;

  // S3 재화.
  static const resourceRight = 22.0;
  static const toolbarTop = 18.0;
  static const toolbarHeight = 40.0;
  static const toolbarLeft = 17.0;
  static const summaryTop = 70.0;
  static const summaryHeight = 70.0;
  static const rowInset = 24.0;
  static const compareCaptionTop = 152.0;
  static const compareCaptionHeight = 24.0;
  static const kpiTop = 182.0;
  static const kpiHeight = 64.0;
  static const kpiGap = 8.0;

  /// 본문 패널 위(비교 KPI가 있을 때 · 없을 때).
  static const bodyTop = 262.0;
  static const bodyTopWithoutComparison = 152.0;
  static const bodyInset = 12.0;
  static const cardHeight = 214.0;
  static const cardGap = 12.0;
}

const _muted = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  height: 1.3,
  fontWeight: AppType.medium,
  color: AppColors.textMuted,
);

const _bold = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.titleSmallSize,
  height: 1.25,
  fontWeight: AppType.bold,
  color: AppColors.text,
);

const _captionStyle = TextStyle(
  fontFamily: AppFonts.display,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  height: 1.2,
  color: AppColors.textMuted,
);

/// 패널 색(시안 rgba(26,44,59,.9), 테두리 rgba(56,81,107,.72)). 시나리오 목록 패널과 같다.
const _panelFill = Color.fromRGBO(26, 44, 59, 0.9);
const _panelBorder = Color.fromRGBO(56, 81, 107, 0.72);

/// 페이즈 헤더 바탕(시안 `.plain` rgba(16,24,35,.5)).
const _phaseHeaderFill = Color.fromRGBO(16, 24, 35, 0.5);

/// 병목 카드 재화 타일 바탕(시안 rgba(16,24,35,.55)).
const _tileFill = Color.fromRGBO(16, 24, 35, 0.55);

/// [id] 섹션의 둥글리기 전 꼭짓점(콘텐츠 캔버스 좌표).
List<Offset> planDetailSectionPolygon(Size size, String id) {
  final section = planDetailSection(id);
  final rect = sectionCanvasElementRect(size, section);
  return [
    for (final point in buildAttachedSectionPolygon(rect.size, section.spec))
      point + rect.topLeft,
  ];
}

/// 두 점을 잇는 변 위 [y]에서의 x.
double _edgeX(Offset top, Offset bottom, double y) {
  final span = bottom.dy - top.dy;
  if (span <= 0) return top.dx;
  final progress = ((y - top.dy) / span).clamp(0.0, 1.0).toDouble();
  return top.dx + (bottom.dx - top.dx) * progress;
}

/// 수량(만 이상은 줄임). 미리보기와 같다.
String _amount(int? value) =>
    value == null ? '—' : planScenarioPreviewAmount(value);

/// S1 메뉴 자리. [row]는 시안 S1 버튼처럼 왼쪽 14에서 오른쪽 변 − 22까지다.
@immutable
class PlanDetailMenuFrame {
  const PlanDetailMenuFrame({
    required this.top,
    required this.topRight,
    required this.bottomRight,
  });

  /// 섹션 위(콘텐츠 캔버스 y).
  final double top;
  final Offset topRight;
  final Offset bottomRight;

  /// [y] 높이에서 버튼이 쓸 수 있는 폭.
  double width(double y) => math.max(
    0.0,
    _edgeX(topRight, bottomRight, y) -
        PlanDetailMetrics.menuLeft -
        PlanDetailMetrics.menuRightMargin,
  );

  /// 섹션 위에서 [offset] 아래, 높이 [height]인 버튼 자리.
  Rect row(double offset, double height) => Rect.fromLTWH(
    PlanDetailMetrics.menuLeft,
    top + offset,
    width(top + offset),
    height,
  );
}

/// S1 메뉴 섹션 한 장(표면 + [builder] 내용). [PlanDetailWorkspace]가 쓰고, 활성 계획 홈에서 연 A↔B 비교 화면도
/// 같은 자리에 메뉴만 둘 때 쓴다(FE5-c2).
class PlanDetailMenuLayer extends StatelessWidget {
  const PlanDetailMenuLayer({
    super.key,
    required this.keyPrefix,
    required this.size,
    required this.builder,
  });

  final String keyPrefix;

  /// 콘텐츠 캔버스 크기.
  final Size size;
  final Widget Function(PlanDetailMenuFrame frame) builder;

  @override
  Widget build(BuildContext context) {
    final points = planDetailSectionPolygon(size, planDetailMenuSectionId);
    final frame = PlanDetailMenuFrame(
      top: points.first.dy,
      topRight: points[1],
      bottomRight: points[2],
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: ValueKey('$keyPrefix-menu-surface'),
              painter: const _DetailSectionPainter(planDetailMenuSectionId),
            ),
          ),
        ),
        Positioned.fill(child: builder(frame)),
      ],
    );
  }
}

/// 계획 Detail 3섹션. [animation]은 계획 화면의 목록 모션이다.
///
/// FE5-c2가 쓸 매개변수: [keyPrefix](키 앞부분), [menuBuilder](S1 내용), [showComparison](false면 S2 활성 대비 칩 ·
/// "활성 계획과 다른 단계" · S3 "활성 계획 대비" 줄 · KPI 줄을 그리지 않고 본문 패널이 요약 행 아래
/// ([PlanDetailMetrics.bodyTopWithoutComparison])부터 시작한다), [selectedCard] · [onSelectCard](카드 ↔ 단계 행 강조),
/// [shortageKpi](부족 재화 KPI 칸 팝오버, 비교가 있을 때만). FE5-c2부터: [resourceTab] · [onResourceTab](S3 seg 세 탭),
/// [tabBody] · [tabSummary](페이즈별 · 전체 탭의 본문 · 요약 행), [toolbarChips](칩 3개 자리), [resourcePlaceholder]
/// (재화를 그릴 수 없을 때 S3 안내, 예: 계산 중 · 계산할 수 없음).
class PlanDetailWorkspace extends StatelessWidget {
  const PlanDetailWorkspace({
    super.key,
    required this.keyPrefix,
    required this.animation,
    required this.data,
    required this.studentName,
    required this.menuBuilder,
    this.showComparison = true,
    this.selectedCard,
    this.onSelectCard,
    this.shortageKpi,
    this.placeholder,
    this.resourceTab = PlanDetailResourceTab.bottleneck,
    this.onResourceTab,
    this.tabBody,
    this.tabSummary,
    this.toolbarChips,
    this.resourcePlaceholder,
  });

  final String keyPrefix;
  final Animation<double> animation;

  /// 그릴 내용. null이면 S2 · S3에 [placeholder]를 보인다.
  final PlanDetailData? data;
  final String Function(String studentId) studentName;
  final Widget Function(PlanDetailMenuFrame frame) menuBuilder;
  final bool showComparison;

  /// 고른 병목 카드(0부터). null이면 고르지 않음.
  final int? selectedCard;
  final ValueChanged<int>? onSelectCard;

  /// 부족 재화 KPI 칸을 감싼다(팝오버).
  final Widget Function(Widget tile)? shortageKpi;
  final Widget? placeholder;

  /// S3 seg의 지금 탭.
  final PlanDetailResourceTab resourceTab;

  /// seg를 바꾼다. null이면 병목만 켜지고 페이즈별 · 전체는 꺼진다(FE5-c1).
  final ValueChanged<PlanDetailResourceTab>? onResourceTab;

  /// 페이즈별 · 전체 탭 본문. [bodyPath]는 S3 본문 패널 자리(콘텐츠 캔버스 좌표)다.
  final Widget Function(PlanDetailResourceTab tab, Path bodyPath)? tabBody;

  /// 페이즈별 · 전체 탭의 요약 행 내용.
  final Widget Function(PlanDetailResourceTab tab)? tabSummary;

  /// S3 맨 위 칩 자리. null이면 표시만 하는 칩 3개다.
  final List<Widget>? toolbarChips;

  /// 재화를 그릴 수 없을 때(계산 중 · 계산 오류 · 계산할 수 없음) S3 본문 안내. 있으면 요약 행 · 본문 대신 보인다.
  final Widget? resourcePlaceholder;

  bool get _otherTab =>
      resourceTab != PlanDetailResourceTab.bottleneck &&
      onResourceTab != null &&
      tabBody != null;

  bool get _comparing => showComparison && (data?.hasComparison ?? false);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(
        constraints.maxWidth,
        constraints.maxHeight.isFinite ? constraints.maxHeight : 660,
      );
      return SizedBox.fromSize(
        key: ValueKey('$keyPrefix-workspace'),
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: PlanSectionMotion(
                key: ValueKey('$keyPrefix-resource-motion'),
                animation: animation,
                introDegrees: planDetailResourceMotion.intro,
                outroDegrees: planDetailResourceMotion.outro,
                child: _resources(size),
              ),
            ),
            Positioned.fill(
              child: PlanSectionMotion(
                key: ValueKey('$keyPrefix-phase-motion'),
                animation: animation,
                introDegrees: planDetailPhaseMotion.intro,
                outroDegrees: planDetailPhaseMotion.outro,
                child: _phases(size),
              ),
            ),
            Positioned.fill(
              child: PlanSectionMotion(
                key: ValueKey('$keyPrefix-menu-motion'),
                animation: animation,
                introDegrees: planDetailMenuMotion.intro,
                outroDegrees: planDetailMenuMotion.outro,
                child: _menu(size),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _menu(Size size) => PlanDetailMenuLayer(
    keyPrefix: keyPrefix,
    size: size,
    builder: menuBuilder,
  );

  // --- S2 페이즈 --------------------------------------------------------------

  Widget _phases(Size size) {
    final points = planDetailSectionPolygon(size, planDetailPhaseSectionId);
    final topLeft = points[0];
    final topRight = points[1];
    final bottomRight = points[2];
    final bottomLeft = points[3];
    final top = topLeft.dy;
    final bottom = bottomLeft.dy;
    double leftAt(double y) => _edgeX(topLeft, bottomLeft, y);
    double rightAt(double y) => _edgeX(topRight, bottomRight, y);
    final titleTop = top + PlanDetailMetrics.phaseTitleTop;
    final titleBottom = titleTop + PlanDetailMetrics.phaseTitleHeight;
    final panelTop = top + PlanDetailMetrics.phasePanelTop;
    final panelBottom = math.max(
      panelTop + 40,
      bottom - PlanDetailMetrics.phasePanelInset,
    );
    final panelRect = Rect.fromLTRB(
      leftAt(panelBottom) + PlanDetailMetrics.phasePanelInset,
      panelTop,
      rightAt(panelTop) - PlanDetailMetrics.phasePanelRight,
      panelBottom,
    );
    final titleLeft = leftAt(titleBottom) + PlanDetailMetrics.phaseTitleLeft;
    final data = this.data;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: ValueKey('$keyPrefix-phase-surface'),
              painter: const _DetailSectionPainter(planDetailPhaseSectionId),
            ),
          ),
        ),
        Positioned(
          left: titleLeft,
          top: titleTop,
          width: math.max(
            0.0,
            rightAt(titleTop) - PlanDetailMetrics.phaseTitleRight - titleLeft,
          ),
          height: PlanDetailMetrics.phaseTitleHeight,
          child: _phaseTitle(data),
        ),
        Positioned.fromRect(
          rect: panelRect,
          child: CustomPaint(
            key: ValueKey('$keyPrefix-phase-panel'),
            painter: const _DetailPanelPainter(),
            child: ClipPath(
              clipper: const _ParallelogramClipper(),
              child: data == null
                  ? Center(child: placeholder ?? const SizedBox.shrink())
                  : _phaseList(data),
            ),
          ),
        ),
      ],
    );
  }

  Widget _phaseTitle(PlanDetailData? data) {
    final different = data?.differentStageCount;
    return Row(
      key: ValueKey('$keyPrefix-phase-title'),
      children: [
        const TitleBar(width: 7, height: 22),
        const SizedBox(width: 10),
        Text('페이즈', maxLines: 1, style: kitDisplayStyle(AppType.headlineSize)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            data == null ? '—' : '${data.phaseCount}개 · 단계 ${data.stageCount}',
            key: ValueKey('$keyPrefix-phase-count'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _muted.copyWith(fontSize: AppType.bodySize),
          ),
        ),
        const Spacer(),
        if (_comparing && different != null)
          BaChip(
            key: ValueKey('$keyPrefix-phase-different'),
            label: different == 0 ? '활성 계획과 같은 단계' : '활성 계획과 다른 단계 $different',
            tone: different == 0 ? AppTones.gray : AppTones.pink,
          ),
      ],
    );
  }

  Widget _phaseList(PlanDetailData data) {
    // 헤더 · 단계 행을 한 목록으로 편다.
    final items = <({PlanDetailPhase phase, PlanDetailStageRow? stage})>[
      for (final phase in data.phases) ...[
        (phase: phase, stage: null),
        for (final stage in phase.stages) (phase: phase, stage: stage),
      ],
    ];
    final selectedStage = switch (selectedCard) {
      final index? when index >= 0 && index < data.cards.length =>
        data.cards[index].stageId,
      _ => null,
    };
    return DiagonalScrollViewport(
      key: ValueKey('$keyPrefix-phase-list'),
      keyPrefix: '$keyPrefix-phase-diagonal',
      itemCount: items.length,
      itemHeight: (index) {
        final item = items[index];
        if (item.stage != null) return PlanDetailMetrics.stageHeight;
        return PlanDetailMetrics.phaseHeaderHeight +
            (index == 0 ? 0 : PlanDetailMetrics.phaseGap);
      },
      itemGap: PlanDetailMetrics.stageGap,
      verticalInset: PlanDetailMetrics.listTop,
      horizontalInset: PlanDetailMetrics.listInset,
      scrollbarReserve: PlanDetailMetrics.listScrollbarReserve,
      fog: const ScrollFogSpec.panel(color: _panelFill),
      itemBuilder: (context, index) {
        final item = items[index];
        final stage = item.stage;
        if (stage == null) {
          return Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? 0 : PlanDetailMetrics.phaseGap,
            ),
            child: _PhaseHeader(
              key: ValueKey('$keyPrefix-phase-${item.phase.number}'),
              phase: item.phase,
            ),
          );
        }
        final number = stage.bottleneckNumber;
        return Padding(
          padding: const EdgeInsets.only(left: PlanDetailMetrics.stageIndent),
          child: _StageRow(
            key: ValueKey('$keyPrefix-stage-${stage.stageId}'),
            keyPrefix: '$keyPrefix-stage-${stage.stageId}',
            stage: stage,
            name: studentName(stage.studentId),
            highlighted: stage.stageId == selectedStage,
            showDelta: _comparing,
            onTap: onSelectCard == null || number == null
                ? null
                : () {
                    // 카드 목록이 걸러졌을 수 있다(활성 계획 홈의 재화 유형 필터). 번호로 찾는다.
                    final index = data.cards.indexWhere(
                      (card) => card.number == number,
                    );
                    if (index >= 0) onSelectCard!(index);
                  },
          ),
        );
      },
    );
  }

  // --- S3 재화 ----------------------------------------------------------------

  Widget _resources(Size size) {
    final points = planDetailSectionPolygon(size, planDetailResourceSectionId);
    final topRight = points[0];
    final bottomLeft = points[2];
    final topLeft = points[3];
    final top = topRight.dy;
    final bottom = bottomLeft.dy;
    double leftAt(double y) => _edgeX(topLeft, bottomLeft, y);
    final right = topRight.dx - PlanDetailMetrics.resourceRight;
    final data = this.data;
    final comparing = _comparing;

    final toolbarTop = top + PlanDetailMetrics.toolbarTop;
    final toolbarLeft =
        leftAt(toolbarTop + PlanDetailMetrics.toolbarHeight) +
        PlanDetailMetrics.toolbarLeft;
    Rect row(double offset, double height) {
      final left =
          leftAt(top + offset + height) + PlanDetailMetrics.rowInset;
      return Rect.fromLTWH(
        left,
        top + offset,
        math.max(0.0, right - left),
        height,
      );
    }

    final bodyTop =
        top +
        (comparing
            ? PlanDetailMetrics.bodyTop
            : PlanDetailMetrics.bodyTopWithoutComparison);
    final bodyBottom = math.max(
      bodyTop + 40,
      bottom - PlanDetailMetrics.bodyInset,
    );
    final bodyRect = Rect.fromLTRB(
      leftAt(bodyBottom) + PlanDetailMetrics.bodyInset,
      bodyTop,
      topRight.dx - PlanDetailMetrics.bodyInset,
      bodyBottom,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: ValueKey('$keyPrefix-resource-surface'),
              painter: const _DetailSectionPainter(
                planDetailResourceSectionId,
              ),
            ),
          ),
        ),
        Positioned(
          left: toolbarLeft,
          top: toolbarTop,
          width: math.max(0.0, right - toolbarLeft),
          height: PlanDetailMetrics.toolbarHeight,
          child: _toolbar(),
        ),
        Positioned.fromRect(
          rect: row(
            PlanDetailMetrics.summaryTop,
            PlanDetailMetrics.summaryHeight,
          ),
          child: _summary(data, comparing),
        ),
        if (comparing && data != null) ...[
          Positioned.fromRect(
            rect: row(
              PlanDetailMetrics.compareCaptionTop,
              PlanDetailMetrics.compareCaptionHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: PlanScenarioCaption(
                '활성 계획 대비',
                key: ValueKey('$keyPrefix-compare-caption'),
                note:
                    '활성 계획과 다른 병목 ${data.differentBottlenecks ?? 0}개 · '
                    '활성 계획에만 있는 병목 ${data.activeOnlyBottlenecks ?? 0}개',
              ),
            ),
          ),
          Positioned.fromRect(
            rect: row(PlanDetailMetrics.kpiTop, PlanDetailMetrics.kpiHeight),
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _kpis(data.kpis),
            ),
          ),
        ],
        if (resourcePlaceholder == null && _otherTab)
          Positioned.fill(
            child: KeyedSubtree(
              key: ValueKey('$keyPrefix-tab-body-${resourceTab.name}'),
              child: tabBody!(
                resourceTab,
                _parallelogramPath(bodyRect.size).shift(bodyRect.topLeft),
              ),
            ),
          )
        else
          Positioned.fromRect(
            rect: bodyRect,
            child: CustomPaint(
              key: ValueKey('$keyPrefix-body-panel'),
              painter: const _DetailPanelPainter(),
              child: ClipPath(
                clipper: const _ParallelogramClipper(),
                child: switch ((resourcePlaceholder, data)) {
                  (final Widget notice, _) => Center(child: notice),
                  (null, null) => Center(
                    child: placeholder ?? const SizedBox.shrink(),
                  ),
                  (null, final PlanDetailData value) => _cards(value),
                },
              ),
            ),
          ),
      ],
    );
  }

  /// S3 요약 행: 병목 탭은 "가장 심한 병목", 페이즈별 · 전체 탭은 [tabSummary], 재화를 그릴 수 없으면 빈 행.
  Widget _summary(PlanDetailData? data, bool comparing) {
    final tabSummary = this.tabSummary;
    if (resourcePlaceholder == null && _otherTab && tabSummary != null) {
      return DiagonalRow(
        key: ValueKey('$keyPrefix-summary-${resourceTab.name}'),
        variant: DiagonalRowVariant.row,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cut = diagonalCutDepth(constraints.maxHeight);
            return Padding(
              padding: EdgeInsets.fromLTRB(cut / 2 + 18, 6, cut / 2 + 14, 6),
              child: tabSummary(resourceTab),
            );
          },
        ),
      );
    }
    return _SummaryRow(
      key: ValueKey('$keyPrefix-summary'),
      keyPrefix: '$keyPrefix-summary',
      data: resourcePlaceholder == null ? data : null,
      studentName: studentName,
      showDelta: comparing,
      onTap:
          resourcePlaceholder != null ||
              data == null ||
              data.cards.isEmpty ||
              onSelectCard == null
          ? null
          : () => onSelectCard!(0),
    );
  }

  Widget _toolbar() {
    final onResourceTab = this.onResourceTab;
    final chips = toolbarChips;
    return Row(
      key: ValueKey('$keyPrefix-toolbar'),
      children: [
        if (onResourceTab != null)
          SkewSegmented<PlanDetailResourceTab>(
            key: ValueKey('$keyPrefix-tab'),
            segments: const [
              SkewSegment(
                value: PlanDetailResourceTab.bottleneck,
                label: '병목',
                leading: Icon(Icons.warning_amber_rounded, size: 15),
              ),
              SkewSegment(
                value: PlanDetailResourceTab.byPhase,
                label: '페이즈별',
                leading: Icon(Icons.layers_outlined, size: 15),
              ),
              SkewSegment(
                value: PlanDetailResourceTab.overall,
                label: '전체',
                leading: Icon(Icons.inventory_2_outlined, size: 15),
              ),
            ],
            selected: resourceTab,
            onChanged: onResourceTab,
            height: 36,
            fontSize: AppType.bodySize,
            horizontalPadding: 14,
          )
        else
          ..._lockedTabs(),
        // 칩은 남는 폭의 오른쪽 끝에 둔다. 좁은 창에서는 넘치지 않게 줄인다(넓은 창에서는 크기 그대로).
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            heightFactor: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: chips ?? _displayChips,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 시나리오 보기(FE5-c1): 병목만 켜고 페이즈별 · 전체는 꺼 둔다.
  List<Widget> _lockedTabs() => [
    SkewSegmented<PlanDetailResourceTab>(
      key: ValueKey('$keyPrefix-tab'),
      segments: const [
        SkewSegment(
          value: PlanDetailResourceTab.bottleneck,
          label: '병목',
          leading: Icon(Icons.warning_amber_rounded, size: 15),
        ),
      ],
      selected: PlanDetailResourceTab.bottleneck,
      // 병목 하나뿐이라 고를 것이 없다. 꺼진 모양이 되지 않게 빈 콜백을 둔다.
      onChanged: (_) {},
      height: 36,
      fontSize: AppType.bodySize,
      horizontalPadding: 14,
    ),
    const SizedBox(width: 6),
    Tooltip(
      message: '페이즈별 · 전체 보기는 아직 열 수 없습니다.',
      child: SkewSegmented<PlanDetailResourceTab>(
        key: ValueKey('$keyPrefix-tab-later'),
        segments: const [
          SkewSegment(
            value: PlanDetailResourceTab.byPhase,
            label: '페이즈별',
            leading: Icon(Icons.layers_outlined, size: 15),
          ),
          SkewSegment(
            value: PlanDetailResourceTab.overall,
            label: '전체',
            leading: Icon(Icons.inventory_2_outlined, size: 15),
          ),
        ],
        selected: null,
        onChanged: null,
        height: 36,
        fontSize: AppType.bodySize,
        horizontalPadding: 14,
      ),
    ),
  ];

  /// 표시만 하는 칩 3개(시나리오 보기).
  static const _displayChips = <Widget>[
    BaChip(
      label: '재화 유형 · 전체',
      tone: AppTones.gray,
      leading: Icon(Icons.filter_list_rounded, size: 13),
    ),
    SizedBox(width: 8),
    BaChip(
      label: '충족 재화 숨기기',
      tone: AppTones.gray,
      leading: Icon(Icons.visibility_off_outlined, size: 13),
    ),
    SizedBox(width: 8),
    BaChip(
      label: '부족량 많은 순',
      tone: AppTones.gray,
      leading: Icon(Icons.sort_rounded, size: 13),
    ),
  ];

  Widget _kpis(PlanDetailKpis kpis) {
    String count(int? value) => value == null ? '—' : '$value종';
    String credits(int? value) =>
        value == null ? '—' : growthCalculatorCompactNumber(value);
    String finishing(({int finishing, int total})? value) =>
        value == null ? '—' : '${value.finishing} / ${value.total}';
    Color finishingColor(
      ({int finishing, int total})? a,
      ({int finishing, int total})? b,
    ) {
      if (a == null || b == null || a.total == 0 || b.total == 0) {
        return AppColors.text;
      }
      final left = a.finishing * b.total;
      final rightValue = b.finishing * a.total;
      if (left == rightValue) return AppColors.text;
      return rightValue > left ? AppTones.ok.foreground : AppTones.warn.foreground;
    }

    final shortageTile = PlanScenarioKpiTile(
      key: ValueKey('$keyPrefix-kpi-shortage'),
      label: '부족 재화',
      before: count(kpis.shortageKinds.a),
      after: count(kpis.shortageKinds.b),
      afterColor: planScenarioLowerBetterColor(
        kpis.shortageKinds.a,
        kpis.shortageKinds.b,
      ),
    );
    final shortageKpi = this.shortageKpi;
    return Row(
      key: ValueKey('$keyPrefix-kpis'),
      children: [
        Expanded(
          child: PlanScenarioKpiTile(
            key: ValueKey('$keyPrefix-kpi-credits'),
            label: '필요 크레딧',
            before: credits(kpis.credits.a),
            after: credits(kpis.credits.b),
            afterColor: planScenarioLowerBetterColor(
              kpis.credits.a,
              kpis.credits.b,
            ),
          ),
        ),
        const SizedBox(width: PlanDetailMetrics.kpiGap),
        Expanded(
          child: shortageKpi == null ? shortageTile : shortageKpi(shortageTile),
        ),
        const SizedBox(width: PlanDetailMetrics.kpiGap),
        Expanded(
          child: PlanScenarioKpiTile(
            key: ValueKey('$keyPrefix-kpi-bottleneck'),
            label: '첫 병목',
            before: planScenarioBottleneckValue(kpis.firstBottleneck.a),
            after: planScenarioBottleneckValue(kpis.firstBottleneck.b),
            afterColor: planScenarioBottleneckColor(
              kpis.firstBottleneck.a,
              kpis.firstBottleneck.b,
            ),
          ),
        ),
        const SizedBox(width: PlanDetailMetrics.kpiGap),
        Expanded(
          child: PlanScenarioKpiTile(
            key: ValueKey('$keyPrefix-kpi-finishing'),
            label: '끝까지 가는 학생',
            before: finishing(kpis.finishing.a),
            after: finishing(kpis.finishing.b),
            afterColor: finishingColor(kpis.finishing.a, kpis.finishing.b),
          ),
        ),
      ],
    );
  }

  Widget _cards(PlanDetailData data) {
    if (data.cards.isEmpty) {
      return Center(
        key: ValueKey('$keyPrefix-cards-empty'),
        child: Text(
          data.kpis.firstBottleneck.b == null
              ? '병목을 계산하지 못했습니다.'
              : '알려진 보유로는 막히는 단계가 없습니다.',
          style: _muted.copyWith(fontSize: AppType.bodySize),
        ),
      );
    }
    return DiagonalScrollViewport(
      key: ValueKey('$keyPrefix-cards'),
      keyPrefix: '$keyPrefix-card-diagonal',
      itemCount: data.cards.length,
      itemHeight: (_) => PlanDetailMetrics.cardHeight,
      itemGap: PlanDetailMetrics.cardGap,
      verticalInset: 14,
      horizontalInset: 18,
      scrollbarReserve: 10,
      fog: const ScrollFogSpec.panel(color: _panelFill),
      itemBuilder: (context, index) {
        final card = data.cards[index];
        return _BottleneckCard(
          key: ValueKey('$keyPrefix-card-${card.number}'),
          keyPrefix: '$keyPrefix-card-${card.number}',
          card: card,
          studentName: studentName,
          selected: index == selectedCard,
          showDelta: _comparing,
          onTap: onSelectCard == null ? null : () => onSelectCard!(index),
        );
      },
    );
  }
}

/// 섹션 표면(공용 [paintSectionSurface]).
class _DetailSectionPainter extends CustomPainter {
  const _DetailSectionPainter(this.sectionId);

  final String sectionId;

  @override
  void paint(Canvas canvas, Size size) {
    paintSectionSurface(
      canvas,
      buildSectionCanvasElementPath(size, planDetailSection(sectionId)),
    );
  }

  @override
  bool shouldRepaint(_DetailSectionPainter oldDelegate) =>
      oldDelegate.sectionId != sectionId;
}

/// 상자 크기의 80° 평행사변형(아랫변 왼쪽 0, 윗변 오른쪽 끝 = 상자 폭).
Path _parallelogramPath(Size size) {
  final cut = diagonalCutDepth(size.height);
  return diagonalRoundedPolygon(
    [
      Offset(cut, 0),
      Offset(size.width, 0),
      Offset(size.width - cut, size.height),
      Offset(0, size.height),
    ],
    radius: AppRadii.rowLarge,
    corner: DiagonalCornerStyle.quadratic,
  );
}

class _ParallelogramClipper extends CustomClipper<Path> {
  const _ParallelogramClipper();

  @override
  Path getClip(Size size) => _parallelogramPath(size);

  @override
  bool shouldReclip(_ParallelogramClipper oldClipper) => false;
}

/// 스크롤 패널(시안 rgba(26,44,59,.9) + 1px rgba(56,81,107,.72)).
class _DetailPanelPainter extends CustomPainter {
  const _DetailPanelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = _parallelogramPath(size);
    canvas.drawPath(path, Paint()..color = _panelFill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _panelBorder,
    );
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_DetailPanelPainter oldDelegate) => false;
}

/// 페이즈 번호 배지 색(P 홀수 = 파랑, 짝수 = 분홍, 시안 병목 카드).
AppTone _phaseTone(int phase) => phase.isOdd ? AppTones.info : AppTones.pink;

/// 페이즈 헤더(시안 `.plain` 44px).
class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({super.key, required this.phase});

  final PlanDetailPhase phase;

  @override
  Widget build(BuildContext context) {
    final kinds = phase.shortageKinds;
    return ClipPath(
      clipper: const DiagonalRowClipper(DiagonalRowVariant.plain),
      child: ColoredBox(
        color: _phaseHeaderFill,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cut = diagonalCutDepth(constraints.maxHeight);
            return Padding(
              padding: EdgeInsets.fromLTRB(cut / 2 + 14, 0, cut / 2 + 14, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${phase.number}',
                      maxLines: 1,
                      style: kitDisplayStyle(
                        AppType.headlineSize,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      phase.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _bold.copyWith(fontSize: AppType.bodyLargeSize),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('단계 ${phase.stages.length}', maxLines: 1, style: _muted),
                  const Spacer(),
                  if (kinds != null)
                    BaChip(
                      label: kinds == 0 ? '충분' : '부족 $kinds종',
                      tone: kinds == 0 ? AppTones.ok : AppTones.warn,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 단계 행(시안 `.srow` 70px).
class _StageRow extends StatelessWidget {
  const _StageRow({
    super.key,
    required this.keyPrefix,
    required this.stage,
    required this.name,
    required this.highlighted,
    required this.showDelta,
    this.onTap,
  });

  final String keyPrefix;
  final PlanDetailStageRow stage;
  final String name;
  final bool highlighted;
  final bool showDelta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final delta = stage.delta;
    final (String? stateLabel, AppTone stateTone) = switch (stage.state) {
      PlanDetailStageState.blockedHere => (
        stage.bottleneckNumber == null
            ? '여기서 막힘'
            : '병목 ${stage.bottleneckNumber} · 여기서 막힘',
        AppTones.pink,
      ),
      PlanDetailStageState.waiting => ('앞 단계 대기', AppTones.gray),
      PlanDetailStageState.clear => (null, AppTones.gray),
    };
    return DiagonalRow(
      mark: highlighted ? DiagonalRowMark.selected : DiagonalRowMark.none,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cut = diagonalCutDepth(constraints.maxHeight);
          return Padding(
            padding: EdgeInsets.fromLTRB(cut / 2 + 16, 0, cut / 2 + 16, 0),
            child: Row(
              children: [
                PortraitStrip(
                  studentIds: [stage.studentId],
                  maxVisible: 1,
                  portraitSize: const Size(52, 42),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(stage.name, maxLines: 1, style: _muted),
                          if (stateLabel != null) ...[
                            const SizedBox(width: 8),
                            BaChip(
                              key: ValueKey('$keyPrefix-state'),
                              label: stateLabel,
                              tone: stateTone,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        planScenarioTargetSummary(stage.targets),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _muted,
                      ),
                    ],
                  ),
                ),
                if (showDelta && delta != null) ...[
                  const SizedBox(width: 10),
                  BaChip(
                    key: ValueKey('$keyPrefix-delta'),
                    label: delta.label,
                    tone: planScenarioDeltaTone(delta.tone),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// S3 요약 행(시안 `.row` 70px "가장 심한 병목").
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    super.key,
    required this.keyPrefix,
    required this.data,
    required this.studentName,
    required this.showDelta,
    this.onTap,
  });

  final String keyPrefix;
  final PlanDetailData? data;
  final String Function(String studentId) studentName;
  final bool showDelta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = data?.cards.firstOrNull;
    final primary = card?.primary;
    final String title;
    final String detail;
    if (card != null && primary != null) {
      title = '${primary.name} · ${_amount(primary.shortage)} 부족';
      detail = [
        'P${card.phase} ${studentName(card.studentId)} ${card.stageName}에서 막힙니다',
        if (card.delayed.isNotEmpty) '이 병목으로 지연되는 단계 ${card.delayed.length}개',
      ].join(' · ');
    } else if (data == null) {
      title = '—';
      detail = '';
    } else {
      title = '병목이 없습니다';
      detail = '알려진 보유로는 막히는 단계가 없습니다.';
    }
    final delta = card?.delta;
    final iconAsset = primary == null
        ? null
        : planningResourceIconAsset(
            category: primary.category,
            itemId: primary.itemId,
          );
    return DiagonalRow(
      variant: onTap == null ? DiagonalRowVariant.row : DiagonalRowVariant.srow,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cut = diagonalCutDepth(constraints.maxHeight);
          return Padding(
            padding: EdgeInsets.fromLTRB(cut / 2 + 18, 0, cut / 2 + 14, 0),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 52,
                  child: iconAsset == null && primary == null
                      ? null
                      : ItemIconTile(
                          iconAsset: iconAsset,
                          size: const Size(64, 52),
                          semanticLabel: primary?.name,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '가장 심한 병목',
                        maxLines: 1,
                        style: _captionStyle.copyWith(color: AppColors.accent),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        key: ValueKey('$keyPrefix-title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _bold.copyWith(
                          fontSize: AppType.titleMediumSize,
                        ),
                      ),
                      if (detail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          key: ValueKey('$keyPrefix-detail'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _muted,
                        ),
                      ],
                    ],
                  ),
                ),
                if (showDelta && delta != null) ...[
                  const SizedBox(width: 10),
                  BaChip(
                    key: ValueKey('$keyPrefix-delta'),
                    label: delta.label,
                    tone: planScenarioDeltaTone(delta.tone),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 병목 카드(시안 `.srow` 214px).
class _BottleneckCard extends StatelessWidget {
  const _BottleneckCard({
    super.key,
    required this.keyPrefix,
    required this.card,
    required this.studentName,
    required this.selected,
    required this.showDelta,
    this.onTap,
  });

  final String keyPrefix;
  final PlanDetailBottleneckCard card;
  final String Function(String studentId) studentName;
  final bool selected;
  final bool showDelta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _phaseTone(card.phase);
    final delta = card.delta;
    final delayed = card.delayed
        .map(
          (stage) =>
              '${studentName(stage.studentId)} ${stage.name} (P${stage.phase})',
        )
        .join(' · ');
    return DiagonalRow(
      mark: selected ? DiagonalRowMark.selected : DiagonalRowMark.none,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cut = diagonalCutDepth(constraints.maxHeight);
          return Padding(
            padding: EdgeInsets.fromLTRB(cut + 10, 16, cut + 10, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                      Text(
                        '병목 ${card.number}',
                        maxLines: 1,
                        style: kitDisplayStyle(
                          AppType.titleLargeSize,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 24,
                        child: SkewBox(
                          fill: tone.base.withValues(alpha: 0.16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Center(
                              widthFactor: 1,
                              child: Text(
                                'P${card.phase}',
                                key: ValueKey('$keyPrefix-phase'),
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: AppFonts.body,
                                  fontFamilyFallback: AppFonts.fallback,
                                  fontSize: AppType.bodySmallSize,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                  color: tone.foreground,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      PortraitStrip(
                        studentIds: [card.studentId],
                        maxVisible: 1,
                        portraitSize: const Size(38, 30),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        studentName(card.studentId),
                        maxLines: 1,
                        style: _bold.copyWith(fontSize: AppType.bodyPlusSize),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${card.stageName} · ${planScenarioTargetSummary(card.targets)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _muted,
                        ),
                      ),
                      if (card.hiddenShortages > 0) ...[
                        const SizedBox(width: 8),
                        BaChip(
                          label: '모자란 재화 외 ${card.hiddenShortages}종',
                          tone: AppTones.gray,
                        ),
                      ],
                      const Spacer(),
                      if (showDelta && delta != null)
                        BaChip(
                          key: ValueKey('$keyPrefix-delta'),
                          label: delta.label,
                          tone: planScenarioDeltaTone(delta.tone),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 84,
                  child: Row(
                    children: [
                      for (final (index, resource) in card.resources.indexed) ...[
                        if (index > 0) const SizedBox(width: 18),
                        Expanded(
                          child: _CardResourceTile(
                            key: ValueKey(
                              '$keyPrefix-resource-${resource.resourceKey}',
                            ),
                            resource: resource,
                            showDelta: showDelta,
                          ),
                        ),
                      ],
                      // 타일이 하나면 시안처럼 반 폭을 비워 둔다.
                      if (card.resources.length == 1) ...[
                        const SizedBox(width: 18),
                        const Spacer(),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  key: ValueKey('$keyPrefix-delayed'),
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '이 병목으로 지연되는 단계',
                      maxLines: 1,
                      style: _muted.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        delayed.isEmpty ? '없음' : delayed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _muted.copyWith(
                          color: AppColors.text,
                          fontWeight: AppType.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 병목 카드 재화 타일(시안: 바탕 skewX −10° rgba(16,24,35,.55), 아이콘 59×48, 이름 · 활성 대비 칩, 진입 잔량 · 필요,
/// "n 부족"(분홍) 또는 "충분"(초록)).
class _CardResourceTile extends StatelessWidget {
  const _CardResourceTile({
    super.key,
    required this.resource,
    required this.showDelta,
  });

  final PlanDetailCardResource resource;
  final bool showDelta;

  @override
  Widget build(BuildContext context) {
    final delta = resource.delta;
    final short = resource.shortage > 0;
    return SkewBox(
      fill: _tileFill,
      radius: 7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
        child: Row(
          children: [
            ItemIconTile(
              iconAsset: planningResourceIconAsset(
                category: resource.category,
                itemId: resource.itemId,
              ),
              size: const Size(59, 48),
              semanticLabel: resource.name,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          resource.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bold.copyWith(fontSize: AppType.bodyPlusSize),
                        ),
                      ),
                      if (showDelta && delta != null) ...[
                        const SizedBox(width: 8),
                        BaChip(
                          label: delta.label,
                          tone: planScenarioDeltaTone(delta.tone),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '진입 잔량 ${_amount(resource.ownedAtEntry)} · 필요 ${_amount(resource.required)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _muted.copyWith(fontSize: AppType.captionPlusSize),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              short ? '${_amount(resource.shortage)} 부족' : '충분',
              maxLines: 1,
              style: kitDisplayStyle(
                short ? AppType.titleLargeSize : AppType.titleSize,
                color: short ? AppColors.accent : AppTones.ok.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 메뉴 정보 줄(시안 `.btn.ghost` 36px: 흐린 라벨 + 굵은 값). 누르는 동작은 없다.
class PlanDetailInfoRow extends StatelessWidget {
  const PlanDetailInfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: PlanDetailMetrics.menuInfoHeight,
    child: SkewBox(
      border: AppColors.textMuted.withValues(alpha: 0.35),
      borderWidth: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // 좁은 창(1280×720)에서는 메뉴 아래쪽이 좁아지므로 라벨도 줄인다(FE5-c2). 넓은 창에서는 그대로다.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _muted.copyWith(fontSize: AppType.popoverBodySize),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _bold.copyWith(fontSize: AppType.popoverBodySize),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 시나리오 보기 모드 S1 메뉴(시안 Scenario-Detail S1). [frame] 자리에 그린다.
///
/// "계획" · "보는 중 · 시나리오" · 고른 시나리오(분홍, 누르면 다시 비교) · 시나리오 목록(뒤로) · 페이즈 편집 · 복제해서
/// 새로 · 비교에 담기 n/4 · 계획에 적용…(FD-088) · "이 시나리오" 정보 5줄.
class PlanScenarioDetailMenu extends StatelessWidget {
  const PlanScenarioDetailMenu({
    super.key,
    required this.frame,
    required this.name,
    required this.students,
    required this.phases,
    required this.stages,
    required this.savedLabel,
    required this.stale,
    required this.compared,
    required this.compareCount,
    required this.compareCapacity,
    this.onRefresh,
    this.onBack,
    this.onEdit,
    this.onDuplicate,
    this.onToggleCompare,
    this.onApply,
  });

  final PlanDetailMenuFrame frame;
  final String name;
  final int? students;
  final int? phases;
  final int? stages;
  final String savedLabel;
  final bool stale;
  final bool compared;
  final int compareCount;
  final int compareCapacity;
  final VoidCallback? onRefresh;
  final VoidCallback? onBack;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onToggleCompare;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final top = frame.top;
    String count(int? value, String unit) =>
        value == null ? '—' : '$value$unit';
    final actions =
        <(String, RailButtonVariant, IconData, String, VoidCallback?, String?)>[
      (
        'plan-scenario-detail-back',
        RailButtonVariant.ghost,
        Icons.arrow_back_rounded,
        '시나리오 목록',
        onBack,
        null,
      ),
      (
        'plan-scenario-detail-edit',
        RailButtonVariant.base,
        Icons.edit_outlined,
        '페이즈 편집',
        onEdit,
        null,
      ),
      (
        'plan-scenario-detail-duplicate',
        RailButtonVariant.ghost,
        Icons.copy_rounded,
        '복제해서 새로',
        onDuplicate,
        null,
      ),
      (
        'plan-scenario-detail-compare',
        RailButtonVariant.ghost,
        compared ? Icons.check_rounded : Icons.add_rounded,
        '${compared ? '비교에서 빼기' : '비교에 담기'} · $compareCount/$compareCapacity',
        onToggleCompare,
        null,
      ),
      (
        'plan-scenario-detail-apply',
        RailButtonVariant.tri,
        Icons.fact_check_outlined,
        '계획에 적용…',
        onApply,
        onApply == null ? planScenarioApplyUnavailable : null,
      ),
    ];
    final info = [
      ('학생', count(students, '명')),
      ('페이즈', count(phases, '개')),
      ('단계', count(stages, '개')),
      ('저장', savedLabel),
      ('데이터', stale ? '저장 시점과 다름' : '현재 기준'),
    ];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 20,
          top: top + PlanDetailMetrics.menuTitleTop,
          width: math.max(0.0, frame.width(top) - 6),
          height: 32,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '계획',
              maxLines: 1,
              style: kitDisplayStyle(AppType.headlineSmallSize),
            ),
          ),
        ),
        Positioned(
          left: 20,
          top: top + PlanDetailMetrics.menuCaptionTop,
          height: 18,
          width: math.max(0.0, frame.width(top) - 6),
          child: const Text('보는 중 · 시나리오', maxLines: 1, style: _captionStyle),
        ),
        Positioned.fromRect(
          rect: frame.row(
            PlanDetailMetrics.menuCurrentTop,
            PlanDetailMetrics.menuCurrentHeight,
          ),
          child: RailButton(
            key: const ValueKey('plan-scenario-detail-current'),
            variant: RailButtonVariant.selectedPink,
            height: PlanDetailMetrics.menuCurrentHeight,
            semanticLabel: '활성 계획과 다시 비교',
            onPressed: onRefresh,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  key: const ValueKey('plan-scenario-detail-name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppType.bodyLargeSize,
                    fontWeight: AppType.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '활성 계획은 바뀌지 않습니다',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: AppType.captionSize,
                    fontWeight: AppType.medium,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final (index, (key, variant, icon, label, onPressed, tooltip))
            in actions.indexed)
          Positioned.fromRect(
            rect: frame.row(
              PlanDetailMetrics.menuActionTops[index],
              PlanDetailMetrics.menuActionHeight,
            ),
            child: _withTooltip(
              tooltip,
              RailButton(
                key: ValueKey(key),
                variant: variant,
                onPressed: onPressed,
                child: Row(
                  children: [
                    Icon(icon),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: AppType.semiBold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          left: 20,
          top: top + PlanDetailMetrics.menuInfoCaptionTop,
          height: 18,
          width: math.max(0.0, frame.width(top) - 6),
          child: const Text('이 시나리오', maxLines: 1, style: _captionStyle),
        ),
        for (final (index, (label, value)) in info.indexed)
          Positioned.fromRect(
            rect: frame.row(
              PlanDetailMetrics.menuInfoTop +
                  PlanDetailMetrics.menuInfoPitch * index,
              PlanDetailMetrics.menuInfoHeight,
            ),
            child: PlanDetailInfoRow(
              key: ValueKey('plan-scenario-detail-info-$index'),
              label: label,
              value: value,
            ),
          ),
      ],
    );
  }

  static Widget _withTooltip(String? message, Widget child) =>
      message == null ? child : Tooltip(message: message, child: child);
}

/// S1 버튼 하나(키 · 모양 · 아이콘 · 글자 · 동작 · 꺼졌을 때 툴팁).
typedef PlanDetailRailAction = ({
  String key,
  RailButtonVariant variant,
  IconData icon,
  String label,
  VoidCallback? onPressed,
  String? tooltip,
});

/// S1 메뉴 내용(FE5-c2 활성 계획 홈 · A↔B 비교 화면). 시나리오 목록(FE5-a) · 시나리오 보기(FE5-c1) S1과 같은 자리 ·
/// 모양이다: "계획" 22 · 소제목 72 · 분홍 현재 버튼 96(58px) · 버튼 166 · 228 · 280 …(44px) · 정보 소제목 · 정보 줄(36px,
/// 40 간격). 정보 소제목은 마지막 버튼 아래 26px이다.
class PlanDetailRailMenu extends StatelessWidget {
  const PlanDetailRailMenu({
    super.key,
    required this.frame,
    required this.keyPrefix,
    required this.caption,
    required this.currentTitle,
    required this.currentSubtitle,
    required this.actions,
    this.currentSemanticLabel,
    this.onCurrent,
    this.infoCaption,
    this.info = const [],
  });

  final PlanDetailMenuFrame frame;
  final String keyPrefix;

  /// 소제목(시안 "보는 중 · 시나리오").
  final String caption;
  final String currentTitle;
  final String currentSubtitle;
  final String? currentSemanticLabel;
  final VoidCallback? onCurrent;

  /// 위에서부터 [PlanDetailMetrics.menuActionTops] 자리에 놓는다(최대 5개).
  final List<PlanDetailRailAction> actions;
  final String? infoCaption;

  /// 정보 줄(라벨, 값).
  final List<(String, String)> info;

  @override
  Widget build(BuildContext context) {
    final top = frame.top;
    final shown = actions.take(PlanDetailMetrics.menuActionTops.length);
    final infoCaptionTop = actions.isEmpty
        ? PlanDetailMetrics.menuActionTops.first
        : PlanDetailMetrics.menuActionTops[shown.length - 1] +
              PlanDetailMetrics.menuActionHeight +
              26;
    final infoCaption = this.infoCaption;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 20,
          top: top + PlanDetailMetrics.menuTitleTop,
          width: math.max(0.0, frame.width(top) - 6),
          height: 32,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '계획',
              maxLines: 1,
              style: kitDisplayStyle(AppType.headlineSmallSize),
            ),
          ),
        ),
        Positioned(
          left: 20,
          top: top + PlanDetailMetrics.menuCaptionTop,
          height: 18,
          width: math.max(0.0, frame.width(top) - 6),
          child: Text(caption, maxLines: 1, style: _captionStyle),
        ),
        Positioned.fromRect(
          rect: frame.row(
            PlanDetailMetrics.menuCurrentTop,
            PlanDetailMetrics.menuCurrentHeight,
          ),
          child: RailButton(
            key: ValueKey('$keyPrefix-current'),
            variant: RailButtonVariant.selectedPink,
            height: PlanDetailMetrics.menuCurrentHeight,
            semanticLabel: currentSemanticLabel,
            onPressed: onCurrent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentTitle,
                  key: ValueKey('$keyPrefix-current-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppType.bodyLargeSize,
                    fontWeight: AppType.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  currentSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppType.captionSize,
                    fontWeight: AppType.medium,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final (index, action) in shown.indexed)
          Positioned.fromRect(
            rect: frame.row(
              PlanDetailMetrics.menuActionTops[index],
              PlanDetailMetrics.menuActionHeight,
            ),
            child: PlanScenarioDetailMenu._withTooltip(
              action.onPressed == null ? action.tooltip : null,
              RailButton(
                key: ValueKey(action.key),
                variant: action.variant,
                onPressed: action.onPressed,
                child: Row(
                  children: [
                    Icon(action.icon),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        action.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: action.variant == RailButtonVariant.primary
                              ? AppType.bold
                              : AppType.semiBold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (infoCaption != null)
          Positioned(
            left: 20,
            top: top + infoCaptionTop,
            height: 18,
            width: math.max(0.0, frame.width(top) - 6),
            child: Text(infoCaption, maxLines: 1, style: _captionStyle),
          ),
        for (final (index, (label, value)) in info.indexed)
          Positioned.fromRect(
            rect: frame.row(
              infoCaptionTop +
                  (PlanDetailMetrics.menuInfoTop -
                      PlanDetailMetrics.menuInfoCaptionTop) +
                  PlanDetailMetrics.menuInfoPitch * index,
              PlanDetailMetrics.menuInfoHeight,
            ),
            child: PlanDetailInfoRow(
              key: ValueKey('$keyPrefix-info-$index'),
              label: label,
              value: value,
            ),
          ),
      ],
    );
  }
}
