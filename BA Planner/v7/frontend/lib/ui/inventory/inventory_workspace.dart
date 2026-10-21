// 인벤토리 4섹션 화면(FE6-a, 시안 Inventory "부족한 것" 보기, E 보고서 §1).
//
// - A 사이드바(왼쪽 사다리꼴): "목록 · 분석" seg → (목록) "아이템 · 장비" seg → 보기("부족한 것 n종"
//   기본 FD-094 / "전체 n종") → 종류 버튼(category 1:1 FD-095, 사선을 따라 폭이 줄고 "부족 n" 칩) → 주요 재화 카드
//   (크레딧 · 엘리그마, 누르면 상세).
// - B KPI 띠: 보유 품목 · 부족 재화 · 과잉 재화(FD-040) · 계획 충족률(FD-031 (a)) · 최근 감소 · 마지막 스캔. 지난 스캔
//   대비 증감 · 최근 감소 · 마지막 스캔은 이력(FE6-f, `inventory_history.dart`)에서 오고, 모르면 `—`다.
// - C 부족 위험도 순위(평행사변형): 제목 + (i) + 정렬 칩, 위험도 행(막대 폭 = 점수, FD-030 (b)). 행을 누르면 D가 바뀐다.
//   후보 승인 패널(FE8-g5 전까지)과 알림 줄은 목록 위 띠에 둔다.
// - D 상세(오른쪽 사다리꼴): 머리(아이콘 · 이름 · FB-3 메타) · kv(보유 · 필요 · 부족 · 충족률) · 수량 직접 고치기 칸 ·
//   사용 학생(FD-101) · 보충 방법(FB-3 획득처) · 최근 변화(FE6-f 스파크라인, 한 재화 안 FD-033) · 액션 3개(FD-125).
// - 분석 모드(FE6-c, 시안 Inventory-Analysis): A 사이드바 아래쪽이 분석 메뉴로 바뀌고 B·C·D 대신 S1 학교별 · S2 오파츠 ·
//   S4 종류 × 티어 · S5 최근 변화 네 섹션을 그린다(`inventory_analysis_sections.dart`).
// - 티어별 충족률(FE6-e, 시안 Inventory-Tiers): 분석 모드 안에서 사이드바는 그대로 두고 네 섹션 대신 T1 기술 노트 · T2 BD
//   (부유 패널) · T4 오파츠 · T5 부족 상위 · T6 요약을 그린다(`inventory_tiers_sections.dart`). 분석 ↔ 티어 교체는 섹션
//   모션 규칙(부착면별 intro/outro, frontend-section-direction-and-user-flows.md §1.4)을 따른다: 나가는 섹션이 outro
//   방향으로 빠진 뒤 들어오는 섹션이 intro 방향으로 들어온다(각 360ms). 목록 ↔ 분석은 FE6-c 그대로 바로 바뀐다.
// - 오파츠 확장(FE6-d, 시안 Inventory-Analysis-Opa): S2 "확장"을 누르면 사이드바(180°) · S1(80°) · S4(0°) · S5(260°)가
//   부착면 쪽으로 빠지고(360ms), S2가 오른쪽 · 위 부착을 유지한 채 확장 rect로 커지며(360ms, 키트 `section_morph.dart` 실수
//   보간, 점 → 아이콘 크로스페이드) 마지막에 선택 오파츠 상세 열이 나타난다(220ms). "축소"는 같은 값을 거꾸로 지나는
//   역순이다(`inventory_opa_sections.dart`).
// - 이동 의도로 고른 행(tidy1, FE7-d 발견 2): [InventoryRevealRequest]가 오면 그 행(목록 · 타일)이 처음 그려진 뒤 한 번,
//   화면 밖이면 목록 가운데로 스크롤한다. 키트 [DiagonalScrollViewport]는 고치지 않고 행 안에서 자기 Scrollable position을 쓴다.
// 섹션 rect는 Studio 문서(`ui/studio/inventory_studio_layout.dart`)를 따르고, 섹션 안 좌표는 시안 값(섹션 위 기준)이다.
// 작은 창에서는 각 내용 묶음이 시안 최소 크기 아래로 줄지 않고 자기 상자(사선을 따라 계산한 rect)로 잘린다(전체
// 화면을 줄이지 않는다).
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/anchored_flyout.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_row.dart';
import '../kit/diagonal_scroll_viewport.dart';
import '../kit/game_assets.dart';
import '../kit/game_image.dart';
import '../kit/info_popover.dart';
import '../kit/item_icon_tile.dart';
import '../kit/kit_overlay.dart' show KitOverlayAlign, KitOverlayPlacement;
import '../kit/kit_pressable.dart';
import '../kit/scroll_viewport_fog.dart';
import '../kit/section_morph.dart';
import '../kit/shortage_flyout.dart';
import '../kit/skew_bar.dart';
import '../kit/portrait_strip.dart';
import '../kit/skew_controls.dart';
import '../kit/stat_chart.dart';
import '../kit/titles.dart';
import '../models/planning_resource_assets.dart';
import '../models/school_labels.dart';
import '../studio/inventory_studio_layout.dart';
import '../studio/section_template.dart' show SectionCanvasElement;
import '../widgets/growth_calculator_section.dart'
    show growthCalculatorCompactNumber, growthCalculatorNumber;
import '../widgets/empty_state_panel.dart';
import '../widgets/section_surface.dart';
import '../widgets/section_template_surface.dart';
import 'inventory_analysis.dart';
import 'inventory_analysis_charts.dart';
import 'inventory_controller.dart';
import 'inventory_history.dart';
import 'inventory_history_charts.dart';
import 'inventory_tiers.dart';
import 'inventory_view_model.dart';
import '../tutorial/tutorial_script.dart';
import '../tutorial_targets/tutorial_hooks.dart';

part 'inventory_analysis_sections.dart';
part 'inventory_opa_sections.dart';
part 'inventory_tiers_sections.dart';

/// 시안 값(섹션 위 기준, A·B는 y=209.2, C·D는 y=365.2).
abstract final class InventoryMetrics {
  // A 사이드바.
  static const sidebarLeft = 16.0;
  static const sidebarTextLeft = 20.0;
  static const sidebarRightMargin = 22.0;
  static const modeSegTop = 22.0;
  static const kindSegTop = 70.0;
  static const viewCaptionTop = 126.0;
  static const viewButtonTop = 152.0;
  static const viewButtonHeight = 44.0;
  static const viewButtonPitch = 52.0;
  static const categoryCaptionTop = 268.0;
  static const categoryButtonTop = 294.0;
  static const categoryButtonHeight = 40.0;
  static const categoryButtonPitch = 46.0;
  static const currencyCaptionGap = 22.0;
  static const currencyCardOffset = 26.0;
  static const currencyCardHeight = 66.0;
  static const currencyCardPitch = 74.0;

  // B KPI 띠.
  static const kpiTop = 14.0;
  static const kpiHeight = 110.0;
  static const kpiLeft = 62.0;
  static const kpiRight = 40.0;

  // C 위험도 목록.
  static const panelInset = 12.0;
  static const panelHorizontalInset = 14.0;
  static const titleTop = 28.0;
  static const titleHeight = 28.0;
  static const titleLeft = 31.0;
  static const titleRight = 46.0;
  static const ruleTop = 67.0;
  static const bandTop = 80.0;
  static const messageHeight = 22.0;
  static const rowsTop = 86.0;
  static const rowHeight = 58.0;
  static const rowGap = 8.0;
  static const rowInset = 8.0;
  static const rowScrollbarReserve = 22.0;

  // D 상세.
  static const detailTitleTop = 20.0;
  static const detailTitleHeight = 40.0;
  static const detailRuleTop = 65.0;
  static const detailBlockTop = 82.0;
  static const detailLeftInset = 30.0;
  static const detailRightMargin = 22.0;
  static const headerHeight = 100.0;
  static const kvHeight = 74.0;
  static const editorHeight = 52.0;
  static const noteHeight = 24.0;
  static const subHeaderHeight = 24.0;
  static const useRowHeight = 46.0;
  static const methodRowHeight = 44.0;
  static const actionHeight = 40.0;

  /// 최근 변화 스파크라인 줄(FE6-f, 시안 `.row` 112: 안쪽 왼쪽 31.7 · 오른쪽 14, svg 높이 92 · 폭 = 줄 폭 − 70).
  static const sparklineRowHeight = 112.0;
  static const sparklineLeft = 31.7;
  static const sparklineRight = 14.0;
  static const sparklineWidthInset = 70.0;

  /// 확인 필요 줄(FB-10b, 표시가 있을 때만): 칩 · 설명 · "이 값이 맞습니다".
  static const reviewHeight = 40.0;
  static const blockGap = 8.0;
  static const maxUses = 4;
  static const maxMethods = 3;
}

/// 스크롤 패널 색(시안 rgba(26,44,59,.9), 테두리 rgba(56,81,107,.72)).
const inventoryPanelFill = Color.fromRGBO(26, 44, 59, 0.9);
const inventoryPanelBorder = Color.fromRGBO(56, 81, 107, 0.72);

const _muted = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionSize,
  height: 1.3,
  fontWeight: AppType.medium,
  color: AppColors.textMuted,
);

const _captionStyle = TextStyle(
  fontFamily: AppFonts.display,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  height: 1.2,
  color: AppColors.textMuted,
);

const _body = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodyPlusSize,
  height: 1.25,
  fontWeight: AppType.semiBold,
  color: AppColors.text,
);

/// 수량 표기: 10만 이상은 줄여 쓰고(98.4M), 그 아래는 천 단위 쉼표(1,020).
String inventoryAmount(int value) => value >= 100000
    ? growthCalculatorCompactNumber(value)
    : growthCalculatorNumber(value);

String _amountOrDash(int? value) => value == null ? '—' : inventoryAmount(value);

String _percentOrDash(double? value) =>
    value == null ? '—' : '${(value * 100).round()}%';

/// 위험도 색: 높으면 핑크, 낮으면 노랑.
Color inventoryRiskColor(double? score) =>
    (score ?? 0) >= inventoryRiskHighThreshold
    ? AppColors.accent
    : AppColors.warning;

/// 섹션 사각형의 네 꼭짓점과 왼쪽·오른쪽 변.
@immutable
class _SectionQuad {
  const _SectionQuad(this.topLeft, this.topRight, this.bottomRight, this.bottomLeft);

  factory _SectionQuad.of(
    Size size,
    String id, {
    bool analysis = false,
    bool tiers = false,
  }) {
    final section = tiers
        ? inventoryTiersSection(id)
        : analysis
        ? inventoryAnalysisSection(id)
        : inventorySection(id);
    return _SectionQuad.fromPolygon(sectionCanvasElementPolygon(size, section));
  }

  /// 캔버스 좌표 꼭짓점 넷(섹션 polygon · 확장 중 morph polygon)에서.
  factory _SectionQuad.fromPolygon(List<Offset> polygon) {
    final points = [...polygon]..sort((a, b) => a.dy.compareTo(b.dy));
    final top = [points[0], points[1]]..sort((a, b) => a.dx.compareTo(b.dx));
    final bottom = [points[2], points[3]]
      ..sort((a, b) => a.dx.compareTo(b.dx));
    return _SectionQuad(top[0], top[1], bottom[1], bottom[0]);
  }

  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  double get top => topLeft.dy;
  double get bottom => bottomLeft.dy;

  static double _edgeX(Offset top, Offset bottom, double y) {
    final span = bottom.dy - top.dy;
    if (span <= 0) return top.dx;
    final progress = ((y - top.dy) / span).clamp(0.0, 1.0).toDouble();
    return top.dx + (bottom.dx - top.dx) * progress;
  }

  double leftAt(double y) => _edgeX(topLeft, bottomLeft, y);
  double rightAt(double y) => _edgeX(topRight, bottomRight, y);
}

/// 내용 묶음을 시안 최소 크기 아래로 줄이지 않고, 넘치는 부분은 자른다(작은 창·테스트 viewport).
class _Fit extends StatelessWidget {
  const _Fit({
    required this.minWidth,
    this.minHeight = 0,
    this.clip = true,
    required this.child,
  });

  final double minWidth;
  final double minHeight;

  /// false면 넘친 부분(그림자·빛)을 자르지 않는다. 배치는 같다.
  final bool clip;
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
      final box = OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: width,
        maxWidth: width,
        minHeight: height,
        maxHeight: height,
        child: child,
      );
      return clip ? ClipRect(child: box) : box;
    },
  );
}

/// 이동 의도로 고른 행을 한 번 보이게 하는 요청(tidy1, FE7-d 발견 2). 의도마다 새로 만든다. 그 행이 처음 그려진 뒤 한 번만
/// 스크롤한다(행이 다시 그려지거나 보기를 바꿔도 다시 스크롤하지 않는다).
class InventoryRevealRequest {
  InventoryRevealRequest(this.resourceKey);

  final String resourceKey;
  bool _done = false;

  /// 처음 부르면 true(스크롤한다), 그 뒤로는 false.
  bool consume() {
    if (_done) return false;
    _done = true;
    return true;
  }
}

/// 인벤토리 4섹션. 스캔 후보 승인은 스캔 탭 아이템 결과 검토 보드가 한다(FE8-g5b — 예전 후보 승인 띠 자리는 없앴다).
class InventoryWorkspace extends StatelessWidget {
  const InventoryWorkspace({
    super.key,
    required this.controller,
    required this.onOpenPlan,
    required this.onOpenScan,
    this.reveal,
  });

  final InventoryController controller;

  /// 계획 탭으로 간다("계획에서 보기" 등). 볼 재화가 있으면 그 resource_key, 없으면 null(tidy1, FD-108).
  final ValueChanged<String?> onOpenPlan;
  final VoidCallback onOpenScan;

  /// 목록 · 타일에서 보이게 할 행(이동 의도, tidy1).
  final InventoryRevealRequest? reveal;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(
        constraints.maxWidth.isFinite ? constraints.maxWidth : 1280,
        constraints.maxHeight.isFinite ? constraints.maxHeight : 720,
      );
      final analysis = controller.screenMode == InventoryScreenMode.analysis;
      return SizedBox.fromSize(
        key: const ValueKey('inventory-page'),
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 분석 모드의 사이드바 내용은 stage가 맨 위에 둔다(오파츠 확장 때 사이드바도 섹션처럼 빠진다).
            if (analysis)
              Positioned.fill(
                child: _InventoryAnalysisStage(
                  controller: controller,
                  onOpenPlan: onOpenPlan,
                  size: size,
                  tiers: controller.tiersOpen,
                  expanded: controller.oopartExpanded,
                  sidebar: _sidebar(size),
                ),
              )
            else ...[
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const ValueKey('inventory-surfaces'),
                    painter: _InventorySurfacesPainter(
                      _InventoryScreen.list.surfaces,
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: _detail(context, size)),
              Positioned.fill(child: _risk(context, size)),
              Positioned.fill(child: _kpis(size)),
              Positioned.fill(child: _sidebar(size)),
            ],
          ],
        ),
      );
    },
  );

  // --- A 사이드바 -------------------------------------------------------------

  Widget _sidebar(Size size) {
    final quad = _SectionQuad.of(size, inventorySidebarSectionId);
    final top = quad.top;
    double width(double y) => math.max(
      0.0,
      quad.rightAt(y) -
          InventoryMetrics.sidebarLeft -
          InventoryMetrics.sidebarRightMargin,
    );
    Rect row(double offset, double height) => Rect.fromLTWH(
      InventoryMetrics.sidebarLeft,
      top + offset,
      width(top + offset),
      height,
    );
    final mode = controller.mode;
    final board = controller.board;
    final enabled = controller.loaded && !controller.loading;
    final categories = board.categories(mode);
    final children = <Widget>[
      Positioned(
        left: InventoryMetrics.sidebarTextLeft,
        top: top + InventoryMetrics.modeSegTop,
        width: width(top + InventoryMetrics.modeSegTop),
        height: AppControlHeights.segmented,
        child: _Fit(
          minWidth: 220,
          minHeight: AppControlHeights.segmented,
          // 두 칸을 따로 둔다(목록 · 분석 키를 FE6-a 그대로 유지, 배치는 한 seg의 간격 6과 같다).
          child: Row(
            children: [
              for (final screen in InventoryScreenMode.values) ...[
                if (screen != InventoryScreenMode.values.first)
                  const SizedBox(width: 6),
                SkewSegmented<InventoryScreenMode>(
                  key: ValueKey('inventory-mode-${screen.name}'),
                  segments: [SkewSegment(value: screen, label: screen.label)],
                  selected: controller.screenMode == screen ? screen : null,
                  onChanged: controller.setScreenMode,
                ),
              ],
            ],
          ),
        ),
      ),
    ];
    if (controller.screenMode == InventoryScreenMode.analysis) {
      children.addAll(_analysisSidebar(top, width, row));
      return Stack(clipBehavior: Clip.none, children: children);
    }
    children.addAll([
      Positioned(
        left: InventoryMetrics.sidebarTextLeft,
        top: top + InventoryMetrics.kindSegTop,
        width: width(top + InventoryMetrics.kindSegTop),
        height: AppControlHeights.segmented,
        child: _Fit(
          minWidth: 220,
          minHeight: AppControlHeights.segmented,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SkewSegmented<InventoryListMode>(
              key: const ValueKey('inventory-kind'),
              segments: [
                for (final value in InventoryListMode.values)
                  SkewSegment(value: value, label: value.label),
              ],
              selected: mode,
              onChanged: enabled ? controller.setMode : null,
            ),
          ),
        ),
      ),
      _sideCaption(top + InventoryMetrics.viewCaptionTop, width, '보기'),
      Positioned.fromRect(
        rect: row(
          InventoryMetrics.viewButtonTop,
          InventoryMetrics.viewButtonHeight,
        ),
        child: _railButton(
          key: 'inventory-view-shortage',
          variant: controller.view == InventoryView.shortage
              ? RailButtonVariant.selectedBlue
              : RailButtonVariant.ghost,
          height: InventoryMetrics.viewButtonHeight,
          onPressed: enabled
              ? () => controller.setView(InventoryView.shortage)
              : null,
          label: '부족한 것',
          trailing: [
            Text(
              board.hasShortages ? '${board.shortageCount(mode)}종' : '—',
              key: const ValueKey('inventory-view-shortage-count'),
              style: _muted.copyWith(fontSize: AppType.bodySmallSize),
            ),
            if (board.unknownPlannedCount(mode) > 0) ...[
              const SizedBox(width: 6),
              Text(
                '모름 ${board.unknownPlannedCount(mode)}',
                style: _muted.copyWith(fontSize: AppType.bodySmallSize),
              ),
            ],
          ],
        ),
      ),
      Positioned.fromRect(
        rect: row(
          InventoryMetrics.viewButtonTop + InventoryMetrics.viewButtonPitch,
          InventoryMetrics.viewButtonHeight,
        ),
        child: _railButton(
          key: 'inventory-view-all',
          variant: controller.view == InventoryView.all
              ? RailButtonVariant.selectedBlue
              : RailButtonVariant.ghost,
          height: InventoryMetrics.viewButtonHeight,
          onPressed: enabled ? () => controller.setView(InventoryView.all) : null,
          label: '전체',
          trailing: [
            Text(
              '${board.allCount(mode)}종',
              key: const ValueKey('inventory-view-all-count'),
              style: _muted.copyWith(fontSize: AppType.bodySmallSize),
            ),
          ],
        ),
      ),
      _sideCaption(top + InventoryMetrics.categoryCaptionTop, width, '종류'),
    ]);
    var y = InventoryMetrics.categoryButtonTop;
    for (final category in categories) {
      children.add(
        Positioned.fromRect(
          rect: row(y, InventoryMetrics.categoryButtonHeight),
          child: _railButton(
            key: 'inventory-category-${category.category}',
            variant: controller.category == category.category
                ? RailButtonVariant.selectedPink
                : RailButtonVariant.ghost,
            height: InventoryMetrics.categoryButtonHeight,
            onPressed: enabled
                ? () => controller.toggleCategory(category.category)
                : null,
            label: category.label,
            trailing: [
              if (category.shortageCount > 0) ...[
                BaChip(
                  label: '부족 ${category.shortageCount}',
                  tone: AppTones.pink,
                ),
                const SizedBox(width: 8),
              ],
              SizedBox(
                width: 32,
                child: Text(
                  '${category.count}',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  style: _muted.copyWith(fontSize: AppType.bodySmallSize),
                ),
              ),
            ],
          ),
        ),
      );
      y += InventoryMetrics.categoryButtonPitch;
    }
    final currencies = board.currencies;
    if (currencies.isNotEmpty) {
      final captionTop =
          y -
          InventoryMetrics.categoryButtonPitch +
          InventoryMetrics.categoryButtonHeight +
          InventoryMetrics.currencyCaptionGap;
      children.add(_sideCaption(top + captionTop, width, '주요 재화'));
      var cardTop = captionTop + InventoryMetrics.currencyCardOffset;
      for (final currency in currencies) {
        children.add(
          Positioned.fromRect(
            rect: row(cardTop, InventoryMetrics.currencyCardHeight),
            child: _Fit(
              minWidth: 320,
              minHeight: InventoryMetrics.currencyCardHeight,
              child: _CurrencyCard(
                key: ValueKey('inventory-currency-${currency.key}'),
                view: currency,
                selected: controller.selectedKey == currency.key,
                onPressed: enabled ? () => controller.select(currency.key) : null,
              ),
            ),
          ),
        );
        cardTop += InventoryMetrics.currencyCardPitch;
      }
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }

  Widget _sideCaption(double y, double Function(double) width, String text) =>
      Positioned(
        left: InventoryMetrics.sidebarTextLeft,
        top: y,
        width: width(y),
        height: 18,
        child: Text(text, maxLines: 1, style: _captionStyle),
      );

  Widget _railButton({
    required String key,
    required RailButtonVariant variant,
    required double height,
    required VoidCallback? onPressed,
    required String label,
    List<Widget> trailing = const [],
  }) => _Fit(
    minWidth: 240,
    minHeight: height,
    child: RailButton(
      key: ValueKey(key),
      variant: variant,
      height: height,
      semanticLabel: label,
      onPressed: onPressed,
      child: Row(
        children: [
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          ...trailing,
        ],
      ),
    ),
  );

  // --- B KPI ----------------------------------------------------------------

  Widget _kpis(Size size) {
    final quad = _SectionQuad.of(size, inventoryKpiSectionId);
    final top = quad.top + InventoryMetrics.kpiTop;
    final left = quad.leftAt(top + InventoryMetrics.kpiHeight) +
        InventoryMetrics.kpiLeft;
    final right = quad.rightAt(top) - InventoryMetrics.kpiRight;
    // 작은 창에서는 띠 높이가 시안(138)보다 낮다. 내용은 시안 크기로 두고 띠 안에서 자른다.
    final height = (quad.bottom - top - InventoryMetrics.kpiTop)
        .clamp(0.0, InventoryMetrics.kpiHeight)
        .toDouble();
    final board = controller.board;
    final kpis = board.kpis;
    final planReady = board.hasShortages;
    // FE6-f 이력 값(FD-041): 지난 스캔 대비 증감 · 최근 감소 · 마지막 스캔. 이력이 없거나 1회뿐이면 `—`.
    final deltas = controller.kpiDeltas;
    String kinds(int? value) => value == null ? '—' : '$value종';
    String signed(int? value) =>
        value == null ? '—' : inventorySignedCount(value);
    final items = <_KpiValue>[
      _KpiValue('owned', '보유 품목', kinds(kpis.ownedKinds)),
      _KpiValue(
        'shortage',
        '부족 재화',
        planReady ? kinds(kpis.shortageKinds) : '—',
        color: AppColors.accent,
        delta: planReady ? '${signed(deltas.shortage)} 지난 스캔 대비' : null,
      ),
      _KpiValue(
        'excess',
        '과잉 재화',
        planReady ? kinds(kpis.excessKinds) : '—',
        delta: planReady ? signed(deltas.excess) : null,
      ),
      _KpiValue(
        'fulfillment',
        '계획 충족률',
        _percentOrDash(kpis.fulfillment),
        delta: kpis.unknownKinds > 0 ? '${kpis.unknownKinds}종 모름' : null,
      ),
      _KpiValue('decline', '최근 감소', kinds(deltas.decline)),
      _KpiValue(
        'last-scan',
        '마지막 스캔',
        inventoryDaysAgoLabel(deltas.lastScanDays),
        color: AppColors.warning,
      ),
    ];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: left,
          top: top,
          width: math.max(0.0, right - left),
          height: height,
          child: _Fit(
            minWidth: 900,
            minHeight: InventoryMetrics.kpiHeight,
            child: Row(
              children: [
                for (final item in items)
                  Expanded(child: _KpiCell(item: item)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- C 위험도 목록 ----------------------------------------------------------

  Widget _risk(BuildContext context, Size size) {
    final quad = _SectionQuad.of(size, inventoryRiskSectionId);
    final top = quad.top;
    final bottom = quad.bottom;
    final titleTop = top + InventoryMetrics.titleTop;
    final ruleTop = top + InventoryMetrics.ruleTop;
    final message = controller.message;
    var band = 0.0;
    if (message != null) band += InventoryMetrics.messageHeight + 4;
    final rowsTop = top + InventoryMetrics.rowsTop + band;
    final panelBottom = math.max(
      rowsTop + 40,
      bottom - InventoryMetrics.panelInset,
    );
    final listLeft =
        quad.leftAt(panelBottom) + InventoryMetrics.panelHorizontalInset;
    final listRect = Rect.fromLTRB(
      listLeft,
      rowsTop - 6,
      math.max(
        listLeft,
        quad.rightAt(rowsTop) - InventoryMetrics.panelHorizontalInset,
      ),
      panelBottom,
    );
    double rowLeft(double y, double height) =>
        quad.leftAt(y + height) + InventoryMetrics.titleLeft;
    double rowWidth(double y, double height) => math.max(
      0.0,
      quad.rightAt(y) - InventoryMetrics.titleRight - rowLeft(y, height),
    );
    final children = <Widget>[
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: const ValueKey('inventory-risk-panel'),
            painter: _RiskPanelPainter(quad),
          ),
        ),
      ),
      Positioned(
        left: rowLeft(titleTop, InventoryMetrics.titleHeight),
        top: titleTop,
        width: rowWidth(titleTop, InventoryMetrics.titleHeight),
        height: InventoryMetrics.titleHeight,
        child: _Fit(
          minWidth: 520,
          minHeight: InventoryMetrics.titleHeight,
          child: controller.view == InventoryView.all
              ? _allTitle()
              : _riskTitle(),
        ),
      ),
      Positioned(
        left: quad.leftAt(ruleTop) + 34,
        top: ruleTop,
        width: math.max(0.0, quad.rightAt(ruleTop) - 46 - quad.leftAt(ruleTop) - 34),
        height: 3,
        child: const Align(
          alignment: Alignment.centerLeft,
          child: TitleRule(capWidth: 46),
        ),
      ),
    ];
    final bandY = top + InventoryMetrics.bandTop;
    if (message != null) {
      children.add(
        Positioned(
          left: rowLeft(bandY, InventoryMetrics.messageHeight),
          top: bandY,
          width: rowWidth(bandY, InventoryMetrics.messageHeight),
          height: InventoryMetrics.messageHeight,
          child: Text(
            message,
            key: const ValueKey('inventory-message'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _muted.copyWith(
              fontSize: AppType.bodySmallSize,
              color: controller.messageTone == InventoryMessageTone.warning
                  ? AppColors.warning
                  : AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    if (_showEmptyGuide) {
      // F3d 시안 Empty-Inventory: 안내 블록은 섹션 위에서 140, 그 높이의 섹션 왼쪽 변 + 27.5(기준 (707.5, 505.2)).
      final guideTop = top + 140;
      final guideLeft = quad.leftAt(guideTop) + 27.5;
      children.add(
        Positioned(
          left: guideLeft,
          top: guideTop,
          width: math.max(
            0.0,
            quad.rightAt(guideTop) - InventoryMetrics.titleRight - guideLeft,
          ),
          height: math.max(0.0, math.min(200.0, bottom - guideTop - 24)),
          child: EmptyStateFit(child: _emptyGuide()),
        ),
      );
      return Stack(clipBehavior: Clip.none, children: children);
    }
    children.add(
      Positioned.fromRect(
        rect: listRect,
        child: ClipPath(
          clipper: const _ParallelogramClipper(),
          child: _riskContent(listRect.size),
        ),
      ),
    );
    return Stack(clipBehavior: Clip.none, children: children);
  }

  /// 확정 인벤토리 0개(F3d): 계정 상태를 읽었고 목록이 있는데 확정 항목이 하나도 없을 때, "부족한 것" 보기에서만 안내를
  /// 둔다. "전체 아이템" 보기는 그대로(수량 직접 고치기 경로 유지).
  bool get _showEmptyGuide =>
      controller.view == InventoryView.shortage &&
      controller.loaded &&
      !controller.disconnected &&
      controller.catalogError == null &&
      controller.profileError == null &&
      controller.catalog.isNotEmpty &&
      controller.repositoryState?.inventory.entries.isEmpty == true;

  Widget _emptyGuide() => EmptyStateGuide(
    key: const ValueKey('inventory-empty-guide'),
    glyph: EmptyStateGlyph.box,
    width: 900,
    title: '인벤토리 스캔 전입니다. 아이템을 한 번 스캔하면 보유 수량이 채워집니다.',
    body: '보유 수량이 있어야 계획에 필요한 재화와 부족 위험을 계산할 수 있습니다.',
    actions: [
      EmptyStateAction(
        key: const ValueKey('inventory-empty-open-scan'),
        label: '스캔하러 가기',
        glyph: EmptyStateGlyph.scanFrame,
        onPressed: onOpenScan,
      ),
    ],
  );

  Widget _riskTitle() => Row(
    children: [
      const TitleBar(width: 7, height: 22),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          '부족 위험도 순위',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: kitDisplayStyle(AppType.panelTitleSize),
        ),
      ),
      const SizedBox(width: 8),
      const InfoPopover(
        label: '위험도',
        title: '위험도',
        children: [
          InfoPopoverText.plain(
            '필요량 대비 보유량이 적을수록, 그 재화를 쓰는 학생이 많을수록 높습니다. 100에 가까울수록 계획을 오래 막습니다.',
          ),
        ],
      ),
      const Spacer(),
      for (final sort in InventorySort.values) ...[
        const SizedBox(width: 6),
        _SortChip(
          key: ValueKey('inventory-sort-${sort.name}'),
          label: sort.label,
          selected: controller.sort == sort,
          onPressed: () => controller.setSort(sort),
        ),
      ],
    ],
  );

  /// 전체 아이템 제목 줄(시안 Inventory-All): 제목 + (i) "타일 읽는 법" + 칩(종류순 · 계획에 쓰는 것만 · 보유 0 숨기기).
  Widget _allTitle() => Row(
    children: [
      const TitleBar(width: 7, height: 22),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          '전체 아이템',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: kitDisplayStyle(AppType.panelTitleSize),
        ),
      ),
      const SizedBox(width: 8),
      InfoPopover(
        label: '타일 읽는 법',
        title: '타일 읽는 법',
        children: [
          InfoPopoverText([
            const TextSpan(text: '숫자는 보유량입니다. 아래 막대는 계획 필요량 대비 충족률이고, '),
            InfoPopoverText.em('분홍'),
            const TextSpan(text: '은 부족, '),
            InfoPopoverText.em('파랑'),
            const TextSpan(text: '은 충분, '),
            InfoPopoverText.em('노랑'),
            const TextSpan(
              text: '은 필요보다 많이 남는 과잉입니다. 막대가 없으면 계획에 안 쓰는 재화이고, 빗금은 보유를 모르는 재화입니다.',
            ),
          ]),
        ],
      ),
      const Spacer(),
      const SizedBox(width: 6),
      // 전체 보기 정렬은 종류순 하나다(다른 정렬은 시안에 없다). 누르는 칩이 아니라 지금 정렬을 알리는 표시다.
      Semantics(
        key: const ValueKey('inventory-all-sort-kind'),
        label: '종류순 정렬',
        child: ExcludeSemantics(
          child: BaChip(label: '종류순', tone: AppTones.pink),
        ),
      ),
      const SizedBox(width: 6),
      _FilterChip(
        key: const ValueKey('inventory-all-planned-only'),
        label: '계획에 쓰는 것만',
        on: controller.plannedOnly,
        onPressed: controller.togglePlannedOnly,
      ),
      const SizedBox(width: 6),
      _FilterChip(
        key: const ValueKey('inventory-all-hide-zero'),
        label: '보유 0 숨기기',
        on: controller.hideZero,
        onPressed: controller.toggleHideZero,
      ),
    ],
  );

  /// 전체 아이템 타일(FE6-b). 그룹 머리 줄과 타일 줄을 공용 사선 뷰포트(translate)의 행으로 쌓는다. 한 줄 타일 수는
  /// 행 자리 폭으로 정한다.
  Widget _tileContent(Size viewport) {
    final groups = controller.tileGroups;
    if (groups.isEmpty) {
      return const _Notice('조건에 맞는 품목이 없습니다.');
    }
    const lastRowHeight =
        InventoryAllMetrics.tileSize + InventoryAllMetrics.groupGap;
    const rowHeight =
        InventoryAllMetrics.tileSize + InventoryAllMetrics.tileRowGap;
    const headerHeight =
        InventoryAllMetrics.groupHeaderHeight +
        InventoryAllMetrics.groupHeaderGap;
    // 행 높이가 클수록 자리 폭이 조금 좁다. 가장 높은 줄(그룹 마지막 줄) 기준으로 센다.
    final slot = diagonalScrollRowSlot(
      mode: DiagonalScrollMode.translate,
      viewportWidth: viewport.width,
      viewportHeight: viewport.height,
      rowTop: 0,
      rowHeight: lastRowHeight,
      scrollOffset: 0,
      horizontalInset: InventoryMetrics.rowInset,
      scrollbarReserve: InventoryMetrics.rowScrollbarReserve,
    );
    final perRow = math.max(
      1,
      ((slot.width -
                  InventoryAllMetrics.tileLeft +
                  InventoryAllMetrics.tileRowGap) /
              InventoryAllMetrics.tilePitch)
          .floor(),
    );
    final rows = <({double height, InventoryTileGroup? header, List<InventoryItemView> tiles})>[];
    for (final group in groups) {
      rows.add((height: headerHeight, header: group, tiles: const []));
      for (var start = 0; start < group.items.length; start += perRow) {
        final end = math.min(group.items.length, start + perRow);
        rows.add((
          height: end == group.items.length ? lastRowHeight : rowHeight,
          header: null,
          tiles: group.items.sublist(start, end),
        ));
      }
    }
    final selected = controller.selectedKey;
    // 위험도 목록과 같은 자리에 놓이므로 key로 갈라 State(와 그 ScrollController)를 따로 둔다. 같은 State를 쓰면
    // 보기 전환 프레임에 새 스크롤 뷰가 옛 것이 떨어지기 전에 같은 컨트롤러에 붙는다(gate ① RED).
    return DiagonalScrollViewport(
      key: const ValueKey('inventory-tiles-viewport'),
      keyPrefix: 'inventory-tiles-diagonal',
      itemCount: rows.length,
      itemHeight: (index) => rows[index].height,
      itemGap: 0,
      verticalInset: 6,
      horizontalInset: InventoryMetrics.rowInset,
      scrollbarReserve: InventoryMetrics.rowScrollbarReserve,
      fog: const ScrollFogSpec.panel(color: inventoryPanelFill),
      itemBuilder: (context, index) {
        final row = rows[index];
        final header = row.header;
        if (header != null) {
          return _Fit(
            minWidth: 280,
            minHeight: InventoryAllMetrics.groupHeaderHeight,
            child: _TileGroupHeader(
              key: ValueKey('inventory-group-${header.id}'),
              group: header,
              onShowAll: () =>
                  controller.showCategoryShortages(header.items.first.item.category),
            ),
          );
        }
        // 고른 타일의 테두리·빛이 줄 밖(위·아래 간격)으로 번지므로 타일 줄은 자르지 않는다.
        return _Fit(
          minWidth:
              InventoryAllMetrics.tileLeft +
              perRow * InventoryAllMetrics.tilePitch,
          minHeight: InventoryAllMetrics.tileSize,
          clip: false,
          child: Padding(
            padding: const EdgeInsets.only(left: InventoryAllMetrics.tileLeft),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final view in row.tiles)
                  Padding(
                    padding: const EdgeInsets.only(
                      right: InventoryAllMetrics.tileRowGap,
                    ),
                    child: _RevealOnRequest(
                      request: reveal?.resourceKey == view.key ? reveal : null,
                      child: InventoryItemTile(
                        key: ValueKey('inventory-tile-${view.key}'),
                        view: view,
                        selected: view.key == selected,
                        needsReview: controller.needsReview(view.key),
                        onTap: () => controller.select(view.key),
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

  Widget _riskContent(Size viewport) {
    if (controller.disconnected) {
      return const _Notice('백엔드에 연결되지 않았습니다. 다시 연결하면 인벤토리와 부족 재화를 읽습니다.');
    }
    if (controller.catalogError case final error?) {
      return _Notice(
        error,
        action: TonalButton(
          key: const ValueKey('inventory-reload'),
          label: '다시 읽기',
          onPressed: controller.loading ? null : controller.load,
        ),
      );
    }
    if (!controller.loaded ||
        (controller.loading && controller.catalog.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.profileError case final error?) {
      return _Notice(error);
    }
    if (controller.catalog.isEmpty) {
      return const _Notice('인벤토리 목록이 비어 있습니다.');
    }
    final visible = controller.visible;
    if (controller.view == InventoryView.shortage) {
      if (controller.shortageError case final error?) {
        return _Notice(
          error,
          action: TonalButton(
            key: const ValueKey('inventory-reload'),
            label: '다시 읽기',
            onPressed: controller.loading ? null : controller.load,
          ),
        );
      }
      if (!controller.hasPlan) {
        return _Notice(
          '저장된 계획이 없습니다. 계획 탭에서 계획을 저장하면 부족한 재화가 보입니다.',
          action: TonalButton(
            key: const ValueKey('inventory-open-plan'),
            label: '계획 열기',
            onPressed: () => onOpenPlan(null),
          ),
        );
      }
      if (visible.isEmpty) {
        return _Notice(
          controller.category == null
              ? '부족한 재화가 없습니다.'
              : '이 종류에는 부족한 재화가 없습니다.',
        );
      }
    } else {
      return _tileContent(viewport);
    }
    final selected = controller.selectedKey;
    return DiagonalScrollViewport(
      key: const ValueKey('inventory-risk-viewport'),
      keyPrefix: 'inventory-risk-diagonal',
      itemCount: visible.length,
      itemHeight: (_) => InventoryMetrics.rowHeight,
      itemGap: InventoryMetrics.rowGap,
      verticalInset: 6,
      horizontalInset: InventoryMetrics.rowInset,
      scrollbarReserve: InventoryMetrics.rowScrollbarReserve,
      fog: const ScrollFogSpec.panel(color: inventoryPanelFill),
      itemBuilder: (context, index) {
        final view = visible[index];
        return _RevealOnRequest(
          request: reveal?.resourceKey == view.key ? reveal : null,
          child: TutorialTarget(
            id: index == 0 && controller.view == InventoryView.shortage
                ? TutorialTargets.inventoryShortageTopRow
                : null,
            child: InventoryRiskRow(
              key: ValueKey('inventory-row-${view.key}'),
              view: view,
              selected: view.key == selected,
              needsReview: controller.needsReview(view.key),
              onTap: () {
                controller.select(view.key);
                // F3c-2: 부족 위험 1위 행을 열었다(9단계).
                if (index == 0 && controller.view == InventoryView.shortage) {
                  TutorialHooksScope.emit(
                    context,
                    TutorialSignals.inventoryTopShortageOpened,
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }

  // --- D 상세 ---------------------------------------------------------------

  Widget _detail(BuildContext context, Size size) {
    final quad = _SectionQuad.of(size, inventoryDetailSectionId);
    final top = quad.top;
    double left(double y, double height) =>
        quad.leftAt(y + height) + InventoryMetrics.detailLeftInset;
    double width(double y, double height) => math.max(
      0.0,
      quad.rightAt(y) - InventoryMetrics.detailRightMargin - left(y, height),
    );
    Widget block(
      double y,
      double height,
      double minWidth,
      Widget child, {
      Key? key,
    }) => Positioned(
      key: key,
      left: left(y, height),
      top: y,
      width: width(y, height),
      height: height,
      child: _Fit(minWidth: minWidth, minHeight: height, child: child),
    );

    final view = controller.selected;
    final titleTop = top + InventoryMetrics.detailTitleTop;
    final ruleTop = top + InventoryMetrics.detailRuleTop;
    final children = <Widget>[
      block(
        titleTop,
        InventoryMetrics.detailTitleHeight,
        320,
        Row(
          children: [
            const TitleBar(width: 7, height: 22),
            const SizedBox(width: 10),
            Text('상세', style: kitDisplayStyle(AppType.panelTitleSize)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                view?.item.displayName ?? '',
                key: const ValueKey('inventory-detail-title-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _muted.copyWith(fontSize: AppType.bodySmallSize),
              ),
            ),
          ],
        ),
      ),
      Positioned(
        left: quad.leftAt(ruleTop) + 21,
        top: ruleTop,
        width: math.max(
          0.0,
          quad.rightAt(ruleTop) -
              InventoryMetrics.detailRightMargin -
              quad.leftAt(ruleTop) -
              21,
        ),
        height: 3,
        child: const Align(
          alignment: Alignment.centerLeft,
          child: TitleRule(capWidth: 46),
        ),
      ),
    ];
    if (view == null) {
      children.add(
        block(
          top + InventoryMetrics.detailBlockTop,
          InventoryMetrics.headerHeight,
          320,
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '목록에서 재화를 고르면 상세가 보입니다.',
              key: ValueKey('inventory-detail-empty'),
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
      return Stack(clipBehavior: Clip.none, children: children);
    }

    var y = top + InventoryMetrics.detailBlockTop;
    void gap([double value = InventoryMetrics.blockGap]) => y += value;

    // 머리.
    children.add(
      block(
        y,
        InventoryMetrics.headerHeight,
        360,
        _DetailHeader(view: view),
      ),
    );
    y += InventoryMetrics.headerHeight;
    gap(10);

    // kv.
    children.add(
      block(
        y,
        InventoryMetrics.kvHeight,
        420,
        DiagonalRow(
          variant: DiagonalRowVariant.row,
          padding: const EdgeInsets.fromLTRB(25, 10, 24, 10),
          child: Row(
            children: [
              _DetailKv('owned', '보유', _amountOrDash(view.owned)),
              _DetailKv(
                'required',
                '필요',
                view.planned ? _amountOrDash(view.requiredAmount) : '—',
              ),
              _DetailKv(
                'shortage',
                '부족',
                _amountOrDash(view.shortageAmount),
                color: view.knownShortage ? AppColors.accent : AppColors.text,
              ),
              _DetailKv(
                'fulfillment',
                '충족률',
                _percentOrDash(view.fulfillment),
              ),
            ],
          ),
        ),
      ),
    );
    y += InventoryMetrics.kvHeight;
    gap(12);

    // 확인 필요(FB-10b · FD-146): 표시가 있을 때만. "이 값이 맞습니다"는 수량을 그대로 두고 그 key만 확인한다.
    if (controller.needsReview(view.key)) {
      children.add(
        block(
          y,
          InventoryMetrics.reviewHeight,
          420,
          _ReviewLine(controller: controller, view: view),
          key: const ValueKey('inventory-review-line'),
        ),
      );
      y += InventoryMetrics.reviewHeight;
      gap();
    }

    // 수량 직접 고치기 / 재화 안내.
    if (view.isCurrency) {
      children.add(
        block(
          y,
          InventoryMetrics.noteHeight,
          320,
          const Text(
            '재화 수량은 스캔으로만 바뀝니다.',
            key: ValueKey('inventory-currency-note'),
            style: _muted,
          ),
        ),
      );
      y += InventoryMetrics.noteHeight;
      gap();
    } else if (controller.editingKey == view.key) {
      children.add(
        block(
          y,
          InventoryMetrics.editorHeight,
          420,
          _QuantityEditor(
            key: ValueKey('inventory-editor-${view.key}'),
            controller: controller,
            itemKey: view.key,
          ),
        ),
      );
      y += InventoryMetrics.editorHeight;
      gap();
    }

    // 사용 학생.
    final uses = controller.usesFor(view.key);
    final blocked = uses.where((use) => use.blocked).length;
    children.add(
      block(
        y,
        InventoryMetrics.subHeaderHeight,
        320,
        Align(
          alignment: Alignment.centerLeft,
          child: SubHeader(
            '사용하는 학생 · 막히는 단계 $blocked',
            fontSize: AppType.microSize,
          ),
        ),
      ),
    );
    y += InventoryMetrics.subHeaderHeight;
    gap(6);
    final useRows = _useRows(view, uses);
    for (var index = 0; index < useRows.length; index++) {
      children.add(
        block(
          y,
          InventoryMetrics.useRowHeight,
          420,
          useRows[index],
          key: ValueKey('inventory-use-slot-$index'),
        ),
      );
      y += InventoryMetrics.useRowHeight;
      gap(6);
    }
    gap(6);

    // 보충 방법.
    children.add(
      block(
        y,
        InventoryMetrics.subHeaderHeight,
        320,
        const Align(
          alignment: Alignment.centerLeft,
          child: SubHeader('보충 방법', fontSize: AppType.microSize),
        ),
      ),
    );
    y += InventoryMetrics.subHeaderHeight;
    gap(6);
    for (final row in _methodRows(view)) {
      children.add(block(y, InventoryMetrics.methodRowHeight, 420, row));
      y += InventoryMetrics.methodRowHeight;
      gap(6);
    }
    gap(6);

    // 최근 변화(FE6-f): 머리 "최근 변화 · 스캔 n회" + 순변화 글자, 스파크라인 줄(한 재화 안, FD-033). 점이 없으면 안내 줄.
    final spark = controller.sparklineFor(view.key);
    children.add(
      block(
        y,
        InventoryMetrics.subHeaderHeight,
        320,
        Row(
          children: [
            SubHeader(
              spark == null || spark.points.isEmpty ? '최근 변화' : spark.header,
              key: const ValueKey('inventory-history-header'),
              fontSize: AppType.microSize,
            ),
            if (spark != null && spark.points.isNotEmpty) ...[
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  spark.summary,
                  key: const ValueKey('inventory-history-summary'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _muted.copyWith(
                    fontSize: AppType.bodySmallSize,
                    fontWeight: AppType.bold,
                    color: spark.warning ? AppColors.accent : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    y += InventoryMetrics.subHeaderHeight;
    gap(6);
    if (spark != null && spark.points.isNotEmpty) {
      children.add(
        block(
          y,
          InventoryMetrics.sparklineRowHeight,
          420,
          _SparklineRow(points: spark.points),
          key: const ValueKey('inventory-history-sparkline'),
        ),
      );
      y += InventoryMetrics.sparklineRowHeight;
      gap(14);
    } else {
      final (title, detail) = _historyEmptyText(spark);
      children.add(
        block(
          y,
          InventoryMetrics.methodRowHeight,
          420,
          _InfoRow(
            key: const ValueKey('inventory-history-empty'),
            title: title,
            detail: detail,
          ),
        ),
      );
      y += InventoryMetrics.methodRowHeight;
      gap(16);
    }

    // 액션.
    children.add(
      block(
        y,
        InventoryMetrics.actionHeight,
        460,
        Row(
          children: [
            TonalButton(
              key: const ValueKey('inventory-action-plan'),
              label: '계획에서 보기',
              variant: TonalButtonVariant.primary,
              onPressed: () => onOpenPlan(view.key),
            ),
            const SizedBox(width: 10),
            TonalButton(
              key: const ValueKey('inventory-action-edit'),
              label: '수량 직접 고치기',
              onPressed: controller.canEdit(view.key) &&
                      controller.editingKey != view.key
                  ? () => controller.beginEdit(view.key)
                  : null,
            ),
            const SizedBox(width: 10),
            TonalButton(
              key: const ValueKey('inventory-action-scan'),
              label: '인벤토리 스캔',
              onPressed: onOpenScan,
            ),
          ],
        ),
      ),
    );
    return Stack(clipBehavior: Clip.none, children: children);
  }

  /// 상세 "최근 변화"에 그릴 점이 없을 때의 안내(제목, 설명).
  (String, String?) _historyEmptyText(InventorySparkline? spark) {
    if (spark != null) {
      return (
        '4주 안에 이 재화를 스캔한 기록이 없습니다.',
        '인벤토리 스캔으로 이 재화를 읽으면 변화가 쌓입니다.',
      );
    }
    if (controller.historyLoading) return ('변화 기록을 읽는 중입니다.', null);
    final error = controller.historyError;
    if (error != null) return (error, null);
    return ('아직 변화 기록이 없습니다.', null);
  }

  /// 사용 학생 줄(최대 [InventoryMetrics.maxUses]개 + "외 n단계").
  List<Widget> _useRows(InventoryItemView view, List<InventoryStageUse> uses) {
    if (!view.planned) {
      return const [
        _InfoRow(
          key: ValueKey('inventory-uses-none'),
          title: '계획에 쓰지 않는 재화입니다.',
        ),
      ];
    }
    if (uses.isEmpty) {
      final students = view.shortage?.affectedStudentIds ?? const <String>[];
      final reason = controller.usesError ??
          (controller.usesAvailable
              ? '활성 계획 계산에 이 재화를 쓰는 단계가 없습니다.'
              : '활성 계획의 단계별 필요량을 아직 읽지 못했습니다.');
      return [
        _InfoRow(
          key: const ValueKey('inventory-uses-unavailable'),
          title: students.isEmpty
              ? '사용 학생 정보가 없습니다.'
              : students.map(controller.studentName).join(' · '),
          detail: reason,
        ),
      ];
    }
    final rows = <Widget>[
      for (var index = 0;
          index < math.min(uses.length, InventoryMetrics.maxUses);
          index++)
        _UseRow(
          key: ValueKey('inventory-use-$index'),
          use: uses[index],
          studentName: controller.studentName(uses[index].studentId),
        ),
    ];
    if (uses.length > InventoryMetrics.maxUses) {
      rows.add(
        _InfoRow(
          key: const ValueKey('inventory-uses-more'),
          title: '외 ${uses.length - InventoryMetrics.maxUses}단계',
        ),
      );
    }
    return rows;
  }

  /// 보충 방법 줄(FB-3 획득처). 빈 표·지원 안 함·실패를 서로 다르게 보인다.
  List<Widget> _methodRows(InventoryItemView view) {
    final acquisition = controller.acquisitionFor(view.key);
    switch (acquisition.status) {
      case InventoryAcquisitionStatus.loading:
        return const [
          _InfoRow(
            key: ValueKey('inventory-acquisition-loading'),
            title: '획득처를 읽는 중입니다.',
          ),
        ];
      case InventoryAcquisitionStatus.unsupported:
        return const [
          _InfoRow(
            key: ValueKey('inventory-acquisition-unsupported'),
            title: '이 연결은 획득처 조회를 지원하지 않습니다.',
          ),
        ];
      case InventoryAcquisitionStatus.notFound:
        return const [
          _InfoRow(
            key: ValueKey('inventory-acquisition-not-found'),
            title: '획득처 표에 없는 재화입니다.',
          ),
        ];
      case InventoryAcquisitionStatus.failed:
        return [
          _InfoRow(
            key: const ValueKey('inventory-acquisition-failed'),
            title: '획득처를 불러오지 못했습니다.',
            detail: '${acquisition.error}',
            action: TonalButton(
              key: const ValueKey('inventory-acquisition-retry'),
              label: '다시 읽기',
              height: 30,
              onPressed: () => controller.retryAcquisition(view.key),
            ),
          ),
        ];
      case InventoryAcquisitionStatus.loaded:
        final methods = acquisition.result!.methods;
        if (methods.isEmpty) {
          return const [
            _InfoRow(
              key: ValueKey('inventory-acquisition-empty'),
              title: '아직 정리된 획득처가 없습니다.',
            ),
          ];
        }
        return [
          for (final method in methods.take(InventoryMetrics.maxMethods))
            _InfoRow(
              key: ValueKey('inventory-acquisition-method-${method.methodId}'),
              title: method.label,
              detail: inventoryAcquisitionDetail(method),
            ),
        ];
    }
  }
}

/// 획득처 한 줄의 보조 글자(종류 · 주간량 · 선택권 수).
String inventoryAcquisitionDetail(ResourceAcquisitionMethod method) {
  final parts = <String>[
    switch (method.kind) {
      ResourceAcquisitionKind.stage => '스테이지',
      ResourceAcquisitionKind.shop => '상점',
      ResourceAcquisitionKind.conversion => '변환',
      ResourceAcquisitionKind.selector => '선택권',
      ResourceAcquisitionKind.other => '기타',
    },
    if (method.weeklyQuantity case final weekly?) '주 $weekly개',
    if (method.selectorResourceKeys case final keys?) '선택 ${keys.length}종',
  ];
  return parts.join(' · ');
}

/// 인벤토리 화면 셋(목록 · 분석 · 티어별 충족률)과 그 섹션.
enum _InventoryScreen {
  list,
  analysis,
  tiers;

  /// 표면을 그리는 순서(그림자 → 표면은 섹션마다, 사이드바가 마지막). 목록은 네 섹션, 분석(FE6-c)은 다섯, 티어(FE6-e)는
  /// 여섯 섹션이다.
  List<SectionCanvasElement> get surfaces => switch (this) {
    list => [
      for (final id in const [
        inventoryDetailSectionId,
        inventoryRiskSectionId,
        inventoryKpiSectionId,
        inventorySidebarSectionId,
      ])
        inventorySection(id),
    ],
    analysis => [
      for (final id in const [
        inventoryAnalysisTiersSectionId,
        inventoryAnalysisChangesSectionId,
        inventoryAnalysisOopartsSectionId,
        inventoryAnalysisSchoolsSectionId,
        inventorySidebarSectionId,
      ])
        inventoryAnalysisSection(id),
    ],
    tiers => [
      for (final id in const [
        inventoryTiersSummarySectionId,
        inventoryTiersTopSectionId,
        inventoryTiersOopartsSectionId,
        inventoryTiersBdSectionId,
        inventoryTiersNotesSectionId,
        inventorySidebarSectionId,
      ])
        inventoryTiersSection(id),
    ],
  };

  /// 사이드바를 뺀, 교체되는 섹션(그리는 순서).
  List<SectionCanvasElement> get swapped => [
    for (final element in surfaces)
      if (element.id != inventorySidebarSectionId) element,
  ];
}

/// 섹션 교체 모션 방향(§1.4 부착면 표: 오른쪽 180/0 · 아래 80/260 · 위 260/80). T2 BD 부유 패널은 FD-019대로 아래 기준
/// 80/260이다.
({double intro, double outro}) _inventorySectionMotion(String id) =>
    switch (id) {
      inventoryAnalysisSchoolsSectionId ||
      inventoryTiersNotesSectionId => (intro: 260, outro: 80),
      inventoryAnalysisChangesSectionId ||
      inventoryTiersSummarySectionId ||
      inventoryTiersBdSectionId => (intro: 80, outro: 260),
      _ => (intro: 180, outro: 0),
    };

/// 섹션 표면을 한 번에 그린다(그림자 → 표면 순서는 섹션마다, [sections] 순서).
class _InventorySurfacesPainter extends CustomPainter {
  const _InventorySurfacesPainter(this.sections);

  final List<SectionCanvasElement> sections;

  @override
  void paint(Canvas canvas, Size size) {
    for (final section in sections) {
      paintSectionSurface(canvas, buildSectionCanvasElementPath(size, section));
    }
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_InventorySurfacesPainter oldDelegate) {
    if (oldDelegate.sections.length != sections.length) return true;
    for (var index = 0; index < sections.length; index++) {
      if (oldDelegate.sections[index].id != sections[index].id) return true;
    }
    return false;
  }
}

/// 분석 모드 본문(사이드바 표면 · 내용 포함). 분석 ↔ 티어별 충족률을 섹션 모션으로 바꾼다: 앞 360ms는 나가는 섹션이
/// outro로, 뒤 360ms는 들어오는 섹션이 intro로 움직인다. 움직이지 않을 때는 한 painter가 표면을 모두 그리고 그 위에 섹션
/// 내용, 맨 위에 사이드바 내용을 둔다(FE6-c와 같은 그림 순서).
///
/// 오파츠 확장(FE6-d)은 [_expand] 하나(0 접힘 → 1 확장)를 [inventoryOpaTimeline] 세 구간으로 나눠 그린다: 사이드바 · S1 ·
/// S4 · S5 퇴장 → S2 morph → 상세 열 등장. "축소"는 같은 값을 거꾸로 지난다. 움직이는 동안은 입력을 받지 않는다.
class _InventoryAnalysisStage extends StatefulWidget {
  const _InventoryAnalysisStage({
    required this.controller,
    required this.onOpenPlan,
    required this.size,
    required this.tiers,
    required this.expanded,
    required this.sidebar,
  });

  final InventoryController controller;
  final ValueChanged<String?> onOpenPlan;
  final Size size;

  /// 티어별 충족률 화면이 목표다.
  final bool tiers;

  /// S2 오파츠 확장이 목표다(FE6-d).
  final bool expanded;

  /// 사이드바 내용(workspace가 만든다). 표면은 이 stage가 그린다.
  final Widget sidebar;

  @override
  State<_InventoryAnalysisStage> createState() =>
      _InventoryAnalysisStageState();
}

/// 오파츠 확장 시퀀스 구간: 퇴장 `AppMotion.section`(360ms) → morph `AppMotion.section`(360ms) → 상세 등장
/// `AppMotion.header`(220ms), 합계 940ms. 곡선은 `AppMotion.sectionCurve`.
const inventoryOpaTimeline = SectionMorphTimeline();

/// 확장 때 빠지는 섹션과 outro 각도(§1.4: 사이드바 왼쪽 180 · S1 위 80 · S4 오른쪽 0 · S5 아래 260).
double inventoryOpaExitAngle(String id) => id == inventorySidebarSectionId
    ? 180
    : _inventorySectionMotion(id).outro;

class _InventoryAnalysisStageState extends State<_InventoryAnalysisStage>
    with TickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: AppMotion.section * 2,
  )..addStatusListener(_motionStatus);

  late final AnimationController _expand = AnimationController(
    vsync: this,
    duration: inventoryOpaTimeline.total,
  );

  /// 다 들어와 있는 화면(움직이지 않을 때 그린다). `late` 초기화는 처음 읽을 때 일어나므로 initState에서 정한다.
  late bool _shown;
  late bool _from;
  late bool _to;

  @override
  void initState() {
    super.initState();
    _shown = widget.tiers;
    _from = widget.tiers;
    _to = widget.tiers;
    _expand.value = widget.expanded ? 1 : 0;
  }

  void _motionStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _shown = _to);
    }
  }

  @override
  void didUpdateWidget(_InventoryAnalysisStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      if (widget.expanded) {
        _expand.forward();
      } else {
        _expand.reverse();
      }
    }
    if (widget.tiers == _to) return;
    // 티어 화면은 접힌 분석에서만 연다(컨트롤러가 확장을 접는다).
    _expand.value = 0;
    _from = _motion.isAnimating ? _to : _shown;
    _to = widget.tiers;
    _motion.forward(from: 0);
  }

  @override
  void dispose() {
    _motion.dispose();
    _expand.dispose();
    super.dispose();
  }

  _InventoryAnalysisSections get _analysis => _InventoryAnalysisSections(
    key: const ValueKey('inventory-analysis-sections'),
    controller: widget.controller,
    onOpenPlan: widget.onOpenPlan,
    size: widget.size,
  );

  _InventoryTiersSections get _tiers => _InventoryTiersSections(
    key: const ValueKey('inventory-tiers-sections'),
    controller: widget.controller,
    size: widget.size,
    common: _analysis,
  );

  Widget get _sidebar => Positioned.fill(child: widget.sidebar);

  @override
  Widget build(BuildContext context) {
    if (_motion.isAnimating) return _swap();
    if (_shown) return _still(tiers: true);
    return AnimatedBuilder(
      animation: _expand,
      builder: (context, _) => _expand.value > 0 || _expand.isAnimating
          ? _expansion(_expand.value)
          : _still(tiers: false),
    );
  }

  /// 움직이지 않는 분석 · 티어 화면.
  Widget _still({required bool tiers}) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: ValueKey(
              tiers ? 'inventory-tiers-surfaces' : 'inventory-analysis-surfaces',
            ),
            painter: _InventorySurfacesPainter(
              tiers
                  ? _InventoryScreen.tiers.surfaces
                  : _InventoryScreen.analysis.surfaces,
            ),
          ),
        ),
      ),
      Positioned.fill(child: tiers ? _tiers : _analysis),
      _sidebar,
    ],
  );

  /// 분석 ↔ 티어 섹션 교체.
  Widget _swap() => AnimatedBuilder(
    animation: _motion,
    builder: (context, _) {
      final value = _motion.value;
      final leaving = value < 0.5;
      final tiers = leaving ? _from : _to;
      final progress = AppMotion.sectionCurve.transform(
        ((leaving ? value : value - 0.5) * 2).clamp(0.0, 1.0).toDouble(),
      );
      final screen = tiers ? _InventoryScreen.tiers : _InventoryScreen.analysis;
      Offset offsetFor(String id) {
        final motion = _inventorySectionMotion(id);
        return leaving
            ? sectionExitOffset(widget.size, motion.outro, progress)
            : sectionEntryOffset(widget.size, motion.intro, progress);
      }

      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final section in screen.swapped)
                    Positioned.fill(
                      key: ValueKey('inventory-motion-${section.id}'),
                      child: Transform.translate(
                        offset: offsetFor(section.id),
                        child: _sectionLayer(
                          section,
                          tiers
                              ? _tiers.content(section.id)
                              : _analysis.content(section.id),
                        ),
                      ),
                    ),
                  // 사이드바 표면은 움직이지 않고 지나가는 섹션 위에 둔다(사이드바 내용은 그 위).
                  Positioned.fill(
                    child: CustomPaint(
                      key: const ValueKey('inventory-motion-surfaces'),
                      painter: _InventorySurfacesPainter([
                        inventoryAnalysisSection(inventorySidebarSectionId),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 사이드바 내용은 움직이지 않고 그대로 누를 수 있다(FE6-e와 같다).
          _sidebar,
        ],
      );
    },
  );

  /// 섹션 하나의 표면 + 내용.
  Widget _sectionLayer(SectionCanvasElement section, Widget content) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(
        child: CustomPaint(painter: _InventorySurfacesPainter([section])),
      ),
      Positioned.fill(child: content),
    ],
  );

  /// 오파츠 확장 중 · 확장 완료 화면([value] 0~1).
  Widget _expansion(double value) {
    final exit = inventoryOpaTimeline.exitProgress(value);
    final morph = inventoryOpaTimeline.morphProgress(value);
    final reveal = inventoryOpaTimeline.revealProgress(value);
    final settled = value >= 1 && !_expand.isAnimating;
    Widget leaving(String id, Widget child) => Positioned.fill(
      key: ValueKey('inventory-opa-exit-$id'),
      child: Transform.translate(
        offset: sectionExitOffset(widget.size, inventoryOpaExitAngle(id), exit),
        child: child,
      ),
    );
    final analysis = _analysis;
    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        // 그림 순서는 멈춘 분석과 같다(S4 · S5 → S2 → S1 → 사이드바).
        if (exit < 1)
          for (final id in const [
            inventoryAnalysisTiersSectionId,
            inventoryAnalysisChangesSectionId,
          ])
            leaving(
              id,
              _sectionLayer(inventoryAnalysisSection(id), analysis.content(id)),
            ),
        Positioned.fill(
          key: const ValueKey('inventory-opa-ooparts'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const ValueKey('inventory-opa-surface'),
                    painter: _InventoryMorphSurfacePainter(morph),
                  ),
                ),
              ),
              Positioned.fill(
                child: analysis.ooparts(morph: morph, reveal: reveal),
              ),
            ],
          ),
        ),
        if (exit < 1) ...[
          leaving(
            inventoryAnalysisSchoolsSectionId,
            _sectionLayer(
              inventoryAnalysisSection(inventoryAnalysisSchoolsSectionId),
              analysis.content(inventoryAnalysisSchoolsSectionId),
            ),
          ),
          leaving(
            inventorySidebarSectionId,
            Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _InventorySurfacesPainter([
                      inventoryAnalysisSection(inventorySidebarSectionId),
                    ]),
                  ),
                ),
                _sidebar,
              ],
            ),
          ),
        ],
      ],
    );
    return settled ? stack : IgnorePointer(child: stack);
  }
}

/// 확장 중 S2 표면(접힘 → 확장 morph path, 키트 [buildSectionMorphPath]).
class _InventoryMorphSurfacePainter extends CustomPainter {
  const _InventoryMorphSurfacePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) => paintSectionSurface(
    canvas,
    buildSectionMorphPath(
      size,
      inventoryAnalysisSection(inventoryAnalysisOopartsSectionId),
      inventoryAnalysisOopartsExpandedSection,
      progress,
    ),
  );

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_InventoryMorphSurfacePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// C 안쪽 스크롤 패널(시안 rgba(26,44,59,.9) + 1px rgba(56,81,107,.72)).
class _RiskPanelPainter extends CustomPainter {
  const _RiskPanelPainter(this.quad);

  final _SectionQuad quad;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = InventoryMetrics.panelInset;
    const horizontal = InventoryMetrics.panelHorizontalInset;
    final top = quad.top + inset;
    final bottom = quad.bottom - inset;
    final path = diagonalRoundedPolygon(
      [
        Offset(quad.leftAt(top) + horizontal, top),
        Offset(quad.rightAt(top) - horizontal, top),
        Offset(quad.rightAt(bottom) - horizontal, bottom),
        Offset(quad.leftAt(bottom) + horizontal, bottom),
      ],
      radius: 10,
      corner: DiagonalCornerStyle.quadratic,
    );
    canvas.drawPath(path, Paint()..color = inventoryPanelFill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = inventoryPanelBorder,
    );
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_RiskPanelPainter oldDelegate) =>
      oldDelegate.quad.topLeft != quad.topLeft ||
      oldDelegate.quad.bottomRight != quad.bottomRight;
}

/// 상자 크기의 80° 평행사변형(아랫변 왼쪽 0, 윗변 오른쪽 끝 = 상자 폭).
class _ParallelogramClipper extends CustomClipper<Path> {
  const _ParallelogramClipper();

  @override
  Path getClip(Size size) {
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

  @override
  bool shouldReclip(_ParallelogramClipper oldClipper) => false;
}

/// 목록 자리 가운데 알림.
class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    key: const ValueKey('inventory-notice'),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      // 아주 작은 창에서도 넘치지 않게 알림 묶음만 줄인다.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (action case final action?) ...[
                const SizedBox(height: 10),
                action,
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// 정렬 칩(시안 `.chip pk` 고름 / `.chip gy`).
class _SortChip extends StatelessWidget {
  const _SortChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => KitPressable(
    onPressed: onPressed,
    semanticLabel: '$label 순 정렬',
    selected: selected,
    builder: (context, state) =>
        BaChip(label: label, tone: selected ? AppTones.pink : AppTones.gray),
  );
}

/// 전체 보기 거르기 칩(켜짐 분홍 / 꺼짐 회색). 의미 트리에는 켜고 끄는 단추로 알린다.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.on,
    required this.onPressed,
  });

  final String label;
  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => KitPressable(
    onPressed: onPressed,
    semanticLabel: label,
    toggled: on,
    builder: (context, state) =>
        BaChip(label: label, tone: on ? AppTones.pink : AppTones.gray),
  );
}

/// KPI 값 하나.
@immutable
class _KpiValue {
  const _KpiValue(this.id, this.label, this.value, {this.color, this.delta});

  final String id;
  final String label;
  final String value;
  final Color? color;
  final String? delta;
}

/// KPI 칸(시안 `.kv`: 라벨 15px, 값 `.dsp` 36px, 오른쪽 작은 변화 글자).
class _KpiCell extends StatelessWidget {
  const _KpiCell({required this.item});

  final _KpiValue item;

  @override
  Widget build(BuildContext context) {
    final delta = item.delta;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KV.labelStyle.copyWith(fontSize: AppType.bodyLargeSize),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                item.value,
                key: ValueKey('inventory-kpi-${item.id}'),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: kitDisplayStyle(
                  AppType.displayLargeSize,
                  color: item.value == '—'
                      ? AppColors.textMuted
                      : item.color ?? AppColors.text,
                ),
              ),
            ),
            if (delta != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  delta,
                  key: ValueKey('inventory-kpi-${item.id}-delta'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _muted.copyWith(fontWeight: AppType.bold),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// 품목 아이콘(`.pt`). 아이콘 그림이 없으면 이름 앞 두 글자를 배경 위에 쓴다.
Widget _itemIcon(InventoryItemView view, Size size) {
  final icon = planningResourceIconAsset(
    category: view.item.category,
    itemId: view.item.itemId,
  );
  final name = view.item.displayName;
  return ItemIconTile(
    iconAsset: icon,
    size: size,
    label: icon == null ? name.substring(0, math.min(4, name.length)) : null,
    semanticLabel: name,
  );
}

/// 전체 아이템 타일(키트 [ItemTile] 74×74). 막대: 계획에 안 쓰면 없음, 보유 모름이면 빗금, 부족 분홍 · 충분 파랑 ·
/// 과잉 노랑(FD-040). 숫자는 보유량(모르면 `—`)이다.
class InventoryItemTile extends StatelessWidget {
  const InventoryItemTile({
    super.key,
    required this.view,
    required this.selected,
    this.needsReview = false,
    required this.onTap,
  });

  final InventoryItemView view;
  final bool selected;

  /// 확인 필요 표시(FB-10b). 74px 타일에는 칩이 들어가지 않아 왼쪽 위 warn 점으로 보인다(상세에 칩).
  final bool needsReview;
  final VoidCallback onTap;

  /// 키트 막대 색과 채움 비율. 막대가 없으면 null.
  static ({CoverageTone tone, double? fraction})? bar(InventoryItemView view) =>
      switch (inventoryTileTone(view)) {
        InventoryTileTone.none => null,
        InventoryTileTone.unknown => (tone: CoverageTone.shortage, fraction: null),
        InventoryTileTone.shortage => (
          tone: CoverageTone.shortage,
          fraction: view.fulfillment,
        ),
        InventoryTileTone.enough => (tone: CoverageTone.enough, fraction: 1.0),
        InventoryTileTone.excess => (tone: CoverageTone.excess, fraction: 1.0),
      };

  @override
  Widget build(BuildContext context) {
    final owned = view.owned;
    final icon = planningResourceIconAsset(
      category: view.item.category,
      itemId: view.item.itemId,
    );
    final name = view.item.displayName;
    final bar = InventoryItemTile.bar(view);
    final tile = ItemTile(
      quantity: owned == null ? '—' : inventoryAmount(owned),
      iconAsset: icon,
      label: icon == null ? name.substring(0, math.min(4, name.length)) : null,
      tone: bar?.tone,
      fraction: bar?.fraction,
      selected: selected,
    );
    return KitPressable(
      onPressed: onTap,
      selected: selected,
      semanticLabel:
          '$name 보유 ${owned ?? '모름'}${needsReview ? ' · 확인 필요' : ''}',
      builder: (context, state) => needsReview
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                tile,
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    key: ValueKey('inventory-tile-review-${view.key}'),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppTones.warn.base,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTones.warn.background),
                    ),
                  ),
                ),
              ],
            )
          : tile,
    );
  }
}

/// 타일 그룹 머리(`.ihdr` 이름 + "n종" + "부족 n" 칩). 칩에 마우스를 올리거나 누르면 부족량 순 상위 5 플라이아웃이 열린다.
class _TileGroupHeader extends StatelessWidget {
  const _TileGroupHeader({
    super.key,
    required this.group,
    required this.onShowAll,
  });

  final InventoryTileGroup group;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final shortages = group.shortages;
    final label = group.label;
    // 머리 띠는 칩 높이로 줄 위에 붙인다(띠 24 + 타일까지 6 = 시안 22 + 8과 같은 30).
    return Padding(
      padding: const EdgeInsets.only(left: InventoryAllMetrics.headerLeft),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: AppControlHeights.chip,
          child: Row(
            children: [
              // 모르는 category는 id를 그대로 이름으로 쓰므로 길면 줄여 맞춘다.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SubHeader(label, fontSize: AppType.microSize),
                ),
              ),
              const SizedBox(width: 8),
              Text('${group.items.length}종', maxLines: 1, style: _muted),
              if (shortages.isNotEmpty) ...[
                const SizedBox(width: 8),
                AnchoredFlyout(
                  key: ValueKey('inventory-group-flyout-${group.id}'),
                  semanticLabel: '부족한 $label 보기',
                  panelLabel: '부족한 $label',
                  children: [
                    FlyoutHeader(
                      '부족한 $label ${shortages.length}종',
                      note: '부족량 순 · 상위 5',
                    ),
                    for (final view in shortages.take(5))
                      ShortageBreakdownRow(
                        item: ShortageItem(
                          name: view.item.displayName,
                          shortage: view.shortageAmount!,
                          owned: view.owned,
                          needed: view.requiredAmount,
                          iconAsset: planningResourceIconAsset(
                            category: view.item.category,
                            itemId: view.item.itemId,
                          ),
                        ),
                      ),
                    FlyoutFooter(
                      text: shortages.length > 5
                          ? '… 외 ${shortages.length - 5}종'
                          : null,
                      trailing: KitPressable(
                        onPressed: onShowAll,
                        semanticLabel: '부족한 $label 모두 보기',
                        builder: (context, state) =>
                            const FlyoutLink('모두 보기 →'),
                      ),
                    ),
                  ],
                  child: BaChip(
                    label: '부족 ${shortages.length}',
                    tone: AppTones.pink,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 위험도 행(시안 `button.srow` 1010×58).
class InventoryRiskRow extends StatelessWidget {
  const InventoryRiskRow({
    super.key,
    required this.view,
    required this.selected,
    this.needsReview = false,
    required this.onTap,
  });

  final InventoryItemView view;
  final bool selected;

  /// 확인 필요 표시(FB-10b): 이름 옆 warn 칩(시안 Scan-Item-Review `.chip.wn`).
  final bool needsReview;
  final VoidCallback onTap;

  /// 행 보조 글자(`보유 1 / 필요 450 · 사용 학생 1명`).
  static String summary(InventoryItemView view) {
    final owned = _amountOrDash(view.owned);
    if (!view.planned) return '보유 $owned · 계획에 쓰지 않음';
    return '보유 $owned / 필요 ${_amountOrDash(view.requiredAmount)} · 사용 학생 ${view.studentCount}명';
  }

  @override
  Widget build(BuildContext context) {
    final risk = view.risk;
    final name = Text(
      view.item.displayName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _body,
    );
    return DiagonalRow(
      variant: DiagonalRowVariant.srow,
      mark: selected ? DiagonalRowMark.selected : DiagonalRowMark.none,
      onTap: onTap,
      child: _Fit(
        minWidth: 560,
        minHeight: InventoryMetrics.rowHeight,
        child: Row(
          children: [
            const SizedBox(width: 20),
            _itemIcon(view, const Size(54, 44)),
            const SizedBox(width: 14),
            SizedBox(
              width: 210,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (needsReview)
                    Row(
                      children: [
                        Flexible(child: name),
                        const SizedBox(width: 6),
                        BaChip(
                          key: ValueKey('inventory-row-review-${view.key}'),
                          label: '확인 필요',
                          tone: AppTones.warn,
                        ),
                      ],
                    )
                  else
                    name,
                  const SizedBox(height: 2),
                  Text(
                    summary(view),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _muted,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: view.planned
                  ? SkewBar(
                      key: ValueKey('inventory-risk-bar-${view.key}'),
                      fraction: risk == null ? null : risk / 100,
                      color: inventoryRiskColor(risk),
                      height: 10,
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 54,
              child: Text(
                view.planned ? inventoryRiskLabel(risk) : '',
                key: ValueKey('inventory-risk-${view.key}'),
                textAlign: TextAlign.right,
                maxLines: 1,
                style: kitDisplayStyle(
                  AppType.titleSmallSize,
                  color: risk == null
                      ? AppColors.textMuted
                      : inventoryRiskColor(risk),
                ),
              ),
            ),
            const SizedBox(width: 78),
          ],
        ),
      ),
    );
  }
}

/// 주요 재화 카드(시안 `.btn.ghost` 548×66: `.pt` 37×30 · 이름 · 보유 / 필요 · 차이 · 막대).
class _CurrencyCard extends StatelessWidget {
  const _CurrencyCard({
    super.key,
    required this.view,
    required this.selected,
    required this.onPressed,
  });

  final InventoryItemView view;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final shortage = view.shortageAmount;
    final required = view.requiredAmount;
    return RailButton(
      variant: selected ? RailButtonVariant.selectedPink : RailButtonVariant.ghost,
      height: InventoryMetrics.currencyCardHeight,
      semanticLabel: view.item.displayName,
      onPressed: onPressed,
      child: Row(
        children: [
          _itemIcon(view, const Size(37, 30)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        view.item.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _amountOrDash(view.owned),
                      key: ValueKey('inventory-currency-owned-${view.key}'),
                      maxLines: 1,
                      style: kitDisplayStyle(AppType.bodyLargeSize),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '/ 필요 ${required == null ? '—' : inventoryAmount(required)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _muted,
                      ),
                    ),
                    if (shortage != null && shortage > 0) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '−${inventoryAmount(shortage)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _muted.copyWith(
                            color: AppColors.accentText,
                            fontWeight: AppType.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                SkewBar(
                  fraction: required == null ? null : view.fulfillment,
                  color: view.knownShortage
                      ? AppColors.accent
                      : AppColors.primary,
                  height: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 상세 머리(`.pt` 111×90 · 이름 `.dsp` 20 · 메타).
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.view});

  final InventoryItemView view;

  /// FB-3 메타 줄(종류 · 학교 · 티어). 재화는 "스캔으로만 바뀌는 재화".
  static String meta(InventoryItemView view) {
    final item = view.item;
    final parts = <String>[
      inventoryCategoryLabel(item.category),
      ?item.school,
      if (item.tier case final tier?) 'T$tier',
      if (view.isCurrency) '스캔으로만 바뀌는 재화',
      if (!view.present && !view.isCurrency) '저장된 수량 없음',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _itemIcon(view, const Size(111, 90)),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              view.item.displayName,
              key: const ValueKey('inventory-detail-name'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kitDisplayStyle(AppType.headlineSize),
            ),
            const SizedBox(height: 6),
            Text(
              meta(view),
              key: const ValueKey('inventory-detail-meta'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _muted.copyWith(fontSize: AppType.bodySmallSize),
            ),
          ],
        ),
      ),
    ],
  );
}

/// 상세 kv 한 칸(라벨 + `.dsp` 26).
class _DetailKv extends StatelessWidget {
  const _DetailKv(this.id, this.label, this.value, {this.color});

  final String id;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: KV(
      label: label,
      value: Text(
        value,
        key: ValueKey('inventory-detail-$id'),
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: kitDisplayStyle(
          AppType.displaySmallSize,
          color: value == '—' ? AppColors.textMuted : color ?? AppColors.text,
        ),
      ),
    ),
  );
}

/// 사용 학생 줄(`리오(무장) · 페이즈 1 · 1단계 (성급 3→5)  −449`).
class _UseRow extends StatelessWidget {
  const _UseRow({super.key, required this.use, required this.studentName});

  final InventoryStageUse use;
  final String studentName;

  @override
  Widget build(BuildContext context) {
    final shortage = use.shortageAtEntry;
    return DiagonalRow(
      variant: DiagonalRowVariant.row,
      padding: const EdgeInsets.fromLTRB(21, 0, 24, 0),
      child: Row(
        children: [
          ItemIconTile(
            iconAsset: GameAssets.studentPortrait(use.studentId),
            size: const Size(38, 30),
            semanticLabel: studentName,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text:
                        '$studentName · 페이즈 ${use.phaseNumber} · ${use.studentStep}단계',
                  ),
                  if (use.stageName.isNotEmpty)
                    TextSpan(text: ' (${use.stageName})', style: _muted),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            shortage != null && shortage > 0
                ? '−${inventoryAmount(shortage)}'
                : '필요 ${inventoryAmount(use.requiredAmount)}',
            maxLines: 1,
            style: shortage != null && shortage > 0
                ? kitDisplayStyle(AppType.bodyLargeSize, color: AppColors.accent)
                : _muted,
          ),
        ],
      ),
    );
  }
}

/// 상세의 한 줄 정보(`.row`: 제목 + 보조 글자 + 선택 버튼).
/// 상세 "최근 변화" 스파크라인 줄(FE6-f, 시안 `.row` 112 안 svg 92).
class _SparklineRow extends StatelessWidget {
  const _SparklineRow({required this.points});

  final List<InventorySparkPoint> points;

  @override
  Widget build(BuildContext context) => DiagonalRow(
    variant: DiagonalRowVariant.row,
    padding: const EdgeInsets.fromLTRB(
      InventoryMetrics.sparklineLeft,
      0,
      InventoryMetrics.sparklineRight,
      0,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        // svg 폭 = 줄 폭 − 70 = 안쪽 폭 − (70 − 31.7 − 14).
        final width = math.max(
          0.0,
          constraints.maxWidth -
              (InventoryMetrics.sparklineWidthInset -
                  InventoryMetrics.sparklineLeft -
                  InventoryMetrics.sparklineRight),
        );
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: width,
            height: InventorySparklineMetrics.height,
            child: CustomPaint(
              key: const ValueKey('inventory-history-sparkline-paint'),
              painter: InventorySparklinePainter(points: points),
            ),
          ),
        );
      },
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({super.key, required this.title, this.detail, this.action});

  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    final action = this.action;
    return DiagonalRow(
      variant: DiagonalRowVariant.row,
      padding: const EdgeInsets.fromLTRB(20, 0, 24, 0),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _muted.copyWith(fontSize: AppType.bodySmallSize),
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(width: 10), action],
        ],
      ),
    );
  }
}

/// 상세 확인 필요 줄(FB-10b): warn 칩 · 설명 · "이 값이 맞습니다". 저장된 수량이 없는 표시는 확인 대신 직접 고치기로
/// 넣도록 안내한다(백엔드 scope는 저장 전후에 있는 항목만 받는다).
class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.controller, required this.view});

  final InventoryController controller;
  final InventoryItemView view;

  @override
  Widget build(BuildContext context) {
    final editing = controller.editingKey == view.key;
    return Row(
      children: [
        const BaChip(
          key: ValueKey('inventory-detail-review'),
          label: '확인 필요',
          tone: AppTones.warn,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            view.present
                ? '스캔에서 적용하지 않아 이전 값으로 남아 있습니다.'
                : '스캔에서 적용하지 않았고 저장된 수량이 없습니다. 수량 직접 고치기로 넣어 주십시오.',
            key: const ValueKey('inventory-review-note'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _muted,
          ),
        ),
        if (view.present && !editing) ...[
          const SizedBox(width: 10),
          TonalButton(
            key: const ValueKey('inventory-review-confirm'),
            label: '이 값이 맞습니다',
            onPressed: controller.canConfirmReview(view.key)
                ? () => controller.confirmReview(view.key)
                : null,
          ),
        ],
      ],
    );
  }
}

/// "수량 직접 고치기" 칸. 입력은 컨트롤러 draft로 가고, 저장은 bucket 전체를 보낸다.
class _QuantityEditor extends StatefulWidget {
  const _QuantityEditor({
    super.key,
    required this.controller,
    required this.itemKey,
  });

  final InventoryController controller;
  final String itemKey;

  @override
  State<_QuantityEditor> createState() => _QuantityEditorState();
}

class _QuantityEditorState extends State<_QuantityEditor> {
  late final TextEditingController _text = TextEditingController(
    text: widget.controller.draftFor(widget.itemKey),
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving = widget.controller.saving;
    return Row(
      children: [
        SizedBox(
          width: 200,
          child: TextField(
            key: ValueKey('inventory-quantity-${widget.itemKey}'),
            controller: _text,
            enabled: !saving,
            keyboardType: TextInputType.number,
            onChanged: (value) =>
                widget.controller.setDraft(widget.itemKey, value),
            decoration: const InputDecoration(
              isDense: true,
              labelText: '보유 수량',
              hintText: '모름',
            ),
          ),
        ),
        const SizedBox(width: 12),
        TonalButton(
          key: const ValueKey('inventory-edit-save'),
          label: saving ? '저장 중' : '저장',
          variant: TonalButtonVariant.primary,
          onPressed: saving
              ? null
              : () => widget.controller.saveQuantity(widget.itemKey, _text.text),
        ),
        const SizedBox(width: 8),
        TonalButton(
          key: const ValueKey('inventory-edit-cancel'),
          label: '취소',
          variant: TonalButtonVariant.ghost,
          onPressed: saving ? null : widget.controller.cancelEdit,
        ),
        const SizedBox(width: 12),
        const Flexible(
          child: Text(
            '빈 칸은 모름으로 저장합니다.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _muted,
          ),
        ),
      ],
    );
  }
}

/// [request]가 오면 이 행이 처음 그려진 다음 프레임에 한 번, 화면 밖(일부라도)이면 목록 가운데로 스크롤한다(tidy1, FE7-d 발견 2).
/// 키트 viewport는 고치지 않고 행이 속한 Scrollable의 position과 viewport의 `getOffsetToReveal`을 쓴다(행이 모두 그려지는
/// 목록이라 행 render box가 늘 있다).
class _RevealOnRequest extends StatefulWidget {
  const _RevealOnRequest({required this.request, required this.child});

  final InventoryRevealRequest? request;
  final Widget child;

  @override
  State<_RevealOnRequest> createState() => _RevealOnRequestState();
}

class _RevealOnRequestState extends State<_RevealOnRequest> {
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(_RevealOnRequest oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.request, widget.request)) _schedule();
  }

  void _schedule() {
    final request = widget.request;
    if (request == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(request));
  }

  void _reveal(InventoryRevealRequest request) {
    if (!mounted || !identical(widget.request, request)) return;
    final box = context.findRenderObject();
    final position = Scrollable.maybeOf(context)?.position;
    if (box is! RenderBox || !box.hasSize || position == null) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null || !request.consume()) return;
    // 위 끝을 viewport 위에 맞추는 offset ≥ 지금 ≥ 아래 끝을 viewport 아래에 맞추는 offset이면 다 보인다.
    final topAligned = viewport.getOffsetToReveal(box, 0).offset;
    final bottomAligned = viewport.getOffsetToReveal(box, 1).offset;
    if (position.pixels <= topAligned && position.pixels >= bottomAligned) {
      return;
    }
    final target = viewport
        .getOffsetToReveal(box, 0.5)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    position.animateTo(
      target,
      duration: AppMotion.header,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
