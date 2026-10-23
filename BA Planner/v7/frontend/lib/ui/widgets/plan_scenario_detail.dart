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
//   페이즈별 · 전체 탭(FE5-d, 시안 Scenario-Detail-Phase · -All): [PlanDetailWorkspace.onResourceTab]을 넘기면 seg가
//   켜진다(활성 계획 홈 · 시나리오 보기 모두).
//   · 페이즈별: 요약 행 "가장 부족한 재화"(+ 활성 대비 칩), 본문 = 페이즈 카드(번호 · 이름 · 학생 · 부족 n종, 크레딧
//     진입/필요/종료, 재화 타일 2열 = 진입 · 필요 · 종료 + 충족 막대 % + 활성 대비 칩). 카드를 누르면 S2에서 그
//     페이즈 헤더와 단계 행이 강조된다.
//   · 전체: 요약 행 "전체 요구량"(확보율 FD-031 (a) + "활성 a% → b%" 칩), 본문 위 한 줄 = "재화 n종 · 한 행에
//     [2|3|4|5]" + 범례, 본문 = 크레딧 행 + 분야별 그룹 행(n열 타일, 마크 = / ±n / 신규). 타일을 누르면 S2에서 그
//     재화를 쓰는 단계가 강조된다(다시 누르면 해제).
//   칩 3개(재화 유형 · 충족 재화 숨기기 · 정렬, [PlanDetailResourceFilter])는 [PlanDetailWorkspace.onFilter]를
//   넘기면 동작한다. 재화 유형 · 숨기기는 병목 카드 · 페이즈 타일 · 전체 타일에, 정렬은 페이즈 · 전체 타일에만 건다
//   (병목 번호 = 막히는 순서를 지킨다). 넘기지 않으면 표시만 한다.
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
import '../kit/kit_pressable.dart';
import '../kit/portrait_strip.dart';
import '../kit/scroll_viewport_fog.dart';
import '../kit/skew_bar.dart';
import '../kit/skew_box.dart';
import '../kit/skew_controls.dart';
import '../kit/titles.dart';
import '../models/plan_scenario_detail.dart';
import '../models/plan_scenario_preview.dart';
import '../models/planning_resource_assets.dart';
import '../studio/plan_scenario_detail_studio_layout.dart';
import 'growth_calculator_section.dart' show growthCalculatorCompactNumber;
import 'plan_scenario_preview.dart';
import 'plan_section_layout.dart'
    show
        PlanResourceCategory,
        PlanResourceSort,
        PlanSectionMotion,
        planResourceCategory;
import 'section_surface.dart';
import 'section_template_surface.dart';

/// 섹션 모션(부착면 규칙 FD-078): S1 0/180(왼쪽), S2 80/260(아래), S3 180/0(오른쪽). 시나리오 목록과 같다.
const planDetailMenuMotion = (intro: 0.0, outro: 180.0);
const planDetailPhaseMotion = (intro: 80.0, outro: 260.0);
const planDetailResourceMotion = (intro: 180.0, outro: 0.0);

/// S3 맨 위 seg.
enum PlanDetailResourceTab { bottleneck, byPhase, overall }

/// 전체 탭 "한 행에" 열 수(시안 2~5, 기본 4).
const planDetailOverallColumnChoices = [2, 3, 4, 5];
const planDetailOverallDefaultColumns = 4;

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

  /// SL2: 레일 아래 여백과 세로 값을 줄이는 하한(시나리오 목록 S1 `PlanScenarioListMetrics`와 같은 값).
  static const menuBottomInset = 8.0;
  static const menuMinScale = 0.68;

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

  // 페이즈별 탭 페이즈 카드(시안 `.srow` 300px: 머리 줄 · 크레딧 줄 · 타일 2열 × 2줄).
  static const phaseCardPadding = 18.0;
  static const phaseCardHeader = 32.0;
  static const phaseCardCreditsGap = 8.0;
  static const phaseCardCredits = 24.0;
  static const phaseCardTilesGap = 12.0;
  static const phaseCardTile = 88.0;
  static const phaseCardTileGap = 12.0;
  static const phaseCardColumnGap = 18.0;
  static const phaseCardGap = 12.0;

  /// 페이즈 카드 높이(타일 [rows]줄, 크레딧 줄 유무). 시안 2줄 + 크레딧 = 300.
  static double phaseCardHeight(int rows, {required bool credits}) =>
      phaseCardPadding * 2 +
      phaseCardHeader +
      (credits ? phaseCardCreditsGap + phaseCardCredits : 0) +
      (rows <= 0
          ? 0
          : phaseCardTilesGap +
                rows * phaseCardTile +
                (rows - 1) * phaseCardTileGap);

  // 전체 탭(시안: 본문 위 30px 줄 → 10 아래 패널, 크레딧 행 54, 그룹 행 = 44 + 줄마다 58).
  static const overallHeaderHeight = 30.0;
  static const overallPanelOffset = 40.0;
  static const overallCreditsHeight = 54.0;
  static const overallGroupHeader = 44.0;
  static const overallTileRow = 58.0;
  static const overallTileHeight = 50.0;
  static const overallTileGap = 12.0;
  static const overallGap = 10.0;

  /// 그룹 행 높이(타일 [rows]줄).
  static double overallGroupHeight(int rows) =>
      overallGroupHeader + math.max(1, rows) * overallTileRow;
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

  /// 섹션 위에서 [offset] 아래, 높이 [height]인 버튼 자리. [scale]([scaleFor])은 세로 값에만 곱한다.
  Rect row(double offset, double height, {double scale = 1}) => Rect.fromLTWH(
    PlanDetailMetrics.menuLeft,
    top + offset * scale,
    width(top + offset * scale),
    height * scale,
  );

  /// SL2: 섹션 위에서 [contentBottom](줄이는 값) + [fixed](줄이지 않는 아래 글자 자리)까지가 레일에 들어가지 않으면
  /// (1280×720 등) 세로 값(자리 · 버튼 높이)만 같은 비율로 줄인다(시나리오 목록 S1 · 계획 만들기 레일과 같은 관례). 들어가면
  /// 1이다(기준 viewport · 1600×900은 그대로).
  double scaleFor(double contentBottom, {double fixed = 0}) =>
      ((bottomRight.dy - top - PlanDetailMetrics.menuBottomInset - fixed) /
              contentBottom)
          .clamp(PlanDetailMetrics.menuMinScale, 1.0)
          .toDouble();
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
/// [resourcePlaceholder](재화를 그릴 수 없을 때 S3 안내, 예: 계산 중 · 계산할 수 없음). FE5-d부터: [filter] ·
/// [onFilter](칩 3개), [selectedPhase] · [onSelectPhase](페이즈 카드 ↔ S2 페이즈 강조), [selectedResource] ·
/// [onSelectResource](전체 타일 ↔ S2 단계 강조), [overallColumns] · [onOverallColumns](전체 "한 행에").
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
    this.filter = const PlanDetailResourceFilter(),
    this.onFilter,
    this.selectedPhase,
    this.onSelectPhase,
    this.selectedResource,
    this.onSelectResource,
    this.overallColumns = planDetailOverallDefaultColumns,
    this.onOverallColumns,
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

  /// 칩 3개 상태. [onFilter]가 없어도 이 값으로 거른다.
  final PlanDetailResourceFilter filter;

  /// 칩을 바꾼다. null이면 칩은 표시만 한다.
  final ValueChanged<PlanDetailResourceFilter>? onFilter;

  /// 고른 페이즈 카드(페이즈 번호, 1부터). null이면 고르지 않음.
  final int? selectedPhase;
  final ValueChanged<int>? onSelectPhase;

  /// 고른 전체 탭 재화(`resource_key`). null이면 고르지 않음.
  final String? selectedResource;

  /// 전체 타일을 누른다(같은 재화를 다시 누르면 null).
  final ValueChanged<String?>? onSelectResource;

  /// 전체 탭 "한 행에" 열 수(2~5).
  final int overallColumns;
  final ValueChanged<int>? onOverallColumns;

  /// 재화를 그릴 수 없을 때(계산 중 · 계산 오류 · 계산할 수 없음) S3 본문 안내. 있으면 요약 행 · 본문 대신 보인다.
  final Widget? resourcePlaceholder;

  /// 지금 보이는 탭(seg가 꺼져 있으면 병목).
  PlanDetailResourceTab get _tab =>
      onResourceTab == null ? PlanDetailResourceTab.bottleneck : resourceTab;

  bool get _comparing => showComparison && (data?.hasComparison ?? false);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(
        constraints.maxWidth,
        constraints.maxHeight.isFinite ? constraints.maxHeight : 660,
      );
      // 병목 카드에는 재화 유형 · 충족 재화 숨기기를 건다(페이즈 · 전체 타일은 그 탭 본문이 거른다).
      final source = data;
      PlanDetailData? view;
      if (source != null) view = source.withCards(filter.cards(source.cards));
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
                child: _resources(size, view),
              ),
            ),
            Positioned.fill(
              child: PlanSectionMotion(
                key: ValueKey('$keyPrefix-phase-motion'),
                animation: animation,
                introDegrees: planDetailPhaseMotion.intro,
                outroDegrees: planDetailPhaseMotion.outro,
                child: _phases(size, view),
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

  Widget _phases(Size size, PlanDetailData? data) {
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
    final highlighted = _highlightedStages(data);
    final highlightedPhase = _tab == PlanDetailResourceTab.byPhase
        ? selectedPhase
        : null;
    final onSelectPhase = this.onSelectPhase;
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
              selected: item.phase.number == highlightedPhase,
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
            highlighted: highlighted.contains(stage.stageId),
            showDelta: _comparing,
            onTap: switch (_tab) {
              PlanDetailResourceTab.bottleneck =>
                onSelectCard == null || number == null
                    ? null
                    : () {
                        // 카드 목록이 걸러졌을 수 있다(재화 유형 필터). 번호로 찾는다.
                        final index = data.cards.indexWhere(
                          (card) => card.number == number,
                        );
                        if (index >= 0) onSelectCard!(index);
                      },
              PlanDetailResourceTab.byPhase =>
                onSelectPhase == null
                    ? null
                    : () => onSelectPhase(stage.phase),
              PlanDetailResourceTab.overall => null,
            },
          ),
        );
      },
    );
  }

  /// S2에서 강조할 단계: 병목 = 고른 카드의 단계, 페이즈별 = 고른 페이즈의 단계, 전체 = 고른 재화를 쓰는 단계.
  Set<String> _highlightedStages(PlanDetailData data) {
    switch (_tab) {
      case PlanDetailResourceTab.bottleneck:
        final index = selectedCard;
        if (index == null || index < 0 || index >= data.cards.length) {
          return const {};
        }
        return {data.cards[index].stageId};
      case PlanDetailResourceTab.byPhase:
        final number = selectedPhase;
        return {
          for (final phase in data.phases)
            if (phase.number == number)
              for (final stage in phase.stages) stage.stageId,
        };
      case PlanDetailResourceTab.overall:
        final key = selectedResource;
        final overall = data.overall;
        if (key == null || overall == null) return const {};
        final tile = [
          ?overall.credits,
          ...overall.tiles,
        ].where((item) => item.resourceKey == key).firstOrNull;
        return {...?tile?.affectedStageIds};
    }
  }

  // --- S3 재화 ----------------------------------------------------------------

  Widget _resources(Size size, PlanDetailData? data) {
    final points = planDetailSectionPolygon(size, planDetailResourceSectionId);
    final topRight = points[0];
    final bottomLeft = points[2];
    final topLeft = points[3];
    final top = topRight.dy;
    final bottom = bottomLeft.dy;
    double leftAt(double y) => _edgeX(topLeft, bottomLeft, y);
    final right = topRight.dx - PlanDetailMetrics.resourceRight;
    final comparing = _comparing;
    final tab = _tab;

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

    final listTop =
        top +
        (comparing
            ? PlanDetailMetrics.bodyTop
            : PlanDetailMetrics.bodyTopWithoutComparison);
    // 전체 탭은 본문 위에 "재화 n종 · 한 행에" 줄을 두고 패널을 40 내린다(시안 471 → 511).
    final overallKinds =
        tab == PlanDetailResourceTab.overall &&
            resourcePlaceholder == null &&
            data != null
        ? _overallGroups(
            data,
          ).fold<int>(0, (sum, group) => sum + group.tiles.length)
        : null;
    final bodyTop =
        listTop +
        (overallKinds != null ? PlanDetailMetrics.overallPanelOffset : 0);
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
        if (overallKinds != null)
          Positioned.fromRect(
            rect: row(
              listTop - top,
              PlanDetailMetrics.overallHeaderHeight,
            ),
            child: _OverallHeader(
              key: ValueKey('$keyPrefix-overall-header'),
              keyPrefix: '$keyPrefix-overall',
              kinds: overallKinds,
              columns: overallColumns,
              onColumns: onOverallColumns,
              showLegend: comparing,
            ),
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
                note: switch (tab) {
                  PlanDetailResourceTab.bottleneck =>
                    '활성 계획과 다른 병목 ${data.differentBottlenecks ?? 0}개 · '
                        '활성 계획에만 있는 병목 ${data.activeOnlyBottlenecks ?? 0}개',
                  PlanDetailResourceTab.byPhase => '페이즈를 누르면 왼쪽 단계가 강조됩니다',
                  PlanDetailResourceTab.overall =>
                    '재화를 누르면 왼쪽에서 그 재화를 쓰는 단계가 강조됩니다',
                },
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
                (null, final PlanDetailData value) => switch (tab) {
                  PlanDetailResourceTab.bottleneck => _cards(value),
                  PlanDetailResourceTab.byPhase => _phaseCards(value),
                  PlanDetailResourceTab.overall => _overallList(value),
                },
              },
            ),
          ),
        ),
      ],
    );
  }

  /// S3 요약 행: 병목 = "가장 심한 병목", 페이즈별 = "가장 부족한 재화", 전체 = "전체 요구량". 재화를 그릴 수 없으면
  /// 빈 행.
  Widget _summary(PlanDetailData? data, bool comparing) {
    final shown = resourcePlaceholder == null ? data : null;
    switch (_tab) {
      case PlanDetailResourceTab.byPhase:
        return _PhaseSummaryRow(
          key: ValueKey('$keyPrefix-summary-byPhase'),
          keyPrefix: '$keyPrefix-summary-byPhase',
          data: shown,
          showDelta: comparing,
          onTap: shown == null || onSelectPhase == null
              ? null
              : switch (shown.phaseSummary) {
                  final summary? => () => onSelectPhase!(summary.phase),
                  null => null,
                },
        );
      case PlanDetailResourceTab.overall:
        return _OverallSummaryRow(
          key: ValueKey('$keyPrefix-summary-overall'),
          keyPrefix: '$keyPrefix-summary-overall',
          data: shown,
          showDelta: comparing,
        );
      case PlanDetailResourceTab.bottleneck:
        break;
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
    final onFilter = this.onFilter;
    final chips = onFilter == null
        ? null
        : [
            PlanDetailFilterChips(
              keyPrefix: keyPrefix,
              filter: filter,
              onChanged: onFilter,
            ),
          ];
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

  /// [onResourceTab]이 없을 때(FE5-c1 시나리오 보기와 같은 모양): 병목만 켜고 페이즈별 · 전체는 꺼 둔다. FE5-d부터
  /// 활성 계획 홈 · 시나리오 보기 모두 [onResourceTab]을 넘긴다.
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

  /// 표시만 하는 칩 3개([onFilter]가 없을 때).
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

  /// 페이즈별 탭 본문: 걸러진 크레딧 줄 · 타일이 있는 페이즈 카드.
  Widget _phaseCards(PlanDetailData data) {
    final cards = [
      for (final phase in data.phaseResources)
        (
          phase: phase,
          credits: switch (phase.credits) {
            final value? when filter.shows(value) => value,
            _ => null,
          },
          tiles: filter.apply(phase.tiles),
        ),
    ].where((card) => card.credits != null || card.tiles.isNotEmpty).toList();
    if (cards.isEmpty) {
      final hasResources = data.phaseResources.any(
        (phase) => phase.credits != null || phase.tiles.isNotEmpty,
      );
      return Center(
        key: ValueKey('$keyPrefix-phase-cards-empty'),
        child: Text(
          hasResources
              ? '조건에 맞는 재화가 없습니다.'
              : data.phaseResources.any((phase) => phase.calculated)
              ? '이 계획에 필요한 재화가 없습니다.'
              : '페이즈별 재화를 계산하지 못했습니다.',
          style: _muted.copyWith(fontSize: AppType.bodySize),
        ),
      );
    }
    final onSelectPhase = this.onSelectPhase;
    return DiagonalScrollViewport(
      key: ValueKey('$keyPrefix-phase-cards'),
      keyPrefix: '$keyPrefix-phase-card-diagonal',
      itemCount: cards.length,
      itemHeight: (index) => PlanDetailMetrics.phaseCardHeight(
        (cards[index].tiles.length + 1) ~/ 2,
        credits: cards[index].credits != null,
      ),
      itemGap: PlanDetailMetrics.phaseCardGap,
      verticalInset: 14,
      horizontalInset: 18,
      scrollbarReserve: 10,
      fog: const ScrollFogSpec.panel(color: _panelFill),
      itemBuilder: (context, index) {
        final card = cards[index];
        final number = card.phase.number;
        return _PhaseResourceCard(
          key: ValueKey('$keyPrefix-phase-card-$number'),
          keyPrefix: '$keyPrefix-phase-card-$number',
          phase: card.phase,
          credits: card.credits,
          tiles: card.tiles,
          selected: number == selectedPhase,
          showDelta: _comparing,
          onTap: onSelectPhase == null ? null : () => onSelectPhase(number),
        );
      },
    );
  }

  /// 전체 탭 분야별 그룹(크레딧 밖, [PlanScenarioResourceField] 순서, 빈 그룹 없음).
  List<({PlanScenarioResourceField field, List<PlanDetailResourceTile> tiles})>
  _overallGroups(PlanDetailData data) {
    final overall = data.overall;
    if (overall == null) return const [];
    return [
      for (final field in PlanScenarioResourceField.values)
        if (field != PlanScenarioResourceField.credits)
          if (filter.apply([
                for (final tile in overall.tiles)
                  if (tile.field == field) tile,
              ])
              case final tiles when tiles.isNotEmpty)
            (field: field, tiles: tiles),
    ];
  }

  /// 전체 탭 본문: 크레딧 행 + 분야별 그룹 행.
  Widget _overallList(PlanDetailData data) {
    final overall = data.overall;
    final credits = switch (overall?.credits) {
      final value? when filter.shows(value) => value,
      _ => null,
    };
    final groups = _overallGroups(data);
    if (overall == null || (credits == null && groups.isEmpty)) {
      return Center(
        key: ValueKey('$keyPrefix-overall-empty'),
        child: Text(
          overall == null
              ? '전체 재화를 계산하지 못했습니다.'
              : overall.credits != null || overall.tiles.isNotEmpty
              ? '조건에 맞는 재화가 없습니다.'
              : '이 계획에 필요한 재화가 없습니다.',
          style: _muted.copyWith(fontSize: AppType.bodySize),
        ),
      );
    }
    final columns = overallColumns.clamp(
      planDetailOverallColumnChoices.first,
      planDetailOverallColumnChoices.last,
    );
    final offset = credits == null ? 0 : 1;
    final onSelectResource = this.onSelectResource;
    void Function()? select(String key) => onSelectResource == null
        ? null
        : () => onSelectResource(selectedResource == key ? null : key);
    return DiagonalScrollViewport(
      key: ValueKey('$keyPrefix-overall-list'),
      keyPrefix: '$keyPrefix-overall-diagonal',
      itemCount: groups.length + offset,
      itemHeight: (index) => index < offset
          ? PlanDetailMetrics.overallCreditsHeight
          : PlanDetailMetrics.overallGroupHeight(
              (groups[index - offset].tiles.length + columns - 1) ~/ columns,
            ),
      itemGap: PlanDetailMetrics.overallGap,
      verticalInset: 14,
      horizontalInset: 18,
      scrollbarReserve: 10,
      fog: const ScrollFogSpec.panel(color: _panelFill),
      itemBuilder: (context, index) {
        if (index < offset && credits != null) {
          return _OverallCreditsRow(
            key: ValueKey('$keyPrefix-overall-credits'),
            keyPrefix: '$keyPrefix-overall-credits',
            tile: credits,
            selected: selectedResource == credits.resourceKey,
            showDelta: _comparing,
            onTap: select(credits.resourceKey),
          );
        }
        final group = groups[index - offset];
        return _OverallGroupRow(
          key: ValueKey('$keyPrefix-overall-group-${group.field.name}'),
          keyPrefix: '$keyPrefix-overall',
          field: group.field,
          tiles: group.tiles,
          columns: columns,
          selectedResource: selectedResource,
          showDelta: _comparing,
          onSelect: onSelectResource == null
              ? null
              : (key) => onSelectResource(selectedResource == key ? null : key),
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
  const _PhaseHeader({super.key, required this.phase, this.selected = false});

  final PlanDetailPhase phase;

  /// 페이즈별 탭에서 고른 페이즈(시안 Scenario-Detail-Phase P1 `srow sel`).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final kinds = phase.shortageKinds;
    final content = LayoutBuilder(
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
    );
    if (selected) {
      return DiagonalRow(mark: DiagonalRowMark.selected, child: content);
    }
    return ClipPath(
      clipper: const DiagonalRowClipper(DiagonalRowVariant.plain),
      child: ColoredBox(color: _phaseHeaderFill, child: content),
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

// --- 칩 3개 · 페이즈별 · 전체 탭(FE5-d) ------------------------------------------

/// S3 칩 3개 상태(재화 유형 · 충족 재화 숨기기 · 정렬). 활성 계획 홈은 옛 홈과 같은 상태를 넘긴다.
@immutable
class PlanDetailResourceFilter {
  const PlanDetailResourceFilter({
    this.categories,
    this.hideSatisfied = false,
    this.sort = PlanResourceSort.defaultOrder,
  });

  /// 고른 재화 유형. null이면 전체.
  final Set<PlanResourceCategory>? categories;
  final bool hideSatisfied;
  final PlanResourceSort sort;

  /// 재화 유형을 모두 골랐다.
  bool get allCategories {
    final value = categories;
    return value == null || value.length == PlanResourceCategory.values.length;
  }

  /// 고른 재화 유형 수.
  int get categoryCount =>
      categories?.length ?? PlanResourceCategory.values.length;

  /// 기본값과 다르다(빈 목록 문구를 고른다).
  bool get active =>
      !allCategories || hideSatisfied || sort != PlanResourceSort.defaultOrder;

  /// 고른 재화 유형인가(옛 홈과 같은 분류 [planResourceCategory]).
  bool includes({
    required String resourceKey,
    required String category,
    String? itemId,
  }) {
    final value = categories;
    if (value == null || allCategories) return true;
    return value.contains(
      planResourceCategory(
        id: resourceKey,
        iconAsset:
            planningResourceIconAsset(category: category, itemId: itemId) ??
            category,
      ),
    );
  }

  /// 페이즈 · 전체 타일을 보인다(유형 + 충족 재화 숨기기. 보유를 모르는 재화는 숨기지 않는다).
  bool shows(PlanDetailResourceTile tile) =>
      includes(
        resourceKey: tile.resourceKey,
        category: tile.category,
        itemId: tile.itemId,
      ) &&
      (!hideSatisfied || !tile.satisfied);

  /// 거르고 정렬한다(기본 순서 = 백엔드 순서).
  List<PlanDetailResourceTile> apply(List<PlanDetailResourceTile> tiles) {
    final result = tiles.where(shows).toList();
    if (sort == PlanResourceSort.defaultOrder) return result;
    int compare(PlanDetailResourceTile a, PlanDetailResourceTile b) {
      final value = switch (sort) {
        PlanResourceSort.defaultOrder => 0,
        PlanResourceSort.shortageDescending => (b.shortage ?? -1).compareTo(
          a.shortage ?? -1,
        ),
        PlanResourceSort.requiredDescending => b.required.compareTo(
          a.required,
        ),
        PlanResourceSort.ownedAscending => (a.owned ?? 1 << 52).compareTo(
          b.owned ?? 1 << 52,
        ),
        PlanResourceSort.nameAscending => a.name.compareTo(b.name),
      };
      return value != 0 ? value : a.name.compareTo(b.name);
    }

    result.sort(compare);
    return result;
  }

  /// 병목 카드: 고른 유형의 모자란 재화가 있는 카드만, 타일도 고른 유형(숨기기면 모자란 재화만). 정렬은 걸지 않는다.
  List<PlanDetailBottleneckCard> cards(List<PlanDetailBottleneckCard> cards) {
    if (allCategories && !hideSatisfied) return cards;
    bool selected(PlanDetailCardResource resource) => includes(
      resourceKey: resource.resourceKey,
      category: resource.category,
      itemId: resource.itemId,
    );
    return [
      for (final card in cards)
        if (card.resources.any(
          (resource) => resource.shortage > 0 && selected(resource),
        ))
          PlanDetailBottleneckCard(
            number: card.number,
            phase: card.phase,
            stageId: card.stageId,
            studentId: card.studentId,
            stageName: card.stageName,
            targets: card.targets,
            resources: [
              for (final resource in card.resources)
                if (selected(resource) &&
                    (!hideSatisfied || resource.shortage > 0))
                  resource,
            ],
            hiddenShortages: card.hiddenShortages,
            delayed: card.delayed,
            delta: card.delta,
          ),
    ];
  }

  /// [category]를 넣거나 뺀다.
  PlanDetailResourceFilter toggleCategory(PlanResourceCategory category) {
    final next = {...(categories ?? PlanResourceCategory.values.toSet())};
    next.contains(category) ? next.remove(category) : next.add(category);
    return PlanDetailResourceFilter(
      categories: next,
      hideSatisfied: hideSatisfied,
      sort: sort,
    );
  }

  /// 전체: 모두 골랐으면 모두 빼고, 아니면 모두 고른다(옛 홈과 같다).
  PlanDetailResourceFilter toggleAllCategories() => PlanDetailResourceFilter(
    categories: allCategories
        ? <PlanResourceCategory>{}
        : PlanResourceCategory.values.toSet(),
    hideSatisfied: hideSatisfied,
    sort: sort,
  );

  PlanDetailResourceFilter withHideSatisfied(bool value) =>
      PlanDetailResourceFilter(
        categories: categories,
        hideSatisfied: value,
        sort: sort,
      );

  PlanDetailResourceFilter withSort(PlanResourceSort value) =>
      PlanDetailResourceFilter(
        categories: categories,
        hideSatisfied: hideSatisfied,
        sort: value,
      );
}

/// S3 칩 3개(재화 유형 메뉴 · 충족 재화 숨기기 토글 · 정렬 메뉴). 키는 `<keyPrefix>-filter-category` ·
/// `-hide-satisfied` · `-sort`다(FE5-c2 홈 칩과 같다). [onChanged]가 null이면 누를 수 없다.
class PlanDetailFilterChips extends StatelessWidget {
  const PlanDetailFilterChips({
    super.key,
    required this.keyPrefix,
    required this.filter,
    required this.onChanged,
  });

  final String keyPrefix;
  final PlanDetailResourceFilter filter;
  final ValueChanged<PlanDetailResourceFilter>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final enabled = onChanged != null;
    final all = filter.allCategories;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 값: −1 = 전체, 그 밖 = [PlanResourceCategory.index](null 값은 메뉴가 취소로 본다).
        PopupMenuButton<int>(
          key: ValueKey('$keyPrefix-filter-category'),
          enabled: enabled,
          tooltip: '재화 유형',
          onSelected: (value) => onChanged?.call(
            value < 0
                ? filter.toggleAllCategories()
                : filter.toggleCategory(PlanResourceCategory.values[value]),
          ),
          itemBuilder: (context) => [
            CheckedPopupMenuItem<int>(
              value: -1,
              checked: all,
              child: const Text('전체'),
            ),
            for (final category in PlanResourceCategory.values)
              CheckedPopupMenuItem<int>(
                value: category.index,
                checked:
                    all || (filter.categories?.contains(category) ?? true),
                child: Text(category.label),
              ),
          ],
          child: BaChip(
            label: all ? '재화 유형 · 전체' : '재화 유형 · ${filter.categoryCount}종',
            tone: all ? AppTones.gray : AppTones.pink,
            leading: const Icon(Icons.filter_list_rounded, size: 13),
          ),
        ),
        const SizedBox(width: 8),
        KitPressable(
          key: ValueKey('$keyPrefix-hide-satisfied'),
          onPressed: onChanged == null
              ? null
              : () => onChanged(filter.withHideSatisfied(!filter.hideSatisfied)),
          toggled: filter.hideSatisfied,
          semanticLabel: '충족 재화 숨기기',
          builder: (context, state) => BaChip(
            label: '충족 재화 숨기기',
            tone: filter.hideSatisfied ? AppTones.pink : AppTones.gray,
            leading: const Icon(Icons.visibility_off_outlined, size: 13),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<PlanResourceSort>(
          key: ValueKey('$keyPrefix-sort'),
          enabled: enabled,
          tooltip: '정렬',
          onSelected: (value) => onChanged?.call(filter.withSort(value)),
          itemBuilder: (context) => [
            for (final sort in PlanResourceSort.values)
              CheckedPopupMenuItem<PlanResourceSort>(
                value: sort,
                checked: sort == filter.sort,
                child: Text(sort.menuLabel),
              ),
          ],
          child: BaChip(
            label: filter.sort.menuLabel,
            tone: filter.sort == PlanResourceSort.defaultOrder
                ? AppTones.gray
                : AppTones.pink,
            leading: const Icon(Icons.sort_rounded, size: 13),
          ),
        ),
      ],
    );
  }
}

/// 충족률 색(시안 `.bar2`: 100% 초록 #7fe3bd, 50% 이상 노랑 #ffc66d, 그 아래 분홍 #f2b3ef, 모르면 흐림).
Color _coverageColor(int? percent) {
  if (percent == null) return AppColors.textMuted;
  if (percent >= 100) return AppTones.ok.foreground;
  if (percent >= 50) return AppColors.warning;
  return AppColors.accent;
}

/// 막대 + "n%"(시안: 막대 높이 [height], % 칸 [percentWidth]).
class _CoverageBar extends StatelessWidget {
  const _CoverageBar({
    super.key,
    required this.tile,
    required this.height,
    required this.percentWidth,
    required this.fontSize,
  });

  final PlanDetailResourceTile tile;
  final double height;
  final double percentWidth;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final percent = tile.percent;
    final color = _coverageColor(percent);
    return Row(
      children: [
        Expanded(
          child: SkewBar(fraction: tile.fraction, color: color, height: height),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: percentWidth,
          child: Text(
            percent == null ? '—' : '$percent%',
            maxLines: 1,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: fontSize,
              height: 1,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// "라벨 값"(흐린 라벨 + 굵은 값).
Widget _labeledAmount(String label, String value, {Color? color}) => Text.rich(
  TextSpan(
    text: '$label ',
    children: [
      TextSpan(
        text: value,
        style: TextStyle(
          color: color ?? AppColors.text,
          fontWeight: AppType.bold,
        ),
      ),
    ],
  ),
  maxLines: 1,
  style: _muted,
);

/// 페이즈별 요약 행(시안 `.row` 70px "가장 부족한 재화").
class _PhaseSummaryRow extends StatelessWidget {
  const _PhaseSummaryRow({
    super.key,
    required this.keyPrefix,
    required this.data,
    required this.showDelta,
    this.onTap,
  });

  final String keyPrefix;
  final PlanDetailData? data;
  final bool showDelta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final data = this.data;
    final summary = data?.phaseSummary;
    final tile = summary?.tile;
    final String title;
    final String detail;
    if (summary != null && tile != null) {
      final exit = tile.exit;
      title =
          '${tile.name} · P${summary.phase}에서 ${summary.students}명 중 '
          '${summary.completable}명만 완료';
      detail = exit == 0 && summary.laterStages > 0
          ? 'P${summary.phase} 종료 시 0개 남아서 뒤 페이즈 단계 ${summary.laterStages}개가 막힙니다'
          : 'P${summary.phase} 종료 시 ${_amount(exit)}개 남습니다';
    } else if (data == null) {
      title = '—';
      detail = '';
    } else if (!data.phaseResources.any((phase) => phase.calculated)) {
      title = '—';
      detail = '페이즈별 재화를 계산하지 못했습니다.';
    } else if (data.phaseResources.every(
      (phase) => phase.shortageKinds == null,
    )) {
      // 재화가 없거나 보유를 하나도 모른다.
      final any = data.phaseResources.any(
        (phase) => phase.credits != null || phase.tiles.isNotEmpty,
      );
      title = any ? '보유량을 모릅니다' : '필요한 재화가 없습니다';
      detail = any ? '보유를 아는 재화가 없어 부족을 판단할 수 없습니다.' : '';
    } else {
      title = '부족한 재화가 없습니다';
      detail = '알려진 보유로는 모든 페이즈를 마칠 수 있습니다.';
    }
    final delta = summary?.delta;
    return _ResourceSummaryFrame(
      caption: '가장 부족한 재화',
      title: title,
      detail: detail,
      keyPrefix: keyPrefix,
      icon: tile == null
          ? null
          : ItemIconTile(
              iconAsset: planningResourceIconAsset(
                category: tile.category,
                itemId: tile.itemId,
              ),
              size: const Size(64, 52),
              semanticLabel: tile.name,
            ),
      reserveIcon: true,
      chip: showDelta && delta != null
          ? BaChip(
              key: ValueKey('$keyPrefix-delta'),
              label: delta.label,
              tone: planScenarioDeltaTone(delta.tone),
            )
          : null,
      onTap: onTap,
    );
  }
}

/// 전체 요약 행(시안 `.row` 70px "전체 요구량", 아이콘 없음).
class _OverallSummaryRow extends StatelessWidget {
  const _OverallSummaryRow({
    super.key,
    required this.keyPrefix,
    required this.data,
    required this.showDelta,
  });

  final String keyPrefix;
  final PlanDetailData? data;
  final bool showDelta;

  @override
  Widget build(BuildContext context) {
    final overall = data?.overall;
    String percent(double? rate) =>
        rate == null ? '—' : '${(rate * 100).round()}%';
    final title = overall == null
        ? '—'
        : [
            '필요량의 ${percent(overall.rate)} 확보',
            '${overall.shortageKinds}종 부족',
            '${overall.totalStudents}명 중 ${overall.affectedStudents}명의 계획에 영향',
            if (overall.unknownKinds > 0) '보유 모름 ${overall.unknownKinds}종',
          ].join(' · ');
    final active = overall?.activeRate;
    final rate = overall?.rate;
    final AppTone tone;
    if (active == null || rate == null) {
      tone = AppTones.gray;
    } else if ((rate * 100).round() == (active * 100).round()) {
      tone = AppTones.gray;
    } else {
      tone = rate > active ? AppTones.ok : AppTones.warn;
    }
    return _ResourceSummaryFrame(
      caption: '전체 요구량',
      title: title,
      detail: overall == null
          ? ''
          : '모든 페이즈를 합친 요구량과 지금 보유량 기준 · 페이즈 순서는 따지지 않습니다',
      keyPrefix: keyPrefix,
      reserveIcon: false,
      chip: showDelta && overall != null && active != null
          ? BaChip(
              key: ValueKey('$keyPrefix-delta'),
              label: '활성 ${percent(active)} → ${percent(rate)}',
              tone: tone,
            )
          : null,
    );
  }
}

/// 요약 행 틀(아이콘 · 분홍 캡션 · 굵은 제목 · 흐린 설명 · 칩). [_SummaryRow]와 같은 배치다.
class _ResourceSummaryFrame extends StatelessWidget {
  const _ResourceSummaryFrame({
    required this.keyPrefix,
    required this.caption,
    required this.title,
    required this.detail,
    required this.reserveIcon,
    this.icon,
    this.chip,
    this.onTap,
  });

  final String keyPrefix;
  final String caption;
  final String title;
  final String detail;

  /// 아이콘 자리(64×52)를 둔다(페이즈별). 전체는 아이콘 없이 글자가 왼쪽부터다.
  final bool reserveIcon;
  final Widget? icon;
  final Widget? chip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = this.chip;
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
                if (reserveIcon) ...[
                  SizedBox(width: 64, height: 52, child: icon),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caption,
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
                if (chip != null) ...[const SizedBox(width: 10), chip],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 페이즈별 탭 페이즈 카드(시안 `.srow` 300px).
class _PhaseResourceCard extends StatelessWidget {
  const _PhaseResourceCard({
    super.key,
    required this.keyPrefix,
    required this.phase,
    required this.credits,
    required this.tiles,
    required this.selected,
    required this.showDelta,
    this.onTap,
  });

  final String keyPrefix;
  final PlanDetailPhaseResources phase;

  /// 걸러진 크레딧 줄(없으면 그리지 않는다).
  final PlanDetailResourceTile? credits;

  /// 걸러지고 정렬된 재화 타일.
  final List<PlanDetailResourceTile> tiles;
  final bool selected;
  final bool showDelta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kinds = phase.shortageKinds;
    final credits = this.credits;
    final rows = (tiles.length + 1) ~/ 2;
    Widget tile(int index) => index < tiles.length
        ? _PhaseResourceTile(
            key: ValueKey('$keyPrefix-resource-${tiles[index].resourceKey}'),
            keyPrefix: '$keyPrefix-resource-${tiles[index].resourceKey}',
            tile: tiles[index],
            showDelta: showDelta,
          )
        : const SizedBox.shrink();
    return DiagonalRow(
      mark: selected ? DiagonalRowMark.selected : DiagonalRowMark.none,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cut = diagonalCutDepth(constraints.maxHeight);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              cut + 10,
              PlanDetailMetrics.phaseCardPadding,
              cut + 10,
              PlanDetailMetrics.phaseCardPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: PlanDetailMetrics.phaseCardHeader,
                  child: Row(
                    children: [
                      Text(
                        'P${phase.number}',
                        key: ValueKey('$keyPrefix-number'),
                        maxLines: 1,
                        style: kitDisplayStyle(
                          AppType.headlineSize,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          phase.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bold.copyWith(
                            fontSize: AppType.bodyLargeSize,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      PortraitStrip(
                        studentIds: phase.studentIds,
                        maxVisible: 6,
                        portraitSize: const Size(28, 23),
                      ),
                      const Spacer(),
                      if (kinds != null)
                        BaChip(
                          key: ValueKey('$keyPrefix-shortage'),
                          label: kinds == 0 ? '충분' : '부족 $kinds종',
                          tone: kinds == 0 ? AppTones.ok : AppTones.warn,
                        ),
                    ],
                  ),
                ),
                if (credits != null) ...[
                  const SizedBox(height: PlanDetailMetrics.phaseCardCreditsGap),
                  SizedBox(
                    key: ValueKey('$keyPrefix-credits'),
                    height: PlanDetailMetrics.phaseCardCredits,
                    child: Row(
                      children: [
                        ItemIconTile(
                          iconAsset: planningResourceIconAsset(
                            category: credits.category,
                            itemId: credits.itemId,
                          ),
                          size: const Size(30, 24),
                          semanticLabel: credits.name,
                        ),
                        const SizedBox(width: 8),
                        const Text('크레딧', maxLines: 1, style: _muted),
                        const SizedBox(width: 16),
                        _labeledAmount('진입', _amount(credits.owned)),
                        const SizedBox(width: 14),
                        _labeledAmount('필요', _amount(credits.required)),
                        const SizedBox(width: 14),
                        _labeledAmount(
                          '종료',
                          _amount(credits.exit),
                          color: AppTones.ok.foreground,
                        ),
                      ],
                    ),
                  ),
                ],
                if (rows > 0) ...[
                  const SizedBox(height: PlanDetailMetrics.phaseCardTilesGap),
                  for (var row = 0; row < rows; row += 1) ...[
                    if (row > 0)
                      const SizedBox(height: PlanDetailMetrics.phaseCardTileGap),
                    SizedBox(
                      height: PlanDetailMetrics.phaseCardTile,
                      child: Row(
                        children: [
                          Expanded(child: tile(row * 2)),
                          const SizedBox(
                            width: PlanDetailMetrics.phaseCardColumnGap,
                          ),
                          Expanded(child: tile(row * 2 + 1)),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 페이즈 카드 재화 타일(시안: 바탕 skewX −10° rgba(16,24,35,.55), 아이콘 59×48, 이름 + 활성 대비 칩, "진입 · 필요 ·
/// 종료", 막대 6px + %).
class _PhaseResourceTile extends StatelessWidget {
  const _PhaseResourceTile({
    super.key,
    required this.keyPrefix,
    required this.tile,
    required this.showDelta,
  });

  final String keyPrefix;
  final PlanDetailResourceTile tile;
  final bool showDelta;

  @override
  Widget build(BuildContext context) {
    final delta = tile.delta;
    return SkewBox(
      fill: _tileFill,
      radius: 7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 8),
        child: Row(
          children: [
            ItemIconTile(
              iconAsset: planningResourceIconAsset(
                category: tile.category,
                itemId: tile.itemId,
              ),
              size: const Size(59, 48),
              semanticLabel: tile.name,
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
                          tile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bold.copyWith(fontSize: AppType.bodyPlusSize),
                        ),
                      ),
                      if (showDelta && delta != null) ...[
                        const SizedBox(width: 8),
                        BaChip(
                          key: ValueKey('$keyPrefix-delta'),
                          label: delta.label,
                          tone: planScenarioDeltaTone(delta.tone),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '진입 ${_amount(tile.owned)} · 필요 ${_amount(tile.required)} · '
                    '종료 ${_amount(tile.exit)}',
                    key: ValueKey('$keyPrefix-amounts'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _muted.copyWith(fontSize: AppType.captionPlusSize),
                  ),
                  const SizedBox(height: 6),
                  _CoverageBar(
                    key: ValueKey('$keyPrefix-coverage'),
                    tile: tile,
                    height: 6,
                    percentWidth: 34,
                    fontSize: AppType.captionSize,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 전체 탭 본문 위 줄(시안 `.plain` 30px "재화 n종 · 한 행에 [2|3|4|5]" + 범례).
class _OverallHeader extends StatelessWidget {
  const _OverallHeader({
    super.key,
    required this.keyPrefix,
    required this.kinds,
    required this.columns,
    required this.onColumns,
    required this.showLegend,
  });

  final String keyPrefix;
  final int kinds;
  final int columns;
  final ValueChanged<int>? onColumns;

  /// "= 같음 · 신규 = 이 시나리오에만 · ± 활성 대비"(비교가 있을 때).
  final bool showLegend;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 16),
    child: Row(
      children: [
        SubHeader('재화 $kinds종', fontSize: AppType.microSize),
        const SizedBox(width: 16),
        Text(
          '한 행에',
          maxLines: 1,
          style: _muted.copyWith(fontSize: AppType.captionPlusSize),
        ),
        const SizedBox(width: 8),
        SkewSegmented<int>(
          key: ValueKey('$keyPrefix-columns'),
          segments: [
            for (final count in planDetailOverallColumnChoices)
              SkewSegment(value: count, label: '$count'),
          ],
          selected: columns,
          onChanged: onColumns,
          height: 26,
          fontSize: AppType.captionSize,
          horizontalPadding: 10,
          spacing: 4,
        ),
        if (showLegend) ...[
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              '= 같음 · 신규 = 이 시나리오에만 · ± 활성 대비',
              key: ValueKey('$keyPrefix-legend'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _muted.copyWith(fontSize: AppType.captionSize),
            ),
          ),
        ],
      ],
    ),
  );
}

/// 전체 탭 크레딧 행(시안 `.srow` 54px: 보유 · 필요, 막대 8px + %, 부족, 활성 대비 칩).
class _OverallCreditsRow extends StatelessWidget {
  const _OverallCreditsRow({
    super.key,
    required this.keyPrefix,
    required this.tile,
    required this.selected,
    required this.showDelta,
    this.onTap,
  });

  final String keyPrefix;
  final PlanDetailResourceTile tile;
  final bool selected;
  final bool showDelta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shortage = tile.shortage;
    final delta = tile.delta;
    final deltaLabel = delta == null
        ? null
        : delta.tone == PlanScenarioDeltaTone.same ||
              delta.tone == PlanScenarioDeltaTone.only
        ? delta.label
        : '활성보다 ${delta.label}';
    return DiagonalRow(
      mark: selected ? DiagonalRowMark.selected : DiagonalRowMark.none,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cut = diagonalCutDepth(constraints.maxHeight);
          // 안쪽 여백 = 사선 깊이 + 10(시안 19.5).
          return Padding(
            padding: EdgeInsets.fromLTRB(cut + 10, 0, cut + 10, 0),
            child: Row(
              children: [
                ItemIconTile(
                  iconAsset: planningResourceIconAsset(
                    category: tile.category,
                    itemId: tile.itemId,
                  ),
                  size: const Size(44, 36),
                  semanticLabel: tile.name,
                ),
                const SizedBox(width: 12),
                Text(
                  '크레딧',
                  maxLines: 1,
                  style: _bold.copyWith(fontSize: AppType.titleSmallSize),
                ),
                const SizedBox(width: 14),
                // 좁은 창에서 막대 자리를 남기도록 폭을 묶는다.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text.rich(
                    TextSpan(
                      text: '보유 ',
                      children: [
                        TextSpan(
                          text: _amount(tile.owned),
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: AppType.bold,
                          ),
                        ),
                        const TextSpan(text: ' · 필요 '),
                        TextSpan(
                          text: _amount(tile.required),
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: AppType.bold,
                          ),
                        ),
                      ],
                    ),
                    key: ValueKey('$keyPrefix-amounts'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _muted,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _CoverageBar(
                    key: ValueKey('$keyPrefix-coverage'),
                    tile: tile,
                    height: 8,
                    percentWidth: 40,
                    fontSize: AppType.bodySmallSize,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  shortage == null
                      ? '—'
                      : shortage > 0
                      ? '−${_amount(shortage)}'
                      : '충분',
                  key: ValueKey('$keyPrefix-shortage'),
                  maxLines: 1,
                  style: kitDisplayStyle(
                    AppType.titleSize,
                    color: (shortage ?? 0) > 0
                        ? AppColors.accent
                        : AppTones.ok.foreground,
                  ),
                ),
                if (showDelta && delta != null && deltaLabel != null) ...[
                  const SizedBox(width: 12),
                  BaChip(
                    key: ValueKey('$keyPrefix-delta'),
                    label: deltaLabel,
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

/// 전체 탭 분야 그룹 행(시안 `.srow`: 머리 줄 "분야 · n종 · 부족 n종/충분" + [columns]열 타일).
class _OverallGroupRow extends StatelessWidget {
  const _OverallGroupRow({
    super.key,
    required this.keyPrefix,
    required this.field,
    required this.tiles,
    required this.columns,
    required this.selectedResource,
    required this.showDelta,
    this.onSelect,
  });

  final String keyPrefix;
  final PlanScenarioResourceField field;
  final List<PlanDetailResourceTile> tiles;
  final int columns;
  final String? selectedResource;
  final bool showDelta;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final known = tiles.where((tile) => tile.owned != null).toList();
    final short = known.where((tile) => (tile.shortage ?? 0) > 0).length;
    final rows = (tiles.length + columns - 1) ~/ columns;
    final onSelect = this.onSelect;
    return DiagonalRow(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cut = diagonalCutDepth(constraints.maxHeight);
          // 안쪽 여백 = 사선 깊이 + 10(시안 1줄 28.0 · 2줄 38.2).
          return Padding(
            padding: EdgeInsets.fromLTRB(cut + 10, 12, cut + 10, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 24,
                  child: Row(
                    children: [
                      SubHeader(field.label, fontSize: AppType.captionSize),
                      const SizedBox(width: 8),
                      Text(
                        '${tiles.length}종',
                        maxLines: 1,
                        style: _muted.copyWith(
                          fontSize: AppType.captionPlusSize,
                        ),
                      ),
                      const Spacer(),
                      if (known.isNotEmpty)
                        BaChip(
                          key: ValueKey('$keyPrefix-group-${field.name}-shortage'),
                          label: short == 0 ? '충분' : '부족 $short종',
                          tone: short == 0 ? AppTones.ok : AppTones.warn,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (var row = 0; row < rows; row += 1)
                  Padding(
                    padding: EdgeInsets.only(
                      top: row == 0
                          ? 0
                          : PlanDetailMetrics.overallTileRow -
                                PlanDetailMetrics.overallTileHeight,
                    ),
                    child: SizedBox(
                      height: PlanDetailMetrics.overallTileHeight,
                      child: Row(
                        children: [
                          for (var column = 0; column < columns; column += 1) ...[
                            if (column > 0)
                              const SizedBox(
                                width: PlanDetailMetrics.overallTileGap,
                              ),
                            Expanded(
                              child: switch (row * columns + column) {
                                final index when index < tiles.length =>
                                  _OverallTile(
                                    key: ValueKey(
                                      '$keyPrefix-tile-${tiles[index].resourceKey}',
                                    ),
                                    keyPrefix:
                                        '$keyPrefix-tile-${tiles[index].resourceKey}',
                                    tile: tiles[index],
                                    selected:
                                        selectedResource ==
                                        tiles[index].resourceKey,
                                    showMark: showDelta,
                                    onTap: onSelect == null
                                        ? null
                                        : () => onSelect(
                                            tiles[index].resourceKey,
                                          ),
                                  ),
                                _ => const SizedBox.shrink(),
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 전체 탭 타일(시안: 바탕 skewX −10°, 아이콘 44×36, 이름 + 마크 = / ±n / 신규, "보유 / 필요", 막대 4px + %).
class _OverallTile extends StatelessWidget {
  const _OverallTile({
    super.key,
    required this.keyPrefix,
    required this.tile,
    required this.selected,
    required this.showMark,
    this.onTap,
  });

  final String keyPrefix;
  final PlanDetailResourceTile tile;
  final bool selected;
  final bool showMark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final delta = tile.delta;
    // 마크(시안 범례 "= 같음 · 신규 = 이 시나리오에만 · ± 활성 대비").
    final (String? mark, Color markColor) = switch (delta) {
      null => (null, AppColors.textMuted),
      PlanScenarioDelta(tone: PlanScenarioDeltaTone.only) => (
        '신규',
        AppColors.accent,
      ),
      PlanScenarioDelta(tone: PlanScenarioDeltaTone.same, :final label) => (
        label == '활성 계획과 같음' ? '=' : label,
        AppColors.textMuted,
      ),
      PlanScenarioDelta(tone: PlanScenarioDeltaTone.better, :final label) => (
        label,
        AppTones.ok.foreground,
      ),
      PlanScenarioDelta(tone: PlanScenarioDeltaTone.worse, :final label) => (
        label,
        AppColors.warning,
      ),
      PlanScenarioDelta(:final label) => (label, AppColors.textMuted),
    };
    return KitPressable(
      onPressed: onTap,
      semanticLabel: tile.name,
      builder: (context, state) => SkewBox(
        fill: selected ? const Color.fromRGBO(52, 36, 58, 0.85) : _tileFill,
        border: selected ? AppColors.accent : null,
        borderWidth: selected ? 1.5 : 0,
        radius: 6,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Row(
            children: [
              ItemIconTile(
                iconAsset: planningResourceIconAsset(
                  category: tile.category,
                  itemId: tile.itemId,
                ),
                size: const Size(44, 36),
                semanticLabel: tile.name,
              ),
              const SizedBox(width: 10),
              Expanded(
                // 좁은 칸(5열 · 작은 창)에서는 마크 · 막대를 빼고 이름 · "보유 / 필요"만 줄여 보인다.
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 150;
                    final amounts = Text(
                      '${_amount(tile.owned)} / ${_amount(tile.required)}',
                      key: ValueKey('$keyPrefix-amounts'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _muted.copyWith(fontSize: AppType.captionSize),
                    );
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                tile.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _bold.copyWith(
                                  fontSize: AppType.bodySmallSize,
                                ),
                              ),
                            ),
                            if (showMark && mark != null && !narrow) ...[
                              const SizedBox(width: 6),
                              Text(
                                mark,
                                key: ValueKey('$keyPrefix-mark'),
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: AppFonts.body,
                                  fontFamilyFallback: AppFonts.fallback,
                                  fontSize: AppType.microPlusSize,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                  color: markColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (narrow)
                          Row(children: [Flexible(child: amounts)])
                        else
                          Row(
                            children: [
                              amounts,
                              const SizedBox(width: 8),
                              Expanded(
                                child: _CoverageBar(
                                  tile: tile,
                                  height: 4,
                                  percentWidth: 30,
                                  fontSize: AppType.microPlusSize,
                                ),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
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
    final infoTop =
        infoCaptionTop +
        (PlanDetailMetrics.menuInfoTop - PlanDetailMetrics.menuInfoCaptionTop);
    // SL2: 1280×720에서는 정보 줄 4 · 5번째가 창 밖이었다 — 내용 아래 끝이 레일에 들어가게 세로 값만 줄인다.
    final scale = frame.scaleFor(
      info.isNotEmpty
          ? infoTop +
                PlanDetailMetrics.menuInfoPitch * (info.length - 1) +
                PlanDetailMetrics.menuInfoHeight
          : infoCaption != null
          ? infoCaptionTop + 18
          : shown.isEmpty
          ? PlanDetailMetrics.menuCurrentTop +
                PlanDetailMetrics.menuCurrentHeight
          : PlanDetailMetrics.menuActionTops[shown.length - 1] +
                PlanDetailMetrics.menuActionHeight,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 20,
          top: top + PlanDetailMetrics.menuTitleTop * scale,
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
          top: top + PlanDetailMetrics.menuCaptionTop * scale,
          height: 18,
          width: math.max(0.0, frame.width(top) - 6),
          child: Text(caption, maxLines: 1, style: _captionStyle),
        ),
        Positioned.fromRect(
          rect: frame.row(
            PlanDetailMetrics.menuCurrentTop,
            PlanDetailMetrics.menuCurrentHeight,
            scale: scale,
          ),
          child: RailButton(
            key: ValueKey('$keyPrefix-current'),
            variant: RailButtonVariant.selectedPink,
            height: PlanDetailMetrics.menuCurrentHeight * scale,
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
              scale: scale,
            ),
            child: PlanScenarioDetailMenu._withTooltip(
              action.onPressed == null ? action.tooltip : null,
              RailButton(
                key: ValueKey(action.key),
                variant: action.variant,
                height: PlanDetailMetrics.menuActionHeight * scale,
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
            top: top + infoCaptionTop * scale,
            height: 18,
            width: math.max(0.0, frame.width(top) - 6),
            child: Text(infoCaption, maxLines: 1, style: _captionStyle),
          ),
        for (final (index, (label, value)) in info.indexed)
          Positioned.fromRect(
            rect: frame.row(
              infoTop + PlanDetailMetrics.menuInfoPitch * index,
              PlanDetailMetrics.menuInfoHeight,
              scale: scale,
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
