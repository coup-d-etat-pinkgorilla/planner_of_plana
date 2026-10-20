// 인벤토리 분석 모드 섹션(FE6-c, 시안 Inventory-Analysis, E 보고서 §3).
//
// - A 사이드바 분석 메뉴: "비교 기준"(계획 요구량 / 이론상 전체 요구량은 비활성, FD-097) · 설명 · "이 화면에 보이는 분석"
//   버튼 4개(누르면 그 섹션 외곽을 분홍으로 강조하고 버튼이 선택 상태가 된다. 다시 누르면 푼다. "장비 설계도"는 S4를
//   설계도 보기로 돌린다) · "따로 여는 화면"(티어별 충족률 FE6-e: 누르면 선택(분홍) 상태로 티어 화면을 열고 다시 누르면
//   닫는다. 열려 있는 동안 분석 버튼 4개는 고르지 않은 모양이고, 누르면 분석으로 돌아간다. 넘치는 재화 정리는 숨김
//   FD-097).
// - S1 학교별 BD · 기술 노트 충족률: 학교 행(엠블럼 · 이름 · BD 막대 + % · 노트 막대 + % · 부족 티어 · "계획 n명" 칩 →
//   학생별 부족 필요량 플라이아웃). "계획 필요 환산량 기준" 칩은 숨김(FD-100).
// - S2 오파츠 · 보유율 × 수요: 티어 토글 + 산점도(`inventory_analysis_charts.dart`). 점을 누르면 그 오파츠를 고른다.
//   "확장"(FE6-d)은 사이드바 · S1 · S4 · S5를 빼고 S2를 키운 뒤 선택 오파츠 상세 열을 보인다(`inventory_opa_sections.dart`).
// - S4 종류 × 티어 충족률: 종류 seg · 표시 칩 · 히트맵 · 범례 · 부족 상위 3행.
// - S5 최근 변화(FE6-f): 기간 seg(1주 · 2주 · 4주)의 재화별 순증감 상위 6행(가운데 축 기준 증가 오른쪽 · 감소 왼쪽 막대,
//   `inventory_history_charts.dart`)과 "이 추세라면" 예측 행(FD-042, 스캔 점 3회 미만이면 숨김). 집계는
//   `inventory_history.dart`다. 기간 처음 수량을 모르면 안내만 보인다.
part of 'inventory_workspace.dart';

const _analysisFocusSections = {
  InventoryAnalysisFocus.schools: inventoryAnalysisSchoolsSectionId,
  InventoryAnalysisFocus.ooparts: inventoryAnalysisOopartsSectionId,
  InventoryAnalysisFocus.blueprints: inventoryAnalysisTiersSectionId,
  InventoryAnalysisFocus.changes: inventoryAnalysisChangesSectionId,
};

extension _InventoryAnalysisSidebar on InventoryWorkspace {
  /// A 사이드바의 분석 메뉴(최상단 seg 아래).
  List<Widget> _analysisSidebar(
    double top,
    double Function(double) width,
    Rect Function(double, double) row,
  ) {
    final enabled = controller.loaded && !controller.loading;
    final tiersOpen = controller.tiersOpen;
    const segHeight = InventoryAnalysisMetrics.compareSegHeight;
    final segTop = top + InventoryAnalysisMetrics.compareSegTop;
    final noteTop = top + InventoryAnalysisMetrics.compareNoteTop;
    return [
      _sideCaption(
        top + InventoryAnalysisMetrics.compareCaptionTop,
        width,
        '비교 기준',
      ),
      Positioned(
        left: InventoryMetrics.sidebarTextLeft,
        top: segTop,
        width: width(segTop),
        height: segHeight,
        child: _Fit(
          minWidth: 300,
          minHeight: segHeight,
          child: Row(
            children: [
              SkewSegmented<String>(
                key: const ValueKey('inventory-compare-plan'),
                segments: const [SkewSegment(value: 'plan', label: '계획 요구량')],
                selected: 'plan',
                onChanged: (_) {},
                height: segHeight,
                fontSize: AppType.bodySmallSize,
              ),
              const SizedBox(width: 6),
              // FD-097: 이론상 전체 요구량은 이번 범위 밖이라 꺼 둔다.
              Semantics(
                label: '이론상 전체 요구량은 준비 중입니다',
                child: const SkewSegmented<String>(
                  key: ValueKey('inventory-compare-theory'),
                  segments: [SkewSegment(value: 'theory', label: '이론상 전체 요구량')],
                  selected: null,
                  onChanged: null,
                  height: segHeight,
                  fontSize: AppType.bodySmallSize,
                ),
              ),
            ],
          ),
        ),
      ),
      Positioned(
        left: InventoryMetrics.sidebarTextLeft,
        top: noteTop,
        width: width(noteTop),
        height: 16,
        child: Text(
          '활성 계획의 학생·목표에 필요한 양과 비교합니다',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _muted,
        ),
      ),
      _sideCaption(
        top + InventoryAnalysisMetrics.focusCaptionTop,
        width,
        '이 화면에 보이는 분석',
      ),
      for (final (index, focus) in InventoryAnalysisFocus.values.indexed)
        Positioned.fromRect(
          rect: row(
            InventoryAnalysisMetrics.focusButtonTop +
                index * InventoryAnalysisMetrics.focusButtonPitch,
            InventoryAnalysisMetrics.focusButtonHeight,
          ),
          child: _railButton(
            key: 'inventory-analysis-focus-${focus.name}',
            variant: !tiersOpen && controller.analysisFocus == focus
                ? RailButtonVariant.selectedPink
                : RailButtonVariant.ghost,
            height: InventoryAnalysisMetrics.focusButtonHeight,
            onPressed: enabled
                ? () => controller.toggleAnalysisFocus(focus)
                : null,
            label: focus.label,
            trailing: const [
              CustomPaint(
                size: Size.square(16),
                painter: _AnalysisGlyphPainter(_AnalysisGlyph.check),
              ),
            ],
          ),
        ),
      _sideCaption(
        top + InventoryAnalysisMetrics.screenCaptionTop,
        width,
        '따로 여는 화면',
      ),
      // 티어별 충족률 화면(FE6-e). "넘치는 재화 정리"는 FD-097로 숨긴다.
      Positioned.fromRect(
        rect: row(
          InventoryAnalysisMetrics.screenButtonTop,
          InventoryAnalysisMetrics.screenButtonHeight,
        ),
        child: _Fit(
          minWidth: 240,
          minHeight: InventoryAnalysisMetrics.screenButtonHeight,
          child: RailButton(
            key: const ValueKey('inventory-analysis-open-tiers'),
            variant: tiersOpen
                ? RailButtonVariant.selectedPink
                : RailButtonVariant.ghost,
            height: InventoryAnalysisMetrics.screenButtonHeight,
            semanticLabel: tiersOpen ? '티어별 충족률 닫기' : '티어별 충족률 열기',
            onPressed: enabled ? controller.toggleTiers : null,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '티어별 충족률',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _body.copyWith(
                          fontSize: AppType.titleSmallSize,
                          fontWeight: AppType.bold,
                        ),
                      ),
                      const Text(
                        '기술 노트 · BD · 오파츠',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _muted,
                      ),
                    ],
                  ),
                ),
                const CustomPaint(
                  size: Size.square(16),
                  painter: _AnalysisGlyphPainter(_AnalysisGlyph.arrow),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}

/// 사이드바 버튼 끝 글리프(시안 svg 24 단위, 굵기 1.9).
enum _AnalysisGlyph {
  /// `M5 12.5l4.5 4.5L19 7.5`
  check,

  /// `M5 12h14M13 6l6 6-6 6`
  arrow,

  /// 확장(FE6-d, 시안 "확장" 버튼) `M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7`
  expand,

  /// 축소(FE6-d, 시안 "축소" 버튼) `M4 14h6v6M20 10h-6V4M14 10l7-7M3 21l7-7`
  collapse,

  /// 단계(FE6-d, 시안 "계획에서 쓰는 단계 보기") `M12 3l9 5-9 5-9-5 9-5z` + `M3 13l9 5 9-5`
  layers,
}

class _AnalysisGlyphPainter extends CustomPainter {
  const _AnalysisGlyphPainter(this.glyph, {this.color = AppColors.textSecondary});

  final _AnalysisGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = switch (glyph) {
      _AnalysisGlyph.check =>
        Path()
          ..moveTo(5, 12.5)
          ..lineTo(9.5, 17)
          ..lineTo(19, 7.5),
      _AnalysisGlyph.arrow =>
        Path()
          ..moveTo(5, 12)
          ..lineTo(19, 12)
          ..moveTo(13, 6)
          ..lineTo(19, 12)
          ..lineTo(13, 18),
      _AnalysisGlyph.expand =>
        Path()
          ..moveTo(15, 3)
          ..lineTo(21, 3)
          ..lineTo(21, 9)
          ..moveTo(9, 21)
          ..lineTo(3, 21)
          ..lineTo(3, 15)
          ..moveTo(21, 3)
          ..lineTo(14, 10)
          ..moveTo(3, 21)
          ..lineTo(10, 14),
      _AnalysisGlyph.collapse =>
        Path()
          ..moveTo(4, 14)
          ..lineTo(10, 14)
          ..lineTo(10, 20)
          ..moveTo(20, 10)
          ..lineTo(14, 10)
          ..lineTo(14, 4)
          ..moveTo(14, 10)
          ..lineTo(21, 3)
          ..moveTo(3, 21)
          ..lineTo(10, 14),
      _AnalysisGlyph.layers =>
        Path()
          ..moveTo(12, 3)
          ..lineTo(21, 8)
          ..lineTo(12, 13)
          ..lineTo(3, 8)
          ..close()
          ..moveTo(3, 13)
          ..lineTo(12, 18)
          ..lineTo(21, 13),
    };
    canvas.save();
    canvas.scale(size.width / 24);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AnalysisGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

/// 분석 모드 네 섹션(S1 · S2 · S4 · S5)과 강조 외곽선.
class _InventoryAnalysisSections extends StatelessWidget {
  const _InventoryAnalysisSections({
    super.key,
    required this.controller,
    required this.onOpenPlan,
    required this.size,
  });

  final InventoryController controller;
  final ValueChanged<String?> onOpenPlan;
  final Size size;

  _SectionQuad _quad(String id) => _SectionQuad.of(size, id, analysis: true);

  /// 계획 상태 때문에 분석을 그릴 수 없으면 그 안내. 그릴 수 있으면 null.
  String? get _blocker {
    if (controller.disconnected) {
      return '백엔드에 연결되지 않았습니다. 다시 연결하면 분석이 보입니다.';
    }
    if (controller.catalogError case final error?) return error;
    if (controller.profileError case final error?) return error;
    if (controller.loaded && !controller.loading && !controller.hasPlan) {
      return '저장된 계획이 없습니다. 계획 탭에서 계획을 저장하면 분석이 보입니다.';
    }
    if (controller.shortageError case final error?) return error;
    return null;
  }

  bool get _waiting => !controller.loaded || controller.loading;

  /// 섹션 [id] 하나의 내용(섹션 교체 모션이 섹션마다 따로 움직일 때 쓴다).
  Widget content(String id) => switch (id) {
    inventoryAnalysisSchoolsSectionId => _schools(),
    inventoryAnalysisOopartsSectionId => ooparts(),
    inventoryAnalysisTiersSectionId => _tiers(),
    _ => _changes(),
  };

  @override
  Widget build(BuildContext context) {
    final focus = controller.analysisFocus;
    final focusId = focus == null ? null : _analysisFocusSections[focus];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: _tiers()),
        Positioned.fill(child: _changes()),
        Positioned.fill(child: ooparts()),
        Positioned.fill(child: _schools()),
        if (focusId != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: ValueKey('inventory-analysis-highlight-$focusId'),
                painter: _AnalysisHighlightPainter(focusId),
              ),
            ),
          ),
      ],
    );
  }

  // --- 공통 -------------------------------------------------------------------

  /// 섹션 제목 줄(위 20, 높이 40). [left]는 줄 아래 왼쪽이 왼쪽 변에서 떨어진 거리, [inner] · [innerRight]는 줄 안
  /// 왼쪽 · 오른쪽 여백이다.
  Widget _title(
    _SectionQuad quad,
    String title, {
    double left = InventoryAnalysisMetrics.titleLeft,
    double inner = 17.1,
    double innerRight = 14,
    double minWidth = 520,
    List<Widget> trailing = const [],
  }) {
    final y = quad.top + InventoryAnalysisMetrics.titleTop;
    const height = InventoryAnalysisMetrics.titleHeight;
    final x = quad.leftAt(y + height) + left;
    return Positioned(
      left: x,
      top: y,
      width: math.max(
        0.0,
        quad.rightAt(y) - InventoryAnalysisMetrics.titleRight - x,
      ),
      height: height,
      child: _Fit(
        minWidth: minWidth,
        minHeight: height,
        child: Padding(
          padding: EdgeInsets.only(left: inner, right: innerRight),
          child: Row(
            children: [
              const TitleBar(width: 7, height: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kitDisplayStyle(AppType.panelTitleSize),
                ),
              ),
              ...trailing,
            ],
          ),
        ),
      ),
    );
  }

  /// 제목 아래 규칙선(위 65, 왼쪽 변에서 21.8, 오른쪽 여백 22).
  Widget _rule(_SectionQuad quad) {
    final y = quad.top + InventoryAnalysisMetrics.ruleTop;
    final x = quad.leftAt(y) + 21.8;
    return Positioned(
      left: x,
      top: y,
      width: math.max(0.0, quad.rightAt(y) - 22 - x),
      height: 3,
      child: const Align(
        alignment: Alignment.centerLeft,
        child: TitleRule(capWidth: 46),
      ),
    );
  }

  /// 섹션 본문 자리의 안내 글자(제목 아래부터 섹션 바닥까지, 사선 안쪽).
  Widget _notice(_SectionQuad quad, String key, String text, {String? detail}) {
    final y = quad.top + InventoryAnalysisMetrics.schoolRowsTop;
    final bottom = quad.bottom - 12;
    final left = quad.leftAt(y) + 40;
    return Positioned(
      left: left,
      top: y,
      width: math.max(0.0, quad.rightAt(y) - 40 - left),
      height: math.max(0.0, bottom - y),
      child: _AnalysisNotice(key: ValueKey(key), text: text, detail: detail),
    );
  }

  // --- S1 학교별 ----------------------------------------------------------------

  Widget _schools() {
    final quad = _quad(inventoryAnalysisSchoolsSectionId);
    final children = <Widget>[_title(quad, '학교별 BD · 기술 노트 충족률'), _rule(quad)];
    final blocker = _blocker;
    if (blocker != null) {
      children.add(_notice(quad, 'inventory-analysis-blocked', blocker));
      return Stack(clipBehavior: Clip.none, children: children);
    }
    if (_waiting) {
      children.add(
        Positioned(
          left: quad.leftAt(quad.bottom),
          top: quad.top + InventoryAnalysisMetrics.schoolRowsTop,
          width: math.max(0.0, quad.rightAt(quad.top) - quad.leftAt(quad.bottom)),
          height: math.max(
            0.0,
            quad.bottom - quad.top - InventoryAnalysisMetrics.schoolRowsTop,
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
      return Stack(clipBehavior: Clip.none, children: children);
    }
    final rows = controller.schoolRows;
    if (rows.isEmpty) {
      children.add(
        _notice(
          quad,
          'inventory-schools-empty',
          '계획에 쓰는 BD · 기술 노트가 없습니다.',
        ),
      );
      return Stack(clipBehavior: Clip.none, children: children);
    }
    // 행은 공용 사선 뷰포트(translate)에 둔다. 상자 바닥 왼쪽 + 안쪽 여백 = 행 아래 왼쪽(왼쪽 변에서 23.9).
    const inset = 8.0;
    final boxTop = quad.top + InventoryAnalysisMetrics.schoolRowsTop;
    final boxBottom = math.max(boxTop + 60, quad.bottom - 10);
    final boxLeft =
        quad.leftAt(boxBottom) + InventoryAnalysisMetrics.schoolRowLeft - inset;
    final box = Rect.fromLTRB(
      boxLeft,
      boxTop,
      math.max(boxLeft, quad.rightAt(boxTop) - 2),
      boxBottom,
    );
    children.add(
      Positioned.fromRect(
        rect: box,
        child: ClipPath(
          clipper: const _ParallelogramClipper(),
          child: DiagonalScrollViewport(
            key: const ValueKey('inventory-schools-viewport'),
            keyPrefix: 'inventory-schools-diagonal',
            itemCount: rows.length,
            itemHeight: (_) => InventoryAnalysisMetrics.schoolRowHeight,
            itemGap: InventoryAnalysisMetrics.schoolRowGap,
            verticalInset: 0,
            horizontalInset: inset,
            fog: const ScrollFogSpec.panel(color: inventoryPanelFill),
            itemBuilder: (context, index) => _SchoolRow(
              key: ValueKey('inventory-school-${rows[index].school}'),
              row: rows[index],
              studentName: controller.studentName,
              onOpenPlan: () => onOpenPlan(null),
            ),
          ),
        ),
      ),
    );
    return Stack(clipBehavior: Clip.none, children: children);
  }

  // --- S2 오파츠 ----------------------------------------------------------------

  /// S2 내용. [morph]는 접힘 0 → 확장 1 섹션 morph 진행(섹션 모양 · 산점도 크기 · 점 → 아이콘), [reveal]은 상세 열 등장
  /// 진행이다(FE6-d). 둘 다 0이면 FE6-c 접힌 S2 그대로다.
  Widget ooparts({double morph = 0, double reveal = 0}) {
    final quad = morph <= 0
        ? _quad(inventoryAnalysisOopartsSectionId)
        : _SectionQuad.fromPolygon(
            sectionMorphPolygon(
              size,
              inventoryAnalysisSection(inventoryAnalysisOopartsSectionId),
              inventoryAnalysisOopartsExpandedSection,
              morph,
            ),
          );
    final ready = _blocker == null && !_waiting;
    final expanded = controller.oopartExpanded;
    final buttonColors = TonalButtonColors.of(TonalButtonVariant.normal);
    final children = <Widget>[
      _title(
        quad,
        '오파츠 · 보유율 × 수요',
        // 작은 창에서도 "확장" · "축소"가 잘리지 않게 제목 글자를 먼저 줄인다(기준 viewport는 폭이 넉넉해 그대로).
        minWidth: 400,
        trailing: [
          const SizedBox(width: 10),
          BaChip(label: '왼쪽 위 = 핵심 병목', tone: AppTones.pink),
          const SizedBox(width: 18),
          // 시안 aria-label "오파츠 패널 확장", 축소는 FD-103으로 "오파츠 패널 축소"를 더한다. 아이콘은 시안 svg(14px)를
          // 기존 16px 자리 가운데에 그린다.
          TonalButton(
            key: const ValueKey('inventory-oopart-expand'),
            label: expanded ? '축소' : '확장',
            semanticLabel: expanded ? '오파츠 패널 축소' : '오파츠 패널 확장',
            leading: SizedBox.square(
              dimension: 16,
              child: Center(
                child: CustomPaint(
                  size: const Size.square(14),
                  painter: _AnalysisGlyphPainter(
                    expanded ? _AnalysisGlyph.collapse : _AnalysisGlyph.expand,
                    color: buttonColors.foreground,
                  ),
                ),
              ),
            ),
            height: 30,
            horizontalPadding: 12,
            fontSize: AppType.bodySmallSize,
            onPressed: ready
                ? () => controller.setOopartExpanded(!expanded)
                : null,
          ),
        ],
      ),
      _rule(quad),
    ];
    if (!ready) {
      return Stack(clipBehavior: Clip.none, children: children);
    }
    final analysis = controller.oopartAnalysis;
    final toggleTop = quad.top + InventoryAnalysisMetrics.tierToggleTop;
    const toggleHeight = InventoryAnalysisMetrics.tierToggleHeight;
    final toggleLeft =
        quad.leftAt(toggleTop + toggleHeight) +
        InventoryAnalysisMetrics.tierToggleLeft;
    final tiers = controller.oopartTiers;
    children.add(
      Positioned(
        left: toggleLeft,
        top: toggleTop,
        width: math.max(0.0, quad.rightAt(toggleTop) - 30 - toggleLeft),
        height: toggleHeight,
        child: _Fit(
          minWidth: 640,
          minHeight: toggleHeight,
          child: Padding(
            padding: const EdgeInsets.only(left: 15.3),
            child: Row(
              children: [
                for (final tier in const [1, 2, 3, 4]) ...[
                  if (tier > 1) const SizedBox(width: 6),
                  SkewSegmented<int>(
                    key: ValueKey('inventory-oopart-tier-$tier'),
                    segments: [
                      SkewSegment(
                        value: tier,
                        label: 'T$tier',
                        leading: _Dot(color: inventoryOopartTierColor(tier)),
                      ),
                    ],
                    selected: tiers.contains(tier) ? tier : null,
                    onChanged: controller.toggleOopartTier,
                    height: 26,
                    fontSize: AppType.captionSize,
                    horizontalPadding: 10,
                  ),
                ],
                const SizedBox(width: 20),
                const _BottleneckRing(),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    analysis.unknownKinds > 0
                        ? '핵심 병목 · 선은 같은 오파츠 · 보유 모름 ${analysis.unknownKinds}종 제외'
                        : '핵심 병목 · 선은 같은 오파츠',
                    key: const ValueKey('inventory-oopart-legend'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final geometry = InventoryScatterGeometry.at(morph);
    final frameTop = quad.top + InventoryAnalysisMetrics.scatterTop;
    final frameHeight = geometry.viewBox.height;
    final frameLeft =
        quad.leftAt(frameTop + frameHeight) +
        InventoryAnalysisMetrics.scatterLeft;
    final frameWidth = math.max(0.0, quad.rightAt(frameTop) - frameLeft);
    children.add(
      Positioned(
        left: frameLeft,
        top: frameTop,
        width: frameWidth,
        height: math.max(0.0, math.min(frameHeight, quad.bottom - frameTop)),
        child: _Fit(
          minWidth: geometry.viewBox.width,
          minHeight: frameHeight,
          child: analysis.isEmpty
              ? SizedBox(
                  width: geometry.viewBox.width,
                  height: frameHeight,
                  child: _AnalysisNotice(
                    key: const ValueKey('inventory-ooparts-empty'),
                    text: analysis.unknownKinds > 0
                        ? '계획에 쓰는 오파츠의 보유를 모릅니다.'
                        : '계획에 쓰는 오파츠가 없습니다.',
                    detail: analysis.unknownKinds > 0
                        ? '인벤토리를 스캔하면 보유율이 보입니다.'
                        : null,
                  ),
                )
              : _OopartScatter(
                  analysis: analysis,
                  tiers: tiers,
                  geometry: geometry,
                  icons: morph,
                  selectedFamily: controller.oopartSelectionExplicit
                      ? controller.selectedOopartFamily
                      : null,
                  onSelect: controller.selectOopart,
                ),
        ),
      ),
    );
    if (reveal > 0) children.add(_oopartDetail(quad, reveal));
    return Stack(clipBehavior: Clip.none, children: children);
  }

  // --- S4 종류 × 티어 -------------------------------------------------------------

  Widget _tiers() {
    final quad = _quad(inventoryAnalysisTiersSectionId);
    final kind = controller.heatmapKind;
    final value = controller.heatmapValue;
    final children = <Widget>[
      _title(
        quad,
        '종류 × 티어 충족률',
        left: 24,
        inner: 19.1,
        minWidth: 820,
        trailing: [
          const SizedBox(width: 10),
          SkewSegmented<InventoryHeatmapKind>(
            key: const ValueKey('inventory-heatmap-kind'),
            segments: [
              for (final item in InventoryHeatmapKind.values)
                SkewSegment(value: item, label: item.label),
            ],
            selected: kind,
            onChanged: controller.setHeatmapKind,
            height: 26,
            fontSize: AppType.captionSize,
          ),
          const SizedBox(width: 22),
          for (final item in InventoryHeatmapValue.values) ...[
            if (item != InventoryHeatmapValue.values.first)
              const SizedBox(width: 6),
            _SortChip(
              key: ValueKey('inventory-heatmap-value-${item.name}'),
              label: item.label,
              selected: value == item,
              onPressed: () => controller.setHeatmapValue(item),
            ),
          ],
        ],
      ),
      _rule(quad),
    ];
    if (_blocker != null || _waiting) {
      return Stack(clipBehavior: Clip.none, children: children);
    }
    final heatmap = controller.heatmap;
    final areaTop = quad.top + InventoryAnalysisMetrics.heatmapTop;
    const areaHeight = InventoryAnalysisMetrics.heatmapHeight;
    if (heatmap.rows.isEmpty) {
      final left = quad.leftAt(areaTop + areaHeight) + 40;
      children.add(
        Positioned(
          left: left,
          top: areaTop,
          width: math.max(0.0, quad.rightAt(areaTop) - 40 - left),
          height: areaHeight,
          child: _AnalysisNotice(
            key: const ValueKey('inventory-heatmap-empty'),
            text: '계획에 쓰는 ${kind.label}가 없습니다.',
          ),
        ),
      );
    } else {
      const legendHeight = 22.0;
      final rowCount = heatmap.rows.length + 1;
      final rowHeight = InventoryHeatmapGeometry.rowHeightFor(
        rowCount,
        areaHeight - legendHeight,
      );
      final gridHeight = InventoryHeatmapGeometry.gridHeight(rowCount, rowHeight);
      final gridTop = areaTop + (areaHeight - gridHeight - legendHeight) / 2;
      final gridBottom = gridTop + gridHeight;
      final gridLeft =
          quad.leftAt(gridBottom) + InventoryAnalysisMetrics.heatmapLeft;
      final canvasWidth = math.max(
        0.0,
        quad.rightAt(gridTop) - InventoryAnalysisMetrics.heatmapRight - gridLeft,
      );
      final gridWidth = canvasWidth - InventoryHeatmapGeometry.skew * gridHeight;
      children.add(
        Positioned(
          left: gridLeft,
          top: gridTop,
          width: canvasWidth,
          height: gridHeight,
          child: _Fit(
            minWidth: 520,
            minHeight: gridHeight,
            child: Semantics(
              label:
                  '${kind.label} 종류 × 티어 ${value.label} 히트맵, ${heatmap.rows.length}행',
              child: CustomPaint(
                key: const ValueKey('inventory-heatmap'),
                painter: InventoryTierHeatmapPainter(
                  heatmap: heatmap,
                  value: value,
                  amount: inventoryAmount,
                  rowHeight: rowHeight,
                ),
              ),
            ),
          ),
        ),
      );
      const legendLeft =
          InventoryHeatmapGeometry.labelWidth + InventoryHeatmapGeometry.gap;
      children.add(
        Positioned(
          left: gridLeft + legendLeft,
          top: gridBottom + 8,
          width: math.max(0.0, gridWidth - legendLeft),
          height: 14,
          child: const _HeatmapLegend(),
        ),
      );
    }
    // 부족 상위.
    final captionTop = quad.top + InventoryAnalysisMetrics.topCaptionTop;
    final captionLeft = quad.leftAt(captionTop + 24) + 24 + 16.2;
    children.add(
      Positioned(
        left: captionLeft,
        top: captionTop,
        width: math.max(0.0, quad.rightAt(captionTop) - 22 - captionLeft),
        height: 24,
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Text('부족 상위', maxLines: 1, style: _captionStyle),
        ),
      ),
    );
    final top = heatmap.top;
    if (top.isEmpty) {
      final y = quad.top + InventoryAnalysisMetrics.topRowsTop;
      final left = quad.leftAt(y + InventoryAnalysisMetrics.topRowHeight) + 40;
      children.add(
        Positioned(
          left: left,
          top: y,
          width: math.max(0.0, quad.rightAt(y) - 40 - left),
          height: InventoryAnalysisMetrics.topRowHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '부족한 ${kind.label}가 없습니다.',
              key: const ValueKey('inventory-top-shortage-empty'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _muted.copyWith(fontSize: AppType.bodySmallSize),
            ),
          ),
        ),
      );
    }
    for (final (index, shortage) in top.indexed) {
      final y =
          quad.top +
          InventoryAnalysisMetrics.topRowsTop +
          index * InventoryAnalysisMetrics.topRowPitch;
      const height = InventoryAnalysisMetrics.topRowHeight;
      final left = quad.leftAt(y + height) + InventoryAnalysisMetrics.topRowLeft;
      children.add(
        Positioned(
          left: left,
          top: y,
          width: math.max(
            0.0,
            quad.rightAt(y) - InventoryAnalysisMetrics.topRowRight - left,
          ),
          height: height,
          child: _Fit(
            minWidth: 640,
            minHeight: height,
            child: _TopShortageRow(
              key: ValueKey('inventory-top-shortage-$index'),
              shortage: shortage,
            ),
          ),
        ),
      );
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }

  // --- S5 최근 변화 ---------------------------------------------------------------

  Widget _changes() {
    final quad = _quad(inventoryAnalysisChangesSectionId);
    final children = <Widget>[
      _title(
        quad,
        '최근 변화',
        left: 23.9,
        inner: 19.1,
        minWidth: 420,
        trailing: [
          const SizedBox(width: 10),
          SkewSegmented<InventoryChangeWindow>(
            key: const ValueKey('inventory-change-window'),
            segments: [
              for (final window in InventoryChangeWindow.values)
                SkewSegment(value: window, label: window.label),
            ],
            selected: controller.changeWindow,
            onChanged: controller.setChangeWindow,
            height: 26,
            fontSize: AppType.captionSize,
          ),
        ],
      ),
      _rule(quad),
    ];
    final changes = controller.netChanges;
    if (changes == null || !changes.known) {
      final (text, detail) = _changesNotice(changes);
      children.add(
        _notice(quad, 'inventory-analysis-changes-empty', text, detail: detail),
      );
      return Stack(clipBehavior: Clip.none, children: children);
    }
    Widget caption(double top, String text, Key key) {
      final y = quad.top + top;
      final left =
          quad.leftAt(y + InventoryAnalysisMetrics.changeCaptionHeight) +
          InventoryAnalysisMetrics.changeRowLeft +
          InventoryAnalysisMetrics.changeCaptionInner;
      return Positioned(
        left: left,
        top: y,
        width: math.max(
          0.0,
          quad.rightAt(y) - InventoryAnalysisMetrics.changeRight - left,
        ),
        height: InventoryAnalysisMetrics.changeCaptionHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            key: key,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _captionStyle,
          ),
        ),
      );
    }

    children.add(
      caption(
        InventoryAnalysisMetrics.changeCaptionTop,
        controller.changeWindow.caption,
        const ValueKey('inventory-change-caption'),
      ),
    );
    final rows = changes.rows;
    final barLeft =
        quad.leftAt(quad.top) + InventoryAnalysisMetrics.changeBarLeft;
    if (rows.isEmpty) {
      final y = quad.top + InventoryAnalysisMetrics.changeRowsTop;
      final left =
          quad.leftAt(y + InventoryAnalysisMetrics.changeRowHeight) +
          InventoryAnalysisMetrics.changeRowLeft +
          InventoryAnalysisMetrics.changeRowInner;
      children.add(
        Positioned(
          left: left,
          top: y,
          width: math.max(
            0.0,
            quad.rightAt(y) - InventoryAnalysisMetrics.changeRight - left,
          ),
          height: InventoryAnalysisMetrics.changeRowHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '이 기간에 수량이 바뀐 재화가 없습니다.',
              key: const ValueKey('inventory-change-none'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _muted.copyWith(fontSize: AppType.bodySmallSize),
            ),
          ),
        ),
      );
    } else {
      final axisTop = quad.top + InventoryAnalysisMetrics.changeAxisTop;
      children.add(
        Positioned(
          key: const ValueKey('inventory-change-axis'),
          left: barLeft + InventoryChangeBarMetrics.axisX,
          top: axisTop,
          width: math.max(
            0.0,
            math.min(
              1.0,
              quad.rightAt(axisTop) -
                  InventoryAnalysisMetrics.changeRight -
                  barLeft,
            ),
          ),
          height: InventoryAnalysisMetrics.changeAxisHeight,
          child: const ColoredBox(color: _changeAxisColor),
        ),
      );
    }
    final maxMagnitude = changes.maxMagnitude;
    for (final (index, row) in rows.indexed) {
      final y =
          quad.top +
          InventoryAnalysisMetrics.changeRowsTop +
          index * InventoryAnalysisMetrics.changeRowPitch;
      final left =
          quad.leftAt(y + InventoryAnalysisMetrics.changeRowHeight) +
          InventoryAnalysisMetrics.changeRowLeft +
          InventoryAnalysisMetrics.changeRowInner;
      children.add(
        Positioned(
          left: left,
          top: y,
          width: InventoryAnalysisMetrics.changeLabelWidth,
          height: InventoryAnalysisMetrics.changeRowHeight,
          child: _ChangeLabel(
            key: ValueKey('inventory-change-row-$index'),
            view: row.view,
          ),
        ),
      );
      children.add(
        Positioned(
          left: barLeft,
          top: y,
          width: math.max(
            0.0,
            math.min(
              InventoryChangeBarMetrics.width,
              quad.rightAt(y) - InventoryAnalysisMetrics.changeRight - barLeft,
            ),
          ),
          height: InventoryAnalysisMetrics.changeRowHeight,
          child: _Fit(
            minWidth: InventoryChangeBarMetrics.width,
            minHeight: InventoryAnalysisMetrics.changeRowHeight,
            child: InventoryChangeBar(
              key: ValueKey('inventory-change-bar-${row.view.key}'),
              delta: row.delta,
              maxMagnitude: maxMagnitude,
            ),
          ),
        ),
      );
    }
    // "이 추세라면"(FD-042): 스캔 점 3회 이상인 재화만, 없으면 문구를 숨긴다.
    final forecasts = controller.forecasts;
    if (forecasts.isNotEmpty) {
      children.add(
        caption(
          InventoryAnalysisMetrics.forecastCaptionTop,
          '이 추세라면',
          const ValueKey('inventory-forecast-caption'),
        ),
      );
      for (final (index, forecast) in forecasts.indexed) {
        final y =
            quad.top +
            InventoryAnalysisMetrics.forecastRowsTop +
            index * InventoryAnalysisMetrics.forecastRowPitch;
        final left =
            quad.leftAt(y + InventoryAnalysisMetrics.forecastRowHeight) +
            InventoryAnalysisMetrics.changeRowLeft;
        children.add(
          Positioned(
            left: left,
            top: y,
            width: math.max(
              0.0,
              quad.rightAt(y) - InventoryAnalysisMetrics.changeRight - left,
            ),
            height: InventoryAnalysisMetrics.forecastRowHeight,
            child: _Fit(
              minWidth: 520,
              minHeight: InventoryAnalysisMetrics.forecastRowHeight,
              child: _ForecastRow(
                key: ValueKey('inventory-forecast-$index'),
                forecast: forecast,
              ),
            ),
          ),
        );
      }
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }

  /// S5에 증감 행을 그릴 수 없을 때의 안내(제목, 설명).
  (String, String?) _changesNotice(InventoryNetChanges? changes) {
    if (changes != null && (controller.history?.eventCount ?? 0) > 0) {
      return (
        '이 기간 처음 수량을 알 수 없어 순증감을 셀 수 없습니다.',
        '변화 기록이 이 기간보다 짧거나 일부가 정리되었습니다.',
      );
    }
    if (_blocker case final blocker?) return (blocker, null);
    if (_waiting || controller.historyLoading) {
      return ('변화 기록을 읽는 중입니다.', null);
    }
    if (controller.historyError case final error?) return (error, null);
    return ('변화 기록이 아직 없습니다.', '스캔 이력이 쌓이면 기간별 순증감과 추세가 보입니다.');
  }
}

/// S5 가운데 축선 색(시안 rgba(56,81,107,.9)).
const _changeAxisColor = Color.fromRGBO(56, 81, 107, 0.9);

/// S5 증감 행의 왼쪽(아이콘 32 × 26 · 간격 8 · 이름 12px 600, 시안 폭 196).
class _ChangeLabel extends StatelessWidget {
  const _ChangeLabel({super.key, required this.view});

  final InventoryItemView view;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _itemIcon(view, const Size(32, 26)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          view.item.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body.copyWith(
            fontSize: AppType.bodySmallSize,
            fontWeight: AppType.semiBold,
          ),
        ),
      ),
    ],
  );
}

/// S5 "이 추세라면" 행(시안 `.row` 44: 글자 13px + 칩 위험 · 충분).
class _ForecastRow extends StatelessWidget {
  const _ForecastRow({super.key, required this.forecast});

  final InventoryForecast forecast;

  @override
  Widget build(BuildContext context) => DiagonalRow(
    variant: DiagonalRowVariant.row,
    padding: const EdgeInsets.fromLTRB(19.8, 0, 14, 0),
    child: Row(
      children: [
        Expanded(
          child: Text(
            forecast.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _body.copyWith(fontSize: AppType.bodySize),
          ),
        ),
        const SizedBox(width: 10),
        BaChip(
          label: forecast.chip,
          tone: forecast.kind == InventoryForecastKind.worsening
              ? AppTones.danger
              : AppTones.ok,
        ),
      ],
    ),
  );
}

/// 분석 섹션 안 안내(가운데, 글자 묶음만 줄여 맞춘다).
class _AnalysisNotice extends StatelessWidget {
  const _AnalysisNotice({super.key, required this.text, this.detail});

  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (detail != null) ...[
                const SizedBox(height: 6),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _muted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "이 화면에 보이는 분석"으로 고른 섹션 외곽선(분홍 2px).
class _AnalysisHighlightPainter extends CustomPainter {
  const _AnalysisHighlightPainter(this.sectionId);

  final String sectionId;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    buildSectionCanvasElementPath(size, inventoryAnalysisSection(sectionId)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.accent.withValues(alpha: 0.9),
  );

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_AnalysisHighlightPainter oldDelegate) =>
      oldDelegate.sectionId != sectionId;
}

/// 학교 엠블럼 asset(`School_Icon_<NAME>.png`, 공용 맵 `school_labels.dart`). 맞는 그림이 없으면 null.
String? inventorySchoolEmblemAsset(String school) => schoolEmblemAsset(school);

/// 학교 엠블럼(S1 30×26 · 티어 화면 28×24, 불투명도 .92, contain). 그림이 없거나 읽지 못하면 이름 앞 두 글자를
/// 쓴다(FE3-f2a 대체 표시).
class _SchoolEmblem extends StatelessWidget {
  const _SchoolEmblem({
    required this.school,
    this.size = const Size(30, 26),
  });

  final String school;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final label = inventorySchoolLabel(school);
    final fallback = Center(
      key: ValueKey('inventory-school-emblem-fallback-$school'),
      child: Text(
        label.substring(0, math.min(2, label.length)),
        maxLines: 1,
        style: _muted.copyWith(fontWeight: AppType.bold),
      ),
    );
    final asset = inventorySchoolEmblemAsset(school);
    return SizedBox(
      width: size.width,
      height: size.height,
      child: asset == null
          ? fallback
          : Opacity(
              opacity: 0.92,
              child: GameImage(
                asset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
            ),
    );
  }
}

/// S1 학교 행(시안 803.8×52, 투명 행).
class _SchoolRow extends StatelessWidget {
  const _SchoolRow({
    super.key,
    required this.row,
    required this.studentName,
    required this.onOpenPlan,
  });

  final InventorySchoolRow row;
  final String Function(String) studentName;
  final VoidCallback onOpenPlan;

  /// 학생 한 줄의 종류별 글자(`상급 BD 12`). 모자라지 않으면 `—`.
  static String needText(InventoryStudentNeed? need, String kind) => need == null
      ? '—'
      : '${inventoryNoteTierLabel(need.tier)} $kind ${inventoryAmount(need.amount)}';

  @override
  Widget build(BuildContext context) {
    final label = row.label;
    final students = row.students;
    final unknown = row.unknownKinds;
    final chip = BaChip(label: '계획 ${students.length}명', tone: AppTones.gray);
    return DiagonalRow(
      variant: DiagonalRowVariant.plain,
      child: _Fit(
        minWidth: 760,
        minHeight: InventoryAnalysisMetrics.schoolRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 19.2),
          child: Row(
            children: [
              _SchoolEmblem(school: row.school),
              const SizedBox(width: 10),
              SizedBox(
                width: 72,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body.copyWith(fontSize: AppType.bodySize),
                ),
              ),
              const SizedBox(width: 10),
              _CoverageBar(
                key: ValueKey('inventory-school-${row.school}-bd'),
                label: 'BD',
                labelWidth: 20,
                barWidth: 126,
                valueWidth: 48,
                coverage: row.bd,
                color: AppColors.primary,
              ),
              // 시안: 간격 10 + 빈 칸 12 + 간격 10.
              const SizedBox(width: 32),
              _CoverageBar(
                key: ValueKey('inventory-school-${row.school}-notes'),
                label: '기술 노트',
                labelWidth: 48,
                barWidth: 129,
                valueWidth: 49,
                coverage: row.notes,
                color: AppColors.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  unknown > 0
                      ? '${row.shortageLabel} · $unknown종 모름'
                      : row.shortageLabel,
                  key: ValueKey('inventory-school-${row.school}-shortage'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: _muted,
                ),
              ),
              const SizedBox(width: 10),
              if (students.isEmpty)
                chip
              else
                AnchoredFlyout(
                  key: ValueKey('inventory-school-flyout-${row.school}'),
                  semanticLabel: '$label 계획 학생 ${students.length}명 보기',
                  panelLabel: '$label 계획 학생',
                  preset: FlyoutPreset.down,
                  children: [
                    FlyoutHeader(
                      '$label · 계획 학생 ${students.length}명',
                      note: '부족 필요량 · ',
                      noteSpans: const [
                        TextSpan(
                          text: 'BD',
                          style: TextStyle(color: AppColors.primary),
                        ),
                        TextSpan(text: ' · '),
                        TextSpan(
                          text: '노트',
                          style: TextStyle(color: AppColors.accentText),
                        ),
                      ],
                    ),
                    for (final student in students.take(5))
                      _SchoolStudentRow(
                        key: ValueKey(
                          'inventory-school-${row.school}-student-${student.studentId}',
                        ),
                        student: student,
                        name: studentName(student.studentId),
                      ),
                    FlyoutFooter(
                      text: students.length > 5
                          ? '… 외 ${students.length - 5}명'
                          : null,
                      trailing: KitPressable(
                        onPressed: onOpenPlan,
                        semanticLabel: '계획에서 보기',
                        builder: (context, state) =>
                            const FlyoutLink('계획에서 보기 →'),
                      ),
                    ),
                  ],
                  child: chip,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 학교 플라이아웃의 학생 한 줄(초상 40×32 · 이름 · BD · 노트 부족 필요량).
class _SchoolStudentRow extends StatelessWidget {
  const _SchoolStudentRow({
    super.key,
    required this.student,
    required this.name,
  });

  final InventorySchoolStudent student;
  final String name;

  @override
  Widget build(BuildContext context) => FlyoutRow(
    children: [
      PortraitStrip(
        studentIds: [student.studentId],
        maxVisible: 1,
        portraitSize: const Size(40, 32),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body.copyWith(
                fontSize: AppType.bodySize,
                fontWeight: AppType.bold,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Flexible(
                  child: Text(
                    _SchoolRow.needText(student.bd, 'BD'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _muted.copyWith(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    _SchoolRow.needText(student.notes, '노트'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _muted.copyWith(color: AppColors.accentText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

/// 학교 행의 종류 막대(라벨 · `.bar2` · %). 계획에 안 쓰면 막대 없이 `—`, 모두 모르면 빗금 + `—`.
class _CoverageBar extends StatelessWidget {
  const _CoverageBar({
    super.key,
    required this.label,
    required this.labelWidth,
    required this.barWidth,
    required this.valueWidth,
    required this.coverage,
    required this.color,
  });

  final String label;
  final double labelWidth;
  final double barWidth;
  final double valueWidth;
  final InventoryCoverage coverage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fulfillment = coverage.fulfillment;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            maxLines: 1,
            textAlign: TextAlign.right,
            style: _muted.copyWith(
              fontSize: AppType.bodySmallSize,
              fontWeight: AppType.semiBold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: barWidth,
          child: coverage.planned
              ? SkewBar(
                  fraction: fulfillment,
                  color: color,
                  style: SkewBarStyle.flat,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: valueWidth,
          child: Text(
            fulfillment == null ? '—' : '${(fulfillment * 100).round()}%',
            maxLines: 1,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: AppType.bodySmallSize,
              height: 1.25,
              fontWeight: AppType.bold,
              color: fulfillment == null ? AppColors.textMuted : AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}

/// 티어 토글의 색 점(9×9).
class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 9,
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}

/// 범례 "핵심 병목" 고리(12px 원 + 바깥 2px 분홍).
class _BottleneckRing extends StatelessWidget {
  const _BottleneckRing();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 16,
    child: Center(
      child: SizedBox.square(
        dimension: 12,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.accent, spreadRadius: 2)],
          ),
        ),
      ),
    ),
  );
}

/// S2 산점도. 마우스를 올린 점의 이름 · 보유율 · 학생 수를 작은 말풍선으로 보인다(시안 `<title>`). 점을 누르면 그
/// 오파츠를 고른다(FD-103, 확장 전후 모두). 확장(FE6-d)에서는 [geometry]가 커지고 점 자리에 오파츠 아이콘이 [icons]만큼
/// 나타난다(크로스페이드). 아이콘 그림이 없으면 이름 앞 두 글자다(시안 "아우" · "오브" · "구스" · "토리").
class _OopartScatter extends StatefulWidget {
  const _OopartScatter({
    required this.analysis,
    required this.tiers,
    required this.geometry,
    required this.icons,
    required this.selectedFamily,
    required this.onSelect,
  });

  final InventoryOopartAnalysis analysis;
  final Set<int> tiers;
  final InventoryScatterGeometry geometry;
  final double icons;

  /// 사용자가 고른 오파츠(선택 표시). 기본 선택은 null로 받는다.
  final String? selectedFamily;
  final ValueChanged<String> onSelect;

  @override
  State<_OopartScatter> createState() => _OopartScatterState();
}

class _OopartScatterState extends State<_OopartScatter> {
  InventoryOopartPoint? _hovered;

  InventoryOopartScatterPainter get _painter => InventoryOopartScatterPainter(
    analysis: widget.analysis,
    tiers: widget.tiers,
    hovered: _hovered?.key,
    geometry: widget.geometry,
    icons: widget.icons,
    selectedFamily: widget.selectedFamily,
  );

  void _hover(Offset position) {
    final hit = _painter.hitTest(position);
    if (hit?.key == _hovered?.key) return;
    setState(() => _hovered = hit);
  }

  void _tap(Offset position) {
    _hover(position);
    final hit = _painter.hitTest(position);
    final family = hit?.view.item.family;
    if (family != null) widget.onSelect(family);
  }

  @override
  Widget build(BuildContext context) {
    final hovered = _hovered;
    final analysis = widget.analysis;
    final geometry = widget.geometry;
    final viewBox = geometry.viewBox;
    final painter = _painter;
    final points = analysis.series.fold<int>(
      0,
      (sum, series) => sum + series.points.length,
    );
    final center = hovered == null
        ? null
        : geometry.pointFor(
            hovered.fulfillment,
            hovered.students,
            analysis.maxStudents,
          );
    final icons = widget.icons.clamp(0.0, 1.0).toDouble();
    return SizedBox(
      width: viewBox.width,
      height: viewBox.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          MouseRegion(
            onHover: (event) => _hover(event.localPosition),
            onExit: (_) {
              if (_hovered != null) setState(() => _hovered = null);
            },
            child: StatChartFrame(
              key: const ValueKey('inventory-oopart-scatter'),
              viewBox: viewBox,
              scale: 1,
              painter: painter,
              onTapAt: _tap,
              semanticLabel:
                  '오파츠 보유율과 사용 학생 수, ${analysis.series.length}종 $points점',
            ),
          ),
          if (icons > 0)
            for (final (point, center, radius) in painter.iconSlots())
              Positioned(
                key: ValueKey('inventory-oopart-icon-${point.key}'),
                left: center.dx - radius,
                top: center.dy - radius,
                width: radius * 2,
                height: radius * 2,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: icons,
                    child: _OopartPointIcon(point: point, radius: radius),
                  ),
                ),
              ),
          if (hovered != null && center != null)
            Positioned(
              left: math.min(center.dx + 12, viewBox.width - 260),
              top: math.max(0.0, center.dy - 40),
              child: IgnorePointer(
                child: Container(
                  key: const ValueKey('inventory-oopart-tooltip'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.popover,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Text(
                    '${inventoryOopartLabel(hovered.view)} T${hovered.tier} · 보유율 '
                    '${(hovered.fulfillment * 100).round()}% · 학생 ${hovered.students}명',
                    maxLines: 1,
                    style: _muted.copyWith(
                      fontSize: AppType.bodySmallSize,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 확장 산점도 점 하나의 아이콘(원으로 자른 오파츠 그림, 시안 clipPath r 13 · 병목 20, 그림 30 · 44). 그림이 없으면
/// 이름 앞 두 글자(11px · 병목 16px, 굵게)다. 원 바탕 · 테두리 · 티어 글자는 painter가 그린다.
class _OopartPointIcon extends StatelessWidget {
  const _OopartPointIcon({required this.point, required this.radius});

  final InventoryOopartPoint point;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final view = point.view;
    final fallback = _OopartInitials(
      view: view,
      fontSize: point.bottleneck ? 16 : 11,
    );
    final asset = planningResourceIconAsset(
      category: view.item.category,
      itemId: view.item.itemId,
    );
    if (asset == null) return fallback;
    return ClipOval(
      child: OverflowBox(
        maxWidth: radius * 2 + 4,
        maxHeight: radius * 2 + 4,
        child: GameImage(
          asset,
          width: radius * 2 + 4,
          height: radius * 2 + 4,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      ),
    );
  }
}

/// 오파츠 이름 앞 두 글자(아이콘 그림 대신).
class _OopartInitials extends StatelessWidget {
  const _OopartInitials({required this.view, required this.fontSize});

  final InventoryItemView view;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final label = inventoryOopartLabel(view);
    return Center(
      child: Text(
        label.substring(0, math.min(2, label.length)),
        key: ValueKey('inventory-oopart-initials-${view.key}'),
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: _muted.copyWith(
          fontSize: fontSize,
          fontWeight: AppType.bold,
          color: AppColors.text,
        ),
      ),
    );
  }
}

/// 히트맵 범례(`0%` · 그라데이션 막대 · `100% 충족`).
class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Text('0%', maxLines: 1, style: _muted),
      SizedBox(width: 8),
      Expanded(
        child: SizedBox(
          height: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              gradient: LinearGradient(
                colors: [
                  Color.fromRGBO(113, 199, 244, 0.06),
                  Color.fromRGBO(113, 199, 244, 0.9),
                ],
              ),
            ),
          ),
        ),
      ),
      SizedBox(width: 8),
      Text('100% 충족', maxLines: 1, style: _muted),
    ],
  );
}

/// 부족 상위 한 줄(시안 `.row` 1119×46: `.pt` 47×38 · 이름 · `−36 · 학생 7명` · 초상 줄 246).
class _TopShortageRow extends StatelessWidget {
  const _TopShortageRow({super.key, required this.shortage, this.title});

  final InventoryTopShortage shortage;

  /// 품목 글자. 없으면 재화 표시 이름이다(티어 화면 T5는 `오파츠 · 네브라 디스크 T3` 꼴).
  final String? title;

  @override
  Widget build(BuildContext context) {
    final view = shortage.view;
    return DiagonalRow(
      variant: DiagonalRowVariant.row,
      padding: const EdgeInsets.fromLTRB(20.1, 0, 14, 0),
      child: Row(
        children: [
          _itemIcon(view, const Size(47, 38)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title ?? view.item.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body.copyWith(fontSize: AppType.bodySize),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '−${inventoryAmount(view.shortageAmount ?? 0)} · 학생 ${shortage.students.length}명',
            maxLines: 1,
            style: _muted.copyWith(
              fontSize: AppType.bodySmallSize,
              fontWeight: AppType.regular,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 26),
          PortraitStrip(studentIds: shortage.students, slotWidth: 246),
        ],
      ),
    );
  }
}
